--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local BattleController = require(script.BattleController)
local MotionEditorController = require(script.MotionEditorController)
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
local BattleStore = require(script.BattleStore)
local DebugBattlePanel = require(script.DebugBattlePanel)
local EncounterView = require(script.EncounterView)
local LevelUpUi = require(script.LevelUpUi)

local remotes = ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER)
local battle = BattleController.new(remotes)
MotionEditorController.new(remotes, battle.EditorButton, battle.InventoryButton)

-- 전투 중 광장 버튼을 감추려면 그 버튼을 가진 BattleController 를 넘겨줘야 한다.
local battleClient = BattleClient.new(remotes, battle)
DebugBattlePanel.new(remotes)
LevelUpUi.new(battleClient)
task.spawn(EncounterView.Start)
-- 구독자를 다 붙인 뒤에 상태를 받기 시작한다(늦게 붙은 쪽도 마지막 상태를 받는다)
BattleStore.Init(remotes)

-- 스튜디오 전용 모션 전시장: workspace 속성 CombatShowcase = true 로 켠다(Combat/CombatShowcase.luau)
if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatShowcase") == true then
	task.spawn(function()
		require(script.Combat.CombatShowcase).Start()
	end)
end
