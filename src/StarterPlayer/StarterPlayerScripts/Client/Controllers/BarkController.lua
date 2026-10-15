--!nonstrict
-- Client/Controllers/BarkController.lua  (docs/13_missions_dialogue_relationships.md §7; docs/05 S03)
--
-- Ambient barks: an NPC with the attribute Barks ("BARK_OPS_1,...") says its next bark, once per session, when
-- the player passes within NPCs.Bark.RANGE on foot. The line floats above the speaker's head (a BillboardGui:
-- a tilted name tag in the speaker's color over a dark slab). One at a time, NPCs.Bark.COOLDOWN seconds
-- apart, and never while a conversation or cinematic is open. The text is the bark's dialogue
-- ("DLG_<barkId>", node <barkId>) in Shared/Dialogue.
-- Fight barks (S28): radio subtitles from the fight's events while the server has them on (see below).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCs = require(Shared.Config.NPCs)
local Net = require(Shared.Modules.Net)
local Speakers = require(Shared.Dialogue.Speakers)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Parent.UI.Components)
local DialogueController = require(script.Parent.DialogueController)
local HUDController = require(script.Parent.HUDController)

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

----------------------------------------------------------------------------------------------------------------
-- Fight barks (docs/05 S28): radio subtitles while a fight runs, switched on and off by the server
-- (Bark_Play { fight = "M01", on }). A 12 s cooldown between them, each line at most twice per fight, never over
-- a dialogue line; FB_M7 answers FB_O1 straight after. What sets each one off (D-087): FB_M1 Unit 01 starts an
-- attack, FB_M2 three of the player's hits in a row miss the ankles, FB_M3 a Stomp telegraph, FB_M4 Integrity
-- under 34%, FB_M5 the Titan goes down, FB_M6 it regains 100 HP, FB_E1 the player is hurt, FB_E2 a Core Strike
-- lands, FB_O1 a Roar at half health or less (it skips the cooldown: the fight's turn, said once or twice).
----------------------------------------------------------------------------------------------------------------
local FIGHT = { cooldown = 12, max = 2, stale = 3, legs = { AnkleL = true, AnkleR = true } }
local PRIORITY = { "FB_O1", "FB_M5", "FB_E2", "FB_M4", "FB_M6", "FB_M3", "FB_M1", "FB_M2", "FB_E1" }
local fight = nil

local function fightTitan()
	local folder = workspace:FindFirstChild("Titans")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:IsA("Model") and model:GetAttribute("TitanType") then
			return model
		end
	end
	return nil
end

local function frameOf(unit)
	local folder = workspace:FindFirstChild("Frames")
	return folder and folder:FindFirstChild("Frame_" .. unit)
end

local function want(id)
	if fight then
		fight.wanted[id] = os.clock()
	end
end

local function sayFight(id, force)
	local line = lines[id]
	if not fight or not line or (fight.counts[id] or 0) >= FIGHT.max then
		return false
	end
	if not force and (os.clock() - fight.lastAt < FIGHT.cooldown or DialogueController.getState().open or HUDController.getState().subtitle) then
		return false
	end
	fight.counts[id] = (fight.counts[id] or 0) + 1
	fight.lastAt = os.clock()
	HUDController.showSubtitle({ text = line.text, speaker = line.speaker })
	if id == "FB_O1" then
		local mine = fight
		task.delay(2.6, function()
			if fight == mine then
				sayFight("FB_M7", true)
			end
		end)
	end
	return true
end

local function watchFight()
	local titan = fightTitan()
	if titan then
		local state, attack = titan:GetAttribute("State"), titan:GetAttribute("Attack")
		if state ~= fight.state or attack ~= fight.attack then
			if state == "Telegraph" and attack == "Stomp" then
				want("FB_M3")
			elseif state == "Telegraph" and attack == "Roar" then
				local hp, max = titan:GetAttribute("HP") or 0, titan:GetAttribute("MaxHP") or 1
				if hp / max <= 0.5 then
					want("FB_O1")
				end
			elseif state == "Downed" then
				want("FB_M5")
			end
			fight.state, fight.attack = state, attack
		end
		local hp = titan:GetAttribute("HP")
		if hp then
			if not fight.low or hp < fight.low then
				fight.low = hp
			elseif hp - fight.low >= 100 then
				fight.low = hp
				want("FB_M6")
			end
		end
	end
	local mine = frameOf("02")
	if mine and mine:GetAttribute("Pilot") == localPlayer.UserId then
		local integrity, max = mine:GetAttribute("Integrity"), mine:GetAttribute("IntegrityMax")
		if integrity and max and max > 0 then
			if fight.integrity and integrity < fight.integrity then
				want(if integrity / max < 0.34 then "FB_M4" else "FB_E1")
			end
			fight.integrity = integrity
		end
	end
	local ally = frameOf("01")
	local action = ally and ally:GetAttribute("Action") or ""
	if action ~= "" and fight.allyAction == "" then
		want("FB_M1")
	end
	fight.allyAction = action
	-- The most pressing wanted line that can be said now; old wishes lapse.
	for _, id in ipairs(PRIORITY) do
		local at = fight.wanted[id]
		if at and os.clock() - at > FIGHT.stale then
			fight.wanted[id] = nil
		elseif at and sayFight(id, id == "FB_O1") then -- the Roar at half health is the fight's turn: no cooldown
			fight.wanted[id] = nil
			break
		end
	end
end

local function onFeedback(payload)
	if not fight or type(payload) ~= "table" or payload.kind ~= "HitLanded" then
		return
	end
	if payload.move == "CoreStrike" then
		want("FB_E2")
	end
	if FIGHT.legs[payload.zone] then
		fight.offLegs = 0
	else
		fight.offLegs += 1
		if fight.offLegs >= 3 then
			fight.offLegs = 0
			want("FB_M2")
		end
	end
end

function BarkController.setFight(name, on)
	fight = if on then { name = name, counts = {}, wanted = {}, lastAt = -math.huge, offLegs = 0, allyAction = "" } else nil
end

function BarkController.getFight()
	return fight and { name = fight.name, counts = table.clone(fight.counts) } or nil
end

function BarkController.Init()
	loadLines()
end

function BarkController.Start()
	Net.on("Bark_Play", function(payload)
		if type(payload) == "table" and type(payload.fight) == "string" then
			BarkController.setFight(payload.fight, payload.on == true)
		end
	end)
	Net.on("Combat_Feedback", onFeedback)
	task.spawn(function()
		while true do
			task.wait(0.25)
			check()
			if fight then
				watchFight()
			end
		end
	end)
end

-- For tests: forget what was said.
function BarkController.reset()
	table.clear(said)
	lastAt = -math.huge
end

return BarkController
