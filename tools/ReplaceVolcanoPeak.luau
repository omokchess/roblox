--!strict
-- ReplaceVolcanoPeak.luau
--
-- 피드백: "화산에서 기존의 봉우리(콜로세움처럼 원으로 쌓아놓은 것)는 없애고,
--          새롭게 만든 봉우리를 그 위치에 놔서 빈 공간을 없애줘.
--          이 때, 떠있는 블록이 생겼는지도 확인 해야 해."
--
-- ── 대상 ────────────────────────────────────────────────────────────────
--   제거: Workspace.World.VolcanoPeak
--         484파트 (PeakBlock=340, PeakCrack=49, CraterRim=38, PeakLedge=32,
--                  CraterRock=14, LavaJet=10, CraterLava=1)
--         중심 (2511, 823, 923), 크기 (1037, 863, 1090), Y[392..1255]
--
--         PeakLedge/CraterRim이 일정 반경으로 규칙적으로 쌓여 있어
--         밖에서 보면 원형 계단(콜로세움)처럼 읽혔다.
--
--   신설: 같은 자리에 같은 Y범위를 채우는 **불규칙 화산추 셸**
--
-- ── 콜로세움처럼 안 보이게 하는 방법 ────────────────────────────────────
--   "링을 쌓는다"는 구조 자체는 원뿔을 만들 때 피하기 어렵다.
--   대신 **층이 눈에 안 띄게** 만든다:
--     1) 반경에 각도별 노이즈 → 링이 정원(正圓)이 아니게
--     2) 높이에 지터 → 인접 블록의 윗면이 일직선으로 안 맞게
--     3) 블록마다 크기·회전 랜덤
--     4) 각 층의 시작 각도를 어긋나게(오프셋) → 세로줄 정렬 방지
--     5) 능선(Spur) 6줄을 비대칭으로 덧대 실루엣을 깨뜨림
--
-- ── 빈 공간 방지 ────────────────────────────────────────────────────────
--   기존 VolcanoPeak과 **같은 Y범위(392~1255), 같은 밑변 반경(520)** 으로 지어
--   아래쪽 VolcanoCore(top=652)와 겹쳐 물리도록 한다.
--   셸이므로 내부 마그마 챔버는 막지 않는다.
--
-- ── 떠있는 블록 점검 ────────────────────────────────────────────────────
--   생성 후 새 봉우리 파트 전체를 아래로 레이캐스트해 공중에 뜬 것이 있는지 센다.
--   (셸 구조라 크레이터 안쪽은 원래 뚫려 있으므로, 바로 아래 이웃 블록에
--    걸리는지를 기준으로 본다)
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "PEAK::" 접두어.
-- 되돌리기: Ctrl+Z 또는 backup/pre-dedupe-2026-07-20.rbxl

local BASE_Y = 392
local TOP_Y = 1255
local BASE_R = 520
local RIM_R = 150
local LEVEL_STEP = 30

local function log(fmt: string, ...): ()
	print("PEAK:: " .. string.format(fmt, ...))
end

local world = workspace.World
local old = world:FindFirstChild("VolcanoPeak")

if not old then
	log("중단: VolcanoPeak 없음 (이미 교체됐을 수 있다)")
	return
end

-- 기존 봉우리의 실제 중심 XZ를 이어받는다.
local mn = Vector3.new(1e9, 1e9, 1e9)
local mx = Vector3.new(-1e9, -1e9, -1e9)
local oldCount = 0
for _, part in ipairs(old:GetDescendants()) do
	if part:IsA("BasePart") then
		local a = part.Position - part.Size / 2
		local b = part.Position + part.Size / 2
		mn = Vector3.new(math.min(mn.X, a.X), math.min(mn.Y, a.Y), math.min(mn.Z, a.Z))
		mx = Vector3.new(math.max(mx.X, b.X), math.max(mx.Y, b.Y), math.max(mx.Z, b.Z))
		oldCount += 1
	end
