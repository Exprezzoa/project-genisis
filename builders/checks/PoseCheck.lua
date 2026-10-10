--!nonstrict
-- builders/checks/PoseCheck.lua  ->  ServerStorage.DevTools.Checks.PoseCheck
-- (docs/19 §3 ConfigCheck, pose part; docs/08 §4-5)
--
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.PoseCheck:Clone()).Run())
--
--   * the Vanguard pose set compiles; every clip of docs/08 §5.1 exists; every joint it names is a joint of the rig;
--   * clip durations and HitboxStart/HitboxEnd events equal the CombatConfig timings (the config is the authority);
--   * PoseAnimator math: key sampling, inherited joints, named poses as full poses, weights, the gait at its
--     key phases, the speed blend, upperBodyOnly, and the rotation convention of docs/08 §4.1.

local Check = {}

local REQUIRED = {
	"Idle", "Boot", "Light1", "Light2", "Light3", "Heavy", "Special_PileDriver", "Dodge_F", "Dodge_B", "Dodge_L", "Dodge_R",
	"CoreStrike", "HitReact_Light", "HitReact_Heavy", "Kneel", "KneelIdle", "RiseFromKneel", "Disabled", "TapIdleHangar",
}

local function near(a, b)
	if typeof(a) == "Vector3" then
		return (a - b).Magnitude < 1e-3
	end
	return math.abs(a - b) < 1e-4
end

