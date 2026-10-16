--!nonstrict
-- builders/maps/central_command/Equipment.lua  ->  DevTools.Builders.CentralCommand.Equipment
-- docs/maps/map_01_central_command.md §7: X 80..130, Z -40..0, ceiling 18. Its roof is the Observation Deck (Y 20).
-- The west wall with the door is the East Corridor's east wall.
--
-- Passes: blockout = shell, the counter and terminal stand-ins (INT_EQUIP_TERMINAL); structure = finishes, ceiling
-- strips, exterior pilasters; dressed = the counter X 112..116, Z -34..-6 (STEEL_MID top) with its clutter and a
-- hanging sign, the Equipment Terminal as a console at (126, 0, -20) facing west under a wall screen and a hologram,
-- lockers (row of 10) along the north wall, three pilot-suit racks (4 suits each), the helmet shelf (12 helmets),
-- crates, a bench. opts: Common, BK, Props (structure and up), pass.

local Builder = {}

local V = Vector3.new
local TRIM = 0.4

-- Pilot suits (03 §uniforms): #2B2F36 with each pilot's piping; plain for spares.
local SUITS = { "#E07A1F", "#C8483C", "#5FAF6A", nil }

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "CentralCommand", "Equipment")
	local BK, P, S = ctx.BK, ctx.P, ctx.Structure

	local floor = BK.floor(S, "Floor", 80, 130, -40, 0, 0, 1, ctx.FLOOR)
	BK.ceiling(S, "Roof", 80, 130, -40, 0, 18, 2, ctx.ROOF) -- top Y 20 = deck surface
	BK.wallX(S, "Wall_N", 80.5, 131, -40, 0, 22, C.EXT, ctx.EXT) -- 22 = parapet top
	BK.wallZ(S, "Wall_E", -39, 0, 130, 0, 22, C.EXT, ctx.EXT)
	BK.wallX(S, "Wall_Divider", 80.5, 129, 0, 0, 18, C.INT, ctx.INT) -- shared with Medical

	local Lib = opts.Props
	if ctx.level >= 2 then
		Builder.structure(ctx, C)
	end
	if ctx.level >= 3 then
		Builder.dress(ctx, C, Lib)
		C.tileSeams(ctx, floor, nil)
	else
		-- Counter X 112..116, Z -34..-6, 2.8 tall; the Equipment Terminal behind it at (126, 0, -20), facing west.
		C.standIn(ctx, "Counter_StandIn", V(112, 0, -34), V(116, 2.8, -6))
		local terminal = C.standIn(ctx, "EquipTerminal_StandIn", V(124.75, 0, -23), V(127.25, 3, -17), { Color = P.STEEL_DARK })
		-- Enabled since Phase 6 (upgrades). The console stands behind the counter, so it reaches across it (D-097).
		BK.prompt(terminal, "INT_EQUIP_TERMINAL", "Use", { dist = 18, lineOfSight = false })
	end

	C.placeRegistry(ctx)
	return C.finish(ctx)
end

function Builder.structure(ctx, C)
	local BK, P = ctx.BK, ctx.P
	BK.box(ctx.Structure, "CeilingLining", V(80.5, 17.9, -39), V(129, 18, -0.5), { Color = "#8A9096", CastShadow = false })
	local door = { { from = -24 - TRIM, to = -16 + TRIM, y1 = 0, y2 = C.DOUBLE_H + TRIM } }
	C.face(ctx, "FaceW", V(80.5, 0, -39), V(80.5, 0, -0.5), V(1, 0, 0), { kind = "interior", top = 17.9, gaps = door })
	C.face(ctx, "FaceN", V(80.5, 0, -39), V(129, 0, -39), V(0, 0, 1), { kind = "interior", top = 17.9, lining = true })
	C.face(ctx, "FaceE", V(129, 0, -39), V(129, 0, -0.5), V(-1, 0, 0), { kind = "interior", top = 17.9, lining = true })
	C.face(ctx, "FaceS", V(80.5, 0, -0.5), V(129, 0, -0.5), V(0, 0, -1), { kind = "interior", top = 17.9 })
	C.face(ctx, "Ext_N", V(80.5, 0, -41), V(131, 0, -41), V(0, 0, -1), { kind = "exterior", top = 22 })
	C.face(ctx, "Ext_E", V(131, 0, -41), V(131, 0, 0), V(1, 0, 0), { kind = "exterior", top = 22 })
	for i, p in ipairs({ { 90, -30 }, { 90, -10 }, { 104, -30 }, { 104, -10 }, { 121, -30 }, { 121, -10 } }) do
		C.fixture(ctx, "Strip" .. i, V(p[1], 17.85, p[2]), V(6, 0.15, 0.3), { Brightness = 1, Range = 18 })
	end
