--!strict
--[[
	음악가 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	수치는 전부 카드 글의 {숫자}(Levels 사다리)에서 읽는다: c.V(1) = 첫 번째 {숫자}.

	키트(Musician_Kit) — `유저 아이디어(직업).md` 의 음표 버프. 음표가 바뀔 때마다 다시 건다(출처 "음표").
	  4분음표 n  아군 스테미나 획득 +2n%, 치명 확률 +0.5n%, 자신의 두 번째 턴마다 아군 보호막 n
	  8분음표 n  아군 치명 확률·치명 피해 +n%
	  16분음표 n 아군 치명 확률 −0.5n%, 치명 피해 +2n%, 피해 +1.5n%
	  → 버프 배율(BuffScale: 반주자·협주자·긴 호흡), 협주자면 자신에게만.
	  음표 종류 카드(4분·8분·16분 강조, 배음)는 규칙 질의로 개수당 값을 더한다.
]]

local ClassResources = require(script.Parent.Parent.ClassResources)
local BattleStatus = require(script.Parent.Parent.BattleStatus)

local R = ClassResources

type Card = any

-- 엔진(CardEffects)을 받아 카드 표를 돌려준다(엔진을 require 하면 순환이 된다)
return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local NOTE_OF_SKILL = { Veloce = R.QUARTER, Brillante = R.EIGHTH, Crescendo = R.SIXTEENTH }

local function isNote(id: string): boolean
	return id == R.QUARTER or id == R.EIGHTH or id == R.SIXTEENTH
end

local function randomNote(c: Card, amount: number): number
	local pick = R.NOTE_IDS[math.floor(H.Rng(c) * 3) + 1]
	return H.Gain(c, pick, amount + Q(c.Rt, "NoteGainBonus", 0))
end

local function noteCap(c: Card): number
	local meter = math.max(1, H.Stack(c, R.METER))
	return R.NoteCap(meter) + Q(c.Rt, "NoteCapBonus", 0)
end

local function hasBrillante(unit: any): boolean
	for _, modifier in unit.Status.Modifiers do
		if modifier.Source == "브릴란테" then
			return true
		end
	end
	return false
end

-- 음표 버프를 다시 건다
local function refreshNotes(c: Card)
	local q, e, s = H.Stack(c, R.QUARTER), H.Stack(c, R.EIGHTH), H.Stack(c, R.SIXTEENTH)
	local scale = Q(c.Rt, "BuffScale", 1)
	local quarterStamina = 0.02 + Q(c.Rt, "QuarterStamina", 0)
	local eighthCrit = 0.01 + Q(c.Rt, "EighthCrit", 0)
	local sixteenthPenalty = math.max(0, 0.005 - Q(c.Rt, "SixteenthPenalty", 0))
	local sixteenthCritDamage = 0.02 + Q(c.Rt, "SixteenthCritDamage", 0)
	local critChance = (0.005 * q + eighthCrit * e - sixteenthPenalty * s) * scale
	local critDamage = (eighthCrit * e + sixteenthCritDamage * s) * scale
	local damage = 0.015 * s * scale
	local stamina = quarterStamina * q * scale
	local targets = if Q(c.Rt, "ChorusSelfOnly", 0) >= 1 then { H.Ally(c) } else H.Allies(c)
	for _, ally in targets do
		BattleStatus.RemoveBySource(ally.Status, "음표")
		if critChance ~= 0 then
			BattleStatus.AddModifier(ally.Status, "CritChance", critChance, -1, "음표")
		end
		if critDamage ~= 0 then
			BattleStatus.AddModifier(ally.Status, "CritDamage", critDamage, -1, "음표")
		end
		if damage ~= 0 then
			BattleStatus.AddModifier(ally.Status, "DamageDealt", damage, -1, "음표")
		end
		if stamina ~= 0 then
			BattleStatus.AddModifier(ally.Status, "StaminaGain", stamina, -1, "음표")
		end
	end
end

local M: { [string]: any } = {}

--=== 키트 ===--

