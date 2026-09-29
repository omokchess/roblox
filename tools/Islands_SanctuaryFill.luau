--!nocheck
--[[
	Islands_SanctuaryFill.luau — 성역 섬의 바깥쪽을 채운다.

	[Islands_Sanctuary.luau] 가 탑 둘레 1,100 안쪽(참배로·열주·제단·비석)을 맡고
	이 스크립트가 그 바깥부터 섬 가장자리까지를 맡는다. 둘은 겹치지 않는다.

	**자리는 전부 아래 표에 각도와 거리로 적혀 있다.** 흩뿌리는 수식을 쓰지 않는다.
	무엇이 어디에 놓일지 내가 말할 수 없으면 잘못 만든 것이다.
	원 둘레에 돌을 두르는 것 같은 규칙적인 반복만 코드에 맡긴다.

	놓는 것
	  순례 고리   r=1300 의 포석 띠. 끊긴 구간이 표에 적혀 있다
	  회랑        고리 위 세 구간에 세우는 쌍기둥과 인방. 대부분 무너졌다
	  부속 신전   다섯. 셋은 열린 정자, 둘은 작은 탑이다
	  계단 대지   둘. 층을 이룬 단이다
	  반사지      둘. 검은 물판. 하늘과 탑이 비친다
	  조각상 받침 여덟. 상은 전부 부러져 발목만 남았다
	  가장자리 성벽 섬 가장자리를 두르던 벽의 잔해
	  떠 있는 바위 열넷. 돌지 않는다. 신이 내려앉던 자리라는 표시다
	  빛 기둥     넷. 고리의 네 지점에 서는 가는 빛
	  화로        참배로를 따라. 불빛이 길의 리듬을 만든다
	  자갈 무더기 열둘. 빈 곳을 메운다

	되돌리기: workspace.Surface.Fill_탑의성역:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local X, Z = 1200, -4400 -- 탑 자리
local RING = 1300 -- 순례 고리 반지름
local KEEP_IN = 1140 -- 이 안쪽은 Islands_Sanctuary 가 맡는다. 침범 금지

-- 순례 고리에서 포석이 남아 있는 구간 { 시작각, 끝각 }
local RING_KEPT = {
	{ 342, 78 },
	{ 96, 168 },
	{ 188, 246 },
	{ 262, 318 },
}

-- 회랑 { 시작각, 끝각, 남은 정도 0~1 }
local ARCADES = {
	{ 350, 62, 0.75 },
	{ 104, 160, 0.45 },
	{ 200, 240, 0.62 },
}

-- 부속 신전 { 각도, 거리, 폭, 깊이, 기둥높이, 양식 }
-- 양식 pavilion = 지붕 인 열린 정자, tower = 작은 탑
local SHRINES = {
	{ ang = 20, r = 1300, w = 260, d = 210, h = 118, style = "pavilion" },
	{ ang = 110, r = 1300, w = 210, d = 210, h = 156, style = "tower" },
	{ ang = 200, r = 1300, w = 290, d = 190, h = 104, style = "pavilion" },
	{ ang = 290, r = 1300, w = 230, d = 230, h = 126, style = "pavilion" },
	{ ang = 66, r = 1580, w = 180, d = 180, h = 142, style = "tower" },
}

-- 계단 대지 { 각도, 거리, 바닥 반지름, 단 수 }
local PLAZAS = {
	{ 155, 1010, 270, 3 },
	{ 335, 1060, 230, 4 },
}

-- 반사지 { 각도, 거리, 반지름 }
local POOLS = {
	{ 248, 1020, 190 },
	{ 42, 1520, 150 },
}

-- 조각상 받침 { 각도, 거리, 받침높이, 남은 다리 높이 }
local STATUES = {
	{ 8, 1180, 46, 58 },
	{ 48, 1230, 40, 22 },
	{ 132, 1190, 52, 40 },
	{ 172, 1250, 44, 14 },
	{ 214, 1170, 48, 62 },
	{ 258, 1240, 42, 26 },
	{ 302, 1200, 50, 36 },
	{ 328, 1260, 44, 18 },
}

-- 가장자리 성벽 { 시작각, 끝각, 거리, 남은 정도 }
local EDGE = {
	{ 8, 64, 1760, 0.42 },
	{ 96, 142, 1780, 0.30 },
	{ 186, 232, 1750, 0.55 },
	{ 268, 316, 1790, 0.36 },
}

-- 떠 있는 바위 { 각도, 거리, 지면에서의 높이, 크기 }
local FLOATERS = {
	{ 30, 760, 210, 64 },
	{ 84, 980, 340, 46 },
	{ 128, 640, 170, 78 },
	{ 162, 1120, 420, 52 },
	{ 196, 880, 260, 60 },
	{ 232, 1340, 300, 44 },
	{ 274, 700, 190, 70 },
	{ 310, 1180, 380, 50 },
	{ 344, 940, 230, 58 },
	{ 58, 1420, 460, 40 },
	{ 148, 1500, 280, 66 },
	{ 218, 1560, 350, 48 },
	{ 292, 1480, 200, 72 },
	{ 12, 1620, 410, 42 },
}

-- 빛 기둥 { 각도 }
local BEACONS = { 40, 130, 220, 310 }

-- 참배로 방향. Islands_Sanctuary 와 같아야 화로가 길 위에 선다
local WAYS = { 20, 110, 200, 290 }
local BRAZIER_AT = { 420, 620, 820 }
local BRAZIER_OFF = 112

-- 자갈 무더기 { 각도, 거리, 크기 }
local RUBBLE = {
	{ 36, 1400, 70 },
	{ 72, 860, 54 },
	{ 100, 1460, 62 },
	{ 144, 820, 48 },
	{ 178, 1380, 76 },
	{ 210, 1520, 58 },
	{ 254, 1440, 66 },
	{ 286, 900, 52 },
	{ 318, 1560, 70 },
	{ 352, 1300, 60 },
	{ 120, 1640, 56 },
	{ 240, 1660, 64 },
}

local STONE = RGB(206, 202, 186)
local WEATHER = RGB(116, 118, 110)
local GLOW = RGB(255, 214, 140)
local WATER = RGB(30, 44, 58)

local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World }

local old = S:FindFirstChild("Fill_탑의성역")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Fill_탑의성역"
root.Parent = S

local rng = Random.new(770231)
local n = 0

local function sub(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

-- 유적은 땅에 붙어야 한다. 자리마다 지면을 실측한다
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1600, 0), rp)
	return hit and hit.Position.Y or nil
