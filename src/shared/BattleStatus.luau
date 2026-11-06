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
	  화상  매 턴 최대 체력 × (3% + 0.1% × 화상 수치) 화염 피해(2026-11-06). 턴 종료 시 1 감소.
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
	-- 화상을 건 연금술사의 저항 무시(맹독성 물질). 연금술사가 걸 때마다 갱신, 화상이 다 타면 지움
	BurnIgnore: number?,
	Oil: number,
	Stacks: { [string]: number },
	-- 다시 걸리지 않는 남은 턴(파상풍 터진 뒤 2턴, 경련 사라진 뒤 3턴). EndTurn 이 줄인다
	Immune: { [string]: number }?,
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

function BattleStatus.AddBurn(state: State, amount: number, ignore: number?): number
	state.Burn = math.max(0, state.Burn + math.floor(amount))
	if ignore and ignore > 0 then
		state.BurnIgnore = ignore
	end
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
-- bleedRatio: 출혈 비율 바꿈(칼리스토 3% — 2026-11-06 개선안 6절). 없으면 BLEED_MAX_HEALTH_RATIO
function BattleStatus.TickDots(state: State, maxHealth: number, health: number?, bleedRatio: number?): TickResult
	local result: TickResult = { Physical = 0, Fire = 0, True = 0, Notes = {} }

	if state.Bleed > 0 then
		local damage = math.floor((health or maxHealth) * (bleedRatio or BattleStatus.BLEED_MAX_HEALTH_RATIO))
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
		local damage = math.floor(maxHealth * BattleStatus.BurnRatio(state.Burn))
		result.Fire += damage
		table.insert(result.Notes, string.format("화상 %d (최대 체력 %.1f%% · %d 피해)", state.Burn, BattleStatus.BurnRatio(state.Burn) * 100, damage))
		state.Burn = math.max(0, state.Burn - BattleStatus.BURN_DECAY)
		if state.Burn == 0 then
			state.BurnIgnore = nil
		end
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
	피해 공식(2026-11-02 사용자 지시). **전투의 피해 계산은 전부 이 절에서 나온다.**
	코드 안에서는 모두 비율(0.2 = 20%)로 다룬다 — 지시문의 `/100` 은 "퍼센트 값"이라는 뜻일 뿐이다.

	  1) base = 스킬 기본 피해 × (1 + 무기)
	  2) flat = base × (1 + 가하는 피해량)            버프: 전투 중 얻는 [가하는 피해량] · 카드로 얻는 것
	  3) dmg  = flat × (1 + 스킬 피해 증가) × (1 + 받는 피해량)
	  4) 치명타 = dmg × (2 + 치명타 피해량)           기본 200%. 확률 100% 초과분은 치명타 피해량으로 넘어간다(GridBattle)

	**각 칸 안은 합연산**(같은 칸의 보정은 더한 뒤 1+ 를 곱한다), **칸끼리는 곱연산**.
	받는 피해량(def) = 맞는 쪽의 [받는 피해량] 합 + 속성 저항(저항은 음수로 들어간다) + 기름의 화염 +50% + 보스 과부하 — 한 칸에 모두 더한다
	(그래서 화염 저항 90% 인 적이 기름을 쓰면 ×0.1 이 아니라 1 + 0.5 − 0.9 = ×0.6).

	공식 밖 곱연산(`Mult`): QTE 등급 배율 · 카드의 스킬 배율(기본 피해량 60% 감소 …) · 파상풍 0.8^n · 연타 분배(×1.2/n) · 디버그 배율.
	고정 피해(True)는 def 의 [받는 피해량]·저항을 받지 않는다. 손 계산 예시는 PrototypeTests "damage formula" 절.
]]

-- 치명타 기본 배율: 200%(2026-11-02 사용자 "dmg × (2 + crit_dmg/100)" — 옛 150%)
BattleStatus.CRIT_MULTIPLIER = 2
-- 무기 공격력 1당 스킬 피해 +4%. 옛 공식은 (무기 공격력 + 스킬 피해) 평면 합이었다 — 직업 스킬 평균 피해(약 27)에서 같은 값이 나오게 옮긴 수치
-- (무기 11~26 → +44~104%). 사용자 지시 문자 그대로(1당 +1%)면 전체 피해가 절반 아래로 떨어진다 → 질문 문서에 올림.
BattleStatus.WEAPON_PERCENT_PER_POWER = 4
-- 파상풍 한 칸당 주는 피해 곱(2026-10-04 월 필그림 리워크)
BattleStatus.TETANUS_DAMAGE = 0.85 -- 2026-11-06 0.8 → 0.85 (파상풍·쇼크 약화)
-- 화상: 최대 체력 × (3% + 0.1% × 화상 수치)(2026-11-06 사용자). 수치 1 이상이면 최소 3.1%
BattleStatus.BURN_BASE_RATIO = 0.03
BattleStatus.BURN_PER_STACK_RATIO = 0.001
-- 융해: (대상의 화상 수치 × 융해 수치) ÷ 2 피해, 융해 1당 최대 100(2026-11-06 사용자)
BattleStatus.MELT_DAMAGE_CAP_PER_STACK = 100
-- 쇼크: 수치 1당 받는 피해량 +6%(옛 8%, 2026-11-06 약화)
BattleStatus.SHOCK_PER_STACK = 0.06

-- 화상 수치 → 최대 체력 대비 피해 비율
function BattleStatus.BurnRatio(burn: number): number
	if burn <= 0 then
		return 0
	end
	return BattleStatus.BURN_BASE_RATIO + BattleStatus.BURN_PER_STACK_RATIO * burn
end

