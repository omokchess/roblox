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

	오른쪽 곁 창(2026-10-31 사용자: "직업 액티브·패시브 설명을 바로 못 읽는다 · 카드 설명을 더 직관적으로 ·
	어느 카드에 마우스를 올렸는지 보이게 · 가끔 호버해도 카드가 안 보인다")
	  편성 탭  고른 직업의 액티브·패시브·전용 상태가 늘 보이고, 다른 직업 버튼에 올리면 그 직업으로 바뀐다
	  카드 탭  올린 줄을 칠하고 카드 + 지금/다음 레벨 값 + 레벨별 수치 + 키워드 풀이
	호버는 MouseEnter/Leave 대신 매 프레임 마우스 자리로 판정한다 — 줄을 옮길 때 옛 줄의 Leave 가 새 줄의 Enter
	뒤에 와서 미리보기를 끄고, 서버 상태가 올 때마다 줄을 다시 만들면 마우스가 가만히 있는 줄엔 Enter 가 안 왔다.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local AbilityCards = require(ReplicatedStorage.Shared.AbilityCards)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local CardAxes = require(ReplicatedStorage.Shared.CardAxes)
local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local ClassPassives = require(ReplicatedStorage.Shared.ClassPassives)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
local Keywords = require(ReplicatedStorage.Shared.Keywords)
local PartyBalance = require(ReplicatedStorage.Shared.PartyBalance)
local PartyDefinitions = require(ReplicatedStorage.Shared.PartyDefinitions)
local ProgressionDefinitions = require(ReplicatedStorage.Shared.ProgressionDefinitions)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)

local BattleStore = require(script.Parent.BattleStore)
local CardView = require(script.Parent.CardView)
local StatTooltip = require(script.Parent.StatTooltip)

local make = CardView.Make

local PANEL_WIDTH = 452
local SIDE_WIDTH = 340
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
	self.partyUnit = nil :: string?
	self.open = false
	self.cardFilter = "All"
	self.statusTarget = "Enemies"
	-- 곁 창 호버 대상({ Gui, Key, Show, Paint? }) — 탭을 다시 그릴 때마다 새로 채운다
	self.hoverTargets = {} :: { any }
	self.hoverGui = nil :: GuiObject?
	self.hoverPaint = nil :: ((boolean) -> ())?
	self.sideKey = nil :: string?
	-- 파티 편성 창(화면 가운데) 상태. 코드는 파일 끝 '파티 편성 창' 절
	self.partyOpen = false
	self.partyHover = {} :: { any }
	self.party = { Units = {}, Brush = nil, Selected = nil, Lifted = false, Data = nil, PresetKey = nil, Confirm = nil, Msg = "", Valid = false, ServerMsg = "" } :: any
	-- 클라이언트에도 카드 풀을 등록한다(순수 자료). 카드 탭이 직업 카드 전부를 보여 준다.
	AbilityCards.Register()
	self:_build()
	RunService.RenderStepped:Connect(function()
		self:_pollHover()
	end)

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
		if self.partyOpen then
			if state and state.Message and state.Message ~= "" and state.Message ~= self.party.ServerMsg then
				self.party.ServerMsg = state.Message
				self.party.Msg = state.Message
			end
			self:_partyRefresh()
		end
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

	-- 곁 창(패널 오른쪽): 편성 탭 = 직업 정보, 카드 탭 = 올린 카드
	local side = make("ScrollingFrame", {
		Name = "Side",
		Size = UDim2.new(0, SIDE_WIDTH, 1, -120),
		Position = UDim2.fromOffset(12 + PANEL_WIDTH + 10, 100),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, side)
	make("UIStroke", { Color = LINE, Thickness = 1 }, side)
	self.side = side
	self.sideBody = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, side)
	self:_buildParty()
end

