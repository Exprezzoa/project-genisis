--!strict
-- Shared/Config/CombatConfig.lua  (docs/12_combat_system.md; these numbers are the authority)
--
-- If a number changes during tuning, change it here AND in docs/12, and log it in decisions.md.
-- Pose clips (Shared/Poses) must use the same timings; DevTools.Checks.ConfigCheck compares them.

local CombatConfig = {}

local V = Vector3.new
-- Lengths are the 40-stud Vanguard's numbers of docs/12 times the rig's scale (D-044).
local S = require(script.Parent.FrameConfig).Vanguard.scale

CombatConfig.SAMPLE_RATE = 20 -- hitbox samples per second during an active window
CombatConfig.LAG_PAD = 2 * S -- studs added to every attack box, per axis
CombatConfig.INPUT_BUFFER = 0.25 -- seconds a press is kept until it becomes valid
CombatConfig.PREDICTION_TIMEOUT = 0.25 -- the client drops a predicted action the server didn't confirm
CombatConfig.CHAIN_DELAY = 0.15 -- a queued light starts this long after the previous light's recovery begins
CombatConfig.RECOVERY_CANCEL = 0.5 -- fraction of a Light/Heavy recovery after which Dodge may cancel it
CombatConfig.MERCY = 0.4 -- seconds of invulnerability after being hit
CombatConfig.ATTACK_MOVE_SCALE = 0.6 -- share of the walk speed a Frame keeps while it attacks (user direction, D-055)
CombatConfig.DODGE_GRACE = 0.15 -- a dodge this late after an attack's active start still counts

-- Moves per Frame class (docs/12 §3). Slowed to about 1.7 x the first numbers on the user's direction (D-052):
-- a 64-stud machine swinging a 45-stud blade has to read as heavy. Damage and poise were raised by the same 1.7 x
-- afterwards (user decision, D-061), so each slower swing hits as much harder: 40/15, 45/15, 70/30, 140/50 and
-- 90/120 became the numbers below. The Core Strike was never slowed and stays at 700. Times in seconds from the move's start:
--   startup, active, recovery   total = startup + active + recovery
--   box  = attack box in the HRP's local space (front = -Z): size, offset of its center
--   aim  = point (HRP local) used to choose the zone when several hurtboxes overlap
--   lunge = root motion { distance, from, to }
CombatConfig.Frames = {
	Vanguard = {
		Light1 = {
			clip = "Light1", startup = 0.35, active = 0.20, recovery = 0.45, damage = 68, poise = 26, energy = 0,
			chain = "Light2", cancelRecovery = true,
			box = { size = V(24, 30, 26) * S, offset = V(0, -2, -15) * S }, aim = V(0, -5, -20) * S,
		},
		Light2 = {
			clip = "Light2", startup = 0.32, active = 0.20, recovery = 0.45, damage = 77, poise = 26, energy = 0,
			chain = "Light3", cancelRecovery = true,
			box = { size = V(24, 30, 26) * S, offset = V(0, -2, -15) * S }, aim = V(0, -5, -20) * S,
		},
		Light3 = {
			clip = "Light3", startup = 0.45, active = 0.25, recovery = 0.70, damage = 119, poise = 51, energy = 0,
			cancelRecovery = true,
			box = { size = V(12, 34, 30) * S, offset = V(0, -3, -17) * S }, aim = V(0, -11, -24) * S,
		},
		Heavy = {
			clip = "Heavy", startup = 0.90, active = 0.28, recovery = 0.90, damage = 238, poise = 85, energy = 0,
			cancelRecovery = true, dodgeCancelBefore = 0.60,
			lunge = { distance = 12 * S, from = 0.70, to = 1.00 },
			box = { size = V(34, 30, 30) * S, offset = V(0, -2, -14) * S }, aim = V(0, -1, -20) * S,
		},
		Special = {
			clip = "Special_PileDriver", startup = 0.60, active = 0.15, recovery = 1.00, damage = 153, poise = 204,
			energy = 50, cooldown = 6.0, cancelRecovery = false,
			box = { size = V(10, 12, 26) * S, offset = V(-4, -7, -16) * S }, aim = V(-3, -9, -24) * S,
		},
	},
}

-- Dodge per class: one timeline, no hitbox.
CombatConfig.Dodge = {
	Vanguard = { duration = 0.35, settle = 0.10, distance = 55 * S, energy = 25, cooldown = 0.8, iFrames = { from = 0.05, to = 0.30 } },
}

