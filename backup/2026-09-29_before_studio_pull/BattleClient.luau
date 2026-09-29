--!strict
--[[
	BattleClient — 서버가 판정한 격자 전투를 **그리고, 입력만 보내는** 클라이언트. (2026-09-28, 옛 BattleClient)

	탑 입장 UI(입장·포기·개발 버튼, 직업 고르기, 보상판, 보유 카드·스탯판)는 전투 입장 코드와 함께 걷어냈다.
	입장은 디버그 패널(`DebugBattlePanel`)·필드 만남 몹, 레벨업·카드는 `LevelUpUi` 가 맡는다.
	남은 것: 격자·유닛 그리기, 스킬 바, QTE, 드래그 이동, 전투 연출(CombatDirector).

	권한 경계
	  서버 → GridState  {Turn, Outcome, Units{X,Y,Health,Groggy,...}, Threats, AutoQte, BattleSeq}
	         BattleState {Arena = {X,Y,Z,Yaw}} — 격자를 어디에 깔지
	  클라 → GridAction {Kind="Move"|"Skill"|"Dodge", ...}

	여기에는 체력·피해·적 위치를 **정하는** 코드가 없다. 오직 QTE 등급만 만든다(입력 타이밍이 여기에만 있다).
	디버그 설정 AutoQte 가 켜져 있으면 QTE 를 띄우지 않고 그 등급을 바로 보낸다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
-- 전투 연출(모션·무기·이펙트·슬라임). 판정은 하지 않고 서버 결과를 그린다.
local CombatDirector = require(script.Parent.Combat.CombatDirector)
local BattleStore = require(script.Parent.BattleStore)

local BattleClient = {}
BattleClient.__index = BattleClient

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
	`plazaUi`는 광장 버튼(모션 제작·인벤토리)을 든 `BattleController`다. 전투 중엔 그 버튼을 감춰야
	하는데 저쪽이 소유하므로 소유자에게 알린다(`SetBattleActive`).
]]
function BattleClient.new(remotes: Folder, plazaUi: any?)
	local self = setmetatable({}, BattleClient)
	self.Remotes = remotes
	self.plazaUi = plazaUi
	self.player = Players.LocalPlayer
	self.active = false
	self.snapshot = nil :: any
	-- 서버가 정한 전장 자리 {X,Y,Z,Yaw} (BattleState.Arena)
	self.arena = nil :: any
	self.battleSeq = 0
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
	self.arenaOrigin = nil :: Vector3?

	self:_buildUi()

	remotes.GridState.OnClientEvent:Connect(function(snapshot)
		self:_onGridState(snapshot)
	end)
	BattleStore.Subscribe(function(state)
		if state and state.Arena then
			self.arena = state.Arena
		end
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

function BattleClient:_buildUi()
	local gui = make("ScreenGui", {
		Name = "TowerBattleGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.player:WaitForChild("PlayerGui"))
	self.Gui = gui

	-- 전투 나가기(보상 없이 그만둔다). 전투 중에만 보인다.
	self.exitButton = make("TextButton", {
		Name = "BattleExit",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(120, 30),
		-- 오른쪽 위 핫바(도구 칸) 아래. 광장 버튼(모션 제작)은 전투 중 감춰져 그 자리가 빈다.
		Position = UDim2.new(1, -16, 0, 164),
		BackgroundColor3 = Color3.fromRGB(120, 40, 44),
		BorderSizePixel = 0,
		Text = "전투 나가기",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.exitButton)
	self.exitButton.Activated:Connect(function()
		self.Remotes.BattleAction:FireServer({ Kind = "End" })
	end)

	--[[
		결투사 태세 버튼(스킬 바 오른쪽 위). 턴당 한 번, 행동을 쓰지 않는다.
		철벽·광검·양날처럼 필수 카드가 태세를 정했으면 잠긴다. 단축키 Q.
	]]
	self.stanceButton = make("TextButton", {
		Name = "Stance",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.new(0.5, 210, 1, -104),
		BackgroundColor3 = Color3.fromRGB(150, 70, 50),
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.stanceButton)
	self.stanceButton.Activated:Connect(function()
		self:_toggleStance()
	end)

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
		-- 카드로 잠겼거나 스테미나가 모자라면 보내지 않는다(그로기로 쉬는 턴은 보내서 턴을 넘긴다)
		local stunned = self.snapshot and self.snapshot.AllyStunned
		if chosen and not stunned and (chosen.Blocked or (chosen.StaminaCost or 0) > ((self.snapshot and self.snapshot.AllyStamina) or 0)) then
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

	self:_bindInput()
end

--[[
	서버가 보낸 직업 스킬로 스킬 바를 다시 만든다.

	직업이 바뀌면 개수도 이름도 바뀌므로 버튼을 통째로 새로 찍는다. 3~5개짜리
	버튼이라 다시 만드는 비용보다 "목록이 어긋날 수 있다"는 위험이 훨씬 비싸다.
]]
function BattleClient:_refreshSkillBar(snapshot: any)
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

-- 결투사 태세 버튼을 스냅샷대로 칠한다
function BattleClient:_refreshStance(snapshot: any)
	local stance = snapshot and snapshot.Stance
	self.stanceButton.Visible = self.active == true and stance ~= nil
	if not stance then
		return
	end
	local now = if stance.Attack then "공격" else "방어"
	local nextOne = if stance.Attack then "방어" else "공격"
	if stance.Locked then
		self.stanceButton.Text = now .. " 태세 (고정)"
		self.stanceButton.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	elseif stance.Used then
		self.stanceButton.Text = now .. " 태세 · 전환함"
		self.stanceButton.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	else
		self.stanceButton.Text = string.format("%s → %s 태세 [Q]", now, nextOne)
		self.stanceButton.BackgroundColor3 = if stance.Attack then Color3.fromRGB(60, 90, 150) else Color3.fromRGB(160, 70, 50)
	end
end

function BattleClient:_toggleStance()
	local stance = self.snapshot and self.snapshot.Stance
	if not self.active or not stance or stance.Used or stance.Locked then
		return
	end
	self.Remotes.GridAction:FireServer({ Kind = "Stance" })
end

--[[
	스킬 설명 말풍선. nil을 넘기면 감춘다.

	설명은 서버 스냅샷이 실어 보낸다(`BattleSkills.Description`). 클라이언트가
	자기 표를 따로 들면 밸런스를 고쳤을 때 서버와 글이 어긋난다.
]]
function BattleClient:_showSkillTip(skill: any)
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
function BattleClient:_refreshStatusLine(snapshot: any)
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
function BattleClient:_selectedSkill(): any
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
function BattleClient:_predictTargets(skillId: string): { { string } }
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

function BattleClient:_onGridState(snapshot: any)
	self.snapshot = snapshot

	if not snapshot then
		--[[
			전투가 끝났다. 마지막 일격·쓰러짐 연출이 끝난 뒤에 치운다
			(서버는 끝나기 직전 상태를 먼저 보내 준다 — BattleService:_settle).
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

	-- 재시작 등으로 **다른 판**이 왔으면 앞 판을 바로 치우고 새로 깐다(자리가 바뀔 수 있다)
	if self.active and snapshot.BattleSeq and snapshot.BattleSeq ~= self.battleSeq then
		self:_teardownBattle()
	end
	if not self.active then
		self.battleSeq = snapshot.BattleSeq or 0
		self:_setupBattle()
	end

	self:_refreshSkillBar(snapshot)
	self:_refreshStance(snapshot)
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
function BattleClient:_consumeEvents(snapshot: any)
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
function BattleClient:_pumpThreat()
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

function BattleClient:_setupBattle()
	self.active = true
	local character = self.player.Character

	--[[
		격자를 **서버가 정한 자리**(BattleState.Arena)에 깐다. 하늘 전장이면 개인 칸, 필드면 그 자리.
		클라이언트가 자기 위치에 깔면 두 사람의 전장이 겹친다 — 어디에 그릴지는 서버가 정한다.
		서버는 BattleState 를 GridState 보다 먼저 보내므로 보통 자리가 이미 와 있다.
		없으면(드묾) 지금 서 있는 곳.
	]]
	local arena = self.arena
	local root = self:_root()
	local origin = if arena
		then Vector3.new(arena.X, arena.Y, arena.Z)
		else (if root then root.Position - Vector3.new(0, 3, 0) else Vector3.zero)
	local yaw = if arena and arena.Yaw then arena.Yaw else 0

	self.arenaOrigin = origin
	self.layout = BattleArena.NewLayout(CFrame.new(origin) * CFrame.Angles(0, yaw, 0))
	-- 필드에서는 나무·지붕을 맞히지 않게 격자 높이 바로 위에서 땅을 찾는다
	if arena and arena.Kind == "Field" then
		self.layout.RayHeight = 14
	end
	self.folder = make("Folder", { Name = "BattleArena_Client" }, workspace)

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
	self.exitButton.Visible = true
	if self.plazaUi then
		self.plazaUi:SetBattleActive(true)
	end
end

function BattleClient:_teardownBattle()
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
	self.exitButton.Visible = false
	self.stanceButton.Visible = false
	if self.plazaUi then
		self.plazaUi:SetBattleActive(false)
	end
	self:_endQte()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- 칸의 자리. 아군은 떠 있는 높이(HumanoidRootPart), 적(슬라임)은 칸 윗면(바닥 가운데 기준).
function BattleClient:_home(side: BattleGrid.Side, x: number, y: number): CFrame
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
function BattleClient:_ensureEnemyModel(id: string, name: string, home: CFrame): Model?
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
function BattleClient:_renderUnits()
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

function BattleClient:_root(): BasePart?
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function BattleClient:_moveCharacterTo(x: number, y: number)
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
function BattleClient:_setBattlePose(enabled: boolean)
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

function BattleClient:_lockCamera()
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
function BattleClient:_gridFromSnapshot(): BattleGrid.Grid
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

function BattleClient:_paintTiles()
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
		local stamina = (self.snapshot and self.snapshot.AllyStamina) or 0
		local cost = barSkill and barSkill.StaminaCost or 0
		--[[
			재사용 대기 중인 스킬은 어둡게 눌러 "지금은 못 쓴다"는 걸 색으로도
			보여준다(요청한 쿨타임 기능의 짝 — 값만 있고 화면에 아무 표시가
			없으면 "왜 스킬이 안 나가지" 버그처럼 보인다).
		]]
		if cooldownLeft > 0 then
			button.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
			button.TextTransparency = 0.5
			button.Text = string.format("%s\n%d턴 대기", barSkill.Name, cooldownLeft)
		elseif barSkill and barSkill.Blocked then
			-- 철벽처럼 필수 카드가 공격 스킬을 막았다
			button.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
			button.TextTransparency = 0.5
			button.Text = string.format("%s\n카드로 잠김", barSkill.Name)
		elseif barSkill and cost > stamina then
			button.BackgroundColor3 = Color3.fromRGB(34, 30, 26)
			button.TextTransparency = 0.4
			button.Text = string.format("%s\n스테미나 %d/%d", barSkill.Name, math.floor(stamina), cost)
		else
			button.BackgroundColor3 = if index == self.selectedSkill
				then Color3.fromRGB(70, 90, 140)
				else Color3.fromRGB(45, 45, 50)
			button.TextTransparency = 0
			if barSkill then
				button.Text = if cost > 0
					then string.format("%s\n%s · 기력 %d", barSkill.Name, barSkill.RangeLabel or "", cost)
					else string.format("%s\n%s", barSkill.Name, barSkill.RangeLabel or "")
			end
		end
	end
end

--=== 입력: 드래그 이동 ===--

function BattleClient:_tileUnderCursor(): any?
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

function BattleClient:_bindInput()
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
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q and not self.qte then
			self:_toggleStance()
			return
		end
		if not self.qte then
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
function BattleClient:_startQte(role: QteDefinitions.Role)
	if self.qte then
		return
	end
	-- 디버그: QTE 를 건너뛰고 정한 등급을 바로 보낸다
	local auto = self.snapshot and self.snapshot.AutoQte
	if auto and auto ~= "Off" then
		self:_submitGrade(role, auto)
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
function BattleClient:_tickQte()
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

function BattleClient:_renderDirectionalQte(visual: { [string]: any })
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
function BattleClient:_qteInput(input: string)
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

function BattleClient:_resolveQte()
	local challenge = self.qte
	if not challenge then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000
	local grade = QteDefinitions.Judge(challenge, elapsed)
	local role = challenge.Role
	self:_endQte()
	self:_submitGrade(role, grade)
end

-- 등급을 서버로 보내고 연출을 시작한다(QTE 를 거쳤든 자동이든)
function BattleClient:_submitGrade(role: QteDefinitions.Role, grade: string)
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

function BattleClient:_endQte()
	self.qte = nil
	self.qtePanel.Visible = false
	self.attackButton.Visible = self.active
end

return BattleClient
