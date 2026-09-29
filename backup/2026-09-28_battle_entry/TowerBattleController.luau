--!strict
--[[
	TowerBattleController — 서버가 판정한 탑 전투를 **그리고, 입력만 보내는** 클라이언트.

	사양 출처: 추가&수정.md `#### 전투 시스템`, `#### 탑 시스템`

	`Battle3DController`는 클라이언트가 자체 판정하던 시험판이고, 적을 딱 1기만
	가정한다(단일 가정이 12곳에 퍼져 있다). 층에는 2~3기가 나오므로 그것을 뜯어고치는
	대신, **서버 스냅샷을 그대로 그리는** 컨트롤러를 따로 세웠다. 시험판은 회귀 위험
	없이 그 자리에 남는다.

	권위 경계
	  서버 → GridState  {Floor, Turn, Outcome, Units{X,Y,Health,Groggy,...}, Threats}
	         TowerState {Floor, Cost, NextRerollCost, RemainingPicks, Cards}
	  클라 → GridAction  {Kind="Move"|"Skill"|"Dodge", ...}
	         TowerAction {Kind="Enter"|"Exit"|"Reroll"|"Acquire", ...}

	즉 여기에는 체력·피해·적 위치를 **정하는** 코드가 없다. 오직 QTE 등급만 만든다 —
	입력 타이밍이 클라이언트에만 있기 때문이고, 그 경계는 `TowerService` 주석에 적혀 있다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- 직업 카드 호버 연출. 짧게 끊어야 목록을 훑을 때 끈적이지 않는다.
local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)
local TowerArena = require(ReplicatedStorage.Shared.TowerArena)
-- 전투 연출(모션·무기·이펙트·슬라임). 판정은 하지 않고 서버 결과를 그린다.
local CombatDirector = require(script.Parent.Combat.CombatDirector)

--[[
	등급별 색. **파일 맨 위에 둔다.**

	`local`은 선언보다 위에 있는 함수에서 보이지 않는다(이 프로젝트에서 이미 두 번
	같은 함정에 빠졌다). 카드 목록과 보상 카드 양쪽이 쓰므로 위로 올려 둔다.
]]
--[[
	보상 카드 한 장의 최대 폭.

	폭은 화면 비율(1/장수)이고 높이는 420 고정이라, 화면이 넓을수록 **폭만** 자란다.
	2560 폭에서는 한 장이 364×420이 되어 거의 정사각형으로 보였다(요청: "카드가 조금
	뚱뚱해"). 좁은 화면에서는 지금처럼 비례로 줄어들어야 하므로 공식은 그대로 두고
	상한만 건다. 420 × 0.7 — 실제 카드가 대략 이 비율이다.
]]
local REWARD_CARD_MAX_WIDTH = 294

local GRADE_STYLE = {
	Essential = { Name = "필수", Fill = Color3.fromRGB(150, 70, 40), Edge = Color3.fromRGB(255, 150, 90) },
	Rare = { Name = "희귀", Fill = Color3.fromRGB(38, 66, 122), Edge = Color3.fromRGB(120, 175, 255) },
	Common = { Name = "일반", Fill = Color3.fromRGB(48, 48, 56), Edge = Color3.fromRGB(150, 150, 165) },
}

local TowerBattleController = {}
TowerBattleController.__index = TowerBattleController

local GRID_WIDTH = BattleGrid.DEFAULT_WIDTH
local GRID_HEIGHT = BattleGrid.DEFAULT_HEIGHT

local TILE_IDLE = Color3.fromRGB(70, 76, 92)
local TILE_ME = Color3.fromRGB(70, 130, 220)
local TILE_RANGE = Color3.fromRGB(190, 55, 60)
local TILE_THREAT = Color3.fromRGB(220, 150, 60)
local TILE_DROP = Color3.fromRGB(90, 190, 120)

local FLOAT_HEIGHT = 3.4
local CAMERA_PITCH = 45

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

--[[
	`plazaUi`는 광장 UI를 든 `BattleController`다.

	등반을 시작하면 광장 버튼 세 개(원정대 편성 · 모션 제작 · 모션 인벤토리)를
	감춰야 하는데, 그 버튼들은 저쪽이 소유하고 있다. 여기서 직접 `.Visible`을
	건드리면 저쪽이 다음 상태 갱신에서 도로 켜 버리므로 소유자에게 알린다.
]]
function TowerBattleController.new(remotes: Folder, plazaUi: any?)
	local self = setmetatable({}, TowerBattleController)
	self.Remotes = remotes
	self.plazaUi = plazaUi
	self.player = Players.LocalPlayer
	self.active = false
	self.snapshot = nil :: any
	self.tower = nil :: any
	self.selectedSkill = 1
	self.qte = nil :: any
	self.dragging = false
	self.dragHover = nil :: any
	-- 전투 연출. 전투 중에만 있다(_setupBattle / _teardownBattle).
	self.director = nil :: any
	-- 이미 그린 서버 사건 번호(GridBattle Events.Seq)
	self.lastEventSeq = 0
	-- 서버 결과를 기다리는 연출(스킬 / 적 공격). 결과가 오면 피해 숫자를 붙인다.
	self.pendingSkillPlay = nil :: any
	self.pendingAttackPlay = nil :: any
	-- 적 공격 예고가 왔지만 아직 회피 QTE 를 안 띄웠다(앞 연출이 끝나길 기다림)
	self.threatWaiting = false
	-- 서버가 배정한 등반실의 중심. 격자를 여기에 깐다.
	self.arenaOrigin = nil :: Vector3?
	-- 광장의 등반문. 이 앞에서만 등반 시작 버튼이 보인다.
	self.gate = nil :: Instance?

	self:_buildUi()

	remotes.GridState.OnClientEvent:Connect(function(snapshot)
		self:_onGridState(snapshot)
	end)
	remotes.TowerState.OnClientEvent:Connect(function(state)
		self:_onTowerState(state)
	end)

	self.player.CharacterAdded:Connect(function()
		if self.active then
			task.wait(0.4)
			self:_renderUnits()
		end
	end)

	return self
end

--=== UI ===--

function TowerBattleController:_buildUi()
	local gui = make("ScreenGui", {
		Name = "TowerBattleGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.player:WaitForChild("PlayerGui"))
	self.Gui = gui

	--[[
		탑 입장/이탈.

		처음엔 (12, 12)에 뒀는데 그 자리는 **Roblox 자체 상단바**(메뉴·채팅·음성 아이콘)가
		차지한다. 버튼이 그 아래 깔려 클릭이 아예 안 됐다. 상단바를 피해 내려 놓는다.
	]]
	self.enterButton = make("TextButton", {
		Name = "TowerEnter",
		Size = UDim2.fromOffset(132, 34),
		Position = UDim2.fromOffset(12, 100),
		BackgroundColor3 = Color3.fromRGB(120, 60, 160),
		BorderSizePixel = 0,
		Text = "탑 등반 시작",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, gui)
	-- 바로 입장하지 않는다. 서버가 직업 선택 화면을 열어 준다(요청).
	self.enterButton.Activated:Connect(function()
		self.Remotes.TowerAction:FireServer({ Kind = "PickClass" })
	end)

	--[[
		등반문 앞에서만 이 버튼을 보여 준다 (요청: "등반 장소로 가서 등반").

		서버도 같은 거리를 재고 거절하므로 이건 **연출**이다. 버튼이 늘 떠 있으면
		눌렀다가 거절 메시지만 보게 되니, 아예 문 앞에서만 나타나게 한다.
		문은 서버가 만든 파트라 클라이언트가 찾아 쓸 수 있다.
	]]
	task.spawn(function()
		local plaza = workspace:WaitForChild("PorcelainPlaza", 30)
		self.gate = plaza and plaza:FindFirstChild("TowerGate")
		self:_refreshEnterButton()
	end)
	task.spawn(function()
		while self.Gui.Parent do
			self:_refreshEnterButton()
			task.wait(0.4)
		end
	end)

	self.exitButton = make("TextButton", {
		Name = "TowerExit",
		Size = UDim2.fromOffset(132, 28),
		Position = UDim2.fromOffset(12, 138),
		BackgroundColor3 = Color3.fromRGB(150, 50, 50),
		BorderSizePixel = 0,
		Text = "등반 포기",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Visible = false,
	}, gui)
	self.exitButton.Activated:Connect(function()
		self.Remotes.TowerAction:FireServer({ Kind = "Exit" })
	end)

	--[[
		[개발 전용] OP 결투사로 즉시 등반. 전투를 끝까지 굴려 보기 위한 버튼이다.

		Studio에서만 만든다. 서버도 `RunService:IsStudio()`로 한 번 더 막으므로,
		이 버튼이 없는 클라이언트가 리모트를 직접 쏴도 통하지 않는다.
	]]
	if RunService:IsStudio() then
		local dev = make("TextButton", {
			Name = "TowerDevEnter",
			Size = UDim2.fromOffset(132, 26),
			Position = UDim2.fromOffset(12, 172),
			BackgroundColor3 = Color3.fromRGB(40, 130, 90),
			BorderSizePixel = 0,
			Text = "[개발] OP 결투사",
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
		}, gui)
		dev.Activated:Connect(function()
			self.Remotes.TowerAction:FireServer({ Kind = "DevEnter" })
		end)
	end

	-- 상태 줄
	self.status = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.new(0, 12, 1, -30),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(228, 228, 232),
		Font = Enum.Font.RobotoMono,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
	}, gui)

	-- 상태이상·자원 줄. 스킬 바 바로 위에 얇게 깐다.
	self.statusLine = make("TextLabel", {
		Name = "StatusLine",
		Size = UDim2.fromOffset(720, 22),
		Position = UDim2.new(0.5, -360, 1, -132),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(228, 228, 232),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		RichText = true,
		Visible = false,
	}, gui)

	-- 스킬 줄. 강화가 열리면 버튼이 최대 6개(직업 3 + 강화 1 + 가드·명상 2)가 된다.
	self.skillBar = make("Frame", {
		Size = UDim2.fromOffset(720, 34),
		Position = UDim2.new(0.5, -360, 1, -70),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	--[[
		스킬 버튼은 **스냅샷이 오면** 만든다.

		예전에는 여기서 `BattleSkills.All()`로 미리 찍어 뒀는데, 그 목록은 직업과
		무관한 공용 5개라 어떤 직업을 골라도 스킬 바가 똑같았다. 이제 어떤 스킬을
		쓸 수 있는지는 서버가 스냅샷(`AllySkills`)으로 알려 준다.
	]]
	self.skillButtons = {}

	--[[
		스킬 설명 말풍선. 스킬 바 **위쪽**에 뜬다.

		버튼 안에 욱여넣을 수 없다 — 여섯 개가 720px을 나눠 쓰므로 한 칸이 120px
		남짓이고, 이름과 근/원거리만으로도 이미 두 줄이다.
	]]
	self.skillTip = make("TextLabel", {
		Size = UDim2.fromOffset(720, 42),
		Position = UDim2.new(0.5, -360, 1, -116),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(210, 210, 220),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		RichText = true,
		Visible = false,
		ZIndex = 6,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.skillTip)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 5),
	}, self.skillTip)

	self.attackButton = make("TextButton", {
		Size = UDim2.fromOffset(160, 30),
		Position = UDim2.new(0.5, -80, 1, -104),
		BackgroundColor3 = Color3.fromRGB(190, 55, 60),
		BorderSizePixel = 0,
		Text = "이 스킬로 공격",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Visible = false,
	}, gui)
	self.attackButton.Activated:Connect(function()
		-- 재사용 대기 중인 스킬은 서버까지 보내지 않고 여기서 막는다(요청한 쿨타임 기능의 짝).
		local chosen = self:_selectedSkill()
		if chosen and (chosen.CooldownLeft or 0) > 0 then
			return
		end
		-- 앞 연출이 끝나기 전에는 다음 스킬을 못 쓴다(연출과 판정이 어긋나지 않게)
		if self.director and self.director:IsBusy() then
			return
		end
		self:_startQte("Skill")
	end)

	-- QTE 판정 바. 사양의 화려한 연출은 시험판에 있고, 여기서는 판정에 필요한 최소만 둔다.
	self.qtePanel = make("Frame", {
		-- 화살표 줄이 들어갈 만큼 세로를 늘렸다(스트라타젬은 방향키 순서를 보여 준다).
		Size = UDim2.fromOffset(420, 96),
		Position = UDim2.new(0.5, -210, 0.5, -48),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	self.qteTitle = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(232, 179, 57),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, self.qtePanel)
	self.qteTrack = make("Frame", {
		Size = UDim2.new(1, -24, 0, 12),
		Position = UDim2.fromOffset(12, 30),
		BackgroundColor3 = Color3.fromRGB(45, 45, 50),
		BorderSizePixel = 0,
	}, self.qtePanel)
	self.qteZone = make("Frame", {
		Size = UDim2.fromScale(0.2, 1),
		BackgroundColor3 = Color3.fromRGB(78, 201, 160),
		BorderSizePixel = 0,
	}, self.qteTrack)
	self.qteCursor = make("Frame", {
		Size = UDim2.new(0, 3, 1, 6),
		Position = UDim2.fromOffset(0, -3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, self.qteTrack)

	-- 스트라타젬 화살표 줄. Directional일 때만 보인다.
	self.qteArrows = make("Frame", {
		Name = "Arrows",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 48),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.qtePanel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, self.qteArrows)
	self.qteArrowLabels = {}
	-- 명령 수만큼 미리 만들어 두고 보이기만 토글한다(매 프레임 생성하지 않는다).
	for index = 1, QteDefinitions.COMMAND_COUNT do
		self.qteArrowLabels[index] = make("TextLabel", {
			Size = UDim2.fromOffset(34, 38),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = 22,
			LayoutOrder = index,
			Visible = false,
		}, self.qteArrows)
	end

	--[[
		보상 화면.

		요청: "카드가 화면 가운데에 총 6개의 카드로", "카드 크기는 다 똑같고, 화면에
		       잘리지 않게", "카드의 중앙을 긋는 가로선", "상단엔 그림, 하단엔 설명".

		예전엔 세로 목록이라 한 장이 가로로 길쭉하고 스크롤해야 보였다. 이제 화면 전체를
		덮는 판 위에 **가로 한 줄로 6장**을 같은 크기로 놓는다. 폭은 화면 비율에서
		계산하므로(고정 픽셀이 아니라) 창이 좁아도 잘리지 않는다.
	]]
	self.rewardPanel = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	--[[
		왼쪽 260px는 보유 카드·스탯 패널 자리로 비워 둡니다.

		보상 화면을 화면 전체로 깔았더니 **왼쪽 카드가 그 패널에 가려졌습니다.**
		패널을 감추는 대신(등반 중 항상 보여야 하므로) 보상 쪽을 그만큼 비켜 놓습니다.
	]]
	local REWARD_LEFT = 260

	self.rewardTitle = make("TextLabel", {
		Size = UDim2.new(1, -(REWARD_LEFT + 40), 0, 30),
		Position = UDim2.fromOffset(REWARD_LEFT, 40),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(232, 179, 57),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}, self.rewardPanel)

	-- 카드가 가로로 놓이는 자리. 가운데 정렬이라 장수가 적어도 치우치지 않습니다.
	self.rewardRow = make("Frame", {
		Name = "CardRow",
		-- 6장으로 줄이면서 높이도 340 → 420으로 키웠습니다. 설명이 답답하지 않게.
		Size = UDim2.new(1, -(REWARD_LEFT + 40), 0, 420),
		Position = UDim2.new(0, REWARD_LEFT, 0.5, -210),
		BackgroundTransparency = 1,
	}, self.rewardPanel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.rewardRow)

	self.rerollButton = make("TextButton", {
		Size = UDim2.fromOffset(220, 36),
		-- 화면 정중앙이 아니라 **카드 줄 기준** 가운데에 맞춥니다.
		Position = UDim2.new(0.5, -110 + REWARD_LEFT / 2, 1, -76),
		BackgroundColor3 = Color3.fromRGB(0, 122, 204),
		BorderSizePixel = 0,
		Text = "다시 뽑기",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, self.rewardPanel)
	self.rerollButton.Activated:Connect(function()
		self.Remotes.TowerAction:FireServer({ Kind = "Reroll" })
	end)

	--[[
		카드를 클릭해도 바로 획득되지 않고 **선택만** 된다(요청). 실제 획득은
		이 버튼을 눌러야 나간다 — 잘못 눌러 카드를 날리는 일을 막는다.
	]]
	self.rewardConfirm = make("TextButton", {
		Size = UDim2.fromOffset(240, 40),
		Position = UDim2.new(0.5, -120 + REWARD_LEFT / 2, 1, -124),
		BackgroundColor3 = Color3.fromRGB(40, 150, 90),
		BorderSizePixel = 0,
		Text = "이 카드 선택하기",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Visible = false,
	}, self.rewardPanel)
	self.rewardConfirm.Activated:Connect(function()
		if self.selectedRewardCardId then
			self.Remotes.TowerAction:FireServer({ Kind = "Acquire", CardId = self.selectedRewardCardId })
		end
	end)

	self.rewardCardEntries = {}
	self.selectedRewardCardId = nil

	self:_buildOwnedPanel()
	self:_buildStatPanel()
	self:_buildClassPicker(gui)
	self:_bindInput()
end

--[[
	등반 중 항상 보이는 **내 카드 목록** (요청).

	보상 화면은 고를 때만 뜨지만, 지금 뭘 가지고 있는지는 전투 중에도 봐야 다음 선택을
	정할 수 있다. 화면 왼쪽에 세로로 붙여 두고 등반이 끝나면 감춘다.
]]
function TowerBattleController:_buildOwnedPanel()
	self.ownedPanel = make("Frame", {
		Name = "OwnedCards",
		Size = UDim2.fromOffset(232, 330),
		Position = UDim2.fromOffset(12, 178),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, self.Gui)
	make("UIStroke", { Color = Color3.fromRGB(62, 62, 70), Thickness = 1 }, self.ownedPanel)

	self.ownedTitle = make("TextLabel", {
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 4),
		BackgroundTransparency = 1,
		Text = "보유 카드",
		TextColor3 = Color3.fromRGB(232, 179, 57),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.ownedPanel)

	self.ownedList = make("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -34),
		Position = UDim2.fromOffset(6, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, self.ownedPanel)
	make("UIListLayout", { Padding = UDim.new(0, 3) }, self.ownedList)
end

--[[
	층마다 스탯을 찍는 판 (요청).

	남은 포인트와 현재 수치를 함께 보여 주고, 누르면 서버에 `SpendStat`을 보낸다.
	실제 차감·검증은 서버가 한다.
]]
function TowerBattleController:_buildStatPanel()
	self.statPanel = make("Frame", {
		Name = "StatPoints",
		Size = UDim2.fromOffset(232, 214),
		Position = UDim2.fromOffset(12, 518),
		BackgroundColor3 = Color3.fromRGB(16, 16, 20),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, self.Gui)
	make("UIStroke", { Color = Color3.fromRGB(62, 62, 70), Thickness = 1 }, self.statPanel)

	self.statTitle = make("TextLabel", {
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 4),
		BackgroundTransparency = 1,
		Text = "스탯",
		TextColor3 = Color3.fromRGB(232, 179, 57),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}, self.statPanel)

	self.statRows = {}
	for index, statId in StatDefinitions.Order do
		local definition = StatDefinitions.Get(statId)
		local row = make("TextButton", {
			Name = statId,
			Size = UDim2.new(1, -12, 0, 28),
			Position = UDim2.fromOffset(6, 30 + (index - 1) * 30),
			BackgroundColor3 = Color3.fromRGB(38, 38, 45),
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, self.statPanel)
		make("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			BackgroundTransparency = 1,
			Text = definition and definition.Name or statId,
			TextColor3 = Color3.fromRGB(222, 222, 230),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
		}, row)
		row.Activated:Connect(function()
			self.Remotes.TowerAction:FireServer({ Kind = "SpendStat", StatId = statId })
		end)
		self.statRows[statId] = row
	end
end

--[[
	직업 선택 화면.

	등반문을 누르면 서버가 `PickClass`와 함께 직업 목록을 내려보낸다. 여기서는 그
	목록을 카드로 깔고, 고른 Id를 Enter에 실어 보낸다. **무엇을 고를 수 있는지도
	서버가 정한다** — 클라이언트가 목록을 들고 있으면 없는 직업을 보낼 수 있다.

	연출 (요청)
	  카드는 화면 한가운데 가로 한 줄로 놓인다.
	  하나를 누르면 **그 카드가 중앙으로 움직이며 커지고**, 나머지는 완전히 투명해진다.
	  빈 공간을 누르면 도로 줄로 돌아간다.

	그래서 `UIListLayout`을 쓰지 않는다 — 레이아웃이 Position을 매 프레임 덮어써서
	카드를 움직일 수 없다. 위치를 직접 계산해 가운데 정렬한다.
]]

-- 카드 배경 불투명도(요청: 50%). 뒤가 옅게 비치되 글자는 읽히는 선.
local CARD_TRANSPARENCY = 0.5

local CARD_SMALL = Vector2.new(190, 340)
local CARD_LARGE = Vector2.new(420, 620)
local CARD_GAP = 14

-- 카드가 자리를 옮기는 연출. 조금 튕기게 해야 "고름"이 눈에 들어온다.
local PICK_TWEEN = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function TowerBattleController:_buildClassPicker(gui: ScreenGui)
	self.classPanel = make("Frame", {
		Name = "ClassPicker",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)

	--[[
		빈 공간 클릭으로 선택을 푼다.

		Frame은 Activated를 받지 못하므로 화면 전체를 덮는 **투명 버튼**을 맨 아래에
		깐다. 카드들은 이 위에 있으므로 카드 클릭을 가로채지 않는다.
	]]
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 0,
	}, self.classPanel)
	backdrop.Activated:Connect(function()
		self:_selectClass(nil)
	end)

	make("TextLabel", {
		Size = UDim2.new(1, -80, 0, 40),
		Position = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Text = "등반할 직업을 고르세요",
		TextColor3 = Color3.fromRGB(232, 179, 57),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.classPanel)

	self.classRow = make("Frame", {
		Name = "Row",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, self.classPanel)

	self.classConfirm = make("TextButton", {
		Size = UDim2.fromOffset(240, 44),
		Position = UDim2.new(0.5, -120, 1, -78),
		BackgroundColor3 = Color3.fromRGB(120, 60, 160),
		BorderSizePixel = 0,
		Text = "이 직업으로 등반하기",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Visible = false,
		ZIndex = 3,
	}, self.classPanel)
	self.classConfirm.Activated:Connect(function()
		if self.pickedClassId then
			self.Remotes.TowerAction:FireServer({ Kind = "Enter", ClassId = self.pickedClassId })
		end
	end)

	local cancel = make("TextButton", {
		Size = UDim2.fromOffset(120, 34),
		Position = UDim2.new(0.5, 150, 1, -73),
		BackgroundColor3 = Color3.fromRGB(70, 70, 82),
		BorderSizePixel = 0,
		Text = "취소",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 3,
	}, self.classPanel)
	cancel.Activated:Connect(function()
		self.Remotes.TowerAction:FireServer({ Kind = "CancelPick" })
	end)

	-- 만들어 둔 카드들. 선택이 바뀔 때마다 전부 다시 배치한다.
	self.classCards = {}
	self.pickedClassId = nil
end

--[[
	카드 하나를 고른다. nil이면 선택 해제.

	고른 카드는 가운데로 커지며 오고, 나머지는 완전히 투명해진다(요청). 위치·크기·
	투명도를 전부 여기서 한 번에 정하므로 "지금 어떤 상태인가"가 한 함수 안에 있다.
]]
function TowerBattleController:_selectClass(classId: string?)
	self.pickedClassId = classId
	self.classConfirm.Visible = classId ~= nil

	local cards = self.classCards or {}
	local total = #cards

	for index, entry in cards do
		local isPicked = entry.ClassId == classId
		local size = if isPicked then CARD_LARGE else CARD_SMALL

		--[[
			가운데 정렬. 카드는 AnchorPoint(0.5, 0.5)라 X 오프셋만 주면 된다.
			고른 카드는 오프셋 0(= 화면 정중앙)으로 온다.
		]]
		local offsetX = (index - (total + 1) / 2) * (CARD_SMALL.X + CARD_GAP)
		local goalPosition = if isPicked then UDim2.fromScale(0.5, 0.46) else UDim2.new(0.5, offsetX, 0.5, 0)

		TweenService:Create(entry.Button, PICK_TWEEN, {
			Position = goalPosition,
			Size = UDim2.fromOffset(size.X, size.Y),
		}):Play()

		--[[
			고르지 않은 카드는 **완전히** 투명해진다(요청). `CanvasGroup`의
			GroupTransparency를 쓰면 자식(테두리·글자·색 띠)이 한 번에 같이
			사라진다 — 라벨마다 따로 TextTransparency를 흔들 필요가 없다.
		]]
		local faded = classId ~= nil and not isPicked
		TweenService:Create(entry.Body, PICK_TWEEN, { GroupTransparency = if faded then 1 else 0 }):Play()

		-- 고른 카드가 나머지 위로 오게 한다.
		entry.Button.ZIndex = if isPicked then 2 else 1
		--[[
			투명해진 카드도 **클릭은 계속 받는다.**

			한 번은 Active를 꺼 봤는데, 그러면 카드가 있던 자리를 다시 눌러 다른
			직업으로 바로 바꾸는 게 안 됐다("기존에 있던 버튼들의 위치엔 클릭이
			안 돼"). 자리는 고정돼 있으니 그 자리를 누르면 그 직업으로 바로
			바뀌는 편이 자연스럽다.
		]]
		-- 설명은 카드가 클 때만 읽을 만하다.
		entry.Description.Visible = isPicked
	end
end

function TowerBattleController:_refreshClassPicker(state: any)
	local classes = state and state.Classes or {}
	self.classPanel.Visible = state ~= nil and state.PickClass == true and #classes > 0
	if not self.classPanel.Visible then
		return
	end

	for _, child in self.classRow:GetChildren() do
		child:Destroy()
	end
	self.classCards = {}

	for order, class in classes do
		local accent = class.Color or Color3.fromRGB(150, 150, 165)

		--[[
			카드는 **버튼 + CanvasGroup** 두 겹이다.

			CanvasGroup은 클릭을 받지 못하고, TextButton은 GroupTransparency가 없다.
			그래서 바깥을 투명한 버튼(위치·크기 애니메이션용)으로 두고, 보이는 것은
			전부 안쪽 CanvasGroup(투명도 애니메이션용)에 넣는다.
		]]
		local button = make("TextButton", {
			Name = "Class" .. class.Id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(CARD_SMALL.X, CARD_SMALL.Y),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
		}, self.classRow)

		local body = make("CanvasGroup", {
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(22, 22, 27),
			BackgroundTransparency = CARD_TRANSPARENCY,
			BorderSizePixel = 0,
		}, button)

		--[[
			마우스를 올리면 카드가 살짝 커진다(요청).

			`button`의 Size는 선택 애니메이션(작은 카드 ↔ 큰 카드)이 이미 쓰고 있어서,
			거기에 또 손대면 두 트윈이 서로 덮어쓴다. **UIScale을 안쪽 body에** 걸어
			선택 여부와 무관하게 따로 확대할 수 있게 했다.
		]]
		local hoverScale = make("UIScale", { Scale = 1 }, body)

		local glow = make("Frame", {
			Name = "Glow",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, body)

		-- 위쪽 색 띠. 모든 카드가 같은 두께를 쓴다(현재 직업만 두껍던 것이 어색해 뺐다).
		make("Frame", {
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, body)
		make("TextLabel", {
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 18),
			BackgroundTransparency = 1,
			Text = class.Name,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 20,
		}, body)
		make("TextLabel", {
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.fromOffset(8, 52),
			BackgroundTransparency = 1,
			Text = string.format("%s\n체력 %d", class.Role, class.MaxHealth),
			TextColor3 = accent,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextWrapped = true,
		}, body)
		local description = make("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, -32, 1, -140),
			Position = UDim2.fromOffset(16, 110),
			BackgroundTransparency = 1,
			Text = class.Description,
			TextColor3 = Color3.fromRGB(216, 216, 226),
			Font = Enum.Font.Gotham,
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Visible = false,
		}, body)

		-- 마우스를 올리면 밝아지면서 살짝 커진다. 고른 카드가 있을 때는 조용히 둔다.
		button.MouseEnter:Connect(function()
			if self.pickedClassId ~= nil then
				return
			end
			TweenService:Create(glow, HOVER_TWEEN, { BackgroundTransparency = 0.82 }):Play()
			TweenService:Create(hoverScale, HOVER_TWEEN, { Scale = 1.06 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(glow, HOVER_TWEEN, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(hoverScale, HOVER_TWEEN, { Scale = 1 }):Play()
		end)

		button.Activated:Connect(function()
			self:_selectClass(class.Id)
		end)

		table.insert(self.classCards, {
			ClassId = class.Id,
			Button = button,
			Body = body,
			Description = description,
		})
	end

	-- 처음엔 아무것도 고르지 않은 상태. 이 호출이 카드들을 제자리에 놓는다.
	self:_selectClass(nil)
end

--[[
	등반 시작 버튼을 보일지 정한다.

	등반 중이면 숨기고, 아니면 등반문에서 GATE_UI_RANGE 안일 때만 보인다.
	서버는 24스터드까지 허용하므로 조금 좁게 잡아, 보이는데 거절당하는 일이 없게 한다.
]]
local GATE_UI_RANGE = 18

function TowerBattleController:_refreshEnterButton()
	local active = self.tower ~= nil and self.tower.Active == true
	if active then
		self.enterButton.Visible = false
		return
	end
	local gate = self.gate
	if not gate or not gate:IsA("BasePart") then
		-- 문을 아직 못 찾았으면 막지 않는다. 서버가 어차피 거리를 다시 잰다.
		self.enterButton.Visible = true
		return
	end
	local root = self:_root()
	self.enterButton.Visible = root ~= nil and (root.Position - gate.Position).Magnitude <= GATE_UI_RANGE
end

--=== 서버 상태 수신 ===--

function TowerBattleController:_onTowerState(state: any)
	self.tower = state
	local active = state ~= nil and state.Active == true
	self.exitButton.Visible = active
	self:_refreshEnterButton()
	self:_refreshClassPicker(state)

	--[[
		등반실 좌표가 뒤늦게 도착했으면 격자를 그 자리로 다시 깐다.

		GridState가 TowerState보다 먼저 올 수 있어(둘은 따로 쏜다) 그때는 1번 방을
		임시로 쓴다. 여기서 바로잡지 않으면 남의 방에 격자를 그린 채로 싸우게 된다.
	]]
	local arena = state and state.Arena
	if active and arena and self.active and self.arenaOrigin then
		local target = Vector3.new(arena.X, arena.Y, arena.Z)
		if (target - self.arenaOrigin).Magnitude > 1 then
			self:_teardownBattle()
			if self.snapshot then
				self:_setupBattle()
				self:_renderUnits()
				self:_paintTiles()
			end
		end
	end
	-- 보유 카드와 스탯은 등반 중 **항상** 보인다(요청).
	self.ownedPanel.Visible = active
	self.statPanel.Visible = active
	-- 반대로 광장 버튼 세 개는 등반 중 감춘다(요청).
	if self.plazaUi then
		self.plazaUi:SetTowerActive(active)
	end
	if active then
		self:_refreshOwned(state)
		self:_refreshStats(state)
	end

	if state and state.Message then
		self.status.Visible = true
		self.status.Text = state.Message
	end

	-- 카드가 걸려 있으면 보상 화면, 아니면 닫는다.
	local cards = state and state.Cards or {}
	self.rewardPanel.Visible = #cards > 0
	if #cards == 0 then
		return
	end

	local function accent(value: any): string
		return string.format('<font color="rgb(255,205,90)"><b>%s</b></font>', tostring(value))
	end
	self.rewardTitle.Text = string.format(
		"%s층 보상 — 코스트 %s · 남은 획득 %s장 · 다시 뽑기 %s",
		accent(state.Floor),
		accent(state.Cost),
		accent(state.RemainingPicks),
		accent(state.NextRerollCost)
	)
	-- 코스트가 모자라면 눌러도 서버가 거절하므로 미리 표시로 알린다.
	local affordable = state.Cost >= state.NextRerollCost
	self.rerollButton.Text = string.format("다시 뽑기 (%d 코스트)", state.NextRerollCost)
	self.rerollButton.BackgroundColor3 = if affordable then Color3.fromRGB(0, 122, 204) else Color3.fromRGB(60, 60, 68)

	--[[
		제시된 카드 구성이 실제로 바뀌었을 때만 선택을 지운다.

		이 함수는 스탯 포인트를 찍는 등 카드와 무관한 이유로도 자주 다시 불린다.
		매번 선택을 지우면 카드를 골라 두고 확인 버튼을 누르기 전에 다른 걸 건드리는
		순간 선택이 날아간다. 카드 구성 자체가 바뀔 때(리롤·획득)만 초기화한다.
	]]
	local ids = {}
	for _, card in cards do
		table.insert(ids, card.Id)
	end
	local signature = table.concat(ids, "/")
	if signature ~= self.rewardSignature then
		self.rewardSignature = signature
		self.selectedRewardCardId = nil
	end
	self.rewardConfirm.Visible = false

	self.rewardCardEntries = {}
	for _, child in self.rewardRow:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for order, card in cards do
		self:_buildCard(card, order, #cards)
	end
end

--[[
	카드 한 장.

	  ┌──────────────┐
	  │   [ 그림 ]    │  상단: 등급 색 배경 + 이름
	  ├──────────────┤  ← 중앙을 긋는 가로선(요청)
	  │   설명 …      │  하단: 정확한 수치가 들어간 설명
	  └──────────────┘

	폭은 **비율로** 잡는다(1/6 - 여백). 고정 픽셀이면 좁은 화면에서 잘린다 —
	요청의 "화면에 잘리지 않게"가 그 뜻이다. 장수가 6장보다 적어도 카드 크기는
	그대로여서(같은 분모) 크기가 들쭉날쭉하지 않다.
]]

--[[
	카드 그림을 그린다.

	`CardArt`가 0~1 좌표의 도형 목록을 주면 여기서 Frame으로 바꾼다. 계산과 그리기를
	나눈 덕에 그림 자체는 Lune 테스트로 검사할 수 있고, 여기는 변환만 맡는다.

	**정사각 캔버스**를 하나 깔고 그 안에 그린다. 그림 자리는 카드보다 가로로 길어서,
	비율을 안 맞추면 원이 타원이 되고 45도로 돌린 마름모가 찌그러진다.
	가로에 맞춘 정사각형이라 위아래가 조금 잘리는데, 문양은 0.14~0.86 범위 안에
	들어오므로 잘리는 것은 배경 띠뿐이다.
]]
function TowerBattleController:_paintArt(parent: Frame, card: any)
	local art = CardArt.For(card)
	parent.BackgroundColor3 = art.Background

	--[[
		**CanvasGroup**이어야 한다. Frame + ClipsDescendants로는 안 잘린다.

		로블록스의 `ClipsDescendants`는 **회전된 자손을 자르지 않는다.** 문양 도형은
		전부 Rotation이 걸려 있어서, 처음엔 배경 띠와 모서리 장식이 카드 밖으로 화면
		끝까지 뻗어 나갔다.

		CanvasGroup은 자손을 자기 크기의 버퍼에 먼저 그린 뒤 그 버퍼를 붙인다. 그리는
		단계에서 이미 잘리므로 회전과 무관하게 경계를 넘지 못한다.
	]]
	local canvas = make("CanvasGroup", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	make("UIAspectRatioConstraint", {
		AspectRatio = 1,
		AspectType = Enum.AspectType.ScaleWithParentSize,
		DominantAxis = Enum.DominantAxis.Width,
	}, canvas)

	-- 테두리 두께는 픽셀 단위라, 캔버스 크기가 바뀌면 같이 바뀌어야 한다.
	local strokes: { { Stroke: UIStroke, Ratio: number } } = {}

	for index, item in art.Shapes do
		local filled = item.Stroke <= 0
		local frame = make("Frame", {
			Name = string.format("S%02d", index),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(item.X, item.Y),
			Size = UDim2.fromScale(item.W, item.H),
			Rotation = item.Rotation,
			BackgroundColor3 = item.Color,
			BackgroundTransparency = if filled then item.Transparency else 1,
			BorderSizePixel = 0,
			ZIndex = item.ZIndex,
		}, canvas)
		if item.Corner > 0 then
			make("UICorner", { CornerRadius = UDim.new(item.Corner, 0) }, frame)
		end
		if not filled then
			local stroke = make("UIStroke", {
				Color = item.Color,
				Thickness = 2,
				Transparency = item.Transparency,
			}, frame)
			table.insert(strokes, { Stroke = stroke, Ratio = item.Stroke })
		end
	end

	if #strokes > 0 then
		local function resize()
			local width = canvas.AbsoluteSize.X
			for _, entry in strokes do
				entry.Stroke.Thickness = math.max(entry.Ratio * width, 1)
			end
		end
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		resize()
	end
end

function TowerBattleController:_buildCard(card: any, order: number, total: number)
	local style = GRADE_STYLE[card.Grade] or GRADE_STYLE.Common

	local button = make("TextButton", {
		Name = "Card" .. order,
		--[[
			폭은 **실제 장수**로 나눈다.

			한 화면의 최대는 희귀 2 + 일반 4 = **6장**이다. 필수 층의 첫 화면은
			필수 3장뿐인데, 그때도 카드 크기가 6장 기준으로 유지되도록 6으로 나눈다 —
			화면마다 카드 크기가 널뛰면 같은 등반 안에서 다른 게임처럼 보인다.

			최소 6으로 잡아 두는 또 다른 이유는 카드가 최대 레벨에 닿아 풀에서 빠지면서
			두세 장만 남는 경우다.
		]]
		Size = UDim2.new(1 / math.max(total, 6), -14, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 22, 27),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	}, self.rewardRow)
	-- 넓은 화면에서 폭만 자라 카드가 뚱뚱해지는 것을 막는다.
	make("UISizeConstraint", { MaxSize = Vector2.new(REWARD_CARD_MAX_WIDTH, math.huge) }, button)
	local stroke = make("UIStroke", { Color = style.Edge, Thickness = 2 }, button)

	--[[
		마우스를 올리면 테두리가 밝아지고 카드 뒤로 은은한 광채가 부풀어 오른다.

		처음엔 카드 자체를 **UIScale**로 키웠는데, 그러면 안의 설명 텍스트가
		호버 트윈이 진행되는 동안 매 프레임 다른 크기로 줄바꿈을 다시 계산해
		글자 줄이 계속 깨져 보였다(요청: "글자 줄 깨지는 문제 수정"). 텍스트가
		있는 요소는 아예 크기를 건드리지 않고, **카드 뒤에 별도로 깔린 halo
		프레임**만 카드 테두리보다 살짝 크게 부풀려 "커지는 느낌"을 낸다.
		글자는 항상 고정된 크기로 남아 줄바꿈이 흔들리지 않는다.
	]]
	local halo = make("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.Edge,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, button)
	button.MouseEnter:Connect(function()
		button.ZIndex = 5
		TweenService:Create(stroke, HOVER_TWEEN, { Thickness = 4 }):Play()
		TweenService:Create(halo, HOVER_TWEEN, { Size = UDim2.new(1, 20, 1, 20), BackgroundTransparency = 0.72 }):Play()
	end)
	button.MouseLeave:Connect(function()
		-- 이미 선택된(금색 테두리) 카드라면 원래 상태가 아니라 선택 표시로 되돌아간다.
		if self.selectedRewardCardId == card.Id then
			return
		end
		button.ZIndex = 1
		TweenService:Create(stroke, HOVER_TWEEN, { Thickness = 2 }):Play()
		TweenService:Create(halo, HOVER_TWEEN, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }):Play()
	end)

	-- 상단: 그림 + 이름.
	local art = make("Frame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = style.Fill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, button)
	self:_paintArt(art, card)
	--[[
		글자는 그림 **위**에 올라와야 한다. 도형이 ZIndex 1~6을 쓰므로 그보다 높게 준다.
		이름 뒤에는 어두운 띠를 깔아, 밝은 문양 위에서도 읽히게 한다.
	]]
	--[[
		등급·레벨 표시.

		이 글자는 문양 위에 바로 얹히는데, 마침 왼쪽 위 모서리 장식과 겹쳐 "일반 · Lv.0"이
		장식에 묻혀 읽히지 않았다. 검은 외곽선을 둘러 어떤 문양 위에서도 떨어지게 한다
		(요청: "글씨 테두리 씌워서 가독성 살려줘").
	]]
	local gradeLabel = make("TextLabel", {
		Size = UDim2.new(1, -14, 0, 22),
		Position = UDim2.fromOffset(7, 7),
		BackgroundTransparency = 1,
		Text = string.format("%s · Lv.%d", style.Name, card.Level),
		TextColor3 = style.Edge,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, art)
	-- TextLabel에 Contextual을 주면 테두리가 **글자 획을 따라** 둘러진다.
	-- Border를 쓰면 라벨 사각형에 붙어 버려 아무 소용이 없다.
	make("UIStroke", {
		Color = Color3.fromRGB(8, 8, 12),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, gradeLabel)
	make("Frame", {
		Name = "NamePlate",
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 1, -52),
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, art)
	make("TextLabel", {
		Size = UDim2.new(1, -14, 0, 46),
		Position = UDim2.new(0, 7, 1, -50),
		BackgroundTransparency = 1,
		Text = card.Name,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextWrapped = true,
		ZIndex = 11,
	}, art)

	-- 카드 중앙을 긋는 가로선 (요청).
	make("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 0.5, -1),
		BackgroundColor3 = style.Edge,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, button)

	-- 하단: 설명. 수치를 눈에 띄게 칠한다.
	make("TextLabel", {
		Name = "Body",
		Size = UDim2.new(1, -24, 0.5, -22),
		Position = UDim2.new(0, 12, 0.5, 12),
		BackgroundTransparency = 1,
		Text = self:_highlightNumbers(self:_breakSentences(card.Description or "")),
		TextColor3 = Color3.fromRGB(222, 222, 230),
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	}, button)

	--[[
		클릭은 **선택만** 한다(요청). 바로 획득해 버리면 잘못 눌렀을 때 되돌릴 수 없다.
		실제 획득은 `이 카드 선택하기` 버튼을 눌러야 나간다.
	]]
	-- EdgeColor를 따로 기억해 둔다. 선택 표시(금색)에서 되돌아갈 원래 색이 필요하다.
	self.rewardCardEntries[card.Id] = { Button = button, Stroke = stroke, Halo = halo, EdgeColor = style.Edge }
	button.Activated:Connect(function()
		self:_selectRewardCard(card.Id)
	end)

	-- 이 카드가 이미 선택돼 있던 채로 다시 그려졌다면(예: 다른 이유로 화면이 갱신됨) 표시를 되살린다.
	if self.selectedRewardCardId == card.Id then
		self:_selectRewardCard(card.Id)
	end
end

--[[
	보상 카드 하나를 고른다. 실제 획득은 아니다 — 표시만 바꾸고
	`이 카드 선택하기` 버튼을 활성화한다.
]]
function TowerBattleController:_selectRewardCard(cardId: string)
	self.selectedRewardCardId = cardId
	for id, entry in self.rewardCardEntries do
		local picked = id == cardId
		TweenService:Create(entry.Stroke, HOVER_TWEEN, {
			Thickness = if picked then 4 else 2,
			Color = if picked then Color3.fromRGB(255, 215, 110) else entry.EdgeColor,
		}):Play()
		TweenService:Create(entry.Halo, HOVER_TWEEN, {
			BackgroundTransparency = if picked then 0.6 else 1,
			Size = if picked then UDim2.new(1, 16, 1, 16) else UDim2.fromScale(1, 1),
		}):Play()
		entry.Button.ZIndex = if picked then 3 else 1
	end
	self.rewardConfirm.Visible = true
end

--[[
	설명 안의 수치와 [태그]에 색을 입힌다(요청: "숫자같은 곳에 하이라이트").

	RichText라 `<` 를 먼저 이스케이프해야 태그가 깨지지 않는다.
	  숫자·퍼센트·배수 → 노랑
	  [스택] 같은 대괄호 키워드 → 하늘
]]
--[[
	문장마다 줄을 바꾼다(요청: "문장마다 줄바꿈 해서 도중에 문장이 끊기는 일이 없도록").

	카드 폭이 좁아 자동 줄바꿈이 문장 한가운데를 자르면 읽는 흐름이 끊긴다. 문장이
	끝나는 자리에서 먼저 끊어 주면, 자동 줄바꿈은 그 안에서만 일어난다.

	**설명 340개를 고치는 대신 여기서 한 번에 처리한다.** 문장 끝(`다.` `요.` `. `)을
	기준으로 나누므로 카드 데이터는 손대지 않아도 된다.
]]
function TowerBattleController:_breakSentences(text: string): string
	local broken = text:gsub("([다요]%.)%s+", "%1\n"):gsub("(%.)%s+", "%1\n")
	-- 끝에 붙은 줄바꿈은 아래 여백을 늘리기만 한다.
	return (broken:gsub("%s+$", ""))
end

function TowerBattleController:_highlightNumbers(text: string): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

	--[[
		대괄호를 **자리표시자로 빼 둔 뒤** 숫자를 칠하고 마지막에 되돌린다.

		처음엔 대괄호를 먼저 `rgb(120,200,255)` 태그로 바꾸고 숫자를 칠했는데, 그러면
		방금 넣은 태그 안의 120·200·255까지 숫자로 잡혀 또 감싸진다. 마크업이 깨져
		RichText가 파싱을 포기하고 **태그가 글자 그대로 화면에 나왔다.**
		자리표시자에 숫자를 쓰지 않는 이유도 같다 — 쓰면 같은 함정에 다시 빠진다.
	]]
	local keywords: { string } = {}
	escaped = escaped:gsub("(%[[^%]]+%])", function(match)
		table.insert(keywords, match)
		return "\1" .. string.rep("K", #keywords) .. "\1"
	end)

	--[[
		백틱으로 감싼 스킬 이름(예: `크레셴도`)도 같은 함정에 빠진다 — 자리표시자로
		먼저 빼 둔다. 안 그러면 백틱이 그대로 플레이어에게 보인다(요청한 버그:
		"스킬도 `크레셴도`같이 써져").
	]]
	local skills: { string } = {}
	escaped = escaped:gsub("`([^`]+)`", function(name)
		table.insert(skills, name)
		return "\2" .. string.rep("S", #skills) .. "\2"
	end)

	escaped = escaped:gsub("(%d+%.?%d*%%?)", '<font color="rgb(255,205,90)"><b>%1</b></font>')

	for index, keyword in keywords do
		escaped = escaped:gsub(
			"\1" .. string.rep("K", index) .. "\1",
			'<font color="rgb(120,200,255)">' .. keyword .. "</font>",
			1
		)
	end
	for index, name in skills do
		escaped = escaped:gsub("\2" .. string.rep("S", index) .. "\2", "<b>" .. name .. "</b>", 1)
	end
	return escaped
end

-- 보유 카드 목록을 다시 그린다. 등급 색과 레벨(현재/최대)을 함께 보여 준다.
function TowerBattleController:_refreshOwned(state: any)
	local owned = state.Owned or {}
	self.ownedTitle.Text = string.format("보유 카드  %d종", #owned)

	for _, child in self.ownedList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, card in owned do
		local style = GRADE_STYLE[card.Grade] or GRADE_STYLE.Common
		local row = make("Frame", {
			Size = UDim2.new(1, -6, 0, 26),
			BackgroundColor3 = style.Fill,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, self.ownedList)

		--[[
			줄 왼쪽에 작은 문양을 붙인다. 보상 화면에서 본 그림과 같은 것이라,
			목록만 훑어도 "그 카드"인지 알아볼 수 있다.
		]]
		local thumb = make("Frame", {
			Name = "Art",
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromOffset(3, 2),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, row)
		self:_paintArt(thumb, card)

		make("TextLabel", {
			Size = UDim2.new(1, -34, 1, 0),
			Position = UDim2.fromOffset(30, 0),
			BackgroundTransparency = 1,
			Text = string.format(
				'%s  <font color="rgb(255,205,90)"><b>%d</b></font>/%d',
				card.Name,
				card.Level,
				card.MaxLevel
			),
			TextColor3 = Color3.fromRGB(226, 226, 234),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
		}, row)
	end
end

-- 남은 포인트와 현재 스탯 수치를 갱신한다.
function TowerBattleController:_refreshStats(state: any)
	local points = state.UnspentPoints or 0
	self.statTitle.Text = string.format(
		'스탯  ·  Lv.%d  ·  남은 포인트 <font color="rgb(255,205,90)"><b>%d</b></font>',
		state.Level or 1,
		points
	)
	local values = state.Stats or {}
	for statId, row in self.statRows do
		local label = row:FindFirstChild("Label")
		local definition = StatDefinitions.Get(statId :: any)
		if label and label:IsA("TextLabel") then
			label.Text = string.format(
				'%s  <font color="rgb(255,205,90)"><b>%d</b></font>',
				definition and definition.Name or statId,
				values[statId] or 0
			)
		end
		-- 포인트가 없으면 눌러도 서버가 거절하므로 미리 흐리게 보여 준다.
		row.BackgroundColor3 = if points > 0 then Color3.fromRGB(46, 58, 46) else Color3.fromRGB(38, 38, 45)
	end
end

--[[
	서버가 보낸 직업 스킬로 스킬 바를 다시 만든다.

	직업이 바뀌면 개수도 이름도 바뀌므로 버튼을 통째로 새로 찍는다. 3~5개짜리
	버튼이라 다시 만드는 비용보다 "목록이 어긋날 수 있다"는 위험이 훨씬 비싸다.
]]
function TowerBattleController:_refreshSkillBar(snapshot: any)
	local skills = snapshot and snapshot.AllySkills or {}
	if #skills == 0 then
		return
	end

	--[[
		목록이 바뀔 수 있으므로 **직업만 보고 건너뛰면 안 된다.**

		강화 조건이 차면 3번 오른쪽에 버튼이 하나 더 생기고, 조건이 풀리면 사라진다.
		그때 개수와 순서가 바뀌므로 목록 전체를 지문으로 삼는다.
	]]
	local signature = snapshot.AllyClassId .. "|"
	for _, skill in skills do
		signature ..= string.format("%s:%s;", skill.Id, tostring(skill.Kind))
	end
	if self.skillBarSignature == signature then
		self.allySkills = skills
		return
	end

	--[[
		고른 스킬을 **Id로 기억해 두고 되찾는다.**

		강화가 열리면 가드·명상의 번호가 밀린다. 번호만 들고 있으면 그 순간
		고른 것이 다른 스킬로 바뀌어 버린다.
	]]
	local previousId = (self.allySkills or {})[self.selectedSkill]
	local keepId = previousId and previousId.Id or nil

	self.skillBarSignature = signature
	self.skillBarClassId = snapshot.AllyClassId
	self.allySkills = skills

	self.selectedSkill = 1
	if keepId then
		for index, skill in skills do
			if skill.Id == keepId then
				self.selectedSkill = index
				break
			end
		end
	end

	for _, button in self.skillButtons do
		button:Destroy()
	end
	self.skillButtons = {}

	--[[
		버튼 폭은 개수에 맞춰 나눈다. 강화가 열리면 최대 6개(직업 3 + 강화 1 +
		가드·명상 2)가 되므로 고정 폭이면 넘친다.
	]]
	local BAR_WIDTH = 720
	local gap = 5
	local width = math.floor((BAR_WIDTH - gap * (#skills - 1)) / #skills)

	for index, skill in skills do
		--[[
			종류마다 색을 달리 한다.
			  강화  금색 — 조건이 찼다는 것을 바로 알아야 한다
			  공용  청회색 — 가드·명상은 직업 스킬과 구분되어야 한다
		]]
		local fill = Color3.fromRGB(45, 45, 50)
		local text = Color3.fromRGB(228, 228, 232)
		if skill.Kind == "Upgrade" then
			fill = Color3.fromRGB(64, 52, 30)
			text = Color3.fromRGB(255, 215, 110)
		elseif skill.Kind == "Common" then
			fill = Color3.fromRGB(38, 46, 58)
			text = Color3.fromRGB(178, 200, 226)
		end

		local button = make("TextButton", {
			Size = UDim2.fromOffset(width, 34),
			Position = UDim2.fromOffset((index - 1) * (width + gap), 0),
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			-- 근거리 / 원거리를 함께 띄운다 (요청).
			Text = string.format("%s\n%s", skill.Name, skill.RangeLabel or ""),
			TextColor3 = text,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
		}, self.skillBar)
		button.Activated:Connect(function()
			self.selectedSkill = index
			self:_paintTiles()
		end)

		--[[
			마우스를 올리면 설명이 뜬다.

			버튼 안에는 이름과 근/원거리밖에 못 넣는다 — 여섯 개가 720px을 나눠
			쓰므로 한 칸이 120px 남짓이다. 설명·피해량·범위는 바 **위쪽**에 따로
			띄운다.
		]]
		button.MouseEnter:Connect(function()
			self:_showSkillTip(skill)
		end)
		button.MouseLeave:Connect(function()
			self:_showSkillTip(nil)
		end)

		self.skillButtons[index] = button
	end
end

--[[
	스킬 설명 말풍선. nil을 넘기면 감춘다.

	설명은 서버 스냅샷이 실어 보낸다(`BattleSkills.Description`). 클라이언트가
	자기 표를 따로 들면 밸런스를 고쳤을 때 서버와 글이 어긋난다.
]]
function TowerBattleController:_showSkillTip(skill: any)
	if not self.skillTip then
		return
	end
	if not skill then
		self.skillTip.Visible = false
		return
	end

	local parts = {}
	if skill.Damage and skill.Damage > 0 then
		table.insert(parts, string.format("피해 %d", skill.Damage))
	end
	table.insert(parts, skill.RangeLabel or "")
	if skill.ShapeText and skill.ShapeText ~= "" then
		table.insert(parts, skill.ShapeText)
	end

	self.skillTip.Text = string.format(
		'<font color="rgb(255,225,150)">%s</font>  <font color="rgb(150,150,165)">%s</font>\n%s',
		skill.Name,
		table.concat(parts, " · "),
		skill.Description or ""
	)
	self.skillTip.Visible = true
end

--[[
	보호막·지속 피해·직업 자원을 한 줄로 보여 준다.

	자원이 몇인지 모르면 "왜 이 스킬이 세게 나갔는지"를 알 수 없다. 스킬 바 위에
	얇게 깐다.
]]
function TowerBattleController:_refreshStatusLine(snapshot: any)
	local status = snapshot and snapshot.AllyStatus
	if not status then
		self.statusLine.Visible = false
		return
	end

	local parts = {}
	if status.Shield > 0 then
		table.insert(parts, string.format('<font color="rgb(120,190,255)">보호막 %d</font>', status.Shield))
	end
	if status.Bleed > 0 then
		table.insert(parts, string.format('<font color="rgb(230,90,90)">출혈 %d</font>', status.Bleed))
	end
	if status.Poison > 0 then
		table.insert(parts, string.format('<font color="rgb(150,220,120)">독 %d</font>', status.Poison))
	end
	if status.Burn > 0 then
		table.insert(parts, string.format('<font color="rgb(255,150,70)">화상 %d%%</font>', status.Burn))
	end
	if status.Oil > 0 then
		table.insert(parts, string.format('<font color="rgb(200,180,120)">기름 %d턴</font>', status.Oil))
	end

	--[[
		자원은 이름을 붙여 보여 준다. 순서를 고정해야 매 턴 자리가 흔들리지 않는다
		(해시 순회는 실행마다 순서가 달라진다).
	]]
	local ids = {}
	for id in status.Stacks do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		table.insert(
			parts,
			string.format('<font color="rgb(255,205,90)">%s %d</font>', ClassResources.Label(id), status.Stacks[id])
		)
	end

	self.statusLine.Visible = #parts > 0
	self.statusLine.Text = table.concat(parts, "   ")
end

-- 지금 고른 스킬. 서버가 준 목록에서 찾는다.
function TowerBattleController:_selectedSkill(): any
	local skills = self.allySkills or {}
	local chosen = skills[self.selectedSkill] or skills[1]
	if not chosen then
		return nil
	end
	return BattleSkills.ById(chosen.Id)
end

--[[
	스킬이 맞힐 적을 모양(모션) 묶음별로 미리 구한다. 연출이 누구에게 돌진하고 누가 움찔할지
	정하는 데만 쓴다 — 실제 피해·대상은 서버 사건이 알려 준다(_consumeEvents).
]]
function TowerBattleController:_predictTargets(skillId: string): { { string } }
	local snapshot = self.snapshot
	local skill = BattleSkills.ById(skillId)
	local me = snapshot and snapshot.Units.player
	local groups: { { string } } = {}
	if not skill or not me or not me.X then
		return groups
	end
	local grid = self:_gridFromSnapshot()
	local rawStack = (
		skill.GrowResource
		and snapshot.AllyStatus
		and snapshot.AllyStatus.Stacks
		and snapshot.AllyStatus.Stacks[skill.GrowResource]
	) or 0
	local growCount = BattleSkills.GrowCount(skill, rawStack)
	for _, shape in BattleSkills.AllShapes(skill) do
		local ids = {}
		for _, id in BattleSkills.Targets(grid, "Ally", me.Y, shape, growCount, me.X) do
			local unit = snapshot.Units[id]
			if unit and unit.Alive and unit.Side == "Enemy" then
				table.insert(ids, id)
			end
		end
		table.insert(groups, ids)
	end
	return groups
end

function TowerBattleController:_onGridState(snapshot: any)
	self.snapshot = snapshot

	if not snapshot then
		--[[
			전투가 끝났다. 마지막 일격·쓰러짐 연출이 끝난 뒤에 치운다
			(서버는 끝나기 직전 상태를 먼저 보내 준다 — TowerService:_onVictory).
		]]
		task.spawn(function()
			local waited = 0
			while self.director and self.director:IsBusy() and waited < 3 do
				waited += task.wait(0.1)
			end
			if self.snapshot == nil then
				self:_teardownBattle()
			end
		end)
		return
	end

	if not self.active then
		self:_setupBattle()
	end

	self:_refreshSkillBar(snapshot)
	self:_refreshStatusLine(snapshot)
	self:_renderUnits()
	self:_paintTiles()
	self:_consumeEvents(snapshot)

	if #snapshot.Log > 0 then
		self.status.Visible = true
		self.status.Text = snapshot.Log[#snapshot.Log]
	end

	--[[
		서버가 "이 적이 너를 노린다"고 알려주면 회피 QTE를 띄운다.
		바로 띄우지 않고, 내 스킬 연출이 끝난 뒤 적이 웅크려 떠는(예고) 동안 띄운다
		(RenderStepped 의 `_pumpThreat`).
	]]
	local threats = snapshot.Threats or {}
	if #threats > 0 and not self.qte then
		self.pendingThreat = threats[1]
		self.threatWaiting = true
		if self.director then
			self.director:Windup(threats[1].Id, true)
		end
	end
end

-- 서버 사건(스킬·적 공격 결과)을 기다리던 연출에 붙인다
function TowerBattleController:_consumeEvents(snapshot: any)
	for _, ev in snapshot.Events or {} do
		if ev.Seq <= self.lastEventSeq then
			continue
		end
		self.lastEventSeq = ev.Seq
		if ev.Kind == "Skill" and self.pendingSkillPlay then
			self.pendingSkillPlay:SetResult(ev)
			self.pendingSkillPlay = nil
		elseif ev.Kind == "EnemyAttack" and self.pendingAttackPlay then
			self.pendingAttackPlay:SetResult(ev)
			self.pendingAttackPlay = nil
		end
	end
end

-- 예고된 적 공격: 앞 연출이 끝났으면 회피 QTE 를 띄운다
function TowerBattleController:_pumpThreat()
	if not self.threatWaiting or self.qte or self.dragging then
		return
	end
	if self.director and self.director:IsBusy() then
		return
	end
	self.threatWaiting = false
	self:_startQte("Dodge")
end

--=== 월드 구성 ===--

function TowerBattleController:_setupBattle()
	self.active = true
	local character = self.player.Character

	--[[
		격자를 **서버가 배정한 등반실**에 깐다.

		예전에는 `캐릭터 위치 + (0,0,-30)`에 깔았다. 그러면 두 사람이 광장에 나란히
		서 있다가 동시에 등반을 시작할 때 두 전장이 같은 공간에 겹치고, 서로의
		캐릭터가 남의 격자 위에 서 있게 된다. 어디에 그릴지는 서버가 정한다
		(`TowerArena` 주석 참고).

		좌표가 아직 안 왔으면(스냅샷이 상태보다 먼저 도착) 1번 방으로 둔다 —
		다음 TowerState가 오면 제자리를 찾는다.
	]]
	local arena = self.tower and self.tower.Arena
	local origin = if arena
		then Vector3.new(arena.X, arena.Y, arena.Z)
		else (function()
			local fallback = TowerArena.SlotOrigin(1)
			return Vector3.new(fallback.X, fallback.Y, fallback.Z)
		end)()

	self.arenaOrigin = origin
	self.layout = BattleArena.NewLayout(CFrame.new(origin))
	self.folder = make("Folder", { Name = "TowerBattleArena" }, workspace)

	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { self.folder, character }

	self.tiles = { Ally = {}, Enemy = {} }
	for _, side in { "Ally", "Enemy" } :: { BattleGrid.Side } do
		for y = 1, GRID_HEIGHT do
			self.tiles[side][y] = {}
			for x = 1, GRID_WIDTH do
				local cf = BattleArena.CellWorldCFrame(self.layout, side, x, y, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
				self.tiles[side][y][x] = make("Part", {
					Name = string.format("Tile_%s_%d_%d", side, x, y),
					Anchored = true,
					CanCollide = false,
					Size = BattleArena.TileSize(self.layout),
					CFrame = cf + Vector3.new(0, 0.2, 0),
					Color = TILE_IDLE,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.4,
				}, self.folder)
			end
		end
	end

	self.director = CombatDirector.new()
	-- 새 전투의 사건은 여기부터 센다(이전 전투 번호와 섞이지 않게)
	self.lastEventSeq = 0
	for _, ev in (self.snapshot and self.snapshot.Events) or {} do
		self.lastEventSeq = math.max(self.lastEventSeq, ev.Seq)
	end
	self.pendingSkillPlay = nil
	self.pendingAttackPlay = nil
	self.threatWaiting = false

	self:_setBattlePose(true)
	self:_lockCamera()
	self.skillBar.Visible = true
	self.attackButton.Visible = true
	self.status.Visible = true
end

function TowerBattleController:_teardownBattle()
	if not self.active then
		return
	end
	self.active = false
	self.arenaOrigin = nil
	if self.director then
		self.director:Destroy()
		self.director = nil
	end
	self.pendingSkillPlay = nil
	self.pendingAttackPlay = nil
	self.threatWaiting = false
	self:_setBattlePose(false)
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	self.skillBar.Visible = false
	self.skillTip.Visible = false
	self.statusLine.Visible = false
	self.attackButton.Visible = false
	self:_endQte()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- 칸의 자리. 아군은 떠 있는 높이(HumanoidRootPart), 적(슬라임)은 칸 윗면(바닥 가운데 기준).
function TowerBattleController:_home(side: BattleGrid.Side, x: number, y: number): CFrame
	local cf = BattleArena.CellWorldCFrame(self.layout, side, x, y, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
	if side == "Ally" then
		local position = (cf + Vector3.new(0, FLOAT_HEIGHT, 0)).Position
		return CFrame.lookAt(position, position + self.layout.Origin.RightVector)
	end
	return cf + Vector3.new(0, 0.4, 0)
end

--[[
	적(슬라임). 서버 스냅샷에 있는 유닛 수만큼 만든다(1기 가정이 없다).
	모양·움직임은 연출(CombatDirector)이 맡고, 여기서는 이름표만 붙인다.
]]
function TowerBattleController:_ensureEnemyModel(id: string, name: string, home: CFrame): Model?
	local director = self.director
	if not director then
		return nil
	end
	if director:Has(id) then
		return director:Model(id)
	end
	local actor = director:AddSlime(id, self.folder, home)
	local model = actor.Model
	local billboard = make("BillboardGui", {
		Name = "Info",
		Size = UDim2.fromOffset(160, 34),
		StudsOffset = Vector3.new(0, 4.2, 0),
		AlwaysOnTop = true,
	}, model.PrimaryPart)
	model:SetAttribute("Label", name)
	make("TextLabel", {
		Name = "Info",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Color3.fromRGB(220, 255, 210),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, billboard)
	return model
end

--[[
	스냅샷대로 유닛을 배치한다.

	여기가 이 파일의 핵심이다 — 위치·체력·그로기를 **정하지 않고 반영만** 한다.
	서버가 보낸 X/Y가 곧 진실이므로, 드래그로 옮긴 뒤에도 서버가 되돌리면 되돌아간다.
	실제로 옮기고 쓰러뜨리는 모습은 연출이 맡는다(집 자리를 알려 주면 거기로 미끄러진다).
]]
function TowerBattleController:_renderUnits()
	local snapshot = self.snapshot
	local director = self.director
	if not snapshot or not self.layout or not director then
		return
	end

	-- 아군 아바타(캐릭터가 바뀌었으면 다시 붙인다)
	local character = self.player.Character
	local me = snapshot.Units.player
	if character and me and me.X and me.Y and character:FindFirstChild("HumanoidRootPart") then
		local home = self:_home("Ally", me.X, me.Y)
		if director:Model("player") ~= character then
			director:AddHumanoid("player", character, snapshot.AllyClassId or "Berserker", home)
			director:SetHome("player", home, true)
		elseif not director:IsHeld("player") then
			director:SetHome("player", home)
		end
	end

	local seen: { [string]: boolean } = {}
	for id, unit in snapshot.Units do
		if unit.Side ~= "Enemy" then
			continue
		end
		seen[id] = true
		if not unit.Alive then
			director:Kill(id)
			continue
		end
		if not unit.X or not unit.Y then
			continue
		end
		local home = self:_home("Enemy", unit.X, unit.Y)
		local model = self:_ensureEnemyModel(id, unit.Name, home)
		director:SetHome(id, home)
		local label = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
		local info = label and label:FindFirstChild("Info")
		if info and info:IsA("TextLabel") then
			info.Text = string.format(
				"%s  %d/%d%s",
				unit.Name,
				unit.Health,
				unit.MaxHealth,
				if unit.Stunned then "  ★그로기" else ""
			)
		end
	end

	for id in director.Actors do
		if id ~= "player" and not seen[id] then
			director:Remove(id)
		end
	end
end

--=== 캐릭터 ===--

function TowerBattleController:_root(): BasePart?
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function TowerBattleController:_moveCharacterTo(x: number, y: number)
	local root = self:_root()
	if not root or not self.layout then
		return
	end
	if self.director and self.director:Has("player") then
		self.director:SetHome("player", self:_home("Ally", x, y))
		return
	end
	local cf = BattleArena.CellWorldCFrame(self.layout, "Ally", x, y, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
	local position = (cf + Vector3.new(0, FLOAT_HEIGHT, 0)).Position
	root.CFrame = CFrame.lookAt(position, position + self.layout.Origin.RightVector)
end

-- 전투 중에는 걷지 못한다. 이동은 드래그로만(사양의 배치 방식).
function TowerBattleController:_setBattlePose(enabled: boolean)
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = self:_root()
	if not humanoid or not root then
		return
	end
	humanoid.WalkSpeed = if enabled then 0 else 16
	humanoid.JumpPower = if enabled then 0 else 50
	for _, stateType in { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Freefall } do
		humanoid:SetStateEnabled(stateType, not enabled)
	end
	root.Anchored = enabled
end

function TowerBattleController:_lockCamera()
	local camera = workspace.CurrentCamera
	if not camera or not self.layout then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = BattleArena.FitCameraCFrame(
		self.layout,
		GRID_WIDTH,
		GRID_HEIGHT,
		camera.FieldOfView,
		camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1),
		CAMERA_PITCH
	)
	-- 화면 흔들림은 연출이 이 자리를 기준으로 더한다
	if self.director then
		self.director:SetCamera(camera.CFrame)
	end
end

--=== 타일 색칠 ===--

-- 스냅샷을 격자 점유로 되돌린다. 미리보기 계산이 BattleGrid를 그대로 쓰게 하려고.
function TowerBattleController:_gridFromSnapshot(): BattleGrid.Grid
	local grid = BattleGrid.New(GRID_WIDTH, GRID_HEIGHT)
	local snapshot = self.snapshot
	if not snapshot then
		return grid
	end
	for id, unit in snapshot.Units do
		if unit.Alive and unit.X and unit.Y then
			BattleGrid.Place(grid, id, unit.Side, unit.X, unit.Y)
		end
	end
	return grid
end

function TowerBattleController:_paintTiles()
	local snapshot = self.snapshot
	if not self.active or not snapshot or not self.tiles then
		return
	end
	local me = snapshot.Units.player
	if not me then
		return
	end

	local grid = self:_gridFromSnapshot()
	local skill = self:_selectedSkill()

	local inRange: { [string]: boolean } = {}
	-- 스냅샷이 오기 전에는 고른 스킬이 없다. 그때는 범위만 안 칠하고 나머지는 그린다.
	if me.Y and skill then
		-- 조건부로 늘어나는 범위(예: 음악가 16분음표)도 실제 판정과 같은 값으로 미리 보여준다.
		local rawStack = (
			skill.GrowResource
			and snapshot.AllyStatus
			and snapshot.AllyStatus.Stacks
			and snapshot.AllyStatus.Stacks[skill.GrowResource]
		) or 0
		local growCount = BattleSkills.GrowCount(skill, rawStack)
		-- 앞뒤관통처럼 모션이 여럿이면(요청: "모션상 단계") 모션마다 덮는 칸을 다 칠한다.
		for _, shape in BattleSkills.AllShapes(skill) do
			for _, cell in BattleSkills.Cells(grid, "Ally", me.Y, shape, growCount, me.X) do
				inRange[cell.X .. "," .. cell.Y] = true
			end
		end
	end

	--[[
		적이 **예고한** 공격이 덮는 아군 칸(위협 미리보기).

		서버가 준 `Planned` 목록만 본다. 예전에는 살아 있는 적 전부의 SkillIndex를
		그대로 칠했는데, 그러면 그로기로 못 움직이는 적의 공격이나 이미 해소된
		공격까지 위협으로 보였다. 이 칸을 보고 라인을 비켜서는 것이 이 전투의 핵심
		선택이므로 표시가 정확해야 한다.
	]]
	local threatened: { [string]: boolean } = {}
	for _, enemyId in snapshot.Planned or {} do
		local unit = snapshot.Units[enemyId]
		if unit and unit.Alive and unit.Y then
			local foeSkill = BattleSkills.ByIndex(BattleSkills.Enemy(), unit.SkillIndex)
			local cells = {}
			for _, shape in BattleSkills.AllShapes(foeSkill) do
				for _, cell in BattleSkills.Cells(grid, "Enemy", unit.Y, shape, nil, unit.X) do
					table.insert(cells, cell)
				end
			end

			--[[
				**나에게 오는 공격만** 칠한다 (요청).

				예전에는 예고된 공격이 덮는 칸을 전부 칠했다. 그러면 내가 라인 1에
				있는데 라인 3이 통째로 주황색이 되어, 정작 위험한지 아닌지가 안 보였다.
				지금 서 있는 칸이 그 범위에 들어갈 때만 칠하므로, 칸이 물들면 곧
				"이번에 맞는다"는 뜻이 된다.
			]]
			local hitsMe = false
			for _, cell in cells do
				if me.X == cell.X and me.Y == cell.Y then
					hitsMe = true
					break
				end
			end
			if hitsMe then
				for _, cell in cells do
					threatened[cell.X .. "," .. cell.Y] = true
				end
			end
		end
	end

	for y = 1, GRID_HEIGHT do
		for x = 1, GRID_WIDTH do
			local ally = self.tiles.Ally[y][x]
			local isMe = me.X == x and me.Y == y
			local hovered = self.dragHover and self.dragHover.X == x and self.dragHover.Y == y
			if self.dragging then
				ally.Color = if hovered then TILE_DROP else TILE_IDLE
			elseif isMe then
				ally.Color = TILE_ME
			elseif threatened[x .. "," .. y] then
				ally.Color = TILE_THREAT
			else
				ally.Color = TILE_IDLE
			end

			local foe = self.tiles.Enemy[y][x]
			foe.Color = if inRange[x .. "," .. y] then TILE_RANGE else TILE_IDLE
			foe.Transparency = if inRange[x .. "," .. y] then 0.15 else 0.4
		end
	end

	for index, button in self.skillButtons do
		local barSkill = (self.allySkills or {})[index]
		local cooldownLeft = barSkill and barSkill.CooldownLeft or 0
		--[[
			재사용 대기 중인 스킬은 어둡게 눌러 "지금은 못 쓴다"는 걸 색으로도
			보여준다(요청한 쿨타임 기능의 짝 — 값만 있고 화면에 아무 표시가
			없으면 "왜 스킬이 안 나가지" 버그처럼 보인다).
		]]
		if cooldownLeft > 0 then
			button.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
			button.TextTransparency = 0.5
			button.Text = string.format("%s\n%d턴 대기", barSkill.Name, cooldownLeft)
		else
			button.BackgroundColor3 = if index == self.selectedSkill
				then Color3.fromRGB(70, 90, 140)
				else Color3.fromRGB(45, 45, 50)
			button.TextTransparency = 0
			if barSkill then
				button.Text = string.format("%s\n%s", barSkill.Name, barSkill.RangeLabel or "")
			end
		end
	end
end

--=== 입력: 드래그 이동 ===--

function TowerBattleController:_tileUnderCursor(): any?
	local camera = workspace.CurrentCamera
	if not camera or not self.folder then
		return nil
	end
	local location = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(location.X, location.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 900, params)
	if not hit then
		return nil
	end
	local side, x, y = hit.Instance.Name:match("^Tile_(%a+)_(%d+)_(%d+)$")
	if side ~= "Ally" then
		return nil
	end
	return { X = tonumber(x), Y = tonumber(y) }
end

function TowerBattleController:_bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.active or self.qte then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- 연출(스킬·적 공격) 중에는 집어 들지 않는다
			if self.director and self.director:IsBusy() then
				return
			end
			self.dragging = true
			-- 바로 집지 않는다: 잠깐 누르고 있거나 다른 칸으로 끌 때 집어 든다(클릭마다 들었다 놓는 연출이 나오지 않게)
			self.dragStart = os.clock()
			self.grabbed = false
		elseif self.qte then
			return
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if self.dragging then
			self.dragging = false
			local target = self.dragHover
			self.dragHover = nil
			local me = self.snapshot and self.snapshot.Units.player
			local grabbed = self.grabbed
			self.grabbed = false
			if grabbed and self.director and self.layout then
				-- 놓은 칸에 먼저 내려놓는다(서버가 거절하면 다음 스냅샷이 제자리로 되돌린다)
				local cell = target or (me and me.X and { X = me.X, Y = me.Y })
				if cell then
					self.director:Drop("player", self:_home("Ally", cell.X, cell.Y))
				end
			end
			if target then
				-- 서버에 의도만 보낸다. 실제 위치는 다음 스냅샷이 알려준다.
				self.Remotes.GridAction:FireServer({ Kind = "Move", X = target.X, Y = target.Y })
			end
			self:_paintTiles()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not self.active then
			return
		end
		if self.dragging then
			self.dragHover = self:_tileUnderCursor()
			self:_paintTiles()
			-- 들린 캐릭터는 가리킨 칸 위 공중을 따라간다
			local hover = self.dragHover
			local me = self.snapshot and self.snapshot.Units.player
			local elsewhere = hover and me and (hover.X ~= me.X or hover.Y ~= me.Y)
			if not self.grabbed and self.director and (elsewhere or os.clock() - (self.dragStart or 0) > 0.18) then
				self.grabbed = true
				self.director:Grab("player")
			end
			if self.grabbed and hover and self.director and self.layout then
				self.director:HoldAt("player", self:_home("Ally", hover.X, hover.Y).Position + Vector3.new(0, 2.2, 0))
			end
		end
		if self.qte then
			self:_tickQte()
		end
		self:_pumpThreat()
	end)

	--[[
		QTE 입력을 `QteDefinitions`가 아는 이름으로 바꿔 넘긴다.
		탭 계열은 "Tap", 방향 계열은 Up/Right/Down/Left다(IsValidInput이 종류별로 가린다).
	]]
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.qte then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.E
		then
			self:_qteInput("Tap")
			return
		end
		local directions = {
			[Enum.KeyCode.Up] = "Up",
			[Enum.KeyCode.W] = "Up",
			[Enum.KeyCode.Right] = "Right",
			[Enum.KeyCode.D] = "Right",
			[Enum.KeyCode.Down] = "Down",
			[Enum.KeyCode.S] = "Down",
			[Enum.KeyCode.Left] = "Left",
			[Enum.KeyCode.A] = "Left",
		}
		local direction = directions[input.KeyCode]
		if direction then
			self:_qteInput(direction)
		end
	end)
end

--=== QTE ===--

--[[
	QTE는 클라이언트가 만들고 판정한다 — 입력 시각이 여기에만 있기 때문이다.
	서버로 나가는 것은 **등급 하나**뿐이고, 그 등급이 배율로 쓰인다.
]]
function TowerBattleController:_startQte(role: QteDefinitions.Role)
	if self.qte then
		return
	end
	local rng = Random.new(os.clock() * 1000)
	self.qte = QteDefinitions.Create(role, function()
		return rng:NextNumber()
	end, os.clock() * 1000, "tower", false)
	self.qteStart = os.clock()
	self.qtePanel.Visible = true
	local chosen = self:_selectedSkill()
	self.qteLabel = if role == "Skill"
		then (chosen and chosen.Name or "공격")
		else string.format("%s의 공격", self.pendingThreat and self.pendingThreat.SkillName or "적")
	self.qteTitle.Text = self.qteLabel
	self.attackButton.Visible = false
end

--[[
	QTE 눈금을 **실제 판정값**으로 그린다.

	처음엔 `visual.ZoneStart` / `visual.Cursor` 같은 이름을 지어 썼는데, `VisualState`가
	돌려주는 키는 소문자이고 **종류마다 다르다**(position/targetPosition, outerRadius/
	targetRadius, count/goal …). 그래서 폴백만 동작해 판정과 아무 상관 없는 가짜 눈금이
	떴다 — 초록 구간에서 눌러도 빗나가는, 가장 나쁜 종류의 버그다.

	가로 바 하나로 다섯 종류를 모두 표현한다:
	  Sweep        커서 = position, 목표 = targetPosition ± successGap
	  Forge/Parry  줄어드는 고리를 나아가는 커서로 환산(1 - radius)
	  Mash         커서 = 누른 횟수 / 목표, 구간은 전체
	  Directional  바 대신 남은 입력 순서를 글자로
]]
function TowerBattleController:_tickQte()
	local challenge = self.qte
	if not challenge then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000
	local visual = QteDefinitions.VisualState(challenge, elapsed)
	local kind = challenge.Type

	local cursor, center, gap = 0, 0.5, 0.1
	if kind == "Sweep" then
		cursor = tonumber(visual.position) or 0
		center = tonumber(visual.targetPosition) or 0.5
		gap = tonumber(visual.successGap) or 0.1
		self.qteTitle.Text = string.format(
			"%s — %d/%d회 (빗맞음 %d)",
			self.qteLabel,
			(tonumber(visual.attempt) or 0) + 1,
			tonumber(visual.attempts) or 1,
			tonumber(visual.misses) or 0
		)
	elseif kind == "Forge" or kind == "Parry" then
		-- 고리가 줄어드는 것 = 커서가 나아가는 것으로 바꿔 읽는다.
		cursor = 1 - (tonumber(visual.outerRadius) or 1)
		center = 1 - (tonumber(visual.targetRadius) or 0.3)
		gap = tonumber(visual.successGap) or 0.08
	elseif kind == "Mash" then
		local count = tonumber(visual.count) or 0
		local goal = math.max(tonumber(visual.goal) or 8, 1)
		cursor = math.clamp(count / goal, 0, 1)
		center, gap = 0.5, 0.5
		self.qteTitle.Text = string.format("%s — 연타! %d/%d", self.qteLabel, count, goal)
	else
		--[[
			Directional(스트라타젬)은 **화살표로** 보여 준다.

			처음엔 "Up Right Down"처럼 영어 단어를 늘어놓았는데, 글로 읽고 방향으로
			바꾸는 사이에 시간이 다 간다. 방향키를 누르는 QTE이므로 눌러야 할 모양
			그대로 보이는 편이 읽는 시간이 0에 가깝다.

			이미 넣은 것은 흐리게, 지금 눌러야 할 것은 크고 밝게 표시한다.
		]]
		self:_renderDirectionalQte(visual)
		self.qteTitle.Text = self.qteLabel
		cursor = math.clamp(elapsed / math.max(challenge.DurationMs, 1), 0, 1)
		center, gap = 0.5, 0.5
	end
	self.qteArrows.Visible = kind == "Directional"

	self.qteZone.Position = UDim2.fromScale(math.clamp(center - gap, 0, 1), 0)
	self.qteZone.Size = UDim2.fromScale(math.clamp(gap * 2, 0.02, 1), 1)
	self.qteCursor.Position = UDim2.new(math.clamp(cursor, 0, 1), -1, 0, -3)

	if elapsed >= challenge.DurationMs then
		self:_resolveQte()
	end
end

--[[
	스트라타젬 화살표를 그린다.

	방향 이름 → 화살표 글리프. 순서대로 늘어놓고, 진행 상황을 색과 크기로 나눈다.
	  이미 넣음  어둡게
	  지금 차례  밝게 + 크게
	  아직       회색
]]
local DIRECTION_GLYPH = { Up = "▲", Right = "▶", Down = "▼", Left = "◀" }

function TowerBattleController:_renderDirectionalQte(visual: { [string]: any })
	local directions = visual.expectedDirections or {}
	local index = (tonumber(visual.sequenceIndex) or 0) + 1

	for order, label in self.qteArrowLabels do
		local direction = directions[order]
		if not direction then
			label.Visible = false
		else
			label.Visible = true
			label.Text = DIRECTION_GLYPH[direction] or "•"
			if order < index then
				label.TextColor3 = Color3.fromRGB(90, 90, 100)
				label.TextSize = 22
			elseif order == index then
				label.TextColor3 = Color3.fromRGB(232, 179, 57)
				label.TextSize = 34
			else
				label.TextColor3 = Color3.fromRGB(170, 170, 180)
				label.TextSize = 22
			end
		end
	end
end

--[[
	입력을 종류에 맞게 먹인다. 시험판(`Battle3DController:_qteInput`)과 같은 계약이다.
	  Mash        누를 때마다 InputCount 증가. 시간이 다 되면 판정
	  Directional 순서를 소비하고 틀리면 Mistakes 증가, 다 넣으면 판정
	  나머지      한 번 누르면 그 시점으로 판정

	이걸 빼먹으면 Mash는 InputCount가 0이라, Directional은 순서를 못 넣어서
	**언제나 실패**한다. 클릭 한 번으로 전부 처리하려 했던 것이 애초에 틀렸다.
]]
function TowerBattleController:_qteInput(input: string)
	local challenge = self.qte
	if not challenge or not QteDefinitions.IsValidInput(challenge.Type, input) then
		return
	end

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
			self:_resolveQte()
		end
		return
	end

	self:_resolveQte()
end

function TowerBattleController:_resolveQte()
	local challenge = self.qte
	if not challenge then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000
	local grade = QteDefinitions.Judge(challenge, elapsed)
	local role = challenge.Role
	self:_endQte()

	if role == "Skill" then
		--[[
			번호와 Id를 함께 보낸다. 강화 스킬이 열리고 닫히면 뒤쪽(가드·명상) 번호가
			밀리므로, 서버가 Id를 먼저 보고 정확한 스킬을 집을 수 있게 한다.
		]]
		local chosen = (self.allySkills or {})[self.selectedSkill]
		self.Remotes.GridAction:FireServer({
			Kind = "Skill",
			SkillIndex = self.selectedSkill,
			SkillId = chosen and chosen.Id or nil,
			Grade = grade,
		})
		-- 서버 판정을 기다리지 않고 바로 휘두른다. 피해 숫자는 결과가 오면 붙는다.
		if self.director and chosen then
			-- 붕괴는 차징이 없으면 이번이 "차징"(피해 없음)이다 — 내려치지 않고 힘을 모으는 모션
			local motionId = chosen.Id
			local stacks = self.snapshot and self.snapshot.AllyStatus and self.snapshot.AllyStatus.Stacks
			if motionId == "Collapse" and ((stacks and stacks[ClassResources.CHARGE]) or 0) <= 0 then
				motionId = "CollapseCharge"
			end
			self.pendingSkillPlay = self.director:PlaySkill("player", motionId, self:_predictTargets(chosen.Id))
		end
	else
		--[[
			대상은 보내지 않는다. 어느 적의 공격을 막는 중인지는 **서버가 대기열로**
			알고 있고, 여기서 Id를 같이 보내면 어긋날 때 교착이 생긴다(그래서 서버가
			무시하도록 바꿨다). 클라이언트가 넘기는 것은 등급 하나뿐이다.
		]]
		local threat = self.pendingThreat
		self.pendingThreat = nil
		self.Remotes.GridAction:FireServer({ Kind = "Dodge", Grade = grade })
		if self.director and threat then
			self.pendingAttackPlay =
				self.director:PlayEnemyAttack(threat.Id, threat.SkillId or "SlimeTackle", "player", grade)
		end
	end
end

function TowerBattleController:_endQte()
	self.qte = nil
	self.qtePanel.Visible = false
	self.attackButton.Visible = self.active
end

return TowerBattleController
