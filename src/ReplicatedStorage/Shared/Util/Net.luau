--!strict
-- 원격 이벤트 레지스트리. 서버가 생성하고 클라이언트는 기다려서 가져온다.
-- 모든 원격 이벤트 이름은 여기 한 곳에 정의 (오타 방지).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local NAMES: { [string]: string } = {
	CombatRequest = "CombatRequest", -- C->S  (actionId, payload)
	CombatEvent = "CombatEvent", -- S->C  (kind, data)       브로드캐스트
	CombatPrivate = "CombatPrivate", -- S->C  (kind, data)       한 명에게 (넉백, 거절 등)
	FerryRelative = "FerryRelative", -- C<->S (unreliable) 배 위 상대 위치 중계
	FerryRequest = "FerryRequest", -- C->S  (kind) 구조 요청 등
	WorldEvent = "WorldEvent", -- S->C  (kind, data) 알림/배너
}
Net.Names = NAMES

local UNRELIABLE = {
	FerryRelative = true,
}

local FOLDER_NAME = "SwampRemotes"

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not f then
			f = Instance.new("Folder")
			f.Name = FOLDER_NAME
			f.Parent = ReplicatedStorage
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local cache: { [string]: Instance } = {}

local function get(name: string): Instance
	local existing = cache[name]
	if existing then
		return existing
	end
	assert(NAMES[name], "Unknown remote: " .. name)
	local f = folder()
	local inst: Instance
	if RunService:IsServer() then
		local found = f:FindFirstChild(name)
		if found then
			inst = found
		else
			inst = Instance.new(if UNRELIABLE[name] then "UnreliableRemoteEvent" else "RemoteEvent")
			inst.Name = name
			inst.Parent = f
		end
	else
		inst = f:WaitForChild(name)
	end
	cache[name] = inst
	return inst
end

function Net.Event(name: string): RemoteEvent
	return get(name) :: RemoteEvent
end

function Net.Unreliable(name: string): UnreliableRemoteEvent
	return get(name) :: UnreliableRemoteEvent
end

-- 서버 시작 시 모든 원격 이벤트를 미리 생성
function Net.CreateAll()
	assert(RunService:IsServer())
	for name in NAMES do
		get(name)
	end
end

return Net
