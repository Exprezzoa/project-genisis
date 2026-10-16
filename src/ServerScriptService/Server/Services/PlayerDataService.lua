--!strict
-- Server/Services/PlayerDataService.lua  (docs/17_saving_progression_monetization.md §1-5)
--
-- Profiles: load with a session lock, migrate, reconcile with the defaults, autosave, save on leave and on
-- shutdown. Schema v1, DataStore "PG_Profiles_v1", key "u_<UserId>".
--
--   getProfile(player) -> profile?            waitForProfile(player, timeout) -> profile?
--   update(player, fn)                        -- fn(profile) changes the data; marks it dirty
--   saveNow(player, reason) -> boolean        -- yields; false = nothing was written
--   shutdown() -> pending                     -- the BindToClose save of every profile (yields)
--   Loaded(player, profile)                   -- fires once per player, also for read-only profiles
--
-- Never overwrites stored data after a failed load: such a profile is readOnly for the session.
-- Without Studio API access the service runs memory-only and says so loudly.
--
-- Studio-only test switches, attributes on ServerScriptService.Server (ignored in live servers):
--   TestMemoryOnly = true         run memory-only even though the API is available
--   TestDataStoreFailure = true   every DataStore call fails from the start (same as /dsfail on)
--   TestFastRetries = true        retry delays of 0.2 s instead of 1, 2, 4, 8 s

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local TableUtil = require(Shared.Modules.TableUtil)
local Types = require(Shared.Modules.Types)

local TAG = "PlayerDataService"
local Migrations = require(script.Parent.Parent.Data.Migrations)

local CURRENT_VERSION = Migrations.CURRENT_VERSION
local Config = GameConfig.Data
local IS_STUDIO = RunService:IsStudio()
local LOAD_FAILED_TOAST = "Couldn't load your save. Progress this session won't be saved."

type Profile = Types.Profile
type Entry = {
	data: Profile,
	readOnly: boolean,
	dirty: boolean,
	saving: boolean,
	released: boolean,
	lastWrite: number,
	lastAutosave: number,
	playClock: number,
	snapshotQueued: boolean,
}

local PlayerDataService = {}

PlayerDataService.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
-- Fires (player, written, reason) after every save attempt.
PlayerDataService.Saved = Signal.new() :: Signal.Signal<Player, boolean, string>

-- Studio play sessions have an empty JobId, so each one gets its own id for the session lock.
local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local store: DataStore? = nil
local memoryOnly = false
local simulateFailure = false
local retryDelays: { number } = Config.RETRY_DELAYS
local entries: { [Player]: Entry } = {}

local function defaultProfile(): Profile
	local settings = {}
	for key, spec in pairs(GameConfig.Settings :: { [string]: any }) do
		settings[key] = spec.default
	end
	return {
		schemaVersion = CURRENT_VERSION,
		createdAt = os.time(),
		lastSaveAt = 0,
		saveCount = 0,
		_lock = nil,
		story = { chapter = 1, sequenceId = "CH1", checkpoint = nil, flags = {}, completedChapters = {}, relLog = {} },
		relationships = { mara = 0, vale = 0, voss = 0, orin = -1 },
		evidence = {},
		progression = { xp = 0, rank = 1, credits = 0, grants = {}, upgrades = {} },
		cosmetics = { owned = {}, equipped = { framePaint = "DEFAULT", suit = "DEFAULT" } },
		settings = settings :: any,
		purchases = { receipts = {} },
		stats = { titansDefeated = 0, framesDisabled = 0, playTimeSec = 0 },
	}
end

local function keyFor(player: Player): string
	return Config.KEY_PREFIX .. player.UserId
end

local function updateAsync(key: string, transform: (stored: any) -> any): any
	if simulateFailure then
		error("simulated DataStore failure")
	end
	return (store :: DataStore):UpdateAsync(key, transform)
end

-- docs/17 §5: 5 attempts with exponential backoff and jitter; every failure is logged.
local function withRetries(what: string, player: Player, call: () -> any): (boolean, any)
	local attempts = #retryDelays
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(call)
		if ok then
			return true, result
		end
		lastError = result
		Log.warn(TAG, "%s for %s failed (attempt %d/%d): %s", what, player.Name, attempt, attempts, tostring(result))
		if attempt < attempts then
			task.wait(retryDelays[attempt] + math.random() * Config.RETRY_JITTER)
		end
	end
	return false, lastError
end

local function newEntry(): Entry
	local now = os.clock()
	return {
		data = defaultProfile(),
		readOnly = false,
		dirty = false,
		saving = false,
		released = false,
		lastWrite = 0,
		lastAutosave = now,
		playClock = now,
		snapshotQueued = false,
	}
