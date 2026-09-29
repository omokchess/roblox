--!strict
--[[
	월 브레이커 — 곡괭이 모양 지팡이를 휘두르는 파괴자. (2026-09-28)

	성격: 거칠고 들뜸. 낮게 웅크려 몸을 들썩이고, 지팡이를 빙글 돌린다. 휘두름이 크고 **다 걸어 버린다**.
	      맞으면 약이 올라 더 들뜨고, 피할 때는 지팡이를 짚고 장대높이뛰기하듯 넘어간다.
	무기 종류: Polearm2H (WeaponDefinitions.PickStaff). 두 손을 가슴 앞 한 점으로 모아 자루 가운데를 쥔다
	  (W 자리 y -1.2 = 자루를 손 쪽으로 당겨 가운데를 쥠). 지팡이 방향 = 팔 X + 90 + 숙임. 곡괭이 날 = 앞(-Z)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 낮게 웅크려 지팡이를 비스듬히(머리가 오른 어깨 뒤 위로) 든 자세
local WILD = {
	Root = { 0, -0.5, 0, 0, -18, 0 },
	Torso = { -14, 0, 0 },
	Head = { 10, 16, 0 },
	RArm = { 58, 26, 8 },
	LArm = { 58, -26, 0 },
	RLeg = { 26, 0, 16 },
	LLeg = { -22, 0, -16 },
	W = { 0.5, -0.6, 0, 88, 0, 0 },
}
-- 두 손으로 머리 위로 치켜듦(곡괭이가 등 뒤로)
local HIGH = W(WILD, {
	Root = { 0, -0.1, 0.3, 0, -14, 0 },
	Torso = { 16, 0, 0 },
	Head = { 16, 10, 0 },
	RArm = { 176, 22, 0 },
	LArm = { 176, -22, 0 },
	W = { 0, -0.6, 0, -20, 0, 0 },
	RLeg = { 10, 0, 14 },
	LLeg = { -20, 0, -14 },
})
-- 곡괭이를 내리찍은 끝(날이 앞 땅에 박힘)
local PICK = W(WILD, {
	Root = { 0, -0.95, -0.6, 0, -12, 0 },
	Torso = { -40, 0, 0 },
	Head = { 24, 8, 0 },
	RArm = { 84, 22, 0 },
	LArm = { 84, -22, 0 },
	-- 끝이 바닥에 닿게(옆에서 본 각 ≈ 60°): 더 세우면 곡괭이가 땅속에 묻힌다
	W = { 0, -0.6, 0, -74, 0, 0 },
	RLeg = { 44, 0, 14 },
	LLeg = { -36, 0, -14 },
})

return {
	Stance = WILD,

	-- 대기: 들썩들썩 좌우로 무게를 옮기고 어깨를 돌리다가, 지팡이를 한 바퀴 빙글 돌려 다시 잡는다
	Idle = {
		Duration = 3.64,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", WILD),
			K(0.52, "sineInOut", WILD, { Root = { 0.15, -0.58, 0, 0, -22, 0 }, Torso = { -18, 4, 0 }, Head = { 6, 20, -6 } }),
			K(1.04, "sineInOut", WILD, { Root = { -0.15, -0.46, 0, 0, -14, 0 }, Torso = { -12, -4, 0 }, Head = { 12, 12, 6 } }),
			K(1.56, "sineInOut", WILD, { Root = { 0.1, -0.56, 0, 0, -20, 0 } }),
			-- 빙글
			K(1.95, "quadIn", WILD, { RArm = { 80, 24, 8 }, LArm = { 80, -24, 0 }, W = { 0.5, -0.6, 0, 88 + 180, 0, 0 }, Torso = { -10, 0, 0 } }),
			K(2.34, "quadOut", WILD, { RArm = { 70, 24, 8 }, LArm = { 70, -24, 0 }, W = { 0.5, -0.6, 0, 88 + 360, 0, 0 }, Torso = { -12, 0, 0 } }),
			K(2.86, "sineInOut", WILD, { W = { 0.5, -0.6, 0, 88 + 360, 0, 0 } }),
		},
	},

	-- 들림: 지팡이를 철봉처럼 머리 위로 가로 쥐고 매달려 다리를 흔든다
	Held = {
		Duration = 1.4,
		Loop = true,
		Keys = {
			K(0, "sineInOut", WILD, { Root = { 0, -0.2, 0, 6, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 20, 14, 0 }, RArm = { 176, 0, 18 }, LArm = { 176, 0, -18 }, W = { 0, -1.8, 0, -86, 0, 90 }, RLeg = { 30, 0, 4 }, LLeg = { 16, 0, -4 } }),
			K(0.7, "sineInOut", WILD, { Root = { 0, -0.2, 0, -6, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 16, 14, 0 }, RArm = { 176, 0, 18 }, LArm = { 176, 0, -18 }, W = { 0, -1.8, 0, -86, 0, 90 }, RLeg = { -24, 0, 4 }, LLeg = { -34, 0, -4 } }),
		},
	},

	-- 내려놓임: 지팡이 밑동을 땅에 쾅 박으며 착지(금), 씩 웃듯 고개를 까딱
	Drop = {
		Duration = 1.0,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, WILD, { Root = { 0, 0.4, 0, 0, -18, 0 }, RArm = { 90, 24, 0 }, LArm = { 90, -24, 0 }, W = { 0, -1.2, 0, 6, 0, 0 }, Torso = { 0, 0, 0 } }),
			K(0.08, "quadIn", WILD, { Root = { 0, -0.8, 0, 0, -18, 0 }, Torso = { -20, 0, 0 }, RArm = { 70, 24, 0 }, LArm = { 70, -24, 0 }, W = { 0, -1.6, 0, 20, 0, 0 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
			K(0.45, "sineOut", WILD, { Root = { 0, -0.7, 0, 0, -18, 0 }, Torso = { -16, 0, 0 }, Head = { 20, 30, -10 }, RArm = { 70, 24, 0 }, LArm = { 70, -24, 0 }, W = { 0, -1.6, 0, 20, 0, 0 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
			K(1.0, "sineInOut", WILD),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "ButtSlam" },
			{ t = 0.09, k = "Shake", a = 0.25, d = 0.2 },
		},
	},

	-- 피격: 휙 젖혀졌다가 고개를 털고 더 들뜬다(약이 오름)
	Hit = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, WILD),
			K(0.05, "expoOut", WILD, { Root = { 0, -0.3, 0.8, 0, -26, 0 }, Torso = { 14, -8, 0 }, Head = { 26, 20, 0 }, RArm = { 40, 10, 30 }, LArm = { 40, -10, -30 } }),
			K(0.3, "sineOut", WILD, { Root = { 0, -0.5, 0.5, 0, -20, 0 }, Torso = { -18, 0, 0 }, Head = { -10, 30, 0 } }),
			K(0.42, "sineInOut", WILD, { Root = { 0, -0.5, 0.4, 0, -18, 0 }, Head = { 0, 0, 0 } }),
			K(0.52, "sineInOut", WILD, { Head = { 0, 30, 0 } }),
			K(0.75, "sineInOut", WILD),
		},
		Events = { { t = 0.35, k = "Fx", n = "Riled" } },
	},

	-- 방어: 지팡이를 가로로 머리 위에 들어 막는다(봉술)
	Guard = {
		Duration = 0.7,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, WILD),
			K(0.07, "expoOut", WILD, { Root = { 0, -0.7, 0.2, 0, -14, 0 }, Torso = { -6, 0, 0 }, Head = { 10, 10, 0 }, RArm = { 140, 10, 20 }, LArm = { 140, -10, -20 }, W = { 0, -1.8, 0, -50, 0, 90 } }),
			K(0.2, "sineOut", WILD, { Root = { 0, -0.8, 0.4, 0, -14, 0 }, Torso = { -10, 0, 0 }, Head = { 12, 10, 0 }, RArm = { 136, 10, 20 }, LArm = { 136, -10, -20 }, W = { 0, -1.8, 0, -46, 0, 90 } }),
			K(0.7, "sineInOut", WILD),
		},
		Events = { { t = 0.08, k = "Fx", n = "StaffBlock" } },
	},

	-- 회피: 지팡이를 앞에 짚고 장대높이뛰기하듯 몸을 띄워 비껴 넘는다
	Dodge = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, WILD),
			K(0.08, "quadOut", WILD, { RArm = { 110, 20, 0 }, LArm = { 110, -20, 0 }, W = { 0, -2.4, 0, -40, 0, 0 }, Root = { 0, -0.7, 0, 0, -18, 0 } }),
			K(0.26, "cubicOut", WILD, { Root = { -1.2, 1.4, 0.8, 0, -18, -26 }, Torso = { 10, 0, 0 }, RArm = { 150, 20, 0 }, LArm = { 150, -20, 0 }, W = { 0, -2.4, 0, -150, 0, 0 }, RLeg = { 60, 0, 30 }, LLeg = { 40, 0, -10 } }),
			K(0.44, "quadIn", WILD, { Root = { -1.8, -0.7, 1.2, 0, -18, 0 }, Torso = { -20, 0, 0 } }),
			K(0.8, "sineInOut", WILD, { Root = { -0.6, -0.5, 0.4, 0, -18, 0 } }),
		},
		Events = { { t = 0.44, k = "Fx", n = "VaultLand" } },
	},

	Skills = {
		-- 쪼개기: 뛰어올라 곡괭이를 대상 정수리에 내리찍고, 박힌 날을 홱 뽑는다
		Cleave = {
			Duration = 1.45,
			Keys = {
				K(0, nil, WILD),
				K(0.25, "cubicOut", HIGH),
				K(0.38, "expoOut", PICK),
				K(0.7, "linear", PICK, { Root = { 0, -0.9, -0.6, 0, -12, 0 } }),
				-- 뽑기
				K(0.82, "expoOut", WILD, { Root = { 0, -0.6, 0.2, 0, -14, 0 }, Torso = { 10, 0, 0 }, RArm = { 110, 22, 0 }, LArm = { 110, -22, 0 }, W = { 0, -0.6, 0, -60, 0, 0 } }),
				K(1.45, "sineInOut", WILD),
			},
			Events = {
				{ t = 0.05, k = "Dash", to = "Target", gap = 4.2, d = 0.22 },
				{ t = 0.28, k = "Trail", on = true },
				{ t = 0.38, k = "Hit", i = 1, fx = "PickSlam" },
				{ t = 0.39, k = "Stop", d = 0.12 },
				{ t = 0.4, k = "Shake", a = 0.5, d = 0.3 },
				{ t = 0.5, k = "Trail", on = false },
				{ t = 0.82, k = "Fx", n = "Yank" },
				{ t = 1.0, k = "Dash", to = "Home", d = 0.3 },
			},
		},

		-- 무너뜨리기: 지팡이 끝을 잡고 길게 뻗어 한 바퀴 크게 휩쓴다(대상 줄 전체)
		BringDown = {
			Duration = 1.6,
			Keys = {
				K(0, nil, WILD),
				K(0.3, "cubicOut", WILD, { Root = { 0, -0.6, 0.2, 0, 40, 0 }, Torso = { -10, 30, 0 }, Head = { 10, -30, 0 }, RArm = { 88, 70, 20 }, LArm = { 88, 40, 0 }, W = { 0, 0.8, 0, -86, 90, 0 } }),
				K(0.62, "linear", WILD, { Root = { 0, -0.7, -0.2, 0, -200, 0 }, Torso = { -16, -20, 0 }, Head = { 10, 20, 0 }, RArm = { 88, -30, 30 }, LArm = { 88, -60, 0 }, W = { 0, 0.8, 0, -86, 90, 0 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
				K(0.8, "cubicOut", WILD, { Root = { 0, -0.7, -0.2, 0, -300, 0 }, Torso = { -16, -26, 0 }, Head = { 10, 26, 0 }, RArm = { 86, -40, 30 }, LArm = { 86, -70, 0 }, W = { 0, 0.8, 0, -86, 90, 0 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
				K(1.1, "sineOut", WILD, { Root = { 0, -0.66, -0.2, 0, -306, 0 }, Torso = { -14, -26, 0 }, RArm = { 84, -42, 30 }, LArm = { 84, -72, 0 }, W = { 0, 0.8, 0, -86, 90, 0 }, RLeg = { 32, 0, 18 }, LLeg = { -26, 0, -18 } }),
				K(1.6, "sineInOut", WILD, { Root = { 0, -0.5, 0, 0, -378, 0 } }),
			},
			Events = {
				{ t = 0.05, k = "Dash", to = "Target", gap = 5, d = 0.2 },
				{ t = 0.32, k = "Trail", on = true },
				{ t = 0.34, k = "Fx", n = "Sweep" },
				{ t = 0.5, k = "Hit", i = 1, fx = "SweepHit" },
				{ t = 0.51, k = "Stop", d = 0.07 },
				{ t = 0.52, k = "Shake", a = 0.4, d = 0.3 },
				{ t = 0.85, k = "Trail", on = false },
				{ t = 1.15, k = "Dash", to = "Home", d = 0.3 },
			},
		},

		-- 허물다: 지팡이를 머리 위에서 풍차처럼 돌려 [허물 벽]을 끌어모으고 — 뛰어올라 곡괭이를 꽂는다(폭발)
		TearDown = {
			Duration = 2.2,
			Keys = {
				K(0, nil, WILD),
				K(0.25, "cubicOut", HIGH, { W = { 0, 0, 0, -86, 0, 90 } }),
				K(0.5, "linear", HIGH, { W = { 0, 0, 0, -86, 0, 90 + 360 } }),
				K(0.75, "linear", HIGH, { W = { 0, 0, 0, -86, 0, 90 + 720 } }),
				K(1.0, "cubicOut", HIGH, { W = { 0, -0.6, 0, -20, 0, 90 + 720 + 270 }, Root = { 0, 0.2, 0.4, 0, -14, 0 }, Torso = { 22, 0, 0 } }),
				K(1.12, "expoOut", PICK, { Root = { 0, -1.1, -0.7, 0, -12, 0 }, Torso = { -48, 0, 0 }, W = { 0, -0.6, 0, -74, 0, 1080 } }),
				K(1.6, "linear", PICK, { Root = { 0, -1.05, -0.7, 0, -12, 0 }, Torso = { -46, 0, 0 }, W = { 0, -0.6, 0, -74, 0, 1080 } }),
				K(2.2, "sineInOut", WILD, { W = { 0.5, -0.6, 0, 88, 0, 1080 } }),
			},
			Events = {
				{ t = 0.25, k = "Trail", on = true },
				{ t = 0.3, k = "Fx", n = "Windmill" },
				{ t = 0.95, k = "Dash", to = "Target", gap = 4.2, d = 0.16, arc = 2.5 },
				{ t = 1.12, k = "Hit", i = 1, fx = "TearDownBlast" },
				{ t = 1.13, k = "Stop", d = 0.15 },
				{ t = 1.14, k = "Shake", a = 0.9, d = 0.55 },
				{ t = 1.3, k = "Trail", on = false },
				{ t = 1.7, k = "Dash", to = "Home", d = 0.35 },
			},
		},

		-- 제 살 깎기: 지팡이 자루로 제 가슴을 쾅 — 금이 온몸에 번지고 포효한다
		SelfCarve = {
			Duration = 1.5,
			Keys = {
				K(0, nil, WILD),
				K(0.25, "cubicOut", WILD, { Root = { 0, -0.4, 0.1, 0, -18, 0 }, Torso = { 10, 0, 0 }, Head = { 20, 16, 0 }, RArm = { 120, 30, 30 }, LArm = { 120, -30, -30 }, W = { 0, -1.2, 0, 60, 0, 90 } }),
				K(0.34, "expoOut", WILD, { Root = { 0, -0.5, 0.4, 0, -18, 0 }, Torso = { -20, 0, 0 }, Head = { -14, 16, 0 }, RArm = { 40, 30, 10 }, LArm = { 40, -30, -10 }, W = { 0, -1.2, 0, 60, 0, 90 } }),
				K(0.6, "sineOut", WILD, { Root = { 0, -0.5, 0.4, 0, -18, 0 }, Torso = { -24, 0, 0 }, Head = { -18, 16, 0 }, RArm = { 38, 30, 10 }, LArm = { 38, -30, -10 }, W = { 0, -1.2, 0, 60, 0, 90 } }),
				-- 포효
				K(0.8, "backOut", WILD, { Root = { 0, -0.3, 0, 0, -18, 0 }, Torso = { 20, 0, 0 }, Head = { 34, 10, 0 }, RArm = { 110, -40, 60 }, LArm = { 110, 40, -60 }, W = { 0, -1.2, 0, -40, 0, 0 } }),
				K(1.1, "sineOut", WILD, { Root = { 0, -0.3, 0, 0, -18, 0 }, Torso = { 22, 0, 0 }, Head = { 36, 10, 0 }, RArm = { 112, -42, 62 }, LArm = { 112, 42, -62 }, W = { 0, -1.2, 0, -40, 0, 0 } }),
				K(1.5, "sineInOut", WILD),
			},
			Events = {
				{ t = 0.34, k = "Fx", n = "SelfStrike" },
				{ t = 0.35, k = "Stop", d = 0.08 },
				{ t = 0.36, k = "Shake", a = 0.3, d = 0.25 },
				{ t = 0.8, k = "Fx", n = "Roar" },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, WILD),
				K(0.14, "backOut", WILD, { Root = { 0, -0.7, 0.2, 0, -14, 0 }, Torso = { -6, 0, 0 }, RArm = { 140, 10, 20 }, LArm = { 140, -10, -20 }, W = { 0, -1.8, 0, -50, 0, 90 } }),
				K(0.8, "sineInOut", WILD, { Root = { 0, -0.72, 0.2, 0, -14, 0 }, Torso = { -7, 0, 0 }, RArm = { 140, 10, 20 }, LArm = { 140, -10, -20 }, W = { 0, -1.8, 0, -50, 0, 90 } }),
				K(1.1, "sineInOut", WILD),
			},
			Events = { { t = 0.14, k = "Fx", n = "StaffBlock" } },
		},

		-- 명상: 지팡이를 세워 짚고 기대어 서서 눈을 감는다(가만히 있질 못해 발끝을 까딱)
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, WILD),
				K(0.4, "cubicInOut", WILD, { Root = { 0, -0.1, 0, 0, -18, -6 }, Torso = { 0, 0, 6 }, Head = { -16, 10, 8 }, RArm = { 60, 20, 0 }, LArm = { 60, -20, 0 }, W = { 0, -1.6, 0, 30, 0, 0 }, RLeg = { 6, 0, 4 }, LLeg = { -4, 0, -10 } }),
				K(1.0, "sineInOut", WILD, { Root = { 0, -0.1, 0, 0, -18, -6 }, Torso = { 0, 0, 6 }, Head = { -18, 10, 8 }, RArm = { 60, 20, 0 }, LArm = { 60, -20, 0 }, W = { 0, -1.6, 0, 30, 0, 0 }, RLeg = { 16, 0, 4 }, LLeg = { -4, 0, -10 } }),
				K(1.5, "sineInOut", WILD, { Root = { 0, -0.1, 0, 0, -18, -6 }, Torso = { 0, 0, 6 }, Head = { -16, 10, 8 }, RArm = { 60, 20, 0 }, LArm = { 60, -20, 0 }, W = { 0, -1.6, 0, 30, 0, 0 }, RLeg = { 6, 0, 4 }, LLeg = { -4, 0, -10 } }),
				K(2.0, "sineInOut", WILD),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
