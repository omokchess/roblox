--!strict
-- AddVolcanoTunnelLights.luau
--
-- 피드백: "화산 지하 통로에 빛을 내뿜는 블록을 몇 개 놔서 잘 보이게 해줘."
--
-- ── 대상 위치 ────────────────────────────────────────────────────────────
--   Workspace.World.VolcanoTunnel      Y[347..642]  c=(2096,495,733)  지상→지하 진입 통로
--     TunFloor 11개 / TunCeil 11개  각 sz=(138,14,44), 바닥 y=354, 천장 y=464
--   Workspace.World.VolcanoUnderworld  Y[-211..72]  c=(1198,-70,314)  지하 대공동
--     ChFloor 144개 / ChCeil 144개 / TunWall 18개
--
-- ── 배치 방식 ────────────────────────────────────────────────────────────
--   통로: 각 TunFloor 위 천장 근처에 용암 램프를 매단다 (전 구간 11개)
--   지하: ChFloor를 일정 간격으로 샘플링해 바닥 화로를 놓는다 (LIGHT_STRIDE마다)
--
--   램프 = Neon 파트 + PointLight. 주황빛으로 화산 테마에 맞춘다.
--   전부 Anchored, CanCollide=false 라 통행을 막지 않는다.
--
--   생성물은 각각 `TunnelLights` / `UnderworldLights` 폴더에 모아둔다.
--   재실행하면 기존 폴더를 지우고 다시 만들므로 중복 생성되지 않는다.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "LIGHT::" 접두어.

local LIGHT_STRIDE = 12 -- 지하 ChFloor 몇 개마다 화로를 놓을지
local LAMP_COLOR = Color3.fromRGB(255, 138, 52) -- 용암 주황
local LAMP_RANGE = 130
local LAMP_BRIGHTNESS = 3.2

local function log(fmt: string, ...): ()
	print("LIGHT:: " .. string.format(fmt, ...))
end

-- 발광 블록 1개를 만든다.
local function makeLamp(parent: Instance, name: string, cf: CFrame, size: Vector3): Part
	local lamp = Instance.new("Part")
	lamp.Name = name
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CastShadow = false
	lamp.Size = size
	lamp.CFrame = cf
	lamp.Material = Enum.Material.Neon
	lamp.Color = LAMP_COLOR
	lamp.TopSurface = Enum.SurfaceType.Smooth
	lamp.BottomSurface = Enum.SurfaceType.Smooth

	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = LAMP_RANGE
	light.Brightness = LAMP_BRIGHTNESS
	light.Shadows = false
	light.Parent = lamp

	lamp.Parent = parent
	return lamp
end

-- 재실행 대비: 기존 조명 폴더를 비운다.
local function freshFolder(parent: Instance, name: string): Folder
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local world = workspace.World

------------------------------------------------------------------
-- (1) 진입 통로: 천장에 매단 램프
------------------------------------------------------------------
local tunnel = world:FindFirstChild("VolcanoTunnel")
local tunnelCount = 0

if tunnel then
	local folder = freshFolder(tunnel, "TunnelLights")

	for _, part in ipairs(tunnel:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "TunFloor" then
			-- 바닥 파트 바로 위, 천장에 가깝게 매단다.
			local top = part.Position.Y + part.Size.Y / 2
			local pos = Vector3.new(part.Position.X, top + 88, part.Position.Z)
			makeLamp(folder, "TunnelLamp", CFrame.new(pos), Vector3.new(16, 5, 16))
			tunnelCount += 1
		end
	end
	log("진입 통로 램프 %d개 (VolcanoTunnel.TunnelLights)", tunnelCount)
else
	log("경고: VolcanoTunnel 없음")
end

------------------------------------------------------------------
-- (2) 지하 대공동: 바닥 화로
------------------------------------------------------------------
local under = world:FindFirstChild("VolcanoUnderworld")
local underCount = 0

if under then
	local folder = freshFolder(under, "UnderworldLights")

	-- 위치가 겹치지 않도록 ChFloor를 좌표순으로 정렬한 뒤 일정 간격 샘플링.
	local floors: { BasePart } = {}
	for _, part in ipairs(under:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "ChFloor" then
			table.insert(floors, part)
		end
	end
	table.sort(floors, function(a, b)
		if math.abs(a.Position.X - b.Position.X) > 0.5 then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)

	for index, part in ipairs(floors) do
		if index % LIGHT_STRIDE == 1 then
			local top = part.Position.Y + part.Size.Y / 2
			local pos = Vector3.new(part.Position.X, top + 9, part.Position.Z)
			makeLamp(folder, "UnderworldBrazier", CFrame.new(pos), Vector3.new(12, 12, 12))
			underCount += 1
		end
	end
	log(
		"지하 화로 %d개 / ChFloor %d개 중 %d개마다 (VolcanoUnderworld.UnderworldLights)",
		underCount,
		#floors,
		LIGHT_STRIDE
	)
else
	log("경고: VolcanoUnderworld 없음")
end

log("완료: 발광 블록 총 %d개", tunnelCount + underCount)
