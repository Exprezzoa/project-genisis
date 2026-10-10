--!nonstrict
-- Server/Services/TitanService.lua  (docs/10_titans.md §1.2-1.6; docs/12 §6; docs/08 §2)
--
-- Titans on the server: spawning a rig with its own look, its hurtboxes, what it takes as damage (HP with the
-- "can't die standing" clamp, poise, both regenerating), and the published attributes. What a Titan does
-- (its state machine, attacks, Downed, death) is its behavior module's job: Server/Titans/Behaviors/<type>,
-- one instance per Titan, stepped from here. Titans are server-owned.
--
--   spawn(typeName, groundCFrame, opts?) -> model        opts: { seed = number, passive = boolean }
--   despawn(model)        getTitans() -> { model }       getById(targetId) -> model?
--   getEntry(model) -> entry          (the behavior reads and writes hp, poise, maxPoise, anklePoise, coreHeld)
--   setHurtboxState(model, "Standing" | "Downed" | "LungeRecover")
--   playAnim(model, clip, speed?)     setState(model, state)     setCoreExposed(model, exposed)
--   setHP(model, hp)      breakPoise(model)      publish(model)      setFrozen(on) / isFrozen()  (debug)
--   reset(model) -> boolean           back to how it spawned (RetryService)
--   Spawned / Hit / Died: Signals
--
-- Attributes on the model (docs/10 §1.6): TitanType, DisplayName, ClassTier, TargetId, HP, MaxHP, Poise,
-- MaxPoise, State, Attack, AttackT0, Anim, AnimT0, AnimSpeed, Enraged, CoreExposed, CoreUntil. Class is the
-- pose rig's name ("Strider"), as on a Frame; the "CLASS-3" of the doc is ClassTier.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local FrameConfig = require(Shared.Config.FrameConfig)
local TitanConfig = require(Shared.Config.TitanConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local CollisionService = require(script.Parent.CollisionService)
local CombatService = require(script.Parent.CombatService)
local Titans = script.Parent.Parent.Titans
local TitanLook = require(Titans.TitanLook)

local TAG = "TitanService"
local PUBLISH = 0.1 -- seconds between HP / Poise attribute updates while they regenerate

local TitanService = {}

TitanService.Spawned = Signal.new()
TitanService.Hit = Signal.new() -- (model, hit, { hp, poise, poiseDamage, clamped })
TitanService.Died = Signal.new()

local titans = {} -- [model] = entry
local byId = {}
local folder
local nextId = 0
local frozen = false -- debug: behaviors don't take their steps

local function now()
	return workspace:GetServerTimeNow()
end

function TitanService.publish(model)
	local entry = titans[model]
	if entry then
		entry.published = now()
		model:SetAttribute("HP", entry.hp)
		model:SetAttribute("Poise", entry.poise)
		model:SetAttribute("MaxPoise", entry.maxPoise)
	end
end

function TitanService.getEntry(model)
	return titans[model]
end

function TitanService.playAnim(model, clip, speed)
	model:SetAttribute("AnimSpeed", speed or 1)
	model:SetAttribute("Anim", clip)
	model:SetAttribute("AnimT0", now())
end

function TitanService.setState(model, state)
	model:SetAttribute("State", state)
end

function TitanService.setCoreExposed(model, exposed, forSeconds)
	model:SetAttribute("CoreUntil", if exposed and forSeconds then now() + forSeconds else 0)
	model:SetAttribute("CoreExposed", exposed)
end

function TitanService.setHurtboxState(model, state)
	local entry = titans[model]
	if not entry then
		return
	end
	for zone, weld in pairs(entry.hurtboxes) do
		local spec = entry.config.hurtboxes[zone]
		local place = spec[state]
		if place == nil then
			place = spec.Standing
		end
		weld.Part1.CanQuery = place ~= false
		if place then
			weld.C0 = place
		end
	end
	model:SetAttribute("HurtboxState", state)
end

-- A hit of a Frame's attack on this Titan (docs/12 §6).
local function takeHit(model, hit)
	local entry = titans[model]
	if not entry or entry.dead then
		return
	end
	local t = now()
	local downed = model:GetAttribute("State") == "Downed"
	local poise = hit.poise
	if entry.anklePoise and (hit.zone == "AnkleL" or hit.zone == "AnkleR") then
		-- The planted leg is open after a Stomp: the ankle's poise multiplier rises (docs/10 §1.2).
		poise = poise / CombatConfig.Zones.AnkleL.poiseMult * entry.anklePoise
	end
	local before = entry.hp
	entry.hp = math.max(if downed then 0 else 1, entry.hp - hit.damage)
	entry.poise = math.max(0, entry.poise - poise)
	entry.lastHurt = t
	if poise > 0 then
		entry.lastPoiseHurt = t
	end
	TitanService.publish(model)
	-- Reaching the clamp while standing forces a poise break (docs/10 §1.3); the behavior acts on it.
	local clamped = not downed and before - hit.damage < 1
	if entry.hp <= 0 then
		entry.dead = true
	end
	TitanService.Hit:Fire(model, hit, { hp = entry.hp, poise = entry.poise, poiseDamage = poise, clamped = clamped })
	if entry.dead then
		TitanService.Died:Fire(model)
	end
end

-- Where a Core Strike has to land, while the core shows.
local function coreOf(model)
	local entry = titans[model]
	if entry and not entry.dead and model:GetAttribute("CoreExposed") then
		return entry.hurtboxes.Core.Part1.Position
	end
	return nil
end

function TitanService.spawn(typeName, groundCFrame, opts)
	opts = opts or {}
	local config = TitanConfig[typeName]
	if not config then
		error("TitanService: unknown Titan type " .. tostring(typeName), 2)
	end
	local templates = ServerStorage:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("Titans") and templates.Titans:FindFirstChild(config.rig)
	if not template then
		error(("TitanService: no template Titans.%s (run the rig builder)"):format(config.rig), 2)
	end
	nextId += 1
	local id = "TITAN_" .. nextId
	local model = template:Clone()
	model.Name = typeName .. "_" .. nextId
	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	for _, state in ipairs(FrameConfig.DisabledStates) do
		humanoid:SetStateEnabled(Enum.HumanoidStateType[state], false)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	TitanLook.dress(model, opts.seed or math.random(1, 1e6))

	-- As on a Frame: only the root collides (docs/08 §2, D-040).
	CollisionService.assignModel(model, "NoCollide")
	CollisionService.assign(root, "TitanRoot")

	-- Facing (docs/10 §1.5): the behavior turns this toward its target, limited by its turn rate.
	local facingAttachment = Instance.new("Attachment")
	facingAttachment.Name = "FacingAttachment"
	facingAttachment.Parent = root
	local facing = Instance.new("AlignOrientation")
	facing.Name = "Facing"
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = facingAttachment
	facing.RigidityEnabled = false
	facing.MaxTorque = math.huge
	facing.Responsiveness = 40
	facing.CFrame = groundCFrame.Rotation
	facing.Parent = root

	local entry = {
		config = config, hp = config.hp, poise = config.poise.base, maxPoise = config.poise.base, lastHurt = 0, lastPoiseHurt = 0,
		published = 0, hurtboxes = {}, id = id, typeName = typeName, spawn = groundCFrame,
	}
	model:SetAttribute("TitanType", typeName)
	model:SetAttribute("DisplayName", config.displayName)
	model:SetAttribute("ClassTier", config.classTier)
	model:SetAttribute("TargetId", id)
	model:SetAttribute("MaxHP", config.hp)
	model:SetAttribute("State", "Idle")
	model:SetAttribute("Attack", "")
	model:SetAttribute("Enraged", false)
	model:SetAttribute("CoreExposed", false)
	model:SetAttribute("AnimSpeed", 1)
	model:SetAttribute("Anim", "Idle")
	model:SetAttribute("AnimT0", now())

	model:PivotTo(groundCFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	model.Parent = folder

	for zone, spec in pairs(config.hurtboxes) do
		local box = Instance.new("Part")
		box.Name = "Hurtbox_" .. zone
		box.Size = spec.size
		box.Transparency = 1
		box.CanCollide, box.CanTouch, box.CanQuery = false, false, true
		box.Massless = true
		box.CastShadow = false
		box.CFrame = root.CFrame
		box:SetAttribute("Zone", zone)
		box.Parent = model
		-- Spatial queries only see parts of a group that meets theirs: hurtboxes stay in Default.
		box.CollisionGroup = "Default"
		task.defer(function() -- once more after CollisionService's own (possibly deferred) handler
			box.CollisionGroup = "Default"
		end)
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = root, box
		weld.Parent = box
		entry.hurtboxes[zone] = weld
		CollectionService:AddTag(box, "Hurtbox")
	end
	titans[model] = entry
	byId[id] = model
	TitanService.setHurtboxState(model, "Standing")
	TitanService.publish(model)
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "PoseRig")
	CombatService.registerTarget(id, {
		model = model,
		takeHit = function(hit)
			takeHit(model, hit)
		end,
		getCore = function()
			return coreOf(model)
		end,
		-- A Core Strike has begun: the Titan stays down until it is over.
		holdCore = function(seconds)
			entry.coreHeld = now() + seconds
			model:SetAttribute("CoreUntil", math.max(model:GetAttribute("CoreUntil") or 0, entry.coreHeld))
		end,
	})

	-- The behavior: what this type of Titan does. A passive Titan (debug) only stands and takes hits.
	local source = Titans:FindFirstChild("Behaviors") and Titans.Behaviors:FindFirstChild(config.rig)
	if source and not opts.passive then
		local ok, result = pcall(function()
			return require(source).new({
				model = model, root = root, humanoid = humanoid, facing = facing, config = config, entry = entry,
				attacks = CombatConfig.TitanAttacks[typeName], service = TitanService,
			})
		end)
		if ok then
			entry.behavior = result
		else
			Log.error(TAG, "%s behavior failed to start: %s", typeName, tostring(result))
		end
	end
	Log.info(TAG, "%s spawned as %s (hair %s)", typeName, id, tostring(model:GetAttribute("Hair")))
	TitanService.Spawned:Fire(model)
	return model
end

function TitanService.despawn(model)
	local entry = titans[model]
	if entry then
		titans[model] = nil
		byId[entry.id] = nil
		CombatService.registerTarget(entry.id, nil)
		if entry.behavior and entry.behavior.destroy then
			entry.behavior:destroy()
		end
	end
	model:Destroy()
end

function TitanService.getTitans()
	local list = {}
	for model in pairs(titans) do
		table.insert(list, model)
	end
	return list
end

function TitanService.getById(targetId)
	return byId[targetId]
end

function TitanService.setHP(model, hp)
	local entry = titans[model]
	if entry then
		entry.hp = math.clamp(hp, 1, entry.config.hp)
		TitanService.publish(model)
	end
end

-- Back to how it spawned: full health and poise, on its spawn point, doing nothing. false for a dead Titan.
function TitanService.reset(model)
	local entry = titans[model]
	if not entry or entry.dead then
		return false
	end
	local config = entry.config
	entry.hp, entry.poise, entry.maxPoise = config.hp, config.poise.base, config.poise.base
	entry.lastHurt, entry.lastPoiseHurt, entry.anklePoise, entry.coreHeld = 0, 0, nil, nil
	if entry.behavior and entry.behavior.reset then
		entry.behavior:reset()
	end
	model:SetAttribute("Enraged", false)
	TitanService.setCoreExposed(model, false)
	TitanService.setHurtboxState(model, "Standing")
	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	model:PivotTo(entry.spawn * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	TitanService.playAnim(model, "Idle")
	TitanService.publish(model)
	return true
end

-- Empties the Titan's poise as a hit would (debug: /titan down).
function TitanService.breakPoise(model)
	local entry = titans[model]
	if entry and not entry.dead then
		entry.poise = 0
		TitanService.publish(model)
		TitanService.Hit:Fire(model, { damage = 0, poise = 0, zone = "Body", move = "Debug" }, { hp = entry.hp, poise = 0, poiseDamage = 0, clamped = false })
	end
end

-- Debug (/titan freeze): every behavior stops where it is; hits still count.
function TitanService.setFrozen(on)
	frozen = on
end

function TitanService.isFrozen()
	return frozen
end

-- HP and poise come back after a quiet spell (docs/10 §1.3); then each Titan's behavior takes its step.
local function step(dt)
	local t = now()
	for model, entry in pairs(titans) do
		if not model.Parent then
			titans[model] = nil
			byId[entry.id] = nil
			continue
		end
		if not entry.dead then
			local config = entry.config
			local changed = false
			local state = model:GetAttribute("State")
			if entry.hp < config.hp and state ~= "Downed" and t - entry.lastHurt >= config.hpRegen.delay then
				entry.hp = math.min(config.hp, entry.hp + config.hpRegen.rate * dt)
				changed = true
			end
			if entry.poise < entry.maxPoise and state ~= "Downed" and t - entry.lastPoiseHurt >= config.poise.regenDelay then
				entry.poise = math.min(entry.maxPoise, entry.poise + config.poise.regen * dt)
				changed = true
			end
			if changed and t - entry.published >= PUBLISH then
				TitanService.publish(model)
			end
		end
		if entry.behavior and not frozen then
			local ok, message = pcall(entry.behavior.step, entry.behavior, dt)
			if not ok then
				Log.error(TAG, "%s behavior stopped: %s", model.Name, tostring(message))
				entry.behavior = nil
			end
		end
	end
end

function TitanService.Init()
	folder = workspace:FindFirstChild("Titans")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Titans"
		folder.Parent = workspace
	end
end

function TitanService.Start()
	RunService.Heartbeat:Connect(step)
end

return TitanService
