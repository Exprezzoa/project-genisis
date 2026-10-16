--!nonstrict
-- builders/maps/central_command/Briefing.lua  ->  DevTools.Builders.CentralCommand.Briefing
-- docs/maps/map_01_central_command.md §6: X -130..-80, Z -40..0, ceiling 16. Tiered seating facing west.
--
-- Passes (docs/07 §2):
--   blockout   shell, tiers, aisle steps, the slide screen, grey stand-ins for the benches and the lectern
--   structure  + finishes, exterior pilasters, the screen's frame and glow, the tiers' amber step lights, nine ceiling
--              strips tagged BriefingLight (CIN_BRIEFING dims them to 0.35: Shared/Cinematics, AmbientController)
--   dressed    + the benches (12 long, two blocks per tier), the lectern with the Division insignia, acoustic panels,
--              banners, a holo clock over the door, vents, a duty screen, seams
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4
local TIERS = { { -109, 0 }, { -103, 1 }, { -97, 2 } } -- bench line X and floor height (map_01 §6)
local BLOCKS = { { -36, -24 }, { -16, -4 } } -- bench blocks along Z either side of the aisle Z -24..-16

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Briefing")
	local BK, S, G = ctx.BK, ctx.Structure, ctx.Gameplay
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("Briefing: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", -130, -80, -40, 0, 0, 1, ctx.FLOOR)
	local ceiling = BK.ceiling(S, "Ceiling", -130, -80, -40, 0, 16, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", -131, -80.5, -40, 0, 17, C.EXT, ctx.EXT)
	BK.wallZ(S, "Wall_W", -39, 0, -130, 0, 17, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_Divider", -129, -80.5, 0, 0, 17, C.INT, ctx.INT) -- shared with Quarters

	-- Tiers: tier 1 is the floor (X -112..-106), tier 2 top Y 1 (X -106..-100), tier 3 top Y 2 (X -100..-94).
	BK.box(S, "Tier2", V(-106, 0, -39), V(-100, 1, -0.5), ctx.FLOOR)
	BK.box(S, "Tier3", V(-100, 0, -39), V(-94, 2, -0.5), ctx.FLOOR)
	-- Two steps up to tier 3 in the center aisle (Z -24..-16); the doc gives the tiers but no way up (D-026).
	BK.stairs(S, "AisleSteps", V(-91, 0, -20), V(-1, 0, 0), 8, 2, { railings = false, stringers = false, material = "SmoothPlastic", color = ctx.FLOOR.Color })

	-- The slide screen on the west wall (Z -35..-5, Y 3..13, its +X face toward the seats). Each client draws
	-- the slides on it (Client/UI/BriefingScreen); the base is docs/07 §6's screen color.
	local screen = BK.part(G, {
		Name = "BriefingScreen", Size = V(0.2, 10, 30), CFrame = CFrame.new(-128.9, 8, -20), Color = "#1B2A33",
		Material = "SmoothPlastic", CanCollide = false, CastShadow = false,
	})

	if ctx.level >= 2 then
		Builder.structure(ctx, C, Lib, screen)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, C, Lib)
		C.tileSeams(ctx, floor, ceiling)
	else
		-- Stand-ins: a bench on each tier in both blocks (docs/07 §6 Bench: 1.8 tall, 1.6 deep) and the lectern Vale
		-- stands behind (map_01 §6; its size is ours, D-081).
		for _, tier in ipairs(TIERS) do
			local x, y = tier[1], tier[2]
			for index, block in ipairs(BLOCKS) do
				C.standIn(ctx, ("Bench_X%d_%d_StandIn"):format(-x, index), V(x - 0.8, y, block[1]), V(x + 0.8, y + 1.8, block[2]), { Color = ctx.P.FABRIC_DARK })
			end
		end
		C.standIn(ctx, "Lectern_StandIn", V(-122.75, 0, -21), V(-121.25, 3.6, -19), { Color = ctx.P.STEEL_DARK })
	end

	BK.trigger(G, "TRG_BRIEFING_ENTER", V(-92, 0, -24), V(-82, 10, -16), "TRG_BRIEFING_ENTER")
	BK.camPoint(G, "CAM_BRF_WIDE", V(-92, 9, -20), V(-125, 7, -20))
	BK.camPoint(G, "CAM_BRF_VALE", V(-112, 6.5, -16), V(-122, 6, -20))
	BK.camPoint(G, "CAM_BRF_PILOTS", V(-113, 6, -24), V(-104, 5, -26))

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.structure(ctx, C, Lib, screen)
	local BK, P = ctx.BK, ctx.P
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	C.face(ctx, "FaceN", V(-129, 0, -39), V(-80.5, 0, -39), V(0, 0, 1), { kind = "interior", top = 16, lining = true })
	C.face(ctx, "FaceS", V(-129, 0, -0.5), V(-80.5, 0, -0.5), V(0, 0, -1), { kind = "interior", top = 16 })
	C.face(ctx, "FaceW", V(-129, 0, -39), V(-129, 0, -0.5), V(1, 0, 0), {
		kind = "interior", top = 16, lining = true, gaps = { { from = -35.6, to = -4.4, y1 = 2.4, y2 = 13.6 } },
	})
	C.face(ctx, "FaceE", V(-80.5, 0, -39), V(-80.5, 0, -0.5), V(-1, 0, 0), {
		kind = "interior", top = 16, gaps = { { from = -24 - TRIM, to = -16 + TRIM, y1 = 0, y2 = C.DOUBLE_H + TRIM } },
	})
	C.face(ctx, "Ext_N", V(-131, 0, -41), V(-80.5, 0, -41), V(0, 0, -1), { kind = "exterior", top = 17 })
	C.face(ctx, "Ext_W", V(-131, 0, -41), V(-131, 0, 0), V(-1, 0, 0), { kind = "exterior", top = 17 })

	-- The screen's frame and its glow toward the seats.
	local frame = { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CastShadow = false }
	BK.box(ctx.Detail, "ScreenFrame_Top", V(-129, 13, -35.6), V(-128.6, 13.6, -4.4), frame)
	BK.box(ctx.Detail, "ScreenFrame_Bottom", V(-129, 2.4, -35.6), V(-128.6, 3, -4.4), frame)
	BK.box(ctx.Detail, "ScreenFrame_N", V(-129, 3, -35.6), V(-128.6, 13, -35), frame)
	BK.box(ctx.Detail, "ScreenFrame_S", V(-129, 3, -5), V(-128.6, 13, -4.4), frame)
	BK.light(screen, "Surface", { Face = Enum.NormalId.Right, Color = P.AMBER, Brightness = 0.5, Range = 22, Tags = { "HubLight" } })

	-- Step lights along the tiers' edges (map_01 §6: thin amber Neon strips, 50% transparency; calibrated glow).
	local step = with({ Color = BK.GLOW.amber.Color, Material = "Neon", Transparency = 0.5 })
	for _, e in ipairs({ { -106, 1 }, { -100, 2 }, { -94, 2 } }) do
		local x, top = e[1], e[2]
		for _, run in ipairs({ { -39, -24 }, { -16, -0.5 } }) do
			BK.box(ctx.Detail, "StepLight", V(x - 0.05, top - 0.14, run[1]), V(x + 0.05, top - 0.04, run[2]), step)
		end
	end

	-- Nine ceiling strips (Briefing in 06 §5: brightness 1.0, dimmed to 0.35 during the briefing cinematic).
	local n = 0
	for _, z in ipairs({ -32, -20, -8 }) do
		for _, x in ipairs({ -121, -105, -89 }) do
			n += 1
			C.fixture(ctx, "Strip" .. n, V(x, 15.9, z), V(6, 0.15, 0.3), { Brightness = 1.0, Range = 18, Tags = { "BriefingLight" } })
		end
	end

	-- The doorway's strip on the room side (the sign is on the corridor side, WestCorridor).
	BK.door(ctx.Structure, "Doorway", CFrame.new(-80, 0, -20) * Lib.FACE["-X"], 8, C.DOUBLE_H, { leaf = false })
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local EAST, WEST = Lib.FACE["+X"], Lib.FACE["-X"]
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- Benches facing the screen: 12 long, one per block on each tier (the seat marks are on tier 2's north block).
	for _, tier in ipairs(TIERS) do
		local x, y = tier[1], tier[2]
		for index, block in ipairs(BLOCKS) do
			Lib.Bench(F, CFrame.new(x, y, (block[1] + block[2]) / 2) * WEST, { name = ("Bench_X%d_%d"):format(-x, index), width = 12 })
		end
	end

	-- The lectern (Vale stands west of it at (-123.5, 0, -20), facing east): a column, a reading desk sloping up toward
	-- the audience, the Division insignia on its front, a microphone.
	local lectern = Lib.kit(F, "Lectern", CFrame.new(-122, 0, -20) * EAST)
	local body = lectern.box("Column", V(1.8, 3.2, 1.2), V(0, 1.6, 0), { Color = P.STEEL_DARK, Material = "Metal" })
	lectern.box("Plinth", V(2.4, 0.2, 1.8), V(0, 0.1, 0), { Color = P.KICKPLATE, CanCollide = false })
	lectern.part("Desk", V(2.2, 0.15, 1.7), CFrame.new(0, 3.35, 0.1) * CFrame.Angles(math.rad(20), 0, 0), { Color = P.STEEL_MID, Material = "Metal" })
	lectern.box("Panel", V(1.4, 1.6, 0.06), V(0, 1.9, -0.63), with({ Color = P.SLATE_DEEP }))
	Lib.insignia(lectern, CFrame.new(0, 1.95, -0.68), 1.0)
	lectern.beam("MicStem", V(0.55, 3.4, 0.2), V(0.4, 4.2, -0.2), 0.05, 0.05, with({ Color = P.STEEL_DARK, Material = "Metal" }))
	lectern.ball("Mic", 0.14, V(0.4, 4.22, -0.22), with({ Color = P.HAZARD_BLACK }))
	lectern.finish(body)

	-- Acoustic panels on the north and south walls, a banner either side of the door, a holo clock above it.
	for _, wall in ipairs({ { -38.95, V(0, 0, 1), "N" }, { -0.55, V(0, 0, -1), "S" } }) do
		for i, x in ipairs({ -122, -114, -88 }) do
			local cf = BK.lookAlong(V(x, 8.5, wall[1] + wall[2].Z * 0.15), wall[2])
			BK.part(F, { Name = "AcousticPanel_" .. wall[3] .. i, Size = V(6, 6, 0.3), CFrame = cf, Color = P.SLATE_DEEP, Material = "Fabric", CanCollide = false })
			BK.part(F, with({ Name = "AcousticTrim_" .. wall[3] .. i, Size = V(6.3, 0.2, 0.36), CFrame = cf * CFrame.new(0, 3.1, 0), Color = P.STEEL_DARK, Material = "Metal" }))
		end
	end
	Lib.Banner(F, CFrame.new(-80.5, 9.2, -31) * WEST, { name = "Banner_N" })
	Lib.Banner(F, CFrame.new(-80.5, 9.2, -9) * WEST, { name = "Banner_S" })
	local clock = Lib.HoloPanel(F, CFrame.new(-80.9, 12.4, -20) * WEST, {
		name = "HoloClock", size = Vector2.new(3.2, 1.4), title = "07:12", lines = { "BRIEFING ROOM ONE" }, titleHeight = 0.5, lineHeight = 0.2, backFace = false,
	})
	BK.tag(clock.PrimaryPart, "HoloClock")

	-- Vents high on the north wall, and a small duty screen by the door.
	for i, x in ipairs({ -118, -98 }) do
		Lib.Vent(F, CFrame.new(x, 14, -39) * Lib.FACE["+Z"], { name = "Vent" .. i })
	end
	BK.screen(ctx.Detail, "DoorScreen", BK.lookAlong(V(-80.6, 5, -13.5), V(-1, 0, 0)), Vector2.new(2.6, 1.6), {
		text = "BRIEFING ROOM ONE\n06:30 EMBER SQUAD\nCMDR VALE",
	})
end

return Builder
