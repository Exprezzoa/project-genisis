--!nonstrict
-- Server/Services/DialogueService.lua  (docs/13_missions_dialogue_relationships.md §2; docs/16 §4-5)
--
-- Which line each player is on, which choices they may take, timers and effects. The server sends
-- Dialogue_Node {dialogueId, nodeId, mode, choices?, timer?}; the client draws the line from its own copy of
-- Shared/Dialogue and only asks: Dialogue_Advance (conversation) or Dialogue_Choose. Modes:
--   conversation  the player advances each line; controls are locked while it runs
--   cinematic     lines advance by themselves; a choice waits for the player (a timed one ends on its own)
--   radio         lines advance by themselves, queued per player, one radio dialogue at a time
-- Conversations and cinematics are one at a time per player too, in the order they were started.
-- A node whose `cond` fails is skipped to its `next`; a choice whose `cond` fails isn't offered.
--
--   start(player, dialogueId, opts?) -> boolean   opts.block = true yields until it has ended; opts.urgent
--                                                 (radio) plays at once over what is playing, the queue waits
--   isActive(player) -> dialogueId?      stop(player)       condHolds(player, cond) -> boolean
--   NodeShown: Signal(player, dialogueId, nodeId)          Ended: Signal(player, dialogueId)
--   Action: Signal(player, dialogueId, nodeId, action)     (a node's NPC move or gesture, for NPCService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CharacterService = require(script.Parent.CharacterService)
local EvidenceService = require(script.Parent.EvidenceService)
local FlagService = require(script.Parent.FlagService)
local RelationshipService = require(script.Parent.RelationshipService)

local TAG = "DialogueService"
local LINE_GAP = 0.25 -- seconds of silence between two lines that advance by themselves
local MIN_SHOWN = 0.25 -- an advance this soon after a line was sent is a double press
local MAX_STEPS = 64 -- guard against a cycle of skipped nodes

local DialogueService = {}

DialogueService.NodeShown = Signal.new()
DialogueService.Ended = Signal.new()
DialogueService.Action = Signal.new()

local dialogues = {} -- [id] = dialogue
local radio = {} -- [player] = { lines = { item }, speaking, holdUntil }
local talk = {} -- [player] = { queue = { item }, running, current = state? }

local function durationOf(node)
	return node.duration or math.max(2.2, 0.06 * #node.text)
end

----------------------------------------------------------------------------------------------------------------
-- Conditions and effects (docs/13 §2)
----------------------------------------------------------------------------------------------------------------
local COMPARE = {
	[">="] = function(a, b) return a >= b end,
	["<="] = function(a, b) return a <= b end,
	[">"] = function(a, b) return a > b end,
	["<"] = function(a, b) return a < b end,
	["=="] = function(a, b) return a == b end,
}

function DialogueService.condHolds(player, cond)
	if cond == nil then
		return true
	elseif cond.flag then
		return FlagService.has(player, cond.flag)
	elseif cond.notFlag then
		return not FlagService.has(player, cond.notFlag)
	elseif cond.rel then
		local compare = COMPARE[cond.rel[2]]
		return compare ~= nil and compare(RelationshipService.get(player, cond.rel[1]), cond.rel[3])
	elseif cond.all then
		for _, part in ipairs(cond.all) do
			if not DialogueService.condHolds(player, part) then
				return false
			end
		end
		return true
	elseif cond.any then
		for _, part in ipairs(cond.any) do
			if DialogueService.condHolds(player, part) then
				return true
			end
		end
		return false
	end
	return true
end

local function applyEffects(player, effects, reason)
	for _, effect in ipairs(effects or {}) do
		if effect.flag then
			FlagService.set(player, effect.flag)
		elseif effect.clearFlag then
			FlagService.clear(player, effect.clearFlag)
		elseif effect.rel then
			RelationshipService.add(player, effect.rel, effect.add or 0, reason, effect.toast)
		elseif effect.evidence then
			EvidenceService.collect(player, effect.evidence)
		elseif effect.reward then
			Log.info(TAG, "reward %s for %s waits for ProgressionService (Phase 6)", tostring(effect.reward), player.Name)
		elseif effect.toast then
			Net.fireClient(player, "UI_Toast", { text = effect.toast })
		end
	end
end

-- The first node from nodeId on whose condition holds; nil when the dialogue ends there.
local function resolve(player, dialogue, nodeId)
	for _ = 1, MAX_STEPS do
		if nodeId == nil then
			return nil
		end
		local node = dialogue.nodes[nodeId]
		if not node then
			Log.warn(TAG, "dialogue has no node %s", tostring(nodeId))
			return nil
		end
		if DialogueService.condHolds(player, node.cond) then
			return nodeId
		end
		nodeId = node.next
	end
	Log.warn(TAG, "dialogue skipped more than %d nodes in a row", MAX_STEPS)
	return nil
end

-- Sends a node to the player: its pause first, then its effects and action, then Dialogue_Node.
local function show(player, id, dialogue, nodeId)
	local node = dialogue.nodes[nodeId]
	if node.pause then
		task.wait(node.pause)
	end
	applyEffects(player, node.effects, id .. ":" .. nodeId)
	if node.action then
		DialogueService.Action:Fire(player, id, nodeId, node.action)
	end
	local payload = { dialogueId = id, nodeId = nodeId, mode = dialogue.mode }
	if node.choices then
		local allowed = {}
		for index, choice in ipairs(node.choices) do
			if DialogueService.condHolds(player, choice.cond) then
				table.insert(allowed, index)
			end
		end
		if #allowed > 0 then
			payload.choices, payload.timer = allowed, node.timer
		end
	end
	Net.fireClient(player, "Dialogue_Node", payload)
	DialogueService.NodeShown:Fire(player, id, nodeId)
	return node, payload
end

----------------------------------------------------------------------------------------------------------------
-- Radio: lines advance by themselves, one dialogue at a time per player
----------------------------------------------------------------------------------------------------------------
local function radioOf(player)
	local state = radio[player]
	if not state then
		state = { lines = {}, speaking = false, holdUntil = 0 }
		radio[player] = state
	end
	return state
end

local function playRadio(player, id, dialogue, holdOff)
	local nodeId = resolve(player, dialogue, dialogue.start)
	while nodeId and player.Parent do
		if holdOff then
			holdOff()
		end
		local node = show(player, id, dialogue, nodeId)
		task.wait(durationOf(node) + LINE_GAP)
		nodeId = resolve(player, dialogue, node.next)
	end
	DialogueService.Ended:Fire(player, id)
end

local function queueRadio(player, id, block)
	local state = radioOf(player)
	local item = { id = id, done = false }
	table.insert(state.lines, item)
	if not state.speaking then
		state.speaking = true
		task.spawn(function()
			while #state.lines > 0 and player.Parent do
				local current = table.remove(state.lines, 1)
				-- An urgent line has the radio until it is over.
				playRadio(player, current.id, dialogues[current.id], function()
					while os.clock() < state.holdUntil and player.Parent do
						task.wait(0.1)
					end
				end)
				current.done = true
			end
			state.speaking = false
		end)
	end
	while block and not item.done and player.Parent do
		task.wait(0.1)
	end
end

local function urgentRadio(player, id, dialogue)
	local total, nodeId = 0, resolve(player, dialogue, dialogue.start)
	while nodeId do
		local node = dialogue.nodes[nodeId]
		total += durationOf(node) + LINE_GAP + (node.pause or 0)
		nodeId = resolve(player, dialogue, node.next)
	end
	local state = radioOf(player)
	state.holdUntil = math.max(state.holdUntil, os.clock() + total)
	task.spawn(playRadio, player, id, dialogue)
end

----------------------------------------------------------------------------------------------------------------
-- Conversations and cinematics
----------------------------------------------------------------------------------------------------------------
-- Waits until the player answers (or the timer runs out, or the conversation is stopped). Returns the answer.
local function await(player, state, timer)
	local started = os.clock()
	while state.answer == nil and player.Parent and talk[player] and talk[player].current == state do
		if timer and os.clock() - started >= timer then
			break
		end
		task.wait(0.05)
	end
	return state.answer
end

local function runTalk(player, id, dialogue)
	local slot = talk[player]
	local state = { id = id }
	slot.current = state
	local locks = dialogue.mode == "conversation"
	if locks then
		CharacterService.setControlLocked(player, true)
	end
	local nodeId = resolve(player, dialogue, dialogue.start)
	while nodeId and player.Parent and slot.current == state do
		local node, payload = show(player, id, dialogue, nodeId)
		state.nodeId, state.shownAt, state.answer = nodeId, os.clock(), nil
		local nextId = node.next
		if payload.choices then
			state.waiting, state.allowed = "choose", payload.choices
			local chosen = await(player, state, node.timer)
			if chosen == nil then
				-- Timed out (or nobody answered): the node's timeoutChoice, else its last offered choice.
				chosen = if node.timeoutChoice and table.find(payload.choices, node.timeoutChoice) then node.timeoutChoice else payload.choices[#payload.choices]
			end
			local choice = node.choices[chosen]
			applyEffects(player, choice.effects, ("%s:%s:%d"):format(id, nodeId, chosen))
			nextId = choice.next or node.next
		elseif dialogue.mode == "conversation" then
			state.waiting = "advance"
			await(player, state, nil)
		else
			state.waiting = nil
			task.wait(durationOf(node) + LINE_GAP)
		end
		state.waiting = nil
		nodeId = resolve(player, dialogue, nextId)
	end
	if slot.current == state then
		slot.current = nil
	end
	applyEffects(player, dialogue.onEnd, id .. ":end")
	if locks then
		CharacterService.setControlLocked(player, false)
	end
	if player.Parent then
		Net.fireClient(player, "Dialogue_End", { dialogueId = id })
	end
	DialogueService.Ended:Fire(player, id)
end

local function queueTalk(player, id, block)
	local slot = talk[player]
	if not slot then
		slot = { queue = {}, running = false }
		talk[player] = slot
	end
	local item = { id = id, done = false }
	table.insert(slot.queue, item)
	if not slot.running then
		slot.running = true
		task.spawn(function()
			while #slot.queue > 0 and player.Parent do
				local current = table.remove(slot.queue, 1)
				local ok, problem = pcall(runTalk, player, current.id, dialogues[current.id])
				if not ok then
					Log.error(TAG, "dialogue %s failed: %s", current.id, tostring(problem))
					CharacterService.setControlLocked(player, false)
				end
				current.done = true
			end
			slot.running = false
		end)
	end
	while block and not item.done and player.Parent do
		task.wait(0.1)
	end
end

----------------------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------------------
function DialogueService.start(player, id, opts)
	opts = opts or {}
	local dialogue = dialogues[id]
	if not dialogue then
		Log.warn(TAG, "unknown dialogue %s", tostring(id))
		return false
	end
	if dialogue.mode == "radio" then
		if opts.urgent then
			urgentRadio(player, id, dialogue)
		else
			queueRadio(player, id, opts.block == true)
		end
	else
		queueTalk(player, id, opts.block == true)
	end
	return true
end

function DialogueService.isActive(player)
	local slot = talk[player]
	return slot and slot.current and slot.current.id or nil
end

-- Ends the running conversation (its onEnd effects still apply) and drops what was queued.
function DialogueService.stop(player)
	local slot = talk[player]
	if slot then
		table.clear(slot.queue)
		slot.current = nil
	end
	local state = radio[player]
	if state then
		table.clear(state.lines)
	end
end

function DialogueService.get(id)
	return dialogues[id]
end

function DialogueService.Init()
	for _, module in ipairs(Shared:WaitForChild("Dialogue"):GetChildren()) do
		if module:IsA("ModuleScript") and module.Name ~= "Speakers" then
			for id, dialogue in pairs(require(module)) do
				if dialogues[id] then
					Log.warn(TAG, "dialogue %s is defined twice", id)
				end
				dialogues[id] = dialogue
			end
		end
	end
end

function DialogueService.Start()
	Net.on("Dialogue_Advance", function(player, payload)
		local slot = talk[player]
		local state = slot and slot.current
		if state and state.waiting == "advance" and payload.dialogueId == state.id and payload.nodeId == state.nodeId and os.clock() - state.shownAt >= MIN_SHOWN then
			state.answer = true
		end
	end)
	Net.on("Dialogue_Choose", function(player, payload)
		local slot = talk[player]
		local state = slot and slot.current
		if state and state.waiting == "choose" and payload.dialogueId == state.id and payload.nodeId == state.nodeId and table.find(state.allowed, payload.index) then
			state.answer = payload.index
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		DialogueService.stop(player)
		talk[player], radio[player] = nil, nil
	end)
end

return DialogueService
