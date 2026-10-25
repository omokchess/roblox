--!strict
--[[
	청의 검사 — 직업 키트·카드 34장의 전투 효과. (조건부 획득, 2026-10-25)

	키트(AzureBlade_Kit)
	  [집중력] 얻은 뒤 2턴(혼신의 도발 +)이 지나면 사라진다 — 얻은 턴 끝은 세지 않는다(BattleSkillEffects.GrantConcentration).
	           무념무상이면 사라지지 않는다. 사라질 때 집중 유지가 확률로 1턴 붙잡는다.
	  `도발`을 쓴 턴을 유닛의 `ProvokeTurn` 에 적는다 — 도발 축 카드가 "도발을 쓴 턴 / 다음 턴"을 본다.

	패시브 둘(도발·집중력)은 규칙이 스킬 표와 키트에 들어 있어 따로 처리기가 없다.
	축(CardAxes): 발도(Iaido) · 집중(Precision) · 도발(Taunt) · 방어(Guard)
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)
local GroggyGauge = require(script.Parent.Parent.GroggyGauge)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function turn(c: Card): number
	return H.State(c).Turn
end

local function focused(c: Card): boolean
	return H.Stack(c, R.CONCENTRATION) > 0
end

local function grant(c: Card): boolean
	local gained = BattleSkillEffects.GrantConcentration(H.Ally(c), turn(c), math.floor(Q(c.Rt, "ConcentrationTurns", 2)), function(id, amount)
		return H.Gain(c, id, amount)
	end)
	if gained > 0 then
		H.Log(c, "집중력")
	end
	return gained > 0
end

local function provokedOn(c: Card, offset: number): boolean
	return H.Ally(c).ProvokeTurn == turn(c) + offset
end

local function restoreStamina(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(amount))
end

local function hitCount(info: any): number
	local count = 0
	for _, list in info.Hits or {} do
		count = math.max(count, #list)
	end
	return count
end

local M: { [string]: any } = {}

--=== 키트 ===--

M.AzureBlade_Kit = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Provoke") then
			H.Ally(c).ProvokeTurn = turn(c)
		end
	end,
	TurnEnd = function(c: Card)
		local ally = H.Ally(c)
		if not focused(c) or Q(c.Rt, "ConcentrationForever", 0) >= 1 then
			return
		end
		if ally.ConcentrationTurn == turn(c) then
			return -- 얻은 턴 끝은 세지 않는다
		end
		ally.ConcentrationLeft = (ally.ConcentrationLeft or 1) - 1
		if ally.ConcentrationLeft > 0 then
			return
		end
		if H.Rng(c) < Q(c.Rt, "ConcentrationLinger", 0) then
			ally.ConcentrationLeft = 1
			H.Log(c, "집중력이 한 턴 더 남는다")
			return
		end
		BattleStatus.SpendAll(ally.Status, R.CONCENTRATION)
	end,
}

--=== 필수 ===--

-- 도발: `도발`은 다른 스킬로 바뀔 수 없다(무념무상·역수 발도와 함께 가질 수 없다 — 그 둘이 도발을 바꾼다)
M.AzureBlade_E_Provoke = {}

-- 치우쳐진 검: 받는 피해 +2.5%
M.AzureBlade_E_Biased = {
	BattleStart = function(c: Card)
		H.Mod(c, "DamageTaken", c.P(1), -1)
		return true
	end,
}

-- 무념무상: 집중력이 사라지지 않는다. 도발로는 못 얻고 진 발도술 치명타로 얻는다. 집중력이 있으면 치명 피해 +20%
M.AzureBlade_E_Mushin = {
	Rules = {
		ConcentrationForever = function(_c: Card, _value: number): number
			return 1
		end,
		ProvokeNoConcentration = function(_c: Card, _value: number): number
			return 1
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		if focused(c) then
			info.CritDamage += c.P(1)
		end
	end,
	Hit = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") and info.Crit and not focused(c) then
			return grant(c)
		end
		return false
	end,
}

-- 역수 발도: 도발을 쓴 턴에 오는 공격을 40% 확률로 받아쳐 무기 공격력의 150% 를 되돌린다
M.AzureBlade_E_Riposte = {
	BeforeTaken = function(c: Card, info: any)
		if not provokedOn(c, 0) or info.Grade == "Success" or (info.Skill and info.Skill.Unavoidable) then
			return false
		end
		if H.Rng(c) < c.P(1) then
			info.Grade = "Success"
			if info.Attacker and info.Attacker.Alive then
				H.Hurt(c, info.Attacker, H.Ally(c).Power * c.P(2), "Physical")
			end
			H.Log(c, "받아쳤다")
			return true
		end
		return false
	end,
}

--=== 희귀 ===--

-- 혼신의 도발: 집중력 유지 +1턴
M.AzureBlade_R_AllOut = {
	Rules = {
		ConcentrationTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 방어 태도: 집중력이 있을 때 받는 피해 −10%, 주는 피해 −2.5%
local function refreshStance(c: Card)
	H.Clear(c)
	if focused(c) then
		H.Mod(c, "DamageTaken", -c.P(1), 1)
		H.Mod(c, "DamageDealt", -c.P(2), 1)
	end
end
M.AzureBlade_R_Stance = {
	TurnStart = refreshStance,
	AfterSkill = refreshStance,
}

-- 검풍: 발도술의 절정이 3명 이상 베면 진 발도술 재사용 대기 끝 + 스테미나 5
M.AzureBlade_R_SwordWind = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "IaidoPeak") and hitCount(info) >= c.V(1) then
			H.Ally(c).Cooldowns.TrueIaido = 0
			restoreStamina(c, c.V(2))
			H.Log(c, "진 발도술이 다시 선다")
			return true
		end
		return false
	end,
}

-- 잔심: 진 발도술로 적을 쓰러뜨리면 40% 확률로 집중력
M.AzureBlade_R_Zanshin = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") and (info.Kills or 0) > 0 and H.Rng(c) < c.P(1) then
			return grant(c)
		end
		return false
	end,
}

-- 칼집 울림: 검집 타격이 맞힌 적 그로기 +10
M.AzureBlade_R_Ring = {
	Hit = function(c: Card, info: any)
		if isSkill(info, "ScabbardStrike") and info.Target.Groggy then
			GroggyGauge.Add(info.Target.Groggy, c.V(1))
			return true
		end
		return false
	end,
}

-- 도발의 대가: 도발을 쓴 턴에 받는 피해 −15%
M.AzureBlade_R_Price = {
	BeforeTaken = function(c: Card, info: any)
		if provokedOn(c, 0) then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 한 호흡: 공간의 이해로 집중력을 쓰면 다음 턴 시작 시 스테미나 15
M.AzureBlade_R_OneBreath = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "SpaceCut") then
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

-- 명경지수: 집중력이 있을 때 회피 시간 +10%
local function refreshStill(c: Card)
	H.Clear(c)
	if focused(c) then
		H.Mod(c, "ParryWindow", c.P(1), 1)
	end
end
M.AzureBlade_R_StillWater = {
	TurnStart = refreshStill,
	AfterSkill = refreshStill,
}

-- 역습 표식: 도발을 쓴 다음 턴의 첫 스킬 치명 +15%
M.AzureBlade_R_Mark = {
	BeforeSkill = function(c: Card, info: any)
		if provokedOn(c, -1) and not c.Mem.used then
			c.Mem.used = turn(c)
			info.Crit += c.P(1)
			return true
		end
		return false
	end,
	TurnStart = function(c: Card)
		c.Mem.used = nil
	end,
}

-- 거짓 틈: 도발을 쓴 턴에 회피하면 50% 확률로 진 발도술 재사용 대기 끝
M.AzureBlade_R_FalseGap = {
	Defend = function(c: Card, info: any)
		if info.Grade == "Success" and provokedOn(c, 0) and H.Rng(c) < c.P(1) then
			H.Ally(c).Cooldowns.TrueIaido = 0
			return true
		end
		return false
	end,
}

--=== 일반 ===--

-- 민첩성: 필드 이동 속도 +5%(BattleService 가 FieldMoveSpeed 로 묻는다), 전투에서는 민첩 +2
M.AzureBlade_C_Agility = {
	Rules = {
		FieldMoveSpeed = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
	BattleStart = function(c: Card)
		local stats = H.State(c).AllyStats
		stats.Agility = (stats.Agility or 0) + c.V(2)
		return true
	end,
}

-- 집중력의 향상: 집중력이 있을 때 치명 +1.5%
M.AzureBlade_C_FocusUp = {
	BeforeSkill = function(c: Card, info: any)
		if focused(c) then
			info.Crit += c.P(1)
		end
	end,
}

-- 바람의 검: 진 발도술 치명 +2.5%
M.AzureBlade_C_WindBlade = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") then
			info.Crit += c.P(1)
		end
	end,
}

-- 칼끝 겨누기: 검집 타격 치명 +5%
M.AzureBlade_C_Point = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "ScabbardStrike") then
			info.Crit += c.P(1)
		end
	end,
}

