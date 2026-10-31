--[[
	callisto_test.luau — 히든 보스 칼리스토 규칙 점검(2026-10-31). 서버 판정(GridBattle)만 돌린다.
	  lune run tools/callisto_test.luau
	실패하면 오류로 끝난다. 사양(사용자 2026-10-31)과 GridBattle "보스: 칼리스토" 절의 정한 박자를 본다.
]]
local loadShared = require("./lune_env")

local BattleStatus = loadShared("BattleStatus")
local GridBattle = loadShared("GridBattle")
local BattleGrid = loadShared("BattleGrid")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local seed = 11
local function rng(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

local function battle(scale: number?)
	return GridBattle.New(1, "시험", 5000, 20, "Berserker", 20, 999, {}, { Name = "칼리스토 시험", Enemies = { "Callisto", "Callisto", "Slime" }, HealthScale = scale or 1, PowerScale = 1 })
end

local function boss(s): any
	return s.Units[s.Callisto.UnitId]
end

-- 이번 턴 예고를 전부 맞고(등급) 턴을 넘긴다. 돌려주는 값 = 이번 턴 예고한 스킬 Id 들
local function playTurn(s, grade: string?): { string }
	local used = {}
	GridBattle.EnemyPlan(s, rng)
	for _, t in GridBattle.PlannedThreatList(s) do
		local plan = GridBattle.PlanAt(t.Unit, t.Index)
		table.insert(used, plan.SkillId)
		GridBattle.ResolveDodge(s, t.Unit.Id, (grade or "Fail") :: any, t.Index)
	end
	GridBattle.EndTurn(s)
	return used
end

local function stack(unit, id: string): number
	return BattleStatus.Stack(unit.Status, id)
end

--=== 1. 편성: 혼자 서는 보스, 공격력 0, 사람 모양 Id ===--
do
	local s = battle()
	local enemies = GridBattle.AliveEnemies(s)
	check(#enemies == 1, "칼리스토는 편성에 있으면 혼자 선다 — " .. #enemies)
	local b = boss(s)
	check(b.DefId == "Callisto" and b.Power == 0, "DefId·공격력 0")
	check(b.MaxHealth == 50000, "1페이지 체력 50000 — " .. b.MaxHealth)
	local snap = GridBattle.Snapshot(s)
	check(snap.Callisto and snap.Callisto.Page == 1 and snap.Units[b.Id].DefId == "Callisto", "스냅샷 Callisto·DefId")
	print("1 편성 OK")
end

--=== 2. 1페이지 박자: 사진 → 멱살 → 찌르기(성위 없음) → 베기 → 트로히아(5연타) → 렌즈(성위 6↑) ===--
do
	local s = battle()
	local ally = GridBattle.Ally(s)
	local t1 = playTurn(s)
	check(#t1 == 1 and t1[1] == "CallistoPhoto", "1턴 파라티리시 — " .. table.concat(t1, ","))
	check(stack(ally, ClassResources.GOCHAL) == 1, "고찰이 걸림")
	check(ally.Status.Burn >= 4, "파라티리시 화상 4(+고찰 1) — " .. ally.Status.Burn)
	local t2 = playTurn(s)
	check(t2[1] == "CallistoSymberasma", "2턴 고찰이 있어 심베라즈마 — " .. tostring(t2[1]))
	check(stack(ally, ClassResources.GOCHAL) == 0, "심베라즈마가 고찰을 지움")
	check(stack(ally, ClassResources.SYMBERASMA) > 0, "심베라즈마 디버프")
	local b = boss(s)
	local t3 = playTurn(s)
	-- 연타 무늬가 달라 서 있는 칸에 따라 몇 대 맞는지가 다르다(예고는 늘 3개)
	check(#b.Plans == 3 and #t3 >= 1 and t3[1] == "CallistoSynthesis", "3턴 성위가 없어 신데시 톤 아스트론 3연타 — " .. table.concat(t3, ","))
	local t4 = playTurn(s)
	check(t4[1] == "CallistoSlash", "4턴(짝수 바퀴) 세시 파라티리시 — " .. tostring(t4[1]))
	check(stack(ally, ClassResources.SEONGWI) == 2, "세시 파라티리시 성위 2 — " .. stack(ally, ClassResources.SEONGWI))
	local t5 = playTurn(s)
	check(#b.Plans == 5 and #t5 >= 2 and t5[1] == "CallistoTrohia", "5턴 트로히아 5연타 — 별자리 칸이 아니면 2대 이상 — " .. table.concat(t5, ","))
	check(stack(ally, ClassResources.SEONGWI) == 2 + #t5, "트로히아 타당 성위 1 — " .. stack(ally, ClassResources.SEONGWI))
	check(BattleStatus.Total(ally.Status, "DamageTaken") >= stack(ally, ClassResources.SEONGWI) * 0.01 - 1e-6, "성위 1당 받는 피해 +1%")
	local ripe = stack(ally, ClassResources.SEONGWI) >= 6
	local t6 = playTurn(s)
	check(t6[1] == (if ripe then "CallistoArktos" else "CallistoSynthesis"), "6턴: 성위 6 이상이면 렌즈, 아니면 찌르기 — " .. tostring(t6[1]))
	if ripe then
		check(stack(ally, ClassResources.SEONGWI) == 0 and stack(ally, ClassResources.MUTBYEOL) > 0, "렌즈가 성위를 뭇별로 바꿈")
	end
	print("2 1페이지 박자 OK")
end

--=== 3. 회피하면 안 걸리고, 회피 불가는 늘 걸린다 · 성위 15 → 뭇별 ===--
do
	local s = battle()
	local ally = GridBattle.Ally(s)
	playTurn(s, "Success") -- 사진(회피 불가)
	check(stack(ally, ClassResources.GOCHAL) == 1, "회피 불가 사진은 QTE 성공이어도 걸림")
	playTurn(s, "Success")
	playTurn(s, "Success") -- 찌르기 3연타 전부 회피
	playTurn(s, "Success") -- 베기 회피
	check(stack(ally, ClassResources.SEONGWI) == 0, "회피한 베기는 성위를 안 검")
	local last = s.Events[#s.Events]
	check(last.Kind == "EnemyAttack" and last.Hits[1][1].Damage == 0, "회피하면 피해 없음")
	-- 성위 15 → 뭇별(직접)
	local s2 = battle()
	local a2 = GridBattle.Ally(s2)
	a2.Status.Stacks[ClassResources.SEONGWI] = 14
	local b2 = boss(s2)
	b2.Plans = { { SkillId = "CallistoTrohia", Cells = { { 1, 2 } } } }
	b2.Plan = b2.Plans[1]
	s2.Planned = { b2.Id }
	GridBattle.ResolveDodge(s2, b2.Id, "Fail", 1)
	check(stack(a2, ClassResources.SEONGWI) == 0 and stack(a2, ClassResources.MUTBYEOL) == 5, "성위 15 → 뭇별 5턴")
	check(BattleStatus.Total(a2.Status, "DamageDealt") <= -0.1 + 1e-6, "뭇별 공격력 −10%")
	for _ = 1, 5 do
		GridBattle.EndTurn(s2)
	end
	check(stack(a2, ClassResources.MUTBYEOL) == 0 and BattleStatus.Total(a2.Status, "DamageDealt") > -0.05, "뭇별은 5턴 뒤 사라짐")
	print("3 회피·성위→뭇별 OK")
end

--=== 4. 작은 곰 자리 → 바퀴 끝 아스트로 세시 ===--
do
	local s = battle()
	local b = boss(s)
	b.Health = math.floor(b.MaxHealth * 0.4)
	playTurn(s) -- 턴 끝에 작은 곰 자리
	check(stack(b, ClassResources.URSA_MINOR) == 1, "체력 50% 미만이면 작은 곰 자리")
	local seen = {}
	for _ = 1, 8 do
		for _, id in playTurn(s) do
			seen[id] = true
		end
	end
	check(seen.CallistoAstro, "작은 곰 자리면 아스트로 세시를 씀")
	print("4 작은 곰 자리 OK")
end

--=== 5. 페이지 넘김(2페이지 사양 없음 → 3), 장판 10턴, 시험 종료 ===--
do
	local s = battle()
	local b = boss(s)
	local ally = GridBattle.Ally(s)
	GridBattle.DebugHitPart(s, b.Id, 999999)
	check(b.Alive and s.Callisto.Page == 2 and b.MaxHealth == 200000 and b.Health == 200000, "1페이지가 다하면 2페이지 체력 200000 — " .. s.Callisto.Page .. " " .. b.Health)
	GridBattle.DebugHitPart(s, b.Id, 999999)
	check(b.Alive and s.Callisto.Page == 3 and b.MaxHealth == 300000 and b.Health == 300000, "2페이지가 다하면 3페이지 체력 300000 — " .. s.Callisto.Page .. " " .. b.Health)
	check(s.Outcome == "Ongoing", "페이지 넘김은 승리가 아님")
	GridBattle.EndTurn(s)
	local first = playTurn(s)
	check(first[1] == "CallistoSubmerge", "3페이지 첫 턴 뭇별 아래에 잠기리 — " .. tostring(first[1]))
	check(s.Callisto.Field == 9, "장판 남은 9턴(깐 턴 포함 10) — " .. s.Callisto.Field)
	check(b.Health == 270000, "잠기리로 칼리스토 10% — " .. b.Health)
	local order = {}
	for i = 1, 12 do
		if s.Outcome ~= "Ongoing" then
			break
		end
		ally.Health = ally.MaxHealth
		local used = playTurn(s, "Success")
		table.insert(order, used[1] or "-")
		if i <= 3 then
			check(used[1] ~= "CallistoSubmerge", "잠기리는 한 번만")
		end
	end
	check(order[1] == "CallistoArtificial" and order[2] == "CallistoShower" and order[3] == "CallistoResonance", "3페이지 박자 — " .. table.concat(order, ","))
	check(s.Outcome == "Victory" and not b.Alive, "장판 10턴이면 칼리스토 체력 1% 이하 → 시험 종료 — " .. s.Outcome .. " " .. b.Health)
	print("5 페이지·장판·시험 종료 OK — " .. table.concat(order, ","))
end

--=== 6. 그날의 기억: 화상 피해 ×2 ===--
do
	local s = battle()
	local b = boss(s)
	BattleStatus.AddBurn(b.Status, 10)
	local before = b.Health
	GridBattle.EndTurn(s)
	local lost = before - b.Health
	check(lost == 10000, "화상 10 = 최대 체력 10% ×2 = 10000 — " .. lost)
	print("6 그날의 기억 OK")
end

--=== 7. 결투사(회피 없이 패리만)도 끝까지 돈다 ===--
do
	local s = GridBattle.New(1, "시험", 5000, 20, "Duelist", 20, 999, {}, { Name = "칼리스토 시험", Enemies = { "Callisto" }, HealthScale = 0.01, PowerScale = 1 })
	for _ = 1, 30 do
		if s.Outcome ~= "Ongoing" then
			break
		end
		local ally = GridBattle.Ally(s)
		ally.Health = ally.MaxHealth
		GridBattle.DebugHitPart(s, s.Callisto.UnitId, 200)
		playTurn(s, if rng() < 0.5 then "Success" else "Partial")
	end
	check(s.Callisto.Page == 3, "축소 체력으로 3페이지까지 감")
	print("7 결투사 OK")
end

--=== 8. 2페이지 성위 품은 자: 소환·미자르·알리오스 장판·타들어가는 성위·칠성 일곱 별 → 북두칠성·점멸 ===--
local function toPage2(scale: number?)
	local s = battle(scale)
	GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
	check(s.Callisto.Page == 2, "2페이지로")
	GridBattle.EndTurn(s)
	return s
end
do
	local s = toPage2()
	local b = boss(s)
	local ally = GridBattle.Ally(s)
	local t1 = playTurn(s)
	check(#t1 == 0, "2페이지 첫 턴은 소환(예고 칸 없음) — " .. table.concat(t1, ","))
	local alcor = s.Units[s.Callisto.AlcorId :: string]
	check(alcor and alcor.Alive and alcor.DefId == "Alcor" and alcor.MaxHealth == 20000, "알코르 소환(체력 2페이지의 10%)")
	check(stack(ally, ClassResources.ALKAID) == 1, "알코르를 못 잡아 미자르 → 알카이드 1 — " .. stack(ally, ClassResources.ALKAID))
	local t2 = playTurn(s)
	check(t2[1] == "CallistoAlioth", "다음은 알리오스 — " .. tostring(t2[1]))
	check(s.Callisto.Aliot == 4, "알리오스 장판 5턴(이번 턴 끝에 하나) — " .. s.Callisto.Aliot)
	check(stack(ally, ClassResources.DUBHE) >= 1 and stack(ally, ClassResources.SEONGWI) >= 2, "장판: 두베 1 · 성위 2")
	-- 타들어가는 성위: 화상 → 알카이드 1 + 두베 1
	BattleStatus.AddBurn(ally.Status, 9)
	local alk, dub = stack(ally, ClassResources.ALKAID), stack(ally, ClassResources.DUBHE)
	GridBattle.EnemyPlan(s, rng)
	s.Planned = {}
	GridBattle.EndTurn(s)
	check(ally.Status.Burn == 0, "화상이 사라짐 — " .. ally.Status.Burn)
	check(stack(ally, ClassResources.ALKAID) >= alk + 1 and stack(ally, ClassResources.DUBHE) >= dub + 1, "알카이드·두베가 오름")
	check(BattleStatus.Total(ally.Status, "DamageTaken") >= stack(ally, ClassResources.DUBHE) * 0.02 - 1e-6, "두베 1당 받는 피해 +2%")
	-- 알코르를 잡으면 미자르가 사라지고 승리 판정에 안 셈
	GridBattle.DebugHitPart(s, alcor.Id, 999999)
	GridBattle.EndTurn(s)
	check(stack(ally, ClassResources.MIZAR) == 0, "알코르가 쓰러지면 미자르 사라짐")
	-- 칼리스토가 쓰러지면 알코르가 남아 있어도 승리
	local s2 = toPage2(0.01)
	playTurn(s2)
	check(s2.Callisto.AlcorId and s2.Units[s2.Callisto.AlcorId].Alive, "알코르 살아 있음")
	GridBattle.DebugSetHealth(s2, s2.Callisto.UnitId, 0)
	check(s2.Outcome == "Victory", "소환체만 남으면 승리 — " .. s2.Outcome)
	-- 2 → 3 넘어가면 알코르 사라짐
	local s3 = toPage2()
	playTurn(s3)
	local id3 = s3.Callisto.AlcorId :: string
	GridBattle.DebugHitPart(s3, s3.Callisto.UnitId, 999999)
	check(s3.Callisto.Page == 3 and not s3.Units[id3].Alive and stack(GridBattle.Ally(s3), ClassResources.MIZAR) == 0, "3페이지로 가면 알코르·미자르 거둠")
	print("8 2페이지 소환·미자르·장판·타들어가는 성위 OK")
end

--=== 9. 칠성군(65% 미만): 일곱 별 → 메갈리 아르크토스 → 북두칠성, 쓰면 초기화 · 점멸 ===--
do
	local s = toPage2()
	local b = boss(s)
	b.Health = math.floor(b.MaxHealth * 0.6)
	local order = {}
	local dipperAt = nil
	for turn = 1, 30 do
		local ally = GridBattle.Ally(s)
		ally.Health = ally.MaxHealth
		local used = playTurn(s, "Partial")
		table.insert(order, used[1] or "소환")
		if used[1] == "CallistoDipper" and not dipperAt then
			dipperAt = turn
			-- 쓰면 초기화(같은 턴 끝 미자르·장판으로 새 바퀴 별이 몇 개 켜질 수는 있다)
			check(stack(b, ClassResources.SEVEN) < 7 and not s.Callisto.Dipper, "북두칠성을 쓰면 칠성 초기화 — " .. stack(b, ClassResources.SEVEN))
		end
		-- 알코르를 잡아 소환이 다시 돌게
		if s.Callisto.AlcorId and s.Units[s.Callisto.AlcorId].Alive and turn % 3 == 0 then
			GridBattle.DebugHitPart(s, s.Callisto.AlcorId, 999999)
		end
	end
	check(dipperAt ~= nil, "일곱 별이 다 빛나 북두칠성을 씀 — " .. table.concat(order, ","))
	print("9 칠성 → 북두칠성 OK (" .. tostring(dipperAt) .. "턴째) — " .. table.concat(order, ",", 1, math.min(#order, 10)))
	-- 점멸: 회피 가능한 공격을 전부 피하면 쌓인다
	local s2 = toPage2()
	local b2 = boss(s2)
	local blink = 0
	for _ = 1, 8 do
		playTurn(s2, "Success")
		blink = stack(b2, ClassResources.BLINK)
	end
	check(blink > 0, "다 피하면 [성위 - 점멸] — " .. blink)
	print("9 점멸 OK (" .. blink .. ")")
end

--=== 10. 유도: 별자리 칸·연타 무늬·추적 행열·비숍 대각 이동·심베라즈마 내던지기 ===--
do
	local function has(cells, x, y)
		for _, c in cells do
			if c[1] == x and c[2] == y then
				return true
			end
		end
		return false
	end
	local pocketSeen, strikeSeen = 0, 0
	for trial = 1, 12 do
		local s = battle()
		local b = boss(s)
		local ally = GridBattle.Ally(s)
		for _ = 1, trial % 6 do
			playTurn(s)
		end
		ally.Health = ally.MaxHealth
		local before = BattleGrid.CellOf(s.Grid, b.Id)
		GridBattle.EnemyPlan(s, rng)
		local after = BattleGrid.CellOf(s.Grid, b.Id)
		if before and after then
			local dx, dy = math.abs(after.X - before.X), math.abs(after.Y - before.Y)
			check(dx == dy, string.format("비숍처럼 대각선으로만 — (%d,%d)→(%d,%d)", before.X, before.Y, after.X, after.Y))
		end
		local here = BattleGrid.CellOf(s.Grid, GridBattle.ALLY_ID)
		local lure = s.Callisto.Lure
		local plans = b.Plans or {}
		if lure and #plans > 0 and here then
			local l = lure[1]
			check(math.abs(l[1] - here.X) + math.abs(l[2] - here.Y) >= 3, "별자리 칸은 아군 자리에서 3칸 이상")
			-- 칸마다 맞는 횟수: 별자리 칸이 가장 적고, 빈칸이 없다
			local hitsAt = function(x, y)
				local n = 0
				for _, p in plans do
					if has(p.Cells, x, y) then
						n += 1
					end
				end
				return n
			end
			local lureHits = hitsAt(l[1], l[2])
			for x = 1, 6 do
				for y = 1, 3 do
					if not has(lure, x, y) then
						check(hitsAt(x, y) > lureHits, string.format("별자리 칸이 아닌 (%d,%d) 는 더 맞는다", x, y))
					end
				end
			end
			if #plans > 1 then
				strikeSeen += 1
			else
				pocketSeen += 1
			end
			-- 별자리 칸으로 옮기면: 맞는 횟수가 가장 적고 턴 끝에 성위
			GridBattle.MoveAlly(s, l[1], l[2])
			local threats = #GridBattle.PlannedThreatList(s)
			check(threats == lureHits, "별자리 칸에서는 그 칸 몫만 맞는다")
			local sw = stack(ally, ClassResources.SEONGWI) + stack(ally, ClassResources.MUTBYEOL) * 100
			for _, t in GridBattle.PlannedThreatList(s) do
				GridBattle.ResolveDodge(s, t.Unit.Id, "Success", t.Index)
			end
			GridBattle.EndTurn(s)
			local now = stack(ally, ClassResources.SEONGWI) + stack(ally, ClassResources.MUTBYEOL) * 100
			check(now > sw, "별자리 칸에서 턴을 마치면 성위")
		end
	end
	check(pocketSeen > 0 and strikeSeen > 0, string.format("한 방·연타 유도 둘 다 나옴(%d · %d)", pocketSeen, strikeSeen))
	-- 추적: 메라크(행)·페크다(열)는 어디 서도 닿는다
	local s = toPage2()
	local b = boss(s)
	b.Plans = { { SkillId = "CallistoMerak", Cells = {}, Track = "Row" } }
	s.Callisto.Cooldowns = { CallistoAlcor = 9, CallistoAlioth = 9, CallistoPhecda = 9 }
	s.Callisto.Aliot = 3
	s.Callisto.AlcorId = nil
	-- 알코르가 있어 소환은 건너뛰게
	GridBattle.EnemyPlan(s, rng)
	if b.Plans and b.Plans[1].SkillId == "CallistoMerak" then
		for x = 1, 6 do
			GridBattle.MoveAlly(s, x, (x % 3) + 1)
			check(#GridBattle.PlannedThreatList(s) == 1, "메라크는 서 있는 행을 노린다(어디 서도 닿음)")
		end
	end
	-- 심베라즈마: 3칸 넘게 내던진다
	local s2 = battle()
	playTurn(s2)
	local from = BattleGrid.CellOf(s2.Grid, GridBattle.ALLY_ID)
	local used = playTurn(s2)
	local to = BattleGrid.CellOf(s2.Grid, GridBattle.ALLY_ID)
	if used[1] == "CallistoSymberasma" and from and to then
		check(math.abs(to.X - from.X) + math.abs(to.Y - from.Y) >= 3, "심베라즈마가 멀리 내던짐")
	end
	print(string.format("10 유도 OK (한 방 %d · 연타 %d)", pocketSeen, strikeSeen))
end

print("칼리스토 규칙: 모두 통과")
