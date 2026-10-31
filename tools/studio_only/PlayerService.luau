-- 섬·명소 이동을 받아 처리한다. 자리는 요청받은 이름으로 그때그때 잰다(Studio 전용 ServerScriptService.PlayerService — 사본 tools/studio_only)
-- 2026-10-31 사용자: "재구성한 맵들에도 M 키로 순간이동" → 섬 땅 폴더를 옛 타일(Surface.World.G_<섬>)뿐 아니라 재구성한 지형
-- (Surface.R_<섬>… · Swamp2_늪지대 · Ruins2_탑의성역 · Roman_칼로도르 …)에서도 찾고, 재구성판이 있으면 그쪽에 내린다.
-- 명소 = CollectionService 태그 "TeleportSpot" 이 붙은 표지 파트(속성 SpotName · Region) — 요청 "spot:<지역>/<이름>"(다른 지역에 같은 이름이 있어도 되게). 짓기 스크립트가 표지를 놓는다.
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local remote = RS:WaitForChild("TeleportRequest")
local World = workspace.Surface.World
local COOL = 1
local last = {}

-- 지역 이름(목록 순서). 폴더 이름이 이 이름으로 시작하면 그 지역(R_평원북 → 평원, R_설원3_지하 → 설원)
local KNOWN = { "평원", "숲", "하이우드", "늪지대", "탑의성역", "사막", "오염지대", "설원", "화산", "칼로도르", "광산" }

local function islandOf(folderName)
	local rest = folderName:match("^R_(.+)$") or folderName:match("^%a+%d*_(.+)$")
	if not rest or rest == "" then
		return nil
	end
	for _, k in ipairs(KNOWN) do
		if rest:sub(1, #k) == k then
			return k
		end
	end
	return (rest:gsub("%d+.*$", ""))
end

-- 섬의 땅 폴더들(내릴 땅 찾기) + 한가운데를 잴 폴더들. 한가운데는 재구성한 지형(있으면 그 Land)으로 재고, 없으면 옛 타일.
-- 내릴 땅은 둘 다 — 재구성판이 옛 타일 위에 얹힌 곳(탑의 성역 등)에서 폐허 벽 꼭대기에 내리지 않게. 지하 폴더는 뺀다
local function islandFolders(islandName)
	local list, lands = {}, {}
	for _, f in ipairs(workspace.Surface:GetChildren()) do
		if f ~= World and islandOf(f.Name) == islandName and not f.Name:find("지하") then
			table.insert(list, f)
			local land = f:FindFirstChild("Land")
			if land then
				table.insert(lands, land)
			end
		end
	end
	local center = if #lands > 0 then lands else table.clone(list)
	local g = World:FindFirstChild("G_" .. islandName)
	if g and #g:GetChildren() > 0 then
		table.insert(list, g)
		if #center == 0 then
			center = { g }
		end
	end
	return list, center
end

local function arrival(islandName)
	local folders, centerFrom = islandFolders(islandName)
	if #folders == 0 then
		return nil
	end
	-- 짓기 스크립트가 "Arrival" 표지를 두었으면 거기(명소 표지와 같은 태그, 속성 Arrival = true)
	for _, p in ipairs(CS:GetTagged("TeleportSpot")) do
		if p:IsA("BasePart") and p:GetAttribute("Region") == islandName and p:GetAttribute("Arrival") then
			return p.Position + Vector3.new(0, 4, 0)
		end
	end
	local sx, sz, cnt = 0, 0, 0
	for _, f in ipairs(centerFrom) do
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") then
				sx, sz, cnt = sx + p.Position.X, sz + p.Position.Z, cnt + 1
			end
		end
	end
	if cnt == 0 then
		return nil
	end
	local cx, cz = sx / cnt, sz / cnt
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = folders
	for i = 0, 160 do
		local a = i * 2.399963
		local r = i * 14
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local hit = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0), rp)
		if hit then
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { hit.Instance }
			op.MaxParts = 1
			if #workspace:GetPartBoundsInBox(CFrame.new(x, hit.Position.Y + 6, z), Vector3.new(8, 10, 8), op) == 0 then
				return Vector3.new(x, hit.Position.Y + 5, z)
			end
		end
	end
	return nil
