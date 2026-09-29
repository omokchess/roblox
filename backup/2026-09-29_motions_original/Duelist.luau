--!strict
--[[
	결투사 — 레이피어 펜서. (2026-09-28)

	성격: 절제·정밀·빠름. 옆으로 선 펜싱 자세(오른 어깨가 적을 봄), 뒷손은 머리 뒤로 든다.
	      움직임은 짧고 날카롭게(expoOut), 큰 동작 없이 **선 하나**로 찌른다. 축은 패링.
	무기 종류: Thrust1H (WeaponDefinitions.Rapier)
	사건 이름(k): Hit(i = 몇 번째 타격) · Dash(to = Target/Home, gap = 대상 앞 거리, 음수면 뚫고 지나감)
	              Fx(n = ClassFx.Duelist 의 이름) · Trail(on) · Shake(a, d) · Stop(d = 타격 정지)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 기본 자세(엉 가르드): 왼쪽으로 38° 돌아 오른 어깨를 앞에 두고, 팔과 머리는 적 쪽으로 되돌린다
local EG = {
	Root = { 0, -0.2, 0, 0, 38, 0 },
	Torso = { 3, -4, 0 },
	Head = { 2, -32, 0 },
	RArm = { 66, -36, 4 },
	LArm = { 22, 0, -128 },
	RLeg = { 18, 0, 14 },
	LLeg = { -14, 0, -12 },
	W = { 0, 0, 0, -66, 0, 0 },
}
-- 찌르기 끝 자세(긴 런지): 팔·날이 적을 향해 일직선
local LUNGE = W(EG, {
	Root = { 0, -0.62, -0.5, 0, 34, 0 },
	Torso = { -14, -6, 0 },
	Head = { 8, -28, 0 },
	RArm = { 102, -34, 0 },
	LArm = { -10, 0, -70 },
	RLeg = { 52, 0, 12 },
	LLeg = { -40, 0, -10 },
	W = { 0, 0, 0, -90, 0, 0 },
})
-- 뒤돌아 찌르기(몸을 반 바퀴)
local BACK = W(LUNGE, { Root = { 0, -0.62, -0.5, 0, 214, 0 } })

return {
	Stance = EG,

	-- 대기: 발끝으로 가볍게 두 번 튀고, 칼끝이 작은 원을 그린다
	Idle = {
		Duration = 1.6,
		Loop = true,
		Keys = {
			K(0, "sineInOut", EG),
			K(0.4, "sineInOut", EG, { Root = { 0, -0.3, 0.05, 0, 36, 0 }, RArm = { 62, -34, 6 }, W = { 0, 0, 0, -60, 0, 4 }, Torso = { 1, -4, 0 } }),
			K(0.8, "sineInOut", EG, { Root = { 0, -0.16, 0, 0, 39, 0 }, RArm = { 68, -38, 2 }, W = { 0, 0, 0, -70, 0, -4 }, LArm = { 26, 0, -132 } }),
			K(1.2, "sineInOut", EG, { Root = { 0, -0.3, 0.05, 0, 37, 0 }, RArm = { 64, -35, 6 }, W = { 0, 0, 0, -64, 0, 2 }, Torso = { 1, -4, 0 } }),
		},
	},

	-- 들림: 흔들려도 품위를 지킨다 — 두 발을 모아 발끝을 세우고 칼을 세워 경례
	Held = {
		Duration = 1.8,
		Loop = true,
		Keys = {
			{ t = 0, e = "sineInOut", Root = { 0, 0.1, 0, 4, 10, 0 }, Torso = { 4, 0, 0 }, Head = { 8, -8, 0 }, RArm = { 104, 34, 0 }, LArm = { -18, 0, -8 }, RLeg = { -8, 0, 2 }, LLeg = { -12, 0, -2 }, W = { 0, 0, 0, -6, 0, 0 } },
			{ t = 0.9, e = "sineInOut", Root = { 0, 0.1, 0, -4, 16, 3 }, Torso = { 6, 0, 0 }, Head = { 4, -14, 0 }, RArm = { 100, 30, 0 }, LArm = { -22, 0, -10 }, RLeg = { -4, 0, 2 }, LLeg = { -16, 0, -2 }, W = { 0, 0, 0, -2, 0, 0 } },
		},
	},

	-- 내려놓임: 앞발로 바닥을 한 번 구르고(아펠) 칼을 한 바퀴 돌려 자세를 잡는다
	Drop = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			{ t = 0, Root = { 0, 0.5, 0, 0, 20, 0 }, Torso = { 4, 0, 0 }, Head = { 6, -10, 0 }, RArm = { 104, 34, 0 }, LArm = { -18, 0, -8 }, RLeg = { -8, 0, 2 }, LLeg = { -12, 0, -2 }, W = { 0, 0, 0, -6, 0, 0 } },
			K(0.07, "quadIn", EG, { Root = { 0, -0.5, 0, 0, 36, 0 }, Torso = { -8, -4, 0 }, RLeg = { 40, 0, 12 }, LLeg = { -20, 0, -12 }, RArm = { 50, -30, 20 }, W = { 0, 0, 0, -40, 0, 0 } }),
			K(0.17, "expoOut", EG, { Root = { 0, -0.34, 0, 0, 38, 0 }, RLeg = { 22, 0, 14 }, RArm = { 80, -30, 10 }, W = { 0, 0, 0, -120, 0, 0 } }),
			K(0.4, "cubicInOut", EG, { RArm = { 74, -34, 8 }, W = { 0, 0, 0, -426, 0, 0 } }),
			K(0.75, "sineInOut", EG),
		},
		Events = {
			{ t = 0.17, k = "Fx", n = "Appel" },
			{ t = 0.2, k = "Trail", on = true },
			{ t = 0.45, k = "Trail", on = false },
		},
	},

	-- 피격: 가슴을 맞고 뒤로 젖혀지며 칼이 옆으로 튕겨 나간다 → 한 발 물러나 다시 선다
	Hit = {
		Duration = 0.6,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, EG),
			K(0.05, "expoOut", EG, { Root = { 0, -0.1, 0.75, 0, 46, 0 }, Torso = { 18, 8, -6 }, Head = { 22, -20, 0 }, RArm = { 50, -70, 40 }, LArm = { 40, 0, -60 }, RLeg = { 30, 0, 10 }, LLeg = { -4, 0, -12 }, W = { 0, 0, 0, -20, 0, 0 } }),
			K(0.2, "sineOut", EG, { Root = { 0, -0.22, 0.9, 0, 44, 0 }, Torso = { 10, 4, -2 }, Head = { 10, -26, 0 }, RArm = { 46, -60, 30 }, LArm = { 30, 0, -80 }, W = { 0, 0, 0, -30, 0, 0 } }),
			K(0.6, "cubicInOut", EG),
		},
	},

	-- 방어(절반 성공): 칼을 세워 받는다(식스트) — 한 발 물러서며 손목으로 버틴다
	Guard = {
		Duration = 0.6,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, EG),
			K(0.07, "expoOut", EG, { Root = { 0, -0.34, 0.35, 0, 30, 0 }, Torso = { 6, 6, 0 }, RArm = { 88, -8, 0 }, W = { 0, 0, 0, -8, 0, -10 }, LArm = { 10, 0, -110 } }),
			K(0.14, "expoOut", EG, { Root = { 0, -0.4, 0.6, 0, 28, 0 }, Torso = { 10, 8, 2 }, Head = { 8, -30, 0 }, RArm = { 96, 4, 8 }, W = { 0, 0, 0, 6, 0, -16 } }),
			K(0.6, "cubicInOut", EG),
		},
		Events = { { t = 0.1, k = "Fx", n = "BlockSpark" } },
	},

	-- 회피(성공 = 패링): 칼등으로 쳐내고(바트) 곧장 되찌른다(리포스트)
	Dodge = {
		Duration = 0.62,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, EG),
			K(0.05, "expoOut", EG, { RArm = { 84, 10, 0 }, W = { 0, 0, 0, -40, 0, 0 }, Torso = { 4, 8, 0 }, Root = { 0, -0.3, 0.2, 0, 34, 0 } }),
			K(0.11, "expoOut", EG, { RArm = { 80, -62, 12 }, W = { 0, 0, 0, -30, 0, 0 }, Torso = { 2, -12, 0 }, Root = { 0, -0.3, 0.25, 0, 44, 0 } }),
			K(0.2, "expoOut", LUNGE, { Root = { 0, -0.5, -0.3, 0, 36, 0 }, RLeg = { 40, 0, 12 }, LLeg = { -30, 0, -10 } }),
			K(0.32, "sineOut", LUNGE, { Root = { 0, -0.5, -0.35, 0, 36, 0 }, RLeg = { 40, 0, 12 }, LLeg = { -30, 0, -10 } }),
			K(0.62, "cubicInOut", EG),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "ParrySpark" },
			{ t = 0.12, k = "Trail", on = true },
			{ t = 0.2, k = "Fx", n = "Riposte" },
			{ t = 0.34, k = "Trail", on = false },
		},
	},

	Skills = {
		-- 앞뒤관통: 적을 뚫고 지나가며 찌르고, 반 바퀴 돌아 등 뒤에서 다시 찌른다
		FrontBackPierce = {
			Duration = 1.45,
			Keys = {
				K(0, nil, EG),
				K(0.14, "quadOut", EG, { Root = { 0, -0.5, 0.35, 0, 42, 0 }, Torso = { -8, -2, 0 }, RArm = { 52, -26, 22 }, W = { 0, 0, 0, -90, 0, 0 }, RLeg = { 26, 0, 12 }, LLeg = { -24, 0, -12 } }),
				K(0.2, "expoOut", LUNGE),
				K(0.42, "linear", LUNGE, { Root = { 0, -0.56, -0.5, 0, 36, 0 } }),
				K(0.52, "cubicIn", LUNGE, { Root = { 0, -0.4, -0.2, 0, 130, 0 }, RArm = { 70, -20, 20 }, W = { 0, 0, 0, -70, 0, 0 } }),
				K(0.6, "expoOut", BACK),
				K(0.82, "linear", BACK, { Root = { 0, -0.56, -0.45, 0, 216, 0 } }),
				K(0.96, "sineOut", EG, { Root = { 0, -0.1, 0, 0, 218, 0 }, W = { 0, 0, 0, -40, 0, 0 }, RArm = { 40, -30, 30 } }),
				K(1.2, "cubicInOut", EG, { Root = { 0, -0.2, 0, 0, 218, 0 } }),
				K(1.45, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.12, k = "Trail", on = true },
				{ t = 0.15, k = "Dash", to = "Target", gap = -2.6, d = 0.09 },
				{ t = 0.19, k = "Hit", i = 1, fx = "Pierce" },
				{ t = 0.2, k = "Stop", d = 0.05 },
				{ t = 0.6, k = "Hit", i = 2, fx = "PierceBack" },
				{ t = 0.61, k = "Stop", d = 0.06 },
				{ t = 0.62, k = "Shake", a = 0.25, d = 0.2 },
				{ t = 0.85, k = "Trail", on = false },
				{ t = 0.98, k = "Dash", to = "Home", d = 0.22 },
			},
		},

		-- 찔러찔러또찔러: 가운데를 찌르고, 뽑아내며 칼끝을 튕기고, 그 반동으로 두 번 더 꿰뚫는다
		TripleThrust = {
			Duration = 1.4,
			Keys = {
				K(0, nil, EG),
				K(0.12, "quadOut", EG, { Root = { 0, -0.42, 0.25, 0, 40, 0 }, RArm = { 56, -30, 14 }, W = { 0, 0, 0, -84, 0, 0 } }),
				K(0.24, "expoOut", LUNGE, { Root = { 0, -0.5, -0.2, 0, 36, 0 }, RLeg = { 38, 0, 12 }, LLeg = { -28, 0, -10 } }),
				-- 뽑아내기: 팔을 당기고 칼끝을 위로 튕긴다
				K(0.38, "expoOut", EG, { Root = { 0, -0.36, 0.2, 0, 40, 0 }, RArm = { 74, -30, 18 }, W = { 0, 0, 0, -30, 0, 0 }, Torso = { 4, -4, 0 } }),
				K(0.47, "expoOut", LUNGE, { Root = { 0, -0.56, -0.35, 0, 35, 0 }, RLeg = { 46, 0, 12 }, LLeg = { -34, 0, -10 } }),
				K(0.56, "expoOut", EG, { Root = { 0, -0.4, 0.15, 0, 40, 0 }, RArm = { 70, -32, 22 }, W = { 0, 0, 0, -56, 0, 0 }, Torso = { 2, -2, 0 } }),
				-- 마지막: 몸 전체로 깊게
				K(0.7, "expoOut", LUNGE, { Root = { 0, -0.7, -0.7, 0, 33, 0 }, Torso = { -22, -8, 0 }, RArm = { 112, -32, 0 }, RLeg = { 60, 0, 12 }, LLeg = { -46, 0, -10 } }),
				K(0.95, "sineOut", LUNGE, { Root = { 0, -0.66, -0.7, 0, 33, 0 }, Torso = { -18, -8, 0 }, RArm = { 108, -32, 0 }, RLeg = { 60, 0, 12 }, LLeg = { -46, 0, -10 } }),
				K(1.12, "cubicInOut", EG, { W = { 0, 0, 0, -20, 0, 0 }, RArm = { 50, -30, 26 } }),
				K(1.4, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.08, k = "Dash", to = "Target", gap = 3.2, d = 0.12 },
				{ t = 0.18, k = "Trail", on = true },
				{ t = 0.23, k = "Hit", i = 1, fx = "Pierce" },
				{ t = 0.39, k = "Fx", n = "Flick" },
				{ t = 0.46, k = "Hit", i = 2, fx = "Pierce" },
				{ t = 0.69, k = "Hit", i = 3, fx = "PierceBig" },
				{ t = 0.7, k = "Stop", d = 0.08 },
				{ t = 0.71, k = "Shake", a = 0.3, d = 0.25 },
				{ t = 0.96, k = "Trail", on = false },
				{ t = 1.0, k = "Dash", to = "Home", d = 0.22 },
			},
		},

		-- 깊은 호흡: 칼을 세워 코끝에 대고 숨을 들이쉬었다 내쉬고, 높은 겨눔 자세로 굳힌다
		DeepBreath = {
			Duration = 1.7,
			Keys = {
				K(0, nil, EG),
				{ t = 0.3, e = "cubicInOut", Root = { 0, -0.05, 0, 0, 20, 0 }, Torso = { 2, 0, 0 }, Head = { 0, -18, 0 }, RArm = { 98, 26, 0 }, LArm = { -12, 0, -10 }, RLeg = { 6, 0, 6 }, LLeg = { -4, 0, -6 }, W = { 0, 0, 0, -2, 0, 0 } },
				-- 들숨
				{ t = 0.8, e = "sineInOut", Root = { 0, 0.1, 0.05, 0, 20, 0 }, Torso = { 10, 0, 0 }, Head = { 14, -18, 0 }, RArm = { 102, 26, 0 }, LArm = { -6, 0, -18 }, W = { 0, 0, 0, -4, 0, 0 } },
				-- 날숨 → 겨눔
				{ t = 1.1, e = "sineInOut", Root = { 0, -0.1, 0, 0, 22, 0 }, Torso = { -2, 0, 0 }, Head = { -4, -18, 0 }, RArm = { 96, 26, 0 }, LArm = { -12, 0, -10 }, W = { 0, 0, 0, 0, 0, 0 } },
				K(1.3, "expoOut", EG, { Root = { 0, -0.36, 0.1, 0, 42, 0 }, RArm = { 118, -36, 10 }, W = { 0, 0, 0, -104, 0, 0 }, LArm = { 60, 0, -60 }, Head = { 0, -36, 0 } }),
				K(1.7, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.35, k = "Fx", n = "Salute" },
				{ t = 0.8, k = "Fx", n = "Focus" },
				{ t = 1.3, k = "Fx", n = "FocusSnap" },
			},
		},

		-- 검 끝을 쏘아라: 활을 당기듯 칼을 머리 옆으로 끌어 겨누고(떨림), 한 줄기 빛처럼 꿰뚫고 지나가 피를 턴다
		PointBlank = {
			Duration = 2.0,
			Keys = {
				K(0, nil, EG),
				K(0.3, "cubicOut", EG, { Root = { 0, -0.62, 0.6, 0, 50, 0 }, Torso = { -6, 12, 0 }, Head = { 0, -56, 0 }, RArm = { 160, -40, 16 }, W = { 0, 0, 0, -160, 0, 0 }, LArm = { 88, -54, 0 }, RLeg = { 34, 0, 14 }, LLeg = { -30, 0, -14 } }),
				K(0.5, "sineInOut", EG, { Root = { 0, -0.68, 0.7, 0, 51, 0 }, Torso = { -8, 13, 0 }, Head = { 0, -57, 0 }, RArm = { 162, -40, 16 }, W = { 0, 0, 0, -162, 0, 0 }, LArm = { 89, -55, 0 }, RLeg = { 36, 0, 14 }, LLeg = { -32, 0, -14 } }),
				K(0.66, "sineInOut", EG, { Root = { 0, -0.7, 0.72, 0, 52, 0 }, Torso = { -9, 14, 0 }, Head = { 0, -58, 0 }, RArm = { 163, -41, 16 }, W = { 0, 0, 0, -163, 0, 0 }, LArm = { 89, -56, 0 }, RLeg = { 36, 0, 14 }, LLeg = { -32, 0, -14 } }),
				K(0.72, "expoOut", LUNGE, { Root = { 0, -0.9, -0.9, 0, 30, 0 }, Torso = { -28, -8, 0 }, Head = { 20, -24, 0 }, RArm = { 116, -32, 0 }, LArm = { -30, 0, -40 }, RLeg = { 70, 0, 10 }, LLeg = { -56, 0, -10 } }),
				K(1.0, "linear", LUNGE, { Root = { 0, -0.86, -0.9, 0, 30, 0 }, Torso = { -26, -8, 0 }, Head = { 20, -24, 0 }, RArm = { 114, -32, 0 }, LArm = { -30, 0, -40 }, RLeg = { 70, 0, 10 }, LLeg = { -56, 0, -10 } }),
				-- 피 털기(치부리): 등을 적에게 둔 채 일어서며 칼을 옆으로 휙 턴다
				K(1.18, "cubicOut", EG, { Root = { 0, -0.2, 0, 0, 24, 0 }, Torso = { 4, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 70, -60, 30 }, W = { 0, 0, 0, -80, 0, 0 }, LArm = { 0, 0, -12 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(1.26, "expoOut", EG, { Root = { 0, -0.2, 0, 0, 24, 0 }, Torso = { 4, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 34, -80, 40 }, W = { 0, 0, 0, -100, 0, 0 }, LArm = { 0, 0, -12 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(1.55, "sineInOut", EG, { Root = { 0, -0.18, 0, 0, 24, 0 }, Torso = { 4, 0, 0 }, Head = { 0, 4, 0 }, RArm = { 30, -80, 40 }, W = { 0, 0, 0, -100, 0, 0 }, LArm = { 0, 0, -12 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(2.0, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Glint" },
				{ t = 0.66, k = "Trail", on = true },
				{ t = 0.67, k = "Dash", to = "Target", gap = -4, d = 0.06 },
				{ t = 0.7, k = "Hit", i = 1, fx = "PointBlank" },
				{ t = 0.71, k = "Stop", d = 0.14 },
				{ t = 0.72, k = "Shake", a = 0.55, d = 0.35 },
				{ t = 0.95, k = "Trail", on = false },
				{ t = 1.24, k = "Fx", n = "Chiburi" },
				{ t = 1.5, k = "Dash", to = "Home", d = 0.24 },
			},
		},

		-- 가드(스킬): 방어 태세 — 칼을 몸 앞에 세우고 무게를 뒤로
		Guard = {
			Duration = 0.9,
			Keys = {
				K(0, nil, EG),
				K(0.16, "backOut", EG, { Root = { 0, -0.36, 0.4, 0, 30, 0 }, Torso = { 6, 6, 0 }, RArm = { 88, -6, 0 }, W = { 0, 0, 0, -6, 0, -8 }, LArm = { 30, 0, -100 } }),
				K(0.6, "sineInOut", EG, { Root = { 0, -0.36, 0.4, 0, 30, 0 }, Torso = { 6, 6, 0 }, RArm = { 88, -6, 0 }, W = { 0, 0, 0, -6, 0, -8 }, LArm = { 30, 0, -100 } }),
				K(0.9, "cubicInOut", EG),
			},
			Events = { { t = 0.16, k = "Fx", n = "GuardRing" } },
		},

		-- 명상: 칼끝을 땅에 짚고 한쪽 무릎을 꿇어 고개를 숙인다
		Meditate = {
			Duration = 1.8,
			Keys = {
				K(0, nil, EG),
				{ t = 0.35, e = "cubicInOut", Root = { 0, -0.9, 0, 0, 20, 0 }, Torso = { -10, 0, 0 }, Head = { -24, -10, 0 }, RArm = { 36, 10, 0 }, LArm = { 20, 0, -10 }, RLeg = { 86, 0, 6 }, LLeg = { -40, 0, -6 }, W = { 0, 0, 0, 60, 0, 0 } },
				{ t = 1.3, e = "sineInOut", Root = { 0, -0.86, 0, 0, 20, 0 }, Torso = { -6, 0, 0 }, Head = { -18, -10, 0 }, RArm = { 36, 10, 0 }, LArm = { 20, 0, -10 }, RLeg = { 86, 0, 6 }, LLeg = { -40, 0, -6 }, W = { 0, 0, 0, 60, 0, 0 } },
				K(1.8, "cubicInOut", EG),
			},
			Events = { { t = 0.4, k = "Fx", n = "Meditate" } },
		},
	},
}
