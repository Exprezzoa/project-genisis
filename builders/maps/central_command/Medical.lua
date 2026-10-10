--!nonstrict
-- builders/maps/central_command/Medical.lua  ->  DevTools.Builders.CentralCommand.Medical
-- docs/maps/map_01_central_command.md §8: X 80..130, Z 0..40, ceiling 18. Its roof is the Observation Deck (Y 20).
-- The west wall with the door is the East Corridor's east wall; the north wall is Equipment's divider.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Medical")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

	BK.floor(S, "Floor", 80, 130, 0, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Roof", 80, 130, 0, 40, 18, 2, ctx.ROOF)
	BK.wallZ(S, "Wall_E", 0, 39, 130, 0, 22, C.EXT, ctx.EXT)
	-- South wall: 20 tall where the roof bridge meets the deck (X 80..92), parapet (22) elsewhere.
	BK.wallX(S, "Wall_S_Bridge", 80.5, 92, 40, 0, 20, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_S", 92, 131, 40, 0, 22, C.EXT, ctx.EXT)

	BK.trigger(G, "TRG_MED_ARCH", V(113, 0, 17), V(117, 8, 23), "TRG_MED_ARCH")

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
