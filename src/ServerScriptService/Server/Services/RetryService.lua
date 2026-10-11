--!nonstrict
-- Server/Services/RetryService.lua  (docs/09_frames.md §5 "Disabled"; docs/14 "Frame Disabled")
--
-- What happens after a Frame is disabled, until the checkpoints of Phase 4 take this over: the pilot sees the
-- FRAME DISABLED card (the client shows it from the Frame's State), then the screen fades, the Titans go back
-- to how they spawned, the Frame is repaired and put back where it last stood clear of every Titan, and the
-- screen fades in. Nothing is lost or saved here.
--
--   getSafe(frame) -> CFrame?        the ground CFrame a retry would use
--   setOwner(fn)                     fn(frame) -> true when something else (the Sequence Runner) handles this one
--   Retried: Signal(frame)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FrameConfig = require(Shared.Config.FrameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local CombatService = require(script.Parent.CombatService)
local FrameService = require(script.Parent.FrameService)
local TitanService = require(script.Parent.TitanService)

local TAG = "RetryService"
local CARD_TIME = 2.5 -- docs/14: the FRAME DISABLED card
local SAMPLE = 0.5 -- seconds between looks for a safe place
local CLEAR_OF_TITANS = 260 -- studs: no living Titan this near and the Frame's place counts as safe

local RetryService = {}

RetryService.Retried = Signal.new()

local safe = {} -- [frame] = ground CFrame
local running = {} -- [frame] = true while a retry runs
local owner = nil

local function groundCFrame(frame)
	local root = frame.PrimaryPart
	local config = FrameConfig[frame:GetAttribute("Class")]
	local position = root.Position - Vector3.new(0, config.hipHeight + root.Size.Y / 2, 0)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return CFrame.lookAt(position, position + (if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis))
end

local function titansNear(position, range)
	local list = {}
	for _, titan in ipairs(TitanService.getTitans()) do
		local root = titan.PrimaryPart
		if root and titan:GetAttribute("State") ~= "Dead" and (root.Position - position).Magnitude <= range then
			table.insert(list, titan)
		end
	end
	return list
end

function RetryService.setOwner(fn)
	owner = fn
end

function RetryService.getSafe(frame)
	return safe[frame]
end

local function retry(frame)
	if running[frame] or (owner and owner(frame)) then
		return
	end
	running[frame] = true
	local player = Players:GetPlayerByUserId(frame:GetAttribute("Pilot") or 0)
	task.wait(CARD_TIME)
	if player then
		Net.fireClient(player, "Fade", { to = 1, duration = FrameConfig.Fade })
		task.wait(FrameConfig.Fade + 0.05)
	end
	if frame.Parent and frame.PrimaryPart then
		-- Every Titan that was in the fight starts over; then the Frame, away from them.
		local reset = 0
		for _, titan in ipairs(titansNear(frame.PrimaryPart.Position, CLEAR_OF_TITANS * 2)) do
			if TitanService.reset(titan) then
				reset += 1
			end
		end
		if safe[frame] then
			FrameService.moveTo(frame, safe[frame])
		end
		CombatService.repair(frame)
		Log.info(TAG, "Unit %s retried: %d Titans reset, Frame %s", tostring(frame:GetAttribute("Unit")), reset, if safe[frame] then "moved back" else "repaired in place")
		RetryService.Retried:Fire(frame)
	end
	if player then
		Net.fireClient(player, "Fade", { to = 0, duration = FrameConfig.Fade })
	end
	running[frame] = nil
end

function RetryService.Start()
	CombatService.FrameDisabled:Connect(function(frame)
		task.spawn(retry, frame)
	end)
	FrameService.Boarded:Connect(function(_, frame)
		safe[frame] = safe[frame] or groundCFrame(frame)
	end)
	-- The safe place: where the Frame last stood idle with no Titan anywhere near.
	task.spawn(function()
		while true do
			task.wait(SAMPLE)
			for _, player in ipairs(Players:GetPlayers()) do
				local frame = FrameService.getPiloted(player)
				local root = frame and frame.PrimaryPart
				if root and frame:GetAttribute("State") == "Idle" and not running[frame] and #titansNear(root.Position, CLEAR_OF_TITANS) == 0 then
					safe[frame] = groundCFrame(frame)
				end
			end
		end
	end)
end

return RetryService
