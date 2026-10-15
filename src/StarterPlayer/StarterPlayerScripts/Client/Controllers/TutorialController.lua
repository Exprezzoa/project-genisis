--!nonstrict
-- Client/Controllers/TutorialController.lua  (docs/13 §8, docs/14_ui.md §10; data: Shared/Tutorials)
--
-- Tutorial cards. The server sends Tutorial_Show {id} (show it) or {id, arm = true} (watch its condition, then
-- show it); either way it only does so for a profile without the flag TUT_<id>, and this client answers
-- Tutorial_Seen {id} once the card is up, so the server sets the flag. One card at a time, never over a dialogue
-- or a cinematic, and none but TUT_DODGE while a Titan telegraphs. Settings → Tutorial Hints off hides them all.
-- The card: top center, 560 wide, a dark slab with an amber edge, the title in amber Michroma 14 on a tilted
-- tag, the body in TitilliumWeb 18 with the keys of the device in use in amber, a thin bar running out over
-- 5 s. It drops in and fades; a tap or click dismisses it.
--
--   show(id)      arm(id)      getState() -> { showing, queued, armed }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Tutorials = require(Shared.Tutorials)
local UIStyle = require(Shared.Config.UIStyle)

local CinematicController = require(script.Parent.CinematicController)
local Components = require(script.Parent.Parent.UI.Components)
local DialogueController = require(script.Parent.DialogueController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local TutorialController = {}

local WIDTH = 560
local DEVICE_INDEX = { KeyboardMouse = 1, Gamepad = 2, Touch = 3 }
local AMBER_HEX = UIStyle.Accent:ToHex()

local localPlayer = Players.LocalPlayer
local queue = {} -- ids waiting to be shown
local armed = {} -- [id] = watcher state
local showing = nil
local token = 0
local card, cardScale, titleLabel, bodyLabel, timerFill, group

----------------------------------------------------------------------------------------------------------------
-- Text
----------------------------------------------------------------------------------------------------------------
local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- "[A|B|C]" -> the part for the device in use, in amber.
local function render(body: string): string
	local index = DEVICE_INDEX[InputController.getDevice()] or 1
	local out = escape(body):gsub("%[([^%]]+)%]", function(group)
		local parts = string.split(group, "|")
		local pick = parts[index] or parts[1]
		return ('<font color="#%s"><b>%s</b></font>'):format(AMBER_HEX, pick)
	end)
	return out
end

----------------------------------------------------------------------------------------------------------------
-- The card
----------------------------------------------------------------------------------------------------------------
local function build()
	local layer = UIController.getLayer("HUD")
	card = Instance.new("Frame")
	card.Name = "Tutorial"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 120)
	card.Size = UDim2.fromOffset(WIDTH, 96)
	card.Visible = false
	card.Parent = layer
	cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = card
	local slab = Components.slab(group, { color = UIStyle.PanelSolid.Color, transparency = 0.12, slant = 10 }, {
		Name = "Back", Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 1, -12),
	})
	Components.slab(slab, { color = UIStyle.Accent, slant = false }, { Name = "Edge", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 4, 1, 0), ZIndex = 2 })
	local tag = Components.slab(group, { color = UIStyle.Accent, slant = 12 }, {
		Name = "Tag", Position = UDim2.fromOffset(22, 0), Size = UDim2.fromOffset(180, 26), Rotation = UIStyle.Tilt, ZIndex = 3,
	})
	titleLabel = Components.label(tag, "", { font = "Header", size = 14, color = UIStyle.Ink }, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
	})
	bodyLabel = Components.label(slab, "", { size = 18, wrap = true }, {
		Name = "Body", Position = UDim2.fromOffset(32, 22), Size = UDim2.new(1, -52, 1, -34), RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 2,
	})
	local track = Components.slab(slab, { color = UIStyle.Paper, transparency = 0.85, slant = false }, {
		Name = "Track", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 32, 1, -8), Size = UDim2.new(1, -64, 0, 2), ZIndex = 2,
	})
	timerFill = Components.slab(track, { color = UIStyle.Accent, slant = false }, { Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	-- A tap or click dismisses it.
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 5
	hit.Parent = card
	hit.Activated:Connect(function()
		TutorialController.hide()
	end)
end

local function blocked(id: string): boolean
	if DialogueController.getState().open or CinematicController.isPlaying() then
		return true
	end
	if id ~= "TUT_DODGE" then
		for _, titan in ipairs(workspace:FindFirstChild("Titans") and workspace.Titans:GetChildren() or {}) do
			if titan:GetAttribute("State") == "Telegraph" then
				return true
			end
		end
	end
	return false
end

function TutorialController.hide()
	if not showing then
		return
	end
	token += 1
	local mine = token
	showing = nil
	local out = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(group, out, { GroupTransparency = 1 }):Play()
	TweenService:Create(card, out, { Position = UDim2.new(0.5, 0, 0, 104) }):Play()
	task.delay(0.21, function()
		if token == mine then
			card.Visible = false
		end
	end)
end

local function present(id: string)
	local data = Tutorials.tutorials[id]
	if not data then
		return
	end
	token += 1
	local mine = token
	showing = id
	titleLabel.Text = data.title
	bodyLabel.Text = render(data.body)
	local tag = titleLabel.Parent
	tag.Size = UDim2.fromOffset(math.max(120, #data.title * 12 + 40), 26)
	card.Size = UDim2.fromOffset(WIDTH, if #data.body > 90 then 112 else 92)
	card.Position = UDim2.new(0.5, 0, 0, 96)
	group.GroupTransparency = 1
	cardScale.Scale = 0.96
	card.Visible = true
	local seconds = data.seconds or Tutorials.SECONDS
	local drop = TweenInfo.new(UIStyle.Pop.Time + 0.1, UIStyle.Pop.Style, UIStyle.Pop.Direction)
	TweenService:Create(card, drop, { Position = UDim2.new(0.5, 0, 0, 120) }):Play()
	TweenService:Create(cardScale, drop, { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()
	timerFill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(timerFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	Net.fireServer("Tutorial_Seen", { id = id })
	task.delay(seconds, function()
		if token == mine then
			TutorialController.hide()
		end
	end)
end

function TutorialController.show(id: string)
	if not table.find(queue, id) and showing ~= id then
		table.insert(queue, id)
	end
end

----------------------------------------------------------------------------------------------------------------
-- Conditions (armed tutorials)
----------------------------------------------------------------------------------------------------------------
local function titans()
	local folder = workspace:FindFirstChild("Titans")
	return folder and folder:GetChildren() or {}
end

local function myFrame()
	local folder = workspace:FindFirstChild("Frames")
	for _, frame in ipairs(folder and folder:GetChildren() or {}) do
		if frame:GetAttribute("Pilot") == localPlayer.UserId then
			return frame
		end
	end
	return nil
end

local CONDITIONS = {
	sweep = function()
		for _, titan in ipairs(titans()) do
			if titan:GetAttribute("State") == "Telegraph" and titan:GetAttribute("Attack") == "Sweep" then
				return true
			end
		end
		return false
	end,
	special = function()
		local frame = myFrame()
		if not frame or (frame:GetAttribute("Energy") or 0) < Tutorials.SPECIAL.energy then
			return false
		end
		for _, titan in ipairs(titans()) do
			local poise, max = titan:GetAttribute("Poise"), titan:GetAttribute("MaxPoise")
			if poise and max and max > 0 and poise / max <= Tutorials.SPECIAL.poise then
				return true
			end
		end
		return false
	end,
	downed = function()
		for _, titan in ipairs(titans()) do
			if titan:GetAttribute("State") == "Downed" then
				return true
			end
		end
		return false
	end,
	-- Healed since the last damage: the lowest HP since it was last hit, against the HP now.
	regen = function(state)
		state.low = state.low or {}
		for _, titan in ipairs(titans()) do
			local hp = titan:GetAttribute("HP")
			if hp then
				local low = state.low[titan]
				if not low or hp < low then
					state.low[titan] = hp
				elseif hp - low >= Tutorials.REGEN_HP then
					return true
				end
			end
		end
		return false
	end,
}

function TutorialController.arm(id: string)
	if Tutorials.tutorials[id] then
		armed[id] = {}
	end
end

local function tick()
	for id, state in pairs(armed) do
		local data = Tutorials.tutorials[id]
		local check = data and CONDITIONS[data.when or ""]
		if not check then
			armed[id] = nil
			TutorialController.show(id)
		elseif check(state) then
			armed[id] = nil
			if data.urgent and not blocked(id) and SettingsController.get("tutorialHints") ~= false then
				TutorialController.hide()
				present(id)
			else
				TutorialController.show(id)
			end
		end
	end
	if showing or #queue == 0 then
		return
	end
	if SettingsController.get("tutorialHints") == false then
		table.clear(queue) -- off: they count as seen by nobody; the server arms them again next time
		return
	end
	for index, id in ipairs(queue) do
		if not blocked(id) then
			table.remove(queue, index)
			present(id)
			return
		end
	end
end

function TutorialController.getState()
	local armedIds = {}
	for id in pairs(armed) do
		table.insert(armedIds, id)
	end
	return { showing = showing, queued = table.clone(queue), armed = armedIds }
end

function TutorialController.Init()
	build()
end

function TutorialController.Start()
	Net.on("Tutorial_Show", function(payload)
		if type(payload) ~= "table" or type(payload.id) ~= "string" then
			return
		end
		if payload.arm then
			TutorialController.arm(payload.id)
		else
			TutorialController.show(payload.id)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
end

return TutorialController
