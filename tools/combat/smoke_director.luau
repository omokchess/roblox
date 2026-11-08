--[[
	smoke_director.luau — 스튜디오 없이 전투 연출 코드를 **끝까지 돌려** 실행 오류를 잡는다. (2026-09-28)

	@lune/roblox 로 스튜디오와 같은 인스턴스 트리를 짓고(tools/sync.json 을 따름), 빠진 엔진 기능
	(Model:PivotTo, ParticleEmitter:Emit, RunService 신호, TweenService, Debris …)을 흉내 낸 뒤
	가짜 R6 캐릭터와 슬라임으로 9직업의 모든 동작을 재생한다. 시간은 가짜 시계로 흘린다
	(os.clock · task.wait · task.delay 가 모두 이 시계를 따른다) — 그래서 몇 초 만에 끝난다.
	화면을 그리지는 않는다. 확인하는 것은 "오류 없이 끝까지 가는가"와 "연출이 끝나는가(멈춰 턴이 막히지 않는가)".

	돌리는 법: python tools/studio_sync.py && lune run tools/combat/smoke_director.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local ApiCheck = require("../roblox_api") -- 로블록스 공식 API 목록 대조(2026-11-07)

local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3

--=== 가짜 시계와 작업 예약 ===--
local now = 0
local queue: { { at: number, co: thread, args: { any } } } = {}

local function schedule(at: number, co: thread, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end

local failures: { string } = {}
local function resume(co: thread, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(failures, "예약 작업 오류: " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end

local fakeTask = {}
function fakeTask.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
function fakeTask.defer(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	schedule(now, co, ...)
	return co
end
function fakeTask.delay(t, f, ...)
	local co = coroutine.create(f)
	schedule(now + (t or 0), co, ...)
	return co
end
function fakeTask.wait(t)
	local start = now
	schedule(now + math.max(t or 0, 1 / 60), coroutine.running())
	coroutine.yield()
	return now - start
end
local function runDue()
	local i = 1
	while i <= #queue do
		local item = queue[i]
		if item.at <= now + 1e-9 then
			table.remove(queue, i)
			resume(item.co, table.unpack(item.args, 1, item.args.n))
		else
			i += 1
		end
	end
end
local fakeOs = setmetatable({ clock = function()
	return now
end }, { __index = os })

--=== 신호 ===--
local function Signal()
	local list = {}
	local sig = {}
	function sig:Connect(fn)
		local c = { fn = fn, Connected = true }
		function c:Disconnect()
			c.Connected = false
		end
		table.insert(list, c)
		return c
	end
	function sig:Fire(...)
		for _, c in table.clone(list) do
			if c.Connected then
				c.fn(...)
			end
		end
	end
	return sig
end
local RenderStepped, PreSimulation, Heartbeat = Signal(), Signal(), Signal()

--=== 엔진 기능 흉내 ===--
--[[
	Lune 은 반사 데이터에 있는 속성(Position·WorldPosition 등)을 덮어쓸 수 없고 기본값도 비어 있다.
	그래서 물건을 만들 때 기본값을 채운다(값이 CFrame 을 따라가지는 않는다 — 점검은 "오류 없이 끝나는가"만 본다).
]]
local function fillDefaults(inst)
	if inst:IsA("BasePart") then
		inst.Position = Vector3.new(0, 0, 0)
	elseif inst:IsA("Attachment") then
		inst.Position = Vector3.new(0, 0, 0)
		inst.WorldPosition = Vector3.new(0, 0, 0)
	elseif inst:IsA("LocalScript") or inst:IsA("Script") then
		inst.Enabled = true
	end
	return inst
end
local FakeInstance = { new = function(class, parent)
	ApiCheck.checkClass(class)
	local inst = fillDefaults(Instance.new(class))
	if parent then
		inst.Parent = parent
	end
	return inst
end }
local function pivotOf(m)
	if m.PrimaryPart then
		return m.PrimaryPart.CFrame
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(m, cf)
	local delta = cf * pivotOf(m):Inverse()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementProperty("Animator", "AnimationPlayed", function()
	return Signal()
end)
roblox.implementMethod("Animator", "GetPlayingAnimationTracks", function()
	return {}
end)
roblox.implementMethod("Debris", "AddItem", function(_, item, t)
	fakeTask.delay(t or 10, function()
		item:Destroy()
	end)
end)
roblox.implementMethod("TweenService", "Create", function()
	return { Play = function() end, Cancel = function() end }
end)
roblox.implementMethod("RunService", "IsStudio", function()
	return true
end)
roblox.implementProperty("RunService", "RenderStepped", function()
	return RenderStepped
end)
roblox.implementProperty("RunService", "PreSimulation", function()
	return PreSimulation
end)
roblox.implementProperty("RunService", "Heartbeat", function()
	return Heartbeat
end)

local fakeRandom = {}
function fakeRandom.new()
	local r = {}
	function r:NextNumber(a, b)
		a, b = a or 0, b or 1
		return a + math.random() * (b - a)
	end
	function r:NextInteger(a, b)
		return math.random(a, b)
	end
	return r
end
local fakeTweenInfo = { new = function(...)
	return { ... }
end }

--=== 스튜디오와 같은 트리 ===--
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local sync = serde.decode("json", fs.readFile("tools/sync.json"))
for _, item in sync do
	local node = game
	for i, name in item.path do
		local child = node:FindFirstChild(name)
		if i == 1 then
			child = game:GetService(name)
		elseif not child then
			local class = if i == #item.path then item.class elseif i > item.base then (item.chain[i - item.base] or "Folder") else "Folder"
			child = Instance.new(class)
			child.Name = name
			child.Parent = node
		end
		node = child
	end
	node:SetAttribute("LuneFile", item.file)
end

local cache = {}
local function fakeRequire(target)
	if typeof(target) ~= "Instance" then
		return require(target)
	end
	if cache[target] ~= nil then
		return cache[target]
	end
	local file = target:GetAttribute("LuneFile")
	assert(file, "파일이 없는 모듈: " .. target:GetFullName())
	local env = setmetatable({
		script = target,
		require = fakeRequire,
		game = game,
		workspace = workspace,
		task = fakeTask,
		os = fakeOs,
		time = function()
			return now
		end,
		Random = fakeRandom,
		TweenInfo = fakeTweenInfo,
		Instance = FakeInstance,
		CFrame = CFrame,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		warn = function(...)
			local parts = {}
			for _, v in table.pack(...) do
				table.insert(parts, tostring(v))
			end
			table.insert(failures, "warn: " .. table.concat(parts, " "))
		end,
	}, { __index = _G })
	ApiCheck.apply(env, roblox) -- Enum·NumberRange·시퀀스를 공식 API 검사판으로 덮는다
	local fn = luau.load(luau.compile(ApiCheck.rewrite(fs.readFile(file))), { debugName = file, environment = env })
	local result = fn()
	cache[target] = result
	return result
end

--=== 가짜 R6 캐릭터 ===--
local function part(name, size, parent)
	local p = fillDefaults(Instance.new("Part"))
	p.Name = name
	p.Size = size
	p.Parent = parent
	return p
end
local function motor(name, p0, p1, c0, c1, parent)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1, m.C0, m.C1 = p0, p1, c0, c1
	m.Parent = parent
	return m
end
local function r6(): any
	local char = Instance.new("Model")
	char.Name = "Tester"
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), char)
	local torso = part("Torso", Vector3.new(2, 2, 1), char)
	local head = part("Head", Vector3.new(2, 1, 1), char)
	local ra = part("Right Arm", Vector3.new(1, 2, 1), char)
	local la = part("Left Arm", Vector3.new(1, 2, 1), char)
	local rl = part("Right Leg", Vector3.new(1, 2, 1), char)
	local ll = part("Left Leg", Vector3.new(1, 2, 1), char)
	char.PrimaryPart = hrp
	local RJ = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", hrp, torso, RJ, RJ, hrp)
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), torso)
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), torso)
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), torso)
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), torso)
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), torso)
	local hum = Instance.new("Humanoid")
	hum.Parent = char
	Instance.new("Animator").Parent = hum
	local animate = Instance.new("LocalScript")
	animate.Name = "Animate"
	animate.Enabled = true
	animate.Parent = char
	char.Parent = workspace
	return char
