--!strict
--[[
	BattleArena — 6×3 격자를 **3D 월드 좌표**로 바꾸는 계산.

	요청: "이제 UI가 아니라 캐릭터가 직접 적이랑 싸우도록 3D에서 구현하면 돼."

	`BattleGrid`는 순수 논리(어느 칸에 누가 있는가)만 다룬다.
	여기서는 그 칸이 월드 어디인지를 정한다. 둘을 나눠 두면
	격자 규칙을 바꾸지 않고 배치 위치만 옮길 수 있다.

	배치
	  아군 진영과 적 진영이 서로 마주 본다.
	  전투 중심(origin)에서 아군은 -Z, 적은 +Z 쪽에 놓인다.

	      적진영   [1,1][2,1]...[6,1]     ← +Z (멀리)
	               [1,2]      ...
	               [1,3]      ...
	      ───────────  중앙선  ───────────
	      아군진영 [1,3]      ...
	               [1,2]      ...
	               [1,1][2,1]...[6,1]     ← -Z (가까이)

	  X는 양 진영 공통으로 좌→우가 1→6이다.
	  Y(세로 3칸)는 진영에서 멀어지는 방향으로 1→3.

	  전투는 지형 위에서 벌어지므로 각 칸의 높이는 레이캐스트로 지면을 찾아 맞춘다.
]]

local BattleGrid = require(script.Parent.BattleGrid)

export type Layout = {
	Origin: CFrame,
	CellSize: number,
	Gap: number,
	-- 양 진영 사이 간격
	Midline: number,
	-- 칸 높이를 찾을 때 광선을 쏘는 높이(원점 기준 아님, 칸 위치 기준). 없으면 200.
	-- 필드 전장은 나무·지붕을 맞히지 않게 낮게 준다.
	RayHeight: number?,
	-- 있으면 모든 칸이 이 한 높이(평평한 돌판)에 선다. 서버가 전투를 열 때 StageHeight 로 정해 준다.
	FlatY: number?,
}

local BattleArena = {}

-- 칸은 캐릭터 한 명이 서는 크기다. R6 아바타가 폭 4·높이 5 정도라 그에 맞춘다.
-- (처음엔 14로 잡았더니 칸이 캐릭터보다 훨씬 커서 격자가 한 화면에 안 들어왔다)
BattleArena.DEFAULT_CELL_SIZE = 5
BattleArena.DEFAULT_GAP = 1
BattleArena.DEFAULT_MIDLINE = 8

function BattleArena.NewLayout(origin: CFrame): Layout
	return {
		Origin = origin,
		CellSize = BattleArena.DEFAULT_CELL_SIZE,
		Gap = BattleArena.DEFAULT_GAP,
		Midline = BattleArena.DEFAULT_MIDLINE,
	}
end

--[[
	칸 하나의 중심을 전투 원점 기준 로컬 좌표로 돌려준다.
	Y는 0이다. 지형 높이는 CellWorldCFrame()에서 맞춘다.
]]
function BattleArena.CellOffset(
	layout: Layout,
	side: BattleGrid.Side,
	x: number,
	y: number,
	width: number,
	height: number
): Vector3
	local pitch = layout.CellSize + layout.Gap

	--[[
		브라운 더스트 1처럼 **양 진영이 좌우로** 마주 본다.

		     아군 진영            중앙선            적 진영
		   [6][5][4][3][2][1]  │  [1][2][3][4][5][6]   ← 세로 라인 1 (위)
		   [6][5][4][3][2][1]  │  [1][2][3][4][5][6]   ← 세로 라인 2 (가운데)
		   [6][5][4][3][2][1]  │  [1][2][3][4][5][6]   ← 세로 라인 3 (아래)
		      ← 화면 왼쪽              화면 오른쪽 →

		  side 축(아군/적) = 로컬 X. 아군은 -X(왼쪽), 적은 +X(오른쪽).
		    각 진영의 6칸(x)도 X를 따라 뻗는다. x=1이 중앙선에 가장 가깝다(전열).
		  세로 라인(y, 1~3) = 로컬 Z. 화면에서는 세로로 늘어선다.

		  공격은 이 세로 라인(y)으로 정해진다. 자세한 건 BattleGrid.LaneTargets 참고.
	]]
	-- Z: 세로 라인 3칸. 가운데 정렬.
	local offsetZ = (y - (height + 1) / 2) * pitch

	-- X: 진영에 따라 좌우로 갈린다. x가 커질수록 자기 진영 뒤열(중앙에서 멀어짐).
	local column = layout.Midline / 2 + (x - 0.5) * pitch
	local offsetX = if side == "Enemy" then column else -column

	local _ = width
	return Vector3.new(offsetX, 0, offsetZ)
