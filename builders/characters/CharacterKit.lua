--!nonstrict
-- builders/characters/CharacterKit.lua  ->  ServerStorage.DevTools.Builders.Characters.CharacterKit
-- docs/08_rigs_and_animation.md §1 and docs/03_characters.md.
--
--   local model = CharacterKit.build(BK, spec)
--
-- Builds an R15 character from the default avatar body (Players:CreateHumanoidModelFromDescription),
-- recolors the body parts and welds part-built gear and hair to them.
--   spec.name, spec.height/width (scales, set on the HumanoidDescription before the rig is created)
--   spec.colors = { skin, torso, arms, legs, hands, feet }   (hex strings)
--   spec.gear = list of pieces: { on = "UpperTorso", name, size, at = CFrame (in that body part's space,
--               -Z is the character's front, +X its right), color, material?, transparency?, shape?, text? }
--               shape: nil (block) | "Ball" | "Egg" (an ellipsoid filling size) | "CylinderX" | "CylinderY" | "CylinderZ"
-- The uniform helpers below return such pieces (docs/03 "Uniform system").
--
-- Body colors are set on the parts directly and the BodyColors object is removed: it can't give hands
-- and feet their own color (gloves, boots), and it would repaint them at spawn (D-029).

local Kit = {}

local V = Vector3.new

local REGIONS = {
	skin = { "Head" },
	torso = { "UpperTorso", "LowerTorso" },
	arms = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" },
	legs = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" },
	hands = { "LeftHand", "RightHand" },
	feet = { "LeftFoot", "RightFoot" },
}

local STRAP, GLOVE, PLATE, AMBER = "#1E2125", "#2A2D31", "#4A5A6A", "#E8A33D"

local function piece(on, name, size, at, color, extra)
	local p = { on = on, name = name, size = size, at = at, color = color }
	for key, value in pairs(extra or {}) do
		p[key] = value
	end
	return p
end

local SUIT_DARK, HYDRAULIC = "#1E2125", "#9AA1A6"
local RAD = math.rad

-- The pilot suit (docs/03 "Uniform system", second pass D-053): a padded flight suit with rounded armor.
-- accent = the pilot's color (piping, cuff bands). Limbs are square in section, so cuffs are slightly larger
-- boxes (round rings wide enough to clear the corners looked like hoops); the rounded pieces are pads on
-- the faces. Round pieces are SmoothPlastic: round Metal mirrors the sky and reads as black.
function Kit.pilotSuit(accent)
	local list = {
		-- Collar and shoulder yoke.
		piece("UpperTorso", "Suit_Yoke", V(2.3, 0.5, 1.2), CFrame.new(0, 0.66, 0), SUIT_DARK, { shape = "Egg" }),
		piece("UpperTorso", "Suit_Collar", V(1.36, 0.3, 1.36), CFrame.new(0, 0.92, 0.02), GLOVE, { shape = "CylinderY" }),
		piece("UpperTorso", "Suit_NeckSeal", V(1.02, 0.34, 1.02), CFrame.new(0, 1.02, 0.02), PLATE, { shape = "CylinderY" }),
		-- Chest: a domed plate, a status light, two rolled belly pads.
		piece("UpperTorso", "Suit_ChestPlate", V(1.56, 1.05, 0.5), CFrame.new(0, 0.2, -0.46), PLATE, { shape = "Egg" }),
		piece("UpperTorso", "Suit_ChestRidge", V(0.16, 0.9, 0.16), CFrame.new(0, 0.2, -0.7) * CFrame.Angles(0, 0, 0), SUIT_DARK, { shape = "CylinderY" }),
		piece("UpperTorso", "Suit_StatusLight", V(0.14, 0.14, 0.14), CFrame.new(-0.48, 0.42, -0.66), AMBER, { shape = "Ball", material = "Neon" }),
		piece("UpperTorso", "Suit_BellyPad1", V(1.3, 0.24, 0.24), CFrame.new(0, -0.42, -0.5), SUIT_DARK, { shape = "CylinderX" }),
		piece("UpperTorso", "Suit_BellyPad2", V(1.16, 0.22, 0.22), CFrame.new(0, -0.66, -0.5), SUIT_DARK, { shape = "CylinderX" }),
		-- Back: life-support pack, two canisters, a feed line up to the collar.
		piece("UpperTorso", "Suit_Pack", V(1.36, 1.2, 0.5), CFrame.new(0, 0.12, 0.6), SUIT_DARK, { shape = "Egg" }),
		piece("UpperTorso", "Suit_PackPlate", V(0.8, 0.7, 0.12), CFrame.new(0, 0.16, 0.86), PLATE, { material = "Metal" }),
		piece("UpperTorso", "Suit_CanisterL", V(0.26, 0.9, 0.26), CFrame.new(-0.56, 0.08, 0.8), HYDRAULIC, { shape = "CylinderY" }),
		piece("UpperTorso", "Suit_CanisterR", V(0.26, 0.9, 0.26), CFrame.new(0.56, 0.08, 0.8), HYDRAULIC, { shape = "CylinderY" }),
		piece("UpperTorso", "Suit_PackLight", V(0.3, 0.08, 0.06), CFrame.new(0, 0.38, 0.93), AMBER, { material = "Neon" }),
		piece("UpperTorso", "Suit_FeedLine", V(0.1, 0.62, 0.1), CFrame.new(0.3, 0.74, 0.62) * CFrame.Angles(RAD(-28), 0, RAD(14)), STRAP, { shape = "CylinderY" }),
		-- Belt, buckle, pouches, hip plates.
		piece("LowerTorso", "Suit_Belt", V(2.08, 0.28, 1.08), CFrame.new(0, 0.02, 0), STRAP),
		piece("LowerTorso", "Suit_Buckle", V(0.4, 0.26, 0.1), CFrame.new(0, 0.02, -0.56), AMBER, { material = "Metal" }),
		piece("LowerTorso", "Suit_PouchL", V(0.36, 0.4, 0.26), CFrame.new(-0.62, -0.08, -0.56), SUIT_DARK, { shape = "Egg" }),
		piece("LowerTorso", "Suit_PouchR", V(0.36, 0.4, 0.26), CFrame.new(0.62, -0.08, -0.56), SUIT_DARK, { shape = "Egg" }),
	}
	for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
		local name, sx = side[1], side[2]
		local function add(on, id, size, at, color, extra)
			table.insert(list, piece(name .. on, "Suit_" .. name .. id, size, at, color, extra))
		end
		table.insert(list, piece("LowerTorso", "Suit_HipPlate" .. name, V(0.3, 0.7, 0.9), CFrame.new(1.04 * sx, -0.22, 0), PLATE, { shape = "Egg" }))
		-- Arm: shoulder cap, accent piping, forearm guard with an accent ring, glove cuff, elbow pad.
		add("UpperArm", "ShoulderCap", V(1.2, 0.72, 1.2), CFrame.new(0.04 * sx, 0.4, 0), PLATE, { shape = "Egg" })
		add("UpperArm", "ShoulderBand", V(1.08, 0.1, 1.08), CFrame.new(0, 0.02, 0), SUIT_DARK)
		add("UpperArm", "Piping", V(0.06, 0.7, 0.06), CFrame.new(0.52 * sx, -0.32, 0.36), accent, { material = "Neon", transparency = 0.2 })
		add("LowerArm", "ElbowPad", V(0.62, 0.5, 0.36), CFrame.new(0, 0.42, 0.44), SUIT_DARK, { shape = "Egg" })
		add("LowerArm", "Gauntlet", V(1.1, 0.6, 1.1), CFrame.new(0, -0.12, 0), SUIT_DARK)
		add("LowerArm", "GauntletPlate", V(0.3, 0.5, 0.8), CFrame.new(0.5 * sx, -0.12, 0), PLATE, { shape = "Egg" })
		add("LowerArm", "GauntletBand", V(1.12, 0.05, 1.12), CFrame.new(0, 0.16, 0), accent)
		add("LowerArm", "GloveCuff", V(1.12, 0.12, 1.12), CFrame.new(0, -0.46, 0), PLATE)
		add("Hand", "Knuckle", V(0.9, 0.2, 0.3), CFrame.new(0, 0.02, -0.4), PLATE, { shape = "CylinderX" })
		-- Leg: thigh pocket, accent piping, knee pad, shin guard, boot cuff, toe cap.
		add("UpperLeg", "ThighPocket", V(0.24, 0.6, 0.56), CFrame.new(0.54 * sx, -0.05, 0), SUIT_DARK, { shape = "Egg" })
		add("UpperLeg", "Piping", V(0.06, 1.1, 0.06), CFrame.new(0.52 * sx, 0, 0.34), accent, { material = "Neon", transparency = 0.2 })
		add("LowerLeg", "KneePad", V(0.9, 0.56, 0.42), CFrame.new(0, 0.5, -0.42), SUIT_DARK, { shape = "Egg" })
		add("LowerLeg", "ShinGuard", V(0.8, 0.9, 0.3), CFrame.new(0, -0.1, -0.44), PLATE, { shape = "Egg" })
		add("LowerLeg", "BootCuff", V(1.1, 0.24, 1.1), CFrame.new(0, -0.5, 0), GLOVE)
		add("LowerLeg", "BootBand", V(1.12, 0.05, 1.12), CFrame.new(0, -0.36, 0), accent)
		add("Foot", "ToeCap", V(1.04, 0.34, 0.7), CFrame.new(0, 0.02, -0.26), GLOVE, { shape = "Egg" })
		add("Foot", "Heel", V(1.04, 0.3, 0.3), CFrame.new(0, 0, 0.4), GLOVE, { shape = "CylinderX" })
	end
	return list
end

-- The pilot's mask (user direction, D-055): a faceplate over the whole face with an amber visor band, a
-- rebreather on the mouth with a filter on each cheek, and a chin guard. Pilots are never seen without it.
function Kit.pilotMask()
	return {
		-- A hood under the hair and the faceplate, so no skin shows anywhere on the head.
		piece("Head", "Mask_Hood", V(1.27, 1.14, 1.27), CFrame.new(0, -0.06, 0), SUIT_DARK, { shape = "CylinderY" }),
		piece("Head", "Mask_Faceplate", V(1.16, 1.06, 0.62), CFrame.new(0, -0.04, -0.36), SUIT_DARK, { shape = "Egg" }),
		piece("Head", "Mask_Brow", V(1.06, 0.16, 0.3), CFrame.new(0, 0.3, -0.52), PLATE, { shape = "CylinderX" }),
		piece("Head", "Mask_Visor", V(0.98, 0.26, 0.2), CFrame.new(0, 0.12, -0.6), "#FFB347", { shape = "Egg", material = "Neon", transparency = 0.1 }),
		piece("Head", "Mask_Rebreather", V(0.36, 0.34, 0.3), CFrame.new(0, -0.3, -0.62), PLATE, { shape = "CylinderZ" }),
		piece("Head", "Mask_RebreatherCap", V(0.22, 0.22, 0.08), CFrame.new(0, -0.3, -0.79), GLOVE, { shape = "CylinderZ" }),
		piece("Head", "Mask_FilterL", V(0.24, 0.24, 0.24), CFrame.new(-0.36, -0.32, -0.5) * CFrame.Angles(0, RAD(-35), 0), HYDRAULIC, { shape = "CylinderX" }),
		piece("Head", "Mask_FilterR", V(0.24, 0.24, 0.24), CFrame.new(0.36, -0.32, -0.5) * CFrame.Angles(0, RAD(35), 0), HYDRAULIC, { shape = "CylinderX" }),
		piece("Head", "Mask_Chin", V(0.7, 0.2, 0.36), CFrame.new(0, -0.52, -0.42), PLATE, { shape = "Egg" }),
		piece("Head", "Mask_StrapL", V(0.08, 0.14, 0.9), CFrame.new(-0.6, 0.02, -0.02), STRAP),
		piece("Head", "Mask_StrapR", V(0.08, 0.14, 0.9), CFrame.new(0.6, 0.02, -0.02), STRAP),
	}
end

-- Short hair built from rounded pieces: a cap, a swept fringe, sides and a nape (docs/03).
function Kit.shortHair(color)
	local function lock(name, size, at)
		return piece("Head", name, size, at, color, { shape = "Egg" })
	end
	return {
		lock("Hair_Cap", V(1.36, 0.78, 1.4), CFrame.new(0, 0.4, 0.06)),
		lock("Hair_Fringe1", V(0.6, 0.34, 0.62), CFrame.new(-0.3, 0.62, -0.42) * CFrame.Angles(RAD(18), 0, RAD(12))),
		lock("Hair_Fringe2", V(0.6, 0.36, 0.66), CFrame.new(0.12, 0.68, -0.46) * CFrame.Angles(RAD(22), 0, RAD(-6))),
		lock("Hair_Fringe3", V(0.5, 0.3, 0.56), CFrame.new(0.44, 0.6, -0.34) * CFrame.Angles(RAD(12), 0, RAD(-18))),
		lock("Hair_SideL", V(0.26, 0.62, 1.04), CFrame.new(-0.6, 0.2, 0.12)),
		lock("Hair_SideR", V(0.26, 0.62, 1.04), CFrame.new(0.6, 0.2, 0.12)),
		lock("Hair_Nape", V(1.18, 0.8, 0.42), CFrame.new(0, 0.12, 0.56)),
		-- Comm earpiece on the right ear.
		piece("Head", "Comm_Earpiece", V(0.1, 0.3, 0.3), CFrame.new(0.63, 0, 0.02), "#2A2D31", { shape = "CylinderX" }),
		piece("Head", "Comm_Light", V(0.04, 0.08, 0.08), CFrame.new(0.69, 0, 0.02), AMBER, { material = "Neon" }),
	}
end

-- Rank bars on the left upper arm (Pilot Officer 1, Lieutenant 2, Captain 3).
function Kit.rankBars(count)
	local list = {}
	for i = 1, count do
		table.insert(list, piece("LeftUpperArm", "Rank_Bar" .. i, V(0.05, 0.08, 0.3), CFrame.new(-0.53, -0.14 - (i - 1) * 0.14, -0.05), AMBER, { material = "Neon" }))
	end
	return list
end

-- Division patch on the right upper arm.
function Kit.divisionPatch()
	return {
		piece("RightUpperArm", "Patch_Base", V(0.05, 0.5, 0.5), CFrame.new(0.52, -0.28, -0.05), PLATE),
		piece("RightUpperArm", "Patch_Bar", V(0.05, 0.08, 0.3), CFrame.new(0.55, -0.28, -0.05), AMBER),
	}
end

-- Squad tag on the chest plate: amber Michroma text.
function Kit.chestTag(text)
	return { piece("UpperTorso", "ChestTag", V(0.84, 0.22, 0.06), CFrame.new(0.2, 0.42, -0.72), "#3B4A5A", { text = text }) }
end

function Kit.join(...)
	local all = {}
	for _, list in ipairs({ ... }) do
		for _, item in ipairs(list) do
			table.insert(all, item)
		end
	end
	return all
end

function Kit.build(BK, spec)
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = spec.height or 1
	description.WidthScale = spec.width or 1
	local model = game:GetService("Players"):CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = spec.name

	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	for region, names in pairs(REGIONS) do
		local color = BK.toColor(spec.colors[region])
		for _, name in ipairs(names) do
			model[name].Color = color
		end
	end

	local scale = spec.height or 1
	local gear = Instance.new("Folder")
	gear.Name = "Gear"
	gear.Parent = model
	for _, p in ipairs(spec.gear or {}) do
		local body = model[p.on]
		local at = body.CFrame * CFrame.new(p.at.Position * scale) * p.at.Rotation
		local props = {
			Name = p.name,
			Size = p.size * scale,
			CFrame = at,
			Color = p.color,
			Material = p.material or "SmoothPlastic",
			Transparency = p.transparency or 0,
			Anchored = false,
			Massless = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}
		local part
		if p.text then
			-- BK.sign's readable side is its front (-Z), which is the character's front too.
			part = BK.sign(gear, p.name, at, Vector2.new(p.size.X, p.size.Y) * scale, p.text, { bgColor = p.color })
			part.Anchored = false
			part.Massless = true
		elseif p.shape == "CylinderX" or p.shape == "CylinderY" or p.shape == "CylinderZ" then
			props.Axis = string.sub(p.shape, -1)
			part = BK.cyl(gear, props)
		elseif p.shape == "Egg" then
			part = BK.part(gear, props)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		elseif p.shape == "Ball" then
			part = BK.ball(gear, props)
		else
			part = BK.part(gear, props)
		end
		BK.weld(body, part)
	end

	model.HumanoidRootPart.Anchored = false
	return model
end

return Kit
