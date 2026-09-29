--!strict
--[[
	Battle3DController — 3D 전투 시험.

	요청: "이제 UI가 아니라 캐릭터가 직접 적이랑 싸우도록 3D에서 구현하면 돼."

	앞의 `BattleTestController`는 화면 안 격자 버튼으로만 확인하는 UI였다.
	여기서는 **월드에 실제 격자를 깔고, 플레이어 아바타와 적 모델을 그 위에 세운다.**

	사양 대응 (추가&수정.md `###### 배치`, `###### 전투`)
	  - 6×3 격자를 양 진영에 깐다 → 바닥 타일을 실제 파트로 생성
	  - 카메라는 Brown Dust식으로 **고정**한다 (전장을 비스듬히 내려다봄)
	  - 싸우는 건 플레이어 본인의 아바타 (사양: "싸우는 건 플레이어 본인의 아바타여야 함")
	  - 아군 타일을 클릭하면 캐릭터가 그 칸으로 걸어간다
	  - 스킬을 고르면 **적 진영 타일이 붉게** 칠해진다 (사양의 미리보기)
	  - `이 스킬로 선택` → 스킬 QTE → 결과 배율로 대미지
	  - 적 반격 → 회피·패리 QTE, 패리 성공 시 적 그로기 +15
	  - 적에 마우스를 올리면 그 스킬이 맞는지/피해가 얼마인지 패널로 보여준다
	  - 적의 공격 라인도 상시 미리보기한다 (아군 쪽 그 라인이 주황, 내가 그 라인이면 빨강)
	  - 한 공방이 끝날 때마다 적이 랜덤한 칸으로 이동한다
	  - 적이 쓰는 스킬도 매 턴 랜덤으로 골라, 사거리·범위·피해가 그때그때 달라진다
	  - 적의 반격 판정은 실제 레이캐스트로 한다: 중앙선에서 아군 쪽으로 레이를 쏴
	    플레이어에 닿는지 직접 확인하고, 닿은 지점에 짧은 섬광을 남긴다
	  - 스킬 사거리는 중앙선이 아니라 **그 라인에서 상대가 실제로 서 있는 칸**부터
	    시작한다(없으면 맨 끝 칸을 조준). 뒷줄로 물러나도 짧은 스킬에 맞는다 —
	    라인(=상대가 없는 라인으로 피함) 회피가 기본 방어 수단이다
	  - 스킬마다 범위를 BattleGrid.Shape로 정확히 정의한다: 찌르기·쌍베기는
	    상대가 있는 칸부터 2칸 직선(Line), 라인 관통은 라인 전체(Row), 십자 참은
	    상대를 중심으로 한 십자(Cross), 광역 폭발은 3×3 사각(Square)

	격자 좌표 ↔ 월드 변환은 `BattleArena`가 맡는다.
	칸 점유·범위 판정은 `BattleGrid`가 맡는다. 이 파일은 연출과 입력만 다룬다.

	**임시 파일이다.** 서버 권위가 없다. 실제 전투를 붙일 때 교체할 것.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)
local GroggyGauge = require(ReplicatedStorage.Shared.GroggyGauge)

local Battle3DController = {}
Battle3DController.__index = Battle3DController

--[[
	스킬은 **세로 라인**을 때린다 (사양). 마우스 조준이 없다.

	범위는 이제 BattleGrid.Shape로 정의한다(요청: 각 스킬의 정확한 범위 지정).
	origin은 그 라인에서 상대가 실제로 서 있는 칸 — 즉 아래 좌표들은 전부 "상대가
	있는 칸을 (n,n)이라 할 때" 기준이다.

	  찌르기    : (n,n),(n+1,n)                                — Line, Radius 2
	  라인 관통 : (0,n)~(6,n) = 라인 전체                        — Row
	  쌍베기    : (n,n),(n+1,n)                                — Line, Radius 2
	  십자 참   : (n,n),(n+1,n),(n-1,n),(n,n+1),(n,n-1)          — Cross, Radius 1
	  광역 폭발 : (n-1,n-1)~(n+1,n+1) 3×3                        — Square, Radius 1

	Row는 origin의 X를 아예 안 쓴다(라인 전체이므로). 나머지는 origin에 격자를
	벗어나지 않는 선에서 반영된다(Line은 뒤로 당김, Cross·Square는 격자 밖 칸만
	잘려나간다 — 가장자리 AOE는 원래 그렇게 좁아지는 게 자연스럽다).
]]
--[[
	스킬 표는 `ReplicatedStorage.Shared.BattleSkills`가 유일한 출처다.

	여기에 같은 표를 한 벌 더 들고 있었다. 서버가 판정을 가지게 되면서 공유 모듈을
	만들었는데 이 사본을 지우지 않아, **정의가 둘로 갈린 상태**가 됐다 — 한쪽만 고치면
	클라가 칠하는 칸과 서버가 때리는 칸이 어긋난다. 그게 이 시스템에서 가장 찾기 어려운
	버그라 공유 모듈에 경고까지 적어 뒀는데, 정작 사본을 남겨 두고 있었다.
]]
-- 시험판은 적 목록을 그대로 쓴다. 직업별 스킬은 서버 전투(TowerService)에만 붙었다.
local SKILLS = BattleSkills.Enemy()

local TILE_IDLE = Color3.fromRGB(70, 76, 92)
local TILE_ALLY = Color3.fromRGB(70, 130, 220)
local TILE_RANGE = Color3.fromRGB(190, 55, 60) -- 사양: 범위는 붉게
local TILE_OCCUPIED = Color3.fromRGB(120, 60, 60)
local TILE_DROP = Color3.fromRGB(90, 190, 120) -- 집어 옮길 때 놓을 수 있는 칸
local TILE_THREAT = Color3.fromRGB(220, 150, 60) -- 적의 공격 라인 (상시 미리보기)
local TILE_DANGER = Color3.fromRGB(230, 90, 60) -- 내가 그 라인에 서 있어 맞는 중
-- 명중 순간 1회성 섬광 색 ("레이저 표시 없애줘" 요청으로 상시 조준 빔은 없앴다)
local ALLY_HIT_FLASH = Color3.fromRGB(140, 200, 255)
local ENEMY_HIT_FLASH = Color3.fromRGB(255, 120, 70)

--[[
	칸 위 캐릭터 뿌리(HumanoidRootPart) 높이.

	요청: "플레이어랑 적이 플렛폼에서 좀 띄워져있어서 보기 약간 불편해.
	       플렛폼 위에 서있는 것처럼 연출 해줘."
	타일 윗면은 지면 raycast 지점(cf)에서 0.4 위다(타일 두께 0.4, 중심을 0.2
	띄워서 배치). R6 아바타는 서 있을 때 발(다리 밑)에서 루트까지 3스터드다.
	그래서 타일 윗면(0.4) + 서 있는 높이(3) = 3.4로, 발이 타일 표면에 닿아
	보통 서 있는 것처럼 보이게 잡는다. 그래도 Humanoid는 여전히 앵커된
	상태라 실제로 지면에 닿아 있는 건 아니다(점프 판정은 안 걸린다) —
	높이만 "서 있는 것처럼" 보이게 낮췄을 뿐이다.
]]
local FLOAT_HEIGHT = 3.4

-- 적 더미(다리 없는 몸통+머리)의 몸통 중심 높이. 몸통이 2스터드라 바닥(=발)이
-- 타일 표면(0.4)에 닿도록 절반인 1을 더했다 — 위 FLOAT_HEIGHT와 같은 이유.
local ENEMY_TORSO_HEIGHT = 1.4
local ENEMY_HEAD_HEIGHT = ENEMY_TORSO_HEIGHT + 1.6

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(class)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Battle3DController.new()
	local self = setmetatable({}, Battle3DController)
	self.player = Players.LocalPlayer
	self.grid = BattleGrid.New()
	self.enemyGroggy = GroggyGauge.New()
	self.selectedSkill = 1
	self.enemyCell = { X = 1, Y = 2 } -- 적: 전열(x=1), 가운데 라인(y=2)
	self.playerCell = { X = 3, Y = 1 }
	self.active = false
	self.tiles = {}
	self.qte = nil :: QteDefinitions.Challenge?
	self.qteStart = 0
	self.qteConn = nil :: RBXScriptConnection?
	self.dragging = false
	self.dragHover = nil
	self.dragConn = nil :: RBXScriptConnection?
	self.enemyRng = Random.new(math.floor(os.clock() * 1000) % 2147483647)
	self.enemySkill = SKILLS[1] -- Start()에서 랜덤으로 다시 뽑는다
	self.lastEnemyHitPosition = nil :: Vector3?

	self:_buildUi()
	self:_bindInput()

	--[[
		전투 중에 캐릭터가 리스폰되면 새 캐릭터에는 부양·조작차단이 걸려 있지 않다.
		그대로 두면 전투 중인데 걸어 다닐 수 있고 바닥으로 떨어진다.
		→ 새 캐릭터가 들어오면 전투 자세를 다시 씌우고 원래 칸에 놓는다.
	]]
	self.player.CharacterAdded:Connect(function()
		if not self.active then
			return
		end
		task.wait(0.2) -- 팔다리가 다 붙을 때까지 기다린다
		if self.active then
			self:_setBattlePose(true)
			self:_moveCharacterTo(self.playerCell.X, self.playerCell.Y)
			self:_lockCamera()
		end
	end)

	return self
end

--=== UI (최소한만) ===--

function Battle3DController:_buildUi()
	local gui = make("ScreenGui", {
		Name = "Battle3DGui",
		ResetOnSpawn = false,
	}, self.player:WaitForChild("PlayerGui"))
	self.gui = gui

	self.startButton = make("TextButton", {
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0, 16, 1, -170),
		BackgroundColor3 = Color3.fromRGB(150, 40, 44),
		Text = "전투 시작 (3D)",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, self.startButton)
	self.startButton.Activated:Connect(function()
		if self.active then
			self:Stop()
		else
			self:Start()
		end
	end)

	-- 하단 스킬 바
	self.bar = make("Frame", {
		Size = UDim2.fromOffset(700, 92),
		Position = UDim2.new(0.5, -350, 1, -110),
		BackgroundColor3 = Color3.fromRGB(20, 22, 28),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, self.bar)

	self.skillButtons = {}
	for index, skill in SKILLS do
		local button = make("TextButton", {
			Size = UDim2.fromOffset(110, 34),
			Position = UDim2.fromOffset(12 + (index - 1) * 116, 10),
			BackgroundColor3 = Color3.fromRGB(48, 52, 62),
			Text = skill.Name,
			TextColor3 = Color3.fromRGB(225, 225, 235),
			Font = Enum.Font.Gotham,
			TextSize = 13,
		}, self.bar)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		button.Activated:Connect(function()
			-- 눌러보기만 하는 미리보기다. 확정이 아니다(사양).
			self.selectedSkill = index
			self:_paintTiles()
		end)
		self.skillButtons[index] = button
	end

	self.confirmButton = make("TextButton", {
		Size = UDim2.fromOffset(150, 32),
		Position = UDim2.fromOffset(12, 52),
		BackgroundColor3 = Color3.fromRGB(150, 40, 44),
		Text = "이 스킬로 선택",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, self.bar)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.confirmButton)
	self.confirmButton.Activated:Connect(function()
		self:_startQte("Skill")
	end)

	self.status = make("TextLabel", {
		Size = UDim2.fromOffset(520, 32),
		Position = UDim2.fromOffset(172, 52),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.bar)

	-- QTE 오버레이 (3D 전투 위에 뜬다)
	self.qteFrame = make("Frame", {
		Size = UDim2.fromOffset(320, 170),
		Position = UDim2.new(0.5, -160, 0.5, -85),
		BackgroundColor3 = Color3.fromRGB(14, 16, 22),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 30,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, self.qteFrame)

	self.qteTitle = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		ZIndex = 31,
	}, self.qteFrame)

	self.sweepTrack = make("Frame", {
		Size = UDim2.fromOffset(260, 24),
		Position = UDim2.fromOffset(30, 72),
		BackgroundColor3 = Color3.fromRGB(40, 43, 52),
		Visible = false,
		ZIndex = 31,
	}, self.qteFrame)
	self.sweepTarget = make("Frame", {
		Size = UDim2.fromScale(0.18, 1),
		BackgroundColor3 = Color3.fromRGB(60, 170, 90),
		ZIndex = 32,
	}, self.sweepTrack)
	self.sweepCursor = make("Frame", {
		Size = UDim2.fromOffset(5, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 33,
	}, self.sweepTrack)

	self.ringHolder = make("Frame", {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromOffset(105, 34),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 31,
	}, self.qteFrame)
	self.ringTarget = make("Frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0.5, -22, 0.5, -22),
		BackgroundColor3 = Color3.fromRGB(60, 170, 90),
		BackgroundTransparency = 0.5,
		ZIndex = 31,
	}, self.ringHolder)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.ringTarget)
	self.ringMoving = make("Frame", {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.new(0.5, -55, 0.5, -55),
		BackgroundColor3 = Color3.fromRGB(90, 150, 240),
		BackgroundTransparency = 0.35,
		ZIndex = 32,
	}, self.ringHolder)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.ringMoving)

	self.qteBig = make("TextLabel", {
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.fromOffset(10, 60),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Visible = false,
		ZIndex = 31,
	}, self.qteFrame)

	self.qteHint = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 142),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(160, 165, 180),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ZIndex = 31,
	}, self.qteFrame)

	-- 적에 마우스를 올렸을 때 뜨는 스킬 미리보기 패널 (커서를 따라다닌다)
	self.hoverPanel = make("Frame", {
		Name = "SkillHover",
		Size = UDim2.fromOffset(220, 74),
		BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 40,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, self.hoverPanel)
	make("UIStroke", { Color = Color3.fromRGB(120, 130, 160), Thickness = 1, Transparency = 0.3 }, self.hoverPanel)

	self.hoverTitle = make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
	}, self.hoverPanel)

	self.hoverBody = make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 28),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 41,
	}, self.hoverPanel)
