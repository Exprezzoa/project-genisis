--!nonstrict
-- builders/maps/central_command/Equipment.lua  ->  DevTools.Builders.CentralCommand.Equipment
-- docs/maps/map_01_central_command.md §7: X 80..130, Z -40..0, ceiling 18. Its roof is the Observation Deck (Y 20).
-- The west wall with the door is the East Corridor's east wall.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Equipment")
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure

	BK.floor(S, "Floor", 80, 130, -40, 0, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Roof", 80, 130, -40, 0, 18, 2, ctx.ROOF) -- top Y 20 = deck surface
	BK.wallX(S, "Wall_N", 80.5, 131, -40, 0, 22, C.EXT, ctx.EXT) -- 22 = parapet top
	BK.wallZ(S, "Wall_E", -39, 0, 130, 0, 22, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_Divider", 80.5, 129, 0, 0, 18, C.INT, ctx.INT) -- shared with Medical

	-- Counter X 112..116, Z -34..-6, 2.8 tall; the Equipment Terminal behind it at (126, 0, -20), facing west.
	C.standIn(ctx, "Counter_StandIn", V(112, 0, -34), V(116, 2.8, -6))
	local terminal = C.standIn(ctx, "EquipTerminal_StandIn", V(124.75, 0, -23), V(127.25, 3, -17), { Color = P.STEEL_DARK })
	-- Enabled since Phase 6 (upgrades). The console stands behind the counter, so it reaches across it (D-097).
	BK.prompt(terminal, "INT_EQUIP_TERMINAL", "Use", { dist = 18, lineOfSight = false })

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
