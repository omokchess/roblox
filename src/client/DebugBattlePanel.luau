--!strict
--[[
	DebugBattlePanel — 전투 **디버그 입장** 패널. (2026-09-28)

	요청: "전투 입장 코드 너가 다시 짜줘. 디버깅 목적으로 짜는거니까, 웬만한 기능은 다 넣어주고."

	F2 또는 왼쪽 위 버튼으로 연다. 지금은 모든 유저에게 보인다(BattleService OPEN_DEBUG_TO_ALL). 서버가 CanDebug 로 알려 주고,
	명령도 서버가 다시 막는다).

	탭
	  편성    직업 · 전장(하늘/필드) · 적 수·종류·배치(격자 클릭) · 체력/공격 배율 · 무기 공격력
	          무적 · 쿨타임 없음 · 아군 피해 배율 · 자동 QTE → 전투 시작 / 필드 만남 몹 세우기
	  전투 중 즉시 승리·패배 · 재시작 · 그만두기 · 턴 넘기기 · 쿨타임 초기화 · 회복
	          적마다 체력 조절·처치 · 직업 자원 주기 · 상태이상 걸기(나 / 적 전체)
	  성장    레벨 정하기 · 레벨 업(승리 판정 → 카드 제시) · 스탯 찍기/되돌리기 · 코스트 · 빌드 처음으로
	  카드    이 직업 카드 전부 — 레벨 올리고 내리기·빼기, 무작위 빌드, 등급 거르기, 마우스 올리면 카드 미리보기

	모든 것은 서버에 **의도만** 보낸다(BattleAction). 판정·값 검사는 `BattleService` 가 한다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local AbilityCards = require(ReplicatedStorage.Shared.AbilityCards)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local CardAxes = require(ReplicatedStorage.Shared.CardAxes)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)

local BattleStore = require(script.Parent.BattleStore)
local CardView = require(script.Parent.CardView)

local make = CardView.Make

local PANEL_WIDTH = 452
local C = Color3.fromRGB
local BG = C(16, 17, 22)
local CARD = C(26, 28, 36)
local LINE = C(52, 56, 70)
local TEXT = C(226, 228, 236)
local DIM = C(150, 154, 170)
local GOLD = C(255, 205, 90)
local GOOD = C(64, 160, 104)
local BAD = C(170, 58, 64)
local BLUE = C(52, 110, 190)

local TABS = { { Id = "Setup", Name = "편성" }, { Id = "Battle", Name = "전투 중" }, { Id = "Grow", Name = "성장" }, { Id = "Cards", Name = "카드" } }

-- 서버에 의도만 보낸다(판정·검사는 BattleService). _build 의 빠른 줄도 쓰므로 위에 둔다.
local function send(request: { [string]: any })
	BattleStore.Send(request)
end

local DebugBattlePanel = {}
DebugBattlePanel.__index = DebugBattlePanel

function DebugBattlePanel.new(remotes: Folder)
	local self = setmetatable({}, DebugBattlePanel)
	self.Remotes = remotes
	self.state = nil :: any
	self.snapshot = nil :: any
	self.tab = "Setup"
	self.open = false
	self.cardFilter = "All"
	self.statusTarget = "Enemies"
	-- 클라이언트에도 카드 풀을 등록한다(순수 자료). 카드 탭이 직업 카드 전부를 보여 준다.
	AbilityCards.Register()
	self:_build()

	BattleStore.Subscribe(function(state)
		-- 전투가 시작되면 패널을 접는다(아군 격자를 가린다). 전투 중 명령은 위쪽 빠른 줄로.
		local wasInBattle = self.state and self.state.InBattle
		if state and state.InBattle and not wasInBattle and self.open then
			self:SetOpen(false)
		end
		self.state = state
		self.quickBar.Visible = state ~= nil and state.CanDebug == true and state.InBattle == true
		self.toggle.Visible = state ~= nil
		if not state then
			self:SetOpen(false)
		end
		if state and state.Message and state.Message ~= "" then
			self.message.Text = state.Message
		end
		self:_refresh()
	end)
	local folder = remotes :: any
	folder.GridState.OnClientEvent:Connect(function(snapshot)
		self.snapshot = snapshot
		if self.open and self.tab == "Battle" then
			self:_refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 and self.state then
			self:SetOpen(not self.open)
		end
	end)
	return self