end

--=== 실행 ===--
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
-- 우주 레이어(Combat/SpaceLayer)는 카메라 화면 투영(ViewportSize · WorldToViewportPoint)이 필요해 Lune 에선 빈 것으로 대신한다
cache[client.Combat.SpaceLayer] = {
	Add = function()
		return function() end
	end,
}
local CombatDirector = fakeRequire(client.Combat.CombatDirector)
local BattleSkills = fakeRequire(game:GetService("ReplicatedStorage").Shared.BattleSkills)
local WeaponDefinitions = fakeRequire(game:GetService("ReplicatedStorage").Shared.Combat.WeaponDefinitions)

local function step(seconds: number)
	local frames = math.ceil(seconds * 60)
	for _ = 1, frames do
		now += 1 / 60
		local ok, err = pcall(function()
			RenderStepped:Fire(1 / 60)
			PreSimulation:Fire(1 / 60)
			Heartbeat:Fire(1 / 60)
		end)
		if not ok then
			table.insert(failures, "프레임 오류: " .. tostring(err))
			return false
		end
		runDue()
	end
	return true
end

-- 연출이 한가해질 때까지(최대 limit 초). 안 끝나면 실패로 적는다
local function settle(director, what: string, limit: number)
	local t0 = now
	repeat
		if not step(0.1) then
			table.insert(failures, what .. " 중에 멈춤")
			return
		end
	until not director:IsBusy() or now - t0 > limit
	if director:IsBusy() then
		table.insert(failures, string.format("%s: %.1f초가 지나도 연출이 안 끝남", what, limit))
	end
end

