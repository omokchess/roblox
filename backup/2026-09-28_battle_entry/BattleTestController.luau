--!strict
--[[
	BattleTestController — 전투 시스템 시험용 임시 UI.

	요청: "전투 시험을 위해 임시로 전투 시작 버튼을 만들어줘"

	새로 만든 세 모듈을 **실제로 눌러서 확인**하기 위한 것이다.
	  BattleGrid       6×3 배치, 스킬 범위 미리보기(붉은 칸)
	  QteDefinitions   스킬 QTE / 회피·패리 QTE 판정
	  GroggyGauge      패리 시 15 누적, 100에서 한 턴 스턴

	**임시 UI다.** 서버 권위가 없고 전부 클라이언트에서 돈다.
	실제 전투를 붙일 때 이 파일은 지우거나 서버 전투로 교체할 것.

	쓰는 법
	  화면 좌하단 `전투 시험` 버튼 → 패널이 열린다.
	  1. 아군 격자(왼쪽) 칸을 눌러 내 위치를 옮긴다.
	  2. 스킬 버튼을 눌러 범위를 미리 본다. 적 격자(오른쪽)가 붉게 칠해진다.
	     — 여러 스킬을 눌러보며 비교만 할 수 있다(사양: 미리보기는 확정이 아니다).
	  3. `이 스킬로 선택`을 누르면 스킬 QTE가 뜬다.
	     성공 1.2배 / 보통 1.0배 / 실패 0.5배 (사양: 실패 시 1/2)
	  4. 이어서 적의 반격에 회피·패리 QTE가 뜬다.
	     성공 0배 / 방어 0.5배 / 실패 1.0배
	     패리 성공 시 적 그로기 +15. 100이 되면 적이 한 턴 스턴.

	QTE 입력
	  Sweep / Forge / Parry : 스페이스 또는 클릭
	  Mash                  : 스페이스 연타
	  Directional           : 방향키 또는 WASD
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)
local GroggyGauge = require(ReplicatedStorage.Shared.GroggyGauge)

local BattleTestController = {}
BattleTestController.__index = BattleTestController

local CELL = 46
local PAD = 4

-- 시험용 스킬 목록. 범위 모양만 다르게 해 미리보기를 확인한다.
local SKILLS: { { Name: string, Shape: BattleGrid.Shape, Damage: number } } = {
	{ Name = "찌르기", Shape = { Kind = "Single" }, Damage = 40 },
	{ Name = "횡베기", Shape = { Kind = "Row" }, Damage = 26 },
	{ Name = "관통", Shape = { Kind = "Column" }, Damage = 30 },
	{ Name = "충격파", Shape = { Kind = "Cross", Radius = 1 }, Damage = 22 },
	{ Name = "폭발", Shape = { Kind = "Square", Radius = 1 }, Damage = 18 },
}

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(class)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function BattleTestController.new()
	local self = setmetatable({}, BattleTestController)

	self.grid = BattleGrid.New()
	self.enemyGroggy = GroggyGauge.New()
	self.selectedSkill = 1
	self.playerCell = { X = 2, Y = 2 }
	self.enemyCell = { X = 4, Y = 2 }
	self.qte = nil :: QteDefinitions.Challenge?
	self.qteStart = 0
	self.qteConnection = nil :: RBXScriptConnection?

	BattleGrid.Place(self.grid, "player", "Ally", self.playerCell.X, self.playerCell.Y)
	BattleGrid.Place(self.grid, "enemy", "Enemy", self.enemyCell.X, self.enemyCell.Y)

	self:_build()
	return self
end

function BattleTestController:_build()
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", {
		Name = "BattleTestGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	self.gui = gui

	-- 여는 버튼
	self.openButton = make("TextButton", {
		Name = "OpenBattleTest",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0, 16, 1, -120),
		BackgroundColor3 = Color3.fromRGB(150, 40, 44),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = "전투 시험",
		AutoButtonColor = true,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, self.openButton)

	-- 패널
	self.panel = make("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(760, 470),
		Position = UDim2.new(0.5, -380, 0.5, -235),
		BackgroundColor3 = Color3.fromRGB(22, 24, 30),
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, self.panel)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "전투 시험 (임시)  —  6×3 배치 · 스킬 QTE · 그로기",
		TextColor3 = Color3.fromRGB(230, 230, 240),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	}, self.panel)

	local close = make("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -34, 0, 4),
		BackgroundColor3 = Color3.fromRGB(60, 62, 72),
		Text = "X",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, self.panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, close)

	self.openButton.Activated:Connect(function()
		self.panel.Visible = true
	end)
	close.Activated:Connect(function()
		self.panel.Visible = false
		self:_endQte()
	end)

	self:_buildGrids()
	self:_buildSkills()
	self:_buildStatus()
	self:_buildQteLayer()
	self:_refresh()
