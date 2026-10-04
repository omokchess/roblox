--!strict
--[[
	광전사 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	축 네 갈래(CardAxes)
	  피(Blood)    출혈·자해·흡혈 — 체력을 값으로 치른다
	  벼랑(Brink)  낮은 체력에서 강해지고 버틴다(견딤·상흔·재기·불굴)
	  분노(Rage)   맞아서 [분노]를 모으고 횡베기·종베기로 터뜨린다
	  광란(Frenzy) 처치·연속 공격으로 굴러간다

	[분노] 상한 8(피의 맹약 +5, 흡혈이면 0 — `RageCap` 질의). 자해는 `SelfHarmScale` 로 줄어든다.
	자리: 무모는 전열(1~2열)에서만 켜진다 — 앞에 서면 더 세게 치고 더 아프게 맞는다.
]]

local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)
local GroggyGauge = require(script.Parent.Parent.GroggyGauge)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function rage(c: Card): number
	return H.Stack(c, R.RAGE)
end

local function rageCap(c: Card): number
	return Q(c.Rt, R.RAGE .. "Cap", ClassResources.Cap(R.RAGE) or 8)
end

local function lostRatio(c: Card): number
	return 1 - H.HealthRatio(c)
end

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function isAttack(info: any): boolean
	return info.Skill ~= nil and (info.Skill.Damage or 0) > 0
end

-- 자기에게 걸린 한 종류 보정값 중 양수(증가)만 / 음수(감소)만의 합
local function sumSign(status: any, kind: string, positive: boolean): number
	local total = 0
	for _, modifier in status.Modifiers do
		if modifier.Kind == kind and (modifier.Value > 0) == positive and modifier.Value ~= 0 then
			total += modifier.Value
		end
	end
	return total
end

--[[
	체력에 따라 켜지는 효과(광기·견딤·상흔·무모 같은 것)는 체력이 바뀔 때마다 다시 건다.
	`fn(c)` 가 자기 보정을 지우고 새로 건다.
]]
local function onHealth(fn: (Card) -> ()): { [string]: any }
	return {
		BattleStart = fn,
		TurnStart = fn,
		Damaged = fn,
		Healed = fn,
	}
end

local M: { [string]: any } = {}

--=== 패시브 ===--

-- 다혈질: 어떤 수단이든 체력이 깎이면 [분노] 1 (화풀이 +1)
M.Berserker_Fury = {
	Damaged = function(c: Card)
		H.Gain(c, R.RAGE, math.floor(Q(c.Rt, "FuryGain", 1)))
	end,
}

-- 광기: 잃은 체력 10%당 피해 +5%(최대 45%). 체력 1% 이하면 대신 +50%.
M.Berserker_Thickening = onHealth(function(c: Card)
	H.Clear(c)
	local ratio = H.HealthRatio(c)
	local bonus = if ratio <= 0.01 then 0.5 else math.min(0.45, math.floor(lostRatio(c) * 10 + 1e-6) * 0.05)
	if bonus > 0 then
		H.Mod(c, "DamageDealt", bonus, -1)
	end
end)

-- 격분: [분노] 8 이상이면 치명 확률 +15%
M.Berserker_Bloodlust = {
	BeforeSkill = function(c: Card, info: any)
		if rage(c) >= 8 then
			info.Crit += 0.15
			return true
		end
		return false
	end,
}

--=== 필수 ===--

