--!nonstrict
-- Client/UI/BriefingScreen.lua  (docs/maps/map_01_central_command.md §6; slides: docs/05 S07)
--
-- The screen on Briefing Room One's west wall (the part ...Briefing.Gameplay.BriefingScreen, 30 × 10 studs). This
-- client draws it as a SurfaceGui; show(index) wipes to one of the seven slides of the S07 table. Wording the
-- table doesn't give (the last-report block, map labels, the Strider caption) uses only what Vale says (D-083).
-- Colors: Directorate amber on the screen base; the feral Titan's eye glow is the orange-red of docs/06.
--
--   show(index)      reset()      current() -> number

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local BriefingScreen = {}

local PIXELS_PER_STUD = 40 -- 30 × 10 studs -> 1200 × 400
local BASE = Color3.fromHex("#1B2A33") -- docs/07 §6 screen base
local PLATE = Color3.fromHex("#4A5A6A") -- the division patch (docs/03)
local FERAL = Color3.fromHex("#E25B2D") -- orange-red: feral Titans (docs/06)
local AMBER, PAPER, SECONDARY, DANGER = UIStyle.Accent, UIStyle.Paper, UIStyle.TextSecondary, UIStyle.Danger
local SLIDES = 7

local gui, page, wipe, counter
local index = 0
local token = 0

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = props.color or AMBER
	f.BackgroundTransparency = props.transparency or 0
	f.AnchorPoint = props.anchor or Vector2.zero
	f.Position = props.pos or UDim2.new()
	f.Size = props.size or UDim2.new()
	f.Rotation = props.rotation or 0
	f.ZIndex = props.z or 2
	f.Parent = parent
	return f
end

local function text(parent, value, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UIStyle.Font[props.font or "Header"]
	label.TextSize = props.size or 24
	label.TextColor3 = props.color or PAPER
	label.TextXAlignment = props.align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.AnchorPoint = props.anchor or Vector2.zero
	label.Position = props.pos or UDim2.new()
	label.Size = props.box or UDim2.new(1, 0, 0, (props.size or 24) + 8)
	label.Text = value
	label.ZIndex = props.z or 3
	label.Parent = parent
	return label
end

local function blink(object, property, a, b, period)
	local mine = token
	task.spawn(function()
		while token == mine and object.Parent do
			object[property] = a
			task.wait(period / 2)
			object[property] = b
			task.wait(period / 2)
		end
	end)
end

----------------------------------------------------------------------------------------------------------------
-- Slides (1200 × 400 canvas, content under a 44 px header)
----------------------------------------------------------------------------------------------------------------
local function emblem(parent)
	local square = frame(parent, { color = PLATE, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(600, 150), size = UDim2.fromOffset(150, 150) })
	frame(square, { color = AMBER, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5), size = UDim2.fromOffset(90, 24), z = 3 })
	text(parent, "THIRD FRONTIER FRAME DIVISION", { size = 34, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 250) })
	text(parent, "NEW HALDEN", { size = 18, color = SECONDARY, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 296) })
end

local function reportsMissed(parent)
	text(parent, "OUTPOST 07", { size = 58, pos = UDim2.fromOffset(60, 40) })
	text(parent, "4 REPORTS MISSED", { size = 30, color = DANGER, pos = UDim2.fromOffset(64, 112) })
	for n = 1, 4 do
		local box = frame(parent, { color = BASE, pos = UDim2.fromOffset(60 + (n - 1) * 150, 200), size = UDim2.fromOffset(130, 90) })
		local stroke = Instance.new("UIStroke")
		stroke.Color = DANGER
		stroke.Thickness = 2
		stroke.Parent = box
		text(box, ("REPORT %d"):format(n), { size = 14, color = SECONDARY, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 10) })
		local missed = text(box, "MISSED", { size = 22, color = DANGER, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 46) })
		if n == 4 then
			blink(missed, "TextTransparency", 0, 0.7, 1.0)
		end
	end
	text(parent, "NO CONTACT", { size = 22, color = AMBER, pos = UDim2.fromOffset(700, 228) })
end

