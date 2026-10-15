--!nonstrict
-- Server/Sequence/Conditions.lua  (docs/13_missions_dialogue_relationships.md §1.3)
--
-- Completion conditions of the Sequence Runner. A compiled condition is { ready() -> boolean,
-- on(kind, key, who) -> boolean }: ready() looks at the world as it is when the step arms, on() is asked for
-- every event SequenceService passes along ("trigger", "interact", "event", "line", "timer", "tick").
--
--   Conditions.bind({ publish, notify })
--   Conditions.compile(runner, token, cond) -> compiled
--
-- Built: trigger, interact, counter, event, line, timer, proximity, zone, any, all.

local Services = script.Parent.Parent.Services
local CharacterService = require(Services.CharacterService)
local FlagService = require(Services.FlagService)
local FrameService = require(Services.FrameService)
local TriggerService = require(Services.TriggerService)
local ZoneService = require(Services.ZoneService)

local Conditions = {}

local hooks = {}

local STATE_OF_EVENT = {
	FrameBoarded = function(player)
		return FrameService.getPiloted(player) ~= nil
	end,
	FrameDismounted = function(player)
		return FrameService.getPiloted(player) == nil
	end,
}

function Conditions.bind(given)
	hooks = given
end

function Conditions.compile(runner, token, cond)
	local kind = cond[1]
	local player = runner.player
	if kind == "trigger" then
		local who = if cond.who == "any" then nil else cond.who
		return {
			ready = function()
				return TriggerService.isInside(player, cond.id, who)
			end,
			on = function(k, key, eventWho)
				return k == "trigger" and key == cond.id and (who == nil or who == eventWho)
			end,
		}
	elseif kind == "interact" or kind == "event" or kind == "line" then
		-- "line": a dialogue line was shown (DialogueService.NodeShown; cond.id is the line id).
		local wanted = if kind == "event" then cond.name else cond.id
		-- An event that leaves a lasting state also counts when that state already holds as the step arms: a player
		-- who boarded while the last lines of the step before still played must not wait forever.
		local holds = STATE_OF_EVENT[wanted]
		return {
			ready = function()
				return kind == "event" and holds ~= nil and holds(player)
			end,
			on = function(k, key)
				return k == kind and key == wanted
			end,
		}
	elseif kind == "counter" then
		-- n distinct interactions; with `flags` each one is remembered as a story flag and counted again after a reload.
		local found, count = {}, 0
		for _, id in ipairs(cond.ids) do
			local flag = cond.flags and cond.flags[id]
			if flag and FlagService.has(player, flag) then
				found[id] = true
				count += 1
			end
		end
		runner.args = { n = count }
		return {
			ready = function()
				return count >= cond.n
			end,
			on = function(k, key)
				if k == "interact" and table.find(cond.ids, key) and not found[key] then
					found[key] = true
					count += 1
					if cond.flags and cond.flags[key] then
						FlagService.set(player, cond.flags[key])
					end
					runner.args = { n = count }
					hooks.publish(runner)
				end
				return count >= cond.n
			end,
		}
	elseif kind == "timer" then
		local elapsed = false
		task.delay(cond.seconds, function()
			elapsed = true
			if runner.token == token then
				hooks.notify(player, "timer", "")
			end
		end)
		return {
			ready = function()
				return elapsed
			end,
			on = function()
				return elapsed
			end,
		}
	elseif kind == "zone" then
		-- The player (on foot or in the Frame) is in that zone of Config/Zones (looked at on every tick).
		local function inside()
			return ZoneService.getZone(player) == cond.id
		end
		return { ready = inside, on = inside }
	elseif kind == "proximity" then
		-- The player's Frame (or the character on foot) within `radius` of a spawn marker, along the ground.
		local function near()
			local frame = FrameService.getPiloted(player)
			local character = player.Character
			local body = if frame then frame.PrimaryPart else (character and character:FindFirstChild("HumanoidRootPart"))
			local cframe = CharacterService.getSpawnCFrame(cond.spawn)
			return body ~= nil and cframe ~= nil and ((body.Position - cframe.Position) * Vector3.new(1, 0, 1)).Magnitude <= cond.radius
		end
		return { ready = near, on = near }
	elseif kind == "any" or kind == "all" then
		local children, met = {}, {}
		for index, child in ipairs(cond) do
			if index > 1 then
				table.insert(children, Conditions.compile(runner, token, child))
			end
		end
		local function tally(test)
			local count = 0
			for index, child in ipairs(children) do
				met[index] = met[index] or test(child)
				count += if met[index] then 1 else 0
			end
			return if kind == "any" then count > 0 else count == #children
		end
		return {
			ready = function()
				return tally(function(child)
					return child.ready()
				end)
			end,
			on = function(k, key, who)
				return tally(function(child)
					return child.on(k, key, who)
				end)
			end,
		}
	end
	error("SequenceService: condition " .. tostring(kind) .. " isn't built yet")
end

return Conditions
