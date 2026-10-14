--!nonstrict
-- Server/Titans/WatcherStandIn.lua  (docs/05_chapter1_script.md S31; docs/maps/map_03 §13; roadmap Phase 4)
--
-- The Watcher of S31 before its rig and animation exist (Phase 5): the stored Watcher model (the user's
-- AttackTitan, D-047), anchored, slid along its route by the server. It can't be hit, locked onto or pushed.
--
--   spawn(groundCFrame) -> model        walk(model, points, seconds)      (yields)
--   face(model, point, seconds)         (yields)                          take(model, part)
--   peel(panel, degrees, seconds)       (yields)                          close(panel)        despawn(model)

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local WatcherStandIn = {}

local HEIGHT = 80 -- CLAUDE.md §7

function WatcherStandIn.spawn(groundCFrame)
	local reference = ServerStorage:FindFirstChild("Reference") and ServerStorage.Reference:FindFirstChild("AttackTitan")
	local model
	if reference then
		model = reference:Clone()
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored, descendant.CanCollide, descendant.CanQuery, descendant.CanTouch = true, false, false, false
			elseif descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	else
		-- No stored model: a plain dark figure of the right height.
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(26, HEIGHT, 14)
		body.Color = Color3.fromHex("#3B3A3F")
		body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch = true, false, false, false
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = "Watcher"
	-- Where the model's pivot sits above its feet, so it can be stood on a ground point.
	local box, size = model:GetBoundingBox()
	model:SetAttribute("PivotToFeet", model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2))
	-- The stored model faces along its pivot's look direction (its eyes are 12 studs ahead of the head along it),
	-- like the fallback box: no extra turn. `Turn` stays for a model that faces elsewhere.
	model:SetAttribute("Turn", 0)
	WatcherStandIn.place(model, groundCFrame)
	model.Parent = workspace:FindFirstChild("Titans") or workspace
	return model
end

function WatcherStandIn.place(model, groundCFrame)
	local lift = model:GetAttribute("PivotToFeet") or 0
	model:PivotTo(CFrame.new(groundCFrame.Position + Vector3.new(0, lift, 0)) * groundCFrame.Rotation * CFrame.Angles(0, model:GetAttribute("Turn") or 0, 0))
end

-- Slides the model through the ground points at an even pace, facing where it goes.
function WatcherStandIn.walk(model, points, seconds)
	local from = model:GetPivot().Position - Vector3.new(0, model:GetAttribute("PivotToFeet") or 0, 0)
	local path, total = { from }, 0
	for _, point in ipairs(points) do
		total += (point - path[#path]).Magnitude
		table.insert(path, point)
	end
	if total < 0.1 then
		return
	end
	local started = os.clock()
	while model.Parent do
		local travelled = math.min(1, (os.clock() - started) / seconds) * total
		local index = 1
		while index < #path - 1 and travelled > (path[index + 1] - path[index]).Magnitude do
			travelled -= (path[index + 1] - path[index]).Magnitude
			index += 1
		end
		local a, b = path[index], path[index + 1]
		local leg = (b - a).Magnitude
		local position = a:Lerp(b, if leg > 0 then math.clamp(travelled / leg, 0, 1) else 1)
		local heading = (b - a) * Vector3.new(1, 0, 1)
		WatcherStandIn.place(model, CFrame.lookAt(position, position + (if heading.Magnitude > 0.1 then heading.Unit else Vector3.zAxis)))
		if os.clock() - started >= seconds then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- Turns on the spot until it looks at `point` (yaw only), at an even pace (docs/05 S31 beat 6).
function WatcherStandIn.face(model, point, seconds)
	local lift = model:GetAttribute("PivotToFeet") or 0
	local turn = CFrame.Angles(0, model:GetAttribute("Turn") or 0, 0)
	local pivot = model:GetPivot() * turn:Inverse()
	local feet = pivot.Position - Vector3.new(0, lift, 0)
	local from = pivot.LookVector * Vector3.new(1, 0, 1)
	local to = (point - feet) * Vector3.new(1, 0, 1)
	if from.Magnitude < 0.01 or to.Magnitude < 0.01 then
		return
	end
	local a, b = math.atan2(-from.X, -from.Z), math.atan2(-to.X, -to.Z)
	local delta = (b - a + math.pi) % (2 * math.pi) - math.pi
	local started = os.clock()
	while model.Parent do
		local alpha = math.min(1, (os.clock() - started) / math.max(seconds, 0.01))
		local yaw = a + delta * (1 - (1 - alpha) ^ 2)
		WatcherStandIn.place(model, CFrame.new(feet) * CFrame.Angles(0, yaw, 0))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- The Watcher takes something small in its right hand (the T-V canister, docs/05 S31 beat 5): the part goes into
-- the model, so it moves and leaves with it.
function WatcherStandIn.take(model, part)
	local hand = model:FindFirstChild("RightHand") or model.PrimaryPart
	if not (hand and part) then
		return
	end
	part.Anchored = true
	part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - part.Size.Y / 2, 0)
	part.Parent = model
end

-- Puts a peeled panel back as it was built (a checkpoint replays S31 in a server where it was already opened).
function WatcherStandIn.close(panel)
	local part = panel.PrimaryPart
	local closed = part and part:GetAttribute("ClosedCFrame")
	if closed then
		part.CFrame = closed
	end
	panel:SetAttribute("Open", false)
end

-- Swings a hinged panel open about its lower outer edge (the rover's roof, docs/05 S31 beat 5), always from
-- where it was built.
function WatcherStandIn.peel(panel, degrees, seconds)
	local part = panel.PrimaryPart
	if not part then
		return
	end
	if not part:GetAttribute("ClosedCFrame") then
		part:SetAttribute("ClosedCFrame", part.CFrame)
	end
	local start = part:GetAttribute("ClosedCFrame")
	local hinge = start * CFrame.new(part.Size.X / 2, -part.Size.Y / 2, 0)
	local started = os.clock()
	while panel.Parent do
		local alpha = math.min(1, (os.clock() - started) / seconds)
		local eased = 1 - (1 - alpha) ^ 2
		part.CFrame = hinge * CFrame.Angles(0, 0, -math.rad(degrees) * eased) * hinge:ToObjectSpace(start)
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	panel:SetAttribute("Open", true)
end

function WatcherStandIn.despawn(model)
	if model then
		model:Destroy()
	end
end

return WatcherStandIn
