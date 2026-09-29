--!nocheck
--[[
	Islands_TowerSamples.luau — 탑 후보 넷을 나란히 세운다.

	고르라고 만든 것이다. 탑의 성역 북쪽 바다 위에 900 간격으로 늘어선다.
	고른 뒤에 그 하나만 Islands_Tower.luau 로 옮겨 성역 한가운데 세운다.

	넷 다 공통으로
	  - 위로 갈수록 부서진다. 아래는 온전하고 꼭대기에서 형태가 풀린다
	  - 꼭대기에 **정육면체 파란 코어**가 뜨고 그 둘레를 서브코어가 돈다
	  - 떨어져 나간 잔해가 코어를 돈다. 먼 것일수록 느리다
	  - 회전은 플레이 모드에서만 보인다. 편집 화면에는 시작 자리로 서 있다

	다른 것은 실루엣뿐이다.
	  1 나선계단  가운데 기둥을 감고 오르는 계단. 오르는 길이 곧 형태다
	  2 나선판    판을 한 장씩 돌려 쌓았다. 드릴처럼 꼬인 덩어리
	  3 늑골      굵은 갈빗대 다섯이 꼬여 오르는 빈 새장. 속이 뚫려 있다
	  4 나선방    기둥 둘레를 방이 돌며 올라간다. 안에 들어갈 데가 있다

	되돌리기: workspace.Surface.TowerSamples:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local ORIGIN_X, ORIGIN_Z = -600, -7200 -- 첫 번째 샘플 자리
local GAP = 900 -- 샘플 간격
local FOOT = 30 -- 바다 위 이 높이에서 시작한다
local HEIGHT = 1300 -- 넷 다 같은 높이여야 비교가 된다
local BREAK_FROM = 0.58 -- 전체 높이의 이 지점부터 부서지기 시작한다

local STONE = RGB(214, 210, 194)
local JOINT = RGB(128, 128, 120)
local GLOW = RGB(255, 214, 140)
local BLUE = RGB(122, 202, 255)

local S = workspace.Surface
local old = S:FindFirstChild("TowerSamples")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "TowerSamples"
root.Parent = S

local rng = Random.new(4711)
local total = 0

local function put(parent, name, cf, size, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
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
	p.Parent = parent
	total += 1
	return p
end

-- t 는 0(바닥)에서 1(꼭대기). 부서진 정도를 돌려준다
local function brAt(t)
	if t < BREAK_FROM then
		return 0
	end
	return ((t - BREAK_FROM) / (1 - BREAK_FROM)) ^ 1.3
end

-- 부서진 자리의 남은 조각은 비뚤어진다. 멀쩡하면 그냥 안 지은 것이다
local function lean(br, scale)
	if br < 0.04 then
		return CFrame.new()
	end
	local a = br * 0.55
	local d = br * (scale or 22)
	return CFrame.new(rng:NextNumber(-d, d), rng:NextNumber(-d * 0.5, d * 0.5), rng:NextNumber(-d, d))
		* CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a))
end

--=== 꼭대기 장치. 넷이 공통으로 쓴다 ===--
local SUBCORE = {
	{ r = 95, s = 0.22, t = 12, size = 13 },
	{ r = 130, s = -0.15, t = -34, size = 10 },
	{ r = 74, s = 0.31, t = 58, size = 9 },
	{ r = 158, s = 0.11, t = 24, size = 11 },
	{ r = 112, s = -0.26, t = -70, size = 8 },
}
local DEBRIS = 30

local function orbitAt(r, phase, tilt)
	return CFrame.Angles(tilt, 0, 0) * Vector3.new(math.cos(phase) * r, 0, math.sin(phase) * r)
end

local function crown(fold, cx, cz, topY)
	local cy = topY + 190
	local at = Vector3.new(cx, cy, cz)

	-- 코어. 공이 아니라 정육면체다
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.Size = Vector3.new(58, 58, 58)
	core.CFrame = CFrame.new(at) * CFrame.Angles(0.5, 0.4, 0.2)
	core.Color = BLUE
	core.Material = M.Neon
	core.Parent = fold
	total += 1

	local l = Instance.new("PointLight")
	l.Color = BLUE
	l.Range = 70
	l.Brightness = 5
	l.Shadows = false
	l.Parent = core

	-- 겉껍질도 정육면체. 반대로 돌아 속이 비어 보이지 않게 한다
	local shell = Instance.new("Part")
	shell.Name = "CoreShell"
	shell.Anchored = true
	shell.CanCollide = false
	shell.Size = Vector3.new(104, 104, 104)
	shell.CFrame = CFrame.new(at) * CFrame.Angles(0.2, 0.9, 0.6)
	shell.Color = BLUE
	shell.Material = M.Neon
	shell.Transparency = 0.78
	shell.Parent = fold
	total += 1

	local orb = Instance.new("Folder")
	orb.Name = "Orbit"
	orb.Parent = fold

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
		sl.Range = 26
		sl.Brightness = 2
		sl.Shadows = false
		sl.Parent = p
	end

	for i = 1, DEBRIS do
		local r = rng:NextNumber(150, 430)
		local ph, tl = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.7, 0.7)
		local p = Instance.new("Part")
		p.Name = "Debris" .. i
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(rng:NextNumber(14, 50), rng:NextNumber(7, 16), rng:NextNumber(14, 50))
		p.Color = STONE:Lerp(JOINT, rng:NextNumber(0, 0.6))
		p.Material = M.Limestone
		p:SetAttribute("R", r)
		-- 먼 것일수록 느리다. 같으면 원반 하나가 통째로 도는 것으로 보인다
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
	spin.Parent = fold
