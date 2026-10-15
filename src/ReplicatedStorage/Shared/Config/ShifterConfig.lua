--!strict
-- Shared/Config/ShifterConfig.lua  (docs/02 §8, docs/06 §6 "Shifter transformation", docs/10; D-095)
--
-- Elias shifting into his Titan form and back. The ability is the profile flag CAN_SHIFT (for now only the
-- /shifter debug command sets it). Where it may be used: the Training Yard, or wherever the story step allows it
-- (the sequence action { "shifting", allowed = true }; no Chapter 1 step does).

return {
	FLAG = "CAN_SHIFT",
	TEMPLATE = "Shifter_Elias", -- ServerStorage.Templates.Titans
	ZONES = { TrainingYard = true }, -- always allowed here (with the ability)

	hold = 1.0, -- seconds of holding Z: the clench before the bolt, and to come back
	cooldown = 6, -- seconds after coming back before the next shift
	leaveGrace = 3, -- seconds a Titan may stand outside an allowed place before it returns to human form

	-- docs/06 §6: bolt 0.35 s, flash 0.12 s up / 0.6 s down (30% with Reduce Flashing), light 8 -> 0 over Range
	-- 60; the human model is swapped for the Titan while the screen is white.
	bolt = { time = 0.35, redraws = 3, segments = { 6, 9 }, forks = { 2, 3 }, height = 260, width = 1.4 },
	flash = { up = 0.12, down = 0.6, reduced = 0.3 },
	light = { brightness = 8, range = 60, time = 0.8 },
	swapAt = 0.12, -- the Titan stands where Elias was, under the white
	emerge = 1.6, -- the Emerge clip: no walking until it is over

	-- Coming back (not in the docs yet): it sinks to one knee in a burst of steam, the rider comes out of the
	-- nape behind it and the body fades into the steam.
	collapse = 1.2,
	fade = 1.5,
	exitBehind = 12, -- studs behind the Titan's root, on the ground
}