end

local function polar(ang, r)
	local a = math.rad(ang)
	return X + math.cos(a) * r, Z + math.sin(a) * r
end

local function put(fold, name, cf, size, mat, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or STONE:Lerp(WEATHER, rng:NextNumber(0, 0.62))
	p.Material = mat or M.Limestone
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fold
	n += 1
	return p
end

-- 각도 구간에 들어가는지. 0도를 넘어가는 구간도 처리한다
local function inSpan(ang, a0, a1)
	ang = ang % 360
	a0, a1 = a0 % 360, a1 % 360
	if a0 <= a1 then
		return ang >= a0 and ang <= a1
	end
	return ang >= a0 or ang <= a1
end

--=== 순례 고리 ===--
local fRing = sub("Ring")
do
	local cnt = math.floor(2 * math.pi * RING / 88)
	for i = 0, cnt - 1 do
		local ang = i / cnt * 360
		local kept = false
		for _, sp in ipairs(RING_KEPT) do
			if inSpan(ang, sp[1], sp[2]) then
				kept = true
			end
		end
		-- 남은 구간 안에서도 군데군데 빠진다. 꽉 채우면 새로 깐 바닥이다
		if kept and rng:NextNumber() > 0.18 then
			for lane = -1, 1 do
				local px, pz = polar(ang, RING + lane * 62 + rng:NextNumber(-7, 7))
				local gy = ground(px, pz)
				if gy then
					put(
						fRing,
						string.format("Ring%d_%d", i, lane + 2),
						CFrame.new(px, gy + 2, pz) * CFrame.Angles(0, -math.rad(ang) + rng:NextNumber(-0.08, 0.08), 0),
						Vector3.new(62, 7, 82)
					)
				end
			end
		end
	end
	task.wait()
end

--=== 회랑 ===--
local fArc = sub("Arcade")
for ai, arc in ipairs(ARCADES) do
	local a0, a1, keep = arc[1], arc[2], arc[3]
	local span = (a1 - a0) % 360
	local bays = math.max(math.floor(span / 6), 4)
	for b = 0, bays do
		local ang = a0 + span * (b / bays)
		local standing = rng:NextNumber() < keep
		for side = -1, 1, 2 do
			local px, pz = polar(ang, RING + side * 96)
			local gy = ground(px, pz)
			if gy then
				local drums = standing and 4 or rng:NextInteger(1, 2)
				put(
					fArc,
					string.format("ArcB%d_%d_%d", ai, b, side),
					CFrame.new(px, gy + 5, pz) * CFrame.Angles(0, -math.rad(ang), 0),
					Vector3.new(38, 10, 38)
				)
				for k = 0, drums - 1 do
					local wob = standing and 0 or 0.1
					put(
						fArc,
						string.format("ArcC%d_%d_%d_%d", ai, b, side, k),
						CFrame.new(px, gy + 12 + k * 24, pz)
							* CFrame.Angles(rng:NextNumber(-wob, wob), -math.rad(ang), rng:NextNumber(-wob, wob)),
						Vector3.new(26, 24, 26)
					)
				end
			end
		end
		-- 인방은 양쪽 기둥이 다 서 있을 때만 걸린다
		if standing and b < bays then
			local ang2 = a0 + span * ((b + 1) / bays)
			for side = -1, 1, 2 do
				local ax, az = polar(ang, RING + side * 96)
				local bx, bz = polar(ang2, RING + side * 96)
				local gy = ground(ax, az)
				if gy then
					local mid = Vector3.new((ax + bx) / 2, gy + 12 + 4 * 24 + 9, (az + bz) / 2)
					put(
						fArc,
						string.format("ArcL%d_%d_%d", ai, b, side),
						CFrame.lookAt(mid, Vector3.new(bx, mid.Y, bz)),
						Vector3.new(30, 18, math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) * 1.05)
					)
				end
			end
		end
	end
	task.wait()
