--!strict
--[[
	AttunerCards — 조율자(Attuner, 조건부 획득) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` `# 조율자` — 원안 카드 넷(필수 `지키기 위한 별`·`태우기 위한 별`, 일반 `별빛 조준`,
	희귀 `유성우`)은 원안 그대로 1레벨에 두고, 나머지 서른 장은 2026-10-25 사용자 지시("나머지를 제가 채움")로
	같은 축에 맞춰 채웠다(문서에 '제안'으로 표시).

	수치 앵커
	  칠성 = 최대 7, 1당 [가하는 피해량] +3%, 별마다 셉텐트리오네스 전까지 한 번
	  융해 = 최대 20, 턴 끝 (×3) 화상 · (×1000) 고정 피해(안 죽음)
	  메그레즈 10 · 메라크 22 · 알리오스 30 · 셉텐트리오네스 50
	  알카이드: 신앙심 말고는 [가하는 피해량]을 올릴 수 없다 → **이 직업 카드는 피해% 를 주지 않는다**
	  (치명·화상·융해·보호막·스테미나·신앙심으로 값을 낸다)

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Constellation  **칠성**. 별을 빨리·많이 켜서 셉텐트리오네스를 자주 연다.
	  Burn           **연소**. [화상]·[융해]를 두껍게 깔아 턴 끝에 터뜨린다.
	  Aegis          **수호**. 미자르·두베·페크다의 보호막·회피·회복을 키운다.
	  Faith          **신앙**. 전투 중 신앙심을 올려 피해(1당 +2%)를 키운다.

	  칠성이 셉텐트리오네스를 열면      → 연소가 화상 10·융해 5 위에 얹는다.
	  수호가 오래 버티면                → 신앙(철야 기도·찬송)이 쌓인다.
	  신앙이 높으면                     → 연소(성흔)의 화상이 굵어진다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Attuner"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Attuner_E_GuardStar",
		Art = "Attuner_E_GuardStar",
		Name = "지키기 위한 별",
		Description = "서포터 전직.\n기본 피해량이 `메그레즈` {3} · `메라크` {5} · `알리오스` {10} · `셉텐트리오네스` {15}로 줄어든다.\n`미자르`의 [묶임]이 사라지고 [보호막] 부여량이 {30}% 늘어난다.\n종류에 상관없이 액티브 스킬을 쓰면 모든 아군의 체력을 (그 스킬 기본 피해량 × {8})만큼 회복한다(최대 {80}).",
		Levels = { { 3, 4 }, { 5, 6 }, { 10, 12 }, { 15, 18 }, { 30, 45 }, { 8, 10 }, { 80, 100 } },
		Excludes = { "Attuner_E_BurnStar" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Aegis", "Constellation" },
	},
	{
		Id = "Attuner_E_BurnStar",
		Art = "Attuner_E_BurnStar",
		Name = "태우기 위한 별",
		Description = "딜러 전직.\n[화상]·[융해] 부여량이 각각 {2} 늘어난다.\n`알카이드`의 피해량 증가가 '공격 적중 시 [화상] {2} 부여'로 바뀐다.\n`미자르`는 자신만 지정하고, [묶임]·[보호막]·피해량 증가 대신 [화상]을 가진 대상에게 [가하는 피해량] +{20}%가 된다.\n`페크다`의 자동 회피 확률이 [명중률]로 바뀐다(공격이 적중하면 [칠성]).\n`두베`의 [보호막] 대신 자신의 턴이 끝난 뒤 `메그레즈`를 쓴다(쓸 때마다 기본 피해량 {50}% 감소).",
		Levels = { { 2, 3 }, { 2, 3 }, { 20, 30 }, { 50, 40 } },
		Excludes = { "Attuner_E_GuardStar" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Burn", "Constellation" },
	},
	{
		Id = "Attuner_E_Alcor",
		Art = "Attuner_E_Alcor",
		Name = "알코르",
		Description = "`미자르` 곁에 숨은 여덟 번째 별.\n[칠성] 최대치가 8이 되고 `셉텐트리오네스`는 [칠성] 8에서 열린다.\n`미자르`가 자신을 지정하면 [칠성]을 한 번 더 얻는다.\n`셉텐트리오네스`의 [치명타 확률]이 {25}% 오른다.",
		Levels = { { 25, 40 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Constellation", "Aegis" },
	},
	{
		Id = "Attuner_E_Oracle",
		Art = "Attuner_E_Oracle",
		Name = "신탁",
		Description = "`셉텐트리오네스`를 쓰면 [핵융합 반응]을 얻지 않는 대신 이번 전투 동안 신앙심이 {12} 오른다.\n신앙심 1당 [가하는 피해량]이 2%에서 {2.5}%가 된다.",
		Levels = { { 12, 18 }, { 2.5, 3 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Constellation" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Attuner_R_Meteor",
		Art = "Attuner_R_Meteor",
		Name = "유성우",
		Description = "턴 시작 시 (보유한 [칠성] / {4})만큼 모든 적에게 [화상]을 부여한다(반올림).",
		Levels = { { 4, 3.5, 3, 2.5, 2, 1.5 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn", "Constellation" },
	},
	{
		Id = "Attuner_R_Furnace",
		Art = "Attuner_R_Furnace",
		Name = "용광로 별",
		Description = "[융해] 최대치가 20에서 {24}가 된다.",
		Levels = { { 24, 26, 28, 30, 32, 35 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_R_Binary",
		Art = "Attuner_R_Binary",
		Name = "쌍성",
		Description = "`미자르`가 준 [보호막]이 턴 끝까지 남아 있으면, 남은 양의 {30}%만큼 체력을 회복한다.",
		Levels = { { 30, 35, 40, 45, 50, 60 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_R_StarMap",
		Art = "Attuner_R_StarMap",
		Name = "별자리 지도",
		Description = "한 턴에 [칠성]을 2 이상 얻으면 스테미나를 {8} 회복한다.",
		Levels = { { 8, 10, 12, 14, 16, 20 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_R_Polaris",
		Art = "Attuner_R_Polaris",
		Name = "북극성",
		Description = "[칠성]이 {5} 이상이면 [받는 피해량]이 {10}% 줄어든다.",
		Levels = { { 5, 5, 5, 4, 4, 4 }, { 10, 12, 14, 16, 18, 20 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Aegis", "Constellation" },
	},
	{
		Id = "Attuner_R_Stigmata",
		Art = "Attuner_R_Stigmata",
		Name = "별의 상흔",
		Description = "신앙심 {10}마다 [화상] 부여량이 1 늘어난다.",
		Levels = { { 10, 9, 8, 7, 6, 5 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Burn" },
	},
	{
		Id = "Attuner_R_Vigil",
		Art = "Attuner_R_Vigil",
		Name = "철야 기도",
		Description = "`가드`로 턴을 마치면 이번 전투 동안 신앙심이 {2} 오른다(이 카드로 최대 {12}).",
		Levels = { { 2, 2, 3, 3, 4, 4 }, { 12, 14, 14, 16, 16, 20 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Aegis" },
	},
	{
		Id = "Attuner_R_Mirage",
		Art = "Attuner_R_Mirage",
		Name = "신기루",
		Description = "`페크다`의 자동 회피 확률이 20%에서 {26}%가 된다.",
		Levels = { { 26, 28, 30, 32, 34, 38 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_R_RedGiant",
		Art = "Attuner_R_RedGiant",
		Name = "적색거성",
		Description = "[융해]가 터진 적의 둘레 1칸에 있는 적에게 터진 [융해]의 {25}%가 옮겨 붙는다(반올림).",
		Levels = { { 25, 30, 35, 40, 45, 55 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_R_Sunspot",
		Art = "Attuner_R_Sunspot",
		Name = "흑점",
		Description = "[핵융합 반응]의 [받는 피해량] 증가가 턴마다 50%p가 아니라 {100}%p씩 줄어든다.",
		Levels = { { 100, 110, 120, 135, 150, 175 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Attuner_C_Starlight",
		Art = "Attuner_C_Starlight",
		Name = "별빛 조준",
		Description = "(보유한 [칠성] / {5})%만큼 [치명타 확률]이 오른다(반올림).",
		Levels = { { 5, 4, 3.5, 3, 2.5, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_C_Ember",
		Art = "Attuner_C_Ember",
		Name = "메그레즈의 불씨",
		Description = "`메그레즈`가 적중한 적에게 {20}% 확률로 [융해] 1을 더 부여한다.",
		Levels = { { 20, 28, 36, 44, 52, 60 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_C_Orbit",
		Art = "Attuner_C_Orbit",
		Name = "메라크의 궤도",
		Description = "`메라크`를 쓰면 {15}% 확률로 재사용 대기가 바로 끝난다.",
		Levels = { { 15, 19, 23, 27, 31, 35 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_C_Flare",
		Art = "Attuner_C_Flare",
		Name = "알리오스의 섬광",
		Description = "`알리오스`가 [화상]을 {2} 더 부여한다.",
		Levels = { { 2, 3, 4, 5, 6, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_C_Roof",
		Art = "Attuner_C_Roof",
		Name = "두베의 지붕",
		Description = "`두베`의 [보호막]이 7에서 {9}가 된다.",
		Levels = { { 9, 10, 11, 12, 13, 15 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_C_StarPilgrim",
		Art = "Attuner_C_StarPilgrim",
		Name = "별 순례",
		Description = "전투 시작 시 이번 전투 동안 신앙심이 {4} 오른다.",
		Levels = { { 4, 5, 6, 7, 8, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "Attuner_C_Observe",
		Art = "Attuner_C_Observe",
		Name = "관측",
		Description = "`셉텐트리오네스`로 [칠성]이 초기화되면 다음 턴 시작 시 스테미나를 {6} 회복한다.",
		Levels = { { 6, 7, 8, 9, 10, 12 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_C_Cinder",
		Art = "Attuner_C_Cinder",
		Name = "남은 불티",
		Description = "[화상]을 가진 적이 쓰러지면 남은 [화상]의 {30}%가 가장 가까운 적에게 옮겨 붙는다.",
		Levels = { { 30, 35, 40, 45, 50, 60 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_C_Radiance",
		Art = "Attuner_C_Radiance",
		Name = "성광",
		Description = "`셉텐트리오네스`의 회복 최대치가 30에서 {36}이 된다.",
		Levels = { { 36, 40, 44, 48, 52, 60 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_C_Devout",
		Art = "Attuner_C_Devout",
		Name = "경건",
		Description = "신앙심이 {15} 이상이면 [받는 회복량]이 {10}% 늘어난다.",
		Levels = { { 15, 15, 15, 12, 12, 12 }, { 10, 13, 16, 19, 22, 26 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Aegis" },
	},
	{
		Id = "Attuner_C_Rosary",
		Art = "Attuner_C_Rosary",
		Name = "묵주",
		Description = "신앙심 {10}마다 [치명타 확률]이 1% 오른다.",
		Levels = { { 10, 9, 8, 7, 6, 5 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "Attuner_C_Lens",
		Art = "Attuner_C_Lens",
		Name = "중력 렌즈",
		Description = "`셉텐트리오네스`의 [치명타 피해량]이 {15}% 오른다.",
		Levels = { { 15, 19, 23, 27, 31, 36 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_C_MeltPoint",
		Art = "Attuner_C_MeltPoint",
		Name = "녹는점",
		Description = "[융해]가 {8} 이상인 적을 맞히면 스테미나를 {3} 회복한다(스킬마다 한 번).",
		Levels = { { 8, 8, 7, 7, 6, 6 }, { 3, 4, 4, 5, 5, 6 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_C_Cluster",
		Art = "Attuner_C_Cluster",
		Name = "별무리",
		Description = "`미자르`의 [보호막]이 49에서 {55}가 된다.",
		Levels = { { 55, 60, 65, 70, 75, 82 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_C_Hymn",
		Art = "Attuner_C_Hymn",
		Name = "찬송",
		Description = "`셉텐트리오네스`를 쓰면 이번 전투 동안 신앙심이 {3} 오른다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith", "Constellation" },
	},
	{
		Id = "Attuner_C_Devotion",
		Art = "Attuner_C_Devotion",
		Name = "헌신의 별",
		Description = "`셉텐트리오네스`가 모자란 스테미나를 체력으로 낼 때 {80}%만 낸다.",
		Levels = { { 80, 74, 68, 62, 56, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Constellation" },
	},
	{
		Id = "Attuner_C_HeatCycle",
		Art = "Attuner_C_HeatCycle",
		Name = "열 순환",
		Description = "자신에게 [화상]이 있으면 턴 끝 스테미나 회복이 {3} 늘어난다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Burn" },
	},
	{
		Id = "Attuner_C_Sanctum",
		Art = "Attuner_C_Sanctum",
		Name = "성소",
		Description = "`가드`를 쓰면 다음 턴 시작 시 [보호막] {5}를 얻는다.",
		Levels = { { 5, 6, 7, 8, 9, 11 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Attuner_C_Psalm",
		Art = "Attuner_C_Psalm",
		Name = "시편",
		Description = "신앙심이 {20} 이상이면 `알리오스`를 쓴 뒤 {25}% 확률로 재사용 대기가 1턴 줄어든다.",
		Levels = { { 20, 20, 20, 18, 18, 15 }, { 25, 30, 35, 40, 45, 50 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Faith" },
	},
	{
		Id = "Attuner_C_Twinkle",
		Art = "Attuner_C_Twinkle",
		Name = "반짝임",
		Description = "자동 회피에 성공하면 다음 스킬의 스테미나 소모가 {20}% 줄어든다.",
		Levels = { { 20, 24, 28, 32, 36, 40 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
