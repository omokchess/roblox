--!strict
--[[
	CardDraft — 층별 보상 흐름(뽑기 → 리롤 → 업그레이드)의 순수 로직.

	사양 출처: 추가&수정.md `##### 층별 보상`, `###### 능력 카드`

	이 모듈은 **데이터와 저장 사이를 잇는 층**이다.
	  AbilityCardDefinitions  뽑기·상한 규칙과 카드 풀
	  PlayerProfile.TowerRun  등반 중 상태(코스트·리롤 횟수·보유 카드)
	  CardDraft (여기)        그 둘을 실제 흐름으로 묶는다

	전투 로직에 의존하지 않아 Studio 없이 전부 검증된다.
	카드의 *효과*를 적용하는 것은 전투 시스템 재구성 때 별도로 붙인다.
	여기서는 **무엇을 얼마나 얻고 올릴 수 있는지**만 다룬다.

	흐름
	  층 클리어 → BeginFloor()  코스트 30 지급, 리롤 횟수 초기화, 카드 제시
	  마음에 안 들면 → Reroll()  코스트 차감(10 → 15 → 23 …), 다시 제시
	  하나 고르면 → Acquire()   카드 획득. **같은 카드를 또 얻으면 강화된다**
	                            (상한: 필수 2 / 나머지 6, 도달 시 이후 등장 안 함)
]]

local AbilityCardDefinitions = require(script.Parent.AbilityCardDefinitions)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ProgressionDefinitions = require(script.Parent.ProgressionDefinitions)
local StatDefinitions = require(script.Parent.StatDefinitions)
local TowerRewardDefinitions = require(script.Parent.TowerRewardDefinitions)

export type DraftResult = {
	Ok: boolean,
	Reason: string?,
	Cards: { AbilityCardDefinitions.AbilityCard },
	Cost: number,
	NextRerollCost: number,
}

local CardDraft = {}

--[[
	이미 최대 레벨에 도달한 카드 Id 목록.
	뽑기에서 제외해 쓸모없는 선택지가 나오지 않게 한다.
]]
function CardDraft.MaxedCardIds(run: PlayerProfile.TowerRun): { [string]: boolean }
	local maxed: { [string]: boolean } = {}
	for _, progress in run.Cards do
		local card = AbilityCardDefinitions.Get(progress.CardId)
		local cap = if card
			then AbilityCardDefinitions.MaxLevelFor(card)
			else AbilityCardDefinitions.MaxLevel(progress.Grade :: any)
		if progress.Level >= cap then
			maxed[progress.CardId] = true
		end
	end
	return maxed
end

-- 이 등반에서 해당 카드가 몇 레벨인지. 없으면 0.
function CardDraft.CardLevel(run: PlayerProfile.TowerRun, cardId: string): number
	for _, progress in run.Cards do
		if progress.CardId == cardId then
			return progress.Level
		end
	end
	return 0
end

--[[
	층을 클리어하고 다음 층 보상 화면에 들어간다.

	  - 코스트 30 지급 (사양)
	  - 리롤 가격 초기화 (사양: "층 이동 시 가격은 초기화된다")
	  - 층수에 맞는 카드 제시 (10층 단위면 필수 3종이 확정 추가)
	  - 레벨 상승분을 PendingLevel에 쌓는다
	    (사양: "스탯은 탑을 모두 오른 시점에 변한다")
]]
function CardDraft.BeginFloor(run: PlayerProfile.TowerRun, classId: string, floor: number, seed: number): DraftResult
	run.Floor = floor
	run.Cost += TowerRewardDefinitions.COST_PER_FLOOR
	run.RerollCount = TowerRewardDefinitions.ResetRerollCount()
	run.PendingLevel += ProgressionDefinitions.LevelGainForFloor(floor)

	--[[
		층에 막 들어왔으므로 아직 아무것도 고르지 않았다(0). 필수 층이면 이 화면이
		필수 3종이고, 한 장을 고르면 다음 화면에서 희귀·일반이 나온다.
	]]
	local cards = AbilityCardDefinitions.DrawForFloor(classId, floor, seed, CardDraft.MaxedCardIds(run), 0, run.Cards)

	return {
		Ok = true,
		Reason = nil,
		Cards = cards,
		Cost = run.Cost,
		NextRerollCost = TowerRewardDefinitions.RerollCost(run.RerollCount),
	}
end

