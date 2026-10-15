--!nonstrict
-- Server/Titans/Watcher.lua  (docs/05_chapter1_script.md S31; docs/10 §3; docs/08 §5.3; D-071, D-091)
--
-- The Watcher of S31: the rig of the user's Titan model (ServerStorage.Templates.Titans.Watcher, from
-- builders/rigs/Watcher). The server places its anchored root along the scripted route; every client animates
-- it with the Pose Animator (tag PoseRig, Class "Watcher"): the careful walk from the attribute GaitSpeed (an
-- anchored root has no velocity), clips from Anim / AnimT0, the head's look from LookTarget. It can't be hit,
-- locked onto or pushed. Without the template it falls back to the stored model itself, anchored and still.
--
--   spawn(groundCFrame) -> model        walk(model, points, seconds)      (yields)
--   face(model, point, seconds)         (yields)                          play(model, clip)     look(model, point?)
--   take(model, part)                   peel(panel, degrees, seconds)     (yields)              close(panel)
--   despawn(model)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Watcher = {}

local HEIGHT = 80 -- CLAUDE.md §7
local CANISTER = "TV_Canister"

local function mapPart(name)
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild(name, true)
end

-- The canister in the rover's cradle shows again (a replay of S31 in the same server); `take` hides it.
local function showCanister(on)
	local part = mapPart(CANISTER)
	if not part then
		return
	end
	part.Transparency = if on then 0 else 1
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = on
		end
	end
end

local function fromReference()
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
	local box, size = model:GetBoundingBox()
	model:SetAttribute("PivotToFeet", model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2))
	return model
end

function Watcher.spawn(groundCFrame)
	local templates = ServerStorage:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("Titans") and templates.Titans:FindFirstChild("Watcher")
	local model = if template then template:Clone() else fromReference()
	model.Name = "Watcher"
	Watcher.place(model, groundCFrame)
	if template then
		model:SetAttribute("Anim", "Idle")
		model:SetAttribute("AnimT0", workspace:GetServerTimeNow())
		model:AddTag("PoseRig")
	end
	-- A replay of S31 in the same server finds the rover as it was before.
	showCanister(true)
	local panel = mapPart("RoofPanel")
	if panel then
		Watcher.close(panel)
	end
	model.Parent = workspace:FindFirstChild("Titans") or workspace
	return model
end

-- Stands the model's feet on a ground point, facing the point's look direction (the rig faces its root's).
function Watcher.place(model, groundCFrame)
	local lift = model:GetAttribute("PivotToFeet") or 0
	model:PivotTo(CFrame.new(groundCFrame.Position + Vector3.new(0, lift, 0)) * groundCFrame.Rotation)
end

-- Starts a clip of Shared/Poses/Watcher on every client ("" lets it go back to the idle).
function Watcher.play(model, clip)
	model:SetAttribute("Anim", clip)
	model:SetAttribute("AnimT0", workspace:GetServerTimeNow())
end

-- The head turns toward a point (docs/08 §5.3 LookAtTarget); nil lets it go.
function Watcher.look(model, point)
	model:SetAttribute("LookTarget", point)
end

-- Slides the model through the ground points at an even pace, facing where it goes; the clients walk it.
function Watcher.walk(model, points, seconds)
	local from = model:GetPivot().Position - Vector3.new(0, model:GetAttribute("PivotToFeet") or 0, 0)
	local path, total = { from }, 0
	for _, point in ipairs(points) do
		total += (point - path[#path]).Magnitude
		table.insert(path, point)
	end
	if total < 0.1 then
		return
	end
	-- The gait follows the ground covered (the walk's slope included, as the feet see it).
	model:SetAttribute("GaitSpeed", total / seconds)
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
		Watcher.place(model, CFrame.lookAt(position, position + (if heading.Magnitude > 0.1 then heading.Unit else Vector3.zAxis)))
		if os.clock() - started >= seconds then
			break
		end
		RunService.Heartbeat:Wait()
	end
	model:SetAttribute("GaitSpeed", 0)
end

-- Turns on the spot until it looks at `point` (yaw only), at an even pace (docs/05 S31 beats 6 and 8).
function Watcher.face(model, point, seconds)
	local lift = model:GetAttribute("PivotToFeet") or 0
	local pivot = model:GetPivot()
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
		Watcher.place(model, CFrame.new(feet) * CFrame.Angles(0, yaw, 0))
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- The Watcher takes the T-V canister in its right hand (docs/05 S31 beat 5): a copy is welded under the hand,
-- so it follows the hand as each client animates it (and leaves with the Watcher); the one in the cradle hides.
function Watcher.take(model, part)
	local hand = model:FindFirstChild("RightHand") or model.PrimaryPart
	if not (hand and part) then
		return
	end
	local copy = part:Clone()
	for _, tag in ipairs(CollectionService:GetTags(copy)) do
		copy:RemoveTag(tag)
	end
	copy.Name = "Canister"
	copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.Massless = hand.Anchored, false, false, false, true
	copy.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	copy.Parent = hand
	if not hand.Anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, copy
		weld.Parent = copy
	end
	showCanister(false)
end

-- Puts a peeled panel back as it was built (a checkpoint replays S31 in a server where it was already opened).
function Watcher.close(panel)
	local part = panel.PrimaryPart
	local closed = part and part:GetAttribute("ClosedCFrame")
	if closed then
		part.CFrame = closed
	end
	panel:SetAttribute("Open", false)
end

-- Swings a hinged panel open about its lower outer edge (the rover's roof, docs/05 S31 beat 5), always from
-- where it was built.
function Watcher.peel(panel, degrees, seconds)
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

function Watcher.despawn(model)
	if model then
		model:Destroy()
	end
end

return Watcher