end

-- 격자 두 개(아군/적)를 만든다. 칸 버튼을 표로 들고 있다가 색만 바꾼다.
function BattleTestController:_buildGrids()
	self.cellButtons = { Ally = {}, Enemy = {} }

	local function buildSide(side: BattleGrid.Side, originX: number, title: string)
		make("TextLabel", {
			Size = UDim2.fromOffset(300, 20),
			Position = UDim2.fromOffset(originX, 44),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Color3.fromRGB(180, 185, 200),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, self.panel)

		for y = 1, self.grid.Height do
			self.cellButtons[side][y] = {}
			for x = 1, self.grid.Width do
				local button = make("TextButton", {
					Size = UDim2.fromOffset(CELL, CELL),
					Position = UDim2.fromOffset(originX + (x - 1) * (CELL + PAD), 68 + (y - 1) * (CELL + PAD)),
					BackgroundColor3 = Color3.fromRGB(48, 52, 62),
					Text = "",
					AutoButtonColor = false,
				}, self.panel)
				make("UICorner", { CornerRadius = UDim.new(0, 4) }, button)

				if side == "Ally" then
					-- 아군 칸을 누르면 내 유닛이 이동한다 (사양: 매 턴 격자 내에서 이동)
					button.Activated:Connect(function()
						local ok = BattleGrid.Move(self.grid, "player", x, y)
						if ok then
							self.playerCell = { X = x, Y = y }
							self:_refresh()
						end
					end)
				else
					-- 적 칸을 누르면 스킬 원점을 옮겨 범위를 확인한다
					button.Activated:Connect(function()
						self.enemyCell = { X = x, Y = y }
						self:_refresh()
					end)
				end

				self.cellButtons[side][y][x] = button
			end
		end
	end

	buildSide("Ally", 24, "아군 진영 (칸을 눌러 이동)")
	buildSide("Enemy", 410, "적 진영 (칸을 눌러 조준)")
end

function BattleTestController:_buildSkills()
	self.skillButtons = {}
	for index, skill in SKILLS do
		local button = make("TextButton", {
			Size = UDim2.fromOffset(120, 28),
			Position = UDim2.fromOffset(24 + (index - 1) * 126, 232),
			BackgroundColor3 = Color3.fromRGB(48, 52, 62),
			Text = skill.Name,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Font = Enum.Font.Gotham,
			TextSize = 13,
		}, self.panel)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)

		button.Activated:Connect(function()
			-- 누르기만 하면 미리보기다. 확정이 아니다(사양).
			self.selectedSkill = index
			self:_refresh()
		end)
		self.skillButtons[index] = button
	end

	self.confirmButton = make("TextButton", {
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.fromOffset(24, 272),
		BackgroundColor3 = Color3.fromRGB(150, 40, 44),
		Text = "이 스킬로 선택",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, self.panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.confirmButton)

	self.confirmButton.Activated:Connect(function()
		self:_startQte("Skill")
	end)
end

function BattleTestController:_buildStatus()
	self.infoLabel = make("TextLabel", {
		Size = UDim2.fromOffset(560, 44),
		Position = UDim2.fromOffset(196, 268),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, self.panel)

	make("TextLabel", {
		Size = UDim2.fromOffset(120, 18),
		Position = UDim2.fromOffset(24, 322),
		BackgroundTransparency = 1,
		Text = "적 그로기",
		TextColor3 = Color3.fromRGB(180, 185, 200),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.panel)

	local track = make("Frame", {
		Size = UDim2.fromOffset(400, 16),
		Position = UDim2.fromOffset(24, 342),
		BackgroundColor3 = Color3.fromRGB(45, 48, 58),
	}, self.panel)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, track)

	self.groggyFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(230, 160, 60),
	}, track)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, self.groggyFill)

	self.groggyLabel = make("TextLabel", {
		Size = UDim2.fromOffset(220, 18),
		Position = UDim2.fromOffset(432, 341),
		BackgroundTransparency = 1,
		Text = "0 / 100",
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.panel)

	self.logLabel = make("TextLabel", {
		Size = UDim2.fromOffset(712, 74),
		Position = UDim2.fromOffset(24, 372),
		BackgroundColor3 = Color3.fromRGB(30, 32, 40),
		Text = "",
		TextColor3 = Color3.fromRGB(190, 195, 210),
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, self.panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.logLabel)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, self.logLabel)
end

function BattleTestController:_buildQteLayer()
	self.qteFrame = make("Frame", {
		Size = UDim2.fromOffset(340, 190),
		Position = UDim2.new(0.5, -170, 0.5, -95),
		BackgroundColor3 = Color3.fromRGB(16, 18, 24),
		Visible = false,
		ZIndex = 20,
	}, self.gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, self.qteFrame)

	self.qteTitle = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		ZIndex = 21,
	}, self.qteFrame)

	self.qteHint = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 158),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(160, 165, 180),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ZIndex = 21,
	}, self.qteFrame)

	-- Sweep: 좌우로 왕복하는 바 + 목표 구간
	self.sweepTrack = make("Frame", {
		Size = UDim2.fromOffset(280, 26),
		Position = UDim2.fromOffset(30, 78),
		BackgroundColor3 = Color3.fromRGB(40, 43, 52),
		Visible = false,
		ZIndex = 21,
	}, self.qteFrame)
	self.sweepTarget = make("Frame", {
		Size = UDim2.fromScale(0.18, 1),
		BackgroundColor3 = Color3.fromRGB(60, 170, 90),
		ZIndex = 22,
	}, self.sweepTrack)
	self.sweepCursor = make("Frame", {
		Size = UDim2.fromOffset(5, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 23,
	}, self.sweepTrack)

	-- Forge / Parry: 줄어드는 링
	self.ringOuter = make("Frame", {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.fromOffset(110, 40),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	}, self.qteFrame)
	self.ringTarget = make("Frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(0.5, -24, 0.5, -24),
		BackgroundColor3 = Color3.fromRGB(60, 170, 90),
		BackgroundTransparency = 0.55,
		ZIndex = 21,
	}, self.ringOuter)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.ringTarget)
	self.ringMoving = make("Frame", {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.new(0.5, -60, 0.5, -60),
		BackgroundColor3 = Color3.fromRGB(90, 150, 240),
		BackgroundTransparency = 0.35,
		ZIndex = 22,
	}, self.ringOuter)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.ringMoving)

	-- Mash / Directional 공용 텍스트
	self.qteBig = make("TextLabel", {
		Size = UDim2.fromOffset(320, 70),
		Position = UDim2.fromOffset(10, 66),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 250),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Visible = false,
		ZIndex = 21,
	}, self.qteFrame)
