--[[ bind_test.luau — [묶임] 점검(2026-10-31 · 11-01): 공통 상태이상(누구든 턴 끝에 풀림) · 솔로 조율자는 미자르로 묶이지 않음(질문 16-B) ·
	미자르·검수 면역 공유. lune run tools/bind_test.luau ]]
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
assert(not line:find("묶임") and not line:find("이동X"), "솔로 조율자는 미자르로 묶이지 않는다 — " .. line)
-- 공통 상태이상: 조율자가 아니어도 묶이면 그 턴 못 움직이고 턴 끝에 풀린다
local b = GridBattle.New(1, "시험", 5000, 20, "Berserker", 20, 999, {}, { Name = "묶임 광전사", Enemies = { "Slime" }, HealthScale = 1000, PowerScale = 0 })
local bAlly = GridBattle.Ally(b)
assert(BattleSkillEffects.TryBind(bAlly.Status), "광전사도 묶인다")
assert(GridBattle.MoveAlly(b, 2, 2) == false, "묶이면 못 움직인다")
GridBattle.EndTurn(b)
assert(BattleStatus.Stack(bAlly.Status, ClassResources.BIND) == 0, "턴 끝에 풀린다(조율자가 아니어도)")
print("묶임 점검 통과")

-- 미자르로 묶인 턴엔 디버그 검수 칸에서 턴을 마쳐도 안 묶인다(면역 공유)
local BattleGrid = loadShared("BattleGrid")
local d = GridBattle.New(1, "시험", 5000, 20, "Attuner", 20, 999, {}, { Name = "묶임 디버그", Enemies = { "Debug" }, HealthScale = 0.01, PowerScale = 0 })
assert(BattleSkillEffects.TryBind(GridBattle.Ally(d).Status), "다른 묶임(파티 미자르·심베라즈마 같은 것)이 먼저 걸림")
local me = BattleGrid.CellOf(d.Grid, "player")
d.Boss.DeletePlan = { Cells = { { me.X, me.Y } }, Owner = "boss_DeleteArm" }
d.Boss.Deleted = {}
GridBattle.EndTurn(d)
assert((d.Boss.Locked or 0) == 0, "묶임 면역 중엔 검수 묶임도 안 걸린다")
print("묶임 면역 공유(묶임 → 검수) 통과")
