--!nonstrict
-- builders/maps/central_command/Quarters.lua  ->  DevTools.Builders.CentralCommand.Quarters
-- docs/maps/map_01_central_command.md §5: X -130..-80, Z 0..40, ceiling 12. Hallway Z 16..24, six rooms;
-- only Q-3 (X -128..-112, Z 0..16) is enterable in Chapter 1.
--
-- Passes (docs/07 §2):
--   blockout   the shell, Q-3's doorway, grey stand-ins carrying Q-3's prompts
--   structure  + wall finishes (wainscot, bands, trims, lining, exterior kickplate and pilasters), all six doorways
--              (five closed doors, Q-4's ajar with light behind it, Q-3 open), name plates, the window's frame and
--              sill, the hallway's corridor strips, Q-3's ceiling panel
--   dressed    + Q-3's props in place of the stand-ins (bunk, desk, terminal, photo, the father's patch, lamp, locker,
--              chair, rug, shelf, jacket, holo clock), floor and ceiling seams, wall seams, the hallway's details
-- opts: Common, BK, Props (the props library, structure pass and up), pass.

local Builder = {}

local V = Vector3.new

-- { room, x1, x2, side ("N" = Hall_N at Z 16, "S" = Hall_S at Z 24), name plate }
local DOORS = {
	{ "Q1", -90, -85, "N", "Q-1 · ROOK, T." },
	{ "Q2", -106, -101, "N", "Q-2 · VACANT" },
	{ "Q3", -122, -117, "N", "Q-3 · VEYNE, E." },
	{ "Q4", -90, -85, "S", "Q-4 · SOLEN, M." },
	{ "Q5", -106, -101, "S", "Q-5 · OKONJO, P." },
	{ "Q6", -122, -117, "S", "Q-6 · VACANT" },
}

local TRIM = 0.4 -- BK.wallWithOpenings' door-frame trim

local function gapOf(x1, x2, y1, y2)
	return { from = x1 - TRIM, to = x2 + TRIM, y1 = y1, y2 = y2 + TRIM }
end

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Quarters")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay
	local full, dressed = ctx.level >= 2, ctx.level >= 3
	local Lib = opts.Props
	if full and not Lib then
		error("Quarters: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", -130, -80, 0, 40, 0, 1, ctx.FLOOR)
	local ceiling = BK.ceiling(S, "Ceiling", -130, -80, 0, 40, 12, 1, ctx.CEIL)
	BK.wallX(S, "Wall_S", -131, -80.5, 40, 0, 13, C.EXT, ctx.EXT)
	-- West exterior wall with Q-3's window slit (Z 6..12, Y 6..7.5).
	BK.wallWithOpenings(S, "Wall_W", "Z", 0, 39, -130, 0, 13, C.EXT, { { from = 6, to = 12, y1 = 6, y2 = 7.5 } }, ctx.EXT)
	local window = BK.box(S, "Q3_Window", V(-130.1, 6, 6), V(-129.9, 7.5, 12), ctx.GLASS)

	-- Hallway walls. Blockout cuts only Q-3's door; the later passes cut all six (five get closed doors).
	local function openings(side)
		local list = {}
		for _, d in ipairs(DOORS) do
			if d[4] == side and (full or d[1] == "Q3") then
				table.insert(list, { from = d[2], to = d[3], y1 = 0, y2 = C.DOOR_H })
			end
		end
		table.sort(list, function(a, b)
			return a.from < b.from
		end)
		return list
	end
	BK.wallWithOpenings(S, "Hall_N", "X", -129, -80.5, 16, 0, 12, C.INT, openings("N"), ctx.INT)
	if full then
		BK.wallWithOpenings(S, "Hall_S", "X", -129, -80.5, 24, 0, 12, C.INT, openings("S"), ctx.INT)
	else
		BK.wallX(S, "Hall_S", -129, -80.5, 24, 0, 12, C.INT, ctx.INT)
	end
	for _, x in ipairs({ -96, -112 }) do
		BK.wallZ(S, ("Divider_N_%d"):format(-x), 0.5, 15.5, x, 0, 12, C.INT, ctx.INT)
		BK.wallZ(S, ("Divider_S_%d"):format(-x), 24.5, 39, x, 0, 12, C.INT, ctx.INT)
	end

	if full then
		Builder.structure(ctx, C, Lib, window)
	end
	if dressed then
		Builder.dressQ3(ctx, C, Lib, window)
		Builder.dressHallway(ctx, C, Lib)
		C.tileSeams(ctx, floor, ceiling)
	else
		-- Q-3 stand-ins (desk, photo, terminal, locker, bunk) so the prompts and the floor plan can be tested.
		C.standIn(ctx, "Q3_Desk_StandIn", V(-120.5, 0, 0.5), V(-115.5, 2.8, 3))
		local photo = C.standIn(ctx, "Q3_Photo_StandIn", V(-120, 2.8, 1.15), V(-119.2, 3.8, 1.25), { Color = "#3A2A1E" })
		BK.prompt(photo, "INT_Q3_PHOTO", "Look")
		local terminal = C.standIn(ctx, "Q3_Terminal_StandIn", V(-118.3, 2.8, 1.25), V(-116.5, 4.2, 1.55), { Color = P.STEEL_DARK })
		BK.prompt(terminal, "INT_Q3_TERMINAL", "Read", { enabled = false }) -- S43 only
		local locker = C.standIn(ctx, "Q3_Locker_StandIn", V(-124.5, 0, 0.5), V(-122.5, 7, 2.5), { Color = P.SLATE })
		BK.prompt(locker, "INT_Q3_LOCKER", "Take", { once = true })
		C.standIn(ctx, "Q3_Bunk_StandIn", V(-127.25, 0, 5.5), V(-123.75, 2, 12.5), { Color = P.FABRIC_DARK })
	end
	BK.prompt(window, "INT_Q3_WINDOW", "Look")

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

