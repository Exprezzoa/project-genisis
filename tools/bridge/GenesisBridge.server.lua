--!nonstrict
-- tools/bridge/GenesisBridge.server.lua  ->  a local Studio plugin (install: tools/bridge/README.md)
--
-- Genesis Bridge lets a Claude cloud session work in this place without the Studio MCP (D-104).
-- GitHub is the mailbox:
--   1. Claude pushes code and a job file `bridge/job.lua` to the work branch.
--   2. This plugin watches the branch. When `bridge/job.lua` carries a new `-- job: <id>` first line,
--      it runs the job in Studio (edit mode, plugin permissions, like the MCP's run-code tool).
--   3. It uploads a report (return value, Output lines, errors, push results) to
--      `reports/<id>.json` on the reports branch, where Claude reads it.
--
-- The job file is a ModuleScript body: it returns a value, or a function that is called with `ctx`
-- (see makeCtx below and tools/bridge/README.md for the ctx API).

local BRIDGE_VERSION = "1.0.0"
local JOB_PATH = "bridge/job.lua"
local REPORT_DIR = "reports"
local MAX_REPORT_BYTES = 650000 -- before base64; GitHub's contents API takes up to about 1 MB
local MAX_LOG_LINES = 3000

----------------------------------------------------------------------------------------------------
-- Pure helpers (no Roblox services; tested with the Luau CLI by tools/bridge/test.luau)
----------------------------------------------------------------------------------------------------

local Pure = {}

-- Bytes and adler32 of a source with CRLF normalized, the same sum as tools/studio_helpers.lua
-- and tools/checksum.ps1 (D-014).
function Pure.sum(text: string): (number, number)
	text = string.gsub(text, "\r\n", "\n")
	local a, b = 1, 0
	for i = 1, #text do
		a = (a + string.byte(text, i)) % 65521
		b = (b + a) % 65521
	end
	return #text, b * 65536 + a
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_CHARS = {}
for i = 1, 64 do
	B64_CHARS[i - 1] = string.sub(B64, i, i)
end

function Pure.base64(s: string): string
	local out = table.create(math.ceil(#s / 3))
	for i = 1, #s, 3 do
		local a, b, c = string.byte(s, i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = B64_CHARS[bit32.rshift(n, 18)]
		local c2 = B64_CHARS[bit32.band(bit32.rshift(n, 12), 63)]
		local c3 = if b then B64_CHARS[bit32.band(bit32.rshift(n, 6), 63)] else "="
		local c4 = if c then B64_CHARS[bit32.band(n, 63)] else "="
		out[#out + 1] = c1 .. c2 .. c3 .. c4
	end
	return table.concat(out)
end

-- "central_command" -> "CentralCommand", "outpost07" -> "Outpost07", "BuildKit" stays.
function Pure.pascal(seg: string): string
	local s = string.gsub(seg, "_(%w)", string.upper)
	s = string.gsub(s, "^%l", string.upper)
	return s
end

local KIND_BY_SUFFIX = {
	{ ".server.lua", "Server" },
	{ ".client.lua", "Client" },
	{ ".lua", "Module" },
}

-- Repo file -> Studio path (array of names, the first is a service) and kind ("Module"|"Server"|"Client").
-- src/ follows docs/16 §2; builders/ follows builders/README.md ("Local <-> Studio").
function Pure.map(file: string): ({ string }?, string)
	local segs = string.split(file, "/")
	local last = segs[#segs]
	local base, kind
	for _, pair in ipairs(KIND_BY_SUFFIX) do
		local suffix = pair[1]
		if #last > #suffix and string.sub(last, -#suffix) == suffix then
			base = string.sub(last, 1, -#suffix - 1)
			kind = pair[2]
			break
		end
	end
	if not base then
		return nil, "not a .lua file"
	end
	local names = {}
	for i = 2, #segs - 1 do
		table.insert(names, segs[i])
	end
	if base ~= "init" then
		table.insert(names, base)
	end
	if #names == 0 then
		return nil, "no instance name"
	end

	if segs[1] == "src" then
		if #names < 2 then
			return nil, "src file must sit under a service folder"
		end
		return names, kind
	elseif segs[1] == "builders" then
		local head = table.remove(names, 1)
		local path
		if head == "lib" then
			path = { "ServerStorage", "DevTools" }
		elseif head == "checks" then
			path = { "ServerStorage", "DevTools", "Checks" }
		elseif head == "tools" then
			path = { "ServerStorage", "DevTools", "Tools" }
		elseif head == "maps" then
			path = { "ServerStorage", "DevTools", "Builders" }
		elseif head then
			path = { "ServerStorage", "DevTools", "Builders", Pure.pascal(head) }
		end
		if not path or #names == 0 then
			return nil, "builders file must sit in a builders subfolder"
		end
		for _, n in ipairs(names) do
			table.insert(path, Pure.pascal(n))
		end
		return path, "Module"
	end
	return nil, "only src/ and builders/ map to Studio"
end

-- The job id from the first line: "-- job: 0001-hello"
function Pure.jobId(text: string): string?
	return string.match(text, "^%s*%-%-%s*job:%s*([%w%._%-]+)")
end

-- Make any value safe for HttpService:JSONEncode (no mixed tables, NaN, functions, instances).
function Pure.jsonSafe(v: any, depth: number?): any
	depth = depth or 0
	local t = typeof(v)
	if t == "nil" or t == "boolean" or t == "string" then
		return v
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return tostring(v)
		end
		return v
	elseif t == "table" then
		if depth >= 8 then
			return "<table: too deep>"
		end
		local n = #v
		local count = 0
		for _ in pairs(v) do
			count += 1
		end
		if count == n and n > 0 then
			local arr = table.create(math.min(n, 2000))
			for i = 1, math.min(n, 2000) do
				arr[i] = Pure.jsonSafe(v[i], depth + 1)
			end
			if n > 2000 then
				table.insert(arr, "<" .. (n - 2000) .. " more>")
			end
			return arr
		end
		local obj = {}
		local kept = 0
		for k, val in pairs(v) do
			kept += 1
			if kept > 2000 then
				obj["<more>"] = (count - 2000) .. " more keys"
				break
			end
			obj[tostring(k)] = Pure.jsonSafe(val, depth + 1)
		end
		if count == 0 then
			return {} -- encodes as []
		end
		return obj
	elseif t == "Instance" then
		return "<" .. v.ClassName .. "> " .. v:GetFullName()
	end
	return tostring(v)
end

if plugin == nil then
	return Pure -- loaded by the test script, not by Studio
end

----------------------------------------------------------------------------------------------------
-- Plugin
----------------------------------------------------------------------------------------------------

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

if not RunService:IsEdit() then
	return -- play-test copies of the place don't run jobs
end

local function getSetting(key, default)
	local ok, v = pcall(plugin.GetSetting, plugin, key)
	if ok and v ~= nil then
		return v
	end
	return default
end
local function setSetting(key, value)
	pcall(plugin.SetSetting, plugin, key, value)
end

local cfg = {
	owner = getSetting("owner", "Exprezzoa"),
	repo = getSetting("repo", "project-genisis"),
	branch = getSetting("branch", "claude/yo-0sxhcv"),
	reportBranch = getSetting("reportBranch", "bridge-reports"),
	token = getSetting("token", ""),
	poll = getSetting("poll", 10),
	watching = getSetting("watching", false),
	lastJob = getSetting("lastJob", ""),
}

-- UI is built further down; until then status goes to Output.
local setStatus = function(text)
	print("[GenesisBridge] " .. text)
end
local history = {}
local function addHistory(line)
	table.insert(history, 1, os.date("%H:%M:%S") .. "  " .. line)
	while #history > 8 do
		table.remove(history)
	end
end

------------------------------------------------------------------ GitHub

local function repoPath()
	return "/repos/" .. cfg.owner .. "/" .. cfg.repo
end

local function encodePath(path)
	local segs = string.split(path, "/")
	for i, s in ipairs(segs) do
		segs[i] = HttpService:UrlEncode(s)
	end
	return table.concat(segs, "/")
end

local function gh(method, path, body, accept)
	local req = {
		Url = "https://api.github.com" .. path,
		Method = method,
		Headers = {
			Authorization = "Bearer " .. cfg.token,
			Accept = accept or "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
		},
	}
	if body then
		req.Body = HttpService:JSONEncode(body)
		req.Headers["Content-Type"] = "application/json"
	end
	local ok, res = pcall(HttpService.RequestAsync, HttpService, req)
	if not ok then
		return nil, tostring(res)
	end
	return res
end

local function httpError(res, err)
	if not res then
		return err
	end
	return "HTTP " .. res.StatusCode .. ": " .. string.sub(res.Body or "", 1, 300)
end

local function headSha(branch)
	local res, err = gh("GET", repoPath() .. "/git/ref/heads/" .. branch)
	if not res or res.StatusCode ~= 200 then
		return nil, httpError(res, err)
	end
	return HttpService:JSONDecode(res.Body).object.sha
end

local function fetchFile(path, ref)
	local res, err = gh(
		"GET",
		repoPath() .. "/contents/" .. encodePath(path) .. "?ref=" .. HttpService:UrlEncode(ref),
		nil,
		"application/vnd.github.raw+json"
	)
	if not res then
		return nil, err
	end
	if res.StatusCode == 404 then
		return nil, "not found"
	end
	if res.StatusCode ~= 200 then
		return nil, httpError(res)
	end
	return res.Body
end

local function listFiles(ref, pattern)
	local res, err = gh("GET", repoPath() .. "/git/trees/" .. ref .. "?recursive=1")
	if not res or res.StatusCode ~= 200 then
		return nil, httpError(res, err)
	end
	local out = {}
	for _, entry in ipairs(HttpService:JSONDecode(res.Body).tree) do
		if entry.type == "blob" and (not pattern or string.match(entry.path, pattern)) then
			table.insert(out, entry.path)
		end
	end
	return out
end

------------------------------------------------------------------ Studio side

local KIND_CLASS = { Module = "ModuleScript", Server = "Script", Client = "LocalScript" }

local function serviceOrChild(name)
	local ok, svc = pcall(game.GetService, game, name)
	if ok and svc then
		return svc
	end
	return game:FindFirstChild(name)
end

local function findPath(path)
	local names = if type(path) == "table" then path else string.split(path, ".")
	local current = serviceOrChild(names[1])
	for i = 2, #names do
		if not current then
			return nil
		end
		current = current:FindFirstChild(names[i])
	end
	return current
end

local function dump(inst, maxDepth, out, depth)
	out = out or {}
	depth = depth or 0
	maxDepth = maxDepth or 2
	local line = string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]"
	local children = inst:GetChildren()
	if depth >= maxDepth then
		if #children > 0 then
			line ..= " (" .. #children .. " children)"
		end
		table.insert(out, line)
		return out
	end
	table.insert(out, line)
	table.sort(children, function(x, y)
		return x.Name < y.Name
	end)
	for _, child in ipairs(children) do
		if #out > 4000 then
			table.insert(out, "<dump cut at 4000 lines>")
			break
		end
		dump(child, maxDepth, out, depth + 1)
	end
	return out
end

-- Write one repo file into its Studio instance.
-- item: "path" or { file = "path", expect = <sum>, force = true, target = "Service.A.B", kind = "Module" }
-- Overwrites an existing, different source only when `expect` equals its current sum or `force` is set,
-- so hand edits made in Studio are never lost silently (CLAUDE.md §1.5).
local function pushOne(item, sha)
	if type(item) == "string" then
		item = { file = item }
	end
	local file = item.file or item[1]
	local r = { file = file }
	local names, kind
	if item.target then
		names, kind = string.split(item.target, "."), item.kind or "Module"
	else
		local mapped, k = Pure.map(file)
		if not mapped then
			r.status, r.detail = "error", k
			return r
		end
		names, kind = mapped, item.kind or k
	end
	r.target = table.concat(names, ".")
	local className = KIND_CLASS[kind]
	if not className then
		r.status, r.detail = "error", "unknown kind " .. tostring(kind)
		return r
	end
	local text, err = fetchFile(file, sha)
	if not text then
		r.status, r.detail = "error", err
		return r
	end
	r.bytes, r.sum = Pure.sum(text)

	local current = serviceOrChild(names[1])
	if not current then
		r.status, r.detail = "error", "no service " .. names[1]
		return r
	end
	for i = 2, #names - 1 do
		local child = current:FindFirstChild(names[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = names[i]
			child.Parent = current
			r.createdFolders = (r.createdFolders or 0) + 1
		end
		current = child
	end
	local name = names[#names]
	local inst = current:FindFirstChild(name)
	if inst then
		if inst.ClassName ~= className then
			r.status, r.detail = "error", "is a " .. inst.ClassName .. ", expected " .. className
			return r
		end
		local oldBytes, oldSum = Pure.sum(inst.Source)
		r.before = oldSum
		if oldSum == r.sum and oldBytes == r.bytes then
			r.status = "unchanged"
			return r
		end
		local allowed = item.force or (item.expect ~= nil and item.expect == oldSum)
		if not allowed then
			r.status = "conflict"
			r.detail = if item.expect ~= nil
				then "Studio source sum is " .. oldSum .. ", expected " .. tostring(item.expect)
				else "Studio source differs; give expect = <its sum> or force = true"
			if item.withSource ~= false then
				r.studioSource = inst.Source
			end
			return r
		end
		inst.Source = text
		r.status = "updated"
	else
		inst = Instance.new(className)
		inst.Name = name
		inst.Source = text
		inst.Parent = current
		r.status = "created"
	end
	return r
end

local function makeCtx(sha, report)
	local ctx = {}
	ctx.commit = sha
	ctx.version = BRIDGE_VERSION
	ctx.sum = Pure.sum
	ctx.map = Pure.map
	ctx.find = findPath

	function ctx.fetch(path, ref)
		local text, err = fetchFile(path, ref or sha)
		if not text then
			error("fetch " .. path .. ": " .. tostring(err), 2)
		end
		return text
	end

	-- Repo files at this commit whose path matches a Lua pattern, e.g. "^builders/.*%.lua$".
	function ctx.files(pattern)
		local list, err = listFiles(sha, pattern)
		if not list then
			error("list files: " .. tostring(err), 2)
		end
		return list
	end

	-- Push repo files into Studio. Returns one result per item; also recorded in the report.
	function ctx.push(items)
		if type(items) ~= "table" or items.file then
			items = { items }
		end
		local results = {}
		for _, item in ipairs(items) do
			local ok, r = pcall(pushOne, item, sha)
			if not ok then
				r = { file = tostring(item.file or item), status = "error", detail = tostring(r) }
			end
			table.insert(results, r)
			table.insert(report.pushes, r)
		end
		return results
	end

	-- Studio's current bytes and sum for repo files (to compare with the repo before pushing).
	function ctx.studioSums(files)
		local out = {}
		for _, file in ipairs(files) do
			local names, kind = Pure.map(file)
			local row = { file = file }
			if not names then
				row.status = "unmapped"
			else
				row.target = table.concat(names, ".")
				local inst = findPath(names)
				if not inst then
					row.status = "missing"
				elseif not inst:IsA("LuaSourceContainer") then
					row.status = "not a script: " .. inst.ClassName
				else
					row.status = if inst.ClassName == KIND_CLASS[kind] then "ok" else "class " .. inst.ClassName
					row.bytes, row.sum = Pure.sum(inst.Source)
				end
			end
			table.insert(out, row)
		end
		return out
	end

	function ctx.dump(inst, maxDepth)
		return dump(inst, maxDepth)
	end

	-- Require a fresh copy so an edited module is never served from require's cache (builders/README.md).
	function ctx.requireFresh(inst)
		if type(inst) == "string" then
			inst = findPath(inst) or error("no instance " .. inst, 2)
		end
		return require(inst:Clone())
	end

	function ctx.note(value)
		table.insert(report.notes, Pure.jsonSafe(value))
	end

	-- Run a play test and return what the test passes to StudioTestService:EndTest (it waits until then).
	function ctx.playtest(args)
		local StudioTestService = game:GetService("StudioTestService")
		return StudioTestService:ExecutePlayModeAsync(args)
	end

	return ctx
end

local function encodeReport(report)
	local ok, body = pcall(HttpService.JSONEncode, HttpService, report)
	if not ok then
		report.result = "<result could not be encoded: " .. tostring(body) .. ">"
		body = HttpService:JSONEncode(report)
	end
	if #body <= MAX_REPORT_BYTES then
		return body
	end
	-- Too big: drop Studio sources from conflicts, then keep the last 300 log lines, then the result.
	for _, r in ipairs(report.pushes) do
		if r.studioSource then
			r.studioSource = "<cut: report too large>"
		end
	end
	body = HttpService:JSONEncode(report)
	if #body > MAX_REPORT_BYTES and #report.logs > 300 then
		local kept = {}
		for i = #report.logs - 299, #report.logs do
			table.insert(kept, report.logs[i])
		end
		report.logs = kept
		report.logsCut = true
		body = HttpService:JSONEncode(report)
	end
	if #body > MAX_REPORT_BYTES then
		report.result = "<cut: result too large (" .. #body .. " bytes)>"
		body = HttpService:JSONEncode(report)
	end
	return body
end

local function runJob(source, jobId, sha)
	local report = {
		bridge = BRIDGE_VERSION,
		job = jobId,
		commit = sha,
		place = game.Name,
		placeId = game.PlaceId,
		started = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		logs = {},
		notes = {},
		pushes = {},
	}
	local logs = report.logs
	local conn = LogService.MessageOut:Connect(function(message, messageType)
		if #logs < MAX_LOG_LINES then
			table.insert(logs, messageType.Name .. ": " .. message)
		end
	end)

	local recording
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Genesis Bridge job " .. jobId)
	end)

	local ctx = makeCtx(sha, report)
	local mod = Instance.new("ModuleScript")
	mod.Name = "BridgeJob_" .. jobId
	local t0 = os.clock()
	local ok, result = xpcall(function()
		mod.Source = source
		local value = require(mod)
		if type(value) == "function" then
			return value(ctx)
		end
		return value
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	report.ms = math.floor((os.clock() - t0) * 1000)

	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end)
	end

	task.wait(0.3) -- let the last Output lines arrive
	conn:Disconnect()
	mod:Destroy()

	report.ok = ok
	if ok then
		report.result = Pure.jsonSafe(result)
	else
		report.error = result
	end
	return report
end

local function ensureReportBranch()
	if headSha(cfg.reportBranch) then
		return true
	end
	local base, err = headSha(cfg.branch)
	if not base then
		return false, err
	end
	local res, e = gh("POST", repoPath() .. "/git/refs", { ref = "refs/heads/" .. cfg.reportBranch, sha = base })
	if not res or res.StatusCode ~= 201 then
		return false, httpError(res, e)
	end
	return true
end

local function uploadReport(jobId, report)
	local body = encodeReport(report)
	local path = REPORT_DIR .. "/" .. jobId .. ".json"
	local url = repoPath() .. "/contents/" .. encodePath(path)
	local okBranch, berr = ensureReportBranch()
	if not okBranch then
		return false, "reports branch: " .. tostring(berr)
	end
	local existingSha
	local res = gh("GET", url .. "?ref=" .. HttpService:UrlEncode(cfg.reportBranch))
	if res and res.StatusCode == 200 then
		existingSha = HttpService:JSONDecode(res.Body).sha
	end
	local put, err = gh("PUT", url, {
		message = "Studio report " .. jobId .. (if report.ok then "" else " (error)"),
		content = Pure.base64(body),
		branch = cfg.reportBranch,
		sha = existingSha,
	})
	if not put or (put.StatusCode ~= 200 and put.StatusCode ~= 201) then
		return false, httpError(put, err)
	end
	return true
end

------------------------------------------------------------------ Watch loop

local busy = false
local lastSeenSha = nil
local alive = true

local function short(sha)
	return string.sub(sha or "?", 1, 7)
end

local function checkOnce(rerun)
	if busy then
		return
	end
	if cfg.token == "" then
		setStatus("Paste a GitHub token and press Save.")
		return
	end
	busy = true
	local ok, err = pcall(function()
		local sha, e = headSha(cfg.branch)
		if not sha then
			error("branch " .. cfg.branch .. ": " .. tostring(e))
		end
		if sha == lastSeenSha and not rerun then
			return
		end
		lastSeenSha = sha
		local text, fe = fetchFile(JOB_PATH, sha)
		if not text then
			if fe == "not found" then
				setStatus("Watching " .. short(sha) .. ". No job file yet.")
				return
			end
			error(fe)
		end
		local id = Pure.jobId(text)
		if not id then
			setStatus("bridge/job.lua has no '-- job: <id>' first line.")
			return
		end
		if id == cfg.lastJob and not rerun then
			setStatus("Watching " .. short(sha) .. ". Last job: " .. id)
			return
		end
		-- Marked before running, so a job that crashes Studio isn't run again on restart.
		cfg.lastJob = id
		setSetting("lastJob", id)
		setStatus("Running job " .. id .. " ...")
		local report = runJob(text, id, sha)
		setStatus("Uploading report " .. id .. " ...")
		local up, ue = uploadReport(id, report)
		if up then
			addHistory(id .. (if report.ok then "  ok" else "  ERROR") .. "  " .. report.ms .. " ms")
			setStatus("Job " .. id .. (if report.ok then " done." else " failed (see report).") .. " Report uploaded.")
		else
			addHistory(id .. "  report upload failed")
			setStatus("Job " .. id .. " ran, but the report upload failed: " .. tostring(ue))
		end
	end)
	busy = false
	if not ok then
		setStatus("Error: " .. tostring(err))
	end
end

------------------------------------------------------------------ UI

local toolbar = plugin:CreateToolbar("Genesis Bridge")
local button = toolbar:CreateButton("Bridge", "Open Genesis Bridge (Claude via GitHub)", "")
button.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"GenesisBridge",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 420, 280, 320)
)
widget.Title = "Genesis Bridge"
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local function themeColor(style, fallback)
	local ok, c = pcall(function()
		return settings().Studio.Theme:GetColor(style)
	end)
	return if ok and c then c else fallback
end
local BG = themeColor(Enum.StudioStyleGuideColor.MainBackground, Color3.fromRGB(46, 46, 46))
local FG = themeColor(Enum.StudioStyleGuideColor.MainText, Color3.fromRGB(230, 230, 230))
local FIELD = themeColor(Enum.StudioStyleGuideColor.InputFieldBackground, Color3.fromRGB(37, 37, 37))
local BTN = themeColor(Enum.StudioStyleGuideColor.Button, Color3.fromRGB(60, 60, 60))

local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = BG
root.BorderSizePixel = 0
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.new()
root.ScrollBarThickness = 6
root.Parent = widget
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
pad.Parent = root
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = root

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function label(text, height)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height or 16)
	l.AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextColor3 = FG
	l.Font = Enum.Font.SourceSans
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Text = text
	l.LayoutOrder = nextOrder()
	l.Parent = root
	return l
end

local function field(name, value, placeholder)
	local title = label(name)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 24)
	box.BackgroundColor3 = FIELD
	box.BorderSizePixel = 0
	box.TextColor3 = FG
	box.PlaceholderText = placeholder or ""
	box.Font = Enum.Font.Code
	box.TextSize = 13
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = value
	box.LayoutOrder = nextOrder()
	box.Parent = root
	return box, title
end

local function btn(text, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = BTN
	b.BorderSizePixel = 0
	b.TextColor3 = FG
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 15
	b.Text = text
	b.LayoutOrder = nextOrder()
	b.Parent = root
	b.MouseButton1Click:Connect(function()
		task.spawn(onClick)
	end)
	return b
end

local statusLabel = label("", nil)
statusLabel.Font = Enum.Font.SourceSansBold
local historyLabel = label("", nil)
historyLabel.Font = Enum.Font.Code
historyLabel.TextSize = 12

local function tokenHint()
	if cfg.token == "" then
		return "no token saved"
	end
	return "token saved (ends …" .. string.sub(cfg.token, -4) .. ")"
end

local ownerBox = field("Owner", cfg.owner)
local repoBox = field("Repository", cfg.repo)
local branchBox = field("Work branch (jobs come from here)", cfg.branch)
local reportBox = field("Reports branch", cfg.reportBranch)
local tokenBox, tokenTitle = field("GitHub token (" .. tokenHint() .. ")", "", "paste a new token here, then Save")

local watchButton

local function refresh()
	historyLabel.Text = if #history > 0 then table.concat(history, "\n") else "No jobs run in this session."
	tokenTitle.Text = "GitHub token (" .. tokenHint() .. ")"
	watchButton.Text = if cfg.watching then "Stop watching" else "Start watching (runs jobs automatically)"
end

setStatus = function(text)
	statusLabel.Text = text
	print("[GenesisBridge] " .. text)
	refresh()
end

btn("Save settings", function()
	cfg.owner = ownerBox.Text
	cfg.repo = repoBox.Text
	cfg.branch = branchBox.Text
	cfg.reportBranch = reportBox.Text
	if tokenBox.Text ~= "" then
		cfg.token = string.gsub(tokenBox.Text, "%s", "")
		tokenBox.Text = ""
	end
	for _, key in ipairs({ "owner", "repo", "branch", "reportBranch", "token" }) do
		setSetting(key, cfg[key])
	end
	lastSeenSha = nil
	setStatus("Settings saved.")
end)

watchButton = btn("", function()
	cfg.watching = not cfg.watching
	setSetting("watching", cfg.watching)
	lastSeenSha = nil
	setStatus(if cfg.watching then "Watching " .. cfg.branch .. " every " .. cfg.poll .. " s." else "Stopped.")
	if cfg.watching then
		checkOnce(false)
	end
end)

btn("Check now", function()
	lastSeenSha = nil
	checkOnce(false)
end)

btn("Run the current job again", function()
	checkOnce(true)
end)

label("Genesis Bridge " .. BRIDGE_VERSION .. ". Jobs run with plugin permissions in this place. Undo a job with Ctrl+Z. Keep only one place with the bridge watching at a time.")

setStatus(if cfg.watching then "Watching " .. cfg.branch .. "." else "Not watching. Press Start watching.")

plugin.Unloading:Connect(function()
	alive = false
end)

task.spawn(function()
	while alive do
		if cfg.watching then
			checkOnce(false)
		end
		task.wait(math.max(5, cfg.poll))
	end
end)
