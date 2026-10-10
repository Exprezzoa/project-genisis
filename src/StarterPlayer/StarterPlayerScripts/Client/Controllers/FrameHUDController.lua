--!nonstrict
-- Client/Controllers/FrameHUDController.lua  (docs/14_ui.md §5, §1.1, §1.3)
--
-- The HUD of a piloted Frame: integrity and energy bars, the ability panel with cooldowns, the reticle, the
-- weapons banner and the system panel. It reads the Frame's attributes every frame; nothing here decides
-- anything. The Titan bar, the lock-on marker and the Core Strike prompt arrive with the Titans (Phase 3).
--
--   getState() -> { visible, integrity, energy, banner, slots = { [name] = { cooldown, available, active } } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local CombatController = require(script.Parent.CombatController)
local FrameController = require(script.Parent.FrameController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local FrameHUDController = {}

local INTEGRITY = { width = 360, height = 18, segments = 10, gap = 3 }
local ENERGY = { width = 300, height = 10, segments = 4, gap = 3 }
local SLOT = { width = 92, height = 72, gap = 8 } -- wider than the 72 of docs/14: a leaning slab eats 18 px of it
-- { key, action for the glyph, move name in CombatConfig (nil = the dodge), energy pips }
local SLOTS = {
	{ "LIGHT", "Light", "Light1", 0 },
	{ "HEAVY", "Heavy", "Heavy", 0 },
	{ "SPECIAL", "Special", "Special", 2 },
	{ "DODGE", "Dodge", nil, 1 },
}
local ENTER_STEP = 0.05 -- seconds between two HUD elements sliding in
local BANNER_TIME = 1.5
local LOW, CRITICAL = 0.34, 0.15

local root
local frame = nil
local integrityBar, integrityValue, energyBar
local slots = {}
local banner, bannerText, bannerLine
local systemLines = {}
local reticle
local entering = {} -- { element, shown position, offset it slides in from }
local state = { visible = false, integrity = 1, energy = 1, banner = "", slots = {} }
local bannerToken = 0
local lastLocked = nil
local animated = RunService:IsRunning()

local function motion(time, style)
	return TweenInfo.new(time or UIStyle.Motion.Time, style or UIStyle.Motion.Style, UIStyle.Motion.Direction)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- A bar of leaning segments. set(fraction, color) fills them from the left.
local function segmentBar(parent, spec, color, props)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(spec.width, spec.height)
	for key, value in pairs(props or {}) do
		holder[key] = value
	end
	holder.Parent = parent
	local width = (spec.width - spec.gap * (spec.segments - 1)) / spec.segments
	local segments = {}
	for index = 1, spec.segments do
		local x = (index - 1) * (width + spec.gap)
		Components.slab(holder, { color = UIStyle.Ink, transparency = 0.35 }, {
			Name = "Back" .. index, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(width, spec.height),
		})
		local clip = Instance.new("Frame")
		clip.Name = "Clip" .. index
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromOffset(x, 0)
		clip.Size = UDim2.fromOffset(width, spec.height)
		clip.ZIndex = 2
		clip.Parent = holder
		local fill = Components.slab(clip, { color = color }, { Name = "Fill", Size = UDim2.fromOffset(width, spec.height) })
		segments[index] = { clip = clip, fill = fill }
	end
	local bar = { holder = holder, color = color }
	function bar.set(fraction, newColor)
		for index, segment in ipairs(segments) do
			local share = math.clamp(fraction * spec.segments - (index - 1), 0, 1)
			segment.clip.Size = UDim2.fromOffset(width * share, spec.height)
			if newColor ~= bar.color then
				Components.paint(segment.fill, newColor)
			end
		end
		bar.color = newColor
	end
	function bar.flash(color, times)
		for _, segment in ipairs(segments) do
			Components.paint(segment.fill, color)
			Components.tweenPaint(segment.fill, TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, times - 1, true), bar.color)
		end
		task.delay(0.24 * times + 0.05, function()
			for _, segment in ipairs(segments) do
				Components.paint(segment.fill, bar.color)
			end
		end)
	end
	return bar
end

local function tag(parent, text, props)
	local holder = Components.slab(parent, { color = UIStyle.Accent }, props)
	holder.Rotation = UIStyle.Tilt
	Components.label(holder, text, { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.Ink }, {
		Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
	})
	return holder
end

local function register(element, from)
	table.insert(entering, { element = element, shown = element.Position, from = from })
end

local function buildBars()
	local block = Instance.new("Frame")
	block.Name = "Vitals"
	block.BackgroundTransparency = 1
	block.AnchorPoint = Vector2.new(0, 1)
	block.Position = UDim2.new(0, 32, 1, -64)
	block.Size = UDim2.fromOffset(INTEGRITY.width + 20, 84)
	block.Parent = root
	tag(block, "INTEGRITY", { Name = "Tag", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(118, 20) })
	integrityValue = Components.label(block, "", { font = "Mono", size = UIStyle.TextSize.Small }, {
		Name = "Value", Position = UDim2.fromOffset(INTEGRITY.width - 120, 0), Size = UDim2.fromOffset(120, 20), TextXAlignment = Enum.TextXAlignment.Right,
	})
	integrityBar = segmentBar(block, INTEGRITY, UIStyle.FrameIntegrity, { Name = "Integrity", Position = UDim2.fromOffset(0, 26) })
	-- A thin ink rule under the bar with a tick at each third: the damage-state thresholds.
	local rule = Components.slab(block, { color = UIStyle.Ink, slant = false }, { Name = "Rule", Position = UDim2.fromOffset(0, 47), Size = UDim2.fromOffset(INTEGRITY.width, 2) })
	for _, share in ipairs({ CRITICAL, LOW, 0.67 }) do
		Components.slab(rule, { color = UIStyle.Accent, slant = false }, { Position = UDim2.new(share, -1, 0, -3), Size = UDim2.fromOffset(2, 8) })
	end
	Components.label(block, "ENERGY", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
		Name = "EnergyLabel", Position = UDim2.fromOffset(ENERGY.width + 10, 56), Size = UDim2.fromOffset(70, 12),
	})
	energyBar = segmentBar(block, ENERGY, UIStyle.FrameEnergy, { Name = "Energy", Position = UDim2.fromOffset(0, 57) })
	register(block, UDim2.fromOffset(-140, 0))