end

--=== 부속 신전 ===--
local fShr = sub("Shrine")
for si, sh in ipairs(SHRINES) do
	local cx, cz = polar(sh.ang, sh.r)
	local gy = ground(cx, cz)
	if gy then
		local yaw = -math.rad(sh.ang)
		local base = CFrame.new(cx, gy, cz) * CFrame.Angles(0, yaw, 0)
		-- 기단 두 단
		for k = 0, 1 do
			put(
				fShr,
				string.format("ShB%d_%d", si, k),
				base * CFrame.new(0, 6 + k * 12, 0),
				Vector3.new(sh.w - k * 34, 12, sh.d - k * 34)
			)
		end
		local hw, hd = (sh.w - 68) / 2, (sh.d - 68) / 2
		if sh.style == "pavilion" then
			-- 네 귀퉁이 기둥. 하나는 부러뜨린다
			local broken = si % 4 + 1
			local c = 0
			for ix = -1, 1, 2 do
				for iz = -1, 1, 2 do
					c += 1
					local hh = (c == broken) and sh.h * 0.42 or sh.h
					local drums = math.max(math.floor(hh / 24), 1)
					for k = 0, drums - 1 do
						put(
							fShr,
							string.format("ShC%d_%d_%d", si, c, k),
							base * CFrame.new(ix * hw, 24 + k * 24, iz * hd) * CFrame.Angles(0, k * 0.2, 0),
							Vector3.new(24, 24, 24)
						)
					end
				end
			end
			-- 지붕. 한쪽이 내려앉아 기울어 있다
			put(
				fShr,
				"ShRoof" .. si,
				base * CFrame.new(0, 24 + sh.h + 8, 0) * CFrame.Angles(0.09, 0, 0.05),
				Vector3.new(sh.w - 30, 16, sh.d - 30)
			)
			put(
				fShr,
				"ShRidge" .. si,
				base * CFrame.new(0, 24 + sh.h + 24, 0) * CFrame.Angles(0.09, 0, 0.05),
				Vector3.new(sh.w * 0.5, 14, sh.d * 0.5)
			)
			-- 가운데 제물대
			put(fShr, "ShAlt" .. si, base * CFrame.new(0, 30, 0), Vector3.new(54, 16, 54))
			put(fShr, "ShGlow" .. si, base * CFrame.new(0, 41, 0), Vector3.new(34, 8, 34), M.Neon, GLOW)
		else
			-- 작은 탑. 층마다 조금씩 돌려 쌓는다
			local lv = math.floor(sh.h / 20)
			for k = 0, lv - 1 do
				local t = k / lv
				local w = sh.w * (0.78 - 0.34 * t)
				put(
					fShr,
					string.format("ShT%d_%d", si, k),
					base * CFrame.new(0, 24 + k * 20, 0) * CFrame.Angles(0, k * 0.22, 0),
					Vector3.new(w, 20, w)
				)
			end
			put(
				fShr,
				"ShTip" .. si,
				base * CFrame.new(0, 24 + lv * 20 + 12, 0) * CFrame.Angles(0, lv * 0.22, 0),
				Vector3.new(34, 26, 34),
				M.Neon,
				GLOW
			)
		end
	end
