--!nonstrict
-- builders/checks/SharedCheck.lua  ->  ServerStorage.DevTools.Checks.SharedCheck
--
-- Unit cases for ReplicatedStorage.Shared.Modules (Log, Signal, Trove, Easing, MathUtil, TableUtil,
-- RateLimiter, StateMachine, Net validation and wrapping). Runs in edit mode; creates nothing in the place.
--
--   local DT = game:GetService("ServerStorage").DevTools
--   return game:GetService("HttpService"):JSONEncode(require(DT.Checks.SharedCheck:Clone()).Full())
--
-- The modules are required from an unparented clone of ReplicatedStorage.Shared, so edits are never served
-- from require's cache. Expected Output noise: the Net cases log 1 red "handler failed" line and a few
-- "rejected" warnings on purpose.

local Check = {}

local C2S = {
	"Client_Ready", "Frame_Action", "Frame_Lock", "Dialogue_Advance", "Dialogue_Choose", "Cinematic_Done",
	"Cinematic_Skip", "Tutorial_Seen", "UI_CardDone", "Shift_Request", "Shift_Special", "Settings_Update",
	"Checkpoint_Restart", "Upgrade_Buy", "Debug_Command",
}
local S2C = {
	"Server_Ready", "Seq_State", "Dialogue_Node", "Dialogue_End", "Cinematic_Play", "Combat_Feedback", "UI_Toast",
	"UI_Card", "Tutorial_Show", "Bark_Play", "Shift_Effect", "Lighting_Set", "Fade", "Music_Set", "Profile_Snapshot",
	"UI_Open", "Upgrade_Result",
}

