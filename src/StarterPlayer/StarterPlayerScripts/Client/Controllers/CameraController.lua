--!strict
-- Client/Controllers/CameraController.lua  (docs/11_controls_and_camera.md §3-4, Config/CameraFeel)
--
-- The Frame camera: a scripted orbit camera behind the piloted Frame. On foot the Roblox default camera runs
-- and this controller does nothing.
--
--   setFrame(model?)         start or stop following a Frame (nil = back to the on-foot camera)
--   getYaw() -> radians      the camera's heading; FrameController turns the move input by it
--   setYaw(radians)          snap the heading (after the server moved the Frame)
--   setLock(point?)          lock-on: point() -> Vector3? is what to keep in view (nil = free camera)
--   setShot(shot?, blendIn?, blendOut?)   a directed view laid over the gameplay camera: shot() -> CFrame;
--                            nil hands the view back over blendOut seconds (the Core Strike camera)
--   setStride(on)            the wider stride field of view
--   suspend(on)              a cinematic has the camera: the Frame camera stops writing it until released
--   shake(magnitude, duration)     a rotational shake that fades out (x the Camera Shake setting)
--   punch(degrees, duration)       a field-of-view kick that eases back
--   getState() -> { yaw, pitch, distance, wanted, fov }      -- for tests
--
-- Angles: yaw 0 looks along -Z and grows turning left; pitch is the camera's elevation above the pivot.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraFeel = require(Shared.Config.CameraFeel)
local GameConfig = require(Shared.Config.GameConfig)

local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)

local Feel = CameraFeel.Frame
local STEP_NAME = "PG_FrameCamera"
local ZOOM_STEP = 0.1 -- share of the zoom range per wheel notch
local STICK_DEADZONE = 0.15
local SHAKE_ANGLE = math.rad(4) -- the swing of a shake of magnitude 1
local SHAKE_SPEED = 28 -- how fast the noise runs

local CameraController = {}

local player = Players.LocalPlayer
local frame: Model? = nil
local root: BasePart? = nil
local yaw, pitch = 0, math.rad(Feel.pitch.default)
local wanted = Feel.distance.default -- the distance the player asked for
local distance = Feel.distance.default -- the distance in use (shorter while something is in the way)
local stride = false
local suspended = false -- a cinematic has the camera
local fov = Feel.fov.base
local stick = Vector2.zero
local lookTouch: InputObject? = nil
local params = RaycastParams.new()
local shakes: { { magnitude: number, start: number, duration: number } } = {}
local punches: { { degrees: number, start: number, duration: number } } = {}
local lockPoint: (() -> Vector3?)? = nil
local lockOffset = 0 -- radians the player has pushed the locked view sideways
local shoulder = Feel.shoulder
local focus = Vector3.zero -- how far the pivot has moved toward the lock point
local shot: (() -> CFrame)? = nil -- a directed view (Core Strike)
local shotLast: CFrame? = nil -- the last CFrame the shot gave, to blend back from
local shotWeight = 0
local shotIn, shotOut = 0.2, 0.3
local liftTo: number? = nil -- the elevation a fresh lock raises the view to, until the player moves it

local function sensitivity(): number
	return SettingsController.get("camSensitivity") or 1
end

local function turn(deltaYaw: number, deltaPitch: number)
	if SettingsController.get("invertY") then
		deltaPitch = -deltaPitch
	end
	if deltaPitch ~= 0 then
		liftTo = nil
	end
	if lockPoint then
		-- Locked on: sideways input only nudges the view, and the nudge decays (docs/11 §4).
		local limit = math.rad(Feel.lock.offset)
		lockOffset = math.clamp(lockOffset - math.rad(deltaYaw), -limit, limit)
	else
		yaw = (yaw - math.rad(deltaYaw)) % (2 * math.pi)
	end
	pitch = math.clamp(pitch + math.rad(deltaPitch), math.rad(Feel.pitch.min), math.rad(Feel.pitch.max))
end

-- The player looks around only while piloting with nothing (menu, dialogue, cinematic) in the way.
local function active(): boolean
	return frame ~= nil and InputController.isGameplay() -- the Frame context, or riding the Titan form (D-095)
