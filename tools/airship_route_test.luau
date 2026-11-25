-- airship_route_test.luau — src/shared/AirshipRoute.luau 순수 계산 시험. 실행: lune run tools/airship_route_test.luau
local R = require("../src/shared/AirshipRoute")

local fails = 0
local function check(ok: boolean, msg: string)
	if not ok then
		fails += 1
		print("FAIL " .. msg)
	end
end

local moor = { x = -4933, y = 114.7, z = -3627 }
local pts, locked = R.build(moor)
local cum, total = R.cumulative(pts)

-- 사다리꼴 속도: 양끝 0·1, 단조, 가운데 일정
check(R.fraction(0, 120, 9) == 0 and R.fraction(120, 120, 9) == 1, "fraction ends")
check(math.abs(R.fraction(60, 120, 9) - 0.5) < 1e-9, "fraction mid")
local prev = 0
for i = 1, 1200 do
	local f = R.fraction(i / 10, 120, 9)
	check(f >= prev, "fraction monotone")
	prev = f
end

-- 위치: 처음·끝 = 매인 자리, 순항 높이 150~220(올라가고 내려오는 토막 제외)
local p0 = R.at(pts, cum, total, locked, 0, 0)
local p1 = R.at(pts, cum, total, locked, 0, R.DURATION)
check(p0.x == moor.x and p0.y == moor.y and p0.z == moor.z, "start at moor")
check(math.abs(p1.x - moor.x) < 1e-6 and math.abs(p1.y - moor.y) < 1e-6 and math.abs(p1.z - moor.z) < 1e-6, "end at moor")
for _, p in R.CRUISE do
	check(p.y >= 150 and p.y <= 220, "cruise height")
end
check(R.CLIMB_Y >= 150 and R.CLIMB_Y <= 220, "climb height")

-- 최고 속도·한 걸음 위치 변화
local maxV, last = 0, p0
for i = 1, R.DURATION * 10 do
	local p = R.at(pts, cum, total, locked, 0, i / 10)
	local v = math.sqrt((p.x - last.x) ^ 2 + (p.y - last.y) ^ 2 + (p.z - last.z) ^ 2) * 10
	maxV = math.max(maxV, v)
	last = p
end
print(string.format("길이 %.0f 스터드, 최고 속도 %.1f 스터드/초, 시간 %d 초", total, maxV, R.DURATION))
check(R.DURATION >= 90 and R.DURATION <= 120, "duration 90~120")
check(maxV < 60, "max speed < 60")

-- 순항 점은 필드 범위 안
for _, p in R.CRUISE do
	check(p.x >= -5400 and p.x <= -2600 and p.z >= -4200 and p.z <= -2000, "cruise inside field")
end

-- 고정 토막: 앞 두 토막·뒤 두 토막은 baseYaw, 가운데는 가는 쪽
local _, yawStart = R.at(pts, cum, total, locked, 1.25, 1)
check(yawStart == 1.25, "locked start yaw")
local _, yawEnd = R.at(pts, cum, total, locked, 1.25, R.DURATION - 1)
check(yawEnd == 1.25, "locked end yaw")
local _, yawMid = R.at(pts, cum, total, locked, 1.25, R.DURATION / 2)
check(yawMid ~= 1.25, "free yaw mid")

-- 코 방향: 북(-Z)으로 가면 0, 동(+X)이면 -90도(앞 = -Z 가 +X 를 향함)
check(math.abs(R.yawOf(0, -1)) < 1e-9, "yaw north")
check(math.abs(R.yawOf(1, 0) + math.pi / 2) < 1e-9, "yaw east")

-- 각 한 걸음: 짧은 쪽으로, 최대치 제한
check(math.abs(R.stepAngle(3.0, -3.0, 0.1) - 3.1) < 1e-9, "step wraps short way")
check(math.abs(R.stepAngle(0, 0.05, 0.1) - 0.05) < 1e-9, "step reaches target")

if fails == 0 then
	print("OK airship_route_test")
else
	error(fails .. " failures")
end
