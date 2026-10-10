--!strict
-- Shared/Modules/Trove.lua  (docs/16_technical_architecture.md §1.5)
--
-- Tracks everything created for a player, Frame, Titan or screen, and cleans it all up in one call.
-- Accepted items: Instance (Destroy), RBXScriptConnection or Signal connection (Disconnect), function (called),
-- thread (task.cancel), or a table with a destroy/Destroy/clean/Disconnect method.
-- Items are cleaned in reverse order of adding.

export type Trove = {
	add: <T>(self: Trove, item: T, method: string?) -> T,
	connect: (self: Trove, signal: any, handler: (...any) -> ()) -> any,
	extend: (self: Trove) -> Trove,
	remove: (self: Trove, item: any) -> boolean,
	attachToInstance: (self: Trove, instance: Instance) -> (),
	clean: (self: Trove) -> (),
	destroy: (self: Trove) -> (),
}

local TABLE_METHODS = { "destroy", "Destroy", "clean", "Disconnect" }

local Trove = {}
Trove.__index = Trove

local function resolveMethod(item: any, method: string?): string
	local kind = typeof(item)
	if kind == "function" then
		return "__call"
	elseif kind == "thread" then
		return "__cancel"
	elseif kind == "Instance" then
		return method or "Destroy"
	elseif kind == "RBXScriptConnection" then
		return "Disconnect"
	elseif kind == "table" then
		if method then
			return method
		end
		for _, name in ipairs(TABLE_METHODS) do
			if type(item[name]) == "function" then
				return name
			end
		end
	end
	error("Trove can't clean up a " .. kind .. " (no cleanup method found)", 3)
end

local function cleanItem(item: any, method: string)
	if method == "__call" then
		item()
	elseif method == "__cancel" then
		if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then
			task.cancel(item)
		end
	else
		item[method](item)
	end
end

function Trove.new(): Trove
	return (setmetatable({ _items = {}, _cleaning = false }, Trove) :: any) :: Trove
end

function Trove.add(self: any, item: any, method: string?): any
	if self._cleaning then
		error("Trove:add called while the trove is being cleaned", 2)
	end
	table.insert(self._items, { item = item, method = resolveMethod(item, method) })
	return item
end

function Trove.connect(self: any, signal: any, handler: (...any) -> ()): any
	return self:add(signal:Connect(handler))
end

-- A child trove that is cleaned together with this one (and can be cleaned earlier on its own).
function Trove.extend(self: any): Trove
	return self:add(Trove.new())
end

-- Cleans one item now. Returns false when the item isn't in the trove.
function Trove.remove(self: any, item: any): boolean
	for index, entry in ipairs(self._items) do
		if entry.item == item then
			table.remove(self._items, index)
			cleanItem(entry.item, entry.method)
			return true
		end
	end
	return false
end

-- Cleans the trove when the instance is destroyed.
function Trove.attachToInstance(self: any, instance: Instance)
	self:connect(instance.Destroying, function()
		self:clean()
	end)
end

function Trove.clean(self: any)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		local entry = items[index]
		local ok, message = pcall(cleanItem, entry.item, entry.method)
		if not ok then
			-- Keep cleaning the rest; report the failure loudly.
			task.spawn(error, "[Trove] cleanup failed: " .. tostring(message), 0)
		end
	end
	self._cleaning = false
end

Trove.destroy = Trove.clean

return Trove
