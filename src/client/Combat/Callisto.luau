--!strict
--[[
	Callisto — 히든 보스 칼리스토의 몸·옷·얼굴·페이즈 모습.
	2026-10-31 1·2판(파트 드레스·그린 얼굴) → 2026-11-01 3판(사용자):
	  "전체적으로 갈색 톤에 재킷을 걸치고(단추를 잠그지 않은 채 열림), 안에는 와이셔츠, 바지는 검은 바지 — 의수를 끼고, 의수 팔은 검을 끼고 있어야"
	  "머리카락은 카탈로그 Carmen" · "1페이즈 눈은 별무리로 가려 안 보이게, 눈·입·코 자리를 조정해 데포르메"
	  "2페이즈는 얼굴이 사라지고 우주 느낌으로 머리를 대체" · "3페이즈는 옷이 다 사라지고 우주가 사람 꼴로 빚어진 모습"
	2026-11-01 4판(사용자): "의수를 놓지 말고 그냥 팔을 검으로 · 얼굴엔 블렌더 가면 · 로블록스 느낌 없이 최대한 퀄리티 높게,
	  체형은 로블록스에 맞춰 · 재질도 진짜 옷 재질처럼" — 옷·가면은 GLB(SurfaceAppearance PBR), 옷을 입으면 관절 몸은 감춘다.
	2026-11-01 5판(사용자): "옷이랑 바지는 이거 입히자" — 블렌더 옷·가면(Outfit) 대신 카탈로그 고전 셔츠·바지. 몸 다섯 부위는 피부색으로 보이게 두고
	  Humanoid(R6, 상태 기계 끔)를 넣어 Shirt·Pants 를 입힌다. 가면이 없으니 1페이즈 얼굴은 그린 얼굴.

	사람 모양이라 R6 관절을 그대로 쓴다(CombatRig·전투 모션·무기가 붙는다). 정면 = 모델 -Z(전투에서는 아군 쪽).
	  옷  셔츠 카탈로그 11985252397 "Mad Scientist Dark Shirt" · 바지 카탈로그 11924564943 "Bondrewd Delver Scientist Black Pants"(아래 SHIRT_TEMPLATE · PANTS_TEMPLATE).
	      오른팔 = 말레니아식 금빛 의수(2026-11-07 — ReplicatedStorage.CallistoAssets.Prosthetic, models/build_callisto_prosthetic.py · tools/Callisto_Prosthetic.luau)가 손으로 칼 슴베를 쥐고 날이 손에서 이어진다
        (오른팔 부위는 투명 — 셔츠 소매 대신 의수가 보인다. 의수가 없으면(시험 환경) 지금처럼 소매. 2페이즈에 우주 팔로 바뀌며 함께 사라진다)
      칼 = 무기 CallistoArms Main, 팔 축 고정
	      (ReplicatedStorage.CallistoAssets.Outfit — 블렌더 옷 4판은 스튜디오에 그대로 남아 있다. 지금은 붙이지 않는다 — 동업자가 옷을 전면 수정할 때 쓸 수 있다.
	       부품마다 속성 Host(관절 부품) · Offset(그 부품에서 본 CFrame), 만든 곳 models/build_callisto_outfit.py · tools/Callisto_Outfit.luau)
	  머리 ReplicatedStorage.CallistoAssets.Hair(카탈로그 70421887676551 "Carmen") — 손잡이를 머리 HairAttachment(0, 0.6, 0)에 맞춰 용접
	  머리카락이 없으면(시험 환경) 맨머리.
	얼굴(1페이즈) — FacePlate 의 SurfaceGui: 둥근 눈썹, 작은 코, 작은 입, 볼터치. 눈은 3D 별 눈가리개(buildBlindfold)가 가린다.
  별 눈가리개(2026-11-07 사용자: "별들이 모여서 생긴 눈가리개처럼") — 반투명 성운 띠 + 촘촘한 작은 별(Neon 구 · ✦ 반짝임) + 가는 별자리 빛줄(Beam). 별이 띠를 따라 물결로 흐르며 반짝인다. 안 고르기 V_Blindfold 1~3.
	  Callisto.FaceOf(model) → face:Set(mood, 초?) 잠깐 표정 · face:SetBase(mood) 기본 표정
	  표정 이름(Observe · Resolve · Sorrow · Attack · …)은 받지만 얼굴은 늘 같다 — 2026-11-01 사용자: "입은 무표정, 표정 변화 딱히 없게"
	페이즈 — Callisto.SetPage(model, page, fade?)(한 번 넘어가면 되돌리지 않는다 — 컷신이 그 순간에 부른다)
	  2  얼굴·머리·머리카락이 사라지고 우주 머리(고전 머리 윤곽 + 빛나는 하얀 테두리로 오려 낸 우주 그림 창 — Combat/SpaceLayer · 도는 별 셋),
	     팔 검·오른 소매(오른팔 부위 — 셔츠 소매도 부위 투명도와 함께 사라진다)가 부서져 그 자리를 우주를 담은 팔이 채운다(2026-11-01 컷신 사양)
	  3  옷이 모두 사라지고(fade 초에 걸쳐 — 몸 부위가 투명해지고 끝나면 셔츠·바지를 지운다) 그동안 몸 전체(몸통·팔다리 상자 윤곽)가 우주 그림 창으로 나타난다(Combat/SpaceLayer)
	팔 검 — Callisto.Blade(model, out, 초?) 날(무기 CallistoArms Main)이 소매 속에서 미끄러져 나오고 들어간다
	  (Weld C0 를 날 축(+Z)으로 밀며 투명도도 함께). 시작 컷신이 시험하고, 전투 중엔 기술을 쓸 때만 나온다(CombatDirector).
	등 뒤 혼천의(고리 셋 + 별 핵 + 행성)와 둘레의 별가루는 그대로(천문학자).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SpaceLayer = require(script.Parent.SpaceLayer)

local Callisto = {}

local ORBIT_STARS = 9 -- 2페이즈부터 우주 머리 둘레를 도는 별
local MOTES = 9 -- 몸 둘레를 떠도는 별가루

local C = Color3.fromRGB
local GOLD = C(222, 186, 104)
local SKIN = C(246, 228, 218)
local GLOW = C(150, 200, 255)
local STAR = C(214, 232, 255)

local RAD = math.pi / 180

-- 카탈로그 id 와 옷 그림(템플릿) id 는 다르다 — 스튜디오 InsertService:LoadAsset 으로 읽은 템플릿 id(2026-11-01)
local SHIRT_TEMPLATE = "rbxassetid://11985252365" -- 카탈로그 11985252397 Mad Scientist Dark Shirt
local PANTS_TEMPLATE = "rbxassetid://11924564913" -- 카탈로그 11924564943 Bondrewd Delver Scientist Black Pants

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

--=== 얼굴(1페이즈 — SurfaceGui) ===--

local FACE_W, FACE_H = 200, 180
local FACE_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BROW = C(110, 78, 62)
local ROSE = C(206, 112, 132)
local BAND_Y = 98 -- 눈 자리(눈물이 흘러내리는 시작 높이)

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

type Face = {
	Gui: SurfaceGui,
	Brows: { Frame },
	Mouths: { [string]: GuiObject },
	Blush: { Frame },
	Tear: Frame,
	Level: number,
	Base: string,
	Mood: string,
	Until: number,
	TearT: number,
	Set: (self: Face, mood: string?, hold: number?) -> (),
	SetBase: (self: Face, mood: string) -> (),
	Step: (self: Face, now: number, dt: number) -> (),
}

-- 표정 값: Brow = {안쪽 끝이 오르는 각, 위아래} · Mouth = smile/line/open/frown/o · Blush = 볼터치 투명도 · Band = (쓰지 않음) · Tear = 눈물.
-- 2026-11-01 사용자: "입은 무표정, 표정 변화 딱히 없게" — 어떤 표정 이름이든 같은 얼굴(일자 입 · 곧은 눈썹 · 띠 밝기 일정 · 눈물 없음)
local NEUTRAL = { Brow = { 0, 0 }, Mouth = "line", Blush = 0.6, Band = 0.5, Tear = false }
local MOODS: { [string]: typeof(NEUTRAL) } = setmetatable({}, {
	__index = function()
		return NEUTRAL
	end,
}) :: any
Callisto.MOODS = MOODS

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
	-- 매 프레임(몸의 Heartbeat): 잠깐 표정이 끝나면 기본으로 · 눈물
	function face.Step(self: any, now: number, dt: number)
		if self.Until > 0 and now >= self.Until then
			self.Until = 0
			apply(self.Base)
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
-- 페이즈 모습에 쓰는 것: 붙인 것(머리카락 — 셔츠·바지는 부품이 아니라 몸 부위에 그려진다) · 지금 페이즈 · 우주 머리의 도는 관절
type Arm = { Joint: Motor6D, Base: CFrame, Phase: number, Sway: number }
type Look = { Dressed: { BasePart }, Blindfold: any?, Prosthetic: { BasePart }, Page: number, Orbits: { Motor6D }, Halo: Motor6D?, HaloGlow: BasePart?, Arms: { Arm } }
local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any

-- 몸에 붙은 얼굴 조종기(없으면 nil)
function Callisto.FaceOf(model: Model): Face?
	return faces[model]
end

--=== 별 눈가리개(1페이즈) ===--
--[[
	2026-11-07 2판(QA 반려: "불투명한 검은 띠 위에 점을 찍은 머리띠로 보인다 — 띠 자체가 별로 이루어져야 한다").
	검은 띠를 없앴다. 머리를 감는 **반투명 성운 빛 띠**(청백·보라 안개 — 조각마다 SurfaceGui 세로 그라디언트라 위아래 가장자리가 부드럽게 풀린다, Neon 아님)가
	눈을 은은히 덮고, 그 위에 크기 다른 별(Neon 구 · 큰 별은 ✦ 반짝임)이 훨씬 촘촘하다 — 눈 자리(±19°)는 특히 빽빽하고,
	위아래 가장자리로 갈수록 별 밀도가 흩어지며 사라진다. 별자리 선(Beam)은 큰 별끼리 가늘게 몇 줄만. 별빛이 띠를 따라 천천히 흐르는 물결은 그대로.
	별 자리는 고정 씨앗(Random.new(11))으로 한 번 뿌린다(모든 클라이언트가 같은 하늘) — 밀도 = 앞쪽 > 옆·뒤, 눈 자리 가중, 세로로 멀수록 성김.
	안 고르기(src/shared/Variant.luau — Studio workspace 속성 V_Blindfold = 1 · 2 · 3):
	  1 A안(기본) 성운 띠 + 촘촘한 별 · 2 B안 안개 거의 없이 별만 훨씬 빽빽(별 ×1.5) · 3 C안 넓고 짙은 성운 + 별은 성기고 큼(×0.65)
	머리 윤곽(고전 머리 메시 ×1.25, 반폭 ≈ 0.62)을 옆면·뒤까지 감는다. 2페이즈에 얼굴과 함께 사라진다.
]]
local BF_R = 0.665 -- 별 놓이는 반지름
local BF_Y = -0.03 -- 띠 가운데 높이(눈 자리)
-- 안: 안개 가운데 투명도 · 안개 높이 · 별 밀도 · 큰 별 비율 가중
local BF_LOOKS = {
	[1] = { Haze = 0.52, HazeH = 0.34, Density = 1.0, Big = 1.0 },
	[2] = { Haze = 0.93, HazeH = 0.3, Density = 1.5, Big = 1.0 },
	[3] = { Haze = 0.36, HazeH = 0.46, Density = 0.65, Big = 1.9 },
}
local BF_SIZE = { 0.03, 0.048, 0.075, 0.115 }
local BF_COLORS = { STAR, GLOW, C(255, 226, 170), C(206, 184, 255) }
local BF_NEBULA_A, BF_NEBULA_B = C(150, 190, 255), C(182, 140, 255) -- 청백 ↔ 보라

local function bfPos(a: number, y: number, wave: number): Vector3
	local r = math.rad(a + wave)
	return Vector3.new(math.sin(r) * BF_R, y, -math.cos(r) * BF_R)
end

-- 별 자리: { 각(도, 앞 0 · 오른쪽 +), 높이, 크기 등급 1~4 }
local function scatterStars(look: { Density: number, Big: number }): { { number } }
	local rng = Random.new(11)
	local out: { { number } } = {}
	for row = 0, 16 do
		local y0 = -0.27 + row * 0.03
		local dy = y0 - BF_Y
		local vert = math.exp(-((dy / 0.15) ^ 2))
		for col = 0, 77 do
			local a0 = col * 360 / 78
			local ang = (a0 + 180) % 360 - 180 -- -180..180, 0 = 앞
			local front = 0.18 + 0.82 * math.max(0, math.cos(math.rad(ang))) ^ 1.3
			local eye = 1 + 1.3 * math.exp(-(((math.abs(ang) - 19) / 20) ^ 2) - (dy / 0.07) ^ 2)
			if rng:NextNumber() < math.min(0.9, 0.26 * look.Density * front * vert * eye) then
				local k = rng:NextNumber()
				local grade = if k < 0.58 then 1 elseif k < 0.86 then 2 elseif k < 0.96 then 3 else 4
				if grade < 4 and rng:NextNumber() < 0.06 * (look.Big - 1) then
					grade += 1
				end
				table.insert(out, { ang + rng:NextNumber(-2, 2), y0 + rng:NextNumber(-0.012, 0.012), grade })
			end
		end
	end
	return out
end

local function buildBlindfold(model: Model, head: BasePart): any
	local Variant = require(ReplicatedStorage.Shared.Variant)
	local look = BF_LOOKS[Variant.Index("Blindfold", 3)]
	local pieces: { BasePart } = {}
	local guis: { SurfaceGui } = {}
	-- 성운 띠: 스무 조각 다각 고리 두 겹(청백 · 보라). 조각은 투명, SurfaceGui 세로 그라디언트가 안개를 그린다
	local segs = 20
	for layer = 1, 2 do
		local r = BF_R - (if layer == 1 then 0.014 else 0.03)
		local h = look.HazeH * (if layer == 1 then 1 else 0.72)
		local peak = math.min(0.97, look.Haze + (if layer == 1 then 0 else 0.12))
		local w = 2 * r * math.tan(math.pi / segs) * 1.03
		for i = 0, segs - 1 do
			local a = i / segs * 360
			local p = deco(model, head, "BlindfoldHaze", Vector3.new(w, h, 0.02), { math.sin(math.rad(a)) * r, BF_Y, -math.cos(math.rad(a)) * r, 0, -a, 0 }, BF_NEBULA_A, Enum.Material.SmoothPlastic)
			p.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 60
			gui.LightInfluence = 0
			gui.Brightness = 2
			gui.AlwaysOnTop = false
			gui.Parent = p
			local mix = 0.5 + 0.5 * math.sin(math.rad(a) * 2 + layer * 1.7)
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = BF_NEBULA_A:Lerp(BF_NEBULA_B, if layer == 1 then mix * 0.5 else 0.35 + mix * 0.65)
			f.Parent = gui
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.22, math.min(1, peak + 0.28)),
				NumberSequenceKeypoint.new(0.5, peak),
				NumberSequenceKeypoint.new(0.78, math.min(1, peak + 0.28)),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = f
			table.insert(guis, gui)
			table.insert(pieces, p)
		end
	end
	-- 별
	local stars = {}
	local seed = scatterStars(look)
	for i, s in seed do
		local grade = s[3]
		local color = BF_COLORS[(i * 7) % 4 + 1]
		local size = BF_SIZE[grade]
		local p = part("BlindfoldStar" .. i, Vector3.new(size, size, size), color, Enum.Material.Neon, "Ball")
		p.CFrame = head.CFrame * CFrame.new(bfPos(s[1], s[2], 0))
		p.Parent = model
		local joint = motor("BlindfoldStarJoint", head, p, CFrame.new(bfPos(s[1], s[2], 0)), CFrame.new())
		local att = Instance.new("Attachment")
		att.Parent = p
		local sparkle: TextLabel? = nil
		if grade >= 3 then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(size * 5, size * 5)
			gui.LightInfluence = 0
			gui.AlwaysOnTop = false
			gui.Parent = p
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "✦"
			label.TextColor3 = color
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.Parent = gui
			sparkle = label
		end
		table.insert(pieces, p)
		stars[i] = { Part = p, Joint = joint, Att = att, Sparkle = sparkle, A = s[1], Y = s[2], K = grade, Phase = i * 1.9 }
	end
	-- 별자리 선: 큰 별(등급 3 이상)끼리 가까운 것 하나씩, 열여섯 줄까지만 가늘게
	local beams: { Beam } = {}
	local linked: { [string]: boolean } = {}
	for i, si in stars do
		if si.K < 3 or #beams >= 16 then
			continue
		end
		local best, bestD = nil, 0.34
		for j, sj in stars do
			if j ~= i and sj.K >= 2 then
				local d = (bfPos(si.A, si.Y, 0) - bfPos(sj.A, sj.Y, 0)).Magnitude
				if d < bestD and not linked[j .. "_" .. i] then
					best, bestD = j, d
				end
			end
		end
		if best then
			linked[i .. "_" .. best] = true
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = si.Att, stars[best].Att
			beam.Width0, beam.Width1 = 0.01, 0.01
			beam.Color = ColorSequence.new(GLOW)
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Transparency = NumberSequence.new(0.45)
			beam.Parent = si.Part
			table.insert(beams, beam)
		end
	end
	local bf: any = { Stars = stars, Beams = beams }
	-- 매 프레임: 별이 띠를 따라 물결로 흐르고(앞뒤 ±1.6°) 같은 물결로 반짝인다
	function bf.Step(self: any, t: number)
		for _, s in self.Stars do
			if s.Joint.Parent then
				local wave = math.sin(t * 0.55 - math.rad(s.A) * 2.0 + s.Phase * 0.15)
				s.Joint.C0 = CFrame.new(bfPos(s.A, s.Y + math.sin(t * 0.8 + s.Phase) * 0.005, wave * 1.6))
				local glint = 0.5 + 0.5 * math.sin(t * 1.7 - math.rad(s.A) * 3.0 + s.Phase)
				s.Part.Transparency = 0.45 * (1 - glint)
				if s.Sparkle then
					s.Sparkle.TextTransparency = 0.85 * (1 - glint) ^ 1.5
				end
			end
		end
	end
	-- 2페이즈: 얼굴과 함께 사라진다
	function bf.Hide(self: any, fade: number)
		for _, b in self.Beams do
			b.Enabled = false
		end
		for _, g in guis do
			g.Enabled = false
		end
		for _, s in self.Stars do
			if s.Sparkle then
				s.Sparkle.TextTransparency = 1
			end
		end
		for _, p in pieces do
			if fade > 0 then
				TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
			else
				p.Transparency = 1
			end
		end
		task.delay(fade + 0.1, function()
			for _, p in pieces do
				p:Destroy()
			end
		end)
	end
	return bf
end

--=== 말레니아식 의수(오른팔 전체) ===--
-- ReplicatedStorage.CallistoAssets.Prosthetic(tools/Callisto_Prosthetic.luau) — MeshPart 마다 속성 Offset(오른팔 부위 가운데에서 본 자리), 이름 = 묶음.
-- 색·재질은 여기서 입힌다(바랜 금 · 황동 · 검은 금속 · 별빛). 없으면 빈 목록(시험 환경 — 셔츠 소매 그대로).
local PROSTHETIC_SKIN: { [string]: { any } } = {
	Gold = { C(212, 172, 88), Enum.Material.Metal },
	Brass = { C(150, 116, 60), Enum.Material.Metal },
	BluedSteel = { C(36, 34, 40), Enum.Material.Metal },
	Glow = { C(156, 200, 255), Enum.Material.Neon },
}

local function attachProsthetic(model: Model, arm: BasePart): { BasePart }
	local made: { BasePart } = {}
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
	local folder = kit and kit:FindFirstChild("Prosthetic")
	if not folder then
		return made
	end
	for _, src in folder:GetChildren() do
		local offset = src:GetAttribute("Offset")
		if not src:IsA("MeshPart") or typeof(offset) ~= "CFrame" then
			continue
		end
		local mp = src:Clone()
		mp:ClearAllChildren() -- 가져오기가 붙인 SurfaceAppearance 는 걷고 색·재질을 직접 입힌다
		local skin = PROSTHETIC_SKIN[src.Name]
		if skin then
			mp.Color = skin[1]
			mp.Material = skin[2]
		end
		mp.Anchored = false
		mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.Massless = false, false, false, true
		mp.CastShadow = src.Name ~= "Glow"
		mp.CFrame = arm.CFrame * offset
		weld(arm, mp)
		mp.Parent = model
		table.insert(made, mp)
	end
	if #made > 0 then
		arm.Transparency = 1 -- 셔츠 소매 대신 의수가 보인다
	end
	return made
end

--=== 팔 검(날) ===--

local BLADE_PARTS = { Blade = true, Fuller = true, Edge = true, Point = true, Collar = true }
local BLADE_SLIDE = 2.0 -- 들어가면 날 축(+Z — 팔 쪽)으로 팔 길이만큼 밀려 소매 속에 숨는다(사라지며)

function Callisto.Blade(model: Model, out: boolean, time: number?)
	local folder = model:FindFirstChild("CombatWeapon")
	local piece = folder and folder:FindFirstChild("W")
	if not piece then
		return
	end
	model:SetAttribute("BladeOut", out)
	for _, p in piece:GetChildren() do
		local joint = p:FindFirstChildOfClass("Weld")
		if not p:IsA("BasePart") or not BLADE_PARTS[p.Name] or not joint then
			continue
		end
		local home = p:GetAttribute("BladeHome")
		if typeof(home) ~= "CFrame" then
			home = joint.C0
			p:SetAttribute("BladeHome", home)
		end
		local goal = if out then home :: CFrame else (home :: CFrame) * CFrame.new(0, 0, BLADE_SLIDE)
		local t = time or 0
		if t <= 0 then
			joint.C0 = goal
			p.Transparency = if out then 0 else 1
			continue
		end
		-- 소매 속으로 들고 나는 동안 투명도도 함께(어깨 위로 날이 비치지 않게)
		local info = TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(joint, info, { C0 = goal }):Play()
		TweenService:Create(p, info, { Transparency = if out then 0 else 1 }):Play()
	end
end

--=== 페이즈 모습 ===--

-- 2페이즈: 얼굴·머리·머리카락을 감추고 우주 머리(머리 관절에 붙어 모션을 따라간다)
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
	if look.Blindfold then
		look.Blindfold:Hide(0.25)
		look.Blindfold = nil
	end
	-- 팔 검과 오른 소매가 부서져(파편은 컷신 이펙트) 그 자리를 우주를 담은 팔이 채운다 — SetPage 가 spaceLimb 로 오른팔을 감춘다
	local function attach(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: string?, c0: CFrame): (Part, Motor6D)
		local p = part(name, size, color, material, shape)
		p.Parent = model
		return p, motor(name .. "Joint", head, p, c0, CFrame.new())
	end
	-- 우주 머리(2026-11-01 사용자: 모델링보다 레이어, 동그라미 말고 아바타 머리에 빛나는 하얀 윤곽): 고전 머리 윤곽으로 오려 낸
	-- 화면에 박힌 우주 그림 창(Combat/SpaceLayer) + 그 둘레를 도는 작은 별 아홉(기운 고리 셋 × 셋 — 사용자: "3배 빽빽하게")
	SpaceLayer.Add(head, "Head", 0.25)
	for i = 1, ORBIT_STARS do
		local color = ({ STAR, GLOW, C(255, 214, 150) })[(i - 1) % 3 + 1]
		local size = 0.12 + 0.05 * ((i * 7) % 3)
		local _, joint = attach("CosmicOrbit" .. i, Vector3.new(size, size, size), color, Enum.Material.Neon, "Ball", CFrame.new())
		table.insert(look.Orbits, joint)
	end
end

-- 부품을 fade 초에 걸쳐 투명하게(없으면 바로)
local function fadeOut(p: BasePart, fade: number?)
	if (fade or 0) > 0 and p.Transparency < 1 then
		TweenService:Create(p, TweenInfo.new(fade :: number, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
	else
		p.Transparency = 1
	end
end

-- 우주를 담은 몸 한 부품: 관절 부품은 (fade 초에 걸쳐) 감추고 — 그 부위에 그려진 셔츠·바지도 함께 — 그 상자 윤곽대로 우주 그림 창(Combat/SpaceLayer).
-- Cosmic 표지 — 두 번 씌우지 않게
local function spaceLimb(model: Model, name: string, fade: number?)
	local body = model:FindFirstChild(name)
	if not body or not body:IsA("BasePart") or body:GetAttribute("Cosmic") then
		return
	end
	body:SetAttribute("Cosmic", true)
	fadeOut(body, fade)
	SpaceLayer.Add(body, "Box", fade)
end

--=== 3페이즈 주변 장식(2026-11-01 동업자 레퍼런스 — 사용자: "나는 옷을 벗고 있는 게 더 좋아서, 이런 느낌은 주변 장식으로") ===--
-- 레퍼런스: 검은 로브 + 머리 자리의 일식(검은 원 · 금빛 테 · 계단처럼 겹친 가시 · 긴 빛살) + 등 뒤로 뻗은 검은 띠 팔 여섯(금 줄무늬, 꺾인 마디).
-- 로브는 빼고(우주 몸) 일식 후광은 머리 뒤에, 띠 팔은 등에 — 둘 다 천천히 움직인다(후광은 돌고, 팔은 흔들린다).
local ECLIPSE_DARK = C(14, 12, 16)
local ECLIPSE_GOLD = C(232, 196, 128)
local ECLIPSE_CREAM = C(255, 240, 214)
local RIBBON = C(24, 22, 28)
local HALO_C0 = CFrame.new(0, 0.15, 0.8)

-- 부품을 투명으로 붙였다가 fade 초에 걸쳐 나타나게
local function appear(p: BasePart, alpha: number, fade: number?)
	p.Transparency = 1
	if (fade or 0) > 0 then
		TweenService:Create(p, TweenInfo.new(fade :: number, Enum.EasingStyle.Sine), { Transparency = alpha }):Play()
	else
		p.Transparency = alpha
	end
end

local function eclipse(model: Model, look: Look, head: BasePart, fade: number?)
	local hub = part("HaloHub", Vector3.new(0.2, 0.2, 0.2), ECLIPSE_DARK)
	hub.Transparency = 1
	hub.CFrame = head.CFrame * HALO_C0
	hub.Parent = model
	look.Halo = motor("HaloJoint", head, hub, HALO_C0, CFrame.new())
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, alpha: number, shape: string?): Part
		local p = part(name, size, color, material, shape)
		p.CFrame = hub.CFrame * cf
		weld(hub, p)
		p.Parent = model
		appear(p, alpha, fade)
		return p
	end
	local face = CFrame.Angles(0, math.pi / 2, 0) -- 원기둥 축(X)을 앞뒤(Z)로
	piece("HaloDisc", Vector3.new(0.06, 1.95, 1.95), face, ECLIPSE_DARK, Enum.Material.SmoothPlastic, 0)
	piece("HaloRim", Vector3.new(0.05, 2.2, 2.2), CFrame.new(0, 0, 0.03) * face, ECLIPSE_GOLD, Enum.Material.Neon, 0.05)
	look.HaloGlow = piece("HaloGlow", Vector3.new(0.04, 3.1, 3.1), CFrame.new(0, 0, 0.06) * face, ECLIPSE_CREAM, Enum.Material.Neon, 0.78)
	-- 계단처럼 겹친 가시 열여섯(블록을 바깥으로 갈수록 좁게) — 검정과 금을 번갈아, 넷마다 길게
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + (if i % 2 == 0 then 0 else 0.06)
		local blocks = if i % 4 == 0 then 6 elseif i % 2 == 0 then 4 else 3
		for k = 0, blocks - 1 do
			local w = math.max(0.08, 0.56 - 0.1 * k)
			local cf = CFrame.Angles(0, 0, a) * CFrame.new(1.18 + 0.34 * k, 0, 0.04 + 0.01 * k)
			local color = if (i + k) % 2 == 0 then ECLIPSE_GOLD else C(46, 42, 40)
			piece("HaloSpike", Vector3.new(0.34, w, 0.05), cf, color, if color == ECLIPSE_GOLD then Enum.Material.Neon else Enum.Material.SmoothPlastic, if color == ECLIPSE_GOLD then 0.15 else 0)
		end
	end
	-- 긴 빛살 여덟(카메라를 보는 띠 — 안쪽은 밝고 끝으로 사라진다)
	local center = Instance.new("Attachment")
	center.Position = Vector3.new(0, 0, 0.08)
	center.Parent = hub
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local len = if i % 2 == 0 then 9 else 6
		local tip = Instance.new("Attachment")
		tip.Position = Vector3.new(math.cos(a) * len, math.sin(a) * len, 0.08)
		tip.Parent = hub
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = center, tip
		beam.Width0, beam.Width1 = 0.55, 0.04
		beam.Color = ColorSequence.new(ECLIPSE_CREAM)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.65), NumberSequenceKeypoint.new(1, 1) })
		beam.Enabled = false
		beam.Parent = hub
		task.delay(fade or 0, function()
			beam.Enabled = true
		end)
	end