end

-- docs/17 §3. Yields. Always returns an entry; entry.readOnly = true when the stored data couldn't be loaded.
local function load(player: Player): Entry
	local entry = newEntry()
	if memoryOnly then
		return entry
	end
	local key = keyFor(player)
	local steal = false
	local tries = 0
	while true do
		tries += 1
		local lockedBy: string? = nil
		local ok, result = withRetries("Load", player, function()
			return updateAsync(key, function(stored)
				lockedBy = nil
				local data = stored or defaultProfile()
				local lock = data._lock
				if not steal and lock and lock.jobId ~= sessionId and os.time() - lock.time < Config.LOCK_TIMEOUT then
					lockedBy = lock.jobId
					return nil -- another server holds the session: don't write
				end
				data._lock = { jobId = sessionId, time = os.time() }
				return data
			end)
		end)
		if not ok then
			entry.readOnly = true
			Log.warn(TAG, "couldn't load the profile of %s; this session is read-only", player.Name)
			return entry
		end
		if not lockedBy then
			if type(result) == "table" and Migrations.run(result, defaultProfile()) then
				entry.data = result
			else
				entry.readOnly = true
				Log.warn(TAG, "the stored profile of %s has an unknown schema; this session is read-only", player.Name)
			end
			return entry
		end
		if player.Parent == nil then
			entry.readOnly = true
			return entry
		end
		Log.debug(TAG, "profile of %s is locked by %s (try %d/%d)", player.Name, lockedBy :: string, tries, Config.LOCK_TRIES)
		task.wait(Config.LOCK_WAIT)
		if tries >= Config.LOCK_TRIES then
			Log.warn(TAG, "stealing the session lock of %s from %s after %d tries", player.Name, lockedBy :: string, tries)
			steal = true
		end
	end
end

-- docs/17 §4. Yields. Writes only while this server still holds the lock; release = the final save.
local function write(player: Player, entry: Entry, release: boolean): boolean
	if memoryOnly or entry.readOnly then
		return false
	end
	local now = os.clock()
	entry.data.stats.playTimeSec += math.floor(now - entry.playClock)
	entry.playClock = now

	local snapshot = TableUtil.deepCopy(entry.data)
	snapshot.lastSaveAt = os.time()
	snapshot.saveCount += 1
	snapshot._lock = if release then nil else { jobId = sessionId, time = os.time() }
	entry.dirty = false -- changes made while the write is in flight set it again

	local foreign: string? = nil
	local ok = withRetries("Save", player, function()
		return updateAsync(keyFor(player), function(stored)
			foreign = nil
			local lock = stored and stored._lock
			if not lock or lock.jobId ~= sessionId then
				foreign = if lock then lock.jobId else "nobody"
				return nil
			end
			return snapshot
		end)
	end)
	entry.lastWrite = os.clock()
	if ok and not foreign then
		entry.data.lastSaveAt = snapshot.lastSaveAt
		entry.data.saveCount = snapshot.saveCount
		return true
	end
	entry.dirty = true
	if foreign then
		Log.error(TAG, "save of %s aborted: the session lock belongs to %s; nothing was written", player.Name, foreign :: string)
		entry.readOnly = true
	end
	return false
end

local function sendSnapshot(player: Player)
	local entry = entries[player]
	if not entry or not player:GetAttribute("ClientReady") then
		return
	end
	local data = entry.data
	Net.fireClient(player, "Profile_Snapshot", {
		settings = data.settings,
		rank = data.progression.rank,
		xp = data.progression.xp,
		credits = data.progression.credits,
		upgrades = data.progression.upgrades,
		evidence = data.evidence,
		flags = data.story.flags,
		readOnly = entry.readOnly,
	})
end

local function queueSnapshot(player: Player, entry: Entry)
	if entry.snapshotQueued then
		return
	end
	entry.snapshotQueued = true
	task.delay(Config.SNAPSHOT_INTERVAL, function()
		entry.snapshotQueued = false
		sendSnapshot(player)
	end)
end

local function onPlayerAdded(player: Player)
	if entries[player] then
		return
	end
	local entry = load(player)
	if player.Parent == nil then
		write(player, entry, true) -- left while loading: give the lock back
		return
	end
	entries[player] = entry
	player:GetAttributeChangedSignal("ClientReady"):Connect(function()
		sendSnapshot(player)
	end)
	if entry.readOnly then
		Net.fireClient(player, "UI_Toast", { text = LOAD_FAILED_TOAST })
	end
	PlayerDataService.Loaded:Fire(player, entry.data)
	sendSnapshot(player)
