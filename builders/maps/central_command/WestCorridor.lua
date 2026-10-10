--!nonstrict
-- builders/maps/central_command/WestCorridor.lua  ->  DevTools.Builders.CentralCommand.WestCorridor
-- docs/maps/map_01_central_command.md §4: X -80..-60, Z -40..40, ceiling 14.
-- The east side is the Ops Hall's west wall (built by OpsHall).

local Builder = {}

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "WestCorridor")
	local BK, S = ctx.BK, ctx.Structure

	BK.floor(S, "Floor", -80, -60, -40, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Ceiling", -80, -60, -40, 40, 14, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", -80.5, -61, -40, 0, 15, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_S", -80.5, -61, 40, 0, 15, C.EXT, ctx.EXT)
	-- West wall: double doors (8 x 9) to Briefing Z -24..-16 and Quarters Z 16..24. 17 tall = Briefing's roof.
	BK.wallWithOpenings(S, "Wall_W", "Z", -39, 39, -80, 0, 17, C.INT, {
		{ from = -24, to = -16, y1 = 0, y2 = C.DOUBLE_H },
		{ from = 16, to = 24, y1 = 0, y2 = C.DOUBLE_H },
	}, ctx.INT)

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
