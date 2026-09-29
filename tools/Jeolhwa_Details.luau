--!nocheck
--[[
	Jeolhwa_Details.luau — 2026-09-27. 절화 3판이 기본 도형으로 놓은 바깥 꾸밈을 블렌더 소품으로 바꾼다.

	품계석   돌/<행각 마당>/Pumgye_k_s  → Pumgye. 글(正一品 .. 從三品)은 어도 쪽 앞면에 SurfaceGui 로 새긴다
	다리 난간 돌/다리_i/Rail_s          → Bridge_Rail_<길이>
	논밭 이랑 논밭/i/Row_k              → Crop_* 토막(길이 10)을 이랑 길이에 맞게 조금 늘여 잇는다. 밭마다 심을 것은 FIELDS 표
	궁 마당 의장기                      → COURT 표(월드 x, z)대로 궁/마당의장 에 세운다(바닥으로 광선을 쏴 앉힘)
	옛 파트는 지우지 않고 숨겨 자리표로 남긴다(안 보이고, 안 부딪히고, 광선도 안 맞는다).
	다시 돌리면 전에 놓은 것(속성 Detail)을 지우고 자리표에서 새로 놓는다. 절화를 Jeolhwa_City3 로 다시 지으면 다시 돌릴 것.
	소품 틀은 ServerStorage.JeolhwaProps (models/build_hanok_props.py → tools/Jeolhwa_Props.luau).
]]

local SS = game:GetService("ServerStorage")
local props = assert(SS:FindFirstChild("JeolhwaProps"), "ServerStorage.JeolhwaProps 가 없다")
local root = assert(workspace:FindFirstChild("Jeolhwa"), "Workspace.Jeolhwa 가 없다")

-- 밭 번호(jeolhwa_plan.py FIELDS 순서) → { {이 이랑부터, 작물}, ... }
local FIELDS = {
	[1] = { { 1, "Barley" }, { 13, "Cabbage" } },
	[2] = { { 1, "Cabbage" }, { 11, "Radish" } },
	[3] = { { 1, "Barley" } },
	[4] = { { 1, "Radish" }, { 9, "Pepper" } },
	[5] = { { 1, "Bean" } },
	[6] = { { 1, "Pepper" } },
	[7] = { { 1, "Barley" } },
	[8] = { { 1, "Bean" }, { 12, "Barley" } },
	[9] = { { 1, "Cabbage" } },
	[10] = { { 1, "Pepper" }, { 6, "Bean" } },
	[11] = { { 1, "Radish" } },
	[12] = { { 1, "Cabbage" } },
	[13] = { { 1, "Barley" } },
	[14] = { { 1, "Bean" } },
	[15] = { { 1, "Pepper" }, { 6, "Radish" } },
}
-- 행각 마당 k = 5 가 정전 쪽(북)이다
local RANKS = { [5] = "正一品", [4] = "從一品", [3] = "正二品", [2] = "從二品", [1] = "正三品", [0] = "從三品" }
local SEG = 10 -- Crop_* 토막 길이
-- 정전 앞 마당(행각 안쪽 x 148.5..301.5, 중문 z 720 ~ 정전 계단 z 762). 행각을 따라 셋씩, 깃이 마당 쪽으로 펴지게
-- (깃은 장대의 -X 쪽이라 서쪽 줄은 돌려 세운다). 서쪽 백호, 동쪽 청룡
local COURT = {
	{ "Uijang_GiWhite", 154, 728, 180 },
	{ "Uijang_GiRed", 154, 744, 180 },
	{ "Uijang_GiYellow", 154, 760, 180 },
	{ "Uijang_GiBlue", 296, 728, 0 },
	{ "Uijang_GiRed", 296, 744, 0 },
	{ "Uijang_GiYellow", 296, 760, 0 },
}

local function template(name)
	return assert(props:FindFirstChild(name), "소품 틀이 없다: " .. name)
end

local function hide(p)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function put(src, cf, name, parent)
	local c = src:Clone()
	c.Name = name
	c:PivotTo(cf)
	c:SetAttribute("Detail", true)
	c.Parent = parent
	return c
end

-- 틀의 피벗은 원점이다. 앞뒤(Z)로만 s 배 늘인다
local function stretchZ(m, s)
	for _, q in ipairs(m:GetDescendants()) do
		if q:IsA("BasePart") then
			local c, sz = q.CFrame, q.Size
			if math.abs(c.RightVector.Z) > 0.99 then
				sz = Vector3.new(sz.X * s, sz.Y, sz.Z)
			elseif math.abs(c.UpVector.Z) > 0.99 then
				sz = Vector3.new(sz.X, sz.Y * s, sz.Z)
			else
				assert(math.abs(c.LookVector.Z) > 0.99, "틀 파트가 비스듬하다: " .. q:GetFullName())
				sz = Vector3.new(sz.X, sz.Y, sz.Z * s)
			end
			q.Size = sz
			q.CFrame = c - c.Position + Vector3.new(c.X, c.Y, c.Z * s)
		end
	end
