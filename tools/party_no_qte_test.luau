--[[
	party_no_qte_test.luau — 파티 전투 QTE 삭제(2026-11-08)로 바꾼 카드·패시브가 실제로 도는지 본다.
	  lune run tools/party_no_qte_test.luau
	결투사 기본 패링 확률 · 광전사 자랑(같은 행이나 열의 아군) · 자동 패링 확률 상한 50% · 체력 스탯 피해 감소 · 펄서 수렴([감극] 연계) · 청의 검사 거짓 틈(도발한 턴에 맞기). 실패하면 오류로 끝난다.
]]
local loadShared = require("./lune_env")

local GridBattle = loadShared("GridBattle")
local BattleStatus = loadShared("BattleStatus")
local BattleSkillEffects = loadShared("BattleSkillEffects")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

local R = ClassResources

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local function noCrit(): number
	return 0.99
end

local seed = 7
local function rng(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

local function member(classId: string, x: number, y: number, cards: { any }?): any
	return { ClassId = classId, X = x, Y = y, Cards = cards or {}, Name = classId, Health = 5000, Power = 10, Stamina = 999 }
end

local function party(members: { any }, enemies: { string }?, cells: { { number } }?): any
	return GridBattle.NewParty(1, members, {
		Name = "시험",
		Enemies = enemies or { "Slime" },
		Cells = cells or { { 1, 1 } },
		HealthScale = 1000,
		PowerScale = 1,
	})
end

-- 1) 결투사 기본 패링 확률(QTE 없는 전투만): 공격 태세 20% · 방어 태세 40% · 간파 +10%
do
	local state = party({ member("Duelist", 3, 2) })
	local me = GridBattle.Ally(state)
	local attack = BattleStatus.Stack(me.Status, R.STANCE_ATTACK) > 0
	local total = BattleStatus.Total(me.Status, "AutoParry")
	check(math.abs(total - ((if attack then 0.2 else 0.4) + 0.1)) < 1e-6, "결투사 시작 패링 확률 = 태세 기본 + 간파 0.1, 실제 " .. total)
	GridBattle.ToggleStance(state)
	local flipped = BattleStatus.Total(me.Status, "AutoParry")
	check(math.abs(flipped - ((if attack then 0.4 else 0.2) + 0.1)) < 1e-6, "태세를 바꾸면 기본 패링이 따라 바뀐다, 실제 " .. flipped)
	-- 연계(PointBlank): 깊은 호흡 다음 턴에 쓰면 아군 패링 확률 +20%(3턴)
	local chain = party({ member("Duelist", 3, 2) })
	local chainAlly = GridBattle.Ally(chain)
	check(GridBattle.SetUnitSkill(chain, "player", "DeepBreath"), "깊은 호흡을 고른다")
	GridBattle.BeginTurn(chain)
	GridBattle.ResolveUnitSkill(chain, "player", noCrit)
	GridBattle.EnemyPlan(chain, rng)
	GridBattle.ResolveEnemyPhase(chain, rng)
	GridBattle.EndTurn(chain)
	local beforeChain = BattleStatus.Total(chainAlly.Status, "AutoParry")
	check(GridBattle.SetUnitSkill(chain, "player", "PointBlank"), "연계를 고른다")
	GridBattle.BeginTurn(chain)
	GridBattle.ResolveUnitSkill(chain, "player", noCrit)
	local chainBonus = 0
	for _, modifier in chainAlly.Status.Modifiers do
		if modifier.Kind == "AutoParry" and modifier.Source == "연계" then
			chainBonus += modifier.Value
		end
	end
	check(math.abs(chainBonus - 0.2) < 1e-6, "연계는 패링 확률 +20% 를 건다, 실제 " .. chainBonus .. " (전 " .. beforeChain .. ")")
	-- QTE 가 있는 솔로 New 는 그대로(기본 패링 없음 · 패링 실수 봐주기)
	local solo = GridBattle.New(1, "솔로", 200, 10, "Duelist")
	check(BattleStatus.Total(GridBattle.Ally(solo).Status, "AutoParry") == 0, "QTE 전투엔 기본 패링이 없다")
	check(BattleStatus.Total(GridBattle.Ally(solo).Status, "ParryForgive") >= 1, "QTE 전투의 간파는 패링 실수 봐주기")
end

-- 2) 광전사 자랑: 같은 행에 다른 아군이 있을 때만 자해
do
	local function lost(allyY: number): number
		local state = party({
			member("Berserker", 3, 2, { { CardId = "Berserker_C_UnstoppingArm", Level = 1 } }),
			member("Pulsar", 4, allyY),
		})
		local unit = state.Units.player
		local before = unit.Health
		GridBattle.BeginTurn(state)
		-- 순서상 먼저 움직이는 유닛이 있으면 그쪽을 먼저 보낸다
		while GridBattle.NextActor(state) do
			local id = GridBattle.NextActor(state) :: string
			GridBattle.ResolveUnitSkill(state, id, noCrit)
			if id == "player" then
				break
			end
		end
		return before - unit.Health
	end
	check(lost(2) >= 1, "같은 행에 아군이 있으면 자해")
	check(lost(1) == 0, "다른 행·다른 열이면 자해 없음")
	-- 2026-11-08 Q13: 같은 행이나 같은 열 — 자기(3,2)와 같은 열(x=3)의 다른 행(y=3)
	local function lostAt(x: number, y: number): number
		local state = party({
			member("Berserker", 3, 2, { { CardId = "Berserker_C_UnstoppingArm", Level = 1 } }),
			member("Pulsar", x, y),
		})
		local unit = state.Units.player
		local before = unit.Health
		GridBattle.BeginTurn(state)
		while GridBattle.NextActor(state) do
			local id = GridBattle.NextActor(state) :: string
			GridBattle.ResolveUnitSkill(state, id, noCrit)
			if id == "player" then
				break
			end
		end
		return before - unit.Health
	end
	check(lostAt(3, 3) >= 1, "같은 열에 아군이 있으면 자해")
	check(lostAt(4, 3) == 0, "행도 열도 다르면 자해 없음")
