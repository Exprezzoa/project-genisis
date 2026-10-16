--!nonstrict
-- Server/Frames/FrameEnergy.lua  (docs/09 §4, docs/12 §3; split out of FrameService)
--
-- A Frame's energy (dodges and the special cost it): stored here, published as the attributes Energy and
-- EnergyMax. It comes back at its regen rate once regenDelay has passed since the last spend. The numbers come
-- from bind's lookup, so a pilot's upgrades count (ProgressionService's effective config, docs/12 §12).
--
--   bind(lookup)             lookup(frame) -> { max, regen, regenDelay }
--   track(frame)             start at full      forget(frame)
--   set(frame, value)        spend(frame, amount) -> boolean (false and nothing taken when there isn't enough)
--   step(dt)                 the regeneration (FrameService's Heartbeat)

local FrameEnergy = {}

local PUBLISH = 0.1 -- seconds between Energy attribute updates while it regenerates

local energy = {} -- [Model] = { value, lastSpend, published }
local lookup = nil

local function now()
	return workspace:GetServerTimeNow()
end

function FrameEnergy.bind(fn)
	lookup = fn
end

function FrameEnergy.track(frame)
	local config = lookup(frame)
	energy[frame] = { value = config.max, lastSpend = 0, published = now() }
	frame:SetAttribute("EnergyMax", config.max)
	frame:SetAttribute("Energy", config.max)
end

function FrameEnergy.forget(frame)
	energy[frame] = nil
end

function FrameEnergy.set(frame, value)
	local entry = energy[frame]
	if not entry then
		return
	end
	entry.value = math.clamp(value, 0, lookup(frame).max)
	entry.published = now()
	frame:SetAttribute("Energy", entry.value)
end

function FrameEnergy.spend(frame, amount)
	local entry = energy[frame]
	if amount <= 0 or frame:GetAttribute("InfiniteEnergy") then
		return true
	end
	if not entry or entry.value < amount then
		return false
	end
	entry.lastSpend = now()
	FrameEnergy.set(frame, entry.value - amount)
	return true
end

function FrameEnergy.step(dt)
	local t = now()
	for frame, entry in pairs(energy) do
		if not frame.Parent then
			energy[frame] = nil
			continue
		end
		local config = lookup(frame)
		if entry.value < config.max and t - entry.lastSpend >= config.regenDelay then
			entry.value = math.min(config.max, entry.value + config.regen * dt)
			if entry.value >= config.max or t - entry.published >= PUBLISH then
				entry.published = t
				frame:SetAttribute("Energy", entry.value)
			end
		end
	end
end

return FrameEnergy
