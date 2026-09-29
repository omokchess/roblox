--!strict
--[[
	CardView — 능력 카드 **한 장을 그리는** 곳. (2026-09-28, TowerBattleController 보상판에서 떼어 냄)

	레벨업 화면(LevelUpUi)·디버그 패널(DebugBattlePanel)이 같은 카드 모양을 쓴다.

	  ┌────────────────┐
	  │ 희귀 · Lv.2 ●●○│  위: 등급색 바탕 + 그림(CardArt) + 등급·레벨 눈금
	  │    [ 그림 ]     │
	  │  이름           │
	  ├────────────────┤  ← 가운데 가로선(요청)
	  │ [선율][박자]    │  축 칩 — 덱 빌딩 축(CardAxes)
	  │ 설명 …          │  아래: 수치를 칠한 설명
	  └────────────────┘

	그림은 `CardArt.For` 가 주는 0~1 도형 목록을 Frame 으로 옮긴다. CanvasGroup 이어야 회전한 도형이 잘린다
	(ClipsDescendants 는 회전된 자손을 자르지 않는다).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CardArt = require(ReplicatedStorage.Shared.CardArt)
local CardAxes = require(ReplicatedStorage.Shared.CardAxes)

local CardView = {}

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

CardView.GRADE_STYLE = {
	Essential = { Name = "필수", Fill = Color3.fromRGB(96, 52, 154), Edge = Color3.fromRGB(214, 160, 255), Glow = Color3.fromRGB(190, 120, 255) },
	Rare = { Name = "희귀", Fill = Color3.fromRGB(38, 74, 150), Edge = Color3.fromRGB(120, 175, 255), Glow = Color3.fromRGB(90, 150, 255) },
	Common = { Name = "일반", Fill = Color3.fromRGB(58, 60, 70), Edge = Color3.fromRGB(170, 172, 186), Glow = Color3.fromRGB(200, 200, 210) },
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
CardView.Make = make

--[[
	문장마다 줄을 바꾼다(요청: "문장마다 줄바꿈 해서 도중에 문장이 끊기는 일이 없도록").
	카드 폭이 좁아 자동 줄바꿈이 문장 한가운데를 자르지 않게, 문장 끝에서 먼저 끊는다.
]]
function CardView.BreakSentences(text: string): string
	local broken = text:gsub("([다요]%.)%s+", "%1\n"):gsub("(%.)%s+", "%1\n")
	return (broken:gsub("%s+$", ""))
end

--[[
	수치(노랑)·[키워드](하늘)·`스킬`(굵게)을 칠한다. RichText 라 < > & 를 먼저 이스케이프한다.
	대괄호·백틱은 자리표시자로 빼 두고 숫자를 칠한 뒤 되돌린다 — 안 그러면 방금 넣은 태그 안의
	rgb 숫자까지 다시 칠해져 마크업이 깨진다.
]]
function CardView.Highlight(text: string): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	local keywords: { string } = {}
	escaped = escaped:gsub("(%[[^%]]+%])", function(match)
		table.insert(keywords, match)
		return "\1" .. string.rep("K", #keywords) .. "\1"
	end)
	local skills: { string } = {}
	escaped = escaped:gsub("`([^`]+)`", function(name)
		table.insert(skills, name)
		return "\2" .. string.rep("S", #skills) .. "\2"
	end)
	escaped = escaped:gsub("(%d+%.?%d*%%?)", '<font color="rgb(255,205,90)"><b>%1</b></font>')
	for index, keyword in keywords do
		escaped = escaped:gsub(
			"\1" .. string.rep("K", index) .. "\1",
			'<font color="rgb(120,200,255)">' .. keyword .. "</font>",
			1
		)
	end
	for index, name in skills do
		escaped = escaped:gsub("\2" .. string.rep("S", index) .. "\2", "<b>" .. name .. "</b>", 1)
	end
	return escaped
end

-- 카드 그림(등급 바탕 + 문양). parent 크기를 다 쓰고, 안에 정사각 캔버스를 가운데 둔다.
function CardView.PaintArt(parent: GuiObject, card: any)
	local art = CardArt.For(card)
	parent.BackgroundColor3 = art.Background
	local canvas = make("CanvasGroup", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	make("UIAspectRatioConstraint", {
		AspectRatio = 1,
		AspectType = Enum.AspectType.ScaleWithParentSize,
		DominantAxis = Enum.DominantAxis.Height,
	}, canvas)
	local strokes: { { Stroke: UIStroke, Ratio: number } } = {}
	for index, item in art.Shapes do
		local filled = item.Stroke <= 0
		local frame = make("Frame", {
			Name = string.format("S%02d", index),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(item.X, item.Y),
			Size = UDim2.fromScale(item.W, item.H),
			Rotation = item.Rotation,
			BackgroundColor3 = item.Color,
			BackgroundTransparency = if filled then item.Transparency else 1,
			BorderSizePixel = 0,
			ZIndex = item.ZIndex,
		}, canvas)
		if item.Corner > 0 then
			make("UICorner", { CornerRadius = UDim.new(item.Corner, 0) }, frame)
		end
		if not filled then
			local stroke = make("UIStroke", { Color = item.Color, Thickness = 2, Transparency = item.Transparency }, frame)
			table.insert(strokes, { Stroke = stroke, Ratio = item.Stroke })
		end
	end
	if #strokes > 0 then
		local function resize()
			local width = canvas.AbsoluteSize.X
			for _, entry in strokes do
				entry.Stroke.Thickness = math.max(entry.Ratio * width, 1)
			end
		end
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		resize()
	end
	return canvas
end

-- 작은 정사각 그림(목록 줄 왼쪽).
function CardView.Thumb(parent: Instance, card: any, size: number, position: UDim2?): Frame
	local style = CardView.GRADE_STYLE[card.Grade] or CardView.GRADE_STYLE.Common
	local thumb = make("Frame", {
		Name = "Thumb",
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.fromOffset(0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, thumb)
	make("UIStroke", { Color = style.Edge, Thickness = 1, Transparency = 0.3 }, thumb)
	CardView.PaintArt(thumb, card)
	return thumb
end

-- 레벨 눈금: 채운 칸 = 지금, 빛나는 칸 = 고르면 오를 칸, 빈 칸 = 남은 칸
local function pips(parent: Instance, level: number, maxLevel: number, nextLevel: number?, color: Color3)
	local row = make("Frame", {
		Name = "Pips",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(maxLevel * 11, 10),
		Position = UDim2.new(1, -8, 0, 11),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for index = 1, maxLevel do
		local filled = index <= level
		local upcoming = nextLevel ~= nil and index == nextLevel
		local pip = make("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Rotation = 45,
			BackgroundColor3 = if upcoming then Color3.fromRGB(255, 225, 120) elseif filled then color else Color3.fromRGB(20, 20, 26),
			BackgroundTransparency = if filled or upcoming then 0 else 0.2,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ZIndex = 12,
		}, row)
		make("UIStroke", { Color = if upcoming then Color3.fromRGB(255, 240, 180) else color, Thickness = 1 }, pip)
	end
	return row
end

-- 축 칩 한 줄. owned(축 → 보유 장수)를 주면 "선율 3" 처럼 지금 빌드의 장수를 함께 보인다.
function CardView.AxisChips(parent: Instance, card: any, owned: { [string]: number }?, position: UDim2, width: UDim): Frame
	local row = make("Frame", {
		Name = "Axes",
		Size = UDim2.new(width.Scale, width.Offset, 0, 20),
		Position = position,
		BackgroundTransparency = 1,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for index, tag in card.Tags or {} do
		local axis = CardAxes.Get(tag, card.ClassId)
		local color = axis and axis.Color or Color3.fromRGB(180, 180, 190)
		local count = owned and owned[tag] or 0
		local chip = make("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Text = if count > 0 then string.format("%s <b>%d</b>", axis and axis.Name or tag, count) else (axis and axis.Name or tag),
			RichText = true,
			TextColor3 = color,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			LayoutOrder = index,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, chip)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)
		make("UIStroke", { Color = color, Thickness = 1, Transparency = 0.45 }, chip)
	end
	return row
end

export type Handle = {
	Button: TextButton,
	SetSelected: (boolean) -> (),
}

--[[
	카드 한 장. opts
	  Size       카드 크기(기본: 부모 채움)
	  Offered    보상 제시 카드면 true — 레벨 눈금에 "고르면 오를 칸"을 빛낸다, 새 카드면 NEW 띠
	  Owned      축별 보유 장수(칩에 표시)
	  TextSize   설명 글자 크기(기본 16)
	  OnClick    눌렀을 때
]]
function CardView.Build(parent: Instance, card: any, opts: any?): Handle
	local options = opts or {}
	local style = CardView.GRADE_STYLE[card.Grade] or CardView.GRADE_STYLE.Common
	local level = card.Level or 0
	local maxLevel = card.MaxLevel or 6

	local button = make("TextButton", {
		Name = "Card_" .. tostring(card.Id),
		Size = options.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = options.LayoutOrder or 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	local stroke = make("UIStroke", { Color = style.Edge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	-- 뒤에서 번지는 빛(호버·선택). 글자 크기를 건드리지 않으려고 카드가 아니라 이 판만 부풀린다.
	local halo = make("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.Glow,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, button)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, halo)

	-- 위: 그림
	local art = make("Frame", {
		Name = "Art",
		Size = UDim2.fromScale(1, 0.48),
		BackgroundColor3 = style.Fill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, button)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, art)
	CardView.PaintArt(art, card)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
	}, art)

	local gradeLabel = make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(9, 6),
		BackgroundTransparency = 1,
		Text = if level > 0 then string.format("%s · Lv.%d", style.Name, level) else style.Name,
		TextColor3 = style.Edge,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, art)
	make("UIStroke", { Color = Color3.fromRGB(8, 8, 12), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, gradeLabel)
	pips(art, level, maxLevel, if options.Offered then level + 1 else nil, style.Edge)

	if options.Offered and level == 0 then
		local ribbon = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(46, 18),
			Position = UDim2.new(1, -8, 0, 26),
			BackgroundColor3 = Color3.fromRGB(255, 205, 90),
			BorderSizePixel = 0,
			Text = "NEW",
			TextColor3 = Color3.fromRGB(40, 28, 8),
			Font = Enum.Font.GothamBlack,
			TextSize = 12,
			ZIndex = 12,
		}, art)
		make("UICorner", { CornerRadius = UDim.new(0, 9) }, ribbon)
	end

	--[[
		띠: 파티 전제(솔로에서는 효과가 없거나 약하다) · 전직 배타(함께 들 수 없는 필수).
		그림 왼쪽 아래(이름판 위)에 쌓는다.
	]]
	local tags = {}
	if card.Party then
		table.insert(tags, { "파티 전제", Color3.fromRGB(90, 150, 220) })
	end
	if card.Excludes and #card.Excludes > 0 then
		table.insert(tags, { "배타: " .. table.concat(card.Excludes, "·"), Color3.fromRGB(200, 80, 90) })
	end
	for index, tag in tags do
		local badge = make("TextLabel", {
			Name = "Badge",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Position = UDim2.new(0, 8, 1, -42 - index * 21),
			BackgroundColor3 = tag[2],
			BorderSizePixel = 0,
			Text = tag[1],
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			ZIndex = 12,
		}, art)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, badge)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, badge)
	end

	make("Frame", {
		Name = "NamePlate",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, art)
	local nameLabel = make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 1, -38),
		BackgroundTransparency = 1,
		Text = card.Name or card.Id,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 19,
		TextScaled = false,
		TextWrapped = true,
		ZIndex = 11,
	}, art)
	make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 12 }, nameLabel)
	nameLabel.TextScaled = true

	make("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromScale(0, 0.48),
		BackgroundColor3 = style.Edge,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, button)

	CardView.AxisChips(button, card, options.Owned, UDim2.new(0, 10, 0.48, 10), UDim.new(1, -20))

	make("TextLabel", {
		Name = "Body",
		Size = UDim2.new(1, -20, 0.52, -44),
		Position = UDim2.new(0, 10, 0.48, 36),
		BackgroundTransparency = 1,
		Text = CardView.Highlight(CardView.BreakSentences(card.Description or "")),
		TextColor3 = Color3.fromRGB(222, 222, 232),
		Font = Enum.Font.Gotham,
		TextSize = options.TextSize or 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	}, button)

	local selected = false
	local function paint(hover: boolean)
		local lit = hover or selected
		TweenService:Create(stroke, HOVER, {
			Thickness = if selected then 4 elseif hover then 3 else 2,
			Color = if selected then Color3.fromRGB(255, 215, 110) else style.Edge,
		}):Play()
		TweenService:Create(halo, HOVER, {
			Size = if lit then UDim2.new(1, 18, 1, 18) else UDim2.fromScale(1, 1),
			BackgroundTransparency = if selected then 0.55 elseif hover then 0.75 else 1,
			BackgroundColor3 = if selected then Color3.fromRGB(255, 215, 110) else style.Glow,
		}):Play()
		button.ZIndex = if lit then 3 else 1
	end
	button.MouseEnter:Connect(function()
		paint(true)
	end)
	button.MouseLeave:Connect(function()
		paint(false)
	end)
	if options.OnClick then
		button.Activated:Connect(options.OnClick)
	end

	return {
		Button = button,
		SetSelected = function(value: boolean)
			selected = value
			paint(false)
		end,
	}
end

return CardView
