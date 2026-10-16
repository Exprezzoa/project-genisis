--!strict
-- Shared/Config/Upgrades.lua  (docs/12_combat_system.md §12; docs/17_saving_progression_monetization.md §6)
--
-- Frame upgrades, bought at the Equipment Terminal. An upgrade is data: its modifiers change the pilot's effective
-- config (Shared/Modules/EffectiveConfig), so adding one needs no code. A modifier's path starts in CombatConfig,
-- or in FrameConfig when it begins with "FrameConfig.". op: "mul", "add" or "set". label and unit only feed the
-- Equipment screen's before → after lines.

export type Modifier = { path: string, op: "mul" | "add" | "set", value: number, label: string, unit: string? }
export type Upgrade = {
	id: string,
	name: string,
	desc: string,
	cost: number,
	rankRequired: number,
	modifiers: { Modifier },
}

local list: { Upgrade } = {
	{
		id = "VG_SERVO_1",
		name = "Servo Tuning I",
		desc = "Retuned arm servos. The light chain recovers faster, so the blade is back in guard sooner.",
		cost = 300,
		rankRequired = 1,
		modifiers = {
			{ path = "Frames.Vanguard.Light1.recovery", op = "mul", value = 0.85, label = "LIGHT 1 RECOVERY", unit = "s" },
			{ path = "Frames.Vanguard.Light2.recovery", op = "mul", value = 0.85, label = "LIGHT 2 RECOVERY", unit = "s" },
			{ path = "Frames.Vanguard.Light3.recovery", op = "mul", value = 0.85, label = "LIGHT 3 RECOVERY", unit = "s" },
		},
	},
	{
		id = "VG_CAPACITOR_1",
		name = "Capacitor Bank I",
		desc = "An extra capacitor bank in the back plate. Energy comes back faster after a dodge or a special.",
		cost = 350,
		rankRequired = 1,
		modifiers = {
			{ path = "FrameConfig.Vanguard.energy.regen", op = "mul", value = 1.2, label = "ENERGY REGEN", unit = "/s" },
		},
	},
	{
		id = "VG_THRUSTER_BAFFLES",
		name = "Thruster Baffles",
		desc = "Baffled dodge thrusters. Shorter cooldown between dodges, and each one draws less energy.",
		cost = 400,
		rankRequired = 2,
		modifiers = {
			{ path = "Dodge.Vanguard.cooldown", op = "add", value = -0.15, label = "DODGE COOLDOWN", unit = "s" },
			{ path = "Dodge.Vanguard.energy", op = "add", value = -5, label = "DODGE COST", unit = "" },
		},
	},
	{
		id = "VG_PILEDRIVER_MK2",
		name = "Pile Driver Mk II",
		desc = "A heavier ram for the Pile Driver. It breaks a Titan's footing harder and recharges sooner.",
		cost = 500,
		rankRequired = 2,
		modifiers = {
			{ path = "Frames.Vanguard.Special.poise", op = "mul", value = 1.3, label = "PILE DRIVER POISE", unit = "" },
			{ path = "Frames.Vanguard.Special.cooldown", op = "add", value = -1.0, label = "PILE DRIVER COOLDOWN", unit = "s" },
		},
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in ipairs(list) do
	byId[upgrade.id] = upgrade
end

return {
	List = list, -- in the Equipment screen's order (and the order modifiers apply in)
	ById = byId,
}
