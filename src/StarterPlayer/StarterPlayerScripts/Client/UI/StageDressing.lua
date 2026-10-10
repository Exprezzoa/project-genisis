--!nonstrict
-- Client/UI/StageDressing.lua  (docs/14_ui.md §1.2)
--
-- The small moving details of the CharacterStage's color field, all Frames and text:
--   motes     tilted squares drifting up the field (they rush when the menu opens)
--   sweep     a thin line travelling down the field
--   word      the screen's name in huge faint letters behind the silhouette
--   readout   a tag in the corner: the zone the player is in and the session clock
--
--   build(root)      set(word, instant)      burst()      update(dt)      getState() -> table (for tests)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = require(script.Parent.Components)

local Dressing = {}

Dressing.MOTES = 18
Dressing.BURST = 9 -- how many times faster the motes rise right after the menu opens
Dressing.BURST_FADE = 2.5 -- how fast the rush dies down (1/s)
Dressing.SWEEP_PERIOD = 5 -- seconds per pass of the line
Dressing.WORD_SIZE = 120
Dressing.WORD_TRANSPARENCY = 0.87

local random = Random.new(7)
local motes = {} -- { frame, x, y, speed, sway, phase }
local holder, sweep, word, readout, blink
local clock, rush = 0, 0
local shownSecond = -1

function Dressing.build(root)
	-- Over the field, under the silhouette. The field's leaning edge is left of this box at every height.
	holder = Instance.new("Frame")
	holder.Name = "Dressing"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.fromScale(1, 0)
	holder.Size = UDim2.fromScale(0.34, 1)
	holder.ClipsDescendants = true
	holder.Parent = root

	for index = 1, Dressing.MOTES do
		local size = random:NextInteger(4, 12)
		local frame = Instance.new("Frame")
		frame.Name = "Mote"
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = if index % 3 == 0 then UIStyle.Paper else UIStyle.Ink
		frame.BackgroundTransparency = random:NextNumber(0.45, 0.8)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromOffset(size, size)
		frame.Rotation = 45
		frame.Parent = holder
		table.insert(motes, {
			frame = frame,
			x = random:NextNumber(0.04, 0.96),
			y = random:NextNumber(0, 1),
			speed = random:NextNumber(0.03, 0.09) * (14 - size) / 6, -- small ones rise faster
			sway = random:NextNumber(0.01, 0.03),
			phase = random:NextNumber(0, 6.28),
		})
	end

	sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.BackgroundColor3 = UIStyle.Paper
	sweep.BackgroundTransparency = 0.55
	sweep.Size = UDim2.new(1, 0, 0, 2)
	sweep.Parent = holder

	word = Components.label(root, "", { font = "Header", size = Dressing.WORD_SIZE, color = UIStyle.Ink }, {
		Name = "Word",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 30, 1, -70),
		Size = UDim2.new(0.44, 0, 0, Dressing.WORD_SIZE + 20),
		Rotation = UIStyle.Tilt,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = Dressing.WORD_TRANSPARENCY,
	})

	readout = Components.slab(root, { color = UIStyle.Ink }, {
		Name = "Readout",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -22),
		Size = UDim2.fromOffset(330, 34),
		ZIndex = 4,
	})
	blink = Instance.new("Frame")
	blink.Name = "Blink"
	blink.BorderSizePixel = 0
	blink.BackgroundColor3 = UIStyle.Accent
	blink.AnchorPoint = Vector2.new(0, 0.5)
	blink.Position = UDim2.new(0, 22, 0.5, 0)
	blink.Size = UDim2.fromOffset(8, 8)
	blink.Rotation = 45
	blink.ZIndex = 5
	blink.Parent = readout
	Components.label(readout, "", { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.Paper }, {
		Name = "Line",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -60, 1, 0),
		ZIndex = 5,
	})
	Dressing.update(0)
end

-- Changes the big word. The new one slides in from the right while it fades up.
function Dressing.set(text, instant)
	word.Text = text
	if instant then
		word.TextTransparency = Dressing.WORD_TRANSPARENCY
		word.Position = UDim2.new(1, 30, 1, -70)
		return
	end
	word.TextTransparency = 1
	word.Position = UDim2.new(1, 190, 1, -70)
	TweenService:Create(word, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextTransparency = Dressing.WORD_TRANSPARENCY,
		Position = UDim2.new(1, 30, 1, -70),
	}):Play()
end

-- The motes rush upward for a moment (the menu just opened).
function Dressing.burst()
	rush = 1
end

local function zoneText()
	local player = Players.LocalPlayer
	local zone = player and player:GetAttribute("Zone")
	if type(zone) ~= "string" or zone == "" then
		return "NO ZONE"
	end
	return string.upper((string.gsub(zone, "(%l)(%u)", "%1 %2"))) -- "OpsHall" -> "OPS HALL"
end

function Dressing.update(dt)
	clock += dt
	rush *= math.exp(-Dressing.BURST_FADE * dt)
	local speedScale = 1 + (Dressing.BURST - 1) * rush
	for _, mote in ipairs(motes) do
		mote.y -= mote.speed * speedScale * dt
		if mote.y < -0.05 then
			mote.y = 1.05
			mote.x = random:NextNumber(0.04, 0.96)
		end
		mote.frame.Position = UDim2.fromScale(mote.x + mote.sway * math.sin(clock * 0.8 + mote.phase), mote.y)
	end
	sweep.Position = UDim2.fromScale(0, (clock / Dressing.SWEEP_PERIOD) % 1)
	blink.BackgroundTransparency = if clock % 1 < 0.5 then 0 else 0.7
	local seconds = math.floor(workspace.DistributedGameTime)
	if seconds ~= shownSecond then
		shownSecond = seconds
		readout.Line.Text = ("%s  //  T+%02d:%02d:%02d"):format(zoneText(), seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
end

function Dressing.getState()
	return { word = word.Text, readout = readout.Line.Text, motes = #motes, firstMoteY = motes[1].y, sweepY = sweep.Position.Y.Scale, rush = rush }
end

return Dressing
