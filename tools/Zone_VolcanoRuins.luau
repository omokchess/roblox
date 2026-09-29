--!nocheck
--[[
	Zone_VolcanoRuins.luau — 화산 섬을 재에 묻힌 도시 유적으로 채운다.

	앞선 판은 버렸다. 지적받은 네 가지가 전부 맞았다.

	1. **블록이 너무 두꺼웠다.** 캐릭터 키가 5 인데 집 벽을 두께 26 으로 세웠다.
	   사람 키의 다섯 배 두꺼운 벽이다. 그래서 이 파일은 사람 치수에서 출발한다.
	   아래 T 표가 그것이고, 집 벽은 2, 성벽도 6 을 넘지 않는다.

	2. **디테일이 없었다.** 벽이 통짜 한 장이었다. 이제 벽은 칸으로 나뉘고
	   칸마다 문, 창, 막힌 벽 중 하나다. 창에는 창턱과 상인방과 창살이 있다.

	3. **떠 있었다.** 가운데 한 점만 재고 넓은 판을 깔았기 때문이다.
	   이제 건물마다 발밑 아홉 점을 재서 가장 낮은 데보다 아래까지 기초를 내린다.
	   마지막에 모든 파트의 밑면에서 아래로 광선을 쏴 뜬 것을 센다.

	4. **받치는 것이 없었다.** 상인방과 지붕이 허공에 걸려 있었다.
	   가로로 걸리는 부재는 그 아래 기둥이나 벽이 먼저 서고, 기둥에는 주초를 깐다.

	화산 섬 실측. 가운데로 물이 파고든 만이 있어 자리를 가려 적어야 한다.
	  북쪽 벌판  z -10750..-10050  x -4600..-2600
	  남쪽 벌판  z -7350..-6650    x -4900..-2500
	  동쪽 팔    z -9700..-8500    x -3200..-1600
	  서쪽 팔    z -9300..-8500    x -6050..-5450
	  허리       z -8400..-8200    x -4700..-3300 이 통한다

	되돌리기: workspace.Surface.Ruins_화산:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

--=== 사람 치수에서 뽑은 값. 이 표를 벗어나지 않는다 ===--
local T = {
	WALL = 2, -- 집 벽 두께
	WALL_BIG = 4, -- 신전 벽 두께
	RAMPART = 6, -- 성벽 두께
	STOREY = 14, -- 한 층 높이
	DOOR_W = 9,
	DOOR_H = 9,
	SILL = 5, -- 창턱 높이
	WIN_H = 6, -- 창 높이
	COL_R = 5, -- 집 기둥 반지름
	COL_R_BIG = 9, -- 신전 기둥 반지름
	TILE = 340, -- 넓은 바닥을 쪼갤 때 한 판의 한도
}

local STONE = RGB(104, 100, 102)
local STONE_D = RGB(62, 58, 62)
local ASH = RGB(158, 152, 144)
local ASH_D = RGB(116, 110, 104)
local OBSID = RGB(34, 32, 38)
local BRONZE = RGB(150, 120, 72)
local TIMBER = RGB(74, 58, 46)
local TRAVERTINE = RGB(206, 200, 182)

local S = workspace.Surface
local G = S.World["G_화산"]

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

for _, nm in ipairs({ "Zone_화산", "Ruins_화산" }) do
	local old = S:FindFirstChild(nm)
	if old then
		old:Destroy()
	end
end
local ROOT = Instance.new("Folder")
ROOT.Name = "Ruins_화산"
ROOT.Parent = S

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = ROOT
	return f
end

local F_temple, F_forum = folder("대신전"), folder("광장")
local F_house, F_civic = folder("주거지구"), folder("공공")
local F_wall, F_mono = folder("성벽"), folder("비석")
local F_debris = folder("잔해")
local F_fire, F_street = folder("불의신전"), folder("길")

local miss = {}
local function ground(x, z, tag)
	local h = workspace:Raycast(Vector3.new(x, 1400, z), Vector3.new(0, -2400, 0), rp)
	if not h then
		miss[#miss + 1] = string.format("%s (%d, %d)", tag, x, z)
		return nil
	end
	return h.Position.Y
end
local function gq(x, z)
	local h = workspace:Raycast(Vector3.new(x, 1400, z), Vector3.new(0, -2400, 0), rp)
	return h and h.Position.Y or nil
end

-- 출력 창을 못 볼 때도 결과를 알 수 있게 탐색기에 이름으로 남긴다
local function report(msg)
	for _, v in ipairs(workspace:GetChildren()) do
		if v:IsA("StringValue") and v.Name:sub(1, 6) == "REPORT" then
			v:Destroy()
		end
	end
	local v = Instance.new("StringValue")
	v.Name = "REPORT " .. msg
	v.Value = msg
	v.Parent = workspace
end
local function fail(msg)
	report("FAIL " .. msg)
	error(msg, 0)
end

local n = 0
local function put(f, name, cf, size, color, mat)
	if not (size.X <= 400 and size.Y <= 400 and size.Z <= 400) then
		fail(name .. " 가 400 을 넘는다 " .. tostring(size))
	end
	if not (size.X > 0 and size.Y > 0 and size.Z > 0) then
		fail(name .. " 크기가 0 이하다 " .. tostring(size))
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Basalt
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = f
	n = n + 1
	return p
end

local rng = Random.new(20260912)

-- 발밑 아홉 점을 재서 가장 낮은 데와 가장 높은 데를 돌려준다.
-- 한 점이라도 바다면 nil. 건물이 물에 발을 담그지 않게 하려는 것이다
local function span(x, z, w, d)
	local lo, hi = 1e9, -1e9
	for ix = -1, 1 do
		for iz = -1, 1 do
			local g = gq(x + ix * w * 0.46, z + iz * d * 0.46)
			if not g then
				return nil
			end
			lo, hi = math.min(lo, g), math.max(hi, g)
		end
	end
	return lo, hi
end

-- 넓은 바닥을 한 변이 제각각인 판으로 쪼개 깐다. 크기를 굳이 맞추지 않는다.
-- **몇 조각으로 나눌지 먼저 정하고 그만큼만 돈다.** while 로 남은 길이를 깎아 가면
-- 값이 이상할 때 영원히 돌 수 있다. 한 번 그걸로 스튜디오가 멈췄다
local function cuts(total, maxc)
	maxc = maxc or T.TILE
	if not (total == total) or total <= 0 then
		return {}
	end
	local n = math.max(1, math.ceil(total / maxc))
	local out, left = {}, total
	for i = 1, n do
		local rest = n - i
		if rest == 0 then
			out[i] = left
		else
			-- 남은 조각도 최소 길이를 챙겨 둔다
			local lo = math.max(left / (rest + 1) * 0.55, 1)
			local hi = math.min(maxc, left - rest * 1)
			local c = (hi > lo) and rng:NextNumber(lo, hi) or math.max(hi, 1)
			out[i] = c
			left = left - c
		end
	end
	return out
end

-- yTop 이 윗면, thick 이 두께다. 두꺼우면 400 아래로 나눠 쌓는다
local function paveRect(f, name, cx, cz, w, d, yTop, thick, colA, colB, mat)
	local layers = math.max(1, math.ceil(thick / 380))
	local xs, zs = cuts(w), cuts(d)
	local ox = -w / 2
	for i, cw in ipairs(xs) do
		local oz = -d / 2
		for j, cd in ipairs(zs) do
			for L = 0, layers - 1 do
				put(f, string.format("%s_%d_%d_%d", name, i, j, L),
					CFrame.new(cx + ox + cw / 2, yTop - thick + thick / layers * (L + 0.5), cz + oz + cd / 2),
					Vector3.new(cw, thick / layers, cd), colA:Lerp(colB, rng:NextNumber(0, 1)), mat)
			end
			oz = oz + cd
		end
		ox = ox + cw
	end
end

-- 기초.
-- **판마다 제 아래만 재서 그만큼만 내린다.** 발밑에서 가장 낮은 데까지
-- 한 덩이로 내리면 집보다 큰 받침대가 생긴다. 앞선 판이 그랬다.
-- 이렇게 하면 평평한 데서는 얇고, 땅이 꺼진 데만 계단처럼 내려간다
local function foundation(f, x, z, w, d, floorY)
	local xs, zs = cuts(w, 44), cuts(d, 44)
	local ox = -w / 2
	for i, cw in ipairs(xs) do
		local oz = -d / 2
		for j, cd in ipairs(zs) do
			local cx, cz = x + ox + cw / 2, z + oz + cd / 2
			local lo = 1e9
			for sx = -1, 1 do
				for sz = -1, 1 do
					local g = gq(cx + sx * cw * 0.45, cz + sz * cd * 0.45)
					if g then
						lo = math.min(lo, g)
					end
				end
			end
			if lo < 1e8 then
				local thick = math.max(4, floorY - (lo - 5))
				local layers = math.max(1, math.ceil(thick / 380))
				for L = 0, layers - 1 do
					put(f, string.format("Found_%d_%d_%d", i, j, L),
						CFrame.new(cx, floorY - thick + thick / layers * (L + 0.5), cz),
						Vector3.new(cw, thick / layers, cd), STONE_D:Lerp(OBSID, rng:NextNumber(0, 1)), M.Basalt)
				end
			end
			oz = oz + cd
		end
		ox = ox + cw
	end
end

--=== 벽 ===--
-- 벽 한 장을 칸으로 나눠 칸마다 문, 창, 막힌 벽 중 하나를 세운다.
-- plan 은 칸마다 w=벽 c=창 d=문 을 적은 문자열이다. 손으로 적는다
local function wall(f, tag, x, z, len, yawDeg, h, thick, plan, ruin, baseY, coping)
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local bays = #plan
	local bw = len / bays
	local cnt = 0
	for i = 1, bays do
		local kind = plan:sub(i, i)
		local t = (i - 0.5) / bays - 0.5
		local px, pz = x + ux * len * t, z + uz * len * t
		local gy = baseY or gq(px, pz)
		if gy then
			local hh = h
			if ruin and rng:NextNumber() < ruin then
				hh = h * rng:NextNumber(0.3, 0.75)
				if hh < T.DOOR_H + 4 then
					kind = "w"
				end
			end
			-- 한 칸 안의 조각. off 는 칸 가운데에서 좌우로 밀어 놓는 거리다
			local function at(y0, y1, wid, off)
				if y1 - y0 < 0.4 or wid < 0.4 then
					return
				end
				put(f, string.format("%s_%d_%d", tag, i, cnt),
					CFrame.new(px, (y0 + y1) / 2, pz) * CFrame.Angles(0, -yaw, 0) * CFrame.new(off or 0, 0, 0),
					Vector3.new(wid, y1 - y0, thick), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.9)), M.Basalt)
				cnt = cnt + 1
			end
			local y = gy
			if kind == "c" then
				local openW = bw * 0.5
				local jamb = (bw - openW) / 2
				at(y, y + T.SILL, bw) -- 창턱 아래 허리벽
				at(y + T.SILL, y + T.SILL + T.WIN_H, jamb, -(bw - jamb) / 2) -- 좌 선틀
				at(y + T.SILL, y + T.SILL + T.WIN_H, jamb, (bw - jamb) / 2) -- 우 선틀
				at(y + T.SILL + T.WIN_H, y + hh, bw) -- 상인방과 그 위
				if hh > T.SILL + T.WIN_H then
					put(f, string.format("%s_mul_%d", tag, i),
						CFrame.new(px, y + T.SILL + T.WIN_H / 2, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(1.2, T.WIN_H, thick * 0.7), TIMBER, M.Wood)
				end
			elseif kind == "d" then
				local openW = math.min(T.DOOR_W, bw * 0.7)
				local jamb = (bw - openW) / 2
				at(y, y + T.DOOR_H, jamb, -(bw - jamb) / 2)
				at(y, y + T.DOOR_H, jamb, (bw - jamb) / 2)
				at(y + T.DOOR_H, y + hh, bw)
			else
				at(y, y + hh, bw)
			end
			-- 여장. 성한 칸 위에만 얹는다. 무너진 칸에 얹으면 공중에 남는다
			if coping and hh >= h - 0.01 then
				for mi = 0, 1 do
					put(f, string.format("%s_merlon_%d_%d", tag, i, mi),
						CFrame.new(px, y + hh + 2.5, pz) * CFrame.Angles(0, -yaw, 0)
							* CFrame.new((mi - 0.5) * bw * 0.5, 0, 0),
						Vector3.new(bw * 0.36, 5, thick), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.8)), M.Basalt)
				end
			end
			if ruin and hh < h * 0.8 and rng:NextNumber() < 0.5 then
				local sx, sz = px - uz * (thick + 2.5), pz + ux * (thick + 2.5)
				local sgy = gq(sx, sz)
				if sgy then
					put(f, string.format("%s_spill_%d", tag, i),
						CFrame.new(sx, sgy + 1.5, sz) * CFrame.Angles(0, -yaw + rng:NextNumber(-0.4, 0.4), 0),
						Vector3.new(bw * 0.6, 3, thick * 2.4), ASH_D:Lerp(STONE_D, rng:NextNumber(0, 1)), M.Basalt)
				end
			end
		end
	end
