--!nonstrict
-- builders/maps/memory_set.lua  ->  ServerStorage.DevTools.Builders.MemorySet
-- docs/maps/map_00_world_layout.md §4: the anomaly vision (S33). A pale void at (0, 2000, 0): a 400 × 400 floor,
-- a line of 12 street lamps along X = -6, a faint line along X = 0, and two dark silhouettes, a man and a small
-- child, standing hand in hand at Z 40 facing -Z. The cinematic walks them (client) and dollies the camera.
--
--   Builder.Build({ BK = BK, Kit = CharacterKit })   -> Workspace.Map.MemorySet (rebuilt each time)

local Builder = {}

local V = Vector3.new
local Y0 = 2000 -- the floor's top
local FLOOR, LAMP, LINE, GLOW = "#EAF6F8", "#DDE9F2", "#CFEFF5", "#DFF8FB"
local SILHOUETTE = "#2A2D31"

-- A street lamp (docs/07 §6 StreetLamp 1 × 12 × 4) painted pale: pole, an arm reaching over the path (+X), the head.
local function lamp(BK, parent, index, z)
	local model = BK.model(parent, ("Lamp_%02d"):format(index))
	local base = V(-6, Y0, z)
	BK.cyl(model, { Name = "Pole", Axis = "Y", Size = V(0.5, 12, 0.5), Position = base + V(0, 6, 0), Color = LAMP, Material = "SmoothPlastic" })
	BK.part(model, { Name = "Arm", Size = V(3, 0.3, 0.3), Position = base + V(1.5, 11.8, 0), Color = LAMP, Material = "SmoothPlastic" })
	local head = BK.part(model, { Name = "Head", Size = V(1.4, 0.4, 1), Position = base + V(3.1, 11.6, 0), Color = LAMP, Material = "SmoothPlastic" })
	local bulb = BK.part(model, { Name = "Glow", Size = V(1.1, 0.06, 0.7), Position = base + V(3.1, 11.37, 0), Color = GLOW, Material = "Neon", CanCollide = false })
	BK.light(bulb, "Point", { Color = GLOW, Brightness = 1, Range = 16, Shadows = false })
	return head
end

local function silhouette(BK, Kit, parent, name, height, width, position)
	local model = Kit.build(BK, {
		name = name, height = height, width = width,
		colors = { skin = SILHOUETTE, torso = SILHOUETTE, arms = SILHOUETTE, legs = SILHOUETTE, hands = SILHOUETTE, feet = SILHOUETTE },
		gear = {},
	})
	local face = model:FindFirstChild("Head") and model.Head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy() -- no face (map_00 §4)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model.HumanoidRootPart.Anchored = true
	model:SetAttribute("Memory", name)
	model.Parent = parent
	model:PivotTo(CFrame.lookAt(position, position + V(0, 0, -1)) + V(0, humanoid.HipHeight + model.HumanoidRootPart.Size.Y / 2, 0))
	return model
end

function Builder.Build(opts)
	local BK, Kit = opts.BK, opts.Kit
	local startClock = os.clock()
	local map = BK.folder(workspace, "Map")
	local root = BK.folder(map, "MemorySet", true)
	BK.part(root, { Name = "Floor", Size = V(400, 1, 400), Position = V(0, Y0 - 0.5, 0), Color = FLOOR, Material = "SmoothPlastic" })
	BK.part(root, { Name = "GroundLine", Size = V(1, 0.05, 250), Position = V(0, Y0 + 0.025, -55), Color = LINE, Material = "SmoothPlastic", CanCollide = false })
	local lamps = BK.folder(root, "Lamps")
	for index = 1, 12 do
		lamp(BK, lamps, index, 60 - (index - 1) * 20)
	end
	local figures = BK.folder(root, "Figures")
	silhouette(BK, Kit, figures, "Memory_Man", 1.05, 1, V(0, Y0, 40))
	silhouette(BK, Kit, figures, "Memory_Child", 0.6, 0.85, V(-1.6, Y0, 40))
	return BK.report(root, startClock)
end

return Builder
