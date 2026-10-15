--!nonstrict
-- Server/Sequence/Actions.lua  (docs/13_missions_dialogue_relationships.md §1.2)
--
-- The Sequence Runner's actions. Each takes the runner and the action's table; an action that blocks yields.
-- SequenceService binds what the actions need from the runner itself (radio lines, the client's state,
-- checkpoints, the ZoneState signal) before any step runs.
--
--   Actions.bind({ publish, save, zoneState })
--   Actions.run(runner, token, list, restoring)        runs a list; stops when the runner moved on
--   Actions.handlers[name](runner, action)
--
-- Built so far (the rest of docs/13 §1.2 comes with the steps that need it): fade, lighting, teleport, wait,
-- setFlag, clearFlag, objective, prompt, dialogue (any mode, through DialogueService), tutorial (a toast for
-- now), toast, zoneState, checkpoint, frame (forceBoard, park, repair,
-- autoWalk, stopWalk), door, card, spawnTitan, despawnTitan, titanCommand (with the Watcher's stand-in:
-- WatcherPath, PeelRover, TakeCanister, WatcherFace), unlock (a case's lock light, S32), ally (Mara's Unit 01),
-- cinematic, npcs, npc, sit (the player on a seat mark), paLoop (the Central Command PA), controls, barks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local NPCConfig = require(Shared.Config.NPCs)

local Services = script.Parent.Parent.Services
local AllyFrameService = require(Services.AllyFrameService)
local CharacterService = require(Services.CharacterService)
local CinematicService = require(Services.CinematicService)
local DialogueService = require(Services.DialogueService)
local CombatService = require(Services.CombatService)
local FlagService = require(Services.FlagService)
local FrameService = require(Services.FrameService)
local InteractionService = require(Services.InteractionService)
local NPCService = require(Services.NPCService)
local TitanService = require(Services.TitanService)
local Doors = require(script.Parent.Doors)
local SceneActions = require(script.Parent.SceneActions)
local ZoneEffects = require(script.Parent.ZoneEffects)
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

-- { "setFlag", flag, unlessMark = key? }: not when the runner holds that mark (Clean Kill: no failure in the fight).
function actions.setFlag(runner, a)
	if a.unlessMark and runner.marks and runner.marks[a.unlessMark] then
		return
	end
	FlagService.set(runner.player, a.flag)
end

-- { "mark", key, value = true }: something the runner remembers across retries (not saved): S28's failures.
function actions.mark(runner, a)
	runner.marks = runner.marks or {}
	runner.marks[a.key] = a.value ~= false
end

function actions.clearFlag(runner, a)
	FlagService.clear(runner.player, a.flag)
end

function actions.objective(runner, a)
	runner.objective, runner.args = a.id, a.args or {}
	hooks.publish(runner)
end

-- { "optional", ids = { ... } }: the optional objectives under the main one (docs/05 S41: the deck); {} clears them.
function actions.optional(runner, a)
	runner.optional = a.ids or {}
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
	DialogueService.start(runner.player, a.id, { block = a.block == true })
end

-- Until TutorialController exists a tutorial is a toast, shown once per profile (flag TUT_<id>).
-- Tutorials (TutorialController, Shared/Tutorials): { "tutorial", id, arm = true? }, once per profile. The flag TUT_<id>
-- is set when the client reports the card shown (Tutorial_Seen); arm = the client shows it when its condition holds.
function actions.tutorial(runner, a)
	local id = "TUT_" .. string.gsub(a.id, "^TUT_", "")
	if FlagService.has(runner.player, id) then
		return
	end
	runner.tutorials = runner.tutorials or {}
	runner.tutorials[id] = true
	Net.fireClient(runner.player, "Tutorial_Show", { id = id, arm = a.arm == true })
end

function actions.toast(runner, a)
	Net.fireClient(runner.player, "UI_Toast", { text = a.text })
end

