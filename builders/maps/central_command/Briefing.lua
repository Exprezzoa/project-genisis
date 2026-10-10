--!nonstrict
-- builders/maps/central_command/Briefing.lua  ->  DevTools.Builders.CentralCommand.Briefing
-- docs/maps/map_01_central_command.md §6: X -130..-80, Z -40..0, ceiling 16. Tiered seating facing west.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Briefing")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay

	BK.floor(S, "Floor", -130, -80, -40, 0, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Ceiling", -130, -80, -40, 0, 16, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", -131, -80.5, -40, 0, 17, C.EXT, ctx.EXT)
	BK.wallZ(S, "Wall_W", -39, 0, -130, 0, 17, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_Divider", -129, -80.5, 0, 0, 17, C.INT, ctx.INT) -- shared with Quarters

	-- Tiers: tier 1 is the floor (X -112..-106), tier 2 top Y 1 (X -106..-100), tier 3 top Y 2 (X -100..-94).
	BK.box(S, "Tier2", V(-106, 0, -39), V(-100, 1, -0.5), ctx.FLOOR)
	BK.box(S, "Tier3", V(-100, 0, -39), V(-94, 2, -0.5), ctx.FLOOR)
	-- Two steps up to tier 3 in the center aisle (Z -24..-16); the doc gives the tiers but no way up (D-026).
	BK.stairs(S, "AisleSteps", V(-91, 0, -20), V(-1, 0, 0), 8, 2, { railings = false, stringers = false, material = "SmoothPlastic", color = ctx.FLOOR.Color })

	BK.trigger(G, "TRG_BRIEFING_ENTER", V(-92, 0, -24), V(-82, 10, -16), "TRG_BRIEFING_ENTER")
	BK.camPoint(G, "CAM_BRF_WIDE", V(-92, 9, -20), V(-125, 7, -20))
	BK.camPoint(G, "CAM_BRF_VALE", V(-112, 6.5, -16), V(-122, 6, -20))
	BK.camPoint(G, "CAM_BRF_PILOTS", V(-113, 6, -24), V(-104, 5, -26))

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
