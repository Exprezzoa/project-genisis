--!nonstrict
-- Server/Services/NPCService.lua  (docs/13_missions_dialogue_relationships.md §6; docs/08_rigs_and_animation.md §1.2)
--
-- Places the NPCs of Shared/Config/NPCs.lua into Workspace.Runtime.NPCs, walks them (Server/NPC/NPCMover),
-- seats them, runs their ambient routes and their Talk prompts. An NPC that stands still has its root anchored;
-- it is un-anchored only to walk or sit. The client (NPCAnimator) plays idle/walk/sit and the gestures from
-- the model's attributes: NPC (id), Gesture, Speaker, Barks, TalkingTo (a UserId while it talks to them).
--
--   only(setName)                 that set exactly: places the missing ones, removes the rest
--   spawn(ids) / despawn(ids, fade?)   ids: a list, one id, or "all" for despawn
--   get(id) -> Model?             place(id, at)          stop(id)
--   walkTo(id, target, opts?) -> boolean    yields; opts.follow = player (follower mode, docs/05 S06)
--   sit(id, at, height?)          on an invisible seat at a SpawnId or point
--   setGesture(id, gesture?)       handOver(fromId, toId)   (a held prop, NPCs.defs[id].holds)
-- Talking NPCs turn to the player by tweening their anchored root (D-081); seated ones only turn their head.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Modules.Log)
local NPCs = require(Shared.Config.NPCs)

local CollisionService = require(script.Parent.CollisionService)
local DialogueService = require(script.Parent.DialogueService)
local FlagService = require(script.Parent.FlagService)
local InteractionService = require(script.Parent.InteractionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local NPCMover = require(script.Parent.Parent.NPC.NPCMover)
local StaticInteractions = require(script.Parent.Parent.Sequence.StaticInteractions)

local TAG = "NPCService"
local FACING = {
	["-Z"] = Vector3.new(0, 0, -1), ["+Z"] = Vector3.new(0, 0, 1),
	["-X"] = Vector3.new(-1, 0, 0), ["+X"] = Vector3.new(1, 0, 0),
}

local FADE = 0.6 -- seconds a fading despawn takes
local TURN_RANGE = 20 -- a participant further away (Hollis at Bay 3 in S05) keeps its pose until it walks in

local NPCService = {}

local active = {} -- [id] = { id, def, model, humanoid, root, job, seat, home }
local folder: Folder

local function promptId(id: string): string
	return NPCs.Talk.PREFIX .. string.upper(id)
end

-- `at` -> the feet's CFrame (facing along its LookVector).
local function feetCFrame(at): CFrame?
	if type(at) == "table" then
		local pos = Vector3.new(at[1], at[2], at[3])
		local facing = FACING[at[4] or "-Z"] or FACING["-Z"]
		return CFrame.lookAt(pos, pos + facing)
	end
	local pos, look = NPCMover.resolve(at)
	if not pos then
		return nil
	end
	return CFrame.lookAt(pos, pos + (look or FACING["-Z"]))
end

local function standingAt(npc, feet: CFrame): CFrame
	return feet + Vector3.new(0, npc.humanoid.HipHeight + npc.root.Size.Y / 2, 0)
end

local function removeSeat(npc)
	if npc.seat then
		npc.seat:Destroy()
		npc.seat = nil
	end
end

local function anchor(npc, anchored: boolean)
	if npc.root.Anchored == anchored then
		return
	end
	npc.root.Anchored = anchored
	if not anchored then
		npc.root:SetNetworkOwner(nil)
		-- An anchored humanoid sits in Freefall and takes about 3 s to find the floor again; MoveTo waits for it.
		npc.humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

local function stand(npc, feet: CFrame)
	removeSeat(npc)
	npc.humanoid.Sit = false
	anchor(npc, true)
	npc.root.CFrame = standingAt(npc, feet)
	npc.home = feet
end

local function prepare(model: Model, id: string, def)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.WalkSpeed = NPCs.Move.WALK
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			CollisionService.assign(part, "NPCs")
		end
	end
	model.Name = id
	model:SetAttribute("NPC", id)
	model:SetAttribute("Gesture", def.idle)
	model:SetAttribute("Speaker", def.speaker)
	model:SetAttribute("Barks", if def.barks then table.concat(def.barks, ",") else nil)
	return humanoid
end

local function addTalkPrompt(npc)
	local talk = npc.def.talk
	local root = npc.root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Talk"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = NPCs.Talk.DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = root
	root:SetAttribute("InteractId", promptId(npc.id))
	root:SetAttribute("FrameOnly", false)
	root:SetAttribute("OnFootOnly", true)
	root:SetAttribute("Once", talk.once == true)
	-- A once-only talk the player already had (an earlier session) stays off for them.
	if talk.once then
		for _, player in ipairs(Players:GetPlayers()) do
			if FlagService.has(player, StaticInteractions.SEEN_PREFIX .. promptId(npc.id)) then
				InteractionService.setEnabled(promptId(npc.id), false, player)
			end
		end
	end
	CollectionService:AddTag(root, "Interactable")
end

-- Props an NPC can hold in its right hand (NPCs.defs[id].holds). The spindle case of S40: a dark case with a red
-- lock light, the one Elias opened in the rover (docs/05 S32, S40).
local PROPS = {
	SpindleCase = function()
		local case = Instance.new("Part")
		case.Name = "SpindleCase"
		case.Size = Vector3.new(0.5, 0.9, 1.3)
		case.Color = Color3.fromHex("#2A2D31")
		case.Material = Enum.Material.SmoothPlastic
		local lock = Instance.new("Part")
		lock.Name = "LockLight"
		lock.Size = Vector3.new(0.52, 0.12, 0.12)
		lock.Color = Color3.fromHex("#E5484D")
		lock.Material = Enum.Material.Neon
		lock.CFrame = CFrame.new(0, 0.3, -0.4)
		lock.Parent = case
		return case
	end,
}

-- Puts a prop in the NPC's right hand (welded, below the palm).
local function hold(npc, name)
	local hand = npc.model:FindFirstChild("RightHand")
	local make = PROPS[name]
	if not hand or not make then
		return
	end
	local prop = make()
	local offset = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - prop.Size.Y / 2 + 0.1, 0)
	for _, part in ipairs({ prop, table.unpack(prop:GetChildren()) }) do
		if part:IsA("BasePart") then
			local at = if part == prop then offset else offset * part.CFrame
			part.CFrame = at
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = hand, part
			weld.Parent = part
		end
	end
	prop.Parent = npc.model
	npc.holding = prop
