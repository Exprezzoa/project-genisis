--!nonstrict
-- builders/rigs/Strider.lua  ->  ServerStorage.DevTools.Builders.Rigs.Strider
-- docs/10_titans.md §1 and "Look direction" (D-039, D-056), docs/08_rigs_and_animation.md §2, §3.2.
--
--   Build({ BK = BK })      -> stats     builds ServerStorage.Templates.Titans.Strider (no hair, first skin tone)
--   BuildHair({ BK = BK })  -> report    loads the checked hair accessories into ServerStorage.Templates.TitanHair
--                                        (run it before Build when the hair list changes)
--   Builder.HAIR                         the hair list; every ID came out of a catalog search run through Studio
--
-- Titans look like giant people (user direction). The Strider is made from the body of the user's own Titan
-- model (ServerStorage.Reference.AttackTitan: an R15 body with sculpted muscle), not from parts:
--   * the copy is turned to face -Z and stood on the ground,
--   * what belongs to the user's Shifter only (hair, pointed ears, the pale blue bands, its hit parts) is left out,
--   * it is made lanky: narrower, with arms 1.3 times as long, then sized to 56 studs,
--   * its joints are rebuilt as the clean, named Motor6Ds the Pose Animator drives (same names as a Frame's),
--   * the feral Titan's own marks are added from parts: orange-red eyes, a grin of teeth, the Dorsal Core
--     under two hinged bone plates, a glowing vein down each forearm.
-- Hair and skin tone are put on per Titan at spawn (Server/Titans/TitanLook).

local Builder = {}

local V = Vector3.new
local rad = math.rad

Builder.HEIGHT = 56 -- studs, ground to the top of the head (docs/10 §1)
Builder.NARROW = V(0.8, 1, 0.86) -- the body's width and depth against the reference (the head keeps its shape)
Builder.ARM_LENGTH = 1.3
Builder.HRP = { V(10, 10, 6), V(0, 29.5, 0) } -- docs/08 §3.2

-- { name, catalog id }: free hair by Roblox, natural colors. Every ID came out of
-- AvatarEditorService:SearchCatalog (HairAccessory, creator Roblox) run through Studio on 2026-10-10, and each
-- was put on an avatar there. Only rigid hair is listed: newer "layered" hair is bent onto the head by the
-- engine's cage system, which a Titan's sculpted head doesn't have (it would sit at the chest, half as wide).
Builder.HAIR = {
	{ "PalHair", 63690008 }, { "StraightBlonde", 376526888 }, { "BlondeSpiked", 376524487 }, { "BlackPonytail", 376527350 },
	{ "BrownCharmer", 376548738 }, { "BrownHair", 62234425 }, { "BeautifulHair", 16630147 }, { "BeautifulBrown", 17877340 },
	{ "MessyHair", 26658141 }, { "Roblohunk", 15913837 }, { "Cinnamon", 13745548 }, { "RockStarSideSwept", 20010032 },
	{ "ChestnutStyle", 212967757 }, { "BedHair", 20372960 }, { "GoldenHair", 13476917 }, { "Shaggy", 20573078 },
	{ "BlondeCharmer", 80921949 }, { "NormalBoy", 13477818 }, { "BlackLongStraight", 1772372988 }, { "BelleLongRed", 2956239660 },
	{ "AuburnScene", 62246484 }, { "BrownScene", 323476364 }, { "BlackMangaHero", 398672920 }, { "CoolSideShave", 3814474927 },
}

-- Joint name -> the two parts it connects, as named in an R15 body.
local JOINTS = {
	Root = { "HumanoidRootPart", "LowerTorso" }, Waist = { "LowerTorso", "UpperTorso" }, Neck = { "UpperTorso", "Head" },
}
for _, side in ipairs({ "Left", "Right" }) do
	JOINTS[side .. "Shoulder"] = { "UpperTorso", side .. "UpperArm" }
	JOINTS[side .. "Elbow"] = { side .. "UpperArm", side .. "LowerArm" }
	JOINTS[side .. "Wrist"] = { side .. "LowerArm", side .. "Hand" }
	JOINTS[side .. "Hip"] = { "LowerTorso", side .. "UpperLeg" }
	JOINTS[side .. "Knee"] = { side .. "UpperLeg", side .. "LowerLeg" }
	JOINTS[side .. "Ankle"] = { side .. "LowerLeg", side .. "Foot" }
end
Builder.JOINTS = JOINTS

local SKIN = { ["eab892"] = true, ["ffcc99"] = true }

local function abs(v)
	return V(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

function Builder.Build(opts)
	local BK = opts.BK
	local P = BK.Palette
	local startClock = os.clock()
	local ServerStorage = game:GetService("ServerStorage")
	local reference = ServerStorage:FindFirstChild("Reference") and ServerStorage.Reference:FindFirstChild("AttackTitan")
	if not reference then
		error("Strider builder: ServerStorage.Reference.AttackTitan (the user's Titan model) is missing")
	end
	local source = reference:Clone()

	----------------------------------------------------------------------------------------------------------------
	-- 1. Face -Z, stand on the ground
	----------------------------------------------------------------------------------------------------------------
	local sourceHead, sourceEyes = source.Head, source.Eyes
	local front = ((sourceEyes.Position - sourceHead.Position) * V(1, 0, 1)).Unit
	local toRig = CFrame.lookAt(sourceHead.Position * V(1, 0, 1), sourceHead.Position * V(1, 0, 1) + front):Inverse()
	local parts = {}
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CFrame = toRig * descendant.CFrame
			table.insert(parts, descendant)
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- 2. The main parts and where the joints are; which main part every other part belongs to
	----------------------------------------------------------------------------------------------------------------
	local main, jointAt = { Head = sourceHead, HumanoidRootPart = source.HumanoidRootPart }, {}
	local links = {} -- rigid connections between parts (welds, unnamed motors)
	local function link(a, b)
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], b)
		table.insert(links[b], a)
	end
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("JointInstance") and descendant.Part0 and descendant.Part1 then
			local pair = JOINTS[descendant.Name]
			if descendant:IsA("Motor6D") and pair then
				main[pair[1]], main[pair[2]] = main[pair[1]] or descendant.Part0, descendant.Part1
				jointAt[descendant.Name] = (descendant.Part0.CFrame * descendant.C0).Position
			elseif descendant:IsA("Motor6D") and descendant.Part0.Name == "UpperTorso" and descendant.Part1 == sourceHead then
				jointAt.Neck = (descendant.Part0.CFrame * descendant.C0).Position
			else
				link(descendant.Part0, descendant.Part1)
			end
		end
	end
	for name in pairs(JOINTS) do
		if not jointAt[name] then
			error("Strider builder: the reference has no joint " .. name)
		end
	end
	local owner = {} -- [part] = name of its main part
	local queue = {}
	for name, part in pairs(main) do
		owner[part] = name
		table.insert(queue, part)
	end
	for _, part in ipairs(parts) do -- a part inside another part goes with it
		if part.Parent and part.Parent:IsA("BasePart") then
			link(part, part.Parent)
		end
	end
	while #queue > 0 do
		local part = table.remove(queue)
		for _, other in ipairs(links[part] or {}) do
			if not owner[other] then
				owner[other] = owner[part]
				table.insert(queue, other)
			end
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- 3. Leave out what is the Shifter's own; mark the skin
	----------------------------------------------------------------------------------------------------------------
	local kept = {}
	for _, part in ipairs(parts) do
		local isMain = main[owner[part] or ""] == part
		local shifterOnly = part.Material == Enum.Material.Ice or part.Name == "Ears" or part.Name == "Handle"
			or (part.Transparency >= 1 and not isMain) or part == main.HumanoidRootPart
		if shifterOnly then
			part.Parent = nil
		else
			if not owner[part] then -- nothing held it: give it to the nearest main part
				local best, distance = nil, math.huge
				for name, candidate in pairs(main) do
					local d = (candidate.Position - part.Position).Magnitude
					if name ~= "HumanoidRootPart" and d < distance then
						best, distance = name, d
					end
				end
				owner[part] = best
			end
			if SKIN[part.Color:ToHex()] then
				part:SetAttribute("Skin", true)
			end
			table.insert(kept, part)
		end
	end
	parts = kept

	----------------------------------------------------------------------------------------------------------------
	-- 4. Proportions: lanky, long-armed, 56 studs
	----------------------------------------------------------------------------------------------------------------
	-- Scales parts by `scale` (world axes) about `pivot`; joints listed in `joints` move the same way.
	local function resize(group, scale, pivot, joints)
		for _, part in ipairs(group) do
			local frame = part.CFrame
			local localScale = V(abs(frame.XVector):Dot(scale), abs(frame.YVector):Dot(scale), abs(frame.ZVector):Dot(scale))
			part.Size *= localScale
			part.CFrame = frame.Rotation + (pivot + (frame.Position - pivot) * scale)
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Attachment") then
					child.Position *= localScale
				elseif child:IsA("SpecialMesh") then
					child.Scale *= localScale
				end
			end
		end
		for _, name in ipairs(joints) do
			jointAt[name] = pivot + (jointAt[name] - pivot) * scale
		end
	end
	local function groupOf(names)
		local wanted, group = {}, {}
		for _, name in ipairs(names) do
			wanted[name] = true
		end
		for _, part in ipairs(parts) do
			if wanted[owner[part]] then
				table.insert(group, part)
			end
		end
		return group
	end
	local allJoints, bodyNames = {}, {}
	for name in pairs(JOINTS) do
		table.insert(allJoints, name)
	end
	for name in pairs(main) do
		if name ~= "Head" and name ~= "HumanoidRootPart" then
			table.insert(bodyNames, name)
		end
	end
	local low = math.huge
	for _, part in ipairs(parts) do
		low = math.min(low, part.Position.Y - abs(part.CFrame.YVector):Dot(part.Size) / 2)
	end
	for _, part in ipairs(parts) do
		part.CFrame -= V(0, low, 0)
	end
	for name, position in pairs(jointAt) do
		jointAt[name] = position - V(0, low, 0)
	end
	-- Narrow the body; the head only moves with the neck.
	local neckBefore = jointAt.Neck
	resize(groupOf(bodyNames), Builder.NARROW, V(0, 0, 0), allJoints)
	local headShift = jointAt.Neck - neckBefore
	for _, part in ipairs(groupOf({ "Head" })) do
		part.CFrame += headShift
	end
	-- Long arms: stretched downward from the shoulder.
	for _, side in ipairs({ "Left", "Right" }) do
		local shoulder = jointAt[side .. "Shoulder"]
		resize(groupOf({ side .. "UpperArm", side .. "LowerArm", side .. "Hand" }), V(1, Builder.ARM_LENGTH, 1), shoulder, { side .. "Elbow", side .. "Wrist" })
	end
	-- 56 studs to the top of the head.
	local top = main.Head.Position.Y + main.Head.Size.Y / 2
	local grow = Builder.HEIGHT / top
	resize(parts, V(grow, grow, grow), V(0, 0, 0), allJoints)

	----------------------------------------------------------------------------------------------------------------
	-- 5. A clean rig: main parts in the model, everything else welded inside its main part, named joints
	----------------------------------------------------------------------------------------------------------------
	local templates = BK.folder(BK.folder(ServerStorage, "Templates"), "Titans")
	local old = templates:FindFirstChild("Strider")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Strider"
	-- For the hair (TitanLook.setHair): the head's width, and an anchor at its center that faces the rig's front
	-- (the head part of the reference is turned back to front).
	BK.attr(model, { Class = "Strider", HeadWidth = main.Head.Size.X })
	local anchor = Instance.new("Attachment")
	anchor.Name = "HairAnchor"
	anchor.CFrame = main.Head.CFrame:ToObjectSpace(CFrame.new(main.Head.Position))
	anchor.Parent = main.Head

	for _, part in ipairs(parts) do
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("LuaSourceContainer") or child:IsA("ValueBase") then
				child:Destroy()
			end
		end
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
	end
	for name, part in pairs(main) do
		if name ~= "HumanoidRootPart" then
			part.Name = name
			part.Parent = model
		end
	end
	for _, part in ipairs(parts) do
		local bone = main[owner[part]]
		if part ~= bone then
			part.Parent = bone
			BK.weld(bone, part)
		end
	end
	local hrp = BK.part(model, {
		Name = "HumanoidRootPart", Size = Builder.HRP[1], CFrame = CFrame.new(jointAt.Root.X, Builder.HRP[2].Y, jointAt.Root.Z), Transparency = 1,
		Anchored = false, CanCollide = true, CanQuery = false, CanTouch = false, Massless = false, CastShadow = false,
	})
	hrp.RootPriority = 127
	hrp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	main.HumanoidRootPart = hrp
	model.PrimaryPart = hrp
	local function joint(name, part0, part1, position)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0, motor.Part1 = part0, part1
		motor.C0 = part0.CFrame:ToObjectSpace(CFrame.new(position))
		motor.C1 = part1.CFrame:ToObjectSpace(CFrame.new(position))
		motor.Parent = part1
		return motor
	end
	for name, pair in pairs(JOINTS) do
		joint(name, main[pair[1]], main[pair[2]], jointAt[name])
	end

	----------------------------------------------------------------------------------------------------------------
	-- 6. The feral Titan's own marks (parts; positions measured on the finished body)
	----------------------------------------------------------------------------------------------------------------
	local function extent(names)
		local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
		for _, part in ipairs(groupOf(names)) do
			local half = V(abs(part.CFrame.XVector):Dot(part.Size), abs(part.CFrame.YVector):Dot(part.Size), abs(part.CFrame.ZVector):Dot(part.Size)) / 2
			lo, hi = lo:Min(part.Position - half), hi:Max(part.Position + half)
		end
		return lo, hi
	end
	local function add(on, kind, props)
		props.Anchored, props.CanCollide, props.CanQuery, props.CanTouch, props.Massless = false, false, false, false, true
		local part = BK[kind](on, props)
		BK.weld(on, part)
		return part
	end

	-- Eyes: feral orange-red.
	for _, part in ipairs(groupOf({ "Head" })) do
		if part.Material == Enum.Material.Neon then
			part.Color = BK.toColor(P.TITAN_GLOW)
			part:AddTag("TitanGlow")
		end
	end
	-- The grin: a dark slit with a row of teeth, low on the face. The face's surface was measured with ray
	-- casts on the first build: at mouth height it lies at z = (-0.475 + 1.6 fx^2) x the head's depth, where fx
	-- is the sideways position as a share of the head's width.
	local head = main.Head
	local width, height, depth = head.Size.X, head.Size.Y, head.Size.Z
	for index = -3, 3 do
		local fx = index / 3 * 0.2
		local surface = head.Position + V(fx * width, (-0.27 + 0.9 * fx * fx) * height, (-0.475 + 1.6 * fx * fx) * depth)
		local turn = CFrame.Angles(0, -math.atan(3.2 * fx * depth / width), 0)
		add(head, "part", { Name = "Mouth", Size = V(width * 0.075, height * 0.085, 0.5), CFrame = CFrame.new(surface) * turn, Color = P.STR_SOCKET, CastShadow = false })
		add(head, "part", {
			Name = "Tooth", Size = V(width * 0.055, height * 0.055, 0.5), CFrame = CFrame.new(surface + V(0, height * 0.008, 0)) * turn * CFrame.new(0, 0, -0.15),
			Color = P.STR_TEETH, CastShadow = false,
		})
	end
	-- Titans wear a wrap of dark cloth round the hips.
	main.LowerTorso.Color = BK.toColor(P.KICKPLATE)
	main.LowerTorso.Material = Enum.Material.Fabric

	-- Dorsal Core: a glowing orb in a dark socket between the shoulder blades, under two hinged bone plates.
	local chest = main.UpperTorso
	local _, chestHi = extent({ "UpperTorso" })
	local coreAt = V(chest.Position.X, chest.Position.Y + chest.Size.Y * 0.18, chestHi.Z - 0.6)
	add(chest, "cyl", { Name = "CoreSocket", Axis = "Z", Size = V(5.4, 5.4, 0.8), CFrame = CFrame.new(coreAt), Color = P.STR_SOCKET })
	local orb = add(chest, "ball", { Name = "CoreOrb", Size = V(4, 4, 4), CFrame = CFrame.new(coreAt + V(0, 0, 0.2)), Color = P.TITAN_GLOW, Material = "Neon", Tags = { "TitanGlow" } })
	BK.light(orb, "Point", { Name = "CoreGlow", Color = P.TITAN_GLOW, Brightness = 0.8, Range = 14 })
	for _, side in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local plate = BK.part(model, {
			Name = "CorePlate" .. side[1], Size = V(4.2, 6.4, 1), CFrame = CFrame.new(coreAt + V(2.05 * side[2], 0, 1.3)), Color = P.STR_BONE, Material = "Limestone",
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
		})
		main["CorePlate" .. side[1]] = plate
		-- Hinged on its outer edge: turning about Y swings it open.
		joint("CoreHinge" .. side[1], chest, plate, coreAt + V(4.15 * side[2], 0, 1.3))
		add(plate, "part", { Name = "PlateRidge", Size = V(0.5, 5.6, 0.4), CFrame = plate.CFrame * CFrame.new(-0.9 * side[2], 0, 0.6), Color = P.STR_BONE, Material = "Limestone" })
	end

	-- A vein of glow down the outside of each forearm (bright during the Sweep telegraph, docs/10 §1.4).
	for _, side in ipairs({ { "Left", -1 }, { "Right", 1 } }) do
		local arm = main[side[1] .. "LowerArm"]
		local armLo, armHi = extent({ side[1] .. "LowerArm" })
		local x = if side[2] < 0 then armLo.X else armHi.X
		add(arm, "part", {
			Name = "VeinGlow", Size = V(0.3, arm.Size.Y * 0.8, 0.3), CFrame = CFrame.new(x - 0.1 * side[2], arm.Position.Y, arm.Position.Z), Color = P.TITAN_GLOW_DEEP,
			Material = "Neon", Transparency = 0.6, CastShadow = false, Tags = { "TitanGlow", "VeinGlow" },
		})
	end

	----------------------------------------------------------------------------------------------------------------
	-- 7. Humanoid (docs/08 §2.6: the Pose Animator owns the joints, so no Animator)
	----------------------------------------------------------------------------------------------------------------
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hrp.Position.Y - hrp.Size.Y / 2
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxSlopeAngle = 50
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local TitanLook = require(game:GetService("ServerScriptService").Server.Titans.TitanLook:Clone())
	TitanLook.setSkin(model, TitanLook.SKIN_TONES[1])
	model.Parent = templates
	source:Destroy()
	local stats = BK.report(model, startClock)
	stats.height = top * grow
	stats.headWidth = model:GetAttribute("HeadWidth")
	stats.joints = jointAt
	return stats
