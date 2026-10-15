--!nonstrict
-- Client/Cinematics/Anomaly.lua  (docs/05_chapter1_script.md S33; docs/maps/map_00 §4 MemorySet)
--
-- The client half of S33, run by CinematicController for CIN_ANOMALY (about 20.6 s), seconds from the start:
--    0.0  the upload overlay: UPLOADING SPINDLE // 12% (0.8 s) -> 37% (0.8 s) -> 61%
--    1.6  the resonance ping: a cyan ring sweeping out over the screen in 0.5 s (30% under Reduce Flashing)
--    1.6  the HUD glitch (5 s): it jitters, the core line turns cyan, the readings print 0.25 s apart
--    6.6  outside (3.5 s): from the outpost's (-20, 20, -540) at the Frame's head; its vents glow cyan and its head
--         turns 45° east by itself over 2.5 s (toward where the Watcher went)
--   10.1  shutdown (1.5 s): the HUD folds, black, CORE OFFLINE in amber, black
--   11.6  the sensory event (8 s): white-cyan over 1 s, then the MemorySet: the man and the child walk away hand in
--         hand at 6 studs/s, the camera dollies, VOICE_01 and VOICE_02 (italic cyan, no name)
--   19.6  a hard cut to black for 1 s; the cinematic then ends behind black and the server goes on (AN_01).
-- No sound yet: the ping's thump and the muffled audio wait for sound IDs (docs/15).
--
--   Anomaly.run(ctx)   ctx = { params = { frame }, alive() -> boolean, takeCamera(), focus(pos, look) }

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationIds = require(Shared.Config.AnimationIds)
local Mission = require(Shared.Dialogue.CH1_Mission)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local Controllers = script.Parent.Parent.Controllers
local FrameHUDController = require(Controllers.FrameHUDController)
local HUDController = require(Controllers.HUDController)
local LightingController = require(Controllers.LightingController)
local SettingsController = require(Controllers.SettingsController)
local UIController = require(Controllers.UIController)

local Anomaly = {}

local CYAN = UIStyle.Resonance
local WHITE_CYAN = Color3.fromHex("#DFF8FB")
local ORIGIN = Vector3.new(6000, 0, 0) -- Outpost 07's origin (builders/maps/outpost07/Layout.ORIGIN)
local OUTSIDE = Vector3.new(-20, 20, -540) -- docs/05 S33, outpost-local
local READINGS = {
	"CORE RESPONSE ............ ANOMALOUS",
	"CORE TISSUE ACTIVITY ..... 412%",
	"MITOTIC RATE ............. ACTIVE",
	"NEURAL LOAD .............. 340%",
	"RESONANCE ................ [ERROR: NO SUCH FIELD]",
	"INHIBITOR LATTICE ........ FAILING",
}
local MEMORY = {
	from = { pos = Vector3.new(8, 2004, 70), look = Vector3.new(0, 2003, 30) },
	to = { pos = Vector3.new(6, 2004, 20), look = Vector3.new(0, 2003, -20) },
	seconds = 8, walkSpeed = 6, walkTo = -120,
}

local function wait(ctx, seconds): boolean
	local done = os.clock() + seconds
	while os.clock() < done do
		if not ctx.alive() then
			return false
		end
		task.wait()
	end
	return ctx.alive()
end

local function overlayLabel(layer, text, size, color)
	return Components.label(layer, text, { font = "Mono", size = size, color = color or UIStyle.Accent }, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0, 520, 0, size + 10),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
	})
end

-- The ping: a ring of resonance racing out from the middle of the screen.
local function ping(layer)
	local ring = Instance.new("Frame")
	ring.Name = "ResonancePing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.02, 0.02)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ring.BackgroundColor3 = CYAN
	ring.BackgroundTransparency = 0.85
	ring.ZIndex = 8
	ring.Parent = layer
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = CYAN
	stroke.Thickness = 10
	stroke.Transparency = if SettingsController.get("reduceFlashing") then 0.7 else 0.1
	stroke.Parent = ring
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromScale(2.2, 2.2), BackgroundTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 2 }):Play()
	task.delay(0.55, function()
		ring:Destroy()
	end)
