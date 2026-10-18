--!nonstrict
-- builders/maps/central_command/Exterior.lua  ->  DevTools.Builders.CentralCommand.Exterior
-- docs/maps/map_01_central_command.md §13.1: the hub's grounds inside the perimeter X -420..420, Z -320..420.
--
-- Passes (docs/07 §2): blockout = the pavement ground and the PlayerBarrier along the perimeter; structure = the
-- asphalt roads (the main road north from the south gate to Z 166, then west to the motor pool), the chain-link
-- perimeter fence, the main gate with its gantry sign and guard booth, the flag plaza, the motor pool's apron and
-- canopy, the level crossing; dressed = street lamps every 40 (lit at EVENING and NIGHT: tag EveningLamp), the three
-- flagpoles, the trucks, the APC and the fuel tank, road paint, signs, booms and clutter.
-- D-103: where the doc's layout meets the rail line (Z 132..148, Arrival) and the Bulwark (X 420..450): the motor pool
-- keeps X -260..-160 but stops at the line (Z 60..130) and the road reaches it over a level crossing at X -225..-195;
-- the road's west leg runs Z 166..196, south of the flag plaza (flagpoles at Z 160); no fence on the east side, where
-- the Bulwark's face is the perimeter; the west fence opens for the rail line.
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new

local ROAD_TOP = 0
local OLIVE_LAMP_TAGS = { "EveningLamp", "HubLight" }

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Exterior")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("Exterior: the structure and dressed passes need opts.Props", 2)
	end

	-- Four ground plates (parts stay under 512 studs where possible; docs/07 §5), top at Common.GROUND_Y.
	local pavement = { Color = "#7C8086", Material = "Pavement" }
	local top = C.GROUND_Y
	for ix, xs in ipairs({ { -420, 0 }, { 0, 420 } }) do
		for iz, zs in ipairs({ { -320, 50 }, { 50, 420 } }) do
			BK.box(S, ("Ground_%d_%d"):format(ix, iz), V(xs[1], top - 4, zs[1]), V(xs[2], top, zs[2]), pavement)
		end
	end

	-- Players can't leave the hub (invisible walls on the perimeter line, 60 tall).
	BK.barrier(G, "Perimeter_W", V(-421, top, -320), V(-420, 60, 420), "PlayerBarrier")
	BK.barrier(G, "Perimeter_E", V(420, top, -320), V(421, 60, 420), "PlayerBarrier")
	BK.barrier(G, "Perimeter_N", V(-421, top, -321), V(421, 60, -320), "PlayerBarrier")
	BK.barrier(G, "Perimeter_S", V(-421, top, 420), V(421, 60, 421), "PlayerBarrier")

	if ctx.level >= 2 then
		Builder.roads(ctx, C)
		Builder.fence(ctx, C)
		Builder.gate(ctx, C, Lib)
		Builder.plaza(ctx, C, Lib)
		Builder.motorPool(ctx, C, Lib)
	end
	if ctx.level >= 3 then
		Builder.lamps(ctx, C, Lib)
		Builder.dressMotorPool(ctx, C, Lib)
		Builder.flags(ctx, C, Lib)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

---------------------------------------------------------------------------------------------------
-- Structure
---------------------------------------------------------------------------------------------------

