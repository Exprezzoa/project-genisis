--!nonstrict
-- Client/Cinematics/FirstShift.lua  (D-096; user direction: "First time shifting should have a cinematic where the
-- player can't control them and starts to go insane then it shifts with impact frames from the lightning")
--
-- The client half of CIN_FIRST_SHIFT, run by CinematicController (letterboxed, the HUD away, no skipping). Its
-- timeline, with the server's bolt at ShifterConfig.firstShift.strikeAt (5.2 s):
--   0.0  close on Elias's face from the front; a heartbeat darkens the edges of the screen
--   0.9  he grips his chest; "Something's wrong. My head—"
--   1.6  it gets worse: the view tilts and sways, colour drains, the heartbeat speeds up, the screen stutters
--        black; he clutches his head with both hands; "Stop. Stop it—"
--   3.6  the fist again (the pain that shifts him: Q-012's way, no wound), tighter and tighter until it sparks;
--        the view closes in; "MAKE IT STOP."
--   4.7  impact frames: black / white / stark black-and-white, the bolt cut out of them
--   5.2  the server's bolt and flash; under the white the Titan stands where he was
--   5.4  from low behind it, the Titan rising out of its crouch (Emerge), the colour coming back; ends at 8.8
-- The three thought lines are placeholders until the user writes the scene (D-096).
--
--   FirstShift.run(ctx)   ctx = { alive() -> boolean, takeCamera(), focus(pos, look) }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShifterConfig = require(Shared.Config.ShifterConfig)

local Controllers = script.Parent.Parent.Controllers
local HUDController = require(Controllers.HUDController)
local SettingsController = require(Controllers.SettingsController)
local UIController = require(Controllers.UIController)
local ShiftEffects = require(script.Parent.Parent.UI.ShiftEffects)

local FirstShift = {}

local LIGHTNING = Color3.fromHex("#FFE14A") -- SHIFT_LIGHTNING
local INK = Color3.fromHex("#0B0E10")
local PAPER = Color3.fromHex("#E8ECEF")
local LINES = {
	{ at = 0.9, text = "Something's wrong. My head—", duration = 1.6 },
	{ at = 2.6, text = "Stop. Stop it—", duration = 1.2 },
	{ at = 3.9, text = "MAKE IT STOP.", duration = 1.0 },
}

local localPlayer = Players.LocalPlayer

-- Four dark edges that pulse with the heartbeat.
local function buildVignette(layer)
	local holder = Instance.new("Frame")
	holder.Name = "FirstShiftVignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 40
	holder.Parent = layer
	local edges = {}
	for _, spec in ipairs({
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.35), 90 }, { UDim2.fromScale(0, 0.65), UDim2.fromScale(1, 0.35), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.3, 1), 0 }, { UDim2.fromScale(0.7, 0), UDim2.fromScale(0.3, 1), 180 },
	}) do
		local edge = Instance.new("Frame")
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Color3.new(0, 0, 0)
		edge.Position, edge.Size = spec[1], spec[2]
		edge.ZIndex = 40
		edge.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec[3]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = edge
		table.insert(edges, edge)
	end
	return holder, edges
end

