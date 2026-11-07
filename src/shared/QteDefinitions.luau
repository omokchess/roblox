--!strict
--[[
	QteDefinitions — QTE 판정 규칙.

	사양 출처
	  추가&수정.md `##### QTE`
	    "C:\Users\hhksh\Documents\Codex\2026-06-09\...\battleroyale 경로의 게임에서
	     QTE 시스템을 가져올 것."
	  추가&수정.md `###### 전투` — 배율과 그로기는 이쪽 사양을 따른다.

	원본: 그 프로젝트의 `game/sim/Qte.js`를 이식했다.
	  타입 5종(sweep / forge / mash / parry / directional), 진행도 수식, 판정 기준을
	  그대로 옮겼다.

	**배율만 이 게임 사양으로 바꿨다.** 원본은 스킬 실패가 0.6이지만,
	추가&수정.md는 "실패 시 대미지가 1/2이 되고 QTE가 취소된다"고 못박고 있다.

	  스킬 QTE   성공 1.2 / 보통 1.0 / 실패 0.5   ← 실패 0.5가 사양
	  회피 QTE   성공 0.0 / 방어 0.5 / 실패 1.0   ← 사양과 원본이 일치

	설계상 중요한 점
	  VisualState()를 **미리보기와 판정이 함께 쓴다.**
	  화면에 보이는 것과 서버가 매기는 결과가 같은 수식에서 나오므로 어긋날 수 없다.

	난이도 너프 (사용자 요청: "스트라타젬을 가린다던가, 깜빡이며 낚시를 한다던가 등을 삭제")
	  - 시야 방해(DisruptionEnabled)를 **완전히 제거**했다.
	    · 패리 표시가 깜빡이며 낚시하던 것 → 항상 선명하게 보인다
	    · 방향 커맨드(스트라타젬)를 가리던 것 → 항상 다 보인다
	  - 타이밍 창을 넓히고 링·바 속도를 낮췄다. 방향 커맨드도 10 → 5개로 줄였다.
	  '브라운 더스트 1' 톤에 맞춰 QTE를 관대하게 만든다.
]]

export type Grade = "Success" | "Partial" | "Fail"
export type Role = "Skill" | "Dodge"
export type QteType = "Sweep" | "Forge" | "Mash" | "Parry" | "Directional"
export type Direction = "Up" | "Right" | "Down" | "Left"

export type Challenge = {
	Id: string,
	Role: Role,
	Type: QteType,
	Title: string,
	StartedAt: number,
	DurationMs: number,
	InputCount: number,
	-- 상대가 실제 플레이어일 때만 시야 방해(깜빡임·화살표 은폐)를 건다.
	DisruptionEnabled: boolean,

	-- 타입별 파라미터
	ParryHitProgress: number?,
	RingSpeedMultiplier: number?,
	ObscurePhase: number?,
	SweepSpeedMultiplier: number?,
	SweepTargets: { number }?,
	SweepAttempts: number?,
	SweepMisses: number?,
	Goal: number?,
	ExpectedDirections: { Direction }?,
	CommandConcealOffset: number?,
	CommandRevealMs: number?,
	SequenceIndex: number?,
	Mistakes: number?,
	-- 3연타 QTE(2026-11-06 칼리스토 개선안 4절): 화살표 BeatSize 개씩 BeatCount 비트를 이어 입력. 비트별 실수는 BeatMistakes[비트]
	BeatCount: number?,
	BeatSize: number?,
	BeatMistakes: { [number]: number }?,
	-- 반대 방향 비트(화면에 보이는 화살표와 반대로 눌러야 맞다): ReverseBeats[비트] = true
	ReverseBeats: { [number]: boolean }?,
	-- 실수 몇 개를 더 성공으로 봐준다(결투사 간파·집중 최대·연계 — 스냅숏 AllyParryForgive). 성공·막기 기준이 같이 늘어난다
	Forgive: number?,
}

