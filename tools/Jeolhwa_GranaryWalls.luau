--!nocheck
--[[
	Jeolhwa_GranaryWalls.luau — 2026-09-27. 곳간 판자벽 충돌을 벽 조각으로 나눈다.

	곳간(Granary)의 판자벽은 네 벽이 한 메시(Gran_Lattice)라 정밀 분해 충돌이 앞문 구멍까지 메웠다
	(Jeolhwa_GateProbe 로 확인). 메시 충돌은 끄고, 보이지 않는 충돌 벽 다섯(앞 둘은 문 양옆, 뒤, 양옆)을 세운다.
	곳간 로컬 치수(블렌더 0.5 배): 벽 가운데 x ±12, z ±7, 두께 0.9, 마루 2.7 부터 벽 높이 7.5. 문 폭 ±2.9.
	놓인 곳간과 ServerStorage 의 틀 모두. 다시 돌려도 벽을 겹쳐 세우지 않는다.
	끝에 곳간 한 채의 대문 쪽 땅 높이도 잰다(북촌 대문 하나가 땅에 묻혀 막힌 까닭을 보려고).
]]

local WALLS = {
	-- { x, z, 폭(x), 깊이(z) }
	{ -7.45, -7, 9.1, 0.9 },
	{ 7.45, -7, 9.1, 0.9 },
	{ 0, 7, 24.9, 0.9 },
	{ -12, 0, 0.9, 14.9 },
	{ 12, 0, 0.9, 14.9 },
}
local Y0, H = 2.5, 7.9

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local nG, nW = 0, 0
local function fix(root)
	for _, m in ipairs(root:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Granary" and not m:FindFirstChild("Collider_Wall") then
			nG += 1
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p.Name:match("_Lattice$") then
					p.CanCollide = false
				end
			end
			local pv = m:GetPivot()
			for _, w in ipairs(WALLS) do
				local c = Instance.new("Part")
				c.Name = "Collider_Wall"
				c.Anchored, c.Transparency, c.CanCollide, c.CastShadow = true, 1, true, false
				c.Size = Vector3.new(w[3], H, w[4])
				c.CFrame = pv * CFrame.new(w[1], Y0 + H / 2, w[2])
				c.Parent = m
				nW += 1
			end
		end
	end
end
fix(workspace:FindFirstChild("Jeolhwa"))
fix(game:GetService("ServerStorage"))
say("곳간 %d 채, 충돌 벽 %d", nG, nW)

-- 북촌 대문(-21, 614) 둘레 땅
for _, m in ipairs(workspace.Jeolhwa:GetDescendants()) do
	if m:IsA("Model") and m.Name == "Wall_GateTile" and (m:GetPivot().Position - Vector3.new(-21, 2, 614)).Magnitude < 3 then
		local pv = m:GetPivot()
		say("대문 피벗 %s yaw %.0f", tostring(pv.Position), math.deg(select(2, pv:ToEulerAnglesYXZ())))
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Surface }
		for _, z in ipairs({ -6, -4, -2, -1, 0, 1, 2, 4, 6 }) do
			local line = {}
			for _, x in ipairs({ -4, -2, 0, 2, 4 }) do
				local o = pv:PointToWorldSpace(Vector3.new(x, 30, z))
				local h = workspace:Raycast(o, Vector3.new(0, -60, 0), rp)
				line[#line + 1] = h and string.format("%5.2f", h.Position.Y - pv.Y) or "  -  "
			end
			say("z %3d: %s", z, table.concat(line, " "))
		end
		local g = workspace.Surface:FindFirstChild("Gs_평원_1_1705", true)
		if g then
			say("땅 조각 %s 크기 %s 위치 %s", g:GetFullName(), tostring(g.Size), tostring(g.Position))
		end
	end
end

local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/granary", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("granary", #report)
