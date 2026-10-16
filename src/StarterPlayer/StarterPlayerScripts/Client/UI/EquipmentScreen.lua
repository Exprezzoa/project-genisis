--!nonstrict
-- Client/UI/EquipmentScreen.lua  (docs/17 §6 "Upgrades"; docs/12 §12; docs/14 §1.1 angular style)
--
-- The Equipment Terminal's screen, on the CharacterStage like every menu screen: the pilot strip (rank, XP to the
-- next rank, credits), the upgrade list on the left (name, cost, and a chip: INSTALLED, RANK n, NEED n CR or
-- AVAILABLE) with an amber pointer that slides to the selected row, and the selected upgrade on the right: its
-- description, each modifier as "before → after", and BUY. A purchase stamps INSTALLED over the panel and counts
-- the credits down; a refusal shakes BUY and says why.
--
--   EquipmentScreen.build(parent, { onBuy(upgradeId), onClose() }) -> screen
--   screen.frame   screen.first (the control a gamepad starts on)
--   screen.refresh(state)          state = { rank, xp, credits, upgrades }
--   screen.result(result, state)   result = { upgradeId, ok, reason }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local UIStyle = require(Shared.Config.UIStyle)
local Upgrades = require(Shared.Config.Upgrades)
local EffectiveConfig = require(Shared.Modules.EffectiveConfig)

local Components = require(script.Parent.Components)

local EquipmentScreen = {}

local ROW = 64
local GAP = 10
local REASONS = {
	Rank = "RANK %d REQUIRED",
	Credits = "NOT ENOUGH CREDITS",
	Owned = "ALREADY INSTALLED",
	Unknown = "NOT AVAILABLE",
	NoProfile = "PROFILE NOT LOADED",
}

local function number(value)
	local text = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
	return text
end

local function quick(instance, seconds, props, style)
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Counts a mono label from one value to another ("%d CR").
local function countTo(label, from, to, seconds, format)
	local started = os.clock()
	local token = {}
	label:SetAttribute("CountToken", tostring(token))
	task.spawn(function()
		while label.Parent and label:GetAttribute("CountToken") == tostring(token) do
			local t = math.clamp((os.clock() - started) / seconds, 0, 1)
			label.Text = format:format(math.floor(from + (to - from) * (1 - (1 - t) ^ 3) + 0.5))
			if t >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function chip(parent, props)
	local holder = Components.slab(parent, { color = UIStyle.Ink, slant = 10 }, props)
	local text = Components.label(holder, "", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.Paper }, {
		Name = "Text", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = (props.ZIndex or 1) + 1,
	})
	return holder, text
end

-- What a row's chip says, its colors, and whether BUY is open.
local function statusOf(upgrade, state)
	if state.upgrades[upgrade.id] then
		return "INSTALLED", UIStyle.Accent, UIStyle.Ink, false
	elseif state.rank < upgrade.rankRequired then
		return ("RANK %d"):format(upgrade.rankRequired), UIStyle.Ink, UIStyle.TextSecondary, false
	elseif state.credits < upgrade.cost then
		return ("NEED %d CR"):format(upgrade.cost - state.credits), UIStyle.Ink, UIStyle.Danger, false
	end
	return "AVAILABLE", UIStyle.Ink, UIStyle.Accent, true
end

