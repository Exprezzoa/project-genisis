--!strict
-- Shared/Config/CombatConfig.lua  (docs/12_combat_system.md; these numbers are the authority)
--
-- If a number changes during tuning, change it here AND in docs/12, and log it in decisions.md.
-- Pose clips (Shared/Poses) must use the same timings; DevTools.Checks.ConfigCheck compares them.

local CombatConfig = {}

local V = Vector3.new

CombatConfig.SAMPLE_RATE = 20 -- hitbox samples per second during an active window
CombatConfig.LAG_PAD = 2 -- studs added to every attack box, per axis
CombatConfig.INPUT_BUFFER = 0.25 -- seconds a press is kept until it becomes valid
CombatConfig.PREDICTION_TIMEOUT = 0.25 -- the client drops a predicted action the server didn't confirm
CombatConfig.CHAIN_DELAY = 0.10 -- a queued light starts this long after the previous light's recovery begins
CombatConfig.RECOVERY_CANCEL = 0.5 -- fraction of a Light/Heavy recovery after which Dodge may cancel it
CombatConfig.MERCY = 0.4 -- seconds of invulnerability after being hit
CombatConfig.DODGE_GRACE = 0.15 -- a dodge this late after an attack's active start still counts

-- Moves per Frame class (docs/12 §3). Times in seconds from the move's start:
--   startup, active, recovery   total = startup + active + recovery
--   box  = attack box in the HRP's local space (front = -Z): size, offset of its center
--   aim  = point (HRP local) used to choose the zone when several hurtboxes overlap
--   lunge = root motion { distance, from, to }
CombatConfig.Frames = {
	Vanguard = {
		Light1 = {
			clip = "Light1", startup = 0.18, active = 0.12, recovery = 0.30, damage = 40, poise = 15, energy = 0,
			chain = "Light2", cancelRecovery = true,
			box = { size = V(24, 30, 26), offset = V(0, -2, -15) }, aim = V(0, -5, -20),
		},
		Light2 = {
			clip = "Light2", startup = 0.16, active = 0.12, recovery = 0.30, damage = 45, poise = 15, energy = 0,
			chain = "Light3", cancelRecovery = true,
			box = { size = V(24, 30, 26), offset = V(0, -2, -15) }, aim = V(0, -5, -20),
		},
		Light3 = {
			clip = "Light3", startup = 0.24, active = 0.16, recovery = 0.50, damage = 70, poise = 30, energy = 0,
			cancelRecovery = true,
			box = { size = V(12, 34, 30), offset = V(0, -3, -17) }, aim = V(0, -11, -24),
		},
		Heavy = {
			clip = "Heavy", startup = 0.55, active = 0.18, recovery = 0.70, damage = 140, poise = 50, energy = 0,
			cancelRecovery = true, dodgeCancelBefore = 0.35,
			lunge = { distance = 12, from = 0.40, to = 0.60 },
			box = { size = V(34, 30, 30), offset = V(0, -2, -14) }, aim = V(0, -1, -20),
		},
		Special = {
			clip = "Special_PileDriver", startup = 0.40, active = 0.10, recovery = 0.80, damage = 90, poise = 120,
			energy = 50, cooldown = 6.0, cancelRecovery = false,
			box = { size = V(10, 12, 26), offset = V(-4, -7, -16) }, aim = V(-3, -9, -24),
		},
	},
}

-- Dodge per class: one timeline, no hitbox.
CombatConfig.Dodge = {
	Vanguard = { duration = 0.35, settle = 0.10, distance = 55, energy = 25, cooldown = 0.8, iFrames = { from = 0.05, to = 0.30 } },
}

CombatConfig.CoreStrike = {
	Vanguard = { clip = "CoreStrike", duration = 1.6, damage = 700, impact = 0.62, range = 34, facing = 60 },
}

-- Which request starts which move from a neutral state; "Light" walks the chain.
CombatConfig.Requests = {
	Light = "Light1",
	Heavy = "Heavy",
	Special = "Special",
}

-- Hit zones (docs/12 §6).
CombatConfig.Zones = {
	Body = { hpMult = 1.0, poiseMult = 1.0 },
	AnkleL = { hpMult = 0.8, poiseMult = 1.6 },
	AnkleR = { hpMult = 0.8, poiseMult = 1.6 },
	ArmL = { hpMult = 0.9, poiseMult = 0.8 },
	ArmR = { hpMult = 0.9, poiseMult = 0.8 },
	Head = { hpMult = 1.2, poiseMult = 1.2 },
	Core = { hpMult = 2.0, poiseMult = 0 },
}

-- Hit reactions of a Frame (docs/12 §7).
CombatConfig.HitReact = {
	heavyAt = 200, -- damage from which the heavy reaction plays
	Light = { clip = "HitReact_Light", stun = 0.25 },
	Heavy = { clip = "HitReact_Heavy", stun = 0.50 },
}

-- Separation (docs/12 §9), run by the pilot client.
CombatConfig.Separation = {
	titanRadius = 17, -- Titan body 9 + Frame 8
	allyRadius = 16,
	gain = 12, -- push speed per stud of overlap
	maxPush = 40,
}

-- Speed check (docs/12 §10), per piloted Frame.
CombatConfig.SpeedCheck = {
	interval = 0.25,
	normal = 48 * 1.25,
	dodge = 170,
	rootMotion = 60,
	violationTime = 0.5, -- cumulative seconds over the limit ...
	window = 3, -- ... within this many seconds -> set back to the last valid position
}

-- Action validation tolerances (docs/12 §10).
CombatConfig.Tolerance = { coreStrikeRange = 4, facing = 10 }

function CombatConfig.total(move: { startup: number, active: number, recovery: number }): number
	return move.startup + move.active + move.recovery
end

return CombatConfig
