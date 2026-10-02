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

-- 4) 무기 회전은 최단 호(slerp): 한 축만 돌면 선형과 같고, 180° 넘게 바뀌면 적힌 대로(칼 돌리기)
local function samp(w0, w1, t)
	return MotionMath.Sample(MotionMath.Compile({ Duration = 1, Keys = { { t = 0, W = w0 }, { t = 1, e = "linear", W = w1 } } }), t).W
end
near(samp({ 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 90, 0, 0 }, 0.5)[4], 45, "한 축 slerp")
near(samp({ 0, 0, 0, -120, 0, 0 }, { 0, 0, 0, -400, 0, 0 }, 0.5)[4], -260, "칼 돌리기는 오일러")
near(samp({ 0.2, 0, 0, 10, 0, 0 }, { 0.6, 0, 0, 10, 0, 0 }, 0.5)[1], 0.4, "무기 자리 보간")
-- 두 축이 함께 바뀌면: 결과 회전이 두 끝 사이 최단 호의 가운데(두 끝과 같은 각도만큼 떨어짐)
do
	local function R(v)
		local r = math.pi / 180
		local cx, sx, cy, sy, cz, sz = math.cos(v[4] * r), math.sin(v[4] * r), math.cos(v[5] * r), math.sin(v[5] * r), math.cos(v[6] * r), math.sin(v[6] * r)
		-- Rx·Ry·Rz 의 셋째 열(무기 +Z)과 둘째 열(+Y)
		return { sy, -sx * cy, cx * cy }, { -cy * sz, cx * cz - sx * sy * sz, sx * cz + cx * sy * sz }
	end
	local a, b = { 0, 0, 0, 20, -60, 30 }, { 0, 0, 0, 110, -5, -120 }
	local m = samp(a, b, 0.5)
	local function ang(p, q)
		local pz, py = R(p)
		local qz, qy = R(q)
		local d = (pz[1] * qz[1] + pz[2] * qz[2] + pz[3] * qz[3] + py[1] * qy[1] + py[2] * qy[2] + py[3] * qy[3]) / 2
		return d
	end
	near(ang(a, m), ang(m, b), "slerp 가운데")
	-- 짐벌(비틀기 90°) 끝에서도 회전이 맞는다
	local g0, g1 = { 0, 0, 0, -164, 90, 0 }, { 0, 0, 0, -70, 90, 0 }
	local gm = samp(g0, g1, 0.5)
	near(ang(g0, gm), ang(gm, g1), "짐벌 slerp 가운데")
end

-- 부드러운 되풀이(Smooth): 키를 그대로 지나되 키에서 멈추지 않고, 이음새(마지막 → 첫 키)도 이어진다
do
	local sm = MotionMath.Compile({
		Duration = 3,
		Loop = true,
		Smooth = true,
		Keys = { { t = 0, Torso = { 0, 0, 0 } }, { t = 1, Torso = { 10, 0, 0 } }, { t = 2, Torso = { 20, 0, 0 } } },
	})
	local function x(t)
		return MotionMath.Sample(sm, t).Torso[1]
	end
	near(x(1), 10, "Smooth 키 지남")
	near(x(3), x(0), "Smooth 한 바퀴")
	assert(x(1.01) - x(0.99) > 0.15, "Smooth 는 키에서 멈추지 않는다")
	assert(math.abs((x(3 - 1e-3) - x(3 - 2e-3)) - (x(1e-3) - x(0))) < 1e-2, "Smooth 이음새 속도 이어짐")
end

print("MotionMath 검사 통과")
