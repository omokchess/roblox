--!nocheck
-- 2026-09-26 설원 꾸미기 전 측량. G_설원 범위, 20 간격 높이 지도, Zone_설원 지물 목록
local out = {}
local function say(f, ...)
	out[#out + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local S = workspace.Surface
	say("WorldScale %s", tostring(S:GetAttribute("WorldScale")))
	local G = S.World["G_설원"]
	local x0, x1, z0, z1, y0, y1 = 1e9, -1e9, 1e9, -1e9, 1e9, -1e9
	local mats = {}
	for _, p in ipairs(G:GetDescendants()) do
		if p:IsA("BasePart") then
			x0 = math.min(x0, p.Position.X - p.Size.X / 2)
			x1 = math.max(x1, p.Position.X + p.Size.X / 2)
			z0 = math.min(z0, p.Position.Z - p.Size.Z / 2)
			z1 = math.max(z1, p.Position.Z + p.Size.Z / 2)
			y0 = math.min(y0, p.Position.Y - p.Size.Y / 2)
			y1 = math.max(y1, p.Position.Y + p.Size.Y / 2)
			mats[p.Material.Name] = (mats[p.Material.Name] or 0) + 1
		end
	end
	say("G_설원 x %.0f..%.0f z %.0f..%.0f y %.0f..%.0f", x0, x1, z0, z1, y0, y1)
	for m, n in pairs(mats) do
		say("mat %s %d", m, n)
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G }
	-- 높이 지도. 한 칸 20. 글자: ~ 땅 없음, 높이를 4 단위로 0-9 A-Z
	local S0 = 20
	local gx0, gx1 = math.floor(x0 / S0) * S0, math.ceil(x1 / S0) * S0
	local gz0, gz1 = math.floor(z0 / S0) * S0, math.ceil(z1 / S0) * S0
	say("GRID x %d..%d z %d..%d step %d", gx0, gx1, gz0, gz1, S0)
	for z = gz0, gz1, S0 do
		local row = {}
		for x = gx0, gx1, S0 do
			local h = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), rp)
			local ch = "~"
			if h then
				local k = math.floor(h.Position.Y / 4)
				if k < 0 then
					ch = "-"
				elseif k < 10 then
					ch = tostring(k)
				else
					ch = string.char(65 + math.min(25, k - 10))
				end
			end
			row[#row + 1] = ch
		end
		say("%6d %s", z, table.concat(row))
	end
	-- 설원 지물
	local Z = S:FindFirstChild("Zone_설원")
	if Z then
		for _, f in ipairs(Z:GetChildren()) do
			local cf, size = f:IsA("Model") and f:GetBoundingBox() or nil, nil
			say("Zone_설원/%s [%s] kids %d desc %d", f.Name, f.ClassName, #f:GetChildren(), #f:GetDescendants())
		end
		for _, m in ipairs(Z["설림"]:GetChildren()) do
			local p = m:IsA("Model") and m:GetPivot().Position or (m:IsA("BasePart") and m.Position)
			if p then
				say("tree %s (%.0f,%.0f,%.0f)", m.Name, p.X, p.Y, p.Z)
			end
		end
	end
	-- 설원 근처 다른 것들
	for _, c in ipairs(S:GetChildren()) do
		say("Surface/%s n=%d", c.Name, #c:GetDescendants())
	end
	for _, c in ipairs(workspace:GetChildren()) do
		say("WS %s [%s]", c.Name, c.ClassName)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snow1", table.concat(out, "\n"))
end)
HS.HttpEnabled = was
print("snow1", #out)
