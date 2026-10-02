--!strict
--[[
	펄서 — 오브 셋을 거느린 떠 있는 마법사. (2026-09-28, 자세 다시 2026-09-30)

	성격: 고요하고 초연함. 늘 발이 땅에서 떠 있고(Root y +0.8), 두 발목을 모아 발끝을 늘어뜨린다.
	참고: 태극권 참장 포구(抱球) — 두 팔을 둥글게 가슴 앞에 모아 큰 공을 안은 듯, 손바닥이 마주 본다.
	      손짓이 곧 주문 — 손을 펴고 모으는 대로 오브가 대형을 바꾼다(Orbs 사건).
	      피할 때는 걷지 않고 **순간 이동**하듯 미끄러진다. 맞으면 공중에서 뒤로 튕겨 돈다.
	무기 종류: Orbs (WeaponDefinitions.Orbs, Hand = Float). 손에 쥐는 것이 없다.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 떠 있는 자세(태극권 포구 抱球 — 가슴 앞에 큰 공을 안듯 두 팔을 둥글게, 오른손이 위·왼손이 아래로 손바닥을 마주):
-- 몸을 카메라 쪽으로 조금 열고, 다리는 모아 발끝을 뒤로. 팔 각도는 손이 가슴 앞 공 둘레에 오도록 posecalc 로 구함
local BALL_R = { RArm = { 80.6, 37.7, -7.3 }, LArm = { 50.7, -42.1, 12.8 } }
local BALL_L = { RArm = { 50.7, 42.1, -12.8 }, LArm = { 80.6, -37.7, 7.3 } }
local BALL_MID = { RArm = { 66.3, 37.8, -4.7 }, LArm = { 66.3, -37.8, 4.7 } }
local FLOAT = {
	Root = { 0, 0.8, 0, 0, -16, 0 },
	Torso = { 4, 0, 0 },
	Head = { 2, 12, 0 },
	RArm = BALL_R.RArm,
	LArm = BALL_R.LArm,
	RLeg = { -16, 0, -3 },
	LLeg = { -24, 0, 3 },
}
-- 오른손을 앞으로 뻗어 겨눔(빔)
local AIM = W(FLOAT, {
	Root = { 0, 0.9, 0, 0, -30, 0 },
	Torso = { 0, -10, 0 },
	Head = { 0, 26, 0 },
	RArm = { 92, 30, 0 },
	LArm = { 60, -10, -30 },
})
-- 두 팔을 활짝(발산)
local OPEN = W(FLOAT, {
	Root = { 0, 1.1, 0, 0, -16, 0 },
	Torso = { 12, 0, 0 },
	Head = { 18, 12, 0 },
	RArm = { 110, -50, 60 },
	LArm = { 110, 50, -60 },
	RLeg = { -24, 0, -6 },
	LLeg = { -30, 0, 6 },
})

return {
	Stance = FLOAT,

	-- 대기: 천천히 오르내리며 품 안의 공을 굴리듯 두 손이 위아래를 바꾼다(포구 전환). 오브는 몸 둘레를 돈다
	Idle = {
		Duration = 4.16,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", FLOAT),
			K(1.04, "sineInOut", FLOAT, { Root = { 0, 1.0, 0, 0, -14, 0 }, Torso = { 6, 2, 0 }, RArm = BALL_MID.RArm, LArm = BALL_MID.LArm, RLeg = { -19, 0, -3 }, LLeg = { -21, 0, 3 } }),
			K(2.08, "sineInOut", FLOAT, { Root = { 0, 1.15, 0, 0, -12, 0 }, Torso = { 7, 3, 0 }, Head = { 6, 8, 0 }, RArm = BALL_L.RArm, LArm = BALL_L.LArm, RLeg = { -22, 0, -3 }, LLeg = { -18, 0, 3 } }),
			K(3.12, "sineInOut", FLOAT, { Root = { 0, 0.95, 0, 0, -18, 0 }, Torso = { 5, 1, 0 }, RArm = BALL_MID.RArm, LArm = BALL_MID.LArm }),
		},
	},

	-- 들림: 무중력 — 팔다리를 느슨히 펼치고 천천히 돈다. 오브가 머리 위로 모인다
	Held = {
		Duration = 3.0,
		Loop = true,
		Keys = {
			K(0, "sineInOut", FLOAT, { Root = { 0, 0.3, 0, 8, -16, 6 }, Torso = { 10, 0, 0 }, Head = { 16, 0, 0 }, RArm = { 50, -20, 70 }, LArm = { 50, 20, -70 }, RLeg = { -10, 0, 10 }, LLeg = { -30, 0, -10 } }),
			K(1.5, "sineInOut", FLOAT, { Root = { 0, 0.5, 0, -6, 20, -6 }, Torso = { 6, 0, 0 }, Head = { 10, 0, 0 }, RArm = { 60, -10, 80 }, LArm = { 40, 10, -60 }, RLeg = { -30, 0, 6 }, LLeg = { -12, 0, -6 } }),
		},
		Events = { { t = 0, k = "Orbs", mode = "Crown" } },
	},

	-- 내려놓임: 깃털처럼 내려앉아 발끝이 땅에 닿는 순간 고리가 퍼지고, 다시 떠오른다
	Drop = {
		Duration = 1.1,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, FLOAT, { Root = { 0, 0.6, 0, 0, -16, 0 } }),
			K(0.35, "sineOut", FLOAT, { Root = { 0, 0.05, 0, 0, -16, 0 }, Torso = { -6, 0, 0 }, Head = { -8, 12, 0 }, RArm = { 40, 0, 50 }, LArm = { 40, 0, -50 }, RLeg = { -4, 0, -3 }, LLeg = { -8, 0, 3 } }),
			K(0.7, "sineInOut", OPEN, { Root = { 0, 0.9, 0, 0, -16, 0 } }),
			K(1.1, "sineInOut", FLOAT),
		},
		Events = {
			{ t = 0.34, k = "Fx", n = "Touchdown" },
			{ t = 0.34, k = "Orbs", mode = "Spread" },
			{ t = 0.8, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 피격: 공중에서 뒤로 튕겨 반쯤 뒤집혔다가 되돌아 선다. 오브가 흩어진다
	Hit = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FLOAT),
			K(0.06, "expoOut", FLOAT, { Root = { 0, 1.1, 1.1, 34, -16, 0 }, Torso = { 16, 0, 0 }, Head = { 24, 0, 0 }, RArm = { 90, -20, 60 }, LArm = { 90, 20, -60 }, RLeg = { 20, 0, 6 }, LLeg = { 10, 0, -6 } }),
			K(0.3, "sineOut", FLOAT, { Root = { 0, 0.9, 1.2, 20, -16, 0 }, Torso = { 10, 0, 0 }, Head = { 12, 0, 0 }, RArm = { 60, -10, 50 }, LArm = { 60, 10, -50 }, RLeg = { 0, 0, 4 }, LLeg = { -6, 0, -4 } }),
			K(0.8, "sineInOut", FLOAT),
		},
		Events = {
			{ t = 0.02, k = "Orbs", mode = "Spread" },
			{ t = 0.55, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 방어: 두 손바닥을 앞으로 밀면 오브가 세모 방패를 친다
	Guard = {
		Duration = 0.8,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, FLOAT),
			K(0.08, "expoOut", FLOAT, { Root = { 0, 0.8, 0.3, 0, -8, 0 }, Torso = { 6, 0, 0 }, Head = { 6, 8, 0 }, RArm = { 88, 18, 0 }, LArm = { 88, -18, 0 } }),
			K(0.2, "sineOut", FLOAT, { Root = { 0, 0.78, 0.5, 0, -8, 0 }, Torso = { 10, 0, 0 }, Head = { 8, 8, 0 }, RArm = { 92, 16, 0 }, LArm = { 92, -16, 0 } }),
			K(0.8, "sineInOut", FLOAT),
		},
		Events = {
			{ t = 0, k = "Orbs", mode = "Shield" },
			{ t = 0.1, k = "Fx", n = "OrbShield" },
			{ t = 0.6, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 회피: 몸을 움츠렸다가 번쩍 — 옆으로 순간 이동하듯 미끄러지고, 빛 잔상이 남는다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, FLOAT),
			K(0.06, "quadOut", FLOAT, { Root = { 0, 0.6, 0, 0, -16, 0 }, Torso = { -10, 0, 0 }, RArm = { 10, 20, 10 }, LArm = { 10, -20, -10 }, RLeg = { -30, 0, 0 }, LLeg = { -34, 0, 0 } }),
			K(0.1, "expoOut", FLOAT, { Root = { -1.8, 1.0, 1.0, 0, -16, 0 }, Torso = { 6, 0, 0 }, RArm = { 40, 0, 50 }, LArm = { 40, 0, -50 } }),
			K(0.4, "sineOut", FLOAT, { Root = { -1.9, 1.0, 1.0, 0, -16, 0 } }),
			K(0.7, "sineInOut", FLOAT),
		},
		Events = { { t = 0.08, k = "Fx", n = "Blink" } },
	},

	Skills = {
		-- 자기권: 두 팔을 벌리며 떠오르면 오브가 넓게 빨리 돌고, 자기장 고리가 몸을 감싼다
		Magnetosphere = {
			Duration = 1.8,
			Keys = {
				K(0, nil, FLOAT),
				K(0.3, "cubicOut", FLOAT, { Root = { 0, 0.6, 0, 0, -16, 0 }, Torso = { -10, 0, 0 }, Head = { -12, 12, 0 }, RArm = { 40, 40, 0 }, LArm = { 40, -40, 0 }, RLeg = { -30, 0, 0 }, LLeg = { -34, 0, 0 } }),
				K(0.6, "backOut", OPEN, { Root = { 0, 1.4, 0, 0, 104, 0 } }),
				K(1.2, "sineOut", OPEN, { Root = { 0, 1.3, 0, 0, 344, 0 } }),
				K(1.8, "sineInOut", FLOAT, { Root = { 0, 0.8, 0, 0, 344, 0 } }),
			},
			Events = {
				{ t = 0.3, k = "Orbs", mode = "Gather" },
				{ t = 0.6, k = "Orbs", mode = "Spread" },
				{ t = 0.6, k = "Fx", n = "Magnetosphere" },
				{ t = 1.5, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 수렴: 오브 셋이 뻗은 손끝 앞으로 모여 돌며 기를 모으고 — 빔. 반동에 몸이 뒤로 밀린다
		Converge = {
			Duration = 1.4,
			Keys = {
				K(0, nil, FLOAT),
				K(0.2, "cubicOut", AIM),
				K(0.5, "sineInOut", AIM, { Root = { 0, 0.92, 0.05, 0, -30, 0 }, RArm = { 93, 30, 0 } }),
				K(0.56, "expoOut", AIM, { Root = { 0, 1.0, 0.6, 0, -30, 0 }, Torso = { 10, -10, 0 }, Head = { 8, 26, 0 }, RArm = { 104, 30, 0 } }),
				K(0.9, "sineOut", AIM, { Root = { 0, 0.96, 0.5, 0, -30, 0 }, Torso = { 6, -10, 0 }, RArm = { 98, 30, 0 } }),
				K(1.4, "sineInOut", FLOAT),
			},
			Events = {
				{ t = 0.1, k = "Orbs", mode = "Gather" },
				{ t = 0.25, k = "Fx", n = "Charge" },
				{ t = 0.56, k = "Fx", n = "ConvergeBeam" },
				{ t = 0.58, k = "Hit", i = 1, fx = "BeamHit" },
				{ t = 0.59, k = "Shake", a = 0.3, d = 0.3 },
				{ t = 1.0, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 섬광: 가슴 앞에 두 손을 모아 빛을 뭉치고 — 팔을 활짝 펴는 순간 눈부시게 터진다
		Flare = {
			Duration = 1.4,
			Keys = {
				K(0, nil, FLOAT),
				K(0.35, "cubicOut", FLOAT, { Root = { 0, 0.7, 0.1, 0, -16, 0 }, Torso = { -12, 0, 0 }, Head = { -16, 12, 0 }, RArm = { 60, 40, 0 }, LArm = { 60, -40, 0 }, RLeg = { -30, 0, 0 }, LLeg = { -34, 0, 0 } }),
				K(0.45, "expoOut", OPEN),
				K(0.9, "sineOut", OPEN, { Root = { 0, 1.0, 0, 0, -16, 0 } }),
				K(1.4, "sineInOut", FLOAT),
			},
			Events = {
				{ t = 0.05, k = "Orbs", mode = "Gather" },
				{ t = 0.3, k = "Fx", n = "FlareGather" },
				{ t = 0.45, k = "Orbs", mode = "Spread" },
				{ t = 0.46, k = "Hit", i = 1, fx = "Flare" },
				{ t = 1.0, k = "Orbs", mode = "Orbit" },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, FLOAT),
				K(0.18, "backOut", FLOAT, { Root = { 0, 0.8, 0.3, 0, -8, 0 }, Torso = { 6, 0, 0 }, RArm = { 88, 18, 0 }, LArm = { 88, -18, 0 } }),
				K(0.8, "sineInOut", FLOAT, { Root = { 0, 0.82, 0.3, 0, -8, 0 }, Torso = { 7, 0, 0 }, RArm = { 90, 18, 0 }, LArm = { 90, -18, 0 } }),
				K(1.1, "sineInOut", FLOAT),
			},
			Events = {
				{ t = 0, k = "Orbs", mode = "Shield" },
				{ t = 0.18, k = "Fx", n = "OrbShield" },
				{ t = 0.9, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 명상: 공중에서 책상다리로 앉아 두 손을 무릎에, 오브가 머리 위에서 돈다
		Meditate = {
			Duration = 2.2,
			Keys = {
				K(0, nil, FLOAT),
				K(0.45, "sineInOut", FLOAT, { Root = { 0, 0.3, 0, 0, -16, 0 }, Torso = { 0, 0, 0 }, Head = { -14, 0, 0 }, RArm = { 30, 0, 14 }, LArm = { 30, 0, -14 }, RLeg = { 84, 0, 30 }, LLeg = { 84, 0, -30 } }),
				K(1.7, "sineInOut", FLOAT, { Root = { 0, 0.45, 0, 0, -16, 0 }, Torso = { 2, 0, 0 }, Head = { -10, 0, 0 }, RArm = { 32, 0, 14 }, LArm = { 32, 0, -14 }, RLeg = { 84, 0, 30 }, LLeg = { 84, 0, -30 } }),
				K(2.2, "sineInOut", FLOAT),
			},
			Events = {
				{ t = 0.2, k = "Orbs", mode = "Crown" },
				{ t = 0.6, k = "Fx", n = "Meditate" },
				{ t = 1.9, k = "Orbs", mode = "Orbit" },
			},
		},
	},
}