end

--=== 전투 시작 / 종료 ===--

function Battle3DController:Start()
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	self.active = true
	self.startButton.Text = "전투 종료"
	self.bar.Visible = true

	-- 전장 원점: 캐릭터가 선 자리에서 조금 앞
	local origin = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector)
	self.layout = BattleArena.NewLayout(origin)

	self.folder = make("Folder", { Name = "Battle3DArena" }, workspace)

	-- 지형에 맞춰 타일을 놓기 위한 레이캐스트 필터 (전장 자체는 제외)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.folder, character }
	self.rayParams = params

	self.grid = BattleGrid.New()
	self.enemyGroggy = GroggyGauge.New()
	self.tiles = { Ally = {}, Enemy = {} }

	for _, side in { "Ally", "Enemy" } :: { BattleGrid.Side } do
		for y = 1, self.grid.Height do
			self.tiles[side][y] = {}
			for x = 1, self.grid.Width do
				local cf =
					BattleArena.CellWorldCFrame(self.layout, side, x, y, self.grid.Width, self.grid.Height, params)
				local tile = make("Part", {
					Name = string.format("Tile_%s_%d_%d", side, x, y),
					Anchored = true,
					CanCollide = false,
					Size = BattleArena.TileSize(self.layout),
					CFrame = cf + Vector3.new(0, 0.2, 0),
					Color = TILE_IDLE,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.35,
					TopSurface = Enum.SurfaceType.Smooth,
					BottomSurface = Enum.SurfaceType.Smooth,
				}, self.folder)

				-- 아군 칸은 드래그로 옮긴다(_beginDrag). 공격 조준은 라인 자동이라 클릭이 없다.

				self.tiles[side][y][x] = tile
			end
		end
	end

	-- 적 더미를 세운다
	self.enemyModel = self:_spawnEnemy()
	BattleGrid.Place(self.grid, "enemy", "Enemy", self.enemyCell.X, self.enemyCell.Y)
	self:_pickEnemySkill()
	BattleGrid.Place(self.grid, "player", "Ally", self.playerCell.X, self.playerCell.Y)

	-- 캐릭터를 떠 있는 말로 만들고(조작 차단 + 앵커) 자기 칸에 놓는다
	self:_setBattlePose(true)
	self:_moveCharacterTo(self.playerCell.X, self.playerCell.Y)
	self:_faceRight() -- 사양: 턴 시작 시 항상 오른쪽(적 진영)을 바라본다

	-- 사양: 카메라를 Brown Dust식으로 고정
	self:_lockCamera()
	self:_paintTiles()

	-- 적 마우스오버 미리보기 루프
	self.hoverConn = RunService.RenderStepped:Connect(function()
		self:_updateHover()
	end)
