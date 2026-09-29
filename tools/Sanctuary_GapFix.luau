--!nocheck
--[[
	Sanctuary_GapFix.luau — 2026-09-27. Sanctuary_GapScan 이 찾은 찐빠를 고친다 → recv/sancgapfix.txt

	뜬 조각(_G.SancGaps)
	  틈 4 이하   그만큼 내려 아래 면에 붙인다 (사당 꼭지, 제단 윗돌)
	  틈 4 넘게   받치던 기둥이 부러져 허공에 남은 것(인방, 주두, 지붕). 옆 땅으로 떨어진 잔해로 눕힌다.
	              제자리에서 조금 비껴, 조금 돌고 기울여, 가장 낮은 모서리가 땅에 0.4 박히게
	  색·재질은 그대로. 부서진 유적 단색을 지킨다
	땅 구멍: GapScan 의 모래톱 구멍 자리에 모래 조각(이웃 높이)을 깐다 (World.G_탑의성역 에 Gs_탑의성역_patch)
	되돌리기: _G.SancGapUndo[p] = { 원래 CFrame } / 모래 조각은 이름으로 찾아 지운다
	GapScan 을 다시 돌려 0 이 될 때까지 번갈아 돌린다.
]]
local S = workspace.Surface
local G = S.World["G_탑의성역"]
local gaps = assert(_G.SancGaps, "Sanctuary_GapScan 을 먼저 돌려라")
_G.SancGapUndo = _G.SancGapUndo or {}
local out = {}
local nDrop, nFall = 0, 0

local function halfY(cf, size)
	local s = size / 2
	return math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
end

local floaters = {}
for _, f in ipairs(gaps) do
	floaters[f.p] = true
end

for i, f in ipairs(gaps) do
	local p = f.p
	if p.Parent then
		if not _G.SancGapUndo[p] then
			_G.SancGapUndo[p] = { p.CFrame }
		end
		if f.gap <= 4 then
			p.CFrame = p.CFrame - Vector3.new(0, f.gap, 0)
			nDrop += 1
		else
			-- 이름으로 정한 흔들림. 같은 파트는 다시 돌려도 같은 자리에 떨어진다
			local seed = 0
			for c in p:GetFullName():gmatch(".") do
				seed = (seed * 31 + string.byte(c)) % 2147483647
			end
			local rng = Random.new(seed)
			local rot = p.CFrame - p.CFrame.Position
			local newRot = CFrame.Angles(0, rng:NextNumber(-0.45, 0.45), 0) * rot
				* CFrame.Angles(rng:NextNumber(-0.22, 0.22), 0, rng:NextNumber(-0.22, 0.22))
			local pos = p.Position + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
			-- 땅에만 떨어뜨린다. 다른 잔해를 맞히면 그 꼭대기(부러진 기둥 머리 따위)에 걸려 다시 뜬다
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { G }
			local h = workspace:Raycast(Vector3.new(pos.X, pos.Y + 5, pos.Z), Vector3.new(0, -200, 0), rp)
			local gy = h and h.Position.Y or 8
			local cf = CFrame.new(pos.X, 0, pos.Z) * newRot
			local e = halfY(cf, p.Size)
			p.CFrame = cf + Vector3.new(0, gy + e - 0.4, 0)
			nFall += 1
			floaters[p] = nil
		end
	end
end
out[#out + 1] = string.format("내려 붙임 %d, 떨어뜨림 %d", nDrop, nFall)

-- 모래톱 구멍
local HOLES = { { -252, -1860 }, { -192, -2008 }, { 50, -2158 }, { 344, -712 }, { 356, -2216 }, { 1044, -1864 } }
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Include
rpG.FilterDescendantsInstances = { G }
local nPatch = 0
for i, hxz in ipairs(HOLES) do
	local name = "Gs_탑의성역_patch_" .. i
	local old = G:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local sum, n, col, mat = 0, 0, nil, nil
	for _, d in ipairs({ { 8, 0 }, { -8, 0 }, { 0, 8 }, { 0, -8 } }) do
		local h = workspace:Raycast(Vector3.new(hxz[1] + d[1], 200, hxz[2] + d[2]), Vector3.new(0, -300, 0), rpG)
		if h then
			sum += h.Position.Y
			n += 1
			col, mat = h.Instance.Color, h.Instance.Material
		end
	end
	if n > 0 then
		local top = sum / n - 0.05
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(12, 3, 12)
		p.CFrame = CFrame.new(hxz[1], top - 1.5, hxz[2])
		p.Color, p.Material = col, mat
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = G
		nPatch += 1
	end
end
out[#out + 1] = "모래 조각 " .. nPatch
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/sancgapfix", table.concat(out, "\n"))
print("sancgapfix", table.concat(out, ", "))
