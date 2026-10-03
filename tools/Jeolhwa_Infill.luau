--!nocheck
--[[
	Jeolhwa_Infill.luau — 2026-10-03. 평원 평탄화 뒤 절화 빈 자리 채우기(편집 모드, StudioJobs).

	사용자(2026-10-03): "곳곳에 뜬금없이 있는 밭이나 건초더미 없애줘. 빈 공간은 광장을 놓든 뭘 하든 해서 채워넣자."
	  1. 걷기: Jeolhwa.논밭(15), 짚더미(Prop_Haystack 5), 가지 없이 뿌리 상자만 남은 평원 나무 그루터기
	     → ServerStorage.Jeolhwa_Removed (OriginalParent 속성. 지우지 않는다)
	  2. 짓기: jeolhwa_plan.py 표(TOWN·TREES·TOWN_PAVES)에 있는데 자리에 없는 것만 놓는다(다시 돌려도 겹쳐 짓지 않는다).
	     건물은 Jeolhwa_City3 place 와 같은 법: 발자국 아래 가장 높은 땅에 맨 아래 켜를 앉힌다
	  3. 광장 꾸밈(PLAZA): 당산나무 단·해시계·방(알림판)·좌판을 파트와 JeolhwaProps 소품으로 짓는다. 폴더 Jeolhwa.광장
	붙여 쓰는 법: --@@DATA@@ 자리에 Jeolhwa_City3_data.luau 를 끼운다
	  sed '/--@@DATA@@/r tools/Jeolhwa_City3_data.luau' tools/Jeolhwa_Infill.luau > <scratch>/infill_run.luau && bash tools/job.sh <scratch>/infill_run.luau
	뒤에 Jeolhwa_Interiors(안살림 새로) 를 돌린다. 보고: /infill
]]
--@@DATA@@

local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local STAMP = "2026-10-03"
local DRY = false -- true 면 지을 목록만 보고