end

function Battle3DController:Stop()
	self.active = false
	self:_endDrag()
	if self.hoverConn then
		self.hoverConn:Disconnect()
		self.hoverConn = nil
	end
	if self.hoverPanel then
		self.hoverPanel.Visible = false
	end

	-- 앵커를 풀기 전에 지면으로 내려놓는다. 안 그러면 떠 있던 높이에서 떨어진다.
	local root = self:_root()
	if root and self.rayParams then
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -200, 0), self.rayParams)
		if hit then
			root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0))
		end
	end

	self:_setBattlePose(false)
	self.startButton.Text = "전투 시작 (3D)"
	self.bar.Visible = false
	self:_endQte()

	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	if self.enemyModel then
		self.enemyModel:Destroy()
		self.enemyModel = nil
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	if self.player.Character then
		camera.CameraSubject = self.player.Character:FindFirstChildWhichIsA("Humanoid")
	end
end

-- 적 더미: R6 형태의 간단한 모델
function Battle3DController:_spawnEnemy(): Model
	local model = make("Model", { Name = "BattleDummy" }, workspace)
	local cf = BattleArena.CellWorldCFrame(
		self.layout,
		"Enemy",
		self.enemyCell.X,
		self.enemyCell.Y,
		self.grid.Width,
		self.grid.Height,
		self.rayParams
	)

	-- 칸(5스터드)에 들어가는 크기. R6 아바타와 비슷하게 잡는다.
	local torso = make("Part", {
		Name = "Torso",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(2, 2, 1),
		CFrame = cf + Vector3.new(0, ENEMY_TORSO_HEIGHT, 0),
		Color = Color3.fromRGB(150, 60, 60),
		Material = Enum.Material.SmoothPlastic,
	}, model)
	make("Part", {
		Name = "Head",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = cf + Vector3.new(0, ENEMY_HEAD_HEIGHT, 0),
		Color = Color3.fromRGB(180, 90, 90),
		Material = Enum.Material.SmoothPlastic,
	}, model)

	model.PrimaryPart = torso

	-- 머리 위 체력·그로기 표시
	local billboard = make("BillboardGui", {
		Name = "Status",
		Size = UDim2.fromOffset(140, 36),
		StudsOffset = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = true,
	}, torso)
	self.enemyLabel = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 220),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, billboard)

	return model
end

