--!nocheck
--[[
	Swamp_Check.luau — 2026-09-28. 늪지대 재작업을 수치로 점검해 /swampcheck 로 보고한다.
	1) 지형 높이: 계획(terrain.txt)과 실제 지형 표면(광선, 물 무시) 차이
	2) 물: 계획상 물인 칸에서 물 표면(y≈0)을 맞히는지, 뭍 칸에 물이 없는지
	3) 뜬 물건: 땅에 앉힌 모델(분류 나무·소품·유적)의 밑면이 지형보다 0.6 이상 뜨면 목록
	4) 부품 수·분류별 모델 수, 숨긴 흙 판 수
]]
local HS = game:GetService("HttpService")
local out = {}
local ok, err = pcall(function()
	local txt = HS:GetAsync("http://127.0.0.1:35000/terrain.txt", true)
	local lines = string.split(txt, "\n")
	local hdr = string.split(lines[1], " ")
	local X0, Z0, R, NX, NZ = tonumber(hdr[1]), tonumber(hdr[2]), tonumber(hdr[3]), tonumber(hdr[4]), tonumber(hdr[5])
	local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
	local IDX = {}
	for i = 1, 64 do
		IDX[string.byte(ALPHA, i)] = i - 1
	end
	local function planH(x, z)
		local i = math.floor((x - X0) / R) + 1
		local j = math.floor((z - Z0) / R) + 1
		if i < 1 or i > NX or j < 1 or j > NZ then
			return nil
		end
		local s = lines[1 + j]
		local v = IDX[s:byte(2 * i - 1)] * 64 + IDX[s:byte(2 * i)]
		return v ~= 0 and (v / 10 - 64) or nil
	end
	local land = RaycastParams.new()
	land.FilterType = Enum.RaycastFilterType.Include
	land.FilterDescendantsInstances = { workspace.Terrain }
	land.IgnoreWater = true
	local wet = RaycastParams.new()
	wet.FilterType = Enum.RaycastFilterType.Include
	wet.FilterDescendantsInstances = { workspace.Terrain }
	wet.IgnoreWater = false
	-- 1, 2
	local n, sum, worst, wn, wbad, lbad = 0, 0, 0, 0, 0, 0
	local worstAt = ""
	for j = 0, 40 do
		for i = 0, 60 do
			local x, z = X0 + 17.3 + i * 32, Z0 + 14.7 + j * 30
			local ph = planH(x, z)
			if ph then
				local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), land)
				if hit then
					local d = math.abs(hit.Position.Y - ph)
					n += 1
					sum += d
					if d > worst then
						worst = d
						worstAt = string.format("(%d,%d) 계획 %.1f 실제 %.1f", x, z, ph, hit.Position.Y)
					end
				end
				local w = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), wet)
				local isWater = w and w.Material == Enum.Material.Water
				if ph < -0.5 then
					wn += 1
					if not isWater then
						wbad += 1
					end
				elseif ph > 0.4 and isWater then
					lbad += 1
				end
			end
		end
		task.wait()
	end
	out[#out + 1] = string.format("지형 높이: 표본 %d, 평균 차 %.2f, 최대 %.2f %s", n, sum / math.max(n, 1), worst, worstAt)
	out[#out + 1] = string.format("물: 계획상 물 칸 %d 중 물 못 맞힘 %d, 뭍 칸인데 물 %d", wn, wbad, lbad)
	-- 3, 4
	local root = workspace.Surface:FindFirstChild("Swamp_늪지대")
	local parts, float, cats = 0, {}, {}
	for _, g in ipairs(root:GetChildren()) do
		local c = 0
		for _, m in ipairs(g:GetChildren()) do
			c += 1
			if g.Name ~= "판자길" and g.Name ~= "건물" then
				local cf, size = m:GetBoundingBox()
				local bottom = cf.Position.Y - size.Y / 2
				local pv = m:GetPivot().Position
				local hit = workspace:Raycast(Vector3.new(pv.X, 60, pv.Z), Vector3.new(0, -120, 0), land)
				if hit and bottom > hit.Position.Y + 0.6 and m:GetAttribute("Asset") ~= "LilyPads" then
					float[#float + 1] = string.format("%s(%.0f,%.0f) %.1f", m:GetAttribute("Asset"), pv.X, pv.Z, bottom - hit.Position.Y)
				end
			end
		end
		cats[#cats + 1] = g.Name .. " " .. c
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	out[#out + 1] = "분류: " .. table.concat(cats, ", ") .. string.format(" / 부품 %d", parts)
	out[#out + 1] = string.format("뜬 것 %d: %s", #float, table.concat(float, " "):sub(1, 1500))
	local hidden = 0
	for _, p in ipairs(workspace.Surface.World["G_늪지대"]:GetChildren()) do
		if p:GetAttribute("SwampOldTransparency") ~= nil and p.Transparency == 1 then
			hidden += 1
		end
	end
	out[#out + 1] = "숨긴 흙 판 " .. hidden
end)
if not ok then
	out[#out + 1] = "ERR " .. tostring(err)
end
HS:PostAsync("http://127.0.0.1:34999/swampcheck", table.concat(out, "\n"))
