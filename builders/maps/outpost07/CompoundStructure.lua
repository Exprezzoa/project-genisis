--!nonstrict
-- builders/maps/outpost07/CompoundStructure.lua  ->  DevTools.Builders.Outpost07.CompoundStructure
-- docs/maps/map_03_outpost_07.md §3-10, §15; docs/07_building_with_parts.md §2 (structure pass), §6 (recipes)
--
-- The STRUCTURE pass of the compound, added on top of Compound's blockout area by area (Compound.Build calls
-- Structure[area](ctx, T) when the pass is "structure" or higher; inject it as opts.Structure like Layout):
--   lights and fixtures of the OutpostLight group (off until the power comes on, S22), the bunker's emergency
--   lamps (always on), the comm mast with its aviation lights, the signs, windows, gates, the guard towers'
--   platforms, wall copings and pilasters, the breaker's door and grip, the spark emitters that start with power.
-- Props (crates, bunks, vehicles, the "abandoned" details) are the dressed pass.
--
-- Tags read by the server's power effect (Server/Sequence/ZoneEffects): OutpostLight (a light that comes on),
-- OutpostLamp (a lamp face: Neon OnColor when lit, OffColor when not), EmergencyLight (dims to PoweredBrightness),
-- AviationLight (blinks at 0.8 Hz once powered), PowerSpark (an emitter that starts with power), BreakerSpark (a
-- burst when the lever comes down). The lever carries its DownCFrame.

local Structure = {}

local V = Vector3.new

-- A lamp face that the power effect lights: Neon in OnColor when lit, plain OffColor when not.
local function lampFace(ctx, parent, props, onColor)
	local P = ctx.P
	local p = table.clone(props)
	p.Color, p.Material, p.CanCollide, p.CastShadow = P.STEEL_DARK, "SmoothPlastic", false, false
	local face = ctx.BK.part(parent, p)
	ctx.BK.attr(face, { OnColor = onColor, OffColor = P.STEEL_DARK })
	ctx.BK.tag(face, "OutpostLamp")
	return face
end

