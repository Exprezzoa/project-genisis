--!nonstrict
-- Client/Cinematics/Message.lua  (docs/05_chapter1_script.md S43 "The message")
--
-- The client half of S43, run by CinematicController for CIN_MESSAGE:
--   the full-screen terminal (RobotoMono amber on #0B0E10, scanlines from a repeating gradient) types the message
--   at 45 characters/s; the last line at 15/s in white; it holds 3.0 s and flickers twice; then, letterboxed, a slow
--   push from behind Elias over his shoulder to his father's photo (4 s), no words; then black over 2 s. It ends
--   behind black and the server shows the Chapter End card.
--
--   Message.run(ctx)   ctx = { alive() -> boolean, takeCamera(), focus(pos, look) }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local Controllers = script.Parent.Parent.Controllers
local DialogueController = require(Controllers.DialogueController)
local UIController = require(Controllers.UIController)

local Message = {}

local TYPE_RATE, LAST_RATE = 45, 15 -- characters per second
local HOLD = 3.0
local PUSH = 4.0
local BACKGROUND = Color3.fromHex("#0B0E10")
local LINES = {
	"MESSAGE RECEIVED  23:47",
	"FROM:  —",
	"ATTACHMENT: spindle_frag_0071.dat (PARTIAL)",
	"------------------------------------------------",
	"[ IMAGE DATA CORRUPTED ]",
	"SUBJECT T-V // ECHO-9 // TRANSFER LOG",
	"DATE: 2181-10-14   ORIGIN: KESSLER BASIN",
	"------------------------------------------------",
	"",
}
local LAST = "Your father did not die where they told you he died."

local function wait(ctx, seconds): boolean
	local done = os.clock() + seconds
	while os.clock() < done do
		if not ctx.alive() then
			return false
		end
		task.wait()
	end
	return ctx.alive()
end

local function typeInto(ctx, label, text, rate): boolean
	for count = 1, utf8.len(text) or #text do
		if not ctx.alive() then
			return false
		end
		local cut = utf8.offset(text, count + 1)
		label.Text = (if cut then string.sub(text, 1, cut - 1) else text) .. "_"
		task.wait(1 / rate)
	end
	label.Text = text
	return true
end

local function buildTerminal(layer)
	local screen = Instance.new("Frame")
	screen.Name = "Terminal"
	screen.BackgroundColor3 = BACKGROUND
	screen.BorderSizePixel = 0
	screen.Size = UDim2.fromScale(1, 1)
	screen.ZIndex = 30
	screen.Parent = layer
	-- Scanlines: a gradient of thin dark bands repeated down the screen.
	for index = 0, 59 do
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = Color3.new(0, 0, 0)
		band.BackgroundTransparency = 0.55
		band.Position = UDim2.fromScale(0, index / 60)
		band.Size = UDim2.new(1, 0, 1 / 120, 0)
		band.ZIndex = 33
		band.Parent = screen
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
		gradient.Parent = band
	end
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.48)
	column.Size = UDim2.fromOffset(760, 440)
	column.ZIndex = 31
	column.Parent = screen
	local labels = {}
	for index = 1, #LINES + 1 do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.FontFace = UIStyle.Font.Mono
		label.TextSize = 20
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if index > #LINES then UIStyle.Paper else UIStyle.Accent
		label.Position = UDim2.fromOffset(0, (index - 1) * 30 + (if index > #LINES then 18 else 0))
		label.Size = UDim2.new(1, 0, 0, 28)
		label.Text = ""
		label.ZIndex = 32
		label.Parent = column
		labels[index] = label
	end
	return screen, labels
end

function Message.run(ctx)
	local layer = UIController.getLayer("Cards")
	local screen, labels = buildTerminal(layer)
	local function finally()
		if screen.Parent then
			screen:Destroy()
		end
		if not ctx.alive() then
			DialogueController.letterbox("message", false) -- an interrupted push lets the bars go
		end
	end
	for index, text in ipairs(LINES) do
		if text ~= "" and not typeInto(ctx, labels[index], text, TYPE_RATE) then
			return finally()
		end
	end
	if not typeInto(ctx, labels[#labels], LAST, LAST_RATE) then
		return finally()
	end
	if not wait(ctx, HOLD) then
		return finally()
	end
	-- Two flickers, then the room.
	for _ = 1, 2 do
		screen.BackgroundTransparency = 0.6
		for _, label in ipairs(labels) do
			label.TextTransparency = 0.7
		end
		task.wait(0.06)
		screen.BackgroundTransparency = 0
		for _, label in ipairs(labels) do
			label.TextTransparency = 0
		end
		task.wait(0.09)
	end
	-- Over Elias's shoulder to his father's photo (Q-3's desk), letterboxed, 4 s.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("Map")
	local photo = map and (map:FindFirstChild("Q3_Photo", true) or map:FindFirstChild("Q3_Photo_StandIn", true))
	finally()
	if root and photo then
		ctx.takeCamera()
		DialogueController.letterbox("message", true)
		local camera = workspace.CurrentCamera
		camera.FieldOfView = 45
		local look = photo.Position
		local away = (root.Position - look) * Vector3.new(1, 0, 1)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
		local right = away:Cross(Vector3.yAxis)
		local from = root.Position + away * 2.6 - right * 1.4 + Vector3.new(0, 2.4, 0)
		local to = look + away * 2.2 + Vector3.new(0, 0.5, 0)
		local started = os.clock()
		while ctx.alive() do
			local t = math.clamp((os.clock() - started) / PUSH, 0, 1)
			local e = t * t * (3 - 2 * t)
			local pos = from:Lerp(to, e)
			camera.CFrame = CFrame.lookAt(pos, look)
			ctx.focus(pos, look)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end
	-- Black over 2 s; it ends there.
	UIController.fade(1, 2)
	DialogueController.letterbox("message", false)
end

return Message
