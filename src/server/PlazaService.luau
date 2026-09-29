--!strict
--[[
	PlazaService — 플레이어 시작 지점(스폰). (2026-09-28 다시 씀)

	요청: "스폰 위치 옮기고, 전투 입장 코드 너가 다시 짜줘."
	  - 고대 대탑 등반문은 전투 입장 코드와 함께 지웠다(`BattleService` 가 새 입장을 맡는다).
	  - 스폰은 절화 도성 배치표(`tools/jeolhwa_plan.py` KEEP "스폰광장" x 165..285, z 420..600)가
	    비워 둔 광장 한가운데. 궁 정문(225, 640)을 마주 본다.

	예전 값 (-990, 36, -990) 은 바다 한가운데라 시작하자마자 떨어졌다(스튜디오에서만 고친 값이
	동기화로 되돌아간 것 — 이제 이 파일이 기준이다).
	광장 지면은 y≈1.8(평원 흙 판). 동쪽 x 250 넘어서는 한 단(6.3) 높아 링이 거기 닿지 않게 225 에 둔다.
]]

local PlazaService = {}
PlazaService.__index = PlazaService

local SPAWN_CENTER = Vector3.new(225, 2, 520)
-- 시작할 때 바라볼 곳: 궁 정문
local LOOK_AT = Vector3.new(225, 8, 640)

local function surfaceYAt(x: number, z: number, ignore: Instance?): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { ignore } else {}
	local from = Vector3.new(x, SPAWN_CENTER.Y + 400, z)
	local result = workspace:Raycast(from, Vector3.new(0, -800, 0), params)
	return if result then result.Position.Y else SPAWN_CENTER.Y
end

function PlazaService.new()
	local self = setmetatable({}, PlazaService)
	self.SpawnIndex = 0
	self:_build()
	return self
end

function PlazaService:_build()
	for _, name in { "PlayerSpawnPoint", "PorcelainPlaza" } do
		local previous = workspace:FindFirstChild(name)
		if previous then
			previous:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlayerSpawnPoint"
	folder.Parent = workspace

	-- 보이지 않는 스폰 발판. 캐릭터는 `ensureR6` 가 만든 뒤 PlacePlayer 가 세우므로 표지 역할이다.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Neutral = true
	spawn.Position = Vector3.new(SPAWN_CENTER.X, surfaceYAt(SPAWN_CENTER.X, SPAWN_CENTER.Z, folder) + 0.5, SPAWN_CENTER.Z)
	spawn.Parent = folder
	self.Spawn = spawn
	self.Model = folder
end

-- 스폰 링 위의 한 지점이 실제로 설 수 있는 곳인지(캐릭터 크기 상자로 막힘 확인 + 발밑 땅)
local function isStandable(position: Vector3, ignore: Instance?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { ignore } else {}
	local blocked = workspace:Blockcast(CFrame.new(position), Vector3.new(4, 6, 4), Vector3.new(0, 0.1, 0), params)
	if blocked then
		return false
	end
	local ground = workspace:Raycast(position, Vector3.new(0, -24, 0), params)
	return ground ~= nil
end

function PlazaService:PlacePlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	self.SpawnIndex = (self.SpawnIndex + 1) % 8
	local base = self.Spawn.Position
	-- 링 8칸 중 설 수 있는 자리. 다 막혔으면 발판 바로 위.
	local target = base + Vector3.new(0, 4, 0)
	for step = 0, 7 do
		local angle = (((self.SpawnIndex + step) % 8) / 8) * math.pi * 2
		local candidate = base + Vector3.new(math.cos(angle) * 8, 4, math.sin(angle) * 8)
		if isStandable(candidate, character) then
			target = candidate
			break
		end
	end
	root.Anchored = false
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.AutoRotate = true
	character:PivotTo(CFrame.lookAt(target, Vector3.new(LOOK_AT.X, target.Y, LOOK_AT.Z)))
end

return PlazaService
