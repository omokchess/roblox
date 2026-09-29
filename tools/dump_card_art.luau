--[[
	dump_card_art.luau — `CardArt` 결과를 **압축 JSON**으로 뽑는다.

	`preview_card_art.luau`는 HTML 파일을 만드는데, 그 파일을 열어볼 수 없는 환경도
	있다. 그때는 이걸로 데이터만 받아 다른 곳(채팅 위젯 등)에서 그리면 된다.

	도형 하나를 **배열**로 낸다 — 키 이름을 반복하지 않아 크기가 3분의 1로 줄어든다.
	  [x, y, w, h, rotation, color, corner, stroke, zIndex, alpha]

	  lune run tools/dump_card_art.luau [직업1,직업2,...]
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

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

local CardArt = loadShared("CardArt")
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
loadShared("AbilityCards/init").Register()

-- 색을 #rrggbb로. JSON에서 가장 짧은 표현이다.
local function hex(color: any): string
	return string.format(
		"#%02x%02x%02x",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

-- 소수점 3자리까지만. 그 이상은 화면에서 차이가 없고 크기만 키운다.
local function num(value: number): string
	return string.format("%.3f", value):gsub("%.?0+$", "")
end

local function jsonString(text: string): string
	return '"' .. text:gsub('[\\"]', "\\%0") .. '"'
end

local requested = process.args[1]
local CLASSES = {}
if requested and requested ~= "" then
	for name in requested:gmatch("[^,]+") do
		table.insert(CLASSES, name)
	end
else
	CLASSES = { "Musician", "Duelist", "Alchemist" }
end

local cards = {}
for _, classId in CLASSES do
	for _, grade in { "Essential", "Rare", "Common" } do
		local pool = AbilityCardDefinitions.GetPool(classId, grade)
		local card = pool[1]
		if card then
			local art = CardArt.For(card)
			local shapes = {}
			for _, item in art.Shapes do
				table.insert(
					shapes,
					string.format(
						"[%s,%s,%s,%s,%s,%s,%s,%s,%d,%s]",
						num(item.X),
						num(item.Y),
						num(item.W),
						num(item.H),
						num(item.Rotation),
						jsonString(hex(item.Color)),
						num(item.Corner),
						num(item.Stroke),
						item.ZIndex,
						num(1 - item.Transparency)
					)
				)
			end
			table.insert(
				cards,
				string.format(
					'{"n":%s,"g":%s,"c":%s,"t":%s,"bg":%s,"s":[%s]}',
					jsonString(card.Name),
					jsonString(grade),
					jsonString(classId),
					jsonString(table.concat(card.Tags, "/")),
					jsonString(hex(art.Background)),
					table.concat(shapes, ",")
				)
			)
		end
	end
end

print("[" .. table.concat(cards, ",") .. "]")
