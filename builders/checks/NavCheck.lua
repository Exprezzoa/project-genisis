--!nonstrict
-- builders/checks/NavCheck.lua  ->  ServerStorage.DevTools.Checks.NavCheck   (docs/19 §3, docs/07 §8)
--
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.NavCheck:Clone()).Run())
--
-- Checks every part tagged NavNode under Workspace.Map:
--   * ids are unique, every link points to an existing node and is listed on both ends;
--   * each node has floor beneath it and headroom above (5.5 + 1);
--   * each link can be walked: the check moves along it in 0.5-stud steps, follows the floor with a ray
--     (so stairs and ramps work), refuses steps higher than a stair step, and sweeps a sphere at height 3
--     between the steps. The doc asks for radius 1.5; 1.45 is used so surfaces that merely touch don't count;
--   * the graph is connected.
-- Parts in the FrameBarrier group are ignored (players walk through them); PlayerBarrier parts block.

local CollectionService = game:GetService("CollectionService")

local Check = {}

local RADIUS = 1.45
local HEIGHT = 3
local HEADROOM = 6.5
local STEP = 0.5
local MAX_STEP_UP = 1.1
local FLOOR_REACH = 2.6
local NODE_FLOOR_TOLERANCE = 0.75

function Check.Run()
	local map = workspace:FindFirstChild("Map")
	local errors = {}
	local function fail(message)
		table.insert(errors, message)
	end

	local ignored = {}
	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.CollisionGroup == "FrameBarrier" then
			table.insert(ignored, descendant)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true

	local nodes, count = {}, 0
	for _, part in ipairs(CollectionService:GetTagged("NavNode")) do
		if part:IsDescendantOf(map) then
			local id = part:GetAttribute("NavId")
			if nodes[id] then
				fail("duplicate node " .. tostring(id))
			else
				local links = {}
				for link in string.gmatch(part:GetAttribute("Links") or "", "[^,]+") do
					table.insert(links, link)
				end
				nodes[id] = { id = id, pos = part.Position, links = links }
				count += 1
			end
		end
	end

	local function floorBelow(x, z, fromY)
		local hit = workspace:Raycast(Vector3.new(x, fromY + FLOOR_REACH, z), Vector3.new(0, -2 * FLOOR_REACH, 0), params)
		return hit and hit.Position.Y, hit and hit.Instance
	end

	-- Nodes: floor and headroom.
	for id, node in pairs(nodes) do
		local p = node.pos
		local floorY = floorBelow(p.X, p.Z, p.Y)
		if not floorY then
			fail(id .. ": no floor beneath")
		elseif math.abs(floorY - p.Y) > NODE_FLOOR_TOLERANCE then
			fail(("%s: floor at Y %.2f, node at Y %.2f"):format(id, floorY, p.Y))
		end
		local above = workspace:Raycast(p + Vector3.new(0, 1.2, 0), Vector3.new(0, HEADROOM - 1.2, 0), params)
		if above then
			fail(("%s: headroom blocked by %s"):format(id, above.Instance:GetFullName()))
		end
	end

	-- Links: both ends listed, then the walk.
	local function walk(a, b)
		local flat = Vector3.new(b.pos.X - a.pos.X, 0, b.pos.Z - a.pos.Z)
		local steps = math.max(1, math.ceil(flat.Magnitude / STEP))
		local current = a.pos
		local floorY = a.pos.Y
		for i = 1, steps do
			local t = i / steps
			local x, z = a.pos.X + flat.X * t, a.pos.Z + flat.Z * t
			local nextFloor = floorBelow(x, z, floorY)
			if not nextFloor then
				return ("no floor at (%.1f, %.1f) near Y %.1f"):format(x, z, floorY)
			end
			if math.abs(nextFloor - floorY) > MAX_STEP_UP then
				return ("step of %.2f at (%.1f, %.1f)"):format(nextFloor - floorY, x, z)
			end
			local from = Vector3.new(current.X, floorY + HEIGHT, current.Z)
			local to = Vector3.new(x, nextFloor + HEIGHT, z)
			local hit = workspace:Spherecast(from, RADIUS, to - from, params)
			if hit then
				return ("blocked at (%.1f, %.1f, %.1f) by %s"):format(hit.Position.X, hit.Position.Y, hit.Position.Z, hit.Instance:GetFullName())
			end
			current = Vector3.new(x, nextFloor, z)
			floorY = nextFloor
		end
		if math.abs(floorY - b.pos.Y) > NODE_FLOOR_TOLERANCE then
			return ("arrives at Y %.2f, node is at Y %.2f"):format(floorY, b.pos.Y)
		end
		return nil
	end

	local linkCount = 0
	local done = {}
	for id, node in pairs(nodes) do
		for _, otherId in ipairs(node.links) do
			local other = nodes[otherId]
			if not other then
				fail(("%s links to missing node %s"):format(id, otherId))
			elseif not table.find(other.links, id) then
				fail(("%s links to %s, but not the other way round"):format(id, otherId))
			else
				local key = if id < otherId then id .. "|" .. otherId else otherId .. "|" .. id
				if not done[key] then
					done[key] = true
					linkCount += 1
					for _, pair in ipairs({ { node, other }, { other, node } }) do
						local problem = walk(pair[1], pair[2])
						if problem then
							fail(("%s -> %s: %s"):format(pair[1].id, pair[2].id, problem))
						end
					end
				end
			end
		end
	end

	-- Connectivity.
	local start = next(nodes)
	local reached, queue, reachedCount = {}, { start }, 0
	while #queue > 0 do
		local id = table.remove(queue)
		if id and not reached[id] then
			reached[id] = true
			reachedCount += 1
			for _, otherId in ipairs(nodes[id].links) do
				if nodes[otherId] and not reached[otherId] then
					table.insert(queue, otherId)
				end
			end
		end
	end
	if reachedCount ~= count then
		local missing = {}
		for id in pairs(nodes) do
			if not reached[id] then
				table.insert(missing, id)
			end
		end
		table.sort(missing)
		fail("graph not connected; unreachable from " .. tostring(start) .. ": " .. table.concat(missing, ", "))
	end

	table.sort(errors)
	return { nodes = count, links = linkCount, passed = #errors == 0, errors = errors }
end

return Check
