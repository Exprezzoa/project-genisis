--!nonstrict
-- builders/maps/central_command/ObservationDeck.lua  ->  DevTools.Builders.CentralCommand.ObservationDeck
-- docs/maps/map_01_central_command.md §7-9: the roof of Equipment and Medical (X 80..130, Z -40..40, Y 20) plus
-- the roof bridge from the stairwell (X 80..92, Z 40..50, deck top Y 20). The deck surface and the parapet
-- walls belong to Equipment, Medical and the East Corridor; this builder adds the bridge and the edge barriers.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "ObservationDeck")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

	BK.floor(S, "Bridge", 81, 92, 41, 50, 20, 1, ctx.DECK)
	BK.railing(S, "BridgeRail", { V(81, 20, 49.85), V(91.85, 20, 49.85), V(91.85, 20, 41) })

	-- Players can jump 7.2 studs, so every edge gets an invisible PlayerBarrier above the parapet or railing.
	BK.barrier(G, "Barrier_N", V(80, 22, -41), V(131, 34, -40), "PlayerBarrier")
	BK.barrier(G, "Barrier_E", V(130, 22, -40), V(131, 34, 40), "PlayerBarrier")
	BK.barrier(G, "Barrier_S", V(92, 22, 40), V(131, 34, 41), "PlayerBarrier")
	BK.barrier(G, "Barrier_W", V(79.5, 22, -40), V(80.5, 34, 39.5), "PlayerBarrier")
	BK.barrier(G, "Barrier_Bridge_E", V(92, 20, 41), V(93, 34, 51), "PlayerBarrier")
	BK.barrier(G, "Barrier_Bridge_S", V(81, 20, 50), V(92, 34, 51), "PlayerBarrier")

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
