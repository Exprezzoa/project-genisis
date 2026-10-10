--!nonstrict
-- Client/Controllers/InteractionController.lua  (docs/14_ui.md §4, docs/13 §4)
--
-- Draws the custom ProximityPrompt UI (the prompts use Style = Custom): a BillboardGui with a key box
-- (E / X / TAP for the device in use), the action text, the object text and a hold-progress bar.
-- A prompt is not drawn when the server switched it off for this player (attribute "PromptOff_<InteractId>")
-- or when it is Frame-only and the player is on foot. Tapping the prompt triggers it (touch).
--
--   getShown() -> { interactId }      -- for tests

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local InputController = require(script.Parent.InputController)
local UIController = require(script.Parent.UIController)

local PILOT_SEAT = "PilotSeat"
local FRAME_SCALE = 1.3 -- Frame-scale prompts: size x 1.3, StudsOffset (0, 8, 0)

local InteractionController = {}

local player = Players.LocalPlayer
local shown = {} -- [prompt] = { gui, glyph, id, connections }

local function isPiloting()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat.Name == PILOT_SEAT
end

local function allowed(part, id)
	if player:GetAttribute("PromptOff_" .. id) == true then
		return false
	end
	local piloting = isPiloting()
	if part:GetAttribute("FrameOnly") and not piloting then
		return false
	end
	if part:GetAttribute("OnFootOnly") and piloting then
		return false
	end
	return true
end

local function hide(prompt)
	local entry = shown[prompt]
	if entry then
		shown[prompt] = nil
		for _, connection in ipairs(entry.connections) do
			connection:Disconnect()
		end
		entry.gui:Destroy()
	end
end

local function show(prompt)
	local part = prompt.Parent
	if shown[prompt] or prompt.Style ~= Enum.ProximityPromptStyle.Custom or not part or not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("InteractId") or prompt.Name
	if not allowed(part, id) then
		return
	end
	local config = UIStyle.Prompt
	local frameScale = if part:GetAttribute("FrameOnly") then FRAME_SCALE else 1
	local scale = UIController.getScale() * frameScale

	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt_" .. id
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(config.Size.X * scale, config.Size.Y * scale)
	gui.StudsOffset = if frameScale > 1 then Vector3.new(0, 8, 0) else config.StudsOffset
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.9 * scale
	uiScale.Parent = gui

	local root = Components.panel(gui, { solid = true, slant = UIStyle.Slant }, { Size = UDim2.fromOffset(config.Size.X, config.Size.Y) })
	local keyBox, glyph = Components.keyGlyph(root, InputController.glyph("Interact"), config.KeyBox)
	keyBox.AnchorPoint = Vector2.new(0, 0.5)
	keyBox.Position = UDim2.new(0, 16, 0.5, 0)
	local hasObject = prompt.ObjectText ~= ""
	Components.label(root, prompt.ActionText, { size = 20 }, {
		Position = UDim2.fromOffset(64, if hasObject then 8 else 20),
		Size = UDim2.new(1, -72, 0, 24),
	})
	if hasObject then
		Components.label(root, prompt.ObjectText, { size = UIStyle.TextSize.Small, color = UIStyle.TextSecondary }, {
			Position = UDim2.fromOffset(64, 32),
			Size = UDim2.new(1, -72, 0, 18),
		})
	end
	local bar = Instance.new("Frame")
	bar.Name = "Hold"
	bar.BackgroundColor3 = UIStyle.Accent
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, 64, 1, -8)
	bar.Size = UDim2.new(0, 0, 0, 3)
	bar.Parent = root

	-- Tap to interact (touch); a mouse click works too.
	local tap = Instance.new("TextButton")
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.Selectable = false
	tap.Parent = root

	local holdTween
	local connections = {
		tap.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end),
		tap.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end),
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration > 0 then
				holdTween = TweenService:Create(bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -72, 0, 3) })
				holdTween:Play()
			end
		end),
		prompt.PromptButtonHoldEnded:Connect(function()
			if holdTween then
				holdTween:Cancel()
			end
			bar.Size = UDim2.new(0, 0, 0, 3)
		end),
	}

	gui.Parent = player:WaitForChild("PlayerGui")
	shown[prompt] = { gui = gui, glyph = glyph, id = id, connections = connections }
	-- Appear: the prompt pops in (scale 0.7 -> 1 with a small overshoot), then its key box keeps rocking.
	uiScale.Scale = 0.7 * scale
	TweenService:Create(uiScale, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Scale = scale }):Play()
	TweenService:Create(keyBox, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
end

function InteractionController.getShown()
	local ids = {}
	for _, entry in pairs(shown) do
		table.insert(ids, entry.id)
	end
	table.sort(ids)
	return ids
end

function InteractionController.Start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
	InputController.DeviceChanged:Connect(function()
		for _, entry in pairs(shown) do
			entry.glyph.Text = InputController.glyph("Interact")
		end
	end)
	-- A prompt switched off for this player while it is on screen disappears at once.
	player.AttributeChanged:Connect(function(attribute)
		if string.sub(attribute, 1, 10) == "PromptOff_" and player:GetAttribute(attribute) == true then
			for prompt, entry in pairs(shown) do
				if "PromptOff_" .. entry.id == attribute then
					hide(prompt)
				end
			end
		end
	end)
end

return InteractionController
