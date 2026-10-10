--!nonstrict
-- builders/rigs/Vanguard.lua  ->  ServerStorage.DevTools.Builders.Rigs.Vanguard
-- docs/09_frames.md §2-3 (part-by-part build, unit variants), docs/08_rigs_and_animation.md §2-3.1 (rig rules,
-- joint table).
--
--   Build({ BK = BK, unit = "02" })  -> stats     builds ServerStorage.Templates.Frames.Vanguard_<unit>
--   Builder.MAIN, Builder.JOINTS                  the tables of docs/08 §3.1 (RigCheck reads them)
--
-- Model space: origin on the ground under the HRP, facing -Z, +X = the rig's right. Every detail part is
-- welded to its main part; offsets below are relative to that main part's center, as in docs/09 §2.
-- Main parts use the "core" sizes of docs/09 where it names one (D-035); centers and joints are docs/08's.

local Builder = {}

local V = Vector3.new
local rad = math.rad

Builder.UNITS = {
	["01"] = { accent = "VG_ACCENT_MARA", tally = "41" },
	["02"] = { accent = "VG_ACCENT_ELIAS" },
}

-- name = { size, center }   (docs/08 §3.1; sx = -1 left, +1 right is applied to X)
Builder.MAIN = {
	LowerTorso = { V(12, 4, 8), V(0, 22, 0) },
	UpperTorso = { V(16, 11, 10), V(0, 29.5, 0) },
	Head = { V(5, 5, 5.5), V(0, 37.5, 0) },
	UpperArm = { V(3.5, 10, 3.5), V(10.5, 27, 0) },
	LowerArm = { V(4, 9, 4), V(10.5, 17.5, 0) },
	Hand = { V(4, 3, 3.5), V(10.5, 10.75, 0) },
	UpperLeg = { V(4.5, 8, 4.5), V(3.75, 16, 0) },
	LowerLeg = { V(5, 9, 5.5), V(3.75, 7.5, 0) },
	Foot = { V(6, 3, 10), V(3.75, 1.5, -1.5) },
}
Builder.HRP = { V(10, 10, 6), V(0, 19, 0) }
Builder.HIP_HEIGHT = 14

-- { joint, part0, part1, joint position }; "L/R" entries are expanded for both sides.
Builder.JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", V(0, 22, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", V(0, 24, 0) },
	{ "Neck", "UpperTorso", "Head", V(0, 35, 0) },
	{ "Shoulder", "UpperTorso", "UpperArm", V(10.5, 32, 0), sided = true },
	{ "Elbow", "UpperArm", "LowerArm", V(10.5, 22, 0), sided = true },
	{ "Wrist", "LowerArm", "Hand", V(10.5, 13, 0), sided = true },
	{ "Hip", "LowerTorso", "UpperLeg", V(3.75, 20, 0), sided = true },
	{ "Knee", "UpperLeg", "LowerLeg", V(3.75, 12, 0), sided = true },
	{ "Ankle", "LowerLeg", "Foot", V(3.75, 3, 0), sided = true },
}

local SIDES = { { "Left", -1 }, { "Right", 1 } }

