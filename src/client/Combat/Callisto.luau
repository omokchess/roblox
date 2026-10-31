--!strict
--[[
	Callisto — 히든 보스 칼리스토의 몸과 얼굴(2026-10-31, 같은 날 2판: 사용자 "레퍼런스를 참고해 퀄리티를 극대화하고 표정까지 — 칼리스토는 여캐").

	사람 모양이라 R6 관절을 그대로 쓴다(CombatRig·전투 모션·무기가 붙는다). 장식은 관절 부품에 용접해 모션을 따라간다.
	정면 = 모델 -Z(전투에서는 아군 쪽).

	레퍼런스(디자인 근거)
	  그리스 신화 칼리스토와 아르카스 — 큰곰자리(등 자수)와 작은곰자리(가슴의 일곱 별 펜던트 = 아들)
	  엘든 링 레날라(보름달의 여왕) — 별·달빛의 비극적인 어머니 보스: 은빛 머리, 푸른 빛, 슬픔이 깊어지는 페이지
	  원신 모나(점성술사) — 별 모티프 머리 장식, 남색·금의 대비
	  체스 비숍(기물군의 비숍) — 갈라진 주교관(작고 우아하게) + 뒤로 흐르는 베일, 대각선 이동(GridBattle bishopMove)
	  천문학자 — 등 뒤에서 천천히 도는 혼천의(고리 셋 + 별 핵 + 행성 둘), 외눈 렌즈
	  의체(사양) — 상아빛 도자기 판 + 금 테 + 푸른 별빛 마디(칼날·카메라는 무기 정의 CallistoArms / CallistoHammer)

	얼굴: 고전 머리(Head 메시)는 그대로 두고 그 앞에 투명한 판(FacePlate)을 붙여 SurfaceGui 로 그린다(눈 = 흰자·별빛 홍채(그라데이션)·
	동공·별 반짝임·눈꺼풀·속눈썹, 눈썹, 입 다섯 모양, 볼터치, 눈물, 눈 밑 별 점). 표정(Mood)은 이 부품들을 트윈한다.
	  Callisto.FaceOf(model)  →  face:Set(mood, 초?) 잠깐 표정 · face:SetBase(mood) 기본 표정(페이지) · 눈은 2.6~5초마다 깜빡
	  표정: Observe(1페이지) · Resolve(2페이지) · Sorrow(3페이지, 눈물) · Attack · Aim(윙크) · Cast · Hit · Guard · Dodge · Death · Smile
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Callisto = {}

local C = Color3.fromRGB
local NAVY = C(24, 30, 68)
local NAVY_DK = C(14, 18, 44)
local VIOLET = C(62, 46, 112)
local IVORY = C(240, 236, 228)
local GOLD = C(222, 186, 104)
local SKIN = C(246, 228, 218)
local HAIR = C(226, 228, 245)
local HAIR_DK = C(188, 194, 226)
local PORCELAIN = C(238, 236, 244)
local GLOW = C(150, 200, 255)
local STAR = C(214, 232, 255)

local RAD = math.pi / 180

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part") :: any
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = false
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = material ~= Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1, m.C0, m.C1 = p0, p1, c0, c1
	m.Parent = p0
	return m
end

-- 장식 하나를 관절 부품에 붙인다. at = 그 부품 공간 자리(x,y,z, 도 rx,ry,rz)
local function deco(model: Model, host: BasePart, name: string, size: Vector3, at: { number }, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = part(name, size, color, material, shape)
	p.CFrame = host.CFrame * CFrame.new(at[1], at[2], at[3]) * CFrame.Angles((at[4] or 0) * RAD, (at[5] or 0) * RAD, (at[6] or 0) * RAD)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = host, p
	weld.Parent = p
	p.Parent = model
	return p
end

--=== 얼굴(SurfaceGui) ===--

local FACE_W, FACE_H = 200, 180
local FACE_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LID_COLOR = SKIN
local LASH = C(40, 30, 64)
local BROW = C(150, 150, 190)
local ROSE = C(206, 112, 132)

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, round: number?, alpha: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

type Eye = { Box: Frame, Lid: Frame, Lash: Frame, Iris: Frame, Side: number }
type Face = {
	Eyes: { Eye },
	Brows: { Frame },
	Mouths: { [string]: GuiObject },
	Blush: { Frame },
	Tear: Frame,
	Base: string,
	Mood: string,
	Until: number,
	NextBlink: number,
	Blinking: number,
	TearT: number,
	Set: (self: Face, mood: string?, hold: number?) -> (),
	SetBase: (self: Face, mood: string) -> (),
}

-- 표정 값: Lid = 눈꺼풀이 덮는 비율(눈마다 {왼, 오른} 가능) · Brow = {안쪽 끝이 오르는 각(+ 슬픔 / − 노여움), 위아래(+ 위)} ·
-- Mouth = smile/line/open/frown/o · Blush = 볼터치 투명도 · Iris = 홍채 크기 · Tear = 눈물
local MOODS: { [string]: { Lid: any, Brow: { number }, Mouth: string, Blush: number, Iris: number, Tear: boolean } } = {
	Observe = { Lid = 0.3, Brow = { 3, 0 }, Mouth = "smile", Blush = 0.62, Iris = 1, Tear = false },
	Resolve = { Lid = 0.14, Brow = { -9, 1 }, Mouth = "line", Blush = 0.72, Iris = 1, Tear = false },
	Sorrow = { Lid = 0.36, Brow = { 15, 2 }, Mouth = "frown", Blush = 0.5, Iris = 1, Tear = true },
	Attack = { Lid = 0, Brow = { -17, -2 }, Mouth = "open", Blush = 0.78, Iris = 0.86, Tear = false },
	Aim = { Lid = { 0.06, 1 }, Brow = { -5, 1 }, Mouth = "smile", Blush = 0.62, Iris = 0.95, Tear = false },
	Cast = { Lid = 0.08, Brow = { 7, 4 }, Mouth = "o", Blush = 0.6, Iris = 1.05, Tear = false },
	Hit = { Lid = 0.86, Brow = { 13, -1 }, Mouth = "open", Blush = 0.45, Iris = 0.9, Tear = false },
	Guard = { Lid = 0.26, Brow = { -13, 0 }, Mouth = "line", Blush = 0.72, Iris = 0.95, Tear = false },
	Dodge = { Lid = { 0.18, 0.32 }, Brow = { 2, 2 }, Mouth = "smile", Blush = 0.62, Iris = 1, Tear = false },
	Death = { Lid = 1, Brow = { 11, 0 }, Mouth = "smile", Blush = 0.5, Iris = 1, Tear = true },
	Smile = { Lid = 0.5, Brow = { 5, 1 }, Mouth = "smile", Blush = 0.4, Iris = 1, Tear = false },
}
Callisto.MOODS = MOODS

local EYE_W, EYE_H = 42, 50

local function buildEye(gui: Instance, x: number, side: number): Eye
	local box = frame(gui, "Eye", UDim2.fromOffset(EYE_W, EYE_H), UDim2.fromOffset(x, 92), C(255, 255, 255), 0.5)
	box.ClipsDescendants = true
	box.ZIndex = 2
	local iris = frame(box, "Iris", UDim2.fromOffset(32, 40), UDim2.new(0.5, side * 1, 0.5, 4), C(96, 120, 230), 0.5)
	iris.ZIndex = 3
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C(48, 40, 124)),
		ColorSequenceKeypoint.new(0.55, C(92, 120, 230)),
		ColorSequenceKeypoint.new(1, C(160, 222, 255)),
	})
	gradient.Parent = iris
	local pupil = frame(iris, "Pupil", UDim2.fromOffset(12, 18), UDim2.fromScale(0.5, 0.52), C(22, 18, 52), 0.5)
	pupil.ZIndex = 4
	local glint = Instance.new("TextLabel")
	glint.Name = "Glint"
	glint.AnchorPoint = Vector2.new(0.5, 0.5)
	glint.Size = UDim2.fromOffset(18, 18)
	glint.Position = UDim2.fromScale(0.32, 0.3)
	glint.BackgroundTransparency = 1
	glint.Text = "✦"
	glint.TextColor3 = C(255, 255, 255)
	glint.TextScaled = true
	glint.Font = Enum.Font.GothamBold
	glint.ZIndex = 5
	glint.Parent = iris
	local dot = frame(iris, "Dot", UDim2.fromOffset(6, 6), UDim2.fromScale(0.7, 0.72), C(255, 255, 255), 0.5)
	dot.ZIndex = 5
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.Size = UDim2.fromScale(1, 0)
	lid.BackgroundColor3 = LID_COLOR
	lid.BorderSizePixel = 0
	lid.ZIndex = 6
	lid.Parent = box
	-- 아래 속눈썹(눈 밖 — 잘리지 않게 얼굴에 바로)
	local lower = frame(gui, "LowerLash", UDim2.fromOffset(26, 3), UDim2.fromOffset(x + side * 3, 92 + EYE_H / 2 + 1), LASH, 0.5, 0.35)
	lower.ZIndex = 3
	-- 위 속눈썹: 눈꺼풀 끝을 따라 내려온다(눈보다 넓고 바깥 끝이 살짝 올라간다)
	local lash = frame(gui, "Lash", UDim2.fromOffset(EYE_W + 10, 7), UDim2.fromOffset(x, 92 - EYE_H / 2), LASH, 0.5)
	lash.Rotation = side * 5
	lash.ZIndex = 7
	local flick = frame(lash, "Flick", UDim2.fromOffset(12, 4), UDim2.new(if side > 0 then 1 else 0, side * 3, 0.5, -2), LASH, 0.5)
	flick.Rotation = side * 30
	flick.ZIndex = 7
	return { Box = box, Lid = lid, Lash = lash, Iris = iris, Side = side }
