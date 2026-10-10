--!nonstrict
-- Server/Services/CombatService.lua  (docs/12_combat_system.md; numbers in Config/CombatConfig)
--
-- The server side of Frame combat: validates Frame_Action requests, runs each action's timeline on server
-- time, samples the attack boxes against hurtboxes, works out zones and damage, and checks Frame speed.
-- Clients only ask and show: they never send damage, positions for hit tests or timestamps.
--
-- Published on the Frame: Action (move name or ""), ActionT0 (server time), ActionSeq (the request that
-- started it), SpecialReadyAt, DodgeReadyAt (server times). State is "Attack" or "Dodge" while one runs.
--
--   registerTarget(targetId, handler)     handler(hit) applies a hit to a real target (Titans, Phase 3).
--                                         hit = { attacker, frame, targetId, model, zone, damage, poise, move, position }
--   getAction(frame) -> { name, elapsed, queued }?        HitLanded: Signal(hit)
--
-- A hurtbox is a part tagged "Hurtbox" with attribute Zone, inside a model with attribute TargetId. A target
-- nobody registered is a training target: it takes no damage, and the hit is written on its model as the
-- attributes HitCount, LastHitZone, LastHitDamage, LastHitPoise, LastHitMove.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local FrameService = require(script.Parent.FrameService)

