--!strict
-- 수학 유틸 (순수 함수 — 서버/클라이언트/테스트 공용)

local MathUtil = {}

function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathUtil.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function MathUtil.smoothstep(e0: number, e1: number, x: number): number
	if e1 == e0 then
		return if x >= e0 then 1 else 0
	end
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 지수 감쇠 보간 계수 (프레임 독립)
function MathUtil.damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function MathUtil.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MathUtil.flatUnit(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-6 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

-- 두 벡터 사이 각도(도), 수평면 기준
function MathUtil.flatAngle(a: Vector3, b: Vector3): number
	local fa, fb = MathUtil.flatUnit(a), MathUtil.flatUnit(b)
	return math.deg(math.acos(math.clamp(fa:Dot(fb), -1, 1)))
end

function MathUtil.ease(style: string?, t: number): number
	t = math.clamp(t, 0, 1)
	if style == "Out" then
		return 1 - (1 - t) ^ 3
	elseif style == "In" then
		return t * t * t
	elseif style == "InOut" then
		return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
	elseif style == "Back" then
		local c1, c3 = 1.70158, 2.70158
		return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
	elseif style == "Linear" then
		return t
	end
	return t * t * (3 - 2 * t)
end

-- 가중 무작위 선택: { {weight, value}, ... }
function MathUtil.weightedPick<T>(items: { { w: number, v: T } }, rng: Random?): T?
	local total = 0
	for _, it in items do
		total += math.max(0, it.w)
	end
	if total <= 0 then
		return nil
	end
	local r = (if rng then rng:NextNumber() else math.random()) * total
	for _, it in items do
		r -= math.max(0, it.w)
		if r <= 0 then
			return it.v
		end
	end
	return items[#items].v
end

return MathUtil
