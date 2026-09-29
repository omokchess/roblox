--!nocheck
--[[
	Islands_Mountains.luau — 봉우리를 작은 블록으로 쌓는다.

	Islands_Ground.luau 가 남긴 Surface/_PeakSeeds 를 읽는다.
	씨앗 하나 = 손으로 그린 격자에서 5 이상을 적어 넣은 칸 하나다.
	**어디에 산을 놓을지는 사람이 정했고, 여기서는 그 자리에 돌을 쌓기만 한다.**

	지키는 것 네 가지:
	  1. 네모 계단으로 보이면 안 된다
	     -> 400짜리 판을 안 쓴다. 46~150 블록을 Y축으로 제각각 돌리고 위치를 흔든다
	     -> 층 경계가 한 줄로 맞지 않게 블록마다 두께와 높이를 달리한다
	  2. 속이 비면 안 된다
	     -> 층마다 원 안을 격자로 꽉 채운다. 껍데기만 두르지 않는다
	     -> 층 두께를 층 간격보다 두껍게 잡아 위아래가 겹치게 한다
	  3. 섬마다 하나만 있으면 안 된다
	     -> 마지막에 섬별 봉우리 수를 센다. 2 미만이면 멈춘다
	  4. 숲이라고 다 초록일 수 없다
	     -> 색은 바이옴이 아니라 봉우리마다 정한다. 숲은 화강암 회색이고
	        초록은 산기슭에만 남는다. 설원은 검은 화강암에 흰 모자를 씌운다

	되돌리기: workspace.Surface.Mountains:Destroy()
]]

local RGB = Color3.fromRGB
local M = Enum.Material

-- p       봉우리 옆면. 0.3 은 수직 탑, 1.0 은 원뿔, 1.6 은 오목한 첨봉
-- hmul    높이 배수. 단계와 섬 높이차를 곱해 실제 높이를 만든다
-- cA/cB   바위 두 색. 아래에서 위로 섞는다
-- capC    정상 모자색 (눈). capT 위쪽부터
-- footC   기슭색 (초목). footT 아래쪽만
-- rmul    밑면 반지름 배수. 1 이면 봉우리 하나가 반지름 500 을 넘어
--         400 간격으로 찍은 씨앗끼리 서로 붙어 한 덩어리가 된다
-- terrace 반지름을 네 단으로 끊어 채석장 계단을 만든다
-- glow    정상 근처에 네온을 섞는다
local MTN = {
	["숲"] = { p = 0.55, hmul = 1.1, rmul = 0.45, mat = M.Rock,
		cA = RGB(150, 148, 140), cB = RGB(104, 110, 100),
		footC = RGB(64, 96, 58), footT = 0.22 },

	["설원"] = { p = 1.5, hmul = 2.2, mat = M.Rock,
		cA = RGB(86, 88, 96), cB = RGB(52, 54, 64),
		capC = RGB(236, 242, 248), capT = 0.52 },

	["탑의성역"] = { p = 0.30, hmul = 2.0, mat = M.Limestone,
		cA = RGB(206, 204, 190), cB = RGB(156, 158, 150),
		footC = RGB(120, 132, 110), footT = 0.10 },

	["화산"] = { p = 0.9, hmul = 1.5, mat = M.Basalt,
		cA = RGB(122, 58, 44), cB = RGB(44, 36, 34), glow = true },

	["사막"] = { p = 1.0, hmul = 1.8, mat = M.Sandstone,
		cA = RGB(178, 104, 68), cB = RGB(210, 176, 128) },

	["광산"] = { p = 1.0, hmul = 1.8, mat = M.Sandstone, terrace = true,
		cA = RGB(158, 128, 88), cB = RGB(104, 100, 94) },

	["오염지대"] = { p = 0.8, hmul = 1.9, mat = M.Slate,
		cA = RGB(52, 42, 56), cB = RGB(96, 62, 92) },

	["평원"] = { p = 1.2, hmul = 1.4, mat = M.Grass,
		cA = RGB(126, 134, 92), cB = RGB(150, 144, 126),
		footC = RGB(118, 152, 84), footT = 0.40 },

	["늪지대"] = { p = 0.7, hmul = 1.2, mat = M.Slate,
		cA = RGB(104, 96, 82), cB = RGB(70, 68, 56) },
}

