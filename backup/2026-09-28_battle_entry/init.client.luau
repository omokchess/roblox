--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local BattleController = require(script.BattleController)
local MotionEditorController = require(script.MotionEditorController)
-- 임시: 새 전투 시스템 시험용.
--   BattleTestController — 화면 안 격자 버튼으로 규칙만 확인하는 UI판
--   Battle3DController   — 월드에 격자를 깔고 아바타가 직접 싸우는 3D판
-- 실제 전투를 붙일 때 이 두 require와 아래 초기화 줄, 두 파일을 지우면 된다.
local BattleTestController = require(script.BattleTestController)
local Battle3DController = require(script.Battle3DController)

--[[
	실제 전투. 서버(`TowerService`)가 판정한 것을 그리고 입력만 보낸다.

	위의 두 시험판과 달리 자체 판정이 없다. 시험판은 QTE 연출과 조작 감각을 붙여 보는
	자리로 남기고, 탑에서 실제로 싸우는 것은 이쪽이다.
]]
local TowerBattleController = require(script.TowerBattleController)

local remotes = ReplicatedStorage:WaitForChild(Constants.REMOTE_FOLDER)
local battle = BattleController.new(remotes)
MotionEditorController.new(remotes, battle.EditorButton, battle.InventoryButton)

local battleTest = BattleTestController.new()
battleTest:BindInput()

Battle3DController.new()
-- 등반 중 광장 버튼을 감추려면 그 버튼을 가진 BattleController를 넘겨줘야 한다.
TowerBattleController.new(remotes, battle)

-- 스튜디오 전용 모션 전시장: workspace 속성 CombatShowcase = true 로 켠다(Combat/CombatShowcase.luau)
if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatShowcase") == true then
	task.spawn(function()
		require(script.Combat.CombatShowcase).Start()
	end)
end
