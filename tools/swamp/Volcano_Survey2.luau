--!nocheck
-- 화산섬 실측 2: 40 간격 높이 지도(지반만), 섬 안의 Mountains 파트, 지반 판 크기 분포. 보고: /volcano_survey2
local HS = game:GetService("HttpService")
local S = workspace.Surface
local G = S.World:FindFirstChild("G_화산")
local out = {}
local function p(...)
	out[#out + 1] = string.format(...)
end
local X0, X1, Z0, Z1 = -2076, -436, -3723, -2037

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }
local STEP = 40
local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
p("STEP %d (x %d→, z %d↓) 글자=높이/5 (0..Z=0..175)", STEP, X0, Z0)
local header = {}
for x = X0 + 7, X1, STEP do
	header[#header + 1] = tostring(math.floor(((x - X0) / STEP) % 10))
end
p("       %s", table.concat(header))
for z = Z0 + 7, Z1, STEP do
	local row = {}
	for x = X0 + 7, X1, STEP do
		local r = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -3000, 0), rp)
		local ch = "."
		if r then
			local h = math.floor(r.Position.Y / 5)
			local i = math.clamp(h + 1, 1, #chars)
			ch = chars:sub(i, i)
			if r.Instance.Material == Enum.Material.CrackedLava then
				ch = ch:lower()
			end
		end
		row[#row + 1] = ch
	end
	p("%6d %s", z, table.concat(row))
end

-- 판 크기
local sizes = {}
for _, d in ipairs(G:GetDescendants()) do
	if d:IsA("BasePart") then
		local k = string.format("%.0fx%.0fx%.0f", d.Size.X, d.Size.Y, d.Size.Z)
		sizes[k] = (sizes[k] or 0) + 1
	end
end
local sl = {}
for k, v in pairs(sizes) do
	sl[#sl + 1] = { k, v }
end
table.sort(sl, function(a, b)
	return a[2] > b[2]
end)
for i = 1, math.min(6, #sl) do
	p("판 %s ×%d", sl[i][1], sl[i][2])
end
local sample = G:GetChildren()[1]
p("G 자식 예: %s (%s) 자식 %d", sample.Name, sample.ClassName, #sample:GetChildren())

-- 섬 안의 Mountains 파트
local cnt, a, b = 0, Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
local names = {}
for _, d in ipairs(S.Mountains:GetDescendants()) do
	if d:IsA("BasePart") and d.Position.X > X0 and d.Position.X < X1 and d.Position.Z > Z0 and d.Position.Z < Z1 then
		cnt += 1
		a = Vector3.new(math.min(a.X, d.Position.X), math.min(a.Y, d.Position.Y), math.min(a.Z, d.Position.Z))
		b = Vector3.new(math.max(b.X, d.Position.X), math.max(b.Y, d.Position.Y), math.max(b.Z, d.Position.Z))
		local top = d.Parent and d.Parent.Name or "?"
		names[top] = (names[top] or 0) + 1
	end
end
p("섬 안 Mountains 파트 %d  x %.0f..%.0f y %.0f..%.0f z %.0f..%.0f", cnt, a.X, b.X, a.Y, b.Y, a.Z, b.Z)
for k, v in pairs(names) do
	p("  부모 %s ×%d", k, v)
end
local wc = {}
for _, c in ipairs(S.World:GetChildren()) do
	wc[#wc + 1] = c.Name
end
p("World 자식: %s", table.concat(wc, ", "))
local sc = {}
for _, c in ipairs(S:GetChildren()) do
	sc[#sc + 1] = c.Name
end
p("Surface 자식: %s", table.concat(sc, ", "))
HS:PostAsync("http://127.0.0.1:34999/volcano_survey2", table.concat(out, "\n"))
