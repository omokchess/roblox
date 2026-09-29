--!strict
--[[
	StatDefinitions — 육성 시스템의 스탯 6종과 그 파생 수치.

	사양 출처: 추가&수정.md `## 육성 시스템 > ### 스탯`

	스탯은 두 종류로 나뉜다.
	  메인 스탯 : 레벨업 포인트로 직접 올린 값. **아이템 착용 제한 판정에 쓰인다.**
	  서브 스탯 : 아이템·버프로 얻은 값. 능력치에는 반영되지만 **착용 제한에는 쓰이지 않는다.**

	표기 규칙(사양): [메인(+서브) = 최종]   예) [근력: 49(+23) = 72]
	→ StatDefinitions.Format 참고.
]]

export type StatId = "Strength" | "Intellect" | "Agility" | "Vitality" | "Luck" | "Faith"

-- 메인/서브를 분리해 담는 스탯 블록.
export type StatBlock = {
	Main: { [StatId]: number },
	Sub: { [StatId]: number },
}

export type StatDefinition = {
	Id: StatId,
	Name: string,
	Description: string,
}

-- 스탯 1점당 증가치. 전부 사양 표의 숫자를 그대로 옮긴 것이다.
-- 비율 값은 소수(0.05 = 5%)로 저장한다.
local PER_POINT = {
	Strength = {
		PhysicalDamage = 0.05, -- 물리 대미지 +5%
		MaxHealth = 1, -- 체력 +1
	},
	Intellect = {
		RangedDamage = 0.07, -- 원거리 대미지 +7%
		DropRate = 0.02, -- 드랍률 +2%
	},
	Agility = {
		PhysicalDamage = 0.03, -- 물리 대미지 +3%
		ParryWindow = 0.03, -- 회피 시간 +3%
		DodgeWindow = 0.03, -- 회피 타이밍 +3%
		MoveSpeed = 0.01, -- 이동속도 (사양에 수치 없음 → 1%로 잠정)
		BuffTaken = 0.03, -- 받는 버프 효율 +3%
	},
	Vitality = {
		MaxHealth = 4, -- 체력 +4
		ParryWindow = 0.01, -- 회피 시간 +1%
		HealTaken = 0.01, -- 받는 회복량 +1%
	},
	Luck = {
		CritChance = 0.007, -- 치명타 확률 +0.7%
		CritDamage = 0.012, -- 치명타 대미지 +1.2%
		DropRate = 0.04, -- 드랍률 +4%
		AutoDodge = 0.0005, -- 자동 회피 확률 +0.05%
	},
	Faith = {
		PrayerDamage = 0.08, -- 기도 대미지 +8%
		PrayerPenalty = -0.005, -- 기도 패널티 -0.5%
		DropRate = 0.02, -- 드랍률 +2%
		HealGiven = 0.01, -- 주는 회복량 +1%
		HealTaken = 0.002, -- 받는 회복량 +0.2%
		BuffGiven = 0.03, -- 주는 버프 효율 +3%
		BuffTaken = 0.01, -- 받는 버프 효율 +1%
	},
}

local definitions: { StatDefinition } = {
	{
		Id = "Strength",
		Name = "힘",
		Description = "물리 대미지 5%, 체력 1",
	},
	{
		Id = "Intellect",
		Name = "지력",
		Description = "원거리 대미지 7%, 드랍률 2%",
	},
	{
		Id = "Agility",
		Name = "민첩",
		Description = "물리 대미지 3%, 패리·회피 타이밍 3%, 이동속도, 받는 버프 효율 3%",
	},
	{
		Id = "Vitality",
		Name = "체력",
		Description = "체력 4, 패리 타이밍 1%, 받는 회복량 1%",
	},
	{
		Id = "Luck",
		Name = "운",
		Description = "치명타 확률 0.7%, 치명타 대미지 1.2%, 드랍률 4%, 자동 회피 0.05%",
	},
	{
		Id = "Faith",
		Name = "신앙심",
		Description = "기도 대미지 8%, 기도 패널티 -0.5%, 드랍률 2%, 회복·버프 효율",
	},
}

local ORDER: { StatId } = { "Strength", "Intellect", "Agility", "Vitality", "Luck", "Faith" }

local StatDefinitions = {}

StatDefinitions.Order = ORDER
StatDefinitions.PerPoint = PER_POINT

-- 레벨업으로 얻는 스탯 포인트: 1레벨당 3개 (사양)
StatDefinitions.POINTS_PER_LEVEL = 3

function StatDefinitions.All(): { StatDefinition }
	return definitions
end

function StatDefinitions.Get(id: StatId): StatDefinition?
	for _, definition in definitions do
		if definition.Id == id then
			return definition
		end
	end
	return nil
end

-- 빈 스탯 블록을 만든다.
function StatDefinitions.NewBlock(): StatBlock
	local main: { [StatId]: number } = {}
	local sub: { [StatId]: number } = {}
	for _, id in ORDER do
		main[id] = 0
		sub[id] = 0
	end
	return { Main = main, Sub = sub }
end

-- 착용 제한 판정용. **메인 스탯만** 본다(사양: 서브스탯은 제한에 영향 없음).
function StatDefinitions.MainValue(block: StatBlock, id: StatId): number
	return block.Main[id] or 0
end

-- 실제 능력치 계산용. 메인 + 서브.
function StatDefinitions.TotalValue(block: StatBlock, id: StatId): number
	return (block.Main[id] or 0) + (block.Sub[id] or 0)
end

--[[
	사양 표기 규칙대로 문자열을 만든다.
	  [근력: 49(+23) = 72]
	서브가 0이면 괄호를 생략한다.
]]
function StatDefinitions.Format(block: StatBlock, id: StatId): string
	local definition = StatDefinitions.Get(id)
	local name = definition and definition.Name or id
	local main = block.Main[id] or 0
	local sub = block.Sub[id] or 0

	if sub == 0 then
		return string.format("[%s: %d]", name, main)
	end
	return string.format("[%s: %d(+%d) = %d]", name, main, sub, main + sub)
end

--[[
	스탯 블록에서 파생 수치를 모두 계산한다.
	반환값의 비율 항목은 "증가분"이다. (0.35 = +35%)
]]
function StatDefinitions.Derive(block: StatBlock): { [string]: number }
	local derived: { [string]: number } = {}

	for _, id in ORDER do
		local points = StatDefinitions.TotalValue(block, id)
		if points ~= 0 then
			for key, perPoint in PER_POINT[id] do
				derived[key] = (derived[key] or 0) + perPoint * points
			end
		end
	end

	return derived
end

return StatDefinitions
