--!nonstrict
-- Server/Services/FrameService.lua  (docs/16 §4, docs/09_frames.md, docs/08_rigs_and_animation.md §5.4)
--
-- Frames have a physical home: each unit of Config/FrameConfig.Units is cloned from its template and parked at
-- its bay marker when the server starts. This service owns boarding and dismounting, network ownership, the
-- Frame's published state and its energy. Actions (attacks, dodge) are run by CombatService on top of it.
--
-- Everything a client needs is an attribute on the Frame Model:
--   Unit, Class, Pilot (UserId or 0), State ("Parked" | "Idle" | "Kneeling" | action states), WeaponsLocked,
--   Integrity, IntegrityMax, DamageState, PlatesDetached, Energy, EnergyMax, Anim, AnimT0, AnimSpeed, HatchOpen, Booted
--
--   spawnFrame(unitId, spawnId?) -> Model      getFrame(unitId) -> Model?      getPiloted(player) -> Model?
--   board(player, frame) -> ok, reason         dismount(player, padId) -> ok, reason
--   park(player, exitCFrame, unitId?) -> ok    back to the bay, the pilot on foot (the end of a sortie, a hub load)
--   kneelAt(player, unitId, groundCFrame, exitCFrame)   kneeling at a pad, the pilot on foot (a load after a dismount)
--   playAnim(frame, clip, speed?)              setState(frame, state)
--   spendEnergy(frame, amount) -> boolean      setEnergy(frame, value)
--   adopt(player, rig)  unadopt(player)        a rig that isn't a unit (Elias's Titan form, ShifterService, D-096)
--                                              counts as the player's piloted one: combat, Titans, debug commands
--   Boarded(player, frame)   Dismounted(player, frame)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CharacterService = require(script.Parent.CharacterService)
local CinematicService = require(script.Parent.CinematicService)
local CollisionService = require(script.Parent.CollisionService)
local InteractionService = require(script.Parent.InteractionService)
local TriggerService = require(script.Parent.TriggerService)
local ZoneService = require(script.Parent.ZoneService)

local TAG = "FrameService"
local FOLDER = "Frames"
local DISABLED_STATES = FrameConfig.DisabledStates
local ENERGY_PUBLISH = 0.1 -- seconds between Energy attribute updates while it regenerates
-- Where the "Board Frame" prompt of a kneeling Frame sits, relative to the root: on the ground under the hand
-- the Kneel pose holds out. (Poses only exist on clients, so on the server the hand itself is still at rest.)
-- (14, -16, -18) on the 40-stud rig; the 64-stud rig's root is 30.4 up, so -27.4 is 3 studs above the ground.
local BOARD_POINT = CFrame.new(22.4, -27.4, -28.8)

local FrameService = {}

FrameService.Boarded = Signal.new()
FrameService.Dismounted = Signal.new()

local frames = {} -- [unitId] = Model
local piloted = {} -- [Player] = Model
local energy = {} -- [Model] = { value, lastSpend, published }
local busy = {} -- [Player] = true while a board or dismount transition runs
local adopted = {} -- [Model] = Player: a rig ridden by its own service's rules (adopt)
local registered = {} -- [unitId] = true once the unit's board prompts have a handler

local function now()
	return workspace:GetServerTimeNow()
end

local function configOf(frame)
	return FrameConfig[frame:GetAttribute("Class")]
end

function FrameService.playAnim(frame, clip, speed)
	frame:SetAttribute("AnimSpeed", speed or 1)
	frame:SetAttribute("Anim", clip)
	frame:SetAttribute("AnimT0", now())
end

function FrameService.setState(frame, state)
	frame:SetAttribute("State", state)
end

