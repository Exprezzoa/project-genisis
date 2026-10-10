--!nonstrict
-- Client/UI/CharacterStage.lua  (docs/14_ui.md §1.2)
--
-- The stage behind every menu screen: the dimmed game view, the diagonal amber band on the left, and on the
-- right a flat silhouette of the player's character in front of a color field. Each screen has its own shot
-- of the silhouette (full body, head, arm, ...) and its own colors; changing screens flies the camera from one
-- shot to the next and blends the colors.
--
-- No images: the silhouette is a clone of the character inside a ViewportFrame under pure ambient light (flat
-- colors, no shading): ink body, slate harness, amber piping and insignia. A second, offset viewport holds an
-- all-white clone tinted paper-white: its shadow.
--
--   build(parent) -> Frame      show(screenName, instant)      hide()      getShot() -> screenName?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = require(script.Parent.Components)

local Stage = {}

local V = Vector3.new
local function hex(value)
	return Color3.fromHex(value)
end

-- The silhouette stands at the origin facing -Z, feet at Y 0 (head about Y 5.2, hands about Y 2.2).
-- from/at: camera position and look-at; fov; field/stripe: the color field behind the silhouette and its
-- accent stripe (palette colors of docs/06 §3). Screens without an entry use DEFAULT.
Stage.SHOTS = {
	Pause = { from = V(-5.0, 3.6, -9.5), at = V(0.4, 2.8, 0), fov = 38, field = hex("#E8A33D"), stripe = hex("#E07A1F") },
	Settings = { from = V(-2.4, 5.2, -5.6), at = V(0.3, 4.3, 0), fov = 34, field = hex("#9FB4C4"), stripe = hex("#E8A33D") },
	MissionLog = { from = V(4.4, 3.7, -6.6), at = V(0.7, 2.9, 0), fov = 34, field = hex("#FFD38A"), stripe = hex("#E8A33D") },
	-- Equipment (Phase 6) will look at the forearm: from (-3.0, 2.6, -2.6), at (-1.5, 2.3, 0).
}
Stage.DEFAULT = "Pause"
Stage.MOVE = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local root, band, field, stripe
local views = {} -- { { frame = ViewportFrame, camera = Camera, home = UDim2 } }
local current = nil
local loaded = false

-- Flat colors of the toned silhouette, by gear part name (anything else, and the body, is ink).
local SLATE = hex("#3B4A5A")
local function toneFor(name)
	if string.find(name, "^Piping") or string.find(name, "^Rank") or name == "Harness_Buckle" or name == "Patch_Bar" then
		return UIStyle.Accent
	elseif string.find(name, "^Harness") or string.find(name, "^Patch") or name == "ChestTag" then
		return SLATE
	end
	return UIStyle.Ink
end

-- An unlit copy of the character: StarterCharacter (neutral pose) or, failing that, the live character.
-- toned = false: every part white (for the tinted shadow); true: the flat ink / slate / amber look.
local function makeSilhouette(toned)
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
			descendant.Color = if toned then toneFor(descendant.Name) else Color3.new(1, 1, 1)
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
		local model = makeSilhouette(view.toned)
		if not model then
			return -- no character yet; try again on the next show
		end
		model.Parent = view.frame
	end
	loaded = true
end

local function viewport(parent, name, tint, offset, zIndex, toned)
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
	table.insert(views, { frame = frame, camera = camera, home = frame.Position, toned = toned })
	return frame
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
	viewport(root, "SilhouetteShadow", UIStyle.Paper, Vector2.new(14, 10), 2, false)
	viewport(root, "Silhouette", Color3.new(1, 1, 1), Vector2.new(0, 0), 3, true)

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
	if root then
		root.Visible = false
	end
	current = nil
end

return Stage
