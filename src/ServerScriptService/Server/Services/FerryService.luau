--!strict
-- 연락선 서버: 배 위 상대 위치 중계, 바다 구조(텔레포트) 처리.
-- 배 자체는 결정적 시간표로 각 클라이언트가 그리므로 서버에는 물리 배가 없다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local WorldData = require(Shared.World.WorldData)
local FerryRoute = require(Shared.Ferry.FerryRoute)

local FerryService = {}

local lastRelay: { [Player]: number } = {}
local lastRescue: { [Player]: number } = {}
local route: FerryRoute.Route

function FerryService.Route(): FerryRoute.Route
	return route
end

local function onRelay(player: Player, rel: any)
	local now = os.clock()
	if now - (lastRelay[player] or 0) < 0.045 then
		return -- 초당 ~20회 제한
	end
	lastRelay[player] = now
	if rel ~= nil and typeof(rel) ~= "CFrame" then
		return
	end
	if typeof(rel) == "CFrame" and rel.Position.Magnitude > 120 then
		return -- 배 크기를 넘는 상대 위치는 무시
	end
	Net.Unreliable("FerryRelative"):FireAllClients(player, rel)
end

local function onRequest(player: Player, kind: any)
	if kind ~= "Rescue" then
		return
	end
	local now = os.clock()
	if now - (lastRescue[player] or 0) < 10 then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local pos = hrp.Position
	local h = WorldData.TerrainHeight(pos.X, pos.Z)
	-- 실제로 먼바다 수면 근처에 있을 때만 허용
	if pos.Y > 6 or (h ~= nil and h > -8) then
		return
	end
	lastRescue[player] = now
	local best, bestD = nil, math.huge
	for _, s in WorldData.SpawnPoints() do
		local d = (s.P - pos).Magnitude
		if d < bestD then
			best, bestD = s.P, d
		end
	end
	if best then
		char:PivotTo(CFrame.new(best + Vector3.new(0, 4, 0)))
		Net.Event("WorldEvent"):FireClient(player, "Toast", { Text = "🛟 구조되었습니다!", Color = "Good" })
	end
end

function FerryService.Start()
	route = FerryRoute.new(require(Shared.World.Generated.FerryRouteData) :: any, WorldData.Offset())
	Net.Unreliable("FerryRelative").OnServerEvent:Connect(onRelay)
	Net.Event("FerryRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		lastRelay[p] = nil
		lastRescue[p] = nil
	end)
end

return FerryService
