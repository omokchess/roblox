--!strict
-- BuildPlainsBossArena.luau
--
-- 피드백:
--   "평원에도 보스방 초대형 구조물을 만들어줘. 근데 콜로세움이면 안 돼."
--   "이 평원의 보스방은 프리미야의 보스방이 아니라, 인간들이 만든 보스방이야."
--
-- ── 컨셉 ────────────────────────────────────────────────────────────────
--   세계관상 인간은 신을 치기 위해 대륙 중앙에 탑을 내렸다.
--   평원 보스방은 그 인간 연합이 세운 **대성채(Grand Bastion)** 로 잡았다.
--
--   신들의 보스방이 원형·유기적 형태(투기장/신전/왕좌)인 것과 대비되도록
--   **철저히 각진 군사 건축**으로 만든다. 원형 요소를 일절 쓰지 않아
--   "콜로세움이면 안 된다"는 조건을 형태 차원에서 만족시킨다.
--
--     - 정사각 성벽 + 네 모서리 각면 능보(bastion)
--     - 탑 방향으로 난 성문과 게이트하우스
--     - 내부 직사각 대전당(great hall) + 부벽(buttress) + 박공지붕
--     - 안쪽 끝 단상(dais) — 인간 챔피언의 자리
--
-- ── 배치 ────────────────────────────────────────────────────────────────
--   평원 섹터 각도 225도. 다른 아레나가 탑에서 1860~2210 거리에 있으므로
--   같은 반경대인 2050에 맞춰 중심을 (-1449, ?, -1449)로 잡는다.
--   Y는 실행 시 지면을 레이캐스트해 자동으로 얹는다.
--
--   성문은 항상 **탑(원점) 방향**을 향하도록 전체를 yaw 회전시킨다.
--   (다른 아레나도 입구가 탑을 향하도록 정렬돼 있다)
--
-- ── 결과물 위치 ─────────────────────────────────────────────────────────
--   Workspace.World.BossArenas.Boss_인간대성채
--     Platform   기단
--     Curtain    성벽 (CurtainWall / Merlon)
--     Bastion1~4 모서리 능보 (BastionWall / BastionCap)
--     Gatehouse  성문 (GateTower / GateArch / GateBanner)
--     Hall       대전당 (HallWall / Buttress / RoofSlab / HallPillar)
--     Dais       단상 (DaisStep / DaisThrone / Brazier)
--     BossSeal   상호작용 (ProximityPrompt)
--
--   재실행하면 기존 Boss_인간대성채를 지우고 다시 짓는다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "BASTION::" 접두어.

local ARENA_ANGLE_DEG = 225 -- 평원 섹터
local ARENA_DIST = 2050 -- 탑에서의 거리
local WALL_HALF = 430 -- 성벽 반변 (정사각 860x860)
local WALL_H = 130 -- 성벽 높이
local WALL_T = 38 -- 성벽 두께
local BASTION = 150 -- 모서리 능보 한 변
local BASTION_H = 215
local HALL_HX, HALL_HZ = 215, 155 -- 대전당 반치수
local HALL_H = 225
local GATE_W = 170 -- 성문 폭

local function log(fmt: string, ...): ()
	print("BASTION:: " .. string.format(fmt, ...))
end

local COLORS = {
	stone = Color3.fromRGB(146, 142, 132),
	stoneDark = Color3.fromRGB(104, 101, 95),
	stoneLight = Color3.fromRGB(178, 173, 161),
	roof = Color3.fromRGB(78, 62, 58),
	banner = Color3.fromRGB(122, 40, 44),
	gold = Color3.fromRGB(206, 168, 92),
	fire = Color3.fromRGB(255, 146, 58),
}

------------------------------------------------------------------
-- 위치 계산
------------------------------------------------------------------
local rad = math.rad(ARENA_ANGLE_DEG)
local cx = math.cos(rad) * ARENA_DIST
local cz = math.sin(rad) * ARENA_DIST

-- 지면 높이 탐색
local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.FilterDescendantsInstances = {}

local groundY = 40
local probe = workspace:Raycast(Vector3.new(cx, 800, cz), Vector3.new(0, -1600, 0), probeParams)
if probe then
	groundY = probe.Position.Y
end

-- 성문이 탑(원점)을 보도록 yaw 회전
local toTower = Vector3.new(-cx, 0, -cz).Unit
local yaw = -math.atan2(toTower.Z, toTower.X)
local BASE = CFrame.new(Vector3.new(cx, groundY, cz)) * CFrame.Angles(0, yaw, 0)

log("중심 (%.0f, %.0f, %.0f) / 지면 %.1f / yaw %.1f도", cx, groundY, cz, groundY, math.deg(yaw))

------------------------------------------------------------------
-- 빌더
------------------------------------------------------------------
local arenas = workspace.World:FindFirstChild("BossArenas")
if not arenas then
	log("중단: BossArenas 없음")
	return
