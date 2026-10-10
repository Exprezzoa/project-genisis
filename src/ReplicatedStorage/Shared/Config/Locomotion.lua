--!strict
-- Shared/Config/Locomotion.lua  (docs/08_rigs_and_animation.md §4.5)
--
-- Procedural gait parameters per rig and gait. Angles in degrees, lengths in studs.
--   ankle = share of the knee angle the ankle takes back (ankle = ankle x knee)
--   armSwing: other = the free arm(s), blade = the arm holding the weapon

local Locomotion = {}

Locomotion.IDLE_BELOW = 2 -- studs/s: slower than this is idle
Locomotion.TURN_SHUFFLE = { yawRate = 30, maxSpeed = 2, hipYaw = 8, interval = 0.4 } -- turning in place
Locomotion.SETTLE = 0.2 -- seconds of root bob overshoot when a Frame stops (docs/09 §1)

Locomotion.Vanguard = {
	walk = {
		speed = 30, stepLength = 15, hipSwing = 22, kneeBend = -35, ankle = -0.5, rootBob = 0.8, rootRoll = 2,
		waistYaw = 5, armSwing = { other = 10, blade = 5 }, lean = -3, headStabilized = true,
	},
	stride = {
		speed = 48, stepLength = 20, hipSwing = 30, kneeBend = -55, ankle = -0.5, rootBob = 1.4, rootRoll = 3,
		waistYaw = 7, armSwing = { other = 16, blade = 6 }, lean = -8, headStabilized = true,
	},
	bladeArm = "Right",
}

return Locomotion
