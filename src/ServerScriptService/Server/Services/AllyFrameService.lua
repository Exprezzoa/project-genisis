--!nonstrict
-- Server/Services/AllyFrameService.lua  (docs/09_frames.md §7; docs/12_combat_system.md §9)
--
-- Mara's Unit 01 on a mission: a server-owned Frame that follows the player's Frame, holds a point, fights the
-- Titan beside the player without stealing the fight, or walks where a step sends it. It moves with the player
-- Frame's speeds, acceleration and turn rates (Humanoid:Move from the server every frame; clients animate the
-- gait from its speed), can't be hurt (attribute God), and no Titan picks it as a target (they pick piloted
-- Frames, docs/10 §5). Distances of docs/09 §7 are for the 40-stud Frame and are scaled like it (D-044, D-074).
--
--   setMode(player, mode, params?)    mode: "Follow" | "Hold" | "Combat" | "Scripted" | "Parked"
--      params.place  spawn id to stand at first, or "follow" (its spot behind the player's Frame)
--      params.at     Hold: spawn id to walk to and hold (default: where it stands)
--      params.face   Hold / Scripted: spawn id to face; Hold sweeps its head around that direction ("scanning")
--      params.to     Scripted: spawn id to walk to;   params.stride = true strides there
--   getFrame() -> Model?      getState() -> { mode, position, speed, attacking, contributed }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local FrameConfig = require(Shared.Config.FrameConfig)
local Log = require(Shared.Modules.Log)

local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local FrameService = require(script.Parent.FrameService)
local TitanService = require(script.Parent.TitanService)
local AllyNavigation = require(script.Parent.Parent.Frames.AllyNavigation)

local TAG = "AllyFrameService"
local UNIT = "01"
local S = 1.6 -- the Frame's build scale (D-044)
local FOLLOW_OFFSET = Vector3.new(-20, 0, 12) * S -- left-rear, in the player's Frame's own space
local RETARGET = 0.5 -- seconds between new follow spots
local ARRIVE = 6 * S -- a goal this close counts as reached
local SLOW = 30 * S -- it starts slowing down this far from a goal
local CATCH_UP = 60 * S -- strides when its follow spot is further than this
local FORMATION = 12 * S -- following, it strides to close up when it is further than this from its spot
local ROUTE_EVERY = 0.25 -- seconds between looks at what is in its way
local STUCK = { seconds = 2.5, unseen = 300 } -- stuck this long: moved, if the player can't see it (behind, or this far)
local LOST = { distance = 250 * S, seconds = 4, below = -300 } -- this far from the player's Frame this long (or fallen
-- below `below`): put back behind it
local COMBAT = {
	radius = 45 * S, -- circles the Titan this far out
	angle = 150, -- degrees around the Titan from the player
	corridor = 25 * S, -- never this close to the line from the player to the Titan
	stepIn = 22 * S, -- steps in this close to swing
	every = { 4, 6 }, -- seconds between attacks
	damage = 15, poise = 8, -- per hit, Body zone
	cap = 0.10, -- of the Titan's max HP per fight; poise still counts past it
	moves = { "Light1", "Light2" },
}
local SCAN = { period = 2.6, angle = 40, distance = 300 } -- Hold: the head sweeps ±angle around the facing

local AllyFrameService = {}

local trail = AllyNavigation.Trail.new() -- where the player's Frame has walked: passable ground

local ally = {
	player = nil, frame = nil, mode = "Parked", params = {},
	speed = 0, heading = 0, moveDir = Vector3.zAxis, goal = nil, stride = false, faceYaw = nil,
	nextRetarget = 0, lostSince = nil, holdT0 = 0, holdYaw = nil, nextRoute = 0, steer = nil, stuckFor = 0, inCorridor = false,
	side = 1, nextAttack = 0, attack = nil, contributed = {}, -- [titan model] = HP taken by Mara
}

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