end

--[[
	격자 전체가 차지하는 크기.
	  X = 좌우 축 (양 진영 6칸씩 + 중앙선, 화면 가로)
	  Y = 세로 라인 축 (3칸, 화면 세로)
]]
function BattleArena.ArenaExtents(layout: Layout, width: number, height: number): Vector2
	local pitch = layout.CellSize + layout.Gap
	local across = layout.Midline + width * pitch * 2
	local lanes = height * pitch
	return Vector2.new(across, lanes)
end

--[[
	격자 전체가 화면에 들어오는 카메라 CFrame. (브라운 더스트식 측면 고정)

	로컬 X(좌우 축)가 화면 가로, 로컬 Z(세로 라인)가 화면 세로가 되도록
	카메라를 +Z 쪽에서 아래로 pitch만큼 기울여 내려다본다.
	→ 아군(-X)이 화면 왼쪽, 적(+X)이 오른쪽으로 보인다.
]]
function BattleArena.FitCameraCFrame(
	layout: Layout,
	width: number,
	height: number,
	fieldOfView: number,
	aspectRatio: number,
	pitchDegrees: number
): CFrame
	local extents = BattleArena.ArenaExtents(layout, width, height)
	local halfAcross = extents.X / 2 -- 로컬 X
	local halfLane = extents.Y / 2 -- 로컬 Z

	local halfVertical = math.rad(fieldOfView) / 2
	local halfHorizontal = math.atan(math.tan(halfVertical) * math.max(aspectRatio, 0.1))
	local pitch = math.rad(pitchDegrees)

	local center = layout.Origin.Position

	-- 카메라가 앉는 방향: 로컬 +Z(=-LookVector) 쪽에서 위로 pitch만큼.
	local back = -layout.Origin.LookVector
	local direction = (back * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit

	-- 격자 네 모서리 (로컬). X=좌우, Z=세로 라인.
	local corners = {
		Vector3.new(halfAcross, 0, halfLane),
		Vector3.new(halfAcross, 0, -halfLane),
		Vector3.new(-halfAcross, 0, halfLane),
		Vector3.new(-halfAcross, 0, -halfLane),
	}

	-- 주어진 거리에서 화각을 얼마나 쓰는지 (1.0 초과면 화면 밖)
	local function usageAt(distance: number): number
		local eye = center + direction * distance
		local forward = (center - eye).Unit
		local right = Vector3.new(-forward.Z, 0, forward.X)
		if right.Magnitude < 1e-4 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local up = forward:Cross(right)

		local worst = 0
		for _, corner in corners do
			local world = layout.Origin * CFrame.new(corner)
			local rel = world.Position - eye
			local depth = rel:Dot(forward)
			if depth <= 0.01 then
				return math.huge
			end
			local angleH = math.atan(math.abs(rel:Dot(right)) / depth)
			local angleV = math.atan(math.abs(rel:Dot(up)) / depth)
			worst = math.max(worst, angleH / halfHorizontal, angleV / halfVertical)
		end
		return worst
	end

	-- 평면 근사로 시작해(가로=X, 세로=Z가 pitch만큼 눕는다) 네 번 수렴시킨다.
	local distance =
		math.max(halfAcross / math.tan(halfHorizontal), (halfLane * math.sin(pitch)) / math.tan(halfVertical))
	for _ = 1, 4 do
		local usage = usageAt(distance)
		if usage == math.huge then
			distance *= 2
		else
			distance *= usage
		end
	end
	distance *= 1.08

	local eye = center + direction * distance
	return CFrame.lookAt(eye, center)
end

function BattleArena.CellWorldCFrame(
	layout: Layout,
	side: BattleGrid.Side,
	x: number,
	y: number,
	width: number,
	height: number,
	raycastParams: RaycastParams?
): CFrame
	local offset = BattleArena.CellOffset(layout, side, x, y, width, height)
	local world = layout.Origin * CFrame.new(offset)
	local position = world.Position

	if layout.FlatY then
		-- 평평한 전장: 모든 칸이 한 높이
		position = Vector3.new(position.X, layout.FlatY, position.Z)
	elseif raycastParams then
		-- 위에서 아래로 쏴 지면에 맞춘다.
		local up = layout.RayHeight or 200
		local hit = workspace:Raycast(position + Vector3.new(0, up, 0), Vector3.new(0, -(up + 400), 0), raycastParams)
		if hit then
			position = Vector3.new(position.X, hit.Position.Y, position.Z)
		end
	end

	-- 상대 진영을 바라보게 한다. 아군은 오른쪽(+X=RightVector)의 적을, 적은 왼쪽을 본다.
	local facing = if side == "Enemy" then -layout.Origin.RightVector else layout.Origin.RightVector
	return CFrame.lookAt(position, position + facing)
end

--[[
	평평한 전장 높이(2026-09-29 요청: 칸마다 땅을 따라 높이가 달라지던 것을 한 판으로).
	양 진영 칸(칸마다 가운데 + 네 귀)과 중앙선 위 땅을 재서, 가장 높은 땅을 판 높이로 쓴다.
	울타리·등불처럼 혼자 튀어나온 것(중앙값 + 6 넘음)은 판 높이에서 뺀다 — 판 밑 받침이 가린다.
	돌려주는 값: 판 높이, 가장 낮은 땅(받침 바닥). 땅을 하나도 못 찾으면 원점 높이.
]]
function BattleArena.StageHeight(
	layout: Layout,
	width: number,
	height: number,
	raycastParams: RaycastParams?
): (number, number)
	local up = layout.RayHeight or 200
	local ys: { number } = {}
	local half = layout.CellSize / 2 - 0.6
	local function probe(localPos: Vector3)
		local world = (layout.Origin * CFrame.new(localPos)).Position
		local hit = workspace:Raycast(world + Vector3.new(0, up, 0), Vector3.new(0, -(up + 400), 0), raycastParams)
		if hit then
			table.insert(ys, hit.Position.Y)
		end
	end
	for _, side in { "Ally", "Enemy" } :: { BattleGrid.Side } do
		for y = 1, height do
			for x = 1, width do
				local c = BattleArena.CellOffset(layout, side, x, y, width, height)
				probe(c)
				for _, d in { Vector3.new(half, 0, half), Vector3.new(-half, 0, half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, -half) } do
					probe(c + d)
				end
			end
		end
	end
	for y = 1, height do
		probe(Vector3.new(0, 0, (y - (height + 1) / 2) * (layout.CellSize + layout.Gap)))
	end
	if #ys == 0 then
		local y0 = layout.Origin.Position.Y
		return y0, y0
	end
	table.sort(ys)
	local median = ys[math.ceil(#ys / 2)]
	local top = ys[1]
	for _, v in ys do
		if v <= median + 6 then
			top = math.max(top, v)
		end
	end
	return top, ys[1]
end

-- 격자 바닥 타일 하나의 크기.
function BattleArena.TileSize(layout: Layout): Vector3
	return Vector3.new(layout.CellSize, 0.4, layout.CellSize)
end

--[[
	월드 위치가 어느 칸인지 되짚는다. 캐릭터가 걸어 들어간 칸을 알아내는 데 쓴다.
	격자 밖이면 nil.
]]
function BattleArena.CellFromWorld(
	layout: Layout,
	position: Vector3,
	width: number,
	height: number
): (BattleGrid.Side?, number?, number?)
	local local_ = layout.Origin:PointToObjectSpace(position)
	local pitch = layout.CellSize + layout.Gap

	local x = math.round(local_.X / pitch + (width + 1) / 2)
	if x < 1 or x > width then
		return nil, nil, nil
	end

	local side: BattleGrid.Side = if local_.Z >= 0 then "Enemy" else "Ally"
	local depth = math.abs(local_.Z) - layout.Midline / 2
	if depth < 0 then
		return nil, nil, nil
	end

	local y = math.floor(depth / pitch) + 1
	if y < 1 or y > height then
		return nil, nil, nil
	end

	return side, x, y
end

return BattleArena
