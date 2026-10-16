--!nonstrict
-- StarterPlayerScripts/DevAutopilot.lua  (Studio test tool, docs/19 §1; nothing in the game requires it)
--
-- Plays Chapter 1 from the current step the way a player does: walks (PathfindingService on foot; the Frame's
-- AutoWalkTo while piloting), holds the real ProximityPrompts (aiming the camera so the engine shows them),
-- advances conversation lines and answers choices from a fixed plan, and fights the Strider through the client's
-- combat input. Required from the MCP run-code tool in the Client datamodel, where it runs in the plugin's own VM:
-- it reaches the game's controllers only through PlayerScripts.DevBridge. The current step comes from the player
-- attribute DevStep (a server-side test helper mirrors SequenceService's state into it).
--
-- Waiting cards (Mission Complete, Chapter End) are left for the tester to press Continue: state.waiting says so.
-- A walk that can't finish falls back to a teleport, logged as SHORTCUT (so the report can say how often).
--
--   start(opts) -> state      opts: { choices = { [dialogueId] = index }, evidence = true, deck = true }
--   stop()                    state = { log, step, waiting, done, error, shortcuts }

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local Autopilot = {}

local player = Players.LocalPlayer
local state
local running = 0 -- token: stop() and start() end the loops of an older run

local function log(text, ...)
	local line = ("%6.1f %s %s"):format(os.clock() - state.started, tostring(state.step), select("#", ...) > 0 and text:format(...) or text)
	table.insert(state.log, line)
	if #state.log > 400 then
		table.remove(state.log, 1)
	end
end

local function call(controller, fn, ...)
	local bridge = player:WaitForChild("PlayerScripts"):WaitForChild("DevBridge")
	local result = table.pack(bridge:Invoke("call", controller, fn, ...))
	if not result[1] then
		error(("%s.%s: %s"):format(controller, fn, tostring(result[2])), 2)
	end
	return table.unpack(result, 2, result.n)
end

local function alive(token)
	return running == token and not state.done
end

local function context()
	return call("InputController", "getContext")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local cache = {}
local function find(attribute, id)
	local hit = cache[attribute .. id]
	if hit and hit.Parent then
		return hit
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:GetAttribute(attribute) == id then
			cache[attribute .. id] = d
			return d
		end
	end
	return nil
end

local function root()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
end

local function myFrame()
	local folder = workspace:FindFirstChild("Frames")
	for _, frame in ipairs(folder and folder:GetChildren() or {}) do
		if frame:GetAttribute("Pilot") == player.UserId then
			return frame
		end
	end
	return nil
end

-- Waits while a cinematic, dialogue or menu holds the controls (the player couldn't move either).
local function waitForControl(token, want)
	while alive(token) do
		local ctx = context()
		if ctx == want then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function teleport(position)
	local hrp = root()
	if hrp then
		hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	end
	state.shortcuts += 1
end

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Frames"), workspace:FindFirstChild("Titans"), workspace:FindFirstChild("Runtime"), workspace:FindFirstChild("NPCs") }
	params.RespectCanCollide = true
	return params
end

-- The floor under a point (trigger boxes and prompt parts float above it; paths are computed to the floor).
local function ground(point)
	local hit = workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0), rayParams())
	return if hit then hit.Position else point
end

-- The nav graph the NPCs walk (parts tagged NavNode; Server/NPC/NPCMover does the same), for routes the
-- PathfindingService can't find (the catwalks, the stairs).
local WAIST = 2.5
local function clearLine(a, b)
	local from = a + Vector3.new(0, WAIST, 0)
	local delta = (b + Vector3.new(0, WAIST, 0)) - from
	return delta.Magnitude < 0.1 or workspace:Raycast(from, delta, rayParams()) == nil
end

