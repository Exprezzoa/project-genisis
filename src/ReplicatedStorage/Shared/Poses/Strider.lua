--!nonstrict
-- Shared/Poses/Strider.lua  (docs/08_rigs_and_animation.md §4.2, §5.2)
--
-- Poses and clips of the Strider for the Procedural Pose Animator. Rotations {rx, ry, rz} in degrees in the
-- convention of docs/08 §4.1; pos {x, y, z} in studs. The rig is the 56-stud body of builders/rigs/Strider
-- (joint names as in an R15 body). The attack, flinch, downed and death clips arrive with the Strider's
-- behavior (the next step of Phase 3).

local function r(x, y, z)
	return { rot = { x, y or 0, z or 0 } }
end

return {
	rig = "Strider",
	poses = {
		-- Hunched: the back leans forward, the head lifts to keep watching, the long arms hang.
		Idle = {
			Waist = r(-14), Neck = r(12), LeftShoulder = r(8, 0, -7), RightShoulder = r(8, 0, 7), LeftElbow = r(12), RightElbow = r(12),
			LeftHip = r(6), RightHip = r(6), LeftKnee = r(-10), RightKnee = r(-10), LeftAnkle = r(4), RightAnkle = r(4),
		},
	},
	clips = {
		Idle = { duration = 1, loop = true, keys = { { t = 0, pose = "Idle" } } },
	},
}
