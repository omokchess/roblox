--!nocheck
--[[
	Snow3_Build.luau — 2026-10-09. 설원 3판 지상 땅(사용자 승인 설계 snow3_plan.py): 단·바닷가·오르막(편집 모드, StudioJobs).
	배치 tools/snow3_ground.py(그림을 격자로 딴 손 표, 검사 0건) → Snow3_Ground_data.luau 를 --@@DATA@@ 자리에:
	  python tools/snow3_ground.py && sed '/--@@DATA@@/r tools/Snow3_Ground_data.luau' tools/Snow3_Build.luau > tools/swamp/_snow3_run.luau && bash tools/job.sh tools/swamp/_snow3_run.luau
	차례(다시 돌려도 된다 — Surface.R_설원3 만 지우고 새로(틀린 2판 R_설원2 도 지운다)):
	  1. 처음 한 번만 백업(이름으로만): Surface.World.G_설원 → TerrainBackup.Snow_G, Surface.Zone_설원 → TerrainBackup.Snow_Zone,
	     workspace.Schneereich 의 자식 중 안쪽방·스크립트(SnowGearSpin·SnowPressRun) 빼고 → ServerStorage.Snow_Old(옛 도시 — 새 마을이 틀·방을 다시 씀)
	  2. Surface.R_설원3: Land(단 덩어리: 바위 옆 + 눈 윗판) → Cliffs(바닷가 바위 + 눈) → Ramps(벽 따라 쐐기 오르막)
	보고: /snow3build
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SNOW, ROCK, ROCK2 = RGB(236, 240, 246), RGB(112, 118, 130), RGB(98, 104, 116)
local BOTTOM = -24

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local jitterN = 0
local function jitter()
	jitterN += 1
	local c = jitterN % 8
	return Vector3.new(if c % 2 == 0 then 0.1 else -0.1, if (c // 2) % 2 == 0 then 0.1 else -0.1, if (c // 4) % 2 == 0 then 0.1 else -0.1)
end
local function part(name, size, cf, color, mat, parent, cls)
	local p = Instance.new(cls or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf + jitter()
	p.Color, p.Material = color, mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- 바위 옆 + 눈 윗판(2). 윗판은 0.2 낮추고 0.1 넓혀 뜬 듯 보이지 않게(사막과 같은 규칙)
local function block(name, x0, x1, z0, z1, top, parent, rock)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local h = top - BOTTOM - 2
	part(name, Vector3.new(x1 - x0, h, z1 - z0), CFrame.new(cx, BOTTOM + h / 2, cz), rock, M.Slate, parent)
	part(name .. "_눈", Vector3.new(x1 - x0 + 0.1, 2, z1 - z0 + 0.1), CFrame.new(cx, top - 1.2, cz), SNOW, M.Snow, parent)
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local backup = SS:FindFirstChild("TerrainBackup") or Instance.new("Folder")
	backup.Name = "TerrainBackup"
	backup.Parent = SS
	for _, mv in { { S.World, "G_설원", "Snow_G" }, { S, "Zone_설원", "Snow_Zone" } } do
		local src = mv[1]:FindFirstChild(mv[2])
		if src and not backup:FindFirstChild(mv[3]) then
			local n = #src:GetDescendants()
			src:SetAttribute("FromPath", src:GetFullName())
			src.Name = mv[3]
			src.Parent = backup
			say("백업 %s → TerrainBackup.%s (%d)", mv[2], mv[3], n)
		end
	end
	local city = workspace:FindFirstChild("Schneereich")
	if city then
		local old = SS:FindFirstChild("Snow_Old") or Instance.new("Folder")
		old.Name = "Snow_Old"
		old.Parent = SS
		local keep = { ["안쪽방"] = true, SnowGearSpin = true, SnowPressRun = true }
		local n = 0
		for _, c in city:GetChildren() do
			if not keep[c.Name] then
				c:SetAttribute("FromPath", c:GetFullName())
				c.Parent = old
				n += 1
			end
		end
		say("옛 슈네라이히 %d묶음 → ServerStorage.Snow_Old (안쪽방·스크립트는 남김)", n)
	end

	for _, name in { "R_설원3", "R_설원2" } do -- 2판(틀린 설계)도 걷는다
		local prev = S:FindFirstChild(name)
		if prev then
			prev:Destroy()
		end
	end
	local root = Instance.new("Folder")
	root.Name = "R_설원3"
	local land, cliffs, ramps = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	land.Name, cliffs.Name, ramps.Name = "Land", "Cliffs", "Ramps"
	land.Parent, cliffs.Parent, ramps.Parent = root, root, root
	for i, t in TILES do
		block(t[1], t[2], t[4], t[3], t[5], t[6], land, if i % 2 == 0 then ROCK else ROCK2)
	end
	for i, c in CLIFFS do
		block("Cliff" .. i, c[1], c[2], c[3], c[4], c[5], cliffs, if i % 2 == 0 then ROCK2 else ROCK)
	end
	-- 오르막: 쐐기(로컬 +Z 가 높다) — 끝 쪽이 높게. 밑은 바위 받침 판
	for _, r in RAMPS do
		local sx, sz, ex, ez, h0, h1, w, name = r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
		local dir = Vector3.new(ex - sx, 0, ez - sz)
		local L = dir.Magnitude
		local mid = Vector3.new((sx + ex) / 2, h0 + (h1 - h0) / 2, (sz + ez) / 2)
		local cf = CFrame.lookAt(mid, mid - dir.Unit) -- +Z = 끝 쪽(높음)
		part(name, Vector3.new(w, h1 - h0, L), cf, SNOW, M.Snow, ramps, "WedgePart")
		-- 끝 단(높은 땅 높이로 평평하게 10) — 벽 옆에서 내려설 자리
		part(name .. "_끝", Vector3.new(w, 2, 12), CFrame.lookAt(Vector3.new(ex, h1 - 1, ez), Vector3.new(ex, h1 - 1, ez) + dir.Unit) * CFrame.new(0, 0, -6), SNOW, M.Snow, ramps)
	end
	root.Parent = S
	say("새 설원 R_설원3: 땅 %d · 벼랑 %d · 오르막 %d", #TILES, #CLIFFS, #RAMPS)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snow3build", table.concat(lines, "\n"))