-- 발검 연습: 진 발도술을 쓰면 스테미나 3
M.AzureBlade_C_DrawPractice = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 칼 쉬게 하기: 호흡을 쓴 다음 턴 진 발도술 치명 피해 +15%
M.AzureBlade_C_Settle = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Meditate") then
			c.Mem.turn = turn(c) + 1
		end
	end,
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") and c.Mem.turn == turn(c) then
			info.CritDamage += c.P(1)
			return true
		end
		return false
	end,
}

-- 도발 연습: 도발을 쓰면 스테미나 4
M.AzureBlade_C_Jeer = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Provoke") then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 검집 막기: 가드를 쓴 턴에 막아 내면 30% 확률로 집중력
M.AzureBlade_C_SheathBlock = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Guard") then
			c.Mem.turn = turn(c)
		end
	end,
	Defend = function(c: Card, info: any)
		if info.Grade == "Partial" and c.Mem.turn == turn(c) and not focused(c) and H.Rng(c) < c.P(1) then
			return grant(c)
		end
		return false
	end,
}

-- 끝까지 노려보기: 집중력이 있을 때 이동하지 않고 턴을 마치면 스테미나 4
M.AzureBlade_C_Stare = {
	TurnEnd = function(c: Card, info: any)
		if focused(c) and not info.Moved then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 베어 넘기기: 발도술의 절정이 벤 적 1명당 치명 피해 +5%
M.AzureBlade_C_Through = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "IaidoPeak") then
			info.CritDamage += c.P(1) * #(info.Targets or {})
		end
	end,
}

