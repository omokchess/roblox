--!nocheck
-- MapSurvey.luau — 지형 갈아엎기 전 지금 맵 조사(편집 모드). workspace 맨 위 자식마다 파트 수·경계 상자, 그 아래 한 단계도. (2026-10-03)
-- 보고: /mapsurvey
local HS = game:GetService("HttpService")
local out = {}
local function say(f, ...)
	out[#out + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local function box(inst)
		local lo, hi, n = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge), 0
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				local p = d.Position
				lo = lo:Min(p)
				hi = hi:Max(p)
			end
		end
		if inst:IsA("BasePart") then
			n += 1
			lo, hi = inst.Position, inst.Position
		end
		return n, lo, hi
	end
	local function line(inst, depth)
		local n, lo, hi = box(inst)
		if n == 0 then
			say("%s%s [%s] 파트 0", string.rep("  ", depth), inst.Name, inst.ClassName)
		else
			say("%s%s [%s] 파트 %d  x %.0f~%.0f  y %.0f~%.0f  z %.0f~%.0f", string.rep("  ", depth), inst.Name, inst.ClassName, n, lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z)
		end
		return n
	end
	for _, c in workspace:GetChildren() do
		if c:IsA("Terrain") or c:IsA("Camera") then
			continue
		end
		local n = line(c, 0)
		if n > 200 and (c:IsA("Folder") or c:IsA("Model")) then
			local kids = c:GetChildren()
			if #kids <= 40 then
				for _, k in kids do
					line(k, 1)
				end
			else
				say("  (자식 %d개)", #kids)
			end
		end
	end
	-- 지형 복셀: 큰 칸으로 훑어 채워진 곳
	local t = workspace.Terrain
	local reg = t:FindFirstChildOfClass("TerrainRegion")
	say("Terrain 자식 %d, MaxExtents %s", #t:GetChildren(), tostring(t.MaxExtents))
end)
HS:PostAsync("http://127.0.0.1:34999/mapsurvey", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(out, "\n"))