function Check.Full()
	local startClock = os.clock()
	local report = { passed = 0, failed = 0, failures = {}, cases = {} }
	local Shared = game:GetService("ReplicatedStorage").Shared:Clone()
	local M = Shared.Modules

	local function expect(condition, label)
		if not condition then
			error("expected: " .. tostring(label), 2)
		end
	end
	local function near(actual, expected, label)
		if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
			error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
		end
	end
	local function case(name, fn)
		local ok, message = xpcall(fn, function(err)
			return tostring(err)
		end)
		table.insert(report.cases, name)
		if ok then
			report.passed += 1
		else
			report.failed += 1
			table.insert(report.failures, { case = name, error = message })
		end
	end
	local function fakeClock()
		local now = 100
		return function()
			return now
		end, function(dt)
			now += dt
		end
	end

	case("Log.format", function()
		local Log = require(M.Log)
		expect(Log.format("Tag", "x %d", 3) == "[Tag] x 3", "formatted with arguments")
		expect(Log.format("Tag", "100%") == "[Tag] 100%", "no arguments: message untouched")
		expect(Log.format("Tag", "x %d", "no") == "[Tag] x %d (bad format arguments)", "bad arguments don't throw")
	end)

	case("Signal", function()
		local Signal = require(M.Signal)
		local signal = Signal.new()
		local log = {}
		local a = signal:Connect(function(x, y)
			table.insert(log, "a" .. x .. y)
		end)
		local slow = signal:Connect(function(x)
			task.wait() -- a yielding handler must not block the next one
			table.insert(log, "slow" .. x)
		end)
		signal:Once(function(x)
			table.insert(log, "once" .. x)
		end)
		signal:Fire(1, 2)
		expect(table.concat(log, ",") == "a12,once1", "handlers ran in order, the yielding one didn't block")
		a:Disconnect()
		expect(a.Connected == false, "Connected is false after Disconnect")
		signal:Fire(3, 4)
		expect(table.concat(log, ",") == "a12,once1", "disconnected and Once handlers don't run again")
		slow:Disconnect()

		local got
		task.spawn(function()
			got = { signal:Wait() }
		end)
		signal:Fire("w", 9)
		expect(got and got[1] == "w" and got[2] == 9, "Wait returns the fired arguments")

		local count = 0
		local self2
		self2 = signal:Connect(function()
			count += 1
			self2:Disconnect()
		end)
		signal:Fire()
		signal:Fire()
		expect(count == 1, "a handler can disconnect itself while firing")
		signal:DisconnectAll()
		task.wait(0.05)
		expect(log[3] == "slow1" and log[4] == "slow3", "the yielding handler finished later")
	end)

	case("Trove", function()
		local Trove = require(M.Trove)
		local Signal = require(M.Signal)
		local trove = Trove.new()
		local order = {}
		local part = trove:add(Instance.new("Part"))
		local event = Instance.new("BindableEvent")
		local rbxConnection = trove:connect(event.Event, function() end)
		local signal = Signal.new()
		local connection = trove:connect(signal, function() end)
		trove:add(function()
			table.insert(order, "first")
		end)
		trove:add(function()
			table.insert(order, "second")
		end)
		local thread = trove:add(task.delay(60, function() end))
		local object = trove:add({ destroyed = false, destroy = function(self)
			self.destroyed = true
		end })
		local child = trove:extend()
		local childCleaned = false
		child:add(function()
			childCleaned = true
		end)
		local removed = false
		local removable = trove:add(function()
			removed = true
		end)
		expect(trove:remove(removable) and removed, "remove cleans one item now")
		expect(trove:remove(removable) == false, "remove returns false for an unknown item")
		expect(not pcall(function()
			trove:add(42)
		end), "adding a number is an error")

		trove:clean()
		expect(pcall(function()
			part.Parent = workspace
		end) == false, "the Instance was destroyed")
		expect(rbxConnection.Connected == false and connection.Connected == false, "both connections disconnected")
		expect(order[1] == "second" and order[2] == "first", "functions called in reverse order")
		expect(coroutine.status(thread) == "dead", "the thread was cancelled")
		expect(object.destroyed and childCleaned, "table.destroy and the child trove ran")
		trove:clean() -- cleaning twice is harmless
		event:Destroy()
	end)

	case("Easing", function()
		local Easing = require(M.Easing)
		expect(#Easing.names == 9, "9 ease names (docs/08 §4.2)")
		for _, name in ipairs(Easing.names) do
			near(Easing.apply(name, 0), 0, name .. "(0)")
			near(Easing.apply(name, 1), 1, name .. "(1)")
		end
		near(Easing.apply("QuadOut", 0.5), 0.75, "QuadOut(0.5)")
		near(Easing.apply("QuadIn", 0.5), 0.25, "QuadIn(0.5)")
		near(Easing.apply("SineInOut", 0.5), 0.5, "SineInOut(0.5)")
		near(Easing.apply("CubicOut", 0.5), 0.875, "CubicOut(0.5)")
		near(Easing.apply(nil, 0.3), 0.3, "nil name = Linear")
		near(Easing.apply("Linear", 7), 1, "t is clamped")
		expect(Easing.apply("BackOut", 0.7) > 1, "BackOut overshoots")
		expect(not pcall(Easing.get, "Bouncy"), "an unknown name is an error")
	end)

	case("MathUtil", function()
		local MathUtil = require(M.MathUtil)
		near(MathUtil.approach(0, 10, 3), 3, "approach up")
		near(MathUtil.approach(10, 0, 3), 7, "approach down")
		near(MathUtil.approach(9, 10, 3), 10, "approach doesn't overshoot")
		near(MathUtil.remap(5, 0, 10, 100, 200), 150, "remap")
		near(MathUtil.round(7.26, 0.5), 7.5, "round to a step")
		near(MathUtil.angleDelta(math.rad(350), math.rad(10)), math.rad(20), "angleDelta wraps forward")
		near(MathUtil.angleDelta(math.rad(10), math.rad(350)), math.rad(-20), "angleDelta wraps backward")
		expect(MathUtil.isFinite(1) and not MathUtil.isFinite(0 / 0) and not MathUtil.isFinite(math.huge)
			and not MathUtil.isFinite("1"), "isFinite")
		expect(MathUtil.isUnitVector(Vector3.new(0, 0, -1.04)) and not MathUtil.isUnitVector(Vector3.new(0, 0, -1.06))
			and not MathUtil.isUnitVector(Vector3.new(0 / 0, 0, 1)), "isUnitVector tolerance 0.05")
		local box = CFrame.new(10, 5, 0) * CFrame.Angles(0, math.rad(45), 0)
		expect(MathUtil.pointInBox(Vector3.new(10 + 3, 5, -3), box, Vector3.new(10, 2, 2)), "point along the rotated box")
		expect(not MathUtil.pointInBox(Vector3.new(10 + 3, 5, 3), box, Vector3.new(10, 2, 2)), "point across the rotated box")
		expect(MathUtil.pointInBounds(Vector3.new(1, 2, 3), Vector3.new(0, 0, 0), Vector3.new(1, 2, 3)), "bounds inclusive")
		near(MathUtil.flatDistance(Vector3.new(0, 50, 0), Vector3.new(3, 0, 4)), 5, "flatDistance ignores Y")
		near(MathUtil.studsToMeters(100), 33, "1 stud = 0.33 m")
	end)

	case("TableUtil", function()
		local TableUtil = require(M.TableUtil)
		local original = { a = 1, nested = { list = { 1, 2 } } }
		local copy = TableUtil.deepCopy(original)
		copy.nested.list[1] = 99
		expect(original.nested.list[1] == 1, "deepCopy is independent")
		local template = { a = 5, b = { c = 1, d = { 1 } }, e = true }
		local target = { a = 2, b = { c = 7 }, unknown = "keep" }
		TableUtil.reconcile(target, template)
		expect(target.a == 2 and target.b.c == 7, "existing values untouched")
		expect(target.b.d[1] == 1 and target.e == true, "missing keys filled, deep")
		expect(target.unknown == "keep", "unknown keys kept")
		target.b.d[1] = 2
		expect(template.b.d[1] == 1, "filled tables are copies")
		expect(TableUtil.deepEqual({ a = { 1, 2 } }, { a = { 1, 2 } }), "deepEqual true")
		expect(not TableUtil.deepEqual({ a = 1 }, { a = 1, b = 2 }), "deepEqual sees extra keys")
		expect(TableUtil.count({ x = true, y = true }) == 2, "count")
		expect(table.concat(TableUtil.sortedKeys({ b = 1, a = 1 }), "") == "ab", "sortedKeys")
	end)

	case("RateLimiter", function()
		local RateLimiter = require(M.RateLimiter)
		local now, advance = fakeClock()
		local limiter = RateLimiter.new(15, 20, now)
		local accepted = 0
		for _ = 1, 30 do
			if limiter:try("p1") then
				accepted += 1
			end
		end
		expect(accepted == 20, "burst of 20, then refused (got " .. accepted .. ")")
		expect(limiter:try("p2"), "keys are independent")
		advance(1)
		accepted = 0
		for _ = 1, 30 do
			if limiter:try("p1") then
				accepted += 1
			end
		end
		expect(accepted == 15, "15 tokens after 1 s (got " .. accepted .. ")")
		advance(100)
		accepted = 0
		for _ = 1, 30 do
			if limiter:try("p1") then
				accepted += 1
			end
		end
		expect(accepted == 20, "refill is capped at the burst")

		local once = RateLimiter.new(0, 1, now)
		expect(once:try("p1") and not once:try("p1"), "once per session")
		advance(10000)
		expect(not once:try("p1"), "rate 0 never refills")
		once:reset("p1")
		expect(once:try("p1"), "reset gives a fresh bucket")

		local slow = RateLimiter.new(1 / 5, 1, now)
		expect(slow:try("p1") and not slow:try("p1"), "1 per 5 s: second call refused")
		advance(4.9)
		expect(not slow:try("p1"), "still refused after 4.9 s")
		advance(0.2)
		expect(slow:try("p1"), "accepted after 5.1 s")
	end)

	case("StateMachine", function()
		local StateMachine = require(M.StateMachine)
		local now, advance = fakeClock()
		local log = {}
		local machine = StateMachine.new({
			Idle = {
				enter = function(_, from)
					table.insert(log, "enter Idle from " .. tostring(from))
				end,
				exit = function(_, to)
					table.insert(log, "exit Idle to " .. to)
				end,
				update = function(m, dt)
					m.context.ticks += dt
				end,
			},
			Attack = {
				canEnter = function(_, from, allowed)
					return allowed == true
				end,
				enter = function(_, from, _, move)
					table.insert(log, "enter Attack " .. tostring(move))
				end,
			},
		}, "Idle", { ticks = 0 }, now)
		local changed
		machine.Changed:Connect(function(to, from)
			changed = from .. ">" .. to
		end)
		expect(log[1] == "enter Idle from nil" and machine:is("Idle"), "initial enter")
		machine:update(0.5)
		expect(machine.context.ticks == 0.5, "update reaches the current state")
		advance(2)
		near(machine:timeInState(), 2, "timeInState")
		expect(machine:transition("Attack", false) == false and machine:getState() == "Idle", "canEnter refuses")
		expect(machine:transition("Attack", true, "Light1") == true, "transition accepted")
		expect(log[2] == "exit Idle to Attack" and log[3] == "enter Attack Light1", "exit, then enter with arguments")
		expect(changed == "Idle>Attack", "Changed fired (to, from)")
		near(machine:timeInState(), 0, "timeInState restarts")
		machine:update(1) -- Attack has no update: no error
		expect(not pcall(function()
			machine:transition("Missing")
		end), "an unknown state is an error")
		machine:destroy()
	end)

	case("Net.Definitions", function()
		local Net = require(M.Net)
		local count = 0
		for _ in pairs(Net.Definitions) do
			count += 1
		end
		expect(count == #C2S + #S2C, ("%d remotes (docs/16 §5 and later additions), got %d"):format(#C2S + #S2C, count))
		for _, name in ipairs(C2S) do
			local d = Net.Definitions[name]
			expect(d and d.direction == "C2S" and d.validate and d.rate and d.burst, name .. " is a complete C2S definition")
		end
		for _, name in ipairs(S2C) do
			expect(Net.Definitions[name] and Net.Definitions[name].direction == "S2C", name .. " is S2C")
		end
		local d = Net.Definitions
		expect(d.Frame_Action.rate == 15 and d.Frame_Action.burst == 20, "Frame_Action 15/s burst 20")
		expect(d.Frame_Lock.rate == 6 and d.Dialogue_Advance.rate == 10 and d.Dialogue_Choose.rate == 4, "rates")
		expect(d.Client_Ready.rate == 0 and d.Client_Ready.burst == 1, "Client_Ready once per session")
		expect(d.Checkpoint_Restart.rate == 0.2 and d.Checkpoint_Restart.burst == 1, "Checkpoint_Restart 1 per 5 s")
		expect(d.Debug_Command.studioOnly == true and d.Debug_Command.rate == 5, "Debug_Command studio only, 5/s")
		expect(not pcall(Net.fireServer, "UI_Toast", {}), "fireServer on an S2C remote is an error")
		expect(not pcall(Net.fireServer, "Nope", {}), "an unknown remote is an error")
	end)

	case("Net.validation", function()
		local Net = require(M.Net)
		local d = Net.Definitions
		local function ok(name, payload)
			return (d[name].validate(payload))
		end
		expect(ok("Frame_Action", { action = "Light", seq = 1 }), "valid without dir")
		expect(ok("Frame_Action", { action = "Dodge", dir = Vector3.new(1, 0, 0), seq = 2 }), "valid with dir")
		expect(not ok("Frame_Action", { action = "Nuke", seq = 1 }), "enum whitelist")
		expect(not ok("Frame_Action", { action = "Light", seq = 0 / 0 }), "NaN rejected")
		expect(not ok("Frame_Action", { action = "Light", seq = math.huge }), "infinity rejected")
		expect(not ok("Frame_Action", { action = "Light", seq = 1.5 }), "seq must be an integer")
		expect(not ok("Frame_Action", { action = "Light", seq = 1, dir = Vector3.new(2, 0, 0) }), "dir must be a unit vector")
		expect(not ok("Frame_Action", { action = "Light", seq = 1, damage = 9999 }), "key whitelist")
		expect(not ok("Frame_Action", { action = "Light" }), "missing field")
		expect(not ok("Frame_Action", "Light") and not ok("Frame_Action", nil), "payload must be a table")
		expect(ok("Frame_Lock", {}) and ok("Frame_Lock", { targetId = "T1", zone = "AnkleL" }), "optional fields")
		expect(not ok("Upgrade_Buy", { upgradeId = string.rep("x", 65) }), "strings over 64 rejected")
		expect(ok("Upgrade_Buy", { upgradeId = string.rep("x", 64) }), "64 characters accepted")
		expect(not ok("Dialogue_Choose", { dialogueId = "D", nodeId = "N", index = 5 }), "choice index 1-4")
		expect(ok("Settings_Update", { camSensitivity = 2.0, subtitleSize = "L", invertY = true }), "settings in range")
		expect(not ok("Settings_Update", { camSensitivity = 2.5 }), "sensitivity above 2.0")
		expect(not ok("Settings_Update", { camSensitivity = 0.1 }), "sensitivity below 0.2")
		expect(not ok("Settings_Update", { subtitleSize = "XL" }), "subtitle size whitelist")
		expect(not ok("Settings_Update", { musicVolume = "loud" }), "volume must be a number")
		expect(not ok("Settings_Update", { credits = 99999 }), "unknown setting key")
		expect(not ok("Settings_Update", {}), "an empty settings update is rejected")
		expect(ok("Debug_Command", { cmd = "tp", args = { "SPAWN_OPS" } }), "debug command")
		expect(not ok("Debug_Command", { cmd = "tp", args = { 1 } }), "args must be strings")
		expect(not ok("Debug_Command", { cmd = "tp", args = { a = "x" } }), "args must be a plain list")
		expect(not ok("Debug_Command", { cmd = "tp", args = table.create(9, "x") }), "at most 8 args")
	end)

	case("Net.wrap", function()
		local Net = require(M.Net)
		local now, advance = fakeClock()
		local player = { Name = "FakePlayer" }
		local calls = {}
		local wrapped = Net.wrap("Frame_Lock", function(who, payload)
			table.insert(calls, payload)
			if payload.zone == "boom" then
				error("handler exploded")
			end
		end, now)
		expect(wrapped(player, { targetId = "T1" }) == true and #calls == 1 and calls[1].targetId == "T1", "valid call reaches the handler")
		local accepted, reason = wrapped(player, { hack = true })
		expect(accepted == false and #calls == 1, "invalid payload never reaches the handler (" .. tostring(reason) .. ")")
		accepted, reason = wrapped(player, {}, "extra")
		expect(accepted == false and reason == "extra arguments", "extra arguments rejected")
		accepted, reason = wrapped(player, { zone = "boom" })
		expect(accepted == false and reason == "handler error", "a handler error is caught")
		for _ = 1, 10 do
			wrapped(player, {})
		end
		accepted, reason = wrapped(player, {})
		expect(accepted == false and reason == "rate limit", "6/s limit")
		advance(1)
		expect(wrapped(player, {}) == true, "accepted again after 1 s")

		local ready = Net.wrap("Client_Ready", function() end, now)
		expect(ready(player, {}) == true and select(2, ready(player, {})) == "rate limit", "Client_Ready once per session")
		expect(not pcall(Net.wrap, "UI_Toast", function() end), "wrapping an S2C remote is an error")
	end)

	case("Loader", function()
		local Loader = require(M.Loader)
		local folder = Instance.new("Folder")
		local function add(name, body)
			local module = Instance.new("ModuleScript")
			module.Name = name
			module.Source = body
			module.Parent = folder
		end
		-- Each fake service appends "<Name>.<Phase>," to the folder's Log attribute.
		local template = [[
			local M = {}
			local function note(phase)
				local folder = script.Parent
				folder:SetAttribute("Log", (folder:GetAttribute("Log") or "") .. script.Name .. "." .. phase .. ",")
			end
			function M.Init() note("Init") end
			function M.Start() note("Start") end
			return M
		]]
		add("B", template)
		add("A", template)
		local names = Loader.run("Test", folder, { "A", "Missing", "B" })
		expect(table.concat(names, ",") == "A,B", "loaded in list order, missing modules skipped")
		expect(folder:GetAttribute("Log") == "A.Init,B.Init,A.Start,B.Start,", "Init on all, then Start on all: " .. tostring(folder:GetAttribute("Log")))

		add("C", "local M = {} function M.Init() error('init exploded') end return M")
		local ok, message = pcall(Loader.run, "Test", folder, { "A", "B", "C" })
		expect(not ok and string.find(message, "[Test] C.Init failed", 1, true) and string.find(message, "init exploded", 1, true),
			"a failing Init names the module: " .. tostring(message))
		ok, message = pcall(Loader.run, "Test", folder, { "A", "B" })
		expect(not ok and string.find(message, "[Test] C failed: it isn't in the load order list", 1, true),
			"a module outside the order list is an error: " .. tostring(message))
		folder.C:Destroy()
		add("D", "return 5")
		ok, message = pcall(Loader.run, "Test", folder, { "A", "B", "D" })
		expect(not ok and string.find(message, "[Test] require D failed", 1, true), "a module must return a table: " .. tostring(message))
		folder:Destroy()
	end)

	Shared:Destroy()
	report.total = report.passed + report.failed
	report.ms = math.floor((os.clock() - startClock) * 1000 + 0.5)
	return report
end

return Check
