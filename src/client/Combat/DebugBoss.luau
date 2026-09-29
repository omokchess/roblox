--!strict
--[[
	DebugBoss — 보스 디버그의 몸(부위 넷)과 그 몸을 움직이는 rig. (2026-09-29)

	맵 양식처럼 블록을 쌓는다. 버그 덩어리: 검보라 몸통, 코드 줄 같은 청록 네온 띠, 떠다니는 글리치 조각.
	  머리      IDE 의 붉은 중단점(동그라미) 하나가 얼굴이다
	  삭제 팔   주먹 앞에 붉은 ✕
	  패치 팔   손바닥에 초록 +, 팔에 붕대 띠(패치)
	  코어      큰 몸통. 앞에 마젠타 결정이 박혀 있고 등 위로 오류 조각이 떠 있다
	부위마다 따로 모델·배우다(맞음·쓰러짐을 부위별로 보여 준다). 자리(Pivot)는 부위가 차지한 칸들 가운데 바닥.
	정면 = 모델 -Z(아군 쪽), +X = 라인 1 쪽(카메라 반대), 한 칸 = 6 스터드. 카메라는 -X 쪽 옆에서 보므로
	코드 줄 같은 잔 무늬는 -X 면에 더 많이 넣었다.

	rig: Apply(pose) — Root {x,y,z,rx,ry,rz}, Body {sx,sy,sz}(%) 는 슬라임 모션과 같은 뜻(Motions/Debug.luau).
	Float 조각은 모션과 따로 매 프레임 떠서 돌고 가끔 튄다(살아 있는 버그). Fade 는 쓰러질 때 연출이 올린다.
]]

local DebugBoss = {}
DebugBoss.__index = DebugBoss

local RAD = math.pi / 180
local RGB = Color3.fromRGB
local M = Enum.Material

local BODY = { RGB(34, 30, 48), M.Metal }
local PANEL = { RGB(58, 52, 80), M.SmoothPlastic }
local TRIM = { RGB(88, 80, 116), M.Metal }
local CYAN = { RGB(50, 170, 210), M.Neon } -- 코드 줄: 네온 번짐이 커서 조금 어둡게
local MAGENTA = { RGB(255, 70, 200), M.Neon }
local RED = { RGB(255, 48, 60), M.Neon }
local GREEN = { RGB(90, 255, 150), M.Neon }
local BANDAGE = { RGB(206, 198, 172), M.Fabric }

-- { 이름, 크기, 자리, 빛, 돌림(도)?, 꾸밈? }  꾸밈: "Float" 떠다님 · "Cyl" 원기둥(축 = 로컬 X)
type Spec = { any }

local function S(name: string, size: { number }, at: { number }, col: { any }, rot: { number }?, flag: string?): Spec
	return { name, size, at, col, rot or { 0, 0, 0 }, flag }
end

-- 한쪽 면에 코드 줄(가는 네온 띠) 여러 개. x 는 면 자리, rows = { {y, z, 길이}, … }
local function codeLines(list: { Spec }, x: number, rows: { { number } }, col: { any })
	for i, r in rows do
		table.insert(list, S("Code" .. i, { 0.1, 0.22, r[3] }, { x, r[1], r[2] }, col))
	end
end

local SPECS: { [string]: { Spec } } = {}

