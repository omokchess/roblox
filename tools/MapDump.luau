--!nocheck
-- MapDump.luau — 위에서 본 지도를 그리려고 Surface·Jeolhwa 파트를 거칠게 내보낸다(편집 모드). (2026-10-03)
-- 한 줄 = 폴더경로|이름|x|y|z|sx|sy|sz|r,g,b|재질. 큰 파트(가로 20 이상)만. 보고: /mapdump (+ /mapnames 이름별 개수)
local HS = game:GetService("HttpService")
local ok, err = pcall(function()
	local rows, names = {}, {}
	local function walk(root)
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				local s = d.Size
				local top = d.Parent and d.Parent.Name or "?"
				local key = top .. "/" .. d.Name
				names[key] = (names[key] or 0) + 1
				if math.max(s.X, s.Z) >= 20 then
					local p, c = d.Position, d.Color
					rows[#rows + 1] = string.format("%s|%s|%.0f|%.1f|%.0f|%.0f|%.1f|%.0f|%d,%d,%d|%s", d:GetFullName():sub(11, 60), d.Name, p.X, p.Y, p.Z, s.X, s.Y, s.Z,
						c.R * 255, c.G * 255, c.B * 255, d.Material.Name)
				end
			end
		end
	end
	walk(workspace.Surface)
	walk(workspace.Jeolhwa)
	-- 보고 한 번 1MB 제한 → 4000줄씩 나눠 /mapdump1, /mapdump2 …
	local part = 0
	for i = 1, #rows, 4000 do
		part += 1
		HS:PostAsync("http://127.0.0.1:34999/mapdump" .. part, table.concat(rows, "\n", i, math.min(#rows, i + 3999)))
	end
	local list = {}
	for k, v in names do
		list[#list + 1] = { k, v }
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	local out = {}
	for i = 1, math.min(80, #list) do
		out[i] = list[i][1] .. " " .. list[i][2]
	end
	HS:PostAsync("http://127.0.0.1:34999/mapnames", table.concat(out, "\n"))
end)
if not ok then
	HS:PostAsync("http://127.0.0.1:34999/mapdump_err", tostring(err))
end
