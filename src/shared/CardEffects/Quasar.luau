--!strict
--[[
	퀘이사 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(Quasar_Kit) — `Keywords` 질량·중력, 스킬 붕괴 설명
	  [질량] 1당 주는 피해 +1%, 받는 피해 −0.5%. 상한 20(거센 빛 40·50 — `MassCap`)
	  차징: 붕괴로 시작하면 턴마다 1씩 차오른다(최대 2, 과충전 3 — `ChargeCap`).
	        차징 중에는 턴마다 내 줄의 적에게 [중력].
	  [중력] 걸린 적은 앞 두 열에서만 움직이고(조석력이면 더 앞 — `GravityColumns`, GridBattle.EnemyPlan),
	        공격이 10% 확률로 빗나간다.

	축(CardAxes): 닻(Anchor, 질량) · 도발(Taunt, 버티기) · 차징(Charge) · 과부하(Overload, 특이점)
	자리: 강착(인접한 적)·중력(앞으로 끌어옴) — 앞에서 적을 끌어안는 탱커.
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function mass(c: Card): number
	return H.Stack(c, R.MASS)
end

local function charge(c: Card): number
	return H.Stack(c, R.CHARGE)
end

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function hasGravity(unit: any): boolean
	return unit ~= nil and BattleSkillEffects.HasGravity(unit.Status)
end

-- 붙어 선 적: 나와 적이 둘 다 중앙선 쪽(열 합 3 이하)이고 줄 차이 1 이하
local function adjacentEnemies(c: Card): { any }
	local mine = H.Cell(c)
	local list = {}
	if not mine then
		return list
	end
	for _, enemy in H.Enemies(c) do
		local cell = H.Cell(c, enemy)
		if cell and mine.X + cell.X <= 3 and math.abs(cell.Y - mine.Y) <= 1 then
			table.insert(list, enemy)
		end
	end
	return list
end

local function gainMass(c: Card, amount: number): number
	if amount <= 0 then
		return 0
	end
	return H.Gain(c, R.MASS, amount)
end

local M: { [string]: any } = {}

--=== 키트 ===--

local function refreshMass(c: Card)
	H.Clear(c)
	local m = mass(c)
	if m > 0 then
		H.Mod(c, "DamageDealt", 0.01 * m, -1)
		H.Mod(c, "DamageTaken", -0.005 * m, -1)
	end
end

M.Quasar_Kit = {
	BattleStart = refreshMass,
	Gain = function(c: Card, id: string)
		if id == R.MASS then
			refreshMass(c)
		end
	end,
	Spend = function(c: Card, id: string)
		if id == R.MASS then
			refreshMass(c)
		end
	end,
	TurnStart = function(c: Card)
		refreshMass(c)
		local status = H.Status(c)
		-- 차징이 차오른다
		local now = charge(c)
		if now > 0 then
			local cap = math.floor(Q(c.Rt, "ChargeCap", 2))
			if now < cap then
				BattleStatus.AddStack(status, R.CHARGE, 1, cap)
			end
			-- 차징 중: 내 줄의 적에게 [중력]
			local mine = H.Cell(c)
			local turns = math.floor(Q(c.Rt, "GravityTurns", 2))
			for _, enemy in H.Enemies(c) do
				local cell = H.Cell(c, enemy)
				if mine and cell and cell.Y == mine.Y then
					BattleSkillEffects.ApplyGravity(enemy.Status, turns)
				end
			end
		end
	end,
	-- [중력] 걸린 적의 공격은 10% 확률로 빗나간다
	BeforeTaken = function(c: Card, info: any)
		if hasGravity(info.Attacker) and info.Grade ~= "Success" and H.Rng(c) < 0.1 then
			info.Mult = 0
			H.Log(c, info.Attacker.Name .. " 의 공격이 중력에 빗나갔다")
			return true
		end
		return false
	end,
}

--=== 패시브 ===--

--[[
	아득한 빛: 맞거나 스킬로 때릴 때마다 그 수치의 10%만큼 [질량] — **한 번에 최대 2**(흡수·방출이 +).
	상한이 없으면 스킬 한 번(피해 100~500)에 질량 20 이 다 차서 질량 카드가 할 일이 없었다.
]]
local function farLight(c: Card, amount: number, bonusKey: string)
	if amount <= 0 then
		return
	end
	local gained = math.min(2, math.floor(amount * 0.1 + 0.5))
	gainMass(c, gained + Q(c.Rt, bonusKey, 0))
end
M.Quasar_FarLight = {
	Taken = function(c: Card, info: any)
		farLight(c, info.Damage, "MassFromTaken")
	end,
	AfterSkill = function(c: Card, info: any)
		farLight(c, info.Total or 0, "MassFromDealt")
	end,
}

--[[
	초대질량: 맞을 때마다 20% 확률로 받는 피해 −50%(곱). 블랙홀이면 늘 발동하고 감소폭·무효화가 바뀐다.
	발동했는지는 Mem.fired 로 남긴다(반사면).
]]
M.Quasar_Supermassive = {
	BeforeTaken = function(c: Card, info: any)
		c.Mem.cut = 0
		local always = Q(c.Rt, "SupermassiveAlways", 0) >= 1
		if not always and H.Rng(c) >= 0.2 then
			return false
		end
		local nullify = Q(c.Rt, "SupermassiveNullify", 0)
		if nullify > 0 and H.Rng(c) < nullify then
			info.Mult = 0
			H.Log(c, "초대질량 — 피해 무효")
			return true
		end
		local cut = Q(c.Rt, "SupermassiveCut", 0.5)
		info.Mult *= 1 - cut
		c.Mem.cut = cut
		return true
	end,
}

-- 고독한 빛: 살아 있는 다른 아군이 없으면 주는 피해 +25%, [질량] 획득 ×2
M.Quasar_LoneLight = {
	Rules = {
		MassGain = function(c: Card, value: number): number
			return if #H.Allies(c) <= 1 then value * 2 else value
		end,
	},
	TurnStart = function(c: Card)
		H.Clear(c)
		if #H.Allies(c) <= 1 then
			H.Mod(c, "DamageDealt", 0.25, -1)
		end
	end,
}

--=== 필수 ===--

-- 거센 빛: 질량 획득 절반, 상한 {1}→{2}
M.Quasar_E_FierceLight = {
	Rules = {
		MassGain = function(_c: Card, value: number): number
			return value * 0.5
		end,
		MassCap = function(c: Card, _value: number): number
			return c.V(2)
		end,
	},
}

-- 블랙홀: 초대질량이 늘 발동, 감소폭 {1}%, {2}% 확률로 완전 무효
M.Quasar_E_BlackHole = {
	Rules = {
		SupermassiveAlways = function(_c: Card, _value: number): number
			return 1
		end,
		SupermassiveCut = function(c: Card, _value: number): number
			return c.P(1)
		end,
		SupermassiveNullify = function(c: Card, value: number): number
			return value + c.P(2)
		end,
	},
}

--[[
	사건의 지평선: 차징 중에는 아군이 받는 피해를 대신 받는다(파티) — 그 피해는 {1}% 줄고 [질량]으로 바뀐다.
	솔로에서는 자기가 받는 피해에 그대로 걸린다: 차징 중 받는 피해 −{1}%, 받은 피해 5당 [질량] 1.
]]
M.Quasar_E_EventHorizon = {
	BeforeTaken = function(c: Card, info: any)
		if charge(c) > 0 then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
	Taken = function(c: Card, info: any)
		if charge(c) > 0 then
			gainMass(c, math.floor(info.Damage / 5))
		end
	end,
}

-- 광속 붕괴: 특이점이 늘 {1}단계. 대신 질량을 전부 쓰고 {2}턴 동안 질량을 못 얻는다.
M.Quasar_E_LightspeedCollapse = {
	Rules = {
		SingularityGrow = function(_c: Card, _value: number): number
			return 2 -- 3단계 범위(Stages 둘 다)
		end,
		SingularityTier = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
		MassGain = function(c: Card, value: number): number
			local until_ = c.Mem.lock or 0
			return if H.State(c).Turn <= until_ then 0 else value
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Singularity") then
			c.Mem.lock = H.State(c).Turn + c.V(2)
			H.Log(c, string.format("%d턴 동안 질량을 얻지 못한다", c.V(2)))
		end
	end,
}

--=== 희귀 ===--

-- 차징 방호: 차징 중 받는 피해 −{1}%
M.Quasar_R_ChargeGuard = {
	BeforeTaken = function(c: Card, info: any)
		if charge(c) > 0 then
			info.Mult *= 1 - c.P(1)
		end
	end,
}

-- 대신 짊어지기(파티): 아군을 대신 맞으면 질량 +{1}. 솔로에는 대신 맞을 아군이 없다.
M.Quasar_R_ShoulderIt = {
	Party = true,
	Guarded = function(c: Card)
		gainMass(c, c.V(1))
	end,
}

-- 조석력: [중력] 걸린 적이 {1}칸 더 끌려온다 — 움직일 수 있는 열이 그만큼 앞으로 좁아진다
M.Quasar_R_TidalForce = {
	Rules = {
		GravityColumns = function(c: Card, value: number): number
			return value - c.V(1)
		end,
	},
}

-- 강착: 턴 시작마다 붙어 선 적 하나당 질량 {1}
M.Quasar_R_Accretion = {
	TurnStart = function(c: Card)
		local count = #adjacentEnemies(c)
		if count > 0 then
			gainMass(c, count * c.V(1))
			return true
		end
		return false
	end,
}

-- 압축: 특이점의 질량당 피해 {1}% → {2}%
M.Quasar_R_Compression = {
	Rules = {
		SingularityPerMass = function(c: Card, value: number): number
			return math.max(value, c.P(2))
		end,
	},
}

-- 제트: 특이점이 {1}단계로 나가면 맞은 적에게 [중력] {2}턴
local function singularityTier(c: Card): number
	local spent = c.Mem.massBefore or 0
	local tier = if spent >= 15 then 3 elseif spent >= 8 then 2 else 1
	return math.max(tier, math.floor(Q(c.Rt, "SingularityTier", 0)))
end
local function rememberMass(c: Card, info: any)
	if isSkill(info, "Singularity") then
		c.Mem.massBefore = mass(c)
	end
end
M.Quasar_R_Jet = {
	BeforeSkill = rememberMass,
	Hit = function(c: Card, info: any)
		if isSkill(info, "Singularity") and info.Target.Alive and singularityTier(c) >= c.V(1) then
			BattleSkillEffects.ApplyGravity(info.Target.Status, c.V(2) + Q(c.Rt, "GravityExtra", 0))
		end
	end,
}

-- 적색편이: [중력] 걸린 적이 주는 피해 −{1}%
M.Quasar_R_Redshift = {
	BeforeTaken = function(c: Card, info: any)
		if hasGravity(info.Attacker) then
			info.Mult *= 1 - c.P(1)
		end
	end,
}

-- 고밀도: 질량 {1} 이상이면 받는 피해 −{2}% 더
local function highDensity(c: Card)
	H.Clear(c)
	if mass(c) >= c.V(1) then
		H.Mod(c, "DamageTaken", -c.P(2), -1)
	end
end
M.Quasar_R_HighDensity = {
	BattleStart = highDensity,
	TurnStart = highDensity,
	Gain = highDensity,
	Spend = highDensity,
}

-- 반발(파티): 아군을 대신 맞은 뒤 다음 공격 +{1}%
M.Quasar_R_Recoil = {
	Party = true,
	Guarded = function(c: Card)
		c.Mem.primed = true
	end,
	BeforeSkill = function(c: Card, info: any)
		if c.Mem.primed and info.Skill.Damage > 0 then
			c.Mem.primed = false
			info.Bonus += c.P(1)
		end
	end,
}

-- 과충전: 차징 상한 {1}턴
M.Quasar_R_Overcharge = {
	Rules = {
		ChargeCap = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

--=== 일반 ===--

-- 가속 차징: 차징 {1}턴당 늘어나는 피해 +{2}%
M.Quasar_C_FastCharge = {
	Rules = {
		ChargeStep = function(c: Card, value: number): number
			return value + c.P(2) / c.V(1)
		end,
	},
}

-- 중력 압착: [중력] 걸린 적에게 피해 +{1}%
M.Quasar_C_GravityCrush = {
	BeforeHit = function(c: Card, info: any)
		if hasGravity(info.Target) then
			info.Bonus += c.P(1)
		end
	end,
}

-- 씨앗 질량: 전투 시작 시 질량 {1}
M.Quasar_C_SeedMass = {
	BattleStart = function(c: Card)
		gainMass(c, c.V(1))
	end,
}

-- 흡수 / 방출: 맞을 때 / 스킬로 때릴 때 아득한 빛이 주는 질량 +{1}
M.Quasar_C_Absorb = {
	Rules = {
		MassFromTaken = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}
M.Quasar_C_Emit = {
	Rules = {
		MassFromDealt = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 덩치(파티): 붙어 선 적이 나를 노릴 확률 +{1}%. 솔로에서는 적이 늘 나를 노린다.
M.Quasar_C_Bulk = {
	Party = true,
}

-- 포식 질량: 처치하면 질량 {1}
M.Quasar_C_FeedMass = {
	Kill = function(c: Card)
		gainMass(c, c.V(1))
	end,
}

-- 고정: 차징 중 그로기가 차지 않고, 턴 시작마다 질량 {1}
M.Quasar_C_Planted = {
	Rules = {
		GroggyImmune = function(c: Card, value: number): number
			return if charge(c) > 0 then 1 else value
		end,
	},
	TurnStart = function(c: Card)
		if charge(c) > 0 then
			gainMass(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 광륜(파티): 인접한 아군 받는 피해 −{1}%
M.Quasar_C_Halo = {
	Party = true,
}

-- 냉각: 질량 {1} 이상에서 특이점을 쓰면 재사용 대기 {2}턴 더 감소
M.Quasar_C_Cooling = {
	BeforeSkill = rememberMass,
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Singularity") and (c.Mem.massBefore or 0) >= c.V(1) then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.Singularity = math.max(0, (cooldowns.Singularity or 0) - c.V(2))
			return true
		end
		return false
	end,
}

-- 충격파: 특이점 {1}단계면 맞은 적 둘레 {2}칸의 다른 적에게 {3} 추가 피해
M.Quasar_C_Shockwave = {
	BeforeSkill = rememberMass,
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Singularity") or singularityTier(c) < c.V(1) then
			return false
		end
		local hitIds, centers = {}, {}
		for _, list in info.Hits do
			for _, hit in list do
				hitIds[hit.Id] = true
			end
		end
		for _, enemy in H.Enemies(c) do
			if hitIds[enemy.Id] then
				table.insert(centers, H.Cell(c, enemy))
			end
		end
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if not hitIds[enemy.Id] and cell then
				for _, center in centers do
					if math.abs(cell.X - center.X) <= c.V(2) and math.abs(cell.Y - center.Y) <= c.V(2) then
						H.Hurt(c, enemy, c.V(3), "Physical")
						count += 1
						break
					end
				end
			end
		end
		return count > 0
	end,
}

-- 조수 간만: 차징을 다 채우기 전에 발동하면, 차징 {1}턴당 질량 {2}
M.Quasar_C_TidalSwing = {
	BeforeSkill = function(c: Card, info: any)
		c.Mem.early = 0
		local now = charge(c)
		if isSkill(info, "Collapse") and now > 0 and now < math.floor(Q(c.Rt, "ChargeCap", 2)) then
			c.Mem.early = now
		end
	end,
	AfterSkill = function(c: Card)
		if (c.Mem.early or 0) > 0 then
			gainMass(c, math.floor(c.Mem.early / c.V(1)) * c.V(2))
			c.Mem.early = 0
			return true
		end
		return false
	end,
}

-- 낙하 연습: 낙하로 처치할 때 질량 +{1}
M.Quasar_C_FallPractice = {
	Rules = {
		InfallKillMass = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 외피: 전투 시작 시 최대 체력 {1}% 보호막
M.Quasar_C_Hull = {
	BattleStart = function(c: Card)
		H.Shield(c, H.Ally(c).MaxHealth * c.P(1))
	end,
}

-- 견인: 차징을 시작한 턴에도 적이 {1}칸 끌려온다
M.Quasar_C_Tow = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Collapse") and charge(c) > 0 then
			c.Rt.Env.Pull(c.V(1))
			return true
		end
		return false
	end,
}

-- 휘청임: 특이점을 맞은 적은 {1}턴 동안 주는 피해 −{2}%
M.Quasar_C_Stagger = {
	Hit = function(c: Card, info: any)
		if isSkill(info, "Singularity") and info.Target.Alive then
			H.ModOn(c, info.Target, "DamageDealt", -c.P(2), c.V(1))
		end
	end,
}

-- 정지 질량: 이동하지 않은 턴에는 질량 {1}
M.Quasar_C_RestMass = {
	TurnEnd = function(c: Card, info: any)
		if not info.Moved then
			gainMass(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 반사면: 초대질량이 발동하면 줄인 피해의 {1}%를 공격자에게
M.Quasar_C_MirrorFace = {
	Taken = function(c: Card, info: any)
		local passive = CardEffects.Has(c.Rt, "Quasar_Supermassive")
		local cut = passive and passive.Mem.cut or 0
		if cut > 0 and cut < 1 and info.Attacker and info.Attacker.Alive then
			local reduced = info.Damage * cut / (1 - cut)
			H.Hurt(c, info.Attacker, reduced * c.P(1), "Physical")
			return true
		end
		return false
	end,
}

-- 붙잡기: [중력] 지속 +{1}턴
M.Quasar_C_Hold = {
	Rules = {
		GravityTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		GravityExtra = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

--[[
	여운: 질량을 쓸 때 {1}스택당 체력 {2}. 질량을 쓰는 건 특이점뿐이다 — 쓰고 곧바로 아득한 빛으로
	다시 차서 앞뒤 비교(Spend 훅)로는 안 보이므로 특이점 직전에 센다.
]]
M.Quasar_C_Afterglow = {
	BeforeSkill = function(c: Card, info: any)
		local amount = mass(c)
		if isSkill(info, "Singularity") and amount > 0 then
			H.HealFlat(c, math.floor(amount / c.V(1)) * c.V(2))
			return true
		end
		return false
	end,
}

return M
end