-- A jagged bolt drawn in UI frames from the top of the screen down to the middle.
local function drawBolt(parent, color, zIndex, random)
	local size = parent.AbsoluteSize
	local points = { Vector2.new(size.X * random:NextNumber(0.4, 0.6), -10) }
	local count = random:NextInteger(7, 10)
	for index = 1, count do
		local t = index / count
		table.insert(points, Vector2.new(size.X * (0.5 + random:NextNumber(-0.12, 0.12) * (1 - t * 0.5)), size.Y * 0.62 * t))
	end
	local function segment(a, b, width)
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		line.Size = UDim2.fromOffset((b - a).Magnitude + width, width)
		line.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
		line.ZIndex = zIndex
		line.Parent = parent
	end
	for index = 1, #points - 1 do
		segment(points[index], points[index + 1], 9)
	end
	for _ = 1, 3 do
		local from = points[random:NextInteger(2, #points - 1)]
		local to = from + Vector2.new(random:NextNumber(-140, 140), random:NextNumber(40, 120))
		segment(from, to, 4)
	end
end

-- Impact frames: a few frames each of black with a white bolt, white with a black bolt, and the world stark black
-- and white. With Reduce Flashing on, fewer and greyer.
local function impactFrames(layer, correction, alive)
	local reduced = SettingsController.get("reduceFlashing") == true
	local random = Random.new()
	local holder = Instance.new("Frame")
	holder.Name = "ImpactFrames"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 60
	holder.Parent = layer
	local order = if reduced then { "dark", "stark" } else { "dark", "light", "stark", "dark", "light", "stark", "dark" }
	for _, kind in ipairs(order) do
		if not alive() then
			break
		end
		holder:ClearAllChildren()
		correction.Saturation, correction.Contrast, correction.Brightness = -1, 0, 0
		if kind == "stark" then
			correction.Contrast, correction.Brightness = 1.6, 0.1
		else
			local back = Instance.new("Frame")
			back.BorderSizePixel = 0
			back.Size = UDim2.fromScale(1, 1)
			back.BackgroundColor3 = if kind == "dark" then INK else PAPER
			back.BackgroundTransparency = if reduced then 0.35 else 0
			back.ZIndex = 60
			back.Parent = holder
			drawBolt(holder, if kind == "dark" then PAPER else INK, 61, random)
		end
		task.wait(0.07)
	end
	holder:Destroy()
end

-- Both hands come up to the head (written over the default animation each frame, YXZ order as D-082).
local function clutchHead(character, weight)
	local parts = {}
	for _, name in ipairs({ "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Neck", "Waist" }) do
		parts[name] = character:FindFirstChild(name, true)
	end
	local connection = RunService.PreSimulation:Connect(function()
		local w = weight()
		if w <= 0 then
			return
		end
		local shake = math.sin(os.clock() * 2 * math.pi * 11) * math.rad(3) * w
		if parts.RightShoulder then
			parts.RightShoulder.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(150) * w + shake, math.rad(-20) * w, math.rad(-25) * w)
		end
		if parts.LeftShoulder then
			parts.LeftShoulder.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(150) * w - shake, math.rad(20) * w, math.rad(25) * w)
		end
		if parts.RightElbow then
			parts.RightElbow.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(120) * w, 0, 0)
		end
		if parts.LeftElbow then
			parts.LeftElbow.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(120) * w, 0, 0)
		end
		if parts.Neck then
			parts.Neck.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(-20) * w + shake, 0, 0)
		end
		if parts.Waist then
			parts.Waist.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(-15) * w, 0, shake * 0.5)
		end
	end)
	return connection
end

local function findTitan()
	local folder = workspace:FindFirstChild("Shifters")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:GetAttribute("Rider") == localPlayer.UserId then
			return model
		end
	end
	return nil
end

