--[[
	card_impact_probe.luau — 2026-10-03. 카드 한 장씩만 들었을 때 스킬 하나의 피해가 몇 배가 되는지(밸런스 원인 찾기).
	  lune run tools/card_impact_probe.luau [직업] [스킬Id] [무기공격력]
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local ClassResources = loadShared("ClassResources")
local AbilityCards = loadShared("AbilityCards/init")
AbilityCards.Register()

local classId = process.args[1] or "Quasar"
local skillId = process.args[2] or "Singularity"
local power = tonumber(process.args[3] or "5000") :: number
local FULL = { Mass = 50, Charge = 3 }

local function run(owned)
	local s = GridBattle.New(1, "시험", 50000, power, classId, 100, 999, owned, {
		Name = "카드 시험", Enemies = { "Slime", "Slime", "Slime", "Slime", "Slime", "Slime" }, HealthScale = 100000, PowerScale = 0.01,
	}, { Strength = 100, Intellect = 100, Agility = 50, Luck = 0 })
	s.Debug = { NoCooldown = true }
	local ally = GridBattle.Ally(s)
	for _, id in ClassResources.ForClass(classId) do
		ally.Status.Stacks[id] = FULL[id] or ClassResources.Cap(id) or 5
	end
	local h0 = 0
	for _, u in s.Units do
		if u.Side == "Enemy" then h0 += u.Health end
	end
	local index
	for i, e in GridBattle.SkillList(s) do
		if e.Id == skillId then index = i end
	end
	local ok = index and GridBattle.ResolveSkill(s, index, "Success", function() return 0.999 end)
	local h1 = 0
	for _, u in s.Units do
		if u.Side == "Enemy" then h1 += u.Health end
	end
	return if ok then h0 - h1 else -1
end

local base = run({})
print(string.format("%s %s 무기 %d — 카드 없음 %d", classId, skillId, power, base))
local rows = {}
for _, module in AbilityCards.Modules do
	if module.ClassId == classId then
		for _, card in module.Cards do
			local d = run({ { CardId = card.Id, Level = 6 } })
			if base > 0 and d >= 0 and math.abs(d / base - 1) > 0.02 then
				table.insert(rows, { card.Id .. " " .. card.Name, d / base })
			end
		end
	end
end
table.sort(rows, function(a, b) return a[2] > b[2] end)
for _, r in rows do
	print(string.format("  ×%.2f  %s", r[2], r[1]))
end
