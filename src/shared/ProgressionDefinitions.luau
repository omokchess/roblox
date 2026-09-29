--!strict
--[[
	ProgressionDefinitions — 레벨, 체력, 스테미나/신앙심 자원.

	사양 출처: 추가&수정.md `##### 플레이어`, `##### 층별 보상`

	체력
	  1레벨 기본 60. 레벨이 5 오를 때마다 최대 체력 +10. 매 턴 최대 체력의 5% 회복.
	스테미나
	  1레벨 기본 60. 매 턴 8 회복. **레벨이 올라도 회복량은 변하지 않는다.**
	  버프로 회복 효율을 높일 수 있다.
	  마법사 계열은 스테미나 대신 '신앙심'을 자원으로 쓴다(이름만 다르고 수치 규칙은 같다).
	레벨
	  탑에서만 오른다. 층 클리어마다 1레벨, 5층 단위마다 2레벨 추가.
	  1레벨당 스탯 포인트 3개.
]]

local StatDefinitions = require(script.Parent.StatDefinitions)

-- 마법사 계열인지에 따라 자원 이름이 바뀐다.
export type ResourceKind = "Stamina" | "Faith"

local BASE_HEALTH = 60
local HEALTH_PER_5_LEVELS = 10
local HEALTH_REGEN_RATIO = 0.05 -- 매 턴 최대 체력의 5%

local BASE_STAMINA = 60
local STAMINA_REGEN_FLAT = 8 -- 매 턴 8, 레벨 무관

local ProgressionDefinitions = {}

ProgressionDefinitions.BASE_HEALTH = BASE_HEALTH
ProgressionDefinitions.HEALTH_PER_5_LEVELS = HEALTH_PER_5_LEVELS
ProgressionDefinitions.HEALTH_REGEN_RATIO = HEALTH_REGEN_RATIO
ProgressionDefinitions.BASE_STAMINA = BASE_STAMINA
ProgressionDefinitions.STAMINA_REGEN_FLAT = STAMINA_REGEN_FLAT

--[[
	레벨 기준 최대 체력.
	레벨 1 → 60, 레벨 6 → 70, 레벨 11 → 80 …
	스탯(힘 +1/점, 체력 +4/점)은 별도로 더한다. → MaxHealthWithStats 참고.
]]
function ProgressionDefinitions.MaxHealth(level: number): number
	local steps = math.floor((math.max(level, 1) - 1) / 5)
	return BASE_HEALTH + steps * HEALTH_PER_5_LEVELS
end

-- 레벨 + 스탯을 모두 반영한 최대 체력.
function ProgressionDefinitions.MaxHealthWithStats(level: number, block: StatDefinitions.StatBlock): number
	local derived = StatDefinitions.Derive(block)
	return ProgressionDefinitions.MaxHealth(level) + (derived.MaxHealth or 0)
end

-- 매 턴 회복하는 체력량 (최대 체력의 5%).
function ProgressionDefinitions.HealthRegen(maxHealth: number): number
	return maxHealth * HEALTH_REGEN_RATIO
end

-- 최대 스테미나(= 신앙심). 현재 사양엔 레벨 증가분이 없다.
function ProgressionDefinitions.MaxStamina(_level: number): number
	return BASE_STAMINA
end

--[[
	매 턴 회복하는 스테미나량.
	기본 8 고정이며, 버프 효율(0.2 = +20%)만 이 값을 늘린다.
]]
function ProgressionDefinitions.StaminaRegen(buffEfficiency: number?): number
	return STAMINA_REGEN_FLAT * (1 + (buffEfficiency or 0))
end

-- 마법사면 '신앙심', 아니면 '스테미나'.
function ProgressionDefinitions.ResourceKind(isPrayerUser: boolean): ResourceKind
	return if isPrayerUser then "Faith" else "Stamina"
end

function ProgressionDefinitions.ResourceName(kind: ResourceKind): string
	return if kind == "Faith" then "신앙심" else "스테미나"
end

--[[
	층을 clearedFloors개 클리어했을 때의 레벨.
	층마다 1, 5층 단위마다 2 추가. 시작 레벨은 1이다.
	  5층 클리어  → 1 + 5 + 2  = 8
	  10층 클리어 → 1 + 10 + 4 = 15
	  30층 클리어 → 1 + 30 + 12 = 43
]]
function ProgressionDefinitions.LevelForFloors(clearedFloors: number): number
	local floors = math.max(clearedFloors, 0)
	return 1 + floors + math.floor(floors / 5) * 2
end

-- 한 층을 더 클리어했을 때 오르는 레벨 수 (5의 배수 층이면 3).
function ProgressionDefinitions.LevelGainForFloor(floor: number): number
	return 1 + (if floor % 5 == 0 then 2 else 0)
end

-- 해당 레벨까지 모았을 스탯 포인트 총량 (1레벨당 3개).
function ProgressionDefinitions.TotalStatPoints(level: number): number
	return math.max(level - 1, 0) * StatDefinitions.POINTS_PER_LEVEL
end

return ProgressionDefinitions