function DebugBattlePanel:SetOpen(open: boolean)
	self.open = open
	self.panel.Visible = open
	self.partyOpen = false
	self.pw.Win.Visible = false
	self.side.Position = UDim2.fromOffset(12 + PANEL_WIDTH + 10, 100)
	self.side.Visible = false
	self.sideKey = nil
	self.hoverGui = nil
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
local function stepper(parent: Instance, order: number, text: string, value: string, steps: { { any } }, onStep: (any) -> ()): Frame
	local line = row(parent, order)
	label(line, text, 118, 1, DIM)
	label(line, value, 62, 2, GOLD, Enum.TextXAlignment.Center)
	for index, step in steps do
		button(line, step[2], math.floor((PANEL_WIDTH - 60 - 118 - 62 - 5 * (#steps + 1)) / #steps), nil, function()
			onStep(step[1])
		end, 2 + index)
	end
	return line
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
	self.hoverTargets = {}
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
	local partyLine = row(top, 2, 34)
	button(partyLine, "파티 편성 — 직업·배치·카드·프리셋 (화면 가운데 창)", PANEL_WIDTH - 60, C(70, 56, 110), function()
		self:SetPartyOpen(true)
	end, 1)

	-- 직업 세 칸씩(조건부 획득 직업은 자물쇠 — 디버그로는 고를 수 있다)
	local classes = section("직업  <font color=\"rgb(150,154,170)\" size=\"12\">바꾸면 카드 빌드가 비워진다 · 🔒 조건부 획득(디버그로 열림)</font>")
	local rows = math.ceil(#(state.Classes or {}) / 3)
	local grid = make("Frame", { Size = UDim2.new(1, 0, 0, rows * 46 + (rows - 1) * 5), BackgroundTransparency = 1, LayoutOrder = 1 }, classes)
	make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -4, 0, 46), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for index, entry in state.Classes or {} do
		local picked = entry.Id == config.ClassId
		-- 고른 직업은 어두운 바탕에 직업색을 조금 섞고 테두리를 직업색으로(밝은 직업색 위 흰 글자는 안 읽힌다)
		local b = button(grid, string.format('%s%s\n<font size="11" color="rgb(170,174,190)">%s</font>', if entry.Conditional then "🔒 " else "", entry.Name, if entry.Conditional then (entry.Hall or "조건부 획득") else (entry.Role or "")), 0, if picked then CARD:Lerp(entry.Color, 0.28) else nil, function()
			patch({ ClassId = entry.Id })
		end, index)
		if picked then
			make("UIStroke", { Color = entry.Color, Thickness = 2 }, b)
		end
		-- 올리면 곁 창이 그 직업 정보로(떼면 고른 직업으로 돌아온다)
		table.insert(self.hoverTargets, {
			Gui = b,
			Key = "class:" .. entry.Id,
			Show = function()
				self:_showClass(entry.Id)
			end,
		})
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
	toggle(cheats, 2, "재사용 대기 없음", config.NoCooldown, function(value)
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
	button(b, "재사용 대기 초기화", 110, nil, function()
		send({ Kind = "ClearCooldowns" })
	end, 2)
	button(b, "나 회복", 80, nil, function()
		send({ Kind = "HealAll" })
	end, 3)
	button(b, "적도 회복", 80, nil, function()
		send({ Kind = "HealAll", Enemies = true })
	end, 4)

	-- 파티 세션: 아군 유닛 고르기 줄(행동 순서대로 ①②③). 자원 주기 · 상태이상 '고른 유닛' · 체력이 이 유닛에 걸린다
	local members: { any } = {}
	local pickedMember: any = nil
	local circled = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩" }
	local function className(classId: string): string
		for _, classEntry in state.Classes or {} do
			if classEntry.Id == classId then
				return classEntry.Name
			end
		end
		return classId
	end
	if snapshot and snapshot.PartyMode and snapshot.Party then
		local rank: { [string]: number } = {}
		for index, id in snapshot.Party.Order or {} do
			rank[id] = index
		end
		members = table.clone(snapshot.Party.Members or {})
		table.sort(members, function(m1, m2)
			return (rank[m1.Id] or 99) < (rank[m2.Id] or 99)
		end)
		for _, member in members do
			if member.Id == self.partyUnit then
				pickedMember = member
			end
		end
		pickedMember = pickedMember or members[1]
		local box = section('조종할 아군  <font size="12" color="rgb(150,154,170)">자원 주기 · 상태이상 · 체력이 이 유닛에 걸린다</font>')
		local line = row(box, 1, 34)
		local width = math.floor((PANEL_WIDTH - 60 - 5 * (#members - 1)) / math.max(#members, 1))
		for index, member in members do
			button(line, string.format("%s %s", circled[index] or tostring(index), className(member.ClassId)), width, if member == pickedMember then BLUE else nil, function()
				self.partyUnit = member.Id
				self:_refresh()
			end, index)
		end
	end
	local pickedId: string? = pickedMember and pickedMember.Id

	if snapshot then
		local me = if #members == 0 then snapshot.Units and snapshot.Units.player else nil
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
		if #members > 0 then
			local mine = section("아군 체력")
			for index, member in members do
				local unit = snapshot.Units[member.Id]
				if not unit then
					continue
				end
				local line = row(mine, index, 28)
				label(line, string.format("%s %s", circled[index] or "", className(member.ClassId)), 96, 1, if member == pickedMember then GOLD else TEXT)
				label(line, if unit.Alive then string.format("%d/%d", unit.Health, unit.MaxHealth) else "쓰러짐", 76, 2, GOLD)
				button(line, "1", 34, nil, function()
					send({ Kind = "SetHealth", Id = member.Id, UnitId = member.Id, Value = 1 })
				end, 3)
				button(line, "절반", 44, nil, function()
					send({ Kind = "SetHealth", Id = member.Id, UnitId = member.Id, Value = math.floor(unit.MaxHealth / 2) })
				end, 4)
				button(line, "가득", 44, nil, function()
					send({ Kind = "SetHealth", Id = member.Id, UnitId = member.Id, Value = unit.MaxHealth })
				end, 5)
				button(line, "처치", 52, BAD, function()
					send({ Kind = "KillEnemy", Id = member.Id, UnitId = member.Id })
				end, 6)
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
		local resources = ClassResources.ForClass(if pickedMember then pickedMember.ClassId else (snapshot.AllyClassId or state.Config.ClassId))
		if #resources > 0 then
			local box = section("자원 주기")
			local stacks = if pickedMember then (pickedMember.Status and pickedMember.Status.Stacks or {}) else (snapshot.AllyStatus and snapshot.AllyStatus.Stacks or {})
			for index, id in resources do
				local line = row(box, index, 26)
				label(line, ClassResources.Label(id), 110, 1)
				label(line, tostring(stacks[id] or 0), 40, 2, GOLD, Enum.TextXAlignment.Center)
				for step, amount in { -1, 1, 5 } do
					button(line, if amount > 0 then "+" .. amount else tostring(amount), 56, nil, function()
						send({ Kind = "GiveStack", Id = id, Amount = amount, UnitId = pickedId })
					end, 2 + step)
				end
			end
		end
	end

	local status = section("상태이상 걸기")
	local targetOptions = if pickedId
		then { { "Enemies", "적 전체" }, { "Ally", "고른 유닛" }, { "AllAllies", "아군 전체" } }
		else { { "Enemies", "적 전체" }, { "Ally", "나" } }
	choice(status, 1, targetOptions, self.statusTarget, function(value)
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
			send({ Kind = "ApplyStatus", Target = self.statusTarget, Status = entry[1], Amount = entry[3], UnitId = pickedId })
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
		local points = state.Stats[id] or 0
		local line = stepper(stats, index, definition and definition.Name or id, tostring(points), { { -5, "−5" }, { -1, "−1" }, { 1, "+1" }, { 5, "+5" } }, function(step)
			send({ Kind = "SpendStat", StatId = id, Amount = step })
		end)
		-- 올리면 곁 창에 이 스탯의 효과와 영향 받는 직업(카드 줄과 같은 칠)
		line.BackgroundColor3 = C(70, 58, 112)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, line)
		local lit = make("UIStroke", { Color = GOLD, Thickness = 1.5, Enabled = false }, line)
		table.insert(self.hoverTargets, {
			Gui = line,
			Key = string.format("stat:%s:%d", id, points),
			Show = function()
				self:_showStat(id, points)
			end,
			Paint = function(on: boolean)
				line.BackgroundTransparency = if on then 0.2 else 1
				lit.Enabled = on
			end,
		})
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
			-- 마우스를 올린 줄: 보라 바탕 + 금색 테두리(곁 창에 뜬 카드가 어느 줄인지)
			line.BackgroundColor3 = C(70, 58, 112)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, line)
			local lit = make("UIStroke", { Color = GOLD, Thickness = 1.5, Enabled = false }, line)
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
			-- 줄 전체(− + 최대 버튼 포함)가 호버 자리. 레벨이 바뀌면 키가 달라져 곁 창을 다시 그린다
			table.insert(self.hoverTargets, {
				Gui = line,
				Key = string.format("card:%s:%d", card.Id, level),
				Show = function()
					self:_showCard(card, level, maxLevel)
				end,
				Paint = function(on: boolean)
					line.BackgroundTransparency = if on then 0.2 else 1
					lit.Enabled = on
					name.TextColor3 = if on then Color3.new(1, 1, 1) elseif have then TEXT else DIM
				end,
			})
		end
	end
end

--=== 곁 창 ===--

local function inside(gui: GuiObject, point: Vector2): boolean
	local at, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= at.X and point.X < at.X + size.X and point.Y >= at.Y and point.Y < at.Y + size.Y
end

-- 매 프레임: 마우스 아래 호버 대상을 칠하고, 곁 창에 보일 것(키)이 바뀌면 다시 그린다
function DebugBattlePanel:_pollHover()
	if not self.open then
		return
	end
	if self.partyOpen then
		self:_pollPartyHover()
		return
	end
	-- AbsolutePosition 은 IgnoreGuiInset 이어도 상단바 아래가 원점이고, GetMouseLocation 은 화면 맨 위가 원점이다 —
	-- 상단바 높이를 빼야 같은 기준이 된다(2026-10-31 사용자: "마우스를 올리면 2~3칸 아래 카드가 호버된다")
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local found = nil
	if inside(self.body, mouse) then
		for _, target in self.hoverTargets do
			if target.Gui.Parent and inside(target.Gui, mouse) then
				found = target
				break
			end
		end
	end
	local gui = found and found.Gui
	if gui ~= self.hoverGui then
		if self.hoverPaint then
			self.hoverPaint(false)
		end
		self.hoverGui = gui
		self.hoverPaint = found and found.Paint
		if self.hoverPaint then
			self.hoverPaint(true)
		end
	end
	local key, show = nil, nil
	if found then
		key, show = found.Key, found.Show
	elseif self.tab == "Setup" and self.state then
		local classId = self.state.Config.ClassId
		key, show = "class:" .. classId, function()
			self:_showClass(classId)
		end
	end
	if key ~= self.sideKey then
		self.sideKey = key
		if show then
			show()
		else
			self.side.Visible = false
		end
	end
end

-- 곁 창을 비우고 세로 목록 하나를 연다
function DebugBattlePanel:_sideReset(): Frame
	for _, child in self.sideBody:GetChildren() do
		child:Destroy()
	end
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.sideBody)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
	}, self.sideBody)
	self.side.CanvasPosition = Vector2.zero
	self.side.Visible = true
	return self.sideBody
end

-- 폭을 다 쓰고 높이는 글에 맞추는 글 한 덩이
local function text(parent: Instance, content: string, order: number, size: number?, color: Color3?, bold: boolean?): TextLabel
	return make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = color or TEXT,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		TextSize = size or 13,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LineHeight = 1.1,
		LayoutOrder = order,
	}, parent)
end

-- 어두운 상자(색 테두리). 안에 text 를 차례로 붙인다
local function tile(parent: Instance, order: number, accent: Color3): Frame
	local box = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, box)
	make("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.55 }, box)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 8),
	}, box)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, box)
	return box
