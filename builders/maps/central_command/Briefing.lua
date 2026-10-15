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

	-- Stand-ins: a bench on each tier in both blocks either side of the aisle (docs/07 §6 Bench: 1.8 tall, 1.6
	-- deep; one per block here) and the lectern Vale stands behind (map_01 §6; its size is ours, D-081).
	for _, tier in ipairs({ { -109, 0 }, { -103, 1 }, { -97, 2 } }) do
		local x, y = tier[1], tier[2]
		for index, block in ipairs({ { -36, -24 }, { -16, -4 } }) do
			C.standIn(ctx, ("Bench_X%d_%d_StandIn"):format(-x, index), V(x - 0.8, y, block[1]), V(x + 0.8, y + 1.8, block[2]), { Color = ctx.P.FABRIC_DARK })
		end
	end
	C.standIn(ctx, "Lectern_StandIn", V(-122.75, 0, -21), V(-121.25, 3.6, -19), { Color = ctx.P.STEEL_DARK })
	-- The slide screen on the west wall (Z -35..-5, Y 3..13, its +X face toward the seats). Each client draws
	-- the slides on it (Client/UI/BriefingScreen); the base is docs/07 §6's screen color.
	BK.part(G, {
		Name = "BriefingScreen", Size = V(0.2, 10, 30), CFrame = CFrame.new(-128.9, 8, -20), Color = "#1B2A33",
		Material = "SmoothPlastic", CanCollide = false, CastShadow = false,
	})

	BK.trigger(G, "TRG_BRIEFING_ENTER", V(-92, 0, -24), V(-82, 10, -16), "TRG_BRIEFING_ENTER")
	BK.camPoint(G, "CAM_BRF_WIDE", V(-92, 9, -20), V(-125, 7, -20))
	BK.camPoint(G, "CAM_BRF_VALE", V(-112, 6.5, -16), V(-122, 6, -20))
	BK.camPoint(G, "CAM_BRF_PILOTS", V(-113, 6, -24), V(-104, 5, -26))

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
