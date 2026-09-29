--!strict
--[[
	펄서 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(Pulsar_Kit)
	  [공명] 자기권·섬광이 1씩 쌓고(상한 3, 임계 자속 +) 수렴이 전부 써서 배율로 바꾼다. 모으지도 쓰지도
	         않은 턴이 끝나면 1 빠진다(플라이휠이 바닥을 받친다).
	  [감극] 지속(보정값 "감극")이 끝나면 스택도 비운다(고정 극이 붙잡는다).
	  [자기장]이 끝나면 `FieldEnd` 훅을 쏜다(재충전·방출 조율·여광).
	  아군 명중률(불완전한 빛)이 깎였으면 그만큼 스킬이 빗나간다.

	축(CardAxes): 결계(Ward, 자기장·반사) · 연쇄(Chain, 감극) · 연사(Volley, 공명·수렴) · 비호(Aegis, 섬광·아군)
	자리: 정지장(서 있기)·반사 — 제자리에서 맞받아치는 후열 포대. 수렴(원거리)은 뒤에서도 닿는다.
]]

local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local BattleStatus = require(script.Parent.Parent.BattleStatus)
local ClassResources = require(script.Parent.Parent.ClassResources)
local QteDefinitions = require(script.Parent.Parent.QteDefinitions)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function hasField(c: Card): boolean
	return BattleSkillEffects.HasField(H.Status(c))
end

local function resonate(c: Card): number
	return H.Stack(c, R.RESONATE)
end

local function depolarOf(unit: any): number
	return BattleStatus.Stack(unit.Status, R.DEPOLAR)
end

local function applyDepolar(c: Card, unit: any, amount: number)
	BattleSkillEffects.ApplyDepolar(unit.Status, amount, math.floor(Q(c.Rt, "DepolarTurns", 2)), Q(c.Rt, "DepolarPer", 0.15))
end

-- 자기장 지속을 늘리거나 줄인다(임계 자속 +1, 차폐 −1)
local function shiftField(c: Card, delta: number)
	for _, modifier in H.Status(c).Modifiers do
		if modifier.Source == "자기장" and modifier.Turns > 0 then
			modifier.Turns = math.max(0, modifier.Turns + delta)
		end
	end
end

local function near(c: Card, from: any, radius: number): { any }
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

M.Pulsar_Kit = {
	TurnStart = function(c: Card)
		-- 지속이 끝난 감극은 스택도 비운다
		for _, enemy in H.Enemies(c) do
			if depolarOf(enemy) > 0 then
				local alive = false
				for _, modifier in enemy.Status.Modifiers do
					if modifier.Source == "감극" then
						alive = true
					end
				end
				if not alive then
					BattleStatus.SpendAll(enemy.Status, R.DEPOLAR)
				end
			end
		end
		-- 자기장이 끝났으면 카드에 알린다
		local now = hasField(c)
		if c.Mem.field and not now then
			BattleStatus.SpendAll(H.Status(c), R.FIELD)
			CardEffects.Fire(c.Rt, "FieldEnd", { Reflect = c.Mem.reflect or 8 })
		end
		c.Mem.field = now
	end,
	BeforeSkill = function(c: Card, info: any)
		if hasField(c) then
			c.Mem.field = true
			c.Mem.reflect = BattleStatus.Total(H.Status(c), "Reflect")
		end
		-- 아군 명중률(불완전한 빛): 깎인 만큼 빗나간다
		local accuracy = BattleStatus.Total(H.Status(c), "Accuracy")
		if accuracy < 0 and (info.Skill.Damage or 0) > 0 and H.Rng(c) < -accuracy then
			info.Mult = 0
			H.Log(c, "빗나갔다")
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			c.Mem.converged = true
		end
		if hasField(c) then
			c.Mem.field = true
			c.Mem.reflect = BattleStatus.Total(H.Status(c), "Reflect")
		end
	end,
	Gain = function(c: Card, id: string)
		if id == R.RESONATE then
			c.Mem.built = true
		end
	end,
	-- 공명을 모으지도 쓰지도 않은 턴이 끝나면 1 이 빠진다(플라이휠이 바닥을 받친다)
	TurnEnd = function(c: Card)
		if not c.Mem.converged and not c.Mem.built then
			local floor = math.floor(Q(c.Rt, "ResonateFloor", 0))
			if resonate(c) > floor then
				H.Spend(c, R.RESONATE, 1)
			end
		end
		c.Mem.converged = false
		c.Mem.built = false
	end,
}

--=== 패시브 ===--

