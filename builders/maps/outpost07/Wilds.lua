--!nonstrict
-- builders/maps/outpost07/Wilds.lua  ->  DevTools.Builders.Outpost07.Wilds
-- docs/maps/map_03_outpost_07.md §11-14: the trail from the North Gate, Kessler Basin (the arena), the East
-- Ridge with the Watcher's route, and the rover crash site with Pad B.
--
-- BLOCKOUT pass, like Compound: right sizes and places, collisions, markers, cameras, triggers, barriers,
-- prompts on stand-ins. No props.
--
--   Builder.Build({ BK = BK, Common = Common, Layout = Layout, pass = "blockout", areas = { "Basin" } })

local Builder = {}

Builder.AREAS = { "Trail", "Basin", "Ridge" }

-- map_03 §11: the trail's centerline. TR4 is the top of the basin ramp, TR5 its foot.
Builder.TRAIL = { { 0, 0, -165 }, { 18, 0, -215 }, { -8, 0, -270 }, { 12, 0, -325 }, { 0, 0, -390 }, { 0, -12, -440 } }
Builder.TRAIL_HALF_WIDTH = 55 -- FrameBarriers this far to each side of the centerline
-- map_03 §13: the Watcher's route.
Builder.WATCHER = {
	W0 = { 290, 30, -560, { "W1", "W4" } }, W1 = { 250, 25, -575, { "W0", "W2" } }, W2 = { 205, 1, -590, { "W1", "W3" } },
	W3 = { 172, -12, -598, { "W2" } }, W4 = { 300, 30, -560, { "W0", "W5" } }, W5 = { 460, 37, -560, { "W4" } },
}
-- map_03 §12: blocking rock formations { name, x, z, sizeX, height, sizeZ }, standing on the basin floor.
Builder.ROCKS = {
	{ "RF1", -140, -480, 30, 28, 24 }, { "RF2", 70, -470, 26, 32, 22 }, { "RF3", 110, -690, 34, 36, 26 }, { "RF4", -30, -680, 28, 30, 24 },
}

local FLOOR_Y = -12
local areas = {}