end

--=== 집 ===--
local HOUSE_PLANS = {
	{ front = "cdc", side = "cc", back = "cwc" },
	{ front = "cdcw", side = "cwc", back = "wcw" },
	{ front = "wdc", side = "cw", back = "cc" },
	{ front = "cdc", side = "cwc", back = "cwc" },
}

local function house(fold, x, z, w, d, yawDeg, ruin)
	local lo, hi = span(x, z, w + 6, d + 6)
	if not lo then
		return false
	end
	local f = Instance.new("Folder")
	f.Name = string.format("House_%d_%d", x, z)
	f.Parent = fold
	local floor = hi + 3
	foundation(f, x, z, w + 6, d + 6, floor)
	paveRect(f, "Floor", x, z, w, d, floor + 1, 2, ASH, ASH_D, M.Sandstone)

	local pl = HOUSE_PLANS[1 + math.floor(rng:NextNumber(0, #HOUSE_PLANS - 0.01))]
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local h = T.STOREY

	wall(f, "Front", x + vx * d / 2, z + vz * d / 2, w, yawDeg, h, T.WALL, pl.front, ruin, floor + 1)
	wall(f, "Back", x - vx * d / 2, z - vz * d / 2, w, yawDeg, h, T.WALL, pl.back, ruin, floor + 1)
	wall(f, "SideL", x - ux * w / 2, z - uz * w / 2, d, yawDeg + 90, h, T.WALL, pl.side, ruin, floor + 1)
	wall(f, "SideR", x + ux * w / 2, z + uz * w / 2, d, yawDeg + 90, h, T.WALL, pl.side, ruin, floor + 1)
	wall(f, "Part", x, z, w, yawDeg, h * 0.9, T.WALL, "wdw", ruin, floor + 1)

	-- 모서리 기둥. 얇은 벽을 받친다
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local px = x + ux * w / 2 * sx + vx * d / 2 * sz
			local pz = z + uz * w / 2 * sx + vz * d / 2 * sz
			local gy = floor + 1
			if gy then
				local ch = (rng:NextNumber() < ruin * 0.6) and h * rng:NextNumber(0.4, 0.8) or h
				put(f, "Corner", CFrame.new(px, gy + ch / 2, pz) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(T.COL_R, ch, T.COL_R), STONE, M.Basalt)
			end
		end
	end

	-- 지붕. 남았으면 보와 마룻대가 걸리고 아니면 바닥에 떨어져 있다
	if rng:NextNumber() > ruin then
		local beams = math.max(2, math.floor(w / 18))
		for i = 0, beams - 1 do
			local t = (i + 0.5) / beams - 0.5
			put(f, "Beam_" .. i,
				CFrame.new(x + ux * w * t, floor + h + 1.5, z + uz * w * t) * CFrame.Angles(0, -yaw, 0),
				Vector3.new(3, 3, d + 3), TIMBER, M.Wood)
		end
		put(f, "Ridge", CFrame.new(x, floor + h + 4.5, z) * CFrame.Angles(0, -yaw, 0),
			Vector3.new(w + 3, 3, 4), TIMBER, M.Wood)
		put(f, "Tiles", CFrame.new(x + ux * w * 0.18, floor + h + 3.5, z + uz * w * 0.18) * CFrame.Angles(0, -yaw, 0),
			Vector3.new(w * 0.45, 2, d * 0.66), STONE_D, M.Slate)
	else
		local gy = gq(x, z) or floor
		put(f, "RoofFallen", CFrame.new(x, gy + 5, z) * CFrame.Angles(0, -yaw + 0.2, 0),
			Vector3.new(w * 0.55, 3, d * 0.55), STONE_D, M.Slate)
		for i = 1, 3 do
			local px, pz = x + rng:NextNumber(-w / 3, w / 3), z + rng:NextNumber(-d / 3, d / 3)
			local g2 = gq(px, pz)
			if g2 then
				put(f, "Timber_" .. i, CFrame.new(px, g2 + 1.5, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					Vector3.new(rng:NextNumber(14, 28), 3, 3), TIMBER, M.Wood)
			end
		end
	end
	return true
end

-- 한 블록. 골목으로 띄운 안에 집을 줄지어 앉힌다
local function insula(x, z, cols, rows, yawDeg, ruin)
	local hw, hd = 52, 42
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local g = Instance.new("Folder")
	g.Name = string.format("Insula_%d_%d", x, z)
	g.Parent = F_house
	local made = 0
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local ox = (i - (cols - 1) / 2) * (hw + 10)
			local oz = (j - (rows - 1) / 2) * (hd + 10)
			local px = x + ux * ox + vx * oz
			local pz = z + uz * ox + vz * oz
			if house(g, px, pz, hw, hd, yawDeg + rng:NextNumber(-3, 3), ruin) then
				made = made + 1
			end
		end
	end
	return made
end

--=== 기둥과 처마 ===--
local function colonnade(f, tag, x, z, dirDeg, cnt, gap, h, rad, ruin, baseY)
	local yaw = math.rad(dirDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	for i = 0, cnt - 1 do
		local px, pz = x + ux * gap * i, z + uz * gap * i
		local gy = baseY or gq(px, pz)
		if gy then
			local r = rng:NextNumber()
			local hh = h
			if r < ruin then
				hh = h * rng:NextNumber(0.2, 0.6)
			elseif r < ruin * 1.3 then
				hh = 0
			end
			put(f, string.format("%s_base_%d", tag, i), CFrame.new(px, gy + 1.5, pz),
				Vector3.new(rad * 2.8, 3, rad * 2.8), STONE_D, M.Basalt)
			if hh > 0 then
				local drums = math.max(2, math.floor(hh / 12))
				for k = 0, drums - 1 do
					local dh = hh / drums
					put(f, string.format("%s_drum_%d_%d", tag, i, k),
						CFrame.new(px, gy + 3 + dh * (k + 0.5), pz) * CFrame.Angles(0, rng:NextNumber(-0.04, 0.04), 0),
						Vector3.new(rad * 2, dh + 0.3, rad * 2), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.7)), M.Basalt)
				end
				put(f, string.format("%s_cap_%d", tag, i), CFrame.new(px, gy + 4.5 + hh, pz),
					Vector3.new(rad * 2.7, 3, rad * 2.7), ASH_D, M.Basalt)
			else
				local a = yaw + math.pi / 2 + rng:NextNumber(-0.3, 0.3)
				for k = 0, 3 do
					local dx2 = math.cos(a) * (rad * 2 + k * rad * 2.6)
					local dz2 = math.sin(a) * (rad * 2 + k * rad * 2.6)
					local g2 = baseY or gq(px + dx2, pz + dz2)
					if g2 then
						put(f, string.format("%s_fallen_%d_%d", tag, i, k),
							CFrame.new(px + dx2, g2 + rad, pz + dz2) * CFrame.Angles(0, -a, math.pi / 2),
							Vector3.new(rad * 2, rad * 2.4, rad * 2), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.7)), M.Basalt)
					end
				end
			end
		end
	end
end

local function architrave(f, tag, x, z, dirDeg, len, y, wid)
	local yaw = math.rad(dirDeg)
	local segs = math.max(1, math.ceil(len / 90))
	for i = 0, segs - 1 do
		local t = (i + 0.5) / segs - 0.5
		put(f, string.format("%s_arch_%d", tag, i),
			CFrame.new(x + math.cos(yaw) * len * t, y, z + math.sin(yaw) * len * t) * CFrame.Angles(0, -yaw, 0),
			Vector3.new(len / segs, 5, wid), STONE:Lerp(ASH_D, rng:NextNumber(0, 0.5)), M.Basalt)
	end
end

--=== 큰 것들 ===--

local function temple(x, z, yawDeg)
	local W, D = 250, 150
	local lo, hi = span(x, z, W + 40, D + 40)
	if not lo then miss[#miss + 1] = "대신전 자리가 바다다" return end
	local f = Instance.new("Folder")
	f.Name = "대신전"
	f.Parent = F_temple
	local top = hi + 12
	foundation(f, x, z, W + 40, D + 40, top - 8)
	paveRect(f, "Krepis1", x, z, W + 26, D + 26, top - 4, 4, STONE, STONE_D, M.Basalt)
	paveRect(f, "Krepis2", x, z, W + 12, D + 12, top, 4, STONE, STONE_D, M.Basalt)

	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local COLH, CR, GAP = 64, T.COL_R_BIG, 26
	for s = -1, 1, 2 do
		colonnade(f, "Long" .. s, x - ux * W / 2 + vx * (D / 2) * s, z - uz * W / 2 + vz * (D / 2) * s,
			yawDeg, math.floor(W / GAP) + 1, GAP, COLH, CR, 0.22, top)
		architrave(f, "Long" .. s, x + vx * (D / 2) * s, z + vz * (D / 2) * s, yawDeg, W, top + COLH + 8, CR * 2.6)
	end
	for s = -1, 1, 2 do
		colonnade(f, "Short" .. s, x + ux * (W / 2) * s - vx * D / 2, z + uz * (W / 2) * s - vz * D / 2,
			yawDeg + 90, math.floor(D / GAP) + 1, GAP, COLH, CR, 0.22, top)
		architrave(f, "Short" .. s, x + ux * (W / 2) * s, z + uz * (W / 2) * s, yawDeg + 90, D, top + COLH + 8, CR * 2.6)
	end
	local cw, cd, ch = 130, 74, 52
	wall(f, "CellaFront", x + vx * cd / 2, z + vz * cd / 2, cw, yawDeg, ch, T.WALL_BIG, "wdw", 0.1, top)
	wall(f, "CellaBack", x - vx * cd / 2, z - vz * cd / 2, cw, yawDeg, ch, T.WALL_BIG, "wcw", 0.25, top)
	wall(f, "CellaL", x - ux * cw / 2, z - uz * cw / 2, cd, yawDeg + 90, ch, T.WALL_BIG, "cwc", 0.25, top)
	wall(f, "CellaR", x + ux * cw / 2, z + uz * cw / 2, cd, yawDeg + 90, ch, T.WALL_BIG, "cwc", 0.25, top)
	put(f, "Pedestal", CFrame.new(x - vx * cd * 0.26, top + 6, z - vz * cd * 0.26),
		Vector3.new(26, 12, 20), OBSID, M.Slate)
	put(f, "Feet", CFrame.new(x - vx * cd * 0.26, top + 16, z - vz * cd * 0.26),
		Vector3.new(14, 8, 10), BRONZE, M.CorrodedMetal)
	-- 앞 계단. 기단 밖 자연 지면 위이므로 단마다 발밑을 재서 아래까지 채운다
	for i = 1, 5 do
		local sx = x + vx * (D / 2 + 14 + i * 7)
		local sz = z + vz * (D / 2 + 14 + i * 7)
		local slo = span(sx, sz, W * 0.5, 7)
		if slo then
			local yTop = top - i * 3.4
			paveRect(f, "Stair" .. i, sx, sz, W * 0.5, 7, yTop, math.max(5, yTop - (slo - 5)), STONE, ASH_D, M.Basalt)
		end
	end
end

local function theatre(x, z, r, rows, faceDeg)
	local lo, hi = span(x, z, r * 2, r * 2)
	if not lo then miss[#miss + 1] = "극장 자리가 바다다" return end
	local f = Instance.new("Folder")
	f.Name = "극장"
	f.Parent = F_civic
	local face = math.rad(faceDeg)
	local base = hi + 2
	for row = 0, rows - 1 do
		local rr = r * (0.34 + 0.66 * row / (rows - 1))
		local cnt = math.max(8, math.floor(rr * 0.22))
		local y = base + row * 5
		for i = 0, cnt do
			local a = face - math.pi / 2 + math.pi * i / cnt
			local px, pz = x + math.cos(a) * rr, z + math.sin(a) * rr
			local gy = gq(px, pz)
			if gy then
				local hgt = math.max(5, y - (gy - 4))
				put(f, string.format("Seat_%d_%d", row, i),
					CFrame.new(px, y - hgt / 2, pz) * CFrame.Angles(0, -a, 0),
					Vector3.new(9, hgt, math.pi * rr / cnt * 1.3), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.6)), M.Basalt)
			end
		end
	end
	local sx, sz = x + math.cos(face) * r * 0.16, z + math.sin(face) * r * 0.16
	local slo, shi = span(sx, sz, r * 0.9, r * 0.42)
	if slo then
		foundation(f, sx, sz, r * 0.9, r * 0.42, shi + 2)
		wall(f, "Scaena", sx + math.cos(face) * r * 0.2, sz + math.sin(face) * r * 0.2,
			r * 0.8, faceDeg + 90, 22, T.WALL_BIG, "cwdwc", 0.4, shi + 2)
	end
end

local function cistern(x, z, w, d)
	local lo, hi = span(x, z, w + 20, d + 20)
	if not lo then miss[#miss + 1] = "저수조 자리가 바다다" return end
	local f = Instance.new("Folder")
	f.Name = "저수조"
	f.Parent = F_civic
	local rim = hi + 4
	foundation(f, x, z, w + 20, d + 20, rim - 16)
	paveRect(f, "Basin", x, z, w, d, rim - 14, 3, OBSID, STONE_D, M.Slate)
	wall(f, "N", x, z + d / 2, w, 0, 18, T.WALL_BIG, "wwww", 0.2, rim - 14)
	wall(f, "S", x, z - d / 2, w, 0, 18, T.WALL_BIG, "wwww", 0.2, rim - 14)
	wall(f, "E", x + w / 2, z, d, 90, 18, T.WALL_BIG, "www", 0.2, rim - 14)
	wall(f, "W", x - w / 2, z, d, 90, 18, T.WALL_BIG, "www", 0.2, rim - 14)
	for ix = -1, 1 do
		for iz = -1, 1, 2 do
			local px, pz = x + ix * w * 0.3, z + iz * d * 0.26
			put(f, string.format("Pier_%d_%d", ix, iz), CFrame.new(px, rim - 14 + 9, pz),
				Vector3.new(6, 18, 6), STONE, M.Basalt)
		end
	end
	for ix = -1, 1 do
		put(f, "Lintel_" .. ix, CFrame.new(x + ix * w * 0.3, rim - 14 + 19.5, z),
			Vector3.new(5, 3, d * 0.56), STONE_D, M.Basalt)
	end
end

local function gate(x, z, yawDeg)
	local lo, hi = span(x, z, 90, 40)
	if not lo then miss[#miss + 1] = "성문 자리가 바다다" return end
	local f = Instance.new("Folder")
	f.Name = "성문"
	f.Parent = F_civic
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local floor = hi + 2
	foundation(f, x, z, 90, 40, floor)
	local OPEN, PIER, H = 18, 20, 34
	for s = -1, 1, 2 do
		local px, pz = x + ux * (OPEN / 2 + PIER / 2) * s, z + uz * (OPEN / 2 + PIER / 2) * s
		put(f, "Pier_" .. s, CFrame.new(px, floor + H / 2, pz) * CFrame.Angles(0, -yaw, 0),
			Vector3.new(PIER, H, 26), STONE, M.Basalt)
		put(f, "PierCap_" .. s, CFrame.new(px, floor + H + 2, pz) * CFrame.Angles(0, -yaw, 0),
			Vector3.new(PIER + 4, 4, 30), STONE_D, M.Basalt)
	end
	put(f, "Lintel", CFrame.new(x, floor + H - 3, z) * CFrame.Angles(0, -yaw, 0),
		Vector3.new(OPEN + 8, 6, 26), STONE_D, M.Basalt)
	put(f, "Attic", CFrame.new(x, floor + H + 6, z) * CFrame.Angles(0, -yaw, 0),
		Vector3.new(OPEN + PIER, 8, 22), STONE, M.Basalt)
	local gx, gz = x + ux * 40, z + uz * 40
	local g2 = gq(gx, gz)
	if g2 then
		put(f, "Debris", CFrame.new(gx, g2 + 3, gz) * CFrame.Angles(0, -yaw + 0.5, math.rad(12)),
			Vector3.new(22, 6, 18), STONE_D, M.Basalt)
	end
end

local function obelisk(x, z, h, fallen)
	local lo, hi = span(x, z, 22, 22)
	if not lo then
		miss[#miss + 1] = string.format("비석 (%d, %d)", x, z)
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Obelisk_%d_%d", x, z)
	f.Parent = F_mono
	foundation(f, x, z, 22, 22, hi + 2)
	put(f, "Plinth", CFrame.new(x, hi + 5, z), Vector3.new(16, 6, 16), STONE, M.Basalt)
	local yaw = rng:NextNumber(0, math.pi)
	local segs = math.ceil(h / 40)
	if fallen then
		for k = 0, segs - 1 do
			local sh = h / segs
			local px = x + math.cos(yaw) * (12 + sh * k)
			local pz = z + math.sin(yaw) * (12 + sh * k)
			local g2 = gq(px, pz)
			if g2 then
				put(f, "Shaft_" .. k, CFrame.new(px, g2 + 4.5, pz) * CFrame.Angles(0, -yaw, math.pi / 2),
					Vector3.new(9, sh - 1, 9), OBSID:Lerp(STONE_D, rng:NextNumber(0, 0.5)), M.Slate)
			end
		end
	else
		for k = 0, segs - 1 do
			local sh = h / segs
			local t = (k + 0.5) / segs
			put(f, "Shaft_" .. k, CFrame.new(x, hi + 8 + sh * (k + 0.5), z) * CFrame.Angles(0, yaw, 0),
				Vector3.new(10 - 3 * t, sh, 10 - 3 * t), OBSID:Lerp(STONE_D, rng:NextNumber(0, 0.4)), M.Slate)
		end
		put(f, "Tip", CFrame.new(x, hi + 8 + h + 3, z) * CFrame.Angles(0, yaw, 0),
			Vector3.new(5, 6, 5), BRONZE, M.CorrodedMetal)
	end
end

local function statue(x, z)
	local lo, hi = span(x, z, 26, 26)
	if not lo then
		miss[#miss + 1] = string.format("조각상 (%d, %d)", x, z)
		return
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Statue_%d_%d", x, z)
	f.Parent = F_mono
	foundation(f, x, z, 26, 26, hi + 2)
	put(f, "Base", CFrame.new(x, hi + 5, z), Vector3.new(18, 6, 18), STONE, M.Basalt)
	put(f, "Die", CFrame.new(x, hi + 12, z), Vector3.new(13, 8, 13), STONE_D, M.Basalt)
	local yaw = rng:NextNumber(0, math.pi * 2)
	put(f, "Legs", CFrame.new(x, hi + 20, z) * CFrame.Angles(0, yaw, 0),
		Vector3.new(6, 8, 4), BRONZE:Lerp(STONE_D, 0.35), M.CorrodedMetal)
	local a = rng:NextNumber(0, math.pi * 2)
	local px, pz = x + math.cos(a) * 18, z + math.sin(a) * 18
	local g2 = gq(px, pz)
	if g2 then
		put(f, "Torso", CFrame.new(px, g2 + 3, pz) * CFrame.Angles(math.rad(84), a, 0),
			Vector3.new(7, 13, 5), BRONZE:Lerp(STONE_D, 0.5), M.CorrodedMetal)
	end
end

local function rampart(pts, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = F_wall
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yawDeg = math.deg(math.atan2(dz, dx))
		local runs = math.max(1, math.floor(len / 96))
		for k = 0, runs - 1 do
			local t = (k + 0.5) / runs
			local px, pz = a[1] + dx * t, a[2] + dz * t
			local rl = len / runs
			-- 여장은 wall 이 성한 칸 위에만 얹는다. 밖에서 얹으면 무너진 칸 위에 떠 버린다
			wall(f, string.format("R%d_%d", i, k), px, pz, rl, yawDeg, 22, T.RAMPART, "wwwwww", 0.45, nil, true)
		end
	end
end

local function debris(x, z, r, cnt, ashy)
	local f = Instance.new("Folder")
	f.Name = string.format("%s_%d_%d", ashy and "Ash" or "Rubble", x, z)
	f.Parent = F_debris
	for i = 1, cnt do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r * math.sqrt(rng:NextNumber())
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		local gy = gq(px, pz)
		if gy then
			if ashy then
				put(f, "Ash_" .. i, CFrame.new(px, gy + 1.5, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					Vector3.new(rng:NextNumber(30, 90), 3, rng:NextNumber(26, 80)),
					ASH:Lerp(ASH_D, rng:NextNumber(0, 1)), M.Sandstone)
			else
				local s = rng:NextNumber(4, 13)
				put(f, "Stone_" .. i,
					CFrame.new(px, gy + s * 0.4, pz)
						* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
					Vector3.new(s, s * 0.8, s * rng:NextNumber(0.8, 1.3)),
					STONE:Lerp(STONE_D, rng:NextNumber(0, 1)), M.Basalt)
			end
		end
	end
end

--=== 불의 신전 ===--
-- 섬 가운데, 두 만 사이 좁은 목에 선다. 신에게 불을 바치는 곳이다.
-- **지붕을 덮지 않는다.** 불이 하늘로 올라야 하므로 내실을 열어 둔다

local FIRE = RGB(255, 138, 48)
local FIRE_HOT = RGB(255, 214, 150)

-- 화로. 주초, 대, 반, 불. 위로 갈수록 좁아지고 아래가 위를 받친다
local function brazier(f, x, z, baseY, scale, lit)
	local s = scale or 1
	local y = baseY or gq(x, z)
	if not y then
		return
	end
	put(f, "BrPlinth", CFrame.new(x, y + 3 * s, z), Vector3.new(13 * s, 6 * s, 13 * s), STONE, M.Basalt)
	put(f, "BrStem", CFrame.new(x, y + 11 * s, z), Vector3.new(5 * s, 10 * s, 5 * s), BRONZE, M.CorrodedMetal)
	put(f, "BrBowl", CFrame.new(x, y + 18 * s, z), Vector3.new(14 * s, 4 * s, 14 * s), BRONZE, M.CorrodedMetal)
	if lit then
		local fl = put(f, "BrFlame", CFrame.new(x, y + 22.5 * s, z), Vector3.new(9 * s, 6 * s, 9 * s), FIRE, M.Neon)
		local l = Instance.new("PointLight")
		l.Color = FIRE
		l.Range = 44 * s
		l.Brightness = 2
		l.Parent = fl
	end
end

-- 불 제단. 세 단 위에 흑요석 화덕, 그 위에 불
local function fireAltar(f, x, z, top)
	paveRect(f, "AltStep1", x, z, 80, 80, top + 5, 5, STONE, STONE_D, M.Basalt)
	paveRect(f, "AltStep2", x, z, 64, 64, top + 10, 5, STONE, STONE_D, M.Basalt)
	paveRect(f, "AltStep3", x, z, 50, 50, top + 15, 5, STONE, STONE_D, M.Basalt)
	put(f, "Hearth", CFrame.new(x, top + 18, z), Vector3.new(36, 6, 36), OBSID, M.Slate)
	local fl = put(f, "Fire1", CFrame.new(x, top + 26, z), Vector3.new(27, 12, 27), FIRE, M.Neon)
	put(f, "Fire2", CFrame.new(x, top + 36, z), Vector3.new(17, 10, 17), FIRE:Lerp(FIRE_HOT, 0.5), M.Neon)
	put(f, "Fire3", CFrame.new(x, top + 43, z), Vector3.new(9, 6, 9), FIRE_HOT, M.Neon)
	local l = Instance.new("PointLight")
	l.Color = FIRE
	l.Range = 150
	l.Brightness = 5
	l.Parent = fl
end

-- 성역 담. 북쪽 한가운데를 문 자리로 비운다
local function precinct(f, x, z, w, d, h, gapW, baseY)
	local side = (w - gapW) / 2
	local function rep(len)
		return string.rep("w", math.max(2, math.floor(len / 30)))
	end
	wall(f, "PN_L", x - (gapW / 2 + side / 2), z + d / 2, side, 0, h, T.RAMPART, rep(side), 0.3, baseY, true)
	wall(f, "PN_R", x + (gapW / 2 + side / 2), z + d / 2, side, 0, h, T.RAMPART, rep(side), 0.3, baseY, true)
	wall(f, "PS", x, z - d / 2, w, 0, h, T.RAMPART, rep(w), 0.35, baseY, true)
	wall(f, "PE", x + w / 2, z, d, 90, h, T.RAMPART, rep(d), 0.35, baseY, true)
	wall(f, "PW", x - w / 2, z, d, 90, h, T.RAMPART, rep(d), 0.35, baseY, true)
end

local function fireTemple(x, z, PW, PD, W, D)
	PW, PD = PW or 400, PD or 200
	W, D = W or 180, D or 110
	local lo, hi = span(x, z, PW, PD)
	if not lo then
		miss[#miss + 1] = "불의 신전 자리가 바다다"
		return
	end
	local f = Instance.new("Folder")
	f.Name = "불의신전"
	f.Parent = F_fire

	-- 성역 마당
	local top = hi + 10
	foundation(f, x, z, PW - 40, PD - 40, top - 6)
	paveRect(f, "Court", x, z, PW - 48, PD - 48, top, 6, ASH, ASH_D, M.Sandstone)
	precinct(f, x, z, PW - 48, PD - 48, 20, 76, top)

	-- 본체 기단 두 단
	paveRect(f, "Krepis", x, z, W + 26, D + 26, top + 7, 7, STONE, STONE_D, M.Basalt)
	local ptop = top + 14
	paveRect(f, "Stylo", x, z, W + 13, D + 13, ptop, 7, STONE, STONE_D, M.Basalt)

	-- 주랑. 네 변에 돌리고 처마는 기둥 머리 높이에 맞춘다
	local COLH, CR, GAP = 52, 8, 26
	for s = -1, 1, 2 do
		colonnade(f, "L" .. s, x - W / 2, z + (D / 2) * s, 0, math.floor(W / GAP) + 1, GAP, COLH, CR, 0.18, ptop)
		architrave(f, "L" .. s, x, z + (D / 2) * s, 0, W, ptop + COLH + 60 - 52, CR * 2.6)
	end
	for s = -1, 1, 2 do
		colonnade(f, "S" .. s, x + (W / 2) * s, z - D / 2, 90, math.floor(D / GAP) + 1, GAP, COLH, CR, 0.18, ptop)
		architrave(f, "S" .. s, x + (W / 2) * s, z, 90, D, ptop + COLH + 8, CR * 2.6)
	end

	-- 내실. 남쪽에 큰 문 하나, 나머지는 창. 지붕은 없다
	local cw, cd, ch = math.floor(W * 0.62), math.floor(D * 0.62), 44
	wall(f, "CellaS", x, z - cd / 2, cw, 0, ch, T.WALL_BIG, "wcdcw", 0.12, ptop)
	wall(f, "CellaN", x, z + cd / 2, cw, 0, ch, T.WALL_BIG, "wcwcw", 0.18, ptop)
	wall(f, "CellaE", x + cw / 2, z, cd, 90, ch, T.WALL_BIG, "cwc", 0.18, ptop)
	wall(f, "CellaW", x - cw / 2, z, cd, 90, ch, T.WALL_BIG, "cwc", 0.18, ptop)

	fireAltar(f, x, z, ptop)

	-- 내실 네 귀 화로
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			brazier(f, x + sx * (cw / 2 - 22), z + sz * (cd / 2 - 20), ptop, 1, true)
		end
	end
	-- 기단 네 귀에도 큰 화로
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			brazier(f, x + sx * (W / 2 + 2), z + sz * (D / 2 + 2), ptop, 1.3, true)
		end
	end

	-- 남쪽 계단. 기단에서 마당으로 내려간다
	for i = 1, 4 do
		local sz = z - (D / 2 + 12 + i * 8)
		local yTop = ptop - i * 3.5
		paveRect(f, "Stair" .. i, x, sz, W * 0.55, 8, yTop, yTop - (top - 7), STONE, ASH_D, M.Basalt)
	end

	-- 북쪽 문. 담을 비운 자리에 선다
	do
		local gz = z + (PD - 48) / 2
		local OPEN, PIER, H = 30, 22, 40
		for s = -1, 1, 2 do
			local px = x + (OPEN / 2 + PIER / 2) * s
			put(f, "PropPier_" .. s, CFrame.new(px, top + H / 2, gz), Vector3.new(PIER, H, 30), STONE, M.Basalt)
			put(f, "PropCap_" .. s, CFrame.new(px, top + H + 2.5, gz), Vector3.new(PIER + 5, 5, 34), STONE_D, M.Basalt)
			brazier(f, px + 26 * s, gz - 16, top, 1.5, true)
		end
		put(f, "PropLintel", CFrame.new(x, top + H - 4, gz), Vector3.new(OPEN + 10, 8, 30), STONE_D, M.Basalt)
		put(f, "PropAttic", CFrame.new(x, top + H + 8, gz), Vector3.new(OPEN + PIER * 2, 8, 24), STONE, M.Basalt)
		put(f, "PropFlame", CFrame.new(x, top + H + 15, gz), Vector3.new(10, 6, 10), FIRE, M.Neon)
	end

	-- 마당에 봉헌대 여섯
	local VOTIVE = { -PW * 0.37, -PW * 0.22, -PW * 0.08, PW * 0.08, PW * 0.22, PW * 0.37 }
	for i, ox in ipairs(VOTIVE) do
		for s = -1, 1, 2 do
			local vz = z + s * (PD * 0.36)
			put(f, string.format("Votive_%d_%d", i, s), CFrame.new(x + ox, top + 6, vz),
				Vector3.new(16, 12, 16), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.8)), M.Basalt)
			if i % 2 == 1 then
				put(f, string.format("VotiveTop_%d_%d", i, s), CFrame.new(x + ox, top + 14, vz),
					Vector3.new(11, 4, 11), BRONZE, M.CorrodedMetal)
			end
		end
	end
end

--=== 폼페이 모티브 ===--
-- 참고한 것들. 포장 도로와 연석과 건널 돌, 길로 트인 가게와 판매대,
-- 아트리움 집 가운데의 빗물 받이 못, 목욕장 바닥 아래 짧은 기둥, 빵집 맷돌,
-- 성문 밖 무덤 길, 길목 분수. 자리는 모두 아래 표에 손으로 적는다

-- 포장 도로. 노면을 땅까지 채우고 양쪽에 연석, 일정 간격에 건널 돌을 놓는다
local function street(x1, z1, x2, z2, w, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = F_street
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local yawDeg = math.deg(math.atan2(dz, dx))
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local segs = math.max(1, math.ceil(len / 56))
	for i = 0, segs - 1 do
		local t = (i + 0.5) / segs
		local px, pz = x1 + dx * t, z1 + dz * t
		local sl = len / segs
		local lo, hi = span(px, pz, sl, w)
		if lo then
			local yTop = hi + 2
			local thick = math.max(4, yTop - (lo - 4))
			local layers = math.max(1, math.ceil(thick / 380))
			for L = 0, layers - 1 do
				put(f, string.format("Pave_%d_%d", i, L),
					CFrame.new(px, yTop - thick + thick / layers * (L + 0.5), pz) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(sl + 1, thick / layers, w), STONE:Lerp(STONE_D, rng:NextNumber(0.2, 0.9)), M.Cobblestone)
			end
			-- 연석
			for s = -1, 1, 2 do
				put(f, string.format("Curb_%d_%d", i, s),
					CFrame.new(px + vx * (w / 2 + 2) * s, yTop + 2, pz + vz * (w / 2 + 2) * s) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(sl + 1, 5, 4), STONE, M.Basalt)
			end
			-- 건널 돌. 비 오면 길이 물길이 되므로 사람은 이걸 밟고 건넜다
			if i % 8 == 4 then
				for k = -1, 1 do
					put(f, string.format("Cross_%d_%d", i, k),
						CFrame.new(px + vx * k * (w * 0.3), yTop + 2.5, pz + vz * k * (w * 0.3)) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(9, 6, 11), STONE, M.Basalt)
				end
			end
		end
	end
end

-- 가게. 길을 향한 앞이 트이고 ㄱ 자 판매대가 놓인다
local function shop(f, x, z, w, d, yawDeg)
	local lo, hi = span(x, z, w + 4, d + 4)
	if not lo then
		return false
	end
	local floor = hi + 3
	foundation(f, x, z, w + 4, d + 4, floor)
	paveRect(f, "Floor", x, z, w, d, floor + 1, 2, ASH, ASH_D, M.Sandstone)
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local h = T.STOREY
	-- 뒤와 옆 세 면만 세운다. 앞은 길로 트인다
	wall(f, "Back", x - vx * d / 2, z - vz * d / 2, w, yawDeg, h, T.WALL, "wcw", 0.3, floor + 1)
	wall(f, "SideL", x - ux * w / 2, z - uz * w / 2, d, yawDeg + 90, h, T.WALL, "ww", 0.3, floor + 1)
	wall(f, "SideR", x + ux * w / 2, z + uz * w / 2, d, yawDeg + 90, h, T.WALL, "ww", 0.3, floor + 1)
	-- 판매대. 앞면에 붙고 한쪽이 꺾인다
	put(f, "Counter", CFrame.new(x + vx * (d / 2 - 5), floor + 5, z + vz * (d / 2 - 5)) * CFrame.Angles(0, -yaw, 0),
		Vector3.new(w * 0.7, 8, 7), STONE, M.Marble)
	put(f, "CounterL", CFrame.new(x - ux * (w / 2 - 4) + vx * (d / 2 - 14), floor + 5, z - uz * (w / 2 - 4) + vz * (d / 2 - 14))
		* CFrame.Angles(0, -yaw, 0), Vector3.new(7, 8, 16), STONE, M.Marble)
	-- 판매대에 묻힌 항아리 자리
	for k = -1, 1 do
		put(f, "Dolium_" .. k,
			CFrame.new(x + ux * k * (w * 0.2) + vx * (d / 2 - 5), floor + 9.5, z + uz * k * (w * 0.2) + vz * (d / 2 - 5))
				* CFrame.Angles(0, -yaw, 0),
			Vector3.new(6, 2, 6), OBSID, M.Slate)
	end
	-- 앞을 막던 나무 문틀. 위에만 남았다
	put(f, "Lintel", CFrame.new(x + vx * d / 2, floor + h, z + vz * d / 2) * CFrame.Angles(0, -yaw, 0),
		Vector3.new(w, 4, T.WALL), TIMBER, M.Wood)
	for s = -1, 1, 2 do
		put(f, "Jamb_" .. s, CFrame.new(x + ux * (w / 2) * s + vx * d / 2, floor + h / 2 + 1, z + uz * (w / 2) * s + vz * d / 2)
			* CFrame.Angles(0, -yaw, 0), Vector3.new(4, h - 2, T.WALL), STONE, M.Basalt)
	end
	return true
end

-- 아트리움 집. 가운데 마당에 빗물 받이 못이 있고 네 기둥이 지붕 구멍을 받쳤다
local function atriumHouse(fold, x, z, w, d, yawDeg, ruin)
	local lo, hi = span(x, z, w + 6, d + 6)
	if not lo then
		return false
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Atrium_%d_%d", x, z)
	f.Parent = fold
	local floor = hi + 3
	foundation(f, x, z, w + 6, d + 6, floor)
	paveRect(f, "Floor", x, z, w, d, floor + 1, 2, ASH, ASH_D, M.Sandstone)
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local h = T.STOREY
	wall(f, "Front", x + vx * d / 2, z + vz * d / 2, w, yawDeg, h, T.WALL, "cwdwc", 0.22, floor + 1)
	wall(f, "Back", x - vx * d / 2, z - vz * d / 2, w, yawDeg, h, T.WALL, "cwcwc", ruin, floor + 1)
	wall(f, "SideL", x - ux * w / 2, z - uz * w / 2, d, yawDeg + 90, h, T.WALL, "cwc", ruin, floor + 1)
	wall(f, "SideR", x + ux * w / 2, z + uz * w / 2, d, yawDeg + 90, h, T.WALL, "cwc", ruin, floor + 1)
	-- 빗물 받이 못. 바닥보다 낮게 판 네모 물
	local iw = math.min(w, d) * 0.3
	paveRect(f, "Impluvium", x, z, iw, iw, floor + 1, 3, RGB(84, 104, 112), RGB(58, 74, 84), M.Slate)
	for s = -1, 1, 2 do
		put(f, "Lip_X" .. s, CFrame.new(x + s * (iw / 2 + 2), floor + 3, z), Vector3.new(4, 4, iw + 8), STONE, M.Marble)
		put(f, "Lip_Z" .. s, CFrame.new(x, floor + 3, z + s * (iw / 2 + 2)), Vector3.new(iw + 8, 4, 4), STONE, M.Marble)
	end
	-- 네 기둥과 그 위 보
	local cr = iw / 2 + 12
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			put(f, string.format("Col_%d_%d", sx, sz), CFrame.new(x + sx * cr, floor + 1 + h / 2, z + sz * cr),
				Vector3.new(6, h, 6), STONE, M.Marble)
		end
	end
	for sx = -1, 1, 2 do
		put(f, "Beam_" .. sx, CFrame.new(x + sx * cr, floor + 1 + h + 1.5, z), Vector3.new(5, 3, cr * 2 + 5), TIMBER, M.Wood)
	end
	-- 뒤쪽 방을 나누는 벽
	wall(f, "Part", x - vx * d * 0.26, z - vz * d * 0.26, w * 0.9, yawDeg, h * 0.85, T.WALL, "wdw", ruin, floor + 1)
	return true
end

-- 목욕장. 바닥을 들어 올리고 그 아래에 짧은 기둥을 촘촘히 세워 더운 바람을 돌렸다
local function baths(x, z, w, d)
	local lo, hi = span(x, z, w + 20, d + 20)
	if not lo then
		miss[#miss + 1] = "목욕장 자리가 바다다"
		return
	end
	local f = Instance.new("Folder")
	f.Name = "목욕장"
	f.Parent = F_civic
	local base = hi + 3
	foundation(f, x, z, w + 20, d + 20, base)
	-- 히포카우스트. 짧은 기둥이 바닥을 받친다
	local step = 14
	for ix = -math.floor(w / 2 / step), math.floor(w / 2 / step) do
		for iz = -math.floor(d / 2 / step), math.floor(d / 2 / step) do
			put(f, string.format("Pila_%d_%d", ix, iz), CFrame.new(x + ix * step, base + 6, z + iz * step),
				Vector3.new(6, 12, 6), RGB(132, 74, 58), M.Brick)
		end
	end
	paveRect(f, "Suspensura", x, z, w, d, base + 15, 3, TRAVERTINE, ASH, M.Marble)
	-- 세 칸. 더운 방, 미지근한 방, 찬 방
	local cw = w / 3
	for i = 0, 2 do
		local cx = x - w / 2 + cw * (i + 0.5)
		wall(f, "N" .. i, cx, z + d / 2, cw, 0, 26, T.WALL_BIG, "wcw", 0.3, base + 15)
		wall(f, "S" .. i, cx, z - d / 2, cw, 0, 26, T.WALL_BIG, "wcw", 0.3, base + 15)
		if i < 2 then
			wall(f, "M" .. i, x - w / 2 + cw * (i + 1), z, d, 90, 26, T.WALL_BIG, "wdw", 0.25, base + 15)
		end
	end
	wall(f, "E", x + w / 2, z, d, 90, 26, T.WALL_BIG, "cwc", 0.3, base + 15)
	wall(f, "W", x - w / 2, z, d, 90, 26, T.WALL_BIG, "cdc", 0.15, base + 15)
	-- 더운 방 욕조
	paveRect(f, "Tub", x - w / 2 + cw * 0.5, z, cw * 0.5, d * 0.45, base + 19, 4, RGB(92, 112, 120), RGB(64, 80, 90), M.Slate)
end

-- 빵집. 맷돌 셋과 돔 화덕
local function bakery(x, z)
	local lo, hi = span(x, z, 150, 110)
	if not lo then
		miss[#miss + 1] = "빵집 자리가 바다다"
		return
	end
	local f = Instance.new("Folder")
	f.Name = "빵집"
	f.Parent = F_civic
	local floor = hi + 3
	foundation(f, x, z, 150, 110, floor)
	paveRect(f, "Floor", x, z, 142, 102, floor + 1, 2, ASH, ASH_D, M.Sandstone)
	wall(f, "N", x, z + 51, 142, 0, T.STOREY, T.WALL, "wcwcw", 0.3, floor + 1)
	wall(f, "S", x, z - 51, 142, 0, T.STOREY, T.WALL, "wwdww", 0.2, floor + 1)
	wall(f, "E", x + 71, z, 102, 90, T.STOREY, T.WALL, "wcw", 0.3, floor + 1)
	wall(f, "W", x - 71, z, 102, 90, T.STOREY, T.WALL, "wcw", 0.3, floor + 1)
	-- 맷돌 셋. 아래가 넓고 위가 좁은 두 돌이 겹친다
	for i = -1, 1 do
		local mx = x + i * 34
		put(f, "MillBase_" .. i, CFrame.new(mx, floor + 4, z + 16), Vector3.new(22, 6, 22), STONE, M.Basalt)
		put(f, "MillLower_" .. i, CFrame.new(mx, floor + 11, z + 16), Vector3.new(15, 9, 15), STONE_D, M.Basalt)
		put(f, "MillUpper_" .. i, CFrame.new(mx, floor + 18, z + 16), Vector3.new(17, 6, 17), STONE, M.Basalt)
		put(f, "MillBar_" .. i, CFrame.new(mx, floor + 22, z + 16), Vector3.new(30, 3, 3), TIMBER, M.Wood)
	end
	-- 화덕. 네모를 좁혀 쌓아 돔처럼 만든다
	local ox, oz = x - 44, z - 24
	for k = 0, 4 do
		local s = 44 - k * 7
		put(f, "Oven_" .. k, CFrame.new(ox, floor + 3 + k * 6, oz), Vector3.new(s, 6, s), RGB(138, 78, 58), M.Brick)
	end
	put(f, "OvenMouth", CFrame.new(ox, floor + 8, oz + 20), Vector3.new(12, 10, 6), OBSID, M.Slate)
	local em = put(f, "OvenFire", CFrame.new(ox, floor + 7, oz + 15), Vector3.new(10, 6, 10), FIRE, M.Neon)
	local l = Instance.new("PointLight")
	l.Color = FIRE
	l.Range = 40
	l.Brightness = 1.5
	l.Parent = em
end

-- 길목 분수. 네모 수반과 물꼭지 기둥
local function fountain(x, z)
	local lo, hi = span(x, z, 30, 30)
	if not lo then
		return false
	end
	local f = Instance.new("Folder")
	f.Name = string.format("Fountain_%d_%d", x, z)
	f.Parent = F_street
	local top = hi + 2
	foundation(f, x, z, 30, 30, top)
	for s = -1, 1, 2 do
		put(f, "SlabX_" .. s, CFrame.new(x + s * 11, top + 6, z), Vector3.new(4, 12, 26), STONE, M.Marble)
		put(f, "SlabZ_" .. s, CFrame.new(x, top + 6, z + s * 11), Vector3.new(26, 12, 4), STONE, M.Marble)
	end
	paveRect(f, "Water", x, z, 18, 18, top + 8, 6, RGB(88, 116, 124), RGB(62, 84, 94), M.Slate)
	put(f, "Pillar", CFrame.new(x, top + 20, z + 13), Vector3.new(10, 28, 8), STONE, M.Marble)
	put(f, "Spout", CFrame.new(x, top + 30, z + 8), Vector3.new(4, 4, 8), BRONZE, M.CorrodedMetal)
	return true
end

-- 무덤 길. 성문 밖 길 양쪽에 작은 묘가 늘어선다
local function tombs(x1, z1, x2, z2, cnt)
	local f = Instance.new("Folder")
	f.Name = "무덤길"
	f.Parent = F_mono
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local yaw = math.atan2(dz, dx)
	local vx, vz = -math.sin(yaw), math.cos(yaw)
	for i = 0, cnt - 1 do
		for s = -1, 1, 2 do
			local t = (i + 0.5) / cnt
			local off = 26 + rng:NextNumber(0, 10)
			local px = x1 + dx * t + vx * off * s
			local pz = z1 + dz * t + vz * off * s
			local lo, hi = span(px, pz, 30, 26)
			if lo then
				local base = hi + 2
				foundation(f, px, pz, 30, 26, base)
				local kind = rng:NextNumber()
				put(f, "TombBase", CFrame.new(px, base + 4, pz) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(26, 8, 22), STONE, M.Basalt)
				if kind < 0.45 then -- 제단형
					put(f, "TombBody", CFrame.new(px, base + 14, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(20, 12, 16), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.7)), M.Basalt)
					put(f, "TombCap", CFrame.new(px, base + 22, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(23, 4, 19), STONE_D, M.Basalt)
				elseif kind < 0.8 then -- 벽감형
					put(f, "TombBody", CFrame.new(px, base + 18, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(22, 20, 8), STONE, M.Basalt)
					put(f, "TombNiche", CFrame.new(px, base + 18, pz - vz * 3) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(10, 12, 4), OBSID, M.Slate)
					put(f, "TombCap", CFrame.new(px, base + 29, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(25, 4, 11), STONE_D, M.Basalt)
				else -- 비석형
					put(f, "Stele", CFrame.new(px, base + 18, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(11, 20, 5), OBSID:Lerp(STONE_D, 0.4), M.Slate)
					put(f, "SteleCap", CFrame.new(px, base + 29, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(14, 3, 7), STONE, M.Basalt)
				end
			end
		end
	end
end

-- 팔라이스트라. 네모 마당을 기둥으로 둘러싼 운동장
local function palaestra(x, z, w, d)
	local lo, hi = span(x, z, w, d)
	if not lo then
		miss[#miss + 1] = "팔라이스트라 자리가 바다다"
		return
	end
	local f = Instance.new("Folder")
	f.Name = "팔라이스트라"
	f.Parent = F_civic
	local top = hi + 2
	foundation(f, x, z, w, d, top)
	paveRect(f, "Sand", x, z, w - 40, d - 40, top + 1, 2, RGB(178, 160, 128), RGB(146, 130, 104), M.Sand)
	local GAP = 26
	for s = -1, 1, 2 do
		colonnade(f, "PN" .. s, x - w / 2 + 20, z + (d / 2 - 16) * s, 0, math.floor((w - 40) / GAP), GAP, 30, 5, 0.3, top)
		architrave(f, "PN" .. s, x, z + (d / 2 - 16) * s, 0, w - 44, top + 37, 13)
	end
	for s = -1, 1, 2 do
		colonnade(f, "PE" .. s, x + (w / 2 - 16) * s, z - d / 2 + 20, 90, math.floor((d - 40) / GAP), GAP, 30, 5, 0.3, top)
--=== 구역 채우기 ===--
-- **자리는 네모로 적고, 그 안의 배치는 건물 치수에서 나온다.**
-- 맵을 1/3 로 줄였으므로 좌표를 손으로 하나하나 다시 적는 대신
-- 구역 네모만 적고 격자로 채운다. 칸 크기는 집 52×42 에 골목 10 을 더한 값이다
local function district(x, z, w, d, yawDeg, ruin)
	local CW, CD = 62, 52
	local nx = math.max(1, math.floor(w / CW))
	local nz = math.max(1, math.floor(d / CD))
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	local g = Instance.new("Folder")
	g.Name = string.format("Insula_%d_%d", x, z)
	g.Parent = F_house
	local made, shopped = 0, 0
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local ox = (i - (nx - 1) / 2) * CW
			local oz = (j - (nz - 1) / 2) * CD
			local px = x + ux * ox + vx * oz
			local pz = z + uz * ox + vz * oz
			-- 다섯 칸마다 한 칸은 빈 마당으로 둔다. 안 그러면 벌집처럼 보인다
			if not (i % 5 == 2 and j % 3 == 1) then
				if nz > 1 and (j == 0 or j == nz - 1) then
					-- 길을 향한 줄은 가게다. 바깥을 바라본다
					if shop(g, px, pz, 42, 32, yawDeg + (j == 0 and 180 or 0)) then
						shopped = shopped + 1
					end
				elseif (i + j) % 4 == 0 then
					if atriumHouse(g, px, pz, 52, 44, yawDeg + rng:NextNumber(-3, 3), ruin) then
						made = made + 1
					end
				else
					if house(g, px, pz, 52, 42, yawDeg + rng:NextNumber(-3, 3), ruin) then
						made = made + 1
					end
				end
			end
		end
	end
	return made, shopped
end

-- 발굴된 집터. 벽이 무릎 높이만 남았다. 넓은 데를 싸게 메운다
local function ruinField(x, z, w, d, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = F_house
	local CW, CD = 58, 48
	local nx = math.max(1, math.floor(w / CW))
	local nz = math.max(1, math.floor(d / CD))
	local cells = 0
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local px = x - w / 2 + CW * (i + 0.5)
			local pz = z - d / 2 + CD * (j + 0.5)
			local lo, hi = span(px, pz, CW - 8, CD - 8)
			if lo then
				local top = hi + 2
				local thick = math.max(4, top - (lo - 4))
				put(f, string.format("Floor_%d_%d", i, j), CFrame.new(px, top - thick / 2, pz),
					Vector3.new(CW - 8, thick, CD - 8), ASH_D:Lerp(STONE_D, rng:NextNumber(0, 1)), M.Sandstone)
				local h = rng:NextNumber(4, 9)
				wall(f, string.format("N%d_%d", i, j), px, pz + (CD - 8) / 2, CW - 8, 0, h, T.WALL, "ww", 0.5, top)
				wall(f, string.format("S%d_%d", i, j), px, pz - (CD - 8) / 2, CW - 8, 0, h, T.WALL, "ww", 0.5, top)
				wall(f, string.format("E%d_%d", i, j), px + (CW - 8) / 2, pz, CD - 8, 90, h, T.WALL, "ww", 0.5, top)
				wall(f, string.format("W%d_%d", i, j), px - (CW - 8) / 2, pz, CD - 8, 90, h, T.WALL, "ww", 0.5, top)
				if rng:NextNumber() < 0.3 then
					put(f, string.format("Stub_%d_%d", i, j), CFrame.new(px, top + 6, pz),
						Vector3.new(7, 12, 7), STONE, M.Basalt)
				end
				cells = cells + 1
			end
		end
	end
	return cells
end

-- 밭. 낮은 돌담으로 구획을 나누고 안에 포도 두둑과 지주를 줄지어 놓는다
local function vineyard(x, z, w, d, yawDeg, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = F_debris
	local yaw = math.rad(yawDeg)
	local ux, uz = math.cos(yaw), math.sin(yaw)
	local vx, vz = -uz, ux
	-- 둘레 돌담
	local function rep(len)
		return string.rep("w", math.max(2, math.floor(len / 40)))
	end
	wall(f, "FN", x + vx * d / 2, z + vz * d / 2, w, yawDeg, 6, 3, rep(w), 0.4)
	wall(f, "FS", x - vx * d / 2, z - vz * d / 2, w, yawDeg, 6, 3, rep(w), 0.4)
	wall(f, "FE", x + ux * w / 2, z + uz * w / 2, d, yawDeg + 90, 6, 3, rep(d), 0.4)
	wall(f, "FW", x - ux * w / 2, z - uz * w / 2, d, yawDeg + 90, 6, 3, rep(d), 0.4)
	-- 포도 두둑. 줄마다 흙을 돋우고 지주를 몇 개 세운다
	local rows = math.max(2, math.floor(d / 34))
	local segs = math.max(1, math.floor(w / 110))
	for r = 0, rows - 1 do
		local oz = (r - (rows - 1) / 2) * (d / rows)
		for s = 0, segs - 1 do
			local ox = (s - (segs - 1) / 2) * (w / segs)
			local px = x + ux * ox + vx * oz
			local pz = z + uz * ox + vz * oz
			local gy = gq(px, pz)
			if gy then
				put(f, string.format("Row_%d_%d", r, s), CFrame.new(px, gy + 2, pz) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(w / segs - 4, 4, 8), RGB(96, 78, 58), M.Ground)
				if s % 2 == 0 then
					put(f, string.format("Stake_%d_%d", r, s), CFrame.new(px, gy + 9, pz) * CFrame.Angles(0, -yaw, 0),
						Vector3.new(2, 14, 2), TIMBER, M.Wood)
				end
			end
		end
	end
end

-- 원형경기장. 타원으로 계단을 둘러 앉히고 두 곳을 비워 입구로 둔다
local function amphitheatre(x, z, w, d, rows)
	local lo, hi = span(x, z, w, d)
	if not lo then
		miss[#miss + 1] = "원형경기장 자리가 바다다"
		return
	end
	local f = Instance.new("Folder")
	f.Name = "원형경기장"
	f.Parent = F_civic
	local base = hi + 2
	for row = 0, rows - 1 do
		local t = row / (rows - 1)
		local rx = w / 2 * (0.40 + 0.60 * t)
		local rz = d / 2 * (0.40 + 0.60 * t)
		local cnt = math.max(10, math.floor((rx + rz) * 0.10))
		local y = base + row * 5
		for i = 0, cnt - 1 do
			local a = i / cnt * math.pi * 2
			-- 두 곳은 입구라 비운다
			if math.abs(math.cos(a)) < 0.985 then
				local px, pz = x + math.cos(a) * rx, z + math.sin(a) * rz
				local gy = gq(px, pz)
				if gy then
					local hgt = math.max(5, y - (gy - 4))
					put(f, string.format("Seat_%d_%d", row, i),
						CFrame.new(px, y - hgt / 2, pz) * CFrame.Angles(0, -a, 0),
						Vector3.new(9, hgt, (rx + rz) * math.pi / cnt * 0.62),
						STONE:Lerp(STONE_D, rng:NextNumber(0, 0.6)), M.Basalt)
				end
			end
		end
	end
	-- 경기장 바닥
	local alo, ahi = span(x, z, w * 0.36, d * 0.36)
	if alo then
		put(f, "Arena", CFrame.new(x, ahi + 1, z), Vector3.new(w * 0.36, math.max(4, ahi + 2 - (alo - 4)), d * 0.36),
			RGB(176, 158, 126), M.Sand)
	end
end

-- 수도교. 교각을 세우고 그 위에 아치와 물길을 얹는다. 아래를 걸어 지날 수 있다
local function aqueduct(x1, z1, x2, z2, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = F_civic
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local yawDeg = math.deg(math.atan2(dz, dx))
	local yaw = math.rad(yawDeg)
	local GAP = 34
	local bays = math.max(2, math.floor(len / GAP))
	-- 물길 높이는 구간에서 가장 높은 땅 위로 잡는다
	local top = -1e9
	for i = 0, bays do
		local g = gq(x1 + dx * i / bays, z1 + dz * i / bays)
		if g then
			top = math.max(top, g)
		end
	end
	if top < -1e8 then
		return
	end
	top = top + 46
	for i = 0, bays do
		local px, pz = x1 + dx * i / bays, z1 + dz * i / bays
		local gy = gq(px, pz)
		if gy then
			local h = top - 10 - gy
			if h > 6 then
				put(f, "Pier_" .. i, CFrame.new(px, gy + h / 2, pz) * CFrame.Angles(0, -yaw, 0),
					Vector3.new(11, h, 14), STONE:Lerp(STONE_D, rng:NextNumber(0, 0.7)), M.Brick)
				-- 아치 어깨. 교각 위에 얹혀 옆으로 뻗는다
				for s = -1, 1, 2 do
					put(f, string.format("Haunch_%d_%d", i, s),
						CFrame.new(px + math.cos(yaw) * 8 * s, gy + h + 3, pz + math.sin(yaw) * 8 * s)
							* CFrame.Angles(0, -yaw, 0),
						Vector3.new(10, 6, 13), STONE_D, M.Brick)
				end
			end
		end
	end
	-- 물길. 교각 위를 잇는다
	for i = 0, bays - 1 do
		local t = (i + 0.5) / bays
		local px, pz = x1 + dx * t, z1 + dz * t
		-- 양쪽 교각이 다 선 구간만 잇는다. 안 그러면 물 위에 물길만 남는다
		local ga = gq(x1 + dx * i / bays, z1 + dz * i / bays)
		local gb = gq(x1 + dx * (i + 1) / bays, z1 + dz * (i + 1) / bays)
		if ga and gb and top - 10 - ga > 6 and top - 10 - gb > 6 then
			put(f, "Channel_" .. i, CFrame.new(px, top - 5, pz) * CFrame.Angles(0, -yaw, 0),
				Vector3.new(len / bays + 1, 10, 15), STONE, M.Brick)
			put(f, "ChannelLip_" .. i, CFrame.new(px, top + 1, pz) * CFrame.Angles(0, -yaw, 0),
				Vector3.new(len / bays + 1, 4, 17), STONE_D, M.Brick)
		end
	end
end

--=== 배치표 ===--
-- 어디까지 갔는지 보이게 한 걸음마다 찍고 한 번 양보한다.
-- 한 번 어디서 멈췄는지 몰라 스튜디오를 재시작해야 했다
local step = 0
local function mark(what)
	step = step + 1
	print(string.format("[화산유적] %d. %s (파트 %d)", step, what, n))
	task.wait()
end

-- 맵을 1/3 로 줄인 뒤의 실측이다. 가운데로 물이 파고든 만이 둘 있다
--   북쪽 벌판  z -3580..-3350  x -1530..-870
--   북서        z -3300..-3060  x -1950..-1650
--   북동        z -3300..-3000  x -1150..-460
--   서쪽 팔     z -3100..-2820  x -2050..-1790
--   가운데 목   z -2880..-2760  x -1560..-1080   <- 불의 신전
--   동쪽 팔     z -3180..-3000  x -1000..-460
--   남서        z -2740..-2200  x -1880..-1280
--   남동        z -2740..-2200  x -1140..-500
--   남쪽 끝     z -2200..-2100  x -1430..-870

local houses, shops, atria = 0, 0, 0

--=== 불의 신전. 섬 가운데 목 ===--
mark("불의 신전")
fireTemple(-1320, -2820, 400, 200, 180, 110)

--=== 큰 것들 ===--
mark("대신전")
temple(-1200, -3470, 0)
mark("극장")
theatre(-760, -2400, 90, 8, 0)
mark("원형경기장")
amphitheatre(-760, -3140, 300, 230, 9)
mark("목욕장")
baths(-1450, -3450, 120, 84)
mark("빵집")
bakery(-950, -3500)
mark("팔라이스트라")
palaestra(-800, -2600, 170, 150)
mark("저수조")
cistern(-1980, -3000, 80, 60)

--=== 광장. 남서쪽 ===--
do
	local lo, hi = span(-1600, -2650, 220, 160)
	if not lo then
		fail("광장 자리가 바다다")
	end
	local f = Instance.new("Folder")
	f.Name = "광장"
	f.Parent = F_forum
	foundation(f, -1600, -2650, 220, 160, hi + 3)
	paveRect(f, "Pave", -1600, -2650, 214, 154, hi + 4, 2, ASH, ASH_D, M.Sandstone)
	paveRect(f, "AltarStep1", -1600, -2650, 40, 40, hi + 8, 5, STONE, STONE_D, M.Basalt)
	paveRect(f, "AltarStep2", -1600, -2650, 30, 30, hi + 12, 5, STONE, STONE_D, M.Basalt)
	put(f, "AltarTable", CFrame.new(-1600, hi + 16, -2650), Vector3.new(22, 8, 22), OBSID, M.Slate)
	put(f, "AltarBowl", CFrame.new(-1600, hi + 22, -2650), Vector3.new(14, 4, 14), BRONZE, M.CorrodedMetal)
	for s = -1, 1, 2 do
		colonnade(f, "Port" .. s, -1690, -2650 + s * 70, 0, 8, 26, 36, 6, 0.3, hi + 4)
		architrave(f, "Port" .. s, -1600, -2650 + s * 70, 0, 190, hi + 48, 15)
	end
end

mark("광장")

--=== 길 ===--
street(-1520, -3345, -880, -3345, 26, "북대로")
street(-1200, -3560, -1200, -3360, 22, "신전길")
street(-1140, -3160, -480, -3160, 24, "동대로")
street(-1000, -3160, -1000, -3020, 22, "동길")
street(-1860, -2700, -520, -2700, 28, "대로")
street(-1600, -2740, -1600, -2240, 24, "광장길")
street(-1320, -2740, -1320, -2600, 22, "성역길")
street(-1050, -2700, -1050, -2250, 22, "남동길")
street(-1900, -3060, -1900, -2840, 20, "서길")

mark("길")

--=== 길목 분수 ===--
for _, p in ipairs({
	{ -1200, -3370 }, { -1000, -3130 }, { -1600, -2710 },
	{ -1050, -2660 }, { -1320, -2706 },
}) do
	fountain(p[1], p[2])
end

mark("분수")

--=== 주거 구역. 네모만 적고 안은 격자로 채운다 ===--
local DISTRICTS = {
	{ -1420, -3480, 150, 190, 0, 0.30 }, -- 북쪽 벌판 서측
	{ -960, -3480, 150, 190, 0, 0.32 }, -- 북쪽 벌판 동측
	{ -1200, -3270, 600, 90, 0, 0.34 }, -- 북대로 남쪽
	{ -800, -3320, 600, 120, 0, 0.32 }, -- 북동
	{ -760, -3020, 560, 110, 0, 0.36 }, -- 북동 남측
	{ -1600, -2480, 560, 220, 0, 0.30 }, -- 남서
	{ -1620, -2280, 520, 120, 0, 0.36 }, -- 남서 남측
	{ -880, -2400, 500, 200, 0, 0.32 }, -- 남동
	{ -840, -2240, 480, 100, 0, 0.38 }, -- 남동 남측
	{ -1800, -3180, 260, 200, 0, 0.36 }, -- 북서
	{ -1900, -2880, 160, 140, 0, 0.38 }, -- 서쪽 팔
	{ -1150, -2160, 480, 100, 0, 0.40 }, -- 남쪽 끝
}
local houses2, shops2 = 0, 0
for _, b in ipairs(DISTRICTS) do
	mark("구역 " .. b[1] .. "," .. b[2])
	local h2, s2 = district(b[1], b[2], b[3], b[4], b[5], b[6])
	houses2 = houses2 + h2
	shops2 = shops2 + s2
end
houses = houses + houses2
shops = shops + shops2

mark("구역 끝")

--=== 발굴된 집터. 바깥쪽을 메운다 ===--
ruinField(-1720, -3480, 300, 110, "북서터")
ruinField(-560, -2900, 180, 200, "동터")
ruinField(-1850, -2560, 220, 260, "남서터")
ruinField(-620, -2200, 240, 110, "남동터")

mark("집터")

--=== 밭 ===--
vineyard(-1700, -3220, 260, 200, 0, "북서밭")
vineyard(-1500, -2350, 340, 200, 0, "남밭")
vineyard(-700, -2820, 260, 160, 0, "동밭")

mark("밭")

--=== 수도교. 가운데 목을 가로지른다 ===--
aqueduct(-2030, -2770, -1620, -2770, "서수도교")
aqueduct(-1020, -2770, -480, -2770, "동수도교")

mark("수도교")

--=== 무덤 길 ===--
tombs(-1520, -2706, -1100, -2706, 5)
tombs(-1200, -3340, -1200, -3180, 3)

mark("무덤")

--=== 비석과 조각상 ===--
local MONO = {
	{ -1400, -3420, 40, false }, { -1000, -3420, 40, false },
	{ -1320, -2700, 34, false }, { -900, -2260, 32, true },
	{ -1620, -2420, 30, true }, { -1880, -2860, 26, false },
	{ -660, -2820, 28, true }, { -1200, -3580, 44, false },
}
for _, o in ipairs(MONO) do
	obelisk(o[1], o[2], o[3], o[4])
end

local STATUES = {
	{ -1520, -2680 }, { -1520, -2620 }, { -1680, -2680 }, { -1680, -2620 },
	{ -1150, -3470 }, { -1250, -3470 }, { -1400, -2820 }, { -1240, -2820 },
	{ -760, -3040 }, { -1900, -2900 },
}
for _, s in ipairs(STATUES) do
	statue(s[1], s[2])
end

mark("비석")

--=== 성벽 ===--
rampart({ { -1530, -3580 }, { -880, -3580 }, { -860, -3400 } }, "북성벽")
rampart({ { -1960, -3100 }, { -1960, -2860 } }, "서성벽")
rampart({ { -1080, -3200 }, { -470, -3200 } }, "동성벽")
rampart({ { -1880, -2740 }, { -1880, -2220 }, { -1300, -2200 } }, "남서성벽")
rampart({ { -1120, -2200 }, { -520, -2220 }, { -500, -2600 } }, "남동성벽")

mark("성벽")

--=== 잔해와 재 ===--
local DEB = {
	{ -1200, -3450, 60, 20, false }, { -900, -3300, 55, 18, false },
	{ -1320, -2900, 70, 22, true }, { -1320, -2740, 60, 18, true },
	{ -700, -3100, 55, 18, false }, { -1600, -2600, 60, 20, false },
	{ -850, -2450, 55, 18, false }, { -1750, -3300, 50, 16, true },
	{ -1900, -2900, 45, 14, false }, { -600, -2700, 50, 16, true },
	{ -1150, -2200, 50, 16, false }, { -1450, -2300, 55, 18, true },
	{ -1050, -3000, 45, 14, false }, { -1700, -2750, 50, 16, true },
}
for _, d in ipairs(DEB) do
	debris(d[1], d[2], d[3], d[4], d[5])
end


for _, d in ipairs(DEB2) do
	debris(d[1], d[2], d[3], d[4], d[5])
end

--=== 자기검사 ===--
-- 바다 위에 적은 자리는 멈추지 않고 알려만 준다. 옮겨 적으면 된다
if #miss > 0 then
	print("[화산유적] 바다 위 " .. #miss .. "곳 -> " .. table.concat(miss, " | "))
end

-- **떠 있는 것이 없는지 실제로 잰다.**
-- 광선을 쓰면 안 된다. 파트가 땅에 물려 있으면 광선이 그 땅 안에서 시작해서
-- 시작점이 들어 있는 파트를 무시하고 아무것도 못 맞춘다. 앞선 검사가 그래서 틀렸다.
-- 대신 밑면 바로 아래에 얇은 상자를 놓고 무엇이든 걸치는지 본다.
-- 기울인 부재는 밑면 어림이 빗나가므로 세워 둔 것만 본다
-- **파트 가운데만 보면 안 된다.** 문 위 상인방은 가운데가 빈 문간이고
-- 양 끝 문틀이 받친다. 그래서 발자국 전체를 본다
local function supported(p, dy)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { p }
	op.MaxParts = 1
	local probe = p.CFrame * CFrame.new(0, -p.Size.Y / 2 - 2.5 - (dy or 0), 0)
	local box = Vector3.new(p.Size.X * 0.98, 5, p.Size.Z * 0.98)
	return #workspace:GetPartBoundsInBox(probe, box, op) > 0
end

-- 뜬 것은 그 자리에서 한 칸씩 내려 앉힌다. 24 를 내려도 받칠 것이 없으면 지운다.
-- 표를 손으로 적다 보면 한두 개는 반드시 어긋나므로 마지막에 이 손질을 둔다
local float, checked, names, seated, gone = 0, 0, {}, 0, 0
for _, p in ipairs(ROOT:GetDescendants()) do
	if p:IsA("BasePart") and math.abs(p.CFrame.UpVector.Y) > 0.98 then
		checked = checked + 1
		if not supported(p, 0) then
			local drop = nil
			for dy = 1, 24 do
				if supported(p, dy) then
					drop = dy
					break
				end
			end
			if drop then
				p.CFrame = p.CFrame - Vector3.new(0, drop, 0)
				seated = seated + 1
			else
				if #names < 6 then
					names[#names + 1] = p:GetFullName()
				end
				p:Destroy()
				gone = gone + 1
			end
			float = float + 1
		end
	end
end

local counts = {}
for _, f in ipairs(ROOT:GetChildren()) do
	counts[#counts + 1] = f.Name .. " " .. #f:GetChildren()
end
print(string.format("[화산유적] 파트 %d개 / 집 %d채 / 가게 %d / 아트리움 %d / %s", n, houses, shops, atria, table.concat(counts, " · ")))
print(string.format("[화산유적] 세워 둔 %d개 중 뜬 것 %d개 / 내려 앉힌 것 %d / 지운 것 %d %s", checked, float, seated, gone, table.concat(names, " ")))
if houses < 50 then fail("집이 " .. houses .. "채뿐이다") end
if gone > 6 then fail("받칠 것이 없어 지운 파트가 " .. gone .. "개다: " .. table.concat(names, " ")) end
report(string.format("OK 파트%d 집%d 가게%d 아트%d 뜬것%d 앉힘%d 지움%d", n, houses, shops, atria, float, seated, gone))
print("[화산유적] 배치표대로 다 섰다")
