--[[
	dump_cards.luau — 카드 전부(글·사다리·레벨별 설명·효과 연결 여부)를 JSON 으로 뽑는다.

	`CardArt`는 Roblox 인스턴스가 아니라 **도형 목록**을 돌려주므로, Studio를 켜지
	않고도 그대로 그려 볼 수 있다. 문양을 손볼 때마다 게임을 켜는 대신 이걸 열면 된다.

	  lune run tools/preview_card_art.luau [출력경로.html] [모드] [크기]
	    모드  sample(기본: 직업·등급마다 2장) | all(306장 전부) | art(손그림 있는 카드만)
	          | 직업 Id(그 직업 전부) | ids=카드Id,카드Id
	    크기  그림 한 변 픽셀(기본 150)

	Roblox와 CSS의 대응
	  AnchorPoint(0.5, 0.5)  → transform: translate(-50%, -50%)
	  Rotation(도)            → rotate(...deg)
	  UICorner(Scale)         → border-radius = Scale * min(폭, 높이)
	                            (로블록스의 Scale은 짧은 변 기준이다)

	**주의 — 잘림은 이 미리보기로 검증되지 않는다.**
	CSS `overflow:hidden`은 회전한 요소도 자르지만, 로블록스의 `ClipsDescendants`는
	**회전한 자손을 자르지 않는다.** 그래서 여기서 멀쩡해 보여도 게임에서는 문양이
	카드 밖으로 새어 나갈 수 있다(실제로 한 번 그랬다). 게임 쪽은 CanvasGroup으로
	해결했으니, 경계를 넘는 도형을 새로 넣을 때는 Studio에서 눈으로 확인할 것.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SHARED = "src/shared/"
local CARD_PIXELS = tonumber(process.args[3]) or 150
local MODE = process.args[2] or "sample"

--=== Roblox 전역 최소 구현 (run_system_tests와 같은 방식) ===--

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

readTree(SHARED, "")

local cache: { [string]: any } = {}
local loadShared
local makeProxy

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
			error("shared 모듈을 찾을 수 없습니다: " .. full)
		end,
	})
end

local sharedProxy = makeProxy("", nil)

function loadShared(name: string): any
	if cache[name] then
		return cache[name]
	end
	local source = sources[name]
	if not source then
		error("shared 모듈을 찾을 수 없습니다: " .. name)
	end

	local env: any = {}
	for key, value in (getfenv and getfenv(1) or _G) :: any do
		env[key] = value
	end
	env.math = math
	env.table = table
	env.string = string
	env.warn = function() end
	env.Color3 = Color3

	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")
	if leaf == "init" and dir then
		local grandDir = dir:match("^(.*)/[^/]+$")
		local outer = if grandDir then makeProxy(grandDir, sharedProxy) else sharedProxy
		env.script = makeProxy(dir, outer)
	else
		local parentProxy = if dir then makeProxy(dir, sharedProxy) else sharedProxy
		env.script = { Parent = parentProxy }
	end
	env.require = function(target: any)
		return target
	end

	local chunk = luau.load(source, { debugName = name, environment = env })
	local result = chunk()
	cache[name] = result
	return result
end

--=== 카드 전부를 JSON 으로 ===--
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
local CardEffects = loadShared("CardEffects/init")
loadShared("AbilityCards/init").Register()
local serde = require("@lune/serde")
local out = {}
for _, classId in { "Musician", "Duelist", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" } do
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade) do
			local max = AbilityCardDefinitions.MaxLevelFor(card)
			table.insert(out, {
				Id = card.Id, Name = card.Name, Grade = card.Grade, ClassId = classId, Tags = card.Tags, Art = card.Art,
				MaxLevel = max, Raw = card.Description, Levels = card.Levels, LevelKeywords = card.LevelKeywords,
				L1 = AbilityCardDefinitions.Describe(card, 1), LMax = AbilityCardDefinitions.Describe(card, max),
				Wired = CardEffects.IsWired(card.Id),
			})
		end
	end
end
fs.writeFile(process.args[1] or "cards_dump.json", serde.encode("json", out, true))
print("[dump_cards] " .. #out)
