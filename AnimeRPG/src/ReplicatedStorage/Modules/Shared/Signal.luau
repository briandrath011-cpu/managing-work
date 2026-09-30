--[[
	Signal (ModuleScript)
	Location: ReplicatedStorage.Modules.Shared.Signal
	Lightweight event object used by server services and client controllers.
]]
local Signal = {}
Signal.__index = Signal

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({ Connected = true, _signal = signal, _fn = fn }, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copy so listeners may disconnect while firing.
	local snapshot = table.clone(self._connections)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in ipairs(table.clone(self._connections)) do
		connection:Disconnect()
	end
end

return Signal
