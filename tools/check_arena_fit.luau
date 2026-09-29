--[[
	check_arena_fit.luau — 격자가 카메라 한 화면에 담기는지 수치로 확인한다.

	Studio 없이 Lune으로 돌린다. `BattleArena`의 실제 계산을 그대로 쓴다.
	  lune run tools/check_arena_fit.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SHARED = "src/shared/"

--=== Roblox 전역 최소 구현 ===--

local Vector2 = {}
Vector2.__index = Vector2
function Vector2.new(x, y)
	return setmetatable({ X = x, Y = y }, Vector2)
end

local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.__mul(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.__unm(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function Vector3.Dot(self, other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
function Vector3.Cross(self, other)
	return Vector3.new(
		self.Y * other.Z - self.Z * other.Y,
		self.Z * other.X - self.X * other.Z,
		self.X * other.Y - self.Y * other.X
	)
end
function Vector3.__index(self, key)
	if key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return rawget(Vector3, key)
end

-- 축 정렬 CFrame만 쓴다 (Origin이 항상 축 정렬이라 충분하다)
local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(pos)
	return setmetatable({
		Position = pos,
		LookVector = Vector3.new(0, 0, -1),
		RightVector = Vector3.new(1, 0, 0),
	}, CFrame)
end
function CFrame.lookAt(eye, target)
	local dir = (target - eye).Unit
	local right = Vector3.new(-dir.Z, 0, dir.X).Unit
	return setmetatable({ Position = eye, LookVector = dir, RightVector = right }, CFrame)
end
function CFrame.__mul(a, b)
	return CFrame.new(a.Position + (b.Position or Vector3.new(0, 0, 0)))
end

--=== 모듈 로더 ===--

local sources = {}
for _, entry in fs.readDir(SHARED) do
	local name = entry:match("^(.+)%.luau$")
	if name then
		sources[name] = fs.readFile(SHARED .. entry)
	end
end

local cache = {}
local loadShared
local proxy = setmetatable({}, {
	__index = function(_, name)
		return loadShared(name)
	end,
})

function loadShared(name)
	if cache[name] then
		return cache[name]
	end
	local env = {}
	for k, v in _G do
		env[k] = v
	end
	env.math, env.table, env.string = math, table, string
	env.Vector2, env.Vector3, env.CFrame = Vector2, Vector3, CFrame
	env.warn = print
	env.script = { Parent = proxy }
	env.require = function(t)
		return t
	end
	local chunk = luau.load(sources[name], { debugName = name, environment = env })
	local result = chunk()
	cache[name] = result
	return result
end

--=== 검사 ===--

local BattleArena = loadShared("BattleArena")
local BattleGrid = loadShared("BattleGrid")

local WIDTH, HEIGHT = 6, 3
local layout = BattleArena.NewLayout(CFrame.new(Vector3.new(0, 0, 0)))

print(string.format("칸 %d / 간격 %d / 중앙선 %d", layout.CellSize, layout.Gap, layout.Midline))

local extents = BattleArena.ArenaExtents(layout, WIDTH, HEIGHT)
print(string.format("격자 전체 크기: 좌우축 %.0f × 세로라인축 %.0f 스터드", extents.X, extents.Y))

-- 칸이 캐릭터 크기인지 (R6 아바타는 폭 4 정도)
assert(
	layout.CellSize >= 4 and layout.CellSize <= 8,
	"칸이 캐릭터 크기 범위를 벗어났다: " .. layout.CellSize
)
print("OK 칸 크기가 캐릭터 규모다")

-- 사양: 브라운 더스트식 좌우 진형. 진영 = X(좌우), 세로 라인 = Z
local ally = BattleArena.CellOffset(layout, "Ally", 1, 1, WIDTH, HEIGHT)
local enemy = BattleArena.CellOffset(layout, "Enemy", 1, 1, WIDTH, HEIGHT)
assert(ally.X < 0 and enemy.X > 0, "아군은 -X(왼쪽), 적은 +X(오른쪽)이어야 한다")
assert(math.abs(ally.Z - enemy.Z) < 0.001, "같은 라인은 Z가 같아야 한다")
print(string.format("OK 진영이 좌우로 갈린다 (아군 X=%.1f / 적 X=%.1f)", ally.X, enemy.X))

-- 세로 라인 3칸이 Z축(화면 세로)에 놓이는지
local lane1 = BattleArena.CellOffset(layout, "Ally", 1, 1, WIDTH, HEIGHT)
local lane3 = BattleArena.CellOffset(layout, "Ally", 1, 3, WIDTH, HEIGHT)
assert(
	math.abs(lane3.Z - lane1.Z) > 0.001 and math.abs(lane3.X - lane1.X) < 0.001,
	"세로 라인 3칸이 Z축에 놓여야 한다"
)
print(string.format("OK 세로 라인 3칸이 Z축에 놓인다 (%.1f ~ %.1f)", lane1.Z, lane3.Z))

-- 6칸(진영 깊이)이 X축을 따라 뻗는지
local col1 = BattleArena.CellOffset(layout, "Ally", 1, 1, WIDTH, HEIGHT)
local col6 = BattleArena.CellOffset(layout, "Ally", 6, 1, WIDTH, HEIGHT)
assert(math.abs(col6.X) > math.abs(col1.X), "x가 커질수록 중앙에서 멀어져야 한다(뒤열)")
print(string.format("OK 6칸이 X축 깊이로 뻗는다 (x1=%.1f ~ x6=%.1f)", col1.X, col6.X))

-- 레인 타겟팅: 아군 y=2 라인이 적 y=2 라인만 때리는지
local grid = BattleGrid.New()
BattleGrid.Place(grid, "foeA", "Enemy", 1, 2)
BattleGrid.Place(grid, "foeB", "Enemy", 1, 1)
local hit = BattleGrid.LaneTargets(grid, "Ally", 2, nil)
assert(#hit == 1 and hit[1] == "foeA", "라인 2 공격은 라인 2의 적만 맞혀야 한다")
print("OK 세로 라인 공격이 같은 라인의 적만 맞힌다")

-- 스킬 시작 범위는 상대가 실제로 서 있는 칸에서 시작한다(요청: "스킬 시작 범위가
-- 적한테 닿은 시점에서 시작되게"). 뒷줄(x=4)에 있어도 depth=1짜리 짧은 스킬이 맞는다 —
-- 예전엔 x=1..depth만 훑어서 뒷줄은 아예 사정 밖이었다.
local grid2 = BattleGrid.New()
BattleGrid.Place(grid2, "backline", "Enemy", 4, 1)
local shortHit = BattleGrid.LaneTargets(grid2, "Ally", 1, 1)
assert(
	#shortHit == 1 and shortHit[1] == "backline",
	"뒷줄 상대도 처음 걸리는 칸부터 depth를 세야 한다"
)
assert(BattleGrid.AimColumn(grid2, "Ally", 1) == 4, "조준 칸은 실제로 상대가 있는 칸이어야 한다")
print("OK 스킬 사정이 상대가 실제로 있는 칸에서 시작한다")

-- 라인에 상대가 아예 없으면 맨 끝 칸을 조준한다(요청: "적이 없는 칸에선 맨 끝 칸을 조준").
assert(BattleGrid.AimColumn(grid2, "Ally", 2) == grid2.Width, "빈 라인은 맨 끝 칸을 조준해야 한다")
assert(#BattleGrid.LaneTargets(grid2, "Ally", 2, nil) == 0, "빈 라인은 맞는 대상이 없어야 한다")
print("OK 빈 라인은 맨 끝 칸을 조준하고 아무도 맞지 않는다")

--[[
	요청: "공격 범위가 (n,n)부터 (n+1,n)인 공격은, 적을 조준했을 때 좌표가 그대로
	반영돼야 하는데, 그냥 (n,n)이야." 상대가 격자 맨 끝(x=6)에 있으면 depth=2
	사거리가 6~7로 넘쳐 예전엔 6~6(1칸)으로 잘렸다. 이제는 5~6(2칸)으로 뒤로
	당겨져서 depth가 그대로 유지돼야 한다.
]]
local grid3 = BattleGrid.New()
BattleGrid.Place(grid3, "edge", "Enemy", grid3.Width, 1)
local edgeWindowStart = BattleGrid.AimColumn(grid3, "Ally", 1, 2)
assert(edgeWindowStart == grid3.Width - 1, "격자 끝 상대는 depth만큼 창을 뒤로 당겨야 한다")
local edgeHit = BattleGrid.LaneTargets(grid3, "Ally", 1, 2)
assert(#edgeHit == 1 and edgeHit[1] == "edge", "뒤로 당긴 창 안에 상대가 그대로 들어와야 한다")
print("OK 격자 끝 상대도 depth칸 사거리가 그대로 반영된다")

--[[
	스킬 범위 지정(요청): 찌르기/쌍베기는 상대가 있는 칸부터 Line(Radius 2),
	라인 관통은 Row(라인 전체), 십자 참은 상대를 중심으로 한 Cross(Radius 1),
	광역 폭발은 3×3 Square(Radius 1). BattleGrid.CellsInShape가 그대로 맞는지 본다.
]]
local lineCells = BattleGrid.CellsInShape(grid, "Enemy", 1, 2, { Kind = "Line", Radius = 2 })
assert(
	#lineCells == 2 and lineCells[1].X == 1 and lineCells[2].X == 2,
	"Line은 origin부터 앞으로 2칸이어야 한다"
)

local lineEdgeCells = BattleGrid.CellsInShape(grid3, "Enemy", grid3.Width, 1, { Kind = "Line", Radius = 2 })
assert(
	#lineEdgeCells == 2 and lineEdgeCells[1].X == grid3.Width - 1 and lineEdgeCells[2].X == grid3.Width,
	"격자 끝에서도 Line이 뒤로 당겨져 2칸을 유지해야 한다"
)

local crossCells = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Cross", Radius = 1 })
assert(#crossCells == 5, "Cross(Radius 1)는 중심 포함 5칸이어야 한다")

local squareCells = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Square", Radius = 1 })
assert(#squareCells == 9, "Square(Radius 1)는 3×3 = 9칸이어야 한다")

local cornerSquare = BattleGrid.CellsInShape(grid, "Enemy", 1, 1, { Kind = "Square", Radius = 1 })
assert(#cornerSquare == 4, "격자 모서리의 Square는 격자 밖 칸이 잘려 4칸이어야 한다")
print("OK Line·Cross·Square 스킬 범위가 사양대로 계산된다")

-- 카메라가 전부 담는지: 모든 칸을 카메라 좌표로 넣어 화각 안인지 본다
local FOV, ASPECT, PITCH = 70, 16 / 9, 45
local camera = BattleArena.FitCameraCFrame(layout, WIDTH, HEIGHT, FOV, ASPECT, PITCH)
local eye = camera.Position
print(string.format("카메라 위치 (%.1f, %.1f, %.1f) 거리 %.1f", eye.X, eye.Y, eye.Z, eye.Magnitude))

local halfV = math.rad(FOV) / 2
local halfH = math.atan(math.tan(halfV) * ASPECT)
local forward = camera.LookVector
local right = camera.RightVector
local up = Vector3.new(
	forward.Y * right.Z - forward.Z * right.Y,
	forward.Z * right.X - forward.X * right.Z,
	forward.X * right.Y - forward.Y * right.X
)

local worst = 0
local outside = 0
for _, side in { "Ally", "Enemy" } do
	for x = 1, WIDTH do
		for y = 1, HEIGHT do
			local offset = BattleArena.CellOffset(layout, side, x, y, WIDTH, HEIGHT)
			local rel = offset - eye
			local depth = rel.X * forward.X + rel.Y * forward.Y + rel.Z * forward.Z
			local hx = rel.X * right.X + rel.Y * right.Y + rel.Z * right.Z
			local hy = rel.X * up.X + rel.Y * up.Y + rel.Z * up.Z

			if depth <= 0 then
				outside += 1
			else
				local angleH = math.atan(math.abs(hx) / depth)
				local angleV = math.atan(math.abs(hy) / depth)
				worst = math.max(worst, angleH / halfH, angleV / halfV)
				if angleH > halfH or angleV > halfV then
					outside += 1
				end
			end
		end
	end
end

print(string.format("화각 사용률 %.0f%% (100%% 미만이면 전부 담김)", worst * 100))
assert(outside == 0, string.format("칸 %d개가 화면 밖으로 나갔다", outside))
print("OK 36칸 전부 한 화면에 담긴다")

print("\n[check_arena_fit] ALL PASSED")
