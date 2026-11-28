--[[
	field_party_test.luau — 필드 몹·보스 트리거가 여는 파티(PartyDefinitions.FieldParty) 점검.
	  lune run tools/field_party_test.luau
]]
local loadShared = require("./lune_env")
local PartyDefinitions = loadShared("PartyDefinitions")

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local default = PartyDefinitions.FieldParty(nil)
check(#default.Units == PartyDefinitions.PARTY_SIZE, "기본 편성은 4인")
local hasProtagonist = false
for _, unit in default.Units do
	hasProtagonist = hasProtagonist or unit.ClassId == PartyDefinitions.PROTAGONIST_ID
end
check(hasProtagonist, "기본 편성에 주인공")
check(PartyDefinitions.Validate(default.Units), "기본 편성이 Validate 통과")
-- 복사본이라 고쳐도 예시 원본은 그대로
default.Units[1].X = 99
check(PartyDefinitions.FieldParty(nil).Units[1].X ~= 99, "예시 원본 보존")
local last = { Units = { { ClassId = "Protagonist", X = 1, Y = 1 } } }
check(PartyDefinitions.FieldParty(last) == last, "마지막 편성 우선")
check(#PartyDefinitions.FieldParty({ Units = {} }).Units == 4, "빈 편성은 기본으로")
print("field_party_test 통과")
