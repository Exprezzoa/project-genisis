--!nonstrict
-- builders/rigs/Vanguard/Legs.lua  ->  ...Builders.Rigs.Vanguard.Legs      (docs/09 §2: feet, lower legs, upper legs)
-- Offsets are relative to each main part's center; the main parts themselves are invisible bones.

local V = Vector3.new
local rad = math.rad

return function(ctx)
	local K, P, main, accent = ctx.K, ctx.P, ctx.main, ctx.accent

	-- Curved front armor on a limb: staves, a raised spine down the middle, a rolled rim top and bottom.
	local function frontArmor(on, name, axis, spread, r0, r1, length)
		local staves = K.shell(on, name, axis, -spread, spread, 5, r0, r1, length, 0.6, P.VG_ARMOR)
		local half = length / 2
		K.capsule(on, name .. "Ridge", K.around(axis, 0, r0 + 0.7, -half + 0.4).Position, K.around(axis, 0, r1 + 0.7, half - 0.4).Position, 0.7, P.VG_ARMOR)
		K.arc(on, name .. "Rim", axis, -spread, spread, 5, r1 + 0.3, half, 0.55, P.VG_ARMOR_DARK)
		K.arc(on, name .. "Rim", axis, -spread, spread, 5, r0 + 0.3, -half, 0.55, P.VG_ARMOR_DARK)
		return staves
	end

	for _, side in ipairs(ctx.SIDES) do
		local name, sx = side[1], side[2]

		-- Foot: y -1.5..1.5, z -5 (toe) .. 5 (heel); the ankle joint is at (0, 1.5, 1.5).
		local foot = main[name .. "Foot"]
		K.box(foot, "Sole", V(5.8, 0.8, 9.4), V(0, -1.1, 0), P.VG_FRAME)
		for index, z in ipairs({ -3.6, -1.8, 0, 1.8, 3.6 }) do
			K.box(foot, "Tread" .. index, V(6, 0.35, 1.1), V(0, -1.33, z), P.KICKPLATE)
		end
		K.box(foot, "FootBody", V(5, 1.8, 6.4), V(0, -0.1, 0.6), P.VG_ARMOR_DARK)
		K.tube(foot, "ToeArmor", V(-2.9, -0.25, -3.7), V(2.9, -0.25, -3.7), 2.3, P.VG_ARMOR)
		K.tube(foot, "HeelBlock", V(-2.7, -0.2, 4.3), V(2.7, -0.2, 4.3), 2.4, P.VG_ARMOR)
		local instep = CFrame.new(0, 0.62, -1.7) * CFrame.Angles(rad(-16), 0, 0)
		K.slab(foot, "Instep", V(5.2, 4.4, 0.6), instep * CFrame.Angles(rad(-90), 0, 0), P.VG_ARMOR, nil, "LR")
		K.capsule(foot, "InstepRidge", instep * V(0, 0.35, -2), instep * V(0, 0.35, 2), 0.6, P.VG_ARMOR_DARK)
		for _, x in ipairs({ -1, 1 }) do
			K.ring(foot, "ToeCap", V(3 * x, -0.25, -3.7), "X", 2.6, 0.35, P.STEEL_DARK)
			K.ring(foot, "HeelCap", V(2.8 * x, -0.2, 4.3), "X", 2.7, 0.35, P.STEEL_DARK)
			K.capsule(foot, "SideRail", V(3.05 * x, -0.5, -2.6), V(3.05 * x, -0.5, 3.2), 0.8, P.STEEL_DARK)
			K.hose(foot, "ToeLine", { V(1.2 * x, 1.3, 0.5), V(1.5 * x, 1.7, -1.6), V(1.3 * x, 0.35, -3.2) }, 0.3, P.HAZARD_BLACK, 5)
		end
		K.ball(foot, "AnkleBall", 4, V(0, 1.5, 1.5), P.STEEL_DARK)
		K.ring(foot, "AnkleCollar", V(0, 1, 1.5), "Y", 5, 0.7, P.STEEL_DARK)
		K.tube(foot, "AnkleAxle", V(-3.3, 1.5, 1.5), V(3.3, 1.5, 1.5), 2.2, P.STEEL_MID)
		K.tube(foot, "AnklePin", V(-3.5, 1.5, 1.5), V(3.5, 1.5, 1.5), 0.9, P.STEEL_LIGHT)
		K.piston(foot, "AchillesPiston", V(0, 0.4, 5), V(0, 2.6, 3.6), 0.8)
		K.rivets(foot, "Bolt", {
			{ instep * V(-2, 0.3, -1.6), instep.UpVector }, { instep * V(2, 0.3, -1.6), instep.UpVector },
			{ instep * V(-2, 0.3, 1.4), instep.UpVector }, { instep * V(2, 0.3, 1.4), instep.UpVector },
		})
		K.attachment(foot, "Dust", V(0, -1.5, -1))

		-- Lower leg: y -4.5 (ankle) .. 4.5 (knee).
		local shin = main[name .. "LowerLeg"]
		K.tube(shin, "Strut", V(0, -4.5, 0), V(0, 4.5, 0), 2.6, P.VG_FRAME)
		K.tube(shin, "CalfArmor", V(0, -3, 0.4), V(0, 3.2, 0.4), 4.6, P.VG_ARMOR_DARK)
		K.ring(shin, "CalfBand", V(0, 1.6, 0.4), "Y", 4.85, 0.3, P.STEEL_DARK)
		local shinAxis = CFrame.new(0, 0.1, 0.2)
		local shinPlates = frontArmor(shin, "ShinPlate", shinAxis, 75, 2.75, 3.35, 6.8)
		shinPlates[3].Name = "ShinGuard"
		shinPlates[3]:SetAttribute("Plate", name .. "ShinGuard")
		if accent then
			K.box(shin, "AccentStripe", V(0.6, 5, 0.1), K.around(shinAxis, 30 * sx, 3.68) * CFrame.Angles(-math.atan2(0.6, 6.8), 0, 0), accent, "SmoothPlastic")
		end
		K.egg(shin, "KneeCap", V(4, 3.6, 2.6), V(0, 4.5, -2.5), P.VG_ARMOR)
		K.ridge(shin, "KneeRidge", V(0, 4.5, -2.5), V(2, 1.8, 1.3), "XZ", -70, 70, 5, 0.45, P.VG_ARMOR_DARK)
		K.tube(shin, "KneeDrum", V(-3, 4.5, 0), V(3, 4.5, 0), 3.6, P.STEEL_DARK)
		K.tube(shin, "KneeCover", V(-3.25, 4.5, 0), V(3.25, 4.5, 0), 2.4, P.STEEL_MID)
		K.tube(shin, "KneePin", V(-3.45, 4.5, 0), V(3.45, 4.5, 0), 0.9, P.STEEL_LIGHT)
		K.ring(shin, "Cuff", V(0, -3.8, 0), "Y", 5.2, 1.4, P.VG_ARMOR)
		K.ring(shin, "CuffRidgeTop", V(0, -3.05, 0), "Y", 5.5, 0.35, P.STEEL_DARK)
		K.ring(shin, "CuffRidgeBottom", V(0, -4.4, 0), "Y", 5.5, 0.35, P.STEEL_DARK)
		for _, x in ipairs({ -1, 1 }) do
			K.piston(shin, "SidePiston", V(2.3 * x, 3.4, 2), V(2.3 * x, -3, 1.7), 0.9)
			K.hose(shin, "CalfHose", { V(1 * x, 3.6, 2), V(1.6 * x, 2.6, 4.4), V(0.9 * x, 0.2, 2.8) }, 0.4, P.HAZARD_BLACK, 6)
		end
		K.box(shin, "VentHousing", V(2.6, 2.2, 0.7), V(0, -1.2, 2.75), P.STEEL_DARK)
		for index, y in ipairs({ -0.6, -1.2, -1.8 }) do
			K.capsule(shin, "CalfVent" .. index, V(-1, y, 3.15), V(1, y, 3.15), 0.32, P.STEEL_MID)
		end
		K.rivets(shin, "Bolt", {
			{ V(-1.9, -3.8, -1.8), V(-0.72, 0, -0.69) }, { V(1.9, -3.8, -1.8), V(0.72, 0, -0.69) },
			{ V(-1.9, -3.8, 1.8), V(-0.72, 0, 0.69) }, { V(1.9, -3.8, 1.8), V(0.72, 0, 0.69) },
		})

		-- Upper leg: y -4 (knee) .. 4 (hip).
		local thigh = main[name .. "UpperLeg"]
		K.tube(thigh, "Strut", V(0, -4, 0), V(0, 4, 0), 2.6, P.VG_FRAME)
		K.tube(thigh, "ThighCore", V(0, -3, 0), V(0, 2.4, 0), 4.8, P.VG_ARMOR_DARK)
		K.ring(thigh, "ThighBand", V(0, -2.6, 0), "Y", 5.05, 0.4, P.STEEL_DARK)
		local thighPlates = frontArmor(thigh, "ThighPlate", CFrame.new(0, -0.2, 0), 65, 2.6, 3, 6)
		thighPlates[3]:SetAttribute("Plate", name .. "Thigh")
		K.slab(thigh, "OuterPlate", V(4, 5.2, 0.6), CFrame.new(3.2 * sx, -0.2, 0.5) * CFrame.Angles(0, rad(90), 0), P.VG_ARMOR_DARK)
		K.ball(thigh, "HipBall", 4.4, V(0, 4, 0), P.STEEL_DARK)
		K.tube(thigh, "HipDrum", V(-3, 3.5, 0), V(3, 3.5, 0), 4, P.STEEL_DARK)
		K.tube(thigh, "HipCover", V(-3.2, 3.5, 0), V(3.2, 3.5, 0), 2.6, P.STEEL_MID)
		K.tube(thigh, "HipPin", V(-3.4, 3.5, 0), V(3.4, 3.5, 0), 0.9, P.STEEL_LIGHT)
		K.piston(thigh, "RearPiston", V(0, 2.6, 2.8), V(0, -3.2, 2.7), 1)
		K.hose(thigh, "ThighHose", { V(-1.4 * sx, 3, 1.6), V(-3.7 * sx, 0.5, 1.9), V(-1.9 * sx, -3.4, 1.6) }, 0.4, P.HAZARD_BLACK, 6)
		K.hose(thigh, "ThighWire", { V(-1.7 * sx, 3, 0.8), V(-4 * sx, 0.3, 0.9), V(-2.2 * sx, -3.4, 0.8) }, 0.28, P.STEEL_MID, 6)

		-- The lines behind the knee bend with it.
		K.cable(name .. "KneeCable", thigh, V(0.9 * sx, -2.4, 2.4), V(0, -0.4, 1), shin, V(0.9 * sx, 3.2, 2.5), V(0, -0.4, -1), 0.45, 2.2)
		K.cable(name .. "KneeWire", thigh, V(-0.8 * sx, -2.2, 2.4), V(0, -0.3, 1), shin, V(-0.8 * sx, 3, 2.5), V(0, -0.3, -1), 0.3, 1.7, P.STEEL_MID)
	end
end
