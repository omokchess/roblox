-- 섬 이동을 받아 처리한다. 자리는 요청받은 이름으로 그때그때 잰다
local RS = game:GetService("ReplicatedStorage")
local remote = RS:WaitForChild("TeleportRequest")
local World = workspace.Surface.World
local COOL = 1
local last = {}

-- 섬의 땅 폴더들: 옛 타일(Surface.World.G_<섬>)이 남아 있으면 그것, 비었거나 없으면 새 지형(Surface.R_<섬>…, 2026-10-04 평원·사막 교체)
local function islandFolders(islandName)
	local g = World:FindFirstChild("G_" .. islandName)
	if g and #g:GetChildren() > 0 then
		return { g }, { g }
	end
	local list, lands = {}, {}
	local head = "R_" .. islandName
	for _, f in ipairs(workspace.Surface:GetChildren()) do
		if f.Name:sub(1, #head) == head then
			table.insert(list, f)
			local land = f:FindFirstChild("Land")
			if land then
				table.insert(lands, land)
			end
		end
	end
	return list, (if #lands > 0 then lands else list)
end

local function arrival(islandName)
	local folders, centerFrom = islandFolders(islandName)
	if #folders == 0 then
		return nil
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

remote.OnServerEvent:Connect(function(plr, name)
	-- 클라이언트가 준 것은 이름뿐이다. 좌표는 서버가 정한다
	if type(name) ~= "string" or #name > 24 then
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
	local pos = arrival(name)
	if not pos then
		return
	end
	last[plr] = now
	ch:PivotTo(CFrame.new(pos))
end)

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	last[plr] = nil
end)
