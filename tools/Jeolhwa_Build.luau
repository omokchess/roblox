--!nocheck
--[[
	Jeolhwa_Lib.luau — 절화 부재 라이브러리. 혼자 실행하지 않는다.

	Jeolhwa_Build.luau 가 이 파일 내용을 앞에 붙여서 쓴다.
	Studio 커맨드 바에는 Jeolhwa_Build.luau 를 붙여넣는다.

	여기 있는 것은 **한 채를 통째로 세우는 법**이다. 기단부터 용마루까지.
	배치는 여기 없다. 어디에 무엇을 세울지는 Build 쪽 표가 정한다.

	한옥 한 채의 차례
	  1 기단      돌로 쌓은 단. 앞에 계단
	  2 초석·기둥  칸 수만큼 격자로. 주칠한 붉은 기둥
	  3 창방·평방  기둥머리를 가로로 묶는 보
	  4 벽·문·창   기둥 사이를 채운다. 정면 가운데 칸은 문
	  5 겹처마     서까래와 부연 두 겹. 기둥선 밖으로 내민다
	  6 지붕       계단식으로 좁혀 올라간다
	  7 용마루     꼭대기 마루. 네 귀로 내림마루가 내려간다
	  8 단청       처마 밑 띠

	**지붕을 계단으로 쌓는 이유.** 블록으로 곡면을 낼 수 없으니 층으로 좁힌다.
	층이 적으면 피라미드로 보이고 많으면 계단으로 보인다. 다섯에서 일곱이 적당하다.
]]

local RGB = Color3.fromRGB
local M = Enum.Material

--=== 팔레트 ===--
-- 「신맵 구조도.md」 §6 의 절화 조선 팔레트
local PAL = {
	roof = RGB(72, 80, 92), -- 청회색 기와
	roofDark = RGB(52, 58, 68), -- 기와 그늘
	ridge = RGB(96, 104, 116), -- 용마루
	wall = RGB(232, 226, 212), -- 회백색 회벽
	trim = RGB(150, 64, 50), -- 주칠 기둥
	trimDark = RGB(112, 46, 36),
	plinth = RGB(178, 176, 168), -- 화강 기단
	stone = RGB(158, 156, 148),
	wood = RGB(110, 78, 52), -- 문짝·마루
	paper = RGB(226, 216, 186), -- 창호지
	thatch = RGB(198, 176, 120), -- 초가 이엉
	dan1 = RGB(52, 104, 84), -- 단청 녹
	dan2 = RGB(44, 76, 124), -- 단청 청
	gold = RGB(214, 176, 92),
	soil = RGB(96, 74, 54),
	water = RGB(58, 92, 108),
}

local COUNT = 0
local ROOT = nil
local RNG = Random.new(19100)

local function setRoot(f)
	ROOT = f
end