end

--=== 갱신 ===--

function BattleTestController:_refresh()
	local skill = SKILLS[self.selectedSkill]

	-- 스킬 범위 미리보기: 사양대로 격자를 붉게 칠한다.
	-- 칠할 칸은 CellsInShape()가 주며, 실제 타격도 같은 함수를 쓴다.
	local highlighted: { [string]: boolean } = {}
	for _, cell in BattleGrid.CellsInShape(self.grid, "Enemy", self.enemyCell.X, self.enemyCell.Y, skill.Shape) do
		highlighted[cell.X .. "," .. cell.Y] = true
	end

	for y = 1, self.grid.Height do
		for x = 1, self.grid.Width do
			local ally = self.cellButtons.Ally[y][x]
			local isPlayer = self.playerCell.X == x and self.playerCell.Y == y
			ally.BackgroundColor3 = if isPlayer then Color3.fromRGB(70, 130, 220) else Color3.fromRGB(48, 52, 62)
			ally.Text = if isPlayer then "나" else ""
			ally.TextColor3 = Color3.new(1, 1, 1)
			ally.Font = Enum.Font.GothamBold
			ally.TextSize = 13

			local foe = self.cellButtons.Enemy[y][x]
			local inRange = highlighted[x .. "," .. y] == true
			local isEnemy = BattleGrid.Occupant(self.grid, "Enemy", x, y) ~= nil
			foe.BackgroundColor3 = if inRange
				then Color3.fromRGB(170, 55, 60) -- 사양: 범위는 붉게
				else Color3.fromRGB(48, 52, 62)
			foe.Text = if isEnemy then "적" else ""
			foe.TextColor3 = Color3.new(1, 1, 1)
			foe.Font = Enum.Font.GothamBold
			foe.TextSize = 13
		end
	end

	for index, button in self.skillButtons do
		button.BackgroundColor3 = if index == self.selectedSkill
			then Color3.fromRGB(70, 90, 140)
			else Color3.fromRGB(48, 52, 62)
	end

	local targets = BattleGrid.UnitsInShape(self.grid, "Enemy", self.enemyCell.X, self.enemyCell.Y, skill.Shape)
	self.infoLabel.Text = string.format(
		"선택: %s   기본 대미지 %d   범위 칸 %d   맞는 적 %d\n미리보기만으로는 확정되지 않습니다. '이 스킬로 선택'을 눌러야 QTE가 시작됩니다.",
		skill.Name,
		skill.Damage,
		#BattleGrid.CellsInShape(self.grid, "Enemy", self.enemyCell.X, self.enemyCell.Y, skill.Shape),
		#targets
	)

	self:_refreshGroggy()