end

local function heading(parent: Instance, content: string, order: number)
	text(parent, content, order, 14, GOLD, true)
end

local function hexOf(color: Color3): string
	return "#" .. color:ToHex()
end

local function dim(content: string): string
	return string.format('<font color="%s">%s</font>', hexOf(DIM), content)
end

-- 스킬·패시브 글: [키워드] 하늘색 · `스킬` 굵게 · 숫자 노랑(CardView 와 같은 칠)
local function rich(content: string): string
	return CardView.Highlight(content)
end

-- 직업 정보: 액티브(1·2·3번 · 강화 · [집중력] 변형) · 패시브 · 전용 상태
function DebugBattlePanel:_showClass(classId: string)
	if not CharacterDefinitions.IsValid(classId) then
		self.side.Visible = false
		return
	end
	local def = CharacterDefinitions.Get(classId)
	local body = self:_sideReset()
	local picked = self.state and self.state.Config.ClassId == classId
	text(body, string.format('<font color="%s">%s</font>  <font size="13" color="%s">%s</font>', hexOf(def.Color), def.Name, hexOf(DIM), def.Role), 1, 20, TEXT, true)
	text(body, string.format("%s체력 %d · 무기 %d%s", if picked then "" else dim("(미리보기) "), def.MaxHealth, def.BasicPower, if def.Conditional then dim(" · 🔒 " .. (def.Hall or "조건부 획득")) else ""), 2, 12, DIM)
	text(body, def.Description, 3, 13, TEXT)

	local skills: { { any } } = {}
	for index, skill in BattleSkills.ForClass(classId) do
		table.insert(skills, { skill, string.format("%d번", index) })
	end
	for _, skill in BattleSkills.Upgrades() do
		if skill.ClassId == classId then
			table.insert(skills, { skill, "강화" })
		end
	end
	for _, skill in BattleSkills.Focus() do
		if skill.ClassId == classId then
			table.insert(skills, { skill, "변형" })
		end
	end
	heading(body, string.format("액티브  %s", dim(string.format("%d개", #skills))), 10)
	for index, entry in skills do
		local skill = entry[1]
		local box = tile(body, 10 + index, def.Color)
		text(box, string.format('<font color="%s">%s</font>  %s', hexOf(def.Color), entry[2], skill.Name), 1, 14, TEXT, true)
		local stats = { BattleSkills.RangeLabel(skill), BattleSkills.ShapeText(skill) }
		if (skill.Damage or 0) > 0 then
			table.insert(stats, string.format('피해 <font color="%s"><b>%s</b></font>%s', hexOf(GOLD), fmt(skill.Damage), if skill.HitWeights then string.format(" (%d연타)", #skill.HitWeights) else ""))
		end
		if (skill.Cooldown or 0) > 0 then
			table.insert(stats, string.format("재사용 %d턴", skill.Cooldown))
		end
		if ((skill :: any).Stamina or 0) > 0 then
			table.insert(stats, string.format("스테미나 %d", (skill :: any).Stamina))
		end
		text(box, table.concat(stats, "  ·  "), 2, 12, DIM)
		if skill.Description and skill.Description ~= "" then
			text(box, rich(skill.Description), 3, 13, TEXT)
		end
	end

	local kit = ClassPassives.Get(classId)
	local passives = kit and kit.Passives or {}
	heading(body, string.format("패시브  %s", dim(string.format("%d개", #passives))), 100)
	for index, passive in passives do
		local box = tile(body, 100 + index, GOLD)
		text(box, passive.Name, 1, 14, TEXT, true)
		text(box, rich(passive.Description), 2, 13, TEXT)
	end

	local statuses = kit and kit.StatusKeywords or {}
	if #statuses > 0 then
		heading(body, "전용 상태", 200)
		for index, id in statuses do
			local keyword = Keywords.Get(id)
			if keyword then
				local box = tile(body, 200 + index, C(120, 200, 255))
				text(box, keyword.Name, 1, 13, C(120, 200, 255), true)
				text(box, keyword.Description, 2, 12, DIM)
			end
		end
	end
end

--[[
	카드 글을 칠한다: 지금 레벨 값은 노랑, 다음 레벨 값은 초록 "▸값", [키워드] 하늘색, `스킬` 굵게.
	`AbilityCardDefinitions.Describe` 는 대괄호를 벗겨 키워드 색이 사라지므로 여기서 따로 칠한다.
	없는 카드(level 0)는 Lv1 값을 보인다.
]]
local function cardText(entry: any, level: number, maxLevel: number): string
	local now = math.max(level, 1)
	local nextLevel = if level >= 1 and level < maxLevel then level + 1 else nil
	local content = CardView.BreakSentences(entry.Description or "")
	content = content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	local slot = 0
	content = content:gsub("{([%d%.%-]+)}(%%?)", function(shown: string, unit: string): string
		slot += 1
		local ladder = entry.Levels and entry.Levels[slot]
		if not ladder or #ladder == 0 then
			return string.format('<font color="%s"><b>%s%s</b></font>', hexOf(GOLD), shown, unit)
		end
		local out = string.format('<font color="%s"><b>%s%s</b></font>', hexOf(GOLD), fmt(ladder[math.min(now, #ladder)]), unit)
		if nextLevel and ladder[nextLevel] then
			out ..= string.format('<font color="rgb(120,220,140)" size="12"> ▸%s%s</font>', fmt(ladder[nextLevel]), unit)
		end
		return out
	end)
	content = content:gsub("%[([^%]]+)%]", '<font color="rgb(120,200,255)">%1</font>')
	content = content:gsub("`([^`]+)`", "<b>%1</b>")
	return content
end

-- 사다리마다 글에서 그 자리 바로 앞 몇 글자(무엇의 값인지)와 뒤 단위(%)
local function ladderLabels(description: string): { { string } }
	local labels = {}
	local last = 1
	for start, finish in description:gmatch("(){[%d%.%-]+}()") do
		local before = description:sub(last, start - 1):gsub("[%[%]`]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		local length = utf8.len(before) or #before
		if length > 12 then
			before = "…" .. before:sub(utf8.offset(before, length - 11) or 1)
		end
		table.insert(labels, { before, if description:sub(finish, finish) == "%" then "%" else "" })
		last = finish
	end
	return labels
end

-- 카드: 실제 카드 모양 + 지금/다음 값 칠한 효과 + 레벨별 수치 + 키워드 풀이 + 배타·파티
-- 스탯: 효과(1점당 → 지금)와 영향 받는 직업(Shared.StatInfo — 그리는 건 StatTooltip)
function DebugBattlePanel:_showStat(statId: string, points: number, classId: string?)
	local body = self:_sideReset()
	local box = tile(body, 1, GOLD)
	StatTooltip.Fill(box, statId, points, classId or (self.state and self.state.Config.ClassId))
end

function DebugBattlePanel:_showCard(entry: any, level: number, maxLevel: number)
	local body = self:_sideReset()
	local holder = make("Frame", { Size = UDim2.fromOffset(250, 350), BackgroundTransparency = 1, LayoutOrder = 1 }, body)
	CardView.Build(holder, {
		Id = entry.Id,
		Name = entry.Name,
		Grade = entry.Grade,
		ClassId = entry.ClassId,
		Tags = entry.Tags,
		Art = entry.Art,
		Level = level,
		MaxLevel = maxLevel,
		Description = AbilityCardDefinitions.Describe(entry, math.max(level, 1)),
	}, { TextSize = 15 })

	local state = if level == 0 then "보유 안 함 — Lv1 값" elseif level >= maxLevel then string.format("Lv %d/%d 최대", level, maxLevel) else string.format("Lv %d/%d · 초록 ▸ = Lv %d", level, maxLevel, level + 1)
	local effect = tile(body, 2, CardView.GRADE_STYLE[entry.Grade] and CardView.GRADE_STYLE[entry.Grade].Edge or GOLD)
	text(effect, string.format("효과  %s", dim(state)), 1, 13, GOLD, true)
	text(effect, cardText(entry, level, maxLevel), 2, 14, TEXT)

	local ladders = entry.Levels or {}
	if #ladders > 0 then
		local table_ = tile(body, 3, GOLD)
		text(table_, "레벨별 수치", 1, 13, GOLD, true)
		local labels = ladderLabels(entry.Description or "")
		for slot, ladder in ladders do
			local cells = {}
			for at, value in ladder do
				local shown = fmt(value) .. (labels[slot] and labels[slot][2] or "")
				if at == level then
					shown = string.format('<font color="%s"><b><u>%s</u></b></font>', hexOf(GOLD), shown)
				elseif at == level + 1 then
					shown = string.format('<font color="rgb(120,220,140)">%s</font>', shown)
				else
					shown = dim(shown)
				end
				table.insert(cells, shown)
			end
			local caption = labels[slot] and labels[slot][1] or ""
			text(table_, dim(if caption ~= "" then caption else "수치 " .. slot), 2 * slot, 11, DIM)
			text(table_, table.concat(cells, dim("  ·  ")), 2 * slot + 1, 13, TEXT)
		end
	end

	local shown = 0
	for _, name in Keywords.Mentioned(entry.Description or "") do
		local keyword = Keywords.ByName(name)
		if keyword and shown < 6 then
			shown += 1
			local box = tile(body, 10 + shown, C(120, 200, 255))
			text(box, keyword.Name, 1, 13, C(120, 200, 255), true)
			text(box, keyword.Description, 2, 12, DIM)
		end
	end

	local notes = {}
	if entry.Party then
		table.insert(notes, "파티 전제 — 혼자면 효과가 없거나 약하다.")
	end
	if entry.Excludes and #entry.Excludes > 0 then
		local names = {}
		for _, id in entry.Excludes do
			local other = AbilityCardDefinitions.Get(id)
			table.insert(names, other and other.Name or id)
		end
		table.insert(notes, "배타 — 함께 들 수 없음: " .. table.concat(names, ", "))
	end
	if #notes > 0 then
		local box = tile(body, 30, BAD)
		text(box, table.concat(notes, "\n"), 1, 12, TEXT)
	end
end

--=== 파티 편성 창 (화면 가운데) ===--
--[[
	2026-11-08 사용자: "프리셋 저장 기능을 만들어두고, 예시 프리셋으로 3개정도 · F2 디버그 패널에서 전부 다 조정 할 수 있어야 해.
	왼쪽 패널에만 안 떠도 되고, 화면 가운데에 떠도 되니까." · "한계 코스트를 8로 설정 후, 각 코스트에 맞춰 직업들을 배치."
	사양: 파티전투_사양.md 4·5절. 열기: 편성 탭의 [파티 편성]. 시작하면 서버에 StartParty { Party = { Units } } 를 보낸다.

	  왼쪽   직업 목록(코스트·역할, 올리면 코스트 근거) → 고르고 칸을 눌러 놓는다
	  가운데 6×3 아군 격자(왼쪽이 뒤열 x=6, 오른쪽이 앞열 x=1) · 칸마다 행동 순번 · 놓인 유닛을 누르면 오른쪽에서 편집
	         (눌러서 든 상태에서 다른 칸을 누르면 옮기고, 유닛이 있는 칸이면 자리를 바꾼다)
	  오른쪽 고른 유닛의 레벨 · 카드(레벨 올리고 내리기·빼기·무작위·지우기, 올리면 카드 미리보기)
	  아래   프리셋 줄(예시 3개 + 저장분) · 이름 · 저장/불러오기/지우기 · 파티 전투 시작
]]

local DEFAULT_UNIT_LEVEL = 15
local RED_TEXT = "rgb(255,120,120)"

local function copyUnit(unit: any): any
	local cards = {}
	for _, card in unit.Cards or {} do
		table.insert(cards, { CardId = card.CardId, Level = card.Level })
	end
	local stats = {}
	for id, points in unit.Stats or {} do
		if points > 0 then
			stats[id] = points
		end
	end
	return { ClassId = unit.ClassId, X = unit.X, Y = unit.Y, Level = unit.Level or DEFAULT_UNIT_LEVEL, Cards = cards, Stats = stats }
end

local function spentStats(unit: any): number
	local total = 0
	for _, points in unit.Stats or {} do
		total += points
	end
	return total
end

local function copyUnits(units: { any }): { any }
	local out = {}
	for _, unit in units do
		table.insert(out, copyUnit(unit))
	end
	return out
end

local function partyCost(units: { any }): number
	local total = 0
	for _, unit in units do
		total += PartyDefinitions.Cost(unit.ClassId) or 0
	end
	return total
end

function DebugBattlePanel:_buildParty()
	local win = make("Frame", {
		Name = "PartyWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Visible = false,
	}, self.Gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, win)
	make("UIStroke", { Color = LINE, Thickness = 1 }, win)
	make("UISizeConstraint", { MinSize = Vector2.new(900, 520), MaxSize = Vector2.new(1180, 740) }, win)
	-- 곁 창(카드 미리보기)이 이 창 위에 뜨도록
	self.side.ZIndex = 5
	local pw: any = { Win = win, Cells = {} }
	self.pw = pw

	make("TextLabel", {
		Size = UDim2.fromOffset(130, 26),
		Position = UDim2.fromOffset(14, 10),
		BackgroundTransparency = 1,
		Text = "파티 편성",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, win)
	pw.Cost = make("TextLabel", {
		Size = UDim2.fromOffset(190, 26),
		Position = UDim2.fromOffset(150, 10),
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, win)
	-- 편성 레벨(디버그): 실제 유닛 레벨 = 유닛 레벨 + 편성 레벨. 파티 승리마다 +1
	pw.PartyLevel = make("TextLabel", {
		Size = UDim2.fromOffset(118, 26),
		Position = UDim2.fromOffset(346, 10),
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, win)
	for index, step in { -1, 1 } do
		local b = make("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(466 + (index - 1) * 30, 10),
			BackgroundColor3 = C(44, 48, 62),
			BorderSizePixel = 0,
			Text = if step < 0 then "−" else "+",
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
		}, win)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		b.Activated:Connect(function()
			send({ Kind = "SetPartyLevel", Value = math.max(0, (self.state and self.state.PartyLevel or 0) + step) })
		end)
	end
	pw.Reason = make("TextLabel", {
		Size = UDim2.new(1, -560, 0, 26),
		Position = UDim2.fromOffset(520, 10),
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, win)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -10, 0, 8),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = DIM,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, win)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	close.Activated:Connect(function()
		self:SetOpen(false)
	end)

	-- 왼쪽: 직업 목록 + 코스트 근거
	local left = make("Frame", { Position = UDim2.fromOffset(10, 48), Size = UDim2.new(0, 236, 1, -224), BackgroundTransparency = 1 }, win)
	pw.ClassList = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -168),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, left)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, pw.ClassList)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, pw.ClassList)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, pw.ClassList)
	pw.Tip = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 160),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "",
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, left)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, pw.Tip)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, pw.Tip)

	-- 가운데: 6×3 아군 격자
	local mid = make("Frame", { Position = UDim2.fromOffset(256, 48), Size = UDim2.new(1, -636, 1, -224), BackgroundTransparency = 1 }, win)
	make("TextLabel", {
		Size = UDim2.new(0.5, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "◀ 뒤열 (x=6)",
		TextColor3 = DIM,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, mid)
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "앞열 (x=1) ▶ 적",
		TextColor3 = DIM,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, mid)
	local grid = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 3 * 66), BackgroundTransparency = 1 }, mid)
	for x = 1, BattleGrid.DEFAULT_WIDTH do
		pw.Cells[x] = {}
		for y = 1, BattleGrid.DEFAULT_HEIGHT do
			local cell = make("TextButton", {
				Size = UDim2.new(1 / 6, -4, 0, 62),
				Position = UDim2.new((BattleGrid.DEFAULT_WIDTH - x) / 6, 2, 0, (y - 1) * 66),
				BackgroundColor3 = C(40, 44, 56),
				BorderSizePixel = 0,
				Text = "",
				RichText = true,
				TextColor3 = DIM,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextWrapped = true,
			}, grid)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, cell)
			local stroke = make("UIStroke", { Color = GOLD, Thickness = 2, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
			cell.Activated:Connect(function()
				self:_partyCell(x, y)
			end)
			pw.Cells[x][y] = { Button = cell, Stroke = stroke }
		end
	end
	local info = make("Frame", { Position = UDim2.fromOffset(0, 24 + 3 * 66 + 8), Size = UDim2.new(1, 0, 1, -(24 + 3 * 66 + 8)), BackgroundTransparency = 1 }, mid)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, info)
	local function infoText(order: number, color: Color3): TextLabel
		return make("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = "",
			RichText = true,
			TextColor3 = color,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		}, info)
	end
	pw.Order = infoText(1, TEXT)
	pw.Hint = infoText(2, DIM)

	-- 오른쪽: 고른 유닛 편집
	pw.Editor = make("ScrollingFrame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 48),
		Size = UDim2.new(0, 360, 1, -224),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, win)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, pw.Editor)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, pw.Editor)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, pw.Editor)

	-- 아래: 프리셋 줄
	local bottom = make("Frame", { Position = UDim2.new(0, 10, 1, -166), Size = UDim2.new(1, -20, 0, 156), BackgroundTransparency = 1 }, win)
	pw.Persist = make("TextLabel", {
		Size = UDim2.new(1, -430, 0, 18),
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = DIM,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bottom)
	pw.PresetList = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -430, 1, -20),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, bottom)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, pw.PresetList)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, pw.PresetList)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, pw.PresetList)

	local controls = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 420, 1, 0), BackgroundTransparency = 1 }, bottom)
	pw.NameBox = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "프리셋 이름 (40자까지)",
		PlaceholderColor3 = DIM,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, controls)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, pw.NameBox)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, pw.NameBox)
	pw.NameBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.party.Confirm = nil
		pw.Save.Text = "저장"
	end)
	local actions = make("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, controls)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, actions)
	pw.Save = button(actions, "저장", 140, C(60, 110, 70), function()
		self:_partySave()
	end, 1)
	button(actions, "불러오기", 130, nil, function()
		self:_partyLoad()
	end, 2)
	button(actions, "지우기", 130, nil, function()
		self:_partyDelete()
	end, 3)
	pw.Start = button(make("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, controls), "파티 전투 시작", 420, BAD, function()
		self:_partyStart()
	end, 1)
	-- 안내·오류 글(예시 설명이 길어서 스크롤)
	local msgBox = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = LINE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, controls)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, msgBox)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, msgBox)
	pw.Msg = make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, msgBox)