local function lastReport(parent)
	text(parent, "LAST REPORT — FRONTIER OUTPOST 07 \"GREYWATCH\"", { size = 24, color = AMBER, pos = UDim2.fromOffset(60, 40) })
	frame(parent, { color = AMBER, transparency = 0.5, pos = UDim2.fromOffset(60, 82), size = UDim2.fromOffset(820, 2) })
	local rows = { { "CONTACT", "ROUTINE" }, { "WEATHER", "NOMINAL" }, { "TITAN ACTIVITY", "NONE FLAGGED" } }
	for n, row in ipairs(rows) do
		local y = 110 + (n - 1) * 62
		text(parent, row[1], { font = "Mono", size = 28, color = SECONDARY, pos = UDim2.fromOffset(60, y) })
		text(parent, row[2], { font = "Mono", size = 28, pos = UDim2.fromOffset(440, y) })
	end
end

-- The territory map: New Halden's blocks in the west, the Bulwark, the corridor east to Outpost 07.
local function territory(parent, lowmarch)
	for n, block in ipairs({ { 70, 150, 60, 70 }, { 140, 120, 50, 110 }, { 196, 160, 44, 60 }, { 92, 232, 80, 40 }, { 180, 230, 40, 46 } }) do
		frame(parent, { color = PLATE, transparency = 0.1 * (n % 2), pos = UDim2.fromOffset(block[1], block[2]), size = UDim2.fromOffset(block[3], block[4]) })
	end
	text(parent, "NEW HALDEN", { size = 18, pos = UDim2.fromOffset(70, 288) })
	frame(parent, { color = AMBER, pos = UDim2.fromOffset(262, 60), size = UDim2.fromOffset(6, 280) })
	text(parent, "BULWARK", { size = 14, color = AMBER, pos = UDim2.fromOffset(276, 64) })
	for n = 0, 15 do -- the corridor east, dashed
		frame(parent, { color = PAPER, transparency = 0.2, pos = UDim2.fromOffset(280 + n * 40, 199), size = UDim2.fromOffset(24, 3) })
	end
	text(parent, "41 KM EAST", { size = 22, color = AMBER, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(280, 160), box = UDim2.fromOffset(640, 30) })
	local marker = frame(parent, { color = DANGER, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(950, 200), size = UDim2.fromOffset(22, 22), rotation = 45, z = 4 })
	blink(marker, "BackgroundTransparency", 0, 0.75, 1.0)
	text(parent, "OUTPOST 07", { size = 20, pos = UDim2.fromOffset(980, 186) })
	if lowmarch then
		frame(parent, { color = PAPER, transparency = 0.4, pos = UDim2.fromOffset(948, 214), size = UDim2.fromOffset(3, 86) })
		frame(parent, { color = AMBER, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromOffset(950, 312), size = UDim2.fromOffset(18, 18), rotation = 45, z = 4 })
		text(parent, "OUTPOST 05 — LOWMARCH", { size = 20, color = AMBER, pos = UDim2.fromOffset(980, 298) })
	end
end

local function orders(parent)
	text(parent, "ORDERS", { size = 30, color = AMBER, pos = UDim2.fromOffset(60, 40) })
	for n, item in ipairs({ "ASSESS", "RESTORE COMMS", "REPORT" }) do
		local y = 110 + (n - 1) * 78
		frame(parent, { color = AMBER, pos = UDim2.fromOffset(60, y + 6), size = UDim2.fromOffset(52, 40) })
		text(parent, ("%02d"):format(n), { size = 22, color = UIStyle.Ink, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(60, y + 6), box = UDim2.fromOffset(52, 40) })
		text(parent, item, { size = 36, pos = UDim2.fromOffset(136, y) })
	end
end

