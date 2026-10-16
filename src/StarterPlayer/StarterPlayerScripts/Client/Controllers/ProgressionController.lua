--!nonstrict
-- Client/Controllers/ProgressionController.lua  (docs/17_saving_progression_monetization.md §6; docs/12 §12)
--
-- The pilot's progression as the server last told it (Profile_Snapshot, Upgrade_Result), and the effective config
-- built from the owned upgrades with the same EffectiveConfig the server plays by, so prediction and the HUD match.
-- Read-only: purchases go to the server (Upgrade_Buy) and come back as Upgrade_Result.
--
--   get() -> { rank, xp, credits, upgrades, readOnly }
--   combat() -> effective CombatConfig      frame() -> effective FrameConfig
--   buy(upgradeId)
--   Changed: Signal(state)      Result: Signal({ upgradeId, ok, reason })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EffectiveConfig = require(Shared.Modules.EffectiveConfig)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local ProgressionController = {}

ProgressionController.Changed = Signal.new()
ProgressionController.Result = Signal.new()

local state = { rank = 1, xp = 0, credits = 0, upgrades = {}, readOnly = false }
local built = EffectiveConfig.BASE

local function set(changes)
	for key, value in pairs(changes) do
		if value ~= nil then
			state[key] = value
		end
	end
	built = EffectiveConfig.build(state.upgrades)
	ProgressionController.Changed:Fire(state)
end

function ProgressionController.get()
	return state
end

function ProgressionController.combat()
	return built.combat
end

function ProgressionController.frame()
	return built.frame
end

function ProgressionController.buy(upgradeId)
	Net.fireServer("Upgrade_Buy", { upgradeId = upgradeId })
end

function ProgressionController.Start()
	Net.on("Profile_Snapshot", function(snapshot)
		set({ rank = snapshot.rank, xp = snapshot.xp, credits = snapshot.credits, upgrades = snapshot.upgrades, readOnly = snapshot.readOnly })
	end)
	Net.on("Upgrade_Result", function(result)
		if result.ok then
			set({ credits = result.credits, upgrades = result.upgrades })
		end
		ProgressionController.Result:Fire(result)
	end)
end

return ProgressionController
