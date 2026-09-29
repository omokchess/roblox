--!strict
--[[
	BattleSkills — 전투 스킬의 범위와 피해.

	사양 출처: 추가&수정.md `##### 배치 및 전투`, 그리고 사용자가 직접 지정한 범위표.

	원래 이 표는 `Battle3DController`(클라이언트 시험판) 안에 있었다. 서버가 판정을
	가지게 되면서 **양쪽이 같은 정의를 봐야** 하므로 공유로 끌어올렸다. 클라이언트가
	미리보기로 칠하는 칸과 서버가 실제로 때리는 칸이 갈라지면, 이런 시스템에서 가장
	고치기 어려운 종류의 버그가 된다.

	범위는 `BattleGrid.Shape`로 적는다. 기준점(origin)은 **그 라인에서 상대가 실제로
	서 있는 칸**이다. 즉 아래 좌표는 전부 "상대가 있는 칸을 (n,n)이라 할 때" 기준이다.

	  Line   Radius r  (n,n)~(n+r-1,n)   앞으로 r칸
	  Row              (0,n)~(6,n)       라인 전체
	  Cross  Radius 1  (n,n),(n±1,n),(n,n±1)
	  Square Radius 1  (n-1,n-1)~(n+1,n+1)

	--------------------------------------------------------------------------
	직업별 스킬

	원래 이 파일에는 스킬 목록이 **하나뿐**이었다. 그래서 어떤 직업을 골라도 똑같은
	5개(찌르기·라인 관통·쌍베기·십자 참·광역 폭발)를 썼다 — 직업 선택이 전투에
	아무 영향을 주지 않는 상태였다.

	이제 `유저 아이디어(직업).md`의 스킬 1·2·3을 직업마다 그대로 옮겨 담는다.
	적은 직업이 없으므로 예전 5개를 **적 전용 목록**으로 남긴다.

	주의: md에서 "피해량: 없음"인 스킬(자가 버프·아군 버프)은 Damage 0으로 들어간다.
	상태이상 로직이 아직 없어서 지금은 실제로 아무 일도 하지 않는다.
]]

local BattleGrid = require(script.Parent.BattleGrid)
local ClassResources = require(script.Parent.ClassResources)

--[[
	사거리 태그.

	  Melee       근거리. 붙어서 때리거나 자신·아군에게 쓰는 것.
	  Ranged      원거리. 활·빔·투척처럼 떨어져서 닿는 것.
	  Supporting  서포팅. 버프·회복처럼 아군을 대상으로 하는 것(요청).

	격자 규칙(라인)과는 별개다 — 사거리는 **연출과 카드 조건**을 가르는 값이고,
	실제로 어느 칸을 덮는지는 `Shape`가 정한다. 둘을 섞으면 "원거리인데 앞 1칸만
	때린다" 같은 조합을 표현할 수 없다. 아군을 향해 쏘는지는 이 값이 아니라
	`Shape.TargetSide`가 정한다 — Supporting이어도 자기 진영을 찍지 않을 수
	있고(예: 아군 전체 버프는 Shape가 필요 없다), 반대로 Melee인데
	`TargetSide = "Ally"`인 것도 있을 수 있다(예: 자해 스킬).
]]
export type SkillRange = "Melee" | "Ranged" | "Supporting"

