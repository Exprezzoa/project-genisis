--!strict
-- Server/Services/TriggerService.lua  (docs/13_missions_dialogue_relationships.md §5)
--
-- Box triggers: parts tagged "Trigger" with a TriggerId attribute. No .Touched. Every 0.2 s the server tests
-- each player's tracked points with a point-in-oriented-box test and fires
--   Entered(player, triggerId, who) / Exited(player, triggerId, who)      who = "foot" | "frame"
-- "foot" is the character's HumanoidRootPart. Other kinds register a provider (FrameService adds "frame").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local MathUtil = require(Shared.Modules.MathUtil)
local Signal = require(Shared.Modules.Signal)

local TAG = "TriggerService"
local TRIGGER_TAG = "Trigger"

export type PointProvider = (player: Player) -> Vector3?

local TriggerService = {}

TriggerService.Entered = Signal.new() :: Signal.Signal<Player, string, string>
TriggerService.Exited = Signal.new() :: Signal.Signal<Player, string, string>

local triggers: { [string]: BasePart } = {}
local providers: { [string]: PointProvider } = {}
-- inside[player][who][triggerId] = true
local inside: { [Player]: { [string]: { [string]: boolean } } } = {}

local function register(instance: Instance)
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end
	local id = instance:GetAttribute("TriggerId")
	if type(id) ~= "string" or id == "" then
		Log.error(TAG, "%s is tagged Trigger but has no TriggerId", instance:GetFullName())
		return
	end
	if triggers[id] and triggers[id] ~= instance then
		Log.error(TAG, "duplicate TriggerId %s (%s)", id, instance:GetFullName())
		return
	end
	triggers[id] = instance
end

local function unregister(instance: Instance)
	for id, part in pairs(triggers) do
		if part == instance then
			triggers[id] = nil
		end
	end
end

local function update(player: Player)
	local state = inside[player]
	if not state then
		state = {}
		inside[player] = state
	end
	for who, provider in pairs(providers) do
		local point = provider(player)
		local whoState = state[who]
		if not whoState then
			whoState = {}
			state[who] = whoState
		end
		for id, part in pairs(triggers) do
			local isInside = point ~= nil and MathUtil.pointInBox(point, part.CFrame, part.Size)
			if isInside and not whoState[id] then
				whoState[id] = true
				TriggerService.Entered:Fire(player, id, who)
			elseif not isInside and whoState[id] then
				whoState[id] = nil
				TriggerService.Exited:Fire(player, id, who)
			end
		end
		-- A trigger that was removed while occupied.
		for id in pairs(whoState) do
			if not triggers[id] then
				whoState[id] = nil
				TriggerService.Exited:Fire(player, id, who)
			end
		end
	end
end

-- who: "foot", "frame" or nil for either.
function TriggerService.isInside(player: Player, triggerId: string, who: string?): boolean
	local state = inside[player]
	if not state then
		return false
	end
	if who then
		return state[who] ~= nil and state[who][triggerId] == true
	end
	for _, whoState in pairs(state) do
		if whoState[triggerId] then
			return true
		end
	end
	return false
end

function TriggerService.getTrigger(triggerId: string): BasePart?
	return triggers[triggerId]
end

-- Registers the function that returns a player's tracked point for one kind (nil = not present).
function TriggerService.setPointProvider(who: string, provider: PointProvider)
	providers[who] = provider
end

function TriggerService.Init()
	providers.foot = function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else nil
	end
end

function TriggerService.Start()
	for _, instance in ipairs(CollectionService:GetTagged(TRIGGER_TAG)) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TRIGGER_TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TRIGGER_TAG):Connect(unregister)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < GameConfig.Tick.TRIGGERS then
			return
		end
		elapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			update(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)
end

return TriggerService
