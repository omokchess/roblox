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

return {
	PAL = PAL,
	put = put,
	shade = shade,
	roof = roof,
	thatchRoof = thatchRoof,
	building = building,
	wallRun = wallRun,
	cityWall = cityWall,
	setRoot = setRoot,
	count = function()
		return COUNT
	end,
}