---------------------------------------------------------------------------------------------------
-- Structure: finishes, doors, plates, the window, lights
---------------------------------------------------------------------------------------------------
function Builder.structure(ctx, C, Lib, window)
	local BK, P = ctx.BK, ctx.P
	local doorGaps = { N = {}, S = {} }
	for _, d in ipairs(DOORS) do
		table.insert(doorGaps[d[4]], gapOf(d[2], d[3], 0, C.DOOR_H))
	end

	-- Q-3's four faces (room X -129..-112.5, Z 0.5..15.5) and the hallway's (Z 16.5..23.5).
	C.face(ctx, "Q3_FaceN", V(-129, 0, 0.5), V(-112.5, 0, 0.5), V(0, 0, 1), { kind = "interior", top = 12 })
	C.face(ctx, "Q3_FaceE", V(-112.5, 0, 0.5), V(-112.5, 0, 15.5), V(-1, 0, 0), { kind = "interior", top = 12 })
	C.face(ctx, "Q3_FaceS", V(-129, 0, 15.5), V(-112.5, 0, 15.5), V(0, 0, -1), { kind = "interior", top = 12, gaps = { gapOf(-122, -117, 0, C.DOOR_H) } })
	C.face(ctx, "Q3_FaceW", V(-129, 0, 0.5), V(-129, 0, 15.5), V(1, 0, 0), {
		kind = "interior", top = 12, lining = true, gaps = { { from = 6 - TRIM, to = 12 + TRIM, y1 = 6 - TRIM, y2 = 7.5 + TRIM } },
	})
	C.face(ctx, "Hall_FaceN", V(-129, 0, 16.5), V(-80.5, 0, 16.5), V(0, 0, 1), { kind = "interior", top = 12, gaps = doorGaps.N })
	C.face(ctx, "Hall_FaceS", V(-129, 0, 23.5), V(-80.5, 0, 23.5), V(0, 0, -1), { kind = "interior", top = 12, gaps = doorGaps.S })
	C.face(ctx, "Hall_FaceW", V(-129, 0, 16.5), V(-129, 0, 23.5), V(1, 0, 0), { kind = "interior", top = 12, lining = true })
	-- Exterior faces: the west wall (X -131) and the south wall (Z 41).
	C.face(ctx, "Ext_W", V(-131, 0, 0), V(-131, 0, 41), V(-1, 0, 0), {
		kind = "exterior", top = 13, gaps = { { from = 6 - TRIM, to = 12 + TRIM, y1 = 6 - TRIM, y2 = 7.5 + TRIM } },
	})
	C.face(ctx, "Ext_S", V(-131, 0, 41), V(-80, 0, 41), V(0, 0, 1), { kind = "exterior", top = 13 })

	-- Doors. Q-3 is an open doorway; Q-4's door stands ajar with a lamp lit behind it; the rest are closed.
	for _, d in ipairs(DOORS) do
		local room, x1, x2, side = d[1], d[2], d[3], d[4]
		local x = (x1 + x2) / 2
		local z = if side == "N" then 16 else 24
		-- The door's -Z (its sign side) faces the hallway.
		local cf = CFrame.new(x, 0, z) * (if side == "N" then Lib.FACE["+Z"] else CFrame.identity)
		local leaf = room ~= "Q3" and room ~= "Q4"
		BK.door(ctx.Structure, "Door_" .. room, cf, x2 - x1, C.DOOR_H, { leaf = leaf, color = P.STEEL_MID })
		if room == "Q4" then
			-- Hinged at the east jamb, swung 14 degrees into the room (south).
			local hinge = CFrame.new(x2 - 0.1, 0, z + 0.15)
			BK.part(ctx.Structure, {
				Name = "Door_Q4_LeafAjar", Size = V(4.9, C.DOOR_H, 0.3), Color = P.STEEL_MID, Material = "Metal",
				CFrame = hinge * CFrame.Angles(0, math.rad(14), 0) * CFrame.new(-2.45, C.DOOR_H / 2, 0),
			})
			local lamp = BK.part(ctx.Lighting, { Name = "Q4_RoomLamp", Size = V(0.4, 0.4, 0.4), CFrame = CFrame.new(-88, 6, 30), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
			BK.light(lamp, "Point", { Color = P.AMBER_LAMP, Brightness = 0.9, Range = 12, Tags = { "HubLight" } })
		end
		-- The name plate beside the door (east side), white on SLATE.
		local plateZ = if side == "N" then 16.56 else 23.44
		local facing = if side == "N" then V(0, 0, 1) else V(0, 0, -1)
		BK.sign(ctx.Detail, "Plate_" .. room, BK.lookAlong(V(x2 + 1.6, 5.2, plateZ), facing), Vector2.new(2.2, 0.55), d[5], {
			textColor = P.SIGN_WHITE, bgColor = P.SLATE,
		})
	end

	-- The window slit: an inner sill, a frame of the trim's colour, and outside a grime strip under it (docs/07 §7).
	BK.box(ctx.Structure, "Q3_WindowSill", V(-129.1, 5.45, 5.6), V(-128.6, 5.6, 12.4), { Color = P.STEEL_DARK, Material = "Metal" })
	BK.box(ctx.Detail, "Q3_WindowMullion", V(-130.05, 6, 8.9), V(-129.95, 7.5, 9.1), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false, CastShadow = false })
	BK.box(ctx.Detail, "Q3_WindowGrime", V(-131.15, 3.6, 8), V(-131.05, 5.6, 10), { Color = P.KICKPLATE, Transparency = 0.6, CanCollide = false, CastShadow = false })

	-- Lights: corridor strips every 10 (docs/06 §5: 0.3 x 0.15 x 6, SurfaceLight 1 / 16) and Q-3's ceiling panel.
	for i, x in ipairs({ -85, -95, -105, -115, -125 }) do
		C.fixture(ctx, "Hall_Strip" .. i, V(x, 11.9, 20), V(6, 0.15, 0.3), { Brightness = 1, Range = 16 })
	end
	C.fixture(ctx, "Q3_CeilingPanel", V(-120.5, 11.9, 8.5), V(3, 0.15, 3), { Brightness = 0.5, Range = 16 })
end

---------------------------------------------------------------------------------------------------
-- Dressed: Q-3 (map_01 §5's table and its dressing line)
---------------------------------------------------------------------------------------------------
function Builder.dressQ3(ctx, C, Lib, window)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local SOUTH = Lib.FACE["+Z"]

	-- Bunk along the west wall, head to the south, drawers facing the room.
	Lib.Bunk(F, CFrame.new(-125.5, 0, 9) * CFrame.Angles(0, -math.pi / 2, 0), { name = "Q3_Bunk" })
	-- Desk against the north wall, facing south; on it from left to right (as Elias faces it): the photo, the patch,
	-- the terminal, the lamp; a mug and a datapad in front.
	Lib.Desk(F, CFrame.new(-118, 0, 1.6) * SOUTH, { name = "Q3_Desk" })
	local photo = Lib.PhotoFrame(F, CFrame.new(-119.75, 2.8, 1.25) * SOUTH * CFrame.Angles(0, math.rad(14), 0), { name = "Q3_PhotoFrame", photoName = "Q3_Photo" })
	BK.prompt(photo.PrimaryPart, "INT_Q3_PHOTO", "Look")
	local _, screen = Lib.Terminal(F, CFrame.new(-117.4, 2.8, 1.3) * SOUTH, {
		name = "Q3_DeskTerminal", screenName = "Q3_Terminal",
		lines = { "VEYNE, E. — PILOT OFFICER", "EMBER-2 · THIRD FRONTIER", "DEPLOYMENT 06:30", "No new messages." },
	})
	BK.prompt(screen, "INT_Q3_TERMINAL", "Read", { enabled = false }) -- S43 only
	Lib.DeskLamp(F, CFrame.new(-115.95, 2.8, 1.05) * SOUTH * CFrame.Angles(0, math.rad(-25), 0), { name = "Q3_DeskLamp" })
	Lib.Mug(F, CFrame.new(-116.2, 2.8, 2.25), { name = "Q3_Mug", color = P.STEEL_MID })
	Lib.Datapad(F, CFrame.new(-118.9, 2.8, 2.3) * CFrame.Angles(0, math.rad(12), 0), { name = "Q3_Datapad" })

	-- The father's patch (05 S02): a shield of the 9th FDU's slate with an amber chevron, lying by the photo.
	-- Clients hide it once the player has CH1_TOOK_PATCH (tag HideOnFlag; AmbientController).
	local patch = BK.model(F, "Q3_Patch")
	local patchCF = CFrame.new(-118.85, 2.82, 1.45) * CFrame.Angles(0, math.rad(-8), 0)
	local cloth = BK.part(patch, with({ Name = "Cloth", Size = V(0.5, 0.04, 0.48), CFrame = patchCF, Color = P.SLATE, Material = "Fabric" }))
	BK.part(patch, with({ Name = "Point", Size = V(0.36, 0.04, 0.36), CFrame = patchCF * CFrame.new(0, 0, 0.24) * CFrame.Angles(0, math.rad(45), 0), Color = P.SLATE, Material = "Fabric" }))
	BK.part(patch, with({ Name = "Chevron", Size = V(0.3, 0.05, 0.08), CFrame = patchCF * CFrame.new(0, 0.005, 0.02), Color = P.AMBER }))
	BK.part(patch, with({ Name = "Edge", Size = V(0.52, 0.03, 0.04), CFrame = patchCF * CFrame.new(0, 0.005, -0.23), Color = P.AMBER }))
	patch.PrimaryPart = cloth
	BK.tag(patch, "HideOnFlag")
	patch:SetAttribute("HideFlag", "CH1_TOOK_PATCH")

	-- Locker against the north wall, facing the room.
	local locker = Lib.Locker(F, CFrame.new(-123.5, 0, 1.2) * SOUTH, { name = "Q3_Locker", names = { "VEYNE" } })
	BK.prompt(locker.PrimaryPart, "INT_Q3_LOCKER", "Take", { once = true })

	-- A chair pushed back from the desk's east end (Elias stands at the desk at the spawn), a rug, boots, a duffel.
	Lib.Chair(F, CFrame.new(-114.4, 0, 4.6) * CFrame.Angles(0, math.rad(35), 0), { name = "Q3_Chair" })
	BK.box(F, "Q3_Rug", V(-123.3, 0, 6.5), V(-117.5, 0.04, 11.5), with({ Color = P.SLATE, Material = "Fabric" }))
	for i, r in ipairs({ { -123.0, -117.8, 6.8, 7.0 }, { -123.0, -117.8, 11.0, 11.2 } }) do
		BK.box(F, "Q3_RugStripe" .. i, V(r[1], 0, r[3]), V(r[2], 0.05, r[4]), with({ Color = P.SLATE_DEEP, Material = "Fabric" }))
	end
	for i, z in ipairs({ 11.55, 12.25 }) do
		BK.box(F, "Q3_BootSole" .. i, V(-123.55, 0, z - 0.25), V(-122.6, 0.15, z + 0.25), with({ Color = "#1E2125" }))
		BK.box(F, "Q3_BootShaft" .. i, V(-123.55, 0.15, z - 0.22), V(-123.1, 1.0, z + 0.22), with({ Color = "#1E2125" }))
	end
	BK.cyl(F, with({ Name = "Q3_Duffel", Axis = "X", Size = V(2.2, 0.9, 0.9), CFrame = CFrame.new(-125.3, 0.45, 3.9), Color = P.SLATE_DEEP, Material = "Fabric" }))
	BK.box(F, "Q3_DuffelStrap", V(-125.45, 0.85, 3.6), V(-125.15, 0.95, 4.2), with({ Color = P.HAZARD_BLACK }))

	-- A shelf on the east wall: three books, the core-chip card stack and a little Vanguard figurine.
	local shelfX1, shelfX2 = -113.45, -112.5
	BK.box(F, "Q3_Shelf", V(shelfX1, 5.45, 5.5), V(shelfX2, 5.6, 10.5), { Color = P.WOOD_OLD, Material = "Wood", CastShadow = true })
	for i, z in ipairs({ 6.0, 10.0 }) do
		BK.box(F, "Q3_ShelfBracket" .. i, V(-112.75, 4.9, z - 0.06), V(shelfX2, 5.45, z + 0.06), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	local books = { { 5.8, P.SLATE_DEEP, 1.0 }, { 6.12, P.RUST_DARK, 0.9 }, { 6.42, P.WOOD_OLD, 1.05 } }
	for i, b in ipairs(books) do
		BK.box(F, "Q3_Book" .. i, V(-113.3, 5.6, b[1]), V(-112.6, 5.6 + b[3], b[1] + 0.28), with({ Color = b[2] }))
	end
	BK.part(F, with({ Name = "Q3_BookLeaning", Size = V(0.7, 0.95, 0.26), CFrame = CFrame.new(-112.95, 6.05, 6.95) * CFrame.Angles(math.rad(-18), 0, 0), Color = P.SLATE }))
	for i = 0, 4 do
		BK.box(F, "Q3_Card" .. i, V(-113.2, 5.6 + i * 0.04, 8.0 + i * 0.01), V(-112.75, 5.64 + i * 0.04, 8.32 + i * 0.01), with({ Color = if i == 4 then P.AMBER else P.STEEL_MID }))
	end
	local fig = CFrame.new(-112.95, 5.6, 9.5)
	BK.box(F, "Q3_Figure_Legs", fig.Position + V(-0.12, 0, -0.1), fig.Position + V(0.12, 0.35, 0.1), with({ Color = P.VG_FRAME }))
	BK.box(F, "Q3_Figure_Torso", fig.Position + V(-0.16, 0.35, -0.12), fig.Position + V(0.16, 0.65, 0.12), with({ Color = P.VG_ARMOR }))
	BK.box(F, "Q3_Figure_Shoulders", fig.Position + V(-0.2, 0.58, -0.3), fig.Position + V(0.2, 0.7, 0.3), with({ Color = P.VG_ARMOR_DARK }))
	BK.box(F, "Q3_Figure_Visor", fig.Position + V(-0.07, 0.7, -0.06), fig.Position + V(0.07, 0.8, 0.06), with({ Color = P.VG_VISOR, Material = "Neon" }))
	BK.box(F, "Q3_Figure_Stripe", fig.Position + V(-0.17, 0.45, -0.13), fig.Position + V(-0.15, 0.52, 0.13), with({ Color = P.VG_ACCENT_ELIAS }))

	-- The uniform jacket on a hook west of the door (pilot suit #2B2F36 with Elias's orange piping, 03).
	local hook = CFrame.new(-125.6, 7.2, 15.38)
	local suit = { Color = "#2B2F36", Material = "Fabric" }
	BK.box(F, "Q3_Hook", hook.Position + V(-0.06, -0.1, -0.25), hook.Position + V(0.06, 0.05, 0.1), with({ Color = P.STEEL_LIGHT, Material = "Metal" }))
	BK.box(F, "Q3_JacketShoulders", hook.Position + V(-0.85, -0.65, -0.55), hook.Position + V(0.85, -0.2, -0.15), with(suit))
	BK.box(F, "Q3_JacketBody", hook.Position + V(-0.7, -2.7, -0.5), hook.Position + V(0.7, -0.6, -0.2), with(suit))
	for _, sx in ipairs({ -1, 1 }) do
		BK.box(F, "Q3_JacketSleeve", hook.Position + V(sx * 0.72 - 0.17, -2.5, -0.48), hook.Position + V(sx * 0.72 + 0.17, -0.55, -0.22), with(suit))
		BK.box(F, "Q3_JacketPiping", hook.Position + V(sx * 0.9 - 0.03, -2.45, -0.4), hook.Position + V(sx * 0.9 + 0.03, -0.6, -0.3), with({ Color = P.WARNING_ORANGE, Material = "Neon", Transparency = 0.3 }))
	end
	BK.box(F, "Q3_JacketCollar", hook.Position + V(-0.35, -0.3, -0.58), hook.Position + V(0.35, -0.1, -0.2), with({ Color = BK.darken(BK.hex("#2B2F36"), 0.2), Material = "Fabric" }))
	BK.box(F, "Q3_JacketTag", hook.Position + V(0.2, -1.2, -0.52), hook.Position + V(0.55, -1.0, -0.5), with({ Color = P.SIGN_WHITE }))

	-- The holo clock over the desk (amber; AmbientController keeps its time with the lighting's clock).
	BK.box(F, "Q3_ClockProjector", V(-118.6, 7.35, 0.5), V(-117.4, 7.55, 0.95), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.box(F, "Q3_ClockLens", V(-118.2, 7.3, 0.6), V(-117.8, 7.36, 0.9), with(Lib.glow))
	local clock = Lib.HoloPanel(F, CFrame.new(-118, 6.45, 0.85) * SOUTH, {
		name = "Q3_HoloClock", size = Vector2.new(2.0, 1.1), title = "07:12", lines = { "DAY 4112 · ASH ADVISORY EAST" },
		titleHeight = 0.5, lineHeight = 0.18, backFace = false,
	})
	BK.tag(clock.PrimaryPart, "HoloClock")

	-- A pinboard by the locker: a duty roster and notes.
	BK.box(F, "Q3_Pinboard", V(-127.6, 4.2, 0.5), V(-125.0, 6.4, 0.62), { Color = P.WOOD_OLD, Material = "Fabric", CanCollide = false })
	local notes = { { -127.3, 5.4, 0.9, 0.85, P.MEDICAL_WHITE }, { -126.25, 5.5, 0.7, 0.7, P.AMBER_LAMP }, { -125.6, 4.8, 0.5, 0.6, P.MEDICAL_WHITE }, { -126.9, 4.45, 0.8, 0.5, P.SIGN_WHITE } }
	for i, n in ipairs(notes) do
		BK.box(F, "Q3_Note" .. i, V(n[1], n[2], 0.62), V(n[1] + n[3], n[2] + n[4], 0.65), with({ Color = n[5] }))
	end

	-- A vent high on the north wall and ash on the outside of the window (S02: "Ash on the glass again").
	Lib.Vent(F, CFrame.new(-126.5, 10, 0.5) * SOUTH, { name = "Q3_Vent" })
	local rng = BK.rng(312)
	for i = 1, 6 do
		local z, y = rng.next(6.3, 11.7), rng.next(6.05, 7.2)
		BK.box(F, "Q3_WindowAsh" .. i, V(-130.16, y, z), V(-130.12, y + rng.next(0.08, 0.3), z + rng.next(0.2, 0.7)), with({ Color = P.ASH, Transparency = 0.35 }))
	end
end

---------------------------------------------------------------------------------------------------
-- Dressed: the hallway
---------------------------------------------------------------------------------------------------
function Builder.dressHallway(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- A conduit along the north wall's top with junction boxes, and two ceiling vents.
	BK.pipeRun(ctx.Detail, "Hall_Conduit", { V(-128.6, 11.25, 16.85), V(-81, 11.25, 16.85) }, 0.18, { color = P.STEEL_MID })
	for i, x in ipairs({ -126, -110, -94 }) do
		BK.box(ctx.Detail, "Hall_JunctionBox" .. i, V(x - 0.4, 10.8, 16.5), V(x + 0.4, 11.6, 17.0), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	for i, x in ipairs({ -100, -120 }) do
		Lib.Vent(F, BK.lookAlong(V(x, 12, 20), V(0, -1, 0)), { name = "Hall_CeilingVent" .. i, grime = false })
	end

	-- The west end: a fire cabinet and a "QUIET HOURS" notice.
	BK.box(F, "Hall_FireCabinet", V(-129, 2.4, 18.4), V(-128.5, 4.8, 19.8), { Color = P.DANGER_RED, Material = "Metal", CanCollide = false })
	BK.box(F, "Hall_FireCabinetGlass", V(-128.5, 2.7, 18.6), V(-128.45, 4.5, 19.6), with({ Color = P.GLASS, Material = "Glass", Transparency = 0.5 }))
	BK.sign(ctx.Detail, "Hall_FireSign", BK.lookAlong(V(-128.94, 5.35, 19.1), V(1, 0, 0)), Vector2.new(1.4, 0.45), "FIRE", { textColor = P.SIGN_WHITE, bgColor = P.DANGER_RED })
	BK.sign(ctx.Detail, "Hall_QuietHours", BK.lookAlong(V(-128.94, 7.4, 21.6), V(1, 0, 0)), Vector2.new(2.6, 1.2), "QUIET HOURS 2200 — 0600", { textColor = P.SIGN_WHITE, bgColor = P.SLATE })

	-- Notice board between Q-2's plate and Q-1's door (north face): duty roster, a mess menu, an ash advisory.
	BK.box(F, "Hall_NoticeBoard", V(-97.6, 4.0, 16.5), V(-91.2, 7.2, 16.62), { Color = P.SLATE_DEEP, CanCollide = false })
	BK.sign(ctx.Detail, "Hall_NoticeHeader", BK.lookAlong(V(-94.4, 6.95, 16.66), V(0, 0, 1)), Vector2.new(6.0, 0.4), "THIRD FRONTIER — PILOT QUARTERS", { textColor = P.AMBER, bgColor = P.SLATE_DEEP })
	local sheets = { { -97.3, 4.3, 1.4, 2.0 }, { -95.7, 4.6, 1.2, 1.6 }, { -94.3, 4.25, 1.5, 2.1 }, { -92.6, 4.5, 1.3, 1.7 } }
	for i, s in ipairs(sheets) do
		BK.box(F, "Hall_NoticeSheet" .. i, V(s[1], s[2], 16.62), V(s[1] + s[3], s[2] + s[4], 16.65), with({ Color = if i == 3 then P.AMBER_LAMP else P.MEDICAL_WHITE }))
		for l = 1, 4 do
			local y = s[2] + s[4] - 0.3 - l * 0.32
			BK.box(F, ("Hall_NoticeLine%d_%d"):format(i, l), V(s[1] + 0.15, y, 16.65), V(s[1] + s[3] - 0.15 - (l % 2) * 0.3, y + 0.06, 16.66), with({ Color = P.KICKPLATE }))
		end
	end

	-- A cable run along the south wall's foot and a wall terminal between Q-6 and Q-5.
	Lib.CableRun(F, V(-128.5, 0, 23.15), V(-107, 0, 23.15), { name = "Hall_CableRun", count = 2 })
	BK.box(F, "Hall_WallTerminal", V(-113.6, 3.6, 23.3), V(-110.6, 5.6, 23.5), { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
	BK.screen(ctx.Detail, "Hall_WallTerminalScreen", BK.lookAlong(V(-112.1, 4.6, 23.27), V(0, 0, -1)), Vector2.new(2.6, 1.6), {
		text = "QUARTERS 3-W\nHot water 0600-0630\nLaundry: Bay C\nAsh advisory: east",
	})
end

return Builder
