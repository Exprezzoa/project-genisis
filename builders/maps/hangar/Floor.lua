--!nonstrict
-- builders/maps/hangar/Floor.lua  ->  DevTools.Builders.Hangar.Floor
-- docs/maps/map_02_frame_hangar.md §6 (control booth) and §7 (floor props and markings).
--
-- Passes:
--   structure  the ★ markings: the Safe Viewing Line (hazard stripe and floor text), the Frame lane's chevrons, the
--              pedestrian lane's dashed edges; the control booth (decor, with T3 seated in it: Config/NPCs)
--   dressed    + tool carts, crate stacks, the plate rack, coolant tanks, power cabinets and their cable runs, the
--              forklift (an ambient mover on its loop: AmbientController), the mobile staircase, extinguisher
--              stations on the pilasters, hazard bollards along the pedestrian lane
-- Places that moved from §7's numbers (D-101): two west crate stacks between the south wall's pilasters (Z -75.6; at
-- Z -80 they stood on the pedestrian lane, whose south edge is drawn at Z -78), the east ones at Z -82 and X 26/104
-- (clear of the cabinets' cables); the power cabinets at X -35, 35, 95 (at -50 and 50 they stood on pilasters); one
-- plate rack (-104, -176) (Unit 03's own pec rack fills X 102..112); T5's cart 3 north of T5; the mobile staircase at
-- X 41.6 (at 40 it stood on the Bay 2-3 catwalk's column); bollards only along the lane's south edge (on the north edge
-- they stood on the nav route to the stair).
-- opts: Common, BK, Props, pass.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Floor", true)
	local BK, P = ctx.BK, ctx.P
	if ctx.level < 2 then
		return C.finish(ctx)
	end
	local Lib = opts.Props
	Builder.markings(ctx)
	Builder.booth(ctx, Lib)
	if ctx.level >= 3 then
		Builder.props(ctx, Lib)
	end
	return C.finish(ctx)
end

function Builder.markings(ctx)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Detail
	local paint = { Color = P.HAZARD_YELLOW, CanCollide = false, CanQuery = false, CastShadow = false }
	-- The Safe Viewing Line: a 2-wide hazard stripe X -100..100 at Z -168, and its floor text at Z -165.
	BK.hazardStripe(F, "SafeViewingLine", CFrame.fromMatrix(V(0, 0.03, -168), Vector3.xAxis, Vector3.yAxis), 200, 2, { angle = 45 })
	BK.floorText(F, "SafeViewingText", V(0, 0, -164.4), Vector2.new(40, 2.4), "SAFE VIEWING LINE — DO NOT CROSS")
	-- The Frame lane: chevrons (2 bars, 1 x 10 at +-45°) every 20 from (0, -180) south to (0, -150), then east.
	local function chevron(name, at, dir)
		local right = V(-dir.Z, 0, dir.X)
		for _, side in ipairs({ -1, 1 }) do
			-- Each arm trails back from the tip at 45°.
			local back = (-dir + right * side).Unit
			local center = at + back * 5 + V(0, 0.03, 0)
			local p = table.clone(paint)
			p.Name = name
			p.Size = V(1, 0.05, 10)
			p.CFrame = CFrame.lookAt(center, center + back)
			BK.part(F, p)
		end
	end
	chevron("LaneChevron", V(0, 0, -172), V(0, 0, 1))
	chevron("LaneChevron", V(0, 0, -156), V(0, 0, 1))
	for x = 20, 100, 20 do
		chevron("LaneChevron", V(x, 0, -150), V(1, 0, 0))
	end
	-- The pedestrian lane, 6 wide: from the south entrance along Z -80 (its south edge at Z -78, D-101) west to
	-- X -105, then north along X -105 to Z -144 and west to the stair's foot. Dashes 3 long every 6.
	local function dashes(a, b, name)
		local dir = (b - a).Unit
		local length = (b - a).Magnitude
		for d = 0, length - 3, 6 do
			local center = a + dir * (d + 1.5)
			local p = table.clone(paint)
			p.Name = name
			p.Size = V(0.4, 0.05, 3)
			p.CFrame = CFrame.lookAt(center + V(0, 0.03, 0), center + V(0, 0.03, 0) + dir)
			BK.part(F, p)
		end
	end
	dashes(V(-3, 0, -78), V(-102, 0, -78), "LaneEdge")
	dashes(V(-3, 0, -84), V(-108, 0, -84), "LaneEdge")
	dashes(V(-102, 0, -84), V(-102, 0, -141), "LaneEdge")
	dashes(V(-108, 0, -87), V(-108, 0, -141), "LaneEdge")
	BK.floorText(F, "LaneText1", V(-50, 0, -81), Vector2.new(14, 1.6), "PEDESTRIANS", { textUp = V(-1, 0, 0) })
	BK.floorText(F, "LaneText2", V(-105, 0, -120), Vector2.new(14, 1.6), "PEDESTRIANS", { textUp = V(0, 0, -1) })
end

-- The control booth (§6): on the south wall's inner face, X 40..80, Z -78..-72, Y 18..28, a glass front with
-- mullions, two consoles and a chair (T3 sits in it, Config/NPCs), lit inside, on two brackets. No access.
function Builder.booth(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local S = ctx.Structure
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	BK.box(S, "Booth_Floor", V(40, 17, -78), V(80, 18, -71.5), steel)
	BK.box(S, "Booth_Roof", V(40, 28, -78), V(80, 29, -71.5), steel)
	for _, x in ipairs({ 40, 79.5 }) do
		BK.box(S, "Booth_Side", V(x, 18, -78), V(x + 0.5, 28, -71.5), { Color = P.WALL_INTERIOR })
	end
	BK.box(S, "Booth_Glass", V(40.5, 18.8, -78), V(79.5, 27.6, -77.8), { Color = P.GLASS, Material = "Glass", Transparency = 0.55, CastShadow = false })
	BK.box(S, "Booth_Sill", V(40.5, 18, -78.2), V(79.5, 18.8, -77.6), steel)
	BK.box(S, "Booth_Head", V(40.5, 27.6, -78.2), V(79.5, 28, -77.6), steel)
	for x = 44.4, 76, 4.4 do
		BK.box(S, "Booth_Mullion", V(x - 0.15, 18.8, -78.15), V(x + 0.15, 27.6, -77.65), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	end
	for i, x in ipairs({ 44, 76 }) do
		BK.triangle(S, "Booth_Bracket" .. i, V(x, 17, -71.5), V(0, -6, 0), V(0, 0, -6), 1, { Color = P.STEEL_DARK, Material = "Metal" })
	end
	-- Inside: two consoles at the glass, operators facing north; a chair; a lamp.
	local F = ctx.Props
	for i, x in ipairs({ 50, 66 }) do
		Lib.Console(F, CFrame.new(x, 18, -76.4) * Lib.FACE["+Z"], { name = "Booth_Console" .. i, seed = 90 + i, lines = { "HANGAR CONTROL", "DOOR E · SEALED", "CRANE · AUTO" } })
	end
	Lib.Chair(F, CFrame.new(50, 18, -73.6), { name = "Booth_Chair" })
	local lamp = BK.box(ctx.Lighting, "Booth_Lamp", V(59.5, 27.6, -75.5), V(60.5, 27.9, -74.5), { Color = P.LIGHT_NEUTRAL, Material = "Neon", CanCollide = false, CastShadow = false })
	BK.light(lamp, "Point", { Color = P.LIGHT_NEUTRAL, Brightness = 0.8, Range = 14, Tags = { "HubLight" } })
	BK.sign(ctx.Detail, "Booth_Sign", BK.lookAlong(V(60, 28.7, -78.25), V(0, 0, -1)), Vector2.new(10, 1.2), "HANGAR CONTROL", { light = true })
end

function Builder.props(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	-- Tool carts (6).
	for i, at in ipairs({ { -60, -172 }, { -95, -172 }, { 60, -179 }, { 95, -172 }, { -40, -100 }, { 40, -95 } }) do
		Lib.ToolCart(F, CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, math.rad((i * 37) % 30 - 15), 0), { name = "ToolCart" .. i, seed = i })
	end
	-- Crate stacks: two on the west between the pilasters (clear of the lane), four on the east at Z -82 (clear of the
	-- cabinets' cables), two by the east wall.
	local stacks = { { -95, -75.6 }, { -65, -75.6 }, { 26, -82 }, { 50, -82 }, { 70, -82 }, { 104, -82 }, { 110, -110 }, { 110, -90 } }
	for i, s in ipairs(stacks) do
		local turn = if s[1] >= 110 then Lib.FACE["-X"] else CFrame.identity
		Lib.CrateStack(F, CFrame.new(s[1], 0, s[2]) * turn, { name = "CrateStack" .. i, seed = i * 7, count = 3 + i % 3 })
	end
	-- The plate rack, coolant tanks under the back walkway.
	Lib.PlateRack(F, CFrame.new(-104, 0, -176) * Lib.FACE["+X"], { name = "PlateRack", plates = 3 })
	for i, at in ipairs({ { 108, -220 }, { 114, -214 }, { 102, -214 }, { -108, -220 }, { -102, -214 }, { -114, -214 } }) do
		Lib.CoolantTank(F, CFrame.new(at[1], 0, at[2]) * Lib.FACE["+Z"], { name = "CoolantTank" .. i })
	end
	-- Power cabinets against the south wall and their cable runs to the bays.
	for i, c in ipairs({ { -35, -70 }, { 35, 0 }, { 95, 70 } }) do
		local x, bayX = c[1], c[2]
		Lib.PowerCabinet(F, CFrame.new(x, 0, -73.1), { name = "PowerCabinet" .. i })
		local turn = V(x, 0, -92)
		Lib.CableRun(F, V(x, 0, -74.8), turn, { name = "Cables" .. i .. "a" })
		Lib.CableRun(F, turn, V(bayX + (if bayX < x then 26 else -26), 0, -180), { name = "Cables" .. i .. "b" })
	end
	-- The forklift on its loop (an ambient mover: the client drives it along Path, 6 studs/s, 3 s at the corners).
	Lib.Forklift(F, CFrame.new(-80, 0, -120) * Lib.FACE["+X"], {
		name = "Forklift", attributes = { Path = "-80,-120;-30,-120;-30,-95;-80,-95", Speed = 6, Pause = 3 },
	})
	-- The mobile staircase beside Bay 3.
	Lib.MobileStair(F, CFrame.new(41.6, 0, -190), { name = "MobileStair" })
	-- Extinguisher stations on six pilasters at Y 4.
	for i, x in ipairs({ -110, -80, -20, 20, 80, 110 }) do
		Lib.ExtinguisherStation(F, CFrame.new(x, 4, -73.5), { name = "Extinguisher" .. i })
	end
	-- Hazard bollards on the pedestrian lane's south edge, every 16 (just inside it, clear of the crate stacks).
	for i, x in ipairs({ -20, -36, -52, -68, -84, -100 }) do
		Lib.Bollard(F, CFrame.new(x, 0, -78.6), { name = "Bollard" .. i })
	end
end

return Builder
