--!strict
--[[
	CardEffects — 능력 카드가 **전투에서 실제로 하는 일** (2판, 2026-09-28).

	1판은 카드마다 한 줄짜리 표(Hook·Give·Base·PerLevel)였다. 두 가지가 문제였다.
	  - 수치가 카드 글(`Levels` 사다리)과 **따로** 적혀 있어, 편집기에서 숫자를 바꿔도 전투는 옛 값으로 돌았다.
	  - 훅이 다섯 개(전투 시작·턴 시작·쉬고 턴 끝·처치·피격)뿐이라 306장 중 60장만 붙일 수 있었다.

	2판
	  - 카드 한 장 = 훅 함수 몇 개(직업별 파일 `CardEffects/<직업>.luau`). 필요한 훅만 적는다.
	  - 수치는 전부 카드의 `Levels` 에서 읽는다: `c.V(1)` = 글의 첫 번째 {숫자}의 지금 레벨 값.
	    그래서 편집기(config_editor → apply_config_edits)에서 고친 숫자가 그대로 전투에 먹는다.
	  - 규칙을 바꾸는 카드(상한 변경·태세 금지 등)는 `Rules` 로 질의에 답한다(`Query`).

	--------------------------------------------------------------------------
	훅 (GridBattle 이 부른다. 인자 표는 훅이 고칠 수 있는 것도 담는다)

	  BattleStart()                         전투가 세워진 직후
	  TurnStart(turn)                       턴이 시작할 때(1턴 포함)
	  TurnEnd(info{Acted, Moved})           턴이 끝나기 직전
	  Move(info{FromX,FromY,ToX,ToY})       이동했을 때
	  BeforeSkill(info)                     스킬 판정 직전. info.Bonus(주는 피해 +비율)·info.Crit(치명 확률 +)·
	                                        info.CritDamage(+)·info.Flat(기본 피해 +) 를 고친다
	  BeforeHit(info{Target, Bonus})        대상 하나를 때리기 직전(대상 조건부 보정)
	  Hit(info{Target, Damage, Crit})       대상 하나를 때린 뒤
	  AfterSkill(info{Skill, Hits, Kills, Grade, Crits})  스킬이 끝난 뒤
	  Kill(info{Target})                    적이 쓰러졌을 때(무엇으로든)
	  BeforeTaken(info{Attacker, Grade, Mult, AutoParry})  적 공격을 받기 직전(배율·자동 패링 확률)
	  Defend(info{Attacker, Grade})         회피·방어·패링 판정 뒤(Success=패링, Partial=방어, Fail=실패)
	  Taken(info{Attacker, Damage})         적 공격을 맞은 뒤(피해 0 이면 안 부른다)
	  Damaged(info{Amount, Element})        어떤 이유로든 체력이 깎였을 때(지속 피해·자해 포함)
	  Gain(id, amount) / Spend(id, amount)  자원(스택)이 늘거나 줄었을 때 — 앞뒤를 견줘 알아낸다
	  Status(info{Target, Kind, Amount})    적에게 출혈·독·화상·기름을 새로 걸었을 때
	  Stance(attack)                        결투사 태세가 바뀌었을 때

	규칙 질의(Rules): `CardEffects.Query(runtime, key, base)` — 카드가 base 를 고쳐 돌려준다.
	  예) NoteCapBonus(음표 상한 +), WallCap, RuinCap, FocusCap, StaminaCost(스킬 스테미나 배율) …

	--------------------------------------------------------------------------
	파티 전제 카드

	"아군이 3명 이상", "인접한 아군" 같은 카드는 **파티 전투를 전제**로 한다. 지금 전투는 솔로라
	아군 목록(`c.Allies()`)이 자기 하나뿐이다 — "아군 전체" 효과는 자신에게 걸리고, 인원·인접 조건은
	성립하지 않는다. 그런 카드는 정의 표에 `Party = true` 를 달아 두면 레벨업 화면이 "파티" 표시를 하고,
	솔로 뽑기에서 덜 나온다(AbilityCardDefinitions.DrawForFloor).
]]

