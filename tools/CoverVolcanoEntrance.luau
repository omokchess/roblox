--!strict
-- CoverVolcanoEntrance.luau
--
-- 피드백: "화산 지하 입구 위로 뻥 뚫려있는데, 이걸 동굴처럼 표현하기 위해 천장을 덮어줘."
--
-- ── 문제 확인 ────────────────────────────────────────────────────────────
--   입구(Mouth*) 묶음: Workspace.World.VolcanoTunnel 의 MouthArch / MouthPylon / MouthFang
--     n=31, 중심 (1923, 501, 655), 크기 (234, 282, 209), Y[360..642]
--
--   입구 위로 레이캐스트를 쏴 본 결과 — 아치 바로 위만 막혀 있고 주변은 하늘이 뚫려 있었다:
--     (1923,531,655) → MouthArch @y=560
--     (1983,531,655) → OPEN SKY
--     (1863,531,655) → OPEN SKY
--     (2023,531,755) → OPEN SKY
--     (1823,531,555) → OPEN SKY
--
-- ── 해법 ────────────────────────────────────────────────────────────────
--   입구 중심 반경 CEIL_RADIUS 안을 격자로 훑으면서, **위로 쏴서 아무것도 안 맞는
--   칸에만** 바위 천장 블록을 놓는다. 이미 막혀 있는 칸은 건너뛰므로 기존 아치·
--   지형과 겹치지 않는다.
--
--   자연스러운 동굴 느낌을 위해:
--     - 가장자리로 갈수록 천장을 낮춘다 (r이 클수록 y 하강) → 돔 형태
--     - 높이·크기에 난수 지터를 줘서 평평한 판처럼 보이지 않게 한다
--     - 재질 Slate, 화산암 계열 어두운 색
--
--   생성물은 `VolcanoTunnel.EntranceCeiling` 폴더에 모은다.
--   재실행하면 폴더를 지우고 다시 만들므로 중복되지 않는다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "CEIL::" 접두어.

local CENTER = Vector3.new(1923, 0, 655) -- 입구 중심 (XZ만 사용)
local CEIL_RADIUS = 250 -- 덮을 반경
local GRID_STEP = 28 -- 격자 간격
local CEIL_Y = 690 -- 중앙 천장 높이 (아치 top=642보다 위)
local EDGE_DROP = 55 -- 가장자리에서 낮아지는 정도
local PROBE_FROM = 650 -- 이 높이에서 위로 쏜다
local PROBE_UP = 1200 -- 위로 얼마나 볼지

local function log(fmt: string, ...): ()
	print("CEIL:: " .. string.format(fmt, ...))
end

local tunnel = workspace.World:FindFirstChild("VolcanoTunnel")
if not tunnel then
	log("중단: VolcanoTunnel 없음")
	return
end

-- 재실행 대비
local old = tunnel:FindFirstChild("EntranceCeiling")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "EntranceCeiling"
folder.Parent = tunnel

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { folder }

local rng = Random.new(20260720)
local placed, skipped = 0, 0

local steps = math.floor(CEIL_RADIUS / GRID_STEP)

for ix = -steps, steps do
	for iz = -steps, steps do
		local dx = ix * GRID_STEP
		local dz = iz * GRID_STEP
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= CEIL_RADIUS then
			local x = CENTER.X + dx
			local z = CENTER.Z + dz

			-- 이 칸 위가 이미 막혀 있는지 확인
			local hit = workspace:Raycast(Vector3.new(x, PROBE_FROM, z), Vector3.new(0, PROBE_UP, 0), params)

			if hit then
				skipped += 1
			else
				-- 가장자리로 갈수록 낮아지는 돔 + 난수 지터
				local t = dist / CEIL_RADIUS
				local y = CEIL_Y - (t * t) * EDGE_DROP + rng:NextNumber(-9, 9)

				local block = Instance.new("Part")
				block.Name = "CaveRoof"
				block.Anchored = true
				block.CanCollide = true
				block.Size = Vector3.new(
					GRID_STEP + rng:NextNumber(2, 9),
					rng:NextNumber(26, 46),
					GRID_STEP + rng:NextNumber(2, 9)
				)
				block.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 0.35), 0)
				block.Material = Enum.Material.Slate
				block.Color = Color3.fromRGB(
					48 + rng:NextInteger(-6, 10),
					42 + rng:NextInteger(-6, 10),
					40 + rng:NextInteger(-6, 10)
				)
				block.TopSurface = Enum.SurfaceType.Smooth
				block.BottomSurface = Enum.SurfaceType.Smooth
				block.Parent = folder
				placed += 1
			end
		end
	end
end

log(
	"천장 블록 %d개 생성, 이미 막힌 칸 %d개는 건너뜀 (반경 %d, 격자 %d)",
	placed,
	skipped,
	CEIL_RADIUS,
	GRID_STEP
)
log("위치: Workspace.World.VolcanoTunnel.EntranceCeiling (파트명 CaveRoof)")
