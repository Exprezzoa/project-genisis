--!strict
-- Shared/Modules/Types.lua  (docs/16_technical_architecture.md §1.8)
--
-- Shared exported types. Add a type here when two or more modules need it.

-- A server Service or client Controller: Init creates state (no cross-module calls),
-- Start connects events and may call other modules (docs/16 §1.3).
export type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
	[string]: any,
}

-- docs/17_saving_progression_monetization.md §2
export type Settings = {
	camSensitivity: number,
	invertY: boolean,
	cameraShake: number,
	sprintToggle: boolean,
	strideToggle: boolean,
	subtitles: boolean,
	subtitleSize: string,
	musicVolume: number,
	sfxVolume: number,
	ambienceVolume: number,
	reduceFlashing: boolean,
	tutorialHints: boolean,
	damageNumbers: boolean,
}

export type Profile = {
	schemaVersion: number,
	createdAt: number,
	lastSaveAt: number,
	saveCount: number,
	_lock: { jobId: string, time: number }?,
	story: {
		chapter: number,
		sequenceId: string,
		checkpoint: string?,
		flags: { [string]: boolean },
		completedChapters: { [string]: boolean },
		relLog: { { var: string, delta: number, reason: string, t: number } },
	},
	relationships: { [string]: number },
	evidence: { [string]: number },
	progression: {
		xp: number,
		rank: number,
		credits: number,
		grants: { [string]: boolean },
		upgrades: { [string]: boolean },
	},
	cosmetics: { owned: { [string]: boolean }, equipped: { framePaint: string, suit: string } },
	settings: Settings,
	purchases: { receipts: { [string]: number } },
	stats: { titansDefeated: number, framesDisabled: number, playTimeSec: number },
}

return {}
