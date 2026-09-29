--[[
	auto_bracket_edits.luau — 편집기가 손으로 하던 "낱말은 [ ], 숫자는 { }"를
	설명 글 전체에 한 번에 돌린다. 이어서 숫자마다 유형과 레벨별 수치를 채운다.

	  lune run tools/auto_bracket_edits.luau <입력.json> [출력.json]

	입력은 `config_edits.json` 모양이다 (`cards.<Id>.Description`에 평문이 들어 있어도
	된다). 출력은 같은 모양이되, 다음을 채운 것이다.

	  cards.<Id>.Description   낱말은 [대괄호], 수치는 {중괄호}로 감쌌다
	  cardKeywords.<Id>#<슬롯>  그 중괄호가 어떤 낱말의 값인지 (알 수 있을 때만)
	  cardUnits.<Id>#<슬롯>     % · 배 · 턴 · 중첩 … (글에 붙은 단위를 그대로 읽는다)
	  cardLevels.<Id>.<슬롯>    레벨별 수치 (아래 "레벨 수치는 어떻게 정했나" 참고)

	이미 있던 값(슬롯 번호까지 같은 것)은 절대 덮지 않는다 — 사람이 이미 고른
	것이 기계가 다시 고른 것보다 낫다는 게 이 스크립트의 유일한 원칙이다.

	--------------------------------------------------------------------------
	괄호를 넣는 규칙

	  낱말   `Keywords.luau`에 있는 이름을 **긴 것부터** 찾아 감싼다.
	         `` `백틱` ``·`[대괄호]`·`{중괄호}` 안은 건드리지 않는다 — 그래서
	         스킬 이름(`` `중독` ``) 속의 "독" 같은 글자가 잘못 감싸이지 않는다.
	  숫자   맨 숫자를 `{ }`로 감싼다. 다만 바로 뒤에 "스킬"(1스킬 2스킬…)이나
	         "분음표"(16분음표…)가 붙으면 그건 값이 아니라 이름이라 건너뛴다.
	         바로 앞에 "레벨"이 붙으면("레벨 2에서") 레벨 번호를 말하는 것이라
	         마찬가지로 건너뛴다.
	  단위   숫자 바로 뒤 글자를 읽는다: % %p 배 턴 중첩 회 개 장 명 칸 점 레벨
	         단계. 아무것도 안 붙으면 "기본"(이어진 낱말의 단위를 따름)으로 둔다.
	  잇기   그 숫자가 있는 문장(마침표 기준)에 수치를 붙일 수 있는 낱말이
	         **정확히 하나**만 있으면 그 낱말에 잇는다. 없거나 둘 이상이면
	         비워 둔다 — 편집기에서 사람이 고르게 두는 편이 낫다.

	--------------------------------------------------------------------------
	레벨 수치는 어떻게 정했나 (`AbilityCardDefinitions.luau`의 등급표 그대로)

	  필수(레벨 2)   Lv1 = 글에 적힌 값, Lv2 = 그 값의 1.5배
	  희귀·일반(레벨 6)  Lv1 = 글에 적힌 값, 매 레벨 그 값의 20%씩 더해
	                    Lv6에서 정확히 2배가 되게 한다

	`AbilityCardDefinitions.luau` 자체 주석 "Lv6에서 초기값의 약 2배에 닿도록
	잡아 과열되지 않게 했다"를 그대로 공식으로 옮긴 것이다. **이건 사람이 카드
	하나하나를 보고 정한 값이 아니라 등급표를 기계적으로 편 것**이다 — 카드마다
	세기가 다르게 느껴져야 하는 곳(처형기 대 조건부 소소한 버프 등)은 이 공식이
	못 읽는다. 그래서 소스에 바로 쓰지 않고 편집기가 읽는 JSON으로만 낸다.
	`config_edits.json`으로 이름을 바꿔 편집기에서 "수정한 것만"으로 걸러 보며
	카드별로 확인·조정한 뒤 반영하는 것을 전제로 한다.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

--=== Roblox 흉내 (build_config_editor.luau와 같다) ===--

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r: number, g: number, b: number)
	return { R = r, G = g, B = b }
end

local sources: { [string]: string } = {}
local folders: { [string]: boolean } = {}
local function readTree(dir: string, prefix: string)
	for _, entry in fs.readDir(dir) do
		local path = dir .. entry
		if fs.isDir(path) then
			folders[prefix .. entry] = true
			readTree(path .. "/", prefix .. entry .. "/")
		else
			local name = entry:match("^(.+)%.luau$")
			if name then
				sources[prefix .. name] = fs.readFile(path)
			end
		end
	end
end
readTree("src/shared/", "")

local cache: { [string]: any } = {}
local loadShared, makeProxy
function makeProxy(prefix: string, parent: any): any
	return setmetatable({}, {
		__index = function(_, name: string)
			if name == "Parent" and parent ~= nil then
				return parent
			end
			local full = if prefix == "" then name else prefix .. "/" .. name
			if sources[full] then
				return loadShared(full)
			end
			if sources[full .. "/init"] then
				return loadShared(full .. "/init")
			end
			if folders[full] then
				return makeProxy(full, nil)
			end
			error("not found: " .. full)
		end,
	})
end
local sharedProxy = makeProxy("", nil)
function loadShared(name: string): any
	if cache[name] then
		return cache[name]
	end
	local env: any = {}
	for key, value in (getfenv and getfenv(1) or _G) :: any do
		env[key] = value
	end
	env.math, env.table, env.string = math, table, string
	env.warn = function() end
	env.Color3 = Color3
	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")
	if leaf == "init" and dir then
		local grand = dir:match("^(.*)/[^/]+$")
		env.script = makeProxy(dir, if grand then makeProxy(grand, sharedProxy) else sharedProxy)
	else
		env.script = { Parent = if dir then makeProxy(dir, sharedProxy) else sharedProxy }
	end
	env.require = function(target: any)
		return target
	end
	local result = luau.load(sources[name], { debugName = name, environment = env })()
	cache[name] = result
	return result
end

local Keywords = loadShared("Keywords")
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
loadShared("AbilityCards/init").Register()

--=== 카드 Id → 등급 ===--

local CLASSES = {
	"Musician", "Duelist", "Berserker", "Quasar", "Pulsar",
	"WallPilgrim", "WallMason", "WallBreaker", "Alchemist",
}

local cardGrade: { [string]: string } = {}
for _, classId in CLASSES do
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade) do
			cardGrade[card.Id] = grade
		end
	end
