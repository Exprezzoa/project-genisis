--!strict
-- Client/Main.client.lua  (docs/16_technical_architecture.md §3)
--
-- Client bootstrap: waits for the server's "ServerReady" attribute, loads every controller in a fixed order
-- (Init all, then Start all), then sends Client_Ready. A failing controller stops the boot with an error
-- that names it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared:WaitForChild("Modules"):WaitForChild("Loader"))
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local TAG = "Main"

-- Input and settings first, then the UI root, then everything that draws into it; debug last.
-- Controllers of later phases are skipped until their module exists.
local ORDER = {
	"InputController",
	"SettingsController",
	"UIController",
	"LightingController",
	"AudioController",
	"CameraController",
	"CharacterController",
	"HUDController",
	"CardController",
	"InteractionController",
	"WaypointController",
	"MobileControlsController",
	"MenuController",
	"MissionLogController",
	"DialogueController",
	"CinematicController",
	"ConversationCameraController",
	"TutorialController",
	"BarkController",
	"AnimationController",
	"NPCAnimator",
	"FrameController",
	"ShifterController",
	"CombatController",
	"FrameHUDController",
	"VFXController",
	"LockOnController",
	"TitanHUDController",
	"TitanVFXController",
	"FrameDamageController",
	"AmbientController",
	"DebugController",
}

if not ReplicatedStorage:GetAttribute("ServerReady") then
	ReplicatedStorage:GetAttributeChangedSignal("ServerReady"):Wait()
end

local startClock = os.clock()

Net.init()
local loaded = Loader.run(TAG, script.Parent:WaitForChild("Controllers"), ORDER)

Net.fireServer("Client_Ready")
Log.debug(TAG, "Client ready: %d controllers in %d ms (%s)", #loaded, (os.clock() - startClock) * 1000, table.concat(loaded, ", "))
