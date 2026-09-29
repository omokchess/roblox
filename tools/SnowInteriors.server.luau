--!strict
--[[
	SnowInteriors — 설원 슈네라이히 기능 건물의 문과 안쪽 방을 잇는다. (2026-09-26)

	맵에 딸린 스크립트다. Snow_City.luau 가 ServerScriptService.SnowInteriors 로 넣는다.
	(Rojo 가 관리하는 src/server 밖에 둔다. 맵과 함께 Studio 에만 있다)

	태그 셋으로 짝을 찾는다. 모두 속성 InteriorId 가 같은 것끼리 한 짝이다.
	  SnowDoor    건물 문 앞의 보이지 않는 판. ProximityPrompt 를 품고,
	              ReturnPos / ReturnLook 속성에 나올 때 설 자리와 볼 방향을 적어 둔다
	  SnowArrive  방 안에 들어섰을 때 설 자리. 판의 앞(LookVector)을 보고 선다
	  SnowExit    방 안 출입문. ProximityPrompt 를 품는다
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local COOLDOWN = 1.0 -- 문 앞에서 두 번 눌러 오가는 것을 막는다

local doors: { [string]: BasePart } = {}
local arrivals: { [string]: BasePart } = {}
local lastMove: { [Player]: number } = {}

local function move(player: Player, cf: CFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if lastMove[player] and now - lastMove[player] < COOLDOWN then
		return
	end
	lastMove[player] = now
	-- 스트리밍이 켜져 있다. 멀리 떨어진 방을 먼저 불러 두지 않으면 허공에 떨어진다
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	character:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function promptOf(part: Instance): ProximityPrompt?
	local p = part:FindFirstChildOfClass("ProximityPrompt")
	return p
end

local function wireDoor(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("InteriorId")
	if typeof(id) ~= "string" then
		return
	end
	doors[id] = part
	local prompt = promptOf(part)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local arrive = arrivals[id]
			if arrive then
				move(player, arrive.CFrame + Vector3.new(0, 3, 0))
			end
		end)
	end
end

local function wireArrive(part: Instance)
	local id = part:GetAttribute("InteriorId")
	if part:IsA("BasePart") and typeof(id) == "string" then
		arrivals[id] = part
	end
end

local function wireExit(part: Instance)
	local id = part:GetAttribute("InteriorId")
	local prompt = promptOf(part)
	if typeof(id) ~= "string" or not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local door = doors[id]
		if not door then
			return
		end
		local pos = door:GetAttribute("ReturnPos")
		local look = door:GetAttribute("ReturnLook")
		if typeof(pos) == "Vector3" and typeof(look) == "Vector3" then
			move(player, CFrame.lookAt(pos, pos + look))
		end
	end)
end

for tag, fn in { SnowDoor = wireDoor, SnowArrive = wireArrive, SnowExit = wireExit } do
	for _, inst in CollectionService:GetTagged(tag) do
		fn(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end

Players.PlayerRemoving:Connect(function(player)
	lastMove[player] = nil
end)
