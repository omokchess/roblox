--!nocheck
--[[
	ZFight_Fix.luau — 2026-09-27. ZFight_Scan 이 찾은 반짝이는 쌍을 가른다 → recv/zfixed.txt

	쌍마다 한쪽 파트를 그 면 쪽으로 STEP(0.03) 만큼 키워(반대쪽 면은 제자리) 두 면이 더는 같은 평면에 있지 않게 한다.
	- 아래를 보는 면(땅 밑)은 보이지 않으니 건드리지 않는다
	- 내가 지은 것(Surface 밖: 절화, 슈네라이히 …)과 Surface 의 땅이 겹치면 내 것을 키운다
	- 둘 다 같은 쪽이면 겹치는 면이 작은 쪽(얹힌 조각)을 키운다
	- 한 파트가 여러 쌍에 걸리면 올린 양을 쌓아 가며, 가른 뒤에도 같은 평면이면 한 켜 더 올린다
	되돌리기: _G.ZFightUndo 에 원래 Size, CFrame 을 남긴다 (ZFight_Undo 한 줄: for p,o in pairs(_G.ZFightUndo) do p.Size=o[1]; p.CFrame=o[2] end)
	먼저 ZFight_Scan.luau 를 같은 세션에서 돌려 _G.ZFightPairs 를 만들어 둘 것.
]]

local STEP = 0.03
local pairsIn = assert(_G.ZFightPairs, "ZFight_Scan 을 먼저 돌려라")
local surface = workspace:FindFirstChild("Surface")

local function mine(p)
	return not (surface and p:IsDescendantOf(surface))
end

-- 면 법선이 파트의 어느 로컬 축인지
local function axisOf(p, n)
	local cf = p.CFrame
	for _, e in ipairs({ { "X", cf.RightVector }, { "Y", cf.UpVector }, { "Z", cf.LookVector } }) do
		local dot = e[2]:Dot(n)
		if math.abs(dot) > 0.999 then
			return e[1], dot > 0 and 1 or -1
		end
	end
end

local function faceArea(p, ax)
	local s = p.Size
	if ax == "X" then
		return s.Y * s.Z
	elseif ax == "Y" then
		return s.X * s.Z
	end
	return s.X * s.Y
end

local function nkey(n)
	return string.format("%d,%d,%d", math.round(n.X * 1000), math.round(n.Y * 1000), math.round(n.Z * 1000))
end

local list = {}
for _, q in ipairs(pairsIn) do
	if q.n.Y > -0.5 and q.a.Parent and q.b.Parent then
		list[#list + 1] = q
	end
end
table.sort(list, function(x, y)
	return x.area > y.area
end)

local off = {} -- off[part][nk] = { n, 올린 양 }
local function getOff(p, nk)
	local t = off[p]
	return t and t[nk] and t[nk][2] or 0
end
local function addOff(p, nk, n, dv)
	off[p] = off[p] or {}
	local e = off[p][nk] or { n, 0 }
	e[2] += dv
	off[p][nk] = e
end

local nRaised = 0
for _, q in ipairs(list) do
	local nk = nkey(q.n)
	local da = q.d + getOff(q.a, nk)
	local db = q.d + q.dd + getOff(q.b, nk)
	if math.abs(da - db) < 0.012 then
		local up
		local ma, mb = mine(q.a), mine(q.b)
		if ma ~= mb then
			up = ma and q.a or q.b
		else
			local axA = axisOf(q.a, q.n)
			local axB = axisOf(q.b, q.n)
			local arA = axA and faceArea(q.a, axA) or math.huge
			local arB = axB and faceArea(q.b, axB) or math.huge
			up = arA <= arB and q.a or q.b
		end
		local cur = (up == q.a) and da or db
		local need = math.max(da, db) + STEP - cur
		addOff(up, nk, q.n, need)
		nRaised += 1
	end
end

_G.ZFightUndo = _G.ZFightUndo or {}
local nParts, byKind, skipped = 0, {}, 0
for p, faces in pairs(off) do
	for _, e in pairs(faces) do
		local n, dv = e[1], e[2]
		local ax = axisOf(p, n)
		if ax and dv > 0 then
			if not _G.ZFightUndo[p] then
				_G.ZFightUndo[p] = { p.Size, p.CFrame }
			end
			local s = p.Size
			p.Size = Vector3.new(s.X + (ax == "X" and dv or 0), s.Y + (ax == "Y" and dv or 0), s.Z + (ax == "Z" and dv or 0))
			p.CFrame = p.CFrame + n * (dv / 2)
			local where = p.Parent and p.Parent.Name or "?"
			local k = where .. ":" .. (p.Name:gsub("[%d_%-]+$", ""))
			byKind[k] = (byKind[k] or 0) + 1
		else
			skipped += 1
		end
	end
	nParts += 1
end

local out = { string.format("쌍 %d 중 보이는 쪽 %d, 가른 쌍 %d, 손본 파트 %d, 축 못 찾음 %d", #pairsIn, #list, nRaised, nParts, skipped) }
local keys = {}
for k in pairs(byKind) do
	keys[#keys + 1] = k
end
table.sort(keys, function(x, y)
	return byKind[x] > byKind[y]
end)
for i, k in ipairs(keys) do
	if i > 80 then
		break
	end
	out[#out + 1] = string.format("%5d  %s", byKind[k], k)
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/zfixed", table.concat(out, "\n"))
print("zfixed", nRaised, nParts)
