--!nocheck
--[[
	Swamp_MeshOverlap.luau — 늪지대 메시 모델(판자길·집·마루)끼리 바닥판이 같은 높이로 겹치는 곳을 찾아 가른다. (2026-09-28)

	면 검사(Swamp_ZScan)는 메시의 면을 모른다. 그런데 판자길 조각은 16 칸짜리를 구간 길이로 나눠 놓아
	이웃과 겹치고, 판자길 끝이 집 앞마루와 겹친다. 둘 다 같은 기준 높이(물 -0.4 + 바닥 7)라 판자 윗면이 겹쳐 반짝인다.
	모델 경계 상자(돌린 상자)의 바닥 사각형끼리 분리축 검사로 겹친 넓이를 재고,
	피벗 높이가 같은(0.05 안) 쌍이면 판자길 쪽(둘 다 판자길이면 뒤쪽)을 조금 올린다(모델마다 다른 높이: 0.02~0.059).
	판자 자체가 ±0.03 들쭉날쭉이라 눈에는 안 띈다. 두 번 돌려도 같은 결과(속성 ZOff 로 원래 높이를 기억).
	APPLY = false 면 보고만 한다. 보고: /swampmesh
]]
local APPLY = true
local root = workspace.Surface["Swamp2_늪지대"]
local WALK = { BoardwalkStraight = true, BoardwalkOpen = true, BoardwalkJunction = true, BoardwalkRamp = true, RopeBridge = true }
local DECK = { DeckPlatform = true, FerryDock = true, StiltHouseA = true, StiltHouseB2 = true, StiltHutC = true, Longhouse = true, WitchHut = true, Watchtower = true }

local items = {}
for _, m in ipairs(root:GetDescendants()) do
	local a = m:IsA("Model") and m:GetAttribute("Asset")
	if a and (WALK[a] or DECK[a]) then
		-- 경계는 보이는 메시만으로(충돌체·불빛 받침 제외)
		local cf, size = m:GetBoundingBox()
		items[#items + 1] = { m = m, a = a, walk = WALK[a] == true, cf = cf, size = size, y = m:GetPivot().Y - (m:GetAttribute("ZOff") or 0) }
	end
end

-- 바닥 사각형(XZ) 네 꼭짓점
local function corners(it)
	local cf, s = it.cf, it.size
	local out = {}
	for _, sg in ipairs({ { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }) do
		local p = cf * Vector3.new(sg[1] * s.X / 2, 0, sg[2] * s.Z / 2)
		out[#out + 1] = Vector2.new(p.X, p.Z)
	end
	return out
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
		local function side(p)
			return (b.X - a.X) * (p.Y - a.Y) - (b.Y - a.Y) * (p.X - a.X)
		end
		local S = input[#input]
		for _, E in ipairs(input) do
			local se, ss = side(E), side(S)
			if se >= 0 then
				if ss < 0 then
					out[#out + 1] = S + (E - S) * (ss / (ss - se))
				end
				out[#out + 1] = E
			elseif ss >= 0 then
				out[#out + 1] = S + (E - S) * (ss / (ss - se))
			end
			S = E
		end
	end
	return out
end

local function area(poly)
	local s = 0
	for i = 1, #poly do
		local p, q = poly[i], poly[i % #poly + 1]
		s += p.X * q.Y - q.X * p.Y
	end
	return math.abs(s / 2)
end

local function ccw(poly)
	local s = 0
	for i = 1, #poly do
		local p, q = poly[i], poly[i % #poly + 1]
		s += p.X * q.Y - q.X * p.Y
	end
	if s < 0 then
		local r = {}
		for i = #poly, 1, -1 do
			r[#r + 1] = poly[i]
		end
		return r
	end
	return poly
end

for _, it in ipairs(items) do
	it.poly = ccw(corners(it))
end

local found, out = {}, {}
for i = 1, #items do
	for j = i + 1, #items do
		local A, B = items[i], items[j]
		if (A.walk or B.walk) and math.abs(A.y - B.y) < 0.05 then
			local d = Vector2.new(A.cf.X - B.cf.X, A.cf.Z - B.cf.Z).Magnitude
			if d < (A.size.Magnitude + B.size.Magnitude) / 2 then
				local ar = area(clip(A.poly, B.poly))
				if ar > 0.5 then
					found[#found + 1] = { A = A, B = B, area = ar }
				end
			end
		end
	end
end

-- 올릴 모델: 판자길 쪽. 둘 다 판자길이면 뒤쪽(번호 큰 쪽). 모델마다 다른 높이.
local lift, order = {}, 0
for _, f in ipairs(found) do
	local pick = (f.B.walk and f.B) or f.A
	if not lift[pick.m] then
		order += 1
		lift[pick.m] = 0.02 + 0.013 * (order % 4)
	end
end
-- 같은 높이를 받은 두 모델이 서로 겹치면 한쪽을 한 칸 더
for _, f in ipairs(found) do
	local la, lb = lift[f.A.m] or 0, lift[f.B.m] or 0
	if math.abs(la - lb) < 0.005 then
		lift[f.B.m] = lb + 0.007
	end
end

local n = 0
for m, dz in pairs(lift) do
	if APPLY then
		local old = m:GetAttribute("ZOff") or 0
		m:PivotTo(m:GetPivot() + Vector3.new(0, dz - old, 0))
		m:SetAttribute("ZOff", dz)
	end
	n += 1
end
table.sort(found, function(x, y)
	return x.area > y.area
end)
out[#out + 1] = string.format("모델 %d, 겹친 쌍 %d, 올린 모델 %d%s", #items, #found, n, APPLY and "" or " (보고만)")
for k = 1, math.min(40, #found) do
	local f = found[k]
	out[#out + 1] = string.format("%6.1f  %s @ %.0f,%.0f  ~  %s @ %.0f,%.0f", f.area, f.A.a, f.A.cf.X, f.A.cf.Z, f.B.a, f.B.cf.X, f.B.cf.Z)
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/swampmesh", table.concat(out, "\n"))
print("swampmesh", out[1])
