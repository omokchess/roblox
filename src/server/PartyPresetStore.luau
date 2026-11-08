--!strict
--[[
	PartyPresetStore — 파티 프리셋 저장(F2 디버그 패널 '파티 편성' 창). 2026-11-08, 사양: 파티전투_사양.md 4절.

	프리셋 = { Name, Units = { {ClassId, X, Y, Cards = {{CardId, Level}}, Level?} } }. 사람마다 최대 MAX_PRESETS 개.
	저장: DataStore `DebugPartyPresets`, 키 = UserId(문자열). **porcelain.* 저장 키는 건드리지 않는다.**
	DataStore 를 못 쓰면(Studio API 접근 꺼짐 · 읽기/쓰기 pcall 실패) 서버 메모리에만 두고 응답의 Persistent = false 로 알린다.

	Roblox 서비스를 이 파일 위쪽에서 부르지 않는다 — 검사·메모리 대체 경로를 lune 에서 시험하려고
	의존(검사 함수·카드 조회·예시)을 `new` 에 넣어 받는다. 실제 연결은 `PartyPresetStore.Roblox()` 와 init.server.luau.
]]

export type Unit =
	{ ClassId: string, X: number, Y: number, Cards: { { CardId: string, Level: number } }, Level: number? }
export type Preset = { Name: string, Units: { Unit } }
export type Backend = { Get: (key: string) -> any, Set: (key: string, value: any) -> () }
export type CardInfo = { ClassId: string, MaxLevel: number }
export type Deps = {
	Validate: (units: { any }) -> (boolean, string?),
	Card: (cardId: string) -> CardInfo?,
	Examples: () -> { { Name: string } },
	Backend: Backend?,
	MaxUnitLevel: number?,
}

local PartyPresetStore = {}
PartyPresetStore.__index = PartyPresetStore

PartyPresetStore.MAX_PRESETS = 30
PartyPresetStore.MAX_NAME = 40
local MAX_CARDS_PER_UNIT = 60

function PartyPresetStore.new(deps: Deps)
	return setmetatable({
		Deps = deps,
		Lists = {} :: { [number]: { Preset } }, -- 사람별 메모리 사본(DataStore 를 한 번 읽은 뒤의 정답)
		Degraded = {} :: { [number]: boolean }, -- 이 사람은 DataStore 가 막혀 메모리만 쓴다
	}, PartyPresetStore)
end

-- 실제 DataStore 연결. 얻지 못하면 nil(= 메모리 전용)
function PartyPresetStore.Roblox(): Backend?
	local ok, store = pcall(function()
		return (game :: any):GetService("DataStoreService"):GetDataStore("DebugPartyPresets")
	end)
	if not ok or not store then
		return nil
	end
	return {
		Get = function(key: string): any
			return store:GetAsync(key)
		end,
		Set = function(key: string, value: any)
			store:SetAsync(key, value)
		end,
	}
end

--=== 안쪽 ===--

function PartyPresetStore:_persistent(userId: number): boolean
	return self.Deps.Backend ~= nil and not self.Degraded[userId]
end

function PartyPresetStore:_list(userId: number): { Preset }
	local list = self.Lists[userId]
	if list then
		return list
	end
	list = {}
	if self.Deps.Backend then
		local backend = self.Deps.Backend :: Backend
		local ok, stored = pcall(backend.Get, tostring(userId))
		if ok then
			if type(stored) == "table" then
				for _, entry in stored do
					if type(entry) == "table" and type(entry.Name) == "string" and type(entry.Units) == "table" then
						table.insert(list, entry)
					end
				end
			end
		else
			self.Degraded[userId] = true
		end
	end
	self.Lists[userId] = list
	return list
end

function PartyPresetStore:_flush(userId: number)
	if not self:_persistent(userId) then
		return
	end
	local backend = self.Deps.Backend :: Backend
	local ok = pcall(backend.Set, tostring(userId), self.Lists[userId])
	if not ok then
		self.Degraded[userId] = true
	end
end

function PartyPresetStore:_reply(userId: number, errorText: string?): { [string]: any }
	return {
		Presets = self:_list(userId),
		Examples = self.Deps.Examples(),
		Persistent = self:_persistent(userId),
		Error = errorText,
	}
end