end

function DebugBattlePanel:SetPartyOpen(open: boolean)
	if open and not self.state then
		return
	end
	self.partyOpen = open
	self.pw.Win.Visible = open
	self.panel.Visible = self.open and not open
	-- 카드 미리보기는 창 왼쪽 가장자리에 띄운다(오른쪽 열 위에서 올려 보므로 가리지 않는다)
	self.side.Position = if open then UDim2.fromOffset(12, 60) else UDim2.fromOffset(12 + PANEL_WIDTH + 10, 100)
	self.side.Visible = false
	self.sideKey = nil
	self.hoverGui = nil
	self.hoverPaint = nil
	if open then
		self:_partyRefresh()
		if not self.party.Data then
			self:_presetCall({ Op = "List" })
		end
	end
end

--=== 편성 상태 ===--

function DebugBattlePanel:_partyUnitAt(x: number, y: number): any
	for _, unit in self.party.Units do
		if unit.X == x and unit.Y == y then
			return unit
		end
	end
	return nil
end

function DebugBattlePanel:_partyUnitOf(classId: string?): any
	for _, unit in self.party.Units do
		if unit.ClassId == classId then
			return unit
		end
	end
	return nil
end

function DebugBattlePanel:_partyMsg(content: string, bad: boolean?)
	self.party.Msg = if bad then string.format('<font color="%s">%s</font>', RED_TEXT, content) else content
	self.pw.Msg.Text = self.party.Msg
