--!nonstrict
-- Client/Controllers/CardController.lua  (docs/14_ui.md §9)
--
-- Full-screen cards, sent by the server as UI_Card { kind, lines, seconds, show }. A card brings its own black:
-- the server lifts the fade layer under it and puts the black back before the card goes (Sequence action "card").
-- Built so far: Transit (S10): black, RobotoMono 20 amber typed in line by line with a block cursor, corner
-- brackets that draw in round the text, an underline, and a thin track filling over the card's time.
-- (The Frame Disabled card lives in FrameDamageController; Title, Mission Complete and Chapter End come later.)
--
--   show(kind, lines, seconds)      hide()      getState() -> { kind, visible, text }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local UIController = require(script.Parent.UIController)

local CardController = {}

local BLOCK = Vector2.new(620, 96)
local TYPE_RATE = 40 -- characters per second
local LINE_PAUSE = 0.15
local CORNER = 18 -- px, the length of a bracket's arms

local root, block, labels, cursor, rule, track, fill
local corners = {}
local state = { kind = nil, visible = false, text = "" }
local token = 0

local function build(layer)
	root = Instance.new("Frame")
	root.Name = "Card"
	root.BackgroundColor3 = UIStyle.Ink
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 1
	root.Parent = layer

	block = Instance.new("Frame")
	block.Name = "Block"
	block.BackgroundTransparency = 1
	block.AnchorPoint = Vector2.new(0.5, 0.5)
	block.Position = UDim2.fromScale(0.5, 0.48)
	block.Size = UDim2.fromOffset(BLOCK.X, BLOCK.Y)
	block.Parent = root
	labels = {}
	for index = 1, 2 do
		labels[index] = Components.label(block, "", { font = "Mono", size = 20, color = UIStyle.Accent }, {
			Name = "Line" .. index, Position = UDim2.fromOffset(24, 14 + (index - 1) * 34), Size = UDim2.new(1, -48, 0, 28), ZIndex = 2,
		})
	end
	cursor = Components.slab(block, { color = UIStyle.Accent, slant = false }, { Name = "Cursor", Size = UDim2.fromOffset(10, 20), ZIndex = 3 })
	rule = Components.slab(block, { color = UIStyle.Accent, transparency = 0.3, slant = false }, {
		Name = "Rule", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(0, 2), ZIndex = 2,
	})
	-- Corner brackets: two thin arms per corner, anchored at the corner.
	for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local anchor = Vector2.new(corner[1], corner[2])
		local horizontal = Components.slab(block, { color = UIStyle.Accent, transparency = 0.35, slant = false }, {
			AnchorPoint = anchor, Position = UDim2.fromScale(corner[1], corner[2]), Size = UDim2.fromOffset(CORNER, 2), ZIndex = 2,
		})
		local vertical = Components.slab(block, { color = UIStyle.Accent, transparency = 0.35, slant = false }, {
			AnchorPoint = anchor, Position = UDim2.fromScale(corner[1], corner[2]), Size = UDim2.fromOffset(2, CORNER), ZIndex = 2,
		})
		table.insert(corners, { horizontal, vertical })
	end
	track = Components.slab(root, { color = UIStyle.Paper, transparency = 0.85, slant = false }, {
		Name = "Track", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, BLOCK.Y / 2 + 34), Size = UDim2.new(0.32, 0, 0, 2),
	})
	fill = Components.slab(track, { color = UIStyle.Accent, slant = false }, { Name = "Fill", Size = UDim2.fromScale(0, 1) })
end

local function placeCursor(label)
	local width = label.TextBounds.X / math.max(UIController.getScale(), 0.01) -- TextBounds is in screen pixels
	cursor.Position = label.Position + UDim2.fromOffset(width + 4, 4)
end

function CardController.hide()
	token += 1
	state.visible = false
	root.Visible = false
end

function CardController.show(kind, lines, seconds)
	token += 1
	local mine = token
	state.kind, state.visible, state.text = kind, true, table.concat(lines or {}, "\n")
	seconds = seconds or 3
	for _, label in ipairs(labels) do
		label.Text = ""
	end
	rule.Size = UDim2.fromOffset(0, 2)
	fill.Size = UDim2.fromScale(0, 1)
	root.Visible = true
	block.Visible = kind == "Transit"
	for _, pair in ipairs(corners) do
		pair[1].Size, pair[2].Size = UDim2.fromOffset(0, 2), UDim2.fromOffset(2, 0)
		local draw = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(pair[1], draw, { Size = UDim2.fromOffset(CORNER, 2) }):Play()
		TweenService:Create(pair[2], draw, { Size = UDim2.fromOffset(2, CORNER) }):Play()
	end
	TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	-- The cursor blinks while the card is up.
	task.spawn(function()
		while token == mine do
			cursor.Visible = not cursor.Visible
			task.wait(0.27)
		end
	end)
	-- Typewriter, line by line, then the underline draws out from the middle.
	task.spawn(function()
		for index, text in ipairs(lines or {}) do
			local label = labels[index]
			if not label then
				break
			end
			for count = 1, utf8.len(text) or #text do
				if token ~= mine then
					return
				end
				local cut = utf8.offset(text, count + 1)
				label.Text = if cut then string.sub(text, 1, cut - 1) else text
				placeCursor(label)
				task.wait(1 / TYPE_RATE)
			end
			task.wait(LINE_PAUSE)
		end
		if token == mine then
			TweenService:Create(rule, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(1, -48, 0, 2) }):Play()
		end
	end)
end

function CardController.getState()
	return state
end

function CardController.Init()
	build(UIController.getLayer("Cards"))
end

function CardController.Start()
	Net.on("UI_Card", function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.show then
			CardController.show(payload.kind, payload.lines, payload.seconds)
		else
			CardController.hide()
		end
	end)
end

return CardController
