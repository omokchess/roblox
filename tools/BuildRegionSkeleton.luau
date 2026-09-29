--!nocheck
-- 신맵 지역 골격 생성 — Studio 커맨드 바에 붙여넣어 실행.
-- 설계 근거는 「신맵 구조도.md」. 지형·건축은 만들지 않고 폴더와 시각 가이드만 만든다.
-- 멱등: 여러 번 실행해도 중복 생성 안 됨. 되돌리기: Workspace._RegionGuide:Destroy()
-- WipeMap 이 남긴 Surface/R_설원/Flora 는 그대로 재사용한다.

local CELL = 1600 -- 셀 한 변
local PAD = 1590 -- 가이드 판 크기 (10 띄워 경계선이 보이게)
local DEPTHS_Y = -640 -- 지저 기준면
local CYL_R = 2400 -- 프로푼디스 원통 반지름 (4800 정사각형에 내접)

local GATE_W, GATE_L, GATE_H = 120, 200, 24 -- 회랑 폭·길이·표식 높이

-- 관문 12개. {표시, x, z, 권장Lv, 봉인}
-- 격자 12변 중 8변만 뚫는다. 탑 사방 4변은 6신 격파 수만큼 열린다.
local GATES = {
	{ "1 평원-늪지대", 800, 1600, 10, false },
	{ "2 늪지대-사막", 1600, 800, 20, false },
	{ "3 사막-광산", 1600, -800, 30, false },
	{ "4 광산-화산", 800, -1600, 45, false },
	{ "5 화산-설원", -800, -1600, 55, false },
	{ "6 설원-숲", -1600, -800, 40, false },
	{ "7 숲-오염지대", -1600, 800, 25, false },
	{ "8 오염지대-평원", -800, 1600, 25, false },
	{ "봉인 탑-평원", 0, 800, 60, true },
	{ "봉인 탑-사막", 800, 0, 60, true },
	{ "봉인 탑-화산", 0, -800, 60, true },
	{ "봉인 탑-숲", -800, 0, 60, true },
}

