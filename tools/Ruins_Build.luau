--!nocheck
--[[
	Ruins_Build.luau — 2026-09-27. 탑의 성역 재작업을 짓는다 (기존 컨셉·색 그대로, 큰 돌 블록 유적).

	배치 tools/ruins_plan.py(→ Ruins_data.luau), 모델 ServerStorage.RuinsKit(Ruins_Kit.luau),
	탑 계단 점 Ruins_steps.luau, 올림 값 Ruins_lifts.luau. python tools/ruins_run.py 가 넷을 합쳐 Ruins_Build_run.luau 를 만든다.

	1. 옛 성역(Ruins_·Fill_·Struct_탑의성역)을 ServerStorage.탑의성역_옛것 으로 옮긴다(지우지 않음). 땅(World.G_탑의성역)은 그대로
	2. Surface.Ruins2_탑의성역 에 짓는다 (다시 돌리면 지우고 새로)
	   Tower   기단(둘레 최저 땅 높이), 탑 여섯 토막, 보이지 않는 충돌(기둥 원통, 계단 비탈),
	           정육면체 코어·껍질·서브코어와 도는 돌 파편(Spin)
	   Items   표대로 땅에 광선을 쏴 앉힌다(모델 올림 값 + 표의 묻기만큼 묻고, 표의 기울기를 준다). 인방은 기둥 머리에
	   Float   떠 있는 바위(땅 위 높이)
	   빛 기둥 네 받침 위에 가는 네온 빛 기둥
	되돌리기: Ruins2_탑의성역 을 지우고 옛것 셋을 Surface 로.
]]
local D = (function()
--@@DATA@@
end)()
local STEPS = (function()
--@@STEPS@@
end)()
local LIFTS = (function()
--@@LIFTS@@
end)()

local RGB = Color3.fromRGB
local M = Enum.Material
local SS = game:GetService("ServerStorage")
local S = workspace.Surface
local kit = assert(SS:FindFirstChild("RuinsKit"), "ServerStorage.RuinsKit 이 없다. Ruins_Kit.luau 를 먼저")
local G = S.World["G_탑의성역"]
local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end
local CX, CZ = D.CX, D.CZ
local BLUE = RGB(122, 202, 255)
local GLOW = RGB(255, 214, 140)

-- 1. 옛것
local bak = SS:FindFirstChild("탑의성역_옛것") or Instance.new("Folder")
bak.Name = "탑의성역_옛것"
bak.Parent = SS
for _, n in ipairs({ "Ruins_탑의성역", "Fill_탑의성역", "Struct_탑의성역" }) do
	local f = S:FindFirstChild(n)
	if f then
		f.Parent = bak
		say("옛것 옮김 %s", n)
	end
end

-- 2. 새 폴더
local root = S:FindFirstChild("Ruins2_탑의성역")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "Ruins2_탑의성역"
root.Parent = S
local function sub(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local fTower, fItems, fFloat = sub("Tower"), sub("Items"), sub("Float")

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }
local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), rp)
	return h and h.Position.Y
end
local function put(name, cf, parent)
	local c = assert(kit:FindFirstChild(name), "틀이 없다 " .. name):Clone()
	c:PivotTo(cf)
	c.Parent = parent
	return c
