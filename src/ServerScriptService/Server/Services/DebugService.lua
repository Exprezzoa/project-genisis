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

local CollectionService = game:GetService("CollectionService")

local CharacterService = require(script.Parent.CharacterService)
local FrameService = require(script.Parent.FrameService)
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
	local spawnCFrame = CharacterService.getSpawnCFrame(spawnId)
	if not spawnCFrame then
		return "unknown spawn " .. spawnId
	end
	local frame = FrameService.getPiloted(player)
	if frame then
		FrameService.moveTo(frame, spawnCFrame)
		return "Frame moved to " .. spawnId
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

-- /frame: Unit 02 comes to where the player stands and the player boards it.
function handlers.frame(player)
	if FrameService.getPiloted(player) then
		return "already piloting"
	end
	local frame = FrameService.getFrame("02")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (frame and root) then
		return "no Unit 02 or no character"
	end
	if frame:GetAttribute("Pilot") ~= 0 then
		return "Unit 02 is occupied"
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local position = Vector3.new(root.Position.X, 0, root.Position.Z)
	FrameService.moveTo(frame, CFrame.lookAt(position, position + (if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis)))
	task.spawn(FrameService.board, player, frame, true)
	return "boarding Unit 02"
end

local function toggle(player, attribute, label)
	local frame = FrameService.getPiloted(player)
	if not frame then
		return "board a Frame first"
	end
	local on = not frame:GetAttribute(attribute)
	frame:SetAttribute(attribute, on)
	return label .. (if on then " on" else " off")
end

function handlers.god(player)
	return toggle(player, "God", "invulnerability")
end

function handlers.energy(player)
	return toggle(player, "InfiniteEnergy", "infinite energy")
end

local hurtboxesShown = false

function handlers.hurtboxes()
	hurtboxesShown = not hurtboxesShown
	local count = 0
	for _, part in ipairs(CollectionService:GetTagged("Hurtbox")) do
		if part:IsA("BasePart") then
			count += 1
			part.Transparency = if hurtboxesShown then 0.6 else 1
			part.Color = (Debug.ZoneColors :: any)[part:GetAttribute("Zone")] or Debug.ZoneColors.Body
			part.Material = Enum.Material.ForceField
		end
	end
	return ("%d hurtboxes %s"):format(count, if hurtboxesShown then "shown" else "hidden")
end

-- Opens or closes a door stand-in: open = it lets everything through and turns nearly invisible.
local function setDoor(doorId: string, open: boolean): boolean
	local found = false
	for _, part in ipairs(CollectionService:GetTagged("Door")) do
		if part:IsA("BasePart") and part:GetAttribute("DoorId") == doorId then
			found = true
			part.CanCollide = not open
			part.CanQuery = not open
			part.Transparency = if open then 0.9 else 0
			part:SetAttribute("Open", open)
		end
	end
	return found
end

function handlers.door(_, args)
	local doorId = (Debug.Doors :: any)[string.lower(args[1] or "")]
	if not doorId then
		return "usage: " .. Debug.Commands.door.usage
	end
	local open = string.lower(args[2] or "open") ~= "close"
	if not setDoor(doorId, open) then
		return doorId .. " isn't in the map"
	end
	return doorId .. (if open then " open" else " closed")
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
	-- Phase 2 has no door system yet: in Studio the Training door starts open so a Frame can walk to the yard
	-- (D-054). The deployment door stays shut.
	setDoor(Debug.Doors.west, true)
	Net.on("Debug_Command", function(player: Player, payload: { cmd: string, args: { string } })
		local message = DebugService.run(player, payload.cmd, payload.args)
		Log.debug(TAG, "/%s %s -> %s", payload.cmd, table.concat(payload.args, " "), message)
		Net.fireClient(player, "UI_Toast", { text = message })
	end)
end

return DebugService
