--!nocheck
--[[
	Snow_City.luau — 설원 섬에 슈네라이히 도시를 세운다. (2026-09-26)

	슈네라이히는 극한의 추위를 사람의 감정을 열기로 바꾸는 기술로 버티는 기술 국가다.
	서쪽 고원 한가운데 감정 변환로가 서고, 집들은 그 열원을 두 겹 고리로 둘러싼다.
	동서 대로가 동문과 차펜 공방을 잇고, 난방관이 변환로에서 방사로 뻗는다.
	동쪽 고원에는 차펜 공방이 불태운 옛 설 공방이 폐허로 남았다.

	**배치는 tools/snow_plan.py 표에 손으로 적었다.** 그 파일이 겹침을 검사하고
	Snow_City_data.luau 를 뽑는다. 붙여 넣는 파일은 --@@DATA@@ 에 그 표를, --@@SCRIPT@@ 에
	SnowInteriors.server.luau 를 끼운 Snow_City_run.luau 다.

	기능 건물 넷(프로스티히 공방, 차펜 공방, 설 공방, 기물군 본부)은 문 앞에서 상호작용하면
	멀리 떨어진 안쪽 방으로 순간이동한다. 방은 여기서 부품 하나하나 손으로 짓는다.
	순간이동은 ServerScriptService.SnowInteriors 가 맡고, 이 스크립트가 그것도 넣는다.

	틀은 ServerStorage.SnowKit (Snow_Kit.luau). 다시 돌리면 Workspace.Schneereich 만 새로 짓는다.
	도시 자리에 걸린 설원 지물(나무 제외)은 ServerStorage.Snow_Cleared 로 옮기고, 다시 돌리면 먼저 되돌린다.
]]
-- snow_plan.py 가 적은 표. 손으로 고치지 말고 snow_plan.py 를 고쳐 다시 뽑는다
local D = {}
D.BUILD = {
	{"Herzofen", -4440, -2670, 0, "광장", ""},
	{"Zapfen_Werk", -4706, -2670, -90, "차펜공방", "zapfen"},
	{"Figuren_HQ", -4290, -2745, 180, "기물군본부", "figuren"},
	{"Frostig_Werk", -4290, -2627, 0, "프로스티히공방", "frostig"},
	{"City_Gate", -4112, -2670, -90, "동문", ""},
	{"Mooring_Mast", -4172, -2795, 180, "계류탑", ""},
	{"Big_Gear", -4440, -2792, 180, "북쪽전망", ""},
	{"Big_Gear", -4452, -2548, 12, "남쪽전망", ""},
	{"Steam_House_A", -4502.1, -2697.7, 246, "안고리", ""},
	{"Steam_House_B", -4484.4, -2722.9, 220, "안고리", ""},
	{"Steam_House_C", -4456.2, -2735, 194, "안고리", ""},
	{"Steam_House_A", -4423.5, -2736, 169, "안고리", ""},
	{"Steam_House_B", -4395.6, -2722.9, 140, "안고리", ""},
	{"Steam_House_C", -4377.9, -2695.1, 112, "안고리", ""},
	{"Steam_House_A", -4378.9, -2640.2, 64, "안고리", ""},
	{"Steam_House_B", -4395.6, -2617.1, 40, "안고리", ""},
	{"Steam_House_C", -4423.8, -2605, 11, "안고리", ""},
	{"Steam_House_A", -4456.5, -2604, -14, "안고리", ""},
	{"Steam_House_B", -4484.4, -2617.1, -40, "안고리", ""},
	{"Steam_House_C", -4501.2, -2642.7, -66, "안고리", ""},
	{"Steam_House_C", -4538.7, -2705.9, 250, "바깥고리", ""},
	{"Steam_House_A", -4519.7, -2736.8, 230, "바깥고리", ""},
	{"Steam_House_B", -4489.8, -2763.6, 208, "바깥고리", ""},
	{"Steam_House_B", -4390.2, -2763.6, 152, "바깥고리", ""},
	{"Steam_House_A", -4360.3, -2736.8, 130, "바깥고리", ""},
	{"Steam_House_C", -4341.3, -2705.9, 110, "바깥고리", ""},
	{"Steam_House_A", -4342.3, -2634.4, 70, "바깥고리", ""},
	{"Steam_House_C", -4359.6, -2602.5, 50, "바깥고리", ""},
	{"Steam_House_B", -4390.2, -2576.4, 28, "바깥고리", ""},
	{"Steam_House_A", -4488.8, -2578.2, -28, "바깥고리", ""},
	{"Steam_House_B", -4521.2, -2601.9, -50, "바깥고리", ""},
	{"Steam_House_C", -4538.7, -2634.1, -70, "바깥고리", ""},
	{"Steam_House_A", -4585, -2695, 180, "서대로", ""},
	{"Steam_House_C", -4618, -2696, 184, "서대로", ""},
	{"Boiler_Tank", -4648, -2700, 0, "서대로", ""},
	{"Steam_House_C", -4583, -2645, 0, "서대로", ""},
	{"Steam_House_B", -4623, -2644, 0, "서대로", ""},
	{"Steam_House_A", -4205, -2696, 180, "동대로", ""},
	{"Steam_House_C", -4172, -2698, 176, "동대로", ""},
	{"Steam_House_B", -4240, -2645, 0, "동대로", ""},
	{"Steam_House_A", -4200, -2644, 2, "동대로", ""},
	{"Steam_House_C", -4168, -2645, -3, "동대로", ""},
	{"Boiler_Tank", -4332, -2580, 0, "동대로", ""},
	{"Sel_Werk_Ruin", -3050, -2625, 90, "설공방", "sel"},
	{"Boiler_Tank", -3030, -2662, 0, "설공방", ""},
	{"Big_Gear", -3085, -2590, 35, "설공방", ""},
}
D.LAMPS = {
	{-4473.1, -2684.1, 247},
	{-4453.5, -2703.4, 202},
	{-4425.9, -2703.1, 157},
	{-4406.6, -2683.5, 112},
	{-4406.6, -2656.5, 68},
	{-4425.9, -2636.9, 23},
	{-4453.5, -2636.6, -22},
	{-4473.1, -2655.9, -67},
	{-4150, -2657, 0},
	{-4185, -2657, 0},
	{-4225, -2657, 0},
	{-4265, -2657, 0},
	{-4305, -2657, 0},
	{-4345, -2657, 0},
	{-4380, -2657, 0},
	{-4500, -2657, 0},
	{-4540, -2657, 0},
	{-4565, -2657, 0},
	{-4605, -2657, 0},
	{-4650, -2657, 0},
	{-3960, -2673, 180},
	{-3800, -2675, 180},
	{-3640, -2685, 180},
	{-3480, -2663, 180},
	{-3320, -2643, 180},
	{-3160, -2639, 180},
}
D.ROADS = {
	{"안고리길", 10, "pave", {{-4484, -2670}, {-4482.5, -2681.4}, {-4478.1, -2692}, {-4471.1, -2701.1}, {-4462, -2708.1}, {-4451.4, -2712.5}, {-4440, -2714}, {-4428.6, -2712.5}, {-4418, -2708.1}, {-4408.9, -2701.1}, {-4401.9, -2692}, {-4397.5, -2681.4}, {-4396, -2670}, {-4397.5, -2658.6}, {-4401.9, -2648}, {-4408.9, -2638.9}, {-4418, -2631.9}, {-4428.6, -2627.5}, {-4440, -2626}, {-4451.4, -2627.5}, {-4462, -2631.9}, {-4471.1, -2638.9}, {-4478.1, -2648}, {-4482.5, -2658.6}, {-4484, -2670}}},
	{"바깥고리길북", 10, "pave", {{-4524.7, -2684.9}, {-4520.8, -2699.4}, {-4514.5, -2713}, {-4505.9, -2725.3}, {-4495.3, -2735.9}, {-4483, -2744.5}, {-4469.4, -2750.8}, {-4454.9, -2754.7}, {-4440, -2756}, {-4425.1, -2754.7}, {-4410.6, -2750.8}, {-4397, -2744.5}, {-4384.7, -2735.9}, {-4374.1, -2725.3}, {-4365.5, -2713}, {-4359.2, -2699.4}, {-4355.3, -2684.9}}},
	{"바깥고리길남", 10, "pave", {{-4355.3, -2655.1}, {-4359.2, -2640.6}, {-4365.5, -2627}, {-4374.1, -2614.7}, {-4384.7, -2604.1}, {-4397, -2595.5}, {-4410.6, -2589.2}, {-4425.1, -2585.3}, {-4440, -2584}, {-4454.9, -2585.3}, {-4469.4, -2589.2}, {-4483, -2595.5}, {-4495.3, -2604.1}, {-4505.9, -2614.7}, {-4514.5, -2627}, {-4520.8, -2640.6}, {-4524.7, -2655.1}}},
	{"동대로", 18, "pave", {{-4394, -2670}, {-4112, -2670}}},
	{"서대로", 18, "pave", {{-4486, -2670}, {-4684, -2670}}},
	{"북골목", 8, "pave", {{-4440, -2716}, {-4440, -2785}}},
	{"남골목", 8, "pave", {{-4440, -2624}, {-4440, -2556}}},
	{"띠길", 12, "ramp", {{-4100, -2670}, {-4040, -2667}, {-3960, -2662}, {-3880, -2660}, {-3800, -2664}, {-3720, -2672}, {-3640, -2676}, {-3560, -2668}, {-3480, -2652}, {-3400, -2640}, {-3320, -2632}, {-3240, -2627}, {-3160, -2626}, {-3072, -2628}}},
}
D.PAVES = {
	{"변환로광장", -4440, -2670, 39, "disc"},
	{"연병장", -4318, -2717, -4262, -2682, "chess"},
	{"탄마당", -3085, -2665, -3015, -2590, "soot"},
}
D.PIPES = {
	{"동관", {{-4418, -2680}, {-4150, -2680}}},
	{"서관", {{-4462, -2680}, {-4680, -2680}}},
	{"북관", {{-4446, -2692}, {-4446, -2780}}},
	{"남관", {{-4434, -2648}, {-4434, -2560}}},
	{"고리관북", {{-4520.4, -2680}, {-4519.8, -2684.1}, {-4518.2, -2691}, {-4516.1, -2697.7}, {-4513.4, -2704.2}, {-4510.1, -2710.5}, {-4506.4, -2716.5}, {-4502, -2722.1}, {-4497.3, -2727.3}, {-4492.1, -2732}, {-4486.5, -2736.4}, {-4480.5, -2740.1}, {-4474.2, -2743.4}, {-4467.7, -2746.1}, {-4461, -2748.2}, {-4454.1, -2749.8}, {-4447.1, -2750.7}, {-4440, -2751}, {-4432.9, -2750.7}, {-4425.9, -2749.8}, {-4419, -2748.2}, {-4412.3, -2746.1}, {-4405.8, -2743.4}, {-4399.5, -2740.1}, {-4393.5, -2736.4}, {-4387.9, -2732}, {-4382.7, -2727.3}, {-4378, -2722.1}, {-4373.6, -2716.5}, {-4369.9, -2710.5}, {-4366.6, -2704.2}, {-4363.9, -2697.7}, {-4361.8, -2691}, {-4360.2, -2684.1}, {-4359.6, -2680}}},
	{"고리관남", {{-4360.2, -2655.9}, {-4361.8, -2649}, {-4363.9, -2642.3}, {-4366.6, -2635.8}, {-4369.9, -2629.5}, {-4373.6, -2623.5}, {-4378, -2617.9}, {-4382.7, -2612.7}, {-4387.9, -2608}, {-4393.5, -2603.6}, {-4399.5, -2599.9}, {-4405.8, -2596.6}, {-4412.3, -2593.9}, {-4419, -2591.8}, {-4425.9, -2590.2}, {-4432.9, -2589.3}, {-4440, -2589}, {-4447.1, -2589.3}, {-4454.1, -2590.2}, {-4461, -2591.8}, {-4467.7, -2593.9}, {-4474.2, -2596.6}, {-4480.5, -2599.9}, {-4486.5, -2603.6}, {-4492.1, -2608}, {-4497.3, -2612.7}, {-4502, -2617.9}, {-4506.4, -2623.5}, {-4510.1, -2629.5}, {-4513.4, -2635.8}, {-4516.1, -2642.3}, {-4518.2, -2649}, {-4519.8, -2655.9}}},
}
D.VENTS = {
	{-4410, -2640},
	{-4470, -2700},
	{-4600, -2672},
	{-4250, -2672},
	{-4379.2, -2730.8},
	{-4499.7, -2608.1},
}
D.MANHOLES = {
	{-4200, -2671},
	{-4360, -2667},
	{-4560, -2672},
	{-4650, -2668},
	{-4418, -2631.9},
	{-4462, -2708.1},
}
D.JUNCTIONS = {
	{-4446, -2750.75, {"고리관북", "북관"}},
	{-4434, -2589.25, {"고리관남", "남관"}},
	{-4359.6, -2680, {"고리관북", "동관"}},
	{-4520.4, -2680, {"고리관북", "서관"}},
}
D.CLEAR = {
	"Drift_-12700_-7900",
	"Spire_-13000_-8200",
}
D.DOORS = {
	frostig = {"Frostig", 6, -9, 3.4},
	zapfen = {"Zapfen", 0, -17, 12},
	sel = {"Sel", 6, -9, 3.4},
	figuren = {"Figuren", 0, -16, 5},
}
D.AIRSHIP = {-4172, -2757, 360, 25.4}

