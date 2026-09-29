--!nocheck
--[[
	ScaleMarker.luau — 사람 크기와 높이 눈금을 세운다.

	블록으로만 지으면 화면에서 크기 감각이 완전히 사라진다.
	탑이 큰 건지 작은 건지, 방 하나에 사람이 들어가는지가 안 보인다.
	그래서 **실제 캐릭터 치수의 블록**을 옆에 세워 기준으로 삼는다.

	로블록스 기본 캐릭터는 키 5, 어깨 너비 4, 두께 2 다.
	R15 도 서 있을 때 머리끝까지 약 5 다. 이 블록이 곧 사람 한 명이다.

	눈금 기둥은 100 마다 띠를 두르고 500 마다 네온으로 바꾼다.
	띠 하나가 사람 스무 명이다.

	MARKS 에 적힌 자리에만 선다. 지반이 있으면 그 위에, 없으면 적어둔 y 에 선다.

	되돌리기: workspace.Surface.ScaleMarks:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local PH, PW, PD = 5, 4, 2 -- 캐릭터 키, 너비, 두께
local RULER = 1300 -- 눈금 기둥 높이
local BAND = 100 -- 띠 간격

-- y 는 지반이 없을 때 쓸 높이다. 탑 샘플은 바다 위 30 에서 시작한다
local MARKS = {
	{ name = "샘플1", x = -600, z = -6880, y = 30, ruler = true },
	{ name = "샘플2", x = 300, z = -6880, y = 30, ruler = true },
	{ name = "샘플3", x = 1200, z = -6880, y = 30, ruler = true },
	{ name = "샘플4", x = 2100, z = -6880, y = 30, ruler = true },
	{ name = "샘플5", x = 3000, z = -6880, y = 30, ruler = true },
	{ name = "거목", x = -4500, z = 1600, y = 250, ruler = false },
	{ name = "절화", x = 0, z = 1600, y = 10, ruler = false },
}

local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World }

local old = S:FindFirstChild("ScaleMarks")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "ScaleMarks"
root.Parent = S

local n = 0
local function put(fold, name, cf, size, color, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = neon and M.Neon or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fold
	n += 1
	return p
end

for _, m in ipairs(MARKS) do
	local hit = workspace:Raycast(Vector3.new(m.x, 2000, m.z), Vector3.new(0, -3000, 0), rp)
	local y = hit and hit.Position.Y or m.y

	local fold = Instance.new("Folder")
	fold.Name = "Mark_" .. m.name
	fold.Parent = root

	-- 사람 한 명. 이게 전부 기준이다
	put(
		fold,
		"사람_키5",
		CFrame.new(m.x, y + PH / 2, m.z),
		Vector3.new(PW, PH, PD),
		RGB(255, 96, 48),
		true
	)
	-- 발밑 원판. 사람 블록이 작아서 멀리서는 안 보인다
	put(fold, "발판", CFrame.new(m.x, y + 0.5, m.z), Vector3.new(14, 1, 14), RGB(255, 96, 48), true)

	local g = Instance.new("BillboardGui")
	g.Size = UDim2.new(0, 170, 0, 44)
	g.StudsOffset = Vector3.new(0, 8, 0)
	g.AlwaysOnTop = true
	g.Parent = fold["사람_키5"]
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.TextColor3 = RGB(255, 170, 130)
	t.TextStrokeTransparency = 0
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = "사람 (키 5)"
	t.Parent = g

	if m.ruler then
		local rx = m.x + 46
		put(fold, "눈금기둥", CFrame.new(rx, y + RULER / 2, m.z), Vector3.new(5, RULER, 5), RGB(250, 250, 250), false)
		for h = BAND, RULER, BAND do
			local big = (h % 500 == 0)
			put(
				fold,
				"눈금_" .. h,
				CFrame.new(rx, y + h, m.z),
				Vector3.new(big and 44 or 26, big and 5 or 3, big and 44 or 26),
				big and RGB(120, 220, 255) or RGB(240, 240, 240),
				big
			)
			if big then
				local bg = Instance.new("BillboardGui")
				bg.Size = UDim2.new(0, 130, 0, 36)
				bg.StudsOffset = Vector3.new(0, 6, 0)
				bg.AlwaysOnTop = true
				bg.Parent = fold["눈금_" .. h]
				local bt = Instance.new("TextLabel")
				bt.Size = UDim2.new(1, 0, 1, 0)
				bt.BackgroundTransparency = 1
				bt.TextColor3 = RGB(150, 230, 255)
				bt.TextStrokeTransparency = 0
				bt.TextScaled = true
				bt.Font = Enum.Font.GothamBold
				bt.Text = tostring(h)
				bt.Parent = bg
			end
		end
	end
end

assert(n > 20, "표시가 " .. n .. "개뿐이다")
print(string.format("[ScaleMarker] %d자리 / 파트 %d개 / 사람 = %dx%dx%d", #MARKS, n, PW, PH, PD))
