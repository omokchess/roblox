--!strict
-- GroundVolcanoPeakBlocks.luau
--
-- 피드백: "(화산 봉우리 교체) 이 때, 떠있는 블록이 생겼는지도 확인 해야 해."
--
-- ── 배경 ────────────────────────────────────────────────────────────────
--   ReplaceVolcanoPeak.luau로 새 봉우리를 지은 뒤 떠있는 블록 수를 줄여 왔다:
--     분할 r/14, 셸 두께 34~62 → 664개 중 217개 부유
--     분할 r/6  (밀도 ↑)      → 1536개 중 418개
--     반경 노이즈를 각도 기준으로 (층 의존 제거) → 424개  (효과 없음)
--     셸 두께 72~108 (Δr 12~18을 확실히 덮음)  → **48개**
--
--   남은 48개는 주로 최하단 링이 산기슭 지형에 닿지 않는 경우다.
--
-- ── 이 스크립트가 하는 일 ───────────────────────────────────────────────
--   Workspace.World.VolcanoPeak 안의 PeakBlock / PeakSpur 중
--   아래 SUPPORT_RANGE 안에 지지물이 없는 것을 찾아서:
--
--     (a) 더 아래(DEEP_RANGE)에 지면·구조물이 있으면
--         → 블록의 **높이를 늘려 아래로 뻗어** 그 지점에 닿게 한다 (실루엣 유지)
--     (b) 그마저 없으면 완전히 고립된 조각이므로 제거한다
--
--   높이를 늘리는 쪽을 기본으로 삼는 이유: 최하단 링을 그냥 내리면
--   산기슭 실루엣이 주저앉기 때문이다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "GROUND::" 접두어.

local SUPPORT_RANGE = 140 -- 이 안에 지지물이 있으면 정상으로 본다
local DEEP_RANGE = 900 -- 여기까지 내려다보며 닿을 곳을 찾는다
local MAX_STRETCH = 700 -- 한 블록을 이 이상 늘리지는 않는다

local function log(fmt: string, ...): ()
	print("GROUND:: " .. string.format(fmt, ...))
end

local peak = workspace.World:FindFirstChild("VolcanoPeak")
if not peak then
	log("중단: VolcanoPeak 없음")
	return
end

local targets: { BasePart } = {}
for _, part in ipairs(peak:GetChildren()) do
	if part:IsA("BasePart") and (part.Name == "PeakBlock" or part.Name == "PeakSpur") then
		table.insert(targets, part)
	end
end

log("검사 대상 %d개", #targets)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local stretched, removed, ok = 0, 0, 0
local lowest, highest = 1e9, -1e9

for _, part in ipairs(targets) do
	params.FilterDescendantsInstances = { part }
	local bottom = part.Position.Y - part.Size.Y / 2
	local origin = Vector3.new(part.Position.X, bottom - 0.2, part.Position.Z)

	local near = workspace:Raycast(origin, Vector3.new(0, -SUPPORT_RANGE, 0), params)
	if near then
		ok += 1
	else
		-- 떠 있다. 더 깊이 내려다본다.
		local deep = workspace:Raycast(origin, Vector3.new(0, -DEEP_RANGE, 0), params)
		if deep then
			local gap = origin.Y - deep.Position.Y
			if gap <= MAX_STRETCH then
				-- 아래로 뻗어서 닿게 한다: 높이를 gap만큼 늘리고 중심을 gap/2 내린다.
				lowest = math.min(lowest, part.Position.Y)
				highest = math.max(highest, part.Position.Y)
				part.Size = Vector3.new(part.Size.X, part.Size.Y + gap, part.Size.Z)
				part.CFrame = part.CFrame - Vector3.new(0, gap / 2, 0)
				stretched += 1
			else
				part:Destroy()
				removed += 1
			end
		else
			part:Destroy()
			removed += 1
		end
	end
end

log("정상 %d / 아래로 연장 %d / 고립 제거 %d", ok, stretched, removed)
if stretched > 0 then
	log("연장된 블록의 원래 높이 범위 Y %.0f ~ %.0f", lowest, highest)
end

------------------------------------------------------------------
-- 재검사
------------------------------------------------------------------
local still = 0
for _, part in ipairs(peak:GetChildren()) do
	if part:IsA("BasePart") and (part.Name == "PeakBlock" or part.Name == "PeakSpur") then
		params.FilterDescendantsInstances = { part }
		local origin = Vector3.new(part.Position.X, part.Position.Y - part.Size.Y / 2 - 0.2, part.Position.Z)
		if not workspace:Raycast(origin, Vector3.new(0, -SUPPORT_RANGE, 0), params) then
			still += 1
		end
	end
end

log("재검사 결과 떠있는 블록: %d개", still)
