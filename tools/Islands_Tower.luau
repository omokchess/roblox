--!nocheck
--[[
	Islands_Tower.luau — 탑의 성역 한가운데 탑.

	후보 다섯 중 5번(늑골 + 나선계단)을 골라 실제 자리에 세운 것이다.
	[tools/Islands_TowerSamples.luau] 에 나머지 후보가 남아 있다.

	구조는 둘이 겹쳐 있다.
	  안쪽 — 가운데 기둥과 그것을 감고 오르는 나선계단. 오르는 길이다
	  바깥 — 굵은 갈빗대 다섯이 꼬여 오르는 새장. 덩어리와 실루엣을 만든다

	**갈빗대는 계단과 반대로 꼰다.** 같은 방향이면 두 나선이 그냥 포개져 보인다.
	반대로 꼬아야 서로 교차하면서 격자 무늬가 생긴다. 이게 이 형태의 전부다.

	위로 갈수록 부서진다. 전체 높이의 42% 지점부터 조각이 빠지기 시작하고
	꼭대기에서는 형태가 완전히 풀린다. 떨어져 나간 것은 사라지지 않고
	꼭대기 파란 정육면체 코어를 도는 잔해가 된다.

	**회전은 편집 화면에서 안 보인다.** 파트를 매 프레임 옮기는 일이라
	Spin 스크립트가 플레이 모드에서 돈다. 편집 화면에는 시작 자리로 서 있다.

	되돌리기: workspace.Surface.Struct_탑의성역:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local X, Z = 1200, -4400 -- 탑의 성역 한가운데
local HEIGHT = 1500
local BREAK_FROM = 0.42 -- 전체 높이의 이 지점부터 부서진다
local BREAK_POW = 1.15 -- 작을수록 빨리 무너진다

-- 안쪽: 기둥과 계단
local COL_R0, COL_R1 = 46, 23
local RAD0, RAD1 = 138, 61 -- 계단 바깥 반지름
local TURNS = 4.0
local STEPS = 172

-- 바깥: 갈빗대. 계단보다 바깥이어야 감싸는 것으로 보인다
local RIBS = 5
local CR0, CR1 = 206, 96
local CTURNS = -2.4 -- 부호가 계단과 반대다
local SEG = 100

local DEBRIS = 70
local SUBCORE = {
	{ r = 95, s = 0.22, t = 12, size = 13 },
	{ r = 130, s = -0.15, t = -34, size = 10 },
	{ r = 74, s = 0.31, t = 58, size = 9 },
	{ r = 158, s = 0.11, t = 24, size = 11 },
	{ r = 112, s = -0.26, t = -70, size = 8 },
}

local STONE = RGB(214, 210, 194)
local JOINT = RGB(128, 128, 120)
local GLOW = RGB(255, 214, 140)
local BLUE = RGB(122, 202, 255)

local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World }

local hit = workspace:Raycast(Vector3.new(X, 900, Z), Vector3.new(0, -1600, 0), rp)
assert(hit, "탑 자리 (" .. X .. ", " .. Z .. ") 아래에 지반이 없다")
local FOOT = hit.Position.Y - 10

local old = S:FindFirstChild("Struct_탑의성역")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Struct_탑의성역"
root.Parent = S

local rng = Random.new(51774)
local total, gone = 0, 0

local function put(name, cf, size, neon, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	if neon then
		p.Color = GLOW
		p.Material = M.Neon
	else
		p.Color = STONE:Lerp(JOINT, rng:NextNumber(0, 0.5))
		p.Material = M.Limestone
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	total += 1
	return p
end

-- t 는 0(바닥)에서 1(꼭대기). 부서진 정도를 돌려준다
local function brAt(t)
	if t < BREAK_FROM then
		return 0
	end
	return ((t - BREAK_FROM) / (1 - BREAK_FROM)) ^ BREAK_POW
end

-- 남은 조각은 비뚤어진다. 멀쩡하면 부서진 게 아니라 안 지은 것이다
local function lean(br, scale)
	if br < 0.04 then
		return CFrame.new()
	end
	local a = br * 0.7
	local d = br * (scale or 24)
	return CFrame.new(rng:NextNumber(-d, d), rng:NextNumber(-d * 0.6, d * 0.6), rng:NextNumber(-d, d))
		* CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a))
end

--=== 기단 ===--
for k = 0, 2 do
	put(
		"Plinth" .. k,
		CFrame.new(X, FOOT - 8 - k * 18, Z) * CFrame.Angles(0, k * 0.4, 0),
		Vector3.new(CR0 * 2 + k * 52, 18, CR0 * 2 + k * 52),
		false
	)
