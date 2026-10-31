--!nocheck
--[[
	Snow_Tunnels.luau — 2026-10-31. 설원 동굴 입구 셋을 비스듬한 굴로(편집 모드, StudioJobs). 자료 tools/snow_tunnel_plan.py:
	  python tools/snow_tunnel_plan.py && sed '/--@@DATA@@/r tools/Snow_Tunnels_data.luau' tools/Snow_Tunnels.luau > tools/swamp/_tunnel_run.luau && bash tools/job.sh tools/swamp/_tunnel_run.luau
	Snow3_Build · Snow3_Under · Snow_City2 뒤에 돌린다(그것들을 다시 지으면 이것도 다시). 몇 번 돌려도 같다:
	  1. 지하의 옛 구멍 벽·디딤(ShaftWall · Ledge — 이름 = 구멍 이름)을 지운다
	  2. 땅(R_설원3.Land)과 지하(R_설원3_지하)의 축 정렬 상자를 상자 빼기로 쪼갠다(도랑 · 굴 방 벽 입). 처음 판은 ServerStorage.Snow_TunnelOriginal
	  3. 굴 자리 지형(땅 밑 물·모래)을 공기로
	  4. Surface.R_설원3_터널 을 지우고 새로: 굴 몸·계단·갱목·입구 바위 언덕·다시 덮은 땅·옛 구멍 메움·지하 천장·등잔(불·빛)·쇠창살·명소
	보고: /snowtunnels (빼기 개수, 도랑·입구 자리에 걸린 다른 파트)
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SKIN = {
	Ceil = { RGB(58, 62, 70), M.Slate, "Tube" },
	Wall = { RGB(70, 75, 84), M.Slate, "Tube" },
	Under = { RGB(70, 75, 84), M.Slate, "Tube" },
	Floor = { RGB(78, 84, 92), M.Slate, "Tube" },
	Step = { RGB(88, 95, 104), M.Slate, "Steps" },
	Step2 = { RGB(80, 87, 96), M.Slate, "Steps" },
	Timber = { RGB(90, 62, 44), M.WoodPlanks, "Timber" },
	Rock = { RGB(100, 110, 106), M.Slate, "PortalRocks" },
	Rock2 = { RGB(88, 97, 95), M.Slate, "PortalRocks" },
	RockSnow = { RGB(238, 243, 247), M.Snow, "PortalRocks" },
	Backfill = { RGB(112, 118, 130), M.Slate, "Fill" },
	Snow = { RGB(236, 240, 246), M.Snow, "Fill" },
	CaveCeil = { RGB(58, 62, 70), M.Slate, "Fill" },
	Bar = { RGB(58, 60, 66), M.Metal, "Gate" },
}
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

-- 상자 빼기: lo~hi 에서 clo~chi 를 뺀 조각들(Snow_City2 3f 와 같은 방식)
local function sub(lo, hi, clo, chi)
	for _, ax in ipairs({ "X", "Y", "Z" }) do
		if math.min(hi[ax], chi[ax]) - math.max(lo[ax], clo[ax]) <= 1e-3 then
			return nil
		end
	end
	local out = {}
	local l, h = { X = lo.X, Y = lo.Y, Z = lo.Z }, { X = hi.X, Y = hi.Y, Z = hi.Z }
	for _, ax in ipairs({ "X", "Y", "Z" }) do
		if clo[ax] > l[ax] + 1e-3 then
			local a, b = table.clone(l), table.clone(h)
			b[ax] = clo[ax]
			out[#out + 1] = { Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y, b.Z) }
			l[ax] = clo[ax]
		end
		if chi[ax] < h[ax] - 1e-3 then
			local a, b = table.clone(l), table.clone(h)
			a[ax] = chi[ax]
			out[#out + 1] = { Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y, b.Z) }
			h[ax] = chi[ax]
		end
	end
	return out
end

local function carve(root, boxes, store)
	local cut, pieces = 0, 0
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.CFrame.XVector.X > 0.9999 and p.CFrame.YVector.Y > 0.9999 then
			local list = { { p.Position - p.Size / 2, p.Position + p.Size / 2 } }
			local hit = false
			for _, c in ipairs(boxes) do
				local clo, chi = Vector3.new(c[1], c[3], c[5]), Vector3.new(c[2], c[4], c[6])
				local nextList = {}
				for _, b in ipairs(list) do
					local rest = sub(b[1], b[2], clo, chi)
					if rest then
						hit = true
						for _, r in ipairs(rest) do
							nextList[#nextList + 1] = r
						end
					else
						nextList[#nextList + 1] = b
					end
				end
				list = nextList
			end
			if hit then
				cut += 1
				if not store:FindFirstChild(p:GetFullName()) then
					local keep = p:Clone()
					keep.Name = p:GetFullName()
					keep.Parent = store
				end
				for i, b in ipairs(list) do
					local q = p:Clone()
					q.Name = p.Name .. (if i > 1 then "_" .. i else "")
					q.Size = b[2] - b[1]
					q.CFrame = CFrame.new((b[1] + b[2]) / 2)
					q.Parent = p.Parent
					pieces += 1
				end
				p:Destroy()
			end
		end
	end
	return cut, pieces
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local G = assert(S:FindFirstChild("R_설원3"), "Surface.R_설원3(설원 땅)이 없다")
	local U = assert(S:FindFirstChild("R_설원3_지하"), "Surface.R_설원3_지하(지하 굴)가 없다")
	local old = S:FindFirstChild("R_설원3_터널")
	if old then
		old:Destroy()
	end
	-- 1. 옛 구멍 벽·디딤
	local gone = 0
	for _, name in SHAFTS do
		for _, p in ipairs(U:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == name then
				p:Destroy()
				gone += 1
			end
		end
	end
	say("옛 구멍 벽·디딤 %d개 지움", gone)
	-- 2. 상자 빼기
	local store = SS:FindFirstChild("Snow_TunnelOriginal")
	if not store then
		store = Instance.new("Folder")
		store.Name = "Snow_TunnelOriginal"
		store.Parent = SS
	end
	local c1, p1 = carve(G:FindFirstChild("Land"), CARVE_LAND, store)
	local c2, p2 = carve(U, CARVE_UNDER, store)
	say("땅 빼기 %d판 → %d조각 · 지하 빼기 %d판 → %d조각", c1, p1, c2, p2)
	-- 도랑 자리에 걸린 다른 파트(땅 말고) — 손볼 것 찾기
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { G:FindFirstChild("Land"), U, workspace.Terrain }
	for _, c in CARVE_LAND do
		local box = { c[1], c[2], c[3] + 25, c[4] + 40, c[5] - 10, c[6] }
		local cf = CFrame.new((box[1] + box[2]) / 2, (box[3] + box[4]) / 2, (box[5] + box[6]) / 2)
		local hits = workspace:GetPartBoundsInBox(cf, Vector3.new(box[2] - box[1] + 30, box[4] - box[3], box[6] - box[5] + 20), op)
		local names = {}
		for i, h in ipairs(hits) do
			if i > 8 then
				break
			end
			names[#names + 1] = h:GetFullName():gsub("^Workspace%.Surface%.", "")
		end
		say("도랑 %.0f,%.0f 근처 다른 파트 %d: %s", c[1], c[5], #hits, table.concat(names, " | "))
	end
	-- 3. 지형
	for _, a in AIR do
		workspace.Terrain:FillBlock(CFrame.new((a[1] + a[2]) / 2, (a[3] + a[4]) / 2, (a[5] + a[6]) / 2), Vector3.new(a[2] - a[1], a[4] - a[3], a[6] - a[5]), M.Air)
	end
	-- 4. 새로 짓기
	local root = Instance.new("Folder")
	root.Name = "R_설원3_터널"
	local folders = {}
	local function folder(n)
		if not folders[n] then
			local f = Instance.new("Folder")
			f.Name = n
			f.Parent = root
			folders[n] = f
		end
		return folders[n]
	end
	local function make(kind, cx, cy, cz, sx, sy, sz, rx, ry, parent, i)
		local s = SKIN[kind]
		local p = Instance.new("Part")
		p.Name = kind .. i
		p.Anchored = true
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(cx, cy, cz) * CFrame.Angles(0, math.rad(ry or 0), 0) * CFrame.Angles(math.rad(rx or 0), 0, 0)
		p.Color, p.Material = s[1], s[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent or folder(s[3])
		return p
	end
	for i, d in PARTS do
		local p = make(d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], nil, i)
		if d[1] == "Backfill" and i % 2 == 0 then
			p.Color = RGB(98, 104, 116)
		end
	end
	-- 등잔: 쇠 갓 + 유리 몸 안의 불 + 빛
	for i, l in LAMPS do
		local cf = CFrame.new(l[1], l[2], l[3]) * CFrame.Angles(math.rad(l[4]), 0, 0)
		local lamp = Instance.new("Model")
		lamp.Name = "등잔" .. i
		local glass = Instance.new("Part")
		glass.Name = "유리"
		glass.Anchored, glass.CanCollide = true, false
		glass.Size = Vector3.new(1.1, 1.5, 1.1)
		glass.CFrame = cf
		glass.Color, glass.Material = RGB(255, 196, 120), M.Glass
		glass.Transparency = 0.35
		glass.Parent = lamp
		for _, dy in { 0.95, -0.95 } do
			local cap = Instance.new("Part")
			cap.Name = "갓"
			cap.Anchored, cap.CanCollide = true, false
			cap.Size = Vector3.new(1.4, 0.4, 1.4)
			cap.CFrame = cf * CFrame.new(0, dy, 0)
			cap.Color, cap.Material = RGB(40, 38, 36), M.Metal
			cap.Parent = lamp
		end
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 1, 1
		fire.Color, fire.SecondaryColor = RGB(255, 170, 70), RGB(255, 90, 30)
		fire.Parent = glass
		local light = Instance.new("PointLight")
		light.Range, light.Brightness = 24, 1.4
		light.Color = RGB(255, 184, 116)
		light.Shadows = true
		light.Parent = glass
		lamp.PrimaryPart = glass
		lamp.Parent = folder("Lamps")
	end
	-- 3번 입구 잠긴 쇠창살(퀘스트로 열 자리)
	for _, g in GATES do
		local m = Instance.new("Model")
		m.Name = "QuestGate_" .. g[1]
		m:SetAttribute("QuestLocked", true)
		m:SetAttribute("Entrance", g[1])
		for i, b in g[2] do
			make(b[1], b[2], b[3], b[4], b[5], b[6], b[7], 0, 0, m, i)
		end
		m.Parent = folder("Gate")
	end
	-- 순간이동 명소(PlayerService 가 태그로 찾는다)
	for _, s in SPOTS do
		local p = Instance.new("Part")
		p.Name = "Spot_" .. s[1]
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(2, 1, 2)
		p.CFrame = CFrame.lookAt(Vector3.new(s[2], s[3], s[4]), Vector3.new(s[5], s[3], s[6]))
		p:SetAttribute("SpotName", s[1])
		p:SetAttribute("Region", "설원")
		CS:AddTag(p, "TeleportSpot")
		p.Parent = folder("Spots")
	end
	root.Parent = S
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	say("R_설원3_터널: 파트 %d · 등잔 %d · 명소 %d", n, #LAMPS, #SPOTS)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snowtunnels", table.concat(lines, "\n"))
