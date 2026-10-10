--!nonstrict
-- Shared/Poses/Vanguard.lua  (docs/08_rigs_and_animation.md §4.2, §5.1)
--
-- Poses and clips of the Vanguard for the Procedural Pose Animator. Rotations {rx, ry, rz} in degrees in the
-- convention of docs/08 §4.1; pos {x, y, z} in studs (Root and PileDriver). A joint missing in a key keeps the
-- previous key's value; a key that names a pose is a full pose.
-- Clip timings equal Config/CombatConfig (DevTools.Checks.ConfigCheck compares them); the events here are
-- visual only. HeadTurnAnomaly (docs/08 §5.1) is an additive computed in code, not a keyed clip.

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end
local function p(x, y, z)
	return { pos = { x, y, z } }
end
local function rp(rot, pos)
	return { rot = rot, pos = pos }
end

-- A pose that drops the root needs the legs to fold, or the feet sink into the floor (D-037). crouch(a) bends
-- hips, knees and ankles by a degrees (the body sinks 17 x (1 - cos a) studs) and adds the given joints.
local function crouch(angle, pose)
	for _, side in ipairs({ "Left", "Right" }) do
		pose[side .. "Hip"] = r(angle)
		pose[side .. "Knee"] = r(-2 * angle)
		pose[side .. "Ankle"] = r(angle)
	end
	return pose
end

-- A fighting stance (D-055): one foot forward and one back, both flat on the floor, the body 1.5 studs lower
-- and the whole machine turned by `yaw` degrees. The swings step from one stance into the other, so the legs
-- and hips drive the blade instead of the arm alone.
local function stance(front, yaw, pose)
	local back = if front == "Left" then "Right" else "Left"
	pose[front .. "Hip"], pose[front .. "Knee"], pose[front .. "Ankle"] = r(35), r(-38), r(3)
	pose[back .. "Hip"], pose[back .. "Knee"], pose[back .. "Ankle"] = r(-20), r(-8), r(28)
	pose.Root = rp({ 0, yaw, 0 }, { 0, -1.5, 0 })
	return pose
end

local KNEEL = {
	Root = p(0, -7, 0), LeftHip = r(80), LeftKnee = r(-80), RightHip = r(-10), RightKnee = r(-100), RightAnkle = r(40),
	Waist = r(-15), RightShoulder = r(60, 0, 10), RightElbow = r(40), Neck = r(-15),
}
-- A dodge is a thruster-assisted leap, not a slide (user feedback, D-058): the machine pushes off one leg,
-- flies with one leg reaching and the other trailing, and lands deep on the reaching leg. It travels during
-- 0.00-0.35 and has absorbed the landing by 0.45. Every key names all the joints it moves; Root drops so the
-- leg that carries the weight reaches the floor.
local function leap(push, flight, landing)
	return {
		duration = 0.45, blendIn = 0.04, blendOut = 0.10,
		keys = {
			{ t = 0.00, pose = "Idle" },
			{ t = 0.07, ease = "QuadOut", pose = push },
			{ t = 0.21, ease = "SineInOut", pose = flight },
			{ t = 0.35, ease = "SineInOut", pose = landing },
			{ t = 0.45, ease = "QuadInOut", pose = "Idle" },
		},
		events = { { t = 0.0, name = "ThrustersOn" }, { t = 0.30, name = "ThrustersOff" } },
	}
end

-- The same pose for the other side: Left and Right swap, turns and side swings change sign.
local function mirror(pose)
	local mirrored = {}
	for joint, entry in pairs(pose) do
		local other = if string.sub(joint, 1, 4) == "Left" then "Right" .. string.sub(joint, 5)
			elseif string.sub(joint, 1, 5) == "Right" then "Left" .. string.sub(joint, 6)
			else joint
		local rot, pos = entry.rot, entry.pos
		mirrored[other] = { rot = rot and { rot[1], -rot[2], -rot[3] }, pos = pos and { -pos[1], pos[2], pos[3] } }
	end
	return mirrored
end

