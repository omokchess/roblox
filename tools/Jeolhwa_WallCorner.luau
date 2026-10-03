--!nocheck
--[[
	Jeolhwa_WallCorner.luau — 2026-10-03. 기와 담 ㄱ자 모서리에 Wall_Corner(추녀 귀 마감)를 앉힌다(편집 모드, StudioJobs).

	사용자(2026-10-03): "요런 담 모서리 부분도 자연스럽게 수정해줄 수 있어?" — 담 토막 둘이 모서리에서 박공으로 끝나
	기와 사이가 비고 벽면이 어긋났다. 모델은 models/build_wall_corner.py → Wall_Corner.fbx (원점 = 두 가운데선 교점, 두 팔).
	  1. 틀 만들기(처음 한 번): Ctrl+M 으로 가져온 Workspace.Wall_Corner 를 받아 원점 표지로 피벗을 잡고,
	     담 토막 틀(JeolhwaKit.Wall_Segment)과 같은 빛·재질을 입히고 세로를 같은 배율로 늘려 ServerStorage.JeolhwaKit.Wall_Corner 로
	  2. 놓기: jeolhwa_plan.py wall_corners() 표(D.CORNERS)마다 두 팔이 담 줄을 따라가게 90도 단위로 돌려 앉힌다.
	     높이는 Plains_WallSettle 이 담 토막과 같이 맞춘다(뒤에 돌릴 것). 다시 돌리면 놓인 모서리를 지우고 새로
	붙여 쓰는 법: sed '/--@@DATA@@/r tools/Jeolhwa_City3_data.luau' tools/Jeolhwa_WallCorner.luau > run → job.sh. 보고: /wallcorner
]]
--@@DATA@@