end

--=== 계단 대지 ===--
local fPlz = sub("Plaza")
for pi, pl in ipairs(PLAZAS) do
	local cx, cz = polar(pl[1], pl[2])
	local gy = ground(cx, cz)
	if gy then
		local r0, tiers = pl[3], pl[4]
		for k = 0, tiers - 1 do
			local r = r0 - k * (r0 * 0.22)
			local cnt = math.max(math.floor(2 * math.pi * r / 74), 8)
			for i = 0, cnt - 1 do
				local a = i / cnt * math.pi * 2
				if rng:NextNumber() > 0.12 + k * 0.05 then
					put(
						fPlz,
						string.format("Plz%d_%d_%d", pi, k, i),
						CFrame.new(cx + math.cos(a) * r, gy + 7 + k * 14, cz + math.sin(a) * r)
							* CFrame.Angles(0, -a, 0),
						Vector3.new(58, 14, 78)
					)
				end
			end
			-- 안쪽을 메우는 판
			put(
				fPlz,
				string.format("PlzF%d_%d", pi, k),
				CFrame.new(cx, gy + 7 + k * 14, cz) * CFrame.Angles(0, k * 0.3, 0),
				Vector3.new(r * 1.5, 14, r * 1.5)
			)
		end
	end
	task.wait()
end

--=== 반사지 ===--
local fPool = sub("Pool")
for pi, po in ipairs(POOLS) do
	local cx, cz = polar(po[1], po[2])
	local gy = ground(cx, cz)
	if gy then
		local r = po[3]
		-- 테두리 돌
		local cnt = math.floor(2 * math.pi * r / 66)
		for i = 0, cnt - 1 do
			local a = i / cnt * math.pi * 2
			put(
				fPool,
				string.format("PoolE%d_%d", pi, i),
				CFrame.new(cx + math.cos(a) * r, gy + 6, cz + math.sin(a) * r) * CFrame.Angles(0, -a, 0),
				Vector3.new(42, 12, 72)
			)
		end
		-- 물판. 반사로 하늘과 탑을 담는다
		local w = put(
			fPool,
			"Pool" .. pi,
			CFrame.new(cx, gy + 2, cz),
			Vector3.new(r * 1.82, 5, r * 1.82),
			M.Glass,
			WATER
		)
		w.Reflectance = 0.55
		w.Transparency = 0.25
	end
end

