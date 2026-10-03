--!strict
--[[
	광전사 — 핏빛 룬 데인 액스를 든 차분한 전투광. (2026-09-28, 다시 2026-10-02·03)

	성격: 평소엔 **차분한 전투광**(2026-10-02 사용자) — 꼿꼿이 힘 빼고 서서 도끼를 한 손에 늘어뜨려 머리를 앞 땅에 눕히고,
	      느리고 깊게 숨 쉰다. 싸울 때만 두 손으로 움켜쥐고 터진다. 맞으면 움찔한 뒤 한 손으로 도끼를 치켜들고 포효한다.
	2026-10-03 다시(사용자: "공격할 때 도끼를 이상하게 잡아 · 스탠딩 때 도끼를 앞쪽으로 · 격분(피격 포효)·스킬 모션 수정"):
	  - 데인 액스 쥐는 법: 두 손을 벌려 오른손은 머리 쪽(무기 y 1.1), 왼손은 자루 아래(y -0.45). 크게 벤 끝은 위 손을
	    미끄러뜨려 두 손을 모은다. 베기마다 날(-Z)이 휘두르는 쪽을 앞서고, 땅에 닿는 자세는 도끼 머리를 땅 바로 위로.
	  - 자세: tools/combat/design/berserker2_gen.py(posecalc), 이 파일은 berserker_motions.py 가 만든다(W 최단 호로 감음).
	참고: 데인 액스(10~11세기) — 긴 자루를 두 손을 벌려 쥐고 크게 휘두를 땐 손을 모은다. 방패 없이 자루로 막는다.
	무기 종류: Axe2H (WeaponDefinitions.Greataxe).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 대기(차분한 전투광): 꼿꼿이 힘 빼고, 늘어뜨린 오른손이 자루 아래를 느슨히 쥐고 도끼 머리는 오른쪽 앞 땅에 눕힌다(2026-10-03: 뒤 → 앞)
local CALM = { Root = { 0, -0.06, 0, 0, -18, 0 }, Torso = { -6, 2, 0 }, Head = { -6, 16, -3 }, RArm = { 12, 0, 8 }, LArm = { 2, 0, -7 }, RLeg = { 4, 0, 7 }, LLeg = { -3, 0, -7 }, W = { 0, 0.15, 0, -48.3, -79.3, -15.7 } }
-- 들림: 축 늘어져 매달리고 도끼는 한 손에 머리가 아래로
local CALM_HANG = { Root = { 0, 0, 0, 2, -18, 0 }, Torso = { -4, 0, 0 }, Head = { -12, 20, 0 }, RArm = { -4, 0, 6 }, LArm = { 0, 0, -6 }, RLeg = { 6, 0, 4 }, LLeg = { -2, 0, -4 }, W = { -0, 0.15, -0, 92.2, -72.1, -178.6 } }
-- 돌진·회피: 웅크려 한 손으로 도끼를 뒤 땅에 끈다
local DRAG = { Root = { 0, -1, 0.2, 0, -16, 0 }, Torso = { -40, 0, 0 }, Head = { 30, 12, 0 }, RArm = { 20, 22, 14 }, LArm = { 24, -22, 0 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 }, W = { -0, 0.15, -0, 109.6, -75.4, -96.7 } }
-- 머리 위 치켜듦(내려찍기 예비): 두 손을 머리 위로, 도끼 머리는 등 뒤, 날은 위
local RAISE = { Root = { 0, -0.15, 0.25, 0, -16, 0 }, Torso = { 14, 0, 0 }, Head = { 18, 12, 0 }, RArm = { 186.6, 37.6, -71.7 }, LArm = { 139.6, -38, 27.7 }, RLeg = { 16, 0, 14 }, LLeg = { -18, 0, -14 }, W = { -0, -1.08, 0.03, 5.5, -66.8, 33.8 } }
-- 내려찍은 끝: 깊게 숙여 두 손이 배 앞 아래, 날이 앞 땅에 박힌다
local CHOP = { Root = { 0, -0.95, -0.6, 0, -16, 0 }, Torso = { -38, 0, 0 }, Head = { 26, 10, 0 }, RArm = { 98.4, 30, -8.6 }, LArm = { 63.9, -58.5, 38.1 }, RLeg = { 46, 0, 14 }, LLeg = { -36, 0, -14 }, W = { -0.01, -1.07, 0, -68.9, -20.4, -33.4 } }
-- 쌍베기 1 예비: 오른 어깨 위로 감아 올림(날은 적 쪽)
local CUT_A0 = { Root = { 0, -0.3, 0.2, 0, -40, 0 }, Torso = { -2, -28, 0 }, Head = { 12, 40, 0 }, RArm = { 211.3, 23, -24 }, LArm = { 126.2, -46.7, 41.5 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0.01, -1.08, 0.02, -151.6, -57.9, -105.9 } }
-- 쌍베기 1 끝: 왼쪽 아래로 베어 내림 — 위 손을 미끄러뜨려 두 손을 모음
local CUT_A1 = { Root = { 0, -0.8, -0.5, 0, 0, 0 }, Torso = { -34, 22, 0 }, Head = { 24, -12, 0 }, RArm = { 67.1, 20.2, -47.1 }, LArm = { 59.2, -78.3, 16.7 }, RLeg = { 40, 0, 18 }, LLeg = { -34, 0, -18 }, W = { -0.02, -0.37, 0.01, -44.5, 2.1, -19.1 } }
-- 쌍베기 2 예비: 왼 어깨 위로 감아 올림
local CUT_B0 = { Root = { 0, -0.4, -0.3, 0, 20, 0 }, Torso = { -6, 34, 0 }, Head = { 14, -22, 0 }, RArm = { 145, 33.6, -73.6 }, LArm = { 99.2, -57.1, 20.2 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { -0.02, -1, -0.05, -51.6, -50.9, 14.1 } }
-- 쌍베기 2 끝: 오른쪽 아래로 베어 내림
local CUT_B1 = { Root = { 0, -0.8, -0.9, 0, -30, 0 }, Torso = { -34, -28, 0 }, Head = { 26, 30, 0 }, RArm = { 69.9, 30.3, 4.9 }, LArm = { 41.9, -49.1, 32 }, RLeg = { 44, 0, 18 }, LLeg = { -38, 0, -18 }, W = { -0.01, -1.09, -0, -87.7, -30.9, -73.5 } }
-- 회오리: 두 손을 자루 아래에 모아 도끼를 오른쪽으로 수평으로 뻗는다
local WHIRL = { Root = { 0, -0.5, 0, 0, 30, 0 }, Torso = { -14, 30, 0 }, Head = { 20, -30, 0 }, RArm = { 63.6, 49.7, 1.9 }, LArm = { 59.9, -22.6, 24 }, RLeg = { 30, 0, 18 }, LLeg = { -24, 0, -18 }, W = { 0.01, -0.2, -0, 23.8, -39.7, -82.4 } }
-- 막기: 자루를 가로로 들어 얼굴 앞에서 받는다(두 손을 벌려)
local BLOCK = { Root = { 0, -0.6, 0.25, 0, -10, 0 }, Torso = { -12, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 126.7, 27, 3.5 }, LArm = { 120.5, -40, 0.3 }, RLeg = { 28, 0, 16 }, LLeg = { -22, 0, -16 }, W = { -0.02, -1.1, 0, 51.7, 5.7, -65.7 } }
-- 포효(피격): 한 손으로 도끼를 머리 위로 치켜들고 가슴을 펴 고개를 젖힌다, 왼 주먹은 아래로
local ROAR = { Root = { 0, -0.22, 0.1, 0, -18, 0 }, Torso = { 18, 0, 0 }, Head = { 34, 12, 0 }, RArm = { 168, 10, 6 }, LArm = { 34, 0, -18 }, RLeg = { 16, 0, 14 }, LLeg = { -14, 0, -14 }, W = { -0, 0.15, -0, -78.6, 6.6, -5.3 } }
-- 호흡: 도끼 머리를 앞 땅에 짚고(자루가 몸보다 길어 비스듬히) 두 손을 가슴 앞 자루 끝에 포갠 채 기댄다
local BREATH = { Root = { 0, -0.08, 0, 0, -18, 0 }, Torso = { -4, 0, 0 }, Head = { -2, 16, 0 }, RArm = { 116.8, 40.1, -23.2 }, LArm = { 124.9, -43.3, 24 }, RLeg = { 6, 0, 8 }, LLeg = { -4, 0, -8 }, W = { -0.01, 0.83, 0.01, 26.8, -52, -140.7 } }

return {
	Stance = CALM,

	-- 대기: 차분한 전투광 — 힘 빼고 서서 느리고 깊게 숨 쉰다(Kit.Breath, Smooth). 들숨에 가슴이 오르면 늘어진 팔·도끼도 조금 따라 들린다
	Idle = Kit.Breath(CALM, {
		Duration = 4.4,
		Chest = 2.5,
		Rise = 0.02,
		Head = -1.2,
		Mid = { Head = { -7, 18, -2 } },
	}),

	-- 버릇(가끔): 목을 천천히 한쪽으로 꺾었다 반대로 꺾어 풀고(뚝) 다시 적을 본다 — 몸통·머리만(도끼는 그대로)
	Fidgets = {
		{
			Duration = 2.2,
			BlendIn = 0.35,
			BlendOut = 0.45,
			Keys = {
				{ t = 0, Head = { -6, 16, -3 }, Torso = { -6, 2, 0 } },
				{ t = 0.6, e = "sineInOut", Head = { -2, 8, 22 }, Torso = { -5, 2, 3 } },
				{ t = 1.1, e = "sineInOut", Head = { -4, 22, -20 }, Torso = { -5, 2, -3 } },
				{ t = 1.25, e = "expoOut", Head = { -5, 22, -25 }, Torso = { -5, 2, -3 } },
				{ t = 2.2, e = "sineInOut", Head = { -6, 16, -3 }, Torso = { -6, 2, 0 } },
			},
		},
	},

	-- 들림: 차분하게 — 버둥대지 않고 축 늘어져 매달린 채 도끼를 한 손에 늘어뜨리고, 고개만 들어 내려다본다. 시계추처럼 느리게 흔들린다
	Held = {
		Duration = 3.0,
		Loop = true,
		Smooth = true,
		Keys = {
			K(0, nil, CALM_HANG),
			K(1.5, nil, CALM_HANG, { Root = { 0, 0.04, 0, -2, -18, 0 }, Head = { -8, 24, 3 }, RLeg = { -2, 0, 4 }, LLeg = { 4, 0, -4 } }),
		},
	},

	-- 내려놓임: 차분하게 — 사뿐히 무릎을 굽혀 내려서고 도끼 머리가 앞 땅에 툭 눕는다. 숨을 한 번 내쉬며 목을 기울이고 선다
	Drop = {
		Duration = 1.2,
		BlendIn = 0.05,
		Keys = {
			K(0, nil, CALM_HANG, { Root = { 0, 0.3, 0, 0, -18, 0 } }),
			K(0.14, "quadIn", CALM, { Root = { 0, -0.42, 0, 0, -18, 0 }, Torso = { -14, 2, 0 }, Head = { -10, 16, -3 }, RLeg = { 26, 0, 8 }, LLeg = { -14, 0, -8 } }),
			K(0.5, "sineOut", CALM, { Root = { 0, -0.12, 0, 0, -18, 0 }, Torso = { -9, 2, 0 }, Head = { -8, 16, 8 } }),
			K(0.8, "sineInOut", CALM, { Head = { -4, 18, -10 } }),
			K(1.2, "sineInOut", CALM),
		},
		Events = {
			{ t = 0.14, k = "Shake", a = 0.15, d = 0.2 },
		},
	},

	-- 피격(격분): 맞고 고개가 젖혀지며 움찔 → 그 힘을 받아 한 손으로 도끼를 머리 위로 치켜들고 가슴을 펴 포효 → 천천히 내린다
	Hit = {
		Duration = 0.95,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, CALM),
			K(0.05, "expoOut", CALM, { Root = { 0, -0.2, 0.45, 0, -18, 0 }, Torso = { -16, 2, 0 }, Head = { 20, 22, 8 } }),
			K(0.22, "backOut", ROAR),
			K(0.5, "sineOut", ROAR, { Torso = { 22, 0, 0 }, Head = { 40, 12, 0 } }),
			K(0.95, "sineInOut", CALM),
		},
		Events = {
			{ t = 0.24, k = "Fx", n = "Roar" },
			{ t = 0.25, k = "Shake", a = 0.2, d = 0.3 },
		},
	},

	-- 방어: 도끼를 움켜쥐어 자루를 가로로 들고 얼굴 앞에서 받는다
	Guard = {
		Duration = 0.7,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, CALM),
			K(0.07, "expoOut", BLOCK),
			K(0.2, "sineOut", BLOCK, { Root = { 0, -0.8, 0.4, 0, -10, 0 }, Torso = { -16, 0, 0 }, Head = { 18, 10, 0 } }),
			K(0.7, "sineInOut", CALM),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "HaftBlock" },
		},
	},

	-- 회피: 낮게 숙여 공격 밑으로 파고들고, 도끼를 뒤로 끌며 어깨로 들이받는다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, CALM),
			K(0.08, "expoOut", DRAG, { Root = { 0, -1.2, 0, 0, -30, 0 }, Torso = { -50, 0, 0 }, Head = { 36, 12, 0 } }),
			K(0.2, "expoOut", DRAG, { Root = { 0, -0.7, -1, 0, 20, 0 }, Torso = { -30, 30, 0 }, Head = { 20, -20, 0 }, LArm = { 70, -30, -30 } }),
			K(0.4, "sineOut", DRAG, { Root = { 0, -0.7, -0.9, 0, 16, 0 }, Torso = { -28, 26, 0 }, Head = { 20, -16, 0 }, LArm = { 70, -30, -30 } }),
			K(0.7, "sineInOut", CALM),
		},
		Events = {
			{ t = 0.2, k = "Fx", n = "ShoulderCheck" },
		},
	},

	Skills = {
		-- 핏빛 분쇄: 도끼를 뒤로 끌며 웅크렸다 도약 → 머리 위로 치켜든 도끼를 두 손으로 내려찍어 날이 땅에 박힌다
		BloodCrash = {
			Duration = 1.7,
			Keys = {
				K(0, nil, CALM),
				K(0.2, "quadOut", DRAG),
				K(0.45, "cubicOut", RAISE, { Root = { 0, 0.4, 0.3, 0, -12, 0 } }),
				K(0.55, "expoOut", CHOP),
				K(1.0, "linear", CHOP, { Root = { 0, -1.05, -0.7, 0, -16, 0 } }),
				K(1.3, "cubicInOut", CALM, { Root = { 0, -0.35, 0, 0, -18, 0 }, Torso = { -14, 2, 0 } }),
				K(1.7, "sineInOut", CALM),
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

		-- 쌍베기: 오른 어깨 위에서 왼쪽 아래로, 곧장 왼 어깨 위에서 오른쪽 아래로 — 한 걸음씩 파고든다
		DoubleSlash = {
			Duration = 1.5,
			Keys = {
				K(0, nil, CALM),
				K(0.2, "cubicOut", CUT_A0),
				K(0.3, "expoOut", CUT_A1),
				K(0.46, "cubicOut", CUT_B0),
				K(0.56, "expoOut", CUT_B1),
				K(0.95, "sineOut", CUT_B1, { Root = { 0, -0.76, -0.9, 0, -30, 0 }, Torso = { -32, -28, 0 }, Head = { 26, 30, 0 } }),
				K(1.5, "sineInOut", CALM),
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

		-- 광역 폭발: 두 손을 자루 아래에 모아 도끼를 옆으로 뻗고 두 바퀴 회오리 → 머리 위로 들어 땅에 내리꽂아 폭발
		Burst = {
			Duration = 2.0,
			Keys = {
				K(0, nil, CALM),
				K(0.2, "cubicOut", WHIRL),
				K(0.5, "linear", WHIRL, { Root = { 0, -0.5, 0, 0, -330, 0 } }),
				K(0.8, "linear", WHIRL, { Root = { 0, -0.5, 0, 0, -690, 0 } }),
				K(1.0, "cubicOut", RAISE, { Root = { 0, 0.2, 0.3, 0, -736, 0 } }),
				K(1.1, "expoOut", CHOP, { Root = { 0, -0.95, -0.6, 0, -736, 0 } }),
				K(1.55, "linear", CHOP, { Root = { 0, -0.92, -0.6, 0, -736, 0 } }),
				K(2.0, "sineInOut", CALM, { Root = { 0, -0.06, 0, 0, -738, 0 } }),
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

		-- 가드(스킬): 자루를 가로로 들고 오래 버틴다
		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, CALM),
				K(0.14, "backOut", BLOCK),
				K(0.8, "sineInOut", BLOCK, { Root = { 0, -0.72, 0.2, 0, -10, 0 }, Torso = { -15, 0, 0 } }),
				K(1.1, "sineInOut", CALM),
			},
			Events = {
				{ t = 0.14, k = "Fx", n = "HaftBlock" },
			},
		},

		-- 호흡(2026-10-03 사용자: '명상' → '호흡'): 도끼 머리를 앞 땅에 짚고 자루 끝에 두 손을 포개 기댄 채, 크게 들이쉬고(가슴을 펴 고개를 듦) 길게 내쉰다(어깨가 처짐) — 두 번
		Meditate = {
			Duration = 2.6,
			Keys = {
				K(0, nil, CALM),
				K(0.45, "cubicInOut", BREATH),
				K(1.0, "sineInOut", BREATH, { Root = { 0, -0.04, 0, 0, -18, 0 }, Torso = { 4, 0, 0 }, Head = { 12, 16, 0 } }),
				K(1.55, "sineInOut", BREATH, { Root = { 0, -0.14, 0, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { -12, 16, 0 } }),
				K(1.95, "sineInOut", BREATH, { Root = { 0, -0.06, 0, 0, -18, 0 }, Torso = { 2, 0, 0 }, Head = { 6, 16, 0 } }),
				K(2.6, "sineInOut", CALM),
			},
			Events = {
				{ t = 0.5, k = "Fx", n = "Meditate" },
			},
		},
	},
}
