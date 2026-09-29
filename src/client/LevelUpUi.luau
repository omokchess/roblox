--!strict
--[[
	LevelUpUi — 레벨업 화면. (2026-09-28, 요청: "레벨업 UI같은 것도 너가 그려줘")

	흐름
	  1. 등장(약 1.7초)   화면이 어두워지고 뒤에서 빛살이 돈다. "LEVEL UP" 이 튀어나오고
	                      레벨 숫자가 이전 → 새 값으로 올라가며, 얻은 스탯 포인트 띠가 붙는다. 반짝이가 흩어진다.
	  2. 고르기           제목이 위로 올라가 작아지고, 가운데로 카드가 한 장씩 솟아오른다.
	                      왼쪽: 스탯 포인트 찍기   오른쪽: 내 빌드(축별 장수 + 보유 카드)
	                      카드를 누르면 **선택만** 된다. "이 카드 받기" 로 확정(잘못 눌러 날리지 않게).
	                      다시 뽑기(코스트) · 건너뛰기
	  3. 다 고르면 "계속" → 닫힘

	카드에는 축 칩이 붙고, 칩 옆 숫자는 **지금 내 빌드에 그 축이 몇 장**인지다 — 시너지를 눈으로 따지며 고르게.

	상태는 `BattleStore`(BattleState) 하나로 그린다. 서버에 보내는 것은 Acquire·Reroll·SkipOffer·SpendStat·DismissLevelUp 뿐.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CardAxes = require(ReplicatedStorage.Shared.CardAxes)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)

local BattleStore = require(script.Parent.BattleStore)
local CardView = require(script.Parent.CardView)

local make = CardView.Make
local C = Color3.fromRGB
local GOLD = C(255, 205, 90)
local TEXT = C(226, 228, 236)
local DIM = C(150, 154, 170)
local PANEL = C(18, 19, 25)

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local LevelUpUi = {}
LevelUpUi.__index = LevelUpUi

function LevelUpUi.new(battleClient: any?)
	local self = setmetatable({}, LevelUpUi)
	self.battleClient = battleClient
	self.state = nil :: any
	self.seenSeq = 0
	self.phase = "Hidden" -- Hidden | Intro | Pick
	self.selected = nil :: string?
	self.offerSignature = ""
	self.cardHandles = {} :: { [string]: any }
	self:_build()
	BattleStore.Subscribe(function(state)
		self:_onState(state)
	end)
	-- 빛살 돌리기
	RunService.RenderStepped:Connect(function(dt)
		if self.root.Visible then
			self.rays.Rotation = (self.rays.Rotation + dt * 12) % 360
		end
	end)
	return self
end

--=== 틀 ===--

function LevelUpUi:_build()
	local gui = make("ScreenGui", {
		Name = "LevelUpGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.Gui = gui

	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	self.root = root
	self.backdrop = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(6, 6, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, root)
	-- 가장자리를 더 어둡게(비네트)
	local vignette = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, self.backdrop)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
	}, vignette)

	-- 빛살: 가운데서 돌아가는 가느다란 띠 14개
	self.rays = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(1100, 1100),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, root)
	self.rayBeams = {}
	for index = 1, 14 do
		local beam = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, if index % 2 == 0 then 70 else 36, 1, 0),
			Rotation = index * (180 / 14),
			BackgroundColor3 = C(255, 214, 120),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, self.rays)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(0.58, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}, beam)
		table.insert(self.rayBeams, beam)
	end

	-- 제목 묶음(등장 때 가운데, 고를 땐 위로)
	local head = make("Frame", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 220),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	self.head = head
	self.headScale = make("UIScale", { Scale = 1 }, head)
	self.titleLabel = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		Text = "LEVEL UP",
		TextColor3 = C(255, 255, 255),
		Font = Enum.Font.GothamBlack,
		TextSize = 88,
		ZIndex = 6,
	}, head)
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 190, 70)),
			ColorSequenceKeypoint.new(0.5, C(255, 248, 210)),
			ColorSequenceKeypoint.new(1, C(255, 170, 60)),
		}),
		Rotation = 90,
	}, self.titleLabel)
	make("UIStroke", { Color = C(70, 34, 6), Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, self.titleLabel)
	self.levelLabel = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 100),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 40,
		RichText = true,
		ZIndex = 6,
	}, head)
	make("UIStroke", { Color = C(10, 10, 14), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, self.levelLabel)
	self.pointsBadge = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(240, 34),
		Position = UDim2.new(0.5, 0, 0, 166),
		BackgroundColor3 = C(52, 120, 76),
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = C(230, 255, 230),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		ZIndex = 6,
	}, head)
	make("UICorner", { CornerRadius = UDim.new(0, 17) }, self.pointsBadge)
	make("UIStroke", { Color = C(140, 230, 160), Thickness = 1.5 }, self.pointsBadge)

	-- 반짝이
	self.sparkles = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, root)

	-- 고르기 화면
	local pick = make("Frame", { Name = "Pick", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 7 }, root)
	self.pick = pick
	self.subtitle = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, -40, 0, 28),
		Position = UDim2.new(0.5, 0, 0, 128),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		RichText = true,
		ZIndex = 8,
	}, pick)
	make("UIStroke", { Color = C(8, 8, 12), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, self.subtitle)

	self.cardRow = make("Frame", {
		Name = "Cards",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(1, -640, 0, 400),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, pick)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.cardRow)

	-- 아래 단추 줄
	local bar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(640, 50),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, pick)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	local function barButton(text: string, color: Color3, order: number, width: number): TextButton
		local b = make("TextButton", {
			Size = UDim2.fromOffset(width, 50),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Text = text,
			TextColor3 = C(255, 255, 255),
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			RichText = true,
			LayoutOrder = order,
			ZIndex = 9,
		}, bar)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
		make("UIStroke", { Color = color:Lerp(C(255, 255, 255), 0.35), Thickness = 1.5 }, b)
		return b
	end
	self.rerollButton = barButton("다시 뽑기", C(36, 92, 170), 1, 180)
	self.skipButton = barButton("건너뛰기", C(60, 62, 74), 2, 130)
	self.takeButton = barButton("이 카드 받기", C(40, 140, 84), 3, 220)
	self.continueButton = barButton("계속", C(150, 110, 30), 4, 240)
	self.rerollButton.Activated:Connect(function()
		BattleStore.Send({ Kind = "Reroll" })
	end)
	self.skipButton.Activated:Connect(function()
		BattleStore.Send({ Kind = "SkipOffer" })
	end)
	self.takeButton.Activated:Connect(function()
		if self.selected then
			BattleStore.Send({ Kind = "Acquire", CardId = self.selected })
		end
	end)
	self.continueButton.Activated:Connect(function()
		BattleStore.Send({ Kind = "DismissLevelUp" })
		self:_close()
	end)

	self:_buildStatPanel(pick)
	self:_buildBuildPanel(pick)
