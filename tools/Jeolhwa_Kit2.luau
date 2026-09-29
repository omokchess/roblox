--!nocheck
--[[
	Jeolhwa_Kit2.luau — 2026-09-26. 블렌더 합본 JeolhwaKit2.fbx 를 모델별 틀로 가른다.

	가져온 Workspace.JeolhwaKit2 안에는 새 건물 11종의 메시가 한데 섞여 있다.
	파트 이름 앞머리(GateP_, Corr_ ...)로 모델을 나누고, 원점 표지(KitOrigin_Marker)
	위치를 빼서 블렌더 원점(기단 바닥 가운데)을 피벗으로 되찾는다.
	색·재질·충돌은 Jeolhwa_City 와 같은 팔레트로 입혀 ServerStorage.JeolhwaKit 에 넣는다.

	끝으로 틀 전부(옛 틀 포함)의 로컬 발자국을 잰다. 배치표를 짤 때 이 값을 쓴다
	  base  땅에 닿는 켜(가장 낮은 파트들)의 x0 x1 z0 z1
	  all   지붕까지 모두 넣은 x0 x1 z0 z1 과 높이
]]

local RGB = Color3.fromRGB
local M = Enum.Material
-- 블렌더 hanok_lib.PALETTE 와 같은 값이다
local SKIN = {
	Stylobate = { RGB(193, 190, 176), M.Limestone },
	Stairs = { RGB(197, 194, 179), M.Limestone },
	Plinth = { RGB(169, 165, 151), M.Limestone },
	Column = { RGB(138, 90, 69), M.Wood },
	Beam = { RGB(126, 83, 64), M.Wood },
	Bracket = { RGB(110, 71, 54), M.Wood },
	Wall = { RGB(219, 212, 193), M.SmoothPlastic },
	Lattice = { RGB(154, 106, 78), M.Wood },
	Paper = { RGB(228, 220, 198), M.SmoothPlastic },
	Roof = { RGB(85, 88, 79), M.Slate },
	RoofEdge = { RGB(71, 74, 67), M.Slate },
	Eave = { RGB(94, 64, 51), M.Wood },
	Trim = { RGB(78, 111, 99), M.SmoothPlastic },
	Ochre = { RGB(180, 136, 74), M.SmoothPlastic },
	Masonry = { RGB(157, 153, 139), M.Slate },
	Thatch = { RGB(156, 134, 96), M.Fabric },
	Onggi = { RGB(92, 64, 50), M.SmoothPlastic },
	Soil = { RGB(122, 100, 73), M.Ground },
	Leaf = { RGB(94, 113, 71), M.Grass },
	Brush = { RGB(142, 125, 102), M.Wood },
}
local PRECISE = {
	Wall = true, Lattice = true, Stairs = true, Column = true, Plinth = true,
	Beam = true, Bracket = true, Stylobate = true, Masonry = true, Brush = true,
}
local HULL = { Roof = true, RoofEdge = true, Eave = true, Thatch = true, Onggi = true }
local NOCOLLIDE = { Trim = true, Ochre = true, Paper = true, Leaf = true }

local PREFIX = {
	GateP = "Gate_Palace", GateH = "Gate_Hall", Corr = "Corridor", CorrC = "Corridor_Corner",
	Nugak = "Pavilion_Nugak", Bell = "Tower_Bell", Chim = "Palace_Chimjeon",
	Shop5 = "Shop_Row5", Shop3 = "Shop_Row3", Gran = "Granary", HouseLM = "Building_HouseLM",
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function skin(p, key)
	local s = SKIN[key]
	assert(s, "모르는 재질 이름 " .. p.Name)
	p.Color = s[1]
	p.Material = s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key]
	p.CastShadow = true
	if PRECISE[key] then
		p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	elseif HULL[key] then
		p.CollisionFidelity = Enum.CollisionFidelity.Hull
	else
		p.CollisionFidelity = Enum.CollisionFidelity.Box
	end
	p.RenderFidelity = Enum.RenderFidelity.Precise
end

-- 파트가 frame 축으로 차지하는 반너비와 가운데
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

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("JeolhwaKit")
	assert(kit, "ServerStorage.JeolhwaKit 이 없다")

	local imp = workspace:FindFirstChild("JeolhwaKit2")
	if imp then
		local marker = imp:FindFirstChild("KitOrigin_Marker", true)
		assert(marker, "원점 표지가 없다")
		local o = marker.Position
		say("표지 %.2f %.2f %.2f", o.X, o.Y, o.Z)
		local groups = {}
		for _, p in ipairs(imp:GetDescendants()) do
			if p:IsA("BasePart") and p ~= marker then
				local pre, key = p.Name:match("^([^_]+)_(.+)$")
				local name = PREFIX[pre]
				assert(name, "모르는 앞머리 " .. p.Name)
				groups[name] = groups[name] or {}
				table.insert(groups[name], { p = p, key = key })
			end
		end
		local n = 0
		for name, list in pairs(groups) do
			local old = kit:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = name
			for _, e in ipairs(list) do
				e.p.CFrame = e.p.CFrame - o
				skin(e.p, e.key)
				e.p.Parent = m
			end
			m.WorldPivot = CFrame.new()
			m.Parent = kit
			n += 1
		end
		imp:Destroy()
		say("새 틀 %d 종", n)
	end

	-- 발자국
	local names = {}
	for _, m in ipairs(kit:GetChildren()) do
		names[#names + 1] = m.Name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local m = kit[name]
		local frame = m:GetPivot()
		local minY = math.huge
		local parts = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				parts[#parts + 1] = { e = e, c = c }
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local b = { math.huge, -math.huge, math.huge, -math.huge }
		local a = { math.huge, -math.huge, math.huge, -math.huge, -math.huge }
		for _, q in ipairs(parts) do
			local e, c = q.e, q.c
			a[1], a[2] = math.min(a[1], c.X - e.X), math.max(a[2], c.X + e.X)
			a[3], a[4] = math.min(a[3], c.Z - e.Z), math.max(a[4], c.Z + e.Z)
			a[5] = math.max(a[5], c.Y + e.Y)
			if c.Y - e.Y < minY + 0.3 then
				b[1], b[2] = math.min(b[1], c.X - e.X), math.max(b[2], c.X + e.X)
				b[3], b[4] = math.min(b[3], c.Z - e.Z), math.max(b[4], c.Z + e.Z)
			end
		end
		say("%s base %.1f %.1f %.1f %.1f all %.1f %.1f %.1f %.1f h %.1f minY %.2f n %d",
			name, b[1], b[2], b[3], b[4], a[1], a[2], a[3], a[4], a[5], minY, #parts)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/kit2", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("kit2", #report, ok)
