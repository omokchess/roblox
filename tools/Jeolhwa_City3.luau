--!nocheck
--[[
	Jeolhwa_City3.luau — 평원의 도성 절화 3판. (2026-09-26)

	2판은 담 두른 필지 네 종류를 길 양쪽에 같은 간격으로 늘어놓아, 위에서 보면 바둑판이고
	길에 서면 어디나 같은 장면이었다. 궁은 넓은 빈 박석 마당에 건물 다섯 채뿐이었다.
	3판은
	  * 궁을 정문(광화문형) → 금천과 다리 → 중문과 행각으로 두른 정전 마당 → 북문 → 침전
	    축으로 세우고, 서쪽에 경회루 연못과 궐내각사, 동쪽에 동궁과 후원을 둔다
	  * 도성은 구역마다 성격과 밀도를 달리한다. 북촌은 골목 담을 맞댄 기와집,
	    저자는 운종가 행랑과 종루 선 저잣마당, 남촌은 초가 무리와 논밭
	  * 길은 광장에서 방사로 나가고 바깥 순환길이 끝을 이어 막다른 길이 없다

	**배치는 tools/jeolhwa_plan.py 표에 손으로 적었다.** 그 파일이 겹침을 검사하고
	평면도를 그리고 이 스크립트가 읽는 표(Jeolhwa_City3_data.luau)를 뽑는다.
	붙여 넣는 파일은 --@@DATA@@ 자리에 그 표를 끼운 Jeolhwa_City3_run.luau 다.

	틀은 ServerStorage.JeolhwaKit 에 이미 색과 충돌을 입혀 두었다(Jeolhwa_City, Jeolhwa_Kit2).
	다시 돌리면 Workspace.Jeolhwa 만 새로 짓는다. 걸린 원래 나무는 그루째
	ServerStorage.Jeolhwa_ClearedFlora 로 옮기고, 다시 돌릴 때 먼저 제자리로 돌린다.
]]
--@@DATA@@

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
local C = {
	pave = RGB(176, 172, 158), -- 박석
	rim = RGB(193, 190, 176), -- 갓돌. 틀의 Stylobate 와 같다
	masonry = RGB(157, 153, 139),
	bed = RGB(54, 62, 56),
	water = RGB(72, 112, 116),
	dirt = RGB(150, 128, 96),
	soil = RGB(122, 100, 73),
	crop = RGB(108, 132, 66),
}

--==================================================================== 도구
local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