end

local function buildFace(plate: BasePart): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(FACE_W, FACE_H)
	gui.LightInfluence = 0.55
	gui.Brightness = 1.15
	gui.ZOffset = 1
	gui.ClipsDescendants = false
	gui.Parent = plate
	-- 화면 왼쪽 눈 = 캐릭터 오른눈(side −1), 오른쪽 = 왼눈(side +1) — 바깥 끝이 side 쪽
	local eyes = { buildEye(gui, 62, -1), buildEye(gui, 138, 1) }
	local brows = {
		frame(gui, "BrowL", UDim2.fromOffset(36, 5), UDim2.fromOffset(60, 54), BROW, 0.5),
		frame(gui, "BrowR", UDim2.fromOffset(36, 5), UDim2.fromOffset(140, 54), BROW, 0.5),
	}
	local mouths: { [string]: GuiObject } = {}
	-- 웃음·찡그림: 둥근 테(UIStroke)의 아래·위 반만 보이게 잘라 둔다
	for _, kind in { "smile", "frown" } do
		local clip = Instance.new("Frame")
		clip.Name = "Mouth_" .. kind
		clip.AnchorPoint = Vector2.new(0.5, 0.5)
		clip.Size = UDim2.fromOffset(26, 8)
		clip.Position = UDim2.fromOffset(100, if kind == "smile" then 143 else 139)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = gui
		local ring = frame(clip, "Arc", UDim2.fromOffset(22, 14), UDim2.fromScale(0.5, if kind == "smile" then 0 else 1), C(0, 0, 0), 0.5, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = ROSE
		stroke.Thickness = 2.5
		stroke.Parent = ring
		mouths[kind] = clip
	end
	mouths.line = frame(gui, "Mouth_line", UDim2.fromOffset(14, 3), UDim2.fromOffset(100, 142), ROSE, 0.5)
	local open = frame(gui, "Mouth_open", UDim2.fromOffset(15, 12), UDim2.fromOffset(100, 143), C(150, 58, 84), 0.5)
	frame(open, "Tongue", UDim2.fromOffset(9, 4), UDim2.fromScale(0.5, 0.78), C(222, 120, 140), 0.5)
	mouths.open = open
	mouths.o = frame(gui, "Mouth_o", UDim2.fromOffset(8, 9), UDim2.fromOffset(100, 143), C(150, 58, 84), 0.5)
	local blush = {
		frame(gui, "BlushL", UDim2.fromOffset(30, 10), UDim2.fromOffset(52, 122), C(255, 150, 172), 0.5, 0.6),
		frame(gui, "BlushR", UDim2.fromOffset(30, 10), UDim2.fromOffset(148, 122), C(255, 150, 172), 0.5, 0.6),
	}
	-- 눈 밑 별 점(오른쪽 — 별의 표식)
	local mark = Instance.new("TextLabel")
	mark.Name = "StarMark"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(10, 10)
	mark.Position = UDim2.fromOffset(158, 112)
	mark.BackgroundTransparency = 1
	mark.Text = "✦"
	mark.TextColor3 = GOLD
	mark.TextScaled = true
	mark.Font = Enum.Font.GothamBold
	mark.Parent = gui
	local tear = frame(gui, "Tear", UDim2.fromOffset(6, 10), UDim2.fromOffset(56, 116), C(180, 222, 255), 0.5, 1)
	tear.ZIndex = 8
	local face: any = {
		Eyes = eyes,
		Brows = brows,
		Mouths = mouths,
		Blush = blush,
		Tear = tear,
		Base = "Observe",
		Mood = "Observe",
		Until = 0,
		NextBlink = os.clock() + 2 + math.random() * 2,
		Blinking = 0,
		TearT = 0,
	}
	local function lidOf(spec: any, i: number): number
		return if type(spec) == "table" then spec[i] else spec
	end
	local function apply(name: string, instant: boolean?)
		local m = MOODS[name] or MOODS.Observe
		face.Mood = name
		local function tween(obj: Instance, goal: { [string]: any })
			if instant then
				for k, v in goal do
					(obj :: any)[k] = v
				end
			else
				TweenService:Create(obj, FACE_TWEEN, goal):Play()
			end
		end
		for i, eye in eyes do
			local lid = lidOf(m.Lid, i)
			tween(eye.Lid, { Size = UDim2.new(1, 0, lid, if lid >= 1 then 2 else 0) })
			tween(eye.Lash, { Position = UDim2.fromOffset(eye.Box.Position.X.Offset, 92 - EYE_H / 2 + EYE_H * math.min(lid, 1)) })
			tween(eye.Iris, { Size = UDim2.fromOffset(32 * m.Iris, 40 * m.Iris) })
		end
		for i, brow in brows do
			local side = if i == 1 then -1 else 1
			-- 안쪽 끝이 오르면(+) 슬픔: 왼눈썹은 반시계(−), 오른눈썹은 시계(+)
			tween(brow, { Rotation = side * m.Brow[1], Position = UDim2.fromOffset(if i == 1 then 60 else 140, 54 - m.Brow[2]) })
		end
		for kind, mouth in mouths do
			mouth.Visible = kind == m.Mouth
		end
		for _, b in blush do
			tween(b, { BackgroundTransparency = m.Blush })
		end
		if not m.Tear then
			tear.BackgroundTransparency = 1
		end
	end
	function face.Set(self: any, mood: string?, hold: number?)
		if mood == nil then
			apply(self.Base)
			self.Until = 0
			return
		end
		apply(mood)
		self.Until = if hold then os.clock() + hold else math.huge
	end
	function face.SetBase(self: any, mood: string)
		self.Base = mood
		if self.Until <= os.clock() then
			apply(mood)
		end
	end
	-- 매 프레임(몸의 Heartbeat): 잠깐 표정이 끝나면 기본으로 · 깜빡임 · 눈물
	function face.Step(self: any, now: number, dt: number)
		if self.Until > 0 and now >= self.Until then
			self.Until = 0
			apply(self.Base)
		end
		local m = MOODS[self.Mood] or MOODS.Observe
		if now >= self.NextBlink and self.Blinking <= 0 and lidOf(m.Lid, 1) < 0.85 then
			self.Blinking = 0.16
			self.NextBlink = now + 2.6 + math.random() * 2.6
			for _, eye in eyes do
				TweenService:Create(eye.Lid, TweenInfo.new(0.06), { Size = UDim2.new(1, 0, 1, 2) }):Play()
				TweenService:Create(eye.Lash, TweenInfo.new(0.06), { Position = UDim2.fromOffset(eye.Box.Position.X.Offset, 92 + EYE_H / 2) }):Play()
			end
		end
		if self.Blinking > 0 then
			self.Blinking -= dt
			if self.Blinking <= 0 then
				apply(self.Mood)
			end
		end
		if m.Tear then
			-- 왼눈 밑에서 볼을 따라 흘러내렸다 사라지기를 되풀이
			self.TearT = (self.TearT + dt / 1.8) % 1
			local k = self.TearT
			tear.Position = UDim2.fromOffset(56 - k * 4, 116 + k * 36)
			tear.BackgroundTransparency = 0.15 + k * 0.85
		end
	end
	apply("Observe", true)
	return face :: Face
end

local faces: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any

-- 몸에 붙은 얼굴 조종기(없으면 nil)
function Callisto.FaceOf(model: Model): Face?
	return faces[model]
end

--=== 몸 ===--

function Callisto.Build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), NAVY)
	root.Transparency = 1
	root.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), NAVY)
	local head = part("Head", Vector3.new(2, 1, 1), SKIN)
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), PORCELAIN, Enum.Material.SmoothPlastic)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), PORCELAIN, Enum.Material.SmoothPlastic)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), NAVY_DK)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), NAVY_DK)
	for _, p in { root, torso, head, rightArm, leftArm, rightLeg, leftLeg } do
		p.Parent = model
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	model.PrimaryPart = root
	model:PivotTo(CFrame.new())
	torso.CFrame = root.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
	rightArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	leftArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)

	--- 몸통: 상아 블라우스 + 겹 주름 장식(자보) · 금 끈 코르셋 · 어깨 망토(케이프렛) · 작은곰자리 펜던트 ---
	deco(model, torso, "Blouse", Vector3.new(0.86, 1.1, 0.05), { 0, 0.42, -0.51 }, IVORY)
	for i, y in { 0.78, 0.6, 0.42 } do
		deco(model, torso, "Jabot" .. i, Vector3.new(0.5 - i * 0.06, 0.16, 0.12), { 0, y, -0.56 }, IVORY)
	end
	deco(model, torso, "Corset", Vector3.new(1.62, 0.92, 0.06), { 0, -0.42, -0.51 }, VIOLET)
	for i = 0, 3 do
		deco(model, torso, "Lace" .. i, Vector3.new(0.5, 0.04, 0.07), { 0, -0.12 - i * 0.2, -0.54, 0, 0, if i % 2 == 0 then 18 else -18 }, GOLD, Enum.Material.Metal)
	end
	deco(model, torso, "CorsetEdgeL", Vector3.new(0.06, 0.94, 0.08), { -0.82, -0.42, -0.52 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "CorsetEdgeR", Vector3.new(0.06, 0.94, 0.08), { 0.82, -0.42, -0.52 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "Collar", Vector3.new(1.3, 0.32, 1.0), { 0, 1.0, 0.04 }, IVORY)
	deco(model, torso, "CollarTrim", Vector3.new(1.34, 0.06, 1.04), { 0, 0.86, 0.04 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "Capelet", Vector3.new(2.5, 0.6, 1.3), { 0, 0.72, 0.03 }, NAVY)
	deco(model, torso, "CapeletHem", Vector3.new(2.54, 0.07, 1.34), { 0, 0.42, 0.03 }, GOLD, Enum.Material.Metal)
	-- 작은곰자리 펜던트(아들 아르카스): 일곱 별을 국자 꼴로
	for i, p in { { 0, 0.18 }, { 0.08, 0.08 }, { 0.14, -0.03 }, { 0.2, -0.13 }, { 0.32, -0.12 }, { 0.34, -0.24 }, { 0.22, -0.26 } } do
		deco(model, torso, "Arcas" .. i, Vector3.new(0.07, 0.07, 0.04), { p[1] - 0.16, 0.28 + p[2], -0.6 }, STAR, Enum.Material.Neon)
	end
	-- 허리 장식 띠(금)와 늘어진 술
	deco(model, torso, "Sash", Vector3.new(2.06, 0.18, 1.08), { 0, -0.92, 0 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "SashGem", Vector3.new(0.24, 0.24, 0.08), { 0, -0.92, -0.56, 0, 0, 45 }, GLOW, Enum.Material.Neon)
	deco(model, torso, "TasselL", Vector3.new(0.08, 0.8, 0.08), { -0.62, -1.38, -0.56 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "TasselR", Vector3.new(0.08, 0.66, 0.08), { 0.66, -1.32, -0.56 }, GOLD, Enum.Material.Metal)
	-- 등의 큰곰자리 자수(국자 넷 + 손잡이 셋) — 빛나는 점, 망토 위
	for i, p in { { -0.62, 0.15 }, { -0.18, 0.22 }, { -0.12, -0.2 }, { -0.6, -0.28 }, { 0.22, -0.35 }, { 0.5, -0.6 }, { 0.78, -0.9 } } do
		deco(model, torso, "UrsaStar" .. i, Vector3.new(0.12, 0.12, 0.05), { p[1], p[2], 0.54 }, GLOW, Enum.Material.Neon)
	end

	--- 치마: 몸통에 뒷자락(발목까지)·옆 두 폭, 다리마다 아래 자락(걸음을 따라간다) ---
	deco(model, torso, "SkirtBack", Vector3.new(2.15, 2.6, 0.14), { 0, -2.1, 0.58, 7, 0, 0 }, NAVY)
	deco(model, torso, "SkirtBackHem", Vector3.new(2.2, 0.1, 0.18), { 0, -3.36, 0.74, 7, 0, 0 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "SkirtSideL", Vector3.new(0.14, 1.5, 1.05), { -1.02, -1.6, 0.08, 0, 0, -6 }, NAVY)
	deco(model, torso, "SkirtSideR", Vector3.new(0.14, 1.5, 1.05), { 1.02, -1.6, 0.08, 0, 0, 6 }, NAVY)
	deco(model, torso, "SkirtFrontL", Vector3.new(0.86, 1.5, 0.12), { -0.55, -1.6, -0.56, -5, 0, -5 }, NAVY)
	deco(model, torso, "SkirtFrontR", Vector3.new(0.86, 1.5, 0.12), { 0.55, -1.6, -0.56, -5, 0, 5 }, NAVY)
	deco(model, torso, "Underskirt", Vector3.new(0.5, 1.4, 0.08), { 0, -1.6, -0.52 }, IVORY)
	for _, leg in { rightLeg, leftLeg } do
		local side = if leg == rightLeg then 1 else -1
		deco(model, leg, "Hem", Vector3.new(1.16, 1.0, 1.16), { 0.04 * side, -0.22, 0 }, NAVY)
		deco(model, leg, "HemTrim", Vector3.new(1.2, 0.08, 1.2), { 0.04 * side, -0.74, 0 }, GOLD, Enum.Material.Metal)
		deco(model, leg, "Boot", Vector3.new(0.9, 0.5, 1.02), { 0, -0.76, -0.06 }, NAVY_DK)
		deco(model, leg, "BootCuff", Vector3.new(0.94, 0.08, 1.06), { 0, -0.52, -0.06 }, GOLD, Enum.Material.Metal)
	end

	--- 머리: 은발(뒤로 길게·옆 머리 둘·앞머리 가닥), 작은 주교관 + 베일, 별 머리핀, 외눈 렌즈 ---
	deco(model, head, "HairCap", Vector3.new(1.36, 0.42, 1.32), { 0, 0.5, 0.04 }, HAIR)
	deco(model, head, "HairBack", Vector3.new(1.42, 1.3, 0.46), { 0, 0.04, 0.5 }, HAIR)
	deco(model, head, "HairLong", Vector3.new(1.32, 2.2, 0.36), { 0, -1.45, 0.62, 6, 0, 0 }, HAIR)
	deco(model, head, "HairLongTip", Vector3.new(1.0, 0.5, 0.3), { 0, -2.75, 0.76, 6, 0, 0 }, HAIR_DK)
	deco(model, head, "LockL", Vector3.new(0.26, 1.7, 0.32), { -0.66, -0.62, -0.18, 0, 0, 4 }, HAIR)
	deco(model, head, "LockR", Vector3.new(0.26, 1.7, 0.32), { 0.66, -0.62, -0.18, 0, 0, -4 }, HAIR)
	deco(model, head, "LockTipL", Vector3.new(0.18, 0.4, 0.24), { -0.7, -1.6, -0.2, 0, 0, 10 }, HAIR_DK)
	deco(model, head, "LockTipR", Vector3.new(0.18, 0.4, 0.24), { 0.7, -1.6, -0.2, 0, 0, -10 }, HAIR_DK)
	-- 앞머리: 가르마 한쪽으로 넘긴 가닥 넷(쐐기)
	-- 눈썹(얼굴 판 y +0.2)이 앞머리 아래로 보이게 가닥 끝을 그 위에 둔다
	for i, s in { { -0.42, 0.44, 18 }, { -0.14, 0.47, 8 }, { 0.16, 0.45, -6 }, { 0.44, 0.4, -16 } } do
		deco(model, head, "Bang" .. i, Vector3.new(0.34, 0.42, 0.14), { s[1], s[2], -0.6, 0, 180, s[3] }, HAIR, nil, "Wedge")
	end
	-- 주교관(작게, 뒤로 살짝 눕혀) — 갈라진 두 쪽 + 금테 + 별
	deco(model, head, "MitreBand", Vector3.new(1.0, 0.16, 1.0), { 0, 0.7, 0.12, -10, 0, 0 }, GOLD, Enum.Material.Metal)
	deco(model, head, "MitreF", Vector3.new(0.86, 0.9, 0.42), { 0, 1.2, -0.06, -10, 0, 0 }, IVORY, nil, "Wedge")
	deco(model, head, "MitreB", Vector3.new(0.86, 0.9, 0.42), { 0, 1.18, 0.34, -10, 180, 0 }, IVORY, nil, "Wedge")
	deco(model, head, "MitreStripe", Vector3.new(0.12, 0.92, 0.86), { 0, 1.18, 0.14, -10, 0, 0 }, GOLD, Enum.Material.Metal)
	deco(model, head, "MitreStar", Vector3.new(0.2, 0.2, 0.05), { 0, 1.05, -0.3, -10, 0, 45 }, GLOW, Enum.Material.Neon)
	-- 베일: 주교관 뒤에서 허리까지 흐르는 반투명 천 + 별 점
	local veil = deco(model, head, "Veil", Vector3.new(1.5, 3.4, 0.05), { 0, -0.95, 0.86, 8, 0, 0 }, C(214, 226, 255))
	veil.Transparency = 0.55
	for i, p in { { -0.4, 0.2 }, { 0.3, -0.4 }, { -0.2, -1.1 }, { 0.45, -1.6 }, { -0.35, -2.1 } } do
		deco(model, head, "VeilStar" .. i, Vector3.new(0.07, 0.07, 0.04), { p[1], -0.95 + p[2], 0.84 + p[2] * -0.14 }, STAR, Enum.Material.Neon)
	end
	-- 별 머리핀(왼쪽)
	deco(model, head, "HairPin", Vector3.new(0.24, 0.24, 0.06), { -0.58, 0.38, -0.36, 0, 30, 45 }, STAR, Enum.Material.Neon)
	deco(model, head, "HairPinTail", Vector3.new(0.05, 0.32, 0.05), { -0.6, 0.18, -0.3, 0, 30, -20 }, GOLD, Enum.Material.Metal)
	-- 외눈 렌즈: 오른눈(몸 +X = 정면에서 보아 왼쪽 — SurfaceGui 왼쪽 눈과 같은 자리) 위에 테만 얇게
	deco(model, head, "MonocleRim", Vector3.new(0.04, 0.34, 0.34), { 0.19, 0.02, -0.66, 0, 90, 0 }, GOLD, Enum.Material.Metal, "Cylinder").Transparency = 0.1
	deco(model, head, "MonocleChain", Vector3.new(0.03, 0.62, 0.03), { 0.4, -0.24, -0.6, 0, 0, 25 }, GOLD, Enum.Material.Metal)
	-- 얼굴 판(투명) — SurfaceGui 로 그린다
	local plate = deco(model, head, "FacePlate", Vector3.new(1.0, 0.9, 0.04), { 0, 0.02, -0.63 }, SKIN)
	plate.Transparency = 1
	plate.CastShadow = false

	--- 의체 팔: 상아빛 도자기 판 · 금 테 · 푸른 별빛 마디 · 가는 손 ---
	for _, arm in { rightArm, leftArm } do
		local side = if arm == rightArm then 1 else -1
		deco(model, arm, "Shoulder", Vector3.new(1.18, 0.46, 1.14), { 0.05 * side, 0.82, 0 }, PORCELAIN)
		deco(model, arm, "ShoulderTrim", Vector3.new(1.2, 0.06, 1.16), { 0.05 * side, 0.6, 0 }, GOLD, Enum.Material.Metal)
		deco(model, arm, "ShoulderGem", Vector3.new(0.18, 0.18, 0.06), { 0.05 * side, 0.82, -0.6, 0, 0, 45 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Elbow", Vector3.new(1.04, 0.2, 1.04), { 0, -0.05, 0 }, GOLD, Enum.Material.Metal)
		deco(model, arm, "ElbowGlow", Vector3.new(1.06, 0.05, 1.06), { 0, -0.05, 0 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Filigree", Vector3.new(0.04, 1.1, 0.04), { 0.51 * side, -0.4, -0.25 }, GOLD, Enum.Material.Metal)
		deco(model, arm, "FiligreeB", Vector3.new(0.04, 0.5, 0.04), { 0.51 * side, -0.6, 0.2, 0, 0, 20 * side }, GOLD, Enum.Material.Metal)
		deco(model, arm, "Wrist", Vector3.new(0.96, 0.14, 0.96), { 0, -0.72, 0 }, GOLD, Enum.Material.Metal)
		deco(model, arm, "WristGlow", Vector3.new(0.98, 0.04, 0.98), { 0, -0.72, 0 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Hand", Vector3.new(0.78, 0.36, 0.78), { 0, -0.98, 0 }, PORCELAIN)
	end

	--- 등 뒤 혼천의: 별 핵 + 고리 셋(도는 모터) + 행성 둘 — 매 프레임 돈다 ---
	local hub = part("OrreryHub", Vector3.new(0.2, 0.2, 0.2), GOLD)
	hub.Transparency = 1
	hub.Parent = model
	motor("Orrery", torso, hub, CFrame.new(0, 1.0, 1.45), CFrame.new())
	local core = part("OrreryCore", Vector3.new(0.5, 0.5, 0.5), STAR, Enum.Material.Neon, "Ball")
	core.Parent = model
	motor("OrreryCoreJoint", hub, core, CFrame.new(), CFrame.new())
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 9
	light.Brightness = 1.6
	light.Parent = core
	local rings: { Motor6D } = {}
	for i, r in { { 2.3, 0 }, { 1.9, 60 }, { 1.5, -50 } } do
		local ring = part("OrreryRing" .. i, Vector3.new(0.06, r[1], r[1]), GOLD, Enum.Material.Neon, "Cylinder")
		ring.Transparency = 0.25
		ring.Parent = model
		rings[i] = motor("OrreryRingJoint" .. i, hub, ring, CFrame.Angles(0, 0, r[2] * RAD), CFrame.new())
		-- 고리 가장자리의 행성(고리와 함께 돈다)
		if i <= 2 then
			local planet = part("OrreryPlanet" .. i, Vector3.new(0.18, 0.18, 0.18), if i == 1 then GLOW else C(255, 214, 150), Enum.Material.Neon, "Ball")
			planet.CFrame = ring.CFrame * CFrame.new(0, r[1] / 2, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = ring, planet
			weld.Parent = planet
			planet.Parent = model
		end
	end
	-- 둘레를 떠도는 별가루 셋
	local motes: { Motor6D } = {}
	for i = 1, 3 do
		local mote = part("Mote" .. i, Vector3.new(0.16, 0.16, 0.16), STAR, Enum.Material.Neon, "Ball")
		mote.Parent = model
		motes[i] = motor("MoteJoint" .. i, torso, mote, CFrame.new(), CFrame.new())
	end

	--- 얼굴 + 매 프레임(혼천의·별가루·표정) ---
	local face: any = buildFace(plate)
	faces[model] = face
	local t0 = math.random() * 10
	-- 한 번 자리에 놓인 뒤 부모가 사라지면(치워짐) 스스로 끊는다
	local placed = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			if placed then
				conn:Disconnect()
			end
			return
		end
		placed = true
		local now = os.clock()
		local t = now + t0
		for i, joint in rings do
			if joint.Parent then
				local tilt = ({ 0, 60, -50 })[i] * RAD
				joint.C0 = CFrame.Angles(0, 0, tilt) * CFrame.Angles(t * (0.35 + i * 0.22) * (if i == 2 then -1 else 1), 0, 0)
			end
		end
		for i, joint in motes do
			if joint.Parent then
				local a = t * 0.8 + i * 2.1
				joint.C0 = CFrame.new(math.cos(a) * 1.7, 0.6 + math.sin(t * 1.3 + i) * 0.5, math.sin(a) * 1.2)
			end
		end
		face:Step(now, dt)
	end)
	return model
end

return Callisto
