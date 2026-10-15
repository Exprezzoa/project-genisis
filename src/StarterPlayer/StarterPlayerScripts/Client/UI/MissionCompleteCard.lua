--!nonstrict
-- Client/UI/MissionCompleteCard.lua  (docs/14_ui.md §9 "Mission Complete"; docs/05 S40, §10)
--
-- A 640 × 420 panel over the dimmed game: MISSION COMPLETE (Michroma 28, amber) and the mission's name (Michroma 18),
-- the rewards counting up row by row (XP and credits; CLEAN KILL only when earned), the totals, the pilot's rank bar
-- filling with the rank's name, and Continue. It stays until Continue (click, Enter / Space, or A).
--
--   MissionCompleteCard.show(parent, data, onContinue) -> close()
--   data = { mission, rows = { { label, xp, credits } }, xp, credits, rank = { name, rank, from, to, fill } }

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Components)

local MissionCompleteCard = {}

local SIZE = Vector2.new(640, 420)
local ROW = 34
local CONTINUE_ACTION = "PG_CardContinue"

local function countUp(label, target, seconds, format)
	local started = os.clock()
	task.spawn(function()
		while label.Parent do
			local t = math.clamp((os.clock() - started) / seconds, 0, 1)
			label.Text = format:format(math.floor(target * (1 - (1 - t) ^ 3) + 0.5))
			if t >= 1 then
				break
			end
			task.wait()
		end
	end)
end

function MissionCompleteCard.show(parent, data, onContinue)
	local dim = Instance.new("Frame")
	dim.Name = "MissionComplete"
	dim.BackgroundColor3 = UIStyle.Ink
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 20
	dim.Parent = parent
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()

	local panel = Components.panel(dim, { solid = true, padding = 24, slant = 6 }, {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(SIZE.X, SIZE.Y), ZIndex = 21,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = panel
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	TweenService:Create(scale, TweenInfo.new(UIStyle.Pop.Time + 0.1, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Scale = 1 }):Play()

	Components.label(panel, "MISSION COMPLETE", { font = "Header", size = 28, color = UIStyle.Accent }, {
		Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 36), ZIndex = 22,
	})
	Components.label(panel, data.mission or "", { font = "Header", size = 18, color = UIStyle.TextPrimary }, {
		Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 24), ZIndex = 22,
	})
	Components.slab(panel, { color = UIStyle.Accent, transparency = 0.5, slant = false }, {
		Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 2), ZIndex = 22,
	})
	-- Headers of the two value columns.
	for _, column in ipairs({ { "XP", 360 }, { "CREDITS", 470 } }) do
		Components.label(panel, column[1], { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
			Position = UDim2.fromOffset(column[2], 82), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22,
		})
	end

	local rows = data.rows or {}
	local y = 104
	for index, row in ipairs(rows) do
		local delay = 0.35 + (index - 1) * 0.35
		local label = Components.label(panel, row.label, { font = "BodyBold", size = 18 }, {
			Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(330, ROW - 6), TextTransparency = 1, ZIndex = 22,
		})
		local xp = Components.label(panel, "", { font = "Mono", size = 18, color = UIStyle.Accent }, {
			Position = UDim2.fromOffset(360, y), Size = UDim2.fromOffset(100, ROW - 6), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22,
		})
		local credits = Components.label(panel, "", { font = "Mono", size = 18, color = UIStyle.TextPrimary }, {
			Position = UDim2.fromOffset(470, y), Size = UDim2.fromOffset(100, ROW - 6), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22,
		})
		task.delay(delay, function()
			if not label.Parent then
				return
			end
			TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
			countUp(xp, row.xp or 0, 0.4, "+%d")
			countUp(credits, row.credits or 0, 0.4, "+%d")
		end)
		y += ROW
	end
	local totalsAt = 0.35 + #rows * 0.35
	Components.slab(panel, { color = UIStyle.Paper, transparency = 0.8, slant = false }, {
		Position = UDim2.fromOffset(0, y + 2), Size = UDim2.new(1, 0, 0, 1), ZIndex = 22,
	})
	local totalLabel = Components.label(panel, "TOTAL", { font = "Header", size = 16, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(0, y + 10), Size = UDim2.fromOffset(330, 24), ZIndex = 22,
	})
	local totalXp = Components.label(panel, "", { font = "Mono", size = 20, color = UIStyle.Accent }, {
		Position = UDim2.fromOffset(360, y + 8), Size = UDim2.fromOffset(100, 26), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22,
	})
	local totalCredits = Components.label(panel, "", { font = "Mono", size = 20 }, {
		Position = UDim2.fromOffset(470, y + 8), Size = UDim2.fromOffset(100, 26), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22,
	})
	totalLabel.TextTransparency = 1
	task.delay(totalsAt, function()
		if totalLabel.Parent then
			totalLabel.TextTransparency = 0
			countUp(totalXp, data.xp or 0, 0.6, "%d")
			countUp(totalCredits, data.credits or 0, 0.6, "%d")
		end
	end)

	-- The rank bar fills to where this chapter leaves the pilot.
	local rank = data.rank or {}
	local rankName = Components.label(panel, ("%s — RANK %d"):format(string.upper(rank.name or ""), rank.rank or 1), { font = "Header", size = 14, color = UIStyle.TextPrimary }, {
		Position = UDim2.fromOffset(0, SIZE.Y - 128), Size = UDim2.new(1, 0, 0, 20), ZIndex = 22,
	})
	local track = Components.slab(panel, { color = UIStyle.Paper, transparency = 0.85, slant = false }, {
		Position = UDim2.fromOffset(0, SIZE.Y - 102), Size = UDim2.new(1, 0, 0, 8), ZIndex = 22,
	})
	local fill = Components.slab(track, { color = UIStyle.Accent, slant = false }, { Size = UDim2.fromScale(0, 1), ZIndex = 23 })
	rankName.TextTransparency = 1
	task.delay(totalsAt + 0.5, function()
		if fill.Parent then
			rankName.TextTransparency = 0
			TweenService:Create(fill, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(rank.fill or 0, 0, 1), 1) }):Play()
		end
	end)

	local closed = false
	local button
	local function close()
		if closed then
			return
		end
		closed = true
		ContextActionService:UnbindAction(CONTINUE_ACTION)
		if GuiService.SelectedObject == button then
			GuiService.SelectedObject = nil
		end
		local out = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(dim, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(scale, out, { Scale = 0.94 }):Play()
		task.delay(0.21, function()
			dim:Destroy()
		end)
		onContinue()
	end
	button = Components.button(panel, "Continue", close, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(200, 48), ZIndex = 22,
	})
	-- Continue is offered once the numbers are in; Enter, Space or A press it, and a gamepad has it selected.
	button.Visible = false
	task.delay(totalsAt + 0.9, function()
		if closed then
			return
		end
		button.Visible = true
		Components.enter(button)
		GuiService.SelectedObject = button
		ContextActionService:BindAction(CONTINUE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end)
	return close
end

return MissionCompleteCard
