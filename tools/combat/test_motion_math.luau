--[[
	test_motion_math.luau — MotionMath 의 섞기 규칙 검사. (2026-09-28)
	돌리는 법: lune run tools/combat/test_motion_math.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local MotionMath = luau.load(luau.compile(fs.readFile("src/shared/Combat/MotionMath.luau")), { debugName = "MotionMath" })()

local function near(a, b, msg)
	assert(math.abs(a - b) < 1e-3, string.format("%s: %s ~= %s", msg, tostring(a), tostring(b)))
end

-- 1) 섞기는 회전을 가까운 쪽으로: 372° → 12° 는 제자리
local a = MotionMath.Neutral()
a.Root = { 0, 0, 0, 0, 372, 0 }
local b = MotionMath.Neutral()
b.Root = { 0, 0, 0, 0, 12, 0 }
near(MotionMath.Blend(a, b, 0.5).Root[5], 372, "블렌드 한 바퀴 되감기")
-- 자리(1~3번)는 그대로 섞는다
a.Root = { 0, 2, 0, 0, 0, 0 }
b.Root = { 0, 0, 0, 0, 0, 0 }
near(MotionMath.Blend(a, b, 0.5).Root[2], 1, "블렌드 자리")

-- 2) 되풀이 이음새: 마지막 키 424° → 첫 키 64° 사이에서 되감지 않는다
local loop = MotionMath.Compile({
	Duration = 2,
	Loop = true,
	Keys = { { t = 0, W = { 0, 0, 0, 64, 0, 0 } }, { t = 1, W = { 0, 0, 0, 424, 0, 0 } } },
})
local mid = MotionMath.Sample(loop, 1.5).W[4]
assert(math.abs(((mid - 64) + 180) % 360 - 180) < 1e-3, "이음새에서 한 바퀴 되감음: " .. mid)

-- 3) 사람 관절 말고 다른 채널(슬라임 Body)도 이어 받는다
local slime = MotionMath.Compile({
	Duration = 1,
	Keys = { { t = 0, Body = { 10, -10, 10 } }, { t = 1, Root = { 0, 1, 0, 0, 0, 0 } } },
})
near(MotionMath.Sample(slime, 1).Body[2], -10, "Body 이어 받기")
near(MotionMath.Sample(slime, 0.5).Root[2], 0.5, "Root 보간")

print("MotionMath 검사 통과")
