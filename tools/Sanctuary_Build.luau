--!nocheck
--[[
	Sanctuary_Build.luau — 2026-09-27. 탑의 성역 리메이크를 짓는다.

	배치는 tools/sanctuary_plan.py 의 표(→ Sanctuary_data.luau), 모델은 ServerStorage.SanctuaryKit(Sanctuary_Kit.luau),
	탑 계단 점은 Sanctuary_steps.luau. python tools/sanctuary_run.py 가 셋을 합쳐 Sanctuary_Build_run.luau 를 만든다.

	하는 일
	  1. 옛 성역(Ruins_·Fill_·Struct_탑의성역)을 ServerStorage.탑의성역_옛것 으로 옮긴다(지우지 않는다)
	  2. 섬 땅 조각(World.G_탑의성역 의 Gs_) 중 모래 아닌 것을 잔디로. 원래 빛은 OrigColor/OrigMat 속성에
	  3. Surface.Sanctuary_탑의성역 에 새로 짓는다 (다시 돌리면 지우고 새로)
	     Floor     안뜰 단(흰 돌 원판, 청화·금 띠, 나침 무늬), 네 계단, 길 포석과 청화 연석, 반사지, 큰 문 앞마당
	     Tower     기단, 탑 여섯 토막, 코어·껍질·도는 파편(Spin 스크립트), 보이지 않는 충돌(기둥 원통, 계단 비탈)
	     Colonnade 열주와 인방
	     Items     나머지(표대로 땅에 광선을 쏴 앉힌다)
	되돌리기: Sanctuary_탑의성역 을 지우고 옛것 셋을 Surface 로, 땅 조각은 속성으로 되칠한다.
]]

local D = (function()
--@@DATA@@
end)()
local STEPS = (function()
--@@STEPS@@
end)()

local RGB = Color3.fromRGB
local M = Enum.Material
local SS = game:GetService("ServerStorage")
local S = workspace.Surface
local kit = assert(SS:FindFirstChild("SanctuaryKit"), "ServerStorage.SanctuaryKit 이 없다. Sanctuary_Kit.luau 를 먼저")
local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local CX, CZ, TT = D.CX, D.CZ, D.TT
local TR = D.TERRACE_R
local CENTER = Vector3.new(CX, 0, CZ)
local MARBLE = { RGB(233, 230, 220), M.Marble }
local MARBLE2 = { RGB(224, 221, 210), M.Marble }
local COBALT = { RGB(36, 71, 143), M.SmoothPlastic }
local GOLD = { RGB(201, 162, 74), M.Metal }
local BLUE = RGB(122, 202, 255)

-- 1. 옛것
local bak = SS:FindFirstChild("탑의성역_옛것")
if not bak then
	bak = Instance.new("Folder")
	bak.Name = "탑의성역_옛것"
	bak.Parent = SS
end
for _, n in ipairs({ "Ruins_탑의성역", "Fill_탑의성역", "Struct_탑의성역" }) do
	local f = S:FindFirstChild(n)
	if f then
		f.Parent = bak
		say("옛것 옮김 %s", n)
	end
end

-- 3. 새 폴더
local root = S:FindFirstChild("Sanctuary_탑의성역")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "Sanctuary_탑의성역"
root.Parent = S
local function sub(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local fFloor, fTower, fCol, fItems = sub("Floor"), sub("Tower"), sub("Colonnade"), sub("Items")

local function part(parent, name, cf, size, skin, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color, p.Material = skin[1], skin[2]
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- 원통 축(X)을 세운다

-- 2. 땅 빛
local G = assert(S.World:FindFirstChild("G_탑의성역"), "World.G_탑의성역 이 없다")
local nGrass = 0
for i, p in ipairs(G:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("^Gs_") then
		if p:GetAttribute("OrigMat") == nil then
			p:SetAttribute("OrigColor", p.Color)
			p:SetAttribute("OrigMat", p.Material.Name)
		end
		if p:GetAttribute("OrigMat") ~= "Sand" then
			local k = (i * 37) % 11 - 5
			p.Color = RGB(88 + k, 128 + k, 68 + math.floor(k / 2))
			p.Material = M.Grass
			nGrass += 1
		end
	end
end
say("잔디로 칠한 땅 조각 %d", nGrass)

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G, fFloor }
local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), rp)
	return h and h.Position.Y
end
local function flat(x, y, z, dir)
	-- dir 쪽을 보는(로컬 Z 가 dir) 수평 CFrame
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + dir.X, y, z + dir.Z))
end

