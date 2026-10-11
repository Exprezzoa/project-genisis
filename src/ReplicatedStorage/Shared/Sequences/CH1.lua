--!nonstrict
-- Shared/Sequences/CH1.lua  (docs/13_missions_dialogue_relationships.md §1; docs/05_chapter1_script.md)
--
-- Chapter 1 as data for the Sequence Runner. So far: the Outpost 07 mission from the arrival to the basin's edge
-- (S20-S27). The hub scenes (S01-S10) come with Phase 5, the fight and what follows (S28-S33) next.
-- Step ids follow the script's scene numbers. A step with `checkpoint` saves when it completes, or when it
-- begins with checkpointOnEnter (docs/13 §1.1). `checkpoints` says which step a saved checkpoint loads into
-- (docs/05 §11); that step's onRestore puts the player where the table says.

local CLUES = { "INT_CLUE_A", "INT_CLUE_B", "INT_CLUE_C" }
local CLUE_FLAGS = { INT_CLUE_A = "CH1_CLUE_A", INT_CLUE_B = "CH1_CLUE_B", INT_CLUE_C = "CH1_CLUE_C" }
local POWER_ON = { "zoneState", zone = "Outpost07", key = "Power", value = true }
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
		CH1_DEPLOYED = "S20_ARRIVAL",
		M01_POWER = "S23_DISMOUNT",
		M01_COMMS = "S25_INVESTIGATE",
		M01_TRAIL = "S27_TRAIL",
	},
	steps = {
		{
			id = "S20_ARRIVAL",
			checkpoint = "CH1_DEPLOYED", checkpointOnEnter = true,
			onEnter = {
				{ "fade", to = 1, duration = 0 },
				{ "lighting", preset = "OVERCAST", instant = true },
				{ "frame", command = "forceBoard", spawn = "FRAME_OP_START_02" }, -- already piloting after the launch; boards on a load
				{ "fade", to = 0, duration = 1.0 },
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
			onRestore = { { "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "forceBoard", spawn = "FRAME_OP_BREAKER" }, TUT_DISMOUNT },
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
			onRestore = { { "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "teleport", spawn = "SPAWN_OP_BUNKER" }, table.unpack(CLUE_PROMPTS) },
			objective = "OBJ_M01_INVESTIGATE",
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
			onRestore = { { "lighting", preset = "OVERCAST", instant = true }, POWER_ON, { "frame", command = "forceBoard", spawn = "FRAME_OP_NORTHGATE" } },
			objective = "OBJ_M01_TRAIL",
			waypoint = { spawn = "FRAME_OP_FIGHT" },
			parallel = {
				{ when = { "trigger", id = "TRG_TRAIL_1", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_1" } } },
				{ when = { "trigger", id = "TRG_TRAIL_2", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_2" } } },
				{ when = { "trigger", id = "TRG_TRAIL_3", who = "frame" }, actions = { { "dialogue", id = "DLG_M01_TRAIL_3" } } },
			},
			complete = { "trigger", id = "TRG_BASIN_ENTRY", who = "frame" },
		},
	},
}