end

function Builder.dress(ctx, C, Lib)
	local BK, P = ctx.BK, ctx.P
	local F = ctx.Props
	local soft = { CanCollide = false, CanQuery = false, CastShadow = false }
	local function with(extra)
		local t = table.clone(soft)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	-- The counter: a steel body with panel seams, a STEEL_MID top, a hatch flap, clutter, a hanging sign.
	BK.box(F, "Counter", V(112.3, 0, -34), V(115.7, 2.6, -6), { Color = P.STEEL_DARK, Material = "Metal" })
	BK.box(F, "CounterTop", V(112, 2.6, -34.2), V(116, 2.8, -5.8), { Color = P.STEEL_MID, Material = "Metal" })
	for z = -30, -10, 4 do
		BK.box(F, "CounterSeam", V(112.24, 0.3, z - 0.05), V(112.3, 2.5, z + 0.05), with({ Color = P.KICKPLATE }))
	end
	BK.box(F, "CounterKick", V(112.2, 0, -34), V(112.3, 0.4, -6), with({ Color = P.KICKPLATE }))
	Lib.Terminal(F, CFrame.new(114.2, 2.8, -27) * Lib.FACE["-X"], { name = "CounterTerminal", lines = { "REQUISITIONS", "QM MORROW, D.", "Queue: 0" } })
	Lib.Clipboard(F, CFrame.new(113.4, 2.8, -22) * CFrame.Angles(0, math.rad(80), 0), { name = "CounterClipboard" })
	Lib.Datapad(F, CFrame.new(113.6, 2.8, -15) * CFrame.Angles(0, math.rad(100), 0), { name = "CounterDatapad" })
	Lib.MetalCase(F, CFrame.new(114.2, 2.8, -10) * Lib.FACE["-X"], { name = "CounterCase" })
	for _, z in ipairs({ -30, -10 }) do
		BK.box(F, "SignChain", V(113.95, 15.5, z - 0.05), V(114.05, 17.9, z + 0.05), with({ Color = P.STEEL_DARK }))
	end
	BK.sign(ctx.Detail, "Sign_Quartermaster", BK.lookAlong(V(113.9, 14.6, -20), V(-1, 0, 0)), Vector2.new(22, 1.8), "EQUIPMENT / QUARTERMASTER", { light = true })

	-- The Equipment Terminal: a console at (126, 0, -20) facing west (the prompt reaches across the counter, D-097),
	-- a wall screen above it and a hologram of the upgrades.
	local console = Lib.Console(F, CFrame.new(126, 0, -20) * Lib.FACE["-X"], {
		name = "EquipTerminal", seed = 97, lines = { "VANGUARD UPGRADES", "THRUSTER · CAPACITOR", "ARMOR · CORE" }, holo = "UPGRADES",
	})
	BK.prompt(console.PrimaryPart, "INT_EQUIP_TERMINAL", "Use", { dist = 18, lineOfSight = false })
	BK.screen(ctx.Detail, "UpgradeWall", BK.lookAlong(V(128.9, 8.5, -20), V(-1, 0, 0)), Vector2.new(10, 4.4), {
		text = "VANGUARD SERVICE BAY\nUpgrades by rank · credits\nTHRUSTER BAFFLES  ·  CAPACITOR BANK I\nREINFORCED PLATING  ·  CORE TUNING",
	})
	BK.box(F, "UpgradeWallFrame", V(128.94, 6.1, -25.2), V(129, 10.9, -14.8), with({ Color = P.STEEL_DARK, Material = "Metal" }))

	-- Lockers (row of 10) along the north wall.
	Lib.Locker(F, CFrame.new(94, 0, -38) * Lib.FACE["+Z"], { name = "Lockers", count = 10 })

	-- Pilot-suit racks: a bar on two posts with 4 suits (shoulders, torso, sleeves, the piping), two behind the counter
	-- and one by the divider.
	local function rack(name, cf)
		local kit = Lib.kit(F, name, cf)
		local steel = with({ Color = P.STEEL_LIGHT, Material = "Metal" })
		for _, x in ipairs({ -4.2, 4.2 }) do
			kit.box("Post", V(0.2, 6.4, 0.2), V(x, 3.2, 0), steel)
			kit.box("Foot", V(0.3, 0.15, 1.6), V(x, 0.08, 0), steel)
		end
		kit.box("Bar", V(8.6, 0.15, 0.15), V(0, 6.3, 0), steel)
		for i = 1, 4 do
			local x = -3.15 + (i - 1) * 2.1
			local suit = with({ Color = "#2B2F36", Material = "Fabric" })
			kit.box("Hanger", V(1.4, 0.1, 0.1), V(x, 6.05, 0), with({ Color = P.STEEL_DARK }))
			kit.box("Shoulders", V(1.6, 0.45, 0.6), V(x, 5.7, 0), suit)
			kit.box("Torso", V(1.3, 2.2, 0.45), V(x, 4.4, 0), suit)
			for _, sx in ipairs({ -0.75, 0.75 }) do
				kit.box("Sleeve", V(0.32, 2.1, 0.4), V(x + sx, 4.5, 0), suit)
			end
			kit.box("Legs", V(1.1, 2.4, 0.4), V(x, 2.15, 0), suit)
			local piping = SUITS[i]
			if piping then
				kit.box("Piping", V(0.06, 2.0, 0.42), V(x + 0.92, 4.5, 0), with({ Color = piping, Material = "Neon", Transparency = 0.3 }))
			end
		end
		kit.finish()
	end
	rack("SuitRack1", CFrame.new(122, 0, -35))
	rack("SuitRack2", CFrame.new(122, 0, -5) * Lib.FACE["+Z"])
	rack("SuitRack3", CFrame.new(96, 0, -4))

	-- The helmet shelf on the east wall north of the terminal: 12 helmets (a ball and a visor wedge) on 3 boards.
	for row = 0, 2 do
		local y = 3.4 + row * 1.9
		BK.box(F, "HelmetBoard" .. row, V(127.4, y - 0.15, -37), V(129, y, -28), { Color = P.STEEL_MID, Material = "Metal" })
		for i = 0, 3 do
			local z = -35.8 + i * 2.2
			BK.ball(F, with({ Name = "Helmet", Size = V(1.3, 1.3, 1.3), Position = V(128.1, y + 0.65, z), Color = "#2B2F36", Material = "SmoothPlastic" }))
			BK.wedge(F, with({ Name = "HelmetVisor", Size = V(0.9, 0.5, 0.35), CFrame = CFrame.new(127.45, y + 0.75, z) * CFrame.Angles(0, -math.pi / 2, 0), Color = "#2A3138", Material = "Glass", Transparency = 0.15 }))
		end
	end

	-- Crates (clear of the lockers, the counter and the way in from the door) and a bench for the pilots.
	Lib.CrateStack(F, CFrame.new(87.5, 0, -10), { name = "Crates1", seed = 71, count = 4 })
	Lib.CrateStack(F, CFrame.new(105.5, 0, -35) * Lib.FACE["+Z"], { name = "Crates2", seed = 72, count = 3 })
	Lib.Bench(F, CFrame.new(96, 0, -26), { name = "Bench" })
	Lib.Vent(F, CFrame.new(100, 15, -39) * Lib.FACE["+Z"], { name = "Vent" })
end

return Builder
