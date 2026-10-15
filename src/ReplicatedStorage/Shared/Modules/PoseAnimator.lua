--!nonstrict
-- Shared/Modules/PoseAnimator.lua  (docs/08_rigs_and_animation.md §4)
--
-- The math of the Procedural Pose Animator. Pure: no services, no instances. The client AnimationController
-- feeds it time and speed and writes the result to Motor6D.Transform; PosePreview uses it in edit mode.
--
-- A pose is { [joint] = { rot = Vector3 (degrees), pos = Vector3 (studs) } }.
--
--   compile(poseSet) -> { rig, poses, clips, joints }   resolves named poses, fills inherited joints
--   sample(clip, t, out) -> out                          the clip's pose at time t (seconds)
--   weight(clip, t) -> 0..1                              action layer weight (blendIn / blendOut)
--   gaitParams(locomotion, speed, idleBelow, out) -> out, amplitude    blends idle -> walk -> stride by speed
--   gait(params, amplitude, phase, bladeArm, out) -> out the procedural step offsets at a phase (0..1)
--   compose(base, offsets, bob, action, w, upperBodyOnly, out) -> out
--                                                        base + offsets, replaced by action where it has joints
--   toCFrame(entry, scale?) -> CFrame                    CFrame.new(pos * scale) * CFrame.Angles(rad(rot))
--   crossed(events, t0, t1, fire)                        calls fire(name) for events in (t0, t1]

local Easing = require(script.Parent.Easing)

local PoseAnimator = {}

local ZERO = Vector3.zero

local function vector(list)
	return if list then Vector3.new(list[1], list[2], list[3]) else nil
end

local function toPose(source, poses)
	if type(source) == "string" then
		return poses[source] or error("PoseAnimator: unknown pose " .. source)
	end
	local pose = {}
	for joint, entry in pairs(source) do
		pose[joint] = { rot = vector(entry.rot), pos = vector(entry.pos) }
	end
	return pose
end

function PoseAnimator.compile(poseSet)
	local poses, clips, joints = {}, {}, {}
	for name, source in pairs(poseSet.poses) do
		poses[name] = toPose(source, poses)
		for joint, entry in pairs(poses[name]) do
			entry.rot, entry.pos = entry.rot or ZERO, entry.pos or ZERO
			joints[joint] = true
		end
	end
	for name, source in pairs(poseSet.clips) do
		-- Every key gets every joint the clip touches: a joint missing in a key keeps the previous key's value.
		-- A key that names a pose is a full pose: joints the pose doesn't list go back to rest.
		local current, keys = {}, {}
		for _, key in ipairs(source.keys) do
			if type(key.pose) == "string" then
				for joint in pairs(current) do
					current[joint] = { rot = ZERO, pos = ZERO }
				end
			end
			for joint, entry in pairs(toPose(key.pose, poses)) do
				local previous = current[joint]
				current[joint] = {
					rot = entry.rot or (previous and previous.rot) or ZERO,
					pos = entry.pos or (previous and previous.pos) or ZERO,
				}
				joints[joint] = true
			end
			table.insert(keys, { t = key.t, ease = Easing.get(key.ease or "Linear"), pose = table.clone(current) })
		end
		-- Joints that first appear in a later key rest at zero before it.
		for _, key in ipairs(keys) do
			for joint in pairs(current) do
				key.pose[joint] = key.pose[joint] or { rot = ZERO, pos = ZERO }
			end
		end
		clips[name] = {
			name = name,
			duration = source.duration,
			loop = source.loop == true,
			blendIn = source.blendIn or 0.08,
			blendOut = source.blendOut or 0.12,
			upperBodyOnly = source.upperBodyOnly == true,
			hold = source.hold == true, -- stays in its last key until another clip replaces it
			keys = keys,
			events = source.events or {},
		}
	end
	return { rig = poseSet.rig, poses = poses, clips = clips, joints = joints }
end