end

function DebugBattlePanel:_partyClass(classId: string): any
	for _, entry in self.state.Classes or {} do
		if entry.Id == classId then
			return entry
		end
	end
	return nil
end

-- 칸을 눌렀을 때: 놓기(직업을 고른 채) · 고르기 · 든 유닛 옮기기/자리 바꾸기
function DebugBattlePanel:_partyCell(x: number, y: number)
	local p = self.party
	local at = self:_partyUnitAt(x, y)
	if p.Brush then
		if at then
			self:_partyMsg("직업은 빈 칸에 놓습니다.", true)
			return
		end
		local existing = self:_partyUnitOf(p.Brush)
		if existing then
			existing.X, existing.Y = x, y
		else
			table.insert(p.Units, { ClassId = p.Brush, X = x, Y = y, Level = DEFAULT_UNIT_LEVEL, Cards = {} })
		end
		p.Selected, p.Brush, p.Lifted = p.Brush, nil, false
	elseif at then
		local lifted = self:_partyUnitOf(p.Selected)
		if p.Lifted and lifted and lifted ~= at then
			lifted.X, lifted.Y, at.X, at.Y = at.X, at.Y, lifted.X, lifted.Y
			p.Lifted = false
		elseif p.Lifted and lifted == at then
			p.Lifted = false
		else
			p.Selected, p.Lifted = at.ClassId, true
		end
	else
		local lifted = self:_partyUnitOf(p.Selected)
		if p.Lifted and lifted then
			lifted.X, lifted.Y = x, y
			p.Lifted = false
		end
	end
	self:_partyRefresh()
