--!strict
--[[
	Keywords — 카드·스킬 글에 나오는 **대괄호 낱말**의 사전.

	카드 설명은 오래도록 `[꽉 찬 병]`, `[도발]`, `[가하는 피해량 증가]` 같은 낱말을
	써 왔지만 그것들이 무엇인지는 어디에도 적혀 있지 않았다. 글쓴이의 머릿속에만
	있었고, 그래서 같은 것을 `[받는 피해 증가]`와 `[받는 피해량 증가]`로 나눠 쓰는
	일이 생겼다.

	이 표는 세 가지를 한다.
	  1. 어떤 낱말이 **정식 키워드**인지 정한다 (오타를 테스트가 잡는다)
	  2. 게임 안에서 낱말에 설명을 띄운다
	  3. 편집기가 "이 카드의 수치가 어떤 키워드에 붙는지" 고르게 한다

	--------------------------------------------------------------------------
	카드의 레벨 수치와 어떻게 이어지나

	카드는 `Levels`에 레벨별 값을 들고 `{1}` 자리표시자로 글에 꽂는다. 거기에
	`LevelKeywords`를 붙이면 그 사다리가 **어떤 키워드의 값인지**가 분명해진다.

	  Description   = "가하는 피해량이 {1}% 증가한다."
	  Levels        = { { 3, 4, 5, 6, 7, 8 } }
	  LevelKeywords = { "DamageDealt" }

	값은 **카드마다 따로**다(요청). 키워드는 "무엇에 붙는 값인가"만 말하고,
	얼마인지는 카드가 정한다 — 만족감과 절박함이 같은 키워드를 쓰면서 세기가
	다를 수 있어야 하기 때문이다.
]]

--[[
	`Neutral` — 이롭다·해롭다로 못 가르는 것들(요청). 부호로 방향을 가르는
	수치(`가하는 피해량`처럼 음수면 반대로 도는 것들)를 전부 `Buff`로 적어
	두면 음수일 때 거짓말이 된다. "중립 상태이상"으로 표시된다.
]]
export type Kind = "Buff" | "Debuff" | "Status" | "Resource" | "Neutral"

export type Keyword = {
	Id: string,
	-- 글에 실제로 적히는 말. `[이 이름]`으로 쓴다.
	Name: string,
	Kind: Kind,
	Description: string,
	--[[
		수치를 붙일 수 있는 키워드인지. 참이면 편집기가 레벨 사다리를 붙일 수 있다.
		[출혈]처럼 수치 자체가 상태이상 정의에 있는 것은 거짓이다.
	]]
	Scalable: boolean,
	-- 화면에 쓰는 단위. "%" 또는 "" (개수·턴).
	Unit: string,
}

local Keywords = {}

