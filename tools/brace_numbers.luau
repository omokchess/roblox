--[[
	brace_numbers.luau — 카드 설명의 맨 숫자를 전부 `{ }`로 감싼다.

	  lune run tools/brace_numbers.luau
	  lune run tools/apply_config_edits.luau config_edits_brace_numbers.json

	--------------------------------------------------------------------------
	사다리(`Levels`)가 있는 카드는 건드리지 않는다

	`{n}`이 나온 **순서**가 곧 몇 번째 사다리인지를 정한다(`Describe`). 이미
	`Levels`가 있는 카드에 다른 숫자를 새로 감싸면 중괄호 개수가 사다리 개수보다
	많아져 순서가 밀리고, `PrototypeTests`의 "글의 중괄호 수 == 사다리 수" 불변식도
	깨진다. 그래서 `AbilityCardDefinitions.HasScaling(card)`가 참인 카드는 건너뛴다
	(지금은 연금술사 34장이 전부 이 경우다).

	--------------------------------------------------------------------------
	감싸지 않는 경우 (`auto_bracket_edits.luau`의 숫자 규칙과 같다)

	  1스킬 · 16분음표   스킬 번호·음표 이름이지 값이 아니다
	  레벨 2에서         레벨 번호를 가리키는 것이지 값이 아니다
	  이미 `` ` ``·`[ ]`·`{ }` 안   건드리지 않는다

	고친 것만 모아 `apply_config_edits.luau`가 읽는 JSON을 만들고 그 스크립트를
	그대로 불러 쓴다 — 블록 찾기·여러 줄 문자열 나누기·CRLF 줄바꿈을 다시 짤
	이유가 없다.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

--=== Roblox 흉내 (다른 tools 스크립트들과 같다) ===--

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

local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
loadShared("AbilityCards/init").Register()

local CLASSES = {
	"Musician", "Duelist", "Berserker", "Quasar", "Pulsar",
	"WallPilgrim", "WallMason", "WallBreaker", "Alchemist",
}

--=== 보호 구간: `` ` ``·[ ]·{ } 안은 다시 안 건드린다 ===--

local function protectedMask(text: string): { [number]: boolean }
	local mask = {}
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
				i = j + 1
			else
				i += 1
			end
		else
			i += 1
		end
	end

	-- "n분음표"는 음악 용어다. 뒤의 "분음표"뿐 아니라 앞에 붙은 숫자까지 보호한다.
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

--=== 맨 숫자를 { }로 감싼다 ===--

local SKIP_SUFFIX = { "스킬", "분음표" }
local SKIP_PREFIX = { "레벨" }

local function isWordByte(byte: number?): boolean
	if not byte then
		return false
	end
	return (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte >= 0x80
end

local function wrapNumbers(text: string): (string, number)
	local wrapped = 0
	local i = 1
	while i <= #text do
		local mask = protectedMask(text)
		local c = text:byte(i)
		local isSign = (c == 45 or (text:sub(i, i + 2) == "\226\136\146")) -- '-' 또는 U+2212
		local signLen = if c == 45 then 1 elseif isSign then 3 else 0
		local digitStart = i + signLen
		local isDigit = text:byte(digitStart) and text:byte(digitStart) >= 48 and text:byte(digitStart) <= 57

		if signLen > 0 and not isDigit then
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
				skip = true
			end
			for _, word in SKIP_SUFFIX do
				if text:sub(numEnd + 1, numEnd + #word) == word then
					skip = true
				end
			end
			for _, word in SKIP_PREFIX do
				if text:sub(numStart - #word, numStart - 1) == word
					or text:sub(numStart - #word - 1, numStart - 1) == word .. " " then
					skip = true
				end
			end

			if skip then
				i = numEnd + 1
			else
				local raw = text:sub(numStart, numEnd)
				text = text:sub(1, numStart - 1) .. "{" .. raw .. "}" .. text:sub(numEnd + 1)
				wrapped += 1
				i = numEnd + 3
			end
		else
			i += 1
		end
	end
	return text, wrapped
end

--=== 실행 ===--

local edits: { [string]: { Description: string } } = {}
local touchedCards, touchedNumbers, skippedScaling = 0, 0, 0

for _, classId in CLASSES do
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade) do
			if AbilityCardDefinitions.HasScaling(card) then
				skippedScaling += 1
				continue
			end
			local text, wrapped = wrapNumbers(card.Description)
			if wrapped > 0 then
				edits[card.Id] = { Description = text }
				touchedCards += 1
				touchedNumbers += wrapped
			end
		end
	end
end

print(string.format(
	"[brace_numbers] 카드 %d장 · 숫자 %d개 감쌈 · 사다리 있어 건너뜀 %d장",
	touchedCards, touchedNumbers, skippedScaling
))

if touchedCards == 0 then
	print("[brace_numbers] 고칠 것이 없습니다.")
	process.exit(0)
end

local editsPath = "config_edits_brace_numbers.json"
fs.writeFile(editsPath, serde.encode("json", { cards = edits }, true))
print("[brace_numbers] " .. editsPath .. " 에 썼습니다.")
print("[brace_numbers] 소스에 반영하려면: lune run tools/apply_config_edits.luau " .. editsPath)
