--!strict
-- Client/Controllers/CharacterController.lua  (docs/11_controls_and_camera.md §1, §3)
--
-- On-foot character on the client: sprint (hold, or toggle by setting / L3 / touch), the control lock
-- (movement off while the server locks controls or a menu, dialogue or cinematic context is active, always
-- restored), and the on-foot camera FOV.
--
--   isSprinting() -> boolean      isControlLocked() -> boolean

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared.Config.Bindings)
local GameConfig = require(Shared.Config.GameConfig)

local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)

local Config = GameConfig.Character

local CharacterController = {}

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local sprinting = false
local locked = false
local controls: any = nil

local function applySpeed()
	if humanoid then
		humanoid.WalkSpeed = if sprinting and not locked then Config.SPRINT_SPEED else Config.WALK_SPEED
	end
end

local function getControls(): any
	if not controls then
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		if playerModule then
			controls = (require(playerModule) :: any):GetControls()
		end
	end
	return controls
end

local function refreshLock()
	local shouldLock = player:GetAttribute("ControlLocked") == true or not InputController.isGameplay()
	if shouldLock == locked then
		return
	end
	locked = shouldLock
	local playerControls = getControls()
	if playerControls then
		if locked then
			playerControls:Disable()
		else
			playerControls:Enable()
		end
	end
	if locked then
		sprinting = false
	end
	applySpeed()
end

function CharacterController.isSprinting(): boolean
	return sprinting
end

function CharacterController.isControlLocked(): boolean
	return locked
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	sprinting = false
	applySpeed()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Config.CAMERA_FOV
	end
end

function CharacterController.Start()
	InputController.ActionPressed:Connect(function(action: string, began: boolean, input: InputObject?)
		if action ~= "Sprint" or locked then
			return
		end
		-- Touch buttons (no input object), L3 and the "toggle" setting toggle; otherwise sprint while held.
		local toggles = input == nil or (Bindings.ToggleInputs :: any)[input.KeyCode] == true or SettingsController.get("sprintToggle")
		if toggles then
			if began then
				sprinting = not sprinting
			end
		else
			sprinting = began
		end
		applySpeed()
	end)
	InputController.ContextChanged:Connect(refreshLock)
	player:GetAttributeChangedSignal("ControlLocked"):Connect(refreshLock)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	refreshLock()
end

return CharacterController
