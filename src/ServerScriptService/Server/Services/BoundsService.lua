--!nonstrict
-- Server/Services/BoundsService.lua  (docs/12_combat_system.md §9 "Out of bounds"; map_03 §2)
--
-- A piloted Frame that drives into a bounds warning (a trigger whose id starts with TRG_OOB_, 15 studs inside the
-- FrameBarriers) is warned: the Frame gets the attribute OutOfBoundsAt, the server time it will be sent back,
-- which the Frame HUD counts down to, and Overwatch says OOB_01. Still in a warning when the time is up: a fade,
-- and the Frame stands at the nearest return point facing back the way it came.
--
-- Return points are the navigation nodes and the Frame spawn markers of the same map, except the Watcher's route
-- (W0-W5 lie beyond the barrier) and anything inside a warning (D-073).
--
--   isWarned(player) -> boolean

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local FrameService = require(script.Parent.FrameService)
local SequenceService = require(script.Parent.SequenceService)
local TriggerService = require(script.Parent.TriggerService)

local TAG = "BoundsService"
local PREFIX = "TRG_OOB_"
local GRACE = CombatConfig.Bounds.grace -- seconds in a warning before the Frame is sent back
local LINE_COOLDOWN = CombatConfig.Bounds.lineCooldown
local FADE = 0.35
local LINE = "DLG_OOB"
local ATTRIBUTE = "OutOfBoundsAt"

local BoundsService = {}

local inside = {} -- [player] = { [triggerId] = BasePart }
local token = {} -- [player] = number: the warning that is running
local lastLine = {} -- [player] = os.clock() of the last OOB_01

local function isWarning(id)
	return type(id) == "string" and string.sub(id, 1, #PREFIX) == PREFIX
end

local function triggerPart(id)
	for _, part in ipairs(CollectionService:GetTagged("Trigger")) do
		if part:GetAttribute("TriggerId") == id and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- The map zone folder a part belongs to (Workspace.Map.<Zone>).
local function zoneOf(part)
	local map = workspace:FindFirstChild("Map")
	local node = part
	while node and node.Parent ~= map do
		node = node.Parent
	end
	return node
end

local function inWarning(point, zone)
	for _, part in ipairs(CollectionService:GetTagged("Trigger")) do
		if part:IsA("BasePart") and isWarning(part:GetAttribute("TriggerId")) and part:IsDescendantOf(zone) then
			local offset = part.CFrame:PointToObjectSpace(point)
			local half = part.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function returnPoint(position, zone)
	local best, bestDistance = nil, math.huge
	local function consider(part, id)
		if not part:IsA("BasePart") or not part:IsDescendantOf(zone) then
			return
		end
		if string.match(id, "^W%d+$") or inWarning(part.Position, zone) then
			return
		end
		local distance = ((part.Position - position) * Vector3.new(1, 0, 1)).Magnitude
		if distance < bestDistance then
			best, bestDistance = part.Position, distance
		end
	end
	for _, node in ipairs(CollectionService:GetTagged("NavNode")) do
		consider(node, node:GetAttribute("NavId") or "")
	end
	for _, marker in ipairs(CollectionService:GetTagged("SpawnPoint")) do
		local id = marker:GetAttribute("SpawnId") or ""
		if string.sub(id, 1, 6) == "FRAME_" then
			consider(marker, id)
		end
	end
	return best
end

local function clear(player)
	token[player] = (token[player] or 0) + 1
	local frame = FrameService.getPiloted(player)
	if frame then
		frame:SetAttribute(ATTRIBUTE, nil)
	end
end

local function sendBack(player, frame, zone)
	local root = frame.PrimaryPart
	local point = root and returnPoint(root.Position, zone)
	if not point then
		Log.warn(TAG, "no return point for %s in %s", player.Name, zone and zone.Name or "?")
		return
	end
	Net.fireClient(player, "Fade", { to = 1, duration = FADE })
	task.wait(FADE)
	if FrameService.getPiloted(player) ~= frame then
		Net.fireClient(player, "Fade", { to = 0, duration = FADE })
		return
	end
	-- Facing back the way it came: from where it stood toward the return point.
	local away = (point - root.Position) * Vector3.new(1, 0, 1)
	FrameService.moveTo(frame, CFrame.lookAt(point, point + (if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis)))
	frame:SetAttribute(ATTRIBUTE, nil)
	Log.info(TAG, "%s's Frame was sent back to %s", player.Name, tostring(point))
	Net.fireClient(player, "Fade", { to = 0, duration = FADE })
end

local function startWarning(player, part)
	local frame = FrameService.getPiloted(player)
	if not frame or frame:GetAttribute(ATTRIBUTE) then
		return
	end
	token[player] = (token[player] or 0) + 1
	local mine = token[player]
	frame:SetAttribute(ATTRIBUTE, workspace:GetServerTimeNow() + GRACE)
	if os.clock() - (lastLine[player] or -math.huge) >= LINE_COOLDOWN then
		lastLine[player] = os.clock()
		SequenceService.say(player, LINE, true) -- at once, over any line that is playing
	end
	local zone = zoneOf(part)
	task.delay(GRACE, function()
		if token[player] ~= mine or not next(inside[player] or {}) then
			return
		end
		if FrameService.getPiloted(player) == frame then
			sendBack(player, frame, zone)
		end
	end)
end

function BoundsService.isWarned(player)
	return next(inside[player] or {}) ~= nil
end

function BoundsService.Start()
	TriggerService.Entered:Connect(function(player, triggerId, who)
		if who ~= "frame" or not isWarning(triggerId) then
			return
		end
		local part = triggerPart(triggerId)
		if not part then
			return
		end
		inside[player] = inside[player] or {}
		inside[player][triggerId] = part
		startWarning(player, part)
	end)
	TriggerService.Exited:Connect(function(player, triggerId, who)
		if who ~= "frame" or not isWarning(triggerId) or not inside[player] then
			return
		end
		inside[player][triggerId] = nil
		if not next(inside[player]) then
			clear(player)
		end
	end)
	-- Leaving the Frame ends any warning.
	FrameService.Dismounted:Connect(function(player, frame)
		inside[player] = nil
		token[player] = (token[player] or 0) + 1
		frame:SetAttribute(ATTRIBUTE, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		inside[player], token[player], lastLine[player] = nil, nil, nil
	end)
end

return BoundsService
