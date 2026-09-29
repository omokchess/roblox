--!strict
--[[
	TowerRewardDefinitions — 탑 층별 보상의 코스트와 리롤 규칙.

	사양 출처: 추가&수정.md `##### 층별 보상`, `#### 탑 시스템`

	코스트
	  층 클리어마다 30개 획득.
	리롤
	  횟수 제한 없음. 첫 리롤 10코스트, 이후 **50%씩 증가**한다.
	    10 → 15 → 22.5 → 33.75 …
	  실제 차감은 반올림한 값을 쓴다.
	  **층을 이동하면 가격이 초기화**된다.

	탑 진입 제약(사양 `#### 탑 시스템`)
	  - 솔로 플레이 전용. 원정대 시스템은 폐기.
	  - 레벨업은 오직 탑에서만 가능.
	  - 무기: 직업에 맞는 기본 무기가 자동 장착.
	  - 방어구: 전부 벗음.
	  - 스탯: 직업 베이스 스탯만 남기고 초기화.
	  - 직업 선택 / 모션 / 종족을 뺀 나머지 외부 요소는 전부 제한.
	  - 나가거나 클리어하면 아이템은 돌려받고, 스탯은 완주 시점에 반영.
]]

local COST_PER_FLOOR = 30
local REROLL_BASE_COST = 10
local REROLL_GROWTH = 1.5

local MAX_FLOOR = 30

-- 무료 프리셋 수와 추가 구매가(로벅스)
local FREE_PRESETS = 3
local EXTRA_PRESET_ROBUX = 100

local TowerRewardDefinitions = {}

TowerRewardDefinitions.COST_PER_FLOOR = COST_PER_FLOOR
TowerRewardDefinitions.REROLL_BASE_COST = REROLL_BASE_COST
TowerRewardDefinitions.REROLL_GROWTH = REROLL_GROWTH
TowerRewardDefinitions.MAX_FLOOR = MAX_FLOOR
TowerRewardDefinitions.FREE_PRESETS = FREE_PRESETS
TowerRewardDefinitions.EXTRA_PRESET_ROBUX = EXTRA_PRESET_ROBUX

--[[
	rerollCount번 리롤한 뒤, 다음 리롤의 **원가**(반올림 전).
	  0회 → 10
	  1회 → 15
	  2회 → 22.5
	  3회 → 33.75
]]
function TowerRewardDefinitions.RawRerollCost(rerollCount: number): number
	return REROLL_BASE_COST * REROLL_GROWTH ^ math.max(rerollCount, 0)
end

-- 실제로 차감할 리롤 비용 (반올림).
function TowerRewardDefinitions.RerollCost(rerollCount: number): number
	return math.round(TowerRewardDefinitions.RawRerollCost(rerollCount))
end

function TowerRewardDefinitions.CanReroll(cost: number, rerollCount: number): boolean
	return cost >= TowerRewardDefinitions.RerollCost(rerollCount)
end

--[[
	층 이동 시 리롤 카운터를 초기화한다(사양).
	층 진입 처리에서 이 값을 그대로 대입하면 된다.
]]
function TowerRewardDefinitions.ResetRerollCount(): number
	return 0
end

-- 프리셋 슬롯을 하나 더 살 때 드는 로벅스. 무료분 안이면 0.
function TowerRewardDefinitions.PresetSlotPrice(ownedSlots: number): number
	if ownedSlots < FREE_PRESETS then
		return 0
	end
	return EXTRA_PRESET_ROBUX
end

function TowerRewardDefinitions.IsFinalFloor(floor: number): boolean
	return floor >= MAX_FLOOR
end

return TowerRewardDefinitions