local SCRIPT_SOURCE = [==[--!strict
--[[
	SnowInteriors — 설원 슈네라이히 기능 건물의 문과 안쪽 방을 잇는다. (2026-09-26)

	맵에 딸린 스크립트다. Snow_City.luau 가 ServerScriptService.SnowInteriors 로 넣는다.
	(Rojo 가 관리하는 src/server 밖에 둔다. 맵과 함께 Studio 에만 있다)

	태그 셋으로 짝을 찾는다. 모두 속성 InteriorId 가 같은 것끼리 한 짝이다.
	  SnowDoor    건물 문 앞의 보이지 않는 판. ProximityPrompt 를 품고,
	              ReturnPos / ReturnLook 속성에 나올 때 설 자리와 볼 방향을 적어 둔다
	  SnowArrive  방 안에 들어섰을 때 설 자리. 판의 앞(LookVector)을 보고 선다
	  SnowExit    방 안 출입문. ProximityPrompt 를 품는다
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local COOLDOWN = 1.0 -- 문 앞에서 두 번 눌러 오가는 것을 막는다

local doors: { [string]: BasePart } = {}
local arrivals: { [string]: BasePart } = {}
local lastMove: { [Player]: number } = {}

local function move(player: Player, cf: CFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if lastMove[player] and now - lastMove[player] < COOLDOWN then
		return
	end
	lastMove[player] = now
	-- 스트리밍이 켜져 있다. 멀리 떨어진 방을 먼저 불러 두지 않으면 허공에 떨어진다
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	character:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function promptOf(part: Instance): ProximityPrompt?
	local p = part:FindFirstChildOfClass("ProximityPrompt")
	return p
end

local function wireDoor(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("InteriorId")
	if typeof(id) ~= "string" then
		return
	end
	doors[id] = part
	local prompt = promptOf(part)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local arrive = arrivals[id]
			if arrive then
				move(player, arrive.CFrame + Vector3.new(0, 3, 0))
			end
		end)
	end
end

local function wireArrive(part: Instance)
	local id = part:GetAttribute("InteriorId")
	if part:IsA("BasePart") and typeof(id) == "string" then
		arrivals[id] = part
	end
end

local function wireExit(part: Instance)
	local id = part:GetAttribute("InteriorId")
	local prompt = promptOf(part)
	if typeof(id) ~= "string" or not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local door = doors[id]
		if not door then
			return
		end
		local pos = door:GetAttribute("ReturnPos")
		local look = door:GetAttribute("ReturnLook")
		if typeof(pos) == "Vector3" and typeof(look) == "Vector3" then
			move(player, CFrame.lookAt(pos, pos + look))
		end
	end)
end

for tag, fn in { SnowDoor = wireDoor, SnowArrive = wireArrive, SnowExit = wireExit } do
	for _, inst in CollectionService:GetTagged(tag) do
		fn(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end

Players.PlayerRemoving:Connect(function(player)
	lastMove[player] = nil
end)
]==]
-- 도는 톱니. 클라이언트에서만 돈다(보기 전용). 태그 SnowGear 모델을 속성 Speed(도/초)대로
-- 서버 시간에 맞춰 돌려서 모든 사람에게 같은 각도로 보인다. 처음 각도는 서버 쪽 피벗에 들어 있다
local GEAR_SCRIPT = [==[
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local gears = {}
local function add(m)
	if m:IsA("Model") then
		gears[m] = { base = m:GetPivot(), speed = m:GetAttribute("Speed") or 0 }
	end
end
for _, m in CS:GetTagged("SnowGear") do
	add(m)
end
CS:GetInstanceAddedSignal("SnowGear"):Connect(add)
CS:GetInstanceRemovedSignal("SnowGear"):Connect(function(m)
	gears[m] = nil
end)
RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for m, g in gears do
		if m.Parent then
			m:PivotTo(g.base * CFrame.Angles(0, 0, math.rad((g.speed * t) % 360)))
		end
	end
end)
]==]

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
local C = {
	road = { RGB(112, 106, 98), M.Cobblestone },
	ramp = { RGB(92, 90, 88), M.Cobblestone },
	plaza = { RGB(104, 99, 94), M.Cobblestone },
	curb = { RGB(140, 139, 138), M.Concrete },
	found = { RGB(85, 86, 92), M.Slate },
	soot = { RGB(40, 38, 38), M.Slate },
	marble = { RGB(225, 225, 228), M.Marble },
	dark = { RGB(40, 40, 44), M.Slate },
	iron = { RGB(58, 60, 66), M.Metal },
	plate = { RGB(94, 98, 107), M.DiamondPlate },
	brass = { RGB(184, 145, 63), M.Metal },
	copper = { RGB(176, 106, 63), M.Metal },
}

local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("SnowKit"), "ServerStorage.SnowKit 이 없다. Snow_Kit.luau 를 먼저 돌려라")
	for _, e in ipairs(D.BUILD) do
		assert(kit:FindFirstChild(e[1]), e[1] .. " 틀이 없다")
	end
	assert(kit:FindFirstChild("Gas_Lamp") and kit:FindFirstChild("Airship"), "등이나 비행선 틀이 없다")

	local old = workspace:FindFirstChild("Schneereich")
	if old then
		old:Destroy()
	end
	local city = Instance.new("Folder")
	city.Name = "Schneereich"
	city:SetAttribute("Version", 1)
	city.Parent = workspace
	local function folder(path)
		local f = city
		for name in string.gmatch(path, "[^/]+") do
			local c = f:FindFirstChild(name)
			if not c then
				c = Instance.new("Folder")
				c.Name = name
				c.Parent = f
			end
			f = c
		end
		return f
	end
	local FStone = folder("돌")

	--==================================================================== 0. 설원 지물 비키기
	local Z = workspace.Surface["Zone_설원"]
	local cleared = SS:FindFirstChild("Snow_Cleared")
	if not cleared then
		cleared = Instance.new("Folder")
		cleared.Name = "Snow_Cleared"
		cleared.Parent = SS
	end
	for _, c in ipairs(cleared:GetChildren()) do
		local home = Z:FindFirstChild(c:GetAttribute("OriginalFolder") or "")
		if home then
			c.Parent = home
		end
	end
	local moved = 0
	for _, name in ipairs(D.CLEAR) do
		local hit = Z:FindFirstChild(name, true)
		assert(hit, "옮길 지물 " .. name .. " 이 없다")
		assert(hit.Parent.Name ~= "설림", "나무는 옮기지 않는다: " .. name)
		hit:SetAttribute("OriginalFolder", hit.Parent.Name)
		hit.Parent = cleared
		moved += 1
	end

	local G = workspace.Surface.World["G_설원"]
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local rpAll = RaycastParams.new()
	rpAll.FilterType = Enum.RaycastFilterType.Include
	rpAll.FilterDescendantsInstances = { G, FStone }
	local function groundY(x, z, rp)
		local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1800, 0), rp or rpAll)
		return h and h.Position.Y
	end

	local nParts = 0
	local function part(name, cf, size, col, parent, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = col[1]
		p.Material = col[2]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		nParts += 1
		return p
	end
	local function span(x0, z0, x1, z1, rp)
		local lo, hi = math.huge, -math.huge
		local nx, nz = math.max(2, math.ceil((x1 - x0) / 8)), math.max(2, math.ceil((z1 - z0) / 8))
		for i = 0, nx do
			for j = 0, nz do
				local gy = groundY(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz, rp)
				assert(gy, string.format("(%.0f,%.0f) 아래에 땅이 없다", x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return lo, hi
	end
	local function slab(name, x0, z0, x1, z1, top, col, parent)
		local lo = span(x0, z0, x1, z1, rpG)
		local bot = math.min(lo, top - 0.4) - 0.9
		return part(name, CFrame.new((x0 + x1) / 2, (top + bot) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, top - bot, z1 - z0), col, parent)
	end

	--==================================================================== 1. 포장
	for _, p in ipairs(D.PAVES) do
		local f = folder("돌/" .. p[1])
		if p[#p] == "disc" then
			local cx, cz, r = p[2], p[3], p[4]
			local lo, hi = span(cx - r, cz - r, cx + r, cz + r, rpG)
			local top, bot = hi + 0.3, lo - 0.9
			part("Plaza", CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(top - bot, 2 * r, 2 * r), C.plaza, f, Enum.PartType.Cylinder)
			part("Curb", CFrame.new(cx, top - 0.35, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.9, 2 * r + 1.6, 2 * r + 1.6), C.curb, f, Enum.PartType.Cylinder)
		else
			local x0, z0, x1, z1, kind = p[2], p[3], p[4], p[5], p[6]
			local _, hi = span(x0, z0, x1, z1, rpG)
			if kind == "chess" then
				-- 연병장. 7 칸 체스판. 기물군(디 피구렌)의 이름값이다
				local T = 7
				local i = 0
				for x = x0, x1 - T + 0.01, T do
					local j = 0
					for z = z0, z1 - T + 0.01, T do
						slab(string.format("Tile_%d_%d", i, j), x, z, x + T, z + T, hi + 0.35, ((i + j) % 2 == 0) and C.dark or C.marble, f)
						j += 1
					end
					i += 1
				end
				-- 판 둘레 놋쇠 테
				for _, e in ipairs({ { x0 - 0.5, z0 - 0.5, x1 + 0.5, z0 }, { x0 - 0.5, z1, x1 + 0.5, z1 + 0.5 },
					{ x0 - 0.5, z0, x0, z1 }, { x1, z0, x1 + 0.5, z1 } }) do
					slab("Rim", e[1], e[2], e[3], e[4], hi + 0.45, C.brass, f)
				end
			else
				slab("Soot", x0, z0, x1, z1, hi + 0.2, C.soot, f)
			end
		end
	end
	task.wait()

	--==================================================================== 2. 길
	local function floorPiece(name, cx, cz, len, width, yaw, col, parent)
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ -0.5, 0, 0.5 }) do
			for _, v in ipairs({ -0.5, 0.5 }) do
				local wp = cf:PointToWorldSpace(Vector3.new(len * u, 0, width * v))
				local gy = groundY(wp.X, wp.Z, rpG)
				assert(gy, string.format("%s 자리 (%.0f,%.0f) 에 땅이 없다", name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local top, bot = hi + 0.3, lo - 0.9
		return part(name, CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0), Vector3.new(len, top - bot, width), col, parent)
	end
	-- 경사 길. 한 조각 10 을 넘지 않게 끊고, 각 끝 높이는 그 자리 폭 다섯 점 가운데 가장 높은 땅 + 0.4.
	-- 두 끝 사이 가운데가 땅보다 낮으면 두 끝을 같이 올린다
	local function rampRoad(name, width, pts, parent)
		local function hAt(p, dir)
			local perp = Vector3.new(-dir.Z, 0, dir.X)
			local hi = -math.huge
			for _, s in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
				local q = p + perp * (width * s)
				local gy = assert(groundY(q.X, q.Z, rpG), name .. " 밑에 땅이 없다")
				hi = math.max(hi, gy)
			end
			return hi + 0.4
		end
		local k = 0
		for i = 1, #pts - 1 do
			local A = Vector3.new(pts[i][1], 0, pts[i][2])
			local B = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
			local dir = (B - A).Unit
			local L = (B - A).Magnitude
			local n = math.max(1, math.ceil(L / 10))
			for s = 0, n - 1 do
				local p0 = A + (B - A) * (s / n)
				local p1 = A + (B - A) * ((s + 1) / n)
				local h0, h1 = hAt(p0, dir), hAt(p1, dir)
				local hm = hAt((p0 + p1) / 2, dir)
				local lift = math.max(0, hm - (h0 + h1) / 2)
				h0, h1 = h0 + lift, h1 + lift
				local a, b = Vector3.new(p0.X, h0, p0.Z), Vector3.new(p1.X, h1, p1.Z)
				local cf = CFrame.lookAt((a + b) / 2, b)
				k += 1
				-- 윗면이 두 끝을 잇는 선에 오게 판 두께 반만큼 내린다. 아래로 두껍게 해 계단 틈을 가린다
				part(string.format("Ramp_%d", k), cf * CFrame.new(0, -1.6, 0), Vector3.new(width, 3.2, (b - a).Magnitude + 0.6), C.ramp, parent)
			end
		end
	end
	for _, r in ipairs(D.ROADS) do
		local name, width, kind, pts = r[1], r[2], r[3], r[4]
		local f = folder("길/" .. name)
		if kind == "ramp" then
			rampRoad(name, width, pts, f)
		else
			for i = 1, #pts - 1 do
				local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
				local n = math.max(1, math.ceil(len / 40))
				for k = 1, n do
					local t = (k - 0.5) / n
					local rp_ = floorPiece(string.format("Road_%d_%d", i, k), ax + (bx - ax) * t, az + (bz - az) * t, len / n + 1, width, yaw, C.road, f)
					if width >= 18 then
						-- 대로 연석. 길 가장자리를 밝은 돌로 한 줄 둘러 길이 고원 바위와 갈라 보이게 한다
						for _, sd in ipairs({ -1, 1 }) do
							part("Curb", rp_.CFrame * CFrame.new(0, rp_.Size.Y / 2 + 0.15, sd * (width / 2 - 0.45)), Vector3.new(rp_.Size.X, 0.3, 0.9), C.curb, f)
						end
					end
				end
				if i > 1 then
					local gy = groundY(ax, az, rpG)
					part("Joint_" .. i, CFrame.new(ax, gy + 0.28 - 0.6, az) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.2, width, width), C.road, f, Enum.PartType.Cylinder)
				end
			end
		end
	end
	task.wait()

	--==================================================================== 3. 건물
	local placed = {}
	local foundations, maxGap = 0, 0
	local function place(kind, x, z, yaw, parent)
		local m = kit[kind]:Clone()
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		local frame = m:GetPivot()
		local minY = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				if c.Y - e.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - e.X), math.max(x1, c.X + e.X)
					z0, z1 = math.min(z0, c.Z - e.Z), math.max(z1, c.Z + e.Z)
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s (%.0f,%.0f) 발자국 (%.0f,%.0f) 아래에 땅이 없다", kind, x, z, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - (frame.Y + minY), 0))
		if hi - lo > 0.25 then
			local f = Instance.new("Part")
			f.Name = "Foundation"
			f.Anchored = true
			f.Size = Vector3.new(x1 - x0 + 1.0, hi - lo + 1.0, z1 - z0 + 1.0)
			f.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))) * frame.Rotation
				+ Vector3.new(0, (lo - 1.0 + hi) / 2 - frame.Y, 0)
			f.Color = C.found[1]
			f.Material = C.found[2]
			f.TopSurface = Enum.SurfaceType.Smooth
			f.BottomSurface = Enum.SurfaceType.Smooth
			f.Parent = m
			foundations += 1
			maxGap = math.max(maxGap, hi - lo)
		end
		placed[#placed + 1] = { m = m, kind = kind }
		return m
	end

	local tagged = {}
	for i, e in ipairs(D.BUILD) do
		local m = place(e[1], e[2], e[3], e[4], folder(e[5]))
		m.Name = e[1]
		if e[6] ~= "" then
			tagged[e[6]] = m
		end
		if i % 6 == 0 then
			task.wait()
		end
	end
	for i, l in ipairs(D.LAMPS) do
		local m = place("Gas_Lamp", l[1], l[2], l[3], folder("가스등"))
		m.Name = "Gas_Lamp_" .. i
	end
	-- 비행선. 계류탑 팔 끝에 코를 대고 떠 있다. 땅에 앉히지 않는다
	do
		local mast
		for _, e in ipairs(placed) do
			if e.kind == "Mooring_Mast" then
				mast = e.m
			end
		end
		assert(mast, "계류탑이 없다")
		local a = D.AIRSHIP
		local ship = kit.Airship:Clone()
		ship:PivotTo(CFrame.new(a[1], mast:GetPivot().Y + a[4], a[2]) * CFrame.Angles(0, math.rad(a[3]), 0))
		ship.Name = "Airship"
		ship.Parent = folder("계류탑")
	end
	task.wait()

	--==================================================================== 3b. 도는 톱니와 시계 바늘
	-- 돌리는 일은 클라이언트 스크립트(맨 끝에서 넣는다)가 서버 시간에 맞춰 한다. 보기 전용이다.
	-- 여기서는 제자리와 처음 각도만 정한다. 톱니 틀 셋은 이 간격(1.96)이 같아 서로 맞물리고,
	-- 이는 톱니 로컬 +X 에서 360/이수 도마다 하나씩 있다. 맞물리는 둘은 같은 배율로 둔다.
	-- 구동 톱니는 상대 쪽으로 이 사이 홈을, 상대 톱니는 구동 쪽으로 이를 내밀게 처음 각도를 준다
	local CS = game:GetService("CollectionService")
	local TEETH = { Gear_24 = 24, Gear_16 = 16, Gear_10 = 10 }
	local function gearR(kind)
		return TEETH[kind] * 1.96 / (2 * math.pi)
	end
	-- 건물 틀마다 붙는 톱니 무리. 로컬 좌표는 건물 피벗 기준이고 판은 건물 앞(-Z)을 본다. ry 로 더 돌린다.
	-- { 구동 톱니, 배율, x, y, z, 초당 도, ry, { { 맞물리는 톱니, 방향(도) }, ... } }
	-- 한 구동 톱니에 둘을 물릴 때는 두 방향 차가 360/이수 의 정수배여야 둘 다 맞물린다
	local GEAR_SETS = {
		City_Gate = {
			{ "Gear_16", 0.8, 0, 20.6, -1.8, 24, 0, { { "Gear_10", 213.75 }, { "Gear_10", 326.25 } } },
			-- 뒷면(도시 안쪽)에도 한 벌. 반대로 돌려 두 면이 한 굴대에 물린 듯 보이게 한다
			{ "Gear_16", 0.8, 0, 20.6, 1.8, -24, 180, { { "Gear_10", 213.75 }, { "Gear_10", 326.25 } } },
		},
		-- 박공벽(x ±12, y 22.6..32.6) 안에 들게 줄였다. 작은 것은 같은 높이 왼쪽 굴대에
		Zapfen_Werk = { { "Gear_16", 0.8, 0, 28.0, -17.6, 18, 0, { { "Gear_10", 0 } } } },
		Big_Gear = { { "Gear_16", 0.95, 1.5, 8.1, 0.3, 20, 0, { { "Gear_10", 200.6 } } } },
		-- 둥근 로 벽에 납작한 톱니가 뜨지 않게 쇠 받침판(9 번째: 판 가운데 x, y, 폭, 높이)에 얹는다.
		-- 작은 것은 거의 바로 아래. 발판(y 24.5)과 로 어깨(y 36) 사이에 든다
		Herzofen = { { "Gear_16", 0.8, 11.4, 32.8, 1.5, 30, -90, { { "Gear_10", 250 } }, { -0.25, -1.95, 9.6, 12.8 } } },
	}
	local nGear = 0
	local function makeGear(kind, scale, cf, speed, phase, col, parent)
		local g = kit[kind]:Clone()
		g:ScaleTo(scale)
		g:PivotTo(cf * CFrame.Angles(0, 0, math.rad(phase)))
		for _, p in ipairs(g:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				if col and p.Name:match("_Brass$") then
					p.Color = col
				end
			end
		end
		g:SetAttribute("Speed", speed)
		if speed ~= 0 then
			CS:AddTag(g, "SnowGear")
		end
		g.Parent = parent
		nGear += 1
		return g
	end
	-- 구동 톱니 하나와 거기 물린 톱니들. base 는 구동 톱니 가운데이고 앞(-Z)이 보는 쪽이다
	local function gearTrain(base, kind, sc, speed, mates, f, still)
		local da = 360 / TEETH[kind]
		for _, mt in ipairs(mates) do
			local kindB, phi = mt[1], mt[2]
			local d = (gearR(kind) + gearR(kindB) - 0.9) * sc
			local off = CFrame.new(d * math.cos(math.rad(phi)), d * math.sin(math.rad(phi)), 0)
			makeGear(kindB, sc, base * off, -speed * TEETH[kind] / TEETH[kindB], phi + 180,
				still and RGB(95, 158, 140) or C.copper[1], f)
		end
		makeGear(kind, sc, base, speed, mates[1][2] - da / 2, still and RGB(140, 96, 70) or nil, f)
	end
	for _, e in ipairs(placed) do
		local sets = GEAR_SETS[e.kind]
		if sets then
			-- 폐허 마당의 조형물은 녹슬어 멈춰 있다
			local still = e.m.Parent.Name == "설공방"
			local f = folder("톱니")
			for _, st in ipairs(sets) do
				local kind, sc, x, y, z, speed, ry, mates = st[1], st[2], st[3], st[4], st[5], st[6], st[7], st[8]
				local base = e.m:GetPivot() * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(ry), 0)
				gearTrain(base, kind, sc, still and 0 or speed, mates, f, still)
				local pl = st[9]
				if pl then
					-- 받침판은 톱니 뒤(+Z) 1.0. 네 귀에 놋쇠 볼트, 두 옆 끝에서 벽으로 받침살
					local pc = base * CFrame.new(pl[1], pl[2], 1.0)
					part("GearPlate", pc, Vector3.new(pl[3], pl[4], 0.4), C.iron, f)
					for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
						part("PlateBolt", pc * CFrame.new(o[1] * (pl[3] / 2 - 0.5), o[2] * (pl[4] / 2 - 0.5), -0.3) * CFrame.Angles(0, math.rad(90), 0),
							Vector3.new(0.3, 0.6, 0.6), C.brass, f, Enum.PartType.Cylinder)
					end
					for _, sx in ipairs({ -1, 1 }) do
						part("PlateStay", pc * CFrame.new(sx * (pl[3] / 2 - 0.4), 0, 1.0), Vector3.new(0.6, pl[4] * 0.6, 1.8), C.iron, f)
					end
				end
			end
		end
		if e.kind == "Figuren_HQ" then
			-- 시계 바늘. 앞에서 보면 로컬 +X 가 왼쪽이라 양의 각속도가 시계 방향이다
			local c = e.m:GetPivot() * CFrame.new(0, 35.5, -17.1)
			for _, hd in ipairs({ { "Hour", 0.55, 2.3, 0.25, 125 }, { "Minute", 0.38, 3.3, 3.0, 10 } }) do
				local m = Instance.new("Model")
				m.Name = "ClockHand_" .. hd[1]
				local zoff = hd[1] == "Hour" and 0 or -0.25
				part(hd[1], c * CFrame.new(0, hd[3] / 2 - 0.35, zoff), Vector3.new(hd[2], hd[3], 0.22), C.iron, m)
				m.WorldPivot = c
				m:PivotTo(c * CFrame.Angles(0, 0, math.rad(hd[5])))
				m:SetAttribute("Speed", hd[4])
				CS:AddTag(m, "SnowGear")
				m.Parent = folder("톱니")
			end
			part("ClockPin", c * CFrame.new(0, 0, -0.45) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 0.7, 0.7), C.brass, folder("톱니"), Enum.PartType.Cylinder)
		end
	end

	--==================================================================== 3c. 맨홀
	-- 길 위 맨홀. 쇠 뚜껑에 놋쇠 테, 가운데에 톱니 무늬
	do
		local rpRoad = RaycastParams.new()
		rpRoad.FilterType = Enum.RaycastFilterType.Include
		rpRoad.FilterDescendantsInstances = { folder("길") }
		for i, mh in ipairs(D.MANHOLES) do
			local hit = workspace:Raycast(Vector3.new(mh[1], 400, mh[2]), Vector3.new(0, -800, 0), rpRoad)
			assert(hit, string.format("맨홀 %d 자리 (%.0f,%.0f) 에 길이 없다", i, mh[1], mh[2]))
			local top = hit.Position.Y
			local f = folder("길/맨홀")
			part("Cover", CFrame.new(mh[1], top + 0.08, mh[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 3.4, 3.4), C.iron, f, Enum.PartType.Cylinder)
			part("CoverRim", CFrame.new(mh[1], top + 0.04, mh[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 4.0, 4.0), C.brass, f, Enum.PartType.Cylinder)
			local g = makeGear("Gear_10", 0.42, CFrame.new(mh[1], top + 0.2, mh[2]) * CFrame.Angles(math.rad(90), 0, 0), 0, i * 23, C.iron[1], f)
			g.Name = "ManholeGear"
		end
	end
	task.wait()

	--==================================================================== 4. 난방관과 김
	-- 관 한 줄은 쇠 받침 위 높이 h 에 걸린 구리관이다. 꺾이는 점마다 공 이음을 넣어 매끈하게 잇고,
	-- 두 끝은 1/4 원환 엘보(Pipe_Bend90)로 휘어 땅으로 들어 볼트 박은 받침판에 선다.
	-- 받침 몇 곳에 밸브 손바퀴와 압력계를 얹고, 이음 몇 곳에서 김이 샌다
	local steamProto
	for _, d in ipairs(kit.Steam_House_A:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			steamProto = d
		end
	end
	local PR, BR = 1.1, 2.6 -- 관 반지름과 엘보 굽힘 반지름. Pipe_Bend90 과 같아야 한다
	local function cylBetween(name, a, b, r, col, f)
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		return part(name, cf, Vector3.new((b - a).Magnitude, 2 * r, 2 * r), col, f, Enum.PartType.Cylinder)
	end
	local function leak(at, f, rate)
		if not steamProto then
			return
		end
		local e = part("Leak", CFrame.new(at), Vector3.new(0.4, 0.4, 0.4), C.iron, f)
		e.Transparency = 1
		e.CanCollide = false
		e.CanQuery = false
		local s = steamProto:Clone()
		s.Rate = rate
		s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 3) })
		s.Speed = NumberRange.new(1.5, 2.5)
		s.Parent = e
	end
	local nValve, nGauge, nLeak = 0, 0, 0
	-- 관마다 높이는 밑 땅에서 가장 높은 곳 + 7. 모음통으로 이어진 관끼리는 가장 높은 것에 맞춘다
	-- (무리가 모음통 여럿으로 이어지므로 더 바뀌지 않을 때까지 되풀이)
	local pipeH = {}
	for _, pl in ipairs(D.PIPES) do
		local name, pts = pl[1], pl[2]
		local hi = -math.huge
		for i = 1, #pts do
			hi = math.max(hi, (assert(groundY(pts[i][1], pts[i][2]), name .. " 밑에 땅이 없다")))
			if i < #pts then
				hi = math.max(hi, groundY((pts[i][1] + pts[i + 1][1]) / 2, (pts[i][2] + pts[i + 1][2]) / 2) or hi)
			end
		end
		pipeH[name] = hi + 7
	end
	local changed = true
	while changed do
		changed = false
		for _, j in ipairs(D.JUNCTIONS) do
			local top = -math.huge
			for _, n in ipairs(j[3]) do
				top = math.max(top, (assert(pipeH[n], "모음통의 관 " .. n .. " 이 없다")))
			end
			for _, n in ipairs(j[3]) do
				if pipeH[n] < top then
					pipeH[n] = top
					changed = true
				end
			end
		end
	end
	local JR = 1.95 -- 모음통 반지름
	local function nearJunction(p, r)
		for _, j in ipairs(D.JUNCTIONS) do
			if Vector2.new(j[1] - p.X, j[2] - p.Z).Magnitude < r then
				return j
			end
		end
		return nil
	end
	for _, pl in ipairs(D.PIPES) do
		local name, pts = pl[1], pl[2]
		local f = folder("난방관/" .. name)
		local h = pipeH[name]
		local P = {}
		for i, q in ipairs(pts) do
			P[i] = Vector3.new(q[1], h, q[2])
		end
		local d0 = (P[2] - P[1]).Unit
		local dn = (P[#P] - P[#P - 1]).Unit
		-- 모음통에 꽂히는 끝은 엘보 없이 통 가운데까지 곧게 들어간다
		local j1, jn = nearJunction(P[1], 2.5), nearJunction(P[#P], 2.5)
		-- 곧은 도막. 두 끝은 엘보가 차지하는 BR 만큼 비운다. 가운데 꺾임은 공 이음이 메운다
		for i = 1, #P - 1 do
			local a = (i == 1 and not j1) and (P[1] + d0 * BR) or P[i]
			local b = (i == #P - 1 and not jn) and (P[#P] - dn * BR) or P[i + 1]
			cylBetween("Pipe", a, b, PR, C.copper, f)
		end
		for i = 2, #P - 1 do
			part("Joint", CFrame.new(P[i]), Vector3.new(2 * PR, 2 * PR, 2 * PR), C.copper, f, Enum.PartType.Ball)
		end
		-- 두 끝. 엘보로 꺾여 땅까지 내려가 받침판에 선다
		for _, e in ipairs({ { P[1], -d0, j1 }, { P[#P], dn, jn } }) do
			local corner, dir = e[1], e[2]
			if e[3] then
				continue
			end
			local bendM = kit.Pipe_Bend90:Clone()
			bendM:PivotTo(CFrame.fromMatrix(corner, dir, Vector3.yAxis))
			bendM.Parent = f
			local gy = assert(groundY(corner.X, corner.Z), name .. " 끝 밑에 땅이 없다")
			cylBetween("Drop", Vector3.new(corner.X, corner.Y - BR, corner.Z), Vector3.new(corner.X, gy + 0.3, corner.Z), PR, C.copper, f)
			part("DropFlange", CFrame.new(corner.X, gy + 0.75, corner.Z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 2.9, 2.9), C.brass, f, Enum.PartType.Cylinder)
			local plate = CFrame.new(corner.X, gy + 0.2, corner.Z) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
			part("BasePlate", plate, Vector3.new(4, 0.4, 4), C.iron, f)
			for _, o in ipairs({ { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } }) do
				part("Bolt", plate * CFrame.new(o[1], 0.35, o[2]) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 0.55, 0.55), C.brass, f, Enum.PartType.Cylinder)
			end
		end
		-- 받침. 줄을 따라 15 마다. 끝 엘보 가까이는 건너뛴다
		local total = 0
		for i = 1, #P - 1 do
			total += (P[i + 1] - P[i]).Magnitude
		end
		local npost = math.max(1, math.floor((total - 2 * BR - 4) / 15))
		local step = (total - 2 * BR - 4) / npost
		-- 관을 따라 want 만큼 간 자리와 그곳의 방향
		local function along(want)
			local acc = 0
			for i = 1, #P - 1 do
				local L = (P[i + 1] - P[i]).Magnitude
				if acc + L >= want then
					local dir = (P[i + 1] - P[i]).Unit
					return P[i] + dir * (want - acc), dir
				end
				acc += L
			end
			return P[#P], dn
		end
		for k = 0, npost do
			local q, dir = along(BR + 2 + step * k)
			-- 받침은 모음통 곁을 비운다. 통은 제 다리로 선다
			if nearJunction(q, JR + 2) then
				continue
			end
			local gy = groundY(q.X, q.Z)
			part("Post", CFrame.new(q.X, (h - PR + gy) / 2, q.Z), Vector3.new(0.9, h - PR - gy, 0.9), C.iron, f)
			part("PostFoot", CFrame.new(q.X, gy + 0.2, q.Z), Vector3.new(1.8, 0.4, 1.8), C.iron, f)
			part("Saddle", CFrame.lookAt(Vector3.new(q.X, h - PR - 0.25, q.Z), Vector3.new(q.X, h - PR - 0.25, q.Z) + dir), Vector3.new(2.4, 0.5, 1.2), C.brass, f)
			part("Clamp", CFrame.lookAt(q, q + dir) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.7, 2.7, 2.7), C.brass, f, Enum.PartType.Cylinder)
			-- 받침 고정쇠 이음에서 김이 조금 샌다. 몇 곳에서만
			if k % 5 == 2 then
				leak(q + dir * 0.45 + Vector3.new(0, PR * 0.6, 0), f, 1.5)
				nLeak += 1
			end
			-- 밸브와 압력계는 받침과 받침 한가운데에 번갈아 단다. 고정쇠와 겹치지 않게.
			-- 꺾인 곳(공 이음)과 모음통 곁은 피한다
			if k < npost and (k % 4 == 1 or k % 4 == 3) then
				local m, mdir
				for _, off in ipairs({ 0, 1, -1, 2, -2, 3, -3 }) do
					local cm, cd = along(BR + 2 + step * (k + 0.5) + off)
					local ok = not nearJunction(cm, JR + 3)
					for i = 2, #P - 1 do
						if (P[i] - cm).Magnitude < 2 then
							ok = false
						end
					end
					if ok then
						m, mdir = cm, cd
						break
					end
				end
				if m then
					local top = m + Vector3.new(0, PR, 0)
					if k % 4 == 1 then
						local v = kit.Pipe_Valve:Clone()
						v:PivotTo(CFrame.lookAt(top, top + mdir))
						v.Parent = f
						nValve += 1
					else
						local side = Vector3.new(-mdir.Z, 0, mdir.X)
						local gm = kit.Pipe_Gauge:Clone()
						gm:PivotTo(CFrame.lookAt(top, top + side))
						gm.Parent = f
						nGauge += 1
					end
				end
			end
		end
	end
	-- 모음통. 선 구리통에 놋쇠 띠, 쇠 뚜껑 위 압력계, 제 다리. 드나드는 관마다 통 벽에 놋쇠 테
	local nJunction = 0
	for i, j in ipairs(D.JUNCTIONS) do
		local f = folder("난방관/모음통")
		local h = pipeH[j[3][1]]
		local c = Vector3.new(j[1], h, j[2])
		local up = CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90))
		part("Drum_" .. i, up, Vector3.new(4.2, 2 * JR, 2 * JR), C.copper, f, Enum.PartType.Cylinder)
		for _, dy in ipairs({ -1.3, 1.3 }) do
			part("DrumBand", up + Vector3.new(0, dy, 0), Vector3.new(0.5, 2 * JR + 0.3, 2 * JR + 0.3), C.brass, f, Enum.PartType.Cylinder)
		end
		part("DrumCap", up + Vector3.new(0, 2.3, 0), Vector3.new(0.4, 2 * JR + 0.4, 2 * JR + 0.4), C.iron, f, Enum.PartType.Cylinder)
		part("DrumCapB", up + Vector3.new(0, -2.3, 0), Vector3.new(0.4, 2 * JR + 0.4, 2 * JR + 0.4), C.iron, f, Enum.PartType.Cylinder)
		local gm = kit.Pipe_Gauge:Clone()
		local capTop = c + Vector3.new(0, 2.5, 0)
		gm:PivotTo(CFrame.lookAt(capTop, capTop + Vector3.new(1, 0, 0)))
		gm.Parent = f
		nGauge += 1
		local gy = assert(groundY(c.X, c.Z), "모음통 밑에 땅이 없다")
		part("DrumLeg", CFrame.new(c.X, (c.Y - 2.5 + gy) / 2, c.Z), Vector3.new(1.2, c.Y - 2.5 - gy, 1.2), C.iron, f)
		part("DrumFoot", CFrame.new(c.X, gy + 0.2, c.Z), Vector3.new(2.4, 0.4, 2.4), C.iron, f)
		leak(c + Vector3.new(0, 2.6, 0.8), f, 2)
		nLeak += 1
		-- 관이 통 벽을 지나는 자리마다 테. 관 줄 도막과 통 둘레(반지름 JR)가 만나는 점을 찾는다
		for _, n in ipairs(j[3]) do
			local pts
			for _, pl in ipairs(D.PIPES) do
				if pl[1] == n then
					pts = pl[2]
				end
			end
			for k = 1, #pts - 1 do
				local A = Vector2.new(pts[k][1] - c.X, pts[k][2] - c.Z)
				local B = Vector2.new(pts[k + 1][1] - c.X, pts[k + 1][2] - c.Z)
				local d = B - A
				local qa, qb, qc = d:Dot(d), 2 * A:Dot(d), A:Dot(A) - JR * JR
				local disc = qb * qb - 4 * qa * qc
				if disc > 0 then
					for _, sg in ipairs({ -1, 1 }) do
						local t = (-qb + sg * math.sqrt(disc)) / (2 * qa)
						if t >= 0 and t <= 1 then
							local hit = A + d * t
							local q = Vector3.new(c.X + hit.X, h, c.Z + hit.Y)
							local dir = Vector3.new(d.X, 0, d.Y).Unit
							part("DrumCollar", CFrame.lookAt(q, q + dir) * CFrame.Angles(0, math.rad(90), 0),
								Vector3.new(0.6, 2 * PR * 1.35, 2 * PR * 1.35), C.brass, f, Enum.PartType.Cylinder)
						end
					end
				end
			end
		end
		nJunction += 1
	end
	-- 김구멍이 길 위에 놓이면 길 윗면에 얹는다
	local rpVent = RaycastParams.new()
	rpVent.FilterType = Enum.RaycastFilterType.Include
	rpVent.FilterDescendantsInstances = { G, FStone, folder("길") }
	for i, v in ipairs(D.VENTS) do
		local gy = groundY(v[1], v[2], rpVent)
		local f = folder("난방관/김구멍")
		part("Grate_" .. i, CFrame.new(v[1], gy + 0.15, v[2]), Vector3.new(3.2, 0.3, 3.2), C.plate, f)
		local e = part("SteamPoint_" .. i, CFrame.new(v[1], gy + 0.6, v[2]), Vector3.new(0.5, 0.5, 0.5), C.iron, f)
		e.Transparency = 1
		e.CanCollide = false
		e.CanQuery = false
		if steamProto then
			local s = steamProto:Clone()
			s.Rate = 3
			s.Parent = e
		end
	end
	task.wait()

	--==================================================================== 5. 안쪽 방
	local IC = {
		brick = { RGB(122, 64, 52), M.Brick },
		brickDark = { RGB(90, 67, 61), M.Brick },
		stone = { RGB(85, 86, 92), M.Slate },
		trim = { RGB(140, 139, 138), M.Concrete },
		iron = { RGB(58, 60, 66), M.Metal },
		plate = { RGB(94, 98, 107), M.DiamondPlate },
		brass = { RGB(184, 145, 63), M.Metal },
		copper = { RGB(176, 106, 63), M.Metal },
		timber = { RGB(90, 62, 44), M.WoodPlanks },
		wood = { RGB(110, 76, 52), M.Wood },
		floorwood = { RGB(98, 70, 50), M.WoodPlanks },
		concrete = { RGB(104, 104, 108), M.Concrete },
		glow = { RGB(225, 140, 60), M.Neon },
		core = { RGB(255, 55, 75), M.Neon },
		soot = { RGB(43, 42, 44), M.Slate },
		char = { RGB(31, 27, 26), M.Wood },
		ash = { RGB(92, 90, 88), M.Slate },
		paper = { RGB(222, 212, 186), M.SmoothPlastic },
		scorch = { RGB(150, 120, 90), M.SmoothPlastic },
		banner = { RGB(124, 43, 46), M.Fabric },
		glass = { RGB(200, 225, 235), M.Glass },
		rubber = { RGB(30, 30, 32), M.Slate },
		marble = { RGB(225, 225, 228), M.Marble },
		dark = { RGB(40, 40, 44), M.Slate },
		screen = { RGB(235, 225, 190), M.Neon },
	}
	-- 방 한 칸. 바닥 윗면이 y 0 이고 앞(-Z) 벽에 나가는 문이 있다
	local roomCount = 0
	local function makeRoom(id, title, W, Dp, H, floorC, wallC, ceilC, wallTop)
		roomCount += 1
		local O = Vector3.new(-7600, 400, -2900 + roomCount * 170)
		local f = folder("안쪽방/" .. title)
		local function B(name, x, y, z, sx, sy, sz, key, opt)
			opt = opt or {}
			local cf = CFrame.new(O + Vector3.new(x, y, z))
			if opt.rot then
				cf = cf * CFrame.Angles(math.rad(opt.rot[1]), math.rad(opt.rot[2]), math.rad(opt.rot[3]))
			end
			local shape
			if opt.cyl then
				shape = Enum.PartType.Cylinder
				-- 원통의 축은 로컬 X. y 축으로 세우려면 z 로 90 도, z 축이면 y 로 90 도
				if opt.cyl == "y" then
					cf = cf * CFrame.Angles(0, 0, math.rad(90))
				elseif opt.cyl == "z" then
					cf = cf * CFrame.Angles(0, math.rad(90), 0)
				end
			elseif opt.ball then
				shape = Enum.PartType.Ball
			end
			local p = part(name, cf, Vector3.new(sx, sy, sz), IC[key], f, shape)
			if opt.tr then
				p.Transparency = opt.tr
			end
			if opt.nocol or IC[key][2] == M.Neon then
				p.CanCollide = false
			end
			if opt.light then
				local l = Instance.new("PointLight")
				l.Range, l.Brightness = opt.light[1], opt.light[2]
				l.Color = opt.light[3] or RGB(255, 190, 120)
				l.Shadows = true
				l.Parent = p
			end
			if opt.spot then
				local l = Instance.new("SpotLight")
				l.Angle, l.Range, l.Brightness = opt.spot[1], opt.spot[2], opt.spot[3]
				l.Face = opt.spot[4]
				l.Color = opt.spot[5] or RGB(255, 240, 210)
				l.Shadows = true
				l.Parent = p
			end
			return p
		end
		-- 껍데기
		B("Floor", 0, -0.5, 0, W + 2, 1, Dp + 2, floorC)
		local wh = wallTop or H
		B("Wall_B", 0, wh / 2, Dp / 2 + 0.5, W + 2, wh, 1, wallC)
		B("Wall_F", 0, wh / 2, -Dp / 2 - 0.5, W + 2, wh, 1, wallC)
		B("Wall_L", -W / 2 - 0.5, wh / 2, 0, 1, wh, Dp, wallC)
		B("Wall_R", W / 2 + 0.5, wh / 2, 0, 1, wh, Dp, wallC)
		if ceilC then
			B("Ceiling", 0, H + 0.5, 0, W + 2, 1, Dp + 2, ceilC)
		end
		-- 들어섰을 때 설 자리. 방 안쪽을 본다
		local arrive = part("Arrive", CFrame.lookAt(O + Vector3.new(0, 0.1, -Dp / 2 + 6), O + Vector3.new(0, 0.1, 10)), Vector3.new(4, 0.2, 4), IC.dark, f)
		arrive.Transparency = 1
		arrive.CanCollide = false
		arrive.CanQuery = false
		arrive:SetAttribute("InteriorId", id)
		CS:AddTag(arrive, "SnowArrive")
		return B, O, f
	end
	local function exitDoor(B, id, Dp, w, h, key)
		local door = B("ExitDoor", 0, h / 2, -Dp / 2 + 0.25, w, h, 0.5, key)
		B("ExitFrameL", -w / 2 - 0.4, h / 2, -Dp / 2 + 0.3, 0.8, h + 0.4, 0.7, "trim")
		B("ExitFrameR", w / 2 + 0.4, h / 2, -Dp / 2 + 0.3, 0.8, h + 0.4, 0.7, "trim")
		B("ExitFrameT", 0, h + 0.4, -Dp / 2 + 0.3, w + 1.6, 0.8, 0.7, "trim")
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "나가기"
		pr.ObjectText = "바깥"
		pr.HoldDuration = 0.25
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = door
		door:SetAttribute("InteriorId", id)
		CS:AddTag(door, "SnowExit")
	end
	-- 방 소품(키트 틀, models/build_props.py)을 방 원점 O 기준 자리에 놓는다. yaw 는 도(앞 -Z 가 0), extra 는 더 돌릴 것
	local function prop(kind, O, f, x, y, z, yaw, extra)
		local m = assert(kit:FindFirstChild(kind), "키트에 " .. kind .. " 이 없다"):Clone()
		local cf = CFrame.new(O + Vector3.new(x, y, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
		m:PivotTo(extra and cf * extra or cf)
		m.Parent = f
		return m
	end

	-- ----------------------------------------------------------- 프로스티히 공방: 무기 공방 매장
	do
		local B, O, f = makeRoom("Frostig", "프로스티히공방", 44, 30, 16, "floorwood", "brick", "timber")
		for _, z in ipairs({ -12, -6, 0, 6, 12 }) do
			B("Beam", 0, 15.4, z, 44, 0.8, 0.8, "iron")
		end
		B("Rug", 0, 0.05, -10, 10, 0.1, 6, "banner")
		-- 판매대와 진열장
		B("Counter", 0, 2, -4, 20, 4, 3, "timber")
		B("CounterTop", 0, 4.15, -4, 20.4, 0.3, 3.4, "brass")
		B("Register", 6, 5, -4, 2, 1.4, 1.4, "brass")
		B("RegisterKeys", 6, 4.6, -4.9, 1.6, 0.4, 0.5, "iron")
		B("Case", -5, 5.3, -4, 6, 2, 2.6, "glass", { tr = 0.55 })
		-- 진열장 속 권총 셋. 옆으로 눕혔다(두께가 위)
		for _, pp in ipairs({ { -6.0, -4.2, 8 }, { -3.6, -4.1, -12 }, { -4.9, -3.6, 180 } }) do
			prop("Steam_Pistol", O, f, pp[1], 4.41, pp[2], pp[3], CFrame.Angles(math.rad(-90), 0, 0))
		end
		-- 뒷벽 총걸이. 장총 여섯 자루
		B("GunRack", 0, 8, 14.7, 18, 7, 0.6, "timber")
		B("RackSign", 0, 12.6, 14.85, 8, 1.4, 0.3, "brass")
		for r, y in ipairs({ 5.8, 8.2, 10.6 }) do
			for c, x in ipairs({ -4.5, 4.5 }) do
				-- 총열 높이가 y. 총은 놋쇠 못 둘(개머리 밑, 앞총대 밑)에 얹힌다
				local py = y - 1.03
				prop("Steam_Rifle", O, f, x, py, 14.19, 0)
				B(string.format("Peg_%d_%d_a", r, c), x + 2.6, py + 0.25, 14.15, 0.5, 0.24, 0.24, "brass", { cyl = "z" })
				B(string.format("Peg_%d_%d_b", r, c), x - 2.3, py + 0.51, 14.15, 0.5, 0.24, 0.24, "brass", { cyl = "z" })
			end
		end
		-- 작업대
		B("Bench", 14, 3.2, 8, 10, 0.8, 4, "timber")
		for _, dx in ipairs({ -4.5, 4.5 }) do
			for _, dz in ipairs({ -1.6, 1.6 }) do
				B("BenchLeg", 14 + dx, 1.4, 8 + dz, 0.6, 2.8, 0.6, "timber")
			end
		end
		B("Vise", 10, 4.2, 8, 1.2, 1.2, 1.6, "iron")
		B("Blueprint", 15, 3.65, 8, 3, 0.05, 2, "paper", { rot = { 0, 8, 0 } })
		B("Tool1", 17.5, 3.8, 7, 2, 0.3, 0.3, "iron", { rot = { 0, 30, 0 } })
		B("Tool2", 12.5, 3.8, 9.2, 1.6, 0.3, 0.4, "brass")
		-- 화덕과 모루
		-- 화덕(굴뚝이 들보 z 6, 12 사이로 천장까지)과 그루터기 모루
		prop("Forge", O, f, -17, 0, 10, 0)
		prop("Anvil", O, f, -12, 0, 4, 0)
		-- 통과 궤짝
		B("Barrel1", 19.5, 1.6, -12, 3.2, 2.6, 2.6, "wood", { cyl = "y" })
		B("Barrel2", 19.2, 1.6, -9, 3.2, 2.6, 2.6, "wood", { cyl = "y" })
		B("Crate1", -19.5, 1.5, -12, 3, 3, 3, "timber")
		B("Crate2", -19.3, 4.5, -12.2, 3, 3, 3, "timber", { rot = { 0, 12, 0 } })
		B("Crate3", -19.5, 1.5, -8.6, 3, 3, 3, "timber", { rot = { 0, -8, 0 } })
		-- 오른쪽 벽. 톱니 장식과 설계도 판
		-- 벽 톱니는 방을(-X) 보게 세운다. 로컬 +X 가 월드 -Z 라 137 도가 위쪽 문 방향이다
		gearTrain(CFrame.new(O + Vector3.new(21.72, 9, -4)) * CFrame.Angles(0, math.rad(90), 0),
			"Gear_16", 0.5, 25, { { "Gear_10", 137 } }, f)
		B("PinBoard", 21.7, 8, 7, 0.4, 5, 8, "timber")
		B("Sheet1", 21.4, 8.8, 5, 0.1, 2.2, 3, "paper")
		B("Sheet2", 21.4, 7.2, 8.5, 0.1, 2, 2.6, "paper", { rot = { 6, 0, 0 } })
		B("Sheet3", 21.4, 9.6, 9.2, 0.1, 1.6, 1.4, "paper")
		-- 매단 등
		for i, p in ipairs({ { -8, -4 }, { 8, -4 }, { 0, 8 } }) do
			B("Chain_" .. i, p[1], 14.3, p[2], 0.15, 2.2, 0.15, "iron")
			B("Lamp_" .. i, p[1], 12.6, p[2], 1.2, 1.4, 1.2, "glow", { light = { 24, 1.3 } })
			B("LampCap_" .. i, p[1], 13.5, p[2], 1.8, 0.4, 1.8, "brass")
		end
		exitDoor(B, "Frostig", 30, 4.6, 8, "timber")
	end

	-- ----------------------------------------------------------- 차펜 공방: 공장과 특허 금고
	-- 문(앞 가운데)에서 뒷벽까지 가운데 통로를 비운다. 왼쪽은 증기 압착기 → 운반대 → 짐통 한 줄,
	-- 그 위 왼벽에 중이층 사무실. 오른쪽 앞은 보일러 둘(김은 천장 본관을 타고 압착기로 간다),
	-- 오른쪽 뒤 구석은 특허 금고. 뒷벽에 큰 톱니 한 쌍
	do
		local B, O, f = makeRoom("Zapfen", "차펜공방", 64, 40, 24, "concrete", "brickDark", "iron")
		for _, z in ipairs({ -15, -5, 5, 15 }) do
			B("Truss", 0, 22.5, z, 64, 1, 1, "iron")
		end
		for _, x in ipairs({ -16, 16 }) do
			for _, z in ipairs({ -10, 10 }) do
				B("Column", x, 11, z, 1.2, 22, 1.2, "iron")
			end
		end
		-- 뒷벽 톱니. 벽(z 20)에 굴대가 박히게 바짝 붙인다. 작은 것은 왼쪽 아래
		gearTrain(CFrame.new(O + Vector3.new(8, 12, 19.4)), "Gear_24", 1.07, 12, { { "Gear_16", 202.4 } }, f)

		-- 증기 압착기. 뒤 왼쪽. 천장 본관에서 김을 받아 판을 찍어 앞(-Z) 운반대로 내보낸다
		prop("Steam_Press", O, f, -12, 0, 15.3, 0)
		B("PressFeed", -12, 20.1, 15.6, 2.2, 1.2, 1.2, "copper", { cyl = "y" })
		-- 운반대. 압착기 앞에서 문 쪽으로 찍은 판을 나른다. 난간 둘, 다리 셋 쌍, 두 끝 굴림대
		B("Belt", -12, 3.4, 2.7, 3.2, 0.8, 17.4, "rubber")
		for _, x in ipairs({ -13.75, -10.25 }) do
			B("BeltRail", x, 3.6, 2.7, 0.3, 1.0, 17.8, "iron")
		end
		for _, z in ipairs({ -4, 2.7, 9.4 }) do
			for _, x in ipairs({ -13.3, -10.7 }) do
				B("BeltLeg", x, 1.5, z, 0.6, 3, 0.6, "iron")
			end
		end
		B("RollerA", -12, 3.4, 11.4, 3.6, 1.4, 1.4, "iron", { cyl = "x" })
		B("RollerB", -12, 3.4, -6, 3.6, 1.4, 1.4, "iron", { cyl = "x" })
		-- 운반대 위에 막 찍은 작은 톱니. 차펜(굴대·톱니) 공방이 만드는 것
		for i, z in ipairs({ -2.5, 2.4, 7.6 }) do
			makeGear("Gear_10", 0.3, CFrame.new(O + Vector3.new(-12, 4.04, z)) * CFrame.Angles(math.rad(90), 0, 0), 0, i * 17, nil, f)
		end
		-- 운반대 끝 짐통. 위가 트인 쇠 통에 찍은 놋쇠 판이 쌓였다
		B("BinFloor", -12, 0.2, -8.7, 3.4, 0.4, 2.8, "iron")
		B("BinF", -12, 1.3, -10.25, 4, 2.6, 0.3, "iron")
		B("BinB", -12, 1.3, -7.15, 4, 2.6, 0.3, "iron")
		B("BinL", -13.85, 1.3, -8.7, 0.3, 2.6, 2.8, "iron")
		B("BinR", -10.15, 1.3, -8.7, 0.3, 2.6, 2.8, "iron")
		-- 톱니 끝 반지름 1.07. 통 안쪽(x -13.7..-10.3, z -10.1..-7.3)에 들게
		for i, pp in ipairs({ { -12.4, 0.64, -8.9 }, { -11.6, 0.95, -8.5 }, { -12.0, 1.26, -8.7 } }) do
			makeGear("Gear_10", 0.3, CFrame.new(O + Vector3.new(pp[1], pp[2], pp[3])) * CFrame.Angles(math.rad(90), 0, 0), 0, i * 29, nil, f)
		end
		B("Crate1", -7.5, 1.5, -9, 3, 3, 3, "timber")
		B("Crate2", -7.6, 4.5, -9.2, 3, 3, 3, "timber", { rot = { 0, 12, 0 } })
		B("Crate3", -7.4, 1.5, -12.4, 3, 3, 3, "timber", { rot = { 0, -8, 0 } })

		-- 보일러 둘. 오른쪽 벽 앞쪽. 아궁이 불빛, 김은 세운 관으로 천장 본관에
		for i, z in ipairs({ -2, -12 }) do
			-- 아궁이가 방 가운데(-X)를 본다. 증기 목(y 14.5)에서 천장 모음관까지 세운 관
			prop("Vertical_Boiler", O, f, 26, 0, z, 90)
			B("Riser_" .. i, 26, 17.85, z, 6.7, 1.4, 1.4, "copper", { cyl = "y" })
		end
		-- 천장 본관. 두 보일러를 잇는 모음관(z) → 방을 가로지르는 본관(x) → 압착기 쪽으로 꺾는 관(z)
		B("Header", 26, 21.2, -7, 10, 1.4, 1.4, "copper", { cyl = "z" })
		B("CeilPipe", 7, 21.2, -2, 38, 1.4, 1.4, "copper", { cyl = "x" })
		B("CeilPipe2", -12, 21.2, 6.8, 17.6, 1.4, 1.4, "copper", { cyl = "z" })
		for i, pp in ipairs({ { 26, -12 }, { 26, -2 }, { -12, -2 }, { -12, 15.6 } }) do
			B("PipeJoint_" .. i, pp[1], 21.2, pp[2], 1.6, 1.6, 1.6, "brass", { ball = true })
		end
		for _, x in ipairs({ 16, 0, -8 }) do
			B("Hanger", x, 22.6, -2, 0.2, 2.8, 0.2, "iron")
		end

		-- 왼쪽 벽 중이층. 다리 셋이 받치고, 계단 오르는 자리(z -17.5..-14.5)만 난간을 튼다
		B("Mezz", -26, 8, 0, 10, 0.6, 36, "plate")
		for _, z in ipairs({ -12, 0, 12 }) do
			B("MezzLeg", -21.6, 3.85, z, 0.8, 7.7, 0.8, "iron")
		end
		for _, z in ipairs({ -14, -10, -6, -2, 2, 6, 10, 14, 17.6 }) do
			B("MezzPost", -21.2, 9.8, z, 0.4, 3, 0.4, "iron")
		end
		B("MezzRail", -21.2, 11.2, 1.8, 0.3, 0.3, 31.6, "iron")
		for _, x in ipairs({ -30, -26, -22 }) do
			B("MezzPostF", x, 9.8, -17.8, 0.4, 3, 0.4, "iron")
		end
		B("MezzRailF", -26, 11.2, -17.8, 9.6, 0.3, 0.3, "iron")
		for k = 0, 7 do
			-- 중이층(윗면 8.3)으로 오르는 나무 계단. 한 단이 바닥부터 꽉 찬 덩이다
			B("Step_" .. k, -12.6 - k * 1.1, (k + 1) / 2, -16, 1.2, k + 1, 3, "timber")
		end
		B("OfficeDesk", -27, 9.8, -8, 5, 3, 3, "timber")
		B("OfficeLamp", -27, 11.8, -8, 0.8, 1, 0.8, "glow", { light = { 12, 1 } })

		-- 특허 금고. 오른쪽 뒤 구석. 앞벽에 문 구멍(x 21.5..26.5)을 내고 두꺼운 쇠문이 110 도 열려 있다
		B("VaultPierL", 20.6, 6, 8.5, 1.8, 12, 1, "iron")
		B("VaultPierR", 29.25, 6, 8.5, 5.5, 12, 1, "iron")
		B("VaultLintel", 24, 9.6, 8.5, 5, 4.8, 1, "iron")
		B("VaultSill", 24, 0.1, 8.5, 5, 0.2, 1.2, "brass")
		B("VaultSide", 20.2, 6, 14.5, 1, 12, 11, "iron")
		B("VaultTop", 25.85, 12.5, 14.25, 12.3, 1, 11.5, "iron")
		-- 문짝은 경첩(21.5, 8.0)에서 방 쪽(-Z)으로 돌아 열렸다. 바깥면은 (-0.94, 0, 0.34) 를 본다
		B("VaultDoor", 21.02, 3.6, 5.51, 5, 7.2, 0.8, "iron", { rot = { 0, 110, 0 } })
		B("VaultWheel", 20.46, 3.6, 5.72, 0.4, 3, 3, "brass", { cyl = "x", rot = { 0, 20, 0 } })
		for _, y in ipairs({ 1.2, 6 }) do
			B("VaultHinge", 21.5, y, 8.0, 1.2, 0.6, 0.6, "brass", { cyl = "y" })
		end
		-- 문서 선반. 벽에 붙은 뒤판과 판 셋, 판마다 문서함 둘
		B("ShelfBack", 31.7, 4.5, 14, 0.4, 9, 10, "timber")
		for _, z in ipairs({ 9.15, 18.85 }) do
			B("ShelfSide", 30.4, 4.5, z, 2.4, 9, 0.3, "timber")
		end
		for r, y in ipairs({ 0.3, 3.3, 6.3 }) do
			B("ShelfBoard", 30.4, y, 14, 2.4, 0.3, 9.4, "timber")
			for c, z in ipairs({ 11.5, 16.5 }) do
				B(string.format("DocBox_%d_%d", r, c), 30.3, y + 0.75, z, 2, 1.2, 1.6, "paper")
			end
		end
		B("VaultDesk", 25.5, 2, 16.5, 5, 4, 2.4, "timber")
		B("Patent1", 25, 4.05, 16.4, 2.2, 0.05, 1.6, "paper", { rot = { 0, 10, 0 } })
		B("Patent2", 26.4, 4.1, 16.8, 2.2, 0.05, 1.6, "paper", { rot = { 0, -14, 0 } })
		B("Seal", 26.4, 4.2, 16.6, 0.5, 0.1, 0.5, "core")
		B("VaultLamp", 23.2, 4.5, 16.8, 0.8, 1, 0.8, "glow", { light = { 12, 1.2 } })

		-- 공장 등. 들보(z ±5)에 사슬로 매단다. 천장 관(z -2, x -12)을 비킨다
		for i, pp in ipairs({ { -4, -5 }, { 10, -5 }, { -4, 5 }, { 10, 5 } }) do
			B("LampChain_" .. i, pp[1], 21.55, pp[2], 0.15, 0.9, 0.15, "iron")
			B("FactoryShade_" .. i, pp[1], 20.8, pp[2], 3.4, 0.6, 3.4, "iron")
			B("FactoryLamp_" .. i, pp[1], 20, pp[2], 2, 1, 2, "glow", { light = { 32, 1.3 } })
		end
		exitDoor(B, "Zapfen", 40, 10, 12, "timber")
	end

	-- ----------------------------------------------------------- 설 공방: 불탄 작업실
	do
		-- 천장은 왼쪽 절반만 남았다. 오른쪽은 하늘로 뚫렸고 눈이 들이친다
		local B, O, f = makeRoom("Sel", "설공방", 34, 26, 14, "soot", "brickDark", nil, 6)
		-- 두 끝점을 잇는 탄 들보. 떨어진 것은 한 끝이 바닥에, 매달린 것은 한 끝이 천장에 걸린다
		local function beam(name, a, b, t)
			return part(name, CFrame.lookAt(O + (a + b) / 2, O + b), Vector3.new(t, t, (b - a).Magnitude), IC.char, f)
		end
		B("SootWall_B", 0, 10, 13.5, 36, 8, 1, "soot")
		B("SootWall_F", 0, 10, -13.5, 36, 8, 1, "soot")
		B("SootWall_L", -17.5, 10, 0, 1, 8, 26, "soot")
		B("SootWall_R", 17.5, 10, 0, 1, 8, 26, "soot")
		B("CeilingLeft", -8, 14.5, 0, 20, 1, 28, "char")
		B("Ash1", -6, 0.05, 2, 6, 0.1, 4, "ash", { rot = { 0, 20, 0 } })
		B("Ash2", 8, 0.05, -5, 5, 0.1, 5, "ash", { rot = { 0, -15, 0 } })
		B("Ash3", 2, 0.05, 8, 7, 0.1, 3, "ash", { rot = { 0, 40, 0 } })
		-- 무너진 서까래
		beam("Beam1", Vector3.new(11.2, 0.3, 2.8), Vector3.new(6.84, 7.17, 8.0), 1) -- 바닥에서 변환장치 뚜껑 테에 기댄 것
		beam("Beam2", Vector3.new(6, 0.4, -3), Vector3.new(13.5, 0.4, -9.5), 0.8) -- 바닥에 누운 것. 도착 자리를 비킨다
		beam("Beam3", Vector3.new(14, 0.35, 3.3), Vector3.new(14, 9.7, 12.8), 1) -- 뒷벽에 기댄 것
		beam("Beam4", Vector3.new(0.5, 14.2, 5), Vector3.new(6, 8, 7), 0.8) -- 남은 천장 끝에 걸려 늘어진 것
		-- 탄 작업대와 넘어진 의자
		-- 작업대는 오른 다리가 부러져 한 끝이 바닥에 닿았다
		B("Bench", -10.2, 1.7, 8, 8, 0.8, 3.5, "char", { rot = { 0, 0, -19 } })
		B("BenchLeg1", -13.5, 1.2, 8, 0.6, 2.4, 0.6, "char")
		B("BenchLeg2", -6.5, 0.48, 8.8, 0.6, 1.2, 0.6, "char", { rot = { 0, 0, 70 } })
		-- 의자는 뒤로 넘어졌다. 등판이 바닥에 눕고 앉는 판이 서 있다
		B("ChairBack", -4, 0.15, 4.4, 2, 2.2, 0.3, "char", { rot = { 90, 0, 0 } })
		B("ChairSeat", -4, 1, 3.15, 2, 0.3, 2, "char", { rot = { 90, 0, 0 } })
		-- 문짝이 비틀린 금고와 흩어진 서류
		B("Safe", -13, 2.25, -8, 4, 4.5, 3.5, "iron")
		B("SafeDoor", -11.4, 2.25, -10.3, 3.2, 3.8, 0.4, "iron", { rot = { 0, -55, 0 } })
		for i, p in ipairs({ { -12.6, -8.4, 0 }, { -9, -6, 25 }, { -7.5, -9, -40 }, { -10.5, -4, 70 }, { -5, -7.4, 10 }, { -12, -3, -20 } }) do
			B("Paper_" .. i, p[1], 0.026 + i * 0.004, p[2], 1.4, 0.05, 1.8, (i % 2 == 0) and "scorch" or "paper", { rot = { 0, p[3], 0 } })
		end
		-- 초기 감정 변환장치. 금이 가 희미하게 달아 있다
		local proto = prop("Emotion_Proto", O, f, 6, 0, 9, 0)
		local core = proto:FindFirstChild("Proto_Core")
		if core then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness, l.Shadows = RGB(255, 110, 80), 10, 0.7, true
			l.Parent = core
		end
		for i, p in ipairs({ { 3, -2 }, { 5, 1 }, { 0, -4 }, { 7, -1 } }) do
			B("Shard_" .. i, p[1], 0.05, p[2], 0.8, 0.05, 0.5, "glass", { rot = { 0, i * 37, 0 }, tr = 0.3 })
		end
		B("Lantern", -4, 0.6, -6, 0.8, 1.2, 0.8, "glow", { light = { 14, 1 } })
		-- 뚫린 지붕. 차가운 빛과 들이치는 눈
		local hole = B("SkyHole", 8, 15.5, 0, 14, 0.2, 26, "glass", { tr = 1, nocol = true, spot = { 70, 32, 1.4, Enum.NormalId.Bottom, RGB(200, 215, 255) } })
		local snow = Instance.new("ParticleEmitter")
		snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		snow.Color = ColorSequence.new(RGB(255, 255, 255))
		snow.Size = NumberSequence.new(0.25)
		snow.Lifetime = NumberRange.new(4, 6)
		snow.Rate = 30
		snow.Speed = NumberRange.new(2, 3)
		snow.EmissionDirection = Enum.NormalId.Bottom
		snow.SpreadAngle = Vector2.new(20, 20)
		snow.Acceleration = Vector3.new(0.6, -0.5, 0)
		snow.LightEmission = 0.2
		snow.Parent = hole
		exitDoor(B, "Sel", 26, 4, 7.5, "char")
	end

	-- ----------------------------------------------------------- 기물군 본부: 작전실
	do
		local B, O, f = makeRoom("Figuren", "기물군본부", 44, 32, 20, "dark", "stone", "stone")
		B("Carpet", 0, 0.05, 0, 6, 0.1, 26, "banner")
		for _, x in ipairs({ -21.5, 21.5 }) do
			for z = -12, 12, 8 do
				B("Pilaster", x, 10, z, 1, 20, 1.6, "trim")
			end
		end
		for _, x in ipairs({ -10, 10 }) do
			B("BackBanner", x, 11, 15.4, 4, 10, 0.2, "banner")
			B("BackEmblem", x, 13, 15.2, 0.3, 2.6, 2.6, "brass", { cyl = "z" })
		end
		for _, x in ipairs({ -21.85, 21.85 }) do
			for _, z in ipairs({ -8, 8 }) do
				B("SideBanner", x, 11, z, 0.2, 9, 3.5, "banner")
			end
		end
		-- 작전 탁자. 체스판 위에 기물이 판세대로 놓였다
		B("Table", 0, 1.5, 2, 16, 3, 12, "timber")
		B("BoardRim", 0, 3.05, 2, 12.6, 0.1, 12.6, "brass")
		for i = 0, 7 do
			for j = 0, 7 do
				B(string.format("Sq_%d_%d", i, j), -5.25 + i * 1.5, 3.16, 2 - 5.25 + j * 1.5, 1.5, 0.12, 1.5, ((i + j) % 2 == 0) and "dark" or "marble")
			end
		end
		local function sq(i, j)
			return -5.25 + i * 1.5, 2 - 5.25 + j * 1.5
		end
		-- 기물은 블렌더로 깎은 키트 틀. 쇠 편은 +Z(놋쇠 편)를, 놋쇠 편은 -Z 를 본다
		local function piece(kind, x, y, z, side, yaw)
			local m = prop("Chess_" .. kind, O, f, x, y, z, yaw or (side == "iron" and 180 or 0))
			if side == "brass" then
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Color, p.Material = IC.brass[1], IC.brass[2]
					end
				end
			end
		end
		-- 판세(손으로 둔 것): 쇠 편은 짧은 쪽, 놋쇠 편은 긴 쪽으로 성을 쌓았고 가운데 폰이 맞물렸다
		local SETUP = {
			iron = { { "King", 6, 0 }, { "Rook", 5, 0 }, { "Rook", 0, 0 }, { "Queen", 3, 1 }, { "Bishop", 2, 3 }, { "Bishop", 6, 3 },
				{ "Knight", 5, 2 }, { "Knight", 2, 2 }, { "Pawn", 0, 1 }, { "Pawn", 1, 1 }, { "Pawn", 3, 3 }, { "Pawn", 4, 3 },
				{ "Pawn", 5, 1 }, { "Pawn", 6, 1 }, { "Pawn", 7, 2 } },
			brass = { { "King", 1, 7 }, { "Rook", 2, 7 }, { "Rook", 7, 7 }, { "Queen", 4, 6 }, { "Bishop", 2, 6 }, { "Bishop", 3, 5 },
				{ "Knight", 5, 5 }, { "Knight", 6, 4 }, { "Pawn", 0, 6 }, { "Pawn", 1, 6 }, { "Pawn", 3, 4 }, { "Pawn", 4, 4 },
				{ "Pawn", 6, 6 }, { "Pawn", 7, 5 } },
		}
		local taken = {}
		for side, list in pairs(SETUP) do
			for _, pc in ipairs(list) do
				local key = pc[2] .. "," .. pc[3]
				assert(not taken[key], "체스 칸 겹침 " .. key)
				taken[key] = true
				local x, z = sq(pc[2], pc[3])
				piece(pc[1], x, 3.22, z, side)
			end
		end
		-- 잡힌 기물은 탁자 가장자리(윗면 y 3)에
		for _, pc in ipairs({ { "Pawn", 7.2, -1.2, "brass" }, { "Knight", 7.2, 0.4, "brass" }, { "Pawn", -7.2, 5.2, "iron" },
			{ "Bishop", -7.2, 3.6, "iron" } }) do
			piece(pc[1], pc[2], 3.0, pc[3], pc[4], 90)
		end
		-- 지휘관 자리
		B("Dais", 0, 0.5, 12.5, 10, 1, 6, "stone")
		B("ChairSeat", 0, 2.4, 13.2, 4, 0.8, 3.2, "timber")
		B("ChairBack", 0, 5, 14.6, 4, 7, 0.8, "timber")
		B("Cushion", 0, 2.9, 13.2, 3.4, 0.3, 2.8, "banner")
		for _, x in ipairs({ -1.8, 1.8 }) do
			B("Finial", x, 8.8, 14.6, 0.6, 0.6, 0.6, "brass", { ball = true })
		end
		-- 영사기. 비숍이 기록을 찍어 돌리는 기계. 오른쪽 벽 막에 비춘다
		-- 막은 오른벽 가운데 칸(기둥 z ±4 사이)
		-- 영사기(키트 틀, 옛 영화 영사기 꼴). 렌즈(모델 앞 -Z)가 오른벽 막(+X)을 본다. 렌즈 끝은 모델 기준 (0, 5.95, -3.25)
		local proj = prop("Film_Projector", O, f, -15, 0, 0, -90)
		local tip = proj:GetPivot():PointToWorldSpace(Vector3.new(0, 5.95, -3.25))
		local screenAt = O + Vector3.new(21.7, 9, 0)
		local lens = part("LensLight", CFrame.lookAt(tip, screenAt), Vector3.new(0.3, 0.3, 0.3), IC.glass, f)
		lens.Transparency, lens.CanCollide, lens.CanQuery = 1, false, false
		local sp = Instance.new("SpotLight")
		sp.Face, sp.Angle, sp.Range, sp.Brightness, sp.Color, sp.Shadows = Enum.NormalId.Front, 22, 45, 3, RGB(255, 245, 215), true
		sp.Parent = lens
		B("Screen", 21.85, 9, 0, 0.2, 5.4, 6.2, "paper")
		local glow = B("ScreenGlow", 21.7, 9, 0, 0.1, 4.6, 5.4, "screen", { tr = 0.35 })
		local a0 = Instance.new("Attachment")
		a0.Parent = lens
		local a1 = Instance.new("Attachment")
		a1.Parent = glow
		local ray = Instance.new("Beam")
		ray.Name = "ProjectorLight"
		ray.Attachment0, ray.Attachment1 = a0, a1
		ray.Color = ColorSequence.new(RGB(255, 245, 215))
		ray.Transparency = NumberSequence.new(0.78, 0.93)
		ray.Width0, ray.Width1 = 1.0, 4.6
		ray.LightEmission = 1
		ray.FaceCamera = true
		ray.Segments = 1
		ray.Parent = lens
		-- 지도는 왼벽 가운데 칸, 총걸이는 왼벽 뒤 끝 칸(기둥 z 12 와 뒷벽 사이)
		B("MapFrame", -21.85, 10, 0, 0.3, 5.6, 6.2, "iron")
		B("Map", -21.65, 10, 0, 0.1, 5, 5.6, "paper")
		for i, p in ipairs({ { 11, -1 }, { 8.6, 1.4 }, { 10.2, 2.1 } }) do
			B("Pin_" .. i, -21.55, p[1], p[2], 0.2, 0.4, 0.4, "core")
		end
		for k = 0, 4 do
			B("RackRifle_" .. k, -21.5, 3.2, 13.3 + k * 0.6, 0.3, 5, 0.3, "iron", { rot = { 0, 0, 8 } })
			B("RackStock_" .. k, -21.1, 0.95, 13.3 + k * 0.6, 0.5, 1.8, 0.5, "wood", { rot = { 0, 0, 8 } })
		end
		-- 샹들리에
		for k = 0, 7 do
			local a = k * math.pi / 4
			B("Chand_" .. k, 3.5 * math.cos(a), 16, 2 + 3.5 * math.sin(a), 2.8, 0.3, 0.3, "iron", { rot = { 0, -math.deg(a) + 90, 0 } })
			if k % 2 == 0 then
				B("Bulb_" .. k, 3.5 * math.cos(a), 15.4, 2 + 3.5 * math.sin(a), 0.8, 0.8, 0.8, "glow")
			end
		end
		B("ChandHub", 0, 16, 2, 0.8, 0.8, 0.8, "brass", { light = { 34, 1.5 } })
		B("ChandChain", 0, 18, 2, 0.2, 4, 0.2, "iron")
		exitDoor(B, "Figuren", 32, 5, 9, "iron")
	end
	task.wait()

	--==================================================================== 6. 문
	local TITLES = { Frostig = "프로스티히 공방", Zapfen = "차펜 공방", Sel = "설 공방 (폐허)", Figuren = "기물군 본부" }
	local nDoors = 0
	for tag, d in pairs(D.DOORS) do
		local m = assert(tagged[tag], "문을 달 건물이 없다: " .. tag)
		local id, dx, dz, dw = d[1], d[2], d[3], d[4]
		local pv = m:GetPivot()
		local front = pv.LookVector
		local base = pv:PointToWorldSpace(Vector3.new(dx, 0, dz))
		local door = part("Door_" .. id, CFrame.lookAt(base + front * 0.9 + Vector3.new(0, 4.5, 0), base + front * 2 + Vector3.new(0, 4.5, 0)),
			Vector3.new(dw, 8, 1), C.iron, folder("문"))
		door.Transparency = 1
		door.CanCollide = false
		door:SetAttribute("InteriorId", id)
		local ret = base + front * 7
		local gy = assert(groundY(ret.X, ret.Z), id .. " 문 앞에 땅이 없다")
		door:SetAttribute("ReturnPos", Vector3.new(ret.X, gy + 3.2, ret.Z))
		door:SetAttribute("ReturnLook", front)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "들어가기"
		pr.ObjectText = TITLES[id]
		pr.HoldDuration = 0.25
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr.Parent = door
		CS:AddTag(door, "SnowDoor")
		nDoors += 1
	end

	--==================================================================== 7. 순간이동 스크립트
	do
		local SSS = game:GetService("ServerScriptService")
		local oldScript = SSS:FindFirstChild("SnowInteriors")
		if oldScript then
			oldScript:Destroy()
		end
		assert(#SCRIPT_SOURCE > 500, "SnowInteriors 소스가 비었다")
		local s = Instance.new("Script")
		s.Name = "SnowInteriors"
		s.Source = SCRIPT_SOURCE
		s.Parent = SSS
	end

	do
		local gs = Instance.new("Script")
		gs.Name = "SnowGearSpin"
		gs.RunContext = Enum.RunContext.Client
		gs.Source = GEAR_SCRIPT
		gs.Parent = city
	end

	--==================================================================== 8. 검사
	local counts = {}
	for _, e in ipairs(placed) do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local line = {}
	for _, k in ipairs(keys) do
		line[#line + 1] = k .. " " .. counts[k]
	end
	say("%s", table.concat(line, ", "))
	say("모델 %d, 받침돌 %d 개, 가장 큰 땅 높이차 %.2f, 옮긴 설원 지물 %d", #placed, foundations, maxGap, moved)
	-- 문과 방 짝
	local ids = {}
	for _, tag in ipairs({ "SnowDoor", "SnowArrive", "SnowExit" }) do
		for _, inst in ipairs(CS:GetTagged(tag)) do
			if inst:IsDescendantOf(city) then
				local id = inst:GetAttribute("InteriorId")
				ids[id] = (ids[id] or "") .. tag:sub(5, 5)
			end
		end
	end
	for id, s in pairs(ids) do
		assert(#s == 3, "짝이 안 맞는 방 " .. id .. " (" .. s .. ")")
	end
	say("문 %d, 방 %d", nDoors, roomCount)
	say("톱니 %d (도는 것 %d), 밸브 %d, 압력계 %d, 김 새는 이음 %d, 모음통 %d", nGear, #CS:GetTagged("SnowGear"), nValve, nGauge, nLeak, nJunction)
	-- 설원 나무는 그대로인가
	say("설림 나무 %d 그루 그대로", #Z["설림"]:GetChildren())
	local n = 0
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	say("파트 합계 %d", n)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowcity", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
