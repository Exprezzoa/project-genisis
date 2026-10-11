--!nonstrict
-- builders/maps/outpost07/Compound.lua  ->  DevTools.Builders.Outpost07.Compound
-- docs/maps/map_03_outpost_07.md §2-10: the ground, the corridor road, the perimeter, the courtyard, the Command
-- Bunker with Pad A, the power station, the maintenance yard, the residential block and the observation tower.
--
-- BLOCKOUT pass: right sizes and places, walls, floors, openings, stairs, collisions, markers, triggers, prompts
-- on stand-ins. Flat colors, no props, no lights. Areas are separate folders under Workspace.Map.Outpost07 and
-- can be rebuilt one at a time:
--
--   Builder.Build({ BK = BK, Common = Common, Layout = Layout, pass = "blockout", areas = { "Bunker" } })
--
-- Prompt texts are placeholders until the mission steps are wired (docs/05).

local Builder = {}

Builder.AREAS = { "Ground", "Road", "Perimeter", "Courtyard", "Bunker", "PowerStation", "Yard", "Residential", "Tower" }

-- map_03 §9: the Watcher's footprints through the compound; index 10 is Clue C.
Builder.FOOTPRINTS = {
	{ 8, -150 }, { 30, -126 }, { 52, -100 }, { 70, -74 }, { 88, -48 }, { 104, -22 }, { 116, 6 }, { 122, 34 }, { 122, 60 }, { 60, 58 },
	{ 46, 30 }, { 48, 2 }, { 50, -28 }, { 40, -70 }, { 24, -110 }, { 6, -150 },
}

local areas = {}

function areas.Ground(ctx, T)
	local S = ctx.Structure
	-- Ground plates (top just under Y 0, so slabs and roads lie on it without shared faces): X -500..500,
	-- Z -390..650, and north of that up to the embankment except where the basin ramp cuts in (X -30..30).
	local y = ctx.C.GROUND_Y
	for ix, xs in ipairs({ { -500, 0 }, { 0, 500 } }) do
		for iz, zs in ipairs({ { -390, -40 }, { -40, 310 }, { 310, 650 } }) do
			T.slab(S, ("Ground_%d_%d"):format(ix, iz), xs[1], xs[2], zs[1], zs[2], y, 4, T.GROUND)
		end
	end
	T.slab(S, "Ground_NW", -500, -30, -400, -390, y, 4, T.GROUND)
	T.slab(S, "Ground_NE", 30, 500, -400, -390, y, 4, T.GROUND)
end

function areas.Road(ctx, T)
	local S = ctx.Structure
	T.slab(S, "Road", -20, 20, 200, 650, 0, 0.4, T.ASPHALT)
	T.slab(S, "Shoulder_W", -26, -20, 200, 650, 0, 0.4, { Color = "#6B6660", Material = "Slate" })
	T.slab(S, "Shoulder_E", 20, 26, 200, 650, 0, 0.4, { Color = "#6B6660", Material = "Slate" })
	-- Checkpoint booth and the overturned truck across the west lane (both block; the truck is a mission beat).
	T.standIn("CheckpointBooth", 28, 0, 315.5, 36, 8, 324.5, T.CONCRETE)
	T.standIn("OverturnedTruck", -27, 0, 256, -3, 8, 264, T.RUST)
	T.trigger("TRG_OP_TRUCK", -40, 255, 40, 275)
	-- Both are lower than a Frame's floating root, which would walk over them.
	T.barrier("FrameBarrier_Booth", 27, 314.5, 37, 325.5)
	T.barrier("FrameBarrier_Truck", -28, 255, -2, 265)
	T.mark("FRAME_OP_START_02", 10, 0, 560, "-Z")
	T.mark("FRAME_OP_START_01", -14, 0, 566, "-Z")
	T.mark("WP_OP_SOUTHGATE", 0, 0, 200, "-Z")
	-- Frames stay in the corridor: walls at X +-120 from the south wall to Z 650, and a cap.
	T.barrier("FrameBarrier_Road_W", -122, 200, -120, 650)
	T.barrier("FrameBarrier_Road_E", 120, 200, 122, 650)
	T.barrier("FrameBarrier_Road_S", -122, 650, 122, 652)
	T.trigger("TRG_OOB_ROAD_W", -120, 204, -105, 650)
	T.trigger("TRG_OOB_ROAD_E", 105, 204, 120, 650)
	T.trigger("TRG_OOB_ROAD_S", -105, 635, 105, 650)
