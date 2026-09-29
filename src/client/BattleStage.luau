--!strict
--[[
	BattleStage — 전투 칸을 그린다(2026-09-29). 싸우는 사람(BattleClient)과 구경하는 사람(BattleSpectator)이 같이 쓴다.

	예전에는 칸마다 땅 높이를 따라 제각각 올라가 울퉁불퉁했다. 이제 칸은 서버가 정한 한 높이(Arena.FlatY)의
	평면에 놓인다. 필드에서 돌판을 깔고 싸우지는 않으므로(요청), 칸은 **시스템만 보여 주는 대열 표시**다 —
	보이지 않는 얇은 판에 윤곽선(SelectionBox)과 옅은 면색만 입힌다. 부딪히지 않고, 드래그 광선만 맞는다.
	칸 색(미리보기·위협·놓을 곳)은 Paint 로 바꾼다.
]]

local BattleArena = require(game:GetService("ReplicatedStorage").Shared.BattleArena)

local BattleStage = {}

BattleStage.TILE_IDLE = Color3.fromRGB(196, 214, 236)

local function tile(name: string, cf: CFrame, size: Vector3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	local box = Instance.new("SelectionBox")
	box.Name = "Mark"
	box.Adornee = p
	box.LineThickness = 0.05
	box.Parent = p
	return p
end

--[[
	칸 하나의 색. active 면 면을 진하게(범위·위협·내 자리), 아니면 옅은 윤곽만.
]]
function BattleStage.Paint(part: BasePart, color: Color3, active: boolean?)
	local box = part:FindFirstChild("Mark") :: SelectionBox?
	if not box then
		return
	end
	box.Color3 = color
	box.SurfaceColor3 = color
	box.Transparency = if active then 0.05 else 0.45
	box.SurfaceTransparency = if active then 0.45 else 0.9
end

--[[
	지워진 칸(보스 디버그의 칸 삭제). 검은 구멍(2026-09-29 요청: 사라진 칸은 검정색).
]]
local VOID = Color3.new(0, 0, 0)
function BattleStage.PaintGone(part: BasePart)
	local box = part:FindFirstChild("Mark") :: SelectionBox?
	if not box then
		return
	end
	box.Color3 = Color3.fromRGB(20, 20, 20)
	box.SurfaceColor3 = VOID
	box.Transparency = 0.1
	box.SurfaceTransparency = 0.02
end

--[[
	칸 위 작은 글자(버프·버그 칸). text 가 nil 이면 지운다.
]]
function BattleStage.Tag(part: BasePart, text: string?, color: Color3?)
	local gui = part:FindFirstChild("Tag") :: BillboardGui?
	if not text then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		local b = Instance.new("BillboardGui")
		b.Name = "Tag"
		b.Size = UDim2.fromOffset(96, 22)
		b.StudsOffset = Vector3.new(0, 0.6, 0)
		b.AlwaysOnTop = true
		b.MaxDistance = 200
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 13
		label.TextStrokeTransparency = 0.3
		label.Parent = b
		b.Parent = part
		gui = b
	end
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
end

--[[
	여러 칸을 차지한 유닛(보스 부위)의 자리: 칸들 가운데 바닥, 아군 쪽을 본다.
]]
function BattleStage.BlockHome(layout: BattleArena.Layout, cells: { { number } }, width: number, height: number, rayParams: RaycastParams?): CFrame
	local sum = Vector3.zero
	local first: CFrame? = nil
	for _, c in cells do
		local cf = BattleArena.CellWorldCFrame(layout, "Enemy", c[1], c[2], width, height, rayParams)
		first = first or cf
		sum += cf.Position
	end
	local center = sum / math.max(#cells, 1)
	return CFrame.new(center + Vector3.new(0, 0.4, 0)) * (first :: CFrame).Rotation
end

--[[
	칸을 놓는다. `layout.FlatY` 가 있으면 한 높이 평면, 없으면(옛 서버) 칸마다 땅을 따른다.
	돌려주는 값: tiles[side][y][x] = 칸 파트. baseY 는 예전 돌판 받침용이라 쓰지 않는다.
]]
function BattleStage.Build(folder: Instance, layout: BattleArena.Layout, _baseY: number?, width: number, height: number, rayParams: RaycastParams?): { [string]: { { BasePart } } }
	local tiles: { [string]: { { BasePart } } } = { Ally = {}, Enemy = {} }
	local size = BattleArena.TileSize(layout)
	for _, side in { "Ally", "Enemy" } do
		for y = 1, height do
			tiles[side][y] = {}
			for x = 1, width do
				local cf = BattleArena.CellWorldCFrame(layout, side :: any, x, y, width, height, rayParams)
				local p = tile(string.format("Tile_%s_%d_%d", side, x, y), cf + Vector3.new(0, 0.12, 0), Vector3.new(size.X - 0.2, 0.05, size.Z - 0.2), folder)
				BattleStage.Paint(p, BattleStage.TILE_IDLE, false)
				tiles[side][y][x] = p
			end
		end
	end
	return tiles
end

--[[
	보스 판 칸 색과 글자. 싸우는 사람(BattleClient)과 구경하는 사람(BattleSpectator)이 같게 쓴다.
	  Buff/Debuff/Heal  패치 팔이 깐 칸 · Pending  검수 준비중(예고) · Gone  검수됨!(검은 칸)
]]
BattleStage.BOARD = {
	Buff = Color3.fromRGB(70, 225, 255), -- 하늘색(주황 위협 칸과 헷갈리지 않게)
	Debuff = Color3.fromRGB(190, 80, 230),
	Heal = Color3.fromRGB(90, 235, 120),
	Pending = Color3.fromRGB(255, 60, 200),
	Gone = Color3.fromRGB(235, 235, 235),
}
BattleStage.BOARD_TAG = { Buff = "▲ 버프", Debuff = "▼ 버그", Heal = "✚ 회복", Pending = "검수 준비중", Gone = "검수됨!" }

-- 구경용(2026-09-29 요청: 남이 싸울 때 그 칸에 무슨 기능이 있는지 보이게): 보스 판만 칠하고 글자를 단다
function BattleStage.PaintBoard(tiles: { [string]: { { BasePart } } }, board: any)
	local kind: { [string]: string } = {}
	for _, m in board.Mods or {} do
		kind[m.X .. "," .. m.Y] = m.Kind
	end
	for _, c in board.Pending or {} do
		kind[c[1] .. "," .. c[2]] = "Pending"
	end
	for _, d in board.Deleted or {} do
		kind[d.X .. "," .. d.Y] = "Gone"
	end
	for y, row in tiles.Ally do
		for x, part in row do
			local k = kind[x .. "," .. y]
			if k == "Gone" then
				BattleStage.PaintGone(part)
			elseif k then
				BattleStage.Paint(part, BattleStage.BOARD[k], true)
			else
				BattleStage.Paint(part, BattleStage.TILE_IDLE, false)
			end
			BattleStage.Tag(part, if k then BattleStage.BOARD_TAG[k] else nil, if k then BattleStage.BOARD[k] else nil)
		end
	end
end

return BattleStage
