--!strict
--[[
	DuelistCards — 결투사(Duelist) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — 태세를 갈아 가며 싸우는 육각형 직업. 축은 **패링**.

	수치 앵커
	  집중 상한 10. 스택 1당 받는 피해 −0.5% / 피해 +1% / 회피 시간 +2.5%
	  집중 5 이상이면 막지 못한 피격에 스택 3을 써서 자동 패링
	  공격 태세 받는 피해 +15% · 피해 +(20 + 집중)%
	  방어 태세 받는 피해 −30% · 피해 −45%

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Precision  **스택**. [집중]을 벌고, 스택 자체를 값으로 쓴다.
	  Guard      **태세**. 언제 바꾸느냐, 혹은 안 바꾸느냐로 이득을 본다.
	  Riposte    **패링**. 막아낸 순간을 자원과 반격으로 바꾼다.
	  Execute    **출혈**. 피를 흘려 두고 마무리에서 회수한다.

	축끼리 수치를 더하지 않습니다. **서로의 발동 조건을 만들어 줍니다**:
	  Riposte가 막아내면        → Precision이 그 순간 스택을 번다(경계).
	  Precision이 5스택을 넘기면 → Riposte의 자동 패링과 Execute의 방어 관통이 열린다.
	  Guard가 태세를 바꾸면      → Execute의 첫 공격 판정이 달라진다(페인트).
	  Execute가 출혈을 남기면    → Precision·Riposte가 그 적에게만 붙는 값을 지불한다.

	그리고 Guard 안에서 방향이 갈립니다 — 필수 `양날`은 **매 턴 강제 전환**,
	일반 `자세 낮추기`는 **버티고 안 바꾸기**. 같은 축인데 정반대로 굴러갑니다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Duelist"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Duelist_E_IronWall",
		Art = "Duelist_E_IronWall",
		Name = "철벽",
		Description = "공격 태세가 사라지고 공격 스킬을 사용할 수 없게 된다. 매 턴마다 갱신되는 [도발]을 {1} 얻는다.\n"
			.. "피격 시 패링하지 못 했다면, [집중]을 {1} 얻고 반드시 방어한다.\n"
			.. "피격 시 받은 스킬의 기본 피해량의 {25}%를 공격자에게 반사하고, 패링 불가 스킬을 전투당 {1}회 패링할 수 있게 된다.",
		Levels = { { 1, 1 }, { 1, 2 }, { 25, 40 }, { 1, 3 } },
		Excludes = { "Duelist_E_LightBlade", "Duelist_E_DoubleEdge" },
		Party = true,
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_E_LightBlade",
		Art = "결투사의_레이피어",
		Name = "광검",
		Description = "방어 태세가 사라진다. [받는 피해량]이 {25}% 늘어나는 대신 [가하는 피해량]이 {40}%, [치명타 피해량]이 {15}% "
			.. "증가한다. 공격 스킬로 적을 처치하면, [가하는 피해량]이 {75}% 줄어든 채 무작위 대상에게 한 번 더 사용한다.",
		Levels = { { 25, 40 }, { 40, 60 }, { 15, 30 }, { 75, 50 } },
		Excludes = { "Duelist_E_IronWall", "Duelist_E_DoubleEdge" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Execute", "Guard" },
	},
	{
		Id = "Duelist_E_DoubleEdge",
		Art = "결투사_양날의_검",
		Name = "양날의 검",
		Description = "매 턴, 태세가 강제로 바뀐다.\n"
			.. "바뀔 때마다 [집중]을 {1} 소모하는 대신, 태세의 효과가 {30}% 증가하고, 변경되는 태세마다 효과를 얻는다.\n"
			.. "공격 태세: 스테미나를 {5} 얻고 공격 스킬의 기본 피해량이 {3} 증가한다.\n"
			.. "방어 태세: 보호막을 {5} 얻는다. 자동 패링 확률이 {10}% 증가하고, 자신이 공격 대상이라면, 공격자에게 [출혈]을 {5} "
			.. "부여한다.",
		Levels = { { 1, 1 }, { 30, 40 }, { 5, 10 }, { 3, 5 }, { 5, 10 }, { 10, 20 }, { 5, 8 } },
		Excludes = { "Duelist_E_IronWall", "Duelist_E_LightBlade" },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "Duelist_E_NamelessBlade",
		Art = "결투사의_레이피어",
		Name = "무명검",
		Description = "[집중] 상한이 {10}에서 {20}으로 증가한다. 대신 스택당 효과가 {40}% 감소한다.",
		Levels = { { 10, 10 }, { 20, 30 }, { 40, 30 } },
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Duelist_R_Bloodletting",
		Art = "Duelist_R_Bloodletting",
		Name = "방혈",
		Description = "[출혈]을 부여할 때마다 {3}턴 간 [치명타 피해량]이 {2.5}% 증가한다.\n"
			.. "최대 {5}중첩까지 증가한다.",
		Levels = { { 3, 3, 4, 4, 5, 5 }, { 2.5, 3, 3.5, 4, 4.5, 5 }, { 5, 5, 5, 6, 6, 6 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_R_NoSpend",
		MaxLevel = 3,
		Art = "결투사의_레이피어",
		Name = "불소모",
		Description = "[집중]이 최대치일 때, 패링에 성공하면 스택을 {3}턴 당 한 번 소모하지 않는다.",
		Levels = { { 3, 2, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Riposte" },
	},
	{
		Id = "Duelist_R_Counter",
		MaxLevel = 1,
		Art = "Duelist_R_Counter",
		Name = "기회 노리기",
		Description = "패링 성공 시 `앞뒤관통` 스킬을 공격자에게 사용한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_R_Pivot",
		Art = "Duelist_R_Pivot",
		Name = "발끝 전환",
		Description = "태세가 변경된 턴에 피격시, [회피 시간]이 {5}% 증가한다.",
		Levels = { { 5, 7, 9, 11, 13, 15 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_R_FocusBreath",
		Art = "결투사의_레이피어",
		MaxLevel = 3,
		Name = "집중 호흡",
		Description = "{3}턴마다 [집중]을 {1} 얻는다.",
		Levels = { { 3, 2, 1 }, { 1, 1, 1 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_R_Feint",
		Art = "Duelist_R_Feint",
		Name = "페인트",
		Description = "태세를 바꾼 직후 처음 하는 공격은 회피가 불가능하며, [가하는 피해량]이 {20}% 증가한다.",
		Levels = { { 20, 23, 26, 29, 32, 35 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Execute" },
	},
	{
		Id = "Duelist_R_BloodLoss",
		Art = "Duelist_R_BloodLoss",
		Name = "실혈",
		Description = "[출혈] 상태의 적에게 [가하는 피해량]이 {15}% 증가한다.",
		Levels = { { 15, 18, 21, 24, 27, 30 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_R_Slip",
		Art = "Duelist_R_Slip",
		Name = "흘리기",
		Description = "패링 실패 시 [받는 피해량]이 {20}% 감소한다.",
		Levels = { { 20, 22, 24, 26, 28, 30 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_R_HonedEdge",
		Art = "결투사의_레이피어",
		Name = "날 세우기",
		Description = "[집중] 스택이 {5} 이상일 때, 적의 [받는 피해량] 감소를 {25}% 무시한다.\n"
			.. "위 효과는 합연산으로 계산된다.",
		Levels = { { 5, 5, 4, 4, 3, 3 }, { 25, 27, 27, 29, 29, 35 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Execute" },
	},
	{
		Id = "Duelist_R_Vigil",
		MaxLevel = 4,
		Art = "Duelist_R_Vigil",
		Name = "경계",
		Description = "`신경을 곤두세우고 깊은 호흡을 들여` 사용 후 준비자세를 취하는동안 패링을 성공시킬 시 [집중]을 {1} 얻는다.\n"
			.. "(턴당 {1}회)",
		Levels = { { 1, 1, 1, 1 }, { 1, 2, 3, 4 } },
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Precision" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Duelist_C_CatchBreath",
		Art = "Duelist_C_CatchBreath",
		Name = "숨 고르기",
		Description = "패링을 할 때마다 스테미나를 {2} 얻는다.",
		Levels = { { 2, 4, 6, 8, 10, 12 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_SwitchGuard",
		MaxLevel = 5,
		Art = "Duelist_C_SwitchGuard",
		Name = "전환 보호",
		Description = "태세를 바꾼 턴에 [받는 피해량]이 {8}% 감소한다.",
		Levels = { { 8, 12, 16, 20, 24 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_WarmUp",
		Art = "결투사의_레이피어",
		MaxLevel = 2,
		Name = "예열",
		Description = "전투 시작 시 [집중]을 {1} 얻는다.",
		Levels = { { 1, 2 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_ShallowCut",
		MaxLevel = 4,
		Art = "Duelist_C_ShallowCut",
		Name = "얕은 상처",
		Description = "`앞뒤관통` 스킬이 [출혈]을 {1} 부여한다.",
		Levels = { { 1, 2, 3, 4 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Composure",
		MaxLevel = 5,
		Art = "결투사의_레이피어",
		Name = "평정",
		Description = "[집중] 수치당 [받는 피해량]이 {0.2}% 더 감소한다.",
		Levels = { { 0.2, 0.5, 0.8, 1.1, 1.4 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Guard" },
	},
	{
		Id = "Duelist_C_FlowThrough",
		Art = "Duelist_C_FlowThrough",
		Name = "반동",
		Description = "패링 직후의 공격은 스테미나를 {80}%만 사용한다.",
		Levels = { { 80, 70, 60, 50, 40, 30 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_FindTheSpot",
		Art = "Duelist_C_FindTheSpot",
		Name = "급소 찾기",
		Description = "[출혈] 상태의 적을 처치하면, 다음 공격의 치명타 확률이 {5}% 증가한다.",
		Levels = { { 5, 10, 15, 20, 25, 30 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Offense",
		MaxLevel = 2,
		Art = "Duelist_C_Offense",
		Name = "공세",
		Description = "공격 태세의 [받는 피해량] 증가가 {5}% 감소한다.\n"
			.. "위 효과는 합연산으로 계산된다.",
		Levels = { { 5, 8 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Defense",
		MaxLevel = 4,
		Art = "Duelist_C_Defense",
		Name = "수세",
		Description = "방어 태세의 [가하는 피해량] 감소가 {5}% 감소한다.",
		Levels = { { 5, 8, 11, 15 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Conclusion",
		MaxLevel = 1,
		Art = "결투사의_레이피어",
		Name = "결착",
		Description = "적을 처치하면, [집중]을 {2} 추가로 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Execute" },
	},
	{
		Id = "Duelist_C_Sentry",
		Art = "Duelist_C_Sentry",
		Name = "파수",
		Description = "전열(1~2열)에 서 있으면 [회피 시간]이 {8}% 증가한다.\n인접한 아군의 [회피 시간]이 {4}% 증가한다.",
		Levels = { { 8, 10, 12, 14, 16, 18 }, { 4, 6, 8, 10, 10, 10 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_C_LowStance",
		Art = "Duelist_C_LowStance",
		Name = "자세 낮추기",
		Description = "같은 태세를 두 턴 이상 유지하면 그 태세 효과가 턴당 {10}%씩, 최대 {30}%까지 증가한다.\n"
			.. "위 효과는 곱연산으로 계산된다.",
		Levels = { { 10, 12, 14, 15, 15, 15 }, { 30, 40, 50, 60, 70, 80 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Restraint",
		MaxLevel = 1,
		Art = "결투사의_레이피어",
		Name = "절제",
		Description = "공격을 하지 않고 턴을 마치면, 자신의 모든 스킬의 쿨타임이 {1}턴 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_Retribution",
		MaxLevel = 5,
		Art = "Duelist_C_Retribution",
		Name = "복수",
		Description = "자신을 공격한 적에게 다음 턴에 [가하는 피해량]이 {12}% 증가한다.",
		Levels = { { 12, 16, 20, 24, 28 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Execute" },
	},
	{
		Id = "Duelist_C_Bond",
		Art = "Duelist_C_Bond",
		Name = "결속",
		Description = "자신이 얻는 [회피 시간] 증가의 {10}%를 인접한 아군 또한 받는다.\n"
			.. "위 효과는 곱연산으로 계산된다.",
		Levels = { { 10, 15, 20, 25, 30, 35 } },
		Party = true,
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Riposte" },
	},
	{
		Id = "Duelist_C_BleedInduce",
		MaxLevel = 5,
		Art = "Duelist_C_BleedInduce",
		Name = "깊은 상처",
		Description = "[출혈]을 부여할 때, {1} 추가로 부여한다.\n"
			.. "(턴당 {1}회)",
		Levels = { { 1, 1, 2, 2, 2 }, { 1, 2, 2, 3, 4 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Steady",
		Art = "Duelist_C_Steady",
		Name = "안정",
		Description = "`신경을 곤두세우고 깊은 호흡을 들여 사용 후 준비 자세를 취하는 동안 [받는 피해량]이 {8}% 더 감소한다.\n"
			.. "위 효과는 합연산으로 계산된다.",
		Levels = { { 8, 10, 12, 14, 16, 18 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "Duelist_C_BladeTip",
		MaxLevel = 3,
		Art = "결투사의_레이피어",
		Name = "칼끝",
		Description = "[집중] 수치당 [치명타 확률]이 {0.5}% 증가한다.",
		Levels = { { 0.5, 0.7, 1 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_StepBack",
		Art = "Duelist_C_StepBack",
		Name = "흐름",
		Description = "패링에 성공하면, 이번 전투동안 [회피 시간]이 {2.5}% 증가한다.\n"
			.. "(최대 {25}%)\n"
			.. "위 효과는 합연산으로 계산된다.",
		Levels = { { 2.5, 3, 3.5, 4, 4.5, 5 }, { 25, 27, 28, 32, 36, 40 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_GripWrap",
		MaxLevel = 3,
		Art = "Duelist_C_GripWrap",
		Name = "칼자루 감기",
		Description = "자동 패링 발동 시 공격자에게 [출혈]을 {1} 부여한다.",
		Levels = { { 1, 2, 3 } },
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
