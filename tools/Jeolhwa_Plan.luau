--!nocheck
--[[
	Jeolhwa_Plan.luau — 절화 도성 배치. Jeolhwa_Lib.luau 뒤에 붙여서 쓴다.

	합쳐진 파일이 tools/Jeolhwa_Build.luau 다. Studio 에는 그것을 붙여넣는다.

	**옛 절화는 지운다.** 러프 단계에 만든 것이라 세부가 없다.
	섬에 흩어진 나무(Pln_Tree)는 남기고 과수원과 건물만 걷어낸다.

	도성은 북쪽 탑의 성역을 정면으로 본다. 주축은 x=1100 을 따라 남북으로 뻗고
	북문에서 들어와 육조거리를 지나 궁성 외문, 조정 앞뜰, 정전 순으로 이어진다.

	성벽은 성역을 보는 방향 기준 **오른쪽 아래**, 즉 섬의 남동쪽 모서리에서 시작해
	시계 반대 방향으로 돈다. 꼭짓점은 전부 손으로 찍었고 육지 위인지 격자로 확인했다.

	배치는 아래 표에 좌표로 적혀 있다. 흩뿌리는 수식을 쓰지 않는다.
]]

local S = workspace.Surface
local GY = 6 -- 평원 지반 윗면. 섬 대부분이 이 높이다

--=== 옛 절화 철거 ===--
local R = S:FindFirstChild("R_평원")
if not R then
	R = Instance.new("Folder")
	R.Name = "R_평원"
	R.Parent = S
end
local wiped = 0
for _, f in ipairs(R:GetChildren()) do
	if f.Name == "Flora" then
		-- 섬 나무는 남기고 과수원만 걷어낸다
		for _, p in ipairs(f:GetChildren()) do
			if p.Name:match("^Pln_Orch") then
				p:Destroy()
				wiped += 1
			end
		end
	else
		wiped += #f:GetDescendants()
		f:Destroy()
	end
end