end

-- Has the engine put every hair of Builder.HAIR on an ordinary avatar once, reads from the accessory's weld
-- how it sits on that head, and keeps the accessory in ServerStorage.Templates.TitanHair with the measurements
-- as attributes, all in units of the head's width: FitSize (the handle's size), FitOffset (its center from the
-- head's center) and, for hair made of a Part and a mesh, FitMeshScale. TitanLook.setHair multiplies them by a
-- Titan's head width. An ID that doesn't load as rigid hair is reported and left out.
function Builder.BuildHair(opts)
	local BK = opts.BK
	local ServerStorage = game:GetService("ServerStorage")
	local Players = game:GetService("Players")
	local folder = BK.folder(BK.folder(ServerStorage, "Templates"), "TitanHair", true)
	local report = { loaded = {}, failed = {} }
	for _, entry in ipairs(Builder.HAIR) do
		local name, id = entry[1], entry[2]
		local ok, result = pcall(function()
			local description = Instance.new("HumanoidDescription")
			description.HairAccessory = tostring(id)
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		local accessory = ok and result:FindFirstChildWhichIsA("Accessory", true)
		local handle = accessory and accessory:FindFirstChild("Handle")
		local head = ok and result:FindFirstChild("Head")
		local weld = handle and handle:FindFirstChild("AccessoryWeld")
		if handle and head and weld and not handle:FindFirstChildWhichIsA("WrapLayer") then
			local headWidth = head.Size.X
			-- Handle.CFrame * C0 = Head.CFrame * C1 (the weld's Part0 is the handle).
			local offset = if weld.Part0 == handle then weld.C1 * weld.C0:Inverse() else weld.C0 * weld.C1:Inverse()
			accessory.Name = name
			accessory:SetAttribute("AssetId", id)
			accessory:SetAttribute("FitSize", handle.Size / headWidth)
			accessory:SetAttribute("FitOffset", offset.Position / headWidth)
			local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
			if mesh then
				accessory:SetAttribute("FitMeshScale", mesh.Scale / headWidth)
			end
			accessory.Parent = folder
			table.insert(report.loaded, name)
		else
			table.insert(report.failed, name .. " (" .. id .. "): " .. (if ok then "not rigid hair" else tostring(result)))
		end
		if ok then
			result:Destroy()
		end
	end
	return report
end

return Builder
