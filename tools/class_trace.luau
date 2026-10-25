--[[
	class_trace.luau — 2026-10-25. 한 직업으로 짧은 전투를 돌려 턴마다 스킬·체력·자원·로그를 찍는다(조건부 직업 점검용).
	  lune run tools/class_trace.luau <직업> [턴] [적 체력 배율] [카드Id:레벨 ...]
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
loadShared("AbilityCards/init").Register()

local classId = process.args[1] or "Attuner"
local turns = tonumber(process.args[2]) or 8
local scale = tonumber(process.args[3]) or 20
local cards = {}
for index = 4, #process.args do
	local id, level = string.match(process.args[index], "([^:]+):?(%d*)")
	table.insert(cards, { CardId = id, Level = tonumber(level) or 6 })
end

local state = GridBattle.New(1, "trace", 400, 14, classId, 20, nil, cards, {
	Name = "trace",
	Enemies = { "Slime", "Slime", "Slime" },
	HealthScale = scale,
	PowerScale = 1.5,
	Cells = { { 1, 2 }, { 2, 2 }, { 1, 1 } },
}, { Strength = 5, Intellect = 5, Agility = 5, Vitality = 5, Luck = 5, Faith = 20 })
local seed = 12345
local function rng()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local shown = 0
local function flush()
	for index = shown + 1, #state.Log do
		print("    " .. state.Log[index])
	end
	shown = #state.Log
end
flush()
for turn = 1, turns do
	if state.Outcome ~= "Ongoing" then
		break
	end
	local ally = GridBattle.Ally(state)
	-- 첫 적의 줄로(card_sim 과 같은 정책)
	local first = GridBattle.AliveEnemies(state)[1]
	local at = first and GridBattle.CellOf(state, first.Id)
	if at then
		GridBattle.MoveAlly(state, 1, at.Y)
	end
	local list = GridBattle.SkillList(state)
	local pick
	for index = #list, 1, -1 do
		local skill = list[index]
		if skill.Id ~= "Guard" and skill.Id ~= "Meditate" and (ally.Cooldowns[skill.Id] or 0) <= 0 and (ally.Stamina >= GridBattle.StaminaCost(state, skill) or skill.HealthForStamina) then
			pick = skill
			break
		end
	end
	pick = pick or list[#list]
	local hp = {}
	for _, enemy in GridBattle.AliveEnemies(state) do
		table.insert(hp, string.format("%s=%d", enemy.Id, enemy.Health))
	end
	local stacks = {}
	for id, n in ally.Status.Stacks do
		if n > 0 then
			table.insert(stacks, id .. "=" .. n)
		end
	end
	table.sort(stacks)
	print(string.format("T%d %s  HP %d  ST %d  [%s]  적 %s", turn, pick.Id, ally.Health, ally.Stamina, table.concat(stacks, ","), table.concat(hp, " ")))
	GridBattle.ResolveSkill(state, 1, "Success", rng, pick.Id)
	for _, enemy in GridBattle.PlannedThreats(state) do
		GridBattle.ResolveDodge(state, enemy.Id, "Partial")
	end
	GridBattle.EndTurn(state)
	GridBattle.EnemyPlan(state, rng)
	flush()
end
print("결과", state.Outcome)
