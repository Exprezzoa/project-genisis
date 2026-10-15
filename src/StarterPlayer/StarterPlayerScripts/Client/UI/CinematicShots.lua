--!nonstrict
-- Client/UI/CinematicShots.lua  (docs/11_controls_and_camera.md §6)
--
-- What CinematicController places its cameras with, and its one-off effects; no state of its own.
--   vec(t)                         { x, y, z } -> Vector3
--   camPoint(camId) -> pos, look   a CinematicCam part (attribute LookAt), nil if missing
--   headOf(titan) -> Vector3?      a Titan's head height, to look at
--   overShoulder(params)           over the player's Frame's right shoulder toward params.titan (S28, S31)
--   reverse(params)                from behind params.titan's head toward the player's Frame (S31 beat 6)
--   hatch(frame) -> from, to, look the first boarding's close-up; turns the character to the hatch (S08)
--   staticFlash(layer, seconds)    flickering grey bars over the screen (S31 beat 6)
--   tapHatch(alive) -> connection? the TapHatch arm gesture on the player's character while alive() holds

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)

local Shots = {}

local TAG = "CinematicController"
local localPlayer = Players.LocalPlayer

function Shots.vec(t)
	return Vector3.new(t[1], t[2], t[3])
end

function Shots.camPoint(id: string): (Vector3?, Vector3?)
	for _, part in ipairs(game:GetService("CollectionService"):GetTagged("CinematicCam")) do
		if part:GetAttribute("CamId") == id then
			local look = part:GetAttribute("LookAt")
			return part.Position, if typeof(look) == "Vector3" then look else part.Position + part.CFrame.LookVector * 50
		end
	end
	Log.warn(TAG, "no cam point %s", tostring(id))
	return nil, nil
end

local function rootOf(model): BasePart?
	return typeof(model) == "Instance" and model:IsA("Model") and model.PrimaryPart or nil
end

function Shots.headOf(titan): Vector3?
	local root = rootOf(titan)
	if not root then
		return nil
	end
	return root.Position + Vector3.new(0, titan:GetExtentsSize().Y * 0.35, 0)
end

-- Over Unit 02's right shoulder toward a Titan: 34 back, 14 right, 24 up from its root.
function Shots.overShoulder(params): (Vector3?, Vector3?)
	local frameRoot, titanRoot = rootOf(params.frame), rootOf(params.titan)
	if not frameRoot or not titanRoot then
		return nil, nil
	end
	local toward = (titanRoot.Position - frameRoot.Position) * Vector3.new(1, 0, 1)
	if toward.Magnitude < 1 then
		return nil, nil
	end
	toward = toward.Unit
	local right = toward:Cross(Vector3.yAxis)
	local look = titanRoot.Position + Vector3.new(0, params.titan:GetExtentsSize().Y * 0.3, 0)
	return frameRoot.Position - toward * 34 + right * 14 + Vector3.new(0, 24, 0), look
end

-- Behind the Titan's head, looking at the player's Frame (its head height).
function Shots.reverse(params): (Vector3?, Vector3?)
	local head, frameRoot = Shots.headOf(params.titan), rootOf(params.frame)
	if not head or not frameRoot then
		return nil, nil
	end
	local target = frameRoot.Position + Vector3.new(0, 22, 0)
	local away = (head - target) * Vector3.new(1, 0, 1)
	if away.Magnitude < 1 then
		return nil, nil
	end
	away = away.Unit
	local right = away:Cross(Vector3.yAxis)
	return head + away * 14 + right * 8 + Vector3.new(0, 6, 0), target
end

-- The first boarding's close-up: Elias turns to the hatch; from beside him at shoulder height, drifting in.
function Shots.hatch(frame): (Vector3?, Vector3?, Vector3?)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hatch = typeof(frame) == "Instance" and frame:FindFirstChild("Hatch")
	if not root or not hatch then
		return nil, nil, nil
	end
	local flat = Vector3.new(hatch.Position.X - root.Position.X, 0, hatch.Position.Z - root.Position.Z)
	if flat.Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	local cf = root.CFrame
	local look = hatch.Position:Lerp(root.Position + Vector3.new(0, 1.5, 0), 0.35)
	local from = root.Position + cf.RightVector * 2.6 + Vector3.new(0, 1.6, 0) + cf.LookVector * 0.6
	return from, from:Lerp(look, 0.15), look
end

-- The 0.2 s of static the Watcher's look puts on the player's screen (S31 beat 6): flickering grey bars.
function Shots.staticFlash(layer, seconds)
	local holder = Instance.new("Frame")
	holder.Name = "Static"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 10
	holder.Parent = layer
	local bars = {}
	for index = 1, 26 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.ZIndex = 10
		bar.Parent = holder
		bars[index] = bar
	end
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds do
			for _, bar in ipairs(bars) do
				local grey = math.random(120, 235) / 255
				bar.BackgroundColor3 = Color3.new(grey, grey, grey)
				bar.BackgroundTransparency = math.random() * 0.6
				bar.Position = UDim2.fromScale(math.random() * 0.2 - 0.1, math.random())
				bar.Size = UDim2.new(1.2, 0, 0, math.random(2, 14))
			end
			RunService.RenderStepped:Wait()
		end
		holder:Destroy()
	end)
end

-- TapHatch (docs/08 §4.6) on the player's own character: RightShoulder (95, 0, -10), RightElbow 30, two 8° taps
-- a quarter second apart, 1.2 s in all; laid over the Animator's pose in PreSimulation like the NPC gestures.
function Shots.tapHatch(alive: () -> boolean): RBXScriptConnection?
	local character = localPlayer.Character
	local upper = character and character:FindFirstChild("RightUpperArm")
	local lower = character and character:FindFirstChild("RightLowerArm")
	local shoulder = upper and upper:FindFirstChild("RightShoulder")
	local elbow = lower and lower:FindFirstChild("RightElbow")
	if not shoulder or not elbow then
		return nil
	end
	local started = os.clock()
	local connection
	connection = RunService.PreSimulation:Connect(function()
		local t = os.clock() - started
		if not alive() or t > 1.2 then
			connection:Disconnect()
			return
		end
		local w = math.clamp(t / 0.25, 0, 1) * math.clamp((1.2 - t) / 0.2, 0, 1)
		local tap = 0
		for _, at in ipairs({ 0.55, 0.8 }) do
			local d = (t - at) / 0.125
			if d > -1 and d < 1 then
				tap += 1 - d * d
			end
		end
		shoulder.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(95) * w, 0, math.rad(-10) * w)
		elbow.Transform *= CFrame.fromEulerAnglesYXZ(math.rad(30 + 8 * tap) * w, 0, 0)
	end)
	return connection
end

return Shots
