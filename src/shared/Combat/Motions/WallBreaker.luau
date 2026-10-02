--!strict
--[[
	월 브레이커 — 곡괭이 머리를 단 쿼터스태프를 휘두르는 파괴자. (2026-09-28, 자세 다시 2026-10-02)

	성격: 거칠고 들뜸. 낮게 웅크려 몸을 들썩이고, 틈만 나면 지팡이 끝으로 툭 찔러 본다. 휘두름이 크고 **다 걸어 버린다**.
	      맞으면 약이 올라 더 들뜨고, 피할 때는 지팡이를 짚고 장대높이뛰기하듯 넘어간다.
	참고: 조지 실버(1599) 쿼터스태프 — 뒷손은 자루 끝, 앞손은 그보다 한 뼘(30~45cm) 위, 앞손·앞발이 적 쪽.
	      낮은 겨눔(close fight): 두 손은 허리 앞, 지팡이 끝은 적 얼굴 높이. 막기는 자루를 가로로 들어 머리 위에서 받고,
	      휩쓸기는 두 손을 자루 끝으로 모아 길게 뻗는다.
	무기 종류: Polearm2H (WeaponDefinitions.PickStaff). 오른손(뒷손) = 자루 끝 가죽(무기 y 0.05), 왼손(앞손) = 그 위 가죽(y 1.35).
	      곡괭이 머리(y 4.0, 날 -Z)가 앞 끝. 두 팔·W 는 tools/combat/design/breaker_gen.py(two_hand)로 구했다 —
	      W 자리 y = 오른손이 쥔 자루 자리(휩쓸기 -1.3, 짚기 1.2 등은 손을 미끄러뜨린 것).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 낮은 겨눔(대기): 몸을 오른쪽으로 틀어 왼 어깨·왼발이 적 쪽, 두 손은 허리 앞, 지팡이 끝은 적 얼굴 높이로 조금 들림,
-- 곡괭이 날은 아래(갈고리처럼 걸어 당길 준비)
local GUARD = { Root = { 0, -0.45, 0, 0, -35, 0 }, Torso = { -12, 0, 0 }, Head = { 4, 30, 0 }, RArm = { 56.5, 57, -25.9 }, LArm = { 72.9, -20.7, 0 }, RLeg = { -20, 0, 12 }, LLeg = { 24, 0, -12 }, W = { -0.02, -0.05, -0.02, -47.9, -32.4, -38.9 } }
-- 툭 찔러 봄: 앞으로 무게를 싣고 두 팔을 뻗음
local JAB = { Root = { 0, -0.55, -0.5, 0, -35, 0 }, Torso = { -20, 0, 0 }, Head = { 10, 30, 0 }, RArm = { 72.1, 50, -23.6 }, LArm = { 90.9, -19.4, 0 }, RLeg = { -34, 0, 12 }, LLeg = { 36, 0, -12 }, W = { 0, -0.07, 0.01, -60.6, -29.9, -32.7 } }
-- 머리 위로 치켜듦(내려찍기 예비): 지팡이는 머리 위에서 뒤로 기울고, 날은 위(내려칠 때 앞장섬)
local HIGH = { Root = { 0, -0.1, 0.3, 0, -14, 0 }, Torso = { 16, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 114.1, 47.6, -28.8 }, LArm = { 164.3, -32.1, 46 }, RLeg = { 10, 0, 14 }, LLeg = { -20, 0, -14 }, W = { -0.04, -0.07, -0.02, 38.6, -51.1, 42.3 } }
-- 내려찍은 끝: 곡괭이 날 끝이 앞 땅에 박힘
local PICK = { Root = { 0, -0.95, -0.6, 0, -12, 0 }, Torso = { -40, 0, 0 }, Head = { 24, 8, 0 }, RArm = { 69.5, 51.6, -26.7 }, LArm = { 105.7, -29.6, 4.9 }, RLeg = { 44, 0, 14 }, LLeg = { -36, 0, -14 }, W = { -0.02, -0.06, -0.01, -48.2, -56.8, -49.9 } }
-- 막기: 두 손을 넓게 벌려 자루를 가로로 머리 위에 들어 받음(들림 때 철봉처럼 매달리는 자세도 이것)
local BLOCK = { Root = { 0, -0.7, 0.2, 0, -14, 0 }, Torso = { -6, 0, 0 }, Head = { 10, 10, 0 }, RArm = { 164.5, 11.6, -4.3 }, LArm = { 175.2, -21.7, 30 }, RLeg = { 20, 0, 14 }, LLeg = { -16, 0, -14 }, W = { 0, 0.31, -0.02, 21.4, -5.7, 89.1 } }
-- 휩쓸기: 두 손을 자루 끝으로 모아 지팡이를 앞으로 수평으로 길게 뻗음(날은 오른쪽 — 몸이 오른쪽으로 돌 때 앞장섬)
local SWEEP = { Root = { 0, -0.6, 0.2, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { 10, 20, 0 }, RArm = { 38.2, 56.7, -39.4 }, LArm = { 46.9, -43.1, 24.8 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 }, W = { 0, 1.28, 0, -140.2, -6, -127.5 } }
-- 짚고 기댐(명상·내려놓임·장대넘기): 지팡이를 오른발 앞에 세워 물미를 땅에, 두 손은 가슴 높이로 미끄러뜨려 쥠
local LEAN = { Root = { 0, -0.15, 0, 0, -18, -4 }, Torso = { 0, 0, 4 }, Head = { -16, 10, 8 }, RArm = { 67.8, 36, -22.7 }, LArm = { 96.3, -38.9, 19.5 }, RLeg = { 6, 0, 4 }, LLeg = { -4, 0, -10 }, W = { -0.02, -1.21, -0.03, 20.1, -39.2, 3.3 } }
-- 제 가슴 치기: 자루를 가로로 팔 길이 앞에 들었다가(CHEST_PRE) 가슴에 끌어당겨 쾅(CHEST).
-- W 는 같은 회전의 다른 오일러 표기(a+180, 180-b, c+180)로 적었다 — 대기·포효와 이어질 때 한 값이 180 넘게 바뀌어 오일러로 돌지 않게
local CHEST_PRE = { Root = { 0, -0.4, 0.1, 0, -18, 0 }, Torso = { 10, 0, 0 }, Head = { 20, 16, 0 }, RArm = { 110, 55.6, -14.4 }, LArm = { 141.1, 3.7, -28 }, RLeg = { -20, 0, 12 }, LLeg = { 24, 0, -12 }, W = { -0.03, 0.34, -0.02, 71.9, -17.3, -212.4 } }
local CHEST = { Root = { 0, -0.5, 0.4, 0, -18, 0 }, Torso = { -20, 0, 0 }, Head = { -14, 16, 0 }, RArm = { 65.6, 54.4, -14 }, LArm = { 34.6, -4.9, -37.2 }, RLeg = { -20, 0, 12 }, LLeg = { 24, 0, -12 }, W = { -0.08, 0.39, 0.09, 126.9, 20.5, -219.1 } }
-- 포효: 두 팔을 벌리고 오른손 하나로 지팡이를 치켜듦
local ROAR = { Root = { 0, -0.3, 0, 0, -18, 0 }, Torso = { 20, 0, 0 }, Head = { 34, 10, 0 }, RArm = { 110, -40, 60 }, LArm = { 110, 40, -60 }, RLeg = { 16, 0, 14 }, LLeg = { -14, 0, -14 }, W = { 0, -0.05, 0, 53.6, 104, -91.7 } }
-- 풍차: 오른팔을 곧게 치켜들고 자루 가운데(y 1.4)를 쥐어 머리 위에서 수평으로 돌림 — 기울기(팔 축 둘레)를 360 씩 더한다
local WIND = { Root = { 0, 0, 0.2, 0, -14, 0 }, Torso = { 0, 0, 0 }, Head = { 24, 10, 0 }, RArm = { 178, 10, 0 }, LArm = { 150, -30, -30 }, RLeg = { 10, 0, 14 }, LLeg = { -20, 0, -14 }, W = { 0, -1.4, 0, 0, 0, 0 } }

local function spin(pose: { [string]: any }, turns: number): { number }
	local w = pose.W
	return { w[1], w[2], w[3], w[4], w[5], w[6] + 360 * turns }
end

return {
	Stance = GUARD,

	-- 대기: 들썩들썩 좌우로 무게를 옮기다가, 지팡이 끝으로 툭 찔러 보고 물러나 고개를 까딱
	Idle = {
		Duration = 3.64,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", GUARD),
			K(0.52, "sineInOut", GUARD, { Root = { 0.12, -0.53, 0, 0, -38, 0 }, Torso = { -15, 4, 0 }, Head = { 0, 34, -6 } }),
			K(1.04, "sineInOut", GUARD, { Root = { -0.12, -0.4, 0, 0, -32, 0 }, Torso = { -10, -4, 0 }, Head = { 8, 26, 6 } }),
			K(1.4, "sineInOut", GUARD, { Root = { 0, -0.5, 0.1, 0, -35, 0 } }),
			K(1.6, "expoOut", JAB),
			K(1.95, "cubicInOut", GUARD),
			K(2.5, "sineInOut", GUARD, { Root = { 0.1, -0.52, 0, 0, -37, 0 }, Torso = { -14, 3, 0 }, Head = { 12, 40, -10 } }),
			K(3.1, "sineInOut", GUARD, { Root = { -0.1, -0.42, 0, 0, -33, 0 }, Torso = { -11, -3, 0 } }),
		},
	},

	-- 들림: 지팡이를 철봉처럼 머리 위로 가로 쥐고 매달려 다리를 흔든다
	Held = {
		Duration = 1.4,
		Loop = true,
		Keys = {
			K(0, "sineInOut", BLOCK, { Root = { 0, -0.2, 0, 6, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 20, 14, 0 }, RLeg = { 30, 0, 4 }, LLeg = { 16, 0, -4 } }),
			K(0.7, "sineInOut", BLOCK, { Root = { 0, -0.2, 0, -6, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 16, 14, 0 }, RLeg = { -24, 0, 4 }, LLeg = { -34, 0, -4 } }),
		},
	},

	-- 내려놓임: 지팡이 밑동을 땅에 쾅 박으며 착지(금), 씩 웃듯 고개를 까딱
	Drop = {
		Duration = 1.0,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, LEAN, { Root = { 0, 0.4, 0, 0, -18, 0 }, Torso = { 0, 0, 0 } }),
			K(0.08, "quadIn", LEAN, { Root = { 0, -0.6, 0, 0, -18, 0 }, Torso = { -16, 0, 0 }, Head = { 6, 16, 0 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
			K(0.45, "sineOut", LEAN, { Root = { 0, -0.55, 0, 0, -18, 0 }, Torso = { -14, 0, 0 }, Head = { 20, 30, -10 }, RLeg = { 34, 0, 18 }, LLeg = { -28, 0, -18 } }),
			K(1.0, "sineInOut", GUARD),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "ButtSlam" },
			{ t = 0.09, k = "Shake", a = 0.25, d = 0.2 },
		},
	},

	-- 피격: 휙 젖혀지며 앞손이 자루를 놓쳤다가, 고개를 털고 다시 잡아 더 들뜬다(약이 오름)
	Hit = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, GUARD),
			K(0.05, "expoOut", GUARD, { Root = { 0, -0.3, 0.8, 0, -40, 0 }, Torso = { 14, -8, 0 }, Head = { 26, 36, 0 }, RArm = { 40, 30, 0 }, LArm = { 40, -10, -30 } }),
			K(0.3, "sineOut", GUARD, { Root = { 0, -0.5, 0.5, 0, -36, 0 }, Torso = { -18, 0, 0 }, Head = { -10, 40, 0 } }),
			K(0.42, "sineInOut", GUARD, { Root = { 0, -0.5, 0.4, 0, -35, 0 }, Head = { 4, 16, 0 } }),
			K(0.52, "sineInOut", GUARD, { Head = { 4, 44, 0 } }),
			K(0.75, "sineInOut", GUARD),
		},
		Events = { { t = 0.35, k = "Fx", n = "Riled" } },
	},

	-- 방어: 지팡이를 가로로 머리 위에 들어 막는다(봉술)
	Guard = {
		Duration = 0.7,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, GUARD),
			K(0.07, "expoOut", BLOCK),
			K(0.2, "sineOut", BLOCK, { Root = { 0, -0.8, 0.4, 0, -14, 0 }, Torso = { -10, 0, 0 }, Head = { 12, 10, 0 } }),
			K(0.7, "sineInOut", GUARD),
		},
		Events = { { t = 0.08, k = "Fx", n = "StaffBlock" } },
	},

	-- 회피: 지팡이를 앞에 짚고 장대높이뛰기하듯 몸을 띄워 비껴 넘는다
	Dodge = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, GUARD),
			K(0.08, "quadOut", LEAN, { Root = { 0, -0.5, 0, 0, -18, 0 }, Torso = { -14, 0, 0 } }),
			K(0.26, "cubicOut", LEAN, { Root = { -1.2, 1.4, 0.8, 0, -18, -26 }, Torso = { 10, 0, 0 }, RLeg = { 60, 0, 30 }, LLeg = { 40, 0, -10 } }),
			K(0.44, "quadIn", GUARD, { Root = { -1.8, -0.7, 1.2, 0, -35, 0 }, Torso = { -20, 0, 0 } }),
			K(0.8, "sineInOut", GUARD, { Root = { -0.6, -0.5, 0.4, 0, -35, 0 } }),
		},
		Events = { { t = 0.44, k = "Fx", n = "VaultLand" } },
	},

	Skills = {
		-- 쪼개기: 뛰어올라 곡괭이를 대상 정수리에 내리찍고, 박힌 날을 홱 뽑는다
		Cleave = {
			Duration = 1.45,
			Keys = {
				K(0, nil, GUARD),
				K(0.25, "cubicOut", HIGH),
				K(0.38, "expoOut", PICK),
				K(0.7, "linear", PICK, { Root = { 0, -0.9, -0.6, 0, -12, 0 } }),
				-- 뽑기: 몸을 뒤로 젖히며 지팡이를 홱 당김
				K(0.82, "expoOut", JAB, { Root = { 0, -0.5, 0.3, 0, -30, 0 }, Torso = { 8, 0, 0 }, Head = { 16, 26, 0 } }),
				K(1.45, "sineInOut", GUARD),
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

		-- 무너뜨리기: 두 손을 자루 끝으로 모아 길게 뻗고, 몸째 한 바퀴 크게 휩쓴다(대상 줄 전체)
		BringDown = {
			Duration = 1.6,
			Keys = {
				K(0, nil, GUARD),
				K(0.3, "cubicOut", SWEEP, { Root = { 0, -0.6, 0.2, 0, 40, 0 }, Torso = { -10, 20, 0 }, Head = { 10, -20, 0 } }),
				K(0.62, "linear", SWEEP, { Root = { 0, -0.7, -0.2, 0, -200, 0 }, Torso = { -16, -20, 0 }, Head = { 10, 20, 0 } }),
				K(0.8, "cubicOut", SWEEP, { Root = { 0, -0.7, -0.2, 0, -300, 0 }, Torso = { -16, -26, 0 }, Head = { 10, 26, 0 } }),
				K(1.1, "sineOut", SWEEP, { Root = { 0, -0.66, -0.2, 0, -306, 0 }, Torso = { -14, -26, 0 }, Head = { 10, 26, 0 } }),
				K(1.6, "sineInOut", GUARD, { Root = { 0, -0.45, 0, 0, -395, 0 } }),
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

		-- 허물다: 지팡이를 머리 위에서 풍차처럼 돌려 [허물 벽]을 끌어모으고 — 뛰어올라 곡괭이를 꽂는다(폭발).
		-- 두 바퀴 돈 감김(720)을 끝까지 들고 간다(되감지 않게 — 다음 모션과 섞일 때는 가까운 쪽으로 돈다)
		TearDown = {
			Duration = 2.2,
			Keys = {
				K(0, nil, GUARD),
				K(0.25, "cubicOut", WIND),
				K(0.5, "linear", WIND, { W = spin(WIND, 1) }),
				K(0.75, "linear", WIND, { W = spin(WIND, 2) }),
				K(1.0, "cubicOut", HIGH, { W = spin(HIGH, 2), Root = { 0, 0.2, 0.4, 0, -14, 0 }, Torso = { 22, 0, 0 } }),
				K(1.12, "expoOut", PICK, { W = spin(PICK, 2), Root = { 0, -1.1, -0.7, 0, -12, 0 }, Torso = { -48, 0, 0 } }),
				K(1.6, "linear", PICK, { W = spin(PICK, 2), Root = { 0, -1.05, -0.7, 0, -12, 0 }, Torso = { -46, 0, 0 } }),
				K(2.2, "sineInOut", GUARD, { W = spin(GUARD, 2) }),
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
				K(0, nil, GUARD),
				K(0.25, "cubicOut", CHEST_PRE),
				K(0.34, "expoOut", CHEST),
				K(0.6, "sineOut", CHEST, { Torso = { -24, 0, 0 }, Head = { -18, 16, 0 } }),
				-- 포효
				K(0.8, "backOut", ROAR),
				K(1.1, "sineOut", ROAR, { Torso = { 22, 0, 0 }, Head = { 36, 10, 0 }, RArm = { 112, -42, 62 }, LArm = { 112, 42, -62 } }),
				K(1.5, "sineInOut", GUARD),
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
				K(0, nil, GUARD),
				K(0.14, "backOut", BLOCK),
				K(0.8, "sineInOut", BLOCK, { Root = { 0, -0.72, 0.2, 0, -14, 0 }, Torso = { -7, 0, 0 } }),
				K(1.1, "sineInOut", GUARD),
			},
			Events = { { t = 0.14, k = "Fx", n = "StaffBlock" } },
		},

		-- 명상: 지팡이를 세워 짚고 기대어 서서 눈을 감는다(가만히 있질 못해 발끝을 까딱)
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, GUARD),
				K(0.4, "cubicInOut", LEAN),
				K(1.0, "sineInOut", LEAN, { Head = { -18, 10, 8 }, RLeg = { 16, 0, 4 } }),
				K(1.5, "sineInOut", LEAN),
				K(2.0, "sineInOut", GUARD),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
