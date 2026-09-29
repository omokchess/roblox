--!strict
-- UnionGroundByRegion.luau
--
-- 요청: "ground 유니온은 지역별로 하나씩만 남도록 묶어줘"
--
-- ══════════════════════════════════════════════════════════════════════
--  경고 — "지역당 정확히 1개"는 엔진 제약상 불가능하다
-- ══════════════════════════════════════════════════════════════════════
--   Roblox 파트의 최대 크기는 **2048스터드**다. UnionOperation도 예외가 아니다.
--   지역 하나가 3,000~4,000스터드라 한 덩어리로 만들면 2048로 잘린다.
--
--   실제로 2026-07-24에 그대로 시도했다가 지면의 55%를 잃었다:
--     Ground_설원 sz=(2048, 648, 2048)   ← 2048에 붙어 잘림
--     Ground_화산 sz=(2048, 972, 2048)
--     격자 3,721지점 중 2,059지점에서 지면 소실
--
--   게다가 `G` 파트가 Locked=true라 **Ctrl+Z로 복구되지 않았다**
--   (`The Parent property of G is locked` ×5000). 백업에서 되돌려야 했다.
--
--   그래서 이 스크립트는 **2048 한도 안에서 최소 개수**로 묶는다.
--   지역을 TILE(1900스터드) 격자로 나눠 타일당 1개를 만든다.
--   결과는 지역당 보통 4개(2×2), 전체 약 32개다.
--
--   추가 안전장치: Union 결과가 한 축이라도 2040을 넘으면 잘린 것으로 보고
--   그 타일을 절반으로 다시 나눠 재시도한다.
--
-- ── 지역 판정 ───────────────────────────────────────────────────────────
--   맵이 탑 중심 링 구조라 각도 섹터로 나눈다. 각도는 보스 아레나 실측값.
--     화산 0° / 늪 72° / 사막 133° / 숲 180° / 평원 225° / 설원 270° / 오염 320°
--   중심 420스터드 안쪽은 탑 광장이라 '중앙'.
--
-- ── 감수하는 것 ─────────────────────────────────────────────────────────
--   재질이 타일당 하나로 통일된다(UnionOperation은 Material이 하나).
--   각 타일의 최다 재질을 쓴다. 색은 UsePartColor=false로 원본 유지.
--
-- 실행 전 반드시 백업할 것. 되돌리기가 안 되는 작업이다.
-- 실행: Studio 커맨드 바. 결과는 "GREG::" 접두어.

local TILE = 1900 -- 2048 한도 안에 여유를 두고 자른다
local MAX_SIZE = 2040 -- 이 값을 넘으면 잘린 것으로 판단
local TOLERANCE = 0.15

local SECTORS = {
	{ name = "화산", angle = 0 },
	{ name = "늪", angle = 72 },
	{ name = "사막", angle = 133 },
	{ name = "숲", angle = 180 },
	{ name = "평원", angle = 225 },
	{ name = "설원", angle = 270 },
	{ name = "오염", angle = 320 },
}
local CENTER_RADIUS = 420

local function log(fmt: string, ...): ()
	print("GREG:: " .. string.format(fmt, ...))
end

local ground = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Ground")
if not ground then
	log("중단: Ground 없음")
	return
end

local function regionOf(x: number, z: number): string
	if math.sqrt(x * x + z * z) < CENTER_RADIUS then
		return "중앙"
	end
	local angle = math.deg(math.atan2(z, x))
	if angle < 0 then
		angle += 360
	end
	local best, bestDiff = SECTORS[1].name, math.huge
	for _, sector in SECTORS do
		local diff = math.abs(angle - sector.angle)
		diff = math.min(diff, 360 - diff)
		if diff < bestDiff then
			bestDiff = diff
			best = sector.name
		end
	end
	return best
end

--=== 수집: 지역 × 타일 ===--

type Group = { parts: { BasePart }, material: { [Enum.Material]: number } }

local groups: { [string]: Group } = {}

for _, part in ipairs(ground:GetDescendants()) do
	if part:IsA("BasePart") then
		local key = string.format(
			"%s#%d,%d",
			regionOf(part.Position.X, part.Position.Z),
			math.floor(part.Position.X / TILE),
			math.floor(part.Position.Z / TILE)
		)
		local group = groups[key]
		if not group then
			group = { parts = {}, material = {} }
			groups[key] = group
		end
		table.insert(group.parts, part)
		group.material[part.Material] = (group.material[part.Material] or 0) + 1
	end