--[[
	피의 대가: 종베기가 맞힌 적마다 체력 {1}→10 을 치르고, 스킬 전에 체력 {4}~{5} 를 **미리** 바쳐
	바친 {2} 당 기본 피해 +{3}. 체력이 1 에 닿아도 바치려던 만큼 받는다.
	ponytail: 바칠 양을 고르는 UI 가 없어 늘 최대치({5})를 바친다 — 고르게 하려면 BattleClient 에 슬라이더.
]]
M.Berserker_E_BloodPrice = {
	Rules = {
		BurstSelfPerHit = function(_c: Card, _value: number): number
			return 10
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		if not isSkill(info, "Burst") then
			return false
		end
		local pay = c.V(5)
		H.LoseHealth(c, pay * Q(c.Rt, "SelfHarmScale", 1))
		info.Flat += math.floor(pay / c.V(2)) * c.V(3)
		H.Log(c, string.format("체력 %d 를 바쳐 기본 피해 +%d", pay, math.floor(pay / c.V(2)) * c.V(3)))
		return true
	end,
}

--[[
	벼랑 끝: 받는 회복 −{1}%. 받는 피해 증가는 {2}% 를 넘지 않고, 받는 피해 **감소**는 사라지는 대신
	그 {3}배가 주는 피해 증가가 된다.
]]
M.Berserker_E_Brink = {
	BattleStart = function(c: Card)
		H.Mod(c, "HealTaken", -c.P(1), -1)
	end,
	BeforeTaken = function(c: Card, info: any)
		local status = H.Status(c)
		local up = sumSign(status, "DamageTaken", true)
		local total = BattleStatus.Total(status, "DamageTaken")
		local want = 1 + math.min(up, c.P(2))
		info.Mult *= want / math.max(0.05, 1 + total)
	end,
	BeforeSkill = function(c: Card, info: any)
		local down = -sumSign(H.Status(c), "DamageTaken", false)
		if down > 0 then
			info.Bonus += down * c.V(3)
			return true
		end
		return false
	end,
}

-- 흡혈: 최대 체력 +{1}%, 준 피해의 {2}% 회복. 대신 [분노]를 얻지 못한다.
M.Berserker_E_Vampire = {
	Rules = {
		RageCap = function(_c: Card, _value: number): number
			return 0
		end,
	},
	BattleStart = function(c: Card)
		local ally = H.Ally(c)
		local extra = math.floor(ally.MaxHealth * c.P(1))
		ally.MaxHealth += extra
		ally.Health += extra
	end,
	Hit = function(c: Card, info: any)
		if info.Damage > 0 then
			H.HealFlat(c, info.Damage * c.P(2))
		end
	end,
}

-- 불굴: 전투당 한 번, 쓰러질 공격을 체력 {2} 로 버티고 다음 턴부터 피해 +{3}%. (재기가 먼저)
-- 불굴 켜진 뒤: [가하는 피해량] +(1 − 지금 체력/최대 체력). 체력이 바뀔 때마다 다시 건다(2026-10-04 리워크)
local function undyingRefresh(c: Card)
	if not c.Mem.on then
		return
	end
	local ally = H.Ally(c)
	H.Clear(c)
	local missing = 1 - math.clamp(ally.Health / math.max(1, ally.MaxHealth), 0, 1)
	if missing > 0 then
		H.Mod(c, "DamageDealt", missing, -1)
	end
end

M.Berserker_E_Undying = {
	Lethal = function(c: Card, save: any)
		if save.Cancel or c.Rt.Quiet then
			return false
		end
		local second = CardEffects.Has(c.Rt, "Berserker_R_SecondWind")
		if second and (second.Mem["once:save"] or 0) == 0 then
			return false -- 재기가 이 뒤에 먼저 받는다
		end
		if not H.PerBattle(c, "save", 1) then
			return false
		end
		save.Cancel = true
		save.Health = math.max(save.Health, c.V(2))
		c.Mem.armed = H.State(c).Turn
		H.Log(c, "쓰러지지 않는다")
		return true
	end,
	TurnStart = function(c: Card, turn: number)
		if c.Mem.armed and turn > c.Mem.armed then
			c.Mem.on = true
		end
		undyingRefresh(c)
	end,
	BeforeSkill = function(c: Card)
		undyingRefresh(c)
		return false
	end,
	Damaged = function(c: Card)
		undyingRefresh(c)
		return false
	end,
	Healed = function(c: Card)
		undyingRefresh(c)
		return false
	end,
}

--=== 희귀 ===--

-- 광란: 적을 처치하면 무작위 적에게 횡베기(기본 30 + 공격력, 출혈 2). 턴당 3번까지.
M.Berserker_R_Frenzy = {
	Kill = function(c: Card)
		local enemies = H.Enemies(c)
		if #enemies == 0 or not H.PerTurn(c, "slash", 3) then
			return false
		end
		local target = enemies[math.floor(H.Rng(c) * #enemies) + 1] or enemies[1]
		local ally = H.Ally(c)
		local amount = BattleStatus.OutgoingDamage(ally.Status, ally.Power + 30)
		local dealt = H.Hurt(c, target, amount, "Physical")
		if target.Alive then
			BattleStatus.AddBleed(target.Status, 2)
		end
		H.Log(c, string.format("횡베기 — %s 에게 %d", target.Name, dealt))
		return true
	end,
}

-- 격노: 적에게 직접 맞으면 [분노] +{1}
M.Berserker_R_Wrath = {
	Taken = function(c: Card)
		H.Gain(c, R.RAGE, c.V(1))
	end,
}

-- 처형: 체력 절반 이하인 적에게 피해 +{1}%
M.Berserker_R_ScentOfBlood = {
	BeforeHit = function(c: Card, info: any)
		local target = info.Target
		if target.MaxHealth > 0 and target.Health / target.MaxHealth <= 0.5 then
			info.Bonus += c.P(1)
		end
	end,
}

-- 무모: 전열(1~2열)이면 받는 피해 +{1}%, 주는 피해 +{2}%
local function reckless(c: Card)
	H.Clear(c)
	if H.IsFront(c) then
		H.Mod(c, "DamageTaken", c.P(1), -1)
		H.Mod(c, "DamageDealt", c.P(2), -1)
	end
end
M.Berserker_R_Reckless = {
	BattleStart = reckless,
	TurnStart = reckless,
	Move = reckless,
}

-- 재기: 전투당 한 번, 체력이 {1}% 이하가 되면 최대 체력의 {2}% 회복. 쓰러질 공격도 먼저 받는다.
M.Berserker_R_SecondWind = {
	Damaged = function(c: Card)
		if c.Rt.Quiet or not H.Ally(c).Alive or H.HealthRatio(c) > c.P(1) then
			return false
		end
		if not H.PerBattle(c, "save", 1) then
			return false
		end
		H.Heal(c, c.P(2))
		H.Log(c, "다시 일어선다")
		return true
	end,
	Lethal = function(c: Card, save: any)
		if save.Cancel or c.Rt.Quiet or not H.PerBattle(c, "save", 1) then
			return false
		end
		save.Cancel = true
		save.Health = math.max(save.Health, math.floor(H.Ally(c).MaxHealth * c.P(2)))
		H.Log(c, "다시 일어선다")
		return true
	end,
}

--[[
	휩쓸기: [분노]가 상한일 때 분쇄가 주 대상 둘레 3×3 까지 번진다. 곁의 적은 최종 피해의 {1}%.
	(분쇄는 분노를 쓰지 않으니 스킬 직전의 분노로 판정)
]]
M.Berserker_R_Sweep = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.full = isSkill(info, "BloodCrash") and rage(c) >= rageCap(c) and rageCap(c) > 0
		c.Mem.center = nil
	end,
	-- 주 대상이 맞고 쓰러지면 칸이 비므로 맞기 전에 자리를 적어 둔다
	BeforeHit = function(c: Card, info: any)
		if c.Mem.full and not c.Mem.center then
			c.Mem.center = H.Cell(c, info.Target)
		end
	end,
	AfterSkill = function(c: Card, info: any)
		local center = c.Mem.center
		c.Mem.full = false
		c.Mem.center = nil
		local main = info.Hits[1] and info.Hits[1][1]
		if not center or not main or main.Damage <= 0 then
			return false
		end
		local hitIds = {}
		for _, list in info.Hits do
			for _, hit in list do
				hitIds[hit.Id] = true
			end
		end
		local splash = main.Damage * c.P(1)
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if not hitIds[enemy.Id] and cell and math.abs(cell.X - center.X) <= 1 and math.abs(cell.Y - center.Y) <= 1 then
				H.Hurt(c, enemy, splash, "Physical")
				count += 1
			end
		end
		if count > 0 then
			H.Log(c, string.format("분쇄가 %d명에게 번졌다", count))
		end
		return count > 0
	end,
}

-- 견딤: 체력 {1}% 이하면 받는 피해 −{2}%
M.Berserker_R_PainTolerance = onHealth(function(c: Card)
	H.Clear(c)
	if H.Ally(c).Alive and H.HealthRatio(c) <= c.P(1) then
		H.Mod(c, "DamageTaken", -c.P(2), -1)
	end
end)

-- 가속: 공격 스킬을 쓴 턴이 이어질 때마다 스테미나 소모 −{1}%. 가드·명상이면 처음부터.
M.Berserker_R_Momentum = {
	Rules = {
		StaminaCost = function(c: Card, value: number): number
			return value * math.max(0, 1 - (c.Mem.streak or 0) * c.P(1))
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Guard") or isSkill(info, "Meditate") then
			c.Mem.streak = 0
		end
	end,
	TurnEnd = function(c: Card, info: any)
		if info.Attacked then
			c.Mem.streak = (c.Mem.streak or 0) + 1
		elseif info.Acted then
			c.Mem.streak = 0
		end
	end,
}

-- 상흔: 잃은 체력 {1}% 마다 받는 피해 −{2}%, 최대 {3}%
M.Berserker_R_Scars = onHealth(function(c: Card)
	H.Clear(c)
	local steps = math.floor(lostRatio(c) * 100 / c.V(1) + 1e-6)
	local cut = math.min(steps * c.P(2), c.P(3))
	if cut > 0 then
		H.Mod(c, "DamageTaken", -cut, -1)
	end
end)

-- 히스테릭: 받는 피해 증가량만큼 주는 피해 증가
M.Berserker_R_Roar = {
	BeforeSkill = function(c: Card, info: any)
		local up = sumSign(H.Status(c), "DamageTaken", true)
		if up > 0 then
			info.Bonus += up
			return true
		end
		return false
	end,
}

--=== 일반 ===--

-- 불씨: 전투 시작 시 [분노] {1}
M.Berserker_C_Ember = {
	BattleStart = function(c: Card)
		H.Gain(c, R.RAGE, c.V(1))
	end,
}

-- 물어뜯기: 공격 스킬이 맞힌 적마다 출혈 +{1}
M.Berserker_C_Bite = {
	Hit = function(c: Card, info: any)
		if info.Target.Alive and isAttack(info) then
			BattleStatus.AddBleed(info.Target.Status, c.V(1))
		end
	end,
}

-- 들이받기: 대상의 출혈 {1} 당 피해 +{2}%
M.Berserker_C_Ram = {
	BeforeHit = function(c: Card, info: any)
		local stacks = math.floor(info.Target.Status.Bleed / c.V(1))
		if stacks > 0 then
			info.Bonus += stacks * c.P(2)
		end
	end,
}

-- 앙심: 지난 턴에 나를 때린 적에게 피해 +{1}%
M.Berserker_C_Grudge = {
	Taken = function(c: Card, info: any)
		c.Mem.hitBy = c.Mem.hitBy or {}
		c.Mem.hitBy[info.Attacker.Id] = H.State(c).Turn
	end,
	BeforeHit = function(c: Card, info: any)
		local turn = c.Mem.hitBy and c.Mem.hitBy[info.Target.Id]
		if turn and turn == H.State(c).Turn - 1 then
			info.Bonus += c.P(1)
		end
	end,
}

-- 짙은 피: 자해 −{1}%
M.Berserker_C_ThickBlood = {
	Rules = {
		SelfHarmScale = function(c: Card, value: number): number
			return value * (1 - c.P(1))
		end,
	},
}

-- 무아: 체력 {1}% 미만이면 받는 피해 증가(디버프)를 {2}% 덜 받는다(곱)
M.Berserker_C_Trance = {
	BeforeTaken = function(c: Card, info: any)
		if H.HealthRatio(c) >= c.P(1) then
			return false
		end
		local status = H.Status(c)
		local up = sumSign(status, "DamageTaken", true)
		if up <= 0 then
			return false
		end
		local total = BattleStatus.Total(status, "DamageTaken")
		local eased = total - up * c.P(2)
		info.Mult *= math.max(0, 1 + eased) / math.max(0.05, 1 + total)
		return true
	end,
}

-- 휘두르기: 종베기 피해 +{1}%
M.Berserker_C_Swing = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Burst") then
			info.Bonus += c.P(1)
			return true
		end
		return false
	end,
}

-- 끓어오름: [분노] {1} 마다 치명 확률 +{2}%
M.Berserker_C_Boiling = {
	BeforeSkill = function(c: Card, info: any)
		info.Crit += math.floor(rage(c) / c.V(1)) * c.P(2)
	end,
}

-- 포식: 처치하면 최대 체력 {1}% 회복
M.Berserker_C_Devour = {
	Kill = function(c: Card)
		H.Heal(c, c.P(1))
	end,
}

-- 무감각: 그로기에 빠지지 않는다
M.Berserker_C_Numb = {
	Rules = {
		GroggyImmune = function(_c: Card, _value: number): number
			return 1
		end,
	},
}

-- 박치기: 분쇄가 {1}% 확률로 맞힌 적을 {2}턴 기절(이번 턴 예고한 공격이 취소된다)
M.Berserker_C_Headbutt = {
	Hit = function(c: Card, info: any)
		local target = info.Target
		if not isSkill(info, "BloodCrash") or not target.Alive or H.Rng(c) >= c.P(1) then
			return false
		end
		target.Groggy.Value = GroggyGauge.MAX
		target.Groggy.StunTurns = math.max(target.Groggy.StunTurns, c.V(2))
		local planned = H.State(c).Planned
		local index = table.find(planned, target.Id)
		if index then
			table.remove(planned, index)
		end
		H.Log(c, target.Name .. " 기절")
		return true
	end,
}

-- 화풀이: 스킬마다 [분노] 1 소모. 대신 피해를 받을 때 얻는 [분노] +1
M.Berserker_C_RageFuel = {
	Rules = {
		FuryGain = function(_c: Card, value: number): number
			return value + 1
		end,
	},
	BeforeSkill = function(c: Card)
		H.Spend(c, R.RAGE, 1)
	end,
}

-- 집중: 체력 {1}% 이하면 치명 확률 +{2}%
M.Berserker_C_DeathWish = {
	BeforeSkill = function(c: Card, info: any)
		if H.HealthRatio(c) <= c.P(1) then
			info.Crit += c.P(2)
			return true
		end
		return false
	end,
}

--[[
	자랑: QTE 를 성공하면(스킬·패링 둘 다) 자해 {1}. 죽지 않고, 재기·불굴도 켜지지 않는다.
	다혈질이 [분노]로 바꾼다 — 사실상 "성공하면 분노".
]]
local function boast(c: Card, grade: string)
	if grade ~= "Success" then
		return false
	end
	c.Rt.Quiet = true
	H.LoseHealth(c, c.V(1) * Q(c.Rt, "SelfHarmScale", 1))
	c.Rt.Quiet = false
	return true
end
M.Berserker_C_UnstoppingArm = {
	AfterSkill = function(c: Card, info: any)
		return boast(c, info.Grade)
	end,
	Defend = function(c: Card, info: any)
		return boast(c, info.Grade)
	end,
}

-- 피의 맹약: 최대 체력 −{1}%, [분노] 상한 +{2} (흡혈이면 상한이 0 이라 늘지 않는다)
M.Berserker_C_BloodPact = {
	Rules = {
		RageCap = function(c: Card, value: number): number
			return if value > 0 then value + c.V(2) else value
		end,
	},
	BattleStart = function(c: Card)
		local ally = H.Ally(c)
		ally.MaxHealth = math.max(1, math.floor(ally.MaxHealth * (1 - c.P(1))))
		ally.Health = math.min(ally.Health, ally.MaxHealth)
	end,
}

-- 고집: 전투당 {1}회, 기절을 {2}턴 줄여 받는다
M.Berserker_C_Stubborn = {
	Stunned = function(c: Card, info: any)
		if info.Turns > 0 and H.PerBattle(c, "stun", c.V(1)) then
			info.Turns -= c.V(2)
			H.Log(c, "버텼다")
			return true
		end
		return false
	end,
}

-- 과잉 살상: 적을 처치하고 남은 피해의 {1}% 가 다음 스킬의 첫 타에 더해진다
M.Berserker_C_Overkill = {
	BeforeHit = function(c: Card, info: any)
		c.Mem.hp = c.Mem.hp or {}
		c.Mem.hp[info.Target.Id] = info.Target.Health
	end,
	Hit = function(c: Card, info: any)
		local target = info.Target
		if c.Mem.ready and c.Mem.ready > 0 and target.Alive then
			local extra = c.Mem.ready
			c.Mem.ready = 0
			H.Hurt(c, target, extra, "Physical")
			H.Log(c, string.format("남은 기세 +%d", extra))
		end
		local before = c.Mem.hp and c.Mem.hp[target.Id]
		if before and not target.Alive and info.Damage > before then
			c.Mem.carry = (c.Mem.carry or 0) + (info.Damage - before) * c.P(1)
		end
	end,
	AfterSkill = function(c: Card)
		if c.Mem.carry and c.Mem.carry >= 1 then
			c.Mem.ready = math.floor(c.Mem.carry)
		end
		c.Mem.carry = 0
	end,
}

-- 굳은살: 같은 적에게 연달아 맞으면 그 적의 공격은 이번 전투 내내 {1}% 덜 아프다(겹치지 않는다)
M.Berserker_C_Callus = {
	Taken = function(c: Card, info: any)
		local id = info.Attacker.Id
		if c.Mem.last == id then
			c.Mem.hard = c.Mem.hard or {}
			c.Mem.hard[id] = true
		end
		c.Mem.last = id
	end,
	BeforeTaken = function(c: Card, info: any)
		if c.Mem.hard and c.Mem.hard[info.Attacker.Id] then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 자존심: 전투당 {1}회, 회복을 받으면 [분노] {2}
M.Berserker_C_BloodVessel = {
	Healed = function(c: Card)
		if H.PerBattle(c, "heal", c.V(1)) then
			H.Gain(c, R.RAGE, c.V(2))
			return true
		end
		return false
	end,
}

-- 잠깐의 준비: 가드 바로 다음 공격 스킬의 피해 +{1}%
M.Berserker_C_NoRetreat = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Guard") then
			c.Mem.primed = true
		end
	end,
	BeforeSkill = function(c: Card, info: any)
		if c.Mem.primed and isAttack(info) then
			c.Mem.primed = false
			info.Bonus += c.P(1)
			return true
		end
		return false
	end,
}

return M
end
