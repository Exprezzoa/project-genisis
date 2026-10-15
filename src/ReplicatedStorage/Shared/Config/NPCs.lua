--!strict
-- Shared/Config/NPCs.lua  (docs/13_missions_dialogue_relationships.md §6; placements: docs/maps/map_01 §3, §5,
-- §6, §7 and map_02 §9)
--
-- Every NPC of Chapter 1 the server can place, by id. The id is also what dialogue actions and sequence actions
-- call it (`action = { npc = "Hollis", moveTo = "MARK_HOLLIS_TALK" }`).
--   template  ServerStorage.Templates.NPCs.<template>
--   at        a SpawnId (MARK_*, SEAT_*) or { x, y, z, facing } with facing "-Z", "+X"... (the feet's point)
--   seat      sits at `at`, hips this many studs above it (an invisible seat; docs/07 §6 Chair, Bench)
--   idle      a held gesture (docs/08 §4.6): "CrossArms", "HandsBehindBack" or "Inspect" (3 s loops)
--   route     a walk that repeats: points (NavId or { x, y, z }), pingPong (there and back) or a loop,
--             a 2-6 s pause at each point, the Inspect gesture where inspect[index] is true (docs/13 §6)
--   barks     ambient bark ids, said when the player passes within Bark.RANGE (docs/05 S03)
--   talk      the Talk prompt TALK_<ID>: the first dialogue, the one after (again), or once only
--   speaker   the dialogue speaker code, so clients know whose line is showing (TalkFidget, LookAt)
--
-- `sets` are who is out together; a sequence action places a set ({ "npcs", set = "HUB_MORNING" }).

export type Def = {
	template: string,
	at: any,
	seat: number?,
	idle: string?,
	route: { points: { any }, pingPong: boolean?, inspect: { [number]: boolean }? }?,
	barks: { string }?,
	talk: { first: string, again: string?, once: boolean? }?,
	speaker: string?,
}

-- Seated on a console chair (docs/07 §6 Chair 2 × 3.6 × 2): the stand-in chairs stand 3 studs south of the
-- console row (map_01 §3 consoles face north). The chair's seat top is 1.0 up (ours, D-081). A seated R15 body's
-- soles are 0.66 below where it sits, so sitters sink 0.25 into the cushion and their feet reach the floor.
local SINK = 0.25
local CHAIR_SEAT = 1.0 - SINK
local BENCH_SEAT = 1.8 - SINK -- docs/07 §6 Bench, 1.8 tall: feet hang about 0.9 (Q-019)
local function console(x: number, z: number): { any }
	return { x, 0, z + 3, "-Z" }
end

local defs: { [string]: Def } = {
	-- Pilot Quarters (map_01 §5): Tamsin leans on the south hallway wall, facing north.
	Tamsin = {
		template = "Tamsin", at = "MARK_TAMSIN", idle = "CrossArms", speaker = "T",
		talk = { first = "DLG_CH1_TAMSIN", again = "DLG_CH1_TAMSIN_REPEAT" },
	},
	-- Ops Hall (map_01 §3): Okafor at C1, three officers with barks at C3, C4, C7, two at C5 and C8, one on
	-- route A (map_01 §13.2).
	Okafor = {
		template = "Okafor", at = console(-36, 14), seat = CHAIR_SEAT, idle = "Inspect", speaker = "O",
		talk = { first = "DLG_CH1_OKAFOR", once = true },
	},
	OfficerC3 = { template = "Officer1", at = console(24, 14), seat = CHAIR_SEAT, barks = { "BARK_OPS_1" }, speaker = "OFFICER" },
	OfficerC4 = { template = "Officer2", at = console(36, 14), seat = CHAIR_SEAT, barks = { "BARK_OPS_2" }, speaker = "OFFICER" },
	OfficerC7 = { template = "Officer3", at = console(24, 26), seat = CHAIR_SEAT, barks = { "BARK_OPS_3" }, speaker = "OFFICER" },
	OfficerC5 = { template = "Officer4", at = console(-36, 26), seat = CHAIR_SEAT },
	OfficerC8 = { template = "Officer5", at = console(36, 26), seat = CHAIR_SEAT },
	OfficerRouteA = {
		template = "Officer6", at = "NAV_OPS_C", idle = "HandsBehindBack",
		route = { points = { "NAV_OPS_C", "NAV_OPS_E", "NAV_EC_MID", "NAV_EC_EQ" }, pingPong = true, inspect = { [4] = true } },
	},
	-- Briefing Room One (map_01 §6): Vale behind the lectern, facing east (placed when S06 starts).
	Vale = { template = "Vale", at = { -123.5, 0, -20, "+X" }, idle = "CrossArms", speaker = "V" },
	-- Equipment (map_01 §7): Morrow behind the counter.
	Morrow = { template = "Morrow", at = { 120, 0, -20, "-X" }, idle = "HandsBehindBack" },
	-- Frame Hangar, morning (map_02 §9).
	Hollis = { template = "Hollis", at = "MARK_HOLLIS_START", idle = "Inspect", speaker = "H" },
	Mara = { template = "Mara", at = "MARK_MARA_VIEW", speaker = "M" },
	-- On the west scaffold deck of Bay 3 (the doc's (54, 18, -205) is the 40-stud Frame's; D-081).
	Pell = { template = "Pell", at = { 40, 26, -205, "+X" }, idle = "Inspect" },
	T1 = {
		template = "Technician1", at = { -60, 0, -150, "+Z" },
		route = { points = { { -60, 0, -150 }, { -60, 0, -100 }, { -20, 0, -100 }, { -20, 0, -150 } }, inspect = { [1] = true, [3] = true } },
	},
	T2 = { template = "Technician2", at = { -70, 0, -176, "-Z" }, idle = "Inspect" },
	T4 = { template = "Technician4", at = { -100, 45, -227, "+X" }, route = { points = { { -100, 45, -227 }, { 100, 45, -227 } }, pingPong = true } },
	T5 = { template = "Technician5", at = { 60, 0, -176, "-Z" }, idle = "Inspect" },
}

return {
	defs = defs,
	sets = {
		-- S01-S07: the hub and the hangar in the morning. Vale joins at S06 (`add`). T3 (control booth) and T6
		-- (forklift) wait for their props in the dressed pass (D-081).
		HUB_MORNING = { "Tamsin", "Okafor", "OfficerC3", "OfficerC4", "OfficerC7", "OfficerC5", "OfficerC8", "OfficerRouteA", "Morrow", "Hollis", "Mara", "Pell", "T1", "T2", "T4", "T5" },
		-- S08-S10 (and a load at CH1_BRIEFED): Mara has boarded Unit 01; Vale stays at the lectern.
		HUB_BRIEFED = { "Tamsin", "Okafor", "OfficerC3", "OfficerC4", "OfficerC7", "OfficerC5", "OfficerC8", "OfficerRouteA", "Morrow", "Hollis", "Vale", "Pell", "T1", "T2", "T4", "T5" },
	},
	-- Talk prompts (docs/05 S02: HoldDuration 0, MaxActivationDistance 8).
	Talk = { DISTANCE = 8, PREFIX = "TALK_" },
	-- Ambient barks (docs/05 S03, docs/13 §7): range, global cooldown, one at a time.
	Bark = { RANGE = 18, COOLDOWN = 6, SHOW = 3.5 },
	-- Movement (docs/08 §1.2, docs/13 §6).
	Move = { REISSUE = 7, ARRIVE = 1.5, TRIES = 3, PAUSE = { 2, 6 }, FOLLOW_WAIT = 30, WALK = 14, SPRINT = 22 },
	-- Turning to face the player in a conversation (D-081): seconds for the turn there and back.
	TURN = 0.4,
	-- Where sitters sit, above the seat mark (NPCService.sit; the briefing benches in S07).
	Seat = { CHAIR = CHAIR_SEAT, BENCH = BENCH_SEAT },
}
