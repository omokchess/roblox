--!nocheck
--[[
	Islands_Sanctuary.luau — 탑 둘레에 유적을 놓아 성역으로 만든다.

	탑 하나만 서 있으면 성역이 아니라 그냥 탑이다.
	여기 있던 것들이 무너진 흔적이 있어야 "지금은 폐허인 성소"로 읽힌다.

	자리는 전부 아래 표에 **각도와 거리**로 적혀 있다. 흩뿌리지 않는다.
	  참배로 넷이 탑에서 바깥으로 뻗고, 그 양옆에 열주가 선다
	  길 끝에 무너진 문이 있다
	  제단과 비석은 따로 적은 자리에만 선다
	  탑에서 떨어진 덩어리가 땅에 박혀 있다

	**참배로를 정확히 90도씩 두지 않았다.** 직교하면 기계로 그은 것처럼 보인다.
	20, 110, 200, 290 도로 두되 길이를 서로 다르게 해서 대칭을 깬다.

	기둥은 대부분 부러져 있다. 부러진 높이를 표에 적어 돌려쓰므로
	어느 기둥이 얼마나 남을지 사람이 정한다.

	되돌리기: workspace.Surface.Ruins_탑의성역:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

local X, Z = 1200, -4400 -- 탑 자리. Islands_Tower.luau 와 같아야 한다
local INNER = 280 -- 이 안쪽은 탑 기단이다. 비워 둔다

-- 참배로. ang 방향으로 len 만큼 뻗는다
local WAYS = {
	{ ang = 20, len = 1020 },
	{ ang = 110, len = 860 },
	{ ang = 200, len = 1120 },
	{ ang = 290, len = 780 },
}
local WAY_HALF = 62 -- 길 반폭
local COL_OFF = 112 -- 길 중심에서 기둥까지
local COL_GAP = 132 -- 기둥 간격

-- 기둥이 부러지고 남은 비율. 앞에서부터 돌려 쓴다.
-- 1 은 멀쩡, 0.25 는 밑동만 남은 것이다
local STUMP = { 1.0, 0.55, 0.85, 0.30, 1.0, 0.45, 0.70, 0.25, 0.95, 0.40, 0.60, 1.0 }

-- 포석 고리
local PAVE = { 300, 372, 444, 516 }

-- 제단 { 각도, 거리 }
local ALTARS = {
	{ 65, 470 },
	{ 245, 520 },
}

-- 비석 { 각도, 거리, 높이, 기울기(도) }
local STELES = {
	{ 5, 640, 118, 6 },
	{ 52, 720, 86, -14 },
	{ 138, 610, 132, 9 },
	{ 176, 780, 74, 22 },
	{ 228, 660, 104, -7 },
	{ 272, 840, 92, 17 },
	{ 318, 700, 126, -11 },
	{ 350, 900, 68, 26 },
}

-- 탑에서 떨어져 땅에 박힌 덩어리 { 각도, 거리, 크기, 기울기(도) }
local FALLEN = {
	{ 34, 600, 86, 38 },
	{ 88, 880, 62, 54 },
	{ 121, 430, 104, 27 },
	{ 158, 960, 70, 44 },
	{ 205, 380, 92, 61 },
	{ 243, 1010, 58, 31 },
	{ 281, 520, 118, 49 },
	{ 305, 1140, 66, 36 },
	{ 342, 470, 80, 58 },
	{ 12, 1080, 96, 24 },
}

local STONE = RGB(206, 202, 186)
local WEATHER = RGB(118, 120, 112)
local GLOW = RGB(255, 214, 140)

local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World }

local old = S:FindFirstChild("Ruins_탑의성역")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Ruins_탑의성역"
root.Parent = S

local rng = Random.new(60411)
local n = 0

-- 유적은 땅에 붙어 있어야 한다. 자리마다 지면을 실측한다
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1600, 0), rp)
	return hit and hit.Position.Y or nil
end

