--!strict
--[[
	MineCartService — 설원 굴 광차 타기(2026-10-31 사용자: "굴 들어갈 때 레일 깔아서 그 레일 타서 들어가게 하자").

	광차 = 태그 MineCart 모델(tools/Snow_Tunnels.luau 가 굴마다 위·아래에 세움). 속성 P1..Pn = 탈 쪽 → 내릴 쪽 레일 윗면 점, Locked = 잠김.
	ProximityPrompt 를 누르면: 그 사람 캐릭터에 광차 모습(ReplicatedStorage.MineCartTemplate 복제)을 엉덩이 아래에 용접하고
	클라이언트에 길을 보낸다(Remote MineCart "Ride", 점들) → 클라이언트(MineCartClient)가 제 캐릭터를 레일 따라 옮긴다.
	캐릭터는 그 사람 것이라 남에게도 매끄럽게 보인다. 다 오면 클라이언트가 "Done" — 광차 모습을 뗀다.
	끊기면(시간 초과·죽음·나감) 서버가 뗀다. 세워 둔 광차는 그대로라 여럿이 차례로 탈 수 있다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MineCartService = {}

-- 시간 초과를 넉넉히 잡는 데만 쓴다(클라이언트 빠르기와 같게)
local SPEED = 44

type Ride = { Visual: Instance?, Token: number }
local riding: { [Player]: Ride } = {}

local function pathOf(cart: Instance): { Vector3 }
	local points = {}
	local index = 1
	while true do
		local point = cart:GetAttribute("P" .. index)
		if typeof(point) ~= "Vector3" then
			break
		end
		table.insert(points, point)
		index += 1
	end
	return points
end

local function stop(player: Player)
	local ride = riding[player]
	if ride then
		if ride.Visual then
			ride.Visual:Destroy()
		end
		riding[player] = nil
	end
end

-- 광차 모습을 엉덩이(HumanoidRootPart) 아래 Lift 에 붙인다. 부딪힘·무게 없음
local function attachVisual(root: BasePart): Instance?
	local template = ReplicatedStorage:FindFirstChild("MineCartTemplate")
	if not template or not template:IsA("Model") then
		return nil
	end
	local lift = template:GetAttribute("Lift")
	local visual = template:Clone()
	visual:PivotTo(root.CFrame * CFrame.new(0, -(if type(lift) == "number" then lift else 3), 0))
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	visual.Name = "MineCartRide"
	visual.Parent = root.Parent
	return visual
end

function MineCartService.Start(remote: RemoteEvent)
	local token = 0
	local function hook(cart: Instance)
		local prompt = cart:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function(player: Player)
			if riding[player] or cart:GetAttribute("Locked") == true then
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
				return
			end
			local points = pathOf(cart)
			if #points < 2 or (root.Position - points[1]).Magnitude > 30 then
				return
			end
			token += 1
			local mine = token
			riding[player] = { Visual = attachVisual(root), Token = mine }
			humanoid.Died:Once(function()
				stop(player)
			end)
			local length = 0
			for index = 2, #points do
				length += (points[index] - points[index - 1]).Magnitude
			end
			remote:FireClient(player, "Ride", points)
			task.delay(length / SPEED * 1.8 + 6, function()
				local ride = riding[player]
				if ride and ride.Token == mine then
					stop(player)
				end
			end)
		end)
	end
	for _, cart in CollectionService:GetTagged("MineCart") do
		hook(cart)
	end
	CollectionService:GetInstanceAddedSignal("MineCart"):Connect(hook)
	remote.OnServerEvent:Connect(function(player: Player, kind: any)
		if kind == "Done" then
			stop(player)
		end
	end)
	Players.PlayerRemoving:Connect(stop)
end

return MineCartService
