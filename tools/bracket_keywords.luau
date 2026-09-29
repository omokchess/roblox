--[[
	bracket_keywords.luau — 카드 설명에 나온 낱말을 전부 `[ ]`로 감싼다.

	  lune run tools/bracket_keywords.luau
	  lune run tools/apply_config_edits.luau config_edits_bracket_keywords.json

	`Keywords.luau`에 있는 이름을 **긴 것부터** 찾아 감싼다. `` ` ``·`[ ]`·`{ }`
	안이나, 백틱으로 한 번이라도 나온 말(스킬 이름)의 다른 자리는 건드리지
	않는다 — `auto_bracket_edits.luau`의 낱말 규칙과 같다("16분음표"·"중독"에서
	잡았던 두 함정도 같이 막는다).

	숫자와 달리 `[낱말]`은 **순서가 의미를 갖지 않는다**(`Describe`는 이름으로
	찾지 자리로 찾지 않는다) — 그래서 이미 `Levels` 사다리가 있는 카드도 안심하고
	같이 감싼다.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

--=== Roblox 흉내 ===--

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

local CLASSES = {
	"Musician", "Duelist", "Berserker", "Quasar", "Pulsar",
	"WallPilgrim", "WallMason", "WallBreaker", "Alchemist",
}

local keywordList = {}
for _, keyword in Keywords.All() do
	table.insert(keywordList, keyword)
end
table.sort(keywordList, function(a, b)
	return #a.Name > #b.Name
end)

--=== 보호 구간 ===--

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

	-- 백틱으로 한 번이라도 나온 말은 그 글 안의 다른 자리도 통째로 보호한다.
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

	-- "n분음표"는 음악 용어다. "음표"가 [음표] 키워드와 우연히 겹친다.
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

local function wrapKeywords(text: string): (string, number)
	local wrapped = 0
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
				wrapped += 1
				search = e + 3
			end
		end
	end
	return text, wrapped
end

--=== 실행 ===--

local edits: { [string]: { Description: string } } = {}
local touchedCards, touchedWords = 0, 0

for _, classId in CLASSES do
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade) do
			local text, wrapped = wrapKeywords(card.Description)
			if wrapped > 0 then
				edits[card.Id] = { Description = text }
				touchedCards += 1
				touchedWords += wrapped
			end
		end
	end
end

print(string.format("[bracket_keywords] 카드 %d장 · 낱말 %d개 감쌈", touchedCards, touchedWords))

if touchedCards == 0 then
	print("[bracket_keywords] 고칠 것이 없습니다.")
	process.exit(0)
end

local editsPath = "config_edits_bracket_keywords.json"
fs.writeFile(editsPath, serde.encode("json", { cards = edits }, true))
print("[bracket_keywords] " .. editsPath .. " 에 썼습니다.")
print("[bracket_keywords] 소스에 반영하려면: lune run tools/apply_config_edits.luau " .. editsPath)
