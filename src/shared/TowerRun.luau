--!strict
--[[
	TowerRun — 탑 등반의 **생명주기**.

	사양 출처: 추가&수정.md `#### 탑 시스템`, `##### 프리셋`, `##### 층별 보상`

	이미 있던 조각들
	  TowerDefinitions        30개 층의 적·배율·기믹
	  TowerRewardDefinitions  코스트 30/층, 리롤 10→15→23…, 프리셋 슬롯 값
	  AbilityCardDefinitions  카드 풀과 뽑기 규칙
	  CardDraft               뽑기 → 리롤 → 획득 흐름
	  PlayerProfile.TowerRun  등반 중 상태 그릇

	빠져 있던 것이 **그 조각들을 순서대로 굴리는 층**이라 여기서 맡는다.

	  입장  Start()      제약을 걸고 등반 상태를 연다
	  진행  ClearFloor() 층을 하나 올리고 보상을 제시한다
	  선택  Reroll() / Acquire()
	  종료  Exit() / Complete()

	전투에 의존하지 않는 **순수 로직**이다. 실제 전투 결과(이겼는가)는 호출하는 쪽이
	판단하고, 여기서는 "층을 클리어했다"는 사실만 받아 상태를 굴린다. 덕분에
	Studio 없이 PrototypeTests로 전부 검증된다.
]]

local AbilityCardDefinitions = require(script.Parent.AbilityCardDefinitions)
local CardDraft = require(script.Parent.CardDraft)
local CharacterDefinitions = require(script.Parent.CharacterDefinitions)
local PlayerProfile = require(script.Parent.PlayerProfile)
local StatDefinitions = require(script.Parent.StatDefinitions)
local TowerDefinitions = require(script.Parent.TowerDefinitions)
local TowerRewardDefinitions = require(script.Parent.TowerRewardDefinitions)

export type RunSummary = {
	ReturnedItems: number,
	GainedLevels: number,
	Floor: number,
	Completed: boolean,
}

local TowerRun = {}

--[[
	직업에 맞는 기본 무기.

	사양: "무기 — 선택한 직업에 맞는 기본 무기를 자동으로 장착하게 됨."
	직업 정의의 BasicPower를 그대로 공격력으로 쓴다. 요구 스탯 0·Common 등급이라
	초기화된 베이스 스탯으로도 반드시 들 수 있다(들지 못하면 입장 자체가 막힌다).
]]
function TowerRun.BasicWeaponFor(classId: string): PlayerProfile.OwnedItem
	local class = CharacterDefinitions.Get(classId)
	return {
		Id = string.format("TowerBasic_%s", class.Id),
		Name = string.format("%s 기본 무기", class.Name),
		Rarity = "Common" :: any,
		PrimaryStat = "Strength" :: any,
		StatRequirement = 0,
		BaseDamage = class.BasicPower,
		StatBonus = nil,
		Affix = nil,
	}
end

--[[
	등반을 시작한다.

	사양의 입장 제약을 여기서 한 번에 건다.
	  방어구 "모두 벗음"      → 슬롯의 장비를 통째로 StoredItems로 옮긴다
	  무기 자동 장착          → 직업 기본 무기만 남긴다
	  스탯 "베이스만, 초기화" → 스탯 블록과 미사용 포인트를 비우고 레벨 1로
	  레벨업은 탑에서만       → 등반 중 오른 레벨은 PendingLevel에만 쌓인다

	되돌리기 위한 값(장비)은 전부 run에 보관하므로, 도중에 나가도 잃지 않는다.
]]
function TowerRun.Start(profile: PlayerProfile.Profile): (boolean, string?)
	if profile.TowerRun and profile.TowerRun.Active then
		return false, "이미 등반 중입니다."
	end

	local slot = PlayerProfile.ActiveSlot(profile)
	if not CharacterDefinitions.IsValid(slot.ClassId) then
		return false, "직업이 올바르지 않습니다."
	end

	local run = PlayerProfile.NewTowerRun()
	run.Active = true
	run.Floor = 0

	-- 장비를 통째로 맡아 둔다. 나가거나 클리어하면 CardDraft.FinishRun이 돌려준다.
	for _, item in slot.Items do
		table.insert(run.StoredItems, item)
	end

	slot.Items = { TowerRun.BasicWeaponFor(slot.ClassId) }
	slot.Stats = StatDefinitions.NewBlock()
	slot.UnspentPoints = 0
	slot.Level = 1

	profile.TowerRun = run
	return true, nil
end

-- 지금 도전 중인(=다음에 오를) 층. 시작 직후면 1층.
function TowerRun.NextFloor(run: PlayerProfile.TowerRun): number
	return math.min(run.Floor + 1, TowerRewardDefinitions.MAX_FLOOR)
