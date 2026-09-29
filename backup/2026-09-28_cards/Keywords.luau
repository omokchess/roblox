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
		Description = "자신이 주는 모든 피해가 그 비율만큼 커진다. 같은 종류끼리는 더해진다.",
		Scalable = true,
		Unit = "%",
		Color = "#ff8a52",
	},
	{
		Id = "DamageTaken",
		Name = "받는 피해량",
		Kind = "Neutral",
		Description = "자신이 받는 모든 피해가 그 비율만큼 커진다. 음수면 줄어든다.",
		Scalable = true,
		Unit = "%",
		Color = "#e05a5a",
	},
	{
		Id = "CritChance",
		Name = "치명타 확률",
		Kind = "Neutral",
		Description = "치명타가 터질 확률이 오른다.",
		Scalable = true,
		Unit = "%",
		Color = "#ffd166",
	},
	{
		Id = "CritDamage",
		Name = "치명타 피해량",
		Kind = "Neutral",
		Description = "치명타가 터졌을 때의 피해가 커진다.",
		Scalable = true,
		Unit = "%",
		Color = "#ffb03a",
	},
	{
		Id = "HealDealt",
		Name = "주는 회복량",
		Kind = "Neutral",
		Description = "남에게 주는 회복이 그 비율만큼 커진다. 음수면 줄어든다.",
		Scalable = true,
		Unit = "%",
		Color = "#4fd0a0",
	},
	{
		Id = "HealTaken",
		Name = "받는 회복량",
		Kind = "Neutral",
		Description = "자신이 받는 회복이 그 비율만큼 커진다. 음수면 감소다.",
		Scalable = true,
		Unit = "%",
		Color = "#6fdc8c",
	},
	{
		Id = "BuffDealt",
		Name = "주는 버프 효율",
		Kind = "Neutral",
		Description = "남에게 주는 버프의 세기가 커진다.",
		Scalable = true,
		Unit = "%",
		Color = "#c8d95a",
	},
	{
		Id = "BuffTaken",
		Name = "받는 버프 효율",
		Kind = "Neutral",
		Description = "남에게 받는 버프의 세기가 커진다.",
		Scalable = true,
		Unit = "%",
		Color = "#9ee08a",
	},
	{
		Id = "ParryWindow",
		Name = "패링 범위",
		Kind = "Neutral",
		Description = "패링·방어 판정을 받아 주는 시간 폭이 넓어진다.",
		Scalable = true,
		Unit = "%",
		Color = "#7ad4e0",
	},
	{
		Id = "Accuracy",
		Name = "명중률",
		Kind = "Neutral",
		Description = "공격이 빗나갈 확률이 줄어든다. 음수면 잘 빗나간다.",
		Scalable = true,
		Unit = "%",
		Color = "#c0d46a",
	},
	{
		Id = "Reflect",
		Name = "반사 피해",
		Kind = "Buff",
		Description = "맞을 때 공격자에게 되돌려주는 고정 피해. 비율이 아니라 절대값이다.",
		Scalable = true,
		Unit = "",
		Color = "#a88ce0",
	},
	{
		Id = "Shield",
		Name = "보호막",
		Kind = "Buff",
		Description = "체력보다 먼저 깎이는 추가 체력. 남으면 다음 턴까지 간다.",
		Scalable = true,
		Unit = "",
		Color = "#5ce0d0",
	},

	--=== 상태이상 (상태이상.md) ===--
	{
		Id = "Bleed",
		Name = "출혈",
		Kind = "Debuff",
		Description = "매 턴 최대 체력의 5%만큼 물리 피해. 턴이 끝날 때 1 줄어든다.",
		Scalable = false,
		Unit = "",
		Color = "#d64252",
	},
	{
		Id = "Poison",
		Name = "독",
		Kind = "Debuff",
		Description = "매 턴 수치만큼 고정 피해. 턴이 끝날 때 3 줄어든다.",
		Scalable = true,
		Unit = "",
		Color = "#7ec25a",
	},
	{
		Id = "Burn",
		Name = "화상",
		Kind = "Debuff",
		Description = "매 턴 수치 비율만큼 화염 피해. 턴이 끝날 때 1 줄어든다.",
		Scalable = true,
		Unit = "",
		Color = "#ff7a2f",
	},
	{
		Id = "Oil",
		Name = "기름",
		Kind = "Debuff",
		Description = "화염으로 받는 피해가 50% 커진다. 화염 계열과 짝이다.",
		Scalable = false,
		Unit = "",
		Color = "#a89b4a",
	},
	{
		Id = "Taunt",
		Name = "도발",
		Kind = "Neutral",
		Description = "다른 아군에게 갈 공격이 자신에게 올 확률이 오른다. 라인은 바뀌지 않는다.",
		Scalable = true,
		Unit = "",
		Color = "#ff6fae",
	},
	{
		Id = "Overheal",
		Name = "과다 회복",
		Kind = "Debuff",
		Description = "받는 회복량이 크게 줄어든다. 중첩끼리 곱해진다.",
		Scalable = true,
		Unit = "%",
		Color = "#c96fd4",
	},
	{
		Id = "Brand",
		Name = "낙인",
		Kind = "Debuff",
		Description = "[광신]이 상한까지 찬 적에게 남는 표식. 회복량이 크게 줄고, "
			.. "월 필그림의 표적 계열 카드가 이 상태를 밑천으로 쓴다.",
		Scalable = true,
		Unit = "%",
		Color = "#e0609a",
	},
	{
		Id = "Groggy",
		Name = "그로기",
		Kind = "Debuff",
		Description = "게이지가 가득 차면 한 턴 동안 아무것도 못 한다.",
		Scalable = false,
		Unit = "",
		Color = "#b0a8c0",
	},

	--=== 결투사 전용 상태이상 ===--
	{
		Id = "AttackStance",
		Name = "공격 태세",
		Kind = "Status",
		Description = "받는 피해량이 15%, 가하는 피해량이 (20 + [집중] 수치)%만큼 늘어난다. "
			.. "치명타 확률이 10% 오른다. 적중 시 짧은 [출혈]을 건다.",
		Scalable = false,
		Unit = "",
		Color = "#b8503c",
	},
	{
		Id = "DefenseStance",
		Name = "방어 태세",
		Kind = "Status",
		Description = "받는 피해량이 30%, 가하는 피해량이 45% 줄어든다. [집중]의 자동 패링이 꺼진다. "
			.. "대신 피격 시 ([집중] 수치 × 5)% 확률로 자동 패링한다(최대 30%). "
			.. "궁극기·패링 불가 스킬은 빼고 센다.",
		Scalable = false,
		Unit = "",
		Color = "#4a7ab8",
	},

	--=== 직업 자원 ===--
	{
		Id = "Note",
		Name = "음표",
		Kind = "Resource",
		Description = "음악가의 자원. 종류가 셋이지만 한 곳에 쌓인다.",
		Scalable = true,
		Unit = "",
		Color = "#e884b0",
	},
	{
		Id = "Meter",
		Name = "박자표",
		Kind = "Resource",
		Description = "음악가의 단계. 1에서 3까지 오르며 음표 상한을 정한다.",
		Scalable = true,
		Unit = "",
		Color = "#60c6d6",
	},
	{
		Id = "Brillante",
		Name = "브릴란테",
		Kind = "Buff",
		Description = "음악가가 아군에게 거는 치명타 버프.",
		Scalable = true,
		Unit = "",
		Color = "#f0a6d8",
	},
	{
		Id = "Focus",
		Name = "집중",
		Kind = "Resource",
		Description = "결투사의 자원. 최대 10. 스택마다 피해·방어·패링이 오른다.",
		Scalable = true,
		Unit = "",
		Color = "#8fb8ff",
	},
	{
		Id = "Rage",
		Name = "분노",
		Kind = "Resource",
		Description = "광전사의 자원. 최대 8. 한 번에 태워 다음 공격에 싣는다.",
		Scalable = true,
		Unit = "",
		Color = "#ff5f5f",
	},
	{
		Id = "Mass",
		Name = "질량",
		Kind = "Resource",
		Description = "퀘이사의 자원. 최대 20. 주고받은 피해에 비례해 쌓인다.",
		Scalable = true,
		Unit = "",
		Color = "#9aa4c8",
	},
	{
		Id = "Gravity",
		Name = "중력",
		Kind = "Debuff",
		Description = "퀘이사가 적에게 건다. 매 턴 끌려오고 받는 피해가 커진다.",
		Scalable = true,
		Unit = "",
		Color = "#7e76a8",
	},
	{
		Id = "Field",
		Name = "자기장",
		Kind = "Buff",
		Description = "펄서가 두르는 막. 맞으면 반사 피해와 [감극]을 준다.",
		Scalable = true,
		Unit = "",
		Color = "#6ad0ff",
	},
	{
		Id = "Depolar",
		Name = "감극",
		Kind = "Debuff",
		Description = "펄서가 적에게 건다. 최대 3중첩. 방어가 깎이고 받는 피해가 커진다.",
		Scalable = true,
		Unit = "",
		Color = "#b47ae0",
	},
	{
		Id = "Resonate",
		Name = "공명",
		Kind = "Resource",
		Description = "펄서가 같은 턴에 2스킬을 이어 쓸 때마다 쌓인다. 최대 3.",
		Scalable = true,
		Unit = "",
		Color = "#5ad0b0",
	},
	{
		Id = "Zeal",
		Name = "광신",
		Kind = "Debuff",
		Description = "월 필그림이 적에게 쌓는다. 최대 10중첩. 방어와 피해가 깎인다.",
		Scalable = true,
		Unit = "",
		Color = "#b25ad0",
	},
	{
		Id = "Wall",
		Name = "벽",
		Kind = "Buff",
		Description = "월 메이슨이 아군에게 두른다. 최대 5중첩. 방어와 회피가 오른다.",
		Scalable = true,
		Unit = "",
		Color = "#c9b184",
	},
	{
		Id = "Ruin",
		Name = "허물 벽",
		Kind = "Resource",
		Description = "월 브레이커의 자원. 최대 5중첩. 피해가 오르지만 받는 피해도 오른다.",
		Scalable = true,
		Unit = "",
		Color = "#d08a5a",
	},
	{
		Id = "Herb",
		Name = "약재",
		Kind = "Resource",
		Description = "연금술사의 자원. 매 턴 차오르고 1·2스킬에서 쓴다.",
		Scalable = true,
		Unit = "",
		Color = "#8ecf72",
	},
	{
		Id = "Extract",
		Name = "원액",
		Kind = "Resource",
		Description = "연금술사가 다지기로 얻는다. 섞기에서 병으로 바뀐다.",
		Scalable = true,
		Unit = "",
		Color = "#5ec8a8",
	},
	{
		Id = "EmptyBottle",
		Name = "빈 병",
		Kind = "Resource",
		Description = "연금술사의 그릇. 섞기가 이것을 채워 [꽉 찬 병]으로 만든다.",
		Scalable = true,
		Unit = "",
		Color = "#9fb6c4",
	},
	{
		Id = "FullBottle",
		Name = "꽉 찬 병",
		Kind = "Resource",
		Description = "던질 수 있는 병. 회복·독·화염·기름 네 종류가 있다.",
		Scalable = true,
		Unit = "",
		Color = "#6ec4dc",
	},
	{
		Id = "HealBottle",
		Name = "회복 병",
		Kind = "Resource",
		Description = "체력이 바닥나면 저절로 터지는 병.",
		Scalable = true,
		Unit = "",
		Color = "#7ee0a0",
	},
	{
		Id = "PoisonBottle",
		Name = "독 병",
		Kind = "Resource",
		Description = "던지면 대상에게 [독]을 건다.",
		Scalable = true,
		Unit = "",
		Color = "#8cd070",
	},
	{
		Id = "FireBottle",
		Name = "화염병",
		Kind = "Resource",
		Description = "던지면 대상에게 [화상]을 건다.",
		Scalable = true,
		Unit = "",
		Color = "#ff9450",
	},
	{
		Id = "OilBottle",
		Name = "기름 병",
		Kind = "Resource",
		Description = "던지면 대상에게 [기름]을 건다. 화염과 짝이다.",
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
