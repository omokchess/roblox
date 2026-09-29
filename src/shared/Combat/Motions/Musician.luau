--!strict
--[[
	음악가 — 바이올리니스트. (2026-09-28)

	성격: 우아함·무대 체질. 늘 연주하며 움직이고, 움직임은 곡선(sine)으로 흐른다.
	      연주자답게 몸을 **관객(카메라) 쪽으로 28° 열고** 선다 — 전투 카메라는 오른쪽 옆에서 보므로
	      실제 연주 자세(바이올린이 왼쪽 앞)로 서면 악기가 카메라 반대편으로 파묻힌다.
	      한 발에 무게를 싣고(콘트라포스토) 다른 발끝을 세우며, 피하면 피루엣으로 돈다.
	      공격은 칼질이 아니라 **활 긋기**다 — 음표가 날아가 때린다.
	무기 종류: Bowed (WeaponDefinitions.Violin: O = 왼손 바이올린, W = 오른손 활)
	  바이올린은 왼팔 위에 얹는다: O = { 0.3, -2.4, -0.8, -90, 160, 0 } (팔과 일직선, 길이 방향으로 당겨 턱까지, 줄 쪽 위로)
	  활은 몸을 가로질러 왼쪽을 본다: W 기울기 ≈ 90. 활 긋기 = 오른팔 Y(좌우) 흔들기.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

local VIOLIN = { 0.3, -1.6, -0.5, -90, 186, 24 }

-- 연주 자세: 몸을 살짝 왼쪽으로 열고, 턱을 바이올린에 괸다. 오른발에 무게, 왼발끝을 세움
local PLAY = {
	Root = { 0, -0.05, 0, 0, -28, 0 },
	Torso = { 4, 8, 0 },
	Head = { -12, 24, 16 },
	LArm = { 88, 34, 0 },
	RArm = { 106, 30, 0 },
	RLeg = { 3, 0, 4 },
	LLeg = { -8, 0, -8 },
	O = VIOLIN,
	W = { 0, 0, 0, 0, 0, 94 },
}
-- 활을 끝까지 내리그은 자리(다운보우 끝)
local DOWN = { RArm = { 104, -8, 6 }, W = { 0, 0, 0, 0, 0, 86 } }
-- 활을 쳐든 자리(업보우 끝)
local UP = { RArm = { 108, 42, 0 }, W = { 0, 0, 0, 0, 0, 98 } }
-- 두 팔을 활짝 편 자세(피날레)
local OPEN = W(PLAY, {
	Root = { 0, 0.15, 0, 0, -40, 0 },
	Torso = { 14, 0, 0 },
	Head = { 20, 0, 0 },
	LArm = { 120, 30, -30 },
	RArm = { 150, -40, 40 },
	RLeg = { 2, 0, 3 },
	LLeg = { -20, 0, -6 },
	W = { 0, 0, 0, -40, 0, 20 },
})

local M = {
	Stance = PLAY,

	-- 대기: 느린 레가토. 활을 길게 내리긋고 올리며 음악에 맞춰 몸이 좌우로 흔들린다
	Idle = {
		Duration = 3.38,
		Loop = true,
		Keys = {
			K(0.0, "sineInOut", PLAY, UP),
			K(1.69, "sineInOut", PLAY, W(DOWN, { Torso = { 2, 4, -4 }, Head = { -14, 26, 20 }, Root = { 0, -0.12, 0, 0, -30, 0 }, RLeg = { 5, 0, 5 }, LLeg = { -10, 0, -8 } })),
			K(2.535, "sineInOut", PLAY, { RArm = { 106, 20, 2 }, W = { 0, 0, 0, 0, 0, 92 }, Torso = { 5, 10, 3 }, Head = { -10, 32, 12 } }),
		},
	},

	-- 들림: 발끝을 번갈아 차며 트레몰로(아주 빠른 활 떨기) — 신이 나서 멈추지 않는다
	Held = {
		Duration = 0.72,
		Loop = true,
		Keys = {
			K(0, "sineInOut", PLAY, { Root = { 0, 0.1, 0, 6, -28, 0 }, Torso = { 10, 8, 0 }, Head = { -2, 30, 14 }, RArm = { 110, 28, 0 }, RLeg = { 18, 0, 2 }, LLeg = { -22, 0, -2 } }),
			K(0.12, "sineInOut", PLAY, { RArm = { 110, 16, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
			K(0.24, "sineInOut", PLAY, { RArm = { 110, 28, 0 }, W = { 0, 0, 0, 0, 0, 94 } }),
			K(0.36, "sineInOut", PLAY, { Root = { 0, 0.14, 0, 4, -26, 0 }, Torso = { 10, 8, 0 }, Head = { -2, 34, 12 }, RArm = { 110, 16, 0 }, W = { 0, 0, 0, 0, 0, 90 }, RLeg = { -20, 0, 2 }, LLeg = { 16, 0, -2 } }),
			K(0.48, "sineInOut", PLAY, { RArm = { 110, 28, 0 }, W = { 0, 0, 0, 0, 0, 94 } }),
			K(0.6, "sineInOut", PLAY, { RArm = { 110, 16, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
		},
	},

	-- 내려놓임: 발끝으로 사뿐히 내려서 활을 크게 한 번 휘두르고, 무릎을 굽혀 인사(커트시)
	Drop = {
		Duration = 1.0,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, PLAY, { Root = { 0, 0.4, 0, 0, -28, 0 }, RLeg = { 10, 0, 2 }, LLeg = { -14, 0, -2 } }),
			K(0.08, "quadIn", PLAY, { Root = { 0, -0.2, 0, 0, -28, 0 } }),
			K(0.3, "cubicOut", OPEN),
			K(0.55, "sineInOut", PLAY, { Root = { 0, -0.45, 0.1, 0, -32, 0 }, Torso = { -18, 4, 0 }, Head = { -24, 20, 8 }, RArm = { 60, -30, 40 }, W = { 0, 0, 0, -30, 0, 60 }, LArm = { 70, 40, -10 }, RLeg = { 16, 0, 4 }, LLeg = { -34, 0, -4 } }),
			K(0.75, "sineInOut", PLAY, { Root = { 0, -0.4, 0.1, 0, -32, 0 }, Torso = { -16, 4, 0 }, Head = { -22, 20, 8 }, RArm = { 60, -30, 40 }, W = { 0, 0, 0, -30, 0, 60 }, LArm = { 70, 40, -10 }, RLeg = { 16, 0, 4 }, LLeg = { -34, 0, -4 } }),
			K(1.0, "sineInOut", PLAY, UP),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "Tiptoe" },
			{ t = 0.12, k = "Trail", on = true },
			{ t = 0.3, k = "Fx", n = "Flourish" },
			{ t = 0.5, k = "Trail", on = false },
		},
	},

	-- 피격: 바이올린을 감싸려고 등을 돌리며 움츠린다 → 다시 자세
	Hit = {
		Duration = 0.65,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, PLAY),
			K(0.05, "expoOut", PLAY, { Root = { 0, -0.2, 0.7, 0, 0, -6 }, Torso = { -16, 30, 6 }, Head = { -20, 20, 0 }, LArm = { 60, 70, 0 }, RArm = { 60, 50, 20 }, W = { 0, 0, 0, 20, 0, 60 }, RLeg = { 20, 0, 6 }, LLeg = { -10, 0, -8 } }),
			K(0.22, "sineOut", PLAY, { Root = { 0, -0.24, 0.8, 0, -4, -4 }, Torso = { -12, 26, 4 }, Head = { -14, 24, 4 }, LArm = { 62, 66, 0 }, RArm = { 64, 46, 18 }, W = { 0, 0, 0, 20, 0, 60 }, RLeg = { 18, 0, 6 }, LLeg = { -8, 0, -8 } }),
			K(0.65, "cubicInOut", PLAY),
		},
	},

	-- 방어: 뒤로 물러서며 바이올린을 가슴에 끌어안고, 활을 앞으로 뻗어 오선 방패를 친다
	Guard = {
		Duration = 0.65,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, PLAY),
			K(0.08, "expoOut", PLAY, { Root = { 0, -0.2, 0.45, 0, -50, 0 }, Torso = { 6, -10, 0 }, Head = { 0, 10, 0 }, LArm = { 50, 30, 0 }, O = { 0.3, -1.6, -0.4, -40, 160, 0 }, RArm = { 88, -10, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
			K(0.18, "sineOut", PLAY, { Root = { 0, -0.25, 0.6, 0, -48, 0 }, Torso = { 8, -8, 0 }, Head = { 2, 10, 0 }, LArm = { 50, 30, 0 }, O = { 0.3, -1.6, -0.4, -40, 160, 0 }, RArm = { 92, -6, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
			K(0.65, "cubicInOut", PLAY, UP),
		},
		Events = { { t = 0.08, k = "Fx", n = "StaveShield" } },
	},

	-- 회피: 한 발로 피루엣(한 바퀴) 돌며 옆으로 비껴난다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, PLAY),
			K(0.06, "quadOut", PLAY, { Root = { 0.3, -0.2, 0.2, 0, -40, 0 }, Torso = { 6, 0, 0 } }),
			K(0.2, "cubicIn", OPEN, { Root = { -0.6, 0.35, 0.5, 0, 150, 0 }, RLeg = { 0, 0, 2 }, LLeg = { 40, 0, -10 } }),
			K(0.36, "cubicOut", OPEN, { Root = { -1.2, 0.2, 0.9, 0, 332, 0 }, RLeg = { 0, 0, 2 }, LLeg = { 30, 0, -10 } }),
			K(0.7, "sineInOut", PLAY, { Root = { -0.4, -0.05, 0.3, 0, 332, 0 } }),
		},
		Events = { { t = 0.06, k = "Fx", n = "Pirouette" } },
	},

	Skills = {
		-- 벨로체: 빠른 스피카토(활을 튀기며 짧게 여러 번) — 앞으로 몸을 싣고, 음표가 줄지어 날아간다
		Veloce = {
			Duration = 1.3,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.12, "quadOut", PLAY, { Root = { 0, -0.2, -0.2, 0, -22, 0 }, Torso = { -8, 12, 0 }, Head = { -18, 30, 16 }, RArm = { 108, 36, 0 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }),
				K(0.2, "expoOut", PLAY, { Root = { 0, -0.2, -0.2, 0, -22, 0 }, Torso = { -8, 12, 0 }, Head = { -18, 30, 16 }, RArm = { 104, 14, 2 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }),
				K(0.28, "expoOut", PLAY, { Root = { 0, -0.24, -0.2, 0, -22, 0 }, Torso = { -8, 12, 0 }, Head = { -18, 30, 16 }, RArm = { 108, 34, 0 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }),
				K(0.36, "expoOut", PLAY, { Root = { 0, -0.2, -0.25, 0, -22, 0 }, Torso = { -9, 12, 0 }, Head = { -18, 30, 16 }, RArm = { 104, 12, 2 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }),
				K(0.44, "expoOut", PLAY, { Root = { 0, -0.24, -0.25, 0, -22, 0 }, Torso = { -9, 12, 0 }, Head = { -18, 30, 16 }, RArm = { 108, 34, 0 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }),
				-- 마지막 한 번은 길고 세게 내리그어 음표를 떠나보낸다
				K(0.62, "expoOut", PLAY, { Root = { 0, -0.3, -0.35, 0, -18, 0 }, Torso = { -12, 16, 0 }, Head = { -16, 28, 12 }, RArm = { 100, -30, 20 }, W = { 0, 0, 0, 0, 0, 80 }, RLeg = { 22, 0, 4 }, LLeg = { -22, 0, -8 } }),
				K(0.9, "sineOut", PLAY, { Root = { 0, -0.26, -0.3, 0, -20, 0 }, Torso = { -10, 14, 0 }, RArm = { 98, -34, 22 }, W = { 0, 0, 0, 0, 0, 80 }, RLeg = { 20, 0, 4 }, LLeg = { -20, 0, -8 } }),
				K(1.3, "sineInOut", PLAY, UP),
			},
			Events = {
				{ t = 0.12, k = "Trail", on = true },
				{ t = 0.2, k = "Fx", n = "Spiccato" },
				{ t = 0.36, k = "Fx", n = "Spiccato" },
				{ t = 0.62, k = "Fx", n = "NoteStream" },
				{ t = 0.9, k = "Hit", i = 1, fx = "NoteHit" },
				{ t = 0.95, k = "Trail", on = false },
			},
		},

		-- 브릴란테: 활을 하늘로 치켜들고 피루엣, 크게 한 획을 그어 금빛 음표를 흩뿌린다(아군 버프)
		Brillante = {
			Duration = 1.7,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.25, "cubicOut", PLAY, { Root = { 0, 0.1, 0, 0, -28, 0 }, Torso = { 12, 8, 0 }, Head = { 16, 20, 6 }, RArm = { 172, 20, 20 }, W = { 0, 0, 0, -60, 0, 30 }, RLeg = { 0, 0, 3 }, LLeg = { -26, 0, -6 } }),
				K(0.6, "sineInOut", OPEN, { Root = { 0, 0.25, 0, 0, 332, 0 } }),
				K(0.82, "expoOut", OPEN, { Root = { 0, -0.1, 0, 0, 332, 0 }, RArm = { 60, -70, 50 }, W = { 0, 0, 0, -20, 0, 50 }, Torso = { -10, -12, 0 }, Head = { -8, -10, 0 } }),
				K(1.25, "sineOut", OPEN, { Root = { 0, 0, 0, 0, 332, 0 }, RArm = { 56, -74, 54 }, W = { 0, 0, 0, -20, 0, 50 }, Torso = { -6, -12, 0 }, Head = { 2, -10, 0 } }),
				K(1.7, "sineInOut", PLAY, { Root = { 0, -0.05, 0, 0, 332, 0 }, RArm = UP.RArm, W = UP.W }),
			},
			Events = {
				{ t = 0.1, k = "Trail", on = true },
				{ t = 0.25, k = "Fx", n = "Raise" },
				{ t = 0.82, k = "Fx", n = "Brillante" },
				{ t = 1.0, k = "Trail", on = false },
			},
		},

		-- 크레셴도: 세 번 긋는 동안 점점 크게, 몸이 점점 뒤로 젖혀지다가 마지막 포르테로 음표를 쏜다
		Crescendo = {
			Duration = 1.9,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.3, "sineInOut", PLAY, { RArm = { 104, 4, 4 }, W = { 0, 0, 0, 0, 0, 88 }, Torso = { 6, 6, 0 } }),
				K(0.55, "sineInOut", PLAY, { RArm = { 110, 44, 0 }, W = { 0, 0, 0, 0, 0, 98 }, Torso = { 10, 10, 2 }, Head = { -8, 30, 16 } }),
				K(0.82, "sineInOut", PLAY, { RArm = { 102, -14, 8 }, W = { 0, 0, 0, 0, 0, 84 }, Torso = { 14, 6, -3 }, Head = { -4, 28, 18 }, Root = { 0, 0.05, 0.1, 0, -30, 0 } }),
				K(1.1, "cubicInOut", PLAY, { RArm = { 120, 50, 0 }, W = { 0, 0, 0, 0, 0, 104 }, Torso = { 20, 12, 4 }, Head = { 6, 30, 16 }, Root = { 0, 0.15, 0.25, 0, -26, 0 }, RLeg = { -4, 0, 3 }, LLeg = { -14, 0, -6 } }),
				-- 포르테
				K(1.22, "expoOut", PLAY, { RArm = { 96, -60, 40 }, W = { 0, 0, 0, -10, 0, 70 }, Torso = { -14, -8, 0 }, Head = { -20, 18, 8 }, Root = { 0, -0.3, -0.4, 0, -24, 0 }, RLeg = { 26, 0, 4 }, LLeg = { -26, 0, -6 } }),
				K(1.5, "sineOut", PLAY, { RArm = { 92, -64, 44 }, W = { 0, 0, 0, -10, 0, 70 }, Torso = { -10, -8, 0 }, Head = { -14, 18, 8 }, Root = { 0, -0.26, -0.35, 0, -24, 0 }, RLeg = { 24, 0, 4 }, LLeg = { -24, 0, -6 } }),
				K(1.9, "sineInOut", PLAY, UP),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "SoftNotes" },
				{ t = 0.82, k = "Fx", n = "SoftNotes" },
				{ t = 1.1, k = "Trail", on = true },
				{ t = 1.22, k = "Fx", n = "Forte" },
				{ t = 1.23, k = "Stop", d = 0.05 },
				{ t = 1.45, k = "Hit", i = 1, fx = "CrescendoHit" },
				{ t = 1.46, k = "Shake", a = 0.35, d = 0.3 },
				{ t = 1.5, k = "Trail", on = false },
			},
		},

		-- 크레셴도 알 포르테: 발끝으로 서서 바이올린을 치켜들고 광란의 트레몰로 → 활을 내던지듯 긋는 순간 별처럼 터진다
		CrescendoAlForte = {
			Duration = 2.4,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.3, "cubicOut", PLAY, { Root = { 0, 0.3, 0.1, 0, -28, 0 }, Torso = { 16, 8, 0 }, Head = { 6, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 30, 0 }, W = { 0, 0, 0, -20, 0, 94 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.38, "linear", PLAY, { Root = { 0, 0.32, 0.1, 0, -28, 0 }, Torso = { 16, 8, 0 }, Head = { 6, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 16, 0 }, W = { 0, 0, 0, -20, 0, 90 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.46, "linear", PLAY, { Root = { 0, 0.3, 0.1, 0, -28, 0 }, Torso = { 17, 8, 0 }, Head = { 6, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 32, 0 }, W = { 0, 0, 0, -20, 0, 96 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.54, "linear", PLAY, { Root = { 0, 0.34, 0.1, 0, -28, 0 }, Torso = { 17, 8, 0 }, Head = { 6, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 14, 0 }, W = { 0, 0, 0, -20, 0, 90 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.62, "linear", PLAY, { Root = { 0, 0.3, 0.1, 0, -28, 0 }, Torso = { 18, 8, 0 }, Head = { 6, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 32, 0 }, W = { 0, 0, 0, -20, 0, 96 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.7, "linear", PLAY, { Root = { 0, 0.36, 0.1, 0, -28, 0 }, Torso = { 18, 8, 0 }, Head = { 8, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 14, 0 }, W = { 0, 0, 0, -20, 0, 90 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				K(0.78, "linear", PLAY, { Root = { 0, 0.3, 0.1, 0, -28, 0 }, Torso = { 18, 8, 0 }, Head = { 8, 30, 14 }, LArm = { 128, 28, 0 }, RArm = { 132, 32, 0 }, W = { 0, 0, 0, -20, 0, 96 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }),
				-- 숨을 멈추는 한 박
				K(1.05, "cubicOut", PLAY, { Root = { 0, 0.4, 0.3, 0, -22, 0 }, Torso = { 24, 14, 4 }, Head = { 20, 30, 10 }, LArm = { 132, 28, 0 }, RArm = { 168, 50, 10 }, W = { 0, 0, 0, -50, 0, 110 }, RLeg = { -10, 0, 2 }, LLeg = { -30, 0, -2 } }),
				-- 내던지듯 긋기
				K(1.14, "expoOut", OPEN, { Root = { 0, -0.35, -0.5, 0, -34, 0 }, Torso = { -18, -14, 0 }, Head = { -10, -4, 0 }, RArm = { 70, -88, 60 }, W = { 0, 0, 0, -10, 0, 40 }, RLeg = { 30, 0, 4 }, LLeg = { -30, 0, -6 } }),
				K(1.7, "sineOut", OPEN, { Root = { 0, -0.3, -0.45, 0, -34, 0 }, Torso = { -14, -14, 0 }, Head = { 4, -4, 0 }, RArm = { 66, -90, 62 }, W = { 0, 0, 0, -10, 0, 40 }, RLeg = { 28, 0, 4 }, LLeg = { -28, 0, -6 } }),
				K(2.4, "sineInOut", PLAY, UP),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Tremolo" },
				{ t = 0.3, k = "Trail", on = true },
				{ t = 1.05, k = "Fx", n = "Gather" },
				{ t = 1.14, k = "Stop", d = 0.1 },
				{ t = 1.15, k = "Fx", n = "Forte" },
				{ t = 1.3, k = "Hit", i = 1, fx = "AlForteStar" },
				{ t = 1.31, k = "Shake", a = 0.6, d = 0.45 },
				{ t = 1.6, k = "Trail", on = false },
			},
		},

		-- 가드(스킬): 오선 방패를 세우고 버틴다
		Guard = {
			Duration = 1.0,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.14, "backOut", PLAY, { Root = { 0, -0.2, 0.4, 0, -50, 0 }, Torso = { 6, -10, 0 }, Head = { 0, 10, 0 }, LArm = { 50, 30, 0 }, O = { 0.3, -1.6, -0.4, -40, 160, 0 }, RArm = { 90, -8, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
				K(0.7, "sineInOut", PLAY, { Root = { 0, -0.22, 0.4, 0, -50, 0 }, Torso = { 7, -10, 0 }, Head = { 0, 10, 0 }, LArm = { 50, 30, 0 }, O = { 0.3, -1.6, -0.4, -40, 160, 0 }, RArm = { 90, -8, 0 }, W = { 0, 0, 0, 0, 0, 90 } }),
				K(1.0, "sineInOut", PLAY, UP),
			},
			Events = { { t = 0.14, k = "Fx", n = "StaveShield" } },
		},

		-- 명상: 눈을 감고 줄을 튕겨(피치카토) 음을 고른다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, PLAY, UP),
				K(0.3, "sineInOut", PLAY, { Head = { -20, 34, 18 }, Torso = { 0, 10, 0 }, RArm = { 84, 44, 0 }, W = { 0, 0, 0, 70, 0, 90 } }),
				K(0.5, "expoOut", PLAY, { Head = { -20, 34, 18 }, Torso = { 0, 10, 0 }, RArm = { 90, 50, 0 }, W = { 0, 0, 0, 70, 0, 90 } }),
				K(0.8, "sineInOut", PLAY, { Head = { -22, 34, 18 }, Torso = { 0, 10, 0 }, RArm = { 84, 44, 0 }, W = { 0, 0, 0, 70, 0, 90 } }),
				K(1.0, "expoOut", PLAY, { Head = { -22, 34, 18 }, Torso = { 0, 10, 0 }, RArm = { 90, 52, 0 }, W = { 0, 0, 0, 70, 0, 90 } }),
				K(1.5, "sineInOut", PLAY, { Head = { -18, 32, 18 }, Torso = { 2, 10, 0 }, RArm = { 86, 46, 0 }, W = { 0, 0, 0, 70, 0, 90 } }),
				K(2.0, "sineInOut", PLAY, UP),
			},
			Events = {
				{ t = 0.5, k = "Fx", n = "Pizz" },
				{ t = 1.0, k = "Fx", n = "Pizz" },
				{ t = 1.1, k = "Fx", n = "Meditate" },
			},
		},
	},
}

--[[
	무대 쪽으로 몸을 더 연다(2026-09-29). 전투 카메라는 캐릭터 오른쪽 옆에서 본다. 원래 28° 만 열어서
	왼쪽 어깨의 바이올린이 머리 뒤에 묻히고 목만 앞으로 삐져나와 "머리에 총을 댄" 듯 보였다.
	모든 키의 몸 돌림(Root Y)에 STAGE_YAW 를 더해 연주 동작은 그대로 두고 보는 각도만 바꾼다.
]]
local STAGE_YAW = -22
local function open(key: any)
	local r = key.Root
	if type(r) == "table" and #r == 6 then
		key.Root = { r[1], r[2], r[3], r[4], r[5] + STAGE_YAW, r[6] }
	end
end
for _, motion in M do
	if type(motion) == "table" and motion.Keys then
		for _, key in motion.Keys do
			open(key)
		end
	end
end
for _, motion in M.Skills or {} do
	for _, key in motion.Keys or {} do
		open(key)
	end
end

return M
