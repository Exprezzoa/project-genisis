--!nonstrict
-- Client/Controllers/NPCAnimator.lua  (docs/08_rigs_and_animation.md §1.2, §4.6; docs/13 §6)
--
-- Animates every NPC in Workspace.Runtime.NPCs on this client: the default R15 idle, walk (AdjustSpeed =
-- speed / 14) and sit animations (Shared/Config/AnimationIds), then the gesture overlays multiplied onto the
-- joints' Transform in PreSimulation, after the Animator wrote them:
--   Gesture attribute   CrossArms / HandsBehindBack held, Inspect in 3 s loops; fades out while walking
--                       (HandsBehindBack stays: an officer strolling)
--   TalkFidget          shoulders and elbows, while that NPC's line is showing (DialogueController.Line)
--   LookAt              Neck 70% / Waist 30% toward the player's head while it talks to them or speaks nearby,
--                       or glances when the player passes close in front
-- It also turns the player's character toward the NPC they are talking to (player attribute TalkTarget).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationIds = require(Shared.Config.AnimationIds)

local DialogueController = require(script.Parent.DialogueController)

local NPCAnimator = {}

local RAD = math.rad
local WALK_REFERENCE = 14 -- docs/08 §1.2: AdjustSpeed = speed / 14
local MOVING = 0.5 -- studs/s: below this the NPC is standing
local BLEND = 4 -- gesture and fidget weights move this much per second
local LOOK = { yaw = RAD(60), pitch = RAD(30), smooth = 8, neck = 0.7, waist = 0.3 }
local GLANCE = 7 -- studs: an idle NPC glances at a player this close in front of it
local SPEAKER_RANGE = 40 -- a speaking NPC further away than this isn't the one talking
local TURN_RATE = 10 -- the player's turn toward their TalkTarget (per second, exponential)

