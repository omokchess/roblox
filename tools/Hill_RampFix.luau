--!nocheck
--[[
	Hill_RampFix.luau — 2026-09-27. 숲 거목(보스) 언덕 오르는 길과 틈을 고친다 → recv/hillfix.txt

	옛 길(Surface.Ramps, Islands_Ramps.luau)은 세상을 1/3 로 줄인 뒤 한 단이 3.7 이 되었고, 높이 41 에서 끝나
	그 위 봉우리 층(한 층 8~10 절벽)을 오를 수 없었다. 길 한가운데 깊이 20 틈도 있었다(Hill_GapScan).

	새 길: 남북 두 줄, 폭 WIDTH. 대지 쪽 끝에서 바깥으로 거꾸로 짚으며 높이선을 잡는다.
	  y(z) = max( 지형(z), 안쪽 이웃 y - RISE )   지형은 길 폭 안 가장 높은 땅
	그러면 길은 지형 밑으로 파묻히지 않고, 바깥에서 안으로 한 칸(RUN)에 RISE 넘게 오르지 않는다.
	지형보다 높은 칸에만 디딤돌을 놓는다. 디딤돌은 윗면에서 폭 안 가장 낮은 땅 밑까지 내려 붙인 기둥이라 밑이 비지 않는다.
	색과 재질은 그 칸 땅에서 가져온다(자연석). 옛 길은 ServerStorage.Ramps_옛것 으로 옮긴다.

	틈 메우기: _G.HillGaps(Hill_GapScan) 의 틈·구멍 칸마다 양옆 벽 중 낮은 쪽 높이까지 같은 돌로 채운다(Surface.Mountains.HillFill).
	되돌리기: Surface.Ramps 를 지우고 Ramps_옛것 을 Surface 로, Mountains.HillFill 을 지운다.
]]
local WIDTH = 26
local RUN = 3
local RISE = 1.2
local LANES = {
	-- 이름, x, 대지 쪽 z, 바깥 끝 z
	{ "거목북", -1600, 420, 30 },
	{ "거목남", -1600, 600, 1070 },
}

local SS = game:GetService("ServerStorage")
local S = workspace.Surface
local out = {}

local old = S:FindFirstChild("Ramps")
if old then
	local bak = SS:FindFirstChild("Ramps_옛것")
	if bak then
		old:Destroy() -- 이미 옮겨 둔 적이 있으면 지금 것은 이 스크립트가 지은 것이다
	else
		old.Name = "Ramps_옛것"
		old.Parent = SS
		out[#out + 1] = "옛 길 창고로"
	end
end
local ramps = Instance.new("Folder")
ramps.Name = "Ramps"
ramps.Parent = S

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { S.World, S.Mountains }
local function hitAt(x, z)
	return workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -900, 0), rp)
end

local nStep = 0
for _, ln in ipairs(LANES) do
	local name, x, zTop, zEnd = ln[1], ln[2], ln[3], ln[4]
	local dir = zEnd > zTop and 1 or -1
	local f = Instance.new("Folder")
	f.Name = "R_" .. name
	f.Parent = ramps
	local zs, T, B, C = {}, {}, {}, {}
	for z = zTop, zEnd, dir * RUN do
		local hi, lo, center = -1e9, 1e9, nil
		for dx = -WIDTH / 2, WIDTH / 2, 2 do
			local h = hitAt(x + dx, z)
			if h then
				hi = math.max(hi, h.Position.Y)
				lo = math.min(lo, h.Position.Y)
				if math.abs(dx) < 1.5 then
					center = h.Instance
				end
			end
		end
		zs[#zs + 1] = z
		T[#T + 1], B[#B + 1], C[#C + 1] = hi, lo, center
	end
	local y = {}
	for k = 1, #zs do
		y[k] = k == 1 and T[k] or math.max(T[k], y[k - 1] - RISE)
	end
	local placed = 0
	for k = 1, #zs do
		if y[k] > B[k] + 0.3 then
			local top, bot = y[k] + 0.06, B[k] - 1.5 -- 0.06: 옆 땅 윗면과 같은 높이면 반짝인다
			local p = Instance.new("Part")
			p.Name = string.format("Rmp_%s_%d", name, k)
			p.Anchored = true
			-- 칸마다 폭을 조금씩 달리해 자로 그은 계단처럼 보이지 않게
			local w = WIDTH + ((k * 7) % 5 - 2) * 0.8
			p.Size = Vector3.new(w, top - bot, RUN)
			p.CFrame = CFrame.new(x + ((k * 3) % 5 - 2) * 0.4, (top + bot) / 2, zs[k])
			local src = C[k]
			if src then
				p.Color, p.Material = src.Color, src.Material
			else
				p.Color, p.Material = Color3.fromRGB(96, 98, 94), Enum.Material.Slate
			end
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = f
			placed += 1
		end
	end
	nStep += placed
	-- 가장 가파른 곳 (바깥에서 안으로)
	local worst = 0
	for k = 2, #zs do
		worst = math.max(worst, y[k - 1] - y[k])
	end
	out[#out + 1] = string.format("%s: 칸 %d, 디딤돌 %d, 높이 %.1f → %.1f, 한 칸 최대 오름 %.2f", name, #zs, placed, y[#y], y[1], worst)
end

-- 틈 메우기
local fill = S.Mountains:FindFirstChild("HillFill")
if fill then
	fill:Destroy()
end
fill = Instance.new("Folder")
fill.Name = "HillFill"
fill.Parent = S.Mountains
local nFill = 0
for _, b in ipairs(_G.HillGaps or {}) do
	for _, c in ipairs(b.cells) do
		local x = -1900 + c.i * 3
		local z = 60 + c.j * 3
		-- 넷 이웃 높이. 틈은 마주 보는 두 벽 중 낮은 쪽까지 채운다
		local hs = {}
		for _, d in ipairs({ { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } }) do
			local h = hitAt(x + d[1], z + d[2])
			hs[#hs + 1] = h
		end
		local function top2(a, b)
			if a and b then
				return math.min(a.Position.Y, b.Position.Y), (a.Position.Y > b.Position.Y) and a.Instance or b.Instance
			end
		end
		local tEW, iEW = top2(hs[1], hs[2])
		local tNS, iNS = top2(hs[3], hs[4])
		local t, src = tEW, iEW
		if tNS and (not t or tNS > t) then
			t, src = tNS, iNS
		end
		local here = hitAt(x, z)
		local lo = here and here.Position.Y or (t and t - 20)
		if t and lo and t - lo > 1 and src then
			local p = Instance.new("Part")
			p.Name = "Fill"
			p.Anchored = true
			p.Size = Vector3.new(3.4, t - lo + 1, 3.4)
			p.CFrame = CFrame.new(x, (t + lo - 1) / 2 - 0.12, z) -- 낮은 벽보다 0.12 아래. 같은 높이면 반짝인다
			p.Color, p.Material = src.Color, src.Material
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = fill
			nFill += 1
		end
	end
end
out[#out + 1] = string.format("틈 메움 %d", nFill)
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hillfix", table.concat(out, "\n"))
print("hillfix", table.concat(out, " / "))
