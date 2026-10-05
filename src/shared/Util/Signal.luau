--!strict
-- Tiny synchronous signal. Handlers run in their own thread so one erroring
-- handler can't break the others.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._handlers = {} :: { [any]: (...any) -> () }
	return self
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local key = {}
	self._handlers[key] = handler
	local handlers = self._handlers
	local connection = {
		Connected = true,
	}
	function connection.Disconnect(conn)
		conn.Connected = false
		handlers[key] = nil
	end
	return connection :: any
end

function Signal:Once(handler: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
