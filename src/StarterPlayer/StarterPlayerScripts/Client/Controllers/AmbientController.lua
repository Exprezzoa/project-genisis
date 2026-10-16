--!nonstrict
-- Client/Controllers/AmbientController.lua  (docs/16 §3; docs/05 S02, S43; docs/07 §6 holograms)
--
-- Small things in the world that only look alive on this client:
--   * the Q-3 desk terminal's screen blinks "1 NEW MESSAGE" in amber while its part has the attribute NewMessage
--     (the server sets it in S43); the dressed terminal is "Q3_Terminal" (Front face), the blockout stand-in
--     "Q3_Terminal_StandIn" (Back face);
--   * map models tagged HideOnFlag vanish for a player who has their HideFlag (the father's patch, CH1_TOOK_PATCH);
--   * holograms: parts tagged Hologram shimmer and now and then glitch, HoloBlink parts blink at BlinkHz, HoloSweep
--     parts turn about PivotCenter (Radius, Period), HoloClock panels show the lighting's clock.
-- (The ambient movers of Phase 7 — crane, forklift, beacons — come here too.)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local UIStyle = require(Shared.Config.UIStyle)

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
	end)
end

return AmbientController
