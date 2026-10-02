--!strict
--[[
	월 필그림 — 두 손에 순례자의 못을 쥔 광신도. (2026-09-28, 자세 다시 2026-10-02)

	성격: 구부정하고 음침함. 고개를 숙인 채 못 두 자루를 가슴 앞에 모아 쥐고 **중얼거리듯 몸을 흔든다**.
	      맞으면 아파하기보다 두 팔을 벌려 고통을 반긴다. 피할 때는 게처럼 낮게 뒤로 기어 물러난다.
	      공격은 찍기 — 못을 거꾸로 쥐고 머리 위에서 내리꽂는다.
	참고: 역수(얼음송곳) 쥠 — 못 머리는 주먹 위(엄지 쪽), 끝은 새끼손가락 쪽으로 나온다. 찍기는 위에서 아래로 내리꽂고,
	      막을 때는 두 자루를 엇걸어 X 를 만든다. 합창에서만 손안에서 뒤집어 바로 쥐고 하늘을 찌른다.
	무기 종류: Spike (WeaponDefinitions.PilgrimNails: W = 오른손 못, O = 왼손 못, 못 머리 y -0.38).
	      팔·못 각도는 tools/combat/design/pilgrim_gen.py 로 구함(주먹 자리 → reach, 못 방향 → aim_axis).
	      못 방향(옆에서 본 각) = 팔 X + 90 + 숙임. 숙임 ≈ -180 이 역수 쥠, ≈ -75 가 팔 끝으로 뻗은 바로 쥠.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 기도(대기): 구부정하게 두 주먹을 가슴 앞에 모으고, 못끝은 앞 아래로
local PRAY = { Root = { 0, -0.3, 0, 0, -14, 0 }, Torso = { -24, 0, 0 }, Head = { -8, 10, 0 }, RArm = { 98.6, 41.9, -11.9 }, LArm = { 98.6, -41.9, 11.9 }, RLeg = { 16, 0, 8 }, LLeg = { -4, 0, -8 }, W = { 0, 0, 0, -142.3, 0, -51.4 }, O = { 0, 0, 0, -142.3, 0, 51.4 } }
-- 치켜듦(내리꽂기 직전): 두 주먹을 머리 위 앞으로, 못끝은 적을 향함
local RAISE = { Root = { 0, 0.1, 0.2, 0, -12, 0 }, Torso = { 14, 0, 0 }, Head = { 18, 6, 0 }, RArm = { 150.1, 34.9, -28.1 }, LArm = { 150.1, -34.9, 28.1 }, RLeg = { 4, 0, 6 }, LLeg = { -12, 0, -6 }, W = { 0, 0, 0, -168, 0, -49.7 }, O = { 0, 0, 0, -168, 0, 49.7 } }
-- 내리꽂은 끝: 깊이 숙여 주먹이 앞 아래, 못끝은 앞 아래로 박힘
local STAB = { Root = { 0, -0.8, -0.5, 0, -12, 0 }, Torso = { -40, 0, 0 }, Head = { 16, 6, 0 }, RArm = { 110, 39.9, -6.6 }, LArm = { 110, -39.9, 6.6 }, RLeg = { 44, 0, 8 }, LLeg = { -30, 0, -8 }, W = { 0, 0, 0, -135.2, 0, -42.7 }, O = { 0, 0, 0, -135.2, 0, 42.7 } }
-- 황홀(들림·피격): 두 팔을 벌려 하늘을 우러름, 못끝은 팔 바깥 아래로 늘어짐
local EXALT = { Root = { 0, -0.1, 0.2, 0, -14, 0 }, Torso = { 16, 0, 0 }, Head = { 30, 8, 0 }, RArm = { 120, -50, 50 }, LArm = { 120, 50, -50 }, RLeg = { 4, 0, 6 }, LLeg = { -10, 0, -6 }, W = { 0, 0, 0, -141.1, 0, -16.1 }, O = { 0, 0, 0, -141.1, 0, 16.1 } }
-- 십자 막기: 두 주먹을 얼굴 앞에 모으고 못끝이 아래로 엇갈려 X
local CROSS = { Root = { 0, -0.45, 0.3, 0, -14, 0 }, Torso = { -12, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 115, 42.4, -9.8 }, LArm = { 115, -42.4, 9.8 }, RLeg = { 16, 0, 8 }, LLeg = { -4, 0, -8 }, W = { 0, 0, 0, -166.9, 0, 10.7 }, O = { 0, 0, 0, -166.9, 0, -10.7 } }
-- X 긋기: 두 못을 머리 위로 엇갈려 듦(XUP) → 팔이 엇갈려 아래로 그음(XDOWN) → 두 팔을 옆으로 갈라 벌림(SPLIT)
local XUP = { Root = { 0, -0.5, 0.2, 0, -14, 0 }, Torso = { -16, 0, 0 }, Head = { 6, 10, 0 }, RArm = { 150, 50, 0 }, LArm = { 150, -50, 0 }, RLeg = { 16, 0, 8 }, LLeg = { -4, 0, -8 }, W = { 0, 0, 0, -124.2, 0, -64.4 }, O = { 0, 0, 0, -124.2, 0, 64.4 } }
local XDOWN = { Root = { 0, -0.7, -0.4, 0, -14, 0 }, Torso = { -34, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 70, -40, 20 }, LArm = { 70, 40, -20 }, RLeg = { 34, 0, 8 }, LLeg = { -26, 0, -8 }, W = { 0, 0, 0, -79.7, 0, 42.6 }, O = { 0, 0, 0, -79.7, 0, -42.6 } }
local SPLIT = { Root = { 0, -0.7, -0.5, 0, -14, 0 }, Torso = { -26, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 90, -60, 80 }, LArm = { 90, 60, -80 }, RLeg = { 34, 0, 8 }, LLeg = { -26, 0, -8 }, W = { 0, 0, 0, -239.5, 0, 58.1 }, O = { 0, 0, 0, -239.5, 0, -58.1 } }
-- 합창: 손안에서 못을 뒤로 한 바퀴 가까이 돌려(-171 → -435.5, 오일러로 돎) 바로 쥐고 하늘을 찌른다 / 내리 가리킴(같은 감김)
local SKY = { Root = { 0, 0.1, 0.2, 0, -14, 0 }, Torso = { 16, 0, 0 }, Head = { 38, 8, 0 }, RArm = { 172, 8, 12 }, LArm = { 172, -8, -12 }, RLeg = { 4, 0, 6 }, LLeg = { -10, 0, -6 }, W = { 0, 0, 0, -435.5, 0, 6.8 }, O = { 0, 0, 0, -435.5, 0, -6.8 } }
local POINT = { Root = { 0, -0.5, -0.2, 0, -14, 0 }, Torso = { -30, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 96, 20, 0 }, LArm = { 96, -20, 0 }, RLeg = { 16, 0, 8 }, LLeg = { -4, 0, -8 }, W = { 0, 0, 0, -468.2, 0, -22.4 }, O = { 0, 0, 0, -468.2, 0, 22.4 } }
-- 명상: 무릎 꿇고 두 주먹을 이마에 — 못 머리가 이마에 닿고 못끝은 아래
local KNEEL = { Root = { 0, -1.05, 0.2, 0, -14, 0 }, Torso = { -30, 0, 0 }, Head = { -30, 0, 0 }, RArm = { 102.2, 43.1, -7.1 }, LArm = { 102.2, -43.1, 7.1 }, RLeg = { 86, 0, 6 }, LLeg = { -46, 0, -6 }, W = { 0, 0, 0, -126.3, 0, -50.1 }, O = { 0, 0, 0, -126.3, 0, 50.1 } }
-- 착지: 무릎 꿇으며 두 못을 앞 땅에 꽂음
local PLANT = { Root = { 0, -1.1, -0.2, 0, -12, 0 }, Torso = { -30, 0, 0 }, Head = { -6, 6, 0 }, RArm = { 111.8, 40.1, -7.6 }, LArm = { 111.8, -40.1, 7.6 }, RLeg = { 80, 0, 6 }, LLeg = { -50, 0, -6 }, W = { 0, 0, 0, -154.7, 0, -37.1 }, O = { 0, 0, 0, -154.7, 0, 37.1 } }
-- 게걸음 회피: 낮게 웅크려 두 주먹을 앞 아래로
local CRAB = { Root = { 0.4, -0.9, 0.8, 0, -30, 0 }, Torso = { -40, 0, 0 }, Head = { 20, 20, 0 }, RArm = { 40, 30, 30 }, LArm = { 40, -30, -30 }, RLeg = { 30, 0, 20 }, LLeg = { -20, 0, -20 }, W = { 0, 0, 0, -9.1, 0, -34.1 }, O = { 0, 0, 0, -9.1, 0, 34.1 } }

return {
	Stance = PRAY,

	-- 대기: 중얼거리는 기도 — 앞뒤로 몸을 흔들고 고개를 까딱이다가, 가끔 눈을 치켜떠 적을 본다
	Idle = {
		Duration = 3.64,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", PRAY),
			K(0.65, "sineInOut", PRAY, { Torso = { -30, 0, 0 }, Head = { -18, 10, 0 }, Root = { 0, -0.36, 0, 0, -14, 0 } }),
			K(1.3, "sineInOut", PRAY),
			K(1.95, "sineInOut", PRAY, { Torso = { -30, 0, 0 }, Head = { -18, 10, 0 }, Root = { 0, -0.36, 0, 0, -14, 0 } }),
			K(2.6, "cubicOut", PRAY, { Torso = { -20, 0, 0 }, Head = { 14, 22, 0 } }),
			K(3.12, "sineInOut", PRAY, { Torso = { -21, 0, 0 }, Head = { 12, 22, 0 } }),
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

	-- 내려놓임: 무릎 꿇듯 내려앉아 두 못을 앞 땅에 꽂고(불꽃), 천천히 일어나 다시 기도
	Drop = {
		Duration = 1.2,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, EXALT, { Root = { 0, 0.3, 0, 0, -14, 0 } }),
			K(0.1, "quadIn", PLANT),
			K(0.6, "sineOut", PLANT, { Root = { 0, -1.05, -0.2, 0, -12, 0 }, Torso = { -34, 0, 0 }, Head = { -10, 6, 0 } }),
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
			K(0.08, "expoOut", CROSS),
			K(0.2, "sineOut", CROSS, { Root = { 0, -0.5, 0.45, 0, -14, 0 }, Torso = { -14, 0, 0 }, Head = { -8, 10, 0 } }),
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
			K(0.08, "expoOut", CRAB),
			K(0.18, "expoOut", CRAB, { Root = { 0.8, -0.8, 1.5, 0, -30, 0 }, RLeg = { -10, 0, 20 }, LLeg = { 20, 0, -20 } }),
			K(0.4, "sineOut", CRAB, { Root = { 0.8, -0.8, 1.5, 0, -30, 0 }, Torso = { -38, 0, 0 }, RLeg = { 10, 0, 20 }, LLeg = { -10, 0, -20 } }),
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
				K(0.2, "cubicOut", XUP),
				K(0.3, "expoOut", XDOWN),
				-- 갈라 벌리기: 팔을 옆으로 모았다가 크게 젖힌다
				K(0.55, "cubicOut", SPLIT, { Root = { 0, -0.6, -0.4, 0, -14, 0 }, Torso = { -20, 0, 0 }, RArm = { 90, 20, 60 }, LArm = { 90, -20, -60 }, RLeg = { 30, 0, 8 }, LLeg = { -24, 0, -8 } }),
				K(0.62, "expoOut", SPLIT),
				K(0.95, "sineOut", SPLIT, { Root = { 0, -0.66, -0.5, 0, -14, 0 }, Torso = { -24, 0, 0 }, RArm = { 88, -62, 80 }, LArm = { 88, 62, -80 }, RLeg = { 32, 0, 8 }, LLeg = { -24, 0, -8 } }),
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

		-- 합창: 팔을 들며 못을 손안에서 돌려 바로 쥐고 하늘로 치켜든 채 노래하듯 고개를 젖히면 — 내리 가리키는 줄 위로 못 비가 쏟아진다.
		-- 끝에서 같은 방향으로 마저 돌려 역수 쥠으로 돌아온다
		Chorale = {
			Duration = 2.2,
			Keys = {
				K(0, nil, PRAY),
				K(0.4, "cubicOut", EXALT, { RArm = { 170, 10, 10 }, LArm = { 170, -10, -10 } }),
				K(0.62, "quadOut", SKY, { Head = { 30, 8, 0 } }),
				K(1.0, "sineInOut", SKY),
				K(1.15, "expoOut", POINT),
				K(1.8, "sineOut", POINT, { Root = { 0, -0.46, -0.2, 0, -14, 0 }, Torso = { -28, 0, 0 }, Head = { 12, 10, 0 }, RArm = { 94, 20, 0 }, LArm = { 94, -20, 0 } }),
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
				K(0.16, "backOut", CROSS),
				K(0.8, "sineInOut", CROSS, { Root = { 0, -0.47, 0.3, 0, -14, 0 }, Torso = { -13, 0, 0 } }),
				K(1.1, "sineInOut", PRAY),
			},
			Events = { { t = 0.16, k = "Fx", n = "CrossBlock" } },
		},

		-- 명상: 무릎을 꿇고 두 주먹을 이마에 댄다(못 머리가 이마에)
		Meditate = {
			Duration = 2.2,
			Keys = {
				K(0, nil, PRAY),
				K(0.45, "cubicInOut", KNEEL),
				K(1.7, "sineInOut", KNEEL, { Torso = { -34, 0, 0 }, Head = { -34, 0, 0 } }),
				K(2.2, "sineInOut", PRAY),
			},
			Events = { { t = 0.6, k = "Fx", n = "Meditate" } },
		},
	},
}
