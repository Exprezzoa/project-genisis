--!nonstrict
-- Client/Controllers/FrameDamageController.lua  (docs/09_frames.md §5; docs/14 "Frame Disabled")
--
-- How a damaged Frame looks, on every client, from the attributes the server publishes (DamageState,
-- PlatesDetached, State): plates break off and fall, sparks and smoke start, the visor and the core vents
-- flicker, and a disabled Frame goes dark (the core vents alone while CoreOffline is set; the vents dark and the
-- visor dim while Standby, parked with nobody aboard). A repair puts everything
-- back. For the pilot, the FRAME DISABLED card.
-- The server only sets the attributes; every client makes its own debris (docs/09 §5).
--
--   getState(frame) -> { level, plates, dark }?      -- for tests

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local FrameController = require(script.Parent.FrameController)
local UIController = require(script.Parent.UIController)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKS = ColorSequence.new(Color3.fromHex("#FFF1DA"), Color3.fromHex("#E07A1F"))
local SMOKE_COLOR = ColorSequence.new(Color3.fromHex("#2A2D31"), Color3.fromHex("#4A4F55"))
local DARK = Color3.fromHex("#2A2D31") -- STEEL_DARK: a dead visor, dead core lights
local LEVELS = { Pristine = 0, Scuffed = 1, Damaged = 2, Critical = 3, Disabled = 4 }
local PLATE_LIFE = 6 -- seconds a fallen plate lies there (docs/09 §5)
local CARD_TIME = 2.5 -- docs/14

local FrameDamageController = {}

local records = {} -- [frame] = record
local effects
local card, cardTitle, cardLine, cardSub
local random = Random.new()
local animated = RunService:IsRunning()

local function emitter(part, name, offset, setup)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = offset
	attachment.Parent = part
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Rate = 0
	setup(particles)
	particles.Parent = attachment
	return particles
end

local function sparkSetup(scale)
	return function(particles)
		particles.Texture = SPARKLE
		particles.Color = SPARKS
		particles.Size = NumberSequence.new(0.9 * scale, 0)
		particles.Lifetime = NumberRange.new(0.25, 0.6)
		particles.Speed = NumberRange.new(10 * scale, 22 * scale)
		particles.SpreadAngle = Vector2.new(70, 70)
		particles.Acceleration = Vector3.new(0, -60, 0)
		particles.LightEmission = 0.8
		particles.Drag = 2
	end
end

local function smokeSetup(scale)
	return function(particles)
		particles.Texture = SMOKE
		particles.Color = SMOKE_COLOR
		particles.Size = NumberSequence.new(2.5 * scale, 7 * scale)
		particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		particles.Lifetime = NumberRange.new(2.2, 3.4)
		particles.Speed = NumberRange.new(4 * scale, 8 * scale)
		particles.SpreadAngle = Vector2.new(25, 25)
		particles.Acceleration = Vector3.new(0, 5, 0)
		particles.Rotation = NumberRange.new(0, 360)
		particles.RotSpeed = NumberRange.new(-30, 30)
		particles.EmissionDirection = Enum.NormalId.Top
		particles.LightInfluence = 1
	end
end

-- A plate comes off: the part on the rig turns invisible and a loose copy of it falls away.
local function shed(record, part)
	local piece = part:Clone()
	for _, child in ipairs(piece:GetDescendants()) do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Attachment") then
			child:Destroy()
		end
	end
	piece.Name = "FallenPlate"
	piece.Anchored, piece.Massless = false, false
	piece.CanCollide, piece.CanQuery, piece.CanTouch = true, false, false
	piece.CollisionGroup = "Debris" -- meets the map only
	piece.CFrame = part.CFrame
	piece.Parent = effects
	local out = (part.Position - record.root.Position) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
	piece.AssemblyLinearVelocity = out * random:NextNumber(14, 26) + Vector3.new(0, random:NextNumber(10, 22), 0)
	piece.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
	Debris:AddItem(piece, PLATE_LIFE)
end

local function syncPlates(frame, record)
	local count = frame:GetAttribute("PlatesDetached") or 0
	local names = FrameConfig[frame:GetAttribute("Class")].plates
	for index, name in ipairs(names) do
		local off = index <= count
		for _, part in ipairs(record.plates[name] or {}) do
			if off and record.hidden[part] == nil then
				record.hidden[part] = part.Transparency
				if record.ready then -- a Frame that is already damaged when it comes into view sheds nothing
					shed(record, part)
				end
				part.Transparency = 1
			elseif not off and record.hidden[part] ~= nil then
				part.Transparency = record.hidden[part]
				record.hidden[part] = nil
			end
		end
	end
end

