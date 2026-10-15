--!nonstrict
-- Server/Services/ShifterService.lua  (docs/02 §8, docs/06 §6 "Shifter transformation", docs/10; D-095, D-096)
--
-- Elias shifting into his Titan form, fighting in it, and coming back. The client asks (Shift_Request after the
-- player held Z; Shift_Special for the specials); the server decides everything.
--
-- To shift he needs the ability (flag CAN_SHIFT), a place that allows it (the Training Yard, or a story step's
-- { "shifting", allowed = true }: player attribute ShiftAllowed), enough of the meter (player attribute ShiftEnergy,
-- ShifterConfig.energy), and to be on foot and free. The first time, a cinematic plays (CIN_FIRST_SHIFT: he loses
-- control) and the bolt lands at its strikeAt. Every client draws the bolt (Shift_Effect "Shift"); under the white
-- the Titan (Templates.Titans.Shifter_Elias) stands where he was and he sits hidden in its nape. The Titan form is
-- then his piloted rig (FrameService.adopt): his client rides it like a Frame, CombatService runs its fists
-- (CombatConfig.Frames.Shifter), Titans fight it. It heals itself; it can't be disabled (NoDisable): at 0 integrity
-- or an empty meter it gives way. Specials (Hardening, Rage) are buffs: DamageMult, DamageTakenMult, SpeedMult on
-- the rig, <Name>Until and <Name>ReadyAt for the HUD.
-- Back: it sinks to one knee, steam pours from its nape (Shift_Effect "Revert"), he comes out behind it, it fades.
-- Outside an allowed place for leaveGrace seconds it comes back by itself; a load, a death or leaving at once.
--
--   isShifted(player) -> boolean     canShift(player) -> boolean, reason?     setAllowed(player, on)
--   shift(player) -> boolean, reason?     revert(player, instant?, reason?)     reset(player)
--   getEnergy(player) -> number     setEnergy(player, value)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local ShifterConfig = require(Shared.Config.ShifterConfig)

