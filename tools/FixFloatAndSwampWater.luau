--!strict
-- FixFloatAndSwampWater.luau
--
-- 피드백 2건 처리:
--   (1) "늪의 물이 유리 재질인 것 같은데, 이거 재질도 바꿔줘"
--   (2) "전체적인 부유물의 속도를 약간 줄이고, 전부 다 한 방향으로만 돌지 않게 해줘"
--
-- ── 대상 위치 ────────────────────────────────────────────────────────────
--   늪 물     : Workspace.World.SwampWater (SwampWater 파트 37개)
--   부유물 5종 (각 Model의 Speed 속성으로 공전 속도 제어):
--     Workspace.Town.Tower.Crown            (탑 꼭대기 왕관: Ring1~3, Shards)
--     Workspace.Town.Tower.CollapseDebris   (탑 아래 잔해 벨트: Belt1~4)
--     Workspace.World.BossArenas.Boss_빙결왕좌.Hero.FloatRing   (설원: Belt1~3)
--     Workspace.World.BossArenas.Boss_부패의심장.Hero.FloatRing (오염: Belt1~3)
--     Workspace.World.BossArenas.Boss_고대수신전.Hero.Wisps     (숲: Halo1~2)
--
-- ── (1) 늪 물 ───────────────────────────────────────────────────────────
-- 기존: SmoothPlastic + Transparency 0.42 → 매끈하고 투명해서 유리처럼 보였다.
-- 변경: Material=Water, 탁한 이끼색, Transparency 0.30, Reflectance 0
--       늪이므로 맑은 물이 아니라 탁하게 간다.
--
-- ── (2) 부유물 ──────────────────────────────────────────────────────────
-- 속도: 기존 |Speed|에 SPEED_SCALE(0.65)을 곱해 약간 느리게 한다.
-- 방향: 그룹 안에서 인덱스 홀짝으로 부호를 강제 교차시켜, 한 방향으로만
--       돌지 않게 만든다. (기존에도 일부 섞여 있었으나 규칙이 없었다)
--
-- 실행 방법: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "FIX::" 접두어로 출력.
-- 되돌리기: Ctrl+Z 또는 backup/pre-dedupe-2026-07-20.rbxl

local SPEED_SCALE = 0.65

local function log(fmt: string, ...): ()
	print("FIX:: " .. string.format(fmt, ...))
end

------------------------------------------------------------------
-- (1) 늪 물 재질
------------------------------------------------------------------
local swamp = workspace.World:FindFirstChild("SwampWater")
local swampCount = 0

if swamp then
	for _, part in ipairs(swamp:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.Water
			part.Color = Color3.fromRGB(58, 82, 62) -- 탁한 이끼 녹색
			part.Transparency = 0.3
			part.Reflectance = 0
			swampCount += 1
		end
	end
	log("늪 물 %d개: SmoothPlastic/T0.42 → Water/T0.30 (탁한 녹색)", swampCount)
else
	log("경고: SwampWater를 찾지 못했다")
end

------------------------------------------------------------------
-- (2) 부유물 속도 · 방향
------------------------------------------------------------------
-- 공전 그룹이 들어있는 컨테이너들. 각 컨테이너의 자식 Model이 벨트 1개다.
local containers: { { tag: string, node: Instance? } } = {
	{ tag = "CROWN", node = workspace.Town.Tower:FindFirstChild("Crown") },
	{ tag = "DEBRIS", node = workspace.Town.Tower:FindFirstChild("CollapseDebris") },
	{ tag = "ICE", node = workspace.World.BossArenas["Boss_빙결왕좌"].Hero:FindFirstChild("FloatRing") },
	{ tag = "TOX", node = workspace.World.BossArenas["Boss_부패의심장"].Hero:FindFirstChild("FloatRing") },
	{ tag = "WISP", node = workspace.World.BossArenas["Boss_고대수신전"].Hero:FindFirstChild("Wisps") },
}

local changed = 0

for _, entry in ipairs(containers) do
	local node = entry.node
	if not node then
		log("경고: %s 컨테이너 없음", entry.tag)
		continue
	end

	-- 이름순으로 정렬해야 실행할 때마다 같은 부호가 나온다(재실행 안정성).
	local belts: { Model } = {}
	for _, child in ipairs(node:GetChildren()) do
		if child:IsA("Model") then
			table.insert(belts, child)
		end
	end
	table.sort(belts, function(a, b)
		return a.Name < b.Name
	end)

	for index, belt in ipairs(belts) do
		local old = belt:GetAttribute("Speed")
		if typeof(old) == "number" then
			-- 크기는 줄이고, 부호는 홀짝으로 교차시킨다.
			local magnitude = math.abs(old) * SPEED_SCALE
			local sign = (index % 2 == 1) and 1 or -1
			local new = magnitude * sign

			belt:SetAttribute("Speed", new)
			changed += 1
			log("%s/%s  %.4f → %.4f", entry.tag, belt.Name, old, new)
		end
	end
end

log("부유물 벨트 %d개 속도·방향 조정 완료 (배율 %.2f)", changed, SPEED_SCALE)
