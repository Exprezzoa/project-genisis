--!nonstrict
-- Server/Services/ProgressionService.lua  (docs/17_saving_progression_monetization.md §6; docs/12 §12; docs/16 §4)
--
-- XP, ranks and credits; rewards granted once per key; upgrades bought at the Equipment Terminal; and each pilot's
-- effective config (the base configs plus the owned upgrades), which CombatService and FrameService play by.
--
--   grant(player, key) -> boolean           Config/Progression.Rewards[key]; false when already granted (or unknown)
--   buyUpgrade(player, upgradeId) -> (boolean, reason?)   reasons: Unknown, Owned, Rank, Credits, NoProfile
--   getEffectiveConfig(player) -> { combat, frame, key }
--   configForFrame(frame) -> { combat, frame, key }       its pilot's (attribute Pilot), else the base
--   give(player, xp, credits)               debug (/give): adds without a grant key
--   Granted: Signal(player, key, reward)    UpgradeBought: Signal(player, upgradeId)
--
-- The Equipment Terminal (INT_EQUIP_TERMINAL) opens the client's Equipment screen (UI_Open); a purchase is answered
-- with Upgrade_Result { upgradeId, ok, reason, credits }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Upgrades = require(Shared.Config.Upgrades)
local EffectiveConfig = require(Shared.Modules.EffectiveConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local InteractionService = require(script.Parent.InteractionService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TAG = "ProgressionService"
local TERMINAL = "INT_EQUIP_TERMINAL"

local ProgressionService = {}

ProgressionService.Granted = Signal.new()
ProgressionService.UpgradeBought = Signal.new()

-- Built from the profile each time: EffectiveConfig caches one result per upgrade set.
function ProgressionService.getEffectiveConfig(player)
	local profile = PlayerDataService.getProfile(player)
	return EffectiveConfig.build(profile and profile.progression.upgrades)
end

function ProgressionService.configForFrame(frame)
	local player = Players:GetPlayerByUserId(frame:GetAttribute("Pilot") or 0)
	return if player then ProgressionService.getEffectiveConfig(player) else EffectiveConfig.BASE
end

-- XP and credits on the profile, the rank following the XP (docs/17 §6).
local function add(player, xp, credits, key)
	return PlayerDataService.update(player, function(profile)
		local progression = profile.progression
		if key then
			progression.grants[key] = true
		end
		progression.xp += xp
		progression.credits += credits
		progression.rank = Progression.rankAt(progression.xp).rank
	end)
end

function ProgressionService.grant(player, key)
	local reward = Progression.Rewards[key]
	if not reward then
		Log.warn(TAG, "no reward %s", tostring(key))
		return false
	end
	local profile = PlayerDataService.getProfile(player)
	if not profile or profile.progression.grants[key] then
		return false
	end
	add(player, reward.xp, reward.credits, key)
	Log.info(TAG, "%s: %s (+%d XP, +%d credits) -> %d XP, rank %d", player.Name, key, reward.xp, reward.credits, profile.progression.xp, profile.progression.rank)
	ProgressionService.Granted:Fire(player, key, reward)
	return true
end

function ProgressionService.give(player, xp, credits)
	return add(player, xp or 0, credits or 0, nil)
end

function ProgressionService.buyUpgrade(player, upgradeId)
	local upgrade = Upgrades.ById[upgradeId]
	local profile = PlayerDataService.getProfile(player)
	if not upgrade then
		return false, "Unknown"
	elseif not profile then
		return false, "NoProfile"
	end
	local progression = profile.progression
	if progression.upgrades[upgradeId] then
		return false, "Owned"
	elseif progression.rank < upgrade.rankRequired then
		return false, "Rank"
	elseif progression.credits < upgrade.cost then
		return false, "Credits"
	end
	PlayerDataService.update(player, function(data)
		data.progression.credits -= upgrade.cost
		data.progression.upgrades[upgradeId] = true
	end)
	Log.info(TAG, "%s bought %s for %d credits (%d left)", player.Name, upgradeId, upgrade.cost, progression.credits)
	ProgressionService.UpgradeBought:Fire(player, upgradeId)
	task.spawn(PlayerDataService.saveNow, player, "upgrade") -- docs/17 §4: saved after an upgrade purchase
	return true
end

function ProgressionService.Start()
	Net.on("Upgrade_Buy", function(player, payload)
		local ok, reason = ProgressionService.buyUpgrade(player, payload.upgradeId)
		local profile = PlayerDataService.getProfile(player)
		Net.fireClient(player, "Upgrade_Result", {
			upgradeId = payload.upgradeId, ok = ok, reason = reason,
			credits = profile and profile.progression.credits, upgrades = profile and profile.progression.upgrades,
		})
	end)

	InteractionService.register(TERMINAL, function(player)
		Net.fireClient(player, "UI_Open", { screen = "Equipment" })
	end)
end

return ProgressionService
