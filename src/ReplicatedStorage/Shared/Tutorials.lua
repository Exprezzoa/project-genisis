--!strict
-- Shared/Tutorials.lua  (docs/13_missions_dialogue_relationships.md §8; texts: docs/05_chapter1_script.md)
--
-- Tutorial cards. The title is the text before the script's " — "; the body is the rest, where [KB|Gamepad|Touch]
-- is the script's "A / B / C" and shows only the part for the device in use (docs/11 §1 "Device glyphs"), in
-- amber. `when` names a condition the client watches once the server arms the tutorial (the fight's, S28):
--   sweep    the first Sweep telegraph starts (the only one shown during a telegraph)
--   special  the Frame has 50+ energy and the Titan's poise is at 60% or less
--   downed   the Titan is Downed
--   regen    the Titan has regenerated 100+ HP since it was last damaged
-- Without `when` a tutorial shows as soon as the server sends it (still never over dialogue or a cinematic).

export type Tutorial = { title: string, body: string, when: string?, seconds: number?, urgent: boolean? }

local tutorials: { [string]: Tutorial } = {
	TUT_MOVE = {
		title = "MOVE",
		body = "[WASD|Left Stick|Thumbstick]. Your Frame is heavy: it takes time to speed up and turn. Hold [SHIFT|L3|STRIDE] for Stride.",
	},
	TUT_DISMOUNT = {
		title = "DISMOUNT",
		body = "Stand on a landing pad and use the prompt. You can only leave your Frame on pads.",
	},
	TUT_LOCK = { title = "LOCK ON", body = "[R|R3|LOCK]. Cycle targets with [C|D-pad ← →|tap LOCK again]." },
	-- urgent: it replaces a card already up (the Sweep's windup is short).
	TUT_DODGE = { title = "DODGE", body = "[SPACE|B|DODGE]. You're invulnerable at the start of a dodge.", when = "sweep", urgent = true },
	TUT_ATTACK = { title = "ATTACK", body = "[LMB|RB|LIGHT] light combo, [RMB|RT|HEAVY] heavy. Hit the ANKLES to break its balance." },
	TUT_SPECIAL = { title = "PILE DRIVER", body = "[Q|LB|SPECIAL]. Breaks balance fast. Costs 50 energy.", when = "special" },
	TUT_CORE = { title = "IT'S DOWN", body = "The Dorsal Core is exposed! CORE STRIKE — [F|Y|CORE].", when = "downed" },
	TUT_REGEN = { title = "IT REGENERATES", body = "Keep the pressure on, and break it to finish it.", when = "regen" },
}

return {
	tutorials = tutorials,
	SECONDS = 5, -- auto-hide (docs/14 §10)
	REGEN_HP = 100,
	SPECIAL = { energy = 50, poise = 0.6 },
}
