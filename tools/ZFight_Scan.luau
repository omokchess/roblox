--!nocheck
--[[
	ZFight_Scan.luau — 2026-09-27. 맵의 반짝임(z-fighting)을 찾는다 → recv/zfight.txt

	두 파트의 면이 같은 쪽을 보며 같은 평면(0.01 안)에 놓이고 서로 겹치면, 카메라가 움직일 때
	어느 면이 앞인지 정하지 못해 번갈아 비친다. Workspace 의 네모 파트(Part Block, WedgePart 의 밑·등 면)의
	모든 면을 법선과 평면 거리(0.02 칸)로 묶고, 묶음마다 평면 위 2D 상자를 u 축으로 훑어(sweep and prune)
	넓이가 실제로 겹치는 쌍만 다각형을 잘라 잰다. 1판은 묶음 안 모든 쌍을 잘라 보다가 Studio 를 오래 붙잡았다.
	(메시 파트는 면을 알 수 없어 뺀다. 보이지 않는 파트도 뺀다)
	결과: 전체 쌍 수, 폴더·파트 이름(숫자 뺀 꼴)별 묶음, 겹친 넓이가 큰 순 예시.
	고칠 때 쓰라고 쌍 목록을 _G.ZFightPairs 에 남긴다. 중간중간 쉬어 Studio 가 멈추지 않게 한다.
]]

local EPS_D = 0.01 -- 평면 거리 차이가 이만큼 안이면 반짝인다고 본다
local MIN_AREA = 0.05
local T0 = os.clock()

local buckets = {} -- 법선 열쇠 → { [d 칸] = { 면... } }
local nFaces, nParts = 0, 0

local function kind(p)
	local t = {}
	local x = p.Parent
	while x and x ~= workspace do
		table.insert(t, 1, x.Name)
		x = x.Parent
	end
	local where = table.concat({ t[1] or "", t[2] or "" }, "/")
	return where .. ":" .. (p.Name:gsub("[%d_%-]+$", ""):gsub("_%d+", "_#"))
end

local basisOf = {}
local function basis(nk, n)
	local b = basisOf[nk]
	if not b then
		local ref = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
		local u = n:Cross(ref).Unit
		b = { u = u, v = n:Cross(u).Unit }
		basisOf[nk] = b
	end
	return b
end

