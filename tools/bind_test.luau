--[[ bind_test.luau — [묶임] 한 규칙 점검(2026-10-31): 솔로 조율자가 매 턴 묶이지 않고 3턴에 한 번, 미자르·검수 면역 공유. lune run tools/bind_test.luau ]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleStatus = loadShared("BattleStatus")
local BattleSkillEffects = loadShared("BattleSkillEffects")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local s = GridBattle.New(1, "시험", 5000, 20, "Attuner", 20, 999, {}, { Name = "묶임", Enemies = { "Slime" }, HealthScale = 1000, PowerScale = 0 })
local ally = GridBattle.Ally(s)
local row = {}
for turn = 1, 9 do
	local bound = BattleStatus.Stack(ally.Status, ClassResources.BIND) > 0
	local ok = GridBattle.MoveAlly(s, if turn % 2 == 0 then 2 else 1, 2)
	table.insert(row, string.format("%d:%s%s", turn, if bound then "묶임" else "-", if ok then "" else "(이동X)"))
	GridBattle.EndTurn(s)
end
print(table.concat(row, " "))
-- 공유: 미자르로 묶인 뒤엔 TryBind 가 안 묶는다
local st = BattleStatus.New()
assert(BattleSkillEffects.TryBind(st) == true)
assert(BattleSkillEffects.TryBind(st) == false)
print("면역 공유 OK")
local line = table.concat(row, " ")
assert(line:find("1:묶임") and line:find("2:%-") and line:find("3:%-") and line:find("4:묶임"), "솔로 조율자는 3턴에 한 번 묶여야 한다 — " .. line)
print("묶임 점검 통과")

-- 미자르로 묶인 턴엔 디버그 검수 칸에서 턴을 마쳐도 안 묶인다(면역 공유)
local BattleGrid = loadShared("BattleGrid")
local d = GridBattle.New(1, "시험", 5000, 20, "Attuner", 20, 999, {}, { Name = "묶임 디버그", Enemies = { "Debug" }, HealthScale = 0.01, PowerScale = 0 })
assert(BattleStatus.Stack(GridBattle.Ally(d).Status, ClassResources.BIND) > 0, "미자르가 첫 턴에 묶음")
local me = BattleGrid.CellOf(d.Grid, "player")
d.Boss.DeletePlan = { Cells = { { me.X, me.Y } }, Owner = "boss_DeleteArm" }
d.Boss.Deleted = {}
GridBattle.EndTurn(d)
assert((d.Boss.Locked or 0) == 0, "미자르 면역 중엔 검수 묶임도 안 걸린다")
print("묶임 면역 공유(미자르 → 검수) 통과")
