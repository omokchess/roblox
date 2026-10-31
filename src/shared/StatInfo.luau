--!strict
--[[
	StatInfo — 스탯 하나의 **효과**와 그 스탯의 **영향을 받는 직업**(2026-10-31 사용자: "스탯 위에 마우스를 올리면 효과와
	영향 받는 직업도 보이게"). 디버그 패널 성장 탭·레벨업 화면의 스탯 줄 툴팁(client/StatTooltip)이 쓴다.

	효과: 점당 수치는 StatDefinitions.PerPoint 그대로. Live = 지금 격자 전투에 실제로 들어가는가(GridBattle·BattleService 를 보고 적음 —
	  들어가는 곳: 근접 스킬 피해(힘 5% · 민첩 3%) · 원거리 스킬 피해(지력 7%) · 최대 체력(힘 1 · 체력 4) · 회피 시간(민첩 3% · 체력 1%,
	  AllyParryWindow) · 치명타(운 0.7% · 1.2%) · 전투 시작 신앙심(신앙심 = ally.Faith). 나머지(드랍률·이동속도·받는 버프 효율 …)는 아직 설명뿐.
	  새로 이으면 여기 Live 를 고칠 것.
	직업: 스킬 데이터(BattleSkills — 피해 있는 스킬의 사거리)와 글(스킬·패시브·카드에 "신앙심")에서 센다 — 직업·카드가 바뀌어도 따라간다.
	  근접(Ranged 가 아닌) 피해 스킬 → 힘·민첩 / 원거리 → 지력 / 모두 → 체력·운 / 신앙심을 쓰는 글 → 신앙심.
	  조율자는 신앙심 말고는 피해를 올릴 수 없다(GridBattle faithOnly — 패시브 알카이드) → 힘·민첩·지력의 피해 몫에서 뺀다.
]]

local AbilityCardDefinitions = require(script.Parent.AbilityCardDefinitions)
local AbilityCards = require(script.Parent.AbilityCards)
local BattleSkills = require(script.Parent.BattleSkills)
local CharacterDefinitions = require(script.Parent.CharacterDefinitions)
local ClassPassives = require(script.Parent.ClassPassives)
local StatDefinitions = require(script.Parent.StatDefinitions)

local StatInfo = {}

export type Effect = { Label: string, Value: string, Total: string, Live: boolean }
export type ClassEntry = { ClassId: string, Name: string, Why: string }

-- 스탯 → 효과 순서(점당 수치 키 · 이름 · 전투 반영 여부). Key 가 없으면 아래 SPECIAL
local EFFECTS: { [string]: { { Key: string, Label: string, Live: boolean } } } = {
	Strength = {
		{ Key = "PhysicalDamage", Label = "근접 스킬 피해", Live = true },
		{ Key = "MaxHealth", Label = "최대 체력", Live = true },
	},
	Intellect = {
		{ Key = "RangedDamage", Label = "원거리 스킬 피해", Live = true },
		{ Key = "DropRate", Label = "드랍률", Live = false },
	},
	Agility = {
		{ Key = "PhysicalDamage", Label = "근접 스킬 피해", Live = true },
		{ Key = "ParryWindow", Label = "회피 시간(QTE 입력 시간)", Live = true },
		{ Key = "DodgeWindow", Label = "회피 타이밍", Live = false },
		{ Key = "MoveSpeed", Label = "이동속도", Live = false },
		{ Key = "BuffTaken", Label = "받는 버프 효율", Live = false },
	},
	Vitality = {
		{ Key = "MaxHealth", Label = "최대 체력", Live = true },
		{ Key = "ParryWindow", Label = "회피 시간(QTE 입력 시간)", Live = true },
		{ Key = "HealTaken", Label = "받는 회복량", Live = false },
	},
	Luck = {
		{ Key = "CritChance", Label = "치명타 확률", Live = true },
		{ Key = "CritDamage", Label = "치명타 피해", Live = true },
		{ Key = "DropRate", Label = "드랍률", Live = false },
		{ Key = "AutoDodge", Label = "자동 회피 확률", Live = false },
	},
	Faith = {
		{ Key = "", Label = "전투 시작 신앙심", Live = true },
		{ Key = "PrayerDamage", Label = "기도 피해", Live = false },
		{ Key = "PrayerPenalty", Label = "기도 패널티", Live = false },
		{ Key = "DropRate", Label = "드랍률", Live = false },
		{ Key = "HealGiven", Label = "주는 회복량", Live = false },
		{ Key = "HealTaken", Label = "받는 회복량", Live = false },
		{ Key = "BuffGiven", Label = "주는 버프 효율", Live = false },
		{ Key = "BuffTaken", Label = "받는 버프 효율", Live = false },
	},
}

-- 비율이 아닌(그대로 더하는) 값
local FLAT: { [string]: boolean } = { MaxHealth = true }
-- 신앙심 말고는 피해를 올릴 수 없는 직업(GridBattle faithOnly — 조율자 패시브 알카이드의 FaithOnlyDamage)
local FAITH_ONLY: { [string]: boolean } = { Attuner = true }

local function number(n: number): string
	local text = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return text
end

local function show(key: string, value: number): string
	if FLAT[key] or key == "" then
		return (if value >= 0 then "+" else "−") .. number(math.abs(value))
	end
	return (if value >= 0 then "+" else "−") .. number(math.abs(value) * 100) .. "%"
end

-- 효과 목록. points = 지금 스탯 점수(합계 칸)
function StatInfo.Effects(statId: string, points: number?): { Effect }
	local out: { Effect } = {}
	local per = (StatDefinitions.PerPoint :: any)[statId] or {}
	for _, e in EFFECTS[statId] or {} do
		local value = if e.Key == "" then 1 else per[e.Key]
		if value then
			table.insert(out, { Label = e.Label, Value = show(e.Key, value), Total = show(e.Key, value * (points or 0)), Live = e.Live })
		end
	end
	return out
end

local registered = false
local function textOf(classId: string): string
	if not registered then
		registered = true
		AbilityCards.Register()
	end
	local parts = {}
	for _, skill in BattleSkills.ForClass(classId) do
		table.insert(parts, skill.Description or "")
	end
	local kit = ClassPassives.Get(classId)
	for _, passive in (kit and kit.Passives) or {} do
		table.insert(parts, passive.Description)
	end
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
			table.insert(parts, card.Description)
		end
	end
	return table.concat(parts, "\n")
end

-- 직업마다 피해 있는 스킬(직업 스킬 + 강화 + [집중력] 변형)의 근접·원거리 수
local function damageSkills(classId: string): (number, number)
	local melee, ranged = 0, 0
	local function count(skill: any)
		if (skill.Damage or 0) > 0 then
			if skill.Range == "Ranged" then
				ranged += 1
			else
				melee += 1
			end
		end
	end
	for _, skill in BattleSkills.ForClass(classId) do
		count(skill)
	end
	for _, list in { BattleSkills.Upgrades(), BattleSkills.Focus() } do
		for _, skill in list do
			if skill.ClassId == classId then
				count(skill)
			end
		end
	end
	return melee, ranged
end

-- 이 스탯의 영향을 받는 직업과 그 까닭(직업 순서는 CharacterDefinitions.All)
function StatInfo.Classes(statId: string): { ClassEntry }
	local out: { ClassEntry } = {}
	for _, def in CharacterDefinitions.All() do
		local melee, ranged = damageSkills(def.Id)
		local faithOnly = FAITH_ONLY[def.Id] == true
		local why: string? = nil
		if statId == "Strength" or statId == "Agility" then
			if melee > 0 and not faithOnly then
				why = string.format("근접 피해 스킬 %d개", melee)
			end
		elseif statId == "Intellect" then
			if ranged > 0 and not faithOnly then
				why = string.format("원거리 피해 스킬 %d개", ranged)
			end
		elseif statId == "Faith" then
			if faithOnly then
				why = "신앙심만 피해를 올림(1점당 +2%)"
			else
				local _, n = textOf(def.Id):gsub("신앙심", "")
				if n > 0 then
					why = string.format("신앙심을 쓰는 스킬·패시브·카드 %d곳", n)
				end
			end
		end
		if why then
			table.insert(out, { ClassId = def.Id, Name = def.Name, Why = why })
		end
	end
	return out
end

-- 모든 직업에 똑같이 들어가는 몫(직업 목록 대신 한 줄로 보인다)
function StatInfo.Everyone(statId: string): string?
	if statId == "Strength" then
		return "최대 체력은 모든 직업"
	elseif statId == "Agility" then
		return "회피 시간은 모든 직업"
	elseif statId == "Vitality" then
		return "모든 직업 — 최대 체력 · 회피 시간"
	elseif statId == "Luck" then
		return "모든 직업 — 치명타(조율자도)"
	end
	return nil
end

-- 피해 몫에서 빠지는 직업(조율자: 신앙심 말고는 피해를 못 올림)
function StatInfo.Excluded(statId: string): { string }
	local out = {}
	if statId == "Strength" or statId == "Agility" or statId == "Intellect" then
		for _, def in CharacterDefinitions.All() do
			if FAITH_ONLY[def.Id] then
				table.insert(out, def.Name)
			end
		end
	end
	return out
end

return StatInfo