local function put(fold, name, cf, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or PAL.stone
	p.Material = mat or M.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fold or ROOT
	COUNT += 1
	return p
end

-- 같은 색을 그대로 쓰면 면이 하나로 뭉쳐 보인다. 명암만 살짝 흔든다
local function shade(c, amt)
	local t = RNG:NextNumber(-(amt or 0.06), amt or 0.06)
	return c:Lerp(t < 0 and RGB(0, 0, 0) or RGB(255, 255, 255), math.abs(t))
end

--=== 지붕 ===--
-- 팔작지붕. 계단식으로 좁혀 올라가고 꼭대기에 용마루, 네 귀로 내림마루
-- base  처마 윗면 높이
-- w,d   처마 끝 기준 폭과 깊이
local function roof(fold, cf, base, w, d, h, tiers, col, dark)
	tiers = tiers or 6
	local ridgeW = w * 0.34
	local ridgeD = d * 0.16
	local step = h / tiers
	for k = 0, tiers - 1 do
		local t = k / (tiers - 1)
		local ww = w + (ridgeW - w) * t
		local dd = d + (ridgeD - d) * t
		put(
			fold,
			"Roof" .. k,
			cf * CFrame.new(0, base + step * (k + 0.5), 0),
			Vector3.new(ww, step * 1.06, dd),
			shade(k == 0 and dark or col, 0.05),
			M.Slate
		)
	end
	local top = base + h
	-- 용마루. 기와지붕의 얼굴이다
	put(fold, "RidgeMain", cf * CFrame.new(0, top + 5, 0), Vector3.new(ridgeW * 1.24, 11, ridgeD * 1.5), PAL.ridge, M.Slate)
	put(fold, "RidgeCap", cf * CFrame.new(0, top + 12, 0), Vector3.new(ridgeW * 1.3, 4, ridgeD * 1.7), PAL.stone, M.Slate)
	-- 치미. 용마루 양 끝에 올리는 장식
	for s = -1, 1, 2 do
		put(
			fold,
			"Chimi" .. s,
			cf * CFrame.new(s * ridgeW * 0.64, top + 15, 0) * CFrame.Angles(0, 0, s * 0.28),
			Vector3.new(12, 20, ridgeD * 1.5),
			PAL.ridge,
			M.Slate
		)
	end
	-- 내림마루. 용마루 끝에서 네 처마 귀로 내려간다
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local a = (cf * CFrame.new(sx * ridgeW * 0.5, top + 2, sz * ridgeD * 0.5)).Position
			local b = (cf * CFrame.new(sx * w * 0.5, base + step * 0.6, sz * d * 0.5)).Position
			put(
				fold,
				string.format("RidgeD%d%d", sx, sz),
				CFrame.lookAt((a + b) / 2, b),
				Vector3.new(9, 9, (b - a).Magnitude),
				PAL.ridge,
				M.Slate
			)
		end
	end
end

--=== 초가지붕 ===--
-- 민가용. 기와와 달리 둥글고 용마루가 없다
local function thatchRoof(fold, cf, base, w, d, h, col)
	local tiers = 4
	local step = h / tiers
	for k = 0, tiers - 1 do
		local t = k / (tiers - 1)
		put(
			fold,
			"Thatch" .. k,
			cf * CFrame.new(0, base + step * (k + 0.5), 0) * CFrame.Angles(0, RNG:NextNumber(-0.03, 0.03), 0),
			Vector3.new(w + (w * 0.22 - w) * t, step * 1.1, d + (d * 0.3 - d) * t),
			shade(col, 0.08),
			M.Grass
		)
	end
	put(fold, "ThatchTop", cf * CFrame.new(0, base + h + 3, 0), Vector3.new(w * 0.26, 7, d * 0.34), shade(col, 0.05), M.Grass)
end

--=== 한 채 ===--
-- o.w / o.d      기둥선 기준 폭과 깊이
-- o.colH         기둥 높이
-- o.bays         정면 칸 수 (기본 3)
-- o.dbays        측면 칸 수 (기본 2)
-- o.plinth       기단 높이 (기본 10)
-- o.roofH        지붕 높이 (기본 colH*0.9)
-- o.tiers        지붕 계단 수
-- o.thatch       true 면 초가. 기둥도 나무색이 된다
-- o.open         true 면 벽 없이 기둥만. 정자와 행각에 쓴다
-- o.dancheong    true 면 처마 밑 단청 띠
-- o.stair        true 면 정면에 계단 (기본 true)
-- o.double       true 면 지붕을 두 겹으로. 정전급에 쓴다
local function building(fold, cx, cz, yaw, o)
	local w, d = o.w, o.d
	local colH = o.colH or 34
	local bays = o.bays or 3
	local dbays = o.dbays or 2
	local ph = o.plinth or 10
	local base = CFrame.new(cx, o.y or 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
	local wood = o.thatch and PAL.wood or PAL.trim

	-- 1 기단
	local pw, pd = w + 34, d + 34
	put(fold, "Plinth0", base * CFrame.new(0, ph * 0.5, 0), Vector3.new(pw, ph, pd), shade(PAL.plinth), M.Concrete)
	put(fold, "Plinth1", base * CFrame.new(0, ph + 2, 0), Vector3.new(pw - 12, 4, pd - 12), shade(PAL.stone), M.Concrete)
	-- 앞 계단
	if o.stair ~= false then
		for k = 0, 2 do
			put(
				fold,
				"Step" .. k,
				base * CFrame.new(0, ph * (k + 0.5) / 3, -pd * 0.5 - 11 + k * 5),
				Vector3.new(w * 0.42, ph / 3, 22 - k * 5),
				shade(PAL.stone),
				M.Concrete
			)
		end
	end

	local fy = ph + 4 -- 마루 높이
	-- 마루
	put(fold, "Floor", base * CFrame.new(0, fy + 2, 0), Vector3.new(w + 10, 5, d + 10), shade(PAL.wood, 0.07), M.WoodPlanks)

	-- 2 초석과 기둥
	local sx, sz = w / bays, d / dbays
	for i = 0, bays do
		for j = 0, dbays do
			local px, pz = -w / 2 + i * sx, -d / 2 + j * sz
			-- 안쪽 기둥은 벽에 가려 안 보인다. 테두리만 세운다
			if i == 0 or i == bays or j == 0 or j == dbays then
				put(fold, string.format("Base%d_%d", i, j), base * CFrame.new(px, fy + 5, pz), Vector3.new(16, 6, 16), shade(PAL.stone), M.Concrete)
				put(
					fold,
					string.format("Col%d_%d", i, j),
					base * CFrame.new(px, fy + 8 + colH / 2, pz),
					Vector3.new(11, colH, 11),
					shade(wood, 0.05),
					M.WoodPlanks
				)
			end
		end
	end

	local topY = fy + 8 + colH
	-- 3 창방과 평방
	for s = -1, 1, 2 do
		put(fold, "Beam" .. s, base * CFrame.new(0, topY + 4, s * d / 2), Vector3.new(w + 12, 9, 10), shade(wood, 0.05), M.WoodPlanks)
		put(fold, "BeamS" .. s, base * CFrame.new(s * w / 2, topY + 4, 0), Vector3.new(10, 9, d + 12), shade(wood, 0.05), M.WoodPlanks)
	end
	put(fold, "Plate", base * CFrame.new(0, topY + 11, 0), Vector3.new(w + 16, 6, d + 16), shade(wood, 0.05), M.WoodPlanks)

	-- 4 벽, 문, 창
	if not o.open then
		local wallH = colH - 4
		for i = 0, bays - 1 do
			local px = -w / 2 + (i + 0.5) * sx
			local isDoor = (i == math.floor(bays / 2))
			-- 정면. 가운데 칸은 문, 나머지는 아래 회벽 위 창호
			if isDoor then
				put(fold, "Door" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.45, -d / 2), Vector3.new(sx - 13, wallH * 0.9, 7), shade(PAL.wood, 0.06), M.WoodPlanks)
				put(fold, "DoorSplit" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.45, -d / 2 - 1), Vector3.new(3, wallH * 0.9, 6), shade(PAL.trimDark), M.WoodPlanks)
			else
				put(fold, "WallF" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.22, -d / 2), Vector3.new(sx - 12, wallH * 0.45, 8), shade(PAL.wall), M.Concrete)
				put(fold, "WinF" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.68, -d / 2), Vector3.new(sx - 13, wallH * 0.44, 6), shade(PAL.paper, 0.05), M.WoodPlanks)
				put(fold, "WinFB" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.68, -d / 2 - 1), Vector3.new(sx - 13, 3, 5), shade(PAL.trimDark), M.WoodPlanks)
			end
			-- 뒷면은 창 없이 회벽
			put(fold, "WallB" .. i, base * CFrame.new(px, fy + 8 + wallH * 0.5, d / 2), Vector3.new(sx - 12, wallH, 8), shade(PAL.wall), M.Concrete)
		end
		for j = 0, dbays - 1 do
			local pz = -d / 2 + (j + 0.5) * sz
			for s = -1, 1, 2 do
				put(fold, string.format("WallS%d_%d", j, s), base * CFrame.new(s * w / 2, fy + 8 + wallH * 0.5, pz), Vector3.new(8, wallH, sz - 12), shade(PAL.wall), M.Concrete)
			end
		end
	end

	-- 8 단청. 처마 밑 띠
	if o.dancheong then
		for s = -1, 1, 2 do
			put(fold, "Dan" .. s, base * CFrame.new(0, topY + 15, s * (d / 2 + 3)), Vector3.new(w + 14, 7, 5), PAL.dan1, M.SmoothPlastic)
			put(fold, "Dan2" .. s, base * CFrame.new(0, topY + 22, s * (d / 2 + 3)), Vector3.new(w + 14, 6, 5), PAL.dan2, M.SmoothPlastic)
		end
	end

	-- 5 겹처마. 기둥선 밖으로 두 겹 내민다
	local ov = o.eave or 26
	local eaveY = topY + (o.dancheong and 28 or 16)
	put(fold, "Eave1", base * CFrame.new(0, eaveY, 0), Vector3.new(w + ov * 2, 9, d + ov * 2), shade(PAL.roofDark, 0.04), M.Slate)
	put(fold, "Eave2", base * CFrame.new(0, eaveY + 9, 0), Vector3.new(w + ov * 1.6, 8, d + ov * 1.6), shade(PAL.roof, 0.04), M.Slate)

	-- 6·7 지붕
	local rw, rd = w + ov * 1.6, d + ov * 1.6
	local rh = o.roofH or colH * 0.95
	if o.double then
		-- 중층. 아래 지붕을 한 겹 더 두르고 그 위에 몸통을 올린다
		local midY = eaveY + 17
		roof(fold, base, midY, rw, rd, rh * 0.5, 4, PAL.roof, PAL.roofDark)
		local uh = colH * 0.6
		for i = 0, bays do
			local px = -w * 0.36 + i * (w * 0.72 / bays)
			for s = -1, 1, 2 do
				put(fold, string.format("UCol%d_%d", i, s), base * CFrame.new(px, midY + rh * 0.5 + uh / 2 + 6, s * d * 0.3), Vector3.new(10, uh, 10), shade(wood, 0.05), M.WoodPlanks)
			end
		end
		for i = 0, bays - 1 do
			local px = -w * 0.36 + (i + 0.5) * (w * 0.72 / bays)
			put(fold, "UWall" .. i, base * CFrame.new(px, midY + rh * 0.5 + uh * 0.5 + 6, -d * 0.3), Vector3.new(w * 0.72 / bays - 12, uh * 0.9, 7), shade(PAL.paper, 0.05), M.WoodPlanks)
			put(fold, "UWallB" .. i, base * CFrame.new(px, midY + rh * 0.5 + uh * 0.5 + 6, d * 0.3), Vector3.new(w * 0.72 / bays - 12, uh * 0.9, 7), shade(PAL.wall), M.Concrete)
		end
		local uy = midY + rh * 0.5 + uh + 12
		put(fold, "UEave", base * CFrame.new(0, uy, 0), Vector3.new(w * 0.98, 9, d * 0.86), shade(PAL.roof, 0.04), M.Slate)
		roof(fold, base, uy + 5, w * 0.98, d * 0.86, rh * 0.72, 5, PAL.roof, PAL.roofDark)
	elseif o.thatch then
		thatchRoof(fold, base, eaveY + 8, rw * 0.94, rd * 0.94, rh * 0.9, PAL.thatch)
	else
		roof(fold, base, eaveY + 17, rw, rd, rh, o.tiers or 6, PAL.roof, PAL.roofDark)
	end
