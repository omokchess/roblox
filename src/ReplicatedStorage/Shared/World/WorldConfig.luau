--!strict
-- 군도 월드 설정 — 기존 게임에 맞게 여기만 고치면 된다.

export type ZonePreset = {
	Atmosphere: { Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number },
	Correction: { TintColor: Color3, Saturation: number, Contrast: number, Brightness: number },
	WaterColor: Color3,
	WaterTransparency: number,
	Fireflies: boolean,
	Mist: boolean,
	AmbientSound: string, -- rbxassetid://... (비워두면 무음)
	Label: string,
}

local WorldConfig = {
	Version = 3, -- 생성 로직을 바꾸면 올려서 재생성 유도

	-- 서버 시작 시 월드(SwampWorld 폴더/지형)가 없으면 자동 생성
	BuildOnServerStart = true,
	BuildTerrain = true,
	BuildPlacements = true,
	-- 섬별 활성화 (기존 게임에 이미 섬이 있으면 false 로)
	Islands = {
		Mistmire = true,
		Harbor = true,
		LighthouseRock = true,
	} :: { [string]: boolean },
	-- 군도 전체 이동량 (지형 격자에 맞도록 4의 배수로 반올림됨)
	Offset = Vector3.new(0, 0, 0),

	WaterLevel = 0,
	CreateSpawnLocations = true,
	SeaWalls = true,
	ApplyLighting = true,

	DayNight = {
		Enabled = true,
		DayLengthMinutes = 24, -- 하루(24시간) 길이
		StartClock = 16.5,
	},

	Water = {
		Color = Color3.fromRGB(30, 74, 84),
		Transparency = 0.4,
		Reflectance = 0.45,
		WaveSize = 0.2,
		WaveSpeed = 9,
	},

	-- 소리 (Roblox 에 업로드한 오디오 ID 를 넣으면 재생)
	Sounds = {
		Bell = "",
		ShipHorn = "",
		Waves = "",
		Frogs = "",
		Fire = "",
	} :: { [string]: string },

	-- 이정표/게시판 문구
	SignTexts = {
		Mistmire = { SignA = "⚓ 선착장", SignB = "🏠 늪 마을", SignC = "☠ 늪의 사당" },
		Harbor = { SignA = "⚓ 안개늪행 부두", SignB = "🏪 항구 광장", SignC = "🗼 감시탑" },
	} :: { [string]: { [string]: string } },
	NoticeText = "【늪지대 생존 수칙】\n좌클릭: 연속 공격 · 길게 눌러 강공격\nF(길게): 방어 — 타이밍 맞추면 패링!\nQ: 구르기(무적) · E/R: 무기 기술\n1·2·3: 무기 교체 · T/휠클릭: 대상 고정 · H: 도움말\n\n독 늪 크롤러를 조심하고,\n사당의 '늪의 군주'는 파티로 도전하세요.",

	Zones = {
		Sea = {
			Label = "바다",
			Atmosphere = { Density = 0.28, Offset = 0.1, Color = Color3.fromRGB(199, 214, 222), Decay = Color3.fromRGB(104, 120, 138), Glare = 0.4, Haze = 1.2 },
			Correction = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.05, Contrast = 0.05, Brightness = 0 },
			WaterColor = Color3.fromRGB(24, 78, 96),
			WaterTransparency = 0.45,
			Fireflies = false,
			Mist = false,
			AmbientSound = "",
		},
		Harbor = {
			Label = "항구섬",
			Atmosphere = { Density = 0.26, Offset = 0.15, Color = Color3.fromRGB(205, 214, 214), Decay = Color3.fromRGB(110, 120, 130), Glare = 0.3, Haze = 1.0 },
			Correction = { TintColor = Color3.fromRGB(255, 250, 240), Saturation = 0.08, Contrast = 0.05, Brightness = 0.01 },
			WaterColor = Color3.fromRGB(28, 84, 96),
			WaterTransparency = 0.45,
			Fireflies = false,
			Mist = false,
			AmbientSound = "",
		},
		Swamp = {
			Label = "안개늪 섬",
			Atmosphere = { Density = 0.42, Offset = 0.35, Color = Color3.fromRGB(170, 190, 170), Decay = Color3.fromRGB(88, 104, 86), Glare = 0.1, Haze = 2.2 },
			Correction = { TintColor = Color3.fromRGB(236, 250, 226), Saturation = -0.08, Contrast = 0.08, Brightness = -0.01 },
			WaterColor = Color3.fromRGB(46, 62, 40),
			WaterTransparency = 0.2,
			Fireflies = true,
			Mist = true,
			AmbientSound = "",
		},
		Village = {
			Label = "늪 마을",
			Atmosphere = { Density = 0.36, Offset = 0.3, Color = Color3.fromRGB(190, 196, 176), Decay = Color3.fromRGB(110, 104, 86), Glare = 0.15, Haze = 1.8 },
			Correction = { TintColor = Color3.fromRGB(255, 244, 226), Saturation = 0.0, Contrast = 0.06, Brightness = 0 },
			WaterColor = Color3.fromRGB(48, 64, 42),
			WaterTransparency = 0.22,
			Fireflies = true,
			Mist = false,
			AmbientSound = "",
		},
		Shrine = {
			Label = "늪의 사당",
			Atmosphere = { Density = 0.5, Offset = 0.45, Color = Color3.fromRGB(150, 196, 170), Decay = Color3.fromRGB(60, 96, 80), Glare = 0.0, Haze = 2.6 },
			Correction = { TintColor = Color3.fromRGB(214, 255, 232), Saturation = -0.15, Contrast = 0.15, Brightness = -0.03 },
			WaterColor = Color3.fromRGB(34, 60, 44),
			WaterTransparency = 0.15,
			Fireflies = true,
			Mist = true,
			AmbientSound = "",
		},
		Lighthouse = {
			Label = "등대 바위섬",
			Atmosphere = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(200, 212, 222), Decay = Color3.fromRGB(100, 116, 136), Glare = 0.4, Haze = 1.3 },
			Correction = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.05, Contrast = 0.06, Brightness = 0 },
			WaterColor = Color3.fromRGB(22, 76, 98),
			WaterTransparency = 0.45,
			Fireflies = false,
			Mist = false,
			AmbientSound = "",
		},
	} :: { [string]: ZonePreset },
}

-- 지형 격자(4 stud)에 맞춘 오프셋
function WorldConfig.GetOffset(): Vector3
	local o = WorldConfig.Offset
	return Vector3.new(math.round(o.X / 4) * 4, math.round(o.Y / 4) * 4, math.round(o.Z / 4) * 4)
end

return WorldConfig