local TAG = "CombatService"
local SAMPLE_INTERVAL = 1 / CombatConfig.SAMPLE_RATE
local PAD = Vector3.one * CombatConfig.LAG_PAD
local ROOT_MOTION_SLACK = 0.5 -- seconds a root-motion allowance outlasts its window (the pilot's updates arrive late and in bursts)
local ROOT_MOTION_MARGIN = 1.2 -- share of an action's distance the speed check lets through

local CombatService = {}

CombatService.HitLanded = Signal.new()

local actions = {} -- [frame] = { name, kind, move, t0, seq, player, hit, nextSample, lastSample, queued, direction }
local cooldowns = {} -- [frame] = { Special = readyAt, Dodge = readyAt }
local locks = {} -- [player] = { targetId, zone }
local targets = {} -- [targetId] = handler
local speed = {} -- [frame] = { position, time, valid, violations }
local rootBudget = {} -- [frame] = { distance, expires }: extra studs the running action may move the Frame

local function now()
	return workspace:GetServerTimeNow()
end

local function movesOf(frame)
	return CombatConfig.Frames[frame:GetAttribute("Class")]
end

local function feedback(player, payload)
	Net.fireClient(player, "Combat_Feedback", payload)
end

local function publish(frame, name, t0, seq)
	frame:SetAttribute("ActionT0", t0)
	frame:SetAttribute("ActionSeq", seq)
	frame:SetAttribute("Action", name)
end

local function finish(frame)
	actions[frame] = nil
	if frame.Parent then
		local state = frame:GetAttribute("State")
		if state == "Attack" or state == "Dodge" then
			FrameService.setState(frame, "Idle")
		end
		frame:SetAttribute("Action", "")
	end
end

local function begin(frame, player, name, seq, direction)
	local class = frame:GetAttribute("Class")
	local t0 = now()
	local action = { name = name, t0 = t0, seq = seq, player = player, hit = {}, nextSample = 0 }
	local clip
	if name == "Dodge" then
		local dodge = CombatConfig.Dodge[class]
		action.kind, action.move, action.direction = "dodge", dodge, direction
		clip = CombatConfig.dodgeClip(frame.PrimaryPart.CFrame:VectorToObjectSpace(direction))
		rootBudget[frame] = { distance = dodge.distance * ROOT_MOTION_MARGIN, expires = t0 + dodge.duration + ROOT_MOTION_SLACK }
		cooldowns[frame].Dodge = t0 + dodge.cooldown
		frame:SetAttribute("DodgeReadyAt", cooldowns[frame].Dodge)
	else
		local move = movesOf(frame)[name]
		action.kind, action.move = "attack", move
		clip = move.clip
		if move.lunge then
			rootBudget[frame] = { distance = move.lunge.distance * ROOT_MOTION_MARGIN, expires = t0 + move.lunge.to + ROOT_MOTION_SLACK }
		end
		if move.cooldown then
			cooldowns[frame][name] = t0 + move.cooldown
			frame:SetAttribute(name .. "ReadyAt", cooldowns[frame][name])
		end
	end
	actions[frame] = action
	FrameService.setState(frame, if name == "Dodge" then "Dodge" else "Attack")
	publish(frame, name, t0, seq)
	FrameService.playAnim(frame, clip)
end

-- May a dodge cut into the running attack right now? (docs/12 §3 "Recovery cancel")
local function dodgeCancels(action, elapsed)
	if action.kind ~= "attack" then
		return false
	end
	local move = action.move
	if move.dodgeCancelBefore and elapsed < move.dodgeCancelBefore then
		return true
	end
	local recoveryStart = move.startup + move.active
	return move.cancelRecovery == true and elapsed >= recoveryStart + move.recovery * CombatConfig.RECOVERY_CANCEL
end

local function onRequest(player, payload)
	local frame = FrameService.getPiloted(player)
	if not frame then
		return
	end
	local name, seq = payload.action, payload.seq
	local function reject(reason)
		feedback(player, { kind = if reason == "NoEnergy" then "NoEnergy" else "Rejected", seq = seq, reason = reason })
	end
	if frame:GetAttribute("WeaponsLocked") then
		return reject("Locked")
	end
	local class = frame:GetAttribute("Class")
	local moves = movesOf(frame)
	local current = actions[frame]
	local idle = current == nil and frame:GetAttribute("State") == "Idle"
	local t = now()
	cooldowns[frame] = cooldowns[frame] or {}

	if name == "Light" then
		if current and current.kind == "attack" and current.move.chain and not current.queued then
			current.queued = seq -- starts at this light's recovery start + CHAIN_DELAY
		elseif idle then
			begin(frame, player, CombatConfig.Requests.Light, seq)
		else
			reject("Busy")
		end
	elseif name == "Heavy" or name == "Special" then
		local moveName = CombatConfig.Requests[name]
		local move = moves[moveName]
		if not idle then
			return reject("Busy")
		elseif (cooldowns[frame][moveName] or 0) > t then
			return reject("Cooldown")
		elseif not FrameService.spendEnergy(frame, move.energy) then
			return reject("NoEnergy")
		end
		begin(frame, player, moveName, seq)
	elseif name == "Dodge" then
		local dodge = CombatConfig.Dodge[class]
		if not (idle or (current and dodgeCancels(current, t - current.t0))) then
			return reject("Busy")
		elseif (cooldowns[frame].Dodge or 0) > t then
			return reject("Cooldown")
		elseif not FrameService.spendEnergy(frame, dodge.energy) then
			return reject("NoEnergy")
		end
		-- Toward the move input; a backstep with none. Only the horizontal part of what the client sent counts.
		local root = frame.PrimaryPart
		local direction = payload.dir and Vector3.new(payload.dir.X, 0, payload.dir.Z)
		if not direction or direction.Magnitude < 0.5 then
			direction = -root.CFrame.LookVector
		end
		begin(frame, player, "Dodge", seq, direction.Unit)
	else
		reject("NoTarget") -- Core Strike needs a Titan with an exposed core (Phase 3)
	end
end

local function onLock(player, payload)
	locks[player] = if payload.targetId then { targetId = payload.targetId, zone = payload.zone or "Body" } else nil
end

local function targetOf(hurtbox)
	local model = hurtbox:FindFirstAncestorWhichIsA("Model")
	while model and model:GetAttribute("TargetId") == nil do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model
end

local function land(action, frame, model, hurtbox)
	local move = action.move
	local zoneName = hurtbox:GetAttribute("Zone") or "Body"
	local zone = CombatConfig.Zones[zoneName] or CombatConfig.Zones.Body
	local hit = {
		attacker = action.player, frame = frame, targetId = model:GetAttribute("TargetId"), model = model, zone = zoneName,
		damage = move.damage * zone.hpMult, poise = move.poise * zone.poiseMult, move = action.name, position = hurtbox.Position,
	}
	local handler = targets[hit.targetId]
	if handler then
		handler(hit)
	else
		model:SetAttribute("HitCount", (model:GetAttribute("HitCount") or 0) + 1)
		model:SetAttribute("LastHitZone", hit.zone)
		model:SetAttribute("LastHitDamage", hit.damage)
		model:SetAttribute("LastHitPoise", hit.poise)
		model:SetAttribute("LastHitMove", hit.move)
	end
	feedback(action.player, {
		kind = "HitLanded", targetId = hit.targetId, zone = hit.zone, amount = hit.damage, poise = hit.poise, pos = hit.position, move = hit.move,
	})
	CombatService.HitLanded:Fire(hit)
end

-- One hitbox sample: every target the box touches that this attack hasn't hit yet takes one hit, on the
-- locked zone if the box touches it, else on the touched hurtbox nearest to the move's aim point.
local function sample(frame, action)
	local root = frame.PrimaryPart
	local move = action.move
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("Hurtbox")
	local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(move.box.offset), move.box.size + PAD, params)
	if #parts == 0 then
		return
	end
	local aim = root.CFrame * move.aim
	local lock = locks[action.player]
	local best = {} -- [model] = { hurtbox, distance }
	for _, hurtbox in ipairs(parts) do
		local model = targetOf(hurtbox)
		if model and not action.hit[model] then
			local locked = lock and lock.targetId == model:GetAttribute("TargetId") and lock.zone == hurtbox:GetAttribute("Zone")
			local distance = if locked then -1 else (hurtbox.Position - aim).Magnitude
			if not best[model] or distance < best[model].distance then
				best[model] = { hurtbox = hurtbox, distance = distance }
			end
		end
	end
	for model, entry in pairs(best) do
		action.hit[model] = true
		land(action, frame, model, entry.hurtbox)
	end
