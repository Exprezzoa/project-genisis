--!nonstrict
-- builders/maps/hangar/Shell.lua  ->  DevTools.Builders.Hangar.Shell
-- docs/maps/map_02_frame_hangar.md §1: footprint X -120..120, Z -230..-70, walls 3 thick, Y 0..90.
-- Blockout: slab, four walls with the three openings, a flat roof, the deployment door (§4, built for S09) and a
-- closed stand-in for the training door.

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

	-- The deployment door (§4): four segments 60 x 17.5 x 3 that telescope up into a header housing on the outside
	-- (segment k to Y 70..87.5 and 3k studs out, 0.3 s apart, 3.0 s each). Each segment carries its open and
	-- closed CFrames; the server's door mover (Server/Sequence/Doors) tweens between them.
	local door = BK.model(S, "DOOR_HANGAR_EAST")
	BK.tag(door, "Door")
	BK.attr(door, { DoorId = "DOOR_HANGAR_EAST" })
	for k = 1, 4 do
		local closed, open = CFrame.new(120, 17.5 * (k - 0.5), -150), CFrame.new(120 + 3 * k, 78.75, -150)
		-- The segment, a rib on its outer face, and on the lowest one the hazard stripe along its bottom; every
		-- piece moves on its own, so each has both CFrames.
		local pieces = {
			{ "Segment" .. k, V(3, 17.5, 60), CFrame.identity, P.STEEL_MID, true },
			{ "Rib" .. k, V(0.4, 0.8, 58), CFrame.new(1.7, 4, 0), P.STEEL_DARK, false },
		}
		if k == 1 then
			table.insert(pieces, { "Hazard", V(0.2, 2, 60), CFrame.new(1.6, -7.75, 0), P.HAZARD_YELLOW, false })
		end
		for _, piece in ipairs(pieces) do
			local part = BK.part(door, {
				Name = piece[1], Size = piece[2], CFrame = closed * piece[3], Color = piece[4], Material = "Metal", CanCollide = piece[5],
			})
			BK.attr(part, { ClosedCFrame = closed * piece[3], OpenCFrame = open * piece[3], Delay = 0.3 * (k - 1), Time = 3.0 })
		end
	end
	BK.box(S, "DoorHousing_E", V(121.5, 68, -182), V(134.5, 90, -118), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	local steel = { Color = P.STEEL_MID, Material = "Metal", Tags = { "Door" } }
	local west = BK.box(S, "DOOR_HANGAR_WEST", V(-121.5, 0, -140), V(-118.5, 70, -80), steel)
	BK.attr(west, { DoorId = "DOOR_HANGAR_WEST", StandIn = true })

	return C.finish(ctx)
end

return Builder
