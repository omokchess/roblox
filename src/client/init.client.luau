--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local BattleController = require(script.BattleController)
--[[
	격자 전투 (2026-09-28 입장 코드 교체).
	  BattleStore       서버 BattleState 를 한 곳에서 받아 나눠 준다
	  BattleClient      서버가 판정한 전투를 그리고 입력만 보낸다(격자·스킬 바·QTE·연출)
	  DebugBattlePanel  디버그 입장(F2) — 직업·적 편성·전장·치트·카드·성장
	  LevelUpUi         레벨업 화면 — 카드 고르기·스탯 찍기
	  EncounterView     필드 만남 몹(닿으면 전투) 그리기
	예전 시험판(BattleTestController·Battle3DController)과 탑 입장 UI 는 지웠다.
]]
local BattleClient = require(script.BattleClient)
local BattleSpectator = require(script.BattleSpectator)
local BattleStore = require(script.BattleStore)
local DebugBattlePanel = require(script.DebugBattlePanel)
local EncounterView = require(script.EncounterView)
local LevelUpUi = require(script.LevelUpUi)

--[[
	자동 번역 끄기(2026-11-07 사용자: "한국어 번역좀 어떻게 해봐") — 로블록스 자동 번역이 이미 한국어인 글을 다시 기계 번역해
	「신경을 곤두세우고 깊은 호흡을 들여」 → 「신경을 예민하게 하고 깊은 호흡을 하기」, 「찔러찔러또찔러」 → 「찌르찌르또찌르」 처럼 바꿨다.
	모든 화면 글(PlayerGui · 월드의 Billboard/SurfaceGui)에 AutoLocalize = false. 근본 해결은 크리에이터 대시보드의 원본 언어를 한국어로.
]]
do
	local Players = game:GetService("Players")
	local function keep(inst: Instance)
		if inst:IsA("GuiBase2d") then
			inst.AutoLocalize = false
		end
	end
	local function watch(root: Instance)
		for _, d in root:GetDescendants() do
			keep(d)
		end
		root.DescendantAdded:Connect(keep)
	end
	watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	watch(workspace)
end

local remotes = ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER)
-- 광장 카메라 복귀. 모션 에디터(모션 제작·인벤토리 버튼)는 2026-09-29 뺐다(backup/2026-09-29_motion_editor)
local battle = BattleController.new(remotes)
local battleClient = BattleClient.new(remotes, battle)
DebugBattlePanel.new(remotes)
LevelUpUi.new(battleClient)
task.spawn(EncounterView.Start)
-- 남의 전투 구경(서버 BattleSpectate)
task.spawn(BattleSpectator.Start, remotes)
-- 지역마다 다른 안개·빛·떠다니는 입자
task.spawn(require(script.RegionAtmosphere).Start)
-- 설원 굴 광차 타기(서버가 길을 보내면 제 캐릭터를 레일 따라)
task.spawn(require(script.MineCartClient).Start, remotes)
-- 구독자를 다 붙인 뒤에 상태를 받기 시작한다(늦게 붙은 쪽도 마지막 상태를 받는다)
BattleStore.Init(remotes)

-- 스튜디오 전용 모션 전시장: workspace 속성 CombatShowcase = true 로 켠다(Combat/CombatShowcase.luau)
-- (2026-11-07 Studio 를 다시 켜면 이 모듈이 자꾸 없어져 있었다 — 원인 미상, 없으면 조용히 건너뛴다)
local showcase = script.Combat:FindFirstChild("CombatShowcase")
if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatShowcase") == true and showcase then
	task.spawn(function()
		require(showcase :: ModuleScript).Start()
	end)
end

-- 스튜디오 전용 QA 촬영장: workspace 속성 QaSkill = "Callisto/CallistoDipper" 처럼 있으면 그 기술 하나를 반복 재생(Combat/QaStage.luau)
local qaStage = script.Combat:FindFirstChild("QaStage")
if game:GetService("RunService"):IsStudio() and type(workspace:GetAttribute("QaSkill")) == "string" and qaStage then
	task.spawn(function()
		require(qaStage :: ModuleScript).Start()
	end)
end

-- 스튜디오 전용 칼리스토 페이즈 미리보기: 얼어붙은 호수 workspace.CallistoPreview 자리표마다 1·2·3페이즈 모습(Combat/CallistoPreview.luau)
if game:GetService("RunService"):IsStudio() and workspace:FindFirstChild("CallistoPreview") then
	task.spawn(function()
		require(script.Combat.CallistoPreview).Start()
	end)
end
