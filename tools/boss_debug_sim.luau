--[[ boss_debug_sim.luau — 디버그 보스를 직업별로 자동 전투해 턴 수·남은 체력을 본다(밸런스 감). lune run tools/boss_debug_sim.luau ]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleGrid = loadShared("BattleGrid")
local CharacterDefinitions = loadShared("CharacterDefinitions")
loadShared("AbilityCards/init").Register()

local process = require("@lune/process")
VERBOSE = process.args[1] ~= nil
local only = process.args[1]
local seed = 11
local function rng(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

for _, classId in { "Musician", "Duelist", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" } do
	if only and only ~= classId then
		continue
	end
	local power = CharacterDefinitions.Get(classId).BasicPower
	local s = GridBattle.New(1, "시험", 60, power, classId, 5, nil, {}, { Name = "보스", Enemies = { "Debug" }, HealthScale = tonumber(process.env.HS or "0.012"), PowerScale = tonumber(process.env.PS or "0.15") })
	GridBattle.EnemyPlan(s, rng)
	local turns = 0
	while s.Outcome == "Ongoing" and turns < 60 do
		turns += 1
		local best
		for x = 1, 6 do
			for y = 1, 3 do
				if BattleGrid.IsEnabled(s.Grid, "Ally", x, y) then
					local was = BattleGrid.CellOf(s.Grid, "player")
					GridBattle.MoveAlly(s, x, y)
					local safe = #GridBattle.PlannedThreats(s) == 0
					local buff = s.Boss.Mods[BattleGrid.CellKey("Ally", x, y)] == "Buff"
					-- 검수 준비중(예고) 칸: 체력이 넉넉하면 검수(+400% → 검수중 → 테스터)를 노리고, 아니면 피한다
					local pending = false
					local arm = s.Units.boss_DeleteArm
					for _, c in (arm and arm.Alive and arm.Plan and arm.Plan.Cells) or {} do
						if c[1] == x and c[2] == y then
							pending = true
						end
					end
					local hpRatio = s.Units.player.Health / s.Units.player.MaxHealth
					local gamble = if not pending then 0 elseif hpRatio > 0.7 then 1.5 else -5
					local score = (if safe then 2 else 0) + (if buff then 1 else 0) + gamble + rng() * 0.5
					if not best or score > best[3] then
						best = { x, y, score }
					end
					if was then
						GridBattle.MoveAlly(s, was.X, was.Y)
					end
				end
			end
		end
		GridBattle.MoveAlly(s, best[1], best[2])
		-- 쓸 수 있는 직업 스킬 중 첫 번째(쿨·스테미나), 없으면 명상
		local used = false
		for index = 3, 1, -1 do
			if GridBattle.ResolveSkill(s, index, "Success", rng) then
				used = true
				break
			end
		end
		if not used then
			GridBattle.ResolveSkill(s, #GridBattle.SkillList(s), "Success", rng)
		end
		if VERBOSE then
			print(turns, s.Log[#s.Log])
		end
		if s.Outcome ~= "Ongoing" then
			break
		end
		for _, enemy in GridBattle.PlannedThreats(s) do
			GridBattle.ResolveDodge(s, enemy.Id, if rng() < 0.6 then "Success" else "Fail")
		end
		GridBattle.EndTurn(s)
		if s.Outcome == "Ongoing" then
			GridBattle.EnemyPlan(s, rng)
		end
	end
	local parts = {}
	for _, key in { "Head", "DeleteArm", "PatchArm", "Core" } do
		local u = s.Units["boss_" .. key]
		table.insert(parts, string.format("%s %d", key, u.Health))
	end
	print(string.format("%-12s %-8s %2d턴  체력 %3d/%d  %s", classId, s.Outcome, turns, s.Units.player.Health, s.Units.player.MaxHealth, table.concat(parts, " ")))
end
