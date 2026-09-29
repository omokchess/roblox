--!strict
--[[
	GridBattle — 격자 전투의 **서버 권위 상태 기계**.

	사양 출처: 추가&수정.md `#### 전투 시스템`, `##### 배치 및 전투`

	  "턴제 시스템은 그대로 가지고 감."
	  "카메라 방식을 Brown Dust(1편)의 방식처럼 고정."
	  "싸우는 건 플레이어 본인의 아바타여야 함."
	  "6*3의 격자를 양 진영에 둔다."
	  "공격 위치는 플레이어가 있는 세로 라인으로 정해진다."
	  "탑은 오직 솔로 플레이로만 등반 가능."

	기존 `BattleService`는 파티 3인·행동 선택·업그레이드 방식인데, 사양이
	"현재 전투 방식을 전면 폐기"라고 못박았다. 그래서 새 규칙을 이 모듈에 담는다.

	**연출과 입력이 전혀 없는 순수 로직이다.**
	  - 난수는 전부 인자로 받은 rng를 쓴다 → 같은 씨앗이면 같은 전투가 재현된다
	  - QTE는 '언제 눌렀나'가 아니라 이미 판정된 **등급(Grade)** 만 받는다
	  - 그래서 Studio 없이 PrototypeTests로 전부 검증된다

	클라이언트(`Battle3DController`)는 이 상태를 그리고 입력만 보낸다. 판정은 서버 몫이다.

	한 턴의 흐름 — **적은 한 턴 먼저 예고한다.**
	  0. (전투 시작 / 지난 턴 끝) EnemyPlan(rng)  적이 옮기고 쓸 스킬을 고른다
	  1. 플레이어 이동      MoveAlly()      예고된 라인을 보고 피할 수 있다
	  2. 스킬 선택 → QTE    ResolveSkill(grade)
	  3. 예고된 공격 해소   PlannedThreats() → ResolveDodge(grade)
	  4. 턴 마무리          EndTurn() → 다시 EnemyPlan(rng)

	예고를 따로 둔 이유: 예전에는 적이 **움직이는 것과 때리는 것이 한 순간**이라,
	플레이어가 라인을 보고 비켜설 틈이 없었다. 회피가 QTE 하나로만 갈려서 사양의
	라인 규칙("공격 위치는 플레이어가 있는 세로 라인으로 정해진다")이 사실상 죽어
	있었다. 이제 예고를 보고 라인을 바꾸는 것이 실제 선택이 된다.
]]

local BattleGrid = require(script.Parent.BattleGrid)
local BattleSkillEffects = require(script.Parent.BattleSkillEffects)
local BattleSkills = require(script.Parent.BattleSkills)
local BattleStatus = require(script.Parent.BattleStatus)
local CardEffects = require(script.Parent.CardEffects)
local ClassResources = require(script.Parent.ClassResources)
local EnemyDefinitions = require(script.Parent.EnemyDefinitions)
local GroggyGauge = require(script.Parent.GroggyGauge)
local ProgressionDefinitions = require(script.Parent.ProgressionDefinitions)
local QteDefinitions = require(script.Parent.QteDefinitions)
local TowerDefinitions = require(script.Parent.TowerDefinitions)

export type Outcome = "Ongoing" | "Victory" | "Defeat"

export type Unit = {
	Id: string,
	Name: string,
	Side: BattleGrid.Side,
	Health: number,
	MaxHealth: number,
	Power: number,
	Groggy: GroggyGauge.State,
	--[[
		[도발] 스택. **다른 아군에게 갈 공격을 자기 쪽으로 돌린다.**

		라인은 건드리지 않는다 — 라인을 유도하면 회피가 곧 무력화라 이 게임의
		핵심 선택(어느 라인에 설지)이 통째로 죽는다. 도발은 "누구를 때리는가"만 바꾼다.
	]]
	Taunt: number,
	-- 보호막·지속 피해·직업 자원·기한부 보정값. 자세한 건 `BattleStatus` 참고.
	Status: BattleStatus.State,
	--[[
		신앙심(= md의 "기도력"). 월 필그림스 직업이 이 값으로 버프·디버프를 키운다.
		`상태이상.md`: "기도력은 스탯 신앙심의 오타임."
	]]
	Faith: number,
	--[[
		스테미나. 지금은 **쓰는 곳이 없고 명상이 채우는 자원**이다.

		md와 카드들이 "스테미나 소모"를 자주 말하지만, 스킬에 소모량을 붙이는 것은
		밸런스 결정이라 여기서 임의로 정하지 않았다. 값과 매 턴 회복만 굴려 두고,
		소모를 붙일 때 이 필드를 그대로 쓰면 된다.
	]]
	Stamina: number,
	MaxStamina: number,
	-- 적만 쓴다. 이번 턴에 고른 스킬 번호.
	SkillIndex: number,
	Alive: boolean,
	--[[
		스킬 Id → 남은 재사용 대기 턴. 없거나 0이면 바로 쓸 수 있다(요청:
		"직업 능력 탭에서 액티브 스킬 쿨타임 쓰는 칸이 없어" — md에 "재사용
		대기 N턴"으로 이미 적혀 있던 값인데 `BattleSkills.Skill`에 자리가
		없어 옮길 데가 없었다). `EndTurn`이 매 턴 1씩 줄이고,
		`ResolveSkill`이 쓸 때 `skill.Cooldown`만큼 다시 채운다.
	]]
	Cooldowns: { [string]: number },
}

export type State = {
	Floor: number,
	Grid: BattleGrid.Grid,
	Units: { [string]: Unit },
	AllyId: string,
	--[[
		아군의 직업. 이 값이 스킬 목록을 정한다.

		예전에는 없었고 모두가 같은 5개를 썼다 — 직업을 골라도 전투가 똑같았다.
	]]
	AllyClassId: string,
	Turn: number,
	Outcome: Outcome,
	--[[
		아군이 직전에 쓴 스킬 Id. 펄서 [공명]처럼 "같은 스킬을 이어 쓰는가"를
		보는 효과가 있어서 기억해 둔다.
	]]
	LastSkillId: string,
	--[[
		공격을 **예고해 둔** 적들의 Id.

		`EnemyPlan`이 채우고, 그 공격이 해소되거나 턴이 끝나면 비워진다. 이 목록이
		있어야 "예고했지만 아직 안 때린 적"과 "그로기라 예고조차 못 한 적"을 가릴 수
		있다.
	]]
	Planned: { string },
	--[[
		등반 중 모은 능력 카드. `TowerRun.Cards`를 그대로 받는다.

		전투가 카드를 **직접** 들고 있어야 하는 이유: 카드 효과는 턴마다·처치마다
		발동하는데, 그때마다 프로필을 뒤지면 전투 로직이 저장 구조에 묶인다.
		여기 복사해 두면 GridBattle은 여전히 순수 로직으로 남는다.
	]]
	Cards: { CardEffects.Owned },
	--[[
		이번 턴에 스킬을 썼는지. `행동하지 않고 턴을 마치면` 카드가 이 값을 본다.
		`EndTurn`에서 판정하고 그 자리에서 다시 false로 돌린다.
	]]
	Acted: boolean,
	-- 마지막 판정 기록. UI가 그대로 띄운다.
	Log: { string },
	--[[
		연출용 사건 기록(최근 것만). 누가 무엇을 썼고 누구에게 얼마가 들어갔는지를
		클라이언트 연출(CombatDirector)이 받아 피해 숫자·쓰러짐을 보여 준다.
		Seq 가 늘기만 하므로 클라이언트는 본 적 없는 Seq 만 처리한다.
	]]
	Events: { any },
	EventSeq: number,
	--[[
		디버그 전투 설정(`BattleService` 디버그 패널). 보통 전투에서는 nil 이다.
		  God             아군이 피해를 받지 않는다
		  AllyDamageScale 아군 스킬 피해 배율(1 = 그대로)
		  NoCooldown      스킬 재사용 대기를 걸지 않는다
	]]
	Debug: DebugFlags?,
	-- 카드 실행기(CardEffects 2판). 전투마다 새로 만든다.
	Runtime: any,
	-- 이번 턴에 이동했는지(카드 조건 "이동하지 않고")
	Moved: boolean,
	-- 이번 턴에 **피해 스킬**을 썼는지(카드 조건 "공격하지 않고" — 가드·명상·버프 스킬은 공격이 아니다)
	Attacked: boolean,
	-- 결투사: 손으로 태세를 바꾼 턴(턴당 한 번)
	StanceToggledTurn: number,
	-- 아군 스탯(메인+서브 합: Strength·Intellect·Agility·Vitality·Luck·Faith). 피해·치명·판정 폭에 쓴다.
	AllyStats: { [string]: number },
	-- 카드·치명타용 결정적 난수 상태(같은 씨앗이면 같은 전투)
	RandomState: number,
}