end

local function plinth(fold, cx, cz, r)
	for k = 0, 2 do
		put(
			fold,
			"Plinth" .. k,
			CFrame.new(cx, FOOT - 8 - k * 16, cz) * CFrame.Angles(0, k * 0.4, 0),
			Vector3.new(r * 2 + k * 46, 16, r * 2 + k * 46),
			false
		)
	end
end

local function label(fold, cx, cz, text)
	local a = Instance.new("Part")
	a.Name = "Label"
	a.Anchored = true
	a.CanCollide = false
	a.Transparency = 1
	a.Size = Vector3.new(4, 4, 4)
	a.Position = Vector3.new(cx, FOOT - 70, cz)
	a.Parent = fold
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.new(0, 400, 0, 90)
	g.AlwaysOnTop = true
	g.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.TextColor3 = RGB(255, 255, 255)
	t.TextStrokeTransparency = 0
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = g
	total += 1
end

--=== 1. 나선계단 ===--
-- 가운데 기둥을 감고 오르는 계단만 있다. 오르는 길이 곧 형태다
local function sampleStair(fold, cx, cz)
	local COL_R0, COL_R1 = 52, 26
	local RAD0, RAD1 = 150, 66
	local TURNS = 3.6
	local steps = 150

	-- 기둥
	local ny = math.floor(HEIGHT / 17)
	for i = 0, ny do
		local t = i / ny
		local r = COL_R0 + (COL_R1 - COL_R0) * t
		local br = brAt(t)
		if rng:NextNumber() > br * 0.7 then
			put(
				fold,
				"Col" .. i,
				CFrame.new(cx, FOOT + t * HEIGHT, cz) * CFrame.Angles(0, i * 0.17, 0) * lean(br, 16),
				Vector3.new(r * 2, 19, r * 2),
				false
			)
		end
	end

	-- 계단
	for i = 0, steps do
		local t = i / steps
		local a = t * TURNS * math.pi * 2
		local r = RAD0 + (RAD1 - RAD0) * t
		local br = brAt(t)
		if rng:NextNumber() > br * 0.85 then
			local pos = Vector3.new(cx + math.cos(a) * r, FOOT + t * HEIGHT, cz + math.sin(a) * r)
			local cf = CFrame.new(pos) * CFrame.Angles(0, -a, 0) * lean(br, 20)
			put(fold, "Step" .. i, cf, Vector3.new(r * 0.95, 10, 2 * math.pi * r / steps * TURNS * 1.35), false)
			-- 바깥 난간. 세 칸에 하나만. 다 세우면 벽이 된다
			if i % 3 == 0 then
				put(fold, "Rail" .. i, cf * CFrame.new(r * 0.5, 22, 0), Vector3.new(7, 34, 9), i % 12 == 0)
			end
		end
	end
	plinth(fold, cx, cz, RAD0)
