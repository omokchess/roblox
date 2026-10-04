--!strict
--[[
	BattleHud — 전투 화면에서 손에 닿는 UI. (2026-09-29)
	  스킬 슬롯(단축키 1~6) · 공격 버튼(Space) · 태세(Q) · 나가기 · 체력/스테미나 · 상태 줄 · 기록 줄
	  스킬 설명 말풍선 · QTE 판 · 판정 글자

	사용자 요청: "버튼들이 다 너무 작고, 버튼 홀딩 했을 때 보이는 설명이 칸에 비해 너무 길거나 줄바꿈이 많아서
	읽기 힘들어. AI티 나지 않게 여러 게임 UI 레퍼런스를 찾아본 후에 UI를 만들어줘."

	참고한 것
	  - Darkest Dungeon · Slay the Spire: 스킬 칸 모서리에 단축키, 설명은 **고정 폭**, 키워드 풀이는 옆에 따로 상자
	  - 툴팁 글 쓰기(Infinite Crisis 툴팁 문서, "tooltips in tooltips"): 폭을 고정하고 글머리 목록은 매단 들여쓰기,
	    숫자·키워드만 색으로 튀게, 넘치면 높이를 잘라 스크롤
	  - Helldivers 2 스트라타젬: 방향 입력은 글자가 아니라 **키캡 줄**, 지금 누를 것만 밝게
	  - Clair Obscur: Expedition 33: 타이밍은 줄어드는 고리, 결과는 가운데에 크게 한 번
	모양: 둥근 알약·그라데이션 대신 먹빛 판 + 뼛빛 1px 선 + 모서리 꺾쇠, 각진 모서리.

	판정·서버 통신은 BattleClient 가 한다. 여기는 그리기와 클릭·마우스 올림만.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local GridBattle = require(ReplicatedStorage.Shared.GridBattle)
local Keywords = require(ReplicatedStorage.Shared.Keywords)
local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)

local BattleHud = {}
BattleHud.__index = BattleHud

-- 먹빛 판 · 뼛빛 선
local INK = Color3.fromRGB(15, 14, 18)
local INK_2 = Color3.fromRGB(28, 26, 31)
local BONE = Color3.fromRGB(230, 218, 194)
local BODY = Color3.fromRGB(204, 196, 182)
local MUTED = Color3.fromRGB(146, 138, 124)
local CRIMSON = Color3.fromRGB(200, 58, 50)
local GOLD = Color3.fromRGB(236, 186, 78)
local STEEL = Color3.fromRGB(128, 160, 196)
local TEAL = Color3.fromRGB(86, 214, 172)
local RED = Color3.fromRGB(238, 72, 64)
local STAMINA = Color3.fromRGB(206, 214, 110)

local SLOT_W, SLOT_H, SLOT_GAP = 132, 88, 8
local ACTION_W = 200
local TIP_W, GLOSS_W = 440, 270
local BOSS_W = 500
local QTE_W, QTE_H = 580, 250
-- 고리 QTE 에서 반지름 1 이 몇 px 인가
local RING_R = 72

local KIND = {
	Class = { Label = "직업 스킬", Color = CRIMSON },
	Upgrade = { Label = "강화", Color = GOLD },
	Common = { Label = "공용", Color = STEEL },
}
local KEYWORD_KIND = { Buff = "버프", Debuff = "디버프", Status = "상태이상", Resource = "자원", Neutral = "중립" }
local DIRECTION_GLYPH = { Up = "▲", Right = "▶", Down = "▼", Left = "◀" }

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

local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- 모서리 꺾쇠: 네 귀퉁이 바깥으로 3px 나간 ㄱ자
local function brackets(parent: Instance, color: Color3, len: number)
	for _, c in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local at = UDim2.new(c.X, (c.X * 2 - 1) * 3, c.Y, (c.Y * 2 - 1) * 3)
		for _, size in { UDim2.fromOffset(len, 2), UDim2.fromOffset(2, len) } do
			make("Frame", { AnchorPoint = c, Position = at, Size = size, BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
		end
	end
end

local function keycap(parent: Instance, text: string, w: number, h: number, textSize: number): TextLabel
	local cap = make("TextLabel", {
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = INK_2,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = textSize,
	}, parent)
	stroke(cap, BONE, 0.45)
	-- 아랫단 그늘(눌리는 키처럼)
	make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, cap)
	return cap
end

local function hex(c: Color3): string
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--[[
	설명 글 → RichText. `[낱말]` 은 괄호를 떼고 키워드 색으로, 숫자(+10%, 3 …)는 밝게 굵게.
	숫자는 괄호 바깥에서만 칠한다(키워드 이름을 깨지 않게).
]]
local NUMBER = '<font color="#fff2d2"><b>%0</b></font>'
function BattleHud.Markup(text: string): string
	local out = {}
	local last = 1
	local function plain(s: string)
		table.insert(out, (escape(s):gsub("[%+%-]?%d+%%?", NUMBER)))
	end
	for start, name, stop in text:gmatch("()%[([^%]]+)%]()") do
		plain(text:sub(last, (start :: any) - 1))
		local keyword = Keywords.ByName(name)
		local color = if keyword and (keyword :: any).Color then (keyword :: any).Color else hex(GOLD)
		table.insert(out, string.format('<font color="%s"><b>%s</b></font>', color, escape(name)))
		last = stop :: any
	end
	plain(text:sub(last))
	return table.concat(out)
end

export type Row = { Level: number, Text: string, Bullet: boolean, Head: boolean }

--[[
	스킬 설명을 줄 단위로 쪼갠다. "- " 글머리와 앞 칸(두 칸 = 한 단계)을 걷어 내고,
	아래에 더 깊은 줄을 거느린 줄은 소제목(Head)으로 표시한다(예: "약재 3 소모").
]]
function BattleHud.ParseDescription(text: string): { Row }
	local rows: { Row } = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local spaces, body = line:match("^( *)(.-)%s*$")
		if body and body ~= "" then
			local bullet = body:sub(1, 2) == "- "
			table.insert(rows, {
				Level = math.floor(#(spaces :: string) / 2),
				Text = if bullet then body:sub(3) else body,
				Bullet = bullet,
				Head = false,
			})
		end
	end
	for i, row in rows do
		local nextRow = rows[i + 1]
		row.Head = nextRow ~= nil and nextRow.Level > row.Level
	end
	return rows
end

--[[
	설명 글 → 줄들(첫 단계 글머리는 accent 색 마름모, 그 아래는 짧은 줄표, 두 칸 들여쓰기 = 한 단계).
	스킬 설명 말풍선과 보스 정보 창이 같이 쓴다(2026-10-02 사용자: 보스 스킬 설명도 플레이어 스킬 설명 양식으로).
	dim = 부서진 부위처럼 흐리게.
]]
local function describe(parent: Instance, text: string, accent: Color3, firstOrder: number?, dim: boolean?)
	for i, row in BattleHud.ParseDescription(text) do
		local line = make("Frame", {
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = (firstOrder or 0) + i,
		}, parent)
		local top = if row.Level == 0 and i > 1 then 5 else 0
		local left = row.Level * 16
		if row.Bullet then
			-- 글머리: 첫 단계는 종류 색 마름모, 그 아래는 짧은 줄표
			if row.Level == 0 then
				make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(left + 4, top + 10),
					Size = UDim2.fromOffset(6, 6),
					Rotation = 45,
					BackgroundColor3 = if dim then MUTED else accent,
					BorderSizePixel = 0,
				}, line)
			else
				make("Frame", {
					Position = UDim2.fromOffset(left, top + 9),
					Size = UDim2.fromOffset(7, 2),
					BackgroundColor3 = MUTED,
					BorderSizePixel = 0,
				}, line)
			end
			left += 15
		end
		make("TextLabel", {
			Position = UDim2.fromOffset(left, top),
			Size = UDim2.new(1, -left, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = BattleHud.Markup(row.Text),
			RichText = true,
			TextWrapped = true,
			TextColor3 = if dim then MUTED elseif row.Head then BONE else BODY,
			Font = if row.Head then Enum.Font.GothamBold else Enum.Font.GothamMedium,
			TextSize = 15,
			LineHeight = 1.1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, line)
	end
end

export type Callbacks = {
	Select: (index: number) -> (),
	Attack: () -> (),
	Stance: () -> (),
	Exit: () -> (),
}

function BattleHud.new(gui: ScreenGui, callbacks: Callbacks)
	local self = setmetatable({}, BattleHud) :: any
	self.gui = gui
	self.callbacks = callbacks
	self.skills = {}
	self.slots = {}
	self.selected = 1
	self.scale = 1
	self.active = false
	self.hovered = nil
	self.tipFor = nil
	self.overTip = false
	self.stanceShown = false

	self:_buildDock()
	self:_buildTip()
	self:_buildQte()
	self:_buildTop()
	self:_buildBossInfo()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_rescale()
		end)
	end
	self:_rescale()
	return self
end

--=== 아래 판: 슬롯 · 공격 · 태세 · 체력 · 상태 ===--

function BattleHud:_buildDock()
	local dock = make("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(ACTION_W, SLOT_H),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.gui)
	self.dock = dock
	self.dockScale = make("UIScale", {}, dock)
	self.slotRow = make("Frame", { Name = "Slots", BackgroundTransparency = 1, Size = UDim2.new(1, -(ACTION_W + 14), 1, 0) }, dock)

	-- 공격(오른쪽 끝, Space). 고른 스킬 이름과 못 쓰는 까닭이 아래 줄에 뜬다
	local attack = make("TextButton", {
		Name = "Attack",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(ACTION_W, SLOT_H),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(112, 28, 28),
		BorderSizePixel = 0,
		Text = "",
	}, dock)
	self.attackStroke = stroke(attack, Color3.fromRGB(240, 128, 108), 0.3)
	brackets(attack, BONE, 10)
	self.attackTitle = make("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 32),
		BackgroundTransparency = 1,
		Text = "공격",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, attack)
	self.attackSub = make("TextLabel", {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(236, 190, 176),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, attack)
	local space = keycap(attack, "SPACE", 60, 20, 11)
	space.AnchorPoint = Vector2.new(1, 1)
	space.Position = UDim2.new(1, -10, 1, -9)
	attack.Activated:Connect(function()
		self.callbacks.Attack()
	end)
	self.attack = attack

	-- 결투사 태세(공격 버튼 위, Q)
	local stance = make("TextButton", {
		Name = "Stance",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -10),
		Size = UDim2.fromOffset(ACTION_W, 32),
		AutoButtonColor = false,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Text = "",
		Visible = false,
	}, dock)
	self.stanceStroke = stroke(stance, BONE, 0.6)
	self.stanceText = make("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -46, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, stance)
	self.stanceKey = keycap(stance, "Q", 22, 20, 12)
	self.stanceKey.AnchorPoint = Vector2.new(1, 0.5)
	self.stanceKey.Position = UDim2.new(1, -8, 0.5, 0)
	stance.Activated:Connect(function()
		self.callbacks.Stance()
	end)
	self.stance = stance

	-- 슬롯 줄 위: 체력·스테미나 막대와 상태 줄
	local vitals = make("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -10),
		Size = UDim2.fromOffset(200, 34),
		BackgroundTransparency = 1,
	}, dock)
	local function bar(y: number, h: number, color: Color3): (Frame, TextLabel)
		local back = make("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, h),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
		}, vitals)
		stroke(back, BONE, 0.7)
		local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
		local label = make("TextLabel", {
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -12, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = BONE,
			Font = Enum.Font.GothamBold,
			TextSize = h - 4,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}, back)
		make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, label)
		return fill, label
	end
	self.hpFill, self.hpText = bar(0, 18, Color3.fromRGB(150, 36, 40))
	self.staminaFill, self.staminaText = bar(22, 14, Color3.fromRGB(110, 118, 50))

	-- 효과 아이콘 줄: 체력 막대 위(2026-09-29 요청: 글씨 대신 아이콘, 누르고 있거나 모바일은 눌러서 설명)
	self.effectRow = make("Frame", {
		Name = "Effects",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -52),
		Size = UDim2.fromOffset(900, 40),
		BackgroundTransparency = 1,
	}, dock)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, self.effectRow)
	self.effectIcons = {}

	-- 효과 설명 말풍선(아이콘 위)
	local pop = make("Frame", {
		Name = "EffectTip",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, self.gui)
	self.effectPopScale = make("UIScale", {}, pop)
	self.effectPopStroke = stroke(pop, BONE, 0.4)
	brackets(pop, BONE, 10)
	local inner = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, pop)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 11),
	}, inner)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, inner)
	self.effectPopName = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, inner)
	self.effectPopDesc = make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		RichText = true,
		TextWrapped = true,
		TextColor3 = BODY,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		LineHeight = 1.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	}, inner)
	self.effectPop = pop