-- 4. 안뜰 단
local BOT = 2
part(fFloor, "Terrace", CFrame.new(CX, (TT + BOT) / 2, CZ) * UPRIGHT, Vector3.new(TT - BOT, TR * 2, TR * 2), MARBLE, CYL)
part(fFloor, "TerraceBand", CFrame.new(CX, TT - 2.6, CZ) * UPRIGHT, Vector3.new(1.6, TR * 2 + 0.8, TR * 2 + 0.8), COBALT, CYL)
part(fFloor, "TerraceGold", CFrame.new(CX, TT - 1.4, CZ) * UPRIGHT, Vector3.new(0.3, TR * 2 + 0.9, TR * 2 + 0.9), GOLD, CYL)
part(fFloor, "TerraceFoot", CFrame.new(CX, BOT + 1.0, CZ) * UPRIGHT, Vector3.new(2.0, TR * 2 + 2.4, TR * 2 + 2.4), MARBLE2, CYL)
-- 나침 무늬: 네 길 쪽 청화 띠와 r 140 고리(짧은 띠 48 개)
for q = 0, 3 do
	local a = math.rad(q * 90)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local c = CENTER + dir * 138
	part(fFloor, "Compass", flat(c.X, TT, c.Z, dir), Vector3.new(3, 0.2, 76), COBALT)
end
for k = 0, 47 do
	local a = math.rad(k * 7.5 + 3.75)
	local dir = Vector3.new(-math.sin(a), 0, math.cos(a))
	local c = CENTER + Vector3.new(math.cos(a), 0, math.sin(a)) * 140
	part(fFloor, "CompassRing", flat(c.X, TT, c.Z, dir), Vector3.new(1.6, 0.2, 2 * math.pi * 140 / 48 - 1.2), COBALT)
end

-- 5. 네 계단 (안뜰 가장자리에서 땅까지)
for _, w in ipairs(D.WAYS) do
	local a = math.rad(w[2])
	local width = w[5]
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local foot = CENTER + dir * (TR + 16)
	local g0 = assert(groundY(foot.X, foot.Z), "계단 발치에 땅이 없다 " .. w[1])
	local rise = TT - g0
	local n = math.ceil(rise / 0.72)
	local tread = 1.5
	for k = 1, n do
		local top = g0 + rise * k / n
		local rIn = TR + (n - k) * tread
		local c = CENTER + dir * (rIn + tread / 2)
		part(fFloor, "Step", flat(c.X, (top + g0 - 1) / 2, c.Z, dir), Vector3.new(width, top - g0 + 1, tread), MARBLE)
		local e = CENTER + dir * (rIn + tread - 0.15)
		part(fFloor, "Nose", flat(e.X, top + 0.05, e.Z, dir), Vector3.new(width, 0.14, 0.3), COBALT)
	end
	for _, s in ipairs({ -1, 1 }) do
		local len = n * tread
		local c = CENTER + dir * (TR + len / 2) + side * s * (width / 2 + 1)
		local h = TT + 0.8 - (g0 - 1)
		part(fFloor, "Cheek", flat(c.X, g0 - 1 + h / 2, c.Z, dir), Vector3.new(2, h, len), MARBLE)
		part(fFloor, "CheekCap", flat(c.X, TT + 0.9, c.Z, dir), Vector3.new(2.2, 0.2, len + 0.2), COBALT)
	end
	say("%s 계단 %d 단, 오름 %.1f", w[1], n, rise)
end

-- 6. 길 포석과 청화 연석
local nPave = 0
for _, w in ipairs(D.WAYS) do
	local a = math.rad(w[2])
	local r0, r1, width = w[3], w[4], w[5]
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local nseg = math.ceil((r1 - r0) / 30)
	local seg = (r1 - r0) / nseg
	for j = 0, nseg - 1 do
		local c = CENTER + dir * (r0 + seg * (j + 0.5))
		local gy = groundY(c.X, c.Z) or 8
		local top = gy + 0.35
		part(fFloor, "Pave", flat(c.X, top - 0.6, c.Z, dir), Vector3.new(width, 1.2, seg), j % 2 == 0 and MARBLE or MARBLE2)
		for _, s in ipairs({ -1, 1 }) do
			local e = c + side * s * (width / 2 + 0.5)
			part(fFloor, "Curb", flat(e.X, top - 0.55, e.Z, dir), Vector3.new(1.0, 1.3, seg), COBALT)
		end
		nPave += 1
	end
end
-- 큰 문 밖 앞마당
do
	local c = CENTER + Vector3.new(0, 0, 700)
	local gy = groundY(c.X, c.Z) or 8
	part(fFloor, "GateCourt", CFrame.new(c.X, gy + 0.35 - 0.6, c.Z), Vector3.new(44, 1.2, 44), MARBLE)
	for _, s in ipairs({ -1, 1 }) do
		part(fFloor, "GateCourtCurb", CFrame.new(c.X + s * 22.5, gy + 0.35 - 0.55, c.Z), Vector3.new(1.0, 1.3, 44), COBALT)
	end
