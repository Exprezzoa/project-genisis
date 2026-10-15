--!strict
-- Shared/Config/ShifterConfig.lua  (docs/02 §8, docs/06 §6 "Shifter transformation", docs/10; D-095, D-096)
--
-- Elias shifting into his Titan form and back. The ability is the profile flag CAN_SHIFT (for now only the
-- /shifter debug command sets it). Where it may be used: the Training Yard, or wherever the story step allows it
-- (the sequence action { "shifting", allowed = true }; no Chapter 1 step does). A mid-to-late game power, built to
-- be overpowered (user direction, D-096).

return {
	FLAG = "CAN_SHIFT",
	TEMPLATE = "Shifter_Elias", -- ServerStorage.Templates.Titans
	ZONES = { TrainingYard = true }, -- always allowed here (with the ability)

	hold = 1.0, -- seconds of holding Z: the clench before the bolt, and to come back
	cooldown = 6, -- seconds after coming back before the next shift
	leaveGrace = 3, -- seconds a Titan may stand outside an allowed place before it returns to human form

	-- The meter (user direction: "a meter for like 3-4 minutes", refilled by waiting or doing damage). One value per
	-- player, 0-100 (player attribute ShiftEnergy). In the Titan form it drains to nothing in 3.5 minutes and the
	-- form gives way at 0; in human form it refills in 4 minutes; damage the player deals (in a Frame or as the Titan)
	-- adds perDamage per point. Shifting needs minToShift.
	energy = { max = 100, start = 100, minToShift = 30, drain = 100 / 210, regen = 100 / 240, perDamage = 1 / 40 },

	-- The Titan form heals itself (with steam) once nothing has hit it for regenDelay seconds.
	titan = { regen = 80, regenDelay = 2.5 },

	-- Specials (user direction: "unlock specials throughout story or purchase such as hardening, rage, etc."). Each
	-- is unlocked by its flag (a story step sets it, or a purchase once the shop exists: Phase 6/10); /shifter
	-- special sets them for testing. The selected one is used with ShiftSpecial (Q) and NextSpecial (T) picks
	-- another. cost comes off the meter; the buff lasts `duration`; clip plays (Shared/Poses/Shifter).
	specials = {
		order = { "Hardening", "Rage" },
		Hardening = {
			label = "HARDENING", flag = "SHIFT_SPECIAL_HARDENING", clip = "Harden", clipTime = 1.0,
			cost = 15, cooldown = 25, duration = 15,
			damageTaken = 0.3, damageDealt = 1.5, -- hardened skin: takes 30% of each hit, the fists hit 1.5 x as hard
		},
		Rage = {
			label = "RAGE", flag = "SHIFT_SPECIAL_RAGE", clip = "Rage", clipTime = 1.4,
			cost = 20, cooldown = 30, duration = 12,
			damageDealt = 1.6, speed = 1.3, -- 1.6 x damage and poise, 1.3 x speed
		},
	},

	-- The first shift (user direction): a cinematic in which Elias loses control and starts to break, then the
	-- lightning lands with impact frames. strikeAt = when the bolt and the swap happen on the cinematic's timeline.
	firstShift = { flag = "SEEN_FIRST_SHIFT", cinematic = "CIN_FIRST_SHIFT", strikeAt = 5.2 },

	-- docs/06 §6: bolt 0.35 s, flash 0.12 s up / 0.6 s down (30% with Reduce Flashing), light 8 -> 0 over Range
	-- 60; the human model is swapped for the Titan while the screen is white.
	bolt = { time = 0.35, redraws = 3, segments = { 6, 9 }, forks = { 2, 3 }, height = 260, width = 1.4 },
	flash = { up = 0.12, down = 0.6, reduced = 0.3 },
	light = { brightness = 8, range = 60, time = 0.8 },
	swapAt = 0.12, -- the Titan stands where Elias was, under the white
	emerge = 1.6, -- the Emerge clip: no walking until it is over

	-- Coming back (user direction: "kneeling and steam coming out the nape"): it sinks to one knee, steam pours out
	-- of its nape, the rider comes out behind it and the body fades into the steam.
	collapse = 1.2,
	fade = 1.5,
	exitBehind = 12, -- studs behind the Titan's root, on the ground
}