end

-- 3) 펄서 수렴: 대상에게 이미 [감극]이 있으면 피해 +20%·[감극] 1 더
do
	local function converge(prime: boolean, cards: { any }?, roll: (() -> number)?): (number, number)
		local state = party({ member("Pulsar", 3, 1, cards) }, { "Slime" }, { { 1, 1 } })
		local enemy = GridBattle.AliveEnemies(state)[1]
		if prime then
			BattleSkillEffects.ApplyDepolar(enemy.Status, 1, 2, 0.15)
		end
		check(GridBattle.SetUnitSkill(state, "player", "Converge"), "수렴을 고른다")
		local before = enemy.Health
		GridBattle.BeginTurn(state)
		GridBattle.ResolveUnitSkill(state, "player", roll or noCrit)
		return before - enemy.Health, BattleStatus.Stack(enemy.Status, R.DEPOLAR)
	end
	local plainDamage, plainStacks = converge(false)
	local primedDamage, primedStacks = converge(true)
	check(plainStacks == 1, "연계 없으면 감극 +1 뿐, 실제 " .. plainStacks)
	check(primedStacks == 3, "연계면 감극 1+1+1, 실제 " .. primedStacks)
	local ratio = primedDamage / math.max(1, plainDamage)
	check(ratio > 1.3 and ratio < 1.5, "연계 피해 ≈ ×1.2 × 감극 ×1.15, 실제 " .. ratio)
	-- 고정 조준 40%(최대 레벨 근처): 감극이 없어도 가끔 연계가 터진다. 같은 상황을 여러 번 돌려 한 번은 섞여야 한다
	local hits = 0
	for _ = 1, 30 do
		local _, stacks = converge(false, { { CardId = "Pulsar_C_FixedAim", Level = 6 } }, rng)
		if stacks >= 2 then
			hits += 1
		end
	end
	check(hits >= 5 and hits <= 25, "고정 조준 40% 가 가끔 연계를 터뜨린다, 30번 중 " .. hits)
end

-- 4) 청의 검사 거짓 틈: 도발한 턴에 맞으면 확률로 진 발도술 재사용 대기 끝(턴당 1회)
do
	local state = party({ member("AzureBlade", 3, 1, { { CardId = "AzureBlade_R_FalseGap", Level = 6 } }) })
	local me = GridBattle.Ally(state)
	local resets = 0
	for _ = 1, 12 do
		if state.Outcome ~= "Ongoing" then
			break
		end
		me.ProvokeTurn = state.Turn
		me.Cooldowns.TrueIaido = 3
		GridBattle.EnemyPlan(state, rng)
		GridBattle.BeginTurn(state)
		GridBattle.ResolveEnemyPhase(state, rng)
		if (me.Cooldowns.TrueIaido or 0) == 0 then
			resets += 1
		end
		GridBattle.EndTurn(state)
	end
	check(resets >= 1 and resets <= 12, "거짓 틈이 가끔은 터진다, 터진 횟수 " .. resets)
end

-- 5) 자동 패링 확률 상한 50%(2026-11-08 Q13): 보정값 +100% 와 민첩 스탯을 얹어도 절반만 터진다. 광전사(회피 직업)로 센다
do
	check(GridBattle.AUTO_PARRY_CAP == 0.5, "상한 상수 0.5")
	local function parryRate(agility: number, vitality: number): (number, number)
		local state = party({
			{ ClassId = "Berserker", X = 3, Y = 1, Cards = {}, Name = "b", Health = 1000000, Power = 10, Stamina = 999, Stats = { Agility = agility, Vitality = vitality } },
		})
		local me = GridBattle.Ally(state)
		BattleStatus.AddModifier(me.Status, "AutoParry", 1, -1, "시험")
		local parried, hit, lostTotal = 0, 0, 0
		for _ = 1, 400 do
			if state.Outcome ~= "Ongoing" then
				break
			end
			state.Log = {}
			local before = me.Health
			GridBattle.EnemyPlan(state, rng)
			GridBattle.BeginTurn(state)
			GridBattle.ResolveEnemyPhase(state, rng)
			local got = false
			for _, line in state.Log do
				if line == "자동 패링" then
					parried += 1
					got = true
				end
			end
			if not got and me.Health < before then
				hit += 1
				lostTotal += before - me.Health
			end
			GridBattle.EndTurn(state)
			me.Health = 1000000
		end
		return parried / math.max(1, parried + hit), lostTotal / math.max(1, hit)
	end
	local rate, avgHit = parryRate(0, 0)
	check(rate > 0.38 and rate < 0.62, "보정값 100% 여도 자동 패링은 약 50%, 실제 " .. rate)
	local rateAgi = parryRate(100, 0)
	check(rateAgi > 0.38 and rateAgi < 0.62, "민첩 100 을 얹어도 약 50%, 실제 " .. rateAgi)
	-- 체력 스탯: 받는 피해 감소(점당 0.1%, 최대 20%) — 같은 씨앗 같은 공격이면 맞는 한 방이 그만큼 줄어든다
	local _, hitVit = parryRate(0, 100)
	check(hitVit < avgHit * 0.97 and hitVit > avgHit * 0.8, "체력 100 이면 맞는 피해 약 −10%, 실제 " .. hitVit .. " / " .. avgHit)
end

print("party_no_qte_test 통과")
