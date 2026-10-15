--!nonstrict
-- Client/Controllers/CinematicController.lua  (docs/11_controls_and_camera.md §6; data: Shared/Cinematics)
--
-- Plays what CinematicService sends (Cinematic_Play): a Scriptable camera through the shots, the shared letterbox,
-- the HUD, prompts and waypoints hidden, depth of field on (docs/06: far 0.25, focus on the shot's target, radius
-- 30). A dialogue-driven cinematic cuts to each line's `action.cam` and pushes in slowly until the server stops it;
-- `action.slide` goes to the briefing screen. A `dynamic` shot is placed at run time (the first boarding's close-up
-- beside Elias at the hatch, with his TapHatch arm gesture). A skippable one shows "HOLD [SPACE] TO SKIP" (Space / A / the SKIP
-- button, 1.0 s).
-- Guaranteed restore: the camera type, subject, FOV and CFrame, the mouse, the HUD and the input context are put
-- back by finish(), which runs on the end, a skip, an error, the character dying or respawning, and the server's
-- stop. The Cinematic input context is held (InputController.hold) so lines and menus opened on top return to it.
--
--   play(id, params)     finish(id?, send?)      isPlaying() -> id?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cinematics = require(Shared.Cinematics)
local Easing = require(Shared.Modules.Easing)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local UIStyle = require(Shared.Config.UIStyle)

local BriefingScreen = require(script.Parent.Parent.UI.BriefingScreen)
local Shots = require(script.Parent.Parent.UI.CinematicShots)
local CameraController = require(script.Parent.CameraController)
local Components = require(script.Parent.Parent.UI.Components)
local DialogueController = require(script.Parent.DialogueController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local CinematicController = {}

local TAG = "CinematicController"
local SKIP_HOLD = 1.0 -- seconds (docs/11 §1)
local PUSH_IN = 0.06 -- a dialogue-driven shot drifts this share of the way toward its target...
local PUSH_TIME = 8 -- ...over this many seconds
local HIDDEN_LAYERS = { "HUD", "Prompts" }
local DOF = { FarIntensity = 0.25, NearIntensity = 0, InFocusRadius = 30 }

local localPlayer = Players.LocalPlayer
local current = nil -- { id, data, token, saved, connections, skippable, holdStart, shotTween }
local tokens = 0
local skipHint, skipFill, skipLabel, dof

local function focus(pos: Vector3, look: Vector3)
	if dof then
		dof.FocusDistance = math.clamp((look - pos).Magnitude, 0, 200)
	end
end

----------------------------------------------------------------------------------------------------------------
-- Skip hint (bottom right, over the letterbox)
----------------------------------------------------------------------------------------------------------------
local function buildSkipHint()
	local layer = UIController.getLayer("Letterbox")
	skipHint = Components.slab(layer, { color = UIStyle.PanelSolid.Color, transparency = 0.2, slant = 10 }, {
		Name = "SkipHint", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -28), Size = UDim2.fromOffset(250, 40), Visible = false,
	})
	skipHint.Active = true
	skipFill = Components.slab(skipHint, { color = UIStyle.Accent, transparency = 0.15, slant = false }, {
		Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(0, 0, 0, 3), ZIndex = 3,
	})
	skipLabel = Components.label(skipHint, "", { font = "Header", size = 13, color = UIStyle.TextPrimary }, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
	})
	-- Touch: press and hold the hint itself (docs/11 §1 "Hold the SKIP button 1.0 s").
	skipHint.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.press("Skip", true)
		end
	end)
	skipHint.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.press("Skip", false)
		end
	end)
end

local function showSkip(on: boolean)
	skipHint.Visible = on
	skipFill.Size = UDim2.new(0, 0, 0, 3)
	if on then
		skipLabel.Text = ("HOLD  [%s]  TO SKIP"):format(InputController.glyph("Skip"))
	end
end

----------------------------------------------------------------------------------------------------------------
-- Restore
----------------------------------------------------------------------------------------------------------------
local function save()
	local camera = workspace.CurrentCamera
	local layers = {}
	for _, name in ipairs(HIDDEN_LAYERS) do
		local layer = UIController.getLayer(name)
		layers[name] = layer.Enabled
	end
	local waypoints = localPlayer.PlayerGui:FindFirstChild("PG_Waypoints")
	return {
		cameraType = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView,
		mouse = UserInputService.MouseBehavior, layers = layers, waypoints = waypoints and waypoints.Enabled,
	}
end

