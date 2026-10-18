--!nonstrict
-- builders/maps/central_command/Research.lua  ->  DevTools.Builders.CentralCommand.Research
-- docs/maps/map_01_central_command.md §10: Research Corridor X 80..200, Z -60..-48, ceiling 12, locked security
-- door at X 100 (DOOR_RESEARCH); Voss Lab X 200..250, Z -80..-20 (shell only in the Vertical Slice).
--
-- Passes (docs/07 §2): blockout = corridor (concrete walls, a header at X 80 under the East corridor's ceiling), the
-- security door (SmoothPlastic window) and its prompt, the lab shell, FrameBarriers to Y 40 over the corridor (from its
-- roof) and the lab (every pass); structure = the corridor's white lining and finishes, LIGHT_COOL strips every 10, the security
-- door's sign, exterior kickplates and pilasters, the lab's parapet and closed door; dressed = the corridor's wall
-- panel seams; the door's card reader, hazard band and camera on the near side; through the window the containment
-- canister at X 190 (clue 3: an AMBER_CORE mass pulsing at 2.0 s, tag Pulse, AmbientController), its console,
-- cabinets, pipes; rooftop units seen from the Observation Deck.
-- opts: Common, BK, Props (structure pass and up), pass.

local Builder = {}

local V = Vector3.new

local Z1, Z2 = -59, -49 -- the corridor's clear width (walls are 2 thick on Z -60 and -48)
local CEIL = 12
local NODULE = "#B5651D" -- map_01 §10
local PULSE = { PulsePeriod = 2.0 } -- map_01 §10: the mass pulses at a 2.0 s period

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Research")
	local BK, P, S, G = ctx.BK, ctx.P, ctx.Structure, ctx.Gameplay
	local white = { Color = P.MEDICAL_WHITE }
	local Lib = opts.Props
	if ctx.level >= 2 and not Lib then
		error("Research: the structure and dressed passes need opts.Props", 2)
	end

	local floor = BK.floor(S, "Floor", 80, 200, -60, -48, 0, 1, { Color = "#D5DADE" })
	BK.ceiling(S, "Ceiling", 80, 200, -60, -48, CEIL, 1, ctx.CEIL)
	-- Exterior walls are Concrete CONCRETE_MID (map_01 §2); the structure pass lines their corridor faces in white.
	BK.wallX(S, "Wall_N", 80, 199, -60, 0, 13, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_S", 80, 199, -48, 0, 13, C.EXT, ctx.EXT)
	-- The East corridor's ceiling is 2 higher (bottom Y 14): a header closes X 80 between this roof (13) and it.
	BK.box(S, "Header_W", V(80, 13, -59), V(81, 14, -48), ctx.EXT)

	-- Security door: steel, 10 x 10, fills the corridor (clear width Z -59..-49), window 3 x 2 at Y 4..6.
	local door = BK.model(G, "DOOR_RESEARCH")
	BK.tag(door, "Door")
	BK.attr(door, { DoorId = "DOOR_RESEARCH", Locked = true, Width = 10, Height = 10 })
	local steel = { Color = P.STEEL_MID, Material = "Metal" }
	local lower = BK.box(door, "Leaf_Lower", V(99.5, 0, -59), V(100.5, 4, -49), steel)
	BK.box(door, "Leaf_Upper", V(99.5, 6, -59), V(100.5, 10, -49), steel)
	BK.box(door, "Leaf_Left", V(99.5, 4, -59), V(100.5, 6, -55.5), steel)
	BK.box(door, "Leaf_Right", V(99.5, 4, -52.5), V(100.5, 6, -49), steel)
	-- SmoothPlastic, not Glass (map_01 §10 says Glass): the engine doesn't draw transparent parts behind Glass
	-- material, and the canister, its ring and the clue-3 mass seen through this window are all transparent.
	BK.box(door, "Window", V(99.9, 4, -55.5), V(100.1, 6, -52.5), { Color = P.GLASS, Transparency = ctx.GLASS.Transparency })
	BK.box(door, "Lintel", V(99.5, 10, -59), V(100.5, 12, -49), white)
	BK.box(door, "StatusStrip", V(99.35, 10.2, -57), V(99.5, 10.5, -51), { Color = P.DANGER_RED, Material = "Neon", CanCollide = false, CanQuery = false })
	door.PrimaryPart = lower
	BK.prompt(lower, "INT_RESEARCH_DOOR", "Open")

	-- Voss Lab shell (closed; the interior is Chapter 2).
	BK.floor(S, "Lab_Floor", 200, 250, -80, -20, 0, 1, { Color = "#D5DADE" })
	BK.ceiling(S, "Lab_Roof", 199, 251, -81, -19, 16, 1, ctx.ROOF)
	BK.wallX(S, "Lab_Wall_N", 199, 251, -80, 0, 16, C.EXT, ctx.EXT)
	BK.wallX(S, "Lab_Wall_S", 199, 251, -20, 0, 16, C.EXT, ctx.EXT)
	BK.wallZ(S, "Lab_Wall_W", -79, -21, 200, 0, 16, C.EXT, ctx.EXT)
	BK.wallZ(S, "Lab_Wall_E", -79, -21, 250, 0, 16, C.EXT, ctx.EXT)

	-- FrameBarriers (docs/07 §5, 40 tall): a 64-stud Frame would walk up onto the corridor roof (13) and the lab (19).
	-- The corridor's sits on its roof (Y 13 up; a Frame's root floats at 22-38), so the corridor stays clear and the
	-- door prompt keeps its line of sight (a queryable part in front of a prompt's part hides it: D-101 (9)).
	BK.barrier(G, "FrameBarrier_Corridor", V(80, 13, -61), V(199, 40, -47), "FrameBarrier")
	BK.barrier(G, "FrameBarrier_VossLab", V(199, 0, -81), V(251, 40, -19), "FrameBarrier")

	if ctx.level >= 2 then
		Builder.structure(ctx, C, Lib)
	end
	if ctx.level >= 3 then
		Builder.dressSeams(ctx)
		Builder.dressNear(ctx, C, Lib)
		Builder.dressFar(ctx, C, Lib)
		Builder.dressRoofs(ctx, C, Lib)
		C.tileSeams(ctx, floor, nil)
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.structure(ctx, C, Lib)
	local BK, P, S, D = ctx.BK, ctx.P, ctx.Structure, ctx.Detail
	local function detail(color, material)
		return { Color = color, Material = material or "SmoothPlastic", CastShadow = false, Tags = { "Detail" } }
	end

	-- White corridor: a MEDICAL_WHITE lining over the concrete walls' inner faces, a dark kickplate, a SLATE band at
	-- 3, a STEEL_DARK ceiling trim on both long walls; the door interrupts them at X 99.5..100.5.
	for _, w in ipairs({ { "N", Z1, 1 }, { "S", Z2, -1 } }) do
		local z, n = w[2], w[3]
		for i, run in ipairs({ { 80, 99.5 }, { 100.5, 199 } }) do
			local function band(folder, name, y1, y2, depth, props)
				BK.box(folder, ("%s_%s%d"):format(name, w[1], i), V(run[1], y1, math.min(z, z + n * depth)), V(run[2], y2, math.max(z, z + n * depth)), props)
			end
			band(S, "Lining", 0, CEIL, 0.04, { Color = P.MEDICAL_WHITE, CastShadow = false })
			band(D, "Kick", 0, 1, 0.1, detail(P.KICKPLATE))
			band(D, "Band", 2.85, 3.15, 0.14, detail(P.SLATE))
			band(D, "CeilTrim", CEIL - 0.35, CEIL, 0.16, detail(P.STEEL_DARK, "Metal"))
		end
	end

	-- LIGHT_COOL strips every 10 (06 §5 corridor strips): two on the near side, ten past the door.
	local strip = 0
	for x = 85, 195, 10 do
		strip += 1
		C.fixture(ctx, "Strip" .. strip, V(x, CEIL - 0.1, -54), V(6, 0.15, 0.3), { Color = P.LIGHT_COOL, Brightness = 1, Range = 16 })
	end

	-- The security door's sign over its leaf, on the player's side (map_01 §10).
	BK.sign(D, "Sign_Restricted", BK.lookAlong(V(99.4, 11.25, -54), V(-1, 0, 0)), Vector2.new(9.6, 1.2), "RESTRICTED — SCIENCE DIVISION — CLEARANCE 3", {
		textColor = P.HAZARD_BLACK, bgColor = P.HAZARD_YELLOW,
	})

	-- Outside: the corridor's long faces and the lab's four faces (kickplate, pilasters every 24); the lab's parapet.
	C.face(ctx, "Ext_N", V(80, 0, -61), V(199, 0, -61), V(0, 0, -1), { kind = "exterior", top = 13 })
	C.face(ctx, "Ext_S", V(81, 0, -47), V(199, 0, -47), V(0, 0, 1), { kind = "exterior", top = 13 })
	C.face(ctx, "Lab_Ext_N", V(199, 0, -81), V(251, 0, -81), V(0, 0, -1), { kind = "exterior", top = 16 })
	C.face(ctx, "Lab_Ext_S", V(199, 0, -19), V(251, 0, -19), V(0, 0, 1), { kind = "exterior", top = 16 })
	C.face(ctx, "Lab_Ext_E", V(251, 0, -81), V(251, 0, -19), V(1, 0, 0), { kind = "exterior", top = 16 })
	C.face(ctx, "Lab_Ext_W", V(199, 0, -81), V(199, 0, -19), V(-1, 0, 0), { kind = "exterior", top = 16, gaps = { { from = -61, to = -47, y1 = 0, y2 = 13 } } })
	local parapet = { Color = P.CONCRETE_DARK, Material = "Concrete" }
	BK.box(S, "Lab_Parapet_N", V(199, 17, -81), V(251, 19, -80), parapet)
	BK.box(S, "Lab_Parapet_S", V(199, 17, -20), V(251, 19, -19), parapet)
	BK.box(S, "Lab_Parapet_W", V(199, 17, -80), V(200, 19, -20), parapet)
	BK.box(S, "Lab_Parapet_E", V(250, 17, -80), V(251, 19, -20), parapet)

	-- The lab's closed door at the corridor's end (map_01 §10: "Door at X 200 closed"), locked: a red strip.
	BK.door(S, "Door_VossLab", CFrame.new(198.75, 0, -54) * Lib.FACE["-X"], 8, C.DOUBLE_H, { double = true, locked = true, wallThickness = 0.5, sign = "SCIENCE DIVISION" })
end

-- Wall panel seams on the corridor's white faces (docs/07 §7): vertical every 16 (world multiples) and a horizontal
-- at 10, 0.2 wide, 0.05 proud of the lining, 8% darker than MEDICAL_WHITE. The SLATE band stands in for the one at 3.
function Builder.dressSeams(ctx)
	local BK, P, D = ctx.BK, ctx.P, ctx.Detail
	local seam = { Color = BK.darken(P.MEDICAL_WHITE, 0.08), CastShadow = false, Tags = { "Detail" } }
	for _, w in ipairs({ { "N", Z1, 1 }, { "S", Z2, -1 } }) do
		local z, n = w[2], w[3]
		local z1, z2 = math.min(z + n * 0.04, z + n * 0.09), math.max(z + n * 0.04, z + n * 0.09)
		for i, run in ipairs({ { 80, 99.5 }, { 100.5, 199 } }) do
			BK.box(D, ("SeamH_%s%d"):format(w[1], i), V(run[1], 9.9, z1), V(run[2], 10.1, z2), seam)
			for x = math.ceil(run[1] / 16) * 16, run[2], 16 do
				if x - 0.6 > run[1] and x + 0.6 < run[2] then
					BK.box(D, ("SeamV_%s%d_Low"):format(w[1], x), V(x - 0.1, 1, z1), V(x + 0.1, 2.85, z2), seam)
					BK.box(D, ("SeamV_%s%d"):format(w[1], x), V(x - 0.1, 3.15, z1), V(x + 0.1, CEIL - 0.35, z2), seam)
				end
			end
		end
	end
end

-- The player's side of the door (X 80..100).
function Builder.dressNear(ctx, C, Lib)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- Panel seams and a hazard band across the leaf's foot.
	for _, y in ipairs({ 3, 7.5 }) do
		BK.box(D, "DoorSeam", V(99.42, y - 0.05, Z1 + 0.3), V(99.5, y + 0.05, Z2 - 0.3), with({ Color = P.STEEL_DARK }))
	end
	BK.hazardStripe(D, "DoorHazard", CFrame.fromMatrix(V(99.5, 1.1, -54), V(0, 0, 1), V(-1, 0, 0)), 9.6, 1.2, { stripe = 1.2 })
	BK.box(D, "DoorWindowFrame_T", V(99.38, 6, -55.7), V(99.5, 6.2, -52.3), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.box(D, "DoorWindowFrame_B", V(99.38, 3.8, -55.7), V(99.5, 4, -52.3), with({ Color = P.STEEL_DARK, Material = "Metal" }))

	-- The card reader on the north wall beside the door, its red light.
	BK.box(F, "CardReader", V(97.4, 3.6, Z1), V(98.4, 5, Z1 + 0.25), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.box(D, "CardReader_Slot", V(97.6, 3.9, Z1 + 0.25), V(98.2, 4.0, Z1 + 0.3), with({ Color = P.HAZARD_BLACK }))
	BK.box(D, "CardReader_Light", V(97.75, 4.55, Z1 + 0.25), V(98.05, 4.8, Z1 + 0.32), with({ Color = P.DANGER_RED, Material = "Neon" }))

	-- The floor before the door: a hazard band and painted text; a camera watching the door from the south wall.
	BK.hazardStripe(D, "FloorHazard", CFrame.new(97.8, 0, -54) * CFrame.Angles(0, math.pi / 2, 0), 10, 2.4)
	BK.floorText(D, "Floor_Clearance", V(93.5, 0, -54), Vector2.new(8, 1.4), "CLEARANCE 3 ONLY", { textUp = V(1, 0, 0) })
	BK.box(D, "Camera_Mount", V(95.85, 10.8, Z2 - 0.6), V(96.15, 11.1, Z2), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.part(F, with({ Name = "Camera", Size = V(1.2, 0.5, 0.5), CFrame = CFrame.lookAt(V(96.4, 10.5, Z2 - 0.8), V(100, 5, -54)) * CFrame.Angles(0, math.pi / 2, 0), Color = P.MEDICAL_WHITE }))
	BK.box(D, "Camera_Lamp", V(96.0, 10.75, Z2 - 0.85), V(96.15, 10.9, Z2 - 0.7), with({ Color = P.DANGER_RED, Material = "Neon" }))

	-- A conduit along the north wall's top, a vent on the south wall.
	BK.pipeRun(D, "Conduit", { V(80.5, CEIL - 0.6, Z1 + 0.4), V(99.2, CEIL - 0.6, Z1 + 0.4) }, 0.15, { color = P.STEEL_MID })
	Lib.Vent(F, CFrame.new(88, 9, Z2) * Lib.FACE["-Z"], { name = "Vent" })
end

-- Past the door (seen through its 3 x 2 window): the canister on its pedestal, a console, cabinets, pipes.
function Builder.dressFar(ctx, C, Lib)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	local cx, cz = 190, -54

	-- Containment canister (clue 3): a pedestal, a glass cylinder 3 across and 6 tall, caps, feed pipes to the ceiling.
	local can = BK.model(F, "ContainmentCanister")
	BK.cyl(can, { Name = "Pedestal", Axis = "Y", Size = V(4.2, 2, 4.2), CFrame = CFrame.new(cx, 1, cz), Color = P.STEEL_DARK, Material = "Metal" })
	BK.cyl(can, with({ Name = "PedestalRing", Axis = "Y", Size = V(4.3, 0.15, 4.3), CFrame = CFrame.new(cx, 1.6, cz), Color = BK.GLOW.amber.Color, Material = "Neon", Transparency = BK.GLOW.amber.Transparency }))
	BK.cyl(can, { Name = "BaseCap", Axis = "Y", Size = V(3.6, 0.5, 3.6), CFrame = CFrame.new(cx, 2.25, cz), Color = P.STEEL_MID, Material = "Metal" })
	-- SmoothPlastic, not Glass: the engine doesn't draw transparent parts (the mass) behind Glass material.
	BK.cyl(can, { Name = "Glass", Axis = "Y", Size = V(3, 6, 3), CFrame = CFrame.new(cx, 5.5, cz), Color = P.GLASS, Transparency = 0.78, Reflectance = 0.15, CastShadow = false })
	BK.cyl(can, { Name = "TopCap", Axis = "Y", Size = V(3.6, 0.6, 3.6), CFrame = CFrame.new(cx, 8.8, cz), Color = P.STEEL_MID, Material = "Metal" })
	for i, dz in ipairs({ -0.8, 0.8 }) do
		BK.cyl(can, with({ Name = "FeedPipe" .. i, Axis = "Y", Size = V(0.4, CEIL - 9.1, 0.4), CFrame = CFrame.new(cx, (9.1 + CEIL) / 2, cz + dz), Color = P.STEEL_LIGHT, Material = "Metal" }))
	end
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		BK.box(can, "Strut" .. i, V(cx + math.cos(a) * 1.55 - 0.1, 2.5, cz + math.sin(a) * 1.55 - 0.1), V(cx + math.cos(a) * 1.55 + 0.1, 8.5, cz + math.sin(a) * 1.55 + 0.1), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	end
	-- The mass: five glowing lobes, Neon AMBER_CORE at 0.3 (map_01 §10; cores are outside D-099's glow calibration,
	-- like clue 2's exposed core in Unit 03), and three darker nodules.
	local glow = P.AMBER_CORE
	for i, b in ipairs({ { 0, 4.6, 0, 1.8 }, { 0.45, 5.6, 0.2, 1.4 }, { -0.4, 5.3, -0.35, 1.3 }, { 0.1, 6.5, -0.15, 1.1 }, { -0.25, 4.3, 0.5, 1.2 } }) do
		BK.ball(can, with({ Name = "Mass" .. i, Size = Vector3.one * b[4], CFrame = CFrame.new(cx + b[1], b[2], cz + b[3]), Color = glow, Material = "Neon", Transparency = 0.3, Tags = { "Pulse" }, Attributes = PULSE }))
	end
	for i, b in ipairs({ { 0.6, 4.9, -0.4, 0.8 }, { -0.5, 6.0, 0.3, 0.7 }, { 0.2, 3.9, -0.6, 0.6 } }) do
		BK.ball(can, with({ Name = "Nodule" .. i, Size = Vector3.one * b[4], CFrame = CFrame.new(cx + b[1], b[2], cz + b[3]), Color = NODULE }))
	end
	local core = can:FindFirstChild("Mass1")
	BK.light(core, "Point", { Color = P.AMBER_CORE, Brightness = 1.5, Range = 14, Tags = { "Pulse" }, Attributes = PULSE })
	can.PrimaryPart = can:FindFirstChild("Pedestal")
	BK.hazardStripe(D, "CanisterHazard_W", CFrame.new(cx - 3.6, 0, cz) * CFrame.Angles(0, math.pi / 2, 0), 8.4, 1.2)
	BK.hazardStripe(D, "CanisterHazard_E", CFrame.new(cx + 3.6, 0, cz) * CFrame.Angles(0, math.pi / 2, 0), 8.4, 1.2)

	-- Its monitoring console against the north wall, facing south; a feed cable along the floor.
	Lib.Console(F, CFrame.new(181, 0, Z1 + 1.4) * Lib.FACE["+Z"], {
		name = "Console_Canister", lines = { "CONTAINMENT · BAY 2", "Seal integrity 100%", "Cycle 2.0 s · nominal" },
	})
	Lib.CableRun(F, V(183.5, 0, Z1 + 1.6), V(188, 0, cz), { name = "Cable_Canister" })

	-- Cabinets along the north wall, a pipe run along the south wall's top, a vent, a fire station.
	for i, x in ipairs({ 128, 134, 160 }) do
		Lib.MedCabinet(F, CFrame.new(x, 0, Z1 + 0.7) * Lib.FACE["+Z"], { name = "Cabinet" .. i })
	end
	BK.pipeRun(D, "Pipes_S", { V(100.6, CEIL - 0.7, Z2 - 0.45), V(198.5, CEIL - 0.7, Z2 - 0.45) }, 0.22, { color = P.STEEL_LIGHT })
	BK.pipeRun(D, "Pipes_S2", { V(100.6, CEIL - 1.4, Z2 - 0.4), V(198.5, CEIL - 1.4, Z2 - 0.4) }, 0.14, { color = P.MEDICAL_WHITE })
	Lib.Vent(F, CFrame.new(146, 9, Z2) * Lib.FACE["-Z"], { name = "Vent_Far" })
	Lib.ExtinguisherStation(F, CFrame.new(112, 4.2, Z2) * Lib.FACE["-Z"], { name = "Extinguisher" })
	BK.floorText(D, "Floor_Specimen", V(176, 0, -54), Vector2.new(9, 1.4), "CONTAINMENT AREA — NO UNESCORTED ACCESS", { textUp = V(1, 0, 0) })
end

-- Seen from the Observation Deck: units on the lab roof, a vent stack on the corridor roof.
function Builder.dressRoofs(ctx, C, Lib)
	local BK, P, F, D = ctx.BK, ctx.P, ctx.Props, ctx.Detail
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end
	for i, p in ipairs({ { 214, -66 }, { 232, -66 } }) do
		BK.box(F, "RoofUnit" .. i, V(p[1] - 4, 17, p[2] - 3), V(p[1] + 4, 20.4, p[2] + 3), { Color = P.STEEL_MID, Material = "Metal" })
		BK.cyl(D, with({ Name = "RoofUnit_Fan" .. i, Axis = "Y", Size = V(4, 0.2, 4), CFrame = CFrame.new(p[1], 20.5, p[2]), Color = P.STEEL_DARK, Material = "Metal" }))
	end
	BK.pipeRun(D, "RoofDuct", { V(214, 18.5, -62.8), V(214, 18.5, -40), V(232, 18.5, -40), V(232, 18.5, -62.8) }, 0.6, { color = P.STEEL_LIGHT })
	for i, x in ipairs({ 120, 160 }) do
		BK.cyl(F, { Name = "VentStack" .. i, Axis = "Y", Size = V(1.4, 3, 1.4), CFrame = CFrame.new(x, 14.5, -54), Color = P.STEEL_MID, Material = "Metal" })
		BK.cyl(D, with({ Name = "VentStack_Cap" .. i, Axis = "Y", Size = V(2, 0.3, 2), CFrame = CFrame.new(x, 16.2, -54), Color = P.STEEL_DARK, Material = "Metal" }))
	end
	BK.box(D, "Antenna", V(240.9, 17, -26.1), V(241.1, 27, -25.9), with({ Color = P.STEEL_DARK, Material = "Metal" }))
	BK.box(D, "Antenna_Lamp", V(240.8, 27, -26.2), V(241.2, 27.4, -25.8), with({ Color = P.DANGER_RED, Material = "Neon" }))
end

return Builder
