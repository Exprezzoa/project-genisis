--!nonstrict
-- builders/maps/hangar/Causeway.lua  ->  DevTools.Builders.Hangar.Causeway
-- docs/maps/map_02_frame_hangar.md §8: the causeway from the launch platform to the Bulwark's Frame Gate,
-- X 200..420, Z -175..-125 (50 wide), Concrete CONCRETE_LIGHT, an amber dashed center line and edge lines,
-- FrameBarriers along both edges, and AUTO_CAUSEWAY_END (440, 0, -150), where S10's auto-walk heads.
-- Passes: blockout = the deck, the lines, the barriers; structure = expansion joints; dressed = Jersey
-- barriers along both edges every 6, street lamps every 40 on both sides (lit at EVENING and NIGHT: tag
-- EveningLamp, AmbientController). opts: Common, BK, Props (dressed), pass.

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

	if ctx.level >= 2 then
		-- Expansion joints across the deck every 24.
		for x = 216, 408, 24 do
			BK.box(ctx.Detail, "Joint", V(x - 0.1, TOP - 0.02, -175), V(x + 0.1, TOP + 0.03, -125), { Color = P.CONCRETE_DARK, CanCollide = false, CanQuery = false, CastShadow = false })
		end
	end
	if ctx.level >= 3 then
		local Lib = opts.Props
		-- Jersey barriers along both edges every 6, on the deck's outermost 2 studs (outside the edge lines).
		for x = 203, 417, 6 do
			Lib.JerseyBarrier(ctx.Props, CFrame.new(x, TOP, -174), { name = "Jersey_N" })
			Lib.JerseyBarrier(ctx.Props, CFrame.new(x, TOP, -126) * Lib.FACE["+Z"], { name = "Jersey_S" })
		end
		-- Street lamps every 40 on both sides, outside the barriers, their arms over the deck.
		for x = 220, 380, 40 do
			Lib.StreetLamp(ctx.Props, CFrame.new(x, -0.1, -177.8) * Lib.FACE["+Z"], { name = "Lamp_N", lightTags = { "EveningLamp", "HubLight" } })
			Lib.StreetLamp(ctx.Props, CFrame.new(x + 20, -0.1, -122.2), { name = "Lamp_S", lightTags = { "EveningLamp", "HubLight" } })
		end
	end
	return C.finish(ctx)
end

return Builder
