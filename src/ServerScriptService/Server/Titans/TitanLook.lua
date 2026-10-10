--!nonstrict
-- Server/Titans/TitanLook.lua  (docs/10_titans.md "Look direction", D-039, D-056)
--
-- What makes one Titan look different from the next: a human skin tone and a head of hair, both picked from
-- a seed. The rig builders mark skin parts with the attribute Skin; the hair accessories are stored (already
-- checked, loaded and measured at build time) in ServerStorage.Templates.TitanHair.
-- No dependencies, so the builders and edit-mode tools can require a clone of this module too.
--
--   dress(model, seed) -> { skin = Color3, hair = string? }
--   setSkin(model, color)        setHair(model, accessoryOrNil)

local ServerStorage = game:GetService("ServerStorage")

local TitanLook = {}

-- Human skin tones (docs/06 §3 "Titan skin"). The first is the tone of the user's own Titan model.
TitanLook.SKIN_TONES = {
	Color3.fromHex("#EAB892"), Color3.fromHex("#F0C9A8"), Color3.fromHex("#D9A47C"), Color3.fromHex("#C68E6A"), Color3.fromHex("#A8704F"),
}

function TitanLook.setSkin(model, color)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Skin") then
			descendant.Color = color
		end
	end
	model:SetAttribute("SkinTone", color)
end

-- Puts a copy of a hair accessory on the Titan's head, grown to the Titan's size. nil removes the hair.
-- The accessory carries how it sits on an ordinary head (FitSize, FitOffset, FitMeshScale, in head widths:
-- measured by the rig builder); the Titan carries HeadWidth and a HairAnchor at the center of its head.
function TitanLook.setHair(model, accessory)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Hair")
	if old then
		old:Destroy()
	end
	model:SetAttribute("Hair", nil)
	local source = accessory and accessory:FindFirstChild("Handle")
	local anchor = head:FindFirstChild("HairAnchor")
	local fitSize, fitOffset = accessory and accessory:GetAttribute("FitSize"), accessory and accessory:GetAttribute("FitOffset")
	local headWidth = model:GetAttribute("HeadWidth")
	if not (source and anchor and fitSize and fitOffset and headWidth) then
		return
	end
	local handle = source:Clone()
	handle.Name = "Hair"
	for _, descendant in ipairs(handle:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("LuaSourceContainer") or descendant:IsA("Attachment")
			or descendant:IsA("WrapLayer") or descendant:IsA("TouchTransmitter") then
			descendant:Destroy()
		elseif descendant:IsA("SpecialMesh") then
			descendant.Scale = (accessory:GetAttribute("FitMeshScale") or descendant.Scale / headWidth) * headWidth
		end
	end
	handle.Size = fitSize * headWidth
	handle.Anchored, handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, false, true
	handle.CFrame = head.CFrame * anchor.CFrame * CFrame.new(fitOffset * headWidth)
	handle.Parent = head
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = head, handle
	weld.Parent = handle
	model:SetAttribute("Hair", accessory.Name)
end

-- A skin tone and a hair style from the seed (the same seed always gives the same Titan).
function TitanLook.dress(model, seed)
	local random = Random.new(seed or 0)
	local skin = TitanLook.SKIN_TONES[random:NextInteger(1, #TitanLook.SKIN_TONES)]
	TitanLook.setSkin(model, skin)
	local templates = ServerStorage:FindFirstChild("Templates")
	local folder = templates and templates:FindFirstChild("TitanHair")
	local styles = folder and folder:GetChildren() or {}
	table.sort(styles, function(a, b)
		return a.Name < b.Name
	end)
	local hair = styles[1] and styles[random:NextInteger(1, #styles)]
	TitanLook.setHair(model, hair)
	return { skin = skin, hair = hair and hair.Name }
end

return TitanLook
