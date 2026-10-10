--!nonstrict
-- Client/Controllers/HUDController.lua  (docs/14_ui.md §3)
--
-- On-foot HUD: objective tracker (top-left), toasts (bottom-right, max 3, 3.5 s) and subtitles
-- (bottom center; radio lines with a [SPEAKER] tag, thoughts in italics without one).
--
--   setObjective(text?, optionalTexts?)     toast(text)
--   showSubtitle({ text, speaker?, thought?, duration? })
--   getState() -> { objective, optional, toasts, subtitle }      -- for tests
--
-- Remotes: UI_Toast {text}; Dialogue_Node {dialogueId, nodeId} for dialogues in "radio" mode
-- (the conversation and cinematic modes belong to DialogueController, Phase 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)
local Speakers = require(Shared.Dialogue.Speakers)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local HUDController = {}

local dialogues = {}
local objectiveFrame, objectiveText, objectiveFlash, optionalHolder
local toastHolder
local subtitleLabel
local subtitleToken = 0
local state = { objective = nil, optional = {}, toasts = {}, subtitle = nil }

local function motion(time)
	return TweenInfo.new(time or UIStyle.Motion.Time, UIStyle.Motion.Style, UIStyle.Motion.Direction)
end

local function escape(text)
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function list(parent, padding)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
	return layout
end