-- 머리(라인 2, 앞 두 열): 목이 뒤로 코어에 붙고, 얼굴 한가운데 붉은 중단점
do
	local h: { Spec } = {
		S("Neck", { 2.8, 3, 5.2 }, { 0, 3.2, 4.6 }, BODY),
		S("Head", { 4.6, 4.6, 4.8 }, { 0, 5.6, 0.8 }, BODY),
		S("Brow", { 4.9, 0.6, 5.2 }, { 0, 8.1, 0.8 }, TRIM),
		S("Chin", { 3.8, 0.8, 4 }, { 0, 3.05, 0.4 }, PANEL),
		S("Face", { 4.2, 4.0, 0.3 }, { 0, 5.6, -1.7 }, PANEL),
		S("Breakpoint", { 0.3, 3.0, 3.0 }, { 0, 5.7, -1.95 }, RED, { 0, 90, 0 }, "Cyl"),
		S("Glint", { 0.32, 0.9, 0.9 }, { -0.7, 6.4, -2.0 }, { RGB(255, 190, 190), M.Neon }, { 0, 90, 0 }, "Cyl"),
		S("FinL", { 0.4, 2.4, 2.2 }, { -2.5, 6.4, 1.8 }, TRIM, { 0, 0, -12 }),
		S("FinR", { 0.4, 2.4, 2.2 }, { 2.5, 6.4, 1.8 }, TRIM, { 0, 0, 12 }),
		S("Bit1", { 0.6, 0.6, 0.6 }, { 1.6, 9.3, 0.2 }, MAGENTA, { 20, 30, 10 }, "Float"),
		S("Bit2", { 0.4, 0.4, 0.4 }, { -1.3, 9.7, 1.5 }, CYAN, { 0, 45, 30 }, "Float"),
		S("Bit3", { 0.5, 0.5, 0.5 }, { 0.3, 10.2, -0.5 }, MAGENTA, { 35, 0, 15 }, "Float"),
	}
	codeLines(h, -2.36, { { 4.4, 0.6, 3.2 }, { 5.0, 1.4, 2.0 }, { 5.6, 0.2, 3.8 }, { 6.2, 1.8, 1.4 }, { 6.8, 0.9, 2.6 } }, CYAN)
	codeLines(h, -1.46, { { 3.6, 4.2, 3.4 }, { 4.3, 5.0, 2.0 } }, CYAN)
	SPECS.Head = h
end

-- 삭제 팔(라인 1, 앞 두 열): 어깨는 코어에 붙고 주먹이 앞으로. 주먹 앞면에 붉은 ✕
do
	local a: { Spec } = {
		S("Shoulder", { 4.8, 4.8, 4.2 }, { 0.3, 4.6, 5.0 }, BODY),
		S("Cap", { 5.2, 0.8, 4.6 }, { 0.3, 7.2, 5.0 }, TRIM),
		S("Upper", { 3.0, 3.0, 5.0 }, { 0.2, 3.9, 1.6 }, PANEL, { -8, 0, 0 }),
		S("Elbow", { 3.4, 3.4, 2.2 }, { 0.2, 3.0, -1.2 }, BODY),
		S("Fore", { 3.2, 2.6, 3.6 }, { 0.2, 2.4, -3.2 }, PANEL),
		S("Fist", { 4.4, 3.6, 2.6 }, { 0.2, 2.2, -5.5 }, BODY),
		S("Delete1", { 0.4, 3.4, 0.2 }, { 0.2, 2.2, -6.85 }, RED, { 0, 0, 45 }),
		S("Delete2", { 0.4, 3.4, 0.2 }, { 0.2, 2.2, -6.86 }, RED, { 0, 0, -45 }),
		S("Knuckle1", { 0.8, 0.8, 0.8 }, { -1.3, 4.2, -5.5 }, TRIM),
		S("Knuckle2", { 0.8, 0.8, 0.8 }, { 1.7, 4.2, -5.5 }, TRIM),
		S("Seam1", { 0.1, 0.25, 3.4 }, { -1.42, 2.4, -3.2 }, RED),
		S("Seam2", { 0.1, 0.25, 4.4 }, { -1.32, 4.0, 1.6 }, RED, { -8, 0, 0 }),
		S("Bit1", { 0.5, 0.5, 0.5 }, { 1.8, 5.4, -4.6 }, MAGENTA, { 20, 10, 40 }, "Float"),
		S("Bit2", { 0.35, 0.35, 0.35 }, { -1.5, 4.8, -6.2 }, RED, { 45, 0, 0 }, "Float"),
	}
	codeLines(a, -2.14, { { 3.6, 5.0, 2.6 }, { 4.4, 4.4, 1.6 }, { 5.2, 5.4, 3.0 } }, CYAN)
	SPECS.DeleteArm = a