local function addFace(p, n, c, a, b)
	local nk = string.format("%d,%d,%d", math.round(n.X * 1000), math.round(n.Y * 1000), math.round(n.Z * 1000))
	local B = basis(nk, n)
	local d = n:Dot(c)
	-- 평면 위 2D 상자
	local cu, cv = c:Dot(B.u), c:Dot(B.v)
	local eu = math.abs(a:Dot(B.u)) + math.abs(b:Dot(B.u))
	local ev = math.abs(a:Dot(B.v)) + math.abs(b:Dot(B.v))
	local f = { p = p, n = n, c = c, a = a, b = b, d = d, u0 = cu - eu, u1 = cu + eu, v0 = cv - ev, v1 = cv + ev }
	local byD = buckets[nk]
	if not byD then
		byD = {}
		buckets[nk] = byD
	end
	local db = math.round(d / 0.02)
	local list = byD[db]
	if not list then
		list = {}
		byD[db] = list
	end
	list[#list + 1] = f
	nFaces += 1
end

local all = workspace:GetDescendants()
for i, p in ipairs(all) do
	if p:IsA("BasePart") and not p:IsA("MeshPart") and not p:IsA("Terrain") and p.Transparency < 0.98 then
		local cf, s = p.CFrame, p.Size / 2
		local R, U, L = cf.RightVector, cf.UpVector, cf.LookVector
		if p:IsA("Part") and p.Shape == Enum.PartType.Block then
			nParts += 1
			addFace(p, R, cf.Position + R * s.X, U * s.Y, L * s.Z)
			addFace(p, -R, cf.Position - R * s.X, U * s.Y, L * s.Z)
			addFace(p, U, cf.Position + U * s.Y, R * s.X, L * s.Z)
			addFace(p, -U, cf.Position - U * s.Y, R * s.X, L * s.Z)
			addFace(p, -L, cf.Position - L * s.Z, R * s.X, U * s.Y)
			addFace(p, L, cf.Position + L * s.Z, R * s.X, U * s.Y)
		elseif p:IsA("WedgePart") then
			nParts += 1
			addFace(p, -U, cf.Position - U * s.Y, R * s.X, L * s.Z)
			addFace(p, L, cf.Position + L * s.Z, R * s.X, U * s.Y)
		end
	end
	if i % 20000 == 0 then
		task.wait()
	end
end

local function quad(f, o, u, v)
	local pts = {}
	for _, sgn in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local w = f.c + f.a * sgn[1] + f.b * sgn[2] - o
		pts[#pts + 1] = { w:Dot(u), w:Dot(v) }
	end
	return pts
end

local function area(poly)
	local s = 0
	for i = 1, #poly do
		local p, q = poly[i], poly[i % #poly + 1]
		s += p[1] * q[2] - q[1] * p[2]
	end
	return s / 2
end

local function ccw(poly)
	if area(poly) < 0 then
		local r = {}
		for i = #poly, 1, -1 do
			r[#r + 1] = poly[i]
		end
		return r
	end
	return poly
end

local function clip(subject, clipper)
	local out = subject
	for i = 1, #clipper do
		local a, b = clipper[i], clipper[i % #clipper + 1]
		local input = out
		out = {}
		if #input == 0 then
			break
		end
		local function inside(p)
			return (b[1] - a[1]) * (p[2] - a[2]) - (b[2] - a[2]) * (p[1] - a[1]) >= -1e-9
		end
		local function inter(p, q)
			local x1, y1, x2, y2 = a[1], a[2], b[1], b[2]
			local x3, y3, x4, y4 = p[1], p[2], q[1], q[2]
			local den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
			if math.abs(den) < 1e-12 then
				return q
			end
			local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
			return { x1 + t * (x2 - x1), y1 + t * (y2 - y1) }
		end
		local S = input[#input]
		for _, E in ipairs(input) do
			if inside(E) then
				if not inside(S) then
					out[#out + 1] = inter(S, E)
				end
				out[#out + 1] = E
			elseif inside(S) then
				out[#out + 1] = inter(S, E)
			end
			S = E
		end
	end
	return out
end

local pairsFound = {}
local work = 0
local function test(f, g)
	if f.p == g.p or math.abs(g.d - f.d) >= EPS_D then
		return
	end
	if math.min(f.v1, g.v1) - math.max(f.v0, g.v0) < 0.01 then
		return
	end
	local o, u = f.c, f.a.Unit
	local v = f.n:Cross(u).Unit
	local ar = math.abs(area(clip(ccw(quad(f, o, u, v)), ccw(quad(g, o, u, v)))))
	if ar > MIN_AREA then
		pairsFound[#pairsFound + 1] = {
			a = f.p, b = g.p, n = f.n, d = f.d, dd = g.d - f.d, area = ar,
			same = f.p.Color == g.p.Color and f.p.Material == g.p.Material,
		}
	end
end

-- 묶음 db 안, 그리고 db 와 db+1 사이를 u 축으로 훑는다
local function sweep(list)
	table.sort(list, function(x, y)
		return x.u0 < y.u0
	end)
	local active = {}
	for _, f in ipairs(list) do
		local keep = {}
		for _, g in ipairs(active) do
			if g.u1 - f.u0 > 0.01 then
				keep[#keep + 1] = g
				if f.tag ~= g.tag or f.tag == 0 then
					test(f, g)
				end
			end
		end
		keep[#keep + 1] = f
		active = keep
		work += 1
		if work % 30000 == 0 then
			task.wait()
		end
	end
end

for _, byD in pairs(buckets) do
	for db, list in pairs(byD) do
		for _, f in ipairs(list) do
			f.tag = 0
		end
		sweep(list)
		local nxt = byD[db + 1]
		if nxt then
			-- 두 묶음 사이 쌍만: 같은 묶음끼리는 이미 봤다
			local mix = {}
			for _, f in ipairs(list) do
				f.tag = 1
				mix[#mix + 1] = f
			end
			for _, g in ipairs(nxt) do
				g.tag = 2
				mix[#mix + 1] = g
			end
			sweep(mix)
			for _, g in ipairs(nxt) do
				g.tag = 0
			end
		end
	end
end

_G.ZFightPairs = pairsFound

local groups = {}
local nSame, nVis = 0, 0
for _, q in ipairs(pairsFound) do
	if q.same then
		nSame += 1
	end
	if q.n.Y > -0.5 then
		nVis += 1
	end
	local ka, kb = kind(q.a), kind(q.b)
	if q.n.Y <= -0.5 then
		ka = "(밑면) " .. ka
	end
	if ka > kb then
		ka, kb = kb, ka
	end
	local k = ka .. "  ~  " .. kb .. (q.same and "  (같은 빛)" or "")
	local g = groups[k]
	if not g then
		g = { n = 0, area = 0, ex = q }
		groups[k] = g
	end
	g.n += 1
	g.area += q.area
end
local keys = {}
for k in pairs(groups) do
	keys[#keys + 1] = k
end
table.sort(keys, function(x, y)
	return groups[x].area > groups[y].area
end)

local out = {}
out[#out + 1] = string.format("파트 %d, 면 %d, 반짝이는 쌍 %d (같은 빛 %d, 아래 보지 않는 면 %d), %.1f 초", nParts, nFaces,
	#pairsFound, nSame, nVis, os.clock() - T0)
out[#out + 1] = "== 묶음 (넓이 큰 순): 쌍 수, 겹친 넓이 합, 예시 위치, 법선"
for i, k in ipairs(keys) do
	if i > 200 then
		break
	end
	local g = groups[k]
	local p = g.ex.a.Position
	out[#out + 1] = string.format("%5d %9.1f  %s   @ %.0f %.0f %.0f n(%.0f,%.0f,%.0f)", g.n, g.area, k, p.X, p.Y, p.Z,
		g.ex.n.X, g.ex.n.Y, g.ex.n.Z)
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/zfight", table.concat(out, "\n"))
print("zfight", #pairsFound)