end

--[[
	걸린 효과 아이콘. effects = { { Id, Name, Glyph, Color, Count?, Desc } }.
	목록(Id·수)이 같으면 다시 찍지 않는다 — 마우스를 올린 채 스냅샷이 와도 말풍선이 꺼지지 않게.
	  PC       마우스를 올리거나 누르고 있으면 설명
	  모바일   누르면 설명이 켜지고, 다시 누르면 꺼진다
]]
function BattleHud:SetEffects(effects: { any })
	local parts = {}
	for _, e in effects do
		local multi = ""
		for _, m in e.Multi or {} do
			multi ..= "," .. tostring(m[2])
		end
		table.insert(parts, string.format("%s:%s%s", e.Id, tostring(e.Count), multi))
	end
	local sig = table.concat(parts, ";")
	self.effects = {}
	for _, e in effects do
		self.effects[e.Id] = e
	end
	if sig == self.effectSig then
		return
	end
	self.effectSig = sig
	for _, icon in self.effectIcons do
		icon:Destroy()
	end
	self.effectIcons = {}
	for order, e in effects do
		local icon = make("TextButton", {
			Name = e.Id,
			Size = UDim2.fromOffset(38, 38),
			AutoButtonColor = false,
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Text = "",
			LayoutOrder = order,
		}, self.effectRow)
		stroke(icon, e.Color, 0.25)
		make("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = e.Color, BorderSizePixel = 0 }, icon)
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = e.Glyph,
			TextColor3 = e.Color,
			Font = Enum.Font.GothamBlack,
			TextSize = 19,
		}, icon)
		--[[ 숫자 여럿(음표): 모서리마다 기호 + 개수. BR 오른쪽 아래 · BL 왼쪽 아래 · TL 왼쪽 위.
		     기호는 제 숫자 쪽으로 조금씩 비켜 겹치되 색·테두리로 또렷하게(2026-10-04 사용자) ]]
		if e.Multi then
			icon.Size = UDim2.fromOffset(46, 46)
			local SPOT = {
				-- { 기호 자리(가운데 비율), 숫자 자리·정렬 }
				BR = { Vector2.new(0.6, 0.6), UDim2.new(1, -2, 1, 0), Vector2.new(1, 1), Enum.TextXAlignment.Right },
				BL = { Vector2.new(0.42, 0.66), UDim2.new(0, 2, 1, 0), Vector2.new(0, 1), Enum.TextXAlignment.Left },
				TL = { Vector2.new(0.5, 0.42), UDim2.new(0, 2, 0, 1), Vector2.new(0, 0), Enum.TextXAlignment.Left },
			}
			for zi, m in e.Multi do
				local spot = SPOT[m[3]]
				local g = make("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(spot[1].X, spot[1].Y),
					Size = UDim2.fromOffset(22, 22),
					BackgroundTransparency = 1,
					Text = m[1],
					TextColor3 = m[4],
					Font = Enum.Font.GothamBlack,
					TextSize = 21,
					ZIndex = 2 + zi,
				}, icon)
				make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, g)
				local n = make("TextLabel", {
					AnchorPoint = spot[3],
					Position = spot[2],
					Size = UDim2.fromOffset(18, 13),
					BackgroundTransparency = 1,
					Text = tostring(m[2]),
					TextColor3 = m[4],
					Font = Enum.Font.GothamBlack,
					TextSize = 12,
					TextXAlignment = spot[4],
					ZIndex = 6,
				}, icon)
				make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, n)
			end
		end
		if e.Count then
			local count = make("TextLabel", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, 0),
				Size = UDim2.fromOffset(30, 14),
				BackgroundTransparency = 1,
				Text = tostring(e.Count),
				TextColor3 = BONE,
				Font = Enum.Font.GothamBlack,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 2,
			}, icon)
			make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, count)
		end
		local id = e.Id
		icon.MouseEnter:Connect(function()
			self:_showEffect(id, icon)
		end)
		icon.MouseButton1Down:Connect(function()
			self:_showEffect(id, icon)
		end)
		icon.MouseLeave:Connect(function()
			if self.effectPinned ~= id then
				self:_hideEffect(id)
			end
		end)
		icon.Activated:Connect(function(input: InputObject?)
			-- 터치: 눌러서 켜고 다시 눌러 끈다
			if input and input.UserInputType == Enum.UserInputType.Touch then
				if self.effectPinned == id then
					self.effectPinned = nil
					self:_hideEffect(id)
				else
					self.effectPinned = id
					self:_showEffect(id, icon)
				end
			end
		end)
		self.effectIcons[order] = icon
	end
	-- 켜 둔 효과가 사라졌으면 말풍선도 끈다
	if self.effectShown and not self.effects[self.effectShown] then
		self:_hideEffect(self.effectShown)
	end
end

function BattleHud:_showEffect(id: string, icon: GuiObject)
	local e = self.effects and self.effects[id]
	if not e then
		return
	end
	self.effectShown = id
	self.effectPopStroke.Color = e.Color
	self.effectPopName.Text = string.format(
		'<font color="%s">%s</font>%s',
		hex(e.Color),
		escape(e.Name),
		if e.Count then string.format('  <font color="%s" size="14">%s</font>', hex(MUTED), tostring(e.Count)) else ""
	)
	self.effectPopDesc.Text = BattleHud.Markup(e.Desc or "")
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local x = math.clamp(icon.AbsolutePosition.X, 12, view.X - 12 - 300 * self.scale)
	self.effectPop.Position = UDim2.fromOffset(x, icon.AbsolutePosition.Y - 8)
	self.effectPop.Visible = true
end

function BattleHud:_hideEffect(id: string)
	if self.effectShown == id then
		self.effectShown = nil
		self.effectPop.Visible = false
	end
end

-- 위: 기록 한 줄(가운데)과 나가기(오른쪽)
function BattleHud:_buildTop()
	self.log = make("TextLabel", {
		Name = "Log",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		Visible = false,
	}, self.gui)
	make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, self.log)
	make("UISizeConstraint", { MaxSize = Vector2.new(820, 30) }, self.log)
	stroke(self.log, BONE, 0.8)

	self.exit = make("TextButton", {
		Name = "BattleExit",
		AnchorPoint = Vector2.new(1, 0),
		-- 오른쪽 위 핫바 아래. 광장 버튼(모션 제작)은 전투 중 감춰져 그 자리가 빈다
		Position = UDim2.new(1, -16, 0, 164),
		Size = UDim2.fromOffset(150, 38),
		AutoButtonColor = false,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Text = "전투 나가기",
		TextColor3 = Color3.fromRGB(240, 170, 160),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Visible = false,
	}, self.gui)
	stroke(self.exit, CRIMSON, 0.2)
	self.exit.Activated:Connect(function()
		self.callbacks.Exit()
	end)
end

--[[
	화면이 좁으면 판 전체를 줄인다(스킬 6개 + 공격 버튼이 1060px 남짓).
	말풍선·QTE 도 같은 배율.
]]
function BattleHud:_rescale()
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local need = self.dock.Size.X.Offset + 40
	self.scale = math.clamp(math.min(view.X / need, view.Y / 700), 0.6, 1)
	for _, s in { self.dockScale, self.tipScale, self.glossScale, self.qteScale, self.effectPopScale, self.bossScale } do
		s.Scale = self.scale
	end
end

