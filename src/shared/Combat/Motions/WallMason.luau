--!strict
--[[
	월 메이슨 — 망치와 정을 든 석공. (2026-09-28)

	성격: 느긋한 장인. 곧게 서서 망치를 어깨에 걸치고, 틈만 나면 정을 톡톡 두드려 본다.
	      움직임은 **박자**가 있다(톡-톡-쾅). 막을 때는 땅에서 돌벽을 세우고, 피할 때는 옆으로 굴러 일어난다.
	무기 종류: Hammer1H (WeaponDefinitions.MasonHammer: W = 오른손 망치, O = 왼손 정)
	  망치 방향 = 팔 X + 90 + 숙임(옆에서 본 각). 어깨에 걸치기 ≈ 210. 망치 머리 치는 면 = 앞(-Z)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 곧게 선 장인: 망치는 오른 어깨, 정은 왼손에 들고 앞을 겨눈다
local WORK = {
	Root = { 0, -0.08, 0, 0, -18, 0 },
	Torso = { 4, 0, 0 },
	Head = { 0, 14, 0 },
	RArm = { 40, 12, 22 },
	LArm = { 52, -20, 0 },
	RLeg = { 6, 0, 8 },
	LLeg = { -6, 0, -8 },
	W = { 0.4, 0, 0, 80, 0, 0 },
	O = { 0, 0, 0, -50, 0, 0 },
}
-- 정을 앞에 대고 망치를 치켜든 자세(정 다듬기)
local SET = W(WORK, {
	Root = { 0, -0.35, 0, 0, -8, 0 },
	Torso = { -16, 0, 0 },
	Head = { 12, 8, 0 },
	LArm = { 96, -24, 0 },
	O = { 0, 0, 0, -96, 0, 0 },
	RArm = { 150, 16, 10 },
	W = { 0, 0, 0, -60, 0, 0 },
	RLeg = { 24, 0, 8 },
	LLeg = { -18, 0, -8 },
})
-- 정 끝을 때린 순간
local TAP = W(SET, { RArm = { 98, 22, 4 }, W = { 0, 0, 0, -30, 0, 0 }, Torso = { -20, 0, 0 } })

return {
	Stance = WORK,

	-- 대기: 정을 들어 톡, 톡 두드려 보고 고개를 갸웃한 뒤 망치를 다시 어깨에 멘다
	Idle = {
		Duration = 4.42,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", WORK),
			K(0.65, "cubicInOut", WORK, { LArm = { 70, -24, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RArm = { 76, 20, 6 }, W = { 0, 0, 0, 10, 0, 0 }, Head = { -12, 10, 0 }, Torso = { -4, 0, 0 } }),
			K(0.806, "expoOut", WORK, { LArm = { 70, -24, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RArm = { 66, 22, 4 }, W = { 0, 0, 0, 22, 0, 0 }, Head = { -14, 10, 0 }, Torso = { -5, 0, 0 } }),
			K(1.04, "sineOut", WORK, { LArm = { 70, -24, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RArm = { 78, 20, 6 }, W = { 0, 0, 0, 8, 0, 0 }, Head = { -12, 10, 0 }, Torso = { -4, 0, 0 } }),
			K(1.17, "expoOut", WORK, { LArm = { 70, -24, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RArm = { 66, 22, 4 }, W = { 0, 0, 0, 22, 0, 0 }, Head = { -14, 10, 0 }, Torso = { -5, 0, 0 } }),
			K(1.82, "sineInOut", WORK, { LArm = { 70, -24, 0 }, O = { 0, 0, 0, -70, 0, 0 }, RArm = { 70, 20, 6 }, W = { 0, 0, 0, 16, 0, 0 }, Head = { -8, 20, -12 }, Torso = { -3, 0, 0 } }),
			K(2.86, "cubicInOut", WORK),
		},
	},

	-- 들림: 난간에 걸터앉은 듯 다리를 앞으로 내밀어 꼬고, 느긋하게 주위를 둘러본다
	Held = {
		Duration = 3.0,
		Loop = true,
		Keys = {
			K(0, "sineInOut", WORK, { Root = { 0, 0.2, 0, 0, -18, 0 }, Torso = { 8, 0, 0 }, Head = { 6, 30, 0 }, RLeg = { 70, 0, -6 }, LLeg = { 80, 0, 6 } }),
			K(1.5, "sineInOut", WORK, { Root = { 0, 0.25, 0, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 4, -20, 0 }, RLeg = { 80, 0, -6 }, LLeg = { 66, 0, 6 } }),
		},
	},

	-- 내려놓임: 쿵 발을 딛고, 망치로 발밑 돌을 톡 쳐 보고(불꽃), 끄덕
	Drop = {
		Duration = 1.1,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, WORK, { Root = { 0, 0.4, 0, 0, -18, 0 }, RLeg = { 60, 0, -6 }, LLeg = { 70, 0, 6 } }),
			K(0.08, "quadIn", WORK, { Root = { 0, -0.35, 0, 0, -18, 0 }, RLeg = { 18, 0, 10 }, LLeg = { -14, 0, -10 } }),
			K(0.3, "cubicOut", WORK, { Root = { 0, -0.5, -0.1, 0, -18, 0 }, Torso = { -34, 0, 0 }, Head = { -10, 10, 0 }, RArm = { 110, 10, 10 }, W = { 0, 0, 0, -70, 0, 0 }, RLeg = { 20, 0, 10 }, LLeg = { -16, 0, -10 } }),
			K(0.4, "expoOut", WORK, { Root = { 0, -0.55, -0.1, 0, -18, 0 }, Torso = { -38, 0, 0 }, Head = { -14, 10, 0 }, RArm = { 50, 10, 10 }, W = { 0, 0, 0, -40, 0, 0 }, RLeg = { 20, 0, 10 }, LLeg = { -16, 0, -10 } }),
			K(0.7, "sineInOut", WORK, { Head = { -10, 14, 0 } }),
			K(0.85, "sineInOut", WORK, { Head = { 6, 14, 0 } }),
			K(1.1, "sineInOut", WORK),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "Stomp" },
			{ t = 0.4, k = "Fx", n = "GroundTap" },
		},
	},

	-- 피격: 뒤로 휘청이고 망치 든 손을 털며 투덜댄다
	Hit = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, WORK),
			K(0.05, "expoOut", WORK, { Root = { 0, -0.2, 0.7, 0, -24, 0 }, Torso = { 14, -6, 0 }, Head = { 18, 10, 0 }, RArm = { 80, -20, 50 }, LArm = { 70, -10, -30 } }),
			K(0.3, "sineOut", WORK, { Root = { 0, -0.15, 0.6, 0, -24, 0 }, Torso = { 4, 0, 0 }, RArm = { 50, 0, 40 }, W = { 0, 0, 0, 40, 0, 0 } }),
			K(0.42, "sineInOut", WORK, { Root = { 0, -0.15, 0.5, 0, -22, 0 }, RArm = { 50, 0, 20 }, W = { 0, 0, 0, 20, 0, 0 } }),
			K(0.75, "sineInOut", WORK),
		},
	},

	-- 방어: 망치로 땅을 쳐 앞에 돌벽을 세우고, 그 뒤에서 팔뚝으로 버틴다
	Guard = {
		Duration = 0.8,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, WORK),
			K(0.06, "expoOut", WORK, { Root = { 0, -0.5, 0.2, 0, -10, 0 }, Torso = { -20, 0, 0 }, RArm = { 60, 20, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 100, -40, -10 }, O = { 0, 0, 0, 40, 0, 0 } }),
			K(0.24, "sineOut", WORK, { Root = { 0, -0.55, 0.4, 0, -10, 0 }, Torso = { -14, 0, 0 }, RArm = { 62, 20, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 104, -44, -10 }, O = { 0, 0, 0, 40, 0, 0 } }),
			K(0.8, "sineInOut", WORK),
		},
		Events = { { t = 0.04, k = "Fx", n = "StoneWall" } },
	},

	-- 회피: 옆으로 몸을 던져 한 바퀴 구르고 곧장 일어난다
	Dodge = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, WORK),
			K(0.06, "quadOut", WORK, { Root = { 0.2, -0.6, 0, 0, -18, 0 }, Torso = { -20, 0, 0 } }),
			K(0.24, "linear", WORK, { Root = { -1.0, -1.2, 0.6, 0, -18, 180 }, Torso = { -30, 0, 0 }, RArm = { 90, 30, 0 }, LArm = { 90, -30, 0 }, RLeg = { 60, 0, 0 }, LLeg = { 60, 0, 0 } }),
			K(0.4, "cubicOut", WORK, { Root = { -1.8, -0.6, 1.0, 0, -18, 360 }, Torso = { -20, 0, 0 }, RLeg = { 30, 0, 14 }, LLeg = { -20, 0, -14 } }),
			K(0.75, "sineInOut", WORK, { Root = { -0.6, -0.08, 0.3, 0, -18, 360 } }),
		},
		Events = { { t = 0.3, k = "Fx", n = "RollDust" } },
	},

	Skills = {
		-- 정 다듬기: 다가가 정을 대상에 대고 — 톡, 톡, 쾅
		ChiselWork = {
			Duration = 1.6,
			Keys = {
				K(0, nil, WORK),
				K(0.2, "cubicOut", SET),
				K(0.36, "expoOut", TAP),
				K(0.5, "cubicOut", SET, { RArm = { 140, 16, 10 } }),
				K(0.62, "expoOut", TAP),
				K(0.82, "cubicOut", SET, { RArm = { 176, 16, 10 }, W = { 0, 0, 0, -80, 0, 0 }, Torso = { -8, 0, 0 } }),
				K(0.92, "expoOut", TAP, { Torso = { -26, 0, 0 }, Root = { 0, -0.5, -0.1, 0, -8, 0 } }),
				K(1.2, "sineOut", TAP, { Torso = { -24, 0, 0 }, Root = { 0, -0.48, -0.1, 0, -8, 0 } }),
				K(1.6, "sineInOut", WORK),
			},
			Events = {
				{ t = 0.05, k = "Dash", to = "Target", gap = 3, d = 0.18 },
				{ t = 0.36, k = "Fx", n = "ChiselTap" },
				{ t = 0.62, k = "Fx", n = "ChiselTap" },
				{ t = 0.84, k = "Trail", on = true },
				{ t = 0.92, k = "Hit", i = 1, fx = "ChiselHit" },
				{ t = 0.93, k = "Stop", d = 0.09 },
				{ t = 0.94, k = "Shake", a = 0.35, d = 0.25 },
				{ t = 1.0, k = "Trail", on = false },
				{ t = 1.25, k = "Dash", to = "Home", d = 0.25 },
			},
		},

		-- 뒷벽 허물기: 망치를 등 뒤까지 크게 돌려 땅을 내려치면, 금이 대상과 그 뒤를 꿰뚫고 달려간다
		BreakBackWall = {
			Duration = 1.7,
			Keys = {
				K(0, nil, WORK),
				K(0.35, "cubicOut", WORK, { Root = { 0, -0.2, 0.3, 0, -30, 0 }, Torso = { 14, 20, 0 }, Head = { 8, -6, 0 }, RArm = { 200, 10, 20 }, W = { 0, 0, 0, -40, 0, 0 }, LArm = { 70, -30, -30 }, RLeg = { 4, 0, 8 }, LLeg = { -16, 0, -8 } }),
				K(0.48, "expoOut", WORK, { Root = { 0, -0.8, -0.4, 0, -8, 0 }, Torso = { -42, -6, 0 }, Head = { 20, 10, 0 }, RArm = { 70, 10, 6 }, W = { 0, 0, 0, -95, 0, 0 }, LArm = { 20, -20, -30 }, RLeg = { 40, 0, 10 }, LLeg = { -30, 0, -10 } }),
				K(0.95, "sineOut", WORK, { Root = { 0, -0.76, -0.4, 0, -8, 0 }, Torso = { -38, -6, 0 }, Head = { 18, 10, 0 }, RArm = { 68, 10, 6 }, W = { 0, 0, 0, -95, 0, 0 }, LArm = { 20, -20, -30 }, RLeg = { 38, 0, 10 }, LLeg = { -28, 0, -10 } }),
				K(1.7, "sineInOut", WORK),
			},
			Events = {
				{ t = 0.36, k = "Trail", on = true },
				{ t = 0.48, k = "Fx", n = "WallBreakWave" },
				{ t = 0.49, k = "Stop", d = 0.1 },
				{ t = 0.5, k = "Shake", a = 0.5, d = 0.35 },
				{ t = 0.62, k = "Trail", on = false },
				{ t = 0.72, k = "Hit", i = 1, fx = "Rubble" },
			},
		},

		-- 축성: 망치로 땅을 세 번(쿵·쿵·쿵) — 금빛 돌기둥이 둘레에 솟는다
		Consecrate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, WORK),
				K(0.25, "cubicOut", WORK, { Root = { 0, -0.3, 0, 0, -18, 0 }, Torso = { -6, 0, 0 }, RArm = { 160, 10, 10 }, W = { 0, 0, 0, -60, 0, 0 } }),
				K(0.35, "expoOut", WORK, { Root = { 0, -0.6, -0.1, 0, -18, 0 }, Torso = { -34, 0, 0 }, RArm = { 60, 10, 10 }, W = { 0, 0, 0, -80, 0, 0 } }),
				K(0.6, "cubicOut", WORK, { Root = { 0, -0.3, 0, 0, -18, 0 }, Torso = { -6, 0, 0 }, RArm = { 160, 10, 10 }, W = { 0, 0, 0, -60, 0, 0 } }),
				K(0.7, "expoOut", WORK, { Root = { 0, -0.6, -0.1, 0, -18, 0 }, Torso = { -34, 0, 0 }, RArm = { 60, 10, 10 }, W = { 0, 0, 0, -80, 0, 0 } }),
				K(0.95, "cubicOut", WORK, { Root = { 0, -0.2, 0.1, 0, -18, 0 }, Torso = { 6, 0, 0 }, RArm = { 185, 10, 10 }, W = { 0, 0, 0, -60, 0, 0 }, Head = { 14, 14, 0 } }),
				K(1.06, "expoOut", WORK, { Root = { 0, -0.75, -0.1, 0, -18, 0 }, Torso = { -40, 0, 0 }, RArm = { 60, 10, 10 }, W = { 0, 0, 0, -85, 0, 0 }, Head = { 10, 14, 0 }, RLeg = { 26, 0, 10 }, LLeg = { -20, 0, -10 } }),
				K(1.5, "sineOut", WORK, { Root = { 0, -0.72, -0.1, 0, -18, 0 }, Torso = { -36, 0, 0 }, RArm = { 60, 10, 10 }, W = { 0, 0, 0, -85, 0, 0 }, Head = { 10, 14, 0 }, RLeg = { 26, 0, 10 }, LLeg = { -20, 0, -10 } }),
				K(2.0, "sineInOut", WORK),
			},
			Events = {
				{ t = 0.35, k = "Fx", n = "GoldTap" },
				{ t = 0.7, k = "Fx", n = "GoldTap" },
				{ t = 1.06, k = "Fx", n = "Consecrate" },
				{ t = 1.07, k = "Shake", a = 0.35, d = 0.3 },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, WORK),
				K(0.12, "expoOut", WORK, { Root = { 0, -0.5, 0.2, 0, -10, 0 }, Torso = { -20, 0, 0 }, RArm = { 60, 20, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 100, -40, -10 }, O = { 0, 0, 0, 40, 0, 0 } }),
				K(0.8, "sineInOut", WORK, { Root = { 0, -0.52, 0.3, 0, -10, 0 }, Torso = { -16, 0, 0 }, RArm = { 60, 20, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 102, -42, -10 }, O = { 0, 0, 0, 40, 0, 0 } }),
				K(1.1, "sineInOut", WORK),
			},
			Events = { { t = 0.1, k = "Fx", n = "StoneWall" } },
		},

		-- 명상: 망치를 내려놓듯 짚고 쪼그려 앉아 정 끝을 들여다본다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, WORK),
				K(0.4, "cubicInOut", WORK, { Root = { 0, -1.1, 0, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { -20, 10, 0 }, RArm = { 30, 10, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 70, -20, 0 }, O = { 0, 0, 0, -10, 0, 0 }, RLeg = { 90, 0, 16 }, LLeg = { 90, 0, -16 } }),
				K(1.5, "sineInOut", WORK, { Root = { 0, -1.1, 0, 0, -18, 0 }, Torso = { -8, 0, 0 }, Head = { -16, 14, 0 }, RArm = { 30, 10, 10 }, W = { 0, 0, 0, -60, 0, 0 }, LArm = { 74, -20, 0 }, O = { 0, 0, 0, -10, 0, 0 }, RLeg = { 90, 0, 16 }, LLeg = { 90, 0, -16 } }),
				K(2.0, "sineInOut", WORK),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
