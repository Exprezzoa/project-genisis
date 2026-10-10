--!strict
-- ReplicatedFirst/LoadingScreen.client.lua  (docs/14_ui.md §2)
--
-- Replaces the default loading screen: ink black, "PROJECT GENESIS" on a tilted slab, a tip that changes every
-- 4 s and a thin amber progress line (indeterminate sweep), in the angular style of the menus: a diagonal
-- amber band, drifting motes and a blinking status tag. Hides when the game is loaded AND the server answered
-- with Server_Ready, or after 20 s; bars wipe across the screen as it goes.
-- It runs before ReplicatedStorage has replicated, so the few style values it needs are repeated here instead
-- of required from Config/UIStyle, and everything is plain Frames.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TIMEOUT = 20
local TIP_INTERVAL = 4
local INK = Color3.fromHex("#0B0E10")
local PAPER = Color3.fromHex("#E8ECEF")
local TEXT_SECONDARY = Color3.fromHex("#9AA6B2")
local ACCENT = Color3.fromHex("#E8A33D")
local SLANT, TILT = 14, -4
local MOTES = 14
local TIPS = {
	"Titans regenerate. Break their balance, then strike the core.",
	"Dodge into attacks, not away. The start of a dodge is invulnerable.",
	"Some details are worth a second look.",
	"Pilots tap the hatch twice. For luck.",
}

ReplicatedFirst:RemoveDefaultLoadingScreen()

local function frame(parent: Instance, name: string, color: Color3, props: { [string]: any }): Frame
	local new = Instance.new("Frame")
	new.Name = name
	new.BackgroundColor3 = color
	new.BorderSizePixel = 0
	for key, value in pairs(props) do
		(new :: any)[key] = value
	end
	new.Parent = parent
	return new
end

local function text(parent: Instance, name: string, font: Font, size: number, color: Color3, props: { [string]: any }): TextLabel
	local new = Instance.new("TextLabel")
	new.Name = name
	new.BackgroundTransparency = 1
	new.FontFace = font
	new.TextSize = size
	new.TextColor3 = color
	for key, value in pairs(props) do
		(new :: any)[key] = value
	end
	new.Parent = parent
	return new
end

local gui = Instance.new("ScreenGui")
gui.Name = "PG_Loading"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local background = frame(gui, "Background", INK, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true })

-- The diagonal amber band on the left with a thin paper line beside it.
local band = frame(background, "Band", ACCENT, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(-0.2, 0.5),
	Size = UDim2.new(0, 220, 3, 0),
	Rotation = SLANT,
})
local bandLine = frame(background, "BandLine", PAPER, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(-0.2, 150, 0.5, 0),
	Size = UDim2.new(0, 6, 3, 0),
	Rotation = SLANT,
})

-- Motes drifting up, as on the menu stage.
local random = Random.new(11)
local motes = {}
for index = 1, MOTES do
	local size = random:NextInteger(4, 10)
	local mote = frame(background, "Mote", if index % 3 == 0 then ACCENT else PAPER, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundTransparency = random:NextNumber(0.6, 0.88),
	})
	table.insert(motes, { frame = mote, x = random:NextNumber(0.25, 0.98), y = random:NextNumber(0, 1), speed = random:NextNumber(0.03, 0.1) })
end

-- The title on a tilted paper slab over an amber shadow.
local titleHolder = frame(background, "Title", INK, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.43),
	Size = UDim2.new(0.62, 0, 0, 76),
	Rotation = TILT,
})
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(820, 76)
limit.Parent = titleHolder
frame(titleHolder, "Shadow", ACCENT, { Position = UDim2.fromOffset(9, 8), Size = UDim2.fromScale(1, 1) })
local slab = frame(titleHolder, "Slab", PAPER, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
local title = text(slab, "Text", Font.fromEnum(Enum.Font.Michroma), 40, INK, {
	Position = UDim2.fromScale(0.04, 0.14),
	Size = UDim2.fromScale(0.92, 0.72),
	Text = "P R O J E C T   G E N E S I S", -- letter-spaced
	TextScaled = true,
	ZIndex = 3,
})
local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MinTextSize = 12
titleLimit.MaxTextSize = 40
titleLimit.Parent = title

local tip = text(background, "Tip", Font.new("rbxasset://fonts/families/TitilliumWeb.json"), 18, TEXT_SECONDARY, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.43, 64),
	Size = UDim2.new(0.8, 0, 0, 48),
	TextWrapped = true,
	Text = TIPS[1],
})