local LIST: { Keyword } = {
	--=== 공용 버프·디버프 ===--
	{
		Id = "DamageDealt",
		Name = "가하는 피해량",
		Kind = "Neutral",
		Description = "주는 피해량이 표기된 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 피해량 = 기본 피해량 * (1 + [가하는 피해량]%)",
		Scalable = true,
		Unit = "%",
		Color = "#ff8a52",
	},
	{
		Id = "DamageTaken",
		Name = "받는 피해량",
		Kind = "Neutral",
		Description = "[받는 피해량]이 표기된 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 피격량 = 공격자의 최종 피해량 * (1 + [받는 피해량]%)",
		Scalable = true,
		Unit = "%",
		Color = "#e05a5a",
	},
	{
		Id = "CritChance",
		Name = "치명타 확률",
		Kind = "Neutral",
		Description = "치명타를 가할 확률이 수치(%)만큼 증가함.\n"
			.. "해당 수치가 100%를 초과할 시 초과량만큼 [치명타 피해량]이 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 치명타 확률 = 기본 치명타 확률% + [치명타 확률]%",
		Scalable = true,
		Unit = "%",
		Color = "#ffd166",
	},
	{
		Id = "CritDamage",
		Name = "치명타 피해량",
		Kind = "Neutral",
		Description = "자신이 가하는 치명타의 피해량이 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 치명타 피해량 = 최종 피해량 * (150% + [치명타 피해량]%)",
		Scalable = true,
		Unit = "%",
		Color = "#ffb03a",
	},
	{
		Id = "HealDealt",
		Name = "주는 회복량",
		Kind = "Neutral",
		Description = "아군에게 [주는 회복량]이 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 회복량 = 기존 회복량 * (1 + [주는 회복량]% + [받는 회복량]%)",
		Scalable = true,
		Unit = "%",
		Color = "#4fd0a0",
	},
	{
		Id = "HealTaken",
		Name = "받는 회복량",
		Kind = "Neutral",
		Description = "자연 회복 포함, 자신에게 들어오는 모든 회복량이 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 회복량 = 기존 회복량 * (1 + [주는 회복량]% + [받는 회복량]%)",
		Scalable = true,
		Unit = "%",
		Color = "#6fdc8c",
	},
	{
		Id = "BuffDealt",
		Name = "주는 버프 효율",
		Kind = "Neutral",
		Description = "주는 버프의 효율이 수치(%)만큼 증가함.\n"
			.. "자신에게 주는 버프에도 포함됨.\n"
			.. "합연산.\n"
			.. "예)\n"
			.. "- [가하는 피해량] 50% 증가 버프가 있음.\n"
			.. "- [주는 버프 효율] 50%\n"
			.. "- [가하는 피해량] 50% 증가 버프에 + 50%가 달려 총 100%만큼 [가하는 피해량] 증가 버프를 줌.\n"
			.. "공식: 최종 버프 수치(%) = 기본 버프 수치(%) + [주는 버프 효율](%) + [받는 버프 효율](%)",
		Scalable = true,
		Unit = "%",
		Color = "#c8d95a",
	},
	{
		Id = "BuffTaken",
		Name = "받는 버프 효율",
		Kind = "Neutral",
		Description = "받는 버프의 효율이 수치(%)만큼 증가함.\n"
			.. "합연산.\n"
			.. "공식: 최종 버프 수치(%) = 기본 버프 수치(%) + [주는 버프 효율](%) + [받는 버프 효율](%)",
		Scalable = true,
		Unit = "%",
		Color = "#9ee08a",
	},
	{
		Id = "ParryWindow",
		Name = "회피 시간",
		Kind = "Neutral",
		-- 2026-09-29: 회피 QTE 가 방향 입력이 되어 "범위"가 뜻이 없어졌다 → 입력 시간으로 바꿈(Id 는 그대로)
		Description = "방향 회피 QTE 의 입력 시간이 표기된 수치(%)만큼 늘어남.\n"
			.. "합연산. 최대 +100%.",
		Scalable = true,
		Unit = "%",
		Color = "#7ad4e0",
	},
	{
		Id = "Accuracy",
		Name = "명중률",
		Kind = "Neutral",
		Description = "기본값 100%.\n"
			.. "[명중률]이 100%를 초과 시 [치명타 확률]이 (초과량 / 3)만큼 증가함. (소숫점 버림.)\n"
			.. "[명중률]이 100% 미만일 경우 (100% - 현재 [명중률]%)의 확률로 공격이 빗나감.",
		Scalable = true,
		Unit = "%",
		Color = "#c0d46a",
	},
	{
		Id = "Reflect",
		Name = "반사 피해",
		Kind = "Buff",
		Description = "맞을 때 공격자에게 되돌려주는 고정 피해. 비율만큼 반사함.\n"
			.. "절대값 반사의 경우 절대값만큼 반사 피해를 가함.\n"
			.. "공식: 최종 [반사 피해]량 = 최종 피격량 * [반사 피해]%\n"
			.. "절대값의 경우: 최종 [반사 피해]량 = 지정된 고정값\n"
			.. "능력 자체에 [반사 피해]량 공식이 지정된 경우: 해당 공식을 따라감.",
		Scalable = true,
		Unit = "",
		Color = "#a88ce0",
	},
	{
		Id = "Shield",
		Name = "보호막",
		Kind = "Buff",
		Description = "[받는 피해량]의 {100}%를 흡수 후 받은 피해량 만큼 감소.\n"
			.. "여유분이 남을 경우 다음 턴까지 지속됨.",
		Scalable = true,
		Unit = "",
		Color = "#5ce0d0",
	},

	--=== 상태이상 (상태이상.md) ===--
	{
		Id = "Bleed",
		Name = "출혈",
		Kind = "Debuff",
		Description = "매 턴 현재 체력의 5%만큼 물리 피해.\n"
			.. "턴 종료 시 1 감소.\n"
			.. "해당 효과로 사망할 수 없음.\n"
			.. "해당 상태이상은 대미지가 0 미만으로 떨어져선 안 됨.\n"
			.. "공식:\n"
			.. "최종 [출혈] 피해량 = 최대 체력 * 0.05 * (1 - 물리 피해 경감%)",
		Scalable = false,
		Unit = "",
		Color = "#d64252",
	},
	{
		Id = "Poison",
		Name = "독",
		Kind = "Debuff",
		Description = "매 턴 수치만큼 방어 무시 고정 피해.\n"
			.. "[받는 피해량] 증가의 영향을 받지 않음.\n"
			.. "턴 종료 시 3 감소.\n"
			.. "해당 효과로 사망할 수 없음.",
		Scalable = true,
		Unit = "",
		Color = "#7ec25a",
	},
	{
		Id = "Burn",
		Name = "화상",
		Kind = "Debuff",
		Description = "매 턴 수치%만큼 최대 체력 비례 화염 속성 피해를 받음.\n"
			.. "화염 속성 경감의 영향을 받음.\n"
			.. "최대 스택 40.\n"
			.. "턴 종료 시 1 감소.\n"
			.. "해당 효과로 사망할 수 없음.\n"
			.. "해당 상태이상은 대미지가 0 미만으로 떨어져선 안 됨.\n"
			.. "공식:\n"
			.. "최종 [화상] 피해량 = 최대 체력 * ([화상] 수치%) * (1 - 화염 속성 경감%)",
		Scalable = true,
		Unit = "",
		Color = "#ff7a2f",
	},
	{
		Id = "Oil",
		Name = "기름",
		Kind = "Debuff",
		Description = "화염 속성으로 받는 피해가 50% 증가함.\n"
			.. "화염 속성 피해 경감으로 취급함.\n"
			.. "곱연산.",
		Scalable = false,
		Unit = "",
		Color = "#a89b4a",
	},
	{
		Id = "Taunt",
		Name = "도발",
		Kind = "Neutral",
		Description = "아군에게 갈 공격을 자신이 뺏어올 확률이 생김.\n"
			.. "곱연산.\n"
			.. "공격 스틸 시 1 감소.\n"
			.. "공식: 최종 스틸 수치% = ([도발] * 10) * (1 - (기존 대상의 현재 체력 / 기존 대상의 최대 체력))",
		Scalable = true,
		Unit = "",
		Color = "#ff6fae",
	},
	{
		Id = "Overheal",
		Name = "과다 회복",
		Kind = "Debuff",
		Description = "받는 회복량이 대폭 감소함.\n"
			.. "곱연산.\n"
			.. "해당 효과로 인해 최종 [받는 회복량]이 음수가 될 수 없음.\n"
			.. "공식: 최종 [받는 회복량] = 최종 회복량  * (1 - 과다회복% * 8)",
		Scalable = true,
		Unit = "%",
		Color = "#c96fd4",
	},
	{
		Id = "Brand",
		Name = "낙인",
		Kind = "Debuff",
		Description = "[받는 회복량] -50%.\n"
			.. "합연산.",
		Scalable = true,
		Unit = "%",
		Color = "#e0609a",
	},
	{
		Id = "Groggy",
		Name = "그로기",
		Kind = "Debuff",
		Description = "한 턴 간 어떤 행동도 할 수 없음.",
		Scalable = false,
		Unit = "",
		Color = "#b0a8c0",
	},

	--=== 결투사 전용 상태이상 ===--
	{
		Id = "AttackStance",
		Name = "공격 태세",
		Kind = "Status",
		Description = "- [받는 피해량] +15%\n"
			.. "- [가하는 피해량] +(20 + 집중)%\n"
			.. "- [치명타 확률] +10%\n"
			.. "- 어떤 스킬이든 적중 시 [출혈] 1 부여.",
		Scalable = false,
		Unit = "",
		Color = "#b8503c",
	},
	{
		Id = "DefenseStance",
		Name = "방어 태세",
		Kind = "Status",
		Description = "- [받는 피해량] −30%\n"
			.. "- [가하는 피해량] −45%\n"
			.. "- [집중]의 자동 패링이 비활성화됨.\n"
			.. "  - 대신 피격 시 (5×[집중])% 확률로 자동 패링. (최대 30%)\n"
			.. "  - 궁극기·패링 불가 스킬 제외.",
		Scalable = false,
		Unit = "",
		Color = "#4a7ab8",
	},

	--=== 직업 자원 ===--
	{
		Id = "Note",
		Name = "음표",
		Kind = "Resource",
		Description = "- 4분·8분·16분으로 나뉘고 각각 주는 버프가 다름.\n"
			.. "- 음표의 값은 이름과 무관하게 전부 1임.\n"
			.. "  - 종류별로 따로 모이지 않고 한 곳에 쌓임.\n"
			.. "- 4분음표 (보라색)\n"
			.. "  - 아군 스테미나 획득량 +(2×개수)%\n"
			.. "  - 아군의 [치명타 확률] +(0.5×개수)%\n"
			.. "  - 자신의 두 번째 턴마다 아군에게 (1×개수)의 [보호막]\n"
			.. "- 8분음표 (분홍색)\n"
			.. "  - 아군의 [치명타 확률] · [치명타 피해량] +(1×개수)%\n"
			.. "  - 적 스테미나 획득량 −(2×개수)%\n"
			.. "- 16분음표 (옅은 남색)\n"
			.. "  - 아군의 [치명타 확률] **−**(0.5×개수)%\n"
			.. "  - 아군의 [치명타 피해량] +(2×개수)%\n"
			.. "  - 아군의 [가하는 피해량] +(1.5×개수)%",
		Scalable = true,
		Unit = "",
		Color = "#e884b0",
	},
	{
		Id = "Meter",
		Name = "박자표",
		Kind = "Resource",
		Description = "- 1에서 시작해 3까지 오름.\n"
			.. "- 값에 비례해 [음표] 최대치가 오름.\n"
			.. "  - 값 1 → 4개\n"
			.. "  - 값 2 → 8개\n"
			.. "  - 값 3 → 16개\n"
			.. "- 값 1당 [음표] 획득량 +1.\n"
			.. "- 최대치에서 `크레셴도`를 쓰면 [음표]를 전부 초기화하고 값이 1 오름.\n"
			.. "- 값이 3이고, [음표]가 16개 이상이면 `Cresc. al forte`로 `크레셴도`가 강화됨.\n"
			.. "- 이펙트\n"
			.. "  - 값 1: 플레이어 뒤에 작은 보표 하나\n"
			.. "  - 값 2: 대신 큰 보표 하나\n"
			.. "  - 값 3: 대신 큰 보표 4개\n"
			.. "  - [음표]가 가득 차면 가장 많은 [음표]의 색으로 빛남.",
		Scalable = true,
		Unit = "",
		Color = "#60c6d6",
	},
	{
		Id = "Brillante",
		Name = "브릴란테",
		Kind = "Buff",
		Description = "[브릴란테] * 1.5만큼 [치명타 확률]과 [치명타 피해량]이 증가함.",
		Scalable = true,
		Unit = "",
		Color = "#f0a6d8",
	},
	{
		Id = "Focus",
		Name = "집중",
		Kind = "Resource",
		Description = "- 최대 10스택.\n"
			.. "- 수치 1당 [받는 피해량] −0.5%, [가하는 피해량] +1%, [회피 시간] +2.5%.\n"
			.. "- 5스택 이상일 때 패링도 방어도 못 한 채 피격되면 3스택을 자동 소모 후 패링함.\n"
			.. "  - 궁극기·패링 불가 스킬 제외.",
		Scalable = true,
		Unit = "",
		Color = "#8fb8ff",
	},
	{
		Id = "Rage",
		Name = "분노",
		Kind = "Resource",
		Description = "- 최대 8스택.\n"
			.. "- 수치 1당 [가하는 피해량] + 10%.\n"
			.. "  - 합연산",
		Scalable = true,
		Unit = "",
		Color = "#ff5f5f",
	},
	{
		Id = "Mass",
		Name = "질량",
		Kind = "Resource",
		Description = "- 최대 20스택.\n"
			.. "- 수치 1당 [가하는 피해량] +1%, [받는 피해량] −0.5%.",
		Scalable = true,
		Unit = "",
		Color = "#9aa4c8",
	},
	{
		Id = "Gravity",
		Name = "중력",
		Kind = "Debuff",
		Description = "- 최대 1스택.\n"
			.. "- [받는 피해량] +15%.\n"
			.. "- 공격 실패 확률 +10%.\n"
			.. "- 행동 가능 칸이 (0,0), (0,1), (0,2), (1,0), (1,1), (1,2)로 제한됨.\n"
			.. "  - x값이 0인 칸이 모두 찰 경우 x값이 1인 칸으로 이동함.",
		Scalable = true,
		Unit = "",
		Color = "#7e76a8",
	},
	{
		Id = "Field",
		Name = "자기장",
		Kind = "Buff",
		Description = "- 3턴 유지.\n"
			.. "- 최대 1스택.\n"
			.. "- [받는 피해량] −20%.\n"
			.. "- 피격 시 공격자에게 [반사 피해] 8을 주고 [감극] 부여.",
		Scalable = true,
		Unit = "",
		Color = "#6ad0ff",
	},
	{
		Id = "Depolar",
		Name = "감극",
		Kind = "Debuff",
		Description = "- 2턴 유지.\n"
			.. "- 최대 3스택.\n"
			.. "- 수치 1당 [받는 피해량] +15%.",
		Scalable = true,
		Unit = "",
		Color = "#b47ae0",
	},
	{
		Id = "Resonate",
		Name = "공명",
		Kind = "Resource",
		Description = "- 최대 3스택.\n"
			.. "- 펄서의 `수렴`이 수치만큼 나눠 연타함(합은 한 방의 1.2배, 없으면 한 번).",
		Scalable = true,
		Unit = "",
		Color = "#5ad0b0",
	},
	{
		Id = "Zeal",
		Name = "광신",
		Kind = "Debuff",
		Description = "- 3턴 유지.\n"
			.. "- 수치 1당 [받는 피해량] +3%, [가하는 피해량] −2%.\n"
			.. "- 해당 상태이상을 부여한 월 필그림의 신앙심 스탯 10당 이 디버프의 수치가 10% 증가함. (최대 +50%)\n"
			.. "  - 곱연산.",
		Scalable = true,
		Unit = "",
		Color = "#b25ad0",
	},
	{
		Id = "Wall",
		Name = "벽",
		Kind = "Buff",
		Description = "- 3턴 유지\n"
			.. "- 최대 5스택.\n"
			.. "- 수치 1당 [받는 피해량] -4%, 자동 회피 · 패링 확률 +2%.\n"
			.. "- 해당 상태이상을 부여한 월 메이슨의 신앙심 스탯 10당 이 버프의 수치가 10% 강해짐. (최대 +50%)\n"
			.. "  - 곱연산.",
		Scalable = true,
		Unit = "",
		Color = "#c9b184",
	},
	{
		Id = "Ruin",
		Name = "허물 벽",
		Kind = "Resource",
		Description = "- 전투 종료까지 영구 지속.\n"
			.. "- 최대 5스택.\n"
			.. "- 수치 1당 [가하는 피해량] +5%, [받는 피해량] +3%.\n"
			.. "  - 합연산.",
		Scalable = true,
		Unit = "",
		Color = "#d08a5a",
	},
	{
		Id = "Herb",
		Name = "약재",
		Kind = "Resource",
		Description = "- 최대 6스택.\n"
			.. "- 수치 1당 [받는 회복량] +1%.\n"
			.. "  - 합연산.\n"
			.. "  - 회복을 2회 받을 때마다 수치 1 소모.\n"
			.. "    - 자연 회복은 포함되지 않음.",
		Scalable = true,
		Unit = "",
		Color = "#8ecf72",
	},
	{
		Id = "Extract",
		Name = "원액",
		Kind = "Resource",
		Description = "- 최대 4스택.\n"
			.. "- 체력이 10% 이하로 떨어지면 수치 1을 소모해 최대 체력의 10%를 회복.\n"
			.. "  - [받는 회복량] 증가와 [주는 회복량] 증가의 영향을 받음.\n"
			.. "  - 기본 회복량으로 취급.",
		Scalable = true,
		Unit = "",
		Color = "#5ec8a8",
	},
	{
		Id = "BrokenBottle",
		Name = "깨진 병",
		Kind = "Resource",
		Description = "- 최대 8스택.\n"
			.. "- `던지기` 스킬을 쓸 때마다 1 얻음.\n"
			.. "- 수치 1당 [가하는 피해량] +3%.",
		Scalable = true,
		Unit = "",
		Color = "#c9a46a",
	},
	{
		Id = "EmptyBottle",
		Name = "빈 병",
		Kind = "Resource",
		Description = "최대 8스택.",
		Scalable = true,
		Unit = "",
		Color = "#9fb6c4",
	},
	{
		Id = "FullBottle",
		Name = "꽉 찬 병",
		Kind = "Resource",
		Description = "- 서로 다른 네 종류가 한 상태이상 안에 들어 있음.\n"
			.. "  - 회복 병\n"
			.. "    - 체력이 5% 이하로 떨어지면 수치 1을 소모해 최대 체력의 25% 회복.\n"
			.. "    - 없으면 발동하지 않음.\n"
			.. "    - [받는 회복량] 증가와 [주는 회복량] 증가의 영향을 받음.\n"
			.. "    - 기본 회복량으로 취급.\n"
			.. "  - 독 병\n"
			.. "    - `던지기` 스킬로 공격 시 대상에게 [독] 10 부여.\n"
			.. "  - 화염병\n"
			.. "    - `던지기` 스킬로 공격 시 대상에게 [화상] 10 부여.\n"
			.. "  - 기름 병\n"
			.. "    - `던지기` 스킬로 공격 시 대상에게 [기름] 5 부여.",
		Scalable = true,
		Unit = "",
		Color = "#6ec4dc",
	},
	{
		Id = "HealBottle",
		Name = "회복 병",
		Kind = "Resource",
		Description = "- 체력이 5% 이하로 떨어지면 수치 1을 소모해 최대 체력의 25% 회복.\n"
			.. "  - 없으면 발동하지 않음.\n"
			.. "  - [받는 회복량] 증가와 [주는 회복량] 증가의 영향을 받음.\n"
			.. "  - 기본 회복량으로 취급.",
		Scalable = true,
		Unit = "",
		Color = "#7ee0a0",
	},
	{
		Id = "PoisonBottle",
		Name = "독 병",
		Kind = "Resource",
		Description = "`던지기` 스킬로 공격 시 대상에게 [독] 10 부여.",
		Scalable = true,
		Unit = "",
		Color = "#8cd070",
	},
	{
		Id = "FireBottle",
		Name = "화염병",
		Kind = "Resource",
		Description = "`던지기` 스킬로 공격 시 대상에게 [화상] 10 부여.",
		Scalable = true,
		Unit = "",
		Color = "#ff9450",
	},
	{
		Id = "OilBottle",
		Name = "기름 병",
		Kind = "Resource",
		Description = "`던지기` 스킬로 공격 시 대상에게 [기름] 5 부여.",
		Scalable = true,
		Unit = "",
		Color = "#b8a860",
	},
}

local byId: { [string]: Keyword } = {}
local byName: { [string]: Keyword } = {}
for _, keyword in LIST do
	byId[keyword.Id] = keyword
	byName[keyword.Name] = keyword
end

function Keywords.All(): { Keyword }
	return LIST
end

function Keywords.Get(id: string): Keyword?
	return byId[id]
end

-- 글에 적힌 이름으로 찾는다. `[가하는 피해량 증가]`의 속 내용이 그대로 들어온다.
function Keywords.ByName(name: string): Keyword?
	return byName[name]
end

--[[
	글에서 `[낱말]`을 전부 뽑는다. 사전에 없는 낱말도 그대로 돌려준다 — 무엇이
	빠졌는지 알아야 사전에 채워 넣을 수 있기 때문이다.
]]
function Keywords.Mentioned(text: string): { string }
	local found: { string } = {}
	local seen: { [string]: boolean } = {}
	for name in text:gmatch("%[([^%]]+)%]") do
		if not seen[name] then
			seen[name] = true
			table.insert(found, name)
		end
	end
	return found
end

return Keywords
