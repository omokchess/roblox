--!strict
--[[
	Callisto — 히든 보스 칼리스토의 몸·옷·얼굴·페이지 모습.
	2026-10-31 1·2판(파트 드레스·그린 얼굴) → 2026-11-01 3판(사용자):
	  "전체적으로 갈색 톤에 재킷을 걸치고(단추를 잠그지 않은 채 열림), 안에는 와이셔츠, 바지는 검은 바지 — 의수를 끼고, 의수 팔은 검을 끼고 있어야"
	  "머리카락은 카탈로그 Carmen" · "1페이즈 눈은 별무리로 가려 안 보이게, 눈·입·코 자리를 조정해 데포르메"
	  "2페이즈는 얼굴이 사라지고 우주 느낌으로 머리를 대체" · "3페이즈는 옷이 다 사라지고 우주가 사람 꼴로 빚어진 모습"

	사람 모양이라 R6 관절을 그대로 쓴다(CombatRig·전투 모션·무기가 붙는다). 정면 = 모델 -Z(전투에서는 아군 쪽).
	  옷  ReplicatedStorage.CallistoAssets.Outfit — 블렌더(models/build_callisto_outfit.py, 들여오기 tools/Callisto_Outfit.luau). 부품마다 속성
	      Host(관절 부품) · Offset(그 부품에서 본 CFrame) 대로 붙인다. 오른팔 = 스팀펑크 의수(관절 팔은 투명) — 검은 무기 CallistoArms(Main)
	  머리 ReplicatedStorage.CallistoAssets.Hair(카탈로그 70421887676551 "Carmen") — 손잡이를 머리 HairAttachment(0, 0.6, 0)에 맞춰 용접
	  들여온 것이 없으면(시험 환경) 맨몸 관절만.
	얼굴(1페이지) — 고전 머리 앞 투명 판(FacePlate)의 SurfaceGui: 눈 자리를 덮는 별무리 띠(반짝이는 별, 표정마다 밝기), 둥근 눈썹,
	  작은 코, 아래로 내린 작은 입, 크고 둥근 볼터치(데포르메), 띠 밑으로 흐르는 눈물.
	  Callisto.FaceOf(model) → face:Set(mood, 초?) 잠깐 표정 · face:SetBase(mood) 기본 표정
	  표정: Observe(1) · Resolve(2) · Sorrow(3, 눈물) · Attack · Aim · Cast · Hit · Guard · Dodge · Death · Smile
	페이지 — Callisto.SetPage(model, page)(한 번 넘어가면 되돌리지 않는다)
	  2  얼굴·머리·머리카락을 감추고 우주 머리: 유리 껍질 속 깊은 밤 + 성운 빛 + 별 입자 · 비스듬한 은하 원반 · 도는 별 셋 · 뒤로 흐르는 별빛 머리칼
	  3  옷·머리카락을 다 감추고 몸 관절이 밤하늘 유리(별 입자)로 — 몸통 앞엔 큰곰자리, 팔다리엔 별 셋과 빛줄(별자리)
	등 뒤 혼천의(고리 셋 + 별 핵 + 행성)와 둘레의 별가루는 그대로(천문학자).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Callisto = {}

local C = Color3.fromRGB
local JACKET = C(110, 74, 48)
local TROUSER = C(28, 28, 32)
local GOLD = C(222, 186, 104)
local SKIN = C(246, 228, 218)
local GLOW = C(150, 200, 255)
local STAR = C(214, 232, 255)
local NIGHT = C(18, 14, 46)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local RAD = math.pi / 180

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = Instance.new("Part")
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

local function weld(host: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = host, p
	w.Parent = p
end

-- 장식 하나를 관절 부품에 붙인다. at = 그 부품 공간 자리(x,y,z, 도 rx,ry,rz)
local function deco(model: Model, host: BasePart, name: string, size: Vector3, at: { number }, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = part(name, size, color, material, shape)
	p.CFrame = host.CFrame * CFrame.new(at[1], at[2], at[3]) * CFrame.Angles((at[4] or 0) * RAD, (at[5] or 0) * RAD, (at[6] or 0) * RAD)
	weld(host, p)
	p.Parent = model
	return p
end

local function stars(parent: Instance, rate: number, size: number, shape: Enum.ParticleEmitterShape?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(C(255, 255, 255), C(170, 200, 255))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(0.5, size * 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.4, 3)
	e.Rate = rate
	e.Speed = NumberRange.new(0, 0.2)
	e.LockedToPart = true
	e.Shape = shape or Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = parent
	return e
end

--=== 얼굴(1페이지 — SurfaceGui) ===--

local FACE_W, FACE_H = 200, 180
local FACE_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BROW = C(110, 78, 62)
local ROSE = C(206, 112, 132)
local BAND = C(12, 14, 38)
local BAND_GLOW = C(140, 170, 255)

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

type Twinkle = { Label: TextLabel, Phase: number, Speed: number }
type Face = {
	Gui: SurfaceGui,
	Brows: { Frame },
	Mouths: { [string]: GuiObject },
	Blush: { Frame },
	Tear: Frame,
	Stars: { Twinkle },
	Glow: UIStroke,
	Level: number,
	Base: string,
	Mood: string,
	Until: number,
	TearT: number,
	Set: (self: Face, mood: string?, hold: number?) -> (),
	SetBase: (self: Face, mood: string) -> (),
	Step: (self: Face, now: number, dt: number) -> (),
}

-- 표정 값: Brow = {안쪽 끝이 오르는 각(+ 슬픔 / − 노여움), 위아래(+ 위)} · Mouth = smile/line/open/frown/o · Blush = 볼터치 투명도 ·
-- Band = 별무리 띠의 밝기(0 꺼짐 ~ 1 번쩍) · Tear = 눈물(띠 밑에서 흐른다)
local MOODS: { [string]: { Brow: { number }, Mouth: string, Blush: number, Band: number, Tear: boolean } } = {
	Observe = { Brow = { 3, 0 }, Mouth = "smile", Blush = 0.55, Band = 0.4, Tear = false },
	Resolve = { Brow = { -9, 1 }, Mouth = "line", Blush = 0.68, Band = 0.55, Tear = false },
	Sorrow = { Brow = { 15, 2 }, Mouth = "frown", Blush = 0.45, Band = 0.25, Tear = true },
	Attack = { Brow = { -17, -2 }, Mouth = "open", Blush = 0.72, Band = 1, Tear = false },
	Aim = { Brow = { -5, 1 }, Mouth = "smile", Blush = 0.58, Band = 0.85, Tear = false },
	Cast = { Brow = { 7, 4 }, Mouth = "o", Blush = 0.55, Band = 0.95, Tear = false },
	Hit = { Brow = { 13, -1 }, Mouth = "open", Blush = 0.4, Band = 0.1, Tear = false },
	Guard = { Brow = { -13, 0 }, Mouth = "line", Blush = 0.68, Band = 0.65, Tear = false },
	Dodge = { Brow = { 2, 2 }, Mouth = "smile", Blush = 0.58, Band = 0.5, Tear = false },
	Death = { Brow = { 11, 0 }, Mouth = "smile", Blush = 0.45, Band = 0, Tear = true },
	Smile = { Brow = { 5, 1 }, Mouth = "smile", Blush = 0.35, Band = 0.5, Tear = false },
}
Callisto.MOODS = MOODS

-- 별무리 띠(176 × 44, 눈 자리 y 98 을 덮는다)의 별 { 띠 안 x, y, 크기, 글자, 색 } — 눈 자리(50·126)엔 큰 별 둘
local BAND_W, BAND_H, BAND_Y = 176, 44, 98
local BAND_STARS: { { any } } = {
	{ 50, 21, 17, "✦", STAR }, { 126, 21, 17, "✦", STAR }, { 16, 24, 9, "✦", GLOW }, { 30, 11, 6, "·", STAR },
	{ 36, 33, 8, "✧", GLOW }, { 66, 34, 7, "·", GOLD }, { 74, 12, 9, "✧", STAR }, { 88, 26, 11, "✦", GLOW },
	{ 100, 10, 6, "·", STAR }, { 108, 35, 7, "✧", STAR }, { 142, 12, 8, "✧", GOLD }, { 150, 31, 10, "✦", STAR },
	{ 164, 19, 6, "·", GLOW }, { 22, 37, 5, "·", STAR }, { 58, 6, 5, "·", STAR }, { 94, 39, 5, "·", GOLD },
	{ 118, 6, 5, "·", STAR }, { 136, 38, 5, "·", GLOW }, { 170, 34, 5, "·", STAR },
}

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
	-- 별무리 띠: 끝이 흐려지는 밤하늘 띠 + 테두리 빛 + 반짝이는 별
	local band = frame(gui, "StarBand", UDim2.fromOffset(BAND_W, BAND_H), UDim2.fromOffset(100, BAND_Y), BAND, 0.5, 0.06)
	band.ZIndex = 4
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.12, 0),
		NumberSequenceKeypoint.new(0.88, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	fade.Parent = band
	local glow = Instance.new("UIStroke")
	glow.Color = BAND_GLOW
	glow.Thickness = 1.5
	glow.Transparency = 0.6
	glow.Parent = band
	local twinkles: { Twinkle } = {}
	for i, s in BAND_STARS do
		local label = Instance.new("TextLabel")
		label.Name = "Star" .. i
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(s[3], s[3])
		label.Position = UDim2.fromOffset(s[1], s[2])
		label.BackgroundTransparency = 1
		label.Text = s[4]
		label.TextColor3 = s[5]
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.ZIndex = 5
		label.Parent = band
		table.insert(twinkles, { Label = label, Phase = i * 1.7, Speed = 1.6 + (i % 5) * 0.45 })
	end
	-- 데포르메: 눈썹은 띠 위로 짧고 둥글게 · 작은 코 · 입은 작게 아래로 · 볼터치는 크고 둥글게
	local brows = {
		frame(gui, "BrowL", UDim2.fromOffset(30, 6), UDim2.fromOffset(62, 66), BROW, 0.5),
		frame(gui, "BrowR", UDim2.fromOffset(30, 6), UDim2.fromOffset(138, 66), BROW, 0.5),
	}
	frame(gui, "Nose", UDim2.fromOffset(5, 3), UDim2.fromOffset(100, 127), C(214, 160, 150), 0.5, 0.35)
	local mouths: { [string]: GuiObject } = {}
	-- 웃음·찡그림: 둥근 테(UIStroke)의 아래·위 반만 보이게 잘라 둔다
	for _, kind in { "smile", "frown" } do
		local clip = Instance.new("Frame")
		clip.Name = "Mouth_" .. kind
		clip.AnchorPoint = Vector2.new(0.5, 0.5)
		clip.Size = UDim2.fromOffset(20, 7)
		clip.Position = UDim2.fromOffset(100, if kind == "smile" then 145 else 141)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = gui
		local ring = frame(clip, "Arc", UDim2.fromOffset(17, 11), UDim2.fromScale(0.5, if kind == "smile" then 0 else 1), C(0, 0, 0), 0.5, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = ROSE
		stroke.Thickness = 2.2
		stroke.Parent = ring
		mouths[kind] = clip
	end
	mouths.line = frame(gui, "Mouth_line", UDim2.fromOffset(11, 3), UDim2.fromOffset(100, 144), ROSE, 0.5)
	local open = frame(gui, "Mouth_open", UDim2.fromOffset(12, 10), UDim2.fromOffset(100, 145), C(150, 58, 84), 0.5)
	frame(open, "Tongue", UDim2.fromOffset(7, 3), UDim2.fromScale(0.5, 0.78), C(222, 120, 140), 0.5)
	mouths.open = open
	mouths.o = frame(gui, "Mouth_o", UDim2.fromOffset(7, 8), UDim2.fromOffset(100, 145), C(150, 58, 84), 0.5)
	local blush = {
		frame(gui, "BlushL", UDim2.fromOffset(34, 14), UDim2.fromOffset(44, 128), C(255, 150, 172), 0.5, 0.55),
		frame(gui, "BlushR", UDim2.fromOffset(34, 14), UDim2.fromOffset(156, 128), C(255, 150, 172), 0.5, 0.55),
	}
	-- 볼 위 별 점(오른쪽 — 별의 표식)
	local mark = Instance.new("TextLabel")
	mark.Name = "StarMark"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(10, 10)
	mark.Position = UDim2.fromOffset(164, 118)
	mark.BackgroundTransparency = 1
	mark.Text = "✦"
	mark.TextColor3 = GOLD
	mark.TextScaled = true
	mark.Font = Enum.Font.GothamBold
	mark.Parent = gui
	local tear = frame(gui, "Tear", UDim2.fromOffset(6, 10), UDim2.fromOffset(58, BAND_Y + 22), C(180, 222, 255), 0.5, 1)
	tear.ZIndex = 8
	local face: any = {
		Gui = gui,
		Brows = brows,
		Mouths = mouths,
		Blush = blush,
		Tear = tear,
		Stars = twinkles,
		Glow = glow,
		Level = 0.4,
		Base = "Observe",
		Mood = "Observe",
		Until = 0,
		TearT = 0,
	}
	local function apply(name: string, instant: boolean?)
		local m = MOODS[name] or MOODS.Observe
		face.Mood = name
		face.Level = m.Band
		local function tween(obj: Instance, goal: { [string]: any })
			if instant then
				for k, v in goal do
					(obj :: any)[k] = v
				end
			else
				TweenService:Create(obj, FACE_TWEEN, goal):Play()
			end
		end
		for i, brow in brows do
			local side = if i == 1 then -1 else 1
			-- 안쪽 끝이 오르면(+) 슬픔: 왼눈썹은 반시계(−), 오른눈썹은 시계(+)
			tween(brow, { Rotation = side * m.Brow[1], Position = UDim2.fromOffset(if i == 1 then 62 else 138, 66 - m.Brow[2]) })
		end
		for kind, mouth in mouths do
			mouth.Visible = kind == m.Mouth
		end
		for _, b in blush do
			tween(b, { BackgroundTransparency = m.Blush })
		end
		tween(glow, { Transparency = 0.85 - 0.6 * m.Band })
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
	-- 매 프레임(몸의 Heartbeat): 잠깐 표정이 끝나면 기본으로 · 별 반짝임(밝기 = 표정) · 눈물
	function face.Step(self: any, now: number, dt: number)
		if self.Until > 0 and now >= self.Until then
			self.Until = 0
			apply(self.Base)
		end
		local level = 0.25 + 0.75 * self.Level
		for _, s in self.Stars do
			s.Label.TextTransparency = 1 - level * (0.55 + 0.45 * math.sin(now * s.Speed + s.Phase))
		end
		local m = MOODS[self.Mood] or MOODS.Observe
		if m.Tear then
			-- 별무리 띠 밑(왼쪽)에서 볼을 따라 흘러내렸다 사라지기를 되풀이
			self.TearT = (self.TearT + dt / 1.8) % 1
			local k = self.TearT
			tear.Position = UDim2.fromOffset(58 - k * 4, BAND_Y + 22 + k * 34)
			tear.BackgroundTransparency = 0.15 + k * 0.85
		end
	end
	apply("Observe", true)
	return face :: Face
end

local faces: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
-- 페이지 모습에 쓰는 것: 입은 것(옷·머리카락) · 지금 페이지 · 우주 머리의 도는 관절
type Look = { Dressed: { BasePart }, Page: number, Disc: Motor6D?, Orbits: { Motor6D } }
local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any

-- 몸에 붙은 얼굴 조종기(없으면 nil)
function Callisto.FaceOf(model: Model): Face?
	return faces[model]
end

--=== 페이지 모습 ===--

-- 2페이지: 얼굴·머리·머리카락을 감추고 우주 머리(머리 관절에 붙어 모션을 따라간다)
local function cosmicHead(model: Model, look: Look, head: BasePart)
	head.Transparency = 1
	local plate = model:FindFirstChild("FacePlate")
	local gui = plate and plate:FindFirstChild("Face")
	if gui and gui:IsA("SurfaceGui") then
		gui.Enabled = false
	end
	local hair = model:FindFirstChild("Hair")
	if hair and hair:IsA("BasePart") then
		hair.Transparency = 1
	end
	local function attach(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: string?, c0: CFrame): (Part, Motor6D)
		local p = part(name, size, color, material, shape)
		p.Parent = model
		return p, motor(name .. "Joint", head, p, c0, CFrame.new())
	end
	local core = attach("CosmicCore", Vector3.new(1.45, 1.45, 1.45), C(8, 6, 24), Enum.Material.SmoothPlastic, "Ball", CFrame.new(0, 0.1, 0))
	local nebula = attach("CosmicNebula", Vector3.new(1.62, 1.62, 1.62), C(96, 64, 190), Enum.Material.Neon, "Ball", CFrame.new(0, 0.1, 0))
	nebula.Transparency = 0.86
	local shell = attach("CosmicShell", Vector3.new(1.78, 1.78, 1.78), C(28, 22, 70), Enum.Material.Glass, "Ball", CFrame.new(0, 0.1, 0))
	shell.Transparency = 0.25
	shell.Reflectance = 0.12
	stars(core, 18, 0.12, Enum.ParticleEmitterShape.Sphere)
	local light = Instance.new("PointLight")
	light.Color = C(150, 120, 255)
	light.Range, light.Brightness = 9, 1.6
	light.Parent = core
	local disc, discJoint = attach("CosmicDisc", Vector3.new(0.04, 2.7, 2.7), C(176, 150, 255), Enum.Material.Glass, "Cylinder", CFrame.new(0, 0.1, 0))
	disc.Transparency = 0.62
	look.Disc = discJoint
	for i, color in { STAR, GLOW, C(255, 214, 150) } do
		local _, joint = attach("CosmicOrbit" .. i, Vector3.new(0.16, 0.16, 0.16), color, Enum.Material.Neon, "Ball", CFrame.new())
		table.insert(look.Orbits, joint)
	end
	-- 뒤로 흐르는 별빛 머리칼
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0.3, 0.7)
	tail.Parent = core
	local stream = stars(core, 26, 0.16, nil)
	stream.Parent = tail
	stream.EmissionDirection = Enum.NormalId.Back
	stream.Speed = NumberRange.new(1.4, 2.8)
	stream.SpreadAngle = Vector2.new(18, 12)
	stream.LockedToPart = false
	stream.Lifetime = NumberRange.new(1, 1.8)
	stream.Color = ColorSequence.new(C(230, 236, 255), C(150, 110, 255))
end

-- 3페이지: 옷·머리카락을 모두 감추고 몸 관절이 밤하늘 유리로(별 입자 + 별자리)
local CONSTELLATIONS: { [string]: { { number } } } = {
	-- 몸통 앞: 큰곰자리(국자 넷 + 손잡이 셋)
	Torso = { { -0.62, 0.45 }, { -0.18, 0.52 }, { -0.12, 0.1 }, { -0.6, 0.02 }, { 0.22, -0.05 }, { 0.5, -0.3 }, { 0.78, -0.6 } },
	["Right Arm"] = { { 0.1, 0.6 }, { -0.15, 0.0 }, { 0.12, -0.55 } },
	["Left Arm"] = { { -0.1, 0.55 }, { 0.15, -0.05 }, { -0.1, -0.6 } },
	["Right Leg"] = { { 0.12, 0.6 }, { -0.1, -0.1 }, { 0.15, -0.7 } },
	["Left Leg"] = { { -0.12, 0.55 }, { 0.1, -0.15 }, { -0.14, -0.65 } },
}

local function cosmicBody(model: Model, look: Look)
	for _, p in look.Dressed do
		p.Transparency = 1
	end
	for name, dots in CONSTELLATIONS do
		local body = model:FindFirstChild(name)
		if not body or not body:IsA("BasePart") then
			continue
		end
		body.Transparency = 0.12
		body.Material = Enum.Material.Glass
		body.Color = NIGHT
		body.Reflectance = 0.1
		stars(body, 8, 0.1, nil)
		local front = -body.Size.Z / 2 - 0.02
		local points: { Vector3 } = {}
		for i, d in dots do
			local at = Vector3.new(d[1], d[2], front)
			table.insert(points, at)
			deco(model, body, "Constellation" .. i, Vector3.new(0.12, 0.12, 0.05), { at.X, at.Y, at.Z, 0, 0, 45 }, STAR, Enum.Material.Neon)
		end
		for i = 2, #points do
			local a, b = points[i - 1], points[i]
			local line = part("ConstellationLine", Vector3.new(0.03, 0.03, (b - a).Magnitude), GLOW, Enum.Material.Neon)
			line.Transparency = 0.35
			line.CFrame = body.CFrame * CFrame.lookAt((a + b) / 2, b)
			weld(body, line)
			line.Parent = model
		end
	end
end

--[[
	페이지 모습을 맞춘다(2 = 우주 머리, 3 = 우주 몸). 전투 화면이 스냅숏마다 부른다 — 이미 그 페이지면 아무 일도 없고, 되돌리지 않는다.
]]
function Callisto.SetPage(model: Model, page: number)
	local look = looks[model]
	local head = model:FindFirstChild("Head")
	if not look or not head or not head:IsA("BasePart") or page <= look.Page then
		return
	end
	if look.Page < 2 and page >= 2 then
		cosmicHead(model, look, head)
	end
	if look.Page < 3 and page >= 3 then
		cosmicBody(model, look)
	end
	look.Page = page
end

--=== 몸 ===--

-- 들여온 옷(블렌더)과 머리카락(카탈로그)을 붙인다. 없으면(시험 환경) 맨몸
local function dress(model: Model, head: BasePart): { BasePart }
	local dressed: { BasePart } = {}
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
	local outfit = kit and kit:FindFirstChild("Outfit")
	for _, src in (outfit and outfit:GetChildren()) or {} do
		local hostName, offset = src:GetAttribute("Host"), src:GetAttribute("Offset")
		local host = type(hostName) == "string" and model:FindFirstChild(hostName)
		if src:IsA("BasePart") and host and host:IsA("BasePart") and typeof(offset) == "CFrame" then
			local p = src:Clone()
			p.Anchored = false
			p.CFrame = host.CFrame * offset
			weld(host, p)
			p.Parent = model
			table.insert(dressed, p)
		end
	end
	local hair = kit and kit:FindFirstChild("Hair")
	local handle = hair and hair:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local h = handle:Clone()
		local att = h:FindFirstChild("HairAttachment")
		h.Name = "Hair"
		h.Anchored = false
		h.CanCollide, h.CanQuery, h.CanTouch, h.Massless = false, false, false, true
		-- 고전 머리(R6)의 HairAttachment 자리 (0, 0.6, 0) 에 손잡이 붙임점을 맞춘다
		h.CFrame = head.CFrame * CFrame.new(0, 0.6, 0) * (if att and att:IsA("Attachment") then att.CFrame:Inverse() else CFrame.new())
		weld(head, h)
		h.Parent = model
		table.insert(dressed, h)
	end
	return dressed
end

function Callisto.Build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), JACKET)
	root.Transparency = 1
	root.Anchored = true
	-- 관절 몸은 옷 밑 색(옷 틈으로 보여도 어울리게). 오른팔은 의수가 보이게 투명
	local torso = part("Torso", Vector3.new(2, 2, 1), JACKET)
	local head = part("Head", Vector3.new(2, 1, 1), SKIN)
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), JACKET)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), JACKET)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), TROUSER)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), TROUSER)
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

	--- 옷·머리카락(들여온 것) ---
	local dressed = dress(model, head)
	if #dressed > 0 then
		rightArm.Transparency = 1
	end
	-- 얼굴 판(투명) — SurfaceGui 로 그린다
	local plate = deco(model, head, "FacePlate", Vector3.new(1.0, 0.9, 0.04), { 0, 0.02, -0.63 }, SKIN)
	plate.Transparency = 1
	plate.CastShadow = false

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
			weld(ring, planet)
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

	--- 얼굴 + 매 프레임(혼천의·별가루·우주 머리·표정) ---
	local face: any = buildFace(plate)
	faces[model] = face
	local look: Look = { Dressed = dressed, Page = 1, Disc = nil, Orbits = {} }
	looks[model] = look
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
		if look.Disc and look.Disc.Parent then
			look.Disc.C0 = CFrame.new(0, 0.1, 0) * CFrame.Angles(0.35, t * 0.6, 1.2)
		end
		for i, joint in look.Orbits do
			if joint.Parent then
				local a = t * (1.1 + i * 0.35) + i * 2.1
				local tilt = CFrame.Angles(0, 0, (i - 2) * 0.6)
				joint.C0 = CFrame.new(0, 0.1, 0) * tilt * CFrame.new(math.cos(a) * 1.25, 0, math.sin(a) * 1.25)
			end
		end
		face:Step(now, dt)
	end)
	return model
end

return Callisto
