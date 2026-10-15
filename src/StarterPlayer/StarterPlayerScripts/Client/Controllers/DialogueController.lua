--!nonstrict
-- Client/Controllers/DialogueController.lua  (docs/14_ui.md §6; docs/13 §2)
--
-- Draws what DialogueService sends (Dialogue_Node / Dialogue_End) from the local copy of Shared/Dialogue:
--   radio         the HUD subtitle (HUDController.showSubtitle)
--   conversation  a box at the bottom: a tilted speaker tab, the line typed in at 60 chars/s, a bobbing "▼" once
--                 it is complete; the first press completes the line, the next one asks for the next line
--   cinematic     letterbox bars and the line centered in the lower bar; lines advance by themselves
-- Choices stack above the box (or the lower bar), numbered; keys 1-4, the D-pad and A, or a click/tap choose; a
-- timed choice shows a bar that runs out (danger red in its last 3 s). The Dialogue input context holds gameplay
-- while a conversation or cinematic runs. The box drops in and unfolds; it folds away at the end.
--
--   getState() -> { open, mode, dialogueId, nodeId, text, typed, choices }      advance()      choose(index)
--   letterbox(owner, on)     the shared letterbox bars (they stay while any owner wants them)
--   Node: Signal(dialogueId, nodeId, node)   every line shown, with its data (a cinematic's cam and slide)
--   Line: Signal(speaker?, mode, seconds?)   each line shown (seconds for a radio line, which ends by itself);
--                                            speaker nil when the dialogue closes (NPCAnimator: TalkFidget)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local Speakers = require(Shared.Dialogue.Speakers)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local HUDController = require(script.Parent.HUDController)
local InputController = require(script.Parent.InputController)
local UIController = require(script.Parent.UIController)

local DialogueController = {}

DialogueController.Line = Signal.new()
DialogueController.Node = Signal.new()

local TYPE_RATE = 60 -- characters per second (docs/14 §6)
local MIN_ADVANCE = 0.6 -- a line can be advanced this long after it appears (docs/05)
local BOX = { width = 900, share = 0.7, minHeight = 140, bottom = 40 }
local CHOICE = { width = 520, height = 44, gap = 6 }
local LETTERBOX = 0.11 -- of the viewport's height, each bar

local dialogues = {}
local layer, box, boxFill, nameTab, nameLabel, lineLabel, more, choicesHolder, timerBar, timerFill
local barTop, barBottom, cineLabel
local state = { open = false, mode = nil, dialogueId = nil, nodeId = nil, text = "", typed = true, choices = nil }
local token = 0
local shownAt = 0
local selected = 1
local choiceButtons = {}
local animated = RunService:IsRunning()

local function tween(object, time, goal, style, direction)
	local tw = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

----------------------------------------------------------------------------------------------------------------
-- Building
----------------------------------------------------------------------------------------------------------------
local function build()
	layer = UIController.getLayer("Dialogue")
	-- Letterbox (cinematic mode).
	barTop = Instance.new("Frame")
	barTop.Name = "LetterboxTop"
	barTop.BackgroundColor3 = Color3.new(0, 0, 0)
	barTop.BorderSizePixel = 0
	barTop.Size = UDim2.fromScale(1, 0)
	barTop.Parent = layer
	barBottom = barTop:Clone()
	barBottom.Name = "LetterboxBottom"
	barBottom.AnchorPoint = Vector2.new(0, 1)
	barBottom.Position = UDim2.fromScale(0, 1)
	barBottom.Parent = layer
	cineLabel = Components.label(barBottom, "", { font = "Body", size = UIStyle.SubtitleSize.M, wrap = true }, {
		Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.7, 0, 0.8, 0),
		TextXAlignment = Enum.TextXAlignment.Center, RichText = true,
	})

	-- The conversation box: a button so a click or tap advances.
	box = Instance.new("TextButton")
	box.Name = "DialogueBox"
	box.AutoButtonColor = false
	box.Text = ""
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -BOX.bottom)
	box.Size = UDim2.new(BOX.share, 0, 0, BOX.minHeight)
	box.Visible = false
	box.Parent = layer
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BOX.width, math.huge)
	limit.Parent = box
	Components.slab(box, { color = UIStyle.Accent, transparency = 0.65 }, { Name = "Shadow", Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y), Size = UDim2.fromScale(1, 1), ZIndex = 0 })
	boxFill = Components.slab(box, { color = UIStyle.Panel.Color, transparency = 0.08 }, { Name = "Fill", Size = UDim2.fromScale(1, 1) })
	Components.slab(box, { color = UIStyle.Accent, slant = false }, { Name = "Edge", Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -56, 0, 2), ZIndex = 2 })
	nameTab = Instance.new("Frame")
	nameTab.Name = "NameTab"
	nameTab.BackgroundTransparency = 1
	nameTab.AnchorPoint = Vector2.new(0, 1)
	nameTab.Position = UDim2.fromOffset(18, 6)
	nameTab.Size = UDim2.fromOffset(220, 34)
	nameTab.Rotation = UIStyle.Tilt
	nameTab.Parent = box
	Components.slab(nameTab, { color = UIStyle.Panel.Color, transparency = 0 }, { Name = "Tab", Size = UDim2.fromScale(1, 1) })
	nameLabel = Components.label(nameTab, "", { font = "Header", size = 16 }, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	lineLabel = Components.label(box, "", { font = "Body", size = 22, wrap = true }, {
		Name = "Line", Position = UDim2.fromOffset(34, 26), Size = UDim2.new(1, -78, 1, -40), TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true, ZIndex = 2,
	})
	more = Components.label(box, "▼", { font = "Header", size = 14, color = UIStyle.Accent }, {
		Name = "More", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -10), Size = UDim2.fromOffset(20, 20),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 2,
	})

	-- Choices above the box, right-aligned; the timer bar above them.
	choicesHolder = Instance.new("Frame")
	choicesHolder.Name = "Choices"
	choicesHolder.BackgroundTransparency = 1
	choicesHolder.AnchorPoint = Vector2.new(1, 1)
	choicesHolder.Size = UDim2.fromOffset(CHOICE.width, 4 * (CHOICE.height + CHOICE.gap) + 10)
	choicesHolder.Visible = false
	choicesHolder.Parent = layer
	timerBar = Instance.new("Frame")
	timerBar.Name = "Timer"
	timerBar.BackgroundColor3 = UIStyle.Ink
	timerBar.BackgroundTransparency = 0.4
	timerBar.BorderSizePixel = 0
	timerBar.Size = UDim2.new(1, 0, 0, 3)
	timerBar.Parent = choicesHolder
	timerFill = Instance.new("Frame")
	timerFill.BackgroundColor3 = UIStyle.Accent
	timerFill.BorderSizePixel = 0
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.Parent = timerBar
end