end

-- Starts a route loop: walk to each point in turn, pause 2-6 s, Inspect where the route says.
local function runRoute(npc)
	local route = npc.def.route
	local points = route.points
	local order = {}
	for index = 1, #points do
		table.insert(order, index)
	end
	if route.pingPong then
		for index = #points - 1, 2, -1 do
			table.insert(order, index)
		end
	end
	task.spawn(function()
		local step = 1
		local mine = npc.job
		while active[npc.id] == npc and npc.job == mine do
			local index = order[step]
			local point = NPCMover.resolve(points[index])
			anchor(npc, false)
			local reached = NPCMover.walk(npc, NPCMover.path(npc.root.Position - Vector3.new(0, npc.humanoid.HipHeight + npc.root.Size.Y / 2, 0), point))
			if not reached then
				return
			end
			mine = npc.job
			anchor(npc, true)
			if route.inspect and route.inspect[index] then
				npc.model:SetAttribute("Gesture", "Inspect")
			end
			task.wait(NPCs.Move.PAUSE[1] + math.random() * (NPCs.Move.PAUSE[2] - NPCs.Move.PAUSE[1]))
			if npc.job ~= mine then
				return
			end
			npc.model:SetAttribute("Gesture", npc.def.idle)
			step = step % #order + 1
		end
	end)
end

local function spawnOne(id: string)
	if active[id] then
		return active[id]
	end
	local def = NPCs.defs[id]
	if not def then
		Log.warn(TAG, "unknown NPC %s", tostring(id))
		return nil
	end
	local template = ServerStorage.Templates.NPCs:FindFirstChild(def.template)
	local feet = feetCFrame(def.at)
	if not template or not feet then
		Log.warn(TAG, "%s: missing template %s or place %s", id, def.template, tostring(def.at))
		return nil
	end
	local model = template:Clone()
	local humanoid = prepare(model, id, def)
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	local npc = { id = id, def = def, model = model, humanoid = humanoid, root = root, job = 0 }
	model.Parent = folder
	active[id] = npc
	if def.seat then
		NPCService.sit(id, def.at, def.seat)
	else
		stand(npc, feet)
	end
	if def.talk then
		addTalkPrompt(npc)
	end
	if def.holds then
		hold(npc, def.holds)
	end
	if def.route then
		runRoute(npc)
	end
	return npc