export type Skill = {
	Id: string,
	Name: string,
	--[[
		한 줄 설명. 스킬 바에 마우스를 올리면 뜬다.

		`config_editor.html`에서 직접 고친다 — 스킬이 무엇을 하는지가 코드에만
		있으면 밸런스를 만지는 사람이 매번 소스를 열어야 한다.
	]]
	Description: string?,
	Damage: number,
	Range: SkillRange,
	Shape: BattleGrid.Shape,
	--[[
		강화 스킬(`upgradeSkills`)만 채운다 — 그 직업 3번 오른쪽에 열리는 스킬임을
		뜻한다. 기본 스킬은 이미 `classSkills[classId]`에 속해 있어 안 채운다.
		편집기가 "직업 능력" 탭에서 어느 직업 자리에 이 강화 스킬을 같이 보여줄지
		이 값 하나로 정한다.
	]]
	ClassId: string?,
	--[[
		**조건부로 범위가 늘어나는 자원.** `ClassResources`의 Id 문자열이다(예:
		음악가 16분음표). 캐스터가 이 자원을 든 개수만큼 `Shape.Stages`가 차례로
		켜진다. `BattleSkills`는 자원 상한·저장소를 모르므로 여기선 이름만
		들고, 실제 개수 세기는 부르는 쪽(`GridBattle`)이 한다 — Radius가 그렇듯
		"얼마나 커지는가"는 스킬 데이터에, "지금 몇인가"는 전투 상태에 둔다.
	]]
	GrowResource: string?,
	-- 자원 몇 개당 한 칸 느는지. 비우면 1개당 한 칸(기본값).
	GrowDivisor: number?,
	--[[
		**모션 단계.** 앞뒤관통처럼 한 번 쓸 때 서로 다른 칸을 순서대로 때리는
		스킬을 위한 것(요청: "모션상 단계... 결투사의 앞뒤관통의 경우에
		써야됨"). `Shape`가 첫 모션이고, 여기 담긴 것들이 그 뒤를 잇는다.

		`Shape.Stages`(조건부 단계)와는 다른 축이다 — 조건부 단계는 자원이
		쌓일수록 **범위가 넓어지는 것**(한 번의 타격)이고, 모션은 **몇 번,
		어디를 차례로 때리는가**(여러 번의 타격)다. 자원 조건과 무관하게 쓸
		때마다 전부 발동하고, **모션마다 `Damage`만큼 따로 입힌다** — 앞뒤관통이
		"9 × 2(합 18)"인 것처럼, `Damage`는 한 모션의 피해량이지 합계가 아니다.
	]]
	Motions: { BattleGrid.Shape }?,
	--[[
		**재사용 대기 턴.** `유저 아이디어(직업).md`에 스킬마다 "재사용 대기
		N턴"으로 이미 적혀 있던 값인데, 옮겨 담을 자리가 없어 빠져 있었다
		(요청: "직업 능력 탭에서 액티브 스킬 쿨타임 쓰는 칸이 없어"). 비우거나
		0이면 매 턴 다시 쓸 수 있다. 실제로 막는 것(캐스터가 지금 몇 턴
		남았는지 세는 것)은 `GridBattle`의 `Unit.Cooldowns`가 한다 — Radius가
		그렇듯 "얼마나 기다리는가"는 스킬 데이터에, "지금 몇 턴 남았는가"는
		전투 상태에 둔다.
	]]
	Cooldown: number?,
}

-- 적 전용. 적은 직업이 없으므로 이 중에서 무작위로 고른다. 지금은 슬라임 공격 둘뿐이다.
local enemySkills: { Skill } = {
	{
		Id = "SlimeTackle",
		Name = "몸통 박치기",
		Description = "통 튀어 올라 온몸으로 들이받는다.",
		Damage = 12,
		Range = "Melee",
		Shape = { Kind = "Line", Radius = 2 },
	},
	{
		Id = "SlimeSpit",
		Name = "산성 침",
		Description = "볼을 부풀렸다가 산성 방울을 멀리 뱉는다.",
		Damage = 9,
		Range = "Ranged",
		Shape = { Kind = "Line", Radius = 3 },
	},
}

--[[
	직업별 스킬 1·2·3. 이름·피해량·범위는 `유저 아이디어(직업).md`를 따른다.
	강화·연계 스킬은 `upgradeSkills`에 따로 있고, 조건이 차면 **3번 오른쪽에 따로**
	버튼이 하나 더 생긴다(3번을 갈아 끼우지 않는다).
]]
local classSkills: { [string]: { Skill } } = {
	Musician = {
		{
			Id = "Veloce",
			Name = "벨로체",
			Description = "직선 3칸 앞으로 멜로디를 연주해 친다. 사용 후 4분음표 2개를 얻는다.",
			Damage = 18,
			Range = "Ranged",
			Shape = { Kind = "Line", Radius = 3 },
		},
		{
			Id = "Brillante",
			Name = "브릴란테",
			Description = "아군 전체에게 음표 수만큼 [브릴란테]를 건다. 사용 후 8분음표 2개를 얻는다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "Crescendo",
			Name = "크레셴도",
			Description = "음표를 쏘아 선율을 일으킨다. 음표가 최대면 전부 태우고 박자표가 1 오른다.",
			Damage = 26,
			Range = "Ranged",
			Shape = { Kind = "Cross", Radius = 1 },
		},
	},
	--[[
		결투사 3번은 md대로 **준비 자세**(피해 없음)다. 그 자세를 잡은 다음 턴에
		연계 스킬이 오른쪽에 열린다.
	]]
	Duelist = {
		--[[
			사양(`유저 아이디어(직업).md` 스킬 1): "피해량: 9 × 2(합 18)" —
			앞으로 찌르고 뒤돌아 다시 찌르는 **두 모션**이다(요청: "모션상
			단계... 결투사의 앞뒤관통의 경우에 써야됨"). `Damage`는 모션 하나의
			몫(9)이지 합계(18)가 아니다 — `Motions`가 있으면 모션마다 따로 입힌다.

			md의 좌표("(n+2,n) 다음 (n-3,n)")는 문자 그대로 옮기지 않았다 — 이
			문서의 다른 단일 대상 근접기들도 실제로는 `(n+1,n)`(적이 실제로
			선 칸)을 가리키는데, 여기만 그대로 옮기면 첫 타가 적이 선 칸을
			완전히 빗나간다(대미지 0인 채로 "적을 처치" 훅이 도는 테스트가 이걸
			잡아냈다). 예전 `Line Radius 2`(적이 선 칸 + 그다음 칸)가 이미
			맞던 범위이므로, 그 두 칸을 그대로 두 모션으로 나눴다 — 자리는
			그대로, 피해만 한 번에서 두 번(9+9)으로 갈린다.
		]]
		{
			Id = "FrontBackPierce",
			Name = "앞뒤관통",
			Description = "앞으로 돌진해 찌르고, 뒤를 돌아보며 다시 찌른다.",
			Damage = 9,
			Range = "Melee",
			Shape = { Kind = "Single", Cells = { { X = 0, Y = 0 } } },
			Motions = {
				{ Kind = "Single", Cells = { { X = 1, Y = 0 } } },
			},
		},
		{
			Id = "TripleThrust",
			Name = "찔러찔러또찔러",
			Description = "중심을 찌르고 빼낸 뒤 그 힘으로 다시 꿰뚫는다. 첫 타가 맞아야 이어진다.",
			Damage = 22,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 3 },
		},
		{
			Id = "DeepBreath",
			Name = "깊은 호흡",
			Description = "호흡을 가다듬고 준비 자세를 잡는다. 다음 턴까지 움직이지 못하지만 패링은 된다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
	},
	Quasar = {
		{
			Id = "Collapse",
			Name = "붕괴",
			Description = "차징하는 동안 적이 매 턴 끌려오고 [중력]이 걸린다. 발동하면 크게 내려친다.",
			Damage = 22,
			Range = "Melee",
			Shape = { Kind = "Square", Radius = 1 },
		},
		{
			Id = "Singularity",
			Name = "특이점",
			Description = "쌓인 [질량]을 전부 태워 내려친다. 소모한 스택에 따라 3단계로 커진다.",
			Damage = 18,
			Range = "Melee",
			Shape = { Kind = "Cross", Radius = 1 },
		},
		{
			Id = "Infall",
			Name = "낙하",
			Description = "짧게 베어 넘긴다. 쓰기만 해도 [질량]을 3 얻는다.",
			Damage = 32,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
	},
	Pulsar = {
		{
			Id = "Magnetosphere",
			Name = "자기권",
			Description = "주위로 [자기장]을 두른다. 맞으면 공격자에게 반사 피해와 [감극]을 준다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "Converge",
			Name = "수렴",
			Description = "오브 셋이 기를 모아 빔으로 쏜다. 한 턴에 세 번까지 이어 쓸 수 있다.",
			Damage = 18,
			Range = "Ranged",
			Shape = { Kind = "Line", Radius = 4 },
		},
		{
			Id = "Flare",
			Name = "섬광",
			Description = "밝은 빛을 터뜨린다. 피해는 없지만 대상의 명중률을 떨어뜨린다.",
			Damage = 0,
			Range = "Ranged",
			Shape = { Kind = "Line", Radius = 3 },
		},
	},
	WallPilgrim = {
		{
			Id = "Nailing",
			Name = "못질",
			Description = "단일 대상을 못으로 찍는다. [광신] 2중첩을 건다.",
			Damage = 26,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "SplitFlock",
			Name = "갈라진 신도",
			Description = "대상과 그 왼쪽 칸을 함께 친다. 각각 [광신] 1중첩을 건다.",
			Damage = 22,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 2 },
		},
		{
			Id = "Chorale",
			Name = "합창",
			Description = "대상이 선 행 전체를 훑는다. 대상에 4중첩, 나머지에 2중첩을 건다.",
			Damage = 18,
			Range = "Ranged",
			Shape = { Kind = "Row" },
		},
	},
	WallMason = {
		{
			Id = "ChiselWork",
			Name = "정 다듬기",
			Description = "단일 대상을 두드린다. 자신이 [벽] 1중첩을 얻는다.",
			Damage = 26,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "BreakBackWall",
			Name = "뒷벽 허물기",
			Description = "대상과 그 뒷열을 함께 친다. [벽] 중첩만큼 피해가 오른다.",
			Damage = 22,
			Range = "Ranged",
			Shape = { Kind = "Line", Radius = 3 },
		},
		{
			Id = "Consecrate",
			Name = "축성",
			Description = "아군 전체에게 [벽] 3중첩을 두른다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
	},
	WallBreaker = {
		{
			Id = "Cleave",
			Name = "쪼개기",
			Description = "단일 대상을 내려찍는다. [허물 벽] 중첩만큼 피해가 오른다.",
			Damage = 22,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "BringDown",
			Name = "무너뜨리기",
			Description = "대상이 선 행 전체를 쓸어버린다.",
			Damage = 18,
			Range = "Melee",
			Shape = { Kind = "Row" },
		},
		{
			Id = "TearDown",
			Name = "허물다",
			Description = "[허물 벽]을 전부 태워 한 대상에게 꽂는다.",
			Damage = 26,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
	},
	Alchemist = {
		{
			Id = "Grind",
			Name = "다지기",
			Description = "소모할 [약재] 수를 골라 다진다. 많이 쓸수록 이득과 대가가 함께 커진다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "Mix",
			Name = "섞기",
			Description = "[원액]을 전부 소모해 [빈 병]에 채운다. 무엇이 나올지는 병마다 따로 정해진다.",
			Damage = 0,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 1 },
		},
		{
			Id = "Throw",
			Name = "던지기",
			Description = "[꽉 찬 병] 하나를 던진다. 병 종류에 따라 독·화상·기름이 걸린다.",
			Damage = 40,
			Range = "Ranged",
			Shape = { Kind = "Line", Radius = 1 },
		},
	},
	--[[
		광전사는 md에 항목이 없다(이전 로스터에서 남은 직업이다).
		`CharacterDefinitions`의 핏빛 분쇄를 축으로 예전 표에서 셋을 골라 맞춰 둔다.
	]]
	Berserker = {
		{
			Id = "BloodCrash",
			Name = "핏빛 분쇄",
			Description = "자기 체력을 태워 내리찍는다. 체력이 곧 화력이다.",
			Damage = 40,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 2 },
		},
		{
			Id = "DoubleSlash",
			Name = "쌍베기",
			Description = "두 번 연달아 베어 넘긴다.",
			Damage = 30,
			Range = "Melee",
			Shape = { Kind = "Line", Radius = 2 },
		},
		{
			Id = "Burst",
			Name = "광역 폭발",
			Description = "주변을 통째로 터뜨린다. 넓지만 약하다.",
			Damage = 18,
			Range = "Melee",
			Shape = { Kind = "Square", Radius = 1 },
		},
	},
}

--[[
	강화·연계 스킬.

	조건이 차면 **3번 스킬 바로 오른쪽에 버튼이 하나 더 생긴다**(요청).
	예전에는 3번을 갈아 끼웠는데, 그러면 원래 3번을 쓸 수 없게 되고 무엇이 바뀐
	건지도 헷갈렸다.
]]
local upgradeSkills: { Skill } = {
	-- 결투사. 준비 자세를 잡은 다음 턴에 열린다.
	{
		Id = "PointBlank",
		Name = "검 끝을 쏘아라",
		Description = "혼신을 다해 찌르고 피가 터지는 선을 남긴다. 사용 후 태세가 바뀐다.",
		Damage = 32,
		Range = "Melee",
		Shape = { Kind = "Row" },
		ClassId = "Duelist",
	},
	--[[
		음악가. 음표 16개 이상에서 열린다.

		사양(`유저 아이디어(직업).md` 스킬 3 강화): 범위는 `(n+3,n) + (n+3,n+1)
		+ (n+3,n-1)`에 "16분음표 3개당 범위가 앞·위·아래로 1칸씩 증가"가 얹힌다.
		앞은 (n+3,n)에서 더 앞으로, 위·아래는 (n+3,n±1)에서 더 위·아래로 —
		원점이 아니라 **그 변에서부터** 자라야 기존 범위에 이어 붙는다.
	]]
	{
		Id = "CrescendoAlForte",
		Name = "크레셴도 알 포르테",
		Description = "모든 음표를 태워 별처럼 폭발하는 선율을 내뿜는다. 16분음표 3개당 범위가 앞·위·아래로 1칸씩 늘어난다.",
		Damage = 34,
		Range = "Ranged",
		Shape = {
			Kind = "Cross",
			Cells = { { X = 3, Y = 0 }, { X = 3, Y = 1 }, { X = 3, Y = -1 } },
			--[[
				단계마다 앞·위·아래로 한 칸씩 더. 16분음표 최대 16개 ÷ 3 = 5단계까지
				가능해서 5단계를 채워 둔다 — 실제 격자(3칸 높이)에서는 위·아래가
				금방 가장자리에 막혀 사실상 앞으로만 자라는 게 보이지만, 값 자체는
				사양대로 다 갖춰 둔다.
			]]
			Stages = {
				{ { X = 4, Y = 0 }, { X = 3, Y = 2 }, { X = 3, Y = -2 } },
				{ { X = 5, Y = 0 }, { X = 3, Y = 3 }, { X = 3, Y = -3 } },
				{ { X = 6, Y = 0 }, { X = 3, Y = 4 }, { X = 3, Y = -4 } },
				{ { X = 7, Y = 0 }, { X = 3, Y = 5 }, { X = 3, Y = -5 } },
				{ { X = 8, Y = 0 }, { X = 3, Y = 6 }, { X = 3, Y = -6 } },
			},
		},
		ClassId = "Musician",
		GrowResource = ClassResources.SIXTEENTH,
		GrowDivisor = 3,
	},
	-- 연금술사. 꽉 찬 병 3개 이상에서 열린다.
	{
		Id = "Poisoning",
		Name = "중독",
		Description = "[꽉 찬 병]을 전부 들이켠다. 종류마다 이득과 대가가 함께 온다.",
		Damage = 40,
		Range = "Ranged",
		Shape = { Kind = "Line", Radius = 1 },
		ClassId = "Alchemist",
	},
	-- 월 브레이커. 자신을 쳐서 허물 벽을 마련하는 수단이라 항상 열려 있다.
	{
		Id = "SelfCarve",
		Name = "제 살 깎기",
		Description = "아군 하나를 대신 쳐서 [허물 벽] 3중첩을 얻는다.",
		Damage = 0,
		Range = "Melee",
		Shape = { Kind = "Line", Radius = 1 },
		ClassId = "WallBreaker",
	},
}

--[[
	모든 직업이 함께 쓰는 스킬 (요청).

	  가드  이번 턴 받는 피해 70% 감소
	  명상  이번 턴 받는 피해 25% 증가, 스테미나 30 즉시 회복

	직업 목록 뒤에 항상 붙으므로 어떤 직업으로도 쓸 수 있다.
]]
local commonSkills: { Skill } = {
	{
		Id = "Guard",
		Name = "가드",
		Description = "이번 턴 받는 피해가 70% 줄어든다.",
		Damage = 0,
		Range = "Melee",
		Shape = { Kind = "Line", Radius = 1 },
	},
	{
		Id = "Meditate",
		Name = "명상",
		Description = "이번 턴 받는 피해가 25% 늘지만 스테미나를 30 즉시 회복한다.",
		Damage = 0,
		Range = "Melee",
		Shape = { Kind = "Line", Radius = 1 },
	},
}
local BattleSkills = {}

-- `Shape`(첫 모션)과 `Motions`(그 뒤를 잇는 모션들)를 순서대로 하나의 목록으로.
function BattleSkills.AllShapes(skill: Skill): { BattleGrid.Shape }
	local shapes = { skill.Shape }
	for _, motion in skill.Motions or {} do
		table.insert(shapes, motion)
	end
	return shapes
end

-- 적이 고르는 스킬 목록.
function BattleSkills.Enemy(): { Skill }
	return enemySkills
end

-- 강화 스킬 목록. 테스트가 대조하는 데 쓴다.
function BattleSkills.Upgrades(): { Skill }
	return upgradeSkills
end

-- 모든 직업이 함께 쓰는 스킬(가드·명상).
function BattleSkills.Common(): { Skill }
	return commonSkills
end

--[[
	직업의 스킬 목록. 모르는 직업이면 적 목록으로 접는다 — 빈 목록을 돌려주면
	스킬 바가 통째로 사라지고 왜 그런지 알기 어렵다.
]]
function BattleSkills.ForClass(classId: any): { Skill }
	return classSkills[tostring(classId)] or enemySkills
end

-- 예전 이름. 적 목록을 가리킨다(시험판 `Battle3DController`가 아직 쓴다).
function BattleSkills.All(): { Skill }
	return enemySkills
end

--[[
	번호로 고른다. 범위를 벗어나면 첫 스킬로 접는다(클라이언트가 보낸 값을 믿지 않는다).

	목록을 인자로 받는다 — 직업마다 목록이 다르므로 "어느 목록의 몇 번인지"를
	같이 넘겨야 서버와 클라이언트가 같은 스킬을 가리킨다.
]]
function BattleSkills.ByIndex(list: { Skill }, index: any): Skill
	local number = tonumber(index)
	if not number then
		return list[1]
	end
	return list[math.clamp(math.floor(number), 1, #list)]
end

function BattleSkills.ById(id: string): Skill?
	for _, list in classSkills do
		for _, skill in list do
			if skill.Id == id then
				return skill
			end
		end
	end
	for _, list in { upgradeSkills, commonSkills, enemySkills } do
		for _, skill in list do
			if skill.Id == id then
				return skill
			end
		end
	end
	return nil
end

-- 사거리 태그를 사람이 읽는 말로. UI가 버튼에 함께 띄운다.
local RANGE_LABELS: { [string]: string } = {
	Melee = "근거리",
	Ranged = "원거리",
	Supporting = "서포팅",
}

function BattleSkills.RangeLabel(skill: Skill): string
	return RANGE_LABELS[skill.Range] or skill.Range
end

--[[
	범위를 사람이 읽는 한 줄로. 스킬 설명 아래에 붙는다.

	`Shape`는 Kind와 Radius 두 값인데, 그 조합이 무엇을 덮는지는 `Targets`를 읽어야
	알 수 있다. 그걸 매번 짐작하게 두지 않으려고 말로 풀어 둔다.
]]
local SHAPE_TEXT: { [string]: string } = {
	Single = "단일 대상",
	Row = "대상이 선 행 전체",
	Column = "대상이 선 열 전체",
	Cross = "십자 %d칸",
	Square = "주변 %d칸 사각",
	Line = "앞으로 %d칸 직선",
	All = "적 전체",
}

function BattleSkills.ShapeText(skill: Skill): string
	local text
	-- 직접 찍은 범위는 이름이 없다. 몇 칸인지만 알려 준다.
	if skill.Shape.Cells then
		text = string.format("지정 %d칸", #skill.Shape.Cells)
	else
		local template = SHAPE_TEXT[skill.Shape.Kind] or skill.Shape.Kind
		text = if template:find("%%d") then string.format(template, skill.Shape.Radius or 1) else template
	end
	-- 앞뒤관통처럼 모션이 여럿이면(요청: "모션상 단계") 몇 번 때리는지도 알려 준다.
	if skill.Motions and #skill.Motions > 0 then
		text ..= string.format(" · %d모션", #skill.Motions + 1)
	end
	return text
end

--[[
	스킬이 실제로 덮는 상대 칸 목록.

	origin은 그 라인에서 처음 걸리는 상대 칸이다(사양: "스킬 시작 범위가 적한테 닿은
	시점에서 시작"). 라인에 아무도 없으면 빈 목록 — 없는 상대 자리를 칠하지 않는다.
	단 Row(라인 관통)는 x를 쓰지 않으므로 상대가 없어도 라인 전체가 그대로 범위다.

	**미리보기와 실제 판정이 이 함수를 함께 쓴다.**

	`shape`는 `skill.Shape` 하나만 받는다 — 스킬 하나가 모션을 여럿 가질 수
	있어서(요청: "모션상 단계"), "이 스킬의 범위"가 아니라 "이 모션 하나의
	범위"를 묻는 함수가 됐다. 스킬 전체를 때리려면 `BattleSkills.AllShapes`로
	모션마다 이 함수를 부른다.

	`growCount`는 자원을 캐스터가 몇 개 들고 있는지다 — 그 값을 세는 것(자원
	상한, 캐스터가 누구인지)은 이 파일이 모를 일이라 부르는 쪽이 넘긴다.
	`shape.Stages`가 없는 모션은 넘겨도 무시된다.

	`casterX`는 캐스터 자신이 선 칸이다. `shape.TargetSide == "Ally"`일
	때만 쓴다 — 아군을 겨누는 스킬은 "상대가 처음 걸리는 칸"이 아니라 **캐스터
	자신의 칸**이 기준점이어야 한다(요청: "아군 진형에 스킬 사용"). 안 넘기면
	1번 칸으로 대충 잡는다 — 미리보기처럼 캐스터를 몰라도 대략은 보여야 하는
	자리에서 쓴다.
]]
function BattleSkills.Cells(
	grid: BattleGrid.Grid,
	attackerSide: BattleGrid.Side,
	lane: number,
	shape: BattleGrid.Shape,
	growCount: number?,
	casterX: number?
): { BattleGrid.Cell }
	if shape.TargetSide == "Ally" then
		return BattleGrid.CellsInShape(grid, attackerSide, casterX or 1, lane, shape, growCount)
	end
	local targetSide = BattleGrid.Opposing(attackerSide)
	if shape.Kind == "Row" then
		return BattleGrid.CellsInShape(grid, targetSide, 1, lane, shape, growCount)
	end
	local anchor = select(1, BattleGrid.FirstOccupiedColumn(grid, targetSide, lane))
	if not anchor then
		return {}
	end
	return BattleGrid.CellsInShape(grid, targetSide, anchor, lane, shape, growCount)
end

--[[
	`skill.GrowResource`를 `rawStack`개 들고 있을 때 몇 칸 자랄지.

	나누는 몫만 여기서 정한다 — 실제 스택 수를 읽는 것(누구의 상태를 볼지)은
	`GridBattle`·클라이언트 미리보기가 각자의 자리에서 한다. 여기 몰아 두는 건
	`GrowDivisor` 나눗셈 규칙이 부르는 쪽마다 따로 적히면 어긋나기 쉬워서다.
]]
function BattleSkills.GrowCount(skill: Skill, rawStack: number): number
	if not skill.GrowResource then
		return 0
	end
	return math.floor(rawStack / (skill.GrowDivisor or 1))
end

-- 위 칸들 중 실제로 유닛이 있는 것. 대미지 대상이다(아군을 겨누면 아군이 대상이다).
-- `shape`도 `Cells`와 같은 이유로 모션 하나만 받는다 — 스킬 전체는 `AllShapes`로 모아 부른다.
function BattleSkills.Targets(
	grid: BattleGrid.Grid,
	attackerSide: BattleGrid.Side,
	lane: number,
	shape: BattleGrid.Shape,
	growCount: number?,
	casterX: number?
): { string }
	local targetSide = if shape.TargetSide == "Ally" then attackerSide else BattleGrid.Opposing(attackerSide)
	local hit: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, cell in BattleSkills.Cells(grid, attackerSide, lane, shape, growCount, casterX) do
		local occupant = BattleGrid.Occupant(grid, targetSide, cell.X, cell.Y)
		if occupant and not seen[occupant] then
			seen[occupant] = true
			table.insert(hit, occupant)
		end
	end
	return hit
end

-- 사거리를 사람이 읽는 문장으로. UI와 로그가 함께 쓴다.
function BattleSkills.RangeText(skill: Skill): string
	local shape = skill.Shape
	if shape.Kind == "Row" then
		return "라인 전체"
	elseif shape.Kind == "Line" then
		return string.format("앞 %d칸", shape.Radius or 1)
	elseif shape.Kind == "Cross" then
		return "십자 범위"
	elseif shape.Kind == "Square" then
		local width = (shape.Radius or 1) * 2 + 1
		return string.format("%d×%d 범위", width, width)
	end
	return "범위"
end

return BattleSkills
