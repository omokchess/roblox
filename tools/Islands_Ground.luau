--!nocheck
--[[
	Islands_Ground.luau — 섬 아홉 개의 지반. Studio 커맨드 바에 통째로 붙여 실행한다.

	**400 격자를 버렸다.** 칸을 그대로 세우면 해안선도 경사도 전부 계단이 되고
	가장 작은 지형 단위가 사람 키의 80배가 된다. 사선도 곡선도 해변도 못 만든다.

	그래서 격자는 **설계도로만** 쓴다.
	  - 격자는 여전히 사람이 손으로 그린다. 글자 하나 = 400스터드, 점은 바다, 숫자는 고도
	  - 실제로 세울 때는 격자 사이를 보간해서 높이를 읽는다. 그래서 경사가 매끈하다
	  - 육지 여부도 보간한다. 그래서 해안선이 사선과 곡선으로 나온다
	  - 판은 150 간격으로 놓되 크기도 각도도 위치도 제각각이다. 줄이 서지 않는다

	블록 미학은 그대로다. 바뀐 것은 판이 격자에 정렬되지 않는다는 것뿐이다.
	파트는 전부 Anchored 이고 하나씩 고를 수 있다. Union 은 쓰지 않는다.

	**해변은 두 번에 나눠 만든다.**
	1차로 어디가 육지인지만 정하고, 2차로 **물까지의 실제 거리**를 재서 모래를 깐다.
	보간값으로 모래를 판정하면 안 된다. 그 값은 한 칸 400에 걸쳐 0에서 1로 변하므로
	모래띠가 170스터드밖에 안 나오고, 해안선이 칸을 비스듬히 가르는 곳에서는
	값이 껑충 뛰어 모래가 통째로 건너뛴다. 그게 이 빠진 해안선의 원인이었다.

	고도 5 이상은 지반으로 세우지 않는다. 산 자리 표시로만 쓰고
	실제 봉우리는 Islands_Mountains.luau 가 작은 블록으로 쌓는다.

	모티브 (실제 섬에서 가져왔다):
	  숲       야쿠시마      — 섬 전체가 하나의 산괴, 화강암 돔이 숲을 뚫는다
	  화산     산토리니      — 칼데라 고리 + 안쪽 석호 + 중앙 원뿔섬
	  탑의성역 하롱베이      — 평지에 석회암 탑이 수직으로 솟는다
	  설원     로포텐        — 바다에서 곧장 솟는 톱니 능선. 길고 좁다
	  사막     푸에르테벤투라 — 초승달. 모래언덕과 말파이스 용암밭
	  광산     밀로스        — 광물 색띠, 계단식 채석장, 물 찬 갱
	  늪지대   삼각주        — 수로로 갈린 낮은 뻘섬
	  평원     제주 해안평야  — 길쭉한 타원, 오름. 절화 자리는 평평
	  오염지대 야쿠시마의 변형 — 숲과 같은 계열인데 능선이 썩었다
]]

local CELL = 400 -- 설계도 한 글자가 덮는 거리
local PITCH = 150 -- 판을 놓는 간격. 지형의 최소 단위다
local SURF_T = 14 -- 표층 두께
local BOTTOM = -80 -- 몸통은 여기까지 꽉 찬다. 아래가 비면 안 된다
local WATER = 0.42 -- 보간값이 이보다 낮으면 바다다
local BEACH = 480 -- 모래띠 기본 폭. 스터드 단위다. 섬마다 beach 로 덮어쓴다
local DIP = 320 -- 물가에서 이 거리 안쪽은 높이가 물쪽으로 낮아진다
local SEEK = 6 -- 물을 찾을 때 뒤지는 격자 반경. 제일 넓은 모래띠보다 멀리 봐야 한다
local RGB = Color3.fromRGB
local M = Enum.Material

