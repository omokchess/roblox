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
	  Buff/Debuff/Heal  서브코어-패치가 깐 칸 · Pending  검수 준비중(예고) · Gone  검수됨!(검은 칸)
]]
BattleStage.BOARD = {
	Buff = Color3.fromRGB(70, 225, 255), -- 하늘색(주황 위협 칸과 헷갈리지 않게)
	Debuff = Color3.fromRGB(190, 80, 230),
	Heal = Color3.fromRGB(90, 235, 120),
	Pending = Color3.fromRGB(255, 60, 200),
	Gone = Color3.fromRGB(235, 235, 235),
}
BattleStage.BOARD_TAG = { Buff = "▲ 버프", Debuff = "▼ 버그", Heal = "✚ 회복", Pending = "검수 준비중", Gone = "검수됨!" }

--[[
	검수 칸 묶음 표시(2026-10-02 요청: "검수 예정 칸을 한번에 몰아서 위에 특정 이펙트를 넣는 식으로, 검수됨 칸도").
	칸마다 글자를 달던 것을 없애고, 붙은 칸(상하좌우)끼리 한 덩어리로 묶어 **덩어리마다 글자 하나**를 띄우고
	칸 위에는 효과를 깐다. 칸 위 효과는 바닥에 붙여(캐릭터 다리를 가르지 않게) 이웃 칸과 이어져 한 판처럼 보인다.
	  Pending  자홍 홀로그램 판(바닥 바로 위) + 칸을 가로지르는 스캔 막대(모든 칸이 같은 박자) + 솟는 화소
	  Gone     검정 판 위로 검정·청록 화소가 깜박이며 흩어진다(지워진 데이터)
	효과는 광선에 안 맞는다(드래그 판정 그대로). 같은 칸 묶음이면 다시 짓지 않는다.
]]
local TweenService = game:GetService("TweenService")
local GROUP_LABEL = { Pending = "검수 준비중", Gone = "검수됨!" }

local function components(keys: { [string]: boolean }): { { { number } } }
	local seen: { [string]: boolean } = {}
	local out = {}
	local sorted = {}
	for key in keys do
		table.insert(sorted, key)
	end
	table.sort(sorted)
	for _, key in sorted do
		if seen[key] then
			continue
		end
		local group, stack = {}, { key }
		seen[key] = true
		while #stack > 0 do
			local k = table.remove(stack) :: string
			local x, y = string.match(k, "(%d+),(%d+)")
			local cx, cy = tonumber(x) :: number, tonumber(y) :: number
			table.insert(group, { cx, cy })
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local nk = (cx + d[1]) .. "," .. (cy + d[2])
				if keys[nk] and not seen[nk] then
					seen[nk] = true
					table.insert(stack, nk)
				end
			end
		end
		table.insert(out, group)
	end
	return out
end

