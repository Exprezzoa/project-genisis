--!strict
-- Server/Services/FlagService.lua  (docs/13_missions_dialogue_relationships.md §3)
--
-- Story flags: strings stored as a set in profile.story.flags. Naming: CH<n>_..., TUT_..., SEEN_..., EV_...
-- Changed fires (player, flag, value) only when a flag actually changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local TableUtil = require(Shared.Modules.TableUtil)

local PlayerDataService = require(script.Parent.PlayerDataService)

local MAX_LENGTH = 64

local FlagService = {}

FlagService.Changed = Signal.new() :: Signal.Signal<Player, string, boolean>

-- UPPER_SNAKE only (CLAUDE.md §7); a bad name is an error so typos surface immediately.
local function check(flag: string)
	if type(flag) ~= "string" or #flag == 0 or #flag > MAX_LENGTH or string.match(flag, "^[A-Z0-9_]+$") == nil then
		error("FlagService: invalid flag name " .. tostring(flag), 3)
	end
end

function FlagService.has(player: Player, flag: string): boolean
	check(flag)
	local profile = PlayerDataService.getProfile(player)
	return profile ~= nil and profile.story.flags[flag] == true
end

-- Returns true when the flag was newly set.
function FlagService.set(player: Player, flag: string): boolean
	check(flag)
	if FlagService.has(player, flag) then
		return false
	end
	local updated = PlayerDataService.update(player, function(profile)
		profile.story.flags[flag] = true
	end)
	if updated then
		FlagService.Changed:Fire(player, flag, true)
	end
	return updated
end

-- Returns true when the flag was set before.
function FlagService.clear(player: Player, flag: string): boolean
	check(flag)
	if not FlagService.has(player, flag) then
		return false
	end
	PlayerDataService.update(player, function(profile)
		profile.story.flags[flag] = nil
	end)
	FlagService.Changed:Fire(player, flag, false)
	return true
end

-- Every set flag, sorted (debug dumps).
function FlagService.getAll(player: Player): { string }
	local profile = PlayerDataService.getProfile(player)
	return if profile then TableUtil.sortedKeys(profile.story.flags) else {}
end

return FlagService
