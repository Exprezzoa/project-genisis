--!nonstrict
-- Client/UI/CharacterStage.lua  (docs/14_ui.md §1.2)
--
-- The stage behind every menu screen: the dimmed game view, the diagonal amber band on the left, and on the
-- right a one-color silhouette of the player's character in front of a color field. The silhouette is alive:
-- it breathes, sways and looks around, and every screen has its own pose, camera shot and colors. Changing
-- screens flies the camera to the next shot while the character moves into the next pose.
--
-- No images and no uploaded animations: the silhouette is a clone of the character inside a ViewportFrame,
-- every part white under pure ambient light and tinted with ImageColor3 (ink; a second, offset copy tinted
-- paper-white is its shadow). It is posed by code every frame (UI/SilhouetteRig).
--
--   build(parent) -> Frame      show(screenName, instant)      hide()      getShot() -> screenName?
--   update(dt)                  -- one animation step (runs on RenderStepped while shown; also for previews)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = require(script.Parent.Components)
local SilhouetteRig = require(script.Parent.SilhouetteRig)

local Stage = {}

local V = Vector3.new
local function hex(value)
	return Color3.fromHex(value)
end

-- The silhouette stands at the origin facing -Z, feet at Y 0 (head about Y 5.2, hands about Y 2.2); its
-- right side is +X. Per screen:
--   from/at/fov   the camera shot
--   field/stripe  the color field behind the silhouette and its accent stripe (palette colors, docs/06 §3)
--   pose          joint angles in degrees the character moves into (SilhouetteRig convention)
--   motion        this screen's own gesture, layered on the idle motion (same format as IDLE below)
-- Screens without an entry use DEFAULT.
-- One color means only the outline reads, so every pose keeps a limb clear of the body and every shot is
-- wide enough to show it.
Stage.SHOTS = {
	-- Full body, three-quarter view: one foot ahead, right fist held in front, looking toward the camera.
	Pause = {
		from = V(-6.5, 3.0, -8.2), at = V(0.9, 2.8, 0.6), fov = 38, field = hex("#E8A33D"), stripe = hex("#E07A1F"),
		pose = {
			Waist = V(-3, -6, 0), Neck = V(2, 22, 0),
			RightShoulder = V(28, 0, 4), RightElbow = V(72, 0, 0),
			LeftShoulder = V(-22, 0, -12), LeftElbow = V(16, 0, 0),
			RightHip = V(26, 0, 10), RightKnee = V(-16, 0, 0), LeftHip = V(-22, 0, -10), LeftKnee = V(-12, 0, 0),
		},
		motion = { { "RightElbow", "X", 5, 0.2, 0 }, { "Waist", "Z", 1.5, 0.12, 0 } },
	},
	-- Waist up, from the front: he lifts his left hand to the side of the mask, elbow out, and adjusts it.
	Settings = {
		from = V(-0.6, 4.4, -9.6), at = V(1.3, 3.8, 0), fov = 34, field = hex("#9FB4C4"), stripe = hex("#E8A33D"),
		pose = {
			Waist = V(0, 6, 0), Neck = V(-4, 10, -6),
			LeftShoulder = V(8, 0, -80), LeftElbow = V(0, 0, -133),
			RightShoulder = V(2, 0, 10), RightElbow = V(8, 0, 0),
		},
		motion = { { "LeftElbow", "Z", 5, 0.45, 0 }, { "Neck", "Z", 3, 0.45, 0.25 } },
	},
	-- From his right side: he holds the right forearm out and looks down at it, reading the log off his wrist.
	MissionLog = {
		from = V(10.8, 4.3, -1.2), at = V(0, 4.0, 1.0), fov = 34, field = hex("#FFD38A"), stripe = hex("#E8A33D"),
		pose = {
			Waist = V(-5, 0, 0), Neck = V(-20, 0, 0),
			RightShoulder = V(58, 0, 0), RightElbow = V(64, 0, 0), RightWrist = V(-10, 0, 0),
			LeftShoulder = V(-14, 0, -4), LeftElbow = V(8, 0, 0),
			RightHip = V(8, 0, 0), LeftHip = V(-8, 0, 0),
		},
		motion = { { "RightWrist", "X", 12, 0.4, 0 }, { "RightElbow", "X", 5, 0.2, 0.5 }, { "Neck", "X", 3, 0.2, 0 } },
	},
	-- Equipment (Phase 6): a shot of the raised forearm, to be tuned the same way when the screen exists.
}
Stage.DEFAULT = "Pause"
Stage.MOVE = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Stage.POSE_RATE = 7 -- how fast the body moves into a new pose (1/s; higher = snappier)