local ISL = {

	{ name = "평원", beach = 480, ax = -2000, az = 0, base = 6, step = 14, rockFrom = 3, peakFrom = 5,
	  surf = RGB(118, 152, 84), rock = RGB(146, 140, 124), mat = M.Grass, rmat = M.Rock,
	  g = {
		"..111112211....",
		".1111111112211.",
		"11111111123211.",
		"11111111122211.",
		".1111111112111.",
		".1111111111121.",
		".1111111111221.",
		"..221111111....",
	} },

	{ name = "숲", beach = 440, ax = -7200, az = -800, base = 14, step = 18, rockFrom = 9, peakFrom = 4,
	  surf = RGB(64, 96, 58), rock = RGB(150, 148, 140), mat = M.Grass, rmat = M.Rock,
	  g = {
		"....11111....",
		"..111111111..",
		".11111111111.",
		".11111121111.",
		"1111223221111",
		"1112243422111",
		"1122336332211",
		"1112243422111",
		"1111223221111",
		".11111111111.",
		".11111111111.",
		"..111111111..",
		"....11111....",
	} },

	{ name = "늪지대", beach = 0, ax = 4400, az = 1600, base = 2, step = 8, rockFrom = 4, peakFrom = 5,
	  surf = RGB(86, 84, 60), rock = RGB(104, 96, 82), mat = M.Mud, rmat = M.Slate,
	  g = {
		"...111.1111....",
		"..1111.111111..",
		".111111.111151.",
		".11.1111111111.",
		"111.1115111111.",
		"1111.111111.11.",
		".111.11111.111.",
		"..1111.11111.1.",
		"...111..1111...",
	} },

	{ name = "탑의성역", beach = 380, ax = -800, az = -6400, base = 24, step = 16, rockFrom = 3, peakFrom = 5,
	  surf = RGB(156, 158, 148), rock = RGB(206, 204, 190), mat = M.Slate, rmat = M.Limestone,
	  g = {
		"...11111...",
		".111111111.",
		".111111111.",
		"11111111111",
		"11112221111",
		"11112321111",
		"11112221111",
		"11111111111",
		".111111111.",
		".111111111.",
		"...11111...",
	} },

	{ name = "사막", beach = 600, ax = 5200, az = -3600, base = 20, step = 18, rockFrom = 3, peakFrom = 5,
	  surf = RGB(222, 196, 140), rock = RGB(92, 74, 66), mat = M.Sand, rmat = M.Basalt,
	  g = {
		".....1122111....",
		"...111222115111.",
		".1112253221111..",
		"1112233211111...",
		"1112521111......",
		".111111.........",
		"..111...........",
	} },

	{ name = "오염지대", beach = 0, ax = -10400, az = -6000, base = 8, step = 24, rockFrom = 4, peakFrom = 5,
	  surf = RGB(88, 72, 88), rock = RGB(48, 40, 52), mat = M.Ground, rmat = M.Slate,
	  g = {
		"...1122111...",
		".11223332211.",
		"1122344432211",
		"1123455432211",
		".123455443211",
		".12344433211.",
		"1123444321111",
		"112234432211.",
		".1223332211..",
		".1122221111..",
		"..111211111..",
		"....11111....",
	} },

	{ name = "설원", beach = 300, ax = -16000, az = -8800, base = 40, step = 30, rockFrom = 4, peakFrom = 5,
	  surf = RGB(232, 238, 244), rock = RGB(86, 88, 96), mat = M.Snow, rmat = M.Rock,
	  g = {
		"....1122211....1121.",
		"..1234567321..112331",
		".123456765432112456.",
		"1123455654321123451.",
		".11233432211..12321.",
		"...1122111.....111..",
	} },

	{ name = "화산", beach = 0, ax = -6000, az = -10800, base = 52, step = 26, rockFrom = 3, peakFrom = 5,
	  surf = RGB(62, 52, 50), rock = RGB(122, 58, 44), mat = M.Basalt, rmat = M.CrackedLava,
	  g = {
		"....34443....",
		"..345555433..",
		".34566.65443.",
		".456...65443.",
		"456.....6543.",
		"45..444..543.",
		"45..454..543.",
		".456...65443.",
		".34566.65443.",
		"..345555433..",
		"...3444433...",
		".....3433....",
	} },

	{ name = "광산", beach = 340, ax = 1600, az = -11200, base = 34, step = 22, rockFrom = 3, peakFrom = 5,
	  surf = RGB(120, 112, 100), rock = RGB(158, 128, 88), mat = M.Rock, rmat = M.Sandstone,
	  g = {
		"...222111...",
		".2333322211.",
		"234444333211",
		"234555433221",
		"23455.433211",
		"2345..432211",
		"234455433221",
		".23444332211",
		".2334332211.",
		"..22333211..",
	} },
}


