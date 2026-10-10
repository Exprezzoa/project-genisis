--!strict
-- ReplicatedFirst/LoadingScreen.client.lua  (docs/14_ui.md §2)
--
-- Replaces the default loading screen: black, "PROJECT GENESIS", a tip that changes every 4 s and a thin
-- amber progress line (indeterminate sweep). Hides when the game is loaded AND the server answered with
-- Server_Ready, or after 20 s. It runs before ReplicatedStorage has replicated, so the few style values it
-- needs are repeated here instead of required from Config/UIStyle.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TIMEOUT = 20
local TIP_INTERVAL = 4
local PANEL_SOLID = Color3.fromHex("#0B0E10")
local TEXT_PRIMARY = Color3.fromHex("#E8ECEF")
local TEXT_SECONDARY = Color3.fromHex("#9AA6B2")
local ACCENT = Color3.fromHex("#E8A33D")
local TIPS = {
	"Titans regenerate. Break their balance, then strike the core.",
	"Dodge into attacks, not away. The start of a dodge is invulnerable.",
	"Some details are worth a second look.",
	"Pilots tap the hatch twice. For luck.",
}

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "PG_Loading"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = PANEL_SOLID
background.BorderSizePixel = 0
background.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.new(0.9, 0, 0, 48)
title.FontFace = Font.fromEnum(Enum.Font.Michroma)
title.TextSize = 40
title.TextColor3 = TEXT_PRIMARY
title.Text = "P R O J E C T   G E N E S I S" -- letter-spaced
title.TextScaled = true
title.Parent = background
local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MinTextSize = 12
titleLimit.MaxTextSize = 40
titleLimit.Parent = title

local tip = Instance.new("TextLabel")
tip.BackgroundTransparency = 1
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0.45, 48)
tip.Size = UDim2.new(0.8, 0, 0, 48)
tip.FontFace = Font.new("rbxasset://fonts/families/TitilliumWeb.json")
tip.TextSize = 18
tip.TextWrapped = true
tip.TextColor3 = TEXT_SECONDARY
tip.Text = TIPS[1]
tip.Parent = background

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0.45, 112)
track.Size = UDim2.new(0, 320, 0, 2)
track.BackgroundColor3 = TEXT_SECONDARY
track.BackgroundTransparency = 0.8
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = background
local sweep = Instance.new("Frame")
sweep.Size = UDim2.fromScale(0.3, 1)
sweep.Position = UDim2.fromScale(-0.3, 0)
sweep.BackgroundColor3 = ACCENT
sweep.BorderSizePixel = 0
sweep.Parent = track

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
gui:SetAttribute("Visible", true)

local sweepTween = TweenService:Create(sweep, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(1, 0) })
sweepTween:Play()

local visible = true
task.spawn(function()
	local index = 1
	while visible do
		task.wait(TIP_INTERVAL)
		index = index % #TIPS + 1
		tip.Text = TIPS[index]
	end
end)

local serverReady = false
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", TIMEOUT)
	local remote = remotes and remotes:WaitForChild("Server_Ready", TIMEOUT)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Wait()
		serverReady = true
	end
end)

local started = os.clock()
while os.clock() - started < TIMEOUT and not (game:IsLoaded() and serverReady) do
	task.wait(0.1)
end

visible = false
sweepTween:Cancel()
gui:SetAttribute("Visible", false)
gui:SetAttribute("HiddenAfter", os.clock() - started)
gui:SetAttribute("ServerReady", serverReady)
local fade = TweenService:Create(background, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
title.Visible, tip.Visible, track.Visible = false, false, false
fade:Play()
fade.Completed:Wait()
gui.Enabled = false
