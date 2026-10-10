--!strict
-- Shared/Modules/Net  (docs/16_technical_architecture.md §5)
--
-- All networking goes through here. The server creates every RemoteEvent under ReplicatedStorage.Remotes
-- from Net.Definitions; clients wait for them (10 s, error if missing). RemoteEvents only.
--
--   Net.init()                              -- once per side, from Main, before anything else uses Net
--   Net.on("Settings_Update", handler)      -- server: handler(player, payload), rate-limited + validated + pcall
--   Net.on("UI_Toast", handler)             -- client: handler(payload)
--   Net.fireServer(name, payload) / Net.fireClient(player, name, payload) / Net.fireAllClients(name, payload)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Definitions = require(script.Definitions)
local Log = require(script.Parent.Log)
local RateLimiter = require(script.Parent.RateLimiter)

local TAG = "Net"
local FOLDER_NAME = "Remotes"
local CLIENT_WAIT = 10

local IS_SERVER = RunService:IsServer()
local IS_STUDIO = RunService:IsStudio()

local Net = {}

Net.Definitions = Definitions

local remotes: { [string]: RemoteEvent } = {}
local limiters: { RateLimiter.RateLimiter } = {}
local initialized = false

local function definitionFor(name: string, direction: string): Definitions.Definition
	local definition = Definitions[name]
	if not definition then
		error("Net: unknown remote " .. tostring(name), 3)
	end
	if definition.direction ~= direction then
		error(("Net: %s is %s, not %s"):format(name, definition.direction, direction), 3)
	end
	return definition
end

local function remoteFor(name: string): RemoteEvent
	local remote = remotes[name]
	if not remote then
		error(("Net: remote %s isn't available (was Net.init called?)"):format(name), 3)
	end
	return remote
end

function Net.init()
	if initialized then
		return
	end
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
		end
		for name in pairs(Definitions) do
			local remote = folder:FindFirstChild(name)
			if not remote then
				remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
			remotes[name] = remote :: RemoteEvent
		end
		folder.Parent = ReplicatedStorage
		Players.PlayerRemoving:Connect(function(player)
			for _, limiter in ipairs(limiters) do
				limiter:reset(player)
			end
		end)
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT)
		if not folder then
			error(("Net: ReplicatedStorage.%s didn't appear within %d s"):format(FOLDER_NAME, CLIENT_WAIT))
		end
		for name in pairs(Definitions) do
			local remote = folder:WaitForChild(name, CLIENT_WAIT)
			if not remote then
				error(("Net: remote %s didn't appear within %d s"):format(name, CLIENT_WAIT))
			end
			remotes[name] = remote :: RemoteEvent
		end
	end
	initialized = true
end

-- Wraps a C2S handler with the remote's rate limiter, payload validation and a pcall.
-- The returned function is what OnServerEvent calls; it returns (accepted, reason) for tests.
-- clock is injectable for tests.
function Net.wrap(name: string, handler: (player: Player, payload: any) -> (), clock: (() -> number)?)
	local definition = definitionFor(name, "C2S")
	local validate = definition.validate :: any
	local limiter = RateLimiter.new(definition.rate :: number, definition.burst :: number, clock)
	table.insert(limiters, limiter)

	return function(player: Player, payload: any, ...: any): (boolean, string?)
		if definition.studioOnly and not IS_STUDIO then
			return false, "studio only"
		end
		if not limiter:try(player) then
			Log.debug(TAG, "%s from %s dropped: rate limit", name, tostring(player))
			return false, "rate limit"
		end
		if select("#", ...) > 0 then
			Log.warn(TAG, "%s from %s rejected: extra arguments", name, tostring(player))
			return false, "extra arguments"
		end
		local valid, reason = validate(payload)
		if not valid then
			Log.warn(TAG, "%s from %s rejected: %s", name, tostring(player), tostring(reason))
			return false, reason
		end
		local ok, message = pcall(handler, player, payload)
		if not ok then
			Log.error(TAG, "%s handler failed: %s", name, tostring(message))
			return false, "handler error"
		end
		return true
	end
end

-- Server: listens to a C2S remote (wrapped). Client: listens to an S2C remote.
function Net.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	if IS_SERVER then
		local wrapped = Net.wrap(name, handler)
		return remoteFor(name).OnServerEvent:Connect(wrapped)
	end
	definitionFor(name, "S2C")
	return remoteFor(name).OnClientEvent:Connect(handler)
end

function Net.fireServer(name: string, payload: { [string]: any }?)
	definitionFor(name, "C2S")
	remoteFor(name):FireServer(payload or {})
end

function Net.fireClient(player: Player, name: string, payload: { [string]: any }?)
	definitionFor(name, "S2C")
	remoteFor(name):FireClient(player, payload or {})
end

function Net.fireAllClients(name: string, payload: { [string]: any }?)
	definitionFor(name, "S2C")
	remoteFor(name):FireAllClients(payload or {})
end

return Net