end

--=== 틀 ===--

function DebugBattlePanel:_build()
	local gui = make("ScreenGui", {
		Name = "DebugBattleGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.Gui = gui

	self.toggle = make("TextButton", {
		Name = "DebugToggle",
		Size = UDim2.fromOffset(150, 32),
		Position = UDim2.fromOffset(12, 60),
		BackgroundColor3 = C(40, 30, 60),
		BorderSizePixel = 0,
		Text = "전투 디버그  (F2)",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.toggle)
	make("UIStroke", { Color = C(120, 90, 170), Thickness = 1 }, self.toggle)
	self.toggle.Activated:Connect(function()
		self:SetOpen(not self.open)
	end)

	local panel = make("Frame", {
		Name = "Panel",
		Size = UDim2.new(0, PANEL_WIDTH, 1, -120),
		Position = UDim2.fromOffset(12, 100),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = LINE, Thickness = 1 }, panel)
	self.panel = panel

	self.title = make("TextLabel", {
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(14, 10),
		BackgroundTransparency = 1,
		Text = "전투 디버그",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	self.subtitle = make("TextLabel", {
		Size = UDim2.new(1, -28, 0, 18),
		Position = UDim2.fromOffset(14, 34),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = DIM,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}, panel)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -10, 0, 10),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = DIM,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	close.Activated:Connect(function()
		self:SetOpen(false)
	end)

	-- 탭 줄
	local tabs = make("Frame", {
		Size = UDim2.new(1, -28, 0, 32),
		Position = UDim2.fromOffset(14, 60),
		BackgroundTransparency = 1,
	}, panel)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
	self.tabButtons = {}
	for index, tab in TABS do
		local button = make("TextButton", {
			Size = UDim2.new(0.25, -5, 1, 0),
			BackgroundColor3 = CARD,
			BorderSizePixel = 0,
			Text = tab.Name,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			LayoutOrder = index,
		}, tabs)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		button.Activated:Connect(function()
			self.tab = tab.Id
			self:_refresh(true)
		end)
		self.tabButtons[tab.Id] = button
	end

	self.body = make("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -16, 1, -150),
		Position = UDim2.fromOffset(8, 100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)

	self.message = make("TextLabel", {
		Size = UDim2.new(1, -28, 0, 36),
		Position = UDim2.new(0, 14, 1, -44),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, self.message)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, self.message)

	-- 전투 중 빠른 줄(화면 위 가운데). 전투 판을 가리지 않는 크기.
	local quick = make("Frame", {
		Name = "QuickBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(566, 34),
		Position = UDim2.new(0.5, 0, 0, 8),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, quick)
	make("UIStroke", { Color = LINE, Thickness = 1 }, quick)
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, quick)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, quick)
	for index, entry in {
		{ "승리", "Win", GOOD },
		{ "패배", "Lose", BAD },
		{ "재시작", "Restart" },
		{ "턴 넘기기", "SkipTurn" },
		{ "쿨 초기화", "ClearCooldowns" },
		{ "회복", "HealAll" },
		{ "그만두기", "End" },
		{ "패널 F2", "Panel", C(70, 56, 110) },
	} do
		local b = make("TextButton", {
			Size = UDim2.new(0, if index == 8 then 76 else 64, 1, 0),
			BackgroundColor3 = entry[3] or C(44, 48, 62),
			BorderSizePixel = 0,
			Text = entry[1],
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			LayoutOrder = index,
		}, quick)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		b.Activated:Connect(function()
			if entry[2] == "Panel" then
				self.tab = "Battle"
				self:SetOpen(not self.open)
			else
				send({ Kind = entry[2] })
			end
		end)
	end
	self.quickBar = quick

	-- 카드 미리보기(카드 탭에서 줄에 마우스를 올리면 패널 오른쪽에)
	self.preview = make("Frame", {
		Size = UDim2.fromOffset(250, 380),
		Position = UDim2.fromOffset(12 + PANEL_WIDTH + 12, 120),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
end

function DebugBattlePanel:SetOpen(open: boolean)
	self.open = open
	self.panel.Visible = open
	self.preview.Visible = false
	if open then
		self:_refresh(true)
	end
end

--=== 작은 부품 ===--

-- 부품을 LayoutOrder 순서대로 붙여 주는 도우미
local function column(parent: Instance): (string?, number?) -> Frame
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12) }, parent)
	local order = 0
	return function(title: string?, height: number?): Frame
		order += 1
		local box = make("Frame", {
			Size = UDim2.new(1, 0, 0, height or 0),
			AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			BackgroundColor3 = CARD,
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 10),
		}, box)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, box)
		if title then
			make("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = GOLD,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
				LayoutOrder = 0,
			}, box)
		end
		return box
	end