--[[
	보스 체력바(2026-10-03 사용자: "보스 체력도 잘 보이게 체력바를 놓고, 부위별로 체력 볼 수 있게").
	화면 위 가운데. 한 줄씩:
	  이름 · 페이즈 · 체력 합          큰 체력바(페이즈 눈금 75/50/25%)
	  부위 넷(부위 색 · 이름 · 체력)     보스 스테미나 + 상태(과부하·회복 불가·버프·충전)
	  이번 턴: 부위마다 예고한 행동(부위 색)
	스냅샷이 올 때마다 다시 그린다(가볍다). 보스가 없으면 숨긴다.
]]
local function comma(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

local BOSS_BAR_W = 660
function BattleHud:SetBoss(snapshot: any?)
	local bossSnap = snapshot and snapshot.Boss
	if not self.bossBar then
		self.bossBar = make("Frame", {
			Name = "BossBar",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 104),
			Size = UDim2.fromOffset(BOSS_BAR_W, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			Visible = false,
		}, self.gui)
		stroke(self.bossBar, CRIMSON, 0.55)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, self.bossBar)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, self.bossBar)
		self.bossBarScale = make("UIScale", {}, self.bossBar)
	end
	local bar = self.bossBar
	bar.Visible = self.active and bossSnap ~= nil
	if not bar.Visible then
		return
	end
	if self.bossBarScale then
		self.bossBarScale.Scale = self.scale
	end
	for _, child in bar:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local def = EnemyDefinitions.Get(bossSnap.Id)
	local units: { [string]: any } = {}
	for _, u in snapshot.Units or {} do
		if u.Part then
			units[u.Part] = u
		end
	end
	local hp, maxHp = 0, 0
	for _, part in def.Parts or {} do
		local u = units[part.Key]
		if u then
			hp += math.max(0, u.Health or 0)
			maxHp += u.MaxHealth or 0
		end
	end
	local sep = string.format('<font color="%s">   |   </font>', hex(Color3.fromRGB(80, 74, 66)))
	local function line(order: number, height: number): Frame
		return make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order }, bar)
	end
	local function text(parent: Instance, rich: string, size: number, x: number, w: number, align: Enum.TextXAlignment?, color: Color3?): TextLabel
		return make("TextLabel", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(if w > 0 then 0 else 1, if w > 0 then w else -x, 1, 0),
			BackgroundTransparency = 1,
			Text = rich,
			RichText = true,
			TextColor3 = color or BONE,
			Font = Enum.Font.GothamBold,
			TextSize = size,
			TextXAlignment = align or Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, parent)
	end
	local function fill(parent: Instance, y: number, h: number, ratio: number, color: Color3, w: number?): Frame
		local track = make("Frame", { Position = UDim2.fromOffset(0, y), Size = if w then UDim2.fromOffset(w, h) else UDim2.new(1, 0, 0, h), BackgroundColor3 = Color3.fromRGB(30, 27, 34), BorderSizePixel = 0 }, parent)
		stroke(track, BONE, 0.85)
		make("Frame", { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
		return track
	end

	-- 1) 이름 · 페이즈 · 체력 합
	local top = line(1, 20)
	-- 판 변주·마지막 발악 이름(GridBattle 표와 같은 Id)
	local variantName, lastName = "", ""
	for _, v in GridBattle.BOSS_VARIANTS do
		if v.Id == bossSnap.Variant then
			variantName = v.Name
		end
	end
	for _, v in GridBattle.BOSS_LAST_STANDS do
		if v.Id == bossSnap.LastStand then
			lastName = v.Name
		end
	end
	text(top, string.format('<b>%s</b>   <font color="%s">%d페이즈</font>%s%s', def.Name, hex(GOLD), bossSnap.Phase or 1,
		if variantName ~= "" then string.format('   <font color="%s">판 변주: %s</font>', hex(STEEL), variantName) else "",
		if lastName ~= "" then string.format('   <font color="%s">마지막 발악: %s</font>', hex(RED), lastName) else ""), 15, 0, 420)
	text(top, string.format("체력 합  %s / %s  (%d%%)", comma(hp), comma(maxHp), math.floor((if maxHp > 0 then hp / maxHp else 0) * 100 + 0.5)), 13, 420, 0, Enum.TextXAlignment.Right, BODY)
	-- 2) 큰 체력바 + 페이즈 눈금
	local big = line(2, 16)
	local track = fill(big, 2, 12, if maxHp > 0 then hp / maxHp else 0, CRIMSON)
	for _, at in bossSnap.PhaseAt or {} do
		make("Frame", { Position = UDim2.new(at, -1, 0, -3), Size = UDim2.new(0, 2, 1, 6), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 2 }, track)
	end
	--[[
		부위마다 걸린 상태이상(2026-10-04 사용자: "보스에게 걸린 상태이상이 더 잘 보이도록").
		체력바 밑에 색 칩(키워드 색 바탕 · 이름 · 수치)으로 줄지어 띄운다. 지속 피해 넷 + 스택 상태이상.
	]]
	local DOTS = {
		{ "Bleed", "출혈", Color3.fromRGB(230, 90, 90) },
		{ "Poison", "독", Color3.fromRGB(150, 220, 120) },
		{ "Burn", "화상", Color3.fromRGB(255, 150, 70) },
		{ "Oil", "기름", Color3.fromRGB(200, 180, 120) },
	}
	local function statusChips(u: any): { { any } }
		local out = {}
		if not u then
			return out
		end
		for _, d in DOTS do
			if (u[d[1]] or 0) > 0 then
				table.insert(out, { d[2], u[d[1]], d[3] })
			end
		end
		local ids = {}
		for id, v in u.Stacks or {} do
			if v > 0 then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			local kw = Keywords.Get(id)
			local color = if kw and kw.Color then Color3.fromHex(kw.Color) else GOLD
			table.insert(out, { if kw then kw.Name else id, u.Stacks[id], color })
		end
		return out
	end
	local CHIP_H = 17
	local function chipRow(parent: Instance, y: number, list: { { any } })
		local row = make("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, CHIP_H), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		for i, chip in list do
			local col: Color3 = chip[3]
			local dark = (col.R * 0.3 + col.G * 0.59 + col.B * 0.11) > 0.55
			local label = make("TextLabel", {
				Size = UDim2.fromOffset(0, CHIP_H),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = col,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Text = string.format(" %s %s ", chip[1], tostring(chip[2])),
				TextColor3 = if dark then INK else Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBlack,
				TextSize = 12,
			}, row)
			make("UICorner", { CornerRadius = UDim.new(0, 4) }, label)
		end
	end

	-- 3) 부위 넷(이름·체력 → 체력바 → 상태이상 칩)
	local anyChips = false
	for _, part in def.Parts or {} do
		if #statusChips(units[part.Key]) > 0 then
			anyChips = true
		end
	end
	local PART_H = if anyChips then 30 + CHIP_H + 3 else 30
	local parts = line(3, PART_H)
	local n = #(def.Parts or {})
	local w = math.floor((BOSS_BAR_W - 24 - (n - 1) * 8) / math.max(n, 1))
	for i, part in def.Parts or {} do
		local u = units[part.Key]
		local alive = u ~= nil and u.Alive == true
		local box = make("Frame", { Position = UDim2.fromOffset((i - 1) * (w + 8), 0), Size = UDim2.fromOffset(w, PART_H), BackgroundTransparency = 1 }, parts)
		local color = part.Color or CRIMSON
		make("Frame", { Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = if alive then color else MUTED, BorderSizePixel = 0 }, box)
		local label = make("TextLabel", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -12, 0, 14),
			BackgroundTransparency = 1,
			Text = if alive then string.format("%s  %s", part.Name, comma(math.max(0, u.Health or 0))) else part.Name .. "  파괴됨",
			TextColor3 = if alive then BONE else MUTED,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, box)
		local _ = label
		fill(box, 18, 7, if u and (u.MaxHealth or 0) > 0 then (u.Health or 0) / u.MaxHealth else 0, if alive then color else MUTED)
		if alive then
			chipRow(box, 30, statusChips(u))
		end
	end
	-- 4) 보스 스테미나 + 상태
	local st = line(4, 16)
	local maxSt = math.max(1, bossSnap.MaxStamina or 100)
	fill(st, 4, 8, (bossSnap.Stamina or 0) / maxSt, if bossSnap.Overheat then RED else STAMINA, 180)
	local chips = { string.format("스테미나 %d/%d", math.floor(bossSnap.Stamina or 0), maxSt) }
	if bossSnap.Overheat then
		table.insert(chips, string.format('<font color="%s">과부하 — 공격 안 함 · 받는 피해 +50%%</font>', hex(RED)))
	end
	if (bossSnap.NoHeal or 0) > 0 then
		table.insert(chips, string.format('<font color="%s">회복 불가 %d턴</font>', hex(RED), bossSnap.NoHeal))
	end
	for _, b in bossSnap.Buffs or {} do
		table.insert(chips, string.format('<font color="%s">%s%s</font>', hex(GOLD), b.Name, if (b.Turns or -1) > 0 then " " .. b.Turns .. "턴" else ""))
	end
	local charge = bossSnap.Charge
	if charge and not charge.Broken then
		local cs = BattleSkills.ById(charge.SkillId)
		table.insert(chips, string.format('<font color="%s">%s %s — 끊기 %s/%s</font>', hex(TEAL), if cs then cs.Name else "?", if charge.Stage == "Release" then "터지기 직전" else "충전 중", comma(charge.Dealt or 0), comma(charge.Need or 0)))
	end
	if (bossSnap.AdaptCount or 0) > 0 then
		local sk = BattleSkills.ById(bossSnap.AdaptSkill or "")
		table.insert(chips, string.format('<font color="%s">적응형 패치 — %s 피해 −%d%%</font>', hex(RED), if sk then sk.Name else "?", math.floor(GridBattle.ADAPT_CUT * bossSnap.AdaptCount * 100 + 0.5)))
	end
	text(st, table.concat(chips, sep), 12, 190, 0, nil, BODY)
	-- 스테미나가 모자라 지금 못 쓰는 해금 스킬(아이디어 11 — 무엇을 막을지 보이게)
	local starved = {}
	local cut = 0
	for _, b in bossSnap.Buffs or {} do
		local bdef = GridBattle.BOSS_BUFFS[b.Id]
		cut += (bdef and bdef.CostCut) or 0
	end
	for _, part in def.Parts or {} do
		local u = units[part.Key]
		if u and u.Alive then
			for _, move in part.Moves or {} do
				local sk = move.Id and BattleSkills.ById(move.Id)
				local cost = sk and math.floor((sk.StaminaCost or 0) * (1 - math.min(0.9, cut))) or 0
				if sk and (move.Phase or 1) <= (bossSnap.Phase or 1) and cost > (bossSnap.Stamina or 0) then
					table.insert(starved, string.format('<font color="%s">%s(%d)</font>', hex(part.Color or BONE), sk.Name, cost))
				end
			end
		end
	end
	if #starved > 0 then
		local row = make("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = string.format('<font color="%s">스테미나 부족 — 못 씀</font>  %s', hex(MUTED), table.concat(starved, "  ")),
			RichText = true,
			TextWrapped = true,
			TextColor3 = BODY,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
		}, bar)
		local _ = row
	end
	-- 5) 이번 턴 예고(부위 색)
	local plans = {}
	for _, part in def.Parts or {} do
		local u = units[part.Key]
		local names = {}
		for _, p in (u and u.Alive and (u.Plans or (u.Plan and { u.Plan }))) or {} do
			local sk = BattleSkills.ById(p.SkillId)
			if sk then
				local tag = if p.Canceled then " (끊김)" elseif sk.BossKind == "Buff" then " [버프]" elseif sk.BossKind == "Charge" then " [충전]" elseif sk.BossKind == "Ultimate" then " [궁극기]" else ""
				table.insert(names, sk.Name .. tag)
			end
		end
		if #names > 0 then
			table.insert(plans, string.format('<font color="%s">● %s</font> %s', hex(part.Color or BONE), part.Name, table.concat(names, " → ")))
		end
	end
	if #plans > 0 then
		local row = make("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = "이번 턴  " .. table.concat(plans, sep) .. (if bossSnap.ComboNotes and #bossSnap.ComboNotes > 0
				then string.format('\n<font color="%s">연계 예고</font>  %s', hex(TEAL), table.concat(bossSnap.ComboNotes, sep))
				else ""),
			RichText = true,
			TextWrapped = true,
			TextColor3 = BONE,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 5,
		}, bar)
		local _ = row
	end