local function mk(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or R
	return f
end
local CITY = mk("City")
setRoot(CITY)

local fWall = mk("Wall", CITY)
local fPal = mk("Palace", CITY)
local fGov = mk("Gov", CITY)
local fTown = mk("Town", CITY)
local fGarden = mk("Garden", CITY)
local fRoad = mk("Road", CITY)
local fFarm = mk("Farm", CITY)

--=== 성벽 꼭짓점. 남동쪽에서 시작해 시계 반대 방향 ===--
local RAMPART = {
	{ 3000, 2400 },
	{ 3200, 1700 },
	{ 3150, 900 },
	{ 2400, 300 },
	{ 1100, 170 },
	{ -200, 240 },
	{ -1100, 520 },
	{ -1550, 1100 },
	{ -1550, 1800 },
	{ -1000, 2450 },
	{ -100, 2770 },
	{ 1100, 2800 },
	{ 2200, 2680 },
}

-- 성문. 성벽에서 이 반경만큼 비우고 그 자리에 문루를 세운다
local GATES = {
	{ name = "북문", x = 1100, z = 172, yaw = 0, w = 170 },
	{ name = "동문", x = 3176, z = 1300, yaw = 90, w = 140 },
	{ name = "서문", x = -1550, z = 1450, yaw = -90, w = 140 },
	{ name = "남문", x = 1100, z = 2800, yaw = 180, w = 140 },
}

--=== 문루 ===--
-- 돌로 쌓은 홍예문 위에 누각을 올린다
local function gateHouse(fold, g)
	local base = CFrame.new(g.x, GY, g.z) * CFrame.Angles(0, math.rad(g.yaw), 0)
	local W, H, T = g.w + 120, 96, 68
	local open = 54
	-- 좌우 육축
	for s = -1, 1, 2 do
		put(fold, g.name .. "_Pier" .. s, base * CFrame.new(s * (open / 2 + (W / 2 - open / 2) / 2), H * 0.5, 0), Vector3.new(W / 2 - open / 2, H, T), shade(PAL.stone, 0.08), M.Concrete)
	end
	-- 홍예. 계단으로 좁혀 아치 시늉을 낸다
	for k = 0, 3 do
		local ww = open - k * 11
		put(fold, g.name .. "_Arch" .. k, base * CFrame.new(0, H * 0.62 + k * 8, 0), Vector3.new(ww, 8, T), shade(PAL.stone, 0.06), M.Concrete)
	end
	put(fold, g.name .. "_Lintel", base * CFrame.new(0, H - 6, 0), Vector3.new(W, 12, T + 6), shade(PAL.plinth), M.Concrete)
	-- 문짝
	for s = -1, 1, 2 do
		put(fold, g.name .. "_Door" .. s, base * CFrame.new(s * open * 0.25, H * 0.32, -T * 0.42), Vector3.new(open * 0.48, H * 0.62, 7), shade(PAL.wood, 0.06), M.WoodPlanks)
	end
	-- 여장
	put(fold, g.name .. "_Deck", base * CFrame.new(0, H + 6, 0), Vector3.new(W + 16, 10, T + 16), shade(PAL.plinth), M.Concrete)
	-- 위 누각
	building(fold, 0, 0, 0, {
		w = W - 60,
		d = T - 12,
		colH = 34,
		bays = 5,
		dbays = 2,
		plinth = 6,
		open = true,
		dancheong = true,
		stair = false,
		y = H + 11,
		eave = 24,
	})
	-- building 은 월드 좌표를 받으므로 문 방향에 맞춰 다시 세운다
end

-- building 이 회전을 스스로 하므로 문루 누각은 따로 부른다
local function gateTower(fold, g)
	local H = 96
	building(fold, g.x, g.z, g.yaw, {
		w = g.w + 60,
		d = 56,
		colH = 34,
		bays = 5,
		dbays = 2,
		plinth = 6,
		open = true,
		dancheong = true,
		stair = false,
		y = GY + H + 11,
		eave = 24,
		roofH = 34,
	})
end

--=== 성벽 세우기 ===--
local wallLen = 0
for i = 1, #RAMPART do
	local a = RAMPART[i]
	local b = RAMPART[i % #RAMPART + 1]
	local ax, az, bx, bz = a[1], a[2], b[1], b[2]
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.max(math.floor(len / 64), 1)
	for k = 0, n - 1 do
		local t0, t1 = k / n, (k + 1) / n
		local mx, mz = ax + dx * (t0 + t1) / 2, az + dz * (t0 + t1) / 2
		local skip = false
		for _, g in ipairs(GATES) do
			if (mx - g.x) ^ 2 + (mz - g.z) ^ 2 < (g.w * 0.62) ^ 2 then
				skip = true
			end
		end
		if not skip then
			cityWall(fWall, ax + dx * t0, az + dz * t0, ax + dx * t1, az + dz * t1, GY, 92)
		end
	end
	wallLen += len
	task.wait()
end
for _, g in ipairs(GATES) do
	gateHouse(fWall, g)
	gateTower(fWall, g)
end

--=== 길 ===--
-- { 시작x, 시작z, 끝x, 끝z, 폭 }
local ROADS = {
	{ 1100, 200, 1100, 1040, 150 }, -- 주작대로. 북문에서 궁성까지
	{ 1100, 1040, 1100, 2600, 110 }, -- 궁 안 어도
	{ -1500, 700, 3100, 700, 110 }, -- 북대로
	{ -1400, 1450, 3150, 1450, 110 }, -- 중대로
	{ -900, 2300, 2900, 2300, 96 }, -- 남대로
	{ 300, 250, 300, 2650, 84 }, -- 서세로
	{ 1900, 250, 1900, 2650, 84 }, -- 동세로
	{ 2600, 700, 2600, 2400, 72 },
	{ -700, 700, -700, 2400, 72 },
}
for ri, r in ipairs(ROADS) do
	local dx, dz = r[3] - r[1], r[4] - r[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.floor(len / 72)
	local yaw = math.atan2(dx, dz)
	for k = 0, n do
		local t = k / n
		put(
			fRoad,
			string.format("Road%d_%d", ri, k),
			CFrame.new(r[1] + dx * t, GY + 1, r[2] + dz * t) * CFrame.Angles(0, yaw, 0),
			Vector3.new(r[5], 4, len / n * 1.06),
			shade(PAL.stone, 0.07),
			M.Concrete
		)
	end
	task.wait()
end

--=== 건물 규격 ===--
local P = {
	["정전"] = { w = 210, d = 132, colH = 54, bays = 5, dbays = 3, plinth = 28, double = true, dancheong = true, eave = 34 },
	["편전"] = { w = 152, d = 96, colH = 44, bays = 5, dbays = 3, plinth = 20, dancheong = true, eave = 30 },
	["전각"] = { w = 112, d = 72, colH = 36, bays = 3, dbays = 2, plinth = 14, dancheong = true },
	["침전"] = { w = 130, d = 84, colH = 38, bays = 5, dbays = 2, plinth = 16, dancheong = true },
	["행각"] = { w = 168, d = 42, colH = 28, bays = 6, dbays = 1, plinth = 10, open = true, tiers = 4 },
	["관아"] = { w = 126, d = 80, colH = 38, bays = 5, dbays = 2, plinth = 16, dancheong = true },
	["누각"] = { w = 100, d = 100, colH = 44, bays = 3, dbays = 3, plinth = 22, open = true, dancheong = true },
	["정자"] = { w = 66, d = 66, colH = 30, bays = 2, dbays = 2, plinth = 16, open = true },
	["기와집"] = { w = 74, d = 54, colH = 26, bays = 3, dbays = 2, plinth = 10, tiers = 5 },
	["민가"] = { w = 58, d = 44, colH = 22, bays = 3, dbays = 2, plinth = 8, thatch = true },
	["상점"] = { w = 54, d = 46, colH = 24, bays = 2, dbays = 2, plinth = 8, tiers = 4 },
	["창고"] = { w = 104, d = 62, colH = 30, bays = 4, dbays = 2, plinth = 12, tiers = 5 },
	["군영"] = { w = 140, d = 70, colH = 32, bays = 5, dbays = 2, plinth = 12, tiers = 5 },
}

-- { x, z, 방향, 규격 }
local BUILDINGS = {
	--- 궁성 안. 주축은 x=1100
	{ 1100, 1560, 0, "정전" },
	{ 1100, 1810, 0, "편전" },
	{ 1100, 2040, 0, "침전" },
	{ 890, 2040, 0, "전각" },
	{ 1310, 2040, 0, "전각" },
	{ 900, 2250, 0, "전각" },
	{ 1300, 2250, 0, "전각" },
	{ 1100, 1300, 0, "누각" }, -- 조정 앞뜰 누각
	-- 정전을 둘러싸는 행각
	{ 1100, 1380, 0, "행각" },
	{ 1100, 1740, 180, "행각" },
	{ 870, 1560, 90, "행각" },
	{ 1330, 1560, -90, "행각" },

	--- 육조거리. 북문에서 궁성까지 양옆
	{ 830, 480, 90, "관아" },
	{ 830, 660, 90, "관아" },
	{ 830, 840, 90, "관아" },
	{ 1370, 480, -90, "관아" },
	{ 1370, 660, -90, "관아" },
	{ 1370, 840, -90, "관아" },
	{ 620, 560, 0, "전각" },
	{ 1580, 560, 0, "전각" },

	--- 서시. 서쪽 저자거리
	{ -420, 560, 0, "상점" },
	{ -300, 560, 0, "상점" },
	{ -180, 560, 0, "상점" },
	{ -60, 560, 0, "상점" },
	{ -420, 840, 180, "상점" },
	{ -300, 840, 180, "상점" },
	{ -180, 840, 180, "상점" },
	{ -60, 840, 180, "상점" },
	{ -620, 700, 90, "기와집" },
	{ 40, 700, -90, "기와집" },

	--- 서민가
	{ -1180, 900, 0, "민가" },
	{ -1060, 900, 0, "민가" },
	{ -940, 900, 0, "민가" },
	{ -1180, 1040, 180, "민가" },
	{ -1060, 1040, 180, "민가" },
	{ -940, 1040, 180, "민가" },
	{ -1180, 1300, 0, "민가" },
	{ -1060, 1300, 0, "민가" },
	{ -940, 1300, 0, "민가" },
	{ -1180, 1620, 0, "민가" },
	{ -1060, 1620, 0, "민가" },
	{ -940, 1620, 0, "민가" },
	{ -1180, 1760, 180, "민가" },
	{ -1060, 1760, 180, "민가" },
	{ -940, 1760, 180, "민가" },
	{ -1240, 1200, 90, "기와집" },
	{ -1240, 1900, 90, "기와집" },

	--- 향교
	{ -560, 1450, 0, "전각" },
	{ -560, 1620, 180, "행각" },
	{ -700, 1530, 90, "기와집" },
	{ -420, 1530, -90, "기와집" },

	--- 동시. 동쪽 저자거리와 창고
	{ 2300, 560, 0, "상점" },
	{ 2420, 560, 0, "상점" },
	{ 2540, 560, 0, "상점" },
	{ 2300, 840, 180, "상점" },
	{ 2420, 840, 180, "상점" },
	{ 2540, 840, 180, "상점" },
	{ 2820, 700, -90, "창고" },
	{ 2820, 950, -90, "창고" },
	{ 2820, 1200, -90, "창고" },

	--- 군영
	{ 2500, 1700, 0, "군영" },
	{ 2500, 1900, 0, "군영" },
	{ 2500, 2100, 0, "군영" },
	{ 2820, 1900, -90, "창고" },
	{ 2300, 1800, 90, "기와집" },

	--- 동민가
	{ 2100, 2450, 0, "민가" },
	{ 2220, 2450, 0, "민가" },
	{ 2340, 2450, 0, "민가" },
	{ 2100, 2590, 180, "민가" },
	{ 2220, 2590, 180, "민가" },
	{ 2340, 2590, 180, "민가" },

	--- 남쪽
	{ 300, 2500, 0, "기와집" },
	{ 460, 2500, 0, "민가" },
	{ 580, 2500, 0, "민가" },
	{ 140, 2500, 0, "민가" },
}

for i, b in ipairs(BUILDINGS) do
	local spec = P[b[4]]
	assert(spec, "모르는 규격: " .. tostring(b[4]))
	local o = {}
	for k, v in pairs(spec) do
		o[k] = v
	end
	o.y = GY
	local fold = fTown
	if b[2] > 1150 and b[1] > 600 and b[1] < 1700 then
		fold = fPal
	elseif b[2] < 1000 and b[1] > 500 and b[1] < 1700 then
		fold = fGov
	end
	building(fold, b[1], b[2], b[3], o)
	if i % 6 == 0 then
		task.wait()
	end
end

--=== 궁성 담장 ===--
local PWALL = {
	{ 620, 1100 },
	{ 1580, 1100 },
	{ 1580, 2600 },
	{ 620, 2600 },
}
for i = 1, #PWALL do
	local a, b = PWALL[i], PWALL[i % #PWALL + 1]
	-- 남북 축 위의 문 자리는 비운다
	local ax, az, bx, bz = a[1], a[2], b[1], b[2]
	if az == 1100 and bz == 1100 then
		wallRun(fPal, ax, az, 1020, az, { y = GY, h = 54 })
		wallRun(fPal, 1180, az, bx, bz, { y = GY, h = 54 })
	elseif az == 2600 and bz == 2600 then
		wallRun(fPal, ax, az, 1180, az, { y = GY, h = 54 })
		wallRun(fPal, 1020, az, bx, bz, { y = GY, h = 54 })
	else
		wallRun(fPal, ax, az, bx, bz, { y = GY, h = 54 })
	end
	task.wait()
end
-- 궁성 정문
gateHouse(fPal, { name = "궁문", x = 1100, z = 1100, yaw = 0, w = 120 })
gateTower(fPal, { name = "궁문", x = 1100, z = 1100, yaw = 0, w = 120 })

--=== 조정 앞뜰의 품계석 ===--
for k = 0, 8 do
	for s = -1, 1, 2 do
		put(
			fPal,
			string.format("Rank%d_%d", k, s),
			CFrame.new(1100 + s * 86, GY + 11, 1330 + k * 26),
			Vector3.new(12, 22, 12),
			shade(PAL.stone),
			M.Concrete
		)
	end
end

--=== 후원. 연못과 정자 ===--
do
	local cx, cz, r = 1100, 2430, 150
	local n = 26
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		put(
			fGarden,
			"PondEdge" .. i,
			CFrame.new(cx + math.cos(a) * r, GY + 4, cz + math.sin(a) * r) * CFrame.Angles(0, -a, 0),
			Vector3.new(30, 10, 44),
			shade(PAL.stone),
			M.Concrete
		)
	end
	local w = put(fGarden, "Pond", CFrame.new(cx, GY + 1, cz), Vector3.new(r * 1.82, 5, r * 1.82), PAL.water, M.Glass)
	w.Reflectance = 0.4
	w.Transparency = 0.3
	-- 섬과 정자
	put(fGarden, "PondIsle", CFrame.new(cx, GY + 6, cz), Vector3.new(96, 12, 96), shade(PAL.soil, 0.08), M.Ground)
	building(fGarden, cx, cz, 0, { w = 66, d = 66, colH = 30, bays = 2, dbays = 2, plinth = 14, open = true, y = GY + 12, stair = false })
	-- 다리
	for k = 0, 3 do
		put(fGarden, "Bridge" .. k, CFrame.new(cx, GY + 10, cz - r - 34 + k * 24), Vector3.new(34, 6, 26), shade(PAL.wood, 0.06), M.WoodPlanks)
	end
end

--=== 논밭. 성 밖 남서쪽 ===--
local FIELDS = {
	{ -1300, 2150, 260, 150 },
	{ -1300, 2340, 260, 150 },
	{ -960, 2150, 260, 150 },
	{ -960, 2340, 260, 150 },
	{ 400, 380, 300, 120 },
	{ 760, 380, 300, 120 },
	{ 1440, 380, 300, 120 },
	{ 1800, 380, 300, 120 },
	{ 2600, 2350, 300, 140 },
	{ 2600, 2530, 300, 140 },
}
for i, f in ipairs(FIELDS) do
	put(fFarm, "Field" .. i, CFrame.new(f[1], GY + 2, f[2]), Vector3.new(f[3], 5, f[4]), shade(PAL.soil, 0.1), M.Ground)
	local rows = math.floor(f[4] / 26)
	for k = 0, rows - 1 do
		put(
			fFarm,
			string.format("Furrow%d_%d", i, k),
			CFrame.new(f[1], GY + 5, f[2] - f[4] / 2 + (k + 0.5) * (f[4] / rows)),
			Vector3.new(f[3] - 14, 4, 10),
			shade(PAL.dan1, 0.14),
			M.Grass
		)
	end
end

--=== 자기검사 ===--
local n = COUNT
assert(n > 3000, "도성이 " .. n .. "파트뿐이다")
assert(#BUILDINGS >= 70, "건물이 " .. #BUILDINGS .. "채뿐이다")

-- 모든 부재가 육지 위에 있어야 한다
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World["G_평원"] }
local off, mnx, mxx, mnz, mxz = 0, 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(CITY:GetDescendants()) do
	if p:IsA("BasePart") then
		mnx, mxx = math.min(mnx, p.Position.X), math.max(mxx, p.Position.X)
		mnz, mxz = math.min(mnz, p.Position.Z), math.max(mxz, p.Position.Z)
		if not workspace:Raycast(Vector3.new(p.Position.X, 900, p.Position.Z), Vector3.new(0, -1600, 0), rp) then
			off += 1
		end
	end
end
assert(off < 40, "바다 위에 놓인 부재가 " .. off .. "개다")

-- 탑의 성역 복합체는 3503 x 3568 이었다. 그보다 작으면 안 된다
local ww, dd = mxx - mnx, mxz - mnz
assert(ww * dd > 3503 * 3568 * 0.95, string.format("도성이 %d x %d 로 성역보다 작다", ww, dd))

print(string.format("[Jeolhwa] 옛 부재 %d개 철거 / 새로 %d파트", wiped, n))
print(string.format("[Jeolhwa] 건물 %d채 / 성벽 둘레 %d / 범위 %d x %d (x %d..%d, z %d..%d)", #BUILDINGS, wallLen, ww, dd, mnx, mxx, mnz, mxz))
print(string.format("[Jeolhwa] 바다 위 부재 %d개 / 북문 (1100,172) 이 탑의 성역을 본다", off))