end

local function sidePanel(parent: Instance, name: string, anchorX: number, x: UDim): Frame
	local panel = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Position = UDim2.new(x.Scale, x.Offset, 0.53, 0),
		Size = UDim2.fromOffset(280, 430),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	make("UIStroke", { Color = C(60, 62, 78), Thickness = 1 }, panel)
	return panel
end

function LevelUpUi:_buildStatPanel(parent: Instance)
	local panel = sidePanel(parent, "Stats", 0, UDim.new(0, 24))
	self.statTitle = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		ZIndex = 9,
	}, panel)
	self.statRows = {}
	for index, id in StatDefinitions.Order do
		local definition = StatDefinitions.Get(id)
		local rowFrame = make("Frame", {
			Size = UDim2.new(1, -24, 0, 58),
			Position = UDim2.fromOffset(12, 44 + (index - 1) * 62),
			BackgroundColor3 = C(28, 30, 38),
			BorderSizePixel = 0,
			ZIndex = 9,
		}, panel)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, rowFrame)
		local name = make("TextLabel", {
			Size = UDim2.new(1, -60, 0, 24),
			Position = UDim2.fromOffset(10, 4),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			ZIndex = 10,
		}, rowFrame)
		make("TextLabel", {
			Size = UDim2.new(1, -60, 0, 26),
			Position = UDim2.fromOffset(10, 27),
			BackgroundTransparency = 1,
			Text = definition and definition.Description or "",
			TextColor3 = DIM,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 10,
		}, rowFrame)
		local plus = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.new(1, -8, 0.5, 0),
			BackgroundColor3 = C(52, 120, 76),
			BorderSizePixel = 0,
			Text = "+",
			TextColor3 = C(255, 255, 255),
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			ZIndex = 10,
		}, rowFrame)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, plus)
		plus.Activated:Connect(function()
			BattleStore.Send({ Kind = "SpendStat", StatId = id, Amount = 1 })
		end)
		self.statRows[id] = { Name = name, Plus = plus, Definition = definition }
	end
