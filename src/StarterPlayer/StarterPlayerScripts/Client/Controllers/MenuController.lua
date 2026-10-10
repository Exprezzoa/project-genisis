--!nonstrict
-- Client/Controllers/MenuController.lua  (docs/14_ui.md §8)
--
-- The Menu layer: pause menu and Settings, plus any screen another controller registers (the Mission Log).
-- One screen is open at a time. Opening one switches the input context to "Menu" (movement off); closing
-- restores the gameplay context. Every control is a button, so mouse, touch and gamepad all work; with a
-- gamepad the first control of the opened screen is selected.
--
--   open(name)   close()   toggle(name)   getOpen() -> name?
--   registerScreen(name, frame, firstSelectable, opts { blur })

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local MenuController = {}

local screens = {}
local openName = nil
local blur

local function percent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

-- docs/14 §8, in order. kind "mode" is the single Sprint/Stride row that drives both toggle settings.
local ROWS = {
	{ label = "Camera Sensitivity", key = "camSensitivity", kind = "slider", step = 0.05, format = function(v)
		return ("%.2f"):format(v)
	end },
	{ label = "Invert Y", key = "invertY", kind = "toggle" },
	{ label = "Camera Shake", key = "cameraShake", kind = "slider", step = 0.05, format = percent },
	{ label = "Sprint / Stride Mode", key = "sprintToggle", also = "strideToggle", kind = "choice", options = { { value = false, text = "HOLD" }, { value = true, text = "TOGGLE" } } },
	{ label = "Subtitles", key = "subtitles", kind = "toggle" },
	{ label = "Subtitle Size", key = "subtitleSize", kind = "choice", options = { { value = "S", text = "S" }, { value = "M", text = "M" }, { value = "L", text = "L" } } },
	{ label = "Music Volume", key = "musicVolume", kind = "slider", step = 0.05, format = percent },
	{ label = "SFX Volume", key = "sfxVolume", kind = "slider", step = 0.05, format = percent },
	{ label = "Ambience Volume", key = "ambienceVolume", kind = "slider", step = 0.05, format = percent },
	{ label = "Reduce Flashing", key = "reduceFlashing", kind = "toggle" },
	{ label = "Tutorial Hints", key = "tutorialHints", kind = "toggle" },
	{ label = "Damage Numbers", key = "damageNumbers", kind = "toggle" },
}

function MenuController.registerScreen(name, frame, firstSelectable, opts)
	frame.Visible = false
	screens[name] = { frame = frame, first = firstSelectable, blur = opts and opts.blur == true }
end

function MenuController.getOpen()
	return openName
end

function MenuController.close()
	if not openName then
		return
	end
	screens[openName].frame.Visible = false
	openName = nil
	blur.Enabled = false
	GuiService.SelectedObject = nil
	InputController.restoreGameplay()
end

function MenuController.open(name)
	local screen = screens[name]
	if not screen then
		error("MenuController: unknown screen " .. tostring(name), 2)
	end
	if openName then
		screens[openName].frame.Visible = false
	end
	openName = name
	screen.frame.Visible = true
	blur.Enabled = screen.blur
	InputController.setContext("Menu")
	GuiService.SelectedObject = if InputController.getDevice() == "Gamepad" then screen.first else nil
end

function MenuController.toggle(name)
	if openName == name then
		MenuController.close()
	else
		MenuController.open(name)
	end
end

local function column(parent, width)
	local panel = Components.panel(parent, { solid = true, padding = 20 }, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UIStyle.Gap)
	layout.Parent = panel
	return panel
end

local function buildPause(layer)
	local panel = column(layer, 360)
	panel.Name = "Pause"
	Components.label(panel, "PAUSED", { font = "Header", size = UIStyle.TextSize.Title, color = UIStyle.Accent }, { Size = UDim2.new(1, 0, 0, 40) })
	local resume = Components.button(panel, "RESUME", MenuController.close)
	Components.button(panel, "MISSION LOG", function()
		MenuController.open("MissionLog")
	end)
	Components.button(panel, "SETTINGS", function()
		MenuController.open("Settings")
	end)
	-- Missions only (Phase 4) and disabled in the Vertical Slice.
	Components.disable(Components.button(panel, "RESTART FROM CHECKPOINT"))
	Components.disable(Components.button(panel, "QUIT TO HUB"))
	MenuController.registerScreen("Pause", panel, resume)
end

local function buildSettings(layer)
	local panel = column(layer, 760)
	panel.Name = "Settings"
	Components.label(panel, "SETTINGS", { font = "Header", size = UIStyle.TextSize.Title, color = UIStyle.Accent }, { Size = UDim2.new(1, 0, 0, 40) })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 0, 520)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UIStyle.Accent
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local setters = {}
	local first
	for index, row in ipairs(ROWS) do
		local holder = Instance.new("Frame")
		holder.Name = row.key
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -12, 0, 44)
		holder.LayoutOrder = index
		holder.Parent = scroll
		Components.label(holder, row.label, { size = UIStyle.TextSize.Body }, { Size = UDim2.new(0.45, 0, 1, 0) })
		local place = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.55, 0, 1, 0) }
		local value = SettingsController.get(row.key)
		local function changed(newValue)
			SettingsController.set(row.key, newValue)
			if row.also then
				SettingsController.set(row.also, newValue)
			end
		end
		local control, setter, firstButton
		if row.kind == "slider" then
			local spec = GameConfig.Settings[row.key]
			control, setter, firstButton = Components.slider(holder, { min = spec.min, max = spec.max, step = row.step, value = value, format = row.format }, changed, place)
		elseif row.kind == "choice" then
			control, setter = Components.choice(holder, row.options, value, changed, place)
		else
			control, setter = Components.toggle(holder, value, changed, place)
		end
		setters[row.key] = setter
		first = first or firstButton or control
	end
	Components.button(panel, "BACK", function()
		MenuController.open("Pause")
	end)
	SettingsController.Changed:Connect(function(key, value)
		if setters[key] then
			setters[key](value)
		end
	end)
	MenuController.registerScreen("Settings", panel, first)
end

function MenuController.Init()
	local layer = UIController.getLayer("Menu")
	blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 12
	blur.Enabled = false
	blur.Parent = Lighting
	buildPause(layer)
	buildSettings(layer)
end

function MenuController.Start()
	InputController.ActionPressed:Connect(function(action, began)
		if not began then
			return
		end
		if action == "Menu" then
			if openName then
				MenuController.close()
			else
				MenuController.open("Pause")
			end
		elseif action == "MissionLog" then
			MenuController.toggle("MissionLog")
		elseif action == "Back" then
			if openName == "Settings" then
				MenuController.open("Pause")
			else
				MenuController.close()
			end
		end
	end)
end

return MenuController
