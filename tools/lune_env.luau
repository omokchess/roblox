--[[
	lune_env.luau — Lune 에서 src/shared 모듈을 require 하는 로더(card_sim·run_system_tests 와 같은 것).
	다른 Lune 도구가 `local loadShared = require("./lune_env")` 로 쓴다. (2026-09-29)
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SHARED = "src/shared/"
WARNINGS = {} :: { string }

--=== Roblox 전역 최소 구현 ===--

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r: number, g: number, b: number)
	return { R = r, G = g, B = b }
end

-- 결정적 선형 합동 생성기. Roblox Random의 인터페이스만 흉내낸다.
local Random = {}
Random.__index = Random
function Random.new(seed: number)
	return setmetatable({ state = (math.floor(seed) % 2147483647 + 2147483647) % 2147483647 + 1 }, Random)
end
function Random:_next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min: number?, max: number?): number
	local value = self:_next()
	if min and max then
		return min + value * (max - min)
	end
	return value
end
function Random:NextInteger(min: number, max: number): number
	return math.floor(min + self:_next() * (max - min + 1) - 1e-12)
end

--=== 모듈 로더 ===--
-- src/shared의 .luau를 읽어 script.Parent 방식 require를 해석해준다.

-- fs.readFile은 비동기라 메타메서드(__index) 안에서 부를 수 없다.
-- 그래서 shared의 모든 소스를 **하위 폴더까지** 미리 읽어 둔다.
--   src/shared/Foo.luau            → 키 "Foo"
--   src/shared/AbilityCards/Bar.luau → 키 "AbilityCards/Bar"
-- (Rojo가 폴더를 Folder 인스턴스로 만들기 때문에 트리를 그대로 흉내낸다)
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

-- 경로 하나를 나타내는 프록시. 인덱싱하면 하위 모듈이나 하위 폴더를 돌려준다.
function makeProxy(prefix: string, parent: any): any
	return setmetatable({}, {
		__index = function(_, name: string)
			-- script.Parent.Parent 같은 상위 참조
			if name == "Parent" and parent ~= nil then
				return parent
			end

			local full = if prefix == "" then name else prefix .. "/" .. name
			if sources[full] then
				return loadShared(full)
			end
			-- Rojo는 init.luau가 있는 폴더를 ModuleScript로 바꾼다.
			-- 즉 Shared.AbilityCards 는 폴더가 아니라 그 init 모듈이다.
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
	-- Lune 환경에 없는 전역 보강
	env.math = math
	env.table = table
	env.string = string
	env.warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(WARNINGS, table.concat(parts, " "))
	end
	env.Color3 = Color3
	env.Random = Random
	-- script.Parent.X 를 해석한다. 하위 폴더에 있는 모듈은
	-- script.Parent      = 그 폴더
	-- script.Parent.Parent = Shared
	-- 가 되도록 프록시를 엮는다.
	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")

	if leaf == "init" and dir then
		-- init 모듈은 자기 폴더가 곧 자신이다.
		--   script.KnightCards → 같은 폴더의 형제 모듈
		--   script.Parent      → 폴더의 상위 (보통 Shared)
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

	local chunk = luau.load(source, {
		debugName = name,
		environment = env,
	})

	local result = chunk()
	cache[name] = result
	return result
end

--=== 시뮬레이션 ===--

return loadShared
