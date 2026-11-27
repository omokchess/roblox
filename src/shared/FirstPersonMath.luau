--!strict
-- 1인칭 카메라 순수 계산(Roblox 서비스 없음 — lune 시험용). 시험: tools/firstperson_test.luau

local FirstPersonMath = {}

-- 지수 감쇠: halfLife 초마다 남은 차이가 절반. dt 를 쪼개도 같은 시간 뒤 같은 값이 된다.
function FirstPersonMath.Smooth(current: number, target: number, dt: number, halfLife: number): number
	if halfLife <= 0 then
		return target
	end
	return current + (target - current) * (1 - 0.5 ^ (dt / halfLife))
end

function FirstPersonMath.ClampPitch(pitch: number, limit: number): number
	return math.clamp(pitch, -limit, limit)
end

return FirstPersonMath
