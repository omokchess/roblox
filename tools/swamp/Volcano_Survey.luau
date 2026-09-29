--!nocheck
-- 화산섬 실측(2026-09-28): 지반 경계·높이 지도(50 간격)·섬 위에 이미 선 것들. 보고: /volcano_survey
local HS = game:GetService("HttpService")
local S = workspace.Surface
local G = S.World:FindFirstChild("G_화산")
local out = {}
local function p(...)
	out[#out + 1] = string.format(...)
end

-- 지반 경계
local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
local n = 0
local mats = {}
for _, d in ipairs(G:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
		local a, b = d.Position - d.Size / 2, d.Position + d.Size / 2
		lo = Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z))
		hi = Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z))
		local key = d.Material.Name .. " " .. tostring(d.Color)
		mats[key] = (mats[key] or 0) + 1
	end
end
p("G_화산 파트 %d  x %.0f..%.0f  y %.0f..%.0f  z %.0f..%.0f", n, lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z)
local mlist = {}
for k, v in pairs(mats) do
	mlist[#mlist + 1] = { k, v }
end
table.sort(mlist, function(a, b)
	return a[2] > b[2]
end)
for i = 1, math.min(8, #mlist) do
	p("  재질 %s ×%d", mlist[i][1], mlist[i][2])
end

-- 높이 지도: 지반만 맞힌다. 글자 = 높이/10 (0-9, A=100.. Z), '.' 바다, '#' 지물(Zone_화산 등)이 먼저 맞음
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }
local rpAll = RaycastParams.new()
rpAll.FilterType = Enum.RaycastFilterType.Exclude
rpAll.FilterDescendantsInstances = {}
local STEP = 100
local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
p("높이 지도 STEP %d, 왼쪽 위 = (x %.0f, z %.0f), 오른쪽으로 +x, 아래로 +z", STEP, lo.X, lo.Z)
for z = lo.Z + 13, hi.Z, STEP do
	local row = {}
	for x = lo.X + 13, hi.X, STEP do
		local r = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -3000, 0), rp)
		local ch = "."
		if r then
			local h = math.floor(r.Position.Y / 10)
			ch = chars:sub(math.clamp(h + 1, 1, #chars), math.clamp(h + 1, 1, #chars))
			local r2 = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -3000, 0), rpAll)
			if r2 and r2.Instance and not r2.Instance:IsDescendantOf(G) and r2.Position.Y > r.Position.Y + 3 then
				ch = "#"
			end
		end
		row[#row + 1] = ch
	end
	p("%6.0f %s", z, table.concat(row))
end

-- 섬 위에 이미 선 것들(Workspace·Surface 의 모델·폴더 가운데 경계가 섬과 겹치는 것)
local function extents(inst)
	local a, b = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	local c = 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			c += 1
			a = Vector3.new(math.min(a.X, d.Position.X), math.min(a.Y, d.Position.Y), math.min(a.Z, d.Position.Z))
			b = Vector3.new(math.max(b.X, d.Position.X), math.max(b.Y, d.Position.Y), math.max(b.Z, d.Position.Z))
		end
	end
	return a, b, c
end
local function overlaps(a, b)
	return a.X <= hi.X and b.X >= lo.X and a.Z <= hi.Z and b.Z >= lo.Z
end
p("섬과 겹치는 것:")
local roots = {}
for _, c in ipairs(workspace:GetChildren()) do
	if c ~= S and not c:IsA("Terrain") and not c:IsA("Camera") then
		roots[#roots + 1] = c
	end
end
for _, c in ipairs(S:GetChildren()) do
	if c.Name ~= "World" then
		roots[#roots + 1] = c
	end
end
for _, c in ipairs(S.World:GetChildren()) do
	if c ~= G then
		roots[#roots + 1] = c
	end
end
for _, c in ipairs(roots) do
	local a, b, cnt = extents(c)
	if cnt > 0 and overlaps(a, b) then
		p("  %s (%s) 파트 %d  x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f", c:GetFullName(), c.ClassName, cnt, a.X, b.X, a.Y, b.Y, a.Z, b.Z)
		if c.Name == "Zone_화산" then
			for _, k in ipairs(c:GetChildren()) do
				local a2, b2, c2 = extents(k)
				p("      %s 파트 %d  x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f", k.Name, c2, a2.X, b2.X, a2.Y, b2.Y, a2.Z, b2.Z)
			end
		end
	end
end
HS:PostAsync("http://127.0.0.1:34999/volcano_survey", table.concat(out, "\n"))
