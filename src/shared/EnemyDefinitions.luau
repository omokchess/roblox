--!strict

-- 보스 정보 창(BattleHud:ShowBossInfo)에 보이는 부위의 행동 하나. Id 가 있으면 BattleSkills 의 스킬(이름·설명·피해·방어 규칙),
-- 없으면 공격이 아닌 기믹이라 Name·Description 을 여기 적는다. When = 언제 쓰나(턴 박자 — GridBattle 보스 예고와 맞출 것)
export type BossMove = { Id: string?, Name: string?, When: string, Description: string? }

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
	-- 정보 창 맨 위 보스 규칙(글머리 줄)
	Rules: { string }?,
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
		  앞 두 열(x 1~2): 삭제 팔(라인 1) · 중단점 머리(라인 2) · 패치 팔(라인 3)
		  뒤 네 열(x 3~6): 코어 — 앞 부위를 부숴야 그 라인이 코어까지 뚫린다(라인 공격은 처음 만나는 칸부터)
		기믹: 삭제 팔이 아군 칸을 지운다 · 패치 팔이 버프/버그 칸을 깐다(그 칸에 서 있을 때만 효과) ·
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
		Rules = {
			"- [디버그 코어]는 다른 부위를 모두 부수기 전까지 쓰러지지 않음.\n  - 체력 1에서 버팀.",
			"- 코어가 쓰러지면 남은 부위도 함께 무너짐.",
			"- 지속 피해([출혈]·[독]·[화상]) −99%.",
		},
		Parts = {
			{
				Key = "Head",
				Name = "중단점 머리",
				Health = 20000,
				Cells = { { 1, 2 }, { 2, 2 } },
				Moves = { { Id = "BreakpointBeam", When = "매 턴" } },
				Break = "- 디버그가 1턴 멈칫.\n  - 그 턴엔 어느 부위도 예고하지 않음.",
			},
			{
				Key = "DeleteArm",
				Name = "삭제 팔",
				Health = 16000,
				Cells = { { 1, 1 }, { 2, 1 } },
				Moves = { { Id = "DeleteCells", When = "매 턴" } },
				Break = "- [검수됨!] 칸이 모두 돌아옴.\n- 더는 칸을 지우지 않음.",
			},
			{
				Key = "PatchArm",
				Name = "패치 팔",
				Health = 16000,
				Cells = { { 1, 3 }, { 2, 3 } },
				Moves = {
					{
						Name = "패치 적용",
						When = "홀수 턴",
						Description = "- 아군 칸을 새로 칠한다.\n  - 검은 칸에는 깔지 않음.\n- 버프 칸 2\n  - [가하는 피해량] +40%, [받는 피해량] −20%.\n- 회복 칸 1\n  - 턴 끝 최대 체력 15% 회복.\n- 버그 칸 2\n  - [가하는 피해량] −30%, [받는 피해량] +40%.\n- 그 칸에 서 있을 때만 효과.",
					},
					{ Id = "ForcedPatch", When = "짝수 턴" },
				},
				Break = "- 버그 칸이 사라짐.\n- 버프·회복 칸은 그대로 굳음.",
			},
			{
				Key = "Core",
				Name = "디버그 코어",
				Health = 48000,
				Cells = CORE_CELLS,
				Moves = {
					{ Id = "MemoryLeak", When = "홀수 턴" },
					{ Id = "NullPointer", When = "짝수 턴(4의 배수 턴 빼고)" },
					{ Id = "CoreDump", When = "4의 배수 턴" },
				},
				Break = "- 디버그가 무너짐 — 승리.",
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
