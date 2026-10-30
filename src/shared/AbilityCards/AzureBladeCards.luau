--!strict
--[[
	AzureBladeCards — 청의 검사(AzureBlade, 조건부 획득) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` `# 청의 검사` — 원안 카드 일곱(필수 `도발`·`치우쳐진 검`, 일반 `민첩성`·
	`집중력의 향상`·`바람의 검`, 희귀 `혼신의 도발`·`방어 태도`)은 원안 그대로 1레벨에 두고, 나머지 스물일곱 장은
	2026-10-25 사용자 지시("나머지를 제가 채움")로 같은 축에 맞춰 채웠다(문서에 '제안'으로 표시).
	`민첩성`은 사용자 지시대로 필드에서는 걷는 속도, 전투에서는 민첩 스탯을 올린다.
	2026-10-28 밸런스(사용자: "미완성이거나 중복 값이 들어 있어 만들다 만 느낌"): 효과가 비었던 필수 `도발`, 손해만 있던
	`치우쳐진 검`, 혼자 2레벨이던 `혼신의 도발`을 채우고, 레벨마다 값이 같거나 되돌아가던 `방어 태도`·`검풍`·`방랑 검객`을 고쳤다.
	원안 값(도발은 바뀌지 않음 · 방어력 2.5% · 집중력 +1턴 · 방어력 +10% · 공격력 −2.5%)은 1레벨에 그대로 두고 더했다.

	수치 앵커
	  검집 타격 18(재사용 1) · 집중 베기 22(2) · 진 발도술 22 = 4/3/3(2) · 발도술의 절정 32 = 6/4/4(4) · 공간의 이해 34 고정(6)
	  [집중력] = 최대 1, `도발`(재사용 2, 스테미나 0)로 얻고 2턴 뒤 사라짐

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Iaido      **발도**. 진 발도술·발도술의 절정의 재사용과 치명으로 친다.
	  Precision  **집중**. [집중력]을 오래·자주 들고 변형 스킬로 바꿔 친다.
	  Taunt      **도발**. `도발`을 쓴 턴의 반격·회피를 값으로 바꾼다.
	  Guard      **방어**. 검집·가드로 막아 내며 버틴다.

	  도발이 집중력을 주면     → 집중이 공간의 이해로 바꾼다.
	  방어로 막아 내면         → 집중력(검집 막기)이 들어온다.
	  집중이 사라지기 전에     → 발도가 재사용을 당겨 한 번 더 벤다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "AzureBlade"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "AzureBlade_E_Provoke",
		Art = "AzureBlade_E_Provoke",
		Name = "도발",
		Description = "`도발`은 다른 스킬로 바뀔 수 없다.\n대신 `도발`의 재사용 대기가 1턴 줄고, 쓸 때마다 [도발] {4}를 얻는다(파티에서 적의 공격을 끌어온다).",
		Levels = { { 4, 6 } },
		Excludes = { "AzureBlade_E_Mushin", "AzureBlade_E_Riposte" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Taunt" },
	},
	{
		Id = "AzureBlade_E_Biased",
		Art = "AzureBlade_E_Biased",
		Name = "치우쳐진 검",
		Description = "검술만 단련해 [받는 피해량]이 {20}% 늘어난다.\n대신 적을 쓰러뜨리면 `진 발도술`의 재사용 대기가 끝나고 스테미나를 {8} 돌려받는다.",
		Levels = { { 20, 15 }, { 8, 12 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_E_Mushin",
		Art = "AzureBlade_E_Mushin",
		Name = "무념무상",
		Description = "[집중력]이 시간이 지나도 사라지지 않는다.\n대신 `도발`로는 [집중력]을 얻지 못하고, `진 발도술`이 치명타로 맞히면 [집중력]을 얻는다.\n[집중력]이 있으면 [치명타 피해량]이 {20}% 오른다.",
		Levels = { { 20, 30 } },
		Excludes = { "AzureBlade_E_Provoke" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Iaido" },
	},
	{
		Id = "AzureBlade_E_Riposte",
		Art = "AzureBlade_E_Riposte",
		Name = "역수 발도",
		Description = "`도발`이 받아치기 자세가 된다 — 쓴 턴에 오는 적 공격을 {40}% 확률로 받아쳐 피해를 받지 않고, 무기 공격력의 {150}%를 되돌린다.\n[집중력]은 그대로 얻는다.",
		Levels = { { 40, 55 }, { 150, 200 } },
		Excludes = { "AzureBlade_E_Provoke" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Guard" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "AzureBlade_R_AllOut",
		Art = "AzureBlade_R_AllOut",
		Name = "혼신의 도발",
		Description = "[집중력]을 유지하는 턴이 1 늘어나고, [집중력]이 있을 때 [가하는 피해량]이 {6}% 오른다.",
		Levels = { { 6, 8, 10, 12, 14, 17 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Precision" },
	},
	{
		Id = "AzureBlade_R_Stance",
		Art = "AzureBlade_R_Stance",
		Name = "방어 태도",
		Description = "[집중력]이 있을 때 적의 공격을 막아 내면(방어) {30}% 확률로 피해를 받지 않고 [집중력]이 1턴 늘어난다.",
		Levels = { { 30, 34, 38, 42, 46, 52 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "AzureBlade_R_SwordWind",
		Art = "AzureBlade_R_SwordWind",
		Name = "검풍",
		Description = "`발도술의 절정`이 적을 3명 이상 베면 `진 발도술`의 재사용 대기가 끝나고 스테미나를 {5} 회복한다.",
		Levels = { { 5, 6, 7, 8, 9, 11 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_R_Zanshin",
		Art = "AzureBlade_R_Zanshin",
		Name = "잔심",
		Description = "`진 발도술`로 적을 쓰러뜨리면 {40}% 확률로 [집중력]을 얻는다.",
		Levels = { { 40, 48, 56, 64, 72, 85 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Iaido" },
	},
	{
		Id = "AzureBlade_R_Ring",
		Art = "AzureBlade_R_Ring",
		Name = "칼집 울림",
		Description = "`검집 타격`이 맞힌 적의 [그로기]가 {10} 더 찬다.",
		Levels = { { 10, 12, 14, 16, 18, 22 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_R_Price",
		Art = "AzureBlade_R_Price",
		Name = "도발의 대가",
		Description = "`도발`을 쓴 턴에 [받는 피해량]이 {15}% 줄어든다.",
		Levels = { { 15, 18, 21, 24, 27, 32 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Guard" },
	},
	{
		Id = "AzureBlade_R_OneBreath",
		Art = "AzureBlade_R_OneBreath",
		Name = "한 호흡",
		Description = "`공간의 이해`로 [집중력]을 소모하면 다음 턴 시작 시 스테미나를 {15} 회복한다.",
		Levels = { { 15, 18, 21, 24, 27, 32 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_R_StillWater",
		Art = "AzureBlade_R_StillWater",
		Name = "명경지수",
		Description = "[집중력]이 있을 때 [회피 시간]이 {10}% 늘어난다.",
		Levels = { { 10, 13, 16, 19, 22, 26 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Guard" },
	},
	{
		Id = "AzureBlade_R_Mark",
		Art = "AzureBlade_R_Mark",
		Name = "역습 표식",
		Description = "`도발`을 쓴 다음 턴의 첫 스킬은 [치명타 확률]이 {15}% 오른다.",
		Levels = { { 15, 19, 23, 27, 31, 36 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Taunt" },
	},
	{
		Id = "AzureBlade_R_FalseGap",
		Art = "AzureBlade_R_FalseGap",
		Name = "거짓 틈",
		Description = "`도발`을 쓴 턴에 적의 공격을 회피하면 {50}% 확률로 `진 발도술`의 재사용 대기가 끝난다.",
		Levels = { { 50, 58, 66, 74, 82, 95 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Iaido" },
	},

	--=== 일반 (20) ===--
	{
		Id = "AzureBlade_C_Agility",
		Art = "AzureBlade_C_Agility",
		Name = "민첩성",
		Description = "필드 이동 속도가 {10}% 빨라진다.\n전투에서 이동한 턴에는 적의 공격을 {12}% 확률로 저절로 피한다(자동 패링).",
		Levels = { { 10, 12, 14, 16, 18, 20 }, { 12, 14, 16, 18, 20, 23 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_FocusUp",
		Art = "AzureBlade_C_FocusUp",
		Name = "집중력의 향상",
		Description = "[집중력]을 얻으면 다음 스킬의 [치명타 확률]이 {15}% 오른다.",
		Levels = { { 15, 17, 19, 21, 23, 26 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_C_WindBlade",
		Art = "AzureBlade_C_WindBlade",
		Name = "바람의 검",
		Description = "`진 발도술`이 치명타로 맞히면 바람이 한 번 더 베어 그 피해의 {30}%를 더 준다.",
		Levels = { { 30, 35, 40, 45, 50, 60 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_Point",
		Art = "AzureBlade_C_Point",
		Name = "칼끝 겨누기",
		Description = "`검집 타격`으로 적을 맞히면 다음 `진 발도술`의 [가하는 피해량]이 {15}% 오른다.",
		Levels = { { 15, 18, 21, 24, 27, 32 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_C_DrawPractice",
		Art = "AzureBlade_C_DrawPractice",
		Name = "발검 연습",
		Description = "`진 발도술`을 쓰면 스테미나를 {3} 돌려받는다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_Settle",
		Art = "AzureBlade_C_Settle",
		Name = "칼 쉬게 하기",
		Description = "`호흡`을 쓴 다음 턴에는 `진 발도술`의 [치명타 피해량]이 {15}% 오른다.",
		Levels = { { 15, 18, 21, 24, 27, 32 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_Jeer",
		Art = "AzureBlade_C_Jeer",
		Name = "도발 연습",
		Description = "`도발`을 쓰면 스테미나를 {4} 얻는다.",
		Levels = { { 4, 5, 6, 7, 8, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Taunt" },
	},
	{
		Id = "AzureBlade_C_SheathBlock",
		Art = "AzureBlade_C_SheathBlock",
		Name = "검집 막기",
		Description = "`가드`를 쓴 턴에 적의 공격을 막아 내면 {30}% 확률로 [집중력]을 얻는다.",
		Levels = { { 30, 36, 42, 48, 54, 62 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "AzureBlade_C_Stare",
		Art = "AzureBlade_C_Stare",
		Name = "끝까지 노려보기",
		Description = "[집중력]이 있을 때 이동하지 않고 턴을 마치면 스테미나를 {4} 회복한다.",
		Levels = { { 4, 5, 6, 7, 8, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_C_Through",
		Art = "AzureBlade_C_Through",
		Name = "베어 넘기기",
		Description = "`발도술의 절정`이 벤 적 1명당 [치명타 피해량]이 {5}% 오른다.",
		Levels = { { 5, 6, 7, 8, 9, 11 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_Cleave",
		Art = "AzureBlade_C_Cleave",
		Name = "공간 가르기",
		Description = "`공간의 이해`로 적을 쓰러뜨리면 스테미나를 {8} 돌려받는다.",
		Levels = { { 8, 10, 12, 14, 16, 20 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_C_Rebuke",
		Art = "AzureBlade_C_Rebuke",
		Name = "검집 되치기",
		Description = "`검집 타격`이 맞힌 적은 이번 턴(곧 올 반격) [가하는 피해량]이 {10}% 줄어든다.",
		Levels = { { 10, 12, 14, 16, 18, 22 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_C_Deflect",
		Art = "AzureBlade_C_Deflect",
		Name = "흘려 넘기기",
		Description = "적의 공격을 막아 내면(방어) 받은 피해의 {50}%를 공격한 적에게 흘려 되돌린다(턴당 1회).",
		Levels = { { 50, 60, 70, 80, 90, 100 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_C_Momentum",
		Art = "AzureBlade_C_Momentum",
		Name = "기세",
		Description = "`도발`을 쓴 다음 턴에 `진 발도술`을 쓰면 {30}% 확률로 재사용 대기가 바로 끝난다.",
		Levels = { { 30, 35, 40, 45, 50, 58 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Iaido" },
	},
	{
		Id = "AzureBlade_C_Answer",
		Art = "AzureBlade_C_Answer",
		Name = "도발 응수",
		Description = "`도발`을 쓴 턴에 적의 공격을 회피하면 턴이 끝날 때 `검집 타격`을 공짜로 한 번 휘두른다(피해 {50}%).\n[집중력]이 있으면 대신 `집중 베기`가 나가고, [집중력]은 쓰지 않는다.",
		Levels = { { 50, 58, 66, 74, 82, 95 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Taunt" },
	},
	{
		Id = "AzureBlade_C_Linger",
		Art = "AzureBlade_C_Linger",
		Name = "집중 유지",
		Description = "[집중력]이 사라질 때 {20}% 확률로 1턴 더 남는다.",
		Levels = { { 20, 25, 30, 35, 40, 48 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_C_Whet",
		Art = "AzureBlade_C_Whet",
		Name = "칼날 벼리기",
		Description = "전투 시작 시 {30}% 확률로 [집중력]을 얻는다.",
		Levels = { { 30, 40, 50, 60, 70, 85 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "AzureBlade_C_Wanderer",
		Art = "AzureBlade_C_Wanderer",
		Name = "방랑 검객",
		Description = "적이 3기 이상이면 `발도술의 절정`의 [가하는 피해량]이 {10}% 오른다.",
		Levels = { { 10, 12, 14, 16, 18, 21 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Iaido" },
	},
	{
		Id = "AzureBlade_C_Shoulder",
		Art = "AzureBlade_C_Shoulder",
		Name = "어깨 너머",
		Description = "`가드`를 쓴 다음 턴의 첫 스킬은 스테미나 소모가 {25}% 줄어든다.",
		Levels = { { 25, 30, 35, 40, 45, 52 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "AzureBlade_C_Glare",
		Art = "AzureBlade_C_Glare",
		Name = "도발의 눈빛",
		Description = "`도발`을 쓴 턴에는 적의 공격이 {35}% 확률로 치명타가 되지 않는다.",
		Levels = { { 35, 42, 49, 56, 63, 72 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Taunt", "Guard" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
