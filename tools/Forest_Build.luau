--!nocheck
--[[
	Forest_Build.luau — 2026-10-09. 숲+평원 리메이크 1차: 옛 숲 걷기 + 새 숲 땅 판·바닷가(편집 모드, StudioJobs 로 돌린다).
	배치는 tools/forest_plan.py(구역) · tools/forest_ground.py(땅 판·바닷가 손 표) → Forest_Build_data.luau 를 --@@DATA@@ 자리에:
	  python tools/forest_ground.py && sed '/--@@DATA@@/r tools/Forest_Build_data.luau' tools/Forest_Build.luau > tools/swamp/_forest_run.luau && bash tools/job.sh tools/swamp/_forest_run.luau

	차례(다시 돌려도 된다 — Surface.R_숲2 만 지우고 새로):
	  1. 옛 숲을 처음 한 번만 ServerStorage.TerrainBackup 으로(이름으로만 고른다 — 2026-10-03 평원 때 다른 지역까지 옮긴 사고):
	     Surface.World.G_숲 → Forest_G, World.G_지협 → Forest_Isthmus, Mountains.M_숲 → Forest_M, Mountains.HillFill → Forest_HillFill(돌산),
	     Surface.R_숲 → Forest_R(큰 나무·나무 26k)
	  2. 평원 해안 조각 중 숲 땅 아래로 묻히는 것(윗면 < 3.5, 숲 판과 겹침)을 몸·_풀 짝째 TerrainBackup.PlainsCoastBuried 로(같은 높이 깜박임)
	  3. Surface.R_숲2: Land(땅 판) → Cliffs(바위 벼랑 + 풀 윗판) → Sand(모래 계단). 색은 평원 것을 그대로 읽어 쓴다(이음매가 안 보이게)
	좌표 = 월드(x 동, z 남; 북 = -z). 보고: /forestbuild
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local M = Enum.Material

--@@DATA@@

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

-- 깜박임 없애기: 만드는 부품마다 x·y·z ±0.1 을 여덟 조합으로 돌린다(사막·평원과 같은 규칙)
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

local ok, err = pcall(function()
	local S = workspace.Surface
	local backup = SS:FindFirstChild("TerrainBackup") or Instance.new("Folder")
	backup.Name = "TerrainBackup"
	backup.Parent = SS

	-- 색: 평원 것을 읽는다(옮기기 전에)
	local function sample(path, fallbackColor, fallbackMat)
		local node = S
		for _, n in path do
			node = node and node:FindFirstChild(n)
		end
		if node and node:IsA("BasePart") then
			return node.Color, node.Material
		end
		return fallbackColor, fallbackMat
	end
	local GRASS, GRASS_M = sample({ "R_평원중", "Land", "Land2" }, Color3.fromRGB(98, 140, 68), M.Grass)
	local ROCK, ROCK_M = sample({ "R_평원북", "Cliffs", "Cliff4" }, Color3.fromRGB(120, 120, 120), M.Slate)
	local CAP, CAP_M = sample({ "R_평원북", "Cliffs", "Cliff1_풀" }, GRASS, GRASS_M)
	local SAND, SAND_M = sample({ "R_평원북", "Sand", "Sand1" }, Color3.fromRGB(226, 203, 150), M.Sand)
	local ROCK2 = ROCK:Lerp(Color3.new(0, 0, 0), 0.08)
	say("색: 풀 %s / 바위 %s / 모래 %s", tostring(GRASS), tostring(ROCK), tostring(SAND))

	-- 1. 옛 숲 백업(처음 한 번)
	local moves = {
		{ S.World, "G_숲", "Forest_G" },
		{ S.World, "G_지협", "Forest_Isthmus" },
		{ S.Mountains, "M_숲", "Forest_M" },
		{ S.Mountains, "HillFill", "Forest_HillFill" },
		{ S, "R_숲", "Forest_R" },
	}
	for _, mv in moves do
		local src = mv[1]:FindFirstChild(mv[2])
		if src and not backup:FindFirstChild(mv[3]) then
			local n = #src:GetDescendants()
			src:SetAttribute("FromPath", src:GetFullName())
			src.Name = mv[3]
			src.Parent = backup
			say("백업 %s → TerrainBackup.%s (%d)", mv[2], mv[3], n)
		elseif src then
			say("경고: %s 가 아직 있는데 백업 %s 도 있다 — 건드리지 않음", mv[2], mv[3])
		end
	end

	-- 2. 묻히는 평원 해안 조각
	local function overlapsGround(p)
		local pos, s = p.Position, p.Size
		local x0, x1, z0, z1 = pos.X - s.X / 2, pos.X + s.X / 2, pos.Z - s.Z / 2, pos.Z + s.Z / 2
		for _, g in GROUND do
			if x0 < g[2] and x1 > g[1] and z0 < g[4] and z1 > g[3] then
				return true
			end
		end
		return false
	end
	local buriedBox = backup:FindFirstChild("PlainsCoastBuried") or Instance.new("Folder")
	buriedBox.Name = "PlainsCoastBuried"
	buriedBox.Parent = backup
	local moved = 0
	for _, region in { "R_평원북", "R_평원동", "R_평원중" } do
		local rf = S:FindFirstChild(region)
		for _, sub in { "Cliffs", "Sand" } do
			local f = rf and rf:FindFirstChild(sub)
			if f then
				local pick = {}
				for _, p in f:GetChildren() do
					if p:IsA("BasePart") and p.Position.Y + p.Size.Y / 2 < 3.5 and overlapsGround(p) then
						pick[(p.Name:gsub("_풀$", ""))] = true
					end
				end
				for _, p in f:GetChildren() do
					if pick[(p.Name:gsub("_풀$", ""))] then
						p:SetAttribute("FromPath", p:GetFullName())
						p.Parent = buriedBox
						moved += 1
					end
				end
			end
		end
	end
	say("묻히는 평원 해안 조각 %d개 → PlainsCoastBuried", moved)

	-- 3. 새 숲
	local old = S:FindFirstChild("R_숲2")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_숲2"
	root.Parent = S
	local land, cliffs, sand = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	land.Name, cliffs.Name, sand.Name = "Land", "Cliffs", "Sand"
	land.Parent, cliffs.Parent, sand.Parent = root, root, root

	for i, g in GROUND do
		local h = TOP - BOTTOM
		part("Land" .. i, Vector3.new(g[2] - g[1], h, g[4] - g[3]), CFrame.new((g[1] + g[2]) / 2, BOTTOM + h / 2, (g[3] + g[4]) / 2), GRASS, GRASS_M, land)
	end
	for i, c in CLIFFS do
		local x0, x1, z0, z1, top = c[1], c[2], c[3], c[4], c[5]
		local bottom = -24
		local h = top - bottom
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		part("Cliff" .. i, Vector3.new(x1 - x0, h - 1.2, z1 - z0), CFrame.new(cx, bottom + (h - 1.2) / 2, cz), if i % 2 == 0 then ROCK else ROCK2, ROCK_M, cliffs)
		-- 풀 윗판: 0.2 낮추고 옆으로 0.1 넓힌다(사막과 같은 규칙 — 뜬 것처럼 안 보이게, 옆면 깜박임 없게)
		part("Cliff" .. i .. "_풀", Vector3.new(x1 - x0 + 0.1, 1.2, z1 - z0 + 0.1), CFrame.new(cx, top - 0.8, cz), CAP, CAP_M, cliffs)
	end
	for i, s in SANDS do
		local x0, x1, z0, z1, top = s[1], s[2], s[3], s[4], s[5]
		local bottom = -24
		part("Sand" .. i, Vector3.new(x1 - x0, top - bottom, z1 - z0), CFrame.new((x0 + x1) / 2, (top + bottom) / 2, (z0 + z1) / 2), SAND, SAND_M, sand)
	end
	say("새 숲 R_숲2: 땅 판 %d · 벼랑 %d(+풀) · 모래 %d", #GROUND, #CLIFFS, #SANDS)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/forestbuild", table.concat(lines, "\n"))
