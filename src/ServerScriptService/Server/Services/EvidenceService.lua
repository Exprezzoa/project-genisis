--!strict
-- Server/Services/EvidenceService.lua  (docs/13_missions_dialogue_relationships.md §3; docs/05 §9)
--
-- Evidence the player has read: profile.evidence[id] = when, the flag EV_<id>, and the toast "Evidence added to
-- Mission Log." the first time. Each entry of Shared/Evidence registers its prompt. The first-read reward
-- (+50 XP, docs/05 §10) is granted by the flag with the mission's rewards at M01_COMPLETE (ProgressionService);
-- the Log Reader UI comes with the Mission Log.
--
--   collect(player, id) -> boolean (true the first time)      has(player, id) -> boolean
--   Collected: Signal(player, id)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Evidence = require(Shared.Evidence)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local FlagService = require(script.Parent.FlagService)
local InteractionService = require(script.Parent.InteractionService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TAG = "EvidenceService"
local TOAST = "Evidence added to Mission Log."

local EvidenceService = {}

EvidenceService.Collected = Signal.new() :: Signal.Signal<Player, string>

function EvidenceService.has(player: Player, id: string): boolean
	local profile = PlayerDataService.getProfile(player)
	return profile ~= nil and profile.evidence[id] ~= nil
end

function EvidenceService.collect(player: Player, id: string): boolean
	if not (Evidence :: any)[id] then
		Log.warn(TAG, "unknown evidence %s", id)
		return false
	end
	if EvidenceService.has(player, id) then
		return false
	end
	PlayerDataService.update(player, function(profile)
		profile.evidence[id] = os.time()
	end)
	FlagService.set(player, "EV_" .. id)
	Net.fireClient(player, "UI_Toast", { text = TOAST })
	EvidenceService.Collected:Fire(player, id)
	Log.info(TAG, "%s collected %s", player.Name, id)
	return true
end

function EvidenceService.Start()
	-- Handlers can be registered before InteractionService.Start finds the prompts in the map.
	for id, entry in pairs(Evidence) do
		InteractionService.register(entry.interact, function(player: Player)
			EvidenceService.collect(player, id)
		end)
	end
end

return EvidenceService
