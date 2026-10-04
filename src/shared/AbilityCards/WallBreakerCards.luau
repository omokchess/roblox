--!strict
--[[
	WallBreakerCards — 월 브레이커(WallBreaker) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — **부수는** 쪽. 아군을 갈아 넣어 단일 화력을 뽑는다.

	수치 앵커
	  허물 벽 = 지속 없음(영구), 최대 5중첩
	            중첩 1당 피해 +5% (최대 +25%) / 받는 피해 +3%
	  쪼개기 22 / 무너뜨리기 18 / 허물다 26 (5중첩 소모 시 41)
	  패시브 광적인 맹세 = 잃은 체력에 비례해 피해량 증가 (최대 +20%)
	  패시브 잔해 = [허물 벽]을 소모해 처치하면 소모한 중첩의 절반을 돌려받음

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Vanguard   **터뜨리기**. 중첩을 쌓아 3스킬 한 방에 싣고, 회수해서 다시 쌓는다.
	  Sacrifice  **갈아 넣기**. 아군이나 자신을 쳐서 중첩을 번다.
	  Brink      **벼랑**. 깎여 나간 체력 자체를 자산으로 쓴다.
	  Faith      **기도력**. 구간에 닿으면 규칙이 바뀐다.

	축끼리 수치를 더하지 않는다. **대가와 지불처를 서로에게 넘긴다**:
	  Sacrifice가 체력을 깎으면 → Brink가 그 낮아진 체력을 값으로 바꾼다.
	  Vanguard가 중첩을 상한까지 쌓으면 → Faith가 소모 규칙 자체를 바꾼다(만가).
	  Brink가 30% 아래를 만들면 → Vanguard의 중첩 수급이 달라진다.

	그래서 자해 없이 천천히 쌓아도, 아군을 태워 즉발로 가도, 벼랑에서 굴러도 다 굴러간다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "WallBreaker"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "WallBreaker_E_BrokenRampart",
		Art = "WallBreaker_E_BrokenRampart",
		Name = "무너진 성벽",
		Description = "[허물 벽] 상한이 {5} 증가하는 대신, 스택당 받는 피해량 증가가 {5}%로 증가한다.",
		Levels = { { 5, 8 }, { 5, 7 } },
		Excludes = { "WallBreaker_E_SelfHarm" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_E_SelfHarm",
		Art = "WallBreaker_E_SelfHarm",
		Name = "자해",
		Description = "`제 살 깎기` 스킬을 자신에게 사용하는 대신, [허물 벽]을 {5} 얻고, 자해로 인한 피해를 {50}% 감소시킨다.",
		Levels = { { 5, 7 }, { 50, 70 } },
		Excludes = { "WallBreaker_E_BrokenRampart" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Brink" },
	},
	{
		Id = "WallBreaker_E_Martyrdom",
		Art = "WallBreaker_E_Martyrdom",
		Name = "순교",
		Description = "사망한 아군마다 절대 소모되지 않는 [허물 벽]을 {3}까지 획득하고, 그 전투동안 [가하는 피해량]이 {20}% 증가한다.",
		Levels = { { 3, 5 }, { 20, 25 } },
		Party = true,
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_E_Levelling",
		Art = "WallBreaker_E_Levelling",
		Name = "평탄화",
		Description = "`허물다` 스킬의 범위가 적 진영 전체가 되는 대신, [허물 벽] 스택당 피해량이 {7}%가 된다.",
		Levels = { { 7, 12 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "WallBreaker_R_SoftBlow",
		Art = "WallBreaker_R_SoftBlow",
		Name = "동정",
		Description = "`제 살 깎기` 스킬이 아군에게 가하는 피해가 최대 체력의 {13}%로 줄어든다.",
		Levels = { { 13, 12, 11, 10, 9, 8 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice" },
	},
	{
		Id = "WallBreaker_R_Salvage",
		MaxLevel = 1,
		Art = "WallBreaker_R_Salvage",
		Name = "잔해 회수",
		Description = "`허물다` 스킬로 적을 처치할 때마다 [허물 벽] 스택을 {1} 획득한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_R_Madness",
		Art = "WallBreaker_R_Madness",
		Name = "광증",
		Description = "잃은 체력 비례 [가하는 피해량] 증가 상한이 {35}%로 증가한다.",
		Levels = { { 35, 40, 50, 55, 60, 65 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_R_Swallow",
		Art = "WallBreaker_R_Swallow",
		Name = "섭취",
		Description = "`허물다` 스킬로 가한 피해량의 {20}%만큼 회복한다.",
		Levels = { { 20, 23, 26, 29, 32, 35 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_R_PaidBack",
		Art = "WallBreaker_R_PaidBack",
		Name = "앙갚음",
		Description = "`제 살 깎기` 스킬로 피해를 받은 자신을 포함한 아군은 해당 전투동안 [가하는 피해량]이 {25}% 증가한다.",
		Levels = { { 25, 27, 29, 31, 33, 35 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_R_Reliquary",
		Art = "WallBreaker_R_Reliquary",
		Name = "성유물",
		Description = "매 턴, 자신의 신앙심 스탯이 {3} 상승한다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_R_Overkill",
		MaxLevel = 5,
		Art = "WallBreaker_R_Overkill",
		Name = "뒤처리",
		Description = "`허물다` 스킬 사용 후 적의 체력을 초과한 피해량의 {60}%를 다음 턴 아무 스킬에나 추가 한다.",
		Levels = { { 60, 70, 80, 90, 100 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_R_Dirge",
		Art = "WallBreaker_R_Dirge",
		Name = "만가",
		Description = "신앙심 스탯이 {40} 이상일 경우, `허물다` 스킬 사용 시 소모하는 [허물 벽]이 {1} 감소한다.\n"
			.. "([가하는 피해량] 증가 버프는 감소하지 않는다.)",
		Levels = { { 40, 38, 36, 34, 32, 30 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Vanguard" },
	},
	{
		Id = "WallBreaker_R_ChainCollapse",
		MaxLevel = 1,
		Art = "WallBreaker_R_ChainCollapse",
		Name = "연쇄 붕괴",
		Description = "`무너뜨리기` 스킬로 {2}명 이상의 적에게 피해를 가할 시 [허물 벽]을 {1} 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Sacrifice" },
	},
	{
		Id = "WallBreaker_R_DullFlesh",
		MaxLevel = 5,
		Art = "WallBreaker_R_DullFlesh",
		Name = "무딘 살",
		Description = "[허물 벽] 스택당 [받는 피해량] 증가가 {0.2}% 감소한다.",
		Levels = { { 0.2, 0.4, 0.6, 0.8, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Vanguard" },
	},

	--=== 일반 (20) ===--
	{
		Id = "WallBreaker_C_Shard",
		Art = "WallBreaker_C_Shard",
		Name = "파편",
		Description = "피해를 받을 때 [허물 벽]을 획득할 확률이 {20}% 증가한다.",
		Levels = { { 20, 25, 30, 35, 40, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_Tenacity",
		Art = "WallBreaker_C_Tenacity",
		Name = "악착",
		Description = "체력이 {30}% 이하일 때, [허물 벽] 획득량이 {1} 증가한다.",
		Levels = { { 30, 32, 34, 36, 38, 40 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_RuinPrayer",
		MaxLevel = 3,
		Art = "WallBreaker_C_RuinPrayer",
		Name = "폐허의 기도",
		Description = "공격 스킬을 사용하지 않고 턴을 마치면 신앙심 스탯이 {1} 증가한다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_SameStride",
		Art = "WallBreaker_C_SameStride",
		Name = "자비",
		Description = "`순례길` 패시브의 신앙심 버프량이 {1} 증가한다.",
		Levels = { { 1, 2, 3, 4, 5, 6 } },
		Party = true,
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_FirstCrack",
		MaxLevel = 3,
		Art = "WallBreaker_C_FirstCrack",
		Name = "이미 새겨진 균열",
		Description = "전투 시작 시, [허물 벽]을 {1} 얻는다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_LooseBrick",
		MaxLevel = 3,
		Art = "WallBreaker_C_LooseBrick",
		Name = "헐거운 벽돌",
		Description = "`쪼개기` 스킬이 적중 할 때마다 [허물 벽]을 {1}스택 얻는다.(턴당 {1}회)",
		Levels = { { 1, 1, 1 }, { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_ShoveOff",
		Art = "WallBreaker_C_ShoveOff",
		Name = "밀어내기",
		Description = "모든 스킬이 적중 시 적을 한 칸 밀어내며, 밀리기 전의 적이 끝 행에 있다면 고정피해 {50}을 가한다.",
		Levels = { { 50, 60, 70, 80, 90, 100 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_FleshPrice",
		MaxLevel = 2,
		Art = "WallBreaker_C_FleshPrice",
		Name = "살점 값",
		Description = "`제 살 깎기` 스킬로 얻는 [허물 벽] 스택이 {1} 증가한다.[허물 벽]의 상한이 {2} 증가한다.",
		Levels = { { 1, 2 }, { 2, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_RuinOath",
		Art = "WallBreaker_C_RuinOath",
		Name = "파괴의 맹세",
		Description = "신앙심 스탯 {10}당 [가하는 피해량]이 {2}% 증가한다.",
		Levels = { { 10, 10, 10, 10, 10, 10 }, { 2, 3, 4, 5, 6, 7 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_DebrisPlus",
		Art = "WallBreaker_C_DebrisPlus",
		Name = "더 많은 잔해",
		Description = "`잔해` 패시브로 돌려받는 [허물 벽]의 양이 {5}% 증가한다.\n"
			.. "이 효과는 합연산으로 계산된다.\n"
			.. "소숫점 버림.\n"
			.. "최종 페이백 비율: {55}%",
		Levels = { { 5, 10, 15, 20, 25, 30 }, { 55, 60, 65, 70, 75, 80 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_ShortWindup",
		MaxLevel = 2,
		Art = "WallBreaker_C_ShortWindup",
		Name = "광적인 파괴",
		Description = "[허물 벽]이 {7}스택 이상일 때, `허물다` 스킬의 쿨타임이 {2}턴 감소한다.",
		Levels = { { 7, 6 }, { 2, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_Defenceless",
		Art = "WallBreaker_C_Defenceless",
		Name = "무방비",
		Description = "패리 혹은 방어에 실패한 턴 다음 턴에 [가하는 피해량]이 {10}% 증가하는 대신, [받는 피해량]이 {15}% 증가한다.",
		Levels = { { 10, 11, 12, 13, 14, 15 }, { 15, 14, 13, 12, 11, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_WeakPoint",
		MaxLevel = 4,
		Art = "WallBreaker_C_WeakPoint",
		Name = "약점 파괴",
		Description = "[허물 벽] 중첩 {2}당 치명타 확률이 {2}% 증가한다.",
		Levels = { { 2, 2, 2, 2 }, { 2, 3, 4, 5 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_C_Comrade",
		MaxLevel = 5,
		Art = "WallBreaker_C_Comrade",
		Name = "병 주고 약 주기",
		Description = "`제 살 깎기` 스킬로 가한 피해량의 {30}%를 회복시킨다.\n"
			.. "이 효과는 자해 카드로 인한 피해도 포함된다.",
		Levels = { { 30, 35, 40, 45, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_C_Oblation",
		Art = "WallBreaker_C_Oblation",
		Name = "제물",
		Description = "적 처치 시, 신앙심 스탯이 {2} 증가한다.",
		Levels = { { 2, 3, 4, 5, 6, 7 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_LongHaft",
		Art = "WallBreaker_C_LongHaft",
		Name = "긴 자루",
		Description = "[허물 벽]을 {7} 이상 보유중일 경우, `쪼개기` 스킬의 사거리가 한 칸 앞으로 증가한다.",
		Levels = { { 7, 6, 5, 4, 3, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_Cliff",
		MaxLevel = 3,
		Art = "WallBreaker_C_Cliff",
		Name = "벼랑",
		Description = "체력이 {30}% 이하일 때 [허물 벽] 중첩당 [가하는 피해량]이 {3}% 증가한다.",
		Levels = { { 30, 40, 50 }, { 3, 4, 5 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_LightHand",
		MaxLevel = 5,
		Art = "WallBreaker_C_LightHand",
		Name = "무뎌진 죄책감",
		Description = "[허물 벽] 스택이 {4} 이하일 때, `제 살 깎기` 스킬의 쿨타임이 {1}턴 감소한다.",
		Levels = { { 4, 5, 6, 7, 7 }, { 1, 1, 1, 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_Tireless",
		Art = "WallBreaker_C_Tireless",
		Name = "최선의 교본",
		Description = "`제 살 깎기` 스킬 사용 시 아군 전체의 신앙심 스탯이 {10} 상승한다.\n"
			.. "(전투당 {1}회.)",
		Levels = { { 10, 15, 20, 25, 30, 35 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_C_SharedLoad",
		Art = "WallBreaker_C_SharedLoad",
		Name = "광인",
		Description = "가하는 피해량이 {20}% 증가하고, 받는 피해량이 {20}% 증가한다.",
		Levels = { { 20, 30, 40, 50, 60, 70 }, { 20, 30, 40, 50, 60, 70 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Brink" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