end

local old = arenas:FindFirstChild("Boss_인간대성채")
if old then
	old:Destroy()
end

local root = Instance.new("Model")
root.Name = "Boss_인간대성채"
root.Parent = arenas

local count = 0

local function group(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

-- 로컬 좌표(성문이 +X)로 파트를 놓는다.
local function put(
	parent: Instance,
	name: string,
	size: Vector3,
	lx: number,
	ly: number,
	lz: number,
	color: Color3,
	material: Enum.Material?,
	yawLocal: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = BASE * CFrame.new(lx, ly, lz) * CFrame.Angles(0, yawLocal or 0, 0)
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	count += 1
	return p
end

------------------------------------------------------------------
-- 1) 기단
------------------------------------------------------------------
local platform = group("Platform")
put(platform, "PlatformSlab", Vector3.new(WALL_HALF * 2 + 90, 26, WALL_HALF * 2 + 90), 0, 13, 0, COLORS.stoneDark)
put(platform, "PlatformTop", Vector3.new(WALL_HALF * 2 + 40, 8, WALL_HALF * 2 + 40), 0, 30, 0, COLORS.stone)

------------------------------------------------------------------
-- 2) 성벽 (정사각, 탑 방향 면에는 성문 구멍)
------------------------------------------------------------------
local curtain = group("Curtain")
local SEG = 40

-- 한 변을 세그먼트로 깔되, 성문 폭 구간은 건너뛴다.
local function wallRun(fixedAxis: string, sign: number, hasGate: boolean)
	local steps = math.floor(WALL_HALF * 2 / SEG)
	for i = 0, steps - 1 do
		local t = -WALL_HALF + SEG * (i + 0.5)
		-- 성문 구간 제외
		if not (hasGate and math.abs(t) < GATE_W / 2) then
			local lx, lz
			if fixedAxis == "x" then
				lx, lz = sign * WALL_HALF, t
			else
				lx, lz = t, sign * WALL_HALF
			end
			local sx = (fixedAxis == "x") and WALL_T or SEG
			local sz = (fixedAxis == "x") and SEG or WALL_T
			put(curtain, "CurtainWall", Vector3.new(sx, WALL_H, sz), lx, 34 + WALL_H / 2, lz, COLORS.stone)
			-- 성가퀴
			put(curtain, "Merlon", Vector3.new(sx * 0.8, 20, sz * 0.55), lx, 34 + WALL_H + 10, lz, COLORS.stoneLight)
		end
	end
end

wallRun("x", 1, true) -- 탑 방향 면 (성문)
wallRun("x", -1, false)
wallRun("z", 1, false)
wallRun("z", -1, false)

-- 성문 상단 인방
put(curtain, "GateLintel", Vector3.new(WALL_T + 8, 34, GATE_W), WALL_HALF, 34 + 96 + 17, 0, COLORS.stoneLight)

------------------------------------------------------------------
-- 3) 모서리 능보 (각면 — 원형 금지)
------------------------------------------------------------------
local corners = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
for index, c in ipairs(corners) do
	local b = group("Bastion" .. index)
	local bx = c[1] * WALL_HALF
	local bz = c[2] * WALL_HALF
	put(b, "BastionWall", Vector3.new(BASTION, BASTION_H, BASTION), bx, 34 + BASTION_H / 2, bz, COLORS.stoneDark)
	put(b, "BastionCap", Vector3.new(BASTION + 24, 16, BASTION + 24), bx, 34 + BASTION_H + 8, bz, COLORS.stoneLight)
	-- 각 모서리에 성가퀴 4개
	for _, m in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		put(
			b,
			"BastionMerlon",
			Vector3.new(34, 24, 34),
			bx + m[1] * (BASTION / 2 - 6),
			34 + BASTION_H + 28,
			bz + m[2] * (BASTION / 2 - 6),
			COLORS.stoneLight
		)
	end
	put(b, "BastionBrazier", Vector3.new(20, 20, 20), bx, 34 + BASTION_H + 30, bz, COLORS.fire, Enum.Material.Neon)
end

------------------------------------------------------------------
-- 4) 게이트하우스 (탑 방향)
------------------------------------------------------------------
local gate = group("Gatehouse")
for _, s in ipairs({ 1, -1 }) do
	local gz = s * (GATE_W / 2 + 46)
	put(gate, "GateTower", Vector3.new(92, 250, 92), WALL_HALF, 34 + 125, gz, COLORS.stoneDark)
	put(gate, "GateTowerCap", Vector3.new(112, 18, 112), WALL_HALF, 34 + 250 + 9, gz, COLORS.stoneLight)
	put(gate, "GateBanner", Vector3.new(4, 92, 40), WALL_HALF + 50, 34 + 150, gz, COLORS.banner, Enum.Material.Fabric)
