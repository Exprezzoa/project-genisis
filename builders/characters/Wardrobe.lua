--!nonstrict
-- builders/characters/Wardrobe.lua  ->  ServerStorage.DevTools.Builders.Characters.Wardrobe
-- docs/03_characters.md "Uniform system", the cast's builds and hair. Pieces in CharacterKit's format:
-- { on = body part, name, size, at = CFrame in that part's space (-Z front, +X right), color, material?,
-- transparency?, shape? ("Ball" | "Egg" | "CylinderX/Y/Z"), text? }. Round pieces are SmoothPlastic (round
-- Metal reads black); sizes are docs/03's where it gives them.
--
--   officerUniform(trim)  technicianCoverall()  labCoat()  guardKit()  armoredVest()
--   headset()  datapad()  glasses()  badge()  echoPin()  goggles()  weldingMask()  wristBands(color)  chevron(color)
--   hair: ponytail(c, tie)  sidepart(c)  lowBun(c)  slicked(c)  bob(c)  crop(c)  greyBeard(c)   (Orin's comes in Ch3)

local Wardrobe = {}

local V = Vector3.new
local RAD = math.rad
local STRAP, GLOVE, PLATE, AMBER = "#1E2125", "#2A2D31", "#4A5A6A", "#E8A33D"
local HIVIS, COVERALL_DARK, WHITE = "#E8B923", "#4A5538", "#E6E8EA"

local function piece(on, name, size, at, color, extra)
	local p = { on = on, name = name, size = size, at = at, color = color }
	for key, value in pairs(extra or {}) do
		p[key] = value
	end
	return p
end

local function egg(on, name, size, at, color)
	return piece(on, name, size, at, color, { shape = "Egg" })
end

----------------------------------------------------------------------------------------------------------------
-- Uniforms
----------------------------------------------------------------------------------------------------------------
-- Officer uniform (Vale, Rhein): coat skirt from the back and sides of the lower torso, shoulder boards, a high
-- collar, a belt, a row of buttons and trim strips in `trim` (amber for the Directorate, silver for Rhein).
function Wardrobe.officerUniform(trim, coat)
	local metal = { material = "Metal" }
	local list = {
		piece("UpperTorso", "Coat_Collar", V(1.3, 0.34, 1.12), CFrame.new(0, 0.86, 0), coat, { shape = "CylinderY" }),
		piece("UpperTorso", "Coat_CollarTrim", V(1.32, 0.06, 1.14), CFrame.new(0, 1.0, 0), trim, { shape = "CylinderY", material = "Metal" }),
		piece("UpperTorso", "Coat_Placket", V(0.18, 1.5, 0.06), CFrame.new(0.18, -0.02, -0.52), coat),
		piece("LowerTorso", "Coat_Belt", V(2.06, 0.24, 1.06), CFrame.new(0, 0.06, 0), STRAP),
		piece("LowerTorso", "Coat_Buckle", V(0.32, 0.2, 0.08), CFrame.new(0, 0.06, -0.55), trim, metal),
		piece("LowerTorso", "Coat_SkirtL", V(1.0, 1.4, 0.1), CFrame.new(-0.5, -0.82, 0.54), coat),
		piece("LowerTorso", "Coat_SkirtR", V(1.0, 1.4, 0.1), CFrame.new(0.5, -0.82, 0.54), coat),
		piece("LowerTorso", "Coat_SideL", V(0.1, 1.3, 0.8), CFrame.new(-1.05, -0.78, 0.12), coat),
		piece("LowerTorso", "Coat_SideR", V(0.1, 1.3, 0.8), CFrame.new(1.05, -0.78, 0.12), coat),
		piece("LowerTorso", "Coat_Vent", V(0.04, 1.2, 0.12), CFrame.new(0, -0.84, 0.56), STRAP),
	}
	for index = 0, 3 do
		table.insert(list, piece("UpperTorso", "Coat_Button" .. index, V(0.1, 0.1, 0.05), CFrame.new(0.18, 0.5 - index * 0.36, -0.56), trim, { shape = "CylinderZ", material = "Metal" }))
	end
	for _, side in ipairs({ { "L", -1 }, { "R", 1 } }) do
		table.insert(list, piece("UpperTorso", "Coat_Board" .. side[1], V(0.6, 0.08, 0.4), CFrame.new(0.72 * side[2], 0.82, 0), coat))
		table.insert(list, piece("UpperTorso", "Coat_BoardTrim" .. side[1], V(0.6, 0.02, 0.06), CFrame.new(0.72 * side[2], 0.87, -0.12), trim, metal))
		table.insert(list, piece(if side[2] < 0 then "LeftLowerArm" else "RightLowerArm", "Coat_Cuff" .. side[1], V(1.06, 0.2, 1.06), CFrame.new(0, -0.38, 0), coat))
		table.insert(list, piece(if side[2] < 0 then "LeftLowerArm" else "RightLowerArm", "Coat_CuffTrim" .. side[1], V(1.07, 0.04, 1.07), CFrame.new(0, -0.27, 0), trim, metal))
	end
	return list
end

-- Commander's chevron (two wedges) on the left upper arm.
function Wardrobe.chevron(color)
	return {
		piece("LeftUpperArm", "Rank_ChevronL", V(0.05, 0.08, 0.26), CFrame.new(-0.53, -0.18, -0.13) * CFrame.Angles(RAD(-35), 0, 0), color, { material = "Neon" }),
		piece("LeftUpperArm", "Rank_ChevronR", V(0.05, 0.08, 0.26), CFrame.new(-0.53, -0.18, 0.03) * CFrame.Angles(RAD(35), 0, 0), color, { material = "Neon" }),
	}
end

-- Technician coverall (olive; colors come from the spec): high-vis bands (0.06 thick Neon at 70%), a collar, a
-- zip, knee pads, and a tool belt with three pouches.
function Wardrobe.technicianCoverall()
	local band = { material = "Neon", transparency = 0.7 }
	local list = {
		piece("UpperTorso", "Cov_Collar", V(1.32, 0.26, 1.12), CFrame.new(0, 0.86, 0), COVERALL_DARK, { shape = "CylinderY" }),
		piece("UpperTorso", "Cov_Zip", V(0.06, 1.4, 0.04), CFrame.new(0, 0, -0.52), STRAP),
		piece("UpperTorso", "Cov_ChestBand", V(2.04, 0.12, 1.04), CFrame.new(0, 0.18, 0), HIVIS, band),
		piece("UpperTorso", "Cov_PocketL", V(0.42, 0.36, 0.08), CFrame.new(-0.5, 0.42, -0.53), COVERALL_DARK),
		piece("UpperTorso", "Cov_PocketR", V(0.42, 0.36, 0.08), CFrame.new(0.5, 0.42, -0.53), COVERALL_DARK),
		piece("LowerTorso", "Cov_ToolBelt", V(2.08, 0.26, 1.08), CFrame.new(0, 0.04, 0), STRAP),
		piece("LowerTorso", "Cov_Pouch1", V(0.36, 0.42, 0.3), CFrame.new(-0.7, -0.1, -0.5), "#3A3328"),
		piece("LowerTorso", "Cov_Pouch2", V(0.3, 0.38, 0.3), CFrame.new(0.72, -0.1, -0.46), "#3A3328"),
		piece("LowerTorso", "Cov_Pouch3", V(0.5, 0.36, 0.3), CFrame.new(0.2, -0.1, 0.56), "#3A3328"),
		piece("LowerTorso", "Cov_Wrench", V(0.08, 0.6, 0.16), CFrame.new(0.92, -0.32, -0.3) * CFrame.Angles(0, 0, RAD(10)), "#9AA1A6", { material = "Metal" }),
	}
	for _, side in ipairs({ "Left", "Right" }) do
		table.insert(list, piece(side .. "LowerArm", "Cov_Band" .. side, V(1.04, 0.12, 1.04), CFrame.new(0, 0.1, 0), HIVIS, band))
		table.insert(list, piece(side .. "LowerLeg", "Cov_LegBand" .. side, V(1.04, 0.12, 1.04), CFrame.new(0, -0.1, 0), HIVIS, band))
		table.insert(list, egg(side .. "LowerLeg", "Cov_Knee" .. side, V(0.6, 0.5, 0.2), CFrame.new(0, 0.42, -0.5), COVERALL_DARK))
	end
	return list
end

-- An armored vest over the coverall (Morrow, the guards).
function Wardrobe.armoredVest(color)
	return {
		piece("UpperTorso", "Vest_Front", V(1.8, 1.3, 0.22), CFrame.new(0, 0.05, -0.56), color),
		piece("UpperTorso", "Vest_Back", V(1.8, 1.3, 0.22), CFrame.new(0, 0.05, 0.56), color),
		piece("UpperTorso", "Vest_StrapL", V(0.3, 0.2, 1.2), CFrame.new(-0.62, 0.78, 0), color),
		piece("UpperTorso", "Vest_StrapR", V(0.3, 0.2, 1.2), CFrame.new(0.62, 0.78, 0), color),
		piece("UpperTorso", "Vest_MagPouch1", V(0.36, 0.42, 0.18), CFrame.new(-0.42, -0.26, -0.72), STRAP),
		piece("UpperTorso", "Vest_MagPouch2", V(0.36, 0.42, 0.18), CFrame.new(0.42, -0.26, -0.72), STRAP),
	}
end

-- Lab coat (Science / medical): a white coat over the shirt, a tail to mid-thigh, lapels, cuffs and pockets.
function Wardrobe.labCoat()
	local list = {
		piece("UpperTorso", "Lab_Front", V(2.02, 1.6, 0.1), CFrame.new(0, 0, -0.52), WHITE),
		piece("UpperTorso", "Lab_Back", V(2.02, 1.6, 0.1), CFrame.new(0, 0, 0.52), WHITE),
		piece("UpperTorso", "Lab_ShirtV", V(0.5, 0.7, 0.04), CFrame.new(0, 0.46, -0.58), "#6C7A89"),
		piece("UpperTorso", "Lab_LapelL", V(0.32, 0.9, 0.06), CFrame.new(-0.26, 0.36, -0.6) * CFrame.Angles(0, 0, RAD(-18)), WHITE),
		piece("UpperTorso", "Lab_LapelR", V(0.32, 0.9, 0.06), CFrame.new(0.26, 0.36, -0.6) * CFrame.Angles(0, 0, RAD(18)), WHITE),
		piece("UpperTorso", "Lab_Pocket", V(0.4, 0.3, 0.04), CFrame.new(-0.56, 0.3, -0.59), "#D6DADD"),
		piece("UpperTorso", "Lab_Pen", V(0.05, 0.3, 0.05), CFrame.new(-0.48, 0.42, -0.62), AMBER),
		piece("LowerTorso", "Lab_TailB", V(2.02, 1.3, 0.1), CFrame.new(0, -0.74, 0.52), WHITE),
		piece("LowerTorso", "Lab_TailL", V(0.1, 1.3, 1.02), CFrame.new(-1.02, -0.74, 0), WHITE),
		piece("LowerTorso", "Lab_TailR", V(0.1, 1.3, 1.02), CFrame.new(1.02, -0.74, 0), WHITE),
		piece("LowerTorso", "Lab_TailFL", V(0.62, 1.3, 0.1), CFrame.new(-0.7, -0.74, -0.52), WHITE),
		piece("LowerTorso", "Lab_TailFR", V(0.62, 1.3, 0.1), CFrame.new(0.7, -0.74, -0.52), WHITE),
	}
	for _, side in ipairs({ "Left", "Right" }) do
		table.insert(list, piece(side .. "UpperArm", "Lab_Sleeve" .. side, V(1.06, 1.1, 1.06), CFrame.new(0, 0, 0), WHITE))
		table.insert(list, piece(side .. "LowerArm", "Lab_Cuff" .. side, V(1.06, 0.6, 1.06), CFrame.new(0, 0.18, 0), WHITE))
	end
	return list
end

-- A Science Division guard (S40): black-grey plates, a helmet with a dark visor, an ECHO pin.
function Wardrobe.guardKit(color)
	local list = Wardrobe.armoredVest(color)
	table.insert(list, egg("Head", "Helmet", V(1.4, 0.9, 1.44), CFrame.new(0, 0.36, 0.04), color))
	table.insert(list, piece("Head", "Helmet_Brim", V(1.42, 0.12, 0.3), CFrame.new(0, 0.14, -0.62), color))
	table.insert(list, piece("Head", "Helmet_Visor", V(1.1, 0.34, 0.12), CFrame.new(0, -0.02, -0.62), "#15181C", { material = "Glass", transparency = 0.15 }))
	for _, item in ipairs(Wardrobe.echoPin()) do
		table.insert(list, item)
	end
	return list
end

----------------------------------------------------------------------------------------------------------------
-- Accessories
----------------------------------------------------------------------------------------------------------------
-- Okafor's headset: an arc of three pieces over the head and a mic boom.
function Wardrobe.headset()
	return {
		piece("Head", "Headset_Top", V(0.9, 0.12, 0.18), CFrame.new(0, 0.82, 0), GLOVE),
		piece("Head", "Headset_ArcL", V(0.12, 0.5, 0.18), CFrame.new(-0.64, 0.5, 0) * CFrame.Angles(0, 0, RAD(-20)), GLOVE),
		piece("Head", "Headset_ArcR", V(0.12, 0.5, 0.18), CFrame.new(0.64, 0.5, 0) * CFrame.Angles(0, 0, RAD(20)), GLOVE),
		piece("Head", "Headset_CupL", V(0.16, 0.42, 0.42), CFrame.new(-0.66, 0.02, 0), STRAP, { shape = "CylinderX" }),
		piece("Head", "Headset_CupR", V(0.16, 0.42, 0.42), CFrame.new(0.66, 0.02, 0), STRAP, { shape = "CylinderX" }),
		piece("Head", "Headset_Boom", V(0.06, 0.06, 0.7), CFrame.new(-0.6, -0.2, -0.32) * CFrame.Angles(RAD(-15), RAD(25), 0), GLOVE),
		piece("Head", "Headset_Mic", V(0.14, 0.12, 0.12), CFrame.new(-0.42, -0.32, -0.64), STRAP, { shape = "Egg" }),
		piece("Head", "Headset_Light", V(0.06, 0.06, 0.06), CFrame.new(-0.74, 0.1, 0), AMBER, { material = "Neon" }),
	}
end

-- Vale's datapad in the left hand (screen Neon amber at 60%).
function Wardrobe.datapad()
	return {
		piece("LeftHand", "Datapad", V(0.6, 0.8, 0.08), CFrame.new(0.1, -0.3, -0.25) * CFrame.Angles(RAD(-55), 0, 0), "#2A2D31"),
		piece("LeftHand", "Datapad_Screen", V(0.5, 0.66, 0.02), CFrame.new(0.1, -0.3, -0.25) * CFrame.Angles(RAD(-55), 0, 0) * CFrame.new(0, 0, -0.05), AMBER, { material = "Neon", transparency = 0.6 }),
	}
end

-- Glasses: two thin frames with glass lenses and a bridge.
function Wardrobe.glasses()
	return {
		piece("Head", "Glasses_FrameL", V(0.32, 0.22, 0.05), CFrame.new(-0.22, 0.08, -0.62), STRAP),
		piece("Head", "Glasses_FrameR", V(0.32, 0.22, 0.05), CFrame.new(0.22, 0.08, -0.62), STRAP),
		piece("Head", "Glasses_LensL", V(0.26, 0.16, 0.03), CFrame.new(-0.22, 0.08, -0.65), "#9FB4C4", { material = "Glass", transparency = 0.7 }),
		piece("Head", "Glasses_LensR", V(0.26, 0.16, 0.03), CFrame.new(0.22, 0.08, -0.65), "#9FB4C4", { material = "Glass", transparency = 0.7 }),
		piece("Head", "Glasses_Bridge", V(0.14, 0.04, 0.04), CFrame.new(0, 0.12, -0.64), STRAP),
		piece("Head", "Glasses_ArmL", V(0.04, 0.04, 0.6), CFrame.new(-0.4, 0.1, -0.32), STRAP),
		piece("Head", "Glasses_ArmR", V(0.04, 0.04, 0.6), CFrame.new(0.4, 0.1, -0.32), STRAP),
	}
end

-- An ID badge on the coat: white with an amber stripe.
function Wardrobe.badge()
	return {
		piece("UpperTorso", "Badge", V(0.3, 0.4, 0.03), CFrame.new(0.56, 0.32, -0.6), WHITE),
		piece("UpperTorso", "Badge_Stripe", V(0.3, 0.06, 0.035), CFrame.new(0.56, 0.42, -0.6), AMBER),
	}
end

-- The ECHO pin on the collar: three concentric thin rings in silver (a clue, docs/04 clue 9).
function Wardrobe.echoPin()
	local list = {}
	for index, ring in ipairs({ { 0.24, "#AEB6BF" }, { 0.18, "#24282E" }, { 0.13, "#AEB6BF" }, { 0.08, "#24282E" }, { 0.04, "#AEB6BF" } }) do
		table.insert(list, piece("UpperTorso", "EchoPin" .. index, V(ring[1], ring[1], 0.05), CFrame.new(-0.42, 0.66, -0.6 - index * 0.004), ring[2], { shape = "CylinderZ", material = "Metal" }))
	end
	return list
end

-- Welding goggles pushed up on the forehead (Hollis).
function Wardrobe.goggles()
	return {
		piece("Head", "Goggles_Band", V(1.28, 0.14, 1.28), CFrame.new(0, 0.42, 0), STRAP, { shape = "CylinderY" }),
		piece("Head", "Goggles_L", V(0.32, 0.26, 0.22), CFrame.new(-0.24, 0.5, -0.6), "#1B1D20", { shape = "CylinderZ" }),
		piece("Head", "Goggles_R", V(0.32, 0.26, 0.22), CFrame.new(0.24, 0.5, -0.6), "#1B1D20", { shape = "CylinderZ" }),
		piece("Head", "Goggles_LensL", V(0.24, 0.2, 0.04), CFrame.new(-0.24, 0.5, -0.72), "#4A6A5A", { shape = "CylinderZ", material = "Glass", transparency = 0.3 }),
		piece("Head", "Goggles_LensR", V(0.24, 0.2, 0.04), CFrame.new(0.24, 0.5, -0.72), "#4A6A5A", { shape = "CylinderZ", material = "Glass", transparency = 0.3 }),
	}
end

-- Pell's welding mask over the face (a dark block, 1.0 x 1.0 x 0.3) with a narrow window.
function Wardrobe.weldingMask()
	return {
		piece("Head", "WeldMask", V(1.0, 1.0, 0.3), CFrame.new(0, 0, -0.62), "#1B1D20"),
		piece("Head", "WeldMask_Window", V(0.6, 0.16, 0.04), CFrame.new(0, 0.12, -0.79), "#3A5A4A", { material = "Glass", transparency = 0.2 }),
		piece("Head", "WeldMask_Band", V(1.26, 0.18, 1.26), CFrame.new(0, 0.3, 0.02), STRAP, { shape = "CylinderY" }),
	}
end

-- Wrist bands on both lower arms (Mara's fingerless-glove look).
function Wardrobe.wristBands(color)
	return {
		piece("LeftLowerArm", "WristBandL", V(1.08, 0.15, 1.08), CFrame.new(0, -0.44, 0), color),
		piece("RightLowerArm", "WristBandR", V(1.08, 0.15, 1.08), CFrame.new(0, -0.44, 0), color),
	}
end

----------------------------------------------------------------------------------------------------------------
-- Hair (6-14 parts each, docs/03)
----------------------------------------------------------------------------------------------------------------
-- Mara: a high tight ponytail. Cap, hairline band, the tie ring (Neon red), three tail pieces each tilted more.
function Wardrobe.ponytail(color, tie)
	local list = {
		egg("Head", "Hair_Cap", V(1.34, 0.7, 1.38), CFrame.new(0, 0.42, 0.04), color),
		egg("Head", "Hair_Hairline", V(1.28, 0.22, 0.34), CFrame.new(0, 0.54, -0.5), color),
		egg("Head", "Hair_SideL", V(0.22, 0.5, 0.9), CFrame.new(-0.6, 0.24, 0.08), color),
		egg("Head", "Hair_SideR", V(0.22, 0.5, 0.9), CFrame.new(0.6, 0.24, 0.08), color),
		piece("Head", "Hair_Tie", V(0.25, 0.35, 0.35), CFrame.new(0, 0.45, 0.62) * CFrame.Angles(RAD(-30), 0, 0), tie, { shape = "CylinderZ", material = "Neon" }),
	}
	local at = CFrame.new(0, 0.42, 0.72)
	for index, size in ipairs({ V(0.35, 0.6, 0.35), V(0.3, 0.6, 0.3), V(0.22, 0.5, 0.22) }) do
		local tilt = CFrame.Angles(RAD(-(20 + 15 * index)), 0, 0)
		local center = at * tilt * CFrame.new(0, -size.Y / 2, 0)
		table.insert(list, egg("Head", "Hair_Tail" .. index, size, center, color))
		at = at * tilt * CFrame.new(0, -size.Y * 0.85, 0)
	end
	return list
end

-- Vale: short grey with a side part (two top pieces slightly offset), and beard stubble at 30%.
function Wardrobe.sidepart(color)
	return {
		egg("Head", "Hair_TopL", V(0.7, 0.4, 1.3), CFrame.new(-0.3, 0.58, 0.04), color),
		egg("Head", "Hair_TopR", V(0.66, 0.36, 1.28), CFrame.new(0.32, 0.56, 0.04) * CFrame.Angles(0, 0, RAD(-8)), color),
		egg("Head", "Hair_SideL", V(0.16, 0.42, 1.0), CFrame.new(-0.62, 0.26, 0.1), color),
		egg("Head", "Hair_SideR", V(0.16, 0.42, 1.0), CFrame.new(0.62, 0.26, 0.1), color),
		egg("Head", "Hair_Nape", V(1.1, 0.5, 0.3), CFrame.new(0, 0.2, 0.56), color),
		piece("Head", "Stubble", V(1.0, 0.35, 0.1), CFrame.new(0, -0.38, -0.58), color, { transparency = 0.3 }),
	}
end

-- Voss: a low bun (Ball 0.6 at the back) and two strands framing the face.
function Wardrobe.lowBun(color)
	return {
		egg("Head", "Hair_Cap", V(1.32, 0.66, 1.36), CFrame.new(0, 0.42, 0.04), color),
		egg("Head", "Hair_Back", V(1.2, 0.8, 0.34), CFrame.new(0, 0.12, 0.56), color),
		piece("Head", "Hair_Bun", V(0.6, 0.6, 0.6), CFrame.new(0, -0.1, 0.72), color, { shape = "Ball" }),
		egg("Head", "Hair_StrandL", V(0.14, 0.6, 0.12), CFrame.new(-0.5, 0.04, -0.5), color),
		egg("Head", "Hair_StrandR", V(0.14, 0.6, 0.12), CFrame.new(0.5, 0.04, -0.5), color),
		egg("Head", "Hair_SideL", V(0.18, 0.5, 0.9), CFrame.new(-0.6, 0.22, 0.1), color),
		egg("Head", "Hair_SideR", V(0.18, 0.5, 0.9), CFrame.new(0.6, 0.22, 0.1), color),
	}
end

-- Rhein: slicked back, the top swept back 8 degrees.
function Wardrobe.slicked(color)
	return {
		egg("Head", "Hair_Cap", V(1.32, 0.66, 1.42), CFrame.new(0, 0.46, 0.1), color),
		egg("Head", "Hair_Sweep", V(1.1, 0.3, 1.2), CFrame.new(0, 0.68, 0.12) * CFrame.Angles(RAD(-8), 0, 0), color),
		egg("Head", "Hair_SideL", V(0.16, 0.4, 1.0), CFrame.new(-0.62, 0.26, 0.14), color),
		egg("Head", "Hair_SideR", V(0.16, 0.4, 1.0), CFrame.new(0.62, 0.26, 0.14), color),
		egg("Head", "Hair_Nape", V(1.1, 0.5, 0.32), CFrame.new(0, 0.16, 0.6), color),
	}
end

-- Tamsin: a red bob, chin length.
function Wardrobe.bob(color)
	return {
		egg("Head", "Hair_Cap", V(1.38, 0.74, 1.42), CFrame.new(0, 0.4, 0.04), color),
		egg("Head", "Hair_Fringe", V(1.1, 0.3, 0.4), CFrame.new(0, 0.5, -0.5) * CFrame.Angles(RAD(14), 0, 0), color),
		egg("Head", "Hair_SideL", V(0.3, 0.9, 1.1), CFrame.new(-0.62, 0.04, 0.08), color),
		egg("Head", "Hair_SideR", V(0.3, 0.9, 1.1), CFrame.new(0.62, 0.04, 0.08), color),
		egg("Head", "Hair_Back", V(1.3, 0.9, 0.36), CFrame.new(0, 0.04, 0.56), color),
		egg("Head", "Hair_TipL", V(0.3, 0.3, 0.5), CFrame.new(-0.6, -0.36, -0.12), color),
		egg("Head", "Hair_TipR", V(0.3, 0.3, 0.5), CFrame.new(0.6, -0.36, -0.12), color),
	}
end

-- A close crop for officers, technicians and Okafor.
function Wardrobe.crop(color)
	return {
		egg("Head", "Hair_Cap", V(1.3, 0.56, 1.34), CFrame.new(0, 0.5, 0.04), color),
		egg("Head", "Hair_SideL", V(0.14, 0.36, 0.9), CFrame.new(-0.62, 0.3, 0.1), color),
		egg("Head", "Hair_SideR", V(0.14, 0.36, 0.9), CFrame.new(0.62, 0.3, 0.1), color),
		egg("Head", "Hair_Nape", V(1.0, 0.4, 0.26), CFrame.new(0, 0.24, 0.58), color),
		egg("Head", "Hair_Front", V(0.9, 0.2, 0.3), CFrame.new(0, 0.6, -0.48), color),
		egg("Head", "Hair_Crown", V(0.6, 0.2, 0.6), CFrame.new(0.1, 0.78, 0.1), color),
	}
end

-- Hollis: bald, a grey beard (a 1.1 x 0.45 x 0.3 front block and two side blocks).
function Wardrobe.greyBeard(color)
	return {
		egg("Head", "Beard_Front", V(1.1, 0.45, 0.3), CFrame.new(0, -0.42, -0.52), color),
		egg("Head", "Beard_SideL", V(0.2, 0.5, 0.5), CFrame.new(-0.56, -0.24, -0.24), color),
		egg("Head", "Beard_SideR", V(0.2, 0.5, 0.5), CFrame.new(0.56, -0.24, -0.24), color),
		egg("Head", "Moustache", V(0.6, 0.12, 0.12), CFrame.new(0, -0.18, -0.62), color),
		egg("Head", "Fringe_Back", V(1.1, 0.24, 0.3), CFrame.new(0, 0.1, 0.58), color),
		egg("Head", "Fringe_SideL", V(0.12, 0.26, 0.6), CFrame.new(-0.62, 0.14, 0.24), color),
		egg("Head", "Fringe_SideR", V(0.12, 0.26, 0.6), CFrame.new(0.62, 0.14, 0.24), color),
	}
end

return Wardrobe