local CharacterService = require(script.Parent.CharacterService)
local CinematicService = require(script.Parent.CinematicService)
local CollisionService = require(script.Parent.CollisionService)
local CombatService = require(script.Parent.CombatService)
local DialogueService = require(script.Parent.DialogueService)
local FlagService = require(script.Parent.FlagService)
local FrameService = require(script.Parent.FrameService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneService = require(script.Parent.ZoneService)

local TAG = "ShifterService"
local TICK = 0.25
local SPECIALS = ShifterConfig.specials
local ENERGY = ShifterConfig.energy

local ShifterService = {}

local entries = {} -- [player] = { phase = "shifting" | "titan" | "reverting", model, outsideSince, lastHitAt, buffs, readyAt }
local cooldownUntil = {} -- [player] = os.clock()
local energy = {} -- [player] = 0..max
local folder

local function now()
	return workspace:GetServerTimeNow()
end

local function characterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function setMassless(character, massless)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Massless = massless
		end
	end
end

-- The ground under a point (the map only: barriers, Frames and characters don't count).
local function groundBelow(position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.CollisionGroup = "Debris"
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position
end

local function inAllowedPlace(player): boolean
	return ShifterConfig.ZONES[ZoneService.getZone(player) or ""] == true or player:GetAttribute("ShiftAllowed") == true
end

----------------------------------------------------------------------------------------------------------------
-- The meter
----------------------------------------------------------------------------------------------------------------
function ShifterService.getEnergy(player): number
	return energy[player] or ENERGY.start
end

function ShifterService.setEnergy(player, value: number)
	local clamped = math.clamp(value, 0, ENERGY.max)
	energy[player] = clamped
	player:SetAttribute("ShiftEnergy", math.floor(clamped * 10 + 0.5) / 10)
end

----------------------------------------------------------------------------------------------------------------
-- Shifting
----------------------------------------------------------------------------------------------------------------
function ShifterService.isShifted(player): boolean
	return entries[player] ~= nil
end

function ShifterService.canShift(player): (boolean, string?)
	if not FlagService.has(player, ShifterConfig.FLAG) then
		return false, "NoAbility"
	end
	if entries[player] then
		return false, "Busy"
	end
	if (cooldownUntil[player] or 0) > os.clock() then
		return false, "Cooldown"
	end
	if not inAllowedPlace(player) then
		return false, "NotHere"
	end
	if ShifterService.getEnergy(player) < ENERGY.minToShift then
		return false, "NoEnergy"
	end
	if not characterParts(player) or FrameService.getPiloted(player) or DialogueService.isActive(player)
		or CinematicService.isPlaying(player) or player:GetAttribute("ControlLocked") == true then
		return false, "NotNow"
	end
	return true, nil
end

-- A story step allows shifting where it plays (and a load takes it back: reset).
function ShifterService.setAllowed(player, on: boolean)
	player:SetAttribute("ShiftAllowed", if on then true else nil)
end

local function clearEntry(player, entry)
	if entries[player] == entry then
		entries[player] = nil
		player:SetAttribute("Shifted", nil)
	end
	CharacterService.setControlLocked(player, false)
end

function ShifterService.shift(player): (boolean, string?)
	local ok, reason = ShifterService.canShift(player)
	if not ok then
		return false, reason
	end
	local template = ServerStorage.Templates:FindFirstChild("Titans") and ServerStorage.Templates.Titans:FindFirstChild(ShifterConfig.TEMPLATE)
	if not template then
		Log.warn(TAG, "no template %s (run builders/rigs/Shifter)", ShifterConfig.TEMPLATE)
		return false, "NotNow"
	end
	local entry = { phase = "shifting", buffs = {}, readyAt = {}, lastHitAt = 0 }
	entries[player] = entry
	player:SetAttribute("Shifted", true)
	CharacterService.setControlLocked(player, true)

	-- The first time he loses control first (the client's cinematic), and the bolt lands on its timeline.
	local first = not FlagService.has(player, ShifterConfig.firstShift.flag)
	if first then
		FlagService.set(player, ShifterConfig.firstShift.flag)
		CinematicService.play(player, ShifterConfig.firstShift.cinematic, { block = false })
		task.wait(ShifterConfig.firstShift.strikeAt)
	end
	local character, humanoid, root = characterParts(player)
	if not character or entries[player] ~= entry then
		clearEntry(player, entry)
		return false, "NotNow"
	end
	local ground = groundBelow(root.Position) or (root.Position - Vector3.new(0, 3, 0))
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)

	-- The bolt on every client; the swap happens under the white.
	Net.fireAllClients("Shift_Effect", { kind = "Shift", position = ground, userId = player.UserId, first = first })
	task.wait(ShifterConfig.swapAt)
	character, humanoid, root = characterParts(player)
	if not character or entries[player] ~= entry then
		clearEntry(player, entry)
		return false, "NotNow"
	end

	local model = template:Clone()
	model.Name = "Shifter_" .. player.UserId
	local titanRoot = model.PrimaryPart
	local titanHumanoid = model:FindFirstChildOfClass("Humanoid")
	for _, state in ipairs(FrameConfig.DisabledStates) do
		titanHumanoid:SetStateEnabled(Enum.HumanoidStateType[state], false)
	end
	CollisionService.assignModel(model, "NoCollide")
	CollisionService.assign(titanRoot, "FrameRoot")
	model:PivotTo(CFrame.lookAt(ground, ground + look) + Vector3.new(0, model:GetAttribute("PivotToFeet") or 31, 0))
	model:SetAttribute("Pilot", 0)
	model:SetAttribute("State", "Starting")
	model:SetAttribute("Anim", "Emerge")
	model:SetAttribute("AnimT0", now())
	model:SetAttribute("Rider", player.UserId)
	model:SetAttribute("NoDisable", true)
	model:AddTag("PoseRig")
	model.Parent = folder
	titanRoot.Anchored = false
	titanHumanoid:ChangeState(Enum.HumanoidStateType.Running)

	-- Elias sits in the nape; the Titan form is his piloted rig from here (his client rides it like a Frame).
	setMassless(character, true)
	model.PilotSeat:Sit(humanoid)
	titanRoot:SetNetworkOwner(player)
	titanRoot.Facing.CFrame = titanRoot.CFrame.Rotation
	titanRoot.Facing.Enabled = true
	FrameService.adopt(player, model)
	model:SetAttribute("Pilot", player.UserId)
	entry.model = model
	Log.info(TAG, "%s shifted (%s)%s", player.Name, tostring(ZoneService.getZone(player)), if first then ", the first time" else "")

	task.wait(ShifterConfig.emerge)
	-- The first time, the cinematic keeps the controls until it is over.
	local waited = 0
	while first and CinematicService.isPlaying(player) == ShifterConfig.firstShift.cinematic and waited < 8 do
		task.wait(0.1)
		waited += 0.1
	end
	if entries[player] == entry and model.Parent then
		model:SetAttribute("State", "Idle")
		entry.phase = "titan"
		CharacterService.setControlLocked(player, false)
	end
	return true, nil
end

-- Back to human form: it sinks to one knee with steam pouring from its nape and he comes out behind it; instant =
-- at once (a load, a death, leaving the game). reason ("Spent", "Drained", "Left") goes to the player's toast.
function ShifterService.revert(player, instant: boolean?, reason: string?)
	local entry = entries[player]
	if not entry or entry.phase == "reverting" then
		return
	end
	local wasShifting = entry.phase == "shifting"
	entry.phase = "reverting"
	local model = entry.model
	local titanRoot = model and model.PrimaryPart
	if FrameService.getPiloted(player) == model then
		FrameService.unadopt(player)
	end
	if reason and player.Parent then
		Net.fireClient(player, "Shift_Effect", { kind = "Ended", reason = reason })
	end
	if model and titanRoot and not instant and not wasShifting then
		CharacterService.setControlLocked(player, true)
		model:SetAttribute("State", "Starting") -- no walking
		model:SetAttribute("Action", "")
		for _, attribute in ipairs({ "DamageMult", "DamageTakenMult", "SpeedMult" }) do
			model:SetAttribute(attribute, nil)
		end
		model:SetAttribute("Anim", "Collapse")
		model:SetAttribute("AnimT0", now())
		Net.fireAllClients("Shift_Effect", { kind = "Revert", position = titanRoot.Position, userId = player.UserId })
		task.wait(ShifterConfig.collapse)
	end

	-- Out of the nape, onto the ground behind it.
	local character, humanoid = characterParts(player)
	if character and model then
		local weld = model.PilotSeat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
		setMassless(character, false)
	end
	if model then
		model:SetAttribute("Pilot", 0)
		if titanRoot then
			titanRoot.Anchored = true
			titanRoot.CanCollide = false
		end
	end
	if character and titanRoot then
		RunService.Heartbeat:Wait() -- a move in the same frame as leaving the seat is overridden by the client
		RunService.Heartbeat:Wait()
		local behind = (titanRoot.CFrame * CFrame.new(0, 0, ShifterConfig.exitBehind)).Position
		local ground = groundBelow(Vector3.new(behind.X, titanRoot.Position.Y, behind.Z)) or groundBelow(titanRoot.Position) or behind
		local face = titanRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local root = character:FindFirstChild("HumanoidRootPart")
		local lift = humanoid.HipHeight + (if root then root.Size.Y / 2 else 1)
		character:PivotTo(CFrame.lookAt(ground, ground + (if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis)) + Vector3.new(0, lift, 0))
	end
	if model then
		if instant then
			model:Destroy()
		else
			model:SetAttribute("Fading", now()) -- each client fades it into the steam
			task.delay(ShifterConfig.fade + 0.1, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end
	end
	entries[player] = nil
	cooldownUntil[player] = os.clock() + ShifterConfig.cooldown
	if player.Parent then
		player:SetAttribute("Shifted", nil)
		CharacterService.setControlLocked(player, false)
	end
	Log.info(TAG, "%s back in human form%s%s", player.Name, if instant then " (at once)" else "", if reason then " (" .. reason .. ")" else "")
end

-- A load (SequenceService) starts clean: back at once, and the story's leave to shift is taken back.
function ShifterService.reset(player)
	ShifterService.revert(player, true)
	ShifterService.setAllowed(player, false)
end

----------------------------------------------------------------------------------------------------------------
-- Specials
----------------------------------------------------------------------------------------------------------------
local function unlockedSpecials(player)
	local list = {}
	for _, name in ipairs(SPECIALS.order) do
		if FlagService.has(player, SPECIALS[name].flag) then
			table.insert(list, name)
		end
	end
	return list
end

-- The active buffs set the rig's multipliers (CombatService and FrameController read them).
local function applyBuffs(entry)
	local model = entry.model
	if not model then
		return
	end
	local dealt, taken, speed = 1, 1, 1
	local t = now()
	for name, untilT in pairs(entry.buffs) do
		if untilT > t then
			local spec = SPECIALS[name]
			dealt *= spec.damageDealt or 1
			taken *= spec.damageTaken or 1
			speed *= spec.speed or 1
		else
			entry.buffs[name] = nil
			model:SetAttribute(name .. "Until", nil)
		end
	end
	model:SetAttribute("DamageMult", if dealt ~= 1 then dealt else nil)
	model:SetAttribute("DamageTakenMult", if taken ~= 1 then taken else nil)
	model:SetAttribute("SpeedMult", if speed ~= 1 then speed else nil)
end

local function onSpecial(player, payload)
	local function deny(why)
		Net.fireClient(player, "Shift_Effect", { kind = "Denied", reason = why })
	end
	if type(payload.select) == "string" then
		local spec = SPECIALS[payload.select]
		if spec and FlagService.has(player, spec.flag) then
			player:SetAttribute("ShiftSpecial", payload.select)
		end
		return
	end
	if payload.use ~= true then
		return
	end
	local entry = entries[player]
	if not entry or entry.phase ~= "titan" or not entry.model then
		return deny("NotNow")
	end
	local name = player:GetAttribute("ShiftSpecial")
	local spec = name and SPECIALS[name]
	if not spec or not FlagService.has(player, spec.flag) then
		return deny("NoSpecial")
	end
	local model = entry.model
	local t = now()
	if model:GetAttribute("State") ~= "Idle" then
		return deny("Busy")
	elseif (entry.readyAt[name] or 0) > t then
		return deny("Cooldown")
	elseif ShifterService.getEnergy(player) < spec.cost then
		return deny("NoEnergy")
	end
	ShifterService.setEnergy(player, ShifterService.getEnergy(player) - spec.cost)
	entry.readyAt[name] = t + spec.cooldown
	entry.buffs[name] = t + spec.duration
	model:SetAttribute(name .. "ReadyAt", entry.readyAt[name])
	model:SetAttribute(name .. "Until", entry.buffs[name])
	applyBuffs(entry)
	-- The clip plays where it stands: no walking or fists until it is over.
	model:SetAttribute("State", "Special")
	FrameService.playAnim(model, spec.clip)
	task.delay(spec.clipTime, function()
		if model.Parent and model:GetAttribute("State") == "Special" then
			model:SetAttribute("State", "Idle")
		end
	end)
	Log.info(TAG, "%s used %s", player.Name, name)
end

local function syncAbility(player)
	player:SetAttribute("CanShift", if FlagService.has(player, ShifterConfig.FLAG) then true else nil)
	local unlocked = unlockedSpecials(player)
	player:SetAttribute("ShiftSpecials", if #unlocked > 0 then table.concat(unlocked, ",") else nil)
	local selected = player:GetAttribute("ShiftSpecial")
	if not (selected and table.find(unlocked, selected)) then
		player:SetAttribute("ShiftSpecial", unlocked[1])
	end
	if player:GetAttribute("ShiftEnergy") == nil then
		ShifterService.setEnergy(player, ShifterService.getEnergy(player))
	end
end

----------------------------------------------------------------------------------------------------------------
-- The running form: the meter, healing, buffs, the place
----------------------------------------------------------------------------------------------------------------
local function step(dt)
	local t = now()
	for _, player in ipairs(Players:GetPlayers()) do
		local entry = entries[player]
		if entry and entry.phase == "titan" then
			local model = entry.model
			if not (model and model.Parent and model.PrimaryPart) or model.PrimaryPart.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
				task.spawn(ShifterService.revert, player, true)
				continue
			end
			-- The meter runs down; empty, the form gives way.
			ShifterService.setEnergy(player, ShifterService.getEnergy(player) - ENERGY.drain * dt)
			if ShifterService.getEnergy(player) <= 0 then
				task.spawn(ShifterService.revert, player, false, "Drained")
				continue
			end
			-- It heals itself once nothing has hit it for a moment.
			local integrity, max = model:GetAttribute("Integrity") or 0, model:GetAttribute("IntegrityMax") or 1
			local healing = integrity < max and t - entry.lastHitAt >= ShifterConfig.titan.regenDelay
			if healing then
				FrameService.setIntegrity(model, integrity + ShifterConfig.titan.regen * dt)
			end
			model:SetAttribute("Regenerating", if healing then true else nil)
			applyBuffs(entry)
			-- Outside an allowed place it comes back after a grace.
			if inAllowedPlace(player) then
				entry.outsideSince = nil
			elseif not entry.outsideSince then
				entry.outsideSince = os.clock()
				Net.fireClient(player, "Shift_Effect", { kind = "Leaving", seconds = ShifterConfig.leaveGrace })
			elseif os.clock() - entry.outsideSince >= ShifterConfig.leaveGrace then
				task.spawn(ShifterService.revert, player, false, "Left")
			end
		elseif not entry and player:GetAttribute("CanShift") then
			-- In human form the meter refills by waiting.
			ShifterService.setEnergy(player, ShifterService.getEnergy(player) + ENERGY.regen * dt)
		end
	end
end

function ShifterService.Init()
	folder = workspace:FindFirstChild("Shifters") or Instance.new("Folder")
	folder.Name = "Shifters"
	folder.Parent = workspace
end

function ShifterService.Start()
	Net.on("Shift_Request", function(player)
		if entries[player] then
			if entries[player].phase == "titan" then
				task.spawn(ShifterService.revert, player)
			end
			return
		end
		task.spawn(function()
			local ok, reason = ShifterService.shift(player)
			if not ok then
				Net.fireClient(player, "Shift_Effect", { kind = "Denied", reason = reason })
			end
		end)
	end)
	Net.on("Shift_Special", onSpecial)
	PlayerDataService.Loaded:Connect(syncAbility)
	FlagService.Changed:Connect(function(player, flag)
		local isSpecial = false
		for _, name in ipairs(SPECIALS.order) do
			isSpecial = isSpecial or SPECIALS[name].flag == flag
		end
		if flag == ShifterConfig.FLAG or isSpecial then
			syncAbility(player)
			if flag == ShifterConfig.FLAG and not FlagService.has(player, flag) and entries[player] then
				task.spawn(ShifterService.revert, player, true)
			end
		end
	end)
	-- Damage the player deals (in a Frame or as the Titan) fills the meter.
	CombatService.HitLanded:Connect(function(hit)
		local player = hit.attacker
		if player and player:GetAttribute("CanShift") and (hit.damage or 0) > 0 then
			ShifterService.setEnergy(player, ShifterService.getEnergy(player) + hit.damage * ENERGY.perDamage)
		end
	end)
	CombatService.FrameHit:Connect(function(rig)
		local player = Players:GetPlayerByUserId(rig:GetAttribute("Rider") or 0)
		local entry = player and entries[player]
		if entry and entry.model == rig then
			entry.lastHitAt = now()
		end
	end)
	-- Out of integrity: the form gives way (it isn't disabled like a Frame).
	CombatService.RigSpent:Connect(function(rig)
		local player = Players:GetPlayerByUserId(rig:GetAttribute("Rider") or 0)
		if player and entries[player] and entries[player].model == rig then
			task.spawn(ShifterService.revert, player, false, "Spent")
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= TICK then
			step(accumulator)
			accumulator = 0
		end
	end)
	local function watchCharacter(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				if entries[player] then
					ShifterService.revert(player, true)
				end
			end)
		end
	end
	local function watchPlayer(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
		syncAbility(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry and entry.model then
			entry.model:Destroy()
		end
		entries[player] = nil
		cooldownUntil[player] = nil
		energy[player] = nil
	end)
end

return ShifterService
