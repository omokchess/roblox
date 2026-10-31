--!strict

-- 보스 정보 창(BattleHud:ShowBossInfo)에 보이는 부위의 행동 하나. Id 가 있으면 BattleSkills 의 스킬(이름·설명·피해·방어 규칙),
-- 없으면 공격이 아닌 기믹이라 Name·Description 을 여기 적는다. When = 언제 쓰나(턴 박자 — GridBattle 보스 예고와 맞출 것)
-- Phase = 이 페이즈부터 쓴다(정보 창이 "N페이즈 해금"으로 보여 준다)
export type BossMove = { Id: string?, Name: string?, When: string, Description: string?, Phase: number? }

-- 보스 부위 하나. 칸 여러 개를 한 유닛이 차지한다(부위파괴 — 부위마다 체력이 따로다)
export type BossPart = {
	Key: string,
	Name: string,
	Health: number,
	-- 적 진영 칸 {x, y}. 첫 칸이 대표 칸(스냅샷 X·Y)
	Cells: { { number } },
	-- 정보 창: 이 부위가 쓰는 것과 부쉈을 때 일어나는 일(GridBattle.bossPartBroken)
	Moves: { BossMove }?,
	Break: string?,
	-- 예고 범위·레이저 색(2026-10-03 사용자: 부위마다 색을 달리해 어디를 때리는지 나눠 보이게)
	Color: Color3?,
}

export type EnemyDefinition = {
	Id: string,
	Name: string,
	MaxHealth: number,
	Power: number,
	Color: Color3,
	MotionId: string,
	Behavior: "Strike" | "Guard" | "Focus" | "Boss",
	-- 있으면 보스다. 이 부위들이 적 진영을 나눠 차지하고, Core 가 쓰러지면 끝난다(GridBattle 보스 규칙)
	Parts: { BossPart }?,
	-- 정보 창 맨 위 보스 규칙(글머리 줄) — 2026-10-03 부터 패시브·기믹으로 나눠 적는다
	Rules: { string }?,
	-- 정보 창 [패시브]·[기믹] 칸: { 이름, 설명 } (2026-10-03 사용자: 액티브 / 패시브 / 기믹으로 나눠 읽기 편하게)
	Passives: { { Name: string, Description: string, Part: string? } }?, -- Part = 부위 키(없으면 보스 전체)
	-- 속성 저항(0~1). 부위 유닛에 그대로 붙는다
	Resist: { [string]: number }?,
	Gimmicks: { { Name: string, Description: string, Part: string? } }?,
	--[[
		사람 모양 적(2026-10-31 칼리스토). 클라이언트가 R6 몸(Combat/<MotionId>.luau)·전용 모션·무기로 그리고, 적 칸을 그대로 보이며
		칸을 옮겨 다닌다. Solo = 편성에 있으면 이것 하나만 세운다(보스).
	]]
	Humanoid: boolean?,
	Solo: boolean?,
	-- 전투 페이지(칼리스토). 페이지마다 이름·체력·무기·행동·패시브. 번호가 빠진 페이지(2)는 사양을 아직 못 받은 것
	Pages: { [number]: { Name: string, Health: number, Weapon: string, Moves: { BossMove }, Passives: { { Name: string, Description: string } }, Gimmick: string? } }?,
	-- 정보 창 [이야기] 칸
	Lore: { { Name: string, Description: string } }?,
}

local CORE_CELLS = {}
for x = 3, 6 do
	for y = 1, 3 do
		table.insert(CORE_CELLS, { x, y })
	end
end

