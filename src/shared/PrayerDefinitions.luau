--!strict
--[[
	PrayerDefinitions — 이 세계의 '마법'(기도) 규칙과 그 대가.

	사양 출처: 세계관.md `## 이 세계의 마법`

	규칙 6가지
	  1. 마법이 아니라 **기도**다.
	  2. 기도를 이루는 어구는 절대로 줄여선 안 된다.
	  3. 기도는 무(無)에서 유(有)를 창조하지 않는다.
	     (공기가 없는 공간에서 얼음을 만들 수 없다)
	  4. 기도를 쓸 때는 오직 기도의 형태와 어구만을 생각한다.
	  5. 기도로 타인을 공격하는 것은 **금기**이며, 어기면 그 구역의 신이 죄를 묻는다.
	  6. 기도는 절대 기계로 구현할 수 없다.

	성능
	  기도 하나하나가 강력하다. 다만 어구를 외워야 해서 난발할 수 없고,
	  사용 후에는 **반드시** 일시적인 육체적·정신적 대가가 따른다.

	"바란다면, 이루어짐."
]]

export type PenaltyId = "Exhaustion" | "Bleed" | "Daze" | "Stun"

export type PenaltyDefinition = {
	Id: PenaltyId,
	Name: string,
	Description: string,
	DebuffName: string,
}

export type Prayer = {
	Id: string,
	Name: string,
	-- 반드시 완창해야 하는 어구. 줄이면 성립하지 않는다(규칙 2).
	Verse: string,
	-- 어구를 외는 데 걸리는 턴 수. 이것이 난발을 막는다.
	ChantTurns: number,
	BaseDamage: number,
	-- 이 기도가 성립하려면 주변에 있어야 하는 것 (규칙 3).
	-- 예: "Air", "Water", "Earth". 비어 있으면 조건 없음.
	RequiredMedium: { string },
	-- 사용 후 치르는 대가.
	Penalty: PenaltyId,
	-- 타인을 해치는 기도인가. 참이면 금기 판정 대상(규칙 5).
	IsOffensive: boolean,
}

local penalties: { PenaltyDefinition } = {
	{
		Id = "Exhaustion",
		Name = "강한 피로감",
		Description = "몸이 무거워져 행동이 둔해진다.",
		DebuffName = "탈진",
	},
	{
		Id = "Bleed",
		Name = "상당한 출혈",
		Description = "지혈될 때까지 피가 흐른다.",
		DebuffName = "출혈",
	},
	{
		Id = "Daze",
		Name = "정신적 붕괴",
		Description = "무엇을 겨누고 있었는지 흐려진다.",
		DebuffName = "현혹",
	},
	{
		Id = "Stun",
		Name = "극심한 나태",
		Description = "다음 행동을 할 수 없다.",
		DebuffName = "스턴",
	},
}

local PrayerDefinitions = {}

-- 규칙 6: 기계로는 구현할 수 없다. 기계 유닛의 기도 시도를 막는 데 쓴다.
PrayerDefinitions.MACHINE_CAN_PRAY = false

function PrayerDefinitions.AllPenalties(): { PenaltyDefinition }
	return penalties
end

function PrayerDefinitions.GetPenalty(id: PenaltyId): PenaltyDefinition?
	for _, penalty in penalties do
		if penalty.Id == id then
			return penalty
		end
	end
	return nil
end

--[[
	규칙 2 — 어구를 줄였는지 본다.
	외운 어구가 원문과 정확히 같아야 기도가 성립한다.
]]
function PrayerDefinitions.IsVerseComplete(prayer: Prayer, spoken: string): boolean
	return spoken == prayer.Verse
end

--[[
	규칙 3 — 무에서 유를 만들 수 없다.
	기도가 요구하는 매질이 주변에 다 있어야 성립한다.
]]
function PrayerDefinitions.HasRequiredMedium(prayer: Prayer, available: { [string]: boolean }): (boolean, string?)
	for _, medium in prayer.RequiredMedium do
		if not available[medium] then
			return false, medium
		end
	end
	return true, nil
end

--[[
	규칙 5 — 타인을 공격하는 기도는 금기다.
	금기를 저지르면 그 구역의 신이 죄를 묻는다.
	  targetIsPlayer: 대상이 사람인지 (짐승·괴수는 금기가 아니다)
]]
function PrayerDefinitions.IsTaboo(prayer: Prayer, targetIsPlayer: boolean): boolean
	return prayer.IsOffensive and targetIsPlayer
end

--[[
	기도를 시도할 수 있는지 종합 판정한다.

	반환: 성립 여부, 실패 사유
]]
function PrayerDefinitions.CanInvoke(
	prayer: Prayer,
	spoken: string,
	availableMedium: { [string]: boolean },
	isMachine: boolean
): (boolean, string?)
	-- 규칙 6
	if isMachine then
		return false, "기도는 기계로 구현할 수 없습니다."
	end

	-- 규칙 2
	if not PrayerDefinitions.IsVerseComplete(prayer, spoken) then
		return false, "어구를 줄이거나 틀렸습니다. 기도가 성립하지 않습니다."
	end

	-- 규칙 3
	local hasMedium, missing = PrayerDefinitions.HasRequiredMedium(prayer, availableMedium)
	if not hasMedium then
		return false,
			string.format("주변에 %s이(가) 없어 기도가 성립하지 않습니다.", tostring(missing))
	end

	return true, nil
end

--[[
	기도 대미지. 신앙심 스탯의 파생값을 곱한다.
	  prayerDamageBonus: StatDefinitions.Derive(...)의 PrayerDamage (0.8 = +80%)
]]
function PrayerDefinitions.EffectiveDamage(prayer: Prayer, prayerDamageBonus: number): number
	return prayer.BaseDamage * (1 + prayerDamageBonus)
end

--[[
	대가의 강도. 신앙심이 높을수록 줄어든다.
	  penaltyReduction: Derive(...)의 PrayerPenalty (음수. -0.15 = 15% 감소)
	사양상 기도 후에는 **반드시** 대가가 따르므로 0 아래로 내려가지 않게 최소치를 남긴다.
]]
function PrayerDefinitions.PenaltyScale(penaltyReduction: number): number
	return math.max(1 + penaltyReduction, 0.1)
end

return PrayerDefinitions
