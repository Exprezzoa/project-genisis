--!nonstrict
-- Client/Controllers/AnimationController.lua  (docs/08_rigs_and_animation.md §4.3-4.5, §7)
--
-- Runs the Procedural Pose Animator for every giant rig: each frame (PreSimulation) it writes
-- Motor6D.Transform = locomotion (idle + procedural gait from the root's speed) with the action clip laid over
-- it, plus the additive layer (breathing, head look, the cockpit hatch).
--
-- What a rig does comes from the server as attributes on its Model: Anim (clip name or ""), AnimT0
-- (workspace:GetServerTimeNow() at the start), AnimSpeed, LookTarget (Vector3), HatchOpen. The pilot's client may start
-- a clip ahead of the server (playLocal); when the server's attributes arrive, the clip adopts the server's
-- start time if it is within ADOPT seconds, otherwise it restarts with a short blend.
--
-- Rigs register themselves through the tag "PoseRig" (the Model needs the attribute Class = its pose set).
--
--   register(rig)   unregister(rig)   playLocal(rig, clipName)   cancelLocal(rig)   hitstop(rig, seconds)
--   getState(rig) -> { clip, time, weight, phase, speed, amplitude }      -- for tests
--   Event:    Signal(rig, clipName, eventName)     clip events (visual only)
--   Footfall: Signal(rig, side, speed)             "Left" / "Right" foot comes down

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local Locomotion = require(Shared.Config.Locomotion)
local Log = require(Shared.Modules.Log)
local PoseAnimator = require(Shared.Modules.PoseAnimator)
local Signal = require(Shared.Modules.Signal)

local TAG = "AnimationController"
local RIG_TAG = "PoseRig"

local AnimationController = {}

AnimationController.Event = Signal.new()
AnimationController.Footfall = Signal.new()

AnimationController.ADOPT = 0.15 -- a predicted clip adopts the server's start time within this many seconds
AnimationController.SNAP_BLEND = 0.08 -- otherwise it restarts and blends over this long
AnimationController.CANCEL_BLEND = 0.1 -- a rejected prediction fades out over this long
AnimationController.LOD = { full = 600, slow = 1200, slowRate = 10 } -- studs; beyond slow the rig freezes
AnimationController.BREATH = { degrees = 1.5, rate = 0.25 } -- Waist X
AnimationController.LOOK = { yaw = 60, pitch = 30, smoothing = 8 }
AnimationController.AMPLITUDE_RATE = 6 -- how fast the gait grows and dies down (1/s)
AnimationController.LEGS_TO_GAIT = 0.5 -- gait amplitude at which a swing's legs are entirely the walk's

local sets = {} -- [class] = compiled pose set
local rigs = {} -- [model] = state

local function now()
	return workspace:GetServerTimeNow()
end

local function poseSet(class)
	if not sets[class] then
		local source = Shared.Poses:FindFirstChild(class)
		if not source then
			return nil
		end
		sets[class] = PoseAnimator.compile(require(source))
	end
	return sets[class]
end

-- Starts a clip on the action layer, cross-fading from whatever the layer showed.
local function start(state, clipName, t0, speed, source, blend)
	local clip = state.set.clips[clipName]
	if not clip then
		Log.warn(TAG, "%s has no clip %s", state.model.Name, tostring(clipName))
		return
	end
	state.from = if state.weight > 0 and state.action then table.clone(state.action) else nil
	state.fromWeight = state.weight
	state.crossfade = blend or clip.blendIn
	state.clip, state.t0, state.rate, state.source = clip, t0, speed or 1, source
	state.lastT = 0
	state.cancelAt = nil
end

local function readServer(state)
	local model = state.model
	local name, t0 = model:GetAttribute("Anim"), model:GetAttribute("AnimT0")
	if type(name) ~= "string" or name == "" or type(t0) ~= "number" then
		if state.source == "server" then
			state.clip = nil
		end
		return
	end
	if state.serverName == name and state.serverT0 == t0 then
		return
	end
	state.serverName, state.serverT0 = name, t0
	local speed = model:GetAttribute("AnimSpeed") or 1
	if state.clip and state.source == "local" and state.clip.name == name then
		-- The server confirmed the predicted clip.
		if math.abs(t0 - state.t0) < AnimationController.ADOPT then
			state.t0, state.source = t0, "server"
		else
			start(state, name, t0, speed, "server", AnimationController.SNAP_BLEND)
		end
		return
	end
	start(state, name, t0, speed, "server")
end

function AnimationController.register(model)
	if rigs[model] then
		return
	end
	local class = model:GetAttribute("Class")
	local set = class and poseSet(class)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if set and not root then
		-- A rig spawned during play: its tag can arrive before its parts. Wait for the root, then try again.
		task.spawn(function()
			if model:WaitForChild("HumanoidRootPart", 10) and model.Parent and not rigs[model] then
				AnimationController.register(model)
			elseif model.Parent and not rigs[model] then
				Log.warn(TAG, "can't animate %s: its root never arrived", model.Name)
			end
		end)
		return
	end
	if not set then
		Log.warn(TAG, "can't animate %s: no pose set for class %s", model.Name, tostring(class))
		return
	end
	-- A giant rig never falls over or gets up; this has to be switched off on every client too (D-046).
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and FrameConfig[class] then
		for _, name in ipairs(FrameConfig.DisabledStates) do
			humanoid:SetStateEnabled(Enum.HumanoidStateType[name], false)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	local motors = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local state = {
		model = model, root = root, set = set, motors = motors, loco = Locomotion[class],
		phase = 0, amplitude = 0, speed = 0, shuffle = 0, clock = 0, weight = 0, lookYaw = 0, lookPitch = 0,
		slowClock = 0, gaitParams = nil, offsets = {}, pose = {}, scale = model:GetScale(), hatch = 0, hatchSpec = FrameConfig[class] and FrameConfig[class].hatch,
	}
	rigs[model] = state
	state.connections = {
		model:GetAttributeChangedSignal("Anim"):Connect(function()
			readServer(state)
		end),
		model:GetAttributeChangedSignal("AnimT0"):Connect(function()
			readServer(state)
		end),
		-- Joints can replicate after the Model itself.
		model.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Motor6D") then
				motors[descendant.Name] = descendant
			end
		end),
	}
	readServer(state)