export type DebugFlags = {
	God: boolean?,
	AllyDamageScale: number?,
	NoCooldown: boolean?,
}

--[[
	층 정의 대신 쓰는 적 편성(디버그 전투·필드 만남). 없으면 층 정의(TowerDefinitions)를 따른다.
	  Enemies     적 정의 Id 목록(EnemyDefinitions)
	  HealthScale / PowerScale  체력·공격력 배율
	  Cells       적마다 설 칸 {x, y}(적 진영 좌표). 비었거나 겹치면 기본 배치(라인 돌려 세우기)
]]
export type Encounter = {
	Name: string?,
	Enemies: { string },
	HealthScale: number?,
	PowerScale: number?,
	Cells: { { number } }?,
}

local ALLY_ID = "player"
-- 회피 QTE 를 놓치고 맞을 때마다 차는 아군 그로기(4번이면 다음 턴을 쉰다)
local ALLY_GROGGY_ON_FAIL = 25
-- 적 치명타 기본 확률(배율은 아군과 같은 CRIT_MULTIPLIER)
local ENEMY_CRIT = 0.05

--[[
	카드 실행기에 넘길 도구 묶음을 만드는 함수. **전방 선언**이다 — 회복·피해 함수가 이 파일 아래쪽에
	있어서(Luau 지역 변수는 선언보다 위에서 안 보인다) 이름만 먼저 잡고 본체는 아래에서 채운다.
]]
local makeEnv: (state: State) -> any

-- 치명타: 기본 확률 5%, 기본 배율 150%(키워드 사전 `CritDamage`: "150% + [치명타 피해량]%")
local CRIT_BASE = 0.05
local CRIT_MULTIPLIER = 1.5

-- 카드 훅을 쏜다(CardEffects 2판)
local function fire(state: State, hook: string, ...: any): number
	return CardEffects.Fire(state.Runtime, hook, ...)
end

-- 카드 규칙 질의(음표 상한 + 등)
local function query(state: State, key: string, base: number): number
	return CardEffects.Query(state.Runtime, key, base)
end

-- 결정적 난수(카드·치명타). 선형 합동 — 같은 씨앗이면 같은 수열
-- Park–Miller. 곱이 2^53 안에 머문다(예전 1103515245 곱은 double 정밀도를 넘어 수열이 무너졌다).
local function nextRandom(state: State): number
	state.RandomState = (state.RandomState * 48271) % 2147483647
	return state.RandomState / 2147483647
end

--[[
	자원·상태이상 **앞뒤 비교**로 카드 훅(Gain·Spend·Status·Stance)을 쏜다.

	스킬 효과(BattleSkillEffects)는 스택을 곳곳에서 직접 바꾼다. 그 자리마다 훅을 심는 대신, 엔진 입구
	(전투 시작·이동·스킬·피격·턴 끝)에서 전후를 떠서 달라진 만큼만 알린다 — 어디서 바뀌었든 빠짐이 없다.
]]
-- 적에게 새로 걸리면 `Status` 훅이 도는 것들(광신은 스택이다)
local DOT_KINDS = { "Bleed", "Poison", "Burn", "Oil", "Zeal" }

local function dotTuple(status: any): { number }
	return { status.Bleed, status.Poison, status.Burn, status.Oil, status.Stacks[ClassResources.ZEAL] or 0 }
end

local function watchBegin(state: State): any
	local ally = state.Units[ALLY_ID]
	local dots = {}
	for id, unit in state.Units do
		if unit.Side == "Enemy" then
			dots[id] = dotTuple(unit.Status)
		end
	end
	return { Stacks = if ally then table.clone(ally.Status.Stacks) else {}, Dots = dots }
end

local function watchEnd(state: State, before: any)
	local ally = state.Units[ALLY_ID]
	if not state.Runtime or not ally then
		return
	end
	local after = ally.Status.Stacks
	local seen: { [string]: boolean } = {}
	for id, value in after do
		seen[id] = true
		-- "…Pending" 은 소수 적립용 속 칸이다(자원이 아니다)
		if string.sub(id, -7) ~= "Pending" then
			local old = before.Stacks[id] or 0
			if value > old then
				fire(state, "Gain", id, value - old)
			elseif value < old then
				fire(state, "Spend", id, old - value)
			end
		end
	end
	for id, old in before.Stacks do
		if not seen[id] and old > 0 and string.sub(id, -7) ~= "Pending" then
			fire(state, "Spend", id, old)
		end
	end
	local stanceBefore = (before.Stacks[ClassResources.STANCE_ATTACK] or 0) > 0
	local stanceAfter = (after[ClassResources.STANCE_ATTACK] or 0) > 0
	if stanceBefore ~= stanceAfter then
		fire(state, "Stance", stanceAfter)
	end
	for id, olds in before.Dots do
		local unit = state.Units[id]
		if unit then
			local now = dotTuple(unit.Status)
			for index, kind in DOT_KINDS do
				if now[index] > olds[index] then
					fire(state, "Status", { Target = unit, Kind = kind, Amount = now[index] - olds[index] })
				end
			end
		end
	end
end

local GridBattle = {}

GridBattle.ALLY_ID = ALLY_ID

local function pushEvent(state: State, event: any)
	state.EventSeq += 1
	event.Seq = state.EventSeq
	table.insert(state.Events, event)
	while #state.Events > 8 do
		table.remove(state.Events, 1)
	end
end

local function pushLog(state: State, message: string)
	table.insert(state.Log, message)
	-- 무한히 쌓이면 복제 비용이 커진다. 최근 것만 남긴다.
	while #state.Log > 12 do
		table.remove(state.Log, 1)
	end
end

