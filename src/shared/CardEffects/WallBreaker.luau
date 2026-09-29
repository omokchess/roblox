--!strict
--[[
	월 브레이커 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(WallBreaker_Kit)
	  [허물 벽] 중첩이 바뀔 때마다 보정값을 다시 건다(BattleSkillEffects.RefreshRuin).
	  제 살 깎기(강화 버튼, 늘 열림)로 자신을 쳐서 허물 벽을 얻고, 허물다로 전부 터뜨린다.

	축(CardAxes): 선봉(Vanguard, 허물다·쪼개기) · 희생(Sacrifice, 제 살 깎기) · 벼랑(Brink, 낮은 체력) · 신앙(Faith)
	자리: 전부 근접 — 앞에서 스스로를 깎아 세지는 광전사형. 밀어내기로 적을 끝 열에 몰아 고정 피해.
]]

local BattleGrid = require(script.Parent.Parent.BattleGrid)
local BattleSkillEffects = require(script.Parent.Parent.BattleSkillEffects)
local ClassResources = require(script.Parent.Parent.ClassResources)

local R = ClassResources

type Card = any

return function(CardEffects: any): { [string]: any }
local H = CardEffects.H
local Q = CardEffects.Query

local function isSkill(info: any, id: string): boolean
	return info.Skill ~= nil and info.Skill.Id == id
end

local function ruin(c: Card): number
	return H.Stack(c, R.RUIN)
end

local function query(c: Card): (string, number) -> number
	return function(key: string, base: number): number
		return Q(c.Rt, key, base)
	end
end

local function gainRuin(c: Card, amount: number): number
	if amount <= 0 then
		return 0
	end
	local got = H.Gain(c, R.RUIN, amount + math.floor(Q(c.Rt, "RuinGainFlat", 0)))
	BattleSkillEffects.RefreshRuin(H.Status(c), query(c))
	return got
end

local function addFaith(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Faith = (ally.Faith or 0) + math.floor(amount)
end

local function hitIds(info: any): ({ [string]: boolean }, number)
	local ids, count = {}, 0
	for _, list in info.Hits do
		for _, hit in list do
			ids[hit.Id] = true
			count += 1
		end
	end
	return ids, count
end

local M: { [string]: any } = {}

--=== 키트 ===--

local function refresh(c: Card)
	BattleSkillEffects.RefreshRuin(H.Status(c), query(c))
end

M.WallBreaker_Kit = {
	BattleStart = refresh,
	Gain = function(c: Card, id: string)
		if id == R.RUIN then
			refresh(c)
		end
	end,
	Spend = function(c: Card, id: string)
		if id == R.RUIN then
			refresh(c)
		end
	end,
	-- 허물다 직전의 허물 벽(잔해·섭취·뒤처리가 본다)
	BeforeSkill = function(c: Card, info: any)
		c.Rt.RuinBefore = ruin(c)
		c.Rt.HpBefore = {}
		for _, target in info.Targets do
			c.Rt.HpBefore[target.Id] = target.Health
		end
	end,
}

--=== 패시브 ===--

-- 광적인 맹세: 잃은 체력 2%당 주는 피해 +1%(최대 48%, 광증 +). 체력 1% 이하면 대신 +50%.
local function madOath(c: Card)
	H.Clear(c)
	local ratio = H.HealthRatio(c)
	local cap = Q(c.Rt, "MadOathCap", 0.48)
	local bonus = if ratio <= 0.01 then math.max(0.5, cap) else math.min(cap, math.floor((1 - ratio) * 50 + 1e-6) * 0.01)
	if bonus > 0 then
		H.Mod(c, "DamageDealt", bonus, -1)
	end
end
M.WallBreaker_MadOath = {
	BattleStart = madOath,
	TurnStart = madOath,
	Damaged = madOath,
	Healed = madOath,
}

-- 순례길: 파티 전제(같은 행 월 필그림 아군 신앙심 +8).

-- 잔해: 허물 벽을 쓴 스킬(허물다)로 적을 처치하면 쓴 양의 50%(더 많은 잔해 → 그 값)를 돌려받는다
M.WallBreaker_Debris = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "TearDown") or info.Kills <= 0 then
			return false
		end
		local spent = (c.Rt.RuinBefore or 0) - ruin(c)
		local back = math.floor(spent * Q(c.Rt, "DebrisRatio", 0.5))
		if back > 0 then
			gainRuin(c, back)
			H.Log(c, string.format("잔해 — 허물 벽 %d 회수", back))
			return true
		end
		return false
	end,
}

