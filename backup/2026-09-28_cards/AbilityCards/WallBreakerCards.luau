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
		Name = "무너진 성벽",
		Description = "[허물 벽] 상한이 {5} 증가하는 대신, 스택당 받는 피해량 증가가 {5}%로 증가한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_E_SelfHarm",
		Name = "자해",
		Description = "`제 살 깎기` 스킬을 자신에게 쓰는 대신, [허물 벽]을 {5}스택 회복하고, 자해로 인한 피해를 {50}% 감소시킨다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Brink" },
	},
	{
		Id = "WallBreaker_E_Martyrdom",
		Name = "순교",
		Description = "사망한 아군마다 [허물 벽] 스택을 {5}까지 획득하고, 그 전투동안 가하는 피해량이 {20}% 증가한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_E_Levelling",
		Name = "평탄화",
		Description = "`허물다` 스킬의 범위가 적 진영 전체가 되는 대신, [허물 벽] 스택당 피해량이 {7}%로 감소한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "WallBreaker_R_SoftBlow",
		Name = "동정",
		Description = "`제 살 깎기` 스킬이 아군에게 가하는 피해가 최대 체력의 {13}%로 줄어든다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice" },
	},
	{
		Id = "WallBreaker_R_Salvage",
		Name = "잔해 회수",
		Description = "`허물다` 스킬로 적을 처치할 때마다 [허물 벽] 스택을 {1} 획득한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_R_Madness",
		Name = "광증",
		Description = "잃은 체력 비례 피해량 상한이 {35}%로 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_R_Swallow",
		Name = "섭취",
		Description = "`허물다` 스킬로 가한 피해량의 {20}%만큼 회복한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_R_PaidBack",
		Name = "앙갚음",
		Description = "`제 살 깎기` 스킬로 피해를 받은 자신을 포함한 아군은 해당 전투동안 가하는 피해량이 {25}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_R_Reliquary",
		Name = "성유물",
		Description = "매 턴, 자신의 신앙심 스탯이 {3} 상승한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_R_Overkill",
		Name = "뒤처리",
		Description = "`허물다` 스킬 사용 후 적의 체력을 초과한 피해량의 {60}%를 다음 턴 아무 스킬에나 추가 한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_R_Dirge",
		Name = "만가",
		Description = "신앙심 스탯이 {40} 이상일 경우, `허물다` 스킬 사용 시 소모 스택이 {1} 감소한다. (단, 피해량 버프는 감소하지 "
			.. "않는다.)",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Vanguard" },
	},
	{
		Id = "WallBreaker_R_ChainCollapse",
		Name = "연쇄 붕괴",
		Description = "`무너뜨리기` 스킬로 {2}명 이상의 적에게 피해를 가할 시 [허물 벽]을 {1} 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Sacrifice" },
	},
	{
		Id = "WallBreaker_R_DullFlesh",
		Name = "무딘 살",
		Description = "[허물 벽] 스택당 받는 피해량 증가가 {0.2}% 감소한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Vanguard" },
	},

	--=== 일반 (20) ===--
	{
		Id = "WallBreaker_C_Shard",
		Name = "파편",
		Description = "피해를 받을 때 [허물 벽]을 획득할 확률이 {20}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_Tenacity",
		Name = "악착",
		Description = "체력이 {30}% 이하일 때, [허물 벽] 획득량이 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_RuinPrayer",
		Name = "폐허의 기도",
		Description = "행동하지 않고 턴을 마치면 신앙심 스탯이 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_SameStride",
		Name = "자비",
		Description = "같은 행의 월 필그림스 아군에게 주는 신앙심이 {4} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_FirstCrack",
		Name = "이미 새겨진 균열",
		Description = "매 턴, [허물 벽] {1}을 획득할 확률이 {30}%가 된다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_LooseBrick",
		Name = "헐거운 벽돌",
		Description = "`쪼개기` 스킬로 타격을 할 때마다 [허물 벽]을 {1}스택 얻는다.(턴당 {1}회)",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_ShoveOff",
		Name = "밀어내기",
		Description = "모든 스킬이 적중 시 적을 한 칸 밀언며, 더이상 밀리지 않을 시 고정피해 {50}을 가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_FleshPrice",
		Name = "살점 값",
		Description = "`제 살 깎기` 스킬로 얻는 [허물 벽] 스택이 {1} 증가한다.[허물 벽]의 상한이 {2} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_RuinOath",
		Name = "파괴의 맹세",
		Description = "신앙심 스탯 {10}당 가하는 피해량이 {2}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_DebrisPlus",
		Name = "잔해 강화",
		Description = "`잔해` 패시브로 얻는 [허물 벽] 스택이 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_ShortWindup",
		Name = "광적인 파괴",
		Description = "[허물 벽]이 {7}스택 이상일 때, `허물다` 스킬의 쿨타임이 {2}턴 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_Defenceless",
		Name = "무방비",
		Description = "방어하지 않은 턴에 가하는 피해량이 {10}% 증가하는 대신, 받는 피해량이 {15}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_WeakPoint",
		Name = "약점 파괴",
		Description = "[허물 벽] 중첩 {1}당 치명타 확률이 {2}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_C_Comrade",
		Name = "병 주고 약 주기",
		Description = "`제 살 깎기` 스킬로 가한 피해량의 {30}%를 회복시킨다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Faith" },
	},
	{
		Id = "WallBreaker_C_Oblation",
		Name = "제물",
		Description = "적 처치 시 신앙심 스탯이 {2} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallBreaker_C_LongHaft",
		Name = "긴 자루",
		Description = "[허물 벽]을 {7} 이상 보유중일 경우, `쪼개기` 스킬의 사거리가 한 칸 앞으로 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard" },
	},
	{
		Id = "WallBreaker_C_Cliff",
		Name = "벼랑",
		Description = "체력이 {30}% 이하일 때 [허물 벽] 중첩당 피해량 증가가 {3}% 추가로 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "WallBreaker_C_LightHand",
		Name = "무뎌진 죄책감",
		Description = "[허물 벽] 스택이 {4} 이하일 때, `제 살 깎기` 스킬의 쿨타임이 {1}턴 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice" },
	},
	{
		Id = "WallBreaker_C_Tireless",
		Name = "최선의 교본",
		Description = "`제 살 깎기` 스킬 사용 시 아군 전체의 신앙심 스탯이 {10} 상승한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Vanguard", "Brink" },
	},
	{
		Id = "WallBreaker_C_SharedLoad",
		Name = "광인",
		Description = "가하는 피해량이 {20}% 증가하고, 받는 피해량이 {20}% 증가한다.(주석: 레벨이 오를 때마다 가하는 피해량과 받는 피해량도 "
			.. "같이 증가함. 주석은 인게임 설명에 반영되지 않음.)",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Sacrifice", "Brink" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