--[[
	층 하나에 대한 전투를 만든다.

	적은 층 정의(TowerDefinitions)에서 가져오고, 체력·공격력에 층 배율을 곱한다.
	배치는 사양의 6×3 격자다. 적이 여럿이면 라인을 갈라 세워, 라인 회피가 실제로
	의미를 갖게 한다(같은 라인에 몰아 두면 한 번에 쓸린다).
]]
function GridBattle.New(
	floor: number,
	allyName: string,
	allyHealth: number,
	allyPower: number,
	allyClassId: string?,
	allyFaith: number?,
	allyStamina: number?,
	allyCards: { CardEffects.Owned }?,
	encounter: Encounter?,
	allyStats: { [string]: number }?
): State
	local definition = TowerDefinitions.Get(floor)
	local grid = BattleGrid.New()
	local enemyIds = if encounter and #encounter.Enemies > 0 then encounter.Enemies else definition.Enemies
	local healthScale = if encounter and encounter.HealthScale then encounter.HealthScale else definition.HealthScale
	local powerScale = if encounter and encounter.PowerScale then encounter.PowerScale else definition.PowerScale

	local state: State = {
		Floor = definition.Floor,
		Grid = grid,
		Units = {},
		AllyId = ALLY_ID,
		AllyClassId = allyClassId or "Berserker",
		Turn = 1,
		Outcome = "Ongoing",
		LastSkillId = "",
		Planned = {},
		Cards = allyCards or {},
		Acted = false,
		Log = {},
		Events = {},
		EventSeq = 0,
		Runtime = nil,
		Moved = false,
		Attacked = false,
		StanceToggledTurn = 0,
		AllyStats = allyStats or {},
		RandomState = (floor * 7919 + 1) % 2147483648,
	}

	state.Units[ALLY_ID] = {
		Id = ALLY_ID,
		Name = allyName,
		Side = "Ally",
		Health = allyHealth,
		MaxHealth = allyHealth,
		Power = allyPower,
		Groggy = GroggyGauge.New(),
		Taunt = 0,
		Status = BattleStatus.New(),
		Faith = allyFaith or 0,
		Stamina = allyStamina or 60,
		MaxStamina = allyStamina or 60,
		SkillIndex = 1,
		Alive = true,
		Cooldowns = {},
	}
	-- 패시브로 들고 시작하는 자원(음악가 박자표, 연금술사 약재·빈 병 등).
	BattleSkillEffects.ApplyStartingStacks(state.Units[ALLY_ID].Status, state.AllyClassId)
	-- 아군은 전열 가운데 라인에서 시작한다.
	BattleGrid.Place(grid, ALLY_ID, "Ally", 1, 2)

	for index, enemyId in enemyIds do
		local enemy = EnemyDefinitions.Get(enemyId)
		local id = string.format("enemy%d", index)
		local health = math.max(1, math.floor(enemy.MaxHealth * healthScale))
		state.Units[id] = {
			Id = id,
			Name = enemy.Name,
			Side = "Enemy",
			Health = health,
			MaxHealth = health,
			Power = math.max(1, math.floor(enemy.Power * powerScale)),
			Groggy = GroggyGauge.New(),
			Taunt = 0,
			Status = BattleStatus.New(),
			Faith = 0,
			Stamina = 0,
			MaxStamina = 0,
			SkillIndex = 1,
			Alive = true,
			Cooldowns = {},
		}
		-- 라인을 돌려가며 세운다. 1번 적은 가운데, 그다음은 위/아래.
		-- (예전 식은 1번을 맨 위 줄에 세워 주석과 달랐다 — 적이 한 마리면 아군 줄과 어긋났다)
		local slot = (index - 1) % grid.Height
		local middle = math.ceil(grid.Height / 2)
		local lane = math.clamp(middle + (if slot % 2 == 1 then -1 else 1) * math.ceil(slot / 2), 1, grid.Height)
		local column = math.floor((index - 1) / grid.Height) + 1
		-- 편성이 칸을 정해 줬으면 그 칸(비어 있을 때만). 아니면 위의 기본 배치
		local wanted = encounter and encounter.Cells and encounter.Cells[index]
		local placed = wanted ~= nil
			and BattleGrid.Place(grid, id, "Enemy", math.floor(wanted[1]), math.floor(wanted[2]))
		if not placed then
			placed = BattleGrid.Place(grid, id, "Enemy", math.min(column, grid.Width), lane)
		end
		-- 편성 칸과 기본 칸이 겹쳤으면 앞에서부터 빈 칸
		local x = 1
		while not placed and x <= grid.Width do
			for y = 1, grid.Height do
				placed = BattleGrid.Place(grid, id, "Enemy", x, y)
				if placed then
					break
				end
			end
			x += 1
		end
	end

	if encounter then
		pushLog(state, string.format("%s — 적 %d", encounter.Name or "시험 전투", #enemyIds))
	else
		pushLog(state, string.format("%d층 %s — %s", definition.Floor, definition.Name, definition.GimmickName))
	end

	--[[
		카드의 `전투 시작 시` 효과. 적을 세운 **뒤에** 쏜다 — 도발처럼 적이 있어야
		뜻이 있는 것이 있고, 로그도 층 안내 다음에 오는 편이 읽기 좋다.

		이어서 1턴 몫의 `매 턴` 효과도 한 번 쏜다. 이게 없으면 조건부 보정값
		("체력 30% 아래면 피해 +12%")이 1턴에는 통째로 빠진 채 시작한다.
	]]
	state.Runtime = CardEffects.NewRuntime(state, allyCards, makeEnv(state), state.AllyClassId)
	local watch = watchBegin(state)
	local started = fire(state, "BattleStart") + fire(state, "TurnStart", state.Turn)
	watchEnd(state, watch)
	if started > 0 then
		pushLog(state, string.format("능력 카드 %d개 발동", started))
	end
	return state
end

--=== 조회 ===--

function GridBattle.Unit(state: State, id: string): Unit?
	return state.Units[id]
end

function GridBattle.Ally(state: State): Unit
	return state.Units[state.AllyId]
end

function GridBattle.AliveEnemies(state: State): { Unit }
	local alive: { Unit } = {}
	for _, unit in state.Units do
		if unit.Side == "Enemy" and unit.Alive then
			table.insert(alive, unit)
		end
	end
	-- 순서를 고정한다. 해시 순회는 실행마다 달라서 재현이 깨진다.
	table.sort(alive, function(a, b)
		return a.Id < b.Id
	end)
	return alive
end

function GridBattle.CellOf(state: State, id: string): BattleGrid.Cell?
	return BattleGrid.CellOf(state.Grid, id)
end

--[[
	지금 아군이 쓸 수 있는 스킬 목록. **번호의 유일한 기준이다.**

	  1~3  직업 스킬
	  4    강화·연계 (조건이 찼을 때만. 요청: 3번 오른쪽에 따로 생긴다)
	  그 뒤 가드 · 명상 (모든 직업 공용)

	서버와 클라이언트가 같은 함수를 보므로 번호가 어긋나지 않는다. 강화가 열리고
	닫힐 때 가드·명상의 번호가 밀리는데, 그 때문에 `ResolveSkill`은 번호보다
	**Id를 먼저** 믿는다.
]]
function GridBattle.SkillList(state: State): { BattleSkills.Skill }
	local list: { BattleSkills.Skill } = {}
	for _, skill in BattleSkills.ForClass(state.AllyClassId) do
		table.insert(list, skill)
	end

	local upgradeId = BattleSkillEffects.UpgradeFor(state.AllyClassId, GridBattle.Ally(state).Status)
	if upgradeId then
		local upgrade = BattleSkills.ById(upgradeId)
		if upgrade then
			table.insert(list, upgrade)
		end
	end

	for _, skill in BattleSkills.Common() do
		table.insert(list, skill)
	end
	return list
end

--=== 도발 ===--

--[[
	[도발] 상한. 이 값에서 다른 아군에게 갈 공격을 100% 가로챈다.

	카드가 한 번에 1~5씩 주므로 20이면 서너 턴 쌓아야 최대가 된다.
]]
GridBattle.TAUNT_MAX = 20

-- 턴이 끝날 때 빠지는 양.
GridBattle.TAUNT_DECAY = 2

--[[
	도발을 쌓는다. 카드·스킬이 부르는 유일한 진입점이다.

	여기서 상한을 강제하므로, 부르는 쪽이 상한을 몰라도 규격("스택은 반드시 상한이
	있을 것")이 깨지지 않는다.
]]
function GridBattle.AddTaunt(state: State, id: string, amount: number): number
	local unit = state.Units[id]
	if not unit or not unit.Alive then
		return 0
	end
	unit.Taunt = math.clamp(unit.Taunt + math.floor(amount), 0, GridBattle.TAUNT_MAX)
	return unit.Taunt
end

-- 이 유닛이 남의 공격을 가로챌 확률. 0~1.
function GridBattle.TauntChance(state: State, id: string): number
	local unit = state.Units[id]
	if not unit or not unit.Alive then
		return 0
	end
	return math.clamp(unit.Taunt / GridBattle.TAUNT_MAX, 0, 1)
end

--[[
	공격이 실제로 누구에게 갈지 정한다.

	원래 대상이 아닌 아군 중 [도발]이 가장 높은 쪽이 확률로 가로챈다. **라인은 보지
	않는다** — 도발은 대상만 바꾸는 효과다.

	탑은 솔로라 지금은 아군이 하나뿐이고, 그때는 원래 대상을 그대로 돌려준다.
	파티가 붙으면 이 함수 하나만 거치면 도발이 그대로 동작한다.
]]
function GridBattle.RedirectTarget(state: State, intendedId: string, rng: () -> number): string
	local intended = state.Units[intendedId]
	if not intended or intended.Side ~= "Ally" then
		return intendedId
	end

	local best: Unit? = nil
	for _, unit in state.Units do
		if unit.Side == "Ally" and unit.Alive and unit.Id ~= intendedId and unit.Taunt > 0 then
			-- 동점이면 Id 순으로 고른다. 해시 순회는 실행마다 달라서 재현이 깨진다.
			if not best or unit.Taunt > best.Taunt or (unit.Taunt == best.Taunt and unit.Id < best.Id) then
				best = unit
			end
		end
	end

	if not best then
		return intendedId
	end
	if rng() < GridBattle.TauntChance(state, best.Id) then
		pushLog(state, string.format("%s 도발 — 공격을 대신 받는다", best.Name))
		return best.Id
	end
	return intendedId
end

--=== 태세 (결투사) ===--

--[[
	결투사의 태세 전환. 턴마다 한 번, **행동을 쓰지 않는다**(설계 문서: "필요하면 공격 태세로, 버텨야 하면
	방어 태세로 바꿔 가며 싸운다" — 전환 자체는 자원을 쓰지 않는다).
	철벽(공격 태세 없음)·광검(방어 태세 없음)·양날(매 턴 강제 전환)이면 손으로 못 바꾼다(`StanceLocked` 질의).
]]
function GridBattle.ToggleStance(state: State): (boolean, string?)
	if state.Outcome ~= "Ongoing" or state.AllyClassId ~= "Duelist" then
		return false, "태세가 없는 직업입니다."
	end
	if query(state, "StanceLocked", 0) >= 1 then
		return false, "필수 카드가 태세를 정해 두었습니다."
	end
	if state.StanceToggledTurn == state.Turn then
		return false, "이번 턴에는 이미 태세를 바꿨습니다."
	end
	local ally = GridBattle.Ally(state)
	local watch = watchBegin(state)
	local attack = BattleStatus.Stack(ally.Status, ClassResources.STANCE_ATTACK) <= 0
	BattleSkillEffects.SetStance(ally.Status, attack)
	state.StanceToggledTurn = state.Turn
	pushLog(state, if attack then "공격 태세로 바꿨다" else "방어 태세로 바꿨다")
	watchEnd(state, watch)
	return true, nil
end

--=== 이동 ===--

--[[
	아군을 자기 진영 안에서 옮긴다(사양: "매 턴마다 해당 격자 내에서 움직이며").
	진영을 넘어가는 이동은 BattleGrid.Move가 막는다.
]]
function GridBattle.MoveAlly(state: State, x: number, y: number): (boolean, string?)
	if state.Outcome ~= "Ongoing" then
		return false, "전투가 끝났습니다."
	end
	local ally = GridBattle.Ally(state)
	if GroggyGauge.IsStunned(ally.Groggy) then
		return false, "그로기 상태에서는 움직일 수 없습니다."
	end
	local from = BattleGrid.CellOf(state.Grid, state.AllyId)
	local ok, reason = BattleGrid.Move(state.Grid, state.AllyId, x, y)
	if ok and from and (from.X ~= x or from.Y ~= y) then
		state.Moved = true
		local watch = watchBegin(state)
		fire(state, "Move", { FromX = from.X, FromY = from.Y, ToX = x, ToY = y })
		watchEnd(state, watch)
	end
	return ok, reason
end

--=== 대미지 ===--

--[[
	피해를 넣는다. 순서가 중요하다.

	  1. 받는 피해 보정 (+기름이면 화염 피해 50% 증가)
	  2. 보호막 흡수 — `상태이상.md`: "(보호막 수치)만큼 추가 HP를 얻는다"
	  3. 남은 만큼 체력 차감

	canKill이 false면 체력 1에서 멈춘다. `상태이상.md`가 출혈·독·화상에 대해
	"이 효과로 사망할 수 없다"고 못박았고, 연금술사 자해도 같은 규칙을 쓴다.
]]
local function damageUnit(
	state: State,
	unit: Unit,
	amount: number,
	element: BattleStatus.Element?,
	canKill: boolean?
): number
	local kind: BattleStatus.Element = element or "Physical"
	local scaled = BattleStatus.IncomingDamage(unit.Status, amount, kind)
	if state.Debug and state.Debug.God and unit.Side == "Ally" then
		scaled = 0
	end
	local absorbed, remaining = BattleStatus.Absorb(unit.Status, scaled)
	if absorbed > 0 then
		pushLog(state, string.format("%s 보호막이 %d 막았다", unit.Name, math.floor(absorbed)))
	end

	local dealt = math.max(0, math.floor(remaining))
	local floorHealth = if canKill == false then 1 else 0
	unit.Health = math.max(floorHealth, unit.Health - dealt)
	--[[
		아군이 쓰러지기 직전 — 카드(재기·불굴)가 막을 수 있다. Cancel 이면 Health 로 버틴다.
	]]
	if unit.Id == ALLY_ID and unit.Health <= 0 and unit.Alive then
		local save = { Cancel = false, Health = 1 }
		fire(state, "Lethal", save)
		if save.Cancel then
			unit.Health = math.clamp(math.floor(save.Health), 1, unit.MaxHealth)
		end
	end

	--[[
		카드의 `피해를 받으면` 효과. 격노처럼 맞을 때마다 자원을 버는 카드가 쓴다.
		실제로 체력이 깎였을 때만 — 보호막이 전부 막았으면 맞은 것이 아니다.
	]]
	if unit.Id == ALLY_ID and dealt > 0 and unit.Alive then
		fire(state, "Damaged", { Amount = dealt, Element = kind })
	end

	if unit.Health <= 0 and unit.Alive then
		unit.Alive = false
		BattleGrid.Remove(state.Grid, unit.Id)
		pushLog(state, string.format("%s 쓰러짐", unit.Name))
		-- 카드의 `적을 처치하면` 효과.
		if unit.Side == "Enemy" then
			fire(state, "Kill", { Target = unit })
		end
	end
	return dealt
end

local function healUnit(unit: Unit, amount: number): number
	local scaled = amount * (1 + BattleStatus.Total(unit.Status, "HealTaken"))
	local before = unit.Health
	unit.Health = math.min(unit.MaxHealth, unit.Health + math.floor(scaled))
	return unit.Health - before
end

-- 회복하고, 아군이 실제로 회복했으면 카드 훅(Healed)을 쏜다
local function heal(state: State, unit: Unit, amount: number): number
	local gained = healUnit(unit, amount)
	if gained > 0 and unit.Id == ALLY_ID then
		fire(state, "Healed", { Amount = gained })
	end
	return gained
end

--[[
	자원을 준다(직업 규칙대로). 음표는 박자표 상한(+카드가 늘린 만큼)에서, 나머지는 자원 상한(+카드)에서 멈춘다.
]]
local function gainResource(state: State, unit: Unit, id: string, amount: number): number
	if amount <= 0 then
		return 0
	end
	amount = amount * query(state, id .. "Gain", 1)
	local status = unit.Status
	if table.find(ClassResources.NOTE_IDS, id) then
		local meter = math.max(1, BattleStatus.Stack(status, ClassResources.METER))
		local cap = ClassResources.NoteCap(meter) + query(state, "NoteCapBonus", 0)
		local total = 0
		for _, noteId in ClassResources.NOTE_IDS do
			total += BattleStatus.Stack(status, noteId)
		end
		local room = math.max(0, cap - total)
		local gained = math.min(math.floor(amount), room)
		if gained > 0 then
			BattleStatus.AddStack(status, id, gained)
		end
		return gained
	end
	local cap = ClassResources.Cap(id)
	if cap then
		cap = query(state, id .. "Cap", cap)
	end
	local before = BattleStatus.Stack(status, id)
	BattleStatus.AddStack(status, id, math.floor(amount), cap)
	return BattleStatus.Stack(status, id) - before
end

makeEnv = function(state: State): any
	return {
		Ally = function()
			return state.Units[ALLY_ID]
		end,
		Allies = function()
			return GridBattle.Allies(state)
		end,
		Enemies = function()
			return GridBattle.AliveEnemies(state)
		end,
		Gain = function(id: string, amount: number): number
			return gainResource(state, state.Units[ALLY_ID], id, amount)
		end,
		Heal = function(unit: Unit, amount: number): number
			return heal(state, unit, amount)
		end,
		Damage = function(unit: Unit, amount: number, element: BattleStatus.Element?, canKill: boolean?): number
			return damageUnit(state, unit, amount, element, canKill)
		end,
		Log = function(message: string)
			pushLog(state, message)
		end,
		Rng = function(): number
			return nextRandom(state)
		end,
		CellOf = function(id: string)
			return BattleGrid.CellOf(state.Grid, id)
		end,
		Threatened = function(): boolean
			return #GridBattle.PlannedThreats(state) > 0
		end,
		-- 적을 끌어당긴다(중력). ids 가 있으면 그 적만
		Pull = function(columns: number, ids: { [string]: boolean }?): number
			return GridBattle.PullEnemies(state, columns, ids)
		end,
	}
end

GridBattle.GainResource = gainResource

-- 아군 전체(솔로면 자기 하나). "아군 전체" 효과가 도는 목록이다.
function GridBattle.Allies(state: State): { Unit }
	local list: { Unit } = {}
	for _, unit in state.Units do
		if unit.Side == "Ally" and unit.Alive then
			table.insert(list, unit)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

local function refreshOutcome(state: State)
	if state.Outcome ~= "Ongoing" then
		return
	end
	if not GridBattle.Ally(state).Alive then
		state.Outcome = "Defeat"
		pushLog(state, "패배")
		return
	end
	if #GridBattle.AliveEnemies(state) == 0 then
		state.Outcome = "Victory"
		pushLog(state, "층 클리어")
	end
end

--[[
	[디버그] 유닛 체력을 바로 정한다. 0 이면 쓰러뜨리고(처치 카드 훅이 돈다) 승패를 다시 본다.
	`BattleService` 디버그 명령(즉시 승리·패배·처치·회복)만 쓴다.
]]
function GridBattle.DebugSetHealth(state: State, unitId: string, value: number)
	local unit = state.Units[unitId]
	if not unit or not unit.Alive then
		return
	end
	local target = math.clamp(math.floor(value), 0, unit.MaxHealth)
	if target <= 0 then
		unit.Health = 0
		unit.Alive = false
		BattleGrid.Remove(state.Grid, unit.Id)
		pushLog(state, string.format("[디버그] %s 쓰러짐", unit.Name))
		if unit.Side == "Enemy" then
			fire(state, "Kill", { Target = unit })
		end
	else
		unit.Health = target
	end
	refreshOutcome(state)
end

--=== 아군 공격 ===--

--[[
	아군이 스킬을 쓴다. QTE **등급만** 받는다 — 언제 눌렀는지는 클라이언트가 판정해
	보내는 것이 아니라, 서버가 만든 챌린지에 대한 결과를 받는 구조다.

	사양: 공격 라인은 아군이 선 세로 라인이다. 마우스 조준이 없다.
]]
--[[
	rng는 연금술사 `섞기`처럼 결과가 갈리는 효과에만 쓴다. 넘기지 않으면 0.5로
	고정돼 결정적으로 동작한다 — 기존 테스트가 그대로 통과하도록 두려는 것이다.
]]
function GridBattle.ResolveSkill(
	state: State,
	skillIndex: any,
	grade: QteDefinitions.Grade,
	rng: (() -> number)?,
	skillId: string?
): (boolean, string?)
	if state.Outcome ~= "Ongoing" then
		return false, "전투가 끝났습니다."
	end
	local ally = GridBattle.Ally(state)
	if GroggyGauge.IsStunned(ally.Groggy) then
		return false, "그로기 상태입니다."
	end
	local cell = BattleGrid.CellOf(state.Grid, state.AllyId)
	if not cell then
		return false, "격자에 없습니다."
	end

	--[[
		쓸 수 있는 목록에서 고른다. 강화가 열려 있으면 4번이 그 자리다.

		**skillId가 오면 그것을 먼저 믿는다.** 강화가 열리고 닫힐 때 가드·명상의
		번호가 한 칸씩 밀리는데, 그 사이에 도착한 요청이 번호만 보고 엉뚱한 스킬을
		쏘면 안 된다. 물론 목록에 없는 Id는 무시한다(클라이언트를 그대로 믿지 않는다).
	]]
	local allySkills = GridBattle.SkillList(state)
	local skill = BattleSkills.ByIndex(allySkills, skillIndex)
	if type(skillId) == "string" then
		for _, candidate in allySkills do
			if candidate.Id == skillId then
				skill = candidate
				break
			end
		end
	end
	for index, candidate in allySkills do
		if candidate.Id == skill.Id then
			ally.SkillIndex = index
			break
		end
	end

	-- 재사용 대기 중이면 아예 못 쓴다. 여기서 막아야 그 뒤의 자원 소모·공명 처리도 같이 막힌다.
	local cooldownLeft = ally.Cooldowns[skill.Id] or 0
	if cooldownLeft > 0 then
		return false,
			string.format("%s은(는) 아직 재사용 대기 중입니다 (%d턴 남음).", skill.Name, cooldownLeft)
	end

	--[[
		스테미나(사양 `##### 플레이어`: 1레벨 60, 매 턴 8 회복). 직업 스킬 1·2·3번이 10·15·20, 강화·연계 25,
		가드·명상은 0(명상은 30 채운다). 카드가 배율을 바꾼다(`StaminaCost` 질의).
	]]
	-- 철벽처럼 공격 스킬을 막는 카드
	if skill.Damage > 0 and query(state, "NoAttackSkills", 0) >= 1 then
		return false, "필수 카드 때문에 공격 스킬을 쓸 수 없습니다."
	end

	local staminaCost = GridBattle.StaminaCost(state, skill)
	if ally.Stamina < staminaCost and not (state.Debug and state.Debug.NoCooldown) then
		return false, string.format("스테미나가 부족합니다 (%d/%d).", math.floor(ally.Stamina), staminaCost)
	end

	-- 펄서 [공명]은 자기권·섬광이 쌓고 수렴이 쓴다. 턴마다 줄어드는 것은 펄서 키트(CardEffects/Pulsar)가 한다.
	state.LastSkillId = skill.Id
	-- 스킬을 썼다. `행동하지 않고 턴을 마치면` 카드가 이번 턴에는 발동하지 않는다.
	state.Acted = true
	if not (state.Debug and state.Debug.NoCooldown) then
		ally.Stamina = math.max(0, ally.Stamina - staminaCost)
	end
	if skill.Damage > 0 then
		state.Attacked = true
	end
	local watch = watchBegin(state)
	if skill.Cooldown and skill.Cooldown > 0 and not (state.Debug and state.Debug.NoCooldown) then
		ally.Cooldowns[skill.Id] = skill.Cooldown
	end

	local multiplier = QteDefinitions.Multiplier("Skill", grade)
	local growCount = skill.GrowResource
			and BattleSkills.GrowCount(skill, BattleStatus.Stack(ally.Status, skill.GrowResource))
		or 0
	growCount = math.floor(query(state, skill.Id .. "Grow", growCount))

	--[[
		앞뒤관통처럼 모션이 여럿이면(요청: "모션상 단계") 모션마다 범위를 따로
		구한다 — 같은 칸이라도 모션마다 겹칠 수 있어(예: 두 모션이 같은 대상을
		또 때리는 경우) 목록을 모션별로 나눠 들고 있는다. 상태이상 효과
		(`context.Targets`)는 "누구를 맞췄는가"만 보면 되므로 합집합 한 번이면
		되고, 피해는 모션마다 따로 준다(아래 2단계).
	]]
	local motionHitUnits: { { Unit } } = {}
	local hitUnits: { Unit } = {}
	local seenUnit: { [string]: boolean } = {}
	for _, shape in BattleSkills.AllShapes(skill) do
		local targets = BattleSkills.Targets(state.Grid, "Ally", cell.Y, shape, growCount, cell.X)
		local aliveHits: { Unit } = {}
		for _, targetId in targets do
			local target = state.Units[targetId]
			if target and target.Alive then
				table.insert(aliveHits, target)
				if not seenUnit[targetId] then
					seenUnit[targetId] = true
					table.insert(hitUnits, target)
				end
			end
		end
		table.insert(motionHitUnits, aliveHits)
	end

	local context: BattleSkillEffects.Context = {
		Ally = ally,
		Status = ally.Status,
		Targets = hitUnits,
		Allies = { ally },
		Grade = grade,
		Rng = rng or function()
			return 0.5
		end,
		StatusOf = function(unit)
			return unit.Status
		end,
		Damage = function(unit, amount, element, canKill)
			return damageUnit(state, unit, amount, element, canKill)
		end,
		Heal = function(unit, amount)
			return heal(state, unit, amount)
		end,
		RestoreStamina = function(amount)
			local before = ally.Stamina
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(amount))
			return ally.Stamina - before
		end,
		Log = function(message)
			pushLog(state, message)
		end,
		PullEnemies = function(columns)
			return GridBattle.PullEnemies(state, columns)
		end,
		-- 직업 규칙대로 자원을 준다(음표 상한·카드가 늘린 상한). 실제로 얹힌 양
		Gain = function(id, amount)
			return gainResource(state, ally, id, amount)
		end,
		-- 카드 규칙 질의(음표 획득량 +, 브릴란테 지속 + …)
		Query = function(key, base)
			return query(state, key, base)
		end,
		-- 살아 있는 적 전부(열화된 초신성 — 섬광이 적 전체)
		Enemies = function()
			return GridBattle.AliveEnemies(state)
		end,
	}

	local effect = BattleSkillEffects.Get(skill.Id)

	-- 카드: 스킬 직전(주는 피해 +비율·치명 +확률·치명 피해·기본 피해 +)
	-- Bonus 는 더하는 비율, Mult 는 곱하는 배율(반주자 "기본 피해량 60% 감소" 같은 것)
	local info = { Skill = skill, Targets = hitUnits, Grade = grade, Bonus = 0, Mult = 1, Crit = 0, CritDamage = 0, Flat = 0 }
	fire(state, "BeforeSkill", info)

	-- 1) 피해 계산 전. 자원을 쓰고 배율을 받는다.
	local skillBonus = 1
	if effect and effect.Before then
		skillBonus = effect.Before(context)
	end

	--[[
		2) 피해. 주는 피해 보정(태세·허물 벽·다지기…)을 함께 먹인다.

		**피해 0인 스킬은 때리지 않는다.** 예전에는 `ally.Power + skill.Damage`가
		0보다 크면 무조건 때렸는데, 무기 공격력이 얹히니 브릴란테·자기권·축성 같은
		버프 스킬이 20 넘는 피해를 주고 적을 죽이기까지 했다.
		skillBonus가 0인 것(붕괴 차징)도 같이 걸러진다.
	]]
	local total = 0
	local hitCount = 0
	-- 연출용: 모양(모션) 묶음마다 누구에게 얼마가 들어갔는지
	local eventHits: { { any } } = {}
	for index in motionHitUnits do
		eventHits[index] = {}
	end
	local crits = 0
	if skill.Damage > 0 and skillBonus > 0 then
		--[[
			스탯(사양 `### 스탯`): 근거리는 힘 5%·민첩 3%, 원거리는 지력 7% 가 피해에 붙는다.
			치명타: 기본 5% + 운 0.7%/점 + 보정. 배율 150% + 운 1.2%/점 + 보정. 100% 넘는 확률은 배율로 넘긴다.
		]]
		local stats = state.AllyStats
		local statBonus = if skill.Range == "Ranged"
			then (stats.Intellect or 0) * 0.07
			else (stats.Strength or 0) * 0.05 + (stats.Agility or 0) * 0.03
		local base = BattleStatus.OutgoingDamage(ally.Status, (ally.Power + skill.Damage + info.Flat) * multiplier * skillBonus)
			* math.max(0, 1 + info.Bonus + statBonus)
			* math.max(0, info.Mult)
		if state.Debug and state.Debug.AllyDamageScale then
			base *= state.Debug.AllyDamageScale
		end
		local critChance = CRIT_BASE + BattleStatus.Total(ally.Status, "CritChance") + info.Crit + (stats.Luck or 0) * 0.007
		local critMultiplier = CRIT_MULTIPLIER
			+ BattleStatus.Total(ally.Status, "CritDamage")
			+ info.CritDamage
			+ (stats.Luck or 0) * 0.012
		if critChance > 1 then
			critMultiplier += critChance - 1
			critChance = 1
		end
		--[[
			모션마다 `base`만큼 **따로** 입힌다(요청: "모션마다 따로 대미지") —
			앞뒤관통의 "9 × 2(합 18)"처럼, `skill.Damage`는 모션 하나의 몫이다.
			같은 대상이 두 모션에 다 걸리면 두 번 맞는다(앞 모션에 쓰러졌으면 건너뛴다).
		]]
		for index, aliveHits in motionHitUnits do
			for _, target in aliveHits do
				if not target.Alive then
					continue
				end
				local hitInfo = { Target = target, Skill = skill, Bonus = 0 }
				fire(state, "BeforeHit", hitInfo)
				local amount = base * math.max(0, 1 + hitInfo.Bonus)
				local roll = if rng then rng() else nextRandom(state)
				local crit = roll < critChance
				if crit then
					amount *= critMultiplier
					crits += 1
				end
				local dealt = damageUnit(state, target, amount, "Physical", true)
				total += dealt
				table.insert(eventHits[index], { Id = target.Id, Damage = dealt, Crit = crit })
				hitCount += 1
				-- 맞으면 그로기가 찬다. 패리만큼은 아니지만 누적되면 스턴이 난다.
				GroggyGauge.AddFrom(target.Groggy, "Hit")
				fire(state, "Hit", { Target = target, Damage = dealt, Crit = crit, Skill = skill })
			end
		end
		pushLog(state, string.format("%s ×%.1f — %d명에게 %d 피해", skill.Name, multiplier, hitCount, total))
	else
		-- 피해가 없는 스킬(버프·자원)이다. 대상이 없어도 효과는 나간다.
		pushLog(state, skill.Name)
	end

	-- 3) 피해 계산 후. 자원을 얻고 상태이상을 건다. (종베기처럼 최종 피해를 보는 효과가 있다)
	context.TotalDealt = total
	context.HitCount = hitCount
	if effect and effect.After then
		effect.After(context)
	end

	local kills = 0
	for _, target in hitUnits do
		if not target.Alive then
			kills += 1
		end
	end
	fire(state, "AfterSkill", { Skill = skill, Hits = eventHits, Kills = kills, Grade = grade, Crits = crits, Total = total })

	for _, list in eventHits do
		for _, hit in list do
			local unit = state.Units[hit.Id]
			hit.Killed = unit ~= nil and not unit.Alive
		end
	end
	pushEvent(state, {
		Kind = "Skill",
		Actor = ally.Id,
		SkillId = skill.Id,
		Grade = grade,
		Hits = eventHits,
	})

	watchEnd(state, watch)
	refreshOutcome(state)
	return true, nil
