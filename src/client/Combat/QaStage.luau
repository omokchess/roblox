--!strict
--[[
	QaStage — 스튜디오 전용 **QA 촬영장**. (2026-11-07, 커밋 전 총괄이 기술마다 핵심 순간을 스크린샷으로 검수하려고)

	기술 하나를 전투와 같은 판·카메라·적/아군 더미 구성으로 **반복 재생**한다. 게임 흐름에는 안 끼고,
	workspace 속성 QaSkill 이 없으면 아무것도 안 한다(init.client 가 속성을 보고 모듈이 있을 때만 부름).
	  QaSkill  "<주인>/<스킬Id>"   예) "Callisto/CallistoDipper"(칼리스토가 아군 더미 여럿에게 씀)
	                                    "Attuner/Septentriones"(그 직업 플레이어가 슬라임 더미 여럿에게 씀)
	  QaSpeed  배율 0.05~1 (기본 1, 0.25 = 4배 느리게). 내부적으로 CombatTimeScale 을 써서 모션·이펙트·카메라(연출기 _step)가
	           같은 배율이 된다. 1 보다 크게는 연출기가 막아 둠(빠르게는 안 됨). 재생 중 바꾸면 다음 반복부터 적용
	  QaPhase  칼리스토 페이지 1·2·3 (기본 1) — 모습·무기·표정·우주 배경
	  QaGrade  칼리스토 공격의 회피 등급 Fail(맞음, 기본)·Partial(막음)·Success(피함)
	  QaGap    반복 사이 쉬는 초 (기본 1.5)
	화면 위 띠: 반복 번호 · 스킬 · 배율 · 경과 시간(연출 시간) — 스크린샷에 시각이 같이 찍힌다.
	반복이 시작될 때마다 http://127.0.0.1:34999/qa_tick (tools/studio_recv.py → tools/recv/qa_tick.txt)로 "tick 번호 스킬 배율" 을 쏜다.
	클라이언트 스크립트는 HttpService 가 막혀 있어 보통 실패한다 — 실패하면 조용히 포기하고 Output 에 [QA] 줄을 남긴다.
	켜는 법: workspace 에 QaSkill 속성을 넣고 플레이(칼리스토 판 우주 배경은 QaPhase 2·3 에서 같이 뜬다).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local BattleStage = require(script.Parent.Parent.BattleStage)
local CallistoSpace = require(script.Parent.CallistoSpace)
local CombatDirector = require(script.Parent.CombatDirector)
local WeaponDefinitions = require(ReplicatedStorage.Shared.Combat.WeaponDefinitions)

local W = BattleGrid.DEFAULT_WIDTH
local H = BattleGrid.DEFAULT_HEIGHT
local FLOAT_HEIGHT = 3.4 -- BattleClient 와 같게
local CAMERA_PITCH = 35 -- BattleClient 와 같게
-- 칼리스토 전투 카메라(BattleClient.CALLISTO_CAM 과 같게 — 거기를 바꾸면 여기도)
local CALLISTO_CAM = { Eye = Vector3.new(-61, 31, 19), Aim = Vector3.new(7, 0, -8) }
local STAGE = Vector3.new(0, 1400, 0) -- 모션 전시장(900)과 겹치지 않게
local PAGE_MOOD = { [1] = "Observe", [2] = "Resolve", [3] = "Sorrow" }
local ALLY_DUMMIES = { { 1, 1 }, { 1, 3 }, { 3, 1 }, { 3, 3 }, { 5, 2 } } -- 판 전체·범위 기술이 보이게 흩어 둔 아군
local ENEMY_DUMMIES = { { 2, 1 }, { 2, 3 }, { 4, 1 }, { 4, 3 }, { 5, 2 } }

local QaStage = {}

local function attrNumber(name: string, default: number): number
	local v = workspace:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- 싸우는 사람의 인형(BattleSpectator.makeDoll 과 같은 방식): 캐릭터를 복제해 스크립트·소리를 빼고 뿌리를 묶는다
local function makeDoll(character: Model, name: string, parent: Instance): Model?
	local was = character.Archivable
	character.Archivable = true
	local doll = character:Clone()
	character.Archivable = was
	if not doll then
		return nil
	end
	for _, d in doll:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	local root = doll:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	local humanoid = doll:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	doll.Name = name
	doll.Parent = parent
	return doll
end

function QaStage.Start()
	local spec = workspace:GetAttribute("QaSkill")
	if type(spec) ~= "string" then
		return
	end
	local owner, skillId = string.match(spec, "^([%w_]+)/([%w_]+)$")
	if not owner or not skillId then
		warn("[QA] QaSkill 은 '주인/스킬Id' 모양이어야 합니다(예: Callisto/CallistoDipper) — " .. spec)
		return
	end
	local boss = owner == "Callisto"

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	task.wait(1)

	-- 무대: 전투와 같은 평평한 판(칸 타일) + 밑받침
	local folder = Instance.new("Folder")
	folder.Name = "QaStage"
	folder.Parent = workspace
	local layout = BattleArena.NewLayout(CFrame.new(STAGE))
	layout.FlatY = STAGE.Y
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(140, 1, 90)
	slab.CFrame = CFrame.new(STAGE + Vector3.new(0, -0.55, 0))
	slab.Material = Enum.Material.Slate
	slab.Color = Color3.fromRGB(70, 70, 76)
	slab.Parent = folder
	local tiles = BattleStage.Build(folder, layout, nil, W, H, nil)

	root.Anchored = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	local function home(side: string, x: number, y: number): CFrame
		local cf = BattleArena.CellWorldCFrame(layout, side :: any, x, y, W, H, nil)
		if side == "Ally" then
			local p = (cf + Vector3.new(0, FLOAT_HEIGHT, 0)).Position
			return CFrame.lookAt(p, p + layout.Origin.RightVector)
		end
		return cf + Vector3.new(0, 0.4, 0)
	end

	-- 카메라: 전투와 같은 구도(칼리스토전은 전용 구도)
	local camera = workspace.CurrentCamera :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	local camCf: CFrame
	if boss then
		camCf = layout.Origin * CFrame.lookAt(CALLISTO_CAM.Eye, CALLISTO_CAM.Aim)
	else
		camCf = BattleArena.FitCameraCFrame(
			layout,
			W,
			H,
			camera.FieldOfView,
			camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1),
			CAMERA_PITCH
		)
	end
	camera.CFrame = camCf

	local director = CombatDirector.new()
	director:SetCamera(camCf)
	local enemyTiles, allyTiles = {}, {}
	for y = 1, H do
		for x = 1, W do
			table.insert(enemyTiles, tiles.Enemy[y][x])
			table.insert(allyTiles, tiles.Ally[y][x])
		end
	end
	director.EnemyTiles = enemyTiles
	director.AllyTiles = allyTiles

	-- 화면 띠
	local gui = Instance.new("ScreenGui")
	gui.Name = "QaStageUi"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 40)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Parent = gui

	-- 배우 세우기 -----------------------------------------------------------
	local targetIds: { string } = {}
	local lastPhase = 0
	local function stand()
		local phase = math.clamp(math.floor(attrNumber("QaPhase", 1)), 1, 3)
		if boss then
			if not director:Has("boss") then
				director:AddEnemy(
					"boss",
					nil,
					folder,
					home("Enemy", 3, 2) + Vector3.new(0, FLOAT_HEIGHT - 0.4, 0),
					"Callisto"
				)
			end
			if lastPhase ~= phase then
				lastPhase = phase
				director:SetMood("boss", PAGE_MOOD[phase])
				director:SetCallistoPage("boss", phase)
				director:SwapWeapon("boss", if phase >= 2 then "CallistoHammer" else "CallistoArms")
			end
			if phase >= 2 then
				CallistoSpace.SetCenter(layout.Origin.Position)
				if not CallistoSpace.IsShown() then
					CallistoSpace.Show(1)
				end
				CallistoSpace.Spin(if phase >= 3 then 1.6 else 0.12, 1)
				CallistoSpace.Galaxy(phase >= 3, 2)
			elseif CallistoSpace.IsShown() then
				CallistoSpace.Hide()
			end
			-- 맞는 쪽: 인형 더미들(진짜 캐릭터가 연출기 손을 타기 전에 복제) + 진짜 캐릭터(player)
			table.clear(targetIds)
			table.insert(targetIds, "player")
			for i, c in ALLY_DUMMIES do
				local id = "ally" .. i
				if not director:Has(id) then
					local doll = makeDoll(character, "QaAlly" .. i, folder)
					if doll then
						local h = home("Ally", c[1], c[2])
						director:AddHumanoid(id, doll, "Berserker", h)
						director:SetHome(id, h, true)
					end
				end
				if director:Has(id) then
					table.insert(targetIds, id)
				end
			end
			if not director:Has("player") then
				local h = home("Ally", 2, 2)
				director:AddHumanoid("player", character, "Berserker", h)
				director:SetHome("player", h, true)
			end
		else
			if not director:Has("player") then
				local h = home("Ally", 2, 2)
				director:AddHumanoid("player", character, owner, h, WeaponDefinitions.ForClass(owner).Id)
				director:SetHome("player", h, true)
			end
			table.clear(targetIds)
			for i, c in ENEMY_DUMMIES do
				local id = "enemy" .. i
				if not director:Has(id) then
					director:AddSlime(id, folder, home("Enemy", c[1], c[2]))
				end
				table.insert(targetIds, id)
			end
		end
	end

	-- 한 번 재생하고 끝날 때까지 기다린다(최대 90초)
	local function waitIdle(minimum: number)
		local t0 = os.clock()
		repeat
			task.wait(0.05)
		until (os.clock() - t0 >= minimum and not director:IsBusy()) or os.clock() - t0 > 90
	end

	local httpBlocked = false
	local function postTick(n: number, speed: number)
		local text = string.format("tick %d %s speed %g", n, spec, speed)
		print("[QA] " .. text)
		if httpBlocked then
			return
		end
		local ok = pcall(function()
			HttpService:PostAsync("http://127.0.0.1:34999/qa_tick", text)
		end)
		if not ok then
			httpBlocked = true
			print(
				"[QA] qa_tick 전송 실패(클라이언트 HttpService 막힘) — 화면 띠의 반복 번호·경과 시간으로 시각을 맞추세요"
			)
		end
	end

	local n = 0
	while gui.Parent do
		local speed = math.clamp(attrNumber("QaSpeed", 1), 0.05, 1)
		workspace:SetAttribute("CombatTimeScale", speed)
		stand()
		local gap = attrNumber("QaGap", 1.5)
		n += 1
		local info = string.format("#%d  %s  x%g  p%d", n, spec, speed, math.floor(attrNumber("QaPhase", 1)))
		label.Text = info .. "  t=0.00s"
		postTick(n, speed)
		local started = os.clock()
		local running = true
		task.spawn(function()
			while running and gui.Parent do
				label.Text = string.format("%s  t=%.2fs", info, (os.clock() - started) * speed)
				task.wait(0.05)
			end
		end)

		local groups = { targetIds, targetIds, targetIds }
		if boss then
			local grade = workspace:GetAttribute("QaGrade")
			local play =
				director:PlayEnemyAttack("boss", skillId, "player", if type(grade) == "string" then grade else "Fail")
			if play then
				-- 서버가 보내는 결과 대신: 아군 전원이 맞은 것으로(판 전체·범위 기술의 숫자·반응 확인)
				local hits = {}
				for _, id in targetIds do
					table.insert(hits, { Id = id, Damage = 100 })
				end
				play:SetResult({ Hits = { hits } })
			else
				label.Text = "재생 실패: 칼리스토 모션 없음 — " .. skillId
			end
		else
			if not BattleSkills.ById(skillId) then
				label.Text = "없는 스킬 Id — " .. skillId
				running = false
				return
			end
			local play = director:PlaySkill("player", skillId, groups)
			if play then
				local hits = {}
				for _, id in targetIds do
					table.insert(hits, { Id = id, Damage = 100 })
				end
				play:SetResult({ Hits = { hits, hits, hits } })
			end
		end
		waitIdle(0.8)
		running = false
		-- 쓰러진 더미는 다음 반복에서 다시 세운다
		task.wait(gap / speed)
		-- 칼리스토는 매번 처음 자세로 되돌린다(공격 중 날이 나온 채 남지 않게)
		if boss and director:Has("boss") then
			director:SetHome("boss", home("Enemy", 3, 2) + Vector3.new(0, FLOAT_HEIGHT - 0.4, 0), true)
		end
	end
end

return QaStage
