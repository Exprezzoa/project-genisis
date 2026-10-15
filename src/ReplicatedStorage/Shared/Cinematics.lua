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
	-- S08, the first boarding only (2.2 s): a close-up from beside Elias of his hand tapping the hatch twice
	-- (TapHatch, docs/08 §4.6); the server opens the hatch at 1.2 s and fades out. The shot is placed from the
	-- character and the Frame's hatch where they are (`dynamic`).
	CIN_HATCH_TAP = {
		dynamic = "hatch",
		gesture = "TapHatch",
		shots = { { hold = true, seconds = 2.2 } },
	},
	-- S09: the deployment door rises (4 s, server) seen from outside, then from behind Unit 02 toward the
	-- launch platform, the Bulwark and the wilderness, pushing 20 studs forward; DR_01-03 over the second shot.
	CIN_DOOR_REVEAL = {
		letterbox = true,
		shots = {
			{ cam = "CAM_DOOR_EXT", seconds = 4.0, fov = 60 },
			{ cam = "CAM_DOOR_REVEAL", to = { pos = { 80, 46, -150 } }, seconds = 5.0, fov = 60 },
		},
		events = { { at = 4.0, dialogue = "DLG_CH1_DOOR" } },
	},
	-- S10: the crane shot, from beside Unit 02 rising toward the open Frame Gate; the step fades to black at 7 s.
	CIN_LAUNCH = {
		letterbox = true,
		shots = {
			{ cam = "CAM_LAUNCH_A", to = { pos = { 200, 110, -60 }, look = { 440, 40, -150 } }, seconds = 7.0, fov = 60 },
			{ hold = true, seconds = 1.0 },
		},
	},
	-- S28 (8.5 s): low behind the crouched Strider's back (dormant), up at its head as it rises (2.5 s, the server's
	-- Rise), then over Unit 02's shoulder as it turns to face it: the eyes flare, the roar (camera shake 0.6 for
	-- 1.2 s, a ring of dust). The server starts the Rise at 3.0 s; params { frame, titan }.
	CIN_STRIDER_RISE = {
		letterbox = true,
		shots = {
			{ cam = "CAM_STR_1", seconds = 3.0, fov = 60 },
			{ cam = "CAM_STR_2", seconds = 2.5, fov = 55 },
			{ dynamic = "overShoulder", seconds = 3.0, fov = 60 },
		},
		clientEvents = { { at = 6.0, fx = "TitanRoar", shake = 0.6, duration = 1.2 } },
	},
	-- S31 (~45 s): the Watcher, cued beat by beat by the server (`cues`; docs/05 S31's table). params { frame,
	-- titan = the Watcher }. Beats 2-3 share the telephoto; beat 6's static comes as it looks at Unit 02.
	CIN_WATCHER = {
		letterbox = true,
		start = "ridge",
		fov = 60,
		cues = {
			ridge = { cam = "CAM_WA_1", fov = 60 }, -- 1: over Unit 01's shoulder toward the ridge
			telephoto = { cam = "CAM_WA_2", fov = 30 }, -- 2-3
			wide = { cam = "CAM_WA_3", dynamic = "track", fov = 55 }, -- 4: following it down the ridge
			rover = { cam = "CAM_WA_4", fov = 55 }, -- 5: the roof, the canister
			reverse = { dynamic = "reverse", fov = 50, fx = "Static", fxAt = 0.7 }, -- 6: it looks at Unit 02
			unit02 = { dynamic = "overShoulder", fov = 60 }, -- 7: over Unit 02, choice C3
			leave = { cam = "CAM_WA_1", dynamic = "track", fov = 60 }, -- 8: up the ridge into the fog
		},
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
