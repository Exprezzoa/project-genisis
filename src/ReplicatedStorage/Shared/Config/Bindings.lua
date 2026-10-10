--!strict
-- Shared/Config/Bindings.lua  (docs/11_controls_and_camera.md §1)
--
-- Action -> inputs per input context, bound through ContextActionService by InputController.
-- Movement, camera, jump and ProximityPrompt interaction (E / X / tap) stay with the Roblox defaults.
-- The Frame context gets its combat actions with combat; Dialogue and Cinematic with Phase 5.

local K = Enum.KeyCode

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
		KeyboardMouse = { Interact = "E", Sprint = "SHIFT", Stride = "SHIFT", MissionLog = "TAB", Menu = "P" },
		Gamepad = { Interact = "X", Sprint = "L3", Stride = "L3", MissionLog = "VIEW", Menu = "D-PAD" },
		Touch = { Interact = "TAP", Sprint = "SPRINT", Stride = "STRIDE", MissionLog = "LOG", Menu = "≡" },
	},
}
