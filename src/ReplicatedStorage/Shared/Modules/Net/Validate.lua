--!strict
-- Shared/Modules/Net/Validate.lua  (docs/16_technical_architecture.md §5)
--
-- Argument validators for client -> server remotes. A validator returns (true) or (false, reason).
-- Rules from the spec: typeof checks, enum whitelists, finite numbers, unit vectors within ±0.05,
-- strings of at most 64 characters, and a key whitelist on every payload table.

local MathUtil = require(script.Parent.Parent.MathUtil)

export type Validator = (value: any) -> (boolean, string?)

local Validate = {}

Validate.MAX_STRING = 64
Validate.UNIT_TOLERANCE = 0.05

function Validate.string(maxLength: number?): Validator
	local limit = maxLength or Validate.MAX_STRING
	return function(value)
		if type(value) ~= "string" then
			return false, "expected a string"
		end
		if #value > limit then
			return false, "string longer than " .. limit
		end
		return true
	end
end

function Validate.number(opts: { min: number?, max: number?, integer: boolean? }?): Validator
	local options = opts or {}
	return function(value)
		if not MathUtil.isFinite(value) then
			return false, "expected a finite number"
		end
		if options.integer and value % 1 ~= 0 then
			return false, "expected an integer"
		end
		if (options.min and value < options.min) or (options.max and value > options.max) then
			return false, "number out of range"
		end
		return true
	end
end

function Validate.boolean(): Validator
	return function(value)
		if type(value) ~= "boolean" then
			return false, "expected a boolean"
		end
		return true
	end
end

function Validate.enum(values: { string }): Validator
	local allowed = {}
	for _, name in ipairs(values) do
		allowed[name] = true
	end
	return function(value)
		if type(value) ~= "string" or not allowed[value] then
			return false, "value not in the whitelist"
		end
		return true
	end
end

function Validate.unitVector(tolerance: number?): Validator
	local limit = tolerance or Validate.UNIT_TOLERANCE
	return function(value)
		if not MathUtil.isUnitVector(value, limit) then
			return false, "expected a unit Vector3"
		end
		return true
	end
end

function Validate.optional(inner: Validator): Validator
	return function(value)
		if value == nil then
			return true
		end
		return inner(value)
	end
end

-- A list (keys 1..n, no holes, no other keys) of at most maxCount validated items.
function Validate.array(inner: Validator, maxCount: number): Validator
	return function(value)
		if type(value) ~= "table" then
			return false, "expected a list"
		end
		local count = #value
		if count > maxCount then
			return false, "list longer than " .. maxCount
		end
		local keys = 0
		for _ in pairs(value) do
			keys += 1
		end
		if keys ~= count then
			return false, "expected a plain list"
		end
		for index = 1, count do
			local ok, reason = inner(value[index])
			if not ok then
				return false, ("item %d: %s"):format(index, tostring(reason))
			end
		end
		return true
	end
end

-- A payload table: only whitelisted string keys, each value validated. Wrap a field in Validate.optional to
-- allow nil. opts.minKeys rejects payloads that carry fewer keys (e.g. an empty Settings_Update).
function Validate.payload(fields: { [string]: Validator }, opts: { minKeys: number? }?): Validator
	local minKeys = if opts and opts.minKeys then opts.minKeys else 0
	return function(value)
		if type(value) ~= "table" then
			return false, "expected a table"
		end
		local keys = 0
		for key in pairs(value) do
			if type(key) ~= "string" or not fields[key] then
				return false, "unexpected key " .. tostring(key)
			end
			keys += 1
		end
		if keys < minKeys then
			return false, "payload is empty"
		end
		for key, validator in pairs(fields) do
			local ok, reason = validator(value[key])
			if not ok then
				return false, key .. ": " .. tostring(reason)
			end
		end
		return true
	end
end

return Validate
