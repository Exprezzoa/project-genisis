--!nonstrict
-- Server/Services/CinematicService.lua  (docs/16_technical_architecture.md §4; docs/11 §6; data: Shared/Cinematics)
--
-- Tells one client to play a cinematic (Cinematic_Play {cinematicId, params, t0}) and keeps the server's side of
-- it: the timeline of events (a dialogue line at t), the end (the client's Cinematic_Done or Cinematic_Skip, or
-- the shots' length + 5 s), and the flag SEEN_<id> that makes it skippable next time. A dialogue-driven
-- cinematic runs until stop() (Cinematic_Play with params.stop = true).
--
--   play(player, id, opts?) -> boolean   opts.block (default true) yields until it ends; opts.params go to the
--                                        client (a dynamic shot's subject); false if the id is unknown
--   stop(player, id)      cue(player, id, name)      isPlaying(player) -> id?
--   Ended: Signal(player, id, skipped)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cinematics = require(Shared.Cinematics)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DialogueService = require(script.Parent.DialogueService)
local FlagService = require(script.Parent.FlagService)

local TAG = "CinematicService"
local SLACK = 5 -- seconds past the shots' length before the server gives up on the client

local CinematicService = {}

CinematicService.Ended = Signal.new()

local playing = {} -- [player] = { id, token, done }
local tokens = 0

local function length(data): number
	local total = data.seconds or 0 -- a scripted cinematic says how long it runs
	for _, shot in ipairs(data.shots or {}) do
		total += shot.seconds or 0
	end
	return total
end

local function finish(player: Player, id: string, skipped: boolean)
	local entry = playing[player]
	if not entry or entry.id ~= id or entry.done then
		return
	end
	entry.done = true
	playing[player] = nil
	FlagService.set(player, "SEEN_" .. id)
	Log.info(TAG, "%s %s %s", player.Name, if skipped then "skipped" else "finished", id)
	CinematicService.Ended:Fire(player, id, skipped)
end

function CinematicService.play(player: Player, id: string, opts): boolean
	opts = opts or {}
	local data = Cinematics[id]
	if not data then
		Log.warn(TAG, "unknown cinematic %s", tostring(id))
		return false
	end
	if playing[player] then
		finish(player, playing[player].id, true)
	end
	tokens += 1
	local skippable = data.skippable == true or FlagService.has(player, "SEEN_" .. id)
	local entry = { id = id, token = tokens, done = false, skippable = skippable }
	playing[player] = entry
	local params = { skippable = skippable }
	for key, value in pairs(opts.params or {}) do -- what a dynamic shot needs (the first boarding's Frame)
		params[key] = value
	end
	Net.fireClient(player, "Cinematic_Play", { cinematicId = id, params = params, t0 = workspace:GetServerTimeNow() })

	-- The server's timeline (a skipped cinematic drops what hadn't happened yet).
	local started = os.clock()
	for _, event in ipairs(data.events or {}) do
		task.delay(event.at, function()
			if entry.done or not player.Parent then
				return
			end
			if event.dialogue then
				DialogueService.start(player, event.dialogue)
			end
		end)
	end
	-- A timed cinematic ends by itself on the server too if the client never answers (a dialogue-driven or cued one
	-- runs until stop()).
	if not data.dialogueDriven and not data.cues then
		task.delay(length(data) + SLACK, function()
			if not entry.done then
				Log.warn(TAG, "%s: no answer from %s's client; ending it", id, player.Name)
				finish(player, id, false)
			end
		end)
	end
	if opts.block ~= false then
		while not entry.done and player.Parent do
			task.wait(0.1)
		end
	end
	Log.debug(TAG, "%s took %.1f s", id, os.clock() - started)
	return true
end

function CinematicService.stop(player: Player, id: string)
	local entry = playing[player]
	if entry and entry.id == id then
		Net.fireClient(player, "Cinematic_Play", { cinematicId = id, params = { stop = true }, t0 = workspace:GetServerTimeNow() })
		finish(player, id, false)
	end
end

-- A cued cinematic (S31): the client cuts to the named beat of `cues` and holds or tracks it until the next.
function CinematicService.cue(player: Player, id: string, name: string)
	local entry = playing[player]
	if entry and entry.id == id then
		Net.fireClient(player, "Cinematic_Play", { cinematicId = id, params = { cue = name }, t0 = workspace:GetServerTimeNow() })
	end
end

function CinematicService.isPlaying(player: Player): string?
	return playing[player] and playing[player].id or nil
end

function CinematicService.Start()
	Net.on("Cinematic_Done", function(player, payload)
		finish(player, payload.cinematicId, false)
	end)
	Net.on("Cinematic_Skip", function(player, payload)
		local entry = playing[player]
		local data = entry and Cinematics[entry.id]
		-- Only what the client was allowed to skip; a dialogue-driven one ends when its dialogue does.
		if entry and entry.id == payload.cinematicId and entry.skippable and data and not data.dialogueDriven and not data.cues then
			finish(player, entry.id, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		playing[player] = nil
	end)
end

return CinematicService
