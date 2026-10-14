--!nonstrict
-- Server/Sequence/Doors.lua  (docs/maps/map_02 §4 and §8; docs/07_building_with_parts.md §5)
--
-- Moves the map's big doors on the server (gameplay depends on them). A door is a Model tagged "Door" with a
-- DoorId; every part of it that moves carries the attributes the builder gave it: ClosedCFrame, OpenCFrame, Delay
-- and Time (seconds). Open and close tween each part between the two (Quad InOut), close in reverse order.
--
--   has(doorId) -> boolean       set(doorId, open, wait?) -> boolean (wait = true yields until it has moved)
--   isOpen(doorId) -> boolean

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Doors = {}

local function find(doorId)
	for _, door in ipairs(CollectionService:GetTagged("Door")) do
		if door:IsA("Model") and door:GetAttribute("DoorId") == doorId and door:IsDescendantOf(workspace) then
			return door
		end
	end
	return nil
end

function Doors.has(doorId)
	return find(doorId) ~= nil
end

function Doors.isOpen(doorId)
	local door = find(doorId)
	return door ~= nil and door:GetAttribute("Open") == true
end

function Doors.set(doorId, open, wait)
	local door = find(doorId)
	if not door then
		return false
	end
	door:SetAttribute("Open", open)
	local longest = 0
	local parts = {}
	for _, part in ipairs(door:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("OpenCFrame") then
			table.insert(parts, part)
			longest = math.max(longest, (part:GetAttribute("Delay") or 0) + (part:GetAttribute("Time") or 1))
		end
	end
	for _, part in ipairs(parts) do
		local delay = part:GetAttribute("Delay") or 0
		local time = part:GetAttribute("Time") or 1
		-- Closing runs the staggering backwards: the last part to open is the first to close.
		local start = if open then delay else longest - delay - time
		local goal = part:GetAttribute(if open then "OpenCFrame" else "ClosedCFrame")
		TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, start), { CFrame = goal }):Play()
	end
	if wait then
		task.wait(longest)
	end
	return true
end

return Doors
