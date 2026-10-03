--[[
	skill_damage_probe.luau — 2026-10-03. 직업 스킬마다 실제 피해(판정 엔진 그대로)를 잰다. 밸런스 점검용.
	  lune run tools/skill_damage_probe.luau
	적: 아주 튼튼한 슬라임 여섯(6×3 판의 앞쪽). 치명타 없이(난수 0.999), QTE 성공.
	두 경우: 자원 0 / 자원 가득(직업 자원 상한, 붕괴는 차징 2).
	한 스킬에 여러 대상이면 합. 표: 직업 · 스킬 · 피해(자원0) · 피해(가득) · 맞은 수.
]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleSkills = loadShared("BattleSkills")
local BattleStatus = loadShared("BattleStatus")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local CLASSES = { "Duelist", "Musician", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
local FULL = {
	Duelist = { [ClassResources.FOCUS] = 10, [ClassResources.READY] = 1 },
	Musician = { [ClassResources.METER] = 3, [ClassResources.SIXTEENTH] = 16, [ClassResources.BRILLANTE] = 5 },
	Quasar = { [ClassResources.MASS] = 20, [ClassResources.CHARGE] = 2 },
	Pulsar = { [ClassResources.RESONATE] = 3 },
	WallPilgrim = {},
	WallMason = { [ClassResources.WALL] = 5 },
	WallBreaker = { [ClassResources.RUIN] = 5 },
	Alchemist = { [ClassResources.POISON_BOTTLE] = 2, [ClassResources.FIRE_BOTTLE] = 2, [ClassResources.OIL_BOTTLE] = 2 },
	Berserker = { [ClassResources.RAGE] = 8 },
}

local function battle(classId: string)
	local s = GridBattle.New(1, "시험", 5000, 20, classId, 20, 999, {}, {
		Name = "피해 시험",
		Enemies = { "Slime", "Slime", "Slime", "Slime", "Slime", "Slime" },
		HealthScale = 400,
		PowerScale = 0.01,
	})
	s.Debug = { NoCooldown = true }
	return s
end

local function enemyHp(s): (number, { [string]: number })
	local hp, each = 0, {}
	for id, u in s.Units do
		if u.Side == "Enemy" then
			hp += u.Health
			each[id] = u.Health
		end
	end
	return hp, each
end

local function measure(classId: string, index: number, full: boolean, skillId: string?): (number, string, number)
	local s = battle(classId)
	local ally = GridBattle.Ally(s)
	if full then
		for id, n in FULL[classId] or {} do
			BattleStatus.AddStack(ally.Status, id, n, 99)
		end
	end
	local list = GridBattle.SkillList(s)
	local entry = if skillId then { Id = skillId } else list[index]
	if not entry then
		return -1, "?", 0
	end
	local before, each0 = enemyHp(s)
	local ok, err = GridBattle.ResolveSkill(s, index, "Success", function()
		return 0.999
	end, skillId)
	if not ok then
		return -1, entry.Id .. "(" .. tostring(err) .. ")", 0
	end
	local after, each1 = enemyHp(s)
	local hit = 0
	for id, h in each0 do
		if each1[id] < h then
			hit += 1
		end
	end
	return before - after, entry.Id, hit
end

for _, classId in CLASSES do
	local s = battle(classId)
	local list = GridBattle.SkillList(s)
	if classId == "Duelist" then
		local d, _, h = measure(classId, 4, true, "PointBlank")
		print(string.format("%-11s %-18s 가득 %5d (%d명, 1명당 %4d)", classId, "PointBlank", d, h, d // math.max(1, h)))
	end
	for i, entry in list do
		local skill = BattleSkills.ById(entry.Id)
		if skill and skill.Damage > 0 then
			local d0, id, h0 = measure(classId, i, false)
			local d1, _, h1 = measure(classId, i, true)
			print(string.format("%-11s %-18s 기본 %5d (%d명, 1명당 %4d)  가득 %5d (%d명, 1명당 %4d)  표 %d×모션%d", classId, id, d0, h0, d0 // math.max(1, h0), d1, h1, d1 // math.max(1, h1), skill.Damage, #BattleSkills.AllShapes(skill)))
		end
	end
end
