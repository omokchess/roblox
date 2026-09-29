--!strict
--[[
	월 필그림 — 두 손에 순례자의 못을 쥔 광신도. (2026-09-28)

	성격: 구부정하고 음침함. 고개를 숙인 채 못 두 자루를 가슴 앞에 모아 쥐고 **중얼거리듯 몸을 흔든다**.
	      맞으면 아파하기보다 두 팔을 벌려 고통을 반긴다. 피할 때는 게처럼 낮게 뒤로 기어 물러난다.
	      공격은 찍기 — 못을 거꾸로 쥐고 머리 위에서 내리꽂는다.
	무기 종류: Spike (WeaponDefinitions.PilgrimNails: W = 오른손 못, O = 왼손 못)
	  못 방향(옆에서 본 각) = 팔 X + 90 + 숙임. 기도(위로 세움) ≈ 180, 거꾸로 쥐고 찍기 ≈ 0~30
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 구부정한 기도 자세: 못 두 자루를 가슴 앞에 모아 세운다
local PRAY = {
	Root = { 0, -0.3, 0, 0, -14, 0 },
	Torso = { -24, 0, 0 },
	Head = { -8, 10, 0 },
	RArm = { 76, 30, 0 },
	LArm = { 76, -30, 0 },
	RLeg = { 16, 0, 8 },
	LLeg = { -4, 0, -8 },
	W = { 0, 0, 0, 14, 0, -8 },
	O = { 0, 0, 0, 14, 0, 8 },
}
-- 두 못을 머리 위로 거꾸로 치켜든 자세(내리꽂기 직전)
local RAISE = W(PRAY, {
	Root = { 0, 0.1, 0.2, 0, -12, 0 },
	Torso = { 14, 0, 0 },
	Head = { 18, 6, 0 },
	RArm = { 172, 16, 0 },
	LArm = { 172, -16, 0 },
	W = { 0, 0, 0, 98, 0, 0 },
	O = { 0, 0, 0, 98, 0, 0 },
	RLeg = { 4, 0, 6 },
	LLeg = { -12, 0, -6 },
})
-- 내리꽂은 끝(못끝이 앞 아래를 찌름)
local STAB = W(PRAY, {
	Root = { 0, -0.8, -0.5, 0, -12, 0 },
	Torso = { -40, 0, 0 },
	Head = { 16, 6, 0 },
	RArm = { 110, 14, 0 },
	LArm = { 110, -14, 0 },
	-- 손목을 앞으로 꺾어 못끝이 앞 아래를 찌른다(98 → 230: 앞으로 132° 돌림)
	W = { 0, 0, 0, 230, 0, 0 },
	O = { 0, 0, 0, 230, 0, 0 },
	RLeg = { 44, 0, 8 },
	LLeg = { -30, 0, -8 },
})
-- 두 팔을 벌리고 하늘을 우러름
local EXALT = W(PRAY, {
	Root = { 0, -0.1, 0.2, 0, -14, 0 },
	Torso = { 16, 0, 0 },
	Head = { 30, 8, 0 },
	RArm = { 120, -50, 50 },
	LArm = { 120, 50, -50 },
	W = { 0, 0, 0, -40, 0, 0 },
	O = { 0, 0, 0, -40, 0, 0 },
	RLeg = { 4, 0, 6 },
	LLeg = { -10, 0, -6 },
})

return {
	Stance = PRAY,

	-- 대기: 중얼거리는 기도 — 앞뒤로 몸을 흔들고 고개를 까딱이다가, 가끔 눈을 치켜떠 적을 본다
	Idle = {
		Duration = 2.8,
		Loop = true,
		Keys = {
			K(0, "sineInOut", PRAY),
			K(0.5, "sineInOut", PRAY, { Torso = { -30, 0, 0 }, Head = { -18, 10, 0 }, Root = { 0, -0.36, 0, 0, -14, 0 } }),
			K(1.0, "sineInOut", PRAY),
			K(1.5, "sineInOut", PRAY, { Torso = { -30, 0, 0 }, Head = { -18, 10, 0 }, Root = { 0, -0.36, 0, 0, -14, 0 } }),
			K(2.0, "cubicOut", PRAY, { Torso = { -20, 0, 0 }, Head = { 14, 22, 0 } }),
			K(2.4, "sineInOut", PRAY, { Torso = { -21, 0, 0 }, Head = { 12, 22, 0 } }),
		},
	},

	-- 들림: 황홀경 — 두 팔을 벌리고 하늘을 우러러 발을 모은 채 늘어진다
	Held = {
		Duration = 2.6,
		Loop = true,
		Keys = {
			K(0, "sineInOut", EXALT, { Root = { 0, 0, 0, 4, -14, 0 }, RLeg = { -4, 0, 2 }, LLeg = { -6, 0, -2 } }),
			K(1.3, "sineInOut", EXALT, { Root = { 0, 0.1, 0, -4, -14, 0 }, Head = { 36, 4, 0 }, RArm = { 126, -46, 54 }, LArm = { 126, 46, -54 }, RLeg = { -6, 0, 2 }, LLeg = { -4, 0, -2 } }),
		},
	},

	-- 내려놓임: 무릎 꿇듯 내려앉아 두 못을 땅에 꽂고(불꽃), 천천히 일어나 다시 기도
	Drop = {
		Duration = 1.2,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, EXALT, { Root = { 0, 0.3, 0, 0, -14, 0 } }),
			K(0.1, "quadIn", STAB, { Root = { 0, -1.1, -0.2, 0, -12, 0 }, Torso = { -30, 0, 0 }, RArm = { 90, 14, 0 }, LArm = { 90, -14, 0 }, RLeg = { 80, 0, 6 }, LLeg = { -50, 0, -6 } }),
			K(0.6, "sineOut", STAB, { Root = { 0, -1.05, -0.2, 0, -12, 0 }, Torso = { -34, 0, 0 }, Head = { -10, 6, 0 }, RArm = { 90, 14, 0 }, LArm = { 90, -14, 0 }, RLeg = { 80, 0, 6 }, LLeg = { -50, 0, -6 } }),
			K(1.2, "sineInOut", PRAY),
		},
		Events = { { t = 0.1, k = "Fx", n = "Genuflect" } },
	},

	-- 피격: 움찔하더니 두 팔을 벌려 고통을 반긴다(고개를 젖힘)
	Hit = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, PRAY),
			K(0.05, "expoOut", PRAY, { Root = { 0, -0.2, 0.6, 0, -14, 0 }, Torso = { -6, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 60, 20, 20 }, LArm = { 60, -20, -20 } }),
			K(0.3, "cubicOut", EXALT),
			K(0.5, "sineOut", EXALT, { Head = { 34, 8, 0 } }),
			K(0.8, "sineInOut", PRAY),
		},
		Events = { { t = 0.3, k = "Fx", n = "Rapture" } },
	},

	-- 방어: 두 못을 X 자로 엇걸어 얼굴 앞을 막는다
	Guard = {
		Duration = 0.7,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, PRAY),
			K(0.08, "expoOut", PRAY, { Root = { 0, -0.45, 0.3, 0, -14, 0 }, Torso = { -12, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 110, 36, 0 }, LArm = { 110, -36, 0 }, W = { 0, 0, 0, -30, 0, -40 }, O = { 0, 0, 0, -30, 0, 40 } }),
			K(0.2, "sineOut", PRAY, { Root = { 0, -0.5, 0.45, 0, -14, 0 }, Torso = { -14, 0, 0 }, Head = { -8, 10, 0 }, RArm = { 112, 36, 0 }, LArm = { 112, -36, 0 }, W = { 0, 0, 0, -30, 0, -40 }, O = { 0, 0, 0, -30, 0, 40 } }),
			K(0.7, "sineInOut", PRAY),
		},
		Events = { { t = 0.08, k = "Fx", n = "CrossBlock" } },
	},

	-- 회피: 게처럼 낮게 웅크려 뒤로 두 번 종종걸음(재빠르고 기분 나쁘게)
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, PRAY),
			K(0.08, "expoOut", PRAY, { Root = { 0.4, -0.9, 0.8, 0, -30, 0 }, Torso = { -40, 0, 0 }, Head = { 20, 20, 0 }, RArm = { 40, 30, 30 }, LArm = { 40, -30, -30 }, RLeg = { 30, 0, 20 }, LLeg = { -20, 0, -20 } }),
			K(0.18, "expoOut", PRAY, { Root = { 0.8, -0.8, 1.5, 0, -30, 0 }, Torso = { -40, 0, 0 }, Head = { 20, 20, 0 }, RArm = { 40, 30, 30 }, LArm = { 40, -30, -30 }, RLeg = { -10, 0, 20 }, LLeg = { 20, 0, -20 } }),
			K(0.4, "sineOut", PRAY, { Root = { 0.8, -0.8, 1.5, 0, -30, 0 }, Torso = { -38, 0, 0 }, Head = { 20, 20, 0 }, RArm = { 40, 30, 30 }, LArm = { 40, -30, -30 }, RLeg = { 10, 0, 20 }, LLeg = { -10, 0, -20 } }),
			K(0.7, "sineInOut", PRAY),
		},
		Events = { { t = 0.08, k = "Fx", n = "Scuttle" } },
	},

	Skills = {
		-- 못질: 달려들어 두 못을 머리 위로 거꾸로 치켜들고 — 내리꽂는다
		Nailing = {
			Duration = 1.4,
			Keys = {
				K(0, nil, PRAY),
				K(0.25, "cubicOut", RAISE),
				K(0.36, "sineIn", RAISE, { Root = { 0, 0.4, 0.3, 0, -12, 0 }, Torso = { 18, 0, 0 } }),
				K(0.42, "expoOut", STAB),
				K(0.8, "linear", STAB, { Root = { 0, -0.76, -0.5, 0, -12, 0 } }),
				K(1.05, "cubicInOut", PRAY, { Root = { 0, -0.3, 0.3, 0, -14, 0 } }),
				K(1.4, "sineInOut", PRAY),
			},
			Events = {
				{ t = 0.1, k = "Dash", to = "Target", gap = 3, d = 0.22 },
				{ t = 0.3, k = "Trail", on = true },
				{ t = 0.42, k = "Hit", i = 1, fx = "NailDown" },
				{ t = 0.43, k = "Stop", d = 0.1 },
				{ t = 0.44, k = "Shake", a = 0.4, d = 0.3 },
				{ t = 0.6, k = "Trail", on = false },
				{ t = 0.9, k = "Dash", to = "Home", d = 0.3 },
			},
		},

		-- 갈라진 신도: 두 못을 엇갈려 X 로 긋고, 몸을 틀며 양옆으로 갈라 벤다(두 칸)
		SplitFlock = {
			Duration = 1.4,
			Keys = {
				K(0, nil, PRAY),
				K(0.2, "cubicOut", PRAY, { Root = { 0, -0.5, 0.2, 0, -14, 0 }, Torso = { -16, 0, 0 }, RArm = { 150, 50, 0 }, LArm = { 150, -50, 0 }, W = { 0, 0, 0, -60, 0, 0 }, O = { 0, 0, 0, -60, 0, 0 } }),
				-- X 긋기
				K(0.3, "expoOut", PRAY, { Root = { 0, -0.7, -0.4, 0, -14, 0 }, Torso = { -34, 0, 0 }, RArm = { 70, -40, 20 }, LArm = { 70, 40, -20 }, W = { 0, 0, 0, -70, 0, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RLeg = { 34, 0, 8 }, LLeg = { -26, 0, -8 } }),
				-- 갈라 벌리기
				K(0.55, "cubicOut", PRAY, { Root = { 0, -0.6, -0.4, 0, -14, 0 }, Torso = { -20, 0, 0 }, RArm = { 90, 20, 60 }, LArm = { 90, -20, -60 }, W = { 0, 0, 0, -80, 0, 0 }, O = { 0, 0, 0, -80, 0, 0 }, RLeg = { 30, 0, 8 }, LLeg = { -24, 0, -8 } }),
				K(0.62, "expoOut", PRAY, { Root = { 0, -0.7, -0.5, 0, -14, 0 }, Torso = { -26, 0, 0 }, RArm = { 90, -60, 80 }, LArm = { 90, 60, -80 }, W = { 0, 0, 0, -84, 0, 0 }, O = { 0, 0, 0, -84, 0, 0 }, RLeg = { 34, 0, 8 }, LLeg = { -26, 0, -8 } }),
				K(0.95, "sineOut", PRAY, { Root = { 0, -0.66, -0.5, 0, -14, 0 }, Torso = { -24, 0, 0 }, RArm = { 88, -62, 80 }, LArm = { 88, 62, -80 }, W = { 0, 0, 0, -84, 0, 0 }, O = { 0, 0, 0, -84, 0, 0 }, RLeg = { 32, 0, 8 }, LLeg = { -24, 0, -8 } }),
				K(1.4, "sineInOut", PRAY),
			},
			Events = {
				{ t = 0.05, k = "Dash", to = "Target", gap = 3, d = 0.2 },
				{ t = 0.22, k = "Trail", on = true },
				{ t = 0.3, k = "Hit", i = 1, fx = "CrossSlash" },
				{ t = 0.31, k = "Stop", d = 0.06 },
				{ t = 0.62, k = "Fx", n = "Split" },
				{ t = 0.63, k = "Shake", a = 0.3, d = 0.25 },
				{ t = 0.8, k = "Trail", on = false },
				{ t = 1.0, k = "Dash", to = "Home", d = 0.28 },
			},
		},

		-- 합창: 두 못을 하늘로 치켜들고 노래하듯 고개를 젖히면, 그 줄 위로 못 비가 쏟아진다
		Chorale = {
			Duration = 2.2,
			Keys = {
				K(0, nil, PRAY),
				K(0.4, "cubicOut", EXALT, { RArm = { 170, 10, 10 }, LArm = { 170, -10, -10 }, W = { 0, 0, 0, -80, 0, 0 }, O = { 0, 0, 0, -80, 0, 0 } }),
				K(1.0, "sineInOut", EXALT, { Root = { 0, 0.1, 0.2, 0, -14, 0 }, Head = { 38, 8, 0 }, RArm = { 172, 8, 12 }, LArm = { 172, -8, -12 }, W = { 0, 0, 0, -80, 0, 0 }, O = { 0, 0, 0, -80, 0, 0 } }),
				-- 내리 가리킴
				K(1.15, "expoOut", PRAY, { Root = { 0, -0.5, -0.2, 0, -14, 0 }, Torso = { -30, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 96, 20, 0 }, LArm = { 96, -20, 0 }, W = { 0, 0, 0, -96, 0, 0 }, O = { 0, 0, 0, -96, 0, 0 } }),
				K(1.8, "sineOut", PRAY, { Root = { 0, -0.46, -0.2, 0, -14, 0 }, Torso = { -28, 0, 0 }, Head = { 12, 10, 0 }, RArm = { 94, 20, 0 }, LArm = { 94, -20, 0 }, W = { 0, 0, 0, -96, 0, 0 }, O = { 0, 0, 0, -96, 0, 0 } }),
				K(2.2, "sineInOut", PRAY),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "Halo" },
				{ t = 1.15, k = "Fx", n = "NailRain" },
				{ t = 1.45, k = "Hit", i = 1, fx = "NailRainHit" },
				{ t = 1.46, k = "Shake", a = 0.35, d = 0.4 },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, PRAY),
				K(0.16, "backOut", PRAY, { Root = { 0, -0.45, 0.3, 0, -14, 0 }, Torso = { -12, 0, 0 }, RArm = { 110, 36, 0 }, LArm = { 110, -36, 0 }, W = { 0, 0, 0, -30, 0, -40 }, O = { 0, 0, 0, -30, 0, 40 } }),
				K(0.8, "sineInOut", PRAY, { Root = { 0, -0.47, 0.3, 0, -14, 0 }, Torso = { -13, 0, 0 }, RArm = { 110, 36, 0 }, LArm = { 110, -36, 0 }, W = { 0, 0, 0, -30, 0, -40 }, O = { 0, 0, 0, -30, 0, 40 } }),
				K(1.1, "sineInOut", PRAY),
			},
			Events = { { t = 0.16, k = "Fx", n = "CrossBlock" } },
		},

		-- 명상: 무릎을 꿇고 이마를 못 끝에 댄다
		Meditate = {
			Duration = 2.2,
			Keys = {
				K(0, nil, PRAY),
				K(0.45, "cubicInOut", PRAY, { Root = { 0, -1.05, 0.2, 0, -14, 0 }, Torso = { -30, 0, 0 }, Head = { -30, 0, 0 }, RArm = { 60, 26, 0 }, LArm = { 60, -26, 0 }, RLeg = { 86, 0, 6 }, LLeg = { -46, 0, -6 } }),
				K(1.7, "sineInOut", PRAY, { Root = { 0, -1.05, 0.2, 0, -14, 0 }, Torso = { -34, 0, 0 }, Head = { -34, 0, 0 }, RArm = { 58, 26, 0 }, LArm = { 58, -26, 0 }, RLeg = { 86, 0, 6 }, LLeg = { -46, 0, -6 } }),
				K(2.2, "sineInOut", PRAY),
			},
			Events = { { t = 0.6, k = "Fx", n = "Meditate" } },
		},
	},
}
