--!nonstrict
-- Client/Controllers/MissionLogController.lua  (docs/14_ui.md §7)
--
-- Mission Log shell: a full-screen overlay (Panel at 0.1 transparency, blur 12 while open) with the tabs
-- OBJECTIVES | EVIDENCE | PEOPLE. Phase 1 shows the current objective; evidence, people and the Log Reader
-- get their content with the story systems (Phase 5). Opened with Tab / View / LOG through MenuController.
--
--   selectTab(name)   getTab() -> name

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local HUDController = require(script.Parent.HUDController)
local MenuController = require(script.Parent.MenuController)
local UIController = require(script.Parent.UIController)

local TABS = { "OBJECTIVES", "EVIDENCE", "PEOPLE" }
local EMPTY = {
	OBJECTIVES = "No active objective.",
	EVIDENCE = "No evidence collected.",
	PEOPLE = "No entries yet.",
}

local MissionLogController = {}

local frame, body
local tabButtons = {}
local currentTab = "OBJECTIVES"

local function refresh()
	for name, button in pairs(tabButtons) do
		button.TextColor3 = if name == currentTab then UIStyle.Accent else UIStyle.TextSecondary
	end
	local text = EMPTY[currentTab]
	if currentTab == "OBJECTIVES" then
		text = HUDController.getState().objective or text
	end
	body.Text = text
end

function MissionLogController.selectTab(name)
	if not EMPTY[name] then
		error("MissionLogController: unknown tab " .. tostring(name), 2)
	end
	currentTab = name
	refresh()
end

function MissionLogController.getTab()
	return currentTab
end

function MissionLogController.Init()
	frame = Instance.new("Frame")
	frame.Name = "MissionLog"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = UIStyle.Panel.Color
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = UIController.getLayer("Menu")
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 64), UDim.new(0, 64)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 56), UDim.new(0, 48)
	padding.Parent = frame

	Components.label(frame, "MISSION LOG", { font = "Header", size = UIStyle.TextSize.Title, color = UIStyle.Accent }, { Size = UDim2.new(1, -220, 0, 40) })
	local close = Components.button(frame, "CLOSE", MenuController.close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(200, 44),
	})
	for index, name in ipairs(TABS) do
		tabButtons[name] = Components.button(frame, name, function()
			MissionLogController.selectTab(name)
		end, { Position = UDim2.fromOffset((index - 1) * 208, 64), Size = UDim2.fromOffset(200, 44) })
	end
	body = Components.label(frame, "", { size = UIStyle.TextSize.Large, wrap = true }, {
		Position = UDim2.fromOffset(0, 136),
		Size = UDim2.new(1, 0, 1, -136),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	MenuController.registerScreen("MissionLog", frame, tabButtons.OBJECTIVES or close, { blur = true })
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			refresh()
		end
	end)
end

return MissionLogController
