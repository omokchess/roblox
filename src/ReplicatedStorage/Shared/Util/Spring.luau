--!strict
-- 임계 감쇠 스프링 (카메라 흔들림, UI 보간)

export type Spring = {
	Position: number,
	Velocity: number,
	Target: number,
	Speed: number,
	Damping: number,
	Impulse: (self: Spring, v: number) -> (),
	Step: (self: Spring, dt: number) -> number,
}

local Spring = {}
Spring.__index = Spring

function Spring.new(initial: number?, speed: number?, damping: number?): Spring
	local self = {
		Position = initial or 0,
		Velocity = 0,
		Target = initial or 0,
		Speed = speed or 12,
		Damping = damping or 0.6,
	}
	return (setmetatable(self, Spring) :: any) :: Spring
end

function Spring.Impulse(self: Spring, v: number)
	self.Velocity += v
end

function Spring.Step(self: Spring, dt: number): number
	-- 반-암시적 오일러 (dt 를 잘게 나눠 안정성 확보)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local k = self.Speed * self.Speed
		local c = 2 * self.Damping * self.Speed
		local a = k * (self.Target - self.Position) - c * self.Velocity
		self.Velocity += a * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

return Spring
