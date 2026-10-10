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
