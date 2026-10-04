--[[
	pulsar_probe.luau — 2026-10-04. 펄서 수렴이 왜 센지 쪼개 본다.  lune run tools/pulsar_probe.luau [무기]
	1) 카드 없이: 공명 0~3 · QTE 성공/실패 · 감극(적에게 0~3)
	2) 카드 한 장씩 배율(공명 3, 무기 그대로)
	3) 다른 직업 주력기와 같은 조건(카드 없이) 비교는 full_build_probe 로
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleStatus = loadShared("BattleStatus")
local ClassResources = loadShared("ClassResources")
local AbilityCards = loadShared("AbilityCards/init")
local BattleSkillEffects = loadShared("BattleSkillEffects")
AbilityCards.Register()
local power = tonumber(process.args[1] or "5000") :: number
local R = ClassResources

local function run(owned, resonate: number, grade: string, depolar: number): number
	local s = GridBattle.New(1, "시험", 50000, power, "Pulsar", 100, 999, owned, {
		Name = "펄서 시험", Enemies = { "Slime" }, HealthScale = 100000, PowerScale = 0.01,
	}, { Strength = 100, Intellect = 100, Agility = 50, Luck = 0 })
	s.Debug = { NoCooldown = true }
	GridBattle.Ally(s).Status.Stacks[R.RESONATE] = resonate
	local enemy
	for _, u in s.Units do
		if u.Side == "Enemy" then enemy = u end
	end
	if depolar > 0 then
		BattleSkillEffects.ApplyDepolar(enemy.Status, depolar, 2, 0.15)
	end
	local index
	for i, e in GridBattle.SkillList(s) do
		if e.Id == "Converge" then index = i end
	end
	local h0 = enemy.Health
	local ok = GridBattle.ResolveSkill(s, index, grade, function() return 0.999 end)
	return if ok then h0 - enemy.Health else -1
end

print(string.format("== 수렴 · 무기 %d · 카드 없음 · 한 대상 · 치명 없음", power))
local base = run({}, 0, "Fail", 0)
for _, g in { "Fail", "Success" } do
	local row = {}
	for n = 0, 3 do
		table.insert(row, string.format("공명%d %7d(×%.2f)", n, run({}, n, g, 0), run({}, n, g, 0) / base))
	end
	print("  QTE " .. g .. ": " .. table.concat(row, "  "))
end
local row = {}
for d = 0, 3 do
	table.insert(row, string.format("감극%d %7d(×%.2f)", d, run({}, 3, "Success", d), run({}, 3, "Success", d) / base))
end
print("  공명3·QTE 성공 + 적 감극: " .. table.concat(row, "  "))

print("== 카드 한 장씩(Lv6) — 공명 3 · QTE 성공 · 감극 0 기준 배율")
local ref = run({}, 3, "Success", 0)
local rows = {}
for _, module in AbilityCards.Modules do
	if module.ClassId == "Pulsar" then
		for _, card in module.Cards do
			local d = run({ { CardId = card.Id, Level = 6 } }, 3, "Success", 0)
			if d > 0 and math.abs(d / ref - 1) > 0.02 then
				table.insert(rows, { card.Id .. " " .. card.Name, d / ref })
			end
		end
	end
end
table.sort(rows, function(a, b) return a[2] > b[2] end)
for _, r in rows do
	print(string.format("  ×%.2f  %s", r[2], r[1]))
end
