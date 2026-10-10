--!nonstrict
-- builders/maps/hangar/Shell.lua  ->  DevTools.Builders.Hangar.Shell
-- docs/maps/map_02_frame_hangar.md §1: footprint X -120..120, Z -230..-70, walls 3 thick, Y 0..90.
-- Blockout: slab, four walls with the three openings, a flat roof, and closed stand-ins for the two big doors.

local Builder = {}

local V = Vector3.new

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Shell", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local T = C.HANGAR

	BK.floor(S, "Floor", -120, 120, -230, -70, 0, 1, { Color = P.FLOOR_HANGAR, Material = "Concrete" })
	BK.ceiling(S, "Roof", -121.5, 121.5, -231.5, -68.5, 90, 2, { Color = "#5A5F66", Material = "Metal" })

	BK.wallX(S, "Wall_N", -121.5, 121.5, -230, 0, 90, T, ctx.EXT)
	-- South: the human entrance X -15..15, Y 0..16.
	BK.wallWithOpenings(S, "Wall_S", "X", -121.5, 121.5, -70, 0, 90, T, { { from = -15, to = 15, y1 = 0, y2 = 16 } }, ctx.EXT)
	-- East: the deployment door Z -180..-120, Y 0..70. West: the training door Z -140..-80, Y 0..70.
	BK.wallWithOpenings(S, "Wall_E", "Z", -228.5, -71.5, 120, 0, 90, T, { { from = -180, to = -120, y1 = 0, y2 = 70 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_W", "Z", -228.5, -71.5, -120, 0, 90, T, { { from = -140, to = -80, y1 = 0, y2 = 70 } }, ctx.EXT)

	-- Closed door stand-ins (the 4-segment telescoping doors of §4 come with the deployment work).
	local steel = { Color = P.STEEL_MID, Material = "Metal", Tags = { "Door" } }
	local east = BK.box(S, "DOOR_HANGAR_EAST", V(118.5, 0, -180), V(121.5, 70, -120), steel)
	BK.attr(east, { DoorId = "DOOR_HANGAR_EAST", StandIn = true })
	local west = BK.box(S, "DOOR_HANGAR_WEST", V(-121.5, 0, -140), V(-118.5, 70, -80), steel)
	BK.attr(west, { DoorId = "DOOR_HANGAR_WEST", StandIn = true })

	return C.finish(ctx)
end

return Builder
