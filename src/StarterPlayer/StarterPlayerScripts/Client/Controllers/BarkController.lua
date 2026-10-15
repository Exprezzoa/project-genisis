--!nonstrict
-- Client/Controllers/BarkController.lua  (docs/13_missions_dialogue_relationships.md §7; docs/05 S03)
--
-- Ambient barks: an NPC with the attribute Barks ("BARK_OPS_1,...") says its next bark, once per session, when
-- the player passes within NPCs.Bark.RANGE on foot. The line floats above the speaker's head (a BillboardGui:
-- a tilted name tag in the speaker's color over a dark slab). One at a time, NPCs.Bark.COOLDOWN seconds
-- apart, and never while a conversation or cinematic is open. The text is the bark's dialogue
-- ("DLG_<barkId>", node <barkId>) in Shared/Dialogue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCs = require(Shared.Config.NPCs)
local Speakers = require(Shared.Dialogue.Speakers)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local DialogueController = require(script.Parent.DialogueController)

local BarkController = {}

local WIDTH = 300 -- px, the widest a bark gets
local TEXT_SIZE = 17
local PADDING = 10
local TAG_HEIGHT = 22

local lines = {} -- [barkId] = { speaker, text }
local said = {} -- [barkId] = true once played this session
local showing = nil
local lastAt = -math.huge
local localPlayer = Players.LocalPlayer

local function loadLines()
	for _, module in ipairs(Shared.Dialogue:GetChildren()) do
		if module:IsA("ModuleScript") and module.Name ~= "Speakers" then
			for dialogueId, dialogue in pairs(require(module)) do
				if dialogue.mode == "bark" then
					local barkId = dialogueId:gsub("^DLG_", "")
					local node = dialogue.nodes[barkId]
					if node then
						lines[barkId] = { speaker = node.speaker, text = node.text }
					end
				end
			end
		end
	end
end

local function textHeight(text: string): number
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = UIStyle.Font.Body
		params.Size = TEXT_SIZE
		params.Width = WIDTH - PADDING * 2
		return TextService:GetTextBoundsAsync(params)
	end)
	return if ok then bounds.Y else TEXT_SIZE * 2
end

local function show(model: Model, barkId: string)
	local line = lines[barkId]
	local head = model:FindFirstChild("Head")
	if not line or not head then
		return
	end
	said[barkId] = true
	lastAt = os.clock()
	local speaker = Speakers[line.speaker] or { name = line.speaker, color = UIStyle.TextSecondary }
	local height = textHeight(line.text) + PADDING * 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bark_" .. barkId
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(WIDTH, height + TAG_HEIGHT + 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.ResetOnSpawn = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 1
	group.Parent = holder

	local body = Components.slab(group, { color = UIStyle.PanelSolid.Color, transparency = 0.12, slant = 8 }, {
		Name = "Body", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, -16, 0, height),
	})
	local stripe = Instance.new("Frame")
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = speaker.color
	stripe.Size = UDim2.new(1, -24, 0, 2)
	stripe.Position = UDim2.fromOffset(12, 0)
	stripe.Parent = body
	Components.label(body, line.text, { size = TEXT_SIZE, wrap = true }, {
		Name = "Text", Position = UDim2.fromOffset(PADDING + 4, PADDING), Size = UDim2.new(1, -(PADDING + 4) * 2, 1, -PADDING * 2),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
	})
	local tag = Components.slab(group, { color = speaker.color, slant = 12 }, {
		Name = "Tag", Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(math.max(80, #speaker.name * 10 + 28), TAG_HEIGHT),
		Rotation = UIStyle.Tilt, ZIndex = 3,
	})
	Components.label(tag, speaker.name, { font = "Header", size = 12, color = UIStyle.Ink }, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
	})
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	TweenService:Create(scale, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()
	showing = gui
	local seconds = math.max(NPCs.Bark.SHOW, 1 + #line.text / 15)
	task.delay(seconds, function()
		TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
		task.wait(0.25)
		gui:Destroy()
		if showing == gui then
			showing = nil
		end
	end)
end

-- BARK_OPS_2 waits for BARK_OPS_1: numbered barks are one exchange, spread over several NPCs (docs/05 S03).
local function ready(barkId: string): boolean
	local prefix, number = barkId:match("^(.-)_(%d+)$")
	local previous = prefix and (prefix .. "_" .. (tonumber(number) - 1))
	return previous == nil or lines[previous] == nil or said[previous] == true
end

local function nextBark(model: Model): string?
	for barkId in string.gmatch(model:GetAttribute("Barks") or "", "[^,]+") do
		if not said[barkId] and ready(barkId) then
			return barkId
		end
	end
	return nil
end

local function check()
	if showing or os.clock() - lastAt < NPCs.Bark.COOLDOWN or DialogueController.getState().open then
		return
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local folder = workspace:FindFirstChild("Runtime") and workspace.Runtime:FindFirstChild("NPCs")
	if not root or not humanoid or humanoid.SeatPart or not folder then
		return
	end
	local best, bestBark, bestDistance = nil, nil, NPCs.Bark.RANGE
	for _, model in ipairs(folder:GetChildren()) do
		local barkId = model:IsA("Model") and nextBark(model)
		local npcRoot = barkId and model:FindFirstChild("HumanoidRootPart")
		if npcRoot then
			local distance = (npcRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestBark, bestDistance = model, barkId, distance
			end
		end
	end
	if best then
		show(best, bestBark)
	end
end

function BarkController.Init()
	loadLines()
end

function BarkController.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			check()
		end
	end)
end

-- For tests: forget what was said.
function BarkController.reset()
	table.clear(said)
	lastAt = -math.huge
end

return BarkController
