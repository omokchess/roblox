--!strict
-- MovePlainsVillageCloser.luau
--
-- 피드백: "평원의 마을을 탑이랑 더 가까이 위치하게 해줘."
--
-- ── 현재 상태 ────────────────────────────────────────────────────────────
--   Workspace.World.PlainsVillage
--     파트 1,866개, 중심 (-990, 58, -990), 크기 (210, 52, 216)
--     탑(원점)에서 거리 1,400 / 평원 섹터 각도 225도
--
-- ── 목표 ────────────────────────────────────────────────────────────────
--   같은 225도 축을 유지한 채 탑 쪽으로 당겨 거리 1,400 → NEW_DIST(980)
--   각도를 바꾸지 않으므로 다른 바이옴을 침범하지 않는다.
--
--   새 위치가 평원 보스방(대성채, 거리 2,050)과 탑 사이에 자연스럽게 놓인다:
--     탑(0) ── 마을(980) ── 대성채(2,050)
--
-- ── 높이 보정 ────────────────────────────────────────────────────────────
--   수평으로만 옮기면 지형 높이가 달라 마을이 뜨거나 파묻힌다.
--   옮기기 전/후 지점의 지면을 각각 레이캐스트해 그 차이만큼 Y도 함께 옮긴다.
--   (레이캐스트 시 마을 자신은 제외한다)
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "VILLAGE::" 접두어.
-- 되돌리기: Ctrl+Z

local NEW_DIST = 980

local function log(fmt: string, ...): ()
	print("VILLAGE:: " .. string.format(fmt, ...))
end

local village = workspace.World:FindFirstChild("PlainsVillage")
if not village then
	log("중단: PlainsVillage 없음")
	return
end

-- 현재 중심 구하기
local mn = Vector3.new(1e9, 1e9, 1e9)
local mx = Vector3.new(-1e9, -1e9, -1e9)
local parts: { BasePart } = {}

for _, part in ipairs(village:GetDescendants()) do
	if part:IsA("BasePart") then
		table.insert(parts, part)
		local a = part.Position - part.Size / 2
		local b = part.Position + part.Size / 2
		mn = Vector3.new(math.min(mn.X, a.X), math.min(mn.Y, a.Y), math.min(mn.Z, a.Z))
		mx = Vector3.new(math.max(mx.X, b.X), math.max(mx.Y, b.Y), math.max(mx.Z, b.Z))
	end
end

local center = (mn + mx) / 2
local oldDist = math.sqrt(center.X * center.X + center.Z * center.Z)
local angle = math.atan2(center.Z, center.X)

log(
	"현재 중심 (%.0f, %.0f, %.0f) 거리 %.0f 각도 %.1f도",
	center.X,
	center.Y,
	center.Z,
	oldDist,
	math.deg(angle)
)

if oldDist <= NEW_DIST + 5 then
	log("중단: 이미 목표 거리(%d) 이내다.", NEW_DIST)
	return
end

-- 같은 각도, 더 가까운 거리
local newX = math.cos(angle) * NEW_DIST
local newZ = math.sin(angle) * NEW_DIST
local dx = newX - center.X
local dz = newZ - center.Z

-- 지면 높이 비교 (마을 제외)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { village }

local function groundAt(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1800, 0), params)
	return hit and hit.Position.Y or nil
end

local oldGround = groundAt(center.X, center.Z)
local newGround = groundAt(newX, newZ)

local dy = 0
if oldGround and newGround then
	dy = newGround - oldGround
	log("지면 %.1f → %.1f (Y보정 %+.1f)", oldGround, newGround, dy)
else
	log("경고: 지면 탐색 실패 — Y보정 없이 수평 이동만 한다")
end

local shift = Vector3.new(dx, dy, dz)

for _, part in ipairs(parts) do
	part.CFrame = part.CFrame + shift
end

log("마을 %d파트 이동: (%+.0f, %+.0f, %+.0f)", #parts, dx, dy, dz)
log("새 중심 (%.0f, %.0f, %.0f) 거리 %d", newX, center.Y + dy, newZ, NEW_DIST)