end

----------------------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------------------
local function list(ids): { string }
	if type(ids) == "string" then
		return { ids }
	end
	return ids or {}
end

function NPCService.spawn(ids)
	for _, id in ipairs(list(ids)) do
		spawnOne(id)
	end
end

-- fade = true: the NPC fades out over FADE seconds first (Mara boarding in S07).
function NPCService.despawn(ids, fade: boolean?)
	local targets = {}
	if ids == "all" then
		for id in pairs(active) do
			table.insert(targets, id)
		end
	else
		targets = list(ids)
	end
	for _, id in ipairs(targets) do
		local npc = active[id]
		if npc then
			active[id] = nil
			npc.job += 1
			removeSeat(npc)
			if fade then
				anchor(npc, true)
				local info = TweenInfo.new(FADE, Enum.EasingStyle.Quad)
				for _, item in ipairs(npc.model:GetDescendants()) do
					if (item:IsA("BasePart") and item.Transparency < 1) or item:IsA("Decal") then
						TweenService:Create(item, info, { Transparency = 1 }):Play()
					end
				end
				Debris:AddItem(npc.model, FADE + 0.1)
			else
				npc.model:Destroy()
			end
		end
	end
end

function NPCService.only(setName: string)
	local set = NPCs.sets[setName]
	if not set then
		Log.warn(TAG, "unknown NPC set %s", tostring(setName))
		return
	end
	local wanted = {}
	for _, id in ipairs(set) do
		wanted[id] = true
	end
	local extra = {}
	for id in pairs(active) do
		if not wanted[id] then
			table.insert(extra, id)
		end
	end
	NPCService.despawn(extra)
	NPCService.spawn(set)
end

function NPCService.get(id: string): Model?
	return active[id] and active[id].model
end

function NPCService.list(): { string }
	local ids = {}
	for id in pairs(active) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function NPCService.place(id: string, at)
	local npc = active[id] or spawnOne(id)
	local feet = npc and feetCFrame(at)
	if feet then
		NPCMover.cancel(npc)
		stand(npc, feet)
	end
end

function NPCService.stop(id: string)
	local npc = active[id]
	if npc then
		NPCMover.cancel(npc)
		if not npc.seat then
			anchor(npc, true)
		end
	end
end

-- One NPC hands what it holds to another (S40: the technician gives Rhein the spindle case).
function NPCService.handOver(fromId: string, toId: string)
	local from, to = active[fromId], active[toId]
	if not (from and to and from.holding) then
		return
	end
	local name = from.holding.Name
	from.holding:Destroy()
	from.holding = nil
	hold(to, name)
end

function NPCService.setGesture(id: string, gesture: string?)
	local npc = active[id]
	if npc then
		npc.model:SetAttribute("Gesture", gesture)
	end
end

-- Walks there (stopping a route or another walk) and stands facing the mark's direction (or the walk's).
function NPCService.walkTo(id: string, target, opts): boolean
	local npc = active[id]
	local point, look = NPCMover.resolve(target)
	if not npc or not point then
		Log.warn(TAG, "walkTo: no NPC %s or no place %s", tostring(id), tostring(target))
		return false
	end
	removeSeat(npc)
	npc.humanoid.Sit = false
	anchor(npc, false)
	local feetNow = npc.root.Position - Vector3.new(0, npc.humanoid.HipHeight + npc.root.Size.Y / 2, 0)
	local reached = NPCMover.walk(npc, NPCMover.path(feetNow, point), opts)
	if reached then
		local facing = look or Vector3.new(npc.root.CFrame.LookVector.X, 0, npc.root.CFrame.LookVector.Z)
		stand(npc, CFrame.lookAt(point, point + facing))
	end
	return reached
end

function NPCService.sit(id: string, at, height: number?)
	local npc = active[id]
	local feet = npc and feetCFrame(at)
	if not feet then
		return
	end
	NPCMover.cancel(npc)
	removeSeat(npc)
	local seat = Instance.new("Seat")
	seat.Name = id .. "_Seat"
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Anchored = true
	seat.CFrame = feet * CFrame.new(0, (height or 1.8) - 0.1, 0)
	seat.Parent = folder
	npc.seat = seat
	npc.home = feet
	npc.root.CFrame = standingAt(npc, seat.CFrame)
	anchor(npc, false)
	seat:Sit(npc.humanoid)
