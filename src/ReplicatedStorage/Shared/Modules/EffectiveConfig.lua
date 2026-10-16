--!nonstrict
-- Shared/Modules/EffectiveConfig.lua  (docs/12_combat_system.md §12)
--
-- A pilot's effective config: the base CombatConfig and FrameConfig with the owned upgrades' modifiers applied
-- (Config/Upgrades, in its list order). The server plays by it (ProgressionService); the client builds the same
-- one from Profile_Snapshot for prediction and the HUD. The base tables are never changed: only the tables on a
-- modifier's path are copied, the rest is shared. One result per upgrade set, cached.
--
--   build(owned) -> { combat, frame, key }      owned = { [upgradeId] = true }
--   apply(bases, modifiers) -> { combat, frame } (any modifiers; for tests)
--   valueAt(config, path) -> number?             a modifier path's value in a built config

local Config = script.Parent.Parent.Config
local CombatConfig = require(Config.CombatConfig)
local FrameConfig = require(Config.FrameConfig)
local Upgrades = require(Config.Upgrades)

local EffectiveConfig = {}

local OPS = {
	mul = function(a, b)
		return a * b
	end,
	add = function(a, b)
		return a + b
	end,
	set = function(_, b)
		return b
	end,
}

local cache = {} -- [key] = built

-- "Frames.Vanguard.Light1.recovery" -> "combat", { "Frames", "Vanguard", "Light1", "recovery" }
local function split(path)
	local segments = string.split(path, ".")
	if segments[1] == "FrameConfig" then
		table.remove(segments, 1)
		return "frame", segments
	elseif segments[1] == "CombatConfig" then
		table.remove(segments, 1)
	end
	return "combat", segments
end

function EffectiveConfig.apply(bases, modifiers)
	local roots = { combat = table.clone(bases.combat), frame = table.clone(bases.frame) }
	local copies = { [roots.combat] = true, [roots.frame] = true } -- tables this result owns
	for _, modifier in ipairs(modifiers) do
		local rootName, segments = split(modifier.path)
		local node = roots[rootName]
		for index = 1, #segments - 1 do
			local key = segments[index]
			local child = node[key]
			if type(child) ~= "table" then
				error(("EffectiveConfig: %s has no table at %s"):format(modifier.path, key), 2)
			end
			if not copies[child] then
				child = table.clone(child)
				copies[child] = true
				node[key] = child
			end
			node = child
		end
		local leaf = segments[#segments]
		local op = OPS[modifier.op]
		if type(node[leaf]) ~= "number" or not op then
			error(("EffectiveConfig: can't %s %s"):format(tostring(modifier.op), modifier.path), 2)
		end
		node[leaf] = op(node[leaf], modifier.value)
	end
	return roots
end

function EffectiveConfig.build(owned)
	local ids = {}
	for _, upgrade in ipairs(Upgrades.List) do
		if owned and owned[upgrade.id] then
			table.insert(ids, upgrade.id)
		end
	end
	local key = table.concat(ids, ",")
	if cache[key] then
		return cache[key]
	end
	local modifiers = {}
	for _, id in ipairs(ids) do
		for _, modifier in ipairs(Upgrades.ById[id].modifiers) do
			table.insert(modifiers, modifier)
		end
	end
	local roots = EffectiveConfig.apply({ combat = CombatConfig, frame = FrameConfig }, modifiers)
	local built = { combat = roots.combat, frame = roots.frame, key = key }
	cache[key] = built
	return built
end

function EffectiveConfig.valueAt(config, path)
	local rootName, segments = split(path)
	local node = config[rootName]
	for _, key in ipairs(segments) do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return if type(node) == "number" then node else nil
end

EffectiveConfig.BASE = EffectiveConfig.build({})

return EffectiveConfig