end
local function part(parent, name, cf, size, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color, p.Material = color, mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 3. 기단과 탑
local lo = 1e9
for k = 0, 23 do
	local a = math.rad(k * 15)
	local g = groundY(CX + math.cos(a) * 131, CZ + math.sin(a) * 131)
	if g then
		lo = math.min(lo, g)
	end
end
local baseY = lo - 0.3
put("Tower_Podium", CFrame.new(CX, baseY - (LIFTS.Tower_Podium or 0), CZ), fTower)
local foot = CFrame.new(CX, baseY + 24, CZ)
for k = 1, 6 do
	put("Tower_S" .. k, foot, fTower)
end
local fHit = Instance.new("Folder")
fHit.Name = "Collision"
fHit.Parent = fTower
local function hit(name, cf, size, shape)
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
end
for z = 0, 452, 8 do
	local r = 28 - 13 * (z + 4) / 560
	hit("ColumnHit", foot * CFrame.new(0, z + 4, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(8, r * 2, r * 2),
		Enum.PartType.Cylinder)
end
local nRamp = 0
local p0 = foot.Position + Vector3.new(STEPS[1][2], STEPS[1][3], STEPS[1][4])
local p1 = foot.Position + Vector3.new(STEPS[2][2], STEPS[2][3], STEPS[2][4])
local q = p0 + (p0 - p1)
local prev = { Vector3.new(q.X, foot.Y, q.Z), STEPS[1][1] - 1 }
for _, st in ipairs(STEPS) do
	local p = foot.Position + Vector3.new(st[2], st[3], st[4])
	if st[1] - prev[2] <= 2 then
		local a, b = prev[1], p
		hit("StairRamp", CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.4, 0), Vector3.new(st[5], 0.8, (b - a).Magnitude + 0.5))
		nRamp += 1
	end
	prev = { p, st[1] }
end
say("기단 바닥 %.2f, 탑 발치 %.2f, 계단 비탈 %d", baseY, foot.Y, nRamp)

-- 코어(정육면체), 껍질, 서브코어, 도는 돌
local at = foot.Position + Vector3.new(0, 620, 0)
local core = part(fTower, "Core", CFrame.new(at) * CFrame.Angles(0.5, 0.4, 0.2), Vector3.new(24, 24, 24), BLUE, M.Neon)
core.CanCollide = false
local cl = Instance.new("PointLight")
cl.Color, cl.Range, cl.Brightness, cl.Shadows = BLUE, 70, 4, false
cl.Parent = core
local shell = part(fTower, "CoreShell", CFrame.new(at) * CFrame.Angles(0.2, 0.9, 0.6), Vector3.new(42, 42, 42), BLUE, M.Neon)
shell.CanCollide = false
shell.Transparency = 0.78
local orb = Instance.new("Folder")
orb.Name = "Orbit"
orb.Parent = fTower
local function orbitAt(r, ph, tl)
	return CFrame.Angles(tl, 0, 0) * Vector3.new(math.cos(ph) * r, 0, math.sin(ph) * r)
end
local SUB = { { 36, 0.22, 12, 5 }, { 48, -0.15, -34, 4 }, { 28, 0.31, 58, 3.4 }, { 60, 0.11, 24, 4.4 }, { 42, -0.26, -70, 3.2 } }
for i, sc in ipairs(SUB) do
	local ph, tl = i * 1.3, math.rad(sc[3])
	local p = part(orb, "SubCore" .. i, CFrame.new(at + orbitAt(sc[1], ph, tl)), Vector3.new(sc[4] * 2, sc[4] * 2, sc[4] * 2), BLUE, M.Neon)
	p.CanCollide = false
	p:SetAttribute("R", sc[1])
	p:SetAttribute("S", sc[2])
	p:SetAttribute("P", ph)
	p:SetAttribute("T", tl)
	p:SetAttribute("SP", 0.25)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = BLUE, 26, 2, false
	l.Parent = p
end
local rng = Random.new(51774)
local KINDS = { "Debris_A", "Debris_B", "Debris_C" }
for i = 1, 40 do
	local c = kit[KINDS[i % 3 + 1]]:Clone()
	c:ScaleTo(rng:NextNumber(0.45, 1.0))
	local r = rng:NextNumber(60, 180)
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
-- 탑 꼭대기 정육면체 코어와 도는 것. 플레이 때만 돈다 (Ruins_Build.luau 가 넣었다)
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

-- 4. 놓을 것
local counts, miss = {}, 0
local COL_TOP = 45.6 -- Col_Big 높이. 인방은 그 머리에
for _, it in ipairs(D.ITEMS) do
	local m, x, z, yaw, sink, tx, tz = it[1], it[2], it[3], it[4], it[5], it[6], it[7]
	local g = groundY(x, z)
	if not g then
		miss += 1
		g = 8
	end
	local y
	if sink == "col" then
		y = g + COL_TOP - 0.05
	else
		y = g - (LIFTS[m] or 0) - sink
	end
	put(m, CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tx), 0, math.rad(tz)), fItems)
	counts[m] = (counts[m] or 0) + 1
end
for _, f in ipairs(D.FLOATERS) do
	local m, x, z, h, yaw = f[1], f[2], f[3], f[4], f[5]
	local g = groundY(x, z) or 8
	put(m, CFrame.new(x, g + h, z) * CFrame.Angles(0, math.rad(yaw), 0), fFloat)
end
-- 빛 기둥
for _, b in ipairs(fItems:GetChildren()) do
	if b.Name == "Beacon_Base" then
		local p = b:GetPivot().Position
		local beam = part(fItems, "BeaconLight", CFrame.new(p + Vector3.new(0, 3.6 + 80, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(160, 2.4, 2.4), GLOW, M.Neon, Enum.PartType.Cylinder)
		beam.CanCollide = false
		beam.Transparency = 0.25
		beam.CastShadow = false
	end
end
local t = {}
for k, v in pairs(counts) do
	t[#t + 1] = k .. " " .. v
end
table.sort(t)
say("놓은 것 %d (땅 못 찾음 %d), 떠 있는 바위 %d", #D.ITEMS, miss, #D.FLOATERS)
say("%s", table.concat(t, ", "))
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/ruinsbuild", table.concat(report, "\n"))
end)
print("ruinsbuild", #report)
