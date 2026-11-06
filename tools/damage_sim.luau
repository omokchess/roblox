--[[
	damage_sim.luau — 2026-11-02 피해 공식 개편 전·후 비교용. 직업마다 카드 없이 같은 정책으로 싸워 평균 피해·처치 턴·받은 피해를 잰다.
	  lune run tools/damage_sim.luau [직업Id]
	정책은 card_sim 의 default 와 같다(적 줄로 이동, 쓸 수 있는 가장 높은 번호 스킬, 회피 등급은 성공·부분·실패 돌림).
	  피해    적 셋(체력 20배, 안 죽음) 14턴 동안 깎은 체력 합 → 턴당 평균
	  처치    적 셋(체력 1.5배) 을 다 잡을 때까지 턴 수(30턴 안에 못 잡으면 99)
	  받은    위 "피해" 싸움에서 내가 잃은 체력(적 치명타 포함)
	무기 공격력은 직업 기본 무기(BasicPower), 스탯은 모두 5(신앙심 20) — 실제 육성 초반 값.
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")

local GridBattle = loadShared("GridBattle")
local CharacterDefinitions = loadShared("CharacterDefinitions")
loadShared("AbilityCards/init").Register()

local GRADES = { "Success", "Partial", "Fail" }

local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- 직업마다 "할 일이 있는" 스킬 순서(card_sim PREFER 와 같다)
local PREFER = {
	Alchemist = function(stack): { string }
		local bottles = stack("PoisonBottle") + stack("FireBottle") + stack("OilBottle")
		if bottles >= 3 then
			return { "Poisoning", "Throw", "Grind" }
		elseif bottles > 0 then
			return { "Throw", "Mix", "Grind" }
		elseif stack("Extract") > 0 and stack("EmptyBottle") > 0 then
			return { "Mix", "Grind" }
		end
		return { "Grind" }
	end,
	AzureBlade = function(stack): { string }
		if stack("Concentration") > 0 then
			return { "SpaceCut", "FocusCut", "TrueIaido" }
		end
		return { "Provoke", "IaidoPeak", "TrueIaido", "ScabbardStrike" }
	end,
	WallBreaker = function(stack): { string }
		if stack("Ruin") >= 3 then
			return { "TearDown", "BringDown", "Cleave" }
		end
		return { "SelfCarve", "BringDown", "Cleave" }
	end,
}

local function fight(classId: string, kill: boolean, turns: number): (number, number, number)
	local encounter = {
		Name = "sim",
		Enemies = { "Slime", "Slime", "Slime" },
		HealthScale = if kill then (if classId == "Attuner" then 4 else 1.5) elseif classId == "Attuner" then 250 else 20,
		PowerScale = 1.5,
		Cells = { { 1, 2 }, { 2, 2 }, { 1, 1 } },
	}
	local stats = { Strength = 5, Intellect = 5, Agility = 5, Vitality = 5, Luck = 5, Faith = 20 }
	local power = CharacterDefinitions.Get(classId).BasicPower
	local state = GridBattle.New(1, "sim", 400, power, classId, stats.Faith, nil, {}, encounter, stats)
	if classId == "Attuner" then
		-- card_sim 과 같게: 화상은 최대 체력 비례라 보스처럼 화염 저항 90%
		for _, enemy in GridBattle.AliveEnemies(state) do
			enemy.Resist = { Fire = 0.9 }
		end
		state.Debug = { AutoDodge = true }
	end
	local startHp = 0
	for _, unit in state.Units do
		if unit.Side == "Enemy" then
			startHp += unit.Health
		end
	end
	local rng = lcg(12345)
	local used = 0
	for turn = 1, turns do
		if state.Outcome ~= "Ongoing" then
			break
		end
		used = turn
		local target = GridBattle.AliveEnemies(state)[1]
		local cell = target and GridBattle.CellOf(state, target.Id)
		if cell then
			GridBattle.MoveAlly(state, if turn % 3 == 1 then 5 else 1, cell.Y)
		end
		local list = GridBattle.SkillList(state)
		local ally = GridBattle.Ally(state)
		local chosen = nil
		for index = #list, 1, -1 do
			local skill = list[index]
			local cost = GridBattle.StaminaCost(state, skill)
			if skill.Id ~= "Guard" and skill.Id ~= "Meditate" and (ally.Cooldowns[skill.Id] or 0) <= 0 and (ally.Stamina >= cost or skill.HealthForStamina) then
				chosen = index
				break
			end
		end
		local prefer = PREFER[classId]
		if prefer then
			local stack = function(id: string): number
				return ally.Status.Stacks[id] or 0
			end
			for _, want in prefer(stack) do
				local found = nil
				for index, skill in list do
					if skill.Id == want and (ally.Cooldowns[skill.Id] or 0) <= 0 and (ally.Stamina >= GridBattle.StaminaCost(state, skill) or skill.HealthForStamina) then
						found = index
					end
				end
				if found then
					chosen = found
					break
				end
			end
		end
		if not chosen then
			for index, skill in list do
				if skill.Id == (if ally.Stamina < 20 then "Meditate" else "Guard") then
					chosen = index
				end
			end
		end
		GridBattle.ResolveSkill(state, chosen, "Success", rng, list[chosen].Id)
		if state.Outcome ~= "Ongoing" then
			break
		end
		for _, enemy in GridBattle.PlannedThreats(state) do
			GridBattle.ResolveDodge(state, enemy.Id, GRADES[turn % 3 + 1] :: any)
		end
		GridBattle.EndTurn(state)
		GridBattle.EnemyPlan(state, rng)
	end
	local endHp = 0
	for _, unit in state.Units do
		if unit.Side == "Enemy" then
			endHp += unit.Health
		end
	end
	local ally = GridBattle.Ally(state)
	return startHp - endHp, if state.Outcome == "Ongoing" then 99 else used, ally.MaxHealth - ally.Health
end

local classes = { "Duelist", "Musician", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker", "Attuner", "AzureBlade" }
local only = process.args[1]
print(string.format("%-12s %5s %10s %8s %8s", "직업", "무기", "턴당피해", "처치턴", "받은피해"))
for _, classId in classes do
	if only and only ~= classId then
		continue
	end
	local dealt, _, taken = fight(classId, false, 14)
	local _, killTurns, _ = fight(classId, true, 30)
	print(string.format("%-12s %5d %10.1f %8s %8d", classId, CharacterDefinitions.Get(classId).BasicPower, dealt / 14, tostring(killTurns), taken))
end
