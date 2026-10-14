--!nonstrict
-- builders/maps/outpost07/Wilds.lua  ->  DevTools.Builders.Outpost07.Wilds
-- docs/maps/map_03_outpost_07.md §11-14: the trail from the North Gate, Kessler Basin (the arena), the East
-- Ridge with the Watcher's route, and the rover crash site with Pad B.
--
-- BLOCKOUT pass, like Compound: right sizes and places, collisions, markers, cameras, triggers, barriers,
-- prompts on stand-ins. No props, except the rover: the player walks into it in S32, so its hull, bay and the
-- things in it are built in every pass (see rover below).
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

-- Rover SR-12 (docs/07 §6, map_03 §14): 10 wide, 9 tall, 24 long, lying on its right side at (150, -12, -600)
-- with its front to the north and its roof to the east (toward W3). On its side the truck's height runs along X
-- (floor X 145.5, roof 154.5) and its width along Y (-12..-2). The hull, the cargo bay, the hinged roof and
-- everything S31-S32 use are built in every pass, because the player walks into the bay; wheels, skid marks and
-- debris come with the structure pass. The bay is 17 long inside (Z -606..-589) instead of the doc's 14, so that
-- the cradle (Z -604) and the case (Z -596) both sit where map_03 puts them (D-070).
local ROVER_GREY = "#7E848A" -- docs/07 §6
local ECHO_WHITE = "#D9DDE2" -- docs/07 §6, the ECHO rings

