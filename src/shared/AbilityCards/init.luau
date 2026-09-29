--!strict
--[[
	AbilityCards — 직업별 카드 묶음의 등록 창구.

	직업 카드 파일을 하나 추가할 때 이 목록에만 넣으면 된다.
	`Register()`가 AbilityCardDefinitions에 전부 밀어넣고,
	종류 수(필수 4 / 희귀 10 / 일반 20)가 사양과 다르면 그쪽에서 경고를 낸다.

	사양 출처: 추가&수정.md `###### 능력 카드`

	로스터는 `유저 아이디어(직업).md`의 직업들이다. 9직업 × 34종 = 306종.
	이전 로스터에서는 광전사만 남았다.
]]

local AbilityCardDefinitions = require(script.Parent.AbilityCardDefinitions)

export type ClassCardModule = {
	ClassId: string,
	Cards: { AbilityCardDefinitions.AbilityCard },
}

-- 직업 카드 파일 목록. 새 직업을 만들면 여기에 한 줄 추가한다.
local modules: { ClassCardModule } = {
	require(script.MusicianCards),
	require(script.DuelistCards),
	require(script.QuasarCards),
	require(script.PulsarCards),
	require(script.WallPilgrimCards),
	require(script.WallMasonCards),
	require(script.WallBreakerCards),
	require(script.AlchemistCards),
	require(script.BerserkerCards),
}

local AbilityCards = {}

AbilityCards.Modules = modules

-- 아직 카드를 만들지 않은 직업을 알려준다. (CharacterDefinitions와 대조용)
function AbilityCards.RegisteredClassIds(): { string }
	local ids: { string } = {}
	for _, module in modules do
		table.insert(ids, module.ClassId)
	end
	return ids
end

function AbilityCards.Register(): number
	for _, module in modules do
		AbilityCardDefinitions.RegisterClassCards(module.ClassId, module.Cards)
	end
	return #modules
end

return AbilityCards
