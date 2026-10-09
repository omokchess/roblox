--!strict
--[[
	월 메이슨 — 직업 키트·패시브·카드 34장의 전투 효과. (CardEffects 2판, 2026-09-28)

	키트(WallMason_Kit)
	  [벽]은 BattleSkillEffects.ApplyWall 한 곳에서 건다(질의 목록은 그 주석). 지속이 끝나면 스택을 비우고
	  `WallEnd` 훅({Unit, Stacks})을 쏜다. 체력이 바뀌면 벽을 다시 칠한다(근성 — 체력 조건).

	축(CardAxes): 판금(Plating, 벽을 두껍게) · 축조(Construct, 벽을 자주) · 인내(Endure, 오래 버티기) · 신앙(Faith)
	자리: 정 다듬기(근접)로 벽을 쌓고 뒷벽 허물기(원거리)로 터뜨린다 — 앞에서 버티다 뒤로 빠져 쏘는 리듬.
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

local function wallOf(unit: any): number
	return BattleStatus.Stack(unit.Status, R.WALL)
end

local function query(c: Card): (string, number) -> number
	return function(key: string, base: number): number
		return Q(c.Rt, key, base)
	end
end

-- 카드가 벽을 준다(스킬과 같은 규칙). refresh=false 면 남은 지속 그대로 중첩만
local function wall(c: Card, unit: any, stacks: number, refresh: boolean?)
	if not unit or not unit.Alive or stacks <= 0 then
		return
	end
	BattleSkillEffects.ApplyWall(unit.Status, stacks, H.Ally(c).Faith or 0, query(c), refresh ~= false)
end

local function repaint(c: Card)
	for _, ally in H.Allies(c) do
		if wallOf(ally) > 0 then
			BattleSkillEffects.RefreshWall(ally.Status, H.Ally(c).Faith or 0, query(c))
		end
	end
end

local function addFaith(c: Card, amount: number)
	local ally = H.Ally(c)
	ally.Faith = (ally.Faith or 0) + math.floor(amount)
	repaint(c)
end

local M: { [string]: any } = {}

--=== 키트 ===--

M.WallMason_Kit = {
	TurnStart = function(c: Card)
		for _, ally in H.Allies(c) do
			local stacks = wallOf(ally)
			if stacks > 0 then
				local alive = false
				for _, modifier in ally.Status.Modifiers do
					if modifier.Source == "벽" then
						alive = true
					end
				end
				if not alive then
					BattleStatus.SpendAll(ally.Status, R.WALL)
					CardEffects.Fire(c.Rt, "WallEnd", { Unit = ally, Stacks = stacks })
				end
			end
		end
	end,
	-- 근성처럼 체력에 따라 벽 효과가 바뀐다
	Damaged = repaint,
	Healed = repaint,
}

--=== 패시브 ===--

-- 순례길: 같은 행의 다른 월 필그림 아군 신앙심 +8 — 파티 전제.

-- 쌓기: 턴 끝에 [벽]이 있으면 자신의 벽 +1(돌 고르기 +). 지속은 새로 세지 않는다.
M.WallMason_Stacking = {
	TurnEnd = function(c: Card)
		local ally = H.Ally(c)
		if wallOf(ally) > 0 then
			wall(c, ally, 1 + math.floor(Q(c.Rt, "StackingBonus", 0)), false)
			return true
		end
		return false
	end,
}

-- 버팀목: [벽] 5 이상이면 치명타를 받지 않는다
M.WallMason_Brace = {
	BeforeTaken = function(c: Card, info: any)
		if wallOf(H.Ally(c)) >= 5 then
			info.Crit = 0
		end
	end,
}

--=== 필수 ===--

-- 대성당: 벽 상한 +{1}, 스택당 효과 {2}%
M.WallMason_E_Cathedral = {
	Rules = {
		WallCap = function(c: Card, value: number): number
			return value + c.V(1)
		end,
		WallScale = function(c: Card, value: number): number
			return value * c.P(2)
		end,
	},
}

-- 석공의 손: 벽이 공격 버프 — 스택당 피해 +{1}%, 치명 확률 +{2}%, 치명 피해 +{3}%
M.WallMason_E_MasonHand = {
	Rules = {
		WallOffense = function(_c: Card, _value: number): number
			return 1
		end,
		WallOffenseDealt = function(c: Card, _value: number): number
			return c.P(1)
		end,
		WallOffenseCrit = function(c: Card, _value: number): number
			return c.P(2)
		end,
		WallOffenseCritDamage = function(c: Card, _value: number): number
			return c.P(3)
		end,
	},
}

-- 초석: 축성이 한 아군(솔로면 자신)에게, 벽 +{1}, 주는 피해 +{2}%(3턴), 재사용 대기 {3}턴
M.WallMason_E_Cornerstone = {
	Rules = {
		ConsecrateSingle = function(_c: Card, _value: number): number
			return 1
		end,
		ConsecrateWall = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Consecrate") then
			H.Mod(c, "DamageDealt", c.P(2), 3)
			H.Ally(c).Cooldowns.Consecrate = c.V(3)
			return true
		end
		return false
	end,
}

-- 맞물린 돌(파티): 벽이 가장 많은 아군의 벽 스택을 가져온다. 대신 자동 회피·패링이 없다.
M.WallMason_E_InterlockedStone = {
	Party = true,
	Rules = {
		WallNoAuto = function(_c: Card, _value: number): number
			return 1
		end,
	},
	TurnStart = function(c: Card)
		local me = H.Ally(c)
		local best = wallOf(me)
		for _, ally in H.Allies(c) do
			best = math.max(best, wallOf(ally))
		end
		if best > wallOf(me) then
			wall(c, me, best - wallOf(me))
		end
	end,
}

--=== 희귀 ===--

-- 정 다듬기 숙련: 정 다듬기 벽 +{1}
M.WallMason_R_ChiselMastery = {
	Rules = {
		ChiselWall = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 완성된 벽: 벽 {1} 이상인 아군 주는 피해 +{2}%
M.WallMason_R_FinishedWall = {
	BeforeSkill = function(c: Card, info: any)
		if wallOf(H.Ally(c)) >= c.V(1) then
			info.Bonus += c.P(2)
			return true
		end
		return false
	end,
}

-- 회반죽: 벽이 사라질 때 그 아군이 최대 체력 {1}% 회복
M.WallMason_R_Mortar = {
	WallEnd = function(c: Card, info: any)
		c.Rt.Env.Heal(info.Unit, math.floor(info.Unit.MaxHealth * c.P(1)))
		return true
	end,
}

-- 채석장: 내가 처치하면 아군 전체 벽 {1}
M.WallMason_R_Quarry = {
	Kill = function(c: Card)
		for _, ally in H.Allies(c) do
			wall(c, ally, c.V(1))
		end
		return true
	end,
}

-- 축복: 전투 시작 시 신앙심 +{1}
M.WallMason_R_Blessing = {
	BattleStart = function(c: Card)
		addFaith(c, c.V(1))
	end,
}

-- 허물어진 틈(옛 후열 조준, Id 그대로): 뒷벽 허물기에 맞은 적 2턴 받는 피해 +{1}% — 다시 맞으면 갱신(겹치지 않음)
M.WallMason_R_BackRowAim = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "BreakBackWall") then
			return false
		end
		local seen = {}
		for _, list in info.Hits do
			for _, enemy in list do
				if not seen[enemy] then
					seen[enemy] = true
					BattleStatus.RemoveBySource(enemy.Status, "카드:" .. c.Id)
					H.ModOn(c, enemy, "DamageTaken", c.P(1), 2)
				end
			end
		end
		return next(seen) ~= nil
	end,
}

-- 버팀벽(2026-10-09 그로기 삭제로 변경): 벽이 있는 동안 방어에 실패해 맞는 피해 −{1}%
M.WallMason_R_Buttress = {
	BeforeTaken = function(c: Card, info: any)
		if info.Grade == "Fail" and wallOf(H.Ally(c)) > 0 then
			info.Mult *= 1 - c.P(1)
		end
	end,
}

-- 쐐기돌: 벽을 가진 아군 하나당 주는 피해 +{1}%, 최대 {2}%
M.WallMason_R_Keystone = {
	BeforeSkill = function(c: Card, info: any)
		local count = 0
		for _, ally in H.Allies(c) do
			if wallOf(ally) > 0 then
				count += 1
			end
		end
		if count > 0 then
			info.Bonus += math.min(count * c.P(1), c.P(2))
			return true
		end
		return false
	end,
}

-- 성별: 신앙심 {1} 이상이면 벽 지속이 갱신 대신 {2}턴씩 더해진다(굳히기와 함께면 그 값)
M.WallMason_R_Consecration = {
	Rules = {
		WallAdditive = function(c: Card, value: number): number
			if (H.Ally(c).Faith or 0) < c.V(1) then
				return value
			end
			local harden = CardEffects.Has(c.Rt, "WallMason_C_Harden")
			return math.max(value, if harden then harden.V(2) else c.V(2))
		end,
	},
}

-- 재적층: 턴당 {1}회, 벽이 끝나 사라지면 그 아군이 사라진 벽의 {2}%(최소 {3})를 돌려받는다
M.WallMason_R_Relayer = {
	WallEnd = function(c: Card, info: any)
		if not H.PerTurn(c, "relayer", c.V(1)) then
			return false
		end
		wall(c, info.Unit, math.max(c.V(3), math.floor(info.Stacks * c.P(2))))
		return true
	end,
}

--=== 일반 ===--

-- 굳히기: 벽 지속 +{1}턴 (성별과 함께면 더해지는 값 {2})
M.WallMason_C_Harden = {
	Rules = {
		WallTurns = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 고른 숨: 벽 {1}스택당 턴 끝 스테미나 +{2}
M.WallMason_C_EvenBreath = {
	TurnEnd = function(c: Card)
		local ally = H.Ally(c)
		local gain = math.floor(wallOf(ally) / c.V(1)) * c.V(2)
		if gain > 0 then
			ally.Stamina = math.min(ally.MaxStamina, ally.Stamina + gain)
			return true
		end
		return false
	end,
}

-- 석공의 기도: 명상으로 턴을 마치면 신앙심 +{1}
M.WallMason_C_MasonPrayer = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Meditate") then
			addFaith(c, c.V(1))
			return true
		end
		return false
	end,
}

-- 같은 돌(파티): 같은 행 월 필그림 아군에게 주는 신앙심 +{1}
M.WallMason_C_SameStone = {
	Party = true,
}

-- 터 다지기: 전투 시작 시 아군 전체 벽 {1}
M.WallMason_C_Groundwork = {
	BattleStart = function(c: Card)
		for _, ally in H.Allies(c) do
			wall(c, ally, c.V(1))
		end
	end,
}

-- 자기 방벽: 턴 시작 시 벽 {1}
M.WallMason_C_SelfBulwark = {
	TurnStart = function(c: Card)
		wall(c, H.Ally(c), c.V(1))
	end,
}

-- 쐐기 박기: 정 다듬기의 벽이 체력이 가장 낮은 아군에게 — 자신이면 {1} 더
M.WallMason_C_DriveWedge = {
	Rules = {
		ChiselToLowest = function(_c: Card, _value: number): number
			return 1
		end,
		ChiselSelfBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 덧대기: 턴당 {1}회, 이미 벽이 있는 아군에게 벽을 주면 {2} 더 (스킬로 줄 때)
M.WallMason_C_Overlay = {
	BeforeSkill = function(c: Card)
		c.Mem.had = wallOf(H.Ally(c)) > 0
	end,
	Gain = function(c: Card, id: string)
		if id == R.WALL and c.Mem.had and H.PerTurn(c, "overlay", c.V(1)) then
			c.Mem.had = false
			wall(c, H.Ally(c), c.V(2))
			return true
		end
		return false
	end,
}

-- 근성: 체력 {1}% 미만이면 벽 효과 +{2}%
M.WallMason_C_Grit = {
	Rules = {
		WallScale = function(c: Card, value: number): number
			return if H.HealthRatio(c) < c.P(1) then value * (1 + c.P(2)) else value
		end,
	},
}

-- 석공의 맹세: 신앙심 {1}당 주는 피해 +{2}%, 최대 {3}%
M.WallMason_C_MasonOath = {
	BeforeSkill = function(c: Card, info: any)
		local bonus = math.min(math.floor((H.Ally(c).Faith or 0) / c.V(1)) * c.P(2), c.P(3))
		if bonus > 0 then
			info.Bonus += bonus
			return true
		end
		return false
	end,
}

-- 빠른 축성: 축성 재사용 대기 −{1}턴
M.WallMason_C_QuickRite = {
	AfterSkill = function(c: Card, info: any)
		if isSkill(info, "Consecrate") then
			local cooldowns = H.Ally(c).Cooldowns
			cooldowns.Consecrate = math.max(0, (cooldowns.Consecrate or 0) - c.V(1))
		end
	end,
}

-- 빗겨내기: 벽이 있는 아군 자동 회피·패링 +{1}%
M.WallMason_C_Deflect = {
	Rules = {
		WallAutoBonus = function(c: Card, value: number): number
			return value + c.P(1)
		end,
	},
}

-- 돌 고르기: 쌓기 패시브 +{1}
M.WallMason_C_StonePicking = {
	Rules = {
		StackingBonus = function(c: Card, value: number): number
			return value + c.V(1)
		end,
	},
}

-- 긴 정: 뒷벽 허물기가 위아래 줄 맨 앞 적에게도 {1}% 피해
M.WallMason_C_LongChisel = {
	AfterSkill = function(c: Card, info: any)
		if not isSkill(info, "BreakBackWall") then
			return false
		end
		local mine = H.Cell(c)
		local hits = 0
		for _, list in info.Hits do
			hits += #list
		end
		if not mine or hits == 0 then
			return false
		end
		local each = info.Total / hits
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
				H.Hurt(c, front, each * c.P(1), "Physical")
				count += 1
			end
		end
		return count > 0
	end,
}

-- 밑돌: 전투 시작 시 아군 전체 보호막 {1}
M.WallMason_C_Footstone = {
	BattleStart = function(c: Card)
		for _, ally in H.Allies(c) do
			BattleStatus.AddShield(ally.Status, c.V(1))
		end
	end,
}

-- 운 좋은 정: 뒷벽 허물기 치명 확률 +{1}%
M.WallMason_C_LuckyChisel = {
	BeforeSkill = function(c: Card, info: any)
		if isSkill(info, "BreakBackWall") then
			info.Crit += c.P(1)
		end
	end,
}

-- 나눔(파티): 턴당 {1}회, 자신이 벽을 얻으면 인접한 아군도 {2}
M.WallMason_C_Sharing = {
	Party = true,
}

-- 완충: 벽이 있는 아군이 받는 치명 피해 −{1}%
M.WallMason_C_Cushion = {
	BeforeTaken = function(c: Card, info: any)
		if wallOf(H.Ally(c)) > 0 then
			info.CritMult = 1 + (info.CritMult - 1) * (1 - c.P(1))
		end
	end,
}

-- 헌석: 처치하면 신앙심 +{1}
M.WallMason_C_StoneOffering = {
	Kill = function(c: Card)
		addFaith(c, c.V(1))
	end,
}

-- 쉬지 않는 축조: 매 턴 벽 {1}
M.WallMason_C_Tireless = {
	TurnStart = function(c: Card)
		wall(c, H.Ally(c), c.V(1))
	end,
}

return M
end
