--!nonstrict
-- Props/Vehicles: Truck and APC (docs/07 §6), parked at the hub's motor pool. cframe = the bottom-center on the ground,
-- the vehicle's front toward -Z. Both are military olive #4F5A45 (the recipe's own hex) with a white unit number.

local V = Vector3.new

local OLIVE = "#4F5A45"

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

	-- The white unit number on a side face. x, y, w, h are scale units on the Left face, where x runs front -> back;
	-- the Right face's x runs back -> front, so the box is mirrored there.
	local function number(part, face, text, x, y, w, h)
		local gui = Props.gui(part, face, 0.6, 30)
		gui.Name = "Number_" .. face.Name
		if face == Enum.NormalId.Right then
			x = 1 - x - w
		end
		Props.label(gui, text, x, y, w, h, { font = Props.FONT.header, color = P.SIGN_WHITE, xAlign = "Center" })
	end

	-- Truck 8 x 7 x 20: a cab-over cab, a flatbed with stake sides, 6 wheels (3 across), dark windows, headlights.
	-- opts.unit (the door number), opts.load = false leaves the two crates off the bed.
	function Props.Truck(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "Truck", cframe)
		local olive = { Color = OLIVE, Material = "Metal" }
		local dark = { Color = P.STEEL_DARK, Material = "Metal" }
		local glass = with(soft, { Color = P.KICKPLATE, Material = "Glass" })
		local chassis = k.box("Chassis", V(3.2, 1.0, 19), V(0, 2.0, 0.3), dark)
		local cab = k.box("Cab", V(8, 4.6, 5.6), V(0, 4.5, -7.2), olive)
		k.box("CabRoof", V(7.6, 0.4, 5.2), V(0, 7.0, -7.2), olive)
		k.box("Bumper", V(8.2, 0.8, 0.6), V(0, 1.9, -10.1), with(dark, soft))
		k.box("Grille", V(4.4, 1.4, 0.1), V(0, 3.1, -10.03), with(dark, soft))
		k.box("Windshield", V(7, 1.9, 0.1), V(0, 5.4, -10.04), glass)
		for _, x in ipairs({ -1, 1 }) do
			k.box("SideWindow", V(0.1, 1.6, 2.4), V(x * 4.03, 5.5, -7.8), glass)
			k.box("DoorSeam", V(0.1, 3.6, 0.1), V(x * 4.03, 4.3, -5.9), with(soft, { Color = P.HAZARD_BLACK }))
			k.box("Headlight", V(1.0, 0.7, 0.1), V(x * 2.9, 3.0, -10.05), with(soft, { Color = P.MEDICAL_WHITE }))
			k.box("Mirror", V(0.3, 1.0, 0.5), V(x * 4.4, 5.6, -9.4), with(soft, dark))
			k.box("Step", V(0.6, 0.2, 1.4), V(x * 4.1, 2.6, -7.6), with(soft, dark))
		end
		-- The door number on the lower door panel (the cab side is 5.6 deep from z -10, 4.6 tall from y 6.8 down): world
		-- y 3.05..4.6, z -9.4..-6.0, clear of the SideWindow, the DoorSeam, the wheel top and the step.
		number(cab, Enum.NormalId.Left, opts.unit or "3F-21", 0.6 / 5.6, 2.2 / 4.6, 3.4 / 5.6, 1.55 / 4.6)
		number(cab, Enum.NormalId.Right, opts.unit or "3F-21", 0.6 / 5.6, 2.2 / 4.6, 3.4 / 5.6, 1.55 / 4.6)
		-- The bed: a deck, stake sides and a headboard.
		local deck = k.box("Deck", V(8, 0.5, 13.6), V(0, 2.75, 3.0), with(olive, { Material = "WoodPlanks", Color = P.WOOD_OLD }))
		for _, x in ipairs({ -3.9, 3.9 }) do
			k.box("SideBoard", V(0.2, 1.2, 13.6), V(x, 3.6, 3.0), olive)
			for z = -3, 9, 4 do
				k.box("Stake", V(0.25, 2.2, 0.25), V(x, 4.1, z), with(soft, dark))
			end
		end
		k.box("TailBoard", V(8, 1.2, 0.2), V(0, 3.6, 9.7), olive)
		k.box("HeadBoard", V(8, 2.8, 0.3), V(0, 4.4, -3.7), olive)
		k.box("TailLights", V(7.6, 0.3, 0.1), V(0, 2.2, 9.86), with(soft, { Color = P.DANGER_RED }))
		for _, wz in ipairs({ -7.2, 4.0, 7.4 }) do
			for _, x in ipairs({ -1, 1 }) do
				k.cyl("Wheel", "X", V(0.9, 3, 3), V(x * 3.55, 1.5, wz), with(soft, { Color = P.HAZARD_BLACK, Material = "Rubber" }))
				k.cyl("Hub", "X", V(0.1, 1.2, 1.2), V(x * 4.03, 1.5, wz), with(soft, dark))
			end
		end
		if opts.load ~= false then
			Props.Crate(k.model, cframe * CFrame.new(-1.6, 3.0, 1.0) * CFrame.Angles(0, math.rad(4), 0), { name = "Load1", size = "M", stencil = "UDD" })
			Props.Crate(k.model, cframe * CFrame.new(1.8, 3.0, 5.2), { name = "Load2", size = "S", stencil = "HALDEN" })
		end
		return k.finish(deck)
	end

	-- APC 10 x 8 x 18: a hull of a lower box and an upper box with wedge glacis plates sloping to the front, 8 wheels,
	-- a turret box with a barrel, hatches, vision blocks and a short antenna (nothing above y 8), headlights under the
	-- upper glacis's overhang, the white unit number on both sides between the wheel tops and the skirt. opts.unit.
	function Props.APC(parent, cframe, opts)
		opts = opts or {}
		local k = Props.kit(parent, opts.name or "APC", cframe)
		local olive = { Color = OLIVE, Material = "Metal" }
		local dark = { Color = P.STEEL_DARK, Material = "Metal" }
		-- A wedge is tall at its +Z side, so unturned its slope faces the front (-Z) and up.
		local hull = k.box("HullLower", V(9.4, 3.4, 15), V(0, 3.3, 1.5), olive)
		k.wedge("GlacisLower", V(9.4, 3.4, 2.8), CFrame.new(0, 3.3, -7.4), olive)
		k.box("HullUpper", V(8.8, 1.4, 12.4), V(0, 5.7, 2.8), olive)
		k.wedge("GlacisUpper", V(8.8, 1.4, 3.4), CFrame.new(0, 5.7, -5.1), olive)
		for _, x in ipairs({ -1, 1 }) do
			k.box("Skirt", V(0.3, 1.0, 16), V(x * 4.75, 4.6, 0.6), with(soft, olive))
			for _, wz in ipairs({ -5.4, -1.4, 2.6, 6.6 }) do
				k.cyl("Wheel", "X", V(1.1, 3, 3), V(x * 4.3, 1.5, wz), with(soft, { Color = P.HAZARD_BLACK, Material = "Rubber" }))
				k.cyl("Hub", "X", V(0.1, 1.1, 1.1), V(x * 4.88, 1.5, wz), with(soft, dark))
			end
			k.box("VisionBlock", V(0.1, 0.5, 1.2), V(x * 4.42, 5.9, -1.5), with(soft, { Color = P.KICKPLATE, Material = "Glass" }))
			-- In front of the lower slope (y 4.0..4.3 here), under GlacisUpper's underside (y 5.0).
			k.box("Headlight", V(0.9, 0.5, 0.2), V(x * 3.3, 4.6, -6.7), with(soft, { Color = P.MEDICAL_WHITE }))
			k.box("Tow", V(0.4, 0.4, 0.8), V(x * 2.4, 2.0, -8.9), with(soft, dark))
		end
		-- HullLower's side is y 1.6..5.0: the number sits at y 3.1..4.1, between the wheel tops (3.0) and the skirt (4.1).
		number(hull, Enum.NormalId.Left, opts.unit or "3F-07", 0.1, 0.27, 0.8, 0.29)
		number(hull, Enum.NormalId.Right, opts.unit or "3F-07", 0.1, 0.27, 0.8, 0.29)
		-- The turret's top is 7.95 and the hatch stands 0.05 proud of it, so the APC's top is 8.0 (the catalog height).
		local turret = k.box("Turret", V(3.8, 1.6, 4.2), V(0, 7.15, 1.6), olive)
		k.cyl("Barrel", "Z", V(0.4, 0.4, 5), V(0, 7.25, -2.9), with(soft, dark))
		k.cyl("Mantlet", "Z", V(0.9, 0.9, 0.6), V(0, 7.25, -0.6), with(soft, dark))
		k.cyl("Hatch", "Y", V(1.6, 0.2, 1.6), V(0, 7.9, 2.4), with(soft, dark))
		k.box("RearHatch", V(3.2, 0.15, 2.6), V(0, 6.45, 6.6), with(soft, dark))
		k.box("RearDoor", V(3.6, 4.2, 0.1), V(0, 3.9, 9.05), with(soft, { Color = BK.darken(BK.hex(OLIVE), 0.12), Material = "Metal" }))
		k.box("Antenna", V(0.1, 1.6, 0.1), V(-3.6, 7.2, 7.2), with(soft, dark))
		BK.bolts(turret, Enum.NormalId.Front, Vector2.new(4, 2), { parent = k.model, name = "TurretBolts" })
		return k.finish(hull)
	end
end