end
local CX = (mn.X + mx.X) / 2
local CZ = (mn.Z + mx.Z) / 2

log("기존 VolcanoPeak %d파트 제거 / 중심 XZ (%.0f, %.0f) Y[%.0f..%.0f]", oldCount, CX, CZ, mn.Y, mx.Y)
old:Destroy()

------------------------------------------------------------------
-- 새 봉우리 생성
------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "VolcanoPeak"
folder.Parent = world

local rng = Random.new(20260720)
local made = 0

local rockColors = {
	Color3.fromRGB(52, 46, 44),
	Color3.fromRGB(44, 39, 38),
	Color3.fromRGB(62, 54, 50),
	Color3.fromRGB(38, 34, 33),
}

local function rock(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Basalt
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	made += 1
	return p
end

local levels = math.floor((TOP_Y - BASE_Y) / LEVEL_STEP)

for i = 0, levels do
	local t = i / levels
	local y = BASE_Y + i * LEVEL_STEP
	-- 위로 갈수록 좁아지되 살짝 오목한 화산 실루엣
	local r = BASE_R + (RIM_R - BASE_R) * (t ^ 0.85)

	-- 분할 수는 "둘레 / 분할 <= 블록 폭"이 되게 잡아야 링에 구멍이 안 생긴다.
	-- r/14로 잡았더니 r=520에서 간격 88스터드인데 블록 폭은 34~62라
	-- 링이 뚫려 PeakBlock 664개 중 217개가 공중에 떴다. r/6으로 조여 겹치게 한다.
	local divisions = math.max(24, math.floor(r / 6))
	-- 시작 각도를 층마다 조금씩 비틀어 세로줄을 없앤다.
	-- 완전 랜덤으로 했더니 인접 층과 각도가 decorrelate돼 블록이 서로 어긋났다 → 느린 트위스트로 변경.
	local angleOffset = i * 0.13

	for d = 0, divisions - 1 do
		local ang = angleOffset + (d / divisions) * math.pi * 2
		-- 각도별 반경 노이즈 (정원 방지).
		-- 주의: 노이즈가 층(i)에 크게 의존하면 인접 층끼리 반경이 달라져 블록이 허공에 뜬다.
		--       (i*0.7 항을 쓰던 초기 버전에서 1536개 중 418개가 떴다)
		--       → 각도에만 의존하는 성분을 주로 쓰고, 층 드리프트는 아주 약하게만 준다.
		--       결과적으로 세로로 이어지는 능선·고랑이 생겨 원형처럼 안 보이면서도 층끼리 물린다.
		local wob = math.sin(ang * 3) * 26 + math.sin(ang * 7) * 13 + math.sin(ang * 5 + i * 0.12) * 6
		local rr = r + wob + rng:NextNumber(-6, 6)
		-- 세로 지터를 줄이고(±6) 블록 높이를 층간격 30보다 크게 잡아 층끼리 반드시 물리게 한다
		local yy = y + rng:NextNumber(-6, 6)

		local px = CX + math.cos(ang) * rr
		local pz = CZ + math.sin(ang) * rr

		-- w는 회전(yaw=-ang) 때문에 **반경 방향** 두께가 된다.
		-- 층간 반경차 Δr이 12~18인데 34~62(반폭 17~31)로 잡았더니
		-- 아래 링을 빗나가는 블록이 27%(1536중 424) 나왔다.
		-- 반폭이 Δr을 확실히 넘도록 72~108로 키워 셸을 두껍게 만든다.
		local w = rng:NextNumber(72, 108)
		local h = rng:NextNumber(42, 64)
		local dpt = rng:NextNumber(40, 78)

		rock(
			"PeakBlock",
			Vector3.new(w, h, dpt),
			CFrame.new(px, yy, pz)
				* CFrame.Angles(
					rng:NextNumber(-0.08, 0.08),
					-ang + rng:NextNumber(-0.25, 0.25),
					rng:NextNumber(-0.08, 0.08)
				),
			rockColors[rng:NextInteger(1, #rockColors)]
		)
	end
end

------------------------------------------------------------------
-- 능선 6줄 (실루엣 깨기)
------------------------------------------------------------------
for s = 1, 6 do
	local ang = (s / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	local steps = rng:NextInteger(9, 15)
	for k = 0, steps do
		local t = k / steps
		local y = BASE_Y + t * (TOP_Y - BASE_Y) * 0.92
		local r = (BASE_R + (RIM_R - BASE_R) * (t ^ 0.85)) + rng:NextNumber(14, 44)
		local px = CX + math.cos(ang) * r
		local pz = CZ + math.sin(ang) * r
		rock(
			"PeakSpur",
			Vector3.new(rng:NextNumber(46, 82), rng:NextNumber(44, 86), rng:NextNumber(46, 82)),
			CFrame.new(px, y, pz) * CFrame.Angles(0, -ang, rng:NextNumber(-0.2, 0.2)),
			rockColors[rng:NextInteger(1, #rockColors)]
		)
	end
end

------------------------------------------------------------------
-- 분화구 (림 + 용암)
------------------------------------------------------------------
local rimDiv = 30
for d = 0, rimDiv - 1 do
	local ang = (d / rimDiv) * math.pi * 2
	local rr = RIM_R + rng:NextNumber(-14, 18)
	rock(
		"CraterRim",
		Vector3.new(rng:NextNumber(40, 66), rng:NextNumber(26, 46), rng:NextNumber(40, 62)),
		CFrame.new(CX + math.cos(ang) * rr, TOP_Y + rng:NextNumber(-8, 14), CZ + math.sin(ang) * rr)
			* CFrame.Angles(0, -ang, rng:NextNumber(-0.18, 0.18)),
		Color3.fromRGB(34, 30, 29)
	)
end

local lava = rock(
	"CraterLava",
	Vector3.new(RIM_R * 1.85, 14, RIM_R * 1.85),
	CFrame.new(CX, TOP_Y - 26, CZ),
	Color3.fromRGB(255, 108, 32),
	Enum.Material.Neon
)
lava.Shape = Enum.PartType.Cylinder
lava.CFrame = CFrame.new(CX, TOP_Y - 26, CZ) * CFrame.Angles(0, 0, math.rad(90))

for j = 1, 10 do
	local ang = rng:NextNumber(0, math.pi * 2)
	local rr = rng:NextNumber(10, RIM_R * 0.8)
	local jet = rock(
		"LavaJet",
		Vector3.new(rng:NextNumber(14, 30), rng:NextNumber(20, 62), rng:NextNumber(14, 30)),
		CFrame.new(CX + math.cos(ang) * rr, TOP_Y - 10 + rng:NextNumber(0, 26), CZ + math.sin(ang) * rr),
		Color3.fromRGB(255, 138, 46),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 126, 40)
	light.Range = 150
	light.Brightness = 3
	light.Shadows = false
	light.Parent = jet
end

log(
	"새 봉우리 %d파트 생성 (밑변 r=%d, 림 r=%d, Y %d~%d, %d층)",
	made,
	BASE_R,
	RIM_R,
	BASE_Y,
	TOP_Y,
	levels + 1
)

------------------------------------------------------------------
-- 떠있는 블록 점검
------------------------------------------------------------------
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local floating = 0
local checked = 0
for _, part in ipairs(folder:GetChildren()) do
	if part:IsA("BasePart") and part.Name == "PeakBlock" then
		checked += 1
		params.FilterDescendantsInstances = { part }
		local origin = part.Position - Vector3.new(0, part.Size.Y / 2 + 0.2, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -140, 0), params)
		if not hit then
			floating += 1
		end
	end
end

log(
	"떠있는 블록 점검: PeakBlock %d개 중 아래 140스터드 내에 지지물 없는 것 %d개",
	checked,
	floating
)
log("위치: Workspace.World.VolcanoPeak (PeakBlock / PeakSpur / CraterRim / CraterLava / LavaJet)")
