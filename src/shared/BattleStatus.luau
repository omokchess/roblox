--!strict
--[[
	BattleStatus — 유닛 하나가 지고 있는 **상태이상·자원·보정값** 전부.

	사양 출처: `상태이상.md` (지속 피해·보호막 정의), `유저 아이디어(직업).md` (직업 자원)

	--------------------------------------------------------------------------
	왜 따로 뺐나

	`GridBattle`은 원래 Health·Power·Groggy만 알았다. 그래서 어떤 스킬도 "버프를
	건다 / 자원을 쌓는다 / 3턴 뒤에 풀린다"를 표현할 수 없었고, 직업 스킬 절반이
	피해 0인 껍데기로 남아 있었다.

	이 모듈은 그 껍데기를 채우기 위한 것이며, **순수 계산만** 한다. Roblox 타입을
	쓰지 않으므로 Lune 테스트에서 그대로 돌아간다.

	--------------------------------------------------------------------------
	담는 것 네 가지

	  1. 보호막    추가 HP. 피해를 먼저 먹는다.
	  2. 지속 피해 출혈·독·화상·기름. 규칙은 전부 `상태이상.md`에서 왔다.
	  3. 스택      직업 자원. 음표·집중·질량·광신·벽·허물 벽·감극·공명·약재…
	               이름만 다르고 동작이 같아 하나의 표로 다룬다.
	  4. 보정값    기한이 있는 ±%. 같은 종류가 여럿이면 **합산**한다.

	--------------------------------------------------------------------------
	지속 피해 규칙 (`상태이상.md` 그대로)

	  출혈  매 턴 최대 체력의 5% 물리 피해. 턴 종료 시 1 감소.
	  독    매 턴 (독 수치)만큼 고정 피해. 턴 종료 시 3 감소.
	  화상  매 턴 (화상 수치)% 화염 피해. 턴 종료 시 1 감소.
	  기름  화염 속성으로 받는 피해 50% 증가. (남은 턴 수로 관리)

	**세 가지 모두 이 효과로는 죽지 않는다.** 그래서 `Tick`은 피해량을 돌려주기만
	하고, 체력을 깎는 것은 `GridBattle`이 "죽지 않게" 처리한다.
]]

local BattleStatus = {}

-- 출혈 한 번이 주는 피해: 최대 체력의 5%.
BattleStatus.BLEED_MAX_HEALTH_RATIO = 0.05
-- 턴 종료 시 각 지속 피해가 빠지는 양.
BattleStatus.BLEED_DECAY = 1
BattleStatus.POISON_DECAY = 3
BattleStatus.BURN_DECAY = 1
-- 기름이 화염 피해를 키우는 비율.
BattleStatus.OIL_FIRE_BONUS = 0.5

--[[
	피해 속성.

	  Physical  물리. 대부분의 스킬과 출혈.
	  Fire      화염. 기름과 맞물린다.
	  True      고정. 어떤 보정도 받지 않는다(독, 개발용 고정 피해).
]]
export type Element = "Physical" | "Fire" | "True"

--[[
	기한이 있는 보정값의 종류.

	모두 **비율**이다(0.2 = 20%). Reflect만 예외로 절대값이다.
]]
export type ModifierKind =
	"DamageDealt" -- 주는 피해
	| "DamageTaken" -- 받는 피해
	| "CritChance" -- 치명타 확률
	| "CritDamage" -- 치명타 피해
	| "ParryWindow" -- 패링·방어 판정 폭
	| "Accuracy" -- 명중률
	| "HealTaken" -- 받는 회복량
	| "BuffTaken" -- 받는 버프 효율
	| "Reflect" -- 피격 시 반사 피해 (절대값)
	| "AutoParry" -- 자동 패링 확률 (QTE 를 못 막았을 때 이 확률로 패링)
	| "StaminaGain" -- 스테미나 획득량(매 턴 회복·명상)
	| "HealDealt" -- 주는 회복량

export type Modifier = {
	Kind: ModifierKind,
	Value: number,
	-- 남은 턴. -1이면 전투가 끝날 때까지.
	Turns: number,
	-- 로그·UI에 띄울 이름. 어떤 스킬이 걸었는지 알아보려고 둔다.
	Source: string,
}

export type State = {
	Shield: number,
	Bleed: number,
	Poison: number,
	Burn: number,
	Oil: number,
	Stacks: { [string]: number },
	Modifiers: { Modifier },
}