--=== 필수 ===--

-- 무너진 성벽: 허물 벽 상한 +{1}, 중첩당 받는 피해 +{2}%
M.WallBreaker_E_BrokenRampart = {
	Rules = {
		RuinCap = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		RuinTakenPer = function(c: Card, value: number): number
			return value - 0.03 + c.P(2)
		end,
	},
}

-- 자해: 제 살 깎기가 허물 벽 {1}, 자해 피해 −{2}%
M.WallBreaker_E_SelfHarm = {
	Rules = {
		SelfCarveRuin = function(c: Card, value: number): number
			return value - 3 + c.V(1)
		end,
		SelfCarveHarm = function(c: Card, value: number): number
			return value * (1 - c.P(2))
		end,
	},
}

-- 순교(파티): 쓰러진 아군마다 소모되지 않는 허물 벽(최대 {1}), 전투 동안 주는 피해 +{2}%
M.WallBreaker_E_Martyrdom = {
	Party = true,
}

-- 평탄화: 허물다가 적 전체, 중첩당 {1}%
M.WallBreaker_E_Levelling = {
	Rules = {
		TearDownPerStack = function(c: Card, _value: number): number
			return c.P(1)
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "TearDown") then
			return false
		end
		local ids, count = hitIds(info)
		local each = if count > 0 then info.Total / count else 0
		if each <= 0 then
			return false
		end
		local extra = 0
		for _, enemy in H.Enemies(c) do
			if not ids[enemy.Id] then
				H.Hurt(c, enemy, each, "Physical")
				extra += 1
			end
		end
		return extra > 0
	end,
}

--=== 희귀 ===--

-- 동정: 제 살 깎기 피해가 최대 체력의 {1}%
M.WallBreaker_R_SoftBlow = {
	Rules = {
		SelfCarveRatio = function(c: Card, value: number): number
			return math.min(value, c.P(1))
		end,
	},
}

-- 잔해 회수: 허물다로 처치할 때마다 허물 벽 {1}
M.WallBreaker_R_Salvage = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TearDown") and info.Kills > 0 then
			gainRuin(c, info.Kills * c.V(1))
			return true
		end
		return false
	end,
}

-- 광증: 광적인 맹세 상한 {1}%
M.WallBreaker_R_Madness = {
	Rules = {
		MadOathCap = function(c: Card, value: number): number
			return math.max(value, c.P(1))
		end,
	},
}

-- 섭취: 허물다로 준 피해의 {1}% 회복
M.WallBreaker_R_Swallow = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TearDown") and info.Total > 0 then
			H.HealFlat(c, info.Total * c.P(1))
			return true
		end
		return false
	end,
}

-- 앙갚음: 제 살 깎기에 맞은 아군은 전투 동안 주는 피해 +{1}% (한 번)
M.WallBreaker_R_PaidBack = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "SelfCarve") and not c.Mem.done then
			c.Mem.done = true
			H.Mod(c, "DamageDealt", c.P(1), -1)
			return true
		end
		return false
	end,
}

-- 성유물: 매 턴 신앙심 +{1}
M.WallBreaker_R_Reliquary = {
	TurnStart = function(c: Card)
		addFaith(c, c.V(1))
	end,
}

-- 뒤처리: 허물다로 넘친 피해의 {1}%를 다음 스킬(첫 타)에 더한다
M.WallBreaker_R_Overkill = {
	Hit = function(c: Card, info: any)
		if c.Mem.ready and c.Mem.ready > 0 and info.Target.Alive and not isSkill(info, "TearDown") then
			local extra = c.Mem.ready
			c.Mem.ready = 0
			H.Hurt(c, info.Target, extra, "Physical")
			H.Log(c, string.format("남은 힘 +%d", extra))
		end
		if isSkill(info, "TearDown") and not info.Target.Alive then
			local before = c.Rt.HpBefore and c.Rt.HpBefore[info.Target.Id] or 0
			if info.Damage > before then
				c.Mem.carry = (c.Mem.carry or 0) + (info.Damage - before) * c.P(1)
			end
		end
	end,
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TearDown") and (c.Mem.carry or 0) >= 1 then
			c.Mem.ready = math.floor(c.Mem.carry)
		end
		c.Mem.carry = 0
	end,
}

