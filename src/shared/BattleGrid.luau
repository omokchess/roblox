--!strict
--[[
	BattleGrid — Brown Dust식 6×3 배치 격자.

	사양 출처: 추가&수정.md `###### 배치`

	  "Brown Dust의 방식을 채택, 기본적으로 6*3의 격자를 양 진영에 둔다.
	   적과 아군 진영에 6*3의 격자를 놓는다. 가로 6, 세로 3이다.
	   일부 특수한 보스전의 경우 칸을 제한하는 기믹을 추가할 것이기 때문에
	   이에 맞춰 유연하게 작업 한다."

	그래서 크기를 상수로 박지 않고 New()에서 받으며, 칸을 하나씩 막을 수 있게 했다.
	보스전 기믹은 SetEnabled()로 칸을 꺼서 표현한다.

	좌표계
	  X 1..6 (가로), Y 1..3 (세로). 진영(Side)마다 격자가 따로 있다.
	  같은 (x, y)라도 Ally/Enemy는 다른 칸이다.

	이 모듈은 순수 상태 관리다. 렌더링·입력은 다루지 않는다.
	스킬 범위 미리보기는 CellsInShape()가 돌려주는 칸 목록을 붉게 칠하면 된다.
]]

export type Side = "Ally" | "Enemy"

export type Cell = {
	Side: Side,
	X: number,
	Y: number,
}

export type Grid = {
	Width: number,
	Height: number,
	-- 보스 기믹으로 막힌 칸. 키는 CellKey().
	Disabled: { [string]: boolean },
	-- 칸 → 유닛 Id
	Occupants: { [string]: string },
	-- 유닛 Id → 칸 (역참조. 이동할 때 원래 칸을 찾는 데 쓴다)
	UnitCells: { [string]: Cell },
	-- 칸 여러 개를 차지한 유닛(보스 부위, PlaceBlock). 밀리거나 끌려가지 않는다
	Blocks: { [string]: boolean }?,
}

--[[
	스킬 범위 모양.
	미리보기와 실제 타격 대상이 **같은 함수**를 쓰도록 여기서 한 번만 정의한다.
	(미리보기와 실제가 어긋나는 것이 이런 시스템에서 가장 흔한 버그다)
]]
export type ShapeKind = "Single" | "Row" | "Column" | "Cross" | "Square" | "All" | "Line"

