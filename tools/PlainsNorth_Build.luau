--!nocheck
--[[
	PlainsNorth_Build.luau — 2026-10-03. 평원 북쪽 시범 지역을 새 방식으로 짓는다(편집 모드, StudioJobs 로 돌린다).

	사용자 확정: 지형은 지역마다 큰 Part 평면 + 큰 구조물(손 배치), 삼각형 법칙, 옛 지형은 ServerStorage 에 백업 후 교체.
	2026-10-03 사용자: "돌산 같은 것도 기본적으로는 커다란 육면체", "대륙이 사각형이라는 건 곡선을 가지고 있지 않다는 거야"
	+ 참고 사진(평평한 풀밭을 초록 윗면 직육면체 덩어리·회색 바위 상자가 계단식으로 감싼다) →
	  땅 = 축에 맞춘 네모 판들(해안선이 계단식 직각), 절벽·돌산 = 회색 바위 상자 + 풀 윗판, 오르막 = 쐐기, 길 = 직각으로 꺾임.
	  블렌더는 상자로 안 되는 경계벽 잔해(돌 쌓은 벽·망루)만 — ServerStorage.PlainsKit (models/plains/build_kit_plains.py).

	차례(다시 돌려도 된다 — 새 폴더만 지우고 다시 짓는다):
	  1. 옛 지형 타일(Surface.World.G_평원, 이 구역 안·가운데 -400 < z < 150) → ServerStorage.TerrainBackup.PlainsNorth (처음 한 번만)
	  2. Surface.R_평원북: 땅 판(LAND) → 바닷가 절벽 상자(CLIFFS) → 돌산·덩어리(MASSES) → 오르막(RAMPS) → 모래 단(SAND)
	  3. 경계벽 잔해(RUINS)·바위(ROCKS)·돌길(PATHS)·밭(FIELDS)·나무(TREES)·정자(남산 꼭대기)
	좌표 = 월드(x 동, z 남 — 북 = -z = 바다·탑의 성역 쪽). 물높이 -3.5, 옛 땅 윗면 ≈ 2, 새 땅 윗면 1.90.
	보고: /plainsnorth
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

-- 옛 타일을 걷어 낼 곳: Surface.World.G_평원 안에서만. 2026-10-03 첫 실행 때 폴더를 안 가려 같은 x 띠의
-- 탑의 성역·화산·광산 타일까지 옮겼다가 곧바로 되돌린 일이 있다 — 폴더와 z 아래끝을 꼭 둔다
local AREA = { folder = "G_평원", x0 = -700, x1 = 1200, zMin = -400, zMax = 150 }
local TOP = 1.90
local GRASS = RGB(117, 151, 83)
local ROCK = RGB(132, 130, 124)
local ROCK2 = RGB(118, 116, 111)
local SANDC = RGB(219, 200, 155)

--=== 손 배치표 ===--
-- 땅 판: { x0, x1, 북쪽 끝 z } — 남쪽 끝은 모두 z 200(옛 땅 첫 줄 아래로 조금). 이웃 판은 맞닿기만(겹치면 깜박임)
local LAND = {
	{ -600, -420, -60 },
	{ -420, -160, -130 },
	{ -160, 140, -170 },
	{ 140, 420, -230 }, -- 남산 곶
	{ 420, 640, -150 }, -- 모래 만
	{ 640, 900, -110 },
	{ 900, 1080, -40 },
}
local SOUTH = 200

-- 바닷가 절벽 상자: { x0, x1, z0, z1, 윗면(땅 위 높이) } — 땅 가장자리를 따라 바다 쪽으로 내밀고 물 아래 -24 까지.
-- 윗면이 0 보다 크면 땅보다 솟은 턱(풀 윗판), 0 이면 땅과 같은 높이
local CLIFFS = {
	-- 서쪽 끝 판(북 -60)
	{ -610, -540, -82, -56, 4 }, { -540, -470, -78, -58, 0 }, { -470, -420, -84, -58, 7 },
	{ -432, -414, -134, -56, 10 }, -- 계단 모서리(동서 경계)
	-- 둘째 판(북 -130)
	{ -420, -350, -150, -128, 0 }, { -350, -290, -146, -128, 5 }, { -290, -220, -152, -128, 0 }, { -220, -160, -148, -128, 3 },
	{ -172, -150, -174, -126, 12 },
	-- 셋째 판(북 -170, 벽 잔해 줄)
	{ -160, -90, -190, -168, 0 }, { -90, -20, -186, -168, 4 }, { -20, 60, -192, -168, 0 }, { 60, 140, -188, -168, 6 },
	{ 128, 152, -234, -166, 14 },
	-- 남산 곶(북 -230)
	{ 140, 220, -252, -228, 2 }, { 220, 320, -256, -228, 0 }, { 320, 420, -250, -228, 3 },
	{ 408, 432, -234, -146, 16 }, -- 곶 동쪽 벼랑(만 서쪽 벽)
	{ 620, 652, -214, -104, 9 }, -- 만 동쪽 벽
	-- 다섯째 판(북 -110)
	{ 640, 720, -130, -108, 0 }, { 720, 800, -134, -108, 5 }, { 800, 900, -128, -108, 0 },
	{ 890, 912, -114, -36, 11 },
	-- 동쪽 끝 판(북 -40)
	{ 900, 980, -60, -38, 3 }, { 980, 1090, -64, -38, 0 },
}

-- 돌산·큰 덩어리(참고 사진의 초록 윗면 상자): { 이름, x0, x1, z0, z1, 윗면(땅 위 높이) } — 같은 이름은 위로 얹는 켜
local MASSES = {
	-- 남산: 곶 위 넷 켜(위로 갈수록 작고 북쪽으로 몰려 바다 쪽이 깎아지른 벼랑). 꼭대기 = 정자 자리
	{ "남산", 160, 400, -222, -60, 26 },
	{ "남산", 190, 370, -210, -90, 44 },
	{ "남산", 228, 340, -200, -112, 58 },
	{ "남산", 258, 312, -190, -128, 68 },
	-- 서쪽 끝 덩어리(바다를 막는 높은 상자 — 서촌에서 보면 북쪽을 가린다)
	{ "서쪽", -600, -500, -56, 60, 34 },
	{ "서쪽", -600, -540, -40, 20, 52 },
	{ "서쪽2", -500, -460, 0, 60, 18 },
	-- 동쪽 끝 덩어리
	{ "동쪽", 960, 1080, -36, 90, 30 },
	{ "동쪽", 1000, 1080, -20, 50, 46 },
	{ "동쪽2", 900, 960, 20, 90, 14 },
	-- 가운데 들판을 나누는 낮은 상자들(삼각형 법칙 — 높고 낮은 덩어리가 번갈아 가렸다 드러낸다)
	{ "서들", -250, -170, -60, 10, 16 },
	{ "서들", -235, -190, -45, -5, 28 },
	{ "중들", 40, 110, -120, -70, 12 },
	{ "동들", 700, 790, 60, 150, 20 },
	{ "동들", 715, 770, 80, 130, 32 },
	{ "동들2", 560, 620, 110, 170, 10 },
	{ "동들3", 820, 870, -40, 10, 14 },
}

-- 오르막 쐐기: { x, 낮은 끝 z, 높은 끝 z, 너비, 낮은 높이, 높은 높이 } — 남산은 남쪽에서 지그재그로 넷
local RAMPS = {
	{ 330, -14, -62, 14, 0, 26 },
	{ 240, -62, -92, 12, 26, 44 },
	{ 318, -90, -114, 10, 44, 58 },
	{ 280, -112, -130, 9, 58, 68 },
	{ -480, 104, 62, 10, 0, 18 }, -- 서쪽 덩어리 둘째로
	{ 745, 194, 152, 10, 0, 20 }, -- 동들 위로
}

-- 모래 단(만): { x0, x1, z0, z1, 윗면 } — 땅(1.9)에서 물(-3.5)로 두 계단
local SAND = {
	{ 432, 620, -186, -150, 0.2 },
	{ 444, 608, -214, -186, -2.0 },
}

-- 경계벽 잔해(세계관: 오염을 막으려 세웠다가 실패해 버려진 벽) — 바닷가를 따라 축에 맞춰 끊기며 이어진다.
-- 남산을 돌아가면 드러난다. { 틀, x, z, 돌림(0·90·180), 크기 배율? }
local RUINS = {
	{ "WallRuin_A", -395, -116, 0 },
	{ "WallRuin_B", -345, -114, 0 },
	{ "WallRuin_A", -298, -116, 0 },
	{ "WallRuin_A", -210, -116, 180, 0.85 },
	{ "WallRuin_Tower", -150, -112, 0 },
	{ "WallRuin_A", -100, -156, 0 },
	{ "WallRuin_B", -48, -154, 90 },
	{ "WallRuin_A", 0, -156, 180 },
	{ "WallRuin_A", 70, -156, 0, 0.9 },
	{ "WallRuin_Tower", 118, -150, 0, 0.9 },
}

-- 바위 상자: { x, z, 너비, 높이, 깊이, 돌림(15 의 배수) }
local ROCKS = {
	{ 140, 30, 9, 6, 8, 0 }, { 152, 40, 5, 4, 5, 15 }, { -40, -40, 8, 5, 7, 0 }, { -30, -30, 4, 3, 4, 45 },
	{ 520, -60, 10, 7, 8, 0 }, { 470, -120, 7, 5, 6, 30 }, { 530, -200, 6, 4, 5, 0 }, { 545, -206, 4, 3, 4, 15 },
	{ -520, -20, 8, 6, 7, 0 }, { -506, -8, 4, 3, 4, 30 }, { 380, 40, 9, 6, 9, 0 }, { 830, 60, 6, 4, 5, 45 },
	{ -150, 20, 8, 5, 8, 0 }, { 960, 110, 7, 5, 6, 15 }, { 430, 20, 5, 4, 5, 0 }, { -330, -60, 7, 5, 6, 0 },
}

-- 돌길(정돈된 돌길 — 절화 진입부): { 폭, 점들 } 축에 맞춰 직각으로만 꺾인다
local PATHS = {
	{ 8, { { 330, 150 }, { 330, -14 } } }, -- 도성 쪽에서 남산 첫 오르막 발치까지
	{ 7, { { 330, 40 }, { 0, 40 }, { 0, -60 }, { -150, -60 }, { -150, -100 } } }, -- 서쪽 → 벽 잔해 망루
	{ 7, { { 330, 40 }, { 530, 40 }, { 530, -150 } } }, -- 동쪽 → 모래 만
}

-- 밭: { x0, z0, x1, z1 } 두둑은 x 방향
local FIELDS = {
	{ -250, 95, -150, 155 },
	{ 400, 95, 500, 150 },
	{ -110, 70, -30, 130 },
}

-- 나무(절화 나무 모델을 복제): { x, z, 돌림, 크기 배율 }
local TREES = {
	{ -200, 40, 0, 1 }, { -180, 70, 80, 0.9 }, { -330, 120, 30, 1.1 }, { -120, 170, 120, 1 },
	{ -60, 40, 200, 0.85 }, { 20, 90, 40, 1 }, { 110, 100, 300, 1.1 }, { 180, 120, 10, 0.9 },
	{ 400, 30, 60, 1 }, { 470, 0, 150, 0.9 }, { 520, 90, 0, 1.1 }, { 640, 60, 90, 1 },
	{ 680, 20, 240, 0.85 }, { 900, 120, 30, 1 }, { 940, 120, 100, 1.1 }, { 820, 150, 0, 0.9 },
	{ -470, 90, 50, 1 }, { -520, 120, 180, 0.9 }, { -400, 150, 270, 1.2 },
	{ -380, 60, 10, 1.1 }, { -400, 95, 140, 0.9 }, { -360, 30, 220, 1 }, { -430, 120, 300, 0.85 },
	{ 70, 70, 20, 1 }, { 95, 60, 160, 0.9 }, { 120, 80, 250, 1.1 },
	{ 860, 80, 60, 1 }, { 880, 140, 200, 0.9 }, { 990, 150, 330, 1.1 },
	{ -230, 40, 300, 0.9 }, { 560, 40, 70, 1 }, { 620, 80, 160, 0.9 },
	-- 남산 첫 켜 위
	{ 200, -75, 0, 0.8 }, { 385, -80, 90, 0.75 }, { 175, -110, 45, 0.7 },
}

--=== 짓기 ===--
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local function part(name, size, cf, color, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 바위 상자 + 풀 윗판(1.2 두께). top·bottom = 월드 높이
local function block(name, x0, x1, z0, z1, top, bottom, parent, rockColor)
	local h = top - bottom
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	part(name, Vector3.new(x1 - x0, h - 1.2, z1 - z0), CFrame.new(cx, bottom + (h - 1.2) / 2, cz), rockColor or ROCK, M.Slate, parent)
	part(name .. "_풀", Vector3.new(x1 - x0, 1.2, z1 - z0), CFrame.new(cx, top - 0.6, cz), GRASS, M.Grass, parent)
end

local ok, err = pcall(function()
	local surface = workspace:FindFirstChild("Surface")
	assert(surface, "Surface 폴더가 없다")
	local kit = SS:FindFirstChild("PlainsKit")

	-- 1. 옛 지형 백업(처음 한 번만)
	local backupRoot = SS:FindFirstChild("TerrainBackup") or Instance.new("Folder")
	backupRoot.Name = "TerrainBackup"
	backupRoot.Parent = SS
	local backup = backupRoot:FindFirstChild("PlainsNorth")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "PlainsNorth"
		backup:SetAttribute("Note", "2026-10-03 평원 북쪽 시범 지역 교체 전 옛 지형 타일. 되돌리려면 FromPath 속성의 폴더로 옮긴다")
		backup.Parent = backupRoot
		local moved = 0
		local tiles = surface.World:FindFirstChild(AREA.folder)
		assert(tiles, "Surface.World." .. AREA.folder .. " 가 없다")
		for _, d in tiles:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d.Position
				if p.X > AREA.x0 and p.X < AREA.x1 and p.Z > AREA.zMin and p.Z < AREA.zMax then
					d:SetAttribute("FromPath", d.Parent:GetFullName())
					d.Parent = backup
					moved += 1
				end
			end
		end
		say("옛 타일 %d개 → ServerStorage.TerrainBackup.PlainsNorth", moved)
	else
		say("백업은 이미 있다(옛 타일 %d개) — 건너뜀", #backup:GetChildren())
	end

	-- 2. 새 폴더
	local old = surface:FindFirstChild("R_평원북")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_평원북"
	root:SetAttribute("Version", 2)
	root.Parent = surface
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end

	-- 2a. 땅 판(윗면 1.90, 두께 12)
	local land = folder("Land")
	for i, l in LAND do
		local x0, x1, zN = l[1], l[2], l[3]
		part("Land" .. i, Vector3.new(x1 - x0, 12, SOUTH - zN), CFrame.new((x0 + x1) / 2, TOP - 6, (zN + SOUTH) / 2), GRASS, M.Grass, land)
	end
	-- 2b. 바닷가 절벽 상자(물 아래 -24 까지). 땅 높이와 같은 것은 0.04 올려 땅 판과 겹친 윗면이 깜박이지 않게
	local cliffs = folder("Cliffs")
	for i, c in CLIFFS do
		block("Cliff" .. i, c[1], c[2], c[3], c[4], TOP + math.max(c[5], 0.04), -24, cliffs, if i % 2 == 0 then ROCK2 else ROCK)
	end
	-- 2c. 돌산·덩어리(같은 이름 켜는 아래 켜 윗면 2 아래에서 시작, 첫 켜는 땅에 4 묻힌다)
	local masses = folder("Masses")
	local tierTop = {}
	for i, m in MASSES do
		local name = m[1]
		local bottom = if tierTop[name] then tierTop[name] - 2 else TOP - 4
		tierTop[name] = TOP + m[6]
		block(string.format("%s_%d", name, i), m[2], m[3], m[4], m[5], TOP + m[6], bottom, masses, if i % 2 == 0 then ROCK2 else ROCK)
	end
	-- 2d. 오르막 쐐기(풀). WedgePart 는 로컬 +Z 쪽이 높고 -Z(앞) 쪽이 낮다(광선으로 재어 확인) → 높은 끝이 남(+z)이면 그대로, 북이면 반 바퀴
	local ramps = folder("Ramps")
	for i, r in RAMPS do
		local x, zl, zh, w, y0, y1 = r[1], r[2], r[3], r[4], TOP + r[5], TOP + r[6]
		local base = y0 - 2
		local up = if zh < zl then -1 else 1 -- 높은 끝 쪽(z 부호)
		local len = math.abs(zh - zl) + 3
		local cz = (zl + zh) / 2 + up * 1.5
		local wp = Instance.new("WedgePart")
		wp.Name = "Ramp" .. i
		wp.Anchored = true
		wp.Size = Vector3.new(w, y1 - base, len)
		wp.CFrame = CFrame.new(x, base + (y1 - base) / 2, cz) * CFrame.Angles(0, if up < 0 then math.pi else 0, 0)
		wp.Color, wp.Material = GRASS, M.Grass
		wp.Parent = ramps
	end
	-- 2e. 모래 단(만)
	local sand = folder("Sand")
	for i, s in SAND do
		part("Sand" .. i, Vector3.new(s[2] - s[1], s[5] + 24, s[4] - s[3]), CFrame.new((s[1] + s[2]) / 2, (s[5] - 24) / 2, (s[3] + s[4]) / 2), SANDC, M.Sand, sand)
	end

	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { root }
	local function groundY(x, z)
		local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), ray)
		return if r then r.Position.Y else TOP
	end

	-- 3a. 경계벽 잔해(블렌더 틀)
	local ruins = folder("Ruins")
	for _, e in RUINS do
		local src = kit and kit:FindFirstChild(e[1])
		if src then
			local m = src:Clone()
			m:PivotTo(CFrame.new(e[2], groundY(e[2], e[3]) - 0.3, e[3]) * CFrame.Angles(0, math.rad(e[4]), 0))
			if e[5] then
				m:ScaleTo(e[5])
			end
			m.Parent = ruins
		else
			say("틀 없음 %s", e[1])
		end
	end
	-- 3b. 바위 상자
	local rocks = folder("Rocks")
	for i, r in ROCKS do
		local y = groundY(r[1], r[2])
		part("Rock" .. i, Vector3.new(r[3], r[4], r[5]), CFrame.new(r[1], y + r[4] / 2 - 0.5, r[2]) * CFrame.Angles(0, math.rad(r[6]), 0), if i % 2 == 0 then ROCK2 else ROCK, M.Slate, rocks)
	end
	-- 3c. 돌길(직각으로 꺾임 — 마디를 반 폭씩 늘려 모서리가 비지 않게)
	local paths = folder("Paths")
	local STONE, STONE2 = RGB(160, 152, 136), RGB(146, 139, 124)
	for pi, pth in PATHS do
		local w, pts = pth[1], pth[2]
		for i = 1, #pts - 1 do
			local a = Vector3.new(pts[i][1], TOP + 0.17 + i * 0.01, pts[i][2])
			local b = Vector3.new(pts[i + 1][1], TOP + 0.17 + i * 0.01, pts[i + 1][2])
			local len = (b - a).Magnitude + w
			part(string.format("Path%d_%d", pi, i), Vector3.new(w, 0.4, len), CFrame.lookAt((a + b) / 2, b), if i % 2 == 0 then STONE2 else STONE, M.Cobblestone, paths)
		end
	end
	-- 3d. 정자(절화 키트) — 남산 꼭대기 켜 가운데
	local summit = Vector3.new(285, groundY(285, -159), -159)
	local jk = SS:FindFirstChild("JeolhwaKit")
	local pav = jk and jk:FindFirstChild("Pavilion_Jeongja")
	if pav then
		local m = pav:Clone()
		m.Name = "Pavilion_남산"
		m:PivotTo(CFrame.Angles(0, math.rad(180), 0) + m:GetPivot().Position)
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(summit.X - cf.X, (summit.Y - 0.2) - (cf.Y - size.Y / 2), summit.Z - cf.Z))
		m.Parent = root
	end
	say("남산 꼭대기 높이 %.1f", summit.Y)
	-- 3e. 밭
	local fields = folder("Fields")
	local SOIL, RIDGE = RGB(122, 100, 73), RGB(104, 84, 60)
	for fi, f in FIELDS do
		local fx0, fz0, fx1, fz1 = f[1], f[2], f[3], f[4]
		part(string.format("Field%d", fi), Vector3.new(fx1 - fx0, 0.5, fz1 - fz0), CFrame.new((fx0 + fx1) / 2, TOP + 0.2, (fz0 + fz1) / 2), SOIL, M.Ground, fields)
		local z, k = fz0 + 2, 0
		while z < fz1 - 1.5 do
			k += 1
			part(string.format("Field%d_Ridge%d", fi, k), Vector3.new(fx1 - fx0 - 3, 0.9, 1.6), CFrame.new((fx0 + fx1) / 2, TOP + 0.7, z), RIDGE, M.Ground, fields)
			z += 3.4
		end
	end
	-- 3f. 나무(절화 나무 모델을 돌아가며 복제, 바닥에 앉힌다)
	local trees = folder("Trees")
	local src = {}
	for _, t in workspace.Jeolhwa["나무"]:GetChildren() do
		if t:IsA("Model") then
			table.insert(src, t)
		end
	end
	table.sort(src, function(a, b)
		return a.Name < b.Name
	end)
	for i, t in TREES do
		local m = src[(i * 7) % #src + 1]:Clone()
		m.Name = "Tree_N" .. i
		local y = groundY(t[1], t[2])
		if t[4] ~= 1 then
			m:ScaleTo(t[4])
		end
		m:PivotTo(CFrame.Angles(0, math.rad(t[3]), 0) + m:GetPivot().Position)
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(t[1] - cf.X, (y - 0.5) - (cf.Y - size.Y / 2), t[2] - cf.Z))
		m.Parent = trees
	end
	say("땅 %d, 절벽 %d, 덩어리 %d, 오르막 %d, 잔해 %d, 바위 %d, 나무 %d", #LAND, #CLIFFS, #MASSES, #RAMPS, #RUINS, #ROCKS, #TREES)
end)
HS:PostAsync("http://127.0.0.1:34999/plainsnorth", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
