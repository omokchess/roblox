--!nocheck
--[[
	TerrainSample.luau — 물방울 침식 지형 샘플. Studio 커맨드 바에서 실행.

	Gaea가 하는 일(다중 옥타브 노이즈 + 수력 침식)을 코드로 한다.
	결과를 32스터드 블록·8스터드 단차로 계단화해 블록 월드로 세운다.

	**기존 맵을 건드리지 않는다.** 미착공인 오염지대 셀에 세우고,
	되돌리기는 workspace._TerrainSample:Destroy() 한 줄.

	평원(0,1600)이 바로 옆이라 경계에 서면 평평한 판과 침식 지형이 나란히 보인다.
]]

--=== 설정 ===--
local ZONE_X, ZONE_Z = -1600, 1600 -- 오염지대 셀 중심 (미착공)
local CELL = 1600
local BLOCK = 32 -- 블록 한 변
local STEP = 8 -- 높이 계단 단위
local LO, HI = 0, 80 -- 고도 범위. 평원 0~60 과 비교 가능한 값
local BASE_Y = -40 -- 기둥 바닥

local N = 128 -- 시뮬 격자 한 변
local DROPLETS = 30000
local SEED = 20260910

-- 물방울 침식 파라미터
local INERTIA = 0.05
local CAPACITY = 4
local MIN_CAPACITY = 0.01
local ERODE = 0.3
local DEPOSIT = 0.3
local EVAPORATE = 0.012
local GRAVITY = 4
local LIFETIME = 30
local RADIUS = 2

-- 평원 팔레트로 세운다. 같은 재질에 형태만 달라야 비교가 된다.
local C_LOW = Color3.fromRGB(74, 110, 62) -- 골짜기 짙은 풀
local C_HIGH = Color3.fromRGB(126, 160, 92) -- 능선 밝은 풀
local C_ROCK = Color3.fromRGB(120, 112, 96) -- 급경사 노출 암반
local SLOPE_ROCK = 0.055 -- 이 기울기 넘으면 암반색

--=== 1. 기반 노이즈 ===--
local H = table.create(N * N, 0)

local function fbm(x, z)
	local sum, amp, f, norm = 0, 1, 1, 0
	for _ = 1, 5 do
		sum += math.noise(x * f, z * f, SEED) * amp
		norm += amp
		amp *= 0.5
		f *= 2
	end
	return sum / norm -- 대략 -0.5 ~ 0.5
end

for gz = 0, N - 1 do
	for gx = 0, N - 1 do
		local h = fbm(gx / N * 3.5, gz / N * 3.5) + 0.5
		H[gz * N + gx + 1] = math.clamp(h, 0, 1)
	end
end

local preMin, preMax = math.huge, -math.huge
for _, v in ipairs(H) do
	preMin, preMax = math.min(preMin, v), math.max(preMax, v)
end

--=== 2. 침식 브러시 ===--
-- 한 점만 깎으면 뾰족한 자국이 남는다. 반경만큼 가중 분배한다.
local brush = {}
do
	local wsum = 0
	for dz = -RADIUS, RADIUS do
		for dx = -RADIUS, RADIUS do
			local d2 = dx * dx + dz * dz
			if d2 <= RADIUS * RADIUS then
				local w = 1 - math.sqrt(d2) / (RADIUS + 1)
				table.insert(brush, { dx, dz, w })
				wsum += w
			end
		end
	end
	for _, b in ipairs(brush) do
		b[3] /= wsum
	end
end

local function at(x, z)
	x = math.clamp(x, 0, N - 1)
	z = math.clamp(z, 0, N - 1)
	return H[z * N + x + 1]
end

-- 높이와 기울기를 이중선형으로 같이 구한다
local function heightGrad(px, pz)
	local x0, z0 = math.floor(px), math.floor(pz)
	local fx, fz = px - x0, pz - z0
	local h00, h10 = at(x0, z0), at(x0 + 1, z0)
	local h01, h11 = at(x0, z0 + 1), at(x0 + 1, z0 + 1)
	local gx = (h10 - h00) * (1 - fz) + (h11 - h01) * fz
	local gz = (h01 - h00) * (1 - fx) + (h11 - h10) * fx
	local h = h00 * (1 - fx) * (1 - fz) + h10 * fx * (1 - fz) + h01 * (1 - fx) * fz + h11 * fx * fz
	return h, gx, gz
end

local function addAt(px, pz, amount)
	local x0, z0 = math.floor(px), math.floor(pz)
	for _, b in ipairs(brush) do
		local x, z = x0 + b[1], z0 + b[2]
		if x >= 0 and x < N and z >= 0 and z < N then
			local i = z * N + x + 1
			H[i] = math.clamp(H[i] + amount * b[3], 0, 1)
		end
	end