end

function BattleHud:SetActive(on: boolean)
	self.active = on
	if not on and self.bossBar then
		self.bossBar.Visible = false
	end
	self.dock.Visible = on
	self.exit.Visible = on
	self.stance.Visible = on and self.stanceShown
	if not on then
		self.log.Visible = false
		self.effectPinned = nil
		self.effectPop.Visible = false
		self:_hideTip()
		self:HideBossInfo()
		self:QteClose()
	end
end

function BattleHud:SetLog(text: string?)
	self.log.Visible = self.active and text ~= nil and text ~= ""
	self.log.Text = text or ""
end

function BattleHud:SetVitals(hp: number, maxHp: number, stamina: number, maxStamina: number)
	self.hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(maxHp, 1), 0, 1), 1)
	self.hpText.Text = string.format("체력  %d / %d", hp, maxHp)
	self.staminaFill.Size = UDim2.fromScale(math.clamp(stamina / math.max(maxStamina, 1), 0, 1), 1)
	self.staminaText.Text = string.format("스테미나  %d / %d", math.floor(stamina), maxStamina)
end

--[[
	스킬 목록. rebuild 가 참이면 슬롯을 새로 찍는다(직업·강화가 바뀌어 개수·순서가 달라졌을 때).
	아니면 쿨타임 같은 값만 바꿔 든다.
]]
function BattleHud:SetSkills(skills: { any }, rebuild: boolean)
	self.skills = skills
	if not rebuild and #self.slots == #skills then
		return
	end
	self:_hideTip()
	for _, slot in self.slots do
		slot.Button:Destroy()
	end
	self.slots = {}
	local rowW = #skills * SLOT_W + math.max(#skills - 1, 0) * SLOT_GAP
	self.dock.Size = UDim2.fromOffset(rowW + 14 + ACTION_W, SLOT_H)
	for index, skill in skills do
		self.slots[index] = self:_makeSlot(index, skill)
	end
	self:_rescale()
end

function BattleHud:_makeSlot(index: number, skill: any): any
	local kind = KIND[skill.Kind] or KIND.Class
	local button = make("TextButton", {
		Name = "Slot" .. index,
		Position = UDim2.fromOffset((index - 1) * (SLOT_W + SLOT_GAP), 0),
		Size = UDim2.fromOffset(SLOT_W, SLOT_H),
		AutoButtonColor = false,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Text = "",
	}, self.slotRow)
	local edge = stroke(button, BONE, 0.72)
	-- 종류 띠(위): 직업 붉게 · 강화 금 · 공용 쇠빛
	make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = kind.Color, BorderSizePixel = 0 }, button)
	local key = keycap(button, tostring(index), 20, 20, 12)
	key.Position = UDim2.fromOffset(7, 10)
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 12),
		Size = UDim2.fromOffset(80, 16),
		BackgroundTransparency = 1,
		Text = if skill.Kind == "Class" then (skill.RangeLabel or "") else kind.Label,
		TextColor3 = if skill.Kind == "Class" then MUTED else kind.Color,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, button)
	local name = make("TextLabel", {
		Position = UDim2.fromOffset(9, 34),
		Size = UDim2.new(1, -18, 0, 34),
		BackgroundTransparency = 1,
		Text = skill.Name,
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, button)
	make("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 17 }, name)
	local meta = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 9, 1, -7),
		Size = UDim2.new(1, -18, 0, 15),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, button)
	-- 쿨타임·잠김 덮개: 큰 숫자 하나
	local cover = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, button)
	local big = make("TextLabel", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 36,
		ZIndex = 3,
	}, cover)
	local caption = make("TextLabel", {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 3,
	}, cover)

	button.Activated:Connect(function()
		self.callbacks.Select(index)
	end)
	button.MouseEnter:Connect(function()
		self.hovered = index
		self:_showTip(index)
		self:_paintSlot(index)
	end)
	button.MouseLeave:Connect(function()
		if self.hovered == index then
			self.hovered = nil
		end
		self:_paintSlot(index)
		self:_hideTipSoon(index)
	end)
	return { Button = button, Edge = edge, Name = name, Meta = meta, Cover = cover, Big = big, Caption = caption }
end

--[[
	매번 칠하는 값(BattleClient._paintTiles 가 부른다).
	  info = { Selected, Stamina, Stunned }
]]
function BattleHud:Paint(info: { Selected: number, Stamina: number, Stunned: boolean })
	self.selected = info.Selected
	self.stamina = info.Stamina
	self.stunned = info.Stunned
	for index in self.slots do
		self:_paintSlot(index)
	end
	self:_paintAttack()
end

-- 쓸 수 없는 까닭(없으면 nil)
function BattleHud:_blocker(skill: any): string?
	if not skill then
		return "스킬 없음"
	end
	if (skill.CooldownLeft or 0) > 0 then
		return string.format("재사용 대기 %d턴", skill.CooldownLeft)
	end
	if skill.Blocked then
		return "카드로 잠김"
	end
	if (skill.StaminaCost or 0) > (self.stamina or 0) then
		return string.format("스테미나 부족 %d/%d", math.floor(self.stamina or 0), skill.StaminaCost)
	end
	return nil
end

function BattleHud:_paintSlot(index: number)
	local slot = self.slots[index]
	local skill = self.skills[index]
	if not slot or not skill then
		return
	end
	local selected = index == self.selected
	local cooldown = skill.CooldownLeft or 0
	local cost = skill.StaminaCost or 0
	local lacking = cost > (self.stamina or 0)

	slot.Button.Position = UDim2.fromOffset((index - 1) * (SLOT_W + SLOT_GAP), if selected then -8 else 0)
	slot.Button.BackgroundColor3 = if selected then Color3.fromRGB(34, 29, 22) else INK
	slot.Edge.Color = if selected then GOLD else BONE
	slot.Edge.Thickness = if selected then 2 else 1
	slot.Edge.Transparency = if selected then 0 elseif self.hovered == index then 0.3 else 0.72

	local parts = {}
	if (skill.Damage or 0) > 0 then
		table.insert(parts, string.format('피해 <font color="%s">%d</font>', hex(BONE), skill.Damage))
	end
	if cost > 0 then
		table.insert(parts, string.format('<font color="%s">◆ %d</font>', hex(if lacking then RED else STAMINA), cost))
	end
	if (skill.Cooldown or 0) > 0 then
		table.insert(parts, string.format("쿨 %d", skill.Cooldown))
	end
	slot.Meta.Text = table.concat(parts, "   ")
	slot.Name.TextTransparency = if lacking then 0.45 else 0

	slot.Cover.Visible = cooldown > 0 or skill.Blocked == true
	if cooldown > 0 then
		slot.Big.Text = tostring(cooldown)
		slot.Caption.Text = "턴 뒤 사용"
	elseif skill.Blocked then
		slot.Big.Text = "✕"
		slot.Caption.Text = "카드로 잠김"
	end
end

function BattleHud:_paintAttack()
	local skill = self.skills[self.selected]
	local reason = if self.stunned then nil else self:_blocker(skill)
	local ready = reason == nil and not self.qteOpen
	self.attackTitle.Text = if self.stunned then "쉬기" elseif skill and (skill.Damage or 0) <= 0 then "사용" else "공격"
	self.attackSub.Text = if self.stunned then "그로기 — 이번 턴을 넘긴다" else (reason or (skill and skill.Name or ""))
	self.attack.BackgroundColor3 = if ready then Color3.fromRGB(112, 28, 28) else Color3.fromRGB(38, 34, 34)
	self.attackStroke.Transparency = if ready then 0.3 else 0.75
	self.attackTitle.TextColor3 = if ready then BONE else MUTED
	self.attackSub.TextColor3 = if reason then Color3.fromRGB(240, 140, 120) else Color3.fromRGB(236, 190, 176)
end

function BattleHud:SetStance(stance: any?)
	self.stanceShown = stance ~= nil
	self.stance.Visible = self.active and stance ~= nil
	if not stance then
		return
	end
	local now = if stance.Attack then "공격" else "방어"
	local nextOne = if stance.Attack then "방어" else "공격"
	local usable = not stance.Locked and not stance.Used
	if stance.Locked then
		self.stanceText.Text = now .. " 태세 · 카드로 고정"
	elseif stance.Used then
		self.stanceText.Text = now .. " 태세 · 이번 턴 전환함"
	else
		self.stanceText.Text = string.format("%s 태세  →  %s", now, nextOne)
	end
	self.stanceStroke.Color = if not usable then BONE elseif stance.Attack then STEEL else CRIMSON
	self.stanceStroke.Transparency = if usable then 0.1 else 0.7
	self.stanceText.TextColor3 = if usable then BONE else MUTED
	self.stanceKey.Visible = usable
end

--=== 스킬 설명 말풍선 ===--