end

function BattleTestController:_refreshGroggy()
	local ratio = GroggyGauge.Ratio(self.enemyGroggy)
	self.groggyFill.Size = UDim2.fromScale(ratio, 1)
	self.groggyLabel.Text = string.format(
		"%d / %d%s",
		self.enemyGroggy.Value,
		GroggyGauge.MAX,
		if GroggyGauge.IsStunned(self.enemyGroggy) then "   [스턴]" else ""
	)
end

function BattleTestController:_log(text: string)
	self.logLabel.Text = text .. "\n" .. string.sub(self.logLabel.Text, 1, 260)
end

--=== QTE ===--

function BattleTestController:_startQte(role: QteDefinitions.Role)
	self:_endQte()

	local random = Random.new(os.clock() * 1000)
	local challenge = QteDefinitions.Create(role, function()
		return random:NextNumber()
	end, 0, "test", true)

	self.qte = challenge
	self.qteStart = os.clock()
	self.qteFrame.Visible = true
	self.qteTitle.Text =
		string.format("%s — %s", if role == "Skill" then "스킬" else "회피/패리", challenge.Title)

	self.sweepTrack.Visible = challenge.Type == "Sweep"
	self.ringOuter.Visible = challenge.Type == "Forge" or challenge.Type == "Parry"
	self.qteBig.Visible = challenge.Type == "Mash" or challenge.Type == "Directional"

	if challenge.Type == "Mash" then
		self.qteHint.Text = "스페이스 연타"
	elseif challenge.Type == "Directional" then
		self.qteHint.Text = "방향키 / WASD"
	else
		self.qteHint.Text = "스페이스 또는 클릭"
	end

	self.qteConnection = RunService.RenderStepped:Connect(function()
		self:_tickQte()
	end)
end

function BattleTestController:_tickQte()
	local challenge = self.qte
	if not challenge then
		return
	end

	local elapsed = (os.clock() - self.qteStart) * 1000
	local state = QteDefinitions.VisualState(challenge, elapsed)

	if challenge.Type == "Sweep" then
		self.sweepCursor.Position = UDim2.fromScale(state.position, 0)
		self.sweepTarget.Position = UDim2.fromScale(math.max(state.targetPosition - state.successGap, 0), 0)
		self.sweepTarget.Size = UDim2.fromScale(state.successGap * 2, 1)
	elseif challenge.Type == "Forge" or challenge.Type == "Parry" then
		local size = math.max(state.outerRadius, 0) * 120
		self.ringMoving.Size = UDim2.fromOffset(size, size)
		self.ringMoving.Position = UDim2.new(0.5, -size / 2, 0.5, -size / 2)
		local targetSize = state.targetRadius * 120
		self.ringTarget.Size = UDim2.fromOffset(targetSize, targetSize)
		self.ringTarget.Position = UDim2.new(0.5, -targetSize / 2, 0.5, -targetSize / 2)
		-- 패리는 표시가 깜빡인다(PvP 방해 요소)
		self.ringMoving.BackgroundTransparency = 1 - (state.indicatorOpacity or 1) * 0.65
	elseif challenge.Type == "Mash" then
		self.qteBig.Text = string.format("%d / %d", state.count, state.goal)
	elseif challenge.Type == "Directional" then
		local parts: { string } = {}
		local arrows = { Up = "↑", Right = "→", Down = "↓", Left = "←" }
		for index, direction in state.expectedDirections do
			local hiddenHere = false
			for _, hidden in state.hiddenCommandIndexes do
				if hidden == index then
					hiddenHere = true
					break
				end
			end
			local glyph = if hiddenHere then "?" else arrows[direction]
			if index <= state.sequenceIndex then
				glyph = "·"
			end
			table.insert(parts, glyph)
		end
		self.qteBig.Text = table.concat(parts, " ")
	end

	-- 시간이 다 되면 자동 판정
	if elapsed >= challenge.DurationMs then
		self:_resolveQte(elapsed)
	end