end

function DebugBattlePanel:_partyRemove(classId: string)
	local p = self.party
	for index, unit in p.Units do
		if unit.ClassId == classId then
			table.remove(p.Units, index)
			break
		end
	end
	if p.Selected == classId then
		p.Selected, p.Lifted = nil, false
	end
	self:_partyRefresh()
end

local function setCardLevel(unit: any, cardId: string, level: number)
	for index, card in unit.Cards do
		if card.CardId == cardId then
			if level <= 0 then
				table.remove(unit.Cards, index)
			else
				card.Level = level
			end
			return
		end
	end
	if level > 0 then
		table.insert(unit.Cards, { CardId = cardId, Level = level })
	end
end

-- 무작위 카드 5장(서로 배타인 카드는 피한다)
local function randomCards(classId: string): { any }
	local rng = Random.new()
	local all: { any } = {}
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
			table.insert(all, card)
		end
	end
	local picked: { any } = {}
	local blocked: { [string]: boolean } = {}
	while #all > 0 and #picked < 5 do
		local card = table.remove(all, rng:NextInteger(1, #all))
		if not blocked[card.Id] then
			table.insert(picked, { CardId = card.Id, Level = rng:NextInteger(1, AbilityCardDefinitions.MaxLevelFor(card)) })
			for _, other in card.Excludes or {} do
				blocked[other] = true
			end
		end
	end
	return picked
end

--=== 그리기 ===--

function DebugBattlePanel:_partyRefresh()
	if not self.partyOpen or not self.state then
		return
	end
	local pw, p = self.pw, self.party
	local state = self.state
	self.partyHover = {}
	self.hoverGui = nil
	self.hoverPaint = nil

	local total = partyCost(p.Units)
	local ok, reason = PartyDefinitions.Validate(p.Units)
	p.Valid = ok
	pw.PartyLevel.Text = string.format('편성 레벨 <font color="rgb(255,205,90)">%d</font>', state.PartyLevel or 0)
	-- 레벨이 줄어 포인트가 모자라진 유닛은 스탯을 되돌린다
	for _, unit in p.Units do
		if spentStats(unit) > ProgressionDefinitions.TotalStatPoints(math.min(state.MaxLevel or 60, unit.Level + (state.PartyLevel or 0))) then
			unit.Stats = {}
			p.Msg = "레벨이 줄어 포인트가 모자라 스탯을 되돌렸습니다."
		end
	end
	pw.Cost.Text = string.format('코스트 <font color="%s">%d</font> / %d', if total > PartyDefinitions.COST_LIMIT then RED_TEXT else "rgb(255,205,90)", total, PartyDefinitions.COST_LIMIT)
	pw.Reason.Text = if ok then "" elseif #p.Units == 0 then dim(reason or "") else string.format('<font color="%s">%s</font>', RED_TEXT, reason or "")
	pw.Start.BackgroundColor3 = if ok then BAD else C(70, 60, 64)
	pw.Msg.Text = p.Msg
	pw.Save.Text = if p.Confirm then "덮어쓰기? 한 번 더" else "저장"
	local data = p.Data
	pw.Persist.Text = if not data then "저장: 불러오는 중…" elseif data.Persistent then "저장: DataStore (DebugPartyPresets)" else '<font color="rgb(255,190,110)">저장: 이 서버 메모리만</font> — 서버를 닫으면 사라집니다'

	self:_partyClasses()
	self:_partyGrid()
	self:_partyEditor()
	self:_partyPresets()
	for _, d in self.pw.Win:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			d.AutoLocalize = false
		end
	end
end

function DebugBattlePanel:_partyTip(classId: string?)
	local tip = self.pw.Tip
	if not classId then
		tip.Text = dim("직업에 마우스를 올리면 역할과 코스트를 이렇게 정한 까닭이 보입니다.")
		return
	end
	local entry = self:_partyClass(classId)
	tip.Text = string.format(
		"<b>%s</b>  %s  ·  코스트 <b>%s</b>\n%s",
		if entry then entry.Name else classId,
		dim(PartyBalance.ROLES[classId] or ""),
		tostring(PartyDefinitions.Cost(classId) or "?"),
		PartyBalance.REASONS[classId] or ""
	)
end

function DebugBattlePanel:_partyClasses()
	local pw, p = self.pw, self.party
	for _, child in pw.ClassList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local order = 0
	for _, entry in self.state.Classes or {} do
		local cost = PartyDefinitions.Cost(entry.Id)
		if not cost then
			continue
		end
		order += 1
		local placed = self:_partyUnitOf(entry.Id) ~= nil
		local brush = p.Brush == entry.Id
		local b = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = if brush then BLUE elseif placed then CARD:Lerp(entry.Color, 0.28) else C(44, 48, 62),
			BorderSizePixel = 0,
			Text = string.format('<b>%s</b>   코스트 <font color="rgb(255,205,90)"><b>%d</b></font>\n<font size="11" color="rgb(170,174,190)">%s%s</font>', entry.Name, cost, PartyBalance.ROLES[entry.Id] or "", if placed then " · 배치됨" else ""),
			RichText = true,
			TextColor3 = TEXT,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		}, pw.ClassList)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
		if placed and p.Selected == entry.Id or brush then
			make("UIStroke", { Color = if brush then BLUE else GOLD, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		end
		b.Activated:Connect(function()
			if placed then
				p.Selected, p.Brush, p.Lifted = entry.Id, nil, false
			else
				p.Brush = if p.Brush == entry.Id then nil else entry.Id
				p.Lifted = false
			end
			self:_partyRefresh()
		end)
		table.insert(self.partyHover, {
			Gui = b,
			Area = pw.ClassList,
			Key = "class:" .. entry.Id,
			Show = function()
				self.side.Visible = false
				self:_partyTip(entry.Id)
			end,
		})
	end
	if not self.sideKey then
		self:_partyTip(nil)
	end
end

function DebugBattlePanel:_partyGrid()
	local pw, p = self.pw, self.party
	local orders: { [any]: number } = {}
	for index, unit in PartyDefinitions.ActionOrder(p.Units) do
		orders[unit] = index
	end
	for x = 1, BattleGrid.DEFAULT_WIDTH do
		for y = 1, BattleGrid.DEFAULT_HEIGHT do
			local cell = pw.Cells[x][y]
			local unit = self:_partyUnitAt(x, y)
			local button_ = cell.Button
			if unit then
				local entry = self:_partyClass(unit.ClassId)
				button_.BackgroundColor3 = if entry then CARD:Lerp(entry.Color, 0.4) else C(60, 64, 80)
				button_.TextColor3 = TEXT
				button_.Text = string.format('<font color="rgb(255,205,90)" size="14">%d</font>  %s\n<font size="11" color="rgb(200,204,216)">코스트 %d · 카드 %d</font>', orders[unit] or 0, if entry then entry.Name else unit.ClassId, PartyDefinitions.Cost(unit.ClassId) or 0, #unit.Cards)
				cell.Stroke.Enabled = p.Selected == unit.ClassId
				cell.Stroke.Color = if p.Lifted then BLUE else GOLD
			else
				button_.BackgroundColor3 = if p.Brush or p.Lifted then C(50, 56, 72) else C(40, 44, 56)
				button_.TextColor3 = DIM
				button_.Text = if x == 1 then "전열" elseif x == BattleGrid.DEFAULT_WIDTH then "후열" else ""
				cell.Stroke.Enabled = false
			end
		end
	end
	local names = {}
	for index, unit in PartyDefinitions.ActionOrder(p.Units) do
		local entry = self:_partyClass(unit.ClassId)
		table.insert(names, string.format("%d %s", index, if entry then entry.Name else unit.ClassId))
	end
	pw.Order.Text = if #names > 0 then "행동 순서  " .. table.concat(names, "  →  ") else dim("행동 순서  (유닛 없음)")
	pw.Hint.Text = if p.Brush then
		"고른 직업을 놓을 빈 칸을 누르세요. (왼쪽 목록에서 다시 누르면 취소)"
		elseif p.Lifted then "유닛을 들었습니다. 옮길 칸을 누르세요 (유닛이 있는 칸이면 자리 바꿈, 다시 누르면 놓기)."
		else "① 왼쪽에서 직업을 고르고 빈 칸을 눌러 놓는다  ② 놓인 유닛을 누르면 오른쪽에서 편집하고 든 상태가 된다  ③ 순번 = 행동 순서(행 위 → 아래, 같은 행은 왼쪽 → 오른쪽)"
end

local function stepRow(parent: Instance, order: number, caption: string, value: string, steps: { { any } }, onStep: (number) -> ()): Frame
	local line = row(parent, order, 30)
	label(line, caption, 70, 1, DIM)
	label(line, value, 52, 2, GOLD, Enum.TextXAlignment.Center)
	for index, step in steps do
		button(line, step[2], 48, nil, function()
			onStep(step[1])
		end, 2 + index)
	end
	return line
end

function DebugBattlePanel:_partyEditor()
	local pw, p = self.pw, self.party
	local editor = pw.Editor
	local scroll = editor.CanvasPosition
	for _, child in editor:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local unit = self:_partyUnitOf(p.Selected)
	if not unit then
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Text = "놓인 유닛을 누르면 여기서 레벨과 카드를 고칩니다.",
			TextColor3 = DIM,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
		}, editor)
		return
	end
	local entry = self:_partyClass(unit.ClassId)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = string.format('<font size="18" color="%s"><b>%s</b></font>  %s\n%s', hexOf(if entry then entry.Color else TEXT), if entry then entry.Name else unit.ClassId, dim((PartyBalance.ROLES[unit.ClassId] or "") .. " · 코스트 " .. tostring(PartyDefinitions.Cost(unit.ClassId) or "?")), dim(string.format("칸 (%d, %d)", unit.X, unit.Y))),
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, editor)
	local bonus = self.state.PartyLevel or 0
	local levelCap = self.state.MaxLevel or 60
	stepRow(editor, nextOrder(), "유닛 레벨", tostring(unit.Level), { { -5, "−5" }, { -1, "−1" }, { 1, "+1" }, { 5, "+5" } }, function(step)
		unit.Level = math.clamp(unit.Level + step, 1, levelCap)
		self:_partyRefresh()
	end)
	local actual = math.min(levelCap, unit.Level + bonus)
	local total = ProgressionDefinitions.TotalStatPoints(actual)
	local left = total - spentStats(unit)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = string.format('실제 레벨 <font color="rgb(255,205,90)"><b>%d</b></font> %s  ·  남은 스탯 포인트 <font color="%s"><b>%d</b></font> / %d', actual, dim(string.format("(유닛 %d + 편성 %d)", unit.Level, bonus)), if left < 0 then RED_TEXT else "rgb(255,205,90)", left, total),
		RichText = true,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, editor)
	unit.Stats = unit.Stats or {}
	for _, statId in StatDefinitions.Order do
		local definition = StatDefinitions.Get(statId)
		local points = unit.Stats[statId] or 0
		local line = row(editor, nextOrder(), 28)
		line.BackgroundColor3 = C(70, 58, 112)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, line)
		local lit = make("UIStroke", { Color = GOLD, Thickness = 1.5, Enabled = false }, line)
		label(line, if definition then definition.Name else statId, 90, 1, TEXT)
		label(line, tostring(points), 40, 2, GOLD, Enum.TextXAlignment.Center)
		for index, step in { -5, -1, 1, 5 } do
			button(line, if step > 0 then "+" .. step else "−" .. -step, 42, nil, function()
				local now = unit.Stats[statId] or 0
				local room = ProgressionDefinitions.TotalStatPoints(math.min(levelCap, unit.Level + bonus)) - spentStats(unit)
				local change = if step > 0 then math.min(step, math.max(room, 0)) else -math.min(-step, now)
				unit.Stats[statId] = if now + change > 0 then now + change else nil
				self:_partyRefresh()
			end, 2 + index)
		end
		table.insert(self.partyHover, {
			Gui = line,
			Area = editor,
			Key = string.format("stat:%s:%d", statId, points),
			Show = function()
				self:_showStat(statId, points, unit.ClassId)
			end,
			Paint = function(on: boolean)
				line.BackgroundTransparency = if on then 0.2 else 1
				lit.Enabled = on
			end,
		})
	end
	button(row(editor, nextOrder(), 28), "스탯 되돌리기", 120, nil, function()
		unit.Stats = {}
		self:_partyRefresh()
	end, 1)
	local actions = row(editor, nextOrder(), 30)
	button(actions, "무작위 카드", 96, C(60, 110, 70), function()
		unit.Cards = randomCards(unit.ClassId)
		self:_partyRefresh()
	end, 1)
	button(actions, "카드 모두 빼기", 104, nil, function()
		unit.Cards = {}
		self:_partyRefresh()
	end, 2)
	button(actions, "유닛 빼기", 84, BAD, function()
		self:_partyRemove(unit.ClassId)
	end, 3)

	local have: { [string]: number } = {}
	for _, card in unit.Cards do
		have[card.CardId] = card.Level
	end
	for _, grade in { "Essential", "Rare", "Common" } do
		local pool = AbilityCardDefinitions.GetPool(unit.ClassId, grade :: any)
		if #pool == 0 then
			continue
		end
		local style = CardView.GRADE_STYLE[grade]
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = string.format('<font color="#%s">%s</font>  %d장', style.Edge:ToHex(), style.Name, #pool),
			RichText = true,
			TextColor3 = GOLD,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
		}, editor)
		local sorted = table.clone(pool)
		table.sort(sorted, function(a, b)
			return a.Name < b.Name
		end)
		for _, card in sorted do
			local maxLevel = AbilityCardDefinitions.MaxLevelFor(card)
			local level = have[card.Id] or 0
			local line = row(editor, nextOrder(), 30)
			line.BackgroundColor3 = C(70, 58, 112)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, line)
			local lit = make("UIStroke", { Color = GOLD, Thickness = 1.5, Enabled = false }, line)
			local thumbHolder = make("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, line)
			CardView.Thumb(thumbHolder, card, 28)
			local name = label(line, card.Name, 108, 2, if level > 0 then TEXT else DIM)
			label(line, if level > 0 then string.format("Lv %d/%d", level, maxLevel) else string.format("−/%d", maxLevel), 50, 3, if level > 0 then GOLD else DIM, Enum.TextXAlignment.Center)
			button(line, "−", 26, nil, function()
				setCardLevel(unit, card.Id, level - 1)
				self:_partyRefresh()
			end, 4)
			button(line, "+", 26, nil, function()
				setCardLevel(unit, card.Id, math.min(level + 1, maxLevel))
				self:_partyRefresh()
			end, 5)
			button(line, "최대", 40, nil, function()
				setCardLevel(unit, card.Id, maxLevel)
				self:_partyRefresh()
			end, 6)
			table.insert(self.partyHover, {
				Gui = line,
				Area = editor,
				Key = string.format("card:%s:%d", card.Id, level),
				Show = function()
					self:_showCard(card, level, maxLevel)
				end,
				Paint = function(on: boolean)
					line.BackgroundTransparency = if on then 0.2 else 1
					lit.Enabled = on
					name.TextColor3 = if on then Color3.new(1, 1, 1) elseif level > 0 then TEXT else DIM
				end,
			})
		end
	end
	task.defer(function()
		editor.CanvasPosition = scroll
	end)
end

-- 프리셋 줄: 예시(지울 수 없음) 먼저, 그 뒤 저장분
local function presetEntries(data: any): { any }
	local entries = {}
	for index, example in (if data then data.Examples else PartyDefinitions.Examples()) or {} do
		table.insert(entries, { Key = "E:" .. index, Name = example.Name, Units = example.Units, Example = true, Note = example.Note })
	end
	for _, saved in (if data then data.Presets else nil) or {} do
		table.insert(entries, { Key = "S:" .. saved.Name, Name = saved.Name, Units = saved.Units, Example = false })
	end
	return entries
end

function DebugBattlePanel:_partyPresets()
	local pw, p = self.pw, self.party
	for _, child in pw.PresetList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for index, entry in presetEntries(p.Data) do
		local picked = p.PresetKey == entry.Key
		local b = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = if picked then BLUE else C(44, 48, 62),
			BorderSizePixel = 0,
			Text = string.format('%s%s   <font color="rgb(150,154,170)">코스트 %d · 유닛 %d</font>', if entry.Example then '<font color="rgb(255,205,90)">[예시]</font> ' else "", entry.Name, partyCost(entry.Units), #entry.Units),
			RichText = true,
			TextColor3 = TEXT,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = index,
		}, pw.PresetList)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
		b.Activated:Connect(function()
			p.PresetKey = entry.Key
			p.Confirm = nil
			if not entry.Example then
				pw.NameBox.Text = entry.Name
			end
			self:_partyMsg(entry.Note or "", false)
			self:_partyPresets()
		end)
	end
	for _, d in pw.PresetList:GetDescendants() do
		if d:IsA("TextButton") then
			d.AutoLocalize = false
		end
	end