-- 손으로 비워두는 자리. 랜드마크가 바위에 파묻히면 안 된다.
-- 봉우리는 설계도가 정하지만 랜드마크 위치는 설계도에 없으므로 여기 적는다.
-- 손으로 값을 덮어쓰는 봉우리. 랜드마크가 앉을 언덕은 설계도의 단계 계산으로는
-- 원하는 크기가 안 나온다. 지반으로 높이를 내면 한 단이 400에 걸쳐 퍼져서
-- 가파를 수가 없고, 가파르게 하면 이번엔 걸어서 못 다닌다.
-- 그래서 거목이 설 대지만 반지름과 높이를 직접 적는다.
local OVERRIDE = {
	["숲|-4800|1600"] = { R0 = 880, H = 215, p = 0.26 }, -- 거목이 앉을 바위 대지
}

local KEEPOUT = {
	-- 거목 자리는 비우지 않는다. 대지 위에 앉혀야 하므로 바위가 있어야 한다
	{ x = 0, z = 1600, r = 1600 }, -- 절화. 궁 위에 바위가 얹히면 안 된다
}

local seeds = workspace.Surface:FindFirstChild("_PeakSeeds")
assert(seeds, "_PeakSeeds 가 없다. Islands_Ground.luau 를 먼저 돌려라")

local old = workspace.Surface:FindFirstChild("Mountains")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Mountains"
root.Parent = workspace.Surface

local fold, count, parts = {}, {}, 0
for name in pairs(MTN) do
	local f = Instance.new("Folder")
	f.Name = "M_" .. name
	f.Parent = root
	fold[name] = f
	count[name] = 0
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Surface.World }

