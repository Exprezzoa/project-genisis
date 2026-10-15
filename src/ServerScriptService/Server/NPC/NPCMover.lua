--!nonstrict
-- Server/NPC/NPCMover.lua  (docs/08_rigs_and_animation.md §1.2; docs/13_missions_dialogue_relationships.md §6)
--
-- How NPCs get somewhere: straight when nothing solid is in the way at waist height, otherwise along the nav
-- graph (parts tagged "NavNode", attributes NavId and Links; map_01 §13.2). Humanoid:MoveTo is re-issued
-- every 7 s (its own timeout is 8 s); after three tries the NPC is put on the point and a warning is logged.
--
--   resolve(target) -> Vector3?, Vector3?     a NavId, a SpawnId, a Vector3 or { x, y, z } -> point, facing
--   path(from, to) -> { Vector3 }             the points to walk, `to` last
--   walk(npc, points, opts) -> boolean        yields; false when cancelled. npc = { model, humanoid, root, job }
--       opts.follow = player   waits (facing them) while the player is more than FOLLOW_WAIT away, matches
--                              their speed (14 or 22)
--   cancel(npc)                               stops what the NPC was walking
-- The caller anchors and un-anchors the root; walk() needs it un-anchored.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local NPCs = require(Shared.Config.NPCs)

local CharacterService = require(script.Parent.Parent.Services.CharacterService)

local TAG = "NPCService"
local MOVE = NPCs.Move
local WAIST = 2.5 -- the line-of-sight test runs this high above the feet
local VISIBLE_NODE = 60 -- nodes further than this aren't considered as the first or last node of a path

local NPCMover = {}

local nodes = nil -- { [id] = { id, pos, links } }

local function graph()
	if nodes then
		return nodes
	end
	nodes = {}
	for _, part in ipairs(CollectionService:GetTagged("NavNode")) do
		local id = part:GetAttribute("NavId")
		if type(id) == "string" and part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			local links = {}
			for link in string.gmatch(part:GetAttribute("Links") or "", "[^,]+") do
				table.insert(links, link)
			end
			nodes[id] = { id = id, pos = part.Position, links = links } -- a marker's center is its point on the floor
		end
	end
	return nodes
end

-- The graph is read once; a rebuilt map changes it.
function NPCMover.reset()
	nodes = nil
end

function NPCMover.resolve(target)
	if typeof(target) == "Vector3" then
		return target, nil
	elseif type(target) == "table" then
		return Vector3.new(target[1], target[2], target[3]), nil
	elseif type(target) == "string" then
		local node = graph()[target]
		if node then
			return node.pos, nil
		end
		local cframe = CharacterService.getSpawnCFrame(target)
		if cframe then
			return cframe.Position, cframe.LookVector
		end
	end
	return nil, nil
end

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { workspace:FindFirstChild("Runtime") }
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

local function clear(a: Vector3, b: Vector3, params): boolean
	local from = a + Vector3.new(0, WAIST, 0)
	local delta = (b + Vector3.new(0, WAIST, 0)) - from
	if delta.Magnitude < 0.1 then
		return true
	end
	return workspace:Raycast(from, delta, params) == nil
end

-- The nearest node that can be reached in a straight line (or the nearest at all, as a last resort).
local function nearestNode(pos: Vector3, params)
	local best, bestDistance, fallback, fallbackDistance = nil, math.huge, nil, math.huge
	for _, node in pairs(graph()) do
		local distance = (node.pos - pos).Magnitude
		if distance < fallbackDistance then
			fallback, fallbackDistance = node, distance
		end
		if distance < bestDistance and distance <= VISIBLE_NODE and clear(pos, node.pos, params) then
			best, bestDistance = node, distance
		end
	end
	return best or fallback
end

-- Dijkstra over the node graph (about 50 nodes, so a plain scan for the next node is enough).
local function route(fromId: string, toId: string): { string }?
	local all = graph()
	local distance, previous, done = { [fromId] = 0 }, {}, {}
	while true do
		local current, best = nil, math.huge
		for id, d in pairs(distance) do
			if not done[id] and d < best then
				current, best = id, d
			end
		end
		if not current then
			return nil
		end
		if current == toId then
			break
		end
		done[current] = true
		for _, link in ipairs(all[current].links) do
			local other = all[link]
			if other and not done[link] then
				local d = best + (other.pos - all[current].pos).Magnitude
				if d < (distance[link] or math.huge) then
					distance[link] = d
					previous[link] = current
				end
			end
		end
	end
	local ids = { toId }
	while ids[1] ~= fromId do
		table.insert(ids, 1, previous[ids[1]])
	end
	return ids
