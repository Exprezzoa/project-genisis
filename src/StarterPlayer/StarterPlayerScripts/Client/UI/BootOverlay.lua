--!nonstrict
-- Client/UI/BootOverlay.lua  (docs/05_chapter1_script.md S08 "Cockpit boot overlay")
--
-- 2.5 s of amber RobotoMono typed in at the center of the screen on a Frame's first boarding, before its HUD comes
-- up: VANGUARD // UNIT 02 → CORE SYNC ........ 98.2% → INHIBITOR LATTICE . NOMINAL → PILOT: VEYNE, E. → ONLINE
-- (the script's lines). Corner brackets draw in around it, a thin bar under CORE SYNC fills to 98.2%, ONLINE
-- blinks twice, then it all fades.
--
--   BootOverlay.play(parent, unit?)      yields until it is gone

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Components)

local BootOverlay = {}

local SECONDS = 2.5
local LINE_HEIGHT = 30
local WIDTH = 460
local CORNER = 16
local TYPE_RATE = 70 -- characters per second
local SYNC = 0.982

local function lines(unit)
	return {
		("VANGUARD // UNIT %s"):format(unit or "02"),
		"CORE SYNC ........ 98.2%",
		"INHIBITOR LATTICE . NOMINAL",
		"PILOT: VEYNE, E.",
		"ONLINE",
	}
end

function BootOverlay.play(parent, unit)
	local started = os.clock()
	local texts = lines(unit)
	local group = Instance.new("CanvasGroup")
	group.Name = "BootOverlay"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.45)
	group.Size = UDim2.fromOffset(WIDTH, #texts * LINE_HEIGHT + 36)
	group.Parent = parent
	local labels = {}
	for index in ipairs(texts) do
		labels[index] = Components.label(group, "", { font = "Mono", size = if index == #texts then 24 else 20, color = UIStyle.Accent }, {
			Position = UDim2.fromOffset(24, 18 + (index - 1) * LINE_HEIGHT), Size = UDim2.new(1, -48, 0, LINE_HEIGHT - 4), ZIndex = 2,
		})
	end
	local syncTrack = Components.slab(group, { color = UIStyle.Accent, transparency = 0.8, slant = false }, {
		Position = UDim2.fromOffset(24, 18 + 2 * LINE_HEIGHT - 4), Size = UDim2.new(1, -48, 0, 2), Visible = false,
	})
	local syncFill = Components.slab(syncTrack, { color = UIStyle.Accent, slant = false }, { Size = UDim2.fromScale(0, 1) })
	for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local anchor = Vector2.new(corner[1], corner[2])
		local h = Components.slab(group, { color = UIStyle.Accent, transparency = 0.3, slant = false }, {
			AnchorPoint = anchor, Position = UDim2.fromScale(corner[1], corner[2]), Size = UDim2.fromOffset(0, 2),
		})
		local v = Components.slab(group, { color = UIStyle.Accent, transparency = 0.3, slant = false }, {
			AnchorPoint = anchor, Position = UDim2.fromScale(corner[1], corner[2]), Size = UDim2.fromOffset(2, 0),
		})
		local draw = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(h, draw, { Size = UDim2.fromOffset(CORNER, 2) }):Play()
		TweenService:Create(v, draw, { Size = UDim2.fromOffset(2, CORNER) }):Play()
	end

	-- Typewriter, line by line; the sync bar fills while its line types.
	for index, text in ipairs(texts) do
		if index == 2 then
			syncTrack.Visible = true
			TweenService:Create(syncFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(SYNC, 1) }):Play()
		end
		for count = 1, #text do
			labels[index].Text = string.sub(text, 1, count) .. "_"
			task.wait(1 / TYPE_RATE)
		end
		labels[index].Text = text
		task.wait(0.06)
	end
	local online = labels[#texts]
	for _ = 1, 2 do
		online.TextTransparency = 0.7
		task.wait(0.08)
		online.TextTransparency = 0
		task.wait(0.08)
	end
	task.wait(math.max(0, SECONDS - 0.25 - (os.clock() - started)))
	local fade = TweenService:Create(group, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	group:Destroy()
end

return BootOverlay
