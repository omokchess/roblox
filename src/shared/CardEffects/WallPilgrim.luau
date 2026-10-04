--!strict
--[[
	월 필그림스 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(WallPilgrim_Kit)
	  [광신] 지속(보정값 "광신")이 끝나면 스택도 비운다. [낙인] 지속(보정값 "낙인")도 같다.
	  광신은 BattleSkillEffects.ApplyZeal 한 곳에서 건다 — 상한(ZealCap)·배율(ZealScale)·지속(ZealTurns)·
	  지속 피해 모드(ZealDot)를 카드가 질의로 바꾼다.
	  신앙심(ally.Faith)은 전투 안에서 오른다(순례 지팡이·묵상·성가…). 광신 수치가 신앙심 10당 +10%(최대 +50%).

	축(CardAxes): 심판(Judgment, 한 적에 깊게) · 전파(Spread, 여럿에 넓게) · 낙인(Mark) · 신앙(Faith)
	자리: 못질(근접)·합창(원거리 줄 전체) — 앞에서 박고 뒤에서 퍼뜨린다. 긴 팔은 뒤 칸까지.
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

local function zealOf(unit: any): number
	return BattleStatus.Stack(unit.Status, R.ZEAL)
end

local function zealCap(c: Card): number
	return math.floor(Q(c.Rt, "ZealCap", ClassResources.Cap(R.ZEAL) or 10))
end

-- 카드가 광신을 건다(스킬과 같은 규칙)
local function zeal(c: Card, unit: any, stacks: number)
	if not unit or not unit.Alive or stacks <= 0 then
		return
	end
	BattleSkillEffects.ApplyZeal(
		unit.Status,
		stacks,
		H.Ally(c).Faith or 0,
		zealCap(c),
		Q(c.Rt, "ZealScale", 1),
		math.floor(Q(c.Rt, "ZealTurns", 3)),
		Q(c.Rt, "ZealDot", 0) >= 1
	)
end

local function addFaith(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Faith = (ally.Faith or 0) + math.floor(amount)
end

local function isBranded(unit: any): boolean
	for _, modifier in unit.Status.Modifiers do
		if modifier.Source == "낙인" then
			return true
		end
	end
	return false
end

-- 적이 쓰러지면 칸이 비므로 맞기 전 자리를 적어 둔다(못 자국·중계)
local function rememberCell(c: Card, info: any)
	c.Rt.LastCells = c.Rt.LastCells or {}
	c.Rt.LastCells[info.Target.Id] = H.Cell(c, info.Target)
end

local function nearestTo(c: Card, from: any): any?
	local cell = c.Rt.LastCells and c.Rt.LastCells[from.Id]
	local best, bestDistance = nil, math.huge
	for _, enemy in H.Enemies(c) do
		local other = H.Cell(c, enemy)
		if enemy ~= from and other then
			local distance = if cell then math.abs(other.X - cell.X) + math.abs(other.Y - cell.Y) else 0
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

-- 내게서 가장 가까운 적(열 합이 작을수록, 줄 차이가 작을수록)
local function nearestEnemy(c: Card): any?
	local mine = H.Cell(c)
	local best, bestDistance = nil, math.huge
	for _, enemy in H.Enemies(c) do
		local cell = H.Cell(c, enemy)
		if mine and cell then
			local distance = mine.X + cell.X + math.abs(cell.Y - mine.Y)
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

local M: { [string]: any } = {}

--=== 키트 ===--

M.WallPilgrim_Kit = {
	BeforeHit = rememberCell,
	TurnStart = function(c: Card)
		for _, enemy in H.Enemies(c) do
			if zealOf(enemy) > 0 then
				local alive = false
				for _, modifier in enemy.Status.Modifiers do
					if modifier.Source == "광신" then
						alive = true
					end
				end
				if not alive then
					BattleStatus.SpendAll(enemy.Status, R.ZEAL)
				end
			end
		end
	end,
}

--=== 패시브 ===--

-- 순례길: 같은 행의 다른 월 필그림 아군 신앙심 +8 — 파티 전제라 솔로에서는 할 일이 없다.

--[[
	각인: 광신이 10 이상 쌓인 적에게 [낙인](받는 회복 −50%, 3턴). 한 번에 한 적(성무일도면 둘).
]]
M.WallPilgrim_Sigil = {
	Status = function(c: Card, info: any)
		if info.Kind ~= "Zeal" or zealOf(info.Target) < 10 or not info.Target.Alive then
			return false
		end
		local limit = math.floor(Q(c.Rt, "BrandCount", 1))
		local branded = {}
		for _, enemy in H.Enemies(c) do
			if enemy ~= info.Target and isBranded(enemy) then
				table.insert(branded, enemy)
			end
		end
		while #branded >= limit and #branded > 0 do
			local other = table.remove(branded, 1).Status
			BattleStatus.RemoveBySource(other, "낙인")
			BattleStatus.SpendAll(other, R.BRAND)
		end
		local turns = math.floor(Q(c.Rt, "BrandTurns", 3))
		-- 2026-10-04: 낙인은 스택(못질이 1씩 쌓는다) — 각인도 1 얹는다
		BattleSkillEffects.ApplyBrand(info.Target.Status, 1, turns)
		CardEffects.Fire(c.Rt, "Branded", { Target = info.Target, Turns = turns })
		H.Log(c, info.Target.Name .. " 에게 낙인")
		return true
	end,
}

--[[
	못 자국: 광신이 걸린 적을 처치하면 그 광신을 가장 가까운 다른 적에게 그대로 옮긴다(못 자국 넓히기 +).
	낙인 찍힌 적이고 본보기가 있으면 광신이 가장 높은 적에게 통째로.
]]
M.WallPilgrim_NailMark = {
	Kill = function(c: Card, info: any)
		local stacks = zealOf(info.Target)
		if stacks <= 0 then
			return false
		end
		local target = nil
		local example = CardEffects.Has(c.Rt, "WallPilgrim_R_MadeExample")
		if example and isBranded(info.Target) then
			local best = -1
			for _, enemy in H.Enemies(c) do
				if zealOf(enemy) > best then
					target, best = enemy, zealOf(enemy)
				end
			end
			stacks += example.V(1)
		else
			target = nearestTo(c, info.Target)
		end
		if not target then
			return false
		end
		zeal(c, target, stacks + math.floor(Q(c.Rt, "NailMarkBonus", 0)))
		CardEffects.Fire(c.Rt, "ZealMoved", { Target = target, Stacks = stacks })
		H.Log(c, string.format("광신 %d 이 %s 에게 옮겨갔다", stacks, target.Name))
		return true
	end,
}

--=== 필수 ===--

-- 광신도: 광신 상한 {1}→{2}, 중첩당 수치 절반. 광신 걸린 적 하나당 자신 받는 피해 +{3}%
M.WallPilgrim_E_Fanatic = {
	Rules = {
		ZealCap = function(c: Card, _value: number): number
			return c.V(2)
		end,
		ZealScale = function(_c: Card, value: number): number
			return value * 0.5
		end,
	},
	TurnStart = function(c: Card)
		H.Clear(c)
		local count = 0
		for _, enemy in H.Enemies(c) do
			if zealOf(enemy) > 0 then
				count += 1
			end
		end
		if count > 0 then
			H.Mod(c, "DamageTaken", count * c.P(3), -1)
		end
	end,
}

-- 성흔: 광신이 디버프 대신 지속 피해 — 중첩 {1}당 턴마다 {2} 피해(죽이지 않는다)
-- 성흔(2026-10-04 리워크): 턴당 {1}회, 스킬로 공격하면 맞은 적마다 그 적의 [광신] 수치만큼 [파상풍]
M.WallPilgrim_E_Stigmata = {
	AfterSkill = function(c: Card, info: any)
		if not info.Hits or not H.PerTurn(c, "stigmata", c.V(1)) then
			return false
		end
		local seen, any = {}, false
		for _, list in info.Hits do
			for _, enemy in list do
				if not seen[enemy] and enemy.Alive then
					seen[enemy] = true
					local z = zealOf(enemy)
					if z > 0 then
						BattleSkillEffects.TetanusHit(enemy, z, function(key, base)
							return Q(c.Rt, key, base)
						end, function(unit, amount)
							return c.Rt.Env.Damage(unit, amount, "True", true)
						end, function()
							return H.Enemies(c)
						end, function(text)
							H.Log(c, text)
						end)
						any = true
					end
				end
			end
		end
		if any then
			H.Log(c, "성흔 — 광신만큼 파상풍")
		end
		return any
	end,
}

-- 파상풍 카드(2026-10-04): 질의만 바꾼다(BattleSkillEffects.TetanusHit · GridBattle 스킬 실패)
M.WallPilgrim_C_RustSpread = {
	Rules = {
		TetanusBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}
M.WallPilgrim_C_RottenNail = {
	Rules = {
		NailingTetanus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}
M.WallPilgrim_C_Debility = {
	Rules = {
		TetanusFail = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}
M.WallPilgrim_R_LockjawFit = {
	Rules = {
		TetanusBurstRatio = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}
M.WallPilgrim_R_Rigor = {
	Rules = {
		TetanusSpread = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 전도: 합창이 적 전체(중첩 절반), 재사용 대기 {1}턴
M.WallPilgrim_E_Evangelism = {
	Rules = {
		ChoraleHalf = function(_c: Card, _value: number): number
			return 1
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Chorale") then
			return false
		end
		H.Ally(c).Cooldowns.Chorale = c.V(1)
		local hitIds, hits = {}, 0
		for _, list in info.Hits do
			for _, hit in list do
				hitIds[hit.Id] = true
				hits += 1
			end
		end
		local each = if hits > 0 then info.Total / hits else 0
		for _, enemy in H.Enemies(c) do
			if not hitIds[enemy.Id] then
				if each > 0 then
					H.Hurt(c, enemy, each, "Physical")
				end
				zeal(c, enemy, 1)
			end
		end
		return true
	end,
}

-- 못과 망치: 대상의 광신 {1}중첩당 피해 +{2}%
M.WallPilgrim_E_NailAndHammer = {
	BeforeHit = function(c: Card, info: any)
		info.Bonus += math.floor(zealOf(info.Target) / c.V(1)) * c.P(2)
	end,
}

--=== 희귀 ===--

-- 깊은 못: 못질 광신 +{1}
M.WallPilgrim_R_DeepNail = {
	Rules = {
		NailingZeal = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}


-- 낙인: 낙인 찍힌 적은 {1}턴 동안 받는 피해 +{2}%
M.WallPilgrim_R_Brand = {
	Branded = function(c: Card, info: any)
		H.ModOn(c, info.Target, "DamageTaken", c.P(2), c.V(1))
		return true
	end,
}

-- 본보기: 못 자국 패시브가 읽는다(낙인 찍힌 적 → 광신이 가장 높은 적 + {1})
M.WallPilgrim_R_MadeExample = {
	Kill = function(_c: Card)
		return false
	end,
}

-- 설교: 합창이 위아래 줄의 적에게도 광신 {1}
M.WallPilgrim_R_Sermon = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Chorale") then
			return false
		end
		local mine = H.Cell(c)
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if mine and cell and math.abs(cell.Y - mine.Y) == 1 then
				zeal(c, enemy, c.V(1))
				count += 1
			end
		end
		return count > 0
	end,
}

-- 전염: 매 턴 광신이 가장 많은 적 하나가 붙어 선 적(칸 거리 1)에게 {1}중첩을 옮긴다
M.WallPilgrim_R_Contagion = {
	TurnStart = function(c: Card)
		local source, best = nil, 0
		for _, enemy in H.Enemies(c) do
			if zealOf(enemy) > best then
				source, best = enemy, zealOf(enemy)
			end
		end
		local from = source and H.Cell(c, source)
		if not from then
			return false
		end
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if enemy ~= source and cell and math.abs(cell.X - from.X) + math.abs(cell.Y - from.Y) == 1 then
				zeal(c, enemy, c.V(1))
				return true
			end
		end
		return false
	end,
}

-- 순례 지팡이: 전투 시작 시 신앙심 +{1}
M.WallPilgrim_R_PilgrimStaff = {
	BattleStart = function(c: Card)
		addFaith(c, c.V(1))
	end,
}


-- 성무일도: 신앙심 {1} 이상이면 낙인을 두 적에게, 지속 +{2}턴
M.WallPilgrim_R_DivineOffice = {
	Rules = {
		BrandCount = function(c: Card, value: number): number
			return if (H.Ally(c).Faith or 0) >= c.V(1) then math.max(value, 2) else value
		end,
		BrandTurns = function(c: Card, value: number): number
			return if (H.Ally(c).Faith or 0) >= c.V(1) then value + c.V(2) else value
		end,
	},
}

-- 고행: 턴당 {1}회, 맞으면 가장 가까운 적에게 광신 {2}, 신앙심 +{3}
M.WallPilgrim_R_Penance = {
	Taken = function(c: Card)
		if not H.PerTurn(c, "penance", c.V(1)) then
			return false
		end
		zeal(c, nearestEnemy(c), c.V(2))
		addFaith(c, c.V(3))
		return true
	end,
}

--=== 일반 ===--

-- 고착: 광신 지속 +{1}턴
M.WallPilgrim_C_Setting = {
	Rules = {
		ZealTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 못 자국 넓히기: 옮기는 중첩 +{1}
M.WallPilgrim_C_NailHole = {
	Rules = {
		NailMarkBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 첫 못: 전투 시작 시 가장 가까운 적에게 광신 {1}
M.WallPilgrim_C_FirstNail = {
	BattleStart = function(c: Card)
		zeal(c, nearestEnemy(c), c.V(1))
	end,
}

-- 묵상: 공격하지 않고 턴을 마치면 신앙심 +{1}
M.WallPilgrim_C_Meditation = {
	TurnEnd = function(c: Card, info: any)
		if not info.Attacked then
			addFaith(c, c.V(1))
			return true
		end
		return false
	end,
}


-- 쪼갬: 갈라진 신도가 위아래 줄 맨 앞 적에게도 {1}% 피해와 광신
M.WallPilgrim_C_Cleave = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "SplitFlock") then
			return false
		end
		local mine = H.Cell(c)
		if not mine then
			return false
		end
		local hits = 0
		for _, list in info.Hits do
			hits += #list
		end
		local each = if hits > 0 then info.Total / hits else 0
		local count = 0
		for _, dy in { -1, 1 } do
			local front, frontX = nil, math.huge
			for _, enemy in H.Enemies(c) do
				local cell = H.Cell(c, enemy)
				if cell and cell.Y == mine.Y + dy and cell.X < frontX then
					front, frontX = enemy, cell.X
				end
			end
			if front then
				if each > 0 then
					H.Hurt(c, front, each * c.P(1), "Physical")
				end
				zeal(c, front, 1 + math.floor(Q(c.Rt, "SplitFlockZeal", 0)))
				count += 1
			end
		end
		return count > 0
	end,
}

-- 녹슨 못: 광신 걸린 적이 주는 피해 −{1}% 더
M.WallPilgrim_C_RustyNail = {
	BeforeTaken = function(c: Card, info: any)
		if zealOf(info.Attacker) > 0 then
			info.Mult *= 1 - c.P(1)
			return true
		end
		return false
	end,
}

-- 회중: 광신 걸린 적이 셋 이상이면 주는 피해 +{1}%
M.WallPilgrim_C_Congregation = {
	BeforeSkill = function(c: Card, info: any)
		local count = 0
		for _, enemy in H.Enemies(c) do
			if zealOf(enemy) > 0 then
				count += 1
			end
		end
		if count >= 3 then
			info.Bonus += c.P(1)
			return true
		end
		return false
	end,
}

-- 성가: 합창을 쓰면 신앙심 +{1}
M.WallPilgrim_C_Hymn = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Chorale") then
			addFaith(c, c.V(1))
		end
	end,
}


-- 출혈 못: 광신을 걸 때 출혈 {1}도
M.WallPilgrim_C_BleedNail = {
	Status = function(c: Card, info: any)
		if info.Kind == "Zeal" and info.Target.Alive then
			BattleStatus.AddBleed(info.Target.Status, c.V(1))
			return true
		end
		return false
	end,
}

-- 순교자: 광신 걸린 적을 처치하면 신앙심 +{1}
M.WallPilgrim_C_Martyr = {
	Kill = function(c: Card, info: any)
		if zealOf(info.Target) > 0 then
			addFaith(c, c.V(1))
			return true
		end
		return false
	end,
}


-- 메아리: 갈라진 신도 광신 +{1}
M.WallPilgrim_C_Echo = {
	Rules = {
		SplitFlockZeal = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 적선: 처치하면 신앙심 +{1}
M.WallPilgrim_C_Alms = {
	Kill = function(c: Card)
		addFaith(c, c.V(1))
	end,
}

-- 긴 팔: 못질이 같은 줄 {1}칸 뒤의 적도 맞힌다(같은 피해·광신)
M.WallPilgrim_C_LongArm = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Nailing") then
			return false
		end
		local main = info.Hits[1] and info.Hits[1][1]
		local center = main and c.Rt.LastCells and c.Rt.LastCells[main.Id]
		if not center then
			return false
		end
		local count = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if enemy.Id ~= main.Id and cell and cell.Y == center.Y and cell.X > center.X and cell.X <= center.X + c.V(1) then
				H.Hurt(c, enemy, main.Damage, "Physical")
				zeal(c, enemy, 2 + math.floor(Q(c.Rt, "NailingZeal", 0)))
				count += 1
			end
		end
		return count > 0
	end,
}

-- 짧은 기도: 합창 재사용 대기 −{1}턴
M.WallPilgrim_C_ShortPrayer = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Chorale") then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.Chorale = math.max(0, (cooldowns.Chorale or 0) - c.V(1))
		end
	end,
}

-- 못 갈기: 광신이 상한까지 찬 적에게 피해 +{1}%
M.WallPilgrim_C_Whetted = {
	BeforeHit = function(c: Card, info: any)
		if zealOf(info.Target) >= zealCap(c) then
			info.Bonus += c.P(1)
		end
	end,
}

-- 지목: 턴당 {1}회, 낙인 찍힌 적을 때리면 스테미나 +{2}
M.WallPilgrim_C_PointOut = {
	Hit = function(c: Card, info: any)
		if isBranded(info.Target) and H.PerTurn(c, "point", c.V(1)) then
			local ally = H.Ally(c)
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + c.V(2))
			return true
		end
		return false
	end,
}

-- 물려받은 못: 못 자국으로 광신이 옮겨갈 때 신앙심 +{1}
M.WallPilgrim_C_Inherited = {
	ZealMoved = function(c: Card)
		addFaith(c, c.V(1))
		return true
	end,
}

return M
end
