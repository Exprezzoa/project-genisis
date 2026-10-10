--!nonstrict
-- builders/maps/hangar/GateCorridor.lua  ->  DevTools.Builders.Hangar.GateCorridor
-- docs/maps/map_02_frame_hangar.md §12: Hangar Gate Corridor X -15..15, Z -70..-40, ceiling 16.
-- Its ends are the openings in the Ops Hall's north wall and the hangar's south wall.

local Builder = {}

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "GateCorridor", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local walls = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }

	BK.floor(S, "Floor", -15, 15, -70, -40, 0, 1, { Color = P.FLOOR_HANGAR, Material = "Concrete" })
	BK.ceiling(S, "Ceiling", -16, 16, -68.5, -41, 16, 1, ctx.CEIL)
	BK.wallZ(S, "Wall_W", -68.5, -41, -15, 0, 16, C.EXT, walls)
	BK.wallZ(S, "Wall_E", -68.5, -41, 15, 0, 16, C.EXT, walls)

	return C.finish(ctx)
end

return Builder