end
-- 아치 상부 계단식 (각진 아치)
for i = 0, 3 do
	local w = GATE_W - i * 30
	if w > 20 then
		put(gate, "GateArch", Vector3.new(WALL_T + 14, 18, w), WALL_HALF, 34 + 96 + 34 + i * 18, 0, COLORS.stoneLight)
	end
end
put(gate, "GateRoad", Vector3.new(150, 4, GATE_W), WALL_HALF + 96, 36, 0, COLORS.stoneDark)

------------------------------------------------------------------
-- 5) 내부 대전당
------------------------------------------------------------------
local hall = group("Hall")
put(hall, "HallFloor", Vector3.new(HALL_HX * 2 + 60, 6, HALL_HZ * 2 + 60), -40, 37, 0, COLORS.stoneLight)

-- 벽 4면 (탑 방향은 입구로 비움)
put(hall, "HallWall", Vector3.new(14, HALL_H, HALL_HZ * 2), -40 - HALL_HX, 40 + HALL_H / 2, 0, COLORS.stone)
put(hall, "HallWall", Vector3.new(HALL_HX * 2, HALL_H, 14), -40, 40 + HALL_H / 2, HALL_HZ, COLORS.stone)
put(hall, "HallWall", Vector3.new(HALL_HX * 2, HALL_H, 14), -40, 40 + HALL_H / 2, -HALL_HZ, COLORS.stone)
-- 입구 쪽은 양옆 기둥만
for _, s in ipairs({ 1, -1 }) do
	put(hall, "HallWall", Vector3.new(14, HALL_H, 70), -40 + HALL_HX, 40 + HALL_H / 2, s * (HALL_HZ - 35), COLORS.stone)
end

-- 부벽
for i = -2, 2 do
	for _, s in ipairs({ 1, -1 }) do
		put(
			hall,
			"Buttress",
			Vector3.new(30, HALL_H * 0.82, 26),
			-40 + i * 88,
			40 + HALL_H * 0.41,
			s * (HALL_HZ + 14),
			COLORS.stoneDark
		)
	end
end

-- 박공지붕 (계단식 슬래브 — 각진 형태 유지)
for i = 0, 5 do
	local shrink = i * 26
	if HALL_HZ - shrink > 10 then
		put(
			hall,
			"RoofSlab",
			Vector3.new(HALL_HX * 2 + 30, 16, (HALL_HZ - shrink) * 2 + 30),
			-40,
			40 + HALL_H + 8 + i * 15,
			0,
			COLORS.roof,
			Enum.Material.Metal
		)
	end
end

-- 내부 기둥
for i = -1, 1 do
	for _, s in ipairs({ 1, -1 }) do
		put(
			hall,
			"HallPillar",
			Vector3.new(24, HALL_H - 20, 24),
			-40 + i * 110,
			40 + (HALL_H - 20) / 2,
			s * (HALL_HZ - 46),
			COLORS.stoneLight
		)
	end
end

------------------------------------------------------------------
-- 6) 단상 (안쪽 끝)
------------------------------------------------------------------
local dais = group("Dais")
for i = 0, 3 do
	local w = 190 - i * 34
	put(dais, "DaisStep", Vector3.new(w * 0.55, 14, w), -40 - HALL_HX + 78, 40 + 7 + i * 14, 0, COLORS.stoneDark)
end
put(dais, "DaisThrone", Vector3.new(46, 76, 60), -40 - HALL_HX + 70, 40 + 56 + 38, 0, COLORS.stone)
put(dais, "DaisBanner", Vector3.new(6, 130, 76), -40 - HALL_HX + 44, 40 + 150, 0, COLORS.banner, Enum.Material.Fabric)
for _, s in ipairs({ 1, -1 }) do
	put(dais, "Brazier", Vector3.new(22, 22, 22), -40 - HALL_HX + 96, 40 + 80, s * 78, COLORS.fire, Enum.Material.Neon)
end

------------------------------------------------------------------
-- 7) 상호작용
------------------------------------------------------------------
local sealPart = put(root, "BossSeal", Vector3.new(70, 6, 70), -40, 41, 0, COLORS.gold, Enum.Material.Metal)
sealPart.Transparency = 0.35

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "도전"
-- 신이 아니라 인간이 만든 보스방이므로 신 이름을 쓰지 않는다.
prompt.ObjectText = "인간 연합 대성채"
prompt.HoldDuration = 1.2
prompt.MaxActivationDistance = 42
prompt.RequiresLineOfSight = false
prompt.Parent = sealPart

log("완료: 총 %d파트 / Workspace.World.BossArenas.Boss_인간대성채", count)
log(
	"성벽 %dx%d, 능보 4기, 대전당 %dx%d, 성문은 탑 방향",
	WALL_HALF * 2,
	WALL_HALF * 2,
	HALL_HX * 2,
	HALL_HZ * 2
)