function areas.Trail(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	local nodes = Builder.TRAIL
	local dirt = { Color = "#5A5244", Material = "Ground" }
	local travelled, nextPrint, side = 0, 14, 1
	for index = 1, 4 do
		local a, b = nodes[index], nodes[index + 1]
		local from, to = T.W(a[1], -0.1, a[2 + 1]), T.W(b[1], -0.1, b[2 + 1])
		BK.beam(S, "Trail" .. index, from, to, 30, 0.3, dirt)
		-- Frames stay within 55 studs of the centerline.
		local along = Vector3.new(b[1] - a[1], 0, b[3] - a[3])
		local right = Vector3.new(-along.Z, 0, along.X).Unit * Builder.TRAIL_HALF_WIDTH
		T.wall(("FrameBarrier_Trail%d_E"):format(index), a[1] + right.X, a[3] + right.Z, b[1] + right.X, b[3] + right.Z)
		T.wall(("FrameBarrier_Trail%d_W"):format(index), a[1] - right.X, a[3] - right.Z, b[1] - right.X, b[3] - right.Z)
		-- Bounds warnings in the outer 15 studs (boxes along the axes, so a little generous on a slanting stretch).
		local lowX, highX = math.min(a[1], b[1]), math.max(a[1], b[1])
		T.trigger(("TRG_OOB_TRAIL%d_E"):format(index), highX + 40, b[3], highX + 55, a[3])
		T.trigger(("TRG_OOB_TRAIL%d_W"):format(index), lowX - 55, b[3], lowX - 40, a[3])
		-- The Watcher's footprints go on up the trail: one every 28 studs, 5 to either side of the centerline.
		local length = along.Magnitude
		while nextPrint <= travelled + length do
			local at = Vector3.new(a[1], 0, a[3]) + along.Unit * (nextPrint - travelled) + Vector3.new(-along.Z, 0, along.X).Unit * 5 * side
			BK.part(S, {
				Name = "WatcherFootprint", Size = Vector3.new(7, 0.1, 14), CFrame = BK.lookAlong(T.W(at.X, 0.12, at.Z), along),
				Color = P.STEEL_DARK, CanCollide = false, CanQuery = false, CastShadow = false,
			})
			nextPrint += 28
			side = -side
		end
		travelled += length
	end
	for index, node in ipairs(nodes) do
		local links = {}
		if index > 1 then
			table.insert(links, "TR" .. (index - 2))
		end
		if index < #nodes then
			table.insert(links, "TR" .. index)
		end
		T.node("TR" .. (index - 1), node[1], node[2], node[3], links)
	end
	T.trigger("TRG_TRAIL_1", -60, -205, 60, -195)
	T.trigger("TRG_TRAIL_2", -60, -305, 60, -295)
	T.trigger("TRG_TRAIL_3", -60, -375, 60, -365)
end

function areas.Basin(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	local mud = { Color = P.MUD_DRY, Material = "Mud" }
	T.slab(S, "Floor", -186, 182, -724, -424, FLOOR_Y, 4, mud)
	-- The ramp down from the trail (X -30..30, Z -390 -> -438, 14 degrees) between two wing walls, and the
	-- embankment to either side of it.
	T.slope(S, "Ramp", "Z", -30, 30, -390, -438, 0, FLOOR_Y, T.CONCRETE_DARK)
	T.box(S, "RampWall_W", -32, FLOOR_Y, -424, -30, 1, -390, T.CONCRETE)
	T.box(S, "RampWall_E", 30, FLOOR_Y, -424, 32, 1, -390, T.CONCRETE)
	T.slope(S, "Embankment_W", "Z", -186, -32, -400, -424, 0, FLOOR_Y, T.ROCK)
	T.slope(S, "Embankment_E", "Z", 32, 182, -400, -424, 0, FLOOR_Y, T.ROCK)
	-- The dam (west), the cliffs (north), the intake tower and the four rock formations: everything that blocks.
	T.box(S, "Dam", -200, FLOOR_Y, -724, -186, 18, -424, T.CONCRETE_DARK)
	T.box(S, "Cliffs", -200, FLOOR_Y, -740, 182, 40, -724, T.ROCK_DARK)
	BK.cyl(S, { Name = "IntakeTower", Axis = "Y", Size = Vector3.new(18, 46, 18), CFrame = CFrame.new(T.W(-95, 11, -600)), Color = P.CONCRETE_MID, Material = "Concrete" })
	for _, rock in ipairs(Builder.ROCKS) do
		T.box(S, rock[1], rock[2] - rock[4] / 2, FLOOR_Y, rock[3] - rock[6] / 2, rock[2] + rock[4] / 2, FLOOR_Y + rock[5], rock[3] + rock[6] / 2, T.ROCK)
	end
	-- Where things start.
	T.mark("TITAN_STRIDER_DORMANT", -60, FLOOR_Y, -580, "-Z") -- its back to the player coming down the ramp
	T.mark("FRAME_OP_FIGHT", 0, FLOOR_Y, -445, "-Z")
	T.mark("FRAME_OP_POSTFIGHT", 20, FLOOR_Y, -520, "-Z")
	T.mark("MARK_MARA_REGROUP", 40, FLOOR_Y, -520, "-Z")
	T.mark("WP_OP_PADB", 120, FLOOR_Y, -600, "-Z")
	T.cam("CAM_STR_1", -20, -10, -505, -60, 0, -580)
	T.cam("CAM_STR_2", -60, 10, -470, -60, 44, -580)
	BK.dismountPad(ctx.Gameplay, "PAD_B", T.W(120, FLOOR_Y, -600), 14, BK.lookAlong(T.W(134, FLOOR_Y, -596), Vector3.new(1, 0, 0)))
	T.trigger("TRG_BASIN_ENTRY", -40, -440, 40, -420, -20, 40)
	-- Frames stay in the basin: the dam's face, the cliff line, the ridge's foot, and the embankment's top except
	-- at the ramp.
	T.barrier("FrameBarrier_Dam", -188, -724, -186, -424, nil, FLOOR_Y)
	T.barrier("FrameBarrier_Cliffs", -186, -726, 182, -724, nil, FLOOR_Y)
	T.barrier("FrameBarrier_Ridge", 182, -724, 184, -424, nil, FLOOR_Y)
	T.barrier("FrameBarrier_Embankment_W", -186, -399, -30, -397, nil, FLOOR_Y)
	T.barrier("FrameBarrier_Embankment_E", 30, -399, 182, -397, nil, FLOOR_Y)
	T.trigger("TRG_OOB_BASIN_W", -186, -724, -171, -424, FLOOR_Y, 40)
	T.trigger("TRG_OOB_BASIN_N", -171, -724, 167, -709, FLOOR_Y, 40)
	T.trigger("TRG_OOB_BASIN_E", 167, -724, 182, -424, FLOOR_Y, 40)
end

function areas.Ridge(ctx, T)
	local S, BK, P = ctx.Structure, ctx.BK, ctx.P
	-- The slope up from the basin (X 182 -> 260, Y -12 -> 30), the plateau, and the ground rising away to the east.
	T.slope(S, "Slope", "X", -724, -424, 182, 260, FLOOR_Y, 30, T.ROCK)
	T.box(S, "Plateau", 260, FLOOR_Y, -724, 340, 30, -424, T.ROCK)
	T.slope(S, "Beyond", "X", -724, -424, 340, 520, 30, 40, T.GROUND)
	for id, node in pairs(Builder.WATCHER) do
		T.node(id, node[1], node[2], node[3], node[4])
	end
	T.mark("TITAN_WATCHER_W0", 290, 30, -560, "-X")
	T.cam("CAM_WA_1", 20, 30, -505, 290, 50, -560)
	T.cam("CAM_WA_2", 120, 20, -540, 290, 62, -560)
	T.cam("CAM_WA_3", 60, 25, -640, 290, 50, -560)
	T.cam("CAM_WA_4", 110, 0, -570, 150, 5, -600)

	-- Rover SR-12 on its right side at (150, -12, -600), long axis along Z, roof to the east (toward W3).
	T.standIn("RoverBody", 146, FLOOR_Y, -612, 154, -5, -588, T.RUST)
	local panel = BK.model(ctx.Gameplay, "RoofPanel")
	local leaf = BK.part(panel, {
		Name = "Panel", Size = Vector3.new(0.4, 7, 20), CFrame = CFrame.new(T.W(154.2, -8.5, -600)), Color = P.RUST_DARK, Material = "CorrodedMetal",
	})
	panel.PrimaryPart = leaf
	local marking = T.standIn("RearMarking", 148.5, -9.5, -587.9, 151.5, -6.5, -587.5, { Color = P.STEEL_LIGHT, CanCollide = false })
	T.prompt(marking, "INT_ROVER_MARKING", "Examine Marking", { onFootOnly = true, enabled = false })
	-- The cradle and the sealed case lie inside the hull; their prompts need no line of sight in the blockout.
	local cradle = T.standIn("CryoCradle", 149, -11, -605, 151, -9, -603, { Color = P.STEEL_MID, CanCollide = false })
	T.prompt(cradle, "INT_ROVER_CRADLE", "Examine Cradle", { onFootOnly = true, enabled = false, lineOfSight = false })
	local case = T.standIn("SealedCase", 149.3, -12, -596.6, 150.7, -10.5, -595.4, { Color = P.STEEL_DARK, CanCollide = false })
	T.prompt(case, "INT_ROVER_CASE", "Examine Case", { onFootOnly = true, enabled = false, lineOfSight = false })
	-- On foot the player stays at the rover: X 90..200, Z -660..-540.
	for _, wall in ipairs({ { "N", 90, -661, 200, -660 }, { "S", 90, -540, 200, -539 }, { "W", 89, -660, 90, -540 }, { "E", 200, -660, 201, -540 } }) do
		T.barrier("PlayerBarrier_Rover_" .. wall[1], wall[2], wall[3], wall[4], wall[5], "PlayerBarrier", FLOOR_Y, 20)
	end
end

function Builder.Build(opts)
	local C, L = opts.Common, opts.Layout
	local reports = {}
	for _, area in ipairs(opts.areas or Builder.AREAS) do
		local build = areas[area] or error("Outpost07.Wilds: unknown area " .. tostring(area))
		local ctx = C.begin(opts, L.ZONE, area)
		ctx.C = C
		build(ctx, L.tools(ctx))
		reports[area] = C.finish(ctx)
		opts.BK.breathe()
	end
	return reports
end

return Builder