-- 만가: 신앙심 {1} 이상이면 허물다가 허물 벽을 {2} 덜 쓴다(배율은 그대로)
M.WallBreaker_R_Dirge = {
	Rules = {
		TearDownKeep = function(c: Card, value: number): number
			return if (H.Ally(c).Faith or 0) >= c.V(1) then value + c.V(2) else value
		end,
	},
}

-- 연쇄 붕괴: 무너뜨리기로 {1}명 이상 맞히면 허물 벽 {2}
M.WallBreaker_R_ChainCollapse = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "BringDown") then
			return false
		end
		local _, count = hitIds(info)
		if count >= c.V(1) then
			gainRuin(c, c.V(2))
			return true
		end
		return false
	end,
}

-- 무딘 살: 허물 벽 중첩당 받는 피해 증가 −{1}%p
M.WallBreaker_R_DullFlesh = {
	Rules = {
		RuinTakenPer = function(c: Card, value: number): number
			return value - c.P(1)
		end,
	},
}

--=== 일반 ===--

-- 파편: 맞을 때 {1}% 확률로 허물 벽 1
M.WallBreaker_C_Shard = {
	Taken = function(c: Card)
		if H.Rng(c) < c.P(1) then
			gainRuin(c, 1)
			return true
		end
		return false
	end,
}

-- 악착: 체력 {1}% 이하면 허물 벽 획득 +{2}
M.WallBreaker_C_Tenacity = {
	Rules = {
		RuinGainFlat = function(c: Card, value: number): number
			return if H.HealthRatio(c) <= c.P(1) then value + c.V(2) else value
		end,
	},
}

