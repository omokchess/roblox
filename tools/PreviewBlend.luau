--!nocheck
--[[
	PreviewBlend.luau — 「신맵 구조도.md」 §5 경계 블렌딩을 미리 본다.

	Studio 커맨드 바에 붙여넣어 실행.

	**Terrain 을 건드리지 않는다.** workspace._RegionGuide.BlendPreview 아래에
	작은 판을 격자로 깔아, 블렌딩된 고도와 재질 경계를 눈으로 확인만 한다.

	되돌리기: workspace._RegionGuide.BlendPreview:Destroy()

	여기 sample() 이 나중에 실제 Terrain 생성에도 그대로 쓰인다.
	미리보기에서 계수를 확정한 뒤 그 함수를 지형 생성기로 옮긴다.
]]

local CELL = 1600
local HALF = CELL * 1.5 -- 맵 반경 2400

-- 표본 간격. 줄이면 재질 경계가 더 곱게 보이지만 파트가 제곱으로 는다.
--   200 → 25×25 = 625판 / 150 → 33×33 = 1089판 / 120 → 41×41 = 1681판
local STEP = 200

-- 재질 경계를 얼마나 흐트릴지. §5 의 손잡이.
--   0 이면 자로 그은 직선, 크게 하면 두 재질이 얼룩덜룩 물린다.
local MAT_JITTER = 0.35
local MAT_FREQ = 0.02

-- 셀 파라미터 — §5 표와 같아야 한다. {기준고도, 기복, 색, 이름}
local CELLS = {
	["0,0"] = { 90, 30, Color3.fromRGB(214, 178, 88), "탑의성역" },
	["0,1"] = { 30, 30, Color3.fromRGB(126, 186, 96), "평원" },
	["-1,0"] = { 110, 70, Color3.fromRGB(46, 104, 62), "숲" },
	["-1,1"] = { 40, 40, Color3.fromRGB(120, 74, 148), "오염지대" },
	["1,1"] = { 10, 30, Color3.fromRGB(74, 96, 70), "늪지대" },
	["1,0"] = { 70, 50, Color3.fromRGB(214, 186, 126), "사막" },
	["0,-1"] = { 380, 140, Color3.fromRGB(168, 68, 44), "화산" },
	["-1,-1"] = { 340, 140, Color3.fromRGB(226, 234, 240), "설원" },
	["1,-1"] = { 210, 90, Color3.fromRGB(96, 92, 88), "광산" },
}

local function cellAt(i, j)
	-- 바깥 셀 너머는 가장자리 셀 값을 그대로 쓴다 (가이아의 외벽 안쪽 여백)
	i = math.clamp(i, -1, 1)
	j = math.clamp(j, -1, 1)
	return CELLS[i .. "," .. j], i, j
end

local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 맵 전체에 단 하나인 노이즈. 셀마다 다른 노이즈를 쓰면 경계에서 무늬가 끊긴다.
local function fbm(x, z)
	local n, a, f = 0, 1, 1 / 900
	for _ = 1, 3 do
		n += math.noise(x * f, z * f, 7.3) * a
		a *= 0.5
		f *= 2.1
	end
	return n / 0.875 -- 대략 -1 ~ 1
end

--[[
	(x, z) 한 점의 고도와 지역을 돌려준다. §5 의 구현 그 자체다.
	returns height, color, regionName
]]
local function sample(x, z)
	local gx, gz = x / CELL, z / CELL
	local i0 = math.clamp(math.floor(gx), -1, 0)
	local j0 = math.clamp(math.floor(gz), -1, 0)
	local sx = smoothstep(gx - i0)
	local sz = smoothstep(gz - j0)

	local corners = {
		{ cellAt(i0, j0) },
		{ cellAt(i0 + 1, j0) },
		{ cellAt(i0, j0 + 1) },
		{ cellAt(i0 + 1, j0 + 1) },
	}
	local w = {
		(1 - sx) * (1 - sz),
		sx * (1 - sz),
		(1 - sx) * sz,
		sx * sz,
	}

	-- 고도는 파라미터를 섞고 노이즈는 한 번만 평가한다
	local base, amp = 0, 0
	for k = 1, 4 do
		base += corners[k][1][1] * w[k]
		amp += corners[k][1][2] * w[k]
	end
	local h = base + amp * fbm(x, z)

	-- 재질은 가중치에 노이즈를 태운 argmax. 이래야 직선 경계가 안 생긴다.
	local best, bestW
	for k = 1, 4 do
		local c, ci, cj = corners[k][1], corners[k][2], corners[k][3]
		local jw = w[k] + math.noise(x * MAT_FREQ, z * MAT_FREQ, ci * 7.7 + cj * 13.3) * MAT_JITTER
		if not bestW or jw > bestW then
			best, bestW = c, jw
		end
	end

	return h, best[3], best[4]
end

--=== 그리기 ===--

local guide = workspace:FindFirstChild("_RegionGuide")
if not guide then
	guide = Instance.new("Folder")
	guide.Name = "_RegionGuide"
	guide.Parent = workspace
end

local preview = guide:FindFirstChild("BlendPreview")
if preview then
	preview:ClearAllChildren()
else
	preview = Instance.new("Folder")
	preview.Name = "BlendPreview"
	preview.Parent = guide
end

local n, lowest, highest = 0, math.huge, -math.huge
local counts = {}

for x = -HALF, HALF, STEP do
	for z = -HALF, HALF, STEP do
		local h, color, name = sample(x, z)
		lowest = math.min(lowest, h)
		highest = math.max(highest, h)
		counts[name] = (counts[name] or 0) + 1

		local p = Instance.new("Part")
		p.Name = string.format("B_%d_%d", x, z)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Locked = true, false, false, false, true
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(STEP, 4, STEP)
		p.Position = Vector3.new(x, h, z)
		p.Color = color
		p.Parent = preview
		n += 1
	end
end

local parts = {}
for name, c in pairs(counts) do
	table.insert(parts, string.format("%s %d", name, c))
end
table.sort(parts)

print(
	string.format(
		"[PreviewBlend] 표본 %d판 / 간격 %d / 고도 %d ~ %d / MAT_JITTER %.2f — 되돌리기: workspace._RegionGuide.BlendPreview:Destroy()",
		n,
		STEP,
		math.floor(lowest),
		math.floor(highest),
		MAT_JITTER
	)
)
print("  지역별 표본: " .. table.concat(parts, ", "))