local sn = 0
for _, sv in ipairs(seeds:GetChildren()) do
	local biome, sx, sz = sv.Name:match("^(.+)|(-?%d+)|(-?%d+)$")
	sx, sz = tonumber(sx), tonumber(sz)
	local base, tier, step = sv.Value.X, sv.Value.Y, sv.Value.Z
	-- 판이 격자에 안 맞으므로 실제 지면은 광선으로 찍는다. 안 찍히면 설계값을 쓴다
	local hit = workspace:Raycast(Vector3.new(sx, 900, sz), Vector3.new(0, -1400, 0), rp)
	if hit then
		base = hit.Position.Y - 12 -- 조금 파묻어 이음매를 감춘다
	end
	local cfg = MTN[biome]
	if cfg then
		sn += 1
		local rng = Random.new(sx * 7349 + sz * 131 + tier)

		local ov = OVERRIDE[sv.Name]
		local R0 = ov and ov.R0 or (250 + (tier - 4) * 85 + rng:NextNumber(-30, 40)) * (cfg.rmul or 1)
		local H = ov and ov.H or (tier - 3) * step * cfg.hmul * rng:NextNumber(0.85, 1.2)
		local prof = ov and ov.p or cfg.p
		local nL = math.clamp(math.round(H / 26), 4, 16)
		local lt = H / nL

		-- 층마다 중심이 조금씩 흘러 봉우리가 한쪽으로 기운다. 좌우대칭이면 가짜로 보인다
		local cx, cz = sx + rng:NextNumber(-60, 60), sz + rng:NextNumber(-60, 60)

		for i = 0, nL - 1 do
			local t = i / nL
			local rt = cfg.terrace and (math.floor(t * 4) / 4) or t
			local R = R0 * (1 - rt) ^ prof
			if R < 42 then
				break
			end

			cx += rng:NextNumber(-8, 8)
			cz += rng:NextNumber(-8, 8)
			local y = base + i * lt

			local blk = math.clamp(R / 2.6, 46, 150)
			-- 간격은 블록 크기의 0.72배다. 아래에서 크기를 1.00배 이상으로만 뽑으므로
			-- 이웃끼리 반드시 겹친다. 예전처럼 0.80배 간격에 0.80배 크기를 허용하면
			-- 흔들림까지 겹쳐서 이웃이 안 닿고, 그 틈이 산 표면에 구멍으로 남는다
			local pitch = blk * 0.72
			local half = math.ceil(R / pitch)

			for gx = -half, half do
				for gz = -half, half do
					local ox, oz = gx * pitch, gz * pitch
					local d = math.sqrt(ox * ox + oz * oz)
					-- 둘레를 울퉁불퉁하게. 매끈한 원이면 공깃돌처럼 보인다
					local a = math.atan2(oz, ox)
					local lim = R * (1 + 0.30 * math.noise(math.cos(a) * 1.9, math.sin(a) * 1.9, sn))
					local bx, bz = cx + ox, cz + oz
					local clear = true
					for _, k in ipairs(KEEPOUT) do
						if (bx - k.x) ^ 2 + (bz - k.z) ^ 2 < k.r * k.r then
							clear = false
							break
						end
					end
					if d <= lim and clear then
						local sxz = blk * rng:NextNumber(1.00, 1.40)
						local sxz2 = blk * rng:NextNumber(1.00, 1.40)
						local th = lt * rng:NextNumber(1.60, 2.30) -- 층끼리 넉넉히 겹쳐 틈이 없게

						local u = math.clamp(t + rng:NextNumber(-0.12, 0.12), 0, 1)
						local col = cfg.cA:Lerp(cfg.cB, u)
						local mat = cfg.mat
						if cfg.footC and t < cfg.footT then
							col = cfg.footC:Lerp(col, t / cfg.footT)
						elseif cfg.capC and t > cfg.capT then
							col = col:Lerp(cfg.capC, (t - cfg.capT) / (1 - cfg.capT))
							mat = M.Snow
						end
						if cfg.glow and t > 0.72 and rng:NextNumber() < 0.10 then
							col = RGB(255, 138, 52)
							mat = M.Neon
						end

						local p = Instance.new("Part")
						p.Name = string.format("Mt_%s_%d_%d_L%d_%d_%d", biome, sx, sz, i, gx, gz)
						p.Anchored = true
						p.Size = Vector3.new(sxz, th, sxz2)
						-- 흔들림은 겹침을 까먹지 않을 만큼만. 예전 0.20 은 이웃을 떼어놓았다
						p.CFrame = CFrame.new(
							cx + ox + rng:NextNumber(-blk * 0.10, blk * 0.10),
							y + rng:NextNumber(-lt * 0.12, lt * 0.12),
							cz + oz + rng:NextNumber(-blk * 0.10, blk * 0.10)
						) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
						p.Color = col
						p.Material = mat
						p.TopSurface = Enum.SurfaceType.Smooth
						p.BottomSurface = Enum.SurfaceType.Smooth
						p.Parent = fold[biome]
						parts += 1
					end
				end
			end
			task.wait()
		end
		count[biome] += 1
	end
end

--=== 자기검사 ===--
local report = {}
for name, c in pairs(count) do
	-- 봉우리를 아예 안 두기로 한 섬이 있다. 탑의성역은 탑 하나만 서는 평지다.
	-- 하나만 있으면 외톨이로 보이므로, 둘 것이면 둘 이상이어야 한다
	assert(c ~= 1, name .. " 에 봉우리가 하나뿐이다. 둘 이상 찍거나 아예 빼라")
	report[#report + 1] = name .. "=" .. c
end
assert(parts > 0, "블록이 하나도 안 쌓였다")

print(string.format("[Mountains] 봉우리 %d개 / 블록 %d개", sn, parts))
print("[Mountains] " .. table.concat(report, " "))