end

function PlayerDataService.getProfile(player: Player): Profile?
	local entry = entries[player]
	return if entry then entry.data else nil
end

function PlayerDataService.waitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while not entries[player] and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerDataService.getProfile(player)
end

-- Runs fn(profile) and marks the profile dirty. Returns false when the profile isn't loaded.
function PlayerDataService.update(player: Player, fn: (profile: Profile) -> ()): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	fn(entry.data)
	entry.dirty = true
	queueSnapshot(player, entry)
	return true
end

-- Saves now (yields). Returns true when the data is stored, false when nothing was written
-- (read-only, memory-only, failed after retries, or already released). release = final save, clears the lock.
function PlayerDataService.saveNow(player: Player, reason: string, release: boolean?): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	while entry.saving do
		PlayerDataService.Saved:Wait()
	end
	if entry.released then
		return false
	end
	if not release and not entry.dirty then
		return not memoryOnly and not entry.readOnly -- the latest data is already stored
	end
	entry.saving = true
	if release then
		entry.released = true
	else
		local wait = Config.MIN_SAVE_INTERVAL - (os.clock() - entry.lastWrite)
		if wait > 0 then
			task.wait(wait)
		end
	end
	local written = write(player, entry, release == true)
	entry.saving = false
	Log.debug(TAG, "save for %s (%s): %s", player.Name, reason, if written then "written" else "not written")
	PlayerDataService.Saved:Fire(player, written, reason)
	return written
end

function PlayerDataService.isReadOnly(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.readOnly
end

function PlayerDataService.isMemoryOnly(): boolean
	return memoryOnly
end

function PlayerDataService.getSessionId(): string
	return sessionId
end

-- Debug (/wipe): replaces the profile with a fresh default one and saves it.
function PlayerDataService.wipe(player: Player): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	entry.data = defaultProfile()
	entry.dirty = true
	queueSnapshot(player, entry)
	return PlayerDataService.saveNow(player, "wipe")
end

-- Debug (/dsfail on|off): makes every DataStore call fail. Studio only.
function PlayerDataService.setSimulateFailure(enabled: boolean)
	if IS_STUDIO then
		simulateFailure = enabled
	end
end

-- The shutdown save (BindToClose, docs/17 §4): every profile saved and released at once, waiting up to CLOSE_TIMEOUT.
-- Returns how many saves were still running at the deadline. Also called by the Phase 6 shutdown test.
function PlayerDataService.shutdown(): number
	local pending = 0
	for player in pairs(entries) do
		pending += 1
		task.spawn(function()
			PlayerDataService.saveNow(player, "shutdown", true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + Config.CLOSE_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	return pending
end

function PlayerDataService.Init()
	local serverFolder = script.Parent.Parent
	if IS_STUDIO then
		simulateFailure = serverFolder:GetAttribute("TestDataStoreFailure") == true
		if serverFolder:GetAttribute("TestFastRetries") == true then
			retryDelays = table.create(#Config.RETRY_DELAYS, 0.2)
		end
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.STORE)
	end)
	if ok then
		store = result
	end
	if not ok or (IS_STUDIO and serverFolder:GetAttribute("TestMemoryOnly") == true) then
		memoryOnly = true
	elseif IS_STUDIO then
		-- One read tells whether Studio may use the API (off by default; docs/17 §1).
		local probeOk = pcall(function()
			return (store :: DataStore):GetAsync("__probe")
		end)
		memoryOnly = not probeOk
	end
	if memoryOnly then
		Log.warn(TAG, "API services disabled: profiles will NOT persist")
	end
end

function PlayerDataService.Start()
	Net.on("Settings_Update", function(player: Player, payload: { [string]: any })
		PlayerDataService.update(player, function(profile)
			for key, value in pairs(payload) do
				(profile.settings :: any)[key] = value
			end
		end)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.saveNow(player, "leave", true)
		entries[player] = nil
	end)

	game:BindToClose(PlayerDataService.shutdown)

	-- Autosave: checked once per second; deferred while the request budget is low.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		if memoryOnly then
			return
		end
		local now = os.clock()
		for player, entry in pairs(entries) do
			if not entry.readOnly and not entry.saving and now - entry.lastAutosave >= Config.AUTOSAVE_INTERVAL then
				local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				if budget >= Config.MIN_BUDGET then
					entry.lastAutosave = now
					entry.dirty = true -- play time and the lock time always move forward
					task.spawn(PlayerDataService.saveNow, player, "autosave")
				end
			end
		end
	end)
end

return PlayerDataService
