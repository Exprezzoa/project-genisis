--!strict
-- Client/Controllers/InputController.lua  (docs/11_controls_and_camera.md)
--
-- Input contexts and bindings (Config/Bindings) through ContextActionService, plus the device in use.
-- Exactly one context is bound at a time: a gameplay context (OnFoot, Frame, Shifter) or one that suspends it
-- (Dialogue, Cinematic, Menu). restoreGameplay() goes back to the last gameplay context, or to the held
-- context: hold("Cinematic") keeps a playing cinematic under the dialogue or menu opened over it.
--
--   setContext(name)   restoreGameplay()   getContext()   isGameplay()   hold(name?)   getHold()   setGameplayContext(name)
--   getDevice() -> "KeyboardMouse" | "Gamepad" | "Touch"        glyph(action) -> string
--   ActionPressed(action, began: boolean, input)   ContextChanged(name)   DeviceChanged(device)
--   press(action, began)   -- for on-screen buttons

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared.Config.Bindings)
local Signal = require(Shared.Modules.Signal)

local ACTION_PREFIX = "PG_"
local GAMEPLAY = { OnFoot = true, Frame = true, Shifter = true }

local InputController = {}

InputController.ActionPressed = Signal.new() :: Signal.Signal<string, boolean, InputObject?>
InputController.ContextChanged = Signal.new() :: Signal.Signal<string>
InputController.DeviceChanged = Signal.new() :: Signal.Signal<string>

local context: string? = nil
local gameplayContext = "OnFoot"
local held: string? = nil
local bound: { string } = {}
local device = "KeyboardMouse"

local function deviceFor(inputType: Enum.UserInputType): string?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(inputType.Name, "Gamepad", 1, true) then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse", 1, true) then
		return "KeyboardMouse"
	end
	return nil
end

function InputController.getDevice(): string
	return device
end

function InputController.getContext(): string?
	return context
end

function InputController.isGameplay(): boolean
	return context ~= nil and GAMEPLAY[context] == true
end

-- The glyph text of an action for the device in use.
function InputController.glyph(action: string): string
	local set = (Bindings.Glyphs :: any)[device]
	return set[action] or action
end

function InputController.press(action: string, began: boolean)
	InputController.ActionPressed:Fire(action, began, nil)
end

function InputController.setContext(name: string)
	local actions = (Bindings :: any)[name]
	if type(actions) ~= "table" or name == "Glyphs" or name == "ToggleInputs" then
		error("InputController: unknown context " .. tostring(name), 2)
	end
	if name == context then
		return
	end
	for _, actionName in ipairs(bound) do
		ContextActionService:UnbindAction(actionName)
	end
	table.clear(bound)
	context = name
	if GAMEPLAY[name] then
		gameplayContext = name
	end
	for action, inputs in pairs(actions) do
		local actionName = ACTION_PREFIX .. action
		ContextActionService:BindAction(actionName, function(_, state: Enum.UserInputState, input: InputObject)
			if state == Enum.UserInputState.Begin then
				InputController.ActionPressed:Fire(action, true, input)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				InputController.ActionPressed:Fire(action, false, input)
			end
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(inputs))
		table.insert(bound, actionName)
	end
	InputController.ContextChanged:Fire(name)
end

function InputController.restoreGameplay()
	InputController.setContext(held or gameplayContext)
end

-- Holds a suspending context (and switches to it), or lets it go with nil; the caller restores gameplay after.
function InputController.hold(name: string?)
	held = name
	if name then
		InputController.setContext(name)
	end
end

function InputController.getHold(): string?
	return held
end

-- The gameplay context to go back to, without switching now (a rig taken during a cinematic: the first shift's).
function InputController.setGameplayContext(name: string)
	if GAMEPLAY[name] then
		gameplayContext = name
	end
end

function InputController.Init()
	device = deviceFor(UserInputService:GetLastInputType()) or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "KeyboardMouse")
end

function InputController.Start()
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local newDevice = deviceFor(inputType)
		if newDevice and newDevice ~= device then
			device = newDevice
			InputController.DeviceChanged:Fire(device)
		end
	end)
	InputController.setContext("OnFoot")
end

return InputController