end

function LevelUpUi:_buildBuildPanel(parent: Instance)
	local panel = sidePanel(parent, "Build", 1, UDim.new(1, -24))
	self.buildTitle = make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Text = "내 빌드",
		TextColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
	}, panel)
	self.axisList = make("Frame", {
		Size = UDim2.new(1, -24, 0, 4 * 34),
		Position = UDim2.fromOffset(12, 44),
		BackgroundTransparency = 1,
		ZIndex = 9,
	}, panel)
	self.ownedGrid = make("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -200),
		Position = UDim2.fromOffset(12, 188),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 9,
	}, panel)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(58, 72), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.ownedGrid)
end

--=== 상태 받기 ===--

function LevelUpUi:_axisCounts(state: any): { [string]: number }
	local counts: { [string]: number } = {}
	for _, card in state.Owned or {} do
		for _, tag in card.Tags or {} do
			counts[tag] = (counts[tag] or 0) + 1
		end
	end
	return counts
end

function LevelUpUi:_onState(state: any)
	self.state = state
	if not state then
		return
	end
	local levelUp = state.LevelUp
	if levelUp and levelUp.Seq > self.seenSeq then
		self.seenSeq = levelUp.Seq
		task.spawn(function()
			self:_playIntro(levelUp)
		end)
		return
	end
	if self.phase == "Pick" then
		self:_refreshPick()
	elseif self.phase == "Hidden" and state.Offer and not state.InBattle then
		-- 레벨업 연출 없이 제시만 남아 있으면(다시 열기) 바로 고르기 화면
		self:_openPick(false)
	end
end

--=== 1. 등장 ===--

function LevelUpUi:_burst()
	for index = 1, 26 do
		local angle = (index / 26) * math.pi * 2 + math.random() * 0.2
		local distance = 180 + math.random() * 260
		local size = 6 + math.random() * 10
		local spark = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = if index % 3 == 0 then C(255, 255, 255) else C(255, 214, 120),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, self.sparkles)
		local seconds = 0.8 + math.random() * 0.6
		tween(spark, seconds, {
			Position = UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance * 0.7),
			Rotation = 45 + math.random(-180, 180),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		}, Enum.EasingStyle.Quart)
		task.delay(seconds + 0.05, function()
			spark:Destroy()
		end)
	end
end