function FirstShift.run(ctx)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not (root and head) then
		return
	end
	ctx.takeCamera()
	local camera = workspace.CurrentCamera
	local layer = UIController.getLayer("Fade")
	local vignette, edges = buildVignette(layer)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "PG_FirstShift"
	correction.Parent = Lighting
	local started = os.clock()
	local function t()
		return os.clock() - started
	end
	local clutchWeight = 0
	local clutch = clutchHead(character, function()
		return clutchWeight
	end)
	local clench = 0
	ShiftEffects.clench(character, function()
		local now = t()
		if not ctx.alive() or now > ShifterConfig.firstShift.strikeAt then
			return nil
		end
		return clench
	end)
	local said = {}
	local strikeAt = ShifterConfig.firstShift.strikeAt
	local lastBeat, beat = 0, 0
	local stutterUntil = 0
	local random = Random.new()

	-- Elias, from the front, falling apart.
	while ctx.alive() and t() < 4.7 do
		local now = t()
		for index, line in ipairs(LINES) do
			if not said[index] and now >= line.at then
				said[index] = true
				HUDController.showSubtitle({ text = line.text, speaker = "E", thought = true, duration = line.duration })
			end
		end
		local dread = math.clamp((now - 1.2) / 3.0, 0, 1) -- how far gone he is
		clench = if now < 0.9 then 0 elseif now < 1.6 then 0.35 elseif now < 3.6 then 0 else math.clamp((now - 3.6) / 1.0, 0, 1)
		clutchWeight = if now < 1.6 then 0 elseif now < 3.4 then math.clamp((now - 1.6) / 0.4, 0, 1) else math.clamp((3.8 - now) / 0.4, 0, 1)
		-- The heartbeat: a hard pulse of the dark edges, faster as it goes on.
		local period = 0.9 - 0.45 * dread
		if now - lastBeat >= period then
			lastBeat, beat = now, 1
		end
		beat = math.max(0, beat - (1 / 0.25) * (1 / 60))
		for _, edge in ipairs(edges) do
			edge.BackgroundTransparency = 0.55 - 0.4 * dread - 0.25 * beat
		end
		-- The colour drains and the contrast climbs; now and then the screen stutters to black.
		correction.Saturation = -0.75 * dread
		correction.Contrast = 0.35 * dread
		correction.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHex("#B8C4C9"), 0.4 * dread)
		if now > 2.0 and now < 4.6 and random:NextNumber() < 0.04 + 0.08 * dread and now > stutterUntil then
			stutterUntil = now + 0.12
			correction.Brightness = -0.9
		elseif now > stutterUntil then
			correction.Brightness = 0
		end
		-- The camera: in front of his face, pushing in, tilting and swaying more and more.
		local face = head.CFrame
		local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		forward = if forward.Magnitude > 0.1 then forward.Unit else Vector3.zAxis
		local distance = 7 - 3.2 * math.clamp(now / 4.6, 0, 1)
		local sway = Vector3.new(math.sin(now * 2.1), math.sin(now * 3.3) * 0.5, 0) * (0.15 + 0.9 * dread)
		local from = face.Position + forward * distance + Vector3.new(0, -0.6, 0) + root.CFrame:VectorToWorldSpace(sway)
		local look = face.Position + Vector3.new(0, -0.2, 0)
		local tilt = math.rad(math.sin(now * 1.7) * 9 * dread + (if now > 3.6 then math.sin(now * 23) * 2 else 0))
		camera.CFrame = CFrame.lookAt(from, look) * CFrame.Angles(0, 0, tilt)
		camera.FieldOfView = 60 - 18 * math.clamp((now - 3.4) / 1.2, 0, 1)
		ctx.focus(from, look)
		RunService.RenderStepped:Wait()
	end
	clutch:Disconnect()
	for _, edge in ipairs(edges) do
		edge.BackgroundTransparency = 0.2
	end

	-- The lightning: impact frames until the real bolt lands.
	if ctx.alive() then
		impactFrames(layer, correction, ctx.alive)
	end
	correction.Saturation, correction.Contrast, correction.Brightness = -0.5, 0.3, 0
	while ctx.alive() and t() < strikeAt + 0.2 do
		RunService.RenderStepped:Wait()
	end

	-- From low behind the Titan as it rises; the colour and the edges come back.
	local titan = nil
	local waited = 0
	while ctx.alive() and not titan and waited < 2 do
		titan = findTitan()
		if not titan then
			waited += RunService.RenderStepped:Wait()
		end
	end
	local reveal = os.clock()
	TweenService:Create(correction, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	for _, edge in ipairs(edges) do
		TweenService:Create(edge, TweenInfo.new(1.6), { BackgroundTransparency = 1 }):Play()
	end
	while ctx.alive() and titan and titan.PrimaryPart and t() < 8.8 do
		local k = math.clamp((os.clock() - reveal) / 3.2, 0, 1)
		local eased = k * k * (3 - 2 * k)
		local base = titan.PrimaryPart.CFrame
		local from = (base * CFrame.new(28 - 6 * eased, -24 + 10 * eased, 52 - 14 * eased)).Position
		local headPart = titan:FindFirstChild("Head")
		local look = if headPart then headPart.Position else base.Position + Vector3.new(0, 30, 0)
		camera.CFrame = CFrame.lookAt(from, look)
		camera.FieldOfView = 55 + 10 * eased
		ctx.focus(from, look)
		RunService.RenderStepped:Wait()
	end
	correction:Destroy()
	vignette:Destroy()
	if not ctx.alive() then
		return
	end
end

return FirstShift
