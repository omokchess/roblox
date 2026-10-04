--!strict
--[[
	AlchemistCards — 연금술사(Alchemist) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` + 유저가 도감에서 직접 고친 원고(card_edits.json).

	수치 앵커
	  약재 최대 6 (턴당 +1) / 원액 최대 4 / 빈 병 최대 8 / 꽉 찬 병 종류당 최대 4
	  다지기 = 소모 약재만큼 가하는 피해 +10~25%, 받는 피해도 같은 값 (최대 5중첩)
	  던지기 40 / 중독(강화) 고정 40

	필수는 **탱 1 · 딜 1**로 갈린다.
	  때리면서 섞기      → 딜 전직 (1·2스킬에 피해가 붙는다)
	  로우리스크 로우리턴 → 탱 전직 (부작용이 전부 방어로 뒤집힌다)
	나머지 둘은 방향을 바꾸지 않고 병 운용을 바꾼다.

	--------------------------------------------------------------------------
	글과 수치 규격 (요청)

	  1. **반말.** "…증가한다", "…얻는다". 아홉 직업 중 연금술사만 먼저 바꿨다.
	  2. **"(레벨당 +n)"을 쓰지 않는다.** 대신 값을 중괄호로 감싸고(`{3}`)
	     `Levels`에 레벨별 값을 늘어놓는다. 화면에는 지금 레벨의 숫자가 직접 찍힌다.
	     → `AbilityCardDefinitions.Describe(card, level)`

	     중괄호 안 숫자는 **레벨 1의 값**이다. 몇 번째 사다리인지는 글에 나온
	     순서가 정한다 — 번호를 적던 예전 방식은 글과 뜻이 달라 헷갈렸다.

	  `Levels`의 길이는 등급 상한과 같다. 필수 2칸, 희귀·일반 6칸.

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Brew      **재고**. 약재·빈 병·원액을 벌어 병을 끊기지 않게 만든다.
	  Catalyst  **폭발**. 만든 병을 한 번에 태워 크게 터뜨린다.
	  Burn      **지속**. 화상·독·기름을 겹쳐 시간으로 죽인다.
	  Brink     **대가**. 도핑의 부작용을 안고 그 낮은 체력을 값으로 쓴다.

	축끼리 수치를 더하지 않는다. **재고가 조건이 되고 대가가 조건이 된다**:
	  Brew가 네 종류를 다 갖추면  → Catalyst의 던지기 규칙 자체가 바뀐다(가득 찬 가방).
	  Catalyst가 크게 터뜨리면    → Brink가 그 부작용을 값으로 되받는다.
	  Burn이 기름을 깔면          → 화염병 한 장의 값이 달라진다(촉진제·점화).
	  Brink가 체력을 내주면       → Brew의 회복 계열이 그 구멍을 메운다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Alchemist"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Alchemist_E_MixAndStrike",
		Art = "때리면서_섞기",
		Name = "때리면서 섞기",
		Description = "`다지기` 스킬에 피해량 {15}가 붙고 범위가 (n,n)이 된다.`섞기` 스킬에 피해량 {20}이 붙고 범위가 (n,n)이 된다.\n"
			.. "각 스킬을 쓸 때마다 [도발]을 {1} 얻는다.\n"
			.. "각 피해들은 고정피해를 가하며, 버프로 피해량을 증가시킬 수 없다.",
		Levels = { { 15, 22 }, { 20, 28 }, { 1, 1 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Catalyst", "Brew" },
	},
	{
		Id = "Alchemist_E_LowRisk",
		Art = "새_그림",
		Name = "로우리스크 로우리턴",
		Description = "스킬로 얻는 부작용이 전부 [받는 피해량] 감소로 바뀐다.\n"
			.. "대신 [가하는 피해량]이 {50}% 감소한다.\n"
			.. "매 공격마다 [도발]을 {5} 얻는다.\n"
			.. "부작용은 체력 감소도 포함된다.",
		Levels = { { 50, 35 }, { 5, 5 } },
		Excludes = { "Alchemist_E_SelfPrescribe" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Brew" },
	},
	{
		Id = "Alchemist_E_OneShot",
		Art = "때리면서_섞기",
		Name = "원샷",
		Description = "`중독` 스킬 사용 시 [꽉 찬 병]을 소모 후 소모한 모든 [꽉 찬 병]을 돌려받는다.\n"
			.. "중독을 사용한 턴 이후 {2}턴간 [꽉 찬 병]을 만들지 못한다.",
		Levels = { { 2, 1 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Catalyst" },
	},
	{
		Id = "Alchemist_E_SelfPrescribe",
		MaxLevel = 1,
		Art = "새_그림",
		Name = "과다복용",
		Description = "`중독` 스킬 사용 시 얻는 모든 버프와 디버프를 두 배로 얻는다.",
		Excludes = { "Alchemist_E_LowRisk" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Brink" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Alchemist_R_IronStomach",
		Art = "Alchemist_R_IronStomach",
		Name = "강철 위장",
		Description = "`중독` 스킬 사용 시 얻는 [독 병]으로 인한 체력 감소 효과가 {10}% 감소한다.",
		Levels = { { 10, 14, 18, 22, 26, 30 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Alchemist_R_BottleKeeping",
		Art = "Alchemist_R_BottleKeeping",
		Name = "준비성",
		Description = "매 턴, [빈 병]을 {1}개 추가로 얻을 확률이 {25}% 추가된다.",
		Levels = { { 1, 1, 1, 1, 1, 1 }, { 25, 30, 35, 40, 45, 50 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_R_Distill",
		Art = "포션",
		Name = "정제",
		Description = "`섞기`를 쓰면 [화염병]을 하나 확정으로 더 얻고, 쓴 [원액] 하나마다 {32}% 확률로 [꽉 찬 병]을 하나 더 얻는다.\n화염병 말고 더 얻은 병이 없다면 [빈 병] {1}개를 돌려받는다.",
		Levels = { { 32, 34, 36, 38, 40, 42 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Catalyst" },
	},
	{
		Id = "Alchemist_R_Accelerant",
		Art = "포션",
		Name = "촉진제",
		Description = "[기름]이 걸린 적에게 주는 화상 피해가 {40}% 증가한다.",
		Levels = { { 40, 48, 56, 64, 72, 80 } },
		LevelKeywords = { "Burn" },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Alchemist_R_CriticalBlend",
		MaxLevel = 2,
		Art = "Alchemist_R_CriticalBlend",
		Name = "가득 찬 가방",
		Description = "[독 병]·[화염병]·[기름 병]을 모두 가지고 있다면, `던지기`가 병을 {2}개 던진다.",
		Levels = { { 2, 3 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Catalyst" },
	},
	{
		Id = "Alchemist_R_Reagent",
		Art = "포션",
		Name = "독성 강화",
		Description = "[독 병]의 독 부여량이 {14}로 증가한다.",
		Levels = { { 14, 16, 18, 20, 22, 24 } },
		LevelKeywords = { "Poison" },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_R_Chain",
		Art = "Alchemist_R_Chain",
		Name = "연쇄 반응",
		Description = "`던지기` 적중 시 메인 타겟에게 적용된 디버프 중 {30}%가 인접한 적에게 퍼진다.",
		Levels = { { 30, 36, 42, 48, 54, 60 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn", "Catalyst" },
	},
	{
		Id = "Alchemist_R_Antidote",
		MaxLevel = 2,
		Art = "포션",
		Name = "해독제",
		Description = "자신에게 쌓인 `부작용` 중첩 {1}개를 {2}턴마다 지운다.",
		Levels = { { 1, 1 }, { 2, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Brink" },
	},
	{
		Id = "Alchemist_R_Napalm",
		Art = "Alchemist_R_Napalm",
		Name = "네이팜",
		Description = "[화염병]의 화상 부여량이 {13}으로 증가한다.",
		Levels = { { 13, 15, 17, 19, 21, 23 } },
		LevelKeywords = { "Burn" },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Alchemist_R_Recycle",
		Art = "Alchemist_R_Recycle",
		Name = "방탄유리병",
		Description = "`던지기` 스킬 사용 시 던진 병마다 {25}% 확률로 [빈 병]을 획득한다.",
		Levels = { { 25, 30, 35, 40, 45, 50 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Catalyst" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Alchemist_C_Satisfaction",
		Art = "포션",
		Name = "만족감",
		Description = "보유한 [꽉 찬 병] {1}개당 [가하는 피해량]이 {3}% 증가한다.",
		Levels = { { 1, 1, 1, 1, 1, 1 }, { 3, 4, 5, 6, 7, 8 } },
		LevelKeywords = { "", "DamageDealt" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_C_AmpleMeasure",
		Art = "Alchemist_C_AmpleMeasure",
		Name = "넉넉한 계량",
		Description = "[약재] 상한이 {8}로 오른다.",
		Levels = { { 8, 9, 10, 11, 12, 13 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_C_Spare",
		Art = "Alchemist_C_Spare",
		Name = "여분 병",
		Description = "전투 시작 시 [빈 병]을 {2} 더 얻는다.",
		Levels = { { 2, 3, 4, 5, 6, 7 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_C_Extract",
		Art = "Alchemist_C_Extract",
		Name = "농축",
		Description = "[원액] 상한이 {6}으로 증가한다.",
		Levels = { { 6, 7, 8, 9, 10, 11 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Catalyst", "Brew" },
	},
	{
		Id = "Alchemist_C_Toxin",
		MaxLevel = 2,
		Art = "Alchemist_C_Toxin",
		Name = "별걸 다 쓰네",
		Description = "매 턴 얻는 [약재]가 {1} 증가한다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Alchemist_C_Slick",
		Art = "Alchemist_C_Slick",
		Name = "미끌미끌",
		Description = "[기름]이 걸린 적이 [가하는 피해량]이 {12}% 감소한다.",
		Levels = { { 12, 15, 18, 21, 24, 27 } },
		LevelKeywords = { "DamageDealt" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Alchemist_C_Tolerance",
		Art = "Alchemist_C_Tolerance",
		Name = "내성",
		Description = "체력이 절반 이하일 때 [받는 회복량]이 {30}% 증가한다.",
		Levels = { { 30, 34, 38, 42, 46, 50 } },
		LevelKeywords = { "DamageTaken" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Brew" },
	},
	{
		Id = "Alchemist_C_Herbal",
		Art = "Alchemist_C_Herbal",
		Name = "약초학",
		Description = "[약재] {1}당 받는 회복량이 {1}% 증가한다.",
		Levels = { { 1, 1, 1, 1, 1, 1 }, { 1, 1.2, 1.4, 1.6, 1.8, 2 } },
		LevelKeywords = { "HealTaken", "" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Brink" },
	},
	{
		Id = "Alchemist_C_Floorstart",
		Art = "포션",
		MaxLevel = 4,
		Name = "호신용 물약",
		Description = "전투 시작 시 [꽉 찬 병]을 무작위로 {1}개 얻는다.",
		Levels = { { 1, 2, 3, 4 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Catalyst" },
	},
	{
		Id = "Alchemist_C_Bulk",
		Art = "Alchemist_C_Bulk",
		Name = "고중량 고반복",
		Description = "`벌크업` 패시브의 [가하는 피해량] 증가와 [받는 피해량] 증가가 각각 {2}% 상승한다.",
		Levels = { { 2, 2.5, 3, 3.5, 4, 4.5 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Catalyst" },
	},
	{
		Id = "Alchemist_C_Insurance",
		Art = "포션",
		Name = "보험 증액",
		Description = "`보험` 패시브의 회복량이 {40}%로 증가한다.",
		Levels = { { 40, 43, 46, 49, 52, 55 } },
		LevelKeywords = { "HealTaken" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_C_Sideeffect",
		Art = "Alchemist_C_Sideeffect",
		Name = "부작용 완화",
		Description = "`부작용` 패시브로 인해 얻는 [받는 피해량] 증가 효과가 {3}% 감소한다.",
		Levels = { { 3, 3.5, 4, 4.5, 5, 5.5 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Alchemist_C_Splash",
		Art = "포션",
		Name = "커다란 약병",
		Description = "`던지기` 스킬이 인접한 적에게도 스킬 피해량의 {40}%를 가한다.",
		Levels = { { 40, 46, 52, 58, 64, 70 } },
		LevelKeywords = { "DamageDealt" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn", "Catalyst" },
	},
	{
		Id = "Alchemist_C_Killherb",
		Art = "Alchemist_C_Killherb",
		Name = "채집",
		Description = "적 처치 시 [약재]를 {2} 얻는다.",
		Levels = { { 2, 3, 4, 5, 6, 7 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew" },
	},
	{
		Id = "Alchemist_C_Cooldown",
		MaxLevel = 2,
		Art = "Alchemist_C_Cooldown",
		Name = "시간 날 때 해둬야지",
		Description = "매 턴, [약재]를 {1}씩 소모해 [원액]을 {1} 얻는다.",
		Levels = { { 1, 1 }, { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Catalyst" },
	},
	{
		Id = "Alchemist_C_Lowhp",
		Art = "Alchemist_C_Lowhp",
		Name = "절박함",
		Description = "체력이 {30}% 이하일 때 [가하는 피해량]이 {8}% 증가한다.",
		Levels = { { 30, 30, 30, 30, 30, 30 }, { 8, 11, 14, 17, 20, 23 } },
		LevelKeywords = { "", "DamageDealt" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Alchemist_C_Sturdy",
		Art = "Alchemist_C_Sturdy",
		Name = "두꺼운 유리",
		Description = "[꽉 찬 병]과 [빈 병]의 합이 {6} 이상일 때 [받는 피해량]이 {10}% 감소한다.",
		Levels = { { 6, 6, 5, 5, 4, 4 }, { 10, 12, 14, 16, 18, 20 } },
		LevelKeywords = { "", "DamageTaken" },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Brink" },
	},
	{
		Id = "Alchemist_C_Ignite",
		Art = "포션",
		Name = "점화",
		Description = "[기름] 상태이상을 보유중인 적에게 [화염병] 적중 시 {15}의 고정피해를 가한다.",
		Levels = { { 15, 19, 23, 27, 31, 35 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Alchemist_C_Grind",
		MaxLevel = 2,
		Art = "Alchemist_C_Grind",
		Name = "통달",
		Description = "`다지기` 스킬로 얻는 [원액]이 {1} 증가한다.[약재]의 소모량은 증가하지 않는다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Catalyst", "Brew" },
	},
	{
		Id = "Alchemist_C_Steady",
		Art = "포션",
		MaxLevel = 2,
		Name = "꾸준한 조제",
		Description = "{5}턴 내에 `섞기` 스킬을 {3}회 이상 사용했다면, 무작위 [꽉 찬 병]을 {1}개 추가로 얻는다.",
		Levels = { { 5, 5 }, { 3, 2 }, { 1, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brew", "Catalyst" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
