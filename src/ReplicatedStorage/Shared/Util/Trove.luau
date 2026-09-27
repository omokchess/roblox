--!strict
-- Trove: 연결/인스턴스/함수를 모아 한 번에 정리

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return (setmetatable({ _items = {} :: { any } }, Trove) :: any) :: Trove
end

function Trove.Add(self: any, item: any): any
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local c = signal:Connect(fn)
	table.insert(self._items, c)
	return c
end

local function cleanup(item: any)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "function" then
		item()
	elseif t == "thread" then
		pcall(task.cancel, item)
	elseif t == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.Clean(self: any)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		cleanup(items[i])
	end
end

function Trove.Destroy(self: any)
	self:Clean()
end

return Trove
