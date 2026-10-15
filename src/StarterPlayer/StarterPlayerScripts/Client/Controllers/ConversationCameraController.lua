--!nonstrict
-- Client/Controllers/ConversationCameraController.lua  (docs/11 §6 "Conversation soft framing"; docs/05 S05; D-093)
--
-- During a conversation (a dialogue in conversation mode, on foot) the camera eases in 0.5 s to a two-shot of
-- Elias and the NPC speaking: from the midpoint of their heads, 9 studs to the side and 2 up, looking at the
-- midpoint. It moves on to whoever speaks next (Elias's own lines keep the last NPC). docs/05 S05: the camera
-- stays the player's: the first time they move it (mouse look, wheel, right stick, a drag), the framing lets go
-- for the rest of that conversation. A wall close on the camera's side puts it on the other side if that is
-- clearer, else closer. Cinematics, cinematic-mode dialogues and piloting are left alone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shots = require(script.Parent.Parent.UI.CinematicShots)
local CameraController = require(script.Parent.CameraController)
local CinematicController = require(script.Parent.CinematicController)
local DialogueController = require(script.Parent.DialogueController)

local ConversationCameraController = {}

local SIDE, UP = 9, 2 -- studs (docs/11 §6)
local EASE = 0.5 -- seconds
local STICK = 0.35 -- right-stick deflection that counts as the player moving the camera

local localPlayer = Players.LocalPlayer
local framing = nil -- { npc, side, from, started }
local released = false -- the player moved the camera during this conversation
local lastReason = nil -- why the framing last let go (for tests)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function headOf(model)
	local head = model and model:FindFirstChild("Head")
	return head and head:IsA("BasePart") and head.Position or nil
end

-- Where the two-shot stands for the pair, on `side` (+1 / -1) of the line between them, pulled in front of a
-- wall. Returns the camera's CFrame and how far it could go (of SIDE).
local function shotFor(npc, side)
	local a, b = headOf(localPlayer.Character), headOf(npc)
	if not a or not b then
		return nil, 0
	end
	local mid = (a + b) / 2
	local across = (b - a) * Vector3.new(1, 0, 1)
	if across.Magnitude < 0.1 then
		return nil, 0
	end
	params.FilterDescendantsInstances = { localPlayer.Character, workspace:FindFirstChild("Runtime") }
	local offset = across.Unit:Cross(Vector3.yAxis) * SIDE * side + Vector3.new(0, UP, 0)
	local hit = workspace:Raycast(mid, offset, params)
	local reach = if hit then math.max(0.5, (hit.Position - mid).Magnitude - 0.5) else offset.Magnitude -- in front of it
	return CFrame.lookAt(mid + offset.Unit * reach, mid), reach
end

local function release(reason)
	if not framing then
		return
	end
	framing, lastReason = nil, reason
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function frame(npc)
	if released or not npc then
		return
	end
	local camera = workspace.CurrentCamera
	if framing and framing.npc == npc then
		return
	end
	if not framing then
		-- Only take a camera that is the player's ordinary one.
		if camera.CameraType ~= Enum.CameraType.Custom or CinematicController.isPlaying() or CameraController.getState().following then
			return
		end
	end
	-- The side the camera is already on, so it doesn't swing across the pair, unless a wall stands close on that
	-- side and the other is clearer. Chosen once per shot, so it never flips between frames.
	local a, b = headOf(localPlayer.Character), headOf(npc)
	if not a or not b or ((b - a) * Vector3.new(1, 0, 1)).Magnitude < 0.1 then
		return
	end
	local sideways = ((b - a) * Vector3.new(1, 0, 1)).Unit:Cross(Vector3.yAxis)
	local side = if framing then framing.side elseif (camera.CFrame.Position - (a + b) / 2):Dot(sideways) >= 0 then 1 else -1
	local _, reach = shotFor(npc, side)
	if reach < SIDE * 0.75 then
		local _, otherReach = shotFor(npc, -side)
		if otherReach > reach then
			side = -side
		end
	end
	framing = { npc = npc, side = side, from = camera.CFrame, started = os.clock() }
	camera.CameraType = Enum.CameraType.Scriptable
end

local function onLine(code, mode)
	if mode == nil then
		-- The dialogue closed.
		release("closed")
		released = false
		return
	end
	if mode ~= "conversation" or not code then
		return
	end
	local npc = if code == "E" then select(2, Shots.speakers("E")) else Shots.speakers(code)
	if code == "E" and framing then
		return -- Elias's lines keep the shot on the NPC he talks to
	end
	frame(npc)
end

local function step()
	if not framing then
		return
	end
	local camera = workspace.CurrentCamera
	if not framing.npc.Parent or CinematicController.isPlaying() or camera.CameraType ~= Enum.CameraType.Scriptable then
		-- The NPC left, a cinematic took over, or something else has the camera.
		framing, lastReason = nil, "taken"
		return
	end
	local goal = shotFor(framing.npc, framing.side)
	if not goal then
		return
	end
	local t = math.clamp((os.clock() - framing.started) / EASE, 0, 1)
	local eased = 1 - (1 - t) * (1 - t)
	camera.CFrame = if t < 1 then framing.from:Lerp(goal, eased) else goal
	camera.Focus = CFrame.new(goal.Position + goal.LookVector * SIDE)
end

local function letGo(reason)
	if framing then
		released = true
		release(reason)
	end
end

function ConversationCameraController.isFraming(): boolean
	return framing ~= nil
end

-- For tests: { framing, released, reason (why it last let go) }.
function ConversationCameraController.getState()
	return { framing = framing ~= nil, released = released, reason = lastReason }
end

function ConversationCameraController.Init() end

function ConversationCameraController.Start()
	DialogueController.Line:Connect(onLine)
	RunService:BindToRenderStep("PG_ConversationCamera", Enum.RenderPriority.Camera.Value + 2, step)
	-- The player moving the camera takes it back (docs/05 S05).
	UserInputService.InputChanged:Connect(function(input, processed)
		if not framing then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseWheel and not processed then
			letGo("wheel")
		elseif kind == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			letGo("mouse")
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > STICK then
			letGo("stick")
		elseif kind == Enum.UserInputType.Touch and not processed and input.Delta.Magnitude > 4 then
			letGo("touch")
		end
	end)
	localPlayer.CharacterAdded:Connect(function()
		framing, released, lastReason = nil, false, "respawned"
	end)
end

return ConversationCameraController