end

--=== 낱말 사전: 긴 이름부터 ===--

local keywordList = {}
for _, keyword in Keywords.All() do
	table.insert(keywordList, keyword)
end
table.sort(keywordList, function(a, b)
	return #a.Name > #b.Name
end)

--=== 보호 구간: `백틱`·[대괄호]·{중괄호} 안은 다시 안 건드린다 ===--

local function protectedMask(text: string): { [number]: boolean }
	local mask = {}
	local backtickTerms = {}
	local n = #text
	local i = 1
	while i <= n do
		local c = text:sub(i, i)
		local closeChar = if c == "[" then "]" elseif c == "{" then "}" elseif c == "`" then "`" else nil
		if closeChar then
			local j = text:find(closeChar, i + 1, true)
			if j then
				for k = i, j do
					mask[k] = true
				end
				if c == "`" then
					table.insert(backtickTerms, text:sub(i + 1, j - 1))
				end
				i = j + 1
			else
				i += 1
			end
		else
			i += 1
		end
	end

	--[[
		스킬 이름이 한 카드 글 안에서 **처음에만 백틱을 두르고 나중엔 맨글로**
		다시 나오는 경우가 있다 (예: "`중독` 스킬... 중독을 사용한 턴 이후").
		그 맨 이름 속 글자가 우연히 낱말과 겹치면(예: "중독"의 "독" = [독])
		잘못 갈라진다. 백틱으로 한 번이라도 나온 말은 그 글 안의 **다른 자리도**
		통째로 보호한다.
	]]
	for _, term in backtickTerms do
		local search = 1
		while true do
			local s, e = text:find(term, search, true)
			if not s then
				break
			end
			for k = s, e do
				mask[k] = true
			end
			search = e + 1
		end
	end

	--[[
		"n분음표"(4분음표·8분음표·16분음표…)는 **음악 용어**다. 그 안의 "음표"가
		[음표](자원 키워드 Note)와 우연히 같은 글자라, 낱말 감싸기가 그대로 두면
		"16분[음표]"처럼 용어 한가운데를 갈라놓는다. 뒤의 "분음표"뿐 아니라 앞에
		붙은 숫자까지 통째로 보호해 둘 다(낱말 단계·숫자 단계) 건드리지 않게 한다.
	]]
	local search = 1
	while true do
		local s, e = text:find("분음표", search, true)
		if not s then
			break
		end
		local digitStart = s
		while digitStart > 1 and text:byte(digitStart - 1) and (text:byte(digitStart - 1) :: number) >= 48 and (text:byte(digitStart - 1) :: number) <= 57 do
			digitStart -= 1
		end
		for k = digitStart, e do
			mask[k] = true
		end
		search = e + 1
	end

	return mask
