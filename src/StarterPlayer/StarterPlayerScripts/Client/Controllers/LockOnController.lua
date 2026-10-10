--!nonstrict
-- Client/Controllers/LockOnController.lua  (docs/12_combat_system.md §8; docs/11 §4-5; docs/14 §5.2)
--
-- Lock-on for a piloted Frame: picks a Titan, keeps the camera and the Frame turned to it, lets the pilot choose
-- the zone to aim for, shows the marker on that zone and tells the server (Frame_Lock), which uses the zone when
-- an attack touches several hurtboxes. The server checks the lock; this side only asks.
--
--   getTarget() -> Model?     getZone() -> string?     Changed: Signal(target?, zone?)
--   toggle()     cycle(step)                                              -- also bound to the inputs
--   candidate() -> Model?     a Titan a lock could take right now (for the HUD's hint)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraFeel = require(Shared.Config.CameraFeel)
local CombatConfig = require(Shared.Config.CombatConfig)
local UIStyle = require(Shared.Config.UIStyle)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CameraController = require(script.Parent.CameraController)
local FrameController = require(script.Parent.FrameController)
local InputController = require(script.Parent.InputController)

local LockOnController = {}

LockOnController.Changed = Signal.new()

local LOCK = CameraFeel.Frame.lock
local PICK_CONE = 60 -- degrees around the camera's forward in which the smallest angle wins (docs/12 §8)
local LABELS = { Body = "BODY", AnkleL = "ANKLE L", AnkleR = "ANKLE R", Head = "HEAD", Core = "CORE" }
local SPIN = 90 -- degrees per second the marker turns (docs/14 §5.2)

local player = Players.LocalPlayer
local frame = nil
local target, zone = nil, nil
local hiddenSince = nil -- os.clock() since the target has been out of sight
local marker, diamond, markerLabel, markerScale
local bars = {}
local sightParams = RaycastParams.new()
local animated = RunService:IsRunning()

local function boxOf(model, zoneName)
	return model:FindFirstChild("Hurtbox_" .. zoneName)
end

-- Can this zone be aimed for right now? The head only while the Titan is low, the core only while it shows.
local function available(model, zoneName)
	if not boxOf(model, zoneName) then
		return false
	elseif zoneName == "Head" then
		return (model:GetAttribute("HurtboxState") or "Standing") ~= "Standing"
	elseif zoneName == "Core" then
		return model:GetAttribute("CoreExposed") == true
	end
	return true
end

local function alive(model)
	return model.Parent ~= nil and model.PrimaryPart ~= nil and model:GetAttribute("State") ~= "Dead"
end

local function inSight(from, model)
	local toward = model.PrimaryPart.Position - from
	return workspace:Raycast(from, toward, sightParams) == nil -- the cast meets the map only
end

local function eyeOf(model)
	return model.PrimaryPart.Position + Vector3.new(0, CameraFeel.Frame.pivotHeight, 0)
end

-- docs/12 §8: Titans (not the Watcher) in range and in sight; the one nearest the middle of the view if any is
-- within 60 degrees of it, otherwise the nearest.
function LockOnController.candidate()
	local own = frame
	local folder = workspace:FindFirstChild("Titans")
	local camera = workspace.CurrentCamera
	if not (own and own.PrimaryPart and folder and camera) then
		return nil
	end
	local eye = eyeOf(own)
	local look = camera.CFrame.LookVector
	local centered, centeredAngle = nil, PICK_CONE
	local nearest, nearestDistance = nil, LOCK.range
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("TitanType") ~= nil and model:GetAttribute("TitanType") ~= "Watcher" and alive(model) then
			local toward = model.PrimaryPart.Position - own.PrimaryPart.Position
			local distance = toward.Magnitude
			if distance <= LOCK.range and inSight(eye, model) then
				local angle = math.deg(math.acos(math.clamp(look:Dot((model.PrimaryPart.Position - camera.CFrame.Position).Unit), -1, 1)))
				if angle < centeredAngle then
					centered, centeredAngle = model, angle
				end
				if distance < nearestDistance then
					nearest, nearestDistance = model, distance
				end
			end
		end
	end
	return centered or nearest
end

local function paintMarker()
	local color = if zone == "Core" then UIStyle.TitanHP else UIStyle.Accent
	for _, bar in ipairs(bars) do
		bar.BackgroundColor3 = color
	end
	markerLabel.TextColor3 = color
	markerLabel.Text = LABELS[zone] or ""
end

local function showMarker()
	local box = target and boxOf(target, zone)
	marker.Adornee = box
	marker.Enabled = box ~= nil
	if not box then
		return
	end
	paintMarker()
	if animated then
		-- Snaps on from large to its size; the core's marker then keeps pulsing.
		markerScale.Scale = 2.2
		local snap = TweenService:Create(markerScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		local shownZone, shownTarget = zone, target
		snap.Completed:Once(function()
			if zone == "Core" and zone == shownZone and target == shownTarget then
				TweenService:Create(markerScale, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.18 }):Play()
			end
		end)
		snap:Play()
	end
end

local function set(newTarget, newZone)
	if newTarget == target and newZone == zone then
		return
	end
	local targetChanged = newTarget ~= target
	target, zone = newTarget, newZone
	hiddenSince = nil
	if targetChanged then
		local point = if newTarget then function()
			local model = target
			return if model and model.PrimaryPart then model.PrimaryPart.Position else nil
		end else nil
		CameraController.setLock(point)
		FrameController.setLock(point)
	end
	showMarker()
	Net.fireServer("Frame_Lock", { targetId = if newTarget then newTarget:GetAttribute("TargetId") else nil, zone = newZone })
	LockOnController.Changed:Fire(newTarget, newZone)
end

function LockOnController.getTarget()
	return target
end

function LockOnController.getZone()
	return zone
end

function LockOnController.toggle()
	if target then
		set(nil, nil)
	else
		local model = LockOnController.candidate()
		if model then
			set(model, "Body")
		end
	end
end

-- The next zone that can be aimed for: Body -> AnkleL -> AnkleR -> Head -> Core -> Body (docs/12 §8).
function LockOnController.cycle(step)
	if not target then
		return
	end
	local zones = CombatConfig.LockOn.zones
	local index = table.find(zones, zone) or 1
	for _ = 1, #zones do
		index = (index - 1 + (step or 1)) % #zones + 1
		if available(target, zones[index]) then
			set(target, zones[index])
			return
		end
	end
end

-- The lock ends when the target dies, leaves the range or stays out of sight for 2 s; a zone that can no longer
-- be aimed for falls back to the body.
local function update(dt)
	if not target then
		return
	end
	local own = frame
	if not (own and own.PrimaryPart) or not alive(target) or (target.PrimaryPart.Position - own.PrimaryPart.Position).Magnitude > LOCK.range then
		set(nil, nil)
		return
	end
	if inSight(eyeOf(own), target) then
		hiddenSince = nil
	else
		hiddenSince = hiddenSince or os.clock()
		if os.clock() - hiddenSince > LOCK.lostSightTime then
			set(nil, nil)
			return
		end
	end
	if not available(target, zone) then
		set(target, "Body")
	end
	diamond.Rotation = (diamond.Rotation + SPIN * dt) % 360
end

-- docs/14 §5.2: a diamond of four amber bars on the zone, turning slowly, with the zone's name under it.
local function buildMarker()
	marker = Instance.new("BillboardGui")
	marker.Name = "LockMarker"
	marker.AlwaysOnTop = true
	marker.ResetOnSpawn = false
	marker.Size = UDim2.fromOffset(120, 100)
	marker.LightInfluence = 0
	marker.Enabled = false
	marker.Parent = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = marker
	markerScale = Instance.new("UIScale")
	markerScale.Parent = holder
	diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.BackgroundTransparency = 1
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(0.5, 0, 0, 36)
	diamond.Size = UDim2.fromOffset(44, 44)
	diamond.Rotation = 45
	diamond.Parent = holder
	for _, side in ipairs({
		{ Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 4) }, { Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 4) },
		{ Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(0, 4, 1, 0) }, { Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0, 4, 1, 0) },
	}) do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = UIStyle.Accent
		bar.AnchorPoint, bar.Position, bar.Size = side[1], side[2], side[3]
		bar.Parent = diamond
		table.insert(bars, bar)
	end
	markerLabel = Instance.new("TextLabel")
	markerLabel.Name = "Zone"
	markerLabel.BackgroundTransparency = 1
	markerLabel.FontFace = UIStyle.Font.Header
	markerLabel.TextSize = 11
	markerLabel.TextColor3 = UIStyle.Accent
	markerLabel.TextStrokeColor3 = UIStyle.Ink
	markerLabel.TextStrokeTransparency = 0.3
	markerLabel.Position = UDim2.new(0, 0, 0, 74)
	markerLabel.Size = UDim2.new(1, 0, 0, 16)
	markerLabel.Text = ""
	markerLabel.Parent = holder
end

function LockOnController.Init()
	sightParams.CollisionGroup = "Debris" -- meets the map only: Frames, Titans and barriers don't block the view
	sightParams.RespectCanCollide = true -- hurtboxes and triggers answer queries without being solid: they don't block it either
	buildMarker()
end

function LockOnController.Start()
	FrameController.Piloting:Connect(function(model)
		frame = model
		if target then
			set(nil, nil)
		end
	end)
	frame = FrameController.getFrame()
	InputController.ActionPressed:Connect(function(action, began)
		if not (began and frame) then
			return
		end
		if action == "LockOn" then
			LockOnController.toggle()
		elseif action == "CycleZone" then
			LockOnController.cycle(1)
		elseif action == "CycleZoneBack" then
			LockOnController.cycle(-1)
		end
	end)
	-- While locked on, the mouse wheel steps through the zones (the camera leaves it alone then).
	UserInputService.InputChanged:Connect(function(input, processed)
		if target and not processed and input.UserInputType == Enum.UserInputType.MouseWheel and InputController.getContext() == "Frame" then
			LockOnController.cycle(if input.Position.Z > 0 then 1 else -1)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return LockOnController
