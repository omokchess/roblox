--!nocheck
-- 2026-09-26 재배치 설계용 높이 지도. 20 스터드 간격으로 평원 땅을 훑는다
-- 글자: ~ 땅 없음, 0-9 높이 4 단위(0 = y<4), A-Z 그 위, # 암반(Slate/Rock 재질)
local out = {}
local function say(f, ...) out[#out + 1] = string.format(f, ...) end
local ok, err = pcall(function()
	local G = workspace.Surface.World["G_평원"]
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G }
	local mats = {}
	local X0, X1, Z0, Z1, S = -440, 840, -120, 1160, 20
	local hdr = {}
	for x = X0, X1, S do hdr[#hdr + 1] = (x % 100 == 0) and "|" or " " end
	say("     %s", table.concat(hdr))
	for z = Z0, Z1, S do
		local row = {}
		for x = X0, X1, S do
			local h = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), rp)
			local ch = "~"
			if h then
				local y = h.Position.Y
				local k = math.floor(y / 4)
				if k < 0 then ch = "-" elseif k < 10 then ch = tostring(k) else ch = string.char(65 + math.min(25, k - 10)) end
				local m = h.Instance.Material.Name
				mats[m] = (mats[m] or 0) + 1
				if m == "Slate" or m == "Rock" or m == "Basalt" then ch = "#" end
			end
			row[#row + 1] = ch
		end
		say("%5d %s", z, table.concat(row))
	end
	for m, n in pairs(mats) do say("mat %s %d", m, n) end
	-- G_평원 범위
	local x0, x1, z0, z1, y1 = 1e9, -1e9, 1e9, -1e9, -1e9
	local n = 0
	for _, p in ipairs(G:GetDescendants()) do
		if p:IsA("BasePart") then
			n += 1
			x0 = math.min(x0, p.Position.X - p.Size.X / 2); x1 = math.max(x1, p.Position.X + p.Size.X / 2)
			z0 = math.min(z0, p.Position.Z - p.Size.Z / 2); z1 = math.max(z1, p.Position.Z + p.Size.Z / 2)
			y1 = math.max(y1, p.Position.Y + p.Size.Y / 2)
		end
	end
	say("G_평원 parts %d x %.0f..%.0f z %.0f..%.0f top %.0f", n, x0, x1, z0, z1, y1)
	local sp = workspace:FindFirstChild("PlayerSpawn")
	if sp then say("Spawn (%.1f,%.1f,%.1f) size %s", sp.Position.X, sp.Position.Y, sp.Position.Z, tostring(sp.Size)) end
	local bh = workspace:FindFirstChild("Building_Hall")
	if bh then local p = bh:GetPivot() say("WS Building_Hall (%.1f,%.1f,%.1f)", p.X, p.Y, p.Z) end
	for _, c in ipairs(workspace.Surface:GetChildren()) do say("Surface/%s [%s] n=%d", c.Name, c.ClassName, #c:GetChildren()) end
	for _, c in ipairs(workspace.Surface.World:GetChildren()) do say("World/%s n=%d", c.Name, #c:GetDescendants()) end
	local R = workspace.Surface:FindFirstChild("R_평원")
	if R then for _, c in ipairs(R:GetChildren()) do say("R_평원/%s [%s] n=%d", c.Name, c.ClassName, #c:GetDescendants()) end end
	local T = workspace.Terrain
	local r = Region3.new(Vector3.new(-440, -40, -120), Vector3.new(840, 40, 1160)):ExpandToGrid(4)
	local ok2, m2 = pcall(function() return T:CountCells() end)
	say("terrain cells %s", tostring(m2))
end)
if not ok then say("ERR %s", tostring(err)) end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
local okp, e2 = pcall(function() HS:PostAsync("http://127.0.0.1:34999/survey6", table.concat(out, "\n")) end)
HS.HttpEnabled = was
print("survey6", #out, okp, e2)
