--!strict
-- Shared/Cinematics.lua  (docs/11_controls_and_camera.md §6; shots from docs/05_chapter1_script.md)
--
-- Every cinematic, played on one client by CinematicController and timed on the server by CinematicService.
--   shots           played in order. A shot starts at a cam point (`cam`, a CinematicCam CamId) or at `from`
--                   { pos, look } and moves to `to` { pos?, look? } over `seconds` with `easing` (default
--                   SineInOut); fov is a number or { start, end }. `hold = true` keeps the last frame.
--   dialogueDriven  the camera cuts to each line's `action.cam` (docs/13 §2) and drifts slowly in; the cinematic
--                   runs until the server stops it (the dialogue's end)
--   events          the server's timeline: { at = seconds, dialogue = id } starts that dialogue
--   skippable       may be skipped the first time too (a seen one always can: docs/11 §1)
--   screen          the briefing screen shows the lines' `action.slide`
-- Positions written for the 40-stud Frame are scaled × 1.6 (D-044), as the cam points already are.

export type Shot = {
	cam: string?, from: { any }?, to: { pos: { number }?, look: { number }? }?,
	seconds: number, fov: any?, easing: string?, hold: boolean?,
}

return {
	-- S04: the hangar reveal, first entry only (6.5 s of shots, then S04_01 over the held frame).
	CIN_HANGAR_REVEAL = {
		letterbox = true,
		shots = {
			{ cam = "CAM_HANGAR_REVEAL_1", to = { pos = { 0, 5, -165 } }, seconds = 3.5, fov = { 55, 50 }, easing = "Linear" },
			-- The pan ends on (0, 22, -205) in docs/05, Unit 02's chest at 40 studs; × 1.6.
			{ cam = "CAM_HANGAR_REVEAL_2", to = { look = { 0, 35, -205 } }, seconds = 3.0, fov = 60 },
			{ hold = true, seconds = 2.6 },
		},
		events = { { at = 6.5, dialogue = "DLG_CH1_HANGAR_REVEAL" } },
	},
	-- S07: the briefing. Vale's lines name their shot (CAM_BRF_WIDE / VALE / PILOTS) and slide.
	CIN_BRIEFING = {
		letterbox = true,
		dialogueDriven = true,
		start = "CAM_BRF_WIDE",
		fov = 60,
		screen = true,
	},
}
