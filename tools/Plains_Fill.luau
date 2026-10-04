--!nocheck
--[[
	Plains_Fill.luau — 2026-10-04. 평원 섬 빈 들 채우기(편집 모드, StudioJobs 로 돌린다).
	사용자: "평원 맵쪽 너무 휑하니까 이것만 손 보고". 배치는 tools/plains_fill_plan.py 표(손 배치, 겹침 검사 0건) →
	Plains_Fill_data.luau 를 아래 --@@DATA@@ 자리에 끼워 돌린다:
	  sed '/--@@DATA@@/r tools/Plains_Fill_data.luau' tools/Plains_Fill.luau > tools/swamp/_fill_run.luau && bash tools/job.sh tools/swamp/_fill_run.luau
	다시 돌리면 Surface.R_평원채움 만 지우고 새로 짓는다(다른 지역·도성은 건드리지 않는다).
	짓는 것: 덩어리·오르막(Plains_Build 와 같은 양식) → 못·텃밭 → 키트 물건(한옥·늪 소품) → 나무 → 바위 → 돌길 → 봉수대·서낭당·장승.
	보고: /plainsfill
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local TOP = 1.90
local GRASS = RGB(117, 151, 83)
local ROCK = RGB(132, 130, 124)
local ROCK2 = RGB(118, 116, 111)
local STONE, STONE2 = RGB(160, 152, 136), RGB(146, 139, 124)
local WOOD = RGB(118, 92, 66)
local SOIL, RIDGE = RGB(122, 100, 73), RGB(104, 84, 60)

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local function part(name, size, cf, color, mat, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function block(name, x0, x1, z0, z1, top, bottom, parent, rockColor, capColor, capMat)
	local h = top - bottom
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	part(name, Vector3.new(x1 - x0, h - 1.2, z1 - z0), CFrame.new(cx, bottom + (h - 1.2) / 2, cz), rockColor or ROCK, M.Slate, parent)
	part(name .. "_풀", Vector3.new(x1 - x0, 1.2, z1 - z0), CFrame.new(cx, top - 0.6, cz), capColor or GRASS, capMat or M.Grass, parent)
end

local function build()
	local surface = workspace:FindFirstChild("Surface")
	assert(surface, "Surface 폴더가 없다")
	--[[
		지난번에 들어 올린 평원 지형 물건을 먼저 내려놓는다(FillLift 속성 = 올린 만큼).
		나무·바위: 언덕·단 위로(땅 높이 차이만큼). 옛 덩어리·오르막·잔해: 든 단 높이만큼(PLATEAUS — 2026-10-04 땅 판 높낮이).
	]]
	-- 평원 옛 오르막(Plains_Build 의 풀 쐐기 · 2026-10-04 자동 턱)을 걷는다 — 손 배치 턱 길(LEDGES)·길 쐐기(ROAD_WEDGES)로 바꿈
	local removed = 0
	for _, f in surface:GetChildren() do
		local rf = f.Name:match("^R_평원") and f.Name ~= "R_평원채움" and f:FindFirstChild("Ramps")
		for _, c in rf and rf:GetChildren() or {} do
			c:Destroy()
			removed += 1
		end
	end
	say("옛 오르막 걷음 %d", removed)
	local liftables, lifters = {}, {}
	for _, f in surface:GetChildren() do
		if f.Name:match("^R_평원") and f.Name ~= "R_평원채움" then
			for _, sub in { "Trees", "Rocks", "Masses", "Ramps", "Ruins" } do
				local x = f:FindFirstChild(sub)
				if x then
					for _, item in x:GetChildren() do
						table.insert(if sub == "Trees" or sub == "Rocks" then liftables else lifters, item)
					end
				end
			end
		end
	end
	local function shift(inst, dy)
		if inst:IsA("Model") then
			inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0))
		else
			inst.CFrame += Vector3.new(0, dy, 0)
		end
	end
	for _, list in { liftables, lifters } do
		for _, item in list do
			local d = item:GetAttribute("FillLift")
			if d then
				shift(item, -d)
				item:SetAttribute("FillLift", nil)
			end
		end
	end
	local old = surface:FindFirstChild("R_평원채움")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_평원채움"
	root.Parent = surface
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	local function centerOf(item)
		return if item:IsA("Model") then item:GetBoundingBox().Position else item.Position
	end

	-- 옛 지형 땅 높이(이번 단·언덕 짓기 전) — 나무·바위를 얼마나 올릴지 잰다
	local baseHit = {}
	for _, f in surface:GetChildren() do
		if f ~= root and f.Name:match("^R_평원") then
			for _, sub in { "Land", "Cliffs", "Masses", "Ramps", "Sand" } do
				local x = f:FindFirstChild(sub)
				if x then
					table.insert(baseHit, x)
				end
			end
		end
	end
	local baseRay = RaycastParams.new()
	baseRay.FilterType = Enum.RaycastFilterType.Include
	baseRay.FilterDescendantsInstances = baseHit
	local baseY = {}
	for _, item in liftables do
		local p = centerOf(item)
		local a = workspace:Raycast(Vector3.new(p.X, 300, p.Z), Vector3.new(0, -400, 0), baseRay)
		baseY[item] = if a then a.Position.Y else TOP
	end

	-- 0. 땅 판 높낮이: 단(바위 옆 + 풀 윗면). 한 점의 단 높이 = 그 점을 덮는 단 중 가장 높은 것
	local plateaus = folder("Plateaus")
	for i, pl in PLATEAUS do
		block(string.format("%s_%d", pl[1], i), pl[2], pl[3], pl[4], pl[5], TOP + pl[6], TOP - 4, plateaus, if i % 2 == 0 then ROCK2 else ROCK)
	end
	local function plateauAt(x, z)
		local h = 0
		for _, pl in PLATEAUS do
			if pl[2] <= x and x <= pl[3] and pl[4] <= z and z <= pl[5] then
				h = math.max(h, pl[6])
			end
		end
		return h
	end
	-- 단 안의 옛 덩어리·오르막·잔해를 단 높이만큼 올린다(검사가 걸침 없음을 보장)
	local raised = 0
	for _, item in lifters do
		local p = centerOf(item)
		local dy = plateauAt(p.X, p.Z)
		if dy > 0 then
			shift(item, dy)
			item:SetAttribute("FillLift", dy)
			raised += 1
		end
	end

	-- 1. 언덕(같은 이름 켜는 아래 켜 윗면 2 아래에서, 첫 켜는 땅에 4 묻힌다). 첫 켜가 단 위면 단 높이를 얹는다
	local masses = folder("Masses")
	local tierTop, lift = {}, {}
	for i, m in MASSES do
		local name = m[1]
		if lift[name] == nil then
			lift[name] = plateauAt((m[2] + m[3]) / 2, (m[4] + m[5]) / 2)
		end
		local bottom = if tierTop[name] then tierTop[name] - 2 else TOP - 4
		tierTop[name] = TOP + m[6] + lift[name]
		block(string.format("%s_%d", name, i), m[2], m[3], m[4], m[5], tierTop[name], bottom, masses, if i % 2 == 0 then ROCK2 else ROCK)
	end
	-- 2. 오르막 쐐기(WedgePart 는 로컬 +Z 쪽이 높다)
	local ramps = folder("Ramps")
	for i, r in RAMPS do
		local x, zl, zh, w, y0, y1 = r[1], r[2], r[3], r[4], TOP + r[5], TOP + r[6]
		local base = y0 - 2
		local up = if zh < zl then -1 else 1
		local len = math.abs(zh - zl) + 3
		local cz = (zl + zh) / 2 + up * 1.5
		local wp = Instance.new("WedgePart")
		wp.Name = "Ramp" .. i
		wp.Anchored = true
		wp.Size = Vector3.new(w, y1 - base, len)
		wp.CFrame = CFrame.new(x, base + (y1 - base) / 2, cz) * CFrame.Angles(0, if up < 0 then math.pi else 0, 0)
		wp.Color, wp.Material = GRASS, M.Grass
		wp.Parent = ramps
	end
	-- 3. 못(돌 테두리 + 물 판)
	local ponds = folder("Ponds")
	for i, p in PONDS do
		local x0, z0, x1, z1 = p[1], p[2], p[3], p[4]
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local water = part("Pond" .. i, Vector3.new(x1 - x0, 0.5, z1 - z0), CFrame.new(cx, TOP + 0.05, cz), RGB(70, 112, 128), M.Glass, ponds)
		water.Transparency = 0.15
		part("Pond" .. i .. "_바닥", Vector3.new(x1 - x0, 0.2, z1 - z0), CFrame.new(cx, TOP - 0.15, cz), RGB(52, 70, 60), M.Mud, ponds)
		local w = 2.2
		part("Pond" .. i .. "_N", Vector3.new(x1 - x0 + 2 * w, 1.0, w), CFrame.new(cx, TOP + 0.4, z0 - w / 2), STONE, M.Cobblestone, ponds)
		part("Pond" .. i .. "_S", Vector3.new(x1 - x0 + 2 * w, 1.0, w), CFrame.new(cx, TOP + 0.4, z1 + w / 2), STONE2, M.Cobblestone, ponds)
		part("Pond" .. i .. "_W", Vector3.new(w, 1.0, z1 - z0), CFrame.new(x0 - w / 2, TOP + 0.4, cz), STONE2, M.Cobblestone, ponds)
		part("Pond" .. i .. "_E", Vector3.new(w, 1.0, z1 - z0), CFrame.new(x1 + w / 2, TOP + 0.4, cz), STONE, M.Cobblestone, ponds)
	end
	-- 4. 텃밭(두둑은 x 방향)
	local gardens = folder("Gardens")
	for gi, g in GARDENS do
		local fx0, fz0, fx1, fz1 = g[1], g[2], g[3], g[4]
		part(string.format("Garden%d", gi), Vector3.new(fx1 - fx0, 0.5, fz1 - fz0), CFrame.new((fx0 + fx1) / 2, TOP + 0.2, (fz0 + fz1) / 2), SOIL, M.Ground, gardens)
		-- 두둑마다 절화 작물 줄(10 길이 틀을 x 로 눕혀 이어 붙임) — 텃밭마다 작물 하나
		local crops = { "Crop_Cabbage", "Crop_Pepper", "Crop_Radish", "Crop_Bean", "Crop_Barley" }
		local props = SS:FindFirstChild("JeolhwaProps")
		local crop = props and props:FindFirstChild(crops[(gi - 1) % #crops + 1])
		local z, k = fz0 + 2, 0
		while z < fz1 - 1.5 do
			k += 1
			local len = fx1 - fx0 - 3
			part(string.format("Garden%d_Ridge%d", gi, k), Vector3.new(len, 0.9, 1.6), CFrame.new((fx0 + fx1) / 2, TOP + 0.7, z), RIDGE, M.Ground, gardens)
			if crop then
				local n = math.floor(len / 10)
				for c = 0, n - 1 do
					local m = crop:Clone()
					m:PivotTo(CFrame.new(fx0 + 1.5 + 5 + c * 10 + (len - n * 10) / 2, 0, z) * CFrame.Angles(0, math.rad(90), 0))
					local cf, size = m:GetBoundingBox()
					m:PivotTo(m:GetPivot() + Vector3.new(0, TOP + 1.1 - (cf.Y - size.Y / 2), 0))
					m.Parent = gardens
				end
			end
			z += 3.4
		end
	end

	-- 땅 높이: 평원 지형(땅·덩어리·오르막·모래·절벽, 단 안 것은 올린 뒤) + 이번 단·언덕·오르막·못 물
	local hit: { Instance } = { plateaus, masses, ramps, ponds }
	for _, h in baseHit do
		table.insert(hit, h)
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = hit
	local function groundY(x, z)
		local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), ray)
		return if r then r.Position.Y else TOP
	end
	-- 단·언덕 안에 든 나무·바위를 새 땅 윗면으로 들어 올린다(짓기 전에 잰 땅 → 지은 뒤 땅 차이)
	local lifted = 0
	for _, item in liftables do
		local p = centerOf(item)
		local dy = groundY(p.X, p.Z) - baseY[item]
		if dy > 0.05 then
			shift(item, dy)
			item:SetAttribute("FillLift", dy)
			lifted += 1
		end
	end
	say("단 %d · 단 따라 올린 옛 덩어리·오르막·잔해 %d · 언덕·단 위로 올린 나무·바위 %d", #PLATEAUS, raised, lifted)

	-- 물건 밑면을 (x, z) 의 땅 + dy 에 앉힌다(경계 상자 가운데를 x, z 에)
	local function seat(m, x, z, yaw, dy)
		m:PivotTo(CFrame.Angles(0, math.rad(yaw), 0) + m:GetPivot().Position)
		local cf, size = m:GetBoundingBox()
		local y = groundY(x, z)
		m:PivotTo(m:GetPivot() + Vector3.new(x - cf.X, (y + dy) - (cf.Y - size.Y / 2), z - cf.Z))
		return y
	end

	-- 5. 키트 물건
	local kits = folder("Kits")
	local missing = 0
	for i, k in KITS do
		local name, x, z, yaw, sc, src = k[1], k[2], k[3], k[4], k[5], k[6]
		local kit = SS:FindFirstChild(src)
		local tmpl = kit and kit:FindFirstChild(name)
		if not tmpl then
			say("틀 없음 %s/%s", src, name)
			missing += 1
			continue
		end
		local m = tmpl:Clone()
		if not m:IsA("Model") then
			local wrap = Instance.new("Model")
			m.Parent = wrap
			wrap.PrimaryPart = m
			m = wrap
		end
		m.Name = string.format("%s_%d", name, i)
		if sc ~= 1 then
			m:ScaleTo(sc)
		end
		-- 집·정자는 밑을 0.2 묻고, 배는 모래 위, 갈대·연잎은 물 판 위
		seat(m, x, z, yaw, if name == "LilyPads" then 0.02 else -0.2)
		m.Parent = kits
	end
	-- 6. 나무(절화 나무 모델을 돌아가며 복제 — Plains_Build 와 같은 방식, 밑동 3 묻기)
	local trees = folder("Trees")
	local srcTrees = {}
	for _, t in workspace.Jeolhwa["나무"]:GetChildren() do
		if t:IsA("Model") then
			table.insert(srcTrees, t)
		end
	end
	table.sort(srcTrees, function(a, b)
		return a.Name < b.Name
	end)
	assert(#srcTrees > 0, "절화 나무 모델이 없다")
	for i, t in TREES do
		local m = srcTrees[(i * 5) % #srcTrees + 1]:Clone()
		m.Name = "Tree_F" .. i
		if t[4] ~= 1 then
			m:ScaleTo(t[4])
		end
		seat(m, t[1], t[2], t[3], -3.0)
		m.Parent = trees
	end
	-- 7. 바위
	local rocks = folder("Rocks")
	for i, r in ROCKS do
		local y = groundY(r[1], r[2])
		part("Rock" .. i, Vector3.new(r[3], r[4], r[5]), CFrame.new(r[1], y + r[4] / 2 - 0.5, r[2]) * CFrame.Angles(0, math.rad(r[6]), 0), if i % 2 == 0 then ROCK2 else ROCK, M.Slate, rocks)
	end
	-- 8. 돌길(직각으로 꺾임)
	local paths = folder("Paths")
	for pi, pth in PATHS do
		local w, pts = pth[1], pth[2]
		for i = 1, #pts - 1 do
			local a = Vector3.new(pts[i][1], TOP + 0.17 + i * 0.01, pts[i][2])
			local b = Vector3.new(pts[i + 1][1], TOP + 0.17 + i * 0.01, pts[i + 1][2])
			local len = (b - a).Magnitude + w
			part(string.format("Path%d_%d", pi, i), Vector3.new(w, 0.4, len), CFrame.lookAt((a + b) / 2, b), if i % 2 == 0 then STONE2 else STONE, M.Cobblestone, paths)
		end
	end

	-- 9. 랜드마크(Part)
	local marks = folder("Marks")
	for i, mk in MARKS do
		local kind, x, z, yaw = mk[1], mk[2], mk[3], mk[4]
		local y = groundY(x, z)
		local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local g = Instance.new("Model")
		g.Name = string.format("%s_%d", kind, i)
		g.Parent = marks
		local function at(name, size, ox, oy, oz, color, mat, ry)
			return part(name, size, base * CFrame.new(ox, oy, oz) * CFrame.Angles(0, math.rad(ry or 0), 0), color, mat, g)
		end
		if kind == "Beacon" then
			-- 봉수대: 돌 대(26×4×26) 위에 연조 다섯(한 줄), 가운데 연조에 불. 남쪽(오르막 쪽)에 돌계단
			at("대", Vector3.new(26, 4.6, 26), 0, 1.7, 0, ROCK, M.Slate)
			at("대_윗돌", Vector3.new(26.6, 0.6, 26.6), 0, 4.3, 0, STONE, M.Cobblestone)
			for s = 1, 3 do
				at("계단" .. s, Vector3.new(8, 1.4 * s, 2.2), 0, 0.7 * s - 0.3, 13 + 2.2 * (4 - s) - 1.1, STONE2, M.Cobblestone)
			end
			for c = -2, 2 do
				local ox = c * 4.8
				at("연조" .. (c + 3), Vector3.new(3.4, 7, 3.4), ox, 4.6 + 3.5, -4, RGB(146, 112, 92), M.Brick)
				at("연조" .. (c + 3) .. "_갓", Vector3.new(4.2, 0.7, 4.2), ox, 4.6 + 7.35, -4, RGB(70, 64, 60), M.Slate)
				at("연조" .. (c + 3) .. "_그을음", Vector3.new(2.2, 0.3, 2.2), ox, 4.6 + 7.8, -4, RGB(30, 28, 26), M.Slate)
			end
			local ember = at("불씨", Vector3.new(2, 0.8, 2), 0, 4.6 + 8.2, -4, RGB(255, 140, 50), M.Neon)
			local fire = Instance.new("Fire")
			fire.Size, fire.Heat = 6, 9
			fire.Parent = ember
			local smoke = Instance.new("Smoke")
			smoke.Size, smoke.RiseVelocity, smoke.Opacity = 3, 5, 0.25
			smoke.Color = RGB(90, 86, 82)
			smoke.Parent = ember
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color = 24, 1.4, RGB(255, 160, 80)
			light.Parent = ember
		elseif kind == "Seonang" then
			-- 서낭당: 돌무더기 세 켜 + 오색 천 매단 장대
			at("돌1", Vector3.new(7.5, 2.4, 7.5), 0, 1.0, 0, ROCK, M.Slate)
			at("돌2", Vector3.new(5.6, 2.0, 5.6), 0, 3.0, 0, ROCK2, M.Slate, 30)
			at("돌3", Vector3.new(3.8, 1.8, 3.8), 0, 4.8, 0, ROCK, M.Slate, 15)
			at("돌4", Vector3.new(2.0, 1.4, 2.0), 0, 6.3, 0, ROCK2, M.Slate, 40)
			at("장대", Vector3.new(0.5, 11, 0.5), 4.4, 5.3, 2.4, WOOD, M.Wood)
			local cloth = { RGB(196, 52, 44), RGB(40, 74, 160), RGB(224, 182, 52), RGB(236, 232, 220), RGB(62, 132, 64) }
			for c, col in cloth do
				at("천" .. c, Vector3.new(0.12, 2.6, 0.7), 4.4, 9.4 - c * 0.35, 2.4 + (c - 3) * 0.12, col, M.Fabric, c * 36)
			end
			at("금줄", Vector3.new(8.2, 0.3, 0.3), 0, 2.4, -3.9, RGB(200, 176, 120), M.Fabric)
		elseif kind == "Jangseung" then
			-- 장승: 나무 기둥 + 검은 관 + 얼굴(앞 = 로컬 -Z)
			at("기둥", Vector3.new(1.7, 9, 1.7), 0, 4.5, 0, WOOD, M.Wood)
			at("관_챙", Vector3.new(2.8, 0.4, 2.8), 0, 9.2, 0, RGB(34, 32, 30), M.SmoothPlastic)
			at("관", Vector3.new(1.7, 1.6, 1.7), 0, 10.2, 0, RGB(34, 32, 30), M.SmoothPlastic)
			at("눈썹", Vector3.new(1.4, 0.25, 0.2), 0, 8.3, -0.9, RGB(40, 30, 24), M.Wood)
			at("눈L", Vector3.new(0.35, 0.35, 0.2), -0.4, 7.8, -0.9, RGB(20, 18, 16), M.SmoothPlastic)
			at("눈R", Vector3.new(0.35, 0.35, 0.2), 0.4, 7.8, -0.9, RGB(20, 18, 16), M.SmoothPlastic)
			at("이", Vector3.new(1.0, 0.3, 0.2), 0, 6.7, -0.9, RGB(236, 230, 214), M.SmoothPlastic)
			at("글", Vector3.new(0.9, 3.6, 0.15), 0, 3.4, -0.9, RGB(170, 50, 40), M.SmoothPlastic)
		end
	end
	-- 오르는 길: 손 배치 턱(바위 옆 + 풀 윗면), 단 위면 단 높이를 얹는다 · 길 쐐기 · 턱 위 작은 돌 · 탑바위
	local ledgeF = folder("Ledges")
	for i, l in LEDGES do
		local off = plateauAt((l[1] + l[3]) / 2, (l[2] + l[4]) / 2)
		block(string.format("%s_턱%d", l[6], i), l[1], l[3], l[2], l[4], TOP + l[5] + off, TOP - 4, ledgeF, if i % 2 == 0 then ROCK2 else ROCK)
	end
	for i, r in ROAD_WEDGES do
		local x, zl, zh, w, y0, y1 = r[1], r[2], r[3], r[4], TOP + r[5], TOP + r[6]
		local base = y0 - 2
		local up = if zh < zl then -1 else 1
		local len = math.abs(zh - zl) + 3
		local cz = (zl + zh) / 2 + up * 1.5
		local wp = Instance.new("WedgePart")
		wp.Name = "RoadRamp" .. i
		wp.Anchored = true
		wp.Size = Vector3.new(w, y1 - base, len)
		wp.CFrame = CFrame.new(x, base + (y1 - base) / 2, cz) * CFrame.Angles(0, if up < 0 then math.pi else 0, 0)
		wp.Color, wp.Material = GRASS, M.Grass
		wp.Parent = ledgeF
	end
	local hit2 = { ledgeF }
	for _, h in hit do
		table.insert(hit2, h)
	end
	local ray2 = RaycastParams.new()
	ray2.FilterType = Enum.RaycastFilterType.Include
	ray2.FilterDescendantsInstances = hit2
	local function groundY2(x, z)
		local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), ray2)
		return if r then r.Position.Y else TOP
	end
	for i, st in LEDGE_STONES do
		local y = groundY2(st[1], st[2])
		part("턱돌" .. i, Vector3.new(st[3], st[3] * 0.8, st[3] * 0.9), CFrame.new(st[1], y + st[3] * 0.4 - 0.3, st[2]) * CFrame.Angles(0, math.rad(i * 37), 0), if i % 2 == 0 then ROCK else ROCK2, M.Slate, ledgeF)
	end
	local forms = folder("Formations")
	local CAP = RGB(150, 147, 139)
	for i, f in FORMATIONS do
		local y = groundY2(f[2], f[3])
		local bottom, topY = y - 2, y
		for k, L in f[4] do
			local cx, cz = f[2] + L[4], f[3] + L[5]
			topY = (if k == 1 then y else topY) + L[3]
			block(string.format("%s_%d", f[1], k), cx - L[1] / 2, cx + L[1] / 2, cz - L[2] / 2, cz + L[2] / 2, topY, bottom, forms, if k % 2 == 0 then ROCK2 else ROCK, CAP, M.Slate)
			bottom = topY - 0.6
		end
		for k, stn in f[5] do
			part(string.format("%s_돌%d", f[1], k), Vector3.new(stn[1], stn[2], stn[3]), CFrame.new(f[2] + stn[4], topY + stn[2] / 2 - 0.3, f[3] + stn[5]) * CFrame.Angles(0, math.rad(k * 41 + i * 13), 0), if k % 2 == 0 then ROCK else ROCK2, M.Slate, forms)
		end
	end
	-- 벽 밑 바위 기둥 줄(사막과 같은 방식): 기둥마다 두 켜(아래가 넓고 깊다), 이웃과 1 겹침. 땅 높이는 벽 바로 바깥에서 잰다
	local pillars = folder("WallPillars")
	local nPillar = 0
	for ri, run in WALL_RUNS do
		local axis, at, out, a0, a1, massTop, k = run[1], run[2], run[3], run[4], run[5], run[6], run[7]
		local dir = if a1 >= a0 then 1 else -1
		local mid = (a0 + a1) / 2
		local ix, iz = if axis == "x" then mid else at - out * 3, if axis == "x" then at - out * 3 else mid
		local topAbs = TOP + massTop + plateauAt(ix, iz) -- 단 위 덩어리는 단 높이만큼 올라가 있다
		local cursor = a0
		while (a1 - cursor) * dir > 2 do
			k = k % #PILLAR_BANK + 1
			local w, hf, d = PILLAR_BANK[k][1], PILLAR_BANK[k][2], PILLAR_BANK[k][3]
			w = math.min(w, math.abs(a1 - cursor) + 1)
			local s0, s1 = math.min(cursor, cursor + dir * w), math.max(cursor, cursor + dir * w)
			local fx, fz = if axis == "x" then (s0 + s1) / 2 else at + out * (d + 1), if axis == "x" then at + out * (d + 1) else (s0 + s1) / 2
			local gy = groundY2(fx, fz)
			local h = math.max(2, (topAbs - gy) * hf)
			for li, L in { { 0.55, 0, 0 }, { 1.0, 1.4, 1.3 } } do
				local ls0, ls1 = s0 + L[2] / 2, s1 - L[2] / 2
				local dd = d - L[3]
				local o0, o1 = at - out * 1, at + out * dd
				local bx0, bx1 = if axis == "x" then ls0 else math.min(o0, o1), if axis == "x" then ls1 else math.max(o0, o1)
				local bz0, bz1 = if axis == "x" then math.min(o0, o1) else ls0, if axis == "x" then math.max(o0, o1) else ls1
				local top = gy + h * L[1]
				local bottom = if li == 1 then gy - 4 else gy + h * 0.55 - 0.6
				block(string.format("Pillar%d_%d_%d", ri, k, li), bx0, bx1, bz0, bz1, top, bottom, pillars, if (k + li) % 2 == 0 then ROCK2 else ROCK, CAP, M.Slate)
				nPillar += 1
			end
			cursor += dir * (w - 1)
		end
	end
	say("벽 밑 바위 기둥 켜 %d", nPillar)
	say("턱 길 %d · 길 쐐기 %d · 턱 돌 %d · 탑바위 %d", #LEDGES, #ROAD_WEDGES, #LEDGE_STONES, #FORMATIONS)
	say("채움: 덩어리 %d, 오르막 %d, 못 %d, 텃밭 %d, 키트 %d(없음 %d), 나무 %d, 바위 %d, 길 %d, 랜드마크 %d",
		#MASSES, #RAMPS, #PONDS, #GARDENS, #KITS, missing, #TREES, #ROCKS, #PATHS, #MARKS)
	assert(missing == 0, "틀이 빠졌다")
end

local ok, err = pcall(build)
HS:PostAsync("http://127.0.0.1:34999/plainsfill", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