-- Stands a Frame on the ground at a spawn-style CFrame (debug commands; the pilot's client follows).
function FrameService.moveTo(frame, groundCFrame)
	local root = frame.PrimaryPart
	frame:PivotTo(groundCFrame * CFrame.new(0, configOf(frame).hipHeight + root.Size.Y / 2, 0))
	-- The pilot's client turns the Frame (and its camera) to this heading; MovedAt also tells the speed check
	-- this jump was the server's own.
	local look = groundCFrame.LookVector
	frame:SetAttribute("MovedYaw", math.atan2(-look.X, -look.Z))
	frame:SetAttribute("MovedAt", now())
	if frame:FindFirstChild("BoardPoint") then
		frame.BoardPoint.CFrame = root.CFrame * BOARD_POINT
	end
end

-- Integrity is the Frame's health (docs/09 §4-5). CombatService decides the damage; this only stores it.
-- The damage state follows from it (docs/09 §5): clients show the state and shed the plates themselves.
function FrameService.setIntegrity(frame, value)
	local config = configOf(frame)
	local max = frame:GetAttribute("IntegrityMax") or config.integrity
	local integrity = math.clamp(value, 0, max)
	frame:SetAttribute("Integrity", integrity)
	local states = config.damageStates
	local state = states[#states]
	if integrity > 0 then
		for _, candidate in ipairs(states) do
			if candidate.above >= 0 and integrity / max >= candidate.above then
				state = candidate
				break
			end
		end
	end
	frame:SetAttribute("PlatesDetached", state.plates)
	frame:SetAttribute("DamageState", state.name)
	return integrity
end

-- Every unit of FrameConfig.Units that exists right now, and every adopted rig (Titans fight those too).
function FrameService.getFrames()
	local list = {}
	for _, frame in pairs(frames) do
		if frame.Parent then
			table.insert(list, frame)
		end
	end
	for rig in pairs(adopted) do
		if rig.Parent then
			table.insert(list, rig)
		end
	end
	return list
end

function FrameService.getFrame(unitId)
	return frames[unitId]
end

function FrameService.getPiloted(player)
	return piloted[player]
end

function FrameService.setEnergy(frame, value)
	local entry = energy[frame]
	entry.value = math.clamp(value, 0, configOf(frame).energy.max)
	entry.published = now()
	frame:SetAttribute("Energy", entry.value)
end

-- Takes amount from the Frame's energy. Returns false (and takes nothing) when there isn't enough.
function FrameService.spendEnergy(frame, amount)
	local entry = energy[frame]
	if amount <= 0 or frame:GetAttribute("InfiniteEnergy") then
		return true
	end
	if entry.value < amount then
		return false
	end
	entry.lastSpend = now()
	FrameService.setEnergy(frame, entry.value - amount)
	return true
end

local function addPrompt(part, id, actionText, objectText, opts)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = opts.hold
	prompt.MaxActivationDistance = opts.dist
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = opts.enabled ~= false
	prompt.Parent = part
	part:SetAttribute("InteractId", id)
	part:SetAttribute("FrameOnly", opts.frameOnly == true)
	part:SetAttribute("OnFootOnly", opts.frameOnly ~= true)
	part:SetAttribute("Once", false)
	CollectionService:AddTag(part, "Interactable")
	return prompt
end

local function updateWeaponsLock(player)
	local frame = piloted[player]
	if frame then
		local zoneId = ZoneService.getZone(player)
		local zone = zoneId and ZoneService.getZoneInfo(zoneId)
		frame:SetAttribute("WeaponsLocked", zone == nil or zone.weapons ~= "Free")
	end
end

-- A rig that isn't a unit, ridden by the player under its own service's rules (Elias's Titan form: ShifterService
-- seats and unseats the rider itself). While adopted it is the player's piloted rig: CombatService fights with it,
-- Titans target it, the debug commands act on it. Its class entry in FrameConfig gives integrity and energy.
function FrameService.adopt(player, rig)
	local config = configOf(rig)
	piloted[player] = rig
	adopted[rig] = player
	energy[rig] = { value = config.energy.max, lastSpend = 0, published = now() }
	rig:SetAttribute("EnergyMax", config.energy.max)
	rig:SetAttribute("Energy", config.energy.max)
	rig:SetAttribute("IntegrityMax", config.integrity)
	FrameService.setIntegrity(rig, config.integrity)
	rig:SetAttribute("WeaponsLocked", true)
	updateWeaponsLock(player)
end

function FrameService.unadopt(player)
	local rig = piloted[player]
	if rig and adopted[rig] then
		piloted[player] = nil
		adopted[rig] = nil
		energy[rig] = nil
	end
end

-- Clones the unit's template and parks it (standing, anchored) at a spawn marker.
function FrameService.spawnFrame(unitId, spawnId)
	local unit = FrameConfig.Units[unitId] or error("FrameService: unknown unit " .. tostring(unitId), 2)
	local config = FrameConfig[unit.class]
	local template = ServerStorage.Templates.Frames:FindFirstChild(config.rig .. "_" .. unitId)
	if not template then
		error(("FrameService: no template %s_%s (run the rig builder)"):format(config.rig, unitId), 2)
	end
	local spawnCFrame = CharacterService.getSpawnCFrame(spawnId or unit.spawn)
	if not spawnCFrame then
		error("FrameService: no spawn point " .. tostring(spawnId or unit.spawn), 2)
	end
	if frames[unitId] then
		frames[unitId]:Destroy()
	end

	local frame = template:Clone()
	frame.Name = "Frame_" .. unitId
	local root = frame.PrimaryPart
	local humanoid = frame:FindFirstChildOfClass("Humanoid")
	for _, state in ipairs(DISABLED_STATES) do
		humanoid:SetStateEnabled(Enum.HumanoidStateType[state], false)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	-- A Humanoid switches collisions back on for its torso parts every frame, whatever CanCollide says, so every
	-- part except the root goes into the group that collides with nothing.
	CollisionService.assignModel(frame, "NoCollide")
	CollisionService.assign(root, "FrameRoot")
	root.Anchored = true
	frame:PivotTo(spawnCFrame * CFrame.new(0, config.hipHeight + root.Size.Y / 2, 0))

	frame:SetAttribute("Pilot", 0)
	frame:SetAttribute("State", "Parked")
	frame:SetAttribute("Standby", true) -- parked with nobody aboard: core vents dark, visor dim (D-092)
	frame:SetAttribute("WeaponsLocked", true)
	frame:SetAttribute("IntegrityMax", config.integrity)
	frame:SetAttribute("Integrity", config.integrity)
	frame:SetAttribute("PlatesDetached", 0)
	frame:SetAttribute("DamageState", config.damageStates[1].name)
	frame:SetAttribute("EnergyMax", config.energy.max)
	frame:SetAttribute("Energy", config.energy.max)
	frame:SetAttribute("Anim", "")
	frame:SetAttribute("AnimT0", 0)
	frame:SetAttribute("AnimSpeed", 1)
	frame:SetAttribute("HatchOpen", false)
	frame:SetAttribute("Booted", false)
	energy[frame] = { value = config.energy.max, lastSpend = 0, published = 0 }

	local folder = workspace:FindFirstChild(FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = workspace
	end
	frame.Parent = folder
	CollectionService:AddTag(frame, "PoseRig")
	frames[unitId] = frame

	-- Hatch prompt (map_02 §3) and the hand prompt used while the Frame kneels (docs/08 §5.4). They are added
	-- once the Frame is in Workspace: InteractionService only takes parts that are.
	local bay = string.match(unit.spawn, "FRAME_BAY(%d+)")
	local label = "Unit " .. unitId
	addPrompt(frame.Hatch, "INT_BOARD_BAY" .. (bay or unitId), "Board Frame", label, { hold = 1.0, dist = 8, enabled = unit.playable })
	local boardPoint = Instance.new("Part")
	boardPoint.Name = "BoardPoint"
	boardPoint.Size = Vector3.new(3, 3, 3)
	boardPoint.Transparency = 1
	boardPoint.Anchored = true
	boardPoint.CanCollide = false
	boardPoint.CanQuery = false
	boardPoint.CanTouch = false
	boardPoint.CFrame = root.CFrame * BOARD_POINT
	boardPoint.Parent = frame
	addPrompt(boardPoint, "INT_BOARD_HAND" .. unitId, "Board Frame", label, { hold = 0.8, dist = 12, enabled = false })

	-- Registered once per unit: a unit spawned again (parked after a sortie) keeps its prompt ids, and the
	-- handler boards whichever copy of the unit exists when the prompt is used.
	if unit.playable and not registered[unitId] then
		registered[unitId] = true
		for _, id in ipairs({ "INT_BOARD_BAY" .. (bay or unitId), "INT_BOARD_HAND" .. unitId }) do
			InteractionService.register(id, function(player)
				local current = frames[unitId]
				if not (current and current.Parent) then
					return
				end
				local ok, reason = FrameService.board(player, current)
				if not ok then
					Log.debug(TAG, "%s can't board Unit %s: %s", player.Name, unitId, tostring(reason))
				end
			end)
		end
	end
	return frame
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

local function setPrompt(frame, name, enabled)
	local part = if name == "Hatch" then frame.Hatch else frame.BoardPoint
	local unit = FrameConfig.Units[frame:GetAttribute("Unit")]
	part.Prompt.Enabled = enabled and unit.playable
end

-- docs/08 §5.4 "Mount". Yields for the fade and the boot or rise clip.
-- force = true skips the distance check (the /frame debug command).
function FrameService.board(player, frame, force)
	local config = configOf(frame)
	local character, humanoid, root = characterParts(player)
	if not character then
		return false, "no living character"
	end
	if busy[player] or piloted[player] then
		return false, "already boarding or piloting"
	end
	if frame:GetAttribute("Pilot") ~= 0 then
		return false, "occupied"
	end
	local kneeling = frame:GetAttribute("State") == "Kneeling"
	-- The first boarding of this Frame (docs/05 S08): a 2.2 s close-up, two taps, the hatch opens at 1.2 s, fade.
	local first = not kneeling and not force and not frame:GetAttribute("Booted") -- not on a load or /frame
	local promptPart = if kneeling then frame.BoardPoint else frame.Hatch
	if not force and (root.Position - promptPart.Position).Magnitude > config.boardDistance + promptPart.Prompt.MaxActivationDistance then
		return false, "too far"
	end
	busy[player] = true
	setPrompt(frame, "Hatch", false)
	setPrompt(frame, "Hand", false)
	frame:SetAttribute("HatchOpen", not kneeling and not first)
	if first then
		-- The pilot is marked only after the close-up: the client hides its pilot and takes the Frame's camera then.
		CinematicService.play(player, "CIN_HATCH_TAP", { block = false, params = { frame = frame } })
		task.wait(1.2)
		frame:SetAttribute("HatchOpen", true)
		task.wait(2.2 - 1.2 - FrameConfig.Fade)
	end
	frame:SetAttribute("Pilot", player.UserId)

	Net.fireClient(player, "Fade", { to = 1, duration = FrameConfig.Fade })
	task.wait(math.max(FrameConfig.Fade, if kneeling or first then 0 else config.hatch.time))
	character, humanoid, root = characterParts(player)
	if not character or not frame.Parent then
		frame:SetAttribute("Pilot", 0)
		frame:SetAttribute("HatchOpen", false)
		setPrompt(frame, if kneeling then "Hand" else "Hatch", true)
		busy[player] = nil
		Net.fireClient(player, "Fade", { to = 0, duration = FrameConfig.Fade })
		return false, "the character was lost"
	end

	local frameRoot = frame.PrimaryPart
	setMassless(character, true)
	frame.PilotSeat:Sit(humanoid)
	frameRoot.Anchored = false
	frameRoot:SetNetworkOwner(player)
	frameRoot.Facing.CFrame = frameRoot.CFrame.Rotation
	frameRoot.Facing.Enabled = true
	piloted[player] = frame
	frame:SetAttribute("HatchOpen", false)
	updateWeaponsLock(player)

	local clip = if kneeling then "RiseFromKneel" elseif frame:GetAttribute("Booted") then nil else "Boot"
	frame:SetAttribute("Booted", true)
	frame:SetAttribute("Standby", false) -- the pilot is aboard: its lights come on
	FrameService.setState(frame, "Starting")
	if clip then
		FrameService.playAnim(frame, clip)
	else
		frame:SetAttribute("Anim", "")
	end
	Net.fireClient(player, "Fade", { to = 0, duration = FrameConfig.Fade })
	FrameService.Boarded:Fire(player, frame)
	task.wait(if clip == "RiseFromKneel" then 1.0 elseif clip == "Boot" then 1.2 else FrameConfig.Fade)
	if piloted[player] == frame and frame:GetAttribute("State") == "Starting" then
		FrameService.setState(frame, "Idle")
	end
	busy[player] = nil
	Log.debug(TAG, "%s boarded Unit %s", player.Name, tostring(frame:GetAttribute("Unit")))
	return true
end

-- Puts the pilot back on foot at a CFrame and leaves the Frame kneeling and anchored where it stands, turned to
-- `facing` if given (a pad's direction).
local function release(player, frame, exitCFrame, facing)
	piloted[player] = nil
	local frameRoot = frame.PrimaryPart
	local character, humanoid, root = characterParts(player)
	if character then
		local weld = frame.PilotSeat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
		setMassless(character, false)
		if exitCFrame then
			-- A move made in the same frame as leaving the seat is overridden by the pilot's client.
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			character:PivotTo(exitCFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
		end
	end
	if frame.Parent then
		frameRoot.Facing.Enabled = false
		frameRoot:SetNetworkOwner(nil)
		frameRoot.AssemblyLinearVelocity = Vector3.zero
		frameRoot.AssemblyAngularVelocity = Vector3.zero
		frameRoot.Anchored = true
		if facing then
			local ahead = facing * Vector3.new(1, 0, 1)
			if ahead.Magnitude > 0.01 then
				frame:PivotTo(CFrame.lookAt(frameRoot.Position, frameRoot.Position + ahead.Unit))
			end
		end
		frame:SetAttribute("Pilot", 0)
		frame:SetAttribute("WeaponsLocked", true)
		FrameService.setState(frame, "Kneeling")
		FrameService.playAnim(frame, "KneelIdle")
		frame.BoardPoint.CFrame = frameRoot.CFrame * BOARD_POINT
		setPrompt(frame, "Hand", true)
	end
	FrameService.Dismounted:Fire(player, frame)
end

-- The sortie is over: the pilot is put on foot at exitCFrame and the unit stands parked in its bay again.
-- unitId parks that unit when nobody pilots it (a checkpoint that starts in the hub).
function FrameService.park(player, exitCFrame, unitId)
	local frame = piloted[player]
	if frame then
		unitId = frame:GetAttribute("Unit")
		release(player, frame, exitCFrame)
	end
	if unitId then
		FrameService.spawnFrame(unitId)
	end
	return frame ~= nil
end

-- A checkpoint that starts on foot after a dismount: the unit kneels at a pad's marker as if just left there, and
-- whoever piloted it is put on foot at exitCFrame first (docs/05 §11, M01_COMMS).
function FrameService.kneelAt(player, unitId, groundCFrame, exitCFrame)
	local frame = frames[unitId]
	if not (frame and frame.Parent) then
		frame = FrameService.spawnFrame(unitId)
	end
	if piloted[player] == frame then
		release(player, frame, exitCFrame)
	end
	if frame:GetAttribute("Pilot") ~= 0 then
		return false
	end
	frame.PrimaryPart.Anchored = true
	FrameService.moveTo(frame, groundCFrame)
	FrameService.setState(frame, "Kneeling")
	FrameService.playAnim(frame, "KneelIdle")
	frame.BoardPoint.CFrame = frame.PrimaryPart.CFrame * BOARD_POINT
	setPrompt(frame, "Hand", true)
	setPrompt(frame, "Hatch", false)
	return true
end

-- docs/08 §5.4 "Dismount (at a DismountPad)". Yields for the kneel and the fade.
function FrameService.dismount(player, padId)
	local frame = piloted[player]
	if not frame or busy[player] then
		return false, "not piloting"
	elseif adopted[frame] then
		return false, "not a Frame"
	end
	local pad = nil
	for _, candidate in ipairs(CollectionService:GetTagged("DismountPad")) do
		if candidate:GetAttribute("PadId") == padId then
			pad = candidate
		end
	end
	if not pad then
		return false, "unknown pad"
	end
	local frameRoot = frame.PrimaryPart
	local offset = frameRoot.Position - pad:GetAttribute("Center")
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > pad:GetAttribute("Radius") then
		return false, "outside the pad"
	end
	if frameRoot.AssemblyLinearVelocity.Magnitude >= FrameConfig.Dismount.maxSpeed then
		return false, "moving"
	end
	local state = frame:GetAttribute("State")
	if state ~= "Idle" then
		return false, "busy (" .. tostring(state) .. ")"
	end
	busy[player] = true
	FrameService.setState(frame, "Kneeling")
	FrameService.playAnim(frame, "Kneel")
	task.wait(FrameConfig.Dismount.fadeAt)
	Net.fireClient(player, "Fade", { to = 1, duration = FrameConfig.Fade })
	task.wait(math.max(FrameConfig.Fade, FrameConfig.Dismount.kneelTime - FrameConfig.Dismount.fadeAt))
	if piloted[player] == frame then
		-- It kneels facing the way the pad's exit point faces, so the pilot steps out at its right hand (docs/05 S23)
		-- and its board prompt is on the same side whichever way it drove in.
		release(player, frame, pad.ExitPoint.CFrame, pad.ExitPoint.CFrame.LookVector)
	end
	Net.fireClient(player, "Fade", { to = 0, duration = FrameConfig.Fade })
	busy[player] = nil
	Log.debug(TAG, "%s dismounted Unit %s at %s", player.Name, tostring(frame:GetAttribute("Unit")), padId)
	return true
end

-- Energy comes back at the class's regen rate once regenDelay has passed since the last spend.
local function regenerate(dt)
	local t = now()
	for frame, entry in pairs(energy) do
		if not frame.Parent then
			energy[frame] = nil
			continue
		end
		local config = configOf(frame).energy
		if entry.value < config.max and t - entry.lastSpend >= config.regenDelay then
			entry.value = math.min(config.max, entry.value + config.regen * dt)
			if entry.value >= config.max or t - entry.published >= ENERGY_PUBLISH then
				entry.published = t
				frame:SetAttribute("Energy", entry.value)
			end
		end
	end
end

function FrameService.Start()
	-- Park every unit in its bay. This runs in Start because the spawn markers are registered by
	-- CharacterService.Start and the prompts by InteractionService.Start, both earlier in the load order.
	for unitId in pairs(FrameConfig.Units) do
		local ok, problem = pcall(FrameService.spawnFrame, unitId)
		if not ok then
			Log.warn(TAG, "Unit %s wasn't parked: %s", unitId, tostring(problem))
		end
	end
	RunService.Heartbeat:Connect(regenerate)
	-- Triggers with who = "frame" test the root of the Frame the player pilots (docs/13 §5).
	TriggerService.setPointProvider("frame", function(player)
		local frame = piloted[player]
		local root = frame and frame.PrimaryPart
		return if root then root.Position else nil
	end)
	ZoneService.ZoneChanged:Connect(updateWeaponsLock)
	-- Dismount prompts: one Frame-scale prompt per pad.
	local function addPad(pad)
		local padId = pad:GetAttribute("PadId")
		local anchor = pad:FindFirstChild("ExitPoint")
		if type(padId) ~= "string" or not anchor or anchor:FindFirstChildOfClass("ProximityPrompt") then
			return
		end
		addPrompt(anchor, padId, "Dismount", "", { hold = 0.8, dist = GameConfig.Interaction.FRAME_PROMPT_DISTANCE, frameOnly = true })
		InteractionService.register(padId, function(player)
			local ok, reason = FrameService.dismount(player, padId)
			if not ok then
				Log.debug(TAG, "%s can't dismount at %s: %s", player.Name, padId, tostring(reason))
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("DismountPad"):Connect(addPad)
	for _, pad in ipairs(CollectionService:GetTagged("DismountPad")) do
		addPad(pad)
	end
	-- A pilot who leaves or loses the character leaves the Frame where it stands.
	local function abandon(player)
		local frame = piloted[player]
		if frame and adopted[frame] then
			FrameService.unadopt(player) -- its own service ends it (ShifterService: back to human form)
		elseif frame then
			release(player, frame, nil)
		end
		busy[player] = nil
	end
	Players.PlayerRemoving:Connect(abandon)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			abandon(player)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function()
			abandon(player)
		end)
	end
end

return FrameService
