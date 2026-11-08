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
	check(b.MaxHealth == 50000, "1페이즈 체력 50000 — " .. b.MaxHealth)
	local snap = GridBattle.Snapshot(s)
	check(snap.Callisto and snap.Callisto.Page == 1 and snap.Units[b.Id].DefId == "Callisto", "스냅샷 Callisto·DefId")
	print("1 편성 OK")
end

--=== 2. 1페이즈 박자: 사진 → 멱살 → 찌르기(성위 없음) → 베기 → 트로히아(5연타) → 렌즈(성위 6↑) ===--
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
	check(#b.Plans == 1 and #t3 >= 1 and t3[1] == "CallistoSynthesis", "3턴 성위가 없어 신데시 톤 아스트론(2026-11-08 한 번만) — " .. table.concat(t3, ","))
	-- 2026-11-06 궁극기 보장: 4번째 턴은 첫 바퀴 끝의 아스트로 세시(바퀴 순서는 그대로 이어진다)
	playTurn(s)
	check(b.Plan and b.Plan.SkillId == "CallistoAstro" and s.Callisto.UltUsed, "4번째 턴 아스트로 세시 보장")
	local t4 = playTurn(s)
	check(t4[1] == "CallistoSlash", "4턴(짝수 바퀴) 세시 파라티리시 — " .. tostring(t4[1]))
	check(stack(ally, ClassResources.SEONGWI) == 2, "세시 파라티리시 성위 2 — " .. stack(ally, ClassResources.SEONGWI))
	local t5 = playTurn(s)
	check(#b.Plans == 1 and #t5 >= 1 and t5[1] == "CallistoTrohia", "5턴 트로히아 한 번(2026-11-08 — 추적, 맞음) — " .. table.concat(t5, ","))
	check(stack(ally, ClassResources.SEONGWI) == 3, "트로히아 성위 1 — " .. stack(ally, ClassResources.SEONGWI))
	check(BattleStatus.Total(ally.Status, "DamageTaken") >= stack(ally, ClassResources.SEONGWI) * 0.01 - 1e-6, "성위 1당 받는 피해 +1%")
	local ripe = stack(ally, ClassResources.SEONGWI) >= 3 -- R1(2026-11-06): 렌즈 문턱 성위 3
	local t6 = playTurn(s)
	check(t6[1] == (if ripe then "CallistoArktos" else "CallistoSynthesis"), "6턴: 성위 3 이상이면 렌즈, 아니면 찌르기 — " .. tostring(t6[1]))
	if ripe then
		check(stack(ally, ClassResources.SEONGWI) == 0 and stack(ally, ClassResources.MUTBYEOL) > 0, "렌즈가 성위를 뭇별로 바꿈")
	end
	-- 2026-11-08 사용자: "x3 … (한 번씩 회피) 있는 스킬들만 한번만 사용하게" — 트로히아·신데시·뭇별은 연타 없이 한 번
	local BS = loadShared("BattleSkills")
	for _, id in { "CallistoTrohia", "CallistoSynthesis", "CallistoShower" } do
		local sk = BS.ById(id)
		check((sk.Strikes or 1) == 1 and not sk.ChainQte and not sk.SameGrade, id .. " 한 번만(연타·연타 QTE 없음)")
	end
	local ts = battle()
	local tb = boss(ts)
	tb.Plans = { { SkillId = "CallistoTrohia", Cells = { { 1, 2 } } } }
	tb.Plan = tb.Plans[1]
	ts.Planned = { tb.Id }
	local before = GridBattle.Ally(ts).Health
	GridBattle.ResolveDodge(ts, tb.Id, "Success", 1)
	check(GridBattle.Ally(ts).Health == before, "트로히아 회피 성공 — 피해 없음")
	print("2 1페이즈 박자 OK")
end

--=== 3. 회피하면 안 걸리고, 회피 불가는 늘 걸린다 · 성위 15 → 뭇별 ===--
do
	local s = battle()
	local ally = GridBattle.Ally(s)
	playTurn(s, "Success") -- 사진(회피 불가)
	check(stack(ally, ClassResources.GOCHAL) == 1, "회피 불가 사진은 QTE 성공이어도 걸림")
	playTurn(s, "Success")
	playTurn(s, "Success") -- 찌르기 회피
	playTurn(s, "Success") -- 아스트로 세시(궁극기 보장 — 회피 불가라 맞는다)
	playTurn(s, "Success") -- 베기 회피
	check(stack(ally, ClassResources.SEONGWI) == 2, "2026-11-06 베기는 가드 QTE(회피 불가) — 성공해도 막기라 성위 2")
	local last = s.Events[#s.Events]
	check(last.Kind == "EnemyAttack" and last.Hits[1][1].Damage > 0 and last.Hits[1][1].Grade == "Partial", "베기는 회피 성공이 막기로 바뀐다")
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

--=== 5. 페이즈 넘김(2페이즈 사양 없음 → 3), 장판 10턴, 시험 종료 ===--
do
	local s = battle()
	local b = boss(s)
	local ally = GridBattle.Ally(s)
	GridBattle.DebugHitPart(s, b.Id, 999999)
	check(b.Alive and s.Callisto.Page == 2 and b.MaxHealth == 200000 and b.Health == 200000, "1페이즈가 다하면 2페이즈 체력 200000 — " .. s.Callisto.Page .. " " .. b.Health)
	GridBattle.DebugHitPart(s, b.Id, 999999)
	check(b.Alive and s.Callisto.Page == 3 and b.MaxHealth == 300000 and b.Health == 300000, "2페이즈가 다하면 3페이즈 체력 300000 — " .. s.Callisto.Page .. " " .. b.Health)
	check(s.Outcome == "Ongoing", "페이즈 넘김은 승리가 아님")
	GridBattle.EndTurn(s)
	local first = playTurn(s)
	check(first[1] == "CallistoSubmerge", "3페이즈 첫 턴 뭇별 아래에 잠기리 — " .. tostring(first[1]))
	check(s.Callisto.Field == 9, "장판 남은 9턴(깐 턴 포함 10) — " .. s.Callisto.Field)
	check(b.Health == 270000, "잠기리로 칼리스토 10% — " .. b.Health)
	local order = {}
	for i = 1, 12 do
		if s.Outcome ~= "Ongoing" then
			break
		end
		ally.Health = ally.MaxHealth
		local used = playTurn(s, "Success")
		table.insert(order, used[1] or (b.Plan and b.Plan.SkillId) or "-") -- 케노스는 빛 칸에 서 있으면 위협이 아니라 used 가 빈다
		if i <= 3 then
			check(used[1] ~= "CallistoSubmerge", "잠기리는 한 번만")
		end
	end
	check(order[1] == "CallistoArtificial" and order[2] == "CallistoShower" and order[3] == "-" and order[4] == "CallistoKenosDive", "3페이즈 박자(잠기리→인위→쏟아지는→체력 70%에서 케노스 도발→다이브) — " .. table.concat(order, ","))
	check(s.Outcome == "Victory" and not b.Alive, "장판 10턴이면 칼리스토 체력 1% 이하 → 시험 종료 — " .. s.Outcome .. " " .. b.Health)
	print("5 페이즈·장판·시험 종료 OK — " .. table.concat(order, ","))
end

--=== 6. 그날의 기억: 화상 피해 ×2 ===--
do
	local s = battle()
	local b = boss(s)
	BattleStatus.AddBurn(b.Status, 10)
	local before = b.Health
	GridBattle.EndTurn(s)
	local lost = before - b.Health
	-- 2026-11-06 화상 공식: 최대 체력 × (2% + 0.1% × 수치) → 수치 10 = 3%
	-- 2026-11-06 개선안 6절: 도트 총합 상한 최대 체력 3%(화상 10 ×2 = 8% → 3% = 1500)
	check(lost == 1500, "화상 10 ×2 = 6% 지만 도트 상한 3% = 1500 — " .. lost)
	-- 출혈은 모두 지금 체력 2%(칼리스토 전용 비율 없음 — 체퍼댐 너프): 출혈 1 = 1000, 상한 3% 안
	local s2 = battle()
	local b2 = boss(s2)
	BattleStatus.AddBleed(b2.Status, 1)
	local before2 = b2.Health
	GridBattle.EndTurn(s2)
	check(before2 - b2.Health == 1000, "칼리스토 출혈 2% — " .. (before2 - b2.Health))
	-- 출혈 + 화상이 같이 와도 총합 3%
	BattleStatus.AddBleed(b2.Status, 5)
	BattleStatus.AddBurn(b2.Status, 10)
	local before3 = b2.Health
	GridBattle.EndTurn(s2)
	check(before3 - b2.Health <= b2.MaxHealth * 0.03 + 1, "출혈+화상 합쳐 3% 이하 — " .. (before3 - b2.Health))
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
	check(s.Callisto.Page == 3, "축소 체력으로 3페이즈까지 감")
	print("7 결투사 OK")
end

--=== 8. 2페이즈 성위 품은 자: 소환·미자르·알리오스 장판·타들어가는 성위·칠성 일곱 별 → 북두칠성·점멸 ===--
local function toPage2(scale: number?)
	local s = battle(scale)
	GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
	check(s.Callisto.Page == 2, "2페이즈로")
	GridBattle.EndTurn(s)
	return s
end
do
	local s = toPage2()
	local b = boss(s)
	local ally = GridBattle.Ally(s)
	local t1 = playTurn(s)
	check(#t1 == 0, "2페이즈 첫 턴은 소환(예고 칸 없음) — " .. table.concat(t1, ","))
	local alcor = s.Units[s.Callisto.AlcorId :: string]
	check(alcor and alcor.Alive and alcor.DefId == "Alcor" and alcor.MaxHealth == 20000, "알코르 소환(체력 2페이즈의 10%)")
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
	check(s3.Callisto.Page == 3 and not s3.Units[id3].Alive and stack(GridBattle.Ally(s3), ClassResources.MIZAR) == 0, "3페이즈로 가면 알코르·미자르 거둠")
	print("8 2페이즈 소환·미자르·장판·타들어가는 성위 OK")
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
		-- 범위를 줄인 북두칠성은 안 맞는 자리면 위협이 아니라 used 가 빈다 — 예고한 스킬을 본다
		local planned = if b.Plans and b.Plans[1] then b.Plans[1].SkillId else nil
		table.insert(order, used[1] or planned or "소환")
		if (used[1] or planned) == "CallistoDipper" and not dipperAt then
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

--=== 10. 추적·별자리 칸(솔로 회복+가호 / 파티 비껴감)·추적 행열·비숍 대각 이동·심베라즈마 내던지기 ===--
do
	local function has(cells, x, y)
		for _, c in cells do
			if c[1] == x and c[2] == y then
				return true
			end
		end
		return false
	end
	local function guarded(unit): boolean
		for _, m in unit.Status.Modifiers do
			if m.Source == "별빛 가호" then
				return true
			end
		end
		return false
	end
	local seekSeen = 0
	for trial = 1, 12 do
		local s = battle()
		local b = boss(s)
		local ally = GridBattle.Ally(s)
		for _ = 1, trial % 6 do
			playTurn(s)
		end
		ally.Health = ally.MaxHealth
		BattleStatus.SpendAll(ally.Status, ClassResources.BIND)   -- 앞 턴 심베라즈마 묶임(질문 6-A)은 이 점검과 상관없다
		local before = BattleGrid.CellOf(s.Grid, b.Id)
		GridBattle.EnemyPlan(s, rng)
		local after = BattleGrid.CellOf(s.Grid, b.Id)
		if before and after then
			-- 질문 5-A: 아무 빈 칸으로(비숍 대각 아님) — 판 안에 있기만 하면 된다
			check(after.X >= 1 and after.X <= 6 and after.Y >= 1 and after.Y <= 3, "칼리스토가 판 안에 선다")
		end
		local here = BattleGrid.CellOf(s.Grid, GridBattle.ALLY_ID)
		local stars = s.Callisto.Lure
		local plans = b.Plans or {}
		-- 추적 공격만(판 전체 공격은 성위를 쓰는 스킬이 섞여 성위 셈이 흔들린다 — 11절에서 따로)
		-- 심베라즈마(2026-11-07 십자 유도기)는 맞으면 내던져 별 칸을 벗어나니 이 성위 셈에서 뺀다
		if stars and #plans > 0 and here and plans[1].Seek and plans[1].SkillId ~= "CallistoSymberasma" then
			seekSeen += 1
			check(#stars == 3 or #stars == 4, "별자리 칸 3~4개 — " .. #stars)
			for _, st in stars do
				check(math.abs(st[1] - here.X) + math.abs(st[2] - here.Y) >= 2, "별자리 칸은 아군 자리·바로 옆이 아니다")
			end
			-- 추적: 별 밖 어느 칸으로 옮겨도 연타가 다 따라온다
			for x = 1, 6 do
				for y = 1, 3 do
					if not has(stars, x, y) then
						GridBattle.MoveAlly(s, x, y)
						check(#GridBattle.PlannedThreatList(s) == #plans, string.format("추적 — (%d,%d) 에서도 다 맞는다", x, y))
					end
				end
			end
			check(not guarded(ally), "별 밖에선 가호 없음")
			-- 솔로 별자리 칸: 올라서면 회복 + 별빛 가호, 찾아갈 사람이 없어 그대로 맞는다
			local st = stars[1]
			ally.Health = math.floor(ally.MaxHealth / 2)
			local hp = ally.Health
			local taken = BattleStatus.Total(ally.Status, "DamageTaken")
			GridBattle.MoveAlly(s, st[1], st[2])
			check(ally.Health - hp >= math.floor(ally.MaxHealth * GridBattle.STAR_HEAL) - 1, string.format("솔로 별자리 칸 — 최대 체력 20%% 회복(%d → %d)", hp, ally.Health))
			check(math.abs(BattleStatus.Total(ally.Status, "DamageTaken") - (taken - GridBattle.STAR_GUARD)) < 1e-6, "별빛 가호 — 받는 피해 −30%")
			check(stack(ally, ClassResources.STAR_GUARD) == 2, "별빛 가호 표시(남은 2턴 — 질문 1-C)")
			check(#GridBattle.PlannedThreatList(s) == #plans, "솔로는 별 위에서도 맞는다")
			local hp2 = ally.Health
			GridBattle.MoveAlly(s, here.X, here.Y)
			GridBattle.MoveAlly(s, st[1], st[2])
			check(ally.Health == hp2, "별자리 칸 보상은 한 턴 한 번")
			local sw = stack(ally, ClassResources.SEONGWI) + stack(ally, ClassResources.MUTBYEOL) * 100
			for _, t in GridBattle.PlannedThreatList(s) do
				GridBattle.ResolveDodge(s, t.Unit.Id, "Success", t.Index)
			end
			GridBattle.EndTurn(s)
			local now = stack(ally, ClassResources.SEONGWI) + stack(ally, ClassResources.MUTBYEOL) * 100
			check(now > sw, "별자리 칸에서 턴을 마치면 성위")
			check(guarded(ally) and stack(ally, ClassResources.STAR_GUARD) == 1, "별빛 가호는 다음 턴까지(질문 1-C)")
			GridBattle.EndTurn(s)
			check(not guarded(ally) and stack(ally, ClassResources.STAR_GUARD) == 0, "별빛 가호는 2턴 뒤 끝")
		end
	end
	check(seekSeen > 0, "추적 공격이 나옴")
	-- 파티: 노린 아군이 별 위면 별 밖의 다른 아군을 찾아간다(둘째 아군을 붙여 본다 — 파티 전투는 아직 없다)
	do
		local s = battle()
		local b = boss(s)
		local ally = GridBattle.Ally(s)
		local friend = table.clone(ally)
		friend.Id = "player2"
		s.Units.player2 = friend
		local mine = BattleGrid.CellOf(s.Grid, GridBattle.ALLY_ID)
		BattleGrid.Place(s.Grid, "player2", "Ally", if mine.X == 6 then 1 else 6, mine.Y)
		local stars
		for _ = 1, 10 do
			GridBattle.EnemyPlan(s, rng)
			stars = s.Callisto.Lure
			if stars and b.Plans and #b.Plans > 0 then
				break
			end
			GridBattle.EndTurn(s)
		end
		check(stars ~= nil, "파티 시험: 추적 공격이 나옴")
		local plans = #b.Plans
		local fc = BattleGrid.CellOf(s.Grid, "player2")
		check(not has(stars, fc.X, fc.Y), "별자리 칸은 둘째 아군 자리도 피한다")
		ally.Health = math.floor(ally.MaxHealth / 2)
		local hp = ally.Health
		GridBattle.MoveAlly(s, stars[1][1], stars[1][2])
		check(ally.Health == hp and not s.Callisto.StarUsed, "파티면 별자리 칸 회복 없음")
		check(#GridBattle.PlannedThreatList(s) == 0, "별 위에 선 나는 안 맞는다")
		s.AllyId = "player2"
		check(#GridBattle.PlannedThreatList(s) == plans, "공격이 별 밖의 다른 아군을 찾아간다")
		BattleGrid.Move(s.Grid, "player2", stars[2][1], stars[2][2])
		check(#GridBattle.PlannedThreatList(s) == 0, "둘 다 별 위면 둘째는 안 맞고")
		s.AllyId = GridBattle.ALLY_ID
		check(#GridBattle.PlannedThreatList(s) == plans, "처음 노린 아군이 맞는다")
	end
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
		-- 2026-11-07 사용자: 메라크는 유도기 — 대상 하나를 쫓는다(어디 서도 맞고 파티면 별 밖 다른 아군을 찾아감), 회피 QTE 가능
		check(b.Plans[1].Seek == true and not b.Plans[1].Track and b.Plans[1].Shape == "Single" and #b.Plans[1].Cells == 1, "메라크는 단일 유도기(Seek) — 줄 고정 아님")
		check(not loadShared("BattleSkills").ById("CallistoMerak").Unavoidable, "메라크는 회피 QTE 가능")
		for x = 1, 6 do
			for y = 1, 3 do
				GridBattle.MoveAlly(s, x, y)
				check(#GridBattle.PlannedThreatList(s) == 1, string.format("메라크는 어디 서도 쫓아와 맞는다 — (%d,%d)", x, y))
			end
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
	print(string.format("10 추적·별자리 칸 OK (%d)", seekSeen))
end

--=== 11. 2026-11-01 답: 판 전체 별 칸(파티 빠짐) · 던진 뒤 묶임 · 알카이드·두베 감소 · 점멸 → 북두칠성 · 알코르 쌍둥이 ===--
do
	-- 판 전체(심베라즈마 = All)에도 별 칸이 깔리고, 파티면 별 위 사람은 빠진다
	local s = battle()
	local b = boss(s)
	local ally = GridBattle.Ally(s)
	local friend = table.clone(ally)
	friend.Id = "player2"
	s.Units.player2 = friend
	local mine = BattleGrid.CellOf(s.Grid, GridBattle.ALLY_ID)
	BattleGrid.Place(s.Grid, "player2", "Ally", if mine.X == 6 then 1 else 6, mine.Y)
	GridBattle.EnemyPlan(s, rng)
	check(s.Callisto.Lure ~= nil and #s.Callisto.Lure >= 3, "어떤 공격이든 별 칸이 깔린다(질문 3-A)")
	-- 판 전체·행열 꼴(Shelter): 파티면 별 위 사람은 빠지고, 혼자면 맞는다
	for _, plan in b.Plans or {} do
		plan.Seek, plan.Shelter, plan.Shape = nil, true, nil
		plan.Cells = {}
		for x = 1, 6 do
			for y = 1, 3 do
				table.insert(plan.Cells, { x, y })
			end
		end
	end
	local st = s.Callisto.Lure[1]
	GridBattle.MoveAlly(s, st[1], st[2])
	local threats = #GridBattle.PlannedThreatList(s)
	if #(b.Plans or {}) > 0 then
		check(threats == 0, "파티: 판 전체 공격도 별 위 사람은 빠진다")
		s.Units.player2 = nil
		BattleGrid.Remove(s.Grid, "player2")
		check(#GridBattle.PlannedThreatList(s) > 0, "혼자면 별 위에서도 맞는다(회복·가호를 받는다)")
	end
	-- 심베라즈마: 던진 뒤 다음 턴 묶임(공통 규칙)
	local s2 = battle()
	local a2 = GridBattle.Ally(s2)
	playTurn(s2)
	local used = playTurn(s2)
	if used[1] == "CallistoSymberasma" then
		check(BattleStatus.Stack(a2.Status, ClassResources.BIND) > 0, "심베라즈마 다음 턴 [묶임]")
		check(GridBattle.MoveAlly(s2, 1, 1) == false or BattleGrid.CellOf(s2.Grid, GridBattle.ALLY_ID).X == 1, "묶이면 못 움직인다")
	end
	-- 2페이즈: 알카이드·두베 턴마다 1 감소 · 점멸 → 북두칠성 보너스 · 알코르 쌍둥이(아군 진형 대칭, 함께 처치)
	local s3 = toPage2()
	local b3 = boss(s3)
	local a3 = GridBattle.Ally(s3)
	playTurn(s3)   -- 소환 턴(알코르 + 쌍둥이)
	-- 감소는 1페이즈에서(2페이즈는 미자르가 알카이드를 다시 채운다)
	local s4 = battle()
	local a4 = GridBattle.Ally(s4)
	BattleStatus.AddStack(a4.Status, ClassResources.ALKAID, 5, 15)
	BattleStatus.AddStack(a4.Status, ClassResources.DUBHE, 4, 20)
	GridBattle.EndTurn(s4)
	check(stack(a4, ClassResources.ALKAID) == 4 and stack(a4, ClassResources.DUBHE) == 3,
		string.format("알카이드·두베가 턴마다 1 준다(알카이드 %d · 두베 %d)", stack(a4, ClassResources.ALKAID), stack(a4, ClassResources.DUBHE)))
	local c3 = s3.Callisto
	local alcor = c3.AlcorId and s3.Units[c3.AlcorId]
	local twin = c3.AlcorTwinId and s3.Units[c3.AlcorTwinId]
	check(alcor and twin and twin.Alive, "알코르와 아군 진형 쌍둥이")
	local ac, tc = BattleGrid.CellOf(s3.Grid, alcor.Id), BattleGrid.CellOf(s3.Grid, twin.Id)
	check(tc and tc.Side == "Ally" and ac.Side == "Enemy", "쌍둥이는 아군 진형에")
	check(GridBattle.DebugHitPart(s3, twin.Id, 999999) == 0 and twin.Alive, "쌍둥이는 맞지 않는다")
	GridBattle.DebugHitPart(s3, alcor.Id, 999999)
	check(not alcor.Alive and not twin.Alive, "적 쪽 알코르를 잡으면 쌍둥이도 사라진다")
	BattleStatus.AddStack(b3.Status, ClassResources.BLINK, 3)
	c3.Dipper = true
	c3.Cooldowns = {}
	GridBattle.EnemyPlan(s3, rng)
	if b3.Plans and b3.Plans[1].SkillId == "CallistoDipper" then
		check(math.abs((c3.DipperBonus or 0) - 0.3) < 1e-6 and stack(b3, ClassResources.BLINK) == 0, "점멸 3 → 북두칠성 +30%(스택은 씀)")
	end
	print("11 2026-11-01 답(판 전체 별 칸·던진 뒤 묶임·감소·점멸·쌍둥이) OK")
end

--=== 12. 2026-11-06 개선안: 케노스 · 범위 줄인 4종 · R1~R3 · 쿨타임 · 3비트 QTE ===--
do
	local BattleSkills = loadShared("BattleSkills")
	local QteDefinitions = loadShared("QteDefinitions")
	local function has(cells, x, y)
		for _, c in cells do
			if c[1] == x and c[2] == y then
				return true
			end
		end
		return false
	end
	local function planOf(s): any
		return boss(s).Plans and boss(s).Plans[1]
	end
	local function toPage3()
		local s = battle()
		GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
		GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
		GridBattle.EndTurn(s)
		playTurn(s, "Success") -- 잠기리
		return s
	end

	-- 케노스 피니셔(2026-11-06 밤): 체력 70% 도발 → 탑로프 → 다이브·파워밤 · 빛 칸 무피해 · 로프 · 핀 폴 · 30% 강화판
	do
		local function hitBoss(s, grade: string): boolean
			local at = BattleGrid.CellOf(s.Grid, boss(s).Id)
			local me = BattleGrid.CellOf(s.Grid, GridBattle.ALLY_ID)
			if at and me then
				BattleStatus.SpendAll(GridBattle.Ally(s).Status, ClassResources.BIND)
				GridBattle.MoveAlly(s, 1, at.Y)
			end
			GridBattle.Ally(s).Stamina = 999
			local ok = GridBattle.ResolveSkill(s, 1, grade :: any, rng)
			return ok
		end
		local function castSkills(s): { string }
			local ids = {}
			for _, ev in s.Events do
				if ev.Kind == "Cast" then
					table.insert(ids, ev.SkillId)
				end
			end
			return ids
		end
		local function startA(ratio: number)
			local s = toPage3()
			local b = boss(s)
			b.Health = math.floor(b.MaxHealth * ratio)
			GridBattle.Ally(s).Health = GridBattle.Ally(s).MaxHealth
			GridBattle.EnemyPlan(s, rng)
			return s
		end
		local function toB(s)
			GridBattle.EndTurn(s)
			GridBattle.EnemyPlan(s, rng)
		end

		-- 임계: 체력 70% 이하에서만 도발(턴 A) — 위협 없음 · 빛 6칸 · 로프 열 1·6
		do
			local s = toPage3()
			boss(s).Health = math.floor(boss(s).MaxHealth * 0.8)
			GridBattle.EnemyPlan(s, rng)
			check(s.Callisto.Finisher == nil, "체력 80% 에선 피니셔 없음")
			GridBattle.EndTurn(s)
		end
		local s = startA(0.65)
		local f = s.Callisto.Finisher
		check(f and f.Stage == 1 and #f.Safe == 6 and not f.Strong and #GridBattle.PlannedThreatList(s) == 0, "70% 이하 턴 A: 도발(피해 없음) · 빛 6칸")
		check(table.find(castSkills(s), "CallistoKenos") ~= nil, "도발 Cast 사건")
		toB(s)
		check(table.find(castSkills(s), "CallistoKenosClimb") ~= nil and s.Callisto.Finisher.Stage == 2, "턴 A 끝 탑로프 Cast")
		local plans = boss(s).Plans
		check(#plans == 2 and plans[1].SkillId == "CallistoKenosDive" and plans[2].SkillId == "CallistoKenosBomb" and #plans[1].Cells == 12 and #plans[1].Safe == 6 and #plans[1].Rope == 6, "턴 B: 다이브·파워밤 · 위험 12칸 · 빛 6 · 로프 6")
		local ally = GridBattle.Ally(s)
		-- 빛 칸: 무피해(우선순위: 빛 칸 > 로프)
		local safe = plans[1].Safe[1]
		GridBattle.MoveAlly(s, safe[1], safe[2])
		check(#GridBattle.PlannedThreatList(s) == 0, "빛 칸 안은 다이브도 파워밤도 없다")
		-- 일반: 위험 칸(로프 아님) — 다이브 + 성위 4 → 파워밤
		local normal
		for _, c in plans[1].Cells do
			if c[1] > 1 and c[1] < 6 then
				normal = c
			end
		end
		GridBattle.MoveAlly(s, normal[1], normal[2])
		check(#GridBattle.PlannedThreatList(s) == 2, "위험 칸: 다이브 + 파워밤")
		local sw = stack(ally, ClassResources.SEONGWI)
		local hp = ally.Health
		for _, t in GridBattle.PlannedThreatList(s) do
			GridBattle.ResolveDodge(s, t.Unit.Id, "Success", t.Index) -- 회피 불가 — 성공해도 맞는다
		end
		check(ally.Health < hp and stack(ally, ClassResources.SEONGWI) == sw + 4, "일반: 다이브 + 파워밤, 성위 4")
		GridBattle.EndTurn(s)
		check(s.Callisto.Finisher == nil and s.Callisto.FinisherCount == 1, "피니셔 끝")

		-- 로프(열 1·6): 다이브만(−75%) · 파워밤·성위 없음
		local s2 = startA(0.65)
		toB(s2)
		local p2 = boss(s2).Plans[1]
		local ropeCell
		for _, c in p2.Cells do
			if c[1] == 1 or c[1] == 6 then
				ropeCell = c
			end
		end
		local a2 = GridBattle.Ally(s2)
		BattleStatus.SpendAll(a2.Status, ClassResources.BIND)
		GridBattle.MoveAlly(s2, ropeCell[1], ropeCell[2])
		local th = GridBattle.PlannedThreatList(s2)
		check(#th == 1, "로프 위: 파워밤 없음 — " .. #th)
		local sw2 = stack(a2, ClassResources.SEONGWI)
		GridBattle.ResolveDodge(s2, th[1].Unit.Id, "Fail", th[1].Index)
		check(stack(a2, ClassResources.SEONGWI) == sw2, "로프: 성위 없음")

		-- 핀 폴: 턴 A·B 연속 스킬 QTE Success → 다이브 취소 · 3% 손실 · 다음 턴 스턴
		local s3 = startA(0.65)
		hitBoss(s3, "Success")
		check(s3.Callisto.Finisher.Pin == 1, "턴 A 적중 → 핀 폴 1/2")
		toB(s3)
		check(not s3.Callisto.Finisher.Failed, "턴 A 에 적중했으니 실패 아님")
		local pb = boss(s3)
		local pbBefore = pb.Health
		hitBoss(s3, "Success")
		check(s3.Callisto.Finisher.Pinned and #GridBattle.PlannedThreatList(s3) == 0, "턴 B 적중 → 핀 폴 2/2, 다이브 취소(우선순위 1)")
		GridBattle.EndTurn(s3)
		check(table.find(castSkills(s3), "CallistoKenosFall") ~= nil and s3.Callisto.Stun == 1, "끌어내림 Cast · 다음 턴 스턴")
		local healthAfter = pb.Health
		GridBattle.EnemyPlan(s3, rng)
		check(pb.Plans == nil and s3.Callisto.Stun == 0, "스턴 턴은 예고 없음")
		-- 조건 미달: Partial 은 세지 않고, 턴 A 를 놓치면 핀 폴 불가
		local s4 = startA(0.65)
		hitBoss(s4, "Partial")
		check(s4.Callisto.Finisher.Pin == 0, "스킬 QTE Success 만 센다")
		toB(s4)
		check(s4.Callisto.Finisher.Failed, "턴 A 에 못 맞히면 핀 폴 실패 표시")
		hitBoss(s4, "Success")
		check(not s4.Callisto.Finisher.Pinned, "턴 A 를 놓치면 턴 B 만으로는 안 된다")

		-- 30% 두 번째는 강화판(빛 4칸) · 세 번째는 없다
		GridBattle.EndTurn(s)
		boss(s).Health = math.floor(boss(s).MaxHealth * 0.25)
		GridBattle.EnemyPlan(s, rng)
		check(s.Callisto.Finisher and s.Callisto.Finisher.Strong and #s.Callisto.Finisher.Safe == 4, "30% 이하 두 번째: 강화판 빛 4칸")
		toB(s)
		GridBattle.EndTurn(s)
		check(s.Callisto.FinisherCount == 2, "두 번 끝")
		boss(s).Health = math.floor(boss(s).MaxHealth * 0.1)
		GridBattle.EnemyPlan(s, rng)
		check(s.Callisto.Finisher == nil, "세 번째는 없다")
	end

	-- 추적 기믹 4종(2026-11-06 밤): 칩 상태(Met) · 피해 감소 사건 값 · 가드 QTE
	do
		local function lastGimmick(s): number?
			for i = #s.Events, 1, -1 do
				if s.Events[i].Kind == "EnemyAttack" then
					return s.Events[i].Gimmick
				end
			end
			return nil
		end
		local BattleSkills2 = BattleSkills
		check(BattleSkills2.ById("CallistoSlash").GuardOnly and BattleSkills2.ById("CallistoArtificial").GuardOnly and not BattleSkills2.ById("CallistoSynthesis").GuardOnly and not BattleSkills2.ById("CallistoMegrez").GuardOnly, "파라티리시·인위적 별자리는 가드 QTE, 신데시·메그레즈는 회피 유지")
		-- 신데시 발 묶기: 이동 안 함 −50%, 이동하면 없음
		local function synth()
			local s = battle()
			playTurn(s)
			playTurn(s)
			GridBattle.Ally(s).Status.Stacks[ClassResources.SEONGWI] = 2
			GridBattle.EnemyPlan(s, rng)
			BattleStatus.SpendAll(GridBattle.Ally(s).Status, ClassResources.BIND)
			return s
		end
		local s = synth()
		check(planOf(s).SkillId == "CallistoSynthesis" and GridBattle.Snapshot(s).Callisto.Gimmick.Met == true, "발 묶기 칩: 이동 안 하면 충족")
		GridBattle.ResolveDodge(s, boss(s).Id, "Fail", 1)
		check(math.abs((lastGimmick(s) or 0) - 0.5) < 1e-6, "발 묶기 −50%")
		local s2 = synth()
		local me = BattleGrid.CellOf(s2.Grid, GridBattle.ALLY_ID)
		GridBattle.MoveAlly(s2, if me.X == 6 then 5 else me.X + 1, me.Y)
		check(GridBattle.Snapshot(s2).Callisto.Gimmick.Met == false, "이동하면 칩이 회색(미충족)")
		GridBattle.ResolveDodge(s2, boss(s2).Id, "Fail", 1)
		check(lastGimmick(s2) == nil, "이동했으면 기믹 감소 없음")
		-- 받는 피해 하한 15%: 가드 −90% 위에 −60% 가 겹쳐도 원래의 15% 밑이 아니다
		local s3 = synth()
		BattleStatus.AddModifier(GridBattle.Ally(s3).Status, "DamageTaken", -0.9, 5, "시험")
		GridBattle.ResolveDodge(s3, boss(s3).Id, "Fail", 1)
		local def3 = math.max(0, 1 + BattleStatus.TakenRatio(GridBattle.Ally(s3).Status, "Physical"))
		check(def3 < 0.5 and (1 - (lastGimmick(s3) or 0)) * def3 >= 0.15 - 1e-6, string.format("가드류가 겹쳐도 받는 피해는 원래의 15%% 이상(def %.2f · 기믹 −%.2f)", def3, lastGimmick(s3) or 0))
		-- 파라티리시 맞받아치기: 칼리스토 적중 → −60% · 성위 없음
		local s4 = battle()
		playTurn(s4)
		playTurn(s4)
		playTurn(s4)
		playTurn(s4) -- 3턴 신데시, 4턴 아스트로(보장), 다음이 파라티리시…
		GridBattle.Ally(s4).Status.Stacks[ClassResources.SEONGWI] = 0
		GridBattle.EnemyPlan(s4, rng)
		if planOf(s4).SkillId == "CallistoSlash" then
			BattleStatus.SpendAll(GridBattle.Ally(s4).Status, ClassResources.BIND)
			check(GridBattle.Snapshot(s4).Callisto.Gimmick.Met == false, "맞받아치기 칩: 적중 전 회색")
			local at = BattleGrid.CellOf(s4.Grid, boss(s4).Id)
			GridBattle.MoveAlly(s4, 1, at.Y)
			GridBattle.Ally(s4).Stamina = 999
			GridBattle.ResolveSkill(s4, 1, "Success", rng)
			check(s4.Callisto.Struck and GridBattle.Snapshot(s4).Callisto.Gimmick.Met, "칼리스토를 스킬로 적중하면 충족")
			GridBattle.ResolveDodge(s4, boss(s4).Id, "Success", 1)
			check(math.abs((lastGimmick(s4) or 0) - 0.6) < 1e-6 and stack(GridBattle.Ally(s4), ClassResources.SEONGWI) == 0, "맞받아치기 −60% · 성위 없음")
		end
		-- 인위적 별자리 로프 기대기(3페이즈): 열 1 또는 6 −50%
		local s5 = toPage3()
		GridBattle.EnemyPlan(s5, rng)
		check(planOf(s5).SkillId == "CallistoArtificial", "3페이즈 인위적 별자리")
		BattleStatus.SpendAll(GridBattle.Ally(s5).Status, ClassResources.BIND)
		GridBattle.MoveAlly(s5, 1, 2)
		check(GridBattle.Snapshot(s5).Callisto.Gimmick.Met == true, "로프 기대기 칩: 열 1 충족")
		GridBattle.ResolveDodge(s5, boss(s5).Id, "Fail", 1)
		check(math.abs((lastGimmick(s5) or 0) - 0.5) < 1e-6, "로프 기대기 −50%")
		-- 메그레즈 쌍둥이 겨누기: 알코르가 살아 있으면 알코르를 맞춰야 한다
		local s6 = toPage2()
		playTurn(s6)
		local c6 = s6.Callisto
		c6.Cooldowns = { CallistoAlioth = 9, CallistoPhecda = 9, CallistoMerak = 9 }
		c6.Aliot = 3
		BattleStatus.AddStack(GridBattle.Ally(s6).Status, ClassResources.ALKAID, 1, 15)
		GridBattle.EnemyPlan(s6, rng)
		check(planOf(s6).SkillId == "CallistoMegrez", "메그레즈 예고")
		c6.Struck = true
		check(GridBattle.Snapshot(s6).Callisto.Gimmick.Met == false, "알코르가 있으면 칼리스토를 맞혀도 미충족")
		c6.StruckAlcor = true
		check(GridBattle.Snapshot(s6).Callisto.Gimmick.Met == true, "알코르를 맞히면 충족")
		GridBattle.ResolveDodge(s6, boss(s6).Id, "Fail", 1)
		check(math.abs((lastGimmick(s6) or 0) - 0.6) < 1e-6, "쌍둥이 겨누기 −60%")
	end

	-- 범위 줄인 4종: 렌즈 9 · 아스트로 세시 4~9 · 알리오스 6 · 북두칠성 7
	do
		local s = battle()
		playTurn(s)
		playTurn(s) -- 다음이 3번 자리
		GridBattle.Ally(s).Status.Stacks[ClassResources.SEONGWI] = 3 -- R1: 성위 3 이면 렌즈
		GridBattle.EnemyPlan(s, rng)
		local plan = planOf(s)
		check(plan.SkillId == "CallistoArktos", "R1 성위 3 이면 렌즈 — " .. plan.SkillId)
		check(#plan.Cells == 9 and not plan.Seek and not plan.Shelter, "렌즈 3열 9칸 — " .. #plan.Cells)
		local s2 = battle()
		playTurn(s2)
		playTurn(s2)
		GridBattle.Ally(s2).Status.Stacks[ClassResources.SEONGWI] = 2
		GridBattle.EnemyPlan(s2, rng)
		check(planOf(s2).SkillId == "CallistoSynthesis", "성위 2 면 렌즈 아님(R1 문턱 3)")
		check(#boss(s2).Plans == 1 and not BattleSkills.ById("CallistoSynthesis").ChainQte, "신데시 한 번(2026-11-08)")

		local s3 = battle()
		stack(boss(s3), ClassResources.URSA_MINOR)
		BattleStatus.AddStack(boss(s3).Status, ClassResources.URSA_MINOR, 1, 1)
		s3.Callisto.Slot = 4
		for _, spot in { { 1, 1 }, { 3, 2 }, { 6, 3 } } do
			GridBattle.MoveAlly(s3, spot[1], spot[2])
			GridBattle.EnemyPlan(s3, rng)
			local p = planOf(s3)
			check(p.SkillId == "CallistoAstro" and #p.Cells >= 4 and #p.Cells <= 9 and has(p.Cells, spot[1], spot[2]), string.format("아스트로 세시 둘레 3×3 (%d,%d) — %d칸", spot[1], spot[2], #p.Cells))
			s3.Callisto.Slot = 4
			GridBattle.EndTurn(s3)
		end

		local s4 = toPage2()
		playTurn(s4) -- 소환
		GridBattle.EnemyPlan(s4, rng)
		check(planOf(s4).SkillId == "CallistoAlioth" and #planOf(s4).Cells == 18 and s4.Callisto.AliothCells == nil, "알리오스 장판 판 전체 18칸(2026-11-07 사용자: 전체광역기)")
		local ally4 = GridBattle.Ally(s4)
		local cell = planOf(s4).Cells[1]
		GridBattle.MoveAlly(s4, cell[1], cell[2])
		-- 판 전체 장판: 어디 서 있어도 턴 끝에 피해·두베 1
		for _, spot in { { 1, 1 }, { 6, 3 } } do
			GridBattle.MoveAlly(s4, spot[1], spot[2])
			local dub = stack(ally4, ClassResources.DUBHE)
			local hp = ally4.Health
			GridBattle.EndTurn(s4)
			check(ally4.Health < hp and stack(ally4, ClassResources.DUBHE) >= math.max(0, dub - 1) and s4.Callisto.Aliot < 5, string.format("알리오스 장판은 판 전체 — (%d,%d)에서도 턴 끝 피해", spot[1], spot[2]))
			GridBattle.EnemyPlan(s4, rng)
		end

		local s5 = toPage2()
		playTurn(s5)
		s5.Callisto.Dipper = true
		GridBattle.EnemyPlan(s5, rng)
		check(planOf(s5).SkillId == "CallistoDipper" and #planOf(s5).Cells == 18 and has(planOf(s5).Cells, 6, 1) and has(planOf(s5).Cells, 1, 3), "북두칠성 판 전체(2026-11-07 사용자: 전체 타격기)")
	end

	-- R2: 평타 2연속이면 다음 턴 쿨 1 이하 남은 기술을 바로 · 쿨타임 +3 · R3
	do
		local s = toPage2()
		playTurn(s) -- 소환
		local c = s.Callisto
		c.Aliot, c.Basics, c.Cooldowns = 0, 0, { CallistoAlioth = 1, CallistoMerak = 1, CallistoMegrez = 5, CallistoPhecda = 5 }
		GridBattle.EnemyPlan(s, rng)
		check(planOf(s).SkillId == "CallistoBuried", "R2 전: 쿨 1 남은 기술은 못 써서 평타 — " .. planOf(s).SkillId)
		c.Aliot, c.Basics, c.Cooldowns = 0, 2, { CallistoAlioth = 1, CallistoMerak = 1, CallistoMegrez = 5, CallistoPhecda = 5 }
		GridBattle.EnemyPlan(s, rng)
		check(planOf(s).SkillId == "CallistoAlioth" and c.Basics == 0, "R2: 평타 2연속 뒤 쿨 1 남은 알리오스를 바로 — " .. planOf(s).SkillId)
		c.Aliot, c.Basics, c.Cooldowns = 0, 2, { CallistoAlioth = 3, CallistoMerak = 3, CallistoMegrez = 5, CallistoPhecda = 5 }
		GridBattle.EnemyPlan(s, rng)
		check(planOf(s).SkillId == "CallistoBuried", "쿨 3 이상은 풀어 주지 않는다")
		check(BattleSkills.ById("CallistoMerak").BossCooldown == 6 and BattleSkills.ById("CallistoPhecda").BossCooldown == 11
			and BattleSkills.ById("CallistoAlioth").BossCooldown == 7 and BattleSkills.ById("CallistoMegrez").BossCooldown == 5
			and BattleSkills.ById("CallistoArtificial").BossCooldown == 6 and BattleSkills.ById("CallistoShower").BossCooldown == 5
			and BattleSkills.ById("CallistoAlcor").BossCooldown == 8, "쿨타임: 메라크 6 · 페크다 11 · 알리오스 7(+3 그대로) · 나머지 +2")
	end

	-- 3비트 QTE: 5개 × 3 · 6,000ms · 비트당 실수 0 회피 / 1 막기 / 2 실패 · 비트별 서버 판정
	do
		local q = QteDefinitions.CreateChain(rng, 0, "t", 3)
		check(#q.ExpectedDirections == 21 and q.DurationMs == 9000 and q.BeatCount == 3 and q.BeatSize == 7 and q.ReverseBeats[2], "화살표 7개 × 3비트 · 9,000ms · 비트 2 반대")
		local opp = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
		local function feed(n, wrongAt)
			for i = 1, n do
				local idx = (q.SequenceIndex or 0) + 1
				local dir = q.ExpectedDirections[idx]
				-- 비트 2(8~14번째)는 화면 화살표의 반대를 눌러야 맞다
				local right = if idx >= 8 and idx <= 14 then opp[dir] else dir
				QteDefinitions.FeedDirection(q, if wrongAt[i] then opp[right] else right)
			end
		end
		feed(21, {})
		local g = QteDefinitions.JudgeChain(q)
		check(g[1] == "Success" and g[2] == "Success" and g[3] == "Success" and QteDefinitions.Judge(q, 100) == "Success", "무실수 3비트 회피")
		q = QteDefinitions.CreateChain(rng, 0, "t", 3)
		feed(21, { [9] = true, [15] = true, [16] = true })
		g = QteDefinitions.JudgeChain(q)
		check(g[1] == "Success" and g[2] == "Partial" and g[3] == "Fail" and QteDefinitions.Judge(q, 100) == "Fail", "비트별 등급 Success·Partial·Fail — " .. table.concat(g, ","))
		q = QteDefinitions.CreateChain(rng, 0, "t", 3)
		feed(16, {})
		g = QteDefinitions.JudgeChain(q)
		check(g[1] == "Success" and g[2] == "Success" and g[3] == "Fail", "시간 끝나 못 채운 비트는 실패")
		-- 반대 비트에 화면 그대로 누르면 틀림
		q = QteDefinitions.CreateChain(rng, 0, "t", 3)
		for i = 1, 7 do
			QteDefinitions.FeedDirection(q, q.ExpectedDirections[i])
		end
		check(QteDefinitions.FeedDirection(q, q.ExpectedDirections[8]) == false and q.BeatMistakes[2] == 1, "비트 2 에선 보이는 방향 그대로 누르면 실수")
		-- 서버: 신데시는 2026-11-08 부터 한 번만(연타 QTE 없음) — 위협 하나, 등급 하나로 피해 0 < 막기 < 전액
		local dmg = {}
		for i, grade in { "Success", "Partial", "Fail" } do
			local s = battle()
			playTurn(s)
			playTurn(s)
			GridBattle.EnemyPlan(s, rng)
			check(#boss(s).Plans == 1 and #GridBattle.PlannedThreatList(s) == 1, "신데시 한 번 — 위협 하나")
			local ally = GridBattle.Ally(s)
			local hp = ally.Health
			GridBattle.ResolveDodge(s, boss(s).Id, grade :: any, 1)
			dmg[i] = hp - ally.Health
		end
		check(dmg[1] == 0 and dmg[2] > 0 and dmg[3] > dmg[2], string.format("등급별 피해 0 < 막기 < 전액 (%d · %d · %d)", dmg[1], dmg[2], dmg[3]))
	end
	-- 궁극기 보장: 체력이 거의 안 깎여도(작은 곰 자리·칠성군 없음) 1P 4번째 턴 아스트로 세시 · 2P 6번째 턴 북두칠성
	do
		local s1 = battle()
		local seen1
		for turn = 1, 4 do
			playTurn(s1)
			if turn == 4 then
				seen1 = boss(s1).Plan and boss(s1).Plan.SkillId
			end
		end
		check(seen1 == "CallistoAstro", "1P 4번째 턴 아스트로 세시 — " .. tostring(seen1))
		local s2 = toPage2()
		local dipperTurn
		for turn = 1, 8 do
			GridBattle.Ally(s2).Health = GridBattle.Ally(s2).MaxHealth
			playTurn(s2, "Success")
			local p = boss(s2).Plan
			if p and p.SkillId == "CallistoDipper" and not dipperTurn then
				dipperTurn = turn
			end
		end
		check(dipperTurn ~= nil and dipperTurn <= 6, "2P 6번째 턴까지 북두칠성 — " .. tostring(dipperTurn))
	end
	print("12 2026-11-06 개선안(케노스·범위 4종·R1~R3·쿨타임·3비트 QTE) OK")
end

--=== 13. 2026-11-07 사용자: "3페이즈에선 2페이즈때 썼던 패턴들을 다 쓸 수 있게" ===--
do
	local function toP3()
		local s = battle()
		GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
		GridBattle.DebugHitPart(s, s.Callisto.UnitId, 999999)
		GridBattle.EndTurn(s)
		return s
	end
	local s = toP3()
	local b = boss(s)
	local seen, hist = {}, {}
	local sevenMax = 0
	for i = 1, 14 do
		-- 체력을 64% 에 붙들어 케노스(70%)는 한 번만, 칠성군(65% 미만)은 켠다. 장판이 깎은 체력은 되돌린다
		b.Health = math.floor(b.MaxHealth * 0.64)
		GridBattle.Ally(s).Health = GridBattle.Ally(s).MaxHealth
		GridBattle.EnemyPlan(s, rng)
		local id = b.Plan and b.Plan.SkillId
		if id == nil then
			for _, ev in s.Events do
				if ev.Kind == "Cast" and ev.SkillId then
					id = ev.SkillId
				end
			end
		end
		sevenMax = math.max(sevenMax, stack(b, ClassResources.SEVEN))
		for _, t in GridBattle.PlannedThreatList(s) do
			GridBattle.ResolveDodge(s, t.Unit.Id, if rng() < 0.5 then "Success" else "Fail", t.Index)
		end
		GridBattle.EndTurn(s)
		table.insert(hist, tostring(id))
		seen[id or "-"] = (seen[id or "-"] or 0) + 1
		if i >= 3 and hist[i] == hist[i - 1] and hist[i] == hist[i - 2] and (id == "CallistoBuried" or id == "CallistoResonance" or id == "CallistoAlioth" or id == "CallistoShower") then
			error("실패: 3페이즈 같은 기술 3연속 — " .. table.concat(hist, ","))
		end
	end
	local all = table.concat(hist, ",")
	check(hist[1] == "CallistoSubmerge" and (seen.CallistoSubmerge or 0) == 1, "3페이즈 첫 턴 잠기리 한 번만 — " .. all)
	for _, need in { "CallistoArtificial", "CallistoShower", "CallistoAlcor", "CallistoAlioth", "CallistoPhecda", "CallistoMerak", "CallistoMegrez", "CallistoDipper", "CallistoKenos" } do
		check(seen[need], "3페이즈에 " .. need .. " 가 나온다 — " .. all)
	end
	check(sevenMax >= 1, "3페이즈에서도 칠성이 쌓인다")
	-- 2026-11-07 사용자: 알리오스 전체 광역 · 다른 스킬 둘(페크다·메라크)은 유도기
	check(GridBattle.CALLISTO_FORM.CallistoAlioth == "All" and GridBattle.CALLISTO_FORM.CallistoPhecda == "Seek" and GridBattle.CALLISTO_FORM.CallistoMerak == "Seek" and GridBattle.CALLISTO_FORM.CallistoMegrez == "Seek", "알리오스 All · 페크다·메라크·메그레즈 Seek")
	print("13 3페이즈 2페이즈 기술 섞기 OK — " .. all)
end

--=== 14. 2026-11-07 총괄 정정: 십자 3개(파라티리시·심베라즈마·메그레즈) + 원래 모양 9개(줄·열·3×3·단일) 유도기 ===--
do
	local BattleSkills = loadShared("BattleSkills")
	local shapes = GridBattle.CALLISTO_SHAPE
	local want = {
		CallistoPhoto = "Cross", CallistoSymberasma = "Cross", CallistoMegrez = "Cross",
		CallistoSlash = "Row", CallistoSynthesis = "Row", CallistoResonance = "Row", CallistoBuried = "Row",
		CallistoTrohia = "Square", CallistoArtificial = "Square", CallistoShower = "Column",
		CallistoPhecda = "Single", CallistoMerak = "Single",
	}
	for id, kind in want do
		check(shapes[id] == kind, id .. " 모양 " .. kind)
		check(GridBattle.CALLISTO_FORM[id] == "Seek", id .. " 은 유도기(Seek)")
		local k = BattleSkills.ById(id).Shape.Kind
		check(k ~= "All" and (k == kind or kind == "X"), id .. " 범위 표시 " .. k)
	end
	for _, id in { "CallistoSubmerge", "CallistoAlioth", "CallistoDipper", "CallistoKenos" } do
		check(shapes[id] == nil and GridBattle.CALLISTO_FORM[id] == "All", id .. " 은 전체로 남는다")
	end
	-- 칸 수(6×3 판): 가운데 기준
	local function n(kind, x, y)
		return #GridBattle.ShapeCells(kind, x, y, 6, 3)
	end
	check(n("Cross", 3, 2) == 5 and n("X", 3, 2) == 5 and n("Cross", 1, 1) == 3 and n("X", 1, 1) == 2, "십자·X 칸 수")
	check(n("Row", 3, 2) == 6 and n("Row", 1, 1) == 6, "줄 = 선 행 6칸")
	check(n("Column", 3, 2) == 3 and n("Column", 6, 1) == 3, "열 = 선 열 3칸")
	check(n("Square", 3, 2) == 9 and n("Square", 1, 1) == 4 and n("Square", 1, 2) == 6, "3×3 — 가운데 9 · 모서리 4 · 가장자리 6(판 밖 잘림)")
	check(n("Single", 3, 2) == 1 and n("Single", 6, 3) == 1, "단일 1칸")
	local function has(list, x, y)
		for _, c in list do
			if c[1] == x and c[2] == y then return true end
		end
		return false
	end
	check(has(GridBattle.ShapeCells("Cross", 3, 2, 6, 3), 3, 1) and not has(GridBattle.ShapeCells("Cross", 3, 2, 6, 3), 2, 1), "십자는 상하좌우")
	check(has(GridBattle.ShapeCells("Row", 3, 2, 6, 3), 6, 2) and not has(GridBattle.ShapeCells("Row", 3, 2, 6, 3), 3, 1), "줄은 같은 행만")
	check(has(GridBattle.ShapeCells("Column", 3, 2, 6, 3), 3, 3) and not has(GridBattle.ShapeCells("Column", 3, 2, 6, 3), 4, 2), "열은 같은 열만")
	-- 대상 따라가기: 모양마다 어디로 옮겨도 대상은 자기 모양 안이라 맞는다(솔로)
	for _, kind in { "Cross", "X", "Row", "Column", "Square", "Single" } do
		local s = battle()
		local b = boss(s)
		b.Plans = { { SkillId = "CallistoBuried", Cells = {}, Seek = true, Shape = kind } }
		b.Plan = b.Plans[1]
		s.Planned = { b.Id }
		for x = 1, 6 do
			for y = 1, 3 do
				GridBattle.MoveAlly(s, x, y)
				check(#GridBattle.PlannedThreatList(s) == 1, string.format("%s 유도기는 옮겨도 쫓아온다 — (%d,%d)", kind, x, y))
			end
		end
	end
	-- 파티: 모양 안에 선 다른 아군만 맞는다(대상 = 쫓는 아군 칸 기준)
	do
		local s = battle()
		local b = boss(s)
		local friend = table.clone(GridBattle.Ally(s))
		friend.Id = "player2"
		s.Units.player2 = friend
		BattleGrid.Place(s.Grid, "player2", "Ally", 6, 3)
		BattleStatus.SpendAll(GridBattle.Ally(s).Status, ClassResources.BIND)
		GridBattle.MoveAlly(s, 3, 2)
		b.Plans = { { SkillId = "CallistoBuried", Cells = {}, Seek = true, Shape = "Cross", Target = GridBattle.ALLY_ID } }
		b.Plan = b.Plans[1]
		s.Planned = { b.Id }
		s.AllyId = "player2"
		check(#GridBattle.PlannedThreatList(s) == 0, "십자 밖(6,3)의 다른 아군은 안 맞는다")
		BattleGrid.Move(s.Grid, "player2", 3, 3)
		check(#GridBattle.PlannedThreatList(s) == 1, "십자 안(3,3)의 다른 아군도 맞는다")
		b.Plans[1].Shape = "Row"
		BattleGrid.Move(s.Grid, "player2", 6, 2)
		check(#GridBattle.PlannedThreatList(s) == 1, "줄 안(6,2)의 다른 아군도 맞는다")
		BattleGrid.Move(s.Grid, "player2", 6, 3)
		check(#GridBattle.PlannedThreatList(s) == 0, "줄 밖(6,3)의 다른 아군은 안 맞는다")
		b.Plans[1].Shape = "Column"
		BattleGrid.Move(s.Grid, "player2", 3, 1)
		check(#GridBattle.PlannedThreatList(s) == 1, "열 안(3,1)의 다른 아군도 맞는다")
		b.Plans[1].Shape = "Single"
		check(#GridBattle.PlannedThreatList(s) == 0, "단일은 대상 한 칸만 — 옆 칸 아군은 안 맞는다")
		s.AllyId = GridBattle.ALLY_ID
	end
	-- 실제 예고: 3페이즈를 돌리며 모양 기술의 Shape 가 박히고 Cells 가 그 모양 칸 수와 같다(판 전체 18칸 아님)
	local s = battle()
	local seenShape = 0
	for _ = 1, 10 do
		GridBattle.Ally(s).Health = GridBattle.Ally(s).MaxHealth
		GridBattle.EnemyPlan(s, rng)
		local p = boss(s).Plan
		if p and shapes[p.SkillId] then
			check(p.Shape == shapes[p.SkillId] and p.Seek == true and #p.Cells < 18 and #p.Cells >= 1, "예고 plan 에 Shape·Cells<18 — " .. p.SkillId)
			seenShape += 1
		end
		for _, t in GridBattle.PlannedThreatList(s) do
			GridBattle.ResolveDodge(s, t.Unit.Id, "Success", t.Index)
		end
		GridBattle.EndTurn(s)
	end
	check(seenShape >= 3, "1페이즈 예고에서 모양 기술이 나온다 — " .. seenShape)
	print("14 십자 3 + 원래 모양 9 유도기 OK")
end

print("칼리스토 규칙: 모두 통과")
