--!nonstrict
-- Client/Controllers/ShifterController.lua  (docs/02 §8, docs/06 §6 "Shifter transformation"; D-095, D-096)
--
-- Holding Shift (Z, gamepad Y) for ShifterConfig.hold seconds: on foot, where shifting is allowed (the Training
-- Yard, or a story step that allows it), with the ability (player attribute CanShift) and enough of the meter
-- (ShiftEnergy), Elias clenches his fist until it sparks and asks the server to shift (Shift_Request); riding the
-- Titan form, it asks to come back. Let go early and nothing happens. In the Titan form ShiftSpecial (Q / LB) uses
-- the selected special and NextSpecial (T / D-pad left) picks the next unlocked one (Shift_Special); its fists are
-- CombatController's. The server decides everything (ShifterService); its answers come as Shift_Effect:
--   Shift  {position, userId, first}  the bolt; the flash on the shifter's screen (dimmer nearby)
--   Revert {position, userId}         the steam from the Titan's nape; it fades when the server marks it Fading
--   Denied {reason} / Ended {reason}  a toast          Leaving {seconds}   "outside the training area" countdown
-- Every Titan form in workspace.Shifters shows its state here too: healing steam (Regenerating), Hardening and Rage
-- (<Name>Until), the dust of its smash (its clip event Slam). HUD: a tag with the shift key and the charge (and the
-- meter on foot), and UI/ShifterHUD while riding.
--
--   getState() -> { mode, holding, charge, riding, energy }      -- for tests

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
local ShifterHUD = require(script.Parent.Parent.UI.ShifterHUD)
local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local FrameController = require(script.Parent.FrameController)
local HUDController = require(script.Parent.HUDController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local ShifterController = {}

local NEARBY_FLASH = 150 -- studs: someone else's shift this close flashes this screen too (dimmer)
local SPECIALS = ShifterConfig.specials
local DENIED = {
	NotHere = "You can't shift here.",
	Cooldown = "Not yet. Your body needs a moment.",
	NotNow = "Not now.",
	Busy = "Not now.",
	NoEnergy = "Not enough strength left.",
	NoSpecial = "No special unlocked yet.",
}
local ENDED = {
	Spent = "The Titan form gives way.",
	Drained = "Out of strength. The Titan form gives way.",
}

local player = Players.LocalPlayer
local holding = nil -- { started, mode, sent }
local tag, glyphLabel, actionLabel, fill, meterLabel, warning
local hud
local tagShown = false
local warnUntil = nil
local cooldownUntil = 0 -- after coming back (the server keeps its own; this one only shapes the HUD and the refusal)
local shown = {} -- [model] = { hardened, rage } as drawn on this screen

local function now()
	return workspace:GetServerTimeNow()
end

local function riding(): boolean
	local frame = FrameController.getFrame()
	return frame ~= nil and frame:GetAttribute("Class") == "Shifter"
end

local function allowedHere(): boolean
	return ShifterConfig.ZONES[player:GetAttribute("Zone") or ""] == true or player:GetAttribute("ShiftAllowed") == true
end

local function energy(): number
	return player:GetAttribute("ShiftEnergy") or ShifterConfig.energy.start
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
	if energy() < ShifterConfig.energy.minToShift then
		return nil, "NoEnergy"
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

local function unlocked(): { string }
	local list = {}
	for name in string.gmatch(player:GetAttribute("ShiftSpecials") or "", "[^,]+") do
		table.insert(list, name)
	end
	return list
end

local function onSpecialAction(action: string)
	if not riding() then
		return
	end
	if action == "ShiftSpecial" then
		Net.fireServer("Shift_Special", { use = true })
	else
		local list = unlocked()
		if #list > 1 then
			local index = table.find(list, player:GetAttribute("ShiftSpecial")) or 0
			Net.fireServer("Shift_Special", { select = list[index % #list + 1] })
		end
	end
end

-- The tag: [Z]  HOLD — SHIFT, the meter on foot, and a thin bar that fills while the key is held.
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
		Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(130, 34), ZIndex = 3,
	})
	meterLabel = Components.label(tag, "", { font = "Mono", size = 13, color = UIStyle.Resonance }, {
		Position = UDim2.fromOffset(180, 6), Size = UDim2.fromOffset(62, 34), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
	})
	local track = Components.slab(tag, { color = UIStyle.Paper, transparency = 0.8, slant = false }, {
		Name = "Track", Position = UDim2.fromOffset(50, 44), Size = UDim2.new(1, -60, 0, 3),
	})
	fill = Components.slab(track, { color = UIStyle.Resonance, slant = false }, { Name = "Fill", Size = UDim2.fromScale(0, 1) })

	warning = Components.label(layer, "", { font = "Header", size = 18, color = UIStyle.Danger }, {
		Name = "ShiftLeaving", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(760, 28),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
	})
	hud = ShifterHUD.build(layer)
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

local function updateHud()
	local frame = FrameController.getFrame()
	hud.show(riding())
	if not riding() then
		return
	end
	local t = now()
	local special = player:GetAttribute("ShiftSpecial")
	local spec = special and SPECIALS[special]
	local readyAt = spec and frame:GetAttribute(special .. "ReadyAt") or 0
	local activeUntil = spec and frame:GetAttribute(special .. "Until") or 0
	local buffs = {}
	for _, name in ipairs(SPECIALS.order) do
		local untilT = frame:GetAttribute(name .. "Until")
		if untilT and untilT > t then
			table.insert(buffs, { label = SPECIALS[name].label, left = untilT - t })
		end
	end
	hud.update({
		hp = frame:GetAttribute("Integrity") or 0, hpMax = frame:GetAttribute("IntegrityMax") or 1, energy = energy(),
		special = spec and special or nil,
		specialReady = if spec then 1 - math.clamp((readyAt - t) / spec.cooldown, 0, 1) else 1,
		specialActive = if activeUntil > t then activeUntil - t else nil,
		more = #unlocked() > 1, buffs = buffs,
		specialKey = InputController.glyph("ShiftSpecial"), nextKey = InputController.glyph("NextSpecial"),
	})
end

-- What every Titan form on this screen shows: hardened arms, rage, healing steam.
local function updateRigs()
	local folder = workspace:FindFirstChild("Shifters")
	local t = now()
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:IsA("Model") and not model:GetAttribute("Fading") then
			local state = shown[model] or {}
			shown[model] = state
			local hardened = (model:GetAttribute("HardeningUntil") or 0) > t
			local rage = (model:GetAttribute("RageUntil") or 0) > t
			if hardened ~= (state.hardened == true) then
				state.hardened = hardened
				ShiftEffects.hardened(model, hardened)
			end
			if rage ~= (state.rage == true) then
				state.rage = rage
				ShiftEffects.rage(model, rage)
			end
			local healing = model:GetAttribute("Regenerating") == true
			if healing ~= (state.healing == true) then
				state.healing = healing
				ShiftEffects.regen(model, healing)
			end
		end
	end
	for model in pairs(shown) do
		if not model.Parent then
			shown[model] = nil
		end
	end
end

local function update()
	local mode, why = modeNow()
	mode = if holding then holding.mode else mode
	-- Just back in human form: the tag stays, the bar refilling until the body can shift again.
	local recovering = not mode and why == "Cooldown"
	local low = not mode and why == "NoEnergy"
	showTag(mode ~= nil or recovering or low)
	meterLabel.Text = if riding() then "" else ("%d%%"):format(math.floor(energy()))
	if mode then
		actionLabel.Text = if mode == "back" then "HOLD — RETURN" else "HOLD — SHIFT"
		fill.Size = UDim2.fromScale(charge(), 1)
	elseif recovering then
		actionLabel.Text = "RECOVERING"
		fill.Size = UDim2.fromScale(1 - (cooldownUntil - os.clock()) / ShifterConfig.cooldown, 1)
	elseif low then
		actionLabel.Text = "GATHERING STRENGTH"
		fill.Size = UDim2.fromScale(energy() / ShifterConfig.energy.minToShift, 1)
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
	updateHud()
	updateRigs()
end

local function rigOf(userId)
	local folder = workspace:FindFirstChild("Shifters")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:GetAttribute("Rider") == userId then
			return model
		end
	end
	return nil
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
		ShiftEffects.steam(payload.position, rigOf(payload.userId))
	elseif payload.kind == "Denied" then
		HUDController.toast(DENIED[payload.reason] or DENIED.NotNow)
	elseif payload.kind == "Ended" and ENDED[payload.reason] then
		HUDController.toast(ENDED[payload.reason])
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

-- The smash and the core strike: dust where the fists come down, and the rider's view shakes.
local function onClipEvent(rig, _, name)
	if name ~= "Slam" or rig:GetAttribute("Class") ~= "Shifter" or not rig.PrimaryPart then
		return
	end
	local root = rig.PrimaryPart
	ShiftEffects.slam((root.CFrame * CFrame.new(0, -(rig:GetAttribute("PivotToFeet") or 31), -32)).Position)
	if rig == FrameController.getFrame() then
		CameraController.shake(0.5, 0.35)
	end
end

function ShifterController.getState()
	return { mode = modeNow(), holding = holding ~= nil, charge = charge(), riding = riding(), energy = energy() }
end

function ShifterController.Init()
	buildTag()
end

function ShifterController.Start()
	InputController.ActionPressed:Connect(function(action, began)
		if action == "Shift" then
			onShiftAction(began)
		elseif (action == "ShiftSpecial" or action == "NextSpecial") and began then
			onSpecialAction(action)
		end
	end)
	InputController.DeviceChanged:Connect(function()
		glyphLabel.Text = InputController.glyph("Shift")
	end)
	Net.on("Shift_Effect", onEffect)
	AnimationController.Event:Connect(onClipEvent)
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
