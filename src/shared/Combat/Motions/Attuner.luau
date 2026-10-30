--!strict
--[[
	조율자 — 북두의 일곱 별을 지휘하는 천문가. (2026-10-25, 조건부 획득 직업)

	성격: 고요하고 단정함. 땅에 서서 지휘자처럼 손짓하면, 옆(오른쪽 뒤)에서 북두칠성 꼴로 천천히 도는 일곱 별이 따라 움직인다(빛나는 구 — [칠성]을 준 스킬·패시브 이름의 별이 켜지고, 켜진 이웃 별끼리 선으로 이어진다).
	  메그레즈 = 적을 가리키면 그 별이 빛줄기를 쏜다(열 전체) · 메라크 = 별을 집어 적의 줄 끝까지 던진다(행 전체)
	  알리오스 = 두 팔을 하늘로 들었다 내리면 별비가 진형 전체에 쏟아진다
	  셉텐트리오네스 = 두 팔을 펴면 별 일곱이 적 위로 날아가 큰 별자리를 펼치고(Orbs Sky), 두 손을 모아 쥐면 한 점으로
	                   무너져 핵융합처럼 터진다.
	무기 종류: Stars (WeaponDefinitions.SevenStars, Hand = Float). 쥐는 것이 없다 — 켜진 별(칠성)은 CombatWeapons:SetLit.
	수치: tools/combat/design/attuner_gen.py 가 이 파일을 만든다(가리키는 팔은 posecalc.point_arm). 손으로 고치지 말 것.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 대기 — 오른팔을 옆으로 비스듬히 아래로 펼쳐 별 쪽을 거느리고, 왼팔은 조금 벌려 늘어뜨린다. 오른다리로 곧게 서고 왼다리는 앞으로 비스듬히 내민다
local STANCE = { Root = { 0.1, -0.03, 0, 0, -18, 0 }, Torso = { 2, 0, 0 }, Head = { 4, -10, 0 }, RArm = { 63.8, -48.3, 0 }, LArm = { 4, 0, -32 }, RLeg = { 0, 0, 2 }, LLeg = { 20, 0, -12 } }
-- 버릇 1 — 오른팔을 몸 앞으로 감아 왼쪽까지 돌린다(몸도 왼쪽으로 조금 틀고 손끝을 본다)
local SWEEP_L = { Root = { 0.1, -0.03, 0, 0, -6, 0 }, Torso = { 2, 28, 0 }, Head = { 2, 20, 0 }, RArm = { 90.6, 52.5, 0 }, LArm = { 4, 0, -32 }, RLeg = { 0, 0, 2 }, LLeg = { 20, 0, -12 } }
-- 버릇 2 — 오른팔을 오른쪽으로 쭉 펼친다(별이 몸을 한 바퀴 빠르게 돈다) · 몸을 오른쪽으로 틀어 별을 본다
local SWEEP_R = { Root = { 0.1, 0.02, 0, 0, -22, 0 }, Torso = { 4, -10, 0 }, Head = { 8, -24, 0 }, RArm = { 96.7, -35.9, 0 }, LArm = { 4, 0, -32 }, RLeg = { 0, 0, 2 }, LLeg = { 20, 0, -12 } }
-- 가리키기 전 — 오른손을 귀 옆으로 끌어올려 겨눔을 모은다
local READY = { Root = { 0, 0, 0, 0, -26, 0 }, Torso = { 6, -4, 0 }, Head = { 4, 22, 0 }, RArm = { 150, 18, 40 }, LArm = { 40, -20, -20 }, RLeg = { -3, 0, -3 }, LLeg = { 5, 0, 4 } }
-- 메그레즈: 팔을 쭉 뻗어 적을 가리킨다(팔 축이 적 가슴 쪽), 왼팔은 뒤로 흘려 균형
local POINT = { Root = { 0, -0.05, 0, 0, -30, 0 }, Torso = { -2, -8, 0 }, Head = { 0, 26, 0 }, RArm = { 91.2, 45.1, 0 }, LArm = { -12, 0, -26 }, RLeg = { -10, 0, -4 }, LLeg = { 12, 0, 4 } }
-- 메라크 1 — 오른팔을 머리 뒤로 높이 젖혀 별을 집어 든다
local FLING_UP = { Root = { 0, 0.05, 0, 0, -22, 0 }, Torso = { 12, 6, 0 }, Head = { 18, 14, 0 }, RArm = { 168, 0, 26 }, LArm = { 60, -10, -24 }, RLeg = { 4, 0, -3 }, LLeg = { -6, 0, 4 } }
-- 메라크 2 — 내딛으며 별을 적의 줄 끝까지 던지듯 팔을 앞 아래로 뿌린다
local FLING_DOWN = { Root = { 0, -0.2, -0.2, 0, -30, 0 }, Torso = { -12, -10, 0 }, Head = { -6, 26, 0 }, RArm = { 87.6, 48, 0 }, LArm = { -20, 0, -30 }, RLeg = { -28, 0, -4 }, LLeg = { 22, 0, 4 } }
-- 알리오스 1 — 두 팔을 하늘로 V 자로 들어 별빛을 부른다
local RAISE = { Root = { 0, 0.08, 0, 0, -18, 0 }, Torso = { 12, 0, 0 }, Head = { 26, 8, 0 }, RArm = { 166, 0, 24 }, LArm = { 166, 0, -24 }, RLeg = { -2, 0, -4 }, LLeg = { 2, 0, 4 } }
-- 알리오스 2 — 두 팔을 적 진영 위로 내리 뻗어 별비를 쏟는다
local CAST = { Root = { 0, -0.12, -0.1, 0, -22, 0 }, Torso = { -8, -4, 0 }, Head = { -4, 20, 0 }, RArm = { 96, 26, 22 }, LArm = { 96, -26, -22 }, RLeg = { -16, 0, -4 }, LLeg = { 14, 0, 4 } }
-- 셉텐트리오네스 1 — 두 팔을 활짝 펴고 발끝으로 떠오르듯 선다(별 일곱이 적 위로 날아간다)
local OPEN = { Root = { 0, 0.18, 0, 0, -18, 0 }, Torso = { 14, 0, 0 }, Head = { 22, 10, 0 }, RArm = { 112, -40, 72 }, LArm = { 112, 40, -72 }, RLeg = { -6, 0, -6 }, LLeg = { -2, 0, 6 } }
-- 셉텐트리오네스 2 — 두 손을 앞으로 모아 움켜쥔다(별자리가 한 점으로 무너진다)
local CLOSE = { Root = { 0, -0.08, -0.1, 0, -24, 0 }, Torso = { -10, -6, 0 }, Head = { -2, 22, 0 }, RArm = { 92, 24, 4 }, LArm = { 92, -24, -4 }, RLeg = { -18, 0, -4 }, LLeg = { 16, 0, 4 } }
-- 방어 — 왼손바닥을 앞으로 내밀어 별 셋을 방패로, 오른손은 뒤로 감싼다
local SHIELD = { Root = { 0, -0.06, 0.25, 0, -14, 0 }, Torso = { -4, 4, 0 }, Head = { -2, 14, 0 }, RArm = { 30, 20, 30 }, LArm = { 86, -14, 0 }, RLeg = { -8, 0, -3 }, LLeg = { 10, 0, 3 } }
-- 피격 — 가슴을 맞아 상체가 뒤로 젖혀지고 두 팔이 흩어진다
local RECOIL = { Root = { 0, -0.08, 0.55, 0, -18, 0 }, Torso = { 18, 6, 0 }, Head = { 22, 8, 0 }, RArm = { 40, 0, 50 }, LArm = { 40, 0, -50 }, RLeg = { 10, 0, -4 }, LLeg = { -6, 0, 4 } }
-- 회피 — 별빛처럼 옆으로 미끄러져 비켜선다(몸을 낮추고 왼쪽으로)
local SIDESTEP = { Root = { -1.7, -0.25, 0.2, 0, -18, 6 }, Torso = { -6, 0, -8 }, Head = { 0, 12, 6 }, RArm = { 20, 0, 46 }, LArm = { 40, 0, -34 }, RLeg = { -4, 0, 12 }, LLeg = { -10, 0, -4 } }
-- 들림 — 별을 올려다보며 느슨히 매달린다(버둥대지 않음)
local DANGLE = { Root = { 0, 0.1, 0, 4, -18, 2 }, Torso = { 6, 0, 0 }, Head = { 24, 12, 0 }, RArm = { 24, 0, 22 }, LArm = { 24, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 4, 0, -3 } }
-- 내려놓임 — 무릎을 살짝 굽혀 사뿐히 내려선다
local LAND = { Root = { 0, -0.35, 0, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { -6, 8, 0 }, RArm = { 40, 10, 34 }, LArm = { 40, -10, -34 }, RLeg = { 22, 0, -4 }, LLeg = { -12, 0, 4 } }
-- 호흡 — 두 손을 가슴 앞에 모으고 고개를 들어 별을 본다
local PRAY = { Root = { 0, 0, 0, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 20, 6, 0 }, RArm = { 56, 28, -14 }, LArm = { 56, -28, 14 }, RLeg = { -3, 0, -3 }, LLeg = { 5, 0, 4 } }

return {
	Stance = STANCE,

	-- 대기: 고요한 숨(Kit.Breath, Smooth). 들숨에 펼친 오른손이 살짝 오르고, 내쉬며 고개가 별(오른쪽) 쪽으로 돈다
	Idle = Kit.Breath(STANCE, {
		Duration = 4.2,
		Chest = 2.4,
		Rise = 0.03,
		Head = -1.4,
		In = { RArm = { 70.1, -48.1, 0 } },
		Mid = { Head = { 6, -16, 0 } },
	}),

	-- 버릇(가끔, 2026-10-30 사용자 말): 오른팔을 몸 앞으로 감아 왼쪽까지 돌렸다가[중] · 오른쪽으로 쭉 펼치면[강] 별이 몸을 한 바퀴
	-- 빠르게 돌고(Orbs Whirl — 다 돌면 저절로 별자리로 돌아간다) · 펼친 채 별을 보다[약] · 대기 자세로
	Fidgets = {
		{
			Duration = 2.2,
			BlendIn = 0.3,
			BlendOut = 0.4,
			Keys = {
					K(0, nil, STANCE),
					K(0.42, "cubicInOut", SWEEP_L),
					K(0.56, "sineInOut", SWEEP_L, { Head = { 0, 16, 0 } }),
					K(0.72, "expoOut", SWEEP_R),
					K(1.45, "sineInOut", SWEEP_R, { Head = { 12, -30, 0 } }),
					K(2.2, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.72, k = "Orbs", mode = "Whirl" },
				{ t = 0.74, k = "Fx", n = "StarTwinkle" },
			},
		},
	},

	-- 들림: 별을 올려다보며 느슨히 매달려 천천히 흔들린다. 별은 머리 위 작은 원으로
	Held = {
		Duration = 3.0,
		Loop = true,
		Smooth = true,
		Keys = {
			K(0, nil, DANGLE),
			K(1.5, nil, DANGLE, { Root = { 0, 0.14, 0, -4, -14, -2 }, Head = { 20, 16, 0 } }),
		},
		Events = {
			{ t = 0, k = "Orbs", mode = "Crown" },
		},
	},

	-- 내려놓임: 사뿐히 내려서면 발밑에 별빛 고리가 퍼지고 별이 제자리(별자리)로 돌아간다
	Drop = {
		Duration = 1.0,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, DANGLE),
			K(0.14, "quadIn", LAND),
			K(0.55, "sineOut", LAND, { Root = { 0, -0.2, 0, 0, -18, 0 } }),
			K(1.0, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.14, k = "Fx", n = "Touchdown" },
			{ t = 0.3, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 피격: 가슴을 맞아 젖혀지고 별이 흩어졌다가 제자리로
	Hit = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, STANCE),
			K(0.06, "expoOut", RECOIL),
			K(0.3, "sineOut", RECOIL, { Root = { 0, -0.05, 0.5, 0, -18, 0 }, Torso = { 12, 4, 0 } }),
			K(0.75, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.02, k = "Orbs", mode = "Spread" },
			{ t = 0.5, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 방어: 왼손바닥을 내밀면 별이 앞에 세모 방패를 친다
	Guard = {
		Duration = 0.8,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, STANCE),
			K(0.08, "expoOut", SHIELD),
			K(0.24, "sineOut", SHIELD, { Root = { 0, -0.08, 0.35, 0, -14, 0 } }),
			K(0.8, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0, k = "Orbs", mode = "Shield" },
			{ t = 0.1, k = "Fx", n = "StarShield" },
			{ t = 0.6, k = "Orbs", mode = "Orbit" },
		},
	},

	-- 회피: 몸을 낮춰 별빛처럼 옆으로 미끄러지고 잔상이 남는다
	Dodge = {
		Duration = 0.75,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, STANCE),
			K(0.1, "expoOut", SIDESTEP),
			K(0.42, "sineOut", SIDESTEP, { Root = { -1.8, -0.2, 0.2, 0, -18, 4 } }),
			K(0.75, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "StarBlink" },
		},
	},

	Skills = {
		-- 메그레즈: 오른손을 귀 옆으로 끌어올렸다가 쭉 뻗어 적을 가리키면 — 메그레즈가 빛줄기를 쏘아 그 열을 위아래로 훑는다
		Megrez = {
			Duration = 1.5,
			Keys = {
				K(0, nil, STANCE),
				K(0.28, "cubicOut", READY),
				K(0.5, "expoOut", POINT),
				K(0.95, "sineOut", POINT, { Root = { 0, -0.08, 0.1, 0, -30, 0 } }),
				K(1.5, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "MegrezCharge" },
				{ t = 0.52, k = "Fx", n = "MegrezBeam" },
				{ t = 0.62, k = "Hit", i = 1, fx = "StarHit" },
				{ t = 0.63, k = "Stop", d = 0.06 },
				{ t = 0.64, k = "Shake", a = 0.25, d = 0.25 },
			},
		},

		-- 메라크: 팔을 머리 뒤로 젖혀 별을 집어 들고 — 내딛으며 적의 줄 끝까지 뿌리면 메라크가 그 줄을 꿰뚫고 달린다
		Merak = {
			Duration = 1.6,
			Keys = {
				K(0, nil, STANCE),
				K(0.32, "cubicOut", FLING_UP),
				K(0.52, "expoOut", FLING_DOWN),
				K(1.0, "sineOut", FLING_DOWN, { Root = { 0, -0.15, -0.1, 0, -30, 0 } }),
				K(1.6, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "MerakSpark" },
				{ t = 0.52, k = "Fx", n = "MerakStreak" },
				{ t = 0.66, k = "Hit", i = 1, fx = "StarHit" },
				{ t = 0.67, k = "Shake", a = 0.3, d = 0.3 },
			},
		},

		-- 알리오스: 두 팔을 하늘로 들어 알리오스를 부르고 — 적 진영 위로 내리 뻗으면 별비가 진형 전체에 쏟아진다
		Alioth = {
			Duration = 2.0,
			Keys = {
				K(0, nil, STANCE),
				K(0.45, "cubicOut", RAISE),
				K(0.8, "sineInOut", RAISE, { Root = { 0, 0.12, 0, 0, -18, 0 }, Head = { 30, 8, 0 } }),
				K(0.95, "expoOut", CAST),
				K(1.5, "sineOut", CAST, { Root = { 0, -0.16, -0.1, 0, -22, 0 } }),
				K(2.0, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.45, k = "Fx", n = "AliothCall" },
				{ t = 0.95, k = "Fx", n = "AliothRain" },
				{ t = 1.2, k = "Hit", i = 1, fx = "RainHit" },
				{ t = 1.22, k = "Shake", a = 0.4, d = 0.4 },
			},
		},

		-- 셉텐트리오네스: 두 팔을 활짝 펴면 별 일곱이 적 위로 날아가 큰 북두칠성을 펼치고 별끼리 빛줄이 이어진다 — 두 손을 모아 쥐면 별자리가 한 점으로 무너져 핵융합처럼 터진다
		Septentriones = {
			Duration = 3.0,
			Keys = {
				K(0, nil, STANCE),
				K(0.5, "cubicOut", OPEN),
				K(1.35, "sineInOut", OPEN, { Root = { 0, 0.24, 0, 0, -18, 0 }, Head = { 26, 10, 0 } }),
				K(1.6, "expoOut", CLOSE),
				K(2.3, "sineOut", CLOSE, { Root = { 0, -0.14, -0.1, 0, -24, 0 } }),
				K(3.0, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.45, k = "Orbs", mode = "Sky", at = "Enemies" },
				{ t = 0.5, k = "Fx", n = "SeptRise" },
				{ t = 1.05, k = "Fx", n = "SeptLines" },
				{ t = 1.6, k = "Orbs", mode = "Gather", at = "Enemies" },
				{ t = 1.62, k = "Fx", n = "SeptCollapse" },
				{ t = 1.9, k = "Hit", i = 1, fx = "Fusion" },
				{ t = 1.91, k = "Stop", d = 0.14 },
				{ t = 1.92, k = "Shake", a = 0.9, d = 0.6 },
				{ t = 2.4, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 가드(스킬): 별 방패를 오래 세운다
		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, STANCE),
				K(0.18, "backOut", SHIELD),
				K(0.8, "sineInOut", SHIELD, { Root = { 0, -0.08, 0.3, 0, -14, 0 } }),
				K(1.1, "sineInOut", STANCE),
			},
			Events = {
				{ t = 0, k = "Orbs", mode = "Shield" },
				{ t = 0.18, k = "Fx", n = "StarShield" },
				{ t = 0.9, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 호흡: 두 손을 가슴 앞에 모으고 별을 올려다보며 크게 들이쉬고 길게 내쉰다 — 별은 머리 위 원으로 돈다
		Meditate = {
			Duration = 2.6,
			Keys = {
				K(0, nil, STANCE),
				K(0.45, "cubicInOut", PRAY),
				K(1.1, "sineInOut", PRAY, { Root = { 0, 0.06, 0, 0, -18, 0 }, Torso = { 10, 0, 0 }, Head = { 26, 6, 0 } }),
				K(1.8, "sineInOut", PRAY, { Root = { 0, -0.06, 0, 0, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 12, 6, 0 } }),
				K(2.6, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.2, k = "Orbs", mode = "Crown" },
				{ t = 0.5, k = "Fx", n = "Meditate" },
				{ t = 2.3, k = "Orbs", mode = "Orbit" },
			},
		},
	},
}
