--!strict
--[[
	AbilityCardDefinitions — 탑 층별 보상으로 뽑는 직업별 능력 카드.

	사양 출처: 추가&수정.md `###### 능력 카드`

	등급별 규칙
	  필수(Essential) : 직업당 4종. **5·10·20·25층에서 3종 출현.** 최대 레벨 2.
	                    일종의 전직이며, 조합에 따라 직업 매커니즘이 바뀐다.
	  희귀(Rare)      : 직업당 10종. 층마다 2종 출현. 최대 레벨 6.
	  일반(Common)    : 직업당 20종. 층마다 4종 출현. 최대 레벨 6.

	--------------------------------------------------------------------------
	필수 층은 **두 화면**이다 (요청: "필수 카드 먼저 나오고 일반 희귀 카드가 나오도록")

	  첫 번째 화면  필수 3종
	  두 번째 화면  희귀 2 + 일반 4 = 6종

	한 줄에 섞어 놓으면 9장이 깔려 화면에 들어가지도 않고, 전직 카드와 소소한
	강화 카드를 같은 줄에서 비교하게 된다. 5의 배수 층은 원래 **2장을 고르므로**
	(`AcquireSlotsForFloor`) 화면을 둘로 나누는 데 필요한 자리가 이미 있다.
	첫 장을 고르면 두 번째 화면이 새로 제시된다.

	설계 원칙 (사양)
	  - 카드는 모션과 이펙트에 영향을 주면 안 된다.
	  - 단순 능력치 증가 카드는 금지. **기믹을 활용한 덱 빌딩**에 중점을 둔다.
	  - 참고: Yostar 『스텔라 소라』의 잠재력 시스템.

	이 모듈은 뽑기 규칙과 카드 풀 스키마를 담당한다.
	직업별 실제 카드 목록은 RegisterClassCards로 등록한다.

	--------------------------------------------------------------------------
	수치 기준 (요청: "수치 변화가 들어가는 게 있으면 다 써줘 / 레벨당 값도")

	설명에 **초기값과 레벨당 증가치를 반드시 함께** 적는다.
	  예) "보호막 획득량이 8% 늘어납니다. (레벨당 +3%)"

	기준으로 삼은 기존 수치 (추가&수정.md `## 육성 시스템`, CharacterDefinitions)
	  1레벨 기본 체력 60 · 매 턴 최대 체력 5% 회복
	  스테미나 60 · 매 턴 8 회복
	  스킬 피해 18~40 (BattleSkills)
	  그로기 최대 100 · 패리 성공 시 +15 · 스턴 1턴
	  스탯 1점 = 물리 5% / 원거리 7% / 패리·회피 타이밍 3%

	등급별 크기 (한 장이 전투에 주는 영향)
	  필수  최대 Lv2. 규칙 자체를 바꾸므로 **비율보다 조건**을 적는다.
	        수치가 있으면 큼직하게(20~40%), 레벨당 증가폭도 크게.
	  희귀  최대 Lv6. 초기 8~15%, 레벨당 +2~4%. 또는 flat 3~8, 레벨당 +1~2.
	  일반  최대 Lv6. 초기 4~8%, 레벨당 +1~2%. 또는 flat 1~4, 레벨당 +1.

	Lv6까지 올렸을 때 일반 카드 한 장이 대략 초기값의 2배에 닿도록 잡는다
	(초기 6% + 레벨당 2% × 5 = 16%처럼 과해지지 않게).

	**단순 능력치 증가 카드 금지**라는 사양은 그대로다. 수치는 조건·전환·스택에
	붙는 값이지, "공격력 +N%" 같은 무조건 증가가 아니다.
	--------------------------------------------------------------------------
]]

local Keywords = require(script.Parent.Keywords)

export type CardGrade = "Essential" | "Rare" | "Common"