function BattleHud:_buildTip()
	local tip = make("Frame", {
		Name = "SkillTip",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(TIP_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, self.gui)
	self.tip = tip
	self.tipScale = make("UIScale", {}, tip)
	stroke(tip, BONE, 0.65)
	brackets(tip, BONE, 12)
	-- 줄 세우기는 안쪽 판에서(꺾쇠까지 줄 세우지 않게)
	local inner = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, tip)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, inner)
	tip.MouseEnter:Connect(function()
		self.overTip = true
	end)
	tip.MouseLeave:Connect(function()
		self.overTip = false
		self:_hideTipSoon(self.tipFor)
	end)

	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 1 }, inner)
	self.tipAccent = make("Frame", {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromOffset(4, 24),
		BackgroundColor3 = CRIMSON,
		BorderSizePixel = 0,
	}, header)
	self.tipName = make("TextLabel", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -130, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	self.tipKind = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 16),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = CRIMSON,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, header)
	make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, self.tipKind)
	self.tipKindStroke = stroke(self.tipKind, CRIMSON, 0.3)
	self.tipStats = make("TextLabel", {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -30, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)

	make("Frame", {
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.fromOffset(14, 0),
		BackgroundColor3 = BONE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, inner)

	local pad = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, inner)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 14),
	}, pad)
	-- 설명: 높이는 글 길이만큼, 화면을 넘으면 잘라서 스크롤
	self.tipBody = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = BONE,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, pad)
	self.tipLayout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, self.tipBody)
	self.tipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:_fitTip()
	end)

	-- 키워드 풀이(말풍선 옆, 최대 3개)
	self.gloss = make("Frame", {
		Name = "Glossary",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(GLOSS_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, self.gui)
	self.glossScale = make("UIScale", {}, self.gloss)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, self.gloss)
end

function BattleHud:_fitTip()
	local content = self.tipLayout.AbsoluteContentSize.Y / math.max(self.scale, 0.01)
	local height = math.min(content, self.tipMax or 400)
	self.tipBody.Size = UDim2.new(1, 0, 0, height)
	self.tipBody.CanvasSize = UDim2.fromOffset(0, content)
end

local function statPart(label: string, value: string, color: Color3?): string
	return string.format('%s <font color="%s">%s</font>', label, hex(color or BONE), value)
end

function BattleHud:_showTip(index: number)
	local skill = self.skills[index]
	local slot = self.slots[index]
	if not skill or not slot then
		return
	end
	self.tipFor = index
	self.hideToken = nil
	local kind = KIND[skill.Kind] or KIND.Class

	self.tipAccent.BackgroundColor3 = kind.Color
	self.tipName.Text = skill.Name
	self.tipKind.Text = kind.Label
	self.tipKind.TextColor3 = kind.Color
	self.tipKindStroke.Color = kind.Color

	local stats = { statPart("", skill.RangeLabel or "") }
	if skill.ShapeText and skill.ShapeText ~= "" then
		table.insert(stats, statPart("", skill.ShapeText))
	end
	if (skill.Damage or 0) > 0 then
		table.insert(stats, statPart("피해", tostring(skill.Damage)))
	end
	if (skill.StaminaCost or 0) > 0 then
		table.insert(stats, statPart("스테미나", tostring(skill.StaminaCost), STAMINA))
	end
	if (skill.CooldownLeft or 0) > 0 then
		table.insert(stats, statPart("재사용", string.format("%d턴 남음", skill.CooldownLeft), RED))
	elseif (skill.Cooldown or 0) > 0 then
		table.insert(stats, statPart("재사용", string.format("%d턴", skill.Cooldown)))
	end
	self.tipStats.Text = table.concat(stats, string.format('<font color="%s">   |   </font>', hex(Color3.fromRGB(80, 74, 66))))

	for _, child in self.tipBody:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	describe(self.tipBody, skill.Description or "", kind.Color)

	-- 키워드 풀이: 사전에 있는 것 앞에서 셋. 풀이는 첫 줄만(공식 줄은 길다)
	for _, child in self.gloss:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, name in Keywords.Mentioned(skill.Description or "") do
		local keyword = Keywords.ByName(name)
		if not keyword or shown >= 3 then
			continue
		end
		shown += 1
		local color = (keyword :: any).Color or hex(GOLD)
		local box = make("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			LayoutOrder = shown,
		}, self.gloss)
		stroke(box, BONE, 0.75)
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 9),
		}, box)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, box)
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			RichText = true,
			Text = string.format(
				'<font color="%s"><b>%s</b></font>   <font color="%s">%s</font>',
				color,
				escape(keyword.Name),
				hex(MUTED),
				KEYWORD_KIND[keyword.Kind] or ""
			),
			TextColor3 = BONE,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, box)
		make("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
			Text = BattleHud.Markup(keyword.Description:match("^[^\n]*") or ""),
			TextColor3 = BODY,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			LineHeight = 1.1,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		}, box)
	end

	-- 자리: 슬롯 위 가운데, 화면 안으로. 풀이는 오른쪽(자리가 없으면 왼쪽)
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local s = self.scale
	local slotTop = slot.Button.AbsolutePosition.Y
	local bottom = view.Y - slotTop + 14
	local x = slot.Button.AbsolutePosition.X + slot.Button.AbsoluteSize.X / 2 - TIP_W * s / 2
	x = math.clamp(x, 12, view.X - 12 - TIP_W * s)
	self.tipMax = math.max(120, (slotTop - 14 - 70) / s - 64 - 26)
	self.tip.Position = UDim2.new(0, x, 1, -bottom)
	local gx = x + TIP_W * s + 8
	if gx + GLOSS_W * s > view.X - 12 then
		gx = x - 8 - GLOSS_W * s
	end
	self.gloss.Position = UDim2.new(0, gx, 1, -bottom)
	self.gloss.Visible = shown > 0
	self.tip.Visible = true
	self.tipBody.CanvasPosition = Vector2.zero
	self:_fitTip()
end

function BattleHud:_hideTip()
	self.tip.Visible = false
	self.gloss.Visible = false
	self.tipFor = nil
end

-- 슬롯에서 말풍선으로 마우스를 옮기는 틈(스크롤하려고)엔 닫지 않는다
function BattleHud:_hideTipSoon(index: number?)
	local token = {}
	self.hideToken = token
	task.delay(0.15, function()
		if self.hideToken == token and not self.overTip and self.hovered == nil and self.tipFor == index then
			self:_hideTip()
		end
	end)
end

--=== 보스 정보 창 ===--
--[[
	보스(부위)를 누르면 여는 창(2026-10-02 사용자: "보스를 클릭하면 부위 포함 사용하는 모든 스킬들의 설명을 볼 수 있게.
	AI티 나지 않게 여러 레퍼런스를 찾아야 함. UI 테마는 플레이어의 스킬 UI를 참고").
	참고한 것
	  - 붕괴: 스타레일 대상 정보: 체력·상태와 **가진 능력 전부**를 한 창에 — 고른 적 기준으로 연다
	  - 몬스터 헌터 와일즈 대형 몬스터 도감: **부위별로** 무엇이 부서지는지 — 여기선 부수면 일어나는 일
	  - Darkest Dungeon 적 정보: 능력 이름 옆 짧은 표식(출혈·기절 …) — 여기선 언제 쓰나·막을 수 있나를 작은 꼬리표로
	  - Into the Breach("멋보다 분명함"): 이번 턴 예고한 행동을 그 자리에서 바로 표시
	모양은 스킬 설명 말풍선과 같다: 먹빛 판 + 뼛빛 1px 선 + 모서리 꺾쇠, 왼쪽 색 막대, 마름모 글머리, 숫자·키워드만 색.
	부위마다 칸 하나: 이름 · 상태 꼬리표 · 체력 줄 · 행동(스킬) · 부수면. 누른 부위 칸은 금빛 테두리로, 그 칸까지 내려 준다.
	창 밖을 누르거나 Esc·X 로 닫는다(BattleClient).
]]
local function chip(parent: Instance, text: string, color: Color3, order: number): TextLabel
	local c = make("TextLabel", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		LayoutOrder = order,
	}, parent)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, c)
	stroke(c, color, 0.35)
	return c
end

-- 줄바꿈되는 설명 한 줄(RichText 로 이미 꾸민 글)
local function richRow(parent: Instance, rich: string, color: Color3, order: number?): TextLabel
	return make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = rich,
		RichText = true,
		TextWrapped = true,
		TextColor3 = color,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		LineHeight = 1.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = order or 0,
	}, parent)
end


function BattleHud:_buildBossInfo()
	local panel = make("Frame", {
		Name = "BossInfo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, -20),
		Size = UDim2.fromOffset(BOSS_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 12,
	}, self.gui)
	self.boss = panel
	self.bossScale = make("UIScale", {}, panel)
	stroke(panel, BONE, 0.65)
	brackets(panel, BONE, 12)
	local inner = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, panel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, inner)

	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 1 }, inner)
	make("Frame", { Position = UDim2.fromOffset(0, 14), Size = UDim2.fromOffset(4, 24), BackgroundColor3 = CRIMSON, BorderSizePixel = 0 }, header)
	self.bossName = make("TextLabel", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -150, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local kind = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 16),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "보스",
		TextColor3 = CRIMSON,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, header)
	make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, kind)
	stroke(kind, CRIMSON, 0.3)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 13),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = INK_2,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
	}, header)
	stroke(close, BONE, 0.55)
	close.Activated:Connect(function()
		self:HideBossInfo()
	end)
	self.bossStats = make("TextLabel", {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -30, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)

	make("Frame", {
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.fromOffset(14, 0),
		BackgroundColor3 = BONE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, inner)

	-- 2026-10-03 사용자: 부위마다 액티브·패시브·기믹을 따로. 위 줄 = 부위 탭(보스 전체 + 부위), 아래 줄 = 그 부위의 세 탭
	local tabs = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, inner)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10) }, tabs)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, tabs)
	self.bossTabRow = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 2 }, tabs)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, self.bossTabRow)
	self.bossPartRow = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1 }, tabs)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, self.bossPartRow)
	self.bossTab = "Active"

	local pad = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4 }, inner)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14) }, pad)
	self.bossBody = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = BONE,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, pad)
	self.bossLayout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, self.bossBody)
	self.bossLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:_fitBossInfo()
	end)
end

