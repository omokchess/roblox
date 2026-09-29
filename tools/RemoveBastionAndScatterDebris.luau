--!strict
-- RemoveBastionAndScatterDebris.luau
--
-- 피드백 2건:
--   (1) "평원 보스룸 아예 없애고"
--   (2) "탑 물체 주변 부유물은 위치랑 기울기가 제각각이어야 해. 정렬된거 취소 해줘"
--
-- ── (1) 평원 보스방 제거 ────────────────────────────────────────────────
--   Workspace.World.BossArenas.Boss_인간대성채 (239파트, 이전 세션에서 신설한 것)
--   통째로 제거한다. 평원에는 보스방을 두지 않는다.
--
-- ── (2) 탑 부유물 재산란 ────────────────────────────────────────────────
--   Workspace.Town.Tower.CollapseDebris  (Belt1~4, 총 51파트)
--
--   이전에 "층계에 맞게 공전"시키려고 각 벨트를 **정원 위에 균등 배치 + 궤도
--   접선 방향 정렬**했는데, 너무 규칙적이라 인공적으로 보였다.
--   → 벨트별 층(고도)은 유지하되, 그 안에서 **위치와 기울기를 제각각**으로 흩는다.
--
--     각도  : 균등 배치에 ±0.55rad 지터를 줘 간격을 불규칙하게
--     반경  : 벨트 평균 반경의 0.70~1.30배
--     높이  : 벨트 평균 높이 ±55스터드
--     기울기: X/Y/Z 3축 전부 완전 랜덤 (접선 정렬 취소)
--
--   DebrisOrbit 스크립트는 파트들의 상대 배치를 그대로 유지한 채 통째로
--   공전시키므로, 여기서 준 랜덤 기울기는 공전 중에도 그대로 유지된다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "FIX2::" 접두어.
-- 되돌리기: Ctrl+Z

local function log(fmt: string, ...): ()
	print("FIX2:: " .. string.format(fmt, ...))
end

------------------------------------------------------------------
-- (1) 평원 보스방 제거
------------------------------------------------------------------
local arenas = workspace.World:FindFirstChild("BossArenas")
if arenas then
	local bastion = arenas:FindFirstChild("Boss_인간대성채")
	if bastion then
		local n = 0
		for _, d in ipairs(bastion:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		bastion:Destroy()
		log("평원 보스방 Boss_인간대성채 제거 (%d파트)", n)
	else
		log("평원 보스방 없음 — 이미 제거됨")
	end
else
	log("경고: BossArenas 없음")
end

------------------------------------------------------------------
-- (2) 탑 부유물 재산란
------------------------------------------------------------------
local tower = workspace.Town:FindFirstChild("Tower")
local debris = tower and tower:FindFirstChild("CollapseDebris")

if not debris then
	log("중단: CollapseDebris 없음")
	return
end

local base = Vector3.new(debris:GetAttribute("CX") or 0, debris:GetAttribute("CY") or 0, debris:GetAttribute("CZ") or 0)

local rng = Random.new(770720)
local total = 0

for _, belt in ipairs(debris:GetChildren()) do
	if belt:IsA("Model") then
		local parts: { BasePart } = {}
		for _, p in ipairs(belt:GetDescendants()) do
			if p:IsA("BasePart") then
				table.insert(parts, p)
			end
		end

		if #parts > 0 then
			-- 현재(정렬된) 상태에서 이 벨트의 평균 반경·높이를 읽어 층을 보존한다.
			local sumR, sumY = 0, 0
			for _, p in ipairs(parts) do
				local dx = p.Position.X - base.X
				local dz = p.Position.Z - base.Z
				sumR += math.sqrt(dx * dx + dz * dz)
				sumY += p.Position.Y
			end
			local avgR = sumR / #parts
			local avgY = sumY / #parts

			for index, p in ipairs(parts) do
				-- 균등 각도 + 지터 → 간격이 제각각
				local ang = (index - 1) / #parts * math.pi * 2 + rng:NextNumber(-0.55, 0.55)
				local rr = avgR * rng:NextNumber(0.70, 1.30)
				local yy = avgY + rng:NextNumber(-55, 55)

				-- 3축 완전 랜덤 기울기 (기존 접선 정렬 취소)
				p.CFrame = CFrame.new(base.X + math.cos(ang) * rr, yy, base.Z + math.sin(ang) * rr)
					* CFrame.Angles(
						rng:NextNumber(0, math.pi * 2),
						rng:NextNumber(0, math.pi * 2),
						rng:NextNumber(0, math.pi * 2)
					)
				total += 1
			end

			log(
				"%s: %d파트 산란 (평균 반경 %.0f ±30%%, 높이 %.0f ±55, 기울기 랜덤)",
				belt.Name,
				#parts,
				avgR,
				avgY
			)
		end
	end
end

log("완료: 탑 부유물 %d파트 재산란 — 정렬 취소됨", total)
