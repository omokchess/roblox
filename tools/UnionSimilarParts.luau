--!strict
-- UnionSimilarParts.luau
--
-- 피드백: 추가&수정.md `# 수동 수정을 위해` — "비슷한 파트끼리는 Union을 할 것."
--
-- ── 목적 ────────────────────────────────────────────────────────────────
--   같은 종류의 장식 파트를 묶어 탐색기 항목 수를 줄이고 렌더 부담을 낮춘다.
--
-- ── 안전 기준 (중요) ────────────────────────────────────────────────────
--   Union은 되돌리기 어렵고 충돌 판정을 바꾼다. 그래서 아래를 **전부** 만족하는
--   파트만 대상으로 한다.
--
--     1) CanCollide = false
--        Union하면 CollisionFidelity가 근사 형상으로 바뀐다. 벽·바닥처럼 밟거나
--        막는 파트를 묶으면 끼임·추락이 생긴다. 실측 결과 World 43,676개 중
--        37,875개가 CanCollide=true라 전부 제외된다.
--
--     2) 자식이 없음
--        ParticleEmitter / PointLight / ProximityPrompt를 가진 파트를 묶으면
--        그 자식들이 사라진다. (예: `Snow Particles`, `TunnelLamp`)
--
--     3) 공전 그룹 밑이 아님
--        CollapseDebris / Crown / FloatRing / Wisps / AuroraFX 아래 파트는
--        스크립트가 매 프레임 CFrame을 쓴다. 묶으면 연출이 깨진다.
--
--     4) 사용자 제작물이 아님
--        `ARVORE/TREE`, `이끼기`는 사용자가 직접 추가한 것이라 손대지 않는다.
--        (추가&수정.md `## 바꾸거나 업애면 안되는 것들`)
--
-- ── 묶는 단위 ───────────────────────────────────────────────────────────
--   (부모, 이름, 재질, 공간격자) 로 버킷을 만든다.
--
--   공간격자(GRID)를 쓰는 이유: 숲 전역에 흩어진 BigLeaf 3,405개를 하나로 묶으면
--   경계 상자가 맵 전체를 덮어 컬링·스트리밍이 무력해진다. 220스터드 격자로 끊어
--   국소적인 덩어리만 만든다.
--
--   한 Union당 최대 MAX_PER_UNION개로 자른다. 너무 크면 삼각형 한도에 걸린다.
--
--   색은 UsePartColor=false로 두면 원본 파트 색이 그대로 구워진다.
--
-- ── 실행 ────────────────────────────────────────────────────────────────
--   DRY_RUN = true  → 계획만 출력, 아무것도 바꾸지 않는다
--   DRY_RUN = false → 실제로 Union한다
--
--   결과는 "UNION::" 접두어로 출력. 되돌리기는 Ctrl+Z.

local DRY_RUN = true

local GRID = 220 -- 공간 격자 한 변(스터드)
local MAX_PER_UNION = 40 -- Union 하나에 넣을 최대 파트 수
local MIN_PER_UNION = 4 -- 이보다 적으면 묶지 않는다

-- 스크립트가 매 프레임 움직이는 그룹. 이 밑은 건드리지 않는다.
local ANIMATED_GROUPS = {
	CollapseDebris = true,
	Crown = true,
	FloatRing = true,
	Wisps = true,
	AuroraFX = true,
}

-- 사용자가 직접 만든 것. 수정 금지.
local USER_CONTENT = {
	["ARVORE/TREE"] = true,
	["이끼기"] = true,
}

local function log(fmt: string, ...): ()
	print("UNION:: " .. string.format(fmt, ...))
end

-- 위 4가지 안전 기준을 검사한다. 통과하면 nil, 걸리면 사유 문자열.
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
	if part.CanCollide then
		return "collides"
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
	end

	return nil
end

--=== 수집 ===--

type Bucket = { parts: { BasePart }, parent: Instance, name: string }

local buckets: { [string]: Bucket } = {}
local rejected: { [string]: number } = {}
local safeCount = 0

for _, descendant in ipairs(workspace.World:GetDescendants()) do
	local reason = rejectReason(descendant)
	if reason then
		rejected[reason] = (rejected[reason] or 0) + 1
	elseif descendant:IsA("BasePart") then
		safeCount += 1
		local position = descendant.Position
		-- (부모, 이름, 재질, 격자칸) 을 하나의 버킷 키로 삼는다.
		local key = string.format(
			"%s|%s|%s|%d,%d,%d",
			tostring(descendant.Parent),
			descendant.Name,
			descendant.Material.Name,
			math.floor(position.X / GRID),
			math.floor(position.Y / GRID),
			math.floor(position.Z / GRID)
		)
		local bucket = buckets[key]
		if not bucket then
			bucket = { parts = {}, parent = descendant.Parent :: Instance, name = descendant.Name }
			buckets[key] = bucket
		end
		table.insert(bucket.parts, descendant)
	end
end

local rejectSummary: { string } = {}
for reason, count in rejected do
	table.insert(rejectSummary, reason .. "=" .. count)
end
log("대상 파트 %d개 / 제외 %s", safeCount, table.concat(rejectSummary, ", "))

--=== 실행 ===--

local plannedUnions = 0
local plannedParts = 0
local failures = 0

for _, bucket in buckets do
	local parts = bucket.parts
	if #parts >= MIN_PER_UNION then
		-- MAX_PER_UNION 단위로 잘라 여러 Union으로 나눈다.
		local index = 1
		while index <= #parts do
			local chunk: { BasePart } = {}
			for offset = 0, MAX_PER_UNION - 1 do
				local part = parts[index + offset]
				if not part then
					break
				end
				table.insert(chunk, part)
			end
			index += #chunk

			if #chunk >= MIN_PER_UNION then
				plannedUnions += 1
				plannedParts += #chunk

				if not DRY_RUN then
					local base = chunk[1]
					local others: { BasePart } = {}
					for i = 2, #chunk do
						table.insert(others, chunk[i])
					end

					local ok, result = pcall(function()
						return base:UnionAsync(others)
					end)

					if ok and result then
						result.Name = bucket.name .. "_Union"
						-- 원본 파트들의 색을 그대로 유지한다.
						result.UsePartColor = false
						result.Anchored = true
						result.CanCollide = false
						result.Parent = bucket.parent
						base:Destroy()
						for _, other in others do
							other:Destroy()
						end
					else
						failures += 1
					end
				end
			end
		end
	end
end

if DRY_RUN then
	log(
		"[계획] Union %d개로 파트 %d개를 묶는다 (격자 %d, 최대 %d/개)",
		plannedUnions,
		plannedParts,
		GRID,
		MAX_PER_UNION
	)
	log("[계획] 실제 실행하려면 DRY_RUN = false 로 바꿀 것. 아무것도 바꾸지 않았다.")
else
	log("Union %d개 생성, 파트 %d개 병합, 실패 %d건", plannedUnions, plannedParts, failures)

	local remaining = 0
	for _, descendant in ipairs(workspace.World:GetDescendants()) do
		if descendant:IsA("BasePart") then
			remaining += 1
		end
	end
	log("검증: World 파트 수 %d", remaining)
end
