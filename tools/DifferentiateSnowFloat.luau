--!strict
-- DifferentiateSnowFloat.luau
--
-- 피드백: "오염지대랑 설원 지역의 구조가 비슷한데, 설원 지역의 부유물 구조를 다르게 해줘."
--
-- ── 왜 비슷했나 ──────────────────────────────────────────────────────────
--   두 아레나의 부유물이 같은 틀로 만들어져 있었다.
--     설원 Boss_빙결왕좌.Hero.FloatRing : Belt1(84) / Belt2(108) / Belt3(30)
--     오염 Boss_부패의심장.Hero.FloatRing: Belt1(72) / Belt2(96)  / Belt3(27)
--   둘 다 **수평 동심 벨트 3겹**이고 파트 구성(FloatStone/FloatChip/FloatCore)도 같다.
--
-- ── 바꾸는 방향 ──────────────────────────────────────────────────────────
--   오염 = 수평 동심 벨트 (그대로 둔다)
--   설원 = **서로 교차하는 경사 궤도면 3개** (혼천의armillary처럼)
--
--   벨트 안의 돌·파편·발광코어는 서로 붙어 있어야 하므로 개별 이동은 하지 않는다.
--   대신 **벨트 전체를 아레나 중심 기준 강체 회전**시켜 궤도면만 기울인다.
--   → 내부 상대 배치는 100% 보존된다.
--
--   FloatSpin 스크립트도 기울어진 평면 안에서 공전하도록 갱신한다.
--   (기존: 항상 월드 Y축 회전 → 변경: 벨트별 TiltX만큼 기운 축을 중심으로 회전)
--
-- ── 대상 ────────────────────────────────────────────────────────────────
--   Workspace.World.BossArenas.Boss_빙결왕좌.Hero.FloatRing
--     중심 속성 CX=0, CY=164, CZ=-2150
--     Belt1 → 28도, Belt2 → -42도, Belt3 → 68도 로 기울인다
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "SNOW::" 접두어.
-- 주의: 두 번 실행하면 각도가 누적되므로 1회만 실행할 것.
--       (재실행 필요 시 Ctrl+Z 후 다시 실행)

local TILTS: { [string]: number } = {
	Belt1 = 28,
	Belt2 = -42,
	Belt3 = 68,
}

local function log(fmt: string, ...): ()
	print("SNOW:: " .. string.format(fmt, ...))
end

local arena = workspace.World.BossArenas:FindFirstChild("Boss_빙결왕좌")
local ring = arena and arena:FindFirstChild("Hero") and arena.Hero:FindFirstChild("FloatRing")

if not ring then
	log("중단: 설원 FloatRing을 찾지 못했다")
	return
end

-- 이미 기울였는지 확인 (중복 실행 방지)
for name in pairs(TILTS) do
	local belt = ring:FindFirstChild(name)
	if belt and belt:GetAttribute("TiltX") ~= nil then
		log("중단: 이미 TiltX가 설정돼 있다 (%s). 중복 실행 방지.", name)
		return
	end
end

local base = Vector3.new(ring:GetAttribute("CX") or 0, ring:GetAttribute("CY") or 0, ring:GetAttribute("CZ") or 0)
log("아레나 중심 (%.0f, %.0f, %.0f)", base.X, base.Y, base.Z)

local total = 0

for name, degrees in pairs(TILTS) do
	local belt = ring:FindFirstChild(name)
	if belt then
		-- 중심을 원점으로 옮겨 회전한 뒤 되돌리는 강체 변환
		local pivot = CFrame.new(base)
		local transform = pivot * CFrame.Angles(math.rad(degrees), 0, 0) * pivot:Inverse()

		local moved = 0
		for _, part in ipairs(belt:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CFrame = transform * part.CFrame
				moved += 1
			end
		end

		belt:SetAttribute("TiltX", degrees)
		total += moved
		log("%s: %d파트를 %d도 기울임", name, moved, degrees)
	else
		log("경고: %s 없음", name)
	end
end

------------------------------------------------------------------
-- FloatSpin 스크립트를 경사축 대응 버전으로 교체
------------------------------------------------------------------
local spin = ring:FindFirstChild("FloatSpin")
if spin and spin:IsA("BaseScript") then
	spin.Source = table.concat({
		"-- 설원 부유물: 벨트별 TiltX만큼 기운 궤도면 안에서 공전한다.",
		"-- (오염지대의 수평 동심 벨트와 구조를 구분하기 위함)",
		'local RS = game:GetService("RunService")',
		"local m = script.Parent",
		'local base = CFrame.new(Vector3.new(m:GetAttribute("CX") or 0, m:GetAttribute("CY") or 0, m:GetAttribute("CZ") or 0))',
		"local grp = {}",
		"for _, g in ipairs(m:GetChildren()) do",
		'	if g:IsA("Model") then',
		'		local tilt = CFrame.Angles(math.rad(g:GetAttribute("TiltX") or 0), 0, 0)',
		"		local frame = base * tilt",
		"		local inv = frame:Inverse()",
		"		local ps = {}",
		"		for _, p in ipairs(g:GetDescendants()) do",
		'			if p:IsA("BasePart") then table.insert(ps, { p, inv * p.CFrame }) end',
		"		end",
		'		table.insert(grp, { s = g:GetAttribute("Speed") or 0.15, p = ps, f = frame })',
		"	end",
		"end",
		"local t = 0",
		"RS.Heartbeat:Connect(function(dt)",
		"	t = t + dt",
		"	for _, g in ipairs(grp) do",
		"		local r = CFrame.Angles(0, t * g.s, 0)",
		"		for _, e in ipairs(g.p) do",
		"			e[1].CFrame = g.f * r * e[2]",
		"		end",
		"	end",
		"end)",
	}, "\n")
	log("FloatSpin 스크립트를 경사축 대응 버전으로 교체했다")
else
	log("경고: FloatSpin 스크립트를 찾지 못했다")
end

log("완료: 총 %d파트, 설원 부유물이 교차 경사 궤도 3면이 됐다", total)