end

--=== 2. 나선판 ===--
-- 판을 한 장씩 돌려 쌓았다. 드릴처럼 꼬인 덩어리가 된다
local function samplePlate(fold, cx, cz)
	local n = math.floor(HEIGHT / 21)
	for i = 0, n do
		local t = i / n
		local br = brAt(t)
		local w = 200 - 132 * t
		local a = i * math.rad(15)
		-- 축에서 조금씩 밀려 나가며 감긴다. 축 위에 그대로 쌓으면 그냥 원뿔이다
		local off = 26 * math.sin(t * math.pi * 2.2)
		local base = CFrame.new(cx + math.cos(a) * off, FOOT + t * HEIGHT, cz + math.sin(a) * off)
			* CFrame.Angles(0, a, 0)
		-- 위쪽은 한 장이 두세 조각으로 쪼개진다
		local pieces = (br > 0.45) and 3 or 1
		for k = 1, pieces do
			if pieces == 1 or rng:NextNumber() > br * 0.6 then
				local sub = (pieces == 1) and CFrame.new() or CFrame.new((k - 2) * w * 0.34, 0, 0)
				put(
					fold,
					string.format("Plate%d_%d", i, k),
					base * sub * lean(br, 26),
					Vector3.new(w / pieces * 0.94, 17, w * 0.78),
					i % 4 == 0 and k == 1
				)
			end
		end
	end
	plinth(fold, cx, cz, 100)
end

--=== 3. 늑골 ===--
-- 굵은 갈빗대 다섯이 꼬여 오르는 빈 새장. 속이 뚫려 있다
local function sampleRib(fold, cx, cz)
	local RIBS = 5
	local RAD0, RAD1 = 128, 44
	local TURNS = 2.4
	local seg = 90
	local pt = {}
	for rb = 1, RIBS do
		pt[rb] = {}
		for i = 0, seg do
			local t = i / seg
			local a = t * TURNS * math.pi * 2 + (rb - 1) / RIBS * math.pi * 2
			local r = RAD0 + (RAD1 - RAD0) * t
			local p = Vector3.new(cx + math.cos(a) * r, FOOT + t * HEIGHT, cz + math.sin(a) * r)
			pt[rb][i] = p
			local br = brAt(t)
			if rng:NextNumber() > br * 0.8 then
				local nx = (i < seg) and 1 or -1
				put(
					fold,
					string.format("Rib%d_%d", rb, i),
					CFrame.new(p) * CFrame.Angles(0, -a, 0) * lean(br, 18),
					Vector3.new(34, 30, HEIGHT / seg * 2.1),
					false
				)
			end
		end
	end
	-- 갈빗대를 서로 묶는 가로대. 없으면 국수 다발로 보인다
	for i = 8, seg - 8, 11 do
		local t = i / seg
		if brAt(t) < 0.5 then
			for rb = 1, RIBS do
				local a, b = pt[rb][i], pt[rb % RIBS + 1][i]
				local mid = (a + b) / 2
				put(
					fold,
					string.format("Tie%d_%d", rb, i),
					CFrame.lookAt(mid, b) * CFrame.Angles(0, 0, 0),
					Vector3.new(11, 11, (b - a).Magnitude),
					i % 33 == 8
				)
			end
		end
	end
	plinth(fold, cx, cz, RAD0)
end

