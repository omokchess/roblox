--!strict
--[[
	조율자 — 직업 키트·패시브·카드 34장의 전투 효과. (조건부 획득, 2026-10-25)

	키트(Attuner_Kit)
	  [핵융합 반응] 턴이 끝날 때마다 한 턴 늙는다(BattleSkillEffects.ApplyFusion — 가하는 +400% 에서 10%p,
	                받는 +400% 에서 50%p 씩). 있는 동안 [칠성] 획득 2배(StarGain).
	  [묶임]        미자르가 건 것 — 그 턴이 끝나면 푼다.

	패시브(별 넷 — 스킬 별 셋은 BattleSkillEffects 가 켠다)
	  알카이드  같은 행·열 아군 [가하는 피해량] +50%, 없으면 칠성. **신앙심 말고는 피해% 가 안 먹는다**(FaithOnlyDamage)
	  미자르    턴 시작 시 한 아군(솔로면 자신) 지정 → 묶임 1 · 보호막 49 · 가하는 +50%. 자신이면 칠성
	  페크다    아군 자동 회피 20%. 자동 회피로 피하면 칠성
	  두베      턴 시작 시 아군 보호막 7. 아군이 14 이상 맞으면 칠성

	별의 "모드"(태우기 위한 별이 바꾼다)는 규칙 질의로 묻는다 — AlkaidBurn · MizarBurn · PhecdaAccuracy · DubheMegrez.
	축(CardAxes): 칠성(Constellation) · 연소(Burn) · 수호(Aegis) · 신앙(Faith)
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function stars(c: Card): number
	return H.Stack(c, R.STAR)
end

local function light(c: Card, source: string): boolean
	local gained = BattleSkillEffects.LightStar(H.Ally(c), source, function(id, amount)
		return H.Gain(c, id, amount)
	end)
	if gained > 0 then
		H.Log(c, string.format("칠성 %d", stars(c)))
		return true
	end
	return false
end

-- 별 모드(태우기 위한 별)
local function mode(c: Card, key: string): boolean
	return Q(c.Rt, key, 0) >= 1
end

-- 직업 보호막(미자르·두베)에 붙는 배율(지키기 위한 별 +30%)
local function shieldScale(c: Card): number
	return Q(c.Rt, "AttunerShieldScale", 1)
end

local function addFaith(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Faith = math.max(0, ally.Faith + amount)
end

local function restoreStamina(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(amount))
end

-- 같은 행(Y) 또는 열(X)에 선 다른 아군(솔로면 없다)
local function inLine(c: Card): { any }
	local me = H.Ally(c)
	local mine = H.Cell(c)
	local list = {}
	for _, ally in H.Allies(c) do
		local cell = H.Cell(c, ally)
		if ally ~= me and mine and cell and (cell.X == mine.X or cell.Y == mine.Y) then
			table.insert(list, ally)
		end
	end
	return list
end

local function nearestEnemy(c: Card, from: any?, except: any?): any?
	local best, bestDistance = nil, math.huge
	for _, enemy in H.Enemies(c) do
		local cell = H.Cell(c, enemy)
		if enemy ~= except and cell then
			local distance = if from then math.abs(cell.X - from.X) + math.abs(cell.Y - from.Y) else cell.X
			if distance < bestDistance or (distance == bestDistance and best and enemy.Id < best.Id) then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

-- 지키기 위한 별: 스킬마다 바뀐 기본 피해량(사다리 칸)
local GUARD_BASE: { [string]: number } = { Megrez = 1, Merak = 2, Alioth = 3, Septentriones = 4 }

local M: { [string]: any } = {}

--=== 키트 ===--

M.Attuner_Kit = {
	Rules = {
		-- 핵융합 반응 동안 칠성 획득 2배
		StarGain = function(c: Card, value: number): number
			return if H.Stack(c, R.FUSION) > 0 then value * 2 else value
		end,
	},
	TurnEnd = function(c: Card)
		local ally = H.Ally(c)
		BattleStatus.SpendAll(ally.Status, R.BIND)
		if H.Stack(c, R.FUSION) > 0 then
			ally.FusionAge = (ally.FusionAge or 0) + 1
			BattleSkillEffects.ApplyFusion(ally.Status, ally.FusionAge, Q(c.Rt, "FusionTakenDrop", 0.5))
		end
	end,
}

--=== 패시브 ===--

M.Attuner_Alkaid = {
	Rules = {
		-- 신앙심 말고는 가하는 피해량을 올릴 수 없다(GridBattle 이 카드 Bonus·스탯 피해를 거르고 신앙심 2% 를 붙인다)
		FaithOnlyDamage = function(_c: Card, _value: number): number
			return 1
		end,
	},
	TurnStart = function(c: Card)
		local partners = inLine(c)
		for _, ally in partners do
			BattleStatus.RemoveBySource(ally.Status, "알카이드")
			if not mode(c, "AlkaidBurn") then
				BattleStatus.AddModifier(ally.Status, "DamageDealt", 0.5, 1, "알카이드")
			end
		end
		if #partners == 0 then
			light(c, "Alkaid")
		end
	end,
	-- 태우기 위한 별: 공격 적중 시 화상
	Hit = function(c: Card, info: any)
		if mode(c, "AlkaidBurn") and info.Target and info.Target.Alive then
			BattleStatus.AddBurn(info.Target.Status, math.floor(Q(c.Rt, "AlkaidBurnAmount", 2)))
		end
	end,
}

M.Attuner_Mizar = {
	TurnStart = function(c: Card)
		local me = H.Ally(c)
		local pick = me
		local allies = H.Allies(c)
		if not mode(c, "MizarBurn") and #allies > 1 then
			-- 3턴 동안 자신을 안 골랐으면 3턴째엔 반드시 자신
			if (c.Mem.skipped or 0) < 2 then
				pick = allies[math.floor(H.Rng(c) * #allies) + 1]
			end
		end
		c.Mem.skipped = if pick == me then 0 else (c.Mem.skipped or 0) + 1
		if not mode(c, "MizarBurn") then
			if Q(c.Rt, "MizarNoBind", 0) < 1 then
				BattleStatus.AddStack(pick.Status, R.BIND, 1, 1)
			end
			local shield = math.floor(Q(c.Rt, "MizarShield", 49) * shieldScale(c))
			BattleStatus.AddShield(pick.Status, shield)
			BattleStatus.RemoveBySource(pick.Status, "미자르")
			BattleStatus.AddModifier(pick.Status, "DamageDealt", 0.5, 1, "미자르")
			me.MizarShield = if pick == me then shield else 0
		end
		if pick == me then
			light(c, "Mizar")
			-- 알코르: 미자르 곁의 여덟 번째 별
			if Q(c.Rt, "AlcorStar", 0) >= 1 then
				light(c, "Alcor")
			end
		end
	end,
}

M.Attuner_Phecda = {
	BattleStart = function(c: Card)
		if mode(c, "PhecdaAccuracy") then
			for _, ally in H.Allies(c) do
				H.ModOn(c, ally, "Accuracy", 0.2, -1)
			end
		end
	end,
	BeforeTaken = function(c: Card, info: any)
		if mode(c, "PhecdaAccuracy") or info.Grade == "Success" then
			return false
		end
		if info.Skill and info.Skill.Unavoidable then
			return false
		end
		if H.Rng(c) < Q(c.Rt, "PhecdaEvade", 0.2) then
			info.Grade = "Success"
			info.Auto = true
			H.Log(c, "자동 회피")
			return true
		end
		return false
	end,
	Defend = function(c: Card, info: any)
		if info.Auto and info.Grade == "Success" then
			light(c, "Phecda")
		end
	end,
	-- 태우기 위한 별: 명중률로 바뀐 페크다는 공격이 적중하면 칠성
	Hit = function(c: Card, info: any)
		if mode(c, "PhecdaAccuracy") and (info.Damage or 0) > 0 then
			light(c, "Phecda")
		end
	end,
}

M.Attuner_Dubhe = {
	TurnStart = function(c: Card)
		if mode(c, "DubheMegrez") then
			return
		end
		local shield = math.floor(Q(c.Rt, "DubheShield", 7) * shieldScale(c))
		for _, ally in H.Allies(c) do
			BattleStatus.AddShield(ally.Status, shield)
		end
	end,
	-- "14 이상의 피해를 받으면": 보호막이 먹은 양까지 센다(미자르 보호막 49 가 늘 덮어 체력은 거의 안 깎인다)
	BeforeTaken = function(c: Card)
		local ally = H.Ally(c)
		c.Mem.before = ally.Status.Shield + ally.Health
	end,
	Defend = function(c: Card)
		local ally = H.Ally(c)
		if c.Mem.before and c.Mem.before - (ally.Status.Shield + ally.Health) >= 14 then
			light(c, "Dubhe")
		end
		c.Mem.before = nil
	end,
	Damaged = function(c: Card, info: any)
		if (info.Amount or 0) >= 14 then
			light(c, "Dubhe")
		end
	end,
	-- 태우기 위한 별: 자신의 턴이 끝난 뒤 메그레즈(쓸 때마다 기본 피해량 감소 — 카드가 Flat 으로 깎는다)
	TurnEnd = function(c: Card)
		if mode(c, "DubheMegrez") and #H.Enemies(c) > 0 then
			c.Rt.Env.CastFree("Megrez", 1)
		end
	end,
}

--=== 필수 ===--

-- 지키기 위한 별: 기본 피해량 3/5/10/15, 미자르 묶임 없음 · 보호막 +30%, 액티브 스킬을 쓰면 아군 회복(기본 피해 ×8, 최대 80)
M.Attuner_E_GuardStar = {
	Rules = {
		MizarNoBind = function(_c: Card, _value: number): number
			return 1
		end,
		AttunerShieldScale = function(c: Card, value: number): number
			return value * (1 + c.P(5))
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		local slot = info.Skill and GUARD_BASE[info.Skill.Id]
		c.Mem.base = 0
		if slot then
			info.Flat += c.V(slot) - info.Skill.Damage
			c.Mem.base = c.V(slot)
		end
	end,
	AfterSkill = function(c: Card, _info: any)
		local amount = math.min(c.V(7), (c.Mem.base or 0) * c.V(6))
		if amount <= 0 then
			return false
		end
		for _, ally in H.Allies(c) do
			c.Rt.Env.Heal(ally, amount)
		end
		return true
	end,
}

-- 태우기 위한 별: 화상·융해 +2, 알카이드 → 적중 화상, 미자르 → 화상 대상 피해 +20%(자신만), 페크다 → 명중률, 두베 → 턴 끝 메그레즈
M.Attuner_E_BurnStar = {
	Rules = {
		AttunerBurnBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		AttunerMeltBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		AlkaidBurn = function(_c: Card, _value: number): number
			return 1
		end,
		AlkaidBurnAmount = function(c: Card, _value: number): number
			return c.V(2)
		end,
		MizarBurn = function(_c: Card, _value: number): number
			return 1
		end,
		PhecdaAccuracy = function(_c: Card, _value: number): number
			return 1
		end,
		DubheMegrez = function(_c: Card, _value: number): number
			return 1
		end,
	},
	BeforeHit = function(c: Card, info: any)
		if info.Target and info.Target.Status.Burn > 0 then
			info.Bonus += c.P(3)
		end
	end,
	-- 턴 끝 메그레즈: 쓸 때마다 기본 피해량 ×(1 − 50%)
	BeforeSkill = function(c: Card, info: any)
		if info.Free and isSkill(info, "Megrez") then
			local uses = c.Mem.freeUses or 0
			info.Flat += info.Skill.Damage * ((1 - c.P(4)) ^ uses - 1)
			c.Mem.freeUses = uses + 1
		end
	end,
}

-- 알코르: 칠성 최대 8(셉텐트리오네스도 8에서), 미자르가 자신이면 칠성 한 번 더, 셉텐트리오네스 치명 +25%
M.Attuner_E_Alcor = {
	Rules = {
		StarCap = function(_c: Card, value: number): number
			return value + 1
		end,
		AlcorStar = function(_c: Card, _value: number): number
			return 1
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Septentriones") then
			info.Crit += c.P(1)
		end
	end,
}

-- 신탁: 셉텐트리오네스가 핵융합 반응 대신 신앙심 +12, 신앙심 1당 피해 2% → 2.5%
M.Attuner_E_Oracle = {
	Rules = {
		SeptentrionesNoFusion = function(_c: Card, _value: number): number
			return 1
		end,
		FaithDamagePer = function(c: Card, _value: number): number
			return c.P(2)
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Septentriones") then
			addFaith(c, c.V(1))
			H.Log(c, string.format("신앙심 %d", H.Ally(c).Faith))
			return true
		end
		return false
	end,
}

--=== 희귀 ===--

-- 유성우: 턴 시작 시 (칠성 / 4, 반올림) 화상을 모든 적에게
M.Attuner_R_Meteor = {
	TurnStart = function(c: Card)
		local amount = math.floor(stars(c) / c.V(1) + 0.5)
		if amount <= 0 then
			return false
		end
		for _, enemy in H.Enemies(c) do
			BattleStatus.AddBurn(enemy.Status, amount)
		end
		return true
	end,
}

-- 용광로 별: 융해 상한 20 → 24
M.Attuner_R_Furnace = {
	Rules = {
		MeltCap = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 쌍성: 미자르 보호막이 턴 끝까지 남으면 남은 양의 30% 회복
M.Attuner_R_Binary = {
	TurnEnd = function(c: Card)
		local ally = H.Ally(c)
		local left = math.min(ally.Status.Shield, ally.MizarShield or 0)
		if left <= 0 then
			return false
		end
		return H.HealFlat(c, left * c.P(1)) > 0
	end,
}

-- 별자리 지도: 한 턴에 칠성 2 이상이면 스테미나 +8
M.Attuner_R_StarMap = {
	Gain = function(c: Card, id: string, amount: number)
		if id ~= R.STAR then
			return false
		end
		local turn = H.State(c).Turn
		if c.Mem.turn ~= turn then
			c.Mem.turn, c.Mem.count = turn, 0
		end
		c.Mem.count += amount
		if c.Mem.count >= 2 and H.PerTurn(c, "map", 1) then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 북극성: 칠성 5 이상이면 받는 피해 −10%
M.Attuner_R_Polaris = {
	BeforeTaken = function(c: Card, info: any)
		if stars(c) >= c.V(1) then
			info.Mult *= 1 - c.P(2)
			return true
		end
		return false
	end,
}

-- 별의 상흔: 신앙심 10마다 화상 부여량 +1
M.Attuner_R_Stigmata = {
	Rules = {
		AttunerBurnBonus = function(c: Card, value: number): number
			return value + math.floor(H.Ally(c).Faith / c.V(1))
		end,
	},
}

-- 철야 기도: 가드로 턴을 마치면 신앙심 +2(이 카드로 최대 12)
M.Attuner_R_Vigil = {
	AfterSkill = function(c: Card, info: any)
		c.Mem.guarded = isSkill(info, "Guard")
	end,
	TurnEnd = function(c: Card)
		if not c.Mem.guarded then
			return false
		end
		c.Mem.guarded = false
		local room = c.V(2) - (c.Mem.total or 0)
		local amount = math.min(c.V(1), room)
		if amount <= 0 then
			return false
		end
		c.Mem.total = (c.Mem.total or 0) + amount
		addFaith(c, amount)
		return true
	end,
}

-- 신기루: 페크다 자동 회피 20% → 26%
M.Attuner_R_Mirage = {
	Rules = {
		PhecdaEvade = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}

-- 적색거성: 융해가 터진 적 둘레 1칸의 적에게 터진 양의 25%
M.Attuner_R_RedGiant = {
	MeltBurst = function(c: Card, info: any)
		local from = H.Cell(c, info.Target)
		local amount = math.floor(info.Melt * c.P(1) + 0.5)
		if not from or amount <= 0 then
			return false
		end
		local cap = math.floor(Q(c.Rt, "MeltCap", ClassResources.Cap(R.MELT) or 20))
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if enemy ~= info.Target and cell and math.abs(cell.X - from.X) <= 1 and math.abs(cell.Y - from.Y) <= 1 then
				BattleSkillEffects.AddMelt(enemy.Status, amount, cap)
				count += 1
			end
		end
		return count > 0
	end,
}

-- 흑점: 핵융합 반응 받는 피해 증가가 턴마다 50%p → 100%p 씩 준다
M.Attuner_R_Sunspot = {
	Rules = {
		FusionTakenDrop = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}

--=== 일반 ===--

-- 별빛 조준: (칠성 / 5, 반올림)% 치명타 확률
M.Attuner_C_Starlight = {
	BeforeSkill = function(c: Card, info: any)
		info.Crit += math.floor(stars(c) / c.V(1) + 0.5) / 100
	end,
}

-- 메그레즈의 불씨: 메그레즈가 맞힌 적에게 20% 확률로 융해 +1
M.Attuner_C_Ember = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Megrez") then
			return false
		end
		local cap = math.floor(Q(c.Rt, "MeltCap", ClassResources.Cap(R.MELT) or 20))
		local any = false
		for _, list in info.Hits or {} do
			for _, hit in list do
				local unit = H.State(c).Units[hit.Id]
				if unit and unit.Alive and H.Rng(c) < c.P(1) then
					BattleSkillEffects.AddMelt(unit.Status, 1, cap)
					any = true
				end
			end
		end
		return any
	end,
}

-- 메라크의 궤도: 메라크를 쓰면 15% 확률로 재사용 대기 초기화
M.Attuner_C_Orbit = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Merak") and H.Rng(c) < c.P(1) then
			H.Ally(c).Cooldowns.Merak = 0
			H.Log(c, "메라크가 다시 돈다")
			return true
		end
		return false
	end,
}

-- 알리오스의 섬광: 알리오스 화상 +2
M.Attuner_C_Flare = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Alioth") then
			return false
		end
		for _, list in info.Hits or {} do
			for _, hit in list do
				local unit = H.State(c).Units[hit.Id]
				if unit and unit.Alive then
					BattleStatus.AddBurn(unit.Status, c.V(1))
				end
			end
		end
		return true
	end,
}

-- 두베의 지붕: 두베 보호막 7 → 9
M.Attuner_C_Roof = {
	Rules = {
		DubheShield = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 별 순례: 전투 시작 시 신앙심 +4
M.Attuner_C_StarPilgrim = {
	BattleStart = function(c: Card)
		addFaith(c, c.V(1))
		return true
	end,
}

-- 관측: 셉텐트리오네스로 칠성이 초기화되면 다음 턴 시작 시 스테미나 +6
-- (턴 시작에 칠성 0 을 보던 첫 안은 알카이드·미자르가 먼저 별을 켜서 영영 안 걸렸다)
M.Attuner_C_Observe = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Septentriones") then
			c.Mem.pending = true
		end
	end,
	TurnStart = function(c: Card)
		if c.Mem.pending then
			c.Mem.pending = false
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 남은 불티: 화상을 가진 적이 쓰러지면 남은 화상의 30% 가 가장 가까운 적에게
M.Attuner_C_Cinder = {
	BeforeHit = function(c: Card, info: any)
		c.Mem.cells = c.Mem.cells or {}
		c.Mem.cells[info.Target.Id] = H.Cell(c, info.Target)
	end,
	Kill = function(c: Card, info: any)
		local burn = info.Target.Status.Burn
		if burn <= 0 then
			return false
		end
		local from = c.Mem.cells and c.Mem.cells[info.Target.Id]
		local target = nearestEnemy(c, from, info.Target)
		local amount = math.floor(burn * c.P(1))
		if target and amount > 0 then
			BattleStatus.AddBurn(target.Status, amount)
			return true
		end
		return false
	end,
}

-- 성광: 셉텐트리오네스 회복 최대치 30 → 36
M.Attuner_C_Radiance = {
	Rules = {
		SeptentrionesHealCap = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 경건: 신앙심 15 이상이면 받는 회복량 +10%
M.Attuner_C_Devout = {
	TurnStart = function(c: Card)
		H.Clear(c)
		if H.Ally(c).Faith >= c.V(1) then
			H.Mod(c, "HealTaken", c.P(2), 1)
			return true
		end
		return false
	end,
}

-- 묵주: 신앙심 10마다 치명타 확률 +1%
M.Attuner_C_Rosary = {
	BeforeSkill = function(c: Card, info: any)
		info.Crit += math.floor(H.Ally(c).Faith / c.V(1)) * 0.01
	end,
}

-- 중력 렌즈: 셉텐트리오네스 치명타 피해량 +15%
M.Attuner_C_Lens = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Septentriones") then
			info.CritDamage += c.P(1)
		end
	end,
}

-- 녹는점: 융해 8 이상인 적을 맞히면 스테미나 +3(스킬마다 한 번)
M.Attuner_C_MeltPoint = {
	BeforeSkill = function(c: Card)
		c.Mem.paid = false
	end,
	BeforeHit = function(c: Card, info: any)
		if not c.Mem.paid and BattleStatus.Stack(info.Target.Status, R.MELT) >= c.V(1) then
			c.Mem.paid = true
			restoreStamina(c, c.V(2))
		end
	end,
}

-- 별무리: 미자르 보호막 49 → 55
M.Attuner_C_Cluster = {
	Rules = {
		MizarShield = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 찬송: 셉텐트리오네스를 쓰면 신앙심 +3
M.Attuner_C_Hymn = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Septentriones") then
			addFaith(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 헌신의 별: 셉텐트리오네스가 체력으로 내는 몫 80%
M.Attuner_C_Devotion = {
	Rules = {
		SeptentrionesHealthCost = function(c: Card, value: number): number
			return value * c.P(1)
		end,
	},
}

-- 열 순환: 자신에게 화상이 있으면 턴 끝 스테미나 +3
M.Attuner_C_HeatCycle = {
	TurnEnd = function(c: Card)
		if H.Status(c).Burn > 0 then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 성소: 가드를 쓰면 다음 턴 시작 시 보호막 5
M.Attuner_C_Sanctum = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Guard") then
			c.Mem.pending = true
		end
	end,
	TurnStart = function(c: Card)
		if c.Mem.pending then
			c.Mem.pending = false
			H.Shield(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 시편: 신앙심 20 이상이면 알리오스를 쓴 뒤 25% 확률로 재사용 대기 −1
M.Attuner_C_Psalm = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Alioth") and H.Ally(c).Faith >= c.V(1) and H.Rng(c) < c.P(2) then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.Alioth = math.max(0, (cooldowns.Alioth or 0) - 1)
			return true
		end
		return false
	end,
}

-- 반짝임: 자동 회피에 성공하면 다음 스킬 스테미나 −20%
M.Attuner_C_Twinkle = {
	Rules = {
		StaminaCost = function(c: Card, value: number): number
			return if c.Mem.discount then value * (1 - c.P(1)) else value
		end,
	},
	Defend = function(c: Card, info: any)
		if info.Auto and info.Grade == "Success" then
			c.Mem.discount = true
			return true
		end
		return false
	end,
	AfterSkill = function(c: Card)
		c.Mem.discount = false
	end,
}

return M
end
