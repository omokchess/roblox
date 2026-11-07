--[[ roblox_api_selftest.luau — 검사기가 실제로 잡는지 확인(2026-11-07). lune run tools/roblox_api_selftest.luau ]]
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local ApiCheck = require("./roblox_api")

local env: any = { Instance = { new = function(c) ApiCheck.checkClass(c) return roblox.Instance.new(c) end }, typeof = typeof, pcall = pcall }
ApiCheck.apply(env, roblox)

local function bad(name: string, code: string)
	local fn = luau.load(luau.compile(ApiCheck.rewrite(code)), { debugName = name, environment = env })
	local ok, err = pcall(fn)
	assert(not ok, "잡지 못함: " .. name)
	print("잡음 " .. name .. " — " .. tostring(err):match("^[^\n]*"))
end
local function good(name: string, code: string)
	local fn = luau.load(luau.compile(ApiCheck.rewrite(code)), { debugName = name, environment = env })
	fn()
end

bad("클래스", [[Instance.new("Fooo")]])
bad("NotCreatable", [[Instance.new("BasePart")]])
bad("없는 속성", [[local s = Instance.new("UIStroke")
s.LineJoin = Enum.LineJoinMode.Round]])
bad("ReadOnly", [[local p = Instance.new("Part")
p.Mass = 3]])
bad("동적 키", [[local p = Instance.new("Part")
local k = "Nope"
p[k] = 1]])
bad("Enum", [[local x = Enum.Material.Foo]])
bad("Enum2", [[local x = Enum.Foo]])
bad("NumberRange", [[local x = NumberRange.new(5, 1)]])
bad("키프레임", [[local x = NumberSequenceKeypoint.new(1.5, 1)]])
bad("시퀀스 끝", [[local x = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1) })]])
good("정상", [[local s = Instance.new("UIStroke")
s.LineJoinMode = Enum.LineJoinMode.Round
s.Thickness = 2
local p = Instance.new("Part")
p.Anchored = true
local r = NumberRange.new(1, 5)
local q = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
local t = {}
t.Foo = 1
t["x"] = 2]])
print("selftest 통과")