--=== 조각상 받침 ===--
local fSta = sub("Statue")
for si, st in ipairs(STATUES) do
	local cx, cz = polar(st[1], st[2])
	local gy = ground(cx, cz)
	if gy then
		local bh, lh = st[3], st[4]
		put(fSta, "StaB" .. si, CFrame.new(cx, gy + bh / 2, cz) * CFrame.Angles(0, math.rad(st[1]), 0), Vector3.new(70, bh, 70))
		put(fSta, "StaC" .. si, CFrame.new(cx, gy + bh + 6, cz) * CFrame.Angles(0, math.rad(st[1]) + 0.3, 0), Vector3.new(56, 12, 56))
		-- 상은 발목에서 부러졌다. 두 다리만 남는다
		for k = -1, 1, 2 do
			put(
				fSta,
				string.format("StaL%d_%d", si, k),
				CFrame.new(cx + math.cos(math.rad(st[1] + 90)) * 14 * k, gy + bh + 12 + lh / 2, cz + math.sin(math.rad(st[1] + 90)) * 14 * k)
					* CFrame.Angles(0, math.rad(st[1]), 0),
				Vector3.new(18, lh, 20)
			)
		end
		-- 떨어진 상반신은 받침 옆에 엎어져 있다
		local a2 = math.rad(st[1] + 150)
		put(
			fSta,
			"StaF" .. si,
			CFrame.new(cx + math.cos(a2) * 88, gy + 16, cz + math.sin(a2) * 88) * CFrame.Angles(1.4, a2, 0.2),
			Vector3.new(34, 74, 30)
		)
	end
end

--=== 가장자리 성벽 ===--
local fEdge = sub("EdgeWall")
for ei, ed in ipairs(EDGE) do
	local a0, a1, r, keep = ed[1], ed[2], ed[3], ed[4]
	local span = (a1 - a0) % 360
	local cnt = math.max(math.floor(span * math.pi / 180 * r / 76), 6)
	for i = 0, cnt do
		local ang = a0 + span * (i / cnt)
		local px, pz = polar(ang, r)
		local gy = ground(px, pz)
		if gy and rng:NextNumber() < keep + 0.25 then
			local h = (rng:NextNumber() < keep) and rng:NextInteger(3, 5) or rng:NextInteger(1, 2)
			for k = 0, h - 1 do
				put(
					fEdge,
					string.format("Wall%d_%d_%d", ei, i, k),
					CFrame.new(px, gy + 8 + k * 18, pz)
						* CFrame.Angles(0, -math.rad(ang), 0)
						* CFrame.Angles(0, 0, rng:NextNumber(-0.04, 0.04)),
					Vector3.new(34, 18, 82)
				)
			end
		end
	end
	task.wait()
end

--=== 떠 있는 바위 ===--
-- 돌지 않는다. 신이 내려앉던 자리라는 표시일 뿐이다
local fFlo = sub("Floater")
for fi, fl in ipairs(FLOATERS) do
	local cx, cz = polar(fl[1], fl[2])
	local gy = ground(cx, cz)
	if gy then
		local s = fl[4]
		put(
			fFlo,
			"Flo" .. fi,
			CFrame.new(cx, gy + fl[3], cz)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), math.rad(fl[1]), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(s, s * 0.52, s * 0.86)
		)
		-- 밑에 딸린 작은 파편 둘. 하나만 뜨면 판때기로 보인다
		for k = 1, 2 do
			put(
				fFlo,
				string.format("FloC%d_%d", fi, k),
				CFrame.new(cx + rng:NextNumber(-s, s), gy + fl[3] - s * rng:NextNumber(0.5, 1.1), cz + rng:NextNumber(-s, s))
					* CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
				Vector3.new(s * 0.3, s * 0.22, s * 0.34)
			)
		end
	end
end