--[[
	적을 랜덤한 칸으로 옮긴다.

	요청: "매 턴마다 적이 랜덤한 위치로 이동하게도 해줘."
	→ 한 번의 공방(플레이어 스킬 + 적 반격, 또는 라인이 달라 빗나간 경우)이
	  끝날 때마다 부른다. `_endTurn()`이 호출 지점을 모은다.

	같은 칸으로 다시 뽑히지 않도록 다른 칸이 나올 때까지 다시 뽑는다
	(칸이 18개뿐이라 반복해도 금방 끝난다. 칸이 1개뿐이면 그냥 둔다).
]]
--[[
	적이 이번 턴에 쓸 스킬을 무작위로 고른다.

	요청: "사용하는 스킬도 랜덤이 되게 해줘."
	플레이어와 같은 SKILLS 목록을 공유한다 — 범위(Shape)·피해가 스킬마다 달라서,
	위협 범위 미리보기도 이제 라인 전체가 아니라 그 스킬이 실제로 닿는 칸만
	정확히 보여준다.
]]
function Battle3DController:_pickEnemySkill()
	self.enemySkill = SKILLS[self.enemyRng:NextInteger(1, #SKILLS)]
end

function Battle3DController:_repositionEnemy()
	if not self.active or not self.enemyModel or not self.layout then
		return
	end

	local totalCells = self.grid.Width * self.grid.Height
	if totalCells <= 1 then
		return
	end

	local nx, ny
	repeat
		nx = self.enemyRng:NextInteger(1, self.grid.Width)
		ny = self.enemyRng:NextInteger(1, self.grid.Height)
	until nx ~= self.enemyCell.X or ny ~= self.enemyCell.Y

	if not BattleGrid.Move(self.grid, "enemy", nx, ny) then
		return
	end
	self.enemyCell = { X = nx, Y = ny }

	local cf =
		BattleArena.CellWorldCFrame(self.layout, "Enemy", nx, ny, self.grid.Width, self.grid.Height, self.rayParams)
	-- PivotTo는 Torso(PrimaryPart)와 Head의 상대 위치를 유지한 채 모델 전체를 옮긴다.
	self.enemyModel:PivotTo(cf + Vector3.new(0, ENEMY_TORSO_HEIGHT, 0))
end

-- 한 공방이 끝날 때 부른다: 적을 새 위치로 옮기고 화면을 갱신한다.
function Battle3DController:_endTurn()
	self:_repositionEnemy()
	self:_pickEnemySkill()
	self:_paintTiles()
end

--=== 카메라 고정 (사양: Brown Dust식) ===--

-- 카메라를 내려다보는 각도. 45도면 격자가 마름모로 잘 보인다.
local CAMERA_PITCH = 45

function Battle3DController:_lockCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9

	-- 격자 크기와 화각으로 거리를 계산하므로 칸 크기를 바꿔도 전부 담긴다.
	camera.CFrame = BattleArena.FitCameraCFrame(
		self.layout,
		self.grid.Width,
		self.grid.Height,
		camera.FieldOfView,
		aspect,
		CAMERA_PITCH
	)
end

--=== 이동 ===--

function Battle3DController:_onTileClicked(_side: BattleGrid.Side, _x: number, _y: number)
	-- 사양: 공격은 플레이어가 선 세로 라인으로 자동 결정된다. 마우스 조준은 없다.
	-- (적 타일 클릭 기능은 제거됐다. 이 함수는 호출되지 않는다.)
end

--[[
	칸 위 '떠 있는' 위치. 지면에서 FLOAT_HEIGHT만큼 띄운다.
	마우스로 집어 옮기는 방식이라 캐릭터는 항상 공중에 있다.
]]
function Battle3DController:_cellAnchorCFrame(side: BattleGrid.Side, x: number, y: number): CFrame
	local cf = BattleArena.CellWorldCFrame(self.layout, side, x, y, self.grid.Width, self.grid.Height, self.rayParams)
	-- 위치는 칸, 회전은 항상 오른쪽(+X) 바라보기로 고정한다.
	local pos = (cf + Vector3.new(0, FLOAT_HEIGHT, 0)).Position
	local right = self.layout.Origin.RightVector
	return CFrame.lookAt(pos, pos + right)
end

--[[
	턴 시작 시 캐릭터가 항상 오른쪽(+X, 적 진영)을 바라보게 한다.
	아군은 화면 왼쪽에 있고 적은 오른쪽이므로 오른쪽을 봐야 마주 본다.
]]
function Battle3DController:_faceRight()
	local root = self:_root()
	if not root or not self.layout then
		return
	end
	local right = self.layout.Origin.RightVector -- +X = 적 방향
	root.CFrame = CFrame.lookAt(root.Position, root.Position + right)
end

function Battle3DController:_root(): BasePart?
	local character = self.player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

--[[
	캐릭터를 칸으로 옮긴다.

	사양: "마우스로 캐릭터를 잡았다가 원하는 칸에 놓는 식"
	→ 걸어가지 않는다. 집어서 놓는 것이므로 위치를 바로 바꾼다.
]]
function Battle3DController:_moveCharacterTo(x: number, y: number)
	local root = self:_root()
	if not root then
		return
	end
	root.CFrame = self:_cellAnchorCFrame("Ally", x, y)
	self:_syncStand()
end

--[[
	전투 중 캐릭터를 '떠 있는 말'로 만든다.

	사양 두 가지를 함께 처리한다.
	  "전투 시작을 했는데도 캐릭터를 움직일 수 있어" → 직접 조작을 막는다
	  "캐릭터가 공중에 떠있어야 해. 점프 판정이면 안 돼" → 앵커 + 낙하/점프 상태 차단

	HumanoidRootPart를 앵커하면 물리로 떨어지지 않는다. 다만 그것만으로는
	Humanoid가 Freefall로 판정해 낙하 애니메이션이 나오므로 관련 상태를 꺼 준다.
]]
--[[
	전투 중 캐릭터를 '떠 있는 말'로 만든다.

	사양 두 가지를 함께 처리한다.
	  "전투 시작을 했는데도 캐릭터를 움직일 수 있어"      → 직접 조작을 막는다
	  "캐릭터가 공중에 떠있어야 해. 점프 판정이면 안 돼"  → 낙하·점프 판정을 없앤다

	점프 판정을 막는 방법을 **두 겹으로** 둔다.
	  1) Freefall/Jumping/FallingDown 상태를 끈다
	  2) 발밑에 보이지 않는 받침을 깔아 Humanoid가 '땅에 서 있다'고 인식하게 한다

	2번이 필요한 이유: 앵커만 하고 상태만 끄면 리그(R6/R15)와 기본 Animate 스크립트에 따라
	낙하 자세가 남을 수 있다. 발밑에 바닥이 실제로 있으면 어떤 리그에서도 서 있는 판정이 된다.
]]
function Battle3DController:_setBattlePose(enabled: boolean)
	local character = self.player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if humanoid then
		humanoid.WalkSpeed = if enabled then 0 else 16
		humanoid.JumpPower = if enabled then 0 else 50
		humanoid.AutoRotate = not enabled

		for _, state in
			{
				Enum.HumanoidStateType.Freefall,
				Enum.HumanoidStateType.Jumping,
				Enum.HumanoidStateType.FallingDown,
			}
		do
			humanoid:SetStateEnabled(state, not enabled)
		end

		if enabled then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end

	if enabled then
		-- 발밑 받침. 보이지 않지만 충돌은 한다.
		if not self.standPlatform then
			self.standPlatform = make("Part", {
				Name = "BattleStand",
				Anchored = true,
				CanCollide = true,
				Transparency = 1,
				Size = Vector3.new(4, 0.4, 4),
				CFrame = CFrame.new(0, -500, 0),
			}, self.folder)
		end
		self:_syncStand()
	else
		if self.standPlatform then
			self.standPlatform:Destroy()
			self.standPlatform = nil
		end
	end

	if root then
		root.Anchored = enabled
	end
end

-- 받침을 캐릭터 발밑으로 옮긴다. 캐릭터를 옮길 때마다 부른다.
function Battle3DController:_syncStand()
	local root = self:_root()
	if not root or not self.standPlatform then
		return
	end
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 2
	-- 루트 밑 (엉덩이 높이 + 다리 절반)만큼 내려가면 발바닥이다
	self.standPlatform.CFrame = CFrame.new(root.Position - Vector3.new(0, hipHeight + 1.2, 0))
end

