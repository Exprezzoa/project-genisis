--!nonstrict
-- Shared/Poses/Shifter.lua  (docs/08 §4.2; D-095, D-096)
--
-- Poses and clips of Elias's Titan form (builders/rigs/Shifter: the 80-stud body of the user's Titan model, hips
-- 31 up, thigh 12.7, shin and foot 18.2). Convention of docs/08 §4.1 (+X swings a hanging limb forward and tips
-- the torso back, +Y turns left, +Z swings a hanging limb toward the rig's right: inward for the left arm, outward
-- for the right). Its own set (user direction: not the Strider's): it moves and fights like a person, a boxer's
-- guard and fists, where the Strider hunches and claws. Clip lengths are CombatConfig.Frames.Shifter's moves
-- (startup + active + recovery), Dodge (0.4 + 0.1), CoreStrike (1.4) and the specials' clipTime.
--   Emerge    as the lightning clears it stands up out of a crouch and rolls its shoulders
--   Punch1-3  jab (left), cross (right), uppercut (left)       Smash  both fists overhead and down (the heavy)
--   NapeStrike  down on the knees, both fists into an open core                Dodge_F/B/L/R  a quick sidestep
--   HitReact_Light / HitReact_Heavy                           Harden  arms crossed, then braced: the skin hardens
--   Rage      a crouch, then a roar with the arms thrown wide  Collapse  down on one knee, head hung (held)

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end
local function p(x, y, z)
	return { pos = { x, y, z } }
end

-- A crouch: hips, knees and ankles fold by `angle` and the body sinks the 31 x (1 - cos a) studs that keeps the
-- feet on the ground (whatever Root the pose had).
local function crouch(angle, pose)
	for _, side in ipairs({ "Left", "Right" }) do
		pose[side .. "Hip"] = r(angle)
		pose[side .. "Knee"] = r(-2 * angle)
		pose[side .. "Ankle"] = r(angle)
	end
	pose.Root = p(0, -31 * (1 - math.cos(math.rad(angle))), 0)
	return pose
end

local function with(base, extra)
	local pose = table.clone(base)
	for joint, entry in pairs(extra) do
		pose[joint] = entry
	end
	return pose
end

-- Fists up by the chin, knees soft, weight forward.
local GUARD = crouch(10, {
	Waist = r(-8, 10, 0), Neck = r(6, -10, 0),
	LeftShoulder = r(55, 0, 22), LeftElbow = r(115), RightShoulder = r(45, 0, -22), RightElbow = r(120),
})
-- Both arms above the head, fists together.
local OVERHEAD = {
	Root = p(0, 0.5, 0), Waist = r(16), Neck = r(12),
	LeftShoulder = r(168, 0, 18), RightShoulder = r(168, 0, -18), LeftElbow = r(45), RightElbow = r(45),
}

return {
	rig = "Shifter",
	poses = {
		-- Upright, the arms hanging closer than the model's rest (its upper arms stand 34 degrees out).
		Idle = {
			Waist = r(-3), LeftShoulder = r(3, 0, 14), RightShoulder = r(3, 0, -14), LeftElbow = r(10), RightElbow = r(10),
		},
		Guard = GUARD,
		-- Down on one knee, head hung (the legs are about 17 studs thick: the knee joint rests 8.5 up).
		Spent = {
			Root = p(0, -13, 0),
			LeftHip = r(42), LeftKnee = r(-132), LeftAnkle = r(40),
			RightHip = r(90, 0, 15), RightKnee = r(-90),
			Waist = r(-35), Neck = r(-30),
			LeftShoulder = r(20, 0, 10), RightShoulder = r(20, 0, -10), LeftElbow = r(30), RightElbow = r(30),
		},
	},
	clips = {
		Idle = { duration = 1, loop = true, keys = { { t = 0, pose = "Idle" } } },
		Emerge = {
			duration = 1.6, blendIn = 0, blendOut = 0.3,
			keys = {
				{ t = 0.00, pose = crouch(40, { Waist = r(-40), Neck = r(30), LeftShoulder = r(40, 0, 20), RightShoulder = r(40, 0, -20), LeftElbow = r(60), RightElbow = r(60) }) },
				{ t = 0.90, ease = "QuadOut", pose = { Root = p(0, 0, 0), LeftHip = r(0), RightHip = r(0), LeftKnee = r(0), RightKnee = r(0), LeftAnkle = r(0), RightAnkle = r(0), Waist = r(8), Neck = r(15), LeftShoulder = r(-10, 0, -25), RightShoulder = r(-10, 0, 25), LeftElbow = r(20), RightElbow = r(20) } },
				{ t = 1.60, ease = "SineInOut", pose = "Idle" },
			},
		},

		-- Jab: the left fist snaps straight out as the hips turn it in; the right stays up.
		Punch1 = {
			duration = 0.60, blendIn = 0.05, blendOut = 0.12,
			keys = {
				{ t = 0.00, pose = "Guard" },
				{ t = 0.18, ease = "QuadOut", pose = with(GUARD, { Waist = r(-12, -24, 0), Neck = r(6, 18, 0), LeftShoulder = r(92, -6, 16), LeftElbow = r(6) }) },
				{ t = 0.30, ease = "Linear", pose = {} },
				{ t = 0.60, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.16, name = "Whoosh" } },
		},
		-- Cross: the right fist drives through as the hips turn the other way; weight onto the front foot.
		Punch2 = {
			duration = 0.65, blendIn = 0.05, blendOut = 0.12,
			keys = {
				{ t = 0.00, pose = "Guard" },
				{ t = 0.20, ease = "QuadOut", pose = with(GUARD, { Waist = r(-16, 28, 0), Neck = r(6, -22, 0), RightShoulder = r(94, 6, -16), RightElbow = r(6), LeftShoulder = r(50, 0, 24), LeftElbow = r(118) }) },
				{ t = 0.32, ease = "Linear", pose = {} },
				{ t = 0.65, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.18, name = "Whoosh" } },
		},
		-- Uppercut: it dips, then the left fist comes up from the hip as the body rises and leans back.
		Punch3 = {
			duration = 0.95, blendIn = 0.05, blendOut = 0.15,
			keys = {
				{ t = 0.00, pose = "Guard" },
				{ t = 0.18, ease = "QuadOut", pose = crouch(24, { Waist = r(-18, -18, 0), Neck = r(12, 10, 0), LeftShoulder = r(5, 0, 22), LeftElbow = r(100), RightShoulder = r(45, 0, -22), RightElbow = r(120) }) },
				{ t = 0.30, ease = "QuadIn", pose = { Root = p(0, 0.8, 0), LeftHip = r(0), RightHip = r(0), LeftKnee = r(0), RightKnee = r(0), LeftAnkle = r(0), RightAnkle = r(0), Waist = r(12, 22, 0), Neck = r(-6, -10, 0), LeftShoulder = r(150, 0, 14), LeftElbow = r(60) } },
				{ t = 0.45, ease = "Linear", pose = {} },
				{ t = 0.95, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.26, name = "Whoosh" } },
		},
		-- Smash (the heavy): both fists go up overhead and come down together as it drops into a crouch.
		Smash = {
			duration = 1.50, blendIn = 0.08, blendOut = 0.25,
			keys = {
				{ t = 0.00, pose = "Guard" },
				{ t = 0.45, ease = "QuadOut", pose = OVERHEAD },
				{ t = 0.62, ease = "QuadIn", pose = crouch(30, { Waist = r(-42), Neck = r(20), LeftShoulder = r(62, 0, 12), RightShoulder = r(62, 0, -12), LeftElbow = r(18), RightElbow = r(18) }) },
				{ t = 0.75, ease = "Linear", pose = { Waist = r(-46), LeftShoulder = r(52, 0, 12), RightShoulder = r(52, 0, -12) } },
				{ t = 1.50, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.55, name = "Whoosh" }, { t = 0.64, name = "Slam" } },
		},
		-- Into an open core (the CoreStrike): fists up, then down on its knees driving both into it.
		NapeStrike = {
			duration = 1.40, blendIn = 0.08, blendOut = 0.25,
			keys = {
				{ t = 0.00, pose = "Guard" },
				{ t = 0.40, ease = "QuadOut", pose = OVERHEAD },
				{ t = 0.60, ease = "QuadIn", pose = crouch(45, { Waist = r(-60), Neck = r(30), LeftShoulder = r(48, 0, 10), RightShoulder = r(48, 0, -10), LeftElbow = r(10), RightElbow = r(10) }) },
				{ t = 1.00, ease = "Linear", pose = {} },
				{ t = 1.40, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.6, name = "Slam" } },
		},

		-- Dodges: a low quick step, leaning with it, the guard up.
		Dodge_F = { duration = 0.50, blendIn = 0.04, blendOut = 0.1, keys = {
			{ t = 0.00, pose = "Guard" }, { t = 0.15, ease = "QuadOut", pose = crouch(22, with(GUARD, { Waist = r(-18, 10, 0) })) }, { t = 0.50, ease = "QuadInOut", pose = "Guard" },
		} },
		Dodge_B = { duration = 0.50, blendIn = 0.04, blendOut = 0.1, keys = {
			{ t = 0.00, pose = "Guard" }, { t = 0.15, ease = "QuadOut", pose = crouch(22, with(GUARD, { Waist = r(8, 10, 0) })) }, { t = 0.50, ease = "QuadInOut", pose = "Guard" },
		} },
		Dodge_L = { duration = 0.50, blendIn = 0.04, blendOut = 0.1, keys = {
			{ t = 0.00, pose = "Guard" }, { t = 0.15, ease = "QuadOut", pose = crouch(22, with(GUARD, { Waist = r(-8, 10, 14) })) }, { t = 0.50, ease = "QuadInOut", pose = "Guard" },
		} },
		Dodge_R = { duration = 0.50, blendIn = 0.04, blendOut = 0.1, keys = {
			{ t = 0.00, pose = "Guard" }, { t = 0.15, ease = "QuadOut", pose = crouch(22, with(GUARD, { Waist = r(-8, 10, -14) })) }, { t = 0.50, ease = "QuadInOut", pose = "Guard" },
		} },

		HitReact_Light = { duration = 0.35, blendIn = 0.04, blendOut = 0.12, keys = {
			{ t = 0.00, pose = "Idle" }, { t = 0.08, ease = "QuadOut", pose = { Waist = r(10, 8, 0), Neck = r(-8, 6, 0) } }, { t = 0.35, ease = "QuadInOut", pose = "Idle" },
		} },
		HitReact_Heavy = { duration = 0.70, blendIn = 0.04, blendOut = 0.15, keys = {
			{ t = 0.00, pose = "Idle" },
			{ t = 0.12, ease = "QuadOut", pose = crouch(16, { Waist = r(18, -8, 0), Neck = r(-12), LeftShoulder = r(-12, 0, -18), RightShoulder = r(-12, 0, 18) }) },
			{ t = 0.70, ease = "QuadInOut", pose = "Idle" },
		} },

		-- Hardening: the forearms cross in front of the chest, then it braces with the arms out as the skin hardens.
		Harden = {
			duration = 1.0, blendIn = 0.08, blendOut = 0.2,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.30, ease = "QuadOut", pose = crouch(12, { Waist = r(-12), Neck = r(-10), LeftShoulder = r(80, 30, 34), LeftElbow = r(100), RightShoulder = r(80, -30, -34), RightElbow = r(100) }) },
				{ t = 0.60, ease = "QuadOut", pose = { Root = p(0, 0, 0), LeftHip = r(0), RightHip = r(0), LeftKnee = r(0), RightKnee = r(0), LeftAnkle = r(0), RightAnkle = r(0), Waist = r(6), Neck = r(14), LeftShoulder = r(35, 0, -45), LeftElbow = r(95), RightShoulder = r(35, 0, 45), RightElbow = r(95) } },
				{ t = 1.00, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.45, name = "Harden" } },
		},
		-- Rage: it hunches with the fists low, then throws its head back and its arms wide in a roar.
		Rage = {
			duration = 1.4, blendIn = 0.08, blendOut = 0.25,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.40, ease = "QuadOut", pose = crouch(20, { Waist = r(-28), Neck = r(20), LeftShoulder = r(15, 0, -28), RightShoulder = r(15, 0, 28), LeftElbow = r(70), RightElbow = r(70) }) },
				{ t = 0.80, ease = "QuadOut", pose = { Root = p(0, 0, 0), LeftHip = r(0), RightHip = r(0), LeftKnee = r(0), RightKnee = r(0), LeftAnkle = r(0), RightAnkle = r(0), Waist = r(24), Neck = r(36), LeftShoulder = r(30, 0, -72), RightShoulder = r(30, 0, 72), LeftElbow = r(70), RightElbow = r(70) } },
				{ t = 1.15, ease = "Linear", pose = {} },
				{ t = 1.40, ease = "QuadInOut", pose = "Guard" },
			},
			events = { { t = 0.8, name = "Rage" } },
		},

		Collapse = {
			duration = 1.2, blendIn = 0.15, blendOut = 0, hold = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 1.20, ease = "QuadIn", pose = "Spent" },
			},
		},
	},
}
