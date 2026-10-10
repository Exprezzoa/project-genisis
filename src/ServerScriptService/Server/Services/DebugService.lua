--!strict
-- Server/Services/DebugService.lua  (docs/19_testing_and_debug.md §2)
--
-- Studio-only debug commands, received as Debug_Command {cmd, args}. Outside Studio nothing is registered
-- and Net drops the remote. Every command answers with a toast and a log line.
--
--   run(player, cmd, args) -> message      -- also callable from tests

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debug = require(Shared.Config.Debug)
local LightingPresets = require(Shared.Config.LightingPresets)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local CharacterService = require(script.Parent.CharacterService)
local FlagService = require(script.Parent.FlagService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TAG = "DebugService"

local DebugService = {}

local handlers: { [string]: (player: Player, args: { string }) -> string } = {}

function handlers.tp(player, args)
	local spawnId = args[1]
	if not spawnId then
		return "usage: " .. Debug.Commands.tp.usage
	end
	if not CharacterService.getSpawnCFrame(spawnId) then
		return "unknown spawn " .. spawnId
	end
	CharacterService.teleport(player, spawnId)
	return "teleported to " .. spawnId
end

function handlers.zone(player, args)
	local spawnId = (Debug.ZoneSpawns :: any)[string.lower(args[1] or "")]
	if not spawnId then
		return "usage: " .. Debug.Commands.zone.usage
	end
	if not CharacterService.getSpawnCFrame(spawnId) then
		return ("zone %s isn't built yet (%s is missing)"):format(args[1], spawnId)
	end
	CharacterService.teleport(player, spawnId)
	return ("teleported to %s (%s)"):format(args[1], spawnId)
end

function handlers.flags(player)
	local profile = PlayerDataService.getProfile(player)
	if not profile then
		return "no profile"
	end
	local flags = FlagService.getAll(player)
	local relationships = {}
	for name, value in pairs(profile.relationships) do
		table.insert(relationships, name .. "=" .. value)
	end
	table.sort(relationships)
	local text = ("%d flags: %s | relationships: %s"):format(#flags, table.concat(flags, ", "), table.concat(relationships, ", "))
	Log.info(TAG, "%s", text)
	return text
end

function handlers.flag(player, args)
	local name, mode = args[1], string.lower(args[2] or "on")
	if not name or (mode ~= "on" and mode ~= "off") then
		return "usage: " .. Debug.Commands.flag.usage
	end
	local ok, changed = pcall(if mode == "on" then FlagService.set else FlagService.clear, player, name)
	if not ok then
		return "invalid flag name " .. name
	end
	return ("flag %s %s%s"):format(name, mode, if changed then "" else " (no change)")
end

function handlers.save(player)
	PlayerDataService.update(player, function() end) -- mark dirty so the save writes
	return if PlayerDataService.saveNow(player, "debug") then "saved" else "NOT saved (read-only, memory-only or failed)"
end

function handlers.wipe(player, args)
	if args[1] ~= "confirm" then
		return "this resets the whole profile; type /wipe confirm"
	end
	return if PlayerDataService.wipe(player) then "profile wiped and saved" else "profile wiped in memory; NOT saved"
end

function handlers.dsfail(_, args)
	local mode = string.lower(args[1] or "")
	if mode ~= "on" and mode ~= "off" then
		return "usage: " .. Debug.Commands.dsfail.usage
	end
	PlayerDataService.setSimulateFailure(mode == "on")
	return "simulated DataStore failures " .. mode
end

function handlers.lighting(player, args)
	local preset = string.upper(args[1] or "")
	if (LightingPresets.presets :: any)[preset] == nil then
		return "usage: " .. Debug.Commands.lighting.usage
	end
	Net.fireClient(player, "Lighting_Set", { preset = preset, instant = false })
	return "lighting " .. preset
end

function DebugService.run(player: Player, cmd: string, args: { string }): string
	local name = string.lower(cmd)
	local command = (Debug.Commands :: any)[name]
	if not command or command.side ~= "server" then
		return "unknown command /" .. cmd
	end
	if command.phase > Debug.CURRENT_PHASE then
		return ("/%s is not available until Phase %d"):format(name, command.phase)
	end
	local ok, message = pcall(handlers[name], player, args)
	if not ok then
		Log.error(TAG, "/%s failed: %s", name, tostring(message))
		return "/" .. name .. " failed (see Output)"
	end
	return message
end

function DebugService.Start()
	if not RunService:IsStudio() then
		return
	end
	Net.on("Debug_Command", function(player: Player, payload: { cmd: string, args: { string } })
		local message = DebugService.run(player, payload.cmd, payload.args)
		Log.debug(TAG, "/%s %s -> %s", payload.cmd, table.concat(payload.args, " "), message)
		Net.fireClient(player, "UI_Toast", { text = message })
	end)
end

return DebugService
