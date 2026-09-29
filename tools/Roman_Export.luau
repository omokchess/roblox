--!nocheck
-- 칼로도르 폴리스 + 화산섬 지반을 블렌더 미리보기(tools/roman_preview.py)용 글로 내보낸다. 보고: /rexp_<n>
-- G 줄 = 지반 파트, P 줄 = 도시의 기본 파트(용암·길·광장·사슬…), K 줄 = 틀 모델 피벗(블렌더가 틀을 다시 빚는다).
-- 틀 안의 기단(Foundation)은 P 줄로 낸다
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local kit = SS.RomanKit
local city = workspace.Surface["Roman_칼로도르"]
local G = workspace.Surface.World["G_화산"]
local lines = {}
local function f(v)
	return string.format("%.3f", v)
end
local function cfs(cf)
	local t = { cf:GetComponents() }
	for i = 1, #t do
		t[i] = f(t[i])
	end
	return table.concat(t, " ")
end
local function prim(tag, p)
	if p.Transparency >= 1 then
		return
	end
	local shape = p:IsA("Part") and p.Shape.Name or ""
	local c = p.Color
	lines[#lines + 1] = table.concat({ tag, p.ClassName, shape, cfs(p.CFrame), f(p.Size.X) .. " " .. f(p.Size.Y) .. " " .. f(p.Size.Z),
		string.format("%d %d %d", c.R * 255, c.G * 255, c.B * 255), p.Material.Name, f(p.Transparency) }, "\t")
end
for _, p in ipairs(G:GetDescendants()) do
	if p:IsA("BasePart") then
		prim("G", p)
	end
end
local function walk(inst)
	for _, c in ipairs(inst:GetChildren()) do
		if c:IsA("Model") and kit:FindFirstChild(c.Name) then
			lines[#lines + 1] = table.concat({ "K", c.Name, cfs(c:GetPivot()) }, "\t")
			for _, q in ipairs(c:GetChildren()) do
				if q:IsA("BasePart") and q.Name == "Foundation" then
					prim("P", q)
				end
			end
		elseif c:IsA("BasePart") then
			prim("P", c)
			walk(c)
		else
			walk(c)
		end
	end
end
walk(city)
local n = 0
for i = 1, #lines, 1500 do
	HS:PostAsync("http://127.0.0.1:34999/rexp_" .. n, table.concat(lines, "\n", i, math.min(#lines, i + 1499)))
	n += 1
end
HS:PostAsync("http://127.0.0.1:34999/rexp_done", tostring(#lines) .. " " .. n)
