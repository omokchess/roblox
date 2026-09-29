--!strict
--[[
	광장 카메라만 담당한다.

	원래 이 파일은 **원정대 시스템**(파티 편성 로비 · 행동 선택 · 업그레이드 고르기 ·
	3인 파티 전투 UI)이 전부 들어 있던 700줄짜리였다. 그 시스템을 걷어낸 뒤엔
	모션 제작 / 모션 인벤토리 버튼이 남아 있었는데, 2026-09-29 모션 에디터를 통째로 뺐다
	(더 쓰기 쉬운 형태로 다시 설계할 때까지. 예전 코드는 backup/2026-09-29_motion_editor).

	남은 일은 광장 카메라 복귀 하나다 — 서버가 PlazaState 를 쏘면 카메라를 원래대로 돌린다.
	`SetBattleActive` 는 `BattleClient` 가 부르므로 자리만 남겨 둔다.

	파일 이름은 그대로 둔다 — Rojo 경로와 require가 걸려 있어 옮기면 그쪽까지
	건드려야 하고, 얻는 것은 이름뿐이다.
]]

local Players = game:GetService("Players")

local BattleController = {}
BattleController.__index = BattleController

function BattleController.new(remotes: Folder)
	local self = setmetatable({}, BattleController)
	self.Remotes = remotes
	self.BattleActive = false
	remotes.PlazaState.OnClientEvent:Connect(function()
		self:_showPlaza()
	end)
	self:_showPlaza()
	return self
end

-- 전투 중인지 기억만 한다. 광장에 감출 버튼이 다시 생기면 여기서 감춘다
function BattleController:SetBattleActive(active: boolean)
	self.BattleActive = active
end

function BattleController:_showPlaza()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

return BattleController