----------------------------------------------------------------------------------------------------------------
-- Lines
----------------------------------------------------------------------------------------------------------------
local function speakerOf(node)
	local speaker = Speakers[node.speaker]
	local thought = node.style == "thought"
	return speaker, thought
end

local function richLine(node)
	local speaker, thought = speakerOf(node)
	if thought or (speaker and speaker.italic) then
		return "<i>" .. node.text .. "</i>"
	end
	return node.text
end

-- Types the line into the label at TYPE_RATE; the first press completes it.
local function typeLine(label, text, mine)
	state.typed = false
	label.Text = text
	label.MaxVisibleGraphemes = 0
	more.Visible = false
	local total = utf8.len(label.ContentText) or #text
	task.spawn(function()
		local started = os.clock()
		while token == mine and not state.typed do
			local count = math.floor((os.clock() - started) * TYPE_RATE)
			if count >= total then
				break
			end
			label.MaxVisibleGraphemes = count
			RunService.RenderStepped:Wait()
		end
		if token == mine then
			label.MaxVisibleGraphemes = -1
			state.typed = true
			more.Visible = state.mode == "conversation" and state.choices == nil
		end
	end)
end

local function openBox()
	if box.Visible then
		return
	end
	box.Visible = true
	if animated then
		box.Position = UDim2.new(0.5, 0, 1, -BOX.bottom + 24)
		boxFill.Size = UDim2.fromScale(0.05, 1)
		tween(box, 0.25, { Position = UDim2.new(0.5, 0, 1, -BOX.bottom) }, UIStyle.Pop.Style, UIStyle.Pop.Direction)
		tween(boxFill, 0.3, { Size = UDim2.fromScale(1, 1) })
		nameTab.Rotation = UIStyle.Tilt - 10
		tween(nameTab, 0.3, { Rotation = UIStyle.Tilt }, UIStyle.Pop.Style, UIStyle.Pop.Direction)
	end