local function navRoute(from, to)
	local nodes = {}
	for _, part in ipairs(game:GetService("CollectionService"):GetTagged("NavNode")) do
		local id = part:GetAttribute("NavId")
		if type(id) == "string" and part:IsDescendantOf(workspace) then
			local links = {}
			for link in string.gmatch(part:GetAttribute("Links") or "", "[^,]+") do
				table.insert(links, link)
			end
			nodes[id] = { id = id, pos = part.Position, links = links }
		end
	end
	local function nearest(pos)
		local best, bestD, any, anyD = nil, math.huge, nil, math.huge
		for _, node in pairs(nodes) do
			local d = (node.pos - pos).Magnitude
			if d < anyD then
				any, anyD = node, d
			end
			if d < bestD and d <= 60 and clearLine(pos, node.pos) then
				best, bestD = node, d
			end
		end
		return best or any
	end
	local first, last = nearest(from), nearest(to)
	if not first or not last then
		return nil
	end
	local distance, previous, done = { [first.id] = 0 }, {}, {}
	while true do
		local current, best = nil, math.huge
		for id, d in pairs(distance) do
			if not done[id] and d < best then
				current, best = id, d
			end
		end
		if not current then
			return nil
		elseif current == last.id then
			break
		end
		done[current] = true
		for _, link in ipairs(nodes[current].links) do
			local other = nodes[link]
			if other and not done[link] then
				local d = best + (other.pos - nodes[current].pos).Magnitude
				if d < (distance[link] or math.huge) then
					distance[link], previous[link] = d, current
				end
			end
		end
	end
	local ids = { last.id }
	while ids[1] ~= first.id do
		table.insert(ids, 1, previous[ids[1]])
	end
	local points = {}
	for _, id in ipairs(ids) do
		table.insert(points, { Position = nodes[id].pos, Action = Enum.PathWaypointAction.Walk })
	end
	table.insert(points, { Position = to, Action = Enum.PathWaypointAction.Walk })
	while #points > 1 and clearLine(from, points[2].Position) do
		table.remove(points, 1)
	end
	return points, "nav"
end

-- Straight when nothing is in the way; else PathfindingService; else the nav graph.
local function route(from, to)
	if clearLine(from - Vector3.new(0, 3, 0), to) and math.abs(from.Y - 3 - to.Y) < 4 then
		return { { Position = to, Action = Enum.PathWaypointAction.Walk } }, "straight"
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 6, AgentCanJump = true, WaypointSpacing = 5 })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints(), "pathfinding"
	end
	local points, how = navRoute(from - Vector3.new(0, 3, 0), to)
	if points then
		return points, how
	end
	return { { Position = to, Action = Enum.PathWaypointAction.Walk } }, "straight (no route)"
end

-- Within radius horizontally, on the same level (the root stands about 3 above the feet).
local function arrived(hrp, target, radius)
	return (flat(hrp.Position) - flat(target)).Magnitude <= radius and math.abs(hrp.Position.Y - 3 - target.Y) < 4
end