end

local function row(parent: Instance, order: number, height: number?): Frame
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

local function button(parent: Instance, text: string, width: number, color: Color3?, onClick: (() -> ())?, order: number?): TextButton
	local b = make("TextButton", {
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = color or C(44, 48, 62),
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		RichText = true,
		LayoutOrder = order or 0,
		AutoButtonColor = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function label(parent: Instance, text: string, width: number, order: number?, color: Color3?, align: Enum.TextXAlignment?): TextLabel
	return make("TextLabel", {
		Size = UDim2.new(0, width, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = order or 0,
	}, parent)
end

-- 여러 값 중 하나(분절 버튼)
local function choice(parent: Instance, order: number, options: { { any } }, current: any, onPick: (any) -> ())
	local line = row(parent, order)
	local width = math.floor((PANEL_WIDTH - 60 - 5 * (#options - 1)) / #options)
	for index, option in options do
		local picked = option[1] == current
		button(line, option[2], width, if picked then BLUE else nil, function()
			onPick(option[1])
		end, index)
	end
end

local function toggle(parent: Instance, order: number, text: string, value: boolean, onChange: (boolean) -> ())
	local line = row(parent, order)
	label(line, text, 250, 1)
	button(line, if value then "켜짐" else "꺼짐", 120, if value then GOOD else nil, function()
		onChange(not value)
	end, 2)
end

-- 이름 · 값 · 버튼 여러 개(증감)
local function stepper(parent: Instance, order: number, text: string, value: string, steps: { { any } }, onStep: (any) -> ())
	local line = row(parent, order)
	label(line, text, 118, 1, DIM)
	label(line, value, 62, 2, GOLD, Enum.TextXAlignment.Center)
	for index, step in steps do
		button(line, step[2], math.floor((PANEL_WIDTH - 60 - 118 - 62 - 5 * (#steps + 1)) / #steps), nil, function()
			onStep(step[1])
		end, 2 + index)
	end
end

local function fmt(n: number): string
	if n % 1 == 0 then
		return tostring(math.floor(n))
	end
	return (string.format("%.3f", n):gsub("0+$", ""):gsub("%.$", ""))
end

--=== 다시 그리기 ===--

function DebugBattlePanel:_refresh(resetScroll: boolean?)
	if not self.open or not self.state then
		return
	end
	local state = self.state
	for id, b in self.tabButtons do
		b.BackgroundColor3 = if id == self.tab then C(70, 56, 110) else CARD
	end
	local class = nil
	for _, entry in state.Classes or {} do
		if entry.Id == state.Config.ClassId then
			class = entry
		end
	end
	self.subtitle.Text = string.format(
		'%s  ·  Lv.<font color="rgb(255,205,90)">%d</font>  ·  %d승  ·  체력 %d  ·  무기 %d%s',
		class and class.Name or state.Config.ClassId,
		state.Level,
		state.Wins,
		state.MaxHealth,
		state.Power,
		if state.InBattle then '  ·  <font color="rgb(255,120,120)">전투 중</font>' else ""
	)

	local scroll = self.body.CanvasPosition
	for _, child in self.body:GetChildren() do
		child:Destroy()
	end
	local section = column(self.body)
	if self.tab == "Setup" then
		self:_setupTab(section)
	elseif self.tab == "Battle" then
		self:_battleTab(section)
	elseif self.tab == "Grow" then
		self:_growTab(section)
	else
		self:_cardsTab(section)
	end
	if not resetScroll then
		task.defer(function()
			self.body.CanvasPosition = scroll
		end)
	else
		self.body.CanvasPosition = Vector2.zero
	end
end

local function patch(config: { [string]: any })
	send({ Kind = "SetConfig", Config = config })
end

function DebugBattlePanel:_setupTab(section: (string?, number?) -> Frame)
	local state = self.state
	local config = state.Config

	-- 시작 버튼을 맨 위에(가장 자주 누른다)
	local top = section(nil)
	local go = row(top, 1, 40)
	button(go, if state.InBattle then "재시작" else "전투 시작", 196, BAD, function()
		send({ Kind = if state.InBattle then "Restart" else "Start" })
	end, 1)
	button(go, string.format("필드 몹 세우기 (%d)", state.Encounters or 0), 130, C(60, 110, 70), function()
		send({ Kind = "SpawnEncounter" })
	end, 2)
	button(go, "몹 치우기", 66, nil, function()
		send({ Kind = "ClearEncounters" })
	end, 3)

	-- 직업 3×3
	local classes = section("직업  <font color=\"rgb(150,154,170)\" size=\"12\">바꾸면 카드 빌드가 비워진다</font>")
	local grid = make("Frame", { Size = UDim2.new(1, 0, 0, 3 * 46 + 2 * 5), BackgroundTransparency = 1, LayoutOrder = 1 }, classes)
	make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -4, 0, 46), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for index, entry in state.Classes or {} do
		local picked = entry.Id == config.ClassId
		-- 고른 직업은 어두운 바탕에 직업색을 조금 섞고 테두리를 직업색으로(밝은 직업색 위 흰 글자는 안 읽힌다)
		local b = button(grid, string.format('%s\n<font size="11" color="rgb(170,174,190)">%s</font>', entry.Name, entry.Role or ""), 0, if picked then CARD:Lerp(entry.Color, 0.28) else nil, function()
			patch({ ClassId = entry.Id })
		end, index)
		if picked then
			make("UIStroke", { Color = entry.Color, Thickness = 2 }, b)
		end
	end

	-- 전장
	local arena = section("전장")
	choice(arena, 1, { { "Sky", "하늘 전장 (혼자)" }, { "Field", "필드 (지금 서 있는 앞)" } }, config.Arena, function(value)
		patch({ Arena = value })
	end)

	-- 적 편성
	local enemies = section(string.format("적 편성  <font color=\"rgb(150,154,170)\" size=\"12\">%d마리 · 칸을 눌러 순서대로 배치(비우면 자동)</font>", #config.Enemies))
	local types = state.EnemyTypes or {}
	local currentType = config.Enemies[1] or "Slime"
	local typeOptions = {}
	for _, enemy in types do
		table.insert(typeOptions, { enemy.Id, string.format("%s (체력 %d · 공격 %d)", enemy.Name, enemy.MaxHealth, enemy.Power) })
	end
	if #typeOptions > 0 then
		choice(enemies, 1, typeOptions, currentType, function(value)
			local list = {}
			for _ = 1, #config.Enemies do
				table.insert(list, value)
			end
			patch({ Enemies = list })
		end)
	end
	stepper(enemies, 2, "마리 수", tostring(#config.Enemies), { { -1, "−1" }, { 1, "+1" }, { 3, "3" }, { 18, "가득" } }, function(step)
		local count = if step == 3 or step == 18 then step else #config.Enemies + step
		count = math.clamp(count, 1, BattleGrid.DEFAULT_WIDTH * BattleGrid.DEFAULT_HEIGHT)
		local list = {}
		for _ = 1, count do
			table.insert(list, currentType)
		end
		patch({ Enemies = list })
	end)
	-- 배치 격자(적 진영: x=1 이 중앙선 쪽 → 왼쪽에 그린다)
	local board = make("Frame", { Size = UDim2.new(1, 0, 0, 3 * 34 + 2 * 4), BackgroundTransparency = 1, LayoutOrder = 3 }, enemies)
	local used: { [string]: number } = {}
	for index, cell in config.Cells do
		used[cell[1] .. "," .. cell[2]] = index
	end
	for y = 1, BattleGrid.DEFAULT_HEIGHT do
		for x = 1, BattleGrid.DEFAULT_WIDTH do
			local key = x .. "," .. y
			local order = used[key]
			local cellButton = make("TextButton", {
				Size = UDim2.new(1 / 6, -4, 0, 34),
				Position = UDim2.new((x - 1) / 6, 2, 0, (y - 1) * 38),
				BackgroundColor3 = if order then C(150, 60, 64) else C(40, 44, 56),
				BorderSizePixel = 0,
				Text = if order then tostring(order) else (if x == 1 then "전열" elseif x == 6 then "후열" else ""),
				TextColor3 = if order then TEXT else DIM,
				Font = Enum.Font.GothamBold,
				TextSize = if order then 15 else 11,
			}, board)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, cellButton)
			cellButton.Activated:Connect(function()
				local cells = table.clone(config.Cells)
				if order then
					table.remove(cells, order)
				elseif #cells < #config.Enemies then
					table.insert(cells, { x, y })
				end
				patch({ Cells = cells })
			end)
		end
	end
	local clear = row(enemies, 4, 26)
	label(clear, string.format("정한 칸 %d / %d", #config.Cells, #config.Enemies), 200, 1, DIM)
	button(clear, "자동 배치로", 120, nil, function()
		patch({ Cells = {} })
	end, 2)

	-- 배율
	local scale = section("수치")
	stepper(scale, 1, "적 체력 ×", fmt(config.HealthScale), { { 0.001, ".001" }, { 0.5, "½" }, { 1, "×1" }, { 2, "×2" }, { 10, "×10" } }, function(value)
		patch({ HealthScale = value })
	end)
	stepper(scale, 2, "적 공격력 ×", fmt(config.PowerScale), { { 0, "0" }, { 0.5, "½" }, { 1, "×1" }, { 3, "×3" } }, function(value)
		patch({ PowerScale = value })
	end)
	stepper(scale, 3, "무기 공격력", if config.WeaponPower > 0 then tostring(config.WeaponPower) else "기본", { { -10, "−10" }, { 10, "+10" }, { 100, "+100" }, { 0, "기본" } }, function(step)
		patch({ WeaponPower = if step == 0 then 0 else math.max(0, (if config.WeaponPower > 0 then config.WeaponPower else state.Power) + step) })
	end)
	stepper(scale, 4, "아군 피해 ×", fmt(config.AllyDamageScale), { { 1, "×1" }, { 2, "×2" }, { 10, "×10" }, { 100, "×100" } }, function(value)
		patch({ AllyDamageScale = value })
	end)

	local cheats = section("시험 편의")
	toggle(cheats, 1, "무적 (아군이 피해를 안 받음)", config.God, function(value)
		patch({ God = value })
	end)
	toggle(cheats, 2, "쿨타임 없음", config.NoCooldown, function(value)
		patch({ NoCooldown = value })
	end)
	local qteLine = row(cheats, 3)
	label(qteLine, "QTE", 60, 1)
	for index, option in { { "Off", "직접" }, { "Success", "자동 성공" }, { "Partial", "자동 부분" }, { "Fail", "자동 실패" } } do
		button(qteLine, option[2], 82, if config.AutoQte == option[1] then BLUE else nil, function()
			patch({ AutoQte = option[1] })
		end, 1 + index)
	end
end

function DebugBattlePanel:_battleTab(section: (string?, number?) -> Frame)
	local state = self.state
	if not state.InBattle then
		local box = section("전투 중이 아닙니다")
		local line = row(box, 1, 38)
		button(line, "전투 시작", 200, BAD, function()
			send({ Kind = "Start" })
		end, 1)
		return
	end
	local snapshot = self.snapshot

	local flow = section("흐름")
	local a = row(flow, 1, 34)
	button(a, "즉시 승리", 100, GOOD, function()
		send({ Kind = "Win" })
	end, 1)
	button(a, "즉시 패배", 100, BAD, function()
		send({ Kind = "Lose" })
	end, 2)
	button(a, "재시작", 90, nil, function()
		send({ Kind = "Restart" })
	end, 3)
	button(a, "그만두기", 90, nil, function()
		send({ Kind = "End" })
	end, 4)
	local b = row(flow, 2, 34)
	button(b, "턴 넘기기", 100, nil, function()
		send({ Kind = "SkipTurn" })
	end, 1)
	button(b, "쿨타임 초기화", 110, nil, function()
		send({ Kind = "ClearCooldowns" })
	end, 2)
	button(b, "나 회복", 80, nil, function()
		send({ Kind = "HealAll" })
	end, 3)
	button(b, "적도 회복", 80, nil, function()
		send({ Kind = "HealAll", Enemies = true })
	end, 4)

	if snapshot then
		local me = snapshot.Units and snapshot.Units.player
		local foes = section(string.format("적  <font size=\"12\" color=\"rgb(150,154,170)\">%d턴</font>", snapshot.Turn or 0))
		local ids = {}
		for id, unit in snapshot.Units or {} do
			if unit.Side == "Enemy" then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for index, id in ids do
			local unit = snapshot.Units[id]
			local line = row(foes, index, 28)
			label(line, string.format("%s %s", unit.Name, if unit.X then string.format("(%d,%d)", unit.X, unit.Y) else ""), 110, 1, if unit.Alive then TEXT else DIM)
			label(line, if unit.Alive then string.format("%d/%d%s", unit.Health, unit.MaxHealth, if unit.Stunned then " ★" else "") else "쓰러짐", 76, 2, GOLD)
			if unit.Alive then
				button(line, "−10", 44, nil, function()
					send({ Kind = "SetHealth", Id = id, Value = unit.Health - 10 })
				end, 3)
				button(line, "1", 34, nil, function()
					send({ Kind = "SetHealth", Id = id, Value = 1 })
				end, 4)
				button(line, "처치", 56, BAD, function()
					send({ Kind = "KillEnemy", Id = id })
				end, 5)
			end
		end
		if me then
			local mine = section(string.format("나  체력 %d/%d · 스테미나 %d", me.Health, me.MaxHealth, snapshot.AllyStamina or 0))
			local line = row(mine, 1, 28)
			for index, value in { { 1, "체력 1" }, { 0.5, "절반" }, { 1.0, "가득" } } do
				button(line, value[2], 90, nil, function()
					local target = if value[2] == "체력 1" then 1 else math.floor(me.MaxHealth * value[1])
					send({ Kind = "SetHealth", Id = "player", Value = target })
				end, index)
			end
		end

		-- 직업 자원
		local resources = ClassResources.ForClass(snapshot.AllyClassId or state.Config.ClassId)
		if #resources > 0 then
			local box = section("자원 주기")
			local stacks = snapshot.AllyStatus and snapshot.AllyStatus.Stacks or {}
			for index, id in resources do
				local line = row(box, index, 26)
				label(line, ClassResources.Label(id), 110, 1)
				label(line, tostring(stacks[id] or 0), 40, 2, GOLD, Enum.TextXAlignment.Center)
				for step, amount in { -1, 1, 5 } do
					button(line, if amount > 0 then "+" .. amount else tostring(amount), 56, nil, function()
						send({ Kind = "GiveStack", Id = id, Amount = amount })
					end, 2 + step)
				end
			end
		end
	end

	local status = section("상태이상 걸기")
	choice(status, 1, { { "Enemies", "적 전체" }, { "Ally", "나" } }, self.statusTarget, function(value)
		self.statusTarget = value
		self:_refresh()
	end)
	local list = {
		{ "Bleed", "출혈 +3", 3 },
		{ "Poison", "독 +5", 5 },
		{ "Burn", "화상 +5", 5 },
		{ "Oil", "기름 +2", 2 },
		{ "Shield", "보호막 +20", 20 },
		{ "Groggy", "그로기 +50", 50 },
		{ "Taunt", "도발 +3", 3 },
	}
	local line: Frame? = nil
	for index, entry in list do
		if (index - 1) % 4 == 0 then
			line = row(status, 1 + math.ceil(index / 4), 30)
		end
		button(line :: Frame, entry[2], 94, nil, function()
			send({ Kind = "ApplyStatus", Target = self.statusTarget, Status = entry[1], Amount = entry[3] })
		end, index)
	end
end

function DebugBattlePanel:_growTab(section: (string?, number?) -> Frame)
	local state = self.state
	local level = section("레벨")
	stepper(level, 1, "레벨", tostring(state.Level), { { -5, "−5" }, { -1, "−1" }, { 1, "+1" }, { 5, "+5" } }, function(step)
		send({ Kind = "SetLevel", Level = state.Level + step })
	end)
	local up = row(level, 2, 34)
	button(up, "레벨 업 (승리 판정 → 카드)", 230, C(120, 90, 30), function()
		send({ Kind = "LevelUp" })
	end, 1)
	label(up, string.format("%d승 · 최대 %d", state.Wins, state.MaxLevel or 60), 150, 2, DIM)

	local stats = section(string.format('스탯  <font color="rgb(255,205,90)">포인트 %d</font>', state.Points))
	for index, id in StatDefinitions.Order do
		local definition = StatDefinitions.Get(id)
		stepper(stats, index, definition and definition.Name or id, tostring(state.Stats[id] or 0), { { -5, "−5" }, { -1, "−1" }, { 1, "+1" }, { 5, "+5" } }, function(step)
			send({ Kind = "SpendStat", StatId = id, Amount = step })
		end)
	end
	local reset = row(stats, 10, 30)
	button(reset, "스탯 되돌리기", 140, nil, function()
		send({ Kind = "ResetStats" })
	end, 1)

	local economy = section(string.format("코스트 %d", if state.Offer then state.Offer.Cost else 0))
	local line = row(economy, 1, 30)
	button(line, "코스트 +30", 110, nil, function()
		send({ Kind = "GiveCost", Amount = 30 })
	end, 1)
	button(line, "코스트 +300", 110, nil, function()
		send({ Kind = "GiveCost", Amount = 300 })
	end, 2)
	local wipe = row(economy, 2, 34)
	button(wipe, "빌드 처음으로 (레벨·스탯·카드·승수)", 330, BAD, function()
		send({ Kind = "ResetBuild" })
	end, 1)
end

function DebugBattlePanel:_cardsTab(section: (string?, number?) -> Frame)
	local state = self.state
	local classId = state.Config.ClassId
	local owned: { [string]: any } = {}
	local axisCount: { [string]: number } = {}
	for _, card in state.Owned or {} do
		owned[card.Id] = card
		for _, tag in card.Tags or {} do
			axisCount[tag] = (axisCount[tag] or 0) + 1
		end
	end

	local top = section(string.format("내 빌드  %d장", #(state.Owned or {})))
	local axes = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, top)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }, axes)
	for _, axis in CardAxes.ForClass(classId) do
		local chip = make("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundColor3 = axis.Color,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Text = string.format("%s <b>%d</b>", axis.Name, axisCount[axis.Id] or 0),
			RichText = true,
			TextColor3 = axis.Color,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
		}, axes)
		make("UICorner", { CornerRadius = UDim.new(0, 11) }, chip)
		make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip)
	end
	local buttons = row(top, 2, 30)
	button(buttons, "무작위 빌드", 110, C(60, 110, 70), function()
		send({ Kind = "RandomBuild" })
	end, 1)
	button(buttons, "모두 빼기", 100, BAD, function()
		send({ Kind = "ClearCards" })
	end, 2)
	label(buttons, "다음 전투부터 적용", 150, 3, DIM)

	local filterBox = section(nil)
	choice(filterBox, 1, { { "All", "전체" }, { "Essential", "필수" }, { "Rare", "희귀" }, { "Common", "일반" }, { "Owned", "보유" } }, self.cardFilter, function(value)
		self.cardFilter = value
		self:_refresh(true)
	end)

	local grades = { "Essential", "Rare", "Common" }
	for _, grade in grades do
		if self.cardFilter ~= "All" and self.cardFilter ~= "Owned" and self.cardFilter ~= grade then
			continue
		end
		local pool = AbilityCardDefinitions.GetPool(classId, grade :: any)
		local style = CardView.GRADE_STYLE[grade]
		local box = section(string.format('<font color="#%s">%s</font>  %d장', style.Edge:ToHex(), style.Name, #pool))
		local sorted = table.clone(pool)
		table.sort(sorted, function(x, y)
			return x.Name < y.Name
		end)
		for index, card in sorted do
			local have = owned[card.Id]
			if self.cardFilter == "Owned" and not have then
				continue
			end
			local maxLevel = AbilityCardDefinitions.MaxLevelFor(card)
			local level = have and have.Level or 0
			local line = row(box, index, 30)
			local thumbHolder = make("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, line)
			CardView.Thumb(thumbHolder, card, 28)
			-- ✎ 그림 있음 · 파 파티 전제 · 배 전직 배타(함께 못 드는 필수가 있다)
			local marks = (if card.Art then ' <font color="rgb(150,154,170)" size="11">✎</font>' else "")
				.. (if card.Party then ' <font color="rgb(110,170,240)" size="11">파</font>' else "")
				.. (if card.Excludes and #card.Excludes > 0 then ' <font color="rgb(230,110,120)" size="11">배</font>' else "")
			local name = label(line, card.Name .. marks, 158, 2, if have then TEXT else DIM)
			label(line, if have then string.format("Lv %d/%d", level, maxLevel) else string.format("−/%d", maxLevel), 52, 3, if have then GOLD else DIM, Enum.TextXAlignment.Center)
			button(line, "−", 30, nil, function()
				if level <= 1 then
					send({ Kind = "RemoveCard", CardId = card.Id })
				else
					send({ Kind = "AddCard", CardId = card.Id, Level = level - 1 })
				end
			end, 4)
			button(line, "+", 30, nil, function()
				send({ Kind = "AddCard", CardId = card.Id, Level = math.min(level + 1, maxLevel) })
			end, 5)
			button(line, "최대", 44, nil, function()
				send({ Kind = "AddCard", CardId = card.Id, Level = maxLevel })
			end, 6)
			-- 줄에 마우스를 올리면 카드 미리보기
			local hover = make("TextButton", { Size = UDim2.new(0, 190, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, name)
			hover.Position = UDim2.fromOffset(-32, 0)
			hover.MouseEnter:Connect(function()
				self:_showPreview(card, level, maxLevel)
			end)
			hover.MouseLeave:Connect(function()
				self.preview.Visible = false
			end)
		end
	end
end

function DebugBattlePanel:_showPreview(card: any, level: number, maxLevel: number)
	for _, child in self.preview:GetChildren() do
		child:Destroy()
	end
	CardView.Build(self.preview, {
		Id = card.Id,
		Name = card.Name,
		Grade = card.Grade,
		ClassId = card.ClassId,
		Tags = card.Tags,
		Art = card.Art,
		Level = level,
		MaxLevel = maxLevel,
		Description = AbilityCardDefinitions.Describe(card, math.max(level, 1)),
	}, { TextSize = 15 })
	self.preview.Visible = true
end

return DebugBattlePanel
