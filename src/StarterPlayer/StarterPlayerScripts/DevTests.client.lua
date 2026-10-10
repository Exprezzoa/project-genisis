--!strict
-- StarterPlayerScripts/DevTests.client.lua  (docs/19_testing_and_debug.md §1)
--
-- Client half of the Studio-only test bridge (see ServerScriptService.DevTests). It exposes the running
-- controllers to test snippets, which live in a different script context:
--
--   local bridge = game.Players.LocalPlayer.PlayerScripts.DevBridge      -- a BindableFunction
--   bridge:Invoke("call", "LightingController", "getCurrent")            -- -> ok, results...
--   bridge:Invoke("get", "HUDController", "someField")
--
-- It does nothing outside Studio, and nothing unless the server's DevTests script is active
-- (ReplicatedStorage attribute "DevTests").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
if not player:GetAttribute("ClientReady") then
	player:GetAttributeChangedSignal("ClientReady"):Wait()
end
if ReplicatedStorage:GetAttribute("DevTests") ~= true then
	return
end

local controllers: { [string]: any } = {}
for _, moduleScript in ipairs(script.Parent:WaitForChild("Client"):WaitForChild("Controllers"):GetChildren()) do
	if moduleScript:IsA("ModuleScript") then
		controllers[moduleScript.Name] = require(moduleScript)
	end
end

local bridge = Instance.new("BindableFunction")
bridge.Name = "DevBridge"
bridge.OnInvoke = function(command: string, controllerName: string, key: string, ...: any): ...any
	local controller = controllers[controllerName]
	if not controller then
		error("DevBridge: unknown controller " .. tostring(controllerName))
	end
	if command == "get" then
		return controller[key]
	elseif command == "call" then
		local fn = controller[key]
		if type(fn) ~= "function" then
			error(("DevBridge: %s.%s isn't a function"):format(tostring(controllerName), tostring(key)))
		end
		return pcall(fn, ...)
	end
	error("DevBridge: unknown command " .. tostring(command))
end
bridge.Parent = script.Parent
