--!nonstrict
-- builders/maps/central_command/Quarters.lua  ->  DevTools.Builders.CentralCommand.Quarters
-- docs/maps/map_01_central_command.md §5: X -130..-80, Z 0..40, ceiling 12. Hallway Z 16..24, six rooms;
-- only Q-3 (X -128..-112, Z 0..16) is enterable in Chapter 1.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Quarters")
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure

	BK.floor(S, "Floor", -130, -80, 0, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Ceiling", -130, -80, 0, 40, 12, 1, ctx.CEIL)
	BK.wallX(S, "Wall_S", -131, -80.5, 40, 0, 13, C.EXT, ctx.EXT)
	-- West exterior wall with Q-3's window slit (Z 6..12, Y 6..7.5).
	BK.wallWithOpenings(S, "Wall_W", "Z", 0, 39, -130, 0, 13, C.EXT, { { from = 6, to = 12, y1 = 6, y2 = 7.5 } }, ctx.EXT)
	local window = BK.box(S, "Q3_Window", V(-130.1, 6, 6), V(-129.9, 7.5, 12), ctx.GLASS)

	-- Hallway walls. Blockout cuts only Q-3's door (X -122..-117); the other rooms get closed doors later.
	BK.wallWithOpenings(S, "Hall_N", "X", -129, -80.5, 16, 0, 12, C.INT, { { from = -122, to = -117, y1 = 0, y2 = C.DOOR_H } }, ctx.INT)
	BK.wallX(S, "Hall_S", -129, -80.5, 24, 0, 12, C.INT, ctx.INT)
	for _, x in ipairs({ -96, -112 }) do
		BK.wallZ(S, ("Divider_N_%d"):format(-x), 0.5, 15.5, x, 0, 12, C.INT, ctx.INT)
		BK.wallZ(S, ("Divider_S_%d"):format(-x), 24.5, 39, x, 0, 12, C.INT, ctx.INT)
	end

	-- Q-3 stand-ins (desk, photo, terminal, locker, bunk) so the prompts and the floor plan can be tested.
	C.standIn(ctx, "Q3_Desk_StandIn", V(-120.5, 0, 0.5), V(-115.5, 2.8, 3))
	local photo = C.standIn(ctx, "Q3_Photo_StandIn", V(-120, 2.8, 1.15), V(-119.2, 3.8, 1.25), { Color = "#3A2A1E" })
	BK.prompt(photo, "INT_Q3_PHOTO", "Look")
	local terminal = C.standIn(ctx, "Q3_Terminal_StandIn", V(-118.3, 2.8, 1.25), V(-116.5, 4.2, 1.55), { Color = P.STEEL_DARK })
	BK.prompt(terminal, "INT_Q3_TERMINAL", "Read", { enabled = false }) -- S43 only
	local locker = C.standIn(ctx, "Q3_Locker_StandIn", V(-124.5, 0, 0.5), V(-122.5, 7, 2.5), { Color = P.SLATE })
	BK.prompt(locker, "INT_Q3_LOCKER", "Take", { once = true })
	C.standIn(ctx, "Q3_Bunk_StandIn", V(-127.25, 0, 5.5), V(-123.75, 2, 12.5), { Color = P.FABRIC_DARK })
	BK.prompt(window, "INT_Q3_WINDOW", "Look")

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

return Builder