local function rover(ctx, T)
	local S, BK, P, G = ctx.Structure, ctx.BK, ctx.P, ctx.Gameplay
	local hull = { Color = ROVER_GREY, Material = "Metal" }
	local W = T.W
	local model = BK.model(S, "RoverSR12")
	-- The cab (solid), and the cargo bay's four closed sides: the floor (west), the right side (on the ground, the
	-- bay's walking surface at Y -11), the left side (facing up) and the rear doors (south).
	T.box(model, "Cab", 145.5, FLOOR_Y, -612, 154.5, -2, -606, hull)
	T.box(model, "BayFloor", 145.5, FLOOR_Y, -606, 146.5, -2, -588, hull)
	T.box(model, "BayRightSide", 146.5, FLOOR_Y, -606, 154.5, -11, -589, { Color = P.STEEL_MID, Material = "DiamondPlate" })
	T.box(model, "BayLeftSide", 146.5, -3, -606, 154.5, -2, -589, hull)
	T.box(model, "RearDoorA", 146.5, -11, -589, 154.5, -7.05, -588, hull)
	T.box(model, "RearDoorB", 146.5, -6.95, -589, 154.5, -3, -588, hull)
	T.box(model, "DoorSeam", 146.6, -7.05, -588.9, 154.4, -6.95, -588.1, { Color = P.STEEL_DARK })
	BK.part(model, { Name = "Windshield", Size = Vector3.new(4, 6, 0.2), CFrame = CFrame.new(W(152, -7, -612.05)), Color = P.GLASS, Material = "Glass", Transparency = 0.55 })

	-- The roof over the bay: a hinged panel the Watcher peels back (110 degrees about its lower outer edge, S31).
	local panel = BK.model(G, "RoofPanel")
	panel.PrimaryPart = T.box(panel, "Panel", 153.5, -11, -606, 154.5, -3, -589, { Color = ROVER_GREY, Material = "CorrodedMetal" })
	-- A ramp of debris to the opening for on-foot entry.
	BK.wedge(G, {
		Name = "DebrisRamp", Size = Vector3.new(6, 1, 3.5), CFrame = CFrame.lookAt(W(156.25, -11.5, -600), W(157.25, -11.5, -600)),
		Color = P.RUST_DARK, Material = "CorrodedMetal",
	})

	-- The ECHO mark on the rear doors: three thin rings (Neon off) and the "SR-12" stencil; the prompt sits on it.
	for index, ring in ipairs({ { 3.0, ECHO_WHITE }, { 2.6, ROVER_GREY }, { 2.0, ECHO_WHITE }, { 1.6, ROVER_GREY }, { 1.0, ECHO_WHITE }, { 0.6, ROVER_GREY } }) do
		BK.cyl(model, {
			Name = "EchoRing", Axis = "Z", Size = Vector3.new(ring[1], ring[1], 0.04), CFrame = CFrame.new(W(150, -8, -588 + 0.02 * index)),
			Color = ring[2], CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	BK.sign(model, "Stencil", CFrame.lookAt(W(152.6, -8, -587.92), W(152.6, -8, -586)) * CFrame.Angles(0, 0, math.rad(90)), Vector2.new(3.6, 1.1), "SR-12", {
		bgTransparency = 1, textColor = ECHO_WHITE,
	})
	local marking = BK.part(G, { Name = "RearMarking", Size = Vector3.new(3.2, 3.2, 0.4), CFrame = CFrame.new(W(150, -8, -587.8)), Transparency = 1, CanCollide = false })
	T.prompt(marking, "INT_ROVER_MARKING", "Inspect", { onFootOnly = true, enabled = false })

	-- The cryo cradle (docs/07 §6: a 2 x 3 cylinder slot, frost-white glow) on a housing bolted to the floor, with
	-- its label, and the T-V canister in it until the Watcher takes it (docs/10).
	T.box(model, "CradleHousing", 146.5, -11, -606, 148.5, -7.5, -602, { Color = P.STEEL_MID, Material = "Metal" })
	for _, x in ipairs({ 149, 151 }) do
		BK.cyl(model, { Name = "CradleBand", Axis = "X", Size = Vector3.new(0.25, 2.5, 2.5), CFrame = CFrame.new(W(x, -10, -604)), Color = P.STEEL_DARK, CanCollide = false })
	end
	BK.sign(model, "CradleLabel", CFrame.lookAt(W(148.53, -8.1, -604), W(150, -8.1, -604)), Vector2.new(3.2, 0.7), "SUBJECT T-V / ECHO-9", {
		bgColor = P.STEEL_DARK, textColor = P.SIGN_WHITE, font = Enum.Font.RobotoMono,
	})
	local cradle = BK.cyl(G, {
		Name = "CryoCradle", Axis = "X", Size = Vector3.new(3, 2, 2), CFrame = CFrame.new(W(150, -10, -604)),
		Color = P.MEDICAL_WHITE, Material = "Neon", Transparency = 0.85, CanCollide = false,
	})
	T.prompt(cradle, "INT_ROVER_CRADLE", "Inspect", { onFootOnly = true, enabled = false, lineOfSight = false })
	local canister = BK.cyl(G, {
		Name = "TV_Canister", Axis = "X", Size = Vector3.new(2.4, 1.2, 1.2), CFrame = CFrame.new(W(150, -10, -604)),
		Color = P.MEDICAL_WHITE, Material = "SmoothPlastic", CanCollide = false, CanQuery = false,
	})
	local frost = BK.emitter(canister, "Smoke")
	frost.Name = "Frost"
	frost.Color = ColorSequence.new(P.MEDICAL_WHITE)
	frost.Size = NumberSequence.new(0.3, 1.2)
	frost.Transparency = NumberSequence.new(0.55, 1)
	frost.Lifetime = NumberRange.new(1, 2)
	frost.Speed = NumberRange.new(0.3, 1)
	frost.Rate = 5

	-- The sealed case (docs/07 §6 MetalCase, 4 x 2 x 2.5) on the bay's floor, with its red lock light facing the
	-- opening (S32 turns it cyan for 0.6 s, then off).
	local case = BK.model(G, "MetalCase")
	local body = T.box(case, "SealedCase", 148.75, -11, -598, 151.25, -9, -594, { Color = P.STEEL_MID, Material = "Metal" })
	case.PrimaryPart = body
	T.prompt(body, "INT_ROVER_CASE", "Open", { hold = 2.0, onFootOnly = true, enabled = false, lineOfSight = false })
	T.box(case, "LidSeam", 148.7, -9.65, -598.05, 151.3, -9.55, -593.95, { Color = P.STEEL_DARK, CanCollide = false })
	for _, z in ipairs({ -597, -595 }) do
		T.box(case, "Clasp", 151.25, -9.8, z - 0.2, 151.4, -9.4, z + 0.2, { Color = P.AMBER, Material = "Neon", CanCollide = false })
	end
	T.box(case, "Handle", 149.7, -9, -596.8, 150.3, -8.7, -595.2, { Color = P.STEEL_LIGHT, Material = "Metal", CanCollide = false })
	T.box(case, "LockLight", 151.25, -10.35, -596.2, 151.45, -9.95, -595.8, { Color = P.DANGER_RED, Material = "Neon", CanCollide = false })

	-- Loose papers and a broken screen in the bay.
	for index, paper in ipairs({ { 151, -600, 20 }, { 152.5, -592, -35 }, { 149, -591, 70 } }) do
		BK.part(model, {
			Name = "Paper" .. index, Size = Vector3.new(0.9, 0.04, 1.2), CFrame = CFrame.new(W(paper[1], -10.97, paper[2])) * CFrame.Angles(0, math.rad(paper[3]), 0),
			Color = P.MEDICAL_WHITE, CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	T.box(model, "BrokenScreen", 146.5, -7, -594, 146.8, -5, -591, { Color = P.STEEL_DARK, Material = "Glass", Reflectance = 0.1 })

	if ctx.level < 2 then
		return
	end
	-- Five wheels still on (the front one of the upper side was torn off and lies nearby); 4 skid marks curving in
	-- from (60, -12, -560); 3 spilled crates and a bent antenna.
	local tire = { Color = P.HAZARD_BLACK, Material = "SmoothPlastic" }
	for _, wheel in ipairs({ { -608, -11.25 }, { -597, -11.25 }, { -592, -11.25 }, { -597, -2.75 }, { -592, -2.75 } }) do
		local wheelProps = table.clone(tire)
		wheelProps.Name, wheelProps.Axis, wheelProps.Size, wheelProps.CFrame = "Wheel", "Y", Vector3.new(4, 1.5, 4), CFrame.new(W(144.5, wheel[2], wheel[1]))
		BK.cyl(model, wheelProps)
	end
	local torn = table.clone(tire)
	torn.Name, torn.Axis, torn.Size, torn.CFrame = "TornWheel", "Y", Vector3.new(4, 1.5, 4), CFrame.new(W(166, FLOOR_Y + 0.75, -614))
	BK.cyl(S, torn)
	for index, track in ipairs({
		{ { 60, -560 }, { 104, -571 }, { 140, -590 } }, { { 58, -567 }, { 102, -578 }, { 138, -597 } },
	}) do
		for leg = 1, 2 do
			local a, b = track[leg], track[leg + 1]
			BK.beam(S, ("SkidMark%d_%d"):format(index, leg), W(a[1], FLOOR_Y + 0.04, a[2]), W(b[1], FLOOR_Y + 0.04, b[2]), 1.6, 0.05, {
				Color = P.MUD_CRACK, CanCollide = false, CanQuery = false, CastShadow = false,
			})
		end
	end
	for index, crate in ipairs({ { 164, -585, 15 }, { 137, -584, -20 }, { 171, -594, 40 } }) do
		BK.part(S, {
			Name = "Crate" .. index, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(W(crate[1], FLOOR_Y + 1.5, crate[2])) * CFrame.Angles(0, math.rad(crate[3]), 0),
			Color = P.WOOD_OLD, Material = "WoodPlanks",
		})
	end
	BK.beam(model, "Antenna", W(154.5, -4, -609), W(158, -3.5, -609), 0.2, 0.2, { Color = P.STEEL_LIGHT, Material = "Metal", CanCollide = false })
	BK.beam(model, "AntennaBent", W(158, -3.5, -609), W(159.5, -6, -607.5), 0.2, 0.2, { Color = P.STEEL_LIGHT, Material = "Metal", CanCollide = false })
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

	rover(ctx, T)
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