end

-- 등 뒤 검은 띠 팔 여섯: 양쪽 셋씩, 마디 셋(꺾임), 마디마다 금 줄무늬 둘. 첫 마디가 몸통에 모터로 붙어 흔들린다
local function ribbonArms(model: Model, look: Look, torso: BasePart, fade: number?)
	local index = 0
	for _, side in { 1, -1 } do
		for j = 1, 3 do
			index += 1
			-- 팔 방향: 옆으로(바깥) 조금 뒤로 — 위 팔은 위로, 아래 팔은 아래로 기울어 거미 다리처럼 퍼진다
			local away = math.rad(56 + j * 9)
			local d = Vector3.new(side * math.sin(away), 0, math.cos(away))
			local pitch = math.rad(({ 32, 4, -26 })[j])
			local base = CFrame.fromMatrix(Vector3.new(side * 0.55, 0.75 - j * 0.42, 0.55), d, Vector3.yAxis) * CFrame.Angles(0, 0, pitch)
			local prev: BasePart = torso
			local c0 = base
			for k, seg in { { 1.7, 0.34 }, { 1.45, 0.26 }, { 1.25, 0.16 } } do
				local len, w = seg[1], seg[2]
				local p = part("RibbonArm", Vector3.new(len, w, 0.07), RIBBON, Enum.Material.SmoothPlastic)
				p.Parent = model
				appear(p, 0, fade)
				local joint = motor("RibbonJoint", prev, p, c0, CFrame.new(-len / 2, 0, 0))
				p.CFrame = prev.CFrame * c0 * CFrame.new(len / 2, 0, 0)
				for _, y in { -w * 0.28, w * 0.28 } do
					local stripe = part("RibbonStripe", Vector3.new(len * 0.86, 0.03, 0.09), ECLIPSE_GOLD, Enum.Material.Metal)
					stripe.CFrame = p.CFrame * CFrame.new(0, y, 0)
					weld(p, stripe)
					stripe.Parent = model
					appear(stripe, 0, fade)
				end
				table.insert(look.Arms, { Joint = joint, Base = c0, Phase = index * 1.3 + k * 0.7, Sway = 0.06 + 0.04 * k })
				prev = p
				-- 다음 마디: 이 마디 끝에서 꺾여(팔꿈치) 아래로
				c0 = CFrame.new(len / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(({ -38, -30, 0 })[k]))
			end
		end
	end
