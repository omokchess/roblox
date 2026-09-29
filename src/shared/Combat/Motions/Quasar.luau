--!strict
--[[
	퀘이사 — 별이 흐르는 검은 대검을 멘 중력의 탱커. (2026-09-28)

	성격: 무겁고 느긋함. 넓게 버티고 서서 대검을 어깨에 걸친다. 숨이 깊고 느리다.
	      공격은 **느린 예비 동작 → 한순간의 내려침 → 긴 여운**(땅이 울리고 타격 정지가 길다).
	      맞아도 거의 밀리지 않는다. 피하는 대신 검 면으로 쳐낸다.
	무기 종류: Great2H (WeaponDefinitions.Greatsword). 오른손이 쥐고 왼손은 모션이 손잡이로 모은다.
	  두 손 잡기: 오른팔 Y +25, 왼팔 Y -25 (양 어깨에서 가슴 앞 한 점으로 모임)
	  칼 방향(옆에서 본 각, 0 아래 · 90 앞 · 180 위 · 270 뒤) = 팔 X + 90 + 숙임 − 몸통 숙임
	  (어깨에 메기 ≈ 210 = 위 뒤, 뒤로 끌기 ≈ 315 = 아래 뒤, 땅 내려찍기 끝 ≈ 60~75)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 대검을 오른 어깨에 걸치고 넓게 선 자세
local REST = {
	Root = { 0, -0.28, 0, 0, -12, 0 },
	Torso = { -6, 0, 0 },
	Head = { 6, 10, 0 },
	RArm = { 52, 18, 24 },
	LArm = { 12, 0, -16 },
	RLeg = { 10, 0, 16 },
	LLeg = { -8, 0, -16 },
	W = { 0.55, 0, 0, 68, 0, 0 },
}
-- 두 손으로 머리 위로 든 자세(칼끝이 등 뒤로 늘어짐)
local HIGH = W(REST, {
	Root = { 0, -0.2, 0.2, 0, -8, 0 },
	Torso = { 10, 0, 0 },
	Head = { 12, 6, 0 },
	RArm = { 168, 22, 0 },
	LArm = { 168, -22, 0 },
	W = { 0, 0, 0, -40, 0, 0 },
})
-- 내려친 끝: 몸을 숙이고 칼이 앞 땅에 박힘
local SLAM = W(REST, {
	Root = { 0, -0.9, -0.6, 0, -8, 0 },
	Torso = { -34, 0, 0 },
	Head = { 22, 4, 0 },
	RArm = { 80, 24, 0 },
	LArm = { 80, -24, 0 },
	RLeg = { 42, 0, 14 },
	LLeg = { -34, 0, -14 },
	-- 끝이 바닥에 닿게(옆에서 본 각 ≈ 60°)
	W = { 0, 0, 0, -76, 0, 0 },
})
-- 칼을 앞으로 겨눈 중단 자세(두 손)
local MID = W(REST, {
	Root = { 0, -0.4, 0, 0, -8, 0 },
	Torso = { -8, 0, 0 },
	Head = { 8, 6, 0 },
	RArm = { 70, 26, 0 },
	LArm = { 70, -26, 0 },
	RLeg = { 22, 0, 14 },
	LLeg = { -20, 0, -14 },
	W = { 0, 0, 0, -50, 0, 0 },
})

return {
	Stance = REST,

	-- 대기: 깊고 느린 숨. 들숨에 어깨가 오르며 대검이 어깨 위에서 들썩인다
	Idle = {
		Duration = 3.9,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", REST),
			K(1.82, "sineInOut", REST, { Root = { 0, -0.2, 0, 0, -12, 0 }, Torso = { -1, 0, 0 }, Head = { 2, 10, 0 }, RArm = { 56, 18, 24 }, LArm = { 14, 0, -18 }, W = { 0.55, 0, 0, 64, 0, 0 } }),
			K(2.73, "sineInOut", REST, { Root = { 0, -0.3, 0, 0, -12, 0 }, Torso = { -7, 0, 0 }, Head = { 8, 14, 0 } }),
		},
	},

	-- 들림: 축 늘어져 대검 무게에 끌려 내려간다. 칼끝이 아래로 늘어지고 천천히 시계추처럼 흔들린다
	Held = {
		Duration = 2.4,
		Loop = true,
		Keys = {
			{ t = 0, e = "sineInOut", Root = { 0, 0, 0, 6, -12, 3 }, Torso = { -10, 0, 0 }, Head = { -22, 0, 0 }, RArm = { -4, 0, 4 }, LArm = { -2, 0, -6 }, RLeg = { 2, 0, 3 }, LLeg = { -4, 0, -3 }, W = { 0, 0, 0, -86, 0, 0 } },
			{ t = 1.2, e = "sineInOut", Root = { 0, 0, 0, -6, -12, -3 }, Torso = { -8, 0, 0 }, Head = { -18, 6, 0 }, RArm = { 4, 0, 4 }, LArm = { 4, 0, -6 }, RLeg = { -4, 0, 3 }, LLeg = { 2, 0, -3 }, W = { 0, 0, 0, -94, 0, 0 } },
		},
	},

	-- 내려놓임: 쿵 — 깊게 주저앉으며 대검을 앞 땅에 꽂고(충격파), 천천히 일어나 다시 어깨에 멘다
	Drop = {
		Duration = 1.3,
		BlendIn = 0.03,
		Keys = {
			{ t = 0, Root = { 0, 0.3, 0, 0, -12, 0 }, Torso = { -10, 0, 0 }, Head = { -10, 0, 0 }, RArm = { 90, 24, 0 }, LArm = { 90, -24, 0 }, RLeg = { 4, 0, 6 }, LLeg = { -4, 0, -6 }, W = { 0, 0, 0, -178, 0, 0 } },
			K(0.08, "quadIn", SLAM, { Root = { 0, -1.1, -0.2, 0, -8, 0 }, Torso = { -20, 0, 0 }, RArm = { 76, 24, 0 }, LArm = { 76, -24, 0 }, W = { 0, 0, 0, -166, 0, 0 }, RLeg = { 30, 0, 18 }, LLeg = { -30, 0, -18 } }),
			K(0.5, "sineOut", SLAM, { Root = { 0, -1.0, -0.2, 0, -8, 0 }, Torso = { -18, 0, 0 }, RArm = { 76, 24, 0 }, LArm = { 76, -24, 0 }, W = { 0, 0, 0, -166, 0, 0 }, RLeg = { 30, 0, 18 }, LLeg = { -30, 0, -18 } }),
			K(0.9, "cubicInOut", REST, { RArm = { 70, 20, 20 }, W = { 0.3, 0, 0, -40, 0, 0 } }),
			K(1.3, "sineInOut", REST),
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
			K(0.05, "expoOut", REST, { Root = { 0, -0.35, 0.3, 0, -10, 0 }, Torso = { 6, 4, 0 }, Head = { 14, 14, 0 }, LArm = { 20, 0, -30 } }),
			K(0.3, "sineOut", REST, { Root = { 0, -0.32, 0.2, 0, -12, 0 }, Torso = { -10, 0, 0 }, Head = { -4, 10, 0 } }),
			K(0.6, "sineInOut", REST),
		},
		Events = { { t = 0.05, k = "Fx", n = "MassAbsorb" } },
	},

	-- 방어: 대검을 앞에 세워 땅에 꽂고 두 손으로 버틴다(칼 면이 벽)
	Guard = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, REST),
			K(0.1, "expoOut", MID, { Root = { 0, -0.55, 0.15, 0, -2, 0 }, RArm = { 74, 22, 0 }, LArm = { 74, -22, 0 }, W = { 0, 0, 0, -164, 90, 0 }, Torso = { -4, 0, 0 } }),
			K(0.22, "sineOut", MID, { Root = { 0, -0.6, 0.35, 0, -2, 0 }, RArm = { 76, 22, 0 }, LArm = { 76, -22, 0 }, W = { 0, 0, 0, -164, 90, 0 }, Torso = { -8, 0, 0 } }),
			K(0.75, "cubicInOut", REST),
		},
		Events = { { t = 0.1, k = "Fx", n = "GravityWall" } },
	},

	-- 회피(성공 = 쳐냄): 검 면으로 옆으로 쓸어 공격을 흘리고, 무게를 싣고 한 걸음 비킨다
	Dodge = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, REST),
			K(0.08, "quadOut", MID, { Root = { 0.2, -0.45, 0, 0, 10, 0 }, RArm = { 80, 50, 10 }, LArm = { 80, 0, 0 }, W = { 0, 0, 0, -70, 90, 0 } }),
			K(0.16, "expoOut", MID, { Root = { -0.5, -0.5, 0.2, 0, -30, 0 }, Torso = { -10, -20, 0 }, RArm = { 76, -30, 20 }, LArm = { 76, -60, 0 }, W = { 0, 0, 0, -70, 90, 0 } }),
			K(0.4, "sineOut", MID, { Root = { -0.6, -0.48, 0.2, 0, -30, 0 }, Torso = { -8, -20, 0 }, RArm = { 72, -34, 22 }, LArm = { 72, -60, 0 }, W = { 0, 0, 0, -70, 90, 0 } }),
			K(0.8, "cubicInOut", REST),
		},
		Events = {
			{ t = 0.1, k = "Trail", on = true },
			{ t = 0.14, k = "Fx", n = "Deflect" },
			{ t = 0.4, k = "Trail", on = false },
		},
	},

	Skills = {
		-- 붕괴: 두 손으로 치켜든 대검 위에 중력이 뭉친다(떨림) → 한 칸 내딛으며 온몸으로 내려친다
		Collapse = {
			Duration = 2.2,
			Keys = {
				K(0, nil, REST),
				K(0.35, "cubicInOut", HIGH),
				K(0.6, "sineInOut", HIGH, { Root = { 0.04, -0.28, 0.25, 0, -8, 0 }, Torso = { 14, 0, 0 }, W = { 0, 0, 0, -44, 0, 0 } }),
				K(0.72, "sineInOut", HIGH, { Root = { -0.04, -0.3, 0.26, 0, -8, 0 }, Torso = { 14, 0, 0 }, W = { 0, 0, 0, -44, 0, 0 } }),
				K(0.84, "sineInOut", HIGH, { Root = { 0.04, -0.32, 0.28, 0, -8, 0 }, Torso = { 16, 0, 0 }, W = { 0, 0, 0, -46, 0, 0 } }),
				K(0.96, "sineInOut", HIGH, { Root = { -0.03, -0.34, 0.3, 0, -8, 0 }, Torso = { 17, 0, 0 }, W = { 0, 0, 0, -48, 0, 0 } }),
				K(1.08, "sineInOut", HIGH, { Root = { 0, -0.36, 0.32, 0, -8, 0 }, Torso = { 18, 0, 0 }, W = { 0, 0, 0, -50, 0, 0 } }),
				K(1.18, "expoOut", SLAM),
				K(1.6, "linear", SLAM, { Root = { 0, -0.86, -0.6, 0, -8, 0 } }),
				K(1.9, "cubicInOut", MID),
				K(2.2, "sineInOut", REST),
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

		-- 붕괴 차징(첫 사용 = 피해 없음): 대검을 치켜들어 중력을 모으고, 적을 끌어당긴 채 버틴다
		CollapseCharge = {
			Duration = 1.7,
			Keys = {
				K(0, nil, REST),
				K(0.35, "cubicInOut", HIGH),
				K(0.6, "sineInOut", HIGH, { Root = { 0.04, -0.28, 0.25, 0, -8, 0 }, Torso = { 14, 0, 0 }, W = { 0, 0, 0, -44, 0, 0 } }),
				K(0.75, "sineInOut", HIGH, { Root = { -0.04, -0.3, 0.26, 0, -8, 0 }, Torso = { 15, 0, 0 }, W = { 0, 0, 0, -45, 0, 0 } }),
				K(0.9, "sineInOut", HIGH, { Root = { 0.04, -0.32, 0.28, 0, -8, 0 }, Torso = { 16, 0, 0 }, W = { 0, 0, 0, -46, 0, 0 } }),
				-- 끌어당기는 손짓: 왼손을 앞으로 뻗어 움켜쥔다
				K(1.1, "expoOut", MID, { Root = { 0, -0.5, 0.2, 0, -8, 0 }, RArm = { 110, 20, 10 }, W = { 0, 0, 0, -90, 0, 0 }, LArm = { 90, -10, 0 }, Head = { 14, 6, 0 } }),
				K(1.35, "sineOut", MID, { Root = { 0, -0.52, 0.35, 0, -8, 0 }, RArm = { 110, 20, 10 }, W = { 0, 0, 0, -90, 0, 0 }, LArm = { 70, 10, 0 }, Head = { 14, 6, 0 } }),
				K(1.7, "sineInOut", REST),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Implode" },
				{ t = 1.1, k = "Fx", n = "Pull" },
				{ t = 1.12, k = "Shake", a = 0.25, d = 0.3 },
			},
		},

		-- 특이점: 대검으로 하늘을 가리키면 대상 위에 거대한 에너지 검이 나타나 — 내려 긋는 손짓에 떨어져 꽂힌다
		Singularity = {
			Duration = 2.2,
			Keys = {
				K(0, nil, REST),
				K(0.4, "cubicOut", REST, { Root = { 0, -0.2, 0, 0, -20, 0 }, Torso = { 10, -8, 0 }, Head = { 20, 14, 0 }, RArm = { 178, 10, 10 }, W = { 0, 0, 0, -88, 0, 0 }, LArm = { 40, 0, -40 } }),
				K(0.95, "sineInOut", REST, { Root = { 0, -0.18, 0, 0, -20, 0 }, Torso = { 12, -8, 0 }, Head = { 22, 14, 0 }, RArm = { 180, 10, 10 }, W = { 0, 0, 0, -90, 0, 0 }, LArm = { 44, 0, -44 } }),
				-- 내려 긋기(명령)
				K(1.1, "expoOut", REST, { Root = { 0, -0.5, -0.2, 0, -6, 0 }, Torso = { -22, 6, 0 }, Head = { 16, 6, 0 }, RArm = { 70, 20, 10 }, W = { 0, 0, 0, -84, 0, 0 }, LArm = { 20, 0, -50 }, RLeg = { 30, 0, 16 }, LLeg = { -24, 0, -16 } }),
				K(1.6, "sineOut", REST, { Root = { 0, -0.46, -0.2, 0, -6, 0 }, Torso = { -18, 6, 0 }, Head = { 12, 6, 0 }, RArm = { 68, 20, 10 }, W = { 0, 0, 0, -82, 0, 0 }, LArm = { 18, 0, -46 }, RLeg = { 30, 0, 16 }, LLeg = { -24, 0, -16 } }),
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

		-- 낙하: 짧고 빠른 가로베기 — 퀘이사치고 가벼운 한 수(그래도 무겁다)
		Infall = {
			Duration = 1.3,
			Keys = {
				K(0, nil, REST),
				K(0.22, "cubicOut", REST, { Root = { 0, -0.5, 0.2, 0, 20, 0 }, Torso = { -8, 30, 0 }, Head = { 6, -16, 0 }, RArm = { 90, 70, 30 }, LArm = { 90, 40, 0 }, W = { 0, 0, 0, -84, 90, 0 }, RLeg = { 20, 0, 14 }, LLeg = { -18, 0, -14 } }),
				K(0.34, "expoOut", REST, { Root = { 0, -0.62, -0.3, 0, -40, 0 }, Torso = { -14, -40, 0 }, Head = { 10, 30, 0 }, RArm = { 88, -70, 20 }, LArm = { 88, -90, 0 }, W = { 0, 0, 0, -84, 90, 0 }, RLeg = { 34, 0, 14 }, LLeg = { -30, 0, -14 } }),
				K(0.7, "sineOut", REST, { Root = { 0, -0.58, -0.3, 0, -44, 0 }, Torso = { -12, -44, 0 }, Head = { 8, 32, 0 }, RArm = { 84, -76, 22 }, LArm = { 84, -94, 0 }, W = { 0, 0, 0, -84, 90, 0 }, RLeg = { 32, 0, 14 }, LLeg = { -28, 0, -14 } }),
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
				K(0.2, "backOut", MID, { Root = { 0, -0.6, 0.15, 0, -2, 0 }, RArm = { 74, 22, 0 }, LArm = { 74, -22, 0 }, W = { 0, 0, 0, -164, 90, 0 } }),
				K(0.8, "sineInOut", MID, { Root = { 0, -0.62, 0.15, 0, -2, 0 }, RArm = { 74, 22, 0 }, LArm = { 74, -22, 0 }, W = { 0, 0, 0, -164, 90, 0 } }),
				K(1.1, "sineInOut", REST),
			},
			Events = { { t = 0.2, k = "Fx", n = "GravityWall" } },
		},

		-- 명상: 대검을 앞에 꽂고 손잡이에 두 손을 얹은 채 고개를 숙인다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, REST),
				K(0.4, "cubicInOut", REST, { Root = { 0, -0.3, 0, 0, -4, 0 }, Torso = { -4, 0, 0 }, Head = { -26, 0, 0 }, RArm = { 50, 24, 0 }, LArm = { 50, -24, 0 }, W = { 0, 0, 0, -140, 0, 0 }, RLeg = { 4, 0, 12 }, LLeg = { -4, 0, -12 } }),
				K(1.5, "sineInOut", REST, { Root = { 0, -0.34, 0, 0, -4, 0 }, Torso = { -2, 0, 0 }, Head = { -22, 0, 0 }, RArm = { 50, 24, 0 }, LArm = { 50, -24, 0 }, W = { 0, 0, 0, -140, 0, 0 }, RLeg = { 4, 0, 12 }, LLeg = { -4, 0, -12 } }),
				K(2.0, "sineInOut", REST),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