function Builder.roads(ctx, C)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	local asphalt = { Color = P.ASPHALT, Material = "Asphalt" }
	local paint = { Color = P.ROAD_LINE, CanCollide = false, CanQuery = false, CastShadow = false }
	-- The apron outside the gate (the hub's ground ends at Z 420; the city backdrop begins at 440).
	BK.box(S, "Ground_GateApron", V(-56, C.GROUND_Y - 4, 420), V(56, C.GROUND_Y, 440), { Color = "#7C8086", Material = "Pavement" })
	BK.box(S, "Road_North", V(-15, ROAD_TOP - 0.3, 166), V(15, ROAD_TOP, 436), asphalt)
	BK.box(S, "Road_West", V(-225, ROAD_TOP - 0.3, 166), V(-15, ROAD_TOP, 196), asphalt)
	BK.box(S, "Road_Spur", V(-225, ROAD_TOP - 0.3, 152), V(-195, ROAD_TOP, 166), asphalt)
	-- Center dashes (8 long every 16), edge lines, a stop line at the junction.
	for z = 204, 428, 16 do
		BK.box(D, "Dash_N", V(-0.25, ROAD_TOP, z), V(0.25, ROAD_TOP + 0.04, z + 8), paint)
	end
	for x = -213, -27, 16 do
		BK.box(D, "Dash_W", V(x, ROAD_TOP, 180.75), V(x + 8, ROAD_TOP + 0.04, 181.25), paint)
	end
	for i, e in ipairs({ { V(-14, ROAD_TOP, 196), V(-13.5, ROAD_TOP, 436) }, { V(13.5, ROAD_TOP, 166), V(14, ROAD_TOP, 436) }, { V(-195, ROAD_TOP, 166.5), V(-15, ROAD_TOP, 167) }, { V(-225, ROAD_TOP, 195), V(-14, ROAD_TOP, 195.5) } }) do
		BK.box(D, "EdgeLine" .. i, e[1], e[2] + V(0, 0.04, 0), paint)
	end
	BK.box(D, "StopLine", V(0.5, ROAD_TOP, 198), V(13.5, ROAD_TOP + 0.04, 198.8), paint)
	BK.floorText(D, "Road_Checkpoint", V(7.5, ROAD_TOP, 398), Vector2.new(12, 2.4), "STOP — CHECKPOINT", { textColor = P.ROAD_LINE, textTransparency = 0.2 })
	BK.hazardStripe(D, "SpeedBump", CFrame.new(0, ROAD_TOP, 404), 30, 1.2)

	-- The level crossing (X -225..-195): a concrete deck over the ballast level with the rails' heads, ramps either side.
	local concrete = { Color = P.CONCRETE_MID, Material = "Concrete" }
	BK.box(S, "Crossing_Deck", V(-225, 0.4, 133), V(-195, 1.25, 147), concrete)
	local north = table.clone(concrete)
	north.Name, north.Size, north.CFrame = "Crossing_RampN", V(30, 1.25, 5), CFrame.new(-210, 0.625, 130.5)
	BK.wedge(S, north)
	local south = table.clone(north)
	south.Name, south.CFrame = "Crossing_RampS", CFrame.new(-210, 0.625, 149.5) * CFrame.Angles(0, math.pi, 0)
	BK.wedge(S, south)
end

-- A chain-link fence run (posts every 8, a top rail and two mid rails, STEEL_MID, a see-through mesh) along `axis`
-- ("X" or "Z") at `fixed`, from `a` to `b`, leaving `gaps` ({ { from, to } }) open. Nothing collides: the perimeter's
-- PlayerBarrier is the wall.
local function fenceRun(ctx, C, name, axis, fixed, a, b, gaps)
	local BK, P = ctx.BK, ctx.P
	local model = BK.model(ctx.Structure, name)
	local function at(s, y)
		return if axis == "X" then V(s, y, fixed) else V(fixed, y, s)
	end
	local spans = {}
	for _, r in ipairs(C.cover(a, b, 0, 1, (function()
		local list = {}
		for _, g in ipairs(gaps or {}) do
			table.insert(list, { g[1], g[2], 0, 1 })
		end
		return list
	end)())) do
		table.insert(spans, { r[1], r[2] })
	end
	local post = { Color = P.STEEL_MID, Material = "Metal", CanCollide = false }
	local rail = { Color = P.STEEL_MID, Material = "Metal", CanCollide = false, CanQuery = false, CastShadow = false }
	local mesh = { Color = P.STEEL_LIGHT, Material = "SmoothPlastic", Transparency = 0.7, CanCollide = false, CanQuery = false, CastShadow = false }
	for _, span in ipairs(spans) do
		local s1, s2 = span[1], span[2]
		local n = math.max(1, math.ceil((s2 - s1) / 8 - 1e-6))
		for i = 0, n do
			local s = s1 + (s2 - s1) * i / n
			local p = at(s, 4.1)
			BK.part(model, { Name = "Post", Size = V(0.35, 8.2, 0.35), CFrame = CFrame.new(p), Color = post.Color, Material = post.Material, CanCollide = false })
		end
		-- Rails and mesh in pieces of at most 400.
		local pieces = math.max(1, math.ceil((s2 - s1) / 400))
		for k = 1, pieces do
			local p1 = s1 + (s2 - s1) * (k - 1) / pieces
			local p2 = s1 + (s2 - s1) * k / pieces
			for _, y in ipairs({ 8.0, 5.2, 2.4 }) do
				BK.beam(model, "Rail", at(p1, y), at(p2, y), 0.14, 0.14, rail)
			end
			BK.beam(model, "Mesh", at(p1, 4.15), at(p2, 4.15), 0.04, 7.9, mesh)
		end
	end
	return model
end

function Builder.fence(ctx, C)
	fenceRun(ctx, C, "Fence_N", "X", -320, -420, 420)
	fenceRun(ctx, C, "Fence_S", "X", 420, -420, 420, { { -19.6, 19.6 } })
	fenceRun(ctx, C, "Fence_W", "Z", -420, -320, 420, { { 127, 153 } })
end

-- The main gate at (0, 0, 420): two concrete pillars and a gantry with the sign on both faces, the sliding gate
-- standing open outside the fence, two red-and-white booms across the lanes inside, and the guard booth.
function Builder.gate(ctx, C, Lib)
	local BK, P, S, F, D = ctx.BK, ctx.P, ctx.Structure, ctx.Props, ctx.Detail
	local concrete = { Color = P.CONCRETE_MID, Material = "Concrete" }
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	for i, x in ipairs({ -18, 18 }) do
		BK.box(S, "GatePillar" .. i, V(x - 1.6, 0, 418.4), V(x + 1.6, 16, 421.6), concrete)
		BK.box(D, "GatePillar_Cap" .. i, V(x - 1.9, 16, 418.1), V(x + 1.9, 16.6, 421.9), { Color = P.CONCRETE_DARK, Material = "Concrete", Tags = { "Detail" } })
		BK.box(D, "GatePillar_Band" .. i, V(x - 1.65, 2.6, 418.35), V(x + 1.65, 3.4, 421.65), { Color = P.HAZARD_YELLOW, Tags = { "Detail" } })
	end
	BK.box(S, "GateGantry", V(-16.4, 13, 419.2), V(16.4, 16, 420.8), steel)
	for _, dir in ipairs({ -1, 1 }) do
		BK.sign(D, "GateSign", BK.lookAlong(V(0, 14.5, 420 + dir * 0.86), V(0, 0, dir)), Vector2.new(31, 2.4), "HALDEN CENTRAL COMMAND — THIRD FRONTIER FRAME DIVISION", { light = true })
	end
	-- The sliding gate, rolled open along the outside of the fence west of the gate.
	local leaf = BK.model(F, "SlidingGate")
	BK.box(leaf, "Frame_T", V(-50, 7.6, 421.7), V(-19.8, 8, 422.1), steel)
	BK.box(leaf, "Frame_B", V(-50, 0.4, 421.7), V(-19.8, 0.8, 422.1), steel)
	for x = -50, -20, 6 do
		BK.box(leaf, "Bar", V(x, 0.8, 421.75), V(x + 0.3, 7.6, 422.05), steel)
	end
	BK.box(leaf, "Mesh", V(-50, 0.8, 421.88), V(-19.8, 7.6, 421.92), { Color = P.STEEL_LIGHT, Transparency = 0.8, CanCollide = false, CanQuery = false, CastShadow = false })
	for x = -48, -22, 13 do
		BK.cyl(leaf, { Name = "Wheel", Axis = "Z", Size = V(0.8, 0.8, 0.3), CFrame = CFrame.new(x, 0.4, 421.9), Color = P.HAZARD_BLACK, CanCollide = false })
	end

	-- Booms across both lanes, lowered, inside the gate at Z 412 (decorative: nothing collides).
	for i, s in ipairs({ { 16.6, -1 }, { -16.6, 1 } }) do
		local x, dir = s[1], s[2]
		local m = BK.model(F, "Boom" .. i)
		BK.box(m, "Post", V(x - 0.7, 0, 411.3), V(x + 0.7, 3.6, 412.7), { Color = P.HAZARD_YELLOW, Material = "Metal" })
		BK.box(m, "Lamp", V(x - 0.25, 3.6, 411.75), V(x + 0.25, 4.0, 412.25), { Color = P.DANGER_RED, Material = "Neon", CanCollide = false, CanQuery = false, CastShadow = false })
		local x2 = x + dir * 15
		BK.box(m, "Arm", V(math.min(x, x2), 2.9, 411.85), V(math.max(x, x2), 3.3, 412.15), { Color = P.MEDICAL_WHITE, CanCollide = false, CanQuery = false })
		for k = 1, 3 do
			local bx = x + dir * (k * 4)
			BK.box(m, "Band", V(bx - 0.8, 2.88, 411.83), V(bx + 0.8, 3.32, 412.17), { Color = P.DANGER_RED, CanCollide = false, CanQuery = false, CastShadow = false })
		end
	end

	-- The guard booth east of the road (8 x 8): a plinth, walls with a window band all round, a door facing the road,
	-- an overhanging roof, a desk with a terminal, a lamp inside.
	local b = BK.model(F, "GuardBooth")
	local x1, x2, z1, z2 = 22, 30, 403, 411
	local wall = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	BK.box(b, "Plinth", V(x1 - 0.5, 0, z1 - 0.5), V(x2 + 0.5, 0.5, z2 + 0.5), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	BK.box(b, "Floor", V(x1, 0.5, z1), V(x2, 0.6, z2), { Color = P.FLOOR_INTERIOR })
	for _, c in ipairs({ { x1, z1 }, { x2, z1 }, { x1, z2 }, { x2, z2 } }) do
		BK.box(b, "Corner", V(c[1] - 0.4, 0.5, c[2] - 0.4), V(c[1] + 0.4, 8.5, c[2] + 0.4), steel)
	end
	-- North, south, east: low wall, glass band, header. West (the road): the door and a window.
	local function side(name, a, bb, fixedAxis, fixed)
		local function box(n, y1, y2, props, inset)
			local t = inset or 0.3
			if fixedAxis == "Z" then
				BK.box(b, name .. n, V(a, y1, fixed - t), V(bb, y2, fixed + t), props)
			else
				BK.box(b, name .. n, V(fixed - t, y1, a), V(fixed + t, y2, bb), props)
			end
		end
		box("_Low", 0.6, 3.6, wall)
		box("_Glass", 3.6, 7, { Color = P.GLASS, Material = "Glass", Transparency = 0.55, CastShadow = false }, 0.08)
		box("_Head", 7, 8.5, wall)
	end
	side("N", x1 + 0.4, x2 - 0.4, "Z", z1)
	side("S", x1 + 0.4, x2 - 0.4, "Z", z2)
	side("E", z1 + 0.4, z2 - 0.4, "X", x2)
	BK.box(b, "W_Low", V(x1 - 0.3, 0.6, z1 + 0.4), V(x1 + 0.3, 3.6, 406.2), wall)
	BK.box(b, "W_Glass", V(x1 - 0.08, 3.6, z1 + 0.4), V(x1 + 0.08, 7, 406.2), { Color = P.GLASS, Material = "Glass", Transparency = 0.55, CastShadow = false })
	BK.box(b, "W_Door", V(x1 - 0.15, 0.6, 406.2), V(x1 + 0.15, 7.6, 410.6), { Color = P.STEEL_MID, Material = "Metal" })
	BK.box(b, "W_Head", V(x1 - 0.3, 7, z1 + 0.4), V(x1 + 0.3, 8.5, z2 - 0.4), wall)
	BK.box(b, "Roof", V(x1 - 1.2, 8.5, z1 - 1.2), V(x2 + 1.2, 9.2, z2 + 1.2), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	BK.box(b, "RoofTrim", V(x1 - 1.25, 8.5, z1 - 1.25), V(x2 + 1.25, 8.7, z2 + 1.25), { Color = P.AMBER, CanCollide = false, CanQuery = false, CastShadow = false })
	BK.sign(D, "Booth_Sign", BK.lookAlong(V(x1 - 1.3, 7.8, 407), V(-1, 0, 0)), Vector2.new(6, 1), "GATE 1 — SECURITY", { light = true })
	Lib.Desk(b, CFrame.new(28.4, 0.6, 407) * Lib.FACE["-X"], { name = "Desk" })
	Lib.Chair(b, CFrame.new(26.2, 0.6, 407) * Lib.FACE["+X"], { name = "Chair" })
	Lib.Terminal(b, CFrame.new(28.6, 3.4, 406.4) * Lib.FACE["-X"], { name = "Terminal", lines = { "GATE 1 · LOG", "No vehicles due", "06:00 shift" } })
	local lamp = BK.box(b, "CeilingLamp", V(25.2, 8.35, 406.2), V(26.8, 8.45, 407.8), { Color = P.LIGHT_NEUTRAL, Material = "Neon", CanCollide = false, CanQuery = false, CastShadow = false })
	BK.light(lamp, "Surface", { Color = P.LIGHT_NEUTRAL, Brightness = 1, Range = 10, Face = Enum.NormalId.Bottom, Tags = { "HubLight" } })
	BK.box(b, "Floodlight", V(29, 9.2, 410.4), V(30.4, 10.2, 411.6), steel)
	b.PrimaryPart = b:FindFirstChild("Plinth")
end

-- The flag plaza in front of the road's end: a low concrete platform with a step, planters at its ends.
function Builder.plaza(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	BK.box(S, "Plaza_Step", V(-30, C.GROUND_Y, 152), V(30, 0.4, 166), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	BK.box(S, "Plaza", V(-28, 0.4, 153.5), V(28, 0.8, 165), { Color = P.CONCRETE_LIGHT, Material = "Concrete" })
	BK.seams(S:FindFirstChild("Plaza"), Enum.NormalId.Top, 8, { width = 0.15, color = P.CONCRETE_MID, parent = D, name = "Plaza_Joints" })
	for i, x in ipairs({ -26, 26 }) do
		BK.box(S, "Planter" .. i, V(x - 1.5, 0.8, 155), V(x + 1.5, 2.4, 163), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		BK.box(D, "PlanterSoil" .. i, V(x - 1.3, 2.4, 155.2), V(x + 1.3, 2.45, 162.8), { Color = P.GROUND, Material = "Ground", Tags = { "Detail" } })
		local rng = BK.rng(70 + i)
		for leaf = 1, 8 do
			local z = 155.8 + leaf * 0.85
			BK.part(D, { Name = "PlanterLeaf" .. i, Size = V(0.3, rng.next(1.2, 2.2), 0.12), Color = P.GRASS_SPARSE, Material = "LeafyGrass", CFrame = CFrame.new(x + rng.next(-0.8, 0.8), 3.1, z) * CFrame.Angles(rng.next(-0.3, 0.3), rng.next(0, 3), rng.next(-0.3, 0.3)), Tags = { "Detail" } })
		end
	end
end

-- The motor pool (X -260..-160, Z 60..130): an asphalt apron with parking bays and a vehicle canopy.
function Builder.motorPool(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	BK.box(S, "MotorPool_Apron", V(-260, -0.3, 60), V(-160, ROAD_TOP, 128), { Color = P.ASPHALT, Material = "Asphalt" })
	local paint = { Color = P.ROAD_LINE, CanCollide = false, CanQuery = false, CastShadow = false }
	-- Bays under the canopy, 14 wide, nose out to the south.
	for _, x in ipairs({ -254, -240, -226, -212, -198 }) do
		BK.box(D, "BayLine", V(x - 0.2, ROAD_TOP, 66), V(x + 0.2, ROAD_TOP + 0.04, 98), paint)
	end
	-- The canopy: a steel roof on six columns, open on all sides, strip lights beneath.
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	for _, x in ipairs({ -252, -226, -200 }) do
		for _, z in ipairs({ 67, 95 }) do
			BK.box(S, "Canopy_Column", V(x - 0.5, 0, z - 0.5), V(x + 0.5, 14, z + 0.5), steel)
		end
	end
	for _, z in ipairs({ 67, 95 }) do
		BK.box(S, "Canopy_Beam", V(-253, 13, z - 0.5), V(-199, 14, z + 0.5), steel)
	end
	BK.box(S, "Canopy_Roof", V(-254, 14, 65), V(-198, 14.6, 97), { Color = P.STEEL_MID, Material = "Metal" })
	BK.box(D, "Canopy_Fascia", V(-254.3, 13.6, 96.9), V(-197.7, 15, 97.3), { Color = P.HAZARD_YELLOW, Tags = { "Detail" } })
	BK.sign(D, "Sign_MotorPool", BK.lookAlong(V(-226, 14.3, 97.35), V(0, 0, 1)), Vector2.new(14, 1.2), "MOTOR POOL — THIRD FRONTIER", { textColor = P.HAZARD_BLACK, bgColor = P.HAZARD_YELLOW })
	for i, x in ipairs({ -240, -226, -212 }) do
		C.fixture(ctx, "CanopyStrip" .. i, V(x, 13.85, 81), V(0.4, 0.15, 10), { Brightness = 1, Range = 18 })
	end
end

---------------------------------------------------------------------------------------------------
-- Dressed
---------------------------------------------------------------------------------------------------

-- Street lamps every 40 along both sides of each road, staggered, arms over the road.
function Builder.lamps(ctx, C, Lib)
	local F = ctx.Props
	local function lamp(name, x, z, face)
		Lib.StreetLamp(F, CFrame.new(x, 0, z) * Lib.FACE[face], { name = name, lightTags = OLIVE_LAMP_TAGS })
	end
	for z = 210, 410, 40 do
		lamp("Lamp_NW", -17.5, z, "+X")
	end
	for z = 190, 390, 40 do
		lamp("Lamp_NE", 17.5, z, "-X")
	end
	for x = -40, -200, -40 do
		if x ~= -200 then
			lamp("Lamp_WN", x, 163.5, "+Z")
		end
	end
	for x = -20, -220, -40 do
		lamp("Lamp_WS", x, 198.5, "-Z")
	end
	lamp("Lamp_Gate", -22, 410, "+X")
end

function Builder.dressMotorPool(ctx, C, Lib)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	-- Two trucks and the APC under the canopy, nose out (facing +Z).
	Lib.Truck(F, CFrame.new(-247, 0, 82) * Lib.FACE["+Z"], { name = "Truck1", unit = "3F-21" })
	Lib.Truck(F, CFrame.new(-233, 0, 81) * Lib.FACE["+Z"], { name = "Truck2", unit = "3F-22", load = false })
	Lib.APC(F, CFrame.new(-219, 0, 82) * Lib.FACE["+Z"], { name = "APC", unit = "3F-07" })
	-- The fuel tank in the east of the apron behind Jersey barriers, bollards at its ends, its warning paint.
	Lib.FuelTank(F, CFrame.new(-174, 0, 84), { name = "FuelTank" })
	for i, z in ipairs({ 76, 84, 92 }) do
		Lib.JerseyBarrier(F, CFrame.new(-182, 0, z) * Lib.FACE["-X"], { name = "Jersey_FuelW" .. i })
		Lib.JerseyBarrier(F, CFrame.new(-166, 0, z) * Lib.FACE["+X"], { name = "Jersey_FuelE" .. i })
	end
	for i, x in ipairs({ -178, -170 }) do
		Lib.Bollard(F, CFrame.new(x, 0, 72), { name = "Bollard_FuelN" .. i })
		Lib.Bollard(F, CFrame.new(x, 0, 96), { name = "Bollard_FuelS" .. i })
	end
	BK.hazardStripe(D, "Fuel_Hazard", CFrame.new(-174, ROAD_TOP, 70), 14, 1.2)
	-- Clutter: barrels by the canopy, crates against the apron's north edge, a tool cart by Truck1, oil stains.
	for i, p in ipairs({ { -196, 104, false }, { -193.2, 104.6, true }, { -194.6, 107, false }, { -191.4, 107.6, false }, { -197.4, 107.4, true } }) do
		Lib.Barrel(F, CFrame.new(p[1], 0, p[2]), { name = "Barrel" .. i, rust = p[3] })
	end
	Lib.CrateStack(F, CFrame.new(-246, 0, 63) * Lib.FACE["+Z"], { name = "Crates1", seed = 31 })
	Lib.CrateStack(F, CFrame.new(-206, 0, 63) * Lib.FACE["+Z"], { name = "Crates2", seed = 32, count = 4 })
	Lib.ToolCart(F, CFrame.new(-241.6, 0, 96) * Lib.FACE["+Z"], { name = "ToolCart", seed = 9 })
	local stain = { Color = P.KICKPLATE, Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false }
	for i, s in ipairs({ { -247, 74, 3.4 }, { -233, 76, 2.6 }, { -219, 73, 4 }, { -205, 112, 2.2 } }) do
		local p = table.clone(stain)
		p.Name, p.Axis, p.Size, p.CFrame = "OilStain" .. i, "Y", V(s[3], 0.03, s[3] * 0.8), CFrame.new(s[1], ROAD_TOP + 0.02, s[2])
		BK.cyl(D, p)
	end
	-- The level crossing's crossbucks (white boards edged red, a red lamp pair) at both approaches, booms raised.
	for i, s in ipairs({ { -228, 127.5, "+Z" }, { -192, 152.5, "-Z" } }) do
		local m = BK.model(F, "Crossbuck" .. i)
		local base = CFrame.new(s[1], 0, s[2]) * Lib.FACE[s[3]]
		local function put(name, size, local_, props)
			local p = table.clone(props)
			p.Name, p.Size, p.CFrame = name, size, base * local_
			return BK.part(m, p)
		end
		put("Post", V(0.4, 10, 0.4), CFrame.new(0, 5, 0), { Color = P.STEEL_MID, Material = "Metal" })
		for _, a in ipairs({ 35, -35 }) do
			put("Board", V(5, 0.7, 0.1), CFrame.new(0, 8.6, -0.25) * CFrame.Angles(0, 0, math.rad(a)), { Color = P.MEDICAL_WHITE, CanCollide = false, CanQuery = false })
			put("BoardEdge", V(5.1, 0.12, 0.08), CFrame.new(0, 8.6, -0.32) * CFrame.Angles(0, 0, math.rad(a)), { Color = P.DANGER_RED, CanCollide = false, CanQuery = false, CastShadow = false })
		end
		put("LampBar", V(2.6, 0.3, 0.3), CFrame.new(0, 6.2, -0.3), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		for _, x in ipairs({ -1.1, 1.1 }) do
			put("Lamp", V(0.7, 0.7, 0.2), CFrame.new(x, 6.2, -0.5), { Color = P.EMERGENCY_RED, CanCollide = false, CanQuery = false, CastShadow = false })
		end
		put("BoomPost", V(1, 3.4, 1), CFrame.new(2.6, 1.7, 0), { Color = P.HAZARD_YELLOW, Material = "Metal" })
		put("Boom", V(0.35, 13, 0.35), CFrame.new(2.6, 9.6, 0), { Color = P.MEDICAL_WHITE, CanCollide = false, CanQuery = false })
		local signPart = put("Sign", V(3.4, 0.9, 0.08), CFrame.new(0, 4.4, -0.25), { Color = P.MEDICAL_WHITE, CanCollide = false, CanQuery = false, CastShadow = false })
		local gui = Lib.gui(signPart, Enum.NormalId.Front, 0.6, 60)
		Lib.label(gui, "RAILWAY CROSSING", 0.05, 0.15, 0.9, 0.7, { font = Lib.FONT.header, color = P.HAZARD_BLACK, xAlign = "Center" })
	end
	-- The direction board at the junction, for traffic coming north from the gate.
	BK.box(F, "Signpost", V(-23.2, 0, 199.8), V(-22.8, 7, 200.2), { Color = P.STEEL_MID, Material = "Metal" })
	BK.sign(D, "Sign_Junction", BK.lookAlong(V(-23, 6, 200.3), V(0, 0, 1)), Vector2.new(9, 1.6), "← MOTOR POOL · CENTRAL COMMAND ↑", { textColor = P.SIGN_WHITE, bgColor = P.SLATE })
	-- A floodlight mast over the apron, lit only at EVENING and NIGHT.
	Lib.FloodlightMast(F, CFrame.new(-258, 0, 124), { name = "FloodMast", height = 30, aim = V(-215, 0, 85), single = true, lightTags = OLIVE_LAMP_TAGS })
end

-- Three flagpoles at (-20, 0, 160), (0, 0, 160), (20, 0, 160): the Directorate's flag in the middle, the Division's
-- either side, flying east.
function Builder.flags(ctx, C, Lib)
	local BK, P, F = ctx.BK, ctx.P, ctx.Props
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	for i, x in ipairs({ -20, 0, 20 }) do
		local k = Lib.kit(F, "Flagpole" .. i, CFrame.new(x, 0.8, 160))
		local base = k.box("Base", V(2.4, 0.8, 2.4), V(0, 0.4, 0), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		local h = if x == 0 then 34 else 30
		k.cyl("Pole", "Y", V(0.5, h, 0.5), V(0, 0.8 + h / 2, 0), { Color = P.STEEL_LIGHT, Material = "Metal" })
		k.ball("Finial", 0.9, V(0, 0.8 + h + 0.3, 0), { Color = P.AMBER, Material = "Metal", CanCollide = false })
		local top = 0.8 + h - 0.6
		local cloth = if x == 0 then P.SLATE else P.SLATE_DEEP
		k.box("Cloth", V(7, 4.4, 0.1), V(3.75, top - 2.2, 0), { Color = cloth, Material = "Fabric", CanCollide = false, CastShadow = false })
		k.box("Hoist", V(0.25, 4.4, 0.14), V(0.35, top - 2.2, 0), { Color = P.STEEL_DARK, CanCollide = false, CastShadow = false })
		k.box("BandTop", V(7, 0.3, 0.12), V(3.75, top - 0.25, 0), { Color = P.AMBER, CanCollide = false, CastShadow = false })
		k.box("BandBottom", V(7, 0.3, 0.12), V(3.75, top - 4.15, 0), { Color = P.AMBER, CanCollide = false, CastShadow = false })
		for _, side in ipairs({ -1, 1 }) do
			Lib.insignia(k, CFrame.new(3.9, top - 2.0, side * 0.065) * (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity), 2.6, P.AMBER)
		end
		k.box("Cleat", V(0.3, 0.6, 0.3), V(0, 3.2, 0.35), soft)
		k.box("Halyard", V(0.05, h - 3, 0.05), V(0, 3.5 + (h - 3) / 2, 0.3), soft)
		k.finish(base)
	end
	-- A plaque at the plaza's front, facing the road.
	BK.sign(ctx.Detail, "Plaza_Plaque", BK.lookAlong(V(0, 1.6, 165.6), V(0, 0, 1)), Vector2.new(10, 1.4), "EVERY WALL WAS BUILT BY SOMEONE WHO CARED.", { textColor = P.AMBER })
	BK.box(F, "Plaza_PlaqueStone", V(-5.4, 0.8, 164.6), V(5.4, 2.6, 165.5), { Color = P.CONCRETE_MID, Material = "Concrete" })
end

return Builder
