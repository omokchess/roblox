--!nocheck
--[[
	Snow_City2.luau — 슈네라이히 2판 마을을 짓는다. (2026-10-09)

	1판(Snow_Town.luau)은 큰 마을 땅에 키운 건물 몇 채를 흩어 놓아 휑했다. 2판은 옛 도시(Snow_City.luau, 2026-09-26)의
	짓는 법을 그대로 쓴다: 집은 배율 1 로 빽빽이, 포장길·연석·맨홀, 쇠 받침 위 난방관·모음통·밸브·압력계·김, 가스등,
	도는 톱니, 계류탑 비행선, 체스판 연병장. 자리는 tools/snow_plan2.py(사용자 마을 그림 그대로, 손 표) → Snow_City2_data.luau.
	  python tools/snow_plan2.py && sed -e '/--@@DATA@@/r tools/Snow_City2_data.luau' -e '/--@@INSIDE@@/r tools/Snow_Inside_data.luau' 	    tools/Snow_City2.luau > tools/swamp/_city2_run.luau && bash tools/job.sh tools/swamp/_city2_run.luau
	  (Snow_Inside_data.luau 는 blender -b -P models/build_steam_town.py 가 키트 FBX 와 함께 뽑는다)

	Workspace.Schneereich.마을 만 지우고 새로 짓는다. SnowGearSpin·SnowPressRun 은 그대로 둔다.
	2026-10-10: 순간이동 안쪽 방을 없애고 건물 자체에 들어가게 했다(천문대·장비상점·공방·체스판 건물·폐허 — 3e 절).
	옛 방(안쪽방)과 SnowInteriors 는 처음 돌 때 ServerStorage(Snow_Rooms_Old·Snow_Interiors_Old)로 옮기고,
	움직이는 압착기는 Snow_PressTemplate 로 남겨 공방 안에 다시 놓는다. 땅은 Surface.R_설원3(평지 59.8). 보고: /snowcity2
]]
--@@DATA@@
--@@INSIDE@@
-- 도는 톱니. 클라이언트에서만 돈다(보기 전용). 태그 SnowGear 모델을 속성 Speed(도/초)대로
-- 서버 시간에 맞춰 돌려서 모든 사람에게 같은 각도로 보인다. 처음 각도는 서버 쪽 피벗에 들어 있다
local GEAR_SCRIPT = [==[
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local gears = {}
local function add(m)
	if m:IsA("Model") then
		gears[m] = { base = m:GetPivot(), speed = m:GetAttribute("Speed") or 0 }
	end
end
for _, m in CS:GetTagged("SnowGear") do
	add(m)
end
CS:GetInstanceAddedSignal("SnowGear"):Connect(add)
CS:GetInstanceRemovedSignal("SnowGear"):Connect(function(m)
	gears[m] = nil
end)
RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for m, g in gears do
		if m.Parent then
			m:PivotTo(g.base * CFrame.Angles(0, 0, math.rad((g.speed * t) % 360)))
		end
	end
end)
]==]

-- 천문대 망원경이 별을 따라간다(적도의 — 극축 하나만 돌리면 된다). 돔은 경통 끝 방위로 돌아 틈을 맞춘다.
-- 보기 전용이고 서버 시간에 맞춰 모두에게 같다. 값 = models/build_steam_obs.py (블렌더 (x,y,z) → 로블록스 로컬 (-x, z, y))
local OBS_SCRIPT = [==[
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local H = Vector3.new(0, 20.2284, -2.2981) -- 적위축이 극축과 만나는 점
local P = Vector3.new(0, 0.6428, -0.7660) -- 극축(위도 40도, 문 쪽)
local S0 = Vector3.new(0, 0.9397, -0.3420) -- 남중한 별 쪽
local APERTURE = Vector3.new(3.6, 34.922, -7.752) -- 처음 자세의 경통 끝(차양) 가운데
local PERIOD = 1200 -- 한 바퀴 20분. 실제 하늘(하루)보다 빨라 "조금씩" 도는 게 보인다
local DIST = 1400
local list = {}
local function newStar()
	local s = Instance.new("Part")
	s.Name = "ObservatoryStar"
	s.Shape = Enum.PartType.Ball
	s.Size = Vector3.new(14, 14, 14)
	s.Material = Enum.Material.Neon
	s.Color = Color3.fromRGB(225, 238, 255)
	s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
	local halo = s:Clone()
	halo.Name = "ObservatoryStarHalo"
	halo.Size = Vector3.new(46, 46, 46)
	halo.Transparency = 0.86
	halo.Parent = workspace
	s.Parent = workspace
	return s, halo
end
local function add(m)
	local dome, scope = m:FindFirstChild("Observatory_Dome"), m:FindFirstChild("Observatory_Scope")
	if dome and scope and not list[m] then
		local s, halo = newStar()
		list[m] = { base = m:GetPivot(), dome = dome, scope = scope, star = s, halo = halo }
	end
end
for _, m in CS:GetTagged("SnowObservatory") do
	add(m)
end
CS:GetInstanceAddedSignal("SnowObservatory"):Connect(add)
CS:GetInstanceRemovedSignal("SnowObservatory"):Connect(function(m)
	local o = list[m]
	if o then
		o.star:Destroy()
		o.halo:Destroy()
		list[m] = nil
	end
end)
RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	local ang = (t % PERIOD) / PERIOD * 2 * math.pi
	for m, o in list do
		if m.Parent then
			local rot = CFrame.fromAxisAngle(P, ang)
			local loc = CFrame.new(H) * rot * CFrame.new(-H)
			o.scope:PivotTo(o.base * loc)
			local ap = loc * APERTURE
			o.dome:PivotTo(o.base * CFrame.Angles(0, math.atan2(-ap.X, -ap.Z), 0))
			local pos = o.base * H + o.base:VectorToWorldSpace(rot:VectorToWorldSpace(S0)) * DIST
			o.star.Position = pos
			o.halo.Position = pos
			o.halo.Transparency = 0.84 + 0.05 * math.sin(t * 3.1)
		end
	end
end)
]==]

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
local C = {
	road = { RGB(112, 106, 98), M.Cobblestone },
	ramp = { RGB(92, 90, 88), M.Cobblestone },
	plaza = { RGB(104, 99, 94), M.Cobblestone },
	curb = { RGB(140, 139, 138), M.Concrete },
	found = { RGB(85, 86, 92), M.Slate },
	soot = { RGB(40, 38, 38), M.Slate },
	marble = { RGB(225, 225, 228), M.Marble },
	dark = { RGB(40, 40, 44), M.Slate },
	iron = { RGB(58, 60, 66), M.Metal },
	plate = { RGB(94, 98, 107), M.DiamondPlate },
	brass = { RGB(184, 145, 63), M.Metal },
	copper = { RGB(176, 106, 63), M.Metal },
}

