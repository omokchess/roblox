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
	local fn = luau.load(luau.compile(fs.readFile(file)), { debugName = file, environment = env })
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

local CLASSES = { "Duelist", "Musician", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
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
		end)
		settle(director, classId .. " 스킬 " .. skillId, 6)
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

if director.ForcedDone > 0 then
	table.insert(failures, string.format("안전장치로 강제로 끝낸 재생 %d개(모션이 스스로 안 끝남)", director.ForcedDone))
end
try("정리", function()
	director:Destroy()
end)
step(3)

print(string.format("재생한 동작 %d개, 흉내 시간 %.0f초", played, now))
if #failures > 0 then
	print("\n실패:")
	for _, f in failures do
		print(" - " .. f)
	end
	error(string.format("연출 점검 실패 %d건", #failures))
end
print("연출 점검 통과")
