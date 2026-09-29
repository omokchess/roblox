--!strict
-- FixSteleCaps.luau
--
-- 피드백: "숲 보스룸 비석을 회전 하면서 비석의 모자가 공중에 떠있어.
--          이 모자가 다시 기둥에 붙게 해줘."
--
-- ── 위치 ────────────────────────────────────────────────────────────────
--   Workspace.World.BossArenas.Boss_고대수신전  (숲 보스룸 = 고대수 신전)
--
-- ── 비석 1기의 구성 (아래→위) ───────────────────────────────────────────
--   SteleBase    받침       size≈(76,14,55) / (64,14,46) / (52,14,37)
--   SteleBreak   부러진 기둥 size≈(44,26,30)   ← 기둥의 실제 꼭대기
--   SteleCap     모자        size≈(54,16,34)   ← 떠 있던 것
--   SteleFinial  첨두        size≈(30,22,22)   ← 모자 위에 얹힘
--   SteleOrb     구슬        size≈(17,17,17)   ← 첨두 위에 얹힘
--   SteleMoss / SteleRubble  주변 장식 (건드리지 않음)
--
-- ── 문제 ────────────────────────────────────────────────────────────────
-- 아레나를 탑 방향으로 회전시키는 과정에서 기둥(SteleBreak)만 내려앉고
-- 모자·첨두·구슬은 옛 높이에 남았다. 실측 결과 약 26스터드 떠 있었다.
--   예) X=-1690, Z=-92
--       SteleBreak top = 175.4
--       SteleCap  bot  = 201.6   → 26.2스터드 공중
--       SteleFinial bot= 217.6   (모자 위에 정상 적층)
--       SteleOrb  bot  = 239.6   (첨두 위에 정상 적층)
--
-- ── 해법 ────────────────────────────────────────────────────────────────
-- 모자/첨두/구슬은 서로 붙어 있으므로 **상대 간격을 유지한 채 통째로** 내린다.
-- 각 SteleCap에서 아래로 레이캐스트해 기둥 꼭대기를 찾고, 그 차이만큼 하강.
-- 같은 비석에 속하는 부품은 수평거리(XZ) GROUP_RADIUS 안에서 묶는다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "STELE::" 접두어.
-- 되돌리기: Ctrl+Z

local GROUP_RADIUS = 40 -- 같은 비석으로 묶을 수평 반경(스터드)
local SNAP_EPSILON = 0.05 -- 이 이하로 떠 있으면 이미 붙은 것으로 본다

local function log(fmt: string, ...): ()
	print("STELE:: " .. string.format(fmt, ...))
end

local arena = workspace.World.BossArenas:FindFirstChild("Boss_고대수신전")
if not arena then
	log("중단: Boss_고대수신전을 찾지 못했다")
	return
end

-- 비석 부품 수집
local caps: { BasePart } = {}
local riders: { BasePart } = {} -- 모자와 함께 움직여야 하는 것들

for _, part in ipairs(arena:GetDescendants()) do
	if part:IsA("BasePart") then
		if part.Name == "SteleCap" then
			table.insert(caps, part)
		elseif part.Name == "SteleFinial" or part.Name == "SteleOrb" then
			table.insert(riders, part)
		end
	end
end

log("SteleCap %d개, 동반 부품(Finial/Orb) %d개", #caps, #riders)

local fixed, already = 0, 0

for _, cap in ipairs(caps) do
	-- 이 모자에 딸린 첨두·구슬을 수평거리로 묶는다.
	local group: { BasePart } = { cap }
	for _, rider in ipairs(riders) do
		local dx = rider.Position.X - cap.Position.X
		local dz = rider.Position.Z - cap.Position.Z
		if math.sqrt(dx * dx + dz * dz) <= GROUP_RADIUS then
			table.insert(group, rider)
		end
	end

	-- 그룹 전체를 제외하고 아래로 쏴서 기둥 꼭대기를 찾는다.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = group

	local origin = cap.Position - Vector3.new(0, cap.Size.Y / 2 + 0.05, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)

	if hit then
		local gap = origin.Y - hit.Position.Y
		if gap > SNAP_EPSILON then
			-- 상대 간격 유지한 채 그룹 통째로 하강
			for _, part in ipairs(group) do
				part.CFrame = part.CFrame - Vector3.new(0, gap, 0)
			end
			fixed += 1
			log(
				"모자@(%.0f,%.0f) %.1f스터드 하강, 동반 %d개 (착지: %s)",
				cap.Position.X,
				cap.Position.Z,
				gap,
				#group - 1,
				hit.Instance.Name
			)
		else
			already += 1
		end
	else
		log("경고: 모자@(%.0f,%.0f) 아래에 기둥이 없다 — 건너뜀", cap.Position.X, cap.Position.Z)
	end
end

log("완료: %d기 접합, %d기는 이미 붙어 있었음", fixed, already)