-- The visor and the core lights: dark when disabled, lit otherwise.
local function setDark(record, dark)
	if record.dark == dark then
		return
	end
	record.dark = dark
	for part, rest in pairs(record.lit) do
		part.Color = if dark then DARK else rest.color
		part.Material = if dark then Enum.Material.SmoothPlastic else rest.material
		for _, light in ipairs(part:GetChildren()) do
			if light:IsA("Light") then
				light.Enabled = not dark
			end
		end
	end
end

-- The core vents alone go dark while the Frame's core is offline (the attribute CoreOffline: after the anomaly,
-- docs/05 S33-S40); the visor stays lit.
local function setVentsDark(record, dark)
	if record.dark or record.ventsDark == dark then
		return
	end
	record.ventsDark = dark
	for _, part in ipairs(record.vents) do
		local rest = record.lit[part]
		part.Color = if dark then DARK else rest.color
		part.Material = if dark then Enum.Material.SmoothPlastic else rest.material
		for _, light in ipairs(part:GetChildren()) do
			if light:IsA("Light") then
				light.Enabled = not dark
			end
		end
	end
end

-- Standing by (parked with nobody aboard, D-092): the visor dim (and the core vents dark, below). When someone
-- boards, the visor brightens and the vents blink on (docs/05 S07, S08).
local STANDBY_VISOR = 0.75 -- the visor's transparency while standing by
local function setStandby(record, standby)
	if record.standby == standby then
		return
	end
	local was = record.standby
	record.standby = standby
	for _, part in ipairs(record.visor) do
		local goal = if standby then STANDBY_VISOR else record.lit[part].transparency
		if was == nil then
			part.Transparency = goal
		else
			TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = goal }):Play()
		end
	end
	return was == true and not standby -- just powered up
end

-- A blink of lit parts: off and on twice.
local function flicker(record, parts)
	for _ = 1, 2 do
		for _, part in ipairs(parts) do
			part.Material = Enum.Material.SmoothPlastic
		end
		task.wait(0.06)
		if record.dark then
			return
		end
		for _, part in ipairs(parts) do
			part.Material = record.lit[part].material
		end
		task.wait(0.08)
	end
end

local function syncState(frame, record)
	local level = LEVELS[frame:GetAttribute("DamageState")] or 0
	if frame:GetAttribute("State") == "Disabled" then
		level = 4
	end
	record.level = level
	-- docs/09 §5: sparks on the left shoulder from Scuffed, on both arms when Critical; smoke on the back from
	-- Damaged, heavy when Critical.
	record.sparksLeft.Rate = if level == 0 or level == 4 then 0 elseif level == 3 then 8 else 3
	record.sparksRight.Rate = if level == 3 then 8 else 0
	record.smoke.Rate = if level == 2 then 12 elseif level == 3 then 30 elseif level == 4 then 16 else 0
	for _, particles in ipairs({ record.sparksLeft, record.sparksRight, record.smoke }) do
		particles.Enabled = particles.Rate > 0
	end
	setDark(record, level == 4)
	local standby = frame:GetAttribute("Standby") == true
	local poweredUp = setStandby(record, standby)
	if level == 4 then
		record.ventsDark = nil -- setDark covers them; look again once it is repaired
	else
		setVentsDark(record, frame:GetAttribute("CoreOffline") == true or standby)
		if poweredUp and not record.ventsDark then
			task.delay(0.1, flicker, record, record.vents)
		end
	end
end

local function showCard()
	if not card then
		return
	end
	card.Visible = true
	if animated then
		-- The title slams in, its rule draws, the second line follows; everything fades at the end.
		local scale = cardTitle:FindFirstChildOfClass("UIScale")
		scale.Scale = 1.5
		cardTitle.TextTransparency, cardSub.TextTransparency = 1, 1
		card.BackgroundTransparency = 1
		cardLine.Size = UDim2.fromOffset(0, 3)
		TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(cardTitle, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
		TweenService:Create(cardLine, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15), { Size = UDim2.fromOffset(520, 3) }):Play()
		TweenService:Create(cardSub, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45), { TextTransparency = 0 }):Play()
	end
	task.delay(CARD_TIME, function()
		card.Visible = false
	end)
end

