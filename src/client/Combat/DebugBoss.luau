--!strict
--[[
	DebugBoss — 보스 디버그의 몸(부위 넷)과 그 몸을 움직이는 rig. (2026-09-29, 2026-10-03 다시 지음)

	2026-10-03 사용자: "디버그를 정12각형 구체로 두고, 디버그 쪽에 보이는 칸은 없애고, 돌아가거나 움직이면서 투사체를 쏘며 공격".
	답: 부위 처리 = "코어 + 위성 셋", 적 칸 = "보이는 것만 없앰"(규칙·칸 차지는 그대로).
	  코어      큰 정십이면체(둘레 반지름 6, 마젠타 속 빛) + 기운 코드 고리 + 앞에 뜬 마젠타 결정. 칸 위 10 스터드에 뜬다
	  머리      작은 정십이면체(2.3, 청록 속 빛) + 앞면에 붉은 중단점 + 벌레 더듬이
	  서브코어-삭제   작은 정십이면체(붉은 속 빛) + 앞면에 붉은 ✕
	  서브코어-패치   작은 정십이면체(초록 속 빛) + 앞면에 초록 + + 비스듬히 감은 붕대 띠
	위성은 코어 둘레를 돈다 — 앞으로 지나 옆으로, 코어 뒤로 숨었다가 다시 나온다(2026-10-03 사용자: "코어 뒤쪽으로도 돌면서
	진짜 공전하는 느낌"). 자리는 CombatDirector 가 매 프레임 DebugBoss.Orbit 으로 정한다.
	2026-10-03 사용자: "공전·자전이 끊겨 보이지 않게, 불규칙한 방향으로" — 자전은 매끈한 잡음(math.noise)으로 축·빠르기가
	천천히 바뀌는 각속도를 쌓아 돌리고, 공전은 멈추지 않고(공격 중에도 움직이며 쏜다) 빠르기·방향·궤도면이 잡음으로 흔들린다.
	"블렌더랑 로블록스 내 제작을 섞어서": 다면체·이음새 빛·코드 고리·더듬이·붕대·결정은 블렌더 메시
	(ReplicatedStorage.MonsterMeshes.Debug<부위> — models/monsters/build_monsters.py), 기호·떠다니는 오류 조각은 아래 Part 표.
	메시가 없으면(가져오기 전) 공 Part 로 대신한다.

	자리(Pivot) = 다면체 가운데, 정면 = 모델 -Z(아군 쪽). 메시 이름 Spin… 은 다면체와 함께 불규칙하게 구르고,
	Ring… 은 RING_AXIS 둘레로 돌며 살짝 흔들리고(가운데 기준), Float… 은 떠서 돈다. 기호는 돌지 않고 늘 아군 쪽을 본다.

	rig: Apply(pose) — Root {x,y,z,rx,ry,rz}, Body {sx,sy,sz}(%) 는 슬라임 모션과 같은 뜻(Motions/Debug.luau).
	Fade 는 쓰러질 때 연출이 올린다.
]]

local DebugBoss = {}
DebugBoss.__index = DebugBoss

local RAD = math.pi / 180
local RGB = Color3.fromRGB
local M = Enum.Material

local BODY = { RGB(34, 30, 48), M.Metal }
local PANEL = { RGB(58, 52, 80), M.SmoothPlastic }
local TRIM = { RGB(88, 80, 116), M.Metal }
local CYAN = { RGB(50, 170, 210), M.Neon } -- 네온 번짐이 커서 조금 어둡게
local MAGENTA = { RGB(255, 70, 200), M.Neon }
local RED = { RGB(255, 48, 60), M.Neon }
local GREEN = { RGB(60, 235, 100), M.Neon } -- 네온이 밝혀 청록으로 보이지 않게 조금 짙게
local BANDAGE = { RGB(206, 198, 172), M.Fabric }

-- 크기·자리(디자인 값 — Motions/Debug.luau·Fx/Debug.luau·CombatDirector 가 같이 쓴다)
DebugBoss.Radius = { Core = 6, Head = 2.3, DeleteArm = 2.3, PatchArm = 2.3 }
DebugBoss.Lift = 10 -- 코어 가운데가 칸 바닥 위로 뜨는 높이
-- 코드 고리 축(build_monsters.py RING_N 과 같게)
local RING_AXIS = Vector3.new(0.35, 1, -0.2).Unit
-- 자전 빠르기(라디안/초 어림 — 잡음이 곱해져 축과 함께 출렁인다)
local SPIN_RATE = { Core = 0.35, Head = 1.0, DeleteArm = 1.1, PatchArm = 0.9 }
local noise = math.noise

-- 위성 궤도: 코어 가운데를 도는 기운 원(반지름 14 — 코드 고리 9.5·위성 2.3 과 닿지 않게). 궤도면은 15~37° 기울고
-- 기운 쪽이 천천히 돌아(세차) 앞·옆·뒤 높낮이가 계속 바뀐다
local ORBIT_R, ORBIT_UP = 14, 0.5
DebugBoss.OrbitSpeed = 0.35 -- 라디안/초(기준 — 잡음으로 빨라졌다 느려졌다 가끔 거꾸로)
DebugBoss.OrbitPhase = { Head = 0, DeleteArm = 2 * math.pi / 3, PatchArm = 4 * math.pi / 3 }
local SEED = { Head = 11.3, DeleteArm = 27.9, PatchArm = 41.7 }

-- 공전 각속도(셋이 함께 도는 바퀴 — 따로 돌면 서로 부딪친다). 대개 한 방향, 가끔 매끈하게 거꾸로
-- 지금 보스 페이즈(BattleClient 가 스냅샷마다 맞춘다). 페이즈마다 공전·자전·이펙트가 커진다(아이디어 8)
DebugBoss.Phase = 1
local function phaseBoost(): number
	return 1 + 0.25 * math.max(0, DebugBoss.Phase - 1)
end

function DebugBoss.OrbitRate(t: number): number
	return DebugBoss.OrbitSpeed * (noise(t * 0.05, 3.7) * 3 + 0.45) * phaseBoost()
end

-- 위성 자리: 코어 가운데 기준 오프셋(코어 공간 — -Z 가 아군 쪽). theta = 궤도 위 각.
-- t 를 주면 궤도면 기울기·세차, 반지름, 위성마다의 자리가 잡음으로 천천히 흔들린다(불규칙한 3차원 길)
function DebugBoss.Orbit(theta: number, t: number?, key: string?): Vector3
	local s = SEED[key or ""] or 0
	local tt = t or 0
	local r = ORBIT_R + noise(tt * 0.2, s) * 2.4
	local incline = 0.45 + noise(tt * 0.04, 5.3) * 0.45
	local azimuth = tt * 0.05 + noise(tt * 0.03, 7.7) * 2
	local plane = CFrame.Angles(0, azimuth, 0) * CFrame.Angles(incline, 0, 0)
	local wander = Vector3.new(noise(tt * 0.31, s, 1), noise(tt * 0.27, s, 2), noise(tt * 0.23, s, 3)) * 2.4
	return plane * Vector3.new(r * math.cos(theta), 0, r * math.sin(theta)) + Vector3.new(0, ORBIT_UP, 0) + wander
end

-- { 이름, 크기, 자리, 빛, 돌림(도)?, 꾸밈? }  꾸밈: "Float" 떠다님 · "Cyl" 원기둥(축 = 로컬 X) · "Ball" 공
type Spec = { any }

local function S(name: string, size: { number }, at: { number }, col: { any }, rot: { number }?, flag: string?): Spec
	return { name, size, at, col, rot or { 0, 0, 0 }, flag }
end

-- 메시가 없을 때의 몸(공). 메시가 있으면 뺀다
local function fallbackBody(r: number): Spec
	return S("Body", { r * 1.7, r * 1.7, r * 1.7 }, { 0, 0, 0 }, BODY, nil, "Ball")
end

local SPECS: { [string]: { Spec } } = {
	-- 기호는 다면체 둘레(반지름 2.3) 바로 바깥 앞에 뜬다 — 다면체가 돌아도 닿지 않게
	Head = {
		fallbackBody(2.3),
		S("Breakpoint", { 0.25, 2.1, 2.1 }, { 0, 0, -2.6 }, RED, { 0, 90, 0 }, "Cyl"),
		S("Glint", { 0.27, 0.55, 0.55 }, { -0.42, 0.42, -2.69 }, { RGB(255, 190, 190), M.Neon }, { 0, 90, 0 }, "Cyl"),
		S("Bit1", { 0.35, 0.35, 0.35 }, { 1.1, 3.9, 0.5 }, MAGENTA, { 20, 30, 10 }, "Float"),
		S("Bit2", { 0.28, 0.28, 0.28 }, { -0.9, 4.3, 0.2 }, CYAN, { 0, 45, 30 }, "Float"),
		S("Bit3", { 0.3, 0.3, 0.3 }, { 0.25, 4.8, -0.4 }, MAGENTA, { 35, 0, 15 }, "Float"),
	},
	DeleteArm = {
		fallbackBody(2.3),
		S("Delete1", { 0.36, 2.5, 0.2 }, { 0, 0, -2.62 }, RED, { 0, 0, 45 }),
		S("Delete2", { 0.36, 2.5, 0.2 }, { 0, 0, -2.63 }, RED, { 0, 0, -45 }),
		S("Bit1", { 0.3, 0.3, 0.3 }, { 1.6, 2.4, -0.6 }, MAGENTA, { 20, 10, 40 }, "Float"),
		S("Bit2", { 0.25, 0.25, 0.25 }, { -1.7, 2.0, -0.4 }, RED, { 45, 0, 0 }, "Float"),
	},
	PatchArm = {
		fallbackBody(2.3),
		S("Plus1", { 0.4, 2.1, 0.2 }, { 0, 0, -2.62 }, GREEN),
		S("Plus2", { 2.1, 0.4, 0.2 }, { 0, 0, -2.63 }, GREEN),
		S("Bit1", { 0.3, 0.3, 0.3 }, { -1.7, 2.3, -0.5 }, GREEN, { 30, 0, 20 }, "Float"),
		S("Bit2", { 0.25, 0.25, 0.25 }, { 1.5, 2.6, -0.3 }, CYAN, { 0, 45, 45 }, "Float"),
	},
	-- 코어: 위로 오류 조각이 떠 있다. 결정은 메시(팔면체)가 있으면 그것으로
	Core = {
		fallbackBody(6),
		S("Crystal", { 2, 2, 2 }, { 0, 0, -7.8 }, MAGENTA, { 35, 45, 0 }, "Float"),
		S("Err1", { 1.4, 1.4, 1.4 }, { 2.4, 7.6, -1.5 }, MAGENTA, { 20, 30, 10 }, "Float"),
		S("Err2", { 0.9, 0.9, 0.9 }, { -3.0, 8.4, 1.2 }, CYAN, { 0, 45, 30 }, "Float"),
		S("Err3", { 0.7, 0.7, 0.7 }, { 0.4, 9.2, 2.6 }, RED, { 35, 0, 15 }, "Float"),
		S("Err4", { 1.1, 1.1, 1.1 }, { -1.6, 7.2, -3.4 }, MAGENTA, { 10, 60, 0 }, "Float"),
		S("Err5", { 0.55, 0.55, 0.55 }, { 4.0, 8.7, 2.0 }, CYAN, { 45, 45, 0 }, "Float"),
		S("Err6", { 0.65, 0.65, 0.65 }, { -4.2, 6.9, -2.2 }, RED, { 0, 20, 45 }, "Float"),
		S("Err7", { 0.45, 0.45, 0.45 }, { 1.6, 10.0, 0.4 }, MAGENTA, { 30, 30, 30 }, "Float"),
	},
}

DebugBoss.Parts = { "Head", "DeleteArm", "PatchArm", "Core" }

-- 메시 이름의 낱말 → 빛(먼저 맞는 것, 없으면 몸 색)
local MESH_LOOK: { { any } } = {
	{ "Bandage", BANDAGE },
	{ "Panel", PANEL },
	{ "Trim", TRIM },
	{ "Magenta", MAGENTA },
	{ "Red", RED },
	{ "Green", GREEN },
	{ "Cyan", CYAN },
}

-- 메시가 있으면 빼는 Part(메시가 대신한다)
local REPLACED = { Body = true, Crystal = true }

-- Part 표 + 메시 Spec 목록과 메시들. 메시 창고가 없으면 Part 표 그대로
local function buildSpecs(key: string): ({ Spec }, { [string]: MeshPart })
	local specs = SPECS[key] or SPECS.Core
	local shared = game:GetService("ReplicatedStorage"):FindFirstChild("MonsterMeshes")
	local folder = shared and shared:FindFirstChild("Debug" .. key)
	if not folder then
		return specs, {}
	end
	local list, meshes = {}, {}
	for _, s in specs do
		if not REPLACED[s[1]] then
			table.insert(list, s)
		end
	end
	for _, mp in folder:GetChildren() do
		local offset = mp:GetAttribute("Offset")
		if not (mp:IsA("MeshPart") and typeof(offset) == "CFrame") then
			continue
		end
		local col = BODY
		for _, look in MESH_LOOK do
			if string.find(mp.Name, look[1], 1, true) then
				col = look[2]
				break
			end
		end
		local rx, ry, rz = offset:ToOrientation()
		local p = offset.Position
		local flag = if string.sub(mp.Name, 1, 5) == "Float" then "Float"
			elseif string.sub(mp.Name, 1, 4) == "Spin" then "Spin"
			elseif string.sub(mp.Name, 1, 4) == "Ring" then "Ring"
			else nil
		table.insert(list, S(mp.Name, { mp.Size.X, mp.Size.Y, mp.Size.Z }, { p.X, p.Y, p.Z }, col, { rx / RAD, ry / RAD, rz / RAD }, flag))
		meshes[mp.Name] = mp
	end
	return list, meshes
end

--[[
	부위 하나를 짓는다. 돌려주는 값이 곧 rig 다(`.Model`). home 은 다면체 가운데 자리.
]]
function DebugBoss.new(key: string, home: CFrame)
	local self = setmetatable({}, DebugBoss)
	local model = Instance.new("Model")
	model.Name = "Debug_" .. key
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Size = Vector3.new(0.2, 0.2, 0.2)
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide, pivot.CanQuery, pivot.CanTouch = false, false, false
	pivot.CFrame = home
	pivot.Parent = model
	model.PrimaryPart = pivot
	self.Model = model
	self.Pivot = home
	self.Fade = 0
	self.Parts = {}
	-- 자전: 쌓아 가는 회전(축·빠르기가 잡음으로 바뀐다), 고리 각, 잡음 씨앗
	self.SpinRate = SPIN_RATE[key] or 0.8
	self.Spin = CFrame.fromOrientation(math.random() * 6, math.random() * 6, 0)
	self.RingAngle = math.random() * 6
	self.Seed = math.random() * 100
	self.LastT = os.clock()
	local list, meshes = buildSpecs(key)
	for i, s in list do
		local size, at, col, rot, flag = s[2], s[3], s[4], s[5], s[6]
		local mesh = meshes[s[1]]
		local p: BasePart = if mesh then mesh:Clone() else Instance.new("Part")
		p.Name = s[1]
		p.Size = Vector3.new(size[1], size[2], size[3])
		p.Color = col[1]
		p.Material = col[2]
		p.Anchored = true
		p.CanCollide, p.CanTouch = false, false
		-- 격자 칸을 찾는 광선·드래그 광선이 몸에 막히지 않게
		p.CanQuery = false
		p.CastShadow = col[2] ~= M.Neon
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if p:IsA("Part") then
			if flag == "Cyl" then
				p.Shape = Enum.PartType.Cylinder
			elseif flag == "Ball" then
				p.Shape = Enum.PartType.Ball
			end
		end
		local rest = CFrame.new(at[1], at[2], at[3]) * CFrame.fromOrientation(rot[1] * RAD, rot[2] * RAD, rot[3] * RAD)
		p.CFrame = home * rest
		p.Parent = model
		table.insert(self.Parts, {
			Part = p,
			Rest = rest,
			Size = p.Size,
			Alpha = 0,
			Float = if flag == "Float" then i * 1.37 else nil,
			Turn = flag,
		})
	end
	return self
end

-- CombatRig 과 같은 이름(연출이 가리지 않고 부른다)
function DebugBoss:SetWeaponMotor() end
function DebugBoss:Take() end
function DebugBoss:Release() end

function DebugBoss:Apply(pose: any)
	local root = pose.Root or { 0, 0, 0, 0, 0, 0 }
	local body = pose.Body or { 0, 0, 0 }
	local sx, sy, sz = 1 + body[1] / 100, 1 + body[2] / 100, 1 + body[3] / 100
	local base = self.Pivot * CFrame.new(root[1], root[2], root[3]) * CFrame.fromOrientation(root[4] * RAD, root[5] * RAD, root[6] * RAD)
	local primary = self.Model.PrimaryPart
	if primary then
		primary.CFrame = self.Pivot
	end
	local t = os.clock()
	local dt = math.clamp(t - self.LastT, 0, 0.1)
	self.LastT = t
	-- 자전: 각속도 벡터가 잡음으로 천천히 방향을 바꾼다 → 매 프레임 그만큼 쌓아 돌린다(끊김 없이 불규칙하게 구른다)
	local seed = self.Seed
	local w = Vector3.new(noise(t * 0.13, seed), noise(t * 0.11, seed + 10), noise(t * 0.17, seed + 20)) * 2.4
	if w.Magnitude < 0.4 then
		w = (if w.Magnitude > 1e-4 then w.Unit else Vector3.new(0, 1, 0)) * 0.4
	end
	w *= self.SpinRate * phaseBoost()
	self.Spin = (CFrame.fromAxisAngle(w.Unit, w.Magnitude * dt) * self.Spin):Orthonormalize()
	-- 고리: 제 축으로 빨라졌다 느려졌다 돌고, 고리 면이 살짝 끄덕인다
	self.RingAngle += (0.45 + noise(t * 0.09, seed + 30) * 0.7) * dt
	local ring = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), noise(t * 0.07, seed + 40) * 0.35) * CFrame.fromAxisAngle(RING_AXIS, self.RingAngle)
	for _, e in self.Parts do
		local rest = e.Rest
		local at = CFrame.new(rest.X * sx, rest.Y * sy, rest.Z * sz) * rest.Rotation
		local cf
		if e.Turn == "Spin" then
			-- 다면체·고리는 가운데(원점) 둘레로 돈다
			cf = base * self.Spin * at
		elseif e.Turn == "Ring" then
			cf = base * ring * at
		else
			cf = base * at
		end
		local k = e.Float
		if k then
			cf = cf * CFrame.new(0, math.sin(t * 1.7 + k) * 0.3, 0) * CFrame.Angles(0, t * 0.9 + k, 0)
			-- 가끔 옆으로 튄다(글리치)
			if math.sin(t * 5.3 + k * 3) > 0.97 then
				cf += Vector3.new(0.35, 0, 0)
			end
		end
		e.Part.Size = Vector3.new(e.Size.X * sx, e.Size.Y * sy, e.Size.Z * sz)
		e.Part.CFrame = cf
		if self.Fade > 0 then
			e.Part.Transparency = e.Alpha + (1 - e.Alpha) * self.Fade
		end
	end
end

return DebugBoss
