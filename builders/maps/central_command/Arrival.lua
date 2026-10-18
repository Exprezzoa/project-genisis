--!nonstrict
-- builders/maps/central_command/Arrival.lua  ->  DevTools.Builders.CentralCommand.Arrival
-- docs/maps/map_01_central_command.md §11: Concourse X -10..10, Z 40..80 (ceiling 14, glass side walls) and the
-- Arrival Platform X -80..80, Z 80..130 with its canopy at Y 18 on 6 columns; the rail line (Z 132..148) and the
-- parked train CT-9.
--
-- Passes (docs/07 §2): blockout = concourse shell, platform, canopy and columns, the rail line (ballast, sleepers,
-- rails, buffer stop); structure = the concourse's framed glass walls (curb, mullions every 4, head beam, fascia) and
-- portal, the canopy's girders, rafters and fascia, the platform's yellow edge line and nosing, the back railing, the
-- light fixtures (concourse and canopy strip lights) and the signs (ARRIVALS — PLATFORM 1 with its back plate and rods,
-- the way to the Ops Hall, the station's name over the portal and on the canopy fascia), the parked train;
-- dressed = info screens, benches, turnstiles, the station hologram, the departure board, posters, bins, column
-- fittings, floor text, tactile strip, joints and tile seams.
-- D-102: the line runs X -600..412 (the doc's -600..600 would run into the Bulwark at X 420): a buffer stop ends it.
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new

local RAIL_WEST, RAIL_EAST = -600, 412
local SEGMENTS = { { RAIL_WEST, -100 }, { -100, RAIL_EAST } } -- parts stay under 512 long (docs/07 §5)
local TRAIN_BODY = "#5B6770" -- map_01 §11
local BALLAST = "#6B6660"

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Arrival")
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("Arrival: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Concourse_Floor", -10, 10, 40, 80, 0, 1, ctx.FLOOR)
	local ceiling = BK.ceiling(S, "Concourse_Ceiling", -10.25, 10.25, 41, 80, 14, 1, ctx.CEIL)
	if ctx.level < 2 then
		BK.wallZ(S, "Concourse_Glass_W", 41, 80, -10, 0, 14, 0.5, ctx.GLASS)
		BK.wallZ(S, "Concourse_Glass_E", 41, 80, 10, 0, 14, 0.5, ctx.GLASS)
	end

	local concrete = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
	local platform = BK.floor(S, "Platform", -80, 80, 80, 130, 0, 1, concrete)
	BK.ceiling(S, "Canopy", -80, 80, 84, 128, 18, 1, ctx.ROOF)
	for _, x in ipairs({ -60, 0, 60 }) do
		for _, z in ipairs({ 88, 124 }) do
			BK.column(S, ("CanopyColumn_%d_%d"):format(x + 60, z), V(x, 0, z), 18, 2)
		end
	end
	Builder.railLine(ctx, C)

	if ctx.level >= 2 then
		Builder.structure(ctx, C, Lib)
		Builder.train(ctx, Lib)
	end
	if ctx.level >= 3 then
		Builder.dressConcourse(ctx, C, Lib)
		Builder.dressPlatform(ctx, C, Lib, platform)
		C.tileSeams(ctx, floor, ceiling)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

-- The rail line: ballast (0.5 tall, Slate, with sloped shoulders), sleepers every 3 (WOOD_OLD), two STEEL_LIGHT rails
-- 0.4 x 0.6 at Z 136 and 144, an embankment where the line leaves the hub's ground (X < -420), and a buffer stop.
function Builder.railLine(ctx, C)
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure
	local y0 = C.GROUND_Y
	local ballast = { Color = BALLAST, Material = "Slate" }
	BK.box(S, "Embankment", V(RAIL_WEST, y0 - 6, 128), V(-420, y0, 152), { Color = P.GROUND, Material = "Ground" })
	for i, xs in ipairs(SEGMENTS) do
		local length, cx = xs[2] - xs[1], (xs[1] + xs[2]) / 2
		BK.box(S, "Ballast" .. i, V(xs[1], y0, 133), V(xs[2], y0 + 0.5, 147), ballast)
		-- A wedge is tall at +Z: the north shoulder as is, the south one turned round.
		local n = table.clone(ballast)
		n.Name, n.Size, n.CFrame = "BallastShoulder_N" .. i, V(length, 0.5, 1), CFrame.new(cx, y0 + 0.25, 132.5)
		BK.wedge(S, n)
		local s = table.clone(n)
		s.Name, s.CFrame = "BallastShoulder_S" .. i, CFrame.new(cx, y0 + 0.25, 147.5) * CFrame.Angles(0, math.pi, 0)
		BK.wedge(S, s)
		for _, z in ipairs({ 136, 144 }) do
			BK.box(S, "Rail", V(xs[1], 0.7, z - 0.2), V(xs[2], 1.3, z + 0.2), { Color = P.STEEL_LIGHT, Material = "Metal", Tags = { "Detail" } })
		end
	end
	local wood = { Color = P.WOOD_OLD, Material = "Wood", Tags = { "Detail" } }
	for x = RAIL_WEST + 1.5, RAIL_EAST - 1.5, 3 do
		BK.box(ctx.Detail, "Sleeper", V(x - 0.5, 0.4, 134.5), V(x + 0.5, 0.7, 145.5), wood)
	end
	-- Buffer stop at the east end: a concrete block, two red uprights, a red beam with two buffers, a red lamp.
	local bx = RAIL_EAST
	local red = { Color = P.DANGER_RED, Material = "Metal" }
	BK.box(S, "BufferStop_Block", V(bx, y0, 134), V(bx + 3, 1.4, 146), { Color = P.CONCRETE_DARK, Material = "Concrete" })
	for _, z in ipairs({ 136, 144 }) do
		BK.box(S, "BufferStop_Upright", V(bx + 0.2, 1.4, z - 0.4), V(bx + 1.0, 4.4, z + 0.4), red)
		BK.cyl(ctx.Detail, { Name = "BufferStop_Buffer", Axis = "X", Size = V(1.4, 1.0, 1.0), CFrame = CFrame.new(bx - 0.5, 3.6, z), Color = P.STEEL_LIGHT, Material = "Metal", Tags = { "Detail" } })
	end
	BK.box(S, "BufferStop_Beam", V(bx + 0.1, 3.0, 134.8), V(bx + 1.1, 4.2, 145.2), red)
	BK.box(ctx.Detail, "BufferStop_Lamp", V(bx + 0.3, 4.2, 139.6), V(bx + 0.8, 4.7, 140.4), { Color = P.DANGER_RED, Material = "Neon", Tags = { "Detail" } })
end

function Builder.structure(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }

	-- Concourse glass walls: a concrete curb, glass, STEEL_DARK mullions every 4 and a head beam; the roof's fascia.
	for _, side in ipairs({ { "W", -10, -1 }, { "E", 10, 1 } }) do
		local x, sx, tag = side[2], side[3], side[1]
		BK.box(S, "Concourse_Curb_" .. tag, V(x - 0.4, 0, 41), V(x + 0.4, 1, 80), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		BK.box(S, "Concourse_Glass_" .. tag, V(x - 0.1, 1, 41), V(x + 0.1, 13, 79.4), ctx.GLASS)
		BK.box(S, "Concourse_Head_" .. tag, V(x - 0.4, 13, 41), V(x + 0.4, 14, 80), steel)
		for z = 44, 76, 4 do
			BK.box(S, "Concourse_Mullion_" .. tag, V(x - 0.3, 1, z - 0.15), V(x + 0.3, 13, z + 0.15), steel)
		end
		BK.box(D, "Concourse_Fascia_" .. tag, V(sx * 10.25, 13.4, 41), V(sx * 10.75, 15.6, 80.6), { Color = P.STEEL_DARK, Material = "Metal", Tags = { "Detail" } })
		BK.box(S, "Portal_Post_" .. tag, V(sx * 9.4, 0, 79.4), V(sx * 10.6, 13, 80.6), steel)
	end
	BK.box(S, "Portal_Header", V(-10.75, 13, 79.4), V(10.75, 15.6, 80.6), steel)

	-- Platform edge: the yellow line at Z 129 (1 wide) and a dark nosing.
	local paint = { CanCollide = false, CanQuery = false, CastShadow = false }
	local yellow = table.clone(paint)
	yellow.Color = P.HAZARD_YELLOW
	BK.box(D, "EdgeLine", V(-80, 0, 128.5), V(80, 0.05, 129.5), yellow)
	BK.box(S, "EdgeNosing", V(-80, -0.6, 129.6), V(80, 0.04, 130.2), { Color = P.CONCRETE_DARK, Material = "Concrete" })

	-- Canopy steel: girders on the column lines, rafters every 15, a fascia all round.
	for _, z in ipairs({ 88, 124 }) do
		BK.box(S, "Canopy_Girder", V(-80, 16.4, z - 0.6), V(80, 18, z + 0.6), steel)
	end
	for x = -75, 75, 15 do
		BK.box(S, "Canopy_Rafter", V(x - 0.3, 17.2, 84), V(x + 0.3, 18, 128), steel)
	end
	BK.box(S, "Canopy_Fascia_S", V(-80.4, 17.2, 128), V(80.4, 19.6, 128.4), steel)
	BK.box(S, "Canopy_Fascia_N", V(-80.4, 17.2, 83.6), V(80.4, 19.6, 84), steel)
	BK.box(S, "Canopy_Fascia_W", V(-80.4, 17.2, 84), V(-80, 19.6, 128), steel)
	BK.box(S, "Canopy_Fascia_E", V(80, 17.2, 84), V(80.4, 19.6, 128), steel)
	for i, x in ipairs({ -61.4, 61.4 }) do
		BK.pipeRun(D, "Downpipe" .. i, { V(x, 18.6, 124), V(x, 0.3, 124) }, 0.22, { color = P.STEEL_MID })
	end

	-- The platform's back edge: a railing either side of the concourse (the ends stay open to the yard).
	BK.railing(S, "Railing_W", { V(-80, 0, 80.6), V(-10.6, 0, 80.6) })
	BK.railing(S, "Railing_E", { V(10.6, 0, 80.6), V(80, 0, 80.6) })

	Builder.lightsAndSigns(ctx, C)
end

-- Light fixtures and signage (docs/07 §2: both belong to the structure pass).
function Builder.lightsAndSigns(ctx, C)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- Concourse strip lights, their housings against the ceiling (Y 14).
	for i, z in ipairs({ 46, 56, 66, 76 }) do
		C.fixture(ctx, "Strip" .. i, V(0, 13.9, z), V(0.3, 0.15, 6), { Brightness = 1, Range = 16 })
	end

	-- Strip lights under the canopy: two rows of eight (06 §5 strips, lit at every preset; HubLight dims at night).
	-- Mounted on the slab's underside (Y 18): the housing spans Y 17.89..18.14, like the concourse strips.
	for row, z in ipairs({ 98, 114 }) do
		for i, x in ipairs({ -70, -50, -30, -10, 10, 30, 50, 70 }) do
			C.fixture(ctx, ("CanopyStrip%d_%d"):format(row, i), V(x, 17.9, z), V(8, 0.15, 0.4), { Brightness = 1, Range = 20 })
		end
	end

	-- Signs: "ARRIVALS — PLATFORM 1" hanging near the Ops Hall end (its back points the way in); the station's name over
	-- the portal, seen from the platform and the train.
	for _, x in ipairs({ -5.5, 5.5 }) do
		BK.box(D, "SignRod", V(x - 0.06, 11.8, 44.94), V(x + 0.06, 14, 45.06), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	BK.box(F, "Sign_Back", V(-6.2, 10.1, 44.9), V(6.2, 11.9, 45.1), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.sign(D, "Sign_Arrivals", BK.lookAlong(V(0, 11, 44.84), V(0, 0, -1)), Vector2.new(12, 1.6), "ARRIVALS — PLATFORM 1", { light = true })
	BK.sign(D, "Sign_ToOps", BK.lookAlong(V(0, 11, 45.16), V(0, 0, 1)), Vector2.new(12, 1.6), "OPS HALL · FRAME HANGAR ↑", { textColor = P.SIGN_WHITE, bgColor = P.SLATE })
	BK.sign(D, "Sign_Station", BK.lookAlong(V(0, 14.3, 80.66), V(0, 0, 1)), Vector2.new(17, 1.8), "HALDEN CENTRAL COMMAND", { light = true })

	-- The station's name on the canopy's front fascia, seen from the train.
	for i, x in ipairs({ -40, 40 }) do
		BK.sign(D, "Sign_Fascia" .. i, BK.lookAlong(V(x, 18.4, 128.46), V(0, 0, 1)), Vector2.new(22, 1.8), "HALDEN CENTRAL COMMAND", { light = true })
	end
end

-- The parked train CT-9 (map_01 §11): 5 cars 40 long, 2 apart, X -104..104, Z 134..146, on two bogies each; body
-- #5B6770 with an amber stripe, dark windows with lit interior strips, two doors per side, a cab at the east end with a
-- slanted nose. Car models under Props.Train_CT9.
function Builder.train(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local train = BK.model(ctx.Props, "Train_CT9")
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(base, extra)
		local t = table.clone(base)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local body = { Color = TRAIN_BODY, Material = "Metal" }
	local dark = { Color = P.STEEL_DARK, Material = "Metal" }
	local glass = with(soft, { Color = P.KICKPLATE, Material = "Glass" })
	local strip = with(soft, { Color = P.LIGHT_NEUTRAL, Material = "Neon" })
	local door = with(soft, { Color = BK.darken(BK.hex(TRAIN_BODY), 0.12), Material = "Metal" })
	local amber = with(soft, { Color = P.AMBER })

	for i = 1, 5 do
		local x0 = -104 + (i - 1) * 42
		local cab = i == 5
		local k = Lib.kit(train, ("Car%d"):format(i), CFrame.new(x0 + 20, 0, 140))
		local bodyLength = if cab then 34 else 40
		local bodyX = if cab then -3 else 0
		local shell = k.box("Body", V(bodyLength, 8, 11.6), V(bodyX, 6.8, 0), body)
		k.box("Roof", V(bodyLength - 0.4, 0.6, 9.6), V(bodyX, 11.1, 0), body)
		k.wedge("Eave_N", V(bodyLength - 0.4, 0.6, 1), CFrame.new(bodyX, 11.1, -5.3), body)
		k.wedge("Eave_S", V(bodyLength - 0.4, 0.6, 1), CFrame.new(bodyX, 11.1, 5.3) * CFrame.Angles(0, math.pi, 0), body)
		for _, sz in ipairs({ -1, 1 }) do
			local z = sz * 5.84
			k.box("Stripe", V(40, 0.5, 0.06), V(0, 4.3, sz * 5.83), amber)
			local windows = { { -18.6, -13.6 }, { -8, 8 } }
			if not cab then
				table.insert(windows, { 13.6, 18.6 })
			end
			for _, w in ipairs(windows) do
				local len, cx = w[2] - w[1], (w[1] + w[2]) / 2
				k.box("Window", V(len, 2.6, 0.08), V(cx, 7.4, z), glass)
				k.box("InteriorStrip", V(len - 0.4, 0.14, 0.04), V(cx, 8.5, sz * 5.89), strip)
			end
			for _, mx in ipairs({ -4, 0, 4 }) do
				k.box("Mullion", V(0.3, 2.6, 0.1), V(mx, 7.4, sz * 5.86), with(soft, body))
			end
			for _, dx in ipairs({ -11, 11 }) do
				k.box("Door", V(3.4, 6.4, 0.08), V(dx, 6.0, z), door)
				k.box("DoorSeam", V(0.08, 6.4, 0.1), V(dx, 6.0, sz * 5.86), with(soft, { Color = P.HAZARD_BLACK }))
				k.box("DoorWindow", V(2.6, 1.8, 0.1), V(dx, 7.6, sz * 5.87), glass)
			end
		end
		for _, bx in ipairs({ -13, 13 }) do
			k.box("Bogie", V(8, 1, 9.6), V(bx, 2.3, 0), dark)
			for _, wx in ipairs({ -2.4, 2.4 }) do
				for _, wz in ipairs({ -4, 4 }) do
					k.cyl("Wheel", "Z", V(1.8, 1.8, 0.4), V(bx + wx, 2.2, wz), with(soft, { Color = P.HAZARD_BLACK, Material = "Metal" }))
				end
			end
		end
		k.box("Skirt", V(17, 1.2, 10.6), V(0, 2.2, 0), with(soft, dark))
		for _, ex in ipairs({ -8, if cab then 4 else 8 }) do
			k.box("RoofUnit", V(6, 0.8, 4), V(ex, 11.8, 0), with(soft, { Color = P.STEEL_MID, Material = "Metal" }))
		end
		if i < 5 then
			k.box("Gangway", V(2.2, 7, 6), V(21, 6.6, 0), with(soft, { Color = P.HAZARD_BLACK, Material = "Fabric" }))
		end
		if i == 1 then
			for _, z in ipairs({ -3.5, 3.5 }) do
				k.box("TailLight", V(0.1, 0.5, 0.8), V(-20.04, 4.6, z), with(soft, { Color = P.DANGER_RED, Material = "Neon" }))
			end
		end
		if cab then
			-- The nose: a lower block and a wedge sloping down to +X (a wedge is tall at +Z; turned -90° about Y).
			k.box("NoseLower", V(6, 3.2, 11.6), V(17, 4.4, 0), body)
			k.wedge("NoseSlope", V(11.6, 4.8, 6), CFrame.new(17, 8.4, 0) * CFrame.Angles(0, -math.pi / 2, 0), body)
			local n = V(4.8, 6, 0).Unit
			local mid = V(17, 8.4, 0) + V(6, -4.8, 0).Unit * -0.6 + n * 0.06
			k.part("Windshield", V(9.4, 0.1, 4.4), CFrame.fromMatrix(mid, V(0, 0, 1), n), with(soft, { Color = P.KICKPLATE, Material = "Glass" }))
			for _, z in ipairs({ -3.5, 3.5 }) do
				k.box("Headlight", V(0.1, 0.6, 1.2), V(20.04, 4.6, z), with(soft, { Color = P.LIGHT_COOL, Material = "Neon" }))
			end
			k.box("NoseStripe", V(0.06, 0.5, 11.6), V(20.03, 3.4, 0), amber)
		end
		-- Car numbers under the stripe on both sides (painted): Y 3.1..3.9, below the stripe (4.05..4.55). On the cab's
		-- platform side (Front, its x = 0 at the +X end) the number starts at X ~8.2, clear of the door at X 9.3..12.7.
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Lib.gui(shell, face, 0.6, 50)
			gui.Name = "Number_" .. face.Name
			local nx = if cab and face == Enum.NormalId.Front then 0.17 else 0.04
			Lib.label(gui, ("CT-9 · %02d"):format(i), nx, 0.8625, 0.22, 0.1, { font = Lib.FONT.header, color = P.SIGN_WHITE })
		end
		k.finish(shell)
	end
	train.PrimaryPart = train:FindFirstChildWhichIsA("BasePart", true)
end

-- A litter bin: a STEEL_MID cylinder with a dark lid ring.
local function bin(ctx, parent, name, x, z)
	local BK, P = ctx.BK, ctx.P
	BK.cyl(parent, { Name = name, Axis = "Y", Size = V(1.2, 2.4, 1.2), CFrame = CFrame.new(x, 1.2, z), Color = P.STEEL_MID, Material = "Metal" })
	BK.cyl(parent, { Name = name .. "_Lid", Axis = "Y", Size = V(1.3, 0.2, 1.3), CFrame = CFrame.new(x, 2.45, z), Color = P.STEEL_DARK, Material = "Metal", Tags = { "Detail" } })
end

function Builder.dressConcourse(ctx, C, Lib)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- Two info pylons with the train times (map_01 §11, its text exactly).
	for i, s in ipairs({ { -8.6, 56, 1 }, { 8.6, 64, -1 } }) do
		local x, z, face = s[1], s[2], s[3]
		BK.box(F, "InfoPylon" .. i, V(x - 0.5, 0, z - 1.4), V(x + 0.5, 9, z + 1.4), { Color = P.STEEL_DARK, Material = "Metal" })
		BK.box(D, "InfoPylon_Cap" .. i, V(x - 0.6, 9, z - 1.5), V(x + 0.6, 9.3, z + 1.5), with({ Color = P.AMBER }))
		BK.screen(D, "InfoScreen" .. i, BK.lookAlong(V(x + face * 0.56, 6.6, z), V(face, 0, 0)), Vector2.new(2.6, 3.4), {
			text = "PLATFORM 1\n\nCT-6 HALDEN CENTRAL → CORROW 07:40 · ON TIME",
		})
	end

	-- Benches along the glass, facing in; bins.
	for i, s in ipairs({ { -8.8, 46, "+X" }, { -8.8, 66, "+X" }, { 8.8, 48, "-X" }, { 8.8, 56, "-X" } }) do
		Lib.Bench(F, CFrame.new(s[1], 0, s[2]) * Lib.FACE[s[3]], { name = "Bench" .. i })
	end
	bin(ctx, F, "Bin1", -8.9, 71.5)
	bin(ctx, F, "Bin2", 8.9, 42.5)

	-- Turnstile gates at Z 76: decorative and passable (nothing collides), a tripod arm and an amber reader each.
	for i, x in ipairs({ -7.5, -2.5, 2.5, 7.5 }) do
		local m = BK.model(F, "Turnstile" .. i)
		BK.box(m, "Body", V(x - 0.4, 0, 74.5), V(x + 0.4, 3.2, 77.5), with({ Color = P.STEEL_MID, Material = "Metal" }))
		BK.box(m, "Cap", V(x - 0.45, 3.2, 74.45), V(x + 0.45, 3.35, 77.55), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		BK.box(m, "Reader", V(x - 0.3, 3.35, 74.7), V(x + 0.3, 3.45, 75.3), with(Lib.glow))
		local hub = V(x + 0.55, 2.6, 76)
		BK.cyl(m, with({ Name = "Hub", Axis = "X", Size = V(0.3, 0.5, 0.5), CFrame = CFrame.new(hub), Color = P.STEEL_LIGHT, Material = "Metal" }))
		for j, tip in ipairs({ V(1.6, 0, 0), V(0.9, -1.1, 0.6), V(0.9, -1.1, -0.6) }) do
			BK.beam(m, "Arm" .. j, hub, hub + tip, 0.14, 0.14, with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
		end
	end

	-- The station hologram over a kiosk west of the walking line (NAV_CONC -> NAV_ARR_IN passes X ~1 here).
	BK.box(F, "MapKiosk", V(-6.5, 0, 64.2), V(-2.5, 1.2, 65.8), { Color = P.STEEL_DARK, Material = "Metal" })
	for i, z in ipairs({ 64.2, 65.8 }) do
		BK.box(D, "MapKiosk_Rim" .. i, V(-6.55, 1.1, z - 0.05), V(-2.45, 1.22, z + 0.05), with(Lib.glow))
	end
	-- One-sided: its arrows are for someone coming off the platform, facing north.
	Lib.HoloPanel(F, CFrame.new(-4.5, 3.6, 65) * Lib.FACE["+Z"], {
		name = "Holo_StationMap", size = Vector2.new(4.4, 3), emitter = 0.9, backFace = false,
		title = "HALDEN CENTRAL COMMAND", lines = { "↑ OPS HALL · FRAME HANGAR", "← BRIEFING · PILOT QUARTERS", "→ MEDICAL · EQUIPMENT", "↓ PLATFORM 1" },
	})

	BK.floorText(D, "Floor_Platform", V(0, 0, 70), Vector2.new(9, 2.2), "PLATFORM 1", { textUp = V(0, 0, 1) })
end

function Builder.dressPlatform(ctx, C, Lib, platform)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- The departure board, double-sided, hanging over the aisle.
	BK.box(F, "Board_Frame", V(-5.4, 12.3, 105.85), V(5.4, 15.7, 106.15), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	for _, x in ipairs({ -4.5, 4.5 }) do
		BK.box(D, "Board_Rod", V(x - 0.06, 15.7, 105.94), V(x + 0.06, 18, 106.06), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	for _, dir in ipairs({ -1, 1 }) do
		BK.screen(D, "Board_Screen", BK.lookAlong(V(0, 14, 106 + dir * 0.16), V(0, 0, dir)), Vector2.new(10, 3), {
			text = "PLATFORM 1 · DEPARTURES\nCT-6 HALDEN CENTRAL → CORROW 07:40 · ON TIME\nCT-9 · NOT IN SERVICE",
		})
	end

	-- Benches facing the line, bins between them.
	for i, x in ipairs({ -70, -44, -20, 20, 44, 70 }) do
		Lib.Bench(F, CFrame.new(x, 0, 108) * Lib.FACE["+Z"], { name = "Bench" .. i })
	end
	for i, x in ipairs({ -57, -32, 32, 57 }) do
		bin(ctx, F, "Bin" .. i, x, 108)
	end

	-- Poster boards along the back railing, facing the platform.
	local lines = { "EVERY WALL WAS BUILT BY SOMEONE WHO CARED.", "REPORT ANOMALIES. TRUST YOUR DIRECTORATE.", "ASH IS A MEMORY. THE BULWARK IS A PROMISE.", "THE FRAME STANDS. HUMANITY STANDS." }
	for i, x in ipairs({ -60, -30, 30, 60 }) do
		BK.box(F, "PosterBoard" .. i, V(x - 1.9, 2.4, 81.3), V(x + 1.9, 7.4, 81.6), { Color = P.STEEL_DARK, Material = "Metal" })
		for _, px in ipairs({ x - 1.6, x + 1.6 }) do
			BK.box(D, "PosterBoard_Leg", V(px - 0.12, 0, 81.33), V(px + 0.12, 2.4, 81.57), with({ Color = P.STEEL_DARK, Material = "Metal" }))
		end
		Lib.Poster(F, CFrame.new(x, 4.9, 81.6) * Lib.FACE["+Z"], { name = "Poster" .. i, text = lines[i] })
	end

	-- Column fittings: a PA horn on every column, a camera on the middle pair, extinguishers on the outer south pair.
	for _, x in ipairs({ -60, 0, 60 }) do
		for _, z in ipairs({ 88, 124 }) do
			local face = if z == 88 then 1 else -1
			local zf = z + face * 1.05
			BK.box(D, "PA_Horn", V(x - 0.4, 12.6, math.min(zf, zf + face * 0.7)), V(x + 0.4, 13.4, math.max(zf, zf + face * 0.7)), with({ Color = P.STEEL_MID, Material = "Metal" }))
			if x == 0 then
				BK.box(D, "Camera_Mount", V(x - 0.15, 14.8, math.min(zf, zf + face * 0.6)), V(x + 0.15, 15.0, math.max(zf, zf + face * 0.6)), with({ Color = P.STEEL_DARK, Material = "Metal" }))
				BK.box(D, "Camera", V(x - 0.3, 14.3, math.min(zf + face * 0.4, zf + face * 1.4)), V(x + 0.3, 14.8, math.max(zf + face * 0.4, zf + face * 1.4)), with({ Color = P.MEDICAL_WHITE }))
			end
		end
	end
	for i, x in ipairs({ -60, 60 }) do
		Lib.ExtinguisherStation(F, CFrame.new(x, 4.2, 122.95) * Lib.FACE["-Z"], { name = "Extinguisher" .. i })
	end

	-- Edge warnings: a tactile strip inside the yellow line and painted text; hazard bands across the platform's ends.
	BK.box(D, "TactileStrip", V(-80, 0, 127.7), V(80, 0.04, 128.4), with({ Color = P.KICKPLATE }))
	for i, x in ipairs({ -50, 0, 50 }) do
		BK.floorText(D, "Floor_StandBack" .. i, V(x, 0, 126.9), Vector2.new(16, 1.1), "STAND BEHIND THE YELLOW LINE", { textUp = V(0, 0, 1) })
	end
	for i, x in ipairs({ -79.2, 79.2 }) do
		BK.hazardStripe(D, "EndStripe" .. i, CFrame.new(x, 0, 104.4) * CFrame.Angles(0, math.pi / 2, 0), 47, 1.6)
	end

	-- Expansion joints on the platform every 16, sunk to Y 0.03: under the edge line and hazard bands (0.05) so they never
	-- fight them (as in the hangar, Shell.lua).
	BK.seams(platform, Enum.NormalId.Top, 16, { width = 0.2, depth = 0.06, color = P.CONCRETE_DARK, parent = D, name = "Platform_Joints" })
end

return Builder