end

--=== 검증 표본 (전) ===--

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { ground }

local samples: { Vector3 } = {}
local before: { number? } = {}
for _, group in groups do
	for index, part in group.parts do
		if index % 2 == 0 then
			table.insert(samples, Vector3.new(part.Position.X, 2000, part.Position.Z))
		end
	end
end
for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -4000, 0), params)
	before[i] = if hit then hit.Position.Y else nil
end
log(
	"표본 %d개 / 그룹 %s개",
	#samples,
	(function()
		local n = 0
		for _ in groups do
			n += 1
		end
		return tostring(n)
	end)()
)

--=== 병합 ===--

local clipped = 0

-- 결과가 2048에 잘렸으면 되돌리고 절반으로 나눠 재시도한다.
local function merge(parts: { BasePart }, material: Enum.Material, label: string, depth: number): number
	if #parts <= 1 then
		return #parts
	end

	local base = parts[1]
	local rest: { BasePart } = {}
	for i = 2, #parts do
		table.insert(rest, parts[i])
	end

	local ok, result = pcall(function()
		return base:UnionAsync(rest, Enum.CollisionFidelity.PreciseConvexDecomposition)
	end)

	if ok and result then
		local size = result.Size
		-- 2048 한도에 닿았는지 본다. 닿았으면 지오메트리가 잘린 것이다.
		if (size.X >= MAX_SIZE or size.Y >= MAX_SIZE or size.Z >= MAX_SIZE) and depth < 6 then
			result:Destroy() -- 잘린 결과는 버린다 (원본 파트는 아직 살아 있다)
			clipped += 1
			local half = math.floor(#parts / 2)
			local a: { BasePart } = {}
			local b: { BasePart } = {}
			for i, part in parts do
				if i <= half then
					table.insert(a, part)
				else
					table.insert(b, part)
				end
			end
			return merge(a, material, label .. "a", depth + 1) + merge(b, material, label .. "b", depth + 1)
		end

		result.Name = "Ground_" .. label
		result.UsePartColor = false
		result.Anchored = true
		result.CanCollide = true
		result.Material = material
		result.Parent = ground
		base:Destroy()
		for _, part in rest do
			part:Destroy()
		end
		return 1
	end

	if depth >= 6 or #parts < 4 then
		log("경고: %s 병합 실패, %d개 유지", label, #parts)
		return #parts
	end

	local half = math.floor(#parts / 2)
	local a: { BasePart } = {}
	local b: { BasePart } = {}
	for i, part in parts do
		if i <= half then
			table.insert(a, part)
		else
			table.insert(b, part)
		end
	end
	return merge(a, material, label .. "a", depth + 1) + merge(b, material, label .. "b", depth + 1)
end

local startClock = os.clock()
local made = 0
for key, group in groups do
	local topMaterial, topCount = Enum.Material.Grass, -1
	for material, count in group.material do
		if count > topCount then
			topCount = count
			topMaterial = material
		end
	end
	made += merge(group.parts, topMaterial, (key:gsub("#", "_")), 0)
end

log("병합 %.1f초 | 결과 %d개 / 2048에 걸려 재분할 %d회", os.clock() - startClock, made, clipped)

--=== 검증 (후) ===--

params.FilterDescendantsInstances = { ground }

local same, differ, missing, worst = 0, 0, 0, 0
for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -4000, 0), params)
	local after = if hit then hit.Position.Y else nil
	if before[i] == nil or after == nil then
		missing += 1
	elseif math.abs(after - (before[i] :: number)) < TOLERANCE then
		same += 1
	else
		differ += 1
		worst = math.max(worst, math.abs(after - (before[i] :: number)))
	end
end
log("지면 검증: 동일 %d / 다름 %d (최대 %.3f) / 미검출 %d", same, differ, worst, missing)

if missing > 0 then
	log("!! 지면이 사라진 지점이 있다. 저장하지 말고 백업에서 복구할 것.")
end

-- 크기 점검: 2048에 붙은 Union이 남아 있으면 안 된다
local oversized = 0
local total = 0
for _, part in ipairs(ground:GetDescendants()) do
	if part:IsA("BasePart") then
		total += 1
		local size = part.Size
		if size.X >= MAX_SIZE or size.Y >= MAX_SIZE or size.Z >= MAX_SIZE then
			oversized += 1
		end
	end
end
log("Ground 인스턴스 %d개 / 2048에 붙은 것 %d개 (0이어야 정상)", total, oversized)