-- 탭 단추. 고른 것은 금빛 글·테두리와 밑줄
local function tabButton(parent: Instance, label: string, selected: boolean, accent: Color3, order: number, dim: boolean?, small: boolean?): TextButton
	local b = make("TextButton", {
		Size = UDim2.fromOffset(0, parent.Size.Y.Offset),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if selected then INK_2 else INK,
		BackgroundTransparency = if selected then 0 else 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = label,
		RichText = true,
		TextColor3 = if selected then accent elseif dim then MUTED else BONE,
		Font = if selected then Enum.Font.GothamBlack else Enum.Font.GothamBold,
		TextSize = if small then 12 else 13,
		LayoutOrder = order,
	}, parent)
	make("UIPadding", { PaddingLeft = UDim.new(0, if small then 7 else 10), PaddingRight = UDim.new(0, if small then 7 else 10) }, b)
	stroke(b, if selected then accent else BONE, if selected then 0.2 else 0.75)
	if selected then
		make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, if small then -7 else -10, 1, 0), Size = UDim2.new(1, if small then 14 else 20, 0, 2), BackgroundColor3 = accent, BorderSizePixel = 0 }, b)
	end
	return b
end

function BattleHud:_fitBossInfo()
	local s = math.max(self.scale, 0.01)
	local content = self.bossLayout.AbsoluteContentSize.Y / s
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- 화면 높이의 70% 안(아래 판·위 줄과 겹치지 않게). 탭을 바꿔도 창 크기가 그대로여야 탭 단추가 제자리에 있다
	-- (2026-10-03: 내용 길이를 따라 줄면 창이 가운데 기준으로 움직여 다음 탭 누름이 엉뚱한 단추에 맞았다)
	local height = view.Y * 0.7 / s - 130
	self.bossBody.Size = UDim2.new(1, 0, 0, math.max(60, height))
	self.bossBody.CanvasSize = UDim2.fromOffset(0, content)
end

function BattleHud:IsBossInfoOpen(): boolean
	return self.boss.Visible
end

-- 화면 점이 창 위인가(창 밖을 누르면 닫는다)
function BattleHud:IsOverBossInfo(point: Vector2): boolean
	local p, size = self.boss.AbsolutePosition, self.boss.AbsoluteSize
	return self.boss.Visible and point.X >= p.X and point.X <= p.X + size.X and point.Y >= p.Y and point.Y <= p.Y + size.Y
end

function BattleHud:HideBossInfo()
	self.boss.Visible = false
	self.bossFocus = nil
end

-- 부위 행동 하나(스킬이면 BattleSkills 에서 이름·설명·피해·방어 규칙을 가져온다)
local KIND_CHIP = { Attack = "공격", Buff = "버프", Charge = "충전", Ultimate = "궁극기", Gimmick = "기믹" }
function BattleHud:_bossMove(parent: Instance, move: any, order: number, planned: { [string]: boolean }, alive: boolean, phase: number, stamina: number?)
	local skill = if move.Id then BattleSkills.ById(move.Id) else nil
	-- 머리(이름·꼬리표·수치 줄) 아래에 설명 줄 — 스킬 설명 말풍선과 같은 짜임
	local holder = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, parent)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, holder)
	make("UIPadding", { PaddingTop = UDim.new(0, 4) }, holder)
	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1 }, holder)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, top)
	make("TextLabel", {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = if skill then skill.Name else (move.Name or "?"),
		TextColor3 = if alive then BONE else MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		LayoutOrder = 1,
	}, top)
	local locked = (move.Phase or 1) > phase
	if move.Id and planned[move.Id] then
		chip(top, "이번 턴 예고", RED, 2)
	end
	chip(top, move.When, if locked then MUTED else STEEL, 3)
	if skill and skill.BossKind then
		chip(top, KIND_CHIP[skill.BossKind] or skill.BossKind, if skill.BossKind == "Ultimate" then RED elseif skill.BossKind == "Buff" then GOLD else TEAL, 4)
	end
	if locked then
		chip(top, "아직 잠김", MUTED, 5)
	elseif skill and stamina and (skill.StaminaCost or 0) > stamina and alive then
		chip(top, "스테미나 부족", RED, 5)
	end
	if skill then
		local stats = {}
		if (skill.Damage or 0) > 0 then
			table.insert(stats, statPart("피해", tostring(skill.Damage)))
		elseif skill.HpRatio then
			table.insert(stats, statPart("피해", string.format("지금 체력 %d%%", math.floor(skill.HpRatio * 100 + 0.5)), RED))
		end
		if (skill.StaminaCost or 0) > 0 then
			table.insert(stats, statPart("스테미나", tostring(skill.StaminaCost), if stamina and skill.StaminaCost > stamina then RED else nil))
		end
		if (skill.BossCooldown or 0) > 0 then
			table.insert(stats, statPart("재사용", skill.BossCooldown .. "턴"))
		end
		table.insert(stats, if skill.Unavoidable then statPart("방어", "회피·막기 불가", RED)
			elseif skill.GuardOnly then statPart("방어", "막기만", GOLD)
			elseif skill.DodgeOnly then statPart("방어", "회피만", GOLD)
			else statPart("방어", "회피·막기"))
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = table.concat(stats, string.format('<font color="%s">   |   </font>', hex(Color3.fromRGB(80, 74, 66)))),
			TextColor3 = MUTED,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		}, holder)
	end
	describe(holder, (if skill then skill.Description else move.Description) or "", CRIMSON, 10, not alive)
end

-- 정보 창의 "보스 전체" 탭 키(부위 키와 겹치지 않게)
local BOSS_ALL = "_All"

--[[
	2026-10-03 사용자: "각 부위별로 액티브랑 패시브랑 기믹을 따로따로 볼 수 있게".
	위 줄 = 부위 탭(보스 전체 + 부위 넷), 아래 줄 = 그 부위의 액티브 / 패시브 / 기믹.
	  액티브  그 부위가 쓰는 스킬(기믹 성격 스킬 — 검수·패치 적용 — 은 기믹으로)
	  패시브  정의 Passives 중 Part 가 그 부위인 것(Part 없는 것은 보스 전체)
	  기믹    그 부위의 기믹 행동 + Gimmicks 중 그 부위 것 + 부수면
	고른 부위·탭은 스냅샷이 바뀌어도 그대로. 창 크기는 _fitBossInfo 가 고정한다.
]]
function BattleHud:ShowBossInfo(snapshot: any, focus: string?)
	local bossSnap = snapshot and snapshot.Boss
	if not bossSnap then
		return
	end
	local def = EnemyDefinitions.Get(bossSnap.Id)
	local units: { [string]: any } = {}
	for _, u in snapshot.Units or {} do
		if u.Part then
			units[u.Part] = u
		end
	end
	if not focus then
		-- 고른 부위가 없으면 살아 있는 첫 부위
		for _, part in def.Parts or {} do
			local u = units[part.Key]
			if not focus and u and u.Alive then
				focus = part.Key
			end
		end
		focus = focus or BOSS_ALL
	end
	-- 새로 열거나 다른 부위를 골랐으면 그 부위 첫 탭(보스 전체는 패시브)
	if not self.boss.Visible or self.bossFocus ~= focus then
		self.bossTab = if focus == BOSS_ALL then "Passive" else "Active"
	end
	local keep = self.boss.Visible and self.bossFocus == focus and self.bossTabShown == self.bossTab
	local scrollAt = self.bossBody.CanvasPosition
	self.bossFocus = focus
	self.bossTabShown = self.bossTab
	self.bossSnapshot = snapshot

	local alive, total, hp, maxHp = 0, 0, 0, 0
	for _, part in def.Parts or {} do
		local u = units[part.Key]
		total += 1
		if u then
			hp += math.max(0, u.Health or 0)
			maxHp += u.MaxHealth or 0
			if u.Alive then
				alive += 1
			end
		end
	end
	self.bossName.Text = def.Name
	local sep = string.format('<font color="%s">   |   </font>', hex(Color3.fromRGB(80, 74, 66)))
	self.bossStats.Text = table.concat({
		statPart("부위", string.format("%d / %d", alive, total)),
		statPart("체력 합", string.format("%s / %s", comma(hp), comma(maxHp))),
		statPart("", string.format("%d턴 · %d페이즈", snapshot.Turn or 1, bossSnap.Phase or 1)),
	}, sep)

	-- 고른 부위의 몫 나누기
	local phase = bossSnap.Phase or 1
	local partDef
	for _, part in def.Parts or {} do
		if part.Key == focus then
			partDef = part
		end
	end
	local function mine(list: { any }?): { any }
		local out = {}
		for _, e in list or {} do
			if (e.Part or BOSS_ALL) == focus then
				table.insert(out, e)
			end
		end
		return out
	end
	local passives, gimmicks = mine(def.Passives), mine(def.Gimmicks)
	local skillMoves, gimmickMoves = {}, {}
	for _, move in (partDef and partDef.Moves) or {} do
		local sk = move.Id and BattleSkills.ById(move.Id)
		if sk and sk.BossKind ~= "Gimmick" then
			table.insert(skillMoves, move)
		else
			table.insert(gimmickMoves, move)
		end
	end
	local nGimmick = #gimmickMoves + #gimmicks + (if partDef and partDef.Break then 1 else 0) + (if focus == BOSS_ALL and def.Rules then 1 else 0)

	-- 탭 줄 두 개
	for _, row in { self.bossTabRow, self.bossPartRow } do
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	local function partTab(key: string, label: string, color: Color3, order: number, dim: boolean)
		tabButton(self.bossPartRow, label, key == focus, color, order, dim, true).Activated:Connect(function()
			if self.bossFocus ~= key and self.bossSnapshot then
				self:ShowBossInfo(self.bossSnapshot, key)
			end
		end)
	end
	partTab(BOSS_ALL, "보스 전체", GOLD, 0, false)
	for i, part in def.Parts or {} do
		local u = units[part.Key]
		local dead = not (u and u.Alive)
		local dot = string.format('<font color="%s">■</font> ', hex(if dead then MUTED else (part.Color or BONE)))
		local planned = if not dead and u and ((u.Plans and #u.Plans > 0) or u.Plan) then string.format(' <font color="%s">!</font>', hex(RED)) else ""
		partTab(part.Key, dot .. (if dead then "<s>" .. part.Name .. "</s>" else part.Name) .. planned, part.Color or GOLD, i, dead)
	end
	local TABS = {
		{ "Active", "액티브", CRIMSON, #skillMoves },
		{ "Passive", "패시브", GOLD, #passives },
		{ "Gimmick", "기믹", TEAL, nGimmick },
	}
	for i, t in TABS do
		if focus == BOSS_ALL and t[1] == "Active" then
			continue -- 보스 전체에는 스킬이 없다(스킬은 부위가 쓴다)
		end
		local label = string.format('%s <font color="%s">%d</font>', t[2], hex(MUTED), t[4])
		tabButton(self.bossTabRow, label, self.bossTab == t[1], t[3], i, t[4] == 0).Activated:Connect(function()
			if self.bossTab ~= t[1] and self.bossSnapshot then
				self.bossTab = t[1]
				self:ShowBossInfo(self.bossSnapshot, self.bossFocus)
			end
		end)
	end

	-- 본문
	for _, child in self.bossBody:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function panelBox(): Frame
		local box = make("Frame", {
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = INK_2,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
		}, self.bossBody)
		stroke(box, BONE, 0.8)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10) }, box)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, box)
		return box
	end
	local function entries(list: { any }, accent: Color3)
		for _, entry in list do
			local box = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, self.bossBody)
			make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, box)
			make("UIPadding", { PaddingLeft = UDim.new(0, 4) }, box)
			richRow(box, string.format('<font color="%s"><b>%s</b></font>', hex(BONE), entry.Name), BONE, 0)
			describe(box, entry.Description, accent, 1)
		end
	end
	local function empty(text: string)
		richRow(self.bossBody, text, MUTED, nextOrder())
	end

	-- 부위 머리: 이름·상태·체력 줄(세 탭 모두 위에)
	local isAlive = false
	if partDef then
		local u = units[partDef.Key]
		isAlive = u ~= nil and u.Alive == true
		local box = panelBox()
		local head = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}, head)
		make("TextLabel", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = partDef.Name,
			TextColor3 = if isAlive then (partDef.Color or BONE) else MUTED,
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			LayoutOrder = 1,
		}, head)
		if not isAlive then
			chip(head, "파괴됨", MUTED, 2)
		elseif partDef.Key == "Core" and alive > 1 then
			chip(head, "잠김 — 다른 부위가 남음", GOLD, 2)
		end
		if u and u.Stunned and isAlive then
			chip(head, "그로기", TEAL, 3)
		end
		local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 2 }, box)
		local track = make("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -128, 0, 6), BackgroundColor3 = INK, BorderSizePixel = 0 }, bar)
		stroke(track, BONE, 0.85)
		local ratio = if u and (u.MaxHealth or 0) > 0 then math.clamp((u.Health or 0) / u.MaxHealth, 0, 1) else 0
		make("Frame", { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = if isAlive then CRIMSON else MUTED, BorderSizePixel = 0 }, track)
		make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, -1),
			Size = UDim2.fromOffset(120, 14),
			BackgroundTransparency = 1,
			Text = if u then string.format("%s / %s", comma(math.max(0, u.Health or 0)), comma(u.MaxHealth or 0)) else "-",
			TextColor3 = if isAlive then BONE else MUTED,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, bar)
	end
	local planned: { [string]: boolean } = {}
	local pu = partDef and units[partDef.Key]
	for _, p in (isAlive and pu and (pu.Plans or (pu.Plan and { pu.Plan }))) or {} do
		planned[p.SkillId] = true
	end
	local function moves(list: { any })
		if #list == 0 then
			return
		end
		local box = panelBox()
		for i, move in list do
			self:_bossMove(box, move, i, planned, isAlive, phase, bossSnap.Stamina)
		end
	end

	if self.bossTab == "Active" then
		moves(skillMoves)
		if #skillMoves == 0 then
			empty("이 부위는 쓰는 스킬이 없음.")
		end
	elseif self.bossTab == "Passive" then
		entries(passives, CRIMSON)
		if #passives == 0 then
			empty("이 부위만의 패시브는 없음 — [보스 전체] 탭의 규칙이 모든 부위에 걸림.")
		end
	else
		moves(gimmickMoves)
		entries(gimmicks, TEAL)
		if partDef and partDef.Break then
			local brk = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, self.bossBody)
			make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, brk)
			make("UIPadding", { PaddingLeft = UDim.new(0, 4) }, brk)
			richRow(brk, string.format('<font color="%s"><b>부수면</b></font>', hex(GOLD)), BONE, 0)
			describe(brk, partDef.Break, GOLD, 1, not isAlive)
		end
		if focus == BOSS_ALL and def.Rules then
			describe(make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, self.bossBody), table.concat(def.Rules, "\n"), CRIMSON)
		end
		if nGimmick == 0 then
			empty("이 부위만의 기믹은 없음.")
		end
	end

	self.boss.Visible = true
	self:_fitBossInfo()
	self.bossBody.CanvasPosition = if keep then scrollAt else Vector2.zero
