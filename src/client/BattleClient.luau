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
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local GridBattle = require(ReplicatedStorage.Shared.GridBattle)
local DebugBoss = require(script.Parent.Combat.DebugBoss)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
local Keywords = require(ReplicatedStorage.Shared.Keywords)
-- 전투 연출(모션·무기·이펙트·슬라임). 판정은 하지 않고 서버 결과를 그린다.
local BattleStage = require(script.Parent.BattleStage)
-- 스킬 슬롯·공격 버튼·설명 말풍선·QTE 판(그리기만)
local BattleHud = require(script.Parent.BattleHud)
-- 내가 싸우는 동안 남의 전투 판은 감춘다
local BattleSpectator = require(script.Parent.BattleSpectator)
local CombatDirector = require(script.Parent.Combat.CombatDirector)
local CombatVfx = require(script.Parent.Combat.CombatVfx)
local BattleStore = require(script.Parent.BattleStore)

local BattleClient = {}
BattleClient.__index = BattleClient

local GRID_WIDTH = BattleGrid.DEFAULT_WIDTH
local GRID_HEIGHT = BattleGrid.DEFAULT_HEIGHT

local TILE_IDLE = BattleStage.TILE_IDLE
local TILE_ME = Color3.fromRGB(70, 130, 220)
local TILE_RANGE = Color3.fromRGB(170, 60, 62)
-- 범위 안에 적이 선 칸(실제로 맞는 칸)과 적이 선 칸(범위 밖)
local TILE_RANGE_HIT = Color3.fromRGB(235, 70, 64)
local TILE_OCCUPIED = Color3.fromRGB(150, 120, 170)
local TILE_THREAT = Color3.fromRGB(220, 150, 60)
local TILE_DROP = Color3.fromRGB(90, 190, 120)
-- 보스 디버그: 버프 칸·버그 칸·검수 준비중 칸(예고)
local TILE_BUFF = BattleStage.BOARD.Buff
local TILE_DEBUFF = BattleStage.BOARD.Debuff
local TILE_HEAL = BattleStage.BOARD.Heal
local TILE_DELETE = BattleStage.BOARD.Pending
-- 회피·가드 불가 공격이 덮는 칸(코어 덤프). 비켜서는 것만 답이다
local TILE_UNAVOID = Color3.fromRGB(200, 20, 30)