-- 요청 유닛을 검사하고 깨끗한 사본을 돌려준다. 실패하면 nil, 사유(한국어)
function PartyPresetStore:_clean(rawUnits: any): ({ Unit }?, string?)
	if type(rawUnits) ~= "table" then
		return nil, "유닛 목록이 없습니다."
	end
	local units: { Unit } = {}
	for _, raw in rawUnits do
		if
			type(raw) ~= "table"
			or type(raw.ClassId) ~= "string"
			or type(raw.X) ~= "number"
			or type(raw.Y) ~= "number"
		then
			return nil, "유닛 모양이 잘못됐습니다."
		end
		local level: number? = nil
		if raw.Level ~= nil then
			local maxLevel = self.Deps.MaxUnitLevel or 60
			if type(raw.Level) ~= "number" or raw.Level % 1 ~= 0 or raw.Level < 1 or raw.Level > maxLevel then
				return nil, string.format("유닛 레벨은 1~%d 정수여야 합니다 (%s).", maxLevel, raw.ClassId)
			end
			level = raw.Level
		end
		local cards: { { CardId: string, Level: number } } = {}
		local rawCards = raw.Cards
		if rawCards ~= nil and type(rawCards) ~= "table" then
			return nil, "카드 목록 모양이 잘못됐습니다."
		end
		local seen: { [string]: boolean } = {}
		for _, card in rawCards or {} do
			if type(card) ~= "table" or type(card.CardId) ~= "string" or type(card.Level) ~= "number" then
				return nil, "카드 모양이 잘못됐습니다."
			end
			local info = self.Deps.Card(card.CardId)
			if not info then
				return nil, string.format("없는 카드입니다 (%s).", card.CardId)
			end
			if info.ClassId ~= raw.ClassId then
				return nil, string.format("%s 의 카드가 아닙니다 (%s).", raw.ClassId, card.CardId)
			end
			if card.Level % 1 ~= 0 or card.Level < 1 or card.Level > info.MaxLevel then
				return nil,
					string.format("카드 레벨은 1~%d 정수여야 합니다 (%s).", info.MaxLevel, card.CardId)
			end
			if seen[card.CardId] then
				return nil, string.format("같은 카드를 두 번 넣었습니다 (%s).", card.CardId)
			end
			seen[card.CardId] = true
			table.insert(cards, { CardId = card.CardId, Level = card.Level })
		end
		if #cards > MAX_CARDS_PER_UNIT then
			return nil, "카드가 너무 많습니다."
		end
		table.insert(units, { ClassId = raw.ClassId, X = raw.X, Y = raw.Y, Cards = cards, Level = level })
	end
	local ok, reason = self.Deps.Validate(units)
	if not ok then
		return nil, reason or "파티 구성이 맞지 않습니다."
	end
	return units, nil
end

--=== 요청 ===--

--[[
	request = { Op = "List" | "Save" | "Delete", Name?, Units? }
	응답    = { Presets, Examples, Persistent, Error? } — 실패해도 현재 목록은 같이 준다.
]]
function PartyPresetStore:Handle(userId: number, request: any): { [string]: any }
	if type(request) ~= "table" then
		return self:_reply(userId, "요청이 잘못됐습니다.")
	end
	local op = request.Op
	local list = self:_list(userId)
	if op == "List" then
		return self:_reply(userId, nil)
	end

	local name = request.Name
	if type(name) ~= "string" then
		return self:_reply(userId, "이름이 없습니다.")
	end
	name = (name:gsub("^%s+", ""):gsub("%s+$", ""))
	local length = utf8.len(name)
	if not length or length < 1 or length > PartyPresetStore.MAX_NAME then
		return self:_reply(userId, string.format("이름은 1~%d자여야 합니다.", PartyPresetStore.MAX_NAME))
	end

	local at: number? = nil
	for index, preset in list do
		if preset.Name == name then
			at = index
		end
	end

	if op == "Delete" then
		if not at then
			return self:_reply(userId, "그 이름의 저장분이 없습니다.")
		end
		table.remove(list, at)
		self:_flush(userId)
		return self:_reply(userId, nil)
	elseif op == "Save" then
		for _, example in self.Deps.Examples() do
			if example.Name == name then
				return self:_reply(userId, "예시 프리셋과 같은 이름으로는 저장할 수 없습니다.")
			end
		end
		local units, reason = self:_clean(request.Units)
		if not units then
			return self:_reply(userId, reason)
		end
		if not at and #list >= PartyPresetStore.MAX_PRESETS then
			return self:_reply(
				userId,
				string.format(
					"저장은 최대 %d개까지입니다. 하나를 지우세요.",
					PartyPresetStore.MAX_PRESETS
				)
			)
		end
		local preset: Preset = { Name = name, Units = units }
		if at then
			list[at] = preset
		else
			table.insert(list, preset)
		end
		self:_flush(userId)
		return self:_reply(userId, nil)
	end
	return self:_reply(userId, "알 수 없는 요청입니다.")
end

return PartyPresetStore
