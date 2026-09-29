--!strict
--[[
	DuelistCards — 결투사(Duelist) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — 태세를 갈아 가며 싸우는 육각형 직업. 축은 **패링**.

	수치 앵커
	  집중 상한 10. 스택 1당 받는 피해 −0.5% / 피해 +1% / 패링 범위 +2.5%
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
		Name = "철벽",
		Description = "공격 태세가 사라지고 공격 스킬을 쓸 수 없게 된다. 패링할 때 받은 스킬 기본 피해량의 {25}%를 공격자에게 반사하고 패링 불가 "
			.. "스킬을 전투당 {1}회 패링할 수 있게 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_E_LightBlade",
		Name = "광검",
		Description = "방어 태세가 사라진다. 받는 피해량이 {25}% 늘어나는 대신 피해량이 {40}%, 치명타 피해량이 {15}% 증가한다. 공격 스킬로 "
			.. "적을 처치하면, 피해량이 {75}% 줄어든 채 무작위 대상에게 한 번 더 사용한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Execute", "Guard" },
	},
	{
		Id = "Duelist_E_DoubleEdge",
		Name = "양날",
		Description = "매 턴 태세가 강제로 바뀐다. 바뀔 때마다 [집중]을 {1} 소모하는 대신, 태세의 효과가 {30}% 증가하고 변경되는 태세마다 "
			.. "효과를 얻는다. 공격 태세: 스테미나를 {5} 얻고 공격 스킬의 기본 피해량이 {3} 증가한다.방어 태세: 보호막을 {5} 얻는다. "
			.. "자동 패링 확률이 {10}% 증가하고, 공격 대상이 된다면 출혈을 부여한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "Duelist_E_NamelessBlade",
		Name = "무명검",
		Description = "[집중] 상한이 {10}에서 {20}으로 증가한다. 대신 스택당 효과가 {40}% 감소한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Duelist_R_Bloodletting",
		Name = "방혈",
		Description = "출혈을 부여할 때마다 {3}턴 간 치명타 피해량이 {2.5}%, 최대 {5}중첩까지 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_R_NoSpend",
		Name = "불소모",
		Description = "[집중]이 최대일 때, 패링에 성공하면 스택을 {3}턴 당 한 번 소모하지 않는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Riposte" },
	},
	{
		Id = "Duelist_R_Counter",
		Name = "패링 어택",
		Description = "패링에 성공하면, 즉시 평타 피해의 {40}%로 반격한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_R_Pivot",
		Name = "발끝 전환",
		Description = "태세가 변경된 턴에 공격을 받으면, 패링 범위가 {5}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_R_FocusBreath",
		Name = "집중 호흡",
		Description = "{3}턴마다 [집중]을 {1} 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_R_Feint",
		Name = "페인트",
		Description = "태세를 바꾼 직후의 첫 공격은 회피되지 않고 피해량이 {20}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Execute" },
	},
	{
		Id = "Duelist_R_BloodLoss",
		Name = "실혈",
		Description = "출혈 상태의 적에게 주는 피해량이 {15}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_R_Slip",
		Name = "흘리기",
		Description = "패링에 실패하면, 받는 피해량이 {20}% 감소한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_R_HonedEdge",
		Name = "날 세우기",
		Description = "[집중] 스택이 {5} 이상일 때, 적의 방어력을 {25}% 무시한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Execute" },
	},
	{
		Id = "Duelist_R_Vigil",
		Name = "경계",
		Description = "준비 자세(3스킬) 중에 패링하면, [집중]을 {1} 더 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Precision" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Duelist_C_CatchBreath",
		Name = "숨 고르기",
		Description = "패링하면 스테미나를 {2} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_SwitchGuard",
		Name = "전환 보호",
		Description = "태세를 바꾼 턴에 받는 피해량이 {8}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_WarmUp",
		Name = "예열",
		Description = "전투 시작 시 [집중]을 {1} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_ShallowCut",
		Name = "얕은 상처",
		Description = "평타가 {1}턴의 출혈을 부여한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Composure",
		Name = "평정",
		Description = "[집중] {1}스택당 받는 피해량이 {0.2}% 더 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Guard" },
	},
	{
		Id = "Duelist_C_FlowThrough",
		Name = "받아넘기기",
		Description = "패링 직후의 공격은 스테미나를 {80}%만 사용한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_FindTheSpot",
		Name = "급소 찾기",
		Description = "출혈이 걸린 적을 처치하면 다음 공격의 치명타 확률이 {5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Offense",
		Name = "공세",
		Description = "공격 태세의 받는 피해량 증가가 {5}%p 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Defense",
		Name = "수세",
		Description = "방어 태세의 피해량 감소가 {5}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Conclusion",
		Name = "결착",
		Description = "적을 처치하면, [집중]을 추가로 {2} 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision", "Execute" },
	},
	{
		Id = "Duelist_C_Sentry",
		Name = "파수",
		Description = "아군이 인접해 있을 때, 패링 범위가 {8}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Guard" },
	},
	{
		Id = "Duelist_C_LowStance",
		Name = "자세 낮추기",
		Description = "같은 태세를 두 턴 이상 유지하면 그 태세 효과가 턴당 {10}%씩, 최대 {30}%까지 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard" },
	},
	{
		Id = "Duelist_C_Restraint",
		Name = "절제",
		Description = "기술을 쓰지 않고 턴을 마치면, 다음 기술의 재사용 대기가 {1}턴 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_Retribution",
		Name = "응징",
		Description = "자신을 공격한 적에게 다음 턴 주는 피해량이 {12}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte", "Execute" },
	},
	{
		Id = "Duelist_C_Bond",
		Name = "결속",
		Description = "자신이 얻는 패링 범위 증가의 {10}%를 인접한 아군 또한 받는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Riposte" },
	},
	{
		Id = "Duelist_C_BleedInduce",
		Name = "출혈 유도",
		Description = "자신이 부여하는 출혈의 지속 시간이 {1}턴 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Execute" },
	},
	{
		Id = "Duelist_C_Steady",
		Name = "안정",
		Description = "준비 자세(3스킬) 중 받는 피해량이 {8}% 더 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
	{
		Id = "Duelist_C_BladeTip",
		Name = "칼끝",
		Description = "[집중] {1}스택당 치명타 확률이 {0.5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Precision" },
	},
	{
		Id = "Duelist_C_StepBack",
		Name = "흐름",
		Description = "패링에 성공하면, 패링 범위가 {2.5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Riposte" },
	},
	{
		Id = "Duelist_C_GripWrap",
		Name = "칼자루 감기",
		Description = "자동 패링이 발동되면, 대상에게 {1}턴 의 출혈을 부여한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Guard", "Precision" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