--=== 4. 나선방 ===--
-- 기둥 둘레를 방이 돌며 올라간다. 안에 들어갈 데가 있다
local function sampleRoom(fold, cx, cz)
	local N = 18
	local STEP_A = math.rad(64)
	local SLAB, WALL = 11, 13
	local ny = math.floor(HEIGHT / 18)
	for i = 0, ny do
		local t = i / ny
		local br = brAt(t)
		if rng:NextNumber() > br * 0.7 then
			put(
				fold,
				"Col" .. i,
				CFrame.new(cx, FOOT + t * HEIGHT, cz) * CFrame.Angles(0, i * 0.2, 0) * lean(br, 14),
				Vector3.new(84 - 34 * t, 20, 84 - 34 * t),
				false
			)
		end
	end

	local rm = {}
	for i = 1, N do
		local t = (i - 1) / (N - 1)
		local a = (i - 1) * STEP_A
		local off = 120 - 48 * math.abs(t - 0.45) * 2
		local w, d = 150 - 66 * t, 132 - 58 * t
		local y = FOOT + t * HEIGHT
		local yaw = math.pi / 2 - a
		rm[i] = { a = a, off = off, y = y, w = w, d = d }
		local cf = CFrame.new(cx + math.cos(a) * off, y, cz + math.sin(a) * off) * CFrame.Angles(0, yaw, 0)
		local br = brAt(t)

		put(fold, "F" .. i, cf * CFrame.new(0, SLAB / 2, 0) * lean(br, 20), Vector3.new(w, SLAB, d), false)
		local sides = {
			{ 0, d / 2, w },
			{ 0, -d / 2, w },
			{ w / 2, 0, d },
			{ -w / 2, 0, d },
		}
		for si, sd in ipairs(sides) do
			for s = -1, 1 do
				-- 2번 면이 기둥 쪽이다. 가운데를 비워 길이 지나간다
				local doorway = (si == 2 and s == 0)
				if not doorway and rng:NextNumber() > br then
					local len = sd[3]
					local lx = sd[1] + ((si <= 2) and (s * len / 3) or 0)
					local lz = sd[2] + ((si <= 2) and 0 or (s * len / 3))
					local size = (si <= 2) and Vector3.new(len / 3 * 1.04, 62, WALL)
						or Vector3.new(WALL, 62, len / 3 * 1.04)
					put(
						fold,
						string.format("W%d_%d_%d", i, si, s + 2),
						cf * CFrame.new(lx, 31 + SLAB, lz) * lean(br, 18),
						size,
						si == 2 and s ~= 0 and i % 3 == 0
					)
				end
			end
		end
	end

	-- 방과 방을 잇는 나선 길. 이게 오르는 길이다
	for i = 1, N - 1 do
		local A, B = rm[i], rm[i + 1]
		local st = 9
		for s = 0, st do
			local t = s / st
			local a = A.a + (B.a - A.a) * t
			local r = A.off + (B.off - A.off) * t
			local y = A.y + (B.y - A.y) * t + 6
			local br = brAt((y - FOOT) / HEIGHT)
			if rng:NextNumber() > br * 0.85 then
				put(
					fold,
					string.format("Way%d_%d", i, s),
					CFrame.new(cx + math.cos(a) * r, y, cz + math.sin(a) * r) * CFrame.Angles(0, -a, 0) * lean(br, 16),
					Vector3.new(58, 9, 2 * math.pi * r * (B.a - A.a) / (math.pi * 2) / st * 1.4),
					false
				)
			end
		end
	end
	plinth(fold, cx, cz, 150)
end