--=== 빛 기둥 ===--
local fBea = sub("Beacon")
for bi, ang in ipairs(BEACONS) do
	local cx, cz = polar(ang, RING)
	local gy = ground(cx, cz)
	if gy then
		for k = 0, 1 do
			put(
				fBea,
				string.format("BeaB%d_%d", bi, k),
				CFrame.new(cx, gy + 7 + k * 14, cz) * CFrame.Angles(0, k * 0.4, 0),
				Vector3.new(64 - k * 16, 14, 64 - k * 16)
			)
		end
		local beam = put(
			fBea,
			"Beam" .. bi,
			CFrame.new(cx, gy + 28 + 190, cz),
			Vector3.new(13, 380, 13),
			M.Neon,
			GLOW
		)
		beam.Transparency = 0.35
		local l = Instance.new("PointLight")
		l.Color = GLOW
		l.Range = 52
		l.Brightness = 2.5
		l.Shadows = false
		l.Parent = beam
	end
end

--=== 화로 ===--
local fBra = sub("Brazier")
for wi, ang in ipairs(WAYS) do
	local a = math.rad(ang)
	local nx, nz = -math.sin(a), math.cos(a)
	for di, d in ipairs(BRAZIER_AT) do
		for side = -1, 1, 2 do
			local px = X + math.cos(a) * d + nx * side * BRAZIER_OFF
			local pz = Z + math.sin(a) * d + nz * side * BRAZIER_OFF
			local gy = ground(px, pz)
			if gy then
				put(fBra, string.format("BrB%d_%d_%d", wi, di, side), CFrame.new(px, gy + 6, pz), Vector3.new(34, 12, 34))
				put(fBra, string.format("BrS%d_%d_%d", wi, di, side), CFrame.new(px, gy + 26, pz), Vector3.new(15, 30, 15))
				put(fBra, string.format("BrP%d_%d_%d", wi, di, side), CFrame.new(px, gy + 46, pz), Vector3.new(40, 12, 40))
				local fire = put(
					fBra,
					string.format("BrF%d_%d_%d", wi, di, side),
					CFrame.new(px, gy + 55, pz) * CFrame.Angles(0.2, side, 0.2),
					Vector3.new(24, 14, 24),
					M.Neon,
					GLOW
				)
				local l = Instance.new("PointLight")
				l.Color = GLOW
				l.Range = 44
				l.Brightness = 2.2
				l.Shadows = false
				l.Parent = fire
			end
		end
	end
end

--=== 자갈 무더기 ===--
local fRub = sub("Rubble")
for ri, ru in ipairs(RUBBLE) do
	local cx, cz = polar(ru[1], ru[2])
	local s = ru[3]
	for k = 1, 7 do
		local a2 = math.rad(ru[1] + k * 51)
		local d = s * rng:NextNumber(0.15, 1.05)
		local px, pz = cx + math.cos(a2) * d, cz + math.sin(a2) * d
		local gy = ground(px, pz)
		if gy then
			local q = s * rng:NextNumber(0.22, 0.5)
			put(
				fRub,
				string.format("Rub%d_%d", ri, k),
				CFrame.new(px, gy + q * 0.3, pz)
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), a2, rng:NextNumber(-0.5, 0.5)),
				Vector3.new(q, q * 0.7, q * 0.9)
			)
		end
	end
end

--=== 자기검사 ===--
assert(n > 900, "채운 것이 " .. n .. "개뿐이다")
for _, f in ipairs(root:GetChildren()) do
	assert(#f:GetChildren() > 0, f.Name .. " 이 비었다. 지면을 못 찾았을 수 있다")
end
-- 안쪽 유적 구역을 침범하면 안 된다. 화로만 예외로 참배로 위에 선다
for _, f in ipairs(root:GetChildren()) do
	if f.Name ~= "Brazier" and f.Name ~= "Floater" then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") then
				local d = math.sqrt((p.Position.X - X) ^ 2 + (p.Position.Z - Z) ^ 2)
				assert(d > KEEP_IN - 120, f.Name .. "/" .. p.Name .. " 이 안쪽 유적을 침범했다 (" .. math.floor(d) .. ")")
			end
		end
	end
end

local rep = {}
for _, f in ipairs(root:GetChildren()) do
	rep[#rep + 1] = f.Name .. "=" .. #f:GetChildren()
end
print(string.format("[SanctuaryFill] 파트 %d개", n))
print("[SanctuaryFill] " .. table.concat(rep, " "))
