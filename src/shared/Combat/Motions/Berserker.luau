--!strict
--[[
	광전사 — 핏빛 룬 도끼를 든 짐승. (2026-09-28)

	성격: 광포함. 깊게 웅크려 고개만 치켜들고 노려보며, 가슴이 크게 들썩인다(거친 숨). 도끼는 낮게 끌고 다닌다.
	      맞으면 움찔한 뒤 **포효**로 받아친다. 피하지 않고 파고들어 어깨로 들이받는다.
	      공격은 전부 온몸을 싣는다 — 도약 내려찍기, 대각 두 번 베기, 두 바퀴 회전 후 내려찍기.
	무기 종류: Axe2H (WeaponDefinitions.Greataxe). 두 손을 가슴 앞 한 점으로 모은다(오른팔 Y +, 왼팔 Y -)
	  도끼 방향 = 팔 X + 90 + 숙임. 날 = 앞(-Z)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 깊게 웅크리고 고개를 치켜든 자세. 도끼는 오른쪽 뒤로 낮게 끈다
local FERAL = {
	Root = { 0, -0.55, 0, 0, -16, 0 },
	Torso = { -28, 0, 0 },
	Head = { 26, 12, 0 },
	-- 오른팔은 몸 옆으로 늘어뜨려 조금 뒤로(손이 오른 허벅지 바깥). 예전엔 손이 몸 앞 가운데라
	-- 자루가 다리 사이를 꿰뚫고 도끼 머리가 땅에 납작 붙었다(2026-09-29 고침)
	RArm = { -10, 0, 22 },
	LArm = { 34, -22, 0 },
	RLeg = { 30, 0, 18 },
	LLeg = { -24, 0, -18 },
	-- 도끼 머리가 오른쪽 뒤 땅에 날을 세워 끌림(옆에서 본 각 ≈ 300° = 뒤 아래)
	W = { 0.5, 0, 0, 258, 0, 0 },
}
-- 팔을 앞으로 모은 키(들이받기·도약 전 웅크림)에서 도끼가 뒤 아래로 끌리는 각(예전엔 205 라 머리가 땅에 박혔다)
local TRAIL_W = { 0.5, 0, 0, 228, 0, 0 }
-- 두 손으로 머리 위로 치켜듦(도끼날이 등 뒤로)
local HIGH = W(FERAL, {
	Root = { 0, 0, 0.3, 0, -12, 0 },
	Torso = { 18, 0, 0 },
	Head = { 20, 8, 0 },
	RArm = { 178, 22, 0 },
	LArm = { 178, -22, 0 },
	W = { 0, 0, 0, -12, 0, 0 },
	RLeg = { 12, 0, 16 },
	LLeg = { -22, 0, -16 },
})
-- 내려찍은 끝(도끼날이 앞 땅에)
local SLAM = W(FERAL, {
	Root = { 0, -1.1, -0.7, 0, -12, 0 },
	Torso = { -46, 0, 0 },
	Head = { 30, 8, 0 },
	RArm = { 80, 24, 0 },
	LArm = { 80, -24, 0 },
	-- 날이 바닥에 닿게(옆에서 본 각 ≈ 75°: 손이 낮아 더 세우면 날이 땅에 묻힌다)
	W = { 0, 0, 0, -50, 0, 0 },
	RLeg = { 50, 0, 16 },
	LLeg = { -40, 0, -16 },
})

return {
	Stance = FERAL,

	-- 대기: 거친 숨(가슴·어깨가 크게 오르내림), 이따금 고개를 홱 꺾는다
	Idle = {
		Duration = 2.86,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", FERAL),
			K(0.585, "quadOut", FERAL, { Torso = { -18, 0, 0 }, Head = { 18, 12, 0 }, RArm = { -4, 0, 24 }, LArm = { 42, -22, 0 }, Root = { 0, -0.48, 0, 0, -16, 0 } }),
			K(1.3, "sineInOut", FERAL),
			K(1.885, "quadOut", FERAL, { Torso = { -18, 0, 0 }, Head = { 18, 12, 0 }, RArm = { -4, 0, 24 }, LArm = { 42, -22, 0 }, Root = { 0, -0.48, 0, 0, -16, 0 } }),
			K(2.106, "expoOut", FERAL, { Torso = { -20, 0, 0 }, Head = { 20, 30, 14 } }),
			K(2.47, "sineInOut", FERAL, { Head = { 24, 16, 4 } }),
		},
	},

	-- 들림: 발버둥 — 팔다리를 마구 휘젓고 도끼를 휘두른다
	Held = {
		Duration = 0.6,
		Loop = true,
		Keys = {
			K(0, "linear", FERAL, { Root = { 0, 0, 0, 10, -16, 8 }, Torso = { -10, 10, 0 }, Head = { 20, -20, 0 }, RArm = { 140, 30, 20 }, LArm = { 60, -40, -40 }, W = { 0, 0, 0, -40, 0, 0 }, RLeg = { 40, 0, 10 }, LLeg = { -30, 0, -10 } }),
			K(0.15, "linear", FERAL, { Root = { 0, 0.1, 0, -6, -16, -8 }, Torso = { -14, -10, 0 }, Head = { 26, 20, 0 }, RArm = { 60, 30, 40 }, LArm = { 130, -30, -20 }, W = { 0, 0, 0, 20, 0, 0 }, RLeg = { -30, 0, 10 }, LLeg = { 40, 0, -10 } }),
			K(0.3, "linear", FERAL, { Root = { 0, 0, 0, 8, -16, 6 }, Torso = { -8, 6, 0 }, Head = { 16, -10, 0 }, RArm = { 150, 20, 10 }, LArm = { 70, -30, -50 }, W = { 0, 0, 0, -60, 0, 0 }, RLeg = { 36, 0, 10 }, LLeg = { -20, 0, -10 } }),
			K(0.45, "linear", FERAL, { Root = { 0, 0.1, 0, -8, -16, -6 }, Torso = { -14, -8, 0 }, Head = { 24, 16, 0 }, RArm = { 70, 40, 30 }, LArm = { 140, -20, -20 }, W = { 0, 0, 0, 10, 0, 0 }, RLeg = { -36, 0, 10 }, LLeg = { 30, 0, -10 } }),
		},
	},

	-- 내려놓임: 쿵 — 한쪽 무릎과 왼 주먹으로 땅을 짚는 착지(땅이 팬다) → 일어서며 포효
	Drop = {
		Duration = 1.4,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, FERAL, { Root = { 0, 0.4, 0, 0, -16, 0 }, Torso = { -10, 0, 0 } }),
			K(0.08, "quadIn", FERAL, { Root = { 0, -1.3, -0.2, 0, -16, 0 }, Torso = { -46, 0, 0 }, Head = { 30, 12, 0 }, RArm = { 60, 10, 70 }, W = { 0.5, 0, 0, 380, 0, 0 }, LArm = { 70, -10, -10 }, RLeg = { 90, 0, 14 }, LLeg = { -60, 0, -10 } }),
			K(0.55, "sineOut", FERAL, { Root = { 0, -1.28, -0.2, 0, -16, 0 }, Torso = { -44, 0, 0 }, Head = { 30, 12, 0 }, RArm = { 60, 10, 70 }, W = { 0.5, 0, 0, 380, 0, 0 }, LArm = { 70, -10, -10 }, RLeg = { 90, 0, 14 }, LLeg = { -60, 0, -10 } }),
			-- 포효
			K(0.8, "backOut", FERAL, { Root = { 0, -0.3, 0.1, 0, -16, 0 }, Torso = { 22, 0, 0 }, Head = { 40, 10, 0 }, RArm = { 100, -40, 60 }, LArm = { 100, 40, -60 }, W = { 0.5, 0, 0, 324, 0, 0 }, RLeg = { 16, 0, 18 }, LLeg = { -14, 0, -18 } }),
			K(1.1, "sineOut", FERAL, { Root = { 0, -0.3, 0.1, 0, -16, 0 }, Torso = { 24, 0, 0 }, Head = { 42, 10, 0 }, RArm = { 104, -42, 62 }, LArm = { 104, 42, -62 }, W = { 0.5, 0, 0, 324, 0, 0 }, RLeg = { 16, 0, 18 }, LLeg = { -14, 0, -18 } }),
			K(1.4, "sineInOut", FERAL),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "Crater" },
			{ t = 0.09, k = "Shake", a = 0.5, d = 0.35 },
			{ t = 0.8, k = "Fx", n = "Roar" },
		},
	},

	-- 피격: 움찔 → 곧장 포효로 받아친다(아픔이 연료)
	Hit = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FERAL),
			K(0.05, "expoOut", FERAL, { Root = { 0, -0.5, 0.5, 0, -16, 0 }, Torso = { -10, 0, 0 }, Head = { 10, 12, 0 } }),
			K(0.3, "backOut", FERAL, { Root = { 0, -0.35, 0.3, 0, -16, 0 }, Torso = { 18, 0, 0 }, Head = { 38, 10, 0 }, RArm = { 90, -30, 50 }, LArm = { 90, 30, -50 }, W = { 0.5, 0, 0, 324, 0, 0 } }),
			K(0.5, "sineOut", FERAL, { Root = { 0, -0.35, 0.3, 0, -16, 0 }, Torso = { 20, 0, 0 }, Head = { 40, 10, 0 }, RArm = { 92, -32, 52 }, LArm = { 92, 32, -52 }, W = { 0.5, 0, 0, 324, 0, 0 } }),
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
			K(0.07, "expoOut", FERAL, { Root = { 0, -0.7, 0.2, 0, -10, 0 }, Torso = { -14, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 100, 20, 30 }, LArm = { 100, -20, -30 }, W = { 0, -1.5, 0, -90, 0, 90 } }),
			K(0.2, "sineOut", FERAL, { Root = { 0, -0.8, 0.4, 0, -10, 0 }, Torso = { -16, 0, 0 }, Head = { 18, 10, 0 }, RArm = { 98, 20, 30 }, LArm = { 98, -20, -30 }, W = { 0, -1.5, 0, -90, 0, 90 } }),
			K(0.7, "sineInOut", FERAL),
		},
		Events = { { t = 0.08, k = "Fx", n = "HaftBlock" } },
	},

	-- 회피: 낮게 숙여 공격 밑으로 파고들고, 어깨로 들이받는다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FERAL),
			K(0.08, "expoOut", FERAL, { Root = { 0, -1.2, 0, 0, -30, 0 }, Torso = { -50, 0, 0 }, Head = { 36, 12, 0 }, RLeg = { 44, 0, 18 }, LLeg = { -40, 0, -18 } }),
			K(0.2, "expoOut", FERAL, { W = TRAIL_W, Root = { 0, -0.7, -1.0, 0, 20, 0 }, Torso = { -30, 30, 0 }, Head = { 20, -20, 0 }, RArm = { 20, 22, 30 }, LArm = { 70, -30, -30 }, RLeg = { 40, 0, 18 }, LLeg = { -40, 0, -18 } }),
			K(0.4, "sineOut", FERAL, { W = TRAIL_W, Root = { 0, -0.7, -0.9, 0, 16, 0 }, Torso = { -28, 26, 0 }, Head = { 20, -16, 0 }, RArm = { 20, 22, 30 }, LArm = { 70, -30, -30 }, RLeg = { 38, 0, 18 }, LLeg = { -36, 0, -18 } }),
			K(0.7, "sineInOut", FERAL),
		},
		Events = { { t = 0.2, k = "Fx", n = "ShoulderCheck" } },
	},

	Skills = {
		-- 핏빛 분쇄: 웅크렸다 도약해 두 손 내려찍기 — 피가 터지고 땅이 팬다
		BloodCrash = {
			Duration = 1.7,
			Keys = {
				K(0, nil, FERAL),
				K(0.2, "quadOut", FERAL, { W = TRAIL_W, Root = { 0, -1.0, 0.2, 0, -16, 0 }, Torso = { -40, 0, 0 }, RArm = { 20, 22, 14 }, LArm = { 20, -22, 0 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 } }),
				K(0.45, "cubicOut", HIGH, { Root = { 0, 0.4, 0.3, 0, -12, 0 } }),
				K(0.55, "expoOut", SLAM),
				K(1.0, "linear", SLAM, { Root = { 0, -1.05, -0.7, 0, -12, 0 } }),
				K(1.3, "cubicInOut", FERAL, { Torso = { -20, 0, 0 } }),
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
				K(0.2, "cubicOut", FERAL, { Root = { 0, -0.3, 0.2, 0, -40, 0 }, Torso = { -4, -30, 0 }, Head = { 16, 40, 0 }, RArm = { 160, -50, 20 }, LArm = { 160, -80, 0 }, W = { 0, 0, 0, -40, 90, 0 } }),
				K(0.3, "expoOut", FERAL, { Root = { 0, -0.8, -0.5, 0, 10, 0 }, Torso = { -36, 30, 0 }, Head = { 26, -10, 0 }, RArm = { 50, 60, 10 }, LArm = { 50, 30, 0 }, W = { 0, 0, 0, -80, 90, 0 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 } }),
				K(0.46, "cubicOut", FERAL, { Root = { 0, -0.4, -0.3, 0, 20, 0 }, Torso = { -6, 36, 0 }, Head = { 16, -20, 0 }, RArm = { 160, 70, 10 }, LArm = { 160, 40, 0 }, W = { 0, 0, 0, -40, -90, 0 } }),
				K(0.56, "expoOut", FERAL, { Root = { 0, -0.9, -0.9, 0, -30, 0 }, Torso = { -38, -30, 0 }, Head = { 28, 30, 0 }, RArm = { 50, -40, 20 }, LArm = { 50, -70, 0 }, W = { 0, 0, 0, -80, -90, 0 }, RLeg = { 44, 0, 18 }, LLeg = { -38, 0, -18 } }),
				K(0.95, "sineOut", FERAL, { Root = { 0, -0.86, -0.9, 0, -30, 0 }, Torso = { -34, -30, 0 }, Head = { 26, 30, 0 }, RArm = { 48, -42, 20 }, LArm = { 48, -72, 0 }, W = { 0, 0, 0, -80, -90, 0 }, RLeg = { 42, 0, 18 }, LLeg = { -36, 0, -18 } }),
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
				K(0.2, "cubicOut", FERAL, { Root = { 0, -0.5, 0, 0, 30, 0 }, Torso = { -14, 30, 0 }, Head = { 20, -30, 0 }, RArm = { 90, 70, 30 }, LArm = { 90, 40, 0 }, W = { 0, 0, 0, -86, 90, 0 } }),
				K(0.5, "linear", FERAL, { Root = { 0, -0.6, 0, 0, -330, 0 }, Torso = { -20, 0, 0 }, Head = { 20, 0, 0 }, RArm = { 90, -70, 0 }, LArm = { 90, -40, 0 }, W = { 0, 0, 0, -86, 90, 0 } }),
				K(0.8, "linear", FERAL, { Root = { 0, -0.6, 0, 0, -690, 0 }, Torso = { -20, 0, 0 }, Head = { 20, 0, 0 }, RArm = { 90, -70, 0 }, LArm = { 90, -40, 0 }, W = { 0, 0, 0, -86, 90, 0 } }),
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
				K(0.14, "backOut", FERAL, { Root = { 0, -0.7, 0.2, 0, -10, 0 }, Torso = { -14, 0, 0 }, RArm = { 100, 20, 30 }, LArm = { 100, -20, -30 }, W = { 0, -1.5, 0, -90, 0, 90 } }),
				K(0.8, "sineInOut", FERAL, { Root = { 0, -0.72, 0.2, 0, -10, 0 }, Torso = { -15, 0, 0 }, RArm = { 100, 20, 30 }, LArm = { 100, -20, -30 }, W = { 0, -1.5, 0, -90, 0, 90 } }),
				K(1.1, "sineInOut", FERAL),
			},
			Events = { { t = 0.14, k = "Fx", n = "HaftBlock" } },
		},

		-- 명상: 도끼를 땅에 박고 그 앞에 쭈그려 앉아 이를 악물고 숨을 고른다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, FERAL),
				K(0.4, "cubicInOut", FERAL, { Root = { 0, -1.2, 0, 0, -16, 0 }, Torso = { -30, 0, 0 }, Head = { 10, 10, 0 }, RArm = { 60, 20, 0 }, LArm = { 60, -20, 0 }, W = { 0, 0, 0, -150, 0, 0 }, RLeg = { 90, 0, 20 }, LLeg = { 90, 0, -20 } }),
				K(1.0, "sineInOut", FERAL, { Root = { 0, -1.15, 0, 0, -16, 0 }, Torso = { -24, 0, 0 }, Head = { 14, 10, 0 }, RArm = { 62, 20, 0 }, LArm = { 62, -20, 0 }, W = { 0, 0, 0, -150, 0, 0 }, RLeg = { 90, 0, 20 }, LLeg = { 90, 0, -20 } }),
				K(1.5, "sineInOut", FERAL, { Root = { 0, -1.2, 0, 0, -16, 0 }, Torso = { -30, 0, 0 }, Head = { 10, 10, 0 }, RArm = { 60, 20, 0 }, LArm = { 60, -20, 0 }, W = { 0, 0, 0, -150, 0, 0 }, RLeg = { 90, 0, 20 }, LLeg = { 90, 0, -20 } }),
				K(2.0, "sineInOut", FERAL),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
