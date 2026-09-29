--!strict
--[[
	GroggyGauge — 그로기 게이지.

	사양 출처: 추가&수정.md `###### 전투`

	  "그로기 게이지: 100까지 찰 경우 한 턴 스턴에 빠지며,
	   피격, 패리 등과 같은 여러 요소로 찰 수 있다."
	  "만약 패리를 할 시 적에게 15의 그로기 게이지가 추가된다."

	사양이 명시한 것은 두 가지뿐이다.
	  - 상한 100, 도달 시 **한 턴 스턴**
	  - 패리 성공 시 적에게 **15**

	"피격, 패리 등과 같은 여러 요소"라고 열어 두었으므로,
	원인(Source)별 수치를 표로 빼서 나중에 조정하기 쉽게 했다.
	패리 15만 사양 확정값이고 나머지는 잠정치다 — 아래 표에 표시해 두었다.

	스턴 처리
	  100에 닿으면 Stunned가 되고 한 턴을 쉰다.
	  스턴이 끝나면 게이지를 0으로 되돌린다(계속 스턴에 걸리는 것을 막기 위함).
]]

export type Source = "Parry" | "Hit" | "CriticalHit" | "Counter" | "Skill" | "Break"

export type State = {
	Value: number,
	-- 스턴 상태이며 남은 턴 수. 0이면 정상.
	StunTurns: number,
}

local MAX = 100
local STUN_TURNS = 1

--[[
	원인별 증가량.

	| 원인 | 값 | 근거 |
	|---|---|---|
	| Parry | 15 | **사양 확정** — "패리를 할 시 적에게 15의 그로기 게이지가 추가" |
	| 나머지 | 잠정 | 사양이 "피격, 패리 등과 같은 여러 요소"로만 열어 둔 부분 |
]]
local GAIN: { [Source]: number } = {
	Parry = 15, -- 사양 확정값
	Hit = 4, -- 잠정
	CriticalHit = 8, -- 잠정
	Counter = 10, -- 잠정
	Skill = 6, -- 잠정
	Break = 20, -- 잠정
}

local GroggyGauge = {}

GroggyGauge.MAX = MAX
GroggyGauge.STUN_TURNS = STUN_TURNS
GroggyGauge.Gain = GAIN

function GroggyGauge.New(): State
	return { Value = 0, StunTurns = 0 }
end

function GroggyGauge.IsStunned(state: State): boolean
	return state.StunTurns > 0
end

--[[
	게이지를 채운다.

	반환: 이번 호출로 스턴에 빠졌는지.
	이미 스턴 중이면 더 쌓지 않는다(스턴 중 누적으로 연속 스턴이 되는 것을 막는다).
]]
function GroggyGauge.Add(state: State, amount: number): boolean
	if GroggyGauge.IsStunned(state) then
		return false
	end

	state.Value = math.clamp(state.Value + math.max(amount, 0), 0, MAX)

	if state.Value >= MAX then
		state.StunTurns = STUN_TURNS
		return true
	end
	return false
end

-- 원인으로 채운다. 표에 없는 원인이면 아무 일도 없다.
function GroggyGauge.AddFrom(state: State, source: Source): boolean
	local amount = GAIN[source]
	if not amount then
		return false
	end
	return GroggyGauge.Add(state, amount)
end

--[[
	턴이 끝날 때 부른다.

	스턴이 걸려 있으면 남은 턴을 하나 줄이고,
	다 풀리는 순간 게이지를 0으로 되돌린다.

	반환: 이번 턴에 행동할 수 없는지 (= 스턴이었는지)
]]
function GroggyGauge.TickTurn(state: State): boolean
	if not GroggyGauge.IsStunned(state) then
		return false
	end

	state.StunTurns -= 1
	if state.StunTurns <= 0 then
		state.StunTurns = 0
		-- 스턴을 마쳤으니 게이지를 비운다.
		state.Value = 0
	end
	return true
end

-- UI용 0~1 비율.
function GroggyGauge.Ratio(state: State): number
	return state.Value / MAX
end

return GroggyGauge
