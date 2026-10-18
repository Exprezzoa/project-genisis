--!nonstrict
-- builders/maps/central_command/TrainingYard.lua  ->  DevTools.Builders.CentralCommand.TrainingYard
-- docs/maps/map_01_central_command.md §12 (X -420..-122, Z -300..-40), docs/07 §6 (Titan simulacrum, training
-- dummy), docs/10_titans.md §1.2 (hurtboxes of the Strider's standing state).
--
-- Passes (docs/07 §2): blockout = the concrete pad, lane lines, the FrameBarrier ring (open at the hangar's west
-- door), the Titan Simulacrum with its hurtboxes, four training dummies, the dismount pad PAD_TRAINING, a stand-in
-- for the observation booth, and SPAWN_TRAINING; structure = Jersey barriers along the edges, the pedestrian gate at
-- (-130, 0, -50) and the observation booth at (-405, 0, -60) (12 x 10 x 10, windows); dressed = floodlight masts
-- (lit at EVENING and NIGHT: the yard opens at night after CH1_COMPLETE, map_01 §14), concrete joints, scuffs, painted
-- floor text and the door threshold's hazard band, signs, the booth's console and chairs, the yard's kit (plate racks,
-- tool carts, crates, barrels, a power cabinet).
-- D-105: the barrier line closing the south-east corner runs at X -130 (the gate's X) from the hangar's south-west
-- corner to the south line, with a short stub along Z -72 to the hangar's west wall; the strip X -130..-122 east of it
-- stays outside the barriers. Nothing locks the gate (D-090: nothing in the hub locks the yard).
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new

local JERSEY = 6 -- a Jersey barrier is 6 long and 2 deep (docs/07 §6)
local GATE = { x = -130, z = -50, width = 5 } -- map_01 §12
local BOOTH = { x1 = -411, x2 = -399, z1 = -65, z2 = -55, height = 10 } -- 12 x 10 x 10 at (-405, 0, -60)
local YARD_LAMP_TAGS = { "EveningLamp" }

Builder.SIMULACRUM = V(-320, 0, -170) -- facing east
Builder.DUMMIES = { V(-260, 0, -250), V(-260, 0, -90), V(-380, 0, -250), V(-380, 0, -90) }

-- Strider main parts (docs/08 §3.2): { name, size, center }, model space (facing -Z, +X = its right).
local STRIDER = {
	{ "LowerTorso", V(12, 5, 7), V(0, 29.5, 0) },
	{ "UpperTorso", V(14, 14, 8), V(0, 39, 0) },
	{ "Head", V(7, 9, 7.5), V(0, 51.5, 0) },
	{ "LeftUpperArm", V(4, 14, 4), V(-9.5, 37, 0) },
	{ "RightUpperArm", V(4, 14, 4), V(9.5, 37, 0) },
	{ "LeftLowerArm", V(3.5, 14, 3.5), V(-9.5, 23, 0) },
	{ "RightLowerArm", V(3.5, 14, 3.5), V(9.5, 23, 0) },
	{ "LeftHand", V(4, 6, 2.5), V(-9.5, 13, 0) },
	{ "RightHand", V(4, 6, 2.5), V(9.5, 13, 0) },
	{ "LeftUpperLeg", V(5.5, 12, 5.5), V(-3.5, 21, 0) },
	{ "RightUpperLeg", V(5.5, 12, 5.5), V(3.5, 21, 0) },
	{ "LeftLowerLeg", V(4.5, 12, 4.5), V(-3.5, 9, 0) },
	{ "RightLowerLeg", V(4.5, 12, 4.5), V(3.5, 9, 0) },
	{ "LeftFoot", V(6, 3, 10), V(-3.5, 1.5, -2) },
	{ "RightFoot", V(6, 3, 10), V(3.5, 1.5, -2) },
}
local HRP_CENTER = V(0, 29.5, 0)
-- Standing hurtboxes (docs/10 §1.2): { zone, size, offset from the HRP center }.
local HURTBOXES = {
	{ "Body", V(14, 20, 8), V(0, 6, 0) },
	{ "Head", V(7, 9, 7.5), V(0, 22, 0) },
	{ "AnkleL", V(5.5, 7, 5.5), V(-3.5, -23, 0) },
	{ "AnkleR", V(5.5, 7, 5.5), V(3.5, -23, 0) },
	{ "ArmL", V(5, 28, 5), V(-9.5, -6.5, 0) },
	{ "ArmR", V(5, 28, 5), V(9.5, -6.5, 0) },
}

-- docs/07 §6 "Titan simulacrum": a static steel effigy with the Strider's main-part dimensions, ankle targets
-- in Neon amber, a core target on the back, and hurtboxes.
function Builder.simulacrum(BK, parent, cframe)
	local P = BK.Palette
	local model = BK.model(parent, "TitanSimulacrum")
	BK.attr(model, { TargetId = "SIMULACRUM", Simulacrum = true })
	local steel = { Color = P.STEEL_MID, Material = "Metal" }
	for _, spec in ipairs(STRIDER) do
		local props = table.clone(steel)
		props.Name, props.Size, props.CFrame = spec[1], spec[2], cframe * CFrame.new(spec[3])
		BK.part(model, props)
	end
	for _, sx in ipairs({ -1, 1 }) do
		BK.part(model, {
			Name = "AnkleTarget", Size = V(4.9, 1.2, 4.9), CFrame = cframe * CFrame.new(3.5 * sx, 6.5, 0), Color = P.AMBER,
			Material = "Neon", CanCollide = false, CanQuery = false,
		})
	end
	BK.cyl(model, {
		Name = "CoreTarget", Axis = "Z", Size = V(5, 5, 0.6), CFrame = cframe * CFrame.new(0, 41, 4.2), Color = P.AMBER,
		Material = "Neon", CanCollide = false, CanQuery = false,
	})
	local root = BK.part(model, {
		Name = "HumanoidRootPart", Size = V(10, 10, 6), CFrame = cframe * CFrame.new(HRP_CENTER), Transparency = 1,
		CanCollide = false, CanQuery = false, CastShadow = false,
	})
	model.PrimaryPart = root
	for _, spec in ipairs(HURTBOXES) do
		BK.part(model, {
			Name = "Hurtbox_" .. spec[1], Size = spec[2], CFrame = root.CFrame * CFrame.new(spec[3]), Transparency = 1,
			CanCollide = false, CanQuery = true, CanTouch = false, CastShadow = false, Tags = { "Hurtbox" },
			Attributes = { Zone = spec[1] },
		})
	end
	return model
end

-- docs/07 §6 "Training dummy (Frame-scale)", 14 x 36 x 10: plates on a spine, two arm stubs, a target disc.
function Builder.dummy(BK, parent, name, cframe)
	local P = BK.Palette
	local model = BK.model(parent, name)
	BK.part(model, { Name = "Spine", Size = V(3, 36, 3), CFrame = cframe * CFrame.new(0, 18, 0), Color = P.STEEL_DARK, Material = "Metal" })
	BK.part(model, { Name = "Base", Size = V(14, 2, 10), CFrame = cframe * CFrame.new(0, 1, 0), Color = P.STEEL_DARK, Material = "Metal" })
	BK.part(model, { Name = "Torso", Size = V(12, 14, 6), CFrame = cframe * CFrame.new(0, 22, 0), Color = P.VG_PRIMER, Material = "Metal" })
	BK.part(model, { Name = "Hips", Size = V(9, 8, 5), CFrame = cframe * CFrame.new(0, 10, 0), Color = P.STEEL_MID, Material = "Metal" })
	BK.part(model, { Name = "Head", Size = V(5, 5, 5), CFrame = cframe * CFrame.new(0, 33.5, 0), Color = P.STEEL_MID, Material = "Metal" })
	for _, sx in ipairs({ -1, 1 }) do
		BK.part(model, { Name = "ArmStub", Size = V(2, 4, 4), CFrame = cframe * CFrame.new(7 * sx, 26, 0), Color = P.STEEL_MID, Material = "Metal" })
	end
	BK.cyl(model, {
		Name = "TargetDisc", Axis = "Z", Size = V(6, 6, 0.3), CFrame = cframe * CFrame.new(0, 22, -3.1), Color = P.HAZARD_YELLOW,
		CanCollide = false,
	})
	return model
end

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "TrainingYard")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("TrainingYard: the structure and dressed passes need opts.Props", 2)
	end

	-- The pad: top at Y 0, in two plates (parts stay under 512 studs).
	local concrete = { Color = P.CONCRETE_DARK, Material = "Concrete" }
	BK.box(S, "Pad_W", V(-420, -1, -300), V(-271, 0, -40), concrete)
	BK.box(S, "Pad_E", V(-271, -1, -300), V(-122, 0, -40), concrete)

	-- Painted lanes: the Frame lane from the west door to the simulacrum, and a ring around the target.
	local paint = { Color = P.HAZARD_YELLOW, CanCollide = false, CanQuery = false, CastShadow = false }
	for _, z in ipairs({ -135, -85 }) do
		BK.box(S, "LaneLine", V(-250, 0, z - 0.5), V(-122, 0.05, z + 0.5), paint)
	end
	local center = Builder.SIMULACRUM
	for index = 0, 23 do
		local angle = math.rad(index * 15)
		local segment = table.clone(paint)
		segment.Name = "RingSegment"
		segment.Size = V(1, 0.05, 12)
		segment.CFrame = CFrame.new(center + V(math.cos(angle) * 60, 0.025, math.sin(angle) * 60)) * CFrame.Angles(0, -angle, 0)
		BK.part(S, segment)
	end

	-- Frames can't leave the yard, except through the hangar's west door (Z -140..-80).
	BK.barrier(G, "FrameBarrier_W", V(-421, 0, -300), V(-420, 40, -40), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_N", V(-421, 0, -301), V(-122, 40, -300), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_S", V(-421, 0, -40), V(-122, 40, -39), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_E1", V(-123, 0, -300), V(-122, 40, -140), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_E2", V(-123, 0, -80), V(-122, 40, -40), "FrameBarrier")

	Builder.simulacrum(BK, G, BK.lookAlong(center, V(1, 0, 0)))
	for index, position in ipairs(Builder.DUMMIES) do
		Builder.dummy(BK, G, "TrainingDummy" .. index, BK.lookAlong(position, V(1, 0, 0)))
		-- A Frame's root floats 22 studs up, so it would walk onto a 36-stud dummy instead of into it (seen in
		-- play, D-049): every dummy gets a FrameBarrier box.
		BK.barrier(G, "FrameBarrier_Dummy" .. index, position + V(-6, 0, -10), position + V(6, 40, 10), "FrameBarrier")
	end

	BK.dismountPad(G, "PAD_TRAINING", V(-200, 0, -110), 22, BK.lookAlong(V(-174, 0, -110), V(1, 0, 0)))
	if ctx.level < 2 then
		C.standIn(ctx, "ObservationBooth", V(BOOTH.x1, 0, BOOTH.z1), V(BOOTH.x2, BOOTH.height, BOOTH.z2))
	end

	if ctx.level >= 2 then
		Builder.boundary(ctx, C, Lib)
		Builder.gate(ctx, C, Lib)
		Builder.booth(ctx, C, Lib)
	end
	if ctx.level >= 3 then
		Builder.floodlights(ctx, C, Lib)
		Builder.groundDetail(ctx, C, Lib)
		Builder.dressBooth(ctx, C, Lib)
		Builder.kit(ctx, C, Lib)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

