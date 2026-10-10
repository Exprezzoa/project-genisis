--!nonstrict
-- builders/maps/hangar/Catwalks.lua  ->  DevTools.Builders.Hangar.Catwalks
-- docs/maps/map_02_frame_hangar.md §3: deck top Y 28, DiamondPlate STEEL_MID, railings 3.5 tall.
-- Back walkway, 4 side catwalks (8 wide) on 2 columns each, the main stair (28 steps) and the two
-- cockpit access bridges (4 wide). Built in Phase 1 because the nav route to the Bay 2 hatch runs over them.

local Builder = {}

local V = Vector3.new

local Y = 28
local BACK_Z1, BACK_Z2 = -228.5, -224 -- from the north wall's inner face to the walkway edge
local SIDE_Z2 = -186
local SIDE = { { "OuterW", -118, -110 }, { "Bay12", -39, -31 }, { "Bay23", 31, 39 }, { "OuterE", 110, 118 } }
local BRIDGE_Z1, BRIDGE_Z2 = -200, -196
local RAIL = 0.15 -- railings sit this far inside the deck edge

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Catwalks", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }

	BK.floor(S, "BackWalkway", -118.5, 118.5, BACK_Z1, BACK_Z2, Y, 1, ctx.DECK)
	for _, side in ipairs(SIDE) do
		local name, x1, x2 = side[1], side[2], side[3]
		BK.floor(S, "Catwalk_" .. name, x1, x2, BACK_Z2, SIDE_Z2, Y, 1, ctx.DECK)
		-- 2 steel columns (2 x 28 x 2) under the south end.
		BK.box(S, ("Catwalk_%s_ColumnW"):format(name), V(x1, 0, SIDE_Z2 - 3), V(x1 + 2, Y - 1, SIDE_Z2 - 1), steel)
		BK.box(S, ("Catwalk_%s_ColumnE"):format(name), V(x2 - 2, 0, SIDE_Z2 - 3), V(x2, Y - 1, SIDE_Z2 - 1), steel)
	end

	-- Main stair: X -118..-110, from (Z -144, Y 0) north to (Z -186, Y 28).
	BK.stairs(S, "MainStair", V(-114, 0, -144), V(0, 0, -1), 8, Y)

	-- Cockpit access bridges, ending in front of the hatches.
	BK.floor(S, "Bridge_Bay1", -110, -72, BRIDGE_Z1, BRIDGE_Z2, Y, 1, ctx.DECK)
	BK.floor(S, "Bridge_Bay2", -31, -2, BRIDGE_Z1, BRIDGE_Z2, Y, 1, ctx.DECK)

	-- Railings. Back walkway: the open south edge between the catwalk junctions.
	local function rail(name, points)
		for i, p in ipairs(points) do
			points[i] = V(p[1], Y, p[2])
		end
		BK.railing(S, name, points)
	end
	local edge = BACK_Z2 + RAIL
	rail("Rail_Back_1", { { -110, edge }, { -39, edge } })
	rail("Rail_Back_2", { { -31, edge }, { 31, edge } })
	rail("Rail_Back_3", { { 39, edge }, { 110, edge } })
	local south = SIDE_Z2 - RAIL
	-- Outer west: the stair arrives at its south end; the Bay 1 bridge leaves its east edge at Z -200..-196.
	rail("Rail_OuterW_E1", { { -110 - RAIL, BACK_Z2 }, { -110 - RAIL, BRIDGE_Z1 } })
	rail("Rail_OuterW_E2", { { -110 - RAIL, BRIDGE_Z2 }, { -110 - RAIL, SIDE_Z2 } })
	-- Bay 1-2 gap: west edge closed; the Bay 2 bridge leaves its east edge.
	rail("Rail_Bay12_W", { { -39 + RAIL, BACK_Z2 }, { -39 + RAIL, south }, { -31 - RAIL, south } })
	rail("Rail_Bay12_E1", { { -31 - RAIL, BACK_Z2 }, { -31 - RAIL, BRIDGE_Z1 } })
	rail("Rail_Bay12_E2", { { -31 - RAIL, BRIDGE_Z2 }, { -31 - RAIL, south } })
	rail("Rail_Bay23", { { 31 + RAIL, BACK_Z2 }, { 31 + RAIL, south }, { 39 - RAIL, south }, { 39 - RAIL, BACK_Z2 } })
	rail("Rail_OuterE", { { 110 + RAIL, BACK_Z2 }, { 110 + RAIL, south }, { 118 - RAIL, south } })
	-- Bridges: closed on the south side and at the end; the last 4 studs of the north side face the hatch.
	rail("Rail_Bridge1_S", { { -110, BRIDGE_Z2 - RAIL }, { -72 - RAIL, BRIDGE_Z2 - RAIL }, { -72 - RAIL, BRIDGE_Z1 } })
	rail("Rail_Bridge1_N", { { -110, BRIDGE_Z1 + RAIL }, { -76, BRIDGE_Z1 + RAIL } })
	rail("Rail_Bridge2_S", { { -31, BRIDGE_Z2 - RAIL }, { -2 - RAIL, BRIDGE_Z2 - RAIL }, { -2 - RAIL, BRIDGE_Z1 } })
	rail("Rail_Bridge2_N", { { -31, BRIDGE_Z1 + RAIL }, { -6, BRIDGE_Z1 + RAIL } })

	return C.finish(ctx)
end

return Builder