function Builder.Build(opts)
	local BK = opts.BK
	local P = BK.Palette
	local unit = opts.unit or "02"
	local variant = Builder.UNITS[unit] or error("Vanguard builder: unknown unit " .. tostring(unit))
	local startClock = os.clock()
	local accent = P[variant.accent]

	local templates = game:GetService("ServerStorage").Templates.Frames
	local old = templates:FindFirstChild("Vanguard_" .. unit)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Vanguard_" .. unit
	BK.attr(model, { Class = "Vanguard", Unit = unit })

	local main = {}
	-- The CFrame each part was asked for. A cylinder with an Axis is turned by BuildKit, so offsets of things
	-- attached to it are measured from this logical frame, not from the part's own CFrame.
	local frames = {}

	-- A rig part: unanchored, massless, never collides or answers queries (docs/08 §2.3 and §2.5).
	local function raw(kind, parent, name, size, cframe, color, material, extra)
		local props = {
			Name = name, Size = size, CFrame = cframe, Color = color or P.VG_FRAME, Material = material or "Metal",
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
			CastShadow = math.max(size.X, size.Y, size.Z) > 1,
		}
		for key, value in pairs(extra or {}) do
			props[key] = value
		end
		local part = BK[kind](parent, props)
		frames[part] = cframe
		return part
	end

	local function mainPart(name, size, center)
		local part = raw("part", model, name, size, CFrame.new(center), P.VG_FRAME, "Metal")
		main[name] = part
		return part
	end

	-- A detail welded to a main part. at = Vector3 or CFrame relative to the main part's center.
	local function add(on, kind, name, size, at, color, material, extra)
		local offset = if typeof(at) == "Vector3" then CFrame.new(at) else at
		local part = raw(kind, on, name, size, frames[on] * offset, color, material, extra)
		BK.weld(on, part)
		return part
	end

	local function bolts(on, name, positions, color)
		for index, position in ipairs(positions) do
			add(on, "part", name .. index, V(0.4, 0.4, 0.4), position, color or P.STEEL_LIGHT)
		end
	end

	local function stencil(on, name, size, at, text, face, color)
		local plate = add(on, "part", name, V(size.X, size.Y, 0.05), at, P.VG_ARMOR, "Metal", { Transparency = 1 })
		local gui = Instance.new("SurfaceGui")
		gui.Face = face or Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Font.fromEnum(Enum.Font.Michroma)
		label.TextScaled = true
		label.TextColor3 = BK.toColor(color or "#E8ECEF")
		label.Text = text
		label.Parent = gui
		return plate
	end

	local function attachment(on, name, position)
		local new = Instance.new("Attachment")
		new.Name = name
		new.CFrame = on.CFrame:ToObjectSpace(frames[on] * CFrame.new(position))
		new.Parent = on
		return new
	end

	----------------------------------------------------------------------------------------------------------------
	-- Main parts and joints
	----------------------------------------------------------------------------------------------------------------
	local hrp = raw("part", model, "HumanoidRootPart", Builder.HRP[1], CFrame.new(Builder.HRP[2]), P.VG_FRAME, "SmoothPlastic", {
		Transparency = 1, CanCollide = true, Massless = false, CastShadow = false,
	})
	hrp.RootPriority = 127
	hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	main.HumanoidRootPart = hrp
	model.PrimaryPart = hrp

	for name, spec in pairs(Builder.MAIN) do
		if spec[2].X == 0 then
			mainPart(name, spec[1], spec[2])
		else
			for _, side in ipairs(SIDES) do
				mainPart(side[1] .. name, spec[1], V(spec[2].X * side[2], spec[2].Y, spec[2].Z))
			end
		end
	end

	local function joint(name, part0, part1, position)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = CFrame.new(position - part0.Position)
		motor.C1 = CFrame.new(position - part1.Position)
		motor.Parent = part1
		return motor
	end
	for _, entry in ipairs(Builder.JOINTS) do
		if entry.sided then
			for _, side in ipairs(SIDES) do
				local function sided(partName)
					return main[partName] or main[side[1] .. partName]
				end
				joint(side[1] .. entry[1], sided(entry[2]), sided(entry[3]), V(entry[4].X * side[2], entry[4].Y, entry[4].Z))
			end
		else
			joint(entry[1], main[entry[2]], main[entry[3]], entry[4])
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- Legs
	----------------------------------------------------------------------------------------------------------------
	for _, side in ipairs(SIDES) do
		local name, sx = side[1], side[2]

		local foot = main[name .. "Foot"]
		add(foot, "wedge", "ToeArmor", V(6, 2, 3), V(0, 0.5, -3.5), P.VG_ARMOR)
		add(foot, "part", "HeelBlock", V(5, 2.5, 2.5), V(0, 0.25, 3.8), P.VG_ARMOR_DARK)
		for _, x in ipairs({ -3.1, 3.1 }) do
			add(foot, "part", "SidePlate", V(0.5, 2, 7), V(x, 0.3, -0.5), P.VG_ARMOR)
		end
		for _, z in ipairs({ -3.5, -1.5, 0.5, 2.5 }) do
			add(foot, "part", "Tread", V(5.8, 0.3, 1), V(0, -1.4, z), P.KICKPLATE)
		end
		add(foot, "cyl", "AnkleCollar", V(5, 1.5, 5), V(0, 1.8, 1.5), P.STEEL_DARK, nil, { Axis = "Y" })
		add(foot, "cyl", "AchillesPiston", V(0.8, 3, 0.8), V(0, 2.5, 3.2), P.VG_HYDRAULIC, nil, { Axis = "Y" })
		bolts(foot, "Bolt", { V(-2.2, 1.3, -3.2), V(2.2, 1.3, -3.2), V(0, 1.6, -2.6), V(-2, 1.6, 3.8), V(2, 1.6, 3.8), V(0, 0.4, 5.1) })
		attachment(foot, "Dust", V(0, -1.5, -1))

		local shin = main[name .. "LowerLeg"]
		local shinGuard = add(shin, "part", "ShinGuard", V(5.4, 7, 1.2), V(0, 0.5, -2.6), P.VG_ARMOR)
		shinGuard:SetAttribute("Plate", name .. "ShinGuard")
		add(shin, "wedge", "ShinChamfer", V(5.4, 1, 1.2), CFrame.new(0, 4.5, -2.6) * CFrame.Angles(0, math.pi, 0), P.VG_ARMOR)
		if accent then
			add(shin, "part", "AccentStripe", V(0.6, 5, 0.1), V(1.6 * sx, 0.5, -3.25), accent, "SmoothPlastic")
		end
		add(shin, "part", "CalfArmor", V(4.5, 5, 1), V(0, 1, 2.5), P.VG_ARMOR_DARK)
		for _, x in ipairs({ -2.6, 2.6 }) do
			add(shin, "cyl", "SidePiston", V(0.9, 6, 0.9), V(x, 0, 1), P.VG_HYDRAULIC, nil, { Axis = "Y" })
		end
		add(shin, "part", "KneeCap", V(4, 3, 2), V(0, 4.2, -2.4), P.VG_ARMOR)
		add(shin, "wedge", "KneeCapTop", V(4, 1, 2), CFrame.new(0, 6.2, -2.4) * CFrame.Angles(0, math.pi, 0), P.VG_ARMOR)
		add(shin, "wedge", "KneeCapBottom", V(4, 1, 2), CFrame.new(0, 2.2, -2.4) * CFrame.Angles(0, math.pi, math.pi), P.VG_ARMOR)
		for _, y in ipairs({ -1, -1.6, -2.2 }) do
			add(shin, "part", "CalfVent", V(2.4, 0.3, 0.3), V(0, y, 3.05), P.STEEL_DARK)
		end
		bolts(shin, "Bolt", { V(-2.2, 3.4, -3.25), V(2.2, 3.4, -3.25), V(-2.2, -2.4, -3.25), V(2.2, -2.4, -3.25), V(-1.8, 3, 3.05), V(1.8, 3, 3.05) })
		for index, at in ipairs({ V(2.6 * sx, 3, -1), V(2.6 * sx, -3, -1), V(-2.6 * sx, 2.5, -1.2), V(-2.6 * sx, -3.2, 0) }) do
			add(shin, "part", "Greeble" .. index, V(0.4, 1.2, 1.4), at, P.STEEL_DARK)
		end

		local thigh = main[name .. "UpperLeg"]
		add(thigh, "part", "ThighPlate", V(5.6, 6, 1), V(0, 0, -2.6), P.VG_ARMOR)
		add(thigh, "wedge", "ThighChamfer", V(5.6, 1, 1), CFrame.new(0, -3.5, -2.6) * CFrame.Angles(0, math.pi, math.pi), P.VG_ARMOR)
		add(thigh, "part", "OuterPlate", V(1, 6, 5), V(2.9 * sx, 0, 0), P.VG_ARMOR_DARK)
		add(thigh, "cyl", "HipDrum", V(6, 4, 4), V(0, 3.5, 0), P.STEEL_DARK, nil, { Axis = "X" })
		add(thigh, "cyl", "RearPiston", V(1, 6, 1), V(0, 0, 2.6), P.VG_HYDRAULIC, nil, { Axis = "Y" })
		bolts(thigh, "Bolt", { V(-2.3, 2.4, -3.15), V(2.3, 2.4, -3.15), V(-2.3, -2.4, -3.15), V(2.3, -2.4, -3.15), V(3.45 * sx, 2.4, 0), V(3.45 * sx, -2.4, 0) })
		add(thigh, "part", "Greeble1", V(0.5, 2, 1.6), V(-2.4 * sx, 1, 0.5), P.STEEL_DARK)
		add(thigh, "part", "Greeble2", V(0.5, 1.2, 1.2), V(-2.4 * sx, -2, -0.5), P.STEEL_MID)
	end

	----------------------------------------------------------------------------------------------------------------
	-- Pelvis
	----------------------------------------------------------------------------------------------------------------
	local pelvis = main.LowerTorso
	add(pelvis, "part", "Codpiece", V(6, 3.5, 1.2), V(0, -0.2, -4.4), P.VG_ARMOR)
	for _, sx in ipairs({ -1, 1 }) do
		add(pelvis, "wedge", "CodpieceChamfer", V(1.2, 3.5, 1.5), CFrame.new(3.75 * sx, -0.2, -4.4) * CFrame.Angles(0, rad(-90 * sx), 0), P.VG_ARMOR)
		add(pelvis, "part", "SkirtPlate", V(1, 4.5, 6), V(6.4 * sx, -1.5, 0), P.VG_ARMOR)
		add(pelvis, "part", "Greeble", V(1.4, 1, 0.5), V(4.6 * sx, 0.8, -4.2), P.STEEL_DARK)
		add(pelvis, "part", "GreebleBack", V(1.6, 1.2, 0.5), V(3.4 * sx, -1.2, 4.9), P.STEEL_MID)
	end
	add(pelvis, "part", "RearPlate", V(10, 3, 1), V(0, 0, 4.3), P.VG_ARMOR_DARK)
	add(pelvis, "part", "WaistRing", V(10, 1, 7), V(0, 2.2, 0), P.STEEL_DARK)
	bolts(pelvis, "Bolt", {
		V(-2.4, 1, -5.05), V(2.4, 1, -5.05), V(-2.4, -1.4, -5.05), V(2.4, -1.4, -5.05),
		V(-6.95, 0, -2), V(-6.95, 0, 2), V(6.95, 0, -2), V(6.95, 0, 2),
	})

	----------------------------------------------------------------------------------------------------------------
	-- Chest
	----------------------------------------------------------------------------------------------------------------
	local chest = main.UpperTorso
	for _, sx in ipairs({ -1, 1 }) do
		local pec = add(chest, "part", "PecPlate", V(7, 5, 1.5), CFrame.new(4.6 * sx, 2, -5.4) * CFrame.Angles(0, rad(-8 * sx), 0), P.VG_ARMOR)
		pec:SetAttribute("Plate", (if sx < 0 then "Left" else "Right") .. "Pec")
		local vent = add(chest, "part", "CoreVent", V(1.2, 5, 0.3), V(3.9 * sx, -1.2, -5.6), P.AMBER_CORE, "Neon", { Tags = { "CoreLight" } })
		for index, y in ipairs({ 1.4, 0, -1.4 }) do
			add(vent, "part", "Louver" .. index, V(1.4, 0.3, 0.4), V(0, y, -0.1), P.STEEL_DARK)
		end
		local nozzle = add(chest, "cyl", "ThrusterNozzle", V(3, 4, 3), CFrame.new(4 * sx, -3, 6.2) * CFrame.Angles(rad(-20), 0, 0), P.STEEL_DARK, nil, { Axis = "Y" })
		add(nozzle, "cyl", "NozzleCore", V(2, 0.3, 2), V(0, -1.9, 0), P.KICKPLATE, nil, { Axis = "Y" })
		attachment(nozzle, "Thruster", V(0, -2, 0))
		add(chest, "cyl", "CoolantTank", V(2, 7, 2), V(6 * sx, 1, 5.6), P.VG_HYDRAULIC, nil, { Axis = "Y" })
		for index = 1, 3 do
			add(chest, "part", "RadiatorFin", V(0.2, 1.6, 1.2), V((0.6 + 0.9 * (index - 1)) * sx, 4.5, 5.5), P.STEEL_MID)
		end
	end
	local hatch = raw("part", model, "Hatch", V(6, 6, 0.6), chest.CFrame * CFrame.new(0, 1.5, -5.3), P.VG_ARMOR_DARK, "Metal", { CanQuery = true })
	main.Hatch = hatch
	add(hatch, "part", "HatchHandle", V(2, 0.3, 0.3), V(0, -1.6, -0.45), P.HAZARD_YELLOW)
	local hinge = Instance.new("Motor6D")
	hinge.Name = "HatchHinge"
	hinge.Part0 = chest
	hinge.Part1 = hatch
	hinge.C0 = CFrame.new(0, 4.5, -5)
	hinge.C1 = CFrame.new(0, 3, 0.3)
	hinge.Parent = hatch
	add(chest, "part", "HatchFrameTop", V(6.8, 0.4, 0.5), V(0, 4.7, -5.2), P.STEEL_DARK)
	add(chest, "part", "HatchFrameBottom", V(6.8, 0.4, 0.5), V(0, -1.7, -5.2), P.STEEL_DARK)
	add(chest, "part", "HatchFrameL", V(0.4, 6, 0.5), V(-3.2, 1.5, -5.2), P.STEEL_DARK)
	add(chest, "part", "HatchFrameR", V(0.4, 6, 0.5), V(3.2, 1.5, -5.2), P.STEEL_DARK)
	for index, y in ipairs({ -2.2, -3.3, -4.4 }) do
		add(chest, "part", "AbPlate" .. index, V(10, 1.8, 1), V(0, y, -5.2), P.VG_ARMOR_DARK)
	end
	add(chest, "part", "CollarRidge", V(12, 1.5, 3), V(0, 5.2, -3), P.VG_ARMOR)
	add(chest, "cyl", "CoreHousing", V(6, 6, 1.5), V(0, 0.5, 5.6), P.STEEL_DARK, nil, { Axis = "Z" })
	local coreDisc = add(chest, "cyl", "CoreDisc", V(4, 4, 0.4), V(0, 0.5, 6.4), P.AMBER_CORE, "Neon", { Axis = "Z", Tags = { "CoreLight" } })
	BK.light(coreDisc, "Point", { Name = "CoreGlow", Color = P.AMBER_CORE, Brightness = 1.2, Range = 18 })
	local antenna = add(chest, "cyl", "Antenna", V(0.3, 6, 0.3), V(5, 7, 4), P.STEEL_LIGHT, nil, { Axis = "Y" })
	add(antenna, "ball", "AntennaTip", V(0.4, 0.4, 0.4), V(0, 3.2, 0), P.AMBER, "Neon")
	stencil(chest, "UnitNumber", V(4, 3), CFrame.new(8.03, 1, 0) * CFrame.Angles(0, rad(-90), 0), unit)
	if accent then
		add(chest, "part", "AccentStripe", V(4, 0.6, 0.1), V(-5, 4.2, -6.2), accent, "SmoothPlastic")
	end
	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Size = V(2, 1, 2)
	seat.CFrame = chest.CFrame * CFrame.new(0, -0.5, 0)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Massless = true
	seat.Anchored = false
	seat.Parent = model
	BK.weld(chest, seat)
	bolts(chest, "Bolt", {
		V(-7, 4.6, -5.05), V(7, 4.6, -5.05), V(-7, -4.6, -5.05), V(7, -4.6, -5.05), V(-8.05, 4, -3), V(-8.05, 4, 3),
		V(-8.05, -4, -3), V(-8.05, -4, 3), V(8.05, 4, -3), V(8.05, -4, -3), V(8.05, -4, 3), V(-5, 5.55, 2),
		V(5, 5.55, 2), V(0, 5.55, 3.5),
	})
	for index, spec in ipairs({
		{ V(1.6, 1, 0.5), V(-6.5, -2.5, -5.2) }, { V(1.2, 1.6, 0.5), V(6.6, -3, -5.2) }, { V(2.4, 0.8, 0.6), V(-4, 4.4, 5.2) },
		{ V(2, 1.2, 0.6), V(4, 3.8, 5.2) }, { V(0.5, 2, 2), V(-8.2, 0.5, 1.5) }, { V(3, 0.6, 1.4), V(0, 5.8, 0.5) },
	}) do
		add(chest, "part", "Greeble" .. index, spec[1], spec[2], if index % 2 == 0 then P.STEEL_MID else P.STEEL_DARK)
	end

	----------------------------------------------------------------------------------------------------------------
	-- Head
	----------------------------------------------------------------------------------------------------------------
	local head = main.Head
	add(head, "part", "HelmetTop", V(5.4, 1, 6), V(0, 2.6, 0.2), P.VG_ARMOR)
	for _, sx in ipairs({ -1, 1 }) do
		add(head, "part", "HelmetSide", V(0.6, 4, 5), V(2.8 * sx, 0.3, 0.2), P.VG_ARMOR)
		add(head, "cyl", "SensorEar", V(1, 1.2, 1.2), V(3.1 * sx, 0, 0), P.STEEL_DARK, nil, { Axis = "X" })
	end
	add(head, "wedge", "Brow", V(5, 1, 1.5), CFrame.new(0, 1.4, -3) * CFrame.Angles(0, 0, 0), P.VG_ARMOR)
	local visor = add(head, "part", "Visor", V(3.6, 0.8, 0.2), V(0, 0.5, -2.85), P.VG_VISOR, "Neon", { Transparency = 0.2, Tags = { "Visor" } })
	BK.light(visor, "Surface", { Name = "VisorGlow", Color = P.AMBER_CORE, Brightness = 0.6, Range = 10, Face = Enum.NormalId.Front })
	add(head, "part", "ChinGuard", V(4, 1.2, 1), V(0, -1.9, -2.6), P.VG_ARMOR_DARK)
	add(head, "wedge", "HeadFin", V(0.3, 3, 1.5), V(-1.8, 3.6, 0.5), accent or P.VG_PRIMER, "SmoothPlastic")
	add(head, "ball", "CameraLens", V(0.6, 0.6, 0.6), V(1.4, -0.9, -2.9), P.AMBER, "Neon")
	add(head, "cyl", "NeckRing", V(3.6, 1, 3.6), V(0, -2.8, 0), P.STEEL_DARK, nil, { Axis = "Y" })
	bolts(head, "Bolt", { V(-2.2, 3.15, -2), V(2.2, 3.15, -2), V(-2.2, 3.15, 2.4), V(2.2, 3.15, 2.4) })

	----------------------------------------------------------------------------------------------------------------
	-- Arms
	----------------------------------------------------------------------------------------------------------------
	for _, side in ipairs(SIDES) do
		local name, sx = side[1], side[2]

		local upper = main[name .. "UpperArm"]
		add(upper, "part", "SleeveFront", V(4.4, 7, 0.8), V(0, -0.5, -2.1), P.VG_ARMOR)
		add(upper, "part", "SleeveBack", V(4.4, 7, 0.8), V(0, -0.5, 2.1), P.VG_ARMOR_DARK)
		add(upper, "cyl", "BicepPiston", V(0.9, 6, 0.9), V(0, -1, -2.4), P.VG_HYDRAULIC, nil, { Axis = "Y" })
		add(upper, "cyl", "ElbowDrum", V(4.6, 4.2, 4.2), V(0, -5, 0), P.STEEL_DARK, nil, { Axis = "X" })
		-- Pauldron: over the shoulder, pushed outward.
		local shell = add(upper, "part", "Pauldron", V(7.5, 4.5, 9), V(0.5 * sx, 6.5, 0), P.VG_ARMOR)
		add(shell, "wedge", "ChamferFront", V(7.5, 1, 2), CFrame.new(0, 2.75, -3.5) * CFrame.Angles(0, 0, 0), P.VG_ARMOR)
		add(shell, "wedge", "ChamferBack", V(7.5, 1, 2), CFrame.new(0, 2.75, 3.5) * CFrame.Angles(0, math.pi, 0), P.VG_ARMOR)
		add(shell, "part", "PauldronTop", V(7.5, 1, 5), V(0, 2.75, 0), P.VG_ARMOR)
		add(upper, "part", "PauldronLip", V(7.5, 1, 9.4), V(0.5 * sx, 3.8, 0), P.VG_ARMOR_DARK)
		if accent then
			local stripe = add(shell, "part", "AccentStripe", V(1, 0.1, 5), V(1.5 * sx, 3.3, 0), accent, "SmoothPlastic")
			stripe:SetAttribute("Plate", name .. "PauldronStripe")
		end
		stencil(shell, "UnitNumber", V(4, 2.6), CFrame.new(3.78 * sx, 0, 0) * CFrame.Angles(0, rad(-90 * sx), 0), unit)
		if variant.tally and sx < 0 then
			stencil(shell, "Tally", V(1.2, 0.8), CFrame.new(3.78 * sx, -1.6, 3) * CFrame.Angles(0, rad(-90 * sx), 0), variant.tally)
		end
		bolts(shell, "Bolt", { V(3.3 * sx, 1.6, -3.9), V(3.3 * sx, 1.6, 3.9), V(3.3 * sx, -1.6, -3.9), V(3.3 * sx, -1.6, 3.9) })
		add(shell, "part", "MarkerLight", V(0.4, 0.4, 0.4), V(3.8 * sx, 1.7, 0), P.AMBER, "Neon")
		bolts(upper, "Bolt", { V(-1.8, 2.4, -2.55), V(1.8, 2.4, -2.55), V(-1.8, -3.4, -2.55), V(1.8, -3.4, -2.55) })

		local lower = main[name .. "LowerArm"]
		add(lower, "part", "ShellFront", V(5.2, 7, 0.6), V(0, 0.2, -2.3), P.VG_ARMOR)
		add(lower, "part", "ShellBack", V(5.2, 7, 0.6), V(0, 0.2, 2.3), P.VG_ARMOR_DARK)
		local outer = add(lower, "part", "ShellOuter", V(0.6, 7, 5.2), V(2.3 * sx, 0.2, 0), P.VG_ARMOR)
		outer:SetAttribute("Plate", name .. "ForearmSide")
		add(lower, "part", "ShellInner", V(0.6, 7, 5.2), V(-2.3 * sx, 0.2, 0), P.VG_ARMOR_DARK)
		add(lower, "cyl", "WristRing", V(4.6, 1, 4.6), V(0, -4.2, 0), P.STEEL_DARK, nil, { Axis = "Y" })
		add(lower, "wedge", "ElbowGuard", V(4, 2, 1.6), CFrame.new(0, 4.4, 2.6) * CFrame.Angles(0, math.pi, 0), P.VG_ARMOR)
		bolts(lower, "Bolt", { V(-2, 3, -2.65), V(2, 3, -2.65), V(-2, -2.6, -2.65), V(2, -2.6, -2.65) })
		if sx > 0 then
			add(lower, "part", "BladeMount", V(1.5, 3, 1.5), V(-3.1, -2.5, 0), P.STEEL_DARK)
		else
			-- Pile Driver on the outer side of the left forearm.
			local casing = add(lower, "cyl", "PD_Casing", V(3.2, 8, 3.2), V(-4.1, -0.5, 0), P.STEEL_DARK, nil, { Axis = "Y" })
			for index, y in ipairs({ 2.6, 0, -2.6 }) do
				add(casing, "cyl", "PD_Ring" .. index, V(3.4, 0.2, 3.4), V(0, y, 0), P.HAZARD_YELLOW, nil, { Axis = "Y" })
			end
			local spike = raw("cyl", model, "PD_Spike", V(1.4, 7, 1.4), lower.CFrame * CFrame.new(-4.1, -3.5, 0), P.STEEL_LIGHT, "Metal", { Axis = "Y" })
			main.PD_Spike = spike
			local slide = Instance.new("Motor6D")
			slide.Name = "PileDriver"
			slide.Part0 = lower
			slide.Part1 = spike
			slide.C0 = CFrame.new(-4.1, -3.5, 0)
			slide.C1 = spike.CFrame:ToObjectSpace(lower.CFrame * slide.C0) -- only the cylinder's own turn
			slide.Parent = spike
			-- The point: four wedges leaning together under the spike.
			for index = 0, 3 do
				add(spike, "wedge", "PD_Tip" .. index + 1, V(0.7, 1.6, 0.7), CFrame.new(0, -4.3, 0) * CFrame.Angles(0, rad(90 * index), 0) * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, 0, math.pi), P.STEEL_LIGHT)
			end
			for index, z in ipairs({ -1.7, 1.7 }) do
				local nub = add(casing, "part", "PD_Vent" .. index, V(0.6, 0.8, 0.5), V(0, 3.2, z), P.STEEL_MID)
				attachment(nub, "Steam", V(0, 0.4, 0))
			end
		end

		local hand = main[name .. "Hand"]
		for index, x in ipairs({ -1.5, -0.5, 0.5, 1.5 }) do
			add(hand, "part", "Finger" .. index, V(0.9, 2.2, 1.2), CFrame.new(x, -2, -0.9) * CFrame.Angles(rad(70), 0, 0), P.VG_FRAME)
		end
		add(hand, "wedge", "Thumb", V(1, 1.6, 1.4), CFrame.new(-2.3 * sx, -0.6, -0.8) * CFrame.Angles(0, 0, rad(90 * sx)), P.VG_FRAME)
		add(hand, "part", "KnuckleGuard", V(4.2, 1, 1), V(0, -1, -2), P.VG_ARMOR)
		bolts(hand, "Bolt", { V(-1.4, 0.8, -1.8), V(1.4, 0.8, -1.8) })
		if sx > 0 then
			add(hand, "part", "Prompt_Board", V(3, 3, 3), V(0, 0, 0), P.VG_FRAME, "SmoothPlastic", { Transparency = 1, CastShadow = false })
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- Breaker Blade
	----------------------------------------------------------------------------------------------------------------
	local bladeModel = Instance.new("Model")
	bladeModel.Name = "BreakerBlade"
	bladeModel.Parent = model
	local gripC0 = CFrame.new(0, -0.5, -0.5) * CFrame.Angles(rad(-90), 0, 0)
	local grip = raw("part", bladeModel, "Blade_Grip", V(1.5, 6, 1.5), main.RightHand.CFrame * gripC0, P.STEEL_DARK, "Metal")
	main.Blade_Grip = grip
	local bladeGrip = Instance.new("Motor6D")
	bladeGrip.Name = "BladeGrip"
	bladeGrip.Part0 = main.RightHand
	bladeGrip.Part1 = grip
	bladeGrip.C0 = gripC0
	bladeGrip.C1 = CFrame.new()
	bladeGrip.Parent = grip
	for index, y in ipairs({ -1.6, 0, 1.6 }) do
		add(grip, "cyl", "Wrap" .. index, V(1.7, 0.4, 1.7), V(0, y, 0), P.KICKPLATE, nil, { Axis = "Y" })
	end
	add(grip, "part", "Pommel", V(2, 1.2, 2), V(0, -3.6, 0), P.STEEL_MID)
	add(grip, "part", "Guard", V(6, 1.5, 3), V(0, 3.75, 0), P.VG_ARMOR)
	-- The blade starts on the guard (D-035): 28 long, so its center is 18.5 from the grip's center.
	local blade = add(grip, "part", "BladeBody", V(2, 28, 7), V(0, 18.5, 0), P.STEEL_MID)
	add(grip, "part", "CuttingEdge", V(0.4, 28, 1.2), V(0, 18.5, -4), P.STEEL_LIGHT, "Metal", { Reflectance = 0.1 })
	add(grip, "part", "SpineRidge", V(2.4, 26, 1), V(0, 17.5, 3.6), P.VG_FRAME)
	add(grip, "wedge", "CleaverTip", V(2, 4, 7), V(0, 34.5, 0), P.STEEL_MID)
	add(grip, "part", "HazardBand1", V(2.1, 1, 7.1), V(0, 6, 0), P.HAZARD_YELLOW, "SmoothPlastic")
	add(grip, "part", "HazardBand2", V(2.1, 1, 7.1), V(0, 7.2, 0), P.HAZARD_BLACK, "SmoothPlastic")
	add(grip, "part", "HazardBand3", V(2.1, 1, 7.1), V(0, 8.4, 0), P.HAZARD_YELLOW, "SmoothPlastic")
	stencil(grip, "Serial", V(6, 2.4), CFrame.new(1.03, 14, 0) * CFrame.Angles(0, rad(-90), rad(90)), "BRK-7", nil, "#9AA1A6")
	bolts(grip, "BladeBolt", { V(1.05, 10.5, 2.4), V(1.05, 18, 2.4), V(1.05, 25.5, 2.4), V(-1.05, 10.5, 2.4), V(-1.05, 18, 2.4), V(-1.05, 25.5, 2.4) })
	attachment(blade, "TrailBase", V(0, -12.5, -3.5))
	attachment(blade, "TrailTip", V(0, 16, -3.5))

	----------------------------------------------------------------------------------------------------------------
	-- Humanoid and facing control (docs/08 §2.6, §2.1)
	----------------------------------------------------------------------------------------------------------------
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = Builder.HIP_HEIGHT
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxSlopeAngle = 50
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = true
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local alignAttachment = attachment(hrp, "FacingAttachment", V(0, 0, 0))
	local align = Instance.new("AlignOrientation")
	align.Name = "Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = alignAttachment
	align.RigidityEnabled = false
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.MaxAngularVelocity = rad(150)
	align.PrimaryAxisOnly = false
	align.CFrame = CFrame.new()
	align.Enabled = false
	align.Parent = hrp

	model.Parent = templates
	return BK.report(model, startClock)
end

return Builder
