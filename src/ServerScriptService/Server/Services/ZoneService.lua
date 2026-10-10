--!strict
-- Server/Services/ZoneService.lua  (docs/16 §4, docs/maps/map_00_world_layout.md §2)
--
-- Tracks which zone each player's character is in (Config/Zones: first matching box wins).
-- ZoneChanged fires (player, zoneId?, previousZoneId?). The current zone is also the player attribute "Zone",
-- which is how clients learn it (lighting, reverb, weapon lock).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local MathUtil = require(Shared.Modules.MathUtil)
local Signal = require(Shared.Modules.Signal)

local ZoneService = {}

ZoneService.ZoneChanged = Signal.new() :: Signal.Signal<Player, string?, string?>

local byId: { [string]: Zones.Zone } = {}
local current: { [Player]: string } = {}

-- The zone that contains a world position, or nil outside every box.
function ZoneService.zoneAt(position: Vector3): Zones.Zone?
	for _, zone in ipairs(Zones) do
		if MathUtil.pointInBounds(position, zone.min, zone.max) then
			return zone
		end
	end
	return nil
end

function ZoneService.getZone(player: Player): string?
	return current[player]
end

function ZoneService.getZoneInfo(zoneId: string): Zones.Zone?
	return byId[zoneId]
end

local function update(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local zone = if root and root:IsA("BasePart") then ZoneService.zoneAt(root.Position) else nil
	local zoneId = if zone then zone.id else nil
	local previous = current[player]
	if zoneId ~= previous then
		current[player] = zoneId :: any
		player:SetAttribute("Zone", zoneId)
		ZoneService.ZoneChanged:Fire(player, zoneId, previous)
	end
end

function ZoneService.Init()
	for _, zone in ipairs(Zones) do
		byId[zone.id] = zone
	end
end

function ZoneService.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < GameConfig.Tick.ZONES then
			return
		end
		elapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			update(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
	end)
end

return ZoneService