end

function areas.Perimeter(ctx, T)
	local S = ctx.Structure
	local wall = T.CONCRETE
	-- Walls 18 tall, 4 thick, on the lines of map_03 §4; gaps for the two gates and the east breach.
	local runs = {
		{ "Wall_S_W", -180, 198, -20, 202 }, { "Wall_S_E", 20, 198, 180, 202 },
		{ "Wall_N_W", -180, -162, -20, -158 }, { "Wall_N_E", 20, -162, 180, -158 },
		{ "Wall_W", -182, -160, -178, 200 },
		{ "Wall_E_N", 178, -160, 182, 40 }, { "Wall_E_S", 178, 80, 182, 200 },
	}
	for _, run in ipairs(runs) do
		T.box(S, run[1], run[2], 0, run[3], run[4], 18, run[5], wall)
		-- A 64-stud Frame steps over an 18-stud wall, so each run carries a FrameBarrier.
		T.barrier("FrameBarrier_" .. run[1], run[2], run[3], run[4], run[5])
	end
	for _, corner in ipairs({ { "SW", -180, 200 }, { "SE", 180, 200 }, { "NW", -180, -160 }, { "NE", 180, -160 } }) do
		T.box(S, "GuardTower_" .. corner[1], corner[2] - 4, 0, corner[3] - 4, corner[2] + 4, 24, corner[3] + 4, T.CONCRETE_DARK)
	end
	-- Gates: posts 4 x 22 x 4 at X +-22, and the south gate's arch beam at Y 20.
	for _, gate in ipairs({ { "South", 200 }, { "North", -160 } }) do
		for _, sx in ipairs({ -1, 1 }) do
			T.box(S, ("%sGatePost_%s"):format(gate[1], if sx < 0 then "W" else "E"), 22 * sx - 2, 0, gate[2] - 2, 22 * sx + 2, 22, gate[2] + 2, T.CONCRETE_DARK)
		end
		-- On foot nobody leaves through a gate.
		T.barrier("PlayerBarrier_" .. gate[1] .. "Gate", -20, gate[2] - 0.5, 20, gate[2] + 0.5, "PlayerBarrier", 0, 30)
	end
	T.box(S, "SouthGateArch", -24, 20, 198.5, 24, 22, 201.5, T.CONCRETE_DARK)
	T.trigger("TRG_OP_SOUTHGATE", -40, 195, 40, 215)
	T.mark("FRAME_OP_NORTHGATE", 0, 0, -150, "-Z")
	-- East breach (Z 40..80): open in the wall, closed to players at the wall line and to Frames a little outside.
	T.barrier("PlayerBarrier_Breach", 179.5, 40, 180.5, 80, "PlayerBarrier", 0, 30)
	T.barrier("FrameBarrier_Breach", 200, 20, 206, 100)
	T.standIn("BreachRubble", 176, 0, 44, 190, 5, 76, T.CONCRETE_DARK)
end

function areas.Courtyard(ctx, T)
	local S = ctx.Structure
	T.slab(S, "Pavement", -60, 60, 40, 160, 0, 0.4, { Color = "#7C8086", Material = "Pavement" })
	T.box(S, "FlagpolePlinth", -2, 0, 118, 2, 1.5, 122, T.CONCRETE_DARK)
	ctx.BK.cyl(S, { Name = "Flagpole", Axis = "Y", Size = Vector3.new(0.8, 30, 0.8), CFrame = CFrame.new(T.W(0, 16.5, 120)), Color = ctx.P.STEEL_LIGHT, Material = "Metal" })
	for index, at in ipairs({ { -55, 45 }, { 55, 45 }, { -55, 155 }, { 55, 155 } }) do
		T.box(S, "FloodlightPole" .. index, at[1] - 0.5, 0, at[2] - 0.5, at[1] + 0.5, 30, at[2] + 0.5, T.STEEL)
	end
	T.mark("MARK_MARA_COURTYARD", -20, 0, 110, "-Z")
	T.barrier("FrameBarrier_Flagpole", -2.5, 117.5, 2.5, 122.5)