local function try(what: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		table.insert(failures, what .. ": " .. tostring(err))
	end
end

local folder = Instance.new("Folder")
folder.Parent = workspace
local char = r6()
local allyHome = CFrame.lookAt(Vector3.new(0, 3.4, 0), Vector3.new(1, 3.4, 0))
local slimeHome = CFrame.lookAt(Vector3.new(10, 0, 0), Vector3.new(0, 0, 0))
local director = CombatDirector.new()
director:SetCamera(CFrame.new())

local CLASSES = { "Duelist", "Musician", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker", "Attuner", "AzureBlade" }
local played = 0
for _, classId in CLASSES do
	local before = #failures
	try(classId .. " 붙이기", function()
		director:AddHumanoid("player", char, classId, allyHome, WeaponDefinitions.ForClass(classId).Id)
		director:SetHome("player", allyHome, true)
		director:AddSlime("slime", folder, slimeHome)
	end)
	step(1)
	try(classId .. " 들기", function()
		director:Grab("player")
	end)
	for i = 1, 30 do
		director:HoldAt("player", allyHome.Position + Vector3.new(0, 2.2, i * 0.05))
		step(1 / 30)
	end
	try(classId .. " 내려놓기", function()
		director:Drop("player", allyHome)
	end)
	settle(director, classId .. " Drop", 4)
	for _, grade in { "Fail", "Partial", "Success" } do
		for _, attack in { "SlimeTackle", "SlimeSpit" } do
			try(classId .. " 적 공격 " .. grade, function()
				director:Windup("slime", true)
				step(0.3)
				local play = director:PlayEnemyAttack("slime", attack, "player", grade)
				step(0.1)
				play:SetResult({ Hits = { { { Id = "player", Damage = if grade == "Success" then 0 else 7, Grade = grade } } }, Reflect = 3 })
			end)
			settle(director, classId .. " 적 공격 " .. attack .. " " .. grade, 5)
			played += 1
		end
	end
	local skills = {}
	for _, s in BattleSkills.ForClass(classId) do
		table.insert(skills, s.Id)
	end
	for _, s in BattleSkills.Upgrades() do
		if s.ClassId == classId then
			table.insert(skills, s.Id)
		end
	end
	if classId == "Quasar" then
		table.insert(skills, "CollapseCharge")
	end
	table.insert(skills, "Guard")
	table.insert(skills, "Meditate")
	for _, skillId in skills do
		try(classId .. " 스킬 " .. skillId, function()
			local play = director:PlaySkill("player", skillId, { { "slime" }, { "slime" }, { "slime" } })
			assert(play, "재생이 안 만들어짐")
			step(0.15)
			play:SetResult({ Hits = { { { Id = "slime", Damage = 12 } }, { { Id = "slime", Damage = 8 } } } })
			-- 돌진해 간 자리에 모션 도중엔 머문다(2026-10-02 고침: 전엔 돌진이 끝나자마자 칸으로 미끄러져 돌아왔다).
			-- 못질: 0.1 대상 앞으로 돌진(0.22초) → 0.9 집으로. 0.6 에는 아직 대상 앞이어야 한다
			if classId == "WallPilgrim" and skillId == "Nailing" then
				step(0.45)
				local a = director.Actors.player
				local away = (a.Pos.Position - a.Home.Position).Magnitude
				assert(away > 2, string.format("못질 도중(0.6초)에 이미 칸으로 돌아옴: 집에서 %.2f", away))
			end
			-- 결투사 앞뒤관통(2026-10-02 사용자): 첫 찌르기는 대상 너머 멀리, 둘째는 등 뒤에서 다시 꿰뚫고 앞(아군 쪽)으로 지나간다
			if classId == "Duelist" and skillId == "FrontBackPierce" then
				local a, foe = director.Actors.player, director.Actors.slime
				local fwd = a.Home.LookVector
				step(0.6)
				local first = (a.Pos.Position - foe.Pos.Position):Dot(fwd)
				assert(first > 5, string.format("앞뒤관통 첫 찌르기가 대상을 충분히 못 지나감: %.2f", first))
				step(1.05)
				local second = (a.Pos.Position - foe.Pos.Position):Dot(fwd)
				assert(second < -3, string.format("앞뒤관통 둘째 찌르기가 대상을 꿰뚫고 앞으로 못 지나감: %.2f", second))
			end
			-- 결투사 강화 스킬(2026-10-02 사용자): 0.67 에 적 진영 맨 끝 줄 너머까지 꿰뚫고 지나간다(돌진 to = "Far")
			if classId == "Duelist" and skillId == "PointBlank" then
				local a = director.Actors.player
				local fwd = a.Home.LookVector
				local far = a.Home.Position + fwd * 30
				director.FarEnd = far
				-- 0.71 타격 정지(0.14초)가 돌진을 잠깐 멈추므로 넉넉히 지나서 본다(1.5 에 집으로)
				step(1.0)
				local past = (a.Pos.Position - far):Dot(fwd)
				director.FarEnd = nil
				assert(past > 2, string.format("검 끝을 쏘아라가 적 진영 끝을 못 넘음: 끝 줄에서 %.2f", past))
			end
		end)
		-- 가장 긴 연출(조율자 셉텐트리오네스 컷신 10.8초)까지 기다린다
		settle(director, classId .. " 스킬 " .. skillId, 12)
		played += 1
	end
	-- 쓰러짐
	try(classId .. " 슬라임 쓰러짐", function()
		director:Kill("slime")
	end)
	settle(director, classId .. " 쓰러짐", 4)
	if director:Has("slime") then
		table.insert(failures, classId .. ": 쓰러진 슬라임이 치워지지 않음")
	end
	print(string.format("%-12s %s", classId, if #failures == before then "통과" else "오류 " .. (#failures - before)))
end

--=== 1b단계: 보스 디버그(부위 넷) ===--
do
	local before = #failures
	local bossHome = CFrame.lookAt(Vector3.new(20, 0, 0), Vector3.new(0, 0, 0))
	local SKILLS = { Head = { "BreakpointBeam" }, DeleteArm = { "DeleteCells" }, PatchArm = { "ForcedPatch" }, Core = { "CoreDump", "NullPointer", "MemoryLeak" } }
	try("보스 붙이기", function()
		director:AddHumanoid("player", char, "Duelist", allyHome, WeaponDefinitions.ForClass("Duelist").Id)
		director:SetHome("player", allyHome, true)
		for key in SKILLS do
			director:AddEnemy("boss_" .. key, key, folder, bossHome)
		end
	end)
	step(1)
	for key, list in SKILLS do
		for _, skillId in list do
			for _, grade in { "Fail", "Success" } do
				try("보스 " .. skillId .. " " .. grade, function()
					director:Windup("boss_" .. key, true)
					step(0.3)
					local play = director:PlayEnemyAttack("boss_" .. key, skillId, "player", grade)
					assert(play, "재생이 안 만들어짐")
					step(0.1)
					play:SetResult({ Hits = { { { Id = "player", Damage = if grade == "Success" then 0 else 9, Grade = grade } } } })
				end)
				settle(director, "보스 " .. skillId .. " " .. grade, 5)
				played += 1
			end
		end
	end
	try("보스 패치 적용", function()
		assert(director:PlaySkill("boss_PatchArm", "PatchCells", { {} }), "패치 적용 재생이 안 만들어짐")
	end)
	settle(director, "보스 패치 적용", 4)
	try("보스 맞음", function()
		local play = director:PlaySkill("player", "FrontBackPierce", { { "boss_Head", "boss_Core" } })
		step(0.15)
		if play then
			play:SetResult({ Hits = { { { Id = "boss_Head", Damage = 120000 }, { Id = "boss_Core", Damage = 90000 } } } })
		end
	end)
	settle(director, "보스 맞음", 6)
	for key in SKILLS do
		try("보스 부위 부서짐 " .. key, function()
			director:Kill("boss_" .. key)
		end)
	end
	settle(director, "보스 부서짐", 5)
	for key in SKILLS do
		if director:Has("boss_" .. key) then
			table.insert(failures, "보스: 부서진 " .. key .. " 가 치워지지 않음")
		end
	end
	print(string.format("%-12s %s", "보스 디버그", if #failures == before then "통과" else "오류 " .. (#failures - before)))
end

--=== 2단계: 서버 규칙 + 전투 화면 연결 ===--
--[[
	진짜 GridBattle 로 층 전투를 만들고, 전투 화면(BattleClient)의 새 연결 함수들을
	가짜 self 로 부른다: 스냅샷 반영(_renderUnits) → 대상 예측(_predictTargets) → 스킬 재생 →
	서버 판정 → 사건 붙이기(_consumeEvents) → 쓰러짐. 적 예고가 있으면 적 공격 → 회피 판정도.
	서버 사건의 모양과 연출이 기대하는 모양이 맞는지를 여기서 본다.
]]
local Shared = game:GetService("ReplicatedStorage").Shared
local GridBattle = fakeRequire(Shared.GridBattle)
local BattleClient = fakeRequire(client.BattleClient)
local BattleArena = fakeRequire(Shared.BattleArena)

-- 지역 안개(RegionAtmosphere): 섬 한가운데는 그 지역, 먼 바다는 바다
do
	local RegionAtmosphere = fakeRequire(client.RegionAtmosphere)
	for _, case in { { 2360, 1080, "늪지대" }, { 6000, 0, "바다" }, { -4000, -2620, "설원" }, { -1260, -2880, "화산" }, { 300, 600, "평원" }, { -1500, 500, "숲" }, { 2700, -800, "사막" }, { 400, -1500, "탑의성역" }, { -2660, -1280, "오염지대" }, { 1260, -3120, "광산" } } do
		local got = RegionAtmosphere.RegionAt(case[1], case[2])
		assert(got == case[3], string.format("지역 (%d,%d) = %s, 기대 %s", case[1], case[2], got, case[3]))
		assert(RegionAtmosphere.MOOD[got], "지역 분위기 없음 " .. got)
	end
end

-- 스킬 설명 말풍선(BattleHud): 글머리·들여쓰기 쪼개기와 키워드·숫자 꾸미기
do
	local BattleHud = fakeRequire(client.BattleHud)
	local rows = BattleHud.ParseDescription("- 약재 1 소모\n  - [원액] 1 획득.\n그냥 글")
	assert(#rows == 3, "설명 줄 수")
	assert(rows[1].Head and rows[1].Bullet and rows[1].Text == "약재 1 소모", "소제목 줄")
	assert(rows[2].Level == 1 and not rows[2].Head, "들여쓴 줄")
	assert(not rows[3].Bullet and rows[3].Level == 0, "글머리 없는 줄")
	local marked = BattleHud.Markup("[원액] +10% <b>")
	assert(not marked:find("%[") and marked:find("원액", 1, true), "키워드 괄호: " .. marked)
	assert(marked:find("<b>+10%</b>", 1, true) and marked:find("&lt;b&gt;", 1, true), "숫자·이스케이프: " .. marked)
end

local turnsPlayed, kills, numbersSeen = 0, 0, 0
for _, classId in CLASSES do
	local before = #failures
	try(classId .. " 통합", function()
		local state = GridBattle.New(1, "시험", 140, 12, classId)
		local seed = 0
		local function rng()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local self = setmetatable({
			director = director,
			layout = BattleArena.NewLayout(CFrame.new(0, 0, 0)),
			folder = folder,
			player = { Character = char },
			snapshot = GridBattle.Snapshot(state),
			lastEventSeq = 0,
			pendingSkillPlay = nil,
			pendingAttackPlay = nil,
			selectedSkill = 1,
		}, { __index = BattleClient })
		self.allySkills = self.snapshot.AllySkills
		self:_renderUnits()
		-- 아군을 첫 적과 같은 줄로
		local foe = GridBattle.AliveEnemies(state)[1]
		local cell = GridBattle.CellOf(state, foe.Id)
		GridBattle.MoveAlly(state, 1, cell.Y)
		self.snapshot = GridBattle.Snapshot(state)
		self:_renderUnits()
		step(0.5)
		for turn = 1, 6 do
			if state.Outcome ~= "Ongoing" then
				break
			end
			-- 쓸 수 있는 첫 공격 스킬(재사용 대기 아닌 것)
			local chosen
			for _, sk in self.snapshot.AllySkills do
				if (sk.CooldownLeft or 0) <= 0 and sk.Damage > 0 then
					chosen = sk
					break
				end
			end
			chosen = chosen or self.snapshot.AllySkills[1]
			self.pendingSkillPlay = director:PlaySkill("player", chosen.Id, self:_predictTargets(chosen.Id))
			step(0.1)
			GridBattle.ResolveSkill(state, chosen.Index, "Success", rng, chosen.Id)
			self.snapshot = GridBattle.Snapshot(state)
			self:_consumeEvents(self.snapshot)
			self:_renderUnits()
			settle(director, classId .. " 통합 스킬 " .. chosen.Id, 8)
			-- 적 차례
			for _, enemy in GridBattle.PlannedThreats(state) do
				local skill = BattleSkills.ByIndex(BattleSkills.Enemy(), enemy.SkillIndex)
				director:Windup(enemy.Id, true)
				step(0.3)
				local grade = ({ "Success", "Partial", "Fail" })[turn % 3 + 1]
				self.pendingAttackPlay = director:PlayEnemyAttack(enemy.Id, skill.Id, "player", grade)
				step(0.1)
				GridBattle.ResolveDodge(state, enemy.Id, grade)
				self.snapshot = GridBattle.Snapshot(state)
				self:_consumeEvents(self.snapshot)
				self:_renderUnits()
				settle(director, classId .. " 통합 적 공격 " .. skill.Id, 8)
			end
			GridBattle.EndTurn(state)
			if state.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(state, rng)
			end
			self.snapshot = GridBattle.Snapshot(state)
			self:_consumeEvents(self.snapshot)
			self:_renderUnits()
			self.allySkills = self.snapshot.AllySkills
			settle(director, classId .. " 통합 턴 끝", 4)
			turnsPlayed += 1
		end
		for _, ev in state.Events do
			for _, group in ev.Hits do
				numbersSeen += #group
				for _, h in group do
					if h.Killed then
						kills += 1
					end
				end
			end
		end
		-- 죽은 적은 연출에서 치워져야 한다
		for id, unit in state.Units do
			if unit.Side == "Enemy" and not unit.Alive and director:Has(id) then
				table.insert(failures, classId .. " 통합: 쓰러진 " .. id .. " 가 남아 있음")
			end
		end
		for id in director.Actors do
			if id ~= "player" then
				director:Remove(id)
			end
		end
	end)
	print(string.format("%-12s 통합 %s", classId, if #failures == before then "통과" else "오류 " .. (#failures - before)))
end
print(string.format("통합: 턴 %d, 피해 기록 %d, 처치 %d", turnsPlayed, numbersSeen, kills))

-- 보스 디버그 통합: 판 칠하기(지운 칸·버프/버그·예고)·부위 몸·부위 공격 연출이 서버 스냅샷과 맞물리는지
do
	local before = #failures
	try("보스 통합", function()
		local BattleStage = fakeRequire(client.BattleStage)
		local state = GridBattle.New(1, "시험", 5000, 20, "Duelist", 5, nil, {}, { Name = "보스", Enemies = { "Debug" }, HealthScale = 0.012, PowerScale = 0.15 })
		local seed = 3
		local function rng()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local layout = BattleArena.NewLayout(CFrame.new(0, 0, 0))
		layout.FlatY = 0
		local tiles = BattleStage.Build(folder, layout, nil, 6, 3, nil)
		local self = setmetatable({
			active = true,
			director = director,
			layout = layout,
			folder = folder,
			tiles = tiles,
			player = { Character = char },
			snapshot = GridBattle.Snapshot(state),
			lastEventSeq = 0,
			selectedSkill = 1,
			skillButtons = {},
			goneCells = {},
			-- 판 층(2026-10-09 BattleClient: 기믹 · 공격 범위)
			layers = { Gimmick = true, Range = true },
		}, { __index = BattleClient })
		GridBattle.EnemyPlan(state, rng)
		for turn = 1, 12 do
			if state.Outcome ~= "Ongoing" then
				break
			end
			self.snapshot = GridBattle.Snapshot(state)
			self.allySkills = self.snapshot.AllySkills
			self:_bossBoard(self.snapshot)
			self:_renderUnits()
			self:_paintTiles()
			step(0.2)
			local chosen = self.snapshot.AllySkills[1]
			self.pendingSkillPlay = director:PlaySkill("player", chosen.Id, self:_predictTargets(chosen.Id))
			step(0.1)
			GridBattle.ResolveSkill(state, chosen.Index, "Success", rng, chosen.Id)
			self.snapshot = GridBattle.Snapshot(state)
			self:_consumeEvents(self.snapshot)
			self:_renderUnits()
			settle(director, "보스 통합 스킬", 8)
			for _, enemy in GridBattle.PlannedThreats(state) do
				local skill = GridBattle.EnemySkill(enemy)
				director:Windup(enemy.Id, true)
				step(0.3)
				local grade = if turn % 2 == 0 then "Success" else "Fail"
				self.pendingAttackPlay = director:PlayEnemyAttack(enemy.Id, skill.Id, "player", grade)
				step(0.1)
				GridBattle.ResolveDodge(state, enemy.Id, grade)
				self.snapshot = GridBattle.Snapshot(state)
				self:_consumeEvents(self.snapshot)
				self:_renderUnits()
				settle(director, "보스 통합 적 공격 " .. skill.Id, 8)
			end
			GridBattle.EndTurn(state)
			if state.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(state, rng)
			end
		end
		-- 부위 몸이 네 개 다 나왔었는지(부서진 것은 치워짐)
		for id, unit in state.Units do
			if unit.Side == "Enemy" and unit.Alive and not director:Has(id) then
				table.insert(failures, "보스 통합: 살아 있는 " .. id .. " 의 몸이 없음")
			end
		end
		print(string.format("보스 통합: %s, %d턴", state.Outcome, state.Turn))
		for id in director.Actors do
			if id ~= "player" then
				director:Remove(id)
			end
		end
	end)
	print(string.format("%-12s %s", "보스 통합", if #failures == before then "통과" else "오류 " .. (#failures - before)))
end

-- 칼리스토 통합(2026-10-31): 사람 모양 적 몸(R6 + 의체)·칸 옮김·연타 예고(계획마다 한 번씩)·페이즈 넘김·장판이 연출과 맞물리는지
do
	local before = #failures
	try("칼리스토 통합", function()
		local BattleStage = fakeRequire(client.BattleStage)
		local state = GridBattle.New(1, "시험", 5000, 20, "Berserker", 5, nil, {}, { Name = "칼리스토", Enemies = { "Callisto" }, HealthScale = 0.002, PowerScale = 0.5 })
		local seed = 5
		local function rng()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local layout = BattleArena.NewLayout(CFrame.new(0, 0, 0))
		layout.FlatY = 0
		local tiles = BattleStage.Build(folder, layout, nil, 6, 3, nil)
		local self = setmetatable({
			active = true,
			director = director,
			layout = layout,
			folder = folder,
			tiles = tiles,
			player = { Character = char },
			snapshot = GridBattle.Snapshot(state),
			lastEventSeq = 0,
			selectedSkill = 1,
			skillButtons = {},
			goneCells = {},
			layers = { Gimmick = true, Range = true },
		}, { __index = BattleClient })
		director.AllyTiles = {}
		for y = 1, 3 do
			for x = 1, 6 do
				table.insert(director.AllyTiles, tiles.Ally[y][x])
			end
		end
		local seenSkills: { [string]: boolean } = {}
		local pages: { [number]: boolean } = {}
		local cutscenes: { [string]: boolean } = {}
		GridBattle.EnemyPlan(state, rng)
		for turn = 1, 80 do -- 2026-11-08 연타 스킬이 한 번이 되며 2페이즈가 길어져(성위·뭇별이 덜 쌓임) 40 → 80
			if state.Outcome ~= "Ongoing" then
				break
			end
			GridBattle.Ally(state).Health = GridBattle.Ally(state).MaxHealth
			self.snapshot = GridBattle.Snapshot(state)
			self.allySkills = self.snapshot.AllySkills
			self:_renderUnits()
			self:_paintTiles()
			self:_callistoField(self.snapshot)
			step(0.2)
			local chosen = self.snapshot.AllySkills[1]
			self.pendingSkillPlay = director:PlaySkill("player", chosen.Id, self:_predictTargets(chosen.Id))
			step(0.1)
			GridBattle.ResolveSkill(state, chosen.Index, "Success", rng, chosen.Id)
			self.snapshot = GridBattle.Snapshot(state)
			self:_consumeEvents(self.snapshot)
			self:_renderUnits()
			settle(director, "칼리스토 통합 스킬", 8)
			for _, t in GridBattle.PlannedThreatList(state) do
				local skill = GridBattle.EnemySkill(t.Unit, t.Index)
				seenSkills[skill.Id] = true
				local grade = if (turn + t.Index) % 3 == 0 then "Success" elseif (turn + t.Index) % 3 == 1 then "Partial" else "Fail"
				self.pendingAttackPlay = director:PlayEnemyAttack(t.Unit.Id, skill.Id, "player", grade)
				step(0.1)
				GridBattle.ResolveDodge(state, t.Unit.Id, grade :: any, t.Index)
				self.snapshot = GridBattle.Snapshot(state)
				self:_consumeEvents(self.snapshot)
				self:_renderUnits()
				settle(director, "칼리스토 통합 적 공격 " .. skill.Id, 8)
			end
			if state.Callisto then
				pages[state.Callisto.Page] = true
				-- 등장·2·3페이즈 컷신(왼발 → 칼날 시험 / 의수 휘두름 → 우주 머리·팔 / 옷이 사라지고 우리은하)과 그 뒤 모습도 돌려 본다
				local want = state.Callisto.Page
				if self.callistoShown ~= want and director:Has(state.Callisto.UnitId) then
					local skill = if not self.callistoShown then "CallistoIntro" elseif want >= 3 then "CallistoPhase3" else "CallistoPhase2"
					cutscenes[skill] = true
					director:PlaySkill(state.Callisto.UnitId, skill, { {} })
					settle(director, "칼리스토 컷신 " .. skill, 8)
					self.callistoShown = want
					self:_callistoLook(state.Callisto.UnitId)
				end
			end
			GridBattle.EndTurn(state)
			if state.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(state, rng)
			end
		end
		local cid = state.Callisto and state.Callisto.UnitId
		local unit = cid and state.Units[cid]
		if unit and unit.Alive and not director:Has(cid) then
			table.insert(failures, "칼리스토 통합: 살아 있는 칼리스토의 몸이 없음")
		end
		if not pages[2] or not pages[3] then
			table.insert(failures, "칼리스토 통합: 2·3페이즈까지 가지 못함")
		end
		for _, skill in { "CallistoIntro", "CallistoPhase2", "CallistoPhase3" } do
			if not cutscenes[skill] then
				table.insert(failures, "칼리스토 통합: 컷신을 틀지 못함 " .. skill)
			end
		end
		local names = {}
		for id in seenSkills do
			table.insert(names, id)
		end
		table.sort(names)
		print(string.format("칼리스토 통합: %s, %d턴, 쓴 스킬 %d — %s", state.Outcome, state.Turn, #names, table.concat(names, ",")))
		for id in director.Actors do
			if id ~= "player" then
				director:Remove(id)
			end
		end
	end)
	print(string.format("%-12s %s", "칼리스토 통합", if #failures == before then "통과" else "오류 " .. (#failures - before)))
end

-- 파티 통합(2026-11-08, 파티전투_사양.md): 유닛 셋 파티. 준비(자리 바꾸기 · 스킬 · 유도 · 칸 클릭) → 턴 시작 → 유닛 셋이 순서대로 연출 →
-- 적 행동(예고 칸 유닛만) → 다음 턴. 서버(BattleService)가 하는 일을 이 점검이 직접 한다 — 엔진 호출 순서와 스냅샷 모양은 같다.
-- 일부러 행동마다 스냅샷을 연달아 보내(연출을 기다리지 않고) 클라 대기열이 겹치지 않고 순서대로 트는지 본다.
do
	local before = #failures
	try("파티 통합", function()
		local BattleStage = fakeRequire(client.BattleStage)
		local PartyHud = fakeRequire(client.PartyHud)
		local function member(classId: string, x: number, y: number, health: number): any
			return { ClassId = classId, X = x, Y = y, Cards = {}, Name = classId, Health = health, Power = 14, Stamina = 200 }
		end
		-- 코스트 3 + 2 + 3 = 8
		local state = GridBattle.NewParty(1, {
			member("WallPilgrim", 6, 2, 600),
			member("Musician", 5, 2, 600),
			member("AzureBlade", 4, 2, 600),
		}, { Name = "파티 통합", Enemies = { "Slime", "Slime", "Slime" }, Cells = { { 1, 1 }, { 1, 2 }, { 1, 3 } }, HealthScale = 4, PowerScale = 0.4 })
		local seed = 11
		local function rng()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local layout = BattleArena.NewLayout(CFrame.new(0, 0, 0))
		layout.FlatY = 0
		local tiles = BattleStage.Build(folder, layout, nil, 6, 3, nil)
		local sent = {}
		local hudStub = setmetatable({}, {
			__index = function()
				return function() end
			end,
		})
		local gui = FakeInstance.new("ScreenGui")
		-- Lune 의 카메라에는 화면 크기 기본값이 없다(PartyHud 가 아래 판 배율을 잡을 때 읽는다)
		local camera = workspace.CurrentCamera
		if camera then
			camera.ViewportSize = roblox.Vector2.new(1280, 720)
		end
		local self: any
		self = setmetatable({
			active = true,
			director = director,
			layout = layout,
			folder = folder,
			tiles = tiles,
			hud = hudStub,
			player = { Character = char },
			Remotes = {
				GridAction = {
					FireServer = function(_, request)
						table.insert(sent, request)
					end,
				},
			},
			lastEventSeq = 0,
			selectedSkill = 1,
			goneCells = {},
			layers = { Gimmick = true, Range = true },
			hpShown = {},
			partyMode = true,
			partyQueue = {},
			partyGapUntil = 0,
			partyBusyShown = false,
			dolls = {},
		}, { __index = BattleClient })
		self.partyHud = PartyHud.new(gui, {
			Select = function(id)
				self.partySelected = id
				self:_refreshParty()
				self:_paintTiles()
			end,
			Choose = function(id, skillId)
				if self:_partyCanEdit() then
					self:_partySend({ Kind = "Choose", Id = id, SkillId = skillId })
				end
			end,
			Homing = function(id, on)
				if self:_partyCanEdit() then
					self:_partySend({ Kind = "Homing", Id = id, On = on })
				end
			end,
			Begin = function()
				if self:_partyCanEdit() then
					self:_partySend({ Kind = "BeginTurn" })
				end
			end,
			Hover = function(skillId)
				self.partyHover = skillId
				self:_paintTiles()
			end,
			TipSkill = function() end,
			TipEffect = function() end,
			HomingPick = function(id)
				self.partyPicking = id
				self:_refreshParty()
			end,
		})
		self.partyHud:SetActive(true)
		director.OnDamage = function(id: string, dmg: number)
			local unit = self.snapshot and self.snapshot.Units[id]
			local shown = self.hpShown[id]
			if unit and shown then
				self.hpShown[id] = math.max(unit.Health, shown - dmg)
			end
		end
		-- 어느 행동이 어떤 순서로 틀렸나
		local played = {}
		local inner = BattleClient._playPartyItem
		self._playPartyItem = function(this, item)
			table.insert(played, if item.Kind == "Volley" then "Enemy" else item.Event.Actor)
			inner(this, item)
		end

		local turning = false
		-- BattleService:_partyPreview 와 같다
		local function previewOf()
			local preview = {}
			for _, unit in GridBattle.Allies(state) do
				local ok, view = pcall(GridBattle.PreviewCells, state, unit.Id, unit.Chosen or GridBattle.BasicSkillId(state, unit.Id), nil)
				if ok and view then
					preview[unit.Id] = view
				end
			end
			return preview
		end
		local function publish()
			local snapshot = GridBattle.Snapshot(state)
			snapshot.PartyMode = true
			snapshot.Turning = turning
			snapshot.Preview = previewOf()
			snapshot.Threats = {}
			snapshot.AutoQte = "Off"
			self:_onGridState(snapshot)
		end
		-- 연출이 끝날 때까지(RenderStepped 연결이 없어 _pumpParty 와 미뤄 둔 그리기를 직접 돌린다)
		local function drain(what: string)
			local t0 = now
			repeat
				self:_pumpParty()
				if not step(0.1) then
					table.insert(failures, what .. " 중에 멈춤")
					return
				end
				if self.pendingRender and not self:_busy() then
					self.pendingRender = false
					self:_renderUnits()
					self:_paintTiles()
				end
			until not self:_busy() or now - t0 > 60
			self:_pumpParty() -- 한가해진 다음 프레임(치워진 배우의 인형 정리·화면 다시 그리기)
			if self:_busy() then
				table.insert(failures, string.format("%s: %.0f초가 지나도 연출이 안 끝남", what, now - t0))
			end
		end

		director:Remove("player")
		publish()
		drain("파티 시작")
		for _, id in { "player", "ally2", "ally3" } do
			assert(director:Has(id), "아군 인형이 안 섬: " .. id)
		end
		assert(self.dolls.ally2 and self.dolls.ally3, "직업 인형을 만들지 못함")
		assert(self.partyHud.panel.Visible, "준비 단계에 아래 판이 안 보임")
		assert(self.partyHud.strip.Visible, "위 순서 띠가 안 보임")
		-- 순번: 행 1순위(y) · 열 2순위(화면 왼쪽 x=6 먼저) — 셋 다 y=2 이니 x=6(player) → 5(ally2) → 4(ally3)
		assert(table.concat(PartyHud.OrderOf(self.snapshot), ",") == "player,ally2,ally3", "준비 순서 " .. table.concat(PartyHud.OrderOf(self.snapshot), ","))
		assert(tiles.Ally[2][6]:FindFirstChild("OrderMark"), "칸 위 순번 숫자가 없음")

		local expectedKills = 0
		local volleys = 0
		for turn = 1, 4 do
			if state.Outcome ~= "Ongoing" then
				break
			end
			table.clear(sent)
			-- 준비 1: 자리를 바꾼다(2턴 빈 칸으로 · 3턴 맞바꾸기) — 클라는 칸 클릭(끌기)을 Place 로 보낸다
			if turn == 2 then
				self.partyPress = { Cell = { X = 5, Y = 2 }, Id = "ally2" }
				self._partyCursorCell = function()
					return { X = 5, Y = 1 }, nil
				end
				self:_partyRelease()
				assert(#sent == 1 and sent[1].Kind == "Place" and sent[1].Id == "ally2" and sent[1].X == 5 and sent[1].Y == 1, "끌어 옮김이 Place 로 안 감")
				assert(GridBattle.PlaceUnit(state, "ally2", 5, 1), "빈 칸으로 옮기기")
			elseif turn == 3 then
				assert(GridBattle.PlaceUnit(state, "player", 4, 2), "맞바꾸기")
			end
			publish()
			drain("준비 " .. turn)
			-- 순번이 자리대로 다시 매겨졌나
			local order = PartyHud.OrderOf(self.snapshot)
			local want = GridBattle.ActionOrder(state)
			assert(table.concat(order, ",") == table.concat(want, ","), "순번이 엔진 순서와 다름: " .. table.concat(order, ","))
			for n, id in order do
				local unit = self.snapshot.Units[id]
				local mark = tiles.Ally[unit.Y][unit.X]:FindFirstChild("OrderMark")
				assert(mark and mark.Box.Text.Text == tostring(n), "순번 숫자 " .. id)
			end
			-- 준비 2: 스킬 고르기 · 유도 — 아래 판 버튼(클릭 표)을 눌러 서버 명령이 나가는지 본다
			self.partySelected = "ally2"
			self:_refreshParty()
			local skills = nil
			for _, m in self.snapshot.Party.Members do
				if m.Id == "ally2" then
					skills = m.Skills
				end
			end
			local pickable = nil
			for index, skill in skills do
				if (skill.CooldownLeft or 0) == 0 and not skill.Blocked and (pickable == nil or skill.Damage > 0) then
					pickable = { Index = index, Skill = skill }
					if skill.Damage > 0 then
						break
					end
				end
			end
			assert(pickable, "고를 스킬이 없음")
			table.clear(sent)
			self.partyHud.clicks["Slot" .. pickable.Index]()
			assert(#sent == 1 and sent[1].Kind == "Choose" and sent[1].SkillId == pickable.Skill.Id, "스킬 고르기가 Choose 로 안 감")
			assert(GridBattle.SetUnitSkill(state, "ally2", pickable.Skill.Id))
			local target = if state.Units.ally3.Alive then "ally3" else "ally2" -- 3턴에 ally3 를 쓰러뜨린다
			self.partySelected = target
			self:_refreshParty()
			-- 스킬에 마우스를 올리면 범위 미리보기(PreviewCells 와 같은 모양을 클라가 그린다)
			self.partyHud.hovers["Slot1"](true) -- 지금 고른 유닛의 첫 스킬
			assert(self.partyHover ~= nil, "마우스 올림이 미리보기로 안 감")
			self.partyHud.hovers["Slot1"](false)
			assert(self.partyHover == nil, "마우스 뗌이 미리보기를 안 지움")
			local wasHoming = state.Units[target].Homing == true
			-- 유도 칸은 늘 보인다. 붙어 있으면 누르면 떼고, 아니면 '적 고르기' → 적을 누르면 대상 적과 함께 붙는다
			assert(self.partyHud.clicks["HomingButton"], "유도 칸이 안 보임")
			table.clear(sent)
			self.partyHud.clicks["HomingButton"]()
			if wasHoming then
				assert(#sent == 1 and sent[1].Kind == "Homing" and sent[1].Id == target and sent[1].On == false, "유도 떼기가 Homing 으로 안 감")
				assert(GridBattle.SetHoming(state, target, false))
			else
				assert(self.partyPicking == target, "유도 누름이 적 고르기로 안 감")
				assert(self.partyHud.clicks["HomingButton"], "적 고르기 중에도 유도 칸이 보여야 한다")
				local foe = GridBattle.AliveEnemies(state)[1].Id
				self:_partyPickEnemy(foe)
				assert(#sent == 1 and sent[1].Kind == "Homing" and sent[1].Id == target and sent[1].On == true and sent[1].TargetId == foe, "적을 고르면 Homing(TargetId) 이 가야 한다")
				assert(GridBattle.SetHoming(state, target, true, foe))
			end
			assert(GridBattle.SetHoming(state, "player", turn % 2 == 1))
			publish()
			drain("준비 2 " .. turn)
			assert(self.snapshot.Preview[target] and #self.snapshot.Preview[target].Motions > 0, "범위 미리보기가 없음")
			if turn == 3 then
				-- 쓰러진 유닛은 쓰러짐 연출 뒤 인형까지 치워진다
				GridBattle.DebugSetHealth(state, "ally3", 0)
				expectedKills += 1
				publish()
				drain("쓰러짐")
				assert(not director:Has("ally3") and not self.dolls.ally3, string.format("쓰러진 유닛의 인형이 남음 (배우 %s, 인형 %s, 살아 %s)", tostring(director:Has("ally3")), tostring(self.dolls.ally3), tostring(self.snapshot.Units.ally3.Alive)))
				assert(table.concat(PartyHud.OrderOf(self.snapshot), ",") == "ally2,player" or table.concat(PartyHud.OrderOf(self.snapshot), ",") == "player,ally2", "쓰러진 유닛이 순서에 남음")
			end

			-- 턴 시작
			table.clear(sent)
			self.partyHud.clicks["BeginTurn"]()
			assert(#sent == 1 and sent[1].Kind == "BeginTurn", "턴 시작이 BeginTurn 으로 안 감")
			local ok, why, order2 = GridBattle.BeginTurn(state)
			assert(ok, why)
			turning = true
			publish()
			assert(not self.partyHud.panel.Visible, "턴이 시작됐는데 준비 판이 남음")
			table.clear(played)
			-- 유닛 하나씩 해소하며 스냅샷을 연달아 보낸다(연출을 기다리지 않는다)
			while true do
				local id = GridBattle.NextActor(state)
				if not id then
					break
				end
				assert(GridBattle.ResolveUnitSkill(state, id, rng))
				publish()
			end
			GridBattle.ResolveEnemyPhase(state, rng)
			publish()
			drain("턴 " .. turn .. " 연출")
			-- 틀어진 순서 = 엔진 행동 순서(안 움직인 유닛은 빠질 수 있다), 적 행동은 맨 끝
			local at = 0
			for _, who in played do
				if who == "Enemy" then
					volleys += 1
					at = math.huge
				else
					local pos = table.find(order2, who)
					assert(pos and pos > at, string.format("연출 순서가 행동 순서와 다름: %s (순서 %s)", table.concat(played, ","), table.concat(order2, ",")))
					at = pos
				end
			end
			assert(not self:_busy(), "연출이 안 끝남")
			GridBattle.EndTurn(state)
			if state.Outcome == "Ongoing" then
				GridBattle.EnemyPlan(state, rng)
			end
			turning = false
			publish()
			drain("턴 끝 " .. turn)
			assert(state.Round.Phase == "Prepare" or state.Outcome ~= "Ongoing", "준비 단계로 안 돌아옴")
		end
		assert(volleys > 0, "적 행동 연출이 한 번도 안 나옴")
		print(string.format("파티 통합: %s, %d턴, 적 공격 연출 %d, 쓰러진 유닛 %d", state.Outcome, state.Turn, volleys, expectedKills))
		self.partyHud:Destroy()
		for id in director.Actors do
			if id ~= "player" then
				director:Remove(id)
			end
		end
		for _, doll in self.dolls do
			doll:Destroy()
		end
	end)
	print(string.format("%-12s %s", "파티 통합", if #failures == before then "통과" else "오류 " .. (#failures - before)))
end

if director.ForcedDone > 0 then
	table.insert(failures, string.format("안전장치로 강제로 끝낸 재생 %d개(모션이 스스로 안 끝남)", director.ForcedDone))
end
try("정리", function()
	director:Destroy()
end)
step(3)

for _, e in ApiCheck.errors do
	table.insert(failures, "API: " .. e) -- pcall 이 삼킨 것도 포함
end
print(string.format("재생한 동작 %d개, 흉내 시간 %.0f초, API 속성 쓰기 검사 %d건", played, now, ApiCheck.writes))
if #failures > 0 then
	print("\n실패:")
	for _, f in failures do
		print(" - " .. f)
	end
	error(string.format("연출 점검 실패 %d건", #failures))
end
print("연출 점검 통과")