local function fxPart(name: string, cf: CFrame, size: Vector3, color: Color3, transparency: number, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function pixels(parent: BasePart, colors: { Color3 }, rate: number, speed: number, life: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.08) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	e.Color = ColorSequence.new(keys)
	e.LightEmission = 0.8
	e.Rotation = NumberRange.new(0, 0)
	e.Parent = parent
end

-- 묶인 칸은 칸마다 따로 그리던 윤곽선을 끈다(내 자리·놓을 곳처럼 다른 색으로 칠한 칸은 그대로 둔다).
-- 칸 칠하기가 갱신마다 윤곽을 다시 켜니 묶음이 그대로여도 매번 돈다.
local function hideTileMarks(tiles: { [string]: { { BasePart } } }, kind: string, keys: { [string]: boolean })
	for key in keys do
		local x, y = string.match(key, "(%d+),(%d+)")
		local row = tiles.Ally[tonumber(y) :: number]
		local t = row and row[tonumber(x) :: number]
		local box = t and t:FindFirstChild("Mark") :: SelectionBox?
		if box and (if kind == "Pending" then box.Color3 == BattleStage.BOARD.Pending else box.SurfaceColor3 == VOID) then
			box.Transparency = 1
			box.SurfaceTransparency = 1
		end
	end
end

function BattleStage.GroupMarks(tiles: { [string]: { { BasePart } } }, kind: "Pending" | "Gone", keys: { [string]: boolean })
	local first = tiles.Ally[1] and tiles.Ally[1][1]
	if not first or not first.Parent then
		return
	end
	hideTileMarks(tiles, kind, keys)
	local holderName = "Marks_" .. kind
	local holder = first.Parent:FindFirstChild(holderName)
	local list = {}
	for key in keys do
		table.insert(list, key)
	end
	table.sort(list)
	local sig = table.concat(list, ";")
	if holder and holder:GetAttribute("Sig") == sig then
		return
	end
	if holder then
		holder:Destroy()
	end
	if sig == "" then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = holderName
	folder:SetAttribute("Sig", sig)
	folder.Parent = first.Parent
	local color = BattleStage.BOARD[kind]
	local edgeColor = if kind == "Pending" then Color3.fromRGB(255, 170, 235) else Color3.fromRGB(70, 220, 255)
	-- 칸 한 칸 건너가는 거리(판이 어느 쪽으로 놓였든 이웃 칸 자리로 잰다)
	local stepX = tiles.Ally[1][2].Position - first.Position
	local stepY = tiles.Ally[2][1].Position - first.Position
	-- 묶음 전체가 같은 박자로 숨 쉬듯 밝아졌다 어두워진다(한 판으로 보이게)
	local pulse = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for _, group in components(keys) do
		local inGroup: { [string]: boolean } = {}
		for _, c in group do
			inGroup[c[1] .. "," .. c[2]] = true
		end
		local sum = Vector3.zero
		for _, c in group do
			local t = tiles.Ally[c[2]] and tiles.Ally[c[2]][c[1]]
			if not t then
				continue
			end
			sum += t.Position
			-- 판은 칸 사이 틈까지 덮어 이웃 판과 이어 붙는다
			local size = Vector3.new(t.Size.X + 0.2, 0.04, t.Size.Z + 0.2)
			if kind == "Pending" then
				local plate = fxPart("Holo", t.CFrame + Vector3.new(0, 0.18, 0), size, color, 0.72, folder)
				TweenService:Create(plate, pulse, { Transparency = 0.5 }):Play()
				pixels(plate, { color, Color3.fromRGB(255, 200, 245) }, 3, 2.2, 1.4)
			else
				-- 지워진 데이터: 검정 판(칸 틈까지 가림) 위로 검정·청록 화소가 깜박이며 흩어진다
				local plate = fxPart("Void", t.CFrame + Vector3.new(0, 0.16, 0), size, Color3.new(0, 0, 0), 0.05, folder)
				plate.Material = Enum.Material.SmoothPlastic
				pixels(plate, { Color3.fromRGB(10, 10, 14), Color3.fromRGB(70, 220, 255), Color3.fromRGB(10, 10, 14) }, 5, 1.2, 0.9)
			end
			-- 묶음 바깥 둘레에만 테두리(안쪽 칸 경계는 그리지 않는다)
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				if inGroup[(c[1] + d[1]) .. "," .. (c[2] + d[2])] then
					continue
				end
				local across = stepX * d[1] + stepY * d[2]
				local along = if d[1] ~= 0 then stepY else stepX
				local mid = t.Position + across * 0.5 + Vector3.new(0, 0.21, 0)
				local edge = fxPart("Edge", CFrame.lookAt(mid, mid + along.Unit), Vector3.new(0.16, 0.06, along.Magnitude + 0.16), edgeColor, 0.1, folder)
				if kind == "Pending" then
					TweenService:Create(edge, pulse, { Transparency = 0.45 }):Play()
				end
			end
		end
		-- 덩어리마다 글자 하나(가운데 위)
		local center = sum / math.max(#group, 1)
		local anchor = fxPart("Label", CFrame.new(center + Vector3.new(0, 0.4, 0)), Vector3.new(0.1, 0.1, 0.1), color, 1, folder)
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromOffset(150, 30)
		b.StudsOffset = Vector3.new(0, 1.6, 0)
		b.AlwaysOnTop = true
		b.MaxDistance = 220
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 18
		label.TextStrokeTransparency = 0.2
		label.TextColor3 = if kind == "Gone" then Color3.fromRGB(235, 235, 235) else color
		label.Text = if #group > 1 then string.format("%s ×%d", GROUP_LABEL[kind], #group) else GROUP_LABEL[kind]
		label.Parent = b
		b.Parent = anchor
	end
end

--[[
	공격 범위 표시(2026-10-03 사용자: "다른 칸에 묻혀서 공격 범위 표시가 잘 보이지 않는다").
	칸 칠하기는 한 칸에 색 하나라 버프·버그·회복·검수 칸 위에서는 범위 주황이 지거나 섞였다. 그래서 범위는 **따로 한 층**:
	  칸 위에 떠 있는 굵은 사선 줄무늬(다른 표시는 전부 평평한 판이라 무늬만으로 구별된다) + 묶음 바깥 둘레 굵은 테두리,
	  둘 다 빠르게 깜박인다(다른 표시는 느리게 숨 쉰다). 묶음마다 글자 하나.
	2026-10-03 사용자: 보스는 부위마다 색을 달리해 나누고, 부위에서 그 범위로 레이저를 쏜다.
	  keys[칸] = { { Group, Color, Label, Unavoid?, Source? } … } — 한 칸을 여러 묶음이 덮으면 줄무늬가 묶음 색을 돌아가며 칠한다.
	  Group 이 같은 칸끼리 붙은 덩어리마다 테두리(묶음마다 조금씩 안쪽·위로 비켜 겹쳐도 보인다)·글자·레이저.
	  source(Source) = 레이저가 나오는 부위 몸(BasePart). 부위가 움직여도(공전) Beam 이 따라간다.
	높이는 검수 판(0.18~0.21)보다 위(0.3~0.5)라 무엇에도 덮이지 않는다.
]]
-- 레이저 원점 Attachment 는 부위 몸에 붙는다 — 표시를 다시 짓거나 지울 때 같이 치운다
local laserRoots: { Instance } = {}
local function clearLasers()
	for _, a in laserRoots do
		a:Destroy()
	end
	table.clear(laserRoots)
end

function BattleStage.ThreatMarks(tiles: { [string]: { { BasePart } } }, keys: { [string]: { any } }, source: ((id: string) -> BasePart?)?)
	local first = tiles.Ally[1] and tiles.Ally[1][1]
	if not first or not first.Parent then
		return
	end
	-- 같은 내용이면 다시 짓지 않는다(레이저 원점 부위가 바뀌어도 Group 이름이 같으면 같다)
	local list = {}
	for key, entries in keys do
		for _, e in entries do
			table.insert(list, key .. "=" .. e.Group .. "/" .. e.Label)
		end
	end
	table.sort(list)
	local sig = table.concat(list, ";")
	local holder = first.Parent:FindFirstChild("Marks_Threat")
	if holder and holder:GetAttribute("Sig") == sig then
		return
	end
	if holder then
		holder:Destroy()
	end
	clearLasers()
	if sig == "" then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Marks_Threat"
	folder:SetAttribute("Sig", sig)
	folder.Parent = first.Parent
	local stepX = tiles.Ally[1][2].Position - first.Position
	local stepY = tiles.Ally[2][1].Position - first.Position
	local ux, uy = stepX.Unit, stepY.Unit
	-- 2026-10-03 사용자: 밝았다 어두워지는 깜빡임은 없애고, 색을 더 또렷하게 + 약간의 네온.
	-- 묶음 색을 채도·밝기 끝까지 올리고(vivid), 줄무늬·테두리는 Neon 재질(fxPart)로 은은히 빛나게 둔다
	local function vivid(c: Color3): Color3
		local h, sat = c:ToHSV()
		return Color3.fromHSV(h, math.min(1, sat * 1.15 + 0.1), 1)
	end

	-- 묶음별 칸, 칸별 묶음들(줄무늬 색 돌리기)
	local groups: { [string]: { Cells: { [string]: boolean }, Entry: any } } = {}
	local order = {}
	for key, entries in keys do
		for _, e in entries do
			local g = groups[e.Group]
			if not g then
				g = { Cells = {}, Entry = e }
				groups[e.Group] = g
				table.insert(order, e.Group)
			end
			g.Cells[key] = true
		end
	end
	table.sort(order)
	local slot = {}
	for i, name in order do
		slot[name] = i - 1
	end

	-- 줄무늬: 칸마다 셋, 덮은 묶음 색을 돌아가며
	for key, entries in keys do
		local x, y = string.match(key, "(%d+),(%d+)")
		local t = tiles.Ally[tonumber(y) :: number] and tiles.Ally[tonumber(y) :: number][tonumber(x) :: number]
		if not t then
			continue
		end
		table.sort(entries, function(a, b)
			return a.Group < b.Group
		end)
		local h = t.Size.X * 0.42
		for si, k in { -h * 0.66, 0, h * 0.66 } do
			local e = entries[(si - 1) % #entries + 1]
			local u0, u1 = math.max(-h, -h + k), math.min(h, h + k)
			local mu = (u0 + u1) / 2
			local mid = t.Position + ux * mu + uy * (mu - k) + Vector3.new(0, 0.3, 0)
			local len = (u1 - u0) * math.sqrt(2)
			fxPart("Stripe", CFrame.lookAt(mid, mid + (ux + uy).Unit), Vector3.new(0.34, 0.05, len), vivid(e.Color), 0.3, folder)
		end
	end

	-- 묶음 덩어리마다 테두리·글자·레이저
	for _, name in order do
		local g = groups[name]
		local e = g.Entry
		local i = slot[name]
		local inset = 0.46 - math.min(i, 4) * 0.045
		local lift = 0.34 + math.min(i, 4) * 0.03
		local edgeColor = if e.Unavoid then Color3.new(1, 1, 1) else vivid(e.Color)
		-- 2026-10-03 사용자: 글자·레이저는 떨어진 덩어리마다가 아니라 묶음(Group)에 하나만.
		-- 가장 큰 덩어리(같으면 묶음 전체 가운데에 가까운 것)에 단다. 테두리·줄무늬는 칸마다 그대로
		local comps = components(g.Cells)
		local all = Vector3.zero
		local n = 0
		for _, comp in comps do
			for _, c in comp do
				local t = tiles.Ally[c[2]] and tiles.Ally[c[2]][c[1]]
				if t then
					all += t.Position
					n += 1
				end
			end
		end
		all /= math.max(n, 1)
		local labelComp, bestScore = nil, -math.huge
		for _, comp in comps do
			local sum = Vector3.zero
			for _, c in comp do
				local t = tiles.Ally[c[2]] and tiles.Ally[c[2]][c[1]]
				if t then
					sum += t.Position
				end
			end
			local score = #comp * 1000 - (sum / math.max(#comp, 1) - all).Magnitude
			if score > bestScore then
				labelComp, bestScore = comp, score
			end
		end
		for _, comp in comps do
			local inComp: { [string]: boolean } = {}
			for _, c in comp do
				inComp[c[1] .. "," .. c[2]] = true
			end
			local sum = Vector3.zero
			for _, c in comp do
				local t = tiles.Ally[c[2]] and tiles.Ally[c[2]][c[1]]
				if not t then
					continue
				end
				sum += t.Position
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					if inComp[(c[1] + d[1]) .. "," .. (c[2] + d[2])] then
						continue
					end
					local across = stepX * d[1] + stepY * d[2]
					local along = if d[1] ~= 0 then stepY else stepX
					local mid = t.Position + across * inset + Vector3.new(0, lift, 0)
					fxPart("Edge", CFrame.lookAt(mid, mid + along.Unit), Vector3.new(if e.Unavoid then 0.42 else 0.3, 0.08, along.Magnitude * (inset * 2) + 0.3), edgeColor, 0.05, folder)
				end
			end
			if comp ~= labelComp then
				continue
			end
			local center = sum / math.max(#comp, 1)
			local anchor = fxPart("Label", CFrame.new(center + Vector3.new(0, 0.5, 0)), Vector3.new(0.1, 0.1, 0.1), e.Color, 1, folder)
			local b = Instance.new("BillboardGui")
			b.Size = UDim2.fromOffset(190, 28)
			b.StudsOffset = Vector3.new(0, 2.4 + math.min(i, 5) * 1.1, 0)
			b.AlwaysOnTop = true
			b.MaxDistance = 220
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextSize = 16
			label.TextStrokeTransparency = 0.1
			label.TextColor3 = e.Color
			label.Text = "! " .. e.Label
			label.Parent = b
			b.Parent = anchor
			-- 레이저: 부위 몸 → 덩어리 가운데(Beam 이라 부위가 움직여도 따라간다). 굵은 색 줄 + 가는 흰 심
			local from = e.Source and source and source(e.Source)
			if from then
				local a0 = Instance.new("Attachment")
				a0.Name = "Laser_" .. name
				a0.Parent = from
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, 0.2, 0)
				a1.Parent = anchor
				for _, spec in { { 0.55, e.Color, 0.15 }, { 0.16, Color3.new(1, 1, 1), 0 } } do
					local beam = Instance.new("Beam")
					beam.Attachment0, beam.Attachment1 = a0, a1
					beam.Width0, beam.Width1 = spec[1] * 0.6, spec[1]
					beam.Color = ColorSequence.new(spec[2])
					beam.LightEmission = 1
					beam.LightInfluence = 0
					beam.FaceCamera = true
					beam.Segments = 1
					beam.Transparency = NumberSequence.new(spec[3])
					beam.Parent = anchor
				end
				table.insert(laserRoots, a0)
			end
		end
	end
end

--[[
	한쪽 진영 칸을 통째로 보이거나 숨긴다(2026-10-03 사용자: 보스 디버그 쪽 칸은 아예 없애기 — 보이는 것만, 규칙은 그대로).
	칸 파트는 남겨 둔다(드래그·자리 계산이 쓴다). 윤곽선·글자만 끈다.
]]
function BattleStage.SetSideVisible(tiles: { [string]: { { BasePart } } }, side: string, visible: boolean)
	for _, row in tiles[side] or {} do
		for _, part in row do
			local box = part:FindFirstChild("Mark") :: SelectionBox?
			if box then
				box.Visible = visible
			end
			local tag = part:FindFirstChild("Tag") :: BillboardGui?
			if tag then
				tag.Enabled = visible
			end
		end
	end
end

-- 구경용(2026-09-29 요청: 남이 싸울 때 그 칸에 무슨 기능이 있는지 보이게): 보스 판만 칠하고 글자를 단다.
-- 검수 칸(Pending·Gone)은 칸 글자 대신 묶음 표시(GroupMarks)
function BattleStage.PaintBoard(tiles: { [string]: { { BasePart } } }, board: any)
	local kind: { [string]: string } = {}
	for _, m in board.Mods or {} do
		kind[m.X .. "," .. m.Y] = m.Kind
	end
	local pending, gone = {}, {}
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
				gone[x .. "," .. y] = true
			elseif k then
				BattleStage.Paint(part, BattleStage.BOARD[k], true)
				if k == "Pending" then
					pending[x .. "," .. y] = true
				end
			else
				BattleStage.Paint(part, BattleStage.TILE_IDLE, false)
			end
			local tagged = k and k ~= "Pending" and k ~= "Gone"
			BattleStage.Tag(part, if tagged then BattleStage.BOARD_TAG[k :: string] else nil, if tagged then BattleStage.BOARD[k :: string] else nil)
		end
	end
	BattleStage.GroupMarks(tiles, "Pending", pending)
	BattleStage.GroupMarks(tiles, "Gone", gone)
	-- 보스 판이면 보스 쪽 칸은 숨긴다(SetSideVisible)
	BattleStage.SetSideVisible(tiles, "Enemy", false)
end

return BattleStage
