--!nonstrict
-- Shared/Poses/Watcher.lua  (docs/08_rigs_and_animation.md §4.2, §5.3; docs/05 S31; D-091)
--
-- Poses and clips of the Watcher for the Procedural Pose Animator, in the convention of docs/08 §4.1 (+X swings a
-- hanging limb forward and leans the torso back, +Y turns left, +Z swings to the right). The rig is the user's
-- 80-stud Titan body (builders/rigs/Watcher): hips 31 studs up, thigh 12.7, shin and foot 18.2. docs/08 §5.3's
-- numbers were written for a 68-stud part rig, so the kneel is refitted to this body: the left knee rests on the
-- ground, the right foot stands flat, the right hand reaches the rover's roof (checked with PosePreview).
-- It never attacks; its clips are S31's: HeadTiltStudy, KneelReach, LiftCanister, RiseAndTurn.

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end
local function p(x, y, z)
	return { pos = { x, y, z } }
end

-- The legs are about 17 studs thick round the joints, so a knee on the ground has its joint 8.5 studs up.
local KNEEL = {
	Root = p(0, -13, 0), -- hips 18 up
	LeftHip = r(42), LeftKnee = r(-132), LeftAnkle = r(40), -- the knee down, the shin flat behind
	RightHip = r(90, 0, 15), RightKnee = r(-90), RightAnkle = r(0), -- the foot flat in front, the shin upright
	Waist = r(-60), Neck = r(45), -- bent over the rover, the head up to watch its hand
	RightShoulder = r(60, 0, -36), RightElbow = r(0), -- straight down into the opened side
	LeftShoulder = r(50, 0, 10), LeftElbow = r(20),
}
local function kneel(extra)
	local pose = table.clone(KNEEL)
	for joint, entry in pairs(extra or {}) do
		pose[joint] = entry
	end
	return pose
end

return {
	rig = "Watcher",
	poses = {
		-- Upright and still; the arms hang closer than the model's rest (its upper arms stand 34° out).
		Idle = {
			Waist = r(-4), LeftShoulder = r(3, 0, 14), RightShoulder = r(3, 0, -14), LeftElbow = r(8), RightElbow = r(8),
		},
		Kneel = KNEEL,
		-- The canister brought up toward its face.
		Lifted = kneel({ RightShoulder = r(80, 55, -10), RightElbow = r(112), Waist = r(-45), Neck = r(30) }),
	},
	clips = {
		Idle = { duration = 1, loop = true, keys = { { t = 0, pose = "Idle" } } },
		-- S31 beat 3: it studies Unit 02 with a slow tilt of the head.
		HeadTiltStudy = {
			duration = 2.0, blendIn = 0.3, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.60, ease = "SineInOut", pose = { Neck = r(0, 0, 18) } },
				{ t = 1.30, ease = "SineInOut", pose = { Neck = r(-5, 10, 10) } },
				{ t = 2.00, ease = "SineInOut", pose = "Idle" },
			},
		},
		-- S31 beat 5: down on one knee, the right hand reaching for the rover's roof. Held until the next clip.
		KneelReach = {
			duration = 3.0, blendIn = 0.3, blendOut = 0, hold = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 1.40, ease = "SineInOut", pose = kneel({ Root = p(0, -7, 0), LeftHip = r(30), LeftKnee = r(-80), LeftAnkle = r(30), RightHip = r(60, 0, 10), RightKnee = r(-70), Waist = r(-30), Neck = r(25), RightShoulder = r(30, 0, -15) }) },
				{ t = 3.00, ease = "SineInOut", pose = "Kneel" },
			},
		},
		-- The canister in its fingers, brought up toward its face (1.5 s), then held.
		LiftCanister = {
			duration = 1.5, blendIn = 0.1, blendOut = 0, hold = true,
			keys = {
				{ t = 0.00, pose = "Kneel" },
				{ t = 1.50, ease = "SineInOut", pose = "Lifted" },
			},
		},
		-- S31 beat 8: up from the kneel in 1.2 s; the server turns it round meanwhile (it stays at Idle to 2.0).
		RiseAndTurn = {
			duration = 2.0, blendIn = 0.1, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Lifted" },
				{ t = 1.20, ease = "SineInOut", pose = "Idle" },
				{ t = 2.00, pose = "Idle" },
			},
		},
	},
}
