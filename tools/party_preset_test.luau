--[[
	party_preset_test.luau — PartyPresetStore 점검(2026-11-08). DataStore 없는 환경(메모리 대체) · 검사 거절 · 30개 한도 · 쓰기 실패 대체.
	  lune run tools/party_preset_test.luau
	실패하면 오류로 끝난다.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local loadShared = require("./lune_env")

loadShared("AbilityCards/init").Register()
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
local PartyDefinitions = loadShared("PartyDefinitions")

local Store = luau.load(fs.readFile("src/server/PartyPresetStore.luau"), { debugName = "PartyPresetStore" })()

local function check(ok: any, msg: string)
	if not ok then
		error("실패: " .. msg, 2)
	end
end

local function deps(backend: any)
	return {
		Validate = PartyDefinitions.Validate,
		Card = function(cardId: string)
			local card = AbilityCardDefinitions.Get(cardId)
			if not card then
				return nil
			end
			return { ClassId = card.ClassId, MaxLevel = AbilityCardDefinitions.MaxLevelFor(card) }
		end,
		Examples = PartyDefinitions.Examples,
		Backend = backend,
		MaxUnitLevel = 60,
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local examples = PartyDefinitions.Examples()
check(#examples == 3, "예시가 3개여야 한다")
local function exampleUnits(i: number): any
	return deepCopy(examples[i].Units)
end

-- 1) 메모리 대체(Backend 없음): 저장·목록·덮어쓰기·지우기
do
	local store = Store.new(deps(nil))
	local reply = store:Handle(1, { Op = "List" })
	check(reply.Persistent == false, "Backend 없으면 Persistent=false")
	check(#reply.Presets == 0 and #reply.Examples == 3, "빈 목록 + 예시 3")
	reply = store:Handle(1, { Op = "Save", Name = "  내 파티  ", Units = exampleUnits(1) })
	check(reply.Error == nil and #reply.Presets == 1 and reply.Presets[1].Name == "내 파티", "저장(이름 공백 다듬기): " .. tostring(reply.Error))
	reply = store:Handle(1, { Op = "Save", Name = "내 파티", Units = exampleUnits(2) })
	check(reply.Error == nil and #reply.Presets == 1 and #reply.Presets[1].Units == 5, "같은 이름은 덮어쓴다")
	check(#store:Handle(2, { Op = "List" }).Presets == 0, "사람마다 따로")
	reply = store:Handle(1, { Op = "Delete", Name = "없는 이름" })
	check(reply.Error ~= nil, "없는 이름 지우기는 오류")
	reply = store:Handle(1, { Op = "Delete", Name = "내 파티" })
	check(reply.Error == nil and #reply.Presets == 0, "지우기")
end

-- 2) 예시 3개 모두 검사를 통과한다(예시와 같은 이름은 거절)
do
	local store = Store.new(deps(nil))
	for i = 1, 3 do
		local reply = store:Handle(1, { Op = "Save", Name = "복사" .. i, Units = exampleUnits(i) })
		check(reply.Error == nil, "예시 " .. i .. " 저장: " .. tostring(reply.Error))
	end
	local reply = store:Handle(1, { Op = "Save", Name = examples[1].Name, Units = exampleUnits(1) })
	check(reply.Error ~= nil, "예시 이름으로 저장 거절")
end

-- 3) 거절들
do
	local store = Store.new(deps(nil))
	local function rejected(label: string, mutate: (any) -> (), name: string?)
		local units = exampleUnits(1)
		mutate(units)
		local reply = store:Handle(1, { Op = "Save", Name = name or "x", Units = units })
		check(reply.Error ~= nil and #reply.Presets == 0, label .. " 는 거절돼야 한다")
	end
	rejected("없는 카드", function(u) u[1].Cards[1].CardId = "Nope_Card" end)
	rejected("최대 레벨 초과", function(u) u[1].Cards[1].Level = 99 end)
	rejected("레벨 0", function(u) u[1].Cards[1].Level = 0 end)
	rejected("소수 레벨", function(u) u[1].Cards[1].Level = 1.5 end)
	rejected("남의 직업 카드", function(u) u[1].Cards[1].CardId = u[2].Cards[1].CardId end)
	rejected("같은 카드 두 번", function(u) table.insert(u[1].Cards, deepCopy(u[1].Cards[1])) end)
	rejected("유닛 레벨 61", function(u) u[1].Level = 61 end)
	rejected("같은 직업 중복", function(u) u[2].ClassId = u[1].ClassId; u[2].Cards = {} end)
	rejected("같은 칸", function(u) u[2].X = u[1].X; u[2].Y = u[1].Y end)
	rejected("격자 밖", function(u) u[1].X = 7 end)
	rejected("코스트 초과", function(u) table.insert(u, { ClassId = "Attuner", X = 1, Y = 1, Cards = {} }) end)
	rejected("유닛 없음", function(u) for i = #u, 1, -1 do u[i] = nil end end)
	rejected("이름 41자", function() end, string.rep("가", 41))
	rejected("이름 없음", function() end, "   ")
	check(store:Handle(1, { Op = "Zap" }).Error ~= nil, "모르는 Op")
	check(store:Handle(1, "문자열").Error ~= nil, "표 아닌 요청")
	check(store:Handle(1, { Op = "Save", Name = "a", Units = "x" }).Error ~= nil, "유닛이 표 아님")
end

-- 4) 30개 한도: 31번째 새 이름은 거절, 덮어쓰기는 가능
do
	local store = Store.new(deps(nil))
	for i = 1, 30 do
		check(store:Handle(1, { Op = "Save", Name = "p" .. i, Units = exampleUnits(1) }).Error == nil, "저장 " .. i)
	end
	check(store:Handle(1, { Op = "Save", Name = "p31", Units = exampleUnits(1) }).Error ~= nil, "31번째 거절")
	check(store:Handle(1, { Op = "Save", Name = "p5", Units = exampleUnits(2) }).Error == nil, "한도에서도 덮어쓰기는 된다")
	check(#store:Handle(1, { Op = "List" }).Presets == 30, "30개 유지")
end

-- 5) DataStore 가짜: 저장·읽기 되고, 쓰기가 실패하면 메모리 전용으로 내려간다
do
	local data: any = {}
	local failWrite = false
	local backend = {
		Get = function(key: string)
			return data[key]
		end,
		Set = function(key: string, value: any)
			if failWrite then
				error("DataStore 막힘")
			end
			data[key] = deepCopy(value)
		end,
	}
	local store = Store.new(deps(backend))
	local reply = store:Handle(7, { Op = "Save", Name = "저장분", Units = exampleUnits(3) })
	check(reply.Error == nil and reply.Persistent == true and data["7"] and #data["7"] == 1, "DataStore 에 키=UserId 로 저장")
	check(#Store.new(deps(backend)):Handle(7, { Op = "List" }).Presets == 1, "새 서버가 저장분을 읽는다")
	failWrite = true
	reply = store:Handle(7, { Op = "Save", Name = "둘째", Units = exampleUnits(1) })
	check(reply.Error == nil and reply.Persistent == false and #reply.Presets == 2, "쓰기 실패 → 메모리에 남기고 Persistent=false")
	local readFails = {
		Get = function()
			error("API 접근 꺼짐")
		end,
		Set = function() end,
	}
	reply = Store.new(deps(readFails)):Handle(9, { Op = "Save", Name = "z", Units = exampleUnits(1) })
	check(reply.Error == nil and reply.Persistent == false and #reply.Presets == 1, "읽기 실패 → 메모리 전용")
end

print("party_preset_test 통과")
