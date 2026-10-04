--!strict
--[[
	WallMasonCards — 월 메이슨(WallMason) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — **쌓아 올리는** 쪽.

	수치 앵커
	  벽 = 3턴, 최대 5중첩, 중첩 1당 방어 +4% / 회피·패링 +2%
	       자신의 기도력 10당 수치 +10% (최대 +50%)
	  정 다듬기 26 / 뒷벽 허물기 22 / 축성 = 아군 전체 벽 3중첩
	  패시브 쌓기 = 아군이 [벽]을 유지한 채 턴을 마치면 자신이 1중첩 획득 (턴당 1회)
	  패시브 버팀목 = [벽]이 상한까지 찬 아군은 치명타를 맞지 않음

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Construct  **속도**. 누구에게 얼마나 자주 [벽]을 얹느냐.
	  Plating    **밀도**. 중첩 하나의 값을 키운다. 적게 갖고 세게.
	  Endure     **수명**. 오래 가게 하고, 사라질 때 값을 남긴다.
	  Faith      **기도력**. 구간에 닿으면 다른 축의 규칙이 바뀐다.

	축끼리 수치를 더하지 않는다. **조건을 만들고 지불한다**:
	  Construct가 "아군 전원이 [벽]을 가졌다"를 만들면 → Faith가 그 수를 피해로 바꾼다.
	  Plating이 상한 중첩을 만들면 → Endure가 그 상태에만 붙는 값을 지불한다.
	  Endure가 "[벽]이 사라지는 순간"을 만들면 → Construct가 거기서 다시 채운다.
	  Faith가 40에 닿으면 → 지속이 초기화 대신 **누적**되어 유지 빌드가 열린다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "WallMason"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "WallMason_E_Cathedral",
		Art = "WallMason_E_Cathedral",
		Name = "대성당",
		Description = "[벽] 상한이 {5} 증가하고 스택당 얻는 버프량이 {70}%가 된다.\n"
			.. "위 효과는 곱연산으로 계산된다.\n"
			.. "소숫점 버림.",
		-- 2026-10-04: 석공의 손과 겹쳐 벽 20 스택이 너무 셌다 → 상한 증가 +15 → +8(사용자)
		Levels = { { 5, 8 }, { 70, 100 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
	{
		Id = "WallMason_E_MasonHand",
		Art = "WallMason_E_MasonHand",
		Name = "석공의 손",
		Description = "[벽]이 방어 버프가 아닌, 공격 버프가 된다.\n[받는 피해량] 감소와 자동 회피가 사라진다.\n대신 다음 효과를 얻는다.\n스택 1당 [가하는 피해량] {5}% 증가\n스택 1당 [치명타 확률] {2}% 증가\n스택 1당 [치명타 피해량] {2}% 증가",
		Levels = { { 5, 8 }, { 2, 4 }, { 2, 3 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Faith" },
	},
	{
		Id = "WallMason_E_Cornerstone",
		Art = "WallMason_E_Cornerstone",
		Name = "초석",
		Description = "`축성` 스킬의 범위가 지정 아군 하나로 바뀐다.\n"
			.. "대신 다음 효과를 얻는다.\n"
			.. "[벽] 스택 부여량 +{2}.\n"
			.. "[가하는 피해량] 증가 {20}% 부여.\n"
			.. "`축성` 스킬의 쿨타임이 {2}턴으로 감소.",
		Levels = { { 2, 3 }, { 20, 30 }, { 2, 1 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Endure" },
	},
	{
		Id = "WallMason_E_InterlockedStone",
		MaxLevel = 1,
		Art = "WallMason_E_InterlockedStone",
		Name = "맞물린 돌",
		Description = "아군 중 가장 많은 [벽]을 보유한 아군의 [벽] 스택을 항상 가져온다.\n"
			.. "대신 자동 회피와 패리 효과를 얻지 못한다.",
		Party = true,
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Plating" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "WallMason_R_ChiselMastery",
		MaxLevel = 1,
		Art = "WallMason_R_ChiselMastery",
		Name = "정 다듬기 숙련",
		Description = "`정 다듬기`스킬이 [벽]을 {1}중첩 더 부여한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_R_FinishedWall",
		Art = "WallMason_R_FinishedWall",
		Name = "완성된 벽",
		Description = "[벽]이 {5}스택 이상인 아군이 [가하는 피해량]이 {10}% 증가한다.",
		Levels = { { 5, 5, 5, 5, 5, 5 }, { 10, 13, 16, 19, 22, 25 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_R_Mortar",
		Art = "WallMason_R_Mortar",
		Name = "회반죽",
		Description = "[벽]이 사라질 때 그 아군이 최대 체력의 {8}%를 회복한다.",
		Levels = { { 8, 9, 10, 11, 12, 13 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_R_Quarry",
		MaxLevel = 4,
		Art = "WallMason_R_Quarry",
		Name = "채석장",
		Description = "자신이 적을 처치 시 아군 전체가 [벽]을 {1}스택 얻는다.",
		Levels = { { 1, 2, 3, 4 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_R_Blessing",
		Art = "WallMason_R_Blessing",
		Name = "축복",
		Description = "전투 시작 시 신앙심이 {12} 상승한다.",
		Levels = { { 12, 16, 20, 24, 28, 32 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_R_BackRowAim",
		Art = "WallMason_R_BackRowAim",
		Name = "후열 조준",
		-- 2026-10-04 기본 벽당 6% → 3% 에 맞춰 절반으로(9~24% → 4.5~12%)
		Description = "`뒷벽 허물기`스킬의 [벽] 중첩당 [가하는 피해량] 증가가 {4.5}%로 증가한다.",
		Levels = { { 4.5, 6, 7.5, 9, 10.5, 12 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
	{
		Id = "WallMason_R_Buttress",
		MaxLevel = 1,
		Art = "WallMason_R_Buttress",
		Name = "버팀벽",
		Description = "[벽]을 보유한 동안 [그로기]가 {50}% 덜 찬다.",
		Levels = { { 50 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_R_Keystone",
		Art = "WallMason_R_Keystone",
		Name = "쐐기돌",
		Description = "[벽]을 가진 아군 하나당 자신의 [가하는 피해량]이 {5}%씩, 최대 {20}%까지 증가한다.",
		Levels = { { 5, 6, 7, 8, 9, 10 }, { 20, 24, 28, 32, 36, 40 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Faith" },
	},
	{
		Id = "WallMason_R_Consecration",
		Art = "WallMason_R_Consecration",
		Name = "성별",
		Description = "자신의 신앙심이 {40}이라면, [벽]을 부여할 때마다 지속시간이 갱신되는 것이 아닌 {3}턴씩 더해진다.",
		Levels = { { 40, 35, 30, 25, 20, 15 }, { 3, 3, 3, 3, 3, 3 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Endure" },
	},
	{
		Id = "WallMason_R_Relayer",
		Art = "WallMason_R_Relayer",
		Name = "재적층",
		Description = "턴당 {2}회, [벽]의 지속시간이 끝나 사라진다면, 해당 아군은 즉시 사라진 [벽]의 {10}%를 돌려받는다.\n"
			.. "(최솟값 {1})",
		Levels = { { 2, 3, 4, 5, 6, 7 }, { 10, 20, 30, 40, 50, 60 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Construct" },
	},

	--=== 일반 (20) ===--
	{
		Id = "WallMason_C_Harden",
		MaxLevel = 3,
		Art = "WallMason_C_Harden",
		Name = "굳히기",
		Description = "[벽] 지속시간이 {1}턴 연장된다.\n"
			.. "`성별` 카드와 같이 사용된다면, 더해지는 지속시간의 값이 {4}로 증가한다.",
		Levels = { { 1, 2, 3 }, { 4, 5, 6 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_EvenBreath",
		MaxLevel = 2,
		Art = "WallMason_C_EvenBreath",
		Name = "고른 숨",
		Description = "[벽] {1}스택당 스테미나 회복량이 {1} 증가한다.",
		Levels = { { 1, 1 }, { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Endure" },
	},
	{
		Id = "WallMason_C_MasonPrayer",
		Art = "WallMason_C_MasonPrayer",
		Name = "석공의 기도",
		Description = "`호흡`으로 턴을 마치면, 신앙심이 {4} 증가한다.",
		Levels = { { 4, 6, 8, 10, 12, 14 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_SameStone",
		Art = "WallMason_C_SameStone",
		Name = "같은 돌",
		Description = "같은 행의 월 필그림스 아군에게 주는 신앙심이 {4} 더 증가한다.",
		Levels = { { 4, 5, 6, 7, 8, 9 } },
		Party = true,
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_Groundwork",
		MaxLevel = 3,
		Art = "WallMason_C_Groundwork",
		Name = "터 다지기",
		Description = "전투 시작 시 아군 전체가 [벽] {1}중첩을 얻는다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_SelfBulwark",
		MaxLevel = 1,
		Art = "WallMason_C_SelfBulwark",
		Name = "자기 방벽",
		Description = "턴을 시작할 때 자신이 [벽] {1}중첩을 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Endure" },
	},
	{
		Id = "WallMason_C_DriveWedge",
		MaxLevel = 3,
		Art = "WallMason_C_DriveWedge",
		Name = "쐐기 박기",
		Description = "`정 다듬기` 스킬의 [벽]이 본인 대신 체력이 가장 낮은 아군이 부여받는다.\n"
			.. "그 아군이 자신이면 {1}중첩 더 부여한다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Overlay",
		MaxLevel = 2,
		Art = "WallMason_C_Overlay",
		Name = "덧대기",
		Description = "턴당 {1}회, 이미 [벽]이 있는 아군에게 중첩을 줄 때 {1}중첩 더 부여한다.",
		Levels = { { 1, 1 }, { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_C_Grit",
		Art = "WallMason_C_Grit",
		Name = "근성",
		Description = "체력이 {50}% 미만일 때, [벽] 효과가 {20}% 증가한다.",
		Levels = { { 50, 50, 50, 50, 50, 50 }, { 20, 25, 30, 35, 40, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_MasonOath",
		MaxLevel = 4,
		Art = "WallMason_C_MasonOath",
		Name = "석공의 맹세",
		Description = "신앙심 {10}당 자신의 피해량이 {3}%씩, 최대 {15}%까지 증가한다.",
		Levels = { { 10, 10, 10, 10 }, { 3, 4, 5, 5 }, { 15, 18, 21, 24 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_QuickRite",
		MaxLevel = 2,
		Art = "WallMason_C_QuickRite",
		Name = "빠른 축성",
		Description = "3스킬 재사용 대기가 {1}턴 감소한다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Deflect",
		Art = "WallMason_C_Deflect",
		Name = "빗겨내기",
		Description = "[벽]이 있는 아군의 회피·패링률이 {3}% 더 증가한다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Endure" },
	},
	{
		Id = "WallMason_C_StonePicking",
		MaxLevel = 2,
		Art = "WallMason_C_StonePicking",
		Name = "돌 고르기",
		Description = "아군이 [벽]을 유지한 채 턴을 마칠 때 얻는 중첩이 {1} 증가한다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Plating" },
	},
	{
		Id = "WallMason_C_LongChisel",
		Art = "WallMason_C_LongChisel",
		Name = "긴 정",
		Description = "2스킬이 위아래 줄의 맨 앞 적에게도 {40}%의 피해를 준다.",
		Levels = { { 40, 45, 50, 55, 60, 70 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Footstone",
		Art = "WallMason_C_Footstone",
		Name = "밑돌",
		Description = "전투 시작 시 아군 전체에게 {8}의 보호막을 제공한다.",
		Levels = { { 8, 10, 12, 14, 16, 20 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Faith" },
	},
	{
		Id = "WallMason_C_LuckyChisel",
		Art = "WallMason_C_LuckyChisel",
		Name = "운 좋은 정",
		Description = "2스킬의 치명타 확률이 {3}% 증가한다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_C_Sharing",
		MaxLevel = 2,
		Art = "WallMason_C_Sharing",
		Name = "나눔",
		Description = "턴당 {1}회, 자신이 [벽]을 얻으면 인접한 아군도 {1}중첩 얻는다.",
		Levels = { { 1, 1 }, { 1, 2 } },
		Party = true,
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Faith" },
	},
	{
		Id = "WallMason_C_Cushion",
		Art = "WallMason_C_Cushion",
		Name = "완충",
		Description = "[벽]이 있는 아군이 받는 치명타 피해가 {20}% 감소한다.",
		Levels = { { 20, 24, 28, 32, 36, 40 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_StoneOffering",
		Art = "WallMason_C_StoneOffering",
		Name = "헌석",
		Description = "적을 처치하면 신앙심이 {6} 상승한다.",
		Levels = { { 6, 7, 8, 9, 10, 12 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_Tireless",
		MaxLevel = 2,
		Art = "WallMason_C_Tireless",
		Name = "쉬지 않는 축조",
		Description = "매 턴 [벽] {1}중첩을 얻는다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
