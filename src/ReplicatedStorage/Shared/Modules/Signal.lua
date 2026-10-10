--!strict
-- Shared/Modules/Signal.lua
--
-- Lightweight signal for module-to-module events (PlayerDataService.Loaded, ZoneService.ZoneChanged, ...).
-- Method names mirror RBXScriptSignal (Connect, Once, Wait, Disconnect) so a Trove can hold either kind.
-- Handlers run immediately, each in its own thread: one that yields or errors never blocks the others.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal.Connect(self: any, handler: (...any) -> ()): Connection
	assert(type(handler) == "function", "Signal:Connect expects a function")
	local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, Connection)
	table.insert(self._handlers, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Fire(self: any, ...: any)
	-- Snapshot: handlers may connect or disconnect while the signal fires.
	local snapshot = table.clone(self._handlers)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, connection in ipairs(self._handlers) do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
