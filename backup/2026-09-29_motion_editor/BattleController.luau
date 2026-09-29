--!strict
--[[
	광장에 떠 있는 버튼과 카메라만 담당한다.

	원래 이 파일은 **원정대 시스템**(파티 편성 로비 · 행동 선택 · 업그레이드 고르기 ·
	3인 파티 전투 UI)이 전부 들어 있던 700줄짜리였다. 그 시스템을 걷어내면서 남은
	것은 두 가지뿐이다.

	  1. 모션 제작 / 모션 인벤토리 버튼 — `MotionEditorController`가 이 둘을 받아 쓴다
	  2. 광장 카메라 복귀 — 서버가 PlazaState를 쏘면 카메라를 원래대로 돌린다

	전투 중에는 버튼을 감춰야 하므로 `SetBattleActive`도 남았다(`BattleClient`가 부른다).

	파일 이름은 그대로 둔다 — Rojo 경로와 require가 걸려 있어 옮기면 그쪽까지
	건드려야 하고, 얻는 것은 이름뿐이다.
]]

local Players = game:GetService("Players")

local BattleController = {}
BattleController.__index = BattleController

local function button(parent: Instance, text: string, width: number?, height: number?): TextButton
	local value = Instance.new("TextButton")
	value.Size = UDim2.fromOffset(width or 150, height or 48)
	value.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
	value.BorderSizePixel = 0
	value.Font = Enum.Font.GothamBold
	value.Text = text
	value.TextColor3 = Color3.fromRGB(240, 220, 160)
	value.TextSize = 14
	value.TextWrapped = true
	value.Parent = parent
	return value
end

function BattleController.new(remotes: Folder)
	local self = setmetatable({}, BattleController)
	self.Remotes = remotes
	-- 광장 버튼(모션 제작·모션 인벤토리)의 상태.
	self.LobbyButtonsWanted = false
	self.BattleActive = false
	self:_buildUi()
	remotes.PlazaState.OnClientEvent:Connect(function()
		self:_showPlaza()
	end)
	return self
end

function BattleController:_buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlazaMotionGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = gui

	self.EditorButton = button(gui, "모션 제작", 132, 42)
	self.EditorButton.Position = UDim2.new(1, -150, 0, 164)
	self.InventoryButton = button(gui, "모션 인벤토리", 132, 42)
	self.InventoryButton.Position = UDim2.new(1, -150, 0, 216)
	self.InventoryButton.BackgroundColor3 = Color3.fromRGB(66, 52, 82)

	self:_showPlaza()
end

--[[
	광장 버튼을 한 번에 켜고 끈다.

	원하는 상태를 `LobbyButtonsWanted`에 기억해 둔다. 전투 중이면 무엇을 원하든
	감추기 때문에, 전투가 끝났을 때 "원래 켜져 있어야 했는지"를 알아야 한다.
]]
function BattleController:_setLobbyButtons(visible: boolean)
	self.LobbyButtonsWanted = visible
	local show = visible and not self.BattleActive
	self.EditorButton.Visible = show
	self.InventoryButton.Visible = show
end

--[[
	전투 중에는 이 버튼들을 감춘다 (요청).

	`_showPlaza`가 버튼을 무조건 다시 켜는데, 등반 중에도 광장 상태가 올 수 있어
	한 번 숨기는 것만으로는 다시 튀어나온다. 그래서 플래그로 막는다.
]]
function BattleController:SetBattleActive(active: boolean)
	self.BattleActive = active
	self:_setLobbyButtons(self.LobbyButtonsWanted)
end

function BattleController:_showPlaza()
	self:_setLobbyButtons(true)
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