function LevelUpUi:_playIntro(levelUp: any)
	-- 전투 마무리 연출이 끝날 때까지 조금 기다린다(쓰러지는 모습을 가리지 않게)
	local waited = 0
	while self.battleClient and self.battleClient.active and waited < 3.5 do
		waited += task.wait(0.1)
	end
	self.phase = "Intro"
	self.root.Visible = true
	self.pick.Visible = false
	self.head.Position = UDim2.fromScale(0.5, 0.42)
	self.headScale.Scale = 0.2
	self.backdrop.BackgroundTransparency = 1
	tween(self.backdrop, 0.35, { BackgroundTransparency = 0.28 })
	for _, beam in self.rayBeams do
		beam.BackgroundTransparency = 1
		tween(beam, 0.6, { BackgroundTransparency = 0.25 })
	end
	self.titleLabel.TextTransparency = 0
	self.levelLabel.TextTransparency = 0
	self.pointsBadge.Visible = false
	tween(self.headScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	self:_burst()

	-- 레벨 숫자 올리기
	local from, to = levelUp.From, levelUp.To
	local steps = math.max(to - from, 1)
	for step = 0, steps do
		local shown = math.min(from + step, to)
		self.levelLabel.Text = string.format('Lv. <font color="rgb(170,174,190)">%d</font>  ▶  <font color="rgb(255,205,90)">%d</font>', from, shown)
		task.wait(0.5 / steps)
	end
	if (levelUp.Points or 0) > 0 then
		self.pointsBadge.Text = string.format("+%d 스탯 포인트", levelUp.Points)
		self.pointsBadge.Visible = true
		self.pointsBadge.Size = UDim2.fromOffset(0, 34)
		tween(self.pointsBadge, 0.3, { Size = UDim2.fromOffset(240, 34) }, Enum.EasingStyle.Back)
	end
	task.wait(1.0)
	self:_openPick(true)
end

--=== 2. 고르기 ===--

function LevelUpUi:_openPick(fromIntro: boolean)
	self.phase = "Pick"
	self.root.Visible = true
	if fromIntro then
		-- 제목 묶음을 위로 올려 작게
		tween(self.head, 0.45, { Position = UDim2.new(0.5, 0, 0, 78) }, Enum.EasingStyle.Quart)
		tween(self.headScale, 0.45, { Scale = 0.52 }, Enum.EasingStyle.Quart)
		for _, beam in self.rayBeams do
			tween(beam, 0.6, { BackgroundTransparency = 0.8 })
		end
	else
		self.head.Position = UDim2.new(0.5, 0, 0, 78)
		self.headScale.Scale = 0.52
		self.backdrop.BackgroundTransparency = 0.28
		local state = self.state
		self.levelLabel.Text = string.format('Lv. <font color="rgb(255,205,90)">%d</font>', state and state.Level or 1)
		self.pointsBadge.Visible = false
		for _, beam in self.rayBeams do
			beam.BackgroundTransparency = 0.8
		end
	end
	self.pick.Visible = true
	self.offerSignature = ""
	self:_refreshPick()
end

function LevelUpUi:_refreshPick()
	local state = self.state
	if not state then
		return
	end
	local offer = state.Offer
	local counts = self:_axisCounts(state)

	-- 제목 아래 한 줄
	if offer then
		local essential = offer.Cards[1] and offer.Cards[1].Grade == "Essential"
		self.subtitle.Text = if essential
			then string.format('<font color="rgb(214,160,255)">전직 카드</font> — 빌드의 방향을 정합니다  ·  남은 선택 <font color="rgb(255,205,90)">%d</font>  ·  코스트 %d', offer.Remaining, offer.Cost)
			else string.format("카드를 고르세요  ·  남은 선택 <font color=\"rgb(255,205,90)\">%d</font>  ·  코스트 %d", offer.Remaining, offer.Cost)
	else
		self.subtitle.Text = "선택을 마쳤습니다"
	end

	-- 카드: 구성이 바뀔 때만 새로 깐다(스탯만 찍었는데 카드가 다시 솟으면 어지럽다)
	local ids = {}
	for _, card in (offer and offer.Cards) or {} do
		table.insert(ids, card.Id .. ":" .. tostring(card.Level))
	end
	local signature = table.concat(ids, "/")
	if signature ~= self.offerSignature then
		self.offerSignature = signature
		self.selected = nil
		self:_layCards(offer, counts)
	end

	-- 단추
	local affordable = offer ~= nil and offer.Cost >= offer.RerollCost
	self.rerollButton.Visible = offer ~= nil
	self.rerollButton.Text = if offer then string.format("다시 뽑기  <font size=\"14\">%d 코스트</font>", offer.RerollCost) else ""
	self.rerollButton.AutoButtonColor = affordable
	self.rerollButton.BackgroundColor3 = if affordable then C(36, 92, 170) else C(50, 52, 62)
	self.skipButton.Visible = offer ~= nil
	self.takeButton.Visible = offer ~= nil
	self.takeButton.BackgroundColor3 = if self.selected then C(40, 140, 84) else C(50, 52, 62)
	self.continueButton.Visible = offer == nil

	-- 스탯
	self.statTitle.Text = string.format('스탯 포인트  <font color="rgb(255,255,255)">%d</font>', state.Points or 0)
	for id, entry in self.statRows do
		entry.Name.Text = string.format('%s  <font color="rgb(255,205,90)">%d</font>', entry.Definition and entry.Definition.Name or id, state.Stats and state.Stats[id] or 0)
		entry.Plus.Visible = (state.Points or 0) > 0
	end

	-- 내 빌드: 축별 장수 막대 + 보유 카드
	for _, child in self.axisList:GetChildren() do
		child:Destroy()
	end
	local classId = state.Config and state.Config.ClassId or ""
	local axes = CardAxes.ForClass(classId)
	local most = 1
	for _, axis in axes do
		most = math.max(most, counts[axis.Id] or 0)
	end
	for index, axis in axes do
		local count = counts[axis.Id] or 0
		local line = make("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, (index - 1) * 34),
			BackgroundTransparency = 1,
			ZIndex = 9,
		}, self.axisList)
		make("TextLabel", {
			Size = UDim2.new(0, 70, 1, 0),
			BackgroundTransparency = 1,
			Text = axis.Name,
			TextColor3 = axis.Color,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
		}, line)
		local track = make("Frame", {
			Size = UDim2.new(1, -110, 0, 10),
			Position = UDim2.new(0, 72, 0.5, -5),
			BackgroundColor3 = C(34, 36, 46),
			BorderSizePixel = 0,
			ZIndex = 10,
		}, line)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, track)
		local fill = make("Frame", {
			Size = UDim2.fromScale(count / most, 1),
			BackgroundColor3 = axis.Color,
			BorderSizePixel = 0,
			ZIndex = 11,
		}, track)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, fill)
		make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 30, 1, 0),
			Position = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			Text = tostring(count),
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 10,
		}, line)
	end
	self.buildTitle.Text = string.format("내 빌드  %d장", #(state.Owned or {}))
	for _, child in self.ownedGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, card in state.Owned or {} do
		local cell = make("Frame", { Size = UDim2.fromOffset(58, 72), BackgroundTransparency = 1, LayoutOrder = index, ZIndex = 9 }, self.ownedGrid)
		local thumb = CardView.Thumb(cell, card, 58)
		thumb.ZIndex = 10
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 58),
			BackgroundTransparency = 1,
			Text = string.format("%s %d", card.Name, card.Level),
			TextColor3 = DIM,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 10,
		}, cell)
	end
