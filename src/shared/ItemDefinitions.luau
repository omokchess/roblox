--!strict
--[[
	ItemDefinitions — 아이템 등급 8종과 착용 제한 규칙.

	사양 출처: 추가&수정.md `## 육성 시스템 > ### 아이템`

	핵심 규칙
	  - 탑에서는 **특별(Epic)** 등급까지만 획득. 고유(Unique)부터는 필드 수급.
	  - 각 아이템은 취급 스탯에 대한 제한이 걸린다. (예: 힘 40 이상)
	  - 제한 미달이어도 착용은 가능하되 **그 무기 대미지가 50% 감소**한다.
	  - 제한 판정에는 **메인 스탯만** 쓴다. 아이템이 준 스탯(서브)은 제한 충족으로 치지 않는다.
	  - 스탯 제한은 100을 넘길 수 없다.
	  - 대장간 제작은 통달(Supreme)까지. 전설은 고급 재료 조달 퀘스트 완료 시 해금.
]]

local StatDefinitions = require(script.Parent.StatDefinitions)

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Unique" | "Supreme" | "Legendary" | "Abyss"

export type RarityDefinition = {
	Id: Rarity,
	Name: string,
	Tier: number, -- 1(일반) ~ 8(심연)
	Color: Color3,
	MaxStatRequirement: number, -- 이 등급 아이템이 걸 수 있는 스탯 제한 상한
	TowerObtainable: boolean, -- 탑에서 얻을 수 있는가
	Craftable: boolean, -- 대장간에서 제작 가능한가
	CraftMaterialCount: number, -- 제작 시 필요 재료 수 (등급이 오를수록 증가)
}

export type Item = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	-- 이 아이템이 다루는 스탯. 제한 판정 대상이다.
	PrimaryStat: StatDefinitions.StatId,
	StatRequirement: number,
	BaseDamage: number,
	-- 아이템이 부여하는 스탯. 전부 서브스탯 판정이다.
	StatBonus: { [StatDefinitions.StatId]: number }?,
	-- 새겨진 수식어 룬 (RuneDefinitions.Affix의 Id). 장비당 최대 1개.
	Affix: string?,
}

-- 제한 미달 시 대미지 배율 (50% 감소)
local UNDER_REQUIREMENT_MULTIPLIER = 0.5

-- 스탯 제한 절대 상한
local MAX_STAT_REQUIREMENT = 100

local rarities: { RarityDefinition } = {
	{
		Id = "Common",
		Name = "일반",
		Tier = 1,
		Color = Color3.fromRGB(158, 158, 158), -- 회색
		MaxStatRequirement = 15,
		TowerObtainable = true,
		Craftable = true,
		CraftMaterialCount = 2,
	},
	{
		Id = "Uncommon",
		Name = "응가",
		Tier = 2,
		Color = Color3.fromRGB(140, 200, 90), -- 연두색
		MaxStatRequirement = 28,
		TowerObtainable = true,
		Craftable = true,
		CraftMaterialCount = 4,
	},
	{
		Id = "Rare",
		Name = "희귀",
		Tier = 3,
		Color = Color3.fromRGB(70, 130, 220), -- 파란색
		MaxStatRequirement = 42,
		TowerObtainable = true,
		Craftable = true,
		CraftMaterialCount = 7,
	},
	{
		Id = "Epic",
		Name = "특별",
		Tier = 4,
		Color = Color3.fromRGB(150, 90, 210), -- 보라색
		MaxStatRequirement = 56,
		TowerObtainable = true, -- 탑에서 얻을 수 있는 마지막 등급
		Craftable = true,
		CraftMaterialCount = 11,
	},
	{
		Id = "Unique",
		Name = "고유",
		Tier = 5,
		Color = Color3.fromRGB(200, 60, 60), -- 붉은색
		MaxStatRequirement = 70,
		TowerObtainable = false, -- 여기부터 필드 수급
		Craftable = true,
		CraftMaterialCount = 16,
	},
	{
		Id = "Supreme",
		Name = "통달",
		Tier = 6,
		Color = Color3.fromRGB(230, 140, 50), -- 주황색
		MaxStatRequirement = 82,
		TowerObtainable = false,
		Craftable = true, -- 대장간 제작 상한
		CraftMaterialCount = 22,
	},
	{
		Id = "Legendary",
		Name = "전설",
		Tier = 7,
		Color = Color3.fromRGB(240, 210, 70), -- 노란색
		MaxStatRequirement = 92,
		TowerObtainable = false,
		Craftable = false, -- 고급 재료 조달 퀘스트 완료 시에만 해금
		CraftMaterialCount = 30,
	},
	{
		Id = "Abyss",
		Name = "심연",
		Tier = 8,
		Color = Color3.fromRGB(30, 45, 110), -- 남색
		MaxStatRequirement = 100, -- 상한
		TowerObtainable = false,
		Craftable = false,
		CraftMaterialCount = 40,
	},
}