-- 폐허의 기도: 공격하지 않고 턴을 마치면 신앙심 +{1}
M.WallBreaker_C_RuinPrayer = {
	TurnEnd = function(c: Card, info: any)
		if not info.Attacked then
			addFaith(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 자비(파티): 순례길 신앙심 +{1}
M.WallBreaker_C_SameStride = {
	Party = true,
}

-- 이미 새겨진 균열: 전투 시작 시 허물 벽 {1}
M.WallBreaker_C_FirstCrack = {
	BattleStart = function(c: Card)
		gainRuin(c, c.V(1))
	end,
}

-- 헐거운 벽돌: 쪼개기가 맞힐 때마다 허물 벽 {1} (턴당 {2}회)
M.WallBreaker_C_LooseBrick = {
	Hit = function(c: Card, info: any)
		if isSkill(info, "Cleave") and H.PerTurn(c, "brick", c.V(2)) then
			gainRuin(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 밀어내기: 스킬에 맞은 적을 한 칸 밀어낸다. 이미 끝 열이면 고정 피해 {1}
M.WallBreaker_C_ShoveOff = {
	Hit = function(c: Card, info: any)
		local target = info.Target
		local cell = target.Alive and H.Cell(c, target)
		if not cell then
			return false
		end
		local grid = H.State(c).Grid
		if cell.X >= grid.Width then
			H.Hurt(c, target, c.V(1), "True")
		else
			BattleGrid.Move(grid, target.Id, cell.X + 1, cell.Y)
		end
		return true
	end,
}

-- 살점 값: 제 살 깎기 허물 벽 +{1}, 허물 벽 상한 +{2}
M.WallBreaker_C_FleshPrice = {
	Rules = {
		SelfCarveRuin = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		RuinCap = function(c: Card, value: number): number
			return value + c.V(2)
		end,
	},
}

-- 파괴의 맹세: 신앙심 {1}당 주는 피해 +{2}%
M.WallBreaker_C_RuinOath = {
	BeforeSkill = function(c: Card, info: any)
		local bonus = math.floor((H.Ally(c).Faith or 0) / c.V(1)) * c.P(2)
		if bonus > 0 then
			info.Bonus += bonus
			return true
		end
		return false
	end,
}

-- 더 많은 잔해: 잔해 회수 비율 {2}%
M.WallBreaker_C_DebrisPlus = {
	Rules = {
		DebrisRatio = function(c: Card, value: number): number
			return math.max(value, c.P(2))
		end,
	},
}

-- 광적인 파괴: 허물 벽 {1} 이상이면 허물다 재사용 대기 −{2}턴
M.WallBreaker_C_ShortWindup = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "TearDown") and (c.Rt.RuinBefore or 0) >= c.V(1) then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.TearDown = math.max(0, (cooldowns.TearDown or 0) - c.V(2))
			return true
		end
		return false
	end,
}

-- 무방비: 패링·방어에 실패한 다음 턴에 주는 피해 +{1}%, 받는 피해 +{2}%
M.WallBreaker_C_Defenceless = {
	Defend = function(c: Card, info: any)
		if info.Grade == "Fail" then
			c.Mem.armed = true
		end
	end,
	TurnStart = function(c: Card)
		if c.Mem.armed then
			c.Mem.armed = false
			H.Mod(c, "DamageDealt", c.P(1), 1)
			H.Mod(c, "DamageTaken", c.P(2), 1)
			return true
		end
		return false
	end,
}

-- 약점 파괴: 허물 벽 {1}당 치명 확률 +{2}%
M.WallBreaker_C_WeakPoint = {
	BeforeSkill = function(c: Card, info: any)
		info.Crit += math.floor(ruin(c) / c.V(1)) * c.P(2)
	end,
}

-- 병 주고 약 주기: 제 살 깎기로 준 피해의 {1}% 회복
M.WallBreaker_C_Comrade = {
	AfterSkill = function(c: Card, info: any)
		local cost = H.Ally(c).LastSelfCarve or 0
		if isSkill(info, "SelfCarve") and cost > 0 then
			H.HealFlat(c, cost * c.P(1))
			return true
		end
		return false
	end,
}

-- 제물: 처치하면 신앙심 +{1}
M.WallBreaker_C_Oblation = {
	Kill = function(c: Card)
		addFaith(c, c.V(1))
	end,
}

-- 긴 자루: 허물 벽 {1} 이상이면 쪼개기가 한 칸 더 앞(같은 줄 뒤 칸의 적)까지
M.WallBreaker_C_LongHaft = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "Cleave") or (c.Rt.RuinBefore or 0) < c.V(1) then
			return false
		end
		local ids, count = hitIds(info)
		local mine = H.Cell(c)
		if count == 0 or not mine then
			return false
		end
		local each = info.Total / count
		local farX = 0
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if ids[enemy.Id] and cell then
				farX = math.max(farX, cell.X)
			end
		end
		for _, enemy in H.Enemies(c) do
			local cell = H.Cell(c, enemy)
			if not ids[enemy.Id] and cell and cell.Y == mine.Y and cell.X == farX + 1 then
				H.Hurt(c, enemy, each, "Physical")
				return true
			end
		end
		return false
	end,
}

-- 벼랑: 체력 {1}% 이하면 허물 벽 중첩당 주는 피해 +{2}%
M.WallBreaker_C_Cliff = {
	BeforeSkill = function(c: Card, info: any)
		if H.HealthRatio(c) <= c.P(1) then
			info.Bonus += ruin(c) * c.P(2)
			return true
		end
		return false
	end,
}

-- 무뎌진 죄책감: 허물 벽 {1} 이하면 제 살 깎기 재사용 대기 −{2}턴
M.WallBreaker_C_LightHand = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "SelfCarve") and (c.Rt.RuinBefore or 0) <= c.V(1) then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.SelfCarve = math.max(0, (cooldowns.SelfCarve or 0) - c.V(2))
			return true
		end
		return false
	end,
}

-- 최선의 교본: 제 살 깎기를 쓰면 아군 전체 신앙심 +{1} (전투당 {2}회)
M.WallBreaker_C_Tireless = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "SelfCarve") and H.PerBattle(c, "book", c.V(2)) then
			for _, ally in H.Allies(c) do
				ally.Faith = (ally.Faith or 0) + c.V(1)
			end
			return true
		end
		return false
	end,
}

-- 광인: 주는 피해 +{1}%, 받는 피해 +{2}%
M.WallBreaker_C_SharedLoad = {
	BattleStart = function(c: Card)
		H.Mod(c, "DamageDealt", c.P(1), -1)
		H.Mod(c, "DamageTaken", c.P(2), -1)
	end,
}

return M
end