end

function areas.Bunker(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	local shell, inner = T.CONCRETE, { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	local floor = { Color = P.FLOOR_HANGAR, Material = "Concrete" }
	T.slab(S, "Floor", -40, 40, -60, 0, 0, 0.5, floor)
	-- Shell: 14 tall, walls 2 thick on the lines X +-40, Z -60, Z 0; the entrance X -4..4, 9 tall, in the south face.
	T.box(S, "Wall_N", -41, 0, -61, 41, 14, -59, shell)
	T.box(S, "Wall_W", -41, 0, -59, -39, 14, 1, shell)
	T.box(S, "Wall_E", 39, 0, -59, 41, 14, 1, shell)
	T.box(S, "Wall_S_W", -39, 0, -1, -4, 14, 1, shell)
	T.box(S, "Wall_S_E", 4, 0, -1, 39, 14, 1, shell)
	T.box(S, "Wall_S_Lintel", -4, 9, -1, 4, 14, 1, shell)
	T.slab(S, "Ceiling", -39, 39, -59, -1, 11.5, 0.5, { Color = "#8A9096" })
	T.slab(S, "Roof", -41, 41, -61, 1, 15.5, 1.5, T.CONCRETE_DARK)
	-- Interior walls 1 thick, 11 tall: corridor X -6..6 (Z -24..0) between the bunk room and the armory, each with
	-- a door at Z -14..-9 (8 tall); the ops room behind, open to the corridor at Z -24.
	for _, side in ipairs({ { "Bunk", -1 }, { "Armory", 1 } }) do
		local x = 6 * side[2]
		T.box(S, side[1] .. "Wall_S", x - 0.5, 0, -9, x + 0.5, 11, -1, inner)
		T.box(S, side[1] .. "Wall_N", x - 0.5, 0, -24.5, x + 0.5, 11, -14, inner)
		T.box(S, side[1] .. "Wall_Lintel", x - 0.5, 8, -14, x + 0.5, 11, -9, inner)
		T.box(S, side[1] .. "Wall_Back", math.min(x, 39 * side[2]), 0, -24.5, math.max(x, 39 * side[2]), 11, -23.5, inner)
	end
	-- What the mission needs inside (stand-ins): the comm console and the LOG1 terminal's desk.
	local console = T.standIn("CommConsole", -4, 0, -42, 4, 3, -38)
	T.prompt(console, "INT_COMMS_CONSOLE", "Use Comm Console", { hold = 3.0, onFootOnly = true, enabled = false })
	local log1 = T.standIn("Log1Terminal", -22, 0, -46.5, -18, 3, -43.5)
	T.prompt(log1, "INT_EV_LOG1", "Read Log", { onFootOnly = true })
	BK.tag(log1, "EvidenceItem")
	-- Outside: the comm mast on the roof, the junction box and the cut cable (Clue A) on the east wall.
	T.box(S, "CommMast", -1.5, 15.5, -31.5, 1.5, 85.5, -28.5, T.STEEL)
	T.standIn("JunctionBox", 41, 1, -31.5, 43, 4, -28.5)
	local cable = T.standIn("CutCable", 44.2, 1, -30.8, 45.8, 2, -29.2, { Color = P.STEEL_DARK, CanCollide = false })
	T.prompt(cable, "INT_CLUE_A", "Examine Cable", { hold = 1.5, onFootOnly = true, enabled = false })
	BK.tag(cable, "EvidenceItem")
	T.mark("SPAWN_OP_BUNKER", 0, 0, -30, "-Z")
	T.mark("WP_OP_CONSOLE", 0, 0, -40, "-Z")
	T.mark("WP_OP_PADA", 0, 0, 30, "-Z")
	BK.dismountPad(ctx.Gameplay, "PAD_A", T.W(0, 0, 30), 14, BK.lookAlong(T.W(16, 0, 24), Vector3.new(0, 0, -1)))
	-- A Frame would step onto the 15.5-stud roof.
	T.barrier("FrameBarrier_Bunker", -42, -62, 42, 2)
end

function areas.PowerStation(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	T.slab(S, "YardSlab", -170, -90, -150, -80, 0, 0.4, T.CONCRETE_DARK)
	T.box(S, "GeneratorBuilding", -170, 0, -150, -140, 16, -130, T.RUST)
	for index, at in ipairs({ { -125, -140 }, { -108, -140 }, { -125, -95 }, { -108, -95 } }) do
		T.box(S, "Transformer" .. index, at[1] - 4, 0, at[2] - 4, at[1] + 4, 10, at[2] + 4, T.STEEL)
	end
	-- The Frame-scale breaker: housing facing east, the lever on its east face (rotates down in S24).
	T.box(S, "BreakerHousing", -98, 0, -119, -92, 26, -111, T.STEEL)
	local lever = BK.model(ctx.Gameplay, "Breaker")
	local arm = BK.part(lever, {
		Name = "BreakerLever", Size = Vector3.new(2, 10, 2), CFrame = CFrame.new(T.W(-90.5, 19, -115)), Color = P.HAZARD_YELLOW, Material = "Metal",
		CanCollide = false,
	})
	lever.PrimaryPart = arm
	T.prompt(arm, "INT_BREAKER", "Throw Breaker", { hold = 2.0, frameOnly = true, dist = 30, enabled = false })
	T.mark("FRAME_OP_BREAKER", -70, 0, -115, "-X")
	T.mark("WP_OP_BREAKER", -92, 0, -115, "-X")
	T.barrier("FrameBarrier_Transformers", -172, -152, -98, -78)
end

function areas.Yard(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	-- Garage X -170..-110, Z 20..80, 18 tall; the middle bay door (Z 43..57, 12 tall) is open on the east face.
	T.slab(S, "GarageFloor", -170, -110, 20, 80, 0, 0.4, T.CONCRETE_DARK)
	T.box(S, "Garage_W", -171, 0, 19, -169, 18, 81, T.RUST)
	T.box(S, "Garage_N", -169, 0, 19, -109, 18, 21, T.RUST)
	T.box(S, "Garage_S", -169, 0, 79, -109, 18, 81, T.RUST)
	T.box(S, "Garage_E_N", -111, 0, 21, -109, 18, 43, T.RUST)
	T.box(S, "Garage_E_S", -111, 0, 57, -109, 18, 79, T.RUST)
	T.box(S, "Garage_E_Lintel", -111, 12, 43, -109, 18, 57, T.RUST)
	T.slab(S, "GarageRoof", -171, -109, 19, 81, 19, 1, T.RUST)
	T.standIn("APC", -105, 0, 52, -95, 7, 68)
	T.standIn("YardTruck", -104.5, 0, 9, -95.5, 8, 31)
	T.barrier("FrameBarrier_APC", -106, 51, -94, 69)
	T.barrier("FrameBarrier_YardTruck", -105.5, 8, -94.5, 32)
	-- Fuel depot: a low bund round three tanks lying along X; Clue B is the gauge on the middle tank's east end.
	for _, wall in ipairs({ { "N", -150, -30.5, -120, -29.5 }, { "S", -150, -0.5, -120, 0.5 }, { "W", -150.5, -30, -149.5, 0 }, { "E", -120.5, -30, -119.5, 0 } }) do
		T.box(S, "Bund_" .. wall[1], wall[2], 0, wall[3], wall[4], 1.5, wall[5], T.CONCRETE)
	end
	for index, z in ipairs({ -25, -15, -5 }) do
		BK.cyl(S, { Name = "FuelTank" .. index, Axis = "X", Size = Vector3.new(22, 6, 6), CFrame = CFrame.new(T.W(-135, 3.5, z)), Color = P.RUST, Material = "CorrodedMetal" })
	end
	local gauge = T.standIn("FuelGauge", -124.4, 2, -16.5, -123.6, 4.5, -13.5)
	T.prompt(gauge, "INT_CLUE_B", "Check Fuel Gauge", { hold = 1.5, onFootOnly = true, enabled = false })
	BK.tag(gauge, "EvidenceItem")
	T.barrier("FrameBarrier_Garage", -172, 18, -108, 82)
	T.barrier("FrameBarrier_Depot", -152, -32, -118, 2)
end

function areas.Residential(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	T.box(S, "R1_BarracksA", 120, 0, 100, 170, 30, 150, T.CONCRETE_LIGHT)
	T.box(S, "R2_BarracksB", 125, 0, 10, 170, 30, 70, T.CONCRETE_LIGHT)
	-- R3 Mess Hall: one story, 12 tall, enterable through the south door (X 86..94, 9 tall).
	local inner = { Color = P.WALL_INTERIOR }
	T.slab(S, "R3_Floor", 70, 110, 40, 76, 0, 0.5, { Color = P.FLOOR_INTERIOR })
	T.box(S, "R3_Wall_N", 69, 0, 39, 111, 12, 41, T.CONCRETE_LIGHT)
	T.box(S, "R3_Wall_W", 69, 0, 41, 71, 12, 77, T.CONCRETE_LIGHT)
	T.box(S, "R3_Wall_E", 109, 0, 41, 111, 12, 77, T.CONCRETE_LIGHT)
	T.box(S, "R3_Wall_S_W", 71, 0, 75, 86, 12, 77, T.CONCRETE_LIGHT)
	T.box(S, "R3_Wall_S_E", 94, 0, 75, 109, 12, 77, T.CONCRETE_LIGHT)
	T.box(S, "R3_Wall_S_Lintel", 86, 9, 75, 94, 12, 77, T.CONCRETE_LIGHT)
	T.slab(S, "R3_Roof", 69, 111, 39, 77, 13, 1, T.CONCRETE_DARK)
	T.standIn("ServingCounter", 74, 0, 42, 106, 3.5, 46, inner)
	T.standIn("MessTable", 88, 0, 58, 96, 3, 62)
	local pad = T.standIn("Log2Datapad", 91.4, 3, 59.6, 92.6, 3.2, 60.4, { Color = P.STEEL_DARK, CanCollide = false })
	T.prompt(pad, "INT_EV_LOG2", "Read Datapad", { onFootOnly = true })
	BK.tag(pad, "EvidenceItem")
	T.barrier("FrameBarrier_R3", 68, 38, 112, 78)
	-- The Watcher's footprints (7 x 14, turned along its path); the tenth, west of the mess hall, is Clue C.
	local prints = Builder.FOOTPRINTS
	for index, at in ipairs(prints) do
		local nextAt = prints[index + 1] or { 6, -190 }
		local heading = Vector3.new(nextAt[1] - at[1], 0, nextAt[2] - at[2])
		local print = BK.part(S, {
			Name = "WatcherFootprint" .. index, Size = Vector3.new(7, 0.1, 14), CFrame = BK.lookAlong(T.W(at[1], 0.05, at[2]), heading),
			Color = P.STEEL_DARK, CanCollide = false, CanQuery = false, CastShadow = false,
		})
		if index == 10 then
			local clue = T.standIn("FootprintClue", at[1] - 1, 0.1, at[2] - 1, at[1] + 1, 0.6, at[2] + 1, { Color = P.STEEL_DARK, CanCollide = false })
			T.prompt(clue, "INT_CLUE_C", "Examine Footprint", { hold = 1.5, onFootOnly = true, enabled = false })
			BK.tag(clue, "EvidenceItem")
			print.Name = "WatcherFootprint10_ClueC"
		end
	end
end

function areas.Tower(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	local cx, cz = 150, -120
	T.box(S, "Core", cx - 6, 0, cz - 6, cx + 6, 50, cz + 6, T.CONCRETE)
	-- Five flights of 10 round the core (south, east, north, west, south), band 4 wide starting 0.5 off the core,
	-- 4 x 4 landings on the corners. The band's middle line is 8.5 from the center; a flight runs 13.
	local faces = {
		{ dir = Vector3.new(1, 0, 0), start = { -6.5, 8.5 }, landing = { 8.5, 8.5 } }, -- south face, climbing east
		{ dir = Vector3.new(0, 0, -1), start = { 8.5, 6.5 }, landing = { 8.5, -8.5 } }, -- east face, climbing north
		{ dir = Vector3.new(-1, 0, 0), start = { 6.5, -8.5 }, landing = { -8.5, -8.5 } }, -- north face, climbing west
		{ dir = Vector3.new(0, 0, 1), start = { -8.5, -6.5 }, landing = { -8.5, 8.5 } }, -- west face, climbing south
	}
	for flight = 1, 5 do
		local face = faces[(flight - 1) % 4 + 1]
		local base = (flight - 1) * 10
		BK.stairs(S, "Flight" .. flight, T.W(cx + face.start[1], base, cz + face.start[2]), face.dir, 4, 10, { stepRise = 1, stepRun = 1.3 })
		if flight < 5 then
			local lx, lz = cx + face.landing[1], cz + face.landing[2]
			T.slab(S, "Landing" .. flight, lx - 2, lx + 2, lz - 2, lz + 2, base + 10, 0.5, { Color = P.STEEL_MID, Material = "DiamondPlate" })
		end
	end
	-- Top platform at Y 50 (20 x 20), open where the last flight arrives (the south-east corner), roof at Y 58.
	local deck = { Color = P.STEEL_MID, Material = "DiamondPlate" }
	T.slab(S, "Platform_N", cx - 10, cx + 10, cz - 10, cz + 6.5, 50, 0.5, deck)
	T.slab(S, "Platform_SW", cx - 10, cx - 6.5, cz + 6.5, cz + 10, 50, 0.5, deck)
	T.slab(S, "Platform_SE", cx + 6.5, cx + 10.5, cz + 6.5, cz + 10.5, 50, 0.5, deck)
	T.slab(S, "Roof", cx - 10, cx + 10, cz - 10, cz + 10, 59, 1, T.RUST)
	for _, post in ipairs({ { -9.5, -9.5 }, { 9.5, -9.5 }, { -9.5, 9.5 }, { 9.5, 9.5 } }) do
		T.box(S, "RoofPost", cx + post[1] - 0.5, 50, cz + post[2] - 0.5, cx + post[1] + 0.5, 58, cz + post[2] + 0.5, T.STEEL)
	end
	for _, rail in ipairs({ { "N", -10, -10, 10, -9.5 }, { "W", -10, -10, -9.5, 10 }, { "E", 9.5, -10, 10, 6.5 } }) do
		T.box(S, "Rail_" .. rail[1], cx + rail[2], 50, cz + rail[3], cx + rail[4], 53.5, cz + rail[5], { Color = P.STEEL_DARK, Material = "Metal" })
	end
	-- Rails round the stairwell opening and the arrival landing, so nobody steps off the platform's edge onto
	-- the flight below or off the landing's outer sides.
	local rail = { Color = P.STEEL_DARK, Material = "Metal" }
	T.box(S, "Rail_Well_N", cx - 7, 50, cz + 6, cx + 6.5, 53.5, cz + 6.5, rail)
	T.box(S, "Rail_Well_W", cx - 7, 50, cz + 6.5, cx - 6.5, 53.5, cz + 10, rail)
	T.box(S, "Rail_Landing_E", cx + 10, 50, cz + 6.5, cx + 10.5, 53.5, cz + 10.5, rail)
	T.box(S, "Rail_Landing_S", cx + 6.5, 50, cz + 10, cx + 10.5, 53.5, cz + 10.5, rail)
	T.box(S, "Rail_SW_S", cx - 10, 50, cz + 9.5, cx - 7, 53.5, cz + 10, rail)
	local light = T.standIn("Searchlight", cx - 1.5, 50, cz - 1.5, cx + 1.5, 54, cz + 1.5)
	T.prompt(light, "INT_EV_LOG3", "Read Note", { onFootOnly = true })
	BK.tag(light, "EvidenceItem")
	T.barrier("FrameBarrier_Tower", 138, -132, 166, -108)
end

function Builder.Build(opts)
	local C, L = opts.Common, opts.Layout
	local reports = {}
	for _, area in ipairs(opts.areas or Builder.AREAS) do
		local build = areas[area] or error("Outpost07.Compound: unknown area " .. tostring(area))
		local ctx = C.begin(opts, L.ZONE, area)
		ctx.C = C
		build(ctx, L.tools(ctx))
		reports[area] = C.finish(ctx)
		opts.BK.breathe()
	end
	return reports
end

return Builder
