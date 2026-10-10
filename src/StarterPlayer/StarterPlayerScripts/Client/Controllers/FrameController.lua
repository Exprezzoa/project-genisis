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
--   setAction(busy, velocity?, moveScale?)   CombatController: while an action runs the Frame walks at moveScale
--                                 of its speed (0 = not at all); velocity = the action's root motion
--   isShiftLocked() -> boolean    aim lock: the Frame faces where the camera looks and strafes (Left Ctrl)
--   isStriding() -> boolean
--   getState() -> { speed, target, heading, striding }       -- for tests
--   Piloting: Signal(frame?)      fired when the player starts or stops piloting

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared.Config.Bindings)
local CombatConfig = require(Shared.Config.CombatConfig)
local FrameConfig = require(Shared.Config.FrameConfig)
local Signal = require(Shared.Modules.Signal)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)

-- Frame states in which the pilot may walk (docs/09 §4). Attacks get their own rules with combat.
local MOVING_STATES = { Idle = true, Attack = true }
local INPUT_EPSILON = 0.05
local SEPARATION_REFRESH = 1 -- seconds between looks for the bodies to keep away from

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
local busy = false -- an action runs: no turning toward the movement, no stride
local moveScale = 1 -- share of the speed the running action leaves
local shiftLock = false
local rootVelocity: Vector3? = nil -- the action's root motion (dodge, lunge), world XZ
local rootMotion: LinearVelocity? = nil
local bodies: { { root: BasePart, radius: number, titan: Model? } } = {}
local bodiesAt = 0

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

-- Separation (docs/12 §9): Titans and other standing Frames push this Frame out of their bodies; they never
-- move for it. A Titan is any model with a TargetId and hurtboxes (the training simulacrum counts).
local function refreshBodies(own: Model)
	table.clear(bodies)
	local seen: { [Model]: boolean } = {}
	for _, hurtbox in ipairs(CollectionService:GetTagged("Hurtbox")) do
		local model = hurtbox:FindFirstAncestorWhichIsA("Model")
		if model and not seen[model] and model:GetAttribute("TargetId") ~= nil and model.PrimaryPart then
			seen[model] = true
			table.insert(bodies, { root = model.PrimaryPart, radius = CombatConfig.Separation.titanRadius, titan = model })
		end
	end
	local folder = own.Parent
	for _, other in ipairs(if folder then folder:GetChildren() else {}) do
		if other ~= own and other:IsA("Model") and other.PrimaryPart and other:GetAttribute("State") ~= "Parked" then
			table.insert(bodies, { root = other.PrimaryPart, radius = CombatConfig.Separation.allyRadius })
		end
	end
end

local function separation(own: Model, position: Vector3): Vector3
	if os.clock() - bodiesAt > SEPARATION_REFRESH then
		bodiesAt = os.clock()
		refreshBodies(own)
	end
	local push = Vector3.zero
	for _, body in ipairs(bodies) do
		if body.root.Parent then
			local away = (position - body.root.Position) * Vector3.new(1, 0, 1)
			local distance = away.Magnitude
			-- A Titan that is down on its hands takes up more ground than one that stands.
			local low = body.titan ~= nil and (body.titan:GetAttribute("HurtboxState") or "Standing") ~= "Standing"
			local radius = if low then CombatConfig.Separation.titanLowRadius else body.radius
			if distance < radius and distance > 0.01 then
				push += away.Unit * math.min(CombatConfig.Separation.maxPush, (radius - distance) * CombatConfig.Separation.gain)
			end
		end
	end
	return push
end

local function update(dt: number)
	local model, pilotHumanoid, rootPart = frame, humanoid, root
	if not (model and pilotHumanoid and rootPart and rootPart.Parent) then
		return
	end
	local canMove = moveScale > 0 and MOVING_STATES[model:GetAttribute("State")] == true and InputController.getContext() == "Frame"

	-- Root motion (docs/11 §5.6): the action moves the Frame, not the legs.
	local push, drive = rootVelocity, rootMotion
	if drive then
		if drive.Enabled and not push then
			-- The action's movement is over: the Frame stops where the action ends instead of sliding on at its
			-- speed (a dodge was measured sliding 21 studs past its 88).
			rootPart.AssemblyLinearVelocity *= Vector3.yAxis
		end
		drive.Enabled = push ~= nil
		if push then
			local apart = separation(model, rootPart.Position)
			drive.PlaneVelocity = Vector2.new(push.X + apart.X, push.Z + apart.Z)
			speed, target = 0, 0
			pilotHumanoid.WalkSpeed = 0
			pilotHumanoid:Move(Vector3.zero, false)
			if facing then
				facing.CFrame = CFrame.Angles(0, heading, 0)
			end
			return
		end
	end

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
	local stride = striding and amount > 0 and not limping and not busy
	CameraController.setStride(stride)

	target = (if stride then config.strideSpeed else config.walkSpeed) * amount * (if limping then config.limp.walkScale else 1) * moveScale
	if speed < target then
		speed = math.min(target, speed + config.acceleration * dt)
	else
		speed = math.max(target, speed - config.deceleration * dt)
	end

	if amount > 0 then
		moveDirection = input.Unit
	end
	if shiftLock then
		-- Aim lock: the Frame faces where the camera looks and strafes, also while it attacks.
		heading = turnToward(heading, CameraController.getYaw(), math.rad(config.turnRate.locked) * dt)
	elseif amount > 0 and not busy then
		-- Free mode: the Frame turns toward where it walks, at its turn rate. A running attack keeps its aim.
		local rate = math.rad(if stride then config.turnRate.stride else config.turnRate.free)
		heading = turnToward(heading, yawOf(moveDirection), rate * dt)
	end
	if facing then
		facing.CFrame = CFrame.Angles(0, heading, 0)
	end

	-- While it slows down with no input the Frame keeps going the way it went. Separation is added on top.
	local velocity = moveDirection * speed + separation(model, rootPart.Position)
	local pace = velocity.Magnitude
	pilotHumanoid.WalkSpeed = pace
	pilotHumanoid:Move(if pace > 0.01 then velocity.Unit else Vector3.zero, false)
end

local function stop()
	local old, oldHumanoid = frame, humanoid
	if not old then
		return
	end
	RunService:UnbindFromRenderStep("PG_FrameMove")
	if rootMotion then
		rootMotion:Destroy()
		rootMotion = nil
	end
	busy, rootVelocity, moveScale, shiftLock = false, nil, 1, false
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
	-- The root-motion drive: a velocity in the ground plane, on while an action asks for one.
	local drive = Instance.new("LinearVelocity")
	drive.Name = "RootMotion"
	drive.Attachment0 = rootPart:FindFirstChild("FacingAttachment") :: Attachment?
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.MaxForce = math.huge
	drive.Enabled = false
	drive.Parent = rootPart
	rootMotion = drive
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

function FrameController.setAction(isBusy: boolean, velocity: Vector3?, scale: number?)
	busy, rootVelocity = isBusy, velocity
	moveScale = if isBusy then (scale or 0) else 1
end

function FrameController.isShiftLocked(): boolean
	return shiftLock
end

function FrameController.isStriding(): boolean
	return striding
end

function FrameController.getState()
	return { speed = speed, target = target, heading = heading, striding = striding, piloting = frame ~= nil, shiftLock = shiftLock }
end

function FrameController.Start()
	InputController.ActionPressed:Connect(function(action: string, began: boolean, input: InputObject?)
		if frame and action == "ShiftLock" and began then
			shiftLock = not shiftLock
			return
		end
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