end

local function buildSlots()
	local panel = Instance.new("Frame")
	panel.Name = "Abilities"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -32, 1, -32)
	panel.Size = UDim2.fromOffset(#SLOTS * SLOT.width + (#SLOTS - 1) * SLOT.gap, SLOT.height + 8)
	panel.Parent = root
	for index, spec in ipairs(SLOTS) do
		local holder = Instance.new("Frame")
		holder.Name = spec[1]
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset((index - 1) * (SLOT.width + SLOT.gap), 8)
		holder.Size = UDim2.fromOffset(SLOT.width, SLOT.height)
		holder.Parent = panel
		local shadow = Components.slab(holder, { color = UIStyle.Paper, transparency = 1 }, {
			Name = "Shadow", Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y), Size = UDim2.fromScale(1, 1),
		})
		local fill = Components.slab(holder, { color = UIStyle.Ink, transparency = 0.1 }, { Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
		local key = Components.label(holder, "", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.Accent }, {
			Name = "Key", Position = UDim2.fromOffset(22, 7), Size = UDim2.new(1, -26, 0, 14), ZIndex = 4,
		})
		local name = Components.label(holder, spec[1], { font = "Header", size = UIStyle.TextSize.Tiny }, {
			Name = "Name", Position = UDim2.new(0, 4, 1, -23), Size = UDim2.new(1, -22, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
		})
		-- Cooldown: a dark sheet that shrinks from the full height to nothing.
		local clip = Instance.new("Frame")
		clip.Name = "Cooldown"
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.AnchorPoint = Vector2.new(0, 1)
		clip.Position = UDim2.fromScale(0, 1)
		clip.Size = UDim2.fromScale(1, 0)
		clip.ZIndex = 3
		clip.Parent = holder
		Components.slab(clip, { color = UIStyle.Ink, transparency = 0.25 }, {
			Name = "Sheet", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(SLOT.width, SLOT.height),
		})
		local seconds = Components.label(holder, "", { font = "Mono", size = UIStyle.TextSize.Body, color = UIStyle.Paper }, {
			Name = "Seconds", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
		})
		local pips = {}
		for pip = 1, spec[4] do
			pips[pip] = Components.slab(holder, { color = UIStyle.FrameEnergy }, {
				Name = "Pip" .. pip, Position = UDim2.new(1, -4 - pip * 13, 0, 10), Size = UDim2.fromOffset(11, 5), ZIndex = 4,
			})
		end
		slots[spec[1]] = {
			spec = spec, holder = holder, fill = fill, shadow = shadow, key = key, name = name, clip = clip, seconds = seconds, pips = pips,
			active = false, available = true,
		}
		state.slots[spec[1]] = { cooldown = 0, available = true, active = false }
	end
	register(panel, UDim2.fromOffset(160, 0))
end

local function buildBanner()
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 28)
	banner.Size = UDim2.fromOffset(460, 36)
	banner.Visible = false
	banner.Parent = root
	Components.slab(banner, { color = UIStyle.Ink, transparency = 0.1 }, { Name = "Fill", Size = UDim2.fromScale(1, 1) })
	bannerText = Components.label(banner, "", { font = "Header", size = UIStyle.TextSize.Small, color = UIStyle.Accent }, {
		Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	bannerLine = Components.slab(banner, { color = UIStyle.Accent, slant = false }, {
		Name = "Line", Position = UDim2.new(0, 18, 1, -4), Size = UDim2.new(0, 0, 0, 2), ZIndex = 2,
	})
	local diamond = Components.slab(banner, { color = UIStyle.Accent, slant = false }, {
		Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.fromOffset(8, 8), Rotation = 45, ZIndex = 2,
	})
	diamond.Visible = true
end

local function buildSystem()
	local panel = Instance.new("Frame")
	panel.Name = "System"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 32, 0.45, 0)
	panel.Size = UDim2.fromOffset(240, 88)
	panel.Parent = root
	Components.slab(panel, { color = UIStyle.Accent, slant = false }, { Name = "Edge", Size = UDim2.new(0, 2, 1, 0) })
	for index, name in ipairs({ "Sync", "Armor", "Thrusters", "Aim" }) do
		systemLines[name] = Components.label(panel, "", { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
			Name = name, Position = UDim2.fromOffset(12, (index - 1) * 22), Size = UDim2.new(1, -12, 0, 20),
		})
	end
	systemLines.Sync.Text = "CORE SYNC 98.2%"
	register(panel, UDim2.fromOffset(-140, 0))
end

local function buildReticle()
	reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.BackgroundTransparency = 1
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	reticle.Size = UDim2.fromOffset(24, 24)
	reticle.Parent = root
	for _, tick in ipairs({ { 0.5, 0, 2, 7 }, { 0.5, 1, 2, 7 }, { 0, 0.5, 7, 2 }, { 1, 0.5, 7, 2 } }) do
		Components.slab(reticle, { color = UIStyle.Paper, transparency = 0.3, slant = false }, {
			AnchorPoint = Vector2.new(tick[1], tick[2]), Position = UDim2.fromScale(tick[1], tick[2]), Size = UDim2.fromOffset(tick[3], tick[4]),
		})
	end
end

-- text = nil hides the banner; seconds = nil keeps it up.
local function showBanner(text, seconds)
	bannerToken += 1
	local token = bannerToken
	state.banner = text or ""
	if not text then
		banner.Visible = false
		return
	end
	bannerText.Text = text
	banner.Visible = true
	if animated then
		-- Drops in from above, its underline draws itself, the text pops.
		banner.Position = UDim2.new(0.5, 0, 0, -12)
		TweenService:Create(banner, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Position = UDim2.new(0.5, 0, 0, 28) }):Play()
		bannerLine.Size = UDim2.new(0, 0, 0, 2)
		TweenService:Create(bannerLine, motion(0.35), { Size = UDim2.new(1, -36, 0, 2) }):Play()
		bannerText.TextTransparency = 1
		TweenService:Create(bannerText, motion(0.18), { TextTransparency = 0 }):Play()
	else
		bannerLine.Size = UDim2.new(1, -36, 0, 2)
	end
	if seconds then
		task.delay(seconds, function()
			if bannerToken == token then
				TweenService:Create(bannerText, motion(0.25), { TextTransparency = 1 }):Play()
				task.wait(0.25)
				if bannerToken == token then
					banner.Visible = false
					state.banner = ""
				end
			end
		end)
	end
end

local function setSlot(slot, active, available, cooldown, total)
	local entry = state.slots[slot.spec[1]]
	entry.cooldown, entry.available, entry.active = cooldown, available, active
	slot.clip.Size = UDim2.fromScale(1, if total > 0 then math.clamp(cooldown / total, 0, 1) else 0)
	slot.seconds.Text = if cooldown > 0.05 and total >= 1 then string.format("%.1f", cooldown) else ""
	if active ~= slot.active then
		slot.active = active
		-- The running move's slot turns amber and kicks onto its shadow.
		Components.paint(slot.fill, if active then UIStyle.Accent else UIStyle.Ink, if active then 0 else 0.1)
		Components.paint(slot.shadow, nil, if active then 0 else 1)
		slot.name.TextColor3 = if active then UIStyle.Ink else UIStyle.TextPrimary
		slot.key.TextColor3 = if active then UIStyle.Ink else UIStyle.Accent
		if animated and active then
			slot.fill.Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y)
			TweenService:Create(slot.fill, motion(0.12), { Position = UDim2.new() }):Play()
		end
	end
	if available ~= slot.available then
		slot.available = available
		local fade = if available then 0 else 0.5
		slot.name.TextTransparency, slot.key.TextTransparency = fade, fade
		for _, pip in ipairs(slot.pips) do
			Components.paint(pip, nil, fade)
		end
	end
