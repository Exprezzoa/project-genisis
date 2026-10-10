--!strict
-- Shared/Modules/TableUtil.lua
--
-- Table helpers for profile data and configs. Pure functions, no services.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value :: any) do
		copy[key] = TableUtil.deepCopy(item)
	end
	return (copy :: any) :: T
end

-- Fills keys that are missing in target from template, recursively. Existing values are never changed
-- and unknown keys are never deleted (docs/17_saving_progression_monetization.md §3.2). Returns target.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, templateValue in pairs(template) do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.deepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" then
			TableUtil.reconcile(current, templateValue)
		end
	end
	return target
end

function TableUtil.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not TableUtil.deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Number of keys (works for sets and dictionaries, where # doesn't).
function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- Keys as a sorted list (stable output for logs and debug dumps).
function TableUtil.sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

return TableUtil
