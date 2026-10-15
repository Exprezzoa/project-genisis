--!nonstrict
-- Server/Sequence/SceneActions.lua  (docs/13_missions_dialogue_relationships.md §1.2; docs/05 S03-S43)
--
-- The Sequence Runner's actions for the hub's story scenes, installed into Actions.handlers:
--   sit (the player on a seat mark, S07)   paLoop (the Central Command PA, S03 / S40)
--   scanBeam (Medical's scanner, S41)      terminalMessage (the Q-3 terminal's "1 NEW MESSAGE", S43)
-- and missionCompleteData(player) / chapterEndData(player), what the Mission Complete (S40) and Chapter End (S43)
-- cards show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local NPCConfig = require(Shared.Config.NPCs)
local Progression = require(Shared.Config.Progression)

local Services = script.Parent.Parent.Services
local CharacterService = require(Services.CharacterService)
local DialogueService = require(Services.DialogueService)
local FlagService = require(Services.FlagService)
local ZoneService = require(Services.ZoneService)

local TAG = "SequenceService"

local SceneActions = {}
local actions = {}

local function mapPart(name)
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild(name, true)
end

-- Mission Complete (docs/05 S40, §10): what the chapter earned, from the flags (ProgressionService grants it in
-- Phase 6: D-090), with the rank the XP reaches.
local function missionCompleteData(player)
	local rewards = Progression.Rewards
	local rows = {
		{ label = "MISSION COMPLETE", xp = rewards.CH1_M01_COMPLETE.xp, credits = rewards.CH1_M01_COMPLETE.credits },
		{ label = "STRIDER DEFEATED", xp = rewards.CH1_STRIDER_DEFEATED.xp, credits = rewards.CH1_STRIDER_DEFEATED.credits },
	}
	local logs = 0
	for _, id in ipairs({ "EV_OP07_LOG1", "EV_OP07_LOG2", "EV_OP07_LOG3" }) do
		if FlagService.has(player, id) then
			logs += 1
		end
	end
	if logs > 0 then
		table.insert(rows, { label = ("EVIDENCE LOGS (%d/3)"):format(logs), xp = rewards.EV_OP07_LOG1.xp * logs, credits = 0 })
	end
	if FlagService.has(player, "CH1_CLEAN_KILL") then
		table.insert(rows, { label = "CLEAN KILL", xp = rewards.CH1_CLEAN_KILL.xp, credits = rewards.CH1_CLEAN_KILL.credits })
	end
	local xp, credits = 0, 0
	for _, row in ipairs(rows) do
		xp += row.xp
		credits += row.credits
	end
	local held, nextRank = Progression.rankAt(xp)
	local fill = if nextRank then (xp - held.xp) / (nextRank.xp - held.xp) else 1
	return { mission = "THE SILENT OUTPOST", rows = rows, xp = xp, credits = credits, rank = { name = held.name, rank = held.rank, fill = fill } }
end

-- The player sits at a seat mark (S07): { "sit", at = "SEAT_BRF_ELIAS", height = "BENCH" }; { "sit", stand = true,
-- at = "SPAWN_BRF_DOOR" } gets up there. The seat is invisible and made for the occasion (as NPCService does).
function actions.sit(runner, a)
	local player = runner.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local runtime = workspace:FindFirstChild("Runtime")
	local old = runtime and runtime:FindFirstChild("PlayerSeat_" .. player.UserId)
	if old then
		old:Destroy()
	end
	if not humanoid or not root then
		return
	end
	if a.stand then
		humanoid.Sit = false
		if a.at then
			task.wait() -- the seat weld goes with the seat; move a frame later
			CharacterService.teleport(player, a.at)
		end
		return
	end
	local mark = CharacterService.getSpawnCFrame(a.at)
	if not mark then
		Log.warn(TAG, "sit: no seat mark %s", tostring(a.at))
		return
	end
	local height = if type(a.height) == "string" then NPCConfig.Seat[a.height] else (a.height or NPCConfig.Seat.CHAIR)
	local seat = Instance.new("Seat")
	seat.Name = "PlayerSeat_" .. player.UserId
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.Transparency = 1
	seat.CanCollide, seat.CanTouch, seat.CanQuery = false, false, false
	seat.Anchored = true
	seat.CFrame = mark * CFrame.new(0, height - 0.1, 0)
	seat.Parent = runtime
	root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
	seat:Sit(humanoid)