end

local function anyProtected(mask: { [number]: boolean }, from: number, to: number): boolean
	for k = from, to do
		if mask[k] then
			return true
		end
	end
	return false
end

--=== 1단계: 낱말을 [ ]로 감싼다 ===--

local function wrapKeywords(text: string): string
	for _, keyword in keywordList do
		local search = 1
		while true do
			local mask = protectedMask(text)
			local s, e = text:find(keyword.Name, search, true)
			if not s then
				break
			end
			if anyProtected(mask, s, e) then
				search = e + 1
			else
				text = text:sub(1, s - 1) .. "[" .. text:sub(s, e) .. "]" .. text:sub(e + 1)
				search = e + 3 -- 넣은 대괄호 두 글자만큼 밀린다
			end
		end
	end
	return text
end

--=== 2단계: 맨 숫자를 { }로 감싼다 ===--

-- 뒤에 이 말이 오면 값이 아니라 이름이다 (1스킬, 16분음표…).
local SKIP_SUFFIX = { "스킬", "분음표" }
-- 앞에 이 말이 오면 "레벨 2에서"처럼 레벨 번호를 가리키는 것이다.
local SKIP_PREFIX = { "레벨" }

-- 숫자 뒤에 붙어 있으면 그것이 단위다. `UNITS`(편집기)와 같은 어휘다.
local UNIT_WORDS = { "%p", "%", "배", "턴", "중첩", "회", "개", "장", "명", "칸", "점", "레벨", "단계" }