local AbilityCardDefinitions = require(script.Parent.AbilityCardDefinitions)
local BattleStatus = require(script.Parent.BattleStatus)
local ClassPassives = require(script.Parent.ClassPassives)
local ClassResources = require(script.Parent.ClassResources)

export type Owned = { CardId: string, Level: number }

-- 훅 함수가 받는 카드 한 장의 손잡이
export type Card = {
	Id: string,
	Level: number,
	-- 글의 i 번째 {숫자}의 지금 레벨 값(편집기 숫자 그대로. 5 → 5%)
	V: (slot: number) -> number,
	-- V 를 비율로(5 → 0.05)
	P: (slot: number) -> number,
	-- 이 카드 전용 기억 칸(전투 동안 유지)
	Mem: { [string]: any },
	Rt: Runtime,
}

export type Handler = {
	-- 파티(아군 여럿)를 전제로 한 카드인지. 솔로에서 덜 뽑히고 "파티" 표시가 붙는다.
	Party: boolean?,
	-- 규칙 질의에 답하는 함수들. key → (card, value) -> value
	Rules: { [string]: (Card, number) -> number }?,
	[string]: any,
}

-- 전투 하나에 붙는 카드 실행기
export type Runtime = {
	Cards: { Card },
	State: any,
	-- GridBattle 이 채워 주는 도구 묶음(순환 참조를 피하려고 함수로 받는다)
	Env: any,
	Depth: number,
	TurnCounters: { [string]: number },
}

local CardEffects = {}

--=== 등록 ===--

local HANDLERS: { [string]: Handler } = {}

local CLASS_MODULES = {
	"Musician",
	"Duelist",
	"Quasar",
	"Pulsar",
	"WallPilgrim",
	"WallMason",
	"WallBreaker",
	"Alchemist",
	"Berserker",
}

function CardEffects.Handler(cardId: string): Handler?
	return HANDLERS[cardId]
end

function CardEffects.IsWired(cardId: string): boolean
	return HANDLERS[cardId] ~= nil
end

function CardEffects.IsParty(cardId: string): boolean
	local handler = HANDLERS[cardId]
	return handler ~= nil and handler.Party == true
end

function CardEffects.WiredIds(): { string }
	local ids: { string } = {}
	for id in HANDLERS do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function CardEffects.Coverage(): number
	return #CardEffects.WiredIds()
end

--=== 실행기 ===--

