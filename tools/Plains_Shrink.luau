--!nocheck
--[[
	Plains_Shrink.luau — 2026-10-09. 평원·절화 줄이기(사용자: "평원 크기를 줄이면서 숲도 줄이자, 절화 줄여도 돼" → 2판 배치 승인).
	배치 = tools/forest_plan.py(JEOLHWA_KEEP/DROP · JEOLHWA · PLAINS). 지우지 않고 ServerStorage 로 옮긴다(FromPath 속성).
	  1. 절화 바깥 구역 서촌·북촌·남촌·산정자 폴더째 → ServerStorage.Jeolhwa_Shrink.<구역>
	  2. 절화 안살림(집 안 소품 묶음): 가장 가까운 건물이 빠진 구역 것이면 같이 → Jeolhwa_Shrink.안살림
	  3. 절화 길·나무·돌·물·서촌길가 파트: 남긴 절화 경계(+10) 밖이면 → Jeolhwa_Shrink.<폴더>
	  4. 평원(R_평원북·동·중·채움·R_평원): Land 판은 새 평원 상자로 잘라 줄이고(밖이면 옮김),
	     그 밖 물건(하위 폴더의 자식 단위)은 가운데가 새 평원 밖이면 → TerrainBackup.PlainsShrink.<지역>.<하위>
	두 번 돌려도 된다(이미 옮긴 것은 없으니 건너뛴다). 보고: /plainsshrink
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")

local KEEP = { "궁", "광장", "저자", "저잣마당", "관아", "주막", "서촌길가", "동촌", "척수관", "마방" }
local DROP = { "서촌", "북촌", "남촌", "산정자" }
local J = { 20, 300, 660, 960 } -- 남긴 절화 x0, z0, x1, z1
local P = { -200, 110, 880, 1059 } -- 새 평원 x0, z0, x1, z1

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local function center(inst)
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	end
	local lo, hi, n = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9), 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			lo, hi, n = lo:Min(d.Position), hi:Max(d.Position), n + 1
		end
	end
	return if n > 0 then (lo + hi) / 2 else nil
end
local function holder(root, ...)
	local node = root
	for _, name in { ... } do
		local c = node:FindFirstChild(name)
		if not c then
			c = Instance.new("Folder")
			c.Name = name
			c.Parent = node
		end
		node = c
	end
	return node
end
local function stash(inst, dest)
	inst:SetAttribute("FromPath", inst:GetFullName())
	inst.Parent = dest
end

local ok, err = pcall(function()
	local JW = workspace.Jeolhwa
	local jroot = holder(SS, "Jeolhwa_Shrink")

	-- 2 먼저(빠질 구역 건물이 아직 제자리에 있을 때): 건물 가운데 목록
	local buildings = {}
	for _, list in { { KEEP, true }, { DROP, false } } do
		for _, name in list[1] do
			local f = JW:FindFirstChild(name)
			for _, b in (f and f:GetChildren()) or {} do
				local c = center(b)
				if c then
					buildings[#buildings + 1] = { c, list[2] }
				end
			end
		end
	end
	local an = JW:FindFirstChild("안살림")
	local movedIn = 0
	for _, item in (an and an:GetChildren()) or {} do
		local c = center(item)
		if c then
			local best, keep = math.huge, true
			for _, b in buildings do
				local d = (Vector2.new(b[1].X, b[1].Z) - Vector2.new(c.X, c.Z)).Magnitude
				if d < best then
					best, keep = d, b[2]
				end
			end
			if not keep then
				stash(item, holder(jroot, "안살림"))
				movedIn += 1
			end
		end
	end
	say("안살림 %d묶음 옮김", movedIn)

	-- 1
	for _, name in DROP do
		local f = JW:FindFirstChild(name)
		if f then
			local n = #f:GetDescendants()
			stash(f, jroot)
			say("절화 %s 옮김(%d)", name, n)
		end
	end

	-- 3
	for _, name in { "길", "나무", "돌", "물", "서촌길가" } do
		local f = JW:FindFirstChild(name)
		local n = 0
		for _, d in (f and f:GetDescendants()) or {} do
			if d:IsA("BasePart") then
				local p = d.Position
				if p.X < J[1] - 10 or p.X > J[3] + 10 or p.Z < J[2] - 10 or p.Z > J[4] + 10 then
					local dest = holder(jroot, name)
					d:SetAttribute("FromPath", d:GetFullName())
					d.Parent = dest
					n += 1
				end
			end
		end
		-- 빈 모델·폴더 정리
		for _, d in (f and f:GetDescendants()) or {} do
			if (d:IsA("Model") or d:IsA("Folder")) and #d:GetDescendants() == 0 then
				d:Destroy()
			end
		end
		say("절화 %s 파트 %d 옮김", name, n)
	end

	-- 4
	local proot = holder(SS, "TerrainBackup", "PlainsShrink")
	local function outside(c)
		return c.X < P[1] or c.X > P[3] or c.Z < P[2] or c.Z > P[4]
	end
	for _, region in { "R_평원북", "R_평원동", "R_평원중", "R_평원채움", "R_평원" } do
		local rf = workspace.Surface:FindFirstChild(region)
		if not rf then
			continue
		end
		local clipped, movedLand, moved = 0, 0, 0
		for _, sub in rf:GetChildren() do
			if sub.Name == "Land" then
				for _, p in sub:GetChildren() do
					if not p:IsA("BasePart") then
						continue
					end
					local pos, s = p.Position, p.Size
					local x0, x1 = math.max(pos.X - s.X / 2, P[1]), math.min(pos.X + s.X / 2, P[3])
					local z0, z1 = math.max(pos.Z - s.Z / 2, P[2]), math.min(pos.Z + s.Z / 2, P[4])
					if x1 - x0 < 1 or z1 - z0 < 1 then
						stash(p, holder(proot, region, "Land"))
						movedLand += 1
					elseif x1 - x0 < s.X - 0.01 or z1 - z0 < s.Z - 0.01 then
						p:SetAttribute("ShrinkFrom", string.format("%.2f,%.2f,%.2f|%.2f,%.2f,%.2f", pos.X, pos.Y, pos.Z, s.X, s.Y, s.Z))
						p.Size = Vector3.new(x1 - x0, s.Y, z1 - z0)
						p.Position = Vector3.new((x0 + x1) / 2, pos.Y, (z0 + z1) / 2)
						clipped += 1
					end
				end
			elseif sub:IsA("BasePart") or sub:IsA("Model") then
				local c = center(sub)
				if c and outside(c) then
					stash(sub, holder(proot, region))
					moved += 1
				end
			else
				for _, item in sub:GetChildren() do
					local c = center(item)
					if c and outside(c) then
						stash(item, holder(proot, region, sub.Name))
						moved += 1
					end
				end
			end
		end
		say("%s: 땅 판 자름 %d · 옮김 %d, 물건 옮김 %d", region, clipped, movedLand, moved)
	end
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/plainsshrink", table.concat(lines, "\n"))