-- 보스 부위 이름표 높이(부위 바닥 기준)
-- 먼 라인(1)일수록 화면에서 위로 올라가 보이므로 서브코어-삭제는 낮게, 머리는 높게 달아 겹치지 않게 한다
-- 보스 부위 이름표 높이(다면체 가운데 기준 — 코어 반지름 6, 위성 2.3)
local BOSS_LABEL = { Head = 5.4, DeleteArm = 3.8, PatchArm = 3.8, Core = 9.5 }

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local FLOAT_HEIGHT = 3.4
local CAMERA_PITCH = 35

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
	-- 연출 중에 받은 스냅샷의 적 자리 갱신을 미뤄둔다 (모션이 끝나야 적이 움직임)
	self.pendingRender = false
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
			-- 캐릭터가 바뀌면 체력바도 다시 붙인다
			if self.hpBar then
				local char = self.player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					self.hpBar.Parent = root
				end
			end
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

	--[[
		버튼·스킬 설명·QTE 는 BattleHud 가 그린다(2026-09-29 다시 그림: 버튼이 작고 설명이 읽기 힘들다는 요청).
		  나가기   보상 없이 그만둔다
		  태세     결투사. 턴당 한 번, 행동을 쓰지 않는다. 필수 카드가 정했으면 잠긴다(Q)
		  슬롯     1~6 으로 고르고, 공격(Space)으로 QTE 를 연다
	]]
	self.hud = BattleHud.new(gui, {
		Select = function(index: number)
			self.selectedSkill = index
			self:_paintTiles()
		end,
		Attack = function()
			self:_tryAttack()
		end,
		Stance = function()
			self:_toggleStance()
		end,
		Exit = function()
			self.Remotes.BattleAction:FireServer({ Kind = "End" })
		end,
	})

	-- (임시) 플레이어 체력 표시. 전투 중에 캐릭터 머리 위에 뜬다.
	self.hpBar = make("BillboardGui", {
		Name = "PlayerHpBar",
		Size = UDim2.fromOffset(200, 30),
		StudsOffset = Vector3.new(0, -3.5, 0),
		AlwaysOnTop = true,
		Enabled = false,
	})
	self.hpLabel = make("TextLabel", {
		Name = "HpLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 100, 100),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, self.hpBar)

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
		self.hud:SetSkills(skills, false)
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

	-- 강화가 열리면 최대 6개(직업 3 + 강화 1 + 가드·명상 2). 슬롯 크기는 그대로, 판이 넓어진다
	self.hud:SetSkills(skills, true)
end

-- 결투사 태세 버튼을 스냅샷대로 칠한다
function BattleClient:_refreshStance(snapshot: any)
	self.hud:SetStance(snapshot and snapshot.Stance)
end

-- 지금 움직일 수 없으면 까닭(움직일 수 있으면 nil). 서버(BattleService Move·GridBattle.MoveAlly)와 같은 조건
function BattleClient:_moveBlocked(): string?
	local snapshot = self.snapshot
	if not snapshot then
		return "전투 정보를 기다리는 중"
	end
	if snapshot.AllyStunned then
		return "그로기 — 이번 턴은 움직일 수 없다"
	end
	if snapshot.Boss and (snapshot.Boss.Locked or 0) > 0 then
		return "검수 준비중 칸에서 턴을 마쳐 이번 턴은 움직일 수 없다"
	end
	if self.threatWaiting or self.pendingThreat or #(snapshot.Threats or {}) > 0 then
		return "적 공격을 받는 중에는 움직일 수 없다"
	end
	return nil
end

-- 공격 버튼·Space: 고른 스킬로 QTE 를 연다
function BattleClient:_tryAttack()
	if not self.active or self.qte then
		return
	end
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
end

function BattleClient:_toggleStance()
	local stance = self.snapshot and self.snapshot.Stance
	if not self.active or not stance or stance.Used or stance.Locked then
		return
	end
	self.Remotes.GridAction:FireServer({ Kind = "Stance" })
end

--[[
	걸린 효과를 아이콘 줄로 보여 준다(2026-09-29 요청: 글씨로만 두지 말고 아이콘, 누르고 있거나 모바일은 눌러서 설명).
	효과 하나 = { Id, Name, Glyph, Color, Count(없으면 nil), Desc }. 모양·설명은 BattleHud 가 그린다.
	음표(4·8·16분)는 한 아이콘에 묶는다(요청).
]]
local NOTE_IDS = { [ClassResources.QUARTER] = true, [ClassResources.EIGHTH] = true, [ClassResources.SIXTEENTH] = true }
-- 키워드 사전의 설명 전부(없으면 nil). 2026-10-03 사용자: 첫 줄("- 최대 10스택.")만 보여서 무엇을 얻는지 몰랐다 →
-- 수치당 얻는 버프·자동 패링 조건까지 사전 글을 통째로 보인다
local function keywordLine(name: string): string?
	local keyword = Keywords.ByName(name)
	return keyword and keyword.Description or nil
end

function BattleClient:_refreshStatusLine(snapshot: any)
	local status = snapshot and snapshot.AllyStatus
	if not status then
		self.hud:SetEffects({})
		return
	end
	local list = {}
	-- 사전에 있는 상태이상(출혈·독·보호막 …)은 사전 설명을 쓴다. 칸·검수처럼 사전에 없는 것만 아래 글
	local function add(id: string, name: string, glyph: string, color: Color3, count: number?, desc: string)
		table.insert(list, { Id = id, Name = name, Glyph = glyph, Color = color, Count = count, Desc = keywordLine(name) or desc })
	end

	-- 보스전 칸·검수
	local boss = snapshot.Boss
	if boss then
		if (boss.Tester or 0) > 0 then
			add("Tester", "테스터", "T", Color3.fromRGB(255, 200, 80), nil, "이번 턴 가하는 피해량 +3500% · 치명타 확률 +100% · 받는 피해량 −80% · 방어막 80(이번 턴까지).")
		end
		if boss.Checking then
			add("Checking", "검수중", "검", Color3.fromRGB(235, 235, 235), nil, "검은 칸(검수됨!) 위. 받는 피해량 +200%. 여기서 턴을 마치면 최대 체력 9% 고정 피해(이 효과로는 죽지 않음), 2턴 뒤 스테미나 20을 잃고 다음 턴 테스터를 얻는다.")
		end
		if boss.Pending then
			add("Pending", "검수 준비중", "준", Color3.fromRGB(255, 60, 200), nil, "이번 턴 가하는 피해량 +400%. 여기서 턴을 마치면 이 칸이 검수됨!이 되고 다음 턴 칸을 움직일 수 없다.")
		end
		if (boss.Locked or 0) > 0 then
			add("Locked", "묶임", "묶", Color3.fromRGB(200, 120, 255), boss.Locked, "검수 준비중 칸에서 턴을 마쳤다. 이번 턴은 칸을 움직일 수 없다.")
		end
		if (boss.LockImmune or 0) > 0 and (boss.Locked or 0) == 0 then
			add("LockImmune", "묶임 면역", "免", Color3.fromRGB(170, 230, 255), boss.LockImmune, string.format("묶임을 당한 뒤라 앞으로 %d턴 동안 검수 준비중 칸에서 턴을 마쳐도 묶이지 않음.", boss.LockImmune))
		end
		if (boss.StaminaDebt or 0) > 0 then
			add("StaminaDebt", "검수 후유증", "후", Color3.fromRGB(206, 214, 110), boss.StaminaDebt, string.format("%d턴 뒤 스테미나 20을 잃는다.", boss.StaminaDebt))
		end
		if boss.Standing == "Buff" then
			add("BuffCell", "버프 칸", "▲", Color3.fromRGB(70, 225, 255), nil, "이 칸에 서 있는 동안 주는 피해 +40% · 받는 피해 −20%.")
		elseif boss.Standing == "Debuff" then
			add("DebuffCell", "버그 칸", "▼", Color3.fromRGB(200, 110, 240), nil, "이 칸에 서 있는 동안 주는 피해 −30% · 받는 피해 +40%.")
		elseif boss.Standing == "Heal" then
			add("HealCell", "회복 칸", "✚", Color3.fromRGB(110, 240, 130), nil, "턴 끝에 이 칸에 서 있으면 최대 체력 15% 회복.")
		end
	end
	if status.Shield > 0 then
		add("Shield", "보호막", "盾", Color3.fromRGB(120, 190, 255), status.Shield, "받는 피해를 이 수치만큼 먼저 막는다.")
	end
	if status.Bleed > 0 then
		add("Bleed", "출혈", "血", Color3.fromRGB(230, 90, 90), status.Bleed, "턴 끝에 피해를 받는다. 이 효과로는 죽지 않는다.")
	end
	if status.Poison > 0 then
		add("Poison", "독", "毒", Color3.fromRGB(150, 220, 120), status.Poison, "턴 끝에 피해를 받는다. 이 효과로는 죽지 않는다.")
	end
	if status.Burn > 0 then
		add("Burn", "화상", "火", Color3.fromRGB(255, 150, 70), status.Burn, string.format("턴 끝에 최대 체력 %d%% 화염 피해. 이 효과로는 죽지 않는다.", status.Burn))
	end
	if status.Oil > 0 then
		add("Oil", "기름", "油", Color3.fromRGB(200, 180, 120), status.Oil, string.format("%d턴 동안 화염 피해 +50%%.", status.Oil))
	end

	--[[
		직업 자원. 순서를 고정해야 매 턴 자리가 흔들리지 않는다(해시 순회는 실행마다 순서가 달라진다).
		음표는 한 아이콘으로 묶고 설명에 4·8·16분을 따로 적는다.
	]]
	local ids = {}
	for id in status.Stacks do
		table.insert(ids, id)
	end
	table.sort(ids)
	local notes, noteTotal = {}, 0
	for _, id in ids do
		local count = status.Stacks[id]
		local label = ClassResources.Label(id)
		if NOTE_IDS[id] then
			noteTotal += count
			table.insert(notes, string.format("%s %d", label, count))
		elseif count > 0 then
			add(id, label, utf8.char(utf8.codepoint(label, 1)), Color3.fromRGB(255, 205, 90), count, keywordLine(label) or (label .. " — 직업 자원."))
		end
	end
	if noteTotal > 0 then
		add("Notes", "음표", "♪", Color3.fromRGB(255, 170, 220), noteTotal, table.concat(notes, " · "))
	end

	self.hud:SetEffects(list)
end

--[[
	적 체력 실시간(2026-10-03 사용자: "적의 HP가 실시간으로 줄어드는 게 보이게").
	서버 스냅샷은 스킬을 쓰자마자(맞기 전에) 깎인 체력을 보낸다. 그대로 그리면 맞기도 전에 체력바가 줄고,
	이름표는 연출이 끝난 뒤에야 한꺼번에 줄었다. 그래서 적마다 "보이는 체력"(hpShown)을 따로 두고
	  - 연출 중이 아니면 서버 값 그대로
	  - 연출 중이면 앞 값을 지키다가, 피해 숫자가 뜰 때마다(CombatDirector.OnDamage) 그만큼 깎는다(서버 값 아래로는 안 내려감)
	  - 연출이 끝나면 서버 값으로 맞춘다
	회복으로 서버 값이 더 크면 바로 올린다.
]]
function BattleClient:_hpView(snapshot: any): any
	if not snapshot or not snapshot.Units then
		return snapshot
	end
	self.hpShown = self.hpShown or {}
	local busy = self.director ~= nil and self.director:IsBusy()
	local units = {}
	for id, u in snapshot.Units do
		if u.Side == "Enemy" and u.Health then
			local shown = self.hpShown[id]
			if not busy or shown == nil or u.Health > shown then
				shown = u.Health
			end
			self.hpShown[id] = shown
			if shown ~= u.Health then
				local c = table.clone(u)
				c.Health = shown
				units[id] = c
				continue
			end
		end
		units[id] = u
	end
	local view = table.clone(snapshot)
	view.Units = units
	return view
end

-- 적 머리 위 이름표: 이름 · 보이는 체력 · 그로기
function BattleClient:_setEnemyInfo(id: string, unit: any)
	local model = self.director and self.director:Model(id)
	local label = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
	local info = label and label:FindFirstChild("Info")
	if info and info:IsA("TextLabel") then
		local hp = (self.hpShown and self.hpShown[id]) or unit.Health
		info.Text = string.format("%s  %d/%d%s", unit.Name, hp, unit.MaxHealth, if unit.Stunned then "  ★그로기" else "")
	end
end

-- (임시) 플레이어 체력을 전투 중에 보여 준다.
function BattleClient:_refreshHpLabel(snapshot: any)
	if not self.hpLabel then
		return
	end
	local me = snapshot and snapshot.Units and snapshot.Units.player
	if not me then
		return
	end
	self.hpLabel.Text = string.format("체력 %d / %d", me.Health, me.MaxHealth)
	self.hud:SetVitals(me.Health, me.MaxHealth, snapshot.AllyStamina or 0, snapshot.AllyMaxStamina or 0)
end

-- 지금 고른 스킬. 서버가 준 목록에서 찾는다.
--[[
	스킬 범위가 몇 단계 자랐는지. 서버가 스냅샷 스킬 목록에 실제 값(카드 규칙까지 반영한 `Grow`)을
	실어 보내면 그것을 쓰고, 없으면(옛 서버) 자원 스택으로 어림한다. 미리보기가 판정과 같아야 한다.
]]
function BattleClient:_growCount(skill: any, rawStack: number): number
	for _, entry in self.allySkills or {} do
		if entry.Id == skill.Id and entry.Grow then
			return entry.Grow
		end
	end
	return BattleSkills.GrowCount(skill, rawStack)
end

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
	local growCount = self:_growCount(skill, rawStack)
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
	-- 보스 정보 창이 열려 있으면 체력·예고를 새 스냅샷으로 고쳐 그린다(보스가 없어졌으면 닫는다)
	if self.hud and self.hud:IsBossInfoOpen() then
		if snapshot and snapshot.Boss then
			self.hud:ShowBossInfo(snapshot, self.hud.bossFocus)
		else
			self.hud:HideBossInfo()
		end
	end

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

	self:_bossBoard(snapshot)
	-- 보스 체력바(부위별 체력·페이즈·스테미나·버프·이번 턴 예고). 체력은 맞는 순간마다 줄어드는 보이는 값(_hpView)
	self.hud:SetBoss(self:_hpView(snapshot))
	self:_bossAlerts(snapshot)
	self:_refreshSkillBar(snapshot)
	self:_refreshStance(snapshot)
	self:_refreshStatusLine(snapshot)
	self:_refreshHpLabel(snapshot)
	-- 연출(스킬·죽음·적 공격) 중이면 적 자리 갱신을 미룬다 — 모션이 끝나야 적이 움직이게
	if self.director and self.director:IsBusy() then
		self.pendingRender = true
	else
		self.pendingRender = false
		self:_renderUnits()
		self:_paintTiles()
	end
	self:_consumeEvents(snapshot)

	if #snapshot.Log > 0 then
		self.hud:SetLog(snapshot.Log[#snapshot.Log])
	end
	-- 테스터가 막 걸렸으면 화면 가운데 크게 한 번
	local tester = snapshot.Boss and snapshot.Boss.Tester or 0
	if tester > (self.lastTester or 0) then
		self.hud:Flash("테스터", "가하는 피해량 +3500% · 치명 +100% · 받는 피해 −80%", BattleHud.Colors.Gold)
	end
	self.lastTester = tester

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

--[[
	보스 디버그 판(지워진 칸·버프/버그 칸). 지운 칸은 드래그가 피하도록 기억하고,
	새로 지워진 칸엔 조각이 튀고, 버프/버그 칸이 새로 깔리면 서브코어-패치가 손을 든다.
]]
--[[
	아이디어 8(2026-10-03 사용자): 페이즈가 오르면 화면 글자(ERROR → FATAL)로 알리고, 원한·마지막 발악도 한 번씩 띄운다.
	보스 연출(공전·자전·이펙트 크기)은 DebugBoss.Phase 로 페이즈만큼 커진다.
]]
local PHASE_FLASH = {
	[2] = { "2페이즈", "ERROR 0x02 — 최적화 · 부위마다 새 스킬" },
	[3] = { "3페이즈", "ERROR 0x03 — 멀티스레드 · 부위마다 두 번 행동" },
	[4] = { "4페이즈", "FATAL — 커널 모드 · 가하는 피해 +30%" },
}
function BattleClient:_bossAlerts(snapshot: any)
	local boss = snapshot.Boss
	if not boss then
		self.bossSeen = nil
		DebugBoss.Phase = 1
		return
	end
	DebugBoss.Phase = boss.Phase or 1
	local seen = self.bossSeen
	if not seen then
		-- 전투 처음: 판 변주만 알린다
		self.bossSeen = { Phase = boss.Phase or 1, FirstBroken = boss.FirstBroken, LastStand = boss.LastStand, Variant = boss.Variant }
		for _, v in GridBattle.BOSS_VARIANTS do
			if v.Id == boss.Variant then
				self.hud:Flash("판 변주: " .. v.Name, v.Text, BattleHud.Colors.Gold or Color3.fromRGB(236, 186, 78))
			end
		end
		return
	end
	-- 판 변주는 턴마다 바뀐다(2026-10-03) — 바뀌면 한 번 띄운다
	if boss.Variant ~= seen.Variant then
		seen.Variant = boss.Variant
		for _, v in GridBattle.BOSS_VARIANTS do
			if v.Id == boss.Variant then
				self.hud:Flash("판 변주: " .. v.Name, v.Text, BattleHud.Colors.Gold or Color3.fromRGB(236, 186, 78))
			end
		end
	end
	if (boss.Phase or 1) > seen.Phase then
		local f = PHASE_FLASH[boss.Phase]
		if f then
			self.hud:Flash(f[1], f[2], if boss.Phase >= 4 then BattleHud.Colors.Red else Color3.fromRGB(236, 186, 78))
		end
		seen.Phase = boss.Phase
	end
	if boss.FirstBroken and not seen.FirstBroken then
		seen.FirstBroken = boss.FirstBroken
		local id = "Grudge_" .. boss.FirstBroken
		local def = GridBattle.BOSS_BUFFS[id]
		if def then
			self.hud:Flash("원한 — " .. def.Name, "먼저 부순 부위에 디버그가 반응함", BattleHud.Colors.Red)
		end
	end
	if boss.LastStand and not seen.LastStand then
		seen.LastStand = boss.LastStand
		for _, v in GridBattle.BOSS_LAST_STANDS do
			if v.Id == boss.LastStand then
				self.hud:Flash("마지막 발악: " .. v.Name, v.Text, BattleHud.Colors.Red)
			end
		end
	end
end

function BattleClient:_bossBoard(snapshot: any)
	local board = snapshot.Boss
	local gone: { [string]: boolean } = {}
	for _, d in (board and board.Deleted) or {} do
		gone[d.X .. "," .. d.Y] = true
	end
	local mods = {}
	for _, m in (board and board.Mods) or {} do
		table.insert(mods, string.format("%d,%d,%s", m.X, m.Y, m.Kind))
	end
	table.sort(mods)
	local modSig = table.concat(mods, ";")
	if self.layout and self.goneCells then
		for key in gone do
			if not self.goneCells[key] then
				local x, y = string.match(key, "(%d+),(%d+)")
				local cf = BattleArena.CellWorldCFrame(self.layout, "Ally", tonumber(x) :: number, tonumber(y) :: number, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
				CombatVfx.Burst(cf.Position + Vector3.new(0, 0.6, 0), {
					Count = 14,
					Colors = { TILE_DELETE, Color3.fromRGB(70, 220, 255), Color3.fromRGB(40, 34, 60) },
					Size = 0.5,
					Speed = 16,
					Dir = Vector3.new(0, 1, 0),
					Spread = 60,
					Gravity = 40,
					Life = 0.7,
					Material = Enum.Material.Neon,
				})
				CombatVfx.Flash(cf.Position, { Color = TILE_DELETE, Size = 5, Life = 0.3 })
			end
		end
	end
	if self.bossModSig and modSig ~= self.bossModSig and modSig ~= "" and self.director and self.director:Has("boss_PatchArm") then
		self.director:PlaySkill("boss_PatchArm", "PatchCells", { {} })
	end
	self.goneCells = gone
	self.bossModSig = modSig
	-- 버프·충전 예고(2026-10-03): 피해가 없어 적 공격 연출로는 안 나온다 — 새 예고가 오면 그 부위가 바로 시전 모션
	local played = self.bossCastPlayed or {}
	local seen: { [string]: number } = {}
	for _, id in snapshot.Planned or {} do
		seen[id] = (seen[id] or 0) + 1
		local u = snapshot.Units[id]
		local plan = u and u.Plans and u.Plans[seen[id]]
		local sk = plan and BattleSkills.ById(plan.SkillId)
		if sk and (sk.BossKind == "Buff" or sk.BossKind == "Charge") then
			local key = string.format("%d:%s:%d", snapshot.Turn or 0, id, seen[id])
			if not played[key] and self.director and self.director:Has(id) then
				played[key] = true
				self.director:PlaySkill(id, plan.SkillId, { {} })
			end
		end
	end
	self.bossCastPlayed = played
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
	-- 회피·가드 불가 공격: QTE 없이 그대로 맞는다(판정은 서버가 강제)
	if self.pendingThreat and self.pendingThreat.Unavoidable then
		self.hud:SetLog(string.format("%s — 피할 수도 막을 수도 없다!", self.pendingThreat.SkillName or "공격"))
		self.hud:Flash("회피 불가", self.pendingThreat.SkillName, BattleHud.Colors.Red)
		self:_submitGrade("Dodge", "Fail")
		return
	end
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

	-- 서버가 정한 한 높이의 평평한 돌판(BattleStage). 옛 서버라 높이가 없으면 칸마다 땅을 따른다
	if arena and arena.FlatY then
		self.layout.FlatY = arena.FlatY
	end
	self.tiles = BattleStage.Build(self.folder, self.layout, arena and arena.BaseY, GRID_WIDTH, GRID_HEIGHT, self.rayParams) :: any

	self.director = CombatDirector.new()
	-- 피해 숫자가 뜨는 순간 그 적의 보이는 체력을 깎는다(체력바·이름표)
	self.hpShown = {}
	self.director.OnDamage = function(id: string, dmg: number)
		local unit = self.snapshot and self.snapshot.Units and self.snapshot.Units[id]
		local shown = self.hpShown[id]
		if not unit or unit.Side ~= "Enemy" or not shown then
			return
		end
		self.hpShown[id] = math.max(unit.Health, shown - dmg)
		self.hud:SetBoss(self:_hpView(self.snapshot))
		self:_setEnemyInfo(id, unit)
	end
	-- 적 진영 맨 뒷줄 가운데(결투사 강화 스킬이 그 너머까지 꿰뚫고 지나간다)
	local back = Vector3.zero
	for y = 1, GRID_HEIGHT do
		back += self.tiles.Enemy[y][GRID_WIDTH].Position
	end
	self.director.FarEnd = back / GRID_HEIGHT
	-- 새 전투의 사건은 여기부터 센다(이전 전투 번호와 섞이지 않게)
	self.lastEventSeq = 0
	self.goneCells = {}
	self.bossModSig = nil
	for _, ev in (self.snapshot and self.snapshot.Events) or {} do
		self.lastEventSeq = math.max(self.lastEventSeq, ev.Seq)
	end
	self.pendingSkillPlay = nil
	self.pendingAttackPlay = nil
	self.threatWaiting = false
	self.pendingRender = false

	self:_setBattlePose(true)
	self:_lockCamera()
	self.hud:SetActive(true)
	BattleSpectator.SetHidden(true)
	-- 체력바를 캐릭터 머리 위에 붙인다
	if character and self.hpBar then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			self.hpBar.Parent = hrp
		end
		self.hpBar.Enabled = true
	end
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
	self.bossCamStart = nil
	self.bossCamBase = nil
	self.bossCamFollow = nil
	self.bossCamLast = nil
	if self.director then
		self.director:Destroy()
		self.director = nil
	end
	self.pendingSkillPlay = nil
	self.pendingAttackPlay = nil
	self.threatWaiting = false
	self.pendingRender = false
	self:_setBattlePose(false)
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	self.hud:SetActive(false)
	BattleSpectator.SetHidden(false)
	self.lastTester = 0
	self.hpBar.Enabled = false
	self.hpBar.Parent = nil
	if self.plazaUi then
		self.plazaUi:SetBattleActive(false)
	end
	self:_endQte()
	self:_restoreOccluders()
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
function BattleClient:_ensureEnemyModel(id: string, name: string, home: CFrame, part: string?): Model?
	local director = self.director
	if not director then
		return nil
	end
	if director:Has(id) then
		return director:Model(id)
	end
	local actor = director:AddEnemy(id, part, self.folder, home)
	local model = actor.Model
	local billboard = make("BillboardGui", {
		Name = "Info",
		Size = UDim2.fromOffset(if part then 200 else 160, 34),
		StudsOffset = Vector3.new(0, if part then BOSS_LABEL[part] or 8 else 4.2, 0),
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

	-- 1차: 죽은 적을 먼저 처리한다. 사망 연출이 끝나야 살아 있는 적이 움직인다.
	local anyNewKill = false
	for id, unit in snapshot.Units do
		if unit.Side ~= "Enemy" then
			continue
		end
		seen[id] = true
		if not unit.Alive then
			local a = director.Actors[id]
			if a and not a.Dying and not a.PendingDeath then
				director:Kill(id)
				anyNewKill = true
			end
			continue
		end
	end

	-- 죽은 적이 있으면 사망 연출이 끝난 뒤에 살아 있는 적 자리를 갱신한다.
	if anyNewKill then
		for id in director.Actors do
			if id ~= "player" and not seen[id] then
				director:Remove(id)
			end
		end
		self.pendingRender = true
		return
	end

	-- 2차: 살아 있는 적 자리·이름표 갱신
	for id, unit in snapshot.Units do
		if unit.Side ~= "Enemy" or not unit.Alive then
			continue
		end
		if not unit.X or not unit.Y then
			continue
		end
		local home = if unit.Cells
			then BattleStage.BlockHome(self.layout, unit.Cells, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
			else self:_home("Enemy", unit.X, unit.Y)
		self:_ensureEnemyModel(id, unit.Name, home, unit.Part)
		director:SetHome(id, home)
		self:_setEnemyInfo(id, unit)
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

--[[
	전투 카메라를 가린 구조물(2026-10-04 사용자): 그 전투를 하는 사람에게만(이 클라이언트에서만) 반투명 + 충돌 끔.
	카메라 → 칸(양쪽 격자 전부) 광선을 쏴서 걸리는 것을 차례로 걷는다. 지형(Terrain)은 못 바꾸므로 거기서 멈춘다.
	LocalTransparencyModifier·CanCollide 는 클라이언트에서만 바뀐다(다른 플레이어·서버는 그대로). 전투가 끝나면 되돌린다.
]]
local OCCLUDE_ALPHA = 0.75
function BattleClient:_restoreOccluders()
	for part, saved in self.occluded or {} do
		if part.Parent then
			part.LocalTransparencyModifier = saved[1]
			part.CanCollide = saved[2]
		end
	end
	self.occluded = {}
end

local function isActor(part: Instance): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

function BattleClient:_scanOccluders()
	local camera = workspace.CurrentCamera
	if not camera or not self.layout then
		return
	end
	self.occluded = self.occluded or {}
	local skip: { Instance } = { workspace:FindFirstChild("CombatFx") :: Instance }
	if self.folder then
		table.insert(skip, self.folder)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = skip
	local eye = camera.CFrame.Position
	for _, side in { "Ally", "Enemy" } do
		for x = 1, GRID_WIDTH do
			for y = 1, GRID_HEIGHT do
				local cell = BattleArena.CellWorldCFrame(self.layout, side :: any, x, y, GRID_WIDTH, GRID_HEIGHT, self.rayParams)
				local goal = cell.Position + Vector3.new(0, 2.5, 0)
				for _ = 1, 8 do
					local hit = workspace:Raycast(eye, goal - eye, params)
					local part = hit and hit.Instance
					if not part or not part:IsA("BasePart") then
						break
					end
					if not isActor(part) and not self.occluded[part] then
						self.occluded[part] = { part.LocalTransparencyModifier, part.CanCollide }
						part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, OCCLUDE_ALPHA)
						part.CanCollide = false
					end
					table.insert(skip, part)
					params.FilterDescendantsInstances = skip
				end
			end
		end
	end
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
	-- 디버그전: 같은 구도에서 천천히 살짝 흔들린다(RenderStepped 가 매 프레임 _bossCamera 로 옮긴다)
	self.bossCamBase = if self.snapshot and self.snapshot.Boss then camera.CFrame else nil
	self.bossCamStart = if self.bossCamBase then os.clock() else nil
	self:_scanOccluders()
end

--[[
	디버그전 카메라(2026-09-29 요청): 플레이어 오른쪽 위 뒤에서 등을 보고, 캐릭터를 집어 들면 필드 전체(보통 전투 구도),
	놓으면 새 자리 기준으로 부드럽게 돌아온다. 그 위에 아주 느린 흔들림.
	  BOSS_CAM  Back 뒤로 · Side 오른쪽 · Up 위 · Ahead 바라보는 곳(캐릭터 앞, 보스 쪽) — 스터드. 칸 한 칸은 6 스터드
]]
local BOSS_CAM = { Back = 13, Side = 7, Up = 10, Ahead = 10, Speed = 3 }
function BattleClient:_bossCamera(t: number, dt: number?): CFrame
	local goal = self.bossCamBase :: CFrame
	local me = self.snapshot and self.snapshot.Units and self.snapshot.Units.player
	if not self.grabbed and me and me.X and self.layout then
		local home = self:_home("Ally", me.X, me.Y).Position
		local ahead = self:_home("Enemy", 1, me.Y).Position - self:_home("Ally", 1, me.Y).Position
		local forward = Vector3.new(ahead.X, 0, ahead.Z).Unit
		local right = forward:Cross(Vector3.yAxis)
		local eye = home - forward * BOSS_CAM.Back + right * BOSS_CAM.Side + Vector3.yAxis * BOSS_CAM.Up
		goal = CFrame.lookAt(eye, home + forward * BOSS_CAM.Ahead + Vector3.yAxis * 2)
	end
	-- 지수 감쇠로 부드럽게(처음 한 번은 바로)
	self.bossCamFollow = if self.bossCamFollow and dt then self.bossCamFollow:Lerp(goal, 1 - math.exp(-dt * BOSS_CAM.Speed)) else goal
	local cam = self.bossCamFollow :: CFrame
	local offset = Vector3.new(math.sin(t * 0.31) * 0.4, math.sin(t * 0.23 + 1.3) * 0.25, math.cos(t * 0.27) * 0.3)
	local tilt = CFrame.Angles(math.rad(math.sin(t * 0.19) * 0.4), math.rad(math.cos(t * 0.17) * 0.5), math.rad(math.sin(t * 0.21 + 0.6) * 0.4))
	return (cam + cam:VectorToWorldSpace(offset)) * tilt
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
			if unit.Cells then
				BattleGrid.PlaceBlock(grid, id, unit.Side, unit.Cells)
			else
				BattleGrid.Place(grid, id, unit.Side, unit.X, unit.Y)
			end
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
	local hitIds: { [string]: boolean } = {}
	-- 스냅샷이 오기 전에는 고른 스킬이 없다. 그때는 범위만 안 칠하고 나머지는 그린다.
	if me.Y and skill then
		-- 조건부로 늘어나는 범위(예: 음악가 16분음표)도 실제 판정과 같은 값으로 미리 보여준다.
		local rawStack = (
			skill.GrowResource
			and snapshot.AllyStatus
			and snapshot.AllyStatus.Stacks
			and snapshot.AllyStatus.Stacks[skill.GrowResource]
		) or 0
		local growCount = self:_growCount(skill, rawStack)
		-- 앞뒤관통처럼 모션이 여럿이면(요청: "모션상 단계") 모션마다 덮는 칸을 다 칠한다.
		for _, shape in BattleSkills.AllShapes(skill) do
			for _, cell in BattleSkills.Cells(grid, "Ally", me.Y, shape, growCount, me.X) do
				inRange[cell.X .. "," .. cell.Y] = true
			end
			-- 실제로 맞는 적
			for _, id in BattleSkills.Targets(grid, "Ally", me.Y, shape, growCount, me.X) do
				hitIds[id] = true
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
	-- 보스 디버그 예고: 겨눈 칸을 늘 보여 준다(라인·열을 보고 비켜서는 게 공략이다). 칸 삭제는 따로 칠한다
	local deleting: { [string]: boolean } = {}
	local unavoid: { [string]: boolean } = {}
	--[[
		2026-10-03 사용자: "각 부위별로 어디 부분을 때리는지 색깔을 다르게 해서 다 나누고, 부위 아이콘에서 레이저를 발사".
		부위의 계획(두 번 행동이면 둘 다)마다 공격 범위 묶음 하나 — 색 = 부위 색(EnemyDefinitions), 레이저 = 부위 몸에서 묶음 가운데로.
		묶음 이름은 "부위:계획번호" 라 같은 부위의 두 번째 공격도 따로 보인다.
	]]
	local partRanges: { [string]: { any } } = {}
	local partColor: { [string]: Color3 } = {}
	if snapshot.Boss then
		for _, part in EnemyDefinitions.Get(snapshot.Boss.Id).Parts or {} do
			partColor[part.Key] = part.Color or Color3.fromRGB(255, 150, 40)
		end
	end
	local planSeen: { [string]: number } = {}
	for _, enemyId in snapshot.Planned or {} do
		local unit = snapshot.Units[enemyId]
		planSeen[enemyId] = (planSeen[enemyId] or 0) + 1
		local plan = unit and ((unit.Plans and unit.Plans[planSeen[enemyId]]) or (planSeen[enemyId] == 1 and unit.Plan))
		if unit and unit.Alive and plan then
			local planSkill = BattleSkills.ById(plan.SkillId)
			local damaging = planSkill ~= nil and ((planSkill.Damage or 0) > 0 or planSkill.HpRatio ~= nil) and not plan.Canceled
			if damaging and unit.Part then
				local group = unit.Part .. ":" .. planSeen[enemyId]
				local label = (planSkill :: any).Name .. (if planSkill and planSkill.Unavoidable then " · 회피 불가" elseif planSkill and planSkill.DodgeOnly then " · 회피만" else "")
				for _, c in plan.Cells do
					local key = c[1] .. "," .. c[2]
					partRanges[key] = partRanges[key] or {}
					table.insert(partRanges[key], {
						Group = group,
						Color = partColor[unit.Part] or Color3.fromRGB(255, 150, 40),
						Label = label,
						Unavoid = planSkill ~= nil and planSkill.Unavoidable == true,
						Source = enemyId,
					})
				end
			end
			for _, c in plan.Cells do
				if plan.SkillId == "DeleteCells" then
					deleting[c[1] .. "," .. c[2]] = true
				elseif not damaging then
					continue
				elseif planSkill and planSkill.Unavoidable then
					unavoid[c[1] .. "," .. c[2]] = true
				else
					threatened[c[1] .. "," .. c[2]] = true
				end
			end
		elseif unit and unit.Alive and unit.Y then
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

	--[[
		누가 맞는지 바로 보이게(2026-09-29). 옆 카메라에서 슬라임이 키가 커서 한 줄 위 칸에 선 것처럼 보여,
		"범위보다 한 칸 위를 때린다"는 착각이 났다. 적이 선 칸은 색을 달리하고, 범위 안에 선 적은 몸에 빨간 윤곽.
	]]
	local occupied: { [string]: string } = {}
	for id, unit in snapshot.Units do
		if unit.Side == "Enemy" and unit.Alive and unit.X and unit.Y then
			for _, c in unit.Cells or { { unit.X, unit.Y } } do
				occupied[c[1] .. "," .. c[2]] = id
			end
		end
	end
	if self.director then
		for id, unit in snapshot.Units do
			if unit.Side ~= "Enemy" then
				continue
			end
			local model = self.director:Model(id)
			if not model then
				continue
			end
			local want = unit.Alive and hitIds[id] == true and not self.dragging
			local mark = model:FindFirstChild("TargetMark") :: Highlight?
			if want and not mark then
				local h = Instance.new("Highlight")
				h.Name = "TargetMark"
				h.FillColor = Color3.fromRGB(255, 70, 70)
				-- 보스 부위는 몸이 커서 채우면 온통 빨개진다 — 윤곽 위주로
				h.FillTransparency = if unit.Part then 0.9 else 0.65
				h.OutlineColor = Color3.fromRGB(255, 120, 110)
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = model
				mark = h
			end
			if mark then
				mark.Enabled = want
			end
		end
	end

	-- 2026-10-03 사용자: 보스 디버그 쪽 칸은 아예 없앤다(보이는 것만 — 규칙·칸 차지는 그대로)
	local bossFight = snapshot.Boss ~= nil
	BattleStage.SetSideVisible(self.tiles, "Enemy", not bossFight)
	local modAt: { [string]: string } = {}
	for _, m in (snapshot.Boss and snapshot.Boss.Mods) or {} do
		modAt[m.X .. "," .. m.Y] = m.Kind
	end
	local gone = self.goneCells or {}

	for y = 1, GRID_HEIGHT do
		for x = 1, GRID_WIDTH do
			local ally = self.tiles.Ally[y][x]
			local isMe = me.X == x and me.Y == y
			local hovered = self.dragHover and self.dragHover.X == x and self.dragHover.Y == y
			local cellKey = x .. "," .. y
			local mod = modAt[cellKey]
			-- 검수 칸(검수됨!·검수 준비중)은 칸 글자 대신 덩어리마다 글자 하나 + 칸 위 효과(아래 GroupMarks, 2026-10-02 요청)
			BattleStage.Tag(
				ally,
				if gone[cellKey] or deleting[cellKey] or unavoid[cellKey] then nil
					elseif mod == "Buff" then "▲ 버프"
					elseif mod == "Debuff" then "▼ 버그"
					elseif mod == "Heal" then "✚ 회복"
					else nil,
				if gone[cellKey] then Color3.fromRGB(235, 235, 235)
					elseif deleting[cellKey] then TILE_DELETE
					elseif unavoid[cellKey] then TILE_UNAVOID
					elseif mod == "Buff" then TILE_BUFF
					elseif mod == "Heal" then TILE_HEAL
					else TILE_DEBUFF
			)
			-- 끌고 있을 때도 칸 색(위협·버프·검수…)은 그대로 두고, 놓을 칸만 초록으로 덮는다(2026-09-29 요청)
			if self.dragging and hovered then
				BattleStage.Paint(ally, TILE_DROP, true)
			elseif gone[cellKey] then
				BattleStage.PaintGone(ally)
			elseif isMe and not self.dragging then
				BattleStage.Paint(ally, TILE_ME, true)
			elseif deleting[cellKey] then
				BattleStage.Paint(ally, TILE_DELETE, true)
			elseif unavoid[cellKey] then
				BattleStage.Paint(ally, TILE_UNAVOID, true)
			elseif threatened[cellKey] then
				BattleStage.Paint(ally, TILE_THREAT, true)
			elseif mod then
				BattleStage.Paint(ally, if mod == "Buff" then TILE_BUFF elseif mod == "Heal" then TILE_HEAL else TILE_DEBUFF, true)
			else
				BattleStage.Paint(ally, TILE_IDLE, false)
			end

			local foe = self.tiles.Enemy[y][x]
			local key = x .. "," .. y
			if bossFight then
				-- 보스 쪽 칸은 숨긴다(아래 SetSideVisible). 맞을 부위는 몸 윤곽(TargetMark)으로 보인다
				continue
			elseif inRange[key] then
				BattleStage.Paint(foe, if occupied[key] and hitIds[occupied[key]] then TILE_RANGE_HIT else TILE_RANGE, true)
			else
				BattleStage.Paint(foe, if occupied[key] then TILE_OCCUPIED else TILE_IDLE, occupied[key] ~= nil)
			end
		end
	end
	-- 검수 칸 묶음 표시(덩어리마다 글자 하나 + 칸 위 효과). 같은 묶음이면 다시 짓지 않는다
	BattleStage.GroupMarks(self.tiles, "Pending", deleting)
	BattleStage.GroupMarks(self.tiles, "Gone", gone)
	-- 공격 범위는 따로 한 층(줄무늬 + 굵은 테두리 + 묶음 글자) — 버프·검수 칸 위에서도 묻히지 않게(2026-10-03 요청)
	-- 보스전: 부위마다 색이 다른 범위 + 부위에서 쏘는 레이저 / 보통 적: 주황(공격 범위)·빨강(회피 불가)
	local threatKeys: { [string]: { any } } = {}
	if snapshot.Boss then
		threatKeys = partRanges
	else
		for key in threatened do
			threatKeys[key] = { { Group = "Threat", Color = Color3.fromRGB(255, 150, 40), Label = "공격 범위" } }
		end
		for key in unavoid do
			threatKeys[key] = { { Group = "Unavoid", Color = Color3.fromRGB(255, 30, 40), Label = "회피 불가", Unavoid = true } }
		end
	end
	local director = self.director
	BattleStage.ThreatMarks(self.tiles, threatKeys, function(id: string): BasePart?
		local model = director and director:Model(id)
		return model and model.PrimaryPart
	end)

	--[[
		슬롯·공격 버튼 칠하기. 재사용 대기·카드 잠김·스테미나 부족을 슬롯마다 보여 준다(값만 있고 화면에
		아무 표시가 없으면 "왜 스킬이 안 나가지" 버그처럼 보인다).
	]]
	if self.hud then
		self.hud:Paint({
			Selected = self.selectedSkill,
			Stamina = (self.snapshot and self.snapshot.AllyStamina) or 0,
			Stunned = (self.snapshot and self.snapshot.AllyStunned) == true,
		})
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

--[[
	커서 아래 보스 부위(정보 창, 2026-10-02 사용자: "보스를 클릭하면 부위 포함 모든 스킬 설명").
	부위 몸은 광선에 안 맞으므로(CanQuery 꺼짐 — 칸 드래그 광선이 막히지 않게) 부위마다 몸 상자를 화면에 비춰
	커서를 품은 것 가운데 **가장 작은 상자**를 고른다(앞 부위가 뒤 코어보다 작다). 돌려주는 값: 부위 키(Head·Core …)
]]
function BattleClient:_bossPartUnderCursor(): string?
	local director = self.director
	local camera = workspace.CurrentCamera
	local snapshot = self.snapshot
	if not director or not camera or not (snapshot and snapshot.Boss) then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local best, bestArea = nil, math.huge
	for id, actor in director.Actors do
		local unit = snapshot.Units[id]
		if actor.Kind ~= "Boss" or not unit or not unit.Part or not actor.Model or not actor.Model.Parent then
			continue
		end
		local cf, size = actor.Model:GetBoundingBox()
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		local front = false
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local v, onScreen = camera:WorldToViewportPoint(cf:PointToWorldSpace(size * Vector3.new(sx, sy, sz)))
					front = front or (onScreen and v.Z > 0)
					minX, minY, maxX, maxY = math.min(minX, v.X), math.min(minY, v.Y), math.max(maxX, v.X), math.max(maxY, v.Y)
				end
			end
		end
		local mx, my = mouse.X, mouse.Y
		if front and mx >= minX and mx <= maxX and my >= minY and my <= maxY then
			local area = (maxX - minX) * (maxY - minY)
			if area < bestArea then
				best, bestArea = unit.Part, area
			end
		end
	end
	return best
end

function BattleClient:_bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.active or self.qte then
			return
		end
		-- 보스 정보 창: 부위를 누르면 연다(연출 중에도 — 아군 칸 위를 누른 건 드래그라 빼고),
		-- 열린 채 창 밖을 누르면 닫고 그 누름은 평소대로(드래그) 쓴다
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local part = if self:_tileUnderCursor() then nil else self:_bossPartUnderCursor()
			if part then
				self.hud:ShowBossInfo(self.snapshot, part)
				return
			end
			-- 전투 화면은 IgnoreGuiInset 이라 GUI 자리와 마우스 자리가 같은 기준이다
			if self.hud:IsBossInfoOpen() and not self.hud:IsOverBossInfo(UserInputService:GetMouseLocation()) then
				self.hud:HideBossInfo()
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and self.hud:IsBossInfoOpen() then
			self.hud:HideBossInfo()
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- 연출(스킬·적 공격) 중에는 집어 들지 않는다
			if self.director and self.director:IsBusy() then
				return
			end
			-- 움직일 수 없는 턴이면 집지도 않는다(서버도 거절한다 — 보이는 자리와 판정 자리가 어긋나지 않게)
			local why = self:_moveBlocked()
			if why then
				self.hud:SetLog(why)
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
				-- 내려놓는 연출 중엔 스냅샷 자리를 안 따른다 → 연출이 끝나면 서버 자리로 한 번 더 맞춘다(거절됐으면 제자리로)
				task.delay(0.6, function()
					if self.active then
						self:_renderUnits()
						self:_paintTiles()
					end
				end)
			end
			self:_paintTiles()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not self.active then
			return
		end
		-- 미뤄둔 적 자리 갱신을 연출이 끝나면 적용한다 (스킬·죽음 모션이 끝나야 적이 움직임)
		if self.pendingRender and self.director and not self.director:IsBusy() then
			self.pendingRender = false
			self:_renderUnits()
			self:_paintTiles()
			-- 연출이 끝났으면 보이는 체력을 서버 값에 맞춘다(숫자 나눔 끝수·지속 피해까지)
			self.hud:SetBoss(self:_hpView(self.snapshot))
		end
		if self.dragging then
			-- 칸 사이 틈·중앙선에 커서가 가도 이동이 취소되지 않게, 마지막으로 가리킨 칸을 기억한다
			local over = self:_tileUnderCursor()
			if over then
				self.dragHover = over
			end
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
		if self.bossCamStart and self.bossCamBase then
			local now = os.clock()
			local cf = self:_bossCamera(now - self.bossCamStart, now - (self.bossCamLast or now))
			self.bossCamLast = now
			if now - (self.occludeScan or 0) > 1 then
				self.occludeScan = now
				self:_scanOccluders()
			end
			if self.director then
				self.director:SetCamera(cf)
			else
				workspace.CurrentCamera.CFrame = cf
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
			if not self.active then
				return
			end
			-- 1~6 스킬 고르기, Space 공격(QTE 열기)
			local slot = SLOT_KEYS[input.KeyCode]
			if slot and (self.allySkills or {})[slot] then
				self.selectedSkill = slot
				self:_paintTiles()
			elseif input.KeyCode == Enum.KeyCode.Space then
				self:_tryAttack()
			end
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
	-- 회피 시간(카드·집중·스탯): 방향 회피 입력 시간을 늘린다(최대 +100%)
	local extra = if role == "Dodge" then math.clamp((self.snapshot and self.snapshot.AllyParryWindow) or 0, 0, 1) else 0
	self.qte.DurationMs = math.floor(self.qte.DurationMs * (1 + extra))
	self.qteStart = os.clock()
	local chosen = self:_selectedSkill()
	local classId = self.snapshot and self.snapshot.AllyClassId or "Berserker"
	self.qteWord = if classId == "Duelist" then "패리" else "회피"
	local title = if role == "Skill"
		then (chosen and chosen.Name or "공격")
		else (self.pendingThreat and self.pendingThreat.SkillName or "적의 공격")
	local flag = if role == "Dodge" and self.pendingThreat and self.pendingThreat.DodgeOnly then "가드 불가" else nil
	self.hud:QteOpen(self.qte, role, title, self.qteWord, flag)
end

--[[
	QTE 를 **실제 판정값**(`QteDefinitions.VisualState`)으로 그린다. 종류마다 키가 다르다
	(position/targetPosition, outerRadius/targetRadius, count/goal, expectedDirections …) — BattleHud.QteTick.
]]
function BattleClient:_tickQte()
	local challenge = self.qte
	if not challenge then
		return
	end
	local elapsed = (os.clock() - self.qteStart) * 1000
	self.hud:QteTick(challenge, QteDefinitions.VisualState(challenge, elapsed), elapsed)
	if elapsed >= challenge.DurationMs then
		self:_resolveQte()
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
		self.hud:QteMark(nextIndex, expected[nextIndex] == input)
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
	self.hud:FlashGrade(role, grade, self.qteWord or "회피")
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
			-- 단계 스킬(특이점·붕괴·분쇄·크레셴도 강화): 범위가 몇 단계 켜졌는지로 연출 단계를 고른다(2026-10-03)
			local stage = 1
			local def = BattleSkills.ById(chosen.Id)
			if def and def.GrowResource then
				stage = 1 + self:_growCount(def, (stacks and stacks[def.GrowResource]) or 0)
			end
			self.pendingSkillPlay = self.director:PlaySkill("player", motionId, self:_predictTargets(chosen.Id), nil, stage)
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
	if self.hud then
		self.hud:QteClose()
	end
end

return BattleClient
