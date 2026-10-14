--!nonstrict
-- builders/maps/hangar/Causeway.lua  ->  DevTools.Builders.Hangar.Causeway
-- docs/maps/map_02_frame_hangar.md §8: the causeway from the launch platform to the Bulwark's Frame Gate,
-- X 200..420, Z -175..-125 (50 wide), Concrete CONCRETE_LIGHT, an amber dashed center line and edge lines,
-- FrameBarriers along both edges, and AUTO_CAUSEWAY_END (440, 0, -150), where S10's auto-walk heads.
-- Blockout plus the painted lines; the Jersey barriers and street lamps are dressed pass.

local Builder = {}

local V = Vector3.new

local TOP = 0.5 -- level with the launch platform's deck

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Causeway", true)
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay

	BK.box(S, "Deck", V(200, C.GROUND_Y - 1, -175), V(420, TOP, -125), { Color = P.CONCRETE_LIGHT, Material = "Concrete" })
	local paint = { CanCollide = false, CanQuery = false, CastShadow = false }
	local edge = table.clone(paint)
	edge.Color = P.ROAD_LINE
	BK.box(S, "EdgeLine_N", V(200, TOP, -173), V(420, TOP + 0.05, -172), edge)
	BK.box(S, "EdgeLine_S", V(200, TOP, -128), V(420, TOP + 0.05, -127), edge)
	local dash = table.clone(paint)
	dash.Color = P.AMBER
	for x = 204, 412, 16 do
		BK.box(S, "CenterDash", V(x, TOP, -150.5), V(x + 8, TOP + 0.05, -149.5), dash)
	end
	-- A Frame stays on the causeway (a Frame's root floats 22 up: barriers as tall as the outpost's, Layout.BARRIER_TOP).
	BK.barrier(G, "FrameBarrier_Causeway_N", V(200, 0, -177), V(420, 60, -175), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_Causeway_S", V(200, 0, -125), V(420, 60, -123), "FrameBarrier")
	BK.spawnPoint(G, "AUTO_CAUSEWAY_END", BK.lookAlong(V(440, 0, -150), V(1, 0, 0)))

	return C.finish(ctx)
end

return Builder
