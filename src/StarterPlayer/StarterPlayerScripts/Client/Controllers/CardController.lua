--!nonstrict
-- Client/Controllers/CardController.lua  (docs/14_ui.md §9)
--
-- Full-screen cards, sent by the server as UI_Card { kind, lines, seconds, show }. A card brings its own black:
-- the server lifts the fade layer under it and puts the black back before the card goes (Sequence action "card").
-- Built so far: Transit (S10): black, RobotoMono 20 amber typed in line by line with a block cursor, corner
-- brackets that draw in round the text, an underline, and a thin track filling over the card's time.
-- Title (S01): black, one line at a time centered, Michroma 28 then 18, letter-spaced with spaced characters;
-- each rises in over 0.6 s, holds for its time (`times`), fades out; a hairline draws under the place.
-- Mission Complete (S40): UI/MissionCompleteCard, waiting for Continue (UI_CardDone back to the server).
-- Chapter End (S43): UI/ChapterEndCard, the same way. (The Frame Disabled card lives in FrameDamageController.)
--
--   show(kind, lines, seconds, times?)      hide()      getState() -> { kind, visible, text }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local InputController = require(script.Parent.InputController)
local ChapterEndCard = require(script.Parent.Parent.UI.ChapterEndCard)
local MissionCompleteCard = require(script.Parent.Parent.UI.MissionCompleteCard)
local UIController = require(script.Parent.UIController)

local CardController = {}

local BLOCK = Vector2.new(620, 96)
local TYPE_RATE = 40 -- characters per second
local LINE_PAUSE = 0.15
local CORNER = 18 -- px, the length of a bracket's arms

local root, block, labels, cursor, rule, track, fill, title, titleLabel, titleRule
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

	title = Instance.new("Frame")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.47)
	title.Size = UDim2.fromOffset(1100, 80)
	title.Visible = false
	title.Parent = root
	titleLabel = Components.label(title, "", { font = "Header", size = 28, color = UIStyle.Paper }, {
		Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	titleRule = Components.slab(title, { color = UIStyle.Paper, transparency = 0.6, slant = false }, {
		Name = "Rule", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 26), Size = UDim2.fromOffset(0, 1), ZIndex = 2,
	})
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

-- Letter-spacing the way docs/05 S01 asks: a space between characters, three between words.
local function spaced(text)
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		table.insert(out, if char == " " then "  " else char)
	end
	return table.concat(out, " ")
end

local function playTitle(lines, times, mine)
	title.Visible = true
	for index, text in ipairs(lines or {}) do
		if token ~= mine then
			return
		end
		local hold = (times and times[index]) or 2
		titleLabel.Text = spaced(text)
		titleLabel.TextSize = if index == 1 then 28 else 18
		titleLabel:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = titleLabel.TextSize
		titleLabel.TextTransparency = 1
		titleLabel.Position = UDim2.new(0.5, 0, 0.5, 10)
		titleRule.Size = UDim2.fromOffset(0, 1)
		local rise = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(titleLabel, rise, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }):Play()
		if index > 1 then
			TweenService:Create(titleRule, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(math.min(900, #text * 22), 1) }):Play()
		end
		task.wait(math.max(hold - 0.5, 0.6))
		if token ~= mine then
			return
		end
		local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(titleLabel, out, { TextTransparency = 1 }):Play()
		TweenService:Create(titleRule, out, { Size = UDim2.fromOffset(0, 1) }):Play()
		task.wait(0.5)
	end
end

function CardController.show(kind, lines, seconds, times)
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
	track.Visible = kind == "Transit"
	title.Visible = false
	if kind == "Title" then
		task.spawn(playTitle, lines, times, mine)
		return
	end
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

-- Cards that wait for Continue (Mission Complete in S40, Chapter End in S43); the server waits for UI_CardDone.
local WAITING = { MissionComplete = MissionCompleteCard, ChapterEnd = ChapterEndCard }

local function waitingCard(kind, data)
	state.kind, state.visible, state.text = kind, true, data and (data.mission or data.title) or ""
	InputController.hold("Cinematic") -- no walking off while it is up
	WAITING[kind].show(UIController.getLayer("Cards"), data or {}, function()
		state.visible = false
		InputController.hold(nil)
		if InputController.getContext() == "Cinematic" then
			InputController.restoreGameplay()
		end
		Net.fireServer("UI_CardDone", { kind = kind })
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
		if payload.show and WAITING[payload.kind] then
			waitingCard(payload.kind, payload.data)
		elseif payload.show then
			CardController.show(payload.kind, payload.lines, payload.seconds, payload.times)
		else
			CardController.hide()
		end
	end)
end

return CardController
