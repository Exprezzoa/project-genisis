--!strict
-- Server/Services/InteractionService.lua  (docs/13_missions_dialogue_relationships.md §4)
--
-- Every interactable is a part tagged "Interactable" with a ProximityPrompt child and the attributes
-- InteractId (unique), FrameOnly, OnFootOnly, Once. The server listens to ProximityPrompt.Triggered (no custom
-- remote), validates the context and routes to the handler registered for that InteractId.
--
--   InteractionService.register("INT_Q3_PHOTO", function(player, interactId) ... end)
--   InteractionService.setEnabled("INT_Q3_TERMINAL", false)          -- for everyone (ProximityPrompt.Enabled)
--   InteractionService.setEnabled("INT_Q3_LOCKER", false, player)    -- for one player
--
-- Per-player state reaches that client as the player attribute "PromptOff_<InteractId>".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local TAG = "InteractionService"
local INTERACT_TAG = "Interactable"
local PILOT_SEAT = "PilotSeat" -- docs/08 §5.4
local ATTRIBUTE_PREFIX = "PromptOff_"

export type Handler = (player: Player, interactId: string) -> ()
type Entry = { part: BasePart, prompt: ProximityPrompt, connection: RBXScriptConnection }

local InteractionService = {}

-- Fires (player, interactId) after a valid interaction, whether or not a handler is registered.
InteractionService.Interacted = Signal.new() :: Signal.Signal<Player, string>

local entries: { [string]: Entry } = {}
local handlers: { [string]: Handler } = {}
local disabledFor: { [Player]: { [string]: boolean } } = {}

local function isPiloting(humanoid: Humanoid): boolean
	local seat = humanoid.SeatPart
	return seat ~= nil and seat.Name == PILOT_SEAT
end

-- The server-side validation of one interaction: returns true, or false and the reason.
-- The engine already hides out-of-range prompts on the client; this is the check a client can't skip.
function InteractionService.canInteract(player: Player, interactId: string): (boolean, string?)
	local entry = entries[interactId]
	if not entry then
		return false, "unknown id"
	end
	if not entry.prompt.Enabled or (disabledFor[player] and disabledFor[player][interactId]) then
		return false, "disabled"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false, "no living character"
	end
	local limit = entry.prompt.MaxActivationDistance + GameConfig.Interaction.DISTANCE_SLACK
	if (root.Position - entry.part.Position).Magnitude > limit then
		return false, "too far"
	end
	local piloting = isPiloting(humanoid)
	if entry.part:GetAttribute("FrameOnly") and not piloting then
		return false, "Frame only"
	end
	if entry.part:GetAttribute("OnFootOnly") and piloting then
		return false, "on foot only"
	end
	return true
end

local function onTriggered(player: Player, interactId: string)
	local allowed, reason = InteractionService.canInteract(player, interactId)
	if not allowed then
		Log.debug(TAG, "%s refused for %s: %s", interactId, player.Name, tostring(reason))
		return
	end
	local entry = entries[interactId]
	if entry.part:GetAttribute("Once") then
		InteractionService.setEnabled(interactId, false, player)
	end
	local handler = handlers[interactId]
	if handler then
		local ok, message = pcall(handler, player, interactId)
		if not ok then
			Log.error(TAG, "%s handler failed: %s", interactId, tostring(message))
		end
	else
		Log.debug(TAG, "%s used by %s (no handler registered)", interactId, player.Name)
	end
	InteractionService.Interacted:Fire(player, interactId)
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end
	local interactId = instance:GetAttribute("InteractId")
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if type(interactId) ~= "string" or interactId == "" or not prompt then
		Log.error(TAG, "%s is tagged Interactable but has no InteractId or no ProximityPrompt", instance:GetFullName())
		return
	end
	if entries[interactId] then
		if entries[interactId].part ~= instance then
			Log.error(TAG, "duplicate InteractId %s (%s)", interactId, instance:GetFullName())
		end
		return
	end
	local id: string = interactId
	entries[id] = {
		part = instance,
		prompt = prompt,
		connection = prompt.Triggered:Connect(function(player)
			onTriggered(player, id)
		end),
	}
end

local function remove(instance: Instance)
	for interactId, entry in pairs(entries) do
		if entry.part == instance then
			entry.connection:Disconnect()
			entries[interactId] = nil
		end
	end
end

-- One handler per InteractId. Registering a second one is an error; unregister first to replace it.
function InteractionService.register(interactId: string, handler: Handler)
	if handlers[interactId] then
		error("InteractionService: a handler is already registered for " .. interactId, 2)
	end
	handlers[interactId] = handler
end

function InteractionService.unregister(interactId: string)
	handlers[interactId] = nil
end

-- Without a player: enables or disables the prompt for everyone. With a player: only for that player.
function InteractionService.setEnabled(interactId: string, enabled: boolean, player: Player?)
	if player then
		local set = disabledFor[player]
		if not set then
			set = {}
			disabledFor[player] = set
		end
		set[interactId] = if enabled then nil else true
		player:SetAttribute(ATTRIBUTE_PREFIX .. interactId, if enabled then nil else true)
		return
	end
	local entry = entries[interactId]
	if not entry then
		error("InteractionService: unknown InteractId " .. tostring(interactId), 2)
	end
	entry.prompt.Enabled = enabled
end

function InteractionService.isEnabled(interactId: string, player: Player?): boolean
	local entry = entries[interactId]
	if not entry or not entry.prompt.Enabled then
		return false
	end
	if player and disabledFor[player] and disabledFor[player][interactId] then
		return false
	end
	return true
end

function InteractionService.exists(interactId: string): boolean
	return entries[interactId] ~= nil
end

function InteractionService.Start()
	for _, instance in ipairs(CollectionService:GetTagged(INTERACT_TAG)) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(INTERACT_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(INTERACT_TAG):Connect(remove)
	Players.PlayerRemoving:Connect(function(player)
		disabledFor[player] = nil
	end)
end

return InteractionService