-- {이름, i(동+), j(남+), 색, 지저에도 있는가}
local REGIONS = {
	{ "탑의성역", 0, 0, Color3.fromRGB(214, 178, 88), true },
	{ "평원", 0, 1, Color3.fromRGB(126, 186, 96), true },
	{ "숲", -1, 0, Color3.fromRGB(46, 104, 62), true },
	{ "오염지대", -1, 1, Color3.fromRGB(120, 74, 148), true },
	{ "늪지대", 1, 1, Color3.fromRGB(74, 96, 70), true },
	{ "사막", 1, 0, Color3.fromRGB(214, 186, 126), true },
	{ "화산", 0, -1, Color3.fromRGB(168, 68, 44), true },
	{ "설원", -1, -1, Color3.fromRGB(226, 234, 240), true },
	{ "광산", 1, -1, Color3.fromRGB(96, 92, 88), false }, -- 원통 밖 = 지저 없음(암반)
}

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Size 는 스터드 단위(Scale)로 준다. fromOffset 은 픽셀 고정이라 멀리서 봐도 안 작아진다.
local function label(part, text, studs)
	local gui = part:FindFirstChildOfClass("BillboardGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Parent = part
	end
	local w = studs or 560
	gui.Size = UDim2.fromScale(w, w / 4.7)
	gui.StudsOffset = Vector3.new(0, 90, 0)
	gui.AlwaysOnTop = true
	local t = gui:FindFirstChildOfClass("TextLabel")
	if not t then
		t = Instance.new("TextLabel")
		t.Parent = gui
	end
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
end

local function pad(parent, name, pos, color, text)
	local p = parent:FindFirstChild(name)
	if not p then
		p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Locked = true
	p.Material = Enum.Material.SmoothPlastic
	p.Size = Vector3.new(PAD, 4, PAD)
	p.Position = pos
	p.Color = color
	p.Transparency = 0.7
	label(p, text)
	return p
end

local surface = folder(workspace, "Surface")
local depths = folder(workspace, "Depths")
local guide = folder(workspace, "_RegionGuide")
local gSurf = folder(guide, "SurfacePads")
local gDeep = folder(guide, "DepthsPads")

local nSurf, nDeep = 0, 0
for _, r in ipairs(REGIONS) do
	local name, i, j, color, hasDepths = r[1], r[2], r[3], r[4], r[5]
	local x, z = i * CELL, j * CELL

	folder(surface, "R_" .. name)
	-- 판 두께 4. 상단을 지상 기준면 Y=0 에 맞춰 나무 밑동과 겹치지 않게 한다
	pad(gSurf, "Pad_" .. name, Vector3.new(x, -2, z), color, string.format("%s  (%d,%d)", name, i, j))
	nSurf += 1

	if hasDepths then
		folder(depths, "D_" .. name)
		pad(
			gDeep,
			"DPad_" .. name,
			Vector3.new(x, DEPTHS_Y, z),
			color:Lerp(Color3.new(0, 0, 0), 0.55),
			string.format("D_%s  Y%d", name, DEPTHS_Y)
		)
		nDeep += 1
	end
end

-- 프로푼디스 원통 외곽선. 이 원 밖은 암반이라 벽 파트가 필요 없다.
local cyl = guide:FindFirstChild("ProfundisRim")
if not cyl then
	cyl = Instance.new("Part")
	cyl.Name = "ProfundisRim"
	cyl.Parent = guide
end
cyl.Shape = Enum.PartType.Cylinder
cyl.Anchored, cyl.CanCollide, cyl.CanTouch, cyl.CanQuery, cyl.Locked = true, false, false, false, true
cyl.Material = Enum.Material.Neon
cyl.Color = Color3.fromRGB(150, 90, 200)
cyl.Transparency = 0.85
cyl.Size = Vector3.new(6, CYL_R * 2, CYL_R * 2)
cyl.CFrame = CFrame.new(0, DEPTHS_Y, 0) * CFrame.Angles(0, 0, math.rad(90))

-- 관문 회랑 표식. 셀 경계 위에 눕혀 폭 120 회랑이 어디를 지나는지 보여준다.
local gGate = folder(guide, "Gates")
for _, g in ipairs(GATES) do
	local text, x, z, lv, sealed = g[1], g[2], g[3], g[4], g[5]
	local alongX = math.abs(x) == 800 -- 경계면이 x = ±800 이면 회랑은 X축을 따라 뚫린다
	local p = gGate:FindFirstChild("Gate_" .. text)
	if not p then
		p = Instance.new("Part")
		p.Name = "Gate_" .. text
		p.Parent = gGate
	end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Locked = true, false, false, false, true
	p.Material = Enum.Material.Neon
	p.Transparency = 0.45
	p.Color = sealed and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(90, 200, 130)
	p.Size = alongX and Vector3.new(GATE_L, GATE_H, GATE_W) or Vector3.new(GATE_W, GATE_H, GATE_L)
	p.Position = Vector3.new(x, GATE_H / 2, z)
	label(p, string.format("%s Lv%d", text, lv), 260)
end

-- 심연 구멍 표식. 오염지대 셀 중심 — 폐기물이 여기서 올라와 오염지대가 됐다.
local mouth = guide:FindFirstChild("AbyssMouth")
if not mouth then
	mouth = Instance.new("Part")
	mouth.Name = "AbyssMouth"
	mouth.Parent = guide
end
mouth.Shape = Enum.PartType.Cylinder
mouth.Anchored, mouth.CanCollide, mouth.CanTouch, mouth.CanQuery, mouth.Locked = true, false, false, false, true
mouth.Material = Enum.Material.Neon
mouth.Color = Color3.fromRGB(180, 60, 220)
mouth.Transparency = 0.6
mouth.Size = Vector3.new(680, 300, 300) -- 지상 0 → 지저 천장 아래까지 관통, 지름 300
mouth.CFrame = CFrame.new(-1600, -320, 1600) * CFrame.Angles(0, 0, math.rad(90))
label(mouth, "심연 구멍 (유일)", 300)

print(
	string.format(
		"[RegionSkeleton] 지상 %d · 지저 %d 존 / 관문 %d(봉인 4) / 셀 %d / 원통 R=%d / 지저기준 Y=%d "
			.. "— 가이드 삭제: workspace._RegionGuide:Destroy()",
		nSurf,
		nDeep,
		#GATES,
		CELL,
		CYL_R,
		DEPTHS_Y
	)
)