--[[
	적 정의. (2026-09-28 요청: "지금 있는 적들을 모두 없애고 슬라임 하나만 우선 만들어줘")
	예전 도자기 적 9종(척후병·수문장·가마술사 …)은 지웠다. 모양·모션은 클라이언트
	`Combat/Slime.luau`·`Shared/Combat/Motions/Slime.luau`, 공격은 `BattleSkills` 의 적 스킬.
]]
local definitions: { [string]: EnemyDefinition } = {
	Slime = {
		Id = "Slime",
		Name = "슬라임",
		MaxHealth = 44,
		Power = 6,
		Color = Color3.fromRGB(96, 214, 88),
		MotionId = "Slime",
		Behavior = "Strike",
	},
	--[[
		보스 디버그(2026-09-29 요청). 적 진영 18칸을 통째로 차지한 버그 덩어리.
		  앞 두 열(x 1~2): 서브코어-삭제(라인 1) · 중단점 머리(라인 2) · 서브코어-패치(라인 3)
		  뒤 네 열(x 3~6): 코어 — 앞 부위를 부숴야 그 라인이 코어까지 뚫린다(라인 공격은 처음 만나는 칸부터)
		기믹: 서브코어-삭제가 아군 칸을 지운다 · 서브코어-패치가 버프/버그 칸을 깐다(그 칸에 서 있을 때만 효과) ·
		      코어 덤프는 버프 칸만 비켜 간다. 자세한 규칙은 GridBattle 의 보스 절.
	]]
	-- 체력·공격력은 60레벨 최종 장비·카드 기준(한 방 20만까지 나온다 — 2026-09-29 사용자).
	-- 낮은 레벨로 시험할 때는 디버그 패널 적 체력 ×0.001·공격력 ½ 정도(부위 비율은 그대로).
	Debug = {
		Id = "Debug",
		Name = "디버그",
		-- 2026-09-29: 20만 딜은 무기 공격력을 크게 올린 값이었다(사용자) → 부위 합 10만으로 낮춤
		MaxHealth = 100000, -- 부위 합(디버그 패널 표시용)
		Power = 40,
		Color = Color3.fromRGB(190, 60, 255),
		MotionId = "Debug",
		Behavior = "Boss",
		-- 2026-10-04 리워크: 화염 저항 90%(도트 경감 99% 대신)
		Resist = { Fire = 0.9 },
		Passives = {
			-- 2026-10-03 사용자: 부위마다 액티브·패시브·기믹을 따로 보이게 → Part = 그 부위 키(없으면 보스 전체 탭)
			{ Name = "코어 보호", Part = "Core", Description = "- [디버그 코어]는 다른 부위를 모두 부수기 전까지 쓰러지지 않음.\n  - 체력 1에서 버팀.\n- 코어가 쓰러지면 남은 부위도 함께 무너짐." },
			{ Name = "화염 저항", Description = "- 화염 속성 피해 −90%.\n- 지속 피해는 경감 없음." },
			{ Name = "4페이즈", Description = "- 보스 체력 합 75% · 50% · 25% 아래로 내려갈 때마다 다음 페이즈.\n- 페이즈마다 부위 넷 모두 스킬 하나씩 해금.\n- 1페이즈는 정해진 박자, 2페이즈부터 부위마다 쓸 수 있는 스킬 중에 고름.\n  - 같은 부위가 같은 스킬을 두 번 잇달아 쓰지 않음." },
			{ Name = "최적화 (2페이즈)", Description = "- 보스 최대 스테미나 +20 · 스테미나 가득." },
			{ Name = "멀티스레드 (3페이즈)", Description = "- 한 턴에 부위마다 두 번 행동." },
			{ Name = "커널 모드 (4페이즈)", Description = "- 보스 [가하는 피해량] +30% · 스테미나 회복 +15." },
			{ Name = "적응형 패치", Description = "- 같은 스킬을 잇달아 쓰면 그 스킬로 주는 피해 −15%씩.\n  - 최대 −45%. 다른 스킬을 쓰면 풀림." },
			{ Name = "원한", Description = "- 처음 부순 부위에 따라 남은 디버그가 버프를 얻음(영구).\n  - 무엇을 얻는지는 부위 탭 [패시브]에." },
			{ Name = "원한 — 눈먼 분노", Part = "Head", Description = "- 처음 부순 부위가 이 부위면 남은 디버그 [가하는 피해량] +20%(영구)." },
			{ Name = "원한 — 백업 복원", Part = "DeleteArm", Description = "- 처음 부순 부위가 이 부위면 남은 디버그 스테미나 회복 +15(영구)." },
			{ Name = "원한 — 무결성 붕괴", Part = "PatchArm", Description = "- 처음 부순 부위가 이 부위면 남은 디버그 스킬 비용 −25%(영구)." },
		},
		Gimmicks = {
			{ Name = "보스 스테미나", Description = "- 스킬마다 스테미나를 씀. 매 턴 40 회복(최대 100).\n- 모자라면 그 부위는 쉼.\n- 턴 시작에 15 아래면 [과부하]\n  - 그 턴 공격하지 않음(칸 기믹만).\n  - 보스가 받는 피해 +50%.\n- 깎는 법\n  - 회피 성공 −6 · 패리 −10 · [충전] 끊기 −30." },
			{ Name = "충전 — 포맷", Part = "DeleteArm", Description = "- [포맷]은 한 턴 충전한 뒤 터짐.\n- 충전 중인 이 부위에 정해진 피해를 주면 끊김.\n  - 끊으면 이 부위 1턴 멈춤 · 보스 스테미나 −30." },
			{ Name = "충전 — 커널 패닉", Part = "Core", Description = "- [커널 패닉]은 한 턴 충전한 뒤 터짐.\n- 충전 중인 이 부위에 정해진 피해를 주면 끊김.\n  - 끊으면 이 부위 1턴 멈춤 · 보스 스테미나 −30." },
			{ Name = "검수 칸", Part = "DeleteArm", Description = "- 부위가 모두 부서져도 [검수]는 계속됨(이 부위가 부서지면 코어가 이어서).\n- 검은 칸 위 부작용은 부위를 부술 때마다 하나씩 사라짐.\n  - 이 부위 몫: 최대 체력 9% 고정 피해." },
			{ Name = "검수 부작용 — 후유증", Part = "Head", Description = "- 검은 칸 위에 있으면 스테미나 −20 후유증.\n- 이 부위를 부수면 사라짐." },
			{ Name = "검수 부작용 — 취약", Part = "PatchArm", Description = "- 검은 칸 위에 있으면 [받는 피해량] +200%.\n- 이 부위를 부수면 사라짐." },
			{ Name = "회복 불가", Part = "Core", Description = "- [블루스크린]을 맞으면 3턴 동안 어떤 회복도 받지 못함." },
			{ Name = "판 변주", Description = "- 매 턴 하나가 무작위로 바뀜(직전과 다른 것, 체력바에 보임).\n  - 회복 칸 없음 · 버프 칸 넷 · 오래 남는 검은 칸(2턴)\n  - 과열 체질(과부하 기준 30 · 피해 +15%) · 고속 스레드(2페이즈부터 두 번 행동)" },
			{ Name = "연계 — 버그 자국", Part = "Head", Description = "- [중단점 광선]을 쏘면 다음 턴 그 라인에 버그 칸이 생김.\n- 체력바 [연계 예고]에 보임." },
			{ Name = "연계 — 확정 검수", Part = "DeleteArm", Description = "- [강제 종료]를 쓰면 다음 [검수]가 그 3×3을 반드시 지움.\n- 체력바 [연계 예고]에 보임." },
			{ Name = "연계 — 감염", Part = "PatchArm", Description = "- [버그 심기]를 쓰면 다음 턴 코어 공격이 버그 칸까지 번짐.\n- 체력바 [연계 예고]에 보임." },
			{ Name = "마지막 발악", Part = "Core", Description = "- 코어만 남으면 셋 중 하나.\n  - 코어 폭주: 한 턴에 세 번 행동 · 비용 −50%\n  - 블루스크린 연쇄: 재사용 2턴 · 지금 체력 35%\n  - 검수 폭주: 네 칸만 남김 · 검은 칸 2턴" },
		},
		Parts = {
			{
				Key = "Head",
				Name = "중단점 머리",
				Health = 20000,
				Cells = { { 1, 2 }, { 2, 2 } },
				Color = Color3.fromRGB(255, 70, 70),
				Moves = {
					{ Id = "BreakpointBeam", When = "1페이즈 매 턴" },
					{ Id = "StackTrace", When = "2페이즈 해금", Phase = 2 },
					{ Id = "Watchpoint", When = "3페이즈 해금 · 버프", Phase = 3 },
					{ Id = "BreakStorm", When = "4페이즈 해금", Phase = 4 },
				},
				Break = "- 디버그가 1턴 멈칫.\n  - 그 턴엔 어느 부위도 예고하지 않음.\n- 검은 칸 부작용 [스테미나 −20 후유증]이 사라짐.",
			},
			{
				Key = "DeleteArm",
				Name = "서브코어-삭제",
				Health = 16000,
				Cells = { { 1, 1 }, { 2, 1 } },
				Color = Color3.fromRGB(255, 80, 210),
				Moves = {
					{ Id = "DeleteCells", When = "매 턴 · 기믹" },
					{ Id = "ForceQuit", When = "2페이즈 해금", Phase = 2 },
					{ Id = "Sudo", When = "3페이즈 해금 · 버프", Phase = 3 },
					{ Id = "Format", When = "4페이즈 해금 · 충전", Phase = 4 },
				},
				Break = "- [검수]는 코어가 이어서 함(칸은 계속 지워짐).\n- 검은 칸 부작용 [최대 체력 9% 고정 피해]가 사라짐.",
			},
			{
				Key = "PatchArm",
				Name = "서브코어-패치",
				Health = 16000,
				Cells = { { 1, 3 }, { 2, 3 } },
				Color = Color3.fromRGB(70, 235, 110),
				Moves = {
					{
						Name = "패치 적용",
						When = "홀수 턴 · 기믹",
						Description = "- 아군 칸을 새로 칠함.\n  - 검은 칸에는 깔지 않음.\n- 버프 칸 2\n  - [가하는 피해량] +40%, [받는 피해량] −20%.\n- 회복 칸 1\n  - 턴 끝 최대 체력 30% 회복(회복 불가 중에도 15%).\n- 버그 칸 2\n  - [가하는 피해량] −30%, [받는 피해량] +40%.\n- 그 칸에 서 있을 때만 효과.",
					},
					{ Id = "ForcedPatch", When = "1페이즈 짝수 턴" },
					{ Id = "Hotfix", When = "2페이즈 해금 · 버프", Phase = 2 },
					{ Id = "BugPlant", When = "3페이즈 해금", Phase = 3 },
					{ Id = "DependencyHell", When = "4페이즈 해금 · 버프", Phase = 4 },
				},
				Break = "- 버그 칸이 사라짐.\n- 버프·회복 칸은 그대로 굳음.\n- 검은 칸 부작용 [받는 피해량 +200%]가 사라짐.",
			},
			{
				Key = "Core",
				Name = "디버그 코어",
				Health = 48000,
				Cells = CORE_CELLS,
				Color = Color3.fromRGB(150, 110, 255),
				Moves = {
					{ Id = "MemoryLeak", When = "1페이즈 홀수 턴" },
					{ Id = "NullPointer", When = "1페이즈 짝수 턴" },
					{ Id = "CoreDump", When = "1페이즈 4의 배수 턴" },
					{ Id = "BlueScreen", When = "궁극기 · 3턴째부터" },
					{ Id = "Overclock", When = "2페이즈 해금 · 버프", Phase = 2 },
					{ Id = "KernelPanic", When = "3페이즈 해금 · 충전", Phase = 3 },
					{ Id = "InfiniteRecursion", When = "4페이즈 해금", Phase = 4 },
				},
				Break = "- 디버그가 무너짐 — 승리.",
			},
		},
	},
	--[[
		히든 보스 칼리스토(2026-10-31 사용자 사양 — 밸런스는 사용자도 모른다고 해 사양 숫자 그대로).
		큰곰자리 · 천문학자 · 시인. 사람 모양이라 칸을 옮겨 다니고 적 칸이 보인다.
		규칙은 GridBattle "보스: 칼리스토" 절, 스킬은 BattleSkills 의 Callisto* 스킬.
		페이지 2 는 사양을 아직 못 받아 1페이지 체력이 다하면 바로 3페이지로 넘어간다.
		공격력 0: 스킬 피해 = 사양 숫자(디버그 패널 적 공격력 배율만 곱한다).
	]]
	Callisto = {
		Id = "Callisto",
		Name = "칼리스토",
		MaxHealth = 50000,
		Power = 0,
		Color = Color3.fromRGB(150, 175, 255),
		MotionId = "Callisto",
		Behavior = "Boss",
		Humanoid = true,
		Solo = true,
		Lore = {
			{ Name = "컨셉", Description = "큰곰자리 · 천문학자 · 시인." },
			{ Name = "이야기", Description = "슈네라이히의 천문학자였고 기물군의 비숍이었다.\n아들 아르카스가 반란을 주동했다는 누명을 쓰고 화형당하는 것을 보았다.\n그 충격으로 기물군을 나와, 아들의 별자리를 만들어 주려고 천문대에 틀어박혔다." },
			{ Name = "조우", Description = "- 성위 3개를 얻으면 천문대 입구가 열림.\n- 천문대 안에서 칼리스토와 대화한 뒤 선택지로 전투.\n- 성위를 조사하러 천문대에 들어간 길이다." },
		},
		Passives = {
			{ Name = "그날의 기억", Description = "- 모든 페이지 공통.\n- 칼리스토는 [화상] 피해를 두 배로 받음." },
		},
		Gimmicks = {
			{ Name = "성위 → 뭇별", Description = "- [성위]가 15스택이 되면 [성위]가 사라지고 [뭇별]을 얻음(5턴).\n- [뭇별]: 방어력 −20% · 공격력 −10%." },
			{ Name = "칸 이동", Description = "- 사람 모양이라 매 턴 적 칸을 옮겨 다님.\n- 줄 공격을 할 땐 아군이 선 줄로 옮겨 섬." },
			{ Name = "페이지", Description = "- 1페이지 체력이 다하면 다음 페이지로(쓰러지지 않음).\n- 2페이지는 아직 사양이 없어 3페이지로 바로 넘어감." },
		},
		Pages = {
			[1] = {
				Name = "관찰자 칼리스토",
				Health = 50000,
				Weapon = "의체 — 손에서 칼날이 나오고 손목에서 카메라가 나옴",
				Passives = {
					{ Name = "뭇별의 시선", Description = "- 대상에게 [뭇별]이 있으면 칼리스토가 주는 피해 +15%." },
					{ Name = "아들을 위한 자리", Description = "- 체력 50% 미만이면 자신에게 [작은 곰 자리]." },
				},
				-- 행동 박자(사양에 없어 정함): 1번 → 2번 → 3번 자리를 차례로, [작은 곰 자리]면 바퀴 끝에 강화 스킬
				Moves = {
					{ Id = "CallistoPhoto", When = "1번 자리 · 홀수 바퀴" },
					{ Id = "CallistoSlash", When = "1번 자리 · 짝수 바퀴" },
					{ Id = "CallistoSymberasma", When = "2번 자리 · 대상에게 [고찰]이 있으면" },
					{ Id = "CallistoTrohia", When = "2번 자리 · [고찰]이 없으면" },
					{ Id = "CallistoArktos", When = "3번 자리 · [뭇별]이 있거나 [성위] 6 이상" },
					{ Id = "CallistoSynthesis", When = "3번 자리 · 그 밖" },
					{ Id = "CallistoAstro", When = "[작은 곰 자리] · 바퀴 끝(4번 자리)" },
				},
			},
			[3] = {
				Name = "뭇별의 어머니 칼리스토",
				Health = 300000,
				Weapon = "의체(2페이지와 같음 — 2페이지 사양을 받으면 맞출 것)",
				Gimmick = "10턴 동안 광역 장판 피해 버티기",
				Passives = {
					{ Name = "잊혀져가는 성위", Description = "- `뭇별 아래에 잠기리`로 받는 피해를 자기 최대 체력의 10%씩 고정으로 받음." },
					{ Name = "시험 종료", Description = "- 칼리스토 체력이 1% 이하가 되면 전투 종료(승리)." },
				},
				Moves = {
					{ Id = "CallistoSubmerge", When = "3페이지 첫 턴 바로 · 한 번만" },
					{ Id = "CallistoArtificial", When = "재사용 대기가 끝나면 먼저(4턴)" },
					{ Id = "CallistoShower", When = "그다음(2턴)" },
					{ Id = "CallistoResonance", When = "평타 · 둘 다 대기 중이면" },
				},
			},
		},
	},
}

local EnemyDefinitions = {}

function EnemyDefinitions.Get(id: string): EnemyDefinition
	return definitions[id] or definitions.Slime
end

-- 전부(이름순). 디버그 패널의 적 편성 목록이 쓴다.
function EnemyDefinitions.All(): { EnemyDefinition }
	local list = {}
	for _, definition in definitions do
		table.insert(list, definition)
	end
	table.sort(list, function(x, y)
		return x.Id < y.Id
	end)
	return list
end

function EnemyDefinitions.IsValid(id: string): boolean
	return definitions[id] ~= nil
end

function EnemyDefinitions.FirstEncounter(): { string }
	return { "Slime" }
end

-- 탑 보스 층은 아직 슬라임이 나온다(층 배율로만 세진다). 디버그는 디버그 패널 편성으로 부른다.
function EnemyDefinitions.Boss(): EnemyDefinition
	return definitions.Slime
end

return EnemyDefinitions