end

----------------------------------------------------------------------------------------------------------------
-- Talking
----------------------------------------------------------------------------------------------------------------
local function turn(npc, look: Vector3)
	if npc.seat or not npc.root.Anchored then
		return
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then
		return
	end
	local pos = npc.root.Position
	TweenService:Create(npc.root, TweenInfo.new(NPCs.TURN, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(pos, pos + flatLook) }):Play()
end

-- A conversation with NPC participants (docs/13 §2 `participants`): they look at the player and the standing ones
-- turn to face them; the player turns to the first one (TalkTarget, client side). Cinematics stage their own,
-- unless the dialogue says face = true (S40's conversation in the hangar).
local engaged = {} -- [player] = { dialogueId, ids }

local function release(player: Player)
	local entry = engaged[player]
	if not entry then
		return
	end
	engaged[player] = nil
	for _, id in ipairs(entry.ids) do
		local npc = active[id]
		if npc and npc.model.Parent then
			npc.model:SetAttribute("TalkingTo", nil)
			if npc.home then
				turn(npc, npc.home.LookVector)
			end
		end
	end
	player:SetAttribute("TalkTarget", nil)
end

local function engage(player: Player, dialogueId: string)
	if engaged[player] and engaged[player].dialogueId == dialogueId then
		return
	end
	local dialogue = DialogueService.get(dialogueId)
	if not dialogue or not dialogue.participants or not (dialogue.mode == "conversation" or dialogue.face) then
		return
	end
	release(player)
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local ids = {}
	for _, id in ipairs(dialogue.participants) do
		local npc = active[id]
		if npc then
			table.insert(ids, id)
			npc.model:SetAttribute("TalkingTo", player.UserId)
			if playerRoot and (playerRoot.Position - npc.root.Position).Magnitude <= TURN_RANGE then
				turn(npc, playerRoot.Position - npc.root.Position)
			end
		end
	end
	engaged[player] = { dialogueId = dialogueId, ids = ids }
	if ids[1] then
		player:SetAttribute("TalkTarget", ids[1])
	end
end

-- The Talk prompt: the first dialogue the first time (flag SEEN_TALK_<ID>), then the repeat one.
local function talk(player: Player, id: string)
	local npc = active[id]
	if not npc or DialogueService.isActive(player) then
		return
	end
	local talkDef = npc.def.talk
	local first = FlagService.set(player, StaticInteractions.SEEN_PREFIX .. promptId(id))
	DialogueService.start(player, if first then talkDef.first else (talkDef.again or talkDef.first))
end

-- A dialogue line's NPC action (docs/13 §2 "action"): { npc = id, moveTo = target }.
local function onAction(_player, dialogueId, nodeId, action)
	if type(action) ~= "table" or not action.npc then
		return
	end
	if action.moveTo then
		task.spawn(NPCService.walkTo, action.npc, action.moveTo)
	elseif action.takeFrom then
		NPCService.handOver(action.takeFrom, action.npc)
	elseif action.gesture ~= nil then
		NPCService.setGesture(action.npc, action.gesture or nil)
	else
		Log.debug(TAG, "%s/%s: no NPC action handled in %s", dialogueId, nodeId, action.npc)
	end
end

function NPCService.Init()
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	folder = runtime:FindFirstChild("NPCs") or Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = runtime
end

function NPCService.Start()
	for id, def in pairs(NPCs.defs) do
		if def.talk then
			InteractionService.register(promptId(id), function(player)
				talk(player, id)
			end)
		end
	end
	DialogueService.Action:Connect(onAction)
	DialogueService.NodeShown:Connect(engage)
	DialogueService.Ended:Connect(function(player, dialogueId)
		if engaged[player] and engaged[player].dialogueId == dialogueId then
			release(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		engaged[player] = nil
	end)
	PlayerDataService.Loaded:Connect(function(player)
		for id, npc in pairs(active) do
			if npc.def.talk and npc.def.talk.once and FlagService.has(player, StaticInteractions.SEEN_PREFIX .. promptId(id)) then
				InteractionService.setEnabled(promptId(id), false, player)
			end
		end
	end)
end

return NPCService
