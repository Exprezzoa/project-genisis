--!strict
-- Shared/Dialogue/CH1_Hub.lua  (docs/05_chapter1_script.md S02-S03; format: docs/13 §2)
--
-- Chapter 1 hub dialogue. Phase 1 holds only Elias's optional thoughts on the hub's interactables; the
-- conversations (DLG_CH1_...) are added in Phase 5. Line ids and text are exactly the script's.
-- [E-thought] lines use speaker "E" with style "thought" (italic subtitle, no name).

return {
	DLG_CH1_THOUGHTS = {
		mode = "radio",
		nodes = {
			S02_PHOTO_1 = { speaker = "E", style = "thought", text = "Dad's last unit photo. Ninth Frontier Defense. He's the one not smiling." },
			S02_PHOTO_2 = { speaker = "E", style = "thought", text = "Six years. They never found anything." },
			S02_LOCKER = { speaker = "E", style = "thought", text = "His old patch. For luck." },
			S02_WINDOW = { speaker = "E", style = "thought", text = "Ash on the glass again." },
			S03_BOARD = { speaker = "E", style = "thought", text = "Outpost Seven: report overdue. Six hours." },
			S03_POSTER = { speaker = "E", style = "thought", text = "\"The Frame stands, humanity stands.\" Dad had this one in the kitchen." },
			S03_HOLO = { speaker = "E", style = "thought", text = "Forty-one kilometers to Seven. Feels further on the map." },
			-- map_01 §10 gives this line without an id; the id is ours (D-030).
			S03_RESEARCH_DOOR = { speaker = "E", style = "thought", text = "Clearance three. Not today." },
		},
	},
}
