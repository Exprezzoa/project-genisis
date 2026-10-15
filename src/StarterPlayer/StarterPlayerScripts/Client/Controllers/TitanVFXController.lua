--!nonstrict
-- Client/Controllers/TitanVFXController.lua  (docs/10_titans.md §1.4 "Telegraph signals", §2 "Ash Collapse";
-- docs/12 §11; Config/CameraFeel)
--
-- What a Titan shows, on every client: the telegraph of each attack (forearm veins for the Sweep, a ground
-- danger disc for the Stomp, an eye flash for the Lunge, every glow for the Roar), the Stomp's shockwave, the
-- Roar's blast, the open core's glow, foot dust and tremors, the white flash when a hit lands, and the Ash
-- Collapse when it dies. Everything follows the attributes the server publishes (State, Attack, AttackT0,
-- AttackWindup, CoreExposed, DiedAt); nothing here affects gameplay. No sounds yet (the registry has no IDs).
--
--   getCounts() -> { telegraphs, discs, shockwaves, roars, flashes, collapses }      -- for tests

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraFeel = require(Shared.Config.CameraFeel)
local CombatConfig = require(Shared.Config.CombatConfig)

local AnimationController = require(script.Parent.AnimationController)
local CameraController = require(script.Parent.CameraController)
local CombatController = require(script.Parent.CombatController)
local FrameController = require(script.Parent.FrameController)
local SettingsController = require(script.Parent.SettingsController)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TITAN_GLOW, TITAN_GLOW_DEEP = Color3.fromHex("#FF7A2E"), Color3.fromHex("#E25B2D")
local HOT = Color3.fromHex("#FFD38A") -- AMBER_LAMP: a glow at its brightest
local ASH, ASH_DARK = Color3.fromHex("#9C9893"), Color3.fromHex("#6F6B66")
local DUST = Color3.fromHex("#8C7B66")
local PAPER = Color3.fromHex("#E8ECEF")
local VEIN_REST = 0.6 -- the veins' transparency at rest (builders/rigs/Strider)
local DISC = { thickness = 0.2, low = 0.55, high = 0.75, rate = 4 } -- docs/10 §1.4 "ground danger disc"
local FLASH_TIME = 0.08 -- docs/12 §11 "Hit flash"
-- Ash Collapse, seconds after death (docs/10 §2).
local ASHES = { tint = 1.5, tintTime = 4.0, glowTime = 2.0, vapor = 2.0, crumble = { 5.0, 11.0 }, fade = { 8.0, 12.0 }, burst = 12.0 }

local TitanVFXController = {}

local counts = { telegraphs = 0, discs = 0, shockwaves = 0, roars = 0, flashes = 0, collapses = 0 }
local effects
local titans = {} -- [model] = { connections, veins, eyes, glows, orb, disc }
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function tween(instance, time, goal, style, direction)
	local made = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

local function effectPart(props)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = effects
	return part
end

local function burst(position, lifetime, amount, setup)
	local part = effectPart({ Transparency = 1, Size = Vector3.one, Position = position })
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 0
	setup(particles)
	particles.Parent = part
	particles:Emit(amount)
	Debris:AddItem(part, lifetime)
end

local function dust(position, amount, size, speed)
	burst(position, 2.4, amount, function(particles)
		particles.Texture = SMOKE
		particles.Color = ColorSequence.new(DUST)
		particles.Size = NumberSequence.new(size, size * 3)
		particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		particles.Lifetime = NumberRange.new(1.0, 1.8)
		particles.Speed = NumberRange.new(speed * 0.6, speed)
		particles.SpreadAngle = Vector2.new(180, 25)
		particles.EmissionDirection = Enum.NormalId.Top
		particles.Rotation = NumberRange.new(0, 360)
		particles.Drag = 3
		particles.LightInfluence = 1
	end)
end

-- The ground under a point (the map only), or the point itself dropped to `fallback`.
local function groundAt(position, fallback)
	local params = RaycastParams.new()
	params.CollisionGroup = "Debris"
	local hit = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, fallback, position.Z)
end

-- Camera shake for the pilot, fading with distance: full within `full` studs, none at `none`.
local function shake(event, position, full, none)
	local frame = FrameController.getFrame()
	local root = frame and frame.PrimaryPart
	if not (root and event) then
		return
	end
	local distance = ((root.Position - position) * Vector3.new(1, 0, 1)).Magnitude
	local share = if none > full then math.clamp((none - distance) / (none - full), 0, 1) else (if distance <= full then 1 else 0)
	if share > 0 then
		CameraController.shake(event.shake * share, event.duration)
	end