-- On foot to a point (within radius, horizontally); a teleport when the walk makes no progress three times.
local function walkTo(token, target, radius, done)
	radius = radius or 4
	target = ground(target)
	local function finished(hrp)
		return arrived(hrp, target, radius) or (done ~= nil and done(hrp))
	end
	for attempt = 1, 3 do
		if not waitForControl(token, "OnFoot") then
			return false
		end
		local hrp, humanoid = root()
		if not hrp then
			task.wait(0.5)
			continue
		end
		if finished(hrp) then
			return true
		end
		local points, how = route(hrp.Position, target)
		local stuck = false
		for _, point in ipairs(points) do
			if not alive(token) then
				return false
			end
			if context() ~= "OnFoot" and not waitForControl(token, "OnFoot") then
				return false -- stopped while a dialogue or cinematic held the controls
			end
			if point.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(point.Position)
			local started, best = os.clock(), math.huge
			while alive(token) do
				if context() ~= "OnFoot" then
					-- A line or a cinematic took the controls: wait it out, then walk on to the same point.
					if not waitForControl(token, "OnFoot") then
						return false
					end
					humanoid:MoveTo(point.Position)
					started, best = os.clock(), math.huge
				end
				local distance = (hrp.Position - Vector3.new(0, 3, 0) - point.Position).Magnitude
				if distance < 1.5 or finished(hrp) then -- tight: the nav corners hug rails
					break
				end
				if distance < best - 0.5 then
					best, started = distance, os.clock()
				elseif os.clock() - started > 2.5 then
					stuck = true
					break
				end
				task.wait(0.1)
			end
			if stuck or finished(hrp) then
				break
			end
		end
		if finished(hrp) then
			return true
		end
		log("walk attempt %d to %s stalled (%s, %d points) at %s, ControlLocked %s", attempt, tostring(target), how, #points, tostring(hrp.Position), tostring(player:GetAttribute("ControlLocked")))
	end
	log("SHORTCUT teleport to %s", tostring(target))
	teleport(target)
	task.wait(0.5)
	return true
end

-- Piloting: the Frame walks itself toward the point (FrameController's AutoWalkTo, set on this client's copy).
-- A stall (8 s without getting closer) tries a sidestep to each side, as a player steers round what's in the way.
local driveStraight
local function driveTo(token, target, radius)
	if driveStraight(token, target, radius) then
		return true
	end
	for _, side in ipairs({ 1, -1, 1, -1 }) do
		local frame = myFrame()
		if not frame or not alive(token) then
			return false
		end
		local here = frame.PrimaryPart.Position
		local toward = flat(target - here)
		if toward.Magnitude < 1 then
			return true
		end
		local across = Vector3.new(-toward.Unit.Z, 0, toward.Unit.X) * side
		log("sidestep %s", if side > 0 then "right" else "left")
		driveStraight(token, here + across * 30 + toward.Unit * 15, 8, 4)
		if driveStraight(token, target, radius) then
			return true
		end
	end
	return false
end

function driveStraight(token, target, radius, patience)
	radius = math.max(radius or 10, 8)
	local started, best = os.clock(), math.huge
	while alive(token) do
		local frame = myFrame()
		if not frame or not frame.PrimaryPart then
			return false
		end
		if context() ~= "Frame" then
			frame:SetAttribute("AutoWalkTo", nil)
			task.wait(0.25)
			started = os.clock()
			continue
		end
		local distance = (flat(frame.PrimaryPart.Position) - flat(target)).Magnitude
		if distance <= radius then
			frame:SetAttribute("AutoWalkTo", nil)
			return true
		end
		frame:SetAttribute("AutoWalkTo", target)
		if distance < best - 1 then
			best, started = distance, os.clock()
		elseif os.clock() - started > (patience or 8) then
			frame:SetAttribute("AutoWalkTo", nil)
			log("drive to %s stalled at %.0f studs (at %s)", tostring(target), distance, tostring(frame.PrimaryPart.Position))
			return false
		end
		task.wait(0.1)
	end
	return false
end

local function yawTo(from, to)
	local d = flat(to - from)
	return math.atan2(-d.X, -d.Z)
end

-- Holds a prompt for its HoldDuration once the engine shows it.
local function usePrompt(token, interactId)
	local part = find("InteractId", interactId)
	local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		log("no prompt %s", interactId)
		return false
	end
	local frameOnly = part:GetAttribute("FrameOnly") == true
	local reach = prompt.MaxActivationDistance - (if frameOnly then 20 else 1)
	if frameOnly then
		local frame = myFrame()
		if frame and (frame.PrimaryPart.Position - part.Position).Magnitude > reach and not driveTo(token, part.Position, reach) then
			log("couldn't drive into reach of %s", interactId)
		end
		-- A pad refuses a moving Frame: let it stop.
		local settle = os.clock() + 3
		while frame and frame.PrimaryPart and frame.PrimaryPart.AssemblyLinearVelocity.Magnitude > 2 and os.clock() < settle do
			task.wait(0.1)
		end
	else
		local hrp = root()
		if not hrp or (hrp.Position - part.Position).Magnitude > reach then
			walkTo(token, part.Position, math.max(2, reach - 1), function(at)
				return (at.Position - part.Position).Magnitude <= reach
			end)
		end
	end
	if not waitForControl(token, if frameOnly then "Frame" else "OnFoot") then
		return false
	end
	local shown = false
	local connection = prompt.PromptShown:Connect(function()
		shown = true
	end)
	local deadline = os.clock() + 4
	while alive(token) and not shown and os.clock() < deadline do
		local hrp = root()
		if frameOnly then
			local frame = myFrame()
			if frame then
				call("CameraController", "setYaw", yawTo(frame.PrimaryPart.Position, part.Position))
			end
		elseif hrp then
			local camera = workspace.CurrentCamera
			local away = flat(hrp.Position - part.Position)
			away = if away.Magnitude > 0.5 then away.Unit else Vector3.new(1, 0, 0)
			camera.CFrame = CFrame.lookAt(hrp.Position + away * 8 + Vector3.new(0, 5, 0), part.Position)
		end
		if prompt.Enabled and table.find(call("InteractionController", "getShown"), interactId) then
			shown = true
		end
		task.wait(0.2)
	end
	connection:Disconnect()
	if not shown then
		log("prompt %s never showed (enabled %s)", interactId, tostring(prompt.Enabled))
		return false
	end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.2)
	prompt:InputHoldEnd()
	log("used %s", interactId)
	return true
end

local function marker(id)
	local part = find("SpawnId", id) or find("TriggerId", id)
	return part and part.Position
end