local function isWordByte(byte: number?): boolean
	if not byte then
		return false
	end
	return (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte >= 0x80
end

-- Position은 `{`를 넣기 **전** 숫자의 시작 자리다. 뒤에서 더 넣는 중괄호는
-- 전부 이 자리 뒤쪽에서만 생기므로, 마지막 글에서도 그대로 유효하다.
type NumberHit = { Slot: number, Value: number, Unit: string, Position: number }

local function wrapNumbers(text: string): (string, { NumberHit })
	local hits: { NumberHit } = {}
	local slot = 0
	local i = 1
	while i <= #text do
		local mask = protectedMask(text)
		local c = text:byte(i)
		local isSign = (c == 45 or (text:sub(i, i + 2) == "\226\136\146")) -- '-' 또는 U+2212
		local signLen = if c == 45 then 1 elseif isSign then 3 else 0
		local digitStart = i + signLen
		local isDigit = text:byte(digitStart) and text:byte(digitStart) >= 48 and text:byte(digitStart) <= 57
		if signLen > 0 and not isDigit then
			-- 부호처럼 보였지만 숫자가 안 따라온다. 그냥 넘어간다.
			i += 1
		elseif isDigit and not mask[digitStart] then
			local j = digitStart
			while j <= #text and text:byte(j) and text:byte(j) :: number >= 48 and text:byte(j) :: number <= 57 do
				j += 1
			end
			if text:sub(j, j) == "." and text:byte(j + 1) and text:byte(j + 1) :: number >= 48 and text:byte(j + 1) :: number <= 57 then
				j += 1
				while j <= #text and text:byte(j) and text:byte(j) :: number >= 48 and text:byte(j) :: number <= 57 do
					j += 1
				end
			end
			local numEnd = j - 1
			local numStart = i
			local prevByte = if numStart > 1 then text:byte(numStart - 1) else nil

			local skip = false
			if isWordByte(prevByte) then
				skip = true -- 앞이 글자다. 낱말의 일부다 (16분음표의 "6"처럼).
			end
			for _, word in SKIP_SUFFIX do
				if text:sub(numEnd + 1, numEnd + #word) == word then
					skip = true
				end
			end
			for _, word in SKIP_PREFIX do
				-- "레벨 2에서"처럼 낱말과 숫자 사이에 **띄어쓰기가 있을 수 있다.**
				if text:sub(numStart - #word, numStart - 1) == word
					or text:sub(numStart - #word - 1, numStart - 1) == word .. " " then
					skip = true
				end
			end

			if skip then
				i = numEnd + 1
			else
				local unit = ""
				for _, word in UNIT_WORDS do
					if text:sub(numEnd + 1, numEnd + #word) == word then
						unit = word
						break
					end
				end
				local raw = text:sub(numStart, numEnd)
				slot += 1
				table.insert(hits, {
					Slot = slot,
					Value = tonumber((raw:gsub("\226\136\146", "-"))) :: number,
					Unit = unit,
					Position = numStart,
				})
				text = text:sub(1, numStart - 1) .. "{" .. raw .. "}" .. text:sub(numEnd + 1)
				i = numEnd + 3 -- 넣은 중괄호 두 글자
			end
		else
			i += 1
		end
	end
	return text, hits
end

--=== 3단계: 숫자가 있는 문장에서 낱말을 하나 찾으면 잇는다 ===--

-- 마침표 기준으로 문장을 가른다. 완벽하지 않아도 "가까운 문맥"이면 충분하다.
local function sentenceOf(text: string, at: number): string
	local start = 1
	for i = at - 1, 1, -1 do
		if text:sub(i, i) == "." then
			start = i + 1
			break
		end
	end
	local stop = #text
	local dot = text:find(".", at, true)
	if dot then
		stop = dot
	end
	return text:sub(start, stop)
end

local function linkKeyword(sentence: string): string?
	local found: { string } = {}
	local seen: { [string]: boolean } = {}
	for name in sentence:gmatch("%[([^%]]+)%]") do
		local keyword = Keywords.ByName(name)
		if keyword and keyword.Scalable and not seen[keyword.Id] then
			seen[keyword.Id] = true
			table.insert(found, keyword.Id)
		end
	end
	if #found == 1 then
		return found[1]
	end
	return nil
end

--=== 4단계: 레벨 사다리. `AbilityCardDefinitions`의 등급표를 그대로 편다 ===--

local function roundLike(base: number, value: number): number
	if base % 1 == 0 then
		return math.floor(value + 0.5)
	end
	return math.floor(value * 10 + 0.5) / 10
end

local function levelLadder(base: number, maxLevel: number): { number }
	local ladder = {}
	if maxLevel <= 1 then
		return { base }
	end
	if maxLevel == 2 then
		ladder[1] = base
		ladder[2] = roundLike(base, base * 1.5)
		return ladder
	end
	local step = base * 0.2
	for level = 1, maxLevel do
		ladder[level] = roundLike(base, base + step * (level - 1))
	end
	return ladder
end

--=== 실행 ===--

local inPath = process.args[1]
if not inPath then
	print("사용법: lune run tools/auto_bracket_edits.luau <입력.json> [출력.json]")
	process.exit(1)
end
local outPath = process.args[2] or "config_edits_auto.json"

local data = serde.decode("json", fs.readFile(inPath))
data.cards = data.cards or {}
data.cardKeywords = data.cardKeywords or {}
data.cardUnits = data.cardUnits or {}
data.cardLevels = data.cardLevels or {}

local touchedCards, touchedNumbers, linkedNumbers = 0, 0, 0

-- 결과를 훑는 순서가 매번 달라지지 않도록 Id를 정렬해 처리한다.
local cardIds = {}
for id in data.cards do
	table.insert(cardIds, id)
end
table.sort(cardIds)

for _, id in cardIds do
	local entry = data.cards[id]
	if type(entry) == "table" and type(entry.Description) == "string" then
		local text = entry.Description
		local before = text
		text = wrapKeywords(text)
		local hits
		text, hits = wrapNumbers(text)

		if text ~= before then
			entry.Description = text
			touchedCards += 1
		end

		local grade = cardGrade[id]
		local maxLevel = if grade then AbilityCardDefinitions.MaxLevel(grade) else 6

		for _, hit in hits do
			touchedNumbers += 1
			local key = id .. "#" .. tostring(hit.Slot)

			if hit.Unit ~= "" and (not data.cardUnits[key] or data.cardUnits[key].Unit == nil) then
				data.cardUnits[key] = { Unit = hit.Unit }
			end

			if not data.cardKeywords[key] or data.cardKeywords[key].Keyword == nil then
				local linked = linkKeyword(sentenceOf(text, hit.Position))
				if linked then
					data.cardKeywords[key] = { Keyword = linked }
					linkedNumbers += 1
				end
			end

			local existingLevels = data.cardLevels[id] and data.cardLevels[id][tostring(hit.Slot)]
			if not existingLevels then
				data.cardLevels[id] = data.cardLevels[id] or {}
				local ladder = levelLadder(hit.Value, maxLevel)
				local levelMap = {}
				for level, value in ladder do
					levelMap[tostring(level)] = value
				end
				data.cardLevels[id][tostring(hit.Slot)] = levelMap
			end
		end
	end
end

print(string.format(
	"[auto_bracket] 카드 %d장의 글을 고침 · 숫자 %d개 감쌈 · 키워드 연결 %d개",
	touchedCards, touchedNumbers, linkedNumbers
))

fs.writeFile(outPath, serde.encode("json", data, true))
print("[auto_bracket] " .. outPath .. " 에 썼습니다. 편집기에서 \"수정본 불러오기\"로 열어 확인하세요.")
