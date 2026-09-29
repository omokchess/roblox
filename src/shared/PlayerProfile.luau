--!strict
--[[
	PlayerProfile — 저장 데이터 스키마(v3)와 기본값·마이그레이션.

	사양 출처: 추가&수정.md 전반

	기존 v2는 모션 팩만 담고 있었다(Packs / Equipped / SelectedCharacterId / HighestFloor).
	여기에 육성·아이템·명예·탑 진행을 얹으면서 **저장 단위를 셋으로 나눴다.**

	  Account  계정 단위 — 슬롯을 새로 만들거나 죽어도 유지된다.
	           명예, 모션 팩, 모션 장착, 프리셋 슬롯 수, 최고 도달 층.
	           └ 사양 근거: "명예는 계정에 귀속되므로, 슬롯을 새로 만들거나
	                        사망 후 부활 해도 유지됨"

	  Slots    캐릭터(프리셋) 단위 — 스탯, 레벨, 아이템, 선행/악행 수치.
	           └ 사양 근거: "무료로 주어지는 프리셋은 최대 3개"

	  TowerRun 탑 등반 중에만 존재하는 일시 상태 — 능력 카드, 코스트, 리롤 횟수.
	           └ 사양 근거: "스탯은 탑을 모두 오른 시점에 변한다"
	                        → 등반 중 성장은 확정 전까지 여기 머문다.

	이 모듈은 순수 데이터라 서버·클라이언트 양쪽에서 같은 타입을 본다.
]]

local StatDefinitions = require(script.Parent.StatDefinitions)
local ItemDefinitions = require(script.Parent.ItemDefinitions)
local HonorDefinitions = require(script.Parent.HonorDefinitions)
local TowerRewardDefinitions = require(script.Parent.TowerRewardDefinitions)

local PROFILE_VERSION = 3

export type OwnedItem = {
	Id: string,
	Name: string,
	Rarity: ItemDefinitions.Rarity,
	PrimaryStat: StatDefinitions.StatId,
	StatRequirement: number,
	BaseDamage: number,
	StatBonus: { [string]: number }?,
	-- 새겨진 수식어. 장비당 최대 1개(사양).
	Affix: string?,
}

-- 탑 등반 중에만 유지되는 카드 진행도.
export type CardProgress = {
	CardId: string,
	Grade: string,
	Level: number,
}

export type TowerRun = {
	Active: boolean,
	Floor: number,
	Cost: number,
	-- 층을 옮기면 0으로 초기화된다(사양).
	RerollCount: number,
	Cards: { CardProgress },
	-- 등반 중 오른 레벨. 완주/이탈 시 슬롯에 확정 반영한다.
	PendingLevel: number,
	-- 입장 시 벗어둔 장비. 나가거나 클리어하면 돌려준다(사양).
	StoredItems: { OwnedItem },
	--[[
		이번 층에서 이미 고른 카드 수.

		사양: "층을 클리어 할 때마다 능력 카드중 한개를 얻을 수 있다.
		       5층 단위로 획득 가능한 능력 카드가 1개씩 증가한다."
		→ 층마다 몇 장까지인지는 AcquireSlotsForFloor가 정하고, 여기서 몇 장 썼는지를 센다.
		층을 옮길 때 0으로 되돌린다.
	]]
	AcquiredThisFloor: number,
	--[[
		등반 도중 이미 지급한 스탯 포인트 수.

		사양은 "스탯은 탑을 모두 오른 시점에 변한다"지만, 요청대로 **층마다 스탯을
		찍을 수 있어야** 등반 중의 선택이 된다. 그래서 포인트는 층 클리어 때 바로 주고,
		완주 확정 시 이미 준 만큼을 빼서 같은 포인트를 두 번 주지 않는다.
	]]
	GrantedPoints: number,
}

export type Slot = {
	Name: string,
	ClassId: string,
	RaceId: string,
	Level: number,
	Stats: StatDefinitions.StatBlock,
	-- 아직 쓰지 않은 스탯 포인트.
	UnspentPoints: number,
	Items: { OwnedItem },
	Gold: number,
	-- 사망 시 갈 차원을 정하는 값(세계관.md).
	GoodDeeds: number,
	EvilDeeds: number,
}

export type Account = {
	-- 계정 귀속. 기본 150, 최대 300.
	Honor: number,
	-- 구매로 늘어나는 프리셋 슬롯 수. 무료 3.
	PresetSlots: number,
	HighestFloor: number,
	-- v2에서 이어받는 모션 데이터.
	Packs: { [string]: any },
	Equipped: { [string]: string },
	SelectedCharacterId: string,
}

