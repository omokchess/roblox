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
		Name = "대성당",
		Description = "[벽] 상한이 {5}에서 {10}으로 오르고 중첩당 수치가 절반이 된다. 3스킬 재사용 대기가 {6}턴이 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
	{
		Id = "WallMason_E_MasonHand",
		Name = "석공의 손",
		Description = "[벽]이 방어 버프가 아닌, 공격 버프가 된다. 방어·회피가 사라지고 중첩 {1}당 피해량 +{5}%, 치명타 확률 +{2}%로 "
			.. "변경된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Faith" },
	},
	{
		Id = "WallMason_E_Cornerstone",
		Name = "초석",
		Description = "3스킬이 아군 전체 대신 아군 하나에게 부여된다. 대신 중첩이 {5}, 지속이 {5}턴, 재사용 대기가 {2}턴이 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Endure" },
	},
	{
		Id = "WallMason_E_InterlockedStone",
		Name = "맞물린 돌",
		Description = "자신의 [벽] 중첩이 아군 중 가장 높은 중첩과 항상 같아진다. 대신 자신은 [벽]의 회피·패링 효과는 받지 못한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Plating" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "WallMason_R_ChiselMastery",
		Name = "정 다듬기 숙련",
		Description = "1스킬이 [벽]을 {1}중첩 더 부여한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_R_FinishedWall",
		Name = "완성된 벽",
		Description = "[벽]이 상한까지 찬 아군은 주는 피해량이 {10}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_R_Mortar",
		Name = "회반죽",
		Description = "[벽]이 사라질 때 그 아군이 최대 체력의 {8}%를 회복한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_R_Quarry",
		Name = "채석장",
		Description = "적을 처치하면 아군 전체가 [벽] {1}중첩을 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_R_Blessing",
		Name = "축복",
		Description = "전투 시작 시 신앙심이 {12} 상승한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_R_BackRowAim",
		Name = "후열 조준",
		Description = "2스킬의 [벽] 중첩당 피해량 증가가 {6}%에서 {9}%로 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
	{
		Id = "WallMason_R_Buttress",
		Name = "버팀벽",
		Description = "[벽]이 있는 아군은 상태이상 지속 시간이 {1}턴 감소한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_R_Keystone",
		Name = "쐐기돌",
		Description = "[벽]을 가진 아군 하나당 자신의 피해량이 {5}%씩, 최대 {20}%까지 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Faith" },
	},
	{
		Id = "WallMason_R_Consecration",
		Name = "성별",
		Description = "신앙심이 {40} 이상이면, [벽]을 부여할 때 지속시간이 초기화되지 않고 더해진다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Endure" },
	},
	{
		Id = "WallMason_R_Relayer",
		Name = "재적층",
		Description = "턴당 {2}회, [벽]이 지속시간이 다해 사라지면, 그 아군이 즉시 {1}중첩을 되돌려 받는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Construct" },
	},

	--=== 일반 (20) ===--
	{
		Id = "WallMason_C_Harden",
		Name = "굳히기",
		Description = "[벽] 지속시간이 {1}턴 연장된다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_EvenBreath",
		Name = "고른 숨",
		Description = "[벽] 중첩 {1}당 스테미나 회복량이 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Endure" },
	},
	{
		Id = "WallMason_C_MasonPrayer",
		Name = "석공의 기도",
		Description = "행동하지 않고 턴을 마치면, 신앙심이 {4} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_SameStone",
		Name = "같은 돌",
		Description = "같은 행의 월 필그림스 아군에게 주는 신앙심이 {4} 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_Groundwork",
		Name = "터 다지기",
		Description = "전투 시작 시 아군 전체가 [벽] {1}중첩을 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_SelfBulwark",
		Name = "자기 방벽",
		Description = "턴을 시작할 때 자신이 [벽] {1}중첩을 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Endure" },
	},
	{
		Id = "WallMason_C_DriveWedge",
		Name = "쐐기 박기",
		Description = "1스킬의 [벽]이 대신 체력이 가장 낮은 아군이 부여받는다. 그 아군이 자신이면 {1}중첩 더 부여한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Overlay",
		Name = "덧대기",
		Description = "턴당 {1}회, 이미 [벽]이 있는 아군에게 중첩을 줄 때 {1}중첩 더 부여한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_C_Grit",
		Name = "근성",
		Description = "체력이 절반 {50}% 미만일 때, [벽] 효과가 {20}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_MasonOath",
		Name = "석공의 맹세",
		Description = "신앙심 {10}당 자신의 피해량이 {3}%씩, 최대 {15}%까지 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_QuickRite",
		Name = "빠른 축성",
		Description = "3스킬 재사용 대기가 {1}턴 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Deflect",
		Name = "빗겨내기",
		Description = "[벽]이 있는 아군의 회피·패링률이 {3}% 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Endure" },
	},
	{
		Id = "WallMason_C_StonePicking",
		Name = "돌 고르기",
		Description = "아군이 [벽]을 유지한 채 턴을 마칠 때 얻는 중첩이 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Plating" },
	},
	{
		Id = "WallMason_C_LongChisel",
		Name = "긴 정",
		Description = "2스킬 사거리가 {1}칸 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct" },
	},
	{
		Id = "WallMason_C_Footstone",
		Name = "밑돌",
		Description = "전투 시작 시 아군 전체에게 {8}의 보호막을 제공한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure", "Faith" },
	},
	{
		Id = "WallMason_C_LuckyChisel",
		Name = "운 좋은 정",
		Description = "2스킬의 치명타 확률이 {3}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating" },
	},
	{
		Id = "WallMason_C_Sharing",
		Name = "나눔",
		Description = "턴당 {1}회, 자신이 [벽]을 얻으면 인접한 아군도 {1}중첩 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Construct", "Faith" },
	},
	{
		Id = "WallMason_C_Cushion",
		Name = "완충",
		Description = "[벽]이 있는 아군이 받는 치명타 피해가 {20}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Endure" },
	},
	{
		Id = "WallMason_C_StoneOffering",
		Name = "헌석",
		Description = "적을 처치하면 신앙심이 {6} 상승한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "WallMason_C_Tireless",
		Name = "쉬지 않는 축조",
		Description = "매 턴 [벽] {1}중첩을 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Plating", "Construct" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