end

local function stepActions()
	local t = now()
	for frame, action in pairs(actions) do
		if not frame.Parent or FrameService.getPiloted(action.player) ~= frame then
			-- The pilot left mid-action: FrameService already put the Frame in its own state.
			actions[frame] = nil
			if frame.Parent then
				frame:SetAttribute("Action", "")
			end
			continue
		end
		local elapsed = t - action.t0
		local move = action.move
		if action.kind == "dodge" then
			if elapsed >= move.duration + move.settle then
				finish(frame)
			end
			continue
		end
		local activeEnd = move.startup + move.active
		if elapsed >= move.startup and not action.lastSample then
			if elapsed >= activeEnd then
				action.lastSample = true -- the last sample sits on the end of the window
				sample(frame, action)
			elseif elapsed >= action.nextSample then
				action.nextSample = elapsed + SAMPLE_INTERVAL
				sample(frame, action)
			end
		end
		if action.queued and move.chain and elapsed >= activeEnd + CombatConfig.CHAIN_DELAY then
			begin(frame, action.player, move.chain, action.queued)
		elseif elapsed >= CombatConfig.total(move) then
			finish(frame)
		end
	end
end

-- docs/12 §10: a piloted Frame that moves further than its state allows for too long is put back.
-- The check works on distance per interval, not on speed: the pilot's position updates reach the server in
-- bursts, so a dodge's 88 studs can show up inside one interval. While an action's root motion is (or was just)
-- running, the interval may hold that action's whole distance on top of normal movement (D-054).
local function allowedDistance(frame, dt, t)
	local budget = rootBudget[frame]
	local extra = if budget and t <= budget.expires then budget.distance else 0
	return CombatConfig.SpeedCheck.normal * dt + extra
end

local function checkSpeed(frame, player)
	local root = frame.PrimaryPart
	local t = now()
	local entry = speed[frame]
	local movedAt = frame:GetAttribute("MovedAt")
	-- A new pilot, or the server moved the Frame itself (FrameService.moveTo): start measuring afresh.
	if not entry or entry.player ~= player or entry.movedAt ~= movedAt then
		speed[frame] = { player = player, position = root.Position, time = t, valid = root.CFrame, violations = {}, movedAt = movedAt }
		return
	end
	local dt = t - entry.time
	local moved = (root.Position - entry.position) * Vector3.new(1, 0, 1)
	local over = moved.Magnitude > allowedDistance(frame, dt, t)
	entry.position, entry.time = root.Position, t
	local check = CombatConfig.SpeedCheck
	for index = #entry.violations, 1, -1 do
		if t - entry.violations[index].time > check.window then
			table.remove(entry.violations, index)
		end
	end
	if not over then
		entry.valid = root.CFrame
		return
	end
	table.insert(entry.violations, { time = t, length = dt })
	local total = 0
	for _, violation in ipairs(entry.violations) do
		total += violation.length
	end
	if total > check.violationTime then
		Log.warn(TAG, "%s moved Unit %s too fast for %.2f s; set back", player.Name, tostring(frame:GetAttribute("Unit")), total)
		frame:PivotTo(entry.valid)
		entry.position = entry.valid.Position
		table.clear(entry.violations)
	end
end

function CombatService.registerTarget(targetId, handler)
	targets[targetId] = handler
end

function CombatService.getAction(frame)
	local action = actions[frame]
	return action and { name = action.name, elapsed = now() - action.t0, queued = action.queued ~= nil }
end

function CombatService.getLock(player)
	return locks[player]
end

function CombatService.Start()
	Net.on("Frame_Action", onRequest)
	Net.on("Frame_Lock", onLock)
	RunService.Heartbeat:Connect(stepActions)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		locks[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CombatConfig.SpeedCheck.interval)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local frame = FrameService.getPiloted(player)
				if frame and frame.PrimaryPart and not frame.PrimaryPart.Anchored then
					checkSpeed(frame, player)
				end
			end
		end
	end)
end

return CombatService