end

-- 패치 팔(라인 3 — 카메라에 가장 가깝다, 머리를 가리지 않게 낮게): 손바닥에 초록 +, 팔에 붕대
do
	local a: { Spec } = {
		S("Shoulder", { 4.6, 4.2, 4.2 }, { -0.3, 3.9, 5.0 }, BODY),
		S("Cap", { 5.0, 0.7, 4.6 }, { -0.3, 6.3, 5.0 }, TRIM),
		S("Upper", { 2.8, 2.6, 5.0 }, { -0.2, 3.0, 1.6 }, PANEL),
		S("Wrap1", { 3.0, 0.5, 0.8 }, { -0.2, 3.0, 2.8 }, BANDAGE, { 0, 0, 8 }),
		S("Wrap2", { 3.0, 0.5, 0.8 }, { -0.2, 3.1, 0.6 }, BANDAGE, { 0, 0, -6 }),
		S("Elbow", { 3.2, 3.0, 2.0 }, { -0.2, 2.4, -1.2 }, BODY),
		S("Fore", { 3.0, 2.4, 3.4 }, { -0.2, 2.0, -3.2 }, PANEL),
		S("Wrap3", { 3.2, 0.5, 0.8 }, { -0.2, 2.1, -3.0 }, BANDAGE, { 0, 0, 5 }),
		S("Palm", { 4.2, 3.2, 0.8 }, { -0.2, 2.3, -5.3 }, BODY),
		S("Plus1", { 0.45, 2.4, 0.2 }, { -0.2, 2.3, -5.78 }, GREEN),
		S("Plus2", { 2.4, 0.45, 0.2 }, { -0.2, 2.3, -5.79 }, GREEN),
		S("Seam", { 0.1, 0.22, 3.2 }, { -1.72, 2.0, -3.2 }, GREEN),
		S("Bit1", { 0.45, 0.45, 0.45 }, { -1.8, 4.6, -4.2 }, GREEN, { 30, 0, 20 }, "Float"),
		S("Bit2", { 0.35, 0.35, 0.35 }, { 1.2, 5.2, -5.0 }, CYAN, { 0, 45, 45 }, "Float"),
	}
	codeLines(a, -2.62, { { 3.0, 5.2, 3.0 }, { 3.8, 4.6, 1.8 }, { 4.6, 5.6, 2.4 } }, CYAN)
	SPECS.PatchArm = a
end