end

--=== 프리셋 동작 ===--

local function selectedEntry(self: any): any
	for _, entry in presetEntries(self.party.Data) do
		if entry.Key == self.party.PresetKey then
			return entry
		end
	end
	return nil
end

-- 서버 PartyPresets 원격에 요청하고 응답(Presets·Examples·Persistent·Error)을 받아 창을 고친다
function DebugBattlePanel:_presetCall(request: { [string]: any }, okMessage: string?)
	local remote = (self.Remotes :: any):FindFirstChild("PartyPresets")
	if not remote then
		self:_partyMsg("서버에 PartyPresets 원격이 없습니다 (서버를 새로 동기화하세요).", true)
		return
	end
	task.spawn(function()
		local ok, reply = pcall(function()
			return remote:InvokeServer(request)
		end)
		if not ok or type(reply) ~= "table" then
			self:_partyMsg("저장소에 닿지 못했습니다.", true)
			return
		end
		self.party.Data = reply
		if reply.Error then
			self:_partyMsg(reply.Error, true)
		elseif okMessage then
			self:_partyMsg(okMessage, false)
		end
		self:_partyRefresh()
	end)
end

function DebugBattlePanel:_partySave()
	local p = self.party
	local name = self.pw.NameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		self:_partyMsg("저장할 이름을 적으세요.", true)
		return
	end
	if #p.Units == 0 then
		self:_partyMsg("유닛이 한 명도 없습니다.", true)
		return
	end
	local ok, reason = PartyDefinitions.Validate(p.Units)
	if not ok then
		self:_partyMsg(reason or "파티 구성이 맞지 않습니다.", true)
		return
	end
	for _, entry in presetEntries(p.Data) do
		if entry.Name == name then
			if entry.Example then
				self:_partyMsg("예시와 같은 이름으로는 저장할 수 없습니다.", true)
				return
			end
			if p.Confirm ~= name then
				p.Confirm = name
				self.pw.Save.Text = "덮어쓰기? 한 번 더"
				self:_partyMsg(string.format("'%s' 저장분이 이미 있습니다. 덮어쓰려면 [저장]을 한 번 더 누르세요.", name), false)
				return
			end
		end
	end
	p.Confirm = nil
	p.PresetKey = "S:" .. name
	self:_presetCall({ Op = "Save", Name = name, Units = copyUnits(p.Units) }, string.format("'%s' 저장했습니다.", name))
