--!nocheck
--[[
	Plains_GroupSettle.luau — 2026-10-03. 평원 평탄화 뒤 "한 덩어리" 물건 높이를 다시 맞춘다(편집 모드, StudioJobs).

	Plains_Reseat 는 물건마다 제 밑 옛 타일 높이로 따로 옮겼다. 그래서
	  - 정전 마당(행각·중문·정전·박석·품계석), 바깥마당 박석과 금천, 연못(둘레돌·물·누각·섬·다리)처럼 서로 붙어야 하는 것들이 0.3~0.8 씩 엇갈렸고
	  - 건물 안살림(안살림/<틀>_<동네>_<번호>/소품)도 건물과 따로 움직여 마루에서 뜨거나 묻혔다.
	고치는 법:
	  1. 덩어리(아래 GROUPS 상자 — 손으로 잰 자리) 안 물건은 ReseatDelta 를 되돌려(처음 지은 높이, 서로 맞음) 덩어리마다 같은 D 만큼 옮긴다
	     (담·문·나무·안살림은 빼고 — 담·문은 Plains_WallSettle, 안살림은 2)
	  2. 안살림 소품은 제 건물(같은 동네 폴더의 같은 틀, 가장 가까운 것)과 같은 ReseatDelta 가 되게 옮긴다
	ReseatDelta 는 늘 "처음 지은 높이에서 옮긴 만큼"으로 남긴다. 다시 돌려도 된다. DRY = true 면 옮기지 않고 보고만. 보고: /groupsettle
	돌리는 순서: Plains_Build → Plains_Reseat → Plains_RoadFix → Plains_WallSettle → Plains_GroupSettle
]]
local DRY = false
local HS = game:GetService("HttpService")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

-- { 이름, x0, x1, z0, z1, D } — jeolhwa_plan.py 표와 스튜디오에서 잰 자리
local GROUPS = {
	{ "정전마당", 128, 322, 698, 884, 0 }, -- 행각 고리 안팎(박석 윗면 = 행각 밑 3.03, 땅보다 1.1 높은 단)
	{ "바깥마당", 25, 425, 631, 700, -0.35 }, -- 박석 윗면 2.60 → 2.25(땅 위 0.35, 정문 문지방과 맞춤). 금천·금천 다리 같이
	{ "경회루", 28, 124, 795, 930, 0 },
	{ "후원", 336, 418, 836, 928, 0 },
	{ "서촌못", -100, -38, 522, 572, 0 },
}

local function skipKind(u: Instance): boolean
	local n = u.Name
	return n:match("^Wall_") ~= nil or n:match("^Fence_") ~= nil or n:match("^Tree") ~= nil
		or (n:match("^Gate_") ~= nil and not u:IsDescendantOf(workspace.Jeolhwa["궁"]["정전"]))
end

local function shift(u: Instance, dy: number)
	if DRY then
		return
	end
	if u:IsA("Model") then
		u:PivotTo(u:GetPivot() + Vector3.new(0, dy, 0))
	else
		u.CFrame += Vector3.new(0, dy, 0)
	end
end
local function setDelta(u: Instance, target: number): number
	local cur = u:GetAttribute("ReseatDelta") or 0
	local dy = target - cur
	if math.abs(dy) > 0.005 then
		shift(u, dy)
		if not DRY then
			u:SetAttribute("ReseatDelta", if math.abs(target) > 0.005 then target else nil)
		end
	end
	return dy
end
local function center(u: Instance): Vector3
	if u:IsA("Model") then
		return u:GetBoundingBox().Position
	end
	return u.Position
end

local ok, err = pcall(function()
	local J = workspace.Jeolhwa
	local inside = J["안살림"]
	-- 1. 덩어리
	for _, g in GROUPS do
		local n, names = 0, {}
		for _, u in J:GetDescendants() do
			if (u:IsA("Model") or u:IsA("BasePart")) and u.Parent:IsA("Folder") and not u:IsDescendantOf(inside)
				and not u:IsDescendantOf(J["나무"]) and not skipKind(u) then
				local c = center(u)
				if c.X >= g[2] and c.X <= g[3] and c.Z >= g[4] and c.Z <= g[5] then
					local dy = setDelta(u, g[6])
					if math.abs(dy) > 0.005 then
						n += 1
					end
					local key = u.Parent.Name .. "/" .. u.Name:gsub("_[%-%d]+", "")
					names[key] = (names[key] or 0) + 1
				end
			end
		end
		local list = {}
		for k, v in names do
			table.insert(list, k .. "×" .. v)
		end
		table.sort(list)
		say("%s: 옮김 %d — %s", g[1], n, table.concat(list, ", "))
	end

	-- 2. 안살림 → 제 건물
	local found, lost, movedProps = 0, {}, 0
	for _, grp in inside:GetChildren() do
		local kind, district = grp.Name:match("^(.-)_([^_]+)_%d+$")
		local folder = district and J:FindFirstChild(district, true)
		local props = grp:GetChildren()
		if not (folder and #props > 0) then
			table.insert(lost, grp.Name)
			continue
		end
		local sum, cnt = Vector3.zero, 0
		for _, p in props do
			if p:IsA("Model") or p:IsA("BasePart") then
				sum += center(p)
				cnt += 1
			end
		end
		local mid = sum / math.max(cnt, 1)
		local best, bd = nil, 60
		for _, b in folder:GetDescendants() do
			if b:IsA("Model") and b.Name == kind then
				local d = (Vector3.new(b:GetPivot().X, 0, b:GetPivot().Z) - Vector3.new(mid.X, 0, mid.Z)).Magnitude
				if d < bd then
					best, bd = b, d
				end
			end
		end
		if not best then
			table.insert(lost, grp.Name)
			continue
		end
		found += 1
		local target = best:GetAttribute("ReseatDelta") or 0
		for _, p in props do
			if p:IsA("Model") or p:IsA("BasePart") then
				if math.abs(setDelta(p, target)) > 0.005 then
					movedProps += 1
				end
			end
		end
	end
	say("안살림: 건물 찾음 %d · 소품 옮김 %d · 못 찾음 %d %s", found, movedProps, #lost, table.concat(lost, ", "))
end)
HS:PostAsync("http://127.0.0.1:34999/groupsettle", (if DRY then "[DRY] " else "") .. tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
