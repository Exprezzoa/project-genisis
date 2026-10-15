--!nonstrict
-- Client/UI/ShiftEffects.lua  (docs/06 §6 "Shifter transformation", docs/02 §8; D-095)
--
-- What a shift looks like on this client (ShifterController plays them):
--   bolt(ground)              the yellow bolt from the sky (6-9 Neon segments, 2-3 forks, redrawn 3 times in 0.35 s),
--                             a ground ring, dust and a light burst (Brightness 8 -> 0, Range 60)
--   flash(layer, reduced)     the full-screen yellow-white flash: 0.12 s up, 0.6 s down (30% with Reduce Flashing)
--   steam(position)           the burst of steam when the Titan form gives way (not in the docs yet)
--   fadeOut(model, seconds)   the Titan's body fading into the steam
--   clench(character, charge) Elias clenching his right fist to his chest until it sparks, wincing (Q-012's
--                             recommended way: no blood, no wound); charge() -> 0..1 while held, nil when let go
-- Yellow (SHIFT_LIGHTNING) is the transformation moment only (docs/06 §3): the bolt, its ring and the sparks.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ShifterConfig = require(Shared.Config.ShifterConfig)

local ShiftEffects = {}

local LIGHTNING = Color3.fromHex("#FFE14A") -- SHIFT_LIGHTNING
local FLASH = Color3.new(1, 1, 1):Lerp(LIGHTNING, 0.35) -- yellow-white
local DUST = Color3.fromHex("#8C7B66") -- the outdoor dust of VFXController
local STEAM = Color3.fromHex("#E8ECEF")

local function effectsFolder()
	return workspace:FindFirstChild("Effects") or workspace
end

local function anchorPart(position, parent)
	local part = Instance.new("Part")
	part.Name = "ShiftAnchor"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = parent
	return part
end

local function segment(a: Vector3, b: Vector3, width: number, parent)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = LIGHTNING
	part.Size = Vector3.new(width, width, (b - a).Magnitude)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	part.Parent = parent
end

-- One jagged path from the sky to the ground, with a few short forks.
local function drawBolt(parent, ground: Vector3, random: Random)
	local spec = ShifterConfig.bolt
	local top = ground + Vector3.new(random:NextNumber(-30, 30), spec.height, random:NextNumber(-30, 30))
	local count = random:NextInteger(spec.segments[1], spec.segments[2])
	local points = { top }
	for index = 1, count - 1 do
		local t = index / count
		local jitter = (1 - t * 0.6) * Vector3.new(random:NextNumber(-14, 14), random:NextNumber(-6, 6), random:NextNumber(-14, 14))
		table.insert(points, top:Lerp(ground, t) + jitter)
	end
	table.insert(points, ground)
	for index = 1, #points - 1 do
		segment(points[index], points[index + 1], spec.width * (1.2 - 0.5 * index / #points), parent)
	end
	for _ = 1, random:NextInteger(spec.forks[1], spec.forks[2]) do
		local from = points[random:NextInteger(2, #points - 1)]
		local to = from + Vector3.new(random:NextNumber(-30, 30), -random:NextNumber(15, 40), random:NextNumber(-30, 30))
		local mid = from:Lerp(to, 0.5) + Vector3.new(random:NextNumber(-6, 6), 0, random:NextNumber(-6, 6))
		segment(from, mid, spec.width * 0.5, parent)
		segment(mid, to, spec.width * 0.4, parent)
	end
end

function ShiftEffects.bolt(ground: Vector3)
	local spec, lightSpec = ShifterConfig.bolt, ShifterConfig.light
	local random = Random.new()
	local holder = Instance.new("Folder")
	holder.Name = "ShiftBolt"
	holder.Parent = effectsFolder()

	-- The light burst and the dust where it strikes.
	local anchor = anchorPart(ground + Vector3.new(0, 6, 0), holder)
	local light = Instance.new("PointLight")
	light.Color = LIGHTNING
	light.Brightness = lightSpec.brightness
	light.Range = lightSpec.range
	light.Shadows = false
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(lightSpec.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(DUST)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.2)
	dust.Speed = NumberRange.new(25, 55)
	dust.SpreadAngle = Vector2.new(180, 8)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -4, 0)
	dust.Drag = 3
	dust.Rate = 0
	dust.Parent = anchor
	dust:Emit(60)

	-- A ring of light runs out over the ground.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = LIGHTNING
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.3, 12, 12)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = holder
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 90, 90), Transparency = 1 }):Play()

	-- The bolt itself, redrawn a few times while it lasts.
	task.spawn(function()
		local each = spec.time / spec.redraws
		for _ = 1, spec.redraws do
			local bolt = Instance.new("Folder")
			bolt.Name = "Bolt"
			bolt.Parent = holder
			drawBolt(bolt, ground, random)
			task.wait(each)
			bolt:Destroy()
		end
	end)
	task.delay(2.5, function()
		holder:Destroy()
	end)
