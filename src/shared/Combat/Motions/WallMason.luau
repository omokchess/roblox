--!strict
--[[
	월 메이슨 — 망치와 정을 든 석공. (2026-09-28, 자세 다시 2026-10-02)

	성격: 느긋한 장인. 틈만 나면 정을 보이지 않는 돌면에 대고 망치로 두드려 본다.
	      움직임은 **박자**가 있다(톡-톡-쾅). 막을 때는 땅을 쳐 돌벽을 세우고, 피할 때는 옆으로 굴러 일어난다.
	참고: 석공 정 작업 — 정은 가운데를 쥐고 날을 돌면에 대며, 망치는 머리 가까이 쥐고 정 머리를 톡톡 친다.
	      세게 휘두르지 않고 손목으로 짧게, 마지막 한 번만 팔을 들어 쾅.
	무기 종류: Hammer1H (WeaponDefinitions.MasonHammer: W = 오른손 망치, O = 왼손 정)
	      정은 가슴 앞에 가로로(날은 왼쪽 아래 돌면, 머리는 오른쪽 망치 쪽), 망치는 목 가까이(자루 y 1.2, W 자리 y -1.21)
	      세워 쥐고 옆으로 톡 친다. 정을 앞으로 겨누고 축을 따라 치면 망치 머리(면~뒷날 2.0)가 곧은 R6 팔 때문에
	      몸을 파고들어서 이 배치를 골랐다. 톡 키(TAP)에서 망치 타격면(무기 (0, 2.2, -0.8))이 정 머리 윗면
	      (정 (0, 0.71, 0))에 닿고 면이 정 축을 따라 날 쪽을 보게, 땅 치기 키에서는 면이 땅(-3)에 닿게
	      tools/combat/design/mason_gen.py(+ mason_lat.py, mason_search.py)로 팔·무기 각을 구했다.
	      예비 자세는 망치 자기 축으로 손목을 젖혀 만든다. 큰 동작(땅 치기)에서는 손이 자루 아래(y 0.5)로 미끄러진다.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 톡: 왼발 앞, 정을 가슴 앞에 가로로 들고(날은 왼쪽 아래), 세워 쥔 망치 면이 오른쪽에서 정 머리에 닿음
local TAP = { Root = { 0, -0.25, 0, 0, -30, 0 }, Torso = { -10, 0, 0 }, Head = { -18, 20, 0 }, RArm = { 42.3, 9.4, 5.8 }, LArm = { 62.9, -26.2, 22.4 }, RLeg = { -14, 0, 10 }, LLeg = { 22, 0, -10 }, W = { -0.01, -1.21, 0, -26, 71.7, 63 }, O = { 0, 0, 0, -43.9, 0, -44.1 } }
-- 톡 예비(대기 기본): 손목만 젖혀 망치 머리를 오른쪽으로 / 쾅 예비: 팔을 들어 망치를 오른쪽 뒤로 크게 젖힘
local LIFT = { Root = { 0, -0.25, 0, 0, -30, 0 }, Torso = { -10, 0, 0 }, Head = { -18, 20, 0 }, RArm = { 42.3, 9.4, 5.8 }, LArm = { 62.9, -26.2, 22.4 }, RLeg = { -14, 0, 10 }, LLeg = { 22, 0, -10 }, W = { -0.01, -1.21, 0.01, -74.8, 110.2, 114.3 }, O = { 0, 0, 0, -43.9, 0, -44.1 } }
local HIGH = { Root = { 0, -0.25, 0, 0, -30, 0 }, Torso = { -10, 0, 0 }, Head = { -18, 20, 0 }, RArm = { 82.3, -10.6, 5.8 }, LArm = { 62.9, -26.2, 22.4 }, RLeg = { -14, 0, 10 }, LLeg = { 22, 0, -10 }, W = { -0.01, -1.2, 0.01, -55.9, 153.9, 99.1 }, O = { 0, 0, 0, -43.9, 0, -44.1 } }
-- 어깨에 멤(들림): 망치 자루 끝을 쥐고 머리를 오른 어깨 뒤에 걸침, 정은 왼손에 늘어뜨림
local SHOULDER = { Root = { 0, -0.05, 0, 0, -18, 0 }, Torso = { 4, 0, 0 }, Head = { 0, 14, 0 }, RArm = { 44, 4, 4 }, LArm = { 8, 0, -6 }, RLeg = { 6, 0, 8 }, LLeg = { -6, 0, -8 }, W = { 0, 0, 0, 88.6, -21.8, 7.9 }, O = { 0, 0, 0, 70.6, 0, 5.7 } }
-- 땅 톡: 숙여 앞 땅을 망치 면으로 친 끝 / 땅 치기 예비(머리 위로 치켜듦)
local GTAP = { Root = { 0, -0.75, -0.1, 0, -18, 0 }, Torso = { -40, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 41, 10, 0 }, LArm = { 30, -20, -20 }, RLeg = { 30, 0, 10 }, LLeg = { -24, 0, -10 }, W = { -0.01, -0.51, -0.03, -1.4, -6.4, 71.3 }, O = { 0, 0, 0, 41, 0, 19.3 } }
local GHIGH = { Root = { 0, -0.25, 0, 0, -18, 0 }, Torso = { -6, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 131, 10, 0 }, LArm = { 30, -20, -20 }, RLeg = { 30, 0, 10 }, LLeg = { -24, 0, -10 }, W = { -0.01, -0.53, -0.02, 12.6, 31.3, 68.1 }, O = { 0, 0, 0, 41, 0, 19.3 } }
-- 뒷벽 허물기: 망치를 등 뒤로 크게 젖힘(BACK) → 앞 땅을 내려친 끝(SLAM)
local BACK = { Root = { 0, -0.2, 0.3, 0, -30, 0 }, Torso = { 14, 20, 0 }, Head = { 8, -6, 0 }, RArm = { 200, 10, 20 }, LArm = { 70, -30, -30 }, RLeg = { 4, 0, 8 }, LLeg = { -16, 0, -8 }, W = { 0, 0, 0, 7.4, 0, 1.4 }, O = { 0, 0, 0, 85.4, 0, 24.3 } }
local SLAM = { Root = { 0, -0.85, -0.45, 0, -8, 0 }, Torso = { -44, -6, 0 }, Head = { 20, 10, 0 }, RArm = { 70.6, 16.2, -4.1 }, LArm = { 20, -20, -30 }, RLeg = { 40, 0, 10 }, LLeg = { -30, 0, -10 }, W = { -0, -0.5, -0, -28.2, -14.8, 79.2 }, O = { 0, 0, 0, 85.4, 0, 24.3 } }
-- 버팀(방어): 정 쥔 왼팔을 얼굴 앞에 세워 대고 웅크림, 망치는 낮게 준비
local BRACE = { Root = { 0, -0.55, 0.4, 0, -10, 0 }, Torso = { -14, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 50, 20, 10 }, LArm = { 111, -58.8, 2.9 }, RLeg = { 20, 0, 10 }, LLeg = { -16, 0, -10 }, W = { 0, 0, 0, -20.3, 0, 0.6 }, O = { 0, 0, 0, -8.4, 0, 1.4 } }
-- 명상: 쪼그려 앉아 망치 머리를 오른쪽 땅에 세워 짚고, 정 날을 눈앞에 들어 들여다봄
local SQUAT = { Root = { 0, -1.1, 0, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { -20, 10, 0 }, RArm = { 0.4, 8.5, -15.3 }, LArm = { 108.7, -38.1, 13 }, RLeg = { 90, 0, 16 }, LLeg = { 90, 0, -16 }, W = { -0.01, -0.51, 0, 9.9, -16.6, 19.7 }, O = { 0, 0, 0, -200.4, 0, -23.9 } }

-- 땅을 치며 왼팔은 버팀 자세로 들어 올린다(방어 첫 키)
local GUARD_HIT = { Root = GTAP.Root, Torso = { -30, 0, 0 }, Head = { -6, 10, 0 }, RArm = GTAP.RArm, LArm = BRACE.LArm, RLeg = GTAP.RLeg, LLeg = GTAP.LLeg, W = GTAP.W, O = BRACE.O }

return {
	Stance = LIFT,

	-- 대기: 톡-톡-쾅 — 손목으로 두 번 톡톡, 팔을 들어 쾅 한 번, 결을 들여다보며 고개를 갸웃한다
	Idle = {
		Duration = 4.42,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", LIFT),
			K(0.3, "quadIn", TAP),
			K(0.55, "sineOut", LIFT),
			K(0.85, "quadIn", TAP),
			K(1.3, "cubicOut", HIGH),
			K(1.6, "quadIn", TAP, { Root = { 0, -0.32, 0, 0, -30, 0 }, Torso = { -14, 0, 0 } }),
			K(1.9, "sineOut", TAP, { Root = { 0, -0.3, 0, 0, -30, 0 }, Torso = { -13, 0, 0 } }),
			K(2.5, "sineInOut", LIFT, { Head = { -26, 22, -12 } }),
			K(3.3, "sineInOut", LIFT, { Head = { -22, 6, 8 } }),
		},
	},

	-- 들림: 망치를 어깨에 걸친 채 난간에 걸터앉은 듯 다리를 앞으로 내밀어 꼬고, 느긋하게 주위를 둘러본다
	Held = {
		Duration = 3.0,
		Loop = true,
		Keys = {
			K(0, "sineInOut", SHOULDER, { Root = { 0, 0.2, 0, 0, -18, 0 }, Torso = { 8, 0, 0 }, Head = { 6, 30, 0 }, RLeg = { 70, 0, -6 }, LLeg = { 80, 0, 6 } }),
			K(1.5, "sineInOut", SHOULDER, { Root = { 0, 0.25, 0, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 4, -20, 0 }, RLeg = { 80, 0, -6 }, LLeg = { 66, 0, 6 } }),
		},
	},

	-- 내려놓임: 쿵 발을 딛고, 망치로 발밑 돌을 톡 쳐 보고(불꽃), 끄덕이며 정을 다시 댄다
	Drop = {
		Duration = 1.1,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, SHOULDER, { Root = { 0, 0.4, 0, 0, -18, 0 }, RLeg = { 60, 0, -6 }, LLeg = { 70, 0, 6 } }),
			K(0.08, "quadIn", SHOULDER, { Root = { 0, -0.35, 0, 0, -18, 0 }, RLeg = { 18, 0, 10 }, LLeg = { -14, 0, -10 } }),
			K(0.3, "cubicOut", GTAP, { Root = { 0, -0.55, -0.1, 0, -18, 0 }, Torso = { -28, 0, 0 }, RArm = { 90, 10, 0 } }),
			K(0.4, "expoOut", GTAP),
			K(0.7, "sineInOut", LIFT, { Head = { -26, 14, 0 } }),
			K(0.85, "sineInOut", LIFT, { Head = { -8, 14, 0 } }),
			K(1.1, "sineInOut", LIFT),
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
			K(0, nil, LIFT),
			K(0.05, "expoOut", LIFT, { Root = { 0, -0.2, 0.7, 0, -36, 0 }, Torso = { 14, -6, 0 }, Head = { 18, 10, 0 }, RArm = { 100, -10, 40 }, LArm = { 50, -10, -30 } }),
			K(0.3, "sineOut", LIFT, { Root = { 0, -0.15, 0.6, 0, -36, 0 }, Torso = { 4, 0, 0 }, Head = { 0, 20, 0 }, RArm = { 90, 0, 30 }, LArm = { 56, -20, 0 } }),
			K(0.42, "sineInOut", LIFT, { Root = { 0, -0.18, 0.5, 0, -32, 0 }, Torso = { -4, 0, 0 }, RArm = { 110, 6, 18 }, LArm = { 60, -24, 8 } }),
			K(0.75, "sineInOut", LIFT),
		},
	},

	-- 방어: 망치로 땅을 쳐 앞에 돌벽을 세우고, 그 뒤에서 정 쥔 팔뚝으로 버틴다
	Guard = {
		Duration = 0.8,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, LIFT),
			K(0.06, "expoOut", GUARD_HIT),
			K(0.24, "sineOut", BRACE),
			K(0.8, "sineInOut", LIFT),
		},
		Events = { { t = 0.04, k = "Fx", n = "StoneWall" } },
	},

	-- 회피: 옆으로 몸을 던져 한 바퀴 구르고 곧장 일어난다(연장은 가슴에 끌어안음)
	Dodge = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, LIFT),
			K(0.06, "quadOut", LIFT, { Root = { 0.2, -0.6, 0, 0, -30, 0 }, Torso = { -20, 0, 0 } }),
			K(0.24, "linear", LIFT, { Root = { -1.0, -1.2, 0.6, 0, -30, 180 }, Torso = { -30, 0, 0 }, RArm = { 90, 30, 0 }, LArm = { 90, -30, 0 }, RLeg = { 60, 0, 0 }, LLeg = { 60, 0, 0 } }),
			K(0.4, "cubicOut", LIFT, { Root = { -1.8, -0.6, 1.0, 0, -30, 360 }, Torso = { -20, 0, 0 }, RLeg = { 30, 0, 14 }, LLeg = { -20, 0, -14 } }),
			K(0.75, "sineInOut", LIFT, { Root = { -0.6, -0.25, 0.3, 0, -30, 360 } }),
		},
		Events = { { t = 0.3, k = "Fx", n = "RollDust" } },
	},

	Skills = {
		-- 정 다듬기: 다가가 정을 대상에 대고 — 톡, 톡, 쾅
		ChiselWork = {
			Duration = 1.6,
			Keys = {
				K(0, nil, LIFT),
				K(0.2, "cubicOut", LIFT, { Root = { 0, -0.3, -0.1, 0, -30, 0 }, Torso = { -14, 0, 0 } }),
				K(0.36, "quadIn", TAP, { Root = { 0, -0.3, -0.1, 0, -30, 0 }, Torso = { -14, 0, 0 } }),
				K(0.5, "cubicOut", LIFT, { Root = { 0, -0.3, -0.1, 0, -30, 0 }, Torso = { -14, 0, 0 } }),
				K(0.62, "quadIn", TAP, { Root = { 0, -0.3, -0.1, 0, -30, 0 }, Torso = { -14, 0, 0 } }),
				K(0.82, "cubicOut", HIGH, { Root = { 0, -0.2, 0, 0, -30, 0 }, Torso = { -6, 0, 0 } }),
				K(0.92, "expoOut", TAP, { Root = { 0, -0.45, -0.2, 0, -30, 0 }, Torso = { -18, 0, 0 } }),
				K(1.2, "sineOut", TAP, { Root = { 0, -0.43, -0.2, 0, -30, 0 }, Torso = { -17, 0, 0 } }),
				K(1.6, "sineInOut", LIFT),
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
				K(0, nil, LIFT),
				K(0.35, "cubicOut", BACK),
				K(0.48, "expoOut", SLAM),
				K(0.95, "sineOut", SLAM, { Root = { 0, -0.81, -0.45, 0, -8, 0 }, Torso = { -40, -6, 0 }, Head = { 18, 10, 0 } }),
				K(1.7, "sineInOut", LIFT),
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
				K(0, nil, LIFT),
				K(0.25, "cubicOut", GHIGH),
				K(0.35, "expoOut", GTAP),
				K(0.6, "cubicOut", GHIGH),
				K(0.7, "expoOut", GTAP),
				K(0.95, "cubicOut", GHIGH, { Root = { 0, -0.15, 0.1, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 14, 14, 0 } }),
				K(1.06, "expoOut", GTAP, { Root = { 0, -0.85, -0.1, 0, -18, 0 }, Torso = { -44, 0, 0 }, RLeg = { 36, 0, 10 }, LLeg = { -28, 0, -10 } }),
				K(1.5, "sineOut", GTAP, { Root = { 0, -0.82, -0.1, 0, -18, 0 }, Torso = { -42, 0, 0 }, Head = { 10, 14, 0 }, RLeg = { 36, 0, 10 }, LLeg = { -28, 0, -10 } }),
				K(2.0, "sineInOut", LIFT),
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
				K(0, nil, LIFT),
				K(0.12, "expoOut", GUARD_HIT),
				K(0.3, "sineOut", BRACE),
				K(0.8, "sineInOut", BRACE, { Root = { 0, -0.57, 0.45, 0, -10, 0 }, Torso = { -16, 0, 0 } }),
				K(1.1, "sineInOut", LIFT),
			},
			Events = { { t = 0.1, k = "Fx", n = "StoneWall" } },
		},

		-- 명상: 망치를 땅에 세워 짚고 쪼그려 앉아 정 끝을 들여다본다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, LIFT),
				K(0.4, "cubicInOut", SQUAT),
				K(1.5, "sineInOut", SQUAT, { Torso = { -8, 0, 0 }, Head = { -16, 18, 6 } }),
				K(2.0, "sineInOut", LIFT),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
