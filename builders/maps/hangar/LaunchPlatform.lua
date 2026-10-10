--!nonstrict
-- builders/maps/hangar/LaunchPlatform.lua  ->  DevTools.Builders.Hangar.LaunchPlatform
-- docs/maps/map_02_frame_hangar.md §8: deck X 123..200, Z -190..-110, top Y 0.5, DiamondPlate #4A4F55.
-- Blockout: the deck only. Chamfered edges, circle marking, "LAUNCH 1" and the masts are structure pass.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "LaunchPlatform", true)
	local BK, S = ctx.BK, ctx.Structure

	BK.box(S, "Deck", V(123, C.GROUND_Y, -190), V(200, 0.5, -110), ctx.DECK)

	return C.finish(ctx)
end

return Builder
