--!nocheck
--[[
	Player_Setup.luau — 플레이어 쪽을 한 번에 깐다.

	넣는 것 셋.
	  1. 스폰 자리. 지금은 허공에서 시작한다. 평원 섬 땅을 실측해서 발판을 놓는다
	  2. 달리기. 왼쪽 Shift 를 누르고 있는 동안만 빨라진다
	  3. 섬 이동. M 을 누르면 섬 목록이 열리고 고른 섬으로 옮겨 준다

	**자리는 박아 넣지 않고 잴 때마다 구한다.** 맵을 1/3 로 줄인 적이 있고
	앞으로도 줄일 수 있다. 좌표를 적어 두면 그때마다 어긋난다.
	그래서 섬마다 G_<섬> 지면 조각의 무게중심을 구하고, 거기서 나선으로
	돌며 광선을 쏴서 물이 아니고 건물 속도 아닌 첫 자리를 쓴다.

	옮기는 일은 서버가 한다. 클라이언트가 좌표를 정해 제 몸을 옮기면
	나중에 검증을 붙일 자리가 없다.

	되돌리기: Workspace 의 PlayerSpawn, ServerScriptService 의 PlayerService,
	StarterPlayerScripts 의 PlayerClient, ReplicatedStorage 의 TeleportRequest 를 지운다
]]

local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local WALK, RUN = 16, 30
local SPAWN_ISLAND = "평원" -- 절화가 있는 섬. 여기서 시작한다

--=== 섬 자리 재기. 스폰 발판을 놓을 때도 같은 규칙을 쓴다 ===--
local World = workspace.Surface.World

local function arrival(islandName)
	local g = World:FindFirstChild("G_" .. islandName)
	if not g then
		return nil
	end
	local sx, sz, cnt = 0, 0, 0
	for _, p in ipairs(g:GetChildren()) do
		if p:IsA("BasePart") then
			sx, sz, cnt = sx + p.Position.X, sz + p.Position.Z, cnt + 1
		end
	end
	if cnt == 0 then
		return nil
	end
	local cx, cz = sx / cnt, sz / cnt

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { g }

	-- 무게중심이 만이나 바다일 수 있다. 황금각 나선으로 돌며 첫 뭍을 찾는다
	for i = 0, 120 do
		local a = i * 2.399963
		local r = i * 14
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local hit = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0), rp)
		if hit then
			-- 건물 속이면 비켜 간다. 지면만 빼고 뭐든 걸치면 다음 자리를 본다
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { g, workspace:FindFirstChild("PlayerSpawn") }
			op.MaxParts = 1
			local head = CFrame.new(x, hit.Position.Y + 6, z)
			if #workspace:GetPartBoundsInBox(head, Vector3.new(8, 10, 8), op) == 0 then
				return Vector3.new(x, hit.Position.Y + 4, z)
			end
		end
	end
	return nil
end

--=== 1. 스폰 발판 ===--
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") then
		d:Destroy()
	end
end

local sp = arrival(SPAWN_ISLAND)
assert(sp, SPAWN_ISLAND .. " 섬에서 설 자리를 못 찾았다")

local pad = Instance.new("SpawnLocation")
pad.Name = "PlayerSpawn"
pad.Size = Vector3.new(14, 1, 14)
pad.Anchored = true
pad.CanCollide = true
pad.Position = sp + Vector3.new(0, -1.5, 0)
pad.Color = Color3.fromRGB(196, 186, 166)
pad.Material = Enum.Material.Marble
pad.TopSurface = Enum.SurfaceType.Smooth
pad.Neutral = true
pad.AllowTeamChangeOnTouch = false
pad.Duration = 0
pad.Parent = workspace

--=== 오갈 통로 ===--
local old = RS:FindFirstChild("TeleportRequest")
if old then
	old:Destroy()
end
local remote = Instance.new("RemoteEvent")
remote.Name = "TeleportRequest"
remote.Parent = RS

--=== 2, 3. 서버 쪽 ===--
local serverSrc = [==[
-- 섬 이동을 받아 처리한다. 자리는 요청받은 이름으로 그때그때 잰다
local RS = game:GetService("ReplicatedStorage")
local remote = RS:WaitForChild("TeleportRequest")
local World = workspace.Surface.World
local COOL = 1
local last = {}

local function arrival(islandName)
	local g = World:FindFirstChild("G_" .. islandName)
	if not g then
		return nil
	end
	local sx, sz, cnt = 0, 0, 0
	for _, p in ipairs(g:GetChildren()) do
		if p:IsA("BasePart") then
			sx, sz, cnt = sx + p.Position.X, sz + p.Position.Z, cnt + 1
		end
	end
	if cnt == 0 then
		return nil
	end
	local cx, cz = sx / cnt, sz / cnt
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { g }
	for i = 0, 120 do
		local a = i * 2.399963
		local r = i * 14
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local hit = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0), rp)
		if hit then
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { g }
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
]==]

local oldS = SSS:FindFirstChild("PlayerService")
if oldS then
	oldS:Destroy()
end
local sv = Instance.new("Script")
sv.Name = "PlayerService"
sv.Source = serverSrc
sv.Parent = SSS