local function config()
	return FrameConfig[ally.frame:GetAttribute("Class")]
end

local function pointOf(id)
	if typeof(id) == "Vector3" then
		return id
	end
	local cframe = id and CharacterService.getSpawnCFrame(id)
	return cframe and cframe.Position
end

local function followSpot(mine)
	local root = mine.PrimaryPart
	local yaw = yawOf(flat(root.CFrame.LookVector))
	local spot = root.Position + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(FOLLOW_OFFSET)
	return Vector3.new(spot.X, root.Position.Y - root.Size.Y / 2 - config().hipHeight, spot.Z), yaw
end

-- Height of a Frame's root center above the ground, and its half width.
local function rootHeight()
	return config().hipHeight + ally.frame.PrimaryPart.Size.Y / 2
end

local function rootRadius()
	local size = ally.frame.PrimaryPart.Size
	return math.max(size.X, size.Z) / 2
end

-- The point to steer for on the way to a goal (AllyNavigation).
local function route(root, goal)
	if AllyNavigation.clear(root.Position, goal, rootHeight(), rootRadius()) then
		return goal
	end
	return trail:toward(root.Position, goal, rootHeight(), rootRadius()) or goal
end

-- Is a point out of the player's sight: behind the player's Frame, or far away?
local function unseen(mine, point)
	if not (mine and mine.PrimaryPart) then
		return true
	end
	local offset = flat(point - mine.PrimaryPart.Position)
	return offset.Magnitude > STUCK.unseen or offset:Dot(flat(mine.PrimaryPart.CFrame.LookVector)) < 0
end

-- Out of its bay and under the server's control (anchored and parked until a mission needs it).
local function activate(player)
	local frame = FrameService.getFrame(UNIT)
	if not (frame and frame.Parent and frame.PrimaryPart) then
		-- Lost or broken (it fell out of the world): a fresh one from the template, parked, then taken out.
		Log.warn(TAG, "Unit %s was missing or broken; spawning it again", UNIT)
		frame = FrameService.spawnFrame(UNIT)
	end
	ally.player, ally.frame = player, frame
	if frame:GetAttribute("AllyActive") then
		return true
	end
	local root = frame.PrimaryPart
	root.Anchored = false
	root:SetNetworkOwner(nil)
	root.Facing.CFrame = root.CFrame.Rotation
	root.Facing.Enabled = true
	frame:SetAttribute("God", true) -- docs/09 §7: Mara is invulnerable
	frame:SetAttribute("AllyActive", true)
	frame:SetAttribute("Pilot", 0)
	FrameService.setState(frame, "Idle")
	FrameService.playAnim(frame, "")
	ally.heading = yawOf(flat(root.CFrame.LookVector))
	ally.moveDir, ally.speed = flat(root.CFrame.LookVector).Unit, 0
	return true
end

local function stand(frame, groundCFrame)
	FrameService.moveTo(frame, groundCFrame)
	ally.heading = yawOf(flat(groundCFrame.LookVector))
	ally.speed = 0
	frame.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
	frame.PrimaryPart.Facing.CFrame = CFrame.Angles(0, ally.heading, 0)
end

-- Ends a running swing chain and puts the Frame back to Idle.
local function endAttack()
	ally.attack = nil
	local frame = ally.frame
	if frame and frame.Parent and frame:GetAttribute("AllyActive") then
		frame:SetAttribute("Action", "")
		FrameService.setState(frame, "Idle")
	end
end

function AllyFrameService.getFrame()
	return if ally.mode ~= "Parked" then ally.frame else nil
end

