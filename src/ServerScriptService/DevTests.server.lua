--!strict
-- ServerScriptService/DevTests.server.lua  (docs/19_testing_and_debug.md §1)
--
-- Studio-only test bridge. Test snippets run through the MCP live in a different script context than the
-- game's modules, so they can't require the running services. This script exposes them instead:
--
--   local bridge = game.ServerStorage.DevBridge                      -- a BindableFunction, play mode only
--   bridge:Invoke("call", "ZoneService", "getZone", player)          -- -> ok, results... (pcall of the function)
--   bridge:Invoke("get", "CollisionService", "GROUPS")               -- -> the field
--   bridge:Invoke("log")                                             -- -> list of signal firings since the last call,
--                                                                    --    e.g. "TriggerService.Entered(Player1, TRG_X, foot)"
--
-- It does nothing outside Studio, and nothing unless ServerStorage.DevTools has the attribute RunTests = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end
local devTools = ServerStorage:FindFirstChild("DevTools")
if not devTools or devTools:GetAttribute("RunTests") ~= true then
	return
end

if not ReplicatedStorage:GetAttribute("ServerReady") then
	ReplicatedStorage:GetAttributeChangedSignal("ServerReady"):Wait()
end

local services: { [string]: any } = {}
local log: { string } = {}

local function watch(serviceName: string, signalName: string, signal: any)
	signal:Connect(function(...)
		local args = table.pack(...)
		local texts = table.create(args.n)
		for index = 1, args.n do
			texts[index] = tostring(args[index])
		end
		table.insert(log, ("%s.%s(%s)"):format(serviceName, signalName, table.concat(texts, ", ")))
	end)
end

for _, moduleScript in ipairs(script.Parent:WaitForChild("Server"):WaitForChild("Services"):GetChildren()) do
	if moduleScript:IsA("ModuleScript") then
		local service = require(moduleScript) :: any
		services[moduleScript.Name] = service
		for key, value in pairs(service) do
			if type(value) == "table" and type(value.Connect) == "function" and type(value.Fire) == "function" then
				watch(moduleScript.Name, key, value)
			end
		end
	end
end

local bridge = Instance.new("BindableFunction")
bridge.Name = "DevBridge"
bridge.OnInvoke = function(command: string, serviceName: string?, key: string?, ...: any): ...any
	if command == "log" then
		local entries = log
		log = {}
		return entries
	end
	local service = services[serviceName :: string]
	if not service then
		error("DevBridge: unknown service " .. tostring(serviceName))
	end
	if command == "get" then
		return service[key]
	elseif command == "call" then
		local fn = service[key]
		if type(fn) ~= "function" then
			error(("DevBridge: %s.%s isn't a function"):format(tostring(serviceName), tostring(key)))
		end
		return pcall(fn, ...)
	end
	error("DevBridge: unknown command " .. tostring(command))
end
bridge.Parent = ServerStorage
ReplicatedStorage:SetAttribute("DevTests", true) -- switches the client half on (StarterPlayerScripts.DevTests)
