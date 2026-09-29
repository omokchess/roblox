--!nocheck
--[[
	BuildIslands.luau — 군도 지반 생성기. Studio 커맨드 바에 통째로 붙여 실행한다.

	「바이옴 배치.md」의 유일한 구현체다. 표가 바뀌면 여기 ISL 도 같이 고친다.

	**Surface/World 를 통째로 지우고 다시 깐다.** 손으로 고친 칸은 사라진다.
	Surface/R_* (절화, 숲 나무, 거목) 는 건드리지 않는다.

	색과 재질은 기존 G_<바이옴> 폴더에서 층별로 한 장씩 뽑아 쓴다.
	폴더가 비어 있으면 FMAT 의 기본 재질로 떨어진다.
]]

local CELL = 400
local RAD = 2200 -- 섬 반지름. 한 섬 약 95칸
local NZ = 380 -- 해안선 노이즈 진폭
local MOAT = 500 -- 오염지대 둘레에 강제로 남기는 바다 폭
local MIN_COMP = 4 -- 이보다 작은 연결 성분은 부스러기로 보고 지운다

-- 3×3. 남쪽 줄이 저레벨, 북쪽 줄이 최상위.
local ISL = {
	{ "평원", 0, 1400 },
	{ "숲", -4770, 1513 },
	{ "늪지대", 5200, 2000 },
	{ "탑의성역", -1200, -3800 },
	{ "사막", 4400, -3200 },
	{ "오염지대", -7000, -3800 },
	{ "설원", -7600, -9400 },
	{ "화산", -1600, -9000 },
	{ "광산", 3800, -8600 },
}

local BASE =
	{ ["늪지대"] = 2, ["평원"] = 6, ["오염지대"] = 8, ["숲"] = 14, ["사막"] = 20,
	  ["탑의성역"] = 24, ["광산"] = 34, ["설원"] = 40, ["화산"] = 52 }

local M = Enum.Material
local FMAT =
	{ ["늪지대"] = M.Mud, ["평원"] = M.Grass, ["오염지대"] = M.CrackedLava, ["숲"] = M.Grass,
	  ["사막"] = M.Sand, ["탑의성역"] = M.Slate, ["광산"] = M.Rock, ["설원"] = M.Snow,
	  ["화산"] = M.Basalt }

-- 평원↔숲 지협. 이 둘만 걸어서 오갈 수 있다.
local BR_A = Vector2.new(0, 1400)
local BR_B = Vector2.new(-4770, 1513)
local BR_W = 640 -- 지협 반폭

local W = workspace.Surface.World

--=== 1. 기존 판에서 층별 생김새를 뽑아둔다 ===--
local look = {}
for _, f in ipairs(W:GetChildren()) do
	local b = f.Name:gsub("G_", "")
	look[b] = {}
	for _, p in ipairs(f:GetChildren()) do
		local k = p.Name:sub(1, 3)
		if not look[b][k] then
			look[b][k] = { c = p.Color, m = p.Material }
		end
	end
end

local function inf(x, z, i, s)
	local dx, dz = x - s[2], z - s[3]
	return RAD - math.sqrt(dx * dx + dz * dz) + math.noise(x * 0.0009, z * 0.0009, i * 21.3) * NZ
end

--=== 2. 육지 판정 ===--
local minx, maxx, minz, maxz = 1e9, -1e9, 1e9, -1e9
for _, s in ipairs(ISL) do
	local R = RAD + NZ + CELL
	minx, maxx = math.min(minx, s[2] - R), math.max(maxx, s[2] + R)
	minz, maxz = math.min(minz, s[3] - R), math.max(maxz, s[3] + R)
end
minx, maxx = math.floor(minx / CELL) * CELL, math.ceil(maxx / CELL) * CELL
minz, maxz = math.floor(minz / CELL) * CELL, math.ceil(maxz / CELL) * CELL

local ab = BR_B - BR_A
local abl = ab:Dot(ab)
local land = {}