local ok, err = pcall(function()
	local J = workspace.Jeolhwa
	local kit, props = SS.JeolhwaKit, SS.JeolhwaProps
	local function folder(path: string): Folder
		local f = J
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

	-- 땅 = 평원 새 지형
	local terrain = {}
	for _, region in { "R_평원북", "R_평원동", "R_평원중" } do
		local f = workspace.Surface:FindFirstChild(region)
		for _, sub in { "Land", "Cliffs", "Masses", "Ramps", "Sand" } do
			local x = f and f:FindFirstChild(sub)
			if x then
				table.insert(terrain, x)
			end
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = terrain
	local function groundY(x: number, z: number): number
		local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), rp)
		return assert(r, string.format("(%.0f,%.0f) 아래 땅 없음", x, z)).Position.Y
	end

	--==================================================== 1. 걷기
	local bin = SS:FindFirstChild("Jeolhwa_Removed")
	if not bin then
		bin = Instance.new("Folder")
		bin.Name = "Jeolhwa_Removed"
		bin.Parent = SS
	end
	local removed = 0
	local function stash(inst: Instance)
		inst:SetAttribute("OriginalParent", inst.Parent:GetFullName())
		inst:SetAttribute("RemovedOn", STAMP)
		inst.Parent = bin
		removed += 1
	end
	if DRY then
		stash = function(inst)
			say("걷을 것 %s", inst:GetFullName())
		end
	end
	if J:FindFirstChild("논밭") then
		stash(J["논밭"])
	end
	for _, m in J:GetDescendants() do
		if m:IsA("Model") and m.Name == "Prop_Haystack" then
			stash(m)
		end
	end
	-- 뿌리 상자만 남은 그루터기(가지 파트가 하나도 없는 Pln_Tree_N)
	local flora = workspace.Surface:FindFirstChild("R_평원") and workspace.Surface["R_평원"]:FindFirstChild("Flora")
	if flora then
		local count = {}
		for _, p in flora:GetDescendants() do
			local k = p:IsA("BasePart") and p.Name:match("^(Pln_Tree_%d+)_")
			if k then
				count[k] = (count[k] or 0) + 1
			end
		end
		for _, p in flora:GetDescendants() do
			local k = p:IsA("BasePart") and p.Name:match("^(Pln_Tree_%d+)_Root$")
			if k and count[k] == 1 then
				stash(p)
			end
		end
	end
	say("걷음 %d (논밭 폴더·짚더미·그루터기)", removed)

	--==================================================== 2. 표에서 빠진 건물·나무·박석
	local function halfExtents(p: BasePart, frame: CFrame)
		local r = frame:ToObjectSpace(p.CFrame)
		local s = p.Size / 2
		local R, U, L = r.RightVector, r.UpVector, r.LookVector
		return Vector3.new(
			math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
			math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
			math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
		), r.Position
	end
	local function exists(parent: Instance, kind: string, x: number, z: number): boolean
		for _, m in parent:GetChildren() do
			if m.Name == kind and m:IsA("Model") then
				local p = m:GetPivot().Position
				if math.abs(p.X - x) < 1.5 and math.abs(p.Z - z) < 1.5 then
					return true
				end
			end
		end
		return false
	end
	local built = 0
	for _, e in D.TOWN do
		local kind, x, z, yaw, f = e[1], e[2], e[3], e[4], folder(e[5])
		if exists(f, kind, x, z) then
			continue
		end
		if DRY then
			say("지을 것 %s %s (%.0f,%.0f)", e[5], kind, x, z)
			continue
		end
		local m = kit[kind]:Clone()
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		local frame = m:GetPivot()
		local minY = math.huge
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local ex, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - ex.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local ex, c = halfExtents(p, frame)
				if c.Y - ex.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - ex.X), math.max(x1, c.X + ex.X)
					z0, z1 = math.min(z0, c.Z - ex.Z), math.max(z1, c.Z + ex.Z)
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in { 0.02, 0.5, 0.98 } do
			for _, v in { 0.02, 0.5, 0.98 } do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		assert(hi - lo < 0.3, string.format("%s (%.0f,%.0f) 발밑이 평평하지 않다 %.2f", kind, x, z, hi - lo))
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - (frame.Y + minY), 0))
		m.Name = kind
		m:SetAttribute("Infill", STAMP)
		m.Parent = f
		built += 1
		say("지음 %s %s (%.0f,%.0f)", e[5], kind, x, z)
	end

	if DRY then
		return
	end

	-- 나무: 표 자리에 나무가 없으면 있는 나무를 복제해 심는다(Jeolhwa_City3 와 같이 뿌리 밑 = 땅 −0.5)
	local FT = J["나무"]
	local src = {}
	for _, t in FT:GetChildren() do
		if t:IsA("Model") then
			table.insert(src, t)
		end
	end
	table.sort(src, function(a, b)
		return a.Name < b.Name
	end)
	local planted, nextId = 0, #src + 1
	for i, t in D.TREES do
		local near = false
		for _, m in src do
			local p = m:GetPivot().Position
			if math.abs(p.X - t[1]) < 3 and math.abs(p.Z - t[2]) < 3 then
				near = true
				break
			end
		end
		if not near then
			local m = src[(i * 7) % #src + 1]:Clone()
			while FT:FindFirstChild("Tree_" .. nextId) do
				nextId += 1
			end
			m.Name = "Tree_" .. nextId
			m:PivotTo(CFrame.new(t[1], groundY(t[1], t[2]) - 0.5, t[2]) * CFrame.Angles(0, math.rad((i * 67) % 360), 0))
			m:SetAttribute("Infill", STAMP)
			m.Parent = FT
			planted += 1
		end
	end

	-- 박석(광장): 저잣마당 박석과 같은 빛·재질, 48 이하 조각, 윗면 = 땅 + 0.3
	local paveLook
	for _, p in J["돌"]["저잣마당"]:GetChildren() do
		if p:IsA("BasePart") then
			paveLook = p
			break
		end
	end
	for _, pv in D.PAVES do
		local name, x0, z0, x1, z1 = pv[1], pv[2], pv[3], pv[4], pv[5]
		if pv[6] == "ground" and not J["돌"]:FindFirstChild(name) then
			local f = folder("돌/" .. name)
			local top = groundY((x0 + x1) / 2, (z0 + z1) / 2) + 0.3
			local nx, nz = math.ceil((x1 - x0) / 48), math.ceil((z1 - z0) / 48)
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					local a0, a1 = x0 + (x1 - x0) * i / nx, x0 + (x1 - x0) * (i + 1) / nx
					local b0, b1 = z0 + (z1 - z0) * j / nz, z0 + (z1 - z0) * (j + 1) / nz
					local p = paveLook:Clone()
					p.Name = string.format("Pave_%d_%d", i, j)
					p.Size = Vector3.new(a1 - a0, 1.3, b1 - b0)
					p.CFrame = CFrame.new((a0 + a1) / 2, top - 0.65, (b0 + b1) / 2)
					p:ClearAllChildren()
					p.Parent = f
				end
			end
			say("박석 %s %d×%d 조각, 윗면 %.2f", name, nx, nz, top)
		end
	end
	local plazaTop = groundY(225, 515) + 0.3

	--==================================================== 3. 광장 꾸밈
	local FP = J:FindFirstChild("광장")
	if FP then
		FP:Destroy() -- 꾸밈은 늘 표대로 새로
	end
	FP = folder("광장")
	local STONE = { RGB(138, 134, 124), Enum.Material.Slate } -- 정전 기단 빛
	local STONE2 = { RGB(176, 171, 158), Enum.Material.Limestone }
	local WOOD = { RGB(92, 62, 40), Enum.Material.Wood }
	local WOOD2 = { RGB(150, 112, 74), Enum.Material.WoodPlanks }
	local function box(name: string, parent: Instance, cf: CFrame, size: Vector3, look): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color, p.Material = look[1], look[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	-- 소품 틀을 바닥 높이 y 에 앉힌다(로컬 frame 기준 x, z, yaw)
	local function prop(name: string, parent: Instance, frame: CFrame, x: number, z: number, yaw: number, y: number): Model
		local m = props[name]:Clone()
		m:PivotTo(frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, y - (cf.Y - size.Y / 2), 0))
		m.Parent = parent
		return m
	end
	local CLOTH = {
		{ RGB(52, 64, 104), Enum.Material.Fabric }, -- 쪽빛
		{ RGB(176, 128, 58), Enum.Material.Fabric }, -- 치자
		{ RGB(128, 52, 40), Enum.Material.Fabric }, -- 홍화
		{ RGB(196, 186, 160), Enum.Material.Fabric }, -- 무명
	}
	local GOODS = { "Stall_Baskets", "Stall_Crates", "Stall_Cloth", "Stall_Jars" }
	local nBooth = 0
	for _, it in D.PLAZA do
		local kind, x, z, yaw, w, d = it[1], it[2], it[3], it[4], it[5], it[6]
		local frame = CFrame.new(x, plazaTop, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local m = Instance.new("Model")
		m.Name = kind
		m.Parent = FP
		if kind == "Dangsan" then
			-- 두 켜 돌 단(0.6 씩, 계단 없이 올라선다) + 큰 나무 + 평상 둘
			box("Step", m, frame * CFrame.new(0, 0.3 - 0.5, 0), Vector3.new(w, 1.6, d), STONE)
			box("Top", m, frame * CFrame.new(0, 0.9 - 0.5, 0), Vector3.new(w - 3, 1.6, d - 3), STONE2)
			local tops = plazaTop + 1.2
			local biggest, bh = nil, 0
			for _, t in FT:GetChildren() do
				if t:IsA("Model") then
					local _, s = t:GetBoundingBox()
					if s.Y > bh and s.X < 60 then
						biggest, bh = t, s.Y
					end
				end
			end
			local tree = biggest:Clone()
			tree.Name = "Tree_Dangsan"
			tree:ScaleTo(1.5)
			tree:PivotTo(CFrame.new(x, tops - 0.3, z) * CFrame.Angles(0, math.rad(35), 0))
			tree.Parent = m
			prop("Pyeongsang", m, frame, -(w - 3) / 2 + 3.2, 0, 90, tops)
			prop("Pyeongsang", m, frame, (w - 3) / 2 - 3.2, 0, 90, tops)
		elseif kind == "Sundial" and kit:FindFirstChild("Sundial") then
			-- 2026-10-03 사용자 "블렌더로": 블렌더 앙부일구 틀(Jeolhwa_Sundial). 피벗 = 대석 밑 가운데, 영침이 +Z(북)
			local sun = kit.Sundial:Clone()
			sun:PivotTo(frame)
			sun.Parent = m
		elseif kind == "Sundial" then
			-- (틀이 없을 때) 앙부일구: 네모 받침돌 + 돌기둥 + 청동 솥(납작한 반구) + 영침
			box("Base", m, frame * CFrame.new(0, 0.3 - 0.5, 0), Vector3.new(w, 1.6, d), STONE)
			box("Pillar", m, frame * CFrame.new(0, 0.6 + 1.6, 0), Vector3.new(1.8, 3.2, 1.8), STONE2)
			local bowl = box("Bowl", m, frame * CFrame.new(0, 0.6 + 3.2 + 0.5, 0), Vector3.new(3.2, 1.2, 3.2), { RGB(96, 78, 46), Enum.Material.Metal })
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.Sphere
			sm.Parent = bowl
			box("Gnomon", m, frame * CFrame.new(0, 0.6 + 3.2 + 1.3, 0.4) * CFrame.Angles(math.rad(-40), 0, 0), Vector3.new(0.15, 1.6, 0.15), { RGB(60, 48, 30), Enum.Material.Metal })
		elseif kind == "Notice" then
			-- 방(榜) 붙이는 판: 기둥 둘 + 판 + 종이 셋 + 기와 머리
			for _, sx in { -w / 2 + 0.5, w / 2 - 0.5 } do
				box("Post", m, frame * CFrame.new(sx, 4.2, 0), Vector3.new(0.7, 8.4, 0.7), WOOD)
			end
			box("Board", m, frame * CFrame.new(0, 5, 0), Vector3.new(w - 1.6, 4.4, 0.3), WOOD2)
			for i, px in { -2.4, 0, 2.4 } do
				local sheet = box("Paper", m, frame * CFrame.new(px, 5 + (i % 2) * 0.3, -0.17) * CFrame.Angles(0, 0, math.rad((i - 2) * 3)), Vector3.new(1.8, 2.6, 0.04), { RGB(236, 228, 206), Enum.Material.SmoothPlastic })
				sheet.CanCollide = false
			end
			box("Cap", m, frame * CFrame.new(0, 8.6, 0), Vector3.new(w + 0.6, 0.5, 1.8), { RGB(70, 72, 70), Enum.Material.Slate })
			box("CapRidge", m, frame * CFrame.new(0, 9.0, 0), Vector3.new(w + 0.2, 0.35, 0.6), { RGB(58, 60, 58), Enum.Material.Slate })
		elseif kind == "Booth" then
			-- 좌판: 앞 기둥 높고 뒤 낮은 천 지붕, 앞에 널 상, 상 위 물건(Stall_*), 뒤에 독 하나
			nBooth += 1
			local cloth = CLOTH[(nBooth - 1) % #CLOTH + 1]
			local hx, hz = w / 2 - 0.4, d / 2 - 0.4
			for _, c in { { -hx, -hz, 6.6 }, { hx, -hz, 6.6 }, { -hx, hz, 5.2 }, { hx, hz, 5.2 } } do
				box("Post", m, frame * CFrame.new(c[1], c[3] / 2, c[2]), Vector3.new(0.45, c[3], 0.45), WOOD)
			end
			local roofAng = math.atan2(6.6 - 5.2, d - 0.8)
			box("Awning", m, frame * CFrame.new(0, 6.0, 0) * CFrame.Angles(roofAng, 0, 0), Vector3.new(w + 0.8, 0.2, d + 0.6), cloth)
			box("Valance", m, frame * CFrame.new(0, 6.25, -d / 2 - 0.25), Vector3.new(w + 0.8, 0.9, 0.08), cloth).CanCollide = false
			box("Table", m, frame * CFrame.new(0, 1.15, -d / 2 + 1.6), Vector3.new(w - 1.2, 0.3, 2.6), WOOD2)
			for _, sx in { -w / 2 + 1.0, w / 2 - 1.0 } do
				box("TableLeg", m, frame * CFrame.new(sx, 0.5, -d / 2 + 1.6), Vector3.new(0.3, 1.0, 2.2), WOOD)
			end
			prop(GOODS[(nBooth - 1) % #GOODS + 1], m, frame, 0, -d / 2 + 1.6, 0, plazaTop + 1.3)
			prop(if nBooth % 2 == 0 then "Suldok" else "Sirung", m, frame, hx - 1.4, hz - 1.4, 20 * nBooth, plazaTop)
		end
		m:SetAttribute("Infill", STAMP)
	end
	say("지음 건물 %d · 나무 %d · 광장 꾸밈 %d(좌판 %d) · 광장 윗면 %.2f", built, planted, #D.PLAZA, nBooth, plazaTop)
end)
HS:PostAsync("http://127.0.0.1:34999/infill", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