end

-- 3페이즈 후광이 한 번 타오른다(큰 기술 — 뭇별 아래에 잠기리)
function Callisto.Flare(model: Model)
	local look = looks[model]
	local glow = look and look.HaloGlow
	if not glow then
		return
	end
	local size = glow.Size
	TweenService:Create(glow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = size * Vector3.new(1, 1.8, 1.8), Transparency = 0.35 }):Play()
	task.delay(0.25, function()
		TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Size = size, Transparency = 0.78 }):Play()
	end)
end

-- 3페이즈: 옷이 (fade 초에 걸쳐) 사라지는 동안 몸 전체가 우주 그림 창으로 나타난다
local function cosmicBody(model: Model, look: Look, fadeTime: number?)
	for _, p in look.Dressed do
		fadeOut(p, fadeTime)
	end
	for _, name in { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		spaceLimb(model, name, fadeTime)
	end
	-- 고전 옷은 몸 부위 투명도를 따라 사라지지만, 확실히 하려고 페이드가 끝나면 셔츠·바지를 없앤다
	task.delay(fadeTime or 0, function()
		for _, c in model:GetChildren() do
			if c:IsA("Shirt") or c:IsA("Pants") then
				c:Destroy()
			end
		end
	end)
	-- 동업자 레퍼런스의 일식 후광 · 검은 띠 팔(주변 장식)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if head and head:IsA("BasePart") and torso and torso:IsA("BasePart") then
		eclipse(model, look, head, fadeTime)
		ribbonArms(model, look, torso, fadeTime)
	end
end

--[[
	페이즈 모습을 맞춘다(2 = 우주 머리, 3 = 우주 몸). 전투 화면이 스냅숏마다 부른다 — 이미 그 페이즈면 아무 일도 없고, 되돌리지 않는다.
]]
function Callisto.SetPage(model: Model, page: number, fadeTime: number?)
	local look = looks[model]
	local head = model:FindFirstChild("Head")
	if not look or not head or not head:IsA("BasePart") or page <= look.Page then
		return
	end
	if look.Page < 2 and page >= 2 then
		cosmicHead(model, look, head)
		spaceLimb(model, "Right Arm", 0.25) -- 팔 검 자리를 채우는 우주 팔(레이어)
		for _, p in look.Prosthetic do -- 의수도 함께 사라진다(부서지는 연출은 이펙트)
			fadeOut(p, 0.25)
		end
	end
	if look.Page < 3 and page >= 3 then
		cosmicBody(model, look, fadeTime)
	end
	look.Page = page
end

--=== 몸 ===--

-- 머리카락(카탈로그)을 붙인다. 없으면(시험 환경) 맨머리. 옷은 Build 가 셔츠·바지로 입힌다 — CallistoAssets.Outfit(블렌더 옷)은 더 붙이지 않는다
local function dress(model: Model, head: BasePart): { BasePart }
	local dressed: { BasePart } = {}
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
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
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), SKIN)
	root.Transparency = 1
	root.Anchored = true
	-- 몸 다섯 부위는 피부색으로 보인다 — 셔츠·바지 그림의 투명한 곳에 피부가 비친다
	local torso = part("Torso", Vector3.new(2, 2, 1), SKIN)
	local head = part("Head", Vector3.new(2, 1, 1), SKIN)
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), SKIN)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), SKIN)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), SKIN)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), SKIN)
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

	--- 옷(고전 셔츠·바지) · 머리카락(들여온 것) ---
	--[[
		Shirt·Pants 는 Humanoid 가 있는 모델의 R6 몸 부위에만 그려진다. 관절은 Motor6D 모션(CombatRig)이 움직이고 뿌리는 고정이니
		Humanoid 는 옷을 입히는 데만 쓴다 — 이름·체력 표시 · 죽음 · 상태 기계(물리·애니메이션 덮어쓰기)를 모두 끈다.
	]]
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance, humanoid.HealthDisplayDistance = 0, 0
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = model
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = SHIRT_TEMPLATE
	shirt.Parent = model
	local pants = Instance.new("Pants")
	pants.PantsTemplate = PANTS_TEMPLATE
	pants.Parent = model
	local dressed = dress(model, head)
	local prosthetic = attachProsthetic(model, rightArm)
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
	-- 둘레를 떠도는 별가루 아홉(사용자: "3배 빽빽하게") — 반지름·높이·빠르기·방향을 저마다 달리
	local motes: { Motor6D } = {}
	for i = 1, MOTES do
		local size = 0.1 + 0.04 * ((i * 5) % 3)
		local mote = part("Mote" .. i, Vector3.new(size, size, size), ({ STAR, GLOW, GOLD })[(i - 1) % 3 + 1], Enum.Material.Neon, "Ball")
		mote.Parent = model
		motes[i] = motor("MoteJoint" .. i, torso, mote, CFrame.new(), CFrame.new())
	end

	--- 얼굴 + 매 프레임(혼천의·별가루·우주 머리·표정) ---
	local face: any = buildFace(plate)
	faces[model] = face
	local look: Look = { Dressed = dressed, Blindfold = nil, Prosthetic = prosthetic, Page = 1, Orbits = {}, Arms = {} }
	looks[model] = look
	look.Blindfold = buildBlindfold(model, head)
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
				local speed = (0.5 + 0.6 * ((i * 3) % 5) / 4) * (if i % 2 == 0 then -1 else 1)
				local a = t * speed + i * (math.pi * 2 / MOTES)
				local r = 1.45 + 0.75 * ((i * 4) % 5) / 4
				joint.C0 = CFrame.new(math.cos(a) * r, -0.5 + 1.9 * ((i * 2) % 9) / 8 + math.sin(t * 1.3 + i) * 0.35, math.sin(a) * r * 0.8)
			end
		end
		if look.Halo and look.Halo.Parent then
			look.Halo.C0 = HALO_C0 * CFrame.Angles(0, 0, t * 0.22)
		end
		for _, arm in look.Arms do
			if arm.Joint.Parent then
				arm.Joint.C0 = arm.Base * CFrame.Angles(math.sin(t * 0.7 + arm.Phase) * arm.Sway, math.sin(t * 0.55 + arm.Phase) * arm.Sway, math.sin(t * 0.9 + arm.Phase * 1.3) * arm.Sway * 1.4)
			end
		end
		for i, joint in look.Orbits do
			if joint.Parent then
				local ring = (i - 1) // 3
				local a = t * (1.1 + ring * 0.35) * (if ring == 1 then -1 else 1) + ((i - 1) % 3) * (math.pi * 2 / 3) + ring
				local r = 1.15 + 0.16 * ring
				local tilt = CFrame.Angles(0, ring * 1.05, (ring - 1) * 0.6)
				joint.C0 = CFrame.new(0, 0.1, 0) * tilt * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
		end
		if look.Blindfold then
			look.Blindfold:Step(t)
		end
		face:Step(now, dt)
	end)
	return model
end

return Callisto
