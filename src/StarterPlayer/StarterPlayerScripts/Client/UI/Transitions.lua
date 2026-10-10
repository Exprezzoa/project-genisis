--!nonstrict
-- Client/UI/Transitions.lua  (docs/14_ui.md §1.3)
--
-- Screen transitions shared by every UI, built from plain Frames.
--
--   wipe(parent, opts)       -- diagonal bars sweep across parent (a full-screen frame) and remove themselves
--                               opts: colors { Color3 }, time (s), reverse (left to right), zIndex
--   slideIn(gui, from, time) -- gui eases from its position + from (UDim2) back to its position

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Transitions = {}

Transitions.WIPE_TIME = 0.5
Transitions.WIPE_STAGGER = 0.07

function Transitions.wipe(parent, opts)
	opts = opts or {}
	local colors = opts.colors or { UIStyle.Paper, UIStyle.Accent, UIStyle.Ink }
	local from, to = 1.5, -0.5 -- right to left, like the lean of the slabs
	if opts.reverse then
		from, to = to, from
	end
	for index, color in ipairs(colors) do
		local bar = Instance.new("Frame")
		bar.Name = "Wipe"
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(from, 0.5)
		bar.Size = UDim2.fromScale(0.36 - 0.09 * (index - 1), 3) -- each bar is narrower than the one before
		bar.Rotation = UIStyle.Slant
		bar.ZIndex = opts.zIndex or 50
		bar.Parent = parent
		local info = TweenInfo.new(opts.time or Transitions.WIPE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, Transitions.WIPE_STAGGER * (index - 1))
		local tween = TweenService:Create(bar, info, { Position = UDim2.fromScale(to, 0.5) })
		tween.Completed:Connect(function()
			bar:Destroy()
		end)
		tween:Play()
	end
end

function Transitions.slideIn(gui, from, time)
	local home = gui:GetAttribute("Home") or gui.Position
	gui:SetAttribute("Home", home)
	gui.Position = home + from
	TweenService:Create(gui, TweenInfo.new(time or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = home }):Play()
end

return Transitions