-- 손으로 놓은 지협. 평원과 숲만 걸어서 오간다.
local BRIDGE = {
	{ x1 = -2700, z1 = 900, x2 = -1700, z2 = 1150, w = 340, base = 10 },
}

--=== 설계도 검사 ===--
-- 손으로 그린 그림이다. 줄 길이가 어긋나면 섬이 찢어지므로 먼저 잡는다.
for _, s in ipairs(ISL) do
	local w = #s.g[1]
	for r, row in ipairs(s.g) do
		assert(#row == w, s.name .. " " .. r .. "행 길이 " .. #row .. " (기준 " .. w .. ")")
	end
end
for _, s in ipairs(ISL) do
	assert((s.beach or BEACH) < SEEK * PITCH, s.name .. " 모래띠가 물을 찾는 범위보다 넓다. SEEK 를 올려라")
end

--=== 설계도 읽기 ===--
-- 격자 네 칸을 겹선형으로 섞는다. 이것 하나로 계단이 경사가 된다.
local function sample(s, x, z)
	local w, h = #s.g[1], #s.g
	local fc = (x - s.ax) / CELL
	local fr = (z - s.az) / CELL
	if fc < -1 or fr < -1 or fc > w or fr > h then
		return 0, 0
	end
	local c0, r0 = math.floor(fc), math.floor(fr)
	local tc, tr = fc - c0, fr - r0

	local function at(c, r)
		if c < 0 or r < 0 or c >= w or r >= h then
			return 0, 0
		end
		local ch = s.g[r + 1]:sub(c + 1, c + 1)
		if ch == "." then
			return 0, 0
		end
		return 1, math.min(tonumber(ch), s.peakFrom - 1)
	end

	local l00, t00 = at(c0, r0)
	local l10, t10 = at(c0 + 1, r0)
	local l01, t01 = at(c0, r0 + 1)
	local l11, t11 = at(c0 + 1, r0 + 1)

	local w00 = (1 - tc) * (1 - tr)
	local w10 = tc * (1 - tr)
	local w01 = (1 - tc) * tr
	local w11 = tc * tr

	-- 높이는 육지 칸끼리만 섞는다. 바다 칸을 0으로 끌어들이면 해안이 푹 꺼진다
	local lw = w00 * l00 + w10 * l10 + w01 * l01 + w11 * l11
	local tw = w00 * t00 * l00 + w10 * t10 * l10 + w01 * t01 * l01 + w11 * t11 * l11
	return lw, (lw > 0) and (tw / lw) or 0
end

--=== 세우기 ===--
local W = workspace.Surface.World
W:ClearAllChildren()

local seedRoot = workspace.Surface:FindFirstChild("_PeakSeeds")
if seedRoot then
	seedRoot:Destroy()
end
seedRoot = Instance.new("Folder")
seedRoot.Name = "_PeakSeeds"
seedRoot.Parent = workspace.Surface

local nPart, nSlab, nSeed, nSand = 0, 0, 0, 0
local report = {}

for _, s in ipairs(ISL) do
	local fold = Instance.new("Folder")
	fold.Name = "G_" .. s.name
	fold.Parent = W

	local w, h = #s.g[1], #s.g
	local rng = Random.new(s.ax * 31 + s.az * 17 + w)

	local nx = math.floor((w * CELL + 2 * CELL) / PITCH)
	local nz = math.floor((h * CELL + 2 * CELL) / PITCH)

	--- 1차: 육지냐 바다냐만 정한다 -----------------------------------------
	local pt = {}
	for ix = 0, nx do
		for iz = 0, nz do
			local gx = s.ax - CELL + ix * PITCH
			local gz = s.az - CELL + iz * PITCH
			-- 흔들림은 판 크기가 감당하는 만큼만.
			-- 판 한 장이 자기 중심에서 확실히 덮는 거리는 한 변의 절반이다.
			-- (간격의 절반 75) + 흔들림 이 그 값을 넘으면 이웃 사이에 구멍이 뚫린다.
			-- 0.34(=51)를 쓰다가 실제로 섬에 구멍이 났다. 0.12(=18)면 여유가 남는다
			local px = gx + rng:NextNumber(-PITCH * 0.12, PITCH * 0.12)
			local pz = gz + rng:NextNumber(-PITCH * 0.12, PITCH * 0.12)
			local L, tier = sample(s, px, pz)
			-- 해안선을 흐트러 놓는다. 보간만 하면 너무 매끈하다
			local wob = L + math.noise(px * 0.0035, pz * 0.0035, s.base) * 0.14
			if wob > WATER then
				pt[ix * 4096 + iz] = { px, pz, tier }
			end
		end
		task.wait()
	end

	--- 2차: 물까지의 거리를 재고 세운다 -------------------------------------
	local slabs = 0
	for key, v in pairs(pt) do
		local ix, iz = key // 4096, key % 4096
		local px, pz, tier = v[1], v[2], v[3]

		-- 제일 가까운 바다까지의 거리. 값이 아니라 실제 거리다
		local best = (SEEK + 1) * PITCH
		for dx = -SEEK, SEEK do
			for dz = -SEEK, SEEK do
				if not pt[(ix + dx) * 4096 + (iz + dz)] then
					local d = math.sqrt((dx * PITCH) ^ 2 + (dz * PITCH) ^ 2)
					if d < best then
						best = d
					end
				end
			end
		end

		-- 모래띠 폭은 섬마다 다르다. 늪지대와 화산에 백사장이 있으면 안 된다
		local bw = s.beach or BEACH
		local sand = (bw > 0) and (1 - math.clamp(best / bw, 0, 1)) or 0
		-- 높이가 물쪽으로 낮아지는 것은 모래가 없는 섬에도 필요하다. 따로 잰다
		local dip = 1 - math.clamp(best / DIP, 0, 1)
		local top = s.base + (tier - 1) * s.step
		top = top * (1 - dip) + (s.base - 18) * dip
		-- 흔들림은 1까지만. 3을 주면 옆 판과 6이 어긋나는데
		-- 캐릭터는 2까지만 저절로 올라가므로 그 턱에 전부 걸린다
		top += rng:NextNumber(-1, 1)

		local rocky = sand < 0.05 and tier >= s.rockFrom
		-- 최소 1.40배. 절반이 105 라 간격 절반 75 + 흔들림 18 을 넘는다
		local size = PITCH * rng:NextNumber(1.40, 1.80)
		local size2 = PITCH * rng:NextNumber(1.40, 1.80)
		local rot = rng:NextNumber(0, math.pi)

		local sc = rocky and s.rock or s.surf
		if sand > 0 then
			sc = sc:Lerp(RGB(228, 212, 172), math.min(sand * 1.6, 1))
		end
		local tintTo = (rng:NextNumber() < 0.5) and RGB(0, 0, 0) or RGB(255, 255, 255)
		sc = sc:Lerp(tintTo, rng:NextNumber(0, 0.06))

		local isSand = sand > 0.25
		if isSand then
			nSand += 1
		end

		local p = Instance.new("Part")
		p.Name = string.format("Gs_%s_%d_%d", s.name, math.floor(px), math.floor(pz))
		p.Anchored = true
		p.Size = Vector3.new(size, SURF_T, size2)
		p.CFrame = CFrame.new(px, top - SURF_T / 2, pz) * CFrame.Angles(0, rot, 0)
		p.Color = sc
		p.Material = isSand and M.Sand or (rocky and s.rmat or s.mat)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = fold
		nPart += 1

		-- 몸통. 표층 밑을 바닥까지 채운다
		local bh = (top - SURF_T) - BOTTOM
		local b = Instance.new("Part")
		b.Name = string.format("Gb_%s_%d_%d", s.name, math.floor(px), math.floor(pz))
		b.Anchored = true
		b.Size = Vector3.new(size * 0.96, bh, size2 * 0.96)
		b.CFrame = CFrame.new(px, top - SURF_T - bh / 2, pz) * CFrame.Angles(0, rot, 0)
		b.Color = s.rock:Lerp(RGB(40, 40, 44), 0.42)
		b.Material = M.Rock
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		b.Parent = fold
		nPart += 1
		slabs += 1

		if slabs % 150 == 0 then
			task.wait()
		end
	end

	-- 산 자리는 설계도에서 그대로 읽는다
	for r, row in ipairs(s.g) do
		for c = 1, #row do
			local ch = row:sub(c, c)
			if ch ~= "." and tonumber(ch) >= s.peakFrom then
				local m = Instance.new("Vector3Value")
				m.Name = s.name .. "|" .. (s.ax + (c - 1) * CELL) .. "|" .. (s.az + (r - 1) * CELL)
				m.Value = Vector3.new(s.base + (s.peakFrom - 2) * s.step, tonumber(ch), s.step)
				m.Parent = seedRoot
				nSeed += 1
			end
		end
	end

	nSlab += slabs
	report[#report + 1] = s.name .. "=" .. slabs
end

--=== 지협 ===--
local bfold = Instance.new("Folder")
bfold.Name = "G_지협"
bfold.Parent = W
local brng = Random.new(4242)
local nb = 0
for _, br in ipairs(BRIDGE) do
	local dx, dz = br.x2 - br.x1, br.z2 - br.z1
	local len = math.sqrt(dx * dx + dz * dz)
	local nrx, nrz = -dz / len, dx / len
	local steps = math.ceil(len / PITCH)
	for i = 0, steps do
		local t = i / steps
		local cx, cz = br.x1 + dx * t, br.z1 + dz * t
		local half = math.ceil(br.w / PITCH)
		for j = -half, half do
			local off = j * PITCH
			-- 가운데가 넓고 양끝이 좁아 섬에 자연스럽게 붙는다
			if math.abs(off) <= br.w * (0.55 + 0.45 * math.sin(t * math.pi)) then
				local px = cx + nrx * off + brng:NextNumber(-40, 40)
				local pz = cz + nrz * off + brng:NextNumber(-40, 40)
				local top = br.base + brng:NextNumber(-4, 4)
				local size = PITCH * brng:NextNumber(1.30, 1.70)
				local size2 = PITCH * brng:NextNumber(1.30, 1.70)
				local rot = brng:NextNumber(0, math.pi)

				local p = Instance.new("Part")
				p.Name = string.format("Gs_지협_%d_%d", math.floor(px), math.floor(pz))
				p.Anchored = true
				p.Size = Vector3.new(size, SURF_T, size2)
				p.CFrame = CFrame.new(px, top - SURF_T / 2, pz) * CFrame.Angles(0, rot, 0)
				p.Color = RGB(112, 138, 84):Lerp(RGB(210, 196, 162), brng:NextNumber(0, 0.5))
				p.Material = M.Grass
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.Parent = bfold

				local bh = (top - SURF_T) - BOTTOM
				local b = Instance.new("Part")
				b.Name = string.format("Gb_지협_%d_%d", math.floor(px), math.floor(pz))
				b.Anchored = true
				b.Size = Vector3.new(size * 0.96, bh, size2 * 0.96)
				b.CFrame = CFrame.new(px, top - SURF_T - bh / 2, pz) * CFrame.Angles(0, rot, 0)
				b.Color = RGB(78, 76, 72)
				b.Material = M.Rock
				b.TopSurface = Enum.SurfaceType.Smooth
				b.BottomSurface = Enum.SurfaceType.Smooth
				b.Parent = bfold
				nPart += 2
				nb += 1
			end
		end
	end
	task.wait()
end

--=== 자기검사 ===--
assert(nSeed > 0, "봉우리 자리가 하나도 없다. 설계도에 5 이상이 있어야 한다")
assert(nb > 0, "지협이 안 깔렸다. 평원과 숲이 끊긴다")
for _, s in ipairs(ISL) do
	local f = W:FindFirstChild("G_" .. s.name)
	assert(f and #f:GetChildren() > 40, s.name .. " 에 판이 거의 없다")
	-- 모래가 해안선 한 바퀴도 못 두르면 이가 빠진 것이다.
	-- 섬 하나 둘레가 판 간격 기준으로 대략 100장이다
	if (s.beach or BEACH) > 0 then
		local c = 0
		for _, p in ipairs(f:GetChildren()) do
			if p.Material == Enum.Material.Sand then
				c += 1
			end
		end
		assert(c > 90, s.name .. " 모래가 " .. c .. "장뿐이다. 해안선에 이가 빠졌다")
	end
end

print(
	string.format("[Islands_Ground] 판 %d장 %d파트 / 모래 %d장 / 지협 %d장 / 봉우리 자리 %d",
		nSlab, nPart, nSand, nb, nSeed)
)
print("[Islands_Ground] " .. table.concat(report, " "))