----------------------------------------------------------------------------------------------------------------
-- Dialogue: advance conversation lines once typed (after a reading pause); answer choices from the plan.
----------------------------------------------------------------------------------------------------------------
local function dialogueLoop(token, plan)
	local lastNode, typedAt = nil, nil
	while alive(token) do
		local ok, d = pcall(call, "DialogueController", "getState")
		if ok and d.open then
			local key = tostring(d.dialogueId) .. ":" .. tostring(d.nodeId)
			if key ~= lastNode then
				lastNode, typedAt = key, nil
			end
			if d.choices and #d.choices > 0 then
				task.wait(0.8)
				local want = plan[d.dialogueId]
				local pick = if want and table.find(d.choices, want) then want else d.choices[1]
				call("DialogueController", "choose", pick)
				log("choice %s -> %d (of %s)", key, pick, table.concat(d.choices, ","))
				state.choicesMade[d.dialogueId] = pick
				task.wait(0.5)
			elseif d.mode == "conversation" then
				if d.typed then
					typedAt = typedAt or os.clock()
					if os.clock() - typedAt > 0.6 then
						call("DialogueController", "advance")
						typedAt = os.clock() + 0.6 -- don't press twice for the same line
					end
				end
			end
		end
		task.wait(0.2)
	end
end

----------------------------------------------------------------------------------------------------------------
-- The fight: lock on, close in, light chain; the core when it opens.
----------------------------------------------------------------------------------------------------------------
local function press(action)
	call("InputController", "press", action, true)
	task.wait(0.04)
	call("InputController", "press", action, false)
end

local function fight(token)
	local strikes = 0
	while alive(token) and state.step == "S28_STRIDER" do
		local frame = myFrame()
		local folder = workspace:FindFirstChild("Titans")
		local titan
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			if string.sub(model.Name, 1, 7) == "Strider" and model:GetAttribute("State") ~= "Dead" then -- TargetId is TITAN_n
				titan = model
			end
		end
		if not frame or not titan or not titan.PrimaryPart or context() ~= "Frame" or titan:GetAttribute("State") == "Dormant" or frame:GetAttribute("State") == "Disabled" then -- "Idle" is also its pause between attacks
			task.wait(0.3)
			continue
		end
		if not call("LockOnController", "getTarget") then
			pcall(call, "LockOnController", "toggle")
		end
		local distance = (flat(frame.PrimaryPart.Position) - flat(titan.PrimaryPart.Position)).Magnitude
		if titan:GetAttribute("CoreExposed") == true then
			frame:SetAttribute("AutoWalkTo", if distance > 40 then titan.PrimaryPart.Position else nil)
			press("CoreStrike")
			strikes += 1
			task.wait(0.25)
		elseif distance > 62 then
			frame:SetAttribute("AutoWalkTo", titan.PrimaryPart.Position)
			task.wait(0.15)
		else
			frame:SetAttribute("AutoWalkTo", nil)
			press("Light")
			task.wait(0.3)
		end
	end
	local frame = myFrame()
	if frame then
		frame:SetAttribute("AutoWalkTo", nil)
	end
	log("fight loop over (core presses %d)", strikes)
end

----------------------------------------------------------------------------------------------------------------
-- The plan, by step. Each runs once when its step comes up; steps it doesn't list need no input.
----------------------------------------------------------------------------------------------------------------
local function waitCard(token, kind)
	state.waiting = kind
	log("WAIT %s card: press Continue", kind)
	local gui = player:WaitForChild("PlayerGui")
	while alive(token) and not gui:FindFirstChild(kind, true) do
		task.wait(0.3)
	end
	while alive(token) and gui:FindFirstChild(kind, true) do
		task.wait(0.3)
	end
	state.waiting = nil
end

