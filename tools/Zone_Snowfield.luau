--!nocheck
--[[
	Zone_Snowfield.luau — 설원 섬을 설원지대로 꾸민다.

	산은 접었다. 블록으로 오를 수 있는 산을 만들면 등산로가 산 표면을 다 먹어
	계단식 떡이 된다. 그래서 봉우리를 치우고 **지대**로 간다.

	설원 섬은 두 덩이가 가운데 띠로 이어진 모양이다. 실측값은 이렇다.
	  서쪽 덩이  x -15400..-11400   (z -8900..-6700)
	  동쪽 덩이  x -10600..-8400    (z -8900..-6700)
	  가운데 띠  z -8100..-7300     x -16200..-8400 로 이어짐

	**자리는 전부 아래 표에 손으로 적혀 있다.** 뿌리는 함수가 아니다.
	지물 하나하나의 생김새만 작은 제작기가 맡고, 어디에 무엇을 놓을지는 표다.

	놓는 것
	  눈 언덕        바람 방향(북동 25도)으로 누운 긴 둔덕
	  서리 바위      눈 모자를 쓴 화강암 무더기
	  빙주           비스듬히 솟은 얼음 기둥
	  설림           눈 쌓인 침엽수. 세 군데 숲
	  돌무지          길잡이. 나중에 웨이포인트 비석 자리

	되돌리기: workspace.Surface.Zone_설원:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local SNOW = RGB(240, 246, 250)
local SNOW_D = RGB(206, 218, 232)
local ICE = RGB(196, 226, 240)
local ROCK = RGB(96, 100, 110)
local ROCK_D = RGB(62, 66, 76)
local BARK = RGB(58, 48, 44)
local NEEDLE = RGB(44, 74, 60)

local WIND = math.rad(25) -- 바람이 부는 방향. 눈 언덕은 전부 이 결을 따른다

local S = workspace.Surface
local G = S.World["G_설원"]

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

local old = S:FindFirstChild("Zone_설원")
if old then
	old:Destroy()
end
local ROOT = Instance.new("Folder")
ROOT.Name = "Zone_설원"
ROOT.Parent = S

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = ROOT
	return f
end

local F_drift = folder("눈언덕")
local F_rock, F_spire = folder("서리바위"), folder("빙주")
local F_tree, F_cairn = folder("설림"), folder("돌무지")

local miss = {}
-- 그 자리 땅 높이. 바다면 nil 을 주고 목록에 적어 둔다
local function ground(x, z, tag)
	local h = workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -2000, 0), rp)
	if not h then
		miss[#miss + 1] = string.format("%s (%d, %d)", tag, x, z)
		return nil
	end
	return h.Position.Y
end

local n = 0
local function block(parent, name, cf, size, color, mat, tr)
	assert(size.X <= 400 and size.Y <= 400 and size.Z <= 400, name .. " 가 400 을 넘는다")
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Transparency = tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	n = n + 1
	return p
end

local rng = Random.new(90125)

--=== 지물 제작기 ===--
-- 표가 자리를 정하고, 여기서는 그 자리에 생김새만 만든다

-- 눈 언덕. 바람에 밀려 한쪽이 길게 늘어진 둔덕. 세 켜로 쌓아 모서리를 죽인다
local function drift(x, z, len, wid, hgt, yaw)
	local y = ground(x, z, "눈언덕")
	if not y then
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Drift_%d_%d", x, z)
	f.Parent = F_drift
	for i = 0, 2 do
		local t = i / 2
		local l = len * (1 - t * 0.42)
		local w = wid * (1 - t * 0.50)
		local h = hgt / 3
		local cf = CFrame.new(x - math.sin(yaw) * len * 0.06 * i, y + h * (i + 0.5) - 2, z + math.cos(yaw) * len * 0.06 * i)
			* CFrame.Angles(0, yaw, 0)
		block(f, "Snow_" .. i, cf, Vector3.new(l, h + 3, w), SNOW:Lerp(SNOW_D, 0.35 - t * 0.3), M.Snow)
	end
end

-- 서리 바위. 화강암 덩이 위에 눈이 얹힌다
local function boulder(x, z, s)
	local y = ground(x, z, "서리바위")
	if not y then
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Rock_%d_%d", x, z)
	f.Parent = F_rock
	local cnt = 3 + math.floor(rng:NextNumber(0, 2.9))
	for i = 1, cnt do
		local ox, oz = rng:NextNumber(-s * 0.7, s * 0.7), rng:NextNumber(-s * 0.7, s * 0.7)
		local w = s * rng:NextNumber(0.5, 1.0)
		local h = s * rng:NextNumber(0.45, 0.85)
		local yaw = rng:NextNumber(0, math.pi)
		block(f, "Stone_" .. i, CFrame.new(x + ox, y + h / 2 - 4, z + oz) * CFrame.Angles(0, yaw, 0),
			Vector3.new(w, h, w * rng:NextNumber(0.7, 1.1)), ROCK:Lerp(ROCK_D, rng:NextNumber(0, 0.7)), M.Granite)
		block(f, "Cap_" .. i, CFrame.new(x + ox, y + h - 2, z + oz) * CFrame.Angles(0, yaw, 0),
			Vector3.new(w * 0.92, 10, w * 0.72), SNOW, M.Snow)
	end
end

-- 빙주. 비스듬히 솟은 얼음 기둥. 밑동에 얼음 부스러기를 깐다
local function spire(x, z, h, tiltDeg, dir)
	local y = ground(x, z, "빙주")
	if not y then
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Spire_%d_%d", x, z)
	f.Parent = F_spire
	local tilt = math.rad(tiltDeg)
	local a = math.rad(dir)
	local seg = 3
	for i = 0, seg - 1 do
		local t = (i + 0.5) / seg
		local hh = h / seg
		local lean = math.sin(tilt) * h * t
		local cf = CFrame.new(x + math.cos(a) * lean, y + h * t - 6, z + math.sin(a) * lean)
			* CFrame.Angles(0, -a, tilt)
		local w = 58 * (1 - t * 0.55)
		block(f, "Ice_" .. i, cf, Vector3.new(w, hh + 8, w * 0.8), ICE, M.Ice, 0.1)
	end
	for i = 1, 4 do
		local ox, oz = rng:NextNumber(-70, 70), rng:NextNumber(-70, 70)
		block(f, "Chip_" .. i, CFrame.new(x + ox, y + 4, z + oz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(rng:NextNumber(28, 52), 16, rng:NextNumber(24, 44)), ICE, M.Ice, 0.15)
	end
end

-- 눈 쌓인 나무.
--
-- **한 가지 모양으로 다 찍으면 숲이 아니라 도장이다.** 앞선 판이 그랬다.
-- 그래서 다섯 가지로 나눈다. 종마다 키, 켜 수, 켜 폭, 줄기가 드러난 길이,
-- 눈 쌓인 정도가 다르다. 잎색도 셋 중 하나를 자리로 정해 고른다
local KIND = {
	["전"] = { h = 182, tiers = 5, w0 = 86, w1 = 26, bare = 0.24, snow = 1.00, lean = 2 }, -- 전나무. 좁고 높다
	["가"] = { h = 146, tiers = 4, w0 = 128, w1 = 50, bare = 0.14, snow = 1.35, lean = 3 }, -- 가문비. 넓고 눈이 무겁다
	["솔"] = { h = 176, tiers = 2, w0 = 132, w1 = 98, bare = 0.62, snow = 0.70, lean = 5 }, -- 소나무. 줄기가 길고 우듬지만 있다
	["묘"] = { h = 74, tiers = 3, w0 = 74, w1 = 24, bare = 0.18, snow = 1.55, lean = 8 }, -- 어린나무. 거의 눈덩이다
}
local NEEDLES = { RGB(44, 74, 60), RGB(34, 62, 66), RGB(60, 82, 48) }

local function deadTree(f, x, y, z, scale)
	local H = 150 * scale
	local grey = RGB(104, 96, 88)
	block(f, "Trunk", CFrame.new(x, y + H * 0.46, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-5, 5))),
		Vector3.new(15 * scale, H, 15 * scale), grey, M.Wood)
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local t = 0.45 + i * 0.11
		local len = (54 - i * 6) * scale
		block(f, "Branch_" .. i,
			CFrame.new(x + math.cos(a) * len * 0.5, y + H * t, z + math.sin(a) * len * 0.5)
				* CFrame.Angles(0, -a, math.rad(rng:NextNumber(20, 38))),
			Vector3.new(len, 9 * scale, 9 * scale), grey, M.Wood)
	end
	block(f, "SnowCap", CFrame.new(x, y + H * 0.97, z), Vector3.new(20 * scale, 8 * scale, 20 * scale), SNOW, M.Snow)
