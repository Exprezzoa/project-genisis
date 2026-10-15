--!nonstrict
-- Client/Controllers/ShifterController.lua  (docs/02 §8, docs/06 §6 "Shifter transformation"; D-095)
--
-- Holding Shift (Z, gamepad Y) for ShifterConfig.hold seconds: on foot, where shifting is allowed (the Training
-- Yard, or a story step that allows it) and with the ability (player attribute CanShift), Elias clenches his fist
-- until it sparks and asks the server to shift (Shift_Request); riding the Titan form, it asks to come back.
-- Let go early and nothing happens. The server decides (ShifterService); its answer comes as Shift_Effect:
--   Shift  {position, userId}  the bolt where it strikes; the flash on the shifter's screen (and dimmer nearby)
--   Revert {position}          the steam; the Titan fades when the server marks it Fading
--   Denied {reason}            a toast        Leaving {seconds}   "outside the training area" with a countdown
-- A small HUD tag shows the key and what holding it does, with the charge filling in Lattice cyan.
--
--   getState() -> { mode, holding, charge, riding }      -- for tests

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local ShifterConfig = require(Shared.Config.ShifterConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local ShiftEffects = require(script.Parent.Parent.UI.ShiftEffects)
local FrameController = require(script.Parent.FrameController)
local HUDController = require(script.Parent.HUDController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local ShifterController = {}

local NEARBY_FLASH = 150 -- studs: someone else's shift this close flashes this screen too (dimmer)
local DENIED = {
	NotHere = "You can't shift here.",
	Cooldown = "Not yet. Your body needs a moment.",
	NotNow = "Not now.",
	Busy = "Not now.",
}

local player = Players.LocalPlayer
local holding = nil -- { started, mode, sent }
local tag, glyphLabel, actionLabel, fill, warning
local tagShown = false
local warnUntil = nil
local cooldownUntil = 0 -- after coming back (the server keeps its own; this one only shapes the HUD and the refusal)

local function riding(): boolean
	local frame = FrameController.getFrame()
	return frame ~= nil and frame:GetAttribute("Class") == "Shifter"
end

local function allowedHere(): boolean
	return ShifterConfig.ZONES[player:GetAttribute("Zone") or ""] == true or player:GetAttribute("ShiftAllowed") == true
end

-- What holding Shift does now ("shift", "back" or nil), and for a refused press why not.
local function modeNow(): (string?, string?)
	if not player:GetAttribute("CanShift") then
		return nil, nil
	end
	local context = InputController.getContext()
	if riding() then
		return if context == "Shifter" then "back" else nil, nil
	end
	if context ~= "OnFoot" or player:GetAttribute("Shifted") then
		return nil, nil
	end
	if not allowedHere() then
		return nil, "NotHere"
	end
	if os.clock() < cooldownUntil then
		return nil, "Cooldown"
	end
	return "shift", nil
end

local function charge(): number
	return if holding then math.clamp((os.clock() - holding.started) / ShifterConfig.hold, 0, 1) else 0
end

local function onShiftAction(began: boolean)
	if began then
		if holding then
			return
		end
		local mode, why = modeNow()
		if not mode then
			if why then
				HUDController.toast(DENIED[why])
			end
			return
		end
		local mine = { started = os.clock(), mode = mode, sent = false }
		holding = mine
		if mode == "shift" and player.Character then
			ShiftEffects.clench(player.Character, function()
				return if holding == mine then charge() else nil
			end)
		end
	elseif holding and not holding.sent then
		holding = nil -- let go too early
	end
end

-- The HUD tag: [Z]  HOLD — SHIFT, a thin bar under it that fills while the key is held.
local function buildTag()
	local layer = UIController.getLayer("HUD")
	tag = Instance.new("Frame")
	tag.Name = "ShiftTag"
	tag.BackgroundTransparency = 1
	tag.AnchorPoint = Vector2.new(1, 1)
	tag.Position = UDim2.new(1, -36, 1, -164)
	tag.Size = UDim2.fromOffset(250, 52)
	tag.Visible = false
	tag.Parent = layer
	Components.slab(tag, { color = UIStyle.Ink, transparency = 0.25 }, { Name = "Back", Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -18, 0, 34) })
	local glyph
	glyph, glyphLabel = Components.keyGlyph(tag, InputController.glyph("Shift"), 34)
	glyph.Position = UDim2.fromOffset(0, 6)
	glyph.ZIndex = 3
	actionLabel = Components.label(tag, "HOLD — SHIFT", { font = "Header", size = 14, color = UIStyle.Paper }, {
		Position = UDim2.fromOffset(50, 6), Size = UDim2.new(1, -56, 0, 34), ZIndex = 3,
	})
	local track = Components.slab(tag, { color = UIStyle.Paper, transparency = 0.8, slant = false }, {
		Name = "Track", Position = UDim2.fromOffset(50, 44), Size = UDim2.new(1, -60, 0, 3),
	})
	fill = Components.slab(track, { color = UIStyle.Resonance, slant = false }, { Name = "Fill", Size = UDim2.fromScale(0, 1) })

	warning = Components.label(layer, "", { font = "Header", size = 18, color = UIStyle.Danger }, {
		Name = "ShiftLeaving", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(760, 28),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
	})
end

local function showTag(on: boolean)
	if on == tagShown then
		return
	end
	tagShown = on
	if on then
		tag.Visible = true
		tag.Position = UDim2.new(1, 4, 1, -164)
		TweenService:Create(tag, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -36, 1, -164) }):Play()
	else
		tag.Visible = false
	end