function actions.zoneState(_, a)
	local map = workspace:FindFirstChild("Map")
	local zone = map and map:FindFirstChild(a.zone)
	if zone then
		zone:SetAttribute(a.key, a.value)
		ZoneEffects.apply(zone, a.key, a.value) -- what the state looks like (the outpost's lights coming on)
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
		-- Back in its bay, the pilot on foot at a spawn (the return to the hub, a load in the hub).
		local cframe = CharacterService.getSpawnCFrame(a.spawn)
		if cframe then
			FrameService.park(player, cframe, PLAYER_UNIT)
			CharacterService.teleport(player, a.spawn)
		end
	elseif a.command == "coreOffline" then
		-- The core vents stay dark after the anomaly (docs/05 S33-S40; FrameDamageController draws it).
		local frame = FrameService.getFrame(PLAYER_UNIT)
		if frame then
			frame:SetAttribute("CoreOffline", a.on ~= false)
		end
	elseif a.command == "kneel" then
		-- The player's unit kneels at a pad's marker, the player on foot at `exit` (a load after a dismount).
		local at, exit = CharacterService.getSpawnCFrame(a.spawn), CharacterService.getSpawnCFrame(a.exit)
		if at and exit then
			FrameService.kneelAt(player, PLAYER_UNIT, at, exit)
			CharacterService.teleport(player, a.exit)
		end
	elseif a.command == "autoWalk" then
		-- The pilot's client walks the Frame toward a spawn marker (or straight ahead), whatever the input says;
		-- `seconds` ends it (block = true waits), else "stopWalk" does.
		local frame = FrameService.getPiloted(player)
		local root = frame and frame.PrimaryPart
		if root then
			local marker = a.to and CharacterService.getSpawnCFrame(a.to)
			local ahead = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local to = if marker then marker.Position else root.Position + ahead.Unit * 2000
			frame:SetAttribute("AutoWalkTo", to)
			if a.seconds then
				local function stop()
					if frame.Parent and frame:GetAttribute("AutoWalkTo") == to then
						frame:SetAttribute("AutoWalkTo", nil)
					end
				end
				if a.block then
					task.wait(a.seconds)
					stop()
				else
					task.delay(a.seconds, stop)
				end
			end
		end
	elseif a.command == "stopWalk" then
		local frame = FrameService.getPiloted(player) or FrameService.getFrame(PLAYER_UNIT)
		if frame then
			frame:SetAttribute("AutoWalkTo", nil)
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

-- A big door of the map (Server/Sequence/Doors): { "door", id, open = true | false, block? }.
function actions.door(_, a)
	if not Doors.set(a.id, a.open ~= false, a.block == true) then
		Log.warn(TAG, "door %s isn't in the map", tostring(a.id))
	end
end

-- A full-screen card (docs/14 §9): { "card", kind, lines, seconds }. The card brings its own black, so the fade
-- layer is lifted while it shows and put back to black before it goes; it blocks for `seconds`.
function actions.card(runner, a)
	if a.kind == "MissionComplete" or a.kind == "ChapterEnd" then
		-- Until the player presses Continue (UI_CardDone, docs/14 §9: no auto-dismiss). Mission Complete sits over the
		-- game; Chapter End brings its own black (the fade lifts under it) and `behind` runs while it is up.
		runner.cardDone = nil
		local data = if a.kind == "MissionComplete" then SceneActions.missionCompleteData(runner.player) else SceneActions.chapterEndData(runner.player)
		Net.fireClient(runner.player, "UI_Card", { kind = a.kind, data = data, show = true })
		if a.kind == "ChapterEnd" then
			task.wait(0.1)
			Net.fireClient(runner.player, "Fade", { to = 0, duration = 0 })
		end
		if a.behind then
			Actions.run(runner, runner.token, a.behind)
		end
		while runner.cardDone ~= a.kind and runner.player.Parent do
			task.wait(0.1)
		end
		return
	end
	local seconds = a.seconds
	if not seconds and a.times then -- a Title card: each line's time, then its fade
		seconds = 0
		for _, t in ipairs(a.times) do
			seconds += math.max(t - 0.5, 0.6) + 0.5
		end
	end
	seconds = seconds or 3
	Net.fireClient(runner.player, "UI_Card", { kind = a.kind, lines = a.lines, seconds = seconds, times = a.times, show = true })
	Net.fireClient(runner.player, "Fade", { to = 0, duration = 0 })
	task.wait(seconds)
	Net.fireClient(runner.player, "Fade", { to = 1, duration = 0 })
	Net.fireClient(runner.player, "UI_Card", { kind = a.kind, show = false })
end

-- Mara's Unit 01 (docs/09 §7): { "ally", mode = "Follow" | "Hold" | "Combat" | "Scripted" | "Parked", place?, at?,
-- face?, to?, stride? } (AllyFrameService.setMode).
function actions.ally(runner, a)
	AllyFrameService.setMode(runner.player, a.mode, a)
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

