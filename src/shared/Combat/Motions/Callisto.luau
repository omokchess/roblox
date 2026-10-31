--!strict
--[[
	칼리스토 — 히든 보스(2026-10-31). 큰곰자리 · 천문학자 · 시인, 기물군의 비숍.

	성격: 관찰자. 서두르지 않고 꼿꼿이 서서 고개를 기울여 상대를 "찍는다". 칼날은 팔의 연장(의체),
	      카메라는 왼손목 — 찍을 때는 왼팔을 쭉 뻗어 렌즈로 겨눈다.
	무기 종류: Prosthesis (WeaponDefinitions.CallistoArms — 오른팔 칼날은 팔 선을 따라 손끝 너머로, 왼손목 카메라 렌즈도 팔 선 방향)
	박자(feedback-motion-rhythm): 느린 준비(sineOut) → 번개 같은 한 방(expoOut) → 여운을 두고 천천히 돌아옴(sineInOut).
	사건(k): Hit(i) · Dash(to = Target/Home, gap) · Fx(n = Fx/Callisto 의 이름) · Trail(on, slot) · Shake(a, d) · Stop(d)
	연타 스킬(트로히아 5 · 신데시 톤 아스트론 3 · 쏟아지는 뭇별 3)은 서버가 예고를 따로 줄 세워 한 번씩 회피하므로
	모션은 **한 번 치는 것**이다(회피 QTE 사이마다 하나씩 다시 튼다).
	괄호 속 레퍼런스(사용자 사양): 아스트로 세시 = 아케인 리니지 블레이드 댄서 칼춤(고속 회전하며 사방을 벤다).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 관찰자의 대기: 오른 어깨를 조금 앞으로(몸 20°), 상체는 살짝 젖혀 턱을 든 채 고개를 갸웃.
-- 칼날 팔은 앞아래로 늘어뜨려 칼끝이 땅 위에서 멈추고(팔 40° — 칼날이 팔 선을 따라 2.2 뻗는다), 카메라 왼팔은 가슴 앞으로 반쯤 든다.
local OBS = {
	Root = { 0, 0, 0, 0, 20, 0 },
	Torso = { 4, -6, 0 },
	Head = { -6, -16, 6 },
	RArm = { 40, 0, 12 },
	LArm = { 52, 10, -4 },
	RLeg = { 8, 0, 4 },
	LLeg = { -6, 0, -4 },
}

-- 베기 준비 · 내려벤 끝
local READY = { Root = { 0, -0.15, 0.2, 0, 38, 0 }, Torso = { -6, 22, 0 }, Head = { 4, -24, 0 }, RArm = { 152, 0, 40 }, LArm = { 34, 0, -24 }, RLeg = { -18, 0, 8 }, LLeg = { 24, 0, -8 } }
local SLASHED = { Root = { 0, -0.35, -0.3, 0, -8, 0 }, Torso = { -20, -26, 0 }, Head = { 10, 10, 0 }, RArm = { 24, 0, -34 }, LArm = { 10, 0, -34 }, RLeg = { 36, 0, 8 }, LLeg = { -26, 0, -8 } }
-- 등손 가로베기(트로히아 한 번)
local COIL = { Root = { 0, -0.2, 0, 0, 44, 0 }, Torso = { -8, 32, 0 }, Head = { 0, -30, 0 }, RArm = { 84, 0, -52 }, LArm = { 20, 0, -20 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 } }
local SWEEP = { Root = { 0, -0.3, -0.2, 0, -12, 0 }, Torso = { -12, -32, 0 }, Head = { 4, 14, 0 }, RArm = { 84, 0, 74 }, LArm = { 30, 0, -40 }, RLeg = { 24, 0, 8 }, LLeg = { -18, 0, -8 } }
-- 찌르기(신데시 톤 아스트론 한 번): 당기고 → 팔·칼날 한 줄로 쭉
local DRAW = { Root = { 0, -0.25, 0.45, 0, 34, 0 }, Torso = { 6, 26, 0 }, Head = { 0, -30, 0 }, RArm = { 58, 28, 22 }, LArm = { 40, 0, -30 }, RLeg = { -12, 0, 8 }, LLeg = { 20, 0, -8 } }
local THRUST = { Root = { 0, -0.45, -0.65, 0, 12, 0 }, Torso = { -16, -6, 0 }, Head = { 12, -10, 0 }, RArm = { 96, 0, 0 }, LArm = { -20, 0, -16 }, RLeg = { 46, 0, 6 }, LLeg = { -36, 0, -6 } }
-- 카메라 겨눔: 몸을 틀어 왼 어깨를 앞으로, 왼팔을 쭉 뻗어 렌즈로 겨눈다
local AIM = { Root = { 0, 0, 0, 0, -30, 0 }, Torso = { 2, -18, 0 }, Head = { -2, 30, 0 }, RArm = { 22, 0, 18 }, LArm = { 90, 0, 0 }, RLeg = { 6, 0, 4 }, LLeg = { -4, 0, -4 } }
-- 하늘을 향한 천문학자(3페이지 별 부르기)
local SKY = { Root = { 0, 0.2, 0, 0, 0, 0 }, Torso = { 14, 0, 0 }, Head = { 30, 0, 0 }, RArm = { 168, 0, 14 }, LArm = { 168, 0, -14 }, RLeg = { 0, 0, 4 }, LLeg = { 0, 0, -4 } }

local IDLE = Kit.Breath(OBS, { Duration = 3.8, Chest = 2.2, Rise = 0.04, Head = -1.2 })

return {
	Idle = IDLE,
	Hit = {
		Duration = 0.55,
		Keys = {
			K(0, nil, OBS),
			K(0.06, "expoOut", OBS, { Torso = { 16, 10, 0 }, Head = { 22, -6, 0 }, Root = { 0, 0, 0.7, 0, 26, 0 }, LArm = { 20, 0, -20 } }),
			K(0.55, "sineInOut", OBS),
		},
	},
	Guard = {
		Duration = 0.55,
		Keys = {
			K(0, nil, OBS),
			-- 칼날 팔을 몸 앞으로 가로질러 막는다
			K(0.08, "expoOut", OBS, { RArm = { 84, 0, -62 }, LArm = { 60, 0, -10 }, Torso = { -6, 10, 0 }, Root = { 0, -0.15, 0.25, 0, 26, 0 } }),
			K(0.55, "sineInOut", OBS),
		},
	},
	Dodge = {
		Duration = 0.55,
		Keys = {
			K(0, nil, OBS),
			K(0.12, "expoOut", OBS, { Root = { -1.4, 0, 0.5, 0, 34, 12 }, Torso = { -8, 10, 0 } }),
			K(0.55, "sineInOut", OBS),
		},
	},
	Death = {
		Duration = 1.6,
		Keys = {
			K(0, nil, OBS),
			K(0.15, "expoOut", OBS, { Torso = { 18, 0, 0 }, Head = { 24, 0, 0 }, Root = { 0, 0, 0.5, 0, 20, 0 } }),
			-- 한 무릎을 꿇고 하늘(아들의 별)을 올려다본 뒤 고개를 떨군다
			K(0.7, "sineOut", OBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 8, 0, 0 }, Head = { 34, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, RArm = { 12, 0, 16 }, LArm = { 120, 0, -10 } }),
			K(1.6, "sineInOut", OBS, { Root = { 0, -1.5, 0.2, 0, 20, 0 }, Torso = { -34, 0, 0 }, Head = { -30, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, RArm = { 6, 0, 10 }, LArm = { 10, 0, -10 } }),
		},
	},
	-- 가끔 카메라를 들어 찰칵(버릇)
	Fidgets = {
		{
			Duration = 1.4,
			Keys = {
				K(0, nil, OBS),
				K(0.35, "sineOut", OBS, { LArm = { 86, 14, 0 }, Head = { -2, 6, 0 } }),
				K(0.9, nil, OBS, { LArm = { 88, 14, 0 }, Head = { -2, 8, 0 } }),
				K(1.4, "sineInOut", OBS),
			},
		},
	},
	Skills = {
		-- 1-1 세시 파라티리시: 다가가 높이 들었다가 비스듬히 내려벤다
		CallistoSlash = {
			Duration = 1.25,
			Keys = {
				K(0, nil, OBS),
				K(0.3, "sineOut", READY),
				K(0.4, "expoOut", SLASHED),
				K(0.85, "sineInOut", SLASHED, { Torso = { -14, -22, 0 } }),
				K(1.25, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 3.2, d = 0.24 },
				{ t = 0.3, k = "Trail", on = true, slot = "W" },
				{ t = 0.36, k = "Fx", n = "BladeArc" },
				{ t = 0.39, k = "Hit", i = 1 },
				{ t = 0.39, k = "Shake", a = 0.25, d = 0.12 },
				{ t = 0.39, k = "Stop", d = 0.05 },
				{ t = 0.56, k = "Trail", on = false, slot = "W" },
				{ t = 0.9, k = "Dash", to = "Home", d = 0.3 },
			},
		},
		-- 1-2 파라티리시: 왼손목 카메라로 찰칵(회피 불가)
		CallistoPhoto = {
			Duration = 1.1,
			Keys = {
				K(0, nil, OBS),
				K(0.32, "sineOut", AIM),
				K(0.46, nil, AIM),
				K(0.54, "expoOut", AIM, { LArm = { 102, 0, 0 }, Torso = { 6, -18, 0 } }),
				K(1.1, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "Flash" },
				{ t = 0.44, k = "Hit", i = 1 },
			},
		},
		-- 2-1 트로히아(5번 중 한 번): 팔등 칼날로 등손 가로베기
		CallistoTrohia = {
			Duration = 0.72,
			Keys = {
				K(0, nil, OBS),
				K(0.13, "quadOut", COIL),
				K(0.22, "expoOut", SWEEP),
				K(0.48, "sineInOut", SWEEP, { Torso = { -8, -26, 0 } }),
				K(0.72, "sineInOut", OBS),
			},
			Events = {
				{ t = 0, k = "Dash", to = "Target", gap = 3, d = 0.14 },
				{ t = 0.13, k = "Trail", on = true, slot = "W" },
				{ t = 0.18, k = "Fx", n = "BladeArc" },
				{ t = 0.2, k = "Hit", i = 1 },
				{ t = 0.2, k = "Shake", a = 0.15, d = 0.08 },
				{ t = 0.32, k = "Trail", on = false, slot = "W" },
				{ t = 0.46, k = "Dash", to = "Home", d = 0.22 },
			},
		},
		-- 2-2 심베라즈마: 멱살을 잡고 → 얼굴 앞에서 찰칵 → 내던진다(회피 불가)
		CallistoSymberasma = {
			Duration = 1.7,
			Keys = {
				K(0, nil, OBS),
				K(0.25, "expoOut", AIM, { LArm = { 96, 0, 4 }, Torso = { -10, -14, 0 }, Root = { 0, -0.1, 0, 0, -20, 0 } }),
				K(0.6, "sineOut", AIM, { LArm = { 124, 0, 4 }, Torso = { 8, -10, 0 }, Head = { 6, 24, 0 } }),
				K(0.95, "sineOut", AIM, { LArm = { 120, 30, 40 }, Torso = { 6, 30, 0 }, Root = { 0, 0, 0.2, 0, 10, 0 } }),
				K(1.1, "expoOut", AIM, { LArm = { 40, -30, -70 }, Torso = { -14, -36, 0 }, Root = { 0, -0.2, -0.2, 0, -40, 0 } }),
				K(1.7, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 1.4, d = 0.2 },
				{ t = 0.74, k = "Fx", n = "Flash" },
				{ t = 1.1, k = "Hit", i = 1 },
				{ t = 1.1, k = "Shake", a = 0.35, d = 0.18 },
				{ t = 1.3, k = "Dash", to = "Home", d = 0.32 },
			},
		},
		-- 3-1 신데시 톤 아스트론(3번 중 한 번): 손을 칼날로 — 당겼다가 한 줄로 찌른다
		CallistoSynthesis = {
			Duration = 0.95,
			Keys = {
				K(0, nil, OBS),
				K(0.26, "sineOut", DRAW),
				K(0.35, "expoOut", THRUST),
				K(0.62, "sineInOut", THRUST, { Torso = { -12, -6, 0 } }),
				K(0.95, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 3.8, d = 0.2 },
				{ t = 0.33, k = "Fx", n = "Stab" },
				{ t = 0.35, k = "Hit", i = 1 },
				{ t = 0.35, k = "Shake", a = 0.2, d = 0.1 },
				{ t = 0.35, k = "Stop", d = 0.04 },
				{ t = 0.62, k = "Dash", to = "Home", d = 0.26 },
			},
		},
		-- 3-2 미크리 아르크토스 하라시: 물러서며 렌즈를 겨눠 모았다가 아군 칸 전부를 태운다(막기만)
		CallistoArktos = {
			Duration = 2.1,
			Keys = {
				K(0, nil, OBS),
				K(0.4, "sineOut", AIM, { Root = { 0, -0.1, 0.6, 0, -30, 0 } }),
				K(0.98, nil, AIM, { Root = { 0, -0.15, 0.65, 0, -30, 0 }, LArm = { 92, 0, 0 } }),
				K(1.06, "expoOut", AIM, { Root = { 0, -0.1, 1.0, 0, -30, 0 }, LArm = { 100, 0, 0 }, Torso = { 12, -18, 0 } }),
				K(2.1, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "LensCharge" },
				{ t = 1.0, k = "Fx", n = "LensBurn" },
				{ t = 1.06, k = "Hit", i = 1 },
				{ t = 1.06, k = "Shake", a = 0.5, d = 0.35 },
			},
		},
		-- 강화 아스트로 세시: 뛰어들어 두 팔(칼날·카메라 팔)을 펴고 고속으로 네 바퀴 — 사방을 벤다(회피 불가)
		CallistoAstro = {
			Duration = 1.9,
			Keys = {
				K(0, nil, OBS),
				K(0.3, "sineOut", OBS, { Root = { 0, -0.6, 0, 0, 0, 0 }, Torso = { -16, 0, 0 }, RArm = { 40, 0, 80 }, LArm = { 40, 0, -80 }, RLeg = { 30, 0, 10 }, LLeg = { -20, 0, -10 } }),
				K(0.36, "quadIn", OBS, { Root = { 0, -0.3, 0, 0, 0, 0 }, Torso = { -6, 0, 0 }, RArm = { 4, 0, 90 }, LArm = { 4, 0, -90 }, RLeg = { 4, 0, 10 }, LLeg = { -4, 0, -10 } }),
				K(1.16, nil, OBS, { Root = { 0, -0.3, 0, 0, 1440, 0 }, Torso = { -6, 0, 0 }, RArm = { 4, 0, 90 }, LArm = { 4, 0, -90 }, RLeg = { 4, 0, 10 }, LLeg = { -4, 0, -10 } }),
				K(1.34, "expoOut", OBS, { Root = { 0, -0.5, 0, 0, 1460, 0 }, Torso = { -14, 0, 0 }, RArm = { 30, 0, 60 }, LArm = { 30, 0, -60 } }),
				K(1.9, "sineInOut", OBS, { Root = { 0, 0, 0, 0, 1460, 0 } }),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 2, d = 0.22 },
				{ t = 0.36, k = "Trail", on = true, slot = "W" },
				{ t = 0.36, k = "Fx", n = "BladeStorm" },
				{ t = 0.76, k = "Hit", i = 1 },
				{ t = 0.76, k = "Shake", a = 0.45, d = 0.4 },
				{ t = 1.16, k = "Trail", on = false, slot = "W" },
				{ t = 1.4, k = "Dash", to = "Home", d = 0.34 },
			},
		},
		-- 3페이지 공명적 성위(평타): 칼날 끝에 별빛을 모아 겨눠 쏜다
		CallistoResonance = {
			Duration = 1.0,
			Keys = {
				K(0, nil, OBS),
				K(0.3, "sineOut", OBS, { RArm = { 96, 0, 6 }, Torso = { 0, 14, 0 }, Head = { 0, -20, 0 } }),
				K(0.42, "expoOut", OBS, { RArm = { 100, 0, 4 }, Torso = { 6, 14, 0 }, Root = { 0, 0, 0.3, 0, 20, 0 } }),
				K(1.0, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.36, k = "Fx", n = "StarBolt" },
				{ t = 0.5, k = "Hit", i = 1 },
			},
		},
		-- 3페이지 인위적 별자리: 왼손으로 허공에 별자리를 긋고 그 별들이 대상 둘레에 내리꽂힌다
		CallistoArtificial = {
			Duration = 1.7,
			Keys = {
				K(0, nil, OBS),
				K(0.35, "sineOut", AIM, { LArm = { 130, -30, -20 }, Head = { 10, 20, 0 } }),
				K(0.75, "sineInOut", AIM, { LArm = { 110, 30, 10 }, Head = { 6, 30, 0 } }),
				K(1.0, "expoOut", AIM, { LArm = { 70, 0, -10 }, Torso = { -8, -18, 0 } }),
				K(1.7, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Constellation" },
				{ t = 1.0, k = "Hit", i = 1 },
				{ t = 1.0, k = "Shake", a = 0.3, d = 0.2 },
			},
		},
		-- 3페이지 쏟아지는 뭇별(3번 중 한 번): 두 팔을 들어 별을 떨군다
		CallistoShower = {
			Duration = 1.0,
			Keys = {
				K(0, nil, OBS),
				K(0.3, "sineOut", SKY),
				K(0.42, "expoOut", SKY, { RArm = { 110, 0, 20 }, LArm = { 110, 0, -20 }, Torso = { -4, 0, 0 }, Head = { 0, 0, 0 } }),
				K(1.0, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.34, k = "Fx", n = "StarShower" },
				{ t = 0.56, k = "Hit", i = 1 },
			},
		},
		-- 3페이지 뭇별 아래에 잠기리: 떠올라 두 팔을 펴고 하늘을 내린다(장판 10턴, 회피 불가)
		CallistoSubmerge = {
			Duration = 2.6,
			Keys = {
				K(0, nil, OBS),
				K(0.8, "sineOut", SKY, { Root = { 0, 1.2, 0, 0, 0, 0 } }),
				K(1.5, nil, SKY, { Root = { 0, 1.4, 0, 0, 0, 0 }, RArm = { 120, 0, 60 }, LArm = { 120, 0, -60 } }),
				K(1.62, "expoOut", SKY, { Root = { 0, 1.0, 0, 0, 0, 0 }, RArm = { 90, 0, 80 }, LArm = { 90, 0, -80 }, Head = { 0, 0, 0 } }),
				K(2.6, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.2, k = "Fx", n = "Submerge" },
				{ t = 1.62, k = "Hit", i = 1 },
				{ t = 1.62, k = "Shake", a = 0.6, d = 0.6 },
			},
		},
	},
}
