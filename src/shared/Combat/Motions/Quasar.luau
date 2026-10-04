--!strict
--[[
	퀘이사 — 별이 흐르는 검은 대검(츠바이핸더)을 쓰는 중력의 검사. (2026-09-28, 다시 2026-10-02)

	2026-10-02 리메이크(사용자: "우아한 대검술 쓰는 느낌 — 회피할 때나 그럴 때 대검을 순간 역수로 잡아서 골반 쪽을 방어", 레퍼런스 찾아서):
	  - 레퍼런스: 요아힘 마이어 「검술의 철저한 기술」(1570)의 츠바이핸더·롱소드 자세 — 바흐셀(낮은 옆 겨눔, 칼끝이 다리 옆 아래),
	    알버(낮게 늘어뜨림), 슈랑크훗(낮은 가로막이, 칼끝이 땅 — 아래를 막음), 네벤훗(오른 허리 뒤, 칼끝 뒤 아래), 폼 탁, 랑고르트,
	    왼쪽 옥스. "자세는 멈춰 서는 곳이 아니라 흐름 속의 한 순간"(hema101 마이어 롱소드 101) → 네벤훗 → 폼 탁 → 내려치기처럼
	    원을 그리며 잇는다(감아 올림 — 칼이 몸 옆으로 한 바퀴).
	  - 퀘이사만의 수: 막고 피할 때 대검을 **역수**로 고쳐 쥔다 — 날이 팔뚝을 따라 허리 바깥으로 지나가 골반·옆구리를 덮거나(회피),
	    허리 앞을 가로질러 면으로 막고 왼손이 날을 받친다(방어 — 슈랑크훗을 거꾸로 쥔 꼴).
	  - 쥐는 법 바로잡음: 날이 90° 꺾여 면이 손가락 마디 쪽을 보던 것을(사용자: "검을 90도 꺾어서 잡고 있어") 무기 Turn = 90 으로
	    앞날(-Z)이 마디 쪽이 되게 했다. 자세 값은 그 기준으로 다시 구했다.
	성격: 느긋하고 우아함. 꼿꼿이 서서 칼끝을 땅 가까이 늘어뜨리고 깊게 숨 쉰다. 공격은 원을 그리는 감기 → 한순간의 내려침.
	무기 종류: Great2H (WeaponDefinitions.Greatsword). 오른손 = 손잡이 윗쪽(날밑 밑, 무기 y 0), 왼손 = 폼멜 쪽 y -0.6.
	수치: tools/combat/design/quasar2_gen.py(posecalc — 두 손이 손잡이를 함께 쥐고, 땅에 닿을 칼끝은 땅 바로 위),
	      (2026-10-04 암흑기사 리메이크 뒤로는 이 파일을 손으로 고친다 — quasar_motions.py 로 다시 만들면 덮어쓴다)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 대기 — 바흐셀·알버: 몸을 오른쪽으로 틀어 왼발을 앞에, 두 손은 오른 허리 앞, 칼끝은 앞 아래 땅 가까이, 앞날은 아래
local STANCE = { Root = { 0, -0.22, 0, 0, -28, 0 }, Torso = { 2, 6, 0 }, Head = { 2, 24, 0 }, RArm = { 34.8, 37.6, -24.8 }, LArm = { 43, -66.4, 32.6 }, RLeg = { -12, 0, 10 }, LLeg = { 14, 0, -10 }, W = { -0.01, -0, -0.01, -42.9, -5, -71.1 } }
-- 경례(들림·버릇): 두 손을 명치 앞에 모으고 날을 얼굴 앞에 곧게
local SALUTE = { Root = { 0, 0, 0, 0, -20, 0 }, Torso = { 0, 0, 0 }, Head = { -4, 20, 0 }, RArm = { 69.5, 51.1, -24 }, LArm = { 43.8, -44.8, 17.1 }, RLeg = { 2, 0, 3 }, LLeg = { -2, 0, -3 }, W = { -0.01, 0, 0.01, 44.5, -71.9, 26.9 } }
-- 피격: 두 손은 그대로 몸만 뒤로 젖혀 밀림
local RECOIL = { Root = { 0, -0.32, 0.35, 0, -22, 0 }, Torso = { 12, 4, 0 }, Head = { 14, 30, 0 }, RArm = { 38.5, 30.9, -21.9 }, LArm = { 49.4, -64.4, 26.2 }, RLeg = { -18, 0, 10 }, LLeg = { 10, 0, -10 }, W = { -0.01, 0.01, -0.01, -48, 5.7, -72.3 } }
--[[
	2026-10-04 다시(사용자: 퀘이사 모션이 "좋은 듯 애매" → 레퍼런스로 FF14 암흑기사 고름, 대기는 그대로·회피를 바꿈).
	영상 https://www.youtube.com/watch?v=1-FY57YArWI 프레임으로 본 동작을 옮겼다:
	  회피   — 암흑기사 낮은 자세: 깊게 웅크려 뒤로 미끄러지고, 한 손 대검은 뒤 아래로 끌리고 왼손은 앞으로 펼친다
	  붕괴   — Salted Earth: 두 손으로 날을 거꾸로 쥐어 머리 위로 들어 올렸다가(중력이 모임) 무릎 꿇듯 발 앞 땅에 꽂는다
	  특이점 — Bloodspiller: 두 손으로 날을 머리 위 곧게 세웠다가 뛰어들 듯 수직으로 내려찍는 손짓(하늘의 검이 따라 떨어진다)
	  낙하   — Souleater: 몸을 오른쪽으로 감아 날을 뒤 아래로 끌다가 돌며 왼쪽 위로 크게 올려벤다
	  방어   — 날을 발 앞에 거꾸로 세워 꽂고 그 뒤에 웅크린다(The Blackest Night 처럼 중력 벽이 감싼다)
	칼 방향: 자세마다 원하는 날 방향(앞·아래·뒤…)을 정하고 posecalc 로 W숙임을 -360..360 에서 찾아 넣었다(앞 키와 가까운 값을 골라 최단 호로 돈다).
]]
-- 회피 1 — 뒤로 낮게 미끄러지기 시작: 상체를 숙이고 대검은 오른손 하나로 뒤 아래로 끌림, 왼손은 앞으로 펼침
local DG_START = { Root = { 0.3, -0.7, 0.5, 0, -55, 0 }, Torso = { -18, -8, 0 }, Head = { 10, 40, 0 }, RArm = { -15, 25, 10 }, LArm = { 70, -10, -30 }, RLeg = { -20, 0, 12 }, LLeg = { 25, 0, -12 }, W = { 0, 0, 0, -120, 0, -35 } }
-- 회피 2 — 더 낮게, 더 멀리(망토가 날리는 자리): 칼끝은 바닥 바로 위로 뒤를 가리킨다
local DG_LOW = { Root = { 0.9, -0.75, 0.8, 0, -70, 0 }, Torso = { -22, -12, 0 }, Head = { 12, 52, 0 }, RArm = { -20, 30, 12 }, LArm = { 80, -10, -40 }, RLeg = { -26, 0, 14 }, LLeg = { 30, 0, -14 }, W = { 0, 0, 0, -120, 0, -45 } }
-- 붕괴 1 — 두 손으로 날을 거꾸로 쥐어 가슴 앞에(날은 아래로)
local PLANT_UP = { Root = { 0, -0.25, 0, 0, -10, 0 }, Torso = { 0, 4, 0 }, Head = { 0, 10, 0 }, RArm = { 95, 20, -5 }, LArm = { 95, -25, 5 }, RLeg = { -6, 0, 8 }, LLeg = { 6, 0, -8 }, W = { 0, 0, 0, -181, 0, 0 } }
-- 붕괴 2 — 거꾸로 쥔 채 머리 위로(칼끝이 아래), 몸을 젖혀 중력을 모은다
local PLANT_HIGH = { Root = { 0, -0.15, 0.1, 0, -10, 0 }, Torso = { 10, 4, 0 }, Head = { 14, 10, 0 }, RArm = { 172, 15, 0 }, LArm = { 172, -15, 0 }, RLeg = { -8, 0, 10 }, LLeg = { 8, 0, -10 }, W = { 0, 0, 0, -251, 0, 0 } }
-- 붕괴 3 — 무릎 꿇듯 깊게 앉으며 발 앞 땅에 날을 꽂는다(Salted Earth)
local PLANT_DOWN = { Root = { 0, -1.0, -0.4, 0, -10, 0 }, Torso = { -30, 4, 0 }, Head = { 20, 10, 0 }, RArm = { 55, 15, -5 }, LArm = { 55, -15, 5 }, RLeg = { 40, 0, 10 }, LLeg = { -40, 0, -10 }, W = { 0, 0, 0, -103, 0, 0 } }
-- 한 손 랑고르트(끌어당기기): 팔·칼이 한 줄로 적을 겨누고 왼손을 뻗어 움켜쥔다
local LANG = { Root = { 0, -0.42, -0.25, 0, 40, 0 }, Torso = { -8, -4, 0 }, Head = { 6, -36, 0 }, RArm = { 99.2, -27.9, 0 }, LArm = { 90, -10, 0 }, RLeg = { 40, -20, 10 }, LLeg = { -30, 0, -10 }, W = { 0, 0, 0, -90, 0, 0 } }
-- 특이점 1 — 두 손으로 날을 머리 위 곧게(Bloodspiller 들기)
local BLOOD_UP = { Root = { 0, -0.1, 0, 0, -10, 0 }, Torso = { 10, 0, 0 }, Head = { 20, 0, 0 }, RArm = { 175, 10, 0 }, LArm = { 175, -10, 0 }, RLeg = { 8, 0, 12 }, LLeg = { -8, 0, -12 }, W = { 0, 0, 0, -92, 0, 0 } }
-- 특이점 2 — 뛰어들 듯 수직으로 내려찍은 끝: 깊게 앉아 날이 앞 아래로
local BLOOD_DOWN = { Root = { 0, -0.8, -0.4, 0, -10, 0 }, Torso = { -28, 0, 0 }, Head = { 20, 0, 0 }, RArm = { 60, 10, 0 }, LArm = { 60, -10, 0 }, RLeg = { 38, 0, 10 }, LLeg = { -36, 0, -10 }, W = { 0, 0, 0, -79, 0, 0 } }
-- 낙하 1 — 몸을 오른쪽으로 감아 웅크리고 날은 뒤 아래로 끌림(Souleater 감기)
local SOUL_WIND = { Root = { 0, -0.6, 0, 0, -80, 0 }, Torso = { -10, -20, 0 }, Head = { 6, 60, 0 }, RArm = { -20, 30, 0 }, LArm = { 50, 0, -50 }, RLeg = { -20, 0, 12 }, LLeg = { 24, 0, -12 }, W = { 0, 0, 0, -87, 0, -60 } }
-- 낙하 2 — 돌며 왼쪽 위로 크게 올려벤 끝: 오른팔이 머리 위, 날은 하늘로
local SOUL_RISE = { Root = { 0, -0.2, -0.3, 0, 60, 0 }, Torso = { 10, 20, 0 }, Head = { 10, -20, 0 }, RArm = { 160, -20, 0 }, LArm = { 40, 0, -60 }, RLeg = { 26, 0, 12 }, LLeg = { -22, 0, -12 }, W = { 0, 0, 0, -91, 0, 0 } }
-- 방어 — 날을 발 앞에 거꾸로 세워 꽂고 두 손으로 자루 끝을 누른 채 그 뒤에 웅크림
local GUARD_PLANT = { Root = { 0, -0.6, 0.2, 0, -10, 0 }, Torso = { -10, 4, 0 }, Head = { 6, 10, 0 }, RArm = { 70, 15, 0 }, LArm = { 70, -15, 0 }, RLeg = { 24, 0, 14 }, LLeg = { -18, 0, -14 }, W = { 0, 0, 0, -126, 0, 0 } }
-- 내려놓임 한가운데: 한 손으로 날을 오른쪽 아래로 크게 휘둘러 내림, 왼팔은 옆으로 펴 균형
local FLOURISH = { Root = { 0, -0.35, 0, 0, -36, 0 }, Torso = { -4, 10, 0 }, Head = { 0, 30, 0 }, RArm = { 24.7, 41.5, -3.8 }, LArm = { 70, 0, -60 }, RLeg = { -10, 0, 12 }, LLeg = { 12, 0, -12 }, W = { 0, 0, 0, -23.2, 4.5, -101.3 } }

return {
	Stance = STANCE,

	-- 대기: 깊고 느린 숨(Kit.Breath, Smooth). 칼끝을 땅 가까이 늘어뜨린 채 가슴이 오르내리고, 내쉬며 고개가 조금 돈다
	Idle = Kit.Breath(STANCE, {
		Duration = 4.0,
		Chest = 2.2,
		Rise = 0.03,
		Head = -1.2,
		Mid = { Head = { 1, 27, 0 } },
	}),

	-- 버릇(가끔): 적에게 경례하듯 날을 얼굴 앞에 세워 칼날을 비춰 보고 다시 늘어뜨린다
	Fidgets = {
		{
			Duration = 2.6,
			BlendIn = 0.3,
			BlendOut = 0.4,
			Keys = {
				K(0, nil, STANCE),
				K(0.7, "cubicInOut", SALUTE, { Head = { 10, 20, 0 } }),
				K(1.7, "sineInOut", SALUTE, { Head = { 6, 22, 0 } }),
				K(2.6, "cubicInOut", STANCE),
			},
		},
	},

	-- 들림: 경례 자세로 꼿꼿이 매달려 천천히 흔들린다(버둥대지 않음)
	Held = {
		Duration = 3.2,
		Loop = true,
		Smooth = true,
		Keys = {
			K(0, nil, SALUTE),
			K(1.6, nil, SALUTE, { Root = { 0, 0.04, 0, 2, -20, 2 }, Head = { -6, 22, 2 }, RLeg = { -2, 0, 3 }, LLeg = { 2, 0, -3 } }),
		},
	},

	-- 내려놓임: 경례 자세로 사뿐히 내려서 무릎을 굽히고 — 한 손으로 날을 오른쪽 아래로 크게 휘둘러(원) 낮은 겨눔으로
	Drop = {
		Duration = 1.3,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, SALUTE, { Root = { 0, 0.3, 0, 0, -20, 0 } }),
			K(0.12, "quadIn", SALUTE, { Root = { 0, -0.5, 0, 0, -20, 0 }, Torso = { -8, 0, 0 }, RLeg = { 26, 0, 6 }, LLeg = { -14, 0, -6 } }),
			K(0.42, "cubicOut", FLOURISH),
			K(0.8, "sineInOut", STANCE, { Root = { 0, -0.3, 0, 0, -28, 0 } }),
			K(1.3, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.12, k = "Fx", n = "HeavyLand" },
			{ t = 0.13, k = "Shake", a = 0.2, d = 0.25 },
			{ t = 0.25, k = "Trail", on = true },
			{ t = 0.6, k = "Trail", on = false },
		},
	},

	-- 피격: 거의 안 밀린다 — 몸만 뒤로 젖혀 받고 곧 낮은 겨눔으로
	Hit = {
		Duration = 0.6,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, STANCE),
			K(0.06, "expoOut", RECOIL),
			K(0.3, "sineOut", RECOIL, { Root = { 0, -0.3, 0.3, 0, -24, 0 }, Torso = { 6, 4, 0 } }),
			K(0.6, "sineInOut", STANCE),
		},
		Events = {
			{ t = 0.05, k = "Fx", n = "MassAbsorb" },
		},
	},

	-- 방어(2026-10-04): 날을 발 앞에 거꾸로 꽂고 그 뒤에 웅크려 받는다 — 중력 벽이 감싼다
	Guard = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, STANCE),
			K(0.1, "expoOut", GUARD_PLANT),
			K(0.25, "sineOut", GUARD_PLANT, { Root = { 0, -0.65, 0.3, 0, -10, 0 }, Torso = { -12, 4, 0 } }),
			K(0.75, "cubicInOut", STANCE),
		},
		Events = {
			{ t = 0.1, k = "Fx", n = "GravityWall" },
		},
	},

	-- 회피(2026-10-04 암흑기사 레퍼런스): 깊게 웅크려 뒤로 미끄러지고 한 손 대검은 뒤 아래로 끌림, 왼손은 앞으로 → 잠시 낮게 버티다 → 낮은 겨눔으로
	Dodge = {
		Duration = 1.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, STANCE),
			K(0.1, "expoOut", DG_START),
			K(0.26, "cubicOut", DG_LOW),
			K(0.5, "sineOut", DG_LOW, { Root = { 0.95, -0.72, 0.85, 0, -72, 0 } }),
			K(1.05, "sineInOut", DG_LOW, { Root = { 0.9, -0.68, 0.8, 0, -70, 0 }, Torso = { -18, -10, 0 } }),
			K(1.25, "cubicInOut", DG_START, { Root = { 0.5, -0.5, 0.5, 0, -50, 0 } }),
			K(1.7, "cubicInOut", STANCE),
		},
		Events = {
			{ t = 0.06, k = "Trail", on = true },
			{ t = 0.14, k = "Fx", n = "Deflect" },
			{ t = 0.5, k = "Trail", on = false },
		},
	},

	Skills = {
		-- 붕괴(2026-10-04 Salted Earth): 날을 거꾸로 쥐어 머리 위로 — 중력이 뭉쳐 떨리고 → 무릎 꿇듯 앉으며 땅에 꽂는다
		Collapse = {
			Duration = 2.2,
			Keys = {
				K(0, nil, STANCE),
				K(0.18, "cubicOut", PLANT_UP),
				K(0.42, "cubicInOut", PLANT_HIGH),
				K(0.6, "sineInOut", PLANT_HIGH, { Root = { 0.04, -0.15, 0.12, 0, -10, 0 }, Torso = { 10.8, 4, 0 } }),
				K(0.72, "sineInOut", PLANT_HIGH, { Root = { -0.04, -0.15, 0.13, 0, -10, 0 }, Torso = { 11.6, 4, 0 } }),
				K(0.84, "sineInOut", PLANT_HIGH, { Root = { 0.04, -0.15, 0.14, 0, -10, 0 }, Torso = { 12.4, 4, 0 } }),
				K(0.96, "sineInOut", PLANT_HIGH, { Root = { -0.03, -0.15, 0.15, 0, -10, 0 }, Torso = { 13.2, 4, 0 } }),
				K(1.08, "sineInOut", PLANT_HIGH, { Root = { 0, -0.15, 0.16, 0, -10, 0 }, Torso = { 14, 4, 0 } }),
				K(1.18, "expoOut", PLANT_DOWN),
				K(1.6, "linear", PLANT_DOWN, { Root = { 0, -0.98, -0.42, 0, -10, 0 } }),
				K(1.95, "cubicInOut", STANCE, { Root = { 0, -0.3, 0, 0, -28, 0 } }),
				K(2.2, "sineInOut", STANCE),
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

		-- 붕괴 차징(첫 사용 = 피해 없음): 거꾸로 쥔 날을 머리 위로 들어 중력을 모으고 → 한 손 랑고르트로 겨눈 채 왼손으로 적을 움켜 끌어당긴다
		CollapseCharge = {
			Duration = 1.7,
			Keys = {
				K(0, nil, STANCE),
				K(0.18, "cubicOut", PLANT_UP),
				K(0.42, "cubicInOut", PLANT_HIGH),
				K(0.6, "sineInOut", PLANT_HIGH, { Root = { 0.04, -0.15, 0.12, 0, -10, 0 }, Torso = { 10.8, 4, 0 } }),
				K(0.75, "sineInOut", PLANT_HIGH, { Root = { -0.04, -0.15, 0.13, 0, -10, 0 }, Torso = { 11.4, 4, 0 } }),
				K(0.9, "sineInOut", PLANT_HIGH, { Root = { 0.04, -0.15, 0.14, 0, -10, 0 }, Torso = { 12, 4, 0 } }),
				K(1.1, "expoOut", LANG),
				K(1.35, "sineOut", LANG, { Root = { 0, -0.44, 0.35, 0, 40, 0 }, LArm = { 70, 10, 0 } }),
				K(1.7, "sineInOut", STANCE),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Implode" },
				{ t = 1.1, k = "Fx", n = "Pull" },
				{ t = 1.12, k = "Shake", a = 0.25, d = 0.3 },
			},
		},

		-- 특이점(2026-10-04 Bloodspiller): 두 손으로 날을 머리 위 곧게 세우면 대상 위에 거대한 검 — 수직으로 내려찍는 몸짓에 떨어져 꽂힌다
		Singularity = {
			Duration = 2.2,
			Keys = {
				K(0, nil, STANCE),
				K(0.4, "cubicOut", BLOOD_UP),
				K(0.95, "sineInOut", BLOOD_UP, { Root = { 0, -0.05, 0, 0, -10, 0 }, Torso = { 14, 0, 0 } }),
				K(1.1, "expoOut", BLOOD_DOWN),
				K(1.6, "sineOut", BLOOD_DOWN, { Root = { 0, -0.78, -0.42, 0, -10, 0 }, Torso = { -26, 0, 0 } }),
				K(2.2, "sineInOut", STANCE),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "PointSky" },
				{ t = 0.5, k = "Fx", n = "SummonSword" },
				-- 2단계부터 빔(1단계엔 아무것도 안 함 — Fx 가 ctx.Stage 로 가른다)
				{ t = 0.85, k = "Fx", n = "SingularityBeam" },
				{ t = 1.1, k = "Trail", on = true },
				{ t = 1.1, k = "Fx", n = "DropSword" },
				{ t = 1.35, k = "Hit", i = 1, fx = "SingularityHit" },
				{ t = 1.36, k = "Stop", d = 0.12 },
				{ t = 1.37, k = "Shake", a = 0.7, d = 0.5 },
				{ t = 1.4, k = "Trail", on = false },
			},
		},

		-- 낙하(2026-10-04 Souleater): 오른쪽으로 감아 날을 뒤 아래로 끌다가 돌며 왼쪽 위로 크게 올려벤다
		Infall = {
			Duration = 1.3,
			Keys = {
				K(0, nil, STANCE),
				K(0.2, "cubicOut", SOUL_WIND),
				K(0.34, "expoOut", SOUL_RISE),
				K(0.7, "sineOut", SOUL_RISE, { Root = { 0, -0.25, -0.32, 0, 64, 0 } }),
				K(1.3, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.08, k = "Dash", to = "Target", gap = 4, d = 0.16 },
				{ t = 0.24, k = "Trail", on = true },
				{ t = 0.33, k = "Hit", i = 1, fx = "InfallCut" },
				{ t = 0.34, k = "Stop", d = 0.08 },
				{ t = 0.35, k = "Shake", a = 0.35, d = 0.25 },
				{ t = 0.5, k = "Trail", on = false },
				{ t = 0.85, k = "Dash", to = "Home", d = 0.28 },
			},
		},

		-- 가드(스킬): 날을 꽂고 그 뒤에서 오래 버틴다
		Guard = {
			Duration = 1.1,
			Keys = {
				K(0, nil, STANCE),
				K(0.2, "backOut", GUARD_PLANT),
				K(0.8, "sineInOut", GUARD_PLANT, { Root = { 0, -0.62, 0.25, 0, -10, 0 }, Torso = { -12, 4, 0 } }),
				K(1.1, "sineInOut", STANCE),
			},
			Events = {
				{ t = 0.2, k = "Fx", n = "GravityWall" },
			},
		},

		-- 호흡(2026-10-03 사용자: '명상' → '호흡'): 대검을 얼굴 앞에 세워 경례하듯 들고 눈을 감아, 크게 들이쉬어 가슴을 펴고 길게 내쉰다(기사의 숨 고르기)
		Meditate = {
			Duration = 2.6,
			Keys = {
				K(0, nil, STANCE),
				K(0.45, "cubicInOut", SALUTE),
				K(1.05, "sineInOut", SALUTE, { Root = { 0, 0.06, 0, 0, -20, 0 }, Torso = { 6, 0, 0 }, Head = { 6, 20, 0 } }),
				K(1.75, "sineInOut", SALUTE, { Root = { 0, -0.1, 0, 0, -20, 0 }, Torso = { -6, 0, 0 }, Head = { -14, 20, 0 } }),
				K(2.05, "sineInOut", SALUTE),
				K(2.6, "cubicInOut", STANCE),
			},
			Events = {
				{ t = 0.5, k = "Fx", n = "Meditate" },
			},
		},
	},
}
