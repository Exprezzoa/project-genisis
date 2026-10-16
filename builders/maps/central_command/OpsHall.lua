--!nonstrict
-- builders/maps/central_command/OpsHall.lua  ->  DevTools.Builders.CentralCommand.OpsHall
-- docs/maps/map_01_central_command.md §3: X -60..60, Z -40..40, ceiling Y 36, roof top Y 38, mezzanine Y 16.
--
-- Passes (docs/07 §2):
--   blockout   shell, mezzanine with stairs and railings, the three offices, four columns, grey stand-ins carrying the
--              prompts and blocking the floor (holo-table, status kiosk, poster, consoles and chairs)
--   structure  + wall finishes, exterior pilasters, column bands, the ceiling's lining and beams, the light strips of
--              06 §5 and six pendants (the strips can't reach the floor), the soffit and downlights under the
--              mezzanine, glass in the mezzanine railing, the offices' mullions, doorway strips and signs
--   dressed    + the holo-table and its projector ring, consoles C1-C8 and chairs, the status wall and its kiosk,
--              banners, posters, the Division emblem, Vale's office and the two side offices, the bay boards under
--              the mezzanine, cable runs, vents, seams
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4 -- BK.wallWithOpenings' door-frame trim

-- map_01 §3: consoles face north (operators look at the status wall); screen lines are ours.
local CONSOLES = {
	{ "C1", -36, 14, { "HALDEN OVERWATCH", "EMBER SQ · STANDBY", "VOICE: OKAFOR, I." } },
	{ "C2", -24, 14, { "CORRIDOR 7 · TRAFFIC", "CT-9 · PLATFORM 1", "CONVOYS 3 · ON TIME" } },
	{ "C3", 24, 14, { "RELAY 7-E", "NO CARRIER", "RETRY 14 · FAILED" }, alert = true, holo = "RELAY 7-E" },
	{ "C4", 36, 14, { "OUTPOST 07 · GREYWATCH", "LAST REPORT 01:10", "WINDOW +6H · OVERDUE" }, alert = true, holo = "OUTPOST 07" },
	{ "C5", -36, 26, { "ASH INDEX 4 · EAST", "WIND 12 KM/H · N", "VISIBILITY 2.1 KM" } },
	{ "C6", -24, 26, { "BULWARK GATES", "G1-G4 · SEALED", "PATROLS 6 · NOMINAL" } },
	{ "C7", 24, 26, { "FRAME CORPS · ROSTER", "EMBER 1-2 · READY", "BAY 03 · MAINT." } },
	{ "C8", 36, 26, { "SCIENCE DIV · LIAISON", "NO TRAFFIC", "CLEARANCE 3 REQ." } },
}

-- The status wall's eight outposts (map_01 §3; names from 02 §3 where the lore has one).
local OUTPOSTS = { { "01", "" }, { "02", "" }, { "03", "" }, { "04", "" }, { "05", "LOWMARCH" }, { "06", "" }, { "07", "GREYWATCH" }, { "08", "" } }
local TICKER = "THE FRAME STANDS. HUMANITY STANDS.   ·   DISCIPLINE IS SURVIVAL.   ·   EVERY WALL WAS BUILT BY SOMEONE WHO CARED.   ·   REPORT ANOMALIES. TRUST YOUR DIRECTORATE.   ·   ASH IS A MEMORY. THE BULWARK IS A PROMISE.   ·   "

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "OpsHall")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay
	local full, dressed = ctx.level >= 2, ctx.level >= 3
	local Lib = opts.Props
	if full and not Lib then
		error("OpsHall: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", -60, 60, -40, 40, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Roof", -61, 61, -41, 41, 36, 2, ctx.ROOF)

	-- North and south walls are exterior (2 thick) and own the corners; west and east are 1 thick
	-- (the doc puts the posters at X ±59.4, just proud of a wall face at ±59.5).
	BK.wallWithOpenings(S, "Wall_N", "X", -61, 61, -40, 0, 36, C.EXT, { { from = -15, to = 15, y1 = 0, y2 = 14 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_S", "X", -61, 61, 40, 0, 36, C.EXT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.EXT)
	BK.wallWithOpenings(S, "Wall_W", "Z", -39, 39, -60, 0, 36, C.INT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.INT)
	BK.wallWithOpenings(S, "Wall_E", "Z", -39, 39, 60, 0, 36, C.INT, { { from = -10, to = 10, y1 = 0, y2 = 14 } }, ctx.INT)

	-- Mezzanine (floor top Y 16) with its two stairs: 16 steps along X in the lane Z -24..-18.
	local mezz = BK.floor(S, "Mezzanine", -59.5, 59.5, -39, -24, 16, 1, ctx.FLOOR)
	for _, side in ipairs({ { "W", -1 }, { "E", 1 } }) do
		local name, sx = side[1], side[2]
		BK.stairs(S, "MezzStair_" .. name, V(sx * 30, 0, -21), V(sx, 0, 0), 6, 16)
		BK.floor(S, "MezzLanding_" .. name, math.min(sx * 54, sx * 59.5), math.max(sx * 54, sx * 59.5), -24, -18, 16, 1, ctx.FLOOR)
		BK.railing(S, "MezzLandingRail_" .. name, { V(sx * 59.5, 16, -18.15), V(sx * 54, 16, -18.15) })
	end
	BK.railing(S, "MezzRail", { V(-54, 16, -24.15), V(54, 16, -24.15) })

	-- Offices on the mezzanine, Z -40..-30 behind a glass front at Z -30 (partitions 10 tall; D-026).
	local frosted = { Color = "#C9D3DA", Material = "Glass", Transparency = 0.3 }
	local function office(name, x1, x2, doorFrom, doorTo, glass)
		BK.wallWithOpenings(S, name .. "_Front", "X", x1, x2, -30, 16, 26, 0.5, { { from = doorFrom, to = doorTo, y1 = 16, y2 = 16 + C.DOOR_H } }, glass)
		BK.wallZ(S, name .. "_SideW", -39, -30, x1, 16, 26, C.INT, ctx.INT)
		BK.wallZ(S, name .. "_SideE", -39, -30, x2, 16, 26, C.INT, ctx.INT)
	end
	office("Office_W", -56, -24, -42.5, -37.5, frosted)
	office("Office_Vale", -20, 20, -2.5, 2.5, ctx.GLASS) -- doc: gap X -2..2; widened to 5 (acceptance test 2)
	office("Office_E", 24, 56, 37.5, 42.5, frosted)

	-- 4 freestanding columns 3 x 36 x 3, CONCRETE_LIGHT (map_01 §3).
	for i, at in ipairs({ V(-46, 0, -12), V(46, 0, -12), V(-46, 0, 34), V(46, 0, 34) }) do
		BK.column(S, "Column_" .. i, at, 36, 3, { color = P.CONCRETE_LIGHT, material = "Concrete" })
	end

	local lining
	if full then
		lining = Builder.structure(ctx, C, Lib)
	end
	if dressed then
		Builder.dress(ctx, C, Lib)
		C.tileSeams(ctx, floor, lining)
		BK.seams(mezz, Enum.NormalId.Top, 8, { width = 0.15, color = P.KICKPLATE, parent = ctx.Detail, name = "Mezzanine_Tiles" })
	else
		Builder.standIns(ctx, C)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

---------------------------------------------------------------------------------------------------
-- Blockout and structure: stand-ins for the props that carry prompts or block the floor
---------------------------------------------------------------------------------------------------
function Builder.standIns(ctx, C)
	local BK, P, G = ctx.BK, ctx.P, ctx.Gameplay
	local holo = BK.cyl(G, {
		Name = "HoloTable_StandIn",
		Axis = "Y",
		Size = V(20, 3.2, 20),
		Position = V(0, 1.6, 0),
		Color = P.STEEL_DARK,
		Attributes = { StandIn = true },
	})
	BK.prompt(holo, "INT_HOLO", "Look", { dist = 16 }) -- measured from the table's center (radius 10)
	local kiosk = C.standIn(ctx, "StatusKiosk_StandIn", V(-1, 0, -20.5), V(1, 3.5, -19.5))
	BK.prompt(kiosk, "INT_STATUS_WALL", "Look")
	local poster = C.standIn(ctx, "Poster_StandIn", V(-59.5, 4, 18.5), V(-59.4, 8, 21.5), { Color = P.SLATE_DEEP })
	BK.prompt(poster, "INT_POSTER", "Look")
	-- Consoles C1-C8 facing north, a chair behind each (docs/07 §6: Console 6 x 3 x 2.5, Chair 2 x 3.6 x 2; the seat
	-- 1.0 up is ours, so seated feet reach the floor). The seated NPCs sit on these chairs (Config/NPCs; D-081).
	for _, c in ipairs(CONSOLES) do
		local name, x, z = c[1], c[2], c[3]
		C.standIn(ctx, "Console_" .. name .. "_StandIn", V(x - 3, 0, z - 1.25), V(x + 3, 3, z + 1.25), { Color = P.STEEL_DARK })
		C.standIn(ctx, "Chair_" .. name .. "_StandIn", V(x - 1, 0, z + 2), V(x + 1, 1.0, z + 4), { Color = P.FABRIC_DARK })
		C.standIn(ctx, "ChairBack_" .. name .. "_StandIn", V(x - 1, 1.0, z + 3.7), V(x + 1, 3.6, z + 4), { Color = P.FABRIC_DARK })
	end
end

function Builder.structure(ctx, C, Lib)
	local BK, P, S, L = ctx.BK, ctx.P, ctx.Structure, ctx.Lighting
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local opening = function(a, b)
		return { from = a - TRIM, to = b + TRIM, y1 = 0, y2 = 14 + TRIM }
	end

	-- Interior faces. The north face is split by the mezzanine: below it (to the soffit at 15) and above it.
	C.face(ctx, "FaceS", V(-59.5, 0, 39), V(59.5, 0, 39), V(0, 0, -1), { kind = "interior", top = 36, gaps = { opening(-10, 10) } })
	C.face(ctx, "FaceW", V(-59.5, 0, -39), V(-59.5, 0, 39), V(1, 0, 0), { kind = "interior", top = 36, gaps = { opening(-10, 10) } })
	C.face(ctx, "FaceE", V(59.5, 0, -39), V(59.5, 0, 39), V(-1, 0, 0), { kind = "interior", top = 36, gaps = { opening(-10, 10) } })
	C.face(ctx, "FaceN_Low", V(-59.5, 0, -39), V(59.5, 0, -39), V(0, 0, 1), { kind = "interior", top = 15, gaps = { opening(-15, 15) } })
	C.face(ctx, "FaceN_High", V(-59.5, 16, -39), V(59.5, 16, -39), V(0, 0, 1), { kind = "interior", top = 20 })
	C.face(ctx, "FaceW_Mezz", V(-59.5, 16, -39), V(-59.5, 16, -18), V(1, 0, 0), { kind = "interior", top = 20, ceilTrim = false, seams = false })
	C.face(ctx, "FaceE_Mezz", V(59.5, 16, -39), V(59.5, 16, -18), V(-1, 0, 0), { kind = "interior", top = 20, ceilTrim = false, seams = false })
	-- Exterior faces outside the gate corridor (X -16..16, roof 17) and the concourse (X -10..10, roof 15).
	C.face(ctx, "Ext_N", V(-61, 0, -41), V(61, 0, -41), V(0, 0, -1), { kind = "exterior", top = 38, gaps = { { from = -16, to = 16, y1 = 0, y2 = 17 } } })
	C.face(ctx, "Ext_S", V(-61, 0, 41), V(61, 0, 41), V(0, 0, 1), { kind = "exterior", top = 38, gaps = { { from = -10.5, to = 10.5, y1 = 0, y2 = 15 } } })

	-- Column bands: SLATE at Y 3 (map_01 §3).
	for i, at in ipairs({ V(-46, 0, -12), V(46, 0, -12), V(-46, 0, 34), V(46, 0, 34) }) do
		BK.box(ctx.Detail, "ColumnBand_" .. i, at + V(-1.55, 2.8, -1.55), at + V(1.55, 3.2, 1.55), with({ Color = P.SLATE }))
	end

	-- Ceiling: a #8A9096 lining under the roof and five steel beams across it.
	local lining = BK.box(S, "CeilingLining", V(-59.5, 35.9, -39), V(59.5, 36, 39), { Color = "#8A9096", CastShadow = false })
	for i, x in ipairs({ -48, -24, 0, 24, 48 }) do
		BK.box(S, "Beam" .. i, V(x - 0.75, 34, -39), V(x + 0.75, 35.9, 39), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	end

	-- Light strips (06 §5, map_01 §3): 0.4 x 0.2 x 16 along Z, rows at Z -14, 0, 14, 28, every 12 along X at Y 35.5,
	-- SurfaceLight down LIGHT_NEUTRAL 1.2 / range 24 / angle 120, one strip in three with shadows.
	local n = 0
	for _, z in ipairs({ -14, 0, 14, 28 }) do
		for x = -54, 54, 12 do
			n += 1
			C.fixture(ctx, ("Strip_%02d"):format(n), V(x, 35.5, z), V(0.4, 0.2, 16), { Brightness = 1.2, Range = 24, Angle = 120, Shadows = n % 3 == 0 })
		end
	end
	-- Eight pendants down to Y 20 so light reaches the floor (06 §5: tall spaces need pendants), two with shadows.
	-- The north pair stands at X +-24 (at +-14 one hid the status wall's Outpost 07 card from the hall's middle);
	-- the south pair lights the entrance.
	for i, p in ipairs({ { -30, 6 }, { 30, 6 }, { -30, 24 }, { 30, 24 }, { -24, -8 }, { 24, -8 }, { -12, 30 }, { 12, 30 } }) do
		local x, z = p[1], p[2]
		BK.box(L, ("Pendant%d_Cable"):format(i), V(x - 0.06, 21, z - 0.06), V(x + 0.06, 35.9, z + 0.06), with({ Color = P.HAZARD_BLACK }))
		BK.cyl(L, with({ Name = ("Pendant%d_Shade"):format(i), Axis = "Y", Size = V(3.2, 1.2, 3.2), Position = V(x, 20.5, z), Color = P.STEEL_DARK, Material = "Metal" }))
		BK.cyl(L, with({ Name = ("Pendant%d_Disc"):format(i), Axis = "Y", Size = V(2.6, 0.08, 2.6), Position = V(x, 19.87, z), Color = P.LIGHT_NEUTRAL, Material = "Neon" }))
		local emitter = BK.box(L, ("Pendant%d"):format(i), V(x - 0.2, 19.6, z - 0.2), V(x + 0.2, 19.8, z + 0.2), with({ Transparency = 1 }))
		BK.light(emitter, "Spot", { Color = P.LIGHT_NEUTRAL, Brightness = 1.4, Range = 32, Angle = 80, Face = Enum.NormalId.Bottom, Shadows = i <= 2, Tags = { "HubLight" } })
	end

	-- Under the mezzanine: a soffit and five downlight panels.
	BK.box(S, "Soffit", V(-59.5, 14.8, -39), V(59.5, 15, -24), { Color = "#8A9096", CastShadow = false, CanCollide = false })
	for i, x in ipairs({ -40, -20, 0, 20, 40 }) do
		C.fixture(ctx, "Downlight" .. i, V(x, 14.7, -31.5), V(3, 0.15, 3), { Brightness = 0.9, Range = 16 })
	end

	-- Glass infill in the mezzanine railings (map_01 §3: glass infill panels).
	local glass = with({ Color = P.GLASS, Material = "Glass", Transparency = 0.55 })
	for i = 0, 8 do
		local x1 = -53.8 + i * 12
		BK.box(S, "MezzRailGlass" .. i, V(x1, 16.4, -24.2), V(math.min(x1 + 11.8, 53.8), 19.2, -24.1), glass)
	end
	for _, sx in ipairs({ -1, 1 }) do
		BK.box(S, "MezzLandingGlass_" .. (if sx < 0 then "W" else "E"), V(math.min(sx * 54.2, sx * 59.3), 16.4, -18.2), V(math.max(sx * 54.2, sx * 59.3), 19.2, -18.1), glass)
	end

	-- The offices' fronts: mullions every 4 (not in the doorways), a head rail and a sill rail.
	local frame = { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CastShadow = false }
	for _, o in ipairs({ { -56, -24, -42.5, -37.5 }, { -20, 20, -2.5, 2.5 }, { 24, 56, 37.5, 42.5 } }) do
		local x1, x2, d1, d2 = o[1], o[2], o[3], o[4]
		BK.box(ctx.Detail, "OfficeHead", V(x1, 25.6, -30.35), V(x2, 26, -29.65), frame)
		for _, seg in ipairs({ { x1, d1 }, { d2, x2 } }) do
			BK.box(ctx.Detail, "OfficeSill", V(seg[1], 16, -30.35), V(seg[2], 16.4, -29.65), frame)
		end
		for x = x1 + 4, x2 - 4, 4 do
			if x < d1 - 0.4 or x > d2 + 0.4 then
				BK.box(ctx.Detail, "OfficeMullion", V(x - 0.15, 16, -30.35), V(x + 0.15, 25.6, -29.65), frame)
			end
		end
	end

	-- Doorway strips (open passages, map_01 §2) and the hall's direction signs. No signs on the doorways' outer
	-- sides: the corridors and the concourse are 14 tall, as tall as the openings.
	BK.door(S, "Doorway_S", CFrame.new(0, 0, 40) * Lib.FACE["+Z"], 20, 14, { leaf = false, wallThickness = 2 })
	BK.door(S, "Doorway_W", CFrame.new(-60, 0, 0) * Lib.FACE["-X"], 20, 14, { leaf = false })
	BK.door(S, "Doorway_E", CFrame.new(60, 0, 0) * Lib.FACE["+X"], 20, 14, { leaf = false })
	BK.sign(ctx.Detail, "Sign_West", BK.lookAlong(V(-59.4, 16.6, 0), V(1, 0, 0)), Vector2.new(16, 1.4), "← BRIEFING ROOM ONE · PILOT QUARTERS")
	BK.sign(ctx.Detail, "Sign_East", BK.lookAlong(V(59.4, 16.6, 0), V(-1, 0, 0)), Vector2.new(16, 1.4), "MEDICAL · EQUIPMENT · OBSERVATION DECK →")
	-- The way north to the hangar, under the mezzanine: a sign hung from the mezzanine's edge.
	for _, x in ipairs({ -9, 9 }) do
		BK.box(ctx.Detail, "HangarSign_Rod", V(x - 0.08, 13.9, -24.66), V(x + 0.08, 14.8, -24.5), with({ Color = P.STEEL_DARK }))
	end
	BK.sign(ctx.Detail, "Sign_Hangar", BK.lookAlong(V(0, 13.15, -24.58), V(0, 0, 1)), Vector2.new(22, 1.5), "FRAME HANGAR — AUTHORIZED PERSONNEL", { light = true })
	return lining
end

---------------------------------------------------------------------------------------------------
-- Dressed
---------------------------------------------------------------------------------------------------
function Builder.statusWall(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local cf = CFrame.new(0, 27, -38.85) * Lib.FACE["+Z"]
	BK.part(F, { Name = "StatusWall_Bezel", Size = V(81, 15, 0.3), CFrame = cf * CFrame.new(0, 0, 0.12), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CastShadow = false })
	local screen = BK.part(F, {
		Name = "StatusWall", Size = V(80, 14, 0.2), CFrame = cf, Color = Lib.SCREEN_BASE, Material = "Neon", Transparency = 0.3,
		CanCollide = false, CanQuery = false, CastShadow = false, Tags = { "StatusWall" },
	})
	BK.light(screen, "Surface", { Face = Enum.NormalId.Front, Color = P.AMBER, Brightness = 0.8, Range = 30, Tags = { "HubLight" } })
	local gui = Lib.gui(screen, Enum.NormalId.Front, 0, 20)
	gui.Name = "ScreenGui"
	Lib.rect(gui, 0, 0, 1, 1, Lib.SCREEN_BASE, 0.2, "Back")
	Lib.label(gui, "THIRD FRONTIER FRAME DIVISION — OPERATIONAL STATUS", 0.02, 0.025, 0.78, 0.1, { font = Lib.FONT.header, color = P.AMBER, name = "Header" })
	Lib.label(gui, "07:12", 0.84, 0.025, 0.14, 0.1, { color = P.AMBER, xAlign = "Right", name = "Clock" })
	Lib.rect(gui, 0.02, 0.14, 0.96, 0.006, P.AMBER, 0.3, "Rule")
	-- Eight outpost cards across the visible upper half (07 blinks amber in the morning; AmbientController).
	for i, o in ipairs(OUTPOSTS) do
		local card = Lib.rect(gui, 0.02 + (i - 1) * 0.1205, 0.17, 0.112, 0.3, P.HAZARD_BLACK, 0.35, "Card" .. o[1])
		Lib.label(card, "OUTPOST", 0.08, 0.06, 0.84, 0.14, { font = Lib.FONT.body, color = P.SIGN_WHITE, transparency = 0.3 })
		Lib.label(card, o[1], 0.08, 0.18, 0.84, 0.36, { font = Lib.FONT.header, color = P.SIGN_WHITE, name = "Number" })
		Lib.label(card, o[2], 0.08, 0.55, 0.84, 0.12, { font = Lib.FONT.body, color = P.SIGN_WHITE, transparency = 0.3 })
		local overdue = o[1] == "07"
		Lib.label(card, if overdue then "REPORT OVERDUE" else "NOMINAL", 0.08, 0.72, 0.84, 0.2, {
			color = if overdue then P.AMBER else P.SUCCESS_GREEN, transparency = if overdue then 0 else 0.35, name = if overdue then "Row07Status" else "Status",
		})
		if overdue then
			Lib.rect(card, 0, 0, 1, 0.025, P.AMBER, 0, "Alarm")
		end
	end
	-- Corridor traffic and the ash index (decor) across the lower half, half hidden behind the offices.
	Lib.label(gui, "CORRIDOR TRAFFIC — 24H", 0.02, 0.52, 0.4, 0.06, { font = Lib.FONT.body, color = P.AMBER_LAMP })
	local rng = BK.rng(4112)
	for b = 0, 47 do
		local h = rng.next(0.04, 0.22)
		Lib.rect(gui, 0.02 + b * 0.0095, 0.82 - h, 0.006, h, P.AMBER, 0.35, "Traffic" .. b)
	end
	Lib.label(gui, "ASH INDEX · EAST 4 · WEST 1", 0.52, 0.52, 0.46, 0.06, { font = Lib.FONT.body, color = P.AMBER_LAMP, xAlign = "Right" })
	Lib.label(gui, "BULWARK G1–G4 SEALED   ·   CORRIDORS 7 OPEN   ·   FRAMES ON STANDBY 3", 0.52, 0.62, 0.46, 0.05, { color = P.SIGN_WHITE, xAlign = "Right", transparency = 0.25 })
	-- The ticker band at the bottom (the client scrolls "Ticker").
	local band = Lib.rect(gui, 0, 0.88, 1, 0.1, P.HAZARD_BLACK, 0.2, "TickerBand")
	band.ClipsDescendants = true
	Lib.label(band, TICKER .. TICKER, 0, 0.1, 3, 0.8, { font = Lib.FONT.body, color = P.AMBER, name = "Ticker" })

	-- The kiosk in front of the wall (map_01 §3: the prompt on a small floor-level kiosk at (0, 0, -20)).
	local kiosk = BK.model(F, "StatusKiosk")
	BK.part(kiosk, { Name = "Pedestal", Size = V(1.4, 2.7, 0.9), CFrame = CFrame.new(0, 1.35, -20.1), Color = P.STEEL_DARK, Material = "Metal" })
	BK.part(kiosk, { Name = "Foot", Size = V(2, 0.2, 1.4), CFrame = CFrame.new(0, 0.1, -20.1), Color = P.KICKPLATE, CanCollide = false })
	local tilt = math.rad(35)
	local n = V(0, math.sin(tilt), math.cos(tilt))
	local center = V(0, 3.05, -19.85)
	BK.part(kiosk, { Name = "ScreenHousing", Size = V(1.9, 1.3, 0.2), CFrame = CFrame.lookAt(center - n * 0.12, center - n * 0.12 + n), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	local kscreen = BK.part(kiosk, {
		Name = "KioskScreen", Size = V(1.7, 1.1, 0.04), CFrame = CFrame.lookAt(center, center + n), Color = Lib.SCREEN_BASE, Material = "Neon", Transparency = 0.3,
		CanCollide = false, CastShadow = false, Tags = { "StatusWall" },
	})
	local kg = Lib.gui(kscreen, Enum.NormalId.Front, 0, 100)
	Lib.rect(kg, 0, 0, 1, 1, Lib.SCREEN_BASE, 0.15, "Back")
	Lib.label(kg, "OPERATIONAL STATUS", 0.06, 0.06, 0.88, 0.16, { font = Lib.FONT.header, color = P.AMBER })
	Lib.label(kg, "OUTPOST 07 · GREYWATCH", 0.06, 0.34, 0.88, 0.16, { color = P.SIGN_WHITE })
	Lib.label(kg, "REPORT OVERDUE", 0.06, 0.56, 0.88, 0.2, { color = P.AMBER, name = "Row07Status" })
	Lib.label(kg, "01–06, 08 NOMINAL", 0.06, 0.8, 0.88, 0.12, { color = P.SUCCESS_GREEN, transparency = 0.35 })
	kiosk.PrimaryPart = kiosk.Pedestal
	BK.prompt(kscreen, "INT_STATUS_WALL", "Look")
end

function Builder.valeOffice(ctx, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local SOUTH = Lib.FACE["+Z"]
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	-- Vale works at the desk facing the glass (south); a visitor's chair in front.
	Lib.Desk(F, CFrame.new(0, 16, -34.6), { name = "Vale_Desk" })
	Lib.Chair(F, CFrame.new(0, 16, -37.1) * SOUTH, { name = "Vale_Chair" })
	Lib.Chair(F, CFrame.new(1.2, 16, -31.9) * CFrame.Angles(0, math.rad(-10), 0), { name = "Vale_VisitorChair" })
	Lib.Terminal(F, CFrame.new(1.0, 18.8, -34.95), { name = "Vale_Terminal", lines = { "VALE, H. — COMMANDER", "EMBER SQ · 0800", "OUTPOST 07 · NO REPORT" } })
	Lib.Clipboard(F, CFrame.new(-1.3, 18.8, -34.3) * CFrame.Angles(0, math.rad(20), 0), { name = "Vale_Clipboard" })
	Lib.Mug(F, CFrame.new(-2.0, 18.8, -35.3), { name = "Vale_Mug", color = P.SLATE_DEEP })
	Lib.HoloPanel(F, CFrame.new(-0.6, 20.6, -34.2), { name = "Vale_Holo", size = Vector2.new(2.4, 1.3), title = "OUTPOST 07", lines = { "COMMS · NONE 6H", "EMBER SQ · ASSIGNED" }, emitter = 1.15 })

	-- A wall map on the west partition (X -19.5): the territory, east to the outposts.
	local map = BK.part(F, { Name = "Vale_WallMap", Size = V(7, 4, 0.1), CFrame = BK.lookAlong(V(-19.38, 21.6, -34.6), V(1, 0, 0)), Color = P.ASH_DARK, CanCollide = false, CastShadow = false })
	local mg = Lib.gui(map, Enum.NormalId.Front, 0.6, 60)
	Lib.rect(mg, 0, 0, 1, 1, P.ASH_DARK, 0, "Paper")
	Lib.rect(mg, 0.05, 0.3, 0.16, 0.4, P.STEEL_MID, 0, "City")
	Lib.rect(mg, 0.25, 0.08, 0.025, 0.84, P.SLATE_DEEP, 0, "Bulwark")
	for i, y in ipairs({ 0.22, 0.4, 0.58, 0.76 }) do
		Lib.rect(mg, 0.275, y, 0.6, 0.008, P.KICKPLATE, 0.3, "Corridor" .. i)
		Lib.rect(mg, 0.86, y - 0.025, 0.04, 0.06, if i == 2 then P.DANGER_RED else P.STEEL_DARK, 0, "Outpost" .. i)
	end
	Lib.label(mg, "FRONTIER — EAST", 0.05, 0.04, 0.5, 0.1, { font = Lib.FONT.header, color = P.KICKPLATE })
	BK.box(F, "Vale_WallMapFrame", V(-19.5, 19.45, -38.2), V(-19.43, 23.75, -31.0), { Color = P.WOOD_OLD, Material = "Wood", CanCollide = false, CastShadow = false })

	-- An open shelf unit on the east partition (X 19.5): back, sides, four shelves, binders.
	local steel = { Color = P.STEEL_MID, Material = "Metal" }
	BK.box(F, "Vale_ShelfBack", V(19.3, 16, -38.6), V(19.5, 22.2, -34.6), steel)
	for _, z in ipairs({ -38.6, -34.75 }) do
		BK.box(F, "Vale_ShelfSide", V(18.3, 16, z), V(19.3, 22.2, z + 0.15), steel)
	end
	for s = 0, 3 do
		local y = 16.4 + s * 1.9
		BK.box(F, "Vale_ShelfBoard" .. s, V(18.3, y - 0.12, -38.45), V(19.3, y, -34.75), steel)
	end
	local rng = BK.rng(77)
	for shelf = 0, 2 do
		local y = 16.4 + shelf * 1.9
		for b = 0, 7 do
			local z = -38.35 + b * 0.45
			local h = rng.next(1.0, 1.5)
			BK.box(F, "Vale_Binder", V(18.45, y, z), V(19.25, y + h, z + 0.38), with({ Color = rng.pick({ P.SLATE_DEEP, P.SLATE, P.STEEL_DARK, P.RUST_DARK }) }))
		end
	end

	-- The Directorate flag on a stand in the north-west corner (the Division insignia on slate).
	local flag = Lib.kit(F, "Vale_Flag", CFrame.new(-16.5, 16, -37.6) * SOUTH)
	flag.cyl("Base", "Y", V(1.2, 0.3, 1.2), V(0, 0.15, 0), { Color = P.STEEL_DARK, Material = "Metal" })
	flag.cyl("Pole", "Y", V(0.22, 8.4, 0.22), V(0, 4.3, 0), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	flag.ball("Finial", 0.4, V(0, 8.6, 0), with({ Color = P.AMBER, Material = "Metal" }))
	flag.box("Crossbar", V(3.2, 0.12, 0.12), V(-1.6, 8.2, 0), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	flag.box("Cloth", V(3.0, 4.2, 0.08), V(-1.65, 6.0, 0), with({ Color = P.SLATE, Material = "Fabric" }))
	flag.box("ClothBand", V(3.0, 0.2, 0.1), V(-1.65, 4.0, 0), with({ Color = P.AMBER }))
	Lib.insignia(flag, CFrame.new(-1.65, 6.3, -0.065), 1.8)
	flag.finish()
end

function Builder.sideOffice(ctx, Lib, name, x)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local SOUTH = Lib.FACE["+Z"]
	Lib.Desk(F, CFrame.new(x - 6, 16, -35.2), { name = name .. "_Desk" })
	Lib.Chair(F, CFrame.new(x - 6, 16, -37.6) * SOUTH, { name = name .. "_Chair" })
	Lib.Terminal(F, CFrame.new(x - 5.4, 18.8, -35.55), { name = name .. "_Terminal", lines = { "DUTY OFFICER", "LOG 0712" } })
	Lib.Locker(F, CFrame.new(x + 7, 16, -37.9) * SOUTH, { name = name .. "_Files", count = 3 })
	Lib.HoloPanel(F, CFrame.new(x - 6.6, 20.4, -34.8), { name = name .. "_Holo", size = Vector2.new(2.0, 1.1), title = "ROSTER", emitter = 1.05 })
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F, L = ctx.Props, ctx.Lighting
	local SOUTH = Lib.FACE["+Z"]
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- The holo-table (the prompt measures 16 from its center; no line-of-sight check: the hologram, glass and rim
	-- stand between most camera angles and the drum) and its warm light.
	local holo = Lib.HoloTable(F, CFrame.new(0, 0, 0), { name = "HoloTable" })
	BK.prompt(holo.PrimaryPart, "INT_HOLO", "Look", { dist = 16, lineOfSight = false })
	local glow = BK.box(L, "HoloTable_Glow", V(-0.2, 5.3, -0.2), V(0.2, 5.7, 0.2), with({ Transparency = 1 }))
	BK.light(glow, "Point", { Color = P.AMBER, Brightness = 1, Range = 18, Tags = { "HubLight" } })
	-- Its projector ring hangs at Y 26: twelve segments with a lens each, on four rods.
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local mid = V(math.sin(a) * 8, 26, math.cos(a) * 8)
		local tangent = V(math.cos(a), 0, -math.sin(a))
		BK.part(F, with({ Name = "Projector_Seg" .. i, Size = V(0.9, 0.6, 4.3), CFrame = CFrame.lookAt(mid, mid + tangent), Color = P.STEEL_DARK, Material = "Metal" }))
		local lens = table.clone(Lib.glow)
		BK.part(F, with({ Name = "Projector_Lens" .. i, Size = V(0.5, 0.08, 0.8), CFrame = CFrame.lookAt(mid - V(0, 0.32, 0), mid - V(0, 0.32, 0) + tangent), Color = lens.Color, Material = "Neon", Transparency = lens.Transparency }))
	end
	for i = 0, 3 do
		local a = math.rad(i * 90 + 15)
		local at = V(math.sin(a) * 8, 0, math.cos(a) * 8)
		BK.box(F, "Projector_Rod" .. i, at + V(-0.1, 26.3, -0.1), at + V(0.1, 35.9, 0.1), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end

	-- Consoles C1-C8 with their chairs (the seated NPCs' marks are 3 south of each console: Config/NPCs).
	for i, c in ipairs(CONSOLES) do
		Lib.Console(F, CFrame.new(c[2], 0, c[3]) * SOUTH, { name = "Console_" .. c[1], lines = c[4], seed = i * 11, alert = c.alert, holo = c.holo })
		Lib.Chair(F, CFrame.new(c[2], 0, c[3] + 3), { name = "Chair_" .. c[1] })
	end
	-- Cable runs behind each console row, out to the side walls.
	for _, z in ipairs({ 12.4, 24.4 }) do
		Lib.CableRun(F, V(-59, 0, z), V(-20.5, 0, z), { name = "ConsoleCables" })
		Lib.CableRun(F, V(20.5, 0, z), V(59, 0, z), { name = "ConsoleCables" })
	end

	Builder.statusWall(ctx, Lib)

	-- Banners on the west and east walls at Z +-25, Y 18..30; posters at (+-59.4, 6, 20); INT_POSTER on the west one.
	for _, side in ipairs({ { -59.5, "+X" }, { 59.5, "-X" } }) do
		for _, z in ipairs({ -25, 25 }) do
			Lib.Banner(F, CFrame.new(side[1], 24, z) * Lib.FACE[side[2]], { name = "Banner" })
		end
	end
	local poster = Lib.Poster(F, CFrame.new(-59.5, 6, 20) * Lib.FACE["+X"], { name = "Poster_W", partName = "Poster_Recruit", text = "THE FRAME STANDS. HUMANITY STANDS." })
	BK.prompt(poster.PrimaryPart, "INT_POSTER", "Look")
	Lib.Poster(F, CFrame.new(59.5, 6, 20) * Lib.FACE["-X"], { name = "Poster_E", text = "DISCIPLINE IS SURVIVAL." })

	-- The Division emblem over the south entrance, and the division's name (06 §7's sign list).
	local emblem = Lib.kit(F, "SouthEmblem", CFrame.new(0, 25, 38.9))
	emblem.cyl("Disc", "Z", V(15, 15, 0.1), V(0, 0, 0.04), { Color = P.SLATE_DEEP, CanCollide = false })
	emblem.cyl("Ring", "Z", V(15.6, 15.6, 0.06), V(0, 0, 0.07), with({ Color = P.AMBER, Material = "Metal" }))
	Lib.insignia(emblem, CFrame.new(0, 0.6, -0.04), 10)
	emblem.finish()
	BK.sign(ctx.Detail, "Sign_Division", BK.lookAlong(V(0, 16.4, 38.9), V(0, 0, -1)), Vector2.new(30, 1.8), "THIRD FRONTIER FRAME DIVISION")

	-- Under the mezzanine: the bay board and the sortie board either side of the way north.
	BK.screen(ctx.Detail, "BayBoard", CFrame.new(-37, 8.2, -38.9) * SOUTH, Vector2.new(16, 6), {
		text = "FRAME BAYS\nBAY 01   UNIT 01 · SOLEN, M.   READY\nBAY 02   UNIT 02 · VEYNE, E.   READY\nBAY 03   UNIT 03 · —   MAINTENANCE",
	})
	BK.screen(ctx.Detail, "SortieBoard", CFrame.new(37, 8.2, -38.9) * SOUTH, Vector2.new(16, 6), {
		text = "SORTIES TODAY\n0800   EMBER SQ   BRIEFING ROOM ONE\n0930   CORRIDOR 7   CONVOY ESCORT\n1200   BULWARK G2   PATROL ROTATION",
	})
	for _, x in ipairs({ -37, 37 }) do
		BK.box(ctx.Detail, "BoardFrame", V(x - 8.3, 4.9, -39.0), V(x + 8.3, 11.5, -38.98), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end

	-- Vents high on the side walls, and the offices.
	for i, z in ipairs({ -8, 8 }) do
		Lib.Vent(F, CFrame.new(-59.5, 30, z) * Lib.FACE["+X"], { name = "Vent_W" .. i })
		Lib.Vent(F, CFrame.new(59.5, 30, z) * Lib.FACE["-X"], { name = "Vent_E" .. i })
	end
	Builder.valeOffice(ctx, Lib)
	Builder.sideOffice(ctx, Lib, "OfficeW", -40)
	Builder.sideOffice(ctx, Lib, "OfficeE", 40)
end

return Builder