export type Profile = {
	Version: number,
	Account: Account,
	Slots: { Slot },
	ActiveSlot: number,
	TowerRun: TowerRun?,
}

local PlayerProfile = {}

PlayerProfile.VERSION = PROFILE_VERSION

--=== 기본값 ===--

function PlayerProfile.NewTowerRun(): TowerRun
	return {
		Active = false,
		Floor = 0,
		Cost = 0,
		RerollCount = 0,
		Cards = {},
		PendingLevel = 0,
		StoredItems = {},
		AcquiredThisFloor = 0,
		GrantedPoints = 0,
	}
end

function PlayerProfile.NewSlot(name: string, classId: string, raceId: string): Slot
	return {
		Name = name,
		ClassId = classId,
		RaceId = raceId,
		Level = 1,
		Stats = StatDefinitions.NewBlock(),
		UnspentPoints = 0,
		Items = {},
		Gold = 0,
		GoodDeeds = 0,
		EvilDeeds = 0,
	}
end

function PlayerProfile.New(): Profile
	return {
		Version = PROFILE_VERSION,
		Account = {
			Honor = HonorDefinitions.DEFAULT_HONOR,
			PresetSlots = TowerRewardDefinitions.FREE_PRESETS,
			HighestFloor = 0,
			Packs = {},
			Equipped = {},
			SelectedCharacterId = "Berserker",
		},
		Slots = { PlayerProfile.NewSlot("1번 프리셋", "Berserker", "Human") },
		ActiveSlot = 1,
		TowerRun = nil,
	}
end

--=== 마이그레이션 ===--

--[[
	v2(모션 전용) → v3.
	모션 데이터는 계정 쪽으로 옮기고, 육성 데이터는 기본값으로 시작한다.
	이미 v3면 손대지 않는다.
]]
function PlayerProfile.Migrate(raw: any): Profile
	if type(raw) ~= "table" then
		return PlayerProfile.New()
	end

	if raw.Version == PROFILE_VERSION and raw.Account and raw.Slots then
		return PlayerProfile.Sanitize(raw)
	end

	-- v2 형태를 흡수한다.
	local profile = PlayerProfile.New()
	profile.Account.Packs = if type(raw.Packs) == "table" then raw.Packs else {}
	profile.Account.Equipped = if type(raw.Equipped) == "table" then raw.Equipped else {}
	profile.Account.SelectedCharacterId = if type(raw.SelectedCharacterId) == "string"
		then raw.SelectedCharacterId
		else "Berserker"
	profile.Account.HighestFloor = if type(raw.HighestFloor) == "number" then raw.HighestFloor else 0

	return profile
end

--=== 검증 ===--

local function sanitizeStatBlock(raw: any): StatDefinitions.StatBlock
	local block = StatDefinitions.NewBlock()
	if type(raw) ~= "table" then
		return block
	end
	for _, id in StatDefinitions.Order do
		if type(raw.Main) == "table" and type(raw.Main[id]) == "number" then
			block.Main[id] = math.max(math.floor(raw.Main[id]), 0)
		end
		if type(raw.Sub) == "table" and type(raw.Sub[id]) == "number" then
			block.Sub[id] = math.max(math.floor(raw.Sub[id]), 0)
		end
	end
	return block
end

