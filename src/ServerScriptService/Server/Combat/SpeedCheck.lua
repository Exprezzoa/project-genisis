--!nonstrict
-- Server/Combat/SpeedCheck.lua  (docs/12 §10; split out of CombatService)
--
-- A piloted Frame that moves further than its state allows for too long is put back.
-- The check works on distance per interval, not on speed: the pilot's position updates reach the server in
-- bursts, so a dodge's 88 studs can show up inside one interval. While an action's root motion is (or was just)
-- running, the interval may hold that action's whole distance on top of normal movement (D-054).
--
--   allow(frame, distance, duration)   the action starting now may move the Frame this far more, for
--                                      duration seconds (plus slack: the pilot's updates arrive late)
--   start(getPiloted)                  the check loop; getPiloted(player) -> Model?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.CombatConfig)
local Log = require(Shared.Modules.Log)

local SpeedCheck = {}

local TAG = "CombatService"
local SLACK = 0.5 -- seconds a root-motion allowance outlasts its window
local MARGIN = 1.2 -- share of an action's distance the check lets through

local speed = {} -- [frame] = { player, position, time, valid, violations, movedAt }
local rootBudget = {} -- [frame] = { distance, expires }: extra studs the running action may move the Frame

local function now()
	return workspace:GetServerTimeNow()
end

function SpeedCheck.allow(frame, distance, duration)
	rootBudget[frame] = { distance = distance * MARGIN, expires = now() + duration + SLACK }
end

local function allowedDistance(frame, dt, t)
	local budget = rootBudget[frame]
	local extra = if budget and t <= budget.expires then budget.distance else 0
	return CombatConfig.SpeedCheck.normal * dt + extra
end

local function check(frame, player)
	local root = frame.PrimaryPart
	local t = now()
	local entry = speed[frame]
	local movedAt = frame:GetAttribute("MovedAt")
	-- A new pilot, or the server moved the Frame itself (FrameService.moveTo): start measuring afresh.
	if not entry or entry.player ~= player or entry.movedAt ~= movedAt then
		speed[frame] = { player = player, position = root.Position, time = t, valid = root.CFrame, violations = {}, movedAt = movedAt }
		return
	end
	local dt = t - entry.time
	local moved = (root.Position - entry.position) * Vector3.new(1, 0, 1)
	local over = moved.Magnitude > allowedDistance(frame, dt, t)
	entry.position, entry.time = root.Position, t
	local config = CombatConfig.SpeedCheck
	for index = #entry.violations, 1, -1 do
		if t - entry.violations[index].time > config.window then
			table.remove(entry.violations, index)
		end
	end
	if not over then
		entry.valid = root.CFrame
		return
	end
	table.insert(entry.violations, { time = t, length = dt })
	local total = 0
	for _, violation in ipairs(entry.violations) do
		total += violation.length
	end
	if total > config.violationTime then
		Log.warn(TAG, "%s moved Unit %s too fast for %.2f s; set back", player.Name, tostring(frame:GetAttribute("Unit")), total)
		frame:PivotTo(entry.valid)
		entry.position = entry.valid.Position
		table.clear(entry.violations)
	end
end

function SpeedCheck.start(getPiloted)
	task.spawn(function()
		while true do
			task.wait(CombatConfig.SpeedCheck.interval)
			for frame in pairs(speed) do
				if not frame.Parent then
					speed[frame] = nil
					rootBudget[frame] = nil
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local frame = getPiloted(player)
				if frame and frame.PrimaryPart and not frame.PrimaryPart.Anchored then
					check(frame, player)
				end
			end
		end
	end)
end

return SpeedCheck