---------------------------------------------------------------------------------------------------
-- Structure
---------------------------------------------------------------------------------------------------

-- Jersey barriers end to end along `axis` ("X" or "Z") at `fixed`, from `a` to `b` (a < b), their fronts toward
-- `face` (the yard). The run is split evenly, so the joints stay under a stud wide.
local function jerseyRun(ctx, Lib, name, axis, fixed, a, b, face)
	local n = math.floor((b - a) / JERSEY)
	if n < 1 then
		return 0
	end
	local step = (b - a) / n
	for i = 0, n - 1 do
		local s = a + step * (i + 0.5)
		local p = if axis == "X" then V(s, 0, fixed) else V(fixed, 0, s)
		Lib.JerseyBarrier(ctx.Props, CFrame.new(p) * Lib.FACE[face], { name = name })
	end
	return n
end

-- Jersey barriers along every open edge (map_01 §12): west, north and south lines 1 inside the pad's edge, the
-- east side north of the hangar, and the south-east corner closed at the gate's X (D-105). The hangar's west wall is
-- the boundary along Z -230..-70 (the training door's opening is the Frames' way in).
function Builder.boundary(ctx, C, Lib)
	jerseyRun(ctx, Lib, "Jersey_W", "Z", -418, -297, -43, "+X")
	jerseyRun(ctx, Lib, "Jersey_N", "X", -298, -417, -125, "+Z")
	jerseyRun(ctx, Lib, "Jersey_S", "X", -42, -417, -129, "-Z")
	jerseyRun(ctx, Lib, "Jersey_E", "Z", -124, -297, -232, "-X")
	-- The south-east corner: a stub from the hangar's west wall (outer face X -121.5) to the gate line, then the gate
	-- line from the stub to the gate's north post.
	jerseyRun(ctx, Lib, "Jersey_SE", "X", -72, -129, -122, "-Z")
	jerseyRun(ctx, Lib, "Jersey_Gate", "Z", GATE.x, -71, GATE.z - GATE.width / 2 - 0.6, "-X")
