--!strict
-- Server/Sequence/StaticInteractions.lua  (docs/05_chapter1_script.md S02-S03, docs/maps/map_01 §10)
--
-- Interactables that always answer the same way, whatever the story step: Elias's thoughts in the hub.
-- InteractionService registers one handler per entry.
--   first      line shown on the first use (node id in the dialogue below)
--   again      line shown on later uses (default: the first line again)
--   firstOnly  no line after the first use
--   flag       story flag set on use; a "Once" prompt stays off for a player who already has it
--   toast      toast shown on every use

export type Entry = { first: string, again: string?, firstOnly: boolean?, flag: string?, toast: string? }

local entries: { [string]: Entry } = {
	INT_Q3_PHOTO = { first = "S02_PHOTO_1", again = "S02_PHOTO_2" },
	INT_Q3_LOCKER = { first = "S02_LOCKER", flag = "CH1_TOOK_PATCH" },
	INT_Q3_WINDOW = { first = "S02_WINDOW" },
	INT_STATUS_WALL = { first = "S03_BOARD" },
	INT_POSTER = { first = "S03_POSTER" },
	INT_HOLO = { first = "S03_HOLO" },
	INT_RESEARCH_DOOR = { first = "S03_RESEARCH_DOOR", firstOnly = true, toast = "ACCESS DENIED" },
}

return {
	DIALOGUE = "DLG_CH1_THOUGHTS",
	SEEN_PREFIX = "SEEN_", -- flag "SEEN_<InteractId>" marks the first use
	entries = entries,
}
