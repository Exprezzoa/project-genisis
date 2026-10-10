--!nonstrict
-- Client/Controllers/VFXController.lua  (docs/06_art_direction.md §6, docs/12 §11, Config/CameraFeel)
--
-- The look-and-feel layer of Frames, on every client: foot dust, the blade trail, thruster flame, the Pile
-- Driver's steam, the ground-impact ring, hit sparks; and for the Frame this player pilots, camera shake and
-- field-of-view punches. Everything is driven by AnimationController's clip events and footfalls and by
-- CombatController's hit feedback; nothing here affects gameplay. Particles use the engine's built-in
-- textures (rbxasset://), no asset IDs.
--
--   getCounts() -> { dust, trails, sparks, rings, shakes }      -- how often each effect ran, for tests
-- While this player pilots, Lighting.PG_CockpitTint tints the whole view warm (the cockpit glass, D-055).

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraFeel = require(Shared.Config.CameraFeel)

local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local CombatController = require(script.Parent.CombatController)
local FrameController = require(script.Parent.FrameController)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local DUST_OUTDOOR = Color3.fromHex("#8C7B66")
local DUST_HANGAR = Color3.fromHex("#5A5E63")
local RING = Color3.fromHex("#CFC6B4")
local BONE_DUST = ColorSequence.new(Color3.fromHex("#E8E2C8"), Color3.fromHex("#9C9893"))
local TRAIL = ColorSequence.new(Color3.fromHex("#FFF1DA"), Color3.fromHex("#E8A33D"))
local FLAME = ColorSequence.new(Color3.fromHex("#FFD38A"), Color3.fromHex("#E07A1F"))
local IMPACT_RADIUS = 14 -- studs on the 40-stud rig; scaled with the rig

local VFXController = {}

local player = Players.LocalPlayer
local counts = { dust = 0, trails = 0, sparks = 0, rings = 0, shakes = 0 }
local effects -- Folder for loose effect parts
local watchedFrame, watchConnection = nil, nil
local cockpit -- ColorCorrectionEffect: the warm tint of the cockpit glass

local function scaleOf(rig)
	return rig:GetScale()
end

-- The emitter named `name` under an attachment, made on first use.
local function emitter(attachment, name, setup)
	local found = attachment:FindFirstChild(name)
	if not found then
		found = Instance.new("ParticleEmitter")
		found.Name = name
		found.Rate = 0
		found.Enabled = false
		setup(found)
		found.Parent = attachment
	end
	return found
end

local function dustSetup(scale, color)
	return function(particles)
		particles.Texture = SMOKE
		particles.Color = ColorSequence.new(color)
		particles.Size = NumberSequence.new(2 * scale, 6 * scale)
		particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		particles.Lifetime = NumberRange.new(0.8, 1.2)
		particles.Speed = NumberRange.new(6 * scale, 10 * scale)
		particles.SpreadAngle = Vector2.new(80, 10)
		particles.EmissionDirection = Enum.NormalId.Top
		particles.Rotation = NumberRange.new(0, 360)
		particles.RotSpeed = NumberRange.new(-40, 40)
		particles.Drag = 3
		particles.LightInfluence = 1
	end
end

local function shake(event)
	if event and event.shake then
		counts.shakes += 1
		CameraController.shake(event.shake, event.duration)
	end
	if event and event.fovPunch then
		CameraController.punch(event.fovPunch, event.duration)
	end
end

local function footfall(rig, side)
	local foot = rig:FindFirstChild(side .. "Foot")
	local attachment = foot and foot:FindFirstChild("Dust")
	if not attachment then
		return
	end
	counts.dust += 1
	-- Hangar dust is grey, outdoor dust is earth.
	local indoors = player:GetAttribute("Zone") == "Hangar"
	local particles = emitter(attachment, if indoors then "DustHangar" else "DustOutdoor", dustSetup(scaleOf(rig), if indoors then DUST_HANGAR else DUST_OUTDOOR))
	particles:Emit(14)
	if rig == FrameController.getFrame() then
		shake(CameraFeel.Events.FrameFootstep)
	end
end

local function trailOf(rig)
	local blade = rig:FindFirstChild("BladeBody", true)
	if not blade then
		return nil
	end
	local trail = blade:FindFirstChild("BladeTrail")
	if not trail then
		trail = Instance.new("Trail")
		trail.Name = "BladeTrail"
		trail.Attachment0 = blade:FindFirstChild("TrailBase")
		trail.Attachment1 = blade:FindFirstChild("TrailTip")
		trail.Color = TRAIL
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.15
		trail.LightEmission = 0.6
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = blade
	end
	return trail
end

local function setThrusters(rig, on)
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == "Thruster" then
			local scale = scaleOf(rig)
			local flame = emitter(descendant, "Flame", function(particles)
				particles.Texture = FIRE
				particles.Color = FLAME
				particles.Size = NumberSequence.new(2.4 * scale, 0.4 * scale)
				particles.Transparency = NumberSequence.new(0.1, 1)
				particles.Lifetime = NumberRange.new(0.2, 0.35)
				particles.Speed = NumberRange.new(30 * scale, 45 * scale)
				particles.SpreadAngle = Vector2.new(8, 8)
				particles.EmissionDirection = Enum.NormalId.Bottom
				particles.LightEmission = 0.8
				particles.Rate = 70
			end)
			flame.Enabled = on
		end
	end
end

local function steam(rig)
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == "Steam" then
			local scale = scaleOf(rig)
			emitter(descendant, "Burst", function(particles)
				particles.Texture = SMOKE
				particles.Color = ColorSequence.new(Color3.new(1, 1, 1))
				particles.Size = NumberSequence.new(1 * scale, 4 * scale)
				particles.Transparency = NumberSequence.new(0.3, 1)
				particles.Lifetime = NumberRange.new(0.5, 0.9)
				particles.Speed = NumberRange.new(8 * scale, 14 * scale)
				particles.SpreadAngle = Vector2.new(25, 25)
				particles.Drag = 2
			end):Emit(12)
		end
	end
end

-- A loose burst at a world position.
local function burst(position, lifetime, setup, amount)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = effects
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 0
	setup(particles)
	particles.Parent = part
	particles:Emit(amount)
	Debris:AddItem(part, lifetime)
end

-- The blade hits the ground: a flat ring racing outward, and dust (docs/06 §6 "Shockwave ring").
local function groundImpact(rig)
	local blade = rig:FindFirstChild("BladeBody", true)
	local tip = blade and blade:FindFirstChild("TrailTip")
	if not tip then
		return
	end
	counts.rings += 1
	local scale = scaleOf(rig)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rig, effects }
	params.CollisionGroup = "Debris"
	local from = tip.WorldPosition + Vector3.new(0, 10 * scale, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -40 * scale, 0), params)
	local ground = if hit then hit.Position else tip.WorldPosition
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = RING
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = effects
	local diameter = 2 * IMPACT_RADIUS * scale
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, diameter, diameter), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
	burst(ground, 1.6, function(particles)
		dustSetup(scale, if player:GetAttribute("Zone") == "Hangar" then DUST_HANGAR else DUST_OUTDOOR)(particles)
		particles.SpreadAngle = Vector2.new(180, 30)
		particles.Speed = NumberRange.new(14 * scale, 22 * scale)
	end, 30)
	if rig == FrameController.getFrame() then
		shake(CameraFeel.Events.LightHit)
	end
