--!nonstrict
-- builders/maps/central_command/WestCorridor.lua  ->  DevTools.Builders.CentralCommand.WestCorridor
-- docs/maps/map_01_central_command.md §4: X -80..-60, Z -40..40, ceiling 14.
-- The east side is the Ops Hall's west wall (built by OpsHall); this builder dresses its west face.
--
-- Passes (docs/07 §2): blockout = shell and the two double doorways; structure = finishes, exterior pilasters, the
-- doorways' strips and signs ("BRIEFING ROOM ONE", "PILOT QUARTERS"), corridor strips; dressed = the wall directory,
-- two benches with planters, the water fountain, the notice board with the simulator rankings, a news screen,
-- vents and seams. opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "WestCorridor")
	local BK, S = ctx.BK, ctx.Structure
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("WestCorridor: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", -80, -60, -40, 40, 0, 1, ctx.FLOOR)
	local ceiling = BK.ceiling(S, "Ceiling", -80, -60, -40, 40, 14, 1, ctx.CEIL)
	BK.wallX(S, "Wall_N", -80.5, -61, -40, 0, 15, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_S", -80.5, -61, 40, 0, 15, C.EXT, ctx.EXT)
	-- West wall: double doors (8 x 9) to Briefing Z -24..-16 and Quarters Z 16..24. 17 tall = Briefing's roof.
	BK.wallWithOpenings(S, "Wall_W", "Z", -39, 39, -80, 0, 17, C.INT, {
		{ from = -24, to = -16, y1 = 0, y2 = C.DOUBLE_H },
		{ from = 16, to = 24, y1 = 0, y2 = C.DOUBLE_H },
	}, ctx.INT)

	if ctx.level >= 2 then
		Builder.structure(ctx, C, Lib)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, C, Lib)
		C.tileSeams(ctx, floor, ceiling)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.structure(ctx, C, Lib)
	local BK = ctx.BK
	local doors = {
		{ from = -24 - TRIM, to = -16 + TRIM, y1 = 0, y2 = C.DOUBLE_H + TRIM },
		{ from = 16 - TRIM, to = 24 + TRIM, y1 = 0, y2 = C.DOUBLE_H + TRIM },
	}
	C.face(ctx, "FaceW", V(-79.5, 0, -39), V(-79.5, 0, 39), V(1, 0, 0), { kind = "interior", top = 14, gaps = doors })
	C.face(ctx, "FaceE", V(-60.5, 0, -39), V(-60.5, 0, 39), V(-1, 0, 0), { kind = "interior", top = 14, gaps = { { from = -10 - TRIM, to = 10 + TRIM, y1 = 0, y2 = 14 } } })
	C.face(ctx, "FaceN", V(-79.5, 0, -39), V(-60.5, 0, -39), V(0, 0, 1), { kind = "interior", top = 14, lining = true })
	C.face(ctx, "FaceS", V(-79.5, 0, 39), V(-60.5, 0, 39), V(0, 0, -1), { kind = "interior", top = 14, lining = true })
	C.face(ctx, "Ext_N", V(-80.5, 0, -41), V(-61, 0, -41), V(0, 0, -1), { kind = "exterior", top = 15 })
	C.face(ctx, "Ext_S", V(-80.5, 0, 41), V(-61, 0, 41), V(0, 0, 1), { kind = "exterior", top = 15 })

	-- The doorways (open passages, map_01 §2) with their signs on the corridor side (06 §7's sign list).
	BK.door(ctx.Structure, "Doorway_Briefing", CFrame.new(-80, 0, -20) * Lib.FACE["+X"], 8, C.DOUBLE_H, { leaf = false, sign = "BRIEFING ROOM ONE" })
	BK.door(ctx.Structure, "Doorway_Quarters", CFrame.new(-80, 0, 20) * Lib.FACE["+X"], 8, C.DOUBLE_H, { leaf = false, sign = "PILOT QUARTERS" })

	-- Corridor strips every 10 along the corridor (06 §5: 0.3 x 0.15 x 6, SurfaceLight 1 / 16).
	for i, z in ipairs({ -35, -25, -15, -5, 5, 15, 25, 35 }) do
		C.fixture(ctx, "Strip" .. i, V(-70, 13.9, z), V(0.3, 0.15, 6), { Brightness = 1, Range = 16 })
	end
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local EAST = Lib.FACE["+X"]
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- The wall directory at (-79, 5, 0) (map_01 §4, its text exactly).
	BK.box(F, "Directory_Back", V(-79.5, 3.6, -4.3), V(-79.35, 6.4, 4.3), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	BK.sign(ctx.Detail, "Directory", BK.lookAlong(V(-79.28, 5, 0), V(1, 0, 0)), Vector2.new(8.2, 2.4), "↑ HANGAR via OPS · ← BRIEFING · ← QUARTERS · → MEDICAL / EQUIPMENT", {
		textColor = P.SIGN_WHITE, bgColor = P.SLATE, light = true,
	})

	-- Two benches against the west wall with a planter at each end (living green is rare: GRASS_SPARSE).
	for i, z in ipairs({ -8, 8 }) do
		Lib.Bench(F, CFrame.new(-78.6, 0, z) * EAST, { name = "Bench" .. i })
		local pz = z + (if z < 0 then -5.3 else 5.3)
		BK.box(F, "Planter" .. i, V(-79.4, 0, pz - 0.8), V(-77.8, 1.6, pz + 0.8), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		BK.box(F, "PlanterSoil" .. i, V(-79.25, 1.6, pz - 0.65), V(-77.95, 1.65, pz + 0.65), with({ Color = P.GROUND, Material = "Ground" }))
		local rng = BK.rng(40 + i)
		for leaf = 1, 6 do
			local a = rng.next(0, math.pi * 2)
			BK.part(F, with({
				Name = "PlanterLeaf" .. i, Size = V(0.3, rng.next(1.4, 2.4), 0.12), Color = P.GRASS_SPARSE, Material = "LeafyGrass",
				CFrame = CFrame.new(-78.6 + math.cos(a) * 0.25, 2.3, pz + math.sin(a) * 0.25) * CFrame.Angles(math.sin(a) * 0.35, 0, math.cos(a) * 0.35),
			}))
		end
	end

	-- The water fountain on the east wall (north of the Ops Hall opening).
	local fz = -28
	BK.box(F, "Fountain_Body", V(-61.6, 2.4, fz - 1), V(-60.5, 3.4, fz + 1), { Color = P.STEEL_LIGHT, Material = "Metal" })
	BK.box(F, "Fountain_Basin", V(-61.5, 3.35, fz - 0.8), V(-60.7, 3.42, fz + 0.8), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.box(F, "Fountain_Spout", V(-61.0, 3.42, fz - 0.06), V(-60.8, 3.7, fz + 0.06), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	BK.box(F, "Fountain_Pipe", V(-60.9, 0, fz - 0.15), V(-60.6, 2.4, fz + 0.15), with({ Color = P.STEEL_MID, Material = "Metal" }))
	BK.sign(ctx.Detail, "Fountain_Sign", BK.lookAlong(V(-60.56, 4.6, fz), V(-1, 0, 0)), Vector2.new(2.2, 0.5), "POTABLE WATER", { textColor = P.SIGN_WHITE, bgColor = P.SLATE })

	-- The notice board on the east wall (south of the opening): "Simulator rankings" (Mara's bet, map_01 §4).
	local nz = 27
	BK.box(F, "Notice_Board", V(-60.62, 3.8, nz - 4), V(-60.5, 7.8, nz + 4), { Color = P.SLATE_DEEP, CanCollide = false })
	local board = BK.part(F, { Name = "Notice_Rankings", Size = V(3.4, 2.6, 0.04), CFrame = BK.lookAlong(V(-60.66, 5.9, nz - 1.8), V(-1, 0, 0)), Color = P.MEDICAL_WHITE, CanCollide = false, CastShadow = false })
	local g = Lib.gui(board, Enum.NormalId.Front, 0.6, 80)
	Lib.rect(g, 0, 0, 1, 1, P.MEDICAL_WHITE, 0, "Paper")
	Lib.label(g, "SIMULATOR RANKINGS", 0.06, 0.05, 0.88, 0.16, { font = Lib.FONT.header, color = P.KICKPLATE, xAlign = "Center" })
	for i, row in ipairs({ { "1", "SOLEN", "41" }, { "2", "VEYNE", "39" }, { "3", "ROOK", "37" } }) do
		local y = 0.27 + (i - 1) * 0.2
		Lib.label(g, row[1] .. ".  " .. row[2], 0.1, y, 0.6, 0.15, { font = Lib.FONT.body, color = P.KICKPLATE })
		Lib.label(g, row[3], 0.7, y, 0.2, 0.15, { color = P.KICKPLATE, xAlign = "Right" })
	end
	Lib.rect(g, 0.08, 0.88, 0.84, 0.01, P.KICKPLATE, 0.4, "Rule")
	for i, s in ipairs({ { nz + 0.6, 4.4, 1.6, 2.4, P.AMBER_LAMP }, { nz + 2.5, 4.9, 1.4, 1.8, P.MEDICAL_WHITE } }) do
		BK.box(F, "Notice_Sheet" .. i, V(-60.7, s[2], s[1]), V(-60.66, s[2] + s[4], s[1] + s[3]), with({ Color = s[5] }))
	end
	BK.sign(ctx.Detail, "Notice_Header", BK.lookAlong(V(-60.68, 7.45, nz), V(-1, 0, 0)), Vector2.new(7.6, 0.5), "NOTICES — THIRD FRONTIER")

	-- A news screen on the west wall between the doors, high (the city's morning broadcast).
	BK.screen(ctx.Detail, "NewsScreen", BK.lookAlong(V(-79.4, 9.6, 0), V(1, 0, 0)), Vector2.new(7, 3.4), {
		text = "HALDEN BROADCAST · DAY 4112\nNo breach of the Bulwark.\nAsh advisory: eastern districts.\nMasks recommended after noon.",
	})

	-- Vents high on both side walls, a conduit along the west wall's top.
	for i, z in ipairs({ -32, 32 }) do
		Lib.Vent(F, CFrame.new(-79.5, 11, z) * EAST, { name = "Vent_W" .. i })
	end
	BK.pipeRun(ctx.Detail, "Conduit", { V(-79.1, 13.3, -38.6), V(-79.1, 13.3, 38.6) }, 0.16, { color = P.STEEL_MID })
end

return Builder