local ItemDefinitions = {}

ItemDefinitions.MAX_STAT_REQUIREMENT = MAX_STAT_REQUIREMENT
ItemDefinitions.UNDER_REQUIREMENT_MULTIPLIER = UNDER_REQUIREMENT_MULTIPLIER

-- 탑에서 얻을 수 있는 최고 등급 (사양: 특별까지)
ItemDefinitions.TOWER_MAX_RARITY = "Epic" :: Rarity

-- 대장간에서 제작 가능한 최고 등급 (사양: 통달까지)
ItemDefinitions.CRAFT_MAX_RARITY = "Supreme" :: Rarity

function ItemDefinitions.AllRarities(): { RarityDefinition }
	return rarities
end

function ItemDefinitions.GetRarity(id: Rarity): RarityDefinition?
	for _, rarity in rarities do
		if rarity.Id == id then
			return rarity
		end
	end
	return nil
end

function ItemDefinitions.RarityTier(id: Rarity): number
	local rarity = ItemDefinitions.GetRarity(id)
	return rarity and rarity.Tier or 0
end

-- 스탯 제한 값을 등급 상한과 절대 상한(100) 안으로 조인다.
function ItemDefinitions.ClampRequirement(rarityId: Rarity, requirement: number): number
	local rarity = ItemDefinitions.GetRarity(rarityId)
	local cap = rarity and rarity.MaxStatRequirement or MAX_STAT_REQUIREMENT
	return math.clamp(requirement, 0, math.min(cap, MAX_STAT_REQUIREMENT))
end

--[[
	착용 제한을 만족하는지 본다.
	**메인 스탯만** 비교한다 — 아이템이 준 서브스탯으로는 제한을 뚫을 수 없다(사양).
]]
function ItemDefinitions.MeetsRequirement(item: Item, block: StatDefinitions.StatBlock): boolean
	local main = StatDefinitions.MainValue(block, item.PrimaryStat)
	return main >= item.StatRequirement
end

--[[
	제한 반영 후의 실제 무기 대미지.
	미달이면 50% 감소.
]]
function ItemDefinitions.EffectiveDamage(item: Item, block: StatDefinitions.StatBlock): number
	if ItemDefinitions.MeetsRequirement(item, block) then
		return item.BaseDamage
	end
	return item.BaseDamage * UNDER_REQUIREMENT_MULTIPLIER
end

function ItemDefinitions.IsTowerObtainable(rarityId: Rarity): boolean
	local rarity = ItemDefinitions.GetRarity(rarityId)
	return rarity ~= nil and rarity.TowerObtainable
end

--[[
	대장간 제작 가능 여부.
	통달까지는 항상 가능하고, 전설은 고급 재료 조달 퀘스트를 끝냈을 때만 가능하다.
	심연 등급은 제작할 수 없다.
]]
function ItemDefinitions.IsCraftable(rarityId: Rarity, hasAdvancedMaterialQuest: boolean): boolean
	local rarity = ItemDefinitions.GetRarity(rarityId)
	if not rarity then
		return false
	end
	if rarity.Craftable then
		return true
	end
	if rarityId == "Legendary" then
		return hasAdvancedMaterialQuest
	end
	return false
end

--[[
	아이템이 부여하는 스탯을 스탯 블록의 **서브** 칸에 더한다.
	(사양: 아이템으로 얻는 스탯은 서브스탯 판정)
]]
function ItemDefinitions.ApplyBonus(block: StatDefinitions.StatBlock, item: Item): ()
	if not item.StatBonus then
		return
	end
	for statId, amount in item.StatBonus do
		block.Sub[statId] = (block.Sub[statId] or 0) + amount
	end
end

return ItemDefinitions
