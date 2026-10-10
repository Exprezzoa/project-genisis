--!nonstrict
-- builders/maps/hangar/Unit03.lua  ->  DevTools.Builders.Hangar.Unit03
-- docs/09_frames.md §3 "Unit 03": the static repair prop in Bay 3 (map_02 §2). Not a rig: an anchored model
-- with no joints, made from the Vanguard builder's own parts so it matches Units 01 and 02 exactly.
--   * the left arm is off and lies on two floor supports in front of the bay,
--   * the pec plates stand on a rack beside it,
--   * the hatch is off and the core shows through the open chest: a Neon ball with six nodules inside a cage
--     of twelve bars (clue 2: it pulses with a 1.6 s period; the pulse itself is a client effect),
--   * 40% of the armor is unpainted primer, and a scaffold tower stands on each side.

local Builder = {}

local V = Vector3.new
local rad = math.rad

local BAY = V(70, 0, -205) -- FRAME_BAY3, the Frame faces +Z
local ARM = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "PD_Spike" }
local PEC_NAMES = { PecStave = true, PecPlate = true, PecRim = true, PecRimBend = true, PecRidge = true, PecRidgeBend = true }
local NODULE = "#E8963A"

function Builder.Build(opts)
	local C = opts.Common
	local ctx = C.begin(opts, "Hangar", "Unit03", true)
	local BK, P = ctx.BK, ctx.P
	local DT = game:GetService("ServerStorage").DevTools
	local Rig = require(DT.Builders.Rigs.Vanguard:Clone())
	local S = Rig.SCALE

	-- A Vanguard with no accent, built into a scratch folder.
	local scratch = Instance.new("Folder")
	Rig.Build({ BK = BK, unit = "03", variant = {}, parent = scratch })
	local model = scratch:FindFirstChild("Vanguard_03")
	model.Name = "Unit03"
	model:PivotTo(CFrame.new(BAY + V(0, Rig.HRP[2].Y, 0)) * CFrame.Angles(0, math.pi, 0))
	BK.attr(model, { StaticProp = true })

	local function partsOf(root)
		local list = { root }
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(list, descendant)
			end
		end
		return list
	end
	-- Moves a group of parts rigidly: `from` (a CFrame among them) ends up at `to`.
	local function move(parts, from, to)
		for _, part in ipairs(parts) do
			part.CFrame = to * from:ToObjectSpace(part.CFrame)
		end
	end

	local chest = model.UpperTorso
	local chestFrame = chest.CFrame
	local arm = {}
	for _, name in ipairs(ARM) do
		for _, part in ipairs(partsOf(model:FindFirstChild(name, true))) do
			table.insert(arm, part)
		end
	end
	local armFrame = model.LeftUpperArm.CFrame
	local pecs = {}
	for _, child in ipairs(chest:GetChildren()) do
		if child:IsA("BasePart") and PEC_NAMES[child.Name] then
			table.insert(pecs, child)
		end
	end

	-- No rig left: no Humanoid, seat, joints, welds or constraints; everything anchored.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Humanoid") or descendant:IsA("Seat") or descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("Constraint") then
			descendant:Destroy()
		end
	end
	local hatch = model:FindFirstChild("Hatch")
	if hatch then
		hatch:Destroy()
	end
	local well = chest:FindFirstChild("HatchWell")
	if well then
		well:Destroy()
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	-- 40% of the armor in primer (the same plates every build).
	local random = Random.new(3)
	local armor, dark = BK.toColor(P.VG_ARMOR), BK.toColor(P.VG_ARMOR_DARK)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant.Color == armor or descendant.Color == dark) and random:NextNumber() < 0.4 then
			descendant.Color = BK.toColor(P.VG_PRIMER)
		end
	end

	-- The left arm lies along X on two supports in front of the bay, shoulder to the east.
	move(arm, armFrame, CFrame.new(BAY + V(13, 11, 22)) * CFrame.Angles(0, 0, rad(-90)))
	local steel = { Color = P.STEEL_DARK, Material = "Metal" }
	local props = BK.folder(ctx.root, "Props")
	BK.box(props, "ArmSupport1", BAY + V(-6, 0, 17), BAY + V(0, 5.6, 27), steel)
	BK.box(props, "ArmSupport2", BAY + V(10, 0, 17), BAY + V(16, 6.6, 27), steel)
	for index, x in ipairs({ -3, 13 }) do
		BK.box(props, "ArmSupportPad" .. index, BAY + V(x - 3.4, if index == 1 then 5.6 else 6.6, 16.6), BAY + V(x + 3.4, if index == 1 then 6 else 7, 27.4), { Color = P.KICKPLATE })
	end

	-- The pec plates stand on a rack east of the bay, facing west.
	local rackAt = BAY + V(36, 0, 20)
	move(pecs, chestFrame, CFrame.new(rackAt + V(0, 9, 0)) * CFrame.Angles(rad(-12), rad(90), 0))
	BK.box(props, "PecRack_Base", rackAt + V(-4, 0, -16), rackAt + V(6, 0.8, 16), steel)
	for index, z in ipairs({ -15, 15 }) do
		BK.box(props, "PecRack_Post" .. index, rackAt + V(3, 0.8, z - 0.6), rackAt + V(4.2, 22, z + 0.6), steel)
	end
	BK.box(props, "PecRack_Rail", rackAt + V(3, 20.8, -15.6), rackAt + V(4.2, 22, 15.6), steel)
	BK.box(props, "PecRack_Shelf", rackAt + V(-3, 2, -15.6), rackAt + V(4.2, 2.8, 15.6), { Color = P.STEEL_MID, Material = "DiamondPlate" })

	-- The exposed core in the open chest.
	local coreAt = chestFrame * CFrame.new(0, 1.5 * S, -2.6 * S)
	local core = BK.ball(model, {
		Name = "ExposedCore", Size = V(4.5, 4.5, 4.5) * S, CFrame = coreAt, Color = P.AMBER_CORE, Material = "Neon",
		CanCollide = false, CanQuery = false, Tags = { "CoreLight" }, Attributes = { PulsePeriod = 1.6 },
	})
	BK.light(core, "Point", { Name = "CoreGlow", Color = P.AMBER_CORE, Brightness = 1.6, Range = 30 })
	for index = 1, 6 do
		local direction = CFrame.Angles(rad(60 * index + 20), rad(47 * index), 0).LookVector
		local size = (1 + 0.5 * (index % 2)) * S
		BK.ball(model, {
			Name = "CoreNodule" .. index, Size = V(size, size, size), CFrame = coreAt + direction * 2.1 * S, Color = NODULE, Material = "Neon",
			CanCollide = false, CanQuery = false,
		})
	end
	for index = 1, 12 do
		local angle = rad(30 * index)
		local offset = V(math.cos(angle), 0, math.sin(angle)) * 2.9 * S
		BK.part(model, {
			Name = "InhibitorBar" .. index, Size = V(0.2, 6, 0.2) * S, CFrame = coreAt * CFrame.new(offset), Color = P.STEEL_LIGHT, Material = "Metal",
			CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end
	for index, y in ipairs({ -2.9, 2.9 }) do
		BK.cyl(model, {
			Name = "InhibitorRing" .. index, Axis = "Y", Size = V(6, 0.25, 6) * S, CFrame = coreAt * CFrame.new(0, y * S, 0), Color = P.STEEL_LIGHT,
			Material = "Metal", CanCollide = false, CanQuery = false, CastShadow = false,
		})
	end

	-- A scaffold tower on each side of the Frame: four posts, a deck every 13 studs, a brace on the outside.
	for _, side in ipairs({ { "W", -30 }, { "E", 30 } }) do
		local name, x = side[1], BAY.X + side[2]
		local x1, x2 = x - 2, x + 2
		local z1, z2 = BAY.Z - 9, BAY.Z + 9
		for _, corner in ipairs({ { x1, z1 }, { x2, z1 }, { x1, z2 }, { x2, z2 } }) do
			BK.box(props, "Scaffold" .. name .. "_Post", V(corner[1] - 0.4, 0, corner[2] - 0.4), V(corner[1] + 0.4, 53, corner[2] + 0.4), steel)
		end
		for level = 1, 4 do
			local y = 13 * level
			BK.box(props, "Scaffold" .. name .. "_Deck" .. level, V(x1 - 0.4, y - 0.5, z1 - 0.4), V(x2 + 0.4, y, z2 + 0.4), ctx.DECK)
			BK.box(props, "Scaffold" .. name .. "_Rail" .. level, V(x1 - 0.4, y + 3.2, z1 - 0.4), V(x1, y + 3.5, z2 + 0.4), steel)
			BK.box(props, "Scaffold" .. name .. "_Rail" .. level, V(x2, y + 3.2, z1 - 0.4), V(x2 + 0.4, y + 3.5, z2 + 0.4), steel)
			BK.beam(props, "Scaffold" .. name .. "_Brace" .. level, V(x, y - 13, z1 - 0.4), V(x, y - 0.5, z2 + 0.4), 0.4, 0.4, { Color = P.STEEL_DARK, Material = "Metal", CanCollide = false })
		end
	end

	model.Parent = ctx.root
	scratch:Destroy()
	return C.finish(ctx)
end

return Builder
