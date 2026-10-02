--!strict
--[[
	퀘이사 — 별이 흐르는 검은 대검(츠바이핸더)을 멘 중력의 탱커. (2026-09-28, 자세 다시 2026-09-30)

	성격: 무겁고 느긋함. 넓게 버티고 서서 대검을 어깨에 멘다. 숨이 깊고 느리다.
	      공격은 **느린 예비 동작 → 한순간의 내려침 → 긴 여운**(땅이 울리고 타격 정지가 길다).
	      맞아도 거의 밀리지 않는다. 피하는 대신 검 면으로 쳐낸다.
	참고: 란츠크네히트의 츠바이핸더 — 칼집 없이 창처럼 어깨에 메고 다녔다(대기).
	      리히테나우어 4자세 중 폼 탁(칼을 머리 높이로 들어 내려칠 준비), 플루크(중단 겨눔).
	무기 종류: Great2H (WeaponDefinitions.Greatsword). 오른손 = 손잡이 윗쪽(가드 밑), 왼손 = 그 아래 0.6.
	수치: tools/combat/posecalc.py — 곧은 R6 팔로 두 손이 손잡이를 함께 쥐려면 손잡이가 몸 가운데 앞에 있어야 한다
	      (두 어깨 구의 교선). 자세마다 손잡이 자리·날 방향을 정하고 두 팔 각도·무기 회전(W)을 계산했다(어긋남 0.03 안).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 대기: 오른손이 배 앞에서 손잡이를 쥐고 칼 면이 오른 어깨 위에 얹혀 뒤 위로(란츠크네히트 메기), 넓게 선다
local REST = {
	Root = { 0, -0.28, 0, 0, -14, 0 },
	Torso = { -4, 0, 0 },
	Head = { 4, 12, 0 },
	RArm = { 60, 24, 8 },
	LArm = { 4, 0, -12 },
	RLeg = { 10, 0, 16 },
	LLeg = { -8, 0, -16 },
	W = { 0, 0, 0, 78.4, -11.7, 7.3 },
}
-- 폼 탁: 두 손을 이마 앞 높이로, 날은 위 뒤로 눕혀 내려칠 준비
local HIGH = { Root = { 0, -0.22, 0.2, 0, -8, 0 }, Torso = { 8, 0, 0 }, Head = { 10, 6, 0 }, RArm = { 127.1, 44.1, -24 }, LArm = { 108, -47.4, 11.1 }, RLeg = { 12, 0, 16 }, LLeg = { -10, 0, -16 }, W = { 0, 0, 0, 16.5, -59.1, 36.2 } }
-- 내려친 끝: 깊게 숙여 두 손이 배 앞 아래, 날끝이 앞 땅에 박힌다
local SLAM = { Root = { 0, -0.9, -0.6, 0, -8, 0 }, Torso = { -34, 0, 0 }, Head = { 22, 4, 0 }, RArm = { 66.9, 44.2, -8.6 }, LArm = { 59.8, -55.4, 24.1 }, RLeg = { 42, 0, 14 }, LLeg = { -34, 0, -14 }, W = { 0, 0, 0, -55.8, -197.2, 50.1 } }
-- 플루크(중단): 손잡이를 배 앞에, 날끝이 적 얼굴로
local MID = { Root = { 0, -0.4, 0, 0, -8, 0 }, Torso = { -8, 0, 0 }, Head = { 8, 6, 0 }, RArm = { 59.3, 46.6, -14.2 }, LArm = { 48.3, -56.2, 26.6 }, RLeg = { 22, 0, 14 }, LLeg = { -20, 0, -14 }, W = { 0, 0, 0, 133.8, 27.6, -125.3 } }
-- 방어 벽: 날을 몸 앞에 곧게 세우고(끝 위) 넓은 면이 적을 본다
local WALL = { Root = { 0, -0.55, 0.15, 0, -2, 0 }, Torso = { -4, 0, 0 }, Head = { 6, 4, 0 }, RArm = { 86.3, 46.6, -15.4 }, LArm = { 64, -45.7, 12.5 }, RLeg = { 24, 0, 16 }, LLeg = { -20, 0, -16 }, W = { 0, 0, 0, -4.3, -61.8, -6.5 } }
-- 꽂기(명상): 날을 곧게 아래로 꽂고 두 손을 폼멜 쪽에 포갠다(손이 손잡이 끝을 쥐도록 무기를 0.58 밀어 올림)
local PLANT = { Root = { 0, -0.3, 0, 0, -4, 0 }, Torso = { -4, 0, 0 }, Head = { -26, 0, 0 }, RArm = { 93, 47.8, -14.7 }, LArm = { 67.2, -46.1, 10.7 }, RLeg = { 4, 0, 12 }, LLeg = { -4, 0, -12 }, W = { 0, 0.58, 0.01, 180.6, -117.6, 2.7 } }
-- 가로베기: 날을 오른쪽 뒤로 눕혀 몸을 감았다가(A) 왼쪽 앞으로 쓸어낸 끝(B)
local SWEEP_A = { Root = { 0, -0.5, 0.2, 0, 20, 0 }, Torso = { -8, 30, 0 }, Head = { 6, -16, 0 }, RArm = { 61.2, 72.4, 6.1 }, LArm = { 61.2, -5.2, 31.4 }, RLeg = { 20, 0, 14 }, LLeg = { -18, 0, -14 }, W = { 0, 0, 0, 28.5, -97.8, -84.8 } }
local SWEEP_B = { Root = { 0, -0.62, -0.3, 0, -40, 0 }, Torso = { -14, -40, 0 }, Head = { 10, 30, 0 }, RArm = { 69.7, 25.9, -43.3 }, LArm = { 69.7, -82.5, 1.6 }, RLeg = { 34, 0, 14 }, LLeg = { -30, 0, -14 }, W = { 0, 0, 0, -57.5, 76.9, -14.3 } }
-- 하늘 가리키기(한 손, 날 위로) / 앞 아래로 내려 긋는 명령
local SKY = { Root = { 0, -0.2, 0, 0, -20, 0 }, Torso = { 10, -8, 0 }, Head = { 20, 14, 0 }, RArm = { 178, 10, 10 }, LArm = { 40, 0, -40 }, RLeg = { 10, 0, 16 }, LLeg = { -8, 0, -16 }, W = { 0, 0, 0, -81.8, 0, 8.1 } }
local CMD = { Root = { 0, -0.5, -0.2, 0, -6, 0 }, Torso = { -22, 6, 0 }, Head = { 16, 6, 0 }, RArm = { 74, 20, 10 }, LArm = { 20, 0, -50 }, RLeg = { 30, 0, 16 }, LLeg = { -24, 0, -16 }, W = { 0, 0, 0, -86.2, 0, -9.6 } }
-- 끌어당기기: 한 손으로 대검을 앞으로 겨누고 왼손을 뻗어 움켜쥔다
local PULL = { Root = { 0, -0.5, 0.2, 0, -8, 0 }, Torso = { -8, 0, 0 }, Head = { 14, 6, 0 }, RArm = { 96, 24, 8 }, LArm = { 90, -10, 0 }, RLeg = { 22, 0, 14 }, LLeg = { -20, 0, -14 }, W = { 0, 0, 0, -78.4, 0, -15.1 } }
-- 들림: 한 손에 늘어진 대검(끝이 아래)
local HANG = { Root = { 0, 0, 0, 6, -12, 3 }, Torso = { -10, 0, 0 }, Head = { -22, 0, 0 }, RArm = { -4, 0, 4 }, LArm = { -2, 0, -6 }, RLeg = { 2, 0, 3 }, LLeg = { -4, 0, -3 }, W = { 0, 0, 0, -84.2, 0, 3.6 } }

-- 폼 탁에서 중력이 뭉쳐 떨린다(붕괴 예비)
local function tremble(t: number, dx: number, lift: number): { [string]: any }
	return K(t, "sineInOut", HIGH, { Root = { dx, -0.22 - lift, 0.2 + lift, 0, -8, 0 }, Torso = { 8 + lift * 40, 0, 0 } })
end

return {
	Stance = REST,

	-- 대기: 깊고 느린 숨(Kit.Breath, Smooth — 2026-10-02 사용자: 끊기지 않게). 들숨에 가슴이 오르며 어깨 위 대검이 함께 들썩이고,
	-- 내쉬며 고개가 조금 돌아간다.
	Idle = Kit.Breath(REST, {
		Duration = 3.9,
		Chest = 2.5,
		Rise = 0.04,
		In = { RArm = { 61.5, 24, 8 }, LArm = { 5, 0, -13 } },
		Mid = { Head = { 3, 15, 0 } },
	}),

	-- 들림: 축 늘어져 대검 무게에 끌려 내려간다. 칼끝이 아래로 늘어지고 천천히 시계추처럼 흔들린다
	Held = {
		Duration = 2.4,
		Loop = true,
		Keys = {
			K(0, "sineInOut", HANG),
			K(1.2, "sineInOut", HANG, { Root = { 0, 0, 0, -6, -12, -3 }, Torso = { -8, 0, 0 }, Head = { -18, 6, 0 }, RArm = { 4, 0, 4 }, LArm = { 4, 0, -6 }, RLeg = { -4, 0, 3 }, LLeg = { 2, 0, -3 }, W = { 0, 0, 0, -94, 0, -3 } }),
		},
	},

	-- 내려놓임: 쿵 — 폼 탁으로 내려오며 대검을 앞 땅에 꽂고(충격파), 중단으로 뽑아 들고 다시 어깨에 멘다
	Drop = {
		Duration = 1.3,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, HIGH, { Root = { 0, 0.3, 0.2, 0, -8, 0 } }),
			K(0.08, "quadIn", SLAM, { Root = { 0, -1.1, -0.2, 0, -8, 0 }, RLeg = { 30, 0, 18 }, LLeg = { -30, 0, -18 } }),
			K(0.5, "sineOut", SLAM, { Root = { 0, -1.0, -0.2, 0, -8, 0 }, Torso = { -30, 0, 0 }, RLeg = { 30, 0, 18 }, LLeg = { -30, 0, -18 } }),
			-- W 는 같은 회전을 ±360 감아 적었다(내려찍기→중단→대기가 짧은 길로 돌게 — check_wrap.py)
			K(0.9, "cubicInOut", MID, { W = { 0, 0, 0, -226.2, -332.4, -125.3 } }),
			K(1.3, "sineInOut", REST, { W = { 0, 0, 0, -281.6, -371.7, 7.3 } }),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "HeavyLand" },
			{ t = 0.09, k = "Shake", a = 0.4, d = 0.3 },
		},
	},

	-- 피격: 거의 안 밀린다 — 짧게 움찔, 질량이 충격을 삼키는 물결
	Hit = {
		Duration = 0.6,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, REST),
			K(0.05, "expoOut", REST, { Root = { 0, -0.35, 0.3, 0, -12, 0 }, Torso = { 6, 4, 0 }, Head = { 14, 16, 0 }, LArm = { 20, 0, -30 } }),
			K(0.3, "sineOut", REST, { Root = { 0, -0.32, 0.2, 0, -14, 0 }, Torso = { -8, 0, 0 }, Head = { -2, 12, 0 } }),
			K(0.6, "sineInOut", REST),
		},
		Events = { { t = 0.05, k = "Fx", n = "MassAbsorb" } },
	},

	-- 방어: 대검을 몸 앞에 곧게 세우고 두 손으로 버틴다(넓은 칼 면이 벽)
	Guard = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, REST),
			K(0.1, "expoOut", WALL),
			K(0.22, "sineOut", WALL, { Root = { 0, -0.6, 0.35, 0, -2, 0 }, Torso = { -7, 0, 0 } }),
			K(0.75, "cubicInOut", REST),
		},
		Events = { { t = 0.1, k = "Fx", n = "GravityWall" } },
	},

	-- 회피(성공 = 쳐냄): 중단에서 검 면으로 왼쪽으로 쓸어 공격을 흘리고, 무게를 싣고 한 걸음 비킨다
	Dodge = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, REST),
			K(0.08, "quadOut", MID, { Root = { 0.2, -0.45, 0, 0, -2, 0 } }),
			-- W 는 같은 회전을 +360 감아 적었다(중단→쳐내기가 짧은 길로 돌게 — check_wrap.py)
			K(0.16, "expoOut", SWEEP_B, { Root = { -0.5, -0.5, 0.2, 0, -30, 0 }, Torso = { -10, -30, 0 }, W = { 0, 0, 0, 302.5, 76.9, -14.3 } }),
			K(0.4, "sineOut", SWEEP_B, { Root = { -0.6, -0.48, 0.2, 0, -30, 0 }, Torso = { -8, -30, 0 }, W = { 0, 0, 0, 302.5, 76.9, -14.3 } }),
			K(0.8, "cubicInOut", REST, { W = { 0, 0, 0, 438.4, -11.7, 7.3 } }),
		},
		Events = {
			{ t = 0.1, k = "Trail", on = true },
			{ t = 0.14, k = "Fx", n = "Deflect" },
			{ t = 0.4, k = "Trail", on = false },
		},
	},

	Skills = {
		-- 붕괴: 폼 탁으로 치켜든 대검 위에 중력이 뭉친다(떨림) → 한 칸 내딛으며 온몸으로 내려친다
		Collapse = {
			Duration = 2.2,
			Keys = {
				K(0, nil, REST),
				K(0.35, "cubicInOut", HIGH),
				tremble(0.6, 0.04, 0.06),
				tremble(0.72, -0.04, 0.08),
				tremble(0.84, 0.04, 0.1),
				tremble(0.96, -0.03, 0.12),
				tremble(1.08, 0, 0.14),
				K(1.18, "expoOut", SLAM),
				K(1.6, "linear", SLAM, { Root = { 0, -0.86, -0.6, 0, -8, 0 } }),
				K(1.9, "cubicInOut", MID, { W = { 0, 0, 0, -226.2, -332.4, -125.3 } }),
				K(2.2, "sineInOut", REST, { W = { 0, 0, 0, -281.6, -371.7, 7.3 } }),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Implode" },
				{ t = 0.9, k = "Dash", to = "Target", gap = 4.5, d = 0.18, e = "quadIn" },
				{ t = 1.05, k = "Trail", on = true },
				{ t = 1.18, k = "Hit", i = 1, fx = "CollapseSlam" },
				{ t = 1.19, k = "Stop", d = 0.14 },
				{ t = 1.2, k = "Shake", a = 0.8, d = 0.5 },
				{ t = 1.4, k = "Trail", on = false },
				{ t = 1.75, k = "Dash", to = "Home", d = 0.35 },
			},
		},

		-- 붕괴 차징(첫 사용 = 피해 없음): 폼 탁으로 중력을 모으고, 한 손으로 대검을 겨눈 채 왼손으로 적을 움켜 끌어당긴다
		CollapseCharge = {
			Duration = 1.7,
			Keys = {
				K(0, nil, REST),
				K(0.35, "cubicInOut", HIGH),
				tremble(0.6, 0.04, 0.06),
				tremble(0.75, -0.04, 0.07),
				tremble(0.9, 0.04, 0.08),
				K(1.1, "expoOut", PULL),
				K(1.35, "sineOut", PULL, { Root = { 0, -0.52, 0.35, 0, -8, 0 }, LArm = { 70, 10, 0 } }),
				K(1.7, "sineInOut", REST),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Implode" },
				{ t = 1.1, k = "Fx", n = "Pull" },
				{ t = 1.12, k = "Shake", a = 0.25, d = 0.3 },
			},
		},

		-- 특이점: 대검으로 하늘을 가리키면 대상 위에 거대한 에너지 검이 나타나 — 앞 아래로 내려 긋는 손짓에 떨어져 꽂힌다
		Singularity = {
			Duration = 2.2,
			Keys = {
				K(0, nil, REST),
				K(0.4, "cubicOut", SKY),
				K(0.95, "sineInOut", SKY, { Root = { 0, -0.18, 0, 0, -20, 0 }, Torso = { 12, -8, 0 }, Head = { 22, 14, 0 }, RArm = { 180, 10, 10 }, LArm = { 44, 0, -44 } }),
				K(1.1, "expoOut", CMD),
				K(1.6, "sineOut", CMD, { Root = { 0, -0.46, -0.2, 0, -6, 0 }, Torso = { -18, 6, 0 }, Head = { 12, 6, 0 }, RArm = { 72, 20, 10 } }),
				K(2.2, "sineInOut", REST),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "PointSky" },
				{ t = 0.5, k = "Fx", n = "SummonSword" },
				{ t = 1.1, k = "Trail", on = true },
				{ t = 1.1, k = "Fx", n = "DropSword" },
				{ t = 1.35, k = "Hit", i = 1, fx = "SingularityHit" },
				{ t = 1.36, k = "Stop", d = 0.12 },
				{ t = 1.37, k = "Shake", a = 0.7, d = 0.5 },
				{ t = 1.4, k = "Trail", on = false },
			},
		},

		-- 낙하: 짧고 빠른 가로베기 — 오른쪽 뒤로 감았다가 왼쪽 앞으로 쓸어낸다(퀘이사치고 가벼운 한 수)
		Infall = {
			Duration = 1.3,
			Keys = {
				K(0, nil, REST),
				K(0.22, "cubicOut", SWEEP_A),
				K(0.34, "expoOut", SWEEP_B),
				K(0.7, "sineOut", SWEEP_B, { Root = { 0, -0.58, -0.3, 0, -44, 0 }, Torso = { -12, -44, 0 } }),
				K(1.3, "cubicInOut", REST),
			},
			Events = {
				{ t = 0.08, k = "Dash", to = "Target", gap = 4, d = 0.16 },
				{ t = 0.26, k = "Trail", on = true },
				{ t = 0.33, k = "Hit", i = 1, fx = "InfallCut" },
				{ t = 0.34, k = "Stop", d = 0.08 },
				{ t = 0.35, k = "Shake", a = 0.35, d = 0.25 },
				{ t = 0.5, k = "Trail", on = false },
				{ t = 0.85, k = "Dash", to = "Home", d = 0.28 },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, REST),
				K(0.2, "backOut", WALL),
				K(0.8, "sineInOut", WALL, { Root = { 0, -0.57, 0.15, 0, -2, 0 }, Torso = { -5, 0, 0 } }),
				K(1.1, "sineInOut", REST),
			},
			Events = { { t = 0.2, k = "Fx", n = "GravityWall" } },
		},

		-- 명상: 대검을 앞 땅에 곧게 꽂고 폼멜에 두 손을 포갠 채 고개를 숙인다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, REST),
				K(0.4, "cubicInOut", PLANT),
				K(1.5, "sineInOut", PLANT, { Root = { 0, -0.34, 0, 0, -4, 0 }, Torso = { -2, 0, 0 }, Head = { -22, 0, 0 } }),
				K(2.0, "sineInOut", REST),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
