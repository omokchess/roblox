--!strict
--[[
	AirshipRoute — 설원 비행선 항로(순수 계산, 로블록스 객체 없음 → tools/airship_route_test.luau 로 lune 시험).
	좌표는 {x, y, z} 표(스터드). 설원 광장 (-4933, -3818), 필드 대략 x -5400~-2600 · z -4200~-2000.
	항로 = 매인 자리 M → 뒤(+Z)로 BACK 만큼 물러남 → 높이 CLIMB_Y 까지 비스듬히 → 순항 점들 → 되돌아와 같은 길로 M.
	앞뒤 두 토막(물러남·오름 / 내림·들어옴)은 코 방향을 매인 방향으로 고정(lockedFirst/lockedLast), 가운데는 가는 쪽을 본다.
]]

local AirshipRoute = {}

export type P = { x: number, y: number, z: number }

AirshipRoute.COUNTDOWN = 10 -- 출발 누르고 문 닫기까지 초
AirshipRoute.DURATION = 120 -- 떠서 내릴 때까지 초(가속·감속 포함)
AirshipRoute.RAMP = 9 -- 가속·감속 초
AirshipRoute.BACK = 40 -- 매인 자리에서 뒤로 물러나는 길이
AirshipRoute.CLIMB_Y = 160 -- 순항 시작 높이(요구 150~220)
AirshipRoute.CLIMB_Z = 110 -- 올라가는 토막 끝이 매인 자리 뒤로 얼마나 떨어지는지
AirshipRoute.MAX_TURN = math.rad(25) -- 코 방향 돌림 최대 초당 각

-- 순항 점(월드 x, y, z). 마을 북쪽 광장 위 → 필드 동남 → 되돌아 서쪽 위
AirshipRoute.CRUISE = {
	{ x = -4600, y = 175, z = -3000 },
	{ x = -4000, y = 195, z = -2700 },
	{ x = -3400, y = 210, z = -2900 },
	{ x = -3200, y = 200, z = -3500 },
	{ x = -3600, y = 185, z = -4000 },
	{ x = -4300, y = 175, z = -4100 },
	{ x = -4933, y = 170, z = -3950 },
	{ x = -5300, y = 168, z = -3650 },
	{ x = -5250, y = 165, z = -3350 },
} :: { P }

-- 매인 자리 → 점 목록. 앞 두 토막·뒤 두 토막은 코 방향 고정.
function AirshipRoute.build(moor: P): ({ P }, number)
	local up = AirshipRoute.CLIMB_Y
	local climb = { x = moor.x, y = math.max(up, moor.y + 30), z = moor.z + AirshipRoute.CLIMB_Z }
	local out = {
		moor,
		{ x = moor.x, y = moor.y, z = moor.z + AirshipRoute.BACK },
		climb,
	}
	for _, p in AirshipRoute.CRUISE do
		table.insert(out, p)
	end
	table.insert(out, climb)
	table.insert(out, { x = moor.x, y = moor.y, z = moor.z + AirshipRoute.BACK })
	table.insert(out, moor)
	return out, 2 -- 두 번째 값: 앞뒤로 고정할 토막 수
end

function AirshipRoute.cumulative(points: { P }): ({ number }, number)
	local cum = { 0 }
	local total = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
		cum[i] = total
	end
	return cum, total
end

-- 사다리꼴 속도: 시각 t(0..T) → 간 비율(0..1). 앞 ramp 초 가속, 뒤 ramp 초 감속, 가운데 일정
function AirshipRoute.fraction(t: number, T: number, ramp: number): number
	if t <= 0 then
		return 0
	elseif t >= T then
		return 1
	end
	local v = 1 / (T - ramp)
	if t < ramp then
		return 0.5 * v * t * t / ramp
	elseif t <= T - ramp then
		return 0.5 * v * ramp + v * (t - ramp)
	end
	local r = T - t
	return 1 - 0.5 * v * r * r / ramp
end

-- 거리 s 에서의 위치·토막 번호(1..#points-1)·그 토막의 방향(정규화 안 함)
function AirshipRoute.sample(points: { P }, cum: { number }, s: number): (P, number, P)
	local n = #points
	local seg = n - 1
	for i = 2, n do
		if s <= cum[i] then
			seg = i - 1
			break
		end
	end
	local a, b = points[seg], points[seg + 1]
	local len = cum[seg + 1] - cum[seg]
	local f = if len > 1e-6 then math.clamp((s - cum[seg]) / len, 0, 1) else 0
	local pos = { x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f, z = a.z + (b.z - a.z) * f }
	return pos, seg, { x = b.x - a.x, y = b.y - a.y, z = b.z - a.z }
end

-- 앞(-Z)이 (dx, dz) 쪽을 보게 하는 CFrame.Angles(0, yaw, 0) 의 yaw
function AirshipRoute.yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

-- 각 cur 을 target 쪽으로 한 걸음(최대 maxStep, 짧은 쪽으로)
function AirshipRoute.stepAngle(cur: number, target: number, maxStep: number): number
	local d = (target - cur + math.pi) % (2 * math.pi) - math.pi
	return cur + math.clamp(d, -maxStep, maxStep)
end

-- 시각 t 의 위치·목표 코 방향(고정 토막이면 baseYaw)
function AirshipRoute.at(
	points: { P },
	cum: { number },
	total: number,
	locked: number,
	baseYaw: number,
	t: number
): (P, number)
	local s = AirshipRoute.fraction(t, AirshipRoute.DURATION, AirshipRoute.RAMP) * total
	local pos, seg, dir = AirshipRoute.sample(points, cum, s)
	local n = #points - 1
	local yaw = baseYaw
	if seg > locked and seg <= n - locked and (dir.x ~= 0 or dir.z ~= 0) then
		yaw = AirshipRoute.yawOf(dir.x, dir.z)
	end
	return pos, yaw
end

return AirshipRoute
