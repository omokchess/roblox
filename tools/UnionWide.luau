--!strict
-- UnionWide.luau
--
-- 요청: "유니온 범위가 더 넓어도 될 것 같아."
--
-- ── 이전과 달라진 점 ────────────────────────────────────────────────────
--   앞서 `UnionSimilarParts.luau`는 CanCollide=true 파트를 전부 제외했다.
--   Union이 충돌 판정을 근사 형상으로 바꿔 끼임·추락이 생길까 봐였다.
--
--   그런데 Ground 작업에서 `CollisionFidelity.PreciseConvexDecomposition`이
--   충돌을 **정확히** 보존함을 실측으로 확인했다.
--     파일럿: Basalt 39파트 → 1 Union, 지면 높이 39지점 전부 동일(오차 0.00)
--     본실행: 10,046파트 병합 후 내부 구멍 0개
--
--   그래서 이번엔 **충돌 파트도 포함**한다. 대신 fidelity를 절대 낮추지 않는다.
--
-- ── 여전히 제외하는 것 ──────────────────────────────────────────────────
--   1) 자식이 있는 파트
--      ParticleEmitter / PointLight / ProximityPrompt / SurfaceGui 등이 사라진다.
--   2) 공전 그룹 아래 파트
--      CollapseDebris / Crown / FloatRing / Wisps / AuroraFX 는 스크립트가
--      매 프레임 CFrame을 쓴다. 묶으면 연출이 깨진다.
--   3) 사용자 제작물
--      `ARVORE/TREE`, `이끼기` — 추가&수정.md `## 바꾸거나 업애면 안되는 것들`
--   4) 이미 Union된 것, Ground(이미 처리함)
--   5) 앵커되지 않은 파트 (물리로 움직이는 것)
--
-- ── 이름을 유지한다 ─────────────────────────────────────────────────────
--   추가&수정.md `# 수동 수정을 위해`가 "검색해서 찾기 편하도록"을 요구하므로
--   Union 결과에 원래 파트 이름을 그대로 준다. `WallCore`를 검색하면 계속 잡힌다.
--
-- ── 검증 ────────────────────────────────────────────────────────────────
--   Union 전후로 같은 좌표에 레이캐스트를 쏴 표면 높이를 비교한다.
--   차이가 나면 로그로 보고한다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "UWIDE::" 접두어.
-- 되돌리기: Ctrl+Z 또는 backup/pre-wide-union.rbxl

local GRID = 200
local MAX_PER_UNION = 40
local MIN_PER_UNION = 3
local TOLERANCE = 0.15
local SAMPLE_STRIDE = 6

local ANIMATED_GROUPS = {
	CollapseDebris = true,
	Crown = true,
	FloatRing = true,
	Wisps = true,
	AuroraFX = true,
}

local USER_CONTENT = {
	["ARVORE/TREE"] = true,
	["이끼기"] = true,
}

-- 이미 Union을 마친 폴더
local DONE_FOLDERS = {
	Ground = true,
}

local function log(fmt: string, ...): ()
	print("UWIDE:: " .. string.format(fmt, ...))
end

local world = workspace:FindFirstChild("World")
if not world then
	log("중단: Workspace.World 없음")
	return
end

local function rejectReason(part: Instance): string?
	if not part:IsA("BasePart") then
		return "notpart"
	end
	if part:IsA("UnionOperation") then
		return "alreadyunion"
	end
	if #part:GetChildren() > 0 then
		return "haschildren"
	end
	if not (part :: BasePart).Anchored then
		return "unanchored"
	end

	local ancestor: Instance? = part
	for _ = 1, 12 do
		ancestor = ancestor and ancestor.Parent
		if not ancestor or ancestor == workspace then
			break
		end
		if ANIMATED_GROUPS[ancestor.Name] then
			return "animated"
		end
		if USER_CONTENT[ancestor.Name] then
			return "usercontent"
		end
		if DONE_FOLDERS[ancestor.Name] then
			return "alreadydone"
		end
	end
	return nil
end

--=== 수집 ===--

type Bucket = { parts: { BasePart }, parent: Instance, name: string, material: Enum.Material }

local buckets: { [string]: Bucket } = {}
local rejected: { [string]: number } = {}
local target = 0

for _, descendant in ipairs(world:GetDescendants()) do
	local reason = rejectReason(descendant)
	if reason then
		rejected[reason] = (rejected[reason] or 0) + 1
	else
		local part = descendant :: BasePart
		target += 1
		-- 부모·이름·재질이 같고 공간적으로 가까운 것끼리 묶는다.
		-- 재질을 섞으면 Union이 한 재질로 통일돼 외형이 망가진다.
		local key = string.format(
			"%s|%s|%s|%d,%d,%d",
			tostring(part.Parent),
			part.Name,
			part.Material.Name,
			math.floor(part.Position.X / GRID),
			math.floor(part.Position.Y / GRID),
			math.floor(part.Position.Z / GRID)
		)
		local bucket = buckets[key]
		if not bucket then
			bucket = {
				parts = {},
				parent = part.Parent :: Instance,
				name = part.Name,
				material = part.Material,
			}
			buckets[key] = bucket
		end
		table.insert(bucket.parts, part)
	end
end

local rejectSummary: { string } = {}
for reason, count in rejected do
	table.insert(rejectSummary, reason .. "=" .. count)
end
log("대상 %d파트 / 제외 %s", target, table.concat(rejectSummary, ", "))

--=== 표면 높이 표본 (Union 전) ===--

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { world }

local samples: { Vector3 } = {}
local before: { number? } = {}

local counter = 0
for _, bucket in buckets do
	for _, part in bucket.parts do
		counter += 1
		if counter % SAMPLE_STRIDE == 0 then
			table.insert(samples, Vector3.new(part.Position.X, part.Position.Y + 600, part.Position.Z))
		end
	end
end

for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -1400, 0), params)
	before[i] = if hit then hit.Position.Y else nil
end

log("검증 표본 %d개", #samples)

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
				-- 원래 이름을 그대로 유지한다 (검색 편의, 추가&수정.md 요구사항)
				result.Name = bucket.name
				result.UsePartColor = false
				result.Anchored = true
				result.Material = bucket.material
				result.CanCollide = base.CanCollide
				result.Parent = bucket.parent

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

log("Union %d개 / %d파트 병합 / 실패 %d / %.1f초", unionCount, mergedCount, failures, os.clock() - startClock)

--=== 검증 ===--

params.FilterDescendantsInstances = { world }

local same, differ, missing, worst = 0, 0, 0, 0
for i, origin in samples do
	local hit = workspace:Raycast(origin, Vector3.new(0, -1400, 0), params)
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

log("표면 검증: 동일 %d / 다름 %d (최대 %.3f) / 미검출 %d", same, differ, worst, missing)

local remaining = 0
for _, descendant in ipairs(world:GetDescendants()) do
	if descendant:IsA("BasePart") then
		remaining += 1
	end
end
log("World 인스턴스: %d개", remaining)