end

function ShiftEffects.flash(layer: ScreenGui, reduced: boolean)
	local spec = ShifterConfig.flash
	local frame = Instance.new("Frame")
	frame.Name = "ShiftFlash"
	frame.BackgroundColor3 = FLASH
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 50
	frame.Parent = layer
	local peak = if reduced then 1 - spec.reduced else 0
	TweenService:Create(frame, TweenInfo.new(spec.up, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = peak }):Play()
	task.delay(spec.up, function()
		TweenService:Create(frame, TweenInfo.new(spec.down, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		task.delay(spec.down, function()
			frame:Destroy()
		end)
	end)
end

function ShiftEffects.steam(position: Vector3)
	local holder = Instance.new("Folder")
	holder.Name = "ShiftSteam"
	holder.Parent = effectsFolder()
	for _, height in ipairs({ 10, 35, 60 }) do
		local anchor = anchorPart(position + Vector3.new(0, height - 31, 0), holder)
		local steam = Instance.new("ParticleEmitter")
		steam.Color = ColorSequence.new(STEAM)
		steam.LightEmission = 0.1
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 34) })
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
		steam.Lifetime = NumberRange.new(2.0, 3.2)
		steam.Speed = NumberRange.new(8, 20)
		steam.SpreadAngle = Vector2.new(70, 70)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Acceleration = Vector3.new(0, 6, 0)
		steam.Drag = 1.5
		steam.Rotation = NumberRange.new(0, 360)
		steam.RotSpeed = NumberRange.new(-30, 30)
		steam.Rate = 24
		steam.Parent = anchor
		steam:Emit(20)
		task.delay(ShifterConfig.collapse + ShifterConfig.fade, function()
			steam.Enabled = false
		end)
	end
	task.delay(ShifterConfig.collapse + ShifterConfig.fade + 3.5, function()
		holder:Destroy()
	end)
end

function ShiftEffects.fadeOut(model: Model, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		elseif part:IsA("Decal") then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		end
	end
end

-- The clench (the pain that makes him shift): the right fist comes up to the chest and tightens, trembling more
-- as the charge rises; the head bows in a wince; in the last third the fist sparks. Written over the default
-- animation each frame (docs/08 §4.6 overlays, YXZ order as D-082).
function ShiftEffects.clench(character: Model, charge: () -> number?)
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local head = character:FindFirstChild("Head")
	local shoulder = upper and upper:FindFirstChild("RightShoulder")
	local elbow = lower and lower:FindFirstChild("RightElbow")
	local neck = head and head:FindFirstChild("Neck")
	if not (shoulder and elbow) then
		return
	end
	local sparks
	if hand then
		sparks = Instance.new("ParticleEmitter")
		sparks.Name = "ShiftSparks"
		sparks.Color = ColorSequence.new(LIGHTNING)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
		sparks.Lifetime = NumberRange.new(0.15, 0.3)
		sparks.Speed = NumberRange.new(6, 12)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Rate = 0
		sparks.Parent = hand
	end
	local weight = 0
	local connection
	connection = RunService.PreSimulation:Connect(function(dt)
		local amount = charge()
		if amount == nil then
			-- Let go: the arm drops back over 0.2 s.
			weight = math.max(0, weight - dt / 0.2)
			if weight <= 0 then
				connection:Disconnect()
				if sparks then
					sparks:Destroy()
				end
				return
			end
		else
			weight = math.min(1, weight + dt / 0.25)
		end
		local level = amount or 0
		local tremble = math.sin(os.clock() * 2 * math.pi * 16) * math.rad(2.5) * level
		shoulder.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(70) * weight + tremble, math.rad(-25) * weight, 0)
		elbow.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(105) * weight, 0, 0)
		if neck then
			neck.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(-18) * weight * (0.4 + 0.6 * level), 0, 0)
		end
		if sparks then
			sparks.Rate = if amount and amount > 0.66 then 40 else 0
		end
	end)
end

return ShiftEffects
