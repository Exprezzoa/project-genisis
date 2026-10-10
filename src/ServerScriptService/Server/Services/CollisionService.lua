--!strict
-- Server/Services/CollisionService.lua  (docs/07_building_with_parts.md §5)
--
-- Registers the collision groups and their matrix at server start, and assigns parts to groups.
-- Map parts keep the group name BuildKit gave them (barriers); everything else is "Default".

local PhysicsService = game:GetService("PhysicsService")

local CollisionService = {}

CollisionService.GROUPS = {
	"Default",
	"Players",
	"FrameRoot",
	"TitanRoot",
	"NPCs",
	"FrameBarrier",
	"PlayerBarrier",
	"Debris",
	"NoCollide",
}

-- The only pairs that collide. Every other pair (including a group with itself) doesn't:
-- Players, Frames, Titans and NPCs pass through each other, barriers only stop their own kind.
CollisionService.COLLIDING_PAIRS = {
	{ "Default", "Default" },
	{ "Default", "Players" },
	{ "Default", "FrameRoot" },
	{ "Default", "TitanRoot" },
	{ "Default", "NPCs" },
	{ "Default", "Debris" },
	{ "Players", "PlayerBarrier" },
	{ "FrameRoot", "FrameBarrier" },
}

local known: { [string]: boolean } = {}

function CollisionService.Init()
	for _, name in ipairs(CollisionService.GROUPS) do
		known[name] = true
		if name ~= "Default" and not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	local collides: { [string]: boolean } = {}
	for _, pair in ipairs(CollisionService.COLLIDING_PAIRS) do
		collides[pair[1] .. "|" .. pair[2]] = true
		collides[pair[2] .. "|" .. pair[1]] = true
	end
	for i, a in ipairs(CollisionService.GROUPS) do
		for j = i, #CollisionService.GROUPS do
			local b = CollisionService.GROUPS[j]
			PhysicsService:CollisionGroupSetCollidable(a, b, collides[a .. "|" .. b] == true)
		end
	end
end

function CollisionService.assign(part: BasePart, group: string)
	if not known[group] then
		error("CollisionService: unknown collision group " .. tostring(group), 2)
	end
	part.CollisionGroup = group
end

-- Assigns every BasePart of the model, including parts added later (accessories, gear).
-- Returns the connection that watches for new parts, so the caller can put it in a Trove.
function CollisionService.assignModel(model: Instance, group: string): RBXScriptConnection
	if not known[group] then
		error("CollisionService: unknown collision group " .. tostring(group), 2)
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
	return model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end)
end

return CollisionService