--=== 클라이언트 쪽. 달리기와 섬 목록 ===--
local clientSrc = ([==[
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local WALK, RUN = %d, %d
local plr = Players.LocalPlayer
local remote = RS:WaitForChild("TeleportRequest")

local function hum()
	local c = plr.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

--=== 달리기 ===--
local function setSpeed(v)
	local h = hum()
	if h then
		h.WalkSpeed = v
	end
end

plr.CharacterAdded:Connect(function(c)
	local h = c:WaitForChild("Humanoid")
	h.WalkSpeed = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and RUN or WALK
end)
if hum() then
	setSpeed(WALK)
end

--=== 섬 목록 ===--
-- 섬 이름은 지면 폴더에서 읽는다. 적어 두면 섬을 늘릴 때마다 손봐야 한다
local ORDER = { "평원", "숲", "늪지대", "탑의성역", "사막", "오염지대", "설원", "화산", "광산" }

local function islands()
	local have, out = {}, {}
	for _, g in ipairs(workspace.Surface.World:GetChildren()) do
		local nm = g.Name:match("^G_(.+)$")
		if nm then
			have[nm] = true
		end
	end
	for _, nm in ipairs(ORDER) do
		if have[nm] then
			out[#out + 1] = nm
			have[nm] = nil
		end
	end
	for nm in pairs(have) do
		out[#out + 1] = nm
	end
	return out
end

local gui = Instance.new("ScreenGui")
gui.Name = "IslandMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = plr:WaitForChild("PlayerGui")

local open = Instance.new("TextButton")
open.Size = UDim2.new(0, 130, 0, 34)
-- 프로젝트의 전투 버튼이 왼쪽 아래를 쓰므로 오른쪽 아래에 붙인다
open.AnchorPoint = Vector2.new(1, 1)
open.Position = UDim2.new(1, -16, 1, -16)
open.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
open.BackgroundTransparency = 0.15
open.BorderSizePixel = 0
open.Text = "섬 이동  (M)"
open.TextColor3 = Color3.fromRGB(236, 232, 224)
open.Font = Enum.Font.GothamMedium
open.TextSize = 15
open.Parent = gui
Instance.new("UICorner").Parent = open

local rows = #islands()
local panelH = math.min(40 + rows * 30, 320)
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 180, 0, panelH)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -16, 1, -58)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "어느 섬으로"
title.TextColor3 = Color3.fromRGB(176, 172, 164)
title.Font = Enum.Font.GothamMedium
title.TextSize = 14
title.Parent = panel

-- 섬이 늘어나도 되게 스크롤되는 목록으로 둔다
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -42)
list.Position = UDim2.new(0, 8, 0, 36)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new(0, 0, 0, rows * 30)
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

for _, nm in ipairs(islands()) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
	b.BorderSizePixel = 0
	b.Text = nm
	b.TextColor3 = Color3.fromRGB(236, 232, 224)
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.Parent = list
	Instance.new("UICorner").Parent = b
	b.MouseButton1Click:Connect(function()
		remote:FireServer(nm)
		panel.Visible = false
	end)
end

local function toggle()
	panel.Visible = not panel.Visible
end
open.MouseButton1Click:Connect(toggle)

UIS.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(RUN)
	elseif input.KeyCode == Enum.KeyCode.M then
		toggle()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(WALK)
	end
end)
]==]):format(WALK, RUN)

local oldC = SP:FindFirstChild("PlayerClient")
if oldC then
	oldC:Destroy()
end
local cl = Instance.new("LocalScript")
cl.Name = "PlayerClient"
cl.Source = clientSrc
cl.Parent = SP

--=== 자기검사 ===--
-- 스폰 발판이 물 위가 아니고 평원 땅에 닿아 있는지 본다
local g = World:FindFirstChild("G_" .. SPAWN_ISLAND)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { g }
local under = workspace:Raycast(pad.Position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rp)
assert(under, "스폰 발판 아래에 " .. SPAWN_ISLAND .. " 땅이 없다")
local drop = pad.Position.Y - under.Position.Y
assert(drop < 8, string.format("스폰 발판이 땅에서 %.1f 떠 있다", drop))

-- 섬마다 설 자리를 찾을 수 있는지 미리 다 재 본다
local ok, bad = {}, {}
for _, gg in ipairs(World:GetChildren()) do
	local nm = gg.Name:match("^G_(.+)$")
	if nm then
		if arrival(nm) then
			ok[#ok + 1] = nm
		else
			bad[#bad + 1] = nm
		end
	end
end

print(string.format("[Player] 스폰 %s (%.0f, %.0f, %.0f) / 땅에서 %.1f",
	SPAWN_ISLAND, pad.Position.X, pad.Position.Y, pad.Position.Z, drop))
print(string.format("[Player] 걷기 %d 달리기 %d / 이동 가능한 섬 %d곳: %s", WALK, RUN, #ok, table.concat(ok, " ")))
assert(#bad == 0, "설 자리를 못 찾은 섬: " .. table.concat(bad, " "))
print("[Player] 스폰 발판, 달리기, 섬 이동 다 걸었다")
