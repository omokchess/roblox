--!strict
--[[
	MineCartClient — 광차 타기(서버 MineCartService 가 레일 길을 보냄). 제 캐릭터를 앉힌 채 레일 따라 옮긴다:
	천천히 출발해 SPEED 까지, 끝 앞에서 늦춘다. 기울어진 레일에선 몸도 기운다. 다 오면 옆으로 내려서고 서버에 "Done".
	레일 윗면 → HumanoidRootPart 높이 = MineCartTemplate 속성 Lift(서버가 붙인 광차 모습과 맞춘다).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MineCartClient = {}

-- 2026-11-01 사용자 "수레가 좀 느린데" → 두 배(22·9·3 → 44·20·6)
local SPEED, ACCEL, SLOW = 44, 20, 6

function MineCartClient.Start(remotes: Instance)
	local remote = remotes:WaitForChild("MineCart") :: RemoteEvent
	local busy = false
	remote.OnClientEvent:Connect(function(kind: string, points: { Vector3 })
		if kind ~= "Ride" or busy or #points < 2 then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			remote:FireServer("Done")
			return
		end
		busy = true
		local template = ReplicatedStorage:FindFirstChild("MineCartTemplate")
		local liftValue = template and template:GetAttribute("Lift")
		local lift = Vector3.yAxis * (if type(liftValue) == "number" then liftValue else 3)
		local lengths, total = {}, 0
		for index = 2, #points do
			lengths[index - 1] = (points[index] - points[index - 1]).Magnitude
			total += lengths[index - 1]
		end
		local function at(distance: number): (Vector3, Vector3)
			for index, length in lengths do
				if distance <= length or index == #lengths then
					local a, b = points[index], points[index + 1]
					return a:Lerp(b, math.clamp(distance / math.max(length, 1e-3), 0, 1)), (b - a).Unit
				end
				distance -= length
			end
			return points[#points], (points[#points] - points[#points - 1]).Unit
		end
		local travelled, speed = 0, 0
		local connection: RBXScriptConnection
		local function finish(direction: Vector3)
			connection:Disconnect()
			busy = false
			if root.Parent and humanoid.Health > 0 then
				humanoid.Sit = false
				-- 레일 옆으로 내려선다(멈춤 막이·레일 위에 서지 않게)
				local side = direction:Cross(Vector3.yAxis)
				root.CFrame = CFrame.lookAt(root.Position + side.Unit * 4.5, root.Position + side.Unit * 4.5 + Vector3.new(direction.X, 0, direction.Z))
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			remote:FireServer("Done")
		end
		connection = RunService.Heartbeat:Connect(function(dt: number)
			if not root.Parent or humanoid.Health <= 0 then
				finish(Vector3.zAxis)
				return
			end
			local left = total - travelled
			local target = if left <= (speed * speed) / (2 * ACCEL) + 1 then SLOW else SPEED
			speed = if speed < target then math.min(target, speed + ACCEL * dt) else math.max(target, speed - ACCEL * 1.6 * dt)
			travelled = math.min(total, travelled + speed * dt)
			local position, direction = at(travelled)
			root.CFrame = CFrame.lookAt(position + lift, position + lift + direction)
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid.Sit = true
			if travelled >= total then
				finish(direction)
			end
		end)
	end)
end

return MineCartClient