end

--=== 담장 ===--
-- a 에서 b 까지. 기와를 인 토담
local function wallRun(fold, ax, az, bx, bz, o)
	o = o or {}
	local h = o.h or 46
	local th = o.th or 22
	local y = o.y or 0
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	local seg = math.max(math.floor(len / 56), 1)
	local yaw = math.atan2(dx, dz)
	for i = 0, seg - 1 do
		local t = (i + 0.5) / seg
		local px, pz = ax + dx * t, az + dz * t
		local cf = CFrame.new(px, y, pz) * CFrame.Angles(0, yaw, 0)
		local l = len / seg * 1.04
		-- 아래 돌기단
		put(fold, "WBase" .. i, cf * CFrame.new(0, 7, 0), Vector3.new(th + 8, 14, l), shade(PAL.stone), M.Concrete)
		-- 회벽 몸통
		put(fold, "WBody" .. i, cf * CFrame.new(0, 14 + h * 0.5, 0), Vector3.new(th, h, l), shade(PAL.wall), M.Concrete)
		-- 기와 지붕
		put(fold, "WCap" .. i, cf * CFrame.new(0, 14 + h + 5, 0), Vector3.new(th + 14, 10, l), shade(PAL.roof, 0.05), M.Slate)
		put(fold, "WRidge" .. i, cf * CFrame.new(0, 14 + h + 12, 0), Vector3.new(th * 0.5, 5, l), PAL.ridge, M.Slate)
	end
	return len
