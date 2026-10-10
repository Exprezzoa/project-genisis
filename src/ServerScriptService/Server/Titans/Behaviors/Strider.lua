--!nonstrict
-- Server/Titans/Behaviors/Strider.lua  (docs/10_titans.md §1.3-1.5, §2; docs/12 §7)
--
-- What a Strider does: picks a Frame, walks at it, chooses an attack by distance, telegraphs it, strikes and
-- recovers; flinches under fast poise damage; drops to hands and knees with its core open when its poise
-- breaks; gets up tougher; roars and enrages at half health; dies only while Downed, then collapses to ash.
-- One instance per Titan, made and stepped by TitanService. Numbers: TitanConfig.Strider and
-- CombatConfig.TitanAttacks.Strider.
--
-- Published State: Idle | Engage | Telegraph | Active | Recover | Flinch | Downed | GetUp | Dead, with Attack,
-- AttackT0 and AttackWindup while an attack runs (clients draw the telegraphs from these).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local StateMachine = require(Shared.Modules.StateMachine)

local Server = script.Parent.Parent.Parent
local CombatService = require(Server.Services.CombatService)
local FrameService = require(Server.Services.FrameService)

local SAMPLE_INTERVAL = 1 / 20 -- hit tests per second during an active window (docs/12 §7)
local RETARGET = 1.0
local APPROACH_COMMIT = 1.0 -- seconds it keeps walking after the attack choice came out as "Approach"
local LUNGE_STOP = 2 -- studs short of a wall the Lunge ends
local UNTARGETABLE = { Parked = true, Kneeling = true, Starting = true, Disabled = true }
local FLINCH_FROM = { Idle = true, Engage = true, Telegraph = true, Recover = true }
local ASH, ASH_DARK = Color3.fromHex("#9C9893"), Color3.fromHex("#6F6B66")
local DEATH = { mounds = 4.0, grow = 6.0, remove = 12.5 } -- docs/10 §2

