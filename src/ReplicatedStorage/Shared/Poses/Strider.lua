--!nonstrict
-- Shared/Poses/Strider.lua  (docs/08_rigs_and_animation.md §4.2, §5.2; timings = CombatConfig.TitanAttacks.Strider)
--
-- Poses and clips of the Strider for the Procedural Pose Animator. Rotations {rx, ry, rz} in degrees in the
-- convention of docs/08 §4.1 (+X swings a hanging limb forward and leans the torso back, +Y turns left, +Z
-- swings to the right); pos {x, y, z} in studs. The rig is the 56-stud body of builders/rigs/Strider (joint
-- names as on a Frame, plus CoreHingeL / CoreHingeR; it has no Jaw joint).
-- Events are visual only: TelegraphGlow, TelegraphEyes, Shockwave, RoarBlast, CoreOpen, CoreClose.

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end
local function p(x, y, z)
	return { pos = { x, y, z } }
end

-- A pose that drops the root needs the legs to fold, or the feet sink into the floor. crouch(a) bends hips,
-- knees and ankles by a degrees: the body sinks about 24 x (1 - cos a) studs (thigh and shin are 12 each).
local function crouch(angle, pose)
	for _, side in ipairs({ "Left", "Right" }) do
		pose[side .. "Hip"] = r(angle)
		pose[side .. "Knee"] = r(-2 * angle)
		pose[side .. "Ankle"] = r(angle)
	end
	return pose
end

-- On hands and knees, the back (and the core under its plates) turned up.
local DOWNED = {
	Root = p(0, -18, 0), LeftHip = r(100, 0, -15), RightHip = r(100, 0, 15), LeftKnee = r(-110), RightKnee = r(-110),
	Waist = r(-75), Neck = r(40), LeftShoulder = r(85, 0, -20), RightShoulder = r(85, 0, 20),
}
local function downed(extra)
	local pose = table.clone(DOWNED)
	for joint, entry in pairs(extra or {}) do
		pose[joint] = entry
	end
	return pose
end
local OPEN = { CoreHingeL = r(0, -100, 0), CoreHingeR = r(0, 100, 0) }

