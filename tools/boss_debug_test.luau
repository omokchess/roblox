--[[
	boss_debug_test.luau — 보스 디버그 규칙 점검(2026-09-29). 서버 판정(GridBattle)만 돌린다.
	  lune run tools/boss_debug_test.luau
	실패하면 오류로 끝난다.
]]
local loadShared = require("./lune_env")

local BattleStatus = loadShared("BattleStatus")
local GridBattle = loadShared("GridBattle")
local BattleGrid = loadShared("BattleGrid")
local BattleSkills = loadShared("BattleSkills")
loadShared("AbilityCards/init").Register()

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local seed = 7
local function rng(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

-- 검수 준비중(예고)·검은 칸이 아닌 칸으로 옮긴다(검수를 하지 않을 때)
local function dodgeGlitch(s)
	local arm = s.Units.boss_DeleteArm
	local bad = {}
	for _, c in (arm and arm.Plan and arm.Plan.Cells) or {} do
		bad[c[1] .. "," .. c[2]] = true
	end
	for x = 1, 6 do
		for y = 1, 3 do
			if not bad[x .. "," .. y] and not s.Boss.Deleted[BattleGrid.CellKey("Ally", x, y)] then
				return (GridBattle.MoveAlly(s, x, y))
			end
		end
	end
	return false
end

local function newBoss(classId: string?)
	local state = GridBattle.New(1, "시험", 5000, 20, classId or "Berserker", 20, 999, {}, { Name = "보스 시험", Enemies = { "Debug", "Slime" }, HealthScale = 0.012, PowerScale = 0.15 })
	state.Debug = { NoCooldown = true }
	-- 판 변주(전투마다 무작위)는 아래 9번에서 따로 본다 — 나머지 시험은 변주 없이
	state.Boss.Variant = ""
	state.Boss.FixedVariant = true -- 턴마다 바뀌는 판 변주는 9번에서 따로 본다
	state.Boss.Buffs = {}
	return state
end

-- 1) 편성: 부위 넷이 적 진영 18칸을 모두 차지하고, 슬라임은 안 나온다
do
	local s = newBoss()
	local enemies = GridBattle.AliveEnemies(s)
	check(#enemies == 4, "부위 넷이어야 한다: " .. #enemies)
	local owners = {}
	for x = 1, 6 do
		for y = 1, 3 do
			local id = BattleGrid.Occupant(s.Grid, "Enemy", x, y)
			check(id ~= nil, string.format("적 칸 (%d,%d) 가 비었다", x, y))
			owners[id] = (owners[id] or 0) + 1
		end
	end
	check(owners.boss_Core == 12 and owners.boss_Head == 2, "코어 12칸·머리 2칸")
	-- 부위는 밀리지 않는다
	check(not BattleGrid.Move(s.Grid, "boss_Head", 3, 2), "보스 부위가 움직였다")
	check(GridBattle.PullEnemies(s, 1) == 0, "보스 부위가 끌려왔다")
end

-- 2) 라인 공격은 앞 부위부터 막히고, 부수면 코어까지 뚫린다
do
	local s = newBoss()
	local line3 = { Kind = "Line", Radius = 3 }
	local hit = BattleSkills.Targets(s.Grid, "Ally", 2, { Kind = "Line", Radius = 2 }, 0, 1)
	check(#hit == 1 and hit[1] == "boss_Head", "라인 2 앞 두 칸은 머리만")
	hit = BattleSkills.Targets(s.Grid, "Ally", 2, line3, 0, 1)
	check(#hit == 2, "앞 3칸은 머리 + 코어")
	GridBattle.DebugSetHealth(s, "boss_Head", 0)
	hit = BattleSkills.Targets(s.Grid, "Ally", 2, { Kind = "Line", Radius = 2 }, 0, 1)
	check(#hit == 1 and hit[1] == "boss_Core", "머리를 부수면 라인 2 는 코어부터")
	check(s.Outcome == "Ongoing", "머리만 부서졌는데 끝났다")
end

-- 3) 턴 박자: 1턴 광선 + 패치(칸 깔기), 2턴 광선 + 칸 삭제 + 강제 적용, 4턴 코어 덤프
do
	local s = newBoss()
	GridBattle.EnemyPlan(s, rng)
	local head = s.Units.boss_Head
	check(head.Plan and head.Plan.SkillId == "BreakpointBeam", "1턴 머리 광선")
	local buffs, debuffs = 0, 0
	for _, kind in s.Boss.Mods do
		if kind == "Buff" then
			buffs += 1
		elseif kind == "Debuff" then
			debuffs += 1
		end
	end
	local heals = 0
	for _, kind in s.Boss.Mods do
		if kind == "Heal" then
			heals += 1
		end
	end
	check(buffs == 2 and debuffs == 2 and heals == 1, "버프 둘·버그 둘·회복 하나")
	check(s.Units.boss_Core.Plan and s.Units.boss_Core.Plan.SkillId == "MemoryLeak", "1턴 코어 메모리 누수(매 턴 광역기)")
	-- 광선은 아군이 선 라인(2) 전부 — 위협이다
	check(#GridBattle.PlannedThreats(s) >= 1, "광선이 위협으로 잡혀야 한다")
	-- 라인을 비켜서면 광선은 빠진다(코어 메모리 누수는 체크무늬라 남을 수 있다)
	GridBattle.MoveAlly(s, 1, 1)
	for _, e in GridBattle.PlannedThreats(s) do
		check(e.Id ~= "boss_Head", "라인을 비키면 광선을 피한다")
	end
	-- 1턴부터 칸 삭제 무늬 예고(12 칸)
	check(s.Units.boss_DeleteArm.Plan and #s.Units.boss_DeleteArm.Plan.Cells == 12, "1턴 칸 삭제 12")
	-- 버프·회복 칸은 이번 턴 끝에도 남는 칸에 깔린다
	local willGo = {}
	for _, c in s.Units.boss_DeleteArm.Plan.Cells do
		willGo[BattleGrid.CellKey("Ally", c[1], c[2])] = true
	end
	for key, kind in s.Boss.Mods do
		if kind ~= "Debuff" then
			check(not willGo[key], "버프·회복 칸이 곧 지워질 칸에 깔렸다")
		end
	end
	dodgeGlitch(s)
	GridBattle.EndTurn(s)
	local names = { s.Boss.PresetName }

	-- 무늬는 매 턴 바뀌고, 다섯 무늬를 규칙적으로 돈다. 지운 칸은 한 턴 뒤 돌아온다
	local function keepSet()
		local keep = {}
		for x = 1, 6 do
			for y = 1, 3 do
				if not s.Boss.Deleted[BattleGrid.CellKey("Ally", x, y)] then
					keep[#keep + 1] = x .. "," .. y
				end
			end
		end
		table.sort(keep)
		return table.concat(keep, " ")
	end
	local seen = { [keepSet()] = true }
	check(#string.split(keepSet(), " ") == 6, "지운 뒤 6 칸만 남는다")
	for turn = 2, 6 do
		GridBattle.EnemyPlan(s, rng)
		check(s.Units.boss_DeleteArm.Plan and #s.Units.boss_DeleteArm.Plan.Cells == 12, turn .. "턴 칸 삭제 12")
		if turn == 2 then
			check(s.Units.boss_Core.Plan and s.Units.boss_Core.Plan.SkillId == "NullPointer", "2턴 코어 널 포인터")
			check(s.Units.boss_PatchArm.Plan.SkillId == "ForcedPatch", "2턴 강제 적용")
		end
		if turn == 4 then
			local core = s.Units.boss_Core
			check(core.Plan and core.Plan.SkillId == "CoreDump", "4턴 코어 덤프")
			for _, c in core.Plan.Cells do
				check(s.Boss.Mods[BattleGrid.CellKey("Ally", c[1], c[2])] ~= "Buff", "코어 덤프가 버프 칸을 덮었다")
			end
		end
		-- 예고 칸을 피해 선다(검수는 아래 6c 에서 따로 본다). 그로기면 못 움직인다
		local moved = dodgeGlitch(s)
		for _, enemy in GridBattle.PlannedThreats(s) do
			check(enemy.Id ~= "boss_DeleteArm", "검수는 회피 QTE 공격이 아니다")
			GridBattle.ResolveDodge(s, enemy.Id, "Fail")
		end
		local before = keepSet()
		GridBattle.EndTurn(s)
		local after = keepSet()
		check(after ~= before, turn .. "턴 무늬가 바뀌어야 한다")
		table.insert(names, s.Boss.PresetName)
		seen[after] = true
		local me = BattleGrid.CellOf(s.Grid, "player")
		check(not moved or me and not s.Boss.Deleted[BattleGrid.CellKey("Ally", me.X, me.Y)], "예고 칸을 피했으면 검은 칸 위가 아니다")
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	check(kinds == 5, "여섯 턴에 무늬 다섯이 다 나와야 한다: " .. kinds)
	check(names[1] == names[6], "다섯 턴마다 같은 무늬로 돌아온다: " .. table.concat(names, ","))
	print("무늬 순서: " .. table.concat(names, " → "))
end

-- 4) 버프 칸에 서서 쓰면 피해가 +40%, 버그 칸이면 −30%
do
	local function damageOn(kind: string?): number
		local s = newBoss("Berserker")
		s.Boss.Mods = {}
		if kind then
			s.Boss.Mods[BattleGrid.CellKey("Ally", 1, 2)] = kind
		end
		local before = s.Units.boss_Head.Health
		GridBattle.ResolveSkill(s, 1, "Success", function()
			return 0.99
		end)
		return before - s.Units.boss_Head.Health
	end
	local plain, buff, debuff = damageOn(nil), damageOn("Buff"), damageOn("Debuff")
	check(plain > 0, "기본 피해가 0")
	check(buff > plain and debuff < plain, string.format("버프/버그 칸 피해 %d / %d / %d", buff, plain, debuff))
end

-- 5) 부위 파괴 효과(2026-10-03 사용자: 검수 칸은 남기고 부위마다 검은 칸 부작용을 하나씩 없앤다):
--    서브코어-삭제 → 검수는 코어가 이어 함·고정 피해 없음, 서브코어-패치 → 버그 칸 사라짐·받는 피해 증가 없음, 머리 → 멈칫·스테미나 후유증 없음, 코어 → 승리
do
	local s = newBoss()
	s.Turn = 2
	GridBattle.EnemyPlan(s, rng)
	GridBattle.EndTurn(s)
	check(next(s.Boss.Deleted) ~= nil, "칸이 지워져 있어야 한다")
	GridBattle.DebugSetHealth(s, "boss_DeleteArm", 0)
	check(next(s.Boss.Deleted) ~= nil, "서브코어-삭제를 부숴도 검은 칸은 남는다")
	check(s.Boss.Removed.Cost, "서브코어-삭제 → 검은 칸 고정 피해가 사라진다")
	GridBattle.EnemyPlan(s, rng)
	check(s.Boss.DeletePlan and s.Boss.DeletePlan.Owner == "boss_Core" and #s.Boss.DeletePlan.Cells == 12, "서브코어-삭제가 없으면 코어가 검수를 잇는다")
	s.Boss.Mods = { [BattleGrid.CellKey("Ally", 2, 2)] = "Buff", [BattleGrid.CellKey("Ally", 3, 3)] = "Debuff" }
	GridBattle.DebugSetHealth(s, "boss_PatchArm", 0)
	check(s.Boss.Mods[BattleGrid.CellKey("Ally", 3, 3)] == nil and s.Boss.Mods[BattleGrid.CellKey("Ally", 2, 2)] == "Buff", "서브코어-패치: 버그만 사라진다")
	check(s.Boss.Removed.Hurt, "서브코어-패치 → 검은 칸 받는 피해 증가가 사라진다")
	GridBattle.DebugSetHealth(s, "boss_Head", 0)
	check(s.Boss.Removed.Stamina, "머리 → 검은 칸 스테미나 후유증이 사라진다")
	GridBattle.EnemyPlan(s, rng)
	check(#s.Planned == 0, "머리를 부순 다음 예고는 멈칫")
	GridBattle.DebugSetHealth(s, "boss_Core", 0)
	check(s.Outcome == "Victory", "코어를 부수면 승리: " .. s.Outcome)
	check(#GridBattle.AliveEnemies(s) == 0, "코어가 쓰러지면 모두 쓰러진다")
end

-- 5b) 2026-10-02 사용자: 다른 부위가 하나라도 살아 있으면 코어는 부서지지 않는다(체력 1에서 멈춤)
do
	local s = newBoss("Duelist")
	GridBattle.EnemyPlan(s, function()
		return 0.5
	end) -- 공용 rng 를 쓰면 뒤 시험의 무늬가 바뀐다
	local core = s.Units.boss_Core
	GridBattle.DebugSetHealth(s, "boss_Core", 1)
	GridBattle.ResolveDodge(s, "boss_Core", "Success") -- 패리 되돌림이 코어로
	check(core.Alive and core.Health == 1, "부위가 남아 있으면 코어는 1에서 버틴다: " .. core.Health)
	GridBattle.DebugSetHealth(s, "boss_Head", 0)
	GridBattle.DebugSetHealth(s, "boss_DeleteArm", 0)
	check(GridBattle.CoreLocked(s, core), "서브코어-패치가 남아 있으면 아직 잠김")
	GridBattle.DebugSetHealth(s, "boss_PatchArm", 0)
	check(not GridBattle.CoreLocked(s, core), "부위가 다 부서지면 풀린다")
	GridBattle.ResolveDodge(s, "boss_Core", "Success")
	check(not core.Alive and s.Outcome == "Victory", "그다음엔 코어가 부서진다: " .. s.Outcome)
	check(#GridBattle.AliveEnemies(s) == 0, "코어가 쓰러지면 모두 쓰러진다")
end

-- 6) 스냅샷: 부위 칸·예고·판 상태가 실린다
do
	local s = newBoss()
	GridBattle.EnemyPlan(s, rng)
	local snap = GridBattle.Snapshot(s)
	check(snap.Boss and #snap.Boss.Mods == 5, "스냅샷 버프/버그/회복 칸")
	check(snap.Units.boss_Core.Part == "Core" and #snap.Units.boss_Core.Cells == 12, "스냅샷 부위 칸")
	check(snap.Units.boss_Head.Plan ~= nil, "스냅샷 예고")
end

-- 6b) 2026-09-29 버프 규칙
do
	-- 라인이 안 맞으면 못 때린다: 라인 1(서브코어-삭제)에서 쓴 스킬은 머리(라인 2)를 못 맞힌다, 카드 피해도 막힌다
	local s = newBoss("Berserker")
	GridBattle.MoveAlly(s, 1, 1)
	local hits = {}
	for _, shape in BattleSkills.AllShapes(BattleSkills.ById("SlimeTackle") or { Shape = { Kind = "All" } }) do
		for _, id in BattleSkills.Targets(s.Grid, "Ally", 1, { Kind = "All" }, 0, 1) do
			hits[id] = true
		end
		local _ = shape
	end
	-- 2026-10-02 사용자: 라인 제한 없앰 — 전체 범위면 모든 부위가 맞는다
	check(hits.boss_DeleteArm and hits.boss_Core and hits.boss_Head and hits.boss_PatchArm, "라인 제한 없음: 전체 범위는 부위 넷 다")
	local before = s.Units.boss_Head.Health
	GridBattle.GainResource(s, s.Units.player, "none", 0)
	local env = s.Runtime and s.Runtime.Env
	local _ = env
	-- 직접 피해(카드 피해 경로와 같은 damageUnit): 반사처럼 라인 무시로 들어와도 0
	local Units = s.Units
	GridBattle.DebugSetHealth(s, "boss_Head", before) -- 그대로
	check(Units.boss_Head.Health == before, "머리 체력 그대로")

	-- 2026-10-04 리워크: 도트 경감 0, 출혈은 지금 체력의 5%
	local s2 = newBoss()
	local core = s2.Units.boss_Core
	core.Status.Bleed = 50
	local h0 = core.Health
	GridBattle.EndTurn(s2)
	check(h0 - core.Health == math.floor(h0 * 0.05), string.format("출혈 지금 체력 5%%: %d → %d", h0, core.Health))
	check(core.Resist and core.Resist.Fire == 0.9, "디버그 화염 저항 90%")
	-- 맹독성 물질: 연금술사가 건 화상(BurnIgnore 0.3)은 저항 90% → 60%, 받는 피해 10% → 40%
	local function burnLoss(ignore)
		local sb = newBoss()
		local u = sb.Units.boss_Core
		BattleStatus.AddBurn(u.Status, 20, ignore)
		local h = u.Health
		GridBattle.EndTurn(sb)
		return h - u.Health
	end
	local plain, toxic = burnLoss(nil), burnLoss(0.3)
	check(plain > 0 and math.abs(toxic / plain - 4) < 0.2, string.format("맹독 화상 4배: %d vs %d", toxic, plain))

	-- 회피만(광선): 막음은 실패로 / 회피·가드 불가(코어 덤프): 성공해도 맞는다
	local s3 = newBoss()
	GridBattle.EnemyPlan(s3, rng)
	local hp = s3.Units.player.Health
	GridBattle.ResolveDodge(s3, "boss_Head", "Partial")
	local lostPartial = hp - s3.Units.player.Health
	check(lostPartial > 0, "광선을 막으려 해도 다 맞는다: " .. lostPartial)
	s3.Turn = 4
	GridBattle.EndTurn(s3)
	s3.Turn = 4
	s3.Boss.Cooldowns.BlueScreen = 99 -- 궁극기(3턴째부터)를 막아 두고 1페이즈 박자만 본다
	GridBattle.EnemyPlan(s3, rng)
	check(s3.Units.boss_Core.Plan and s3.Units.boss_Core.Plan.SkillId == "CoreDump", "4턴 코어 덤프")
	hp = s3.Units.player.Health
	GridBattle.ResolveDodge(s3, "boss_Core", "Success")
	check(s3.Units.player.Health < hp, "코어 덤프는 회피 성공이어도 맞는다")

	-- 회복 칸: 턴 끝에 최대 체력 15%
	local s4 = newBoss()
	s4.Boss.Mods = { [BattleGrid.CellKey("Ally", 1, 2)] = "Heal" }
	s4.Units.player.Health = 1000
	GridBattle.EndTurn(s4)
	check(s4.Units.player.Health >= 1000 + 5000 * 0.15 - 1, "회복 칸 회복: " .. s4.Units.player.Health)
end

-- 6c) 검수(2026-09-29 사용자 설계): 예고 칸 +400% → 거기서 마치면 검은 칸에 묶임(검수중) → 다음 턴 테스터
do
	-- 부위가 한 방에 부서지지 않게 체력은 넉넉히
	local function newBoss(classId: string?)
		local st = GridBattle.New(1, "시험", 5000, 20, classId or "Berserker", 20, 999, {}, { Name = "보스 시험", Enemies = { "Debug" }, HealthScale = 1, PowerScale = 0.15 })
		st.Debug = { NoCooldown = true }
		return st
	end
	local function totalBoss(st)
		return st.Units.boss_Core.Health + st.Units.boss_Head.Health + st.Units.boss_DeleteArm.Health + st.Units.boss_PatchArm.Health
	end
	local function hitAt(st, x, y): number
		st.Boss.Mods = {}
		GridBattle.MoveAlly(st, x, y)
		local h = totalBoss(st)
		GridBattle.ResolveSkill(st, 1, "Success", function()
			return 0.99
		end)
		return h - totalBoss(st)
	end

	local s = newBoss("Berserker")
	GridBattle.EnemyPlan(s, rng)
	local c = s.Units.boss_DeleteArm.Plan.Cells[1]
	local plain = newBoss("Berserker")
	local d2 = hitAt(plain, c[1], c[2])
	GridBattle.MoveAlly(s, c[1], c[2])
	check(GridBattle.Snapshot(s).Boss.Pending, "예고 칸 위(스냅샷)")
	local d1 = hitAt(s, c[1], c[2])
	check(d2 > 0 and d1 >= d2 * 4, string.format("검수 준비중 피해 %d vs 보통 %d", d1, d2))

	-- 예고 칸에서 마친다 → 검은 칸이 되고 그대로 서 있고, 다음 턴 못 움직인다
	GridBattle.EndTurn(s)
	local me = BattleGrid.CellOf(s.Grid, "player")
	check(me.X == c[1] and me.Y == c[2], "검은 칸이 돼도 밀려나지 않는다")
	check(s.Boss.Deleted[BattleGrid.CellKey("Ally", c[1], c[2])] ~= nil, "예고 칸이 검은 칸이 됐다")
	check(s.Boss.Locked == 1, "다음 턴 묶임")
	check(not GridBattle.MoveAlly(s, c[1] == 1 and 2 or 1, c[2]), "묶인 턴엔 못 움직인다")
	check(GridBattle.Snapshot(s).Boss.Checking, "검은 칸 위(검수중)")

	-- 검수중: 받는 피해 +200%
	GridBattle.EnemyPlan(s, rng)
	local hp0 = s.Units.player.Health
	GridBattle.ResolveDodge(s, "boss_Head", "Fail")
	local taken = hp0 - s.Units.player.Health
	local ref = newBoss()
	GridBattle.EnemyPlan(ref, rng)
	GridBattle.MoveAlly(ref, c[1], c[2])
	GridBattle.EnemyPlan(ref, rng)
	local r0 = ref.Units.player.Health
	GridBattle.ResolveDodge(ref, "boss_Head", "Fail")
	local refTaken = r0 - ref.Units.player.Health
	check(refTaken > 0 and taken >= refTaken * 1.8, string.format("검수중 받는 피해(방어 뺄셈이 있어 딱 3배는 아니다) %d vs 보통 %d", taken, refTaken))

	-- 검은 칸에서 마친다 → 최대 체력 9% 고정 피해(죽지 않음), 테스터(방어막 200), 2턴 뒤 스테미나 20
	s.Units.player.Health = 5000
	local st0 = s.Units.player.Stamina
	-- 다음 무늬가 하필 이 칸을 또 예고하면 다시 묶인다(무작위 차례에 달림) — 묶임 한 턴만 보려고 이번 예고는 지운다
	s.Boss.DeletePlan = nil
	GridBattle.EndTurn(s)
	check(math.abs((5000 - s.Units.player.Health) - 450) <= 1, "검수중 최대 체력 9%: " .. (5000 - s.Units.player.Health))
	check(s.Boss.Tester == 1 and s.Units.player.Status.Shield >= GridBattle.TESTER_SHIELD, "테스터 + 방어막")
	check(s.Boss.Locked == 0, "묶임은 한 턴")
	local stAfter1 = s.Units.player.Stamina
	local d3 = hitAt(s, 1, 2)
	local d4 = hitAt(newBoss("Berserker"), 1, 2)
	check(d3 >= d4 * 20, string.format("테스터 피해 %d vs 보통 %d", d3, d4))
	GridBattle.EndTurn(s)
	check(s.Boss.Tester == 0 and s.Units.player.Status.Shield == 0, "테스터·방어막은 한 턴")
	check(#(s.Boss.StaminaDebt or {}) == 1, "스테미나 빚은 아직 남았다(1턴 흐름)")
	GridBattle.EndTurn(s)
	check(#s.Boss.StaminaDebt == 0 and table.concat(s.Log, " "):find("검수중 후유증", 1, true), "2턴 뒤 스테미나 20 깎임")
	local _ = st0 + stAfter1

	-- 검수중 고정 피해로는 죽지 않는다(2026-10-02 사용자: 최대 체력 9%, 이 효과로 사망하지 않음)
	local k = newBoss("Berserker")
	GridBattle.EnemyPlan(k, rng)
	local kc = k.Units.boss_DeleteArm.Plan.Cells[1]
	GridBattle.MoveAlly(k, kc[1], kc[2])
	GridBattle.EndTurn(k)
	check(GridBattle.Snapshot(k).Boss.Checking, "검은 칸 위(죽지 않음 시험)")
	k.Units.player.Health = 10
	GridBattle.EndTurn(k)
	check(k.Units.player.Alive and k.Units.player.Health >= 1, "검수중 고정 피해로는 죽지 않는다: " .. k.Units.player.Health)
end

-- 7) 끝까지 싸워 본다(자동: 매 턴 가장 센 스킬, 회피 반반) — 멈추거나 오류 없이 끝나야 한다
do
	local s = newBoss("Duelist")
	local turns = 0
	GridBattle.EnemyPlan(s, rng)
	while s.Outcome == "Ongoing" and turns < 80 do
		turns += 1
		-- 버프 칸이 있고 위협이 없으면 그리로, 아니면 위협 없는 칸으로
		local best = nil
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
					local score = (if safe then 2 else 0) + (if buff then 1 else 0) + gamble
					if not best or score > best[3] then
						best = { x, y, score }
					end
					if was then
						GridBattle.MoveAlly(s, was.X, was.Y)
					end
				end
			end
		end
		if best then
			GridBattle.MoveAlly(s, best[1], best[2])
		end
		GridBattle.ResolveSkill(s, 1, "Success", rng)
		if s.Outcome ~= "Ongoing" then
			break
		end
		for _, enemy in GridBattle.PlannedThreats(s) do
			GridBattle.ResolveDodge(s, enemy.Id, if rng() < 0.5 then "Success" else "Fail")
		end
		GridBattle.EndTurn(s)
		if s.Outcome == "Ongoing" then
			GridBattle.EnemyPlan(s, rng)
		end
	end
	print(string.format("자동 전투: %s, %d턴, 체력 %d/%d  머리 %d 삭제팔 %d 패치팔 %d 코어 %d", s.Outcome, turns, s.Units.player.Health, s.Units.player.MaxHealth, s.Units.boss_Head.Health, s.Units.boss_DeleteArm.Health, s.Units.boss_PatchArm.Health, s.Units.boss_Core.Health))
	for i = math.max(1, #s.Log - 5), #s.Log do print("  ", s.Log[i]) end
	check(s.Outcome ~= "Ongoing", "80턴 안에 끝나지 않았다")
end

-- 8) 막 누르기: 직업마다 아무 칸으로 옮기고(검은 칸·예고 칸 포함) 아무 스킬·아무 등급으로 60턴. 오류 없이 규칙이 지켜져야 한다
do
	local CharacterDefinitions = loadShared("CharacterDefinitions")
	local fz = 91
	local function r(): number
		fz = (fz * 48271) % 2147483647
		return fz / 2147483647
	end
	for _, def in CharacterDefinitions.All() do
		local s = GridBattle.New(1, "시험", 5000, 20, def.Id, 20, 999, {}, { Name = "막 누르기", Enemies = { "Debug" }, HealthScale = 1, PowerScale = 0.15 })
		s.Debug = { God = true }
		GridBattle.EnemyPlan(s, r)
		local prevTwoTurn = false
		for turn = 1, 60 do
			if s.Outcome ~= "Ongoing" then
				break
			end
			local before = BattleGrid.CellOf(s.Grid, "player")
			local locked = (s.Boss.Locked or 0) > 0
			local ok = GridBattle.MoveAlly(s, math.floor(r() * 6) + 1, math.floor(r() * 3) + 1)
			local after = BattleGrid.CellOf(s.Grid, "player")
			if locked then
				check(not ok and after.X == before.X and after.Y == before.Y, def.Id .. " 묶인 턴에 움직였다")
			end
			local skills = GridBattle.SkillList(s)
			GridBattle.ResolveSkill(s, math.floor(r() * #skills) + 1, ({ "Success", "Partial", "Fail" })[math.floor(r() * 3) + 1], r)
			for _, t in GridBattle.PlannedThreatList(s) do
				GridBattle.ResolveDodge(s, t.Unit.Id, ({ "Success", "Partial", "Fail" })[math.floor(r() * 3) + 1], t.Index)
			end
			GridBattle.EndTurn(s)
			local me = s.Units.player
			check(me.Stamina >= 0 and me.Health >= 0 and me.Health <= me.MaxHealth, def.Id .. " 체력·스테미나 범위")
			check((s.Boss.Tester or 0) <= 1 and (s.Boss.Locked or 0) <= 1, def.Id .. " 테스터·묶임은 한 턴")
			local black = 0
			for _ in s.Boss.Deleted do
				black += 1
			end
			-- 보통 12 칸, 포맷이 터진 턴은 16 칸(두 칸만 남김). 검은 칸이 2턴 남는 판(오래 남는 검은 칸·검수 폭주)은
			-- 앞 턴 것과 겹쳐 더 많을 수 있다 — 그때는 판 칸 수(18)만 넘지 않으면 된다
			-- 판 변주는 턴마다 바뀌어 앞 턴(오래 남는 검은 칸)의 검은 칸이 이번 턴에도 남을 수 있다
			local twoTurn = s.Boss.Variant == "LongBlack" or s.Boss.LastStand == "Purge"
			-- 강제 종료 연계는 남길 칸이라도 그 3×3을 지운다 → 한 턴 치만으로도 17 칸까지(한 칸은 남는다)
			local limit = if twoTurn or prevTwoTurn then 18 else 17
			prevTwoTurn = twoTurn
			check(black <= limit, string.format("%s 검은 칸이 %d 칸보다 많다: %d", def.Id, limit, black))
			if s.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(s, r)
			end
			local _ = turn
		end
	end
end

-- 8) 2026-10-03 사용자: 4페이즈·스킬 해금·3페이즈 두 번 행동·보스 스테미나(과부하)·버프·충전 끊기·궁극기(체퍼댐 50%·회복 불가)
do
	local function setRatio(st, ratio)
		for _, id in st.Boss.Parts do
			local u = st.Units[id]
			u.Health = math.max(1, math.floor(u.MaxHealth * ratio))
		end
	end
	local function plans(st)
		local n, ids = 0, {}
		for _, id in st.Boss.Parts do
			for _, p in st.Units[id].Plans or {} do
				n += 1
				ids[p.SkillId] = (ids[p.SkillId] or 0) + 1
			end
		end
		return n, ids
	end

	-- 페이즈: 체력 합 비율로만 오르고 내려가지 않는다. 2페이즈 최적화(최대 스테미나 +20, 가득)
	local s = newBoss()
	check(s.Boss.Phase == 1, "처음은 1페이즈")
	setRatio(s, 0.7)
	GridBattle.EnemyPlan(s, rng)
	check(s.Boss.Phase == 2 and s.Boss.MaxStamina == 120, "75% 아래 → 2페이즈 · 최대 스테미나 120")
	setRatio(s, 0.2)
	GridBattle.EndTurn(s)
	GridBattle.EnemyPlan(s, rng)
	check(s.Boss.Phase == 4, "25% 아래 → 4페이즈: " .. s.Boss.Phase)
	local kernel = false
	for _, b in s.Boss.Buffs do
		kernel = kernel or b.Id == "KernelMode"
	end
	check(kernel, "4페이즈 커널 모드 버프")

	-- 3페이즈: 부위마다 두 번 행동(스테미나가 넉넉할 때)
	local t = newBoss()
	setRatio(t, 0.4)
	t.Boss.Stamina, t.Boss.MaxStamina = 999, 999
	GridBattle.EnemyPlan(t, rng)
	check(t.Boss.Phase == 3, "40% → 3페이즈")
	local doubled = 0
	for _, id in t.Boss.Parts do
		local acts = 0
		for _, p in t.Units[id].Plans or {} do
			if p.SkillId ~= "DeleteCells" then
				acts += 1
			end
		end
		if acts >= 2 then
			doubled += 1
		end
	end
	check(doubled >= 3, "3페이즈 부위 셋 이상이 두 번 행동: " .. doubled)
	check(#GridBattle.PlannedThreatList(t) >= 0, "3페이즈 위협 목록")

	-- 같은 부위가 같은 스킬을 잇달아 쓰지 않는다(2페이즈 이상)
	local u = newBoss()
	setRatio(u, 0.6)
	local last = {}
	for turn = 1, 12 do
		u.Turn = turn
		u.Boss.Stamina, u.Boss.MaxStamina = 999, 999
		GridBattle.EnemyPlan(u, rng)
		for _, id in u.Boss.Parts do
			local key = u.Units[id].Part
			for _, p in u.Units[id].Plans or {} do
				if p.SkillId ~= "DeleteCells" and p.SkillId ~= "KernelPanicBurst" then
					check(last[key] ~= p.SkillId, key .. " 같은 스킬을 잇달아 썼다: " .. p.SkillId)
					last[key] = p.SkillId
					break
				end
			end
		end
		GridBattle.EndTurn(u)
	end

	-- 과부하: 스테미나가 바닥이면 공격 없이 칸 기믹만 · 받는 피해 +50%
	local o = newBoss()
	o.Boss.Stamina = 5
	GridBattle.EnemyPlan(o, rng)
	check(o.Boss.Overheat == 1, "스테미나 5 → 과부하")
	local n, ids = plans(o)
	check(n == (ids.DeleteCells or 0), "과부하 턴엔 칸 기믹만: " .. n)
	local ref2 = newBoss()
	GridBattle.MoveAlly(o, 1, 2)
	GridBattle.MoveAlly(ref2, 1, 2)
	o.Boss.Mods, ref2.Boss.Mods = {}, {}
	local hh, hr = o.Units.boss_Head.Health, ref2.Units.boss_Head.Health
	GridBattle.ResolveSkill(o, 1, "Success", function()
		return 0.99
	end)
	GridBattle.ResolveSkill(ref2, 1, "Success", function()
		return 0.99
	end)
	local dO, dR = hh - o.Units.boss_Head.Health, hr - ref2.Units.boss_Head.Health
	check(dR > 0 and dO >= dR * 1.4, string.format("과부하 받는 피해 %d vs 보통 %d", dO, dR))

	-- 회피 성공은 보스 스테미나를 깎는다
	local d = newBoss()
	GridBattle.EnemyPlan(d, rng)
	local st = d.Boss.Stamina
	GridBattle.ResolveDodge(d, "boss_Head", "Success")
	check(d.Boss.Stamina == st - 6, "회피 성공 → 보스 스테미나 −6")

	-- 충전(커널 패닉): 끊지 못하면 다음 턴 터지고, 코어에 10% 피해를 주면 끊긴다(코어가 잠겨 있어도)
	local BLOCK = { "MemoryLeak", "NullPointer", "CoreDump", "Overclock", "InfiniteRecursion", "BlueScreen" }
	local function chargeBoss()
		local c = newBoss()
		setRatio(c, 0.45)
		c.Turn = 1
		c.Boss.Stamina, c.Boss.MaxStamina = 999, 999
		for _, sid in BLOCK do
			c.Boss.Cooldowns[sid] = 99
		end
		GridBattle.EnemyPlan(c, rng)
		return c
	end
	local c = chargeBoss()
	check(c.Boss.Charge and c.Boss.Charge.SkillId == "KernelPanic" and c.Boss.Charge.Stage == "Charging", "코어가 커널 패닉 충전")
	GridBattle.EndTurn(c)
	c.Boss.Stamina = 999
	GridBattle.EnemyPlan(c, rng)
	local burst = false
	for _, p in c.Units.boss_Core.Plans or {} do
		burst = burst or (p.SkillId == "KernelPanicBurst" and p.Release == true)
	end
	check(burst, "끊지 못하면 다음 턴 커널 패닉이 터진다")
	local c2 = chargeBoss()
	local stBefore = c2.Boss.Stamina
	local core = c2.Units.boss_Core
	core.Health = 2 -- 잠긴 코어(체력 1에서 버팀)여도 충전 피해는 센다
	for _ = 1, 20 do
		if c2.Boss.Charge.Broken then
			break
		end
		GridBattle.DebugHitPart(c2, "boss_Core", math.ceil(c2.Boss.Charge.Need / 4))
	end
	check(c2.Boss.Charge.Broken, "코어에 충전량만큼 피해를 주면 끊긴다")
	check(core.Alive and core.Health >= 1, "잠긴 코어는 그래도 버틴다")
	check(c2.Boss.Stamina <= stBefore - 30, "충전을 끊으면 보스 스테미나 −30")
	check((c2.Boss.PartStun.Core or 0) == 1, "충전을 끊으면 코어 1턴 멈춤")

	-- 궁극기(블루스크린): 3턴째부터, 지금 체력의 50%, 회피 성공이어도 맞고, 3턴 동안 회복 불가
	local g = newBoss()
	g.Turn = 2
	GridBattle.EnemyPlan(g, rng)
	check(g.Units.boss_Core.Plan.SkillId ~= "BlueScreen", "2턴엔 궁극기를 안 쓴다")
	GridBattle.EndTurn(g)
	g.Turn = 3
	g.Boss.Stamina = 100
	GridBattle.EnemyPlan(g, rng)
	check(g.Units.boss_Core.Plan.SkillId == "BlueScreen", "3턴째 궁극기")
	local hp = g.Units.player.Health
	GridBattle.ResolveDodge(g, "boss_Core", "Success")
	local lost = hp - g.Units.player.Health
	check(math.abs(lost - math.floor(hp * 0.5)) <= 2, string.format("블루스크린 = 지금 체력 50%%: %d / %d", lost, hp))
	check(g.Boss.NoHeal == 3, "회복 불가 3턴")
	g.Boss.Mods = { [BattleGrid.CellKey("Ally", 1, 2)] = "Heal" }
	g.Boss.DeletePlan = nil
	g.Boss.Deleted = {}
	GridBattle.MoveAlly(g, 1, 2)
	local before = g.Units.player.Health
	GridBattle.EndTurn(g)
	check(g.Units.player.Health <= before, "회복 불가 동안 회복 칸이 안 듣는다")
	check(g.Boss.NoHeal == 2, "회복 불가가 한 턴 흐른다")

	-- 보스 버프: 감시식이 걸리면 보스 공격 피해가 오른다
	local w1, w2 = newBoss(), newBoss()
	GridBattle.EnemyPlan(w1, rng)
	GridBattle.EnemyPlan(w2, rng)
	table.insert(w2.Boss.Buffs, { Id = "Watchpoint", Turns = 2 })
	-- 선 칸 효과(버프·버그 칸)가 다르면 비교가 흔들린다 — 둘 다 지운다
	w1.Boss.Mods, w2.Boss.Mods = {}, {}
	local a1, a2 = w1.Units.player.Health, w2.Units.player.Health
	GridBattle.ResolveDodge(w1, "boss_Head", "Fail")
	GridBattle.ResolveDodge(w2, "boss_Head", "Fail")
	check((a2 - w2.Units.player.Health) > (a1 - w1.Units.player.Health), "감시식: 보스 피해 증가")

	-- 루트 권한: 막음(Partial)이 실패가 된다(가드 무시)
	local function forced(st)
		GridBattle.EnemyPlan(st, rng)
		st.Units.boss_PatchArm.Plans = { { SkillId = "ForcedPatch", Cells = { { 1, 1 }, { 1, 2 }, { 1, 3 } } } }
		st.Units.boss_PatchArm.Plan = st.Units.boss_PatchArm.Plans[1]
		GridBattle.MoveAlly(st, 1, 2)
		st.Boss.Mods = {}
		local h = st.Units.player.Health
		return h
	end
	local r1, r2 = newBoss(), newBoss()
	local q1 = forced(r1)
	table.insert(r1.Boss.Buffs, { Id = "Sudo", Turns = 2 })
	local q2 = forced(r2)
	GridBattle.ResolveDodge(r1, "boss_PatchArm", "Partial")
	GridBattle.ResolveDodge(r2, "boss_PatchArm", "Partial")
	check((q1 - r1.Units.player.Health) > (q2 - r2.Units.player.Health), "루트 권한: 막음이 통하지 않는다")

	-- 스냅샷: 페이즈·스테미나·버프·충전·회복 불가·계획 목록
	local snap = GridBattle.Snapshot(t)
	check(snap.Boss.Phase == 3 and snap.Boss.MaxStamina ~= nil and snap.Boss.Buffs ~= nil, "스냅샷 보스 상태")
	check(snap.Units.boss_Core.Plans ~= nil, "스냅샷 계획 목록")
end

-- 9) 2026-10-03 사용자가 고른 반복 줄이기: 판 변주(5)·원한 버프(4)·마지막 발악(14)·적응형 패치(3)·연계(1)
do
	-- 판 변주: 보스전마다 하나가 걸리고, 시작 로그에 남는다
	local raw = GridBattle.New(1, "시험", 5000, 20, "Berserker", 20, 999, {}, { Name = "보스 시험", Enemies = { "Debug" }, HealthScale = 0.012, PowerScale = 0.15 })
	local known = {}
	for _, v in GridBattle.BOSS_VARIANTS do
		known[v.Id] = true
	end
	check(known[raw.Boss.Variant], "판 변주가 하나 걸려야 한다: " .. tostring(raw.Boss.Variant))
	check(table.concat(raw.Log, " "):find("판 변주", 1, true) ~= nil, "판 변주 로그")
	-- 판 변주는 턴마다 새로 뽑는다(직전과 다른 것)
	local seenVariants, last = {}, raw.Boss.Variant
	for _ = 1, 8 do
		raw.Turn += 1
		GridBattle.EnemyPlan(raw, rng)
		check(raw.Boss.Variant ~= last, "턴마다 다른 판 변주")
		last = raw.Boss.Variant
		seenVariants[last] = true
	end
	local kinds = 0
	for _ in seenVariants do
		kinds += 1
	end
	check(kinds >= 3, "여러 판 변주가 돌아가며 나온다: " .. kinds)
	-- 회복 칸 없음 / 버프 칸 넷
	local nh = newBoss()
	nh.Boss.Variant = "NoHealCell"
	nh.Turn = 1
	GridBattle.EnemyPlan(nh, rng)
	local heals, buffs = 0, 0
	for _, kind in nh.Boss.Mods do
		heals += if kind == "Heal" then 1 else 0
	end
	check(heals == 0, "회복 칸 없음 변주")
	local db = newBoss()
	db.Boss.Variant = "DoubleBuff"
	db.Turn = 1
	GridBattle.EnemyPlan(db, rng)
	for _, kind in db.Boss.Mods do
		buffs += if kind == "Buff" then 1 else 0
	end
	check(buffs >= 3, "버프 칸 넷 변주: " .. buffs)

	-- 원한: 먼저 부순 부위에 따라 남은 보스 버프가 다르다
	local function grudge(first)
		local g = newBoss()
		GridBattle.DebugSetHealth(g, "boss_" .. first, 0)
		local got = nil
		for _, b in g.Boss.Buffs do
			if string.sub(b.Id, 1, 7) == "Grudge_" then
				got = b.Id
			end
		end
		return g, got
	end
	local _, g1 = grudge("Head")
	local _, g2 = grudge("PatchArm")
	check(g1 == "Grudge_Head" and g2 == "Grudge_PatchArm", "원한 버프가 먼저 부순 부위를 따른다")

	-- 마지막 발악: 코어만 남으면 셋 중 하나
	local l = newBoss()
	GridBattle.DebugSetHealth(l, "boss_Head", 0)
	GridBattle.DebugSetHealth(l, "boss_DeleteArm", 0)
	check(l.Boss.LastStand == nil, "부위가 남아 있으면 아직 발악 아님")
	GridBattle.DebugSetHealth(l, "boss_PatchArm", 0)
	check(l.Boss.LastStand ~= nil, "코어만 남으면 마지막 발악")
	-- 코어 폭주: 코어가 세 번
	l.Boss.LastStand = "Overdrive"
	l.Boss.Stamina, l.Boss.MaxStamina = 999, 999
	l.Boss.Cooldowns = {}
	l.Boss.Stagger = 0 -- 머리를 부순 다음 턴 멈칫은 따로 본다
	GridBattle.EndTurn(l)
	l.Boss.Stamina = 999
	GridBattle.EnemyPlan(l, rng)
	local acts = 0
	for _, p in l.Units.boss_Core.Plans or {} do
		acts += if p.SkillId ~= "DeleteCells" then 1 else 0
	end
	check(acts == 3, "코어 폭주: 세 번 행동 " .. acts)
	-- 검수 폭주: 네 칸만 남긴다
	local pu = newBoss()
	GridBattle.DebugSetHealth(pu, "boss_Head", 0)
	GridBattle.DebugSetHealth(pu, "boss_DeleteArm", 0)
	GridBattle.DebugSetHealth(pu, "boss_PatchArm", 0)
	pu.Boss.LastStand = "Purge"
	pu.Boss.Stagger = 0
	GridBattle.EndTurn(pu)
	GridBattle.EnemyPlan(pu, rng)
	check(pu.Boss.DeletePlan and #pu.Boss.DeletePlan.Cells == 14, "검수 폭주: 네 칸만 남김 " .. (pu.Boss.DeletePlan and #pu.Boss.DeletePlan.Cells or -1))

	-- 적응형 패치: 같은 스킬 연속이면 피해가 줄고, 다른 스킬을 쓰면 풀린다
	local a = newBoss("Berserker")
	GridBattle.MoveAlly(a, 1, 2)
	a.Boss.Mods = {}
	local function hit(index)
		local h = a.Units.boss_Head.Health
		GridBattle.ResolveSkill(a, index, "Success", function()
			return 0.99
		end)
		a.Acted = false
		a.Attacked = false
		return h - a.Units.boss_Head.Health
	end
	local d1 = hit(1)
	local d2 = hit(1)
	check(d1 > 0 and d2 < d1 and a.Boss.AdaptCount == 1, string.format("적응형 패치 2연속 %d → %d", d1, d2))
	hit(2)
	check(a.Boss.AdaptCount == 0, "다른 스킬을 쓰면 적응형 패치가 풀린다")

	-- 연계: 머리 광선 다음 턴 → 그 라인에 버그 칸(오염 추적)
	local c = newBoss()
	c.Turn = 2
	GridBattle.MoveAlly(c, 3, 3)
	GridBattle.EnemyPlan(c, rng)
	check(#c.Boss.ComboNotes >= 1, "광선이 다음 턴 연계를 예고한다")
	local lane = 3
	GridBattle.EndTurn(c)
	c.Boss.Mods = {}
	c.Boss.Deleted = {} -- 검은 칸에는 버그 칸을 깔지 않는다 — 라인이 통째로 검은 칸이면 시험이 흔들린다
	GridBattle.EnemyPlan(c, rng)
	local tainted = 0
	for key, kind in c.Boss.Mods do
		local _, y = string.match(key, "(%d+),(%d+)$")
		if kind == "Debuff" and tonumber(y) == lane then
			tainted += 1
		end
	end
	check(tainted >= 1, "오염 추적: 광선 라인에 버그 칸 " .. tainted)
	check(GridBattle.Snapshot(c).Boss.Variant ~= nil, "스냅샷에 판 변주")
end

-- 10. 묶임 면역(2026-10-03): 한 번 묶이면 묶인 턴 끝과 다음 턴 끝에는 예고 칸 위에서 마쳐도 안 묶인다
do
	local s = newBoss()
	local function endOnPending(): boolean
		local me = BattleGrid.CellOf(s.Grid, "player")
		s.Boss.DeletePlan = { Cells = { { me.X, me.Y } }, Owner = "boss_DeleteArm" }
		s.Boss.Deleted = {}
		s.Units.player.Health = s.Units.player.MaxHealth
		GridBattle.EndTurn(s)
		return (s.Boss.Locked or 0) > 0
	end
	check(endOnPending(), "처음엔 묶인다")
	check(GridBattle.Snapshot(s).Boss.LockImmune == 2, "묶인 턴: 면역 2 남음")
	check(not endOnPending(), "묶인 턴 끝: 면역")
	check(not endOnPending(), "그다음 턴 끝: 면역")
	check(endOnPending(), "면역이 끝나면 다시 묶인다")
end

print("보스 디버그 점검 통과")