function EquipmentScreen.build(parent, callbacks)
	local frame = Instance.new("Frame")
	frame.Name = "Equipment"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 5
	frame.Parent = parent

	Components.title(frame, "EQUIPMENT", { Position = UDim2.fromOffset(72, 48), Size = UDim2.fromOffset(520, 68), ZIndex = 6 }, { size = UIStyle.TextSize.Hero, color = UIStyle.Ink, textColor = UIStyle.Paper })
	Components.label(frame, "UNIT 02 — VANGUARD REFIT", { font = "Mono", size = UIStyle.TextSize.Small, color = UIStyle.Accent }, {
		Position = UDim2.fromOffset(96, 124), Size = UDim2.fromOffset(480, 20), ZIndex = 6,
	})
	local close = Components.button(frame, "CLOSE", callbacks.onClose, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -72, 0, 56), Size = UDim2.fromOffset(200, 44), ZIndex = 6,
	})

	local page = Components.slab(frame, { color = UIStyle.Ink, transparency = 0.04, slant = 4 }, {
		Name = "Page", Position = UDim2.fromOffset(72, 160), Size = UDim2.new(0.62, -72, 1, -208), ZIndex = 4,
	})

	-- Pilot strip: rank and XP bar on the left, credits on the right.
	local rankLabel = Components.label(page, "", { font = "Header", size = UIStyle.TextSize.Small }, {
		Position = UDim2.fromOffset(56, 22), Size = UDim2.new(0.6, -56, 0, 20), ZIndex = 5,
	})
	local track = Components.slab(page, { color = UIStyle.Paper, transparency = 0.85, slant = false }, {
		Position = UDim2.fromOffset(56, 50), Size = UDim2.new(0.6, -56, 0, 6), ZIndex = 5,
	})
	local xpFill = Components.slab(track, { color = UIStyle.Accent, slant = false }, { Size = UDim2.fromScale(0, 1), ZIndex = 6 })
	local xpLabel = Components.label(page, "", { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(56, 60), Size = UDim2.new(0.6, -56, 0, 16), ZIndex = 5,
	})
	Components.label(page, "CREDITS", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 18), Size = UDim2.fromOffset(220, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
	})
	local creditsLabel = Components.label(page, "0 CR", { font = "Mono", size = UIStyle.TextSize.Title, color = UIStyle.Accent }, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 36), Size = UDim2.fromOffset(260, 36), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
	})
	Components.slab(page, { color = UIStyle.Accent, transparency = 0.5, slant = false }, {
		Position = UDim2.fromOffset(56, 90), Size = UDim2.new(1, -112, 0, 2), ZIndex = 5,
	})

	-- The list (scrolls on short screens) with its pointer.
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(40, 108)
	list.Size = UDim2.new(0.46, -40, 1, -132)
	list.CanvasSize = UDim2.fromOffset(0, #Upgrades.List * (ROW + GAP))
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UIStyle.Accent
	list.ZIndex = 5
	list.Parent = page
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.BackgroundColor3 = UIStyle.Accent
	pointer.BorderSizePixel = 0
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Size = UDim2.fromOffset(12, 12)
	pointer.Rotation = 45
	pointer.Position = UDim2.fromOffset(8, ROW / 2)
	pointer.ZIndex = 7
	pointer.Parent = list

	-- The detail panel.
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.new(0.46, 24, 0, 108)
	detail.Size = UDim2.new(0.54, -80, 1, -132)
	detail.ZIndex = 5
	detail.ClipsDescendants = false
	detail.Parent = page
	local nameLabel = Components.label(detail, "", { font = "Header", size = UIStyle.TextSize.Large }, { Size = UDim2.new(1, 0, 0, 30), ZIndex = 6 })
	local costChip, costText = chip(detail, { Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(110, 24), ZIndex = 6 })
	local rankChip, rankText = chip(detail, { Position = UDim2.fromOffset(118, 40), Size = UDim2.fromOffset(96, 24), ZIndex = 6 })
	local descLabel = Components.label(detail, "", { size = UIStyle.TextSize.Body, wrap = true, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 52), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6,
	})
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromOffset(0, 136)
	stats.Size = UDim2.new(1, 0, 0, 90)
	stats.ZIndex = 6
	stats.Parent = detail
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 4)
	statsLayout.Parent = stats
	local message = Components.label(detail, "", { font = "Header", size = UIStyle.TextSize.Tiny, color = UIStyle.Danger }, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 18), ZIndex = 6,
	})
	local selectedId = Upgrades.List[1].id
	local buy
	buy = Components.button(detail, "BUY", function()
		if not buy:GetAttribute("Disabled") then
			callbacks.onBuy(selectedId)
		end
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 48), ZIndex = 6 })
	local stamp = Components.title(detail, "INSTALLED", {
		Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(340, 62), Visible = false, ZIndex = 9,
	}, { size = UIStyle.TextSize.Title, width = 340 })
	local stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	local rows = {}
	local current = { rank = 1, xp = 0, credits = 0, upgrades = {} }
	local shownCredits = 0

	local function setBuyOpen(open, text)
		Components.setText(buy, text)
		buy:SetAttribute("Disabled", not open)
		buy.Active, buy.Selectable = open, open
		buy.Label.TextColor3 = if open then UIStyle.Ink else UIStyle.Paper
		buy.Label.TextTransparency = if open then 0 else 0.45
		buy.Label:SetAttribute("Shown", buy.Label.TextTransparency) -- what the menu's entrance fades the text to
		Components.paint(buy.Fill, UIStyle.Paper, if open then 0 else 0.82)
		buy.Shadow.Visible = false
	end

	local function showDetail()
		local upgrade = Upgrades.ById[selectedId]
		nameLabel.Text = string.upper(upgrade.name)
		costText.Text = ("%d CR"):format(upgrade.cost)
		rankText.Text = ("RANK %d"):format(upgrade.rankRequired)
		local rankMet = current.rank >= upgrade.rankRequired
		Components.paint(costChip, UIStyle.Accent)
		costText.TextColor3 = UIStyle.Ink
		Components.paint(rankChip, if rankMet then UIStyle.Paper else UIStyle.Danger)
		rankText.TextColor3 = if rankMet then UIStyle.Ink else UIStyle.Paper
		descLabel.Text = upgrade.desc
		for _, child in ipairs(stats:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		-- before = without this upgrade, after = with it (on top of what the pilot owns).
		local without, with = table.clone(current.upgrades), table.clone(current.upgrades)
		without[upgrade.id], with[upgrade.id] = nil, true
		local before, after = EffectiveConfig.build(without), EffectiveConfig.build(with)
		for index, modifier in ipairs(upgrade.modifiers) do
			local unit = modifier.unit or ""
			local from = EffectiveConfig.valueAt(before, modifier.path)
			local to = EffectiveConfig.valueAt(after, modifier.path)
			Components.label(stats, ("%-22s %s%s  →  %s%s"):format(modifier.label, number(from), unit, number(to), unit), { font = "Mono", size = UIStyle.TextSize.Small, color = UIStyle.TextPrimary }, {
				Size = UDim2.new(1, 0, 0, 20), LayoutOrder = index, ZIndex = 6,
			})
		end
		local status, _, _, open = statusOf(upgrade, current)
		setBuyOpen(open, if open then ("BUY — %d CR"):format(upgrade.cost) elseif status == "INSTALLED" then "INSTALLED" elseif current.rank < upgrade.rankRequired then ("RANK %d REQUIRED"):format(upgrade.rankRequired) else "NOT ENOUGH CREDITS")
	end

	local function select(id)
		if selectedId ~= id then
			message.Text = ""
		end
		selectedId = id
		for index, upgrade in ipairs(Upgrades.List) do
			if upgrade.id == id then
				quick(pointer, 0.25, { Position = UDim2.fromOffset(8, (index - 1) * (ROW + GAP) + ROW / 2) }, Enum.EasingStyle.Back)
			end
		end
		showDetail()
	end

	for index, upgrade in ipairs(Upgrades.List) do
		local row = Components.button(list, "", function()
			select(upgrade.id)
		end, { Name = upgrade.id, Position = UDim2.fromOffset(24, (index - 1) * (ROW + GAP)), Size = UDim2.new(1, -36, 0, ROW), ZIndex = 5 })
		row.SelectionGained:Connect(function()
			select(upgrade.id)
		end)
		Components.label(row, string.upper(upgrade.name), { font = "Header", size = UIStyle.TextSize.Small, color = UIStyle.Ink }, {
			Name = "Title", Position = UDim2.fromOffset(40, 8), Size = UDim2.new(1, -150, 0, 22), ZIndex = 4,
		})
		Components.label(row, ("%d CR"):format(upgrade.cost), { font = "Mono", size = UIStyle.TextSize.Small, color = UIStyle.Ink }, {
			Name = "Cost", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 8), Size = UDim2.fromOffset(100, 22), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
		})
		local status, text = chip(row, { Name = "Status", Position = UDim2.fromOffset(40, 34), Size = UDim2.fromOffset(150, 22), ZIndex = 4 })
		rows[upgrade.id] = { button = row, chip = status, text = text }
	end

	local screen = { frame = frame, first = rows[Upgrades.List[1].id].button }

	function screen.refresh(state, animateCredits)
		current = { rank = state.rank or 1, xp = state.xp or 0, credits = state.credits or 0, upgrades = state.upgrades or {} }
		local held, nextRank = Progression.rankAt(current.xp)
		rankLabel.Text = ("%s — RANK %d"):format(string.upper(held.name), held.rank)
		local fill = if nextRank then (current.xp - held.xp) / (nextRank.xp - held.xp) else 1
		quick(xpFill, 0.6, { Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1) })
		xpLabel.Text = if nextRank then ("%d / %d XP  ·  NEXT: %s"):format(current.xp, nextRank.xp, string.upper(nextRank.name)) else ("%d XP  ·  TOP RANK"):format(current.xp)
		if animateCredits then
			countTo(creditsLabel, shownCredits, current.credits, 0.7, "%d CR")
		elseif current.credits ~= shownCredits or creditsLabel:GetAttribute("CountToken") == nil then
			creditsLabel:SetAttribute("CountToken", nil)
			creditsLabel.Text = ("%d CR"):format(current.credits)
		end
		shownCredits = current.credits
		for _, upgrade in ipairs(Upgrades.List) do
			local row = rows[upgrade.id]
			local label, color, textColor = statusOf(upgrade, current)
			row.text.Text = label
			row.text.TextColor3 = textColor
			Components.paint(row.chip, color)
		end
		showDetail()
	end

	function screen.result(result, state)
		if result.ok then
			message.Text = ""
			screen.refresh(state, true)
			local row = rows[result.upgradeId]
			if row then
				-- The row's chip flashes paper, then settles on amber.
				Components.paint(row.chip, UIStyle.Paper)
				task.delay(0.12, function()
					Components.tweenPaint(row.chip, TweenInfo.new(0.35), UIStyle.Accent)
				end)
			end
			stamp.Visible = true
			stamp.Rotation = -8
			stampScale.Scale = 1.7
			quick(stampScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(1.4, function()
				quick(stampScale, 0.18, { Scale = 0.6 })
				task.delay(0.18, function()
					stamp.Visible = false
				end)
			end)
		else
			local upgrade = Upgrades.ById[result.upgradeId]
			local reason = REASONS[result.reason] or "NOT AVAILABLE"
			message.Text = if result.reason == "Rank" and upgrade then reason:format(upgrade.rankRequired) else reason
			-- BUY twitches sideways.
			local home = buy.Position
			task.spawn(function()
				for _, dx in ipairs({ 10, -8, 6, -4, 0 }) do
					buy.Position = home + UDim2.fromOffset(dx, 0)
					task.wait(0.04)
				end
				buy.Position = home
			end)
		end
	end

	screen.select = select
	screen.getSelected = function()
		return selectedId
	end
	select(selectedId)
	return screen
end

return EquipmentScreen
