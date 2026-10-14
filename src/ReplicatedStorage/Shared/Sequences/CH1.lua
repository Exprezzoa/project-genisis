--!nonstrict
-- Shared/Sequences/CH1.lua  (docs/13_missions_dialogue_relationships.md §1; docs/05_chapter1_script.md)
--
-- Chapter 1 as data for the Sequence Runner. So far: the deployment from boarding to the launch (S08-S10) and the
-- Outpost 07 mission to the return (S20-S33). The other hub scenes (S01-S07, S40-S43) come with Phase 5, and so do
-- the cinematics: for now the Strider just rises while its lines play, the Watcher is a stand-in the player
-- watches from the cockpit (no choice C3 yet), and S33's anomaly is a fade to black. Mara's Unit 01 is the "ally" action
-- (AllyFrameService): she follows on the road and the trail, holds in the courtyard and at the regroup mark, and
-- fights beside the player.
-- Step ids follow the script's scene numbers. A step with `checkpoint` saves when it completes, or when it
-- begins with checkpointOnEnter (docs/13 §1.1). `checkpoints` says which step a saved checkpoint loads into
-- (docs/05 §11); that step's onRestore puts the player where the table says.

local CLUES = { "INT_CLUE_A", "INT_CLUE_B", "INT_CLUE_C" }
local CLUE_FLAGS = { INT_CLUE_A = "CH1_CLUE_A", INT_CLUE_B = "CH1_CLUE_B", INT_CLUE_C = "CH1_CLUE_C" }
local POWER_ON = { "zoneState", zone = "Outpost07", key = "Power", value = true }
local STRIDER_DORMANT = { "spawnTitan", type = "Strider", id = "STRIDER", spawn = "TITAN_STRIDER_DORMANT", state = "Dormant", firstSweepWindup = 1.8 }
-- Mara's Unit 01 (docs/09 §7): where she is and what she does in each step.
local MARA_COURTYARD = { "ally", mode = "Hold", place = "MARK_MARA_COURTYARD", at = "MARK_MARA_COURTYARD" }
local MARA_REGROUP = { "ally", mode = "Hold", place = "MARK_MARA_REGROUP", at = "MARK_MARA_REGROUP" }
local TUT_DISMOUNT = { "tutorial", id = "TUT_DISMOUNT", text = "DISMOUNT — Stand on a landing pad and use the prompt. You can only leave your Frame on pads." }
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
	},
	steps = {
		{
			-- Until S01-S07 are written (Phase 5) a new profile starts here, on foot where it spawned; CH1_BRIEFED puts
			-- the player at the briefing room door in the morning (docs/05 §11).
			id = "S08_BOARD",
			onRestore = {
				{ "lighting", preset = "MORNING", instant = true }, { "frame", command = "park", spawn = "SPAWN_BRF_DOOR" }, { "ally", mode = "Parked" },
			},
			objective = "OBJ_CH1_BOARD",
			waypoint = { spawn = "WP_BAY2_BRIDGE" },
			complete = { "event", name = "FrameBoarded" },
			onComplete = {
				{ "dialogue", id = "DLG_CH1_BOARD" },
				{ "tutorial", id = "TUT_MOVE", text = "MOVE — WASD / Left Stick / Thumbstick. Your Frame is heavy: it takes time to speed up and turn. Hold SHIFT / L3 for Stride." },
			},
		},
		{
			-- The door rises in 4 s (map_02 §4); the two shots of S09 are Phase 5's, so the player keeps control.
			id = "S09_DOOR",
			objective = "OBJ_CH1_DOOR",
			waypoint = { spawn = "WP_DEPLOY_DOOR" },
			complete = { "trigger", id = "TRG_DEPLOY_DOOR", who = "frame" },
			onComplete = {
				{ "door", id = "DOOR_HANGAR_EAST", open = true },
				{ "dialogue", id = "DLG_CH1_DOOR" },
			},
		},
		{
			-- Launch (docs/05 S10): the Frame walks itself east along the causeway while the Bulwark's gate opens (6 s),
			-- black at 7 s, the transit card, then the outpost (S20). The crane shot is Phase 5's.
			id = "S10_LAUNCH",
			objective = "OBJ_CH1_LAUNCH",
			waypoint = { spawn = "WP_LAUNCH_CENTER" },
			complete = { "proximity", spawn = "WP_LAUNCH_CENTER", radius = 20 },
			onComplete = {
				{ "dialogue", id = "DLG_CH1_LAUNCH" },
				{ "frame", command = "autoWalk", to = "AUTO_CAUSEWAY_END" },
				{ "door", id = "DOOR_BULWARK_GATE", open = true },
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
			onEnter = {
				{ "titanCommand", id = "STRIDER", command = "Rise" },
				{ "ally", mode = "Hold", face = "TITAN_STRIDER_DORMANT" },
				{ "wait", seconds = 2.5 },
				{ "dialogue", id = "DLG_M01_CONTACT", block = true },
				{ "titanCommand", id = "STRIDER", command = "StartFight" },
				{ "objective", id = "OBJ_M01_FIGHT" }, -- set when ST_03 finishes (docs/05 §13)
				{ "ally", mode = "Combat" },
				{ "tutorial", id = "TUT_LOCK", text = "LOCK ON — R / R3 / LOCK. Cycle targets with C / D-pad ← → / tap LOCK again." },
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
			},
			onFail = {
				{ "dialogue", id = "DLG_M01_FAIL", block = true },
				{ "fade", to = 1, duration = 0.35 },
			},
			complete = { "event", name = "TitanDefeated" },
			onComplete = {
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
				{ "dialogue", id = "DLG_M01_WATCHER_1", block = true },
				-- Beat 4: down the ridge to the rover in 12 s while Vale and Mara talk; beat 5: the roof, the canister.
				{ "dialogue", id = "DLG_M01_WATCHER_2" },
				{ "titanCommand", id = "WATCHER", command = "WatcherPath", nodes = { "W1", "W2", "W3" }, seconds = 12, block = true },
				{ "titanCommand", id = "WATCHER", command = "PeelRover" },
				{ "titanCommand", id = "WATCHER", command = "TakeCanister" },
				-- Beat 6: it looks straight at Unit 02 for 1.5 s.
				{ "titanCommand", id = "WATCHER", command = "WatcherFace", target = "Frame:Player", seconds = 0.6 },
				{ "wait", seconds = 1.5 },
				{ "dialogue", id = "DLG_M01_WATCHER_3", block = true },
				{ "titanCommand", id = "WATCHER", command = "WatcherPath", nodes = { "W2", "W1", "W4", "W5" }, seconds = 8, block = true },
				{ "despawnTitan", id = "WATCHER" },
				{ "dialogue", id = "DLG_M01_WATCHER_4", block = true },
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
			-- The anomaly itself (HUD glitch, the Frame's head turning, the memory) is a Phase 5 cinematic.
			onComplete = {
				{ "toast", text = "UPLOADING SPINDLE // 61%" },
				{ "wait", seconds = 2.4 },
				{ "fade", to = 1, duration = 1.0 },
				{ "dialogue", id = "DLG_M01_DARK", block = true },
				{ "wait", seconds = 2 },
				{ "checkpoint", id = "M01_COMPLETE" },
				{ "lighting", preset = "EVENING", instant = true },
				{ "frame", command = "park", spawn = "SPAWN_HANGAR_FLOOR" },
				{ "ally", mode = "Parked" },
				{ "fade", to = 0, duration = 1.0 },
				{ "toast", text = "MISSION COMPLETE — THE SILENT OUTPOST" },
			},
		},
		{
			-- The return to the hangar. Only where M01_COMPLETE puts the player for now (docs/05 §11); Vale, Rhein and
			-- the rest of S40 come with Phase 5.
			id = "S40_RETURN",
			onRestore = {
				{ "lighting", preset = "EVENING", instant = true }, { "frame", command = "park", spawn = "SPAWN_HANGAR_FLOOR" }, { "ally", mode = "Parked" },
			},
		},
	},
}