end

local function spot(region, name)
	for _, p in ipairs(CS:GetTagged("TeleportSpot")) do
		if p:IsA("BasePart") and p:GetAttribute("Region") == region and p:GetAttribute("SpotName") == name then
			return p.Position + Vector3.new(0, 4, 0), p
		end
	end
	return nil
end

remote.OnServerEvent:Connect(function(plr, name)
	-- 클라이언트가 준 것은 이름뿐이다. 좌표는 서버가 정한다
	if type(name) ~= "string" or #name > 80 then
		return
	end
	local now = os.clock()
	if last[plr] and now - last[plr] < COOL then
		return
	end
	local ch = plr.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local pos, marker
	local region, spotName = name:match("^spot:([^/]+)/(.+)$")
	if spotName then
		pos, marker = spot(region, spotName)
	else
		pos = arrival(name)
	end
	if not pos then
		return
	end
	last[plr] = now
	-- 명소 표지가 바라보는 쪽(LookVector)을 보고 선다
	local look = marker and marker.CFrame.LookVector or Vector3.new(0, 0, -1)
	ch:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)))
end)

-- 창에 띄울 목록을 TeleportRequest 의 속성 "Menu"(JSON)로 알린다: { {Name, Center, Spots = {이름…}} } (KNOWN 순서, 명소는 Order 속성 → 이름 순)
local HttpService = game:GetService("HttpService")
local function publish()
	local regions, byName = {}, {}
	local function region(nm)
		if not byName[nm] then
			byName[nm] = { Name = nm, Center = #islandFolders(nm) > 0, Spots = {} }
			table.insert(regions, byName[nm])
		end
		return byName[nm]
	end
	for _, f in ipairs(workspace.Surface:GetChildren()) do
		local nm = f ~= World and islandOf(f.Name)
		if nm then
			region(nm)
		end
	end
	for _, g in ipairs(World:GetChildren()) do
		local nm = g.Name:match("^G_(.+)$")
		if nm and #g:GetChildren() > 0 then
			region(nm)
		end
	end
	local spots = {}
	for _, p in ipairs(CS:GetTagged("TeleportSpot")) do
		if p:IsA("BasePart") and p:GetAttribute("SpotName") and p:GetAttribute("Region") and not p:GetAttribute("Arrival") then
			table.insert(spots, p)
		end
	end
	table.sort(spots, function(a, b)
		local oa, ob = a:GetAttribute("Order") or 999, b:GetAttribute("Order") or 999
		if oa ~= ob then
			return oa < ob
		end
		return a:GetAttribute("SpotName") < b:GetAttribute("SpotName")
	end)
	for _, p in ipairs(spots) do
		table.insert(region(p:GetAttribute("Region")).Spots, p:GetAttribute("SpotName"))
	end
	local rank = {}
	for i, k in ipairs(KNOWN) do
		rank[k] = i
	end
	table.sort(regions, function(a, b)
		local ra, rb = rank[a.Name] or 99, rank[b.Name] or 99
		if ra ~= rb then
			return ra < rb
		end
		return a.Name < b.Name
	end)
	remote:SetAttribute("Menu", HttpService:JSONEncode(regions))
end

-- 짓기 스크립트가 폴더·표지를 바꾸면 1초 뒤 한 번 다시 알린다
local pending = false
local function soon()
	if pending then
		return
	end
	pending = true
	task.delay(1, function()
		pending = false
		publish()
	end)
end
CS:GetInstanceAddedSignal("TeleportSpot"):Connect(soon)
CS:GetInstanceRemovedSignal("TeleportSpot"):Connect(soon)
workspace.Surface.ChildAdded:Connect(soon)
workspace.Surface.ChildRemoved:Connect(soon)
publish()

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	last[plr] = nil
end)