end

local function update()
	local mode, why = modeNow()
	mode = if holding then holding.mode else mode
	-- Just back in human form: the tag stays, the bar refilling until the body can shift again.
	local recovering = not mode and why == "Cooldown"
	showTag(mode ~= nil or recovering)
	if mode then
		actionLabel.Text = if mode == "back" then "HOLD — RETURN" else "HOLD — SHIFT"
		fill.Size = UDim2.fromScale(charge(), 1)
	elseif recovering then
		actionLabel.Text = "RECOVERING"
		fill.Size = UDim2.fromScale(1 - (cooldownUntil - os.clock()) / ShifterConfig.cooldown, 1)
	end
	-- The hold is complete: ask once.
	if holding and not holding.sent and charge() >= 1 then
		holding.sent = true
		Net.fireServer("Shift_Request", {})
		local done = holding
		task.delay(0.3, function()
			if holding == done then
				holding = nil
			end
		end)
	end
	-- Outside the allowed place in the Titan form: a countdown until it gives way.
	if warnUntil then
		local left = warnUntil - os.clock()
		if not riding() or allowedHere() or left <= -0.5 then
			warnUntil = nil
			warning.Visible = false
		else
			warning.Visible = true
			warning.Text = ("OUTSIDE THE TRAINING AREA — RETURNING TO HUMAN FORM IN %d"):format(math.max(0, math.ceil(left)))
		end
	end
end

local function onEffect(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "Shift" and typeof(payload.position) == "Vector3" then
		ShiftEffects.bolt(payload.position)
		local reduced = SettingsController.get("reduceFlashing") == true
		if payload.userId == player.UserId then
			ShiftEffects.flash(UIController.getLayer("Fade"), reduced)
		else
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - payload.position).Magnitude < NEARBY_FLASH then
				ShiftEffects.flash(UIController.getLayer("Fade"), true)
			end
		end
	elseif payload.kind == "Revert" and typeof(payload.position) == "Vector3" then
		ShiftEffects.steam(payload.position)
	elseif payload.kind == "Denied" then
		HUDController.toast(DENIED[payload.reason] or DENIED.NotNow)
	elseif payload.kind == "Leaving" then
		warnUntil = os.clock() + (payload.seconds or ShifterConfig.leaveGrace)
	end
end

-- A Titan form the server marks Fading melts into the steam on this screen.
local function watchModel(model)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Fading"):Connect(function()
		ShiftEffects.fadeOut(model, ShifterConfig.fade)
	end)
end

function ShifterController.getState()
	return { mode = modeNow(), holding = holding ~= nil, charge = charge(), riding = riding() }
end

function ShifterController.Init()
	buildTag()
end

function ShifterController.Start()
	InputController.ActionPressed:Connect(function(action, began)
		if action == "Shift" then
			onShiftAction(began)
		end
	end)
	InputController.DeviceChanged:Connect(function()
		glyphLabel.Text = InputController.glyph("Shift")
	end)
	Net.on("Shift_Effect", onEffect)
	player:GetAttributeChangedSignal("Shifted"):Connect(function()
		if not player:GetAttribute("Shifted") then
			cooldownUntil = os.clock() + ShifterConfig.cooldown
		end
	end)
	RunService.RenderStepped:Connect(update)
	task.spawn(function()
		local folder = workspace:WaitForChild("Shifters")
		folder.ChildAdded:Connect(watchModel)
		for _, model in ipairs(folder:GetChildren()) do
			watchModel(model)
		end
	end)
end

return ShifterController