end

local function feetOf(model, root)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return root.Position.Y - root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 0)
end

local function landingOf(model, attackName)
	local root = model.PrimaryPart
	local spec = CombatConfig.TitanAttacks[model:GetAttribute("TitanType")]
	local attack = spec and spec[attackName]
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local point = root.Position + look * (if attack and attack.forward then attack.forward else 0)
	return groundAt(point, feetOf(model, root)), attack
end

----------------------------------------------------------------------------------------------------------------
-- Telegraphs
----------------------------------------------------------------------------------------------------------------
local function setVeins(entry, transparency, time)
	for _, vein in ipairs(entry.veins) do
		tween(vein, time, { Transparency = transparency })
	end
end

local function removeDisc(entry)
	if entry.disc then
		entry.disc:Destroy()
		entry.disc = nil
	end
end

-- Glow parts pulse to their hottest and back; with a light when asked (the Lunge's eye flash).
local function flare(parts, time, light)
	for _, part in ipairs(parts) do
		local rest = part.Color
		part.Color = HOT
		tween(part, time, { Color = rest }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if light then
			local flash = Instance.new("PointLight")
			flash.Name = "EyeFlash"
			flash.Color = TITAN_GLOW
			flash.Range = 48
			flash.Brightness = 8
			flash.Shadows = false
			flash.Parent = part
			tween(flash, time, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(flash, time + 0.1)
		end
	end
end

local function onAttack(model, entry)
	local name = model:GetAttribute("Attack")
	if name == nil or name == "" then
		setVeins(entry, VEIN_REST, 0.4)
		removeDisc(entry)
		return
	end
	counts.telegraphs += 1
	local windup = model:GetAttribute("AttackWindup") or 1
	local left = math.max(0.05, (model:GetAttribute("AttackT0") or now()) + windup - now())
	if name == "Sweep" then
		setVeins(entry, 0, left) -- the forearm veins brighten until the arm comes round
	elseif name == "Stomp" then
		counts.discs += 1
		local ground, attack = landingOf(model, name)
		local diameter = 2 * (if attack then attack.radius else 26)
		removeDisc(entry)
		entry.disc = effectPart({
			Name = "DangerDisc", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = TITAN_GLOW_DEEP, Transparency = 1,
			Size = Vector3.new(DISC.thickness, diameter * 0.2, diameter * 0.2),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		})
		entry.discBorn = os.clock()
		tween(entry.disc, 0.18, { Size = Vector3.new(DISC.thickness, diameter, diameter) }, Enum.EasingStyle.Back)
	elseif name == "Lunge" then
		task.delay(math.min(0.2, left * 0.5), function() -- "eyes flash ... at 0.2 s"
			if model.Parent and model:GetAttribute("Attack") == "Lunge" then
				flare(entry.eyes, 0.45, true)
			end
		end)
	elseif name == "Roar" then
		flare(entry.glows, left + 0.9, false)
		setVeins(entry, 0, left)
	end
end

-- The Stomp lands: a ring racing out to the edge of its reach, dust, and a jolt for a pilot standing near.
local function shockwave(model, entry)
	counts.shockwaves += 1
	local ground, attack = landingOf(model, "Stomp")
	local diameter = 2 * (if attack then attack.radius else 26)
	if entry.disc then
		local disc = entry.disc
		entry.disc = nil
		disc.Color = HOT
		tween(disc, 0.2, { Transparency = 1 })
		Debris:AddItem(disc, 0.25)
	end
	local ring = effectPart({
		Name = "Shockwave", Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Color3.fromHex("#CFC6B4"), Transparency = 0.25,
		Size = Vector3.new(0.5, 6, 6), CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(ring, 0.4, { Size = Vector3.new(0.5, diameter, diameter), Transparency = 1 })
	Debris:AddItem(ring, 0.5)
	dust(ground, 40, 5, 34)
	local event = CameraFeel.Events.StriderStomp
	shake(event, ground, event.within + diameter / 2, event.within + diameter)
end

-- The Roar goes out: a shell of hot air to the edge of its reach, dust at the feet, a long shake (none when a
-- cinematic shakes its own camera).
local function roar(model, noShake)
	counts.roars += 1
	local root = model.PrimaryPart
	local spec = CombatConfig.TitanAttacks[model:GetAttribute("TitanType")]
	local radius = if spec and spec.Roar then spec.Roar.radius else 35
	local shell = effectPart({
		Name = "RoarBlast", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = TITAN_GLOW, Transparency = 0.2,
		Size = Vector3.one * 8, Position = root.Position + Vector3.new(0, 14, 0),
	})
	tween(shell, 0.6, { Size = Vector3.one * (2 * radius + 30), Transparency = 1 })
	Debris:AddItem(shell, 0.7)
	local ground = groundAt(root.Position, feetOf(model, root))
	dust(ground, 50, 6, 46)
	if not noShake then
		shake(CameraFeel.Events.Roar, ground, radius * 2, radius * 5)
	end
end

local function setCore(entry, open)
	local orb = entry.orb
	local light = orb and orb:FindFirstChildWhichIsA("PointLight")
	if not light then
		return
	end
	if entry.coreTween then
		entry.coreTween:Cancel()
		entry.coreTween = nil
	end
	if open then
		-- Wide open and beating: this is what the pilot is meant to strike.
		light.Range = 40
		light.Brightness = 2
		entry.coreTween = TweenService:Create(light, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Brightness = 6 })
		entry.coreTween:Play()
		orb.Color = HOT
		tween(orb, 0.6, { Color = TITAN_GLOW })
	else
		local rest = entry.coreRest or { brightness = 0.8, range = 14 }
		tween(light, 0.4, { Brightness = rest.brightness, Range = rest.range })
	end
end

----------------------------------------------------------------------------------------------------------------
-- Ash Collapse (docs/10 §2): the client's part of it. The server leaves the mounds and removes the body.
----------------------------------------------------------------------------------------------------------------
local function waitUntil(model, diedAt, at)
	local left = diedAt + at - now()
	if left > 0 then
		task.wait(left)
	end
	return model.Parent ~= nil
end

local function collapse(model, entry)
	counts.collapses += 1
	local diedAt = model:GetAttribute("DiedAt") or now()
	removeDisc(entry)
	setCore(entry, false)
	local body, glow = {}, {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			table.insert(if CollectionService:HasTag(part, "TitanGlow") then glow else body, part)
		end
	end
	if not waitUntil(model, diedAt, ASHES.tint) then
		return
	end
	-- 1.5: skin goes to ash over 4 s; the glows die in 2.
	for _, part in ipairs(body) do
		tween(part, ASHES.tintTime, { Color = if random:NextNumber() < 0.3 then ASH_DARK else ASH }, Enum.EasingStyle.Linear)
	end
	for _, part in ipairs(glow) do
		tween(part, ASHES.glowTime, { Color = ASH }, Enum.EasingStyle.Linear)
		for _, light in ipairs(part:GetChildren()) do
			if light:IsA("Light") then
				tween(light, ASHES.glowTime, { Brightness = 0 }, Enum.EasingStyle.Linear)
			end
		end
	end
	if not waitUntil(model, diedAt, ASHES.vapor) then
		return
	end
	-- 2.0: vapor rises off the torso, head and limbs.
	local emitters = {}
	for _, name in ipairs({ "UpperTorso", "Head", "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg" }) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			local vapor = Instance.new("ParticleEmitter")
			vapor.Name = "AshVapor"
			vapor.Texture = SMOKE
			vapor.Color = ColorSequence.new(ASH)
			vapor.Size = NumberSequence.new(6, 14)
			vapor.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			vapor.Rate = 30
			vapor.Lifetime = NumberRange.new(3, 4)
			vapor.Speed = NumberRange.new(3, 6)
			vapor.Acceleration = Vector3.new(0, 4, 0)
			vapor.SpreadAngle = Vector2.new(40, 40)
			vapor.Rotation = NumberRange.new(0, 360)
			vapor.LightInfluence = 1
			vapor.Parent = part
			table.insert(emitters, vapor)
		end
	end
	if not waitUntil(model, diedAt, ASHES.crumble[1]) then
		return
	end
	-- 5.0-11.0: it crumbles: flakes break off all over the body, fall and fade. From 8.0 the body itself fades.
	local fading = false
	while model.Parent and now() - diedAt < ASHES.crumble[2] do
		for _ = 1, 3 do
			local from = body[random:NextInteger(1, #body)]
			if from and from.Parent then
				local size = random:NextNumber(0.8, 2.6)
				local offset = Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5)) * from.Size
				local flake = effectPart({
					Name = "AshFlake", Anchored = false, Material = Enum.Material.Sand, Color = if random:NextNumber() < 0.5 then ASH else ASH_DARK,
					Size = Vector3.new(size, size * 0.6, size), CFrame = from.CFrame * CFrame.new(offset),
				})
				flake.CollisionGroup = "Debris"
				flake.CanCollide = true
				flake.AssemblyLinearVelocity = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(2, 10), random:NextNumber(-8, 8))
				tween(flake, 1.5, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(flake, 1.6)
			end
		end
		if not fading and now() - diedAt >= ASHES.fade[1] then
			fading = true
			local time = ASHES.fade[2] - ASHES.fade[1]
			for _, part in ipairs(model:GetDescendants()) do
				if (part:IsA("BasePart") and part.Transparency < 1) or part:IsA("Decal") or part:IsA("Texture") then
					tween(part, time, { Transparency = 1 }, Enum.EasingStyle.Linear)
				end
			end
		end
		task.wait(0.1)
	end
	if not waitUntil(model, diedAt, ASHES.burst) then
		return
	end
	-- 12.0: what is left goes up in a burst of grey flakes.
	for _, vapor in ipairs(emitters) do
		vapor.Enabled = false
	end
	local root = model.PrimaryPart
	if root then
		burst(root.Position - Vector3.new(0, 14, 0), 3, 80, function(particles)
			particles.Texture = SPARKLE
			particles.Color = ColorSequence.new(ASH)
			particles.Size = NumberSequence.new(2.5, 0.5)
			particles.Transparency = NumberSequence.new(0.1, 1)
			particles.Lifetime = NumberRange.new(1.2, 2.2)
			particles.Speed = NumberRange.new(10, 28)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Acceleration = Vector3.new(0, -6, 0)
			particles.Drag = 2
			particles.LightEmission = 0
		end)
	end
end

-- An ash mound the server left: it rises out of the ground instead of appearing (docs/10 §2 "grow over 6 s").
local function growMound(mound)
	local grow = mound:GetAttribute("Grow")
	if not (mound:IsA("BasePart") and type(grow) == "number" and grow > 0) then
		return
	end
	local size, cframe = mound.Size, mound.CFrame
	mound.Size = Vector3.new(0.2, size.Y * 0.3, size.Z * 0.3)
	mound.CFrame = cframe * CFrame.new(-(size.X - 0.2) / 2, 0, 0) -- the cylinder's axis points up: it starts flat on the ground
	tween(mound, grow, { Size = size, CFrame = cframe }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
end

----------------------------------------------------------------------------------------------------------------
-- Watching Titans
----------------------------------------------------------------------------------------------------------------
local function onState(model, entry)
	local state = model:GetAttribute("State")
	local attack = model:GetAttribute("Attack")
	if state == "Active" then
		if attack == "Stomp" then
			shockwave(model, entry)
		elseif attack == "Roar" then
			roar(model)
		end
	elseif state == "Downed" then
		removeDisc(entry)
		setVeins(entry, VEIN_REST, 0.2)
		task.delay(0.6, function() -- its hands hit the ground
			local root = model.PrimaryPart
			if model.Parent and root and model:GetAttribute("State") == "Downed" then
				local ground = groundAt(root.Position + root.CFrame.LookVector * 14, feetOf(model, root))
				dust(ground, 36, 5, 26)
				shake(CameraFeel.Events.StriderStomp, ground, 60, 140)
			end
		end)
	elseif state == "Flinch" then
		removeDisc(entry)
		setVeins(entry, VEIN_REST, 0.15)
	elseif state == "Dead" and not entry.dead then
		entry.dead = true
		task.spawn(collapse, model, entry)
	end
end

-- Finds the Titan's glowing parts. Run again a moment after the first look: parts can arrive after the tag.
local function scan(model, entry)
	table.clear(entry.veins)
	table.clear(entry.eyes)
	table.clear(entry.glows)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and CollectionService:HasTag(part, "TitanGlow") then
			if CollectionService:HasTag(part, "VeinGlow") then
				table.insert(entry.veins, part)
			elseif part.Name == "CoreOrb" then
				entry.orb = part
			else
				table.insert(entry.eyes, part)
			end
			table.insert(entry.glows, part)
		end
	end
	if not entry.coreRest then
		local light = entry.orb and entry.orb:FindFirstChildWhichIsA("PointLight")
		if light then
			entry.coreRest = { brightness = light.Brightness, range = light.Range }
		end
	end
end

local function watch(model)
	if not model:IsA("Model") or model:GetAttribute("TitanType") == nil then
		return
	end
	local entry = titans[model]
	if entry then
		scan(model, entry)
		return
	end
	entry = { connections = {}, veins = {}, eyes = {}, glows = {} }
	titans[model] = entry
	scan(model, entry)
	table.insert(entry.connections, model:GetAttributeChangedSignal("Attack"):Connect(function()
		onAttack(model, entry)
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("State"):Connect(function()
		onState(model, entry)
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("CoreExposed"):Connect(function()
		setCore(entry, model:GetAttribute("CoreExposed") == true)
	end))
	if model:GetAttribute("CoreExposed") then
		setCore(entry, true)
	end
end

local function unwatch(model)
	local entry = titans[model]
	if entry then
		titans[model] = nil
		for _, connection in ipairs(entry.connections) do
			connection:Disconnect()
		end
		removeDisc(entry)
	end
end

-- Danger discs pulse (0.75 <-> 0.55 at 4 Hz) and stay under the foot that will come down while the Titan turns.
local function stepDiscs()
	for model, entry in pairs(titans) do
		local disc = entry.disc
		if disc and model.PrimaryPart then
			local wave = 0.5 + 0.5 * math.sin((os.clock() - entry.discBorn) * DISC.rate * 2 * math.pi)
			disc.Transparency = DISC.low + (DISC.high - DISC.low) * wave
			local ground = landingOf(model, "Stomp")
			disc.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

-- A Titan's foot comes down: dust, and a tremor that fades with distance.
local function footfall(rig, side)
	if not titans[rig] then
		return
	end
	local root = rig.PrimaryPart
	local foot = rig:FindFirstChild(side .. "Foot", true)
	local position = if foot and foot:IsA("BasePart") then foot.Position else root.Position
	local ground = Vector3.new(position.X, feetOf(rig, root), position.Z)
	dust(ground, 10, 3, 14)
	local event = CameraFeel.Events.StriderFootstep
	shake(event, ground, event.fullWithin, event.zeroAt)
end

-- One of our hits landed on a Titan: it flashes white for a blink (docs/12 §11), unless Reduce Flashing is on.
local function onHit(payload)
	if SettingsController.get("reduceFlashing") then
		return
	end
	for model in pairs(titans) do
		if model:GetAttribute("TargetId") == payload.targetId then
			counts.flashes += 1
			local flash = Instance.new("Highlight")
			flash.Name = "HitFlash"
			flash.FillColor = PAPER
			flash.FillTransparency = 0.35
			flash.OutlineTransparency = 1
			flash.DepthMode = Enum.HighlightDepthMode.Occluded
			flash.Parent = model
			Debris:AddItem(flash, FLASH_TIME)
		end
	end
end

-- S28's intro (docs/05 Shot 3): the eyes flare as it turns to Unit 02 (a 0.4 s bloom pulse, clue 6), then it roars:
-- every glow, the hot shell and a ring of dust. Only effects: the cinematic shakes its camera, nothing is hit.
function TitanVFXController.introRoar(model)
	local entry = titans[model]
	if not entry then
		return
	end
	flare(entry.eyes, 0.4, true)
	task.delay(0.45, function()
		if model.Parent then
			flare(entry.glows, 1.4, false)
			roar(model, true)
		end
	end)
end

function TitanVFXController.getCounts()
	return counts
end

function TitanVFXController.Init()
	effects = workspace:FindFirstChild("Effects")
	if not effects then
		effects = Instance.new("Folder")
		effects.Name = "Effects"
		effects.Parent = workspace
	end
end

function TitanVFXController.Start()
	local function onRig(model)
		-- A spawned Titan's tag can arrive before its parts and attributes: look again shortly after.
		watch(model)
		task.delay(1, watch, model)
	end
	CollectionService:GetInstanceAddedSignal("PoseRig"):Connect(onRig)
	CollectionService:GetInstanceRemovedSignal("PoseRig"):Connect(unwatch)
	for _, model in ipairs(CollectionService:GetTagged("PoseRig")) do
		onRig(model)
	end
	CollectionService:GetInstanceAddedSignal("AshMound"):Connect(growMound)
	AnimationController.Footfall:Connect(footfall)
	CombatController.Hit:Connect(onHit)
	RunService.Heartbeat:Connect(stepDiscs)
end

return TitanVFXController