end

--=== 성벽 ===--
-- 도성 성벽. 담장보다 두껍고 위에 여장을 올린다
local function cityWall(fold, ax, az, bx, bz, y, h)
	h = h or 92
	local th = 54
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	local seg = math.max(math.floor(len / 64), 1)
	local yaw = math.atan2(dx, dz)
	for i = 0, seg - 1 do
		local t = (i + 0.5) / seg
		local cf = CFrame.new(ax + dx * t, y, az + dz * t) * CFrame.Angles(0, yaw, 0)
		local l = len / seg * 1.03
		-- 아래가 넓고 위가 좁다. 수직이면 담장처럼 보인다
		put(fold, "CW0_" .. i, cf * CFrame.new(0, h * 0.25, 0), Vector3.new(th, h * 0.5, l), shade(PAL.stone, 0.08), M.Concrete)
		put(fold, "CW1_" .. i, cf * CFrame.new(0, h * 0.75, 0), Vector3.new(th - 12, h * 0.5, l), shade(PAL.stone, 0.08), M.Concrete)
		-- 미석
		put(fold, "CWCap" .. i, cf * CFrame.new(0, h + 4, 0), Vector3.new(th + 6, 8, l), shade(PAL.plinth), M.Concrete)
		-- 여장. 두 칸마다 총안을 비운다
		local merlons = 3
		for k = 0, merlons - 1 do
			if (i + k) % 4 ~= 2 then
				put(
					fold,
					string.format("CWM%d_%d", i, k),
					cf * CFrame.new(0, h + 20, (k - (merlons - 1) / 2) * (l / merlons)),
					Vector3.new(th - 6, 24, l / merlons * 0.86),
					shade(PAL.wall),
					M.Concrete
				)
			end
		end
	end
	return len
end

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
	-- 위 누각은 gateTower 가 따로 세운다. building 은 월드 좌표를 받기 때문이다
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