--=== 상수 (원본 Qte.js와 동일) ===--
local DURATION_MS = 3500
local RING_SPEED_MULTIPLIER = 2.0
local SWEEP_SPEED_MIN = 2.0
local SWEEP_SPEED_MAX = 2.8
local SWEEP_ATTEMPTS = 3
local SWEEP_SUCCESS_GAP = 0.12
local PARRY_SUCCESS_GAP = 0.04
local PARRY_GUARD_GAP = 0.10
-- 방향 입력 수(2026-09-29 요청: 8개는 너무 어렵다 → 6)
local COMMAND_COUNT = 6
local COMMAND_REVEAL_MS = 900
local COMMAND_GUARD_MISTAKES = 2
local COMMAND_DODGE_MISTAKES = 1
-- 3연타 QTE: 화살표 5개 × 비트, 제한 시간은 전체 6,000ms(3비트 기준 화살표당 400ms), 비트마다 실수 0 이면 회피 · 1 이면 막기 · 2 이상 실패
-- 2026-11-06 사용자 답("제한 시간을 늘리는 대신 입력을 훨씬 어렵게"): 합계 9,000ms(비트당 3,000) · 비트당 화살표 7 · 비트 2는 반대 방향 입력
local CHAIN_DURATION_MS = 9000
local CHAIN_BEAT_SIZE = 7
local CHAIN_REVERSE_BEAT = 2
local OPPOSITE: { [string]: Direction } = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local CHAIN_DODGE_MISTAKES = 0
local CHAIN_GUARD_MISTAKES = 1

--[[
	배율. 추가&수정.md `###### 전투` 기준.

	스킬: "'이 스킬로 선택' 버튼을 누를 경우 스킬 QTE가 나오게 되며,
	       실패 시 대미지가 1/2이 되고 QTE가 취소된다."
	회피: "실패 시 대미지 그대로 / 방어 시 대미지의 1/2 / 패리·회피 성공 시 대미지를 받지 않는다."
]]
local MULTIPLIERS: { [Role]: { [Grade]: number } } = {
	Skill = { Success = 1.2, Partial = 1.0, Fail = 0.5 },
	Dodge = { Success = 0.0, Partial = 0.5, Fail = 1.0 },
}

-- 패리 성공 시 적에게 쌓이는 그로기 (사양: 15)
local PARRY_GROGGY_GAIN = 15

local SKILL_TYPES: { { Type: QteType, Title: string } } = {
	{ Type = "Sweep", Title = "스윕 바" },
	{ Type = "Forge", Title = "단조 링" },
	{ Type = "Mash", Title = "과열 연타" },
}

local DODGE_TYPES: { { Type: QteType, Title: string } } = {
	{ Type = "Directional", Title = "방향 회피" },
}

local DIRECTIONS: { Direction } = { "Up", "Right", "Down", "Left" }

local QteDefinitions = {}

QteDefinitions.DURATION_MS = DURATION_MS
QteDefinitions.SWEEP_ATTEMPTS = SWEEP_ATTEMPTS
QteDefinitions.COMMAND_COUNT = COMMAND_COUNT
QteDefinitions.COMMAND_GUARD_MISTAKES = COMMAND_GUARD_MISTAKES
QteDefinitions.COMMAND_DODGE_MISTAKES = COMMAND_DODGE_MISTAKES
QteDefinitions.CHAIN_DURATION_MS = CHAIN_DURATION_MS
QteDefinitions.CHAIN_BEAT_SIZE = CHAIN_BEAT_SIZE
QteDefinitions.CHAIN_DODGE_MISTAKES = CHAIN_DODGE_MISTAKES
QteDefinitions.CHAIN_GUARD_MISTAKES = CHAIN_GUARD_MISTAKES
-- 화면이 만들어 둘 화살표 칸 수(일반 6 · 3연타 5 × 3)
QteDefinitions.CHAIN_REVERSE_BEAT = CHAIN_REVERSE_BEAT
QteDefinitions.COMMAND_MAX = CHAIN_BEAT_SIZE * 3
QteDefinitions.PARRY_GROGGY_GAIN = PARRY_GROGGY_GAIN
QteDefinitions.Multipliers = MULTIPLIERS

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