for x = minx, maxx, CELL do
	for z = minz, maxz, CELL do
		local best, bv, cor = nil, -1e9, -1e9
		for i, s in ipairs(ISL) do
			local v = inf(x, z, i, s)
			if s[1] == "오염지대" then
				cor = v
			end
			if v > bv then
				bv, best = v, s[1]
			end
		end

		local ok = bv > 0
		if not ok then
			-- 지협: 두 중심을 잇는 선분에 가까우면 육지로 만든다
			local t = math.clamp((Vector2.new(x, z) - BR_A):Dot(ab) / abl, 0, 1)
			local d = (Vector2.new(x, z) - (BR_A + ab * t)).Magnitude
			if d < BR_W + math.noise(x * 0.0018, z * 0.0018, 99) * 180 then
				ok = true
				best = (t < 0.5) and "평원" or "숲"
			end
		end

		-- 오염지대 해자. 어느 쪽에서 보든 폭 MOAT 는 바다로 남는다
		if ok then
			if best == "오염지대" then
				local sec = -1e9
				for i, s in ipairs(ISL) do
					if s[1] ~= "오염지대" then
						sec = math.max(sec, inf(x, z, i, s))
					end
				end
				if sec > -MOAT then
					ok = false
				end
			elseif cor > -MOAT then
				ok = false
			end
		end

		if ok then
			land[x .. "_" .. z] = { x, z, best }
		end
	end
	task.wait()
end

--=== 3. 부스러기 섬 제거 ===--
local seen, drop = {}, 0
local N4 = { { CELL, 0 }, { -CELL, 0 }, { 0, CELL }, { 0, -CELL } }
for k in pairs(land) do
	if not seen[k] then
		local comp, q, qi = {}, { k }, 1
		seen[k] = true
		while qi <= #q do
			local cur = q[qi]
			qi += 1
			comp[#comp + 1] = cur
			local cx, cz = land[cur][1], land[cur][2]
			for _, d in ipairs(N4) do
				local nk = (cx + d[1]) .. "_" .. (cz + d[2])
				if land[nk] and not seen[nk] then
					seen[nk] = true
					q[#q + 1] = nk
				end
			end
		end
		if #comp < MIN_COMP then
			for _, kk in ipairs(comp) do
				land[kk] = nil
				drop += 1
			end
		end
	end
end

--=== 4. 세우기 ===--
W:ClearAllChildren()
local G = {}
for _, s in ipairs(ISL) do
	local f = Instance.new("Folder")
	f.Name = "G_" .. s[1]
	f.Parent = W
	G[s[1]] = f
end

local LAY = { { "Wt_", 8 }, { "Ws_", 22 }, { "Wr_", 28 } }
local cnt = {}
for _, s in ipairs(ISL) do
	cnt[s[1]] = 0
end

local n, i = 0, 0
for _, c in pairs(land) do
	local x, z, b = c[1], c[2], c[3]
	cnt[b] += 1
	i += 1
	local top = BASE[b]
	for _, L in ipairs(LAY) do
		local pre, th = L[1], L[2]
		local lk = look[b] and look[b][pre]
		local p = Instance.new("Part")
		p.Name = pre .. x .. "_" .. z
		p.Anchored = true
		p.Size = Vector3.new(CELL, th, CELL)
		p.Position = Vector3.new(x, top - th / 2, z)
		p.Color = lk and lk.c or Color3.fromRGB(120, 120, 120)
		p.Material = lk and lk.m or FMAT[b]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = G[b]
		n += 1
		top -= th
	end
	if i % 150 == 0 then
		task.wait()
	end
end

--=== 5. 자기검사 ===--
-- 오염지대는 어떤 섬과도 4방향으로 닿아서는 안 된다
local touch = 0
for k, c in pairs(land) do
	if c[3] == "오염지대" then
		for _, d in ipairs(N4) do
			local nb = land[(c[1] + d[1]) .. "_" .. (c[2] + d[2])]
			if nb and nb[3] ~= "오염지대" then
				touch += 1
			end
		end
	end
end
assert(touch == 0, "오염지대가 다른 섬과 붙었다: " .. touch .. "칸. MOAT 를 올려라")

-- 평원과 숲은 반드시 이어져 있어야 한다
local bridge = 0
for k, c in pairs(land) do
	if c[3] == "숲" then
		for _, d in ipairs(N4) do
			local nb = land[(c[1] + d[1]) .. "_" .. (c[2] + d[2])]
			if nb and nb[3] == "평원" then
				bridge += 1
			end
		end
	end
end
assert(bridge > 0, "평원↔숲 지협이 끊겼다. BR_W 를 올려라")

local s = ""
for _, isl in ipairs(ISL) do
	s ..= isl[1] .. "=" .. cnt[isl[1]] .. " "
end
print(string.format("[BuildIslands] %d칸 %d파트 / 부스러기 %d칸 제거 / 지협 %d칸", i, n, drop, bridge))
print("[BuildIslands] " .. s)