local Strider = {}
Strider.__index = Strider

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function yawOf(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function turnToward(from, to, step)
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + math.clamp(delta, -step, step)
end

local function radiusOf(frame)
	local config = FrameConfig[frame:GetAttribute("Class")]
	return if config then config.body.radius else 8
end

----------------------------------------------------------------------------------------------------------------
-- Senses and movement
----------------------------------------------------------------------------------------------------------------
function Strider:lookVector()
	return Vector3.new(-math.sin(self.heading), 0, -math.cos(self.heading))
end

local function targetable(frame)
	return frame.Parent ~= nil and frame.PrimaryPart ~= nil and (frame:GetAttribute("Pilot") or 0) ~= 0 and not UNTARGETABLE[frame:GetAttribute("State")]
end

-- docs/10 §1.5 "Target selection": the player's Frame scores 100 - distance / 10, an ally's 60 - distance / 10.
function Strider:pickTarget()
	local best, bestScore = nil, -math.huge
	for _, frame in ipairs(FrameService.getFrames()) do
		if targetable(frame) then
			local distance = flat(frame.PrimaryPart.Position - self.root.Position).Magnitude
			local piloted = Players:GetPlayerByUserId(frame:GetAttribute("Pilot")) ~= nil
			local score = (if piloted then 100 else 60) - distance / 10
			if distance <= self.config.aggroRadius and score > bestScore then
				best, bestScore = frame, score
			end
		end
	end
	self.target = best
	return best
end

-- The gap between the two bodies: center distance minus both body radii.
function Strider:gapTo(frame)
	return flat(frame.PrimaryPart.Position - self.root.Position).Magnitude - self.config.bodyRadius - radiusOf(frame)
end

function Strider:face(dt, rate)
	local target = self.target
	if target and target.PrimaryPart and rate > 0 then
		local toward = flat(target.PrimaryPart.Position - self.root.Position)
		if toward.Magnitude > 0.5 then
			self.heading = turnToward(self.heading, yawOf(toward), math.rad(rate) * dt)
		end
	end
	self.facing.CFrame = CFrame.Angles(0, self.heading, 0)
end

function Strider:moveToward(gap)
	local t = os.clock()
	if t - self.lastMove < 1 / self.attacks.moveRate then
		return
	end
	self.lastMove = t
	self.humanoid.WalkSpeed = if gap > self.attacks.chaseGap then self.config.chaseSpeed else self.config.walkSpeed
	self.humanoid:MoveTo(self.target.PrimaryPart.Position)
end

function Strider:stop()
	self.humanoid.WalkSpeed = 0
	self.humanoid:Move(Vector3.zero)
	self.lastMove = 0
end

----------------------------------------------------------------------------------------------------------------
-- Attacks
----------------------------------------------------------------------------------------------------------------
-- docs/10 §1.5 "Attack choice": weighted by the gap; never the same attack three times running; Stomp only
-- when its landing point can reach the target. Returns an attack name, "Approach" or "Wait".
function Strider:choose(gap)
	local weights
	for _, band in ipairs(self.attacks.choice) do
		if gap < band.gap then
			weights = band.weights
			break
		end
	end
	if not weights then
		return "Approach"
	end
	local history = self.history
	local repeated = #history >= 2 and history[#history] == history[#history - 1] and history[#history]
	local total, options = 0, {}
	for name, weight in pairs(weights) do
		local allowed = name ~= repeated
		if allowed and name == "Stomp" then
			local spec = self.attacks.Stomp
			local landing = flat(self.root.Position) + self:lookVector() * spec.forward
			allowed = (flat(self.target.PrimaryPart.Position) - landing).Magnitude <= self.attacks.stompReach + radiusOf(self.target)
		end
		if allowed then
			total += weight
			table.insert(options, { name, weight })
		end
	end
	if total <= 0 then
		return "Wait"
	end
	local roll = self.random:NextNumber() * total
	for _, option in ipairs(options) do
		roll -= option[2]
		if roll <= 0 then
			return option[1]
		end
	end
	return options[#options][1]
end

-- One hit test of the running attack against every Frame it hasn't hit yet (docs/12 §7).
function Strider:sampleHits()
	local attack = self.attack
	local spec = attack.spec
	local origin = flat(self.root.Position)
	local look = self:lookVector()
	for _, frame in ipairs(FrameService.getFrames()) do
		if not attack.hit[frame] and targetable(frame) then
			local position = flat(frame.PrimaryPart.Position)
			local reach = radiusOf(frame)
			local offset = position - origin
			local away = if offset.Magnitude > 0.1 then offset.Unit else look
			local landed, push = false, away
			if spec.shape == "Arc" then
				landed = offset.Magnitude <= spec.radius + reach and math.deg(math.acos(math.clamp(look:Dot(away), -1, 1))) <= spec.halfAngle
			elseif spec.shape == "Circle" then
				local fromLanding = position - (origin + look * spec.forward)
				landed = fromLanding.Magnitude <= spec.radius + reach
				push = if fromLanding.Magnitude > 0.1 then fromLanding.Unit else away
			elseif spec.shape == "Path" then
				-- Distance from the Frame to the stretch travelled so far.
				local travelled = origin - attack.start
				local along = if travelled.Magnitude > 0.1 then math.clamp((position - attack.start):Dot(travelled.Unit), 0, travelled.Magnitude) else 0
				local nearest = attack.start + (if travelled.Magnitude > 0.1 then travelled.Unit * along else Vector3.zero)
				landed = (position - nearest).Magnitude <= spec.halfWidth + reach
				push = attack.direction
			elseif spec.shape == "Sphere" then
				landed = offset.Magnitude <= spec.radius + reach
			end
			if landed then
				attack.hit[frame] = true
				CombatService.hitFrame(frame, {
					damage = spec.damage, knockback = push * spec.knockback, stagger = spec.stagger, attack = attack.name, source = self.model,
					activeStart = attack.activeStart,
					anyDodge = spec.shape == "Sphere", -- the Roar is escaped by any dodge in progress
				})
			end
		end
	end
end

function Strider:startLunge()
	local attack = self.attack
	attack.start = flat(self.root.Position)
	attack.direction = self:lookVector()
	-- The path is checked first: the Lunge ends early at a wall or a FrameBarrier (docs/10 §1.4).
	local params = RaycastParams.new()
	params.CollisionGroup = "FrameRoot" -- the group that meets both the map and the barriers
	params.RespectCanCollide = true
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model, workspace:FindFirstChild("Frames") }
	local blocked = workspace:Blockcast(self.root.CFrame, self.root.Size, attack.direction * attack.spec.speed * attack.spec.active, params)
	attack.travel = if blocked then math.max(0, blocked.Distance - LUNGE_STOP) / attack.spec.speed else attack.spec.active
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Lunge"
	drive.Attachment0 = self.root:FindFirstChild("FacingAttachment")
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.PlaneVelocity = Vector2.new(attack.direction.X, attack.direction.Z) * attack.spec.speed
	drive.MaxForce = 1e7
	drive.Parent = self.root
	self.lunge = drive
end

-- The pause before the next attack: 1.2-2.0 s, shorter when enraged (docs/10 §1.4-1.5). It also follows a
-- Flinch and a GetUp, so the Titan never strikes the instant it is free again.
function Strider:rest()
	local cooldown = self.attacks.cooldown
	local scale = if self.enraged then self.attacks.enrage.cooldownScale else 1
	self.cooldownUntil = now() + self.random:NextNumber(cooldown.min, cooldown.max) * scale
end

-- Ends whatever attack is running and puts the body back to normal (also when it is cut short).
function Strider:clearAttack()
	if self.lunge then
		self.lunge:Destroy()
		self.lunge = nil
	end
	self.entry.anklePoise = nil
	if self.model:GetAttribute("HurtboxState") ~= "Standing" then
		self.service.setHurtboxState(self.model, "Standing")
	end
	self.model:SetAttribute("Attack", "")
	self.attack = nil
end

----------------------------------------------------------------------------------------------------------------
-- States (docs/10 §1.5)
----------------------------------------------------------------------------------------------------------------
local STATES = {}

STATES.Idle = {
	enter = function(machine)
		local self = machine.context
		self:stop()
		self.service.setState(self.model, "Idle")
	end,
	update = function(machine, dt)
		local self = machine.context
		self.decisionClock += dt
		if self.decisionClock >= RETARGET then
			self.decisionClock = 0
			if self:pickTarget() then
				machine:transition("Engage")
			end
		end
	end,
}

STATES.Engage = {
	enter = function(machine)
		local self = machine.context
		self.service.setState(self.model, "Engage")
		self.decisionClock = 0
	end,
	update = function(machine, dt)
		local self = machine.context
		self:face(dt, self.config.turnRate.approach)
		self.retargetClock += dt
		self.decisionClock += dt
		if self.decisionClock < 1 / self.attacks.decisionRate then
			return
		end
		self.decisionClock = 0
		if self.retargetClock >= RETARGET or not (self.target and targetable(self.target)) then
			self.retargetClock = 0
			if not self:pickTarget() then
				machine:transition("Idle")
				return
			end
		end
		local t = now()
		local gap = self:gapTo(self.target)
		-- The Roar: first at half health, then every 25-35 s while it stays there (docs/10 §1.4).
		if self.entry.hp / self.config.hp <= self.attacks.enrage.hpFraction and t >= self.nextRoar then
			machine:transition("Telegraph", "Roar")
			return
		end
		local choice = if t >= self.cooldownUntil then self:choose(gap) else "Wait"
		local bands = self.attacks.choice
		if choice == "Approach" and gap < bands[#bands].gap then
			self.cooldownUntil = t + APPROACH_COMMIT -- chosen over an attack: it walks for a while before it chooses again
		end
		if choice ~= "Wait" and choice ~= "Approach" then
			machine:transition("Telegraph", choice)
		elseif choice == "Approach" or gap > self.attacks.standGap then
			self:moveToward(gap)
		else
			self:stop()
		end
	end,
}

STATES.Telegraph = {
	enter = function(machine, _, name)
		local self = machine.context
		self:stop()
		local spec = self.attacks[name]
		local scale = if self.enraged and name ~= "Roar" then self.attacks.enrage.windupScale else 1
		self.attack = { name = name, spec = spec, windup = spec.windup * scale, hit = {} }
		table.insert(self.history, name)
		self.service.setState(self.model, "Telegraph")
		-- Played faster when enraged, so the clip reaches its strike as the shorter windup ends.
		self.service.playAnim(self.model, spec.clip, 1 / scale)
		self.model:SetAttribute("AttackT0", now())
		self.model:SetAttribute("AttackWindup", self.attack.windup)
		self.model:SetAttribute("Attack", name)
	end,
	update = function(machine, dt)
		local self = machine.context
		self:face(dt, self.config.turnRate[self.attack.spec.track] or 0)
		if machine:timeInState() >= self.attack.windup then
			machine:transition("Active")
		end
	end,
}

STATES.Active = {
	enter = function(machine)
		local self = machine.context
		self.service.setState(self.model, "Active")
		self.attack.activeStart = now()
		self.sampleClock = SAMPLE_INTERVAL
		if self.attack.spec.shape == "Path" then
			self:startLunge()
		elseif self.attack.name == "Roar" then
			self.enraged = true
			self.model:SetAttribute("Enraged", true)
			local every = self.attacks.enrage.roarEvery
			self.nextRoar = now() + self.random:NextNumber(every.min, every.max)
		end
	end,
	update = function(machine, dt)
		local self = machine.context
		self.facing.CFrame = CFrame.Angles(0, self.heading, 0) -- no turning while it strikes
		if self.lunge and machine:timeInState() >= self.attack.travel then
			self.lunge:Destroy()
			self.lunge = nil
		end
		self.sampleClock += dt
		if self.sampleClock >= SAMPLE_INTERVAL then
			self.sampleClock = 0
			self:sampleHits()
		end
		if machine:timeInState() >= self.attack.spec.active then
			self:sampleHits()
			machine:transition("Recover")
		end
	end,
	exit = function(machine)
		local self = machine.context
		if self.lunge then
			self.lunge:Destroy()
			self.lunge = nil
		end
	end,
}

STATES.Recover = {
	enter = function(machine)
		local self = machine.context
		local spec = self.attack.spec
		self.service.setState(self.model, "Recover")
		if spec.recoverHurtboxes then
			self.service.setHurtboxState(self.model, spec.recoverHurtboxes) -- on its hands: the head is in reach
		end
		self.entry.anklePoise = spec.anklePoise
	end,
	update = function(machine)
		local self = machine.context
		if machine:timeInState() >= self.attack.spec.recovery then
			self:rest()
			self:clearAttack()
			machine:transition("Engage")
		end
	end,
}

STATES.Flinch = {
	enter = function(machine)
		local self = machine.context
		self:clearAttack()
		self:stop()
		self.service.setState(self.model, "Flinch")
		self.service.playAnim(self.model, "Flinch")
	end,
	update = function(machine)
		local self = machine.context
		if machine:timeInState() >= self.config.flinch.duration then
			self:rest()
			machine:transition("Engage")
		end
	end,
}

-- Poise broken: DownedFall, then DownedLoop with the core exposed (docs/10 §1.3).
STATES.Downed = {
	enter = function(machine)
		local self = machine.context
		self:clearAttack()
		self:stop()
		self.loop = false
		self.service.setState(self.model, "Downed")
		self.service.setHurtboxState(self.model, "Downed")
		self.service.playAnim(self.model, "DownedFall")
	end,
	update = function(machine)
		local self = machine.context
		local downed = self.config.downed
		local t = machine:timeInState()
		if not self.loop and t >= downed.fall then
			self.loop = true
			self.service.setCoreExposed(self.model, true, downed.loop)
			self.service.playAnim(self.model, "DownedLoop")
		end
		-- It stays down while a Core Strike is on its way (entry.coreHeld, set through CombatService).
		if t >= downed.fall + downed.loop and now() >= (self.entry.coreHeld or 0) then
			machine:transition("GetUp")
		end
	end,
	exit = function(machine)
		local self = machine.context
		self.service.setCoreExposed(self.model, false)
	end,
}

STATES.GetUp = {
	enter = function(machine)
		local self = machine.context
		local poise = self.config.poise
		-- Each break makes the next one harder: +60 max poise, up to the cap.
		self.entry.maxPoise = math.min(poise.cap, self.entry.maxPoise + poise.perBreak)
		self.entry.poise = self.entry.maxPoise
		self.service.publish(self.model)
		self.service.setState(self.model, "GetUp")
		self.service.setHurtboxState(self.model, "Standing")
		self.service.playAnim(self.model, "GetUp")
	end,
	update = function(machine)
		local self = machine.context
		if machine:timeInState() >= self.config.downed.getUp then
			self:rest()
			machine:transition("Engage")
		end
	end,
}

-- Death, then the Ash Collapse (docs/10 §2): the clients show it; the server leaves ash and removes the body.
STATES.Dead = {
	enter = function(machine)
		local self = machine.context
		self:clearAttack()
		self:stop()
		self.service.setCoreExposed(self.model, false)
		self.service.setState(self.model, "Dead")
		self.service.playAnim(self.model, "Death")
		self.model:SetAttribute("DiedAt", now())
		for _, weld in pairs(self.entry.hurtboxes) do
			weld.Part1.CanQuery = false
		end
	end,
	update = function(machine)
		local self = machine.context
		local t = machine:timeInState()
		if not self.mounds and t >= DEATH.mounds then
			self.mounds = true
			local ground = flat(self.root.Position) + self:lookVector() * 8
			for index = 1, 6 do
				local mound = Instance.new("Part")
				mound.Name = "AshMound"
				mound.Shape = Enum.PartType.Cylinder
				mound.Anchored, mound.CanCollide, mound.CanQuery, mound.CanTouch = true, false, false, false
				mound.Material = Enum.Material.Sand
				mound.Color = if index % 2 == 0 then ASH_DARK else ASH
				local size = self.random:NextNumber(8, 16)
				mound.Size = Vector3.new(self.random:NextNumber(1, 2.4), size, size)
				local angle = index / 6 * 2 * math.pi
				mound.CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * 9, mound.Size.X / 2 - 0.3, math.sin(angle) * 7)) * CFrame.Angles(0, 0, math.rad(90))
				mound:SetAttribute("Grow", DEATH.grow) -- clients let it rise over this long (TitanVFXController)
				mound:AddTag("AshMound")
				mound.Parent = workspace
				Debris:AddItem(mound, 180)
			end
		end
		if t >= DEATH.remove then
			self.service.despawn(self.model)
		end
	end,
}