local function step(name, fn)
	local ok, message = pcall(fn)
	if not ok then
		Log.warn(TAG, "restore %s failed: %s", name, tostring(message))
	end
end

-- Ends the cinematic on this client and puts everything back. send = "done" | "skip" | nil (the server stopped it).
function CinematicController.finish(id: string?, send: string?)
	local playing = current
	if not playing or (id and playing.id ~= id) then
		return
	end
	current = nil
	tokens += 1
	for _, connection in ipairs(playing.connections) do
		connection:Disconnect()
	end
	local saved = playing.saved
	step("camera", function()
		-- Piloting: the Frame camera takes the view back on its next frame.
		CameraController.suspend(false)
		if CameraController.getState().following then
			return
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = humanoid or saved.subject
		camera.FieldOfView = saved.fov
	end)
	step("mouse", function()
		UserInputService.MouseBehavior = saved.mouse
	end)
	step("layers", function()
		for name, enabled in pairs(saved.layers) do
			UIController.getLayer(name).Enabled = enabled
		end
		local waypoints = localPlayer.PlayerGui:FindFirstChild("PG_Waypoints")
		if waypoints and saved.waypoints ~= nil then
			waypoints.Enabled = saved.waypoints
		end
	end)
	step("letterbox", function()
		DialogueController.letterbox("cinematic", false)
	end)
	step("dof", function()
		dof.Enabled = false
	end)
	step("skip", function()
		showSkip(false)
	end)
	step("input", function()
		InputController.hold(nil)
		if InputController.getContext() == "Cinematic" then
			InputController.restoreGameplay()
		end
	end)
	if send == "done" then
		Net.fireServer("Cinematic_Done", { cinematicId = playing.id })
	elseif send == "skip" then
		Net.fireServer("Cinematic_Skip", { cinematicId = playing.id })
	end
end

----------------------------------------------------------------------------------------------------------------
-- Shots
----------------------------------------------------------------------------------------------------------------
local function fovs(value, fallback): (number, number)
	if type(value) == "table" then
		return value[1], value[2] or value[1]
	end
	return value or fallback, value or fallback
end

-- The cinematic's own camera shake (the Frame camera's is suspended): a fading noise rotation.
local function jolt(): CFrame
	local entry = current and current.shake
	if not entry then
		return CFrame.identity
	end
	local age = (os.clock() - entry.start) / entry.duration
	if age < 0 then
		return CFrame.identity
	elseif age >= 1 then
		current.shake = nil
		return CFrame.identity
	end
	local swing = math.rad(3) * entry.magnitude * (1 - age) * (SettingsController.get("cameraShake") or 1)
	local n = os.clock() * 18
	return CFrame.Angles(math.noise(n, 1.5) * swing, math.noise(n, 7.5) * swing, math.noise(n, 13.5) * swing * 0.5)
end

-- Plays one shot; yields for its length. Returns false if the cinematic ended meanwhile.
local function playShot(shot, mine): boolean
	local camera = workspace.CurrentCamera
	local fromPos, fromLook
	if shot.hold then
		task.wait(shot.seconds or 0)
		return current ~= nil and current.token == mine
	elseif shot.dynamic == "overShoulder" then
		fromPos, fromLook = Shots.overShoulder(current.params)
	elseif shot.cam then
		fromPos, fromLook = Shots.camPoint(shot.cam)
	elseif shot.from then
		fromPos, fromLook = Shots.vec(shot.from[1]), Shots.vec(shot.from[2])
	end
	if not fromPos then
		task.wait(shot.seconds or 0)
		return current ~= nil and current.token == mine
	end
	local toPos = if shot.to and shot.to.pos then Shots.vec(shot.to.pos) else fromPos
	local toLook = if shot.to and shot.to.look then Shots.vec(shot.to.look) else fromLook
	local fov0, fov1 = fovs(shot.fov, 70)
	local seconds = math.max(shot.seconds or 0, 0.01)
	local started = os.clock()
	while current and current.token == mine do
		local t = math.clamp((os.clock() - started) / seconds, 0, 1)
		local e = Easing.apply(shot.easing or "SineInOut", t)
		local pos, look = fromPos:Lerp(toPos, e), fromLook:Lerp(toLook, e)
		if shot.dynamic == "overShoulder" then
			-- It keeps the Titan's head in frame as it turns, pushing in a little.
			local _, liveLook = Shots.overShoulder(current.params)
			look = liveLook or look
			pos = fromPos:Lerp(look, 0.08 * e)
		end
		camera.CFrame = CFrame.lookAt(pos, look) * jolt()
		camera.FieldOfView = fov0 + (fov1 - fov0) * e
		focus(pos, look)
		if t >= 1 then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