end
say("포석 %d 토막", nPave)

-- 7. 반사지
for _, pl in ipairs(D.POOLS) do
	local u, v0, v1, w = pl[1], pl[2], pl[3], pl[4]
	local cx, cz, L = CX + u, CZ + (v0 + v1) / 2, v1 - v0
	local gy = groundY(cx, cz) or 8
	part(fFloor, "PoolBed", CFrame.new(cx, gy - 0.2, cz), Vector3.new(w, 0.5, L), { RGB(24, 44, 60), M.Slate })
	local wtr = part(fFloor, "PoolWater", CFrame.new(cx, gy + 0.2, cz), Vector3.new(w, 0.3, L), { RGB(70, 118, 150), M.Glass })
	wtr.Transparency = 0.3
	wtr.Reflectance = 0.3
	wtr.CanCollide = false
	for _, s in ipairs({ -1, 1 }) do
		part(fFloor, "PoolRim", CFrame.new(cx + s * (w / 2 + 0.8), gy + 0.45, cz), Vector3.new(1.6, 1.3, L + 3.2), MARBLE)
		part(fFloor, "PoolRimLine", CFrame.new(cx + s * (w / 2 + 0.8), gy + 1.15, cz), Vector3.new(0.5, 0.12, L + 3.2), COBALT)
		part(fFloor, "PoolRim", CFrame.new(cx, gy + 0.45, cz + s * (L / 2 + 0.8)), Vector3.new(w, 1.3, 1.6), MARBLE)
	end
end

-- 8. 탑
local foot = CFrame.new(CX, TT, CZ)
local function put(name, cf, parent)
	local c = assert(kit:FindFirstChild(name), "틀이 없다 " .. name):Clone()
	c:PivotTo(cf)
	c.Parent = parent
	return c
end
put("Tower_Plinth", foot, fTower)
for k = 1, 6 do
	put("Tower_S" .. k, foot * CFrame.new(0, 12, 0), fTower)
end
local fHit = Instance.new("Folder")
fHit.Name = "Collision"
fHit.Parent = fTower
local function hitPart(name, cf, size, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Parent = fHit
	return p
end
for z = 0, 390, 26 do
	local r = 14 - 6 * (z + 13) / 520
	hitPart("ColumnHit", foot * CFrame.new(0, 12 + z + 13, 0) * UPRIGHT, Vector3.new(26, r * 2, r * 2), CYL)
end
local nRamp = 0
local base = foot.Position + Vector3.new(0, 12, 0)
-- 기단 윗면에서 첫 계단으로: 첫 두 계단이 오르는 쪽 반대로 한 칸 물린 자리
local p0 = base + Vector3.new(STEPS[1][2], STEPS[1][3], STEPS[1][4])
local p1 = base + Vector3.new(STEPS[2][2], STEPS[2][3], STEPS[2][4])
local q = p0 + (p0 - p1)
local prev = { Vector3.new(q.X, base.Y, q.Z), STEPS[1][1] - 1, STEPS[1][5] }
for _, st in ipairs(STEPS) do
	local p = base + Vector3.new(st[2], st[3], st[4])
	if st[1] - prev[2] == 1 then
		local a, b = prev[1], p
		local len = (b - a).Magnitude
		hitPart("StairRamp", CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.3, 0), Vector3.new(st[5], 0.6, len + 0.4))
		nRamp += 1
	end
	prev = { p, st[1], st[5] }
end
say("계단 비탈 %d", nRamp)

-- 코어, 껍질, 도는 것
local topY = TT + 12 + 560
local at = Vector3.new(CX, topY, CZ)
local core = part(fTower, "Core", CFrame.new(at) * CFrame.Angles(0.5, 0.4, 0.2), Vector3.new(21, 21, 21), { BLUE, M.Neon })
core.CanCollide = false
local cl = Instance.new("PointLight")
cl.Color, cl.Range, cl.Brightness, cl.Shadows = BLUE, 60, 4, false
cl.Parent = core
local shell = part(fTower, "CoreShell", CFrame.new(at) * CFrame.Angles(0.2, 0.9, 0.6), Vector3.new(37, 37, 37), { BLUE, M.Neon })
shell.CanCollide = false
shell.Transparency = 0.78
local orb = Instance.new("Folder")
orb.Name = "Orbit"
orb.Parent = fTower
local function orbitAt(r, ph, tl)
	return CFrame.Angles(tl, 0, 0) * Vector3.new(math.cos(ph) * r, 0, math.sin(ph) * r)
