--!nonstrict
-- builders/maps/central_command/EastCorridor.lua  ->  DevTools.Builders.CentralCommand.EastCorridor
-- docs/maps/map_01_central_command.md §9: X 60..80, Z -60..40, ceiling 14, plus the stairwell X 60..80, Z 40..62.
-- The west side (Z -40..40) is the Ops Hall's east wall (built by OpsHall).
--
-- Stairwell: the doc's layout can't be built (the exit door at Z 42..50 would open beside the upper flight,
-- its 2-deep landings are narrower than the nav capsule, and NAV_STAIR_B sits inside a step). Provisional
-- layout until Q-009 is answered. Kept from the doc: the door from the corridor, the exit door, the roof
-- bridge, two flights of 10 steps running south then north. Changed: the stairwell is 2 studs deeper
-- (Z 40..62); the flights are 6 wide (flight 1 at X 67..73 in line with the door, flight 2 at X 61..67);
-- the landing is 3.5 deep; a gallery at Y 20 leads from the top landing along the north and east walls
-- to the exit door.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "EastCorridor")
	local BK, S = ctx.BK, ctx.Structure

	-- Corridor
	BK.floor(S, "Floor", 60, 80, -60, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Ceiling", 60, 80, -60, 40, 14, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", 59, 80, -60, 0, 15, C.EXT, ctx.EXT)
	BK.wallZ(S, "Wall_W_North", -59, -41, 60, 0, 15, C.EXT, ctx.EXT)
	BK.wallZ(S, "Wall_E_North", -48, -41, 80, 0, 15, C.EXT, ctx.EXT) -- north of it the Research Corridor opens
	-- East wall: double doors to Equipment Z -24..-16 and Medical Z 16..24. 22 tall = the deck's parapet.
	BK.wallWithOpenings(S, "Wall_E", "Z", -39, 39.5, 80, 0, 22, C.INT, {
		{ from = -24, to = -16, y1 = 0, y2 = C.DOUBLE_H },
		{ from = 16, to = 24, y1 = 0, y2 = C.DOUBLE_H },
	}, ctx.INT)
	-- South wall with the stairwell door (X 66..74); above the corridor it is the stairwell's north wall.
	BK.wallWithOpenings(S, "Wall_S", "X", 61, 80.5, 40, 0, 31, C.INT, { { from = 66, to = 74, y1 = 0, y2 = C.DOUBLE_H } }, ctx.INT)

	-- Stairwell shell (Z 40..62)
	BK.floor(S, "Stair_Floor", 60, 80, 40, 62, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Stair_Roof", 59, 81, 39.5, 63, 30, 1, ctx.ROOF)
	BK.wallZ(S, "Stair_Wall_W", 41, 61, 60, 0, 30, C.EXT, ctx.EXT)
	BK.wallX(S, "Stair_Wall_S", 59, 81, 62, 0, 30, C.EXT, ctx.EXT)
	-- East wall with the exit door to the roof bridge (Z 42..50, Y 20..28).
	BK.wallWithOpenings(S, "Stair_Wall_E", "Z", 40.5, 61, 80, 0, 30, C.EXT, { { from = 42, to = 50, y1 = 20, y2 = 28 } }, ctx.EXT)

	-- Flight 1: X 67..73, from (Z 42.5, Y 0) south to (Z 57.5, Y 10). Landing Z 57.5..61.
	BK.stairs(S, "Flight1", V(70, 0, 42.5), V(0, 0, 1), 6, 10)
	BK.floor(S, "Landing", 61, 73, 57.5, 61, 10, 1, ctx.DECK)
	BK.railing(S, "LandingRail", { V(72.85, 10, 57.5), V(72.85, 10, 61) })
	-- Flight 2: X 61..67, from (Z 57.5, Y 10) north to (Z 42.5, Y 20). The west side is the wall. The east
	-- railing starts one tread in (a sloped railing's collider would lean 1.25 studs over the landing) and
	-- stops 3 studs short of the top, where the gallery begins.
	local flight2 = BK.stairs(S, "Flight2", V(64, 10, 57.5), V(0, 0, -1), 6, 10, { railings = false })
	BK.railing(flight2, "Flight2_RailE", { V(66.85, 12, 56), V(66.85, 19, 45.5) }, { sink = 1 })
	-- Top landing and gallery at Y 20.
	BK.floor(S, "TopLanding", 61, 67, 40.5, 42.5, 20, 1, ctx.DECK)
	BK.floor(S, "Gallery_N", 67, 79, 40.5, 46, 20, 1, ctx.DECK)
	BK.floor(S, "Gallery_E", 74, 79, 46, 51, 20, 1, ctx.DECK)
	BK.railing(S, "GalleryRail", { V(67.15, 20, 45.85), V(74.15, 20, 45.85), V(74.15, 20, 50.85), V(79, 20, 50.85) })

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
