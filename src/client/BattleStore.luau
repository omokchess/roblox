--!strict
--[[
	BattleStore — 서버의 BattleState 를 **한 곳에서** 받아 여러 화면에 나눠 준다. (2026-09-28)

	디버그 패널·레벨업 화면·전투 화면이 모두 같은 상태를 본다. 각자 OnClientEvent 에 붙으면
	접속 직후 대기열에 쌓인 첫 상태를 먼저 붙은 하나만 받고 나머지는 놓친다.
	그래서 여기 하나만 붙고, 늦게 구독한 쪽에도 마지막 상태를 바로 건넨다.
]]

local BattleStore = {}

local latest: any = nil
local listeners: { (any) -> () } = {}
local remotes: Folder? = nil

function BattleStore.Init(folder: Folder)
	if remotes then
		return
	end
	remotes = folder
	local any = folder :: any
	any.BattleState.OnClientEvent:Connect(function(state)
		latest = state
		for _, listener in listeners do
			task.spawn(listener, state)
		end
	end)
	-- 접속 직후 한 번 달라고 한다(서버도 캐릭터를 세운 뒤 보내지만, 그 전에 붙었을 수 있다)
	any.BattleAction:FireServer({ Kind = "Hello" })
end

function BattleStore.Subscribe(listener: (any) -> ())
	table.insert(listeners, listener)
	if latest ~= nil then
		task.spawn(listener, latest)
	end
end

function BattleStore.Get(): any
	return latest
end

function BattleStore.Send(request: { [string]: any })
	local folder = remotes :: any
	if folder then
		folder.BattleAction:FireServer(request)
	end
end

return BattleStore
