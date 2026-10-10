--!nonstrict
-- Client/Controllers/TitanHUDController.lua  (docs/14_ui.md §5.1; docs/12 §11 "Player hit")
--
-- What the pilot needs to read a Titan fight: the Titan bar (name, class chip, health with the regenerating part
-- shown lighter, poise, CORE EXPOSED with its countdown, ENRAGED), the Core Strike prompt, and the red edge
-- vignette when the Frame is hit. It reads the Titan's attributes every frame; nothing here decides anything.
--
--   getState() -> { titan, hp, poise, coreExposed, enraged, prompt, vignettes }      -- for tests

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local TitanConfig = require(Shared.Config.TitanConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local CombatController = require(script.Parent.CombatController)
local FrameController = require(script.Parent.FrameController)
local InputController = require(script.Parent.InputController)
local LockOnController = require(script.Parent.LockOnController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local TitanHUDController = {}

local WIDTH = 640
local HP_HEIGHT, POISE_HEIGHT = 12, 5
local SHOW_WITHIN = 500 -- studs: the bar shows the nearest living Titan this close to the Frame
local GHOST_DELAY, GHOST_TIME = 0.45, 0.35 -- the paler bar that shows what a hit just took
local PROMPT = Vector2.new(260, 64)
local VIGNETTE = { depth = 0.34, peak = 0.55, reduced = 0.25, time = 0.3 } -- docs/14 §5.1, §7 (Reduce Flashing)
local BAR_Y = 28
local JITTER = { pixels = 3, time = 0.15 }

local root
local frame = nil -- the piloted Frame
local bar, nameLabel, classChip, classLabel, enragedChip
local hpFill, hpLight, hpGhost, poiseHolder, poiseFill, coreHolder, coreFill, coreLabel
local prompt, promptScale, promptKey, promptLabel
local lockHint
local vignette = {}
local shown = nil -- the Titan on the bar
local last = { hp = 1, steady = 1, ghost = 1, ghostAt = 0, downed = false, enraged = false, prompt = false }
local state = { titan = nil, hp = 1, poise = 1, coreExposed = false, enraged = false, prompt = false, vignettes = 0 }
local animated = RunService:IsRunning()
local jitterToken = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function motion(time, style, direction)
	return TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
end

-- A leaning track with fills laid into it; each fill is a clipped slab so it keeps the track's lean.
local function track(parent, name, y, height)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, y)
	holder.Size = UDim2.fromOffset(WIDTH, height)
	holder.Parent = parent
	Components.slab(holder, { color = UIStyle.Ink, transparency = 0.3 }, { Name = "Back", Size = UDim2.fromScale(1, 1) })
	return holder
end

local function fill(holder, name, color, transparency, zIndex)
	local clip = Instance.new("Frame")
	clip.Name = name
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = zIndex
	clip.Parent = holder
	local slab = Components.slab(clip, { color = color, transparency = transparency }, { Name = "Fill", Size = UDim2.fromOffset(WIDTH, holder.Size.Y.Offset) })
	return { clip = clip, slab = slab }
end

local function setSpan(entry, from, to)
	from, to = math.clamp(from, 0, 1), math.clamp(to, 0, 1)
	entry.clip.Position = UDim2.fromScale(from, 0)
	entry.clip.Size = UDim2.fromScale(math.max(0, to - from), 1)
	entry.slab.Position = UDim2.fromOffset(-from * WIDTH, 0)
end

local function chip(parent, text, color, props)
	local holder = Components.slab(parent, { color = UIStyle.Ink, transparency = 0.15 }, props)
	local stroke = Instance.new("Frame")
	stroke.Name = "Edge"
	stroke.BackgroundColor3 = color
	stroke.BorderSizePixel = 0
	stroke.Position = UDim2.new(0, 6, 1, -2)
	stroke.Size = UDim2.new(1, -12, 0, 2)
	stroke.ZIndex = 2
	stroke.Parent = holder
	local label = Components.label(holder, text, { font = "Header", size = UIStyle.TextSize.Tiny, color = color }, {
		Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	return holder, label
end

local function buildBar()
	bar = Instance.new("Frame")
	bar.Name = "TitanBar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, BAR_Y)
	bar.Size = UDim2.fromOffset(WIDTH, 80)
	bar.Visible = false
	bar.Parent = root

	nameLabel = Components.label(bar, "", { font = "Header", size = 16, color = UIStyle.TextPrimary }, {
		Name = "Name", Size = UDim2.fromOffset(WIDTH - 220, 22),
	})
	classChip, classLabel = chip(bar, "CLASS-3", UIStyle.Accent, {
		Name = "Class", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(92, 20),
	})
	enragedChip = chip(bar, "ENRAGED", UIStyle.Danger, {
		Name = "Enraged", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(96, 20), Visible = false,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = enragedChip

	local hp = track(bar, "HP", 26, HP_HEIGHT)
	hpGhost = fill(hp, "Ghost", UIStyle.Paper, 0.15, 2)
	hpLight = fill(hp, "Regen", UIStyle.TitanHP, 0.5, 3)
	hpFill = fill(hp, "Fill", UIStyle.TitanHP, 0, 4)
	-- The regenerating part shimmers (docs/14 §5.1): a pale band sliding along the bar, seen only inside that part.
	local shimmer = Components.slab(hpLight.slab, { color = UIStyle.Paper, transparency = 0.55 }, {
		Name = "Shimmer", Position = UDim2.fromOffset(-60, 0), Size = UDim2.fromOffset(48, HP_HEIGHT), ZIndex = 2,
	})
	if animated then
		TweenService:Create(shimmer, TweenInfo.new(1.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Position = UDim2.fromOffset(WIDTH + 12, 0) }):Play()
	end

	-- How to lock on, and once locked how to change the zone (the pilot would not find the keys otherwise).
	lockHint = Components.label(bar, "", { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
		Name = "LockHint", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 62), Size = UDim2.fromOffset(420, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	poiseHolder = track(bar, "Poise", 26 + HP_HEIGHT + 4, POISE_HEIGHT)
	poiseFill = fill(poiseHolder, "Fill", UIStyle.TitanPoise, 0, 2)

	-- Downed: the poise bar gives way to CORE EXPOSED and the time left.
	coreHolder = Instance.new("Frame")
	coreHolder.Name = "Core"
	coreHolder.BackgroundTransparency = 1
	coreHolder.Position = UDim2.fromOffset(0, 26 + HP_HEIGHT + 4)
	coreHolder.Size = UDim2.fromOffset(WIDTH, 18)
	coreHolder.Visible = false
	coreHolder.Parent = bar
	coreLabel = Components.label(coreHolder, "CORE EXPOSED", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.TitanHP }, {
		Name = "Label", Size = UDim2.fromOffset(150, 18),
	})
	local countdown = Instance.new("Frame")
	countdown.Name = "Countdown"
	countdown.BackgroundTransparency = 1
	countdown.Position = UDim2.fromOffset(154, 6)
	countdown.Size = UDim2.fromOffset(WIDTH - 154, 6)
	countdown.Parent = coreHolder
	Components.slab(countdown, { color = UIStyle.Ink, transparency = 0.3 }, { Name = "Back", Size = UDim2.fromScale(1, 1) })
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 2
	clip.Parent = countdown
	Components.slab(clip, { color = UIStyle.TitanHP }, { Name = "Fill", Size = UDim2.fromOffset(WIDTH - 154, 6) })
	coreFill = clip
end

local function buildPrompt()
	prompt = Instance.new("Frame")
	prompt.Name = "CoreStrikePrompt"
	prompt.BackgroundTransparency = 1
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.fromScale(0.5, 0.72)
	prompt.Size = UDim2.fromOffset(PROMPT.X, PROMPT.Y)
	prompt.Visible = false
	prompt.Parent = root
	promptScale = Instance.new("UIScale")
	promptScale.Parent = prompt
	-- A paper shadow under an ink slab, like every highlighted control (docs/14 §1.1).
	Components.slab(prompt, { color = UIStyle.Paper }, { Name = "Shadow", Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y), Size = UDim2.fromScale(1, 1) })
	Components.slab(prompt, { color = UIStyle.Ink }, { Name = "Body", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	Components.slab(prompt, { color = UIStyle.TitanHP, slant = false }, {
		Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(20, 20), Rotation = 45, ZIndex = 3,
	})
	Components.slab(prompt, { color = UIStyle.Ink, slant = false }, {
		Name = "DiamondCore", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(8, 8), Rotation = 45, ZIndex = 4,
	})
	promptKey = Components.label(prompt, "F", { font = "Header", size = UIStyle.TextSize.Large, color = UIStyle.Accent }, {
		Name = "Key", Position = UDim2.fromOffset(64, 0), Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
	})
	promptLabel = Components.label(prompt, "CORE STRIKE", { font = "Header", size = UIStyle.TextSize.Small, color = UIStyle.TextPrimary }, {
		Name = "Label", Position = UDim2.fromOffset(114, 0), Size = UDim2.new(1, -124, 1, 0), ZIndex = 3,
	})
end

-- Four edge bands fading inward stand in for a radial gradient.
local function buildVignette()
	local holder = Instance.new("Frame")
	holder.Name = "DamageVignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 0
	holder.Parent = root
	local edges = {
		{ "Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, VIGNETTE.depth), 90 },
		{ "Bottom", UDim2.fromScale(0, 1 - VIGNETTE.depth), UDim2.fromScale(1, VIGNETTE.depth), -90 },
		{ "Left", UDim2.fromScale(0, 0), UDim2.fromScale(VIGNETTE.depth * 0.7, 1), 0 },
		{ "Right", UDim2.fromScale(1 - VIGNETTE.depth * 0.7, 0), UDim2.fromScale(VIGNETTE.depth * 0.7, 1), 180 },
	}
	for _, edge in ipairs(edges) do
		local band = Instance.new("Frame")
		band.Name = edge[1]
		band.BackgroundColor3 = UIStyle.Danger
		band.BackgroundTransparency = 1
		band.BorderSizePixel = 0
		band.Position, band.Size = edge[2], edge[3]
		band.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge[4]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = band
		table.insert(vignette, band)
	end
end

-- The Frame was hit: red edges in and out (docs/14 §5.1), weaker with Reduce Flashing.
local function onHurt()
	state.vignettes += 1
	local peak = if SettingsController.get("reduceFlashing") then VIGNETTE.reduced else VIGNETTE.peak
	for _, band in ipairs(vignette) do
		band.BackgroundTransparency = 1
		local rise = TweenService:Create(band, motion(VIGNETTE.time * 0.3), { BackgroundTransparency = 1 - peak })
		rise.Completed:Once(function()
			TweenService:Create(band, motion(VIGNETTE.time * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		end)
		rise:Play()
	end
	-- The Frame's own HUD jitters for a moment (docs/12 §11: +-3 px for 0.15 s).
	local hud = root.Parent:FindFirstChild("FrameHUD")
	if hud and animated then
		jitterToken += 1
		local token = jitterToken
		task.spawn(function()
			local started = os.clock()
			while os.clock() - started < JITTER.time and jitterToken == token do
				hud.Position = UDim2.fromOffset(math.random(-JITTER.pixels, JITTER.pixels), math.random(-JITTER.pixels, JITTER.pixels))
				RunService.RenderStepped:Wait()
			end
			if jitterToken == token then
				hud.Position = UDim2.fromOffset(0, 0)
			end
		end)
	end
end

-- The nearest living Titan within range of the Frame.
local function pick(model)
	local locked = LockOnController.getTarget()
	if locked and locked.Parent and locked:GetAttribute("State") ~= "Dead" then
		return locked -- the bar follows the lock
	end
	local folder = workspace:FindFirstChild("Titans")
	local rootPart = model.PrimaryPart
	if not (folder and rootPart) then
		return nil
	end
	local best, bestDistance = nil, SHOW_WITHIN
	for _, titan in ipairs(folder:GetChildren()) do
		local titanRoot = titan:IsA("Model") and titan.PrimaryPart
		if titanRoot and titan:GetAttribute("State") ~= "Dead" and titan:GetAttribute("HP") ~= nil then
			local distance = (titanRoot.Position - rootPart.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = titan, distance
			end
		end
	end
	return best
end

local function setShown(titan)
	if titan == shown then
		return
	end
	shown = titan
	state.titan = titan
	if not titan then
		if animated then
			local out = TweenService:Create(bar, motion(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -96) })
			out.Completed:Once(function()
				if not shown then
					bar.Visible = false
				end
			end)
			out:Play()
		else
			bar.Visible = false
		end
		return
	end
	nameLabel.Text = titan:GetAttribute("DisplayName") or titan.Name
	classLabel.Text = "CLASS-" .. tostring(titan:GetAttribute("ClassTier") or "?")
	local hp = (titan:GetAttribute("HP") or 0) / math.max(1, titan:GetAttribute("MaxHP") or 1)
	last.hp, last.steady, last.ghost, last.ghostAt = hp, hp, hp, 0
	last.downed, last.enraged = false, false
	enragedChip.Visible = false
	coreHolder.Visible, poiseHolder.Visible = false, true
	bar.Visible = true
	if animated then
		-- Drops in from above with a small overshoot.
		bar.Position = UDim2.new(0.5, 0, 0, -96)
		TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, BAR_Y) }):Play()
	end
end

-- A short sideways kick of the bar when the Titan is hit.
local function kick(strength)
	if not animated then
		return
	end
	bar.Position = UDim2.new(0.5, strength, 0, BAR_Y + 2)
	TweenService:Create(bar, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, BAR_Y) }):Play()
end

-- Can the Frame strike the core right now? The same test the server makes (docs/12 §10), without the tolerance.
local function canStrike(model, titan)
	if not titan:GetAttribute("CoreExposed") then
		return false
	end
	local core = titan:FindFirstChild("Hurtbox_Core")
	local strike = CombatConfig.CoreStrike[model:GetAttribute("Class")]
	local rootPart = model.PrimaryPart
	if not (core and strike and rootPart) then
		return false
	end
	local toward = (core.Position - rootPart.Position) * Vector3.new(1, 0, 1)
	local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	if toward.Magnitude > strike.range then
		return false
	end
	if toward.Magnitude < 0.1 or look.Magnitude < 0.1 then
		return true
	end
	return math.deg(math.acos(math.clamp(look.Unit:Dot(toward.Unit), -1, 1))) <= strike.facing
end

local function setPrompt(on)
	if on == last.prompt then
		return
	end
	last.prompt = on
	state.prompt = on
	prompt.Visible = on
	if on and animated then
		-- Pops in, then breathes (scale 1 <-> 1.06 every 0.5 s) for as long as the strike is there to take.
		promptScale.Scale = 0.6
		local pop = TweenService:Create(promptScale, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Scale = 1 })
		pop.Completed:Once(function()
			if last.prompt then
				TweenService:Create(promptScale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 }):Play()
			end
		end)
		pop:Play()
	elseif not on then
		promptScale.Scale = 1
	end
end

local function update()
	local model = frame
	if not model then
		return
	end
	local titan = pick(model)
	setShown(titan)
	if not titan then
		setPrompt(false)
		return
	end
	local t = now()
	local maxHP = math.max(1, titan:GetAttribute("MaxHP") or 1)
	local hp = math.clamp((titan:GetAttribute("HP") or 0) / maxHP, 0, 1)
	local poise = math.clamp((titan:GetAttribute("Poise") or 0) / math.max(1, titan:GetAttribute("MaxPoise") or 1), 0, 1)
	state.hp, state.poise = hp, poise

	-- Health: solid up to where it stood after the last hit, lighter above that while it regenerates, and a
	-- pale ghost of what the last hit took, which drains away after a moment.
	if hp < last.hp - 1e-4 then
		if t - last.ghostAt > GHOST_DELAY + GHOST_TIME then
			last.ghost = last.hp
		end
		last.ghostAt = t
		last.steady = hp
		kick(math.clamp((last.hp - hp) * 400, 4, 14))
	elseif hp < last.steady then
		last.steady = hp
	end
	last.hp = hp
	local sinceHit = t - last.ghostAt
	if sinceHit > GHOST_DELAY then
		last.ghost = math.max(hp, last.ghost - (last.ghost - hp) * math.clamp((sinceHit - GHOST_DELAY) / GHOST_TIME, 0, 1))
	end
	setSpan(hpFill, 0, math.min(hp, last.steady))
	setSpan(hpLight, last.steady, hp)
	setSpan(hpGhost, hp, last.ghost)
	setSpan(poiseFill, 0, poise)

	-- Downed: CORE EXPOSED and the time left before it gets up.
	local downed = titan:GetAttribute("State") == "Downed"
	local exposed = titan:GetAttribute("CoreExposed") == true
	state.coreExposed = exposed
	if downed ~= last.downed then
		last.downed = downed
		coreHolder.Visible, poiseHolder.Visible = downed, not downed
		if downed and animated then
			coreLabel.TextTransparency = 1
			TweenService:Create(coreLabel, motion(0.15), { TextTransparency = 0 }):Play()
			coreHolder.Position = UDim2.fromOffset(-24, 26 + HP_HEIGHT + 4)
			TweenService:Create(coreHolder, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Position = UDim2.fromOffset(0, 26 + HP_HEIGHT + 4) }):Play()
		end
	end
	if downed then
		local loop = TitanConfig[titan:GetAttribute("TitanType")]
		local total = if loop then loop.downed.loop else 5
		local left = if exposed then math.clamp(((titan:GetAttribute("CoreUntil") or 0) - t) / total, 0, 1) else 1
		coreFill.Size = UDim2.fromScale(left, 1)
	end

	local enraged = titan:GetAttribute("Enraged") == true
	state.enraged = enraged
	if enraged ~= last.enraged then
		last.enraged = enraged
		enragedChip.Visible = enraged
		if enraged and animated then
			local scale = enragedChip:FindFirstChildOfClass("UIScale")
			scale.Scale = 1.8
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			kick(16)
		end
	end

	local lockedOn = LockOnController.getTarget() == titan
	lockHint.Text = if lockedOn
		then ("LOCKED: %s   [%s] ZONE   [%s] RELEASE"):format(string.upper(LockOnController.getZone() or ""), InputController.glyph("CycleZone"), InputController.glyph("LockOn"))
		else ("[%s] LOCK ON"):format(InputController.glyph("LockOn"))
	lockHint.TextColor3 = if lockedOn then UIStyle.Accent else UIStyle.TextSecondary
	promptKey.Text = InputController.glyph("CoreStrike")
	setPrompt(model:GetAttribute("State") == "Idle" and canStrike(model, titan))
end

local function show(model)
	frame = model
	root.Visible = model ~= nil
	if not model then
		RunService:UnbindFromRenderStep("PG_TitanHUD")
		shown = nil
		state.titan = nil
		bar.Visible = false
		setPrompt(false)
		return
	end
	RunService:BindToRenderStep("PG_TitanHUD", Enum.RenderPriority.Last.Value, update)
end

function TitanHUDController.getState()
	return state
end

function TitanHUDController.build(layer)
	root = Instance.new("Frame")
	root.Name = "TitanHUD"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = layer
	buildVignette()
	buildBar()
	buildPrompt()
	return root
end

function TitanHUDController.Init()
	TitanHUDController.build(UIController.getLayer("HUD"))
end

function TitanHUDController.Start()
	FrameController.Piloting:Connect(show)
	CombatController.Hurt:Connect(onHurt)
	show(FrameController.getFrame())
end

return TitanHUDController
