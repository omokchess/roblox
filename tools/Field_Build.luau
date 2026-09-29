--!nocheck
--[[
	Field_Build.luau — 들판 부품 목록(tools/swamp/field_parts.txt)을 Studio 에 세운다. (2026-09-29)
	목록은 tools/fields/<지역>.py 가 만든다(자리·모양은 배치표, 규칙은 tools/field_parts.py · field_pois.py).
	편집 모드 로더: bash tools/job.sh tools/Field_Build.luau → /field_build 보고

	줄 형식은 field_parts.py 머리말. 여기서 하는 일:
	  F  이름 → workspace.Surface["F_" .. 이름] 에 짓는다. 이미 있으면 지우고 다시(같은 결과)
	  R  폴더 다각형 → 그 폴더의 Gs_/Gb_ 판 가운데가 다각형 안이면 ServerStorage.FieldRemoved.<이름> 로 옮긴다
	     (다시 지을 때는 먼저 제자리로 되돌린다 — 되돌리기: 창고 부품의 속성 From 경로로 옮기면 된다)
	  A  닻: 처음 쓰일 때 (x,z) 에서 아래로 광선을 쏴 땅(새 땅·오름·옛 섬 판) 높이를 잰다
	  P  부품, K 틀 복제(평원 나무 · 절화 틀)
	남의 것(사용자 부품)은 건드리지 않는다: 지우는 것은 F_ 폴더와, R 이 가리킨 폴더의 Gs_/Gb_ 판뿐.
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local t0 = os.clock()

local src = HS:GetAsync("http://127.0.0.1:35000/field_parts.txt", true)
local lines = string.split(src, "\n")
local name = assert(string.match(lines[1], "^F (.+)$"), "첫 줄이 F 가 아니다")
local report = {}
local function say(fmt, ...)
	table.insert(report, string.format(fmt, ...))
end

local function pathTo(path)
	local node = workspace
	for seg in string.gmatch(path, "[^/]+") do
		node = node:FindFirstChild(seg)
		if not node then
			return nil
		end
	end
	return node
end

--=== 0. 다시 짓기: 옛 결과 지우고 치웠던 판 되돌리기 ===--
local surface = workspace.Surface
local old = surface:FindFirstChild("F_" .. name)
if old then
	old:Destroy()
end
local removedRoot = SS:FindFirstChild("FieldRemoved") or Instance.new("Folder")
removedRoot.Name = "FieldRemoved"
removedRoot.Parent = SS
local backup = removedRoot:FindFirstChild(name)
if backup then
	local back = 0
	for _, p in backup:GetChildren() do
		local home = pathTo(p:GetAttribute("From") or "")
		if home then
			p.Parent = home
			back += 1
		end
	end
	backup:Destroy()
	say("되돌린 옛 판 %d", back)
end
backup = Instance.new("Folder")
backup.Name = name
backup.Parent = removedRoot

local root = Instance.new("Folder")
root.Name = "F_" .. name
root.Parent = surface
-- 땅·오름 폴더는 미리(광선 목록에 처음부터 넣으려고 — 나중에 들어오는 자손도 걸린다)
for _, n0 in { "땅", "오름" } do
	local f = Instance.new("Folder")
	f.Name = n0
	f.Parent = root
end

--=== 도구 ===--
local function pip(x, z, poly)
	local inside = false
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		if (a[2] > z) ~= (b[2] > z) then
			local xi = a[1] + (z - a[2]) * (b[1] - a[1]) / (b[2] - a[2])
			if xi > x then
				inside = not inside
			end
		end
	end
	return inside
end

local groups = {}
local function folderFor(path)
	local node = root
	for seg in string.gmatch(path, "[^/]+") do
		local c = node:FindFirstChild(seg)
		if not c then
			c = Instance.new("Folder")
			c.Name = seg
			c.Parent = node
		end
		node = c
	end
	return node
end

-- 땅 광선: 새 땅·오름·옛 섬 판·산만 본다(나무·돌담·사람 부품에 걸리지 않게)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
local function refreshGround()
	local list = { surface.World }
	if surface:FindFirstChild("Mountains") then
		table.insert(list, surface.Mountains)
	end
	for _, n in { "땅", "오름" } do
		local f = root:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	rp.FilterDescendantsInstances = list
end
refreshGround()

local anchors = {}
local anchorY = {}
local missed = 0
local function ground(id)
	local y = anchorY[id]
	if y then
		return y
	end
	local a = anchors[id]
	local r = workspace:Raycast(Vector3.new(a[1] + 0.13, 400, a[2] + 0.17), Vector3.new(0, -500, 0), rp)
	if r then
		y = r.Position.Y
	else
		y = a[3] or 0
		if not a[3] then
			missed += 1
		end
	end
	anchorY[id] = y
	return y
end

local SHAPE = { C = Enum.PartType.Cylinder, S = Enum.PartType.Ball }
local QUIET = { Crop = true, Soil = true, Eulsae = true, Plume = true, Reed = true, Cloth = true, Rope = true, Fish = true,
	Moss = true, Path = true, CedarLeaf = true, Rubble = true, Water = true, RopePost = true }
local NOCOLLIDE = { Crop = true, Eulsae = true, Plume = true, Reed = true, Cloth = true, Rope = true, Fish = true, Water = true,
	CedarLeaf = true }
local RAD = math.pi / 180

-- 틀: 평원 나무 = 지금 절화에 선 블록 나무(Workspace.Jeolhwa.나무 — 줄기 Wood·잎 Grass 네모 블록)를 복제한다.
-- 창고의 Pln_PreviousGeneratedTrees·BeforeBlockWorldGeneratedFlora 는 블록 맵 이전의 공 모양 잎 나무라 쓰지 않는다
-- (2026-09-29 그것을 썼다가 "나무가 갑자기 왜그래" 지적). 절화 나무 자체는 읽기만 한다.
local treeTemplates = {}
local jtrees = workspace:FindFirstChild("Jeolhwa") and workspace.Jeolhwa:FindFirstChild("나무")
for _, m in (jtrees and jtrees:GetChildren()) or {} do
	if m:IsA("Model") and #m:GetChildren() >= 4 then
		local ball = false
		for _, d in m:GetDescendants() do
			if d:IsA("Part") and d.Shape ~= Enum.PartType.Block then
				ball = true
			end
		end
		if not ball then
			table.insert(treeTemplates, m)
		end
	end
end
local kit = SS:FindFirstChild("JeolhwaKit")
local props = SS:FindFirstChild("JeolhwaProps")

local function placeClone(src, x, y, z, yaw, scale, parent)
	local m = src:Clone()
	if scale ~= 1 and m:IsA("Model") then
		m:ScaleTo(m:GetScale() * scale)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local cf, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local bottomOffset = (cf.Position.Y - size.Y / 2) - pivot.Position.Y
	m:PivotTo(CFrame.new(x, y - bottomOffset - 0.25, z) * CFrame.Angles(0, -yaw * RAD, 0))
	m.Parent = parent
	return m
end

local counts = { P = 0, K = 0, R = 0 }
local n = 0
for i = 2, #lines do
	local line = lines[i]
	local tag = string.sub(line, 1, 1)
	if tag == "G" then
		local id, path = string.match(line, "^G (%d+) (.+)$")
		groups[tonumber(id)] = path
	elseif tag == "A" then
		local t = string.split(line, " ")
		anchors[tonumber(t[2])] = { tonumber(t[3]), tonumber(t[4]), tonumber(t[5]) }
	elseif tag == "R" then
		local t = string.split(line, " ")
		local folder = pathTo(t[2])
		local poly = {}
		for k = 3, #t - 1, 2 do
			table.insert(poly, { tonumber(t[k]), tonumber(t[k + 1]) })
		end
		if folder then
			for _, p in folder:GetChildren() do
				if p:IsA("BasePart") and (string.sub(p.Name, 1, 3) == "Gs_" or string.sub(p.Name, 1, 3) == "Gb_") and pip(p.Position.X, p.Position.Z, poly) then
					p:SetAttribute("From", t[2])
					p.Parent = backup
					counts.R += 1
				end
			end
		end
		refreshGround()
	elseif tag == "P" then
		local t = string.split(line, " ")
		local shape, anc = t[2], t[3]
		local x, y, z = tonumber(t[4]), tonumber(t[5]), tonumber(t[6])
		if anc ~= "-" then
			y += ground(tonumber(anc))
		end
		local p = if shape == "W" then Instance.new("WedgePart") else Instance.new("Part")
		if SHAPE[shape] then
			p.Shape = SHAPE[shape]
		end
		p.Size = Vector3.new(tonumber(t[7]), tonumber(t[8]), tonumber(t[9]))
		p.CFrame = CFrame.new(x, y, z) * CFrame.fromOrientation(tonumber(t[11]) * RAD, tonumber(t[10]) * RAD, tonumber(t[12]) * RAD)
		p.Material = Enum.Material[t[13]]
		p.Color = Color3.fromRGB(tonumber(t[14]), tonumber(t[15]), tonumber(t[16]))
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		local pname = t[18] or "P"
		p.Name = pname
		if QUIET[pname] then
			p.CastShadow = false
		end
		if NOCOLLIDE[pname] then
			p.CanCollide = false
			p.CanTouch = false
		end
		if pname == "Water" then
			p.Transparency = 0.25
			p.Reflectance = 0.12
		end
		p.Parent = folderFor(groups[tonumber(t[17])])
		counts.P += 1
	elseif tag == "K" then
		local t = string.split(line, " ")
		local kind, anc = t[2], t[3]
		local x, y, z = tonumber(t[4]), tonumber(t[5]), tonumber(t[6])
		if anc ~= "-" then
			y += ground(tonumber(anc))
		end
		local yaw, scale = tonumber(t[7]), tonumber(t[8])
		local parent = folderFor(groups[tonumber(t[9])])
		local src
		if kind == "PlainsTree" then
			if #treeTemplates > 0 then
				src = treeTemplates[(math.floor(math.abs(x * 7.13 + z * 3.71)) % #treeTemplates) + 1]
			end
		else
			src = (kit and kit:FindFirstChild(kind)) or (props and props:FindFirstChild(kind))
		end
		if src then
			local m = placeClone(src, x, y, z, yaw, scale, parent)
			m.Name = kind
			counts.K += 1
		else
			say("틀 없음 %s", kind)
		end
	end
	n += 1
	if n % 500 == 0 then
		task.wait()
	end
end

say("%s: 부품 %d, 틀 %d, 옛 판 치움 %d, 땅 못 찾은 닻 %d, 평원 나무 틀 %d, %.1f초", name, counts.P, counts.K, counts.R, missed, #treeTemplates, os.clock() - t0)
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/field_build", table.concat(report, "\n"))
end)
