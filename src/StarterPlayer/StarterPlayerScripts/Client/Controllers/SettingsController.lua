--!strict
-- Client/Controllers/SettingsController.lua  (docs/14_ui.md §8, docs/17 §2)
--
-- The player's settings on the client. Values start at the defaults of GameConfig.Settings and are replaced
-- by the profile's when Profile_Snapshot arrives. set() applies at once (Changed fires) and sends the pending
-- changes to the server with Settings_Update, debounced 1.0 s.
--
--   get(key)   set(key, value)   Changed(key, value)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DEBOUNCE = 1.0
-- The server accepts one Settings_Update per second; a little more keeps two sends apart on a jittery link.
local MIN_SEND_INTERVAL = 1.25

local SettingsController = {}

SettingsController.Changed = Signal.new() :: Signal.Signal<string, any>

local specs = GameConfig.Settings :: { [string]: any }
local values: { [string]: any } = {}
local pending: { [string]: any } = {}
local sendThread: thread? = nil
local lastSend = 0

local function clean(key: string, value: any): any
	local spec = specs[key]
	if not spec then
		error("SettingsController: unknown setting " .. tostring(key), 3)
	end
	if spec.kind == "number" then
		return math.clamp(tonumber(value) or spec.default, spec.min, spec.max)
	elseif spec.kind == "enum" then
		return if table.find(spec.values, value) then value else spec.default
	end
	return value == true
end

local function flush()
	sendThread = nil
	if next(pending) == nil then
		return
	end
	local payload = pending
	pending = {}
	lastSend = os.clock()
	Net.fireServer("Settings_Update", payload)
end

function SettingsController.get(key: string): any
	if specs[key] == nil then
		error("SettingsController: unknown setting " .. tostring(key), 2)
	end
	return values[key]
end

function SettingsController.set(key: string, value: any)
	local cleaned = clean(key, value)
	if values[key] == cleaned then
		return
	end
	values[key] = cleaned
	pending[key] = cleaned
	SettingsController.Changed:Fire(key, cleaned)
	if sendThread then
		task.cancel(sendThread)
	end
	local wait = math.max(DEBOUNCE, MIN_SEND_INTERVAL - (os.clock() - lastSend))
	sendThread = task.delay(wait, flush)
end

function SettingsController.Init()
	for key, spec in pairs(specs) do
		values[key] = spec.default
	end
end

function SettingsController.Start()
	Net.on("Profile_Snapshot", function(snapshot: { settings: { [string]: any }? })
		for key, value in pairs(snapshot.settings or {}) do
			-- A change that hasn't been sent yet wins over the server's older value.
			if specs[key] and pending[key] == nil then
				local cleaned = clean(key, value)
				if values[key] ~= cleaned then
					values[key] = cleaned
					SettingsController.Changed:Fire(key, cleaned)
				end
			end
		end
	end)
end

return SettingsController