-- 지속 피해 한 턴치를 정리한 결과. GridBattle이 이걸 받아 체력을 깎는다.
export type TickResult = {
	-- 속성별 피해량. 이 피해로는 죽지 않는다.
	Physical: number,
	Fire: number,
	True: number,
	-- 로그에 남길 줄. 비어 있으면 이번 턴에 지속 피해가 없었다는 뜻이다.
	Notes: { string },
}

function BattleStatus.New(): State
	return {
		Shield = 0,
		Bleed = 0,
		Poison = 0,
		Burn = 0,
		Oil = 0,
		Stacks = {},
		Modifiers = {},
	}
end

--=== 스택 ===--

--[[
	스택을 쌓는다. cap이 있으면 그 값에서 멈춘다.

	**상한을 부르는 쪽이 넘긴다.** 자원마다 상한이 다르고(음표는 박자표에 따라
	4/8/16, 집중은 10, 질량은 20…) 그 규칙은 직업 쪽 관심사이기 때문이다.
	`유저 아이디어(직업).md` 규격의 "스택은 반드시 상한이 있을 것"은 부르는 쪽에서 지킨다.
]]
function BattleStatus.AddStack(state: State, id: string, amount: number, cap: number?): number
	local next_ = (state.Stacks[id] or 0) + amount
	if cap then
		next_ = math.min(next_, cap)
	end
	state.Stacks[id] = math.max(0, math.floor(next_))
	return state.Stacks[id]
end

function BattleStatus.Stack(state: State, id: string): number
	return state.Stacks[id] or 0
end

--[[
	스택을 쓴다. 가진 만큼만 빠지고, **실제로 쓴 양**을 돌려준다.

	"소모한 스택 1당 피해 +N%"류 스킬이 많아서, 요청량이 아니라 실제 소모량을
	알아야 계산이 맞는다.
]]
function BattleStatus.SpendStack(state: State, id: string, amount: number): number
	local have = state.Stacks[id] or 0
	local spent = math.min(have, math.max(0, math.floor(amount)))
	state.Stacks[id] = have - spent
	return spent
end

-- 스택을 전부 쓴다. 소모한 양을 돌려준다.
function BattleStatus.SpendAll(state: State, id: string): number
	local have = state.Stacks[id] or 0
	state.Stacks[id] = 0
	return have
end

--=== 보정값 ===--

--[[
	보정값을 붙인다. 같은 종류가 이미 있어도 **합쳐지지 않고 따로 쌓인다** —
	기한이 서로 다르기 때문이다. 합산은 조회할 때(`Total`) 한다.
]]
function BattleStatus.AddModifier(state: State, kind: ModifierKind, value: number, turns: number, source: string): ()
	table.insert(state.Modifiers, { Kind = kind, Value = value, Turns = turns, Source = source })
end

--[[
	같은 출처로 걸린 보정값을 모두 뗀다.

	태세(공격/방어)처럼 **하나만 켜져 있어야 하는** 것에 쓴다. 바꿀 때 이전 것을
	떼지 않으면 두 태세가 동시에 걸려 수치가 겹친다.
]]
function BattleStatus.RemoveBySource(state: State, source: string): ()
	local kept: { Modifier } = {}
	for _, modifier in state.Modifiers do
		if modifier.Source ~= source then
			table.insert(kept, modifier)
		end
	end
	state.Modifiers = kept
end

-- 그 종류의 보정값 합계.
function BattleStatus.Total(state: State, kind: ModifierKind): number
	local total = 0
	for _, modifier in state.Modifiers do
		if modifier.Kind == kind then
			total += modifier.Value
		end
	end
	return total
end

--=== 보호막 ===--

function BattleStatus.AddShield(state: State, amount: number): number
	state.Shield = math.max(0, state.Shield + math.floor(amount))
	return state.Shield
end

--[[
	보호막으로 피해를 먼저 먹는다. (흡수량, 남은 피해)를 돌려준다.
	`상태이상.md`: "(보호막 수치)만큼 추가 HP를 얻는다."
]]
function BattleStatus.Absorb(state: State, amount: number): (number, number)
	local absorbed = math.min(state.Shield, math.max(0, amount))
	state.Shield -= absorbed
	return absorbed, math.max(0, amount - absorbed)
end

--=== 지속 피해 ===--

function BattleStatus.AddBleed(state: State, amount: number): number
	state.Bleed = math.max(0, state.Bleed + math.floor(amount))
	return state.Bleed
end

function BattleStatus.AddPoison(state: State, amount: number): number
	state.Poison = math.max(0, state.Poison + math.floor(amount))
	return state.Poison
end

function BattleStatus.AddBurn(state: State, amount: number): number
	state.Burn = math.max(0, state.Burn + math.floor(amount))
	return state.Burn
end