-- 모델을 피벗 x 축으로만 늘인다. 담과 행각 토막 길이를 두 끝에 맞추려는 것이다
local function stretchX(model, f)
	local frame = model:GetPivot()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local r = frame:ToObjectSpace(p.CFrame)
			local R, U, L = r.RightVector, r.UpVector, r.LookVector
			local ax = { math.abs(R.X), math.abs(U.X), math.abs(L.X) }
			local s = p.Size
			if ax[1] >= ax[2] and ax[1] >= ax[3] then
				s = Vector3.new(s.X * f, s.Y, s.Z)
			elseif ax[2] >= ax[3] then
				s = Vector3.new(s.X, s.Y * f, s.Z)
			else
				s = Vector3.new(s.X, s.Y, s.Z * f)
			end
			p.Size = s
			p.CFrame = frame * CFrame.new(r.X * f, r.Y, r.Z) * r.Rotation
		end
	end
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("JeolhwaKit"), "ServerStorage.JeolhwaKit 이 없다")
	for _, list in ipairs({ D.PALACE, D.TOWN }) do
		for _, e in ipairs(list) do
			assert(kit:FindFirstChild(e[1]), e[1] .. " 틀이 없다. Jeolhwa_Kit2 를 먼저 돌려라")
		end
	end

	--==================================================================== 판
	-- 2판은 지우지 않고 ServerStorage 로 치워 둔다. 3판을 다시 돌릴 때는 3판만 새로 짓는다
	local old = workspace:FindFirstChild("Jeolhwa")
	if old then
		if old:GetAttribute("Version") ~= 3 and not SS:FindFirstChild("Jeolhwa_v2_backup") then
			old.Name = "Jeolhwa_v2_backup"
			old.Parent = SS
			say("2판을 ServerStorage.Jeolhwa_v2_backup 으로 옮겼다")
		else
			old:Destroy()
		end
	end
	local city = Instance.new("Folder")
	city.Name = "Jeolhwa"
	city:SetAttribute("Version", 3)
	city.Parent = workspace
	local function folder(path)
		local f = city
		for name in string.gmatch(path, "[^/]+") do
			local c = f:FindFirstChild(name)
			if not c then
				c = Instance.new("Folder")
				c.Name = name
				c.Parent = f
			end
			f = c
		end
		return f
	end
	local FStone, FWater, FRoads, FTrees = folder("돌"), folder("물"), folder("길"), folder("나무")

	local G = workspace.Surface.World["G_평원"]
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local rpAll = RaycastParams.new()
	rpAll.FilterType = Enum.RaycastFilterType.Include
	rpAll.FilterDescendantsInstances = { G, FStone }
	local function groundY(x, z, rp)
		local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp or rpAll)
		return h and h.Position.Y
	end
	-- 사각형 위를 16 간격으로 재어 가장 낮은 곳과 높은 곳
	local function span(x0, z0, x1, z1, rp)
		local lo, hi = math.huge, -math.huge
		local nx, nz = math.max(2, math.ceil((x1 - x0) / 16)), math.max(2, math.ceil((z1 - z0) / 16))
		for i = 0, nx do
			for j = 0, nz do
				local gy = groundY(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz, rp)
				assert(gy, string.format("(%.0f,%.0f) 아래에 땅이 없다", x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return lo, hi
	end

	local nParts = 0
	local function part(name, cf, size, color, mat, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		nParts += 1
		return p
	end
	-- 윗면이 top 인 판. 밑은 판 아래 가장 낮은 땅보다 0.9 깊게 묻는다
	local function slab(name, x0, z0, x1, z1, top, color, mat, parent)
		local lo = span(x0, z0, x1, z1, rpG)
		local bot = math.min(lo, top - 0.4) - 0.9
		return part(name, CFrame.new((x0 + x1) / 2, (top + bot) / 2, (z0 + z1) / 2),
			Vector3.new(x1 - x0, top - bot, z1 - z0), color, mat, parent)
	end
	-- 넓은 자리는 48 이하 조각으로 나눈다. 윗면은 모두 같은 높이다
	local function tiled(name, x0, z0, x1, z1, top, color, mat, parent)
		local nx, nz = math.ceil((x1 - x0) / 48), math.ceil((z1 - z0) / 48)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				slab(string.format("%s_%d_%d", name, i, j),
					x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz,
					x0 + (x1 - x0) * (i + 1) / nx, z0 + (z1 - z0) * (j + 1) / nz, top, color, mat, parent)
			end
		end
	end
	-- 윗면 top 에서 바깥(dx, dz) 쪽으로 아래 바닥까지 내려가는 계단. (x, z) 는 가장자리 가운데
	local function stepsDown(name, x, z, dx, dz, width, top, parent, belowFn)
		local below = belowFn and belowFn(x + dx * 6, z + dz * 6, top) or groundY(x + dx * 6, z + dz * 6)
		assert(below, name .. " 계단 아래에 바닥이 없다")
		local drop = top - below
		if drop < 0.5 then
			return 0
		end
		local n = math.ceil(drop / 0.9)
		local rot = (dx ~= 0) and CFrame.Angles(0, math.rad(90), 0) or CFrame.new()
		for k = 1, n do
			local stTop = top - drop * k / (n + 1)
			local off = 2.2 * (k - 0.5)
			local bot = below - 1
			part(string.format("%s_Step%d", name, k),
				CFrame.new(x + dx * off, (stTop + bot) / 2, z + dz * off) * rot,
				Vector3.new(width, stTop - bot, 2.3), C.rim, M.Limestone, parent)
		end
		return n
	end

	--==================================================================== 1. 돌 바닥
	local ringTop
	for _, p in ipairs(D.PAVES) do
		local name, x0, z0, x1, z1, kind = p[1], p[2], p[3], p[4], p[5], p[6]
		local _, hi = span(x0, z0, x1, z1, rpG)
		local f = folder("돌/" .. name)
		if kind == "ring" then
			-- 행각 마당 기단. 한 높이로 평평해야 행각 토막 지붕이 층지지 않는다
			ringTop = hi + 0.8
			tiled("Base", x0, z0, x1, z1, ringTop, C.masonry, M.Slate, f)
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			part("Rim_S", CFrame.new(cx, ringTop - 0.3, z0 + 1), Vector3.new(x1 - x0 + 0.6, 0.8, 2.2), C.rim, M.Limestone, f)
			part("Rim_N", CFrame.new(cx, ringTop - 0.3, z1 - 1), Vector3.new(x1 - x0 + 0.6, 0.8, 2.2), C.rim, M.Limestone, f)
			part("Rim_W", CFrame.new(x0 + 1, ringTop - 0.3, cz), Vector3.new(2.2, 0.8, z1 - z0 - 4.6), C.rim, M.Limestone, f)
			part("Rim_E", CFrame.new(x1 - 1, ringTop - 0.3, cz), Vector3.new(2.2, 0.8, z1 - z0 - 4.6), C.rim, M.Limestone, f)
			-- 가운데 어도. 중문에서 정전 계단까지 한 켜 높인 돌길
			part("Eodo", CFrame.new(225, ringTop + 0.15, 745.5), Vector3.new(12, 0.3, 33), C.rim, M.Limestone, f)
			-- 품계석. 어도 양옆에 여섯씩
			for k = 0, 5 do
				for _, sx in ipairs({ -1, 1 }) do
					part(string.format("Pumgye_%d_%d", k, sx), CFrame.new(225 + sx * 13, ringTop + 1.1, 734 + k * 5),
						Vector3.new(1.4, 2.2, 1.0), C.rim, M.Limestone, f)
				end
			end
			say("행각 기단 윗면 %.2f", ringTop)
		else
			tiled("Pave", x0, z0, x1, z1, hi + 0.3, C.pave, M.Limestone, f)
		end
	end
	assert(ringTop, "행각 기단(ring) 자리가 표에 없다")

	--==================================================================== 2. 물
	local pools = {}
	for _, p in ipairs(D.POOLS) do
		local name, x0, z0, x1, z1 = p[1], p[2], p[3], p[4], p[5]
		local lo, hi = span(x0 - 2, z0 - 2, x1 + 2, z1 + 2)
		local canal = (z1 - z0) < 12 or (x1 - x0) < 12
		local rimTop = hi + (canal and 1.0 or 1.6)
		local waterTop = rimTop - 0.5
		local bedTop = hi + 0.05
		local f = folder("물/" .. name)
		local sf = folder("돌/" .. name)
		local bot = lo - 1
		local T = 1.5
		part("Rim_S", CFrame.new((x0 + x1) / 2, (rimTop + bot) / 2, z0 - T / 2), Vector3.new(x1 - x0 + 2 * T, rimTop - bot, T), C.rim, M.Limestone, sf)
		part("Rim_N", CFrame.new((x0 + x1) / 2, (rimTop + bot) / 2, z1 + T / 2), Vector3.new(x1 - x0 + 2 * T, rimTop - bot, T), C.rim, M.Limestone, sf)
		part("Rim_W", CFrame.new(x0 - T / 2, (rimTop + bot) / 2, (z0 + z1) / 2), Vector3.new(T, rimTop - bot, z1 - z0), C.rim, M.Limestone, sf)
		part("Rim_E", CFrame.new(x1 + T / 2, (rimTop + bot) / 2, (z0 + z1) / 2), Vector3.new(T, rimTop - bot, z1 - z0), C.rim, M.Limestone, sf)
		part("Bed", CFrame.new((x0 + x1) / 2, (bedTop + bot) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, bedTop - bot, z1 - z0), C.bed, M.Slate, sf)
		local w = part("Water", CFrame.new((x0 + x1) / 2, (waterTop + bedTop) / 2, (z0 + z1) / 2),
			Vector3.new(x1 - x0, waterTop - bedTop, z1 - z0), C.water, M.Glass, f)
		w.Transparency = 0.25
		w.Reflectance = 0.08
		w.CanCollide = false
		w.CastShadow = false
		pools[#pools + 1] = { name = name, x0 = x0, z0 = z0, x1 = x1, z1 = z1, rimTop = rimTop }
		say("못 %s 둘레 %.2f 물 %.2f", name, rimTop, waterTop)
	end
	local function poolAt(x, z)
		for _, p in ipairs(pools) do
			if x >= p.x0 - 2 and x <= p.x1 + 2 and z >= p.z0 - 2 and z <= p.z1 + 2 then
				return p
			end
		end
	end
	for i, s in ipairs(D.ISLANDS) do
		local p = assert(poolAt((s[1] + s[3]) / 2, (s[2] + s[4]) / 2), "섬이 못 밖에 있다")
		slab("Island_" .. i, s[1], s[2], s[3], s[4], p.rimTop + 0.2, C.rim, M.Limestone, folder("돌/" .. p.name))
	end
	task.wait()

	--==================================================================== 3. 건물
	local placed = {}
	local foundations, maxGap = 0, 0
	local function place(kind, x, z, yaw, parent, stretch)
		local m = kit[kind]:Clone()
		if stretch and math.abs(stretch - 1) > 0.001 then
			stretchX(m, stretch)
		end
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		local frame = m:GetPivot()
		local minY = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				if c.Y - e.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - e.X), math.max(x1, c.X + e.X)
					z0, z1 = math.min(z0, c.Z - e.Z), math.max(z1, c.Z + e.Z)
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s (%.0f,%.0f) 발자국 (%.0f,%.0f) 아래에 땅이 없다", kind, x, z, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - (frame.Y + minY), 0))
		if hi - lo > 0.25 then
			local f = Instance.new("Part")
			f.Name = "Foundation"
			f.Anchored = true
			f.Size = Vector3.new(x1 - x0 + 1.0, hi - lo + 1.0, z1 - z0 + 1.0)
			f.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))) * frame.Rotation
				+ Vector3.new(0, (lo - 1.0 + hi) / 2 - frame.Y, 0)
			f.Color = C.masonry
			f.Material = M.Slate
			f.TopSurface = Enum.SurfaceType.Smooth
			f.BottomSurface = Enum.SurfaceType.Smooth
			f.Parent = m
			foundations += 1
			maxGap = math.max(maxGap, hi - lo)
		end
		placed[#placed + 1] = { m = m, kind = kind }
		return m
	end

	local count = 0
	for _, list in ipairs({ D.PALACE, D.TOWN }) do
		for _, e in ipairs(list) do
			local m = place(e[1], e[2], e[3], e[4], folder(e[5]))
			m.Name = e[1]
			count += 1
			if count % 6 == 0 then
				task.wait()
			end
		end
	end
	for ci, c in ipairs(D.CORRIDORS) do
		local ax, az, bx, bz, yaw, n = c[1], c[2], c[3], c[4], c[5], c[6]
		local L = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		for k = 1, n do
			local t = (k - 0.5) / n
			local m = place("Corridor", ax + (bx - ax) * t, az + (bz - az) * t, yaw, folder("궁/행각"), L / n / 20)
			m.Name = string.format("Corridor_%d_%d", ci, k)
		end
	end
	for _, g in ipairs(D.GATES) do
		local m = place("Wall_GateTile", g[1], g[2], g[3], folder(g[4]))
		m.Name = "Wall_GateTile"
	end
	task.wait()

	-- 담. 두 끝 사이를 20 에 가까운 토막으로 고르게 나눠 늘여 붙인다
	local nWalls = 0
	for wi, w in ipairs(D.WALLS) do
		local kind, ax, az, bx, bz, grp = w[1], w[2], w[3], w[4], w[5], w[6]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = math.max(1, math.floor(len / 20 + 0.5))
		local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
		local f = folder(grp .. "/담")
		for k = 1, n do
			local t = (k - 0.5) / n
			local m = place(kind, ax + (bx - ax) * t, az + (bz - az) * t, yaw, f, len / n / 20)
			m.Name = string.format("%s_%d_%d", kind, wi, k)
			nWalls += 1
		end
		if wi % 8 == 0 then
			task.wait()
		end
	end

	-- 다리. 건물을 다 앉힌 뒤에 놓는다. 끝이 누각 기단이나 섬에 닿는지 알아야 계단을 붙일지 정한다
	local rpBelow = RaycastParams.new()
	rpBelow.FilterType = Enum.RaycastFilterType.Exclude
	rpBelow.FilterDescendantsInstances = { FWater, FTrees, FRoads }
	local function belowAt(x, z, from)
		local h = workspace:Raycast(Vector3.new(x, from + 1, z), Vector3.new(0, -80, 0), rpBelow)
		return h and h.Position.Y
	end
	for i, b in ipairs(D.BRIDGES) do
		local x, z, yaw, L, w = b[1], b[2], b[3], b[4], b[5]
		local p = assert(poolAt(x, z), string.format("다리 %d 가 물 위에 있지 않다", i))
		local top = p.rimTop + 0.4
		local f = folder("돌/다리_" .. i)
		local along = (yaw == 0) and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local size = (yaw == 0) and Vector3.new(w, 1.4, L) or Vector3.new(L, 1.4, w)
		part("Deck", CFrame.new(x, top - 0.7, z), size, C.rim, M.Limestone, f)
		-- 난간돌. 긴 두 변에 낮게
		local side = (yaw == 0) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
		local rs = (yaw == 0) and Vector3.new(0.9, 1.0, L - 1) or Vector3.new(L - 1, 1.0, 0.9)
		for _, s in ipairs({ -1, 1 }) do
			part("Rail_" .. s, CFrame.new(Vector3.new(x, top + 0.5, z) + side * s * (w / 2 - 0.45)), rs, C.masonry, M.Slate, f)
		end
		-- 두 끝 계단. 아래 바닥(둘레돌 밖 땅, 섬, 누각 기단)까지
		for _, s in ipairs({ -1, 1 }) do
			local e = Vector3.new(x, 0, z) + along * s * (L / 2)
			stepsDown("End" .. s, e.X, e.Z, along.X * s, along.Z * s, w - 2, top, f, belowAt)
		end
	end
	task.wait()

	--==================================================================== 4. 길
	local FLOOR = { stone = { C.rim, M.Limestone }, dirt = { C.dirt, M.Ground } }
	local function floorPiece(name, cx, cz, len, width, yaw, kind, parent)
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ -0.5, 0, 0.5 }) do
			for _, v in ipairs({ -0.5, 0.5 }) do
				local wp = cf:PointToWorldSpace(Vector3.new(len * u, 0, width * v))
				local gy = groundY(wp.X, wp.Z, rpG)
				assert(gy, string.format("%s 자리 (%.0f,%.0f) 에 땅이 없다", name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local top, bot = hi + 0.3, lo - 0.9
		return part(name, CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(len, top - bot, width), FLOOR[kind][1], FLOOR[kind][2], parent)
	end
	for _, lane in ipairs(D.ROADS) do
		local name, width, kind, pts = lane[1], lane[2], lane[3], lane[4]
		local f = folder("길/" .. name)
		for i = 1, #pts - 1 do
			local ax, az = pts[i][1], pts[i][2]
			local bx, bz = pts[i + 1][1], pts[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
			local n = math.max(1, math.ceil(len / 40))
			for k = 1, n do
				local t = (k - 0.5) / n
				floorPiece(string.format("Road_%d_%d", i, k), ax + (bx - ax) * t, az + (bz - az) * t, len / n + 1, width, yaw, kind, f)
			end
			if i > 1 then
				-- 굽이 이음. 꺾인 자리의 빈 삼각형을 둥근 판으로 메운다. 길보다 0.02 낮춰 깜빡이지 않게
				local gy = groundY(ax, az, rpG)
				local c = part("Joint_" .. i, CFrame.new(ax, gy + 0.28 - 0.6, az) * CFrame.Angles(0, 0, math.rad(90)),
					Vector3.new(1.2, width, width), FLOOR[kind][1], FLOOR[kind][2], f)
				c.Shape = Enum.PartType.Cylinder
			end
		end
	end
	task.wait()

	--==================================================================== 5. 논밭
	for i, fd in ipairs(D.FIELDS) do
		local x0, z0, x1, z1 = fd[1], fd[2], fd[3], fd[4]
		local _, hi = span(x0, z0, x1, z1, rpG)
		local f = folder("논밭/" .. i)
		local top = hi + 0.25
		slab("Soil", x0, z0, x1, z1, top, C.soil, M.Ground, f)
		local k = 0
		for fx = x0 + 2, x1 - 2, 4 do
			k += 1
			part("Row_" .. k, CFrame.new(fx, top + 0.45, (z0 + z1) / 2), Vector3.new(1.4, 0.9, z1 - z0 - 2), C.crop, M.Grass, f)
		end
	end
	task.wait()

	--==================================================================== 6. 나무
	local cleared = SS:FindFirstChild("Jeolhwa_ClearedFlora")
	if not cleared then
		cleared = Instance.new("Folder")
		cleared.Name = "Jeolhwa_ClearedFlora"
		cleared.Parent = SS
	end
	local floraRoots = {}
	for _, r in ipairs({ "R_평원", "R_숲" }) do
		local f = workspace.Surface:FindFirstChild(r)
		if f and f:FindFirstChild("Flora") then
			floraRoots[#floraRoots + 1] = f.Flora
		end
	end
	-- 앞서 옮긴 것을 먼저 제자리로 돌린다
	-- 원래 자리는 Flora 밑 하위 폴더일 수도 있다. 2판은 뿌리 폴더만 찾아서 하위 폴더 나무가 창고에 남았다
	local byPath = {}
	for _, r in ipairs(floraRoots) do
		byPath[r:GetFullName()] = r
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("Folder") or d:IsA("Model") then
				byPath[d:GetFullName()] = d
			end
		end
	end
	local restored = 0
	for _, c in ipairs(cleared:GetChildren()) do
		local home = byPath[c:GetAttribute("OriginalParent") or ""]
		if home then
			c.Parent = home
			restored += 1
		end
	end
	-- 나무 한 그루는 이름 앞머리로 묶인다. Pln_Tree_9_B1t_L2 처럼 파트가 낱개로 들어 있다
	local function treeKey(p)
		return p.Parent:GetFullName() .. "/" .. (p.Name:match("^(.-_%d+)_") or p.Name)
	end
	local trees, plainKeys = {}, {}
	for _, r in ipairs(floraRoots) do
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") then
				local k = treeKey(p)
				if not trees[k] then
					trees[k] = {}
					if r.Parent.Name == "R_평원" then
						plainKeys[#plainKeys + 1] = k
					end
				end
				table.insert(trees[k], p)
			end
		end
	end
	-- 평원 식생에는 그루터기와 덤불도 섞여 있다. 파트 넷 이상, 키 14 이상인 나무만 옮겨 심는다
	local tall = {}
	for _, k in ipairs(plainKeys) do
		local lo, hi = math.huge, -math.huge
		for _, p in ipairs(trees[k]) do
			lo = math.min(lo, p.Position.Y - p.Size.Y / 2)
			hi = math.max(hi, p.Position.Y + p.Size.Y / 2)
		end
		if #trees[k] >= 4 and hi - lo >= 14 then
			tall[#tall + 1] = k
		end
	end
	plainKeys = tall
	table.sort(plainKeys)
	assert(#plainKeys > 0, "옮겨 심을 평원 나무가 없다")
	say("옮겨 심을 나무 후보 %d 그루", #plainKeys)
	for i, t in ipairs(D.TREES) do
		local src = trees[plainKeys[((i * 7) % #plainKeys) + 1]]
		local model = Instance.new("Model")
		model.Name = "Tree_" .. i
		local minY, rx, rz = math.huge, nil, nil
		for _, p in ipairs(src) do
			local c = p:Clone()
			c.Parent = model
			minY = math.min(minY, c.Position.Y - c.Size.Y / 2)
			if c.Name:match("_Root$") then
				rx, rz = c.Position.X, c.Position.Z
			end
		end
		if not rx then
			local cf0 = model:GetBoundingBox()
			rx, rz = cf0.X, cf0.Z
		end
		-- 뿌리 밑을 피벗으로 삼아 한 그루씩 조금씩 돌려 심는다. 같은 방향이면 복사본으로 보인다
		model.WorldPivot = CFrame.new(rx, minY, rz)
		model.Parent = FTrees
		local gy = assert(groundY(t[1], t[2]), "나무 자리에 땅이 없다")
		model:PivotTo(CFrame.new(t[1], gy - 0.5, t[2]) * CFrame.Angles(0, math.rad((i * 67) % 360), 0))
	end

	-- 원래 나무 비키기. 새로 앉힌 것에 걸린 나무를 그루째 옮긴다
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = floraRoots
	local movedTrees = 0
	local function clearArea(cf, size)
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
			if p.Parent ~= cleared then
				for _, q in ipairs(trees[treeKey(p)] or { p }) do
					if q.Parent ~= cleared then
						q:SetAttribute("OriginalParent", q.Parent:GetFullName())
						q.Parent = cleared
					end
				end
				movedTrees += 1
			end
		end
	end
	for _, e in ipairs(placed) do
		local cf, size = e.m:GetBoundingBox()
		clearArea(cf, size + Vector3.new(6, 60, 6))
	end
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsDescendantOf(FTrees) and d.Parent and not d.Parent:IsA("Model") then
			clearArea(d.CFrame, d.Size + Vector3.new(4, 60, 4))
		end
	end

	--==================================================================== 7. 검사
	local counts = {}
	for _, e in ipairs(placed) do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local line = {}
	for _, k in ipairs(keys) do
		line[#line + 1] = k .. " " .. counts[k]
	end
	say("%s", table.concat(line, ", "))
	say("모델 %d (담 토막 %d), 받침돌 %d 개, 가장 큰 땅 높이차 %.2f", #placed, nWalls, foundations, maxGap)
	say("나무 되돌림 %d, 새로 비킨 나무 %d 그루, 창고 파트 %d", restored, movedTrees, #cleared:GetChildren())

	-- 광장은 비워 둔다. 새로 지은 것이 스폰 광장에 들어가면 멈춘다
	local keepCF, keepSize = CFrame.new(225, 30, 510), Vector3.new(118, 60, 178)
	local kp = OverlapParams.new()
	kp.FilterType = Enum.RaycastFilterType.Include
	kp.FilterDescendantsInstances = { city }
	local intruders = {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(keepCF, keepSize, kp)) do
		if not p:IsDescendantOf(FRoads) and not p:IsDescendantOf(FTrees) then
			intruders[#intruders + 1] = p:GetFullName()
		end
	end
	assert(#intruders == 0, "스폰 광장에 들어간 것: " .. table.concat(intruders, ", ", 1, math.min(5, #intruders)))

	-- 행각은 한 높이여야 한다. 토막 밑이 기단 윗면과 어긋나면 지붕이 층진다
	local worst = 0
	for _, e in ipairs(placed) do
		if e.kind == "Corridor" or e.kind == "Corridor_Corner" then
			local cf, size = e.m:GetBoundingBox()
			worst = math.max(worst, math.abs((cf.Y - size.Y / 2) - ringTop))
		end
	end
	assert(worst < 0.05, string.format("행각 토막 높이가 %.2f 어긋난다", worst))

	local n = 0
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	say("파트 합계 %d", n)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/city3", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