local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("SnowKit"), "ServerStorage.SnowKit 이 없다")
	for _, e in ipairs(D.BUILD) do
		assert(kit:FindFirstChild(e[1]), e[1] .. " 틀이 없다")
	end
	assert(kit:FindFirstChild("Gas_Lamp") and kit:FindFirstChild("Airship"), "등이나 비행선 틀이 없다")

	local city = workspace:FindFirstChild("Schneereich")
	if not city then
		city = Instance.new("Folder")
		city.Name = "Schneereich"
		city.Parent = workspace
	end
	-- 옛 순간이동 안쪽 방은 들어가는 건물로 바뀌었다(2026-10-10). 움직이는 압착기는 틀로 남기고,
	-- 방과 순간이동 스크립트는 ServerStorage 로 보관한다(마을 서쪽 하늘에 떠 보이던 것)
	local rooms = city:FindFirstChild("안쪽방")
	if rooms then
		local press = rooms:FindFirstChild("Press_Moving", true)
		if press and not SS:FindFirstChild("Snow_PressTemplate") then
			local t = press:Clone()
			t.Name = "Snow_PressTemplate"
			t.Parent = SS
		end
		rooms.Name = "Snow_Rooms_Old"
		rooms.Parent = SS
	end
	local oldTp = game:GetService("ServerScriptService"):FindFirstChild("SnowInteriors")
	if oldTp then
		oldTp.Name = "Snow_Interiors_Old"
		oldTp.Disabled = true
		oldTp.Parent = SS
	end
	local KEEP = { SnowGearSpin = true, SnowPressRun = true }
	for _, c in ipairs(city:GetChildren()) do
		if not KEEP[c.Name] then
			c:Destroy()
		end
	end
	city:SetAttribute("Version", 2)
	local town = Instance.new("Folder")
	town.Name = "마을"
	town.Parent = city
	local function folder(path)
		local f = town
		for name in string.gmatch(path, "[^/]+") do
			local c = f:FindFirstChild(name)
			if not c then
				c = Instance.new("Folder")
				c.Name = name
				c.Parent = f
			end
			f = c
		end
		return f
	end
	local FStone = folder("돌")

	local G = assert(workspace.Surface:FindFirstChild("R_설원3"), "Surface.R_설원3(설원 땅)이 없다")
	-- 지난번 지하 카지노 땅 파기를 먼저 되돌린다(건물을 앉힐 때 땅 높이를 재는데, 구멍이 열려 있으면 굴 속까지 받침돌을 채운다).
	-- 다시 파는 일은 맨 끝(3f)에서
	do
		local land = assert(G:FindFirstChild("Land"), "R_설원3.Land 가 없다")
		local store = SS:FindFirstChild("Snow_LandOriginal")
		if not store then
			store = Instance.new("Folder")
			store.Name = "Snow_LandOriginal"
			store.Parent = SS
		end
		-- 되돌리기
		for _, orig in ipairs(store:GetChildren()) do
			local key = orig:GetAttribute("CarveKey")
			for _, p in ipairs(land:GetChildren()) do
				if p:GetAttribute("CarvedFrom") == key then
					p:Destroy()
				end
			end
			local back = orig:Clone()
			back:SetAttribute("CarveKey", nil)
			back.Parent = land
			orig:Destroy()
		end
	end
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local rpAll = RaycastParams.new()
	rpAll.FilterType = Enum.RaycastFilterType.Include
	rpAll.FilterDescendantsInstances = { G, FStone }
	local function groundY(x, z, rp)
		local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1800, 0), rp or rpAll)
		return h and h.Position.Y
	end

	local nParts = 0
	local function part(name, cf, size, col, parent, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = col[1]
		p.Material = col[2]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		nParts += 1
		return p
	end
	local function span(x0, z0, x1, z1, rp)
		local lo, hi = math.huge, -math.huge
		local nx, nz = math.max(2, math.ceil((x1 - x0) / 8)), math.max(2, math.ceil((z1 - z0) / 8))
		for i = 0, nx do
			for j = 0, nz do
				local gy = groundY(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz, rp)
				assert(gy, string.format("(%.0f,%.0f) 아래에 땅이 없다", x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return lo, hi
	end
	local function slab(name, x0, z0, x1, z1, top, col, parent)
		local lo = span(x0, z0, x1, z1, rpG)
		local bot = math.min(lo, top - 0.4) - 0.9
		return part(name, CFrame.new((x0 + x1) / 2, (top + bot) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, top - bot, z1 - z0), col, parent)
	end

	--==================================================================== 1. 포장
	for _, p in ipairs(D.PAVES) do
		local f = folder("돌/" .. p[1])
		if p[#p] == "disc" then
			local cx, cz, r, ck, lift = p[2], p[3], p[4], p[5], p[6]
			local lo, hi = span(cx - r, cz - r, cx + r, cz + r, rpG)
			local top, bot = hi + 0.3 + lift, lo - 0.9
			part("Plaza", CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(top - bot, 2 * r, 2 * r), C[ck], f, Enum.PartType.Cylinder)
			-- 연석은 둘레를 돌 토막으로 두른다(옛 도시처럼 원판 하나로 깔면 그 윗면이 광장 전체를 덮는다)
			local n = math.ceil(2 * math.pi * r / 4)
			for k = 0, n - 1 do
				local a = 2 * math.pi * k / n
				local q = Vector3.new(cx + math.cos(a) * (r - 0.45), top - 0.15, cz + math.sin(a) * (r - 0.45))
				part("Curb", CFrame.lookAt(q, q + Vector3.new(-math.sin(a), 0, math.cos(a))), Vector3.new(0.9, 0.6, 2 * math.pi * r / n + 0.25), C.curb, f)
			end
		elseif p[#p] == "playtri" then
			-- 직각삼각형 바닥: 쐐기 부품을 눕힌다. 쐐기 단면(로컬 YZ)의 직각 꼭짓점 = (y -h/2, z +L/2).
			-- 로컬 Y = z 쪽 다리, 로컬 -Z = x 쪽 다리, 로컬 X(두께) = 위
			local x0, z0, dx, dz = p[2], p[3], p[4], p[5]
			local Ly, Lz = math.abs(dz), math.abs(dx)
			local Y = Vector3.new(0, 0, dz > 0 and 1 or -1)
			local Zv = Vector3.new(dx > 0 and -1 or 1, 0, 0)
			local X = Y:Cross(Zv)
			local _, hi = span(math.min(x0, x0 + dx), math.min(z0, z0 + dz), math.max(x0, x0 + dx), math.max(z0, z0 + dz), rpG)
			local top, bot = hi + 0.2, hi - 0.9
			local c = Vector3.new(x0, (top + bot) / 2, z0) + Y * (Ly / 2) - Zv * (Lz / 2)
			local w = Instance.new("WedgePart")
			w.Name = "Pave"
			w.Anchored = true
			w.Size = Vector3.new(top - bot, Ly, Lz)
			w.CFrame = CFrame.fromMatrix(c, X, Y, Zv)
			w.Color, w.Material = RGB(118, 92, 70), M.Sand
			w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			w.Parent = f
			nParts += 1
		else
			local x0, z0, x1, z1, kind = p[2], p[3], p[4], p[5], p[6]
			local _, hi = span(x0, z0, x1, z1, rpG)
			if kind == "chess" then
				-- 연병장. 7 칸 체스판. 기물군(디 피구렌)의 이름값이다
				local T = 7
				local i = 0
				for x = x0, x1 - T + 0.01, T do
					local j = 0
					for z = z0, z1 - T + 0.01, T do
						slab(string.format("Tile_%d_%d", i, j), x, z, x + T, z + T, hi + 0.35, ((i + j) % 2 == 0) and C.dark or C.marble, f)
						j += 1
					end
					i += 1
				end
				-- 판 둘레 놋쇠 테
				for _, e in ipairs({ { x0 - 0.5, z0 - 0.5, x1 + 0.5, z0 }, { x0 - 0.5, z1, x1 + 0.5, z1 + 0.5 },
					{ x0 - 0.5, z0, x0, z1 }, { x1, z0, x1 + 0.5, z1 } }) do
					slab("Rim", e[1], e[2], e[3], e[4], hi + 0.45, C.brass, f)
				end
			else
				-- 앞마당(stone)은 돌 포장, 석탄·탄 마당(soot)은 그을음, 놀이터(play)는 나무껍질 깔개
				local col = ({ stone = C.plaza, soot = C.soot, play = { RGB(118, 92, 70), M.Sand } })[kind] or C.soot
				slab(kind == "soot" and "Soot" or "Pave", x0, z0, x1, z1, hi + 0.2, col, f)
			end
		end
	end
	task.wait()

	--==================================================================== 2. 길
	local roadLift = 0 -- 대로가 고리길을 덮도록 길마다 조금씩 높인다(같은 높이로 겹치면 깜빡인다)
	local function floorPiece(name, cx, cz, len, width, yaw, col, parent)
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ -0.5, 0, 0.5 }) do
			for _, v in ipairs({ -0.5, 0.5 }) do
				local wp = cf:PointToWorldSpace(Vector3.new(len * u, 0, width * v))
				local gy = groundY(wp.X, wp.Z, rpG)
				assert(gy, string.format("%s 자리 (%.0f,%.0f) 에 땅이 없다", name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local top, bot = hi + 0.3 + roadLift, lo - 0.9
		return part(name, CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0), Vector3.new(len, top - bot, width), col, parent)
	end
	-- 경사 길. 한 조각 10 을 넘지 않게 끊고, 각 끝 높이는 그 자리 폭 다섯 점 가운데 가장 높은 땅 + 0.4.
	-- 두 끝 사이 가운데가 땅보다 낮으면 두 끝을 같이 올린다
	local function rampRoad(name, width, pts, parent)
		local function hAt(p, dir)
			local perp = Vector3.new(-dir.Z, 0, dir.X)
			local hi = -math.huge
			for _, s in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
				local q = p + perp * (width * s)
				local gy = assert(groundY(q.X, q.Z, rpG), name .. " 밑에 땅이 없다")
				hi = math.max(hi, gy)
			end
			return hi + 0.4
		end
		local k = 0
		for i = 1, #pts - 1 do
			local A = Vector3.new(pts[i][1], 0, pts[i][2])
			local B = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
			local dir = (B - A).Unit
			local L = (B - A).Magnitude
			local n = math.max(1, math.ceil(L / 10))
			for s = 0, n - 1 do
				local p0 = A + (B - A) * (s / n)
				local p1 = A + (B - A) * ((s + 1) / n)
				local h0, h1 = hAt(p0, dir), hAt(p1, dir)
				local hm = hAt((p0 + p1) / 2, dir)
				local lift = math.max(0, hm - (h0 + h1) / 2)
				h0, h1 = h0 + lift, h1 + lift
				local a, b = Vector3.new(p0.X, h0, p0.Z), Vector3.new(p1.X, h1, p1.Z)
				local cf = CFrame.lookAt((a + b) / 2, b)
				k += 1
				-- 윗면이 두 끝을 잇는 선에 오게 판 두께 반만큼 내린다. 아래로 두껍게 해 계단 틈을 가린다
				part(string.format("Ramp_%d", k), cf * CFrame.new(0, -1.6, 0), Vector3.new(width, 3.2, (b - a).Magnitude + 0.6), C.ramp, parent)
			end
		end
	end
	for _, r in ipairs(D.ROADS) do
		local name, width, kind, pts = r[1], r[2], r[3], r[4]
		roadLift = r[5] or 0
		local f = folder("길/" .. name)
		if kind == "ramp" then
			rampRoad(name, width, pts, f)
		else
			for i = 1, #pts - 1 do
				local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
				local n = math.max(1, math.ceil(len / 40))
				for k = 1, n do
					local t = (k - 0.5) / n
					local rp_ = floorPiece(string.format("Road_%d_%d", i, k), ax + (bx - ax) * t, az + (bz - az) * t, len / n + 1, width, yaw, C.road, f)
					if width >= 18 then
						-- 대로 연석. 길 가장자리를 밝은 돌로 한 줄 둘러 길이 고원 바위와 갈라 보이게 한다
						for _, sd in ipairs({ -1, 1 }) do
							part("Curb", rp_.CFrame * CFrame.new(0, rp_.Size.Y / 2 + 0.15, sd * (width / 2 - 0.45)), Vector3.new(rp_.Size.X, 0.3, 0.9), C.curb, f)
						end
					end
				end
				if i > 1 then
					local gy = groundY(ax, az, rpG)
					part("Joint_" .. i, CFrame.new(ax, gy + 0.28 + roadLift - 0.6, az) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.2, width, width), C.road, f, Enum.PartType.Cylinder)
				end
			end
		end
	end
	task.wait()

	--==================================================================== 3. 건물
	local placed = {}
	local foundations, maxGap = 0, 0
	local function place(kind, x, z, yaw, parent, sc)
		local m = kit[kind]:Clone()
		sc = sc or 1
		if sc ~= 1 then
			m:ScaleTo(sc)
		end
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		local frame = m:GetPivot()
		local minY = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				if c.Y - e.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - e.X), math.max(x1, c.X + e.X)
					z0, z1 = math.min(z0, c.Z - e.Z), math.max(z1, c.Z + e.Z)
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s (%.0f,%.0f) 발자국 (%.0f,%.0f) 아래에 땅이 없다", kind, x, z, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - (frame.Y + minY), 0))
		if hi - lo > 0.25 then
			local f = Instance.new("Part")
			f.Name = "Foundation"
			f.Anchored = true
			f.Size = Vector3.new(x1 - x0 + 1.0, hi - lo + 1.0, z1 - z0 + 1.0)
			f.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))) * frame.Rotation
				+ Vector3.new(0, (lo - 1.0 + hi) / 2 - frame.Y, 0)
			f.Color = C.found[1]
			f.Material = C.found[2]
			f.TopSurface = Enum.SurfaceType.Smooth
			f.BottomSurface = Enum.SurfaceType.Smooth
			f.Parent = m
			foundations += 1
			maxGap = math.max(maxGap, hi - lo)
		end
		placed[#placed + 1] = { m = m, kind = kind, sc = sc }
		return m
	end

	for i, e in ipairs(D.BUILD) do
		local m = place(e[1], e[2], e[3], e[4], folder(e[5]), e[7])
		m.Name = e[1]
		if i % 6 == 0 then
			task.wait()
		end
	end
	for i, l in ipairs(D.LAMPS) do
		local m = place("Gas_Lamp", l[1], l[2], l[3], folder("가스등"))
		m.Name = "Gas_Lamp_" .. i
	end
	-- 비행선. 계류탑 팔 끝에 코를 대고 떠 있다. 땅에 앉히지 않는다
	do
		local mast
		for _, e in ipairs(placed) do
			if e.kind == "Mooring_Mast" then
				mast = e.m
			end
		end
		assert(mast, "계류탑이 없다")
		local a = D.AIRSHIP
		local ship = kit.Airship:Clone()
		ship:PivotTo(CFrame.new(a[1], mast:GetPivot().Y + a[4], a[2]) * CFrame.Angles(0, math.rad(a[3]), 0))
		ship.Name = "Airship"
		ship.Parent = folder("계류탑")
	end
	task.wait()

	--==================================================================== 3d. 천문대(들어가는 건물) · 놀이터 · 얼어붙은 연못
	-- 천문대 틀(build_steam_obs.py)은 블렌더 좌표 (x, y, z) → 로블록스 로컬 (-x, z, y). 아래 B() 가 그 바꿈이다.
	-- 보이는 메시는 부딪히지 않게 하고(둥근 벽 메시 충돌은 문 자리를 막을 수 있다), 걸을 자리는 여기서 상자로 짓는다:
	-- 받침·바닥·문 앞 계단·벽 고리(문 자리 비움)·피어·탁자·책상·책장. 회랑·나선 계단·난간은 보이는 부품 그대로 밟는다.
	local CSo = game:GetService("CollectionService")
	do
		local obs
		for _, e in ipairs(placed) do
			if e.kind == "Observatory" then
				obs = e.m
			end
		end
		assert(obs, "천문대가 없다")
		local pv = obs:GetPivot()
		local function B(bx, by, bz)
			return pv * CFrame.new(-bx, bz, by)
		end
		for _, p in ipairs(obs:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
		for _, name in ipairs({ "Observatory_Dome", "Observatory_Scope", "Orrery_A", "Orrery_B", "Orrery_C", "Orrery_D" }) do
			local c = assert(kit:FindFirstChild(name), name .. " 틀이 없다"):Clone()
			c:PivotTo(pv)
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
				end
			end
			c.Parent = obs
			local speed = ({ Orrery_A = 24, Orrery_B = 15, Orrery_C = 9, Orrery_D = 5 })[name]
			if speed then
				-- 태양계 모형 팔: 탁자 가운데 수직축 둘레(SnowGearSpin 은 피벗의 로컬 Z 둘레로 돌린다)
				c.WorldPivot = B(-10, 5, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
				c:SetAttribute("Speed", speed)
				CSo:AddTag(c, "SnowGear")
			end
		end
		CSo:AddTag(obs, "SnowObservatory")
		local fc = Instance.new("Folder")
		fc.Name = "충돌"
		fc.Parent = obs
		local function coll(name, cf, size, shape)
			local p = part(name, cf, size, C.found, fc, shape)
			p.Transparency = 1
			p.CastShadow = false
			return p
		end
		local CYL = Enum.PartType.Cylinder
		coll("Plinth", B(0, 0, 0.85) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.7, 52, 52), CYL)
		coll("Floor", B(0, 0, 1.85) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 41, 41), CYL)
		coll("StepA", B(0, -26.2, 0.565), Vector3.new(12, 1.13, 2.4))
		coll("StepB", B(0, -28.0, 0.285), Vector3.new(12, 0.57, 1.4))
		for k = 0, 39 do
			local a = 9 * k + 4.5
			local d = ((a - (-90) + 180) % 360) - 180
			if math.abs(d) > 13.5 then
				local r = math.rad(a)
				local c0 = B(21.5 * math.cos(r), 21.5 * math.sin(r), 1.7 + 11.15)
				local c1 = B(30 * math.cos(r), 30 * math.sin(r), 1.7 + 11.15)
				coll("Wall", CFrame.lookAt(c0.Position, c1.Position), Vector3.new(3.8, 22.3, 2.4))
			end
		end
		coll("Pier", B(0, 0, 9.0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(14, 4.2, 4.2), CYL)
		coll("OrreryTable", B(-10, 5, 3.9) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(3.8, 7.2, 7.2), CYL)
		coll("Desk", B(-13.2, -6.8, 3.6) * CFrame.Angles(0, math.rad(35), 0), Vector3.new(5.2, 3.2, 2.6))
		for k = 0, 3 do
			local a = math.rad(140 + 65 * (k + 0.5) / 4)
			local c0 = B(19.6 * math.cos(a), 19.6 * math.sin(a), 6.5)
			local c1 = B(30 * math.cos(a), 30 * math.sin(a), 6.5)
			coll("Shelf", CFrame.lookAt(c0.Position, c1.Position), Vector3.new(5.6, 9, 1.8))
		end
		-- 회랑(높이 14, 30 → 300 도, 계단 자리 비움) + 아래 받침살 + 안쪽 난간
		local fg = Instance.new("Folder")
		fg.Name = "회랑"
		fg.Parent = obs
		local WOOD = { RGB(90, 62, 44), M.WoodPlanks }
		local function radial(a_deg, r, z)
			local a = math.rad(a_deg)
			return B(r * math.cos(a), r * math.sin(a), z).Position
		end
		local function boxAt(name, a_deg, r, z, tang, h, rad_, col, f)
			local c0 = radial(a_deg, r, z)
			local c1 = radial(a_deg, r + 10, z)
			return part(name, CFrame.lookAt(c0, c1), Vector3.new(tang, h, rad_), col, f)
		end
		local nseg = 45
		for k = 0, nseg - 1 do
			local am = 30 + 6 * k + 3
			boxAt("Gallery", am, 17.95, 14.0 - 0.3 + (k % 2) * 0.01, 2.25, 0.6, 4.8, WOOD, fg)
			if k % 4 == 1 then
				local p0, p1 = radial(am, 20.3, 11.2), radial(am, 16.6, 13.4)
				part("Strut", CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.35, 0.35, (p1 - p0).Magnitude), C.iron, fg)
			end
		end
		local function rail(p0, p1, f)
			part("Rail", CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.2, 0.2, (p1 - p0).Magnitude + 0.15), C.iron, f)
		end
		local prev
		local angs = {}
		for a = 30, 294, 12 do
			angs[#angs + 1] = a
		end
		angs[#angs + 1] = 300
		for _, a in ipairs(angs) do
			local base = radial(a, 15.75, 14.0)
			part("RailPost", CFrame.new(base + Vector3.new(0, 1.6, 0)), Vector3.new(0.25, 3.2, 0.25), C.iron, fg)
			part("RailCap", CFrame.new(base + Vector3.new(0, 3.3, 0)), Vector3.new(0.4, 0.4, 0.4), C.brass, fg, Enum.PartType.Ball)
			if prev then
				rail(prev + Vector3.new(0, 3.1, 0), base + Vector3.new(0, 3.1, 0), fg)
				rail(prev + Vector3.new(0, 1.6, 0), base + Vector3.new(0, 1.6, 0), fg)
			end
			prev = base
		end
		-- 회랑 끝(300 도, 계단 시작 위) 가로 난간
		rail(radial(300, 15.75, 17.1), radial(300, 20.3, 17.1), fg)
		rail(radial(300, 15.75, 15.6), radial(300, 20.3, 15.6), fg)
		-- 나선 계단(벽 따라 -60 → 30 도, 15 단, 단 높이 0.8) + 안쪽 손잡이
		local prevTop
		for k = 0, 14 do
			local am = -60 + 6 * k + 3
			local top = 2.0 + 0.8 * (k + 1)
			boxAt("Step", am, 18.48, top - 0.25, 2.45, 0.5, 3.75, WOOD, fg)
			local s0, s1 = radial(am, 20.3, top - 1.2), radial(am, 17.0, top - 0.55)
			part("StepBracket", CFrame.lookAt((s0 + s1) / 2, s1), Vector3.new(0.3, 0.3, (s1 - s0).Magnitude), C.iron, fg)
			local hp = radial(am, 16.85, top)
			part("HandPost", CFrame.new(hp + Vector3.new(0, 1.5, 0)), Vector3.new(0.22, 3.0, 0.22), C.iron, fg)
			if prevTop then
				rail(prevTop + Vector3.new(0, 3.0, 0), hp + Vector3.new(0, 3.0, 0), fg)
			end
			prevTop = hp
		end
		-- 조율자 전직 자리(책상 앞). NPC 를 세울 때 쓴다
		local spot = part("ClassChangeSpot", B(-10.5, -4.0, 2.0 + 2.5), Vector3.new(2, 5, 2), C.iron, obs)
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		spot:SetAttribute("ClassChange", "조율자")
		say("천문대: 충돌 %d · 회랑·계단 부품 %d", #fc:GetChildren(), #fg:GetChildren())
	end
	-- 놀이터 회전 놀이기구: 받침 위에 판을 얹고 돌린다
	for _, e in ipairs(placed) do
		if e.kind == "Play_RoundBase" then
			local r = kit.Play_Round:Clone()
			if e.sc ~= 1 then
				r:ScaleTo(e.sc)
			end
			r:PivotTo(e.m:GetPivot())
			r.WorldPivot = e.m:GetPivot() * CFrame.Angles(-math.pi / 2, 0, 0)
			r:SetAttribute("Speed", 14)
			CSo:AddTag(r, "SnowGear")
			r.Parent = e.m.Parent
		end
	end
	-- 놀이터 울타리(무쇠 기둥 + 가로대 둘 + 살, 기둥 끝 놋쇠 구슬)
	do
		local f = folder("놀이터/울타리")
		for _, pl in ipairs(D.FENCES) do
			for k = 1, #pl - 1 do
				local a = Vector3.new(pl[k][1], 0, pl[k][2])
				local b = Vector3.new(pl[k + 1][1], 0, pl[k + 1][2])
				local Lg = (b - a).Magnitude
				local n = math.max(1, math.ceil(Lg / 3))
				local ga = groundY(a.X, a.Z, rpG)
				local gb = groundY(b.X, b.Z, rpG)
				for j = (k == 1) and 0 or 1, n do
					local p = a + (b - a) * (j / n)
					local gy = ga + (gb - ga) * (j / n)
					part("Post", CFrame.new(p.X, gy + 1.5, p.Z), Vector3.new(0.3, 3.0, 0.3), C.iron, f)
					part("Finial", CFrame.new(p.X, gy + 3.15, p.Z), Vector3.new(0.45, 0.45, 0.45), C.brass, f, Enum.PartType.Ball)
				end
				local m = math.floor(Lg / 1.0)
				for j = 1, m - 1 do
					local t = j / m
					local p = a + (b - a) * t
					local gy = ga + (gb - ga) * t
					part("Picket", CFrame.new(p.X, gy + 1.45, p.Z), Vector3.new(0.12, 2.5, 0.12), C.iron, f)
				end
				for _, h in ipairs({ 0.6, 2.6 }) do
					local p0 = Vector3.new(a.X, ga + h, a.Z)
					local p1 = Vector3.new(b.X, gb + h, b.Z)
					part("Rail", CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.16, 0.2, Lg), C.iron, f)
				end
			end
		end
	end
	-- 얼어붙은 분수 웅덩이: 얼음 원판(미끄러운 Ice) + 둘레 돌 벽·돌기둥 + 불 피운 쇠 통
	do
		local f = folder("연못")
		local ICE = { RGB(128, 182, 222), M.Ice }
		local SNOW = { RGB(238, 243, 247), M.Snow }
		for i, d in ipairs(D.POND) do
			local x, z, r, h = d[1], d[2], d[3], d[4]
			local _, hi = span(x - r, z - r, x + r, z + r, rpG)
			local ice = part("Ice_" .. i, CFrame.new(x, hi + h - 0.25, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 2 * r, 2 * r), ICE, f, Enum.PartType.Cylinder)
			ice.Reflectance = 0.12
		end
		-- 분수 웅덩이 벽: 원판을 합친 테두리 호를 짧은 토막(≤2.4)으로. 몸(슬레이트) + 갓돌(밝은 돌) + 눈
		local STONE = { RGB(96, 96, 102), M.Slate }
		local nWall = 0
		for _, w in ipairs(D.BASIN) do
			local cx, cz, rr, a0, a1 = w[1], w[2], w[3], w[4], w[5]
			local n = math.max(1, math.ceil(math.rad(a1 - a0) * rr / 2.4))
			for k = 0, n - 1 do
				local t0, t1 = math.rad(a0 + (a1 - a0) * k / n), math.rad(a0 + (a1 - a0) * (k + 1) / n)
				local p0 = Vector3.new(cx + rr * math.cos(t0), 0, cz + rr * math.sin(t0))
				local p1 = Vector3.new(cx + rr * math.cos(t1), 0, cz + rr * math.sin(t1))
				local mid = (p0 + p1) / 2
				local gy = groundY(mid.X, mid.Z, rpG)
				local L = (p1 - p0).Magnitude + 0.2
				local cf = CFrame.lookAt(Vector3.new(mid.X, gy, mid.Z), Vector3.new(p1.X, gy, p1.Z))
				part("BasinWall", cf * CFrame.new(0, 0.9 - 0.3, 0), Vector3.new(1.2, 2.4, L), STONE, f)
				part("BasinCap", cf * CFrame.new(0, 2.05, 0), Vector3.new(1.8, 0.3, L + 0.1), C.curb, f)
				part("BasinSnow", cf * CFrame.new(0, 2.27, 0), Vector3.new(1.3, 0.14, L), SNOW, f)
				nWall += 1
			end
		end
		-- 호가 만나는 꺾인 자리 돌기둥 + 놋쇠 구슬
		for _, q in ipairs(D.CUSPS) do
			local gy = groundY(q[1], q[2], rpG)
			part("BasinPier", CFrame.new(q[1], gy + 1.3, q[2]), Vector3.new(2.3, 2.6, 2.3), STONE, f)
			part("PierCap", CFrame.new(q[1], gy + 2.75, q[2]), Vector3.new(2.7, 0.3, 2.7), C.curb, f)
			part("PierBall", CFrame.new(q[1], gy + 3.35, q[2]), Vector3.new(0.9, 0.9, 0.9), C.brass, f, Enum.PartType.Ball)
		end
		say("분수 웅덩이: 벽 토막 %d · 돌기둥 %d", nWall, #D.CUSPS)
		for _, fr in ipairs(D.FIRES) do
			local gy = groundY(fr[1], fr[2], rpG)
			part("FireBarrel", CFrame.new(fr[1], gy + 1.5, fr[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(3.0, 2.4, 2.4), { RGB(78, 70, 66), M.CorrodedMetal }, f, Enum.PartType.Cylinder)
			for _, dy in ipairs({ 0.6, 2.4 }) do
				part("BarrelBand", CFrame.new(fr[1], gy + dy, fr[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 2.55, 2.55), C.iron, f, Enum.PartType.Cylinder)
			end
			local coal = part("Coals", CFrame.new(fr[1], gy + 3.0, fr[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 2.1, 2.1), { RGB(255, 120, 50), M.Neon }, f, Enum.PartType.Cylinder)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Parent = coal
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 160, 90)
			l.Range = 24
			l.Brightness = 2
			l.Parent = coal
		end
	end
	-- 눈 나무(숲 키트 잎을 눈 색으로 — Snow_Field 와 같은 방식)
	do
		local fk = SS:FindFirstChild("ForestKit")
		local LEAF = { LeafA = RGB(232, 240, 248), LeafB = RGB(196, 212, 228) }
		local f = folder("나무")
		for _, t in ipairs(D.TREES) do
			local src = fk and fk:FindFirstChild(t[1])
			if src then
				local gy = groundY(t[2], t[3], rpG)
				local base = CFrame.new(t[2], gy - 0.3, t[3]) * CFrame.Angles(0, math.rad(t[4]), 0)
				local sc = t[5]
				local model = Instance.new("Model")
				model.Name = t[1]
				for _, s in ipairs(src:GetChildren()) do
					if s:IsA("BasePart") and s.Name ~= "Origin" then
						local p = s:Clone()
						p.Size = s.Size * sc
						p.CFrame = base * CFrame.new(s.Position * sc) * s.CFrame.Rotation
						if LEAF[p.Name] then
							p.Color = LEAF[p.Name]
							p.Material = M.Snow
						end
						p.Parent = model
					end
				end
				model.Parent = f
			end
		end
	end
	-- 천문대 망원경·돔·별 돌리기(클라이언트, 서버 시간에 맞춰). 마을을 새로 지을 때마다 같이 새로 넣는다
	do
		local s = Instance.new("Script")
		s.Name = "SnowObservatorySpin"
		s.RunContext = Enum.RunContext.Client
		s.Source = OBS_SCRIPT
		s.Parent = town
	end
	task.wait()

	--==================================================================== 3e. 들어가는 건물(models/build_steam_inside.py)
	-- 보이는 메시는 부딪히지 않게 하고 INSIDE 표의 상자로 벽·바닥·계단·가구를 세운다. 키트 소품은 복제해 놓는다
	-- ("@Press" = 옛 공방 방에서 옮긴 움직이는 압착기 틀). 겉모양에 구운 옛 배율(BAKED)은 톱니·시계 바늘 자리에 곱한다
	local CSi = game:GetService("CollectionService")
	local nColl, nProp, nLamp = 0, 0, 0
	for _, e in ipairs(placed) do
		local spec = INSIDE[e.kind]
		if spec then
			local pv = e.m:GetPivot()
			for _, p in ipairs(e.m:GetDescendants()) do
				if p:IsA("MeshPart") then -- 키트 메시만(천문대처럼 먼저 지은 충돌 상자는 둔다)
					p.CanCollide = false
				end
			end
			local fc = Instance.new("Folder")
			fc.Name = "충돌"
			fc.Parent = e.m
			for _, b in ipairs(spec.coll) do
				local p = part("Coll", pv * CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, math.rad(b[7]), 0), Vector3.new(b[4], b[5], b[6]), C.found, fc)
				p.Transparency = 1
				p.CastShadow = false
				nColl += 1
			end
			for _, pr in ipairs(spec.props) do
				local src = if pr[1] == "@Press" then SS:FindFirstChild("Snow_PressTemplate") else kit:FindFirstChild(pr[1])
				if src then
					local m = src:Clone()
					if pr[6] ~= 1 then
						m:ScaleTo(pr[6])
					end
					m:PivotTo(pv * CFrame.new(pr[2], pr[3], pr[4]) * CFrame.Angles(0, math.rad(pr[5]), 0)
						* CFrame.Angles(math.rad(pr[7]), math.rad(pr[8]), math.rad(pr[9])))
					local col = pr[11] and C[string.lower(pr[11])]
					for _, p in ipairs(m:GetDescendants()) do
						if p:IsA("BasePart") then
							p.CanCollide = false
							if col then
								p.Color, p.Material = col[1], col[2]
							end
						end
					end
					if pr[10] then
						m:SetAttribute("Speed", pr[10])
						CSi:AddTag(m, "SnowGear")
					end
					m.Parent = e.m
					nProp += 1
				else
					say("소품 틀 없음 %s", pr[1])
				end
			end
			-- 등마다 따뜻한 점광원(블렌더 LampPt 상자 자리)
			for _, l in ipairs(spec.lamps) do
				local p = part("Lamp", pv * CFrame.new(l[1], l[2], l[3]), Vector3.new(0.2, 0.2, 0.2), C.found, fc)
				p.Transparency = 1
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				local pl = Instance.new("PointLight")
				pl.Color = RGB(255, 190, 120)
				pl.Brightness = 1.4
				pl.Range = 16
				pl.Parent = p
				nLamp += 1
			end
		end
	end
	say("들어가는 건물: 충돌 상자 %d · 소품 %d · 등 %d", nColl, nProp, nLamp)

	--==================================================================== 3b. 도는 톱니와 시계 바늘
	-- 돌리는 일은 클라이언트 스크립트(맨 끝에서 넣는다)가 서버 시간에 맞춰 한다. 보기 전용이다.
	-- 여기서는 제자리와 처음 각도만 정한다. 톱니 틀 셋은 이 간격(1.96)이 같아 서로 맞물리고,
	-- 이는 톱니 로컬 +X 에서 360/이수 도마다 하나씩 있다. 맞물리는 둘은 같은 배율로 둔다.
	-- 구동 톱니는 상대 쪽으로 이 사이 홈을, 상대 톱니는 구동 쪽으로 이를 내밀게 처음 각도를 준다
	local CS = game:GetService("CollectionService")
	local TEETH = { Gear_24 = 24, Gear_16 = 16, Gear_10 = 10 }
	local function gearR(kind)
		return TEETH[kind] * 1.96 / (2 * math.pi)
	end
	-- 건물 틀마다 붙는 톱니 무리. 로컬 좌표는 건물 피벗 기준이고 판은 건물 앞(-Z)을 본다. ry 로 더 돌린다.
	-- { 구동 톱니, 배율, x, y, z, 초당 도, ry, { { 맞물리는 톱니, 방향(도) }, ... } }
	-- 한 구동 톱니에 둘을 물릴 때는 두 방향 차가 360/이수 의 정수배여야 둘 다 맞물린다
	local BAKED = { Zapfen_Werk = 1.3, Figuren_HQ = 1.2 } -- 들어가는 건물로 다시 지으며 옛 배율을 겉모양에 구워 넣은 틀
	local GEAR_SETS = {
		City_Gate = {
			{ "Gear_16", 0.8, 0, 20.6, -1.8, 24, 0, { { "Gear_10", 213.75 }, { "Gear_10", 326.25 } } },
			-- 뒷면(도시 안쪽)에도 한 벌. 반대로 돌려 두 면이 한 굴대에 물린 듯 보이게 한다
			{ "Gear_16", 0.8, 0, 20.6, 1.8, -24, 180, { { "Gear_10", 213.75 }, { "Gear_10", 326.25 } } },
		},
		-- 박공벽(x ±12, y 22.6..32.6) 안에 들게 줄였다. 작은 것은 같은 높이 왼쪽 굴대에
		Zapfen_Werk = { { "Gear_16", 0.8, 0, 28.0, -17.6, 18, 0, { { "Gear_10", 0 } } } },
		Big_Gear = { { "Gear_16", 0.95, 1.5, 8.1, 0.3, 20, 0, { { "Gear_10", 200.6 } } } },
		-- 둥근 로 벽에 납작한 톱니가 뜨지 않게 쇠 받침판(9 번째: 판 가운데 x, y, 폭, 높이)에 얹는다.
		-- 작은 것은 거의 바로 아래. 발판(y 24.5)과 로 어깨(y 36) 사이에 든다
		Herzofen = { { "Gear_16", 0.8, 11.4, 32.8, 1.5, 30, -90, { { "Gear_10", 250 } }, { -0.25, -1.95, 9.6, 12.8 } } },
	}
	local nGear = 0
	local function makeGear(kind, scale, cf, speed, phase, col, parent)
		local g = kit[kind]:Clone()
		g:ScaleTo(scale)
		g:PivotTo(cf * CFrame.Angles(0, 0, math.rad(phase)))
		for _, p in ipairs(g:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				if col and p.Name:match("_Brass$") then
					p.Color = col
				end
			end
		end
		g:SetAttribute("Speed", speed)
		if speed ~= 0 then
			CS:AddTag(g, "SnowGear")
		end
		g.Parent = parent
		nGear += 1
		return g
	end
	-- 구동 톱니 하나와 거기 물린 톱니들. base 는 구동 톱니 가운데이고 앞(-Z)이 보는 쪽이다
	local function gearTrain(base, kind, sc, speed, mates, f, still)
		local da = 360 / TEETH[kind]
		for _, mt in ipairs(mates) do
			local kindB, phi = mt[1], mt[2]
			local d = (gearR(kind) + gearR(kindB) - 0.9) * sc
			local off = CFrame.new(d * math.cos(math.rad(phi)), d * math.sin(math.rad(phi)), 0)
			makeGear(kindB, sc, base * off, -speed * TEETH[kind] / TEETH[kindB], phi + 180,
				still and RGB(95, 158, 140) or C.copper[1], f)
		end
		makeGear(kind, sc, base, speed, mates[1][2] - da / 2, still and RGB(140, 96, 70) or nil, f)
	end
	for _, e in ipairs(placed) do
		local sets = GEAR_SETS[e.kind]
		if sets then
			-- 폐허 마당의 조형물은 녹슬어 멈춰 있다
			local still = e.m.Parent.Name == "설공방"
			local f = folder("톱니")
			for _, st in ipairs(sets) do
				-- 건물을 키웠으면 자리·톱니·받침판도 같은 배율로
				local k = e.sc * (BAKED[e.kind] or 1)
				local kind, sc, x, y, z, speed, ry, mates = st[1], st[2] * k, st[3] * k, st[4] * k, st[5] * k, st[6], st[7], st[8]
				local base = e.m:GetPivot() * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(ry), 0)
				gearTrain(base, kind, sc, still and 0 or speed, mates, f, still)
				local pl = st[9] and { st[9][1] * k, st[9][2] * k, st[9][3] * k, st[9][4] * k }
				if pl then
					-- 받침판은 톱니 뒤(+Z) 1.0. 네 귀에 놋쇠 볼트, 두 옆 끝에서 벽으로 받침살
					local pc = base * CFrame.new(pl[1], pl[2], 1.0)
					part("GearPlate", pc, Vector3.new(pl[3], pl[4], 0.4), C.iron, f)
					for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
						part("PlateBolt", pc * CFrame.new(o[1] * (pl[3] / 2 - 0.5), o[2] * (pl[4] / 2 - 0.5), -0.3) * CFrame.Angles(0, math.rad(90), 0),
							Vector3.new(0.3, 0.6, 0.6), C.brass, f, Enum.PartType.Cylinder)
					end
					for _, sx in ipairs({ -1, 1 }) do
						part("PlateStay", pc * CFrame.new(sx * (pl[3] / 2 - 0.4), 0, 1.0), Vector3.new(0.6, pl[4] * 0.6, 1.8), C.iron, f)
					end
				end
			end
		end
		if e.kind == "Figuren_HQ" then
			-- 시계 바늘. 앞에서 보면 로컬 +X 가 왼쪽이라 양의 각속도가 시계 방향이다
			local k = e.sc * (BAKED[e.kind] or 1)
			local c = e.m:GetPivot() * CFrame.new(0, 35.5 * k, -17.1 * k)
			for _, hd in ipairs({ { "Hour", 0.55, 2.3, 0.25, 125 }, { "Minute", 0.38, 3.3, 3.0, 10 } }) do
				local m = Instance.new("Model")
				m.Name = "ClockHand_" .. hd[1]
				local zoff = (hd[1] == "Hour" and 0 or -0.25) * k
				part(hd[1], c * CFrame.new(0, (hd[3] / 2 - 0.35) * k, zoff), Vector3.new(hd[2] * k, hd[3] * k, 0.22), C.iron, m)
				m.WorldPivot = c
				m:PivotTo(c * CFrame.Angles(0, 0, math.rad(hd[5])))
				m:SetAttribute("Speed", hd[4])
				CS:AddTag(m, "SnowGear")
				m.Parent = folder("톱니")
			end
			part("ClockPin", c * CFrame.new(0, 0, -0.45 * k) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 0.7 * k, 0.7 * k), C.brass, folder("톱니"), Enum.PartType.Cylinder)
		end
	end

	--==================================================================== 3c. 맨홀
	-- 길 위 맨홀. 쇠 뚜껑에 놋쇠 테, 가운데에 톱니 무늬
	do
		local rpRoad = RaycastParams.new()
		rpRoad.FilterType = Enum.RaycastFilterType.Include
		rpRoad.FilterDescendantsInstances = { folder("길") }
		for i, mh in ipairs(D.MANHOLES) do
			local hit = workspace:Raycast(Vector3.new(mh[1], 400, mh[2]), Vector3.new(0, -800, 0), rpRoad)
			assert(hit, string.format("맨홀 %d 자리 (%.0f,%.0f) 에 길이 없다", i, mh[1], mh[2]))
			local top = hit.Position.Y
			local f = folder("길/맨홀")
			part("Cover", CFrame.new(mh[1], top + 0.08, mh[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 3.4, 3.4), C.iron, f, Enum.PartType.Cylinder)
			part("CoverRim", CFrame.new(mh[1], top + 0.04, mh[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 4.0, 4.0), C.brass, f, Enum.PartType.Cylinder)
			local g = makeGear("Gear_10", 0.42, CFrame.new(mh[1], top + 0.2, mh[2]) * CFrame.Angles(math.rad(90), 0, 0), 0, i * 23, C.iron[1], f)
			g.Name = "ManholeGear"
		end
	end
	task.wait()

	--==================================================================== 4. 난방관과 김
	-- 관 한 줄은 쇠 받침 위 높이 h 에 걸린 구리관이다. 꺾이는 점마다 공 이음을 넣어 매끈하게 잇고,
	-- 두 끝은 1/4 원환 엘보(Pipe_Bend90)로 휘어 땅으로 들어 볼트 박은 받침판에 선다.
	-- 받침 몇 곳에 밸브 손바퀴와 압력계를 얹고, 이음 몇 곳에서 김이 샌다
	local steamProto
	for _, d in ipairs(kit.Steam_House_A:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			steamProto = d
		end
	end
	local PR, BR = 1.1, 2.6 -- 관 반지름과 엘보 굽힘 반지름. Pipe_Bend90 과 같아야 한다
	local function cylBetween(name, a, b, r, col, f)
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		return part(name, cf, Vector3.new((b - a).Magnitude, 2 * r, 2 * r), col, f, Enum.PartType.Cylinder)
	end
	local function leak(at, f, rate)
		if not steamProto then
			return
		end
		local e = part("Leak", CFrame.new(at), Vector3.new(0.4, 0.4, 0.4), C.iron, f)
		e.Transparency = 1
		e.CanCollide = false
		e.CanQuery = false
		local s = steamProto:Clone()
		s.Rate = rate
		s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 3) })
		s.Speed = NumberRange.new(1.5, 2.5)
		s.Parent = e
	end
	local nValve, nGauge, nLeak = 0, 0, 0
	local rpRoadP = RaycastParams.new()
	rpRoadP.FilterType = Enum.RaycastFilterType.Include
	rpRoadP.FilterDescendantsInstances = { folder("길") }
	-- 관마다 높이는 밑 땅에서 가장 높은 곳 + 7. 모음통으로 이어진 관끼리는 가장 높은 것에 맞춘다
	-- (무리가 모음통 여럿으로 이어지므로 더 바뀌지 않을 때까지 되풀이)
	local pipeH = {}
	for _, pl in ipairs(D.PIPES) do
		local name, pts = pl[1], pl[2]
		local hi = -math.huge
		for i = 1, #pts do
			hi = math.max(hi, (assert(groundY(pts[i][1], pts[i][2]), name .. " 밑에 땅이 없다")))
			if i < #pts then
				hi = math.max(hi, groundY((pts[i][1] + pts[i + 1][1]) / 2, (pts[i][2] + pts[i + 1][2]) / 2) or hi)
			end
		end
		pipeH[name] = hi + 7
	end
	local changed = true
	while changed do
		changed = false
		for _, j in ipairs(D.JUNCTIONS) do
			local top = -math.huge
			for _, n in ipairs(j[3]) do
				top = math.max(top, (assert(pipeH[n], "모음통의 관 " .. n .. " 이 없다")))
			end
			for _, n in ipairs(j[3]) do
				if pipeH[n] < top then
					pipeH[n] = top
					changed = true
				end
			end
		end
	end
	local JR = 1.95 -- 모음통 반지름
	local function nearJunction(p, r)
		for _, j in ipairs(D.JUNCTIONS) do
			if Vector2.new(j[1] - p.X, j[2] - p.Z).Magnitude < r then
				return j
			end
		end
		return nil
	end
	for _, pl in ipairs(D.PIPES) do
		local name, pts = pl[1], pl[2]
		local f = folder("난방관/" .. name)
		local h = pipeH[name]
		local P = {}
		for i, q in ipairs(pts) do
			P[i] = Vector3.new(q[1], h, q[2])
		end
		local d0 = (P[2] - P[1]).Unit
		local dn = (P[#P] - P[#P - 1]).Unit
		-- 모음통에 꽂히는 끝은 엘보 없이 통 가운데까지 곧게 들어간다
		local j1, jn = nearJunction(P[1], 2.5), nearJunction(P[#P], 2.5)
		-- 곧은 도막. 두 끝은 엘보가 차지하는 BR 만큼 비운다. 가운데 꺾임은 공 이음이 메운다
		for i = 1, #P - 1 do
			local a = (i == 1 and not j1) and (P[1] + d0 * BR) or P[i]
			local b = (i == #P - 1 and not jn) and (P[#P] - dn * BR) or P[i + 1]
			cylBetween("Pipe", a, b, PR, C.copper, f)
		end
		for i = 2, #P - 1 do
			part("Joint", CFrame.new(P[i]), Vector3.new(2 * PR, 2 * PR, 2 * PR), C.copper, f, Enum.PartType.Ball)
		end
		-- 두 끝. 엘보로 꺾여 땅까지 내려가 받침판에 선다
		for _, e in ipairs({ { P[1], -d0, j1 }, { P[#P], dn, jn } }) do
			local corner, dir = e[1], e[2]
			if e[3] then
				continue
			end
			local bendM = kit.Pipe_Bend90:Clone()
			bendM:PivotTo(CFrame.fromMatrix(corner, dir, Vector3.yAxis))
			bendM.Parent = f
			local gy = assert(groundY(corner.X, corner.Z), name .. " 끝 밑에 땅이 없다")
			cylBetween("Drop", Vector3.new(corner.X, corner.Y - BR, corner.Z), Vector3.new(corner.X, gy + 0.3, corner.Z), PR, C.copper, f)
			part("DropFlange", CFrame.new(corner.X, gy + 0.75, corner.Z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 2.9, 2.9), C.brass, f, Enum.PartType.Cylinder)
			local plate = CFrame.new(corner.X, gy + 0.2, corner.Z) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
			part("BasePlate", plate, Vector3.new(4, 0.4, 4), C.iron, f)
			for _, o in ipairs({ { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } }) do
				part("Bolt", plate * CFrame.new(o[1], 0.35, o[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 0.55, 0.55), C.brass, f, Enum.PartType.Cylinder)
			end
		end
		-- 받침. 줄을 따라 15 마다. 끝 엘보 가까이는 건너뛴다
		local total = 0
		for i = 1, #P - 1 do
			total += (P[i + 1] - P[i]).Magnitude
		end
		local npost = math.max(1, math.floor((total - 2 * BR - 4) / 15))
		local step = (total - 2 * BR - 4) / npost
		-- 관을 따라 want 만큼 간 자리와 그곳의 방향
		local function along(want)
			local acc = 0
			for i = 1, #P - 1 do
				local L = (P[i + 1] - P[i]).Magnitude
				if acc + L >= want then
					local dir = (P[i + 1] - P[i]).Unit
					return P[i] + dir * (want - acc), dir
				end
				acc += L
			end
			return P[#P], dn
		end
		for k = 0, npost do
			local q, dir = along(BR + 2 + step * k)
			-- 받침은 모음통 곁을 비운다. 통은 제 다리로 선다
			if nearJunction(q, JR + 2) then
				continue
			end
			-- 길을 건너는 곳은 받침 없이 건너간다(길 한복판에 기둥이 서지 않게)
			if workspace:Raycast(Vector3.new(q.X, 400, q.Z), Vector3.new(0, -800, 0), rpRoadP) then
				continue
			end
			local gy = groundY(q.X, q.Z)
			part("Post", CFrame.new(q.X, (h - PR + gy) / 2, q.Z), Vector3.new(0.9, h - PR - gy, 0.9), C.iron, f)
			part("PostFoot", CFrame.new(q.X, gy + 0.2, q.Z), Vector3.new(1.8, 0.4, 1.8), C.iron, f)
			part("Saddle", CFrame.lookAt(Vector3.new(q.X, h - PR - 0.25, q.Z), Vector3.new(q.X, h - PR - 0.25, q.Z) + dir), Vector3.new(2.4, 0.5, 1.2), C.brass, f)
			part("Clamp", CFrame.lookAt(q, q + dir) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.7, 2.7, 2.7), C.brass, f, Enum.PartType.Cylinder)
			-- 받침 고정쇠 이음에서 김이 조금 샌다. 몇 곳에서만
			if k % 5 == 2 then
				leak(q + dir * 0.45 + Vector3.new(0, PR * 0.6, 0), f, 1.5)
				nLeak += 1
			end
			-- 밸브와 압력계는 받침과 받침 한가운데에 번갈아 단다. 고정쇠와 겹치지 않게.
			-- 꺾인 곳(공 이음)과 모음통 곁은 피한다
			if k < npost and (k % 4 == 1 or k % 4 == 3) then
				local m, mdir
				for _, off in ipairs({ 0, 1, -1, 2, -2, 3, -3 }) do
					local cm, cd = along(BR + 2 + step * (k + 0.5) + off)
					local ok = not nearJunction(cm, JR + 3)
					for i = 2, #P - 1 do
						if (P[i] - cm).Magnitude < 2 then
							ok = false
						end
					end
					if ok then
						m, mdir = cm, cd
						break
					end
				end
				if m then
					local top = m + Vector3.new(0, PR, 0)
					if k % 4 == 1 then
						local v = kit.Pipe_Valve:Clone()
						v:PivotTo(CFrame.lookAt(top, top + mdir))
						v.Parent = f
						nValve += 1
					else
						local side = Vector3.new(-mdir.Z, 0, mdir.X)
						local gm = kit.Pipe_Gauge:Clone()
						gm:PivotTo(CFrame.lookAt(top, top + side))
						gm.Parent = f
						nGauge += 1
					end
				end
			end
		end
	end
	-- 모음통. 선 구리통에 놋쇠 띠, 쇠 뚜껑 위 압력계, 제 다리. 드나드는 관마다 통 벽에 놋쇠 테
	local nJunction = 0
	for i, j in ipairs(D.JUNCTIONS) do
		local f = folder("난방관/모음통")
		local h = pipeH[j[3][1]]
		local c = Vector3.new(j[1], h, j[2])
		local up = CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90))
		part("Drum_" .. i, up, Vector3.new(4.2, 2 * JR, 2 * JR), C.copper, f, Enum.PartType.Cylinder)
		for _, dy in ipairs({ -1.3, 1.3 }) do
			part("DrumBand", up + Vector3.new(0, dy, 0), Vector3.new(0.5, 2 * JR + 0.3, 2 * JR + 0.3), C.brass, f, Enum.PartType.Cylinder)
		end
		part("DrumCap", up + Vector3.new(0, 2.3, 0), Vector3.new(0.4, 2 * JR + 0.4, 2 * JR + 0.4), C.iron, f, Enum.PartType.Cylinder)
		part("DrumCapB", up + Vector3.new(0, -2.3, 0), Vector3.new(0.4, 2 * JR + 0.4, 2 * JR + 0.4), C.iron, f, Enum.PartType.Cylinder)
		local gm = kit.Pipe_Gauge:Clone()
		local capTop = c + Vector3.new(0, 2.5, 0)
		gm:PivotTo(CFrame.lookAt(capTop, capTop + Vector3.new(1, 0, 0)))
		gm.Parent = f
		nGauge += 1
		local gy = assert(groundY(c.X, c.Z), "모음통 밑에 땅이 없다")
		part("DrumLeg", CFrame.new(c.X, (c.Y - 2.5 + gy) / 2, c.Z), Vector3.new(1.2, c.Y - 2.5 - gy, 1.2), C.iron, f)
		part("DrumFoot", CFrame.new(c.X, gy + 0.2, c.Z), Vector3.new(2.4, 0.4, 2.4), C.iron, f)
		leak(c + Vector3.new(0, 2.6, 0.8), f, 2)
		nLeak += 1
		-- 관이 통 벽을 지나는 자리마다 테. 관 줄 도막과 통 둘레(반지름 JR)가 만나는 점을 찾는다
		for _, n in ipairs(j[3]) do
			local pts
			for _, pl in ipairs(D.PIPES) do
				if pl[1] == n then
					pts = pl[2]
				end
			end
			for k = 1, #pts - 1 do
				local A = Vector2.new(pts[k][1] - c.X, pts[k][2] - c.Z)
				local B = Vector2.new(pts[k + 1][1] - c.X, pts[k + 1][2] - c.Z)
				local d = B - A
				local qa, qb, qc = d:Dot(d), 2 * A:Dot(d), A:Dot(A) - JR * JR
				local disc = qb * qb - 4 * qa * qc
				if disc > 0 then
					for _, sg in ipairs({ -1, 1 }) do
						local t = (-qb + sg * math.sqrt(disc)) / (2 * qa)
						if t >= 0 and t <= 1 then
							local hit = A + d * t
							local q = Vector3.new(c.X + hit.X, h, c.Z + hit.Y)
							local dir = Vector3.new(d.X, 0, d.Y).Unit
							part("DrumCollar", CFrame.lookAt(q, q + dir) * CFrame.Angles(0, math.rad(90), 0),
								Vector3.new(0.6, 2 * PR * 1.35, 2 * PR * 1.35), C.brass, f, Enum.PartType.Cylinder)
						end
					end
				end
			end
		end
		nJunction += 1
	end
	-- 김구멍이 길 위에 놓이면 길 윗면에 얹는다
	local rpVent = RaycastParams.new()
	rpVent.FilterType = Enum.RaycastFilterType.Include
	rpVent.FilterDescendantsInstances = { G, FStone, folder("길") }
	for i, v in ipairs(D.VENTS) do
		local gy = groundY(v[1], v[2], rpVent)
		local f = folder("난방관/김구멍")
		part("Grate_" .. i, CFrame.new(v[1], gy + 0.15, v[2]), Vector3.new(3.2, 0.3, 3.2), C.plate, f)
		local e = part("SteamPoint_" .. i, CFrame.new(v[1], gy + 0.6, v[2]), Vector3.new(0.5, 0.5, 0.5), C.iron, f)
		e.Transparency = 1
		e.CanCollide = false
		e.CanQuery = false
		if steamProto then
			local s = steamProto:Clone()
			s.Rate = 3
			s.Parent = e
		end
	end
	task.wait()

	-- 도는 톱니 스크립트(SnowGearSpin)는 옛 도시 것을 그대로 쓴다. 없으면 넣는다
	if not city:FindFirstChild("SnowGearSpin") then
		local gs = Instance.new("Script")
		gs.Name = "SnowGearSpin"
		gs.RunContext = Enum.RunContext.Client
		gs.Source = GEAR_SCRIPT
		gs.Parent = city
	end

	--==================================================================== 8. 검사
	local counts = {}
	for _, e in ipairs(placed) do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local line = {}
	for _, k in ipairs(keys) do
		line[#line + 1] = k .. " " .. counts[k]
	end
	say("%s", table.concat(line, ", "))
	say("모델 %d, 받침돌 %d 개, 가장 큰 땅 높이차 %.2f", #placed, foundations, maxGap)
	say("톱니 %d (도는 것 %d), 밸브 %d, 압력계 %d, 김 새는 이음 %d, 모음통 %d", nGear, #CS:GetTagged("SnowGear"), nValve, nGauge, nLeak, nJunction)
	local n = 0
	for _, d in ipairs(town:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	say("파트 합계 %d", n)

	--==================================================================== 3f. 지하 카지노 땅 파기(INSIDE.dig — build_steam_under.py)
	-- Surface.R_설원3.Land 의 축 정렬 큰 판(마을·마을_눈)을 상자 빼기로 쪼갠다. 처음 판은 ServerStorage.Snow_LandOriginal 에
	-- 두고 다시 지을 때마다 되돌린 뒤 다시 판다(몇 번 돌려도 같다). 마을 다른 것들이 땅 높이를 다 잰 뒤라 맨 끝에 한다.
	do
		local digs = {}
		for _, e in ipairs(placed) do
			local spec = INSIDE[e.kind]
			if spec and spec.dig then
				local pv = e.m:GetPivot()
				local X, Y, Z = pv.XVector, pv.YVector, pv.ZVector
				for _, d in ipairs(spec.dig) do
					local c = pv:PointToWorldSpace(Vector3.new(d[1], d[2], d[3]))
					local hx, hy, hz = d[4] / 2, d[5] / 2, d[6] / 2
					local h = if d[7]
						then Vector3.new(hx, hy, hz)
						else Vector3.new(
							math.abs(X.X) * hx + math.abs(Y.X) * hy + math.abs(Z.X) * hz,
							math.abs(X.Y) * hx + math.abs(Y.Y) * hy + math.abs(Z.Y) * hz,
							math.abs(X.Z) * hx + math.abs(Y.Z) * hy + math.abs(Z.Z) * hz
						)
					digs[#digs + 1] = { c - h, c + h }
				end
			end
		end
		local land = G:FindFirstChild("Land")
		local store = SS:FindFirstChild("Snow_LandOriginal")
		if not store then
			store = Instance.new("Folder")
			store.Name = "Snow_LandOriginal"
			store.Parent = SS
		end
		local function sub(lo, hi, clo, chi)
			for _, ax in ipairs({ "X", "Y", "Z" }) do
				if math.min(hi[ax], chi[ax]) - math.max(lo[ax], clo[ax]) <= 1e-3 then
					return { { lo, hi } }
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
		local nCut, nPiece, k = 0, 0, 0
		for _, p in ipairs(land:GetChildren()) do
			if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.CFrame.XVector.X > 0.9999 and p.CFrame.YVector.Y > 0.9999 then
				local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
				local boxes = { { lo, hi } }
				local hit = false
				for _, d in ipairs(digs) do
					local nxt = {}
					for _, b in ipairs(boxes) do
						local r = sub(b[1], b[2], d[1], d[2])
						if #r ~= 1 or r[1][1] ~= b[1] or r[1][2] ~= b[2] then
							hit = true
						end
						for _, q in ipairs(r) do
							nxt[#nxt + 1] = q
						end
					end
					boxes = nxt
				end
				if hit then
					k += 1
					local key = p.Name .. "#" .. k
					local orig = p:Clone()
					orig:SetAttribute("CarveKey", key)
					orig.Parent = store
					for _, b in ipairs(boxes) do
						local s = b[2] - b[1]
						if s.X > 0.05 and s.Y > 0.05 and s.Z > 0.05 then
							local q = p:Clone()
							q.Size = s
							q.CFrame = CFrame.new((b[1] + b[2]) / 2)
							q:SetAttribute("CarvedFrom", key)
							q.Parent = land
							nPiece += 1
						end
					end
					p:Destroy()
					nCut += 1
				end
			end
		end
		say("땅 파기: 상자 %d, 쪼갠 판 %d → 조각 %d", #digs, nCut, nPiece)
	end
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowcity2", table.concat(report, "\n"))
end)
HS.HttpEnabled = was