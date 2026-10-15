--!strict
-- Server/Main.server.lua  (docs/16_technical_architecture.md §3)
--
-- Server bootstrap: creates the remotes, loads every service in the fixed order (Init all, then Start all),
-- then sets ReplicatedStorage "ServerReady" and answers each client's Client_Ready with Server_Ready.
-- A failing service stops the boot with an error that names it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared.Modules.Loader)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local TAG = "Main"

-- docs/16 §3. Services of later phases are skipped until their module exists.
local ORDER = {
	"CollisionService",
	"PlayerDataService",
	"FlagService",
	"RelationshipService",
	"EvidenceService",
	"ProgressionService",
	"ZoneService",
	"TriggerService",
	"InteractionService",
	"CharacterService",
	"NPCService",
	"AmbientService",
	"FrameService",
	"AllyFrameService",
	"TitanService",
	"CombatService",
	"RetryService",
	"DialogueService",
	"CinematicService",
	"ShifterService",
	"SequenceService",
	"BoundsService",
	"DebugService",
}

local startClock = os.clock()

Net.init()
local loaded = Loader.run(TAG, script.Parent:WaitForChild("Services"), ORDER)

Net.on("Client_Ready", function(player: Player)
	-- Services that need to know when a client finished starting watch this attribute.
	player:SetAttribute("ClientReady", true)
	Net.fireClient(player, "Server_Ready")
end)

ReplicatedStorage:SetAttribute("ServerReady", true)
Log.debug(TAG, "Server ready: %d services in %d ms (%s)", #loaded, (os.clock() - startClock) * 1000, table.concat(loaded, ", "))
