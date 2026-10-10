--!strict
-- Client/Controllers/CombatController.lua  (docs/12_combat_system.md §5, §11; docs/11 §5.6)
--
-- The pilot's side of Frame combat: buffers attack and dodge presses, predicts the clip, asks the server
-- (Frame_Action), follows the server's answer (the Frame's Action / ActionT0 / ActionSeq attributes and
-- Combat_Feedback), and drives the root motion of the dodge and the heavy lunge on the Frame it owns.
-- The server decides everything that counts; this only makes it feel immediate.
--
--   getAction() -> { name, elapsed, predicted }?          -- for the HUD and tests
--   Hit: Signal(payload)        a hit of ours landed ({ zone, amount, poise, pos, move, targetId })
--   Refused: Signal(reason)     "Locked" | "NoEnergy" | "Cooldown" | "Busy" | "NoTarget" | "Rejected"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraFeel = require(Shared.Config.CameraFeel)
local CombatConfig = require(Shared.Config.CombatConfig)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local AnimationController = require(script.Parent.AnimationController)
local FrameController = require(script.Parent.FrameController)
local InputController = require(script.Parent.InputController)

local REQUESTS = { Light = true, Heavy = true, Dodge = true, Special = true, CoreStrike = true }
local PREDICTED_SLACK = 0.3 -- a predicted action nobody confirmed or refused is dropped this long after its end

local CombatController = {}

CombatController.Hit = Signal.new() :: Signal.Signal<any>
CombatController.Refused = Signal.new() :: Signal.Signal<string>

type Action = { name: string, kind: string, move: any, t0: number, predicted: boolean, seq: number?, direction: Vector3?, chained: boolean?, serverT0: number? }

local player = Players.LocalPlayer
local frame: Model? = nil
local action: Action? = nil
local buffered: { name: string, at: number }? = nil
local pending: { seq: number, at: number }? = nil
local sequence = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function describe(model: Model, name: string): (string, any)
	local class = model:GetAttribute("Class") :: string
	if name == "Dodge" then
		return "dodge", (CombatConfig.Dodge :: any)[class]
	end
	return "attack", (CombatConfig.Frames :: any)[class][name]
end

local function drop(reason: string)
	buffered = nil
	CombatController.Refused:Fire(reason)
end

-- Takes back a prediction the server didn't confirm.
local function cancel(model: Model)
	if action and action.predicted then
		AnimationController.cancelLocal(model)
		action = nil
	end
	pending = nil
end

local function predict(model: Model, request: string, name: string)
	local root = model.PrimaryPart :: BasePart
	sequence += 1
	local kind, move = describe(model, name)
	local direction: Vector3? = nil
	local clip = move.clip
	if kind == "dodge" then
		-- Toward the move input; a backstep with none.
		local character = player.Character
		local pilot = character and character:FindFirstChildOfClass("Humanoid")
		local input = if pilot then pilot.MoveDirection * Vector3.new(1, 0, 1) else Vector3.zero
		direction = if input.Magnitude > 0.1 then input.Unit else -root.CFrame.LookVector
		clip = CombatConfig.dodgeClip(root.CFrame:VectorToObjectSpace(direction :: Vector3))
	end
	action = { name = name, kind = kind, move = move, t0 = now(), predicted = true, seq = sequence, direction = direction }
	pending = { seq = sequence, at = os.clock() }
	buffered = nil
	AnimationController.playLocal(model, clip)
	Net.fireServer("Frame_Action", { action = request, dir = direction, seq = sequence })
end

local function ready(model: Model, attribute: string): boolean
	return ((model:GetAttribute(attribute) :: number?) or 0) <= now()
end

-- Sends the buffered press as soon as it would be valid (docs/12 §5).
local function tryBuffered(model: Model)
	local press = buffered
	if not press then
		return
	end
	if os.clock() - press.at > CombatConfig.INPUT_BUFFER then
		buffered = nil
		return
	end
	if model:GetAttribute("WeaponsLocked") then
		return drop("Locked")
	end
	local class = model:GetAttribute("Class") :: string
	local idle = action == nil and model:GetAttribute("State") == "Idle"
	local energy = (model:GetAttribute("Energy") :: number?) or 0
	local name = press.name

	if name == "Light" then
		local current = action
		if idle then
			predict(model, "Light", CombatConfig.Requests.Light)
		elseif current and current.kind == "attack" and current.move.chain and not current.chained then
			-- Queue the next light on the server; its clip starts when the server starts it.
			current.chained = true
			buffered = nil
			sequence += 1
			Net.fireServer("Frame_Action", { action = "Light", seq = sequence })
		end
	elseif name == "Heavy" or name == "Special" then
		local moveName = (CombatConfig.Requests :: any)[name]
		local move = (CombatConfig.Frames :: any)[class][moveName]
		if not idle then
			return
		elseif not ready(model, moveName .. "ReadyAt") then
			return drop("Cooldown")
		elseif energy < move.energy then
			return drop("NoEnergy")
		end
		predict(model, name, moveName)
	elseif name == "Dodge" then
		local dodge = (CombatConfig.Dodge :: any)[class]
		local current = action
		local cancels = false
		if current and current.kind == "attack" then
			local elapsed = now() - current.t0
			local move = current.move
			cancels = (move.dodgeCancelBefore ~= nil and elapsed < move.dodgeCancelBefore)
				or (move.cancelRecovery == true and elapsed >= move.startup + move.active + move.recovery * CombatConfig.RECOVERY_CANCEL)
		end
		if not (idle or cancels) then
			return
		elseif not ready(model, "DodgeReadyAt") then
			return drop("Cooldown")
		elseif energy < dodge.energy then
			return drop("NoEnergy")
		end
		predict(model, "Dodge", "Dodge")
	else
		drop("NoTarget") -- Core Strike arrives with the Titans
	end
