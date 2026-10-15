--!nonstrict
-- Shared/Poses/Shifter.lua  (docs/08 §4.2; D-095)
--
-- Poses and clips of Elias's Titan form (builders/rigs/Shifter: the 80-stud body of the user's Titan model, hips
-- 31 up). Convention of docs/08 §4.1. Not in the docs yet; the smallest set the shift needs:
--   Emerge    as the lightning clears it stands up out of a crouch and rolls its shoulders (1.6 s)
--   Collapse  it sinks to one knee and hangs its head while the steam rises, then the rider comes out (1.2 s, held)

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end
local function p(x, y, z)
	return { pos = { x, y, z } }
end

-- A crouch: hips, knees and ankles fold by `angle`, the body sinks about 31 x (1 - cos a) studs (thigh 12.7,
-- shin and foot 18.2).
local function crouch(angle, pose)
	for _, side in ipairs({ "Left", "Right" }) do
		pose[side .. "Hip"] = r(angle)
		pose[side .. "Knee"] = r(-2 * angle)
		pose[side .. "Ankle"] = r(angle)
	end
	return pose
end

return {
	rig = "Shifter",
	poses = {
		-- Upright, the arms hanging closer than the model's rest (as the Watcher's Idle).
		Idle = {
			Waist = r(-3), LeftShoulder = r(3, 0, 14), RightShoulder = r(3, 0, -14), LeftElbow = r(10), RightElbow = r(10),
		},
		-- Down on one knee, head hung (as the Watcher's kneel: the legs are about 17 studs thick).
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
				{ t = 0.00, pose = crouch(40, { Root = p(0, -7.3, 0), Waist = r(-40), Neck = r(30), LeftShoulder = r(40, 0, 20), RightShoulder = r(40, 0, -20), LeftElbow = r(60), RightElbow = r(60) }) },
				{ t = 0.90, ease = "QuadOut", pose = { Root = p(0, 0, 0), LeftHip = r(0), RightHip = r(0), LeftKnee = r(0), RightKnee = r(0), LeftAnkle = r(0), RightAnkle = r(0), Waist = r(8), Neck = r(15), LeftShoulder = r(-10, 0, -25), RightShoulder = r(-10, 0, 25), LeftElbow = r(20), RightElbow = r(20) } },
				{ t = 1.60, ease = "SineInOut", pose = "Idle" },
			},
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