function PoseAnimator.sample(clip, t, out)
	out = out or {}
	local keys = clip.keys
	if clip.loop and clip.duration > 0 then
		t %= clip.duration
	end
	local last = keys[#keys]
	if t >= last.t or #keys == 1 then
		for joint, entry in pairs(last.pose) do
			out[joint] = entry
		end
		return out
	end
	local index = 1
	while keys[index + 1].t <= t do
		index += 1
	end
	local from, to = keys[index], keys[index + 1]
	if t <= from.t then
		for joint, entry in pairs(from.pose) do
			out[joint] = entry
		end
		return out
	end
	local alpha = to.ease((t - from.t) / (to.t - from.t))
	for joint, a in pairs(from.pose) do
		local b = to.pose[joint]
		out[joint] = { rot = a.rot:Lerp(b.rot, alpha), pos = a.pos:Lerp(b.pos, alpha) }
	end
	return out
end

function PoseAnimator.weight(clip, t)
	if clip.loop or clip.hold then
		return math.clamp(t / math.max(clip.blendIn, 1e-3), 0, 1)
	end
	local fadeIn = math.clamp(t / math.max(clip.blendIn, 1e-3), 0, 1)
	local fadeOut = math.clamp((clip.duration + clip.blendOut - t) / math.max(clip.blendOut, 1e-3), 0, 1)
	return math.min(fadeIn, fadeOut)
end

-- docs/08 §4.5 "Speed blend": below IDLE_BELOW idle; up to the walk speed the walk gait grows in; above it the
-- parameters blend from walk to stride. Returns the blended parameters and the gait amplitude (0..1).
local NUMBERS = { "stepLength", "hipSwing", "kneeBend", "ankle", "rootBob", "rootRoll", "waistYaw", "lean", "swingLift" }

function PoseAnimator.gaitParams(locomotion, speed, idleBelow, out)
	out = out or { armSwing = {} }
	local walk, stride = locomotion.walk, locomotion.stride
	local blend = math.clamp((speed - walk.speed) / (stride.speed - walk.speed), 0, 1)
	for _, key in ipairs(NUMBERS) do
		local from = walk[key] or 0 -- swingLift is optional
		out[key] = from + ((stride[key] or 0) - from) * blend
	end
	out.armSwing.other = walk.armSwing.other + (stride.armSwing.other - walk.armSwing.other) * blend
	out.armSwing.blade = walk.armSwing.blade + (stride.armSwing.blade - walk.armSwing.blade) * blend
	out.headStabilized = walk.headStabilized
	local amplitude = math.clamp((speed - idleBelow) / (walk.speed - idleBelow), 0, 1)
	return out, amplitude
end

-- The step at a phase: 0 and 0.5 are the footfalls (left foot forward at 0). Offsets are added to the idle pose.
function PoseAnimator.gait(params, amplitude, phase, bladeArm, out)
	out = out or {}
	local angle = phase * 2 * math.pi
	local cos, sin = math.cos(angle), math.sin(angle)
	local hip = params.hipSwing * cos * amplitude
	-- A leg bends its knee while it swings forward.
	local leftKnee = params.kneeBend * math.max(0, -sin) * amplitude
	local rightKnee = params.kneeBend * math.max(0, sin) * amplitude
	local leftArm = if bladeArm == "Left" then params.armSwing.blade else params.armSwing.other
	local rightArm = if bladeArm == "Right" then params.armSwing.blade else params.armSwing.other
	local yaw = params.waistYaw * cos * amplitude
	local lean = params.lean * amplitude
	out.LeftHip = Vector3.new(hip, 0, 0)
	out.RightHip = Vector3.new(-hip, 0, 0)
	out.LeftKnee = Vector3.new(leftKnee, 0, 0)
	out.RightKnee = Vector3.new(rightKnee, 0, 0)
	out.LeftAnkle = Vector3.new(params.ankle * leftKnee, 0, 0)
	out.RightAnkle = Vector3.new(params.ankle * rightKnee, 0, 0)
	-- A high step (the Watcher's careful walk): the swinging leg folds like a crouch, lifting the foot.
	local lift = params.swingLift or 0
	if lift ~= 0 then
		local leftLift, rightLift = lift * math.max(0, -sin) * amplitude, lift * math.max(0, sin) * amplitude
		out.LeftHip += Vector3.new(leftLift, 0, 0)
		out.RightHip += Vector3.new(rightLift, 0, 0)
		out.LeftKnee += Vector3.new(-2 * leftLift, 0, 0)
		out.RightKnee += Vector3.new(-2 * rightLift, 0, 0)
		out.LeftAnkle += Vector3.new(leftLift, 0, 0)
		out.RightAnkle += Vector3.new(rightLift, 0, 0)
	end
	out.LeftShoulder = Vector3.new(-leftArm * cos * amplitude, 0, 0)
	out.RightShoulder = Vector3.new(rightArm * cos * amplitude, 0, 0)
	out.Waist = Vector3.new(lean, -yaw, 0)
	out.Neck = if params.headStabilized then Vector3.new(-lean, yaw, 0) else ZERO
	out.Root = Vector3.new(0, 0, params.rootRoll * cos * amplitude)
	out.RootBob = -params.rootBob * amplitude * cos * cos -- studs; lowest at the footfalls
	return out
end

local LEGS = {
	LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true, LeftAnkle = true, RightAnkle = true, Root = true,
}

-- Locomotion (base pose + gait offsets) with the action laid over it at weight w. With upperBodyOnly the
-- action leaves the legs and the root to the gait: true = entirely, or a number 0..1 for the share the gait
-- keeps (so a swing's stance fades into the walk as the machine picks up speed instead of snapping).
function PoseAnimator.compose(base, offsets, bob, action, w, upperBodyOnly, out)
	out = out or {}
	local gaitShare = if upperBodyOnly == true then 1 elseif type(upperBodyOnly) == "number" then upperBodyOnly else 0
	for joint in pairs(out) do
		out[joint] = nil
	end
	for joint, entry in pairs(base) do
		out[joint] = { rot = entry.rot, pos = entry.pos }
	end
	if offsets then
		for joint, rot in pairs(offsets) do
			if joint ~= "RootBob" then
				local slot = out[joint]
				if slot then
					slot.rot += rot
				else
					out[joint] = { rot = rot, pos = ZERO }
				end
			end
		end
		local root = out.Root
		if not root then
			root = { rot = ZERO, pos = ZERO }
			out.Root = root
		end
		root.pos += Vector3.new(0, bob or offsets.RootBob or 0, 0)
	end
	if action and w > 0 then
		for joint, entry in pairs(action) do
			local weight = if LEGS[joint] then w * (1 - gaitShare) else w
			if weight > 0 then
				local slot = out[joint]
				if slot then
					slot.rot = slot.rot:Lerp(entry.rot, weight)
					slot.pos = slot.pos:Lerp(entry.pos, weight)
				else
					out[joint] = { rot = entry.rot * weight, pos = entry.pos * weight }
				end
			end
		end
	end
	return out
end

-- scale = the rig's scale: pose offsets are written for the unscaled rig (D-044).
function PoseAnimator.toCFrame(entry, scale)
	local rot = entry.rot
	return CFrame.new(entry.pos * (scale or 1)) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

function PoseAnimator.crossed(events, t0, t1, fire)
	for _, event in ipairs(events) do
		if event.t > t0 and event.t <= t1 then
			fire(event.name)
		end
	end
end

return PoseAnimator
