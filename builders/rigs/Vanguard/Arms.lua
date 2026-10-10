--!nonstrict
-- builders/rigs/Vanguard/Arms.lua  ->  ...Builders.Rigs.Vanguard.Arms
-- docs/09 §2: upper arms and pauldrons, lower arms, Pile Driver, hands, Breaker Blade.
-- Offsets are relative to each main part's center; the main parts themselves are invisible bones.

local V = Vector3.new
local rad = math.rad

return function(ctx)
	local K, P, main, model, accent, unit, variant = ctx.K, ctx.P, ctx.main, ctx.model, ctx.accent, ctx.unit, ctx.variant

	for _, side in ipairs(ctx.SIDES) do
		local name, sx = side[1], side[2]

		-- Upper arm: y -5 (elbow) .. 5 (shoulder).
		local upper = main[name .. "UpperArm"]
		K.tube(upper, "Strut", V(0, -5, 0), V(0, 5, 0), 2.6, P.VG_FRAME)
		K.ball(upper, "ShoulderBall", 4.6, V(0, 5, 0), P.STEEL_DARK)
		K.tube(upper, "Sleeve", V(0, -3.6, 0), V(0, 1.6, 0), 4.6, P.VG_ARMOR)
		K.ring(upper, "SleeveRim", V(0, -3.5, 0), "Y", 4.95, 0.45, P.VG_ARMOR_DARK)
		K.ring(upper, "SleeveSeam", V(0, -1, 0), "Y", 4.72, 0.2, P.VG_FRAME)
		K.shell(upper, "SleevePlate", CFrame.new(0, -1.2, 0), 90 * sx - 50, 90 * sx + 50, 3, 2.35, 2.35, 3.6, 0.5, P.VG_ARMOR_DARK)
		K.piston(upper, "BicepPiston", V(0, 1.2, -2.6), V(0, -4.4, -2.3), 0.9)
		K.tube(upper, "ElbowDrum", V(-2.3, -5, 0), V(2.3, -5, 0), 4.2, P.STEEL_DARK)
		K.tube(upper, "ElbowCover", V(-2.5, -5, 0), V(2.5, -5, 0), 2.6, P.STEEL_MID)
		K.tube(upper, "ElbowPin", V(-2.7, -5, 0), V(2.7, -5, 0), 0.9, P.STEEL_LIGHT)

		-- Pauldron: a drum over the shoulder, pushed outward, with rolled rims, a painted band and a domed cap.
		local c = V(0.6 * sx, 6, 0)
		local out = V(sx, 0, 0)
		local drum = K.tube(upper, "Pauldron", c - out * 3.2, c + out * 3.2, 8.8, P.VG_ARMOR)
		drum:SetAttribute("Plate", name .. "Pauldron")
		K.ring(upper, "PauldronRim", c + out * 3.05, "X", 9.3, 0.55, P.VG_ARMOR_DARK)
		K.ring(upper, "PauldronRim", c - out * 3.05, "X", 9.3, 0.55, P.VG_ARMOR_DARK)
		local stripe = K.ring(upper, "AccentStripe", c + out * 1.2, "X", 8.94, 0.9, accent or P.VG_PRIMER, "SmoothPlastic")
		stripe:SetAttribute("Plate", name .. "PauldronStripe")
		K.ring(upper, "PauldronSeam", c - out * 0.6, "X", 8.92, 0.25, P.STEEL_DARK)
		for _, angle in ipairs({ -28, -14, 0, 14 }) do
			local at = c + V(0, math.sin(rad(angle)) * 4.42, -math.cos(rad(angle)) * 4.42)
			K.capsule(upper, "PauldronVent", at - out * 2.5, at - out * 1.1, 0.4, P.STEEL_DARK)
		end
		K.egg(upper, "PauldronCap", V(1.6, 7.8, 7.8), c + out * 3.35, P.VG_ARMOR_DARK)
		K.ring(upper, "PauldronHub", c + out * 4.05, "X", 2.4, 0.5, P.STEEL_DARK)
		K.ring(upper, "PauldronHubPin", c + out * 4.3, "X", 1, 0.3, P.STEEL_LIGHT)
		K.stencil(upper, "UnitNumber", V(3.4, 2), CFrame.new(c + out * 4.03 + V(0, 2.2, 0)) * CFrame.Angles(0, rad(-90 * sx), 0), unit)
		if variant.tally and sx < 0 then
			K.stencil(upper, "Tally", V(1.2, 0.8), CFrame.new(c + out * 3.95 + V(0, -2.2, 1.5)) * CFrame.Angles(0, rad(-90 * sx), 0), variant.tally)
		end
		K.ball(upper, "MarkerLight", 0.5, c + out * 3.85 + V(0, -2.4, -1.7), P.AMBER, "Neon")
		local rim = {}
		for index = 0, 7 do
			local angle = rad(45 * index)
			table.insert(rim, { c + out * 3.34 + V(0, math.cos(angle) * 4.35, math.sin(angle) * 4.35), out })
		end
		K.rivets(upper, "Bolt", rim)

		-- Lower arm: y -4.5 (wrist) .. 4.5 (elbow). Thick: a sleeve that flares into a heavy cuff.
		local lower = main[name .. "LowerArm"]
		K.tube(lower, "Strut", V(0, -4.5, 0), V(0, 4.5, 0), 2.6, P.VG_FRAME)
		local sleeve = K.tube(lower, "Shell", V(0, -1.4, 0), V(0, 3, 0), 4.6, P.VG_ARMOR_DARK)
		K.ring(lower, "ShellRim", V(0, 2.9, 0), "Y", 4.9, 0.4, P.STEEL_DARK)
		K.tube(lower, "Cuff", V(0, -4, 0), V(0, -1.4, 0), 5.6, P.VG_ARMOR)
		K.ring(lower, "CuffRidge", V(0, -1.5, 0), "Y", 5.9, 0.4, P.STEEL_DARK)
		K.ring(lower, "CuffLip", V(0, -3.9, 0), "Y", 5.9, 0.4, P.STEEL_DARK)
		K.ring(lower, "CuffBand", V(0, -2.7, 0), "Y", 5.66, 0.5, P.HAZARD_YELLOW, "SmoothPlastic")
		K.ring(lower, "WristRing", V(0, -4.3, 0), "Y", 4.6, 0.8, P.STEEL_DARK)
		K.egg(lower, "ElbowGuard", V(3.4, 3, 2.4), V(0, 4.2, 2.2), P.VG_ARMOR)
		K.hose(lower, "ForearmLine", { V(-1.2 * sx, 3.4, 1.9), V(-3.6 * sx, 1, 2.2), V(-2.2 * sx, -1.3, 1.6) }, 0.4, P.HAZARD_BLACK, 6)
		K.hose(lower, "ForearmWire", { V(-1.7 * sx, 3.4, 1.1), V(-3.9 * sx, 0.8, 1.1), V(-2.5 * sx, -1.3, 0.8) }, 0.28, P.STEEL_MID, 6)
		K.rivets(lower, "Bolt", {
			{ V(0, -3.3, -2.8), V(0, 0, -1) }, { V(2.8, -3.3, 0), V(1, 0, 0) }, { V(0, -3.3, 2.8), V(0, 0, 1) }, { V(-2.8, -3.3, 0), V(-1, 0, 0) },
		})

		-- The lines behind the elbow bend with it.
		K.cable(name .. "ElbowCable", upper, V(0.8, -2.8, 2.2), V(0, -0.3, 1), lower, V(0.8, 2.6, 2.3), V(0, -0.3, -1), 0.42, 2)
		K.cable(name .. "ElbowWire", upper, V(-0.8, -2.6, 2.2), V(0, -0.3, 1), lower, V(-0.8, 2.4, 2.3), V(0, -0.3, -1), 0.28, 1.6, P.STEEL_MID)

		if sx > 0 then
			-- Outer armor plate, and the blade mount on the inner side.
			local axis = CFrame.new(0, 0.8, 0)
			local plates = K.shell(lower, "ShellOuter", axis, 35, 145, 3, 2.7, 2.4, 4, 0.6, P.VG_ARMOR)
			plates[2]:SetAttribute("Plate", name .. "ForearmSide")
			K.arc(lower, "ShellOuterRim", axis, 35, 145, 3, 2.7, 2, 0.5, P.VG_ARMOR_DARK)
			K.tube(lower, "BladeMount", V(-3.1, -4, 0), V(-3.1, -1, 0), 1.5, P.STEEL_DARK)
			K.ring(lower, "BladeMountCap", V(-3.1, -1, 0), "Y", 1.9, 0.4, P.STEEL_MID)
		else
			sleeve:SetAttribute("Plate", name .. "ForearmSide")
			-- Pile Driver on the outer side of the left forearm.
			local casing = K.add(lower, "cyl", "PD_Casing", V(3.2, 8, 3.2), V(-4.1, -0.5, 0), P.STEEL_DARK, nil, { Axis = "Y" })
			for index, y in ipairs({ 2.6, 0, -2.6 }) do
				K.add(casing, "cyl", "PD_Ring" .. index, V(3.45, 0.24, 3.45), V(0, y, 0), P.HAZARD_YELLOW, nil, { Axis = "Y" })
			end
			K.ball(lower, "PD_Breech", 3.2, V(-4.1, 3.5, 0), P.STEEL_DARK)
			K.ring(lower, "PD_Muzzle", V(-4.1, -4.3, 0), "Y", 3.7, 0.6, P.STEEL_MID)
			K.capsule(lower, "PD_Canister", V(-4.5, -1.4, 2.1), V(-4.5, 1.8, 2.1), 1.1, P.VG_HYDRAULIC)
			K.hose(lower, "PD_GasLine", { V(-4.5, 2.4, 2.1), V(-4.8, 4.6, 1.8), V(-4.1, 4.9, 0.3) }, 0.34, P.HAZARD_BLACK, 5)
			K.hose(lower, "PD_Feed", { V(-4.1, 4.9, 0), V(-3.4, 6.2, 1.6), V(-1.2, 4.6, 2.6) }, 0.5, P.HAZARD_BLACK, 6)
			for _, y in ipairs({ 2, -2.4 }) do
				K.box(lower, "PD_Bracket", V(1.6, 0.8, 2.2), V(-2.7, y, 0), P.STEEL_MID)
			end
			local spike = K.raw("cyl", model, "PD_Spike", V(1.4, 7, 1.4), lower.CFrame * CFrame.new(-4.1, -3.5, 0), P.STEEL_LIGHT, "Metal", { Axis = "Y" })
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
				K.add(spike, "wedge", "PD_Tip" .. index + 1, V(0.7, 1.6, 0.7), CFrame.new(0, -4.3, 0) * CFrame.Angles(0, rad(90 * index), 0) * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, 0, math.pi), P.STEEL_LIGHT)
			end
			for index, z in ipairs({ -1.7, 1.7 }) do
				local nub = K.add(casing, "part", "PD_Vent" .. index, V(0.6, 0.8, 0.5), V(0, 3.2, z), P.STEEL_MID)
				K.attachment(nub, "Steam", V(0, 0.4, 0))
			end
		end

		-- Hand: y -1.5 .. 1.5 (wrist).
		local hand = main[name .. "Hand"]
		K.ball(hand, "WristBall", 3, V(0, 1.5, 0), P.STEEL_DARK)
		K.egg(hand, "Palm", V(4.2, 3.2, 3.2), V(0, 0, 0), P.VG_FRAME)
		K.capsule(hand, "KnuckleGuard", V(-1.7, -0.9, -1.6), V(1.7, -0.9, -1.6), 1.3, P.VG_ARMOR)
		for index, x in ipairs({ -1.5, -0.5, 0.5, 1.5 }) do
			K.poly(hand, "Finger" .. index, { V(x, -1.1, -1.5), V(x, -2.6, -1.7), V(x, -3, -0.5) }, 0.9, P.VG_FRAME, "Metal", { caps = true })
			K.ring(hand, "FingerJoint" .. index, V(x, -2.6, -1.7), "X", 1.05, 0.5, P.STEEL_MID)
		end
		K.poly(hand, "Thumb", { V(-2 * sx, -0.2, -0.8), V(-2.5 * sx, -1.4, -1.3), V(-1.9 * sx, -2.3, -0.9) }, 1, P.VG_FRAME, "Metal", { caps = true })
		if sx > 0 then
			K.box(hand, "Prompt_Board", V(3, 3, 3), V(0, 0, 0), P.VG_FRAME, "SmoothPlastic", { Transparency = 1, CastShadow = false })
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- Breaker Blade. In the grip's space +Y runs up the blade, -Z is the cutting edge, +Z the spine.
	------------------------------------------------------------------------------------------------------------------
	local bladeModel = Instance.new("Model")
	bladeModel.Name = "BreakerBlade"
	bladeModel.Parent = model
	local gripC0 = CFrame.new(0, -0.5, -0.5) * CFrame.Angles(rad(-90), 0, 0)
	local grip = K.raw("part", bladeModel, "Blade_Grip", V(1.5, 6, 1.5), main.RightHand.CFrame * gripC0, P.STEEL_DARK, "Metal", { Transparency = 1, CastShadow = false })
	main.Blade_Grip = grip
	local bladeGrip = Instance.new("Motor6D")
	bladeGrip.Name = "BladeGrip"
	bladeGrip.Part0 = main.RightHand
	bladeGrip.Part1 = grip
	bladeGrip.C0 = gripC0
	bladeGrip.C1 = CFrame.new()
	bladeGrip.Parent = grip
	K.tube(grip, "Handle", V(0, -3, 0), V(0, 3, 0), 1.5, P.STEEL_DARK)
	for index, y in ipairs({ -2.2, -1.1, 0, 1.1, 2.2 }) do
		K.ring(grip, "Wrap" .. index, V(0, y, 0), "Y", 1.75, 0.4, P.KICKPLATE)
	end
	K.ball(grip, "Pommel", 2.4, V(0, -3.7, 0), P.STEEL_MID)
	K.ring(grip, "PommelRing", V(0, -3, 0), "Y", 2, 0.4, P.STEEL_DARK)
	K.capsule(grip, "Guard", V(0, 3.75, -3.4), V(0, 3.75, 3.6), 2.6, P.VG_ARMOR)
	K.box(grip, "Collar", V(2.2, 1.6, 5.6), V(0, 5.2, 0.2), P.STEEL_DARK)
	-- The blade starts on the guard (D-035): 28 long, so its center is 18.5 from the grip's center.
	local blade = K.box(grip, "BladeBody", V(1.6, 28, 6.2), V(0, 18.5, 0.3), P.STEEL_MID)
	K.box(grip, "CuttingEdge", V(0.95, 28, 0.95), CFrame.new(0, 18.5, -2.85) * CFrame.Angles(0, rad(45), 0), P.STEEL_LIGHT, "Metal", { Reflectance = 0.1 })
	K.capsule(grip, "SpineRidge", V(0, 5.2, 3.5), V(0, 31.6, 3.5), 2.2, P.VG_FRAME)
	for index = 0, 4 do
		K.ring(grip, "SpineClamp" .. index + 1, V(0, 8 + 5.3 * index, 3.5), "Y", 2.6, 0.7, P.STEEL_MID)
	end
	K.add(grip, "wedge", "CleaverTip", V(1.6, 4, 6.2), V(0, 34.5, 0.3), P.STEEL_MID)
	for index, y in ipairs({ 6.6, 7.8, 9 }) do
		K.box(grip, "HazardBand" .. index, V(1.7, 1, 5.4), V(0, y, 0), if index == 2 then P.HAZARD_BLACK else P.HAZARD_YELLOW, "SmoothPlastic")
	end
	for _, x in ipairs({ -1, 1 }) do
		K.capsule(grip, "Fuller", V(0.8 * x, 24, 0), V(0.8 * x, 31, 0), 0.5, P.STEEL_DARK)
		K.rivets(grip, "BladeBolt", {
			{ V(0.82 * x, 11.5, 1.6), V(x, 0, 0) }, { V(0.82 * x, 16.5, 1.6), V(x, 0, 0) }, { V(0.82 * x, 21.5, 1.6), V(x, 0, 0) }, { V(0.82 * x, 26.5, 1.6), V(x, 0, 0) },
		})
	end
	-- Power feed: a capacitor on the flat of the blade, wired to the guard and up to the spine.
	K.capsule(grip, "Capacitor", V(1.15, 11, 0.2), V(1.15, 14, 0.2), 1.1, P.VG_HYDRAULIC)
	K.ring(grip, "CapacitorBand", V(1.15, 12.5, 0.2), "Y", 1.3, 0.5, P.HAZARD_YELLOW)
	K.hose(grip, "PowerFeed", { V(1.1, 4.6, 1), V(2, 8, 2.4), V(1.15, 10.4, 0.2) }, 0.36, P.HAZARD_BLACK, 6)
	K.hose(grip, "PowerLine", { V(1.15, 14.6, 0.2), V(1.6, 16.6, 1.8), V(0.9, 18.6, 3.2) }, 0.3, P.HAZARD_BLACK, 5)
	K.stencil(grip, "Serial", V(6, 2.4), CFrame.new(-0.83, 18, 0) * CFrame.Angles(0, rad(90), rad(90)), "BRK-7", "#9AA1A6")
	K.attachment(blade, "TrailBase", V(0, -12.5, -3.5))
	K.attachment(blade, "TrailTip", V(0, 16, -3.5))
end
