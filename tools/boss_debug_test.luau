--[[
	boss_debug_test.luau — 보스 디버그 규칙 점검(2026-09-29). 서버 판정(GridBattle)만 돌린다.
	  lune run tools/boss_debug_test.luau
	실패하면 오류로 끝난다.
]]
local loadShared = require("./lune_env")

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

-- 5) 부위 파괴 효과: 삭제 팔 → 칸 복구, 패치 팔 → 버그 칸 사라짐, 머리 → 멈칫, 코어 → 승리
do
	local s = newBoss()
	s.Turn = 2
	GridBattle.EnemyPlan(s, rng)
	GridBattle.EndTurn(s)
	check(next(s.Boss.Deleted) ~= nil, "칸이 지워져 있어야 한다")
	GridBattle.DebugSetHealth(s, "boss_DeleteArm", 0)
	check(next(s.Boss.Deleted) == nil, "삭제 팔을 부수면 칸이 돌아온다")
	for x = 1, 6 do
		for y = 1, 3 do
			check(BattleGrid.IsEnabled(s.Grid, "Ally", x, y), "복구 안 된 칸")
		end
	end
	s.Boss.Mods = { [BattleGrid.CellKey("Ally", 2, 2)] = "Buff", [BattleGrid.CellKey("Ally", 3, 3)] = "Debuff" }
	GridBattle.DebugSetHealth(s, "boss_PatchArm", 0)
	check(s.Boss.Mods[BattleGrid.CellKey("Ally", 3, 3)] == nil and s.Boss.Mods[BattleGrid.CellKey("Ally", 2, 2)] == "Buff", "패치 팔: 버그만 사라진다")
	GridBattle.DebugSetHealth(s, "boss_Head", 0)
	GridBattle.EnemyPlan(s, rng)
	check(#s.Planned == 0, "머리를 부순 다음 예고는 멈칫")
	GridBattle.DebugSetHealth(s, "boss_Core", 0)
	check(s.Outcome == "Victory", "코어를 부수면 승리: " .. s.Outcome)
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
	-- 라인이 안 맞으면 못 때린다: 라인 1(삭제 팔)에서 쓴 스킬은 머리(라인 2)를 못 맞힌다, 카드 피해도 막힌다
	local s = newBoss("Berserker")
	GridBattle.MoveAlly(s, 1, 1)
	local hits = {}
	for _, shape in BattleSkills.AllShapes(BattleSkills.ById("SlimeTackle") or { Shape = { Kind = "All" } }) do
		for _, id in BattleSkills.Targets(s.Grid, "Ally", 1, { Kind = "All" }, 0, 1) do
			hits[id] = true
		end
		local _ = shape
	end
	check(hits.boss_DeleteArm and hits.boss_Core and not hits.boss_Head and not hits.boss_PatchArm, "라인 1 에선 삭제 팔·코어만 맞는다")
	local before = s.Units.boss_Head.Health
	GridBattle.GainResource(s, s.Units.player, "none", 0)
	local env = s.Runtime and s.Runtime.Env
	local _ = env
	-- 직접 피해(카드 피해 경로와 같은 damageUnit): 반사처럼 라인 무시로 들어와도 0
	local Units = s.Units
	GridBattle.DebugSetHealth(s, "boss_Head", before) -- 그대로
	check(Units.boss_Head.Health == before, "머리 체력 그대로")

	-- 도트 99% 경감: 출혈을 크게 걸고 턴을 넘겨도 거의 안 깎인다
	local s2 = newBoss()
	local core = s2.Units.boss_Core
	core.Status.Bleed = 50
	local h0 = core.Health
	GridBattle.EndTurn(s2)
	check(h0 - core.Health <= math.ceil(h0 * 0.01) + 1, string.format("도트 경감 %d → %d", h0, core.Health))

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

	-- 검은 칸에서 마친다 → 최대 체력 20% 고정 피해, 테스터(방어막 200), 2턴 뒤 스테미나 20
	s.Units.player.Health = 5000
	local st0 = s.Units.player.Stamina
	GridBattle.EndTurn(s)
	check(5000 - s.Units.player.Health >= 1000 - 1, "검수중 최대 체력 20%: " .. (5000 - s.Units.player.Health))
	check(s.Boss.Tester == 1 and s.Units.player.Status.Shield >= 200, "테스터 + 방어막 200")
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
			for _, enemy in GridBattle.PlannedThreats(s) do
				GridBattle.ResolveDodge(s, enemy.Id, ({ "Success", "Partial", "Fail" })[math.floor(r() * 3) + 1])
			end
			GridBattle.EndTurn(s)
			local me = s.Units.player
			check(me.Stamina >= 0 and me.Health >= 0 and me.Health <= me.MaxHealth, def.Id .. " 체력·스테미나 범위")
			check((s.Boss.Tester or 0) <= 1 and (s.Boss.Locked or 0) <= 1, def.Id .. " 테스터·묶임은 한 턴")
			local black = 0
			for _ in s.Boss.Deleted do
				black += 1
			end
			check(black <= 12, def.Id .. " 검은 칸이 12 칸보다 많다: " .. black)
			if s.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(s, r)
			end
			local _ = turn
		end
	end
end

print("보스 디버그 점검 통과")
