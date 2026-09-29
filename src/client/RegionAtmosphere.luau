--!strict
--[[
	RegionAtmosphere — 지역마다 다른 안개·빛·떠다니는 입자. (2026-09-29)

	요청: "맵 전체에 안개랑 광원 효과를 넣고, 각 지형별로 안개가 다르게 나오도록 해줘."
	예전 스튜디오 전용 LocalScript(StarterPlayerScripts.BiomeAtmosphere)는 섬을 옮기기 전 자리표라 지금 섬과 어긋나 있었고,
	색 조금만 바꿔 지역 차이가 거의 안 보였다. 이것으로 바꾼다(옛것은 꺼 둔다 — tools/RegionAtmosphere_Setup.luau).

	  지역 판정  섬 중심·반지름(2026-09-29 높이 지도로 잼). 가장 가까운(반지름 - 거리가 큰) 지역, 어디에도 안 들면 바다
	  바꾸는 것  Lighting 밝기·주변광 / Atmosphere 안개(짙기·색·먼 빛깔·연무·눈부심) / 색보정 / 번짐 / 햇살(SunRays)
	  입자       카메라 둘레 상자(공중)와 발밑 땅 상자(땅 안개)에 지역마다 다른 입자 — 꽃가루·반딧불·늪 안개·모래바람·
	             재·불똥·수증기·눈·포자·금빛 먼지. 텍스처는 로블록스 내장(smoke·sparkles)만 쓴다(올릴 자산 없음)
	지역이 바뀌면 2.5초에 걸쳐 섞는다. 전투 중(하늘 전장)도 발밑 지역을 따른다.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RegionAtmosphere = {}

local RGB = Color3.fromRGB
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- { 이름, 중심 x, 중심 z, 반지름 } — 섬 모양이 길면 점을 둘로
local REGIONS: { { any } } = {
	{ "평원", 380, 560, 820 },
	{ "숲", -1470, 540, 1000 },
	{ "늪지대", 2360, 1080, 1000 },
	{ "사막", 2680, -800, 1000 },
	{ "탑의성역", 400, -1480, 820 },
	{ "오염지대", -2660, -1280, 900 },
	{ "화산", -1260, -2880, 880 },
	{ "광산", 1260, -3120, 800 },
	{ "설원", -4700, -2620, 750 },
	{ "설원", -3300, -2620, 700 },
	-- 설원 안쪽 방(공중 방 모음)
	{ "설원", -7600, -2470, 400 },
}

export type Particle = {
	Where: "Air" | "Ground",
	Texture: string,
	Color: Color3,
	Size: { number },
	Alpha: { number },
	Life: { number },
	Rate: number,
	Speed: { number },
	Accel: Vector3?,
	Spread: number?,
	Light: number?,
	Rot: { number }?,
	Dir: Enum.NormalId?,
}

export type Mood = {
	Brightness: number,
	Ambient: Color3,
	Outdoor: Color3,
	Density: number,
	Offset: number,
	Fog: Color3,
	Decay: Color3,
	Haze: number,
	Glare: number,
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Bloom: number,
	Rays: number,
	RaySpread: number,
	Particles: { Particle },
}

local MOOD: { [string]: Mood } = {
	-- 들판·마을: 맑고 따뜻한 옅은 연무, 꽃가루
	["평원"] = {
		Brightness = 2.9, Ambient = RGB(120, 128, 118), Outdoor = RGB(152, 160, 146),
		Density = 0.22, Offset = 0.12, Fog = RGB(206, 214, 202), Decay = RGB(126, 140, 128), Haze = 0.9, Glare = 0.35,
		Tint = RGB(255, 250, 240), Saturation = 0.12, Contrast = 0.12, Bloom = 0.8, Rays = 0.12, RaySpread = 0.8,
		Particles = {
			{ Where = "Air", Texture = SPARK, Color = RGB(255, 246, 210), Size = { 0.18, 0.12 }, Alpha = { 0.35, 0.6 }, Life = { 6, 10 }, Rate = 10, Speed = { 0.3, 1.2 }, Accel = Vector3.new(0.6, 0.05, 0.3), Spread = 180, Light = 0.3 },
		},
	},
	-- 숲: 푸른 안개가 짙고 햇살이 나무 사이로, 떠다니는 빛 알갱이·땅 안개
	["숲"] = {
		Brightness = 2.2, Ambient = RGB(52, 70, 52), Outdoor = RGB(92, 114, 90),
		Density = 0.38, Offset = 0.02, Fog = RGB(146, 176, 142), Decay = RGB(58, 80, 58), Haze = 2.4, Glare = 0.1,
		Tint = RGB(234, 252, 230), Saturation = 0.05, Contrast = 0.18, Bloom = 1.0, Rays = 0.28, RaySpread = 0.55,
		Particles = {
			{ Where = "Air", Texture = SPARK, Color = RGB(200, 255, 150), Size = { 0.22, 0.1 }, Alpha = { 0.2, 0.8 }, Life = { 5, 9 }, Rate = 14, Speed = { 0.2, 0.8 }, Accel = Vector3.new(0, 0.15, 0), Spread = 180, Light = 1 },
			{ Where = "Ground", Texture = SMOKE, Color = RGB(206, 226, 200), Size = { 14, 26 }, Alpha = { 0.9, 0.78 }, Life = { 10, 16 }, Rate = 4, Speed = { 0.4, 1.2 }, Accel = Vector3.new(0.3, 0, 0.1), Spread = 180, Rot = { -8, 8 } },
		},
	},
	-- 늪: 낮게 깔린 누런 안개가 가장 짙다, 반딧불
	["늪지대"] = {
		Brightness = 1.9, Ambient = RGB(64, 68, 50), Outdoor = RGB(102, 108, 82),
		Density = 0.5, Offset = 0, Fog = RGB(170, 170, 128), Decay = RGB(78, 84, 58), Haze = 3.2, Glare = 0.05,
		Tint = RGB(246, 252, 220), Saturation = -0.16, Contrast = 0.1, Bloom = 0.75, Rays = 0.05, RaySpread = 0.8,
		Particles = {
			{ Where = "Ground", Texture = SMOKE, Color = RGB(214, 214, 176), Size = { 18, 34 }, Alpha = { 0.82, 0.7 }, Life = { 12, 18 }, Rate = 7, Speed = { 0.3, 0.9 }, Accel = Vector3.new(0.2, 0, 0.2), Spread = 180, Rot = { -6, 6 } },
			{ Where = "Air", Texture = SPARK, Color = RGB(255, 236, 120), Size = { 0.3, 0.12 }, Alpha = { 0.1, 0.9 }, Life = { 4, 7 }, Rate = 9, Speed = { 0.4, 1.4 }, Spread = 180, Light = 1 },
		},
	},
	-- 사막: 눈부시고 뜨거운 연무, 모래바람
	["사막"] = {
		Brightness = 3.3, Ambient = RGB(140, 124, 96), Outdoor = RGB(198, 178, 138),
		Density = 0.3, Offset = 0.16, Fog = RGB(234, 212, 170), Decay = RGB(172, 132, 92), Haze = 3.6, Glare = 1.3,
		Tint = RGB(255, 242, 214), Saturation = 0.08, Contrast = 0.16, Bloom = 1.25, Rays = 0.3, RaySpread = 1,
		Particles = {
			{ Where = "Ground", Texture = SMOKE, Color = RGB(226, 196, 146), Size = { 8, 18 }, Alpha = { 0.72, 0.9 }, Life = { 4, 7 }, Rate = 10, Speed = { 10, 18 }, Accel = Vector3.new(0, 0.5, 0), Spread = 18, Dir = Enum.NormalId.Left, Rot = { -30, 30 } },
			{ Where = "Air", Texture = SPARK, Color = RGB(230, 206, 160), Size = { 0.12, 0.1 }, Alpha = { 0.3, 0.7 }, Life = { 2, 4 }, Rate = 30, Speed = { 14, 24 }, Spread = 12, Dir = Enum.NormalId.Left },
		},
	},
	-- 탑의 성역: 금빛으로 빛나는 공기, 위로 오르는 금가루
	["탑의성역"] = {
		Brightness = 2.9, Ambient = RGB(112, 104, 78), Outdoor = RGB(170, 156, 118),
		Density = 0.26, Offset = 0.1, Fog = RGB(228, 216, 178), Decay = RGB(150, 138, 100), Haze = 1.3, Glare = 0.7,
		Tint = RGB(255, 246, 222), Saturation = 0.1, Contrast = 0.16, Bloom = 1.6, Rays = 0.32, RaySpread = 0.7,
		Particles = {
			{ Where = "Air", Texture = SPARK, Color = RGB(255, 222, 140), Size = { 0.25, 0.1 }, Alpha = { 0.2, 1 }, Life = { 6, 10 }, Rate = 16, Speed = { 0.4, 1 }, Accel = Vector3.new(0, 0.4, 0), Spread = 180, Light = 1 },
		},
	},
	-- 오염지대: 보랏빛 독 안개, 떠다니는 포자
	["오염지대"] = {
		Brightness = 1.9, Ambient = RGB(66, 44, 76), Outdoor = RGB(104, 80, 118),
		Density = 0.44, Offset = 0.02, Fog = RGB(160, 126, 176), Decay = RGB(60, 38, 70), Haze = 2.6, Glare = 0.2,
		Tint = RGB(240, 222, 255), Saturation = 0.15, Contrast = 0.26, Bloom = 1.35, Rays = 0.08, RaySpread = 0.8,
		Particles = {
			{ Where = "Ground", Texture = SMOKE, Color = RGB(150, 100, 170), Size = { 14, 28 }, Alpha = { 0.84, 0.74 }, Life = { 10, 15 }, Rate = 5, Speed = { 0.3, 1 }, Spread = 180, Rot = { -6, 6 } },
			{ Where = "Air", Texture = SPARK, Color = RGB(206, 120, 255), Size = { 0.35, 0.15 }, Alpha = { 0.3, 0.9 }, Life = { 6, 10 }, Rate = 12, Speed = { 0.2, 0.7 }, Accel = Vector3.new(0, -0.05, 0), Spread = 180, Light = 0.7 },
		},
	},
	-- 화산(지열): 붉은 재 안개, 내리는 재와 오르는 불똥
	["화산"] = {
		Brightness = 2.1, Ambient = RGB(92, 52, 40), Outdoor = RGB(132, 84, 62),
		Density = 0.42, Offset = 0.05, Fog = RGB(202, 132, 96), Decay = RGB(92, 40, 28), Haze = 2.9, Glare = 0.45,
		Tint = RGB(255, 224, 200), Saturation = 0.18, Contrast = 0.3, Bloom = 1.5, Rays = 0.16, RaySpread = 0.9,
		Particles = {
			{ Where = "Air", Texture = SMOKE, Color = RGB(90, 84, 82), Size = { 0.6, 0.4 }, Alpha = { 0.4, 0.8 }, Life = { 6, 9 }, Rate = 26, Speed = { 1, 3 }, Accel = Vector3.new(0.4, -1.2, 0), Spread = 40, Dir = Enum.NormalId.Bottom, Rot = { -60, 60 } },
			{ Where = "Ground", Texture = SPARK, Color = RGB(255, 132, 40), Size = { 0.35, 0.1 }, Alpha = { 0, 1 }, Life = { 3, 6 }, Rate = 16, Speed = { 3, 7 }, Accel = Vector3.new(0.3, 1.5, 0), Spread = 25, Dir = Enum.NormalId.Top, Light = 1 },
		},
	},
	-- 광산: 먼지 낀 누런 공기, 피어오르는 김
	["광산"] = {
		Brightness = 2.4, Ambient = RGB(84, 78, 70), Outdoor = RGB(128, 120, 106),
		Density = 0.34, Offset = 0.06, Fog = RGB(200, 190, 160), Decay = RGB(108, 96, 72), Haze = 2, Glare = 0.3,
		Tint = RGB(252, 246, 228), Saturation = -0.08, Contrast = 0.18, Bloom = 0.9, Rays = 0.14, RaySpread = 0.8,
		Particles = {
			{ Where = "Ground", Texture = SMOKE, Color = RGB(236, 232, 220), Size = { 6, 20 }, Alpha = { 0.8, 1 }, Life = { 5, 9 }, Rate = 6, Speed = { 2, 5 }, Accel = Vector3.new(0.3, 1, 0), Spread = 20, Dir = Enum.NormalId.Top, Rot = { -10, 10 } },
			{ Where = "Air", Texture = SPARK, Color = RGB(214, 196, 150), Size = { 0.14, 0.1 }, Alpha = { 0.4, 0.8 }, Life = { 4, 7 }, Rate = 14, Speed = { 0.3, 1 }, Spread = 180 },
		},
	},
	-- 설원: 차갑고 푸른 안개, 내리는 눈
	["설원"] = {
		Brightness = 3.0, Ambient = RGB(128, 142, 158), Outdoor = RGB(182, 200, 216),
		Density = 0.38, Offset = 0.05, Fog = RGB(214, 228, 242), Decay = RGB(146, 166, 196), Haze = 1.9, Glare = 0.6,
		Tint = RGB(236, 246, 255), Saturation = -0.1, Contrast = 0.14, Bloom = 1.25, Rays = 0.18, RaySpread = 0.8,
		Particles = {
			{ Where = "Air", Texture = SPARK, Color = RGB(255, 255, 255), Size = { 0.3, 0.25 }, Alpha = { 0.1, 0.4 }, Life = { 7, 10 }, Rate = 90, Speed = { 3, 6 }, Accel = Vector3.new(1.2, -0.6, 0.4), Spread = 30, Dir = Enum.NormalId.Bottom, Rot = { -90, 90 } },
		},
	},
	-- 바다: 맑고 멀리 푸른 연무
	["바다"] = {
		Brightness = 2.9, Ambient = RGB(116, 128, 132), Outdoor = RGB(150, 166, 172),
		Density = 0.22, Offset = 0.2, Fog = RGB(192, 214, 224), Decay = RGB(110, 148, 170), Haze = 1.3, Glare = 0.55,
		Tint = RGB(248, 252, 255), Saturation = 0.1, Contrast = 0.12, Bloom = 0.9, Rays = 0.16, RaySpread = 0.9,
		Particles = {},
	},
}
RegionAtmosphere.MOOD = MOOD
RegionAtmosphere.REGIONS = REGIONS

-- 이 자리의 지역 이름(바다 = 어디에도 안 듦)
function RegionAtmosphere.RegionAt(x: number, z: number): string
	local best, bestW = "바다", 0
	for _, r in REGIONS do
		local w = r[4] - math.sqrt((x - r[2]) ^ 2 + (z - r[3]) ^ 2)
		if w > bestW then
			best, bestW = r[1], w
		end
	end
	return best
end

local function range(v: { number }): NumberRange
	return NumberRange.new(v[1], v[2] or v[1])
end

local function makeEmitter(spec: Particle, parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.Texture
	e.Color = ColorSequence.new(spec.Color)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.Size[1]),
		NumberSequenceKeypoint.new(1, spec.Size[2] or spec.Size[1]),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, spec.Alpha[1]),
		NumberSequenceKeypoint.new(0.8, spec.Alpha[2] or spec.Alpha[1]),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = range(spec.Life)
	e.Speed = range(spec.Speed)
	e.Acceleration = spec.Accel or Vector3.zero
	e.SpreadAngle = Vector2.new(spec.Spread or 180, spec.Spread or 180)
	e.LightEmission = spec.Light or 0
	e.LightInfluence = if (spec.Light or 0) > 0.5 then 0 else 1
	e.RotSpeed = range(spec.Rot or { 0, 0 })
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = spec.Dir or Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Parent = parent
	return e
end

local function anchorPart(name: string, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = workspace.CurrentCamera
	return p
end

function RegionAtmosphere.Start()
	-- 옛 스튜디오 전용 스크립트가 켜져 있으면 둘이 다투므로 여기서 멈추게 한다(대개 편집 모드에서 이미 꺼 둠)
	local old = Players.LocalPlayer:FindFirstChild("PlayerScripts") and Players.LocalPlayer.PlayerScripts:FindFirstChild("BiomeAtmosphere")
	if old and old:IsA("LocalScript") then
		old.Enabled = false
	end

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	local grade = Lighting:FindFirstChild("Grade") or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local bloom = Lighting:FindFirstChild("Bloom") or Lighting:FindFirstChildOfClass("BloomEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")

	local air = anchorPart("RegionAir", Vector3.new(140, 60, 140))
	local ground = anchorPart("RegionGround", Vector3.new(160, 4, 160))
	-- 지역마다 입자를 한 벌씩 만들어 두고 Rate 만 올리고 내린다
	local emitters: { [string]: { { Emitter: ParticleEmitter, Rate: number } } } = {}
	for name, mood in MOOD do
		local list = {}
		for _, spec in mood.Particles do
			table.insert(list, { Emitter = makeEmitter(spec, if spec.Where == "Ground" then ground else air), Rate = spec.Rate })
		end
		emitters[name] = list
	end

	local info = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local current: string? = nil
	local function apply(name: string)
		local m = MOOD[name]
		TweenService:Create(Lighting, info, { Brightness = m.Brightness, Ambient = m.Ambient, OutdoorAmbient = m.Outdoor }):Play()
		TweenService:Create(atmo, info, { Density = m.Density, Offset = m.Offset, Color = m.Fog, Decay = m.Decay, Haze = m.Haze, Glare = m.Glare }):Play()
		if grade and grade:IsA("ColorCorrectionEffect") then
			TweenService:Create(grade, info, { TintColor = m.Tint, Saturation = m.Saturation, Contrast = m.Contrast }):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(bloom, info, { Intensity = m.Bloom }):Play()
		end
		if rays then
			TweenService:Create(rays, info, { Intensity = m.Rays, Spread = m.RaySpread }):Play()
		end
		for region, list in emitters do
			for _, item in list do
				TweenService:Create(item.Emitter, info, { Rate = if region == name then item.Rate else 0 }):Play()
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local groundY = 0
	local lastRay = 0
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local pos = camera.CFrame.Position
		air.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
		local now = os.clock()
		if now - lastRay > 0.5 then
			lastRay = now
			params.FilterDescendantsInstances = { camera, Players.LocalPlayer.Character :: any }
			local hit = workspace:Raycast(pos, Vector3.new(0, -300, 0), params)
			groundY = if hit then hit.Position.Y else pos.Y - 20
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local at = if root then root.Position else pos
			local name = RegionAtmosphere.RegionAt(at.X, at.Z)
			if name ~= current then
				current = name
				apply(name)
			end
		end
		ground.CFrame = CFrame.new(pos.X, groundY + 3, pos.Z)
	end)
end

return RegionAtmosphere
