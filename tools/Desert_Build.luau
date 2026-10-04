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
	-- 오르막(탁상지 위로): WedgePart 는 로컬 +Z 쪽이 높다 → 높은 쪽 방향으로 돌린다(Angles(0,θ,0): 로컬 +Z → (sinθ, 0, cosθ))
	local ramps = folder("Ramps")
	local YAW = { ["+z"] = 0, ["-z"] = math.pi, ["+x"] = math.pi / 2, ["-x"] = -math.pi / 2 }
	for i, r in RAMPS do
		local x0, x1, z0, z1, lo, hi, dir = r[1], r[2], r[3], r[4], TOP + r[5], TOP + r[6], r[7]
		local base = lo - 2
		local alongX = dir == "+x" or dir == "-x"
		local run = if alongX then x1 - x0 else z1 - z0
		local width = if alongX then z1 - z0 else x1 - x0
		local wp = Instance.new("WedgePart")
		wp.Name = "Ramp" .. i
		wp.Anchored = true
		wp.Size = Vector3.new(width, hi - base, run)
		wp.CFrame = CFrame.new((x0 + x1) / 2, base + (hi - base) / 2, (z0 + z1) / 2) * CFrame.Angles(0, YAW[dir], 0)
		wp.Color, wp.Material = SAND, M.Sand
		wp.Parent = ramps
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
	ray.FilterDescendantsInstances = { land, dunes, mesas, canyon, cliffs, shore, bridges, ramps, tops }
	local rocks = folder("Rocks")
	for i, r in ROCKS do
		local hit = workspace:Raycast(Vector3.new(r[1], 400, r[2]), Vector3.new(0, -500, 0), ray)
		local y = if hit then hit.Position.Y else TOP
		part("Rock" .. i, Vector3.new(r[3], r[4], r[5]), CFrame.new(r[1], y + r[4] / 2 - 0.6, r[2]) * CFrame.Angles(0, math.rad(r[6]), 0), if i % 2 == 0 then STONE2 else STONE, M.Sandstone, rocks)
	end
	say("R_사막: 땅 %d, 절벽 %d, 해변 %d, 사구 %d, 높은 바위 %d, 협곡 판 %d, 돌덩이 %d", #LAND, #CLIFFS, #SHORE, #DUNES, #MESAS, #CANYON, #ROCKS)
end

local ok, err = pcall(build)
HS:PostAsync("http://127.0.0.1:34999/desertbuild", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
