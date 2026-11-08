--[[
	attuner_party_sim.luau — 2026-11-08 조율자 깡딜러 밸런스. 파티로 싸우며 **유닛마다** 적에게 준 피해(체력 감소)를 잰다.
	  lune run tools/attuner_party_sim.luau [상대: slime|callisto] [턴수]
	시나리오 3개를 같은 규칙으로 돌려 비교한다 — 각 직업 단독 파티(카드 없음, 같은 행 y=2 앞열) 와 예시 '조율자 중심'.
	정책: 쓸 수 있는 가장 센 적 치는 기술(조율자는 칠성 7 이면 셉텐트리오네스 → 알리오스 → 메라크 → 메그레즈).
	피해 = 그 유닛의 행동 앞뒤 적 체력 합 차이(지속 피해·융해 폭발은 턴 끝 몫이라 "턴끝" 열로 따로).
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local PartyDefinitions = loadShared("PartyDefinitions")
loadShared("AbilityCards/init").Register()
local BattleSkillEffects = loadShared("BattleSkillEffects")

local args = process.args
local foe = args[1] or "slime"
local turns = tonumber(args[2]) or 12
local VERBOSE = args[3] == "v"
-- 시험용: 넷째 인자 = 융해 1당 피해 증가 배수(기술별 비율 5·10·15·20% 에 곱한다 — 2026-11-08 사용자 지정 비율)
if tonumber(args[4]) then
	local k = tonumber(args[4]) :: number
	for id, rate in BattleSkillEffects.MELT_DAMAGE_PER_STACK do
		BattleSkillEffects.MELT_DAMAGE_PER_STACK[id] = rate * k
	end
end

local function enemyHp(state: any): number
	local sum = 0
	for _, unit in state.Units do
		if unit.Side == "Enemy" and unit.Alive then
			sum += unit.Health
		end
	end
	return sum
end

local function run(label: string, members: { any })
	local seed = 7
	local function rng(): number
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local encounter = if foe == "callisto"
		then { Name = "sim", Enemies = { "Callisto" }, HealthScale = 1, PowerScale = 0.01 }
		else { Name = "sim", Enemies = { "Slime", "Slime", "Slime" }, HealthScale = 60, PowerScale = 0.01, Cells = { { 1, 2 }, { 2, 2 }, { 1, 1 } } }
	local state = GridBattle.NewParty(1, members, encounter, { SkipValidate = true })
	local perClass: { [string]: number } = {}
	local tail = 0
	local startHp = enemyHp(state)
	for _ = 1, turns do
		if state.Outcome ~= "Ongoing" then
			break
		end
		GridBattle.EnemyPlan(state, rng)
		for _, ally in GridBattle.Allies(state) do
			local list = GridBattle.UnitSkillList(state, ally.Id)
			local order = {}
			for index = #list, 1, -1 do
				table.insert(order, list[index].Id)
			end
			if ally.ClassId == "Attuner" then
				order = { "Septentriones", "Alioth", "Merak", "Megrez" }
			end
			for _, skillId in order do
				local damaging = false
				for _, skill in list do
					if skill.Id == skillId and skill.Damage > 0 and not skill.Shape.TargetSide then
						damaging = true
					end
				end
				if damaging and GridBattle.SetUnitSkill(state, ally.Id, skillId) then
					break
				end
			end
		end
		GridBattle.BeginTurn(state)
		for _ = 1, 12 do
			local actor = GridBattle.NextActor(state)
			if not actor then
				break
			end
			local class = (state.Units[actor] :: any).ClassId
			local before = enemyHp(state)
			local chosen = (state.Units[actor] :: any).Chosen
			local st = (state.Units[actor] :: any)
			if VERBOSE then
				print("   ", class, "chosen", chosen, "stam", st.Stamina, "star", st.Status.Stacks.Star, "cd", st.Cooldowns.Megrez, st.Cooldowns.Merak, st.Cooldowns.Alioth)
			end
			GridBattle.ResolveUnitSkill(state, actor, rng)
			perClass[class] = (perClass[class] or 0) + before - enemyHp(state)
			if VERBOSE then
				print(string.format("  %s %s -> %.1f", class, tostring(chosen), before - enemyHp(state)))
			end
		end
		if state.Outcome ~= "Ongoing" then
			break
		end
		GridBattle.ResolveEnemyPhase(state, rng)
		local before = enemyHp(state)
		GridBattle.EndTurn(state)
		tail += before - enemyHp(state)
	end
	local parts = {}
	for class, dmg in perClass do
		table.insert(parts, string.format("%s %.1f", class, dmg / turns))
	end
	table.sort(parts)
	print(string.format("%-28s 턴당 %s | 턴끝 %.1f | 적 체력 %.1f%% 감소", label, table.concat(parts, " · "), tail / turns, 100 * (startHp - enemyHp(state)) / startHp))
end

local function solo(classId: string): { any }
	return { { ClassId = classId, X = 3, Y = 2, Cards = {}, Name = classId, Health = 99999, Power = 15, Stamina = 999 } }
end

print("상대", foe, "턴", turns)
for _, classId in { "Attuner", "AzureBlade", "Berserker" } do
	run("단독 " .. classId, solo(classId))
end
local ex = PartyDefinitions.Examples()[3]
for _, preset in PartyDefinitions.Examples() do
	if preset.Name == "조율자 중심" then
		ex = preset
	end
end
local members = {}
for _, u in ex.Units do
	table.insert(members, { ClassId = u.ClassId, X = u.X, Y = u.Y, Cards = u.Cards, Name = u.ClassId, Health = 99999, Power = 15, Stamina = 999 })
end
run("예시 " .. ex.Name, members)