CombatConfig.CoreStrike = {
	-- stepTime: the Frame steps into place during the first part of the clip (the arms are still going up).
	-- blade: where the middle of the blade comes down, in the Frame's own space in real studs, measured on the
	-- CoreStrike clip at its Impact (19 to the right, 48 ahead, at the height of a downed Strider's core). The
	-- step-in puts the Frame where that point is on the core.
	Vanguard = { clip = "CoreStrike", duration = 1.6, damage = 700, impact = 0.62, range = 34 * S, facing = 60, stepTime = 0.5, blade = V(19, 0, -48) },
}

-- Titan attacks (docs/10 §1.4, docs/12 §7). Lengths are the Titan's own studs; the hit tests add the Frame's
-- body radius. windup / active / recovery in seconds; `track` names the turn rate of TitanConfig used during
-- the windup; knockback is the distance a hit Frame is thrown.
CombatConfig.TitanAttacks = {
	Strider = {
		Sweep = { clip = "Sweep", windup = 1.1, active = 0.35, recovery = 1.4, damage = 180, shape = "Arc", radius = 45, halfAngle = 60, knockback = 12, track = "sweepWindup" },
		Stomp = { clip = "Stomp", windup = 0.9, active = 0.15, recovery = 1.6, damage = 220, shape = "Circle", radius = 26, forward = 8, knockback = 18, track = "approach", anklePoise = 2.0 },
		Lunge = {
			clip = "Lunge", windup = 1.3, active = 0.5, recovery = 2.2, damage = 260, shape = "Path", halfWidth = 7, speed = 100, knockback = 25,
			track = "lungeWindup", recoverHurtboxes = "LungeRecover",
		},
		Roar = { clip = "Roar", windup = 0.6, active = 0.9, recovery = 0.6, damage = 0, shape = "Sphere", radius = 35, knockback = 40, stagger = 0.6, track = "approach" },
		cooldown = { min = 1.2, max = 2.0 }, -- between attacks
		enrage = { hpFraction = 0.5, windupScale = 0.87, cooldownScale = 0.8, roarEvery = { min = 25, max = 35 } },
		-- Attack choice by the gap between the two bodies (center distance minus both body radii). The doc's
		-- table is in center distances for a 40-stud Frame (17 apart at the closest); as gaps it reads the same
		-- for the 64-stud Frame. Beyond the last band the Titan only approaches.
		choice = {
			{ gap = 5, weights = { Stomp = 60, Sweep = 40 } },
			{ gap = 13, weights = { Sweep = 80, Stomp = 20 } },
			{ gap = 28, weights = { Sweep = 60, Lunge = 30, Stomp = 10 } },
			{ gap = 53, weights = { Lunge = 70, Approach = 30 } },
		},
		standGap = 13, -- closer than this it stops walking and waits for its cooldown
		chaseGap = 93, -- further than this it uses its chase speed
		stompReach = 32, -- Stomp only if the target is this close to the landing point (26 + 6)
		decisionRate = 10, -- decisions per second
		moveRate = 4, -- movement commands per second at most
	} :: any,
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
	titanRadius = 9 + 8 * S, -- Titan body 9 + Frame 8
	titanLowRadius = 22 + 8 * S, -- a Titan on its hands (Downed, Lunge recovery) reaches about 22 studs past its root
	allyRadius = 16 * S,
	gain = 12, -- push speed per stud of overlap
	maxPush = 40 * S,
}

-- Speed check (docs/12 §10), per piloted Frame.
CombatConfig.SpeedCheck = {
	interval = 0.25,
	normal = 48 * S * 1.25,
	dodge = 170 * S,
	rootMotion = 60 * S,
	violationTime = 0.5, -- cumulative seconds over the limit ...
	window = 3, -- ... within this many seconds -> set back to the last valid position
}

-- Lock-on (docs/12 §8): the server accepts a lock on a target this near.
CombatConfig.LockOn = { range = 220 * S, zones = { "Body", "AnkleL", "AnkleR", "Head", "Core" } }

-- Action validation tolerances (docs/12 §10).
CombatConfig.Tolerance = { coreStrikeRange = 4 * S, facing = 10 }

-- The dodge clip for a direction in the Frame's own space (front = -Z).
function CombatConfig.dodgeClip(localDirection: Vector3): string
	if math.abs(localDirection.X) > math.abs(localDirection.Z) then
		return if localDirection.X > 0 then "Dodge_R" else "Dodge_L"
	end
	return if localDirection.Z > 0 then "Dodge_B" else "Dodge_F"
end

function CombatConfig.total(move: { startup: number, active: number, recovery: number }): number
	return move.startup + move.active + move.recovery
end

return CombatConfig