end

-- The server's word on what the Frame is doing replaces whatever was predicted.
local function followServer(model: Model)
	local name = model:GetAttribute("Action") :: string?
	local t0 = model:GetAttribute("ActionT0") :: number?
	local current = action
	if name and name ~= "" and t0 then
		if pending and model:GetAttribute("ActionSeq") == pending.seq then
			pending = nil
		end
		if not current or current.predicted or current.serverT0 ~= t0 or current.name ~= name then
			local kind, move = describe(model, name)
			local direction = if current and current.name == name then current.direction else nil
			if kind == "dodge" and not direction then
				direction = -(model.PrimaryPart :: BasePart).CFrame.LookVector
			end
			-- Keep the predicted start time for our own action: the movement already began on it.
			local start = if current and current.predicted and current.name == name then current.t0 else t0
			action = { name = name, kind = kind, move = move, t0 = start, predicted = false, direction = direction, serverT0 = t0 }
		end
	elseif current and not current.predicted then
		action = nil
	end
end

local function rootMotion(model: Model, current: Action): Vector3?
	local elapsed = now() - current.t0
	local move = current.move
	if current.kind == "dodge" then
		if elapsed <= move.duration and current.direction then
			return current.direction * (move.distance / move.duration)
		end
	elseif move.lunge and elapsed >= move.lunge.from and elapsed <= move.lunge.to then
		return (model.PrimaryPart :: BasePart).CFrame.LookVector * (move.lunge.distance / (move.lunge.to - move.lunge.from))
	end
	return nil
end

local function update()
	local model = frame
	if not model then
		return
	end
	followServer(model)
	local current = action
	if current and current.predicted then
		local length = if current.kind == "dodge" then current.move.duration + current.move.settle else CombatConfig.total(current.move)
		local unanswered = pending ~= nil and os.clock() - pending.at > CombatConfig.PREDICTION_TIMEOUT
		if unanswered or now() - current.t0 > length + PREDICTED_SLACK then
			cancel(model)
		end
	end
	if InputController.getContext() == "Frame" then
		tryBuffered(model)
	else
		buffered = nil
	end
	current = action
	-- Attacks leave part of the walk speed; a dodge is all root motion.
	local scale = if current and current.kind == "attack" then CombatConfig.ATTACK_MOVE_SCALE else 0
	FrameController.setAction(current ~= nil, if current then rootMotion(model, current) else nil, scale)
end

function CombatController.getAction()
	local current = action
	return current and { name = current.name, elapsed = now() - current.t0, predicted = current.predicted }
end

function CombatController.Start()
	InputController.ActionPressed:Connect(function(name: string, began: boolean)
		if began and frame and REQUESTS[name] then
			buffered = { name = name, at = os.clock() }
		end
	end)
	FrameController.Piloting:Connect(function(model: Model?)
		frame = model
		action, buffered, pending = nil, nil, nil
		FrameController.setAction(false, nil)
	end)
	frame = FrameController.getFrame()
	Net.on("Combat_Feedback", function(payload: any)
		local model = frame
		if not model then
			return
		end
		if payload.kind == "Rejected" or payload.kind == "NoEnergy" then
			if pending and payload.seq == pending.seq then
				cancel(model)
			end
			CombatController.Refused:Fire(payload.reason or payload.kind)
		elseif payload.kind == "HitLanded" then
			local event = (CameraFeel.Events :: any)[(CameraFeel.MoveEvent :: any)[payload.move]]
			if event and event.hitstop then
				AnimationController.hitstop(model, event.hitstop)
			end
			CombatController.Hit:Fire(payload)
		end
	end)
	-- Just before FrameController's own step, which applies the movement lock and the root motion.
	RunService:BindToRenderStep("PG_FrameCombat", Enum.RenderPriority.Input.Value, update)
end

return CombatController