end

-- The letterbox is shared: a cinematic (CinematicController) and a cinematic-mode dialogue each own it, and it
-- stays while anyone does. The cinematic line clears when the dialogue lets go.
local letterboxOwners = {}

local function setLetterbox(on, owner)
	owner = owner or "dialogue"
	letterboxOwners[owner] = if on then true else nil
	if not on and owner == "dialogue" then
		cineLabel.Text = ""
	end
	on = next(letterboxOwners) ~= nil
	local goal = if on then LETTERBOX else 0
	if animated then
		tween(barTop, 0.4, { Size = UDim2.fromScale(1, goal) }, Enum.EasingStyle.Quad)
		tween(barBottom, 0.4, { Size = UDim2.fromScale(1, goal) }, Enum.EasingStyle.Quad)
	else
		barTop.Size, barBottom.Size = UDim2.fromScale(1, goal), UDim2.fromScale(1, goal)
	end
end

function DialogueController.letterbox(owner, on)
	setLetterbox(on, owner)
end

----------------------------------------------------------------------------------------------------------------
-- Choices
----------------------------------------------------------------------------------------------------------------
local function clearChoices()
	for _, button in ipairs(choiceButtons) do
		button:Destroy()
	end
	table.clear(choiceButtons)
	choicesHolder.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(choicesHolder) then
		GuiService.SelectedObject = nil
	end
end

