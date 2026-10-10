--!nonstrict
-- Server/Services/TitanService.lua  (docs/10_titans.md §1.2-1.3, §1.6; docs/12 §6; docs/08 §2)
--
-- Titans on the server: spawning a rig with its own look, its hurtboxes, and what it takes as damage (HP with
-- the "can't die standing" clamp, poise, both regenerating). Titans are server-owned. What a Titan does
-- (the state machine, attacks, Downed, death) is its behavior module's job (Server/Titans/Behaviors/<type>),
-- which arrives with the next step of Phase 3: until then a Titan stands and takes hits.
--
--   spawn(typeName, groundCFrame, opts?) -> model        opts: { seed = number }
--   despawn(model)        getTitans() -> { model }       getById(targetId) -> model?
--   setHurtboxState(model, "Standing" | "Downed" | "LungeRecover")
--   setHP(model, hp)      Spawned / Hit / Died: Signals
--
-- Attributes on the model (docs/10 §1.6): TitanType, DisplayName, ClassTier, TargetId, HP, MaxHP, Poise,
-- MaxPoise, State, Anim, AnimT0, AnimSpeed, Enraged, CoreExposed. Class is the pose rig's name ("Strider"),
-- as on a Frame; the "CLASS-3" of the doc is ClassTier.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local TitanConfig = require(Shared.Config.TitanConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local CollisionService = require(script.Parent.CollisionService)
local CombatService = require(script.Parent.CombatService)
local TitanLook = require(script.Parent.Parent.Titans.TitanLook)

local TAG = "TitanService"
local PUBLISH = 0.1 -- seconds between HP / Poise attribute updates while they regenerate

local TitanService = {}

TitanService.Spawned = Signal.new()
TitanService.Hit = Signal.new() -- (model, hit, { hp, poise, clamped })
TitanService.Died = Signal.new()

local titans = {} -- [model] = { config, hp, poise, maxPoise, lastHurt, lastPoiseHurt, published, hurtboxes }
local byId = {}
local folder
local nextId = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function publish(model, entry)
	entry.published = now()
	model:SetAttribute("HP", entry.hp)
	model:SetAttribute("Poise", entry.poise)
	model:SetAttribute("MaxPoise", entry.maxPoise)
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
	local before = entry.hp
	entry.hp = math.max(if downed then 0 else 1, entry.hp - hit.damage)
	entry.poise = math.max(0, entry.poise - hit.poise)
	entry.lastHurt = t
	if hit.poise > 0 then
		entry.lastPoiseHurt = t
	end
	publish(model, entry)
	-- Reaching the clamp while standing forces a poise break (docs/10 §1.3); the behavior acts on it.
	local clamped = not downed and before - hit.damage < 1
	TitanService.Hit:Fire(model, hit, { hp = entry.hp, poise = entry.poise, clamped = clamped })
	if entry.hp <= 0 then
		entry.dead = true
		TitanService.Died:Fire(model)
	end
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

	local entry = {
		config = config, hp = config.hp, poise = config.poise.base, maxPoise = config.poise.base, lastHurt = 0, lastPoiseHurt = 0,
		published = 0, hurtboxes = {}, id = id,
	}
	model:SetAttribute("TitanType", typeName)
	model:SetAttribute("DisplayName", config.displayName)
	model:SetAttribute("ClassTier", config.classTier)
	model:SetAttribute("TargetId", id)
	model:SetAttribute("MaxHP", config.hp)
	model:SetAttribute("State", "Idle")
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
	publish(model, entry)
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "PoseRig")
	CombatService.registerTarget(id, function(hit)
		takeHit(model, hit)
	end)
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
		publish(model, entry)
	end
end

-- HP and poise come back after a quiet spell (docs/10 §1.3).
local function regenerate(dt)
	local t = now()
	for model, entry in pairs(titans) do
		if not model.Parent then
			titans[model] = nil
			byId[entry.id] = nil
			continue
		end
		if entry.dead then
			continue
		end
		local config = entry.config
		local changed = false
		if entry.hp < config.hp and model:GetAttribute("State") ~= "Downed" and t - entry.lastHurt >= config.hpRegen.delay then
			entry.hp = math.min(config.hp, entry.hp + config.hpRegen.rate * dt)
			changed = true
		end
		if entry.poise < entry.maxPoise and t - entry.lastPoiseHurt >= config.poise.regenDelay then
			entry.poise = math.min(entry.maxPoise, entry.poise + config.poise.regen * dt)
			changed = true
		end
		if changed and t - entry.published >= PUBLISH then
			publish(model, entry)
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
	RunService.Heartbeat:Connect(regenerate)
end

return TitanService