local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local kit = SS.JeolhwaKit
	local seg = kit.Wall_Segment
	-- 담 토막 틀의 켜 이름 → 빛·재질, 세로 배율(돌 켜 높이 / 블렌더 2.5)
	local look = {}
	for _, p in seg:GetDescendants() do
		if p:IsA("BasePart") then
			look[p.Name:match("_(%a+)$")] = p
		end
	end
	local k = look.Masonry.Size.Y / 2.5

	-- 1. 틀
	local tpl = kit:FindFirstChild("Wall_Corner")
	local fresh = workspace:FindFirstChild("Wall_Corner")
	if fresh then
		local marker
		for _, p in fresh:GetDescendants() do
			if p:IsA("BasePart") and p.Name:match("Marker$") then
				marker = p
			end
		end
		assert(marker, "원점 표지가 없다")
		-- 표지 밑면 = 원점(블렌더 z 0)
		local origin = CFrame.new(marker.Position - Vector3.new(0, marker.Size.Y / 2, 0))
		marker:Destroy()
		local m = Instance.new("Model")
		m.Name = "Wall_Corner"
		for _, p in fresh:GetDescendants() do
			if p:IsA("BasePart") then
				local rel = origin:ToObjectSpace(p.CFrame)
				p.Size = Vector3.new(p.Size.X, p.Size.Y * k, p.Size.Z)
				p.CFrame = CFrame.new(rel.X, rel.Y * k, rel.Z) * rel.Rotation
				local suffix = p.Name:match("_(%a+)$")
				local src = look[suffix]
				assert(src, "담 토막에 없는 켜 " .. p.Name)
				p.Name = "WallC_" .. suffix
				p.Color, p.Material = src.Color, src.Material
				p.CanCollide, p.CastShadow = src.CanCollide, src.CastShadow
				if p:IsA("MeshPart") and src:IsA("MeshPart") then
					p.CollisionFidelity = src.CollisionFidelity
					p.RenderFidelity = Enum.RenderFidelity.Precise
				end
				p.Anchored = true
				p.Parent = m
			end
		end
		m.WorldPivot = CFrame.new()
		fresh:Destroy()

		if tpl then
			tpl:Destroy()
		end
		m.Parent = kit
		tpl = m
		say("틀 만듦(세로 배율 %.3f)", k)
	end
	assert(tpl, "Wall_Corner 틀이 없다 — FBX 를 먼저 가져올 것")

	-- 틀의 두 팔 방향(피벗 기준 상자에서 + 쪽으로 멀리 나간 두 축)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in tpl:GetDescendants() do
		if p:IsA("BasePart") then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local c = p.CFrame * Vector3.new(sx * p.Size.X / 2, 0, sz * p.Size.Z / 2)
					lo, hi = lo:Min(c), hi:Max(c)
				end
			end
		end
	end
	local arms = {}
	if hi.X > -lo.X + 0.5 then table.insert(arms, Vector3.xAxis) end
	if -lo.X > hi.X + 0.5 then table.insert(arms, -Vector3.xAxis) end
	if hi.Z > -lo.Z + 0.5 then table.insert(arms, Vector3.zAxis) end
	if -lo.Z > hi.Z + 0.5 then table.insert(arms, -Vector3.zAxis) end
	assert(#arms == 2, "틀 팔을 못 찾음 " .. #arms)
	-- 밑받침(SettleFoundation): 담을 땅에서 띄울 때(Plains_WallSettle LIFT) 돌 켜가 땅까지 이어져 보이게
	-- ㄱ자 돌 켜를 그대로 1.6 아래로. 팔 끝 = 상자 끝, 두께 = 돌 켜 두께(피벗 가운데에서 ±h)
	if not tpl:FindFirstChild("SettleFoundation") then
		local mas = tpl.WallC_Masonry
		local mlo, mhi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local c = mas.CFrame * Vector3.new(sx * mas.Size.X / 2, 0, sz * mas.Size.Z / 2)
				mlo, mhi = mlo:Min(c), mhi:Max(c)
			end
		end
		-- 팔 a 를 따라 돌 켜가 차지하는 구간 [-h, R]
		local function span(a: Vector3): (number, number)
			if a.X > 0 then
				return mlo.X, mhi.X
			elseif a.X < 0 then
				return -mhi.X, -mlo.X
			elseif a.Z > 0 then
				return mlo.Z, mhi.Z
			end
			return -mhi.Z, -mlo.Z
		end
		local h = -select(1, span(arms[1]))
		for i, a in arms do
			local _, to = span(a)
			local from = if i == 1 then -h else h
			local len = to - from
			local f = Instance.new("Part")
			f.Name = "SettleFoundation"
			f.Anchored = true
			f.Size = if a.X ~= 0 then Vector3.new(len, 1.6, 2 * h) else Vector3.new(2 * h, 1.6, len)
			f.CFrame = CFrame.new(a * (from + len / 2) - Vector3.new(0, 0.8, 0))
			f.Color, f.Material = mas.Color, mas.Material
			f.TopSurface, f.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			f.Parent = tpl
		end
		say("틀 밑받침 두 토막(돌 켜 반두께 %.2f)", h)
	end

	-- 2. 놓기
	for _, d in workspace.Jeolhwa:GetDescendants() do
		if d:IsA("Model") and d.Name == "Wall_Corner" then
			d:Destroy()
		end
	end
	local placed = 0
	for _, c in D.CORNERS do
		local x, z = c[1], c[2]
		local want = { Vector3.new(c[3], 0, c[4]), Vector3.new(c[5], 0, c[6]) }
		local best
		for yaw = 0, 270, 90 do
			local r = CFrame.Angles(0, math.rad(yaw), 0)
			local a1, a2 = r:VectorToWorldSpace(arms[1]), r:VectorToWorldSpace(arms[2])
			local okA = ((a1 - want[1]).Magnitude < 0.1 and (a2 - want[2]).Magnitude < 0.1)
				or ((a1 - want[2]).Magnitude < 0.1 and (a2 - want[1]).Magnitude < 0.1)
			if okA then
				best = r
			end
		end
		assert(best, string.format("모서리 (%.0f,%.0f) 방향을 못 맞춤", x, z))
		-- 그 모서리 담 토막이 든 폴더(가장 가까운 Wall_Segment)
		local parent, bd = nil, 40
		for _, w in workspace.Jeolhwa:GetDescendants() do
			if w:IsA("Model") and w.Name:match("^Wall_Segment") then
				local p = w:GetPivot().Position
				local dist = (Vector2.new(p.X, p.Z) - Vector2.new(x, z)).Magnitude
				if dist < bd then
					parent, bd = w.Parent, dist
				end
			end
		end
		assert(parent, string.format("모서리 (%.0f,%.0f) 근처에 담이 없다", x, z))
		local m = tpl:Clone()
		m:PivotTo(CFrame.new(x, 1.9, z) * best)
		m.Parent = parent
		placed += 1
	end
	say("모서리 %d 곳", placed)
end)
HS:PostAsync("http://127.0.0.1:34999/wallcorner", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
