--!nonstrict
-- builders/maps/central_command/OpsHall.lua  ->  DevTools.Builders.CentralCommand.OpsHall
-- docs/maps/map_01_central_command.md §3: X -60..60, Z -40..40, ceiling Y 36, roof top Y 38, mezzanine Y 16.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "OpsHall")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay

	BK.floor(S, "Floor", -60, 60, -40, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Roof", -61, 61, -41, 41, 36, 2, ctx.ROOF)

	-- North and south walls are exterior (2 thick) and own the corners; west and east are 1 thick
	-- (the doc puts the posters at X ±59.4, just proud of a wall face at ±59.5).
	BK.wallWithOpenings(S, "Wall_N", "X", -61, 61, -40, 0, 36, C.EXT, { { from = -15, to = 15, y1 = 0, y2 = 14 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_S", "X", -61, 61, 40, 0, 36, C.EXT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_W", "Z", -39, 39, -60, 0, 36, C.INT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.INT)
	BK.wallWithOpenings(S, "Wall_E", "Z", -39, 39, 60, 0, 36, C.INT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.INT)

	-- Mezzanine (floor top Y 16) with its two stairs: 16 steps along X in the lane Z -24..-18.
	BK.floor(S, "Mezzanine", -59.5, 59.5, -39, -24, 16, 1, ctx.FLOOR)
	for _, side in ipairs({ { "W", -1 }, { "E", 1 } }) do
		local name, sx = side[1], side[2]
		BK.stairs(S, "MezzStair_" .. name, V(sx * 30, 0, -21), V(sx, 0, 0), 6, 16)
		BK.floor(S, "MezzLanding_" .. name, math.min(sx * 54, sx * 59.5), math.max(sx * 54, sx * 59.5), -24, -18, 16, 1, ctx.FLOOR)
		BK.railing(S, "MezzLandingRail_" .. name, { V(sx * 59.5, 16, -18.15), V(sx * 54, 16, -18.15) })
	end
	BK.railing(S, "MezzRail", { V(-54, 16, -24.15), V(54, 16, -24.15) })

	-- Offices on the mezzanine, Z -40..-30 behind a glass front at Z -30 (partitions 10 tall; D-026).
	local frosted = { Color = "#C9D3DA", Material = "Glass", Transparency = 0.3 }
	local function office(name, x1, x2, doorFrom, doorTo, glass)
		BK.wallWithOpenings(S, name .. "_Front", "X", x1, x2, -30, 16, 26, 0.5, { { from = doorFrom, to = doorTo, y1 = 16, y2 = 16 + C.DOOR_H } }, glass)
		BK.wallZ(S, name .. "_SideW", -39, -30, x1, 16, 26, C.INT, ctx.INT)
		BK.wallZ(S, name .. "_SideE", -39, -30, x2, 16, 26, C.INT, ctx.INT)
	end
	office("Office_W", -56, -24, -42.5, -37.5, frosted)
	office("Office_Vale", -20, 20, -2.5, 2.5, ctx.GLASS) -- doc: gap X -2..2; widened to 5 (acceptance test 2)
	office("Office_E", 24, 56, 37.5, 42.5, frosted)

	-- 4 freestanding columns 3 x 36 x 3.
	for i, at in ipairs({ V(-46, 0, -12), V(46, 0, -12), V(-46, 0, 34), V(46, 0, 34) }) do
		BK.column(S, "Column_" .. i, at, 36, 3)
	end

	-- Stand-ins for the props that carry prompts or block the floor (replaced by Props in later passes).
	local holo = BK.cyl(G, {
		Name = "HoloTable_StandIn",
		Axis = "Y",
		Size = V(20, 3.2, 20),
		Position = V(0, 1.6, 0),
		Color = P.STEEL_DARK,
		Attributes = { StandIn = true },
	})
	BK.prompt(holo, "INT_HOLO", "Look", { dist = 16 }) -- measured from the table's center (radius 10)
	local kiosk = C.standIn(ctx, "StatusKiosk_StandIn", V(-1, 0, -20.5), V(1, 3.5, -19.5))
	BK.prompt(kiosk, "INT_STATUS_WALL", "Look")
	local poster = C.standIn(ctx, "Poster_StandIn", V(-59.5, 4, 18.5), V(-59.4, 8, 21.5), { Color = P.SLATE_DEEP })
	BK.prompt(poster, "INT_POSTER", "Look")
	-- Consoles C1-C8 facing north, a chair behind each (docs/07 §6: Console 6 x 3 x 2.5, Chair 2 x 3.6 x 2; the seat
	-- 1.0 up is ours, so seated feet reach the floor). The seated NPCs sit on these chairs (Config/NPCs; D-081).
	local consoles = { { "C1", -36, 14 }, { "C2", -24, 14 }, { "C3", 24, 14 }, { "C4", 36, 14 }, { "C5", -36, 26 }, { "C6", -24, 26 }, { "C7", 24, 26 }, { "C8", 36, 26 } }
	for _, c in ipairs(consoles) do
		local name, x, z = c[1], c[2], c[3]
		C.standIn(ctx, "Console_" .. name .. "_StandIn", V(x - 3, 0, z - 1.25), V(x + 3, 3, z + 1.25), { Color = P.STEEL_DARK })
		C.standIn(ctx, "Chair_" .. name .. "_StandIn", V(x - 1, 0, z + 2), V(x + 1, 1.0, z + 4), { Color = P.FABRIC_DARK })
		C.standIn(ctx, "ChairBack_" .. name .. "_StandIn", V(x - 1, 1.0, z + 3.7), V(x + 1, 3.6, z + 4), { Color = P.FABRIC_DARK })
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
