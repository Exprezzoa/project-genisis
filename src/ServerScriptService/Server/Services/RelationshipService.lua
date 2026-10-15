--!strict
-- Server/Services/RelationshipService.lua  (docs/13_missions_dialogue_relationships.md §3)
--
-- Relationship values (mara, vale, voss, orin), clamped to -3..+3, kept in the profile. Every change is logged in
-- profile.story.relLog (the last 50) with its reason. A toast only when the caller gives one; the UI never shows
-- the numbers.
--
--   get(player, var) -> number      add(player, var, delta, reason, toast?) -> number (the new value)
--   VARS: the known variables       Changed: Signal(player, var, value, delta)
-- An unknown variable is refused (a typo would otherwise live in the profile for good), and one already in a
-- profile is dropped when the profile loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)

local TAG = "RelationshipService"
local MIN, MAX = -3, 3
local LOG_SIZE = 50

local RelationshipService = {}

RelationshipService.Changed = Signal.new() :: Signal.Signal<Player, string, number, number>

-- docs/17 profile: relationships = { mara, vale, voss, orin }.
RelationshipService.VARS = { mara = true, vale = true, voss = true, orin = true }

function RelationshipService.get(player: Player, var: string): number
	local profile = PlayerDataService.getProfile(player)
	return if profile then (profile.relationships[var] or 0) else 0
end

function RelationshipService.add(player: Player, var: string, delta: number, reason: string, toast: string?): number
	if not RelationshipService.VARS[var] then
		Log.warn(TAG, "unknown relationship %s (%s); not changed", tostring(var), reason)
		return 0
	end
	local value = 0
	PlayerDataService.update(player, function(profile)
		local before = profile.relationships[var] or 0
		value = math.clamp(before + delta, MIN, MAX)
		profile.relationships[var] = value
		local entries = profile.story.relLog
		table.insert(entries, { var = var, delta = delta, reason = reason, t = os.time() })
		while #entries > LOG_SIZE do
			table.remove(entries, 1)
		end
	end)
	Log.info(TAG, "%s %s %+d -> %d (%s)", player.Name, var, delta, value, reason)
	RelationshipService.Changed:Fire(player, var, value, delta)
	if toast then
		Net.fireClient(player, "UI_Toast", { text = toast })
	end
	return value
end

local function dropUnknown(player: Player)
	PlayerDataService.update(player, function(profile)
		for var in pairs(profile.relationships) do
			if not RelationshipService.VARS[var] then
				profile.relationships[var] = nil
				Log.warn(TAG, "dropped unknown relationship %s from %s's profile", var, player.Name)
			end
		end
	end)
end

function RelationshipService.Start()
	PlayerDataService.Loaded:Connect(dropUnknown)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if PlayerDataService.getProfile(player) then
			dropUnknown(player)
		end
	end
end

return RelationshipService