end

function LevelUpUi:_layCards(offer: any, counts: { [string]: number })
	for _, child in self.cardRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.cardHandles = {}
	if not offer then
		return
	end
	local count = #offer.Cards
	-- 폭: 가운데 자리(양옆 패널 뺀 폭)를 장수로 나누되 230 을 넘지 않게. 높이는 폭의 1.55배.
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1600, 900)
	local room = math.max(viewport.X - 640, 480)
	local width = math.clamp(math.floor((room - 14 * (count - 1)) / math.max(count, 1)), 150, 230)
	local height = math.floor(width * 1.62)
	self.cardRow.Size = UDim2.new(1, -640, 0, height + 30)
	for index, card in offer.Cards do
		local slot = make("Frame", {
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			ZIndex = 8,
		}, self.cardRow)
		local holder = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 80),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, slot)
		local scale = make("UIScale", { Scale = 0.7 }, holder)
		local handle = CardView.Build(holder, card, {
			Offered = true,
			Owned = counts,
			TextSize = if width < 190 then 13 else 15,
			OnClick = function()
				self.selected = card.Id
				for id, other in self.cardHandles do
					other.SetSelected(id == card.Id)
				end
				self.takeButton.BackgroundColor3 = C(40, 140, 84)
			end,
		})
		self.cardHandles[card.Id] = handle
		-- 한 장씩 솟아오른다
		task.delay(0.06 * index, function()
			tween(holder, 0.42, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
			tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

--=== 3. 닫기 ===--

function LevelUpUi:_close()
	self.phase = "Hidden"
	tween(self.backdrop, 0.25, { BackgroundTransparency = 1 })
	for _, beam in self.rayBeams do
		tween(beam, 0.25, { BackgroundTransparency = 1 })
	end
	tween(self.headScale, 0.25, { Scale = 0.2 })
	task.delay(0.26, function()
		if self.phase == "Hidden" then
			self.root.Visible = false
			self.pick.Visible = false
		end
	end)
end

return LevelUpUi