-- text = nil hides the tracker. optionalTexts are shown in the secondary style with a diamond prefix.
function HUDController.setObjective(text, optionalTexts)
	state.objective = text
	state.optional = optionalTexts or {}
	objectiveFrame.Visible = text ~= nil
	if not text then
		return
	end
	objectiveText.Text = text
	for _, child in ipairs(optionalHolder:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, optional in ipairs(state.optional) do
		Components.label(optionalHolder, "◇ " .. optional, { size = UIStyle.TextSize.Body, color = UIStyle.TextSecondary, wrap = true }, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
	end
	-- New objective: slide in 12 px and flash the amber underline for 0.6 s.
	objectiveFrame.Position = UDim2.fromOffset(24 - UIStyle.Motion.Slide, 24)
	TweenService:Create(objectiveFrame, motion(), { Position = UDim2.fromOffset(24, 24) }):Play()
	objectiveFlash.BackgroundTransparency = 0
	TweenService:Create(objectiveFlash, motion(0.6), { BackgroundTransparency = 1 }):Play()
end

function HUDController.toast(text)
	local config = UIStyle.Toast
	-- An ink slab with leaning edges and an amber underline; the text pops in from the right. The slab's
	-- height follows the wrapped text (a slab can't size itself automatically).
	local panel = Components.slab(toastHolder, { color = UIStyle.Ink, transparency = 0.06 }, { Size = UDim2.fromOffset(config.Width, 44) })
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = UIStyle.Accent
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0.06, 1)
	bar.Size = UDim2.new(0.88, 0, 0, 3)
	bar.Parent = panel
	local label = Components.label(panel, text, { font = "BodyItalic", size = UIStyle.TextSize.Body, color = UIStyle.Paper, wrap = true }, {
		Position = UDim2.fromOffset(70, 12),
		Size = UDim2.new(1, -60, 0, 200), -- tall on purpose: TextBounds is capped by the label's own height
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	TweenService:Create(label, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Position = UDim2.fromOffset(30, 12) }):Play()
	local function fit()
		panel.Size = UDim2.fromOffset(config.Width, math.max(44, math.ceil(label.TextBounds.Y / UIController.getScale()) + 24)) -- TextBounds is in screen pixels
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	local entry = { text = text, panel = panel }
	table.insert(state.toasts, entry)
	while #state.toasts > config.Max do
		table.remove(state.toasts, 1).panel:Destroy()
	end
	task.delay(config.Duration, function()
		local index = table.find(state.toasts, entry)
		if index then
			table.remove(state.toasts, index)
			panel:Destroy()
		end
	end)
end

local function refreshSubtitleStyle()
	subtitleLabel.TextSize = UIStyle.SubtitleSize[SettingsController.get("subtitleSize")]
	subtitleLabel.Visible = state.subtitle ~= nil and SettingsController.get("subtitles")
end

-- line: { text, speaker = speaker code?, thought = boolean?, duration = seconds? }
function HUDController.showSubtitle(line)
	subtitleToken += 1
	local token = subtitleToken
	local speaker = line.speaker and Speakers[line.speaker]
	if line.thought or not speaker or speaker.name == "" then
		subtitleLabel.FontFace = UIStyle.Font.BodyItalic
		subtitleLabel.Text = escape(line.text)
	else
		subtitleLabel.FontFace = UIStyle.Font.BodyBold
		subtitleLabel.Text = ('<font color="#%s">[%s]</font> %s'):format(speaker.color:ToHex(), speaker.name, escape(line.text))
	end
	subtitleLabel.TextColor3 = if speaker and speaker.name == "" then speaker.color else UIStyle.TextPrimary
	state.subtitle = { text = line.text, speaker = line.speaker, thought = line.thought == true }
	refreshSubtitleStyle()
	-- docs/13 §2: default duration max(2.2, 0.06 x characters).
	task.delay(line.duration or math.max(2.2, 0.06 * #line.text), function()
		if token == subtitleToken then
			state.subtitle = nil
			subtitleLabel.Visible = false
		end
	end)
end

function HUDController.getState()
	local toasts = {}
	for _, entry in ipairs(state.toasts) do
		table.insert(toasts, entry.text)
	end
	return {
		objective = state.objective,
		optional = state.optional,
		toasts = toasts,
		subtitle = state.subtitle,
		subtitleVisible = subtitleLabel.Visible,
		subtitleSize = subtitleLabel.TextSize,
	}
end

function HUDController.build(hud)
	objectiveFrame = Instance.new("Frame")
	objectiveFrame.Name = "Objective"
	objectiveFrame.BackgroundTransparency = 1
	objectiveFrame.Position = UDim2.fromOffset(24, 24)
	objectiveFrame.Size = UDim2.fromOffset(440, 0)
	objectiveFrame.AutomaticSize = Enum.AutomaticSize.Y
	objectiveFrame.Visible = false
	objectiveFrame.Parent = hud
	list(objectiveFrame, 4)
	-- A tilted amber tag over the objective text on an ink bar.
	Components.title(objectiveFrame, "OBJECTIVE", { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, { size = UIStyle.TextSize.Tiny, width = 156 })
	objectiveText = Components.label(objectiveFrame, "", { font = "BodyBold", size = 20, wrap = true }, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UIStyle.Ink,
		BackgroundTransparency = 0.15,
		LayoutOrder = 2,
	})
	local textPadding = Instance.new("UIPadding")
	textPadding.PaddingLeft, textPadding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	textPadding.PaddingTop, textPadding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	textPadding.Parent = objectiveText
	objectiveFlash = Instance.new("Frame")
	objectiveFlash.Name = "Flash"
	objectiveFlash.BackgroundColor3 = UIStyle.Accent
	objectiveFlash.BackgroundTransparency = 1
	objectiveFlash.BorderSizePixel = 0
	objectiveFlash.Size = UDim2.new(1, 0, 0, 2)
	objectiveFlash.LayoutOrder = 3
	objectiveFlash.Parent = objectiveFrame
	optionalHolder = Instance.new("Frame")
	optionalHolder.Name = "Optional"
	optionalHolder.BackgroundTransparency = 1
	optionalHolder.Size = UDim2.new(1, 0, 0, 0)
	optionalHolder.AutomaticSize = Enum.AutomaticSize.Y
	optionalHolder.LayoutOrder = 4
	optionalHolder.Parent = objectiveFrame
	list(optionalHolder, 2)

	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.BackgroundTransparency = 1
	toastHolder.AnchorPoint = Vector2.new(1, 1)
	toastHolder.Position = UDim2.new(1, -24, 1, -160)
	toastHolder.Size = UDim2.fromOffset(UIStyle.Toast.Width, 400)
	toastHolder.Parent = hud
	local toastLayout = list(toastHolder, UIStyle.Gap)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	subtitleLabel = Components.label(hud, "", { font = "BodyBold", size = UIStyle.SubtitleSize.M, wrap = true }, {
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.new(0.7, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = true,
		Visible = false,
	})
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Transparency = 0.4
	outline.Thickness = 1.5
	outline.Parent = subtitleLabel
end

function HUDController.Init()
	HUDController.build(UIController.getLayer("HUD"))
	for _, moduleScript in ipairs(Shared.Dialogue:GetChildren()) do
		if moduleScript:IsA("ModuleScript") and moduleScript.Name ~= "Speakers" then
			for id, dialogue in pairs(require(moduleScript)) do
				dialogues[id] = dialogue
			end
		end
	end
end

function HUDController.Start()
	Net.on("UI_Toast", function(payload)
		if type(payload.text) == "string" then
			HUDController.toast(payload.text)
		end
	end)
	Net.on("Dialogue_Node", function(payload)
		local dialogue = dialogues[payload.dialogueId]
		local node = dialogue and dialogue.nodes[payload.nodeId]
		if node and dialogue.mode == "radio" then
			HUDController.showSubtitle({ text = node.text, speaker = node.speaker, thought = node.style == "thought", duration = node.duration })
		end
	end)
	SettingsController.Changed:Connect(function(key)
		if key == "subtitles" or key == "subtitleSize" then
			refreshSubtitleStyle()
		end
	end)
end

return HUDController
