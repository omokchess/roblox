--!strict

local PlazaService = {}
PlazaService.__index = PlazaService

--[[
	플레이어 시작 지점(평원 섹터).

	능력을 주는 고대 대탑은 월드 원점(0,0)에 서 있지만, 원점은 탑의 나선 구조 내부라
	그곳에 스폰하면 나선 벽 사이에 끼어 움직일 수 없다. 그래서 시작점을 평원에 둔다.

	요청("평원쪽 마을 없애줘")으로 `World.PlainsVillage`를 통째로 지웠다. 그 안에 있던
	`VillageSpawn` 발판도 같이 사라졌으므로, 이제는 아래 _build()의 폴백 경로가 항상
	타면서 `PlazaSpawn`을 직접 만든다. 이 좌표의 지면은 `Ground_평원_-1_-1`(Y≈36)로
	비어 있는 평지다 — 마을을 다시 지을 때 이 값을 그 마을 중심으로 되돌리면 된다.
]]
local SPAWN_CENTER = Vector3.new(-990, 36, -990)

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Anchored = true
	value.Size = size
	value.Position = position
	value.Color = color
	value.Material = Enum.Material.Slate
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Parent = parent
	return value
end

local function surfaceYAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local plaza = workspace:FindFirstChild("PorcelainPlaza")
	if plaza then
		table.insert(ignore, plaza)
	end
	params.FilterDescendantsInstances = ignore
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
	local previous = workspace:FindFirstChild("PorcelainPlaza")
	if previous then
		previous:Destroy()
	end
	local plaza = Instance.new("Folder")
	plaza.Name = "PorcelainPlaza"
	plaza.Parent = workspace
	self.Model = plaza

	-- 원정대 게시판은 원정대 시스템과 함께 삭제됐다. 이제 광장에는 등반문만 있다.
	self:_buildTowerGate(plaza)

	-- 맵에 이미 배치해 둔 마을 스폰 발판이 있으면 그걸 그대로 쓴다.
	-- SpawnLocation이 둘이면 로블록스가 아무 쪽이나 고르므로 새로 만들지 않는다.
	local placed = workspace:FindFirstChild("VillageSpawn", true)
	if placed and placed:IsA("SpawnLocation") then
		placed.Neutral = true
		placed.Enabled = true
		self.Spawn = placed
		return
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(8, 1, 8)
	local spawnX = SPAWN_CENTER.X
	local spawnZ = SPAWN_CENTER.Z + 62
	spawn.Position = Vector3.new(spawnX, surfaceYAt(spawnX, spawnZ) + 3, spawnZ)
	spawn.Neutral = true
	spawn.Parent = plaza
	self.Spawn = spawn
end

--[[
	등반문(Tower Gate).

	요청: "탑 등반 할 땐 따로 등반 장소로 가서 등반 해야 해."

	예전에는 화면 왼쪽 위 버튼 하나로 어디서든 등반이 시작됐다. 이제 광장의 이 문
	앞까지 걸어와야 한다. 문을 통과하면 하늘의 개인 등반실로 옮겨진다
	(`TowerArena` 주석 참고).

	거리 검사는 **서버가 다시 한다**. ProximityPrompt의 MaxActivationDistance는
	연출이지 보안이 아니다 — 리모트는 누구나 아무 데서나 쏠 수 있다.
	`TowerService`가 이 파트 위치를 받아 직접 확인한다.
]]
function PlazaService:_buildTowerGate(plaza: Folder)
	-- 원정 게시판 반대편. 스폰에서 걸어 나오면 바로 보이는 자리다.
	local gateX = SPAWN_CENTER.X - 26
	local gateZ = SPAWN_CENTER.Z + 46
	local gateY = surfaceYAt(gateX, gateZ)

	local gate = part(
		plaza,
		"TowerGate",
		Vector3.new(10, 14, 2),
		Vector3.new(gateX, gateY + 7, gateZ),
		Color3.fromRGB(58, 44, 78)
	)
	gate.Material = Enum.Material.Marble

	-- 문틀. 순전히 눈에 띄라고 두는 것이라 충돌은 끈다.
	for _, side in { -1, 1 } do
		local pillar = part(
			plaza,
			"TowerGatePillar",
			Vector3.new(1.6, 17, 1.6),
			Vector3.new(gateX + side * 6, gateY + 8.5, gateZ),
			Color3.fromRGB(214, 198, 236)
		)
		pillar.Material = Enum.Material.Marble
		pillar.CanCollide = false
	end

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(180, 140, 255)
	glow.Range = 26
	glow.Brightness = 2
	glow.Parent = gate

	local sign = Instance.new("SurfaceGui")
	sign.Name = "TowerGateDisplay"
	sign.Face = Enum.NormalId.Back
	sign.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sign.CanvasSize = Vector2.new(500, 700)
	sign.LightInfluence = 0.2
	sign.Parent = gate

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.3)
	title.Position = UDim2.fromScale(0, 0.18)
	title.BackgroundTransparency = 1
	title.Text = "고대 대탑"
	title.TextColor3 = Color3.fromRGB(226, 206, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = sign

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.fromScale(1, 0.12)
	hint.Position = UDim2.fromScale(0, 0.52)
	hint.BackgroundTransparency = 1
	hint.Text = "E — 등반 시작"
	hint.TextColor3 = Color3.fromRGB(196, 176, 226)
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterTowerPrompt"
	prompt.ActionText = "등반 시작"
	prompt.ObjectText = "고대 대탑"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0.4
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate

	self.TowerGate = gate
	self.TowerGatePrompt = prompt
end

-- 스폰 링 위의 한 지점이 실제로 설 수 있는 곳인지 확인한다.
-- 캐릭터 반경만큼의 상자를 쏴서 막혀 있으면 false.
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

	-- 스폰 링에서 실제로 설 수 있는 자리를 고른다. 8칸을 모두 돌아도 없으면 스폰 발판 바로 위에 세운다.
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
	character:PivotTo(CFrame.lookAt(target, SPAWN_CENTER + Vector3.new(0, 8, 0)))
end

return PlazaService
