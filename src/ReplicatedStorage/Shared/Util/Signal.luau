--!strict
-- 가벼운 Signal (BindableEvent 없이, 핸들러는 task.spawn 으로 격리 실행)

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

type Handler = { fn: (...any) -> (), connected: boolean, once: boolean }

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { Handler } }, Signal)
	return (self :: any) :: Signal<T...>
end

local function makeConnection(signal: any, h: Handler): Connection
	local conn = {} :: any
	conn.Connected = true
	function conn.Disconnect(c: any)
		if not c.Connected then
			return
		end
		c.Connected = false
		h.connected = false
		local list = signal._handlers
		local idx = table.find(list, h)
		if idx then
			table.remove(list, idx)
		end
	end
	return conn :: Connection
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local h: Handler = { fn = fn, connected = true, once = false }
	table.insert(self._handlers, h)
	return makeConnection(self, h)
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local h: Handler = { fn = fn, connected = true, once = true }
	table.insert(self._handlers, h)
	return makeConnection(self, h)
end

function Signal.Fire(self: any, ...: any)
	local list: { Handler } = table.clone(self._handlers)
	for _, h in list do
		if h.connected then
			if h.once then
				h.connected = false
				local idx = table.find(self._handlers, h)
				if idx then
					table.remove(self._handlers, idx)
				end
			end
			task.spawn(h.fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	for _, h: Handler in self._handlers do
		h.connected = false
	end
	table.clear(self._handlers)
end

return Signal
