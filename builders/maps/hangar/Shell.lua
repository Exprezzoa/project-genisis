--!nonstrict
-- builders/maps/hangar/Shell.lua  ->  DevTools.Builders.Hangar.Shell
-- docs/maps/map_02_frame_hangar.md §1, §4: footprint X -120..120, Z -230..-70, walls 3 thick, Y 0..90.
--
-- Passes:
--   blockout   slab, four walls with the openings, a flat roof, the deployment door (§4, segmented: it moves in S09)
--              and a closed stand-in for the training door
--   structure  + the sloped roof (two deck halves from Y 92 at the walls to 98 at the ridge, gables, coping) on
--              seven steel trusses (bottom chord Y 88); pilasters 3 x 90 x 2 and a kickplate on the inner faces; six
--              clerestory window bays in the south wall (Y 60..80, mullions every 5); the training door segmented like
--              the deployment door, with its housing; ribs and hazard stripes on both doors, "LAUNCH 1 →" on the
--              deployment door; the north wall's lettering, two division banners on the south wall, the pipe runs at
--              Y 75 and 60 (the lower one climbs over the doors and ends at the north wall); the entrance's hazard frame
--              and sign; floor expansion joints on a 24 grid
-- Pilasters step around what stands against the walls (D-101): none behind the back walkway and the outer catwalks
-- (Y 43.5..52), none along the main stair and in the doorways, none in the north wall's lettering band (43.5..72),
-- a gap around the control booth (17..29); on the south wall they stand at the window bays' edges (every 30).
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4

-- Clerestory window bays (map_02 §1): six 30-wide bays between X -110 and 110, skipping the middle; each opening is
-- 29.2 wide so neighbouring trims meet at the bay edge.
local WINDOWS = { { -110, -80 }, { -80, -50 }, { -50, -20 }, { 20, 50 }, { 50, 80 }, { 80, 110 } }