function AllyFrameService.setMode(player, mode, params)
	params = params or {}
	if mode == "Parked" then
		ally.mode, ally.goal, ally.attack = "Parked", nil, nil
		if ally.frame and ally.frame:GetAttribute("AllyActive") then
			FrameService.spawnFrame(UNIT) -- back in Bay 1, standing and anchored
		end
		ally.frame = nil
		return true
	end
	if not activate(player) then
		return false
	end
	local frame = ally.frame
	if params.place == "follow" then
		local mine = FrameService.getPiloted(player)
		if mine and mine.PrimaryPart then
			local spot, yaw = followSpot(mine)
			stand(frame, CFrame.new(spot) * CFrame.Angles(0, yaw, 0))
		end
	elseif params.place then
		local cframe = CharacterService.getSpawnCFrame(params.place)
		if cframe then
			stand(frame, cframe)
		else
			Log.warn(TAG, "no spawn %s", tostring(params.place))
		end
	end
	endAttack()
	ally.mode, ally.params = mode, params
	ally.goal, ally.stride, ally.faceYaw, ally.holdYaw = nil, false, nil, nil
	ally.nextRetarget, ally.lostSince, ally.holdT0 = 0, nil, os.clock()
	ally.nextRoute, ally.steer, ally.stuckFor = 0, nil, 0
	if mode == "Combat" then
		ally.nextAttack = os.clock() + math.random(COMBAT.every[1], COMBAT.every[2])
	elseif mode == "Hold" then
		-- It holds facing the way the marker faces unless it is told what to face.
		local marker = params.at and CharacterService.getSpawnCFrame(params.at)
		ally.goal = marker and marker.Position
		ally.holdYaw = marker and yawOf(flat(marker.LookVector))
	elseif mode == "Scripted" then
		ally.goal, ally.stride = pointOf(params.to), params.stride == true
	end
	frame:SetAttribute("AllyMode", mode)
	return true
end

----------------------------------------------------------------------------------------------------------------
-- Combat (docs/09 §7)
----------------------------------------------------------------------------------------------------------------
local function titanFor(player, mine)
	local lock = CombatService.getLock(player)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(TitanService.getTitans()) do
		if model.PrimaryPart and model:GetAttribute("State") ~= "Dead" then
			if lock and lock.targetId == model:GetAttribute("TargetId") then
				return model
			end
			local distance = if mine and mine.PrimaryPart then (model.PrimaryPart.Position - mine.PrimaryPart.Position).Magnitude else 0
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

-- Distance from p to the segment a-b, along the ground.
local function toSegment(p, a, b)
	local ab, ap = flat(b - a), flat(p - a)
	local t = if ab.Magnitude > 0.01 then math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (ap - ab * t).Magnitude
end

local function strike(titan, moveName)
	local frame = ally.frame
	if not (titan.Parent and titan.PrimaryPart) or titan:GetAttribute("State") == "Dead" then
		return
	end
	local move = CombatConfig.Frames[frame:GetAttribute("Class")][moveName]
	if flat(titan.PrimaryPart.Position - frame.PrimaryPart.Position).Magnitude > move.reach + CombatConfig.Separation.titanRadius then
		return
	end
	-- Mara's share of the Titan's HP stops at the cap; her poise damage doesn't.
	local cap = (titan:GetAttribute("MaxHP") or 0) * COMBAT.cap
	local given = ally.contributed[titan] or 0
	local damage = math.clamp(cap - given, 0, COMBAT.damage)
	ally.contributed[titan] = given + damage
	CombatService.allyHit({
		frame = frame, targetId = titan:GetAttribute("TargetId"), model = titan, zone = "Body",
		damage = damage, poise = COMBAT.poise, move = moveName, position = titan.PrimaryPart.Position,
	})
end