-- 코어(뒤 네 열, 세 라인 전부): 큰 몸통 + 앞 어깨(팔 쪽)·목 소켓·마젠타 결정, 등 위로 오류 조각
do
	local c: { Spec } = {
		S("Foot1", { 3.6, 1.4, 3.6 }, { 5.5, 0.7, -6 }, BODY),
		S("Foot2", { 3.6, 1.4, 3.6 }, { -5.5, 0.7, -6 }, BODY),
		S("Foot3", { 3.6, 1.4, 3.6 }, { 5.5, 0.7, 6 }, BODY),
		S("Foot4", { 3.6, 1.4, 3.6 }, { -5.5, 0.7, 6 }, BODY),
		S("Torso", { 14, 8.6, 20 }, { 0, 5.6, -1 }, BODY),
		S("Top", { 15, 1, 21 }, { 0, 10.4, -1 }, TRIM),
		S("Hump", { 10, 3, 12 }, { 0, 12.4, 1 }, PANEL),
		S("ShoulderL1", { 4.2, 5.2, 4.2 }, { 6.3, 5.4, -11.8 }, BODY),
		S("ShoulderL3", { 4.2, 5.2, 4.2 }, { -6.3, 5.4, -11.8 }, BODY),
		S("Socket", { 3.4, 3.4, 3 }, { 0, 4.2, -12.2 }, BODY),
		S("Frame", { 6.4, 6.0, 0.6 }, { 0, 7.4, -11.3 }, TRIM),
		S("Chamber", { 5.2, 4.8, 0.6 }, { 0, 7.4, -11.4 }, { RGB(16, 12, 24), M.SmoothPlastic }),
		S("Crystal", { 2.4, 2.4, 2.4 }, { 0, 7.6, -12.1 }, MAGENTA, { 35, 45, 0 }, "Float"),
		S("Fin1", { 1, 3, 5 }, { 4, 13.4, 6.5 }, TRIM, { 25, 0, 0 }),
		S("Fin2", { 1, 3, 5 }, { -4, 13.4, 6.5 }, TRIM, { 25, 0, 0 }),
		S("Fin3", { 1, 3.6, 5 }, { 0, 14.2, 5 }, TRIM, { 30, 0, 0 }),
		S("Spine", { 2, 2, 6 }, { 0, 11.6, 9.6 }, PANEL, { -18, 0, 0 }),
		S("Err1", { 1.6, 1.6, 1.6 }, { 2.6, 15.8, -1.5 }, MAGENTA, { 20, 30, 10 }, "Float"),
		S("Err2", { 1.0, 1.0, 1.0 }, { -3.2, 16.6, 1.2 }, CYAN, { 0, 45, 30 }, "Float"),
		S("Err3", { 0.8, 0.8, 0.8 }, { 0.4, 17.4, 3.4 }, RED, { 35, 0, 15 }, "Float"),
		S("Err4", { 1.2, 1.2, 1.2 }, { -1.6, 15.2, -4.2 }, MAGENTA, { 10, 60, 0 }, "Float"),
		S("Err5", { 0.6, 0.6, 0.6 }, { 4.4, 16.9, 2.6 }, CYAN, { 45, 45, 0 }, "Float"),
		S("Err6", { 0.7, 0.7, 0.7 }, { -4.6, 14.9, -2.8 }, RED, { 0, 20, 45 }, "Float"),
		S("Err7", { 0.5, 0.5, 0.5 }, { 1.8, 18.2, 0.4 }, MAGENTA, { 30, 30, 30 }, "Float"),
	}
	-- 카메라 쪽(-X) 옆면: 코드 줄 여섯, 반대쪽 셋
	codeLines(c, -7.06, { { 3.0, -6, 7 }, { 4.0, -2, 11 }, { 5.0, -7, 5 }, { 6.0, 1, 9 }, { 7.0, -4, 12 }, { 8.0, 3, 6 } }, CYAN)
	codeLines(c, 7.06, { { 4.0, 0, 9 }, { 5.6, -3, 6 }, { 7.2, 2, 10 } }, CYAN)
	-- 몸통 앞면 가장자리 마젠타 띠(결정 쪽으로 모인다)
	table.insert(c, S("Seam1", { 0.25, 7, 0.1 }, { -4.2, 6.2, -11.06 }, MAGENTA))
	table.insert(c, S("Seam2", { 0.25, 7, 0.1 }, { 4.2, 6.2, -11.06 }, MAGENTA))
	SPECS.Core = c
end

DebugBoss.Parts = { "Head", "DeleteArm", "PatchArm", "Core" }

--[[
	부위 하나를 짓는다. 돌려주는 값이 곧 rig 다(`.Model`). home 은 Pivot 자리.
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
	for i, s in SPECS[key] or SPECS.Core do
		local size, at, col, rot, flag = s[2], s[3], s[4], s[5], s[6]
		local p = Instance.new("Part")
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
		if flag == "Cyl" then
			p.Shape = Enum.PartType.Cylinder
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
	for _, e in self.Parts do
		local rest = e.Rest
		local cf = base * CFrame.new(rest.X * sx, rest.Y * sy, rest.Z * sz) * rest.Rotation
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