local function put(fold, name, cf, size, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	if neon then
		p.Color = GLOW
		p.Material = M.Neon
	else
		p.Color = STONE:Lerp(WEATHER, rng:NextNumber(0, 0.62))
		p.Material = M.Limestone
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fold
	n += 1
	return p
end

local function polar(ang, r)
	local a = math.rad(ang)
	return X + math.cos(a) * r, Z + math.sin(a) * r
end

local function sub(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

--=== 포석 고리 ===--
-- 고리마다 군데군데 빠져 있다. 꽉 채우면 새로 깐 바닥으로 보인다
local fPave = sub("Pave")
for ri, r in ipairs(PAVE) do
	local cnt = math.floor(2 * math.pi * r / 86)
	for i = 0, cnt - 1 do
		if rng:NextNumber() > 0.22 + ri * 0.07 then
			local a = (i / cnt) * 360
			local px, pz = polar(a, r + rng:NextNumber(-9, 9))
			local gy = ground(px, pz)
			if gy then
				put(
					fPave,
					string.format("Pave%d_%d", ri, i),
					CFrame.new(px, gy + 2, pz) * CFrame.Angles(0, -math.rad(a) + rng:NextNumber(-0.1, 0.1), 0),
					Vector3.new(70, 7, 78),
					false
				)
			end
		end
	end
	task.wait()
end

--=== 참배로와 열주 ===--
local fWay = sub("Way")
local si = 0
for wi, w in ipairs(WAYS) do
	local a = math.rad(w.ang)
	local dx, dz = math.cos(a), math.sin(a)
	local nx, nz = -dz, dx -- 길의 직각 방향

	-- 길바닥
	local steps = math.floor((w.len - INNER) / 80)
	for s = 0, steps do
		local d = INNER + s * 80
		for lane = -1, 1 do
			if rng:NextNumber() > 0.18 then
				local px = X + dx * d + nx * lane * WAY_HALF * 0.72
				local pz = Z + dz * d + nz * lane * WAY_HALF * 0.72
				local gy = ground(px, pz)
				if gy then
					put(
						fWay,
						string.format("W%d_%d_%d", wi, s, lane + 2),
						CFrame.new(px, gy + 2, pz) * CFrame.Angles(0, -a + rng:NextNumber(-0.06, 0.06), 0),
						Vector3.new(74, 7, 64),
						false
					)
				end
			end
		end
	end

	-- 양옆 열주
	local cols = math.floor((w.len - INNER - 60) / COL_GAP)
	for c = 0, cols do
		local d = INNER + 60 + c * COL_GAP
		for side = -1, 1, 2 do
			si += 1
			local keep = STUMP[(si - 1) % #STUMP + 1]
			local px = X + dx * d + nx * side * COL_OFF
			local pz = Z + dz * d + nz * side * COL_OFF
			local gy = ground(px, pz)
			if gy then
				local full = 86
				local h = full * keep
				local drums = math.max(math.floor(h / 22), 1)
				-- 기단
				put(
					fWay,
					string.format("ColB%d_%d_%d", wi, c, side),
					CFrame.new(px, gy + 5, pz) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
					Vector3.new(34, 10, 34),
					false
				)
				-- 북을 쌓아 올린다. 부러진 기둥은 위로 갈수록 어긋난다
				for k = 0, drums - 1 do
					local t = k / math.max(drums - 1, 1)
					local tilt = (1 - keep) * 0.16 * t
					put(
						fWay,
						string.format("Col%d_%d_%d_%d", wi, c, side, k),
						CFrame.new(px + rng:NextNumber(-3, 3) * t * 4, gy + 12 + k * 22, pz + rng:NextNumber(-3, 3) * t * 4)
							* CFrame.Angles(rng:NextNumber(-tilt, tilt), rng:NextNumber(0, 1), rng:NextNumber(-tilt, tilt)),
						Vector3.new(25 - k * 0.6, 22, 25 - k * 0.6),
						false
					)
				end
				-- 온전한 기둥만 머리를 인다
				if keep > 0.9 then
					put(
						fWay,
						string.format("ColC%d_%d_%d", wi, c, side),
						CFrame.new(px, gy + 12 + drums * 22 + 6, pz) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
						Vector3.new(34, 12, 34),
						c % 4 == 0
					)
				end
			end
		end
	end

	-- 길 끝의 무너진 문
	local gx, gz = X + dx * w.len, Z + dz * w.len
	local gy = ground(gx, gz)
	if gy then
		local half = 92
		for side = -1, 1, 2 do
			local px, pz = gx + nx * side * half, gz + nz * side * half
			local gy2 = ground(px, pz) or gy
			-- 한쪽 기둥만 부러뜨린다. 둘 다 멀쩡하면 폐허가 아니다
			local drums = (side == (wi % 2 == 0 and 1 or -1)) and 3 or 6
			for k = 0, drums - 1 do
				put(
					fWay,
					string.format("Gate%d_%d_%d", wi, side, k),
					CFrame.new(px, gy2 + 14 + k * 26, pz) * CFrame.Angles(0, -a, 0),
					Vector3.new(40, 26, 46),
					false
				)
			end
		end
		-- 인방은 한쪽만 걸쳐 있고 반대쪽은 떨어져 있다
		put(
			fWay,
			"Lintel" .. wi,
			CFrame.new(gx + nx * 30, gy + 14 + 6 * 26 + 10, gz + nz * 30) * CFrame.Angles(0, -a, 0.12),
			Vector3.new(46, 20, half * 1.5),
			wi % 2 == 0
		)
	end
	task.wait()
end

--=== 제단 ===--
local fAlt = sub("Altar")
for i, al in ipairs(ALTARS) do
	local px, pz = polar(al[1], al[2])
	local gy = ground(px, pz)
	if gy then
		for k = 0, 2 do
			put(
				fAlt,
				string.format("Alt%d_%d", i, k),
				CFrame.new(px, gy + 6 + k * 12, pz) * CFrame.Angles(0, k * 0.3, 0),
				Vector3.new(150 - k * 30, 12, 150 - k * 30),
				false
			)
		end
		-- 제단 위 판. 성역이 여기서 읽힌다
		put(fAlt, "AltTop" .. i, CFrame.new(px, gy + 46, pz) * CFrame.Angles(0, 0.5, 0), Vector3.new(76, 8, 76), true)
		-- 네 귀퉁이 기둥. 둘은 부러져 있다
		local hh = { 58, 24, 52, 18 }
		for c = 0, 3 do
			local a2 = math.rad(45 + c * 90)
			put(
				fAlt,
				string.format("AltP%d_%d", i, c),
				CFrame.new(px + math.cos(a2) * 58, gy + 6 + hh[c + 1] / 2, pz + math.sin(a2) * 58)
					* CFrame.Angles(0, a2, (c % 2 == 1) and 0.1 or 0),
				Vector3.new(18, hh[c + 1], 18),
				false
			)
		end
	end
end

--=== 비석 ===--
local fSte = sub("Stele")
for i, st in ipairs(STELES) do
	local px, pz = polar(st[1], st[2])
	local gy = ground(px, pz)
	if gy then
		local h, tl = st[3], math.rad(st[4])
		put(
			fSte,
			"SteleB" .. i,
			CFrame.new(px, gy + 5, pz) * CFrame.Angles(0, math.rad(st[1]), 0),
			Vector3.new(46, 10, 46),
			false
		)
		put(
			fSte,
			"Stele" .. i,
			CFrame.new(px, gy + 10 + h / 2, pz) * CFrame.Angles(tl, math.rad(st[1]), tl * 0.5),
			Vector3.new(26, h, 20),
			false
		)
		-- 꼭대기 홈에 박힌 빛. 비석이 그냥 돌기둥으로 안 보이게
		put(
			fSte,
			"SteleG" .. i,
			CFrame.new(px, gy + 10 + h - 14, pz) * CFrame.Angles(tl, math.rad(st[1]), tl * 0.5),
			Vector3.new(28, 12, 8),
			true
		)
	end
end

--=== 떨어져 박힌 덩어리 ===--
local fFal = sub("Fallen")
for i, fa in ipairs(FALLEN) do
	local px, pz = polar(fa[1], fa[2])
	local gy = ground(px, pz)
	if gy then
		local sz, tl = fa[3], math.rad(fa[4])
		-- 절반쯤 땅에 박혀 있어야 떨어진 것으로 보인다. 얹혀 있으면 놓아둔 것이다
		put(
			fFal,
			"Fallen" .. i,
			CFrame.new(px, gy + sz * 0.18, pz) * CFrame.Angles(tl, math.rad(fa[1] * 1.7), tl * 0.6),
			Vector3.new(sz, sz * 0.58, sz * 0.82),
			false
		)
		-- 박히면서 튄 파편
		for k = 1, 3 do
			local a2 = math.rad(fa[1] + k * 97)
			local d = sz * rng:NextNumber(0.7, 1.4)
			local qx, qz = px + math.cos(a2) * d, pz + math.sin(a2) * d
			local qy = ground(qx, qz)
			if qy then
				put(
					fFal,
					string.format("Chip%d_%d", i, k),
					CFrame.new(qx, qy + 5, qz) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a2, rng:NextNumber(-0.4, 0.4)),
					Vector3.new(sz * 0.28, sz * 0.2, sz * 0.3),
					false
				)
			end
		end
	end
end

--=== 자기검사 ===--
assert(n > 400, "유적이 " .. n .. "개뿐이다")
for _, f in ipairs(root:GetChildren()) do
	assert(#f:GetChildren() > 0, f.Name .. " 이 비었다. 지면을 못 찾았을 수 있다")
end
-- 탑 기단 안쪽에는 아무것도 없어야 한다
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") then
		local d = math.sqrt((p.Position.X - X) ^ 2 + (p.Position.Z - Z) ^ 2)
		assert(d > INNER - 60, p.Name .. " 이 탑 기단을 침범했다 (거리 " .. math.floor(d) .. ")")
	end
end

print(string.format("[Sanctuary] 파트 %d개 / 참배로 %d, 제단 %d, 비석 %d, 낙석 %d", n, #WAYS, #ALTARS, #STELES, #FALLEN))