end

--=== 3. 물방울 침식 ===--
local rng = Random.new(SEED)
local t0 = os.clock()

for d = 1, DROPLETS do
	local px, pz = rng:NextNumber(1, N - 2), rng:NextNumber(1, N - 2)
	local dx, dz = 0, 0
	local speed, water, sediment = 1, 1, 0

	for _ = 1, LIFETIME do
		local h, gx, gz = heightGrad(px, pz)

		dx = dx * INERTIA - gx * (1 - INERTIA)
		dz = dz * INERTIA - gz * (1 - INERTIA)
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 1e-6 then
			break
		end
		dx, dz = dx / len, dz / len

		local nx, nz = px + dx, pz + dz
		if nx < 1 or nx >= N - 1 or nz < 1 or nz >= N - 1 then
			break
		end

		local nh = heightGrad(nx, nz)
		local dh = nh - h

		local cap = math.max(-dh * speed * water * CAPACITY, MIN_CAPACITY)

		if sediment > cap or dh > 0 then
			-- 오르막이면 파낸 만큼만 되메워 구덩이를 막는다
			local amount = (dh > 0) and math.min(dh, sediment) or (sediment - cap) * DEPOSIT
			sediment -= amount
			addAt(px, pz, amount)
		else
			local amount = math.min((cap - sediment) * ERODE, -dh)
			sediment += amount
			addAt(px, pz, -amount)
		end

		speed = math.sqrt(math.max(0, speed * speed - dh * GRAVITY))
		water *= (1 - EVAPORATE)
		px, pz = nx, nz
	end

	if d % 4000 == 0 then
		task.wait()
	end
end

--=== 4. 자기검사 ===--
local postMin, postMax, diff = math.huge, -math.huge, 0
for i, v in ipairs(H) do
	assert(v == v, "NaN at " .. i)
	postMin, postMax = math.min(postMin, v), math.max(postMax, v)
	diff += math.abs(v - 0.5)
end
assert(postMin >= 0 and postMax <= 1, "높이가 0~1 범위를 벗어났다")
assert(postMax - postMin > 0.15, "기복이 거의 없다 — 침식 파라미터 확인")
print(
	string.format(
		"[TerrainSample] 침식 %d방울 %.1f초 / 높이 %.3f~%.3f (침식 전 %.3f~%.3f)",
		DROPLETS,
		os.clock() - t0,
		postMin,
		postMax,
		preMin,
		preMax
	)
)

--=== 5. 블록으로 세우기 ===--
local old = workspace:FindFirstChild("_TerrainSample")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "_TerrainSample"
root.Parent = workspace

local per = CELL // BLOCK -- 50
local originX, originZ = ZONE_X - CELL / 2, ZONE_Z - CELL / 2
local n, flat, cmp = 0, 0, 0
local tops = {}

for bz = 0, per - 1 do
	for bx = 0, per - 1 do
		local gx = (bx + 0.5) * BLOCK / CELL * N
		local gz = (bz + 0.5) * BLOCK / CELL * N
		local h01, sx, sz = heightGrad(gx, gz)

		local y = LO + h01 * (HI - LO)
		y = math.floor(y / STEP) * STEP -- 계단화
		tops[bz * per + bx] = y

		local slope = math.sqrt(sx * sx + sz * sz)
		local color
		if slope > SLOPE_ROCK then
			color = C_ROCK
		else
			color = C_LOW:Lerp(C_HIGH, h01)
		end

		local p = Instance.new("Part")
		p.Name = string.format("Smp_%d_%d", bx, bz)
		p.Anchored = true
		p.Material = Enum.Material.Grass
		p.Color = color
		p.Size = Vector3.new(BLOCK, y - BASE_Y, BLOCK)
		p.Position = Vector3.new(originX + (bx + 0.5) * BLOCK, (y + BASE_Y) / 2, originZ + (bz + 0.5) * BLOCK)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = root
		n += 1
	end
	task.wait() -- 한 줄씩 쌓이는 게 보이게
end

-- 평원과 같은 잣대로 재본다: 인접 기둥의 단차
local rough = 0
for bz = 0, per - 1 do
	for bx = 0, per - 2 do
		local a, b = tops[bz * per + bx], tops[bz * per + bx + 1]
		local d = math.abs(a - b)
		rough += d
		cmp += 1
		if d < 0.5 then
			flat += 1
		end
	end
end

print(
	string.format(
		"[TerrainSample] 블록 %d개 / 인접 단차 평균 %.1f / 단차0 비율 %.0f%%  (평원 실측: 2.5 / 79%%)",
		n,
		rough / cmp,
		flat / cmp * 100
	)
)
print("되돌리기: workspace._TerrainSample:Destroy()")