-- One swing of the attack chain; the next starts when this one's active window has passed.
local function runAttack(titan)
	local frame = ally.frame
	local attack = { titan = titan }
	ally.attack = attack
	-- The next step-in is counted from this one's start (docs/09 §7: every 4-6 s).
	ally.nextAttack = os.clock() + COMBAT.every[1] + math.random() * (COMBAT.every[2] - COMBAT.every[1])
	task.spawn(function()
		for index, moveName in ipairs(COMBAT.moves) do
			if ally.attack ~= attack or not frame.Parent then
				return
			end
			local move = CombatConfig.Frames[frame:GetAttribute("Class")][moveName]
			FrameService.setState(frame, "Attack")
			frame:SetAttribute("Action", moveName)
			FrameService.playAnim(frame, move.clip)
			task.wait(move.startup)
			if ally.attack ~= attack then
				return
			end
			strike(titan, moveName)
			task.wait(move.active + (if index < #COMBAT.moves then CombatConfig.CHAIN_DELAY else move.recovery))
		end
		if ally.attack == attack and frame.Parent then
			endAttack()
		end
	end)
end

local function decideCombat(mine, root)
	local titan = titanFor(ally.player, mine)
	if not (titan and mine and mine.PrimaryPart) then
		ally.goal = nil
		return
	end
	local center = titan.PrimaryPart.Position
	local fromPlayer = flat(mine.PrimaryPart.Position - center)
	local base = yawOf(if fromPlayer.Magnitude > 0.1 then fromPlayer.Unit else Vector3.zAxis)
	local toTitan = flat(center - root.Position)
	ally.faceYaw = if toTitan.Magnitude > 1 then yawOf(toTitan.Unit) else nil
	if ally.attack then
		ally.goal = nil
		return
	end
	-- It keeps to the side of the player-Titan line it is on and heads for its spot 150 degrees round from the
	-- player, which takes it out of the corridor in front of the player's camera.
	local fromCenter = flat(root.Position - center)
	if fromCenter.Magnitude > 0.1 then
		local left = (yawOf(fromCenter.Unit) - base + math.pi) % (2 * math.pi) - math.pi
		ally.side = if left >= 0 then 1 else -1
	end
	ally.inCorridor = toSegment(root.Position, mine.PrimaryPart.Position, center) < COMBAT.corridor
	local around = base + ally.side * math.rad(COMBAT.angle)
	local direction = CFrame.Angles(0, around, 0).LookVector
	local downed = titan:GetAttribute("State") == "Downed" or (titan:GetAttribute("HurtboxState") or "Standing") ~= "Standing"
	if os.clock() >= ally.nextAttack and not downed then
		-- Step in on its own side of the Titan and swing.
		local mineSide = flat(root.Position - center)
		local reach = if mineSide.Magnitude > 0.1 then mineSide.Unit else direction
		ally.goal = center + reach * COMBAT.stepIn
		if toTitan.Magnitude <= COMBAT.stepIn + ARRIVE * 2 then
			runAttack(titan)
		end
	else
		ally.goal = center + direction * COMBAT.radius
	end
	ally.stride = (ally.goal and flat(ally.goal - root.Position).Magnitude or 0) > CATCH_UP
end

----------------------------------------------------------------------------------------------------------------
-- Every frame
----------------------------------------------------------------------------------------------------------------
local function decide(root, mine)
	local mode = ally.mode
	ally.faceYaw = nil
	if mode == "Follow" then
		if not (mine and mine.PrimaryPart) then
			ally.goal = nil -- the player is on foot: it waits where it is
			return
		end
		if os.clock() >= ally.nextRetarget then
			ally.nextRetarget = os.clock() + RETARGET
			-- Its spot left-rear of the player, led by where the player is heading; if a Frame couldn't stand there
			-- (a wall, a wreck), the player's own trail that far back instead.
			local velocity = flat(mine.PrimaryPart.AssemblyLinearVelocity)
			local spot = followSpot(mine) + velocity * RETARGET
			if not AllyNavigation.clear(mine.PrimaryPart.Position, spot, rootHeight(), rootRadius()) then
				spot = trail:behind(FOLLOW_OFFSET.Magnitude) or spot
			end
			ally.goal = spot
			-- It strides with the player, and to close up when it has dropped out of formation.
			ally.stride = velocity.Magnitude > config().walkSpeed * 1.05 or flat(spot - root.Position).Magnitude > FORMATION
		end
		if ally.goal and flat(ally.goal - root.Position).Magnitude <= ARRIVE then
			ally.faceYaw = yawOf(flat(mine.PrimaryPart.CFrame.LookVector))
		end
		-- Left far behind (stuck on the map, or the player was moved) or fallen: back behind the player, on a spot a
		-- Frame can stand on (its formation spot, else the player's own trail).
		if flat(mine.PrimaryPart.Position - root.Position).Magnitude > LOST.distance or root.Position.Y < LOST.below then
			ally.lostSince = ally.lostSince or os.clock()
			if os.clock() - ally.lostSince > LOST.seconds or root.Position.Y < LOST.below then
				local spot, yaw = followSpot(mine)
				if not AllyNavigation.clear(mine.PrimaryPart.Position, spot, rootHeight(), rootRadius()) then
					spot = trail:behind(FOLLOW_OFFSET.Magnitude)
				end
				if spot then
					stand(ally.frame, CFrame.new(spot) * CFrame.Angles(0, yaw, 0))
					Log.debug(TAG, "Unit %s was put back behind %s", UNIT, ally.player.Name)
				end
				ally.lostSince = nil
			end
		else
			ally.lostSince = nil
		end
	elseif mode == "Hold" or mode == "Scripted" then
		local face = pointOf(ally.params.face)
		if face and (not ally.goal or flat(ally.goal - root.Position).Magnitude <= ARRIVE) then
			local toward = flat(face - root.Position)
			if toward.Magnitude > 1 then
				ally.faceYaw = yawOf(toward.Unit)
			end
		elseif mode == "Hold" and ally.holdYaw and (not ally.goal or flat(ally.goal - root.Position).Magnitude <= ARRIVE) then
			ally.faceYaw = ally.holdYaw
		end
	elseif mode == "Combat" then
		decideCombat(mine, root)
	end
end

local function step(dt)
	local frame = ally.frame
	if ally.mode == "Parked" or not (frame and frame.Parent and frame.PrimaryPart) then
		return
	end
	local root = frame.PrimaryPart
	local humanoid = frame:FindFirstChildOfClass("Humanoid")
	local mine = ally.player and FrameService.getPiloted(ally.player)
	if mine and mine.PrimaryPart then
		trail:record(mine.PrimaryPart.Position - Vector3.new(0, rootHeight(), 0))
	end
	decide(root, mine)
	local spec = config()

	-- Where to steer: straight at the goal, or along the player's trail around what is in the way.
	if os.clock() >= ally.nextRoute then
		ally.nextRoute = os.clock() + ROUTE_EVERY
		ally.steer = ally.goal and route(root, ally.goal)
	end
	local target = 0
	if ally.goal and ally.steer and not ally.attack then
		local distance = flat(ally.goal - root.Position).Magnitude
		local toward = flat(ally.steer - root.Position)
		if toward.Magnitude <= ARRIVE and distance > ARRIVE then
			ally.nextRoute = 0 -- reached a trail point: pick the next one now
		end
		if distance > ARRIVE and toward.Magnitude > 0.5 then
			ally.moveDir = toward.Unit
			local top = if ally.stride then spec.strideSpeed else spec.walkSpeed
			target = math.min(top, top * distance / SLOW + spec.walkSpeed * 0.2)
		end
	end
	if ally.speed < target then
		ally.speed = math.min(target, ally.speed + spec.acceleration * dt)
	else
		ally.speed = math.max(target, ally.speed - spec.deceleration * dt)
	end

	-- Stuck (it means to move and doesn't) with neither it nor its goal in front of the player: put it at its goal.
	if target > 10 and flat(root.AssemblyLinearVelocity).Magnitude < 3 then
		ally.stuckFor += dt
	else
		ally.stuckFor = 0
	end
	if ally.stuckFor > STUCK.seconds and ally.goal and ally.mode ~= "Combat" then
		ally.stuckFor = 0
		if unseen(mine, root.Position) and unseen(mine, ally.goal) then
			stand(frame, CFrame.new(ally.goal) * CFrame.Angles(0, ally.heading, 0))
			Log.debug(TAG, "Unit %s was stuck and was moved to its goal", UNIT)
		end
	end

	-- Facing: what it should look at (the Titan, a held direction), else where it walks.
	local rate
	if ally.faceYaw then
		rate = spec.turnRate.locked
		ally.heading = turnToward(ally.heading, ally.faceYaw, math.rad(rate) * dt)
	elseif ally.speed > 1 then
		rate = if ally.stride then spec.turnRate.stride else spec.turnRate.free
		ally.heading = turnToward(ally.heading, yawOf(ally.moveDir), math.rad(rate) * dt)
	end
	root.Facing.CFrame = CFrame.Angles(0, ally.heading, 0)

	-- The ally yields: the player's Frame pushes it out of its body, never the other way (docs/12 §9).
	local push = Vector3.zero
	if mine and mine.PrimaryPart then
		local away = flat(root.Position - mine.PrimaryPart.Position)
		local radius = CombatConfig.Separation.allyRadius
		if away.Magnitude < radius and away.Magnitude > 0.01 then
			push = away.Unit * math.min(CombatConfig.Separation.maxPush, (radius - away.Magnitude) * CombatConfig.Separation.gain)
		end
	end
	-- Nor does it walk into a Titan's body.
	for _, model in ipairs(TitanService.getTitans()) do
		local titanRoot = model.PrimaryPart
		if titanRoot then
			local away = flat(root.Position - titanRoot.Position)
			local low = (model:GetAttribute("HurtboxState") or "Standing") ~= "Standing"
			local radius = if low then CombatConfig.Separation.titanLowRadius else CombatConfig.Separation.titanRadius
			if away.Magnitude < radius and away.Magnitude > 0.01 then
				push += away.Unit * math.min(CombatConfig.Separation.maxPush, (radius - away.Magnitude) * CombatConfig.Separation.gain)
			end
		end
	end
	local velocity = ally.moveDir * ally.speed + push
	local pace = velocity.Magnitude
	humanoid.WalkSpeed = pace
	humanoid:Move(if pace > 0.01 then velocity.Unit else Vector3.zero, false)

	-- Holding: the head sweeps slowly around the direction it faces ("scanning").
	if ally.mode == "Hold" and ally.speed < 1 then
		local sweep = math.sin((os.clock() - ally.holdT0) * 2 * math.pi / SCAN.period) * math.rad(SCAN.angle)
		local look = CFrame.Angles(0, ally.heading + sweep, 0).LookVector
		frame:SetAttribute("LookTarget", root.Position + look * SCAN.distance)
	elseif frame:GetAttribute("LookTarget") ~= nil then
		frame:SetAttribute("LookTarget", nil)
	end
end

function AllyFrameService.getState()
	local frame = ally.frame
	local root = frame and frame.Parent and frame.PrimaryPart
	local contributed = 0
	for model, amount in pairs(ally.contributed) do
		if model.Parent then
			contributed += amount
		end
	end
	return {
		mode = ally.mode, position = root and root.Position, speed = ally.speed, goal = ally.goal, attacking = ally.attack ~= nil,
		contributed = contributed, heading = ally.heading, inCorridor = ally.inCorridor == true,
	}
end

function AllyFrameService.Start()
	RunService.Heartbeat:Connect(step)
	TitanService.Died:Connect(function(model)
		ally.contributed[model] = nil
		if ally.attack and ally.attack.titan == model then
			endAttack()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if ally.player == player then
			AllyFrameService.setMode(player, "Parked")
			ally.player = nil
		end
	end)
end

return AllyFrameService