-- 공간 가르기: 공간의 이해로 적을 쓰러뜨리면 스테미나 8
M.AzureBlade_C_Cleave = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "SpaceCut") and (info.Kills or 0) > 0 then
			restoreStamina(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 검집 되치기: 검집 타격이 맞힌 적은 이번 턴 가하는 피해 −10%
M.AzureBlade_C_Rebuke = {
	Hit = function(c: Card, info: any)
		if isSkill(info, "ScabbardStrike") and info.Target.Alive then
			H.ModOn(c, info.Target, "DamageDealt", -c.P(1), 1)
			return true
		end
		return false
	end,
}

-- 흘려 넘기기: 막아 내면 받는 피해 5% 더 감소
M.AzureBlade_C_Deflect = {
	BeforeTaken = function(c: Card, info: any)
		if info.Grade == "Partial" then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 기세: 도발을 쓴 다음 턴 진 발도술 피해 +8%
M.AzureBlade_C_Momentum = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "TrueIaido") and provokedOn(c, -1) then
			info.Bonus += c.P(1)
			return true
		end
		return false
	end,
}

-- 도발 응수: 도발을 쓴 턴에 회피하면 다음 턴 치명 +6%
M.AzureBlade_C_Answer = {
	Defend = function(c: Card, info: any)
		if info.Grade == "Success" and provokedOn(c, 0) and H.PerTurn(c, "answer", 1) then
			H.Mod(c, "CritChance", c.P(1), 2)
			return true
		end
		return false
	end,
}

-- 집중 유지: 집중력이 사라질 때 20% 확률로 1턴 더(키트가 굴린다)
M.AzureBlade_C_Linger = {
	Rules = {
		ConcentrationLinger = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}

-- 칼날 벼리기: 전투 시작 시 30% 확률로 집중력(1턴부터 센다)
M.AzureBlade_C_Whet = {
	BattleStart = function(c: Card)
		if H.Rng(c) < c.P(1) and grant(c) then
			H.Ally(c).ConcentrationTurn = 0
			return true
		end
		return false
	end,
}

-- 방랑 검객: 적이 3기 이상이면 발도술의 절정 피해 +10%
M.AzureBlade_C_Wanderer = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "IaidoPeak") and #H.Enemies(c) >= c.V(1) then
			info.Bonus += c.P(2)
			return true
		end
		return false
	end,
}

-- 어깨 너머: 가드를 쓴 다음 턴의 첫 스킬 스테미나 −25%
M.AzureBlade_C_Shoulder = {
	Rules = {
		StaminaCost = function(c: Card, value: number): number
			return if c.Mem.turn == turn(c) then value * (1 - c.P(1)) else value
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if c.Mem.turn == turn(c) then
			c.Mem.turn = nil
		end
		if isSkill(info, "Guard") then
			c.Mem.turn = turn(c) + 1
		end
	end,
}

-- 도발의 눈빛: 도발을 쓴 턴에는 적 공격이 35% 확률로 치명타가 되지 않는다
M.AzureBlade_C_Glare = {
	BeforeTaken = function(c: Card, info: any)
		if provokedOn(c, 0) and info.Crit > 0 and H.Rng(c) < c.P(1) then
			info.Crit = 0
			return true
		end
		return false
	end,
}

return M
end