export type AbilityCard = {
	Id: string,
	--[[
		설명. 레벨에 따라 달라지는 수치는 `{1}`, `{2}` 자리표시자로 적는다.

		예) "보유한 [꽉 찬 병] 1개당 가하는 피해량이 {1}% 증가한다."

		실제로 화면에 뿌릴 때는 `Describe(card, level)`을 쓴다. 자리표시자가 없는
		카드는 레벨과 무관하게 같은 글이 나온다.
	]]
	Description: string,
	--[[
		자리표시자에 들어갈 **레벨별 수치**.

		`Levels[1]`이 `{1}`의 값이고, 그 안의 인덱스가 카드 레벨이다.
		길이는 등급 상한과 같아야 한다(필수 2, 나머지 6).

		--------------------------------------------------------------------------
		왜 이렇게 바꿨나 (요청)

		  "(레벨당 +n) 등의 표현을 없앰. 매 레벨마다 카드에 적힌 수치를 다르게 할 것."

		예전에는 설명이 통짜 문자열이라 레벨이 올라도 글이 그대로였고, 대신 괄호로
		"(레벨당 +1%)"를 덧붙여 플레이어가 암산하게 만들었다. 이제 레벨에 맞는
		숫자가 카드에 직접 찍힌다.
	]]
	Levels: { { number } }?,
	--[[
		각 사다리가 **어떤 키워드의 값인지**. `Levels`와 같은 순서다.

		  Description   = "가하는 피해량이 {1}% 증가한다."
		  Levels        = { { 3, 4, 5, 6, 7, 8 } }
		  LevelKeywords = { "DamageDealt" }

		없어도 게임은 돌아간다 — 이건 편집기와 사람을 위한 이름표다. 붙여 두면
		"이 카드의 3은 무엇의 3인가"가 소스만 봐도 읽히고, 편집기가 같은 키워드를
		쓰는 카드들을 나란히 놓고 세기를 비교할 수 있다.

		값 자체는 **카드마다 따로**다(요청). 키워드는 종류만 말한다.

		--------------------------------------------------------------------------
		한 슬롯에 낱말을 **여럿** 이을 수 있다(요청).

		  Description   = "가하는 피해량과 받는 피해량이 각각 {1}% 오른다."
		  Levels        = { { 3, 4, 5, 6, 7, 8 } }
		  LevelKeywords = { "DamageDealt,DamageTaken" }

		슬롯 문자열 하나에 쉼표로 이어 담는다 — 배열 길이는 그대로 슬롯 수(글의
		중괄호 개수)와 같다. `Describe`가 쉼표로 갈라 하나씩 대조한다.
	]]
	LevelKeywords: { string }?,
	--[[
		이 카드만 쓰는 레벨 상한. 없으면 등급표(`RULES[Grade].MaxLevel`)를 그대로
		따른다 — 대부분의 카드가 이렇다. `MaxLevelFor`가 이 둘을 하나로 합친다.

		뽑기 상한(`CardDraft`)·표시(`TowerService`)·`Describe`의 사다리 길이가
		전부 이 값을 따라가므로, 여기서 늘리면 `Levels`의 각 사다리도 그만큼
		칸이 있어야 한다 — 편집기의 "최대 레벨" 칸이 사다리 칸 수를 같이 맞춘다.
	]]
	MaxLevel: number?,
	Name: string,
	--[[
		손으로 그린 그림의 Id (`CardArtworks`).

		비워 두면 태그를 보고 문양이 저절로 그려진다. 그래서 306장을 다 그리지
		않아도 게임이 돌아가고, 마음에 안 드는 카드만 골라 그려 넣으면 된다.
	]]
	Art: string?,
	Grade: CardGrade,
	ClassId: string,
	-- 기믹 태그. 덱 빌딩에서 카드끼리 연계되는 축을 나타낸다.
	-- 예: "Bleed", "Parry", "Prayer", "Overload"
	Tags: { string },
	--[[
		함께 가질 수 없는 카드(필수 카드의 전직 갈래). 둘 중 하나를 가지면 다른 쪽은 더 안 나온다.
		서로 적어 두지 않아도 된다 — 한쪽에만 적어도 양쪽이 막힌다(`Excluded`).
	]]
	Excludes: { string }?,
	-- 파티(아군 여럿)를 전제로 한 카드. 솔로 뽑기에서 덜 나오고 카드에 "파티" 표시가 붙는다.
	Party: boolean?,
}

export type GradeRule = {
	Grade: CardGrade,
	PoolSizePerClass: number, -- 직업당 보유 종류 수
	DrawPerFloor: number, -- 층 클리어마다 나오는 종류 수
	MaxLevel: number,
	-- 확정 추가 출현 주기(층). 0이면 주기 출현 없음.
	GuaranteedEveryFloors: number,
	GuaranteedCount: number,
}

