--!strict
--[[
	HonorDefinitions — 명예 수치와 거래 가능 등급.

	사양 출처: 추가&수정.md `## 거래 > ### 명예`

	  - 계정 생성 시 기본값 150. **계정 귀속**이라 슬롯을 새로 만들거나
	    사망 후 부활해도 유지된다.
	  - 최대 300.
	  - 값어치가 같거나 더 주는 거래로 올릴 수 있다.
	  - 너무 싼 물건(예: 나뭇가지)을 반복 거래해 올리는 것은 막는다.

	거래 가능 등급 (사양 표 그대로)
	     ~50  커먼
	    ~100  언커먼
	    ~150  레어
	    ~200  에픽
	    ~220  유니크
	    ~260  슈프림
	    ~280  레전더리
	     300  전부
]]

local ItemDefinitions = require(script.Parent.ItemDefinitions)

local DEFAULT_HONOR = 150
local MAX_HONOR = 300
local MIN_HONOR = 0

-- 명예 상한선별 거래 가능 최고 등급. 낮은 순으로 둔다.
local TRADE_TIERS: { { Threshold: number, MaxRarity: ItemDefinitions.Rarity } } = {
	{ Threshold = 50, MaxRarity = "Common" },
	{ Threshold = 100, MaxRarity = "Uncommon" },
	{ Threshold = 150, MaxRarity = "Rare" },
	{ Threshold = 200, MaxRarity = "Epic" },
	{ Threshold = 220, MaxRarity = "Unique" },
	{ Threshold = 260, MaxRarity = "Supreme" },
	{ Threshold = 280, MaxRarity = "Legendary" },
	{ Threshold = 300, MaxRarity = "Abyss" },
}

-- 명예 획득을 인정하는 거래의 최소 가치.
-- 이보다 싼 물건은 반복 거래해도 명예가 오르지 않는다(사양의 나뭇가지 방지).
local MIN_TRADE_VALUE_FOR_HONOR = 50

local HonorDefinitions = {}

HonorDefinitions.DEFAULT_HONOR = DEFAULT_HONOR
HonorDefinitions.MAX_HONOR = MAX_HONOR
HonorDefinitions.MIN_HONOR = MIN_HONOR
HonorDefinitions.MIN_TRADE_VALUE_FOR_HONOR = MIN_TRADE_VALUE_FOR_HONOR
HonorDefinitions.TradeTiers = TRADE_TIERS

function HonorDefinitions.Clamp(honor: number): number
	return math.clamp(honor, MIN_HONOR, MAX_HONOR)
end

-- 이 명예로 거래할 수 있는 최고 등급.
function HonorDefinitions.MaxTradableRarity(honor: number): ItemDefinitions.Rarity
	local clamped = HonorDefinitions.Clamp(honor)
	local result: ItemDefinitions.Rarity = "Common"
	for _, tier in TRADE_TIERS do
		if clamped <= tier.Threshold then
			return tier.MaxRarity
		end
		result = tier.MaxRarity
	end
	return result
end

-- 해당 등급 아이템을 거래할 수 있는지.
function HonorDefinitions.CanTrade(honor: number, rarity: ItemDefinitions.Rarity): boolean
	local allowed = HonorDefinitions.MaxTradableRarity(honor)
	return ItemDefinitions.RarityTier(rarity) <= ItemDefinitions.RarityTier(allowed)
end

--[[
	거래가 명예를 올릴 자격이 있는지 판정한다.

	  givenValue   내가 준 것의 가치
	  receivedValue 내가 받은 것의 가치

	사양: "값어치가 똑같은, 혹은 더 주는 식의 거래"만 인정하고,
	      너무 싼 물건의 반복 거래는 인정하지 않는다.
]]
function HonorDefinitions.QualifiesForHonorGain(givenValue: number, receivedValue: number): boolean
	if givenValue < MIN_TRADE_VALUE_FOR_HONOR then
		return false
	end
	return givenValue >= receivedValue
end

return HonorDefinitions