--[[
	보상을 다시 뽑는다. 횟수 제한은 없고 가격만 오른다(사양).
	코스트가 모자라면 아무것도 바꾸지 않고 실패를 돌려준다.
]]
function CardDraft.Reroll(run: PlayerProfile.TowerRun, classId: string, seed: number): DraftResult
	local price = TowerRewardDefinitions.RerollCost(run.RerollCount)

	if run.Cost < price then
		return {
			Ok = false,
			Reason = string.format("코스트가 부족합니다. (필요 %d, 보유 %d)", price, run.Cost),
			Cards = {},
			Cost = run.Cost,
			NextRerollCost = price,
		}
	end

	run.Cost -= price
	run.RerollCount += 1

	--[[
		리롤할 때마다 다른 조합이 나오도록 seed에 횟수를 섞는다.

		`AcquiredThisFloor`를 함께 넘겨 **지금 보고 있는 화면을 그대로 다시 뽑는다** —
		필수 화면에서 리롤했는데 희귀·일반이 나오면 리롤로 단계를 건너뛰게 된다.
	]]
	local cards = AbilityCardDefinitions.DrawForFloor(
		classId,
		run.Floor,
		seed + run.RerollCount * 31337,
		CardDraft.MaxedCardIds(run),
		run.AcquiredThisFloor,
		run.Cards
	)

	return {
		Ok = true,
		Reason = nil,
		Cards = cards,
		Cost = run.Cost,
		NextRerollCost = TowerRewardDefinitions.RerollCost(run.RerollCount),
	}
end

--[[
	고른 카드를 **얻는다**.

	사양: "층을 클리어 할 때마다 능력 카드중 한개를 얻을 수 있다.
	       5층 단위로 획득 가능한 능력 카드가 1개씩 증가한다.
	       똑같은 카드를 한번 더 얻으면 강화 되며,
	       해당 카드가 최대 레벨에 도달 시 다음 층부터는 등장하지 않는다."

	즉 별도의 '업그레이드' 행동이 없다. **획득이 곧 강화**다.
	  처음 얻으면      → 레벨 1
	  또 얻으면        → 레벨 +1 (강화)
	  최대 레벨에 닿으면 → 이후 뽑기에서 제외 (MaxedCardIds가 처리)

	이번 층의 획득 가능 장수는 AcquireSlotsForFloor(floor)이며,
	usedThisFloor로 이미 얻은 장수를 넘겨받아 판정한다.
]]
function CardDraft.Acquire(
	run: PlayerProfile.TowerRun,
	card: AbilityCardDefinitions.AbilityCard,
	usedThisFloor: number
): (boolean, string?)
	local slots = AbilityCardDefinitions.AcquireSlotsForFloor(run.Floor)
	if usedThisFloor >= slots then
		return false,
			string.format(
				"이번 층에서 얻을 수 있는 카드를 모두 얻었습니다. (%d/%d)",
				usedThisFloor,
				slots
			)
	end

	local current = CardDraft.CardLevel(run, card.Id)
	local cap = AbilityCardDefinitions.MaxLevelFor(card)
	if current >= cap then
		return false, string.format("이미 최대 레벨입니다. (%d/%d)", current, cap)
	end

	-- 이미 가지고 있으면 강화(레벨 +1), 없으면 레벨 1로 새로 넣는다.
	for _, progress in run.Cards do
		if progress.CardId == card.Id then
			progress.Level += 1
			return true, nil
		end
	end

	table.insert(run.Cards, {
		CardId = card.Id,
		Grade = card.Grade,
		Level = 1,
	})
	return true, nil
end

--[[
	등반을 마치거나 도중에 나간다.

	사양: "도중에 탑에서 나가거나, 탑을 클리어할 경우 아이템은 모두 돌려받지만,
	       스탯은 탑을 모두 오른 시점에 변한다."
	→ 보관했던 장비는 항상 돌려주고,
	  레벨·스탯 포인트는 **완주했을 때만** 슬롯에 반영한다.
]]
function CardDraft.FinishRun(profile: PlayerProfile.Profile, completed: boolean): (number, number)
	local run = profile.TowerRun
	if not run then
		return 0, 0
	end

	local slot = PlayerProfile.ActiveSlot(profile)

	-- 장비는 나가는 방식과 무관하게 돌려준다.
	local returned = 0
	for _, item in run.StoredItems do
		table.insert(slot.Items, item)
		returned += 1
	end

	--[[
		레벨은 완주했을 때만 확정된다.

		스탯 포인트는 등반 **도중에** 이미 지급됐을 수 있다(층마다 찍을 수 있어야
		선택이 되기 때문이다). 그만큼은 빼고 남은 몫만 준다 — 안 그러면 완주 시
		같은 포인트를 두 번 받는다.
	]]
	local gainedLevels = 0
	if completed then
		gainedLevels = run.PendingLevel
		slot.Level += gainedLevels
		local owed = gainedLevels * StatDefinitions.POINTS_PER_LEVEL - run.GrantedPoints
		slot.UnspentPoints += math.max(owed, 0)
	end

	-- 최고 도달 층은 계정에 남는다.
	if run.Floor > profile.Account.HighestFloor then
		profile.Account.HighestFloor = run.Floor
	end

	profile.TowerRun = nil
	return returned, gainedLevels
end

return CardDraft