-- 융해 폭발 피해(화상 수치 × 융해 수치 ÷ 2, 융해 1당 100 상한)
function BattleStatus.MeltDamage(burn: number, melt: number): number
	return math.min(burn * melt / 2, BattleStatus.MELT_DAMAGE_CAP_PER_STACK * melt)
end

export type DamageParts = {
	-- 스킬 기본 피해(스킬 표 값 + 카드의 기본 피해 +)
	Skill: number,
	-- 1) 무기 칸(비율). 무기 공격력 환산(WeaponRatio) + 스탯 피해
	Weapon: number?,
	-- 2) 가하는 피해량 칸(비율). 전투 중 버프(DealtBonus) + 카드가 주는 것
	Buffs: number?,
	-- 3) 스킬 피해 증가 칸(비율). 그 스킬 자체의 증가(스택당·대상 조건)
	Skills: number?,
	-- 3) 받는 피해량 칸(비율). TakenRatio
	Def: number?,
	-- 공식 밖 곱연산(기본 1)
	Mult: number?,
	-- 4) 치명타로 터졌는가 · 치명타 피해량(비율)
	Crit: boolean?,
	CritDamage: number?,
}

-- 치명타 한 방의 배율 = 2 + 치명타 피해량
function BattleStatus.CritMultiplier(critDamage: number?): number
	return BattleStatus.CRIT_MULTIPLIER + (critDamage or 0)
end

-- 무기 공격력 → 무기 칸 비율
function BattleStatus.WeaponRatio(power: number): number
	return power * BattleStatus.WEAPON_PERCENT_PER_POWER / 100
end

--[[
	피해 공식 한 번. 위 네 줄 그대로다 — 어느 칸에 무엇을 넣을지는 부르는 쪽(GridBattle)이 정한다.
	칸 하나가 −100% 아래로 가도 음수 피해가 되지 않게 각 칸은 0 에서 멈춘다.
]]
function BattleStatus.Damage(parts: DamageParts): number
	local base = parts.Skill * math.max(0, 1 + (parts.Weapon or 0))
	local flat = base * math.max(0, 1 + (parts.Buffs or 0))
	local dmg = flat * math.max(0, 1 + (parts.Skills or 0)) * (parts.Mult or 1) * math.max(0, 1 + (parts.Def or 0))
	if parts.Crit then
		dmg *= BattleStatus.CritMultiplier(parts.CritDamage)
	end
	return math.max(0, dmg)
end

--[[
	공격 쪽의 [가하는 피해량] 합(전투 중 버프). 치명타는 부르는 쪽이 따로 굴린다 — 굴림 결과를 로그에
	남겨야 해서 여기서 숨기면 안 된다.
]]
-- allow: 이 출처의 [가하는 피해량]만 센다(조율자 알카이드 — "신앙심 말고는 가하는 피해량을 올릴 수 없음")
function BattleStatus.DealtBonus(attacker: State, allow: { [string]: boolean }?): number
	local dealt = 0
	for _, modifier in attacker.Modifiers do
		if modifier.Kind == "DamageDealt" and (allow == nil or allow[modifier.Source]) then
			dealt += modifier.Value
		end
	end
	return dealt
end

-- [파상풍] 수치 1당 주는 피해 ×0.8(곱연산, 2026-10-04 월 필그림 리워크) — 공식 밖 곱연산
function BattleStatus.TetanusFactor(attacker: State): number
	return BattleStatus.TETANUS_DAMAGE ^ (attacker.Stacks.Tetanus or 0)
end

--[[
	공격 쪽 보정만 먹인 피해량(무기·스킬 칸이 없는 공격: 적 공격 · 카드 고유 피해).
	[가하는 피해량] 칸 + 파상풍.
]]
function BattleStatus.OutgoingDamage(attacker: State, base: number, allow: { [string]: boolean }?): number
	return BattleStatus.Damage({ Skill = base, Buffs = BattleStatus.DealtBonus(attacker, allow), Mult = BattleStatus.TetanusFactor(attacker) })
end

--[[
	받는 피해량(def) — 맞는 쪽 보정을 **한 칸에 합산**한 비율.

	  [받는 피해량] 보정값 합 + 기름(화염 +50%, `상태이상.md`) + extra(보스 과부하처럼 호출자가 아는 것) − 속성 저항
	  True 속성은 어떤 보정도 받지 않는다(extra 만).
	  resist: 이 속성 저항(0.9 = 90%). ignore 만큼 저항을 깎는다(연금술사 맹독성 물질 — 저항이 있을 때만).
]]
function BattleStatus.TakenRatio(defender: State, element: Element, resist: number?, ignore: number?, extra: number?): number
	local def = extra or 0
	if element == "True" then
		return def
	end
	def += BattleStatus.Total(defender, "DamageTaken")
	if element == "Fire" and defender.Oil > 0 then
		def += BattleStatus.OIL_FIRE_BONUS
	end
	local r = resist or 0
	if r > 0 then
		r = math.max(0, r - (ignore or 0))
	end
	return def - r
end

--[[
	방어 쪽 보정을 먹인 피해량. 보호막은 아직 빼지 않는다.
	속성 저항·과부하는 부르는 쪽(GridBattle.damageUnit)이 TakenRatio 로 직접 넣는다.
]]
function BattleStatus.IncomingDamage(defender: State, amount: number, element: Element): number
	return BattleStatus.Damage({ Skill = amount, Def = BattleStatus.TakenRatio(defender, element) })
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
		BurnIgnore = state.BurnIgnore,
		Oil = state.Oil,
		Stacks = stacks,
		Modifiers = modifiers,
		-- 다시 안 걸리는 남은 턴 끝 수(묶임 면역 등 — 상태 아이콘이 보인다)
		Immune = if state.Immune then table.clone(state.Immune) else nil,
	}
end

return BattleStatus
