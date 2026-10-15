--!strict
-- Shared/Config/Bindings.lua  (docs/11_controls_and_camera.md §1)
--
-- Action -> inputs per input context, bound through ContextActionService by InputController.
-- Movement, camera, jump and ProximityPrompt interaction (E / X / tap) stay with the Roblox defaults.
-- The Dialogue and Cinematic contexts suspend gameplay (InputController.hold keeps a cinematic under its lines).

local K = Enum.KeyCode
local M = Enum.UserInputType

local MENU_KEYS = {
	MissionLog = { K.Tab, K.ButtonSelect },
	Menu = { K.P, K.M, K.DPadUp },
}

return {
	OnFoot = {
		Sprint = { K.LeftShift, K.ButtonL3 },
		Shift = { K.Z, K.ButtonY }, -- hold: Elias shifts into his Titan form where it is allowed (D-095)
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
	},
	-- Elias in his Titan form (D-095, D-096): it moves and fights on the Frame's keys (Light = punches, Heavy = the
	-- smash, CoreStrike = both fists into an open core); ShiftSpecial uses the selected special and NextSpecial picks
	-- the next unlocked one; hold Shift again to come back. Gamepad: X is free here (no prompts), Y is Shift.
	Shifter = {
		Stride = { K.LeftShift, K.ButtonL3 },
		ShiftLock = { K.LeftControl, K.DPadDown },
		Light = { M.MouseButton1, K.ButtonR1 },
		Heavy = { M.MouseButton2, K.ButtonR2 },
		Dodge = { K.Space, K.ButtonB },
		CoreStrike = { K.F, K.ButtonX },
		ShiftSpecial = { K.Q, K.ButtonL1 },
		NextSpecial = { K.T, K.DPadLeft },
		LockOn = { K.R, M.MouseButton3, K.ButtonR3 },
		CycleZone = { K.C, K.DPadRight },
		Shift = { K.Z, K.ButtonY },
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
	},
	Frame = {
		Stride = { K.LeftShift, K.ButtonL3 },
		ShiftLock = { K.LeftControl, K.DPadDown }, -- the Frame faces where the camera looks (D-055)
		Light = { M.MouseButton1, K.ButtonR1 },
		Heavy = { M.MouseButton2, K.ButtonR2 },
		Dodge = { K.Space, K.ButtonB },
		Special = { K.Q, K.ButtonL1 },
		CoreStrike = { K.F, K.ButtonY },
		LockOn = { K.R, M.MouseButton3, K.ButtonR3 },
		CycleZone = { K.C, K.DPadRight }, -- also the mouse wheel while locked on (LockOnController)
		CycleZoneBack = { K.DPadLeft },
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
	},
	-- A conversation or a cinematic with choices (DialogueController); clicks and taps go to the box and buttons.
	Dialogue = {
		Advance = { K.Space, K.Return, K.E, K.ButtonA },
		Choice1 = { K.One }, Choice2 = { K.Two }, Choice3 = { K.Three }, Choice4 = { K.Four },
		ChoiceUp = { K.Up, K.DPadUp }, ChoiceDown = { K.Down, K.DPadDown },
	},
	-- A playing cinematic: hold to skip (docs/11 §1: 1.0 s; only seen or skippable ones). Touch: the SKIP button.
	Cinematic = {
		Skip = { K.Space, K.ButtonA },
	},
	-- While a menu is open the same keys close it; B closes too.
	Menu = {
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
		Back = { K.ButtonB },
	},

	-- Inputs that toggle instead of hold, whatever the setting says (docs/11 §1: L3 is a toggle).
	ToggleInputs = { [K.ButtonL3] = true },

	-- Glyph text per device for the UI (docs/11 §1 "Device glyphs").
	Glyphs = {
		KeyboardMouse = { Interact = "E", Shift = "Z", ShiftSpecial = "Q", NextSpecial = "T", Sprint = "SHIFT", Stride = "SHIFT", ShiftLock = "CTRL", Light = "LMB", Heavy = "RMB", Dodge = "SPACE", Special = "Q", CoreStrike = "F", LockOn = "R", CycleZone = "C", MissionLog = "TAB", Menu = "P", Skip = "SPACE" },
		Gamepad = { Interact = "X", Shift = "Y", ShiftSpecial = "LB", NextSpecial = "D-PAD LEFT", Sprint = "L3", Stride = "L3", ShiftLock = "D-PAD DOWN", Light = "RB", Heavy = "RT", Dodge = "B", Special = "LB", CoreStrike = "Y", LockOn = "R3", CycleZone = "D-PAD RIGHT", MissionLog = "VIEW", Menu = "D-PAD", Skip = "A" },
		Touch = { Interact = "TAP", Shift = "SHIFT", ShiftSpecial = "SPECIAL", NextSpecial = "NEXT", Sprint = "SPRINT", Stride = "STRIDE", ShiftLock = "AIM", Light = "LIGHT", Heavy = "HEAVY", Dodge = "DODGE", Special = "SPECIAL", CoreStrike = "CORE", LockOn = "LOCK", CycleZone = "LOCK", MissionLog = "LOG", Menu = "≡", Skip = "SKIP" },
	},
}
