--!nonstrict
-- Client/UI/BoundsWarning.lua  (docs/12_combat_system.md §9; docs/14_ui.md §1)
--
-- The Frame HUD's out-of-bounds warning, "RETURN TO THE MISSION AREA": a slab that drops in and unfolds sideways,
-- a hazard band scrolling across its top edge, a pulsing title, and a bar that drains to the moment the server
-- sends the Frame back. Hides by folding shut.
--
--   local warning = BoundsWarning.new(parent, opts)       opts: animated, reduceFlashing() -> boolean
--   warning.set(secondsLeft, total)                       every frame; secondsLeft = nil hides it
--   warning.isShown() -> boolean

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)
local Components = require(script.Parent.Components)

local BoundsWarning = {}

local SIZE = Vector2.new(560, 92)
local STRIPE = { width = 16, pitch = 34, speed = 40, height = 8 } -- px, px, px per second
local PULSE = 2.2 -- title pulses per second

function BoundsWarning.new(parent, opts)
	opts = opts or {}
	local animated = opts.animated ~= false
	local reduceFlashing = opts.reduceFlashing or function()
		return false
	end

	local holder = Instance.new("Frame")
	holder.Name = "BoundsWarning"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.18, 0)
	holder.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)
	holder.Visible = false
	holder.Parent = parent

	-- The body unfolds from the middle; the shadow slab sits behind it, offset like every highlighted element.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.ClipsDescendants = true
	body.Parent = holder
	local shadow = Components.slab(holder, { color = UIStyle.Danger, transparency = 0.55 }, {
		Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, UIStyle.Shadow.X, 0.5, UIStyle.Shadow.Y),
		Size = UDim2.fromScale(1, 1), ZIndex = 0,
	})
	Components.slab(body, { color = UIStyle.Ink, transparency = 0.06 }, { Name = "Fill", Size = UDim2.fromScale(1, 1) })

	-- Hazard band along the top edge: leaning red bars on ink, scrolling sideways.
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundTransparency = 1
	band.ClipsDescendants = true
	band.Position = UDim2.fromOffset(26, 6)
	band.Size = UDim2.new(1, -52, 0, STRIPE.height)
	band.Parent = body
	local stripes = {}
	local count = math.ceil((SIZE.X - 52) / STRIPE.pitch) + 2
	for index = 1, count do
		stripes[index] = Components.slab(band, { color = UIStyle.Danger, slant = 40 }, {
			Name = "Stripe" .. index, Size = UDim2.fromOffset(STRIPE.width, STRIPE.height),
		})
	end

	local title = Components.label(body, "RETURN TO THE MISSION AREA", { font = "Header", size = UIStyle.TextSize.Large, color = UIStyle.Danger }, {
		Name = "Title", Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	local detail = Components.label(body, "", { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.TextSecondary }, {
		Name = "Detail", Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	-- Markers either side of the title.
	for side = 0, 1 do
		Components.slab(body, { color = UIStyle.Danger, slant = false }, {
			Name = "Marker" .. side, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = UDim2.new(side, if side == 0 then 30 else -30, 0, 35), Size = UDim2.fromOffset(9, 9), ZIndex = 2,
		})
	end
	local barBack = Components.slab(body, { color = UIStyle.Danger, transparency = 0.8, slant = false }, {
		Name = "BarBack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.new(1, -96, 0, 4), ZIndex = 2,
	})
	local barFill = Components.slab(barBack, { color = UIStyle.Danger, slant = false }, { Name = "BarFill", Size = UDim2.fromScale(1, 1), ZIndex = 3 })

	local shown = false
	local token = 0
	local started = os.clock()

	local function show()
		shown = true
		token += 1
		started = os.clock()
		holder.Visible = true
		if animated then
			-- Drops in, unfolds from a sliver, the title types its weight in.
			holder.Position = UDim2.new(0.5, 0, 0.18, -18)
			body.Size = UDim2.fromScale(0.04, 1)
			shadow.Size = UDim2.fromScale(0.04, 1)
			title.TextTransparency = 1
			TweenService:Create(holder, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Position = UDim2.new(0.5, 0, 0.18, 0) }):Play()
			local unfold = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			TweenService:Create(body, unfold, { Size = UDim2.fromScale(1, 1) }):Play()
			TweenService:Create(shadow, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
			TweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12), { TextTransparency = 0 }):Play()
		else
			body.Size, shadow.Size, title.TextTransparency = UDim2.fromScale(1, 1), UDim2.fromScale(1, 1), 0
		end
	end

	local function hide()
		shown = false
		token += 1
		local mine = token
		if not animated then
			holder.Visible = false
			return
		end
		local fold = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(body, fold, { Size = UDim2.fromScale(0.02, 1) }):Play()
		TweenService:Create(shadow, fold, { Size = UDim2.fromScale(0.02, 1) }):Play()
		task.delay(0.18, function()
			if token == mine then
				holder.Visible = false
			end
		end)
	end

	local function set(left, total)
		if left == nil then
			if shown then
				hide()
			end
			return
		end
		if not shown then
			show()
		end
		left = math.max(0, left)
		local fraction = if total and total > 0 then math.clamp(left / total, 0, 1) else 0
		barFill.Size = UDim2.fromScale(fraction, 1)
		detail.Text = string.format("OVERWATCH RECALL IN %.1f S  //  TURN BACK", left)
		local t = os.clock() - started
		-- The band scrolls; the title and markers pulse between danger red and paper (steady with reduce flashing).
		local offset = (t * STRIPE.speed) % STRIPE.pitch
		for index, stripe in ipairs(stripes) do
			stripe.Position = UDim2.fromOffset((index - 2) * STRIPE.pitch + offset, 0)
		end
		local glow = if reduceFlashing() or not animated then 0 else (0.5 + 0.5 * math.sin(t * math.pi * 2 * PULSE)) * 0.55
		title.TextColor3 = UIStyle.Danger:Lerp(UIStyle.Paper, glow)
	end

	return {
		holder = holder,
		set = set,
		isShown = function()
			return shown
		end,
	}
end

return BoundsWarning
