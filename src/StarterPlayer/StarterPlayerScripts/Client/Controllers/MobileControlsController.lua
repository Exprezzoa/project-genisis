--!nonstrict
-- Client/Controllers/MobileControlsController.lua  (docs/11_controls_and_camera.md §2)
--
-- Touch buttons, shown only while the last input was touch. Phase 1 has the on-foot set: SPRINT (toggle,
-- bottom-left above the thumbstick), LOG (top-left under the objective tracker) and the menu button
-- (top-right). The Frame buttons (LIGHT, HEAVY, DODGE, ...) come with the Frame in Phase 2.
-- Buttons: circular, panel color, 2-px amber stroke, Michroma 14, pressed scale 0.92, at least 56 px.
--
--   getButtons() -> { [action] = TextButton }      -- for tests

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local InputController = require(script.Parent.InputController)
local UIController = require(script.Parent.UIController)

local MobileControlsController = {}

-- { action, text, size, anchor, position }
local BUTTONS = {
	{ "Sprint", "SPRINT", 64, Vector2.new(0, 1), UDim2.new(0, 40, 1, -260) },
	{ "MissionLog", "LOG", 56, Vector2.new(0, 0), UDim2.new(0, 24, 0, 120) },
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

function MobileControlsController.Init()
	holder = Instance.new("Frame")
	holder.Name = "MobileControls"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = UIController.getLayer("HUD")

	for _, spec in ipairs(BUTTONS) do
		local action, text, size = spec[1], spec[2], spec[3]
		local button = Instance.new("TextButton")
		button.Name = action
		button.AutoButtonColor = false
		button.Selectable = false
		button.AnchorPoint = spec[4]
		button.Position = spec[5]
		button.Size = UDim2.fromOffset(size, size)
		button.BackgroundColor3 = UIStyle.Panel.Color
		button.BackgroundTransparency = UIStyle.Panel.Transparency
		button.FontFace = UIStyle.Font.Header
		button.TextSize = if #text <= 3 then 22 else UIStyle.TextSize.Small
		button.TextColor3 = UIStyle.TextPrimary
		button.Text = text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIStyle.AccentStroke.Color
		stroke.Thickness = UIStyle.AccentStroke.Thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		local pressScale = Instance.new("UIScale")
		pressScale.Parent = button
		button.MouseButton1Down:Connect(function()
			pressScale.Scale = 0.92
			InputController.press(action, true)
		end)
		button.MouseButton1Up:Connect(function()
			pressScale.Scale = 1
			InputController.press(action, false)
		end)
		button.MouseLeave:Connect(function()
			pressScale.Scale = 1
		end)
		button.Parent = holder
		buttons[action] = button
	end
	refresh()
end

function MobileControlsController.Start()
	InputController.DeviceChanged:Connect(refresh)
end

return MobileControlsController