local function watch(frame)
	if records[frame] or not frame:IsA("Model") or frame:GetAttribute("Unit") == nil or not frame.PrimaryPart then
		return
	end
	local config = FrameConfig[frame:GetAttribute("Class")]
	local shoulderL, shoulderR, torso = frame:FindFirstChild("LeftUpperArm"), frame:FindFirstChild("RightUpperArm"), frame:FindFirstChild("UpperTorso")
	if not (config and config.plates and shoulderL and shoulderR and torso) then
		return
	end
	local scale = frame:GetScale()
	local record = { root = frame.PrimaryPart, plates = {}, hidden = {}, lit = {}, visor = {}, vents = {}, level = 0, dark = false, ready = false, connections = {} }
	records[frame] = record
	for _, part in ipairs(frame:GetDescendants()) do
		if part:IsA("BasePart") then
			local plate = part:GetAttribute("Plate")
			if plate then
				record.plates[plate] = record.plates[plate] or {}
				table.insert(record.plates[plate], part)
			end
			local isVisor, isCore = CollectionService:HasTag(part, "Visor"), CollectionService:HasTag(part, "CoreLight")
			if isVisor or isCore then
				record.lit[part] = { color = part.Color, material = part.Material, transparency = part.Transparency }
				table.insert(if isVisor then record.visor else record.vents, part)
			end
		end
	end
	record.sparksLeft = emitter(shoulderL, "DamageSparks", Vector3.new(-shoulderL.Size.X / 2, shoulderL.Size.Y / 2, 0), sparkSetup(scale))
	record.sparksRight = emitter(shoulderR, "DamageSparks", Vector3.new(shoulderR.Size.X / 2, shoulderR.Size.Y / 2, 0), sparkSetup(scale))
	record.smoke = emitter(torso, "DamageSmoke", Vector3.new(0, torso.Size.Y / 4, torso.Size.Z / 2), smokeSetup(scale))
	for _, attribute in ipairs({ "PlatesDetached", "DamageState", "State", "CoreOffline", "Standby" }) do
		table.insert(record.connections, frame:GetAttributeChangedSignal(attribute):Connect(function()
			syncPlates(frame, record)
			syncState(frame, record)
			if attribute == "State" and frame:GetAttribute("State") == "Disabled" and frame == FrameController.getFrame() then
				showCard()
			end
		end))
	end
	syncPlates(frame, record)
	syncState(frame, record)
	record.ready = true
	-- Damaged: the visor flickers every 3-5 s; Critical: the core vents with it.
	task.spawn(function()
		while records[frame] == record and frame.Parent do
			task.wait(random:NextNumber(3, 5))
			if record.level >= 2 and not record.dark then
				flicker(record, record.visor)
				if record.level >= 3 and not record.dark then
					flicker(record, record.vents)
				end
			end
		end
	end)
end

local function unwatch(frame)
	local record = records[frame]
	if record then
		records[frame] = nil
		for _, connection in ipairs(record.connections) do
			connection:Disconnect()
		end
	end
end

-- docs/14 "Frame Disabled": a red-tinted veil, FRAME DISABLED, "Restarting from checkpoint...", 2.5 s.
local function buildCard()
	card = Instance.new("Frame")
	card.Name = "FrameDisabledCard"
	card.BackgroundColor3 = UIStyle.Danger
	card.BackgroundTransparency = 0.55
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.Visible = false
	card.Parent = UIController.getLayer("Cards")
	local veil = Instance.new("UIGradient") -- dark in the middle so the words read, red toward the top and bottom
	veil.Rotation = 90
	veil.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.new(0.12, 0.12, 0.12)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) })
	veil.Parent = card
	cardTitle = Components.label(card, "FRAME DISABLED", { font = "Header", size = 40, color = UIStyle.Danger }, {
		Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(900, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = cardTitle
	cardLine = Instance.new("Frame")
	cardLine.Name = "Rule"
	cardLine.BackgroundColor3 = UIStyle.Danger
	cardLine.BorderSizePixel = 0
	cardLine.AnchorPoint = Vector2.new(0.5, 0.5)
	cardLine.Position = UDim2.new(0.5, 0, 0.46, 38)
	cardLine.Size = UDim2.fromOffset(520, 3)
	cardLine.Parent = card
	cardSub = Components.label(card, "Restarting from checkpoint...", { font = "Body", size = 18, color = UIStyle.TextSecondary }, {
		Name = "Sub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 66), Size = UDim2.fromOffset(900, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

function FrameDamageController.getState(frame)
	local record = records[frame]
	if not record then
		return nil
	end
	local hidden = 0
	for _ in pairs(record.hidden) do
		hidden += 1
	end
	return { level = record.level, plates = hidden, dark = record.dark, sparks = record.sparksLeft.Rate, smoke = record.smoke.Rate }
end

function FrameDamageController.Init()
	effects = workspace:FindFirstChild("Effects")
	if not effects then
		effects = Instance.new("Folder")
		effects.Name = "Effects"
		effects.Parent = workspace
	end
	buildCard()
end

function FrameDamageController.Start()
	local function onRig(model)
		watch(model)
		task.delay(1, watch, model) -- parts can arrive after the tag
	end
	CollectionService:GetInstanceAddedSignal("PoseRig"):Connect(onRig)
	CollectionService:GetInstanceRemovedSignal("PoseRig"):Connect(unwatch)
	for _, model in ipairs(CollectionService:GetTagged("PoseRig")) do
		onRig(model)
	end
end

return FrameDamageController
