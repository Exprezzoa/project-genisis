--!nonstrict
-- Client/Controllers/WaypointController.lua  (docs/14_ui.md §3 "Waypoint marker"; docs/13 §1.1 `waypoint`)
--
-- The markers of the current step's waypoints: an amber diamond on the spot with the distance in meters under
-- it; while the spot is off screen the marker sits on the screen's edge with an arrow pointing toward it. The
-- positions come from the server in Seq_State. Drawn in screen space (docs/14 names a BillboardGui, but a
-- billboard can't be held at the screen's edge).
--
--   set(positions)        getState() -> { count, markers = { { onScreen, meters } } }      -- for tests

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)
local Net = require(Shared.Modules.Net)

local FrameController = require(script.Parent.FrameController)

local WaypointController = {}

local METERS_PER_STUD = 0.33 -- CLAUDE.md §7
local EDGE = 70 -- pixels the marker keeps from the screen's edge
local DIAMOND = 26
local ARRIVED = 12 -- studs: this close the marker fades, so it doesn't sit in the player's face

local player = Players.LocalPlayer
local gui
local markers = {} -- { position, holder, diamond, arrow, label, scale, onScreen, meters }
local animated = RunService:IsRunning()

local function build(position)
	local holder = Instance.new("Frame")
	holder.Name = "Waypoint"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(120, 80)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local group = Instance.new("CanvasGroup") -- one transparency for the whole marker
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = holder
	-- The diamond: four amber bars as a square turned 45 degrees, with a small filled core.
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.BackgroundTransparency = 1
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(0.5, 0, 0, 30)
	diamond.Size = UDim2.fromOffset(DIAMOND, DIAMOND)
	diamond.Rotation = 45
	diamond.Parent = group
	for _, side in ipairs({
		{ Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 3) }, { Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 3) },
		{ Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(0, 3, 1, 0) }, { Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0, 3, 1, 0) },
	}) do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = UIStyle.Accent
		bar.AnchorPoint, bar.Position, bar.Size = side[1], side[2], side[3]
		bar.Parent = diamond
	end
	local core = Instance.new("Frame")
	core.Name = "Core"
	core.BorderSizePixel = 0
	core.BackgroundColor3 = UIStyle.Accent
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(8, 8)
	core.Parent = diamond
	-- The arrow shown at the screen's edge: a chevron of two bars, turned toward the spot.
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0, 30)
	arrow.Size = UDim2.fromOffset(64, 64)
	arrow.Visible = false
	arrow.Parent = group
	for _, turn in ipairs({ -40, 40 }) do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = UIStyle.Accent
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, 0)
		bar.Size = UDim2.fromOffset(3, 14)
		bar.Rotation = turn
		bar.Parent = arrow
	end
	local label = Instance.new("TextLabel")
	label.Name = "Distance"
	label.BackgroundTransparency = 1
	label.FontFace = UIStyle.Font.Mono
	label.TextSize = 14
	label.TextColor3 = UIStyle.TextPrimary
	label.TextStrokeColor3 = UIStyle.Ink
	label.TextStrokeTransparency = 0.4
	label.Position = UDim2.new(0, 0, 0, 54)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Text = ""
	label.Parent = group
	if animated then
		-- Drops onto its spot: large and faint to its size, then the diamond keeps breathing.
		scale.Scale = 2.4
		group.GroupTransparency = 1
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
		TweenService:Create(core, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(14, 14) }):Play()
	end
	return { position = position, holder = holder, group = group, diamond = diamond, arrow = arrow, label = label, onScreen = false, meters = 0 }
end

function WaypointController.set(positions)
	-- Keep the markers whose spots stay; drop and add the rest.
	local kept = {}
	for _, marker in ipairs(markers) do
		local stays = false
		for index, position in ipairs(positions) do
			if (position - marker.position).Magnitude < 0.5 then
				stays = true
				table.remove(positions, index)
				break
			end
		end
		if stays then
			table.insert(kept, marker)
		else
			marker.holder:Destroy()
		end
	end
	markers = kept
	for _, position in ipairs(positions) do
		table.insert(markers, build(position))
	end
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera or #markers == 0 then
		return
	end
	local frame = FrameController.getFrame()
	local character = player.Character
	local body = if frame then frame.PrimaryPart else (character and character:FindFirstChild("HumanoidRootPart"))
	local viewport = camera.ViewportSize
	local center = viewport / 2
	local half = center - Vector2.new(EDGE, EDGE)
	for _, marker in ipairs(markers) do
		local point, visible = camera:WorldToViewportPoint(marker.position)
		local at = Vector2.new(point.X, point.Y)
		local inside = visible and math.abs(at.X - center.X) <= half.X and math.abs(at.Y - center.Y) <= half.Y
		if not inside then
			-- Off screen (or behind the camera): onto the edge, along the direction to the spot.
			local dir = at - center
			if point.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, 1)
			end
			local reach = math.min(half.X / math.max(math.abs(dir.X), 1e-3), half.Y / math.max(math.abs(dir.Y), 1e-3))
			at = center + dir * reach
			marker.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
		end
		marker.onScreen = inside
		marker.arrow.Visible = not inside
		marker.diamond.Visible = inside
		marker.holder.Position = UDim2.fromOffset(at.X, at.Y - 10)
		local distance = if body then ((body.Position - marker.position) * Vector3.new(1, 0, 1)).Magnitude else 0
		marker.meters = math.floor(distance * METERS_PER_STUD + 0.5)
		marker.label.Text = marker.meters .. " m"
		if not animated or marker.holder:FindFirstChildOfClass("UIScale").Scale <= 1.01 then
			marker.group.GroupTransparency = if distance < ARRIVED then 0.75 else 0
		end
	end
end

function WaypointController.getState()
	local list = {}
	for _, marker in ipairs(markers) do
		table.insert(list, { onScreen = marker.onScreen, meters = marker.meters })
	end
	return { count = #markers, markers = list }
end

function WaypointController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "PG_Waypoints"
	gui.IgnoreGuiInset = true -- screen space = the camera's viewport
	gui.ResetOnSpawn = false
	gui.DisplayOrder = UIStyle.DisplayOrder.HUD - 1
	gui.Parent = player:WaitForChild("PlayerGui")
end

function WaypointController.Start()
	Net.on("Seq_State", function(payload)
		local positions = {}
		for _, position in ipairs(if type(payload.waypoints) == "table" then payload.waypoints else {}) do
			if typeof(position) == "Vector3" then
				table.insert(positions, position)
			end
		end
		WaypointController.set(positions)
	end)
	RunService:BindToRenderStep("PG_Waypoints", Enum.RenderPriority.Camera.Value + 2, update)
end

return WaypointController