end

function BattleTestController:_input(input: string)
	local challenge = self.qte
	if not challenge then
		return
	end
	if not QteDefinitions.IsValidInput(challenge.Type, input) then
		return
	end

	local elapsed = (os.clock() - self.qteStart) * 1000

	if challenge.Type == "Mash" then
		challenge.InputCount += 1
		return
	end

	if challenge.Type == "Directional" then
		local expected = challenge.ExpectedDirections or {}
		local nextIndex = (challenge.SequenceIndex or 0) + 1
		if expected[nextIndex] == input then
			challenge.SequenceIndex = nextIndex
		else
			challenge.Mistakes = (challenge.Mistakes or 0) + 1
			challenge.SequenceIndex = nextIndex
		end
		if (challenge.SequenceIndex or 0) >= #expected then
			self:_resolveQte(elapsed)
		end
		return
	end

	-- Sweep / Forge / Parry: 한 번 입력하면 그 시점으로 판정
	self:_resolveQte(elapsed)
end

function BattleTestController:_resolveQte(elapsed: number)
	local challenge = self.qte
	if not challenge then
		return
	end

	local grade = QteDefinitions.Judge(challenge, elapsed)
	local multiplier = QteDefinitions.Multiplier(challenge.Role, grade)
	local gradeText = ({ Success = "성공", Partial = "보통/방어", Fail = "실패" })[grade]

	if challenge.Role == "Skill" then
		local skill = SKILLS[self.selectedSkill]
		local targets = BattleGrid.UnitsInShape(self.grid, "Enemy", self.enemyCell.X, self.enemyCell.Y, skill.Shape)
		local damage = math.floor(skill.Damage * multiplier)
		self:_log(
			string.format(
				"[스킬] %s / %s → %s ×%.1f = %d 대미지, 대상 %d",
				skill.Name,
				challenge.Title,
				gradeText,
				multiplier,
				damage,
				#targets
			)
		)
		self:_endQte()
		-- 스킬을 쓰면 적이 반격한다 → 회피/패리 QTE
		task.delay(0.45, function()
			if self.panel.Visible then
				self:_startQte("Dodge")
			end
		end)
		return
	end

	-- 회피/패리
	local incoming = 35
	local taken = math.floor(incoming * multiplier)
	local groggyGain = QteDefinitions.GroggyGain(challenge, grade)
	local stunned = false
	if groggyGain > 0 then
		stunned = GroggyGauge.Add(self.enemyGroggy, groggyGain)
	end

	self:_log(
		string.format(
			"[피격] %s → %s ×%.1f = %d 받음%s%s",
			challenge.Title,
			gradeText,
			multiplier,
			taken,
			if groggyGain > 0 then string.format(" / 적 그로기 +%d", groggyGain) else "",
			if stunned then "  ★ 적 스턴!" else ""
		)
	)

	if GroggyGauge.IsStunned(self.enemyGroggy) then
		-- 스턴 한 턴을 소모시킨다
		GroggyGauge.TickTurn(self.enemyGroggy)
		self:_log("[턴] 적이 스턴으로 한 턴을 쉬고 게이지가 초기화됐다.")
	end

	self:_endQte()
	self:_refreshGroggy()
end

function BattleTestController:_endQte()
	if self.qteConnection then
		self.qteConnection:Disconnect()
		self.qteConnection = nil
	end
	self.qte = nil
	if self.qteFrame then
		self.qteFrame.Visible = false
	end
end

function BattleTestController:BindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.qte then
			return
		end
		local map: { [Enum.KeyCode]: string } = {
			[Enum.KeyCode.Space] = if self.qte.Type == "Mash" then "Mash" else "Tap",
			[Enum.KeyCode.Up] = "Up",
			[Enum.KeyCode.W] = "Up",
			[Enum.KeyCode.Right] = "Right",
			[Enum.KeyCode.D] = "Right",
			[Enum.KeyCode.Down] = "Down",
			[Enum.KeyCode.S] = "Down",
			[Enum.KeyCode.Left] = "Left",
			[Enum.KeyCode.A] = "Left",
		}
		local mapped = map[input.KeyCode]
		if mapped then
			self:_input(mapped)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_input(if self.qte.Type == "Mash" then "Mash" else "Tap")
		end
	end)
end

return BattleTestController