-- A dialogue-driven cut: straight to the cam point, then a slow push toward its target.
local function cut(camId: string, mine)
	local pos, look = Shots.camPoint(camId)
	if not pos then
		return
	end
	current.cut = (current.cut or 0) + 1
	local cutToken = current.cut
	local camera = workspace.CurrentCamera
	local started = os.clock()
	task.spawn(function()
		while current and current.token == mine and current.cut == cutToken do
			local t = math.clamp((os.clock() - started) / PUSH_TIME, 0, 1)
			local p = pos:Lerp(look, PUSH_IN * Easing.apply("SineOut", t))
			camera.CFrame = CFrame.lookAt(p, look)
			focus(p, look)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- The first boarding's close-up (CIN_HATCH_TAP): Elias turns to the hatch; the camera beside him, at his
-- shoulder's height, drifts in toward his hand and the hatch.
local function hatchShot(mine, frame)
	local from, to, look = Shots.hatch(frame)
	if not from then
		return
	end
	local camera = workspace.CurrentCamera
	camera.FieldOfView = 50
	local started = os.clock()
	task.spawn(function()
		while current and current.token == mine do
			local t = math.clamp((os.clock() - started) / 2.2, 0, 1)
			local p = from:Lerp(to, Easing.apply("SineInOut", t))
			camera.CFrame = CFrame.lookAt(p, look)
			focus(p, look)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- A cued beat (S31): cut to it, move over `seconds` if it has a `to`, then hold or keep tracking until the next.
--   dynamic "track"    from the cam point's position, following the Titan's head
--   dynamic "reverse"  from behind the Titan's head toward the player's Frame
--   dynamic "overShoulder"  over the player's Frame toward the Titan
local function runCue(name: string, mine)
	local data = current and current.data
	local shot = data and data.cues and data.cues[name]
	if not shot then
		Log.warn(TAG, "%s: no cue %s", tostring(current and current.id), tostring(name))
		return
	end
	current.cue = (current.cue or 0) + 1
	local cueToken = current.cue
	local params = current.params
	local camera = workspace.CurrentCamera
	local fromPos, fromLook
	if shot.cam then
		fromPos, fromLook = Shots.camPoint(shot.cam)
	end
	local toPos = if shot.to and shot.to.pos then Shots.vec(shot.to.pos) else fromPos
	local toLook = if shot.to and shot.to.look then Shots.vec(shot.to.look) else fromLook
	local fov0, fov1 = fovs(shot.fov, 60)
	local started = os.clock()
	if shot.fx == "Static" then
		task.delay(shot.fxAt or 0, function()
			if current and current.cue == cueToken then
				Shots.staticFlash(UIController.getLayer("Letterbox"), 0.2)
			end
		end)
	end
	task.spawn(function()
		while current and current.token == mine and current.cue == cueToken do
			local t = if shot.seconds then math.clamp((os.clock() - started) / shot.seconds, 0, 1) else 1
			local e = Easing.apply(shot.easing or "SineInOut", t)
			local pos, look
			if shot.dynamic == "track" then
				pos, look = fromPos, Shots.headOf(params.titan) or fromLook
			elseif shot.dynamic == "reverse" then
				pos, look = Shots.reverse(params)
			elseif shot.dynamic == "overShoulder" then
				pos, look = Shots.overShoulder(params)
			elseif fromPos then
				pos, look = fromPos:Lerp(toPos, e), fromLook:Lerp(toLook, e)
			end
			if pos and look then
				camera.CFrame = CFrame.lookAt(pos, look) * jolt()
				focus(pos, look)
			end
			camera.FieldOfView = fov0 + (fov1 - fov0) * e
			RunService.RenderStepped:Wait()
		end
	end)
end

function CinematicController.cue(id: string, name: string)
	if current and current.id == id then
		runCue(name, current.token)
	end
end

function CinematicController.play(id: string, params)
	params = params or {}
	local data = Cinematics[id]
	if not data then
		Log.warn(TAG, "unknown cinematic %s", tostring(id))
		Net.fireServer("Cinematic_Done", { cinematicId = id })
		return
	end
	if current then
		CinematicController.finish(nil, "done")
	end
	tokens += 1
	local mine = tokens
	current = { id = id, data = data, token = mine, saved = save(), connections = {}, skippable = params.skippable == true, params = params }

	local camera = workspace.CurrentCamera
	CameraController.suspend(true)
	camera.CameraType = Enum.CameraType.Scriptable
	InputController.hold("Cinematic")
	for _, name in ipairs(HIDDEN_LAYERS) do
		UIController.getLayer(name).Enabled = false
	end
	local waypoints = localPlayer.PlayerGui:FindFirstChild("PG_Waypoints")
	if waypoints then
		waypoints.Enabled = false
	end
	if data.letterbox then
		DialogueController.letterbox("cinematic", true)
	end
	for key, value in pairs(DOF) do
		dof[key] = value
	end
	dof.Enabled = true
	showSkip(current.skippable)
	if data.dynamic == "hatch" then
		hatchShot(mine, params.frame)
	end
	if data.gesture == "TapHatch" then
		local connection = Shots.tapHatch(function()
			return current ~= nil and current.token == mine
		end)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	-- Effects on this client at their time: the S28 roar (the Titan's glow and blast, and this camera's shake).
	for _, event in ipairs(data.clientEvents or {}) do
		task.delay(event.at, function()
			if not current or current.token ~= mine then
				return
			end
			if event.fx == "TitanRoar" then
				local ok, TitanVFX = pcall(require, script.Parent.TitanVFXController)
				if ok and typeof(params.titan) == "Instance" then
					TitanVFX.introRoar(params.titan)
				end
				current.shake = { magnitude = event.shake or 0.6, duration = event.duration or 1.2, start = os.clock() + 0.45 }
			end
		end)
	end

	-- Interruptions: the character dying or being replaced ends it (and tells the server).
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(current.connections, humanoid.Died:Connect(function()
			CinematicController.finish(id, "done")
		end))
	end
	table.insert(current.connections, localPlayer.CharacterAdded:Connect(function()
		CinematicController.finish(id, "done")
	end))
	-- Skip: hold for SKIP_HOLD seconds.
	if current.skippable then
		table.insert(current.connections, InputController.ActionPressed:Connect(function(action, began)
			if action == "Skip" and current and current.token == mine then
				current.holdStart = if began then os.clock() else nil
			end
		end))
		table.insert(current.connections, RunService.RenderStepped:Connect(function()
			if not current or current.token ~= mine then
				return
			end
			local held = if current.holdStart then os.clock() - current.holdStart else 0
			skipFill.Size = UDim2.new(math.clamp(held / SKIP_HOLD, 0, 1), -20, 0, 3)
			if held >= SKIP_HOLD then
				CinematicController.finish(id, "skip")
			end
		end))
	end

	if data.cues then
		camera.FieldOfView = data.fov or 60
		runCue(data.start, mine)
		return
	end
	if data.dialogueDriven then
		camera.FieldOfView = data.fov or 70
		if data.screen then
			BriefingScreen.reset()
		end
		table.insert(current.connections, DialogueController.Node:Connect(function(_, _, node)
			local action = node.action
			if type(action) ~= "table" or not current or current.token ~= mine then
				return
			end
			if action.cam then
				cut(action.cam, mine)
			end
			if action.slide and data.screen then
				BriefingScreen.show(action.slide)
			end
		end))
		if data.start then
			cut(data.start, mine)
		end
		return
	end
	task.spawn(function()
		local ok, message = pcall(function()
			for _, shot in ipairs(data.shots or {}) do
				if not playShot(shot, mine) then
					return
				end
			end
		end)
		if not ok then
			Log.warn(TAG, "%s failed: %s", id, tostring(message))
		end
		if current and current.token == mine then
			CinematicController.finish(id, "done")
		end
	end)
end

function CinematicController.isPlaying(): string?
	return current and current.id or nil
end

function CinematicController.Init()
	buildSkipHint()
	dof = game:GetService("Lighting"):FindFirstChild("PG_CinematicDOF") or Instance.new("DepthOfFieldEffect")
	dof.Name = "PG_CinematicDOF"
	dof.Enabled = false
	dof.Parent = game:GetService("Lighting")
end

function CinematicController.Start()
	Net.on("Cinematic_Play", function(payload)
		if type(payload) ~= "table" or type(payload.cinematicId) ~= "string" then
			return
		end
		local params = payload.params or {}
		if params.stop then
			CinematicController.finish(payload.cinematicId, nil)
		elseif params.cue then
			CinematicController.cue(payload.cinematicId, params.cue)
		else
			CinematicController.play(payload.cinematicId, params)
		end
	end)
end

return CinematicController