end

--[[
	이 스킬 한 번의 스테미나. 직업 스킬 1·2·3번 10·15·20, 강화·연계 25, 가드·명상 0.
	스킬 표에 `Stamina` 가 있으면 그것. 카드가 `StaminaCost` 질의로 고친다(반올림).
]]
function GridBattle.StaminaCost(state: State, skill: BattleSkills.Skill): number
	local base = (skill :: any).Stamina
	if base == nil then
		base = 0
		for index, candidate in BattleSkills.ForClass(state.AllyClassId) do
			if candidate.Id == skill.Id then
				base = ({ 10, 15, 20 })[index] or 20
			end
		end
		for _, candidate in BattleSkills.Upgrades() do
			if candidate.Id == skill.Id then
				base = 25
			end
		end
	end
	-- 모든 스킬(StaminaCost) → 이 스킬만(<Id>StaminaCost, 궤도처럼 한 스킬을 보는 카드) 순서로 고친다
	local cost = query(state, "StaminaCost", base)
	cost = query(state, skill.Id .. "StaminaCost", cost)
	return math.max(0, math.floor(cost + 0.5))
end

--[[
	적을 아군 쪽으로 끌어당긴다(퀘이사 붕괴). 실제로 옮겨진 수를 돌려준다.

	x가 작을수록 중앙선에 가깝다(BattleArena 주석). 그래서 x를 1씩 줄이면 끌려온다.
]]
function GridBattle.PullEnemies(state: State, columns: number, ids: { [string]: boolean }?): number
	local moved = 0
	for _, enemy in GridBattle.AliveEnemies(state) do
		local cell = BattleGrid.CellOf(state.Grid, enemy.Id)
		if cell and cell.X > 1 and columns > 0 and (ids == nil or ids[enemy.Id]) then
			local goal = math.max(1, cell.X - columns)
			if BattleGrid.Move(state.Grid, enemy.Id, goal, cell.Y) then
				moved += 1
			end
		end
	end
	return moved