end

-- The Central Command PA (docs/05 S03): a random line every `every` seconds while the player is in one of `zones`,
-- never the same twice running, until the runner reaches `untilStep` (or leaves the sequence).
function actions.paLoop(runner, a)
	runner.paToken = (runner.paToken or 0) + 1
	local mine, last = runner.paToken, nil
	task.spawn(function()
		while runner.paToken == mine and runner.player.Parent do
			task.wait(a.every or 45)
			if runner.paToken ~= mine or not runner.step or runner.step.id == a.untilStep then
				return
			end
			if table.find(a.zones, ZoneService.getZone(runner.player) or "") and not DialogueService.isActive(runner.player) then
				local choices = {}
				for _, id in ipairs(a.lines) do
					if id ~= last then
						table.insert(choices, id)
					end
				end
				last = choices[math.random(#choices)]
				DialogueService.start(runner.player, last)
			end
		end
	end)
end

-- S41's scanner: a thin ring of pale Neon (#DDE9F2) sweeps down over Elias, `sweeps` times in `seconds` each;
-- block = false lets the step go on (Voss talks while it sweeps).
function actions.scanBeam(runner, a)
	if a.block == false then
		task.spawn(actions.scanBeam, runner, { sweeps = a.sweeps, seconds = a.seconds })
		return
	end
	local character = runner.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local ring = Instance.new("Model")
	ring.Name = "ScanBeam"
	local center = Instance.new("Part")
	center.Name = "Center"
	center.Size, center.Transparency, center.Anchored = Vector3.new(0.2, 0.2, 0.2), 1, true
	center.CanCollide, center.CanQuery, center.CanTouch = false, false, false
	center.Parent = ring
	ring.PrimaryPart = center
	for index = 1, 24 do
		local angle = index / 24 * math.pi * 2
		local segment = Instance.new("Part")
		segment.Size = Vector3.new(0.62, 0.06, 0.12)
		segment.Color = Color3.fromHex("#DDE9F2")
		segment.Material = Enum.Material.Neon
		segment.Transparency = 0.15
		segment.Anchored, segment.CanCollide, segment.CanQuery, segment.CanTouch, segment.CastShadow = true, false, false, false, false
		segment.CFrame = CFrame.new(feet) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2.3)
		segment.Parent = ring
	end
	center.CFrame = CFrame.new(feet)
	ring.Parent = workspace:FindFirstChild("Runtime") or workspace
	local top, bottom = feet + Vector3.new(0, 6.2, 0), feet + Vector3.new(0, 0.1, 0)
	for _ = 1, a.sweeps or 2 do
		local started = os.clock()
		while ring.Parent and runner.player.Parent do
			local t = math.min(1, (os.clock() - started) / (a.seconds or 2))
			ring:PivotTo(CFrame.new(top:Lerp(bottom, t)))
			if t >= 1 then
				break
			end
			task.wait()
		end
	end
	ring:Destroy()
end

-- The Q-3 terminal's screen: "1 NEW MESSAGE" blinking (S43) while the attribute NewMessage is set on its part.
function actions.terminalMessage(_, a)
	local terminal = mapPart("Q3_Terminal_StandIn")
	if terminal then
		terminal:SetAttribute("NewMessage", a.on ~= false)
	end
end

SceneActions.missionCompleteData = missionCompleteData

-- Chapter End (docs/05 S43, docs/14 §9): the evidence logs read.
function SceneActions.chapterEndData(player)
	local found = 0
	for _, id in ipairs({ "EV_OP07_LOG1", "EV_OP07_LOG2", "EV_OP07_LOG3" }) do
		if FlagService.has(player, id) then
			found += 1
		end
	end
	return { chapter = "CHAPTER ONE", title = "THE LAST QUIET MORNING", evidence = found, total = 3, next = "To be continued in Chapter Two: CLASSIFIED" }
end

function SceneActions.install(target)
	for name, handler in pairs(actions) do
		target[name] = handler
	end
end

return SceneActions