-- 기름은 남은 턴으로 관리한다. 여러 번 걸면 더 긴 쪽이 남는다.
function BattleStatus.AddOil(state: State, turns: number): number
	state.Oil = math.max(state.Oil, math.floor(turns))
	return state.Oil
end

--[[
	이번 턴의 지속 피해를 정산한다. **체력은 건드리지 않는다** — 돌려준 값을
	`GridBattle`이 "죽지 않게" 적용한다(`상태이상.md`: "이 효과로 사망할 수 없다").

	감소는 여기서 함께 처리한다. 피해를 준 뒤 줄어드는 순서다.
]]
-- health: 지금 체력(출혈은 2026-10-04 리워크로 지금 체력 비례). 없으면 최대 체력
function BattleStatus.TickDots(state: State, maxHealth: number, health: number?): TickResult
	local result: TickResult = { Physical = 0, Fire = 0, True = 0, Notes = {} }

	if state.Bleed > 0 then
		local damage = math.floor((health or maxHealth) * BattleStatus.BLEED_MAX_HEALTH_RATIO)
		result.Physical += damage
		table.insert(result.Notes, string.format("출혈 %d (%d 피해)", state.Bleed, damage))
		state.Bleed = math.max(0, state.Bleed - BattleStatus.BLEED_DECAY)
	end

	if state.Poison > 0 then
		-- 독은 수치 그대로가 피해다. 그래서 감소가 3으로 크다.
		result.True += state.Poison
		table.insert(result.Notes, string.format("독 %d (%d 피해)", state.Poison, state.Poison))
		state.Poison = math.max(0, state.Poison - BattleStatus.POISON_DECAY)
	end

	if state.Burn > 0 then
		local damage = math.floor(maxHealth * state.Burn / 100)
		result.Fire += damage
		table.insert(result.Notes, string.format("화상 %d%% (%d 피해)", state.Burn, damage))
		state.Burn = math.max(0, state.Burn - BattleStatus.BURN_DECAY)
	end

	if state.Oil > 0 then
		state.Oil -= 1
	end

	return result
end

--=== 턴 넘기기 ===--

--[[
	기한이 있는 보정값을 한 턴 깎고, 다 된 것을 버린다.
	Turns == -1은 전투가 끝날 때까지 남는다.
]]
function BattleStatus.TickModifiers(state: State): ()
	local kept: { Modifier } = {}
	for _, modifier in state.Modifiers do
		if modifier.Turns < 0 then
			table.insert(kept, modifier)
		elseif modifier.Turns > 1 then
			modifier.Turns -= 1
			table.insert(kept, modifier)
		end
		-- Turns == 1이면 이번 턴이 마지막이었으므로 버린다.
	end
	state.Modifiers = kept
end

--=== 피해 계산 ===--

--[[
	공격 쪽 보정을 먹인 피해량.

	`DamageDealt`만 본다. 치명타는 부르는 쪽이 따로 굴린다 — 굴림 결과를 로그에
	남겨야 해서 여기서 숨기면 안 된다.
]]
function BattleStatus.OutgoingDamage(attacker: State, base: number): number
	return base * (1 + BattleStatus.Total(attacker, "DamageDealt"))
end

--[[
	방어 쪽 보정을 먹인 피해량. 보호막은 아직 빼지 않는다.

	  True 속성은 어떤 보정도 받지 않는다.
	  Fire 속성은 기름이 있으면 50% 늘어난다(`상태이상.md`).
]]
function BattleStatus.IncomingDamage(defender: State, amount: number, element: Element): number
	if element == "True" then
		return math.max(0, amount)
	end
	local scaled = amount * (1 + BattleStatus.Total(defender, "DamageTaken"))
	if element == "Fire" and defender.Oil > 0 then
		scaled *= 1 + BattleStatus.OIL_FIRE_BONUS
	end
	return math.max(0, scaled)
end

-- UI가 그릴 만큼만 추린 요약.
function BattleStatus.Snapshot(state: State): any
	local modifiers = {}
	for _, modifier in state.Modifiers do
		table.insert(modifiers, {
			Kind = modifier.Kind,
			Value = modifier.Value,
			Turns = modifier.Turns,
			Source = modifier.Source,
		})
	end
	local stacks = {}
	for id, amount in state.Stacks do
		if amount > 0 then
			stacks[id] = amount
		end
	end
	return {
		Shield = state.Shield,
		Bleed = state.Bleed,
		Poison = state.Poison,
		Burn = state.Burn,
		Oil = state.Oil,
		Stacks = stacks,
		Modifiers = modifiers,
	}
end

return BattleStatus
