--!nonstrict
-- Client/Controllers/MissionLogController.lua  (docs/14_ui.md §7)
--
-- Mission Log shell: a full-screen overlay (blur 12 while open) with the tabs OBJECTIVES | EVIDENCE | PEOPLE.
-- Phase 1 shows the current objective; evidence, people and the Log Reader get their content with the story
-- systems (Phase 5). Opened with Tab / View / LOG through MenuController.
--
--   selectTab(name)   getTab() -> name   build(layer)

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
		Components.setAccented(button, name == currentTab)
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

function MissionLogController.build(layer)
	frame = MenuController.backdrop(layer, "MissionLog")
	Components.title(frame, "MISSION LOG", { Position = UDim2.fromOffset(72, 48), Size = UDim2.fromOffset(520, 68), ZIndex = 6 }, { size = UIStyle.TextSize.Hero, color = UIStyle.Ink, textColor = UIStyle.Paper })
	local close = Components.button(frame, "CLOSE", MenuController.close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 56),
		Size = UDim2.fromOffset(200, 44),
		ZIndex = 6,
	})
	for index, name in ipairs(TABS) do
		tabButtons[name] = Components.button(frame, name, function()
			MissionLogController.selectTab(name)
		end, { Position = UDim2.fromOffset(96 + (index - 1) * 236, 148), Size = UDim2.fromOffset(224, 44), ZIndex = 6 })
	end
	local page = Components.slab(frame, { color = UIStyle.Ink, transparency = 0.04, slant = 4 }, {
		Name = "Page",
		Position = UDim2.fromOffset(72, 212),
		Size = UDim2.new(0.62, -72, 1, -272), -- the right side belongs to the silhouette
		ZIndex = 4,
	})
	body = Components.label(page, "", { size = UIStyle.TextSize.Large, wrap = true }, {
		Position = UDim2.fromOffset(72, 32),
		Size = UDim2.new(1, -144, 1, -64),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5,
	})
	MenuController.registerScreen("MissionLog", frame, tabButtons.OBJECTIVES or close, { blur = true })
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			refresh()
		end
	end)
	refresh()
end

function MissionLogController.Init()
	MissionLogController.build(UIController.getLayer("Menu"))
end

return MissionLogController