end

--=== QTE ===--

local function ring(parent: Instance, color: Color3, transparency: number): (Frame, UIStroke)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	return frame, stroke(frame, color, transparency, 2)
end

-- 바깥으로 두께를 그리는 선(UIStroke)을 써서 반지름 r1~r2 띠를 그린다
local function setBand(frame: Frame, line: UIStroke, r1: number, r2: number)
	r1 = math.max(r1, 0)
	frame.Size = UDim2.fromOffset(r1 * 2, r1 * 2)
	line.Thickness = math.max(r2 - r1, 1)
end

function BattleHud:_buildQte()
	self.qteDim = make("Frame", {
		Name = "QteDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, self.gui)
	local panel = make("Frame", {
		Name = "Qte",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(QTE_W, QTE_H),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 21,
	}, self.gui)
	self.qtePanel = panel
	self.qteScale = make("UIScale", {}, panel)
	stroke(panel, BONE, 0.72)
	brackets(panel, BONE, 16)

	local head = make("Frame", {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 30),
		BackgroundTransparency = 1,
	}, panel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, head)
	local function tag(order: number): TextLabel
		local label = make("TextLabel", {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			Text = "",
			TextColor3 = INK,
			Font = Enum.Font.GothamBlack,
			TextSize = 13,
			LayoutOrder = order,
		}, head)
		make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, label)
		return label
	end
	self.qteRole = tag(1)
	self.qteTitle = make("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 23,
		LayoutOrder = 2,
	}, head)
	self.qteFlag = tag(3)
	self.qteFlag.BackgroundColor3 = RED
	self.qteFlag.TextColor3 = BONE

	self.qteHint = make("TextLabel", {
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	local body = make("Frame", {
		Position = UDim2.fromOffset(20, 82),
		Size = UDim2.new(1, -40, 0, 146),
		BackgroundTransparency = 1,
	}, panel)

	-- 스윕: 긴 바, 초록 칸, 커서
	local sweep = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 0, 34),
		BackgroundColor3 = INK_2,
		BorderSizePixel = 0,
	}, sweep)
	stroke(track, BONE, 0.7)
	for i = 1, 9 do
		make("Frame", {
			Position = UDim2.fromScale(i / 10, 0.25),
			Size = UDim2.new(0, 1, 0.5, 0),
			BackgroundColor3 = BONE,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, track)
	end
	self.sweepZone = make("Frame", { BackgroundColor3 = TEAL, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, track)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = TEAL,
		BorderSizePixel = 0,
	}, self.sweepZone)
	self.sweepCursor = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 5, 1, 22),
		BackgroundColor3 = BONE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)
	stroke(self.sweepCursor, Color3.new(0, 0, 0), 0.3)
	self.qteSweep = sweep

	-- 고리: 초록 띠(성공)·옅은 띠(막기/보통)·줄어드는 흰 고리
	local ringBox = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_R * 2 + 10, RING_R * 2 + 10),
		BackgroundTransparency = 1,
		Visible = false,
	}, body)
	self.bandPartial = { ring(ringBox, TEAL, 0.84) }
	self.bandSuccess = { ring(ringBox, TEAL, 0.45) }
	self.ringTarget = { ring(ringBox, TEAL, 0) }
	self.ringOuter = { ring(ringBox, BONE, 0) }
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = BONE,
		BorderSizePixel = 0,
	}, ringBox)
	self.qteRing = ringBox

	-- 연타: 키캡 + 큰 숫자 + 눈금 바
	local mash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	self.mashKey = keycap(mash, "SPACE", 180, 62, 22)
	self.mashKey.AnchorPoint = Vector2.new(0, 0.5)
	self.mashKey.Position = UDim2.new(0, 30, 0.42, 0)
	self.mashCount = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.42, 0),
		Size = UDim2.fromOffset(240, 70),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 56,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, mash)
	self.mashBar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -60, 0, 12),
		BackgroundColor3 = INK_2,
		BorderSizePixel = 0,
	}, mash)
	stroke(self.mashBar, BONE, 0.7)
	self.mashPartial = make("Frame", { BackgroundColor3 = TEAL, BackgroundTransparency = 0.8, BorderSizePixel = 0 }, self.mashBar)
	self.mashSuccess = make("Frame", { BackgroundColor3 = TEAL, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, self.mashBar)
	self.mashFill = make("Frame", { BackgroundColor3 = BONE, BorderSizePixel = 0, ZIndex = 2 }, self.mashBar)
	self.qteMash = mash

	-- 방향: 키캡 줄
	local dir = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
	}, dir)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 9),
	}, row)
	self.dirCaps = {}
	for i = 1, QteDefinitions.COMMAND_COUNT do
		-- 크고 굵게(2026-09-29 요청: 화살표가 잘 안 보인다). 글자에 검은 테를 둘러 어떤 칸 색에서도 읽히게
		local cap = keycap(row, "", 68, 68, 40)
		make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, cap)
		cap.LayoutOrder = i
		cap.Visible = false
		-- 크기는 고정(2026-09-29 요청: 둠칫거리면 알아보기 힘들다) — 차례는 색과 테두리로만
		self.dirCaps[i] = { Cap = cap, Stroke = cap:FindFirstChildOfClass("UIStroke") }
	end
	self.dirNote = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		RichText = true,
	}, dir)
	self.qteDir = dir

	-- 남은 시간(판 아래 가장자리가 줄어든다)
	self.qteTimer = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = BONE,
		BorderSizePixel = 0,
	}, panel)

	-- 판정 글자(판이 닫힌 뒤에도 잠깐 남는다)
	self.flash = make("TextLabel", {
		Name = "Grade",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(600, 64),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 50,
		Visible = false,
		ZIndex = 23,
	}, self.gui)
	self.flashStroke = make("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, self.flash)
	self.flashSub = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(600, 22),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		ZIndex = 23,
	}, self.flash)
	self.flashSubStroke = make("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, self.flashSub)
end

--[[
	QTE 를 연다.
	  role    "Skill" | "Dodge"
	  title   스킬 이름 / 적 공격 이름
	  word    Dodge 일 때 "회피" 또는 "패리"(결투사)
	  flag    빨간 딱지(가드 불가 따위). 없으면 nil
]]
function BattleHud:QteOpen(challenge: any, role: string, title: string, word: string, flag: string?)
	self.qteOpen = true
	self:_hideTip()
	self.qteDim.Visible = true
	self.qtePanel.Visible = true
	self.qteRole.Text = if role == "Skill" then "공격" else word
	self.qteRole.BackgroundColor3 = if role == "Skill" then CRIMSON else STEEL
	self.qteTitle.Text = title
	self.qteFlag.Text = flag or ""
	self.qteFlag.Visible = flag ~= nil
	self.qteMarks = {}

	local kind = challenge.Type
	self.qteSweep.Visible = kind == "Sweep"
	self.qteRing.Visible = kind == "Forge" or kind == "Parry"
	self.qteMash.Visible = kind == "Mash"
	self.qteDir.Visible = kind == "Directional"

	local key = string.format('<font color="%s"><b>SPACE</b></font> 또는 <font color="%s"><b>클릭</b></font>', hex(BONE), hex(BONE))
	if kind == "Sweep" then
		self.qteHint.Text = key .. " — 흰 막대가 초록 칸 안에 들어왔을 때"
	elseif kind == "Forge" or kind == "Parry" then
		self.qteHint.Text = key .. " — 줄어드는 흰 고리가 초록 띠에 겹칠 때"
	elseif kind == "Mash" then
		local goal = challenge.Goal or 8
		self.qteHint.Text = string.format(
			'<font color="%s"><b>SPACE</b></font>를 딱 <font color="%s"><b>%d</b></font>번 — %d번까지 성공, 넘치면 감점',
			hex(BONE),
			hex(TEAL),
			goal,
			goal + 1
		)
		-- 눈금: 0 ~ 목표+3. 성공(목표·목표+1)과 보통(±2) 구간
		local total = goal + 3
		self.mashTotal = total
		self.mashPartial.Position = UDim2.fromScale(math.max(goal - 2, 0) / total, 0)
		self.mashPartial.Size = UDim2.fromScale((math.min(goal + 2, total) - math.max(goal - 2, 0)) / total, 1)
		self.mashSuccess.Position = UDim2.fromScale((goal - 0.5) / total, 0)
		self.mashSuccess.Size = UDim2.fromScale(2 / total, 1)
	else
		local mistakes = QteDefinitions.COMMAND_DODGE_MISTAKES
		self.qteHint.Text = string.format(
			'<font color="%s"><b>방향키</b></font> 또는 <font color="%s"><b>WASD</b></font> — 왼쪽부터 순서대로 (%d번 틀려도 %s)',
			hex(BONE),
			hex(BONE),
			mistakes,
			word
		)
		local directions = challenge.ExpectedDirections or {}
		for i, cap in self.dirCaps do
			cap.Cap.Visible = directions[i] ~= nil
			cap.Cap.Text = DIRECTION_GLYPH[directions[i]] or ""
		end
	end
	self:_paintAttack()
end

-- 방향 입력 하나의 결과(맞았나)를 기억한다 — 틀린 키캡은 붉게 남는다
function BattleHud:QteMark(index: number, ok: boolean)
	self.qteMarks = self.qteMarks or {}
	self.qteMarks[index] = ok
end

function BattleHud:QteTick(challenge: any, visual: { [string]: any }, elapsed: number)
	local kind = challenge.Type
	local progress = math.clamp(elapsed / math.max(challenge.DurationMs, 1), 0, 1)
	self.qteTimer.Size = UDim2.new(1 - progress, 0, 0, 4)
	self.qteTimer.BackgroundColor3 = if progress > 0.7 then RED else BONE

	if kind == "Sweep" then
		local center = tonumber(visual.targetPosition) or 0.5
		local gap = tonumber(visual.successGap) or 0.12
		self.sweepZone.Position = UDim2.fromScale(math.clamp(center - gap, 0, 1), 0)
		self.sweepZone.Size = UDim2.fromScale(math.clamp(gap * 2, 0.02, 1), 1)
		local cursor = math.clamp(tonumber(visual.position) or 0, 0, 1)
		self.sweepCursor.Position = UDim2.fromScale(cursor, 0.5)
		self.sweepCursor.BackgroundColor3 = if math.abs(cursor - center) <= gap then TEAL else BONE
	elseif kind == "Forge" or kind == "Parry" then
		-- 단조는 VisualState 에 간격이 없다: Judge 의 0.11 / 0.22 와 같게
		local target = tonumber(visual.targetRadius) or 0.3
		local good = tonumber(visual.successGap) or 0.11
		local okay = tonumber(visual.partialGap) or 0.22
		local outer = tonumber(visual.outerRadius) or 1
		setBand(self.bandPartial[1], self.bandPartial[2], (target - okay) * RING_R, (target + okay) * RING_R)
		setBand(self.bandSuccess[1], self.bandSuccess[2], (target - good) * RING_R, (target + good) * RING_R)
		setBand(self.ringTarget[1], self.ringTarget[2], target * RING_R - 1, target * RING_R + 1)
		setBand(self.ringOuter[1], self.ringOuter[2], outer * RING_R - 1.5, outer * RING_R + 1.5)
		local near = math.abs(outer - target)
		self.ringOuter[2].Color = if near <= good then TEAL elseif near <= okay then GOLD else BONE
		self.ringOuter[2].Transparency = 1 - (tonumber(visual.indicatorOpacity) or 1)
	elseif kind == "Mash" then
		local count = tonumber(visual.count) or 0
		local goal = math.max(tonumber(visual.goal) or 8, 1)
		local total = self.mashTotal or (goal + 3)
		local over = count > goal + 1
		local color = if over then RED elseif count >= goal then TEAL else BONE
		self.mashCount.Text = string.format('<font color="%s">%d</font><font size="26" color="%s">  / %d</font>', hex(color), count, hex(MUTED), goal)
		self.mashFill.Size = UDim2.fromScale(math.clamp(count / total, 0, 1), 1)
		self.mashFill.BackgroundColor3 = color
	else
		local directions = visual.expectedDirections or {}
		local current = (tonumber(visual.sequenceIndex) or 0) + 1
		local marks = self.qteMarks or {}
		for i, cap in self.dirCaps do
			if not directions[i] then
				continue
			end
			local label, line = cap.Cap, cap.Stroke
			if i < current then
				local ok = marks[i] ~= false
				-- 넣은 것: 흐리게(맞음 초록 / 틀림 빨강)
				label.BackgroundColor3 = if ok then Color3.fromRGB(18, 42, 36) else Color3.fromRGB(74, 20, 20)
				label.TextColor3 = if ok then TEAL else RED
				label.TextTransparency = if ok then 0.45 else 0
				line.Color = if ok then TEAL else RED
				line.Transparency = 0.5
				line.Thickness = 1
			elseif i == current then
				-- 지금 차례: 금색으로 채우고 화살표는 먹색(가장 대비가 크다)
				label.BackgroundColor3 = GOLD
				label.TextColor3 = INK
				label.TextTransparency = 0
				line.Color = Color3.new(1, 1, 1)
				line.Transparency = 0
				line.Thickness = 2
			else
				-- 아직: 밝은 뼛빛 화살표
				label.BackgroundColor3 = Color3.fromRGB(44, 40, 48)
				label.TextColor3 = BONE
				label.TextTransparency = 0
				line.Color = BONE
				line.Transparency = 0.3
				line.Thickness = 1
			end
		end
		local mistakes = tonumber(visual.mistakes) or 0
		self.dirNote.Text = string.format(
			'틀림 <font color="%s"><b>%d</b></font>   ·   %d번까지 %s, %d번까지 막기',
			hex(if mistakes > QteDefinitions.COMMAND_DODGE_MISTAKES then RED else BONE),
			mistakes,
			QteDefinitions.COMMAND_DODGE_MISTAKES,
			self.qteRole.Text,
			QteDefinitions.COMMAND_GUARD_MISTAKES
		)
	end
end

function BattleHud:QteClose()
	self.qteOpen = false
	self.qteDim.Visible = false
	self.qtePanel.Visible = false
	if self.skills then
		self:_paintAttack()
	end
end

--[[
	화면 가운데 큰 글자 한 번(판정·과부하 알림). 0.35초 머물다 위로 흐려진다.
]]
function BattleHud:Flash(text: string, sub: string?, color: Color3)
	local label, subLabel = self.flash, self.flashSub
	for _, t in self.flashTweens or {} do
		t:Cancel()
	end
	label.Visible = true
	label.Text = text
	label.TextColor3 = color
	label.Position = UDim2.fromScale(0.5, 0.56)
	subLabel.Text = sub or ""
	label.TextTransparency, subLabel.TextTransparency = 0, 0
	self.flashStroke.Transparency, self.flashSubStroke.Transparency = 0, 0
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4)
	self.flashTweens = {
		TweenService:Create(label, info, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.52) }),
		TweenService:Create(subLabel, info, { TextTransparency = 1 }),
		TweenService:Create(self.flashStroke, info, { Transparency = 1 }),
		TweenService:Create(self.flashSubStroke, info, { Transparency = 1 }),
	}
	for _, t in self.flashTweens do
		t:Play()
	end
end

-- QTE 등급 → 글자
function BattleHud:FlashGrade(role: string, grade: string, word: string)
	local mult = QteDefinitions.Multipliers[role :: any][grade :: any]
	if role == "Skill" then
		local text = if grade == "Success" then "완벽" elseif grade == "Partial" then "보통" else "실패"
		self:Flash(text, string.format("피해 ×%s", tostring(mult)), if grade == "Success" then GOLD elseif grade == "Partial" then BONE else RED)
	else
		local text = if grade == "Success" then word elseif grade == "Partial" then "막음" else "피격"
		-- 결투사 패리는 피해를 다 막지 않는다(GridBattle.PARRY_KEEP — 10% 는 받고 90% 되돌림)
		local sub = if grade == "Success" and word == "패리" then "받는 피해량 −90%"
			elseif grade == "Success" then "피해 없음"
			elseif grade == "Partial" then "피해 절반" else "피해 그대로"
		self:Flash(text, sub, if grade == "Success" then TEAL elseif grade == "Partial" then BONE else RED)
	end
end

BattleHud.Colors = { Gold = GOLD, Red = RED, Teal = TEAL, Buff = Color3.fromRGB(70, 225, 255) }

return BattleHud
