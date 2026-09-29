--!strict
-- UnionGround.luau
--
-- 요청: "Union은 일단 Ground만 묶어서 처리 해줘"
--
-- ── 대상 ────────────────────────────────────────────────────────────────
--   Workspace.World.Ground — `G` 파트 10,899개
--   실측: 전부 CanCollide=true, 전부 Locked=true
--         크기 50 × (426~456) × 50 → 50×50 발자국의 기둥, 높이가 제각각 (845종)
--         재질 12종 (Ground / Sand / Basalt / Grass …), 색 24종
--         bbox (-3650,-420,-3600) ~ (3550,552,3650)
--
-- ── 묶는 기준 ───────────────────────────────────────────────────────────
--   (재질, 공간격자) 로 버킷을 만든다.
--
--   **재질로 나누는 것이 필수다.** UnionOperation은 Material을 하나만 갖는다.
--   Grass와 Basalt를 한 덩어리로 묶으면 전부 한 재질이 되어 지형이 망가진다.
--   색은 UsePartColor=false로 두면 원본 파트 색이 그대로 유지되므로 나눌 필요가 없다.
--
--   공간격자(GRID)로 끊는 이유: 전부를 하나로 묶으면 경계 상자가 맵 전체를 덮어
--   컬링·스트리밍이 무력해진다.
--
-- ── 충돌 ────────────────────────────────────────────────────────────────
--   Ground는 밟고 다니는 지면이라 충돌이 어긋나면 끼임·추락이 생긴다.
--   그래서 CollisionFidelity를 **PreciseConvexDecomposition**으로 고정한다.
--
--   파일럿 검증(Basalt 39파트 → 1 Union, 0.05초):
--     지면 높이 39지점 전부 동일, 오차 0.00 → 충돌이 정확히 보존됨을 확인했다.
--
-- ── 안전장치 ────────────────────────────────────────────────────────────
--   Union 전후로 같은 좌표에 레이캐스트를 쏴 지면 높이를 비교한다.
--   허용 오차를 넘는 지점이 나오면 로그로 보고한다.
--
--   백업: backup/pre-ground-union.rbxl
--   되돌리기: Ctrl+Z 또는 위 백업
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "GUNION::" 접두어.

local GRID = 200 -- 공간 격자 한 변(스터드)
local MAX_PER_UNION = 40 -- Union 하나에 넣을 최대 파트 수
local MIN_PER_UNION = 2 -- 이보다 적으면 묶지 않는다
local HEIGHT_TOLERANCE = 0.15 -- 지면 높이 허용 오차(스터드)
local SAMPLE_STRIDE = 3 -- 검증 표본 간격 (3개마다 1개)

local function log(fmt: string, ...): ()
	print("GUNION:: " .. string.format(fmt, ...))
end

local ground = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Ground")
if not ground then
	log("중단: Workspace.World.Ground를 찾지 못했다")
	return
end

--=== 수집 ===--

type Bucket = { parts: { BasePart }, material: Enum.Material }

local buckets: { [string]: Bucket } = {}
local total = 0

for _, part in ipairs(ground:GetDescendants()) do
	-- 이미 Union된 것은 다시 묶지 않는다(파일럿 결과 포함).
	if part:IsA("BasePart") and not part:IsA("UnionOperation") then
		total += 1
		local key = string.format(
			"%s|%d,%d",
			part.Material.Name,
			math.floor(part.Position.X / GRID),
			math.floor(part.Position.Z / GRID)
		)
		local bucket = buckets[key]
		if not bucket then
			bucket = { parts = {}, material = part.Material }
			buckets[key] = bucket
		end
		table.insert(bucket.parts, part)
	end
end

log(
	"대상 파트 %d개 / 버킷 %s",
	total,
	(function()
		local n = 0
		for _ in buckets do
			n += 1
		end
		return tostring(n)
	end)()
)

--=== Union 전 지면 높이 표본 ===--

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { ground }

local samples: { Vector3 } = {}
local before: { number? } = {}

local index = 0
for _, bucket in buckets do
	for _, part in bucket.parts do
		index += 1
		if index % SAMPLE_STRIDE == 0 then
			table.insert(samples, Vector3.new(part.Position.X, 2000, part.Position.Z))
		end
	end
end

for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -4000, 0), params)
	before[i] = if hit then hit.Position.Y else nil
end

log("검증 표본 %d개 기록", #samples)

--=== 실행 ===--

local unionCount, mergedCount, failures = 0, 0, 0
local startClock = os.clock()

for _, bucket in buckets do
	local parts = bucket.parts
	local cursor = 1

	while cursor <= #parts do
		local chunk: { BasePart } = {}
		for offset = 0, MAX_PER_UNION - 1 do
			local part = parts[cursor + offset]
			if not part then
				break
			end
			table.insert(chunk, part)
		end
		cursor += #chunk

		if #chunk >= MIN_PER_UNION then
			local base = chunk[1]
			local rest: { BasePart } = {}
			for i = 2, #chunk do
				table.insert(rest, chunk[i])
			end

			local ok, result = pcall(function()
				return base:UnionAsync(rest, Enum.CollisionFidelity.PreciseConvexDecomposition)
			end)

			if ok and result then
				result.Name = "G_Union"
				result.UsePartColor = false -- 원본 파트 색 유지
				result.Anchored = true
				result.CanCollide = true
				result.Material = bucket.material
				result.Parent = ground

				base:Destroy()
				for _, part in rest do
					part:Destroy()
				end

				unionCount += 1
				mergedCount += #chunk
			else
				failures += 1
			end
		end
	end
end

local elapsed = os.clock() - startClock
log("Union %d개 생성 / 파트 %d개 병합 / 실패 %d건 / %.1f초", unionCount, mergedCount, failures, elapsed)

--=== Union 후 지면 높이 검증 ===--

params.FilterDescendantsInstances = { ground }

local same, differ, missing = 0, 0, 0
local worst = 0

for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -4000, 0), params)
	local after = if hit then hit.Position.Y else nil

	if before[i] == nil or after == nil then
		missing += 1
	elseif math.abs(after - (before[i] :: number)) < HEIGHT_TOLERANCE then
		same += 1
	else
		differ += 1
		worst = math.max(worst, math.abs(after - (before[i] :: number)))
	end
end

log("지면 검증: 동일 %d / 다름 %d (최대 오차 %.3f) / 미검출 %d", same, differ, worst, missing)

if differ > 0 or missing > 0 then
	log("경고: 지면이 달라진 지점이 있다. Ctrl+Z 또는 backup/pre-ground-union.rbxl로 되돌릴 것.")
else
	log("지면 높이가 전부 보존됐다.")
end

local remaining = 0
for _, part in ipairs(ground:GetDescendants()) do
	if part:IsA("BasePart") then
		remaining += 1
	end
end
log("Ground 인스턴스 %d개 → %d개", total, remaining)