--=== 드래그 앤 드롭 ===--
--[[
	사양: "캐릭터는 마우스로 캐릭터를 잡았다가, 원하는 칸에 놓는 식"

	체스 말처럼 집어 옮긴다.
	  누르기  → 캐릭터를 집는다. 놓을 수 있는 아군 칸이 초록으로 표시된다
	  끌기    → 캐릭터가 커서를 따라 공중에 뜬 채 움직인다
	  떼기    → 커서 아래 아군 칸에 놓는다. 칸 밖이면 원래 자리로 돌아간다

	걸어가지 않으므로 이동 애니메이션도, 점프 판정도 생기지 않는다.
]]

-- 타일 파트만 모은다 (레이캐스트 필터용)
function Battle3DController:_allTiles(): { BasePart }
	local list: { BasePart } = {}
	for _, side in { "Ally", "Enemy" } :: { BattleGrid.Side } do
		local rows = self.tiles[side]
		if rows then
			for _, row in rows do
				for _, tile in row do
					table.insert(list, tile)
				end
			end
		end
	end
	return list
end

-- 커서 아래에 있는 타일을 찾는다. (타일만 맞도록 필터한다)
function Battle3DController:_tileUnderCursor(): (BattleGrid.Side?, number?, number?)
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	--[[
		타일만 포함시킨다. folder 전체를 넣으면 발밑 받침(BattleStand)이
		커서 레이를 먼저 막아 타일을 못 찾는다.
	]]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = self:_allTiles()

	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then
		return nil, nil, nil
	end

	-- 타일 이름에 좌표를 박아 두었으므로 그대로 읽는다
	local side, x, y = hit.Instance.Name:match("^Tile_(%a+)_(%d+)_(%d+)$")
	if not side then
		return nil, nil, nil
	end
	return side :: BattleGrid.Side, tonumber(x), tonumber(y)
end

function Battle3DController:_beginDrag()
	if not self.active or self.qte or self.dragging then
		return
	end
	-- 캐릭터를 눌렀을 때만 집는다
	local side, x, y = self:_tileUnderCursor()
	local onSelf = side == "Ally" and x == self.playerCell.X and y == self.playerCell.Y
	if not onSelf and not self:_cursorOnCharacter() then
		return
	end

	self.dragging = true
	self.dragConn = RunService.RenderStepped:Connect(function()
		self:_updateDrag()
	end)
	self:_paintTiles()
end

-- 커서가 캐릭터 위에 있는지 (타일보다 캐릭터가 앞에 있을 때)
function Battle3DController:_cursorOnCharacter(): boolean
	local character = self.player.Character
	if not character then
		return false
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { character }

	return workspace:Raycast(ray.Origin, ray.Direction * 2000, params) ~= nil
end

-- 끄는 동안 캐릭터가 커서를 따라다닌다 (항상 공중)
function Battle3DController:_updateDrag()
	local root = self:_root()
	if not root or not self.dragging then
		return
	end

	local side, x, y = self:_tileUnderCursor()
	if side == "Ally" and x and y then
		-- 놓을 수 있는 칸 위면 그 칸에 스냅해 보여 준다
		root.CFrame = self:_cellAnchorCFrame("Ally", x, y)
		self:_syncStand()
		self.dragHover = { X = x, Y = y }
	else
		self.dragHover = nil
	end
	self:_paintTiles()
end

function Battle3DController:_endDrag()
	if self.dragConn then
		self.dragConn:Disconnect()
		self.dragConn = nil
	end
	if not self.dragging then
		return
	end
	self.dragging = false

	local hover = self.dragHover
	self.dragHover = nil

	if hover and BattleGrid.Move(self.grid, "player", hover.X, hover.Y) then
		self.playerCell = { X = hover.X, Y = hover.Y }
	end
	-- 놓지 못했으면 원래 칸으로 되돌린다
	self:_moveCharacterTo(self.playerCell.X, self.playerCell.Y)
	self:_paintTiles()
end

--=== 타일 색칠 (사양: 범위는 붉게) ===--