--[[
	저장본을 신뢰하지 않고 값 범위를 강제한다.
	DataStore가 오래된 값이나 조작된 값을 돌려줄 수 있기 때문이다.
]]
function PlayerProfile.Sanitize(raw: any): Profile
	local profile = PlayerProfile.New()

	if type(raw) ~= "table" then
		return profile
	end

	local account = if type(raw.Account) == "table" then raw.Account else {}

	profile.Account.Honor = HonorDefinitions.Clamp(
		if type(account.Honor) == "number" then account.Honor else HonorDefinitions.DEFAULT_HONOR
	)
	profile.Account.PresetSlots = math.max(
		if type(account.PresetSlots) == "number" then math.floor(account.PresetSlots) else 0,
		TowerRewardDefinitions.FREE_PRESETS
	)
	profile.Account.HighestFloor = math.clamp(
		if type(account.HighestFloor) == "number" then math.floor(account.HighestFloor) else 0,
		0,
		TowerRewardDefinitions.MAX_FLOOR
	)
	profile.Account.Packs = if type(account.Packs) == "table" then account.Packs else {}
	profile.Account.Equipped = if type(account.Equipped) == "table" then account.Equipped else {}
	profile.Account.SelectedCharacterId = if type(account.SelectedCharacterId) == "string"
		then account.SelectedCharacterId
		else "Berserker"

	-- 슬롯
	local slots: { Slot } = {}
	if type(raw.Slots) == "table" then
		for _, rawSlot in raw.Slots do
			if type(rawSlot) == "table" then
				local slot = PlayerProfile.NewSlot(
					if type(rawSlot.Name) == "string" then rawSlot.Name else "프리셋",
					if type(rawSlot.ClassId) == "string" then rawSlot.ClassId else "Berserker",
					if type(rawSlot.RaceId) == "string" then rawSlot.RaceId else "Human"
				)
				slot.Level = math.max(if type(rawSlot.Level) == "number" then math.floor(rawSlot.Level) else 1, 1)
				slot.Stats = sanitizeStatBlock(rawSlot.Stats)
				slot.UnspentPoints = math.max(
					if type(rawSlot.UnspentPoints) == "number" then math.floor(rawSlot.UnspentPoints) else 0,
					0
				)
				slot.Gold = math.max(if type(rawSlot.Gold) == "number" then math.floor(rawSlot.Gold) else 0, 0)
				slot.GoodDeeds =
					math.max(if type(rawSlot.GoodDeeds) == "number" then math.floor(rawSlot.GoodDeeds) else 0, 0)
				slot.EvilDeeds =
					math.max(if type(rawSlot.EvilDeeds) == "number" then math.floor(rawSlot.EvilDeeds) else 0, 0)
				slot.Items = if type(rawSlot.Items) == "table" then rawSlot.Items else {}
				table.insert(slots, slot)
			end
		end
	end

	if #slots == 0 then
		slots = { PlayerProfile.NewSlot("1번 프리셋", "Berserker", "Human") }
	end
	profile.Slots = slots
	profile.ActiveSlot =
		math.clamp(if type(raw.ActiveSlot) == "number" then math.floor(raw.ActiveSlot) else 1, 1, #slots)

	-- 탑 진행은 활성일 때만 이어받는다.
	if type(raw.TowerRun) == "table" and raw.TowerRun.Active == true then
		local run = PlayerProfile.NewTowerRun()
		run.Active = true
		run.Floor = math.clamp(
			if type(raw.TowerRun.Floor) == "number" then math.floor(raw.TowerRun.Floor) else 0,
			0,
			TowerRewardDefinitions.MAX_FLOOR
		)
		run.Cost = math.max(if type(raw.TowerRun.Cost) == "number" then math.floor(raw.TowerRun.Cost) else 0, 0)
		run.RerollCount =
			math.max(if type(raw.TowerRun.RerollCount) == "number" then math.floor(raw.TowerRun.RerollCount) else 0, 0)
		run.PendingLevel = math.max(
			if type(raw.TowerRun.PendingLevel) == "number" then math.floor(raw.TowerRun.PendingLevel) else 0,
			0
		)
		run.Cards = if type(raw.TowerRun.Cards) == "table" then raw.TowerRun.Cards else {}
		run.StoredItems = if type(raw.TowerRun.StoredItems) == "table" then raw.TowerRun.StoredItems else {}
		run.GrantedPoints = math.max(
			if type(raw.TowerRun.GrantedPoints) == "number" then math.floor(raw.TowerRun.GrantedPoints) else 0,
			0
		)
		run.AcquiredThisFloor = math.max(
			if type(raw.TowerRun.AcquiredThisFloor) == "number" then math.floor(raw.TowerRun.AcquiredThisFloor) else 0,
			0
		)
		profile.TowerRun = run
	end

	return profile
end

--=== 조회 도우미 ===--

function PlayerProfile.ActiveSlot(profile: Profile): Slot
	return profile.Slots[profile.ActiveSlot] or profile.Slots[1]
end

-- 프리셋을 하나 더 만들 수 있는지. 무료 3개를 넘으면 구매가 필요하다.
function PlayerProfile.CanAddSlot(profile: Profile): (boolean, number)
	local owned = #profile.Slots
	if owned < profile.Account.PresetSlots then
		return true, 0
	end
	return false, TowerRewardDefinitions.EXTRA_PRESET_ROBUX
end

return PlayerProfile