end

-- 다음 층의 구성(적·배율·기믹). 전투를 붙일 때 이 값을 쓴다.
function TowerRun.NextFloorDefinition(run: PlayerProfile.TowerRun): TowerDefinitions.FloorDefinition
	return TowerDefinitions.Get(TowerRun.NextFloor(run))
end

--[[
	층을 하나 클리어했다. 보상 화면으로 넘어간다.

	실제로 이겼는지는 호출하는 쪽(전투)이 판단한다. 여기서는 상태만 굴린다.
	  - 코스트 +30, 리롤 가격 초기화, 레벨 적립 → CardDraft.BeginFloor
	  - 이번 층 카드 획득 수를 0으로 되돌린다
]]
function TowerRun.ClearFloor(profile: PlayerProfile.Profile, seed: number): CardDraft.DraftResult
	local run = profile.TowerRun
	if not run or not run.Active then
		return {
			Ok = false,
			Reason = "등반 중이 아닙니다.",
			Cards = {},
			Cost = 0,
			NextRerollCost = TowerRewardDefinitions.RerollCost(0),
		}
	end

	local slot = PlayerProfile.ActiveSlot(profile)
	run.AcquiredThisFloor = 0
	return CardDraft.BeginFloor(run, slot.ClassId, TowerRun.NextFloor(run), seed)
end

-- 보상을 다시 뽑는다. 가격과 코스트 판정은 CardDraft가 맡는다.
function TowerRun.Reroll(profile: PlayerProfile.Profile, seed: number): CardDraft.DraftResult
	local run = profile.TowerRun
	if not run or not run.Active then
		return {
			Ok = false,
			Reason = "등반 중이 아닙니다.",
			Cards = {},
			Cost = 0,
			NextRerollCost = TowerRewardDefinitions.RerollCost(0),
		}
	end
	local slot = PlayerProfile.ActiveSlot(profile)
	return CardDraft.Reroll(run, slot.ClassId, seed)
end

--[[
	고른 카드를 얻는다(= 이미 있으면 강화).

	층당 몇 장까지인지는 AcquireSlotsForFloor가 정하고, 몇 장 썼는지는
	run.AcquiredThisFloor가 센다. 성공했을 때만 카운터를 올린다.
]]
function TowerRun.Acquire(profile: PlayerProfile.Profile, card: AbilityCardDefinitions.AbilityCard): (boolean, string?)
	local run = profile.TowerRun
	if not run or not run.Active then
		return false, "등반 중이 아닙니다."
	end

	local ok, reason = CardDraft.Acquire(run, card, run.AcquiredThisFloor)
	if ok then
		run.AcquiredThisFloor += 1
	end
	return ok, reason
end

-- 이번 층에 아직 더 고를 수 있는지.
function TowerRun.RemainingPicks(run: PlayerProfile.TowerRun): number
	local slots = AbilityCardDefinitions.AcquireSlotsForFloor(run.Floor)
	return math.max(slots - run.AcquiredThisFloor, 0)
end

-- 마지막 층까지 올랐는지(사양: 30층).
function TowerRun.IsCleared(run: PlayerProfile.TowerRun): boolean
	return TowerRewardDefinitions.IsFinalFloor(run.Floor)
end

--[[
	등반을 끝낸다.

	사양: "도중에 탑에서 나가거나, 탑을 클리어할 경우 아이템은 모두 돌려받지만,
	       스탯은 탑을 모두 오른 시점에 변한다."
	→ completed 여부와 무관하게 장비는 돌려주고, 레벨은 완주했을 때만 확정한다.
	   그 분기는 CardDraft.FinishRun이 이미 담고 있으므로 그대로 위임한다.
]]
function TowerRun.Finish(profile: PlayerProfile.Profile, completed: boolean): RunSummary
	local run = profile.TowerRun
	local floor = if run then run.Floor else 0
	local returned, gained = CardDraft.FinishRun(profile, completed)
	return {
		ReturnedItems = returned,
		GainedLevels = gained,
		Floor = floor,
		Completed = completed,
	}
end

-- 도중 이탈. 장비만 돌려받고 레벨은 날아간다(사양).
function TowerRun.Exit(profile: PlayerProfile.Profile): RunSummary
	return TowerRun.Finish(profile, false)
end

--[[
	완주. 30층을 오른 시점에만 부른다.
	아직 정상이 아니면 실패로 돌려주고 상태를 건드리지 않는다.
]]
function TowerRun.Complete(profile: PlayerProfile.Profile): (boolean, RunSummary?)
	local run = profile.TowerRun
	if not run or not run.Active then
		return false, nil
	end
	if not TowerRun.IsCleared(run) then
		return false, nil
	end
	return true, TowerRun.Finish(profile, true)
end

return TowerRun