end

--=== 안쪽 기둥 ===--
local ny = math.floor(HEIGHT / 17)
for i = 0, ny do
	local t = i / ny
	local br = brAt(t)
	if rng:NextNumber() > br * 0.9 then
		local r = COL_R0 + (COL_R1 - COL_R0) * t
		put(
			"Col" .. i,
			CFrame.new(X, FOOT + t * HEIGHT, Z) * CFrame.Angles(0, i * 0.17, 0) * lean(br, 18),
			Vector3.new(r * 2, 19, r * 2),
			false
		)
	else
		gone += 1
	end
end

--=== 나선계단 ===--
for i = 0, STEPS do
	local t = i / STEPS
	local a = t * TURNS * math.pi * 2
	local r = RAD0 + (RAD1 - RAD0) * t
	local br = brAt(t)
	if rng:NextNumber() > br then
		local cf = CFrame.new(X + math.cos(a) * r, FOOT + t * HEIGHT, Z + math.sin(a) * r)
			* CFrame.Angles(0, -a, 0)
			* lean(br, 22)
		put("Step" .. i, cf, Vector3.new(r * 0.95, 10, 2 * math.pi * r / STEPS * TURNS * 1.35), false)
		-- 바깥 난간. 네 칸에 하나만. 다 세우면 벽이 되어 계단이 안 보인다
		if i % 4 == 0 then
			put("Rail" .. i, cf * CFrame.new(r * 0.48, 22, 0), Vector3.new(7, 34, 9), i % 16 == 0)
		end
	else
		gone += 1
	end
end

--=== 바깥 갈빗대 ===--
local pt = {}
for rb = 1, RIBS do
	pt[rb] = {}
	for i = 0, SEG do
		local t = i / SEG
		local a = t * CTURNS * math.pi * 2 + (rb - 1) / RIBS * math.pi * 2
		local r = CR0 + (CR1 - CR0) * t
		pt[rb][i] = Vector3.new(X + math.cos(a) * r, FOOT + t * HEIGHT, Z + math.sin(a) * r)
		local br = brAt(t)
		if rng:NextNumber() > br * 0.95 then
			put(
				string.format("Rib%d_%d", rb, i),
				CFrame.new(pt[rb][i]) * CFrame.Angles(0, -a, 0) * lean(br, 20),
				Vector3.new(32, 28, HEIGHT / SEG * 2.1),
				false
			)
		else
			gone += 1
		end
	end
end

-- 갈빗대끼리 묶는 가로대. 없으면 국수 다발로 보인다
for i = 8, SEG - 8, 11 do
	local t = i / SEG
	if brAt(t) < 0.55 then
		for rb = 1, RIBS do
			local a, b = pt[rb][i], pt[rb % RIBS + 1][i]
			put(
				string.format("Tie%d_%d", rb, i),
				CFrame.lookAt((a + b) / 2, b),
				Vector3.new(10, 10, (b - a).Magnitude),
				i % 33 == 8
			)
		end
	end
end

--=== 꼭대기 ===--
local TOP = FOOT + HEIGHT
local CY = TOP + 210
local at = Vector3.new(X, CY, Z)

local function orbitAt(r, phase, tilt)
	return CFrame.Angles(tilt, 0, 0) * Vector3.new(math.cos(phase) * r, 0, math.sin(phase) * r)
end

local core = Instance.new("Part")
core.Name = "Core"
core.Anchored = true
core.CanCollide = false
core.Size = Vector3.new(62, 62, 62)
core.CFrame = CFrame.new(at) * CFrame.Angles(0.5, 0.4, 0.2)
core.Color = BLUE
core.Material = M.Neon
core.Parent = root
total += 1

local cl = Instance.new("PointLight")
cl.Color = BLUE
cl.Range = 80
cl.Brightness = 5
cl.Shadows = false
cl.Parent = core

-- 겉껍질도 정육면체. 반대로 돌아 속이 비어 보이지 않게 한다
local shell = Instance.new("Part")
shell.Name = "CoreShell"
shell.Anchored = true
shell.CanCollide = false
shell.Size = Vector3.new(112, 112, 112)
shell.CFrame = CFrame.new(at) * CFrame.Angles(0.2, 0.9, 0.6)
shell.Color = BLUE
shell.Material = M.Neon
shell.Transparency = 0.78
shell.Parent = root
total += 1