end

local function refreshMouse()
	if frame then
		UserInputService.MouseBehavior = if active() then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	end
end

local function refreshFilter()
	local ignore: { Instance } = CollectionService:GetTagged("NoCollideCamera")
	for _, hurtbox in ipairs(CollectionService:GetTagged("Hurtbox")) do -- invisible, but they answer queries
		table.insert(ignore, hurtbox)
	end
	for _, name in ipairs({ "Frames", "Titans" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- "Debris" only collides with the map: the cast passes barriers, Frames, Titans and characters.
	params.CollisionGroup = "Debris"
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local rootPart = root
	if not (camera and rootPart and rootPart.Parent) then
		return
	end
	if suspended then
		return
	end
	if active() and stick.Magnitude > STICK_DEADZONE then
		-- Quadratic response: fine aim near the center, full speed at the rim.
		local rate = Feel.sensitivity.gamepad * sensitivity() * stick.Magnitude * dt
		turn(stick.X * rate, stick.Y * rate)
	end

	-- Lock-on: the view turns to stand off the line to the target and leans toward it, so the Frame doesn't
	-- hide what it fights.
	local point = if lockPoint then lockPoint() else nil
	local lean = Vector3.zero
	if point then
		local toward = (point - rootPart.Position) * Vector3.new(1, 0, 1)
		if toward.Magnitude > 1 then
			local desired = math.atan2(-toward.X, -toward.Z) + math.rad(Feel.lock.side) + lockOffset
			local delta = (desired - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw = (yaw + delta * math.min(1, Feel.lock.yawBlend * dt)) % (2 * math.pi)
			lean = toward * Feel.lock.focus
		end
		lockOffset *= math.exp(-3 * dt / Feel.lock.offsetDecay)
	end
	if liftTo then
		pitch += (liftTo - pitch) * math.min(1, 4 * dt)
		if math.abs(liftTo - pitch) < 0.005 then
			liftTo = nil
		end
	end
	focus += (lean - focus) * math.min(1, Feel.lock.focusBlend * dt)
	shoulder += ((if point then 0 else Feel.shoulder) - shoulder) * math.min(1, 3 * dt / Feel.shoulderBlend)

	local pivot = rootPart.Position + Vector3.new(0, Feel.pivotHeight, 0) + focus
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
	local offset = rotation * Vector3.new(shoulder, 0, wanted)

	-- Something between the pivot and the camera: come in at once, go back out slowly.
	local allowed = wanted
	local hit = workspace:Spherecast(pivot, Feel.collision.radius, offset, params)
	if hit then
		allowed = math.max(Feel.collision.minDistance, hit.Distance / offset.Magnitude * wanted - Feel.collision.pad)
	end
	if allowed < distance then
		distance = allowed
	else
		distance = math.min(allowed, distance + Feel.collision.zoomOutSpeed * dt)
	end

	local target = if stride then Feel.fov.stride else Feel.fov.base
	fov += (target - fov) * math.min(1, dt / Feel.fov.strideBlend * 3)

	-- Shake: every running shake adds its fading magnitude; noise turns the sum into a small rotation.
	local clock = os.clock()
	local magnitude = 0
	for index = #shakes, 1, -1 do
		local entry = shakes[index]
		local age = (clock - entry.start) / entry.duration
		if age >= 1 then
			table.remove(shakes, index)
		else
			magnitude += entry.magnitude * (1 - age)
		end
	end
	local jolt = CFrame.identity
	if magnitude > 0 then
		local swing = magnitude * SHAKE_ANGLE * (SettingsController.get("cameraShake") or 1)
		local n = clock * SHAKE_SPEED
		jolt = CFrame.Angles(math.noise(n, 1.5) * swing, math.noise(n, 7.5) * swing, math.noise(n, 13.5) * swing * 0.5)
	end
	local kick = 0
	for index = #punches, 1, -1 do
		local entry = punches[index]
		local age = (clock - entry.start) / entry.duration
		if age >= 1 then
			table.remove(punches, index)
		else
			kick += entry.degrees * (1 - age) ^ 2
		end
	end

	local view = CFrame.new(pivot + rotation * Vector3.new(shoulder, 0, distance)) * rotation
	-- A directed shot blends in over the gameplay view and back out when it ends.
	if shot then
		shotLast = shot()
		shotWeight = math.min(1, shotWeight + dt / math.max(shotIn, 0.01))
	elseif shotWeight > 0 then
		shotWeight = math.max(0, shotWeight - dt / math.max(shotOut, 0.01))
	end
	if shotWeight > 0 and shotLast then
		local eased = shotWeight * shotWeight * (3 - 2 * shotWeight)
		view = view:Lerp(shotLast, eased)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = view * jolt
	camera.FieldOfView = fov + kick
	camera.Focus = CFrame.new(pivot)
end

function CameraController.getYaw(): number
	return yaw
end

-- Snaps the camera's heading (the server moved the Frame and turned it).
function CameraController.setYaw(value: number)
	yaw = value % (2 * math.pi)
end

function CameraController.setLock(point: (() -> Vector3?)?)
	lockPoint = point
	lockOffset = 0
	local least = math.rad(Feel.lock.pitch)
	liftTo = if point and pitch < least then least else nil
end

function CameraController.setShot(newShot: (() -> CFrame)?, blendIn: number?, blendOut: number?)
	shot = newShot
	if newShot then
		shotIn, shotOut = blendIn or 0.2, blendOut or 0.3
	end
end

function CameraController.setStride(on: boolean)
	stride = on
end

function CameraController.suspend(on: boolean)
	suspended = on
end

function CameraController.shake(magnitude: number, duration: number?)
	if frame then
		table.insert(shakes, { magnitude = magnitude, start = os.clock(), duration = duration or 0.2 })
	end
end

function CameraController.punch(degrees: number, duration: number?)
	if frame then
		table.insert(punches, { degrees = degrees, start = os.clock(), duration = duration or 0.2 })
	end
end

function CameraController.getState()
	return { yaw = yaw, pitch = pitch, distance = distance, wanted = wanted, fov = fov, following = frame ~= nil }
end

function CameraController.setFrame(model: Model?)
	if model == frame then
		return
	end
	local camera = workspace.CurrentCamera
	if frame then
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
	frame = model
	root = if model then model.PrimaryPart else nil
	stride = false
	lookTouch = nil
	table.clear(shakes)
	table.clear(punches)
	lockPoint, lockOffset, shoulder, focus = nil, 0, Feel.shoulder, Vector3.zero
	shot, shotLast, shotWeight = nil, nil, 0
	if model and root then
		-- Start behind the Frame.
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.rad(Feel.pitch.default)
		wanted = Feel.distance.default
		distance = wanted
		fov = Feel.fov.base
		refreshFilter()
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
		refreshMouse()
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = GameConfig.Character.CAMERA_FOV
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end
end

function CameraController.Start()
	UserInputService.InputChanged:Connect(function(input, processed)
		if not active() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local scale = Feel.sensitivity.mouse * sensitivity()
			turn(input.Delta.X * scale, input.Delta.Y * scale)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not lockPoint then -- locked: the wheel cycles zones
			local range = Feel.distance.max - Feel.distance.min
			wanted = math.clamp(wanted - input.Position.Z * range * ZOOM_STEP, Feel.distance.min, Feel.distance.max)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, -input.Position.Y)
		elseif input == lookTouch then
			local scale = Feel.sensitivity.touch * sensitivity()
			turn(input.Delta.X * scale, input.Delta.Y * scale)
		end
	end)
	-- Touch: a drag that starts on the empty right half of the screen looks around.
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed and active() and not lookTouch then
			local camera = workspace.CurrentCamera
			if camera and input.Position.X > camera.ViewportSize.X / 2 then
				lookTouch = input
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == lookTouch then
			lookTouch = nil
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.zero
		end
	end)
	InputController.ContextChanged:Connect(refreshMouse)
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(refreshFilter)
	end)
	for _, other in ipairs(Players:GetPlayers()) do
		other.CharacterAdded:Connect(refreshFilter)
	end
end

return CameraController
