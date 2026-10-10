--!nonstrict
-- Client/Controllers/MobileControlsController.lua  (docs/11_controls_and_camera.md §2)
--
-- Touch buttons, shown only while the last input was touch. Phase 1 has the on-foot set: SPRINT (toggle,
-- bottom-left above the thumbstick), LOG and the menu button (both top-right, side by side). The Frame
-- buttons (LIGHT, HEAVY, DODGE, ...) come with the Frame in Phase 2.
-- LOG used to sit top-left under the objective tracker (docs/11 §2); on a phone in landscape that spot
-- collides with SPRINT, so it moved next to the menu button (D-031).
-- Buttons: tilted ink squares with a 2-px amber stroke, Michroma text, pressed scale 0.92, at least 56 px.
--
--   getButtons() -> { [action] = TextButton }   build(layer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local InputController = require(script.Parent.InputController)
local UIController = require(script.Parent.UIController)

local MobileControlsController = {}

-- { action, text, size, anchor, position }
local BUTTONS = {
	{ "Sprint", "SPRINT", 64, Vector2.new(0, 1), UDim2.new(0, 40, 1, -220) },
	{ "MissionLog", "LOG", 56, Vector2.new(1, 0), UDim2.new(1, -96, 0, 24) },
	{ "Menu", "≡", 56, Vector2.new(1, 0), UDim2.new(1, -24, 0, 24) },
}

local holder
local buttons = {}

local function refresh()
	holder.Visible = InputController.getDevice() == "Touch"
end

function MobileControlsController.getButtons()
	return buttons
end

function MobileControlsController.build(layer)
	holder = Instance.new("Frame")
	holder.Name = "MobileControls"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = layer

	for _, spec in ipairs(BUTTONS) do
		local action, text, size = spec[1], spec[2], spec[3]
		local button = Instance.new("TextButton")
		button.Name = action
		button.AutoButtonColor = false
		button.Selectable = false
		button.AnchorPoint = spec[4]
		button.Position = spec[5]
		button.Size = UDim2.fromOffset(size, size)
		button.Rotation = 2 * UIStyle.Tilt
		button.BackgroundColor3 = UIStyle.Ink
		button.BackgroundTransparency = 0.1
		button.BorderSizePixel = 0
		button.FontFace = UIStyle.Font.Header
		button.TextSize = if #text <= 3 then 20 else UIStyle.TextSize.Tiny
		button.TextColor3 = UIStyle.Paper
		button.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIStyle.AccentStroke.Color
		stroke.Thickness = UIStyle.AccentStroke.Thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		local pressScale = Instance.new("UIScale")
		pressScale.Parent = button
		local function pressed(down)
			pressScale.Scale = if down then 0.92 else 1
			button.BackgroundColor3 = if down then UIStyle.Accent else UIStyle.Ink
			button.TextColor3 = if down then UIStyle.Ink else UIStyle.Paper
		end
		button.MouseButton1Down:Connect(function()
			pressed(true)
			InputController.press(action, true)
		end)
		button.MouseButton1Up:Connect(function()
			pressed(false)
			InputController.press(action, false)
		end)
		button.MouseLeave:Connect(function()
			pressed(false)
		end)
		button.Parent = holder
		buttons[action] = button
	end
end

function MobileControlsController.Init()
	MobileControlsController.build(UIController.getLayer("HUD"))
	refresh()
end

function MobileControlsController.Start()
	InputController.DeviceChanged:Connect(refresh)
end

return MobileControlsController
