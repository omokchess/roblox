--!strict
--[[
	BattleSkillEffects — 스킬 하나하나가 **실제로 무엇을 하는지**.

	사양 출처: `유저 아이디어(직업).md` 각 직업의 `스킬` 항목, `상태이상.md`

	--------------------------------------------------------------------------
	왜 GridBattle 밖에 있나

	직업 9개 × 스킬 3개 + 강화 스킬이라 효과가 서른 개 가까이 된다. 이걸 전부
	`GridBattle.ResolveSkill` 안에 if로 넣으면 그 함수가 혼자 수백 줄이 되고,
	격자 규칙과 직업 규칙이 한 덩어리로 엉킨다.

	그래서 **스킬 Id → 효과 함수** 표로 뺐다. `GridBattle`은 표를 찾아 부르기만 한다.
	순환 참조를 피하려고 GridBattle을 require하지 않고, 필요한 것만 `Context`로 받는다.

	--------------------------------------------------------------------------
	호출 순서

	  1. `Before(ctx)` — 피해 계산 **전**. 자원을 쓰고 **피해 배율**을 돌려준다.
	     (예: 크레셴도는 음표 1개당 +3%)
	  2. GridBattle이 피해를 넣는다.
	  3. `After(ctx)` — 피해 계산 **후**. 자원을 얻고 상태이상을 건다.
	     (예: 벨로체는 4분음표 2개를 얻고 보호막 2를 준다)

	자원을 쓰고 나서 그 양으로 배율을 정하는 스킬이 많아(특이점·알 포르테·허물다)
	`Before`가 소모까지 맡는다.

	--------------------------------------------------------------------------
	솔로 전투라는 전제

	사양이 "탑은 오직 솔로 플레이로만 등반 가능"이므로 아군은 플레이어 하나다.
	그래서 md의 "아군 전체" 효과(브릴란테·축성)는 **자기 자신에게만** 걸린다.
	파티가 생기면 `ctx.Allies`를 여럿으로 넘기면 그대로 동작한다.
]]

local BattleStatus = require(script.Parent.BattleStatus)
local ClassResources = require(script.Parent.ClassResources)

local R = ClassResources

--[[
	효과 함수가 받는 것.

	GridBattle의 타입을 직접 쓰지 않고 any로 받는다 — 그러면 이 모듈이 GridBattle을
	require하지 않아도 되고, 순환 참조가 생기지 않는다.
]]
export type Context = {
	-- 연타 수(Before 가 정한다 — 펄서 수렴. 없으면 1)
	Repeat: number?,
	-- 시전자 (아군)
	Ally: any,
	-- 시전자의 상태이상 그릇
	Status: BattleStatus.State,
	-- 이번에 실제로 맞은 유닛들
	Targets: { any },
	-- 아군 전체. 솔로에서는 Ally 하나뿐이다.
	Allies: { any },
	-- QTE 등급 ("Success" | "Partial" | "Fail")
	Grade: string,
	-- 결정적 난수. 같은 씨앗이면 같은 결과가 나와야 하므로 반드시 이걸 쓴다.
	Rng: () -> number,
	-- 유닛의 상태이상 그릇을 꺼낸다.
	StatusOf: (unit: any) -> BattleStatus.State,
	-- 피해를 넣는다. 죽지 않는 피해는 canKill=false.
	Damage: (unit: any, amount: number, element: BattleStatus.Element, canKill: boolean) -> number,
	-- 회복시킨다.
	Heal: (unit: any, amount: number) -> number,
	-- 스테미나를 채운다. 실제로 채워진 양을 돌려준다(명상).
	RestoreStamina: (amount: number) -> number,
	-- 로그 한 줄.
	Log: (message: string) -> (),
	-- 적을 시전자 쪽으로 끌어당긴다(퀘이사 붕괴).
	PullEnemies: (columns: number) -> number,
	-- 직업 규칙대로 자원을 준다(카드가 늘린 상한까지). 실제로 얹힌 양
	Gain: (id: string, amount: number) -> number,
	-- 카드 규칙 질의(CardEffects.Query)
	Query: (key: string, base: number) -> number,
	-- 피해 계산 뒤(After)에만: 이번 스킬이 준 피해 합계와 맞힌 횟수
	TotalDealt: number?,
	HitCount: number?,
	-- 살아 있는 적 전부
	Enemies: (() -> { any })?,
}

export type Effect = {
	-- 피해 계산 전. 배율을 돌려준다(1이면 보정 없음).
	Before: ((Context) -> number)?,
	-- 피해 계산 후.
	After: ((Context) -> ())?,
}

local BattleSkillEffects = {}

--=== 공용 도우미 ===--

-- 음표 총 개수. 종류가 셋이지만 한 곳에 모인 것으로 센다(md의 `!!` 주석).
local function totalNotes(status: BattleStatus.State): number
	local total = 0
	for _, id in R.NOTE_IDS do
		total += BattleStatus.Stack(status, id)
	end
	return total
end

-- 음표를 종류 상관없이 전부 비운다. 소모한 총량을 돌려준다.
local function spendAllNotes(status: BattleStatus.State): number
	local spent = 0
	for _, id in R.NOTE_IDS do
		spent += BattleStatus.SpendAll(status, id)
	end
	return spent
end


--=== 음악가 ===--