end

local function refuse(reason)
	if not state.visible then
		return
	end
	if reason == "NoEnergy" then
		energyBar.flash(UIStyle.Danger, if SettingsController.get("reduceFlashing") then 1 else 2)
	elseif reason == "Locked" then
		showBanner("WEAPONS LOCKED — HANGAR SAFETY")
	elseif reason == "Cooldown" and animated then
		for _, slot in pairs(slots) do
			if state.slots[slot.spec[1]].cooldown > 0 then
				slot.holder.Rotation = 4
				TweenService:Create(slot.holder, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
			end
		end
	end
end

local function update()
	local model = frame
	if not (model and model.Parent) then
		return
	end
	local class = model:GetAttribute("Class")
	local integrity = (model:GetAttribute("Integrity") or 0) / math.max(1, model:GetAttribute("IntegrityMax") or 1)
	local energy = model:GetAttribute("Energy") or 0
	local energyMax = math.max(1, model:GetAttribute("EnergyMax") or 100)
	state.integrity, state.energy = integrity, energy / energyMax

	local color = if integrity < LOW then UIStyle.Danger else UIStyle.FrameIntegrity
	integrityBar.set(integrity, color)
	integrityBar.holder.Position = UDim2.fromOffset(0, 26 + (if integrity < CRITICAL and animated then math.sin(os.clock() * math.pi / 0.3) * 1.5 else 0))
	integrityValue.Text = string.format("%d / %d", math.ceil(model:GetAttribute("Integrity") or 0), model:GetAttribute("IntegrityMax") or 0)
	integrityValue.TextColor3 = if integrity < LOW then UIStyle.Danger else UIStyle.TextPrimary
	energyBar.set(energy / energyMax, UIStyle.FrameEnergy)

	local locked = model:GetAttribute("WeaponsLocked") == true
	if locked ~= lastLocked then
		if locked then
			showBanner("WEAPONS LOCKED — HANGAR SAFETY")
		elseif lastLocked ~= nil then
			showBanner("WEAPONS UNLOCKED", BANNER_TIME)
		else
			showBanner(nil)
		end
		lastLocked = locked
	end

	local action = model:GetAttribute("Action")
	local moves = CombatConfig.Frames[class]
	local dodge = CombatConfig.Dodge[class]
	local t = now()
	for _, slot in pairs(slots) do
		local spec = slot.spec
		local move = spec[3] and moves[spec[3]]
		local cost = if move then move.energy else dodge.energy
		local total = if move then (move.cooldown or 0) else dodge.cooldown
		local readyAt = model:GetAttribute((spec[3] or "Dodge") .. "ReadyAt") or 0
		local cooldown = math.max(0, readyAt - t)
		local active = (spec[3] ~= nil and action == spec[3]) or (spec[2] == "Dodge" and action == "Dodge") or (spec[2] == "Light" and type(action) == "string" and string.sub(action, 1, 5) == "Light")
		setSlot(slot, active, not locked and energy >= cost and cooldown <= 0, cooldown, total)
		slot.key.Text = InputController.glyph(spec[2])
	end

	local thrusters = (model:GetAttribute("DodgeReadyAt") or 0) > t
	systemLines.Armor.Text = "ARMOR " .. (if integrity < CRITICAL then "CRITICAL" elseif integrity < 0.67 then "DAMAGED" else "NOMINAL")
	systemLines.Armor.TextColor3 = if integrity < LOW then UIStyle.Danger else UIStyle.TextSecondary
	systemLines.Thrusters.Text = "THRUSTERS " .. (if thrusters then "RECHARGING" else "READY")
	systemLines.Thrusters.TextColor3 = if thrusters then UIStyle.Accent else UIStyle.TextSecondary
	local aim = FrameController.isShiftLocked()
	systemLines.Aim.Text = "AIM LOCK " .. (if aim then "ON" else "OFF") .. "  [" .. InputController.glyph("ShiftLock") .. "]"
	systemLines.Aim.TextColor3 = if aim then UIStyle.Accent else UIStyle.TextSecondary
	reticle.Visible = not locked
end

local function show(model)
	frame = model
	state.visible = model ~= nil
	root.Visible = state.visible
	if not model then
		RunService:UnbindFromRenderStep("PG_FrameHUD")
		return
	end
	lastLocked = nil
	update()
	RunService:BindToRenderStep("PG_FrameHUD", Enum.RenderPriority.Last.Value, update)
	if animated then
		-- The elements slide into place one after another (docs/14 §5.3).
		for index, entry in ipairs(entering) do
			entry.element.Position = entry.shown + entry.from
			TweenService:Create(entry.element, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * ENTER_STEP), { Position = entry.shown }):Play()
		end
	end
end

function FrameHUDController.getState()
	return state
end

function FrameHUDController.build(layer)
	root = Instance.new("Frame")
	root.Name = "FrameHUD"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = layer
	buildBars()
	buildSystem()
	buildSlots()
	buildBanner()
	buildReticle()
	return root
end

function FrameHUDController.Init()
	FrameHUDController.build(UIController.getLayer("HUD"))
end

function FrameHUDController.Start()
	FrameController.Piloting:Connect(show)
	CombatController.Refused:Connect(refuse)
	show(FrameController.getFrame())
end

return FrameHUDController