end
local SUB = { { 32, 0.22, 12, 4.3 }, { 43, -0.15, -34, 3.3 }, { 25, 0.31, 58, 3.0 }, { 53, 0.11, 24, 3.7 }, { 37, -0.26, -70, 2.7 } }
for i, sc in ipairs(SUB) do
	local ph, tl = i * 1.3, math.rad(sc[3])
	local p = part(orb, "SubCore" .. i, CFrame.new(at + orbitAt(sc[1], ph, tl)), Vector3.new(sc[4] * 2, sc[4] * 2, sc[4] * 2), { BLUE, M.Neon })
	p.CanCollide = false
	p:SetAttribute("R", sc[1])
	p:SetAttribute("S", sc[2])
	p:SetAttribute("P", ph)
	p:SetAttribute("T", tl)
	p:SetAttribute("SP", 0.25)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = BLUE, 24, 2, false
	l.Parent = p
end
local rng = Random.new(51774)
local KINDS = { "Debris_Rib", "Debris_Step", "Debris_Drum" }
for i = 1, 36 do
	local c = kit[KINDS[i % 3 + 1]]:Clone()
	c:ScaleTo(rng:NextNumber(0.35, 0.8))
	local r = rng:NextNumber(55, 165)
	local ph, tl = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.75, 0.75)
	c:SetAttribute("R", r)
	c:SetAttribute("S", (rng:NextNumber() < 0.5 and -1 or 1) * (20 / r))
	c:SetAttribute("P", ph)
	c:SetAttribute("T", tl)
	c:SetAttribute("SP", rng:NextNumber(0.15, 0.6))
	c:PivotTo(CFrame.new(at + orbitAt(r, ph, tl)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)))
	c.Name = "Debris" .. i
	c.Parent = orb
end
local spin = Instance.new("Script")
spin.Name = "Spin"
spin.Source = [==[
-- 탑 꼭대기 코어와 도는 파편. 플레이 때만 돈다 (Sanctuary_Build.luau 가 넣었다)
local RS = game:GetService("RunService")
local root = script.Parent
local core = root:WaitForChild("Core")
local shell = root:WaitForChild("CoreShell")
local orbit = root:WaitForChild("Orbit")
local origin = core.Position
local list = {}
for _, p in ipairs(orbit:GetChildren()) do
	if p:GetAttribute("R") then
		list[#list + 1] = {
			p = p, model = p:IsA("Model"), r = p:GetAttribute("R"), s = p:GetAttribute("S"),
			ph = p:GetAttribute("P"), tl = p:GetAttribute("T"), sp = p:GetAttribute("SP"),
		}
	end
end
RS.Heartbeat:Connect(function()
	local t = time()
	core.CFrame = CFrame.new(origin) * CFrame.Angles(t * 0.12, t * 0.18, t * 0.09)
	shell.CFrame = CFrame.new(origin) * CFrame.Angles(-t * 0.07, -t * 0.11, t * 0.05)
	for _, e in ipairs(list) do
		local a = e.ph + t * e.s
		local v = CFrame.Angles(e.tl, 0, 0) * Vector3.new(math.cos(a) * e.r, 0, math.sin(a) * e.r)
		local cf = CFrame.new(origin + v) * CFrame.Angles(t * e.sp * 0.7, t * e.sp, t * e.sp * 0.4)
		if e.model then
			e.p:PivotTo(cf)
		else
			e.p.CFrame = cf
		end
	end
end)
]==]
spin.Parent = fTower

-- 9. 열주 인방, 10. 놓을 것
for _, l in ipairs(D.LINTELS) do
	put("Lintel", CFrame.new(l[1], TT + 35.2, l[2]) * CFrame.Angles(0, math.rad(l[3]), 0), fCol)
end
local counts = {}
local miss = 0
for _, it in ipairs(D.ITEMS) do
	local m, x, z, yaw, sink = it[1], it[2], it[3], it[4], it[5]
	local y = groundY(x, z)
	if not y then
		miss += 1
		y = 8
	end
	put(m, CFrame.new(x, y - sink, z) * CFrame.Angles(0, math.rad(yaw), 0), m:match("^Col_") and fCol or fItems)
	counts[m] = (counts[m] or 0) + 1
end
local t = {}
for k, v in pairs(counts) do
	t[#t + 1] = k .. " " .. v
end
table.sort(t)
say("놓은 것 %d (땅 못 찾음 %d): %s", #D.ITEMS, miss, table.concat(t, ", "))
say("인방 %d, 안뜰 윗면 %.2f, 코어 높이 %.1f", #D.LINTELS, TT, topY)

local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/sancbuild", table.concat(report, "\n"))
end)
print("sancbuild", #report)