end

local function conifer(x, z, kind, scale)
	local y = ground(x, z, "설림")
	if not y then
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Tree_%s_%d_%d", kind, x, z)
	f.Parent = F_tree

	if kind == "고" then
		deadTree(f, x, y, z, scale)
		return
	end

	local k = KIND[kind]
	assert(k, "모르는 나무 종류 " .. tostring(kind))
	local H = k.h * scale
	local nd = NEEDLES[(math.abs(x // 100 + z // 70) % 3) + 1]
	local tilt = math.rad(rng:NextNumber(-k.lean, k.lean))
	local face = rng:NextNumber(0, math.pi * 2)
	local lean = CFrame.Angles(0, face, 0) * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, -face, 0)
	local function at(yy)
		return CFrame.new(x, y, z) * lean * CFrame.new(0, yy, 0)
	end

	block(f, "Trunk", at(H * 0.5) * CFrame.Angles(0, face, 0),
		Vector3.new(17 * scale, H, 17 * scale), BARK, M.Wood)

	local n0 = k.tiers - 1
	for i = 0, n0 do
		local t = n0 > 0 and i / n0 or 0
		local w = (k.w0 - (k.w0 - k.w1) * t) * scale
		local yy = H * (k.bare + (0.94 - k.bare) * t)
		local yaw = rng:NextNumber(0, math.pi)
		block(f, "Bough_" .. i, at(yy) * CFrame.Angles(0, yaw, 0),
			Vector3.new(w, (30 - 6 * t) * scale, w), nd, M.Grass)
		local sn = 9 * k.snow * scale
		block(f, "Snow_" .. i, at(yy + (15 - 3 * t) * scale) * CFrame.Angles(0, yaw, 0),
			Vector3.new(w * (0.88 + 0.08 * k.snow), sn, w * (0.88 + 0.08 * k.snow)), SNOW, M.Snow)
	end
	block(f, "Top", at(H * 0.99), Vector3.new(24 * scale, 34 * scale, 24 * scale), SNOW, M.Snow)
end

-- 돌무지. 길잡이 표식. 나중에 여기에 웨이포인트 비석을 세운다
local function cairn(x, z)
	local y = ground(x, z, "돌무지")
	if not y then
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Cairn_%d_%d", x, z)
	f.Parent = F_cairn
	local w = 96
	for i = 0, 4 do
		local t = i / 4
		local s = w * (1 - t * 0.62)
		block(f, "Stone_" .. i, CFrame.new(x, y + 16 + i * 26, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(s, 30, s * 0.85), ROCK:Lerp(ROCK_D, t * 0.6), M.Granite)
	end
	block(f, "Cap", CFrame.new(x, y + 16 + 5 * 26, z), Vector3.new(34, 22, 34), SNOW, M.Snow)
end

--=== 배치표 ===--
-- 전부 손으로 적은 자리다. 섬 실측 범위 안쪽으로만 적었다

-- 눈 언덕 { x, z, 길이, 폭, 높이, 방향도 }
local DRIFTS = {
	-- 서쪽 덩이 북쪽
	{ -14900, -8600, 300, 150, 46, 25 }, { -14300, -8500, 240, 130, 38, 18 },
	{ -13500, -8600, 330, 160, 52, 30 }, { -12700, -8500, 260, 140, 40, 22 },
	{ -12000, -8400, 220, 120, 34, 14 },
	-- 서호 둘레
	{ -14600, -7900, 280, 150, 44, 28 }, { -14500, -7400, 250, 130, 38, 20 },
	{ -12700, -7900, 300, 150, 48, 32 }, { -12600, -7400, 230, 120, 34, 24 },
	{ -13600, -7100, 340, 170, 54, 26 },
	-- 서쪽 덩이 남쪽
	{ -14800, -6950, 270, 140, 42, 16 }, { -13000, -6900, 240, 130, 36, 30 },
	{ -12400, -7050, 210, 110, 30, 20 },
	-- 가운데 띠
	{ -15600, -7700, 320, 160, 50, 25 }, { -15800, -7300, 250, 130, 38, 18 },
	{ -11600, -7800, 300, 150, 46, 28 }, { -11300, -7500, 260, 140, 40, 22 },
	{ -11000, -7900, 230, 120, 34, 16 },
	-- 동쪽 덩이
	{ -10300, -8500, 250, 130, 40, 24 }, { -9700, -8500, 290, 150, 46, 30 },
	{ -9000, -8400, 220, 120, 34, 18 }, { -8700, -8000, 260, 140, 42, 26 },
	{ -10200, -7200, 280, 150, 44, 20 }, { -9500, -7100, 240, 130, 36, 28 },
	{ -8900, -7000, 300, 160, 48, 22 }, { -8700, -7600, 230, 120, 34, 14 },
	{ -10000, -6850, 210, 110, 30, 26 },
}
for _, d in ipairs(DRIFTS) do
	drift(d[1], d[2], d[3], d[4], d[5], math.rad(d[6]))
end

-- 서리 바위 { x, z, 크기 }
local ROCKS = {
	{ -15200, -8200, 120 }, { -14100, -8750, 90 }, { -12300, -8700, 110 },
	{ -15500, -7500, 130 }, { -14900, -7100, 95 }, { -12200, -7700, 105 },
	{ -11800, -7200, 120 }, { -13200, -6800, 88 }, { -15900, -7900, 115 },
	{ -10700, -8200, 100 }, { -9200, -8700, 92 }, { -8600, -7300, 118 },
	{ -10150, -6900, 96 }, { -9800, -8100, 108 },
}
for _, r in ipairs(ROCKS) do
	boulder(r[1], r[2], r[3])
end

-- 빙주 { x, z, 높이, 기울기도, 기운 방향도 }
local SPIRES = {
	{ -14200, -7650, 260, 12, 40 }, { -13000, -8200, 300, 9, 200 },
	{ -12900, -7550, 230, 14, 320 }, { -14700, -8250, 280, 11, 120 },
	{ -14950, -6950, 210, 16, 60 }, { -11500, -8300, 250, 10, 260 },
	{ -10100, -7600, 270, 13, 150 }, { -9300, -8200, 220, 15, 20 },
	{ -8800, -7150, 240, 11, 300 },
}
for _, s in ipairs(SPIRES) do
	spire(s[1], s[2], s[3], s[4], s[5])
end

-- 설림 세 군데. { x, z, 종류, 크기 }
-- 종류 전=전나무 가=가문비 솔=소나무 묘=어린나무 고=고사목
-- 한 숲을 한 종으로 채우지 않는다. 고사목과 어린나무를 섞어야 숲이 산다
local TREES = {
	-- 숲 가 : 서쪽 덩이 남서
	{ -15000, -7250, "전", 1.0 }, { -14780, -7120, "가", 0.9 }, { -14820, -7420, "전", 1.1 },
	{ -14560, -7300, "묘", 0.95 }, { -14600, -6980, "가", 1.05 }, { -14330, -7180, "솔", 0.85 },
	{ -14380, -7470, "전", 1.0 }, { -14120, -7050, "고", 1.15 }, { -14100, -7350, "가", 0.9 },
	{ -13880, -7200, "전", 1.0 }, { -13860, -6920, "묘", 0.88 }, { -13640, -7380, "솔", 1.08 },
	{ -15200, -7080, "가", 0.92 }, { -15180, -7430, "전", 1.0 }, { -13500, -7080, "고", 0.95 },
	{ -13420, -7300, "전", 1.12 },
	-- 숲 나 : 서쪽 덩이 북동
	{ -12500, -8600, "가", 1.0 }, { -12280, -8450, "전", 1.1 }, { -12320, -8720, "묘", 0.9 },
	{ -12060, -8560, "솔", 0.95 }, { -12020, -8280, "가", 1.05 }, { -11800, -8420, "전", 1.0 },
	{ -11840, -8700, "고", 0.88 }, { -11600, -8300, "가", 1.1 }, { -11580, -8580, "전", 0.96 },
	{ -12700, -8300, "전", 1.0 }, { -12760, -8620, "묘", 0.9 }, { -11400, -8450, "솔", 1.04 },
	-- 숲 다 : 동쪽 덩이 남
	{ -9500, -6950, "전", 1.0 }, { -9300, -7100, "가", 1.08 }, { -9320, -6820, "고", 0.9 },
	{ -9080, -6980, "전", 0.96 }, { -9060, -7260, "솔", 1.0 }, { -8860, -7120, "가", 1.1 },
	{ -8840, -6860, "묘", 0.92 }, { -9700, -7080, "전", 1.02 }, { -9720, -6820, "가", 0.88 },
	{ -8850, -7020, "전", 1.0 }, { -9900, -6950, "묘", 0.94 }, { -8640, -7280, "고", 1.06 },
}
for _, t in ipairs(TREES) do
	conifer(t[1], t[2], t[3], t[4])
end
do -- 한 종이 몰리면 도장 찍은 티가 난다
	local by = {}
	for _, t in ipairs(TREES) do
		by[t[3]] = (by[t[3]] or 0) + 1
	end
	for k, v in pairs(by) do
		assert(v <= #TREES * 0.5, k .. " 나무가 " .. v .. "그루로 너무 몰렸다")
	end
end

-- 돌무지. 두 덩이를 잇는 가운데 띠를 따라 길잡이로 세운다
local CAIRNS = {
	{ -15700, -7500 }, { -14000, -7700 }, { -12400, -7550 },
	{ -11200, -7700 }, { -9900, -7500 }, { -8700, -7700 },
}
for _, c in ipairs(CAIRNS) do
	cairn(c[1], c[2])
end

--=== 자기검사 ===--
assert(#miss == 0, "바다 위에 적은 자리가 " .. #miss .. "곳 있다:\n  " .. table.concat(miss, "\n  "))

local counts = {}
for _, f in ipairs(ROOT:GetChildren()) do
	counts[#counts + 1] = f.Name .. " " .. #f:GetChildren()
end
print(string.format("[설원지대] 파트 %d개 / %s", n, table.concat(counts, " · ")))
assert(#F_tree:GetChildren() >= 36, "설림이 " .. #F_tree:GetChildren() .. "그루뿐이다")
assert(#F_drift:GetChildren() >= 24, "눈 언덕이 모자란다")
print("[설원지대] 배치표대로 다 섰다")