end

-- The Frame's vents to cyan (or dark), and its head turning east by itself through the look layer.
local function ventColor(frame, color, seconds)
	for _, part in ipairs(frame:GetDescendants()) do
		if part:IsA("BasePart") and CollectionService:HasTag(part, "CoreLight") then
			TweenService:Create(part, TweenInfo.new(seconds), { Color = color }):Play()
		end
	end
end

local function turnHeadEast(ctx, frame, seconds)
	local root = frame.PrimaryPart
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
	local sign = if forward:Cross(Vector3.xAxis).Y < 0 then -1 else 1 -- turn toward +X (east)
	local started = os.clock()
	task.spawn(function()
		while ctx.alive() and frame.Parent do
			local t = math.clamp((os.clock() - started) / seconds, 0, 1)
			local eased = t * t * (3 - 2 * t)
			local direction = CFrame.Angles(0, sign * math.rad(45) * eased, 0) * forward
			frame:SetAttribute("LookTarget", root.Position + Vector3.new(0, 25, 0) + direction * 200)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- The two figures walk away hand in hand: walk animation, the joined hands (map_00 §4), moved on this client.
local function walkFigures(ctx)
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("MemorySet")
	local figures = folder and folder:FindFirstChild("Figures")
	if not figures then
		return
	end
	local hands = { Memory_Man = { "LeftUpperArm", "LeftShoulder", { 10, 0, -15 } }, Memory_Child = { "RightUpperArm", "RightShoulder", { -50, 0, 20 } } }
	local walkers = {}
	for _, model in ipairs(figures:GetChildren()) do
		local animator = model:FindFirstChildOfClass("Humanoid") and model.Humanoid:FindFirstChildOfClass("Animator")
		local root = model:FindFirstChild("HumanoidRootPart")
		if animator and root then
			local animation = Instance.new("Animation")
			animation.AnimationId = AnimationIds.Walk
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play(0.2)
			track:AdjustSpeed(MEMORY.walkSpeed / 14)
			local hand = hands[model.Name]
			local motor = hand and model:FindFirstChild(hand[1]) and model[hand[1]]:FindFirstChild(hand[2])
			table.insert(walkers, { model = model, root = root, start = root.CFrame, track = track, motor = motor, angles = hand and hand[3] })
		end
	end
	local started = os.clock()
	local step = RunService.PreSimulation:Connect(function()
		local travelled = math.min((os.clock() - started) * MEMORY.walkSpeed, 40 - MEMORY.walkTo)
		for _, walker in ipairs(walkers) do
			walker.root.CFrame = walker.start * CFrame.new(0, 0, -travelled)
			if walker.motor then
				local a = walker.angles
				walker.motor.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
			end
		end
	end)
	return function()
		step:Disconnect()
		for _, walker in ipairs(walkers) do
			walker.track:Stop(0)
			walker.root.CFrame = walker.start
		end
	end
end

function Anomaly.run(ctx)
	local frame = ctx.params.frame
	local hudLayer = UIController.getLayer("HUD")
	local topLayer = UIController.getLayer("Letterbox")
	local camera = workspace.CurrentCamera
	local cleanup = {}
	local lighting = LightingController.getCurrent()
	table.insert(cleanup, function()
		-- An interrupted memory leaves its lighting; put back what was there (the server sets Evening after).
		if LightingController.getCurrent() == "MEMORY" and lighting then
			LightingController.apply(lighting, true)
		end
	end)
	local function finally()
		for _, fn in ipairs(cleanup) do
			pcall(fn)
		end
	end

	-- 1. The upload (1.6 s).
	local upload = overlayLabel(hudLayer, "UPLOADING SPINDLE // 12%", 20)
	table.insert(cleanup, function()
		upload:Destroy()
	end)
	if not wait(ctx, 0.8) then
		return finally()
	end
	upload.Text = "UPLOADING SPINDLE // 37%"
	if not wait(ctx, 0.8) then
		return finally()
	end
	upload.Text = "UPLOADING SPINDLE // 61%"

	-- 2. The ping and the HUD glitch (5 s).
	ping(topLayer)
	local hud = FrameHUDController.anomaly()
	table.insert(cleanup, hud.reset)
	task.spawn(hud.print, READINGS, 0.25)
	if not wait(ctx, 1.2) then
		return finally()
	end
	upload:Destroy()
	if not wait(ctx, 3.8) then
		return finally()
	end

	-- 3. Outside (3.5 s): the vents glow cyan, the head turns east.
	if typeof(frame) == "Instance" and frame.PrimaryPart then
		ctx.takeCamera()
		local look = frame.PrimaryPart.Position + Vector3.new(0, 25, 0)
		local from = ORIGIN + OUTSIDE
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(from, look)
		ctx.focus(from, look)
		ventColor(frame, CYAN, 0.8)
		turnHeadEast(ctx, frame, 2.5)
	end
	if not wait(ctx, 3.5) then
		return finally()
	end

	-- 4. Shutdown (1.5 s): the HUD folds, black, CORE OFFLINE, black.
	hud.collapse(0.3)
	if not wait(ctx, 0.3) then
		return finally()
	end
	UIController.fade(1, 0)
	if typeof(frame) == "Instance" then
		ventColor(frame, Color3.fromHex("#2A2D31"), 0) -- dark, as Unit 02 stands in S40
		frame:SetAttribute("LookTarget", nil)
	end
	local offline = overlayLabel(UIController.getLayer("Subtitles"), "CORE OFFLINE", 22)
	offline.Position = UDim2.fromScale(0.5, 0.5)
	table.insert(cleanup, function()
		offline:Destroy()
	end)
	if not wait(ctx, 0.9) then
		return finally()
	end
	offline:Destroy()
	if not wait(ctx, 0.3) then
		return finally()
	end

	-- 5. The sensory event (8 s): white-cyan, then the memory.
	local white = Instance.new("Frame")
	white.Name = "WhiteCyan"
	white.BackgroundColor3 = WHITE_CYAN
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.Size = UDim2.fromScale(1, 1)
	white.ZIndex = 9
	white.Parent = UIController.getLayer("Subtitles") -- over the fade: white-cyan rises out of the black
	table.insert(cleanup, function()
		white:Destroy()
	end)
	TweenService:Create(white, TweenInfo.new(1.0), { BackgroundTransparency = 0.1 }):Play()
	if not wait(ctx, 1.0) then
		return finally()
	end
	UIController.fade(0, 0) -- the black lifts under the white
	LightingController.apply("MEMORY", true)
	ctx.takeCamera()
	camera.FieldOfView = 55
	local stopWalking = walkFigures(ctx)
	if stopWalking then
		table.insert(cleanup, stopWalking)
	end
	TweenService:Create(white, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	local started = os.clock()
	local dolly = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / (MEMORY.seconds - 1), 0, 1)
		local e = t * t * (3 - 2 * t)
		local pos = MEMORY.from.pos:Lerp(MEMORY.to.pos, e)
		local look = MEMORY.from.look:Lerp(MEMORY.to.look, e)
		camera.CFrame = CFrame.lookAt(pos, look)
		ctx.focus(pos, look)
	end)
	table.insert(cleanup, function()
		dolly:Disconnect()
	end)
	local voice = {}
	for id, node in pairs(Mission.DLG_M01_VOICE.nodes) do
		voice[id] = node.text
	end
	task.delay(1.5, function()
		if ctx.alive() and voice.VOICE_01 then
			HUDController.showSubtitle({ text = voice.VOICE_01, speaker = "VOICE", duration = 2.6 })
		end
	end)
	task.delay(4.4, function()
		if ctx.alive() and voice.VOICE_02 then
			HUDController.showSubtitle({ text = voice.VOICE_02, speaker = "VOICE", duration = 2.4 })
		end
	end)
	if not wait(ctx, MEMORY.seconds - 1) then
		return finally()
	end

	-- 6. The hard cut: black, nothing.
	UIController.fade(1, 0)
	wait(ctx, 1.0)
	finally()
end

return Anomaly