M.Musician_Kit = {
	BattleStart = function(c: Card)
		refreshNotes(c)
	end,
	TurnStart = function(c: Card, turn: number)
		-- 4분음표: 자신의 두 번째 턴마다 아군에게 (개수)의 보호막
		if turn % 2 == 0 then
			local q = H.Stack(c, R.QUARTER)
			if q > 0 then
				local amount = math.floor(q * Q(c.Rt, "BuffScale", 1))
				for _, ally in H.Allies(c) do
					BattleStatus.AddShield(ally.Status, amount)
				end
			end
		end
		refreshNotes(c)
	end,
	Gain = function(c: Card, id: string)
		if isNote(id) then
			refreshNotes(c)
		end
	end,
	Spend = function(c: Card, id: string)
		if isNote(id) then
			refreshNotes(c)
		end
	end,
	AfterSkill = function(c: Card)
		refreshNotes(c)
	end,
}

--=== 패시브 ===--

-- 청중: 스킬에 두 번 피격될 때마다 무작위 음표 1개
M.Musician_Listener = {
	Taken = function(c: Card)
		c.Mem.hits = (c.Mem.hits or 0) + 1
		if c.Mem.hits >= 2 then
			c.Mem.hits = 0
			randomNote(c, 1)
			return true
		end
		return false
	end,
}

-- 후렴: 음표를 4개 얻을 때마다 최대 체력 2.5% 회복(후렴 카드가 간격·양을 바꾼다)
M.Musician_Refrain = {
	Gain = function(c: Card, id: string, amount: number)
		if not isNote(id) then
			return false
		end
		local every = math.max(1, math.floor(Q(c.Rt, "RefrainEvery", 4)))
		c.Mem.count = (c.Mem.count or 0) + amount
		local fired = false
		while c.Mem.count >= every do
			c.Mem.count -= every
			H.Heal(c, 0.025 + Q(c.Rt, "RefrainHealBonus", 0))
			fired = true
		end
		return fired
	end,
}

--=== 필수 ===--

-- 긴 호흡: 크레셴도를 안 쓴 턴마다 주는 버프 +{5}%(최대 {40}%), 크레셴도로 초기화. 브릴란테를 줄 때마다 체력 {5}% 회복
M.Musician_E_LongBreath = {
	Rules = {
		BuffScale = function(c: Card, value: number): number
			return value * (1 + (c.Mem.ramp or 0))
		end,
	},
	TurnStart = function(c: Card, turn: number)
		if turn > 1 and not c.Mem.crescendoLastTurn then
			c.Mem.ramp = math.min((c.Mem.ramp or 0) + c.P(1), c.P(2))
		end
		c.Mem.crescendoLastTurn = false
	end,
	AfterSkill = function(c: Card, info: any)
		local id = info.Skill.Id
		if id == "Crescendo" or id == "CrescendoAlForte" then
			c.Mem.ramp = 0
			c.Mem.crescendoLastTurn = true
		elseif id == "Brillante" then
			H.Heal(c, c.P(3))
			return true
		end
		return false
	end,
}

