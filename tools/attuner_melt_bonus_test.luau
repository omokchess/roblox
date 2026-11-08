--[[
	attuner_melt_bonus_test.luau — 2026-11-08 조율자 깡딜러: 대상 [융해] 비례 피해 증가(+15%/스택, 최대 +300%)가 실제 피해에 들어가는지 본다.
	  lune run tools/attuner_melt_bonus_test.luau
	메그레즈를 대상 융해 0 · 3 · 19(스킬이 1 더 얹어 20) · 29(상한 넘김)에서 쏴 피해 비를 보고, 알리오스(판 전체)는 대상마다 다른 융해로 쏴 대상별로 다르게 들어가는지 본다.
]]
local loadShared = require("./lune_env")

local GridBattle = loadShared("GridBattle")
local BattleStatus = loadShared("BattleStatus")
local BattleSkillEffects = loadShared("BattleSkillEffects")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local function noCrit(): number
	return 0.99
end

local PER, CAP = BattleSkillEffects.MELT_DAMAGE_PER_STACK, BattleSkillEffects.MELT_DAMAGE_CAP
check(math.abs(BattleSkillEffects.MeltBonus(0)) < 1e-9, "융해 0 → 보너스 0")
check(math.abs(BattleSkillEffects.MeltBonus(3) - 3 * PER) < 1e-9, "융해 3 → 3×" .. PER)
check(math.abs(BattleSkillEffects.MeltBonus(20) - CAP) < 1e-9 and math.abs(BattleSkillEffects.MeltBonus(99) - CAP) < 1e-9, "상한 " .. CAP)

local function fresh(cells: { { number } }): any
	return GridBattle.NewParty(1, {
		{ ClassId = "Attuner", X = 3, Y = 2, Cards = {}, Name = "Attuner", Health = 5000, Power = 10, Stamina = 999 },
	}, { Name = "시험", Enemies = table.create(#cells, "Slime"), Cells = cells, HealthScale = 1000, PowerScale = 1 })
end

-- 메그레즈 한 방이 대상에게 준 피해. 대상에 미리 melt 를 얹어 둔다(스킬이 1 더 얹는다)
local function megrez(preMelt: number): number
	local state = fresh({ { 1, 2 } })
	local enemy = GridBattle.AliveEnemies(state)[1]
	BattleStatus.AddStack(enemy.Status, ClassResources.MELT, preMelt, 99)
	local before = enemy.Health
	GridBattle.SetUnitSkill(state, "player", "Megrez")
	GridBattle.BeginTurn(state)
	GridBattle.ResolveUnitSkill(state, GridBattle.NextActor(state) :: string, noCrit)
	return before - enemy.Health
end

local d0 = megrez(0) -- 스킬이 1 얹어 +15%
local d3 = megrez(3) -- 4 → +60%
local d19 = megrez(19) -- 20 → +300%
local d29 = megrez(29) -- 30 → 상한 +300%
print("메그레즈 피해: 융해 0=" .. d0 .. " · 3=" .. d3 .. " · 19=" .. d19 .. " · 29=" .. d29)
check(d0 > 0, "피해가 들어간다")
check(math.abs(d3 / d0 - (1 + 4 * PER) / (1 + PER)) < 0.08, "융해 3 → 4 스택 비율 " .. d3 / d0)
check(math.abs(d19 / d0 - (1 + CAP) / (1 + PER)) < 0.08, "융해 20 → 상한 비율 " .. d19 / d0)
check(d29 == d19, "상한을 넘으면 더 세지지 않는다")

-- 알리오스(판 전체): 대상마다 자기 융해로
do
	local state = fresh({ { 1, 2 }, { 2, 2 } })
	local list = GridBattle.AliveEnemies(state)
	local a, b = list[1], list[2]
	BattleStatus.AddStack(b.Status, ClassResources.MELT, 10, 99)
	local ha, hb = a.Health, b.Health
	GridBattle.SetUnitSkill(state, "player", "Alioth")
	GridBattle.BeginTurn(state)
	GridBattle.ResolveUnitSkill(state, GridBattle.NextActor(state) :: string, noCrit)
	local da, db = ha - a.Health, hb - b.Health
	print("알리오스: 융해 0 대상=" .. da .. " · 융해 10 대상=" .. db)
	check(da > 0 and db > da, "융해가 더 많은 대상이 더 많이 맞는다")
	check(math.abs(db / da - (1 + 15 * PER) / (1 + 5 * PER)) < 0.08, "알리오스 대상별 비율 " .. db / da)
end
print("attuner_melt_bonus_test OK")
