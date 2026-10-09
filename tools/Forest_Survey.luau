--!nocheck
-- Forest_Survey.luau — 2026-10-09 숲 갈아엎기 전 조사(편집 모드). 옛 숲·지협이 무엇으로 되어 있는지. 보고: /forestsurvey
local HS = game:GetService("HttpService")
local out = {}
local function say(f, ...)
	out[#out + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local S = workspace.Surface
	-- World / Mountains 아래 이름 머리별 개수·범위
	for _, folderName in { "World", "Mountains" } do
		local f = S:FindFirstChild(folderName)
		local groups = {}
		for _, c in f:GetChildren() do
			local key = c.Name:match("^(G_[^_]+)") or c.Name:match("^(Mt_[^_]+)") or c.Name
			local g = groups[key] or { n = 0, lo = Vector3.new(1e9, 1e9, 1e9), hi = Vector3.new(-1e9, -1e9, -1e9), cls = c.ClassName }
			groups[key] = g
			for _, d in (if c:IsA("BasePart") then { c } else c:GetDescendants()) do
				if d:IsA("BasePart") then
					g.n += 1
					g.lo = g.lo:Min(d.Position)
					g.hi = g.hi:Max(d.Position)
				end
			end
		end
		for key, g in groups do
			if g.n > 0 then
				say("%s/%s [%s] %d  x %.0f~%.0f z %.0f~%.0f y %.0f~%.0f", folderName, key, g.cls, g.n, g.lo.X, g.hi.X, g.lo.Z, g.hi.Z, g.lo.Y, g.hi.Y)
			end
		end
	end
	-- R_숲 아래 한 단계
	for _, c in S["R_숲"]:GetChildren() do
		local n = 0
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		say("R_숲/%s [%s] %d", c.Name, c.ClassName, n)
	end
	-- 지형(Terrain) 이 숲 자리에 있나: 숲 가운데·가장자리 몇 곳 위에서 광선
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	rp.IgnoreWater = true
	for _, p in { { -1610, 523 }, { -1000, 300 }, { -2300, 600 }, { -1600, -200 }, { -1600, 1300 }, { -500, 300 } } do
		local hit = workspace:Raycast(Vector3.new(p[1], 500, p[2]), Vector3.new(0, -1000, 0), rp)
		say("지형 광선 (%d,%d): %s", p[1], p[2], if hit then string.format("%.1f %s", hit.Position.Y, hit.Material.Name) else "없음")
	end
	-- 숲 섬 위 모든 파트 광선(무엇이 맨 위인가)
	local rp2 = RaycastParams.new()
	for _, p in { { -1610, 523 }, { -1000, 300 }, { -2300, 600 }, { -500, 300 } } do
		local hit = workspace:Raycast(Vector3.new(p[1], 500, p[2]), Vector3.new(0, -1000, 0), rp2)
		say("맨 위 (%d,%d): %s", p[1], p[2], if hit then string.format("%.1f %s", hit.Position.Y, hit.Instance:GetFullName()) else "없음")
	end
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/forestsurvey", table.concat(out, "\n"))
