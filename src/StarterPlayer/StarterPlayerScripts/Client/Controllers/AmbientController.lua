--!nonstrict
-- Client/Controllers/AmbientController.lua  (docs/16 §3; docs/05 S02, S43; docs/07 §6 holograms)
--
-- Small things in the world that only look alive on this client:
--   * the Q-3 desk terminal's screen blinks "1 NEW MESSAGE" in amber while its part has the attribute NewMessage
--     (the server sets it in S43); the dressed terminal is "Q3_Terminal" (Front face), the blockout stand-in
--     "Q3_Terminal_StandIn" (Back face);
--   * map models tagged HideOnFlag vanish for a player who has their HideFlag (the father's patch, CH1_TOOK_PATCH);
--   * holograms: parts tagged Hologram shimmer and now and then glitch, HoloBlink parts blink at BlinkHz, HoloSweep
--     parts turn about PivotCenter (Radius, Period), HoloClock panels show the lighting's clock;
--   * the Ops Hall's status wall and kiosk (tag StatusWall; map_01 §3, §14): Outpost 07 "REPORT OVERDUE" blinking
--     1 Hz while the hub is in its MORNING, "COMMS RESTORED / UNDER REVIEW" after; the ticker scrolls; the clock;
--   * the hub's lights (tag HubLight) dim 30% at NIGHT (map_01 §14), and those with a playing cinematic's `dim` tag
--     ease to its fraction (the briefing room's strips to 0.35 in CIN_BRIEFING, 06 §5).
-- (The ambient movers of Phase 7 — crane, forklift, beacons — come here too.)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local UIStyle = require(Shared.Config.UIStyle)
local LightingController = require(script.Parent.LightingController)
local CinematicController = require(script.Parent.CinematicController)
local Cinematics = require(Shared.Cinematics)

local AmbientController = {}

local TERMINALS = { { name = "Q3_Terminal", face = Enum.NormalId.Front }, { name = "Q3_Terminal_StandIn", face = Enum.NormalId.Back } }
local SHIMMER_PERIOD = 3.2 -- seconds per slow transparency swell
local SHIMMER_DEPTH = 0.06
local GLITCH_EVERY = { 2.5, 6 } -- seconds between glitches (random in range)
local GLITCH_TIME = 0.09

local localPlayer = Players.LocalPlayer
local screen = nil
local flags = {}
local holograms = {} -- [part] = base transparency

-- The terminal's room face shows the message; the prop's own screen text hides meanwhile.
local function showMessage(part, face, on)
	if screen then
		screen:Destroy()
		screen = nil
	end
	local own = part:FindFirstChild("ScreenGui")
	if own and own:IsA("SurfaceGui") then
		own.Enabled = not on
	end
	if not on then
		return
	end
	screen = Instance.new("SurfaceGui")
	screen.Name = "PG_TerminalScreen"
	screen.Face = face
	screen.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screen.PixelsPerStud = 60
	screen.LightInfluence = 0
	screen.Brightness = 1.6
	screen.Adornee = part
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.BackgroundColor3 = UIStyle.Ink
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = screen
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = UIStyle.Font.Mono
	label.TextScaled = true
	label.TextColor3 = UIStyle.Accent
	label.Text = "1 NEW MESSAGE"
	label.Parent = back
	local mine = screen
	task.spawn(function()
		while screen == mine do
			label.TextTransparency = 0
			task.wait(0.6)
			label.TextTransparency = 0.85
			task.wait(0.4)
		end
	end)
end

local function watchTerminal(part, face)
	part:GetAttributeChangedSignal("NewMessage"):Connect(function()
		showMessage(part, face, part:GetAttribute("NewMessage") == true)
	end)
	showMessage(part, face, part:GetAttribute("NewMessage") == true)
end

---------------------------------------------------------------------------------------------------
-- HideOnFlag
---------------------------------------------------------------------------------------------------
local function applyHide(model)
	local flag = model:GetAttribute("HideFlag")
	local hidden = flag ~= nil and flags[flag] == true
	local parts = if model:IsA("BasePart") then { model } else model:GetDescendants()
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		elseif part:IsA("SurfaceGui") then
			part.Enabled = not hidden
		end
	end
end

local function refreshHidden()
	for _, model in ipairs(CollectionService:GetTagged("HideOnFlag")) do
		if model:IsDescendantOf(workspace) then
			applyHide(model)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Holograms
---------------------------------------------------------------------------------------------------
local function addHologram(part)
	if part:IsA("BasePart") and holograms[part] == nil then
		holograms[part] = part.Transparency
	end
end

local function clockText()
	local total = math.floor(Lighting.ClockTime * 60 + 0.5) -- to the nearest minute (7.2 is 07:12)
	return string.format("%02d:%02d", (total // 60) % 24, total % 60)
end

local function startHolograms()
	for _, part in ipairs(CollectionService:GetTagged("Hologram")) do
		addHologram(part)
	end
	CollectionService:GetInstanceAddedSignal("Hologram"):Connect(addHologram)
	CollectionService:GetInstanceRemovedSignal("Hologram"):Connect(function(part)
		holograms[part] = nil
	end)

	-- Shimmer (10 Hz is plenty for a slow swell) and the occasional glitch of one part.
	task.spawn(function()
		local nextGlitch = os.clock() + GLITCH_EVERY[1]
		local glitched, glitchEnds = nil, 0
		while true do
			local now = os.clock()
			local swell = math.sin(now * 2 * math.pi / SHIMMER_PERIOD) * SHIMMER_DEPTH
			for part, base in pairs(holograms) do
				if part.Parent then
					local value = math.clamp(base + swell * (1 - base), 0, 1)
					if part == glitched and now < glitchEnds then
						value = math.min(1, value + 0.3)
					end
					part.Transparency = value
				else
					holograms[part] = nil
				end
			end
			if now >= nextGlitch then
				local list = {}
				for part in pairs(holograms) do
					table.insert(list, part)
				end
				if #list > 0 then
					glitched = list[math.random(1, #list)]
					glitchEnds = now + GLITCH_TIME
				end
				nextGlitch = now + GLITCH_EVERY[1] + math.random() * (GLITCH_EVERY[2] - GLITCH_EVERY[1])
			end
			task.wait(0.1)
		end
	end)

	-- Blinkers: on for half of each period, nearly off for the other half.
	task.spawn(function()
		local base = {}
		while true do
			local now = os.clock()
			for _, part in ipairs(CollectionService:GetTagged("HoloBlink")) do
				if part:IsA("BasePart") then
					base[part] = base[part] or part.Transparency
					local hz = part:GetAttribute("BlinkHz") or 1
					local on = (now * hz) % 1 < 0.5
					part.Transparency = if on then base[part] else 0.9
				end
			end
			task.wait(0.05)
		end
	end)

	-- Sweeps turn every frame about their pivot.
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, part in ipairs(CollectionService:GetTagged("HoloSweep")) do
			local pivot = part:GetAttribute("PivotCenter")
			if pivot then
				local period = part:GetAttribute("Period") or 6
				local angle = (now / period) % 1 * 2 * math.pi
				part.CFrame = CFrame.new(pivot) * CFrame.Angles(0, angle, 0) * CFrame.new(part:GetAttribute("Radius") or 0, 0, 0)
			end
		end
	end)

	-- Clocks follow the lighting's time of day.
	task.spawn(function()
		while true do
			local text = clockText()
			for _, part in ipairs(CollectionService:GetTagged("HoloClock")) do
				for _, gui in ipairs(part:GetChildren()) do
					local title = gui:IsA("SurfaceGui") and gui:FindFirstChild("Title")
					if title then
						title.Text = text
					end
				end
			end
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The status wall, and the hub lights at night
---------------------------------------------------------------------------------------------------
local TICKER_SPEED = 0.025 -- band widths per second (the ticker label is 3 bands wide and says it all twice)
local NIGHT_DIM = 0.7

local function startStatusWalls()
	local cache = {} -- [part] = { rows, alarms, tickers, clocks }
	local function scan(part)
		local entry = { rows = {}, alarms = {}, tickers = {}, clocks = {} }
		for _, d in ipairs(part:GetDescendants()) do
			if d.Name == "Row07Status" and d:IsA("TextLabel") then
				table.insert(entry.rows, d)
			elseif d.Name == "Alarm" and d:IsA("Frame") then
				table.insert(entry.alarms, d)
			elseif d.Name == "Ticker" and d:IsA("TextLabel") then
				table.insert(entry.tickers, d)
			elseif d.Name == "Clock" and d:IsA("TextLabel") then
				table.insert(entry.clocks, d)
			end
		end
		cache[part] = entry
	end
	for _, part in ipairs(CollectionService:GetTagged("StatusWall")) do
		scan(part)
	end
	CollectionService:GetInstanceAddedSignal("StatusWall"):Connect(scan)
	CollectionService:GetInstanceRemovedSignal("StatusWall"):Connect(function(part)
		cache[part] = nil
	end)

	local baseBrightness = {}
	local last = os.clock()
	task.spawn(function()
		while true do
			local now = os.clock()
			local dt = now - last
			last = now
			local hub = LightingController.getHub()
			local morning = hub == "MORNING"
			local clock = clockText()
			for _, entry in pairs(cache) do
				for _, row in ipairs(entry.rows) do
					row.Text = if morning then "REPORT OVERDUE" else "COMMS RESTORED / UNDER REVIEW"
					row.TextTransparency = if morning and now % 1 >= 0.5 then 0.85 else 0
				end
				for _, alarm in ipairs(entry.alarms) do
					alarm.Visible = morning
				end
				for _, ticker in ipairs(entry.tickers) do
					ticker.Position = UDim2.fromScale(-((now * TICKER_SPEED) % 1.5), ticker.Position.Y.Scale)
				end
				for _, label in ipairs(entry.clocks) do
					label.Text = clock
				end
			end
			-- Hub lights ease (0.5 s) toward base × night dim × the playing cinematic's dim.
			local playing = CinematicController.isPlaying()
			local spec = playing and (Cinematics :: any)[playing]
			local dim = spec and spec.dim
			local night = if hub == "NIGHT" then NIGHT_DIM else 1
			local ease = math.min(1, dt / 0.5)
			for _, light in ipairs(CollectionService:GetTagged("HubLight")) do
				if light:IsA("Light") then
					local base = baseBrightness[light]
					if not base then
						base = light.Brightness
						baseBrightness[light] = base
					end
					local target = base * night * (if dim and light:HasTag(dim.tag) then dim.to else 1)
					local current = light.Brightness
					if math.abs(current - target) > 0.003 then
						light.Brightness = current + (target - current) * ease
					end
				end
			end
			task.wait(0.05)
		end
	end)
end

function AmbientController.Init() end

function AmbientController.Start()
	Net.on("Profile_Snapshot", function(snapshot)
		flags = (snapshot and snapshot.flags) or {}
		refreshHidden()
	end)
	CollectionService:GetInstanceAddedSignal("HideOnFlag"):Connect(applyHide)
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 30)
		if not map then
			return
		end
		for _, t in ipairs(TERMINALS) do
			local part = map:FindFirstChild(t.name, true)
			if part then
				watchTerminal(part, t.face)
				break
			end
		end
		refreshHidden()
		startHolograms()
		startStatusWalls()
	end)
end

return AmbientController