-- A wall lamp (map_03 §15): a housing on the wall, its face down, a SpotLight AMBER_LAMP, range 30, angle 60.
local function wallLamp(ctx, T, name, x, y, z, outward)
	local BK, P = ctx.BK, ctx.P
	local cf = BK.lookAlong(T.W(x, y, z), outward)
	BK.part(ctx.Lighting, { Name = name, Size = V(1.8, 0.9, 1.4), CFrame = cf * CFrame.new(0, 0, -0.7), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	local face = lampFace(ctx, ctx.Lighting, { Name = name .. "_Face", Size = V(1.4, 0.15, 1.0), CFrame = cf * CFrame.new(0, -0.5, -0.7) }, P.AMBER_LAMP)
	BK.light(face, "Spot", { Color = P.AMBER_LAMP, Range = 30, Angle = 60, Face = Enum.NormalId.Bottom, Enabled = false, Tags = { "OutpostLight" } })
end

-- A ceiling panel (SurfaceLight LIGHT_NEUTRAL, brightness 0.8, range 16) with its face down.
local function ceilingPanel(ctx, T, name, x, y, z)
	local P = ctx.P
	local face = lampFace(ctx, ctx.Lighting, { Name = name, Size = V(4, 0.2, 2), CFrame = CFrame.new(T.W(x, y, z)) }, P.LIGHT_NEUTRAL)
	ctx.BK.light(face, "Surface", { Color = P.LIGHT_NEUTRAL, Brightness = 0.8, Range = 16, Face = Enum.NormalId.Bottom, Enabled = false, Tags = { "OutpostLight" } })
end

-- A sign on a wall, facing `outward` (amber Michroma on SLATE_DEEP, docs/06 §7).
local function sign(ctx, T, name, x, y, z, outward, width, height, text)
	local BK = ctx.BK
	return BK.sign(ctx.Detail, name, BK.lookAlong(T.W(x, y, z), outward), Vector2.new(width, height), text)
end

-- Glass strips along a building's faces, one per floor (dark glass, the residential block's window rows).
local function windowRows(ctx, T, name, x1, z1, x2, z2, floors)
	local BK, P = ctx.BK, ctx.P
	local glass = { Color = "#2A3138", Material = "Glass", Transparency = 0.25, Reflectance = 0.15, CanCollide = false, CastShadow = false }
	for floor = 1, floors do
		local y1, y2 = (floor - 1) * 10 + 4, (floor - 1) * 10 + 7
		T.box(ctx.Detail, ("%s_WinS%d"):format(name, floor), x1 + 3, y1, z2, x2 - 3, y2, z2 + 0.15, glass)
		T.box(ctx.Detail, ("%s_WinN%d"):format(name, floor), x1 + 3, y1, z1 - 0.15, x2 - 3, y2, z1, glass)
		T.box(ctx.Detail, ("%s_WinW%d"):format(name, floor), x1 - 0.15, y1, z1 + 3, x1, y2, z2 - 3, glass)
		T.box(ctx.Detail, ("%s_WinE%d"):format(name, floor), x2, y1, z1 + 3, x2 + 0.15, y2, z2 - 3, glass)
		-- A floor line between the floors.
		if floor < floors then
			T.box(ctx.Detail, ("%s_Band%d"):format(name, floor), x1 - 0.2, floor * 10 - 0.3, z1 - 0.2, x2 + 0.2, floor * 10 + 0.3, z2 + 0.2, { Color = P.CONCRETE_DARK, Material = "Concrete" })
		end
	end
	T.box(ctx.Detail, name .. "_Coping", x1 - 0.4, 30, z1 - 0.4, x2 + 0.4, 30.8, z2 + 0.4, { Color = P.CONCRETE_DARK, Material = "Concrete" })
end

-- A chain-link gate leaf (20 x 14): a frame of thin bars and a see-through mesh. cf is its hinge at the bottom.
local function gateLeaf(ctx, name, cf)
	local BK, P = ctx.BK, ctx.P
	local model = BK.model(ctx.Detail, name)
	local bar = { Color = P.STEEL_LIGHT, Material = "Metal", CanCollide = false }
	local function piece(pname, size, offset, props)
		local p = table.clone(props)
		p.Name, p.Size, p.CFrame = pname, size, cf * CFrame.new(offset)
		BK.part(model, p)
	end
	piece("Top", V(20, 0.4, 0.4), V(10, 14, 0), bar)
	piece("Bottom", V(20, 0.4, 0.4), V(10, 0.6, 0), bar)
	piece("Hinge", V(0.5, 14, 0.5), V(0, 7, 0), bar)
	piece("Latch", V(0.4, 14, 0.4), V(20, 7, 0), bar)
	piece("Mesh", V(19.6, 13.2, 0.1), V(10, 7.2, 0), { Color = P.STEEL_LIGHT, Material = "DiamondPlate", Transparency = 0.65, CanCollide = false, CastShadow = false })
	return model
end

function Structure.Road(ctx, T)
	local BK, P = ctx.BK, ctx.P
	-- The gantry over the road at Z 330 with its sign (map_03 §3), and the faded dashed center line.
	for _, x in ipairs({ -24, 24 }) do
		T.box(ctx.Structure, "GantryPost", x - 0.6, 0, 329.4, x + 0.6, 22, 330.6, { Color = P.STEEL_DARK, Material = "Metal" })
	end
	T.box(ctx.Structure, "GantryBeam", -25, 20, 329.5, 25, 22, 330.5, { Color = P.STEEL_DARK, Material = "Metal" })
	BK.sign(ctx.Detail, "GantrySign", BK.lookAlong(T.W(0, 17.5, 330.6), V(0, 0, 1)), Vector2.new(44, 4), "FRONTIER OUTPOST 07 — GREYWATCH — HALT FOR INSPECTION")
	for z = 210, 640, 16 do
		T.box(ctx.Detail, "CenterDash", -0.5, 0, z, 0.5, 0.06, z + 8, { Color = P.ROAD_LINE, Transparency = 0.35, CanCollide = false, CastShadow = false })
	end
	-- The checkpoint booth's windows (broken: dark openings) and its open door.
	T.box(ctx.Detail, "BoothWindow_W", 27.85, 4, 317, 28, 6.5, 323, { Color = "#1B1D20", CanCollide = false })
	T.box(ctx.Detail, "BoothDoor", 36, 0, 317.5, 36.15, 7, 320.5, { Color = "#1B1D20", CanCollide = false })
end

function Structure.Perimeter(ctx, T)
	local BK, P = ctx.BK, ctx.P
	local coping = { Color = P.CONCRETE_DARK, Material = "Concrete" }
	-- Coping along every wall run and a pilaster every 20 studs (the WallSegment recipe, 07 §6).
	local runs = {
		{ -180, 198, -20, 202 }, { 20, 198, 180, 202 }, { -180, -162, -20, -158 }, { 20, -162, 180, -158 },
		{ -182, -160, -178, 200 }, { 178, -160, 182, 40 }, { 178, 80, 182, 200 },
	}
	for index, run in ipairs(runs) do
		local x1, z1, x2, z2 = run[1], run[2], run[3], run[4]
		local alongX = (x2 - x1) > (z2 - z1)
		T.box(ctx.Detail, "Coping" .. index, x1 - (if alongX then 0 else 0.5), 18, z1 - (if alongX then 0.5 else 0), x2 + (if alongX then 0 else 0.5), 19, z2 + (if alongX then 0.5 else 0), coping)
		local from, to = if alongX then x1 else z1, if alongX then x2 else z2
		for at = from + 10, to - 10, 20 do
			if alongX then
				T.box(ctx.Detail, "Pilaster", at - 0.8, 0, z1 - 0.6, at + 0.8, 18, z2 + 0.6, coping)
			else
				T.box(ctx.Detail, "Pilaster", x1 - 0.6, 0, at - 0.8, x2 + 0.6, 18, at + 0.8, coping)
			end
		end
	end
	-- Guard towers: a roofed platform at Y 18 with a railing, a ladder and a dead searchlight.
	for _, corner in ipairs({ { -180, 200 }, { 180, 200 }, { -180, -160 }, { 180, -160 } }) do
		local cx, cz = corner[1], corner[2]
		T.slab(ctx.Structure, "TowerDeck", cx - 5, cx + 5, cz - 5, cz + 5, 18.5, 0.5, { Color = P.STEEL_MID, Material = "DiamondPlate" })
		for _, post in ipairs({ { -4.6, -4.6 }, { 4.6, -4.6 }, { -4.6, 4.6 }, { 4.6, 4.6 } }) do
			T.box(ctx.Structure, "TowerPost", cx + post[1] - 0.25, 18.5, cz + post[2] - 0.25, cx + post[1] + 0.25, 24, cz + post[2] + 0.25, { Color = P.STEEL_DARK, Material = "Metal" })
		end
		T.slab(ctx.Structure, "TowerRoof", cx - 5.5, cx + 5.5, cz - 5.5, cz + 5.5, 24.6, 0.6, { Color = P.RUST, Material = "CorrodedMetal" })
		for _, rail in ipairs({ { -5, -5, 5, -4.8 }, { -5, 4.8, 5, 5 }, { -5, -5, -4.8, 5 }, { 4.8, -5, 5, 5 } }) do
			T.box(ctx.Detail, "TowerRail", cx + rail[1], 21, cz + rail[2], cx + rail[3], 21.3, cz + rail[4], { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		end
		T.box(ctx.Detail, "Searchlight", cx - 0.8, 18.5, cz - 0.8, cx + 0.8, 20, cz + 0.8, { Color = P.STEEL_DARK, Material = "Metal" })
	end
	-- South gate: the sign on the arch beam; the west leaf hangs from one hinge (70 degrees, tilted 8), the east
	-- leaf is swung fully open. North gate: both leaves open, a hazard barrier pushed aside.
	BK.sign(ctx.Detail, "SouthGateSign", BK.lookAlong(T.W(0, 21, 201.6), V(0, 0, 1)), Vector2.new(40, 2.4), "FRONTIER OUTPOST 07 — GREYWATCH")
	gateLeaf(ctx, "SouthGate_W", CFrame.new(T.W(-20, 0, 200)) * CFrame.Angles(0, math.rad(70), 0) * CFrame.Angles(0, 0, math.rad(-8)))
	gateLeaf(ctx, "SouthGate_E", CFrame.new(T.W(20, 0, 200)) * CFrame.Angles(0, math.rad(90), 0))
	gateLeaf(ctx, "NorthGate_W", CFrame.new(T.W(-20, 0, -160)) * CFrame.Angles(0, math.rad(-95), 0))
	gateLeaf(ctx, "NorthGate_E", CFrame.new(T.W(20, 0, -160)) * CFrame.Angles(0, math.rad(-85), 0))
	BK.part(ctx.Detail, {
		Name = "HazardBarrier", Size = V(10, 1, 0.6), CFrame = CFrame.new(T.W(30, 2.5, -150)) * CFrame.Angles(0, math.rad(35), 0),
		Color = P.HAZARD_YELLOW, CanCollide = false,
	})
	-- Gate lamps on the four gate posts (OutpostLight).
	for _, at in ipairs({ { -22, 200, 1 }, { 22, 200, 1 }, { -22, -160, -1 }, { 22, -160, -1 } }) do
		wallLamp(ctx, T, "GateLamp", at[1], 21, at[2] + 2.2 * at[3], V(0, 0, at[3]))
	end
end

function Structure.Courtyard(ctx, T)
	local BK, P = ctx.BK, ctx.P
	-- Faded parade-ground markings (white at 50%).
	local paint = { Color = "#E8ECEF", Transparency = 0.5, CanCollide = false, CastShadow = false }
	T.box(ctx.Detail, "Parade_Outline_N", -40, 0.4, 70, 40, 0.45, 70.6, paint)
	T.box(ctx.Detail, "Parade_Outline_S", -40, 0.4, 149.4, 40, 0.45, 150, paint)
	T.box(ctx.Detail, "Parade_Outline_W", -40, 0.4, 70, -39.4, 0.45, 150, paint)
	T.box(ctx.Detail, "Parade_Outline_E", 39.4, 0.4, 70, 40, 0.45, 150, paint)
	-- Floodlight heads on the four poles: two lamp boxes aimed at the courtyard's middle, one SpotLight each pole
	-- (range 60, brightness 1.5, shadows; map_03 §5).
	for index, at in ipairs({ { -55, 45 }, { 55, 45 }, { -55, 155 }, { 55, 155 } }) do
		local head = T.W(at[1], 30.5, at[2])
		local aim = CFrame.lookAt(head, T.W(0, 0, 100))
		BK.part(ctx.Lighting, { Name = "FloodHead" .. index, Size = V(6.4, 2.2, 2.2), CFrame = aim, Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		local face = lampFace(ctx, ctx.Lighting, { Name = "FloodFace" .. index, Size = V(6, 1.8, 0.2), CFrame = aim * CFrame.new(0, 0, -1.15) }, P.LIGHT_COOL)
		BK.light(face, "Spot", { Color = P.LIGHT_COOL, Brightness = 1.5, Range = 60, Angle = 60, Face = Enum.NormalId.Front, Shadows = true, Enabled = false, Tags = { "OutpostLight" } })
	end
end

function Structure.Bunker(ctx, T)
	local BK, P = ctx.BK, ctx.P
	local concrete = { Color = P.CONCRETE_MID, Material = "Concrete" }
	-- Battered walls: a wedge along the outside base of each wall (4 thick at the base, map_03 §6), the roof
	-- parapet (1.5) and a roof hatch.
	for _, w in ipairs({ { "N", 0, -61, V(0, 0, -1), 82 }, { "W", -41, -30, V(-1, 0, 0), 62 }, { "E", 41, -30, V(1, 0, 0), 62 } }) do
		BK.wedge(ctx.Structure, { Name = "Batter_" .. w[1], Size = V(w[5], 6, 2), CFrame = BK.lookAlong(T.W(w[2], 3, w[3]) + w[4], w[4]), Color = P.CONCRETE_MID, Material = "Concrete" })
	end
	for _, p in ipairs({ { -41, -61, 41, -60 }, { -41, 0, 41, 1 }, { -41, -60, -40, 0 }, { 40, -60, 41, 0 } }) do
		T.box(ctx.Structure, "Parapet", p[1], 15.5, p[2], p[3], 17, p[4], concrete)
	end
	T.box(ctx.Detail, "RoofHatch", -18, 15.5, -20, -14, 16, -16, { Color = P.STEEL_MID, Material = "DiamondPlate" })
	-- Entrance: the blast door slid into the wall (its edge shows), a canopy over it, the sign.
	T.box(ctx.Detail, "BlastDoorEdge", 3.6, 0, -0.6, 4, 9, 0.6, { Color = P.STEEL_MID, Material = "Metal" })
	BK.wedge(ctx.Structure, { Name = "Canopy", Size = V(12, 1.2, 4), CFrame = BK.lookAlong(T.W(0, 9.6, 3), V(0, 0, 1)), Color = P.CONCRETE_DARK, Material = "Concrete" })
	sign(ctx, T, "BunkerSign", 0, 11.6, 1.1, V(0, 0, 1), 12, 1.6, "COMMAND BUNKER")
	-- The comm mast (07 §6 CommMast, 70 tall): four truss legs, platforms every 20, two dishes left (the third lies
	-- fallen at (30, 0, 20)), red aviation lights that blink once powered.
	for _, leg in ipairs({ { -2.5, -32.5 }, { 2.5, -32.5 }, { -2.5, -27.5 }, { 2.5, -27.5 } }) do
		BK.truss(ctx.Structure, { Name = "MastLeg", Size = V(2, 70, 2), CFrame = CFrame.new(T.W(leg[1], 50.5, leg[2])), Color = P.STEEL_DARK, Material = "Metal" })
	end
	for y = 35.5, 75.5, 20 do
		T.slab(ctx.Structure, "MastPlatform", -4, 4, -34, -26, y, 0.3, { Color = P.STEEL_MID, Material = "DiamondPlate" })
	end
	for index, dish in ipairs({ { 40, V(1, 0, 0) }, { 62, V(0, 0, 1) } }) do
		BK.cyl(ctx.Detail, { Name = "Dish" .. index, Axis = "Z", Size = V(7, 7, 0.6), CFrame = BK.lookAlong(T.W(0, dish[1], -30) + dish[2] * 4, dish[2]), Color = "#B7BCC2", Material = "Metal" })
	end
	BK.cyl(ctx.Detail, { Name = "FallenDish", Axis = "Z", Size = V(10, 10, 0.8), CFrame = CFrame.new(T.W(30, 1.6, 20)) * CFrame.Angles(math.rad(80), 0, math.rad(20)), Color = "#B7BCC2", Material = "Metal" })
	for index, y in ipairs({ 85.8, 56 }) do
		local beacon = BK.part(ctx.Lighting, { Name = "AviationLight" .. index, Size = V(0.9, 0.9, 0.9), CFrame = CFrame.new(T.W(2.4, y, -28)), Color = P.STEEL_DARK, Material = "SmoothPlastic", CanCollide = false })
		BK.attr(beacon, { OnColor = P.DANGER_RED, OffColor = P.STEEL_DARK })
		BK.tag(beacon, "AviationLight")
		BK.light(beacon, "Point", { Color = P.DANGER_RED, Brightness = 2, Range = 20, Enabled = false })
	end
	-- The cable tray down the east wall to the junction box, the cable to the cut, and a spark there once powered.
	T.box(ctx.Detail, "CableTray", 41, 4, -31, 41.6, 14, -29, { Color = P.STEEL_DARK, Material = "Metal" })
	BK.cyl(ctx.Detail, { Name = "CableEnd_A", Axis = "X", Size = V(1.6, 0.8, 0.8), CFrame = CFrame.new(T.W(43.7, 1.5, -30)), Color = "#1B1D20", CanCollide = false })
	BK.cyl(ctx.Detail, { Name = "CableEnd_B", Axis = "X", Size = V(1.6, 0.8, 0.8), CFrame = CFrame.new(T.W(46.3, 1.5, -30)), Color = "#1B1D20", CanCollide = false })
	-- The real cable ends replace the stand-in's look; the stand-in keeps the prompt.
	local standIn = ctx.Gameplay:FindFirstChild("CutCable")
	if standIn then
		standIn.Transparency = 1
	end
	local spark = BK.part(ctx.Detail, { Name = "CutSpark", Size = V(0.3, 0.3, 0.3), CFrame = CFrame.new(T.W(45, 1.6, -30)), Transparency = 1, CanCollide = false, CanQuery = false })
	local emitter = BK.emitter(spark, "Sparks")
	emitter.Rate, emitter.Enabled = 1, false
	BK.tag(emitter, "PowerSpark")
	-- Outside lamps (OutpostLight): two over the entrance, one on each side wall.
	wallLamp(ctx, T, "BunkerLamp_SW", -10, 12, 1.4, V(0, 0, 1))
	wallLamp(ctx, T, "BunkerLamp_SE", 10, 12, 1.4, V(0, 0, 1))
	wallLamp(ctx, T, "BunkerLamp_W", -41.4, 12, -30, V(-1, 0, 0))
	wallLamp(ctx, T, "BunkerLamp_E", 41.6, 12, -20, V(1, 0, 0))
	-- Inside: six ceiling panels (OutpostLight) and four caged emergency lamps, red, always on, dimmed to 0.3
	-- once the power is back (map_03 §6).
	for index, at in ipairs({ { 0, -6 }, { 0, -18 }, { -22, -13 }, { 22, -13 }, { -8, -38 }, { 8, -38 } }) do -- two over the console
		ceilingPanel(ctx, T, "CeilingPanel" .. index, at[1], 10.9, at[2])
	end
	for index, at in ipairs({ { -37, -4 }, { 37, -4 }, { -37, -56 }, { 37, -56 } }) do
		local lamp = BK.part(ctx.Lighting, { Name = "EmergencyLamp" .. index, Size = V(0.8, 0.6, 0.8), CFrame = CFrame.new(T.W(at[1], 9.6, at[2])), Color = P.EMERGENCY_RED, Material = "Neon", CanCollide = false })
		T.box(ctx.Lighting, "EmergencyCage" .. index, at[1] - 0.55, 9.25, at[2] - 0.55, at[1] + 0.55, 9.95, at[2] + 0.55, { Color = P.STEEL_DARK, Material = "DiamondPlate", Transparency = 0.6, CanCollide = false })
		BK.light(lamp, "Point", { Color = P.EMERGENCY_RED, Brightness = 1, Range = 14, Tags = { "EmergencyLight" }, Attributes = { PoweredBrightness = 0.3 } })
	end
	-- The comm console (07 §6 Console, at Frame-pilot scale 8 wide): a slanted top and a screen on the prompt's base.
	BK.wedge(ctx.Detail, { Name = "ConsoleTop", Size = V(8, 1.2, 2.5), CFrame = BK.lookAlong(T.W(0, 3.6, -40.6), V(0, 0, 1)), Color = P.STEEL_MID, Material = "Metal" })
	BK.screen(ctx.Detail, "ConsoleScreen", CFrame.lookAt(T.W(0, 5.1, -41.6), T.W(0, 4.4, -38)), Vector2.new(6, 1.8), {
		text = "COMMS ROUTING\nARRAY ...... NO CARRIER\nUPLINK ..... --",
	})
	T.box(ctx.Detail, "RadioStack_W", -8, 0, -42, -5, 6, -38.5, { Color = P.STEEL_DARK, Material = "Metal" })
	T.box(ctx.Detail, "RadioStack_E", 5, 0, -42, 8, 6, -38.5, { Color = P.STEEL_DARK, Material = "Metal" })
	T.box(ctx.Detail, "RadioRacks_N", -30, 0, -58.5, 30, 8, -56.5, { Color = P.STEEL_DARK, Material = "Metal" })
	BK.screen(ctx.Detail, "Log1Screen", CFrame.lookAt(T.W(-20, 3.9, -45.6), T.W(-20, 3.9, -40)), Vector2.new(1.8, 1.2), {})
end

function Structure.PowerStation(ctx, T)
	local BK, P = ctx.BK, ctx.P
	-- Chain-link fence round the station (posts every 8, 10 tall, 3 rails), open on the east side at Z -125..-105.
	local post = { Color = P.STEEL_MID, Material = "Metal", CanCollide = false }
	local function fence(name, x1, z1, x2, z2)
		local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
		local from, to = if alongX then x1 else z1, if alongX then x2 else z2
		for at = from, to, 8 do
			local x, z = if alongX then at else x1, if alongX then z1 else at
			T.box(ctx.Detail, name .. "Post", x - 0.2, 0, z - 0.2, x + 0.2, 10, z + 0.2, post)
		end
		for _, y in ipairs({ 1, 5, 9.6 }) do
			T.box(ctx.Detail, name .. "Rail", math.min(x1, x2) - 0.1, y, math.min(z1, z2) - 0.1, math.max(x1, x2) + 0.1, y + 0.2, math.max(z1, z2) + 0.1, post)
		end
		T.box(ctx.Detail, name .. "Mesh", math.min(x1, x2) - 0.05, 0.2, math.min(z1, z2) - 0.05, math.max(x1, x2) + 0.05, 9.6, math.max(z1, z2) + 0.05, { Color = P.STEEL_LIGHT, Material = "DiamondPlate", Transparency = 0.7, CanCollide = false, CastShadow = false })
	end
	fence("FenceN", -170, -150, -90, -150)
	fence("FenceS", -170, -80, -90, -80)
	fence("FenceE1", -90, -150, -90, -125)
	fence("FenceE2", -90, -105, -90, -80)
	-- The generator building: roll door, two exhaust stacks, its sign; transformers get fins, insulators and signs.
	T.box(ctx.Detail, "RollDoor", -140.2, 0, -146, -140, 12, -134, { Color = P.STEEL_MID, Material = "CorrodedMetal" })
	for _, x in ipairs({ -165, -150 }) do
		BK.cyl(ctx.Structure, { Name = "ExhaustStack", Axis = "Y", Size = V(2, 10, 2), CFrame = CFrame.new(T.W(x, 21, -142)), Color = P.RUST_DARK, Material = "CorrodedMetal" })
	end
	sign(ctx, T, "GeneratorSign", -139.9, 13.5, -140, V(1, 0, 0), 8, 1.4, "GENERATOR 1")
	for index, at in ipairs({ { -125, -140 }, { -108, -140 }, { -125, -95 }, { -108, -95 } }) do
		for side = -1, 1, 2 do
			for fin = -1.5, 1.5, 1 do
				T.box(ctx.Detail, "Fin", at[1] + side * 4, 1, at[2] + fin * 2 - 0.15, at[1] + side * 4 + side * 1, 8, at[2] + fin * 2 + 0.15, { Color = "#59606A", Material = "Metal", CanCollide = false })
			end
		end
		for ins = -2, 2, 2 do
			BK.cyl(ctx.Detail, { Name = "Insulator", Axis = "Y", Size = V(0.8, 2.4, 0.8), CFrame = CFrame.new(T.W(at[1] + ins, 11.2, at[2])), Color = "#D9D9D9", Material = "SmoothPlastic", CanCollide = false })
		end
		if index <= 2 then
			-- Two of them are scorched and spark once the power is back (map_03 §7).
			T.box(ctx.Detail, "Scorch", at[1] - 3, 10, at[2] - 4.1, at[1] + 3, 10.05, at[2] - 1, { Color = "#1B1D20", CanCollide = false, CastShadow = false })
			local spot = BK.part(ctx.Detail, { Name = "TransformerSpark", Size = V(0.3, 0.3, 0.3), CFrame = CFrame.new(T.W(at[1], 10.5, at[2])), Transparency = 1, CanCollide = false, CanQuery = false })
			local emitter = BK.emitter(spot, "Sparks")
			emitter.Rate, emitter.Enabled = 3, false
			BK.tag(emitter, "PowerSpark")
		end
	end
	-- The breaker: a steel door on the housing, a black grip band on the lever, the lever's down position (it turns
	-- 90 degrees about its top pivot, its end swinging out to the east, toward the Frame that throws it), and two spark bursts for the moment it comes down (docs/05 S22).
	T.box(ctx.Detail, "BreakerDoor", -92, 2, -118, -91.8, 14, -112, { Color = P.STEEL_MID, Material = "Metal" })
	local lever = ctx.Gameplay:FindFirstChild("Breaker")
	local arm = lever and lever:FindFirstChild("BreakerLever")
	if arm then
		local pivot = arm.CFrame * CFrame.new(0, arm.Size.Y / 2, 0)
		BK.attr(arm, { UpCFrame = arm.CFrame, DownCFrame = pivot * CFrame.Angles(0, 0, math.rad(90)) * pivot:Inverse() * arm.CFrame })
		local grip = BK.part(lever, { Name = "Grip", Size = V(2.2, 1.6, 2.2), CFrame = arm.CFrame * CFrame.new(0, -arm.Size.Y / 2 + 1, 0), Color = P.HAZARD_BLACK, CanCollide = false })
		BK.attr(grip, { UpCFrame = grip.CFrame, DownCFrame = pivot * CFrame.Angles(0, 0, math.rad(90)) * pivot:Inverse() * grip.CFrame })
		for index = 1, 2 do
			local spot = BK.part(lever, { Name = "BreakerSparkPoint" .. index, Size = V(0.3, 0.3, 0.3), CFrame = pivot * CFrame.new(0, -0.5, (index - 1.5) * 2), Transparency = 1, CanCollide = false, CanQuery = false })
			local emitter = BK.emitter(spot, "Sparks")
			BK.tag(emitter, "BreakerSpark")
		end
	end
	wallLamp(ctx, T, "StationLamp", -150, 12, -129.4, V(0, 0, 1))
	wallLamp(ctx, T, "GeneratorLamp", -139.4, 13, -144, V(1, 0, 0))
	wallLamp(ctx, T, "GateLampStation", -89.5, 9, -105, V(1, 0, 0))
end

function Structure.Yard(ctx, T)
	local BK, P = ctx.BK, ctx.P
	-- Three bay doors on the garage's east face (the middle one open), the fuel tanks' saddles and sign.
	for _, z in ipairs({ { 26, 40 }, { 60, 74 } }) do
		T.box(ctx.Detail, "BayDoor", -108.9, 0, z[1], -108.7, 12, z[2], { Color = P.STEEL_MID, Material = "CorrodedMetal" })
	end
	for _, z in ipairs({ -25, -15, -5 }) do
		for _, x in ipairs({ -140, -130 }) do
			T.box(ctx.Detail, "Saddle", x - 0.6, 0, z - 3, x + 0.6, 1.4, z + 3, { Color = P.STEEL_DARK, Material = "Metal" })
		end
	end
	sign(ctx, T, "FuelSign", -119.4, 2.6, -24, V(1, 0, 0), 6, 1.2, "FUEL — NO FLAME")
	for _, z in ipairs({ 33, 50, 67 }) do
		wallLamp(ctx, T, "GarageLamp", -108.4, 14, z, V(1, 0, 0))
	end
end

function Structure.Residential(ctx, T)
	local P = ctx.P
	windowRows(ctx, T, "R1", 120, 100, 170, 150, 3)
	windowRows(ctx, T, "R2", 125, 25, 170, 70, 3)
	-- R2's collapsed corner: broken slab ends sticking out and a rubble pile (map_03 §9).
	for floor = 1, 2 do
		T.box(ctx.Structure, "BrokenSlab", 155, floor * 10 - 0.5, 18, 162, floor * 10 + 0.5, 25, { Color = P.CONCRETE_DARK, Material = "Concrete" })
	end
	ctx.BK.wedge(ctx.Structure, { Name = "Rubble", Size = V(15, 7, 12), CFrame = ctx.BK.lookAlong(T.W(162.5, 3.5, 17), V(0, 0, -1)), Color = P.CONCRETE_DARK, Material = "Concrete" })
	T.box(ctx.Detail, "R1_Door", 119.8, 0, 122, 120, 8, 128, { Color = P.STEEL_MID, Material = "Metal" })
	sign(ctx, T, "QuartersSign", 119.7, 9.2, 125, V(-1, 0, 0), 10, 1.4, "QUARTERS — 7TH GARRISON")
	-- The mess hall: windows either side of the door, a sign, two ceiling panels; lamps on the barracks.
	for _, x in ipairs({ { 74, 82 }, { 98, 106 } }) do
		T.box(ctx.Detail, "R3_Window", x[1], 4, 76.9, x[2], 7, 77.05, { Color = "#2A3138", Material = "Glass", Transparency = 0.25, CanCollide = false })
	end
	sign(ctx, T, "MessSign", 90, 10.4, 77.1, V(0, 0, 1), 8, 1.2, "MESS")
	ceilingPanel(ctx, T, "MessPanel1", 80, 11.9, 58)
	ceilingPanel(ctx, T, "MessPanel2", 100, 11.9, 58)
	wallLamp(ctx, T, "MessLamp", 90, 11, 77.6, V(0, 0, 1))
	wallLamp(ctx, T, "R1Lamp", 119.6, 11, 132, V(-1, 0, 0))
	wallLamp(ctx, T, "R2Lamp", 124.6, 11, 48, V(-1, 0, 0))
	wallLamp(ctx, T, "R1Lamp2", 145, 11, 150.6, V(0, 0, 1))
	wallLamp(ctx, T, "R2Lamp2", 147, 11, 70.6, V(0, 0, 1))
end

function Structure.Tower(ctx, T)
	wallLamp(ctx, T, "TowerLamp", 150, 9, -113.6, V(0, 0, 1))
end

return Structure
