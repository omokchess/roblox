--!strict
--[[
	연금술사 — 약병 두 개를 든 유리대포. (2026-09-28, 자세 다시 2026-09-30)

	성격: 호기심 많고 부산스러움. 던질 병을 늘 어깨 위에 들고 있고, 틈만 나면 톡 던져 올려 받는다.
	      겁이 많아 맞으면 병부터 감싸고, 피할 때는 허둥지둥 뛰어 물러난다.
	      공격은 투구 — 몸을 틀어 팔을 감았다가 크게 던진다(손의 병이 날아가고 새 병이 퐁 생긴다: Hide 사건).
	참고: 수류탄 투척 준비 자세(FM 3-23.30) — 몸을 옆으로 세워 표적에 어깨를 두고, 던질 것은 어깨 높이,
	      안 던지는 손은 45° 위로 표적을 가리킨다. 던지기는 야구공처럼 위로 넘겨 포물선.
	무기 종류: Throwable (WeaponDefinitions.Flask: W = 오른손 둥근 플라스크, O = 왼손 원통 약병)
	      병은 거의 모든 자세에서 **똑바로 선다**(세계 위쪽) — 팔 각도마다 비틀기 없이 세우는 W/O 를
	      tools/combat/posecalc.py(aim_axis)로 구했다. 붓기·마시기·다지기는 병 입이 상대 병·입에 닿게 팔 자리를 찾았다.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 투척 준비(대기): 왼 어깨를 적에게(몸을 오른쪽으로 55°), 오른손 병은 머리 옆 뒤 어깨 위, 왼팔은 45° 위로 표적을 가리킨다
local READY = { Root = { 0, -0.12, 0, 0, -55, 0 }, Torso = { -4, 10, 0 }, Head = { 4, 40, 0 }, RArm = { 140, -40, 20 }, LArm = { 122.7, 37.5, 0 }, RLeg = { -12, 0, 12 }, LLeg = { 14, 0, -14 }, W = { 0, 0, 0, -45.8, 0, 12 }, O = { 0, 0, 0, -29.5, 0, 2.4 } }
-- 감기(던지기 직전): 몸을 더 틀고 병을 머리 뒤로 / 던진 끝: 몸이 적 쪽으로 돌아 숙이고 팔이 앞 아래로 따라감
local COCK = { Root = { 0, -0.3, 0.3, 0, -85, 0 }, Torso = { 10, -10, 0 }, Head = { 6, 70, 0 }, RArm = { 165, -70, 30 }, LArm = { 111.5, 85.8, 0 }, RLeg = { -20, 0, 14 }, LLeg = { 20, 0, -14 }, W = { 0, 0, 0, -116.6, 0, 37.2 }, O = { 0, 0, 0, -22.2, 0, -10 } }
local RELEASE = { Root = { 0, -0.5, -0.5, 0, 10, 0 }, Torso = { -30, -10, 0 }, Head = { 16, -10, 0 }, RArm = { 70, 20, 10 }, LArm = { 10, 0, -40 }, RLeg = { 30, 0, 10 }, LLeg = { -30, 0, -10 }, W = { 0, 0, 0, -28.9, 0, -10.2 }, O = { 0, 0, 0, 115.4, 0, 37.2 } }
-- 다지기: 왼손 병(절구)을 배 앞에 세우고 오른손 병을 거꾸로 세워 그 입에 짓찧는다
local GRIND = { Root = { 0, -0.15, 0, 0, -30, 0 }, Torso = { -24, 0, 0 }, Head = { -24, 10, 0 }, RArm = { 130, 84, -15 }, LArm = { 60, -20, 0 }, RLeg = { 8, 0, 6 }, LLeg = { -6, 0, -6 }, W = { 0, 0, 0, -179.9, 0, -29.4 }, O = { 0, 0, 0, 52.7, 0, -8 } }
-- 붓기: 오른손 병을 기울여 왼손 병 입 위로 / 흔들기: 두 병을 머리 높이로
local POUR = { Root = { 0, -0.15, 0, 0, -30, 0 }, Torso = { -14, 0, 0 }, Head = { -18, 10, 0 }, RArm = { 142, 18, -30 }, LArm = { 70, -24, 0 }, RLeg = { 8, 0, 6 }, LLeg = { -6, 0, -6 }, W = { 0, 0, 0, -136.7, 0, 40 }, O = { 0, 0, 0, 32.8, 0, -5.6 } }
local SHAKE_HI = { Root = { 0, -0.15, 0, 0, -30, 0 }, Torso = { 0, 0, 0 }, Head = { 6, 16, 0 }, RArm = { 130, 30, 10 }, LArm = { 130, -30, -10 }, RLeg = { 8, 0, 6 }, LLeg = { -6, 0, -6 }, W = { 0, 0, 0, -39.6, 0, 6.4 }, O = { 0, 0, 0, -39.6, 0, -6.4 } }
local SHAKE_LO = W(SHAKE_HI, { Root = { 0, -0.25, 0, 0, -30, 0 }, RArm = { 110, 30, 10 }, LArm = { 110, -30, -10 }, W = { 0, 0, 0, -37, 0, 0.5 }, O = { 0, 0, 0, -26.1, 0, 13 } })
-- 마시기: 팔을 곧게 치켜들어 병을 거꾸로, 병 입이 입에 닿는다
local DRINK = { Root = { 0, -0.1, 0, 0, -30, 0 }, Torso = { 12, 0, 0 }, Head = { 34, 10, 0 }, RArm = { 178, 4, -15 }, LArm = { 40, 0, -20 }, RLeg = { 8, 0, 6 }, LLeg = { -6, 0, -6 }, W = { 0, 0, 0, 151.3, 0, 68.2 }, O = { 0, 0, 0, 36.3, 0, 12.2 } }
-- 두 병을 가슴 앞에 세워 감싼다(들림) / 등을 돌려 웅크려 품는다(방어)
local HUG = { Root = { 0, 0.1, 0, 4, -30, 4 }, Torso = { -14, 0, 0 }, Head = { -10, 30, 0 }, RArm = { 70, 44, 0 }, LArm = { 70, -44, 0 }, RLeg = { 30, 0, 6 }, LLeg = { -20, 0, -6 }, W = { 0, 0, 0, 30, 0, 4 }, O = { 0, 0, 0, 24.4, 0, -9.8 } }
local HUDDLE = { Root = { 0, -0.45, 0.3, 0, 50, 0 }, Torso = { -30, 0, 0 }, Head = { -10, -60, 0 }, RArm = { 60, 50, 0 }, LArm = { 60, -50, 0 }, RLeg = { 20, 0, 6 }, LLeg = { -10, 0, -6 }, W = { 0, 0, 0, 50.4, 0, 22.5 }, O = { 0, 0, 0, 50.4, 0, -22.5 } }
-- 비틀 착지(두 병은 세운 채 팔을 벌려 균형)
local STUMBLE = { Root = { 0.2, -0.4, 0, 0, -30, -14 }, Torso = { -20, 0, 10 }, Head = { -2, 20, 10 }, RArm = { 80, 0, 60 }, LArm = { 80, 0, -60 }, RLeg = { 20, 0, 10 }, LLeg = { -10, 0, -4 }, W = { 0, 0, 0, 19.9, 0, -22.6 }, O = { 0, 0, 0, 11.4, 0, 27.7 } }
local STUMBLE2 = { Root = { -0.2, -0.3, 0, 0, -30, 12 }, Torso = { -14, 0, -8 }, Head = { -2, 20, 10 }, RArm = { 90, 0, 50 }, LArm = { 90, 0, -70 }, RLeg = { 4, 0, 4 }, LLeg = { -4, 0, -12 }, W = { 0, 0, 0, 5.6, 0, -13.2 }, O = { 0, 0, 0, 8.8, 0, 11.4 } }
-- 병을 눈높이로 들어 무사한지 들여다봄
local PEEK = { Root = { 0, -0.1, 0, 0, -40, 0 }, Torso = { -8, 0, 0 }, Head = { 4, 26, 10 }, RArm = { 108, 6, 8 }, LArm = { 22, 0, -12 }, RLeg = { 8, 0, -2 }, LLeg = { -6, 0, 2 }, W = { 0, 0, 0, -9.8, 0, 2.2 }, O = { 0, 0, 0, 75.7, 0, 11.6 } }
-- 허둥지둥 뒤로 깡충(팔을 번쩍) → 착지
local HOP = { Root = { 0.4, 0.8, 1.6, 0, 120, 0 }, Torso = { 6, 0, 0 }, Head = { 20, -40, 0 }, RArm = { 150, 0, 60 }, LArm = { 150, 0, -60 }, RLeg = { 40, 0, 10 }, LLeg = { -30, 0, -10 }, W = { 0, 0, 0, -48.3, 0, 52.3 }, O = { 0, 0, 0, -48.3, 0, -52.3 } }
local HOP2 = { Root = { 0.6, -0.3, 1.9, 0, 30, 6 }, Torso = { -16, 0, 6 }, Head = { 0, 20, 0 }, RArm = { 90, 0, 60 }, LArm = { 90, 0, -60 }, RLeg = { 10, 0, 6 }, LLeg = { -10, 0, -6 }, W = { 0, 0, 0, -2.4, 0, -19.8 }, O = { 0, 0, 0, 18.5, 0, 7.8 } }
-- 중독: 부르르 떪 / 기운이 터짐
local SHUDDER = { Root = { 0, -0.5, 0.1, 0, -30, 0 }, Torso = { -30, 0, 0 }, Head = { -20, 20, 0 }, RArm = { 40, 20, 30 }, LArm = { 40, -20, -30 }, RLeg = { 8, 0, 6 }, LLeg = { -6, 0, -6 }, W = { 0, 0, 0, 77.9, 0, -19.5 }, O = { 0, 0, 0, 77.9, 0, 19.5 } }
local BURST = { Root = { 0, 0, 0, 0, -30, 0 }, Torso = { 16, 0, 0 }, Head = { 26, 20, 0 }, RArm = { 120, -40, 60 }, LArm = { 120, 40, -60 }, RLeg = { 4, 0, 12 }, LLeg = { -4, 0, -12 }, W = { 0, 0, 0, -13.8, 0, 41.5 }, O = { 0, 0, 0, -13.8, 0, -41.5 } }
-- 피격: 오른팔이 휙 튀어 병이 기운다(놓칠 뻔)
local JOLT = { Root = { 0, -0.1, 0.8, 0, -40, 10 }, Torso = { 12, 14, -10 }, Head = { 24, 30, 0 }, RArm = { 170, -30, 40 }, LArm = { 60, 0, -60 }, RLeg = { 8, 0, -2 }, LLeg = { -6, 0, 2 }, W = { 0, 0, 0, -105.3, 0, -8 }, O = { 0, 0, 0, 10.5, 0, 17.8 } }
-- 명상: 쪼그려 앉아 두 병을 눈 위로 들어 빛에 비춘다
local LIGHT = { Root = { 0, -1.1, 0, 0, -30, 0 }, Torso = { -6, 0, 0 }, Head = { 16, 10, 0 }, RArm = { 120, 20, 0 }, LArm = { 120, -20, 0 }, RLeg = { 90, 0, 16 }, LLeg = { 90, 0, -16 }, W = { 0, 0, 0, -24.4, 0, 2 }, O = { 0, 0, 0, -24.4, 0, -2 } }

return {
	Stance = READY,

	-- 대기: 발끝에 무게를 싣고 겨눈 채 가볍게 숨 쉰다(2026-10-02 사용자: 모든 직업 대기는 부드럽게 숨 쉬듯 — Kit.Breath, Smooth).
	-- 들숨에 어깨 위 병과 겨눈 왼팔이 살짝 올라간다(병은 세운 그대로).
	Idle = Kit.Breath(READY, {
		Duration = 3.3,
		Chest = 2.5,
		In = { RArm = { 141.5, -40, 20 }, LArm = { 124, 37.5, 0 }, W = { 0, 0, 0, -46.6, 0, 12 } },
		Mid = { LArm = { 123.2, 37.5, 0 } },
	}),

	-- 버릇(가끔, 불규칙한 간격 — CombatDirector): 병을 톡 던져 올려(병 축으로 두 바퀴 돌며) 받고 다시 겨눈다(옛 대기 동작)
	Fidgets = {
		{
			Duration = 1.7,
			BlendIn = 0.25,
			BlendOut = 0.35,
			Keys = {
				K(0.0, nil, READY),
				K(0.44, "quadOut", READY, { RArm = { 132, -40, 20 }, W = { 0, 0, 0, -38, 0, 12 } }),
				-- 던져 올림: 병을 세운 채 병 축으로 돌며 떠올랐다 떨어진다(자리 y = 병 축(위)으로 민 값)
				K(0.7, "quadOut", READY, { RArm = { 146, -40, 20 }, W = { 0, 2.4, 0, -51.8, 360, 12 }, Head = { 16, 40, 0 } }),
				K(1.0, "quadIn", READY, { W = { 0, 0, 0, -45.8, 720, 12 }, Head = { 6, 40, 0 } }),
				K(1.15, "backOut", READY, { Root = { 0, -0.2, 0, 0, -55, 0 }, W = { 0, 0, 0, -45.8, 720, 12 } }),
				K(1.7, "sineInOut", READY, { W = { 0, 0, 0, -45.8, 720, 12 } }),
			},
		},
	},

	-- 들림: 허둥지둥 — 병 두 개를 가슴에 끌어안고 다리를 파닥인다
	Held = {
		Duration = 0.5,
		Loop = true,
		Keys = {
			K(0, "sineInOut", HUG),
			K(0.25, "sineInOut", HUG, { Root = { 0, 0.14, 0, -4, -30, -4 }, Torso = { -12, 0, 0 }, Head = { -8, 0, 0 }, RArm = { 72, 44, 0 }, LArm = { 72, -44, 0 }, RLeg = { -20, 0, 6 }, LLeg = { 30, 0, -6 } }),
		},
	},

	-- 내려놓임: 비틀 착지 → 휘청 → 병이 무사한지 들어 보고 휴
	Drop = {
		Duration = 1.3,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, HUG, { Root = { 0, 0.4, 0, 0, -30, 0 } }),
			K(0.1, "quadIn", STUMBLE),
			K(0.3, "sineInOut", STUMBLE2),
			K(0.5, "sineInOut", PEEK, { Root = { 0.05, -0.2, 0, 0, -40, -4 } }),
			K(0.8, "sineInOut", PEEK, { Head = { 4, 22, 10 } }),
			K(1.0, "sineInOut", PEEK, { Torso = { 0, 0, 0 }, Head = { 14, 20, 0 }, Root = { 0, -0.05, 0, 0, -40, 0 } }),
			K(1.3, "sineInOut", READY),
		},
		Events = { { t = 0.1, k = "Fx", n = "Stumble" } },
	},

	-- 피격: 오른손 병을 놓칠 뻔 — 팔이 휙 튀고 몸이 비틀린다
	Hit = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, READY),
			K(0.05, "expoOut", JOLT),
			K(0.28, "sineOut", PEEK, { Root = { 0, -0.2, 0.7, 0, -40, 4 }, Torso = { 0, 6, -4 }, Head = { 8, 26, 0 } }),
			K(0.7, "sineInOut", READY),
		},
		Events = { { t = 0.05, k = "Fx", n = "Slosh" } },
	},

	-- 방어: 적에게 등을 돌려 웅크리고 병 두 개를 품에 감싼다
	Guard = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, READY),
			K(0.08, "expoOut", HUDDLE),
			K(0.24, "sineOut", HUDDLE, { Root = { 0, -0.5, 0.5, 0, 54, 0 }, Torso = { -32, 0, 0 } }),
			K(0.75, "sineInOut", READY),
		},
		Events = { { t = 0.1, k = "Fx", n = "Huddle" } },
	},

	-- 회피: 허둥지둥 뒤로 깡충 — 반 바퀴 돌았다 되돌아서며 휘청
	Dodge = {
		Duration = 0.8,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, READY),
			K(0.06, "quadOut", READY, { Root = { 0, -0.35, 0, 0, -55, 0 }, Torso = { -18, 10, 0 } }),
			K(0.24, "cubicOut", HOP),
			K(0.42, "quadIn", HOP2),
			K(0.8, "sineInOut", READY, { Root = { 0.2, -0.15, 0.6, 0, -55, 0 } }),
		},
		Events = { { t = 0.42, k = "Fx", n = "Stumble" } },
	},

	Skills = {
		-- 다지기: 왼손 병을 절구 삼아 배 앞에 세우고, 오른손 병을 거꾸로 세워 그 입에 빙빙 짓찧는다
		Grind = {
			Duration = 1.6,
			Keys = {
				K(0, nil, READY),
				K(0.25, "cubicOut", GRIND),
				K(0.45, "sineInOut", GRIND, { RArm = { 126, 80, -15 } }),
				K(0.65, "sineInOut", GRIND, { RArm = { 132, 88, -12 } }),
				K(0.85, "sineInOut", GRIND, { RArm = { 128, 82, -18 } }),
				K(1.05, "sineInOut", GRIND, { RArm = { 132, 87, -13 } }),
				K(1.25, "sineInOut", GRIND, { RArm = { 126, 81, -15 }, Torso = { -22, 0, 0 }, Head = { -20, 10, 0 } }),
				K(1.6, "sineInOut", READY),
			},
			Events = {
				{ t = 0.45, k = "Fx", n = "GrindPuff" },
				{ t = 0.85, k = "Fx", n = "GrindPuff" },
				{ t = 1.25, k = "Fx", n = "GrindDone" },
			},
		},

		-- 섞기: 오른손 병을 기울여 왼손 병에 붓고 — 두 병을 칵테일처럼 머리 높이에서 마구 흔든다
		Mix = {
			Duration = 1.9,
			Keys = {
				K(0, nil, READY),
				K(0.3, "cubicOut", POUR),
				K(0.8, "sineInOut", POUR, { Head = { -20, 10, 0 }, RArm = { 143, 17, -30 } }),
				-- 흔들기
				K(1.0, "cubicOut", SHAKE_HI),
				K(1.08, "linear", SHAKE_LO),
				K(1.16, "linear", SHAKE_HI),
				K(1.24, "linear", SHAKE_LO),
				K(1.32, "linear", SHAKE_HI),
				K(1.4, "linear", SHAKE_LO),
				K(1.9, "sineInOut", READY),
			},
			Events = {
				{ t = 0.35, k = "Fx", n = "Pour" },
				{ t = 1.0, k = "Fx", n = "Fizz" },
				{ t = 1.45, k = "Fx", n = "MixDone" },
			},
		},

		-- 던지기: 몸을 틀어 팔을 머리 뒤로 감았다가 위로 넘겨 크게 던진다 — 병이 포물선을 그려 깨진다. 손엔 새 병이 퐁
		Throw = {
			Duration = 1.6,
			Keys = {
				K(0, nil, READY),
				K(0.35, "cubicOut", COCK),
				K(0.45, "sineIn", COCK, { Root = { 0, -0.34, 0.4, 0, -90, 0 }, Torso = { 12, -12, 0 } }),
				K(0.52, "expoOut", RELEASE),
				K(0.9, "sineOut", RELEASE, { Root = { 0, -0.46, -0.45, 0, 10, 0 } }),
				K(1.6, "sineInOut", READY),
			},
			Events = {
				{ t = 0.5, k = "Hide", slot = "W", on = true },
				{ t = 0.5, k = "Fx", n = "Lob" },
				{ t = 0.95, k = "Hit", i = 1, fx = "Shatter" },
				{ t = 0.96, k = "Shake", a = 0.35, d = 0.3 },
				{ t = 1.2, k = "Hide", slot = "W", on = false },
				{ t = 1.2, k = "Fx", n = "Pop" },
			},
		},

		-- 중독: 병을 거꾸로 들어 입에 대고 꿀꺽꿀꺽 — 부르르 떨더니 초록 기운이 터진다
		Poisoning = {
			Duration = 2.2,
			Keys = {
				K(0, nil, READY),
				K(0.3, "cubicOut", DRINK),
				K(0.45, "sineInOut", DRINK, { Torso = { 14, 0, 0 }, Head = { 37, 10, 0 } }),
				K(0.6, "sineInOut", DRINK),
				K(0.75, "sineInOut", DRINK, { Torso = { 15, 0, 0 }, Head = { 38, 10, 0 } }),
				-- 부르르
				K(1.0, "expoOut", SHUDDER),
				K(1.08, "linear", SHUDDER, { Root = { 0.1, -0.5, 0.1, 0, -30, 4 }, Torso = { -30, 0, 4 } }),
				K(1.16, "linear", SHUDDER, { Root = { -0.1, -0.5, 0.1, 0, -30, -4 }, Torso = { -30, 0, -4 } }),
				K(1.24, "linear", SHUDDER, { Root = { 0.1, -0.5, 0.1, 0, -30, 4 }, Torso = { -30, 0, 4 } }),
				-- 기운이 터짐
				K(1.4, "backOut", BURST),
				K(1.8, "sineOut", BURST, { Torso = { 14, 0, 0 }, Head = { 20, 20, 0 }, RArm = { 116, -40, 58 }, LArm = { 116, 40, -58 } }),
				K(2.2, "sineInOut", READY),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "Gulp" },
				{ t = 1.0, k = "Fx", n = "Shudder" },
				{ t = 1.4, k = "Fx", n = "ToxicAura" },
				{ t = 1.42, k = "Hit", i = 1, fx = "ToxicHit" },
				{ t = 1.43, k = "Shake", a = 0.3, d = 0.3 },
			},
		},

		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, READY),
				K(0.14, "backOut", HUDDLE),
				K(0.8, "sineInOut", HUDDLE, { Root = { 0, -0.47, 0.3, 0, 50, 0 }, Torso = { -31, 0, 0 } }),
				K(1.1, "sineInOut", READY),
			},
			Events = { { t = 0.14, k = "Fx", n = "Huddle" } },
		},

		-- 명상: 쪼그려 앉아 두 병을 나란히 들어 빛에 비춰 본다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, READY),
				K(0.4, "cubicInOut", LIGHT),
				K(1.5, "sineInOut", LIGHT, { Torso = { -4, 0, 0 }, Head = { 20, 14, 0 } }),
				K(2.0, "sineInOut", READY),
			},
			Events = { { t = 0.5, k = "Fx", n = "Meditate" } },
		},
	},
}
