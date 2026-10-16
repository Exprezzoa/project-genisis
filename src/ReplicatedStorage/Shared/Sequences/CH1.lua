--!nonstrict
-- Shared/Sequences/CH1.lua  (docs/13_missions_dialogue_relationships.md §1; docs/05_chapter1_script.md)
--
-- Chapter 1 as data for the Sequence Runner, S01 to S43 and the free roam after it: the morning in the hub (S01-S07),
-- the deployment (S08-S10), the Outpost 07 mission (S20-S33) with its cinematics (the Strider's rise, the Watcher
-- and choice C3, the anomaly), and the evening (S40-S43: Vale and Rhein, Voss and choice C4, Mara on the deck, the
-- message). The Watcher is still the stand-in model slid along its path (its rig pass is to come). Mara's Unit 01
-- is the "ally" action
-- (AllyFrameService): she follows on the road and the trail, holds in the courtyard and at the regroup mark, and
-- fights beside the player.
-- Step ids follow the script's scene numbers. A step with `checkpoint` saves when it completes, or when it
-- begins with checkpointOnEnter (docs/13 §1.1). `checkpoints` says which step a saved checkpoint loads into
-- (docs/05 §11); that step's onRestore puts the player where the table says.

-- The Central Command PA (docs/05 S03) and where it can be heard: the building, not the hangar or the yard.
local PA_LINES = { "DLG_CH1_PA_A1", "DLG_CH1_PA_A2", "DLG_CH1_PA_A3", "DLG_CH1_PA_A4" }
local PA_EVENING = { "DLG_CH1_PA_E1", "DLG_CH1_PA_E2", "DLG_CH1_PA_E3" }
local CENTRAL_COMMAND = { "Quarters", "Briefing", "Medical", "Equipment", "Research", "OpsHall", "Corridors", "Arrival", "ObservationDeck" }
local CLUES = { "INT_CLUE_A", "INT_CLUE_B", "INT_CLUE_C" }
local CLUE_FLAGS = { INT_CLUE_A = "CH1_CLUE_A", INT_CLUE_B = "CH1_CLUE_B", INT_CLUE_C = "CH1_CLUE_C" }
local POWER_ON = { "zoneState", zone = "Outpost07", key = "Power", value = true }
local STRIDER_DORMANT = { "spawnTitan", type = "Strider", id = "STRIDER", spawn = "TITAN_STRIDER_DORMANT", state = "Dormant", firstSweepWindup = 1.8 }
-- Mara's Unit 01 (docs/09 §7): where she is and what she does in each step.
local MARA_COURTYARD = { "ally", mode = "Hold", place = "MARK_MARA_COURTYARD", at = "MARK_MARA_COURTYARD" }
local MARA_REGROUP = { "ally", mode = "Hold", place = "MARK_MARA_REGROUP", at = "MARK_MARA_REGROUP" }
local TUT_DISMOUNT = { "tutorial", id = "TUT_DISMOUNT" }
-- The fight's tutorials (docs/05 S28 table): LOCK at the start, the rest when their conditions hold on the client.
local FIGHT_TUTORIALS = {
	{ "tutorial", id = "TUT_LOCK" },
	{ "tutorial", id = "TUT_DODGE", arm = true },
	{ "tutorial", id = "TUT_SPECIAL", arm = true },
	{ "tutorial", id = "TUT_CORE", arm = true },
	{ "tutorial", id = "TUT_REGEN", arm = true },
}
-- A clue's prompt stays off for a player who found it before a reload.
local CLUE_PROMPTS = {
	{ "prompt", id = "INT_CLUE_A", enabled = true, unlessFlag = "CH1_CLUE_A" },
	{ "prompt", id = "INT_CLUE_B", enabled = true, unlessFlag = "CH1_CLUE_B" },
	{ "prompt", id = "INT_CLUE_C", enabled = true, unlessFlag = "CH1_CLUE_C" },
}

local function clue(letter)
	local id = "INT_CLUE_" .. letter
	return { when = { "interact", id = id }, actions = { { "prompt", id = id, enabled = false }, { "dialogue", id = "DLG_M01_CLUE_" .. letter } } }
end

