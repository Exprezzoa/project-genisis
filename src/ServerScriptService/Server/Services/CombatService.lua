--!nonstrict
-- Server/Services/CombatService.lua  (docs/12_combat_system.md; numbers in Config/CombatConfig)
--
-- The server side of Frame combat: validates Frame_Action requests, runs each action's timeline on server
-- time, samples the attack boxes against hurtboxes and works out zones and damage (Server/Combat/SpeedCheck checks
-- Frame speed).
-- Clients only ask and show: they never send damage, positions for hit tests or timestamps.
--
-- Published on the Frame: Action (move name, "HitReact" or ""), ActionT0 (server time), ActionSeq (the request
-- that started it), SpecialReadyAt, DodgeReadyAt (server times). State is "Attack", "Dodge", "CoreStrike",
-- "HitStunLight" or "HitStunHeavy" while one runs, and "Disabled" once the Integrity is gone.
--
--   registerTarget(targetId, handler)     a real target (a Titan). handler = { takeHit = function(hit),
--                                         getCore = function() -> Vector3? (where its exposed core is),
--                                         holdCore = function(seconds), model = Model }; a plain function(hit)
--                                         also works. hit = { attacker, frame, targetId, model, zone, damage,
--                                         poise, move, position, coreStrike? }
--   hitFrame(frame, hit) -> "Hit" | "Pending" | the reason it was ignored      a Titan's attack touched a Frame
--   allyHit(hit)                          a hit by Mara's Unit 01 (no attacker; AllyFrameService caps it)
--   repair(frame)                         full Integrity and out of Disabled (debug, later the retry flow)
--   getAction(frame) -> { name, elapsed, queued }?
--   HitLanded: Signal(hit)     FrameHit: Signal(frame, hit, { integrity, heavy, stun, disabled })
--   FrameEvaded: Signal(frame, hit, reason)     FrameDisabled: Signal(frame)
--   RigSpent: Signal(rig)     a rig with the attribute NoDisable ran out of integrity (it isn't disabled)
-- Multipliers a rig may carry (its specials): DamageMult on what it deals, DamageTakenMult on what it takes.
--
-- A hurtbox is a part tagged "Hurtbox" with attribute Zone, inside a model with attribute TargetId. A target
-- nobody registered is a training target: it takes no damage, and the hit is written on its model as the
-- attributes HitCount, LastHitZone, LastHitDamage, LastHitPoise, LastHitMove.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local FrameService = require(script.Parent.FrameService)
local SpeedCheck = require(script.Parent.Parent.Combat.SpeedCheck)

local TAG = "CombatService"
local SAMPLE_INTERVAL = 1 / CombatConfig.SAMPLE_RATE
local PAD = Vector3.one * CombatConfig.LAG_PAD
local KNOCKBACK_TIME = 0.25 -- the pilot's client carries a knockback out over this long (docs/12 §7)
local ACTION_STATES = { Attack = true, Dodge = true, CoreStrike = true, HitStunLight = true, HitStunHeavy = true }

local CombatService = {}

CombatService.HitLanded = Signal.new()
CombatService.FrameHit = Signal.new()
CombatService.FrameEvaded = Signal.new()
CombatService.FrameDisabled = Signal.new()
CombatService.RigSpent = Signal.new() -- a NoDisable rig ran out of integrity (the Titan form, D-096)

local actions = {} -- [frame] = { name, kind, move, t0, seq, player, hit, nextSample, lastSample, queued, direction }
local cooldowns = {} -- [frame] = { Special = readyAt, Dodge = readyAt }
local locks = {} -- [player] = { targetId, zone }
local targets = {} -- [targetId] = handler
local lastHit = {} -- [frame] = server time of the last hit it took (mercy)
local pendingHits = {} -- { frame, hit, at, resolveAt }: hits waiting out the dodge grace

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
		if ACTION_STATES[frame:GetAttribute("State")] then
			FrameService.setState(frame, "Idle")
		end
		frame:SetAttribute("Action", "")
	end
end

local function begin(frame, player, name, seq, direction, target)
	local class = frame:GetAttribute("Class")
	local t0 = now()
	local action = { name = name, t0 = t0, seq = seq, player = player, hit = {}, nextSample = 0 }
	local clip
	if name == "CoreStrike" then
		local strike = CombatConfig.CoreStrike[class]
		action.kind, action.move, action.target = "core", strike, target
		clip = strike.clip
		-- The pilot's client steps the Frame into place (docs/11 §5.6); it may cover the strike's whole reach.
		SpeedCheck.allow(frame, strike.range + CombatConfig.Tolerance.coreStrikeRange, strike.stepTime)
		frame:SetAttribute("ActionTarget", target)
	elseif name == "Dodge" then
		local dodge = CombatConfig.Dodge[class]
		action.kind, action.move, action.direction = "dodge", dodge, direction
		clip = CombatConfig.dodgeClip(frame.PrimaryPart.CFrame:VectorToObjectSpace(direction))
		SpeedCheck.allow(frame, dodge.distance, dodge.duration)
		cooldowns[frame].Dodge = t0 + dodge.cooldown
		frame:SetAttribute("DodgeReadyAt", cooldowns[frame].Dodge)
	else
		local move = movesOf(frame)[name]
		action.kind, action.move = "attack", move
		clip = move.clip
		if move.lunge then
			SpeedCheck.allow(frame, move.lunge.distance, move.lunge.to)
		end
		if move.cooldown then
			cooldowns[frame][name] = t0 + move.cooldown
			frame:SetAttribute(name .. "ReadyAt", cooldowns[frame][name])
		end
	end
	actions[frame] = action
	FrameService.setState(frame, if name == "Dodge" or name == "CoreStrike" then name else "Attack")
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

-- The nearest exposed core the Frame may strike: within the strike's range and in front of the Frame, each
-- with its tolerance (docs/12 §10). Returns the target's id.
local function coreInReach(frame)
	local strike = CombatConfig.CoreStrike[frame:GetAttribute("Class")]
	local root = frame.PrimaryPart
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local best, bestDistance = nil, strike.range + CombatConfig.Tolerance.coreStrikeRange
	for targetId, handler in pairs(targets) do
		local core = type(handler) == "table" and handler.getCore and handler.getCore()
		if core then
			local toward = (core - root.Position) * Vector3.new(1, 0, 1)
			local distance = toward.Magnitude
			local angle = 0
			if distance > 0.1 and look.Magnitude > 0.1 then
				angle = math.deg(math.acos(math.clamp(look.Unit:Dot(toward.Unit), -1, 1)))
			end
			if distance <= bestDistance and angle <= strike.facing + CombatConfig.Tolerance.facing then
				best, bestDistance = targetId, distance
			end
		end
	end
	return best
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
		if not move then
			return reject("Rejected") -- this class has no such move (the Titan form's specials are ShifterService's)
		elseif not idle then
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
	elseif name == "CoreStrike" then
		if not idle then
			return reject("Busy")
		end
		local targetId = coreInReach(frame)
		if not targetId then
			return reject("NoTarget")
		end
		-- The Titan stays down until the strike is over (docs/10 §1.5).
		local handler = targets[targetId]
		if handler.holdCore then
			handler.holdCore(CombatConfig.CoreStrike[class].duration)
		end
		begin(frame, player, "CoreStrike", seq, nil, targetId)
	else
		reject("Rejected")
	end
end

-- docs/12 §8: the target must exist and be in range, and the zone must be one that can be hit right now;
-- otherwise the lock falls back to the body. A training target (nobody registered it) is taken as asked.
local function onLock(player, payload)
	local frame = FrameService.getPiloted(player)
	if not (frame and payload.targetId) then
		locks[player] = nil
		return
	end
	local zone = if type(payload.zone) == "string" then payload.zone else "Body"
	local handler = targets[payload.targetId]
	local model = type(handler) == "table" and handler.model
	if model then
		local root = model.PrimaryPart
		if not root or (root.Position - frame.PrimaryPart.Position).Magnitude > CombatConfig.LockOn.range + CombatConfig.Tolerance.coreStrikeRange then
			locks[player] = nil
			return
		end
		local box = model:FindFirstChild("Hurtbox_" .. zone)
		if not (box and box.CanQuery) then
			zone = "Body"
		end
	end
	locks[player] = { targetId = payload.targetId, zone = zone }
end

local function targetOf(hurtbox)
	local model = hurtbox:FindFirstAncestorWhichIsA("Model")
	while model and model:GetAttribute("TargetId") == nil do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model
end

-- Hands a hit to its target and tells the attacker.
local function deliver(hit)
	local model = hit.model
	local handler = targets[hit.targetId]
	if type(handler) == "table" then
		handler.takeHit(hit)
	elseif handler then
		handler(hit)
	elseif model then
		model:SetAttribute("HitCount", (model:GetAttribute("HitCount") or 0) + 1)
		model:SetAttribute("LastHitZone", hit.zone)
		model:SetAttribute("LastHitDamage", hit.damage)
		model:SetAttribute("LastHitPoise", hit.poise)
		model:SetAttribute("LastHitMove", hit.move)
	end
	if hit.attacker then
		feedback(hit.attacker, {
			kind = "HitLanded", targetId = hit.targetId, zone = hit.zone, amount = hit.damage, poise = hit.poise, pos = hit.position, move = hit.move,
		})
	end
	CombatService.HitLanded:Fire(hit)
end

local function land(action, frame, model, hurtbox)
	local move = action.move
	local zoneName = hurtbox:GetAttribute("Zone") or "Body"
	local zone = CombatConfig.Zones[zoneName] or CombatConfig.Zones.Body
	local mult = frame:GetAttribute("DamageMult") or 1 -- a buff of the attacking rig (the Titan form's specials)
	deliver({
		attacker = action.player, frame = frame, targetId = model:GetAttribute("TargetId"), model = model, zone = zoneName,
		damage = move.damage * zone.hpMult * mult, poise = move.poise * zone.poiseMult * mult, move = action.name, position = hurtbox.Position,
	})
end

-- A swing's box is as wide as the blade's sweep, so its far corners lie further out than the blade gets:
-- a hurtbox counts only if its near side is within the move's reach of the Frame.
local function inReach(root, hurtbox, reach)
	if not reach then
		return true
	end
	local offset = (hurtbox.Position - root.Position) * Vector3.new(1, 0, 1)
	return offset.Magnitude - math.max(hurtbox.Size.X, hurtbox.Size.Z) / 2 <= reach + CombatConfig.LAG_PAD
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
		if model and not action.hit[model] and inReach(root, hurtbox, move.reach) then
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
		elseif action.kind == "stun" then
			if elapsed >= move.duration then
				finish(frame)
			end
			continue
		elseif action.kind == "core" then
			-- Core Strike (docs/12 §3, §6): one flat hit on the core at the impact time, nothing else.
			if not action.struck and elapsed >= move.impact then
				action.struck = true
				local handler = targets[action.target]
				local core = type(handler) == "table" and handler.getCore()
				if core then
					deliver({
						attacker = action.player, frame = frame, targetId = action.target, model = handler.model, zone = "Core",
						damage = move.damage, poise = 0, move = "CoreStrike", position = core, coreStrike = true,
					})
				end
			end
			if elapsed >= move.duration then
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

----------------------------------------------------------------------------------------------------------------
-- Titan attacks on Frames (docs/12 §7)
----------------------------------------------------------------------------------------------------------------
-- Why a hit doesn't count right now, or nil when it does.
local function evades(frame, hit, t)
	if frame:GetAttribute("God") then
		return "God"
	elseif frame:GetAttribute("State") == "Disabled" then
		return "Disabled"
	end
	local action = actions[frame]
	if action and action.kind == "core" then
		return "CoreStrike"
	elseif action and action.kind == "dodge" then
		local elapsed = t - action.t0
		local window = action.move.iFrames
		-- The Roar is escaped by any dodge still under way; everything else only by the i-frames.
		if (hit.anyDodge and elapsed <= action.move.duration) or (elapsed >= window.from and elapsed <= window.to) then
			return "Dodged"
		end
	end
	if t - (lastHit[frame] or 0) < CombatConfig.MERCY then
		return "Mercy"
	end
	return nil
end

local function applyHit(frame, hit)
	local t = now()
	lastHit[frame] = t
	-- A buff of the rig hit (the Titan form's Hardening) takes part of the damage.
	local damage = hit.damage * (frame:GetAttribute("DamageTakenMult") or 1)
	local integrity = FrameService.setIntegrity(frame, (frame:GetAttribute("Integrity") or 0) - damage)
	local heavy = damage >= CombatConfig.HitReact.heavyAt
	local react = if heavy then CombatConfig.HitReact.Heavy else CombatConfig.HitReact.Light
	local stun = hit.stagger or react.stun
	local disabled = integrity <= 0
	if disabled and frame:GetAttribute("NoDisable") then
		-- A rig that can't be disabled (the Titan form) is spent instead: its own service ends it.
		actions[frame] = nil
		frame:SetAttribute("Action", "")
		CombatService.FrameHit:Fire(frame, hit, { integrity = 0, heavy = heavy, stun = 0, disabled = false })
		CombatService.RigSpent:Fire(frame)
		return
	end
	local player = Players:GetPlayerByUserId(frame:GetAttribute("Pilot") or 0)
	if player and FrameService.getPiloted(player) == frame then
		if disabled then
			actions[frame] = nil
			frame:SetAttribute("Action", "")
			FrameService.setState(frame, "Disabled")
			FrameService.playAnim(frame, "Disabled")
		else
			-- The hit stun is an action like any other: nothing else starts until it ends.
			actions[frame] = { name = "HitReact", kind = "stun", move = { duration = stun }, t0 = t, seq = 0, player = player, hit = {}, nextSample = 0 }
			FrameService.setState(frame, if heavy then "HitStunHeavy" else "HitStunLight")
			publish(frame, "HitReact", t, 0)
			FrameService.playAnim(frame, react.clip)
		end
		SpeedCheck.allow(frame, hit.knockback.Magnitude, KNOCKBACK_TIME)
		feedback(player, {
			kind = "HitTaken", damage = damage, knockback = hit.knockback, time = KNOCKBACK_TIME, heavy = heavy, stun = stun,
			attack = hit.attack, disabled = disabled,
		})
	elseif disabled then
		FrameService.setState(frame, "Disabled")
	end
	CombatService.FrameHit:Fire(frame, hit, { integrity = integrity, heavy = heavy, stun = stun, disabled = disabled })
	if disabled then
		Log.info(TAG, "Unit %s is disabled", tostring(frame:GetAttribute("Unit")))
		CombatService.FrameDisabled:Fire(frame)
	end
end

-- A Titan's attack touched this Frame. hit = { damage, knockback = Vector3 (studs), attack = name, source = the
-- Titan, activeStart = server time its active window began, stagger = seconds?, anyDodge = boolean? }.
-- Dodge grace: a hit found less than DODGE_GRACE after the window began waits until that moment; a dodge that
-- starts in the meantime escapes it.
function CombatService.hitFrame(frame, hit)
	local t = now()
	local reason = evades(frame, hit, t)
	if reason then
		CombatService.FrameEvaded:Fire(frame, hit, reason)
		return reason
	end
	local graceEnd = (hit.activeStart or 0) + CombatConfig.DODGE_GRACE
	if t < graceEnd then
		table.insert(pendingHits, { frame = frame, hit = hit, at = t, resolveAt = graceEnd })
		return "Pending"
	end
	applyHit(frame, hit)
	return "Hit"
end

local function stepHits()
	local t = now()
	for index = #pendingHits, 1, -1 do
		local entry = pendingHits[index]
		if t >= entry.resolveAt then
			table.remove(pendingHits, index)
			local frame = entry.frame
			if frame.Parent then
				local action = actions[frame]
				-- A dodge begun since the hit was found (or just before, its i-frames not yet running) escapes it.
				local late = action and action.kind == "dodge" and action.t0 >= entry.at - action.move.iFrames.from
				local reason = if late then "Grace" else evades(frame, entry.hit, t)
				if reason then
					CombatService.FrameEvaded:Fire(frame, entry.hit, reason)
				else
					applyHit(frame, entry.hit)
				end
			end
		end
	end
end

-- Full Integrity, and back on its feet if it was Disabled.
function CombatService.repair(frame)
	FrameService.setIntegrity(frame, math.huge)
	lastHit[frame] = nil
	if frame:GetAttribute("State") == "Disabled" then
		FrameService.setState(frame, "Idle")
		FrameService.playAnim(frame, "")
	end
end

-- A hit by the ally Frame (AllyFrameService decides it): straight to the target; there is no pilot to tell.
function CombatService.allyHit(hit)
	deliver(hit)
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
	RunService.Heartbeat:Connect(stepHits)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		locks[player] = nil
	end)
	SpeedCheck.start(FrameService.getPiloted)
end

return CombatService