--[[
	스킬이 붉게 칠할 상대 칸 목록 (미리보기 = 실제 대상과 같은 규칙).

	origin은 **공격자가 선 라인(lane)에서 상대가 실제로 서 있는 칸**이다
	(요청: "적을 조준했을 때 좌표가 그대로 반영돼야 한다"). BattleGrid.CellsInShape가
	그 origin 기준으로 skill.Shape를 펼친다 — Cross·Square는 origin의 라인뿐
	아니라 위아래 라인까지도 이 한 번의 호출로 알아서 나온다.

	Row(라인 관통)는 origin의 X를 쓰지 않으므로 상대가 없어도 라인 전체를
	그대로 칠한다. 그 외 모양은 그 라인에 상대가 없으면 아예 칸을 넣지 않는다
	— 없는 상대 자리에 동떨어진 칸 하나가 붉게 뜨는 것("가중치 표시가
	이상하다")을 막는다.
]]
--[[
	계산은 공유 모듈에 맡긴다. 여기 있던 구현은 `BattleSkills.Cells`와 글자까지 같은
	사본이었다 — 스킬 표에 이어 **판정 규칙까지 두 벌**이었던 셈이다. 한쪽만 고치면
	클라가 칠하는 칸과 서버가 때리는 칸이 어긋난다.
]]
function Battle3DController:_skillCells(attackerSide: BattleGrid.Side, lane: number, skill): { BattleGrid.Cell }
	return BattleSkills.Cells(self.grid, attackerSide, lane, skill.Shape)
end

function Battle3DController:_skillTargets(attackerSide: BattleGrid.Side, lane: number, skill): { string }
	return BattleSkills.Targets(self.grid, attackerSide, lane, skill.Shape)
end

-- 스킬 사정을 사람이 읽는 문장으로.
local function skillRangeText(skill): string
	local shape = skill.Shape
	if shape.Kind == "Row" then
		return "라인 전체"
	elseif shape.Kind == "Line" then
		return string.format("앞 %d칸", shape.Radius or 1)
	elseif shape.Kind == "Cross" then
		return "십자 범위"
	elseif shape.Kind == "Square" then
		local width = (shape.Radius or 1) * 2 + 1
		return string.format("%d×%d 범위", width, width)
	end
	return "범위"
end

function Battle3DController:_paintTiles()
	if not self.active then
		return
	end
	local skill = SKILLS[self.selectedSkill]

	-- 공격 대상 라인 = 플레이어가 선 세로 라인 (사양: 마우스로 정하지 않는다)
	local inRange: { [string]: boolean } = {}
	for _, cell in self:_skillCells("Ally", self.playerCell.Y, skill) do
		inRange[cell.X .. "," .. cell.Y] = true
	end

	--[[
		적 공격 라인 상시 미리보기 (사양: 적 공격 범위도 미리보기).
		적도 이제 매 턴 스킬을 랜덤으로 고르므로, 위협 범위는 그 스킬의
		실제 범위(Shape)로 정확히 계산한다 — 라인 전체를 뭉뚱그리지 않는다.
		(_skillCells가 플레이어 스킬 미리보기와 같은 함수라 계산 방식이 어긋나지 않는다)
	]]
	local threatLane = self.enemyCell.Y
	local threatened_: { [string]: boolean } = {}
	for _, cell in self:_skillCells("Enemy", threatLane, self.enemySkill) do
		threatened_[cell.X .. "," .. cell.Y] = true
	end

	for y = 1, self.grid.Height do
		for x = 1, self.grid.Width do
			local allyTile = self.tiles.Ally[y][x]
			local isMe = self.playerCell.X == x and self.playerCell.Y == y
			local hovered = self.dragHover and self.dragHover.X == x and self.dragHover.Y == y
			local threatened = threatened_[x .. "," .. y] == true
			if self.dragging then
				-- 집고 있는 동안엔 놓을 수 있는 칸을 초록으로 보여 준다
				allyTile.Color = if hovered then TILE_DROP else TILE_IDLE
				allyTile.Transparency = if hovered then 0.05 else 0.3
			elseif isMe and threatened then
				-- 지금 서 있는 라인이 적의 공격 라인과 같다 → 위험
				allyTile.Color = TILE_DANGER
				allyTile.Transparency = 0.08
			elseif isMe then
				allyTile.Color = TILE_ALLY
				allyTile.Transparency = 0.15
			elseif threatened then
				allyTile.Color = TILE_THREAT
				allyTile.Transparency = 0.35
			else
				allyTile.Color = TILE_IDLE
				allyTile.Transparency = 0.45
			end

			local foeTile = self.tiles.Enemy[y][x]
			local hot = inRange[x .. "," .. y] == true
			local occupied = BattleGrid.Occupant(self.grid, "Enemy", x, y) ~= nil
			foeTile.Color = if hot then TILE_RANGE elseif occupied then TILE_OCCUPIED else TILE_IDLE
			foeTile.Transparency = if hot then 0.1 else 0.45
		end
	end

	for index, button in self.skillButtons do
		button.BackgroundColor3 = if index == self.selectedSkill
			then Color3.fromRGB(70, 90, 140)
			else Color3.fromRGB(48, 52, 62)
	end

	local targets = self:_skillTargets("Ally", self.playerCell.Y, skill)
	local playerInDanger = threatened_[self.playerCell.X .. "," .. self.playerCell.Y] == true
	local threatNote =
		string.format(" · 적 스킬 %s(사정 %s)", self.enemySkill.Name, skillRangeText(self.enemySkill))
	if playerInDanger then
		threatNote ..= " ⚠ 위험!"
	end
	self.status.Text = string.format(
		"%s · 기본 %d · 내 라인(%d)의 적 %d명   |   드래그로 라인 이동%s",
		skill.Name,
		skill.Damage,
		self.playerCell.Y,
		#targets,
		threatNote
	)
	self:_refreshEnemyLabel()
end

--=== 적 마우스오버 스킬 미리보기 ===--

--[[
	커서 아래의 적을 찾는다. 적 타일(Tile_Enemy_x_y)이나 적 모델을 맞히면
	그 적의 칸 (x, y)을 돌려준다. 없으면 nil.
]]
function Battle3DController:_enemyUnderCursor(): (number?, number?)
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local include: { Instance } = {}
	if self.folder then
		table.insert(include, self.folder)
	end
	if self.enemyModel then
		table.insert(include, self.enemyModel)
	end
	params.FilterDescendantsInstances = include

	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then
		return nil, nil
	end

	-- 적 모델을 맞혔으면 적 칸을 그대로 쓴다.
	if self.enemyModel and hit.Instance:IsDescendantOf(self.enemyModel) then
		return self.enemyCell.X, self.enemyCell.Y
	end

	-- 적 타일이면 이름에서 좌표를 읽는다. 실제 유닛이 있는 칸만 대상.
	local sx, x, y = hit.Instance.Name:match("^Tile_(%a+)_(%d+)_(%d+)$")
	if sx == "Enemy" then
		local cx, cy = tonumber(x), tonumber(y)
		if BattleGrid.Occupant(self.grid, "Enemy", cx, cy) then
			return cx, cy
		end
	end
	return nil, nil
end

--[[
	미리보기 갱신. 전투 중 매 프레임 돈다.
	적 위에 커서가 있으면 지금 선택한 스킬이 그 적을 맞히는지, 예상 피해를 보여 준다.
	공격 대상은 마우스가 아니라 플레이어의 세로 라인으로 정해지므로,
	"이 적이 내 라인 안이라 맞는지"를 알려 주는 것이 핵심이다.
]]
function Battle3DController:_updateHover()
	if not self.active or self.qte or self.dragging or not self.hoverPanel then
		if self.hoverPanel then
			self.hoverPanel.Visible = false
		end
		return
	end

	local ex, ey = self:_enemyUnderCursor()
	if not ex then
		self.hoverPanel.Visible = false
		return
	end

	local skill = SKILLS[self.selectedSkill]
	-- 이 스킬이 실제로 맞히는 적 칸 목록 (플레이어 라인 기준)
	local hitCells = self:_skillCells("Ally", self.playerCell.Y, skill)
	local willHit = false
	for _, cell in hitCells do
		if cell.X == ex and cell.Y == ey then
			willHit = true
			break
		end
	end

	self.hoverTitle.Text = skill.Name
	if willHit then
		self.hoverTitle.TextColor3 = Color3.fromRGB(255, 210, 120)
		self.hoverBody.Text = string.format(
			"이 적을 맞힙니다\n피해 %d  (QTE ×0.5~1.2)  ·  사정 %s",
			skill.Damage,
			skillRangeText(skill)
		)
	else
		self.hoverTitle.TextColor3 = Color3.fromRGB(150, 155, 170)
		self.hoverBody.Text = string.format(
			"내 라인(%d)이 아니라 못 맞힙니다\n%d번 라인으로 이동하거나 다른 스킬을 고르세요",
			self.playerCell.Y,
			ey
		)
	end

	-- 패널을 커서 오른쪽 아래에 붙인다 (화면 밖으로 안 나가게)
	local mouse = UserInputService:GetMouseLocation()
	local vp = workspace.CurrentCamera.ViewportSize
	local px = math.min(mouse.X + 16, vp.X - 230)
	local py = math.min(mouse.Y + 12, vp.Y - 84)
	self.hoverPanel.Position = UDim2.fromOffset(px, py)
	self.hoverPanel.Visible = true
end

function Battle3DController:_refreshEnemyLabel()
	if not self.enemyLabel then
		return
	end
	self.enemyLabel.Text = string.format(
		"그로기 %d/%d%s",
		self.enemyGroggy.Value,
		GroggyGauge.MAX,
		if GroggyGauge.IsStunned(self.enemyGroggy) then "  [스턴]" else ""
	)
end

--=== QTE (BattleTestController와 같은 규칙) ===--

function Battle3DController:_startQte(role: QteDefinitions.Role)
	if not self.active or self.qte then
		return
	end
	self:_endQte()

	local random = Random.new(math.floor(os.clock() * 1000))
	local challenge = QteDefinitions.Create(role, function()
		return random:NextNumber()
	end, 0, "b3d", true)

	self.qte = challenge
	self.qteStart = os.clock()
	self.qteFrame.Visible = true
	self.qteTitle.Text =
		string.format("%s — %s", if role == "Skill" then "스킬" else "회피/패리", challenge.Title)

	self.sweepTrack.Visible = challenge.Type == "Sweep"
	self.ringHolder.Visible = challenge.Type == "Forge" or challenge.Type == "Parry"
	self.qteBig.Visible = challenge.Type == "Mash" or challenge.Type == "Directional"
	self.qteHint.Text = if challenge.Type == "Mash"
		then "스페이스 연타"
		elseif challenge.Type == "Directional" then "방향키 / WASD"
		else "스페이스 또는 클릭"

	self.qteConn = RunService.RenderStepped:Connect(function()
		self:_tickQte()
	end)
end

function Battle3DController:_tickQte()
	local challenge = self.qte
	if not challenge then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000
	local state = QteDefinitions.VisualState(challenge, elapsed)

	if challenge.Type == "Sweep" then
		self.sweepCursor.Position = UDim2.fromScale(state.position, 0)
		self.sweepTarget.Position = UDim2.fromScale(math.max(state.targetPosition - state.successGap, 0), 0)
		self.sweepTarget.Size = UDim2.fromScale(state.successGap * 2, 1)
	elseif challenge.Type == "Forge" or challenge.Type == "Parry" then
		local size = math.max(state.outerRadius, 0) * 110
		self.ringMoving.Size = UDim2.fromOffset(size, size)
		self.ringMoving.Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2)
		local targetSize = state.targetRadius * 110
		self.ringTarget.Size = UDim2.fromOffset(targetSize, targetSize)
		self.ringTarget.Position = UDim2.new(0.5, -targetSize / 2, 0.5, -targetSize / 2)
		self.ringMoving.BackgroundTransparency = 1 - (state.indicatorOpacity or 1) * 0.65
	elseif challenge.Type == "Mash" then
		self.qteBig.Text = string.format("%d / %d", state.count, state.goal)
	elseif challenge.Type == "Directional" then
		local arrows = { Up = "↑", Right = "→", Down = "↓", Left = "←" }
		local parts: { string } = {}
		for index, direction in state.expectedDirections do
			local hidden = false
			for _, hiddenIndex in state.hiddenCommandIndexes do
				if hiddenIndex == index then
					hidden = true
					break
				end
			end
			local glyph = if index <= state.sequenceIndex then "·" elseif hidden then "?" else arrows[direction]
			table.insert(parts, glyph)
		end
		self.qteBig.Text = table.concat(parts, " ")
	end

	if elapsed >= challenge.DurationMs then
		self:_resolveQte(elapsed)
	end