end

-- The pedestrian gate at (-130, 0, -50): two steel posts with a header and a sign on both faces, a mesh leaf swung
-- open into the yard, and a concrete pier from the south post to the south line. Opening 5 wide, 8 high (map_01 §2).
function Builder.gate(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	local m = BK.model(S, "PedestrianGate")
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	local half = GATE.width / 2
	local zN, zS = GATE.z - half, GATE.z + half -- the opening's north and south edges
	BK.box(m, "Post_N", V(GATE.x - 0.3, 0, zN - 0.6), V(GATE.x + 0.3, 9, zN), steel)
	BK.box(m, "Post_S", V(GATE.x - 0.3, 0, zS), V(GATE.x + 0.3, 9, zS + 0.6), steel)
	BK.box(m, "Header", V(GATE.x - 0.35, 8, zN - 0.6), V(GATE.x + 0.35, 9, zS + 0.6), steel)
	BK.box(m, "Pier_S", V(GATE.x - 1, 0, zS + 0.6), V(GATE.x + 1, 3, -43), { Color = P.CONCRETE_LIGHT, Material = "Concrete" })
	BK.box(D, "Pier_S_Band", V(GATE.x - 1.01, 2.4, zS + 0.6), V(GATE.x + 1.01, 2.8, -43), { Color = P.HAZARD_YELLOW, Tags = { "Detail" } })
	for _, dir in ipairs({ -1, 1 }) do
		BK.sign(D, "GateSign", BK.lookAlong(V(GATE.x + dir * 0.4, 9.7, GATE.z), V(dir, 0, 0)), Vector2.new(6.2, 1.2), "TRAINING YARD — PILOTS ONLY", { light = true })
	end
	BK.box(m, "SignBracket", V(GATE.x - 0.15, 9, GATE.z - 3.1), V(GATE.x + 0.15, 10.3, GATE.z + 3.1), steel)
	-- The leaf, hinged on the north post and swung 90° into the yard (toward -X), along the north post's line.
	local leaf = BK.model(m, "Leaf")
	local frame = { Color = P.STEEL_MID, Material = "Metal", CanCollide = false }
	local mesh = { Color = P.STEEL_LIGHT, Material = "SmoothPlastic", Transparency = 0.7, CanCollide = false, CanQuery = false, CastShadow = false }
	local x1, x2 = GATE.x - 0.3 - GATE.width + 0.2, GATE.x - 0.3
	local z = zN - 0.3
	BK.box(leaf, "Frame_Top", V(x1, 7.4, z - 0.1), V(x2, 7.6, z + 0.1), frame)
	BK.box(leaf, "Frame_Bottom", V(x1, 0.3, z - 0.1), V(x2, 0.5, z + 0.1), frame)
	BK.box(leaf, "Frame_Free", V(x1, 0.3, z - 0.1), V(x1 + 0.2, 7.6, z + 0.1), frame)
	BK.box(leaf, "Mesh", V(x1 + 0.2, 0.5, z - 0.02), V(x2, 7.4, z + 0.02), mesh)
	-- A painted walkway from the gate toward the booth and the yard.
	BK.floorText(D, "Floor_Pedestrians", V(GATE.x - 6, 0, GATE.z), Vector2.new(9, 1.6), "PEDESTRIANS", { textUp = V(-1, 0, 0) })
end

-- The observation booth (12 x 10 x 10, map_01 §12): plinth, steel corners, low concrete walls with a window band on
-- the yard's sides (north and east), a door on the east side toward the gate, an overhanging roof with an amber trim.
function Builder.booth(ctx, C, Lib)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local b = BK.model(S, "ObservationBooth")
	local x1, x2, z1, z2 = BOOTH.x1, BOOTH.x2, BOOTH.z1, BOOTH.z2
	local wall = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	local glass = { Color = P.GLASS, Material = "Glass", Transparency = 0.55, CastShadow = false }
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	local plinth = BK.box(b, "Plinth", V(x1 - 0.5, 0, z1 - 0.5), V(x2 + 0.5, 0.5, z2 + 0.5), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	BK.box(b, "Floor", V(x1, 0.5, z1), V(x2, 0.6, z2), { Color = P.FLOOR_INTERIOR })
	for _, c in ipairs({ { x1, z1 }, { x2, z1 }, { x1, z2 }, { x2, z2 } }) do
		BK.box(b, "Corner", V(c[1] - 0.4, 0.5, c[2] - 0.4), V(c[1] + 0.4, 9.3, c[2] + 0.4), steel)
	end
	-- side(name, from, to, axis of the wall's run, fixed coordinate, windows?)
	local function side(name, a, bb, runAxis, fixed, windows)
		local function box(n, y1, y2, props, t)
			t = t or 0.3
			if runAxis == "X" then
				BK.box(b, name .. n, V(a, y1, fixed - t), V(bb, y2, fixed + t), props)
			else
				BK.box(b, name .. n, V(fixed - t, y1, a), V(fixed + t, y2, bb), props)
			end
		end
		if windows then
			box("_Low", 0.6, 3.6, wall)
			box("_Glass", 3.6, 7.2, glass, 0.08)
			box("_Head", 7.2, 9.3, wall)
		else
			box("_Wall", 0.6, 9.3, wall)
		end
	end
	side("N", x1 + 0.4, x2 - 0.4, "X", z1, true)
	side("W", z1 + 0.4, z2 - 0.4, "Z", x1, false)
	side("S", x1 + 0.4, x2 - 0.4, "X", z2, false)
	-- East: a window from the north corner to Z -59.6, then the closed door (about 4 wide, 7 high; the booth is decor,
	-- map_01 §12) to the south corner.
	local dz = -59.6
	BK.box(b, "E_Low", V(x2 - 0.3, 0.6, z1 + 0.4), V(x2 + 0.3, 3.6, dz), wall)
	BK.box(b, "E_Glass", V(x2 - 0.08, 3.6, z1 + 0.4), V(x2 + 0.08, 7.2, dz), glass)
	BK.box(b, "E_Jamb", V(x2 - 0.3, 0.6, dz), V(x2 + 0.3, 7.6, dz + 0.3), steel)
	BK.box(b, "E_Door", V(x2 - 0.15, 0.6, dz + 0.3), V(x2 + 0.15, 7.6, z2 - 0.4), { Color = P.STEEL_MID, Material = "Metal" })
	BK.box(b, "E_Head", V(x2 - 0.3, 7.6, z1 + 0.4), V(x2 + 0.3, 9.3, z2 - 0.4), wall)
	BK.box(b, "Roof", V(x1 - 1, 9.3, z1 - 1), V(x2 + 1, 10, z2 + 1), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	BK.box(b, "RoofTrim", V(x1 - 1.05, 9.3, z1 - 1.05), V(x2 + 1.05, 9.5, z2 + 1.05), { Color = P.AMBER, CanCollide = false, CanQuery = false, CastShadow = false })
	BK.sign(ctx.Detail, "Booth_Sign", BK.lookAlong(V(x2 + 0.45, 8.45, -60), V(1, 0, 0)), Vector2.new(7, 1), "OBSERVATION — RANGE CONTROL", { light = true })
	b.PrimaryPart = plinth
	-- Frames don't walk onto it.
	BK.barrier(ctx.Gameplay, "FrameBarrier_Booth", V(x1 - 1.5, 0, z1 - 1.5), V(x2 + 1.5, 40, z2 + 1.5), "FrameBarrier")
end

---------------------------------------------------------------------------------------------------
-- Dressed
---------------------------------------------------------------------------------------------------

-- Six floodlight masts (40 tall, one light each for the light budget) around the simulacrum's ring and over the
-- Frame lane, each aimed 25-40 studs out so its pool lands on the yard (a light reaches at most 60). Lit at EVENING
-- and NIGHT like the street lamps (AmbientController, tag EveningLamp); their faces go dark by day. Each gets a
-- FrameBarrier box, like the dummies (D-049).
Builder.MASTS = {
	{ V(-320, 0, -246), V(-320, 0, -205) },
	{ V(-320, 0, -94), V(-320, 0, -135) },
	{ V(-396, 0, -170), V(-355, 0, -170) },
	{ V(-244, 0, -170), V(-285, 0, -170) },
	{ V(-200, 0, -150), V(-185, 0, -112) },
	{ V(-170, 0, -270), V(-190, 0, -235) },
}

function Builder.floodlights(ctx, C, Lib)
	local BK, P, G = ctx.BK, ctx.P, ctx.Gameplay
	for i, m in ipairs(Builder.MASTS) do
		local at, aim = m[1], m[2]
		local facing = Vector3.new(aim.X - at.X, 0, aim.Z - at.Z).Unit
		local mast = Lib.FloodlightMast(ctx.Lighting, BK.lookAlong(at, facing), { name = "Mast" .. i, height = 40, aim = aim, single = true, lightTags = YARD_LAMP_TAGS })
		for _, d in ipairs(mast:GetDescendants()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 8) == "LampFace" then
				BK.attr(d, { OnColor = P.LIGHT_COOL, OffColor = P.STEEL_MID })
			end
		end
		BK.barrier(G, "FrameBarrier_Mast" .. i, at + V(-2.5, 0, -2.5), at + V(2.5, 40, 2.5), "FrameBarrier")
	end
end

-- Ground detail: expansion joints every 24, scuffs where Frames turn and fight, painted floor text, and the hazard
-- band across the training door's threshold. (No sign on the hangar's wall: it belongs to the hangar's shell and
-- lies outside this area's bounds; the gate carries the yard's sign.)
function Builder.groundDetail(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	local joint = BK.darken(BK.toColor(P.CONCRETE_DARK), 0.12)
	for _, name in ipairs({ "Pad_W", "Pad_E" }) do
		local pad = S:FindFirstChild(name)
		if pad then
			BK.seams(pad, Enum.NormalId.Top, 24, { width = 0.25, color = joint, parent = D, name = name .. "_Joints" })
		end
	end
	-- Scuffs: dark, flat, seeded; around the simulacrum's ring and along the lane.
	local rng = BK.rng(1205)
	local scuff = BK.darken(BK.toColor(P.CONCRETE_DARK), 0.22)
	local center = Builder.SIMULACRUM
	for i = 1, 14 do
		local angle = rng.next(0, math.pi * 2)
		local r = rng.next(30, 70)
		local p = center + V(math.cos(angle) * r, 0, math.sin(angle) * r)
		BK.part(D, { Name = "Scuff", Size = V(rng.next(6, 14), 0.04, rng.next(3, 6)), CFrame = CFrame.new(p.X, 0.02, p.Z) * CFrame.Angles(0, rng.next(0, math.pi), 0), Color = scuff, Material = "Concrete", Transparency = 0.35, Tags = { "Detail" } })
	end
	for i = 1, 6 do
		local x = rng.next(-240, -140)
		local z = rng.next(-128, -92)
		BK.part(D, { Name = "LaneScuff", Size = V(rng.next(8, 16), 0.04, rng.next(2.5, 4.5)), CFrame = CFrame.new(x, 0.02, z) * CFrame.Angles(0, rng.next(-0.25, 0.25), 0), Color = scuff, Material = "Concrete", Transparency = 0.35, Tags = { "Detail" } })
	end
	-- Floor text, read by a Frame walking in from the door (toward -X), and at the ring.
	BK.floorText(D, "Floor_FrameLane", V(-150, 0, -110), Vector2.new(30, 5), "FRAME LANE", { textUp = V(-1, 0, 0) })
	BK.floorText(D, "Floor_LiveTarget", V(-246, 0, -170), Vector2.new(20, 4), "LIVE TARGET", { textUp = V(-1, 0, 0) })
	for i, p in ipairs(Builder.DUMMIES) do
		BK.floorText(D, "Floor_Dummy" .. i, p + V(12, 0, 0), Vector2.new(8, 3), "D-" .. i, { textUp = V(-1, 0, 0) })
	end
	-- The training door's threshold: a hazard band across the opening (Z -140..-80), just inside the pad's edge.
	BK.hazardStripe(D, "Hazard_TrainingDoor", CFrame.new(-125, 0.03, -110) * CFrame.Angles(0, math.pi / 2, 0), 60, 3, { stripe = 2.5 })
end

-- Inside the booth (fronts toward the seated operators, who look north out of the window): a console and a desk
-- with a terminal under the north window, two chairs, a ceiling lamp; a
-- bench and a flag outside the door; the power cabinet that feeds the yard on the booth's west side.
function Builder.dressBooth(ctx, C, Lib)
	local BK, P, F = ctx.BK, ctx.P, ctx.Props
	local b = ctx.Structure:FindFirstChild("ObservationBooth")
	local parent = b or F
	Lib.Console(parent, CFrame.new(-407.5, 0.6, -63.2) * Lib.FACE["+Z"], { name = "RangeConsole", lines = { "RANGE CONTROL", "SIMULACRUM: ARMED", "DUMMIES 4/4" }, seed = 12 })
	Lib.Desk(parent, CFrame.new(-402.5, 0.6, -63.4) * Lib.FACE["+Z"], { name = "Desk" })
	Lib.Terminal(parent, CFrame.new(-402.5, 3.4, -63.8) * Lib.FACE["+Z"], { name = "Terminal", lines = { "TRAINING LOG", "Last run: Ember-2", "Sim hits 0/0" } })
	Lib.Chair(parent, CFrame.new(-407.5, 0.6, -61.2) * Lib.FACE["-Z"], { name = "Chair1" })
	Lib.Chair(parent, CFrame.new(-402.5, 0.6, -61.6) * Lib.FACE["-Z"], { name = "Chair2" })
	local lamp = BK.box(parent, "CeilingLamp", V(-406, 9.15, -61), V(-404, 9.25, -59), { Color = P.LIGHT_NEUTRAL, Material = "Neon", CanCollide = false, CanQuery = false, CastShadow = false })
	BK.light(lamp, "Surface", { Color = P.LIGHT_NEUTRAL, Brightness = 1, Range = 12, Face = Enum.NormalId.Bottom, Tags = { "HubLight" } })
	Lib.Bench(F, CFrame.new(-397.2, 0, -63) * Lib.FACE["+X"], { name = "Bench_Booth" })
	Lib.Flag(F, CFrame.new(-396.5, 0, -53.5) * Lib.FACE["+X"], { name = "Flag_Booth" })
	Lib.PowerCabinet(F, CFrame.new(-414.5, 0, -60) * Lib.FACE["+X"], { name = "PowerCabinet_Yard" })
	Lib.CableRun(F, V(-413, 0, -57.5), V(-411.6, 0, -57.5), { name = "Cable_Booth" })
end

-- The yard's kit along the north line: armor plates for the dummies, tool carts, crates and barrels, kept clear of the
-- Frame paths (the ring is 60 round the simulacrum; the dummies stand 60 east and west of it).
function Builder.kit(ctx, C, Lib)
	local F = ctx.Props
	Lib.PlateRack(F, CFrame.new(-360, 0, -292) * Lib.FACE["+Z"], { name = "PlateRack1" })
	Lib.PlateRack(F, CFrame.new(-348, 0, -292) * Lib.FACE["+Z"], { name = "PlateRack2" })
	Lib.ToolCart(F, CFrame.new(-372, 0, -268) * Lib.FACE["+X"], { name = "ToolCart_DummyNW" })
	Lib.ToolCart(F, CFrame.new(-272, 0, -76) * Lib.FACE["-X"], { name = "ToolCart_DummySE" })
	Lib.CrateStack(F, CFrame.new(-404, 0, -293) * Lib.FACE["+Z"], { name = "Crates_NW", seed = 51, count = 5 })
	Lib.CrateStack(F, CFrame.new(-150, 0, -293) * Lib.FACE["+Z"], { name = "Crates_NE", seed = 52, count = 4 })
	for i, p in ipairs({ V(-392, 0, -294), V(-389, 0, -293.2), V(-390.5, 0, -290.6), V(-140, 0, -290) }) do
		Lib.Barrel(F, CFrame.new(p), { name = "Barrel" .. i, rust = i % 2 == 0 })
	end
	-- Frames in the yard keep off the kit: one FrameBarrier box per group.
	local BK, G = ctx.BK, ctx.Gameplay
	BK.barrier(G, "FrameBarrier_KitNW", V(-410, 0, -297), V(-342, 40, -286), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_KitNE", V(-158, 0, -297), V(-136, 40, -286), "FrameBarrier")
end

return Builder
