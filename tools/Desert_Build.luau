--!nocheck
--[[
	Desert_Build.luau — 2026-10-04. 사막 섬(제니스) 새 지형(편집 모드, StudioJobs 로 돌린다).
	배치는 tools/desert_plan.py 표(손 배치·검사 0건) → Desert_Build_data.luau 를 아래 --@@DATA@@ 자리에 끼운다:
	  sed '/--@@DATA@@/r tools/Desert_Build_data.luau' tools/Desert_Build.luau > tools/swamp/_desert_run.luau && bash tools/job.sh tools/swamp/_desert_run.luau

	차례(다시 돌려도 된다 — Surface.R_사막 만 지우고 새로):
	  1. 옛 지형을 처음 한 번만 ServerStorage.TerrainBackup 으로: Surface.World.G_사막 → Desert, Surface.Mountains 의 Mt_사막_* → DesertMountains
	     (2026-10-03 평원 때 폴더를 안 가려 다른 지역 타일까지 옮긴 사고 — 여기서는 폴더 이름·이름 머리로만 고른다)
	  2. Surface.R_사막: 땅 판(LAND) → 바닷가 사암 절벽(CLIFFS) → 모래 해변 계단(SHORE) → 사구 단(DUNES) → 메사·첨탑(MESAS) → 바위(ROCKS)
	좌표 = 월드(x 동, z 남; 북 = -z). 보고: /desertbuild
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SAND = RGB(226, 203, 150)
local SAND_DARK = RGB(216, 186, 130) -- 사구 옆면(너무 어두우면 올리브 줄처럼 보였다)
local STONE = RGB(212, 128, 82) -- 사암 재질이 어둡게 그려져 밝게 잡는다
local STONE2 = RGB(224, 146, 98)
local MESA_TOP = RGB(208, 152, 104)

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

-- 옆(side) 상자 + 윗판(1.2). top·bottom = 월드 높이
local function block(name, x0, x1, z0, z1, top, bottom, parent, side, sideMat, cap, capMat)
	local h = top - bottom
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	part(name, Vector3.new(x1 - x0, h - 1.2, z1 - z0), CFrame.new(cx, bottom + (h - 1.2) / 2, cz), side, sideMat, parent)
	part(name .. "_윗면", Vector3.new(x1 - x0, 1.2, z1 - z0), CFrame.new(cx, top - 0.6, cz), cap, capMat, parent)
end

local function build()
	local surface = workspace:FindFirstChild("Surface")
	assert(surface, "Surface 폴더가 없다")

	-- 1. 옛 지형 백업(처음 한 번만)
	local backup = SS:FindFirstChild("TerrainBackup") or Instance.new("Folder")
	backup.Name = "TerrainBackup"
	backup.Parent = SS
	local world = surface:FindFirstChild("World")
	local oldTiles = world and world:FindFirstChild("G_사막")
	if oldTiles and not backup:FindFirstChild("Desert") then
		oldTiles.Name = "Desert"
		oldTiles:SetAttribute("Note", "2026-10-04 사막 새 지형 교체 전 옛 타일(Surface.World.G_사막)")
		oldTiles.Parent = backup
		say("옛 타일 G_사막 → TerrainBackup.Desert")
	end
	local mountains = surface:FindFirstChild("Mountains")
	if mountains then
		-- Mt_사막_* 파트는 Mountains 안 여러 겹 아래에 있다 → 자손을 이름 머리로 고른다(남은 것만 옮기므로 다시 돌려도 된다)
		local keep = backup:FindFirstChild("DesertMountains") or Instance.new("Folder")
		keep.Name = "DesertMountains"
		keep:SetAttribute("Note", "2026-10-04 Surface.Mountains 의 Mt_사막_* (옛 붉은 언덕)")
		keep.Parent = backup
		local moved = 0
		for _, d in mountains:GetDescendants() do
			if d:IsA("BasePart") and d.Name:sub(1, #"Mt_사막_") == "Mt_사막_" then
				d:SetAttribute("FromPath", d:GetFullName())
				d.Parent = keep
				moved += 1
			end
		end
		say("옛 붉은 언덕 Mt_사막_* %d → TerrainBackup.DesertMountains", moved)
	end

	-- 2. 새 지형
	local old = surface:FindFirstChild("R_사막")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_사막"
	root.Parent = surface
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	local land = folder("Land")
	for i, l in LAND do
		local x0, x1, z0, z1 = l[1], l[2], l[3], l[4]
		part("Land" .. i, Vector3.new(x1 - x0, 14, z1 - z0), CFrame.new((x0 + x1) / 2, TOP - 7, (z0 + z1) / 2), SAND, M.Sand, land)
	end
	local cliffs = folder("Cliffs")
	for i, c in CLIFFS do
		block("Cliff" .. i, c[1], c[2], c[3], c[4], TOP + math.max(c[5], 0.04), -24, cliffs, if i % 2 == 0 then STONE2 else STONE, M.Sandstone, SAND, M.Sand)
	end
	local shore = folder("Shore")
	for i, s in SHORE do
		part("Shore" .. i, Vector3.new(s[2] - s[1], s[5] + 24, s[4] - s[3]), CFrame.new((s[1] + s[2]) / 2, (s[5] - 24) / 2, (s[3] + s[4]) / 2), SAND, M.Sand, shore)
	end
	-- 사구(바닥 굴곡): 켜 없이 상자 하나씩, 서로 겹쳐 오르내림(2026-10-04 사용자: 계단형 말고 바닥 굴곡을 많이)
	local dunes = folder("Dunes")
	for i, d in DUNES do
		block("Dune" .. i, d[1], d[2], d[3], d[4], TOP + d[5], TOP - 4, dunes, SAND_DARK, M.SmoothPlastic, SAND, M.Sand)
	end
	-- 높은 바위: 상자 하나(층계 없음). 같은 무리는 서로 겹친 덩어리
	local mesas = folder("Mesas")
	for i, m in MESAS do
		block(string.format("%s_%d", m[1], i), m[2], m[3], m[4], m[5], TOP + m[6], TOP - 4, mesas, if i % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
	end
	-- 협곡 탁상지: 붉은 바위 높은 판들, 그 틈이 협곡 바닥(땅)
	local canyon = folder("Canyon")
	for i, c in CANYON do
		block("Table" .. i, c[1], c[2], c[3], c[4], TOP + c[5], TOP - 4, canyon, if i % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
	end
	-- 협곡 벽 바위(손 배치 — 2026-10-04 사용자: 자동 생성 무늬는 사람이 꾸민 것 같다): 무너져 나온 덩어리·처마
	local walls = folder("WallRocks")
	for i, w in WALL_ROCKS do
		local bottom = if w[5] > 0 then TOP + w[5] else TOP - 4
		block("WallRock" .. i, w[1], w[2], w[3], w[4], TOP + w[6], bottom, walls, if i % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
	end
	-- 들판 → 서쪽 벽 위 바위 턱 길(손 배치) + 밑동 모래 둔덕
	local ledges = folder("Ledges")
	for i, l in LEDGES do
		block("Ledge" .. i, l[1], l[2], l[3], l[4], TOP + l[5], TOP - 4, ledges, if i % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
	end
	for i, d in LEDGE_SAND do
		block("LedgeSand" .. i, d[1], d[2], d[3], d[4], TOP + d[5], TOP - 4, ledges, SAND_DARK, M.SmoothPlastic, SAND, M.Sand)
	end
	--[[
		오르막 = 바위 계단(2026-10-04 사용자: 매끈한 경사길 말고 계단식으로 풍경과 녹이게).
		표(RAMPS)의 칸을 높은 쪽으로 단마다 높이 ≤ 2 로 나눈 사암 단(옆 = 탁상지와 같은 사암, 윗면 = 붉은 모래)을 쌓는다.
		단마다 폭·옆 위치를 조금씩 엇갈리게(규칙 반복), 세 단마다 바깥 옆에 돌덩이 — 깎아 만든 길처럼.
	]]
	local ramps = folder("Ramps")
	local SHIFT = { 0, 0.8, -0.6, 0.4, -0.9, 0.5, -0.3 }
	for i, r in RAMPS do
		local x0, x1, z0, z1, lo, hi, dir = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
		local alongX = dir == "+x" or dir == "-x"
		local sign = if dir == "+x" or dir == "+z" then 1 else -1
		local a0, a1 = if alongX then x0 else z0, if alongX then x1 else z1 -- 오르는 축
		local b0, b1 = if alongX then z0 else x0, if alongX then z1 else x1 -- 가로 축
		--[[ 2026-10-04 사용자: "계단도 형태를 그냥 지형처럼 올라갈 수 있게" → 고른 단 대신 들쭉날쭉한 바위 턱.
		     턱 높이(≤ 2)·깊이·폭·옆 위치를 무늬로 엇갈려, 계단이 아니라 비탈의 바위 턱을 밟고 오르는 것처럼 ]]
		local RISE = { 1.4, 2.0, 1.1, 1.8, 1.5, 1.2, 1.9 }
		local RUN = { 1.2, 0.8, 1.4, 0.9, 1.1, 1.3 }
		local steps, total = {}, 0
		while total < hi - lo - 0.01 do
			local rr = math.min(RISE[(#steps % #RISE) + 1], hi - lo - total)
			total += rr
			table.insert(steps, total)
		end
		local n = #steps
		local runs, runSum = {}, 0
		for k = 1, n do
			runs[k] = RUN[(k % #RUN) + 1]
			runSum += runs[k]
		end
		local acc = 0
		for k = 1, n do
			local top = TOP + lo + steps[k]
			local depth = (a1 - a0) * runs[k] / runSum
			local s0 = if sign > 0 then a0 + acc else a1 - acc - depth
			acc += depth
			local s1 = s0 + depth + 0.6 -- 턱끼리 살짝 겹쳐 틈 없이
			-- 턱마다 옆으로 크게 엇갈리고 폭도 달라 계단 줄이 아니라 비탈의 바위 턱으로(폭 ±5, 옆 ±6)
			local jog = SHIFT[(k % #SHIFT) + 1] * 7
			local w0, w1 = b0 + jog - (k % 3) * 2.5, b1 + jog + ((k + 1) % 3) * 2.5
			local bx0, bx1, bz0, bz1 = if alongX then s0 else w0, if alongX then s1 else w1, if alongX then w0 else s0, if alongX then w1 else s1
			block(string.format("Step%d_%d", i, k), bx0, bx1, bz0, bz1, top, TOP - 4, ramps, if k % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
			if k % 2 == 0 then
				-- 바깥 옆 돌덩이(번갈아 양쪽)
				local side = if (k // 3) % 2 == 0 then w0 - 2.2 else w1 + 2.2
				local mid = (s0 + s1) / 2
				local cx, cz = if alongX then mid else side, if alongX then side else mid
				part(string.format("StepRock%d_%d", i, k), Vector3.new(3.6, 3, 3.2), CFrame.new(cx, top + 0.6, cz) * CFrame.Angles(0, math.rad(k * 23), 0), STONE, M.Sandstone, ramps)
			end
		end
		-- 무너진 비탈: 계단 양옆에 높은 쪽(벽)에서 내려오는 바위 턱 셋 — 계단이 벽에 붙인 판이 아니라 무너진 바위 비탈을 깎은 길로 보이게
		local TALUS = { { 0.45, 0.75, 4, 10 }, { 0.7, 0.45, 9, 7 }, { 0.9, 0.2, 14, 6 } } -- { 높은 끝에서부터 덮는 길이 비율, 높이 비율, 바깥 거리, 폭 }
		for t, tl in TALUS do
			local len = (a1 - a0) * tl[1]
			local s0 = if sign > 0 then a1 - len else a0
			local s1 = s0 + len
			local top = TOP + lo + (hi - lo) * tl[2]
			for side = -1, 1, 2 do
				local edge = if side < 0 then b0 - tl[3] + (t - 1) * 1.5 else b1 + tl[3] - (t - 1) * 1.5
				local c0, c1 = math.min(edge, edge - side * tl[4]), math.max(edge, edge - side * tl[4])
				local bx0, bx1, bz0, bz1 = if alongX then s0 else c0, if alongX then s1 else c1, if alongX then c0 else s0, if alongX then c1 else s1
				block(string.format("Talus%d_%d_%d", i, t, side), bx0, bx1, bz0, bz1, top, TOP - 4, ramps, if t % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
			end
		end
	end
	-- 자연 돌다리(협곡 위, 두께 5)
	local bridges = folder("Bridges")
	for i, br in BRIDGES do
		block("Bridge" .. i, br[1], br[2], br[3], br[4], TOP + br[5], TOP + br[5] - 5, bridges, STONE2, M.Sandstone, MESA_TOP, M.Sand)
	end
	-- 히든 분지 표지(나중에 보상·제단을 다는 자리) — 속성만 붙인 빈 부품
	local hs = HIDDEN[1]
	local hidden = folder("Hidden")
	hidden:SetAttribute("Note", "협곡 끝 곶 안 히든 분지(2026-10-04). 거대 뼈·제단은 Desert_Bones 가 이 폴더에 둔다")
	local marker = part("HiddenArea", Vector3.new(hs[2] - hs[1], 1, hs[4] - hs[3]), CFrame.new((hs[1] + hs[2]) / 2, TOP + 0.5, (hs[3] + hs[4]) / 2), SAND, M.Sand, hidden)
	marker.Transparency, marker.CanCollide, marker.CanQuery, marker.CanTouch = 1, false, false, true

	-- 탁상지 위 꾸밈 판(모래 더미·바위턱) — 가운데 땅 높이를 재서 그 위에
	local tops = folder("TopPatches")
	local tray = RaycastParams.new()
	tray.FilterType = Enum.RaycastFilterType.Include
	tray.FilterDescendantsInstances = { canyon }
	for i, t in TOP_PATCHES do
		local hit = workspace:Raycast(Vector3.new((t[1] + t[2]) / 2, 400, (t[3] + t[4]) / 2), Vector3.new(0, -500, 0), tray)
		local y = if hit then hit.Position.Y else TOP
		if t[6] == "바위" then
			block("TopRock" .. i, t[1], t[2], t[3], t[4], y + t[5], y - 2, tops, STONE2, M.Sandstone, MESA_TOP, M.Sand)
		else
			block("TopSand" .. i, t[1], t[2], t[3], t[4], y + t[5], y - 2, tops, SAND_DARK, M.SmoothPlastic, SAND, M.Sand)
		end
	end

	-- 바위
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { land, dunes, mesas, canyon, cliffs, shore, bridges, ramps, tops, ledges, walls }
	local rocks = folder("Rocks")
	for i, r in ROCKS do
		local hit = workspace:Raycast(Vector3.new(r[1], 400, r[2]), Vector3.new(0, -500, 0), ray)
		local y = if hit then hit.Position.Y else TOP
		part("Rock" .. i, Vector3.new(r[3], r[4], r[5]), CFrame.new(r[1], y + r[4] / 2 - 0.6, r[2]) * CFrame.Angles(0, math.rad(r[6]), 0), if i % 2 == 0 then STONE2 else STONE, M.Sandstone, rocks)
	end
	-- 턱 길 위 작은 돌 · 탑바위(아래로 갈수록 넓은 상자 켜 + 꼭대기 작은 돌) — 모두 손 배치표 그대로
	for i, r in LEDGE_STONES do
		local hit = workspace:Raycast(Vector3.new(r[1], 400, r[2]), Vector3.new(0, -500, 0), ray)
		local y = if hit then hit.Position.Y else TOP
		part("LedgeStone" .. i, Vector3.new(r[3], r[4], r[5]), CFrame.new(r[1], y + r[4] / 2 - 0.4, r[2]) * CFrame.Angles(0, math.rad(r[6]), 0), if i % 2 == 0 then STONE2 else STONE, M.Sandstone, rocks)
	end
	local forms = folder("Formations")
	for i, f in FORMATIONS do
		local hit = workspace:Raycast(Vector3.new(f[2], 400, f[3]), Vector3.new(0, -500, 0), ray)
		local y = if hit then hit.Position.Y else TOP
		local bottom = y - 2
		local topY = y
		for k, L in f[4] do
			local cx, cz = f[2] + L[4], f[3] + L[5]
			topY = (if k == 1 then y else topY) + L[3]
			block(string.format("%s_%d", f[1], k), cx - L[1] / 2, cx + L[1] / 2, cz - L[2] / 2, cz + L[2] / 2, topY, bottom, forms, if k % 2 == 0 then STONE2 else STONE, M.Sandstone, MESA_TOP, M.Sand)
			bottom = topY - 0.6
		end
		for k, st in f[5] do
			part(string.format("%s_돌%d", f[1], k), Vector3.new(st[1], st[2], st[3]), CFrame.new(f[2] + st[4], topY + st[2] / 2 - 0.3, f[3] + st[5]) * CFrame.Angles(0, math.rad(k * 41 + i * 13), 0), if k % 2 == 0 then STONE else STONE2, M.Sandstone, forms)
		end
	end
	say("R_사막: 땅 %d, 절벽 %d, 해변 %d, 사구 %d, 높은 바위 %d, 협곡 판 %d, 돌덩이 %d", #LAND, #CLIFFS, #SHORE, #DUNES, #MESAS, #CANYON, #ROCKS)
end

local ok, err = pcall(build)
HS:PostAsync("http://127.0.0.1:34999/desertbuild", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
