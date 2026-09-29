--!strict
--[[
	연금술사 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(Alchemist_Kit) — `Keywords` 약재·원액
	  [약재] 1당 받는 회복 +1%(약초학 +). 회복을 2번 받을 때마다 1 소모.
	  [원액] 체력이 10% 이하로 떨어지면 1 을 써서 최대 체력 10% 회복.
	  약재는 턴마다 1(별걸 다 쓰네 +), 빈 병은 2턴마다 1 — GridBattle.EndTurn 이 규칙대로(상한 질의) 준다.

	축(CardAxes): 조제(Brew, 병을 모으기) · 촉매(Catalyst, 스킬 순환) · 연소(Burn, 불·기름) · 벼랑(Brink, 부작용 감당)
	자리: 던지기(원거리) — 뒤에서 조제하고 던진다. 때리면서 섞기·로우리스크는 도발을 얻는 앞줄 조제사.
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local BOTTLES = { R.POISON_BOTTLE, R.FIRE_BOTTLE, R.OIL_BOTTLE }
local ALL_BOTTLES = { R.POISON_BOTTLE, R.FIRE_BOTTLE, R.OIL_BOTTLE, R.HEAL_BOTTLE }

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function fullBottles(c: Card): number
	local total = 0
	for _, id in BOTTLES do
		total += H.Stack(c, id)
	end
	return total
end

local function query(c: Card): (string, number) -> number
	return function(key: string, base: number): number
		return Q(c.Rt, key, base)
	end
end

local function randomBottle(c: Card, kinds: { string }): number
	local pick = kinds[math.min(#kinds, math.floor(H.Rng(c) * #kinds) + 1)]
	return H.Gain(c, pick, 1)
end

local function neighbours(c: Card, from: any, radius: number): { any }
	local center = H.Cell(c, from)
	local list = {}
	if not center then
		return list
	end
	for _, enemy in H.Enemies(c) do
		local cell = H.Cell(c, enemy)
		if enemy ~= from and cell and math.abs(cell.X - center.X) <= radius and math.abs(cell.Y - center.Y) <= radius then
			table.insert(list, enemy)
		end
	end
	return list
end

local M: { [string]: any } = {}

--=== 키트 ===--

local function refreshHerb(c: Card)
	H.Clear(c, "약재")
	local herbs = H.Stack(c, R.HERB)
	if herbs > 0 then
		H.Mod(c, "HealTaken", herbs * 0.01 * Q(c.Rt, "HerbHealScale", 1), -1, "약재")
	end
end

M.Alchemist_Kit = {
	BattleStart = refreshHerb,
	Gain = function(c: Card, id: string)
		if id == R.HERB then
			refreshHerb(c)
		end
	end,
	Spend = function(c: Card, id: string)
		if id == R.HERB then
			refreshHerb(c)
		end
	end,
	-- 회복을 2번 받을 때마다 약재 1
	Healed = function(c: Card)
		c.Mem.heals = (c.Mem.heals or 0) + 1
		if c.Mem.heals >= 2 then
			c.Mem.heals = 0
			H.Spend(c, R.HERB, 1)
			refreshHerb(c)
		end
	end,
	-- 원액: 체력 10% 이하면 1 을 써서 10% 회복
	Damaged = function(c: Card)
		local ally = H.Ally(c)
		if ally.Health > 0 and H.HealthRatio(c) <= 0.1 and H.Stack(c, R.EXTRACT) > 0 then
			H.Spend(c, R.EXTRACT, 1)
			H.Heal(c, 0.1)
			H.Log(c, "원액 — 체력 10% 회복")
			return true
		end
		return false
	end,
}

--=== 패시브 ===--

-- 보험: 체력 5% 이하로 떨어지면 [회복 병] 1 → 체력 30%(보험 증액 →)
M.Alchemist_Insurance = {
	Damaged = function(c: Card)
		local ally = H.Ally(c)
		if ally.Health > 0 and H.HealthRatio(c) <= 0.05 and H.Stack(c, R.HEAL_BOTTLE) > 0 then
			H.Spend(c, R.HEAL_BOTTLE, 1)
			H.Heal(c, Q(c.Rt, "InsuranceRatio", 0.3))
			H.Log(c, "보험 — 회복 병")
			return true
		end
		return false
	end,
}

-- 벌크업: 섞기마다 주는 피해 +5%·받는 피해 +5%(고중량 고반복 +), 최대 5중첩
local function bulk(c: Card)
	H.Clear(c)
	local n = c.Mem.n or 0
	if n > 0 then
		local per = Q(c.Rt, "BulkPer", 0.05)
		local flip = Q(c.Rt, "SideFlip", 0) >= 1
		H.Mod(c, "DamageDealt", per * n, -1)
		H.Mod(c, "DamageTaken", (if flip then -per else per) * n, -1)
	end
end
M.Alchemist_BulkUp = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Mix") then
			c.Mem.n = math.min(5, (c.Mem.n or 0) + 1)
			bulk(c)
		end
	end,
}

-- 부작용: 중독을 쓸 때마다 받는 피해 +10%(부작용 완화 −), 상한 없음. 해독제가 중첩을 지운다.
local function sideEffect(c: Card)
	H.Clear(c)
	local n = c.Rt.SideEffects or 0
	if n > 0 then
		local per = math.max(0, Q(c.Rt, "SideEffectPer", 0.1))
		local flip = Q(c.Rt, "SideFlip", 0) >= 1
		H.Mod(c, "DamageTaken", (if flip then -per else per) * n * Q(c.Rt, "PoisoningScale", 1), -1)
	end
end
M.Alchemist_SideEffect = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Poisoning") then
			c.Rt.SideEffects = (c.Rt.SideEffects or 0) + 1
			sideEffect(c)
		end
	end,
	TurnStart = sideEffect,
}

--=== 필수 ===--

--[[
	때리면서 섞기: 다지기에 고정 피해 {1}, 섞기에 고정 피해 {2} — 범위 (n,n)(줄에서 처음 걸리는 적).
	쓸 때마다 도발 {3}. 고정 피해라 버프로 늘지 않는다.
]]
M.Alchemist_E_MixAndStrike = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.first = if isSkill(info, "Grind") or isSkill(info, "Mix") then info.Targets[1] else nil
	end,
	AfterSkill = function(c: Card, info: any)
		local target = c.Mem.first
		c.Mem.first = nil
		if not (isSkill(info, "Grind") or isSkill(info, "Mix")) then
			return false
		end
		local ally = H.Ally(c)
		ally.Taunt = math.max(ally.Taunt, 0) + c.V(3)
		if target and target.Alive then
			H.Hurt(c, target, if isSkill(info, "Grind") then c.V(1) else c.V(2), "True")
		end
		return true
	end,
}

-- 로우리스크 로우리턴: 부작용이 전부 받는 피해 감소로. 대신 주는 피해 −{1}%, 공격마다 도발 {2}
M.Alchemist_E_LowRisk = {
	Rules = {
		SideFlip = function(_c: Card, _value: number): number
			return 1
		end,
	},
	BattleStart = function(c: Card)
		H.Mod(c, "DamageDealt", -c.P(1), -1)
	end,
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Damage > 0 then
			local ally = H.Ally(c)
			ally.Taunt += c.V(2)
		end
	end,
}

-- 원샷: 중독이 태운 병을 전부 돌려받는다. 대신 그 뒤 {1}턴 동안 병을 만들지 못한다.
M.Alchemist_E_OneShot = {
	Rules = {
		PoisoningReturnAll = function(_c: Card, _value: number): number
			return 1
		end,
		MixLocked = function(c: Card, value: number): number
			return if H.State(c).Turn <= (c.Mem.lock or 0) then 1 else value
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Poisoning") then
			c.Mem.lock = H.State(c).Turn + c.V(1)
			return true
		end
		return false
	end,
}

-- 과다복용: 중독의 버프·디버프 ×2
M.Alchemist_E_SelfPrescribe = {
	Rules = {
		PoisoningScale = function(_c: Card, value: number): number
			return value * 2
		end,
	},
}

--=== 희귀 ===--

-- 강철 위장: 중독의 [독 병] 체력 감소 −{1}%
M.Alchemist_R_IronStomach = {
	Rules = {
		PoisonSelfScale = function(c: Card, value: number): number
			return value * (1 - c.P(1))
		end,
	},
}

-- 준비성: 매 턴 {2}% 확률로 빈 병 {1} 더
M.Alchemist_R_BottleKeeping = {
	TurnEnd = function(c: Card)
		if H.Rng(c) < c.P(2) then
			H.Gain(c, R.EMPTY_BOTTLE, c.V(1))
			return true
		end
		return false
	end,
}

-- 정제: 섞기면 화염병 하나 확정 + 쓴 원액마다 {1}% 확률로 병 하나 더. 더 얻은 게 없으면 빈 병 {2} 반환
M.Alchemist_R_Distill = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.extract = if isSkill(info, "Mix") then H.Stack(c, R.EXTRACT) else 0
	end,
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Mix") or Q(c.Rt, "MixLocked", 0) >= 1 then
			return false
		end
		H.Gain(c, R.FIRE_BOTTLE, 1)
		local more = 0
		for _ = 1, c.Mem.extract or 0 do
			if H.Rng(c) < c.P(1) then
				more += randomBottle(c, BOTTLES)
			end
		end
		if more == 0 then
			H.Gain(c, R.EMPTY_BOTTLE, c.V(2))
		end
		return true
	end,
}

-- 촉진제: 기름 걸린 적의 화상 피해 +{1}% (턴 끝 화상에 더 얹는다)
M.Alchemist_R_Accelerant = {
	TurnEnd = function(c: Card)
		local count = 0
		for _, enemy in H.Enemies(c) do
			if enemy.Status.Oil > 0 and enemy.Status.Burn > 0 then
				local tick = math.floor(enemy.MaxHealth * enemy.Status.Burn / 100)
				c.Rt.Env.Damage(enemy, tick * c.P(1), "Fire", false)
				count += 1
			end
		end
		return count > 0
	end,
}

-- 가득 찬 가방: 독·화염·기름 병을 다 가지고 있으면 던지기가 병을 {1}개 던진다
M.Alchemist_R_CriticalBlend = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.full = isSkill(info, "Throw")
			and H.Stack(c, R.POISON_BOTTLE) > 0
			and H.Stack(c, R.FIRE_BOTTLE) > 0
			and H.Stack(c, R.OIL_BOTTLE) > 0
		c.Mem.targets = info.Targets
	end,
	AfterSkill = function(c: Card)
		if not c.Mem.full then
			return false
		end
		c.Mem.full = false
		local thrown = 0
		for _ = 2, c.V(1) do
			for _, id in BOTTLES do
				if H.Stack(c, id) > 0 then
					H.Spend(c, id, 1)
					for _, target in c.Mem.targets or {} do
						if target.Alive then
							BattleSkillEffects.ThrowBottle(target.Status, id, query(c))
						end
					end
					thrown += 1
					break
				end
			end
		end
		return thrown > 0
	end,
}