local function ladderValue(cardId: string, slot: number, level: number): number
	local card = AbilityCardDefinitions.Get(cardId)
	local ladders = card and card.Levels
	local ladder = ladders and ladders[slot]
	if not ladder or #ladder == 0 then
		-- 사다리가 없으면 글의 숫자를 그대로 쓴다
		if card then
			local seen = 0
			for token in card.Description:gmatch("{([%d%.%-]+)}") do
				seen += 1
				if seen == slot then
					return tonumber(token) or 0
				end
			end
		end
		return 0
	end
	return ladder[math.clamp(level, 1, #ladder)]
end

function CardEffects.NewRuntime(state: any, owned: { Owned }?, env: any, classId: string?): Runtime
	local runtime: Runtime = {
		Cards = {},
		State = state,
		Env = env,
		Depth = 0,
		TurnCounters = {},
	}
	--[[
		직업 패시브(ClassPassives)와 직업 키트(`<직업>_Kit` — 음표 버프처럼 전용 상태이상이 늘 하는 일)를
		**늘 가진 카드**로 앞에 끼운다. 같은 훅·같은 도우미로 돌아가서 카드와 섞여도 순서가 분명하다.
	]]
	local always: { Owned } = {}
	if classId then
		if HANDLERS[classId .. "_Kit"] then
			table.insert(always, { CardId = classId .. "_Kit", Level = 1 })
		end
		local kit = ClassPassives.Get(classId)
		for _, passive in (kit and kit.Passives) or {} do
			if HANDLERS[passive.Id] then
				table.insert(always, { CardId = passive.Id, Level = 1 })
			end
		end
	end
	local all = table.clone(always)
	for _, entry in owned or {} do
		table.insert(all, entry)
	end
	for _, entry in all do
		if HANDLERS[entry.CardId] then
			local level = math.max(1, entry.Level or 1)
			local id = entry.CardId
			local card: Card = {
				Id = id,
				Level = level,
				V = function(slot: number): number
					return ladderValue(id, slot, level)
				end,
				P = function(slot: number): number
					return ladderValue(id, slot, level) / 100
				end,
				Mem = {},
				Rt = runtime,
			}
			table.insert(runtime.Cards, card)
		end
	end
	return runtime
end

--[[
	훅을 쏜다. 카드 안에서 또 훅이 도는 것은 한 겹까지만(서로 부르며 멈추지 않는 것을 막는다).
	발동한 카드 수를 돌려준다(카드가 true 를 돌려주면 센다 — 로그용).
]]
function CardEffects.Fire(runtime: Runtime?, hook: string, ...: any): number
	if not runtime or runtime.Depth > 1 then
		return 0
	end
	runtime.Depth += 1
	local fired = 0
	for _, card in runtime.Cards do
		local handler = HANDLERS[card.Id]
		local fn = handler and handler[hook]
		if type(fn) == "function" then
			local ok, result = pcall(fn, card, ...)
			if not ok then
				warn(string.format("[CardEffects] %s.%s: %s", card.Id, hook, tostring(result)))
			elseif result then
				fired += 1
			end
		end
	end
	runtime.Depth -= 1
	return fired
end

-- 규칙 질의. 카드가 base 를 차례로 고친다.
function CardEffects.Query(runtime: Runtime?, key: string, base: number): number
	if not runtime then
		return base
	end
	local value = base
	for _, card in runtime.Cards do
		local handler = HANDLERS[card.Id]
		local rule = handler and handler.Rules and handler.Rules[key]
		if rule then
			local ok, result = pcall(rule, card, value)
			if ok and type(result) == "number" then
				value = result
			end
		end
	end
	return value
end

-- 이 카드가 있는지(규칙이 "~카드와 같이 쓰면" 을 볼 때)
function CardEffects.Has(runtime: Runtime?, cardId: string): Card?
	if not runtime then
		return nil
	end
	for _, card in runtime.Cards do
		if card.Id == cardId then
			return card
		end
	end
	return nil
end

-- 턴마다 초기화되는 횟수 세기. 넘으면 false.
function CardEffects.PerTurn(card: Card, key: string, limit: number): boolean
	local counters = card.Rt.TurnCounters
	local full = card.Id .. ":" .. key
	local used = counters[full] or 0
	if used >= limit then
		return false
	end
	counters[full] = used + 1
	return true
end

-- 전투당 횟수 세기
function CardEffects.PerBattle(card: Card, key: string, limit: number): boolean
	local used = card.Mem["once:" .. key] or 0
	if used >= limit then
		return false
	end
	card.Mem["once:" .. key] = used + 1
	return true
end

function CardEffects.NewTurn(runtime: Runtime?)
	if runtime then
		table.clear(runtime.TurnCounters)
	end
end

--=== 카드 파일이 쓰는 도우미 ===--
--[[
	카드 파일은 GridBattle 을 모른다. 엔진이 넣어 준 Env 를 이 함수들로만 쓴다.
	Env 에 무엇이 있는지는 GridBattle 의 makeEnv 참고.
]]

local H = {}
CardEffects.H = H

function H.State(c: Card): any
	return c.Rt.State
end

function H.Ally(c: Card): any
	return c.Rt.Env.Ally()
end

function H.Status(c: Card): BattleStatus.State
	return c.Rt.Env.Ally().Status
end

function H.Stack(c: Card, id: string): number
	return BattleStatus.Stack(H.Status(c), id)
end

-- 자원을 준다(직업 규칙대로 — 음표는 박자표 상한). 실제로 얹힌 양
function H.Gain(c: Card, id: string, amount: number): number
	return c.Rt.Env.Gain(id, amount)
end

function H.Spend(c: Card, id: string, amount: number): number
	return BattleStatus.SpendStack(H.Status(c), id, amount)
end

-- 보정값(비율)을 건다. turns 생략 = 1턴(그 턴 동안). source 는 카드 Id 로 묶인다.
function H.Mod(c: Card, kind: BattleStatus.ModifierKind, value: number, turns: number?, tag: string?)
	BattleStatus.AddModifier(H.Status(c), kind, value, turns or 1, "카드:" .. c.Id .. (tag or ""))
end

-- 같은 카드가 건 보정값을 지운다(갱신형 효과)
function H.Clear(c: Card, tag: string?)
	BattleStatus.RemoveBySource(H.Status(c), "카드:" .. c.Id .. (tag or ""))
end

function H.ModOn(c: Card, unit: any, kind: BattleStatus.ModifierKind, value: number, turns: number?, tag: string?)
	BattleStatus.AddModifier(unit.Status, kind, value, turns or 1, "카드:" .. c.Id .. (tag or ""))
end

function H.Heal(c: Card, ratio: number): number
	local ally = H.Ally(c)
	return c.Rt.Env.Heal(ally, math.floor(ally.MaxHealth * ratio))
end

function H.HealFlat(c: Card, amount: number): number
	return c.Rt.Env.Heal(H.Ally(c), math.floor(amount))
end

function H.Shield(c: Card, amount: number)
	BattleStatus.AddShield(H.Status(c), math.floor(amount))
end

function H.LoseHealth(c: Card, amount: number): number
	return c.Rt.Env.Damage(H.Ally(c), math.floor(amount), "True", false)
end

function H.Hurt(c: Card, unit: any, amount: number, element: string?): number
	return c.Rt.Env.Damage(unit, math.max(0, math.floor(amount)), element or "True", true)
end

function H.Log(c: Card, message: string)
	local card = AbilityCardDefinitions.Get(c.Id)
	c.Rt.Env.Log(string.format("[%s] %s", card and card.Name or c.Id, message))
end

function H.Enemies(c: Card): { any }
	return c.Rt.Env.Enemies()
end

function H.Allies(c: Card): { any }
	return c.Rt.Env.Allies()
end

function H.Rng(c: Card): number
	return c.Rt.Env.Rng()
end

function H.Cell(c: Card, unit: any?): any?
	return c.Rt.Env.CellOf((unit or H.Ally(c)).Id)
end

-- 격자 자리: x=1 이 중앙선 쪽(전열), 6 이 끝(후열)
function H.IsFront(c: Card): boolean
	local cell = H.Cell(c)
	return cell ~= nil and cell.X <= 2
end

function H.IsBack(c: Card): boolean
	local cell = H.Cell(c)
	return cell ~= nil and cell.X >= 5
end

-- 내 줄에 서 있는 적 수
function H.LaneEnemies(c: Card): number
	local cell = H.Cell(c)
	if not cell then
		return 0
	end
	local count = 0
	for _, enemy in H.Enemies(c) do
		local other = H.Cell(c, enemy)
		if other and other.Y == cell.Y then
			count += 1
		end
	end
	return count
end

-- 이번 턴에 나를 노린(예고한) 적이 있는지
function H.Threatened(c: Card): boolean
	return c.Rt.Env.Threatened()
end

function H.HealthRatio(c: Card): number
	local ally = H.Ally(c)
	return if ally.MaxHealth > 0 then ally.Health / ally.MaxHealth else 0
end

function H.NoteTotal(c: Card): number
	local total = 0
	for _, id in ClassResources.NOTE_IDS do
		total += H.Stack(c, id)
	end
	return total
end

H.PerTurn = CardEffects.PerTurn
H.PerBattle = CardEffects.PerBattle

--=== 직업 파일 불러오기 ===--
--[[
	직업 파일은 `function(CardEffects) → { [카드 Id] = 처리기 }` 다. 엔진을 require 하면 순환이 되므로
	엔진이 다 만들어진 **맨 끝에서** 자기 자신을 넘겨 부른다. 아직 없는 직업 파일은 건너뛴다
	(Lune 시험 하네스는 FindFirstChild 가 없어 인덱싱으로 찾는다).
]]
for _, name in CLASS_MODULES do
	local ok, factory = pcall(function()
		return (require :: any)((script :: any)[name])
	end)
	if ok and type(factory) == "function" then
		for id, handler in factory(CardEffects) do
			HANDLERS[id] = handler
		end
	end
end

return CardEffects