--[[
	QTE를 하나 만든다.

	rng는 0~1을 돌려주는 함수. 시드를 고정하면 재현 가능한 판정이 나오므로
	서버 권위 판정과 리플레이가 어긋나지 않는다.
]]
function QteDefinitions.Create(role: Role, rng: () -> number, now: number, id: string, pvp: boolean): Challenge
	local _ = pvp -- 너프 이후 미사용. 시그니처 호환을 위해 남긴다.
	local registry = if role == "Dodge" then DODGE_TYPES else SKILL_TYPES
	local pick = registry[math.clamp(math.floor(clamp01(rng()) * #registry) + 1, 1, #registry)]

	local challenge: Challenge = {
		Id = id,
		Role = role,
		Type = pick.Type,
		Title = pick.Title,
		StartedAt = now,
		DurationMs = DURATION_MS,
		InputCount = 0,
		DisruptionEnabled = false, -- 너프: 시야 방해 제거 (항상 선명)
	}

	-- 마감 시점이 곧 최적 타이밍이면 안 된다. 링은 서버가 정한 지점에서
	-- 목표에 닿고, 그 뒤로도 계속 줄어들어 실패 구간으로 들어간다.
	if pick.Type == "Parry" then
		challenge.ParryHitProgress = 0.58 + clamp01(rng()) * 0.2
		challenge.ObscurePhase = clamp01(rng())
	end

	if pick.Type == "Sweep" then
		challenge.SweepSpeedMultiplier = SWEEP_SPEED_MIN + clamp01(rng()) * (SWEEP_SPEED_MAX - SWEEP_SPEED_MIN)
		local targets: { number } = {}
		for _ = 1, SWEEP_ATTEMPTS do
			table.insert(targets, 0.18 + clamp01(rng()) * 0.64)
		end
		challenge.SweepTargets = targets
		challenge.SweepAttempts = 0
		challenge.SweepMisses = 0
	end

	if pick.Type == "Forge" or pick.Type == "Parry" then
		challenge.RingSpeedMultiplier = RING_SPEED_MULTIPLIER * (1 + clamp01(rng()) * 0.5)
	end

	if pick.Type == "Mash" then
		challenge.Goal = 7 + math.floor(clamp01(rng()) * 4)
	end

	if pick.Type == "Directional" then
		local expected: { Direction } = {}
		for _ = 1, COMMAND_COUNT do
			table.insert(expected, DIRECTIONS[math.clamp(math.floor(clamp01(rng()) * 4) + 1, 1, 4)])
		end
		challenge.ExpectedDirections = expected
		challenge.CommandConcealOffset = math.floor(clamp01(rng()) * 3)
		challenge.CommandRevealMs = COMMAND_REVEAL_MS
		challenge.SequenceIndex = 0
		challenge.Mistakes = 0
	end

	return challenge
end

--[[
	현재 화면 상태. **UI와 판정이 이 함수를 공유한다.**
	같은 수식에서 나오므로 보이는 것과 결과가 어긋날 수 없다.
]]
function QteDefinitions.VisualState(challenge: Challenge, elapsedMs: number): { [string]: any }
	local progress = clamp01(elapsedMs / math.max(1, challenge.DurationMs))
	local ringSpeed = challenge.RingSpeedMultiplier or RING_SPEED_MULTIPLIER

	if challenge.Type == "Sweep" then
		local sweepSpeed =
			math.clamp(challenge.SweepSpeedMultiplier or SWEEP_SPEED_MIN, SWEEP_SPEED_MIN, SWEEP_SPEED_MAX)
		-- 뒤로 갈수록 빨라져 난이도가 오른다.
		local acceleratedPhase = progress * (1.25 + progress * 1.35) * sweepSpeed
		local cycle = acceleratedPhase % 2
		local attempts = challenge.SweepAttempts or 0
		local attempt = math.clamp(math.floor(attempts), 0, SWEEP_ATTEMPTS - 1)
		local targets = challenge.SweepTargets or {}

		return {
			progress = progress,
			-- 0↔1을 왕복하는 바
			position = if cycle <= 1 then cycle else 2 - cycle,
			targetPosition = math.clamp(targets[attempt + 1] or 0.5, 0.09, 0.91),
			successGap = SWEEP_SUCCESS_GAP,
			attempt = attempt,
			attempts = SWEEP_ATTEMPTS,
			misses = math.max(challenge.SweepMisses or 0, 0),
		}
	end

	if challenge.Type == "Forge" then
		return {
			progress = progress,
			outerRadius = math.max(0, 1 - progress * 0.82 * ringSpeed),
			targetRadius = 0.3,
		}
	end

	if challenge.Type == "Mash" then
		return {
			progress = progress,
			count = math.max(challenge.InputCount, 0),
			goal = challenge.Goal or 8,
		}
	end

	if challenge.Type == "Parry" then
		local hitProgress = math.max(challenge.ParryHitProgress or 0.68, 0.1)
		local obscurePhase = clamp01(challenge.ObscurePhase or 0)
		local visibilityCycle = ((elapsedMs / 260) + obscurePhase) % 1
		local disruption = challenge.DisruptionEnabled

		return {
			progress = progress,
			outerRadius = math.max(0, 1 - progress * (0.8 / hitProgress) * ringSpeed),
			targetRadius = 0.2,
			successGap = PARRY_SUCCESS_GAP,
			partialGap = PARRY_GUARD_GAP,
			-- 표시를 깜빡이게 해 타이밍을 외우지 못하게 한다 (PvP 한정)
			indicatorOpacity = if (not disruption) or progress < 0.06 or visibilityCycle < 0.46 then 1 else 0.06,
		}
	end

	-- Directional
	local directions = challenge.ExpectedDirections or {}
	local sequenceIndex = math.max(challenge.SequenceIndex or 0, 0)
	local revealMs = math.max(challenge.CommandRevealMs or COMMAND_REVEAL_MS, 0)
	local concealOffset = math.max(math.floor(challenge.CommandConcealOffset or 0), 0) % 3
	local disruption = challenge.DisruptionEnabled

	local hidden: { number } = {}
	if disruption and elapsedMs >= revealMs then
		for index = 1, #directions do
			local zeroBased = index - 1
			if zeroBased >= sequenceIndex and (zeroBased + concealOffset) % 3 == 0 then
				table.insert(hidden, index)
			end
		end
	end

	return {
		progress = progress,
		expectedDirections = directions,
		sequenceIndex = sequenceIndex,
		mistakes = math.max(challenge.Mistakes or 0, 0),
		hiddenCommandIndexes = hidden,
		beatCount = challenge.BeatCount,
		beatSize = challenge.BeatSize,
		beatMistakes = challenge.BeatMistakes,
		reverseBeats = challenge.ReverseBeats,
	}
end

local function ringGrade(outerRadius: number, targetRadius: number, successGap: number, partialGap: number): Grade
	local gap = math.abs(outerRadius - targetRadius)
	if gap <= successGap then
		return "Success"
	end
	if gap <= partialGap then
		return "Partial"
	end
	return "Fail"
end

--[[
	판정. 서버가 권위를 갖는다.
	클라이언트가 보낸 시점(elapsedMs)을 그대로 믿지 말고 서버 시계로 검증할 것.
]]
function QteDefinitions.Judge(challenge: Challenge, elapsedMs: number): Grade
	local state = QteDefinitions.VisualState(challenge, elapsedMs)

	if challenge.Type == "Sweep" then
		return if math.abs(state.position - state.targetPosition) <= state.successGap then "Success" else "Fail"
	end

	if challenge.Type == "Forge" then
		return ringGrade(state.outerRadius, state.targetRadius, 0.11, 0.22)
	end

	if challenge.Type == "Parry" then
		return ringGrade(state.outerRadius, state.targetRadius, state.successGap, state.partialGap)
	end

	if challenge.Type == "Mash" then
		local count = math.max(challenge.InputCount, 0)
		local goal = challenge.Goal or 8
		if count == goal or count == goal + 1 then
			return "Success"
		end
		if count >= goal - 2 and count <= goal + 2 then
			return "Partial"
		end
		return "Fail"
	end

	if challenge.Type == "Directional" and challenge.BeatSize then
		local worst: Grade = "Success"
		for _, grade in QteDefinitions.JudgeChain(challenge) do
			if grade == "Fail" or (grade == "Partial" and worst == "Success") then
				worst = grade
			end
		end
		return worst
	end

	if challenge.Type == "Directional" then
		local expected = state.expectedDirections
		-- 끝까지 입력하지 못했으면 실패
		if #expected == 0 or state.sequenceIndex < #expected then
			return "Fail"
		end
		local forgive = math.max(0, challenge.Forgive or 0)
		if state.mistakes <= COMMAND_DODGE_MISTAKES + forgive then
			return "Success"
		end
		if state.mistakes <= COMMAND_GUARD_MISTAKES + forgive then
			return "Partial"
		end
		return "Fail"
	end

	return "Fail"
end

--[[
	3연타 QTE 만들기(2026-11-06 칼리스토 개선안 4절). 방향 입력 한 줄(5 × beats)에 제한 시간 6,000ms.
	서버는 비트마다 ResolveDodge 를 따로 부르고, 등급은 JudgeChain 이 비트별로 낸다.
]]
function QteDefinitions.CreateChain(rng: () -> number, now: number, id: string, beats: number): Challenge
	local expected: { Direction } = {}
	for _ = 1, CHAIN_BEAT_SIZE * beats do
		table.insert(expected, DIRECTIONS[math.clamp(math.floor(clamp01(rng()) * 4) + 1, 1, 4)])
	end
	return {
		Id = id,
		Role = "Dodge",
		Type = "Directional",
		Title = "연타 회피",
		StartedAt = now,
		DurationMs = CHAIN_DURATION_MS,
		InputCount = 0,
		DisruptionEnabled = false,
		ExpectedDirections = expected,
		CommandConcealOffset = 0,
		CommandRevealMs = COMMAND_REVEAL_MS,
		SequenceIndex = 0,
		Mistakes = 0,
		BeatCount = beats,
		BeatSize = CHAIN_BEAT_SIZE,
		BeatMistakes = {},
		ReverseBeats = if beats >= CHAIN_REVERSE_BEAT then { [CHAIN_REVERSE_BEAT] = true } else {},
	}
end

-- 방향 입력 하나를 먹인다(일반·3연타 공통). 맞았는지를 돌려준다
function QteDefinitions.FeedDirection(challenge: Challenge, input: string): boolean
	local expected = challenge.ExpectedDirections or {}
	local index = (challenge.SequenceIndex or 0) + 1
	local want = expected[index]
	if want and challenge.BeatSize and (challenge.ReverseBeats or {})[math.ceil(index / challenge.BeatSize)] then
		want = OPPOSITE[want]
	end
	local ok = want == input
	if not ok then
		challenge.Mistakes = (challenge.Mistakes or 0) + 1
		if challenge.BeatSize then
			local beat = math.ceil(index / challenge.BeatSize)
			local mistakes = challenge.BeatMistakes or {}
			challenge.BeatMistakes = mistakes
			mistakes[beat] = (mistakes[beat] or 0) + 1
		end
	end
	challenge.SequenceIndex = index
	return ok
end

-- 3연타 QTE 의 비트별 등급. 비트를 다 못 채웠으면(시간 끝) 그 비트부터 실패
function QteDefinitions.JudgeChain(challenge: Challenge): { Grade }
	local size = challenge.BeatSize or CHAIN_BEAT_SIZE
	local beats = challenge.BeatCount or 1
	local done = challenge.SequenceIndex or 0
	local grades: { Grade } = {}
	local forgive = math.max(0, challenge.Forgive or 0)
	for beat = 1, beats do
		local mistakes = (challenge.BeatMistakes or {})[beat] or 0
		grades[beat] = if done < beat * size or mistakes > CHAIN_GUARD_MISTAKES + forgive then "Fail"
			elseif mistakes > CHAIN_DODGE_MISTAKES + forgive then "Partial"
			else "Success"
	end
	return grades
end

-- 스윕은 3회 시도의 실수 횟수로 최종 등급을 낸다.
function QteDefinitions.SweepFinalGrade(misses: number): Grade
	local count = math.max(math.floor(misses), 0)
	if count == 0 then
		return "Success"
	end
	if count == 1 then
		return "Partial"
	end
	return "Fail"
end

-- 등급 → 대미지 배율.
function QteDefinitions.Multiplier(role: Role, grade: Grade): number
	return MULTIPLIERS[role][grade]
end

--[[
	이 QTE 결과로 적에게 쌓일 그로기.
	사양: "만약 패리를 할 시 적에게 15의 그로기 게이지가 추가된다."
	→ 패리(Parry) 타입을 성공했을 때만 준다.
]]
function QteDefinitions.GroggyGain(challenge: Challenge, grade: Grade): number
	if challenge.Type == "Parry" and grade == "Success" then
		return PARRY_GROGGY_GAIN
	end
	return 0
end

-- 이 타입에 유효한 입력인지.
function QteDefinitions.IsValidInput(qteType: QteType, input: string): boolean
	if qteType == "Directional" then
		for _, direction in DIRECTIONS do
			if direction == input then
				return true
			end
		end
		return false
	end
	if qteType == "Mash" then
		return input == "Mash" or input == "Tap"
	end
	return input == "Tap"
end

return QteDefinitions