local track = frame(background, "Track", TEXT_SECONDARY, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.43, 126),
	Size = UDim2.new(0, 320, 0, 2),
	BackgroundTransparency = 0.8,
	ClipsDescendants = true,
})
local sweep = frame(track, "Sweep", ACCENT, { Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(-0.3, 0) })

-- Status tag in the corner: a blinking diamond and what the screen is waiting for.
local status = text(background, "Status", Font.fromEnum(Enum.Font.RobotoMono), 12, TEXT_SECONDARY, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -28, 1, -24),
	Size = UDim2.fromOffset(260, 20),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "LOADING  //  ASSETS",
})
local blink = frame(background, "Blink", ACCENT, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -304, 1, -34),
	Size = UDim2.fromOffset(8, 8),
	Rotation = 45,
})

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
gui:SetAttribute("Visible", true)

-- Entrance: the band slides in, the title slab drops into place.
local enter = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
TweenService:Create(band, enter, { Position = UDim2.fromScale(0.08, 0.5) }):Play()
TweenService:Create(bandLine, enter, { Position = UDim2.new(0.08, 150, 0.5, 0) }):Play()
titleHolder.Position = UDim2.new(0.5, 0, 0.43, -40)
TweenService:Create(titleHolder, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.43) }):Play()

local sweepTween = TweenService:Create(sweep, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(1, 0) })
sweepTween:Play()

local clock = 0
local stepped = RunService.RenderStepped:Connect(function(dt)
	clock += dt
	for _, mote in ipairs(motes) do
		mote.y -= mote.speed * dt
		if mote.y < -0.05 then
			mote.y = 1.05
		end
		mote.frame.Position = UDim2.fromScale(mote.x, mote.y)
	end
	blink.BackgroundTransparency = if clock % 1 < 0.5 then 0 else 0.7
end)

local visible = true
task.spawn(function()
	local index = 1
	local fade = TweenInfo.new(0.25)
	while visible do
		task.wait(TIP_INTERVAL)
		if not visible then
			break
		end
		index = index % #TIPS + 1
		-- The tip fades out, changes, and fades back in.
		local out = TweenService:Create(tip, fade, { TextTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		tip.Text = TIPS[index]
		TweenService:Create(tip, fade, { TextTransparency = 0 }):Play()
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
	status.Text = if game:IsLoaded() then "LOADING  //  COMMAND LINK" else "LOADING  //  ASSETS"
	task.wait(0.1)
end

visible = false
sweepTween:Cancel()
gui:SetAttribute("Visible", false)
gui:SetAttribute("HiddenAfter", os.clock() - started)
gui:SetAttribute("ServerReady", serverReady)

-- Exit: three bars wipe across from the right; behind them the screen clears.
status.Text = "READY"
local wipeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
for index, color in ipairs({ PAPER, ACCENT, INK }) do
	local bar = frame(gui, "Wipe", color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1.5, 0.5),
		Size = UDim2.fromScale(0.36 - 0.09 * (index - 1), 3),
		Rotation = SLANT,
		ZIndex = 10,
	})
	task.delay(0.07 * (index - 1), function()
		TweenService:Create(bar, wipeInfo, { Position = UDim2.fromScale(-0.5, 0.5) }):Play()
	end)
end
task.wait(0.25)
for _, child in ipairs(background:GetChildren()) do
	if child:IsA("GuiObject") then
		child.Visible = false
	end
end
local fade = TweenService:Create(background, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
fade:Play()
fade.Completed:Wait()
task.wait(0.3)
stepped:Disconnect()
gui.Enabled = false