local RULES: { [CardGrade]: GradeRule } = {
	Essential = {
		Grade = "Essential",
		PoolSizePerClass = 4,
		DrawPerFloor = 0, -- 평상시엔 안 나온다
		MaxLevel = 2,
		--[[
			나오는 층은 주기가 아니라 목록이다(`ESSENTIAL_FLOORS`: 5·10·20·25).
			주기로는 표현되지 않아 이 값은 쓰지 않는다.
		]]
		GuaranteedEveryFloors = 0,
		GuaranteedCount = 3, -- 3종 확정 추가
	},
	Rare = {
		Grade = "Rare",
		PoolSizePerClass = 10,
		DrawPerFloor = 2,
		MaxLevel = 6,
		GuaranteedEveryFloors = 0,
		GuaranteedCount = 0,
	},
	Common = {
		Grade = "Common",
		PoolSizePerClass = 20,
		DrawPerFloor = 4,
		MaxLevel = 6,
		GuaranteedEveryFloors = 0,
		GuaranteedCount = 0,
	},
}

-- ClassId → Grade → 카드 목록
local pools: { [string]: { [CardGrade]: { AbilityCard } } } = {}

local AbilityCardDefinitions = {}

AbilityCardDefinitions.Rules = RULES

-- 카드 레벨 상한 (필수 2, 나머지 6)
function AbilityCardDefinitions.MaxLevel(grade: CardGrade): number
	return RULES[grade].MaxLevel
end

-- 이 카드의 레벨 상한. `card.MaxLevel`이 있으면 그것, 없으면 등급표를 따른다.
function AbilityCardDefinitions.MaxLevelFor(card: AbilityCard): number
	return card.MaxLevel or RULES[card.Grade].MaxLevel
end

-- 소수는 필요한 만큼만. `3.0`이 아니라 `3`, `1.20`이 아니라 `1.2`.
local function trim(value: number): string
	if value % 1 == 0 then
		return tostring(math.floor(value))
	end
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