-- 별들의 등대: 전투 시작 시 아군 전체 주는 피해 +10%, 2턴 (등대 증폭·점등이 고친다)
M.Pulsar_Beacon = {
	BattleStart = function(c: Card)
		local bonus = Q(c.Rt, "BeaconBonus", 0.1)
		local turns = math.floor(Q(c.Rt, "BeaconTurns", 2))
		local shield = Q(c.Rt, "BeaconShield", 0)
		for _, ally in H.Allies(c) do
			H.ModOn(c, ally, "DamageDealt", bonus, turns)
			if shield > 0 then
				BattleStatus.AddShield(ally.Status, math.floor(shield))
			end
		end
	end,
}

-- 중성자: 매 턴 도발 3 (파티에서 적이 나를 노린다. 솔로에서는 적이 늘 나를 노린다)
M.Pulsar_Neutron = {
	TurnStart = function(c: Card)
		local ally = H.Ally(c)
		ally.Taunt = math.max(ally.Taunt, 3)
	end,
}

-- 자전: [자기장]이 있으면 턴 끝에 스테미나 +4 (회전 +)
M.Pulsar_Spin = {
	TurnEnd = function(c: Card)
		if hasField(c) then
			local ally = H.Ally(c)
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(Q(c.Rt, "SpinStamina", 4)))
		end
	end,
}

--=== 필수 ===--

