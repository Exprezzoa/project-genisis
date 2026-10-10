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

-- Standard pilot harness (docs/03): straps, chest plate, collar ring, belt and buckle.
function Kit.pilotHarness()
	return {
		piece("UpperTorso", "Harness_StrapL", V(0.25, 2.2, 0.15), CFrame.new(-0.55, 0.1, -0.53), STRAP),
		piece("UpperTorso", "Harness_StrapR", V(0.25, 2.2, 0.15), CFrame.new(0.55, 0.1, -0.53), STRAP),
		piece("UpperTorso", "Harness_ChestPlate", V(1.4, 0.9, 0.25), CFrame.new(0, 0.2, -0.6), PLATE, { material = "Metal" }),
		piece("UpperTorso", "Harness_Collar", V(1.3, 0.35, 1.3), CFrame.new(0, 0.9, 0), GLOVE, { shape = "CylinderY" }),
		piece("LowerTorso", "Harness_Belt", V(2.05, 0.25, 1.05), CFrame.new(0, 0, 0), STRAP),
		piece("LowerTorso", "Harness_Buckle", V(0.35, 0.25, 0.1), CFrame.new(0, 0, -0.55), AMBER, { material = "Neon" }),
	}
end

-- Thin Neon piping down the outer arms and legs (0.06 wide, 30% transparency).
function Kit.piping(color)
	local list = {}
	for _, limb in ipairs({ { "UpperArm", 1.24, 0.52 }, { "LowerArm", 1.12, 0.52 }, { "UpperLeg", 1.36, 0.51 }, { "LowerLeg", 1.3, 0.5 } }) do
		for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
			table.insert(list, piece(side[1] .. limb[1], "Piping_" .. side[1] .. limb[1], V(0.06, limb[2], 0.06), CFrame.new(side[2] * limb[3], 0, 0), color, { material = "Neon", transparency = 0.3 }))
		end
	end
	return list
end

-- Rank bars on the left upper arm (Pilot Officer 1, Lieutenant 2, Captain 3).
function Kit.rankBars(count)
	local list = {}
	for i = 1, count do
		table.insert(list, piece("LeftUpperArm", "Rank_Bar" .. i, V(0.05, 0.08, 0.3), CFrame.new(-0.53, 0.35 - (i - 1) * 0.14, 0), AMBER, { material = "Neon" }))
	end
	return list
end

-- Division patch on the right upper arm.
function Kit.divisionPatch()
	return {
		piece("RightUpperArm", "Patch_Base", V(0.05, 0.5, 0.5), CFrame.new(0.52, 0.15, 0), PLATE),
		piece("RightUpperArm", "Patch_Bar", V(0.05, 0.08, 0.3), CFrame.new(0.55, 0.15, 0), AMBER),
	}
end

-- Squad tag on the chest plate: amber Michroma text.
function Kit.chestTag(text)
	return { piece("UpperTorso", "ChestTag", V(0.9, 0.26, 0.1), CFrame.new(0, 0.3, -0.76), "#3B4A5A", { text = text }) }
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
		elseif p.shape == "CylinderY" then
			props.Axis = "Y"
			part = BK.cyl(gear, props)
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