local function highlight(position)
	selected = math.clamp(position, 1, #choiceButtons)
	if InputController.getDevice() == "Gamepad" then
		GuiService.SelectedObject = choiceButtons[selected]
	end
end

function DialogueController.choose(index)
	local choices = state.choices
	if not (choices and table.find(choices, index)) then
		return
	end
	Net.fireServer("Dialogue_Choose", { dialogueId = state.dialogueId, nodeId = state.nodeId, index = index })
	state.choices = nil
	for _, button in ipairs(choiceButtons) do
		button:SetAttribute("Disabled", true)
	end
	-- The picked one stays a moment, the others fold away.
	for _, button in ipairs(choiceButtons) do
		if button:GetAttribute("Index") ~= index and animated then
			tween(button, 0.18, { Size = UDim2.fromOffset(0, CHOICE.height) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	task.delay(0.35, function()
		if state.choices == nil then
			clearChoices()
		end
	end)
end

local function showChoices(node, allowed, timer, mine)
	clearChoices()
	local above = if state.mode == "cinematic" then barBottom.AbsoluteSize.Y / math.max(UIController.getScale(), 0.01) + 16 else box.AbsoluteSize.Y / math.max(UIController.getScale(), 0.01) + BOX.bottom + 26
	-- Right-aligned with the box (its right edge sits at 0.85 of the width; 0.5 + half of a 900-px box when capped).
	local viewport = workspace.CurrentCamera.ViewportSize.X / math.max(UIController.getScale(), 0.01)
	choicesHolder.Position = UDim2.new(0.5, math.min(BOX.width, viewport * BOX.share) / 2, 1, -above)
	choicesHolder.Visible = true
	for position, index in ipairs(allowed) do
		local choice = node.choices[index]
		local silent = string.sub(choice.text, 1, 1) == "["
		local button = Components.button(choicesHolder, "", function()
			DialogueController.choose(index)
		end, {
			Name = "Choice" .. position, AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, -(#allowed - position) * (CHOICE.height + CHOICE.gap)), Size = UDim2.fromOffset(CHOICE.width, CHOICE.height),
		})
		button:SetAttribute("Index", index)
		local label = button.Label
		label.FontFace = if silent then UIStyle.Font.BodyItalic else UIStyle.Font.Body
		label.TextSize = 20
		local cap = label:FindFirstChildOfClass("UITextSizeConstraint") -- the button's label is capped at its own size
		if cap then
			cap.MaxTextSize = 20
		end
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = choice.text
		label.Position = UDim2.fromOffset(0, 0)
		label.Size = UDim2.new(1, -64, 1, 0)
		label.AnchorPoint = Vector2.new(0, 0)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 54)
		pad.Parent = label
		if silent then
			label.TextColor3 = UIStyle.TextSecondary
		end
		Components.label(button, tostring(position), { font = "Header", size = 14, color = UIStyle.Accent }, {
			Name = "Number", Position = UDim2.fromOffset(26, 0), Size = UDim2.new(0, 20, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
		})
		table.insert(choiceButtons, button)
		if animated then
			-- They slide in from the right one after another.
			local target = button.Position
			button.Position = target + UDim2.fromOffset(60, 0)
			task.delay((position - 1) * 0.05, function()
				tween(button, 0.25, { Position = target }, UIStyle.Pop.Style, UIStyle.Pop.Direction)
			end)
		end
	end
	timerBar.Position = UDim2.new(0, 0, 1, -#allowed * (CHOICE.height + CHOICE.gap) - 8)
	timerBar.Visible = timer ~= nil
	if timer then
		timerFill.Size = UDim2.fromScale(1, 1)
		timerFill.BackgroundColor3 = UIStyle.Accent
		local started = os.clock()
		task.spawn(function()
			while token == mine and state.choices do
				local left = timer - (os.clock() - started)
				timerFill.Size = UDim2.fromScale(math.clamp(left / timer, 0, 1), 1)
				timerFill.BackgroundColor3 = if left <= 3 then UIStyle.Danger else UIStyle.Accent
				if left <= 0 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end
	selected = 1
	highlight(1)
end

----------------------------------------------------------------------------------------------------------------
-- Flow
----------------------------------------------------------------------------------------------------------------
function DialogueController.advance()
	if not state.open or state.mode ~= "conversation" then
		return
	end
	if not state.typed then
		state.typed = true -- the first press completes the line
		return
	end
	if state.choices or os.clock() - shownAt < MIN_ADVANCE or state.sent then
		return
	end
	state.sent = true
	more.Visible = false
	Net.fireServer("Dialogue_Advance", { dialogueId = state.dialogueId, nodeId = state.nodeId })
end

local function onNode(payload)
	local dialogue = dialogues[payload.dialogueId]
	local node = dialogue and dialogue.nodes[payload.nodeId]
	if not node then
		return
	end
	DialogueController.Node:Fire(payload.dialogueId, payload.nodeId, node)
	if payload.mode == "radio" or payload.mode == nil then
		HUDController.showSubtitle({ text = node.text, speaker = node.speaker, thought = node.style == "thought", duration = node.duration })
		if node.style ~= "thought" then
			DialogueController.Line:Fire(node.speaker, "radio", node.duration or (1 + #node.text / 15))
		end
		return
	end
	token += 1
	local mine = token
	local opening = not state.open
	state.open, state.mode, state.dialogueId, state.nodeId = true, payload.mode, payload.dialogueId, payload.nodeId
	state.text, state.choices, state.sent = node.text, payload.choices, false
	DialogueController.Line:Fire(if node.style == "thought" then nil else node.speaker, payload.mode, nil)
	shownAt = os.clock()
	if opening then
		InputController.setContext("Dialogue")
	end
	if payload.mode == "cinematic" then
		box.Visible = false
		setLetterbox(true)
		local speaker, thought = speakerOf(node)
		local name = if speaker and speaker.name ~= "" and not thought then ("<font color=\"#%s\">%s</font>  "):format(speaker.color:ToHex(), speaker.name) else ""
		cineLabel.Text = name .. richLine(node)
		state.typed = true
	else
		openBox()
		local speaker, thought = speakerOf(node)
		nameTab.Visible = not thought and speaker ~= nil and speaker.name ~= ""
		if speaker then
			nameLabel.Text = speaker.name
			nameLabel.TextColor3 = speaker.color
			nameTab.Size = UDim2.fromOffset(math.max(120, #speaker.name * 16 + 40), 34)
		end
		lineLabel.TextColor3 = if thought then UIStyle.TextSecondary else UIStyle.TextPrimary
		typeLine(lineLabel, richLine(node), mine)
	end
	if payload.choices then
		showChoices(node, payload.choices, payload.timer, mine)
	else
		clearChoices()
	end
end

local function onEnd()
	token += 1
	DialogueController.Line:Fire(nil, nil, nil)
	local wasOpen = state.open
	state.open, state.mode, state.choices = false, nil, nil
	clearChoices()
	setLetterbox(false)
	if box.Visible then
		if animated then
			tween(boxFill, 0.18, { Size = UDim2.fromScale(0.04, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(box, 0.18, { Position = UDim2.new(0.5, 0, 1, -BOX.bottom + 20) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local mine = token
			task.delay(0.18, function()
				if token == mine then
					box.Visible = false
				end
			end)
		else
			box.Visible = false
		end
	end
	if wasOpen and InputController.getContext() == "Dialogue" then
		InputController.restoreGameplay()
	end
end

function DialogueController.getState()
	return { open = state.open, mode = state.mode, dialogueId = state.dialogueId, nodeId = state.nodeId, text = state.text, typed = state.typed, choices = state.choices }
end

function DialogueController.Init()
	for _, module in ipairs(Shared.Dialogue:GetChildren()) do
		if module:IsA("ModuleScript") and module.Name ~= "Speakers" then
			for id, dialogue in pairs(require(module)) do
				dialogues[id] = dialogue
			end
		end
	end
	build()
end

function DialogueController.Start()
	Net.on("Dialogue_Node", onNode)
	Net.on("Dialogue_End", onEnd)
	box.Activated:Connect(DialogueController.advance)
	-- Bobbing "▼" when a line is complete.
	RunService.RenderStepped:Connect(function()
		if more.Visible then
			more.Position = UDim2.new(1, -26, 1, -10 + math.sin(os.clock() * 6) * 2)
		end
	end)
	InputController.ActionPressed:Connect(function(action, began)
		if not began or not state.open then
			return
		end
		if action == "Advance" then
			if state.choices and #choiceButtons > 0 then
				local button = choiceButtons[selected]
				DialogueController.choose(button and button:GetAttribute("Index"))
			else
				DialogueController.advance()
			end
		elseif state.choices and string.sub(action, 1, 6) == "Choice" then
			local position = tonumber(string.sub(action, 7))
			if position then
				local button = choiceButtons[position]
				if button then
					DialogueController.choose(button:GetAttribute("Index"))
				end
			elseif action == "ChoiceUp" then
				highlight(selected - 1)
			elseif action == "ChoiceDown" then
				highlight(selected + 1)
			end
		end
	end)
end

return DialogueController