end

--=== 적 턴 ===--

--[[
	적이 움직이고 **다음에 쓸 스킬을 예고한다.** 아직 때리지는 않는다.

	사양: "매 턴마다 해당 격자 내에서 움직이며". 매 턴 자리와 스킬이 바뀌어야
	라인 회피가 살아 있는 선택이 된다.

	이 함수가 플레이어 행동 **전에** 돌아야 한다. 예고를 보고 라인을 비켜서는 것이
	이 전투의 핵심 선택이기 때문이다.

	rng는 인자로 받는다 — 서버가 씨앗을 쥐고 있어야 재현·검증이 된다.
]]
function GridBattle.EnemyPlan(state: State, rng: () -> number): { Unit }
	local planned: { Unit } = {}
	state.Planned = {}
	if state.Outcome ~= "Ongoing" then
		return planned
	end

	for _, enemy in GridBattle.AliveEnemies(state) do
		if GroggyGauge.IsStunned(enemy.Groggy) then
			pushLog(state, string.format("%s 그로기 — 행동 불가", enemy.Name))
		else
			-- 빈 칸을 찾을 때까지 몇 번만 시도한다. 격자가 꽉 찰 일이 없어 금방 끝난다.
			-- [도발]은 여기에 개입하지 않는다. 라인 선택은 순수하게 유지한다.
			-- [중력]에 걸린 적은 앞 두 열(조석력이면 더 앞)에서만 움직인다
			local width = state.Grid.Width
			if BattleSkillEffects.HasGravity(enemy.Status) then
				width = math.clamp(math.floor(query(state, "GravityColumns", 2)), 1, width)
			end
			for _ = 1, 8 do
				local x = math.floor(rng() * width) + 1
				local y = math.floor(rng() * state.Grid.Height) + 1
				if BattleGrid.Move(state.Grid, enemy.Id, x, y) then
					break
				end
			end
			enemy.SkillIndex = math.floor(rng() * #BattleSkills.Enemy()) + 1
			table.insert(planned, enemy)
			table.insert(state.Planned, enemy.Id)
		end
	end
	return planned
end

--[[
	예고해 둔 공격 중 **지금 아군에게 닿는 것**만 골라낸다.

	플레이어가 이동한 **뒤에** 부른다. 예고된 라인에서 비켜섰으면 그 공격은
	여기서 빠진다 — 그게 위치로 피한다는 뜻이다.
]]
function GridBattle.PlannedThreats(state: State): { Unit }
	local threats: { Unit } = {}
	if state.Outcome ~= "Ongoing" then
		return threats
	end
	for _, enemyId in state.Planned do
		local enemy = state.Units[enemyId]
		if enemy and enemy.Alive and GridBattle.EnemyThreatensAlly(state, enemy) then
			table.insert(threats, enemy)
		end
	end
	return threats
end

--[[
	적 하나의 공격이 아군에게 닿는지. 닿으면 회피/패리 QTE를 띄울 차례다.
	사양의 라인 규칙을 그대로 쓰므로, 아군이 다른 라인에 있으면 그냥 빗나간다.
]]
function GridBattle.EnemyThreatensAlly(state: State, enemy: Unit): boolean
	local cell = BattleGrid.CellOf(state.Grid, enemy.Id)
	if not cell then
		return false
	end
	local skill = BattleSkills.ByIndex(BattleSkills.Enemy(), enemy.SkillIndex)
	local growCount = skill.GrowResource
			and BattleSkills.GrowCount(skill, BattleStatus.Stack(enemy.Status, skill.GrowResource))
		or 0
	-- 모션이 여럿이면 그중 하나라도 나를 걸면 위협이다.
	for _, shape in BattleSkills.AllShapes(skill) do
		for _, targetId in BattleSkills.Targets(state.Grid, "Enemy", cell.Y, shape, growCount, cell.X) do
			if targetId == state.AllyId then
				return true
			end
		end
	end
	return false
end

--[[
	적 공격에 대한 회피/패리 결과를 적용한다.

	사양: 패리 성공 시 상대 그로기가 오른다(QteDefinitions.PARRY_GROGGY_GAIN).
	Dodge 배율은 Success 0 / Partial 0.5 / Fail 1.0 — 즉 성공하면 아예 안 맞는다.
]]
function GridBattle.ResolveDodge(state: State, enemyId: string, grade: QteDefinitions.Grade): (boolean, string?)
	if state.Outcome ~= "Ongoing" then
		return false, "전투가 끝났습니다."
	end
	local enemy = state.Units[enemyId]
	if not enemy or not enemy.Alive or enemy.Side ~= "Enemy" then
		return false, "그런 적이 없습니다."
	end

	local ally = GridBattle.Ally(state)
	local skill = BattleSkills.ByIndex(BattleSkills.Enemy(), enemy.SkillIndex)
	local watch = watchBegin(state)
	--[[
		카드: 맞기 직전(배율·자동 패링 확률). 자동 패링은 QTE 를 못 막았을 때 확률로 패링으로 바꾼다
		(보정값 `AutoParry` + 카드). 궁극기·패링 불가 공격은 아직 적에게 없다.
	]]
	local before = {
		Attacker = enemy,
		Grade = grade,
		Mult = 1,
		AutoParry = BattleStatus.Total(ally.Status, "AutoParry"),
		-- 적 치명타: 기본 5% · 150%. 카드가 끈다(Crit = 0)거나 배율을 깎는다.
		Crit = ENEMY_CRIT + BattleStatus.Total(enemy.Status, "CritChance"),
		CritMult = CRIT_MULTIPLIER,
	}
	fire(state, "BeforeTaken", before)
	grade = before.Grade
	local autoParried = before.Auto == true and grade == "Success"
	if grade ~= "Success" and before.AutoParry > 0 and nextRandom(state) < before.AutoParry then
		grade = "Success"
		autoParried = true
		pushLog(state, "자동 패링")
	end
	local multiplier = QteDefinitions.Multiplier("Dodge", grade) * math.max(0, before.Mult)
	if grade ~= "Success" and multiplier > 0 and before.Crit > 0 and nextRandom(state) < before.Crit then
		multiplier *= math.max(1, before.CritMult)
		pushLog(state, enemy.Name .. " 치명타")
	end
	-- 적에게 걸린 주는 피해 보정(광신·섬광·중력)을 먹인다.
	local incoming = BattleStatus.OutgoingDamage(enemy.Status, (enemy.Power + skill.Damage) * multiplier)
	local taken = damageUnit(state, ally, incoming, "Physical", true)

	--[[
		실제로 맞았으면 반사가 나간다(펄서 자기권).
		`Reflect`는 비율이 아니라 절대값이고, [자기장]이 걸린 동안만 붙어 있다.
	]]
	local reflected = 0
	if taken > 0 then
		-- 카드가 반사량을 고친다(정지장 +50%, 정지 궤도 ×2 …)
		local reflect = query(state, "ReflectAmount", BattleStatus.Total(ally.Status, "Reflect"))
		if reflect > 0 then
			local dealt = damageUnit(state, enemy, reflect, "Physical", true)
			reflected = dealt
			-- 자기권은 반사와 함께 [감극]도 건다.
			local stacks = BattleSkillEffects.ApplyDepolar(
				enemy.Status,
				1,
				math.floor(query(state, "DepolarTurns", 2)),
				query(state, "DepolarPer", 0.15)
			)
			pushLog(
				state,
				string.format("자기장 반사 — %s에게 %d 피해, 감극 %d", enemy.Name, dealt, stacks)
			)
			fire(state, "Reflected", { Target = enemy, Damage = dealt })
		end
	end

	if grade == "Success" then
		-- 완전 회피 = 패리로 본다. 상대 그로기를 채운다(사양).
		GroggyGauge.Add(enemy.Groggy, QteDefinitions.PARRY_GROGGY_GAIN)
		pushLog(
			state,
			string.format(
				"%s의 %s를 받아넘겼다 (적 그로기 +%d)",
				enemy.Name,
				skill.Name,
				QteDefinitions.PARRY_GROGGY_GAIN
			)
		)
	else
		pushLog(state, string.format("%s의 %s — %d 피해", enemy.Name, skill.Name, taken))
	end

	fire(state, "Defend", { Attacker = enemy, Grade = grade, Auto = autoParried, Skill = skill })
	if taken > 0 then
		fire(state, "Taken", { Attacker = enemy, Damage = taken })
	end

	--[[
		QTE 를 놓치고 그대로 맞으면 아군 그로기가 찬다(ALLY_GROGGY_ON_FAIL). 가득 차면 **다음 내 턴**을 쉰다 —
		턴 끝(EndTurn)에서 한 번 깎이므로 1 을 더해 둔다. 카드가 막거나(무감각 `GroggyImmune`)
		줄인다(고집 — `Stunned` 훅이 Turns 를 깎는다).
	]]
	if grade == "Fail" and taken > 0 and ally.Alive and query(state, "GroggyImmune", 0) < 1 then
		if GroggyGauge.Add(ally.Groggy, ALLY_GROGGY_ON_FAIL * query(state, "AllyGroggyScale", 1)) then
			local stun = { Turns = GroggyGauge.STUN_TURNS }
			fire(state, "Stunned", stun)
			if stun.Turns > 0 then
				ally.Groggy.StunTurns = stun.Turns + 1
				pushLog(state, string.format("%s 그로기 — 다음 턴 행동 불가", ally.Name))
			else
				ally.Groggy.StunTurns = 0
				ally.Groggy.Value = 0
				pushLog(state, "그로기를 버텼다")
			end
		end
	end

	pushEvent(state, {
		Kind = "EnemyAttack",
		Actor = enemy.Id,
		SkillId = skill.Id,
		Target = ally.Id,
		Grade = grade,
		Hits = { { { Id = ally.Id, Damage = taken, Grade = grade, Killed = not ally.Alive } } },
		Reflect = reflected,
		ReflectKilled = not enemy.Alive,
	})

	watchEnd(state, watch)
	refreshOutcome(state)
	return true, nil
end

--[[
	턴을 마무리한다.

	  1. 지속 피해 (출혈·독·화상) — `상태이상.md`. 이 피해로는 죽지 않는다.
	  2. 기한부 보정값을 한 턴 깎는다.
	  3. 그로기·도발 감소.
	  4. 직업 자원 자동 회복 (연금술사 약재·빈 병).

	사양: 스턴은 STUN_TURNS만큼 지속되고, 풀리면 게이지가 0으로 돌아간다.
]]
function GridBattle.EndTurn(state: State)
	if state.Outcome ~= "Ongoing" then
		return
	end
	local watch = watchBegin(state)
	-- 카드: 턴 끝(행동했는지·이동했는지). "공격하지 않고 턴을 마치면" 이 여기다.
	fire(state, "TurnEnd", { Acted = state.Acted, Moved = state.Moved, Attacked = state.Attacked })
	for _, unit in state.Units do
		if unit.Alive then
			--[[
				지속 피해. `TickDots`는 피해량만 돌려주고 감소까지 처리한다.
				죽지 않아야 하므로 canKill=false로 넣는다.
			]]
			local tick = BattleStatus.TickDots(unit.Status, unit.MaxHealth)
			local total = 0
			total += damageUnit(state, unit, tick.Physical, "Physical", false)
			total += damageUnit(state, unit, tick.Fire, "Fire", false)
			total += damageUnit(state, unit, tick.True, "True", false)
			if #tick.Notes > 0 then
				pushLog(state, string.format("%s — %s", unit.Name, table.concat(tick.Notes, " · ")))
			end

			BattleStatus.TickModifiers(unit.Status)
			GroggyGauge.TickTurn(unit.Groggy)
			-- 도발은 유지비다. 매 턴 빠지므로 계속 쌓아야 유지된다.
			unit.Taunt = math.max(0, unit.Taunt - GridBattle.TAUNT_DECAY)
			-- 쿨타임 감소. 0 밑으로는 안 내려간다.
			for id, remaining in unit.Cooldowns do
				unit.Cooldowns[id] = math.max(0, remaining - 1)
			end
		end
	end

	-- 직업 자원 자동 회복. 아군만 해당한다(적은 직업이 없다).
	local ally = GridBattle.Ally(state)
	if ally.Alive then
		for id, amount in ClassResources.TurnGain(state.AllyClassId, state.Turn) do
			gainResource(state, ally, id, amount)
		end
		--[[
			스테미나는 사양대로 매 턴 고정 8씩 찬다
			(`ProgressionDefinitions.StaminaRegen`, 받는 버프 효율이 반영된다).
		]]
		local regen = ProgressionDefinitions.StaminaRegen(BattleStatus.Total(ally.Status, "BuffTaken"))
			* math.max(0, 1 + BattleStatus.Total(ally.Status, "StaminaGain"))
		ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(regen + 0.5))
	end

	--[[
		카드의 `행동하지 않고 턴을 마치면` 효과. 턴을 넘기기 **전에** 판정한다.
		페르마타·묵상처럼 한 턴을 통째로 쉬는 대신 자원을 받는 카드가 여기 걸린다.
	]]
	state.Acted = false
	state.Attacked = false

	--[[
		예고를 비운다. 이번 턴 몫은 이미 해소됐으므로, 남겨 두면 다음 턴에 같은
		공격이 한 번 더 나간다.
	]]
	state.Planned = {}
	state.Turn += 1
	state.Moved = false
	CardEffects.NewTurn(state.Runtime)

	--[[
		카드의 `매 턴` 효과. **턴 번호를 올린 뒤**에 쏜다 — 여기서 거는 조건부
		보정값은 1턴짜리라, 새 턴이 시작한 시점에 붙어야 그 턴 내내 유효하다.
		직전 `TickModifiers`가 지난 턴 몫을 이미 걷어 갔으므로 겹치지도 않는다.
	]]
	fire(state, "TurnStart", state.Turn)
	watchEnd(state, watch)

	refreshOutcome(state)
