--!strict
-- Shared/Config/GameConfig.lua
--
-- Game-wide constants that don't belong to a more specific config module.

local GameConfig = {}

-- On-foot character (docs/08_rigs_and_animation.md §1.1, docs/11_controls_and_camera.md §3, docs/13 §6).
GameConfig.Character = {
	WALK_SPEED = 14,
	SPRINT_SPEED = 22,
	JUMP_HEIGHT = 7.2,
	CAMERA_MIN_ZOOM = 6,
	CAMERA_MAX_ZOOM = 22,
	CAMERA_FOV = 70,
	RESPAWN_DELAY = 2, -- seconds between losing the character (fall, reset) and the respawn
}

-- Server polling (docs/13 §5: triggers are checked every 0.2 s; zones use the same rate).
GameConfig.Tick = {
	TRIGGERS = 0.2,
	ZONES = 0.2,
}

GameConfig.Interaction = {
	-- Added to a prompt's MaxActivationDistance when the server re-checks the distance (latency allowance).
	DISTANCE_SLACK = 4,
	-- Frame-scale prompts (docs/13 §4 gives 30 studs, for the 40-stud Frame). The engine measures a prompt from
	-- the player's character, and the pilot of a 64-stud Frame sits about 49 studs up: with 30 no Frame prompt
	-- could be reached at all (D-068). So the prompt itself gets FRAME_PROMPT_DISTANCE, which covers the seat's
	-- height, and the server checks what the doc means: the Frame's root within FRAME_REACH of the prompt,
	-- measured along the ground (30 x 1.6).
	FRAME_PROMPT_DISTANCE = 70,
	FRAME_REACH = 48,
}

-- Saving (docs/17_saving_progression_monetization.md §2-5).
GameConfig.Data = {
	STORE = "PG_Profiles_v1",
	KEY_PREFIX = "u_",
	-- 5 attempts; the delay (plus 0..RETRY_JITTER s) is waited after a failed attempt.
	RETRY_DELAYS = { 1, 2, 4, 8, 16 },
	RETRY_JITTER = 0.5,
	LOCK_TIMEOUT = 600, -- a session lock older than this is ignored
	LOCK_WAIT = 5, -- seconds between tries while another server holds the lock
	LOCK_TRIES = 6, -- then the lock is stolen (about 30 s)
	AUTOSAVE_INTERVAL = 120,
	MIN_SAVE_INTERVAL = 6, -- never more than one write per key in this many seconds
	MIN_BUDGET = 2, -- autosaves are deferred while the UpdateAsync budget is below this
	CLOSE_TIMEOUT = 25, -- BindToClose waits this long for the final saves
	SNAPSHOT_INTERVAL = 0.5, -- Profile_Snapshot at most 2 per second
	DEFAULT_SPAWN = "SPAWN_Q3_DESK",
}

-- Player settings: defaults from the profile schema (docs/17 §2), ranges from the Settings menu (docs/14 §8).
-- The server validates Settings_Update against this table; the Settings menu builds its rows from it.
GameConfig.Settings = {
	camSensitivity = { kind = "number", default = 1.0, min = 0.2, max = 2.0 },
	invertY = { kind = "boolean", default = false },
	cameraShake = { kind = "number", default = 1.0, min = 0, max = 1 },
	sprintToggle = { kind = "boolean", default = false },
	strideToggle = { kind = "boolean", default = false },
	subtitles = { kind = "boolean", default = true },
	subtitleSize = { kind = "enum", default = "M", values = { "S", "M", "L" } },
	musicVolume = { kind = "number", default = 0.6, min = 0, max = 1 },
	sfxVolume = { kind = "number", default = 0.9, min = 0, max = 1 },
	ambienceVolume = { kind = "number", default = 0.7, min = 0, max = 1 },
	reduceFlashing = { kind = "boolean", default = false },
	tutorialHints = { kind = "boolean", default = true },
	damageNumbers = { kind = "boolean", default = false },
}

return GameConfig
