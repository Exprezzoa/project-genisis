--!nonstrict
-- Server/Frames/AllyNavigation.lua  (docs/09_frames.md §7; used by AllyFrameService)
--
-- How the ally Frame gets around things without a navigation mesh: a straight line when nothing that stops a
-- Frame is in the way (rays in the FrameRoot collision group, at the height of a Frame's root, so low props that
-- a Frame steps over don't count), and otherwise the player Frame's own trail, which is known to be passable.
--
--   clear(fromRoot, toGround, rootHeight, radius) -> boolean      fromRoot: a root position; toGround: a point on
--                                                                 the ground; rootHeight: root center above it
--   Trail.new() -> trail      trail:record(groundPoint)      trail:toward(fromRoot, goal, rootHeight, radius) -> Vector3?
--                             trail:behind(distance) -> Vector3?     trail:clear()

local AllyNavigation = {}

local SPACING = 8 -- studs between two trail points
local KEEP = 120 -- trail points kept (about 960 studs of path)
local JUMP = 60 -- a point this far from the last one means the Frame was moved: the trail starts over

local params = RaycastParams.new()
params.CollisionGroup = "FrameRoot"
params.RespectCanCollide = true
params.FilterType = Enum.RaycastFilterType.Exclude

local function refreshFilter()
	local skip = {}
	for _, name in ipairs({ "Frames", "Titans", "Runtime" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	params.FilterDescendantsInstances = skip
end

-- Three rays at root height (the middle and both sides of the root) from a root to a point on the ground.
function AllyNavigation.clear(fromRoot, toGround, rootHeight, radius)
	refreshFilter()
	local to = toGround + Vector3.new(0, rootHeight, 0)
	local along = (to - fromRoot) * Vector3.new(1, 0, 1)
	if along.Magnitude < 1 then
		return true
	end
	local side = Vector3.new(-along.Z, 0, along.X).Unit * radius
	for _, offset in ipairs({ Vector3.zero, side, -side }) do
		if workspace:Raycast(fromRoot + offset, to - fromRoot, params) then
			return false
		end
	end
	return true
end

local Trail = {}
Trail.__index = Trail

function Trail.new()
	return setmetatable({ points = {} }, Trail)
end

function Trail:clear()
	table.clear(self.points)
end

function Trail:record(groundPoint)
	local points = self.points
	local last = points[#points]
	local gap = if last then ((groundPoint - last) * Vector3.new(1, 0, 1)).Magnitude else math.huge
	if gap < SPACING then
		return
	elseif last and gap > JUMP then
		table.clear(points)
	end
	table.insert(points, groundPoint)
	if #points > KEEP then
		table.remove(points, 1)
	end
end

-- The trail point about `distance` studs of path behind the newest one.
function Trail:behind(distance)
	local points = self.points
	local walked = 0
	for index = #points, 2, -1 do
		walked += ((points[index] - points[index - 1]) * Vector3.new(1, 0, 1)).Magnitude
		if walked >= distance then
			return points[index - 1]
		end
	end
	return points[1]
end

-- The trail point to head for on the way to `goal`: of the points in a straight, clear line from here, the one
-- nearest the goal (so the ally cuts the corners the trail allows). nil when none is in sight.
function Trail:toward(fromRoot, goal, rootHeight, radius)
	local best, bestDistance = nil, math.huge
	local checked = 0
	for index = #self.points, 1, -1 do
		local point = self.points[index]
		local distance = ((point - goal) * Vector3.new(1, 0, 1)).Magnitude
		if distance < bestDistance then
			checked += 1
			if AllyNavigation.clear(fromRoot, point, rootHeight, radius) then
				best, bestDistance = point, distance
			end
			if checked > 40 then
				break -- enough rays for one look
			end
		end
	end
	return best
end

AllyNavigation.Trail = Trail

return AllyNavigation
