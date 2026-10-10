--!nonstrict
-- builders/maps/central_command/Research.lua  ->  DevTools.Builders.CentralCommand.Research
-- docs/maps/map_01_central_command.md §10: Research Corridor X 80..200, Z -60..-48, ceiling 12, locked security
-- door at X 100 (DOOR_RESEARCH); Voss Lab X 200..250, Z -80..-20 (shell only in the Vertical Slice).

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Research")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay
	local white = { Color = P.MEDICAL_WHITE }

	BK.floor(S, "Floor", 80, 200, -60, -48, 0, 1, { Color = "#D5DADE" })
	BK.ceiling(S, "Ceiling", 80, 200, -60, -48, 12, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", 80, 199, -60, 0, 13, C.EXT, white)
	BK.wallX(S, "Wall_S", 80, 199, -48, 0, 13, C.EXT, white)

	-- Security door: steel, 10 x 10, fills the corridor (clear width Z -59..-49), window 3 x 2 at Y 4..6.
	local door = BK.model(G, "DOOR_RESEARCH")
	BK.tag(door, "Door")
	BK.attr(door, { DoorId = "DOOR_RESEARCH", Locked = true, Width = 10, Height = 10 })
	local steel = { Color = P.STEEL_MID, Material = "Metal" }
	local lower = BK.box(door, "Leaf_Lower", V(99.5, 0, -59), V(100.5, 4, -49), steel)
	BK.box(door, "Leaf_Upper", V(99.5, 6, -59), V(100.5, 10, -49), steel)
	BK.box(door, "Leaf_Left", V(99.5, 4, -59), V(100.5, 6, -55.5), steel)
	BK.box(door, "Leaf_Right", V(99.5, 4, -52.5), V(100.5, 6, -49), steel)
	BK.box(door, "Window", V(99.9, 4, -55.5), V(100.1, 6, -52.5), ctx.GLASS)
	BK.box(door, "Lintel", V(99.5, 10, -59), V(100.5, 12, -49), white)
	BK.box(door, "StatusStrip", V(99.35, 10.2, -57), V(99.5, 10.5, -51), { Color = P.DANGER_RED, Material = "Neon", CanCollide = false })
	door.PrimaryPart = lower
	BK.prompt(lower, "INT_RESEARCH_DOOR", "Open")

	-- Voss Lab shell (closed; the interior is Chapter 2).
	BK.floor(S, "Lab_Floor", 200, 250, -80, -20, 0, 1, { Color = "#D5DADE" })
	BK.ceiling(S, "Lab_Roof", 199, 251, -81, -19, 16, 1, ctx.ROOF)
	BK.wallX(S, "Lab_Wall_N", 199, 251, -80, 0, 16, C.EXT, ctx.EXT)
	BK.wallX(S, "Lab_Wall_S", 199, 251, -20, 0, 16, C.EXT, ctx.EXT)
	BK.wallZ(S, "Lab_Wall_W", -79, -21, 200, 0, 16, C.EXT, ctx.EXT)
	BK.wallZ(S, "Lab_Wall_E", -79, -21, 250, 0, 16, C.EXT, ctx.EXT)

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
