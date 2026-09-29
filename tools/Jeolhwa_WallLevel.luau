--!nocheck
--[[
	Jeolhwa_WallLevel.luau — 절화 담 토막 높이를 맞춘다(2026-09-29 사용자: "절화 담장 높이가 각 담장마다 조금씩 다른 것도 수정해 줘").
	담은 토막(20 가량)마다 제 발밑 가장 높은 땅에 앉혀져, 이웃 토막끼리 윗선이 0.2~0.6 씩 들쭉날쭉했고
	궁 남쪽 담 한 줄은 개울 턱에서 두 토막이 3 스터드나 꺼졌다.
	같은 동네(궁·북촌·관아 …)·같은 종류 담은 **가장 높은 토막의 바닥선**으로 모두 올리고, 올린 만큼 밑을 담 아랫돌과 같은 빛의
	돌 받침(LevelFoundation, 폭 +0.8 로 턱이 지게)이 땅 밑 1.5 까지 채운다. 싸리 울타리는 차이가 0.2 뿐이라 그대로 둔다.
	다시 돌려도 된다(이미 맞춰졌으면 아무것도 안 바뀐다). 보고: /jwall_level
]]
local HS = game:GetService("HttpService")
local KINDS = { Wall_Segment = true, Wall_Stone = true }
local report = {}

local function halfExtents(p, frame)
	local r = frame:ToObjectSpace(p.CFrame)
	local s = p.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

local ok, err = pcall(function()
	-- 폴더·종류별로 모은다
	local groups = {}
	for _, m in ipairs(workspace.Jeolhwa:GetDescendants()) do
		if m:IsA("Model") then
			local kind = string.match(m.Name, "^(Wall_%a+)_%d+_%d+$")
			if kind and KINDS[kind] then
				local frame = m:GetPivot()
				local lo, list = math.huge, {}
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") and p.Name ~= "Foundation" and p.Name ~= "LevelFoundation" then
						local e, c = halfExtents(p, frame)
						list[#list + 1] = { p = p, e = e, c = c }
						lo = math.min(lo, c.Y - e.Y)
					end
				end
				-- 묶음 = 동네(Jeolhwa 바로 아래 폴더: 궁·북촌·관아 …) × 담 종류. 궁 바깥 담과 동궁 담이 만나는 곳의 턱도 없앤다
				local district = m
				while district.Parent and district.Parent ~= workspace.Jeolhwa do
					district = district.Parent
				end
				local key = district.Name .. "|" .. kind
				groups[key] = groups[key] or {}
				-- lo 는 틀(피벗) 기준, base 는 월드 바닥선
				table.insert(groups[key], { m = m, frame = frame, lo = lo, base = frame.Y + lo, list = list })
			end
		end
	end
	local nMoved, nGroups, maxLift = 0, 0, 0
	for key, g in pairs(groups) do
		nGroups += 1
		local target = -math.huge
		for _, w in ipairs(g) do
			target = math.max(target, w.base)
		end
		for _, w in ipairs(g) do
			local dy = target - w.base
			if dy > 0.02 then
				local m = w.m
				-- 받침은 맨 아래 층 파트들(아랫돌)의 발자국·빛을 따른다
				local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
				local look
				for _, q in ipairs(w.list) do
					if q.c.Y - q.e.Y < w.lo + 0.3 then
						x0, x1 = math.min(x0, q.c.X - q.e.X), math.max(x1, q.c.X + q.e.X)
						z0, z1 = math.min(z0, q.c.Z - q.e.Z), math.max(z1, q.c.Z + q.e.Z)
						look = look or q.p
					end
				end
				m:PivotTo(m:GetPivot() + Vector3.new(0, dy, 0))
				local oldBase = w.base
				local newBase = oldBase + dy
				local bottom = oldBase - 1.5
				local c = w.frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))
				local f = Instance.new("Part")
				f.Name = "LevelFoundation"
				f.Anchored = true
				f.Size = Vector3.new(x1 - x0 + 0.8, newBase - bottom, z1 - z0 + 0.8)
				f.CFrame = CFrame.new(c.X, (newBase + bottom) / 2, c.Z) * w.frame.Rotation
				f.Color = look and look.Color or Color3.fromRGB(120, 116, 108)
				f.Material = look and look.Material or Enum.Material.Slate
				f.TopSurface, f.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				f.Parent = m
				nMoved += 1
				maxLift = math.max(maxLift, dy)
			end
		end
	end
	table.insert(report, string.format("담 묶음 %d, 올린 토막 %d, 가장 많이 올린 것 %.2f", nGroups, nMoved, maxLift))
end)
if not ok then
	table.insert(report, "ERR " .. tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/jwall_level", table.concat(report, "\n"))
end)
