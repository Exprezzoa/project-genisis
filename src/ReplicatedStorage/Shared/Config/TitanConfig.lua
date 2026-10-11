--!strict
-- Shared/Config/TitanConfig.lua  (docs/10_titans.md §1.2-1.3; attacks live in CombatConfig.TitanAttacks)
--
-- One entry per Titan type. A type = rig template (ServerStorage.Templates.Titans.<rig>) + pose set
-- (Shared.Poses.<rig>) + this entry + a behavior module (Server/Titans/Behaviors/<rig>).

local V = Vector3.new

local TitanConfig = {}

TitanConfig.Strider = {
	rig = "Strider",
	displayName = "STRIDER-CLASS — UNREGISTERED",
	classTier = 3,
	height = 56,
	hp = 6000, -- was 2400: the user's fight took about a minute against a 2-3.5 minute target (D-064)
	hpRegen = { rate = 10, delay = 4.0 }, -- per second, once no HP damage came for `delay`; never while Downed
	poise = { base = 300, perBreak = 60, cap = 480, regen = 25, regenDelay = 3.0 },
	flinch = { threshold = 60, window = 1.5, duration = 0.6, cooldown = 4.0 },
	downed = { fall = 1.0, loop = 5.0, getUp = 1.5 },
	walkSpeed = 16,
	chaseSpeed = 22,
	turnRate = { approach = 70, sweepWindup = 45, lungeWindup = 90 }, -- degrees per second
	bodyRadius = 9, -- for separation
	aggroRadius = 220,
	-- Hurtboxes (docs/10 §1.2): invisible parts welded to the HRP; the weld's C0 per state. Offsets are from
	-- the HRP's center. A state a zone doesn't list uses Standing; `false` switches the zone off.
	hurtboxes = {
		Body = { size = V(14, 20, 8), Standing = CFrame.new(0, 6, 0), Downed = CFrame.new(0, -10, -6) * CFrame.Angles(math.rad(-75), 0, 0), LungeRecover = CFrame.new(0, -12, -8) * CFrame.Angles(math.rad(-80), 0, 0) },
		Head = { size = V(7, 9, 7.5), Standing = CFrame.new(0, 22, 0), Downed = CFrame.new(0, -7.5, -18), LungeRecover = CFrame.new(0, -14, -22) },
		AnkleL = { size = V(5.5, 7, 5.5), Standing = CFrame.new(-3.5, -23, 0), Downed = CFrame.new(-3.5, -26, 10), LungeRecover = CFrame.new(-3.5, -26, 8) },
		AnkleR = { size = V(5.5, 7, 5.5), Standing = CFrame.new(3.5, -23, 0), Downed = CFrame.new(3.5, -26, 10), LungeRecover = CFrame.new(3.5, -26, 8) },
		ArmL = { size = V(5, 28, 5), Standing = CFrame.new(-9.5, -6.5, 0), Downed = CFrame.new(-9.5, -18, -14), LungeRecover = CFrame.new(-9.5, -20, -18) },
		ArmR = { size = V(5, 28, 5), Standing = CFrame.new(9.5, -6.5, 0), Downed = CFrame.new(9.5, -18, -14), LungeRecover = CFrame.new(9.5, -20, -18) },
		Core = { size = V(5, 5, 3), Standing = false, Downed = CFrame.new(0, -8.7, -7.5), LungeRecover = false },
	} :: { [string]: any },
}

return TitanConfig
