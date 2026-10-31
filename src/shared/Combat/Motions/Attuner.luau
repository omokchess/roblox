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

-- 대기 — 발끝을 내린 채 떠서, 앞 오른쪽으로 내민 오른손 위에 뜬 북두칠성을 고개 숙여 내려다본다. 왼팔은 힘을 빼 뒤로 흘린다
local STANCE = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 6, -8, 0 }, Head = { -10, -26, 4 }, RArm = { 86.1, -0.9, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 버릇 — 별을 받친 오른손을 눈높이로 들어 올리고 고개를 들어 별을 본다(별이 손을 따라 오르며 차례로 반짝인다)
local OFFER = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 10, -10, 0 }, Head = { 8, -24, 2 }, RArm = { 103.7, 2.6, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 메그레즈 1 — 꺼낸 별을 손끝에 띄운 채 오른팔을 몸 앞으로 감아 왼쪽으로 가져간다(몸도 왼쪽으로 틂)
local MEG_L = { Root = { 0, 0.7, 0, 0, -6, 0 }, Torso = { 4, 26, 0 }, Head = { 2, 16, 0 }, RArm = { 93.4, 52.7, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 메그레즈 2 — 오른쪽으로 확 뿌려 별을 대상 열로 날린다(팔이 앞 오른쪽으로 쭉, 고개는 적 쪽)
local MEG_R = { Root = { 0, 0.7, -0.1, 0, -24, 0 }, Torso = { 0, -14, 0 }, Head = { -2, 18, 0 }, RArm = { 94.1, 2.8, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 메라크 1 — 꺼낸 별을 왼쪽 아래로 끌어내린다(오른손이 왼 무릎 앞, 몸을 왼쪽으로 숙여 튼다)
local MER_LOW = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { -8, 20, 0 }, Head = { -12, 18, 0 }, RArm = { 62.7, 69.8, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 메라크 2 — 팔을 오른쪽 위로 휘둘러 별을 내 행으로 돌진시킨다(몸을 펴 젖히고 오른쪽으로 튼다)
local MER_UP = { Root = { 0, 0.76, 0, 0, -24, 0 }, Torso = { 10, -14, 0 }, Head = { 12, 4, 0 }, RArm = { 116, 5.2, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 알리오스 0 — 꺼낸 별을 손끝에 띄워 적 진영 쪽으로 들어 올린다
local AL_READY = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 4, -6, 0 }, Head = { 0, 16, 0 }, RArm = { 104.8, 4.9, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 알리오스 손짓 A — 왼 위로 크게 그어 올린다
local AL_A = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 6, 16, 0 }, Head = { 10, 18, 0 }, RArm = { 123.6, 50, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 알리오스 손짓 B — 오른 아래로 내리긋는다
local AL_B = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { -6, -14, 0 }, Head = { -8, 10, 0 }, RArm = { 68.1, -3.8, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 알리오스 손짓 C — 앞 위로 찌르듯 뻗는다
local AL_C = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 8, 16, 0 }, RArm = { 112, 26.2, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 알리오스 손짓 D — 오른쪽으로 가로 휘두른다
local AL_D = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 2, -16, 0 }, Head = { 0, 8, 0 }, RArm = { 94, -23.2, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 셉텐트리오네스 1 — 오른손을 왼 허리로 끌어 모은다(별자리가 손을 따라 허리춤으로, 몸을 왼쪽으로 숙여 튼다)
local SEPT_LOW = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { -6, 22, 0 }, Head = { -14, 14, 0 }, RArm = { 62.6, 86.4, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 셉텐트리오네스 2 — 오른팔을 하늘 높이 치켜든다(별 일곱이 하늘로 — 몸을 젖히고 올려다본다)
local SEPT_UP = { Root = { 0, 0.8, 0, 0, -18, 0 }, Torso = { 12, -4, 0 }, Head = { 30, 4, 0 }, RArm = { 133.3, 16, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 셉텐트리오네스 3 — 치켜든 팔을 적 진영으로 내리친다(별자리가 진형을 강타)
local SEPT_DOWN = { Root = { 0, 0.62, -0.1, 0, -22, 0 }, Torso = { -10, -8, 0 }, Head = { -10, 14, 0 }, RArm = { 77.2, 15.2, 0 }, LArm = { -14, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 10, 0, 6 } }
-- 방어 — 왼손바닥을 앞으로 내밀어 별 셋을 방패로, 오른손은 뒤로 감싼다
local SHIELD = { Root = { 0, 0.64, 0.25, 0, -14, 0 }, Torso = { -4, 4, 0 }, Head = { -2, 14, 0 }, RArm = { 30, 20, 30 }, LArm = { 86, -14, 0 }, RLeg = { -8, 0, -3 }, LLeg = { 10, 0, 3 } }
-- 피격 — 가슴을 맞아 상체가 뒤로 젖혀지고 두 팔이 흩어진다
local RECOIL = { Root = { 0, 0.62, 0.55, 0, -18, 0 }, Torso = { 18, 6, 0 }, Head = { 22, 8, 0 }, RArm = { 40, 0, 50 }, LArm = { 40, 0, -50 }, RLeg = { 10, 0, -4 }, LLeg = { -6, 0, 4 } }
-- 회피 — 별빛처럼 옆으로 미끄러져 비켜선다(몸을 낮추고 왼쪽으로)
local SIDESTEP = { Root = { -1.7, 0.45, 0.2, 0, -18, 6 }, Torso = { -6, 0, -8 }, Head = { 0, 12, 6 }, RArm = { 20, 0, 46 }, LArm = { 40, 0, -34 }, RLeg = { -4, 0, 12 }, LLeg = { -10, 0, -4 } }
-- 들림 — 별을 올려다보며 느슨히 매달린다(버둥대지 않음)
local DANGLE = { Root = { 0, 0.8, 0, 4, -18, 2 }, Torso = { 6, 0, 0 }, Head = { 24, 12, 0 }, RArm = { 24, 0, 22 }, LArm = { 24, 0, -22 }, RLeg = { -6, 0, 3 }, LLeg = { 4, 0, -3 } }
-- 내려놓임 — 무릎을 살짝 굽혀 사뿐히 내려선다
local LAND = { Root = { 0, -0.35, 0, 0, -18, 0 }, Torso = { -10, 0, 0 }, Head = { -6, 8, 0 }, RArm = { 40, 10, 34 }, LArm = { 40, -10, -34 }, RLeg = { 22, 0, -4 }, LLeg = { -12, 0, 4 } }
-- 호흡 — 두 손을 가슴 앞에 모으고 고개를 들어 별을 본다
local PRAY = { Root = { 0, 0.7, 0, 0, -18, 0 }, Torso = { 6, 0, 0 }, Head = { 20, 6, 0 }, RArm = { 56, 28, -14 }, LArm = { 56, -28, 14 }, RLeg = { -3, 0, -3 }, LLeg = { 5, 0, 4 } }

return {
	Stance = STANCE,

	-- 대기: 떠서 숨 쉰다(Kit.Breath, Smooth) — 들숨에 몸이 천천히 떠오르고(Rise 0.14) 별을 받친 손이 살짝 오르며, 내쉬며 고개가 별 쪽으로
	Idle = Kit.Breath(STANCE, {
		Duration = 4.4,
		Chest = 2.2,
		Rise = 0.14,
		Head = -1.2,
		In = { RArm = { 89.6, -0.9, 0 } },
		Mid = { Head = { -8, -22, 4 } },
	}),

	-- 버릇(가끔): 별을 받친 손을 천천히 눈높이로 들어 올리면[약중] 별이 국자를 따라 손잡이 끝부터 차례로 반짝이고(StarTwinkle) ·
	-- 잠깐 바라보다[약] · 손을 내려 받쳐 든다[중]. 별은 손을 따라 오르내릴 뿐 돌지 않는다
	Fidgets = {
		{
			Duration = 2.4,
			BlendIn = 0.3,
			BlendOut = 0.4,
			Keys = {
					K(0, nil, STANCE),
					K(0.7, "sineInOut", OFFER),
					K(1.5, "sineInOut", OFFER, { Head = { 12, -22, 2 } }),
					K(2.4, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.75, k = "Fx", n = "StarTwinkle" },
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
			K(1.5, nil, DANGLE, { Root = { 0, 0.84, 0, -4, -14, -2 }, Head = { 20, 16, 0 } }),
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
			K(0.3, "sineOut", RECOIL, { Root = { 0, 0.65, 0.5, 0, -18, 0 }, Torso = { 12, 4, 0 } }),
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
			K(0.24, "sineOut", SHIELD, { Root = { 0, 0.62, 0.35, 0, -14, 0 } }),
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
			K(0.42, "sineOut", SIDESTEP, { Root = { -1.8, 0.5, 0.2, 0, -18, 4 } }),
			K(0.75, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "StarBlink" },
		},
	},

	Skills = {
		-- 메그레즈: 손 위 별무리에서 메그레즈를 꺼내(나머지는 허리춤으로)[약] 팔을 왼쪽으로 가져갔다가[중] 오른쪽으로 확 뿌리면[강] 별이 대상 열로 날아가 열을 가로질러 훑고 손끝으로 돌아온다
		Megrez = {
			Duration = 1.95,
			Keys = {
				K(0, nil, STANCE),
				K(0.4, "cubicInOut", MEG_L),
				K(0.52, "sineInOut", MEG_L, { Head = { 0, 20, 0 } }),
				K(0.62, "expoOut", MEG_R),
				K(1.0, "sineOut", MEG_R, { Root = { 0, 0.66, -0.14, 0, -26, 0 } }),
				K(1.85, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.08, k = "Orbs", mode = "Pick", star = 1 },
				{ t = 0.1, k = "Fx", n = "TeleGrab", star = 1 },
				{ t = 0.6, k = "Fx", n = "MegrezFling" },
				{ t = 0.78, k = "Hit", i = 1, fx = "StarHit" },
				{ t = 0.79, k = "Stop", d = 0.05 },
				{ t = 0.8, k = "Shake", a = 0.3, d = 0.25 },
				{ t = 1.45, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 메라크: 메라크를 꺼내[약] 왼쪽 아래로 끌어내렸다가[중] 팔을 오른쪽 위로 휘두르면[강] 별이 내 행을 꿰뚫고 달리며 흰 선을 남기고(1타), 그 선이 네 번 부분부분 터지고 다섯 번째에 통째로 터진다(10 · 2 · 2 · 2 · 2 · 4)
		Merak = {
			Duration = 2.4,
			Keys = {
				K(0, nil, STANCE),
				K(0.42, "cubicInOut", MER_LOW),
				K(0.6, "sineInOut", MER_LOW, { Head = { -14, 22, 0 } }),
				K(0.72, "expoOut", MER_UP),
				K(1.3, "sineOut", MER_UP, { Root = { 0, 0.8, 0, 0, -26, 0 } }),
				K(2.3, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.08, k = "Orbs", mode = "Pick", star = 2 },
				{ t = 0.1, k = "Fx", n = "TeleGrab", star = 2 },
				{ t = 0.7, k = "Fx", n = "MerakDash" },
				{ t = 0.85, k = "Hit", i = 1, fx = "MerakPass" },
				{ t = 0.86, k = "Shake", a = 0.3, d = 0.25 },
				{ t = 1.2, k = "Hit", i = 2, fx = "MerakBurst" },
				{ t = 1.36, k = "Hit", i = 3, fx = "MerakBurst" },
				{ t = 1.52, k = "Hit", i = 4, fx = "MerakBurst" },
				{ t = 1.68, k = "Hit", i = 5, fx = "MerakBurst" },
				{ t = 1.95, k = "Hit", i = 6, fx = "MerakBurst" },
				{ t = 1.96, k = "Shake", a = 0.5, d = 0.35 },
				{ t = 2.05, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 알리오스: 알리오스를 꺼내 적 진영 위로 띄우고[약] 허공에 팔을 자유자재로 휘두를 때마다[강] 별이 진형을 곧게 가로지른다 — 10타가 0.5 · 0.45 · 0.2 · 0.15 … 초 간격으로 점점 빨라진다(사용자 원안의 두 배 빠르기) → 별이 손끝으로 돌아온다
		Alioth = {
			Duration = 3.0,
			Keys = {
				K(0, nil, STANCE),
				K(0.15, "cubicOut", AL_READY),
				K(0.315, "sineInOut", AL_READY),
				K(0.375, "expoOut", AL_A),
				K(0.815, "sineInOut", AL_A),
				K(0.875, "expoOut", AL_B),
				K(1.265, "sineInOut", AL_B),
				K(1.325, "expoOut", AL_C),
				K(1.465, "sineInOut", AL_C),
				K(1.525, "expoOut", AL_D),
				K(1.615, "sineInOut", AL_D),
				K(1.675, "expoOut", AL_A),
				K(1.765, "sineInOut", AL_A),
				K(1.825, "expoOut", AL_B),
				K(1.915, "sineInOut", AL_B),
				K(1.975, "expoOut", AL_C),
				K(2.065, "sineInOut", AL_C),
				K(2.125, "expoOut", AL_D),
				K(2.215, "sineInOut", AL_D),
				K(2.275, "expoOut", AL_A),
				K(2.365, "sineInOut", AL_A),
				K(2.425, "expoOut", AL_B),
				K(2.625, "sineOut", AL_B),
				K(2.95, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.06, k = "Orbs", mode = "Pick", star = 3 },
				{ t = 0.07, k = "Fx", n = "TeleGrab", star = 3 },
				{ t = 0.175, k = "Fx", n = "AliothLaunch" },
				{ t = 0.375, k = "Hit", i = 1, fx = "AliothStrike" },
				{ t = 0.875, k = "Hit", i = 2, fx = "AliothStrike" },
				{ t = 1.325, k = "Hit", i = 3, fx = "AliothStrike" },
				{ t = 1.525, k = "Hit", i = 4, fx = "AliothStrike" },
				{ t = 1.675, k = "Hit", i = 5, fx = "AliothStrike" },
				{ t = 1.825, k = "Hit", i = 6, fx = "AliothStrike" },
				{ t = 1.975, k = "Hit", i = 7, fx = "AliothStrike" },
				{ t = 2.125, k = "Hit", i = 8, fx = "AliothStrike" },
				{ t = 2.275, k = "Hit", i = 9, fx = "AliothStrike" },
				{ t = 2.425, k = "Hit", i = 10, fx = "AliothStrike" },
				{ t = 0.375, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 0.875, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 1.325, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 1.525, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 1.675, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 1.825, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 1.975, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 2.125, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 2.275, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 2.425, k = "Shake", a = 0.15, d = 0.1 },
				{ t = 2.5, k = "Fx", n = "AliothReturn" },
				{ t = 2.7, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 셉텐트리오네스(컷신): 오른손을 왼 허리로 모았다가[중] 하늘로 치켜들면[강] 별 일곱이 하늘 높이 오르고 → 별이 하나씩 적 진영으로 레이저(별 이름 · 화면 색 · 카메라가 별 → 레이저를 따라 아래로) → 팔을 내리치면[강] 북두칠성 꼴로 진형 전체를 강타하고 선 자국이 남는다
		Septentriones = {
			Duration = 10.8,
			Keys = {
				K(0, nil, STANCE),
				K(0.3, "cubicOut", SEPT_LOW),
				K(0.75, "sineInOut", SEPT_LOW, { Head = { -16, 16, 0 } }),
				K(0.95, "expoOut", SEPT_UP),
				K(4.5, "sineInOut", SEPT_UP, { Root = { 0, 0.86, 0, 0, -18, 0 }, Head = { 26, 6, 0 } }),
				K(8.6, "sineInOut", SEPT_UP, { Root = { 0, 0.9, 0, 0, -20, 0 } }),
				K(8.95, "expoOut", SEPT_DOWN),
				K(9.6, "sineOut", SEPT_DOWN, { Root = { 0, 0.58, -0.12, 0, -24, 0 } }),
				K(10.6, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.95, k = "Orbs", mode = "Sky", at = "Enemies" },
				{ t = 0.95, k = "Fx", n = "SeptRise", d = 1.1, total = 9.5 },
				{ t = 2.1, k = "Fx", n = "SeptLaser", star = 4, nth = 1 },
				{ t = 2.57, k = "Hit", i = 1, fx = "SeptLaserHit" },
				{ t = 2.57, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 3.05, k = "Fx", n = "SeptLaser", star = 5, nth = 2 },
				{ t = 3.52, k = "Hit", i = 2, fx = "SeptLaserHit" },
				{ t = 3.52, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 4.0, k = "Fx", n = "SeptLaser", star = 3, nth = 3 },
				{ t = 4.47, k = "Hit", i = 3, fx = "SeptLaserHit" },
				{ t = 4.47, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 4.95, k = "Fx", n = "SeptLaser", star = 1, nth = 4 },
				{ t = 5.42, k = "Hit", i = 4, fx = "SeptLaserHit" },
				{ t = 5.42, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 5.9, k = "Fx", n = "SeptLaser", star = 6, nth = 5 },
				{ t = 6.37, k = "Hit", i = 5, fx = "SeptLaserHit" },
				{ t = 6.37, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 6.85, k = "Fx", n = "SeptLaser", star = 2, nth = 6 },
				{ t = 7.32, k = "Hit", i = 6, fx = "SeptLaserHit" },
				{ t = 7.32, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 7.8, k = "Fx", n = "SeptLaser", star = 7, nth = 7 },
				{ t = 8.27, k = "Hit", i = 7, fx = "SeptLaserHit" },
				{ t = 8.27, k = "Shake", a = 0.8, d = 0.4 },
				{ t = 8.62, k = "Fx", n = "SeptGather" },
				{ t = 9.05, k = "Hit", i = 8, fx = "SeptSlam" },
				{ t = 9.06, k = "Stop", d = 0.12 },
				{ t = 9.07, k = "Shake", a = 3, d = 1.3 },
				{ t = 9.9, k = "Orbs", mode = "Orbit" },
			},
		},

		-- 가드(스킬): 별 방패를 오래 세운다
		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, STANCE),
				K(0.18, "backOut", SHIELD),
				K(0.8, "sineInOut", SHIELD, { Root = { 0, 0.62, 0.3, 0, -14, 0 } }),
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
				K(1.1, "sineInOut", PRAY, { Root = { 0, 0.76, 0, 0, -18, 0 }, Torso = { 10, 0, 0 }, Head = { 26, 6, 0 } }),
				K(1.8, "sineInOut", PRAY, { Root = { 0, 0.64, 0, 0, -18, 0 }, Torso = { 0, 0, 0 }, Head = { 12, 6, 0 } }),
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
