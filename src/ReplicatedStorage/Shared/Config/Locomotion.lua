--!strict
-- Shared/Config/Locomotion.lua  (docs/08_rigs_and_animation.md §4.5)
--
-- Procedural gait parameters per rig and gait. Angles in degrees, lengths in studs.
-- speed and stepLength are world numbers (the 40-stud spec x the rig's scale, D-044). rootBob is in the rig's
-- own units like every pose offset: the animator multiplies it by the rig's scale.
--   ankle = share of the knee angle the ankle takes back (ankle = ankle x knee)
--   armSwing: other = the free arm(s), blade = the arm holding the weapon

local Locomotion = {}

local S = require(script.Parent.FrameConfig).Vanguard.scale

Locomotion.IDLE_BELOW = 2 -- studs/s: slower than this is idle
Locomotion.TURN_SHUFFLE = { yawRate = 30, maxSpeed = 2, hipYaw = 8, interval = 0.4 } -- turning in place
Locomotion.SETTLE = 0.2 -- seconds of root bob overshoot when a Frame stops (docs/09 §1)

Locomotion.Vanguard = {
	walk = {
		speed = 30 * S, stepLength = 15 * S, hipSwing = 22, kneeBend = -35, ankle = -0.5, rootBob = 0.8, rootRoll = 2,
		waistYaw = 5, armSwing = { other = 10, blade = 5 }, lean = -3, headStabilized = true,
	},
	stride = {
		speed = 48 * S, stepLength = 20 * S, hipSwing = 30, kneeBend = -55, ankle = -0.5, rootBob = 1.4, rootRoll = 3,
		waistYaw = 7, armSwing = { other = 16, blade = 6 }, lean = -8, headStabilized = true,
	},
	bladeArm = "Right",
}

-- docs/08 §4.5. The Strider has no weapon arm: both arms swing alike. Lengths are real studs (56-stud rig).
Locomotion.Strider = {
	walk = {
		speed = 16, stepLength = 14, hipSwing = 20, kneeBend = -40, ankle = -0.5, rootBob = 1.2, rootRoll = 4,
		waistYaw = 8, armSwing = { other = 14, blade = 14 }, lean = -4, headStabilized = false,
	},
	stride = {
		speed = 22, stepLength = 16, hipSwing = 26, kneeBend = -50, ankle = -0.5, rootBob = 1.6, rootRoll = 5,
		waistYaw = 10, armSwing = { other = 18, blade = 18 }, lean = -8, headStabilized = false,
	},
	bladeArm = "Right",
}

-- docs/08 §4.5 "Watcher careful walk" (D-091): its lengths x 80/68 for the 80-stud body (D-047); speed 10 is the
-- careful walk of docs/10 §3. Feet lift high: swingLift bends hip, knee and ankle of the swinging leg like a
-- crouch (a degrees lifts the foot about 31 x (1 - cos a) studs: 32 gives the doc's 4 studs x 80/68). Above
-- walking speed (S31 beat 8, the way out over the ridge) the steps lengthen.
Locomotion.Watcher = {
	walk = {
		speed = 10, stepLength = 21, hipSwing = 18, kneeBend = -30, ankle = -0.5, rootBob = 1.2, rootRoll = 2,
		waistYaw = 4, armSwing = { other = 12, blade = 12 }, lean = -6, headStabilized = true, swingLift = 32,
	},
	stride = {
		speed = 24, stepLength = 30, hipSwing = 24, kneeBend = -40, ankle = -0.5, rootBob = 1.6, rootRoll = 3,
		waistYaw = 6, armSwing = { other = 16, blade = 16 }, lean = -8, headStabilized = true, swingLift = 20,
	},
	bladeArm = "Right",
}

return Locomotion