--[[
	불완전한 빛: 수렴이 공명과 상관없이 늘 {1}연타 최대치, 쓸 때마다 +{2}% (최대 {3}번).
	대신 쓸 때마다 자신의 명중률 −{4}% 영구.
]]
M.Pulsar_E_ImperfectLight = {
	Rules = {
		ConvergeFixedStacks = function(c: Card, _value: number): number
			return c.V(1)
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			info.Bonus += math.min(c.Mem.uses or 0, c.V(3)) * c.P(2)
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			c.Mem.uses = (c.Mem.uses or 0) + 1
			H.Mod(c, "Accuracy", -c.P(4), -1, tostring(c.Mem.uses))
		end
	end,
}

-- 핵파스타: 자기장 {1}턴, 반사 {2}, 감극 중첩당 ×{3}
M.Pulsar_E_NuclearPasta = {
	Rules = {
		FieldTurns = function(c: Card, value: number): number
			return value - 3 + c.V(1)
		end,
		FieldReflect = function(c: Card, value: number): number
			return value - 8 + c.V(2)
		end,
		DepolarPer = function(c: Card, value: number): number
			return value * c.V(3)
		end,
	},
}

-- 열화된 초신성: 섬광이 적 전체, 명중률 −{1}%. 섬광을 쓰면 아군 전체 피해 +{2}% {3}턴
M.Pulsar_E_DimSupernova = {
	Rules = {
		FlareAll = function(_c: Card, _value: number): number
			return 1
		end,
		FlareAccuracy = function(c: Card, value: number): number
			return value - 0.3 + c.P(1)
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Flare") then
			for _, ally in H.Allies(c) do
				H.ModOn(c, ally, "DamageDealt", c.P(2), c.V(3))
			end
			return true
		end
		return false
	end,
}

-- 정지 궤도(파티): 자기장이 다른 아군에게, 반사 ×{1}, 자기권 재사용 대기 {2}턴
M.Pulsar_E_Geostationary = {
	Party = true,
	Rules = {
		FieldOnOther = function(_c: Card, _value: number): number
			return 1
		end,
		FieldReflect = function(c: Card, value: number): number
			return value * c.V(1)
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Magnetosphere") then
			H.Ally(c).Cooldowns.Magnetosphere = c.V(2)
		end
	end,
}

--=== 희귀 ===--

-- 임계 자속: 자기장 동안 공명 상한 +{1}. 공명이 상한이면 자기장 +{2}턴(턴마다 한 번)
M.Pulsar_R_CriticalFlux = {
	Rules = {
		ResonateCap = function(c: Card, value: number): number
			return if hasField(c) then value + c.V(1) else value
		end,
	},
	Gain = function(c: Card, id: string)
		if id == R.RESONATE and hasField(c) and resonate(c) >= Q(c.Rt, "ResonateCap", 3) and H.PerTurn(c, "extend", 1) then
			shiftField(c, c.V(2))
			H.Log(c, "자기장이 길어진다")
			return true
		end
		return false
	end,
}

-- 고정 극: 섬광을 맞은 적은 {1}턴 동안 감극을 잃지 않는다
M.Pulsar_R_Lock = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Flare") then
			return
		end
		c.Mem.locked = c.Mem.locked or {}
		local turn = H.State(c).Turn
		for _, enemy in H.Enemies(c) do
			c.Mem.locked[enemy.Id] = turn + c.V(1)
		end
	end,
	TurnStart = function(c: Card, turn: number)
		for _, enemy in H.Enemies(c) do
			local untilTurn = c.Mem.locked and c.Mem.locked[enemy.Id]
			if untilTurn and turn <= untilTurn and depolarOf(enemy) > 0 then
				applyDepolar(c, enemy, 0)
			end
		end
	end,
}

-- 유도: 자기장 동안 수렴이 감극을 {1} 더
M.Pulsar_R_Induction = {
	Rules = {
		ConvergeDepolarBonus = function(c: Card, value: number): number
			return if hasField(c) then value + c.V(1) else value
		end,
	},
}

-- 방전: 반사 피해가 인접한 적에게도 {1}%
M.Pulsar_R_Arc = {
	Reflected = function(c: Card, info: any)
		local count = 0
		for _, enemy in near(c, info.Target, 1) do
			H.Hurt(c, enemy, info.Damage * c.P(1), "Physical")
			count += 1
		end
		return count > 0
	end,
}

-- 플라이휠: 공명이 턴이 지나도 {1} 아래로 떨어지지 않는다
M.Pulsar_R_Flywheel = {
	Rules = {
		ResonateFloor = function(c: Card, value: number): number
			return math.max(value, c.V(1))
		end,
	},
}

-- 등대 증폭: 별들의 등대 +{1}% → +{2}%, {3}턴 더
M.Pulsar_R_Beacon = {
	Rules = {
		BeaconBonus = function(c: Card, value: number): number
			return value - c.P(1) + c.P(2)
		end,
		BeaconTurns = function(c: Card, value: number): number
			return value + c.V(3)
		end,
	},
}

-- 재충전: 자기장이 끝날 때 재사용 대기 {1}턴 감소
M.Pulsar_R_Recharge = {
	FieldEnd = function(c: Card)
		for id, left in H.Ally(c).Cooldowns do
			H.Ally(c).Cooldowns[id] = math.max(0, left - c.V(1))
		end
		return true
	end,
}

-- 정밀 조율: 수렴 QTE 성공 보너스 {1}% → {2}%
M.Pulsar_R_QteMastery = {
	Rules = {
		ConvergeQteBonus = function(c: Card, value: number): number
			return math.max(value, c.P(2))
		end,
	},
}

-- 접지: 감극 {1}중첩인 적에게 피해 +{2}%
M.Pulsar_R_Grounding = {
	BeforeHit = function(c: Card, info: any)
		if depolarOf(info.Target) >= c.V(1) then
			info.Bonus += c.P(2)
		end
	end,
}

-- 차폐: 자기장 동안 그로기가 차지 않는다. 막을 때마다 자기장 −{1}턴
M.Pulsar_R_Shroud = {
	Rules = {
		GroggyImmune = function(c: Card, value: number): number
			return if hasField(c) then 1 else value
		end,
	},
	Defend = function(c: Card, info: any)
		if hasField(c) and info.Grade == "Fail" and c.V(1) > 0 then
			shiftField(c, -c.V(1))
		end
	end,
}

--=== 일반 ===--

-- 반사 강화: 자기권 반사 +{1}
M.Pulsar_C_ReflectUp = {
	Rules = {
		FieldReflect = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 감극 활용: 감극 {1}중첩당 피해 +{2}%
M.Pulsar_C_DepolarDamage = {
	BeforeHit = function(c: Card, info: any)
		local stacks = depolarOf(info.Target)
		if stacks > 0 then
			info.Bonus += math.floor(stacks / c.V(1)) * c.P(2)
		end
	end,
}

-- 회전: 자전 스테미나 +{1}
M.Pulsar_C_Spin = {
	Rules = {
		SpinStamina = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 궤도: 수렴을 쓴 다음 턴에는 스킬 스테미나 −{1}%
M.Pulsar_C_Orbit = {
	Rules = {
		StaminaCost = function(c: Card, value: number): number
			return if c.Mem.turn == H.State(c).Turn then value * (1 - c.P(1)) else value
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			c.Mem.turn = H.State(c).Turn + 1
		end
	end,
}

-- 잔광: 섬광이 {1} 피해도 준다
M.Pulsar_C_Afterglow = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Flare") then
			return false
		end
		for _, unit in c.Mem.targets or {} do
			if unit.Alive then
				H.Hurt(c, unit, c.V(1), "Physical")
			end
		end
		c.Mem.targets = nil
		return true
	end,
	-- 섬광은 피해 0 스킬이라 Hits 가 비어 있다 — 맞은 적은 BeforeSkill 의 Targets 로 센다
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Flare") then
			c.Mem.targets = info.Targets
		end
	end,
}

-- 인력(파티): 중성자의 표적 확률 +{1}%
M.Pulsar_C_Attraction = {
	Party = true,
}

-- 자화: 전투 시작 시 자기장 {1}턴
M.Pulsar_C_Magnetize = {
	BattleStart = function(c: Card)
		BattleSkillEffects.ApplyField(H.Status(c), c.V(1), Q(c.Rt, "FieldReflect", 8))
		c.Mem.field = true
	end,
}

-- 역류: 반사 피해로 적을 처치하면 공명 {1}
M.Pulsar_C_Backflow = {
	Reflected = function(c: Card, info: any)
		if not info.Target.Alive then
			H.Gain(c, R.RESONATE, c.V(1))
			return true
		end
		return false
	end,
}

-- 잔류: 감극 지속 +{1}턴
M.Pulsar_C_Residue = {
	Rules = {
		DepolarTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 집속: 수렴 피해 +{1}%
M.Pulsar_C_Focused = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			info.Bonus += c.P(1)
		end
	end,
}

-- 수호광: 체력이 절반 아래인 아군 받는 피해 −{1}% (솔로면 자신)
M.Pulsar_C_GuardLight = {
	BeforeTaken = function(c: Card, info: any)
		if H.HealthRatio(c) < 0.5 then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 정지장: 이동하지 않은 턴에는 반사 +{1}%
M.Pulsar_C_StaticField = {
	Rules = {
		ReflectAmount = function(c: Card, value: number): number
			return if H.State(c).Moved then value else value * (1 + c.P(1))
		end,
	},
}

-- 잔상: 섬광 명중률 감소 +{1}%p
M.Pulsar_C_Afterimage = {
	Rules = {
		FlareAccuracy = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 반동 제어: 수렴을 {1}번 쓸 때마다 다음 턴 받는 피해 −{2}%
M.Pulsar_C_RecoilControl = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Converge") then
			return false
		end
		c.Mem.uses = (c.Mem.uses or 0) + 1
		if c.Mem.uses >= c.V(1) then
			c.Mem.uses = 0
			H.Mod(c, "DamageTaken", -c.P(2), 2)
			return true
		end
		return false
	end,
}

-- 중계: 감극 걸린 적을 처치하면 남은 중첩의 {1}%가 가장 가까운 적에게
M.Pulsar_C_Relay = {
	Kill = function(c: Card, info: any)
		local stacks = depolarOf(info.Target)
		if stacks <= 0 then
			return false
		end
		local from = c.Mem.lastCell and c.Mem.lastCell[info.Target.Id]
		local best, bestDistance = nil, math.huge
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if cell then
				local distance = if from then math.abs(cell.X - from.X) + math.abs(cell.Y - from.Y) else 0
				if distance < bestDistance then
					best, bestDistance = enemy, distance
				end
			end
		end
		local moved = math.floor(stacks * c.P(1))
		if best and moved > 0 then
			applyDepolar(c, best, moved)
			return true
		end
		return false
	end,
	-- 쓰러지면 칸이 비므로 맞기 전에 자리를 적어 둔다
	BeforeHit = function(c: Card, info: any)
		c.Mem.lastCell = c.Mem.lastCell or {}
		c.Mem.lastCell[info.Target.Id] = H.Cell(c, info.Target)
	end,
}

-- 점등: 별들의 등대가 보호막 {1}도
M.Pulsar_C_LightUp = {
	Rules = {
		BeaconShield = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 코일: 공명 {1}스택당 수렴 피해 +{2}%, 최대 {3}%
M.Pulsar_C_Coil = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") then
			info.Bonus += math.min(math.floor(resonate(c) / c.V(1)) * c.P(2), c.P(3))
		end
	end,
}

-- 방출 조율: 자기장이 끝날 때 주변 {1}칸 적에게 반사 피해의 {2}%
M.Pulsar_C_Discharge = {
	FieldEnd = function(c: Card, info: any)
		local mine = H.Cell(c)
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			-- 적 칸은 반대편 격자라 중앙선을 사이에 두고 잰다(열 합)
			if mine and cell and mine.X + cell.X - 1 <= c.V(1) + 1 and math.abs(cell.Y - mine.Y) <= c.V(1) then
				H.Hurt(c, enemy, (info.Reflect or 8) * c.P(2), "Physical")
				count += 1
			end
		end
		if count > 0 then
			H.Log(c, string.format("자기장이 터졌다 — %d기", count))
		end
		return count > 0
	end,
}

-- 고정 조준: 수렴 QTE 가 방어 판정이면 {1}% 확률로 성공 판정
M.Pulsar_C_FixedAim = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "Converge") and info.Grade == "Partial" and H.Rng(c) < c.P(1) then
			info.Mult *= QteDefinitions.Multiplier("Skill", "Success") / math.max(0.01, QteDefinitions.Multiplier("Skill", "Partial"))
			H.Log(c, "조준이 맞았다")
			return true
		end
		return false
	end,
}

-- 여광: 자기장이 끝난 다음 턴까지 받는 피해 감소의 {1}%가 남는다
M.Pulsar_C_Trailing = {
	FieldEnd = function(c: Card)
		H.Mod(c, "DamageTaken", -0.2 * c.P(1), 1)
		return true
	end,
}

return M
end
