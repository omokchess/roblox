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


-- 깜박임 없애기(2026-10-04 사용자: "모든 블록에다가 XYZ좌표를 각각 0.1씩 +-"): 만드는 부품마다 x·y·z 를 ±0.1 —
-- 차례로 여덟 조합을 돌려 이웃한 부품끼리 같은 면이 겹치지 않게
local jitterN = 0
local function jitter(): Vector3
	jitterN += 1
	local c = jitterN % 8
	return Vector3.new(if c % 2 == 0 then 0.1 else -0.1, if (c // 2) % 2 == 0 then 0.1 else -0.1, if (c // 4) % 2 == 0 then 0.1 else -0.1)
end
local function part(name, size, cf, color, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf + jitter()
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


--[[
	벽 밑 바위 기둥(2026-10-04 사용자: "벽면쪽 블록들의 밀도를 각각 다 다르게 … 벽면으로 판단되는 모든 곳에다가").
	후보 덩어리(축에 맞춘 바위 상자)마다 네 벽을 따라 크기 표(PILLAR_BANK, 손으로 적음)의 두 켜 기둥을 세운다.
	  - 벽마다 밀도가 다르다: 밀도 표(DENSITY)를 덩어리·벽 번호로 골라, 기둥 뒤 틈 = (1 - 밀도) × 틈 표(GAPS)
	  - 벽 바로 바깥(높이 땅+3)에 다른 단단한 것이 있으면(벽이 가려짐) 그 자리는 건너뜀 · 빼는 네모(EXCLUDE) 안도 건너뜀
	  - 보이는 높이(윗면 - 바깥 땅)가 minH 안 되면 건너뜀
]]
--[[
	벽 밑 바위 줄(2026-10-04 사용자: "이 부분 자연스러워보이는데 여기에 있는것들 참고해다가 붙이자. 함수는 취소하고").
	본보기 = 사막 서쪽 바깥 벽(T1s, x 2900, z -1012 ~ -923, 벽 높이 30)에 섰던 바위 다섯(+ 앞 잔돌 하나)을 스튜디오에서 그대로 뽑은 것.
	  { 폭, 깊이, 아래 켜 높이 비, 위 켜 높이 비, 앞 잔돌? { 폭, 깊이, 아래 비, 위 비 } } — 높이 비 = 벽 보이는 높이에 대한 비
	벽마다 본보기를 이어 붙인다: 시작 자리를 벽마다 달리하고, 한 벌마다 순서를 뒤집어(거울) 같은 줄이 붙어 나오지 않게.
	가려진 벽·빼는 네모·낮은 벽(minH 아래)은 건너뛴다.
]]
local TEMPLATE = {
	{ 8.9, 5.6, 0.24, 0.44 },
	{ 16.5, 7.8, 0.43, 0.79 },
	{ 14.9, 7.3, 0.48, 0.88, { 8.2, 9.8, 0.15, 0.29 } },
	{ 20.3, 8.6, 0.52, 0.95 },
	{ 29.0, 10.75, 0.50, 0.92 },
}
local function wallPillars(blocks, solids, exclude, groundAt, parent, colors, capColor, capMat, sideMat, minH)
	local over = OverlapParams.new()
	over.FilterType = Enum.RaycastFilterType.Include
	over.FilterDescendantsInstances = solids
	local function excluded(x, z)
		for _, e in exclude do
			if e[1] <= x and x <= e[2] and e[3] <= z and z <= e[4] then
				return true
			end
		end
		return false
	end
	local n = 0
	for bi, b in blocks do
		local pos, size = b.Position, b.Size
		local x0, x1, z0, z1 = pos.X - size.X / 2, pos.X + size.X / 2, pos.Z - size.Z / 2, pos.Z + size.Z / 2
		local topAbs = pos.Y + size.Y / 2 + 1.2
		for f, face in { { "x", z0, -1, x0, x1 }, { "x", z1, 1, x0, x1 }, { "z", x0, -1, z0, z1 }, { "z", x1, 1, z0, z1 } } do
			local axis, at, out, a0, a1 = face[1], face[2], face[3], face[4], face[5]
			-- 두 켜 바위 하나(아래 켜 넓고, 위 켜 폭 1.4·깊이 1.3 좁음)
			local function place(name, s0, s1, d, lowF, upF, gy, visible, tint)
				for li, L in { { lowF, 0, 0 }, { upF, 1.4, 1.3 } } do
					local ls0, ls1 = s0 + L[2] / 2, s1 - L[2] / 2
					local dd = d - L[3]
					local o0, o1 = at - out * 1, at + out * dd
					local bx0, bx1 = if axis == "x" then ls0 else math.min(o0, o1), if axis == "x" then ls1 else math.max(o0, o1)
					local bz0, bz1 = if axis == "x" then math.min(o0, o1) else ls0, if axis == "x" then math.max(o0, o1) else ls1
					local top = gy + visible * L[1]
					local bottom = if li == 1 then gy - 4 else gy + visible * lowF - 0.6
					block(string.format("%s_%d", name, li), bx0, bx1, bz0, bz1, top, bottom, parent, colors[(li + tint) % 2 + 1], sideMat, capColor, capMat)
					n += 1
				end
			end
			local idx = (bi * 3 + f) % #TEMPLATE -- 벽마다 시작 자리
			local step = 1
			local cursor, k = a0 + 1, 0
			while cursor < a1 - 2 do
				k += 1
				idx += step
				if idx > #TEMPLATE or idx < 1 then
					-- 한 벌 끝 → 순서를 뒤집어 거꾸로 이어 간다
					step = -step
					idx = math.clamp(idx + step * 2, 1, #TEMPLATE)
				end
				local t = TEMPLATE[idx]
				local w = math.min(t[1], a1 - cursor + 1)
				local s0, s1 = cursor, cursor + w
				local mid = (s0 + s1) / 2
				local px, pz = if axis == "x" then mid else at + out * 1.5, if axis == "x" then at + out * 1.5 else mid
				local gy = groundAt(px, pz)
				local visible = topAbs - gy
				local skip = excluded(px, pz) or visible < minH
				if not skip then
					skip = #workspace:GetPartBoundsInBox(CFrame.new(px, gy + 3, pz), Vector3.new(0.6, 0.6, 0.6), over) > 0
				end
				if not skip then
					place(string.format("Rock%d_%d_%d", bi, f, k), s0, s1, t[2], t[3], t[4], gy, visible, k)
					local fr = t[5]
					if fr and w > fr[1] + 1 then
						local fs = mid - fr[1] / 2 + 0.6
						place(string.format("Rock%d_%d_%d_앞", bi, f, k), fs, fs + fr[1], fr[2], fr[3], fr[4], gy, visible, k + 1)
					end
				end
				cursor += w - 0.6
			end
		end
	end
	return n
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
	-- 벽면 기둥(모든 바위 벽, 벽마다 밀도 다르게) — 협곡 판(돌출 빼고)·높은 바위. 빼는 자리: 곶 어귀 좁은 틈·턱 길·오르막
	local pillars = folder("WallPillars")
	local wallBlocks = {}
	for i = 1, CANYON_MAIN do
		table.insert(wallBlocks, canyon:FindFirstChild("Table" .. i))
	end
	for _, p in mesas:GetChildren() do
		if not p.Name:match("_윗면$") then
			table.insert(wallBlocks, p)
		end
	end
	local exclude = { { 3378, 3446, -1006, -954 }, { 2848, 2906, -802, -662 } }
	for _, r in RAMPS do
		table.insert(exclude, { r[1] - 16, r[2] + 16, r[3] - 16, r[4] + 16 })
	end
	local gray = RaycastParams.new()
	gray.FilterType = Enum.RaycastFilterType.Include
	gray.FilterDescendantsInstances = { land, dunes, shore, cliffs }
	local function floorAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), gray)
		return if hit then hit.Position.Y else TOP
	end
	local nPillar = wallPillars(wallBlocks, { canyon, mesas, cliffs }, exclude, floorAt, pillars, { STONE, STONE2 }, MESA_TOP, M.Sand, M.Sandstone, 8)
	say("벽 밑 바위 기둥 켜 %d", nPillar)
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
	-- 자연 돌다리(2026-10-04 사용자: "다리 가운데에는 돌 기둥을 놔서 버텨지는 것처럼, 다리 생긴 것도 자연스럽게"):
	--   폭이 다른 두 판을 엇갈려 겹침(가운데가 두껍게 처짐) · 양 끝 받침 턱(벽에서 내려온 바위) · 위에 돌 몇 · 가운데 돌기둥(아래가 넓은 두 켜)
	local bridges = folder("Bridges")
	for i, br in BRIDGES do
		local x0, x1, z0, z1, h = br[1], br[2], br[3], br[4], TOP + br[5]
		local alongX = (x1 - x0) > (z1 - z0)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local L = if alongX then x1 - x0 else z1 - z0
		local W = if alongX then z1 - z0 else x1 - x0
		local function slab(name, a0, a1, w0, w1, top, bottom, color)
			local bx0, bx1 = if alongX then cx - L / 2 + a0 else cx - W / 2 + w0, if alongX then cx - L / 2 + a1 else cx - W / 2 + w1
			local bz0, bz1 = if alongX then cz - W / 2 + w0 else cz - L / 2 + a0, if alongX then cz - W / 2 + w1 else cz - L / 2 + a1
			block(name, bx0, bx1, bz0, bz1, top, bottom, bridges, color, M.Sandstone, MESA_TOP, M.Sand)
		end
		slab("Bridge" .. i .. "_윗판", 0, L, 0, W, h, h - 4, STONE2)
		slab("Bridge" .. i .. "_아랫판", L * 0.22, L * 0.78, W * 0.12, W * 0.9, h - 3, h - 7.5, STONE) -- 가운데가 처진 배
		slab("Bridge" .. i .. "_받침1", 0, L * 0.16, W * 0.05, W * 0.95, h - 3, h - 11, STONE)
		slab("Bridge" .. i .. "_받침2", L * 0.84, L, W * 0.1, W * 0.92, h - 3, h - 9, STONE2)
		slab("Bridge" .. i .. "_턱", L * 0.35, L * 0.6, W * 0.62, W, h + 1.2, h - 1, STONE) -- 위 한쪽 솟은 턱
		-- 가운데 돌기둥: 바닥(땅)에서 다리 배 밑까지, 아래 켜가 넓다
		local pcx, pcz = cx, cz
		local foot = TOP - 4
		local belly = h - 7
		block("Bridge" .. i .. "_기둥아래", pcx - 6, pcx + 6, pcz - 5.5, pcz + 5.5, TOP + (belly - TOP) * 0.45, foot, bridges, STONE, M.Sandstone, MESA_TOP, M.Sand)
		block("Bridge" .. i .. "_기둥위", pcx - 4.2, pcx + 4.2, pcz - 3.8, pcz + 3.8, belly + 0.5, TOP + (belly - TOP) * 0.45 - 0.6, bridges, STONE2, M.Sandstone, MESA_TOP, M.Sand)
		part("Bridge" .. i .. "_돌1", Vector3.new(2.6, 2, 2.4), CFrame.new(cx + 3, h + 0.8, cz - 2) * CFrame.Angles(0, math.rad(30), 0), STONE, M.Sandstone, bridges)
		part("Bridge" .. i .. "_돌2", Vector3.new(1.8, 1.4, 1.6), CFrame.new(cx - 5, h + 0.5, cz + 2.5) * CFrame.Angles(0, math.rad(65), 0), STONE2, M.Sandstone, bridges)
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
