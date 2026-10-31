--!strict
--[[
	StatTooltip — 스탯 툴팁 내용(2026-10-31 사용자: "스탯 위에 마우스를 올리면 그 스탯 효과와 영향 받는 직업도 보이게").
	디버그 패널(성장 탭 곁 창)과 레벨업 화면(스탯 줄 옆)이 같은 내용을 그린다. 내용은 Shared.StatInfo.

	  힘  12점
	  효과  1점당 → 지금
	    근접 스킬 피해   +5%  → +60%
	    드랍률 …        (아직 전투에 없음 — 흐리게)
	  영향 받는 직업
	    결투사 — 근접 피해 스킬 3개   ◀ 지금 직업(금빛)
	    … · 모든 직업 몫 한 줄 · 빠지는 직업(조율자 — 신앙심 말고는 피해를 못 올림)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)
local StatInfo = require(ReplicatedStorage.Shared.StatInfo)

local StatTooltip = {}

local GOLD = "rgb(255,205,90)"
local DIM = "rgb(140,144,160)"
local GOOD = "rgb(140,225,160)"
local SKY = "rgb(150,200,255)"

local function line(parent: Instance, text: string, order: number, size: number?, bold: boolean?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Text = text
	label.RichText = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(226, 228, 236)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = size or 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LineHeight = 1.1
	label.LayoutOrder = order
	label.ZIndex = 30
	label.Parent = parent
end

local function color(c: string, text: string): string
	return string.format('<font color="%s">%s</font>', c, text)
end

--[[
	parent 에 세로 목록으로 채운다(parent 에 UIListLayout 이 없으면 붙인다). points = 지금 스탯(합계 칸), classId = 지금 직업(금빛으로)
]]
function StatTooltip.Fill(parent: Instance, statId: string, points: number, classId: string?)
	if not parent:FindFirstChildOfClass("UIListLayout") then
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = parent
	end
	local def = StatDefinitions.Get(statId :: any)
	line(parent, string.format("%s  %s", color(GOLD, def and def.Name or statId), color(DIM, string.format("%d점", points))), 1, 18, true)
	line(parent, string.format("%s  %s", color(GOLD, "효과"), color(DIM, "1점당 → 지금")), 2, 13, true)
	local order = 2
	for _, e in StatInfo.Effects(statId, points) do
		order += 1
		if e.Live then
			line(parent, string.format("  %s  %s  %s", e.Label, color(SKY, e.Value), color(GOOD, "→ " .. e.Total)), order)
		else
			line(parent, color(DIM, string.format("  %s  %s  (아직 전투에 없음)", e.Label, e.Value)), order, 12)
		end
	end
	order += 1
	line(parent, color(GOLD, "영향 받는 직업"), order, 13, true)
	local everyone = StatInfo.Everyone(statId)
	if everyone then
		order += 1
		line(parent, "  " .. color(SKY, everyone), order)
	end
	local classes = StatInfo.Classes(statId)
	for _, c in classes do
		order += 1
		local mine = c.ClassId == classId
		line(parent, string.format("  %s %s%s", if mine then color(GOLD, c.Name) else c.Name, color(DIM, "— " .. c.Why), if mine then color(GOLD, "  ◀ 지금 직업") else ""), order)
	end
	if #classes == 0 and not everyone then
		order += 1
		line(parent, color(DIM, "  지금은 이 스탯을 쓰는 직업이 없음"), order)
	end
	for _, name in StatInfo.Excluded(statId) do
		order += 1
		line(parent, color(DIM, string.format("  %s — 신앙심 말고는 피해를 못 올려 피해 몫은 안 받음", name)), order, 12)
	end
end

return StatTooltip
