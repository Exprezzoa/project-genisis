--!strict
-- Server/Services/CharacterService.lua  (docs/16 §4, docs/08_rigs_and_animation.md §1.1)
--
-- Spawns the player's character once the profile is loaded, respawns it at the last spawn point when it is
-- lost (fall, reset), teleports to spawn points and holds the on-foot character settings.
-- Spawn points are parts tagged "SpawnPoint" with a SpawnId attribute; their CFrame is on the floor, facing -Z.
--
--   teleport(player, spawnId) -> boolean      setControlLocked(player, locked)
--   spawn(player, spawnId)                     getSpawnCFrame(spawnId) -> CFrame?
--   Spawned(player, character, spawnId)
--
-- Control lock reaches the client as the player attribute "ControlLocked".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local CollisionService = require(script.Parent.CollisionService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TAG = "CharacterService"
local SPAWN_TAG = "SpawnPoint"
local Config = GameConfig.Character

local CharacterService = {}

CharacterService.Spawned = Signal.new() :: Signal.Signal<Player, Model, string>

local spawns: { [string]: BasePart } = {}
local lastSpawn: { [Player]: string } = {}
local spawning: { [Player]: boolean } = {}

local function registerSpawn(instance: Instance)
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end
	local id = instance:GetAttribute("SpawnId")
	if type(id) ~= "string" or id == "" then
		Log.error(TAG, "%s is tagged SpawnPoint but has no SpawnId", instance:GetFullName())
		return
	end
	if spawns[id] and spawns[id] ~= instance then
		Log.error(TAG, "duplicate SpawnId %s (%s)", id, instance:GetFullName())
		return
	end
	spawns[id] = instance
end

local function unregisterSpawn(instance: Instance)
	for id, part in pairs(spawns) do
		if part == instance then
			spawns[id] = nil
		end
	end
end

-- Puts the character on the spawn point: feet on the floor, facing the spawn's -Z, standing still.
local function place(character: Model, spawnCFrame: CFrame)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	character:PivotTo(spawnCFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function onCharacterAdded(player: Player, character: Model)
	CollisionService.assignModel(character, "Players")
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		Log.error(TAG, "the character of %s has no Humanoid", player.Name)
		return
	end
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.JUMP_HEIGHT

	-- Lost character (died, fell out of the world, reset): respawn at the last spawn point.
	local function lost()
		if spawning[player] or player.Parent == nil or player.Character ~= character then
			return
		end
		spawning[player] = true
		task.delay(Config.RESPAWN_DELAY, function()
			spawning[player] = nil
			if player.Parent ~= nil then
				CharacterService.spawn(player, lastSpawn[player] or GameConfig.Data.DEFAULT_SPAWN)
			end
		end)
	end
	humanoid.Died:Connect(lost)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			lost()
		end
	end)
end

function CharacterService.getSpawnCFrame(spawnId: string): CFrame?
	local part = spawns[spawnId]
	return if part then part.CFrame else nil
end

-- Loads a fresh character and puts it on the spawn point. Yields until the character exists.
function CharacterService.spawn(player: Player, spawnId: string)
	local spawnCFrame = CharacterService.getSpawnCFrame(spawnId)
	if not spawnCFrame then
		Log.error(TAG, "unknown spawn %s; %s spawns at the engine default", tostring(spawnId), player.Name)
	else
		lastSpawn[player] = spawnId
	end
	player:LoadCharacter()
	local character = player.Character
	if not character then
		return
	end
	if spawnCFrame then
		place(character, spawnCFrame)
	end
	CharacterService.Spawned:Fire(player, character, spawnId)
end

-- Moves the existing character to a spawn point, which also becomes the respawn point.
function CharacterService.teleport(player: Player, spawnId: string): boolean
	local spawnCFrame = CharacterService.getSpawnCFrame(spawnId)
	local character = player.Character
	if not spawnCFrame or not character then
		Log.error(TAG, "can't teleport %s to %s (unknown spawn or no character)", player.Name, tostring(spawnId))
		return false
	end
	lastSpawn[player] = spawnId
	place(character, spawnCFrame)
	return true
end

function CharacterService.setControlLocked(player: Player, locked: boolean)
	player:SetAttribute("ControlLocked", locked)
end

function CharacterService.Init()
	-- Characters are loaded by this service only, after the profile is ready.
	Players.CharacterAutoLoads = false
end

function CharacterService.Start()
	for _, instance in ipairs(CollectionService:GetTagged(SPAWN_TAG)) do
		registerSpawn(instance)
	end
	CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(registerSpawn)
	CollectionService:GetInstanceRemovedSignal(SPAWN_TAG):Connect(unregisterSpawn)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSpawn[player] = nil
		spawning[player] = nil
	end)

	local function firstSpawn(player: Player)
		if not spawning[player] and player.Character == nil then
			spawning[player] = true
			CharacterService.spawn(player, GameConfig.Data.DEFAULT_SPAWN)
			spawning[player] = nil
		end
	end
	PlayerDataService.Loaded:Connect(firstSpawn)
	-- Profiles that finished loading before this service started (memory-only mode loads instantly).
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.getProfile(player) then
			task.spawn(firstSpawn, player)
		end
	end
end

return CharacterService
