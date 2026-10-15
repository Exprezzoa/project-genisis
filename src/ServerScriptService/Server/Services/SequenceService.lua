--!nonstrict
-- Server/Services/SequenceService.lua  (docs/13_missions_dialogue_relationships.md §1)
--
-- The Sequence Runner: one per player, stepping through a sequence of Shared/Sequences. A step runs its onEnter
-- actions, shows its objective, waits for its completion condition (with side listeners running in `parallel`),
-- runs onComplete, saves its checkpoint and moves on. Steps name things by id only; this service turns the
-- signals of the other services into the conditions' events.
--
--   start(player, sequenceId, stepId?, restoring?)     stop(player)     (a rejoining player resumes by itself)
--   jump(player, stepId) -> ok, message                 the step as a checkpoint load would enter it (/step)
--   loadCheckpoint(player, checkpoint) -> ok, message   the step that checkpoint loads into (docs/05 §11)
--   notify(player, kind, key, who?)                     feed an event by hand: "trigger" | "interact" | "event" | "line"
--   say(player, dialogueId, urgent?)                    a radio dialogue outside the steps
--   getState(player) -> { sequenceId, stepId, objective, args, armed }?
--   StepEntered / StepCompleted: Signal(player, stepId)       ZoneState: Signal(zone, key, value)
--
-- The actions are in Server/Sequence/Actions, the completion conditions in Server/Sequence/Conditions (docs/16
-- §2). Dialogues of every mode go through DialogueService. A step's onFail runs when the player's Frame is
-- disabled during it, then its checkpoint is loaded.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local Actions = require(script.Parent.Parent.Sequence.Actions)
local Conditions = require(script.Parent.Parent.Sequence.Conditions)
local CharacterService = require(script.Parent.CharacterService)
local CinematicService = require(script.Parent.CinematicService)
local CombatService = require(script.Parent.CombatService)
local DialogueService = require(script.Parent.DialogueService)
local FlagService = require(script.Parent.FlagService)
local FrameService = require(script.Parent.FrameService)
local InteractionService = require(script.Parent.InteractionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RetryService = require(script.Parent.RetryService)
local TitanService = require(script.Parent.TitanService)
local TriggerService = require(script.Parent.TriggerService)

local TAG = "SequenceService"
local PLAYER_UNIT = "02"
local POLL = 0.25 -- seconds between looks at the conditions nothing announces (proximity)
local FAIL_CARD = 2.5 -- the FRAME DISABLED card (docs/14) before a failed step's onFail runs
local RESTORE_FADE = 0.6 -- seconds of the fade in after a checkpoint load

local SequenceService = {}

SequenceService.StepEntered = Signal.new()
SequenceService.StepCompleted = Signal.new()
SequenceService.ZoneState = Signal.new()

local sequences = {} -- [id] = sequence
local runners = {} -- [player] = runner
local gated = {} -- [interactId] = true: prompts that some step switches on and off

local enter, gate -- forward

----------------------------------------------------------------------------------------------------------------
-- State for the client, and checkpoints
----------------------------------------------------------------------------------------------------------------
local function waypointsOf(runner, spec)
	local list = {}
	for _, entry in ipairs(if spec == nil then {} elseif spec[1] then spec else { spec }) do
		if entry.spawn then
			local cframe = CharacterService.getSpawnCFrame(entry.spawn)
			if cframe then
				table.insert(list, cframe.Position)
			end
		elseif entry.pos then
			table.insert(list, entry.pos)
		elseif entry.interact then
			-- The interactable itself, unless the player has the flag that says it is done.
			if not (entry.unlessFlag and FlagService.has(runner.player, entry.unlessFlag)) then
				for _, part in ipairs(CollectionService:GetTagged("Interactable")) do
					if part:GetAttribute("InteractId") == entry.interact and part:IsA("BasePart") then
						table.insert(list, part.Position)
					end
				end
			end
		elseif entry.entity == "Frame:Player" then
			local frame = FrameService.getFrame(PLAYER_UNIT)
			if frame and frame.PrimaryPart then
				table.insert(list, frame.PrimaryPart.Position)
			end
		end
	end
	return list
end

local function publish(runner)
	local step = runner.step
	Net.fireClient(runner.player, "Seq_State", {
		sequenceId = runner.sequence.id, stepId = step and step.id, objectiveId = runner.objective, objectiveArgs = runner.args,
		optionalIds = runner.optional or {},
		waypoints = if step then waypointsOf(runner, step.waypoint) else {},
	})
end

local function save(runner, checkpoint)
	local sequenceId = runner.sequence.id
	PlayerDataService.update(runner.player, function(profile)
		profile.story.sequenceId = sequenceId
		profile.story.checkpoint = checkpoint
	end)
	Log.info(TAG, "%s reached checkpoint %s", runner.player.Name, checkpoint)
end

----------------------------------------------------------------------------------------------------------------
-- The runner
----------------------------------------------------------------------------------------------------------------
local function complete(runner, token)
	if runner.token ~= token or not runner.armed then
		return
	end
	runner.armed = false
	local step = runner.step
	task.spawn(function()
		Actions.run(runner, token, step.onComplete)
		if runner.token ~= token then
			return
		end
		if step.checkpoint and not step.checkpointOnEnter then
			save(runner, step.checkpoint)
		end
		SequenceService.StepCompleted:Fire(runner.player, step.id)
		enter(runner, runner.index + 1, false)
	end)
end

function enter(runner, index, restoring)
	runner.token += 1
	local token = runner.token
	local step = runner.sequence.steps[index]
	runner.index, runner.step, runner.armed = index, step, false
	runner.watch, runner.side = nil, {}
	runner.args = {}
	runner.objective = step and step.objective
	runner.optional = if step and step.optional then table.clone(step.optional) else {}
	if not step then
		Log.info(TAG, "%s finished %s as far as it is written", runner.player.Name, runner.sequence.id)
		publish(runner)
		return
	end
	Log.info(TAG, "%s enters %s%s", runner.player.Name, step.id, if restoring then " (restored)" else "")
	if step.checkpoint and step.checkpointOnEnter and not restoring then
		save(runner, step.checkpoint)
	end
	publish(runner)
	SequenceService.StepEntered:Fire(runner.player, step.id)
	task.spawn(function()
		-- A load runs the step's onRestore if it has one, else its onEnter without what is marked skipOnRestore,
		-- behind a black screen that lifts once the player stands where the step wants them.
		if restoring then
			Net.fireClient(runner.player, "Fade", { to = 1, duration = 0 })
		end
		Actions.run(runner, token, if restoring and step.onRestore then step.onRestore else step.onEnter, restoring)
		if runner.token ~= token then
			return
		end
		if restoring then
			Net.fireClient(runner.player, "Fade", { to = 0, duration = RESTORE_FADE })
		end
		for _, listener in ipairs(step.parallel or {}) do
			table.insert(runner.side, { watch = Conditions.compile(runner, token, listener.when), actions = listener.actions, once = listener.once ~= false })
		end
		runner.watch = if step.complete then Conditions.compile(runner, token, step.complete) else nil
		runner.armed = true
		publish(runner)
		if runner.watch and runner.watch.ready() then
			complete(runner, token)
		end
	end)
end

function SequenceService.notify(player, kind, key, who)
	local runner = runners[player]
	if not (runner and runner.armed) then
		return
	end
	local token = runner.token
	for _, listener in ipairs(runner.side) do
		if not listener.spent and listener.watch.on(kind, key, who) then
			listener.spent = listener.once
			task.spawn(Actions.run, runner, token, listener.actions)
		end
	end
	if runner.watch and runner.watch.on(kind, key, who) then
		complete(runner, token)
	end
end

-- The player's Frame was disabled during a step that says what happens then (docs/13 §1.4): the card, the step's
-- onFail actions, and the last checkpoint is loaded again.
local function fail(runner)
	local token = runner.token
	local step = runner.step
	runner.armed = false
	task.spawn(function()
		task.wait(FAIL_CARD)
		Actions.run(runner, token, step.onFail)
		if runner.token ~= token or not runner.player.Parent then
			return
		end
		local profile = PlayerDataService.getProfile(runner.player)
		local checkpoint = profile and profile.story.checkpoint
		local ok, message = SequenceService.loadCheckpoint(runner.player, checkpoint)
		if not ok then
			Log.warn(TAG, "retry of %s: %s", step.id, tostring(message))
		end
	end)
end

function SequenceService.start(player, sequenceId, stepId, restoring)
	local sequence = sequences[sequenceId]
	if not sequence then
		return false, "unknown sequence " .. tostring(sequenceId)
	end
	local index = 1
	if stepId then
		index = nil
		for candidate, step in ipairs(sequence.steps) do
			if step.id == stepId then
				index = candidate
			end
		end
		if not index then
			return false, ("no step %s in %s"):format(tostring(stepId), sequenceId)
		end
	end
	local runner = runners[player]
	if not runner then
		runner = { player = player, token = 0, titans = {} }
		runners[player] = runner
	end
	runner.sequence = sequence
	if restoring then
		-- A load starts as clean as a rejoin: every step-gated prompt off (the step's own actions switch on what it
		-- needs), no Titan left from the step it jumps away from, and no cinematic, conversation or card still up
		-- from it (a non-blocking one outlives its step's actions).
		gate(player)
		for id in pairs(runner.titans) do
			Actions.handlers.despawnTitan(runner, { id = id })
		end
		local cinematic = CinematicService.isPlaying(player)
		if cinematic then
			CinematicService.stop(player, cinematic)
		end
		DialogueService.stop(player)
		Net.fireClient(player, "UI_Card", { show = false, dismiss = true }) -- a card still up (one waiting for Continue too)
	end
	enter(runner, index, restoring == true)
	return true, sequence.steps[index].id
end

function SequenceService.jump(player, stepId)
	local runner = runners[player]
	return SequenceService.start(player, if runner then runner.sequence.id else "CH1", stepId, true)
end

function SequenceService.loadCheckpoint(player, checkpoint)
	for sequenceId, sequence in pairs(sequences) do
		local stepId = sequence.checkpoints and sequence.checkpoints[checkpoint]
		if stepId then
			return SequenceService.start(player, sequenceId, stepId, true)
		end
	end
	return false, "no step is mapped to checkpoint " .. tostring(checkpoint)
end

function SequenceService.stop(player)
	local runner = runners[player]
	if runner then
		runner.token += 1
		runner.armed = false
		runners[player] = nil
		for id in pairs(runner.titans) do
			Actions.handlers.despawnTitan(runner, { id = id })
		end
	end
end

-- A radio dialogue from outside the steps (DialogueService): queued behind what the player hears; urgent = true
-- plays it at once over whatever line is showing (Overwatch's bounds warning) and the queue waits.
function SequenceService.say(player, dialogueId, urgent)
	DialogueService.start(player, dialogueId, { urgent = urgent == true })
end

function SequenceService.getState(player)
	local runner = runners[player]
	if not runner then
		return nil
	end
	return {
		sequenceId = runner.sequence.id, stepId = runner.step and runner.step.id, objective = runner.objective, args = runner.args,
		armed = runner.armed,
	}
end

function SequenceService.Init()
	Actions.bind({ publish = publish, save = save, zoneState = SequenceService.ZoneState })
	Conditions.bind({ publish = publish, notify = SequenceService.notify })
	for _, module in ipairs(Shared:WaitForChild("Sequences"):GetChildren()) do
		if module:IsA("ModuleScript") then
			local sequence = require(module)
			sequences[sequence.id] = sequence
			-- Which prompts do the steps switch? Those are step-gated (docs/13 §4).
			local function scan(list)
				for _, action in ipairs(list or {}) do
					if action[1] == "prompt" then
						gated[action.id] = true
					end
				end
			end
			for _, step in ipairs(sequence.steps) do
				scan(step.onEnter)
				scan(step.onComplete)
				scan(step.onRestore)
				for _, listener in ipairs(step.parallel or {}) do
					scan(listener.actions)
				end
			end
		end
	end
end

-- A step-gated prompt is on in the world but off for each player until that player's step switches it on:
-- InteractionService's per-player switch can only take a prompt away, not add one that is off for everybody.
function gate(player)
	for interactId in pairs(gated) do
		InteractionService.setEnabled(interactId, false, player)
	end
end

function SequenceService.Start()
	for interactId in pairs(gated) do
		if InteractionService.exists(interactId) then
			InteractionService.setEnabled(interactId, true)
		else
			Log.warn(TAG, "a step switches prompt %s, which isn't in the map", interactId)
		end
	end
	Players.PlayerAdded:Connect(gate)
	for _, player in ipairs(Players:GetPlayers()) do
		gate(player)
	end
	TriggerService.Entered:Connect(function(player, triggerId, who)
		SequenceService.notify(player, "trigger", triggerId, who)
	end)
	InteractionService.Interacted:Connect(function(player, interactId)
		SequenceService.notify(player, "interact", interactId)
	end)
	DialogueService.NodeShown:Connect(function(player, _, nodeId)
		SequenceService.notify(player, "line", nodeId)
	end)
	-- A card that waits for Continue was closed (Actions "card", Mission Complete).
	Net.on("UI_CardDone", function(player, payload)
		local runner = runners[player]
		if runner then
			runner.cardDone = payload.kind
		end
	end)
	-- A tutorial card is up on the client: its flag, if this runner sent it (Actions "tutorial").
	Net.on("Tutorial_Seen", function(player, payload)
		local runner = runners[player]
		if runner and runner.tutorials and runner.tutorials[payload.id] then
			runner.tutorials[payload.id] = nil
			FlagService.set(player, payload.id)
		end
	end)
	FrameService.Boarded:Connect(function(player)
		SequenceService.notify(player, "event", "FrameBoarded")
	end)
	FrameService.Dismounted:Connect(function(player)
		SequenceService.notify(player, "event", "FrameDismounted")
	end)
	TitanService.Died:Connect(function()
		for player in pairs(runners) do
			SequenceService.notify(player, "event", "TitanDefeated")
		end
	end)
	CombatService.FrameDisabled:Connect(function(frame)
		local player = Players:GetPlayerByUserId(frame:GetAttribute("Pilot") or 0)
		if player then
			local runner = runners[player]
			if runner and runner.armed and runner.step and runner.step.onFail then
				fail(runner)
			else
				SequenceService.notify(player, "event", "FrameDisabled")
			end
		end
	end)
	-- A step with onFail handles its own retry; otherwise RetryService's plain one runs.
	RetryService.setOwner(function(frame)
		local player = Players:GetPlayerByUserId(frame:GetAttribute("Pilot") or 0)
		local runner = player and runners[player]
		return runner ~= nil and runner.step ~= nil and runner.step.onFail ~= nil
	end)
	-- Conditions nothing announces are looked at a few times a second.
	task.spawn(function()
		while true do
			task.wait(POLL)
			for player, runner in pairs(runners) do
				if runner.armed then
					SequenceService.notify(player, "tick", "")
				end
			end
		end
	end)
	-- A returning player goes back to the saved checkpoint as soon as their first character exists (docs/13 §1.4,
	-- docs/05 §11). A checkpoint no step loads into (the hub's, until Phase 5) leaves them where they spawned; a
	-- profile without one starts the chapter.
	local resumed = {}
	CharacterService.Spawned:Connect(function(player)
		if resumed[player] then
			return
		end
		resumed[player] = true
		local profile = PlayerDataService.getProfile(player)
		local checkpoint = profile and profile.story.checkpoint
		if checkpoint then
			task.defer(function()
				local _, message = SequenceService.loadCheckpoint(player, checkpoint)
				Log.info(TAG, "%s resumes at %s: %s", player.Name, checkpoint, tostring(message))
			end)
		else
			-- A new profile starts the chapter at its first step (S08 until Phase 5 writes S01-S07).
			task.defer(SequenceService.start, player, "CH1")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		resumed[player] = nil
		SequenceService.stop(player)
	end)
end

return SequenceService
