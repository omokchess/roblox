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
		Name = "피의 대가",
		Description = "핏빛 분쇄의 체력 소모가 {10}에서 {25}로 늘고, 소모한 체력 {1}당 피해가 {3} 증가한다. 소모량은 {10}에서 {40} "
			.. "사이로 직접 정할 수 있으며, 자신의 체력 소모로 죽지 않게 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_E_Brink",
		Name = "벼랑 끝",
		Description = "잃은 체력 {10}%마다 입히는 피해가 {8}% 증가한다. 대신 받는 회복 효과가 {50}% 줄어든다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_E_Vampire",
		Name = "흡혈귀",
		Description = "최대 체력이 {10}% 증가하고, 가한 피해의 {25}%만큼 체력을 회복한다. 대신 [분노]를 얻을 수 없게 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Frenzy" },
	},
	{
		Id = "Berserker_E_Undying",
		Name = "불사",
		Description = "전투 당 한번 치명적인 피해를 받아도 체력 {1}로 버틴다. 버틴 직후 한 턴 동안 주는 피해가 {30}% 증가한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Rage" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Berserker_R_Frenzy",
		Name = "광란",
		Description = "적을 처치하면 한 번 더 행동하며, 최대 {2}번 발동된다. 추가 행동의 피해는 {70}%이다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_R_Wrath",
		Name = "격노",
		Description = "피해를 받을 때마다 [분노] {1}스택을 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_R_ScentOfBlood",
		Name = "피 냄새",
		Description = "체력이 절반 아래인 적에게 입히는 피해가 {20}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_R_Reckless",
		Name = "무모함",
		Description = "받는 피해가 {20}% 늘어나는 대신, 주는 피해가 {30}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Rage" },
	},
	{
		Id = "Berserker_R_SecondWind",
		Name = "재기",
		Description = "체력이 {25}% 아래로 떨어지면, 전투당 한 번 최대 체력의 {25}%를 회복한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_R_Sweep",
		Name = "휩쓸기",
		Description = "[분노]가 최대일 때, 평타가 주변 모든 적을 대상으로 한다. 주 대상 외에는 피해의 {20}%를 입힌다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Frenzy" },
	},
	{
		Id = "Berserker_R_PainTolerance",
		Name = "고통 감내",
		Description = "자신의 체력이 {25}% 아래면, 받는 피해량이 {30}% 줄어들고 턴마다 스테미나를 {5} 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Brink" },
	},
	{
		Id = "Berserker_R_Momentum",
		Name = "가속",
		Description = "연속으로 공격한 턴마다 스테미나 소모가 {10}% 줄어든다. 방어하면 초기화된다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_R_Scars",
		Name = "상흔",
		Description = "잃은 체력 {10}%마다 받는 피해가 {4}%씩, 최대 {40}%까지 줄어든다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Brink", "Blood" },
	},
	{
		Id = "Berserker_R_Roar",
		Name = "포효",
		Description = "핏빛 분쇄 스킬을 사용하면, 모든 적들의 주는 피해를 {12}% 감소시킨다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Berserker_C_Ember",
		Name = "불씨",
		Description = "전투 시작 시 [분노]를 {1} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_Bite",
		Name = "물어뜯기",
		Description = "평타가 {1}턴의 출혈을 부여한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_C_Ram",
		Name = "들이받기",
		Description = "한 턴에 최종 이동한 칸 수 {1}당 주는 피해가 {6}%, 최대 {3}번 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Grudge",
		Name = "앙심",
		Description = "전 턴에 자신을 공격한 적에게 주는 피해가 {12}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_ThickBlood",
		Name = "짙은 피",
		Description = "체력 소모량이 {20}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood" },
	},
	{
		Id = "Berserker_C_Trance",
		Name = "무아",
		Description = "체력이 {30}% 아래일 때, 특수 상태이상 제외 상태이상의 효과를 {25}% 감소하여 받는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_Swing",
		Name = "휘두르기",
		Description = "적이 둘 이상 인접하면, 평타가 한 명 더 대상으로 한다. 두 번째 대상에게는 피해의 {30}%를 입힌다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Boiling",
		Name = "끓어오름",
		Description = "[분노] {1}스택당 치명타 확률이 {1}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage" },
	},
	{
		Id = "Berserker_C_Devour",
		Name = "포식",
		Description = "적을 처치하면 최대 체력의 {5}%를 회복한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Frenzy" },
	},
	{
		Id = "Berserker_C_Numb",
		Name = "무감각",
		Description = "턴당 {1}회, 지속 피해를 받으면 [분노]를 {1} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Brink" },
	},
	{
		Id = "Berserker_C_Headbutt",
		Name = "박치기",
		Description = "핏빛 분쇄가 {15}% 확률로 적을 {1}턴 기절시킨다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_RageFuel",
		Name = "분노 연료",
		Description = "체력을 {2}번 소모할 때마다 [분노]를 {1} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_DeathWish",
		Name = "죽음 소망",
		Description = "체력이 {75}% 이하일 때 치명타 확률이 {5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_UnstoppingArm",
		Name = "멈추지 않는 팔",
		Description = "같은 턴에 두번 연속 공격하면, 피해량이 {10}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy", "Rage" },
	},
	{
		Id = "Berserker_C_BloodPact",
		Name = "피의 맹약",
		Description = "전투 시작 시 최대 체력의 {15}%를 깎고 [분노]를 {2} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_Stubborn",
		Name = "고집",
		Description = "전투당 한 번, 기절에 걸린다면, {1}턴 감소시켜 받는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_Overkill",
		Name = "과잉 살상",
		Description = "적을 처치하고 남은 피해의 {20}%가 다음 공격에 추가된다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Frenzy" },
	},
	{
		Id = "Berserker_C_Callus",
		Name = "굳은살",
		Description = "같은 적에게 연속으로 맞으면, 그 피해가 {10}% 줄어든다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Brink" },
	},
	{
		Id = "Berserker_C_BloodVessel",
		Name = "혈맥",
		Description = "턴당 {1}회, 회복을 받으면 [분노]를 {1} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Blood", "Rage" },
	},
	{
		Id = "Berserker_C_NoRetreat",
		Name = "이판사판",
		Description = "뒤로 이동하지 않은 턴에는 주는 피해가 {8}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Rage", "Frenzy" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