-- A Strider's hunched outline built from slabs (docs/10: long arms, small head, forward lean).
local function strider(parent)
	local ink = Color3.fromHex("#0B0E10")
	local body = frame(parent, { color = BASE, transparency = 1, pos = UDim2.fromOffset(120, 40), size = UDim2.fromOffset(300, 320) })
	local parts = {
		{ 120, 60, 90, 120, 18 }, -- torso, leaning forward
		{ 152, 30, 40, 40, 10 }, -- head
		{ 90, 90, 22, 150, 30 }, { 190, 100, 22, 160, -12 }, -- long arms
		{ 112, 172, 30, 120, 6 }, { 158, 172, 30, 120, -8 }, -- legs
	}
	for _, p in ipairs(parts) do
		frame(body, { color = ink, pos = UDim2.fromOffset(p[1], p[2]), size = UDim2.fromOffset(p[3], p[4]), rotation = p[5], z = 3 })
	end
	local eye = frame(body, { color = FERAL, pos = UDim2.fromOffset(170, 44), size = UDim2.fromOffset(10, 5), rotation = 10, z = 4 })
	blink(eye, "BackgroundTransparency", 0, 0.5, 1.6)
	text(parent, "STRIDER", { size = 44, pos = UDim2.fromOffset(500, 90) })
	text(parent, "CLASS-2 (est.)", { size = 30, color = AMBER, pos = UDim2.fromOffset(504, 150) })
	text(parent, "KESSLER BASIN — STALE DATA", { font = "Mono", size = 22, color = SECONDARY, pos = UDim2.fromOffset(504, 214) })
end

local BUILDERS = {
	emblem, reportsMissed, lastReport,
	function(parent) territory(parent, false) end,
	orders, strider,
	function(parent) territory(parent, true) end,
}

----------------------------------------------------------------------------------------------------------------
local function screenPart(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local found = map and map:FindFirstChild("BriefingScreen", true)
	return if found and found:IsA("BasePart") then found else nil
end

local function build(): boolean
	if gui and gui.Parent then
		return true
	end
	local part = screenPart()
	if not part then
		return false
	end
	gui = Instance.new("SurfaceGui")
	gui.Name = "PG_BriefingScreen"
	gui.Face = Enum.NormalId.Right -- the part's +X face looks east, over the seats
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Adornee = part
	gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local back = frame(gui, { color = BASE, size = UDim2.fromScale(1, 1), z = 1 })
	for n = 0, 39 do -- scanlines
		frame(back, { color = Color3.new(0, 0, 0), transparency = 0.86, pos = UDim2.fromOffset(0, n * 10), size = UDim2.new(1, 0, 0, 2), z = 6 })
	end
	frame(back, { color = AMBER, pos = UDim2.fromOffset(0, 0), size = UDim2.new(1, 0, 0, 4), z = 5 })
	text(back, "THIRD FRONTIER — BRIEFING ROOM ONE", { size = 14, color = AMBER, pos = UDim2.fromOffset(24, 10), z = 5 })
	counter = text(back, "", { font = "Mono", size = 14, color = SECONDARY, align = Enum.TextXAlignment.Right, pos = UDim2.fromOffset(-24, 10), z = 5 })
	page = frame(back, { color = BASE, transparency = 1, pos = UDim2.fromOffset(0, 44), size = UDim2.new(1, 0, 1, -44), z = 2 })
	page.ClipsDescendants = true
	wipe = frame(back, { color = AMBER, pos = UDim2.fromOffset(-12, 44), size = UDim2.new(0, 6, 1, -44), z = 5 })
	wipe.Visible = false
	return true
end

-- Wipes to slide n: the amber bar sweeps left to right, the new slide drawn behind it.
function BriefingScreen.show(n: number)
	if not build() or n < 1 or n > SLIDES or n == index then
		return
	end
	token += 1
	local mine = token
	index = n
	counter.Text = ("%d / %d"):format(n, SLIDES)
	local holder = frame(page, { color = BASE, transparency = 1, size = UDim2.new(0, 0, 1, 0), z = 2 })
	holder.ClipsDescendants = true
	local content = frame(holder, { color = BASE, transparency = 1, size = UDim2.fromOffset(1200, 356), z = 2 })
	BUILDERS[n](content)
	wipe.Visible = true
	wipe.Position = UDim2.fromOffset(-6, 44)
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	TweenService:Create(holder, info, { Size = UDim2.new(1, 0, 1, 0) }):Play()
	TweenService:Create(wipe, info, { Position = UDim2.new(1, 0, 0, 44) }):Play()
	task.delay(0.46, function()
		if token ~= mine then
			return
		end
		wipe.Visible = false
		for _, old in ipairs(page:GetChildren()) do
			if old ~= holder then
				old:Destroy()
			end
		end
	end)
end

function BriefingScreen.reset()
	index = 0
	if build() then
		for _, old in ipairs(page:GetChildren()) do
			old:Destroy()
		end
		BriefingScreen.show(1)
	end
end

function BriefingScreen.current(): number
	return index
end

return BriefingScreen
