--!strict
-- 클라이언트 전투 이벤트 버스: 서버 CombatEvent + 로컬 예측 이벤트를 구독자에게 분배.
-- 전투 ID → 모델 매핑도 담당.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)

local CombatBus = {}

type Handler = (kind: string, data: any, isLocal: boolean) -> ()
local handlers: { Handler } = {}
local privateHandlers: { (kind: string, data: any) -> () } = {}
local idCache: { [number]: Model } = {}

function CombatBus.Subscribe(fn: Handler)
	table.insert(handlers, fn)
end

function CombatBus.SubscribePrivate(fn: (kind: string, data: any) -> ())
	table.insert(privateHandlers, fn)
end

-- 로컬 예측 이벤트 (서버 이벤트와 같은 형식)
function CombatBus.Emit(kind: string, data: any)
	for _, h in handlers do
		task.spawn(h, kind, data, true)
	end
end

local function scan(id: number): Model?
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		if ch and ch:GetAttribute("CombatId") == id then
			return ch
		end
	end
	for _, m in CollectionService:GetTagged("SwampEnemy") do
		if m:IsA("Model") and m:GetAttribute("CombatId") == id then
			return m
		end
	end
	return nil
end

function CombatBus.Model(id: number?): Model?
	if not id then
		return nil
	end
	local cached = idCache[id]
	if cached and cached.Parent and cached:GetAttribute("CombatId") == id then
		return cached
	end
	local found = scan(id)
	if found then
		idCache[id] = found
	end
	return found
end

function CombatBus.LocalId(): number?
	local ch = Players.LocalPlayer.Character
	return ch and ch:GetAttribute("CombatId") :: number?
end

function CombatBus.IsLocal(id: number?): boolean
	return id ~= nil and id == CombatBus.LocalId()
end

function CombatBus.Start()
	Net.Event("CombatEvent").OnClientEvent:Connect(function(kind: string, data: any)
		for _, h in handlers do
			task.spawn(h, kind, data, false)
		end
	end)
	Net.Event("CombatPrivate").OnClientEvent:Connect(function(kind: string, data: any)
		for _, h in privateHandlers do
			task.spawn(h, kind, data)
		end
	end)
end

return CombatBus