return {
	id = "CH1",
	title = "THE LAST QUIET MORNING",
	checkpoints = {
		CH1_BRIEFED = "S08_BOARD",
		CH1_DEPLOYED = "S20_ARRIVAL",
		M01_POWER = "S23_DISMOUNT",
		M01_COMMS = "S25_INVESTIGATE",
		M01_TRAIL = "S27_TRAIL",
		M01_FIGHT = "S28_STRIDER",
		M01_TITAN_DOWN = "S31_WATCHER",
		M01_COMPLETE = "S40_RETURN",
		CH1_RETURNED = "S40_RETURN",
		CH1_MEDICAL = "S42_EVENING",
		CH1_COMPLETE = "S50_FREE_ROAM",
	},
	steps = {
		{
			-- S01 (docs/05): black, the title card, the morning broadcast; on S01_04 the picture comes up in Q-3, at
			-- the desk, and control returns.
			id = "S01_COLD_OPEN",
			onEnter = {
				{ "fade", to = 1, duration = 0 },
				{ "controls", locked = true },
				{ "lighting", preset = "MORNING", instant = true },
				{ "frame", command = "park", spawn = "SPAWN_Q3_DESK" },
				{ "ally", mode = "Parked" },
				{ "npcs", set = "HUB_MORNING" },
				{ "card", kind = "Title", lines = { "2187", "NEW HALDEN — HALDEN CENTRAL COMMAND" }, times = { 1.5, 2.5 } },
				{ "dialogue", id = "DLG_CH1_COLD_OPEN" },
			},
			complete = { "line", id = "S01_04" },
			onComplete = {
				{ "fade", to = 0, duration = 1.2 },
				{ "controls", locked = false },
			},
		},
		{
			-- S02-S03: free roam from Q-3 to the hangar. The Q-3 prompts, the Ops Hall's, Tamsin and Okafor (Talk) and
			-- the officers' barks are always there; the PA plays in Central Command until the briefing.
			id = "S02_QUARTERS",
			onEnter = {
				{ "paLoop", lines = PA_LINES, every = 45, zones = CENTRAL_COMMAND, untilStep = "S07_BRIEFING" },
			},
			objective = "OBJ_CH1_HANGAR",
			waypoint = { spawn = "WP_HANGAR_ENTRANCE" },
			complete = { "trigger", id = "TRG_HANGAR_REVEAL", who = "foot" },
		},
		{
			-- S04: the hangar reveal, first entry only; then the waypoint moves to the Safe Viewing Line, where Mara is.
			id = "S04_REVEAL",
			onEnter = {
				{ "cinematic", id = "CIN_HANGAR_REVEAL", once = "SEEN_HANGAR_REVEAL" },
			},
			objective = "OBJ_CH1_HANGAR",
			waypoint = { pos = Vector3.new(0, 0, -168) },
			complete = { "proximity", spawn = "MARK_MARA_VIEW", radius = 12 },
		},
		{
			-- S05: Mara at the viewing line (choice C1); Hollis walks in for MH_14 and back after MH_18 (line actions).
			id = "S05_MARA",
			onEnter = {
				{ "dialogue", id = "DLG_CH1_MARA_HANGAR", block = true },
			},
			complete = { "timer", seconds = 0 },
		},
		{
			-- S06: Mara leads the way to Briefing Room One (a follower: she waits if the player is 30 studs behind);
			-- the walk banter in the Ops Hall; Vale is already at the lectern.
			id = "S06_WALK",
			onEnter = {
				{ "npcs", add = { "Vale" } },
				{ "npc", id = "Mara", walk = "NAV_BRF_IN", follow = true },
			},
			objective = "OBJ_CH1_BRIEFING",
			waypoint = { spawn = "WP_BRIEFING_DOOR" },
			parallel = {
				{ when = { "zone", id = "OpsHall" }, actions = { { "dialogue", id = "DLG_CH1_WALK" } } },
			},
			complete = { "trigger", id = "TRG_BRIEFING_ENTER", who = "foot" },
		},
		{
			-- S07: the briefing. Black, Elias and Mara on the tier-2 bench, the cinematic (Vale's lines cut the shots and
			-- the slides; choice C2), black, both at the door, BR_17. Checkpoint CH1_BRIEFED when it ends.
			id = "S07_BRIEFING",
			checkpoint = "CH1_BRIEFED",
			onEnter = {
				{ "fade", to = 1, duration = 0.3 },
				{ "npc", id = "Mara", stop = true },
				{ "sit", at = "SEAT_BRF_ELIAS", height = "BENCH" },
				{ "npc", id = "Mara", sit = "SEAT_BRF_MARA", height = "BENCH" },
				{ "cinematic", id = "CIN_BRIEFING", block = false },
				{ "wait", seconds = 0.4 },
				{ "fade", to = 0, duration = 0.6 },
				{ "dialogue", id = "DLG_CH1_BRIEFING", block = true },
				{ "fade", to = 1, duration = 0.6 },
				{ "cinematic", id = "CIN_BRIEFING", stop = true },
				{ "sit", stand = true, at = "SPAWN_BRF_DOOR" },
				{ "npc", id = "Mara", place = { -85, 0, -23, "+X" } },
				{ "fade", to = 0, duration = 0.6 },
				{ "dialogue", id = "DLG_CH1_BRIEF_END" },
			},
			complete = { "timer", seconds = 0 },
		},
		{
			-- After the briefing Mara walks to Bay 1 and boards: she fades out at the Bay 1 hatch and Unit 01's chest lights
			-- come on (docs/05 S07). CH1_BRIEFED loads here: the briefing room door in the morning, Mara already aboard
			-- (docs/05 §11).
			id = "S08_BOARD",
			onEnter = {
				{ "npc", id = "Mara", walk = "NAV_BAY1_HATCH", despawnAfter = true, andThen = { { "frame", command = "standby", unit = "01", on = false } } },
			},
			onRestore = {
				{ "lighting", preset = "MORNING", instant = true }, { "frame", command = "park", spawn = "SPAWN_BRF_DOOR" }, { "ally", mode = "Parked" },
				{ "frame", command = "standby", unit = "01", on = false },
				{ "npcs", set = "HUB_BRIEFED" },
			},
			objective = "OBJ_CH1_BOARD",
			waypoint = { spawn = "WP_BAY2_BRIDGE" },
			complete = { "event", name = "FrameBoarded" },
			onComplete = {
				{ "dialogue", id = "DLG_CH1_BOARD" },
				{ "tutorial", id = "TUT_MOVE" },
			},
		},
		{
			-- S09: the door rises in 4 s (map_02 §4) during the reveal (9 s; DR_01-03 are the cinematic's). Unit 01 joins
			-- at its spot behind the player's Frame as it starts and follows from there (D-084).
			id = "S09_DOOR",
			objective = "OBJ_CH1_DOOR",
			waypoint = { spawn = "WP_DEPLOY_DOOR" },
			complete = { "trigger", id = "TRG_DEPLOY_DOOR", who = "frame" },
			onComplete = {
				{ "ally", mode = "Follow", place = "follow" },
				{ "door", id = "DOOR_HANGAR_EAST", open = true },
				{ "cinematic", id = "CIN_DOOR_REVEAL" },
			},
		},
		{
			-- Launch (docs/05 S10): the Frame walks itself east along the causeway while the Bulwark's gate opens (6 s),
			-- black at 7 s under the crane shot, the transit card, then the outpost (S20). Unit 01 follows.
			id = "S10_LAUNCH",
			objective = "OBJ_CH1_LAUNCH",
			waypoint = { spawn = "WP_LAUNCH_CENTER" },
			complete = { "proximity", spawn = "WP_LAUNCH_CENTER", radius = 20 },
			onComplete = {
				{ "dialogue", id = "DLG_CH1_LAUNCH" },
				{ "frame", command = "autoWalk", to = "AUTO_CAUSEWAY_END" },
				{ "door", id = "DOOR_BULWARK_GATE", open = true },
				{ "cinematic", id = "CIN_LAUNCH", block = false },
				{ "wait", seconds = 6 },
				{ "fade", to = 1, duration = 1.0 },
				{ "frame", command = "stopWalk" },
				{ "card", kind = "Transit", lines = { "TRANSIT — 41 KM EAST", "FRONTIER OUTPOST 07 \"GREYWATCH\"" }, seconds = 3.0 },
				{ "door", id = "DOOR_HANGAR_EAST", open = false }, -- it closes after the launch (map_02 §4)
				{ "door", id = "DOOR_BULWARK_GATE", open = false },
			},
		},
		{
			id = "S20_ARRIVAL",
			checkpoint = "CH1_DEPLOYED", checkpointOnEnter = true,
			onEnter = {
				{ "fade", to = 1, duration = 0 },
				{ "lighting", preset = "OVERCAST", instant = true },
				{ "frame", command = "forceBoard", spawn = "FRAME_OP_START_02" }, -- already piloting after the launch; boards on a load
				{ "ally", mode = "Follow", place = "FRAME_OP_START_01" },
				{ "fade", to = 0, duration = 1.0 },
				{ "frame", command = "autoWalk", to = "WP_OP_SOUTHGATE", seconds = 2 }, -- both walk north 2 s, then control returns
				{ "dialogue", id = "DLG_M01_ARRIVAL" },
			},
			objective = "OBJ_M01_REACH",
			waypoint = { spawn = "WP_OP_SOUTHGATE" },
			parallel = {
				{ when = { "trigger", id = "TRG_OP_TRUCK", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRUCK" } } },
			},
			complete = { "trigger", id = "TRG_OP_SOUTHGATE", who = "frame" },
		},
		{
			id = "S21_SOUTH_GATE", -- and S22: the breaker
			checkpoint = "M01_POWER",
			onEnter = {
				{ "dialogue", id = "DLG_M01_GATE" },
				{ "prompt", id = "INT_BREAKER", enabled = true },
				{ "ally", mode = "Hold", at = "MARK_MARA_COURTYARD" }, -- docs/05 S21: she holds in the courtyard, scanning
			},
			objective = "OBJ_M01_POWER",
			waypoint = { spawn = "WP_OP_BREAKER" },
			complete = { "interact", id = "INT_BREAKER" },
			onComplete = {
				{ "prompt", id = "INT_BREAKER", enabled = false },
				POWER_ON,
				{ "dialogue", id = "DLG_M01_POWER" },
			},
		},
		{
			id = "S23_DISMOUNT",
			onEnter = { TUT_DISMOUNT },
			onRestore = { { "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "forceBoard", spawn = "FRAME_OP_BREAKER" }, MARA_COURTYARD, TUT_DISMOUNT },
			objective = "OBJ_M01_DISMOUNT",
			waypoint = { spawn = "WP_OP_PADA" },
			complete = { "event", name = "FrameDismounted" },
		},
		{
			id = "S24_COMMS",
			checkpoint = "M01_COMMS",
			onEnter = { { "prompt", id = "INT_COMMS_CONSOLE", enabled = true } },
			objective = "OBJ_M01_COMMS",
			waypoint = { spawn = "WP_OP_CONSOLE" },
			complete = { "interact", id = "INT_COMMS_CONSOLE" },
			onComplete = {
				{ "prompt", id = "INT_COMMS_CONSOLE", enabled = false },
				{ "dialogue", id = "DLG_M01_COMMS" },
			},
		},
		{
			id = "S25_INVESTIGATE",
			onEnter = CLUE_PROMPTS,
			-- On foot in the bunker, Unit 02 kneeling on Pad A where it was left (docs/05 §11).
			onRestore = {
				{ "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "kneel", spawn = "WP_OP_PADA", exit = "SPAWN_OP_BUNKER" },
				MARA_COURTYARD, table.unpack(CLUE_PROMPTS),
			},
			objective = "OBJ_M01_INVESTIGATE",
			waypoint = {
				{ interact = "INT_CLUE_A", unlessFlag = "CH1_CLUE_A" }, { interact = "INT_CLUE_B", unlessFlag = "CH1_CLUE_B" },
				{ interact = "INT_CLUE_C", unlessFlag = "CH1_CLUE_C" },
			},
			-- Found clues are kept as flags, so they survive a reload (docs/05 §11).
			complete = { "counter", ids = CLUES, n = 3, flags = CLUE_FLAGS },
			parallel = { clue("A"), clue("B"), clue("C") },
			onComplete = { { "dialogue", id = "DLG_M01_CLUES_DONE" } },
		},
		{
			id = "S26_REMOUNT",
			checkpoint = "M01_TRAIL",
			objective = "OBJ_M01_REMOUNT",
			waypoint = { entity = "Frame:Player" },
			complete = { "event", name = "FrameBoarded" },
		},
		{
			id = "S27_TRAIL",
			-- The Strider waits in the basin, crouched with its back to the trail (docs/05 S28).
			onEnter = { STRIDER_DORMANT, { "ally", mode = "Follow" } }, -- docs/05 S26: Mara joins in follow mode
			onRestore = {
				{ "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "forceBoard", spawn = "FRAME_OP_NORTHGATE" },
				{ "ally", mode = "Follow", place = "follow" }, STRIDER_DORMANT,
			},
			objective = "OBJ_M01_TRAIL",
			waypoint = { spawn = "FRAME_OP_FIGHT" },
			parallel = {
				{ when = { "trigger", id = "TRG_TRAIL_1", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_1" } } },
				{ when = { "trigger", id = "TRG_TRAIL_2", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_2" } } },
				{ when = { "trigger", id = "TRG_TRAIL_3", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_3" } } },
			},
			complete = { "trigger", id = "TRG_BASIN_ENTRY", who = "frame" },
		},
		{
			id = "S28_STRIDER", -- and S30: the fight and the victory
			checkpoint = "M01_FIGHT", checkpointOnEnter = true,
			-- The rise (docs/05 S28, 8.5 s): the cinematic runs on the client; the Rise starts with Shot 2 at 3.0 s; the
			-- lines from 6.0 s (the roar); the fight once they are said.
			onEnter = {
				{ "ally", mode = "Hold", face = "TITAN_STRIDER_DORMANT" },
				{ "mark", key = "fightFailed", value = false },
				{ "cinematic", id = "CIN_STRIDER_RISE", block = false, titan = "STRIDER" },
				{ "wait", seconds = 3.0 },
				{ "titanCommand", id = "STRIDER", command = "Rise" },
				{ "wait", seconds = 3.0 },
				{ "dialogue", id = "DLG_M01_CONTACT", block = true },
				{ "titanCommand", id = "STRIDER", command = "StartFight" },
				{ "objective", id = "OBJ_M01_FIGHT" }, -- set when ST_03 finishes (docs/05 §13)
				{ "ally", mode = "Combat" },
				{ "barks", fight = "M01", on = true },
				table.unpack(FIGHT_TUTORIALS),
			},
			-- A retry: the Frame repaired at the fight spawn, the Strider already standing, no rise (docs/05 S28).
			onRestore = {
				{ "lighting", preset = "OVERCAST", instant = true }, POWER_ON,
				{ "frame", command = "forceBoard", spawn = "FRAME_OP_FIGHT" },
				{ "frame", command = "repair" },
				{ "spawnTitan", type = "Strider", id = "STRIDER", spawn = "TITAN_STRIDER_DORMANT" },
				{ "ally", mode = "Combat", place = "follow" },
				{ "fade", to = 0, duration = 0.35 },
				{ "titanCommand", id = "STRIDER", command = "StartFight" },
				{ "objective", id = "OBJ_M01_FIGHT" },
				{ "barks", fight = "M01", on = true },
				table.unpack(FIGHT_TUTORIALS),
			},
			onFail = {
				{ "barks", fight = "M01", on = false },
				{ "mark", key = "fightFailed" }, -- no Clean Kill after a failure (docs/05 §10)
				{ "dialogue", id = "DLG_M01_FAIL", block = true },
				{ "fade", to = 1, duration = 0.35 },
			},
			parallel = {
				{ when = { "timer", seconds = 5 }, actions = { { "tutorial", id = "TUT_ATTACK" } } }, -- 5 s after the start
			},
			complete = { "event", name = "TitanDefeated" },
			onComplete = {
				{ "barks", fight = "M01", on = false },
				{ "setFlag", flag = "CH1_CLEAN_KILL", unlessMark = "fightFailed" },
				{ "ally", mode = "Hold", at = "MARK_MARA_REGROUP" }, -- docs/05 S30: Unit 01 walks to the regroup mark and waits
				{ "wait", seconds = 3 },
				{ "dialogue", id = "DLG_M01_VICTORY", block = true },
				{ "checkpoint", id = "M01_TITAN_DOWN" },
			},
		},
		{
			id = "S31_WATCHER",
			-- On a load S31 starts 2 s after the player stands at the post-fight spot (docs/05 §11).
			onRestore = {
				{ "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "forceBoard", spawn = "FRAME_OP_POSTFIGHT" },
				MARA_REGROUP,
				{ "wait", seconds = 2 },
			},
			objective = "OBJ_M01_REGROUP",
			waypoint = { spawn = "MARK_MARA_REGROUP" },
			-- Within 40 studs of where Unit 01 waits, or 25 s after the victory lines (docs/05 S31).
			complete = { "any", { "proximity", spawn = "MARK_MARA_REGROUP", radius = 40 }, { "timer", seconds = 25 } },
			onComplete = {
				{ "spawnTitan", type = "Watcher", id = "WATCHER", spawn = "TITAN_WATCHER_W0" },
				{ "ally", mode = "Hold", face = "TITAN_WATCHER_W0" }, -- Mara turns to the ridge
				-- Beat 1: over Unit 01's shoulder. Beats 2-3: the telephoto.
				{ "cinematic", id = "CIN_WATCHER", block = false, titan = "WATCHER" },
				{ "dialogue", id = "DLG_M01_WATCHER_1", block = true },
				{ "cinematic", id = "CIN_WATCHER", cue = "telephoto" },
				{ "dialogue", id = "DLG_M01_WATCHER_2", block = true },
				-- Beat 3: it tilts its head, studying them (2 s), while Orin calls it in.
				{ "titanCommand", id = "WATCHER", command = "WatcherAnim", clip = "HeadTiltStudy" },
				{ "dialogue", id = "DLG_M01_WATCHER_3", block = true },
				-- Beat 4: down the ridge to the rover in 12 s, in long careful steps, while Vale and Mara talk.
				{ "cinematic", id = "CIN_WATCHER", cue = "wide" },
				{ "dialogue", id = "DLG_M01_WATCHER_4" },
				{ "titanCommand", id = "WATCHER", command = "WatcherPath", nodes = { "W1", "W2", "W3" }, seconds = 12, block = true },
				-- Beat 5: it kneels (3 s); the roof peels back as its hand comes down (1.5 s); it lifts the canister out (1.5 s).
				{ "cinematic", id = "CIN_WATCHER", cue = "rover" },
				{ "titanCommand", id = "WATCHER", command = "WatcherAnim", clip = "KneelReach", wait = 1.5 },
				{ "titanCommand", id = "WATCHER", command = "PeelRover" },
				{ "titanCommand", id = "WATCHER", command = "TakeCanister" },
				{ "titanCommand", id = "WATCHER", command = "WatcherAnim", clip = "LiftCanister", wait = 1.5 },
				-- Beat 6: it looks straight at Unit 02 for 1.5 s (static on the player's screen).
				{ "cinematic", id = "CIN_WATCHER", cue = "reverse" },
				{ "titanCommand", id = "WATCHER", command = "WatcherLook", target = "Frame:Player" },
				{ "wait", seconds = 1.5 },
				-- Beat 7: over Unit 02; choice C3.
				{ "cinematic", id = "CIN_WATCHER", cue = "unit02" },
				{ "dialogue", id = "DLG_M01_WATCHER_5", block = true },
				-- Beat 8 (8 s): it rises and turns round (2 s) and walks east up the ridge into the fog (6 s to the top);
				-- out of sight it goes on and is removed past local X 450 (W5).
				{ "cinematic", id = "CIN_WATCHER", cue = "leave" },
				{ "titanCommand", id = "WATCHER", command = "WatcherLook", off = true },
				{ "titanCommand", id = "WATCHER", command = "WatcherAnim", clip = "RiseAndTurn", wait = 0.9 },
				{ "titanCommand", id = "WATCHER", command = "WatcherTurn", node = "W2", seconds = 1.1 },
				{ "titanCommand", id = "WATCHER", command = "WatcherPath", nodes = { "W2", "W1", "W4", "W5" }, seconds = 13, despawnAfter = true },
				{ "wait", seconds = 6 },
				{ "dialogue", id = "DLG_M01_WATCHER_6", block = true },
				{ "despawnTitan", id = "WATCHER" },
				{ "cinematic", id = "CIN_WATCHER", stop = true },
			},
		},
		{
			id = "S32_ROVER",
			onEnter = {
				{ "prompt", id = "INT_ROVER_MARKING", enabled = true },
				{ "prompt", id = "INT_ROVER_CRADLE", enabled = true },
				{ "prompt", id = "INT_ROVER_CASE", enabled = true },
			},
			objective = "OBJ_M01_ROVER",
			waypoint = { spawn = "WP_OP_PADB" },
			parallel = {
				{ when = { "interact", id = "INT_ROVER_MARKING" }, actions = { { "setFlag", flag = "CH1_SAW_ECHO" }, { "dialogue", id = "DLG_M01_ROVER_MARKING" } } },
				{ when = { "interact", id = "INT_ROVER_CRADLE" }, actions = { { "setFlag", flag = "CH1_SAW_CRADLE" }, { "dialogue", id = "DLG_M01_ROVER_CRADLE" } } },
			},
			complete = { "interact", id = "INT_ROVER_CASE" }, -- the sealed case is the one that must be opened
			onComplete = {
				{ "prompt", id = "INT_ROVER_MARKING", enabled = false },
				{ "prompt", id = "INT_ROVER_CRADLE", enabled = false },
				{ "prompt", id = "INT_ROVER_CASE", enabled = false },
				{ "setFlag", flag = "CH1_HAS_SPINDLE" },
				{ "unlock", id = "INT_ROVER_CASE" }, -- the lock light: cyan for 0.6 s, then off (clue 10)
				{ "dialogue", id = "DLG_M01_ROVER_CASE", block = true }, -- the upload objective follows RV_08
			},
		},
		{
			id = "S33_UPLOAD",
			objective = "OBJ_M01_UPLOAD",
			waypoint = { entity = "Frame:Player" },
			complete = { "event", name = "FrameBoarded" },
			-- The upload and the anomaly (docs/05 S33): the client's cinematic ends behind black; AN_01, 2 s of black, then
			-- the checkpoint, the evening, the hangar.
			onComplete = {
				{ "cinematic", id = "CIN_ANOMALY" },
				{ "fade", to = 1, duration = 0 },
				{ "dialogue", id = "DLG_M01_DARK", block = true },
				{ "wait", seconds = 2 },
				-- The mission's rewards, granted with the checkpoint (docs/05 §10; each once per profile).
				{ "grant", key = "CH1_M01_COMPLETE" },
				{ "grant", key = "CH1_STRIDER_DEFEATED" },
				{ "grant", key = "EV_OP07_LOG1", ifFlag = "EV_OP07_LOG1" },
				{ "grant", key = "EV_OP07_LOG2", ifFlag = "EV_OP07_LOG2" },
				{ "grant", key = "EV_OP07_LOG3", ifFlag = "EV_OP07_LOG3" },
				{ "grant", key = "CH1_CLEAN_KILL", ifFlag = "CH1_CLEAN_KILL" },
				{ "checkpoint", id = "M01_COMPLETE" }, -- the evening (S40) sets itself up behind the black
			},
		},
		{
			-- S40: back in the hangar in the evening (docs/05 S40). Unit 02 in Bay 2 with its vents dark, Unit 01 in Bay 1;
			-- Vale and Rhein walk in, the conversation (auto-framed), Rhein leaves with the case and the guards (the camera
			-- holds on his pin), Vale sends Elias to Medical, the Mission Complete card. A load at M01_COMPLETE or
			-- CH1_RETURNED replays it (docs/05 §11). Checkpoint CH1_RETURNED.
			id = "S40_RETURN",
			checkpoint = "CH1_RETURNED",
			onEnter = {
				{ "fade", to = 1, duration = 0 },
				{ "lighting", preset = "EVENING", instant = true },
				{ "frame", command = "park", spawn = "SPAWN_HANGAR_FLOOR" },
				{ "frame", command = "coreOffline" },
				{ "ally", mode = "Parked" },
				{ "npcs", set = "HUB_EVENING" },
				{ "fade", to = 0, duration = 1.0 },
				{ "npc", id = "ValeReturn", walk = "MARK_VALE_RETURN" },
				{ "npc", id = "Rhein", walk = "MARK_RHEIN_RETURN", block = true },
				{ "cinematic", id = "CIN_RETURN", block = false },
				{ "dialogue", id = "DLG_CH1_RETURN_1", block = true },
				{ "npc", id = "Rhein", walk = "NAV_GATE_S", despawnAfter = true },
				{ "cinematic", id = "CIN_RETURN", cue = "pin" },
				{ "npc", id = "GuardS1", walk = "NAV_GATE_S", despawnAfter = true },
				{ "npc", id = "GuardS2", walk = "NAV_GATE_S", despawnAfter = true },
				{ "npc", id = "GuardS3", walk = "NAV_GATE_S", despawnAfter = true },
				{ "wait", seconds = 1.0 },
				{ "dialogue", id = "DLG_CH1_RETURN_2", block = true },
				{ "cinematic", id = "CIN_RETURN", stop = true },
				-- Granted at M01_COMPLETE already; again here for a profile saved past it before rewards existed (nothing twice).
				{ "grant", key = "CH1_M01_COMPLETE" },
				{ "grant", key = "CH1_STRIDER_DEFEATED" },
				{ "grant", key = "EV_OP07_LOG1", ifFlag = "EV_OP07_LOG1" },
				{ "grant", key = "EV_OP07_LOG2", ifFlag = "EV_OP07_LOG2" },
				{ "grant", key = "EV_OP07_LOG3", ifFlag = "EV_OP07_LOG3" },
				{ "grant", key = "CH1_CLEAN_KILL", ifFlag = "CH1_CLEAN_KILL" },
				{ "card", kind = "MissionComplete" },
				{ "objective", id = "OBJ_CH1_MEDICAL" },
				{ "paLoop", lines = PA_EVENING, every = 45, zones = CENTRAL_COMMAND, untilStep = "S50_FREE_ROAM" },
			},
			waypoint = { spawn = "WP_MEDICAL_ARCH" },
			complete = { "timer", seconds = 0 },
		},
		{
			-- S41: Medical. Stepping into the scanner arch: the beam sweeps twice while Voss talks (choice C4); Mara goes up
			-- to the Observation Deck. Checkpoint CH1_MEDICAL.
			id = "S41_MEDICAL",
			checkpoint = "CH1_MEDICAL",
			objective = "OBJ_CH1_MEDICAL",
			waypoint = { spawn = "WP_MEDICAL_ARCH" },
			complete = { "trigger", id = "TRG_MED_ARCH", who = "foot" },
			onComplete = {
				{ "scanBeam", sweeps = 2, seconds = 2.0, block = false },
				{ "dialogue", id = "DLG_CH1_MEDICAL", block = true },
				{ "npcs", add = { "MaraDeck" } },
			},
		},
		{
			-- S42 (optional) and S43: Mara on the Observation Deck within 10 studs (her conversation, CH1_DECK_SCENE, then she
			-- leaves by the stairwell); the Q-3 terminal blinks 1 NEW MESSAGE, and reading it is S43: the message, the
			-- photo, black, the Chapter End card, behind which the hub turns to night. CH1_MEDICAL loads here (docs/05 §11:
			-- the Medical Bay door).
			id = "S42_EVENING",
			onEnter = {
				{ "terminalMessage" },
				{ "prompt", id = "INT_Q3_TERMINAL", enabled = true },
			},
			onRestore = {
				{ "lighting", preset = "EVENING", instant = true },
				{ "frame", command = "park", spawn = "SPAWN_MED_DOOR" },
				{ "frame", command = "coreOffline" },
				{ "ally", mode = "Parked" },
				{ "npcs", set = "HUB_EVENING" },
				{ "npcs", remove = { "ValeReturn", "Rhein", "TechCase", "GuardS1", "GuardS2", "GuardS3" } },
				{ "npcs", add = { "MaraDeck" }, unlessFlag = "CH1_DECK_SCENE" },
				{ "optional", ids = {}, ifFlag = "CH1_DECK_SCENE" },
				{ "terminalMessage" },
				{ "prompt", id = "INT_Q3_TERMINAL", enabled = true },
				{ "paLoop", lines = PA_EVENING, every = 45, zones = CENTRAL_COMMAND, untilStep = "S50_FREE_ROAM" },
			},
			objective = "OBJ_CH1_REST",
			optional = { "OBJ_CH1_DECK_OPT" },
			waypoint = { spawn = "WP_QUARTERS" },
			parallel = {
				{
					when = { "proximity", spawn = "MARK_MARA_DECK", radius = 10 },
					actions = {
						{ "dialogue", id = "DLG_CH1_DECK", block = true, unlessFlag = "CH1_DECK_SCENE" },
						{ "optional", ids = {} },
						{ "npc", id = "MaraDeck", walk = "NAV_STAIR_T", despawnAfter = true },
					},
				},
			},
			complete = { "interact", id = "INT_Q3_TERMINAL" },
			onComplete = {
				{ "terminalMessage", on = false },
				{ "prompt", id = "INT_Q3_TERMINAL", enabled = false },
				{ "optional", ids = {} },
				{ "cinematic", id = "CIN_MESSAGE" },
				{
					"card", kind = "ChapterEnd",
					behind = {
						{ "lighting", preset = "NIGHT", instant = true },
						{ "teleport", spawn = "SPAWN_QH" },
						{ "npcs", remove = "all" },
					},
				},
			},
		},
		{
			-- After the chapter (docs/05 S43): free roam in the hub at night (the Training Yard is open). CH1_COMPLETE.
			id = "S50_FREE_ROAM",
			checkpoint = "CH1_COMPLETE", checkpointOnEnter = true,
			onRestore = {
				{ "lighting", preset = "NIGHT", instant = true },
				{ "frame", command = "park", spawn = "SPAWN_QH" },
				{ "frame", command = "coreOffline" },
				{ "ally", mode = "Parked" },
				{ "npcs", remove = "all" },
				{ "terminalMessage", on = false },
				{ "prompt", id = "INT_Q3_TERMINAL", enabled = false },
			},
		},
	},
}
