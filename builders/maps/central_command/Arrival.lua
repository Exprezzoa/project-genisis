--!nonstrict
-- builders/maps/central_command/Arrival.lua  ->  DevTools.Builders.CentralCommand.Arrival
-- docs/maps/map_01_central_command.md §11: Concourse X -10..10, Z 40..80 (ceiling 14, glass side walls) and the
-- Arrival Platform X -80..80, Z 80..130 with its canopy at Y 18 on 6 columns.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Arrival")
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure

	BK.floor(S, "Concourse_Floor", -10, 10, 40, 80, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Concourse_Ceiling", -10.25, 10.25, 41, 80, 14, 1, ctx.CEIL)
	BK.wallZ(S, "Concourse_Glass_W", 41, 80, -10, 0, 14, 0.5, ctx.GLASS)
	BK.wallZ(S, "Concourse_Glass_E", 41, 80, 10, 0, 14, 0.5, ctx.GLASS)

	local concrete = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	BK.floor(S, "Platform", -80, 80, 80, 130, 0, 1, concrete)
	BK.ceiling(S, "Canopy", -80, 80, 84, 128, 18, 1, ctx.ROOF)
	for _, x in ipairs({ -60, 0, 60 }) do
		for _, z in ipairs({ 88, 124 }) do
			BK.column(S, ("CanopyColumn_%d_%d"):format(x + 60, z), V(x, 0, z), 18, 2)
		end
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
