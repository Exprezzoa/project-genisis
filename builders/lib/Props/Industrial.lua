--!nonstrict
-- Props/Industrial: Crate (S/M/L), CrateStack, MetalCase, Barrel, ToolCart, Forklift, FloodlightMast, JerseyBarrier,
-- StreetLamp, the hangar's PowerCabinet, PlateRack, MobileStair, Bollard, ExtinguisherStation, CoolantTank (new), and the
-- motor pool's FuelTank.
-- Recipes: docs/07_building_with_parts.md §6. cframe = the bottom-center on the floor, facing -Z.

local V = Vector3.new

return function(Props, BK)
	local P = Props.P
	local soft = { CanCollide = false, CastShadow = false, CanQuery = false }

	local function with(base, extra)
		local t = table.clone(base)
		for k, v in pairs(extra) do
			t[k] = v
		end
		return t
	end

	local CRATE_SIZES = { S = V(3, 3, 3), M = V(4, 4, 4), L = V(6, 4, 4) }
	local STENCILS = { "UDD", "HALDEN", "FRAGILE" }

	-- Crate S / M / L: WoodPlanks WOOD_OLD, four edge battens #4F3E2E, a stencil on +-Z, corner caps on M and L.
	-- opts.size ("S" | "M" | "L"), opts.stencil.
	function Props.Crate(parent, cframe, opts)
		opts = opts or {}
		local size = CRATE_SIZES[opts.size or "M"]
		local k = Props.kit(parent, opts.name or "Crate", cframe)
		local body = k.box("Body", size, V(0, size.Y / 2, 0), { Color = P.WOOD_OLD, Material = "WoodPlanks" })
		local batten = with({ Color = "#4F3E2E", Material = "Wood" }, soft)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			k.box("Batten", V(0.3, size.Y, 0.3), V(c[1] * (size.X / 2 - 0.1), size.Y / 2, c[2] * (size.Z / 2 - 0.1)), batten)
		end
		for _, side in ipairs({ -1, 1 }) do
			k.box("Band", V(size.X - 0.2, 0.3, 0.06), V(0, size.Y * 0.75, side * (size.Z / 2 + 0.02)), batten)
		end
		if opts.size ~= "S" then
			for _, c in ipairs({ { -1, -1 }, { 1, 1 } }) do
				k.box("Cap", V(0.6, 0.6, 0.6), V(c[1] * (size.X / 2 - 0.2), size.Y - 0.2, c[2] * (size.Z / 2 - 0.2)), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
			end
		end
		local text = opts.stencil or STENCILS[1]
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Props.gui(body, face, 0.6, 40)
			gui.Name = "Stencil_" .. face.Name
			Props.label(gui, text, 0.12, 0.3, 0.76, 0.3, { font = Props.FONT.header, color = P.KICKPLATE, xAlign = "Center", transparency = 0.25 })
		end
		return k.finish(body)
	end

	-- CrateStack: 3-6 crates one crate deep (footprint about 12 x 4, so it stands against a wall), seeded rotation +-8°,
	-- the upper ones offset. opts.seed, opts.count.
	function Props.CrateStack(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 1)
		local model = BK.model(parent, opts.name or "CrateStack")
		local count = opts.count or rng.int(3, 6)
		local layout = { { -3.2, 0, "L" }, { 3.2, 0, "M" }, { -2.4, 0, "M", 4 }, { 3.0, 0, "S", 4 }, { -1.8, 0, "S", 8 }, { 0.9, 0, "S", 4 } }
		for i = 1, count do
			local l = layout[i]
			local y = l[4] or 0
			local cf = cframe * CFrame.new(l[1], y, l[2]) * CFrame.Angles(0, math.rad(rng.next(-8, 8)), 0)
			Props.Crate(model, cf, { name = "Crate" .. i, size = l[3], stencil = rng.pick(STENCILS) })
		end
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		return model
	end

	-- MetalCase 4 x 2 x 2.5: Metal STEEL_MID, a lid seam, two small amber clasps (calibrated glow), a handle.
	function Props.MetalCase(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "MetalCase", cframe)
		local body = k.box("Body", V(4, 2, 2.5), V(0, 1, 0), { Color = P.STEEL_MID, Material = "Metal" })
		k.box("LidSeam", V(4.04, 0.1, 2.54), V(0, 1.45, 0), with({ Color = P.KICKPLATE }, soft))
		for _, x in ipairs({ -1.2, 1.2 }) do
			k.box("Clasp", V(0.3, 0.2, 0.06), V(x, 1.45, -1.29), with(Props.glow, soft))
		end
		k.box("Handle", V(1.4, 0.15, 0.15), V(0, 2.12, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		return k.finish(body)
	end

	-- Barrel 2.6 x 3.6: a cylinder #5B6770 or RUST (opts.rust), two STEEL_DARK rings, a lid disc.
	function Props.Barrel(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Barrel", cframe)
		local body = k.cyl("Body", "Y", V(2.6, 3.6, 2.6), V(0, 1.8, 0), { Color = if opts.rust then P.RUST else "#5B6770", Material = if opts.rust then "CorrodedMetal" else "Metal" })
		for _, y in ipairs({ 1.1, 2.5 }) do
			k.cyl("Ring", "Y", V(2.7, 0.2, 2.7), V(0, y, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		end
		k.cyl("Lid", "Y", V(2.3, 0.06, 2.3), V(0, 3.62, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		return k.finish(body)
	end

	-- ToolCart 4 x 3.2 x 2.5: STEEL_DARK frame, three shelves (the top HAZARD_YELLOW), four wheels, tools on top.
	function Props.ToolCart(parent, cframe, opts)
		opts = opts or {}
		local rng = BK.rng(opts.seed or 3)
		local k = Props.kit(parent, opts.name or "ToolCart", cframe)
		local frame = with({ Color = P.STEEL_DARK, Material = "Metal" }, soft)
		for _, c in ipairs({ { -1.85, -1.1 }, { 1.85, -1.1 }, { -1.85, 1.1 }, { 1.85, 1.1 } }) do
			k.box("Post", V(0.2, 2.8, 0.2), V(c[1], 1.8, c[2]), frame)
			k.cyl("Wheel", "X", V(0.3, 0.8, 0.8), V(c[1], 0.4, c[2]), with({ Color = P.HAZARD_BLACK }, soft))
		end
		local top = k.box("Top", V(4, 0.2, 2.5), V(0, 3.1, 0), { Color = P.HAZARD_YELLOW, Material = "Metal" })
		for i, y in ipairs({ 2.0, 0.95 }) do
			k.box("Shelf" .. i, V(3.8, 0.15, 2.3), V(0, y, 0), { Color = P.STEEL_MID, Material = "Metal" })
		end
		k.box("Handle", V(0.15, 0.15, 2.0), V(2.2, 3.0, 0), frame)
		for t = 1, rng.int(3, 5) do
			local x, z = rng.next(-1.5, 1.5), rng.next(-0.8, 0.8)
			if t % 2 == 0 then
				-- A wrench: a shaft and a jaw.
				k.part("WrenchShaft", V(1.2, 0.08, 0.14), CFrame.new(x, 3.24, z) * CFrame.Angles(0, rng.next(0, 3), 0), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
				k.box("WrenchJaw", V(0.3, 0.1, 0.3), V(x + 0.6, 3.25, z), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
			else
				k.box("ToolBox", V(rng.next(0.6, 1.2), rng.next(0.3, 0.6), rng.next(0.4, 0.7)), V(x, 3.4, z), with({ Color = rng.pick({ P.DANGER_RED, P.STEEL_MID, P.SLATE }), Material = "Metal" }, soft))
			end
		end
		for i, y in ipairs({ 1.3, 2.35 }) do
			k.box("Bin" .. i, V(1.2, 0.5, 0.9), V(-0.9 + i * 0.6, y, 0.2), with({ Color = P.SLATE }, soft))
		end
		return k.finish(top)
	end

	-- Forklift 4 x 6 x 8: a HAZARD_YELLOW body, a counterweight, a cage over the seat, a mast with two forks at -Z,
	-- four wheels. An ambient mover: the model carries Tag AmbientMover; opts.attributes add its path.
	function Props.Forklift(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Forklift", cframe)
		local yellow = { Color = P.HAZARD_YELLOW, Material = "Metal" }
		local dark = with({ Color = P.STEEL_DARK, Material = "Metal" }, soft)
		local body = k.box("Body", V(3.8, 1.6, 5.2), V(0, 1.5, 0.6), yellow)
		k.box("Counterweight", V(3.8, 1.8, 1.4), V(0, 1.6, 3.4), { Color = P.STEEL_DARK, Material = "Metal" })
		k.box("Seat", V(1.6, 0.4, 1.4), V(0, 2.5, 1.4), with({ Color = P.FABRIC_DARK }, soft))
		k.box("SeatBack", V(1.6, 1.2, 0.3), V(0, 3.1, 2.1), with({ Color = P.FABRIC_DARK }, soft))
		for _, c in ipairs({ { -1.7, -0.8 }, { 1.7, -0.8 }, { -1.7, 2.8 }, { 1.7, 2.8 } }) do
			k.box("CagePost", V(0.2, 3.6, 0.2), V(c[1], 4.1, c[2]), dark)
			k.cyl("Wheel", "X", V(0.6, 1.4, 1.4), V(c[1] * 1.05, 0.7, c[2] * 0.9 - (if c[2] < 0 then 0.6 else 0)), with({ Color = P.HAZARD_BLACK }, soft))
		end
		k.box("CageRoof", V(3.6, 0.2, 3.8), V(0, 5.95, 1.0), with(yellow, soft))
		for _, x in ipairs({ -1.2, 1.2 }) do
			k.box("Mast", V(0.4, 5.6, 0.4), V(x, 2.9, -2.2), dark)
			k.box("Fork", V(0.4, 0.15, 3.2), V(x, 0.3, -3.8), with({ Color = P.STEEL_MID, Material = "Metal" }, soft))
		end
		k.box("Carriage", V(3.0, 1.4, 0.3), V(0, 1.0, -2.45), dark)
		k.box("Beacon", V(0.4, 0.3, 0.4), V(0, 6.2, 1.0), with(Props.glow, soft))
		local model = k.finish(body)
		BK.tag(model, "AmbientMover")
		if opts.attributes then
			BK.attr(model, opts.attributes)
		end
		return model
	end

	-- FloodlightMast 2 x 50 x 2: a lattice mast (four bars, diagonal braces every 6, STEEL_DARK) and two lamp boxes
	-- 3 x 2 x 2 with LIGHT_COOL faces and SpotLights (3 / 60 / 50). opts.height, opts.aim (world point), opts.shadows,
	-- opts.single (one light for both heads, to save the area's light budget), opts.lightTags.
	function Props.FloodlightMast(parent, cframe, opts)
		opts = opts or {}
		local h = opts.height or 50
		local k = Props.kit(parent, opts.name or "FloodlightMast", cframe)
		local dark = { Color = P.STEEL_DARK, Material = "Metal" }
		local base = k.box("Base", V(3, 0.8, 3), V(0, 0.4, 0), { Color = P.CONCRETE_DARK, Material = "Concrete" })
		for _, c in ipairs({ { -0.8, -0.8 }, { 0.8, -0.8 }, { 0.8, 0.8 }, { -0.8, 0.8 } }) do
			k.box("Leg", V(0.25, h - 0.8, 0.25), V(c[1], 0.8 + (h - 0.8) / 2, c[2]), dark)
		end
		local faces = { { V(-0.8, 0, -0.8), V(0.8, 0, -0.8) }, { V(0.8, 0, -0.8), V(0.8, 0, 0.8) }, { V(0.8, 0, 0.8), V(-0.8, 0, 0.8) }, { V(-0.8, 0, 0.8), V(-0.8, 0, -0.8) } }
		local n = 0
		for y = 1, h - 7, 6 do
			for _, f in ipairs(faces) do
				n += 1
				local a, b = f[1] + V(0, y, 0), f[2] + V(0, y + 6, 0)
				if n % 2 == 0 then
					a, b = f[1] + V(0, y + 6, 0), f[2] + V(0, y, 0)
				end
				k.beam("Brace", a, b, 0.12, 0.12, with(dark, soft))
			end
		end
		k.box("Platform", V(4, 0.3, 2.4), V(0, h, 0), dark)
		local aim = opts.aim
		for i, x in ipairs({ -1, 1 }) do
			local head = cframe:PointToWorldSpace(V(x * 1.1, h + 1.4, 0))
			local target = aim or cframe:PointToWorldSpace(V(x * 6, 0, -30))
			local hc = CFrame.lookAt(head, target)
			BK.part(k.model, { Name = "Lamp" .. i, Size = V(3, 2, 2), CFrame = hc * CFrame.new(0, 0, 0.6), Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
			local face = BK.part(k.model, with({ Name = "LampFace" .. i, Size = V(2.6, 1.6, 0.1), CFrame = hc * CFrame.new(0, 0, -0.45), Color = P.LIGHT_COOL, Material = "Neon" }, soft))
			if i == 1 or not opts.single then
				BK.light(face, "Spot", { Color = P.LIGHT_COOL, Brightness = 3, Range = 60, Angle = 50, Face = Enum.NormalId.Front, Shadows = opts.shadows == true and i == 1, Tags = opts.lightTags })
			end
		end
		return k.finish(base)
	end

	-- Jersey barrier 6 x 3 x 2: a base box and two wedges (a wedge profile) in CONCRETE_LIGHT, a hazard band.
	-- A WedgePart is tall at its +Z side, so the front slope stands as is and the back one is turned round (both lean
	-- in toward the top; until 2026-10-17 they were swapped and the barrier was wider at the top).
	function Props.JerseyBarrier(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "JerseyBarrier", cframe)
		local concrete = { Color = P.CONCRETE_LIGHT, Material = "Concrete" }
		local base = k.box("Base", V(6, 1, 2), V(0, 0.5, 0), concrete)
		k.box("Top", V(6, 2, 0.8), V(0, 2, 0), concrete)
		k.wedge("SlopeF", V(6, 2, 0.6), CFrame.new(0, 2, -0.7), concrete)
		k.wedge("SlopeB", V(6, 2, 0.6), CFrame.new(0, 2, 0.7) * CFrame.Angles(0, math.pi, 0), concrete)
		k.box("Band", V(6.02, 0.4, 0.82), V(0, 2.6, 0), with({ Color = P.HAZARD_YELLOW }, soft))
		return k.finish(base)
	end

	-- StreetLamp 1 x 12 x 4: a STEEL_DARK pole, an arm toward -Z, a lamp head; the light (AMBER_LAMP) is off unless
	-- opts.lit; opts.lightTags tag it (e.g. EveningLamp: on at EVENING and NIGHT).
	function Props.StreetLamp(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "StreetLamp", cframe)
		local dark = { Color = P.STEEL_DARK, Material = "Metal" }
		local pole = k.cyl("Pole", "Y", V(0.5, 12, 0.5), V(0, 6, 0), dark)
		k.cyl("Foot", "Y", V(1, 0.6, 1), V(0, 0.3, 0), dark)
		k.box("Arm", V(0.3, 0.3, 3.2), V(0, 11.8, -1.6), with(dark, soft))
		k.box("Head", V(1, 0.5, 1.6), V(0, 11.6, -3.2), with(dark, soft))
		local face = k.box("Face", V(0.8, 0.08, 1.3), V(0, 11.32, -3.2), with({ Color = if opts.lit then P.AMBER_LAMP else P.STEEL_MID, Material = if opts.lit then "Neon" else "SmoothPlastic" }, soft))
		BK.light(face, "Spot", { Color = P.AMBER_LAMP, Brightness = 1.6, Range = 30, Angle = 100, Face = Enum.NormalId.Bottom, Enabled = opts.lit == true, Tags = opts.lightTags })
		BK.attr(face, { OnColor = P.AMBER_LAMP, OffColor = P.STEEL_MID })
		return k.finish(pole)
	end

	-- PowerCabinet (new) 6 x 9 x 3: STEEL_MID with door seams, vents, indicator lights (amber glow, one red) and a
	-- "HIGH VOLTAGE" placard; its cables leave from the base (see CableRun).
	function Props.PowerCabinet(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "PowerCabinet", cframe)
		local body = k.box("Body", V(6, 9, 3), V(0, 4.5, 0), { Color = P.STEEL_MID, Material = "Metal" })
		k.box("Plinth", V(6.2, 0.4, 3.2), V(0, 0.2, 0), with({ Color = P.KICKPLATE }, soft))
		local dark = with({ Color = P.KICKPLATE }, soft)
		k.box("SeamMid", V(0.08, 8.2, 0.05), V(0, 4.6, -1.52), dark)
		for _, x in ipairs({ -2.95, 2.95 }) do
			k.box("SeamSide", V(0.08, 8.2, 0.05), V(x * 0.98, 4.6, -1.52), dark)
		end
		for i = 0, 3 do
			k.box("Vent", V(2.0, 0.12, 0.05), V(-1.6, 7.6 - i * 0.3, -1.52), dark)
			k.box("Vent", V(2.0, 0.12, 0.05), V(1.6, 7.6 - i * 0.3, -1.52), dark)
		end
		for i = 0, 4 do
			local light = if i == 4 then { Color = P.DANGER_RED, Material = "Neon" } else Props.glow
			k.box("Indicator" .. i, V(0.3, 0.3, 0.08), V(-1.8 + i * 0.5, 6.4, -1.54), with(light, soft))
		end
		for _, x in ipairs({ -0.4, 0.4 }) do
			k.box("Handle", V(0.12, 1.2, 0.15), V(x, 4.4, -1.58), with({ Color = P.STEEL_LIGHT, Material = "Metal" }, soft))
		end
		local placard = k.box("Placard", V(2.4, 1.2, 0.05), V(0, 2.4, -1.53), with({ Color = P.HAZARD_YELLOW }, soft))
		local gui = Props.gui(placard, Enum.NormalId.Front, 0.6, 60)
		Props.label(gui, "HIGH VOLTAGE", 0.05, 0.2, 0.9, 0.6, { font = Props.FONT.header, color = P.HAZARD_BLACK, xAlign = "Center" })
		return k.finish(body)
	end

	-- PlateRack (new) 8 x 9 x 4: a steel A-frame base with two uprights and 2-3 armor plates standing in it
	-- (VG_PRIMER, VG_ARMOR), leaning 8°.
	function Props.PlateRack(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "PlateRack", cframe)
		local dark = { Color = P.STEEL_DARK, Material = "Metal" }
		local base = k.box("Base", V(8, 0.6, 4), V(0, 0.3, 0), dark)
		for _, x in ipairs({ -3.6, 3.6 }) do
			k.box("Upright", V(0.5, 7, 0.5), V(x, 3.8, 0.8), dark)
			k.part("Brace", V(0.3, 4.6, 0.3), CFrame.new(x, 2.6, -0.4) * CFrame.Angles(math.rad(-30), 0, 0), with(dark, soft))
		end
		k.box("TopBar", V(7.7, 0.4, 0.4), V(0, 7.1, 0.8), dark)
		local plates = { { -1.6, P.VG_PRIMER }, { 0, P.VG_ARMOR }, { 1.6, P.VG_PRIMER } }
		for i = 1, opts.plates or 2 do
			local p = plates[i]
			k.part("Plate" .. i, V(6.6, 7.4, 0.5), CFrame.new(0, 4.2, p[1] * 0.5) * CFrame.Angles(math.rad(-8), 0, 0), { Color = p[2], Material = "Metal" })
			k.part("PlateRim" .. i, V(6.8, 0.3, 0.6), CFrame.new(0, 7.8, p[1] * 0.5 + 0.5) * CFrame.Angles(math.rad(-8), 0, 0), with({ Color = P.VG_FRAME, Material = "Metal" }, soft))
		end
		return k.finish(base)
	end

	-- MobileStair (new): a rolling stair to a 14-tall platform, HAZARD_YELLOW frame, steps rising toward -Z, railings,
	-- four wheels. Footprint about 6 x 16.
	function Props.MobileStair(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "MobileStair", cframe)
		local yellow = { Color = P.HAZARD_YELLOW, Material = "Metal" }
		local deck = { Color = P.STEEL_MID, Material = "DiamondPlate" }
		local base = k.box("Chassis", V(5, 0.8, 16), V(0, 1.2, 0), yellow)
		for _, c in ipairs({ { -2.4, -7 }, { 2.4, -7 }, { -2.4, 7 }, { 2.4, 7 } }) do
			k.cyl("Wheel", "X", V(0.6, 1.2, 1.2), V(c[1], 0.6, c[2]), with({ Color = P.HAZARD_BLACK }, soft))
		end
		local steps = 12
		for i = 1, steps do
			local y = 1.6 + i * (12.4 / steps)
			local z = 7.2 - i * (10 / steps)
			k.box("Step" .. i, V(4.4, 0.3, 0.9), V(0, y, z), deck)
		end
		k.box("Platform", V(5, 0.4, 4), V(0, 14, -5.8), deck)
		for _, x in ipairs({ -2.4, 2.4 }) do
			k.beam("Stringer", V(x, 1.6, 7.6), V(x, 14, -2.8), 0.3, 0.6, yellow)
			k.box("PlatformLeg", V(0.4, 12.4, 0.4), V(x, 7.8, -7.6), yellow)
			k.beam("Rail", V(x, 5.2, 7.6), V(x, 17.6, -2.8), 0.15, 0.15, with(yellow, soft))
			k.box("PlatformRail", V(0.15, 0.15, 4), V(x, 17.6, -5.8), with(yellow, soft))
		end
		k.box("FrontRail", V(5, 0.15, 0.15), V(0, 17.6, -7.8), with(yellow, soft))
		return k.finish(base)
	end

	-- Bollard (new) 1.2 x 3.5: a HAZARD_YELLOW post with two black bands and a cap.
	function Props.Bollard(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Bollard", cframe)
		local post = k.cyl("Post", "Y", V(1.2, 3.5, 1.2), V(0, 1.75, 0), { Color = P.HAZARD_YELLOW, Material = "Metal" })
		for _, y in ipairs({ 2.2, 2.9 }) do
			k.cyl("Band", "Y", V(1.24, 0.3, 1.24), V(0, y, 0), with({ Color = P.HAZARD_BLACK }, soft))
		end
		k.cyl("Cap", "Y", V(1.0, 0.15, 1.0), V(0, 3.58, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		return k.finish(post)
	end

	-- ExtinguisherStation (new): a red cabinet 1.4 x 2.4 x 0.6 with a glass front and a white label. Wall prop
	-- (cframe = center of its back on the wall).
	function Props.ExtinguisherStation(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "ExtinguisherStation", cframe)
		local box = k.box("Cabinet", V(1.4, 2.4, 0.6), V(0, 0, -0.3), { Color = P.DANGER_RED, Material = "Metal", CanCollide = false })
		k.box("Glass", V(1.1, 1.8, 0.05), V(0, -0.1, -0.62), with({ Color = P.GLASS, Material = "Glass", Transparency = 0.5 }, soft))
		k.cyl("Extinguisher", "Y", V(0.5, 1.4, 0.5), V(0, -0.2, -0.32), with({ Color = P.DANGER_RED, Material = "Metal" }, soft))
		local label = k.box("Label", V(1.2, 0.35, 0.05), V(0, 1.45, -0.32), with({ Color = P.SIGN_WHITE }, soft))
		local gui = Props.gui(label, Enum.NormalId.Front, 0.6, 80)
		Props.label(gui, "FIRE", 0.1, 0.1, 0.8, 0.8, { font = Props.FONT.header, color = P.DANGER_RED, xAlign = "Center" })
		return k.finish(box)
	end

	-- CoolantTank (new) 4 x 10: a standing cylinder #7B848C on a base ring, two bands, a valve and a pipe stub,
	-- a hazard label.
	function Props.CoolantTank(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "CoolantTank", cframe)
		local body = k.cyl("Body", "Y", V(4, 9.2, 4), V(0, 5.2, 0), { Color = "#7B848C", Material = "Metal" })
		k.cyl("Base", "Y", V(4.4, 0.6, 4.4), V(0, 0.3, 0), { Color = P.STEEL_DARK, Material = "Metal" })
		k.ball("Dome", 4, V(0, 9.6, 0), with({ Color = "#7B848C", Material = "Metal" }, { CanCollide = false }))
		for _, y in ipairs({ 3, 7.4 }) do
			k.cyl("Band", "Y", V(4.1, 0.3, 4.1), V(0, y, 0), with({ Color = P.STEEL_DARK, Material = "Metal" }, soft))
		end
		k.cyl("Stub", "Z", V(0.6, 0.6, 1.2), V(0, 1.6, -2.4), with({ Color = P.STEEL_MID, Material = "Metal" }, soft))
		k.cyl("Valve", "Y", V(1.0, 0.15, 1.0), V(0, 2.1, -2.9), with({ Color = P.DANGER_RED, Material = "Metal" }, soft))
		local label = k.box("Label", V(1.8, 1.0, 0.05), CFrame.new(0, 5.4, -2.02).Position, with({ Color = P.HAZARD_YELLOW }, soft))
		local gui = Props.gui(label, Enum.NormalId.Front, 0.6, 60)
		Props.label(gui, "COOLANT", 0.05, 0.25, 0.9, 0.5, { font = Props.FONT.header, color = P.HAZARD_BLACK, xAlign = "Center" })
		return k.finish(body)
	end

	-- FuelTank 8 across x 16 long, lying along local Z: a #7B848C cylinder on two concrete saddles, end caps, two bands,
	-- a ladder up its +X side to a small platform with a filler hatch, a "FUEL — NO FLAME" sign on its front cap.
	function Props.FuelTank(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "FuelTank", cframe)
		local metal = { Color = "#7B848C", Material = "Metal" }
		local dark = with({ Color = P.STEEL_DARK, Material = "Metal" }, soft)
		local body = k.cyl("Body", "Z", V(8, 8, 16), V(0, 5.2, 0), metal)
		for _, z in ipairs({ -8.1, 8.1 }) do
			k.cyl("Cap", "Z", V(7.4, 7.4, 0.3), V(0, 5.2, z), with(metal, { CanCollide = false }))
		end
		for _, z in ipairs({ -4.6, 4.6 }) do
			k.box("Saddle", V(7, 2.2, 1.4), V(0, 1.1, z), { Color = P.CONCRETE_DARK, Material = "Concrete" })
			k.cyl("Band", "Z", V(8.2, 8.2, 0.3), V(0, 5.2, z), dark)
		end
		for _, z in ipairs({ -5.9, -4.9 }) do
			k.box("LadderRail", V(0.15, 8.6, 0.15), V(4.3, 4.6, z), dark)
		end
		for y = 1, 8, 1.2 do
			k.box("Rung", V(0.12, 0.12, 1.0), V(4.3, y, -5.4), dark)
		end
		k.box("Platform", V(2.4, 0.2, 3), V(2.2, 9.25, -5.4), with({ Color = P.STEEL_MID, Material = "DiamondPlate" }, soft))
		k.cyl("Hatch", "Y", V(1.4, 0.3, 1.4), V(0, 9.3, 2), dark)
		k.cyl("Valve", "Z", V(0.8, 0.8, 1.2), V(-2.4, 2.6, -8.6), with({ Color = P.DANGER_RED, Material = "Metal" }, soft))
		local sign = k.box("Sign", V(3.6, 1.6, 0.06), V(0, 5.4, -8.3), with({ Color = P.HAZARD_YELLOW }, soft))
		local gui = Props.gui(sign, Enum.NormalId.Front, 0.6, 50)
		Props.label(gui, "FUEL — NO FLAME", 0.05, 0.2, 0.9, 0.6, { font = Props.FONT.header, color = P.HAZARD_BLACK, xAlign = "Center" })
		return k.finish(body)
	end
end
