--!nocheck
--[[
	Plains_Reseat.luau — 2026-10-03. 평원 평탄화 뒤 도성 물건 높이 바로잡기(편집 모드, StudioJobs).

	Plains_Build 의 첫 옮겨 앉히기는 물건 가운데 위에서 내려 쏜 광선이 맞은 "가장 높은 옛 타일"을 받침으로 봤다 →
	둔덕 타일 옆·아래를 지나던 길이 4.8 스터드 땅속으로 들어갔다. 그래서:
	  1. ReseatDelta 만큼 되돌린다(원래 자리)
	  2. 받침 = 물건 밑면 + 3 아래에 있는 옛 타일 윗면 중 가장 높은 것(물건 바로 밑 땅). 옛 타일은 백업 폴더
	     (ServerStorage.TerrainBackup.PlainsCenter·PlainsEast·PlainsNorth)에서 자리·크기로 바로 잰다(광선 없이)
	  3. 새 땅(평원 지역 폴더의 땅·절벽·덩어리·오르막·모래) 높이 − 받침 만큼 옮기고 ReseatDelta 에 적는다
	받침이 없으면(옛 타일 밖) 그대로 둔다. 보고: /reseat
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	-- 옛 타일(백업)
	local tiles = {}
	for _, name in { "PlainsCenter", "PlainsEast", "PlainsNorth" } do
		local f = SS.TerrainBackup:FindFirstChild(name)
		for _, t in (f and f:GetChildren()) or {} do
			if t:IsA("BasePart") then
				table.insert(tiles, { CF = t.CFrame, Half = t.Size / 2, Top = t.Position.Y + t.Size.Y / 2 })
			end
		end
	end
	say("옛 타일 %d", #tiles)
	local function support(x: number, z: number, bottom: number): number?
		local best = nil
		for _, t in tiles do
			if t.Top <= bottom + 3 and (not best or t.Top > best) then
				local lp = t.CF:PointToObjectSpace(Vector3.new(x, t.CF.Y, z))
				if math.abs(lp.X) <= t.Half.X and math.abs(lp.Z) <= t.Half.Z then
					best = t.Top
				end
			end
		end
		return best
	end

	-- 새 땅
	local terrain = {}
	for _, region in { "R_평원북", "R_평원동", "R_평원중" } do
		local f = workspace.Surface:FindFirstChild(region)
		for _, sub in { "Land", "Cliffs", "Masses", "Ramps", "Sand" } do
			local x = f and f:FindFirstChild(sub)
			if x then
				table.insert(terrain, x)
			end
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = terrain

	local function bottomOf(inst: Instance): (number, number, number)
		if inst:IsA("Model") then
			local cf, size = inst:GetBoundingBox()
			return cf.X, cf.Y - size.Y / 2, cf.Z
		end
		local cf, s = inst.CFrame, inst.Size
		-- 돌아간 Part 의 세로 반 높이(축 정렬 상자)
		local hy = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
		return cf.X, cf.Y - hy, cf.Z
	end
	local function shift(inst: Instance, dy: number)
		if inst:IsA("Model") then
			inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0))
		else
			inst.CFrame += Vector3.new(0, dy, 0)
		end
	end

	local holders = { workspace.Jeolhwa }
	local flora = workspace.Surface:FindFirstChild("R_평원")
	if flora then
		table.insert(holders, flora)
	end
	local undone, moved, lifted, sunk, skipped = 0, 0, 0, 0, 0
	for _, holder in holders do
		for _, d in holder:GetDescendants() do
			if not ((d:IsA("Model") or d:IsA("BasePart")) and d.Parent and d.Parent:IsA("Folder")) then
				continue
			end
			-- 1. 되돌리기
			local was = d:GetAttribute("ReseatDelta")
			if was then
				shift(d, -was)
				d:SetAttribute("ReseatDelta", nil)
				undone += 1
			end
			-- 2·3. 밑면 아래 받침 → 새 땅
			local x, bottom, z = bottomOf(d)
			local old = support(x, z, bottom)
			if not old then
				skipped += 1
				continue
			end
			local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), ray)
			if not r then
				skipped += 1
				continue
			end
			local dy = r.Position.Y - old
			if math.abs(dy) > 0.01 then
				shift(d, dy)
				d:SetAttribute("ReseatDelta", dy)
				moved += 1
				if dy > 0.5 then
					lifted += 1
				elseif dy < -0.5 then
					sunk += 1
				end
			end
		end
	end
	say("되돌림 %d · 옮김 %d(0.5 넘게 올림 %d · 내림 %d) · 받침 없음 %d", undone, moved, lifted, sunk, skipped)
end)
HS:PostAsync("http://127.0.0.1:34999/reseat", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