end

local function vertical(text)
	local out = {}
	for _, cp in utf8.codes(text) do
		out[#out + 1] = utf8.char(cp)
	end
	return table.concat(out, "\n")
end

-- 전에 놓은 것 치우기
local n0 = 0
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("Detail") and m.Parent then
		m:Destroy()
		n0 += 1
	end
end

local count, report = {}, {}
local function add(k)
	count[k] = (count[k] or 0) + 1
end

for _, p in ipairs(root:GetDescendants()) do
	if not (p:IsA("Part") and p.Parent) then
		continue
	end
	local bottom = p.Position - Vector3.new(0, p.Size.Y / 2, 0)

	local k, sx = p.Name:match("^Pumgye_(%d+)_(%-?%d+)$")
	if k then
		k, sx = tonumber(k), tonumber(sx)
		-- 앞(-Z)이 어도(x 225)를 보게. 서쪽 줄(sx -1)은 +X 를 본다
		local cf = CFrame.new(bottom) * CFrame.Angles(0, math.rad(sx < 0 and -90 or 90), 0)
		local m = put(template("Pumgye"), cf, p.Name, p.Parent)
		local lab = Instance.new("Part")
		lab.Name = "Pumgye_Text"
		lab.Anchored = true
		lab.Size = Vector3.new(0.72, 1.2, 0.02)
		lab.CFrame = cf * CFrame.new(0, 1.15, -0.322) -- 몸 앞면 -0.31, 테 앞면 -0.34 사이
		hide(lab)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 100
		sg.LightInfluence = 1
		sg.Parent = lab
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = vertical(assert(RANKS[k], "품계 없음 " .. k))
		t.TextScaled = true
		t.Font = Enum.Font.SourceSansBold
		t.TextColor3 = Color3.fromRGB(92, 88, 78)
		t.Parent = sg
		lab.Parent = m
		hide(p)
		add("Pumgye")
		continue
	end

	if p.Name:match("^Rail_%-?%d$") and p.Parent.Name:match("^다리_") then
		local L = math.max(p.Size.X, p.Size.Z)
		local alongX = p.Size.X > p.Size.Z
		local name = "Bridge_Rail_" .. math.floor(L + 0.5)
		local cf = CFrame.new(bottom) * (alongX and CFrame.Angles(0, math.rad(90), 0) or CFrame.new())
		put(template(name), cf, p.Name, p.Parent)
		hide(p)
		add(name)
		continue
	end

	local r = p.Name:match("^Row_(%d+)$")
	if r and p.Parent.Parent and p.Parent.Parent.Name == "논밭" then
		r = tonumber(r)
		local plan = assert(FIELDS[tonumber(p.Parent.Name)], "밭 표에 없다: " .. p.Parent.Name)
		local crop
		for _, e in ipairs(plan) do
			if r >= e[1] then
				crop = e[2]
			end
		end
		local src = template("Crop_" .. crop)
		assert(p.Size.Z > p.Size.X, "이랑이 앞뒤(Z)로 눕지 않았다: " .. p:GetFullName())
		local L = p.Size.Z
		local n = math.max(1, math.floor(L / SEG + 0.5))
		local seg = L / n
		for j = 1, n do
			local c = src:Clone()
			stretchZ(c, seg / SEG)
			-- 같은 토막이 줄지어 보이지 않게 엇갈려 돌려 놓는다
			local flip = (r + j) % 2 == 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new()
			c:PivotTo(CFrame.new(bottom.X, bottom.Y, p.Position.Z - L / 2 + seg * (j - 0.5)) * flip)
			c.Name = string.format("Crop_%d_%d", r, j)
			c:SetAttribute("Detail", true)
			c.Parent = p.Parent
			add("Crop_" .. crop)
		end
		hide(p)
	end
end

local court = root["궁"]:FindFirstChild("마당의장")
if not court then
	court = Instance.new("Folder")
	court.Name = "마당의장"
	court.Parent = root["궁"]
end
local rpDown = RaycastParams.new()
rpDown.FilterType = Enum.RaycastFilterType.Exclude
rpDown.FilterDescendantsInstances = { court, root:FindFirstChild("안살림") }
for i, e in ipairs(COURT) do
	local h = assert(workspace:Raycast(Vector3.new(e[2], 60, e[3]), Vector3.new(0, -100, 0), rpDown), "마당 깃 밑에 바닥이 없다 " .. i)
	put(template(e[1]), CFrame.new(e[2], h.Position.Y, e[3]) * CFrame.Angles(0, math.rad(e[4]), 0), e[1] .. "_" .. i, court)
	add("궁 마당 " .. e[1])
end

report[#report + 1] = string.format("치운 옛 소품 %d", n0)
local keys = {}
for k in pairs(count) do
	keys[#keys + 1] = k
end
table.sort(keys)
for _, k in ipairs(keys) do
	report[#report + 1] = string.format("%s %d", k, count[k])
end
local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/details", table.concat(report, "\n"))
end)
print("details", table.concat(report, ", "))
