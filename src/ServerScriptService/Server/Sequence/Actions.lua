--!nonstrict
-- Server/Sequence/Actions.lua  (docs/13_missions_dialogue_relationships.md §1.2)
--
-- The Sequence Runner's actions. Each takes the runner and the action's table; an action that blocks yields.
-- SequenceService binds what the actions need from the runner itself (radio lines, the client's state,
-- checkpoints, the ZoneState signal) before any step runs.
--
--   Actions.bind({ speak, publish, save, zoneState })
--   Actions.run(runner, token, list, restoring)        runs a list; stops when the runner moved on
--   Actions.handlers[name](runner, action)
--
-- Built so far (the rest of docs/13 §1.2 comes with the steps that need it): fade, lighting, teleport, wait,
-- setFlag, clearFlag, objective, prompt, dialogue (radio lines, stepped by SequenceService until DialogueService
-- exists), tutorial (a toast for now), toast, zoneState, checkpoint, frame (forceBoard, park, repair),
-- spawnTitan, despawnTitan, titanCommand (with the Watcher's stand-in: WatcherPath, PeelRover, TakeCanister,
-- WatcherFace), unlock (a case's lock light, S32).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local Services = script.Parent.Parent.Services
local CharacterService = require(Services.CharacterService)
local CombatService = require(Services.CombatService)
local FlagService = require(Services.FlagService)
local FrameService = require(Services.FrameService)
local InteractionService = require(Services.InteractionService)
local TitanService = require(Services.TitanService)
local WatcherStandIn = require(script.Parent.Parent.Titans.WatcherStandIn)

local TAG = "SequenceService"
local PLAYER_UNIT = "02"
local LATTICE_CYAN = Color3.fromHex("#7FE3F0") -- docs/06 palette: resonance only
local LIGHT_OFF = Color3.fromHex("#2A2D31") -- STEEL_DARK

local Actions = {}

local hooks = {}
local actions = {}
Actions.handlers = actions

function Actions.bind(given)
	hooks = given
end

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
	hooks.publish(runner)
end

-- unlessFlag: leave the prompt alone for a player who has the flag (a clue found before a reload).
function actions.prompt(runner, a)
	if a.unlessFlag and FlagService.has(runner.player, a.unlessFlag) then
		return
	end
	InteractionService.setEnabled(a.id, a.enabled == true, runner.player)
end

function actions.dialogue(runner, a)
	hooks.speak(runner, a.id, a.block == true)
end

-- Until TutorialController exists a tutorial is a toast, shown once per profile (flag TUT_<id>).
function actions.tutorial(runner, a)
	local flag = "TUT_" .. string.gsub(a.id, "^TUT_", "")
	if not FlagService.has(runner.player, flag) then
		FlagService.set(runner.player, flag)
		Net.fireClient(runner.player, "UI_Toast", { text = a.text or a.id })
	end
end

function actions.toast(runner, a)
	Net.fireClient(runner.player, "UI_Toast", { text = a.text })
end

function actions.zoneState(_, a)
	local map = workspace:FindFirstChild("Map")
	local zone = map and map:FindFirstChild(a.zone)
	if zone then
		zone:SetAttribute(a.key, a.value)
	end
	hooks.zoneState:Fire(a.zone, a.key, a.value)
end

function actions.checkpoint(runner, a)
	hooks.save(runner, a.id)
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
	elseif a.command == "park" then
		-- Back in its bay, the pilot on foot at a spawn (the return to the hub).
		local cframe = CharacterService.getSpawnCFrame(a.spawn)
		if cframe then
			FrameService.park(player, cframe)
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
		if model:GetAttribute("StandIn") then
			WatcherStandIn.despawn(model)
		else
			TitanService.despawn(model)
		end
	end
end

function actions.spawnTitan(runner, a)
	actions.despawnTitan(runner, a)
	local cframe = CharacterService.getSpawnCFrame(a.spawn)
	if not cframe then
		Log.warn(TAG, "spawnTitan: no spawn %s", tostring(a.spawn))
		return
	end
	if a.type == "Watcher" then
		-- Until its rig exists the Watcher is a stand-in the server slides about (roadmap Phase 4).
		local model = WatcherStandIn.spawn(cframe)
		model:SetAttribute("StandIn", true)
		runner.titans[a.id] = model
		return
	end
	runner.titans[a.id] = TitanService.spawn(a.type, cframe, { dormant = a.state == "Dormant", firstSweepWindup = a.firstSweepWindup })
end

-- A named prop of the map that a step moves (the rover's roof, the canister).
local function mapPart(name)
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild(name, true)
end

-- The lock light of an interactable's model: cyan for 0.6 s, then off (docs/05 S32, clue 10). Doesn't yield.
function actions.unlock(_, a)
	for _, part in ipairs(CollectionService:GetTagged("Interactable")) do
		local light = part:GetAttribute("InteractId") == a.id and part.Parent and part.Parent:FindFirstChild("LockLight")
		if light then
			light.Color = LATTICE_CYAN
			task.delay(0.6, function()
				light.Material = Enum.Material.SmoothPlastic
				light.Color = LIGHT_OFF
			end)
		end
	end
end

local function navPoint(id)
	for _, node in ipairs(CollectionService:GetTagged("NavNode")) do
		if node:GetAttribute("NavId") == id and node:IsA("BasePart") then
			return node.Position
		end
	end
	return nil
end

function actions.titanCommand(runner, a)
	local model = runner.titans[a.id]
	if not (model and model.Parent) then
		return
	end
	if a.command == "WatcherPath" then
		-- Along nav nodes in `seconds`; block = true waits until it has arrived.
		local points = {}
		for _, id in ipairs(a.nodes) do
			local point = navPoint(id)
			if point then
				table.insert(points, point)
			end
		end
		if a.block then
			WatcherStandIn.walk(model, points, a.seconds)
		else
			task.spawn(WatcherStandIn.walk, model, points, a.seconds)
		end
	elseif a.command == "PeelRover" then
		local panel = mapPart("RoofPanel")
		if panel then
			WatcherStandIn.peel(panel, 110, 1.5)
		end
	elseif a.command == "TakeCanister" then
		WatcherStandIn.take(model, mapPart("TV_Canister"))
	elseif a.command == "WatcherFace" then
		-- Turns to look at the player's Frame (a.target = "Frame:Player") over a.seconds.
		local frame = FrameService.getPiloted(runner.player) or FrameService.getFrame(PLAYER_UNIT)
		if frame and frame.PrimaryPart then
			WatcherStandIn.face(model, frame.PrimaryPart.Position, a.seconds or 0.6)
		end
	else
		TitanService.command(model, a.command)
	end
end

function Actions.run(runner, token, list, restoring)
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

return Actions