-- Idle motion layered on every pose: { joint, axis, degrees, cycles per second, phase }.
local IDLE = {
	{ "Waist", "X", 2, 0.26, 0 }, -- breathing
	{ "Waist", "Y", 2.5, 0.09, 0.6 }, -- slow turn of the shoulders
	{ "Neck", "Y", 7, 0.11, 0.3 }, -- slow look around
	{ "Neck", "X", 2, 0.19, 1.1 },
	{ "RightShoulder", "Z", 2.5, 0.26, 0.4 },
	{ "LeftShoulder", "Z", -2.5, 0.26, 0.4 },
	{ "RightElbow", "X", 3, 0.17, 2.0 },
	{ "LeftElbow", "X", 3, 0.15, 0.7 },
}
local BOB = { height = 0.05, rate = 0.26 } -- the whole body rises and sinks with the breath

local root, band, field, stripe
local views = {} -- { { frame, camera, home, rig } }
local current = nil
local loaded = false
local clock = 0
local pose = {} -- the pose being shown: [joint] = Vector3 degrees
local target = Stage.SHOTS[Stage.DEFAULT].pose
local motion = nil -- the current screen's gesture waves
local connection = nil

-- A white, unlit, anchored copy of the character: StarterCharacter (rest pose) or, failing that, the live one.
local function makeSilhouette()
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source then
		local player = Players.LocalPlayer
		source = player and player.Character
	end
	if not source then
		return nil
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local model = source:Clone()
	source.Archivable = wasArchivable
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Color = Color3.new(1, 1, 1)
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Transparency = if descendant.Name == "HumanoidRootPart" then 1 else 0
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") or descendant:IsA("SurfaceGui") or descendant:IsA("LuaSourceContainer") or descendant:IsA("Light") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end
	-- Facing -Z (the pivot is the root part), centered on the origin, feet on Y 0.
	model:PivotTo(CFrame.new(model:GetPivot().Position))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (V(0, size.Y / 2, 0) - box.Position))
	return model
end

local function ensureLoaded()
	if loaded then
		return
	end
	for _, view in ipairs(views) do
		local model = makeSilhouette()
		if not model then
			return -- no character yet; try again on the next show
		end
		view.rig = SilhouetteRig.new(model)
		model.Parent = view.frame
	end
	loaded = true
end