-- Forward: the left leg reaches, the right drives and trails; the free arm sweeps back and the blade is carried
-- level along the side like a lance (swept back it would cut through the floor).
local LEAP_F = {
	push = {
		Root = rp({ -12, 0, 0 }, { 0, -1.5, 0 }), Waist = r(-10), Neck = r(10),
		LeftHip = r(48), LeftKnee = r(-95), LeftAnkle = r(52), RightHip = r(-14), RightKnee = r(-22), RightAnkle = r(24),
		LeftShoulder = r(-20, 0, -10), LeftElbow = r(35), RightShoulder = r(-10, 0, 10), RightElbow = r(40), RightWrist = r(-10),
	},
	flight = {
		Root = rp({ -16, 0, 0 }, { 0, -1.2, 0 }), Waist = r(-6), Neck = r(14),
		LeftHip = r(62), LeftKnee = r(-40), LeftAnkle = r(-12), RightHip = r(-46), RightKnee = r(-42), RightAnkle = r(35),
		LeftShoulder = r(-38, 0, -14), LeftElbow = r(40), RightShoulder = r(-25, 0, 12), RightElbow = r(45), RightWrist = r(0),
	},
	landing = {
		Root = rp({ -4, 0, 0 }, { 0, -3.4, 0 }), Waist = r(-16), Neck = r(8),
		LeftHip = r(48), LeftKnee = r(-78), LeftAnkle = r(30), RightHip = r(-8), RightKnee = r(-62), RightAnkle = r(45),
		LeftShoulder = r(18, 0, -12), LeftElbow = r(30), RightShoulder = r(14, 0, 10), RightElbow = r(40), RightWrist = r(-35),
	},
}
-- Backward (the dodge with no move input): the front leg pushes, the right leg reaches back for the ground; the
-- hips lead and the torso stays over the guard.
local LEAP_B = {
	push = {
		Root = rp({ 6, 0, 0 }, { 0, -1.7, 0 }), Waist = r(-14), Neck = r(-4),
		LeftHip = r(34), LeftKnee = r(-50), LeftAnkle = r(16), RightHip = r(-24), RightKnee = r(-22), RightAnkle = r(46),
		LeftShoulder = r(25, 0, -12), LeftElbow = r(30), RightShoulder = r(25, 0, 12), RightElbow = r(40), RightWrist = r(-30),
	},
	flight = {
		Root = rp({ 10, 0, 0 }, { 0, -1.0, 0 }), Waist = r(-20), Neck = r(-8),
		LeftHip = r(46), LeftKnee = r(-26), LeftAnkle = r(-14), RightHip = r(-44), RightKnee = r(-18), RightAnkle = r(50),
		LeftShoulder = r(40, 0, -16), LeftElbow = r(25), RightShoulder = r(35, 0, 14), RightElbow = r(35), RightWrist = r(-30),
	},
	landing = {
		Root = rp({ 2, 0, 0 }, { 0, -2.65, 0 }), Waist = r(-18), Neck = r(-2),
		LeftHip = r(45), LeftKnee = r(-60), LeftAnkle = r(15), RightHip = r(-5), RightKnee = r(-45), RightAnkle = r(50),
		LeftShoulder = r(20, 0, -10), LeftElbow = r(30), RightShoulder = r(15, 0, 10), RightElbow = r(40), RightWrist = r(-25),
	},
}
-- To the left: the left leg reaches out, the right pushes and trails; the body rolls into the leap.
local LEAP_L = {
	push = {
		Root = rp({ 0, 0, 10 }, { 0, -1.9, 0 }), Waist = r(-8, 0, -6), Neck = r(0, 0, -6),
		LeftHip = r(30, 0, -22), LeftKnee = r(-80), LeftAnkle = r(50), RightHip = r(4, 0, 14), RightKnee = r(-30), RightAnkle = r(24),
		LeftShoulder = r(0, 0, -30), LeftElbow = r(30), RightShoulder = r(5, 0, 14), RightElbow = r(40),
	},
	flight = {
		Root = rp({ 0, 0, 18 }, { 0, -1.0, 0 }), Waist = r(-8, 0, -12), Neck = r(0, 0, -10),
		LeftHip = r(16, 0, -40), LeftKnee = r(-70), LeftAnkle = r(40), RightHip = r(8, 0, 30), RightKnee = r(-46), RightAnkle = r(30),
		LeftShoulder = r(0, 0, -48), LeftElbow = r(20), RightShoulder = r(10, 0, 26), RightElbow = r(30),
	},
	landing = {
		Root = rp({ 0, 0, 5 }, { 0, -2.2, 0 }), Waist = r(-12, 0, 6), Neck = r(0, 0, 4),
		LeftHip = r(26, 0, -30), LeftKnee = r(-62), LeftAnkle = r(34), RightHip = r(10, 0, 14), RightKnee = r(-48), RightAnkle = r(36),
		LeftShoulder = r(10, 0, -24), LeftElbow = r(30), RightShoulder = r(10, 0, 12), RightElbow = r(40),
	},
}

