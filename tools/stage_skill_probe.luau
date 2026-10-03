--[[
	stage_skill_probe.luau — 2026-10-03. 단계 스킬(Shape.Stages: 붕괴·특이점·분쇄·크레셴도 강화)이
	자원 수만큼 범위가 실제로 자라는지 서버 판정으로 잰다.  lune run tools/stage_skill_probe.luau
]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleSkills = loadShared("BattleSkills")
local BattleStatus = loadShared("BattleStatus")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local function battle(classId: string)
	local s = GridBattle.New(1, "시험", 5000, 20, classId, 20, 999, {}, { Name = "단계 시험", Enemies = { "Slime", "Slime", "Slime", "Slime", "Slime", "Slime" }, HealthScale = 50, PowerScale = 0.1 })
	s.Debug = { NoCooldown = true }
	return s
end

for _, case in {
	{ "Quasar", "Singularity", ClassResources.MASS, { 0, 8, 15 } },
	{ "Quasar", "Collapse", ClassResources.CHARGE, { 1, 2 } },
	{ "Berserker", "BloodCrash", ClassResources.RAGE, { 0, 4, 8 } },
} do
	local classId, skillId, res, stacks = case[1], case[2], case[3], case[4]
	local skill = BattleSkills.ById(skillId)
	print(string.format("== %s %s GrowResource=%s", classId, skillId, tostring(skill.GrowResource)))
	for _, n in stacks do
		local s = battle(classId)
		local ally = GridBattle.Ally(s)
		if res then
			BattleStatus.AddStack(ally.Status, res, n, 99)
		end
		local grow = GridBattle.AllyGrowCount(s, skill)
		local snap = GridBattle.Snapshot(s)
		local shownGrow
		for _, e in snap.Skills or snap.AllySkills or {} do
			if e.Id == skillId then
				shownGrow = e.Grow
			end
		end
		print(string.format("  자원 %d → 단계 %d (스냅샷 Grow=%s)", n, grow, tostring(shownGrow)))
	end
end
