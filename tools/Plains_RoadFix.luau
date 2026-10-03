--!nocheck
--[[
	Plains_RoadFix.luau — 2026-10-03. 평원 평탄화(Plains_Build·Plains_Reseat) 뒤 길 높이 맞추기(편집 모드, StudioJobs).

	옛 비탈 타일에 묻혀 있던 두꺼운 길 상자(두께 2~7)가 평평한 새 땅 위로 1~6 스터드 솟았다.
	  1. 길 폴더(Jeolhwa.길)의 Part 마다 윗면 − 가운데 땅 높이가 1 넘게 뜨면 윗면이 땅 + 0.45(다른 길과 같음)가 되게 내린다
	  2. 동산길 끝(정자 오르막, Plains_Build EAST RAMPS 의 { 676, 322, 290, 28 }): Road_2_2 를 오르막 아래까지 평평하게 줄이고,
	     오르막 위로 기운 판(Road_2_3, Road_2_2 복제)을 깔고, Road_3_1 은 둔덕 위에서 평평하게, Joint_3 는 오르막 꼭대기 이음매로
	다시 돌려도 된다(이미 맞으면 안 움직인다). 보고: /roadfix
]]
local HS = game:GetService("HttpService")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local OFF = 0.45 -- 길 윗면이 땅보다 높은 만큼(평원 길 대부분이 0.4~0.5)
local THICK = 1.3

local ok, err = pcall(function()
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
	local function ground(x: number, z: number): number
		local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), ray)
		return r and r.Position.Y or 1.9
	end
	local function halfY(p: BasePart): number
		local cf, s = p.CFrame, p.Size
		return math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
	end

	-- 2. 동산길 끝 — 먼저(1 이 이 조각들을 건드리지 않게)
	local ds = workspace.Jeolhwa["길"]:FindFirstChild("동산길")
	local skip = {}
	if ds and ds:FindFirstChild("Road_2_2") and ds:FindFirstChild("Road_3_1") then
		local r22, r31, j3 = ds.Road_2_2, ds.Road_3_1, ds:FindFirstChild("Joint_3")
		skip[r22], skip[r31] = true, true
		-- 길 줄기: Road_2_2 의 남서 끝(z 큰 쪽)에서 Road_3_1 의 북동 끝까지
		local function ends(p: BasePart): (Vector3, Vector3)
			local a = p.Position + p.CFrame.RightVector * p.Size.X / 2
			local b = p.Position - p.CFrame.RightVector * p.Size.X / 2
			if a.Z < b.Z then
				a, b = b, a
			end
			return Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z) -- (남서, 북동)
		end
		local sw = ends(r22)
		local _, ne = ends(r31)
		if r22:GetAttribute("RoadFixSW") then
			sw = r22:GetAttribute("RoadFixSW") -- 다시 돌릴 때 처음 끝점
			ne = r22:GetAttribute("RoadFixNE")
		else
			r22:SetAttribute("RoadFixSW", sw)
			r22:SetAttribute("RoadFixNE", ne)
		end
		local u = (ne - sw).Unit
		-- 줄기를 따라 땅 높이를 재어 오르막 시작(P1)·끝(P2)을 찾는다
		local total = (ne - sw).Magnitude
		local g0 = ground(sw.X, sw.Z)
		local t1, t2
		for t = 0, total, 0.25 do
			local p = sw + u * t
			local g = ground(p.X, p.Z)
			if not t1 and g > g0 + 0.05 then
				t1 = t - 0.25
			end
			if t1 and not t2 and g >= 8.25 then
				t2 = t
			end
		end
		assert(t1 and t2, "오르막을 못 찾음")
		local P1, P2 = sw + u * t1, sw + u * t2
		local h1, h2 = ground(P1.X, P1.Z), ground(P2.X, P2.Z)
		say("동산길 오르막 P1 %.1f,%.1f (%.1f) → P2 %.1f,%.1f (%.1f)", P1.X, P1.Z, h1, P2.X, P2.Z, h2)

		-- 판 하나를 a→b(높이 ha→hb, 윗면 = 땅 + OFF)로 놓는다. 길이 축 = 로컬 X(다른 길 조각과 같음)
		local function lay(p: BasePart, a: Vector3, ha: number, b: Vector3, hb: number)
			local A = Vector3.new(a.X, ha + OFF, a.Z)
			local B = Vector3.new(b.X, hb + OFF, b.Z)
			local along = (B - A).Unit
			local side = along:Cross(Vector3.yAxis).Unit
			local up = side:Cross(along).Unit
			local mid = (A + B) / 2 - up * THICK / 2
			p.Size = Vector3.new((B - A).Magnitude + 0.3, THICK, p.Size.Z)
			p.CFrame = CFrame.fromMatrix(mid, along, up)
		end
		lay(r22, sw, g0, P1, h1)
		local r23 = ds:FindFirstChild("Road_2_3") or r22:Clone()
		r23.Name = "Road_2_3"
		r23:SetAttribute("RoadFixSW", nil)
		r23:SetAttribute("RoadFixNE", nil)
		r23.Parent = ds
		lay(r23, P1, h1, P2, h2)
		lay(r31, P2, h2, ne, ground(ne.X, ne.Z))
		if j3 then
			local top = h2 + OFF - 0.05
			j3.CFrame = CFrame.new(P2.X, top - halfY(j3), P2.Z) * j3.CFrame.Rotation
		end
	end

	-- 1. 뜬 길 조각 내리기
	local fixed = 0
	for _, d in workspace.Jeolhwa["길"]:GetDescendants() do
		if d:IsA("BasePart") and not skip[d] and d.Name ~= "Joint_3" and d.Name ~= "Road_2_3" then
			local top = d.Position.Y + halfY(d)
			local g = ground(d.Position.X, d.Position.Z)
			local off = top - g
			if off > 1.0 then
				d.CFrame += Vector3.new(0, OFF - off, 0)
				fixed += 1
				say("내림 %.2f %s", off - OFF, d:GetFullName())
			end
		end
	end
	say("뜬 조각 %d개 내림", fixed)
end)
HS:PostAsync("http://127.0.0.1:34999/roadfix", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
