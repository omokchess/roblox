--!nocheck
--[[
	Snow_Audit.luau — 2026-09-27. 슈네라이히에서 서로 맞지 않게 파고든 구조물을 찾는다.

	구조물 단위
	  - Schneereich 아래 가장 바깥 Model 하나 (집, 가로등, 톱니 …)
	  - 난방관/<이름> 폴더 하나 (관 조각끼리는 일부러 겹친다)
	  - 그 밖의 낱 파트 하나 (방 안 가구 하나하나)
	  - 설림 나무 한 그루 (사용자 것. 손대지 않고 보기만 한다)
	땅(돌/길 폴더, Foundation)과 보이지 않는 파트는 뺀다.
	서로 다른 단위의 파트가 겹치면 두 파트 세계 AABB 가 겹친 상자의 가장 짧은 변을 깊이로 적는다.
	방 안에서는 아무것에도 닿지 않은 파트(뜬 것)도 적는다. 문 앞 설 자리와 방 도착 자리를 막는 것도 적는다.
]]

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local restore = {}
local ok, err = pcall(function()
	local city = assert(workspace:FindFirstChild("Schneereich"), "도시가 없다")
	local trees = workspace.Surface["Zone_설원"]:FindFirstChild("설림")

	-- 톱니는 CanQuery 가 꺼져 있다. 점검하는 동안만 켠다
	for _, p in ipairs(city:GetDescendants()) do
		if p:IsA("BasePart") and not p.CanQuery and p.Transparency < 1 then
			p.CanQuery = true
			restore[#restore + 1] = p
		end
	end

	local function rel(inst)
		local segs = {}
		local a = inst
		while a and a ~= city do
			table.insert(segs, 1, a.Name)
			a = a.Parent
		end
		return segs
	end
	local unitOf, label = {}, {}
	local function fmtPos(v)
		return string.format("(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
	end
	for _, p in ipairs(city:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "Foundation" then
			local segs = rel(p)
			local top = segs[1]
			if top ~= "돌" and top ~= "길" then
				local m
				local a = p.Parent
				while a and a ~= city do
					if a:IsA("Model") then
						m = a
					end
					a = a.Parent
				end
				local u
				if m then
					u = m
					label[u] = label[u] or (table.concat(rel(m), "/") .. fmtPos(m:GetPivot().Position))
				elseif top == "난방관" then
					u = p.Parent
					label[u] = label[u] or table.concat(rel(u), "/")
				else
					u = p
					label[u] = table.concat(rel(p), "/") .. fmtPos(p.Position)
				end
				unitOf[p] = u
			end
		end
	end
	if trees then
		-- 나무는 Model 이 아니라 Folder 일 수 있다. 자리는 첫 파트로 적는다
		for _, t in ipairs(trees:GetChildren()) do
			for _, p in ipairs(t:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					unitOf[p] = t
					label[t] = label[t] or ("나무 " .. t.Name .. fmtPos(p.Position))
				end
			end
		end
	end

	local function aabb(p)
		local s = p.Size / 2
		local R = p.CFrame.RightVector
		local U = p.CFrame.UpVector
		local L = p.CFrame.LookVector
		local e = Vector3.new(
			math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
			math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
			math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
		)
		return p.Position - e, p.Position + e
	end
	local function depth(a, b)
		local a0, a1 = aabb(a)
		local b0, b1 = aabb(b)
		local lo, hi = a0:Max(b0), a1:Min(b1)
		local d = hi - lo
		return math.min(d.X, d.Y, d.Z), (lo + hi) / 2
	end

	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = trees and { city, trees } or { city }
	op.MaxParts = 80

	local pairsFound = {}
	local nQ = 0
	for p, u in pairs(unitOf) do
		if p:IsDescendantOf(city) then
			nQ += 1
			if nQ % 300 == 0 then
				task.wait()
			end
			for _, q in ipairs(workspace:GetPartsInPart(p, op)) do
				local v = unitOf[q]
				if v and v ~= u then
					local la, lb = label[u], label[v]
					local key = la < lb and (la .. " | " .. lb) or (lb .. " | " .. la)
					local d, at = depth(p, q)
					local e = pairsFound[key]
					if not e or d > e.d then
						pairsFound[key] = { d = d, at = at, a = p.Name, b = q.Name }
					end
				end
			end
		end
	end
	local list = {}
	for key, e in pairs(pairsFound) do
		if e.d >= 0.2 then
			list[#list + 1] = { key = key, e = e }
		end
	end
	table.sort(list, function(x, y)
		return x.key < y.key
	end)
	say("겹침 %d 쌍 (깊이 0.2 이상)", #list)
	for _, it in ipairs(list) do
		say("%.2f  %s  [%s ~ %s] %s", it.e.d, it.key, it.e.a, it.e.b, fmtPos(it.e.at))
	end

	-- 방 안에서 뜬 것
	local rooms = city:FindFirstChild("안쪽방")
	if rooms then
		for _, room in ipairs(rooms:GetChildren()) do
			local ob = OverlapParams.new()
			ob.FilterType = Enum.RaycastFilterType.Include
			ob.FilterDescendantsInstances = { room }
			for _, p in ipairs(room:GetDescendants()) do
				-- 낱 파트만 본다. 모델 부품은 제 모델끼리만 닿아도 된다(모델은 통째로 바닥에 선다)
				if p:IsA("BasePart") and p.Transparency < 1 and unitOf[p] == p then
					local touching = false
					for _, q in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size + Vector3.new(0.16, 0.16, 0.16), ob)) do
						if q ~= p and unitOf[q] ~= unitOf[p] then
							touching = true
							break
						end
					end
					if not touching then
						say("뜸  %s/%s %s", room.Name, p.Name, fmtPos(p.Position))
					end
				end
			end
		end
	end

	-- 문 앞 설 자리와 방 도착 자리
	local CS = game:GetService("CollectionService")
	local ofree = OverlapParams.new()
	ofree.FilterType = Enum.RaycastFilterType.Include
	ofree.FilterDescendantsInstances = trees and { city, trees } or { city }
	local function blockers(pos)
		local names = {}
		for _, q in ipairs(workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(3, 4.6, 3), ofree)) do
			if q.CanCollide and q.Transparency < 1 then
				names[#names + 1] = table.concat(rel(q), "/")
			end
		end
		return #names == 0 and "비었음" or table.concat(names, ", ")
	end
	for _, d in ipairs(CS:GetTagged("SnowDoor")) do
		local rp = d:GetAttribute("ReturnPos")
		say("문앞 %s %s: %s", d:GetAttribute("InteriorId"), fmtPos(rp), blockers(rp + Vector3.new(0, 0.3, 0)))
	end
	for _, a in ipairs(CS:GetTagged("SnowArrive")) do
		local pos = a.Position + Vector3.new(0, 2.8, 0)
		say("도착 %s %s: %s", a:GetAttribute("InteriorId"), fmtPos(pos), blockers(pos))
	end

end)
for _, p in ipairs(restore) do
	p.CanQuery = false
end
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/audit", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("audit", #report, ok)