end

function Battle3DController:_qteInput(input: string)
	local challenge = self.qte
	if not challenge or not QteDefinitions.IsValidInput(challenge.Type, input) then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000

	if challenge.Type == "Mash" then
		challenge.InputCount += 1
		return
	end

	if challenge.Type == "Directional" then
		local expected = challenge.ExpectedDirections or {}
		local nextIndex = (challenge.SequenceIndex or 0) + 1
		if expected[nextIndex] ~= input then
			challenge.Mistakes = (challenge.Mistakes or 0) + 1
		end
		challenge.SequenceIndex = nextIndex
		if nextIndex >= #expected then
			self:_resolveQte(elapsed)
		end
		return
	end

	self:_resolveQte(elapsed)
end

function Battle3DController:_resolveQte(elapsed: number)
	local challenge = self.qte
	if not challenge then
		return
	end

	local grade = QteDefinitions.Judge(challenge, elapsed)
	local multiplier = QteDefinitions.Multiplier(challenge.Role, grade)
	local gradeText = ({ Success = "성공", Partial = "보통/방어", Fail = "실패" })[grade]

	if challenge.Role == "Skill" then
		local skill = SKILLS[self.selectedSkill]
		--[[
			아군 공격도 적과 완전히 같은 함수(_castAttackRay)로 판정한다
			(요청: "플레이어랑 적이랑 거의 같은 로직을 쓴다고 생각해줘"). "레이저 표시 없애줘"
			요청으로 스킬 선택 중 계속 보이던 지속 조준 빔은 없앴다 — 맞았을 때만 잠깐
			1회성 섬광을 띄운다.
		]]
		local hit, hitPos, origin = self:_castAttackRay("Ally", self.playerCell.Y, skill)
		if hit and hitPos and origin then
			self:_showAttackRay(origin, hitPos, ALLY_HIT_FLASH)
		end
		local damage = math.floor(skill.Damage * multiplier)
		self.status.Text = string.format(
			"[스킬] %s → %s ×%.1f = %d, %s",
			skill.Name,
			gradeText,
			multiplier,
			damage,
			if hit then "명중" else "빗나감"
		)
		self:_flashEnemy(hit)
		self:_endQte()

		--[[
			적도 같은 규칙으로 반격한다. 같은 `_castAttackRay`를 attackerSide만
			"Enemy"로 바꿔 쓴다 — 적이 고른 랜덤 스킬의 범위(Shape)만큼
			아군 쪽으로 실제 레이를 쏴서, 플레이어 캐릭터에 물리적으로 닿는지 본다.
			(요청: "적의 공격 위치도 레이캐스트로 쭉 가다가 플레이어한테 닿았을 때
			 거기서부터 공격 위치를 정하도록")
		]]
		task.delay(0.5, function()
			if not self.active then
				return
			end
			local enemyLane = self.enemyCell.Y
			local playerHit, hitPosition, eOrigin = self:_castAttackRay("Enemy", enemyLane, self.enemySkill)
			self.lastEnemyHitPosition = hitPosition
			if playerHit and hitPosition and eOrigin then
				self:_showAttackRay(eOrigin, hitPosition, ENEMY_HIT_FLASH)
			end

			if playerHit then
				self:_startQte("Dodge") -- 레이가 실제로 닿았다 → 회피/패리 QTE
			else
				self.status.Text = string.format(
					"적이 %s(으)로 공격했지만 사정 밖이라 빗나갔다. (라인 %d, 사정 %s)",
					self.enemySkill.Name,
					enemyLane,
					skillRangeText(self.enemySkill)
				)
				-- 반격이 빗나가도 한 공방은 끝난 것이므로 적이 다음 위치로 옮긴다.
				self:_endTurn()
			end
		end)
		return
	end

	local taken = math.floor(self.enemySkill.Damage * multiplier)
	local groggyGain = QteDefinitions.GroggyGain(challenge, grade)
	local stunned = false
	if groggyGain > 0 then
		stunned = GroggyGauge.Add(self.enemyGroggy, groggyGain)
	end

	self.status.Text = string.format(
		"[피격] %s ×%.1f = %d 받음%s%s",
		gradeText,
		multiplier,
		taken,
		if groggyGain > 0 then string.format(" / 적 그로기 +%d", groggyGain) else "",
		if stunned then "  ★ 스턴!" else ""
	)

	if GroggyGauge.IsStunned(self.enemyGroggy) then
		GroggyGauge.TickTurn(self.enemyGroggy)
	end

	self:_endQte()
	-- 회피/패리 판정까지 끝나면 한 공방이 완전히 마무리된 것 → 적이 다음 위치로 옮긴다.
	self:_endTurn()
end

--[[
	skill.Shape가 펼치는 칸들을 라인(Y)별로 (최소 X ~ 최대 X) 구간으로 묶어,
	각 라인마다 그 구간을 잇는 레이 하나씩을 만든다.

	요청: "적의 공격 위치도 레이캐스트로 쭉 가다가 플레이어한테 닿았을 때
	       거기서부터 공격 위치를 정하도록. 플레이어랑 적이랑 거의 같은 로직을
	       쓴다고 생각해줘." → attackerSide만 바꾸면 아군·적이 같은 계산을 쓴다.

	레이는 라인당 직선 하나뿐이라, 십자·사각처럼 옆 라인까지 퍼지는 모양은
	라인별 구간으로 근사한다(그 라인에서 모양이 닿는 가장 앞~뒤 칸을 잇는다).
	_skillCells와 완전히 같은 칸 목록에서 뽑으므로 미리보기와 실제 판정이
	어긋나지 않는다.
]]
function Battle3DController:_shapeRaySegments(
	attackerSide: BattleGrid.Side,
	lane: number,
	skill
): { { Lane: number, From: Vector3, To: Vector3 } }
	if not self.layout then
		return {}
	end
	local targetSide = BattleGrid.Opposing(attackerSide)

	local byLane: { [number]: { MinX: number, MaxX: number } } = {}
	for _, cell in self:_skillCells(attackerSide, lane, skill) do
		local group = byLane[cell.Y]
		if not group then
			byLane[cell.Y] = { MinX = cell.X, MaxX = cell.X }
		else
			group.MinX = math.min(group.MinX, cell.X)
			group.MaxX = math.max(group.MaxX, cell.X)
		end
	end

	local segments = {}
	for laneY, range in byLane do
		local fromOffset =
			BattleArena.CellOffset(self.layout, targetSide, range.MinX - 0.5, laneY, self.grid.Width, self.grid.Height)
		local toOffset =
			BattleArena.CellOffset(self.layout, targetSide, range.MaxX + 0.5, laneY, self.grid.Width, self.grid.Height)
		local fromPos = (self.layout.Origin * CFrame.new(fromOffset)).Position + Vector3.new(0, 3, 0)
		local toPos = (self.layout.Origin * CFrame.new(toOffset)).Position + Vector3.new(0, 3, 0)
		table.insert(segments, { Lane = laneY, From = fromPos, To = toPos })
	end
	return segments
end

--[[
	공격 판정 — 아군과 적이 완전히 같은 함수를 쓴다(attackerSide로만 갈린다).

	요청: "적의 공격 위치도 레이캐스트로 쭉 가다가 플레이어한테 닿았을 때
	       거기서부터 공격 위치를 정하도록. 플레이어랑 적이랑 거의 같은 로직을 쓴다고 생각해줘."

	Ally가 쏘면 적 모델에, Enemy가 쏘면 플레이어 캐릭터에 닿는지를 물리적으로
	확인한다. 모양이 여러 라인에 걸치면(십자·사각) 라인마다 따로 쏜다.
	**순수 함수라 이 자체로는 아무것도 그리지 않는다** — 명중 순간의 1회성
	섬광(_showAttackRay)이 이 결과를 그린다.

	반환: 맞았는지, 맞았다면 그 지점(공격 위치)과 맞은 레이의 시작점(연출용).
]]
function Battle3DController:_castAttackRay(
	attackerSide: BattleGrid.Side,
	centerLane: number,
	skill
): (boolean, Vector3?, Vector3?)
	local targetInstance = if attackerSide == "Enemy" then self.player.Character else self.enemyModel
	if not targetInstance then
		return false, nil, nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { targetInstance }

	for _, segment in self:_shapeRaySegments(attackerSide, centerLane, skill) do
		local hit = workspace:Raycast(segment.From, segment.To - segment.From, params)
		if hit then
			return true, hit.Position, segment.From
		end
	end
	return false, nil, nil
end

--[[
	1회성 섬광 — 실제로 판정이 난 순간(QTE 결과가 나왔을 때)에만 잠깐 번쩍인다.
	"쭉 가다가 닿는" 과정을 눈으로 보여준다. 색을 진영별로 다르게 준다.
]]
function Battle3DController:_showAttackRay(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local mid = (from + to) / 2
	local beam = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(0.22, 0.22, length),
		CFrame = CFrame.new(mid, to),
		Color = color or Color3.fromRGB(255, 90, 60),
		Material = Enum.Material.Neon,
	}, workspace)
	TweenService:Create(beam, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	task.delay(0.3, function()
		beam:Destroy()
	end)
end

function Battle3DController:_flashEnemy(hit: boolean)
	local model = self.enemyModel
	local torso = model and model.PrimaryPart
	if not torso then
		return
	end
	local original = torso.Color
	torso.Color = if hit then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(90, 90, 90)
	TweenService:Create(torso, TweenInfo.new(0.35), { Color = original }):Play()
end

function Battle3DController:_endQte()
	if self.qteConn then
		self.qteConn:Disconnect()
		self.qteConn = nil
	end
	self.qte = nil
	if self.qteFrame then
		self.qteFrame.Visible = false
	end
end

function Battle3DController:_bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		-- QTE 중이면 QTE 입력으로 간다
		if self.qte then
			local challenge = self.qte
			local map: { [Enum.KeyCode]: string } = {
				[Enum.KeyCode.Space] = if challenge.Type == "Mash" then "Mash" else "Tap",
				[Enum.KeyCode.Up] = "Up",
				[Enum.KeyCode.W] = "Up",
				[Enum.KeyCode.Right] = "Right",
				[Enum.KeyCode.D] = "Right",
				[Enum.KeyCode.Down] = "Down",
				[Enum.KeyCode.S] = "Down",
				[Enum.KeyCode.Left] = "Left",
				[Enum.KeyCode.A] = "Left",
			}
			local mapped = map[input.KeyCode]
			if mapped then
				self:_qteInput(mapped)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:_qteInput(if challenge.Type == "Mash" then "Mash" else "Tap")
			end
			return
		end

		-- 전투 중 좌클릭 = 캐릭터 집기 (사양: 마우스로 잡았다가 놓는 방식)
		if self.active and input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_beginDrag()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.dragging then
			self:_endDrag()
		end
	end)
end

return Battle3DController
