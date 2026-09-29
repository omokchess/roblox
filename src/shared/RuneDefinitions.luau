--!strict
--[[
	RuneDefinitions — 룬과 수식어(장비 강화).

	사양 출처: 추가&수정.md `### 룬`

	  - 무기 또는 방어구에 수식어를 새길 수 있고, 이는 **대장간에서만** 가능하다.
	  - 원하는 수식어에 맞는 룬을 줘야 그 수식어가 붙는다.
	  - 사용하고 남은 룬은 **돌덩이**가 된다.
	  - **장비 하나엔 최대 한 가지 수식어만** 들어간다. 겹칠 수 없다.
	  - 랜덤 룬은 모든 수식어 중 하나를 무작위로 붙인다.

	수식어 설계 원칙 (사양)
	  장비의 성능을 부각하기 위한 시스템으로, **리스크를 주는 대신 리턴을 준다.**
	  리스크 없이 리턴만 얻는 방식도 있지만, 그 경우 리턴의 양이 적어진다.
]]

export type RuneKind = "Fixed" | "Random"

export type Affix = {
	Id: string,
	Name: string,
	Description: string,
	-- 리스크가 없는 수식어는 그만큼 리턴이 작다.
	HasRisk: boolean,
	-- 배율은 곱연산 기준값이다. 1.0이 변화 없음.
	Modifiers: { [string]: number },
}

export type Rune = {
	Id: string,
	Name: string,
	Kind: RuneKind,
	-- Fixed면 붙일 수식어 Id. Random이면 nil.
	AffixId: string?,
}

-- 룬을 다 쓰고 남는 것 (사양: 돌덩이)
local SPENT_RUNE_ID = "Pebble"
local SPENT_RUNE_NAME = "돌덩이"

local affixes: { Affix } = {
	--=== 리스크 있는 수식어 — 리턴이 크다 ===--
	{
		Id = "Reckless",
		Name = "무모한",
		Description = "대미지 +35%, 받는 대미지 +20%",
		HasRisk = true,
		Modifiers = { Damage = 1.35, DamageTaken = 1.20 },
	},
	{
		Id = "Brittle",
		Name = "메마른",
		Description = "치명타 대미지 +50%, 최대 체력 -15%",
		HasRisk = true,
		Modifiers = { CritDamage = 1.50, MaxHealth = 0.85 },
	},
	{
		Id = "Ravenous",
		Name = "굶주린",
		Description = "가한 대미지의 12%를 회복, 매 턴 스테미나 회복 -30%",
		HasRisk = true,
		Modifiers = { Lifesteal = 0.12, StaminaRegen = 0.70 },
	},
	{
		Id = "Zealous",
		Name = "광신의",
		Description = "기도 대미지 +40%, 기도 패널티 +25%",
		HasRisk = true,
		Modifiers = { PrayerDamage = 1.40, PrayerPenalty = 1.25 },
	},
	{
		Id = "Unstable",
		Name = "불안정한",
		Description = "치명타 확률 +18%, 자동 회피 확률 -50%",
		HasRisk = true,
		Modifiers = { CritChance = 1.18, AutoDodge = 0.50 },
	},
	{
		Id = "Heavy",
		Name = "묵직한",
		Description = "물리 대미지 +28%, 이동속도 -12%",
		HasRisk = true,
		Modifiers = { PhysicalDamage = 1.28, MoveSpeed = 0.88 },
	},

	--=== 리스크 없는 수식어 — 리턴이 작다 ===--
	{
		Id = "Sturdy",
		Name = "단단한",
		Description = "최대 체력 +6%",
		HasRisk = false,
		Modifiers = { MaxHealth = 1.06 },
	},
	{
		Id = "Keen",
		Name = "예리한",
		Description = "대미지 +7%",
		HasRisk = false,
		Modifiers = { Damage = 1.07 },
	},
	{
		Id = "Swift",
		Name = "날랜",
		Description = "패리·회피 타이밍 +5%",
		HasRisk = false,
		Modifiers = { ParryWindow = 1.05, DodgeWindow = 1.05 },
	},
	{
		Id = "Devout",
		Name = "경건한",
		Description = "주는 회복량 +8%",
		HasRisk = false,
		Modifiers = { HealGiven = 1.08 },
	},
	{
		Id = "Fortunate",
		Name = "운좋은",
		Description = "드랍률 +9%",
		HasRisk = false,
		Modifiers = { DropRate = 1.09 },
	},
}

local RuneDefinitions = {}

RuneDefinitions.SPENT_RUNE_ID = SPENT_RUNE_ID
RuneDefinitions.SPENT_RUNE_NAME = SPENT_RUNE_NAME

function RuneDefinitions.AllAffixes(): { Affix }
	return affixes
end

function RuneDefinitions.GetAffix(id: string): Affix?
	for _, affix in affixes do
		if affix.Id == id then
			return affix
		end
	end
	return nil
end

--[[
	룬을 장비에 새길 수 있는지 본다.
	사양: 장비 하나엔 최대 한 가지 수식어. 이미 있으면 겹칠 수 없다.
]]
function RuneDefinitions.CanInscribe(existingAffixId: string?): (boolean, string?)
	if existingAffixId ~= nil then
		return false, "이미 수식어가 새겨져 있습니다. 수식어는 겹칠 수 없습니다."
	end
	return true, nil
end

--[[
	룬이 실제로 붙일 수식어를 정한다.
	  Fixed  → 룬에 새겨진 그 수식어
	  Random → 전체 수식어 중 하나를 무작위로
]]
function RuneDefinitions.ResolveAffix(rune: Rune, seed: number): Affix?
	if rune.Kind == "Fixed" then
		return if rune.AffixId then RuneDefinitions.GetAffix(rune.AffixId) else nil
	end

	local random = Random.new(seed)
	return affixes[random:NextInteger(1, #affixes)]
end

--[[
	대장간에서 룬을 새긴다.

	반환: 성공 여부, 붙은 수식어, 실패 사유
	성공하면 호출부는 룬 아이템을 '돌덩이'로 바꿔야 한다(사양).
]]
function RuneDefinitions.Inscribe(existingAffixId: string?, rune: Rune, seed: number): (boolean, Affix?, string?)
	local allowed, reason = RuneDefinitions.CanInscribe(existingAffixId)
	if not allowed then
		return false, nil, reason
	end

	local affix = RuneDefinitions.ResolveAffix(rune, seed)
	if not affix then
		return false, nil, "룬에서 수식어를 읽을 수 없습니다."
	end

	return true, affix, nil
end

return RuneDefinitions