return {
	rig = "Strider",
	poses = {
		-- Hunched: the back leans forward, the head lifts to keep watching, the long arms hang.
		Idle = {
			Waist = r(-14), Neck = r(12), LeftShoulder = r(8, 0, -7), RightShoulder = r(8, 0, 7), LeftElbow = r(12), RightElbow = r(12),
			LeftHip = r(6), RightHip = r(6), LeftKnee = r(-10), RightKnee = r(-10), LeftAnkle = r(4), RightAnkle = r(4),
		},
		Downed = downed(OPEN),
	},
	clips = {
		Idle = { duration = 1, loop = true, keys = { { t = 0, pose = "Idle" } } },
		-- Before the fight (docs/05 S28): crouched with its hands on the ground, then it rises in 2.5 s.
		Dormant = { duration = 1, loop = true, blendIn = 0, keys = { { t = 0, pose = downed() } } },
		Rise = {
			duration = 2.5, blendIn = 0, blendOut = 0.25,
			keys = {
				{ t = 0.00, pose = downed() },
				{ t = 1.10, ease = "SineInOut", pose = crouch(55, { Root = p(0, -10, 0), Waist = r(-45), Neck = r(25), LeftShoulder = r(30, 0, -15), RightShoulder = r(30, 0, 15) }) },
				{ t = 2.50, ease = "QuadInOut", pose = "Idle" },
			},
		},

		-- The right arm pulls back across the body, then sweeps a wide arc at chest height.
		Sweep = {
			duration = 2.85, blendIn = 0.15, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 1.10, ease = "QuadOut", pose = { Waist = r(-8, -50, 0), RightShoulder = r(25, 0, 88), RightElbow = r(35), LeftShoulder = r(15, 0, -20), Neck = r(8, 30, 0) } },
				{ t = 1.28, ease = "Linear", pose = { Waist = r(-10, 0, 0), RightShoulder = r(82, 0, 25), RightElbow = r(8), Neck = r(8) } },
				{ t = 1.45, ease = "Linear", pose = { Waist = r(-10, 45, 0), RightShoulder = r(78, 0, -40), RightElbow = r(10), LeftShoulder = r(-15, 0, -12) } },
				{ t = 2.85, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.0, name = "TelegraphGlow" }, { t = 1.08, name = "Whoosh" } },
		},
		-- The right leg lifts high and comes down.
		Stomp = {
			duration = 2.65, blendIn = 0.15, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.90, ease = "QuadOut", pose = {
					RightHip = r(75), RightKnee = r(-80), RightAnkle = r(5), Waist = r(10), LeftShoulder = r(20, 0, -50), RightShoulder = r(20, 0, 50), Neck = r(-5),
				} },
				{ t = 1.05, ease = "QuadIn", pose = crouch(22, { Root = p(0, -1.8, 0), Waist = r(-20), LeftShoulder = r(10, 0, -25), RightShoulder = r(10, 0, 25) }) },
				{ t = 2.65, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.0, name = "TelegraphDisc" }, { t = 0.92, name = "Shockwave" } },
		},
		-- Crouches low, throws itself forward and lands on its hands, head low.
		Lunge = {
			duration = 4.0, blendIn = 0.15, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 1.30, ease = "QuadOut", pose = crouch(48, { Root = p(0, -8, 0), Waist = r(-40), LeftShoulder = r(-30, 0, -20), RightShoulder = r(-30, 0, 20), Neck = r(30) }) },
				{ t = 1.80, ease = "Linear", pose = crouch(40, { Root = p(0, -5.6, 0), Waist = r(-70), LeftShoulder = r(140, 0, -10), RightShoulder = r(140, 0, 10), Neck = r(35) }) },
				{ t = 2.10, ease = "QuadOut", pose = downed({ Root = p(0, -16, 0), Waist = r(-80), LeftShoulder = r(90, 0, -10), RightShoulder = r(90, 0, 10), Neck = r(15) }) },
				{ t = 3.40, ease = "Linear", pose = {} },
				{ t = 4.00, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.2, name = "TelegraphEyes" } },
		},
		-- Leans back and bellows (the sculpted head has no jaw to open).
		Roar = {
			duration = 2.1, blendIn = 0.12, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.60, ease = "QuadOut", pose = { Waist = r(20), Neck = r(35), LeftShoulder = r(10, 0, -60), RightShoulder = r(10, 0, 60), LeftElbow = r(30), RightElbow = r(30) } },
				{ t = 1.50, ease = "Linear", pose = { Waist = r(16), Neck = r(30) } },
				{ t = 2.10, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.6, name = "RoarBlast" } },
		},
		Flinch = {
			duration = 0.6, blendIn = 0.04, blendOut = 0.15,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.12, ease = "QuadOut", pose = { Waist = r(15, 10, 0), Neck = r(-10), LeftShoulder = r(-10, 0, -20), RightShoulder = r(-10, 0, 20) } },
				{ t = 0.60, ease = "QuadInOut", pose = "Idle" },
			},
		},
		-- Poise broken: it drops onto hands and knees and the plates over the core swing open.
		DownedFall = {
			duration = 1.0, blendIn = 0.08, blendOut = 0, hold = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.60, ease = "QuadIn", pose = downed() },
				{ t = 1.00, ease = "SineOut", pose = "Downed" },
			},
			events = { { t = 0.6, name = "CoreOpen" } },
		},
		DownedLoop = { duration = 1.25, loop = true, blendIn = 0, keys = {
			{ t = 0.0, pose = "Downed" }, { t = 0.62, ease = "SineInOut", pose = downed({ Waist = r(-71), CoreHingeL = r(0, -100, 0), CoreHingeR = r(0, 100, 0) }) },
			{ t = 1.25, ease = "SineInOut", pose = "Downed" },
		} },
		GetUp = {
			duration = 1.5, blendIn = 0, blendOut = 0.2,
			keys = {
				{ t = 0.00, pose = "Downed" },
				{ t = 0.50, ease = "SineInOut", pose = downed({ Root = p(0, -14, 0), Waist = r(-60), CoreHingeL = r(0, -100, 0), CoreHingeR = r(0, 100, 0) }) },
				{ t = 0.90, ease = "SineInOut", pose = crouch(55, { Root = p(0, -10, 0), Waist = r(-40), CoreHingeL = r(0, 0, 0), CoreHingeR = r(0, 0, 0) }) },
				{ t = 1.50, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.5, name = "CoreClose" } },
		},
		-- The knees buckle; the Ash Collapse follows (docs/10 §2).
		Death = {
			duration = 2.0, blendIn = 0.1, blendOut = 0, hold = true,
			keys = {
				{ t = 0.00, pose = "Downed" },
				{ t = 2.00, ease = "QuadIn", pose = downed({ Root = p(0, -21, 0), Waist = r(-60, 0, 15), Neck = r(-30, 0, 20), LeftShoulder = r(40, 0, -35), RightShoulder = r(30, 0, 30), CoreHingeL = r(0, -100, 0), CoreHingeR = r(0, 100, 0) }) },
			},
		},
	},
}