-- 공명: 음표 상한 +{2}. 음표를 소모할 때마다 아군 치명 피해·자신 치명 확률 +{5}%(최대 {30}%·{15}%)
M.Musician_E_Resonance = {
	Rules = {
		NoteCapBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
	Spend = function(c: Card, id: string)
		if not isNote(id) then
			return false
		end
		-- 한 번의 소모(여러 종류가 같이 빠져도)를 한 번으로 센다
		if not CardEffects.PerTurn(c, "spend", 1) then
			return false
		end
		c.Mem.stacks = (c.Mem.stacks or 0) + 1
		local critDamage = math.min(c.Mem.stacks * c.P(2), c.P(3))
		local critChance = math.min(c.Mem.stacks * c.P(2), c.P(4))
		for _, ally in H.Allies(c) do
			BattleStatus.RemoveBySource(ally.Status, "카드:" .. c.Id)
			BattleStatus.AddModifier(ally.Status, "CritDamage", critDamage, -1, "카드:" .. c.Id)
		end
		H.Clear(c, "self")
		H.Mod(c, "CritChance", critChance, -1, "self")
		return true
	end,
}

-- 반주자: 딜링 스킬 기본 피해 −{60}%, 음표·브릴란테 버프 ×{1.5}
M.Musician_E_Accompanist = {
	Rules = {
		BuffScale = function(c: Card, value: number): number
			return value * c.V(2)
		end,
	},
	BeforeSkill = function(c: Card, info: any)
		if info.Skill.Damage > 0 then
			info.Mult *= math.max(0, 1 - c.P(1))
		end
	end,
}

-- 협주자: 음표·브릴란테의 아군 버프가 없어지고 자신에게 ×{1.5}
M.Musician_E_Concertist = {
	Rules = {
		BuffScale = function(c: Card, value: number): number
			return value * c.V(1)
		end,
		ChorusSelfOnly = function(_c: Card, _value: number): number
			return 1
		end,
	},
}

--=== 희귀 ===--

-- 메트로놈: {3}턴마다 무작위 음표 {1}개
M.Musician_R_Metronome = {
	TurnStart = function(c: Card, turn: number)
		local every = math.max(1, math.floor(c.V(1)))
		if turn > 1 and (turn - 1) % every == 0 then
			randomNote(c, math.floor(c.V(2)))
			return true
		end
		return false
	end,
}

-- 지속음: 브릴란테 +{1}턴
M.Musician_R_Sustain = {
	Rules = {
		BrillanteTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 전조: 박자표를 얻을 때마다 모든 적에게 소모한 음표 수×{1.5} 피해
M.Musician_R_Modulation = {
	TurnStart = function(c: Card)
		c.Mem.spent = 0
	end,
	Spend = function(c: Card, id: string, amount: number)
		if isNote(id) then
			c.Mem.spent = (c.Mem.spent or 0) + amount
		end
	end,
	Gain = function(c: Card, id: string)
		if id ~= R.METER then
			return false
		end
		local amount = (c.Mem.spent or 0) * c.V(1)
		c.Mem.spent = 0
		if amount <= 0 then
			return false
		end
		for _, enemy in H.Enemies(c) do
			H.Hurt(c, enemy, amount, "True")
		end
		H.Log(c, string.format("모든 적에게 %d 피해", math.floor(amount)))
		return true
	end,
}

-- 울림: 브릴란테가 끝난 다음 턴까지 효과의 {20}%가 남는다
M.Musician_R_Cadenza = {
	TurnStart = function(c: Card)
		local ally = H.Ally(c)
		local now = hasBrillante(ally)
		if c.Mem.had and not now and (c.Mem.lastCrit or 0) > 0 then
			H.Mod(c, "CritChance", c.Mem.lastCrit * c.P(1), 1)
			H.Mod(c, "CritDamage", (c.Mem.lastCritDamage or 0) * c.P(1), 1)
		end
		c.Mem.had = now
		if now then
			c.Mem.lastCrit, c.Mem.lastCritDamage = 0, 0
			for _, modifier in ally.Status.Modifiers do
				if modifier.Source == "브릴란테" then
					if modifier.Kind == "CritChance" then
						c.Mem.lastCrit += modifier.Value
					elseif modifier.Kind == "CritDamage" then
						c.Mem.lastCritDamage += modifier.Value
					end
				end
			end
		end
	end,
}

-- 투티(파티): 아군이 {3}명 이상 살아 있으면 음표 획득량 +{1}
M.Musician_R_Tutti = {
	Party = true,
	Rules = {
		NoteGainBonus = function(c: Card, value: number): number
			return if #H.Allies(c) >= c.V(1) then value + c.V(2) else value
		end,
	},
}

-- 페르마타: 공격하지 않고 턴을 마치면 무작위 음표 {1}개, 브릴란테 지속 +{1}턴
M.Musician_R_Fermata = {
	TurnEnd = function(c: Card, info: any)
		if info.Attacked then
			return false
		end
		randomNote(c, math.floor(c.V(1)))
		for _, ally in H.Allies(c) do
			for _, modifier in ally.Status.Modifiers do
				if modifier.Source == "브릴란테" and modifier.Turns > 0 then
					modifier.Turns += math.floor(c.V(2))
				end
			end
		end
		return true
	end,
}

-- 배음: 16분음표 1개당 아군 치명 피해 +{1}% 더
M.Musician_R_Harmonic = {
	Rules = {
		SixteenthCritDamage = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 오스티나토: 전투당 {1}회, 같은 스킬을 연속으로 쓰면 그 스킬의 음표 1개 더
M.Musician_R_Ostinato = {
	AfterSkill = function(c: Card, info: any)
		local id = info.Skill.Id
		local previous = c.Mem.previous
		c.Mem.previous = id
		local note = NOTE_OF_SKILL[id]
		if note and previous == id and CardEffects.PerBattle(c, "repeat", math.floor(c.V(1))) then
			H.Gain(c, note, 1)
			return true
		end
		return false
	end,
}

-- 자장가: 브릴란테를 쓴 턴에 가장 가까운 적의 다음 행동이 한 턴 늦어진다(이번 턴 예고한 공격을 거둔다)
M.Musician_R_Overture = {
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Id ~= "Brillante" then
			return false
		end
		local state = H.State(c)
		local best, bestX = nil, math.huge
		for _, id in state.Planned do
			local cell = H.Cell(c, state.Units[id])
			if cell and cell.X < bestX then
				best, bestX = id, cell.X
			end
		end
		if best then
			table.remove(state.Planned, table.find(state.Planned, best) :: number)
			H.Log(c, string.format("%s의 다음 행동이 늦어졌다", state.Units[best].Name))
			return true
		end
		return false
	end,
}

-- 데스캉트: 브릴란테를 받은 아군 치명 확률 +{3}%, 그 아군이 치명타를 내면 턴당 {1}회 음표 1개
M.Musician_R_Descant = {
	Rules = {
		BrillanteCrit = function(c: Card, value: number): number
			return value + c.P(2)
		end,
	},
	Hit = function(c: Card, info: any)
		if info.Crit and hasBrillante(H.Ally(c)) and CardEffects.PerTurn(c, "crit", math.floor(c.V(1))) then
			randomNote(c, 1)
			return true
		end
		return false
	end,
}

--=== 일반 ===--

-- 절약: 음표를 두 번째로 소모할 때마다 {1}개 덜 소모(돌려받는다)
M.Musician_C_HalfSpend = {
	Spend = function(c: Card, id: string)
		if not isNote(id) or not CardEffects.PerTurn(c, "spend", 1) then
			return false
		end
		c.Mem.count = (c.Mem.count or 0) + 1
		if c.Mem.count % 2 == 0 then
			randomNote(c, math.floor(c.V(1)))
			return true
		end
		return false
	end,
}

-- 마디줄: 박자표가 오를 때마다 아군 보호막 {5}
M.Musician_C_BarLine = {
	Gain = function(c: Card, id: string)
		if id ~= R.METER then
			return false
		end
		for _, ally in H.Allies(c) do
			BattleStatus.AddShield(ally.Status, math.floor(c.V(1)))
		end
		return true
	end,
}

-- 전주: 전투당 각 음표를 처음 얻을 때 체력 {2}% 회복
M.Musician_C_Prelude = {
	Gain = function(c: Card, id: string)
		if isNote(id) and CardEffects.PerBattle(c, id, 1) then
			H.Heal(c, c.P(1))
			return true
		end
		return false
	end,
}

-- 온쉼표: 이동하지도 공격하지도 않고 턴을 넘기면 스테미나 +{8}
M.Musician_C_Rest = {
	TurnEnd = function(c: Card, info: any)
		if info.Attacked or info.Moved then
			return false
		end
		local ally = H.Ally(c)
		ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + math.floor(c.V(1)))
		return true
	end,
}

-- 4분 강조: 4분음표의 스테미나 획득 증가 +{0.5}%/개
M.Musician_C_Quarter = {
	Rules = {
		QuarterStamina = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 8분 강조: 8분음표의 치명 확률·피해 증가 +{0.5}%p/개
M.Musician_C_Eighth = {
	Rules = {
		EighthCrit = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 16분 강조: 16분음표의 치명 확률 감소가 개수당 {0.2}% 줄어든다
M.Musician_C_Sixteenth = {
	Rules = {
		SixteenthPenalty = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 송진: 벨로체 보호막 {2} → {4}
M.Musician_C_Rosin = {
	Rules = {
		VeloceShield = function(c: Card, value: number): number
			return math.max(value, c.V(2))
		end,
	},
}

-- 비브라토: 브릴란테를 받은 아군의 받는 회복량 +{15}%
M.Musician_C_Vibrato = {
	TurnStart = function(c: Card)
		for _, ally in H.Allies(c) do
			if hasBrillante(ally) then
				H.ModOn(c, ally, "HealTaken", c.P(1), 1)
			end
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Id == "Brillante" then
			for _, ally in H.Allies(c) do
				H.ModOn(c, ally, "HealTaken", c.P(1), 1)
			end
		end
	end,
}

-- 스타카토: 음표를 소모하면 그 턴 동안 주는 피해 +{8}%
-- (소모는 크레셴도가 판정 **안에서** 하므로, 소모할 스킬이면 판정 전에 붙인다)
M.Musician_C_Staccato = {
	BeforeSkill = function(c: Card, info: any)
		local id = info.Skill.Id
		local spends = id == "CrescendoAlForte" or (id == "Crescendo" and H.NoteTotal(c) >= noteCap(c))
		if spends and H.NoteTotal(c) > 0 then
			info.Bonus += c.P(1)
		end
	end,
}

-- 운궁: 전투당 {1}회, 평타(벨로체) 뒤 무작위 음표 1개
M.Musician_C_Bowing = {
	AfterSkill = function(c: Card, info: any)
		if info.Skill.Id == "Veloce" and CardEffects.PerBattle(c, "bow", math.floor(c.V(1))) then
			randomNote(c, 1)
			return true
		end
		return false
	end,
}

-- 조율: 후열에 서 있으면 박자표 1당 받는 피해 −{4}%
M.Musician_C_Tuning = {
	BeforeTaken = function(c: Card, info: any)
		if H.IsBack(c) then
			info.Mult *= math.max(0, 1 - c.P(1) * H.Stack(c, R.METER))
		end
	end,
}

-- 갈채: 적을 처치하면 무작위 음표 {1}개
M.Musician_C_Applause = {
	Kill = function(c: Card)
		randomNote(c, math.floor(c.V(1)))
		return true
	end,
}

-- 서곡: 전투당 {1}회, 처음 쓰는 공격 스킬 피해 +{10}%
M.Musician_C_Lullaby = {
	BeforeSkill = function(c: Card, info: any)
		if info.Skill.Damage > 0 and CardEffects.PerBattle(c, "open", math.floor(c.V(1))) then
			info.Bonus += c.P(2)
		end
	end,
}

-- 불협화음: 같은 스킬을 2회 이상 연달아 쓰면 그 스킬 피해 +{5}%
M.Musician_C_Score = {
	BeforeSkill = function(c: Card, info: any)
		if info.Skill.Damage > 0 and c.Mem.previous == info.Skill.Id then
			info.Bonus += c.P(1)
		end
	end,
	AfterSkill = function(c: Card, info: any)
		c.Mem.previous = info.Skill.Id
	end,
}

-- 카덴차: 음표 수가 최대일 때 주는 피해 +{12}%
M.Musician_C_Echo = {
	BeforeSkill = function(c: Card, info: any)
		if H.NoteTotal(c) >= noteCap(c) then
			info.Bonus += c.P(1)
		end
	end,
}

-- 아첼레란도: 크레셴도의 음표당 피해 +{0.5}% 더
M.Musician_C_Crescendo = {
	BeforeSkill = function(c: Card, info: any)
		if info.Skill.Id == "Crescendo" or info.Skill.Id == "CrescendoAlForte" then
			info.Bonus += H.NoteTotal(c) * c.P(1)
		end
	end,
}

-- 앙코르: 박자표가 {3}일 때 주는 피해 +{7}%
M.Musician_C_Encore = {
	BeforeSkill = function(c: Card, info: any)
		if H.Stack(c, R.METER) >= c.V(1) then
			info.Bonus += c.P(2)
		end
	end,
}

-- 화음(파티): 둘 이상의 아군에게 브릴란테가 있으면 자신의 벨로체도 브릴란테 효과를 절반 받는다
M.Musician_C_Chord = {
	Party = true,
	BeforeSkill = function(c: Card, info: any)
		if info.Skill.Id ~= "Veloce" then
			return
		end
		local count = 0
		for _, ally in H.Allies(c) do
			if hasBrillante(ally) then
				count += 1
			end
		end
		if count >= 2 then
			local brillante = H.Stack(c, R.BRILLANTE)
			-- 브릴란테는 스택당 1.5% — 그중 {1}%
			info.Crit += brillante * 0.015 * c.P(1)
			info.CritDamage += brillante * 0.015 * c.P(1)
		end
	end,
}

-- 후렴(카드): 음표 {4}개마다(패시브 후렴의 간격) 회복이 최대 체력 {1}% 더
M.Musician_C_Refrain = {
	Rules = {
		RefrainEvery = function(c: Card, value: number): number
			return math.min(value, c.V(1))
		end,
		RefrainHealBonus = function(c: Card, value: number): number
			return value + c.P(2)
		end,
	},
}

return M
end
