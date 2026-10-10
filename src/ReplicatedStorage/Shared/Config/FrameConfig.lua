--!strict
-- Shared/Config/FrameConfig.lua  (docs/09_frames.md §4-5, docs/08_rigs_and_animation.md §2-3, docs/11 §4-5)
--
-- One entry per Frame class. A class = rig builder + pose set + this entry + a move list in CombatConfig;
-- no code is written per class. Combat numbers (damage, timings, costs) live in CombatConfig.

local FrameConfig = {}

-- The Vanguard was specified at 40 studs and is built 1.6 times that, 64 studs (user direction, D-044).
-- Lengths below are written as <the 40-stud number> * S, so they can still be compared with the docs.
local S = 1.6

FrameConfig.Vanguard = {
	rig = "Vanguard", -- ServerStorage.Templates.Frames.<rig>_<unit>, Shared.Poses.<rig>
	scale = S, -- the rig builder scales the model by this; pose offsets (Root, PileDriver) are multiplied by it
	height = 40 * S,
	hipHeight = 14 * S,
	integrity = 1000,
	energy = { max = 100, regen = 18, regenDelay = 1.0 },
	walkSpeed = 30 * S,
	strideSpeed = 48 * S,
	acceleration = 70 * S,
	deceleration = 90 * S,
	turnRate = { free = 150, locked = 220, stride = 110 }, -- degrees per second
	limp = { threshold = 0.15, walkScale = 0.75 }, -- under 15% integrity: walk x0.75, no stride
	-- Body target for enemy attacks: a vertical cylinder centered on the HRP's XZ.
	body = { radius = 8 * S, height = 40 * S },
	-- Damage states by integrity fraction (docs/09 §5), highest first.
	damageStates = {
		{ name = "Pristine", above = 0.67 },
		{ name = "Scuffed", above = 0.34 },
		{ name = "Damaged", above = 0.15 },
		{ name = "Critical", above = 0 },
		{ name = "Disabled", above = -1 },
	},
	pilotSeat = Vector3.new(0, 29, 0) * S, -- model space
	boardDistance = 10, -- docs/08 §5.4: the pilot must be this close to the prompt
	hatch = { openAngle = -100, time = 0.6 },
}

-- Units of the Vertical Slice (docs/09 §3). spawn = registry id of the bay marker (map_02 §2).
FrameConfig.Units = {
	["01"] = { class = "Vanguard", pilot = "Mara", accent = "VG_ACCENT_MARA", spawn = "FRAME_BAY1", playable = false },
	["02"] = { class = "Vanguard", pilot = "Elias", accent = "VG_ACCENT_ELIAS", spawn = "FRAME_BAY2", playable = true },
	-- Unit 03 is a static repair prop (no rig, no joints); the hangar builder places it.
}

-- Humanoid states a giant rig must never enter (docs/08 §2.6). Disabling a state doesn't replicate, so the
-- server and every client switch them off for each rig. Found in play: a parked Frame's Humanoid was
-- "FallingDown" on the client, so on boarding the Frame dropped onto its root and took 3 s to get up (D-046).
FrameConfig.DisabledStates = { "Dead", "Ragdoll", "FallingDown", "GettingUp", "Climbing", "Swimming", "Jumping", "Seated", "PlatformStanding" }

-- Facing control (docs/08 §2.1).
FrameConfig.Align = { responsiveness = 40 }

-- Dismount (docs/08 §5.4): the Frame must be inside the pad, slower than this, and out of combat.
FrameConfig.Dismount = { maxSpeed = 3, kneelTime = 1.0, fadeAt = 0.8 }

FrameConfig.Fade = 0.35 -- seconds of the board and dismount fades

return FrameConfig
