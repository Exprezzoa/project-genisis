--!nonstrict
-- Server/Services/ShifterService.lua  (docs/02 §8, docs/06 §6 "Shifter transformation", docs/10; D-095)
--
-- Elias shifting into his Titan form and back. The client asks (Shift_Request, after the player held Z for
-- ShifterConfig.hold); the server decides. To shift he needs the ability (flag CAN_SHIFT) and a place that allows
-- it: the Training Yard, or a story step that says so ({ "shifting", allowed = true } sets the player attribute
-- ShiftAllowed). He must be on foot and free (no Frame, conversation, cinematic or locked controls).
--
-- Shift: every client draws the yellow bolt (Shift_Effect "Shift"); under the white flash the Titan
-- (Templates.Titans.Shifter_Elias) stands where he was, he sits hidden in its nape, and his client rides it like
-- a Frame (the Titan sits in workspace.Shifters with Pilot = his UserId; FrameController and CameraController
-- take it). Back: it sinks to one knee in steam (Shift_Effect "Revert"), he comes out behind it, it fades.
-- A Titan outside an allowed place for ShifterConfig.leaveGrace seconds comes back by itself; a load, a death or
-- leaving brings it back at once.
--
--   isShifted(player) -> boolean     canShift(player) -> boolean, reason?     setAllowed(player, on)
--   shift(player) -> boolean, reason?     revert(player, instant?)     reset(player)  (a load: back at once, story leave cleared)

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
local DialogueService = require(script.Parent.DialogueService)
local FlagService = require(script.Parent.FlagService)
local FrameService = require(script.Parent.FrameService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneService = require(script.Parent.ZoneService)

local TAG = "ShifterService"

local ShifterService = {}

local entries = {} -- [player] = { phase = "shifting" | "titan" | "reverting", model, outsideSince }
local cooldownUntil = {} -- [player] = os.clock()
local folder

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
	local character, humanoid, root = characterParts(player)
	local ground = groundBelow(root.Position) or (root.Position - Vector3.new(0, 3, 0))
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local entry = { phase = "shifting" }
	entries[player] = entry
	player:SetAttribute("Shifted", true)
	CharacterService.setControlLocked(player, true)
	-- The bolt on every client; the swap happens under the white.
	Net.fireAllClients("Shift_Effect", { kind = "Shift", position = ground, userId = player.UserId })
	task.wait(ShifterConfig.swapAt)
	character, humanoid, root = characterParts(player)
	if not character or entries[player] ~= entry then
		if entries[player] == entry then
			entries[player] = nil
			player:SetAttribute("Shifted", nil)
		end
		CharacterService.setControlLocked(player, false)
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
	model:SetAttribute("AnimT0", workspace:GetServerTimeNow())
	model:SetAttribute("Rider", player.UserId)
	model:AddTag("PoseRig")
	model.Parent = folder
	titanRoot.Anchored = false
	titanHumanoid:ChangeState(Enum.HumanoidStateType.Running)

	-- Elias sits in the nape; his client rides the Titan from here (FrameController).
	setMassless(character, true)
	model.PilotSeat:Sit(humanoid)
	titanRoot:SetNetworkOwner(player)
	titanRoot.Facing.CFrame = titanRoot.CFrame.Rotation
	titanRoot.Facing.Enabled = true
	model:SetAttribute("Pilot", player.UserId)
	entry.model = model
	Log.info(TAG, "%s shifted (%s)", player.Name, tostring(ZoneService.getZone(player)))

	task.wait(ShifterConfig.emerge)
	if entries[player] == entry and model.Parent then
		model:SetAttribute("State", "Idle")
		entry.phase = "titan"
		CharacterService.setControlLocked(player, false)
	end
	return true, nil
end

-- Back to human form: it sinks to one knee in steam and he comes out behind it; instant = at once (a load, a
-- death, leaving the game).
function ShifterService.revert(player, instant: boolean?)
	local entry = entries[player]
	if not entry or entry.phase == "reverting" then
		return
	end
	local wasShifting = entry.phase == "shifting"
	entry.phase = "reverting"
	local model = entry.model
	local titanRoot = model and model.PrimaryPart
	if model and titanRoot and not instant and not wasShifting then
		CharacterService.setControlLocked(player, true)
		model:SetAttribute("State", "Starting") -- no walking
		model:SetAttribute("Anim", "Collapse")
		model:SetAttribute("AnimT0", workspace:GetServerTimeNow())
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
			model:SetAttribute("Fading", workspace:GetServerTimeNow()) -- each client fades it into the steam
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
	Log.info(TAG, "%s back in human form%s", player.Name, if instant then " (at once)" else "")
end

-- A load (SequenceService) starts clean: back at once, and the story's leave to shift is taken back.
function ShifterService.reset(player)
	ShifterService.revert(player, true)
	ShifterService.setAllowed(player, false)
end

local function syncAbility(player)
	player:SetAttribute("CanShift", if FlagService.has(player, ShifterConfig.FLAG) then true else nil)
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
	PlayerDataService.Loaded:Connect(syncAbility)
	FlagService.Changed:Connect(function(player, flag)
		if flag == ShifterConfig.FLAG then
			syncAbility(player)
			if not FlagService.has(player, flag) and entries[player] then
				task.spawn(ShifterService.revert, player, true)
			end
		end
	end)
	-- A Titan outside an allowed place comes back after a grace; a lost Titan (fell out of the world) at once.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		for player, entry in pairs(entries) do
			if entry.phase == "titan" then
				local model = entry.model
				if not (model and model.Parent and model.PrimaryPart) or model.PrimaryPart.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
					task.spawn(ShifterService.revert, player, true)
				elseif inAllowedPlace(player) then
					entry.outsideSince = nil
				elseif not entry.outsideSince then
					entry.outsideSince = os.clock()
					Net.fireClient(player, "Shift_Effect", { kind = "Leaving", seconds = ShifterConfig.leaveGrace })
				elseif os.clock() - entry.outsideSince >= ShifterConfig.leaveGrace then
					task.spawn(ShifterService.revert, player)
				end
			end
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
	end)
end

return ShifterService