local musicianEffects: { [string]: Effect } = {
	-- 벨로체: 음표 1개당 피해 +2.5%. 사용 후 4분음표 2개, 자신에게 보호막 2.
	Veloce = {
		Before = function(ctx)
			return 1 + totalNotes(ctx.Status) * 0.025
		end,
		After = function(ctx)
			local gained = ctx.Gain(R.QUARTER, 2 + ctx.Query("NoteGainBonus", 0))
			-- "자신과 무작위 아군" — 솔로면 자기 하나. 보호막 양은 카드(송진)가 바꾼다.
			local shield = math.floor(ctx.Query("VeloceShield", 2))
			BattleStatus.AddShield(ctx.Status, shield)
			local others = {}
			for _, ally in ctx.Allies do
				if ally ~= ctx.Ally then
					table.insert(others, ally)
				end
			end
			if #others > 0 then
				BattleStatus.AddShield(ctx.StatusOf(others[math.floor(ctx.Rng() * #others) + 1]), shield)
			end
			ctx.Log(string.format("4분음표 +%d · 보호막 +%d", gained, shield))
		end,
	},

	--[[
		브릴란테: 아군 전체에게 음표 수만큼 [브릴란테].
		브릴란테 = 치명타 확률·피해량 +(1.5 × 값)%.
	]]
	Brillante = {
		After = function(ctx)
			--[[
				카드가 바꾸는 것
				  BuffScale        버프 배율(반주자·협주자 ×1.5, 긴 호흡이 턴마다 +)
				  BrillanteTurns   지속(기본 3, 지속음 +)
				  ChorusSelfOnly   1 이면 자신에게만(협주자)
				  BrillanteCrit    받은 아군 치명 확률 +(데스캉트)
			]]
			local notes = totalNotes(ctx.Status)
			local scale = ctx.Query("BuffScale", 1)
			local turns = math.max(1, math.floor(ctx.Query("BrillanteTurns", 3)))
			local bonus = notes * 0.015 * scale
			local extraCrit = ctx.Query("BrillanteCrit", 0)
			local targets = if ctx.Query("ChorusSelfOnly", 0) >= 1 then { ctx.Ally } else ctx.Allies
			for _, ally in targets do
				local status = ctx.StatusOf(ally)
				BattleStatus.RemoveBySource(status, "브릴란테")
				BattleStatus.SpendAll(status, R.BRILLANTE)
				BattleStatus.AddStack(status, R.BRILLANTE, notes)
				BattleStatus.AddModifier(status, "CritChance", bonus + extraCrit, turns, "브릴란테")
				BattleStatus.AddModifier(status, "CritDamage", bonus, turns, "브릴란테")
			end
			local gained = ctx.Gain(R.EIGHTH, 2 + ctx.Query("NoteGainBonus", 0))
			ctx.Log(
				string.format("브릴란테 %d (치명타 +%.1f%%, %d턴) · 8분음표 +%d", notes, bonus * 100, turns, gained)
			)
		end,
	},

	--[[
		크레셴도: 음표 1개당 피해 +3%.
		음표가 최대치면 **전부 초기화**하고 개당 +4%, 사용 후 박자표 +1.
		16개 이상이면 알 포르테로 강화된다(개당 +7%, 전부 소모).
	]]
	Crescendo = {
		Before = function(ctx)
			local status = ctx.Status
			local notes = totalNotes(status)
			local meter = math.max(1, BattleStatus.Stack(status, R.METER))
			local cap = ClassResources.NoteCap(meter) + ctx.Query("NoteCapBonus", 0)

			if notes >= cap and notes > 0 then
				local spent = spendAllNotes(status)
				ctx.Gain(R.METER, 1)
				ctx.Log(
					string.format(
						"음표 %d 초기화 — 박자표 %d (개당 +4%%)",
						spent,
						BattleStatus.Stack(status, R.METER)
					)
				)
				return 1 + spent * 0.04
			end

			return 1 + notes * 0.03
		end,
		After = function(ctx)
			local gained = ctx.Gain(R.SIXTEENTH, 1 + ctx.Query("NoteGainBonus", 0))
			if gained > 0 then
				ctx.Log(string.format("16분음표 +%d", gained))
			end
		end,
	},

	--[[
		크레셴도 알 포르테 (강화). 음표 16개 이상에서 크레셴도를 대신한다.
		모든 음표를 소모하고, 소모한 음표 1개당 피해 +7%.
	]]
	CrescendoAlForte = {
		Before = function(ctx)
			local spent = spendAllNotes(ctx.Status)
			ctx.Log(string.format("크레셴도 알 포르테 — 음표 %d 소모 (개당 +7%%)", spent))
			return 1 + spent * 0.07
		end,
		After = function(ctx)
			--[[
				md: "사용 후 자신이 가지고 있던 음표 개수 종류당 -4한 만큼의 버프를
				2턴 간 얻는다. (4이하인 경우 1로 보정됨.)"
				종류는 셋뿐이므로 보정이 거의 항상 걸린다 — 최소 1로 둔다.
			]]
			BattleStatus.AddModifier(ctx.Status, "DamageDealt", 0.01, 2, "알 포르테")
		end,
	},
}

--=== 결투사 ===--

--[[
	태세를 바꾼다. **스택만 뒤집는다** — 태세의 보정값(받는 피해·피해·치명·자동 패링)은 결투사 키트
	(`CardEffects/Duelist` 의 Duelist_Kit)가 집중·카드(철벽·광검·양날·자세 낮추기…)를 보고 다시 건다.
	  공격 태세: 받는 피해 +15%, 피해 +(20 + 집중)%, 치명타 확률 +10%, 적중 시 출혈 1
	  방어 태세: 받는 피해 −30%, 피해 −45%, (5×집중)% 자동 패링(최대 30%)
]]
function BattleSkillEffects.SetStance(status: BattleStatus.State, attack: boolean)
	BattleStatus.SpendAll(status, R.STANCE_ATTACK)
	if attack then
		BattleStatus.AddStack(status, R.STANCE_ATTACK, 1, 1)
	end
end

local function applyStance(ctx: Context, attack: boolean): ()
	BattleSkillEffects.SetStance(ctx.Status, attack)
	ctx.Log(if attack then "공격 태세" else "방어 태세")
end

local duelistEffects: { [string]: Effect } = {
	--[[
		앞뒤관통: 사용 후 2턴 간 아군 회피 시간 +(2×집중)%, 자신 받는 피해 −10%.
	]]
	FrontBackPierce = {
		After = function(ctx)
			local focus = BattleStatus.Stack(ctx.Status, R.FOCUS)
			for _, ally in ctx.Allies do
				BattleStatus.AddModifier(ctx.StatusOf(ally), "ParryWindow", focus * 0.02, 2, "앞뒤관통")
			end
			BattleStatus.AddModifier(ctx.Status, "DamageTaken", -0.1, 2, "앞뒤관통")
			ctx.Log(string.format("회피 시간 +%d%% · 받는 피해 −10%% (2턴)", focus * 2))
		end,
	},

	--[[
		찔러찔러또찔러: 대상에게 출혈. 3턴 간 [회피 시간] +(2.5×집중)%. 집중 +1.
	]]
	TripleThrust = {
		After = function(ctx)
			for _, target in ctx.Targets do
				BattleStatus.AddBleed(ctx.StatusOf(target), 3)
			end
			local focus = BattleStatus.Stack(ctx.Status, R.FOCUS)
			BattleStatus.AddModifier(ctx.Status, "ParryWindow", focus * 0.025, 3, "찔러찔러또찔러")
			BattleStatus.AddStack(ctx.Status, R.FOCUS, 1, ClassResources.Cap(R.FOCUS))
			ctx.Log(string.format("출혈 부여 · 집중 %d", BattleStatus.Stack(ctx.Status, R.FOCUS)))
		end,
	},

	--[[
		신경을 곤두세우고 깊은 호흡을 들여 (준비 자세).

		1턴 간 받는 버프·회복 +30%, 받는 피해 −25%, [회피 시간] +(3×집중)%.
		집중 +3. 다음 턴에 이 슬롯은 **연계 스킬**로 강화된다.
	]]
	DeepBreath = {
		After = function(ctx)
			local status = ctx.Status
			local focus = BattleStatus.Stack(status, R.FOCUS)
			BattleStatus.AddModifier(status, "BuffTaken", 0.3, 1, "준비 자세")
			BattleStatus.AddModifier(status, "HealTaken", 0.3, 1, "준비 자세")
			BattleStatus.AddModifier(status, "DamageTaken", -0.25, 1, "준비 자세")
			BattleStatus.AddModifier(status, "ParryWindow", focus * 0.03, 1, "준비 자세")
			BattleStatus.AddStack(status, R.FOCUS, 3, ClassResources.Cap(R.FOCUS))
			BattleStatus.AddStack(status, R.READY, 1, 1)
			ctx.Log(
				string.format(
					"준비 자세 — 집중 %d, 다음 턴 연계 가능",
					BattleStatus.Stack(status, R.FOCUS)
				)
			)
		end,
	},

	--[[
		연계: 마지막까지 빛나는 점을 향해 검 끝을 쏘아라.

		치명타 확률 보정 +15%, 집중 1스택당 피해 +2.5%.
		3턴 간 아군 패링 +15% · 받는 피해 −10%. 출혈. **태세 변경.**
		2턴 간 받는 피해 −15% · 피해 +15%.
	]]
	PointBlank = {
		Before = function(ctx)
			local focus = BattleStatus.Stack(ctx.Status, R.FOCUS)
			BattleStatus.AddModifier(ctx.Status, "CritChance", 0.15, 1, "연계")
			-- 2026-10-03 사용자: 버프 받은 찔러찔러또찔러보다 약하다 → 이 스킬 자체 피해량 +1000%(집중 보너스와 합연산)
			return 1 + 10 + focus * 0.025
		end,
		After = function(ctx)
			local status = ctx.Status
			BattleStatus.SpendStack(status, R.READY, 1)
			for _, ally in ctx.Allies do
				local allyStatus = ctx.StatusOf(ally)
				BattleStatus.AddModifier(allyStatus, "ParryWindow", 0.15, 3, "연계")
				BattleStatus.AddModifier(allyStatus, "DamageTaken", -0.1, 3, "연계")
			end
			for _, target in ctx.Targets do
				BattleStatus.AddBleed(ctx.StatusOf(target), 3)
			end
			-- 태세를 뒤집는다.
			applyStance(ctx, BattleStatus.Stack(status, R.STANCE_ATTACK) <= 0)
			BattleStatus.AddModifier(status, "DamageTaken", -0.15, 2, "연계 여파")
			BattleStatus.AddModifier(status, "DamageDealt", 0.15, 2, "연계 여파")
		end,
	},
}

--=== 퀘이사 ===--

--[[
	[중력] (`Keywords` Gravity): 최대 1스택, 받는 피해 +15%, 공격 실패 +10%, 앞 두 열로 끌려온다.
	스택은 "걸려 있다" 표시이고, 지속은 보정값(출처 "중력")이 센다 — 보정이 끝나면 풀린 것.
	매 턴 끌려오는 것·공격 실패는 퀘이사 키트(`CardEffects/Quasar`)가 한다.
]]
function BattleSkillEffects.ApplyGravity(status: BattleStatus.State, turns: number)
	BattleStatus.SpendAll(status, R.GRAVITY)
	BattleStatus.AddStack(status, R.GRAVITY, 1, 1)
	BattleStatus.RemoveBySource(status, "중력")
	BattleStatus.AddModifier(status, "DamageTaken", 0.15, turns, "중력")
end

function BattleSkillEffects.HasGravity(status: BattleStatus.State): boolean
	for _, modifier in status.Modifiers do
		if modifier.Source == "중력" then
			return true
		end
	end
	return false
end

local quasarEffects: { [string]: Effect } = {
	--[[
		붕괴: 차징을 시작한다(피해 없음). 차징은 턴마다 1씩 차오르고(최대 2, 과충전 3 — 키트),
		차징 중에는 매 턴 적에게 [중력]. 다시 쓰면 발동 — 차징 1턴당 피해 +25%(가속 차징 +)·범위 +1단계.
	]]
	Collapse = {
		Before = function(ctx)
			local charge = BattleStatus.Stack(ctx.Status, R.CHARGE)
			if charge <= 0 then
				BattleStatus.AddStack(ctx.Status, R.CHARGE, 1, math.floor(ctx.Query("ChargeCap", 2)))
				ctx.Log("붕괴 차징 시작")
				return 0
			end
			BattleStatus.SpendAll(ctx.Status, R.CHARGE)
			local step = 0.25 + ctx.Query("ChargeStep", 0)
			ctx.Log(string.format("붕괴 발동 — 차징 %d턴 (피해 +%d%%)", charge, math.floor(charge * step * 100 + 0.5)))
			return 1 + charge * step
		end,
		After = function(ctx)
			-- 차징을 막 시작했으면 범위 안 적에게 바로 [중력]
			if BattleStatus.Stack(ctx.Status, R.CHARGE) <= 0 then
				return
			end
			local turns = math.floor(ctx.Query("GravityTurns", 2))
			for _, target in ctx.Targets do
				BattleSkillEffects.ApplyGravity(ctx.StatusOf(target), turns)
			end
		end,
	},

	--[[
		특이점: [질량]을 전부 태운다. 소모 1당 피해 +5%(압축 +). 소모량으로 단계가 갈린다 —
		1단계(1~7) 기본 10 · 2단계(8~14) 12 · 3단계(15~) 14. 질량 보너스는 20스택까지만 센다.
		(2026-10-03 사용자 "딜탱 본분에 맞게 극 너프": 풀세팅 한 방 25만 — 거센 빛 50스택 × 압축 8% 로 ×5 까지 올랐다) 범위는 GrowResource(질량 ÷ 7.5)가 넓힌다.
	]]
	Singularity = {
		Before = function(ctx)
			local spent = BattleStatus.SpendAll(ctx.Status, R.MASS)
			local tier = if spent >= 15 then 3 elseif spent >= 8 then 2 else 1
			tier = math.max(tier, math.floor(ctx.Query("SingularityTier", 0)))
			local per = ctx.Query("SingularityPerMass", 0.01)
			local power = ctx.Ally.Power or 0
			local base = ({ 10, 12, 14 })[tier]
			local counted = math.min(spent, 20)
			ctx.Log(string.format("특이점 %d단계 — 질량 %d 소모 (피해 +%d%%)", tier, spent, math.floor(counted * per * 100 + 0.5)))
			-- 딜탱 계수 0.5(2026-10-03: 너프 뒤에도 풀세팅 38만으로 버서커 주력기와 같았다)
			return 0.5 * (1 + counted * per) * (power + base) / math.max(1, power + 10)
		end,
	},

	-- 낙하: 사용만 해도 질량 3. 이 스킬로 처치하면 5 추가(낙하 연습 +).
	Infall = {
		After = function(ctx)
			ctx.Gain(R.MASS, 3)
			local killed = 0
			for _, target in ctx.Targets do
				if not target.Alive then
					killed += 1
				end
			end
			if killed > 0 then
				ctx.Gain(R.MASS, ctx.Query("InfallKillMass", 5))
			end
			ctx.Log(string.format("질량 %d", BattleStatus.Stack(ctx.Status, R.MASS)))
		end,
	},
}

--=== 펄서 ===--

--[[
	[자기장] (`Keywords` Field): 3턴, 받는 피해 −20%, 피격 시 반사 8 + [감극].
	스택(1)은 표시용이고 지속은 보정값(출처 "자기장")이 센다. 반사·감극은 GridBattle.ResolveDodge.
]]
function BattleSkillEffects.ApplyField(status: BattleStatus.State, turns: number, reflect: number)
	BattleStatus.SpendAll(status, R.FIELD)
	BattleStatus.AddStack(status, R.FIELD, 1, 1)
	BattleStatus.RemoveBySource(status, "자기장")
	BattleStatus.AddModifier(status, "DamageTaken", -0.2, turns, "자기장")
	BattleStatus.AddModifier(status, "Reflect", reflect, turns, "자기장")
end

function BattleSkillEffects.HasField(status: BattleStatus.State): boolean
	for _, modifier in status.Modifiers do
		if modifier.Source == "자기장" then
			return true
		end
	end
	return false
end

--[[
	[감극] (`Keywords` Depolar): 최대 3, 2턴, 중첩당 받는 피해 +15%(핵파스타 ×2). 새로 걸면 지속이 갱신된다.
	지속이 끝나면 펄서 키트가 스택을 비운다. 걸린 뒤의 중첩 수를 돌려준다.
]]
function BattleSkillEffects.ApplyDepolar(status: BattleStatus.State, amount: number, turns: number, per: number): number
	if amount > 0 then
		BattleStatus.AddStack(status, R.DEPOLAR, amount, ClassResources.Cap(R.DEPOLAR))
	end
	local stacks = BattleStatus.Stack(status, R.DEPOLAR)
	BattleStatus.RemoveBySource(status, "감극")
	if stacks > 0 then
		BattleStatus.AddModifier(status, "DamageTaken", per * stacks, turns, "감극")
	end
	return stacks
end

local function depolar(ctx: Context, target: any, amount: number)
	BattleSkillEffects.ApplyDepolar(
		ctx.StatusOf(target),
		amount,
		math.floor(ctx.Query("DepolarTurns", 2)),
		ctx.Query("DepolarPer", 0.15)
	)
end

-- 자기장을 두른다. 정지 궤도면 자신이 아니라 무작위 다른 아군에게(파티).
local function giveField(ctx: Context)
	local turns = math.max(1, math.floor(ctx.Query("FieldTurns", 3)))
	local reflect = ctx.Query("FieldReflect", 8)
	local holder = ctx.Ally
	if ctx.Query("FieldOnOther", 0) >= 1 then
		local others = {}
		for _, ally in ctx.Allies do
			if ally ~= ctx.Ally then
				table.insert(others, ally)
			end
		end
		holder = others[math.floor(ctx.Rng() * #others) + 1]
		if not holder then
			ctx.Log("자기장을 받을 아군이 없다")
			return
		end
	end
	BattleSkillEffects.ApplyField(ctx.StatusOf(holder), turns, reflect)
	ctx.Log(string.format("자기장 — 받는 피해 −20%%, 반사 %d (%d턴)", math.floor(reflect), turns))
end

local pulsarEffects: { [string]: Effect } = {
	-- 자기권: [자기장]을 두르고 [공명] 1.
	Magnetosphere = {
		After = function(ctx)
			giveField(ctx)
			ctx.Gain(R.RESONATE, 1)
		end,
	},

	--[[
		수렴: [공명] 1당 피해 +30%. QTE 성공이면 피해 +20%(정밀 조율 +)·[감극] 1 더.
		md 는 "공명 수만큼 연타"지만 이 전투는 스킬 한 번이 한 타라 배율로 옮겼다.
		쌓인 [공명]을 **전부 쓴다**(플라이휠이 바닥만큼 남긴다) — 자기권·섬광으로 모으고 수렴으로 터뜨리는 박자.
	]]
	Converge = {
		Before = function(ctx)
			local stacks = BattleStatus.Stack(ctx.Status, R.RESONATE)
			local keep = math.floor(ctx.Query("ResonateFloor", 0))
			BattleStatus.SpendStack(ctx.Status, R.RESONATE, math.max(0, stacks - keep))
			local fixed = ctx.Query("ConvergeFixedStacks", -1)
			if fixed >= 0 then
				stacks = fixed
			end
			local qte = if ctx.Grade == "Success" then ctx.Query("ConvergeQteBonus", 0.2) else 0
			-- 2026-10-04: 설명대로 [공명] 수만큼 연타(없으면 한 번). 예전엔 한 번만 때리고 공명 1당 +30% 를 곱했다
			ctx.Repeat = math.max(1, stacks)
			ctx.Log(string.format("수렴 %d연타", ctx.Repeat))
			return 1 + qte
		end,
		After = function(ctx)
			local extra = 1 + (if ctx.Grade == "Success" then 1 else 0) + math.floor(ctx.Query("ConvergeDepolarBonus", 0))
			for _, target in ctx.Targets do
				if target.Alive then
					depolar(ctx, target, extra)
				end
			end
			ctx.Log(string.format("감극 +%d", extra))
		end,
	},

	--[[
		섬광: 피해 없음(잔광이 붙인다). 2턴 간 대상 명중률 −30% — 이 전투에는 적 명중 판정이 없어
		**그 적이 주는 피해 −30%** 로 옮겼다. 맞히면 [공명] 1·[자기장]. 열화된 초신성이면 적 전체.
	]]
	Flare = {
		After = function(ctx)
			local targets = ctx.Targets
			if ctx.Query("FlareAll", 0) >= 1 and ctx.Enemies then
				targets = ctx.Enemies()
			end
			local cut = ctx.Query("FlareAccuracy", 0.3)
			for _, target in targets do
				local status = ctx.StatusOf(target)
				BattleStatus.RemoveBySource(status, "섬광")
				BattleStatus.AddModifier(status, "Accuracy", -cut, 2, "섬광")
				BattleStatus.AddModifier(status, "DamageDealt", -cut, 2, "섬광")
			end
			ctx.Log(string.format("섬광 — 적 %d기 명중률 −%d%% (2턴)", #targets, math.floor(cut * 100 + 0.5)))
			if #targets > 0 then
				ctx.Gain(R.RESONATE, 1)
				giveField(ctx)
			end
		end,
	},
}

--=== 월 필그림스 ===--

--[[
	[광신] (`Keywords` Zeal): 최대 10(광신도 20), 3턴(고착 +), 중첩당 받는 피해 +3%·주는 피해 −2%,
	신앙심 10당 수치 +10%(최대 +50%). 광신도는 중첩당 수치 ×0.5, 성흔이면 디버프 대신 지속 피해
	(보정값은 지속만 세는 0 으로 건다 — 피해는 월 필그림 카드가 턴 끝에 넣는다).
	새로 걸면 지속이 갱신된다. 걸린 뒤의 중첩 수를 돌려준다.
]]
function BattleSkillEffects.ApplyZeal(
	status: BattleStatus.State,
	stacks: number,
	faith: number,
	cap: number,
	scale: number,
	turns: number,
	dot: boolean
): number
	local faithMul = 1 + math.min(math.floor(faith / 10) * 0.1, 0.5)
	if stacks > 0 then
		BattleStatus.AddStack(status, R.ZEAL, math.floor(stacks), cap)
	end
	local applied = BattleStatus.Stack(status, R.ZEAL)
	BattleStatus.RemoveBySource(status, "광신")
	if applied > 0 then
		local k = if dot then 0 else scale * faithMul
		BattleStatus.AddModifier(status, "DamageDealt", -0.02 * applied * k, turns, "광신")
		BattleStatus.AddModifier(status, "DamageTaken", 0.03 * applied * k, turns, "광신")
	end
	return applied
end

local function applyZeal(ctx: Context, target: any, stacks: number): ()
	if not target.Alive or stacks <= 0 then
		return
	end
	BattleSkillEffects.ApplyZeal(
		ctx.StatusOf(target),
		stacks,
		ctx.Ally.Faith or 0,
		math.floor(ctx.Query("ZealCap", ClassResources.Cap(R.ZEAL) or 10)),
		ctx.Query("ZealScale", 1),
		math.floor(ctx.Query("ZealTurns", 3)),
		ctx.Query("ZealDot", 0) >= 1
	)
end

local wallPilgrimEffects: { [string]: Effect } = {
	-- 못질: 광신 2 (깊은 못 +)
	Nailing = {
		After = function(ctx)
			local stacks = 2 + math.floor(ctx.Query("NailingZeal", 0))
			for _, target in ctx.Targets do
				applyZeal(ctx, target, stacks)
			end
			ctx.Log(string.format("광신 %d중첩 — 대상 %d기", stacks, #ctx.Targets))
		end,
	},
	-- 갈라진 신도: 맞은 적마다 광신 1 (메아리 +)
	SplitFlock = {
		After = function(ctx)
			local stacks = 1 + math.floor(ctx.Query("SplitFlockZeal", 0))
			for _, target in ctx.Targets do
				applyZeal(ctx, target, stacks)
			end
			ctx.Log(string.format("광신 %d중첩 — 대상 %d기", stacks, #ctx.Targets))
		end,
	},
	--[[
		합창: 대상에게 4중첩, 나머지에게 2중첩. 맞은 순서의 첫 번째를 "대상"으로 본다(앞열부터).
		전도면 적 전체가 대상이 되는 대신 중첩이 절반(`ChoraleHalf`) — 줄 밖의 적은 카드가 맞힌다.
	]]
	Chorale = {
		After = function(ctx)
			local half = ctx.Query("ChoraleHalf", 0) >= 1
			for index, target in ctx.Targets do
				local stacks = if index == 1 then 4 else 2
				applyZeal(ctx, target, if half then stacks // 2 else stacks)
			end
			ctx.Log(string.format("합창 — 대상 %d기에 광신", #ctx.Targets))
		end,
	},
}

--=== 월 메이슨 ===--

--[[
	[벽] (`Keywords` Wall): 3턴, 최대 5, 중첩당 받는 피해 −4%·자동 회피/패링 +2%, 신앙심 10당 +10%(최대 +50%).
	한 곳(ApplyWall·RefreshWall)에서 건다. 카드가 질의로 바꾸는 것:
	  WallCap(대성당 +5) · WallScale(대성당 70%, 근성 +) · WallTurns(굳히기 +) · WallAdditive(성별 — 갱신 대신 더하기)
	  WallOffense(석공의 손 — 공격 버프로: WallOffenseDealt/Crit/CritDamage) · WallNoAuto(맞물린 돌) · WallAutoBonus(빗겨내기)
	refresh=false 면 지속을 새로 세지 않고 남은 턴 그대로 중첩만 올린다(패시브 쌓기).
	지속이 끝나면 월 메이슨 키트가 스택을 비우고 `WallEnd` 훅을 쏜다(회반죽·재적층).
]]
type Query = (key: string, base: number) -> number

local function wallLeft(status: BattleStatus.State): number
	local left = 0
	for _, modifier in status.Modifiers do
		if modifier.Source == "벽" then
			left = math.max(left, modifier.Turns)
		end
	end
	return left
end

function BattleSkillEffects.RefreshWall(status: BattleStatus.State, faith: number, query: Query, turns: number?)
	local left = turns or wallLeft(status)
	BattleStatus.RemoveBySource(status, "벽")
	local stacks = BattleStatus.Stack(status, R.WALL)
	if stacks <= 0 or left <= 0 then
		return
	end
	local k = (1 + math.min(math.floor(faith / 10) * 0.1, 0.5)) * query("WallScale", 1)
	if query("WallOffense", 0) >= 1 then
		BattleStatus.AddModifier(status, "DamageDealt", query("WallOffenseDealt", 0.05) * stacks * k, left, "벽")
		BattleStatus.AddModifier(status, "CritChance", query("WallOffenseCrit", 0.02) * stacks * k, left, "벽")
		BattleStatus.AddModifier(status, "CritDamage", query("WallOffenseCritDamage", 0.07) * stacks * k, left, "벽")
		-- 표시·만료 판정용(값 0)
		BattleStatus.AddModifier(status, "DamageTaken", 0, left, "벽")
		return
	end
	BattleStatus.AddModifier(status, "DamageTaken", -0.04 * stacks * k, left, "벽")
	if query("WallNoAuto", 0) < 1 then
		BattleStatus.AddModifier(status, "AutoParry", 0.02 * stacks * k + query("WallAutoBonus", 0), left, "벽")
	end
end

function BattleSkillEffects.ApplyWall(
	status: BattleStatus.State,
	stacks: number,
	faith: number,
	query: Query,
	refresh: boolean
): number
	local cap = math.floor(query("WallCap", ClassResources.Cap(R.WALL) or 5))
	local left = wallLeft(status)
	local turns
	if not refresh and left > 0 then
		turns = left
	else
		turns = math.floor(query("WallTurns", 3))
		local additive = query("WallAdditive", 0)
		if additive > 0 and left > 0 then
			turns = left + math.floor(additive)
		end
	end
	if stacks > 0 then
		BattleStatus.AddStack(status, R.WALL, math.floor(stacks), cap)
	end
	BattleSkillEffects.RefreshWall(status, faith, query, turns)
	return BattleStatus.Stack(status, R.WALL)
end

local function applyWall(ctx: Context, ally: any, stacks: number): ()
	BattleSkillEffects.ApplyWall(ctx.StatusOf(ally), stacks, ctx.Ally.Faith or 0, ctx.Query, true)
end

-- 체력이 가장 낮은 아군(쐐기 박기)
local function lowestAlly(ctx: Context): any
	local best = ctx.Ally
	for _, ally in ctx.Allies do
		if ally.Health / math.max(1, ally.MaxHealth) < best.Health / math.max(1, best.MaxHealth) then
			best = ally
		end
	end
	return best
end

local wallMasonEffects: { [string]: Effect } = {
	-- 정 다듬기: [벽] 1 (숙련 +). 쐐기 박기면 체력이 가장 낮은 아군에게 — 그게 자신이면 더.
	ChiselWork = {
		After = function(ctx)
			local stacks = 1 + math.floor(ctx.Query("ChiselWall", 0))
			local holder = ctx.Ally
			if ctx.Query("ChiselToLowest", 0) >= 1 then
				holder = lowestAlly(ctx)
				if holder == ctx.Ally then
					stacks += math.floor(ctx.Query("ChiselSelfBonus", 0))
				end
			end
			applyWall(ctx, holder, stacks)
			ctx.Log(string.format("벽 %d중첩", BattleStatus.Stack(ctx.StatusOf(holder), R.WALL)))
		end,
	},
	-- 뒷벽 허물기: [벽] 중첩 1당 피해 +6%(후열 조준 +).
	BreakBackWall = {
		Before = function(ctx)
			-- 2026-10-04: 한 대상 51.6만 → 스킬 배율(−70%)은 빼고 기본 피해 22 → 16, 대성당 벽 상한 +15 → +8 로 잡는다(사용자)
			return 1 + BattleStatus.Stack(ctx.Status, R.WALL) * ctx.Query("BackWallPerStack", 0.06)
		end,
	},
	-- 축성: 아군 전체에게 벽 3중첩(솔로라 자신뿐). 초석이면 한 아군에게 더 많이(카드가 더한다).
	Consecrate = {
		After = function(ctx)
			local stacks = 3 + math.floor(ctx.Query("ConsecrateWall", 0))
			local targets = if ctx.Query("ConsecrateSingle", 0) >= 1 then { lowestAlly(ctx) } else ctx.Allies
			for _, ally in targets do
				applyWall(ctx, ally, stacks)
			end
			ctx.Log(string.format("축성 — 벽 %d중첩", BattleStatus.Stack(ctx.Status, R.WALL)))
		end,
	},
}

--=== 월 브레이커 ===--

--[[
	[허물 벽] (`Keywords` Ruin): 영구, 최대 5(무너진 성벽·살점 값 + — `RuinCap`), 중첩당 주는 피해 +5%·
	받는 피해 +3%(무너진 성벽 5%, 무딘 살 −). 보정값은 월 브레이커 키트가 중첩이 바뀔 때마다 다시 건다.
	여기서는 규칙대로 얻기만 한다(ctx.Gain — 상한·획득 배율 질의가 먹는다).
]]
function BattleSkillEffects.RefreshRuin(status: BattleStatus.State, query: (string, number) -> number)
	BattleStatus.RemoveBySource(status, "허물 벽")
	local stacks = BattleStatus.Stack(status, R.RUIN)
	if stacks > 0 then
		BattleStatus.AddModifier(status, "DamageDealt", 0.05 * stacks, -1, "허물 벽")
		BattleStatus.AddModifier(status, "DamageTaken", math.max(0, query("RuinTakenPer", 0.03)) * stacks, -1, "허물 벽")
	end
end

local function applyRuin(ctx: Context, stacks: number): ()
	ctx.Gain(R.RUIN, stacks + math.floor(ctx.Query("RuinGainFlat", 0)))
	BattleSkillEffects.RefreshRuin(ctx.Status, ctx.Query)
end

local wallBreakerEffects: { [string]: Effect } = {
	-- 쪼개기 / 무너뜨리기: 허물 벽 중첩당 피해 +5%는 상시 보정으로 이미 걸려 있다.
	Cleave = {},
	BringDown = {},

	--[[
		제 살 깎기 (강화). **3번 오른쪽에 따로 놓인 버튼**이다.

		md의 강화 2스킬은 아군을 때려 허물 벽을 얻는 것인데, 솔로라 때릴 아군이
		자기 자신뿐이다(필수 카드 `자해`가 명시적으로 그렇게 만든다).
		최대 체력 15%(최대 30)를 스스로 깎고 허물 벽 3중첩을 얻는다.
	]]
	SelfCarve = {
		After = function(ctx)
			-- 동정이 비율을, 자해가 피해·얻는 양을 바꾼다
			local cost = math.min(math.floor(ctx.Ally.MaxHealth * ctx.Query("SelfCarveRatio", 0.15)), 30)
			cost = math.floor(cost * ctx.Query("SelfCarveHarm", 1) + 0.5)
			if cost > 0 then
				ctx.Damage(ctx.Ally, cost, "True", false)
			end
			ctx.Ally.LastSelfCarve = cost
			applyRuin(ctx, math.floor(ctx.Query("SelfCarveRuin", 3)))
			ctx.Log(
				string.format(
					"제 살 깎기 — 체력 %d 소모, 허물 벽 %d중첩",
					cost,
					BattleStatus.Stack(ctx.Status, R.RUIN)
				)
			)
		end,
	},

	-- 허물다: 허물 벽 전부 소모. 소모 중첩 1당 피해 +12%(평탄화 7%). 만가면 덜 쓰지만 배율은 전부로.
	TearDown = {
		Before = function(ctx)
			local stacks = BattleStatus.Stack(ctx.Status, R.RUIN)
			local keep = math.min(stacks, math.floor(ctx.Query("TearDownKeep", 0)))
			BattleStatus.SpendStack(ctx.Status, R.RUIN, stacks - keep)
			BattleSkillEffects.RefreshRuin(ctx.Status, ctx.Query)
			local per = ctx.Query("TearDownPerStack", 0.12)
			ctx.Log(string.format("허물다 — 허물 벽 %d 소모 (피해 +%d%%)", stacks - keep, math.floor(stacks * per * 100 + 0.5)))
			return 1 + stacks * per
		end,
	},
}

--=== 연금술사 ===--

--[[
	[꽉 찬 병] 하나가 대상에게 거는 것. 독 10(독성 강화) · 화상 10(네이팜) · 기름 10.
	던지기와 카드(가득 찬 가방 — 두 병째)가 같이 쓴다.
]]
function BattleSkillEffects.ThrowBottle(status: BattleStatus.State, bottle: string, query: (string, number) -> number)
	if bottle == R.POISON_BOTTLE then
		BattleStatus.AddPoison(status, math.floor(query("PoisonBottleAmount", 10)))
	elseif bottle == R.FIRE_BOTTLE then
		BattleStatus.AddBurn(status, math.floor(query("FireBottleAmount", 10)))
	elseif bottle == R.OIL_BOTTLE then
		BattleStatus.AddOil(status, 10)
	end
end

local alchemistEffects: { [string]: Effect } = {
	--[[
		다지기: [약재]를 쓴다. 사용자 지시대로 **무조건 최대치**를 쓴다.

		소모량마다 이득과 대가가 같이 커진다(md의 표 그대로).
		  1개 → 원액 1
		  2개 → 원액 2, 주는 피해 +10%, 받는 피해 +10%
		  3개 → 원액 3, 주는 피해 +15%, 받는 피해 +15%
		  4개 → 원액 4, 주는 피해 +25%, 받는 피해 +25%
	]]
	Grind = {
		After = function(ctx)
			local status = ctx.Status
			local herbs = math.min(BattleStatus.Stack(status, R.HERB), 4)
			if herbs <= 0 then
				ctx.Log("약재가 없다")
				return
			end
			BattleStatus.SpendStack(status, R.HERB, herbs)
			ctx.Gain(R.EXTRACT, herbs + math.floor(ctx.Query("GrindExtractBonus", 0)))

			local bonus = 0
			if herbs >= 4 then
				bonus = 0.25
			elseif herbs >= 3 then
				bonus = 0.15
			elseif herbs >= 2 then
				bonus = 0.1
			end
			if bonus > 0 then
				-- 로우리스크 로우리턴: 부작용(받는 피해 증가)이 받는 피해 감소로 뒤집힌다
				local flip = if ctx.Query("SideFlip", 0) >= 1 then -1 else 1
				BattleStatus.AddModifier(status, "DamageDealt", bonus, -1, "다지기")
				BattleStatus.AddModifier(status, "DamageTaken", bonus * flip, -1, "다지기")
			end
			ctx.Log(
				string.format(
					"다지기 %d — 원액 %d · 주는/받는 피해 +%d%%",
					herbs,
					BattleStatus.Stack(status, R.EXTRACT),
					bonus * 100
				)
			)
		end,
	},

	--[[
		섞기: [원액]을 전부 [빈 병]과 함께 태워 [꽉 찬 병]을 만든다.

		사용자 지시: **각 33% 확률로 독 병 / 화염병 / 기름 병 중 하나를 확정으로**
		하나 만든다. (회복 병은 이 목록에 없다)
	]]
	Mix = {
		After = function(ctx)
			local status = ctx.Status
			if ctx.Query("MixLocked", 0) >= 1 then
				ctx.Log("원샷 — 아직 병을 만들 수 없다")
				return
			end
			local extract = BattleStatus.Stack(status, R.EXTRACT)
			local bottles = math.min(extract, BattleStatus.Stack(status, R.EMPTY_BOTTLE))
			if bottles <= 0 then
				ctx.Log("원액이나 빈 병이 없다")
				return
			end
			BattleStatus.SpendStack(status, R.EXTRACT, bottles)
			BattleStatus.SpendStack(status, R.EMPTY_BOTTLE, bottles)

			local kinds = { R.POISON_BOTTLE, R.FIRE_BOTTLE, R.OIL_BOTTLE }
			local made = { 0, 0, 0 }
			for _ = 1, bottles do
				local pick = math.min(3, math.floor(ctx.Rng() * 3) + 1)
				made[pick] += 1
				ctx.Gain(kinds[pick], 1)
			end
			ctx.Log(
				string.format("섞기 %d병 — 독 %d · 화염 %d · 기름 %d", bottles, made[1], made[2], made[3])
			)
		end,
	},

	--[[
		던지기: [꽉 찬 병] 하나를 던진다. 그 병의 상태이상을 건다.
		  독 병   독 10
		  화염병  화상 10
		  기름 병 기름 10턴

		강화 스킬 `중독`은 3번 오른쪽에 **따로 놓인 버튼**이다(요청). 예전에는 이
		스킬이 조건에 따라 중독으로 바뀌었는데, 그러면 평범한 던지기를 쓸 수 없었다.
	]]
	Throw = {
		After = function(ctx)
			local status = ctx.Status
			local kinds = { R.POISON_BOTTLE, R.FIRE_BOTTLE, R.OIL_BOTTLE }
			local chosen: string? = nil
			for _, kind in kinds do
				if BattleStatus.Stack(status, kind) > 0 then
					chosen = kind
					break
				end
			end
			if not chosen then
				ctx.Log("던질 병이 없다")
				return
			end
			BattleStatus.SpendStack(status, chosen, 1)
			ctx.Ally.LastBottle = chosen
			for _, target in ctx.Targets do
				BattleSkillEffects.ThrowBottle(ctx.StatusOf(target), chosen, ctx.Query)
			end
			ctx.Log(string.format("%s 사용", ClassResources.Label(chosen)))
		end,
	},

	--[[
		중독 (강화). 꽉 찬 병 3개 이상에서 열린다.

		보유한 병을 전부 태우고 **절반을 돌려받는다.** 종류마다 자신에게 버프와
		대가(체력 감소)가 함께 붙는다 — md의 `스킬 3-1` 표 그대로다.
	]]
	Poisoning = {
		Before = function(ctx)
			local status = ctx.Status
			local poison = BattleStatus.SpendAll(status, R.POISON_BOTTLE)
			local fire = BattleStatus.SpendAll(status, R.FIRE_BOTTLE)
			local oil = BattleStatus.SpendAll(status, R.OIL_BOTTLE)

			-- 절반을 돌려받는다(원샷이면 전부).
			local all = ctx.Query("PoisoningReturnAll", 0) >= 1
			local function back(n: number): number
				return if all then n else n // 2
			end
			BattleStatus.AddStack(status, R.POISON_BOTTLE, back(poison), ClassResources.Cap(R.POISON_BOTTLE))
			BattleStatus.AddStack(status, R.FIRE_BOTTLE, back(fire), ClassResources.Cap(R.FIRE_BOTTLE))
			BattleStatus.AddStack(status, R.OIL_BOTTLE, back(oil), ClassResources.Cap(R.OIL_BOTTLE))

			-- 과다복용 ×2. 로우리스크면 체력 감소·받는 피해 증가가 받는 피해 감소로 뒤집힌다.
			local scale = ctx.Query("PoisoningScale", 1)
			local flip = ctx.Query("SideFlip", 0) >= 1
			local function cost(ratio: number)
				local amount = math.floor(ctx.Ally.MaxHealth * ratio * scale)
				if amount <= 0 then
					return
				end
				if flip then
					BattleStatus.AddModifier(status, "DamageTaken", -amount / math.max(1, ctx.Ally.MaxHealth), 3, "중독")
				else
					ctx.Damage(ctx.Ally, amount, "True", false)
				end
			end
			local bonus = 0
			if poison > 0 then
				-- 체력 30% 감소(강철 위장 −), 주는 피해 +15%. 이 효과로 죽지는 않는다.
				cost(0.3 * ctx.Query("PoisonSelfScale", 1))
				bonus += 0.15
			end
			if fire > 0 then
				cost(0.05)
				bonus += 0.1
			end
			if oil > 0 then
				cost(0.05)
				bonus += 0.05
				if fire > 0 then
					-- 화염병과 같이 태우면 추가 대가와 추가 화력.
					cost(0.2)
					bonus += 0.15
				end
			end
			BattleStatus.AddModifier(status, "DamageDealt", bonus * scale, -1, "중독")
			-- 3개 이상 태웠으므로 추가 대가가 붙는다(md: 3턴 받는 피해 증가).
			BattleStatus.AddModifier(status, "DamageTaken", (if flip then -0.5 else 0.5) * scale, 3, "중독")
			ctx.Log(string.format("중독 — 병 %d 소모, 주는 피해 +%d%%", poison + fire + oil, bonus * 100))
			return 1.5
		end,
		After = function(ctx)
			-- 태운 종류에 맞춰 대상에게도 상태이상을 남긴다.
			for _, target in ctx.Targets do
				local targetStatus = ctx.StatusOf(target)
				BattleStatus.AddPoison(targetStatus, 10)
				BattleStatus.AddBurn(targetStatus, 10)
				BattleStatus.AddOil(targetStatus, 10)
			end
		end,
	},
}

--=== 광전사 ===--

--[[
	자해. 카드가 줄인다(짙은 피 `SelfHarmScale`). 이 피해로는 죽지 않는다.
	체력이 깎이면 패시브 다혈질이 [분노]를 준다(CardEffects/Berserker).
]]
local function selfHarm(ctx: Context, amount: number)
	local scaled = math.floor(amount * ctx.Query("SelfHarmScale", 1) + 0.5)
	if scaled > 0 then
		ctx.Damage(ctx.Ally, scaled, "True", false)
	end
end

local berserkerEffects: { [string]: Effect } = {
	--[[
		분쇄: [분노]를 쓰지 않는다. 분노 1당 3턴 간 대상 받는 피해 +10%. 적중 시 출혈 1, 자신 체력 3, 분노 +1.
	]]
	BloodCrash = {
		After = function(ctx)
			local rage = BattleStatus.Stack(ctx.Status, R.RAGE)
			local hit = 0
			for _, target in ctx.Targets do
				local status = ctx.StatusOf(target)
				BattleStatus.RemoveBySource(status, "분쇄")
				if rage > 0 then
					BattleStatus.AddModifier(status, "DamageTaken", 0.1 * rage, 3, "분쇄")
				end
				BattleStatus.AddBleed(status, 1)
				hit += 1
			end
			if hit > 0 then
				selfHarm(ctx, 3)
				ctx.Gain(R.RAGE, 1)
				ctx.Log(string.format("분쇄 — 대상 받는 피해 +%d%% (3턴)", rage * 10))
			end
		end,
	},

	-- 횡베기: 분노를 (보유/2, 반올림) 소모, 소모 1당 피해 +20%. 적중 시 출혈 2, 맞힌 적마다 자신 체력 3.
	DoubleSlash = {
		Before = function(ctx)
			local rage = BattleStatus.Stack(ctx.Status, R.RAGE)
			local spend = math.floor(rage / 2 + 0.5)
			BattleStatus.SpendStack(ctx.Status, R.RAGE, spend)
			return 1 + 0.2 * spend
		end,
		After = function(ctx)
			for _, target in ctx.Targets do
				BattleStatus.AddBleed(ctx.StatusOf(target), 2)
				selfHarm(ctx, 3)
			end
		end,
	},

	--[[
		종베기: 분노 전부 소모, 1당 피해 +40%(2026-10-03, 예전 20%). 적중 시 출혈 3. (맞힌 적 / 2)만큼 분노를 돌려받는다.
		맞힌 적마다 자신 체력 5(피의 대가 10), 그리고 (최종 피해 / 5)만큼 체력.
	]]
	Burst = {
		Before = function(ctx)
			local spent = BattleStatus.SpendAll(ctx.Status, R.RAGE)
			-- 2026-10-03 사용자: 2스킬(횡베기)과 딜이 비슷 → 소모 분노 1당 +20% → +40%
			ctx.Log(string.format("종베기 — 분노 %d 소모 (피해 +%d%%)", spent, spent * 40))
			return 1 + 0.4 * spent
		end,
		After = function(ctx)
			local perHit = ctx.Query("BurstSelfPerHit", 5)
			for _, target in ctx.Targets do
				BattleStatus.AddBleed(ctx.StatusOf(target), 3)
				selfHarm(ctx, perHit)
			end
			ctx.Gain(R.RAGE, math.floor(#ctx.Targets / 2))
			selfHarm(ctx, math.floor((ctx.TotalDealt or 0) / 5))
		end,
	},
}

--=== 공용 (모든 직업) ===--

--[[
	가드와 명상. 요청받은 수치를 그대로 쓴다.

	  가드  이번 턴 받는 피해 70% 감소
	  명상  이번 턴 받는 피해 25% 증가, 스테미나 30 즉시 회복

	"이번 턴"이라 Turns = 1이다. `EndTurn`이 한 번 깎으면 사라진다.
]]
local commonEffects: { [string]: Effect } = {
	Guard = {
		After = function(ctx)
			BattleStatus.AddModifier(ctx.Status, "DamageTaken", -0.7, 1, "가드")
			ctx.Log("가드 — 이번 턴 받는 피해 70% 감소")
		end,
	},
	Meditate = {
		After = function(ctx)
			BattleStatus.AddModifier(ctx.Status, "DamageTaken", 0.25, 1, "호흡")
			local gained = ctx.RestoreStamina(30)
			-- `%%`로 이스케이프해야 한다. `25%`로 두면 string.format이 변환 지시자로 읽는다.
			ctx.Log(string.format("호흡 — 스테미나 +%d, 이번 턴 받는 피해 25%% 증가", gained))
		end,
	},
}

--=== 표 ===--

local effects: { [string]: Effect } = {}

local function register(source: { [string]: Effect })
	for id, effect in source do
		effects[id] = effect
	end
end

register(musicianEffects)
register(duelistEffects)
register(quasarEffects)
register(pulsarEffects)
register(wallPilgrimEffects)
register(wallMasonEffects)
register(wallBreakerEffects)
register(alchemistEffects)
register(berserkerEffects)
register(commonEffects)

function BattleSkillEffects.Get(skillId: string): Effect?
	return effects[skillId]
end

--[[
	이 직업이 **지금 쓸 수 있는 강화 스킬**의 Id. 조건이 안 차면 nil.

	3번을 갈아 끼우지 않고, 3번 오른쪽에 버튼이 하나 더 생긴다(요청). 그래서
	"바꿔치기"가 아니라 "추가로 열린다"는 뜻의 이름을 쓴다.
]]
function BattleSkillEffects.UpgradeFor(classId: string, status: BattleStatus.State): string?
	if classId == "Duelist" then
		-- 준비 자세를 잡은 다음 턴에만 연계가 열린다.
		return if BattleStatus.Stack(status, R.READY) >= 1 then "PointBlank" else nil
	elseif classId == "Musician" then
		return if totalNotes(status) >= 16 then "CrescendoAlForte" else nil
	elseif classId == "Alchemist" then
		local bottles = BattleStatus.Stack(status, R.POISON_BOTTLE)
			+ BattleStatus.Stack(status, R.FIRE_BOTTLE)
			+ BattleStatus.Stack(status, R.OIL_BOTTLE)
		return if bottles >= 3 then "Poisoning" else nil
	elseif classId == "WallBreaker" then
		--[[
			제 살 깎기는 조건이 없다. md가 조건을 적지 않았고, 이것이 이 직업이
			[허물 벽]을 마련하는 유일한 수단이라 항상 열려 있어야 한다.
		]]
		return "SelfCarve"
	end
	return nil
end

--[[
	지금 이 스킬이 화면에 뭐라고 보여야 하는지. 바뀔 게 없으면 nil.

	같은 슬롯에서 **모드만** 달라지는 것에 쓴다. 지금은 퀘이사 붕괴뿐이다
	(차징 중인지 발동 차례인지 버튼에 보여야 한다).
]]
function BattleSkillEffects.DisplayName(skillId: string, status: BattleStatus.State): string?
	if skillId == "Collapse" and BattleStatus.Stack(status, R.CHARGE) > 0 then
		return string.format("붕괴 발동 (차징 %d)", BattleStatus.Stack(status, R.CHARGE))
	end
	return nil
end

-- 효과가 붙어 있는 스킬 Id 전부. 테스트가 스킬 표와 대조하는 데 쓴다.
function BattleSkillEffects.Ids(): { string }
	local ids: { string } = {}
	for id in effects do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

--[[
	전투를 시작할 때 자원을 채운다. 패시브에 적힌 초기값이다.
]]
function BattleSkillEffects.ApplyStartingStacks(status: BattleStatus.State, classId: string): ()
	for id, amount in ClassResources.StartingStacks(classId) do
		BattleStatus.AddStack(status, id, amount, ClassResources.Cap(id))
	end
	-- 결투사는 공격 태세로 시작한다. 보정값은 키트가 건다(SetStance 주석).
	if classId == "Duelist" then
		BattleSkillEffects.SetStance(status, true)
	end
end

return BattleSkillEffects