----------------------------------------------------------------------------------------------------------------
-- Hits taken
----------------------------------------------------------------------------------------------------------------
function Strider:onHit(_hit, result)
	local machine = self.machine
	local state = machine:getState()
	if state == "Dead" then
		return
	end
	if result.hp <= 0 then
		machine:transition("Dead")
		return
	end
	if (result.poise <= 0 or result.clamped) and state ~= "Downed" and state ~= "GetUp" then
		machine:transition("Downed")
		return
	end
	-- Flinch: 60 poise damage inside 1.5 s, outside an active window, at most every 4 s (docs/10 §1.3).
	local flinch = self.config.flinch
	local t = now()
	table.insert(self.poiseLog, { time = t, amount = result.poiseDamage or 0 })
	local sum = 0
	for index = #self.poiseLog, 1, -1 do
		local entry = self.poiseLog[index]
		if t - entry.time > flinch.window then
			table.remove(self.poiseLog, index)
		else
			sum += entry.amount
		end
	end
	if sum >= flinch.threshold and FLINCH_FROM[state] and t >= self.flinchReadyAt then
		self.flinchReadyAt = t + flinch.cooldown
		table.clear(self.poiseLog)
		machine:transition("Flinch")
	end
end

-- Back to how it started: no target, no attack, not enraged, facing the way it spawned (TitanService.reset).
function Strider:reset()
	self:clearAttack()
	self.enraged = false
	self.target = nil
	self.nextRoar, self.flinchReadyAt = 0, 0
	self.cooldownUntil = now() + 1
	self.decisionClock, self.retargetClock = 0, 0
	table.clear(self.history)
	table.clear(self.poiseLog)
	self.heading = yawOf(self.entry.spawn.LookVector)
	self.facing.CFrame = CFrame.Angles(0, self.heading, 0)
	self.machine:transition("Idle")
end

function Strider:step(dt)
	self.machine:update(dt)
end

function Strider:destroy()
	if self.hitConnection then
		self.hitConnection:Disconnect()
		self.hitConnection = nil
	end
	if self.lunge then
		self.lunge:Destroy()
	end
	self.machine:destroy()
end

-- context: { model, root, humanoid, facing, config, entry, attacks, service } from TitanService.spawn.
function Strider.new(context)
	local self = setmetatable(context, Strider)
	self.heading = yawOf(self.root.CFrame.LookVector)
	self.random = Random.new()
	self.history = {}
	self.poiseLog = {}
	self.decisionClock, self.retargetClock, self.lastMove = 0, 0, 0
	self.cooldownUntil, self.nextRoar, self.flinchReadyAt = now() + 1, 0, 0
	self.enraged = false
	self.machine = StateMachine.new(STATES, "Idle", self)
	self.hitConnection = self.service.Hit:Connect(function(model, hit, result)
		if model == self.model then
			self:onHit(hit, result)
		end
	end)
	return self
end

return Strider
