--!strict
--[[
	BerserkerCards — 광전사(Berserker) 능력 카드 34종.

	기본 정체성: Role 폭딜 / `BloodCrash`(핏빛 분쇄) — 40 피해, 자기 체력 10 소모

	이 직업의 핵심은 **체력이 곧 자원**이라는 것입니다.
	따라서 카드도 "체력을 얼마나, 어떻게 태울지"를 고르게 만듭니다.

	수치 기준은 `AbilityCardDefinitions` 위쪽 주석을 따릅니다.
	핏빛 분쇄의 피해 40 · 체력 소모 10, [분노] 최대 8스택을 앵커로 삼았습니다.

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Rage    **축적**. [분노]를 모아 한 번에 태운다.
	  Frenzy  **횟수**. 추가 행동·다중 타격으로 한 턴에 더 많이 때린다.
	  Blood   **지불**. 체력을 내주고 화력과 흡혈을 산다.
	  Brink   **구간**. 체력이 낮을 때만 열리는 값을 쓴다.

	축끼리 수치를 더하지 않습니다. **한 축의 대가가 다른 축의 조건이 됩니다**:
	  Blood가 체력을 깎으면      → Brink의 저체력 구간이 열린다.
	  Rage가 스택을 태우면       → Frenzy가 그 순간에 한 번 더 휘두르게 한다.
	  Frenzy가 처치를 만들면     → Blood와 Rage가 처치에서 자원을 회수한다.
	  Brink가 벼랑에 서면        → Blood의 지불이 싸진다(고통 감내).

	그래서 자해 없이 [분노]만 모아도, 체력을 태워 벼랑에서 굴러도, 처치를 연쇄해
	턴을 늘려도 각각 다른 덱이 됩니다.

	필수 조합이 만드는 방향
	  피의 대가 + 벼랑 끝 → 극단 폭딜 (죽기 직전이 가장 강합니다)
	  흡혈귀 + 광란       → 지속 전투형 (때리며 회복합니다)
	  불사 + 아무거나     → 생존 폭딜
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Berserker"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Berserker_E_BloodPrice",
		Art = "광전사가_광광",
		Name = "피의 대가",
		Description = "`종베기`의 체력 소모가 {5}에서 10으로 늘고, 소모한 체력 {2}당 기본 피해가 {3} 증가한다.\n"
			.. "소모량은 {10}에서 {30} 사이로 직접 정할 수 있으며, 체력 소모로 체력이 {1}에 도달하더라도 소모될 체력만큼의 버프를 "
			.. "받는다.",
		Levels = { { 5, 5 }, { 2, 1 }, { 3, 3 }, { 10, 5 }, { 30, 40 }, { 1, 1 } },
		Excludes = { "Berserker_E_Vampire" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_E_Brink",
		Art = "Berserker_E_Brink",
		Name = "벼랑 끝",
		Description = "[받는 회복량]이 {35}% 줄어든다.\n"
			.. "자신의 [받는 피해량]이 {25}%를 초과할 수 없게 되고, 모든 [받는 피해량] 감소의 {1.5}배 만큼 [가하는 피해량] 증가로 "
			.. "치환시킨다.",
		Levels = { { 35, 50 }, { 25, 50 }, { 1.5, 2 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_E_Vampire",
		Art = "광전사가_광광",
		Name = "흡혈",
		Description = "최대 체력이 {10}% 증가하고, 가한 피해량의 {25}%만큼 체력을 회복한다.\n"
			.. "대신 [분노]를 얻을 수 없게 된다.",
		Levels = { { 10, 20 }, { 25, 35 } },
		Excludes = { "Berserker_E_BloodPrice" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Frenzy" },
	},
	{
		Id = "Berserker_E_Undying",
		Art = "Berserker_E_Undying",
		Name = "불굴",
		Description = "전투당 한 번, HP가 {1} 이하가 되는 공격을 받았을 때, HP {1}로 버틴 후 다음 턴부터 전투 종료까지 [가하는 피해량]이 "
			.. "{30}% 증가한다.",
		Levels = { { 1, 10 }, { 1, 10 }, { 30, 50 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Rage" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Berserker_R_Frenzy",
		MaxLevel = 1,
		Art = "Berserker_R_Frenzy",
		Name = "광란",
		Description = "적 처치 시 `횡베기` 스킬로 무작위 적을 공격한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_R_Wrath",
		MaxLevel = 2,
		Art = "Berserker_R_Wrath",
		Name = "격노",
		Description = "직접 피해를 받을 때, [분노]를 {1} 추가로 얻는다.",
		Levels = { { 1, 2 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_R_ScentOfBlood",
		Art = "광전사가_광광",
		Name = "처형",
		Description = "체력이 절반 이하인 적에게 [가하는 피해량]이 {20}% 증가한다.",
		Levels = { { 20, 30, 40, 50, 60, 70 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_R_Reckless",
		MaxLevel = 4,
		Art = "Berserker_R_Reckless",
		Name = "무모",
		Description = "전열(1~2열)에 서 있으면 [받는 피해량]이 {20}% 증가하고, [가하는 피해량]이 {20}% 증가한다.",
		Levels = { { 20, 30, 40, 50 }, { 20, 30, 40, 50 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Rage" },
	},
	{
		Id = "Berserker_R_SecondWind",
		Art = "Berserker_R_SecondWind",
		Name = "재기",
		Description = "전투당 한 번, HP가 {25}% 이하로 감소할 경우 최대 체력의 {25}%만큼 회복한다.\n위 효과는 불굴 효과보다 먼저 발동된다.",
		Levels = { { 25, 25, 25, 25, 25, 25 }, { 25, 28, 31, 34, 37, 40 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_R_Sweep",
		Art = "Berserker_R_Sweep",
		Name = "휩쓸기",
		Description = "[분노] 수치가 최대치일 때, `분쇄` 스킬의 범위가 3 x 3 범위로 증가한다.\n"
			.. "메인 대상이 아닌 대상에게 가하는 피해는 최종 피해량의 {50}%이다.",
		Levels = { { 50, 60, 70, 80, 90, 100 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Frenzy" },
	},
	{
		Id = "Berserker_R_PainTolerance",
		Art = "Berserker_R_PainTolerance",
		Name = "견딤",
		Description = "HP가 {25}% 이하일 경우 [받는 피해량]이 {30}% 감소한다.",
		Levels = { { 25, 27, 29, 31, 33, 35 }, { 30, 32, 34, 36, 38, 40 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Brink" },
	},
	{
		Id = "Berserker_R_Momentum",
		MaxLevel = 5,
		Art = "Berserker_R_Momentum",
		Name = "가속",
		Description = "공격 스킬을 사용하는 턴이 연속될 때마다 스테미나 소모가 {10}%씩 감소한다.\n"
			.. "`가드` 혹은 `호흡` 시 스테미나 소모량 감소는 초기화 된다.",
		Levels = { { 10, 15, 20, 25, 30 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_R_Scars",
		Art = "Berserker_R_Scars",
		Name = "상흔",
		Description = "잃은 체력 {10}%마다 [받는 피해량]이 {4}%씩, 최대 {40}%까지 줄어든다.",
		Levels = { { 10, 9, 8, 7, 6, 5 }, { 4, 4, 5, 5, 6, 6 }, { 40, 40, 40, 40, 40, 40 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Blood" },
	},
	{
		Id = "Berserker_R_Roar",
		MaxLevel = 1,
		Art = "Berserker_R_Roar",
		Name = "히스테릭",
		Description = "[받는 피해량] 증가량만큼 [가하는 피해량]이 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Berserker_C_Ember",
		MaxLevel = 3,
		Art = "Berserker_C_Ember",
		Name = "불씨",
		Description = "전투 시작 시 [분노]를 {1} 얻는다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_Bite",
		Art = "광전사가_광광",
		Name = "물어뜯기",
		Description = "모든 공격 스킬이 [출혈]을 {1} 추가로 부여한다.",
		Levels = { { 1, 2, 3, 4, 5, 6 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_C_Ram",
		Art = "Berserker_C_Ram",
		Name = "들이받기",
		Description = "공격 대상의 [출혈] {5}당 [가하는 피해량]이 {1}% 증가한다.",
		Levels = { { 5, 5, 4, 4, 3, 3 }, { 1, 2, 3, 4, 5, 6 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Grudge",
		MaxLevel = 5,
		Art = "Berserker_C_Grudge",
		Name = "앙심",
		Description = "이전 턴에 자신을 공격한 적에게 [가하는 피해량]이 {12}% 증가한다.",
		Levels = { { 12, 14, 16, 18, 20 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_ThickBlood",
		Art = "광전사가_광광",
		Name = "짙은 피",
		Description = "자해로 인한 체력 소모량이 {20}% 감소한다.",
		Levels = { { 20, 22, 24, 26, 28, 30 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_C_Trance",
		Art = "Berserker_C_Trance",
		Name = "무아",
		Description = "체력이 {30}% 아래일 때, 특수 상태이상을 제외한 디버프의 효과를 {25}% 감소하여 받는다.\n"
			.. "이 효과는 곱연산으로 계산된다.",
		Levels = { { 30, 30, 30, 30, 30, 30 }, { 25, 30, 35, 40, 45, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_Swing",
		Art = "Berserker_C_Swing",
		Name = "휘두르기",
		Description = "`종베기` 스킬의 피해량이 {15}% 증가한다.",
		Levels = { { 15, 18, 21, 24, 27, 30 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Boiling",
		Art = "Berserker_C_Boiling",
		Name = "끓어오름",
		Description = "[분노] {3}스택당 치명타 확률이 {1}% 증가한다.",
		Levels = { { 3, 3, 2, 2, 2, 2 }, { 1, 2, 2, 3, 3, 4 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_Devour",
		Art = "광전사가_광광",
		Name = "포식",
		Description = "적 처치 시 최대 체력의 {5}%를 회복한다.",
		Levels = { { 5, 6, 7, 8, 9, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Frenzy" },
	},
	{
		Id = "Berserker_C_Numb",
		MaxLevel = 1,
		Art = "Berserker_C_Numb",
		Name = "무감각",
		Description = "[그로기] 상태이상에 빠지지 않는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Brink" },
	},
	{
		Id = "Berserker_C_Headbutt",
		Art = "Berserker_C_Headbutt",
		Name = "박치기",
		Description = "`분쇄` 스킬이 {15}% 확률로 적을 {1}턴 기절시킨다.",
		Levels = { { 15, 20, 25, 30, 35, 40 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_RageFuel",
		MaxLevel = 1,
		Art = "Berserker_C_RageFuel",
		Name = "화풀이",
		Description = "모든 스킬이 [분노]를 {1}씩 소모하지만, 피해를 받았을 때 얻는 [분노]가 {1} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_DeathWish",
		Art = "Berserker_C_DeathWish",
		Name = "집중",
		Description = "체력이 {75}% 이하일 때 [치명타 확률]이 {5}% 증가한다.",
		Levels = { { 75, 80, 85, 85, 85, 85 }, { 5, 7, 9, 11, 13, 15 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_UnstoppingArm",
		MaxLevel = 1,
		Art = "Berserker_C_UnstoppingArm",
		Name = "자랑",
		Description = "QTE 성공 시 자해 피해를 {1} 입는다.\n"
			.. "이 효과로 사망하지 않는다.\n"
			.. "이 효과로 `불굴`과 `재기` 효과를 발동하지 않는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy", "Rage" },
	},
	{
		Id = "Berserker_C_BloodPact",
		MaxLevel = 1,
		Art = "광전사가_광광",
		Name = "피의 맹약",
		Description = "최대 체력이 {20}% 영구히 감소하는 대신, [분노]의 최대치가 {5} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_Stubborn",
		Art = "Berserker_C_Stubborn",
		Name = "고집",
		Description = "전투당 {1}회, 기절에 걸린다면, {1}턴 감소시켜 받는다.",
		Levels = { { 1, 1, 2, 2, 3, 3 }, { 1, 1, 1, 1, 1, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_Overkill",
		Art = "Berserker_C_Overkill",
		Name = "과잉 살상",
		Description = "적을 처치하고 남은 피해의 {20}%가 다음 공격에 추가된다.",
		Levels = { { 20, 30, 40, 50, 60, 70 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Callus",
		MaxLevel = 4,
		Art = "Berserker_C_Callus",
		Name = "굳은살",
		Description = "같은 적에게 연속으로 피격 시 그 적에 한해 해당 전투동안 [받는 피해량]이 {10}% 감소한다.\n"
			.. "이 효과는 중첩되지 않는다.",
		Levels = { { 10, 15, 20, 25 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_BloodVessel",
		Art = "광전사가_광광",
		Name = "자존심",
		Description = "전투당 {1}회, 회복을 받으면 [분노]를 {1} 얻는다.",
		Levels = { { 1, 2, 3, 4, 5, 6 }, { 1, 1, 1, 1, 2, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_NoRetreat",
		Art = "Berserker_C_NoRetreat",
		Name = "잠깐의 준비",
		Description = "`가드` 직후 [가하는 피해량]이 {15}% 증가한다.",
		Levels = { { 15, 17, 19, 21, 23, 25 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Frenzy" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