-- A big door (§4): four segments 60 x 17.5 x 3 that telescope up into the header housing outside: segment k goes to
-- Y 70..87.5 and 3k studs out, 0.3 s apart, 3.0 s each. Everything on a segment is built at its closed place and gets
-- both CFrames, so the server's door mover (Server/Sequence/Doors) carries it along. out = +1 (east) or -1 (west).
local function bigDoor(ctx, Lib, id, x, zc, out, full, stencil)
	local BK, P = ctx.BK, ctx.P
	local model = BK.model(ctx.Structure, id)
	BK.tag(model, "Door")
	BK.attr(model, { DoorId = id })
	local inward = V(-out, 0, 0)
	for k = 1, 4 do
		local closed = CFrame.new(x, 17.5 * (k - 0.5), zc)
		local open = CFrame.new(x + out * 3 * k, 78.75, zc)
		local temp = Instance.new("Model")
		BK.part(temp, { Name = "Segment" .. k, Size = V(3, 17.5, 60), CFrame = closed, Color = P.STEEL_MID, Material = "Metal" })
		BK.part(temp, { Name = "Rib" .. k, Size = V(0.4, 0.8, 58), CFrame = closed * CFrame.new(out * 1.7, 4, 0), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		if k == 1 then
			BK.part(temp, { Name = "Hazard", Size = V(0.2, 2, 60), CFrame = closed * CFrame.new(out * 1.6, -7.75, 0), Color = P.HAZARD_YELLOW, CanCollide = false })
		end
		if full then
			-- Ribs on the inner face, a seam line along the segment's top, 45° stripes inside on the lowest segment.
			for _, ry in ipairs({ -4, 4 }) do
				BK.part(temp, { Name = "RibIn" .. k, Size = V(0.4, 0.8, 58), CFrame = closed * CFrame.new(-out * 1.7, ry, 0), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
			end
			BK.part(temp, { Name = "RibOut" .. k, Size = V(0.4, 0.8, 58), CFrame = closed * CFrame.new(out * 1.7, -4, 0), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
			for _, side in ipairs({ -1, 1 }) do
				BK.part(temp, { Name = "Seam" .. k, Size = V(0.2, 0.25, 60), CFrame = closed * CFrame.new(side * 1.55, 8.6, 0), Color = P.KICKPLATE, CanCollide = false, CastShadow = false })
			end
			if k == 1 then
				local face = closed.Position + inward * 1.52 + V(0, -7.75, 0)
				BK.hazardStripe(temp, "HazardIn", CFrame.fromMatrix(face, Vector3.zAxis, inward), 60, 2, { angle = 45 })
			end
			if stencil and k == 2 then
				local at = closed.Position + inward * 1.53 + V(0, 2, 8)
				local plate = BK.part(temp, { Name = "Stencil", Size = V(18, 3.6, 0.05), CFrame = BK.lookAlong(at, inward), Color = P.STEEL_MID, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
				local gui = Lib.gui(plate, Enum.NormalId.Front, 0.6, 30)
				Lib.label(gui, stencil, 0, 0, 1, 1, { font = Lib.FONT.header, color = P.HAZARD_YELLOW, xAlign = "Center", transparency = 0.15 })
			end
		end
		for _, part in ipairs(temp:GetDescendants()) do
			if part:IsA("BasePart") then
				BK.attr(part, { ClosedCFrame = part.CFrame, OpenCFrame = open * closed:ToObjectSpace(part.CFrame), Delay = 0.3 * (k - 1), Time = 3.0 })
			end
		end
		for _, child in ipairs(temp:GetChildren()) do
			child.Parent = model
		end
		temp:Destroy()
	end
	return model
end

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Shell", true)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local T = C.HANGAR
	local full = ctx.level >= 2
	local Lib = opts.Props
	if full and not Lib then
		error("Hangar.Shell: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", -120, 120, -230, -70, 0, 1, { Color = P.FLOOR_HANGAR, Material = "Concrete" })
	if not full then
		BK.ceiling(S, "Roof", -121.5, 121.5, -231.5, -68.5, 90, 2, { Color = "#5A5F66", Material = "Metal" })
	end

	BK.wallX(S, "Wall_N", -121.5, 121.5, -230, 0, 90, T, ctx.EXT)
	-- South: the human entrance X -15..15, Y 0..16 (and from the structure pass the clerestory windows).
	local south = { { from = -15, to = 15, y1 = 0, y2 = 16 } }
	if full then
		for _, w in ipairs(WINDOWS) do
			table.insert(south, { from = w[1] + TRIM, to = w[2] - TRIM, y1 = 60, y2 = 80 })
		end
	end
	BK.wallWithOpenings(S, "Wall_S", "X", -121.5, 121.5, -70, 0, 90, T, south, ctx.EXT)
	-- East: the deployment door Z -180..-120, Y 0..70. West: the training door Z -140..-80, Y 0..70.
	BK.wallWithOpenings(S, "Wall_E", "Z", -228.5, -71.5, 120, 0, 90, T, { { from = -180, to = -120, y1 = 0, y2 = 70 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_W", "Z", -228.5, -71.5, -120, 0, 90, T, { { from = -140, to = -80, y1 = 0, y2 = 70 } }, ctx.EXT)

	bigDoor(ctx, Lib, "DOOR_HANGAR_EAST", 120, -150, 1, full, "LAUNCH 1 →")
	BK.box(S, "DoorHousing_E", V(121.5, 68, -182), V(134.5, 90, -118), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	if full then
		bigDoor(ctx, Lib, "DOOR_HANGAR_WEST", -120, -110, -1, true, nil)
		BK.box(S, "DoorHousing_W", V(-134.5, 68, -142), V(-121.5, 90, -78), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		Builder.structure(ctx, C, Lib, floor)
	else
		local steel = { Color = P.STEEL_MID, Material = "Metal", Tags = { "Door" } }
		local west = BK.box(S, "DOOR_HANGAR_WEST", V(-121.5, 0, -140), V(-118.5, 70, -80), steel)
		BK.attr(west, { DoorId = "DOOR_HANGAR_WEST", StandIn = true })
	end

	return C.finish(ctx)
end

---------------------------------------------------------------------------------------------------
-- Structure
---------------------------------------------------------------------------------------------------
function Builder.structure(ctx, C, Lib, floor)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local concrete = { Color = P.CONCRETE_DARK, Material = "Concrete" }

	-- Roof (§1): coping on the wall tops to Y 92, two deck halves rising to the ridge at X 0 (deck top 92 -> 98, 1
	-- thick, #5A5F66 Metal), gables over the north and south walls, a ridge cap.
	for _, c in ipairs({ { V(-121.5, 90, -231.5), V(121.5, 92, -228.5) }, { V(-121.5, 90, -71.5), V(121.5, 92, -68.5) }, { V(-121.5, 90, -228.5), V(-118.5, 92, -71.5) }, { V(118.5, 90, -228.5), V(121.5, 92, -71.5) } }) do
		BK.box(S, "Coping", c[1], c[2], concrete)
	end
	local slope = math.atan2(6, 121.5)
	local length = math.sqrt(121.5 ^ 2 + 6 ^ 2)
	local deck = { Color = "#5A5F66", Material = "Metal" }
	for _, side in ipairs({ -1, 1 }) do
		local p = table.clone(deck)
		p.Name = if side < 0 then "Roof_W" else "Roof_E"
		p.Size = V(length, 1, 163)
		p.CFrame = CFrame.new(side * 60.75, 95, -150) * CFrame.Angles(0, 0, -side * slope) * CFrame.new(0, -0.5, 0)
		BK.part(S, p)
		-- Gables over the north and south walls: the right angle under the ridge.
		for _, z in ipairs({ -230, -70 }) do
			BK.triangle(S, "Gable", V(0, 92, z), V(side * 121.5, 0, 0), V(0, 6, 0), 3, concrete)
		end
	end
	BK.box(S, "RidgeCap", V(-1.5, 97.8, -231.5), V(1.5, 98.6, -68.5), { Color = P.STEEL_DARK, Material = "Metal" })

	-- Seven trusses every 24 along Z (bottom chord Y 88, top chords under the deck, verticals every 12, diagonals).
	local steel = { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false }
	local function underside(x)
		return 91 + 6 * (1 - math.abs(x) / 121.5) - 0.6
	end
	for _, z in ipairs({ -224, -200, -176, -152, -128, -104, -80 }) do
		BK.beam(S, "Truss_Bottom", V(-118.5, 88.6, z), V(118.5, 88.6, z), 1.2, 1.2, steel)
		for _, side in ipairs({ -1, 1 }) do
			BK.beam(S, "Truss_Top", V(side * 118.5, underside(118.5), z), V(0, underside(0), z), 1.2, 1.2, steel)
		end
		for x = -108, 108, 12 do
			BK.beam(S, "Truss_Vertical", V(x, 89.2, z), V(x, underside(x), z), 0.6, 0.6, steel)
			if x < 108 then
				local x2 = x + 12
				local a, b = if x < 0 then V(x, 89.2, z) else V(x, underside(x), z), if x < 0 then V(x2, underside(x2), z) else V(x2, 89.2, z)
				BK.beam(S, "Truss_Diagonal", a, b, 0.45, 0.45, steel)
			end
		end
	end

	-- Pilasters 3 x 90 x 2 (CONCRETE_DARK) and the 1-stud kickplate on each inner face.
	local function face(name, a, b, normal, gaps, pilasters)
		local length = (b - a).Magnitude
		local u = (b - a).Unit
		local key = if math.abs(u.X) > 0.5 then "X" else "Z"
		local base = CFrame.fromMatrix(a, u, Vector3.yAxis)
		local nz = math.sign(base:VectorToObjectSpace(normal).Z)
		local function local1(w)
			return (w - a[key]) * u[key]
		end
		local g = {}
		for _, gap in ipairs(gaps) do
			local s1, s2 = local1(gap[1]), local1(gap[2])
			table.insert(g, { math.min(s1, s2), math.max(s1, s2), gap[3], gap[4] })
		end
		local function slab(partName, r, d, props)
			local p = table.clone(props)
			p.Name = partName
			p.Size = V(r[2] - r[1], r[4] - r[3], d)
			p.CFrame = base * CFrame.new((r[1] + r[2]) / 2, (r[3] + r[4]) / 2, nz * d / 2)
			BK.part(S, p)
		end
		for i, r in ipairs(C.cover(0, length, 0, 1, g)) do
			slab(name .. "_Kick" .. i, r, 0.1, with({ Color = P.KICKPLATE }))
		end
		for _, pil in ipairs(pilasters) do
			local s = local1(pil[1])
			local skips = {}
			for _, skip in ipairs(pil[2] or {}) do
				table.insert(skips, { s - 2, s + 2, skip[1], skip[2] })
			end
			for j, r in ipairs(C.cover(s - 1.5, s + 1.5, 0, 90, skips)) do
				slab(("%s_Pilaster%d_%d"):format(name, math.abs(pil[1]), j), r, 2, concrete)
			end
		end
	end
	local deckBand = { 43.5, 52 }
	local doorE = { -180 - TRIM, -120 + TRIM, 0, 70 + TRIM }
	local doorW = { -140 - TRIM, -80 + TRIM, 0, 70 + TRIM }
	face("FaceN", V(-118.5, 0, -228.5), V(118.5, 0, -228.5), V(0, 0, 1), {}, {
		{ -96, { { 43.5, 72 } } }, { -72, { { 43.5, 72 } } }, { -48, { { 43.5, 72 } } }, { -24, { { 43.5, 72 } } }, { 0, { { 43.5, 72 } } },
		{ 24, { { 43.5, 72 } } }, { 48, { { 43.5, 72 } } }, { 72, { { 43.5, 72 } } }, { 96, { { 43.5, 72 } } },
	})
	face("FaceS", V(-118.5, 0, -71.5), V(118.5, 0, -71.5), V(0, 0, -1), { { -15 - TRIM, 15 + TRIM, 0, 16 + TRIM } }, {
		{ -110 }, { -80 }, { -50 }, { -20 }, { 20 }, { 50, { { 17, 29 } } }, { 80, { { 17, 29 } } }, { 110 },
	})
	face("FaceE", V(118.5, 0, -228.5), V(118.5, 0, -71.5), V(-1, 0, 0), { doorE }, {
		{ -216, { deckBand } }, { -192, { deckBand } }, { -96 },
	})
	face("FaceW", V(-118.5, 0, -228.5), V(-118.5, 0, -71.5), V(1, 0, 0), { doorW }, {
		{ -216, { deckBand } }, { -192, { deckBand } },
	})

	-- The clerestory windows: glass with a mullion every 5 (05 shafts of morning sun come through them).
	for i, w in ipairs(WINDOWS) do
		local width = w[2] - w[1] - 2 * TRIM
		BK.window(S, "Clerestory" .. i, CFrame.new((w[1] + w[2]) / 2, 60, -70), width, 20, { mullions = 5, depth = 0.6 })
	end

	-- The entrance (§1): a hazard-striped frame on the inner face, "FRAME HANGAR" above it.
	local inner = V(0, 0, -1)
	BK.hazardStripe(ctx.Detail, "Entrance_Top", CFrame.fromMatrix(V(0, 17.1, -71.46), Vector3.xAxis, inner), 33.6, 1.2, { angle = 45 })
	for _, x in ipairs({ -16.2, 16.2 }) do
		BK.hazardStripe(ctx.Detail, "Entrance_Side", CFrame.fromMatrix(V(x, 8.2, -71.46), Vector3.yAxis, inner), 16.4, 1.2, { angle = 45 })
	end
	BK.sign(ctx.Detail, "Sign_FrameHangar", BK.lookAlong(V(0, 20.4, -71.42), inner), Vector2.new(20, 3), "FRAME HANGAR", { light = true })

	-- The north wall's lettering (§1), between the back walkway and the pilasters' upper halves.
	local band = BK.part(ctx.Detail, with({ Name = "Lettering", Size = V(200, 18, 0.05), CFrame = BK.lookAlong(V(0, 61.5, -228.4), V(0, 0, 1)), Transparency = 1 }))
	local gui = Lib.gui(band, Enum.NormalId.Front, 1, 12)
	Lib.label(gui, "THIRD FRONTIER FRAME DIVISION", 0, 0.12, 1, 0.62, { font = Lib.FONT.header, color = P.SIGN_WHITE, xAlign = "Center", transparency = 0.1 })
	Lib.label(gui, "EVERY WALL WAS BUILT BY SOMEONE WHO CARED.", 0.1, 0.78, 0.8, 0.18, { font = Lib.FONT.header, color = P.SIGN_WHITE, xAlign = "Center", transparency = 0.1 })

	-- Two giant division banners (16 x 28, SLATE_DEEP with the amber chevron) on the south wall at X +-40, Y 30..58.
	for _, x in ipairs({ -40, 40 }) do
		local kit = Lib.kit(S, "DivisionBanner", CFrame.new(x, 44, -71.5))
		kit.box("Cloth", V(16, 28, 0.4), V(0, 0, -0.7), { Color = P.SLATE_DEEP, Material = "Fabric", CanCollide = false })
		kit.box("BandTop", V(16, 0.8, 0.08), V(0, 12.9, -0.94), with({ Color = P.AMBER }))
		kit.box("BandBottom", V(16, 0.8, 0.08), V(0, -12.9, -0.94), with({ Color = P.AMBER }))
		Lib.insignia(kit, CFrame.new(0, 3.5, -0.95), 11)
		kit.cyl("Rod", "X", V(18, 0.8, 0.8), V(0, 14.4, -0.7), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		for _, bx in ipairs({ -8.4, 8.4 }) do
			kit.box("Bracket", V(0.6, 0.6, 1.2), V(bx, 14.4, -0.4), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		end
		kit.finish()
	end

	-- Pipe runs (§1), clear of the pilasters' faces: Y 75 (radius 0.8, #7B848C) along the west, north and east walls;
	-- Y 60 (radius 1.2, STEEL_MID) along the west and east walls only, climbing to 72 over the door openings and ending
	-- in a flange at the north wall (along the north wall it would cross the lettering and the back walkway, D-101).
	BK.pipeRun(ctx.Detail, "Pipe_Y75", { V(-115.3, 75, -74), V(-115.3, 75, -225.3), V(115.3, 75, -225.3), V(115.3, 75, -74) }, 0.8, { color = "#7B848C" })
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 115.3
		local door = if sx > 0 then { -117, -183 } else { -77, -143 }
		BK.pipeRun(ctx.Detail, "Pipe_Y60_" .. (if sx > 0 then "E" else "W"), {
			V(x, 60, -74), V(x, 60, door[1]), V(x, 72, door[1]), V(x, 72, door[2]), V(x, 60, door[2]), V(x, 60, -227.6),
		}, 1.2, { color = P.STEEL_MID })
		BK.cyl(ctx.Detail, with({ Name = "PipeFlange", Axis = "Z", Size = V(3.4, 3.4, 0.6), Position = V(x, 60, -228.1), Color = P.STEEL_DARK, Material = "Metal" }))
	end

	-- Floor expansion joints on a 24 grid (§1), lower than the painted bay lines (0.05) so they never fight them.
	BK.seams(floor, Enum.NormalId.Top, 24, { width = 0.2, depth = 0.06, color = P.KICKPLATE, parent = ctx.Detail, name = "ExpansionJoints" })
end

return Builder
