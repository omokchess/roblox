--!strict
--[[
	CombatShowcase — 스튜디오 전용 **모션 전시장**. (2026-09-28)

	전투 모션을 한눈에 확인하고 다른 게임과 비교하려고 만들었다. 게임 흐름에는 끼지 않는다.
	켜는 법: 스튜디오에서 workspace 에 속성 CombatShowcase = true 를 넣고 플레이.
	  캐릭터를 공중 무대(맵 위 높은 곳)로 옮기고, 전투 카메라와 같은 구도(오른쪽 옆 위)로 비춘다.
	  직업마다: 대기 → 들림 → 내려놓임 → 피격 → 방어 → 회피 → 스킬 전부 → 슬라임 공격 3등급(회피·막음·맞음)
	  키: N 다음 직업 · B 이전 직업 · R 이 직업 처음부터 · P 멈춤/계속
	화면 위에 지금 재생 중인 직업·모션 이름을 띄운다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatDirector = require(script.Parent.CombatDirector)
local WeaponDefinitions = require(ReplicatedStorage.Shared.Combat.WeaponDefinitions)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)

local CLASSES = { "Duelist", "Musician", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
local CLASS_NAME = {
	Duelist = "결투사",
	Musician = "음악가",
	Quasar = "퀘이사",
	Pulsar = "펄서",
	WallPilgrim = "월 필그림",
	WallMason = "월 메이슨",
	WallBreaker = "월 브레이커",
	Alchemist = "연금술사",
	Berserker = "광전사",
}
local REACTION_NAME = { Idle = "대기", Held = "들림", Drop = "내려놓임", Hit = "피격", Guard = "방어", Dodge = "회피" }

local STAGE = Vector3.new(0, 900, 0)

local CombatShowcase = {}

function CombatShowcase.Start()
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	task.wait(1)

	-- 무대(맵 양식: 돌판 블록)
	local folder = Instance.new("Folder")
	folder.Name = "CombatShowcase"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(60, 1, 24)
	floor.CFrame = CFrame.new(STAGE + Vector3.new(6, -0.5, 0))
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(120, 118, 110)
	floor.Parent = folder

	root.Anchored = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- 아군은 +X 를 보고, 슬라임은 앞 8칸에서 -X 를 본다(실제 전투 격자와 같은 방향)
	local allyHome = CFrame.lookAt(STAGE + Vector3.new(0, 3.4, 0), STAGE + Vector3.new(1, 3.4, 0))
	local slimeHome = CFrame.lookAt(STAGE + Vector3.new(10, 0, 0), STAGE + Vector3.new(0, 0, 0))

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local focus = STAGE + Vector3.new(5, 1.5, 0)
	local camCf = CFrame.lookAt(focus + Vector3.new(0, 15, 22), focus)
	camera.CFrame = camCf

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatShowcaseUi"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 56)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.Parent = gui

	local director = CombatDirector.new()
	director:SetCamera(camCf)

	local classIndex = 1
	local generation = 0
	local paused = false

	local function show(text: string)
		label.Text = string.format("[%d/%d] %s — %s     (N 다음 · B 이전 · R 처음 · P 멈춤)", classIndex, #CLASSES, CLASS_NAME[CLASSES[classIndex]], text)
	end

	-- 한 동작이 끝날 때까지(연출이 한가해질 때까지) 기다린다. 다른 직업으로 넘어가면 false
	local function waitIdle(gen: number, minimum: number): boolean
		local t0 = os.clock()
		repeat
			task.wait(0.05)
			while paused and gen == generation do
				task.wait(0.1)
			end
		until gen ~= generation or (os.clock() - t0 >= minimum and not director:IsBusy())
		return gen == generation
	end

	local function runClass(gen: number)
		local classId = CLASSES[classIndex]
		director:Remove("slime")
		director:AddHumanoid("player", character, classId, allyHome, WeaponDefinitions.ForClass(classId).Id)
		director:SetHome("player", allyHome, true)
		director:AddSlime("slime", folder, slimeHome)

		show(REACTION_NAME.Idle)
		if not waitIdle(gen, 3) then
			return
		end
		show(REACTION_NAME.Held)
		director:Grab("player")
		local t0 = os.clock()
		while os.clock() - t0 < 1.8 and gen == generation do
			local k = (os.clock() - t0) / 1.8
			director:HoldAt("player", allyHome.Position + Vector3.new(0, 2.2, math.sin(k * math.pi * 2) * 3))
			task.wait()
		end
		show(REACTION_NAME.Drop)
		director:Drop("player", allyHome)
		if not waitIdle(gen, 0.5) then
			return
		end
		for _, name in { "Hit", "Guard", "Dodge" } do
			show(REACTION_NAME[name])
			director:PlayEnemyAttack("slime", "SlimeTackle", "player", if name == "Hit" then "Fail" elseif name == "Guard" then "Partial" else "Success")
			if not waitIdle(gen, 0.6) then
				return
			end
		end
		-- 스킬 전부(직업 스킬 → 강화 → 가드·명상)
		local skills = {}
		for _, s in BattleSkills.ForClass(classId) do
			table.insert(skills, s.Id)
		end
		for _, s in BattleSkills.Upgrades() do
			if (s :: any).ClassId == classId then
				table.insert(skills, s.Id)
			end
		end
		if classId == "Quasar" then
			table.insert(skills, 1, "CollapseCharge")
		end
		table.insert(skills, "Guard")
		table.insert(skills, "Meditate")
		for _, skillId in skills do
			local skill = BattleSkills.ById(skillId)
			show(string.format("스킬: %s", if skill then skill.Name else skillId))
			director:PlaySkill("player", skillId, { { "slime" }, { "slime" }, { "slime" } })
			if not waitIdle(gen, 0.8) then
				return
			end
			if not director:Has("slime") then
				director:AddSlime("slime", folder, slimeHome)
			end
		end
		show("슬라임 산성 침")
		director:PlayEnemyAttack("slime", "SlimeSpit", "player", "Fail")
		if not waitIdle(gen, 0.6) then
			return
		end
		show("끝 — N 으로 다음 직업")
	end

	local function restart()
		generation += 1
		local gen = generation
		task.spawn(runClass, gen)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			classIndex = classIndex % #CLASSES + 1
			restart()
		elseif input.KeyCode == Enum.KeyCode.B then
			classIndex = (classIndex - 2) % #CLASSES + 1
			restart()
		elseif input.KeyCode == Enum.KeyCode.R then
			restart()
		elseif input.KeyCode == Enum.KeyCode.P then
			paused = not paused
		end
	end)

	restart()
end

return CombatShowcase
