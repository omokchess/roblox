-- FirstPersonMath 시험. lune run tools/firstperson_test.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local src = fs.readFile("src/shared/FirstPersonMath.luau")
local M = luau.load(src)()
local function run(dt)
	local v, t = 0, 0
	while t < 1 - 1e-9 do
		v = M.Smooth(v, 1, dt, 0.07)
		t += dt
	end
	return v
end
local a, b, c = run(1 / 240), run(1 / 60), run(1 / 30)
assert(math.abs(a - b) < 1e-6 and math.abs(b - c) < 1e-6, "dt 달라도 같은 값")
assert(math.abs(M.Smooth(0, 1, 0.07, 0.07) - 0.5) < 1e-9, "반감 시간")
assert(M.Smooth(0, 1, 1, 0) == 1)
assert(M.ClampPitch(5, math.rad(80)) == math.rad(80) and M.ClampPitch(-5, math.rad(80)) == -math.rad(80))
print("firstperson_test OK")