-- 독성 강화: 독 병 독 {1}
M.Alchemist_R_Reagent = {
	Rules = {
		PoisonBottleAmount = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 연쇄 반응: 던지기에 맞은 주 대상의 디버프(출혈·독·화상·기름) {1}%가 붙어 선 적에게 퍼진다
M.Alchemist_R_Chain = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Throw") then
			return false
		end
		local main = info.Hits[1] and info.Hits[1][1]
		local target = main and H.State(c).Units[main.Id]
		if not target or not target.Alive then
			return false
		end
		local s = target.Status
		local count = 0
		for _, enemy in neighbours(c, target, 1) do
			BattleStatus.AddBleed(enemy.Status, math.floor(s.Bleed * c.P(1)))
			BattleStatus.AddPoison(enemy.Status, math.floor(s.Poison * c.P(1)))
			BattleStatus.AddBurn(enemy.Status, math.floor(s.Burn * c.P(1)))
			BattleStatus.AddOil(enemy.Status, math.floor(s.Oil * c.P(1)))
			count += 1
		end
		return count > 0
	end,
}

-- 해독제: {2}턴마다 부작용 중첩 {1}개를 지운다
M.Alchemist_R_Antidote = {
	TurnStart = function(c: Card, turn: number)
		if turn % math.max(1, c.V(2)) == 0 and (c.Rt.SideEffects or 0) > 0 then
			c.Rt.SideEffects = math.max(0, c.Rt.SideEffects - c.V(1))
			return true
		end
		return false
	end,
}

-- 네이팜: 화염병 화상 {1}
M.Alchemist_R_Napalm = {
	Rules = {
		FireBottleAmount = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 방탄유리병: 던진 병마다 {1}% 확률로 빈 병
M.Alchemist_R_Recycle = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Throw") and H.Ally(c).LastBottle and H.Rng(c) < c.P(1) then
			H.Gain(c, R.EMPTY_BOTTLE, 1)
			return true
		end
		return false
	end,
}

--=== 일반 ===--

-- 만족감: 꽉 찬 병 {1}개당 주는 피해 +{2}%
M.Alchemist_C_Satisfaction = {
	BeforeSkill = function(c: Card, info: any)
		info.Bonus += math.floor(fullBottles(c) / c.V(1)) * c.P(2)
	end,
}

-- 넉넉한 계량: 약재 상한 {1}
M.Alchemist_C_AmpleMeasure = {
	Rules = {
		HerbCap = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 여분 병: 전투 시작 시 빈 병 {1}
M.Alchemist_C_Spare = {
	BattleStart = function(c: Card)
		H.Gain(c, R.EMPTY_BOTTLE, c.V(1))
	end,
}

-- 농축: 원액 상한 {1}
M.Alchemist_C_Extract = {
	Rules = {
		ExtractCap = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 별걸 다 쓰네: 매 턴 약재 +{1}
M.Alchemist_C_Toxin = {
	TurnEnd = function(c: Card)
		H.Gain(c, R.HERB, c.V(1))
	end,
}

-- 미끌미끌: 기름 걸린 적이 주는 피해 −{1}%
M.Alchemist_C_Slick = {
	BeforeTaken = function(c: Card, info: any)
		if info.Attacker.Status.Oil > 0 then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 내성: 체력 절반 이하에서 받는 회복 +{1}%
local function tolerance(c: Card)
	H.Clear(c)
	if H.HealthRatio(c) <= 0.5 then
		H.Mod(c, "HealTaken", c.P(1), -1)
	end
end
M.Alchemist_C_Tolerance = {
	BattleStart = tolerance,
	TurnStart = tolerance,
	Damaged = tolerance,
	Healed = tolerance,
}

-- 약초학: 약재 {1}당 받는 회복 +{2}% (약재 기본 1% 대신)
M.Alchemist_C_Herbal = {
	Rules = {
		HerbHealScale = function(c: Card, value: number): number
			return math.max(value, c.V(2) / c.V(1))
		end,
	},
}

-- 호신용 물약: 전투 시작 시 꽉 찬 병 {1}개(회복 병 포함 네 종류 중 무작위)
M.Alchemist_C_Floorstart = {
	BattleStart = function(c: Card)
		for _ = 1, c.V(1) do
			randomBottle(c, ALL_BOTTLES)
		end
	end,
}

-- 고중량 고반복: 벌크업 중첩당 +{1}%p
M.Alchemist_C_Bulk = {
	Rules = {
		BulkPer = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 보험 증액: 보험 회복 {1}%
M.Alchemist_C_Insurance = {
	Rules = {
		InsuranceRatio = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}

-- 부작용 완화: 부작용 중첩당 −{1}%p
M.Alchemist_C_Sideeffect = {
	Rules = {
		SideEffectPer = function(c: Card, value: number): number
			return value - c.P(1)
		end,
	},
}

-- 커다란 약병: 던지기가 붙어 선 적에게도 스킬 피해의 {1}%
M.Alchemist_C_Splash = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Throw") then
			return false
		end
		local main = info.Hits[1] and info.Hits[1][1]
		local target = main and H.State(c).Units[main.Id]
		if not main or main.Damage <= 0 or not target then
			return false
		end
		local count = 0
		for _, enemy in neighbours(c, target, 1) do
			H.Hurt(c, enemy, main.Damage * c.P(1), "Physical")
			count += 1
		end
		return count > 0
	end,
}

-- 채집: 처치하면 약재 {1}
M.Alchemist_C_Killherb = {
	Kill = function(c: Card)
		H.Gain(c, R.HERB, c.V(1))
	end,
}

-- 시간 날 때 해둬야지: 매 턴 약재 {1}을 써서 원액 {2}
M.Alchemist_C_Cooldown = {
	TurnEnd = function(c: Card)
		if H.Stack(c, R.HERB) >= c.V(1) then
			H.Spend(c, R.HERB, c.V(1))
			H.Gain(c, R.EXTRACT, c.V(2))
			return true
		end
		return false
	end,
}

-- 절박함: 체력 {1}% 이하면 주는 피해 +{2}%
M.Alchemist_C_Lowhp = {
	BeforeSkill = function(c: Card, info: any)
		if H.HealthRatio(c) <= c.P(1) then
			info.Bonus += c.P(2)
			return true
		end
		return false
	end,
}

-- 두꺼운 유리: 꽉 찬 병 + 빈 병 {1} 이상이면 받는 피해 −{2}%
M.Alchemist_C_Sturdy = {
	BeforeTaken = function(c: Card, info: any)
		if fullBottles(c) + H.Stack(c, R.EMPTY_BOTTLE) >= c.V(1) then
			info.Mult *= 1 - c.P(2)
			return true
		end
		return false
	end,
}

-- 점화: 기름 걸린 적에게 화염병이 맞으면 고정 피해 {1}
M.Alchemist_C_Ignite = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.oiled = {}
		if isSkill(info, "Throw") then
			for _, target in info.Targets do
				if target.Status.Oil > 0 then
					c.Mem.oiled[target.Id] = true
				end
			end
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Throw") or H.Ally(c).LastBottle ~= R.FIRE_BOTTLE then
			return false
		end
		local count = 0
		for _, enemy in H.Enemies(c) do
			if c.Mem.oiled[enemy.Id] then
				H.Hurt(c, enemy, c.V(1), "True")
				count += 1
			end
		end
		return count > 0
	end,
}

-- 통달: 다지기 원액 +{1}(약재 소모는 그대로)
M.Alchemist_C_Grind = {
	Rules = {
		GrindExtractBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 꾸준한 조제: {1}턴 안에 섞기를 {2}번 이상 쓰면 무작위 꽉 찬 병 {3}
M.Alchemist_C_Steady = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Mix") then
			return false
		end
		local turn = H.State(c).Turn
		c.Mem.uses = c.Mem.uses or {}
		table.insert(c.Mem.uses, turn)
		local recent = {}
		for _, t in c.Mem.uses do
			if turn - t < c.V(1) then
				table.insert(recent, t)
			end
		end
		c.Mem.uses = recent
		if #recent >= c.V(2) then
			c.Mem.uses = {}
			for _ = 1, c.V(3) do
				randomBottle(c, ALL_BOTTLES)
			end
			return true
		end
		return false
	end,
}

return M
end