--[[
	이 레벨에서 카드에 찍힐 설명.

	두 가지를 갈아 끼운다.
	  `{3}`      → 이 레벨의 값. **글에 나온 순서**가 몇 번째 사다리인지 정한다.
	  `[키워드]`  → 낱말 + 그 키워드의 값 (사다리가 붙어 있을 때)

	중괄호 안 숫자는 **레벨 1의 값**이지 슬롯 번호가 아니다. 예전에는 번호였는데,
	글쓴이가 "여기 3%"라고 생각하면서 `{1}`을 적어야 해 헷갈렸고 사다리를 하나
	끼워 넣으면 뒤 번호가 전부 밀렸다.

	레벨은 1부터이며 범위를 벗어나면 가장 가까운 쪽으로 물린다 — 0레벨 미리보기는
	1레벨 값을 보여준다.
]]
function AbilityCardDefinitions.Describe(card: AbilityCard, level: number?): string
	--[[
		**사다리가 없어도 중괄호는 벗긴다.**

		예전에는 `Levels`가 없으면 글을 손도 대지 않고 그대로 돌려줬다. 그런데
		이제는 사다리가 없는 카드에도 편집기가 다루기 좋도록 숫자마다 중괄호를
		씌워 두었다 — 그대로 두면 플레이어에게 `{3}`이 그대로 보인다. 실제로
		그렇게 나오고 있었다(카드 300장 가까이가 이 경우다).

		사다리가 없으면 `valueAt`이 nil을 주고, 그때는 중괄호 안 숫자를 그대로
		쓴다. 즉 괄호만 벗겨진다.
	]]
	local values = card.Levels
	local step = math.floor(level or 1)
	local function valueAt(slot: number): string?
		if not values then
			return nil
		end
		local ladder = values[slot]
		if not ladder or #ladder == 0 then
			return nil
		end
		return trim(ladder[math.clamp(step, 1, #ladder)])
	end

	--[[
		중괄호를 **나온 순서대로** 세어 사다리를 고른다.
		숫자는 소수도 된다(`{1.2}`) — 안의 값은 참고용이고 실제 값은 사다리가 준다.
	]]
	local seen = 0
	local text = card.Description:gsub("{([%d%.%-]+)}", function(shown: string): string
		seen += 1
		return valueAt(seen) or shown
	end)

	--[[
		**`[키워드]`에도 값을 붙인다** (요청).

		`LevelKeywords`가 그 키워드를 가리키는 사다리를 알려 준다. 붙일 값이 있으면
		`[가하는 피해량]`이 `가하는 피해량 3%`로 나온다. 사다리가 없는
		낱말(예: `[꽉 찬 병]`)은 대괄호만 벗고 그대로 남는다 — 화면에서는 색으로
		구분되므로 대괄호가 없어도 낱말인 것이 읽힌다.
	]]
	--[[
		한 슬롯에 낱말을 **여럿** 이을 수 있다(요청). `LevelKeywords[slot]`은 그때
		쉼표로 이은 Id 문자열("DamageDealt,DamageTaken")이다 — 배열 타입은 그대로
		두고 그 안의 문자열 하나가 여러 Id를 담을 수 있게만 한 것이다.
	]]
	local function slotHasKeyword(ids: string, id: string): boolean
		for candidate in ids:gmatch("[^,]+") do
			if candidate == id then
				return true
			end
		end
		return false
	end

	--[[
		**대괄호는 `LevelKeywords`가 없어도 벗긴다.**

		예전에는 이 갈아 끼우기가 통째로 `if card.LevelKeywords` 안에 있어서,
		사다리 이름표가 없는 카드는 `[약재]`처럼 대괄호가 그대로 플레이어에게
		보였다. 카드 300장 가까이가 그 경우였다.

		사전에 없는 낱말은 대괄호를 남긴다 — 오타를 눈에 띄게 두려는 것이다.
	]]
	--[[
		같은 낱말이 글에 **두 번 이상** 나올 수 있다(예: "[치명타 피해량]이 오르고,
		[치명타 피해량]은 최대 30%까지"). 예전에는 항상 그 낱말을 처음 이은 슬롯
		하나만 봤다 — 두 번째로 나온 자리도 첫 슬롯 값을 그대로 받아 값이 틀리게
		나왔다. 이제 몇 번째로 나왔는지 세어, 그 낱말을 이은 슬롯 중 같은 순번을
		쓴다.
	]]
	local keywordOccurrence: { [string]: number } = {}
	text = text:gsub("%[([^%]]+)%]", function(name: string): string
		local keyword = Keywords.ByName(name)
		if not keyword then
			return "[" .. name .. "]"
		end
		if card.LevelKeywords then
			local target = (keywordOccurrence[keyword.Id] or 0) + 1
			local matched = 0
			for slot, ids in card.LevelKeywords :: { string } do
				if slotHasKeyword(ids, keyword.Id) then
					matched += 1
					if matched == target then
						keywordOccurrence[keyword.Id] = target
						local value = valueAt(slot)
						if value then
							return string.format("%s %s%s", name, value, keyword.Unit)
						end
						break
					end
				end
			end
		end
		return name
	end)

	return text
end

--[[
	이 카드의 수치가 레벨에 따라 변하는지. 도감과 테스트가 쓴다.
]]
function AbilityCardDefinitions.HasScaling(card: AbilityCard): boolean
	return card.Levels ~= nil and #card.Levels > 0
end

--[[
	직업 카드 등록. 서버 초기화 시 직업별로 한 번씩 호출한다.
	사양의 종류 수(필수 4 / 희귀 10 / 일반 20)와 다르면 경고를 남긴다.
]]
-- 사양 위로 더 둔 카드(직업 → 등급 → 더 둔 수). 2026-10-04 사용자: 월 필그림 파상풍 카드 "추가"(희귀 2 · 일반 3)
AbilityCardDefinitions.EXTRA_CARDS = {
	WallPilgrim = { Rare = 2, Common = 3 },
} :: { [string]: { [string]: number } }

function AbilityCardDefinitions.ExpectedCount(classId: string, grade: string): number
	local extra = AbilityCardDefinitions.EXTRA_CARDS[classId]
	return RULES[grade].PoolSizePerClass + ((extra and extra[grade]) or 0)
end

function AbilityCardDefinitions.RegisterClassCards(classId: string, cards: { AbilityCard }): ()
	local byGrade: { [CardGrade]: { AbilityCard } } = {
		Essential = {},
		Rare = {},
		Common = {},
	}

	for _, card in cards do
		table.insert(byGrade[card.Grade], card)
	end

	for grade, rule in RULES do
		local count = #byGrade[grade]
		if count ~= AbilityCardDefinitions.ExpectedCount(classId, grade) then
			warn(
				string.format(
					"[AbilityCard] %s 직업의 %s 카드가 %d종입니다. 사양은 %d종입니다.",
					classId,
					grade,
					count,
					AbilityCardDefinitions.ExpectedCount(classId, grade)
				)
			)
		end
	end

	pools[classId] = byGrade
end

function AbilityCardDefinitions.GetPool(classId: string, grade: CardGrade): { AbilityCard }
	local classPool = pools[classId]
	if not classPool then
		return {}
	end
	return classPool[grade] or {}
end

--[[
	Id로 카드를 찾는다.

	등반 중 보유 카드 목록을 보여줄 때 쓴다 — `TowerRun.Cards`에는 Id·등급·레벨만
	남기므로 이름과 설명은 여기서 되찾는다(저장본에 텍스트를 중복해 넣지 않는다).
]]
function AbilityCardDefinitions.Get(cardId: string): AbilityCard?
	for _, classPool in pools do
		for _, gradeCards in classPool do
			for _, card in gradeCards do
				if card.Id == cardId then
					return card
				end
			end
		end
	end
	return nil
end

-- 결정적 셔플. 같은 seed면 항상 같은 결과가 나온다.
--[[
	필수 카드가 나오는 층 (요청: **5 · 10 · 20 · 25층에서 한 번씩**).

	주기 계산이 아니라 **명시한 목록**이다. 15층과 30층은 빠져 있어서
	`floor % 10 == 0` 같은 규칙으로는 표현되지 않는다.
]]
local ESSENTIAL_FLOORS: { [number]: boolean } = {
	[5] = true,
	[10] = true,
	[20] = true,
	[25] = true,
}

AbilityCardDefinitions.ESSENTIAL_FLOORS = ESSENTIAL_FLOORS

function AbilityCardDefinitions.IsEssentialFloor(floor: number): boolean
	return ESSENTIAL_FLOORS[math.floor(floor)] == true
end

--[[
	이번에 제시할 카드 한 화면을 만든다.

	  필수 층 + 아직 아무것도 안 골랐다 → **필수 3종**
	  그 밖의 모든 경우                 → 희귀 2종 + 일반 4종

	`pickedThisFloor`가 화면을 가른다. 필수 층에서 첫 장을 고르면 이 값이 1이 되고,
	그때 다시 부르면 희귀·일반 화면이 나온다 — 그래서 "필수 먼저, 그다음 희귀·일반"이
	된다. 값을 넘기지 않으면 0으로 본다(= 첫 화면).

	maxedCardIds에 든 카드(이미 최대 레벨)는 후보에서 빠진다.

	owned(지금 가진 카드 {CardId, Level})를 넘기면 **빌드를 읽고** 뽑는다(2026-09-28):
	  - 전직 배타(Excludes): 가진 필수와 부딪치는 필수는 나오지 않는다(철벽을 들었으면 광검·양날은 안 나온다).
	  - 파티 전제(Party): 솔로 전투라 1/4 확률로만 나온다.
	  - 시너지: 가진 카드와 축(Tags)이 겹칠수록 잘 나온다(겹친 장수당 +35%, 4장까지). 가진 카드의 강화도 +50%.
	  - 갈림길: 일반 화면에 **아직 없는 축**의 카드가 한 장도 없으면 마지막 한 장을 그런 카드로 바꾼다 —
	    한 축만 파다가 막히지 않게, 매 층 방향을 틀 선택지를 하나는 남긴다.
	owned 가 없으면 예전처럼 고르게 섞는다(파티 카드만 덜 나온다).
]]
local PARTY_WEIGHT = 0.25
local SYNERGY_PER_CARD = 0.35
local SYNERGY_CAP = 4
local UPGRADE_WEIGHT = 0.5

-- 가중치 순서 섞기(Efraimidis–Spirakis): 키 = u^(1/w) 가 큰 순서. 같은 씨앗이면 같은 순서.
local function weightedOrder(source: { AbilityCard }, weights: { [string]: number }, seed: number): { AbilityCard }
	local random = Random.new(seed)
	local keyed = {}
	for _, card in source do
		local w = math.max(weights[card.Id] or 1, 1e-6)
		table.insert(keyed, { Card = card, Key = random:NextNumber() ^ (1 / w) })
	end
	table.sort(keyed, function(a, b)
		return a.Key > b.Key
	end)
	local order = {}
	for _, entry in keyed do
		table.insert(order, entry.Card)
	end
	return order
end

function AbilityCardDefinitions.DrawForFloor(
	classId: string,
	floor: number,
	seed: number,
	maxedCardIds: { [string]: boolean }?,
	pickedThisFloor: number?,
	owned: { any }?
): { AbilityCard }
	local maxed = maxedCardIds or {}
	local result: { AbilityCard } = {}

	-- 빌드 읽기: 가진 카드·축·배타
	local ownedIds: { [string]: boolean } = {}
	local tagCount: { [string]: number } = {}
	local blocked: { [string]: boolean } = {}
	for _, entry in owned or {} do
		local card = AbilityCardDefinitions.Get(entry.CardId)
		if card then
			ownedIds[card.Id] = true
			for _, tag in card.Tags or {} do
				tagCount[tag] = (tagCount[tag] or 0) + 1
			end
			for _, other in card.Excludes or {} do
				blocked[other] = true
			end
		end
	end
	local hasBuild = next(ownedIds) ~= nil

	local function weightOf(card: AbilityCard): number
		local weight = 1
		if card.Party then
			weight *= PARTY_WEIGHT
		end
		if hasBuild then
			local shared = 0
			for _, tag in card.Tags or {} do
				shared += tagCount[tag] or 0
			end
			weight *= 1 + SYNERGY_PER_CARD * math.min(shared, SYNERGY_CAP)
			if ownedIds[card.Id] then
				weight *= 1 + UPGRADE_WEIGHT
			end
		end
		return weight
	end

	local function isBlocked(card: AbilityCard): boolean
		if blocked[card.Id] then
			return true
		end
		for _, other in card.Excludes or {} do
			if ownedIds[other] then
				return true
			end
		end
		return false
	end

	local function newAxis(card: AbilityCard): boolean
		for _, tag in card.Tags or {} do
			if not tagCount[tag] then
				return true
			end
		end
		return false
	end

	local function take(grade: CardGrade, count: number, saltedSeed: number)
		if count <= 0 then
			return
		end
		local available: { AbilityCard } = {}
		local weights: { [string]: number } = {}
		for _, card in AbilityCardDefinitions.GetPool(classId, grade) do
			if not maxed[card.Id] and not isBlocked(card) then
				table.insert(available, card)
				weights[card.Id] = weightOf(card)
			end
		end

		local picks = weightedOrder(available, weights, saltedSeed)
		local chosen: { AbilityCard } = {}
		for index = 1, math.min(count, #picks) do
			table.insert(chosen, picks[index])
		end
		-- 갈림길: 일반 화면에 새 축 카드가 하나도 없으면 마지막 장을 바꾼다
		if hasBuild and grade == "Common" and #chosen > 0 then
			local anyNew = false
			for _, card in chosen do
				anyNew = anyNew or newAxis(card)
			end
			if not anyNew then
				for index = count + 1, #picks do
					if newAxis(picks[index]) then
						chosen[#chosen] = picks[index]
						break
					end
				end
			end
		end
		for _, card in chosen do
			table.insert(result, card)
		end
	end

	--[[
		필수 층의 **첫 화면**은 필수만 보여주고 여기서 끝난다.
		희귀·일반은 한 장을 고른 뒤 다음 화면에서 나온다.
	]]
	if AbilityCardDefinitions.IsEssentialFloor(floor) and (pickedThisFloor or 0) <= 0 then
		take("Essential", RULES.Essential.GuaranteedCount, seed + floor * 7919)
		return result
	end

	-- 그 밖에는 늘 희귀와 일반이 같이 나온다.
	take("Rare", RULES.Rare.DrawPerFloor, seed + floor * 104729)
	take("Common", RULES.Common.DrawPerFloor, seed + floor * 1299709)

	return result
end

--[[
	이번 층에서 **얻을 수 있는** 카드 장수.

	요청: "5층 단위로 1개씩 늘어나는 게 아니라, **5층마다 2개씩** 선택할 수 있는 것."
	  → 5의 배수 층에서 2장, 그 외에는 1장.

	예전에는 `1 + floor/5`라 25층이면 6장이 됐다. 층이 오를수록 한 층에서 고르는
	장수가 계속 늘어나 후반이 통째로 카드 고르기가 됐다.

	주의: 이것은 '업그레이드 횟수'가 아니라 '획득 횟수'다.
	      같은 카드를 다시 얻으면 그때 강화된다(레벨 +1).
]]
function AbilityCardDefinitions.AcquireSlotsForFloor(floor: number): number
	local level = math.floor(math.max(floor, 0))
	if level > 0 and level % 5 == 0 then
		return 2
	end
	return 1
end

--[[
	이 카드를 더 얻을 수 있는지(= 강화 여지가 남았는지).
	최대 레벨에 도달하면 사양대로 다음 층부터 등장하지 않는다.
]]
function AbilityCardDefinitions.CanAcquire(grade: CardGrade, currentLevel: number): boolean
	return currentLevel < RULES[grade].MaxLevel
end

return AbilityCardDefinitions