end

function NPCMover.path(from: Vector3, to: Vector3): { Vector3 }
	local params = rayParams()
	if clear(from, to, params) then
		return { to }
	end
	local first, last = nearestNode(from, params), nearestNode(to, params)
	if not first or not last then
		return { to }
	end
	local ids = route(first.id, last.id)
	if not ids then
		Log.warn(TAG, "no nav route from %s to %s; walking straight", first.id, last.id)
		return { to }
	end
	local points = {}
	for _, id in ipairs(ids) do
		table.insert(points, graph()[id].pos)
	end
	table.insert(points, to)
	-- Skip ahead: from the start, go straight to the furthest point already in sight.
	while #points > 1 and clear(from, points[2], params) do
		table.remove(points, 1)
	end
	return points
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function arrived(root: BasePart, point: Vector3): boolean
	local feet = root.Position.Y - root.Size.Y / 2
	return flat(root.Position - point).Magnitude <= MOVE.ARRIVE and math.abs(feet - point.Y) < 6
end

local function followerRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Holds the NPC in place, facing the player, until they come back within reach or the walk is cancelled.
-- Returns (carry on?, waited?).
local function waitFor(npc, player, job): (boolean, boolean)
	local playerRoot = followerRoot(player)
	if not playerRoot or (playerRoot.Position - npc.root.Position).Magnitude <= MOVE.FOLLOW_WAIT then
		return true, false
	end
	-- Standing still means anchored (a humanoid's own facing would undo a turn); the walk un-anchors again.
	npc.humanoid:MoveTo(npc.root.Position)
	npc.root.Anchored = true
	local resumed = false
	while npc.job == job and npc.model.Parent do
		playerRoot = followerRoot(player)
		if not playerRoot or (playerRoot.Position - npc.root.Position).Magnitude <= MOVE.FOLLOW_WAIT * 0.8 then
			resumed = true
			break
		end
		local look = flat(playerRoot.Position - npc.root.Position)
		if look.Magnitude > 0.1 then
			npc.root.CFrame = npc.root.CFrame:Lerp(CFrame.lookAt(npc.root.Position, npc.root.Position + look), 0.5)
		end
		task.wait(0.1)
	end
	if npc.model.Parent and npc.job == job then
		npc.root.Anchored = false
		npc.root:SetNetworkOwner(nil)
		npc.humanoid:ChangeState(Enum.HumanoidStateType.Running) -- out of the anchored Freefall at once
	end
	return resumed, true
end

function NPCMover.walk(npc, points, opts)
	opts = opts or {}
	npc.job += 1
	local job = npc.job
	local humanoid, root = npc.humanoid, npc.root
	humanoid.WalkSpeed = MOVE.WALK
	for _, point in ipairs(points) do
		local tries, issued = 0, -math.huge
		while not arrived(root, point) do
			if npc.job ~= job or not npc.model.Parent then
				return false
			end
			if opts.follow then
				local carryOn, waited = waitFor(npc, opts.follow, job)
				if not carryOn then
					return false
				end
				if waited then
					issued, tries = -math.huge, 0 -- the wait replaced the MoveTo target
				end
				-- The player's WalkSpeed is set on their client and doesn't replicate; their velocity does.
				local playerRoot = followerRoot(opts.follow)
				local speed = if playerRoot then flat(playerRoot.AssemblyLinearVelocity).Magnitude else 0
				humanoid.WalkSpeed = if speed > (MOVE.WALK + MOVE.SPRINT) / 2 then MOVE.SPRINT else MOVE.WALK
			end
			if os.clock() - issued >= MOVE.REISSUE then
				tries += 1
				if tries > MOVE.TRIES then
					Log.warn(TAG, "%s didn't reach %s; placed there", npc.model.Name, tostring(point))
					root.CFrame = CFrame.new(point + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)) * root.CFrame.Rotation
					break
				end
				humanoid:MoveTo(point)
				issued = os.clock()
			end
			task.wait(0.1)
		end
	end
	if npc.job == job then
		humanoid:MoveTo(root.Position)
	end
	return npc.job == job
end

function NPCMover.cancel(npc)
	npc.job += 1
	if npc.model.Parent and not npc.root.Anchored then
		npc.humanoid:MoveTo(npc.root.Position)
	end
end

return NPCMover