end

function DebugBattlePanel:_partyLoad()
	local p = self.party
	local entry = selectedEntry(self)
	if not entry then
		self:_partyMsg("불러올 프리셋을 아래 목록에서 고르세요.", true)
		return
	end
	p.Units = copyUnits(entry.Units)
	local first = PartyDefinitions.ActionOrder(p.Units)[1]
	p.Selected, p.Brush, p.Lifted, p.Confirm = if first then first.ClassId else nil, nil, false, nil
	self:_partyMsg(string.format("'%s' 을 불러왔습니다.", entry.Name), false)
	self:_partyRefresh()
end

function DebugBattlePanel:_partyDelete()
	local p = self.party
	local entry = selectedEntry(self)
	if not entry then
		self:_partyMsg("지울 프리셋을 아래 목록에서 고르세요.", true)
		return
	end
	if entry.Example then
		self:_partyMsg("예시 프리셋은 지울 수 없습니다.", true)
		return
	end
	p.Confirm = nil
	p.PresetKey = nil
	self:_presetCall({ Op = "Delete", Name = entry.Name }, string.format("'%s' 지웠습니다.", entry.Name))
end

-- 서버에 파티 전투 시작을 부탁한다(적 편성·배율·무적 등은 편성 탭 설정 그대로)
function DebugBattlePanel:_partyStart()
	local p = self.party
	local ok, reason = PartyDefinitions.Validate(p.Units)
	if not ok then
		self:_partyMsg(reason or "파티 구성이 맞지 않습니다.", true)
		return
	end
	self:_partyMsg("파티 전투를 시작합니다…", false)
	send({ Kind = "StartParty", Party = { Units = copyUnits(p.Units) } })
end

-- 매 프레임: 마우스 아래 직업(코스트 근거)·카드(미리보기)를 보인다
function DebugBattlePanel:_pollPartyHover()
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local found = nil
	for _, target in self.partyHover do
		if target.Gui.Parent and inside(target.Area, mouse) and inside(target.Gui, mouse) then
			found = target
			break
		end
	end
	local gui = found and found.Gui
	if gui ~= self.hoverGui then
		if self.hoverPaint then
			self.hoverPaint(false)
		end
		self.hoverGui = gui
		self.hoverPaint = found and found.Paint
		if self.hoverPaint then
			self.hoverPaint(true)
		end
	end
	local key = if found then found.Key else nil
	if key ~= self.sideKey then
		self.sideKey = key
		if found then
			found.Show()
		else
			self.side.Visible = false
			self:_partyTip(nil)
		end
	end
end

return DebugBattlePanel