local function viewport(parent, name, tint, offset, zIndex)
	local frame = Instance.new("ViewportFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, offset.X, 0.5, offset.Y)
	frame.Size = UDim2.fromScale(0.52, 1)
	frame.Ambient = Color3.new(1, 1, 1)
	frame.LightColor = Color3.new(0, 0, 0)
	frame.ImageColor3 = tint
	frame.ZIndex = zIndex
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.Parent = frame
	frame.CurrentCamera = camera
	table.insert(views, { frame = frame, camera = camera, home = frame.Position })
	return frame
end

-- One animation step: ease the pose toward the screen's pose, add the idle motion, apply it to both copies.
function Stage.update(dt)
	if not loaded then
		return
	end
	clock += dt
	local alpha = 1 - math.exp(-Stage.POSE_RATE * dt)
	for joint, goal in pairs(target) do
		pose[joint] = (pose[joint] or Vector3.zero):Lerp(goal, alpha)
	end
	for joint, value in pairs(pose) do
		if not target[joint] then
			pose[joint] = value:Lerp(Vector3.zero, alpha)
		end
	end
	local final = table.clone(pose)
	for _, waves in ipairs({ IDLE, motion or {} }) do
		for _, wave in ipairs(waves) do
			local swing = wave[3] * math.sin((clock * wave[4] + wave[5]) * 2 * math.pi)
			local axis = if wave[2] == "X" then V(swing, 0, 0) elseif wave[2] == "Y" then V(0, swing, 0) else V(0, 0, swing)
			final[wave[1]] = (final[wave[1]] or Vector3.zero) + axis
		end
	end
	local bob = CFrame.new(0, BOB.height * math.sin(clock * BOB.rate * 2 * math.pi), 0)
	for _, view in ipairs(views) do
		view.rig:apply(final, bob)
	end
end

function Stage.build(parent)
	root = Instance.new("Frame")
	root.Name = "Stage"
	root.BackgroundColor3 = UIStyle.Ink
	root.BackgroundTransparency = 0.35
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 0
	root.Visible = false
	root.Parent = parent

	-- Right: color field, accent stripe, shadow and silhouette.
	field = Components.slab(root, { color = Stage.SHOTS[Stage.DEFAULT].field }, {
		Name = "Field",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 160, 0.5, 0),
		Size = UDim2.new(0.46, 160, 1.3, 0),
	})
	stripe = Components.slab(root, { color = Stage.SHOTS[Stage.DEFAULT].stripe }, {
		Name = "Stripe",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.54, 30, 0.5, 0),
		Size = UDim2.new(0, 46, 1.3, 0),
	})
	viewport(root, "SilhouetteShadow", UIStyle.Paper, Vector2.new(14, 10), 2)
	viewport(root, "Silhouette", UIStyle.Ink, Vector2.new(0, 0), 3)

	-- Left: the diagonal amber band the pause column sits on, with a thin ink band beside it.
	band = Components.slab(root, { color = UIStyle.Accent, slant = false }, {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.16, 0.5),
		Size = UDim2.new(0, 300, 3, 0),
		Rotation = UIStyle.Slant,
		ZIndex = 4,
	})
	Components.slab(root, { color = UIStyle.Ink, slant = false }, {
		Name = "BandShade",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.16, 190, 0.5, 0),
		Size = UDim2.new(0, 36, 3, 0),
		Rotation = UIStyle.Slant,
		ZIndex = 4,
	})
	return root
end

function Stage.getShot()
	return current
end

function Stage.show(screenName, instant)
	local shot = Stage.SHOTS[screenName] or Stage.SHOTS[Stage.DEFAULT]
	local opening = not root.Visible
	root.Visible = true
	ensureLoaded()
	current = screenName
	target = shot.pose
	motion = shot.motion
	if instant or opening then
		-- Start in the pose instead of unfolding from the rest pose.
		pose = table.clone(shot.pose)
	end
	if not connection and RunService:IsRunning() then
		connection = RunService.RenderStepped:Connect(Stage.update)
	end
	Stage.update(0)

	local goal = CFrame.lookAt(shot.from, shot.at)
	for _, view in ipairs(views) do
		if instant or opening then
			view.camera.CFrame = goal
			view.camera.FieldOfView = shot.fov
		else
			TweenService:Create(view.camera, Stage.MOVE, { CFrame = goal, FieldOfView = shot.fov }):Play()
		end
	end
	if instant then
		Components.paint(field, shot.field)
		Components.paint(stripe, shot.stripe)
		return
	end
	Components.tweenPaint(field, Stage.MOVE, shot.field)
	Components.tweenPaint(stripe, Stage.MOVE, shot.stripe)
	if opening then
		-- Everything slides in: the band from the left, the field and the silhouette from the right.
		Components.paint(field, shot.field)
		Components.paint(stripe, shot.stripe)
		band.Position = UDim2.fromScale(-0.3, 0.5)
		TweenService:Create(band, Stage.MOVE, { Position = UDim2.fromScale(0.16, 0.5) }):Play()
		for _, view in ipairs(views) do
			view.frame.Position = view.home + UDim2.fromOffset(260, 0)
			TweenService:Create(view.frame, Stage.MOVE, { Position = view.home }):Play()
		end
	else
		-- A small kick sideways sells the cut between screens.
		for _, view in ipairs(views) do
			view.frame.Position = view.home + UDim2.fromOffset(36, 0)
			TweenService:Create(view.frame, Stage.MOVE, { Position = view.home }):Play()
		end
	end
end

function Stage.hide()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if root then
		root.Visible = false
	end
	current = nil
end

return Stage
