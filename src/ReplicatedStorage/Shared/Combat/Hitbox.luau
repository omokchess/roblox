--!strict
-- 히트박스 판정 (순수 수학 — 서버 판정 / 클라이언트 예측 / 테스트 공용)
-- 대상은 반지름 r 의 구(몸통 중심)로 근사한다.

local Hitbox = {}

export type Shape = {
	Shape: string,
	Range: number?,
	Angle: number?,
	Height: number?,
	Size: Vector3?,
	Radius: number?,
	Length: number?,
	Width: number?,
	Offset: Vector3?,
}

local function arc(shape: Shape, origin: CFrame, p: Vector3, r: number): boolean
	local lp = origin:PointToObjectSpace(p) - (shape.Offset or Vector3.zero)
	local h = shape.Height or 6
	if math.abs(lp.Y) > h / 2 + r then
		return false
	end
	local d = math.sqrt(lp.X * lp.X + lp.Z * lp.Z)
	local range = shape.Range or 6
	if d > range + r then
		return false
	end
	if d <= r then
		return true
	end
	local ang = math.deg(math.atan2(lp.X, -lp.Z)) -- 0 = 정면
	local half = (shape.Angle or 90) / 2 + math.deg(math.asin(math.min(1, r / d)))
	return math.abs(ang) <= half
end

local function box(shape: Shape, origin: CFrame, p: Vector3, r: number): boolean
	local size = shape.Size or Vector3.new(4, 4, 4)
	local lp = origin:PointToObjectSpace(p) - (shape.Offset or Vector3.zero)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local cx = math.clamp(lp.X, -hx, hx)
	local cy = math.clamp(lp.Y, -hy, hy)
	local cz = math.clamp(lp.Z, -hz, hz)
	local dx, dy, dz = lp.X - cx, lp.Y - cy, lp.Z - cz
	return dx * dx + dy * dy + dz * dz <= r * r
end

local function sphere(shape: Shape, origin: CFrame, p: Vector3, r: number): boolean
	local c = origin:PointToWorldSpace(shape.Offset or Vector3.zero)
	local R = (shape.Radius or 5) + r
	return (p - c).Magnitude <= R
end

local function line(shape: Shape, origin: CFrame, p: Vector3, r: number): boolean
	local lp = origin:PointToObjectSpace(p) - (shape.Offset or Vector3.zero)
	local L = shape.Length or 8
	-- 선분: (0,0,0) → (0,0,-L)
	local t = math.clamp(-lp.Z, 0, L)
	local dx, dy, dz = lp.X, lp.Y, lp.Z + t
	local w = (shape.Width or 2) / 2 + r
	-- 세로 방향은 조금 더 관대하게 (키 차이)
	return dx * dx + (dy * 0.6) * (dy * 0.6) + dz * dz <= w * w
end

local TESTS: { [string]: (Shape, CFrame, Vector3, number) -> boolean } = {
	Arc = arc,
	Box = box,
	Sphere = sphere,
	Line = line,
}

function Hitbox.Test(shape: Shape, origin: CFrame, targetPos: Vector3, targetRadius: number, slack: number?): boolean
	local fn = TESTS[shape.Shape]
	if not fn then
		return false
	end
	return fn(shape, origin, targetPos, targetRadius * (slack or 1))
end

-- 대략적인 도달 거리 (후보 추리기/AI 사거리 판단용)
function Hitbox.Reach(shape: Shape): number
	local off = shape.Offset and shape.Offset.Magnitude or 0
	if shape.Shape == "Arc" then
		return (shape.Range or 6) + off
	elseif shape.Shape == "Box" then
		local s = shape.Size or Vector3.new(4, 4, 4)
		return s.Magnitude / 2 + off
	elseif shape.Shape == "Sphere" then
		return (shape.Radius or 5) + off
	elseif shape.Shape == "Line" then
		return (shape.Length or 8) + off
	end
	return 10
end

return Hitbox
