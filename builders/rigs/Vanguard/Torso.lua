--!nonstrict
-- builders/rigs/Vanguard/Torso.lua  ->  ...Builders.Rigs.Vanguard.Torso     (docs/09 §2: pelvis, chest, head)
-- Offsets are relative to each main part's center; the main parts themselves are invisible bones.

local V = Vector3.new
local rad = math.rad

return function(ctx)
	local K, P, BK, main, model, accent, unit = ctx.K, ctx.P, ctx.BK, ctx.main, ctx.model, ctx.accent, ctx.unit

	------------------------------------------------------------------------------------------------------------------
	-- Pelvis: y -2 (hips) .. 2 (waist)
	------------------------------------------------------------------------------------------------------------------
	local pelvis = main.LowerTorso
	local hipBarrel = K.axisX(V(0, -0.2, 0))
	K.tube(pelvis, "PelvisCore", V(-4.8, -0.2, 0), V(4.8, -0.2, 0), 5.4, P.VG_FRAME)
	K.tube(pelvis, "HipAxle", V(-5.8, -2, 0), V(5.8, -2, 0), 3.2, P.STEEL_DARK)
	K.shell(pelvis, "Codpiece", hipBarrel, -50, 75, 4, 3, 3, 5, 0.7, P.VG_ARMOR)
	K.arc(pelvis, "CodpieceRidge", hipBarrel, -45, 70, 4, 3.8, 0, 0.7, P.VG_ARMOR)
	for _, along in ipairs({ -2.5, 2.5 }) do
		K.arc(pelvis, "CodpieceRim", hipBarrel, -50, 75, 4, 3.35, along, 0.55, P.VG_ARMOR_DARK)
	end
	K.shell(pelvis, "RearPlate", hipBarrel, 125, 235, 3, 3, 3, 8.4, 0.7, P.VG_ARMOR_DARK)
	K.ring(pelvis, "WaistRing", V(0, 1.9, 0), "Y", 8.6, 0.7, P.STEEL_DARK)
	K.ring(pelvis, "WaistSeal", V(0, 2.45, 0), "Y", 7.6, 0.5, P.KICKPLATE)
	for _, sx in ipairs({ -1, 1 }) do
		K.slab(pelvis, "SkirtPlate", V(5.6, 4.8, 0.7), CFrame.new(6.3 * sx, -1.3, 0) * CFrame.Angles(0, rad(90), 0), P.VG_ARMOR)
		K.slab(pelvis, "HipGuard", V(2.6, 2.6, 0.6), CFrame.new(4.5 * sx, 0, -3.3) * CFrame.Angles(0, rad(-20 * sx), 0), P.VG_ARMOR_DARK)
		K.hose(pelvis, "HipLine", { V(2.4 * sx, 1.6, 2.6), V(5.8 * sx, 2.5, 3.6), V(5.6 * sx, 1.2, 0.6) }, 0.4, P.HAZARD_BLACK, 6)
		K.rivets(pelvis, "Bolt", {
			{ V(6.68 * sx, 0, -2), V(sx, 0, 0) }, { V(6.68 * sx, 0, 2), V(sx, 0, 0) }, { V(6.68 * sx, -2.6, -2), V(sx, 0, 0) }, { V(6.68 * sx, -2.6, 2), V(sx, 0, 0) },
		})
	end

	------------------------------------------------------------------------------------------------------------------
	-- Chest: y -5.5 (waist) .. 5.5 (neck); shoulders at (+-10.5, 2.5, 0). A barrel lying across the shoulders,
	-- armored with curved plates, on a ribbed waist.
	------------------------------------------------------------------------------------------------------------------
	local chest = main.UpperTorso
	local barrel = K.axisX(V(0, 0.8, 0))
	K.ring(chest, "Bellows1", V(0, -5.1, 0), "Y", 7.2, 0.6, P.STEEL_DARK)
	K.ring(chest, "Bellows2", V(0, -4.5, 0), "Y", 7.9, 0.6, P.KICKPLATE)
	K.ring(chest, "Bellows3", V(0, -3.9, 0), "Y", 7.2, 0.6, P.STEEL_DARK)
	K.tube(chest, "Barrel", V(-7, 0.8, 0), V(7, 0.8, 0), 9.6, P.VG_FRAME)
	K.ring(chest, "CollarRidge", V(0, 5.5, 0), "Y", 6, 0.9, P.VG_ARMOR)
	K.ring(chest, "NeckSeal", V(0, 6.1, 0), "Y", 4.2, 0.6, P.KICKPLATE)

	for _, sx in ipairs({ -1, 1 }) do
		local sideName = if sx < 0 then "Left" else "Right"
		K.ring(chest, "ShoulderSocket", V(7.3 * sx, 1.6, 0), "X", 7, 0.6, P.STEEL_DARK)

		-- Pec armor: curved plates from the top of the chest round to the front, rimmed on both ends.
		local pecAxis = K.axisX(V(5.4 * sx, 0.8, 0))
		local pec = K.shell(chest, "PecStave", pecAxis, -80, 40, 5, 4.8, 4.8, 5, 0.8, P.VG_ARMOR)
		pec[4].Name = "PecPlate"
		pec[4]:SetAttribute("Plate", sideName .. "Pec")
		for _, along in ipairs({ -2.5, 2.5 }) do
			K.arc(chest, "PecRim", pecAxis, -80, 40, 5, 5.2, along, 0.6, P.VG_ARMOR_DARK)
		end
		K.arc(chest, "PecRidge", pecAxis, -74, 34, 5, 5.7, 0, 0.5, P.VG_ARMOR)

		-- Core vent in the flank under the pec.
		K.box(chest, "VentHousing", V(2, 4.2, 0.8), K.around(pecAxis, 60, 4.5), P.STEEL_DARK)
		local vent = K.box(chest, "CoreVent", V(1.3, 3.4, 0.3), K.around(pecAxis, 60, 4.95), P.AMBER_CORE, "Neon", { Tags = { "CoreLight" } })
		for index, y in ipairs({ 1.1, 0, -1.1 }) do
			K.capsule(vent, "Louver" .. index, V(-0.75, y, -0.2), V(0.75, y, -0.2), 0.34, P.STEEL_DARK)
		end

		-- Cable bundle under the flank, between the pec and the back plates.
		for index, along in ipairs({ 6.5, 5.95, 5.4 }) do
			K.arc(chest, "FlankCable", barrel, 47, 115, 6, 4.95, along * sx, if index == 2 then 0.34 else 0.46, if index == 2 then P.STEEL_MID else P.HAZARD_BLACK, "SmoothPlastic")
		end
		K.box(chest, "CableClamp", V(0.9, 1.9, 0.5), K.around(barrel, 84, 5.05, 5.95 * sx), P.STEEL_MID)

		-- Back: thruster and coolant tank.
		local nozzle = K.add(chest, "cyl", "ThrusterNozzle", V(3, 4, 3), CFrame.new(4 * sx, -3, 6.2) * CFrame.Angles(rad(-20), 0, 0), P.STEEL_DARK, nil, { Axis = "Y" })
		K.add(nozzle, "cyl", "NozzleBell", V(3.5, 0.6, 3.5), V(0, -1.75, 0), P.STEEL_MID, nil, { Axis = "Y" })
		K.add(nozzle, "cyl", "NozzleBand", V(3.3, 0.4, 3.3), V(0, 0.6, 0), P.STEEL_MID, nil, { Axis = "Y" })
		K.add(nozzle, "cyl", "NozzleCore", V(2.2, 0.3, 2.2), V(0, -1.95, 0), P.KICKPLATE, nil, { Axis = "Y" })
		K.attachment(nozzle, "Thruster", V(0, -2, 0))
		K.capsule(chest, "CoolantTank", V(5.3 * sx, 0.2, 6.2), V(5.3 * sx, 4, 6.2), 1.8, P.VG_HYDRAULIC)
		for _, y in ipairs({ 1, 3.2 }) do
			K.ring(chest, "TankStrap", V(5.3 * sx, y, 6.2), "Y", 2.1, 0.4, P.STEEL_DARK)
			K.box(chest, "TankBracket", V(1, 0.5, 2), V(5.3 * sx, y, 5.2), P.STEEL_DARK)
		end
		K.hose(chest, "CoolantLine", { V(5.3 * sx, 4.9, 6.2), V(4.6 * sx, 6.6, 4.6), V(2.6 * sx, 5.3, 3.4) }, 0.45, P.HAZARD_BLACK, 6)
		for index = 1, 3 do
			K.box(chest, "RadiatorFin", V(0.2, 1.6, 1.4), V((0.6 + 0.9 * (index - 1)) * sx, 6, 2.5), P.STEEL_MID)
		end
	end

	-- Belly plates under the hatch.
	K.shell(chest, "AbPlate", barrel, 44, 88, 2, 4.6, 4.6, 6, 0.7, P.VG_ARMOR_DARK)

	-- Cockpit hatch (separate part on its hinge): a raised, round-edged panel in a rolled frame.
	local hatch = K.raw("part", model, "Hatch", V(6, 6, 0.6), chest.CFrame * CFrame.new(0, 1.5, -5.3), P.VG_ARMOR_DARK, "Metal", { CanQuery = true })
	main.Hatch = hatch
	K.slab(hatch, "HatchPanel", V(4.4, 4.4, 0.5), V(0, 0, -0.4), P.VG_ARMOR)
	K.capsule(hatch, "HatchRidge", V(0, -1.9, -0.7), V(0, 0.6, -0.7), 0.45, P.VG_ARMOR_DARK)
	K.box(hatch, "HatchPort", V(2.6, 0.45, 0.2), V(0, 1.4, -0.68), P.KICKPLATE, "Glass")
	K.capsule(hatch, "HatchHandle", V(-1, -2.6, -0.5), V(1, -2.6, -0.5), 0.36, P.HAZARD_YELLOW)
	K.rivets(hatch, "Bolt", {
		{ V(-2.65, 2.65, -0.3), V(0, 0, -1) }, { V(2.65, 2.65, -0.3), V(0, 0, -1) }, { V(-2.65, -2.65, -0.3), V(0, 0, -1) }, { V(2.65, -2.65, -0.3), V(0, 0, -1) },
	})
	local hinge = Instance.new("Motor6D")
	hinge.Name = "HatchHinge"
	hinge.Part0 = chest
	hinge.Part1 = hatch
	hinge.C0 = CFrame.new(0, 4.5, -5)
	hinge.C1 = CFrame.new(0, 3, 0.3)
	hinge.Parent = hatch
	K.capsule(chest, "HatchFrameTop", V(-3.3, 4.7, -5.1), V(3.3, 4.7, -5.1), 0.6, P.STEEL_DARK)
	K.capsule(chest, "HatchFrameBottom", V(-3.3, -1.7, -5.1), V(3.3, -1.7, -5.1), 0.6, P.STEEL_DARK)
	K.tube(chest, "HatchFrameL", V(-3.3, -1.7, -5.1), V(-3.3, 4.7, -5.1), 0.6, P.STEEL_DARK)
	K.tube(chest, "HatchFrameR", V(3.3, -1.7, -5.1), V(3.3, 4.7, -5.1), 0.6, P.STEEL_DARK)
	K.box(chest, "HatchWell", V(6.4, 6.2, 1.2), V(0, 1.5, -4.5), P.STEEL_DARK)
	for _, x in ipairs({ -2, 2 }) do
		K.tube(chest, "HatchKnuckle", V(x - 0.6, 4.7, -5.1), V(x + 0.6, 4.7, -5.1), 1, P.STEEL_MID)
	end

	-- Back: curved plates, the core housing, a few vertebrae under it.
	K.shell(chest, "BackShell", barrel, 118, 250, 6, 4.8, 4.8, 12.4, 0.7, P.VG_ARMOR_DARK)
	for _, along in ipairs({ -6.2, 6.2 }) do
		K.arc(chest, "BackRim", barrel, 118, 250, 6, 5.15, along, 0.55, P.STEEL_DARK)
	end
	K.ring(chest, "CoreFlange", V(0, 0.5, 5.55), "Z", 7.2, 0.4, P.STEEL_MID)
	K.ring(chest, "CoreHousing", V(0, 0.5, 5.9), "Z", 6, 1.5, P.STEEL_DARK)
	local coreDisc = K.ring(chest, "CoreDisc", V(0, 0.5, 6.7), "Z", 4, 0.4, P.AMBER_CORE, "Neon", { Tags = { "CoreLight" } })
	BK.light(coreDisc, "Point", { Name = "CoreGlow", Color = P.AMBER_CORE, Brightness = 1.2, Range = 18 })
	for index = 0, 2 do
		local spoke = CFrame.Angles(0, 0, rad(60 * index))
		K.capsule(chest, "CoreGuard", spoke * V(-2.6, 0, 0) + V(0, 0.5, 6.95), spoke * V(2.6, 0, 0) + V(0, 0.5, 6.95), 0.3, P.STEEL_DARK)
	end
	local flangeBolts = {}
	for index = 0, 7 do
		local angle = rad(45 * index + 22.5)
		table.insert(flangeBolts, { V(math.cos(angle) * 3.3, 0.5 + math.sin(angle) * 3.3, 5.8), V(0, 0, 1) })
	end
	K.rivets(chest, "FlangeBolt", flangeBolts)
	for index = 1, 3 do
		K.ball(chest, "Vertebra" .. index, 1.3, K.around(barrel, 127 - 11 * index, 5).Position, P.STEEL_MID)
	end

	K.tube(chest, "Antenna", V(5, 5, 3), V(5, 10.6, 3), 0.3, P.STEEL_LIGHT)
	K.ring(chest, "AntennaBase", V(5, 5.2, 3), "Y", 0.9, 1, P.STEEL_DARK)
	K.ball(chest, "AntennaTip", 0.45, V(5, 10.7, 3), P.AMBER, "Neon")
	K.tube(chest, "Whip", V(-5.2, 5, 3.2), V(-5.6, 8.4, 3.6), 0.2, P.STEEL_LIGHT)

	K.stencil(chest, "UnitNumber", V(4, 2.4), CFrame.new(7.05, -2.3, 0) * CFrame.Angles(0, rad(-90), 0), unit)
	if accent then
		K.box(chest, "AccentStripe", V(0.6, 4, 0.1), K.around(K.axisX(V(-5.4, 0.8, 0)), -44, 5.64), accent, "SmoothPlastic")
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

	------------------------------------------------------------------------------------------------------------------
	-- Head: y -2.5 (neck) .. 2.5
	------------------------------------------------------------------------------------------------------------------
	local head = main.Head
	K.ring(head, "NeckRing", V(0, -2.6, 0), "Y", 3.6, 1, P.STEEL_DARK)
	K.ring(head, "NeckCollar", V(0, -1.95, 0), "Y", 3, 0.5, P.KICKPLATE)
	K.tube(head, "Skull", V(0, -1.8, 0.2), V(0, 1.4, 0.2), 5, P.VG_FRAME)
	K.egg(head, "HelmetTop", V(5.5, 3.2, 5.9), V(0, 1.25, 0.3), P.VG_ARMOR)
	K.ridge(head, "HelmetCrest", V(0, 1.25, 0.3), V(2.75, 1.6, 2.95), "YZ", 25, 165, 7, 0.5, P.VG_ARMOR_DARK)
	K.hose(head, "Brow", { V(-2.7, 1, -1), V(0, 1.3, -4.3), V(2.7, 1, -1) }, 0.9, P.VG_ARMOR, 6, "Metal", { caps = true })
	K.hose(head, "ChinGuard", { V(-2.4, -1.5, -0.9), V(0, -2.1, -4.3), V(2.4, -1.5, -0.9) }, 1.1, P.VG_ARMOR_DARK, 6, "Metal", { caps = true })
	-- The visor wraps around the face in three panes.
	local visor = K.box(head, "Visor", V(2.2, 0.8, 0.25), V(0, 0.2, -2.42), P.VG_VISOR, "Neon", { Transparency = 0.2, Tags = { "Visor" } })
	BK.light(visor, "Surface", { Name = "VisorGlow", Color = P.AMBER_CORE, Brightness = 0.6, Range = 10, Face = Enum.NormalId.Front })
	for _, sx in ipairs({ -1, 1 }) do
		K.box(head, "VisorSide", V(1.1, 0.8, 0.25), CFrame.new(1.5 * sx, 0.2, -2.18) * CFrame.Angles(0, rad(-28 * sx), 0), P.VG_VISOR, "Neon", { Transparency = 0.2, Tags = { "Visor" } })
		K.slab(head, "HelmetSide", V(3.4, 2.6, 0.5), CFrame.new(2.6 * sx, -0.5, 0.5) * CFrame.Angles(0, rad(90), 0), P.VG_ARMOR_DARK)
		K.ring(head, "SensorEar", V(3.05 * sx, -0.4, 0.5), "X", 1.4, 0.6, P.STEEL_DARK)
		K.ring(head, "SensorLens", V(3.4 * sx, -0.4, 0.5), "X", 0.8, 0.2, P.STEEL_LIGHT)
	end
	K.add(head, "wedge", "HeadFin", V(0.3, 3, 1.5), V(-1.8, 3.3, 0.5), accent or P.VG_PRIMER, "SmoothPlastic")
	K.ball(head, "CameraLens", 0.6, V(1.3, -0.9, -2.4), P.AMBER, "Neon")
	K.ring(head, "CameraMount", V(1.3, -0.9, -2.2), "Z", 0.9, 0.4, P.STEEL_DARK)
	K.tube(head, "SensorMast", V(3.2, 0, 1.2), V(3.4, 3.4, 1.6), 0.2, P.STEEL_LIGHT)

	-- Neck lines bend with the head.
	for _, sx in ipairs({ -1, 1 }) do
		K.cable("NeckCable" .. (if sx < 0 then "L" else "R"), chest, V(1.5 * sx, 5.6, 2.4), V(0, 1, 0.5), head, V(1.1 * sx, -1.4, 2.4), V(0, 1, -0.6), 0.4, 1.4)
	end
end