local orb = Instance.new("Folder")
orb.Name = "Orbit"
orb.Parent = root

for i, sc in ipairs(SUBCORE) do
	local ph, tl = i * 1.3, math.rad(sc.t)
	local p = Instance.new("Part")
	p.Name = "SubCore" .. i
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(sc.size * 2, sc.size * 2, sc.size * 2)
	p.Color = BLUE
	p.Material = M.Neon
	p:SetAttribute("R", sc.r)
	p:SetAttribute("S", sc.s)
	p:SetAttribute("P", ph)
	p:SetAttribute("T", tl)
	p:SetAttribute("SP", 0.25)
	p.CFrame = CFrame.new(at + orbitAt(sc.r, ph, tl)) * CFrame.Angles(0.4, 0.3, 0.1)
	p.Parent = orb
	total += 1
	local sl = Instance.new("PointLight")
	sl.Color = BLUE
	sl.Range = 28
	sl.Brightness = 2
	sl.Shadows = false
	sl.Parent = p
end

for i = 1, DEBRIS do
	local r = rng:NextNumber(150, 470)
	local ph, tl = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.75, 0.75)
	local p = Instance.new("Part")
	p.Name = "Debris" .. i
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(rng:NextNumber(14, 54), rng:NextNumber(7, 18), rng:NextNumber(14, 54))
	p.Color = STONE:Lerp(JOINT, rng:NextNumber(0, 0.6))
	p.Material = M.Limestone
	p:SetAttribute("R", r)
	-- 먼 것일수록 느리다. 같은 속도면 원반 하나가 통째로 도는 것으로 보인다
	p:SetAttribute("S", (rng:NextNumber() < 0.5 and -1 or 1) * (58 / r))
	p:SetAttribute("P", ph)
	p:SetAttribute("T", tl)
	p:SetAttribute("SP", rng:NextNumber(0.15, 0.6))
	p.CFrame = CFrame.new(at + orbitAt(r, ph, tl))
		* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3))
	p.Parent = orb
	total += 1
end

local spin = Instance.new("Script")
spin.Name = "Spin"
spin.Source = [==[
local RS = game:GetService("RunService")
local root = script.Parent
local core = root:WaitForChild("Core")
local shell = root:WaitForChild("CoreShell")
local orbit = root:WaitForChild("Orbit")
local origin = core.Position

local list = {}
for _, p in ipairs(orbit:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("R") then
		list[#list + 1] = {
			p = p, r = p:GetAttribute("R"), s = p:GetAttribute("S"),
			ph = p:GetAttribute("P"), tl = p:GetAttribute("T"), sp = p:GetAttribute("SP"),
		}
	end
end

RS.Heartbeat:Connect(function()
	local t = time()
	core.CFrame = CFrame.new(origin) * CFrame.Angles(t * 0.12, t * 0.18, t * 0.09)
	-- 껍질은 반대로 돈다. 같이 돌면 한 덩어리로 보인다
	shell.CFrame = CFrame.new(origin) * CFrame.Angles(-t * 0.07, -t * 0.11, t * 0.05)
	for _, e in ipairs(list) do
		local a = e.ph + t * e.s
		local v = CFrame.Angles(e.tl, 0, 0) * Vector3.new(math.cos(a) * e.r, 0, math.sin(a) * e.r)
		e.p.CFrame = CFrame.new(origin + v) * CFrame.Angles(t * e.sp * 0.7, t * e.sp, t * e.sp * 0.4)
	end
end)
]==]
spin.Parent = root

--=== 자기검사 ===--
assert(total > 500, "탑이 " .. total .. "개뿐이다")
assert(gone > 120, "떨어져 나간 조각이 " .. gone .. "개뿐이다. BREAK_FROM 을 내려라")
-- 갈빗대가 계단 안쪽으로 들어오면 감싸는 게 아니라 뚫고 지나간 것이 된다
assert(CR1 > RAD1 + 20 and CR0 > RAD0 + 20, "갈빗대가 계단보다 안쪽이다")
-- 두 나선이 같은 방향이면 겹쳐 보인다
assert(TURNS * CTURNS < 0, "계단과 갈빗대가 같은 방향으로 꼬였다")

print(
	string.format(
		"[Tower] 파트 %d개 / 떨어져 나간 조각 %d / 잔해 %d / 바닥 %d 꼭대기 %d 코어 %d",
		total,
		gone,
		DEBRIS,
		FOOT,
		TOP,
		CY
	)
)