export type Shape = {
	Kind: ShapeKind,
	-- Square에서 쓰는 반경. Cross에서는 팔 길이. Line에서는 앞으로 뻗는 칸 수.
	Radius: number?,
	--[[
		**직접 찍은 칸 목록.** 기준점 (n,n)에서의 상대 좌표다.

		있으면 `Kind`와 `Radius`를 덮어쓴다. 이름 붙은 모양(십자·사각·직선)으로
		표현되지 않는 범위를 위해 둔다 — "앞 두 칸과 위 한 칸" 같은 것은 어떤
		Kind로도 안 된다.

		`config_editor.html`의 범위 편집기가 6×3 격자에서 칸을 찍어 만든다.
	]]
	Cells: { { X: number, Y: number } }?,
	--[[
		**조건부로 늘어나는 단계.** 캐스터가 들고 있는 자원(예: 음악가의
		16분음표) 개수가 `growCount`만큼 찼을 때, `Stages[1]`부터 `Stages
		[growCount]`까지 차례로 켜진다 — 각 단계는 `Cells`와 같은 형식(기준점
		(n,n)에서의 상대 좌표)의 **그 단계에서 새로 추가되는 칸**이다(이전
		단계 칸을 다시 안 적어도 된다. 누적으로 켜진다).

		이름 붙은 방향 공식 대신 칸을 직접 찍게 한 이유: 자라는 모양이 항상
		일직선이라는 보장이 없다(요청: "그 색깔에 따라서 단계별 범위지정" —
		`config_editor.html` 그림 그리기 격자에서 단계마다 다른 색으로 칸을
		찍는다). `Cells`가 있을 때만 의미가 있다.

		자원이 무엇인지는 여기서 모른다 — `BattleGrid`는 격자만 알고 직업
		자원은 모르므로, 실제 개수는 부르는 쪽(`BattleSkills.Cells`/`Targets`)이
		`growCount`로 넘긴다.
	]]
	Stages: { { { X: number, Y: number } } }?,
	--[[
		**어느 진영을 겨누는가.** 비우면 기존처럼 상대 진영(`Foe`)이다.
		`Ally`면 캐스터 **자기 진영**을 겨눈다 — 기준점 (n,n)도 상대가 아니라
		캐스터 자신이 선 칸이다(요청: "격자에서 찍기에 아군 진형에 스킬
		사용 누르면 아군 진형에 범위 지정"). 버프·회복처럼 아군을 대상으로
		하는 스킬이 실제로 아군 칸을 때린 것으로 잡히려면 이게 있어야 한다 —
		`Range = "Supporting"`은 연출·카드 조건일 뿐 겨누는 진영을 안 정한다.
	]]
	TargetSide: ("Foe" | "Ally")?,
}

local DEFAULT_WIDTH = 6
local DEFAULT_HEIGHT = 3

local BattleGrid = {}

BattleGrid.DEFAULT_WIDTH = DEFAULT_WIDTH
BattleGrid.DEFAULT_HEIGHT = DEFAULT_HEIGHT

function BattleGrid.CellKey(side: Side, x: number, y: number): string
	return string.format("%s:%d,%d", side, x, y)
end

function BattleGrid.New(width: number?, height: number?): Grid
	return {
		Width = width or DEFAULT_WIDTH,
		Height = height or DEFAULT_HEIGHT,
		Disabled = {},
		Occupants = {},
		UnitCells = {},
	}
end

function BattleGrid.InBounds(grid: Grid, x: number, y: number): boolean
	return x >= 1 and x <= grid.Width and y >= 1 and y <= grid.Height
end

--[[
	칸을 켜고 끈다. 보스전에서 칸을 제한할 때 쓴다(사양).
	막힌 칸에는 배치도 이동도 할 수 없다.
]]
function BattleGrid.SetEnabled(grid: Grid, side: Side, x: number, y: number, enabled: boolean): ()
	grid.Disabled[BattleGrid.CellKey(side, x, y)] = if enabled then nil else true
end

function BattleGrid.IsEnabled(grid: Grid, side: Side, x: number, y: number): boolean
	if not BattleGrid.InBounds(grid, x, y) then
		return false
	end
	return grid.Disabled[BattleGrid.CellKey(side, x, y)] ~= true
end

function BattleGrid.Occupant(grid: Grid, side: Side, x: number, y: number): string?
	return grid.Occupants[BattleGrid.CellKey(side, x, y)]
end

function BattleGrid.CellOf(grid: Grid, unitId: string): Cell?
	return grid.UnitCells[unitId]
end

--[[
	유닛을 칸에 놓는다.

	실패 사유를 문자열로 돌려주므로 UI가 그대로 띄울 수 있다.
	이미 다른 칸에 있던 유닛이면 그 칸을 비우고 옮긴다.
]]
function BattleGrid.Place(grid: Grid, unitId: string, side: Side, x: number, y: number): (boolean, string?)
	if not BattleGrid.InBounds(grid, x, y) then
		return false, "격자 밖입니다."
	end
	if not BattleGrid.IsEnabled(grid, side, x, y) then
		return false, "이 전투에서 막혀 있는 칸입니다."
	end

	local key = BattleGrid.CellKey(side, x, y)
	local existing = grid.Occupants[key]
	if existing ~= nil and existing ~= unitId then
		return false, "이미 다른 유닛이 있는 칸입니다."
	end

	-- 원래 있던 칸을 비운다.
	local previous = grid.UnitCells[unitId]
	if previous then
		grid.Occupants[BattleGrid.CellKey(previous.Side, previous.X, previous.Y)] = nil
	end

	grid.Occupants[key] = unitId
	grid.UnitCells[unitId] = { Side = side, X = x, Y = y }
	return true, nil
end

--[[
	칸 여러 개를 한 유닛이 차지한다(보스 부위). 첫 칸이 대표 칸(CellOf)이다.
	하나라도 막혔거나 남이 있으면 아무 칸도 차지하지 않는다. 이런 유닛은 옮기지 않는다.
]]
function BattleGrid.PlaceBlock(grid: Grid, unitId: string, side: Side, cells: { { number } }): boolean
	for _, c in cells do
		local existing = BattleGrid.Occupant(grid, side, c[1], c[2])
		if not BattleGrid.IsEnabled(grid, side, c[1], c[2]) or (existing ~= nil and existing ~= unitId) then
			return false
		end
	end
	for _, c in cells do
		grid.Occupants[BattleGrid.CellKey(side, c[1], c[2])] = unitId
	end
	grid.UnitCells[unitId] = { Side = side, X = cells[1][1], Y = cells[1][2] }
	local blocks = grid.Blocks or {}
	blocks[unitId] = true
	grid.Blocks = blocks
	return true
end

-- 여러 칸 유닛이 그 라인(y)에 한 칸이라도 걸쳐 있는가
function BattleGrid.UnitInLane(grid: Grid, side: Side, unitId: string, lane: number): boolean
	for x = 1, grid.Width do
		if BattleGrid.Occupant(grid, side, x, lane) == unitId then
			return true
		end
	end
	return false
end

function BattleGrid.Remove(grid: Grid, unitId: string): ()
	local cell = grid.UnitCells[unitId]
	if not cell then
		return
	end
	grid.UnitCells[unitId] = nil
	if grid.Blocks then
		grid.Blocks[unitId] = nil
	end
	-- 여러 칸을 차지한 유닛(PlaceBlock)도 모든 칸을 비운다
	for key, id in grid.Occupants do
		if id == unitId then
			grid.Occupants[key] = nil
		end
	end
end

--[[
	같은 진영 안에서 이동한다(사양: "매 턴마다 해당 격자 내에서 움직이며").
	진영을 넘어가는 이동은 막는다.
]]
function BattleGrid.Move(grid: Grid, unitId: string, x: number, y: number): (boolean, string?)
	local cell = grid.UnitCells[unitId]
	if not cell then
		return false, "격자에 없는 유닛입니다."
	end
	-- 보스 부위처럼 여러 칸을 차지한 유닛은 밀기·끌어당기기·이동이 모두 안 먹힌다
	if grid.Blocks and grid.Blocks[unitId] then
		return false, "움직일 수 없는 거대한 적입니다."
	end
	return BattleGrid.Place(grid, unitId, cell.Side, x, y)
end

--[[
	스킬 범위에 들어가는 칸 목록.

	**미리보기와 실제 타격이 이 함수를 함께 쓴다.**
	사양: "스킬 범위 미리보기의 경우 격자의 색깔을 붉게 표시해 미리보기를 표시"
	→ 반환된 칸을 붉게 칠하면 그것이 곧 맞을 칸이다.

	막힌 칸은 제외한다. `growCount`는 `shape.Stages`를 몇 단계까지 켤지다
	(자원 개수 등 — 부르는 쪽이 결정해 넘긴다. 기본 0).
]]
function BattleGrid.CellsInShape(
	grid: Grid,
	side: Side,
	originX: number,
	originY: number,
	shape: Shape,
	growCount: number?
): { Cell }
	local cells: { Cell } = {}
	local radius = shape.Radius or 1

	local function add(x: number, y: number)
		if BattleGrid.IsEnabled(grid, side, x, y) then
			table.insert(cells, { Side = side, X = x, Y = y })
		end
	end

	--[[
		직접 찍은 칸이 있으면 그것이 전부다. 기준점에서의 상대 좌표를 그대로 더한다.
		격자 밖으로 나가는 칸은 `add`가 걸러 낸다.
	]]
	if shape.Cells then
		for _, offset in shape.Cells do
			add(originX + offset.X, originY + offset.Y)
		end
		if shape.Stages and growCount and growCount > 0 then
			for stage = 1, math.min(growCount, #shape.Stages) do
				for _, offset in shape.Stages[stage] do
					add(originX + offset.X, originY + offset.Y)
				end
			end
		end
		return cells
	end

	if shape.Kind == "Single" then
		add(originX, originY)
	elseif shape.Kind == "Row" then
		for x = 1, grid.Width do
			add(x, originY)
		end
	elseif shape.Kind == "Column" then
		for y = 1, grid.Height do
			add(originX, y)
		end
	elseif shape.Kind == "Cross" then
		add(originX, originY)
		for step = 1, radius do
			add(originX - step, originY)
			add(originX + step, originY)
			add(originX, originY - step)
			add(originX, originY + step)
		end
	elseif shape.Kind == "Square" then
		for x = originX - radius, originX + radius do
			for y = originY - radius, originY + radius do
				add(x, y)
			end
		end
	elseif shape.Kind == "All" then
		for x = 1, grid.Width do
			for y = 1, grid.Height do
				add(x, y)
			end
		end
	elseif shape.Kind == "Line" then
		--[[
			origin(보통 상대가 실제로 서 있는 칸)에서 앞으로 radius칸을 뻗는다.
			요청: "공격 범위가 (n,n)부터 (n+1,n)인 공격은... 좌표가 그대로
			반영돼야 하는데 그냥 (n,n)이야." — origin이 격자 끝에 가까워 radius칸을
			다 못 뻗으면 ClampWindowStart로 창을 뒤로 당겨서 칸 수를 그대로 지킨다.
		]]
		local length = math.max(radius, 1)
		local startX = BattleGrid.ClampWindowStart(grid, originX, length)
		for x = startX, math.min(startX + length - 1, grid.Width) do
			add(x, originY)
		end
	end

	return cells
end

-- 위 칸들 중 실제로 유닛이 있는 것만. 대미지 계산 대상이다.
function BattleGrid.UnitsInShape(
	grid: Grid,
	side: Side,
	originX: number,
	originY: number,
	shape: Shape,
	growCount: number?
): { string }
	local units: { string } = {}
	for _, cell in BattleGrid.CellsInShape(grid, side, originX, originY, shape, growCount) do
		local occupant = BattleGrid.Occupant(grid, cell.Side, cell.X, cell.Y)
		if occupant then
			table.insert(units, occupant)
		end
	end
	return units
end

-- 반대 진영을 돌려준다.
function BattleGrid.Opposing(side: Side): Side
	return if side == "Ally" then "Enemy" else "Ally"
end

--[[
	그 라인에서 공격자 쪽(앞열, x=1)부터 훑어 **처음 걸리는** 점유 칸을 찾는다.
	라인에 유닛이 여럿(향후 "뒤에 있는 적" 기믹) 있어도 가장 가까운 것부터 나온다.
	없으면 nil.
]]
function BattleGrid.FirstOccupiedColumn(grid: Grid, side: Side, lane: number): (number?, string?)
	for x = 1, grid.Width do
		local occupant = BattleGrid.Occupant(grid, side, x, lane)
		if occupant then
			return x, occupant
		end
	end
	return nil, nil
end

--[[
	depth칸짜리 사거리 창이 격자를 벗어나지 않도록 시작 칸을 안으로 당긴다.

	요청: "공격 범위가 (n,n)부터 (n+1,n)인 공격은, 적을 조준했을 때 좌표가 그대로
	       반영돼야 하는데, 그냥 (n,n)이야." — anchor(적이 실제로 있는 칸)가 격자
	       끝에 가까워서 앞으로 depth칸을 다 못 뻗으면, 그냥 잘려서 1칸짜리가
	       되어버렸다. 그 대신 창을 뒤로 당겨서라도 depth칸을 항상 그대로
	       확보한다(격자 폭보다 depth가 크면 그때만 격자 폭만큼으로 줄어든다).
]]
function BattleGrid.ClampWindowStart(grid: Grid, anchor: number, depth: number): number
	local reach = math.max(depth, 1)
	return math.max(1, math.min(anchor, grid.Width - reach + 1))
end

--[[
	조준 칸. 그 라인에 상대가 있으면 그 칸(=가장 가까운 유닛), 없으면 맨 끝 칸.
	depth를 주면 그 사거리 창이 격자를 벗어나지 않게 당겨진 시작 칸을 돌려준다.

	사양: "적이 없는 칸에선 맨 끝 칸을 조준."
	빔 미리보기·판정 둘 다 이 함수로 "어디를 겨눌지"를 정한다.
]]
function BattleGrid.AimColumn(grid: Grid, attackerSide: Side, lane: number, depth: number?): number
	local targetSide = BattleGrid.Opposing(attackerSide)
	local startX = select(1, BattleGrid.FirstOccupiedColumn(grid, targetSide, lane))
	local anchor = startX or grid.Width
	return BattleGrid.ClampWindowStart(grid, anchor, depth or 1)
end

--[[
	세로 라인(lane) 공격 판정.

	사양: "공격 위치는 플레이어가 있는 세로 라인으로 정해진다.
	       플레이어가 세로 3칸 중 2번째 라인이면, 적 라인 중 2번째 라인의 적이 대상."

	즉 공격자는 **자기 세로 라인(y)과 같은 라인**의 상대 진영만 때린다.
	마우스로 조준하지 않는다 — 서 있는 라인이 곧 공격 라인이다.
	적도 같은 규칙을 쓴다(자기 y == 상대 y).

	요청: "스킬 시작 범위가 적한테 닿은 시점에서 시작되게. 적이 (1,2)에 있으면
	       플레이어가 (n,2)에 있을 때 스킬도 (1,2)에서 시작하도록. 뒤에 있는 적을
	       공격하는 로직도 추가할 거라 유연하게."

	그래서 depth를 "앞열(x=1)부터 몇 칸"이 아니라 **그 라인에서 처음 만나는 상대
	유닛부터** 몇 칸 훑을지로 바꿨다. 뒤로 물러나는 건 이제 사정거리 밖으로
	도망치는 회피가 아니다(라인=Splash 회피가 기본 방어 수단이 된다). 대신 depth가
	클수록 그 유닛 뒤에 또 있는 유닛까지 꿰뚫는다 — 나중에 라인에 유닛을 여러 개
	세우면 자연히 관통 공격이 된다. 라인에 아무도 없으면 빈 목록(조준 표시는
	AimColumn으로 맨 끝 칸을 쓴다).

	target이 격자 끝쪽이라 depth칸을 다 못 뻗을 상황이면 ClampWindowStart로
	창을 뒤로 당겨서, 선언된 depth만큼은 항상 그대로 반영되게 한다.
]]
function BattleGrid.LaneTargets(grid: Grid, attackerSide: Side, lane: number, depth: number?): { string }
	local targetSide = BattleGrid.Opposing(attackerSide)
	local reach = depth or grid.Width

	local startX = select(1, BattleGrid.FirstOccupiedColumn(grid, targetSide, lane))
	if not startX then
		return {}
	end

	local windowStart = BattleGrid.ClampWindowStart(grid, startX, reach)
	local units: { string } = {}
	for x = windowStart, math.min(windowStart + reach - 1, grid.Width) do
		local occupant = BattleGrid.Occupant(grid, targetSide, x, lane)
		if occupant then
			table.insert(units, occupant)
		end
	end
	return units
end

-- 해당 라인에 상대 진영 유닛이 하나라도 있는지 (없으면 그 라인 공격은 빗나간다).
function BattleGrid.LaneHasTarget(grid: Grid, attackerSide: Side, lane: number): boolean
	return #BattleGrid.LaneTargets(grid, attackerSide, lane, nil) > 0
end

--[[
	멀티플레이에서 같은 칸을 고른 경우의 처리 방식.

	사양: "같은 칸에 캐릭터를 놓는 경우가 생긴다면, 해당 팀 전체가 투표를 하게 된다.
	       듀오의 경우, 투표가 불가하므로 가위바위보를 통해 위치를 정한다."

	투표는 3인 이상에서만 성립한다(2인이면 1:1로 갈려 결론이 안 난다).
]]
export type ConflictResolution = "Vote" | "RockPaperScissors"

function BattleGrid.ConflictResolution(teamSize: number): ConflictResolution
	if teamSize <= 2 then
		return "RockPaperScissors"
	end
	return "Vote"
end

-- 배치 요청들 중 칸이 겹치는 것을 찾아낸다. 겹친 칸마다 경쟁자 목록을 돌려준다.
function BattleGrid.FindConflicts(
	requests: { { UnitId: string, Side: Side, X: number, Y: number } }
): { [string]: { string } }
	local byCell: { [string]: { string } } = {}
	for _, request in requests do
		local key = BattleGrid.CellKey(request.Side, request.X, request.Y)
		if not byCell[key] then
			byCell[key] = {}
		end
		table.insert(byCell[key], request.UnitId)
	end

	local conflicts: { [string]: { string } } = {}
	for key, unitIds in byCell do
		if #unitIds > 1 then
			conflicts[key] = unitIds
		end
	end
	return conflicts
end

return BattleGrid