end

function AnimationController.unregister(model)
	local state = rigs[model]
	if state then
		rigs[model] = nil
		for _, connection in ipairs(state.connections) do
			connection:Disconnect()
		end
	end
end

-- Prediction for the pilot: start the clip now; the server's attributes confirm or replace it.
function AnimationController.playLocal(model, clipName)
	local state = rigs[model]
	if state then
		start(state, clipName, now(), 1, "local")
	end
end

-- The server rejected the predicted action: fade it out.
function AnimationController.cancelLocal(model)
	local state = rigs[model]
	if state and state.clip and state.source == "local" then
		state.cancelAt = now()
	end
end

-- Freezes the rig's clip time for a moment (hit feel). Physics and the gait go on.
function AnimationController.hitstop(model, seconds)
	local state = rigs[model]
	if state then
		state.hitstop = math.max(state.hitstop or 0, seconds)
	end
end

function AnimationController.getState(model)
	local state = rigs[model]
	if not state then
		return nil
	end
	return {
		clip = state.clip and state.clip.name or "",
		source = state.source,
		time = state.lastT,
		weight = state.weight,
		phase = state.phase,
		speed = state.speed,
		amplitude = state.amplitude,
	}
end

local function step(state, dt)
	local root = state.root
	local loco = state.loco
	state.clock += dt

	-- Locomotion: the gait follows the distance travelled.
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	state.speed = speed
	local params, target = PoseAnimator.gaitParams(loco, speed, Locomotion.IDLE_BELOW, state.gaitParams)
	state.gaitParams = params
	state.amplitude += (target - state.amplitude) * (1 - math.exp(-AnimationController.AMPLITUDE_RATE * dt))
	local previous = state.phase
	if speed >= Locomotion.IDLE_BELOW then
		state.phase = (previous + speed * dt / (2 * params.stepLength)) % 1
		if state.amplitude > 0.2 then
			if state.phase < previous then
				AnimationController.Footfall:Fire(state.model, "Left", speed)
			elseif previous < 0.5 and state.phase >= 0.5 then
				AnimationController.Footfall:Fire(state.model, "Right", speed)
			end
		end
	end
	local offsets = PoseAnimator.gait(params, state.amplitude, state.phase, loco.bladeArm, state.offsets)
	-- Turning on the spot: a small shuffle of the feet.
	local shuffle = Locomotion.TURN_SHUFFLE
	if speed < shuffle.maxSpeed and math.abs(math.deg(root.AssemblyAngularVelocity.Y)) > shuffle.yawRate then
		state.shuffle = (state.shuffle + dt / (2 * shuffle.interval)) % 1
		local swing = math.sin(state.shuffle * 2 * math.pi)
		offsets.LeftHip += Vector3.new(4 * math.max(0, swing), shuffle.hipYaw * swing, 0)
		offsets.RightHip += Vector3.new(4 * math.max(0, -swing), -shuffle.hipYaw * swing, 0)
		offsets.LeftKnee += Vector3.new(-8 * math.max(0, swing), 0, 0)
		offsets.RightKnee += Vector3.new(-8 * math.max(0, -swing), 0, 0)
	end

	-- Action layer.
	local action, weight, upperBodyOnly = nil, 0, false
	local clip = state.clip
	if clip then
		if state.hitstop and state.hitstop > 0 then
			state.hitstop -= dt
			state.t0 += dt
		end
		local t = math.max(0, (now() - state.t0) * state.rate)
		PoseAnimator.crossed(clip.events, state.lastT, t, function(name)
			AnimationController.Event:Fire(state.model, clip.name, name)
		end)
		state.lastT = t
		action = PoseAnimator.sample(clip, t, {})
		weight = PoseAnimator.weight(clip, t)
		if state.from then
			-- Cross-fade from what the layer showed when this clip started.
			local alpha = math.clamp(t / math.max(state.crossfade, 1e-3), 0, 1)
			if alpha >= 1 then
				state.from = nil
			else
				for joint, entry in pairs(state.from) do
					local to = action[joint]
					action[joint] = if to
						then { rot = entry.rot:Lerp(to.rot, alpha), pos = entry.pos:Lerp(to.pos, alpha) }
						else { rot = entry.rot * (1 - alpha), pos = entry.pos * (1 - alpha) }
				end
				weight = math.max(weight, state.fromWeight * (1 - alpha))
			end
		end
		if state.cancelAt then
			weight *= math.clamp(1 - (now() - state.cancelAt) / AnimationController.CANCEL_BLEND, 0, 1)
		end
		-- The legs go over from the clip's own stance to the walk as the gait grows in (no snap at one speed).
		upperBodyOnly = clip.upperBodyOnly and math.clamp(state.amplitude / AnimationController.LEGS_TO_GAIT, 0, 1)
		if weight <= 0 and t > clip.blendIn and not clip.loop and not clip.hold then
			state.clip = nil
		end
	end
	state.action, state.weight = action, weight

	local pose = PoseAnimator.compose(state.set.poses.Idle, offsets, nil, action, weight, upperBodyOnly, state.pose)

	-- Additive layer: breathing and the head look.
	local breath = AnimationController.BREATH
	local waist = pose.Waist
	if waist then
		waist.rot += Vector3.new(breath.degrees * math.sin(state.clock * breath.rate * 2 * math.pi), 0, 0)
	end
	local look = AnimationController.LOOK
	local lookTarget = state.model:GetAttribute("LookTarget")
	local yaw, pitch = 0, 0
	if typeof(lookTarget) == "Vector3" then
		local head = state.motors.Neck and state.motors.Neck.Part1
		if head then
			local localDirection = root.CFrame:VectorToObjectSpace(lookTarget - head.Position)
			yaw = math.clamp(math.deg(math.atan2(-localDirection.X, -localDirection.Z)), -look.yaw, look.yaw)
			pitch = math.clamp(math.deg(math.atan2(localDirection.Y, Vector2.new(localDirection.X, localDirection.Z).Magnitude)), -look.pitch, look.pitch)
		end
	end
	local smoothing = 1 - math.exp(-look.smoothing * dt)
	state.lookYaw += (yaw - state.lookYaw) * smoothing
	state.lookPitch += (pitch - state.lookPitch) * smoothing
	if pose.Neck and (math.abs(state.lookYaw) > 0.01 or math.abs(state.lookPitch) > 0.01) then
		pose.Neck.rot += Vector3.new(state.lookPitch, state.lookYaw, 0)
	end

	-- The cockpit hatch swings open and shut at a steady rate (docs/09 §6).
	local hatchSpec = state.hatchSpec
	if hatchSpec then
		local goal = if state.model:GetAttribute("HatchOpen") then hatchSpec.openAngle else 0
		local stepSize = math.abs(hatchSpec.openAngle) / hatchSpec.time * dt
		state.hatch += math.clamp(goal - state.hatch, -stepSize, stepSize)
		pose.HatchHinge = { rot = Vector3.new(state.hatch, 0, 0), pos = Vector3.zero }
	end

	for name, motor in pairs(state.motors) do
		local entry = pose[name]
		motor.Transform = if entry then PoseAnimator.toCFrame(entry, state.scale) else CFrame.identity
	end
end

local function update(dt)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local lod = AnimationController.LOD
	for model, state in pairs(rigs) do
		if not model:IsDescendantOf(workspace) then
			continue
		end
		local distance = if eye then (state.root.Position - eye).Magnitude else 0
		if distance > lod.slow then
			continue
		elseif distance > lod.full then
			state.slowClock += dt
			if state.slowClock < 1 / lod.slowRate then
				continue
			end
			dt, state.slowClock = state.slowClock, 0
		end
		step(state, dt)
	end
end

function AnimationController.Init()
	CollectionService:GetInstanceAddedSignal(RIG_TAG):Connect(AnimationController.register)
	CollectionService:GetInstanceRemovedSignal(RIG_TAG):Connect(AnimationController.unregister)
	for _, model in ipairs(CollectionService:GetTagged(RIG_TAG)) do
		AnimationController.register(model)
	end
end

function AnimationController.Start()
	RunService.PreSimulation:Connect(update)
end

return AnimationController
