--!nonstrict
-- Server/Services/SequenceService.lua  (docs/13_missions_dialogue_relationships.md §1)
--
-- The Sequence Runner: one per player, stepping through a sequence of Shared/Sequences. A step runs its onEnter
-- actions, shows its objective, waits for its completion condition (with side listeners running in `parallel`),
-- runs onComplete, saves its checkpoint and moves on. Steps name things by id only; this service turns the
-- signals of the other services into the conditions' events.
--
--   start(player, sequenceId, stepId?, restoring?)     stop(player)
--   jump(player, stepId) -> ok, message                 the step as a checkpoint load would enter it (/step)
--   loadCheckpoint(player, checkpoint) -> ok, message   the step that checkpoint loads into (docs/05 §11)
--   notify(player, kind, key, who?)                     feed an event by hand: "trigger" | "interact" | "event"
--   getState(player) -> { sequenceId, stepId, objective, args, armed }?
--   StepEntered / StepCompleted: Signal(player, stepId)       ZoneState: Signal(zone, key, value)
--
-- Built so far (the rest of docs/13 §1.2-1.3 comes with the steps that need it): actions fade, lighting,
-- teleport, wait, setFlag, clearFlag, objective, prompt, dialogue (radio lines, stepped here until
-- DialogueService exists), tutorial (a toast for now), zoneState, checkpoint, frame (forceBoard, repair),
-- spawnTitan, despawnTitan, titanCommand; conditions trigger, interact, counter, event, timer, proximity, any,
-- all. A step's onFail runs when the player's Frame is disabled during it, then its checkpoint is loaded.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local FlagService = require(script.Parent.FlagService)
local FrameService = require(script.Parent.FrameService)
local InteractionService = require(script.Parent.InteractionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RetryService = require(script.Parent.RetryService)
local TitanService = require(script.Parent.TitanService)
local TriggerService = require(script.Parent.TriggerService)

local TAG = "SequenceService"
local LINE_GAP = 0.25 -- seconds of silence between two radio lines
local PLAYER_UNIT = "02"
local POLL = 0.25 -- seconds between looks at the conditions nothing announces (proximity)
local FAIL_CARD = 2.5 -- the FRAME DISABLED card (docs/14) before a failed step's onFail runs

local SequenceService = {}

SequenceService.StepEntered = Signal.new()
SequenceService.StepCompleted = Signal.new()
SequenceService.ZoneState = Signal.new()

local sequences = {} -- [id] = sequence
local dialogues = {} -- [id] = dialogue
local runners = {} -- [player] = runner
local gated = {} -- [interactId] = true: prompts that some step switches on and off

local enter, gate -- forward

----------------------------------------------------------------------------------------------------------------
-- Radio lines: one dialogue at a time per player, in the order they were asked for.
----------------------------------------------------------------------------------------------------------------
local function speak(runner, id, block)
	local dialogue = dialogues[id]
	if not dialogue then
		Log.warn(TAG, "unknown dialogue %s", tostring(id))
		return
	end
	local item = { id = id, done = false }
	table.insert(runner.lines, item)
	if not runner.speaking then
		runner.speaking = true
		task.spawn(function()
			while #runner.lines > 0 and runner.player.Parent do
				local current = table.remove(runner.lines, 1)
				local spoken = dialogues[current.id]
				local nodeId = spoken.start
				while nodeId and runner.player.Parent do
					local node = spoken.nodes[nodeId]
					if node.pause then
						task.wait(node.pause)
					end
					Net.fireClient(runner.player, "Dialogue_Node", { dialogueId = current.id, nodeId = nodeId, mode = spoken.mode })
					task.wait((node.duration or math.max(2.2, 0.06 * #node.text)) + LINE_GAP) -- docs/13 §2
					nodeId = node.next
				end
				current.done = true
			end
			runner.speaking = false
		end)
	end
	while block and not item.done and runner.player.Parent do
		task.wait(0.1)
	end
end

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
-- Actions (docs/13 §1.2). Each takes the runner and the action's table; a yielding action is one that blocks.
----------------------------------------------------------------------------------------------------------------
local actions = {}

function actions.fade(runner, a)
	Net.fireClient(runner.player, "Fade", { to = a.to, duration = a.duration or 0 })
	if a.block ~= false and (a.duration or 0) > 0 then
		task.wait(a.duration)
	end
end

function actions.lighting(runner, a)
	Net.fireClient(runner.player, "Lighting_Set", { preset = a.preset, instant = a.instant == true })
end

function actions.teleport(runner, a)
	if a.frame then
		local frame = FrameService.getPiloted(runner.player)
		local cframe = CharacterService.getSpawnCFrame(a.spawn)
		if frame and cframe then
			FrameService.moveTo(frame, cframe)
		else
			Log.warn(TAG, "teleport: %s isn't piloting, or no spawn %s", runner.player.Name, tostring(a.spawn))
		end
	else
		CharacterService.teleport(runner.player, a.spawn)
	end
end

function actions.wait(_, a)
	task.wait(a.seconds or 0)
end

function actions.setFlag(runner, a)
	FlagService.set(runner.player, a.flag)
end

function actions.clearFlag(runner, a)
	FlagService.clear(runner.player, a.flag)
end

function actions.objective(runner, a)
	runner.objective, runner.args = a.id, a.args or {}
	publish(runner)
end

-- unlessFlag: leave the prompt alone for a player who has the flag (a clue found before a reload).
function actions.prompt(runner, a)
	if a.unlessFlag and FlagService.has(runner.player, a.unlessFlag) then
		return
	end
	InteractionService.setEnabled(a.id, a.enabled == true, runner.player)
end

function actions.dialogue(runner, a)
	speak(runner, a.id, a.block == true)
end

-- Until TutorialController exists a tutorial is a toast, shown once per profile (flag TUT_<id>).
function actions.tutorial(runner, a)
	local flag = "TUT_" .. string.gsub(a.id, "^TUT_", "")
	if not FlagService.has(runner.player, flag) then
		FlagService.set(runner.player, flag)
		Net.fireClient(runner.player, "UI_Toast", { text = a.text or a.id })
	end
end

function actions.zoneState(_, a)
	local map = workspace:FindFirstChild("Map")
	local zone = map and map:FindFirstChild(a.zone)
	if zone then
		zone:SetAttribute(a.key, a.value)
	end
	SequenceService.ZoneState:Fire(a.zone, a.key, a.value)
end

function actions.checkpoint(runner, a)
	save(runner, a.id)
end

function actions.frame(runner, a)
	local player = runner.player
	if a.command == "forceBoard" then
		local frame = FrameService.getPiloted(player) or FrameService.getFrame(PLAYER_UNIT)
		local cframe = a.spawn and CharacterService.getSpawnCFrame(a.spawn)
		if frame and cframe then
			FrameService.moveTo(frame, cframe)
		end
		if frame and not FrameService.getPiloted(player) then
			FrameService.board(player, frame, true) -- yields for the fade and the boot
		end
	elseif a.command == "repair" then
		local frame = FrameService.getPiloted(player)
		if frame then
			CombatService.repair(frame)
		end
	else
		Log.warn(TAG, "frame command %s isn't built yet", tostring(a.command))
	end
end

-- Titans of the mission are known to the steps by an id of their own (docs/13 §1.2).
function actions.despawnTitan(runner, a)
	local model = runner.titans[a.id]
	runner.titans[a.id] = nil
	if model and model.Parent then
		TitanService.despawn(model)
	end
end

function actions.spawnTitan(runner, a)
	actions.despawnTitan(runner, a)
	local cframe = CharacterService.getSpawnCFrame(a.spawn)
	if not cframe then
		Log.warn(TAG, "spawnTitan: no spawn %s", tostring(a.spawn))
		return
	end
	runner.titans[a.id] = TitanService.spawn(a.type, cframe, { dormant = a.state == "Dormant", firstSweepWindup = a.firstSweepWindup })
end

function actions.titanCommand(runner, a)
	local model = runner.titans[a.id]
	if model and model.Parent then
		TitanService.command(model, a.command)
	end
end

local function runActions(runner, token, list, restoring)
	for _, action in ipairs(list or {}) do
		if runner.token ~= token or not runner.player.Parent then
			return
		end
		local handler = actions[action[1]]
		if not handler then
			Log.warn(TAG, "action %s isn't built yet (step %s)", tostring(action[1]), runner.step and runner.step.id or "?")
		elseif not (restoring and action.skipOnRestore) then
			local ok, problem = pcall(handler, runner, action)
			if not ok then
				Log.error(TAG, "action %s failed in %s: %s", tostring(action[1]), runner.step and runner.step.id or "?", tostring(problem))
			end
		end
	end
end

----------------------------------------------------------------------------------------------------------------
-- Conditions (docs/13 §1.3): { ready() -> boolean, on(kind, key, who) -> boolean }
----------------------------------------------------------------------------------------------------------------
local function compile(runner, token, cond)
	local kind = cond[1]
	local player = runner.player
	if kind == "trigger" then
		local who = if cond.who == "any" then nil else cond.who
		return {
			ready = function()
				return TriggerService.isInside(player, cond.id, who)
			end,
			on = function(k, key, eventWho)
				return k == "trigger" and key == cond.id and (who == nil or who == eventWho)
			end,
		}
	elseif kind == "interact" or kind == "event" then
		local wanted = if kind == "interact" then cond.id else cond.name
		return {
			ready = function()
				return false
			end,
			on = function(k, key)
				return k == kind and key == wanted
			end,
		}
	elseif kind == "counter" then
		-- n distinct interactions; with `flags` each one is remembered as a story flag and counted again after a reload.
		local found, count = {}, 0
		for _, id in ipairs(cond.ids) do
			local flag = cond.flags and cond.flags[id]
			if flag and FlagService.has(player, flag) then
				found[id] = true
				count += 1
			end
		end
		runner.args = { n = count }
		return {
			ready = function()
				return count >= cond.n
			end,
			on = function(k, key)
				if k == "interact" and table.find(cond.ids, key) and not found[key] then
					found[key] = true
					count += 1
					if cond.flags and cond.flags[key] then
						FlagService.set(player, cond.flags[key])
					end
					runner.args = { n = count }
					publish(runner)
				end
				return count >= cond.n
			end,
		}
	elseif kind == "timer" then
		local elapsed = false
		task.delay(cond.seconds, function()
			elapsed = true
			if runner.token == token then
				SequenceService.notify(player, "timer", "")
			end
		end)
		return {
			ready = function()
				return elapsed
			end,
			on = function()
				return elapsed
			end,
		}
	elseif kind == "proximity" then
		-- The player's Frame (or the character on foot) within `radius` of a spawn marker, along the ground.
		local function near()
			local frame = FrameService.getPiloted(player)
			local character = player.Character
			local body = if frame then frame.PrimaryPart else (character and character:FindFirstChild("HumanoidRootPart"))
			local cframe = CharacterService.getSpawnCFrame(cond.spawn)
			return body ~= nil and cframe ~= nil and ((body.Position - cframe.Position) * Vector3.new(1, 0, 1)).Magnitude <= cond.radius
		end
		return { ready = near, on = near }
	elseif kind == "any" or kind == "all" then
		local children, met = {}, {}
		for index, child in ipairs(cond) do
			if index > 1 then
				table.insert(children, compile(runner, token, child))
			end
		end
		local function tally(test)
			local count = 0
			for index, child in ipairs(children) do
				met[index] = met[index] or test(child)
				count += if met[index] then 1 else 0
			end
			return if kind == "any" then count > 0 else count == #children
		end
		return {
			ready = function()
				return tally(function(child)
					return child.ready()
				end)
			end,
			on = function(k, key, who)
				return tally(function(child)
					return child.on(k, key, who)
				end)
			end,
		}
	end
	error("SequenceService: condition " .. tostring(kind) .. " isn't built yet")
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
		runActions(runner, token, step.onComplete)
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
		-- A load runs the step's onRestore if it has one, else its onEnter without what is marked skipOnRestore.
		runActions(runner, token, if restoring and step.onRestore then step.onRestore else step.onEnter, restoring)
		if runner.token ~= token then
			return
		end
		for _, listener in ipairs(step.parallel or {}) do
			table.insert(runner.side, { watch = compile(runner, token, listener.when), actions = listener.actions, once = listener.once ~= false })
		end
		runner.watch = if step.complete then compile(runner, token, step.complete) else nil
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
			task.spawn(runActions, runner, token, listener.actions)
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
		runActions(runner, token, step.onFail)
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
		runner = { player = player, token = 0, lines = {}, speaking = false, titans = {} }
		runners[player] = runner
	end
	runner.sequence = sequence
	if restoring then
		gate(player) -- a load starts with every step-gated prompt off; the step's own actions switch on what it needs
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
		for _, model in pairs(runner.titans) do
			if model.Parent then
				TitanService.despawn(model)
			end
		end
	end
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
	for _, module in ipairs(Shared:WaitForChild("Dialogue"):GetChildren()) do
		if module:IsA("ModuleScript") and module.Name ~= "Speakers" then
			for id, dialogue in pairs(require(module)) do
				dialogues[id] = dialogue
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
	Players.PlayerRemoving:Connect(SequenceService.stop)
end

return SequenceService
