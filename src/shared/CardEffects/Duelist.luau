--!strict
--[[
	결투사 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(Duelist_Kit) — `유저 아이디어(직업).md` 결투사
	  [집중] 스택 1당 받는 피해 −0.5%, 피해 +1%, 회피 시간 +2.5% (무명검이 스택당 효과를 줄인다)
	  공격 태세  받는 피해 +15%, 피해 +(20+집중)%, 치명 확률 +10%, 적중 시 출혈 1.
	             집중 5 이상에서 막지도 못하고 맞으면 집중 3을 써서 자동 패링
	  방어 태세  받는 피해 −30%, 피해 −45%, (5×집중)% 확률 자동 패링(최대 30%)
	  태세 효과 배율(StanceBoost)은 양날·자세 낮추기가, 페널티 감소는 공세·수세가 준다.
	  철벽(방어 고정)·광검(공격 고정)은 태세를 바꿀 수 없게 막고(StanceLocked) 해당 태세로 되돌린다.
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function isAttack(c: Card): boolean
	return H.Stack(c, R.STANCE_ATTACK) > 0
end

local function focus(c: Card): number
	return H.Stack(c, R.FOCUS)
end

local function gainFocus(c: Card, amount: number): number
	return H.Gain(c, R.FOCUS, amount)
end

local function isReady(c: Card): boolean
	return H.Stack(c, R.READY) >= 1
end

local function bleed(_c: Card, unit: any, amount: number)
	if unit and unit.Alive and amount > 0 then
		BattleStatus.AddBleed(unit.Status, math.floor(amount))
	end
end

local function refreshStance(c: Card)
	local status = H.Status(c)
	BattleStatus.RemoveBySource(status, "태세")
	BattleStatus.RemoveBySource(status, "집중")
	-- 필수 카드가 태세를 정해 두었으면 그쪽으로 되돌린다
	local forced = Q(c.Rt, "ForcedStance", 0) -- 1 공격, −1 방어
	if forced > 0 and not isAttack(c) then
		BattleSkillEffects.SetStance(status, true)
	elseif forced < 0 and isAttack(c) then
		BattleSkillEffects.SetStance(status, false)
	end
	local stacks = focus(c)
	local per = Q(c.Rt, "FocusScale", 1)
	if stacks > 0 then
		BattleStatus.AddModifier(status, "DamageTaken", -0.005 * stacks * per, -1, "집중")
		BattleStatus.AddModifier(status, "DamageDealt", 0.01 * stacks * per, -1, "집중")
		BattleStatus.AddModifier(status, "ParryWindow", 0.025 * stacks * per, -1, "집중")
	end
	local boost = 1 + Q(c.Rt, "StanceBoost", 0)
	if isAttack(c) then
		BattleStatus.AddModifier(status, "DamageTaken", math.max(0, 0.15 - Q(c.Rt, "AttackTakenCut", 0)), -1, "태세")
		BattleStatus.AddModifier(status, "DamageDealt", (0.2 + 0.01 * stacks * per) * boost, -1, "태세")
		BattleStatus.AddModifier(status, "CritChance", 0.1 * boost, -1, "태세")
	else
		BattleStatus.AddModifier(status, "DamageTaken", -0.3 * boost, -1, "태세")
		BattleStatus.AddModifier(status, "DamageDealt", math.min(0, -0.45 + Q(c.Rt, "DefenseDealtCut", 0)), -1, "태세")
		BattleStatus.AddModifier(status, "AutoParry", math.min(0.05 * stacks * per, 0.3) * boost, -1, "태세")
	end
end

local M: { [string]: any } = {}

--=== 키트 ===--

M.Duelist_Kit = {
	Rules = {
		FocusCap = function(_c: Card, value: number): number
			return value
		end,
	},
	BattleStart = function(c: Card)
		refreshStance(c)
	end,
	TurnStart = function(c: Card)
		refreshStance(c)
	end,
	Stance = function(c: Card)
		refreshStance(c)
	end,
	Gain = function(c: Card, id: string)
		if id == R.FOCUS then
			refreshStance(c)
		end
	end,
	Spend = function(c: Card, id: string)
		if id == R.FOCUS then
			refreshStance(c)
		end
	end,
	-- 공격 태세: 적중 시 짧은 출혈
	Hit = function(c: Card, info: any)
		if isAttack(c) and info.Damage > 0 then
			bleed(c, info.Target, 1)
		end
	end,
	-- 공격 태세 · 집중 5 이상: 막지 못하고 맞으면 집중 3을 써서 자동 패링
	BeforeTaken = function(c: Card, info: any)
		if info.Grade ~= "Fail" or not isAttack(c) or focus(c) < 5 then
			return false
		end
		local cost = math.floor(Q(c.Rt, "FocusParryCost", 3))
		if cost > 0 then
			H.Spend(c, R.FOCUS, cost)
		end
		info.Grade = "Success"
		info.Auto = true
		H.Log(c, if cost > 0 then string.format("집중 %d — 자동 패링", cost) else "집중 — 자동 패링(소모 없음)")
		return true
	end,
}

--=== 패시브 ===--

-- 간파: 4번 피격될 때마다 다음 공격을 확정으로 패링
M.Duelist_Read = {
	Taken = function(c: Card)
		c.Mem.hits = (c.Mem.hits or 0) + 1
		if c.Mem.hits >= 4 then
			c.Mem.hits = 0
			c.Mem.ready = true
		end
	end,
	BeforeTaken = function(c: Card, info: any)
		if c.Mem.ready and info.Grade ~= "Success" then
			c.Mem.ready = false
			info.Grade = "Success"
			H.Log(c, "간파 — 확정 패링")
			return true
		end
		return false
	end,
}

-- 흘려 받기: 방어의 피해 감소가 절반(50% → 25% 감소), 대신 회피 시간 +10%
M.Duelist_Slip = {
	TurnStart = function(c: Card)
		H.Mod(c, "ParryWindow", 0.1, 1)
	end,
	BeforeTaken = function(_c: Card, info: any)
		if info.Grade == "Partial" then
			info.Mult *= 1.5
		end
	end,
}

-- 사전 전략: 적이 3기 이하면 피해 +5%, 4기 이상이면 받는 피해 −5% (매 턴 다시 판정)
M.Duelist_Count = {
	TurnStart = function(c: Card)
		if #H.Enemies(c) <= 3 then
			H.Mod(c, "DamageDealt", 0.05, 1)
		else
			H.Mod(c, "DamageTaken", -0.05, 1)
		end
	end,
}

--=== 필수 ===--

-- 철벽: 공격 태세·공격 스킬 없음. 매 턴 도발 {1}. 패링 못 하면 집중 {1}을 얻고 반드시 방어.
-- 피격 시 그 스킬 기본 피해의 {25}%를 반사. 패링 불가 스킬을 전투당 {1}회 패링(지금 적에게는 없다).
M.Duelist_E_IronWall = {
	Rules = {
		ForcedStance = function(_c: Card, _value: number): number
			return -1
		end,
		StanceLocked = function(_c: Card, _value: number): number
			return 1
		end,
		NoAttackSkills = function(_c: Card, _value: number): number
			return 1
		end,
	},
	TurnStart = function(c: Card)
		local ally = H.Ally(c)
		ally.Taunt = math.max(ally.Taunt, math.floor(c.V(1)))
	end,
	BeforeTaken = function(c: Card, info: any)
		if info.Grade == "Fail" then
			info.Grade = "Partial"
			gainFocus(c, math.floor(c.V(2)))
			return true
		end
		return false
	end,
	Defend = function(c: Card, info: any)
		local attacker = info.Attacker
		if attacker and attacker.Alive and info.Skill then
			local amount = (attacker.Power + info.Skill.Damage) * c.P(3)
			H.Hurt(c, attacker, amount, "Physical")
			return true
		end
		return false
	end,
}

-- 광검: 방어 태세 없음. 받는 피해 +{25}%, 주는 피해 +{40}%, 치명 피해 +{15}%.
-- 공격 스킬로 적을 처치하면 피해 {75}% 감소한 채 무작위 대상에게 한 번 더(턴당 1회)
M.Duelist_E_LightBlade = {
	Rules = {
		ForcedStance = function(_c: Card, _value: number): number
			return 1
		end,
		StanceLocked = function(_c: Card, _value: number): number
			return 1
		end,
	},
	BattleStart = function(c: Card)
		H.Mod(c, "DamageTaken", c.P(1), -1)
		H.Mod(c, "DamageDealt", c.P(2), -1)
		H.Mod(c, "CritDamage", c.P(3), -1)
	end,
	AfterSkill = function(c: Card, info: any)
		if info.Kills <= 0 or info.Skill.Damage <= 0 or not CardEffects.PerTurn(c, "echo", 1) then
			return false
		end
		local hits = 0
		for _, group in info.Hits do
			hits += #group
		end
		local enemies = H.Enemies(c)
		if hits == 0 or #enemies == 0 then
			return false
		end
		local target = enemies[math.floor(H.Rng(c) * #enemies) + 1]
		local amount = info.Total / hits * math.max(0, 1 - c.P(4))
		H.Hurt(c, target, amount, "Physical")
		H.Log(c, string.format("%s에게 한 번 더 — %d", target.Name, math.floor(amount)))
		return true
	end,
}

-- 양날의 검: 매 턴 태세가 강제로 바뀐다. 바뀔 때마다 집중 {1} 소모, 태세 효과 +{30}%, 태세별 효과
--   공격: 스테미나 +{5}, 공격 스킬 기본 피해 +{3}
--   방어: 보호막 {5}, 자동 패링 +{10}%, 공격 대상이 되면 공격자에게 출혈 {5}
M.Duelist_E_DoubleEdge = {
	Rules = {
		StanceLocked = function(_c: Card, _value: number): number
			return 1
		end,
		StanceBoost = function(c: Card, value: number): number
			return value + c.P(2)
		end,
	},
	TurnStart = function(c: Card, turn: number)
		if turn <= 1 then
			return false
		end
		local status = H.Status(c)
		BattleSkillEffects.SetStance(status, not isAttack(c))
		H.Spend(c, R.FOCUS, math.floor(c.V(1)))
		H.Clear(c, "def")
		if isAttack(c) then
			local ally = H.Ally(c)
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(c.V(3)))
		else
			H.Shield(c, c.V(5))
			H.Mod(c, "AutoParry", c.P(6), 1, "def")
		end
		refreshStance(c)
		return true
	end,
	BeforeSkill = function(c: Card, info: any)
		if isAttack(c) and info.Skill.Damage > 0 then
			info.Flat += c.V(4)
		end
	end,
	BeforeTaken = function(c: Card, info: any)
		if not isAttack(c) then
			bleed(c, info.Attacker, c.V(7))
		end
	end,
}

-- 무명검: 집중 상한 {10} → {20}, 스택당 효과 {40}% 감소
M.Duelist_E_NamelessBlade = {
	Rules = {
		FocusCap = function(c: Card, value: number): number
			return math.max(value, c.V(2))
		end,
		FocusScale = function(c: Card, value: number): number
			return value * math.max(0, 1 - c.P(3))
		end,
	},
}

--=== 희귀 ===--

-- 방혈: 출혈을 걸 때마다 {3}턴 간 치명 피해 +{2.5}%, 최대 {5}중첩
M.Duelist_R_Bloodletting = {
	Status = function(c: Card, info: any)
		if info.Kind ~= "Bleed" then
			return false
		end
		local turn = H.State(c).Turn
		local list = c.Mem.list or {}
		c.Mem.list = list
		for index = #list, 1, -1 do
			if list[index] < turn then
				table.remove(list, index)
			end
		end
		if #list < c.V(3) then
			table.insert(list, turn + c.V(1) - 1)
		end
		H.Clear(c)
		H.Mod(c, "CritDamage", #list * c.P(2), -1)
		return true
	end,
	TurnStart = function(c: Card, turn: number)
		local list = c.Mem.list or {}
		for index = #list, 1, -1 do
			if list[index] < turn then
				table.remove(list, index)
			end
		end
		H.Clear(c)
		if #list > 0 then
			H.Mod(c, "CritDamage", #list * c.P(2), -1)
		end
	end,
}

-- 불소모: 집중이 최대일 때 자동 패링이 {3}턴에 한 번 집중을 쓰지 않는다
M.Duelist_R_NoSpend = {
	Rules = {
		FocusParryCost = function(c: Card, value: number): number
			local cap = Q(c.Rt, "FocusCap", R.Cap(R.FOCUS) or 10)
			local turn = H.State(c).Turn
			if focus(c) >= cap and turn >= (c.Mem.readyTurn or 0) then
				c.Mem.readyTurn = turn + math.max(1, math.floor(c.V(1)))
				return 0
			end
			return value
		end,
	},
}

-- 기회 노리기: 패링 성공 시 공격자에게 `앞뒤관통`(9 × 2)
M.Duelist_R_Counter = {
	Defend = function(c: Card, info: any)
		if info.Grade ~= "Success" or not info.Attacker or not info.Attacker.Alive then
			return false
		end
		local ally = H.Ally(c)
		local amount = (ally.Power + 9) * (1 + BattleStatus.Total(ally.Status, "DamageDealt"))
		H.Hurt(c, info.Attacker, amount, "Physical")
		H.Hurt(c, info.Attacker, amount, "Physical")
		H.Log(c, string.format("반격 앞뒤관통 %d × 2", math.floor(amount)))
		return true
	end,
}

-- 발끝 전환: 태세를 바꾼 턴에 회피 시간 +{5}%
M.Duelist_R_Pivot = {
	Stance = function(c: Card)
		H.Mod(c, "ParryWindow", c.P(1), 1)
		return true
	end,
}

-- 집중 호흡: {3}턴마다 집중 {1}
M.Duelist_R_FocusBreath = {
	TurnStart = function(c: Card, turn: number)
		local every = math.max(1, math.floor(c.V(1)))
		if turn > 1 and (turn - 1) % every == 0 then
			gainFocus(c, math.floor(c.V(2)))
			return true
		end
		return false
	end,
}

-- 페인트: 태세를 바꾼 직후 첫 공격 피해 +{20}%(회피 불가 — 이 게임의 적은 회피하지 않는다)
M.Duelist_R_Feint = {
	Stance = function(c: Card)
		c.Mem.armed = true
	end,
	BeforeSkill = function(c: Card, info: any)
		if c.Mem.armed and info.Skill.Damage > 0 then
			c.Mem.armed = false
			info.Bonus += c.P(1)
		end
	end,
}

-- 실혈: 출혈 상태의 적에게 주는 피해 +{15}%
M.Duelist_R_BloodLoss = {
	BeforeHit = function(c: Card, info: any)
		if info.Target.Status.Bleed > 0 then
			info.Bonus += c.P(1)
		end
	end,
}

-- 흘리기: 패링 실패 시 받는 피해 −{20}%
M.Duelist_R_Slip = {
	BeforeTaken = function(c: Card, info: any)
		if info.Grade ~= "Success" then
			info.Mult *= math.max(0, 1 - c.P(1))
		end
	end,
}

-- 날 세우기: 집중 {5} 이상이면 적의 받는 피해 감소를 {25}%만큼 무시
M.Duelist_R_HonedEdge = {
	BeforeHit = function(c: Card, info: any)
		if focus(c) < c.V(1) then
			return
		end
		local reduction = -BattleStatus.Total(info.Target.Status, "DamageTaken")
		if reduction > 0 then
			info.Bonus += math.min(reduction, c.P(2))
		end
	end,
}

-- 경계: 준비 자세 동안 패링에 성공하면 집중 {1}(턴당 {1}회)
M.Duelist_R_Vigil = {
	Defend = function(c: Card, info: any)
		if info.Grade == "Success" and isReady(c) and CardEffects.PerTurn(c, "vigil", math.floor(c.V(2))) then
			gainFocus(c, math.floor(c.V(1)))
			return true
		end
		return false
	end,
}

--=== 일반 ===--

-- 숨 고르기: 패링할 때마다 스테미나 +{2}
M.Duelist_C_CatchBreath = {
	Defend = function(c: Card, info: any)
		if info.Grade == "Success" then
			local ally = H.Ally(c)
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(c.V(1)))
			return true
		end
		return false
	end,
}

-- 전환 보호: 태세를 바꾼 턴에 받는 피해 −{8}%
M.Duelist_C_SwitchGuard = {
	Stance = function(c: Card)
		H.Mod(c, "DamageTaken", -c.P(1), 1)
		return true
	end,
}

-- 예열: 전투 시작 시 집중 {1}
M.Duelist_C_WarmUp = {
	BattleStart = function(c: Card)
		gainFocus(c, math.floor(c.V(1)))
		return true
	end,
}

-- 얕은 상처: `앞뒤관통`이 출혈 {1}
M.Duelist_C_ShallowCut = {
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Id ~= "FrontBackPierce" then
			return false
		end
		for _, group in info.Hits do
			for _, hit in group do
				local unit = H.State(c).Units[hit.Id]
				bleed(c, unit, c.V(1))
			end
		end
		return true
	end,
}

-- 평정: 집중 1당 받는 피해 −{0.2}% 더
M.Duelist_C_Composure = {
	BeforeTaken = function(c: Card, info: any)
		info.Mult *= math.max(0, 1 - c.P(1) * focus(c))
	end,
}

-- 반동: 패링 직후의 공격은 스테미나를 {80}%만 쓴다
M.Duelist_C_FlowThrough = {
	Rules = {
		StaminaCost = function(c: Card, value: number): number
			return if c.Mem.discount then value * c.P(1) else value
		end,
	},
	Defend = function(c: Card, info: any)
		if info.Grade == "Success" then
			c.Mem.discount = true
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Damage > 0 then
			c.Mem.discount = false
		end
	end,
}

-- 급소 찾기: 출혈 상태의 적을 처치하면 다음 공격 치명 확률 +{5}%
M.Duelist_C_FindTheSpot = {
	Kill = function(c: Card, info: any)
		if info.Target.Status.Bleed > 0 then
			c.Mem.crit = c.P(1)
			return true
		end
		return false
	end,
	BeforeSkill = function(c: Card, info: any)
		if c.Mem.crit and info.Skill.Damage > 0 then
			info.Crit += c.Mem.crit
			c.Mem.crit = nil
		end
	end,
}

-- 공세: 공격 태세의 받는 피해 증가 −{5}%p
M.Duelist_C_Offense = {
	Rules = {
		AttackTakenCut = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 수세: 방어 태세의 피해 감소 −{5}%p
M.Duelist_C_Defense = {
	Rules = {
		DefenseDealtCut = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 결착: 적을 처치하면 집중 {2} 더
M.Duelist_C_Conclusion = {
	Kill = function(c: Card)
		gainFocus(c, math.floor(c.V(1)))
		return true
	end,
}

-- 파수: 전열(1~2열)에서 회피 시간 +{8}%, 인접 아군 +{4}%(파티)
M.Duelist_C_Sentry = {
	TurnStart = function(c: Card)
		if H.IsFront(c) then
			H.Mod(c, "ParryWindow", c.P(1), 1)
		end
	end,
	Move = function(c: Card)
		H.Clear(c)
		if H.IsFront(c) then
			H.Mod(c, "ParryWindow", c.P(1), 1)
		end
	end,
}

-- 자세 낮추기: 같은 태세를 두 턴 이상 유지하면 태세 효과가 턴당 {10}%, 최대 {30}%까지 증가
M.Duelist_C_LowStance = {
	Rules = {
		StanceBoost = function(c: Card, value: number): number
			return value + math.min((c.Mem.held or 0) * c.P(1), c.P(2))
		end,
	},
	TurnStart = function(c: Card)
		local now = isAttack(c)
		if c.Mem.last == now then
			c.Mem.held = (c.Mem.held or 0) + 1
		else
			c.Mem.held = 0
		end
		c.Mem.last = now
	end,
	Stance = function(c: Card)
		c.Mem.held = 0
		c.Mem.last = isAttack(c)
	end,
}

-- 절제: 공격하지 않고 턴을 마치면 모든 스킬 재사용 대기 −{1}턴
M.Duelist_C_Restraint = {
	TurnEnd = function(c: Card, info: any)
		if info.Attacked then
			return false
		end
		local ally = H.Ally(c)
		for id, left in ally.Cooldowns do
			ally.Cooldowns[id] = math.max(0, left - math.floor(c.V(1)))
		end
		return true
	end,
}

-- 복수: 자신을 공격한 적에게 다음 턴에 주는 피해 +{12}%
M.Duelist_C_Retribution = {
	Taken = function(c: Card, info: any)
		c.Mem.marks = c.Mem.marks or {}
		c.Mem.marks[info.Attacker.Id] = H.State(c).Turn + 1
	end,
	BeforeHit = function(c: Card, info: any)
		local marks = c.Mem.marks
		if marks and marks[info.Target.Id] == H.State(c).Turn then
			info.Bonus += c.P(1)
		end
	end,
}

-- 결속(파티): 자신이 얻는 회피 시간 증가의 {10}%를 인접한 아군도 받는다
M.Duelist_C_Bond = {
	Party = true,
	TurnStart = function(c: Card)
		local ally = H.Ally(c)
		local share = BattleStatus.Total(ally.Status, "ParryWindow") * c.P(1)
		if share <= 0 then
			return
		end
		local mine = H.Cell(c)
		for _, other in H.Allies(c) do
			local cell = other ~= ally and H.Cell(c, other)
			if cell and mine and math.abs(cell.X - mine.X) + math.abs(cell.Y - mine.Y) == 1 then
				H.ModOn(c, other, "ParryWindow", share, 1)
			end
		end
	end,
}

-- 깊은 상처: 출혈을 걸 때 {1} 더(턴당 {1}회)
M.Duelist_C_BleedInduce = {
	Status = function(c: Card, info: any)
		if info.Kind == "Bleed" and CardEffects.PerTurn(c, "extra", math.floor(c.V(2))) then
			bleed(c, info.Target, c.V(1))
			return true
		end
		return false
	end,
}

-- 안정: 준비 자세 동안 받는 피해 −{8}% 더
M.Duelist_C_Steady = {
	BeforeTaken = function(c: Card, info: any)
		if isReady(c) then
			info.Mult *= math.max(0, 1 - c.P(1))
		end
	end,
}

-- 칼끝: 집중 1당 치명 확률 +{0.5}%
M.Duelist_C_BladeTip = {
	BeforeSkill = function(c: Card, info: any)
		info.Crit += focus(c) * c.P(1)
	end,
}

-- 흐름: 패링에 성공하면 이번 전투 동안 회피 시간 +{2.5}%(최대 {25}%)
M.Duelist_C_StepBack = {
	Defend = function(c: Card, info: any)
		if info.Grade ~= "Success" then
			return false
		end
		c.Mem.bonus = math.min((c.Mem.bonus or 0) + c.P(1), c.P(2))
		H.Clear(c)
		H.Mod(c, "ParryWindow", c.Mem.bonus, -1)
		return true
	end,
}

-- 칼자루 감기: 자동 패링이 나면 공격자에게 출혈 {1}
M.Duelist_C_GripWrap = {
	Defend = function(c: Card, info: any)
		if info.Auto and info.Attacker then
			bleed(c, info.Attacker, c.V(1))
			return true
		end
		return false
	end,
}

return M
end
