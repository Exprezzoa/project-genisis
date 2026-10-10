--!strict
-- Shared/Config/Bindings.lua  (docs/11_controls_and_camera.md §1)
--
-- Action -> inputs per input context, bound through ContextActionService by InputController.
-- Movement, camera, jump and ProximityPrompt interaction (E / X / tap) stay with the Roblox defaults.
-- Lock-on (R, C) arrives with the Titans; the Dialogue and Cinematic contexts with Phase 5.

local K = Enum.KeyCode
local M = Enum.UserInputType

local MENU_KEYS = {
	MissionLog = { K.Tab, K.ButtonSelect },
	Menu = { K.P, K.M, K.DPadUp },
}

return {
	OnFoot = {
		Sprint = { K.LeftShift, K.ButtonL3 },
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
	},
	Frame = {
		Stride = { K.LeftShift, K.ButtonL3 },
		Light = { M.MouseButton1, K.ButtonR1 },
		Heavy = { M.MouseButton2, K.ButtonR2 },
		Dodge = { K.Space, K.ButtonB },
		Special = { K.Q, K.ButtonL1 },
		CoreStrike = { K.F, K.ButtonY },
		MissionLog = MENU_KEYS.MissionLog,
		Menu = MENU_KEYS.Menu,
	},
	Dialogue = {},
	Cinematic = {},
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
		KeyboardMouse = { Interact = "E", Sprint = "SHIFT", Stride = "SHIFT", Light = "LMB", Heavy = "RMB", Dodge = "SPACE", Special = "Q", CoreStrike = "F", MissionLog = "TAB", Menu = "P" },
		Gamepad = { Interact = "X", Sprint = "L3", Stride = "L3", Light = "RB", Heavy = "RT", Dodge = "B", Special = "LB", CoreStrike = "Y", MissionLog = "VIEW", Menu = "D-PAD" },
		Touch = { Interact = "TAP", Sprint = "SPRINT", Stride = "STRIDE", Light = "LIGHT", Heavy = "HEAVY", Dodge = "DODGE", Special = "SPECIAL", CoreStrike = "CORE", MissionLog = "LOG", Menu = "≡" },
	},
}
