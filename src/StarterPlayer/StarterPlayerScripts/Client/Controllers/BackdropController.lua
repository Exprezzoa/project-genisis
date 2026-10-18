--!nonstrict
-- Client/Controllers/BackdropController.lua  (docs/16 §3; map_00 §3.1)
--
-- The city backdrop's lights, on this client only (ambient visuals; nothing here decides gameplay):
--   * window strips (tag CityWindow) light by Rank to the hub preset's share
--     (MORNING 10%, EVENING 60%, NIGHT 85%; any other preset counts as MORNING); antenna blinkers (tag Blinker) flash
--     red at 0.8 Hz, each out of step by where it stands.
-- Split out of AmbientController (which stays under the ~600-line limit, CLAUDE.md §4) in Session 11.

local CollectionService = game:GetService("CollectionService")

local LightingController = require(script.Parent.LightingController)

local BackdropController = {}

---------------------------------------------------------------------------------------------------
-- The city backdrop (map_00 §3.1). Window strips (tag CityWindow, Rank in [0, 1), built shown at 0.35) show while
-- Rank is under the hub preset's share, else transparency 1: set when the share changes and as strips stream in or
-- are rebuilt. Blinkers (tag Blinker, red Neon) flash at BlinkHz (0.8): Neon half of each period, SmoothPlastic (same
-- red, unlit) the other half, all from one loop, each shifted by a phase hashed from its position.
---------------------------------------------------------------------------------------------------
local WINDOW_SHARE = { MORNING = 0.10, EVENING = 0.60, NIGHT = 0.85 }
local WINDOW_SHOWN = 0.35
local BLINK_HZ = 0.8

local function windowShare(hub)
	return WINDOW_SHARE[hub] or WINDOW_SHARE.MORNING
end

-- A strip without a numeric Rank is left as built.
local function setWindow(part, share)
	local rank = part:GetAttribute("Rank")
	if part:IsA("BasePart") and type(rank) == "number" then
		local value = if rank < share then WINDOW_SHOWN else 1
		if math.abs(part.Transparency - value) > 0.001 then
			part.Transparency = value
		end
	end
end

-- A phase in [0, 1) hashed from where the part stands: the same on every client, different for each antenna.
local function blinkPhase(part)
	local p = part.Position
	local h = math.sin(p.X * 12.9898 + p.Y * 4.1414 + p.Z * 78.233) * 43758.5453
	return h - math.floor(h)
end

local function startBackdrops()
	local share = windowShare(LightingController.getHub())
	local function applyWindows()
		for _, part in ipairs(CollectionService:GetTagged("CityWindow")) do
			setWindow(part, share)
		end
	end
	applyWindows()
	CollectionService:GetInstanceAddedSignal("CityWindow"):Connect(function(part)
		setWindow(part, share)
	end)

	local blinkers = {} -- [part] = { phase, hz, lit }
	local function addBlinker(part)
		if part:IsA("BasePart") and blinkers[part] == nil then
			local hz = part:GetAttribute("BlinkHz")
			if type(hz) ~= "number" or hz <= 0 then
				hz = BLINK_HZ
			end
			blinkers[part] = { phase = blinkPhase(part), hz = hz, lit = nil }
		end
	end
	for _, part in ipairs(CollectionService:GetTagged("Blinker")) do
		addBlinker(part)
	end
	CollectionService:GetInstanceAddedSignal("Blinker"):Connect(addBlinker)
	CollectionService:GetInstanceRemovedSignal("Blinker"):Connect(function(part)
		blinkers[part] = nil
	end)

	task.spawn(function()
		while true do
			local wanted = windowShare(LightingController.getHub())
			if wanted ~= share then
				share = wanted
				applyWindows()
			end
			if next(blinkers) == nil then
				task.wait(0.25) -- nothing to blink: only watch the preset
			else
				local now = os.clock()
				for part, b in pairs(blinkers) do
					if part.Parent then
						local lit = (now * b.hz + b.phase) % 1 < 0.5
						if lit ~= b.lit then
							b.lit = lit
							part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
						end
					else
						blinkers[part] = nil
					end
				end
				task.wait(0.05)
			end
		end
	end)
end

function BackdropController.Init() end

function BackdropController.Start()
	startBackdrops() -- by tag only: it needs no Map, and strips and blinkers stream in whenever
end

return BackdropController