function Check.Run()
	local Shared = game:GetService("ReplicatedStorage").Shared:Clone()
	local PoseAnimator = require(Shared.Modules.PoseAnimator)
	local CombatConfig = require(Shared.Config.CombatConfig)
	local Locomotion = require(Shared.Config.Locomotion)
	local fails, passed = {}, 0
	local function expect(condition, message)
		if condition then
			passed += 1
		else
			table.insert(fails, message)
		end
	end

	local ok, set = pcall(PoseAnimator.compile, require(Shared.Poses.Vanguard))
	expect(ok, "compile failed: " .. tostring(set))
	if not ok then
		return { pass = false, fails = fails }
	end

	for _, name in ipairs(REQUIRED) do
		expect(set.clips[name] ~= nil, "clip missing: " .. name)
	end

	local template = game:GetService("ServerStorage").Templates.Frames:FindFirstChild("Vanguard_02")
	expect(template ~= nil, "template Vanguard_02 missing")
	if template then
		for joint in pairs(set.joints) do
			local motor = template:FindFirstChild(joint, true)
			expect(motor ~= nil and motor:IsA("Motor6D"), "pose joint isn't a joint of the rig: " .. joint)
		end
	end

	local function event(clip, name)
		for _, entry in ipairs(clip.events) do
			if entry.name == name then
				return entry.t
			end
		end
		return nil
	end
	for moveName, move in pairs(CombatConfig.Frames.Vanguard) do
		local clip = set.clips[move.clip]
		expect(clip ~= nil, moveName .. ": clip " .. move.clip .. " missing")
		if clip then
			expect(near(clip.duration, CombatConfig.total(move)), ("%s: clip lasts %.2f, the move %.2f"):format(moveName, clip.duration, CombatConfig.total(move)))
			expect(near(event(clip, "HitboxStart") or -1, move.startup), moveName .. ": HitboxStart isn't at the startup time")
			expect(near(event(clip, "HitboxEnd") or -1, move.startup + move.active), moveName .. ": HitboxEnd isn't at the end of the active window")
			expect(clip.keys[#clip.keys].t == clip.duration, moveName .. ": the last key isn't at the clip's end")
		end
	end
	local dodge = CombatConfig.Dodge.Vanguard
	for _, name in ipairs({ "Dodge_F", "Dodge_B", "Dodge_L", "Dodge_R" }) do
		expect(set.clips[name] and near(set.clips[name].duration, dodge.duration + dodge.settle), name .. ": duration differs from dodge + settle")
	end
	local core = CombatConfig.CoreStrike.Vanguard
	expect(near(set.clips.CoreStrike.duration, core.duration) and near(event(set.clips.CoreStrike, "Impact") or -1, core.impact), "CoreStrike: duration or Impact differ from the config")

	-- Sampling.
	local light1 = set.clips.Light1
	expect(near(PoseAnimator.sample(light1, 0).RightElbow.rot, Vector3.new(35, 0, 0)), "Light1 at 0 isn't the Idle pose")
	expect(near(PoseAnimator.sample(light1, 0.18).Waist.rot, Vector3.new(0, -35, 0)), "Light1 at 0.18 isn't the windup key")
	expect(near(PoseAnimator.sample(light1, 0.24).LeftShoulder.rot, Vector3.new(10, 0, -10)), "a joint missing in a key didn't keep the previous value")
	expect(near(PoseAnimator.sample(light1, 0.27).Waist.rot, Vector3.new(0, 22.5, 0)), "linear sampling between two keys is off")
	expect(near(PoseAnimator.sample(light1, 5).LeftShoulder.rot, Vector3.new(5, 0, -6)), "past its end a clip isn't in its last key")
	expect(near(PoseAnimator.sample(set.clips.Light3, 0.9).Root.pos, Vector3.zero), "a named pose key didn't reset the joints it doesn't list")
	expect(near(PoseAnimator.sample(set.clips.Light3, 0).LeftElbow.rot, Vector3.new(15, 0, 0)), "Light3 at 0 isn't Idle")
	expect(near(PoseAnimator.sample(set.clips.Special_PileDriver, 0.48).PileDriver.pos, Vector3.new(0, -6, 0)), "the spike isn't out during the thrust")
	expect(near(PoseAnimator.sample(set.clips.Idle, 7.3).Waist.rot, Vector3.new(-3, 0, 0)), "a looping clip doesn't wrap")

	-- Weights.
	expect(near(PoseAnimator.weight(light1, 0.03), 0.5), "blendIn weight")
	expect(near(PoseAnimator.weight(light1, 0.3), 1), "full weight in the middle")
	expect(near(PoseAnimator.weight(light1, 0.66), 0.5), "blendOut weight")
	expect(near(PoseAnimator.weight(light1, 1), 0), "weight after the blend out")
	expect(near(PoseAnimator.weight(set.clips.Disabled, 60), 1), "a hold clip lets go")
	expect(near(PoseAnimator.weight(set.clips.KneelIdle, 60), 1), "a loop clip lets go")

	-- Gait.
	local loco = Locomotion.Vanguard
	local params, amplitude = PoseAnimator.gaitParams(loco, loco.walk.speed, Locomotion.IDLE_BELOW)
	expect(near(amplitude, 1) and near(params.stepLength, loco.walk.stepLength) and near(params.hipSwing, 22), "walk speed doesn't give the walk gait")
	local stride, strideAmplitude = PoseAnimator.gaitParams(loco, loco.stride.speed, Locomotion.IDLE_BELOW)
	expect(near(strideAmplitude, 1) and near(stride.stepLength, loco.stride.stepLength) and near(stride.kneeBend, -55) and near(stride.armSwing.other, 16), "stride speed doesn't give the stride gait")
	local _, still = PoseAnimator.gaitParams(loco, 1, Locomotion.IDLE_BELOW)
	expect(near(still, 0), "below 2 studs/s the gait isn't off")
	local _, half = PoseAnimator.gaitParams(loco, (Locomotion.IDLE_BELOW + loco.walk.speed) / 2, Locomotion.IDLE_BELOW)
	expect(near(half, 0.5), "the gait doesn't grow linearly up to the walk speed")
	params = PoseAnimator.gaitParams(loco, loco.walk.speed, Locomotion.IDLE_BELOW)
	local step = PoseAnimator.gait(params, 1, 0, "Right")
	expect(near(step.LeftHip, Vector3.new(22, 0, 0)) and near(step.RightHip, Vector3.new(-22, 0, 0)), "phase 0 isn't the left footfall")
	expect(near(step.RootBob, -0.8) and near(step.LeftKnee, Vector3.zero), "the root isn't lowest at the footfall")
	expect(near(step.RightShoulder, Vector3.new(5, 0, 0)) and near(step.LeftShoulder, Vector3.new(-10, 0, 0)), "arm swing (blade arm 5, other 10) is off")
	expect(near(step.Waist, Vector3.new(-3, -5, 0)) and near(step.Neck, Vector3.new(3, 5, 0)), "waist counter-yaw, lean or head stabilization is off")
	step = PoseAnimator.gait(params, 1, 0.25, "Right")
	expect(near(step.RightKnee, Vector3.new(-35, 0, 0)) and near(step.RightAnkle, Vector3.new(17.5, 0, 0)) and near(step.LeftKnee, Vector3.zero), "knee bend on the swing or ankle compensation is off")
	expect(near(step.RootBob, 0), "the root isn't up between footfalls")
	step = PoseAnimator.gait(params, 1, 0.5, "Right")
	expect(near(step.RightHip, Vector3.new(22, 0, 0)), "phase 0.5 isn't the right footfall")

	-- Compose.
	local idle = set.poses.Idle
	local action = PoseAnimator.sample(set.clips.Special_PileDriver, 0.45)
	step = PoseAnimator.gait(params, 1, 0, "Right")
	local pose = PoseAnimator.compose(idle, step, nil, action, 1, true)
	expect(near(pose.LeftHip.rot, Vector3.new(22, 0, 0)), "upperBodyOnly: the action took the legs")
	expect(near(pose.Root.pos, Vector3.new(0, -0.8, 0)), "upperBodyOnly: the action took the root")
	expect(near(pose.LeftElbow.rot, Vector3.new(5, 0, 0)), "the action didn't replace an arm joint")
	pose = PoseAnimator.compose(idle, step, nil, action, 1, false)
	expect(near(pose.Root.pos, Vector3.new(0, -1, 0)), "a full-body action didn't take the root")
	pose = PoseAnimator.compose(idle, step, nil, nil, 0, false)
	expect(near(pose.RightShoulder.rot, Vector3.new(15, 0, 8)), "locomotion isn't idle plus the gait")
	expect(near(idle.RightShoulder.rot, Vector3.new(10, 0, 8)), "compose changed the base pose")

	-- Convention (docs/08 §4.1): +X swings a hanging limb forward (-Z), +Y turns left, +Z swings it to the right.
	local function turned(x, y, z, point)
		return PoseAnimator.toCFrame({ rot = Vector3.new(x, y, z), pos = Vector3.zero }) * point
	end
	expect(near(turned(90, 0, 0, Vector3.new(0, -1, 0)), Vector3.new(0, 0, -1)), "+X doesn't swing a hanging limb forward")
	expect(near(turned(0, 90, 0, Vector3.new(0, 0, -1)), Vector3.new(-1, 0, 0)), "+Y doesn't turn to the left")
	expect(near(turned(0, 0, 90, Vector3.new(0, -1, 0)), Vector3.new(1, 0, 0)), "+Z doesn't swing a hanging limb to the right")

	-- Events.
	local fired = {}
	PoseAnimator.crossed(light1.events, 0.16, 0.18, function(name)
		table.insert(fired, name)
	end)
	expect(#fired == 2 and fired[1] == "Whoosh" and fired[2] == "HitboxStart", "crossed() fired " .. table.concat(fired, ","))

	local shown = table.move(fails, 1, math.min(#fails, 20), 1, {})
	return { pass = #fails == 0, passed = passed, failCount = #fails, fails = shown }
end

return Check