return {
	rig = "Vanguard",
	poses = {
		Idle = {
			RightShoulder = r(10, 0, 8), RightElbow = r(35), RightWrist = r(-25),
			LeftShoulder = r(5, 0, -6), LeftElbow = r(15), Waist = r(-3),
		},
		-- Weapons lowered for moving inside the hangar: the blade tip points 30 degrees further down.
		IdleHangar = {
			RightShoulder = r(10, 0, 8), RightElbow = r(35), RightWrist = r(-55),
			LeftShoulder = r(5, 0, -6), LeftElbow = r(15), Waist = r(-3),
		},
		Kneel = KNEEL,
		Disabled = {
			Root = p(0, -8, 0), LeftHip = r(80), RightHip = r(80), LeftKnee = r(-110), RightKnee = r(-110), Waist = r(-30),
			LeftAnkle = r(30), RightAnkle = r(30),
			Neck = r(-40), LeftShoulder = r(10, 0, -5), RightShoulder = r(10, 0, 5), LeftElbow = r(5), RightElbow = r(5),
		},
	},
	clips = {
		Idle = { duration = 1, loop = true, keys = { { t = 0, pose = "Idle" } } },
		TapIdleHangar = { duration = 1, loop = true, blendIn = 0.3, keys = { { t = 0, pose = "IdleHangar" } } },
		KneelIdle = { duration = 1, loop = true, blendIn = 0, keys = { { t = 0, pose = "Kneel" } } },
		Boot = {
			duration = 1.2, blendIn = 0, blendOut = 0.2,
			keys = {
				{ t = 0.0, pose = "Idle" },
				{ t = 0.01, pose = { Neck = r(-30) } },
				{ t = 0.8, ease = "SineOut", pose = { Neck = r(0) } },
				{ t = 1.2, pose = "Idle" },
			},
			events = { { t = 0.6, name = "VisorOn" } },
		},
		-- Blade swings (D-050): RightWrist near -85 lays the blade in line with the forearm, so arm and blade
		-- sweep one long arc at chest height; with the idle wrist the blade stood up and the swing read as a punch.
		-- Right to left.
		Light1 = {
			duration = 1.00, blendIn = 0.10, blendOut = 0.12, upperBodyOnly = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.35, ease = "QuadOut", pose = stance("Left", -14, {
					Waist = r(0, -40, 0), RightShoulder = r(30, 0, 80), RightElbow = r(10), RightWrist = r(-85), LeftShoulder = r(15, 0, -15),
				}) },
				{ t = 0.45, ease = "Linear", pose = crouch(18, {
					Root = p(0, -0.85, 0), Waist = r(0, 0, 0), RightShoulder = r(80, 0, 20), RightElbow = r(5), RightWrist = r(-85),
				}) },
				{ t = 0.55, ease = "Linear", pose = stance("Right", 14, {
					Waist = r(0, 42, 0), RightShoulder = r(70, 0, -40), RightElbow = r(20), RightWrist = r(-85), LeftShoulder = r(-15, 0, -8),
				}) },
				{ t = 1.00, ease = "QuadInOut", pose = "Idle" },
			},
			events = {
				{ t = 0.32, name = "TrailOn" }, { t = 0.33, name = "Whoosh" }, { t = 0.35, name = "HitboxStart" },
				{ t = 0.55, name = "HitboxEnd" }, { t = 0.58, name = "TrailOff" },
			},
		},
		-- Left to right, back along the same arc.
		Light2 = {
			duration = 0.97, blendIn = 0.10, blendOut = 0.12, upperBodyOnly = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.32, ease = "QuadOut", pose = stance("Right", 14, {
					Waist = r(0, 42, 0), RightShoulder = r(70, 0, -40), RightElbow = r(20), RightWrist = r(-85), LeftShoulder = r(-15, 0, -8),
				}) },
				{ t = 0.42, ease = "Linear", pose = crouch(18, {
					Root = p(0, -0.85, 0), Waist = r(0, 5, 0), RightShoulder = r(85, 0, 5), RightElbow = r(5), RightWrist = r(-85),
				}) },
				{ t = 0.52, ease = "Linear", pose = stance("Left", -14, {
					Waist = r(0, -40, 0), RightShoulder = r(45, 0, 75), RightElbow = r(10), RightWrist = r(-85), LeftShoulder = r(15, 0, -15),
				}) },
				{ t = 0.97, ease = "QuadInOut", pose = "Idle" },
			},
			events = {
				{ t = 0.29, name = "TrailOn" }, { t = 0.30, name = "Whoosh" }, { t = 0.32, name = "HitboxStart" },
				{ t = 0.52, name = "HitboxEnd" }, { t = 0.55, name = "TrailOff" },
			},
		},
		-- Overhead smash.
		Light3 = {
			duration = 1.40, blendIn = 0.10, blendOut = 0.15, upperBodyOnly = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.45, ease = "QuadOut", pose = {
					Root = p(0, 0.5, 0), Waist = r(12), RightShoulder = r(170, 0, 10), RightElbow = r(40),
					LeftShoulder = r(150, 0, -10), LeftElbow = r(40),
				} },
				{ t = 0.58, ease = "Linear", pose = crouch(21, {
					Root = p(0, -1.2, 0), Waist = r(-25), RightShoulder = r(60, 0, 5), RightElbow = r(10), RightWrist = r(-70),
					LeftShoulder = r(50, 0, -5),
				}) },
				{ t = 0.70, ease = "Linear", pose = crouch(24, { Root = p(0, -1.5, 0) }) },
				{ t = 1.40, ease = "QuadInOut", pose = "Idle" },
			},
			events = {
				{ t = 0.42, name = "TrailOn" }, { t = 0.43, name = "Whoosh" }, { t = 0.45, name = "HitboxStart" },
				{ t = 0.64, name = "GroundImpact" }, { t = 0.70, name = "HitboxEnd" }, { t = 0.73, name = "TrailOff" },
			},
		},
		-- Spinning cleave. Root motion (12 studs forward, 0.70-1.00) is applied by FrameController.
		Heavy = {
			duration = 2.08, blendIn = 0.08, blendOut = 0.15, upperBodyOnly = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.60, ease = "QuadOut", pose = stance("Left", -24, {
					Waist = r(0, -55, 0), RightShoulder = r(15, 0, 85), RightElbow = r(25), RightWrist = r(-85), LeftShoulder = r(20, 0, -20),
				}) },
				{ t = 0.90, ease = "Linear", pose = {} }, -- holds the windup until the release
				{ t = 1.04, ease = "Linear", pose = crouch(24, {
					Root = p(0, -1.5, 0), Waist = r(0, 10, 0), RightShoulder = r(80, 0, 25), RightElbow = r(0), RightWrist = r(-88),
				}) },
				{ t = 1.18, ease = "Linear", pose = stance("Right", 24, {
					Waist = r(0, 55, 0), RightShoulder = r(70, 0, -45), RightElbow = r(20), RightWrist = r(-85), LeftShoulder = r(-20, 0, -8),
				}) },
				{ t = 2.08, ease = "QuadInOut", pose = "Idle" },
			},
			events = {
				{ t = 0.84, name = "TrailOn" }, { t = 0.87, name = "Whoosh" }, { t = 0.90, name = "HitboxStart" },
				{ t = 1.18, name = "HitboxEnd" }, { t = 1.22, name = "TrailOff" },
			},
		},
		Special_PileDriver = {
			duration = 1.75, blendIn = 0.08, blendOut = 0.15, upperBodyOnly = true,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.60, ease = "QuadOut", pose = crouch(20, {
					Root = p(0, -1, 0), Waist = r(0, 30, 0), LeftShoulder = r(-30, 0, -10), LeftElbow = r(90), PileDriver = p(0, 0, 0),
				}) },
				{ t = 0.67, ease = "Linear", pose = { Waist = r(-18, -20, 0), LeftShoulder = r(55, 0, -5), LeftElbow = r(5) } }, -- punches low (D-037)
				{ t = 0.68, ease = "Linear", pose = { PileDriver = p(0, -6, 0) } },
				{ t = 0.75, ease = "Linear", pose = { PileDriver = p(0, -6, 0) } },
				{ t = 1.25, ease = "SineInOut", pose = { PileDriver = p(0, 0, 0) } },
				{ t = 1.75, ease = "QuadInOut", pose = "Idle" },
			},
			events = {
				{ t = 0.60, name = "HitboxStart" }, { t = 0.68, name = "Clank" }, { t = 0.69, name = "SteamBurst" },
				{ t = 0.75, name = "HitboxEnd" },
			},
		},
		Dodge_F = leap(LEAP_F.push, LEAP_F.flight, LEAP_F.landing),
		Dodge_B = leap(LEAP_B.push, LEAP_B.flight, LEAP_B.landing),
		Dodge_L = leap(LEAP_L.push, LEAP_L.flight, LEAP_L.landing),
		Dodge_R = leap(mirror(LEAP_L.push), mirror(LEAP_L.flight), mirror(LEAP_L.landing)),
		CoreStrike = {
			duration = 1.60, blendIn = 0.08, blendOut = 0.2,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.50, ease = "QuadOut", pose = {
					Root = p(0, 2, 0), Waist = r(10), RightShoulder = r(170, 0, 10), LeftShoulder = r(170, 0, -10),
				} },
				{ t = 0.62, ease = "QuadIn", pose = crouch(34, {
					Root = p(0, -3, 0), Waist = r(-35), RightShoulder = r(40, 0, 5), LeftShoulder = r(40, 0, -5),
				}) },
				{ t = 0.70, ease = "Linear", pose = { Waist = r(-35, 10, 0) } },
				{ t = 0.78, ease = "SineInOut", pose = { Waist = r(-35, 14, 0) } },
				{ t = 0.86, ease = "SineInOut", pose = { Waist = r(-35, 6, 0) } },
				{ t = 0.95, ease = "SineInOut", pose = { Waist = r(-35, 14, 0) } },
				{ t = 1.03, ease = "SineInOut", pose = { Waist = r(-35, 6, 0) } },
				{ t = 1.12, ease = "SineInOut", pose = { Waist = r(-35, 14, 0) } },
				{ t = 1.20, ease = "SineInOut", pose = { Waist = r(-35, 10, 0) } },
				{ t = 1.60, ease = "QuadInOut", pose = "Idle" },
			},
			events = { { t = 0.62, name = "Impact" } },
		},
		HitReact_Light = {
			duration = 0.35, blendIn = 0.03, blendOut = 0.1,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.08, ease = "QuadOut", pose = { Waist = r(12, 0, 8), Neck = r(8) } },
				{ t = 0.35, ease = "QuadInOut", pose = "Idle" },
			},
		},
		-- Root motion (4 studs backward, 0.0-0.3) is applied by FrameController.
		HitReact_Heavy = {
			duration = 0.70, blendIn = 0.03, blendOut = 0.12,
			keys = {
				{ t = 0.00, pose = "Idle" },
				{ t = 0.12, ease = "QuadOut", pose = crouch(24, {
					Root = p(0, -1.5, 0), Waist = r(20), LeftShoulder = r(-20, 0, -15), RightShoulder = r(-20, 0, 15),
				}) },
				{ t = 0.70, ease = "QuadInOut", pose = "Idle" },
			},
		},
		Kneel = {
			duration = 1.0, blendIn = 0.1, blendOut = 0, hold = true,
			keys = { { t = 0.0, pose = "Idle" }, { t = 1.0, ease = "SineInOut", pose = "Kneel" } },
		},
		RiseFromKneel = {
			duration = 1.0, blendIn = 0, blendOut = 0.15,
			keys = { { t = 0.0, pose = "Kneel" }, { t = 1.0, ease = "SineInOut", pose = "Idle" } },
		},
		Disabled = {
			duration = 1.8, blendIn = 0.1, blendOut = 0, hold = true,
			keys = { { t = 0.0, pose = "Idle" }, { t = 1.8, ease = "SineInOut", pose = "Disabled" } },
			events = { { t = 1.2, name = "VisorOff" } },
		},
	},
}