end

local function onEvent(rig, _clip, name)
	if name == "TrailOn" or name == "TrailOff" then
		local trail = trailOf(rig)
		if trail then
			trail.Enabled = name == "TrailOn"
			if name == "TrailOn" then
				counts.trails += 1
			end
		end
	elseif name == "ThrustersOn" or name == "ThrustersOff" then
		setThrusters(rig, name == "ThrustersOn")
	elseif name == "SteamBurst" then
		steam(rig)
	elseif name == "GroundImpact" then
		groundImpact(rig)
	end
end

local function onHit(payload)
	counts.sparks += 1
	if typeof(payload.pos) == "Vector3" then
		burst(payload.pos, 1.2, function(particles)
			particles.Texture = SPARKLE
			particles.Color = BONE_DUST
			particles.Size = NumberSequence.new(3, 0)
			particles.Transparency = NumberSequence.new(0, 1)
			particles.Lifetime = NumberRange.new(0.3, 0.6)
			particles.Speed = NumberRange.new(40, 80)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Drag = 4
			particles.LightEmission = 0.3
		end, 24)
	end
	shake(CameraFeel.Events[CameraFeel.MoveEvent[payload.move]])
end

-- The dodge kicks the field of view of the Frame this player pilots.
local function watch(frame)
	if watchConnection then
		watchConnection:Disconnect()
		watchConnection = nil
	end
	watchedFrame = frame
	-- Through the cockpit glass the world is warm; on foot it isn't.
	local tint = CameraFeel.Frame.tint
	TweenService:Create(cockpit, TweenInfo.new(tint.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = if frame then Color3.new(1, 1, 1):Lerp(tint.color, tint.amount) else Color3.new(1, 1, 1),
	}):Play()
	if frame then
		watchConnection = frame:GetAttributeChangedSignal("Action"):Connect(function()
			if frame:GetAttribute("Action") == "Dodge" then
				CameraController.punch(CameraFeel.Frame.fov.dodgeKick, CameraFeel.Frame.fov.dodgeKickTime)
			end
		end)
	end
end

function VFXController.getCounts()
	return counts
end

function VFXController.Init()
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace
	cockpit = Instance.new("ColorCorrectionEffect")
	cockpit.Name = "PG_CockpitTint"
	cockpit.Parent = Lighting
end

function VFXController.Start()
	AnimationController.Footfall:Connect(footfall)
	AnimationController.Event:Connect(onEvent)
	CombatController.Hit:Connect(onHit)
	FrameController.Piloting:Connect(watch)
	watch(FrameController.getFrame())
end

return VFXController
