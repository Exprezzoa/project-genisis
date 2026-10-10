--!nonstrict
-- builders/maps/central_command/Exterior.lua  ->  DevTools.Builders.CentralCommand.Exterior
-- docs/maps/map_01_central_command.md §13.1. Blockout: the pavement ground of the hub (X -420..420,
-- Z -320..420) and the PlayerBarrier along the perimeter. Roads, fence, gate, motor pool, lamps and
-- flagpoles come with the structure and dressed passes.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Exterior")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

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

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
