--!strict
--[[
	광전사 — 핏빛 룬 데인 액스를 든 짐승. (2026-09-28, 자세 다시 2026-09-30)

	성격: 광포함. 깊게 웅크려 고개만 치켜들고 노려보며, 가슴이 크게 들썩인다(거친 숨).
	      맞으면 움찔한 뒤 **포효**로 받아친다. 피하지 않고 파고들어 어깨로 들이받는다.
	      공격은 전부 온몸을 싣는다 — 도약 내려찍기, 대각 두 번 베기, 두 바퀴 회전 후 내려찍기.
	참고: 데인 액스(10~11세기) — 두 손을 벌려 한 손은 자루 끝, 다른 손은 머리 쪽 높이 쥐고 도끼를 조종한다.
	      크게 벨 때는 위 손을 아래로 미끄러뜨려 두 손을 모은다. 방패 없이 자루로 막는다.
	무기 종류: Axe2H (WeaponDefinitions.Greataxe). 오른손이 머리 쪽, 왼손이 자루 끝.
	      무기 자리 y(-1.69 등) = 오른손이 쥔 자루 자리로 도끼를 밀어 맞춘 값(tools/combat/posecalc.py 로 구함).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 대기(데인 액스 가드): 웅크리고 고개만 치켜듦. 도끼 머리는 오른 어깨 바깥 높이(머리 위로 비켜), 자루는 몸 앞을 대각으로 왼 허리까지 —
-- 오른손은 머리 쪽 가죽, 왼손은 자루 끝 가죽을 벌려 쥔다
local FERAL = { Root = { 0, -0.55, 0, 0, -16, 0 }, Torso = { -28, 0, 0 }, Head = { 26, 12, 0 }, RArm = { 168, 27.4, -7.6 }, LArm = { 93.6, -45.9, 15.4 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0, -1.5, 0.02, -53.1, -34.6, -27.3 } }
-- 머리 위로 치켜듦: 위 손을 미끄러뜨려 두 손을 모으고, 도끼 머리는 등 뒤
local HIGH = { Root = { 0, 0, 0.3, 0, -12, 0 }, Torso = { 18, 0, 0 }, Head = { 20, 8, 0 }, RArm = { 137.2, 50.1, -27.6 }, LArm = { 117.2, -48.1, 14.1 }, RLeg = { 12, 0, 16 }, LLeg = { -22, 0, -16 }, W = { 0, -0.4, 0.01, 23, -51.9, 51.8 } }
-- 내려찍은 끝: 날이 앞 땅에 박힘
local SLAM = { Root = { 0, -1.1, -0.7, 0, -12, 0 }, Torso = { -46, 0, 0 }, Head = { 30, 8, 0 }, RArm = { 70.7, 43.2, -8.2 }, LArm = { 57.9, -54.3, 24.7 }, RLeg = { 50, 0, 16 }, LLeg = { -40, 0, -16 }, W = { 0, -0.41, -0.01, -51.4, -204.5, 46.2 } }
-- 쌍베기: 오른 위 예비(A0) → 왼 아래 끝(A1), 왼 위 예비(B0) → 오른 아래 끝(B1)
local CUT_A0 = { Root = { 0, -0.3, 0.2, 0, -40, 0 }, Torso = { -4, -30, 0 }, Head = { 16, 40, 0 }, RArm = { 141.2, 38.7, -25.1 }, LArm = { 115.5, -53.4, 5.6 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0, -0.6, 0.01, -1.9, -78.3, 4.6 } }
local CUT_A1 = { Root = { 0, -0.8, -0.5, 0, 10, 0 }, Torso = { -36, 30, 0 }, Head = { 26, -10, 0 }, RArm = { 84.6, 53.4, -9.9 }, LArm = { 81.6, -62.9, 24 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 }, W = { 0, -0.59, 0.01, -108.7, -57.2, -34.9 } }
local CUT_B0 = { Root = { 0, -0.4, -0.3, 0, 20, 0 }, Torso = { -6, 36, 0 }, Head = { 16, -20, 0 }, RArm = { 130.2, 60.7, -24.3 }, LArm = { 107.7, -44.5, 25.3 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0, -0.59, 0, -191.5, -125.6, -129.4 } }
local CUT_B1 = { Root = { 0, -0.9, -0.9, 0, -30, 0 }, Torso = { -38, -30, 0 }, Head = { 28, 30, 0 }, RArm = { 76.2, 34.8, 5.2 }, LArm = { 74.1, -57.2, 11.7 }, RLeg = { 44, 0, 18 }, LLeg = { -38, 0, -18 }, W = { 0, -0.59, 0, -197.2, -190.8, -258.3 } }
-- 회오리: 두 손을 자루 끝에 모아 도끼를 오른쪽 옆으로 수평으로 뻗는다
local WHIRL = { Root = { 0, -0.5, 0, 0, 30, 0 }, Torso = { -14, 30, 0 }, Head = { 20, -30, 0 }, RArm = { 86.2, 64.2, 15.7 }, LArm = { 85.6, -10.4, 30.4 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0, -0.21, -0.01, 2.7, -54.2, -88.5 } }
-- 막기: 자루를 가로로 들어 얼굴 앞에서 받는다
local BLOCK = { Root = { 0, -0.7, 0.2, 0, -10, 0 }, Torso = { -14, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 92.9, 60.5, -18.1 }, LArm = { 87.3, -60.5, 18.1 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { -0.11, -0.38, 0.02, -84.4, -177.4, -11.2 } }
-- 명상: 도끼 머리를 앞 땅에 비스듬히 박고 쭈그려 앉아 자루 끝에 두 손을 얹는다
local PLANT = { Root = { 0, -1.2, 0, 0, -16, 0 }, Torso = { -30, 0, 0 }, Head = { 10, 10, 0 }, RArm = { 66.3, 57.7, -24.8 }, LArm = { 61.4, -41.6, 8.3 }, RLeg = { 90, 0, 20 }, LLeg = { 90, 0, -20 }, W = { -0.01, 0.39, -0.01, 109.9, -1.5, -99.2 } }
-- 한 손: 오른손이 자루 끝을 쥐고 도끼 머리를 뒤 아래로 끈다(돌진·들이받기) / 포효하며 한 손으로 치켜듦
local DRAG_FWD = { Root = { 0, -1, 0.2, 0, -16, 0 }, Torso = { -40, 0, 0 }, Head = { 30, 12, 0 }, RArm = { 20, 22, 14 }, LArm = { 20, -22, 0 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 }, W = { 0, 0, 0, -3.9, 11, -189.3 } }
local ROAR = { Root = { 0, -0.3, 0.1, 0, -16, 0 }, Torso = { 22, 0, 0 }, Head = { 40, 10, 0 }, RArm = { 100, -40, 60 }, LArm = { 100, 40, -60 }, RLeg = { 16, 0, 18 }, LLeg = { -14, 0, -18 }, W = { 0, 0, 0, -42, -5.1, 7 } }

return {
	Stance = FERAL,

	-- 대기: 거친 숨(가슴·어깨가 크게 오르내림 — 도끼도 함께 들썩), 이따금 고개를 홱 꺾는다
	Idle = {
		Duration = 2.86,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", FERAL),
			K(0.585, "quadOut", FERAL, { Torso = { -20, 0, 0 }, Head = { 18, 12, 0 }, Root = { 0, -0.48, 0, 0, -16, 0 } }),
			K(1.3, "sineInOut", FERAL),
			K(1.885, "quadOut", FERAL, { Torso = { -20, 0, 0 }, Head = { 18, 12, 0 }, Root = { 0, -0.48, 0, 0, -16, 0 } }),
			K(2.106, "expoOut", FERAL, { Torso = { -22, 0, 0 }, Head = { 20, 30, 14 } }),
			K(2.47, "sineInOut", FERAL, { Head = { 24, 16, 4 } }),
		},
	},

	-- 들림: 발버둥 — 한 손으로 도끼를 마구 휘두르고 팔다리를 휘젓는다
	Held = {
		Duration = 0.6,
		Loop = true,
		Keys = {
			K(0, "linear", ROAR, { Root = { 0, 0, 0, 10, -16, 8 }, Torso = { -10, 10, 0 }, Head = { 20, -20, 0 }, RArm = { 140, 30, 20 }, LArm = { 60, -40, -40 }, W = { 0, 0, 0, -40, 0, 0 }, RLeg = { 40, 0, 10 }, LLeg = { -30, 0, -10 } }),
			K(0.15, "linear", ROAR, { Root = { 0, 0.1, 0, -6, -16, -8 }, Torso = { -14, -10, 0 }, Head = { 26, 20, 0 }, RArm = { 60, 30, 40 }, LArm = { 130, -30, -20 }, W = { 0, 0, 0, 10, 0, 0 }, RLeg = { -30, 0, 10 }, LLeg = { 40, 0, -10 } }),
			K(0.3, "linear", ROAR, { Root = { 0, 0, 0, 8, -16, 6 }, Torso = { -8, 6, 0 }, Head = { 16, -10, 0 }, RArm = { 150, 20, 10 }, LArm = { 70, -30, -50 }, W = { 0, 0, 0, -60, 0, 0 }, RLeg = { 36, 0, 10 }, LLeg = { -20, 0, -10 } }),
			K(0.45, "linear", ROAR, { Root = { 0, 0.1, 0, -8, -16, -6 }, Torso = { -14, -8, 0 }, Head = { 24, 16, 0 }, RArm = { 70, 40, 30 }, LArm = { 140, -20, -20 }, W = { 0, 0, 0, 0, 0, 0 }, RLeg = { -36, 0, 10 }, LLeg = { 30, 0, -10 } }),
		},
	},

	-- 내려놓임: 쿵 — 도끼를 앞 땅에 박으며 한쪽 무릎으로 착지(땅이 팬다) → 한 손으로 도끼를 치켜들고 포효
	Drop = {
		Duration = 1.4,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, HIGH, { Root = { 0, 0.4, 0.3, 0, -12, 0 } }),
			K(0.08, "quadIn", SLAM, { Root = { 0, -1.3, -0.5, 0, -12, 0 }, RLeg = { 90, 0, 14 }, LLeg = { -60, 0, -10 } }),
			K(0.55, "sineOut", SLAM, { Root = { 0, -1.28, -0.5, 0, -12, 0 }, Torso = { -44, 0, 0 }, RLeg = { 90, 0, 14 }, LLeg = { -60, 0, -10 } }),
			-- 포효
			K(0.8, "backOut", ROAR),
			K(1.1, "sineOut", ROAR, { Torso = { 24, 0, 0 }, Head = { 42, 10, 0 }, RArm = { 104, -42, 62 }, LArm = { 104, 42, -62 } }),
			K(1.4, "sineInOut", FERAL),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "Crater" },
			{ t = 0.09, k = "Shake", a = 0.5, d = 0.35 },
			{ t = 0.8, k = "Fx", n = "Roar" },
		},
	},

	-- 피격: 움찔 → 곧장 도끼를 치켜들고 포효로 받아친다(아픔이 연료)
	Hit = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FERAL),
			K(0.05, "expoOut", FERAL, { Root = { 0, -0.5, 0.5, 0, -16, 0 }, Torso = { -12, 0, 0 }, Head = { 10, 12, 0 } }),
			K(0.3, "backOut", ROAR, { Root = { 0, -0.35, 0.3, 0, -16, 0 }, Torso = { 18, 0, 0 }, Head = { 38, 10, 0 } }),
			K(0.5, "sineOut", ROAR, { Root = { 0, -0.35, 0.3, 0, -16, 0 }, Torso = { 20, 0, 0 } }),
			K(0.8, "sineInOut", FERAL),
		},
		Events = { { t = 0.3, k = "Fx", n = "Roar" } },
	},

	-- 방어: 도끼 자루를 가로로 들어 받고, 이를 드러내며 버틴다
	Guard = {
		Duration = 0.7,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, FERAL),
			K(0.07, "expoOut", BLOCK),
			K(0.2, "sineOut", BLOCK, { Root = { 0, -0.8, 0.4, 0, -10, 0 }, Torso = { -16, 0, 0 }, Head = { 18, 10, 0 } }),
			K(0.7, "sineInOut", FERAL),
		},
		Events = { { t = 0.08, k = "Fx", n = "HaftBlock" } },
	},

	-- 회피: 낮게 숙여 공격 밑으로 파고들고, 도끼를 뒤로 끌며 어깨로 들이받는다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FERAL),
			K(0.08, "expoOut", DRAG_FWD, { Root = { 0, -1.2, 0, 0, -30, 0 }, Torso = { -50, 0, 0 }, Head = { 36, 12, 0 }, RLeg = { 44, 0, 18 }, LLeg = { -40, 0, -18 } }),
			K(0.2, "expoOut", DRAG_FWD, { Root = { 0, -0.7, -1.0, 0, 20, 0 }, Torso = { -30, 30, 0 }, Head = { 20, -20, 0 }, LArm = { 70, -30, -30 }, RLeg = { 40, 0, 18 }, LLeg = { -40, 0, -18 } }),
			K(0.4, "sineOut", DRAG_FWD, { Root = { 0, -0.7, -0.9, 0, 16, 0 }, Torso = { -28, 26, 0 }, Head = { 20, -16, 0 }, LArm = { 70, -30, -30 }, RLeg = { 38, 0, 18 }, LLeg = { -36, 0, -18 } }),
			K(0.7, "sineInOut", FERAL),
		},
		Events = { { t = 0.2, k = "Fx", n = "ShoulderCheck" } },
	},

	Skills = {
		-- 핏빛 분쇄: 도끼를 뒤로 끌며 웅크렸다 도약해 두 손 내려찍기 — 피가 터지고 땅이 팬다
		BloodCrash = {
			Duration = 1.7,
			Keys = {
				K(0, nil, FERAL),
				K(0.2, "quadOut", DRAG_FWD),
				K(0.45, "cubicOut", HIGH, { Root = { 0, 0.4, 0.3, 0, -12, 0 } }),
				K(0.55, "expoOut", SLAM),
				K(1.0, "linear", SLAM, { Root = { 0, -1.05, -0.7, 0, -12, 0 } }),
				K(1.3, "cubicInOut", FERAL, { Torso = { -22, 0, 0 } }),
				K(1.7, "sineInOut", FERAL),
			},
			Events = {
				{ t = 0.22, k = "Fx", n = "BloodBoil" },
				{ t = 0.22, k = "Dash", to = "Target", gap = 4.2, d = 0.3, arc = 3.5 },
				{ t = 0.42, k = "Trail", on = true },
				{ t = 0.55, k = "Hit", i = 1, fx = "BloodCrash" },
				{ t = 0.56, k = "Stop", d = 0.14 },
				{ t = 0.57, k = "Shake", a = 0.9, d = 0.5 },
				{ t = 0.7, k = "Trail", on = false },
				{ t = 1.15, k = "Dash", to = "Home", d = 0.35 },
			},
		},

		-- 쌍베기: 오른 위에서 왼 아래로, 곧장 왼 위에서 오른 아래로 — 한 걸음씩 파고든다
		DoubleSlash = {
			Duration = 1.5,
			Keys = {
				K(0, nil, FERAL),
				K(0.2, "cubicOut", CUT_A0),
				K(0.3, "expoOut", CUT_A1),
				K(0.46, "cubicOut", CUT_B0),
				K(0.56, "expoOut", CUT_B1),
				K(0.95, "sineOut", CUT_B1, { Root = { 0, -0.86, -0.9, 0, -30, 0 }, Torso = { -34, -30, 0 }, Head = { 26, 30, 0 } }),
				K(1.5, "sineInOut", FERAL),
			},
			Events = {
				{ t = 0.05, k = "Dash", to = "Target", gap = 4, d = 0.2 },
				{ t = 0.2, k = "Trail", on = true },
				{ t = 0.3, k = "Hit", i = 1, fx = "AxeSlashA" },
				{ t = 0.31, k = "Stop", d = 0.06 },
				{ t = 0.56, k = "Hit", i = 2, fx = "AxeSlashB" },
				{ t = 0.57, k = "Stop", d = 0.1 },
				{ t = 0.58, k = "Shake", a = 0.5, d = 0.3 },
				{ t = 0.75, k = "Trail", on = false },
				{ t = 1.05, k = "Dash", to = "Home", d = 0.3 },
			},
		},

		-- 광역 폭발: 도끼를 옆으로 뻗고 두 바퀴 회오리 → 머리 위로 들어 땅에 내리꽂아 폭발
		Burst = {
			Duration = 2.0,
			Keys = {
				K(0, nil, FERAL),
				K(0.2, "cubicOut", WHIRL),
				K(0.5, "linear", WHIRL, { Root = { 0, -0.6, 0, 0, -330, 0 } }),
				K(0.8, "linear", WHIRL, { Root = { 0, -0.6, 0, 0, -690, 0 } }),
				K(1.0, "cubicOut", HIGH, { Root = { 0, 0.2, 0.3, 0, -732, 0 } }),
				K(1.1, "expoOut", SLAM, { Root = { 0, -1.1, -0.5, 0, -732, 0 } }),
				K(1.55, "linear", SLAM, { Root = { 0, -1.05, -0.5, 0, -732, 0 } }),
				K(2.0, "sineInOut", FERAL, { Root = { 0, -0.55, 0, 0, -736, 0 } }),
			},
			Events = {
				{ t = 0.2, k = "Trail", on = true },
				{ t = 0.25, k = "Fx", n = "Whirl" },
				{ t = 0.55, k = "Fx", n = "Whirl" },
				{ t = 1.1, k = "Hit", i = 1, fx = "BurstBlast" },
				{ t = 1.11, k = "Stop", d = 0.12 },
				{ t = 1.12, k = "Shake", a = 0.8, d = 0.5 },
				{ t = 1.3, k = "Trail", on = false },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, FERAL),
				K(0.14, "backOut", BLOCK),
				K(0.8, "sineInOut", BLOCK, { Root = { 0, -0.72, 0.2, 0, -10, 0 }, Torso = { -15, 0, 0 } }),
				K(1.1, "sineInOut", FERAL),
			},
			Events = { { t = 0.14, k = "Fx", n = "HaftBlock" } },
		},

		-- 명상: 도끼날을 앞 땅에 박고 쭈그려 앉아 자루 끝에 두 손을 얹고 이를 악물고 숨을 고른다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, FERAL),
				K(0.4, "cubicInOut", PLANT),
				K(1.0, "sineInOut", PLANT, { Root = { 0, -1.15, 0, 0, -16, 0 }, Torso = { -24, 0, 0 }, Head = { 14, 10, 0 } }),
				K(1.5, "sineInOut", PLANT),
				K(2.0, "sineInOut", FERAL),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
