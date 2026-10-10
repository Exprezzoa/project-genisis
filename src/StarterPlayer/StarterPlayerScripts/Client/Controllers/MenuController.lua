--!nonstrict
-- Client/Controllers/MenuController.lua  (docs/14_ui.md §8)
--
-- The Menu layer: pause menu and Settings, plus any screen another controller registers (the Mission Log).
-- One screen is open at a time. Opening one switches the input context to "Menu" (movement off); closing
-- restores the gameplay context. Every control is a button, so mouse, touch and gamepad all work; with a
-- gamepad the first control of the opened screen is selected.
-- Look: every screen sits on the CharacterStage (UI/CharacterStage): dimmed game view, amber band, and the
-- character's silhouette, whose shot changes with the screen.
--
--   open(name)   close()   toggle(name)   getOpen() -> name?
--   registerScreen(name, frame, firstSelectable, opts { blur })
--   backdrop(parent, name) -> Frame     -- an empty full-screen container for a screen's content
--   build(layer)                        -- builds the screens into a layer (Init does this; also for previews)

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local UIStyle = require(Shared.Config.UIStyle)

local CharacterStage = require(script.Parent.Parent.UI.CharacterStage)
local Components = require(script.Parent.Parent.UI.Components)
local Transitions = require(script.Parent.Parent.UI.Transitions)
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

-- docs/14 §8, in order. The Sprint/Stride row drives both toggle settings.
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
	if blur then
		blur.Enabled = false
	end
	GuiService.SelectedObject = nil
	CharacterStage.hide()
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
	if blur then
		blur.Enabled = screen.blur
	end
	InputController.setContext("Menu")
	GuiService.SelectedObject = if InputController.getDevice() == "Gamepad" then screen.first else nil
	CharacterStage.show(name, false)
	-- The content arrives piece by piece: big surfaces slide up, then the titles and buttons run in.
	for _, child in ipairs(screen.frame:GetChildren()) do
		if child.Name == "Body" or child.Name == "Page" then
			Transitions.slideIn(child, UDim2.fromOffset(0, 70), 0.45)
		end
	end
	Components.cascade(screen.frame, { delay = 0.08 })
end

function MenuController.toggle(name)
	if openName == name then
		MenuController.close()
	else
		MenuController.open(name)
	end
end

-- An empty full-screen container for one screen's content. The dim, the band and the silhouette behind it
-- belong to the CharacterStage, which every screen shares.
function MenuController.backdrop(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 5
	frame.Parent = parent
	return frame
end

local function column(parent, width, position, rotation)
	local holder = Instance.new("Frame")
	holder.Name = "Column"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(width, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Rotation = rotation
	holder.ZIndex = 5
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = holder
	return holder
end

local function buildPause(layer)
	local screen = MenuController.backdrop(layer, "Pause")
	local list = column(screen, 440, UDim2.new(0.16, -40, 0.5, 0), UIStyle.Tilt)
	Components.title(list, "PAUSED", { LayoutOrder = 1 }, { size = UIStyle.TextSize.Hero, color = UIStyle.Ink, textColor = UIStyle.Paper })
	local resume = Components.button(list, "RESUME", MenuController.close, { LayoutOrder = 2 })
	local log = Components.button(list, "MISSION LOG", function()
		MenuController.open("MissionLog")
	end, { LayoutOrder = 3 })
	local settings = Components.button(list, "SETTINGS", function()
		MenuController.open("Settings")
	end, { LayoutOrder = 4 })
	-- Missions only (Phase 4) and disabled in the Vertical Slice.
	local restart = Components.button(list, "RESTART FROM CHECKPOINT", nil, { LayoutOrder = 5 })
	local quit = Components.button(list, "QUIT TO HUB", nil, { LayoutOrder = 6 })
	Components.disable(restart)
	Components.disable(quit)
	for index, button in ipairs({ resume, log, settings, restart, quit }) do
		Components.tag(button, ("%02d"):format(index))
	end
	MenuController.registerScreen("Pause", screen, resume)
end

local function buildSettings(layer)
	local screen = MenuController.backdrop(layer, "Settings")
	-- A wide ink slab holds the rows; the title sits on its top-left corner.
	local body = Components.slab(screen, { color = UIStyle.Ink, transparency = 0.04, slant = 4 }, {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.4, 0.52), -- left of center: the silhouette's head fills the right
		Size = UDim2.new(0, 760, 0.84, 0), -- relative height: it has to fit a phone in landscape
		ZIndex = 4,
	})
	Components.title(body, "SETTINGS", { Position = UDim2.fromOffset(40, -30), Size = UDim2.fromOffset(360, 60), ZIndex = 6 })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(64, 44)
	scroll.Size = UDim2.new(1, -128, 1, -116)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UIStyle.Accent
	scroll.ZIndex = 5
	scroll.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll

	local setters = {}
	local first
	for index, row in ipairs(ROWS) do
		local holder = Instance.new("Frame")
		holder.Name = row.key
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -16, 0, 44)
		holder.LayoutOrder = index
		holder.Parent = scroll
		Components.label(holder, string.upper(row.label), { font = "Header", size = UIStyle.TextSize.Small }, { Size = UDim2.new(0.45, 0, 1, 0) })
		local place = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.52, 0, 1, 0) }
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
	Components.button(body, "BACK", function()
		MenuController.open("Pause")
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -64, 1, -16), Size = UDim2.fromOffset(220, 44), ZIndex = 6 })
	SettingsController.Changed:Connect(function(key, value)
		if setters[key] then
			setters[key](value)
		end
	end)
	MenuController.registerScreen("Settings", screen, first)
end

-- For previews: MenuController.showStage(screenName, instant).
MenuController.showStage = CharacterStage.show

function MenuController.build(layer)
	CharacterStage.build(layer)
	buildPause(layer)
	buildSettings(layer)
end

function MenuController.Init()
	blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 12
	blur.Enabled = false
	blur.Parent = Lighting
	MenuController.build(UIController.getLayer("Menu"))
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
