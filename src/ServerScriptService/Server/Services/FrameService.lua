--!nonstrict
-- Server/Services/FrameService.lua  (docs/16 §4, docs/09_frames.md, docs/08_rigs_and_animation.md §5.4)
--
-- Frames have a physical home: each unit of Config/FrameConfig.Units is cloned from its template and parked at
-- its bay marker when the server starts. This service owns boarding and dismounting, network ownership, the
-- Frame's published state and its energy. Actions (attacks, dodge) are run by CombatService on top of it.
--
-- Everything a client needs is an attribute on the Frame Model:
--   Unit, Class, Pilot (UserId or 0), State ("Parked" | "Idle" | "Kneeling" | action states), WeaponsLocked,
--   Integrity, IntegrityMax, Energy, EnergyMax, Anim, AnimT0, AnimSpeed, HatchOpen, Booted
--
--   spawnFrame(unitId, spawnId?) -> Model      getFrame(unitId) -> Model?      getPiloted(player) -> Model?
--   board(player, frame) -> ok, reason         dismount(player, padId) -> ok, reason
--   playAnim(frame, clip, speed?)              setState(frame, state)
--   spendEnergy(frame, amount) -> boolean      setEnergy(frame, value)
--   Boarded(player, frame)   Dismounted(player, frame)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CharacterService = require(script.Parent.CharacterService)
local CollisionService = require(script.Parent.CollisionService)
local InteractionService = require(script.Parent.InteractionService)
local ZoneService = require(script.Parent.ZoneService)

local TAG = "FrameService"
local FOLDER = "Frames"
local DISABLED_STATES = { "Dead", "Ragdoll", "FallingDown", "Climbing", "Swimming", "Jumping" }
local ENERGY_PUBLISH = 0.1 -- seconds between Energy attribute updates while it regenerates
-- Where the "Board Frame" prompt of a kneeling Frame sits, relative to the root: on the ground under the hand
-- the Kneel pose holds out. (Poses only exist on clients, so on the server the hand itself is still at rest.)
local BOARD_POINT = CFrame.new(14, -16, -18)

local FrameService = {}

FrameService.Boarded = Signal.new()
FrameService.Dismounted = Signal.new()

local frames = {} -- [unitId] = Model
local piloted = {} -- [Player] = Model
local energy = {} -- [Model] = { value, lastSpend, published }
local busy = {} -- [Player] = true while a board or dismount transition runs

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
	if amount <= 0 then
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
	-- A Humanoid switches collisions back on for its torso parts every frame, whatever CanCollide says, so every
	-- part except the root goes into the group that collides with nothing.
	CollisionService.assignModel(frame, "NoCollide")
	CollisionService.assign(root, "FrameRoot")
	root.Anchored = true
	frame:PivotTo(spawnCFrame * CFrame.new(0, config.hipHeight + root.Size.Y / 2, 0))

	frame:SetAttribute("Pilot", 0)
	frame:SetAttribute("State", "Parked")
	frame:SetAttribute("WeaponsLocked", true)
	frame:SetAttribute("IntegrityMax", config.integrity)
	frame:SetAttribute("Integrity", config.integrity)
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

	if unit.playable then
		for _, id in ipairs({ "INT_BOARD_BAY" .. (bay or unitId), "INT_BOARD_HAND" .. unitId }) do
			InteractionService.register(id, function(player)
				local ok, reason = FrameService.board(player, frame)
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
function FrameService.board(player, frame)
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
	local promptPart = if kneeling then frame.BoardPoint else frame.Hatch
	if (root.Position - promptPart.Position).Magnitude > config.boardDistance + promptPart.Prompt.MaxActivationDistance then
		return false, "too far"
	end
	busy[player] = true
	frame:SetAttribute("Pilot", player.UserId)
	setPrompt(frame, "Hatch", false)
	setPrompt(frame, "Hand", false)
	frame:SetAttribute("HatchOpen", not kneeling)

	Net.fireClient(player, "Fade", { to = 1, duration = FrameConfig.Fade })
	task.wait(math.max(FrameConfig.Fade, if kneeling then 0 else config.hatch.time))
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

-- Puts the pilot back on foot at a CFrame and leaves the Frame kneeling and anchored where it stands.
local function release(player, frame, exitCFrame)
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
		frame:SetAttribute("Pilot", 0)
		frame:SetAttribute("WeaponsLocked", true)
		FrameService.setState(frame, "Kneeling")
		FrameService.playAnim(frame, "KneelIdle")
		frame.BoardPoint.CFrame = frameRoot.CFrame * BOARD_POINT
		setPrompt(frame, "Hand", true)
	end
	FrameService.Dismounted:Fire(player, frame)
end

-- docs/08 §5.4 "Dismount (at a DismountPad)". Yields for the kneel and the fade.
function FrameService.dismount(player, padId)
	local frame = piloted[player]
	if not frame or busy[player] then
		return false, "not piloting"
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
		release(player, frame, pad.ExitPoint.CFrame)
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
	ZoneService.ZoneChanged:Connect(updateWeaponsLock)
	-- Dismount prompts: one Frame-scale prompt per pad.
	local function addPad(pad)
		local padId = pad:GetAttribute("PadId")
		local anchor = pad:FindFirstChild("ExitPoint")
		if type(padId) ~= "string" or not anchor or anchor:FindFirstChildOfClass("ProximityPrompt") then
			return
		end
		addPrompt(anchor, padId, "Dismount", "", { hold = 0.8, dist = 30, frameOnly = true })
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
		if frame then
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
