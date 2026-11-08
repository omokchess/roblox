--!strict
--[[
	PartyHud — 파티 전투 화면(2026-11-08, 파티전투_사양.md). 그리기와 클릭만 한다 — 서버 통신·무대는 BattleClient.

	  위 띠        행동 순서: 유닛 카드 → … → 적. 준비 단계엔 지금 자리로 센 순서(자리를 바꾸면 바로 다시 맨다),
	               실행 중엔 서버가 고정한 순서 + 지금 행동하는 유닛을 금색으로 밝힌다. 빗나갈 유닛에는 '빗나감'
	  아래 창      (준비 단계에서만) 왼쪽: 고른 유닛의 스탠딩·체력·스테미나·상태 칩 / 오른쪽: 행동 목록(스킬·가드)·유도 칩 3개·[턴 시작]
	  아래 가운데 글  실행 중 지금 누가 움직이는지

	모양은 BattleHud 와 같다: 먹빛 판 + 뼛빛 1px 선, 각진 모서리. 새 글자 UI 는 모두 AutoLocalize = false.
	QTE 는 파티 전투에서 아예 뜨지 않는다(BattleClient 가 막는다).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local ClassPassives = require(ReplicatedStorage.Shared.ClassPassives)
local Keywords = require(ReplicatedStorage.Shared.Keywords)
local BattleHud = require(script.Parent.BattleHud)
local PartyDefinitions = require(ReplicatedStorage.Shared.PartyDefinitions)

local PartyHud = {}
PartyHud.__index = PartyHud

local INK = Color3.fromRGB(15, 14, 18)
local BONE = Color3.fromRGB(230, 218, 194)
local BODY = Color3.fromRGB(204, 196, 182)
local MUTED = Color3.fromRGB(146, 138, 124)
local CRIMSON = Color3.fromRGB(200, 58, 50)
local GOLD = Color3.fromRGB(236, 186, 78)
local STEEL = Color3.fromRGB(128, 160, 196)
local RED = Color3.fromRGB(238, 72, 64)

local SLOT_W, SLOT_H, SLOT_GAP = 106, 84, 6
local MAX_SLOTS = 7
local LEFT_W = 330
local CARD_W, CARD_H = 116, 48
local INK_2 = Color3.fromRGB(28, 26, 31)
local PANEL_H = 190

-- 직업 색(카드 띠 · 무대 인형 몸 색)
local CLASS_COLORS: { [string]: Color3 } = {
	Attuner = Color3.fromRGB(150, 190, 255),
	AzureBlade = Color3.fromRGB(90, 150, 230),
	Berserker = Color3.fromRGB(210, 80, 70),
	WallPilgrim = Color3.fromRGB(200, 170, 110),
	Alchemist = Color3.fromRGB(130, 200, 120),
	Musician = Color3.fromRGB(230, 170, 210),
	Duelist = Color3.fromRGB(220, 200, 150),
	Quasar = Color3.fromRGB(170, 120, 230),
	Pulsar = Color3.fromRGB(100, 220, 220),
	WallMason = Color3.fromRGB(170, 150, 130),
	WallBreaker = Color3.fromRGB(200, 120, 70),
}

local KIND_COLOR: { [string]: Color3 } = { Class = CRIMSON, Upgrade = GOLD, Common = STEEL }

-- 카드·클래스 패시브(별)·기술 Id → 한국어 이름(없으면 nil)
local function nameOfId(id: string): string?
	local card = AbilityCardDefinitions.Get(id)
	if card then
		return card.Name
	end
	local passive = ClassPassives.Passive(id)
	if passive then
		return passive.Name
	end
	local skill = BattleSkills.ById(id)
	return if skill then skill.Name else nil
end

--[[
	화면에 Id 가 그대로 보이지 않게(2026-11-08 QA: "카드:Pulsar_Beacon 3턴", "[Attuner_Dubhe] 정산 2"): 글 속의
	"카드:Id" 와 "[Id]" 를 한국어 이름으로 바꾼다. 기록 줄·상태 칩이 모두 이 함수 하나를 지난다.
]]
function PartyHud.Readable(text: string): string
	local out = text:gsub("카드:([%w_]+)", function(id: string)
		return nameOfId(id) or id
	end)
	out = out:gsub("%[([%w_]+)%]", function(id: string)
		return "[" .. (nameOfId(id) or id) .. "]"
	end)
	return out
end

function PartyHud.ClassColor(classId: string?): Color3
	return CLASS_COLORS[classId or ""] or BONE
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(class)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if class == "TextLabel" or class == "TextButton" then
		(instance :: any).AutoLocalize = false
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

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, props: { [string]: any }?): any
	local base: { [string]: any } = {
		Position = pos,
		Size = size,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = BONE,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return make("TextLabel", base, parent)
end

--[[
	버튼 누름을 이름으로도 기억해 둔다(self.clicks[버튼 이름]) — Lune 연출 점검(smoke_director)의 흉내 인스턴스에는 Activated 신호가 없어
	거기서는 이 표로 눌러 본다. 스튜디오에서는 신호가 그대로 이어진다.
]]
local function onClick(self: any, button: any, handler: () -> ())
	self.clicks[button.Name] = handler
	local ok, signal = pcall(function()
		return button.Activated
	end)
	if ok then
		signal:Connect(handler)
	end
end

-- 마우스 올림/뗌(MouseEnter/MouseLeave). tip 이 있으면 설명 줄에 띄우고, fn(true/false) 도 부른다. smoke 용으로 self.hovers[이름] 에 기억
local function onHover(self: any, gui: any, tip: string?, fn: ((boolean) -> ())?)
	local function enter()
		if tip and self.tipLabel then
			self.tipLabel.Text = tip
		end
		if fn then
			fn(true)
		end
	end
	local function leave()
		if tip and self.tipLabel then
			self.tipLabel.Text = ""
		end
		if fn then
			fn(false)
		end
	end
	if fn then
		self.hovers[gui.Name] = function(on: boolean)
			if on then
				enter()
			else
				leave()
			end
		end
	end
	pcall(function()
		gui.MouseEnter:Connect(enter)
		gui.MouseLeave:Connect(leave)
	end)
end

-- 키워드 사전 설명(없으면 빈 글)
local function describe(name: string): string
	local keyword = Keywords.ByName(name)
	return if keyword then keyword.Description else ""
end

--[[
	행동 순서(살아 있는 아군 Id). 준비 단계엔 지금 자리로 센다(PartyDefinitions.ActionOrder — 행 1순위 · 열 2순위),
	그 밖엔 서버가 BeginTurn 에서 고정한 순서(쓰러진 유닛은 뺀다).
]]
function PartyHud.OrderOf(snapshot: any): { string }
	local units = snapshot.Units
	local ids: { string } = {}
	local party = snapshot.Party
	if party and party.Phase ~= "Prepare" then
		for _, id in party.Order do
			local unit = units[id]
			if unit and unit.Alive then
				table.insert(ids, id)
			end
		end
		return ids
	end
	local entries = {}
	for id, unit in units do
		if unit.Side == "Ally" and unit.ClassId and unit.Alive and unit.X and unit.Y then
			table.insert(entries, { Id = id, X = unit.X, Y = unit.Y })
		end
	end
	for _, entry in PartyDefinitions.ActionOrder(entries) do
		table.insert(ids, entry.Id)
	end
	return ids
end

export type Callbacks = {
	Select: (id: string?) -> (),
	Choose: (id: string, skillId: string?) -> (),
	Homing: (id: string, on: boolean) -> (),
	Begin: () -> (),
	-- 스킬에 마우스를 올리면 그 스킬 범위를 격자에 미리 보여 준다(떼면 nil)
	Hover: (skillId: string?) -> (),
	-- 솔로 HUD 의 설명 말풍선을 그대로 띄우고 거둔다(BattleHud.ShowSkillTip / ShowEffectTip)
	TipSkill: (skill: any?, anchor: GuiObject?) -> (),
	TipEffect: (effect: any?, anchor: GuiObject?) -> (),
	-- 유도 칸: id 를 주면 '적 고르기' 상태로, nil 이면 취소
	HomingPick: (id: string?) -> (),
}

function PartyHud.new(gui: ScreenGui, callbacks: Callbacks)
	local self = setmetatable({}, PartyHud) :: any
	self.gui = gui
	self.callbacks = callbacks
	self.active = false
	self.shown = {} :: { Instance }
	self.clicks = {} :: { [string]: () -> () }
	self.hovers = {} :: { [string]: (boolean) -> () }
	self.tips = {} :: { [any]: string }
	self.tipLabel = nil :: any
	self.standClone = nil :: Model?
	self.standId = nil :: string?
	self.standFailed = false

	self.strip = make("Frame", {
		Name = "PartyOrderStrip",
		AnchorPoint = Vector2.new(0.5, 0),
		-- 디버그 빠른 줄(DebugBattlePanel QuickBar: 위 8~42)의 아래
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(0, CARD_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, self.strip)

	-- 실행 중엔 아래 판이 없으니 그 자리에(위쪽은 기록 줄·보스 막대가 쓴다)
	self.banner = label(gui, "", UDim2.new(0.5, 0, 1, -36), UDim2.fromOffset(420, 28), {
		Name = "PartyBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = GOLD,
		Visible = false,
	})
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, self.banner)

	self.panel = make("Frame", {
		Name = "PartyPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(960, PANEL_H),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	self.panelScale = make("UIScale", {}, self.panel)
	return self
end

function PartyHud:SetActive(on: boolean)
	self.active = on
	if not on then
		self.strip.Visible = false
		self.banner.Visible = false
		self.panel.Visible = false
		self:_clear()
	end
end

function PartyHud:Destroy()
	self:_clear()
	if self.standClone then
		self.standClone:Destroy()
		self.standClone = nil
	end
	self.strip:Destroy()
	self.banner:Destroy()
	self.panel:Destroy()
end

function PartyHud:_clear()
	table.clear(self.clicks)
	table.clear(self.hovers)
	table.clear(self.tips)
	-- 스탠딩 복제본은 뷰포트와 함께 지워지지 않게 먼저 떼어 둔다(같은 유닛이면 다시 쓴다)
	if self.standClone then
		self.standClone.Parent = nil
	end
	for _, item in self.shown do
		item:Destroy()
	end
	table.clear(self.shown)
	for _, child in self.strip:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

-- 화면이 좁으면 아래 판을 줄인다(BattleHud 와 같은 규칙)
function PartyHud:_rescale(width: number)
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	self.panelScale.Scale = math.clamp(math.min(view.X / (width + 40), view.Y / 700), 0.6, 1)
end

--[[
	스냅샷이 올 때마다(그리고 고른 유닛이 바뀔 때마다) 다시 그린다.
	ui = { Selected = 고른 유닛 Id?, Busy = 연출 중인가, Acting = 지금 행동하는 유닛 Id | "Enemy" | nil, Miss = { [유닛 Id] = 빗나감 } }
]]
function PartyHud:Update(snapshot: any, ui: { Selected: string?, Busy: boolean, Acting: string?, Miss: { [string]: boolean }, Stand: Model?, Threatened: { [string]: boolean }?, Effects: { any }?, Picking: string? })
	self:_clear()
	self.standFailed = false
	if not self.active or not snapshot or not snapshot.Party then
		return
	end
	local party = snapshot.Party
	local units = snapshot.Units
	local members: { [string]: any } = {}
	for _, member in party.Members do
		members[member.Id] = member
	end
	local order = PartyHud.OrderOf(snapshot)
	local prep = party.Phase == "Prepare" and not ui.Busy and not snapshot.Turning and snapshot.Outcome == "Ongoing"

	-- 위 띠
	self.strip.Visible = true
	local actingIndex = if ui.Acting then table.find(order, ui.Acting) else nil
	for index, id in order do
		local unit, member = units[id], members[id]
		local active = ui.Acting == id
		local done = ui.Acting == "Enemy" or (actingIndex ~= nil and index < actingIndex)
		local card = make("Frame", {
			Name = "Card" .. index,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = if active then Color3.fromRGB(44, 36, 22) else INK,
			BackgroundTransparency = if done then 0.45 else 0.06,
			BorderSizePixel = 0,
			LayoutOrder = index * 2 - 1,
		}, self.strip)
		stroke(card, if active then GOLD else BONE, if active then 0 else 0.7, if active then 2 else 1)
		make("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = PartyHud.ClassColor(member and member.ClassId), BorderSizePixel = 0 }, card)
		label(card, tostring(index), UDim2.fromOffset(11, 3), UDim2.fromOffset(16, 20), {
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextColor3 = if active then GOLD else BONE,
		})
		label(card, if unit then unit.Name else id, UDim2.fromOffset(30, 4), UDim2.new(1, -34, 0, 18), {
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = if done then 0.4 else 0,
		})
		local sub = ""
		local subColor = MUTED
		if ui.Miss[id] then
			sub, subColor = "빗나감", RED
		elseif unit and unit.Homing then
			local foe = if unit.HomingTarget then units[unit.HomingTarget] else nil
			sub, subColor = "유도 → " .. (if foe then foe.Name else (if unit.AimY and unit.Y and unit.AimY < unit.Y then "▲" elseif unit.AimY and unit.Y and unit.AimY > unit.Y then "▼" else "·")), GOLD
		elseif unit then
			sub = string.format("체력 %d/%d", math.ceil(unit.Health), unit.MaxHealth)
		end
		label(card, sub, UDim2.fromOffset(12, 27), UDim2.new(1, -16, 0, 16), { TextSize = 12, TextColor3 = subColor })
		if index < #order then
			label(self.strip, "▶", UDim2.new(), UDim2.fromOffset(14, CARD_H), {
				LayoutOrder = index * 2,
				TextColor3 = MUTED,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	end
	-- 끝: 적
	label(self.strip, "▶", UDim2.new(), UDim2.fromOffset(14, CARD_H), {
		LayoutOrder = #order * 2,
		TextColor3 = MUTED,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local foe = make("Frame", {
		Name = "FoeCard",
		Size = UDim2.fromOffset(64, CARD_H),
		BackgroundColor3 = if ui.Acting == "Enemy" then Color3.fromRGB(64, 22, 20) else INK,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		LayoutOrder = #order * 2 + 1,
	}, self.strip)
	stroke(foe, CRIMSON, if ui.Acting == "Enemy" then 0 else 0.45, if ui.Acting == "Enemy" then 2 else 1)
	label(foe, "적", UDim2.new(), UDim2.fromScale(1, 1), {
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(240, 150, 140),
	})

	-- 가운데 위 글
	if prep or snapshot.Outcome ~= "Ongoing" then
		self.banner.Visible = false
	else
		self.banner.Visible = true
		local name = if ui.Acting and ui.Acting ~= "Enemy" and units[ui.Acting] then units[ui.Acting].Name else nil
		self.banner.Text = if ui.Acting == "Enemy" then "적의 행동" elseif name then "행동 중 — " .. name else "턴 진행 중"
	end

	-- 아래 창(준비 단계에서만): [왼쪽] 고른 유닛 스탠딩·상태 / [오른쪽] 행동 목록·유도·턴 시작
	self.panel.Visible = prep
	if not prep then
		return
	end
	local selected = ui.Selected
	if selected and not (units[selected] and units[selected].Alive) then
		selected = nil
	end
	local selMember = if selected then members[selected] else nil
	local selUnit = if selected then units[selected] else nil
	local skills = if selMember then selMember.Skills else {}
	-- 행동 목록(스킬 수, 최소 4칸) + 맨 끝 [유도] 칸
	local rightW = (math.max(math.min(#skills, MAX_SLOTS), 4) + 1) * (SLOT_W + SLOT_GAP) - SLOT_GAP
	local width = LEFT_W + 14 + rightW
	self.panel.Size = UDim2.fromOffset(width, PANEL_H)
	self:_rescale(width)

	-- 유닛 바꾸기 단추줄(창 왼쪽 위, 행동 순서대로 ①②③) — 3D 클릭이 안 돼도 고를 수 있다
	local picks = make("Frame", { Name = "Picks", Position = UDim2.fromOffset(0, -30), Size = UDim2.fromOffset(LEFT_W, 26), BackgroundTransparency = 1 }, self.panel)
	table.insert(self.shown, picks)
	for index, id in order do
		local isSel = id == selected
		local pick = make("TextButton", {
			Name = "Pick" .. index,
			Position = UDim2.fromOffset((index - 1) * 58, 0),
			Size = UDim2.fromOffset(54, 26),
			AutoButtonColor = false,
			BackgroundColor3 = if isSel then Color3.fromRGB(44, 36, 22) else INK,
			BorderSizePixel = 0,
			Text = tostring(index),
			TextColor3 = if isSel then GOLD else BONE,
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
		}, picks)
		stroke(pick, if isSel then GOLD else PartyHud.ClassColor(members[id] and members[id].ClassId), if isSel then 0 else 0.3, if isSel then 2 else 1)
		onClick(self, pick, function()
			self.callbacks.Select(id)
		end)
	end

	-- 왼쪽 칸
	local left = make("Frame", { Name = "Left", Size = UDim2.fromOffset(LEFT_W, PANEL_H), BackgroundColor3 = INK, BackgroundTransparency = 0.06, BorderSizePixel = 0 }, self.panel)
	table.insert(self.shown, left)
	stroke(left, BONE, 0.6)
	if not selMember or not selUnit then
		label(left, "아군 칸을 눌러 유닛을 고른다. 고르지 않은 유닛은 기본 공격을 쓴다.", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 60), { TextWrapped = true, TextColor3 = BODY, TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
	else
		-- 스탠딩: 무대의 인형을 복제해 정면 3/4 에서 비춘다(스탠딩 그림 파일이 없다)
		local stand = make("ViewportFrame", { Name = "Stand", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(112, PANEL_H - 12), BackgroundColor3 = INK_2, BackgroundTransparency = 0.3, BorderSizePixel = 0 }, left)
		self:_fillStand(stand, selected :: string, ui.Stand)
		local x0 = 126
		local cost = selMember.Cost
		label(left, selUnit.Name, UDim2.fromOffset(x0, 6), UDim2.new(1, -x0 - 6, 0, 20), { Font = Enum.Font.GothamBlack, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd })
		label(left, string.format("코스트 %s%s", tostring(cost or "?"), if selUnit.Taunt and selUnit.Taunt > 0 then string.format("  도발 %d", selUnit.Taunt) else ""), UDim2.fromOffset(x0, 25), UDim2.new(1, -x0 - 6, 0, 14), { TextSize = 11, TextColor3 = MUTED })
		local function bar(y: number, ratio: number, color: Color3, text: string)
			local back = make("Frame", { Position = UDim2.fromOffset(x0, y), Size = UDim2.new(1, -x0 - 8, 0, 16), BackgroundColor3 = INK, BorderSizePixel = 0 }, left)
			stroke(back, BONE, 0.7)
			make("Frame", { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
			label(back, text, UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0), { TextSize = 11, ZIndex = 2 })
		end
		bar(42, selUnit.Health / math.max(selUnit.MaxHealth, 1), Color3.fromRGB(150, 36, 40), string.format("체력  %d / %d", math.ceil(selUnit.Health), selUnit.MaxHealth))
		bar(62, (selMember.Stamina or 0) / math.max(selMember.MaxStamina or 1, 1), Color3.fromRGB(110, 118, 50), string.format("스테미나  %d / %d", math.floor(selMember.Stamina or 0), selMember.MaxStamina or 0))
		-- 효과 아이콘: 보호막·상태이상·직업 자원·음표는 솔로 효과 줄과 같은 아이콘+숫자(BattleHud.EffectIcon). 마우스를 올리면 설명
		local effects: { any } = {}
		for _, e in ui.Effects or {} do
			table.insert(effects, e)
		end
		if selUnit.Taunt and selUnit.Taunt > 0 then
			table.insert(effects, { Id = "Taunt", Name = "도발", Glyph = "도", Color = GOLD, Count = selUnit.Taunt, Desc = describe("도발") })
		end
		if selUnit.Homing then
			table.insert(effects, { Id = "HomingMark", Name = "유도", Glyph = "유", Color = GOLD, Desc = "고른 적이 선 행을 겨눈다. 그 적이 차례 전에 쓰러지면 자기 행 → 위 → 아래 행 순으로 겨눈다." })
		end
		if ui.Threatened and ui.Threatened[selected :: string] then
			table.insert(effects, { Id = "ThreatMark", Name = "예고 칸", Glyph = "危", Color = RED, Desc = "적의 공격이 이 칸에 온다. 가드를 고르면 받는 피해가 절반이 된다." })
		end
		local chipRow = make("Frame", { Name = "Chips", Position = UDim2.fromOffset(x0, 82), Size = UDim2.fromOffset(math.floor((LEFT_W - x0 - 6) / 0.8), 84), BackgroundTransparency = 1 }, left)
		make("UIScale", { Scale = 0.8 }, chipRow)
		local perRow = math.max(1, math.floor((LEFT_W - x0 - 6) / 0.8 / 42))
		for slot, e in effects do
			if slot > perRow * 2 then
				break
			end
			local icon = BattleHud.EffectIcon(chipRow, e, slot)
			icon.Position = UDim2.fromOffset(((slot - 1) % perRow) * 42, ((slot - 1) // perRow) * 42)
			-- 솔로 효과 줄과 같은 설명 말풍선
			onHover(self, icon, nil, function(on: boolean)
				self.callbacks.TipEffect(if on then e else nil, icon)
			end)
		end
	end

	-- 오른쪽 칸: 행동 목록(스킬·가드·호흡) + 맨 끝에 늘 보이는 [유도] 칸
	local right = make("Frame", { Name = "Right", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(rightW, PANEL_H), BackgroundTransparency = 1 }, self.panel)
	table.insert(self.shown, right)
	local slotRow = make("Frame", { Name = "Slots", Size = UDim2.new(1, 0, 0, SLOT_H + 10), BackgroundTransparency = 1 }, right)
	if selMember and selUnit then
		local basicId = if snapshot.Preview and snapshot.Preview[selected :: string] then snapshot.Preview[selected :: string].SkillId else nil
		for index, skill in skills do
			if index > MAX_SLOTS then
				break
			end
			local chosen = selUnit.Chosen == skill.Id
			local cooldown = skill.CooldownLeft or 0
			local lacking = (skill.StaminaCost or 0) > (selMember.Stamina or 0)
			local why = if cooldown > 0 then string.format("재사용 대기 %d턴", cooldown) elseif skill.Blocked then "카드로 잠김" elseif lacking then "스테미나 부족" else nil
			local slot = make("TextButton", {
				Name = "Slot" .. index,
				Position = UDim2.fromOffset((index - 1) * (SLOT_W + SLOT_GAP), if chosen then 0 else 8),
				Size = UDim2.fromOffset(SLOT_W, SLOT_H),
				AutoButtonColor = false,
				BackgroundColor3 = if chosen then Color3.fromRGB(34, 29, 22) else INK,
				BackgroundTransparency = if why then 0.4 else 0.06,
				BorderSizePixel = 0,
				Text = "",
			}, slotRow)
			stroke(slot, if chosen then GOLD else BONE, if chosen then 0 else 0.72, if chosen then 2 else 1)
			make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = KIND_COLOR[skill.Kind] or CRIMSON, BorderSizePixel = 0 }, slot)
			label(slot, tostring(index), UDim2.fromOffset(7, 6), UDim2.fromOffset(16, 14), { Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = MUTED })
			local tag = if chosen then "선택" elseif not selUnit.Chosen and basicId == skill.Id then "기본" else ""
			label(slot, tag, UDim2.new(1, -46, 0, 6), UDim2.fromOffset(40, 14), { TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if chosen then GOLD else BODY })
			local nameLabel = label(slot, skill.Name, UDim2.fromOffset(8, 22), UDim2.new(1, -16, 0, 22), { Font = Enum.Font.GothamBlack, TextScaled = true, TextWrapped = true, TextTransparency = if why then 0.5 else 0 })
			make("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 15 }, nameLabel)
			self:_shapeIcon(slot, skill)
			local parts = {}
			if (skill.Damage or 0) > 0 then
				table.insert(parts, string.format("피해 %d", skill.Damage))
			end
			if (skill.StaminaCost or 0) > 0 then
				table.insert(parts, string.format("◆%d", skill.StaminaCost))
			end
			if (skill.Cooldown or 0) > 0 then
				table.insert(parts, string.format("재사용 %d", skill.Cooldown))
			end
			label(slot, table.concat(parts, " "), UDim2.new(0, 8, 1, -18), UDim2.new(1, -16, 0, 14), { TextSize = 11, TextColor3 = if lacking then RED else MUTED })
			if why then
				label(slot, why, UDim2.fromOffset(8, 46), UDim2.new(1, -16, 0, 14), { TextSize = 11, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
			end
			local skillId = skill.Id
			onClick(self, slot, function()
				-- 이미 고른 스킬을 다시 누르면 고름을 지운다(기본 공격)
				self.callbacks.Choose(selected :: string, if chosen then nil else skillId)
			end)
			-- 마우스를 올리면: 격자에 범위 미리보기 + 솔로 스킬 바와 같은 설명창
			onHover(self, slot, nil, function(on: boolean)
				self.callbacks.Hover(if on then skillId else nil)
				self.callbacks.TipSkill(if on then skill else nil, slot)
			end)
		end
	end

	-- [유도] 칸: 행동 목록 맨 오른쪽에 늘 있다(유닛을 안 골랐으면 흐리게). 누르면 '적 고르기' → 적을 누르면 붙는다. 붙은 뒤 다시 누르면 뗀다
	local left2, per = party.HomingLeft or 0, party.HomingPerTurn or 3
	local attached = selUnit ~= nil and selUnit.Homing == true
	local picking = ui.Picking ~= nil and ui.Picking == selected
	local usable = selUnit ~= nil and (attached or picking or left2 > 0)
	local homingX = (math.max(math.min(#skills, MAX_SLOTS), 4)) * (SLOT_W + SLOT_GAP)
	local homing = make("TextButton", {
		Name = "HomingButton",
		Position = UDim2.fromOffset(homingX, if attached or picking then 0 else 8),
		Size = UDim2.fromOffset(SLOT_W, SLOT_H),
		AutoButtonColor = false,
		BackgroundColor3 = if picking then Color3.fromRGB(70, 52, 16) elseif attached then Color3.fromRGB(52, 40, 18) else INK,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Text = "",
	}, slotRow)
	stroke(homing, GOLD, if picking then 0 elseif usable then 0.3 else 0.8, if picking then 2 else 1)
	make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = GOLD, BorderSizePixel = 0 }, homing)
	label(homing, "유도", UDim2.fromOffset(8, 6), UDim2.new(1, -16, 0, 18), { Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = if usable then GOLD else MUTED })
	local targetName = if attached and selUnit.HomingTarget and units[selUnit.HomingTarget] then units[selUnit.HomingTarget].Name else nil
	local homingText = if selUnit == nil then "유닛을 고른다"
		elseif picking then "적을 고른다 (Esc 취소)"
		elseif attached then (if targetName then "→ " .. targetName else "→ 자동") .. " · 누르면 뗀다"
		elseif left2 > 0 then "누르고 적을 고른다"
		else "칩을 다 썼다"
	label(homing, homingText, UDim2.fromOffset(8, 24), UDim2.new(1, -16, 0, 30), { TextSize = 11, TextWrapped = true, TextColor3 = if usable then BODY else MUTED, TextYAlignment = Enum.TextYAlignment.Top })
	for chip = 1, per do
		label(homing, if chip <= left2 then "◆" else "◇", UDim2.new(0, 8 + (chip - 1) * 22, 1, -26), UDim2.fromOffset(22, 22), { Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = if chip <= left2 then GOLD else MUTED, TextXAlignment = Enum.TextXAlignment.Center })
	end
	onClick(self, homing, function()
		if not selected then
			return
		end
		if picking then
			self.callbacks.HomingPick(nil)
		elseif attached then
			self.callbacks.Homing(selected, false)
		elseif left2 > 0 then
			self.callbacks.HomingPick(selected)
		end
	end)

	-- 아래 줄: 안내 · 턴 시작
	label(right, "칸·유닛을 눌러 고르기 · 끌어서 옮기기/맞바꾸기 · 스킬에 마우스를 올리면 설명과 범위 미리보기", UDim2.fromOffset(0, SLOT_H + 24), UDim2.new(1, -214, 0, 44), { TextSize = 11, TextColor3 = MUTED, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local begin = make("TextButton", {
		Name = "BeginTurn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, SLOT_H + 20),
		Size = UDim2.fromOffset(206, 52),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(112, 28, 28),
		BorderSizePixel = 0,
		Text = "턴 시작",
		TextColor3 = BONE,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
	}, right)
	stroke(begin, Color3.fromRGB(240, 128, 108), 0.3)
	onClick(self, begin, function()
		self.callbacks.Begin()
	end)
end

-- 스킬 슬롯의 작은 범위 그림: 적 진영 6×3 에 맞는 칸을 밝힌다(가운데 행에서 쐈을 때)
function PartyHud:_shapeIcon(slot: any, skill: any)
	local skillDef = BattleSkills.ById(skill.Id)
	if not skillDef then
		return
	end
	local ok, cells = pcall(function()
		local grid = BattleGrid.New(BattleGrid.DEFAULT_WIDTH, BattleGrid.DEFAULT_HEIGHT)
		local lit: { [string]: boolean } = {}
		for _, shape in BattleSkills.AllShapes(skillDef) do
			for _, cell in BattleSkills.Cells(grid, "Ally", 2, shape, skill.Grow or 0, 3) do
				if cell.Side == "Enemy" then
					lit[cell.X .. "," .. cell.Y] = true
				end
			end
		end
		return lit
	end)
	if not ok then
		return
	end
	local size = 5
	local holder = make("Frame", { Name = "Shape", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Size = UDim2.fromOffset(size * 6 + 5, size * 3 + 2), BackgroundTransparency = 1 }, slot)
	-- 화면에서 적 진영은 [1][2]…[6] 순서(x=1 이 중앙선 쪽 = 왼쪽)
	for y = 1, 3 do
		for x = 1, 6 do
			make("Frame", { Position = UDim2.fromOffset((x - 1) * (size + 1), (y - 1) * (size + 1)), Size = UDim2.fromOffset(size, size), BackgroundColor3 = if cells[x .. "," .. y] then Color3.fromRGB(235, 90, 80) else MUTED, BackgroundTransparency = if cells[x .. "," .. y] then 0 else 0.7, BorderSizePixel = 0 }, holder)
		end
	end
end

-- 스탠딩 뷰포트: 무대 인형(stage)을 복제해 정면 3/4 에서 비춘다. 같은 유닛이면 복제본을 다시 쓴다
function PartyHud:_fillStand(stand: any, id: string, stage: Model?)
	if not stage then
		self.standFailed = true -- 무대 인형이 아직 없다 — 다음 갱신 때 다시(BattleClient 가 NeedsStand 로 본다)
		return
	end
	if self.standId ~= id or not self.standClone then
		if self.standClone then
			self.standClone:Destroy()
		end
		self.standClone = nil
		local was = stage.Archivable
		stage.Archivable = true -- 플레이어 캐릭터는 Archivable 이 꺼져 있을 수 있다: 잠깐 켜고 복제
		local clone = stage:Clone()
		stage.Archivable = was
		local parts = 0
		for _, d in if clone then clone:GetDescendants() else {} do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("Highlight") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				parts += 1
			end
		end
		if not clone or parts < 3 then
			-- 복제 실패/덜 불러온 캐릭터: 쓰지 않고 다음 갱신 때 다시 시도
			if clone then
				clone:Destroy()
			end
			self.standFailed = true
			return
		end
		self.standClone, self.standId = clone, id
	end
	local clone = self.standClone :: Model
	clone.Parent = stand
	local root = clone:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.CFrame else CFrame.new()
	local facing = at.LookVector
	-- 몸(머리·몸통·팔다리)의 위아래 끝으로 키를 재어 전신이 창 세로의 약 88% 를 채우게 한다(무기·이펙트 상자는 빼고). 정면에서 30° 옆
	local minY, maxY = math.huge, -math.huge
	for _, name in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = clone:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			minY = math.min(minY, part.Position.Y - part.Size.Y / 2)
			maxY = math.max(maxY, part.Position.Y + part.Size.Y / 2)
		end
	end
	if minY >= maxY then
		minY, maxY = at.Position.Y - 3, at.Position.Y + 2.5 -- 몸을 못 찾으면(Lune 흉내) 보통 R6 키
	end
	local height = maxY - minY
	local fov = 40
	local distance = (height / 0.88) / 2 / math.tan(math.rad(fov / 2))
	local side = facing:Cross(Vector3.yAxis)
	local target = Vector3.new(at.Position.X, (minY + maxY) / 2, at.Position.Z)
	local cam = make("Camera", { FieldOfView = fov }, stand)
	cam.CFrame = CFrame.lookAt(target + (facing * math.cos(math.rad(30)) + side * math.sin(math.rad(30))) * distance, target)
	stand.CurrentCamera = cam
	stand.Ambient = Color3.fromRGB(200, 200, 210)
	stand.LightColor = Color3.fromRGB(255, 246, 228)
	stand.LightDirection = (facing * 0.6 - side * 0.5 - Vector3.yAxis).Unit
end

-- 스탠딩을 못 만들었나(무대 인형이 없거나 복제 실패) — BattleClient 가 잠시 뒤 다시 그리게 한다
function PartyHud:NeedsStand(): boolean
	return self.standFailed == true
end

return PartyHud