-- Fight barks on the client (BarkController): { "barks", fight = "M01", on = true | false }.
function actions.barks(runner, a)
	Net.fireClient(runner.player, "Bark_Play", { fight = a.fight, on = a.on ~= false })
end

-- { "controls", locked = true | false }: the player's movement (S01 keeps it still while the screen is black).
function actions.controls(runner, a)
	CharacterService.setControlLocked(runner.player, a.locked == true)
end

-- Cinematics (CinematicService): { "cinematic", id, block = true, once = "FLAG", titan = id? } plays it (skipped when the flag is
-- set, which is set after: docs/13 §1.2); { "cinematic", id, stop = true } ends a dialogue-driven or cued one;
-- { "cinematic", id, cue = name } cuts a cued one to that beat.
function actions.cinematic(runner, a)
	if a.stop then
		CinematicService.stop(runner.player, a.id)
		return
	elseif a.cue then
		CinematicService.cue(runner.player, a.id, a.cue)
		return
	end
	if a.once and FlagService.has(runner.player, a.once) then
		return
	end
	-- The subjects a dynamic shot frames: the player's Frame, and the Titan named by `titan` (S28).
	local params = { frame = FrameService.getPiloted(runner.player), titan = a.titan and runner.titans[a.titan] or nil }
	CinematicService.play(runner.player, a.id, { block = a.block ~= false, params = params })
	if a.once then
		FlagService.set(runner.player, a.once)
	end
end

-- NPC sets (NPCService): { "npcs", set = "HUB_MORNING" } places that set exactly; add / remove change it.
function actions.npcs(_, a)
	if a.set then
		NPCService.only(a.set)
	end
	if a.add then
		NPCService.spawn(a.add)
	end
	if a.remove then
		NPCService.despawn(a.remove)
	end
end

-- One NPC: { "npc", id, place = at } | { walk = target, follow = true?, block = true?, despawnAfter = true? } | { sit = at, height = "BENCH" |
-- "CHAIR" | n } | { stop = true } | { despawn = true } | { gesture = name | false }.
function actions.npc(runner, a)
	if a.place then
		NPCService.place(a.id, a.place)
	end
	if a.sit then
		NPCService.sit(a.id, a.sit, if type(a.height) == "string" then NPCConfig.Seat[a.height] else a.height)
	end
	if a.gesture ~= nil then
		NPCService.setGesture(a.id, a.gesture or nil)
	end
	if a.walk then
		local opts = { follow = if a.follow then runner.player else nil }
		local function go()
			-- despawnAfter: gone (fading) once there, as Mara at the Bay 1 bridge in S07
			if NPCService.walkTo(a.id, a.walk, opts) and a.despawnAfter then
				NPCService.despawn(a.id, true)
			end
		end
		if a.block then
			go()
		else
			task.spawn(go)
		end
	end
	if a.stop then
		NPCService.stop(a.id)
	end
	if a.despawn then
		NPCService.despawn(a.id)
	end
end

SceneActions.install(actions) -- the hub scenes' actions (sit, paLoop, scanBeam, terminalMessage)

function Actions.run(runner, token, list, restoring)
	for _, action in ipairs(list or {}) do
		if runner.token ~= token or not runner.player.Parent then
			return
		end
		local handler = actions[action[1]]
		-- Any action can hang on a flag: ifFlag (only with it) or unlessFlag (only without it).
		local gated = (action.ifFlag and not FlagService.has(runner.player, action.ifFlag))
			or (action.unlessFlag and FlagService.has(runner.player, action.unlessFlag))
		if not handler then
			Log.warn(TAG, "action %s isn't built yet (step %s)", tostring(action[1]), runner.step and runner.step.id or "?")
		elseif not (restoring and action.skipOnRestore) and not gated then
			local ok, problem = pcall(handler, runner, action)
			if not ok then
				Log.error(TAG, "action %s failed in %s: %s", tostring(action[1]), runner.step and runner.step.id or "?", tostring(problem))
			end
		end
	end
end

return Actions