--=== 5. 늑골 + 나선계단 ===--
-- 1번과 3번을 겹친 것이다. 갈빗대가 겉을 감싸 덩어리를 만들고
-- 그 안에서 계단이 올라간다.
-- **갈빗대는 계단과 반대로 꼰다.** 같은 방향이면 두 나선이 그냥 포개져 보이고,
-- 반대로 꼬면 서로 교차하면서 격자 무늬가 생긴다. 이게 이 조합의 전부다.
local function sampleCage(fold, cx, cz)
	-- 안쪽 기둥
	local COL_R0, COL_R1 = 48, 24
	local ny = math.floor(HEIGHT / 17)
	for i = 0, ny do
		local t = i / ny
		local br = brAt(t)
		if rng:NextNumber() > br * 0.7 then
			put(
				fold,
				"Col" .. i,
				CFrame.new(cx, FOOT + t * HEIGHT, cz) * CFrame.Angles(0, i * 0.17, 0) * lean(br, 16),
				Vector3.new((COL_R0 + (COL_R1 - COL_R0) * t) * 2, 19, (COL_R0 + (COL_R1 - COL_R0) * t) * 2),
				false
			)
		end
	end

	-- 안쪽 나선계단
	local RAD0, RAD1, TURNS, steps = 146, 64, 3.6, 150
	for i = 0, steps do
		local t = i / steps
		local a = t * TURNS * math.pi * 2
		local r = RAD0 + (RAD1 - RAD0) * t
		local br = brAt(t)
		if rng:NextNumber() > br * 0.85 then
			local cf = CFrame.new(cx + math.cos(a) * r, FOOT + t * HEIGHT, cz + math.sin(a) * r)
				* CFrame.Angles(0, -a, 0)
				* lean(br, 20)
			put(fold, "Step" .. i, cf, Vector3.new(r * 0.95, 10, 2 * math.pi * r / steps * TURNS * 1.35), false)
			if i % 4 == 0 then
				put(fold, "Rail" .. i, cf * CFrame.new(r * 0.48, 22, 0), Vector3.new(7, 34, 9), i % 16 == 0)
			end
		end
	end

	-- 바깥 갈빗대. 계단보다 바깥에 있어야 감싸는 것으로 보인다
	local RIBS, CR0, CR1, CTURNS, seg = 5, 218, 102, -2.2, 90
	local pt = {}
	for rb = 1, RIBS do
		pt[rb] = {}
		for i = 0, seg do
			local t = i / seg
			local a = t * CTURNS * math.pi * 2 + (rb - 1) / RIBS * math.pi * 2
			local r = CR0 + (CR1 - CR0) * t
			pt[rb][i] = Vector3.new(cx + math.cos(a) * r, FOOT + t * HEIGHT, cz + math.sin(a) * r)
			local br = brAt(t)
			if rng:NextNumber() > br * 0.8 then
				put(
					fold,
					string.format("Rib%d_%d", rb, i),
					CFrame.new(pt[rb][i]) * CFrame.Angles(0, -a, 0) * lean(br, 18),
					Vector3.new(32, 28, HEIGHT / seg * 2.1),
					false
				)
			end
		end
	end
	-- 갈빗대끼리 묶는 가로대. 없으면 국수 다발이다
	for i = 8, seg - 8, 11 do
		local t = i / seg
		if brAt(t) < 0.5 then
			for rb = 1, RIBS do
				local a, b = pt[rb][i], pt[rb % RIBS + 1][i]
				put(
					fold,
					string.format("Tie%d_%d", rb, i),
					CFrame.lookAt((a + b) / 2, b),
					Vector3.new(10, 10, (b - a).Magnitude),
					i % 33 == 8
				)
			end
		end
	end
	plinth(fold, cx, cz, CR0)
end

--=== 나란히 세운다 ===--
local SAMPLES = {
	{ "1 나선계단", sampleStair },
	{ "2 나선판", samplePlate },
	{ "3 늑골", sampleRib },
	{ "4 나선방", sampleRoom },
	{ "5 늑골+계단", sampleCage },
}

for i, s in ipairs(SAMPLES) do
	local cx = ORIGIN_X + (i - 1) * GAP
	local cz = ORIGIN_Z
	local fold = Instance.new("Folder")
	fold.Name = "Sample" .. i
	fold.Parent = root
	s[2](fold, cx, cz)
	crown(fold, cx, cz, FOOT + HEIGHT)
	label(fold, cx, cz, s[1])
end

assert(total > 1200, "샘플이 " .. total .. "개뿐이다")
print(string.format("[TowerSamples] 샘플 %d개 / 파트 %d개", #SAMPLES, total))
for i, s in ipairs(SAMPLES) do
	print(string.format("  %s : x=%d z=%d", s[1], ORIGIN_X + (i - 1) * GAP, ORIGIN_Z))
end
