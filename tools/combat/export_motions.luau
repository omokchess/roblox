--[[
	export_motions.luau — 전투 모션·무기 자료를 JSON 으로 뽑는다(블렌더 미리보기용). (2026-09-28)

	Roblox 식 require(script.Parent.X) 를 쓰는 모듈을 Lune 에서 읽으려고, 파일을 직접 읽어
	`script`·`require` 를 흉내 낸 환경으로 불러온다.
	돌리는 법: lune run tools/combat/export_motions.luau  → tools/combat/out/motions.json, weapons.json
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local ROOT = "src/shared/Combat/"
local cache = {}

local function load(path: string)
	if cache[path] then
		return cache[path]
	end
	local source = fs.readFile(path)
	-- script 흉내: __path 를 가진 마디. .Parent 는 위 폴더, 다른 이름은 그 아래 자식
	local function node(p: string)
		return setmetatable({ __path = p }, {
			__index = function(_, key)
				if key == "Parent" then
					return node(string.match(p, "^(.*)/[^/]+$") or p)
				end
				return node(p .. "/" .. key)
			end,
		})
	end
	local selfPath = string.gsub(path, "%.luau$", "")
	selfPath = string.gsub(selfPath, "/init$", "")
	local env = setmetatable({
		script = node(selfPath),
		require = function(target)
			if type(target) == "table" and rawget(target, "__path") then
				local p = rawget(target, "__path")
				if fs.isFile(p .. ".luau") then
					return load(p .. ".luau")
				end
				return load(p .. "/init.luau")
			end
			return require(target)
		end,
		game = setmetatable({}, {
			__index = function()
				error("game 은 쓸 수 없다: " .. path)
			end,
		}),
	}, { __index = _G })
	local fn = luau.load(luau.compile(source), { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

local function strip(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		if k ~= "_c" and type(x) ~= "function" then
			out[k] = strip(x)
		end
	end
	return out
end

fs.writeDir("tools/combat/out")
local motions = load(ROOT .. "CombatMotions.luau")
fs.writeFile("tools/combat/out/motions.json", serde.encode("json", strip(motions.Sets), false))
local weapons = load(ROOT .. "WeaponDefinitions.luau")
fs.writeFile("tools/combat/out/weapons.json", serde.encode("json", strip(weapons.All()), false))
print("모션·무기 JSON 을 썼다")