-- Joint offsets in degrees {rx, ry, rz}, applied in Y-X-Z order (CFrame.fromEulerAnglesYXZ: raise, then swing about
-- the body's vertical axis). Inspect is docs/08 §4.6 as written. CrossArms and HandsBehindBack are fitted to this
-- R15 rig (D-082): the doc's values, in any sign or order reading, leave the hands at the sides; these put the
-- hands crossed in front of the chest and together behind the lower back.
local GESTURES = {
	CrossArms = {
		LeftShoulder = { 40, -35, 20 }, RightShoulder = { 50, 5, -40 },
		LeftElbow = { 50, -40, 0 }, RightElbow = { 45, 70, 0 },
	},
	HandsBehindBack = {
		LeftShoulder = { -20, -20, 40 }, RightShoulder = { -20, 20, -40 },
		LeftElbow = { 10, -60, 0 }, RightElbow = { 10, 60, 0 },
	},
	Inspect = { Waist = { -20, 0, 0 }, RightShoulder = { 70, 0, 0 } },
}
local INSPECT_PERIOD = 3
local FIDGET_JOINTS = { "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow" }
local JOINTS = { -- motor name -> the part that holds it (R15)
	Neck = "Head", Waist = "UpperTorso",
	LeftShoulder = "LeftUpperArm", RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm", RightElbow = "RightLowerArm",
}

local npcs = {} -- [model] = state
local localPlayer = Players.LocalPlayer
local talk = { speaker = nil, radioSpeaker = nil, radioUntil = 0 }

local function approach(current: number, target: number, step: number): number
	if current < target then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 -> 1 in 0.5 s, held 1.5 s, back to 0 in 0.5 s, rest 0.5 s.
local function inspectWeight(t: number): number
	local phase = t % INSPECT_PERIOD
	if phase < 0.5 then
		return smoothstep(phase / 0.5)
	elseif phase < 2 then
		return 1
	elseif phase < 2.5 then
		return 1 - smoothstep((phase - 2) / 0.5)
	end
	return 0
end

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = true
	return track
end

local function add(model: Instance)
	if not model:IsA("Model") or npcs[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if not animator or not root or not model.Parent then
		return
	end
	local state = {
		model = model, humanoid = humanoid, root = root,
		tracks = {
			idle = loadTrack(animator, AnimationIds.Idle, Enum.AnimationPriority.Idle),
			walk = loadTrack(animator, AnimationIds.Walk, Enum.AnimationPriority.Movement),
			sit = loadTrack(animator, AnimationIds.Sit, Enum.AnimationPriority.Movement),
		},
		playing = nil, lastPos = root.Position, speed = 0,
		motors = {}, weights = {}, fidgetWeight = 0, fidget = {}, phase = math.random() * 10,
		lookYaw = 0, lookPitch = 0,
	}
	for motorName, partName in pairs(JOINTS) do
		local part = model:WaitForChild(partName, 5)
		state.motors[motorName] = part and part:FindFirstChild(motorName)
	end
	for _, joint in ipairs(FIDGET_JOINTS) do
		state.fidget[joint] = {
			amp = RAD(6 + math.random() * 6), freq = 0.5 + math.random() * 0.6, phase = math.random() * math.pi * 2,
		}
	end
	npcs[model] = state
end

local function play(state, name: string)
	if state.playing == name then
		return
	end
	if state.playing then
		state.tracks[state.playing]:Stop(0.25)
	end
	state.tracks[name]:Play(0.25)
	state.playing = name
end

local function currentSpeaker(): string?
	if talk.speaker then
		return talk.speaker
	end
	if talk.radioSpeaker and os.clock() < talk.radioUntil then
		return talk.radioSpeaker
	end
	return nil
end

local function playerHead(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("Head")
end

-- Heartbeat: which base animation plays, and the weights the overlays use.
local function step(dt: number)
	local head = playerHead()
	local speaker = currentSpeaker()
	for model, state in pairs(npcs) do
		if not model.Parent then
			npcs[model] = nil
			continue
		end
		local pos = state.root.Position
		local moved = Vector3.new(pos.X - state.lastPos.X, 0, pos.Z - state.lastPos.Z).Magnitude / math.max(dt, 1 / 240)
		state.lastPos = pos
		state.speed += (moved - state.speed) * math.min(1, dt * 10)
		local moving = state.speed > MOVING
		if state.humanoid.SeatPart then
			play(state, "sit")
		elseif moving then
			play(state, "walk")
			state.tracks.walk:AdjustSpeed(math.max(0.3, state.speed / WALK_REFERENCE))
		else
			play(state, "idle")
		end

		local gesture = model:GetAttribute("Gesture")
		for name in pairs(GESTURES) do
			local wanted = if name == gesture and (not moving or name == "HandsBehindBack") then 1 else 0
			state.weights[name] = approach(state.weights[name] or 0, wanted, BLEND * dt)
		end

		local near = head and (head.Position - pos).Magnitude or math.huge
		local speaking = speaker ~= nil and model:GetAttribute("Speaker") == speaker and near <= SPEAKER_RANGE
		state.fidgetWeight = approach(state.fidgetWeight, if speaking then 1 else 0, BLEND * dt)

		-- LookAt: talking to this player, speaking near them, or a glance when they pass close in front.
		local yaw, pitch = 0, 0
		if head then
			local talkingToMe = model:GetAttribute("TalkingTo") == localPlayer.UserId
			local local_ = state.root.CFrame:PointToObjectSpace(head.Position)
			local glance = near <= GLANCE and local_.Z < 0
			if talkingToMe or speaking or glance then
				local neck = state.motors.Neck
				local from = if neck and neck.Part0 then state.root.CFrame:PointToObjectSpace((neck.Part0.CFrame * neck.C0).Position) else Vector3.zero
				local d = local_ - from
				yaw = math.clamp(math.atan2(-d.X, -d.Z), -LOOK.yaw, LOOK.yaw)
				pitch = math.clamp(math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude), -LOOK.pitch, LOOK.pitch)
			end
		end
		local k = 1 - math.exp(-LOOK.smooth * dt)
		state.lookYaw += (yaw - state.lookYaw) * k
		state.lookPitch += (pitch - state.lookPitch) * k
	end
end

-- R15 joints here are AnimationConstraints (CreateHumanoidModelFromDescription); Transform works the same way.
local function offset(motor: Instance?, rx: number, ry: number, rz: number)
	if motor and (rx ~= 0 or ry ~= 0 or rz ~= 0) then
		motor.Transform = motor.Transform * CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	end
end

-- PreSimulation: the overlays on top of what the Animator wrote this frame.
local function overlay()
	local now = os.clock()
	for _, state in pairs(npcs) do
		local sum = {}
		local function addJoint(joint, rx, ry, rz, w)
			local s = sum[joint]
			if not s then
				s = { 0, 0, 0 }
				sum[joint] = s
			end
			s[1] += RAD(rx) * w
			s[2] += RAD(ry) * w
			s[3] += RAD(rz) * w
		end
		for name, joints in pairs(GESTURES) do
			local w = state.weights[name] or 0
			if name == "Inspect" then
				w *= inspectWeight(now + state.phase)
			end
			if w > 0.001 then
				for joint, angles in pairs(joints) do
					addJoint(joint, angles[1], angles[2], angles[3], w)
				end
			end
		end
		if state.fidgetWeight > 0.001 then
			for joint, f in pairs(state.fidget) do
				local wave = math.sin(now * f.freq * math.pi * 2 + f.phase) * f.amp
				local s = sum[joint] or { 0, 0, 0 }
				sum[joint] = s
				s[1] += wave * state.fidgetWeight
				if joint:find("Shoulder") then
					s[3] += wave * 0.5 * state.fidgetWeight
				end
			end
		end
		for joint, s in pairs(sum) do
			offset(state.motors[joint], s[1], s[2], s[3])
		end
		if math.abs(state.lookYaw) > 0.001 or math.abs(state.lookPitch) > 0.001 then
			offset(state.motors.Neck, state.lookPitch * LOOK.neck, state.lookYaw * LOOK.neck, 0)
			offset(state.motors.Waist, state.lookPitch * LOOK.waist, state.lookYaw * LOOK.waist, 0)
		end
	end
end

-- The player turns toward the NPC they are talking to (docs/05 S05), while their controls are locked.
local function facePartner(dt: number)
	local id = localPlayer:GetAttribute("TalkTarget")
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not id or not root or not humanoid or humanoid.SeatPart then
		return
	end
	local folder = workspace:FindFirstChild("Runtime") and workspace.Runtime:FindFirstChild("NPCs")
	local npc = folder and folder:FindFirstChild(id)
	local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
	if not npcRoot then
		return
	end
	local look = Vector3.new(npcRoot.Position.X - root.Position.X, 0, npcRoot.Position.Z - root.Position.Z)
	if look.Magnitude < 0.5 then
		return
	end
	local target = CFrame.lookAt(root.Position, root.Position + look)
	root.CFrame = root.CFrame:Lerp(target, 1 - math.exp(-TURN_RATE * dt))
end

function NPCAnimator.Init() end

function NPCAnimator.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Runtime"):WaitForChild("NPCs")
		for _, child in ipairs(folder:GetChildren()) do
			task.spawn(add, child)
		end
		folder.ChildAdded:Connect(function(child)
			task.spawn(add, child)
		end)
	end)
	DialogueController.Line:Connect(function(speaker, mode, seconds)
		if mode == "radio" then
			talk.radioSpeaker, talk.radioUntil = speaker, os.clock() + (seconds or 3)
		else
			talk.speaker = speaker
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
		facePartner(dt)
	end)
	RunService.PreSimulation:Connect(overlay)
end

return NPCAnimator
