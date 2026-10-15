--!nonstrict
-- builders/rigs/Watcher.lua  ->  ServerStorage.DevTools.Builders.Rigs.Watcher
-- docs/10_titans.md §3, docs/08_rigs_and_animation.md §5.3; D-047 (the Watcher is the user's AttackTitan), D-091.
--
--   Build({ BK = BK })  -> stats     builds ServerStorage.Templates.Titans.Watcher
--   copy(BK, { name, leaveOut? }) -> model, info      the rigged copy alone (unparented), for builders/rigs/Shifter;
--                                    leaveOut(part) -> true drops a part as well; info = { main, jointAt, hrp, top, low }
--
-- The Watcher is the user's own Titan model (ServerStorage.Reference.AttackTitan, 80 studs), used as it is: its
-- hair, ears, eyes and wrist bands stay (Q-015). The reference is never changed; this builds a copy the Pose
-- Animator can drive, the way builders/rigs/Strider does with the same body:
--   * the copy is turned to face -Z and stood on the ground (no resizing: it is already 80 studs),
--   * its invisible hit parts (Eyes, Nape) and its old root are left out (the Watcher is never hit),
--   * its joints are rebuilt as clean, named Motor6Ds (the Frame names, as on the Strider),
--   * every part is welded inside its body part; only the new root is anchored. The server places the root
--     (Server/Titans/Watcher) and each client animates the joints.

local Builder = {}

local V = Vector3.new

Builder.HRP_SIZE = V(14, 14, 8)

-- Joint name -> the two parts it connects, as named in an R15 body (as in builders/rigs/Strider).
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

local function abs(v)
	return V(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

function Builder.copy(BK, opts)
	local ServerStorage = game:GetService("ServerStorage")
	local reference = ServerStorage:FindFirstChild("Reference") and ServerStorage.Reference:FindFirstChild("AttackTitan")
	if not reference then
		error("Watcher builder: ServerStorage.Reference.AttackTitan (the user's Titan model) is missing")
	end
	local source = reference:Clone()

	-- 1. Face -Z (its invisible Eyes part sits in front of the head).
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

	-- 2. The main parts and where the joints are; which main part every other part belongs to.
	local main, jointAt = { Head = sourceHead, HumanoidRootPart = source.HumanoidRootPart }, {}
	local links = {}
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
			error("Watcher builder: the reference has no joint " .. name)
		end
	end
	local owner = {}
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

	-- 3. Leave out the hit parts and the old root (and whatever opts.leaveOut names); everything visible stays.
	local kept = {}
	for _, part in ipairs(parts) do
		local isMain = main[owner[part] or ""] == part
		if (part.Transparency >= 1 and not isMain) or part == main.HumanoidRootPart or (not isMain and opts.leaveOut and opts.leaveOut(part)) then
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
			table.insert(kept, part)
		end
	end
	parts = kept

	-- 4. Stand it on the ground.
	local low, top = math.huge, -math.huge
	for _, part in ipairs(parts) do
		local half = abs(part.CFrame.YVector):Dot(part.Size) / 2
		low = math.min(low, part.Position.Y - half)
		top = math.max(top, part.Position.Y + half)
	end
	for _, part in ipairs(parts) do
		part.CFrame -= V(0, low, 0)
	end
	for name, position in pairs(jointAt) do
		jointAt[name] = position - V(0, low, 0)
	end

	-- 5. A clean rig: main parts in the model, everything else welded inside its main part, named joints.
	local model = Instance.new("Model")
	model.Name = opts.name
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
		Name = "HumanoidRootPart", Size = Builder.HRP_SIZE, CFrame = CFrame.new(jointAt.Root), Transparency = 1,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})
	main.HumanoidRootPart = hrp
	model.PrimaryPart = hrp
	for name, pair in pairs(JOINTS) do
		local part0, part1, position = main[pair[1]], main[pair[2]], jointAt[name]
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0, motor.Part1 = part0, part1
		motor.C0 = part0.CFrame:ToObjectSpace(CFrame.new(position))
		motor.C1 = part1.CFrame:ToObjectSpace(CFrame.new(position))
		motor.Parent = part1
	end
	source:Destroy()
	return model, { main = main, jointAt = jointAt, hrp = hrp, top = top, low = low }
end

function Builder.Build(opts)
	local BK = opts.BK
	local startClock = os.clock()
	local templates = BK.folder(BK.folder(game:GetService("ServerStorage"), "Templates"), "Titans")
	local old = templates:FindFirstChild("Watcher")
	if old then
		old:Destroy()
	end
	local model, info = Builder.copy(BK, { name = "Watcher" })
	-- Class = its pose set (Shared/Poses/Watcher); PivotToFeet = the root's height above its feet, so the server
	-- can stand it on a ground point. No TitanType: it isn't a fighting Titan (lock-on, barks and the Titan HUD
	-- and effects pass it by).
	BK.attr(model, { Class = "Watcher", PivotToFeet = info.hrp.Position.Y, Height = info.top - info.low })
	model.Parent = templates
	local stats = BK.report(model, startClock)
	stats.height = info.top - info.low
	stats.hipHeight = info.hrp.Position.Y
	return stats
end

return Builder