end

--[[
	클라이언트로 보낼 만큼만 추린 스냅샷.
	상태 표를 통째로 보내면 서버 내부 구조가 그대로 새어 나간다.
]]
function GridBattle.Snapshot(state: State): any
	local units = {}
	for id, unit in state.Units do
		local cell = BattleGrid.CellOf(state.Grid, id)
		units[id] = {
			Id = unit.Id,
			Name = unit.Name,
			Side = unit.Side,
			Health = unit.Health,
			MaxHealth = unit.MaxHealth,
			Alive = unit.Alive,
			Groggy = unit.Groggy.Value,
			Stunned = GroggyGauge.IsStunned(unit.Groggy),
			Taunt = unit.Taunt,
			SkillIndex = unit.SkillIndex,
			-- 적에게 걸린 것도 보여야 한다(광신·감극·화상 등).
			Shield = unit.Status.Shield,
			Bleed = unit.Status.Bleed,
			Poison = unit.Status.Poison,
			Burn = unit.Status.Burn,
			Oil = unit.Status.Oil,
			X = cell and cell.X or nil,
			Y = cell and cell.Y or nil,
		}
	end
	--[[
		아군 스킬 목록을 함께 보낸다.

		클라이언트가 `BattleSkills.All()`로 직접 만들면 직업과 무관한 목록이 뜬다
		(그래서 어떤 직업을 골라도 스킬 바가 똑같았다). **무엇을 쓸 수 있는지도
		서버가 정한다.**
	]]
	local ally = GridBattle.Ally(state)
	local allyStatus = ally.Status

	--[[
		쓸 수 있는 스킬 그대로 내려보낸다. `SkillList`가 유일한 기준이므로 클라이언트
		버튼 번호와 서버 판정이 어긋날 수 없다.
	]]
	local classCount = #BattleSkills.ForClass(state.AllyClassId)
	local commonCount = #BattleSkills.Common()
	local allySkills = {}
	local resolved = GridBattle.SkillList(state)
	for index, skill in resolved do
		local override = BattleSkillEffects.DisplayName(skill.Id, allyStatus)
		--[[
			종류를 함께 보낸다.
			  Class    직업 스킬 1~3
			  Upgrade  강화·연계 (3번 오른쪽)
			  Common   가드·명상
		]]
		local kind = "Class"
		if index > #resolved - commonCount then
			kind = "Common"
		elseif index > classCount then
			kind = "Upgrade"
		end

		table.insert(allySkills, {
			Index = index,
			Id = skill.Id,
			Name = override or skill.Name,
			-- 스킬 바에서 마우스를 올렸을 때 띄울 설명과 범위.
			Description = skill.Description or "",
			ShapeText = BattleSkills.ShapeText(skill),
			Damage = skill.Damage,
			Range = BattleSkills.RangeText(skill),
			-- 근거리 / 원거리 (요청).
			RangeKind = skill.Range,
			RangeLabel = BattleSkills.RangeLabel(skill),
			Kind = kind,
			Upgraded = kind == "Upgrade" or override ~= nil,
			-- 쿨타임. UI가 이걸로 스킬 바를 잠그거나 "N턴 남음"을 띄운다.
			Cooldown = skill.Cooldown or 0,
			CooldownLeft = ally.Cooldowns[skill.Id] or 0,
			StaminaCost = GridBattle.StaminaCost(state, skill),
			Blocked = skill.Damage > 0 and query(state, "NoAttackSkills", 0) >= 1,
		})
	end

	return {
		Floor = state.Floor,
		Turn = state.Turn,
		Outcome = state.Outcome,
		Units = units,
		AllyClassId = state.AllyClassId,
		AllySkills = allySkills,
		-- 자원·보호막·지속 피해. UI가 이걸로 상태 표시를 그린다.
		AllyStatus = BattleStatus.Snapshot(allyStatus),
		AllyStamina = ally.Stamina,
		AllyMaxStamina = ally.MaxStamina,
		-- 결투사 태세 버튼: 지금 태세, 이번 턴에 바꿨는지, 필수 카드가 잠갔는지
		Stance = if state.AllyClassId == "Duelist"
			then {
				Attack = BattleStatus.Stack(allyStatus, ClassResources.STANCE_ATTACK) > 0,
				Used = state.StanceToggledTurn == state.Turn,
				Locked = query(state, "StanceLocked", 0) >= 1,
			}
			else nil,
		-- 아군 그로기(회피 실패로 찬다. 가득 차면 다음 턴을 쉰다)
		AllyGroggy = ally.Groggy.Value,
		AllyStunned = GroggyGauge.IsStunned(ally.Groggy),
		--[[
			패링 판정 폭(비율). 회피 QTE 의 성공·방어 구간을 이만큼 넓힌다.
			보정값 ParryWindow + 민첩 3%/점 + 체력 1%/점(사양 `### 스탯`).
		]]
		AllyParryWindow = BattleStatus.Total(ally.Status, "ParryWindow")
			+ (state.AllyStats.Agility or 0) * 0.03
			+ (state.AllyStats.Vitality or 0) * 0.01,
		--[[
			공격을 예고한 적들. 클라이언트가 이걸로 위협 칸을 칠한다.

			예고한 적만 담으므로, 그로기로 못 움직인 적의 칸은 칠해지지 않는다 —
			예전에는 유닛의 SkillIndex를 그대로 보고 칠해서 이미 지난 공격이나
			행동 불가인 적의 공격까지 표시됐다.
		]]
		Planned = table.clone(state.Planned),
		Log = table.clone(state.Log),
		Events = table.clone(state.Events),
	}
end

return GridBattle