local STEPS = {
	S02_QUARTERS = function(token)
		walkTo(token, marker("TRG_HANGAR_REVEAL"), 3)
	end,
	S04_REVEAL = function(token)
		walkTo(token, marker("MARK_MARA_VIEW"), 8)
	end,
	S06_WALK = function(token)
		walkTo(token, marker("TRG_BRIEFING_ENTER"), 3)
	end,
	S08_BOARD = function(token)
		walkTo(token, marker("WP_BAY2_BRIDGE"), 3)
		usePrompt(token, "INT_BOARD_BAY2")
	end,
	S09_DOOR = function(token)
		driveTo(token, Vector3.new(0, 30, -120), 12) -- out of Bay 2 onto the floor first (Bay 3's barrier is in the straight line)
		driveTo(token, marker("TRG_DEPLOY_DOOR"), 8)
	end,
	S10_LAUNCH = function(token)
		driveTo(token, marker("WP_LAUNCH_CENTER"), 12)
	end,
	S20_ARRIVAL = function(token)
		driveTo(token, Vector3.new(6015, 30, 285), 10) -- the truck trigger, east of the overturned truck
		driveTo(token, Vector3.new(6010, 30, 225), 10)
		driveTo(token, marker("TRG_OP_SOUTHGATE"), 8)
	end,
	S21_SOUTH_GATE = function(token)
		usePrompt(token, "INT_BREAKER")
	end,
	S23_DISMOUNT = function(token)
		driveTo(token, marker("WP_OP_PADA"), 10)
		usePrompt(token, "PAD_A")
	end,
	S24_COMMS = function(token)
		usePrompt(token, "INT_COMMS_CONSOLE")
	end,
	S25_INVESTIGATE = function(token)
		if state.opts.evidence then
			for _, id in ipairs({ "INT_EV_LOG1", "INT_EV_LOG2", "INT_EV_LOG3" }) do
				usePrompt(token, id)
				task.wait(1)
			end
		end
		for _, id in ipairs({ "INT_CLUE_A", "INT_CLUE_B", "INT_CLUE_C" }) do
			usePrompt(token, id)
			task.wait(1.5)
		end
	end,
	S26_REMOUNT = function(token)
		usePrompt(token, "INT_BOARD_HAND02")
	end,
	S27_TRAIL = function(token)
		-- Round the bunker's east side (its FrameBarrier is in the straight line from Pad A), the north gate, then the
		-- trail's nav nodes TR0-TR5 into the basin.
		driveTo(token, Vector3.new(6055, 30, 20), 10)
		driveTo(token, Vector3.new(6055, 30, -100), 10)
		driveTo(token, marker("FRAME_OP_NORTHGATE"), 10)
		for index = 0, 5 do
			local node = find("NavId", "TR" .. index)
			if node then
				driveTo(token, node.Position, 10)
			end
		end
	end,
	S28_STRIDER = fight,
	S31_WATCHER = function(token)
		driveTo(token, marker("MARK_MARA_REGROUP"), 30)
	end,
	S32_ROVER = function(token)
		driveTo(token, marker("WP_OP_PADB"), 10)
		usePrompt(token, "PAD_B")
		usePrompt(token, "INT_ROVER_MARKING")
		task.wait(2)
		usePrompt(token, "INT_ROVER_CRADLE")
		task.wait(2)
		usePrompt(token, "INT_ROVER_CASE")
	end,
	S33_UPLOAD = function(token)
		usePrompt(token, "INT_BOARD_HAND02")
	end,
	S40_RETURN = function(token)
		waitCard(token, "MissionComplete")
	end,
	S41_MEDICAL = function(token)
		walkTo(token, marker("TRG_MED_ARCH"), 2)
	end,
	S42_EVENING = function(token)
		if state.opts.deck then
			walkTo(token, marker("MARK_MARA_DECK"), 8)
			task.wait(1)
			while alive(token) and context() ~= "OnFoot" do
				task.wait(0.3)
			end
		end
		usePrompt(token, "INT_Q3_TERMINAL")
		waitCard(token, "ChapterEnd")
	end,
}

function Autopilot.start(opts)
	running += 1
	local token = running
	state = { log = {}, step = nil, waiting = nil, done = false, error = nil, shortcuts = 0, choicesMade = {}, started = os.clock(), opts = opts or {} }
	Autopilot.state = state
	task.spawn(dialogueLoop, token, state.opts.choices or {})
	task.spawn(function()
		local handled = {}
		while alive(token) do
			local step = player:GetAttribute("DevStep")
			if step ~= state.step then
				state.step = step
				log("step")
			end
			if step == "S50_FREE_ROAM" then
				state.done = true
				log("DONE")
				break
			end
			local handler = step and STEPS[step]
			if handler and not handled[step] then
				handled[step] = true
				local ok, err = pcall(handler, token)
				if not ok then
					state.error = tostring(err)
					log("ERROR %s", tostring(err))
				end
			end
			task.wait(0.25)
		end
	end)
	return state
end

-- For trying one piece on its own: Autopilot.try("walk", Vector3) / ("prompt", interactId) / ("drive", Vector3).
function Autopilot.try(what, target, radius)
	running += 1
	local token = running
	state = { log = {}, step = player:GetAttribute("DevStep"), done = false, shortcuts = 0, choicesMade = {}, started = os.clock(), opts = {} }
	Autopilot.state = state
	local target3 = if type(target) == "string" and what ~= "prompt" then marker(target) else target
	local ok = if what == "walk" then walkTo(token, target3, radius) elseif what == "drive" then driveTo(token, target3, radius) else usePrompt(token, target)
	return ok, state
end

function Autopilot.stop()
	running += 1
	if state then
		state.done = true
	end
end

return Autopilot
