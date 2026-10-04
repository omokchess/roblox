--[[
	converge_hits_check.luau — 2026-10-04. 펄서 수렴이 [공명] 수만큼 연타하는지(없으면 한 번).  lune run tools/converge_hits_check.luau
]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local function hits(stacks: number): (number, number)
	local s = GridBattle.New(1, "시험", 5000, 20, "Pulsar", 20, 999, {}, { Name = "연타 시험", Enemies = { "Slime" }, HealthScale = 400, PowerScale = 0.01 })
	s.Debug = { NoCooldown = true }
	GridBattle.Ally(s).Status.Stacks[ClassResources.RESONATE] = stacks
	local index
	for i, e in GridBattle.SkillList(s) do
		if e.Id == "Converge" then
			index = i
		end
	end
	local hp0 = 0
	for _, u in s.Units do
		if u.Side == "Enemy" then hp0 += u.Health end
	end
	assert(GridBattle.ResolveSkill(s, index, "Fail", function() return 0.999 end), "수렴을 못 썼다")
	local hp1 = 0
	for _, u in s.Units do
		if u.Side == "Enemy" then hp1 += u.Health end
	end
	local log = table.concat(s.Log, " ")
	return hp0 - hp1, tonumber(log:match("수렴 (%d)연타")) or 0
end

local d0, n0 = hits(0)
local d3, n3 = hits(3)
assert(n0 == 1 and n3 == 3, string.format("연타 수 %d / %d", n0, n3))
assert(math.abs(d3 / d0 - 3) < 0.05, string.format("3연타 피해가 한 번의 3배가 아니다: %d vs %d", d3, d0))
print(string.format("수렴 연타 점검 통과: 공명 0 → 1회 %d, 공명 3 → 3회 %d", d0, d3))
