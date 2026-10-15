--!nonstrict
-- Client/Controllers/AmbientController.lua  (docs/16 §3; docs/05 S43)
--
-- Small things in the world that only look alive on this client. So far: the Q-3 desk terminal's screen, which
-- blinks "1 NEW MESSAGE" in amber while its part has the attribute NewMessage (the server sets it in S43).
-- (The ambient movers of Phase 7 — crane, forklift, beacons — come here too.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local AmbientController = {}

local TERMINAL = "Q3_Terminal_StandIn"
local localPlayer = Players.LocalPlayer
local screen = nil

-- The terminal's +Z face looks at the room (the stand-in sits against the desk's back edge, facing south).
local function showMessage(part, on)
	if screen then
		screen:Destroy()
		screen = nil
	end
	if not on then
		return
	end
	screen = Instance.new("SurfaceGui")
	screen.Name = "PG_TerminalScreen"
	screen.Face = Enum.NormalId.Back
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

local function watch(part)
	part:GetAttributeChangedSignal("NewMessage"):Connect(function()
		showMessage(part, part:GetAttribute("NewMessage") == true)
	end)
	showMessage(part, part:GetAttribute("NewMessage") == true)
end

function AmbientController.Init() end

function AmbientController.Start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 30)
		local part = map and map:FindFirstChild(TERMINAL, true)
		if part then
			watch(part)
		end
	end)
end

return AmbientController
