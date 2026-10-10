--!strict
-- Client/Controllers/FrameController.lua  (docs/11_controls_and_camera.md §5, docs/09 §4, Config/FrameConfig)
--
-- Piloting on the pilot's own machine, which owns the Frame's physics: camera-relative movement with
-- acceleration and deceleration, stride, the turn-rate limited facing, and the switch between the on-foot
-- and Frame input contexts and cameras. The server decides who pilots what (the Frame's Pilot attribute).
--
-- The move input is the seated pilot's own Humanoid.MoveDirection: Roblox's control script keeps filling it
-- from the keyboard, gamepad or touch stick, already turned by the camera, and a seated Humanoid doesn't act
-- on it. (This place has no PlayerModule in PlayerScripts to ask for a move vector.)
--
--   getFrame() -> Model?          the Frame this player pilots
--   isStriding() -> boolean
--   getState() -> { speed, target, heading, striding }       -- for tests
--   Piloting: Signal(frame?)      fired when the player starts or stops piloting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared.Config.Bindings)
local FrameConfig = require(Shared.Config.FrameConfig)
local Signal = require(Shared.Modules.Signal)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)

-- Frame states in which the pilot may walk (docs/09 §4). Attacks get their own rules with combat.
local MOVING_STATES = { Idle = true }
local INPUT_EPSILON = 0.05

local FrameController = {}

FrameController.Piloting = Signal.new() :: Signal.Signal<Model?>

local player = Players.LocalPlayer
local frame: Model? = nil
local config: any = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local facing: AlignOrientation? = nil
local speed = 0
local target = 0
local heading = 0 -- radians, same convention as the camera's yaw
local moveDirection = Vector3.zero
local striding = false
local watched: { [Model]: RBXScriptConnection } = {}

-- The pilot sits inside the chest: hidden on their own screen, and never able to jump out of the seat.
local function setPilotHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
	local pilot = character:FindFirstChildOfClass("Humanoid")
	if pilot then
		pilot:SetStateEnabled(Enum.HumanoidStateType.Jumping, not hidden)
	end
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- Turns `from` toward `to` by at most `step` radians, the short way round.
local function turnToward(from: number, to: number, step: number): number
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + math.clamp(delta, -step, step)
end

local function update(dt: number)
	local model, pilotHumanoid, rootPart = frame, humanoid, root
	if not (model and pilotHumanoid and rootPart and rootPart.Parent) then
		return
	end
	local canMove = MOVING_STATES[model:GetAttribute("State")] == true and InputController.getContext() == "Frame"

	local input = Vector3.zero
	local character = player.Character
	local pilot = character and character:FindFirstChildOfClass("Humanoid")
	if canMove and pilot then
		local move = pilot.MoveDirection
		input = Vector3.new(move.X, 0, move.Z)
		if input.Magnitude > 1 then
			input = input.Unit
		end
	end
	local amount = input.Magnitude
	if amount < INPUT_EPSILON then
		amount = 0
	end

	local limping = (model:GetAttribute("Integrity") or 1) / (model:GetAttribute("IntegrityMax") or 1) < config.limp.threshold
	local stride = striding and amount > 0 and not limping
	CameraController.setStride(stride)

	target = (if stride then config.strideSpeed else config.walkSpeed) * amount * (if limping then config.limp.walkScale else 1)
	if speed < target then
		speed = math.min(target, speed + config.acceleration * dt)
	else
		speed = math.max(target, speed - config.deceleration * dt)
	end

	if amount > 0 then
		moveDirection = input.Unit
		-- Free mode: the Frame turns toward where it walks, at its turn rate.
		local rate = math.rad(if stride then config.turnRate.stride else config.turnRate.free)
		heading = turnToward(heading, yawOf(moveDirection), rate * dt)
	end
	if facing then
		facing.CFrame = CFrame.Angles(0, heading, 0)
	end

	-- While it slows down with no input the Frame keeps going the way it went.
	pilotHumanoid.WalkSpeed = speed
	pilotHumanoid:Move(if speed > 0.01 then moveDirection else Vector3.zero, false)
end

local function stop()
	local old, oldHumanoid = frame, humanoid
	if not old then
		return
	end
	RunService:UnbindFromRenderStep("PG_FrameMove")
	if oldHumanoid and oldHumanoid.Parent then
		oldHumanoid.WalkSpeed = 0
		oldHumanoid:Move(Vector3.zero, false)
	end
	frame, humanoid, root, facing, config = nil, nil, nil, nil, nil
	speed, target, striding = 0, 0, false
	setPilotHidden(false)
	CameraController.setFrame(nil)
	if InputController.getContext() == "Frame" then
		InputController.setContext("OnFoot")
	end
	FrameController.Piloting:Fire(nil)
end

local function start(model: Model)
	if frame == model then
		return
	end
	stop()
	local class = model:GetAttribute("Class")
	local classConfig = class and (FrameConfig :: any)[class]
	local rootPart = model.PrimaryPart
	local frameHumanoid = model:FindFirstChildOfClass("Humanoid")
	if not (classConfig and rootPart and frameHumanoid) then
		return
	end
	frame, config, root, humanoid = model, classConfig, rootPart, frameHumanoid
	facing = rootPart:FindFirstChild("Facing") :: AlignOrientation?
	speed, target, striding = 0, 0, false
	moveDirection = rootPart.CFrame.LookVector
	heading = yawOf(moveDirection)
	setPilotHidden(true)
	InputController.setContext("Frame")
	CameraController.setFrame(model)
	-- Before the camera, so the camera follows this frame's movement input.
	RunService:BindToRenderStep("PG_FrameMove", Enum.RenderPriority.Input.Value + 1, update)
	FrameController.Piloting:Fire(model)
end

local function refresh(model: Model)
	if model:GetAttribute("Pilot") == player.UserId then
		start(model)
	elseif frame == model then
		stop()
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = model:GetAttributeChangedSignal("Pilot"):Connect(function()
		refresh(model)
	end)
	refresh(model)
end

function FrameController.getFrame(): Model?
	return frame
end

function FrameController.isStriding(): boolean
	return striding
end

function FrameController.getState()
	return { speed = speed, target = target, heading = heading, striding = striding, piloting = frame ~= nil }
end

function FrameController.Start()
	InputController.ActionPressed:Connect(function(action: string, began: boolean, input: InputObject?)
		-- "Sprint" is the on-screen touch button, which stays where it is while piloting.
		if not frame or (action ~= "Stride" and action ~= "Sprint") then
			return
		end
		local toggles = input == nil or (Bindings.ToggleInputs :: any)[input.KeyCode] == true or SettingsController.get("sprintToggle")
		if toggles then
			if began then
				striding = not striding
			end
		else
			striding = began
		end
	end)
	player.CharacterAdded:Connect(function()
		if frame then
			task.defer(setPilotHidden, true)
		end
	end)

	task.spawn(function()
		local folder = workspace:WaitForChild("Frames")
		folder.ChildAdded:Connect(watch)
		folder.ChildRemoved:Connect(function(model)
			local connection = watched[model :: Model]
			if connection then
				connection:Disconnect()
				watched[model :: Model] = nil
			end
			if frame == model then
				stop()
			end
		end)
		for _, model in ipairs(folder:GetChildren()) do
			watch(model)
		end
	end)
end

return FrameController
