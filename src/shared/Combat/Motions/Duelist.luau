--!strict
--[[
	결투사 — 레이피어 펜서. (2026-09-28, 자세 다시 2026-09-30)

	성격: 절제·정밀·빠름. 옆으로 선 펜싱 자세(오른 어깨가 적을 봄), 뒷손은 주머니에 꽂은 여유.
	      움직임은 짧고 날카롭게(expoOut), 큰 동작 없이 **선 하나**로 찌른다. 축은 패링.
	참고: 카포 페로(1610) 테르차 — 앞팔을 적에게 뻗어 칼끝을 적 얼굴에, 손보호 고리는 아래.
	      검 끝을 쏘아라 = 가토츠(칼을 머리 옆으로 끌어 수평 겨눔, 앞손이 조준선).
	무기 종류: Thrust1H (WeaponDefinitions.Rapier)
	사건 이름(k): Hit(i = 몇 번째 타격) · Dash(to = Target/Home/Far, gap = 대상 앞 거리, 음수면 뚫고 지나감 · Far = 적 진영 맨 끝 너머 past 스터드)
	              Fx(n = ClassFx.Duelist 의 이름) · Trail(on) · Shake(a, d) · Stop(d = 타격 정지)
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K, W = Kit.K, Kit.With

-- 기본 자세(사용자 지정 2026-09-30 `스탠딩/직업 베이스 모션.md`, 다시 2026-10-02 "너가 나를 이길 수 있을 것 같아?" 느낌):
--   몸을 62° 옆으로 틀어 오른 어깨를 적에게 두고, 오른팔을 어깨 높이로 쭉 뻗어 **적 가슴을 정확히 겨눈다**(팔 축이 적 쪽 —
--   tools/combat/design/duelist_gen.py 의 point_arm). 상체는 뒤로 12° 젖히고 고개는 적 쪽으로 돌려 턱을 든 채 내려다본다.
--   칼은 팔 선과 한 줄(숙임 -90)로 정면(2026-10-02 사용자: "완전히 정면으로" — 처음 지정의 "30° 비스듬히" 대신).
--   칼끝은 아래로 안 간다. 손보호 고리는 아래(6시).
--   손목은 날 축을 중심으로 오른쪽으로 30° 돌린다(W 비틀기 +30 — 뒤에서 보아 시계 방향, 2026-10-02 사용자: "완전 똑바로 말고 손목을 약간 돌린 것처럼").
--   왼손은 주머니에 꽂은 듯 — 앞·안쪽으로 살짝 기울인다(2026-10-02 사용자: 바깥 뒤로 기울인 것의 반대로).
--   큰 기술·피격 때만 빠져나온다. 앞발은 적 쪽, 뒷발은 옆으로.
local POCKET = { 14, -6, 10 }
local EG = { Root = { 0, -0.12, 0, 0, 62, 0 }, Torso = { 12, -6, 0 }, Head = { -4, -54, 4 }, RArm = { 82.7, -47.5, 0 }, LArm = POCKET, RLeg = { 16, -38, 10 }, LLeg = { -10, 0, -12 }, W = { 0, 0, 0, -90, 30, 0 } }
-- 숨: 들이쉬며 조금 더 젖혀 뽐냈다가(IN) 내쉬며 가라앉음(OUT) — 팔 겨눔은 자세마다 다시 계산해 흔들리지 않는다
local EG_IN = { Root = { 0, -0.1, 0, 0, 62, 0 }, Torso = { 15, -6, 1 }, Head = { -6, -54, 5 }, RArm = { 79.9, -47.5, 0 }, LArm = { 16, -6, 11 } }
local EG_OUT = { Root = { 0, -0.15, 0, 0, 62, 0 }, Torso = { 10, -6, -1 }, Head = { -3, -53, 3 }, RArm = { 85.1, -47.5, 0 }, LArm = { 12, -6, 9 } }
-- 찌르기 끝(런지): 팔·칼이 한 줄로 적 가슴을 꿰뚫는다(칼 = 팔 연장선). 왼손은 주머니 근처 그대로 — 여유
local LUNGE = W(EG, {
	Root = { 0, -0.62, -0.5, 0, 40, 0 },
	Torso = { -14, -6, 0 },
	Head = { 10, -32, 0 },
	RArm = { 102, -23, 0 },
	LArm = { -18, 0, 8 },
	RLeg = { 56, -20, 10 },
	LLeg = { -40, 0, -10 },
	W = { 0, 0, 0, -90, 0, 0 },
})
-- 몸을 다 던진 깊은 런지(마지막 한 방)
local DEEP = W(LUNGE, {
	Root = { 0, -0.8, -0.7, 0, 36, 0 },
	Torso = { -24, -8, 0 },
	Head = { 18, -28, 0 },
	RArm = { 114, -18, 0 },
	RLeg = { 66, -20, 10 },
	LLeg = { -50, 0, -10 },
})
-- 앞뒤관통 준비동작(2026-10-02 사용자: "오른쪽 아래로 검을 한번 휘둘렀다가, 펜싱처럼 찌르기 준비" — tools/combat/design/duelist_fbp.py)
--   RISE 칼끝을 왼쪽 위로 살짝 → SWISH 오른쪽 아래로 휙(칼끝은 땅 위 0.7) → COCK 뒷발에 무게, 손을 오른 허리 앞으로 당기고 칼끝은 적 가슴
--   COCK2 두 번째(더 강하게): 더 낮고 깊게, 왼팔을 뒤 위로 들어 균형(고전 펜싱 앙가르드)
local RISE = { Root = { 0, -0.12, 0, 0, 58, 0 }, Torso = { 10, -6, 0 }, Head = { -4, -52, 4 }, RArm = { 102.2, -29.2, -12.8 }, LArm = POCKET, RLeg = { 16, -38, 10 }, LLeg = { -10, 0, -12 }, W = { 0, 0, 0, -77.4, 0, -8.3 } }
local SWISH = { Root = { 0, -0.22, 0, 0, 52, 0 }, Torso = { 4, -10, -2 }, Head = { -2, -46, 4 }, RArm = { 45.3, -62.1, 17.2 }, LArm = POCKET, RLeg = { 16, -38, 10 }, LLeg = { -10, 0, -12 }, W = { 0, 0, 0, -66.9, 0, -6 } }
local COCK = { Root = { 0, -0.48, 0.38, 0, 48, 0 }, Torso = { 2, -6, 0 }, Head = { -2, -44, 2 }, RArm = { 40.1, -41.5, -0.7 }, LArm = POCKET, RLeg = { 30, -26, 12 }, LLeg = { -26, 0, -14 }, W = { 0, 0, 0, -30.8, 0, 8.2 } }
local COCK2 = { Root = { 0, -0.66, 0.5, 0, 44, 0 }, Torso = { -2, -8, 0 }, Head = { 2, -40, 2 }, RArm = { 36.1, -43.2, 0.1 }, LArm = { 150, 0, -50 }, RLeg = { 40, -24, 12 }, LLeg = { -34, 0, -14 }, W = { 0, 0, 0, -21.4, 0, 16.4 } }
-- 뚫고 지나간 뒤 등 뒤의 적을 보는 자세: 몸 전체를 반 바퀴(돌기 +180, 자리도 같이 돌림 — 팔·칼은 몸을 따라 돈다)
local function behind(pose: { [string]: any }, over: { [string]: any }?): { [string]: any }
	local r = pose.Root
	return W(W(pose, { Root = { -r[1], r[2], -r[3], r[4], r[5] + 180, r[6] } }), over or {})
end

-- 경례: 칼을 얼굴 앞에 수직으로 세운다(날 축만 세움 — posecalc.aim_axis)
local SALUTE = {
	Root = { 0, 0.05, 0, 0, 12, 0 },
	Torso = { 4, 0, 0 },
	Head = { 6, -10, 0 },
	RArm = { 104, 30, 0 },
	LArm = POCKET,
	RLeg = { -4, 0, 2 },
	LLeg = { -6, 0, -2 },
	W = { 0, 0, 0, -15, 0, 0 },
}
-- 가토츠 겨눔(검 끝을 쏘아라): 몸을 오른쪽으로 틀어 왼 어깨를 앞에, 오른손은 머리 옆 뒤로 끌어 칼을 수평으로,
-- 왼손은 칼끝을 따라 적을 가리킨다(조준선). 여기서 몸을 왼쪽으로 되돌리며 쏜다.
local DRAW = {
	Root = { 0, -0.6, 0.6, 0, -42, 0 },
	Torso = { -4, -10, 0 },
	Head = { 0, 50, 0 },
	RArm = { 172, 21.5, -11 },
	LArm = { 122, 11, 0 },
	RLeg = { -24, 0, 12 },
	LLeg = { 30, 30, -12 },
	W = { 0, 0, 0, -162, 0, 27.7 },
}
-- 쏜 끝: 몸 전체가 한 줄 — 팔·칼이 적 너머까지
local SHOT = W(DEEP, {
	Root = { 0, -0.9, -0.9, 0, 34, 0 },
	Torso = { -28, -8, 0 },
	Head = { 22, -26, 0 },
	RArm = { 118, -18, 0 },
	LArm = { -34, 0, -30 },
	RLeg = { 70, -20, 10 },
	LLeg = { -56, 0, -10 },
})

return {
	Stance = EG,

	-- 대기: 여유 — 느리게 숨 쉰다(2026-10-02 사용자: "끊기는 느낌이 아니라 부드럽게 숨을 쉬고 있는 느낌").
	-- 내쉰 끝(OUT) → 들이쉰 끝(IN, 상체를 더 젖혀 턱을 듦) → 내쉬는 중(EG). Smooth = 키에서 멈추지 않는 곡선(MotionMath.smoothSample).
	-- 들숨이 날숨보다 짧다(1.45초 : 2.15초). 칼끝은 팔 선 둘레로 작게(±2°) 떠돈다.
	Idle = {
		Duration = 3.6,
		Loop = true,
		Smooth = true,
		Keys = {
			K(0.0, nil, EG, { Root = EG_OUT.Root, Torso = EG_OUT.Torso, Head = EG_OUT.Head, RArm = EG_OUT.RArm, LArm = EG_OUT.LArm, W = { 0, 0, 0, -89.5, 30, -1 } }),
			K(1.45, nil, EG, { Root = EG_IN.Root, Torso = EG_IN.Torso, Head = EG_IN.Head, RArm = EG_IN.RArm, LArm = EG_IN.LArm, W = { 0, 0, 0, -88, 30, 2 } }),
			K(2.5, nil, EG, { W = { 0, 0, 0, -91, 30, 0.5 } }),
		},
	},

	-- 버릇(가끔, 불규칙한 간격 — CombatDirector): 주머니 손을 빼 목 쪽 깃을 잡고 두 번 살짝 당겨 다듬은 뒤 다시 주머니로.
	-- 당길 때 턱을 들고 고개를 살짝 오른쪽으로 기울인다. 칼 겨눔·숨은 그대로(왼팔·머리만 덮음).
	-- 손 자리 = 몸통 앞 깃(몸통 공간 (-0.35, 1.05, -1.45)) — R6 팔은 곧아 가슴에 붙일 수 없어 깃을 앞으로 당겨 쥔 모양(posecalc.reach)
	Fidgets = {
		{
			Duration = 2.1,
			BlendIn = 0.3,
			BlendOut = 0.45,
			Keys = {
				{ t = 0, LArm = POCKET, Head = { -4, -54, 4 } },
				{ t = 0.45, e = "cubicOut", LArm = { 113.2, -61.4, -16.8 }, Head = { -1, -52, 0 } },
				{ t = 0.62, e = "quadIn", LArm = { 106.4, -59.5, -16.1 }, Head = { 1, -51, -3 } },
				{ t = 0.82, e = "sineOut", LArm = { 117.3, -59.4, -15.2 }, Head = { 0, -51, -2 } },
				{ t = 0.98, e = "quadIn", LArm = { 106.4, -59.5, -16.1 }, Head = { 3, -50, -6 } },
				{ t = 1.25, e = "sineOut", LArm = { 113.2, -61.4, -16.8 }, Head = { 1, -51, -4 } },
				{ t = 2.1, e = "cubicInOut", LArm = POCKET, Head = { -4, -54, 4 } },
			},
		},
	},

	-- 들림: 흔들려도 품위를 지킨다 — 두 발을 모으고 칼을 얼굴 앞에 세워 경례, 왼손은 주머니
	Held = {
		Duration = 1.8,
		Loop = true,
		Keys = {
			K(0, "sineInOut", SALUTE, { Root = { 0, 0.1, 0, 4, 10, 0 }, Head = { 8, -8, 0 }, RLeg = { -8, 0, 2 }, LLeg = { -12, 0, -2 } }),
			K(0.9, "sineInOut", SALUTE, { Root = { 0, 0.1, 0, -4, 16, 3 }, Torso = { 6, 0, 0 }, Head = { 4, -14, 0 }, RArm = { 100, 28, 0 }, LArm = { -12, 0, 7 }, RLeg = { -4, 0, 2 }, LLeg = { -16, 0, -2 }, W = { 0, 0, 0, -11, 0, 0 } }),
		},
	},

	-- 내려놓임: 경례 자세로 내려와 앞발로 바닥을 구르고(아펠) 칼을 한 바퀴 돌려(물리네) 겨눔으로
	Drop = {
		Duration = 0.75,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, SALUTE, { Root = { 0, 0.5, 0, 0, 20, 0 }, RLeg = { -8, 0, 2 }, LLeg = { -12, 0, -2 } }),
			K(0.07, "quadIn", EG, { Root = { 0, -0.5, 0, 0, 42, 0 }, Torso = { -8, -6, 0 }, RLeg = { 40, -24, 12 }, LLeg = { -20, 0, -14 }, RArm = { 62, -30, 14 }, W = { 0, 0, 0, -40, 0, 0 } }),
			K(0.17, "expoOut", EG, { Root = { 0, -0.32, 0, 0, 45, 0 }, RLeg = { 24, -30, 12 }, RArm = { 80, -30, 6 }, W = { 0, 0, 0, -120, 0, 0 } }),
			K(0.4, "cubicInOut", EG, { RArm = { 82, -30, 4 }, W = { 0, 0, 0, -430, 0, 0 } }),
			-- 한 바퀴(-360) 더 돈 값으로 끝낸다 — 대기로 넘어갈 때 섞기는 가까운 쪽으로 돌아 되감지 않는다
			K(0.75, "sineInOut", EG, { W = { 0, 0, 0, -450, 0, 0 } }),
		},
		Events = {
			{ t = 0.17, k = "Fx", n = "Appel" },
			{ t = 0.2, k = "Trail", on = true },
			{ t = 0.45, k = "Trail", on = false },
		},
	},

	-- 피격: 가슴을 맞고 젖혀지며 칼이 옆으로 튕기고 주머니 손이 빠져 균형을 잡는다 → 한 발 물러나 다시 겨눈다
	Hit = {
		Duration = 0.6,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, EG),
			K(0.05, "expoOut", EG, { Root = { 0, -0.1, 0.75, 0, 52, 0 }, Torso = { 18, 8, -6 }, Head = { 22, -26, 0 }, RArm = { 50, -70, 40 }, LArm = { 40, 0, -50 }, RLeg = { 30, -24, 10 }, LLeg = { -4, 0, -14 }, W = { 0, 0, 0, -20, 0, 0 } }),
			K(0.2, "sineOut", EG, { Root = { 0, -0.22, 0.9, 0, 50, 0 }, Torso = { 10, 4, -2 }, Head = { 10, -32, 0 }, RArm = { 58, -54, 26 }, LArm = { 20, 0, -30 }, W = { 0, 0, 0, -40, 0, 0 } }),
			K(0.6, "cubicInOut", EG),
		},
	},

	-- 방어(절반 성공): 칼을 수직으로 세워 바깥(식스트)으로 받고 한 발 물러서며 손목으로 버틴다
	Guard = {
		Duration = 0.6,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, EG),
			K(0.07, "expoOut", EG, { Root = { 0, -0.32, 0.35, 0, 42, 0 }, Torso = { 6, -4, 0 }, RArm = { 90, -36, 6 }, W = { 0, 0, 0, -10, 0, -8 } }),
			K(0.14, "expoOut", EG, { Root = { 0, -0.38, 0.6, 0, 40, 0 }, Torso = { 10, -2, 2 }, Head = { 8, -36, 0 }, RArm = { 96, -40, 10 }, W = { 0, 0, 0, -4, 0, -14 } }),
			K(0.6, "cubicInOut", EG),
		},
		Events = { { t = 0.1, k = "Fx", n = "BlockSpark" } },
	},

	-- 회피(성공 = 패링): 칼을 안쪽으로 쳐내고(바트) 감아 누른 뒤 곧장 되찌른다(리포스트)
	Dodge = {
		Duration = 0.62,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, EG),
			K(0.05, "expoOut", EG, { RArm = { 84, -16, 4 }, W = { 0, 0, 0, -34, 0, 0 }, Torso = { 4, 2, 0 }, Root = { 0, -0.3, 0.2, 0, 42, 0 } }),
			K(0.11, "expoOut", EG, { RArm = { 82, -44, 8 }, W = { 0, 0, 0, -40, 0, 0 }, Torso = { 2, -10, 0 }, Root = { 0, -0.3, 0.25, 0, 48, 0 } }),
			K(0.2, "expoOut", LUNGE, { Root = { 0, -0.5, -0.3, 0, 40, 0 }, RLeg = { 44, -22, 10 }, LLeg = { -30, 0, -10 } }),
			K(0.32, "sineOut", LUNGE, { Root = { 0, -0.5, -0.35, 0, 40, 0 }, RLeg = { 44, -22, 10 }, LLeg = { -30, 0, -10 } }),
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
		-- 앞뒤관통(2026-10-02 사용자 다시 짬): 칼을 오른쪽 아래로 한 번 휘두르고 펜싱 찌르기 준비 → 적을 뚫고 지나가며 쭉 찌른다 →
		-- 반 바퀴 돌아 다시 휘두르고(첫 찌르기의 피를 턴다) 더 낮고 깊게 준비 → 등 뒤에서 한 번 더 강하게 찌른다.
		FrontBackPierce = {
			Duration = 2.3,
			Keys = {
				K(0, nil, EG),
				K(0.1, "quadOut", RISE),
				K(0.22, "expoOut", SWISH),
				K(0.42, "cubicInOut", COCK),
				-- 찌르기 직전 숨을 고르듯 조금 더 당겨 웅크림
				K(0.5, "sineInOut", COCK, { Root = { 0, -0.5, 0.44, 0, 48, 0 } }),
				K(0.56, "expoOut", LUNGE),
				K(0.74, "linear", LUNGE, { Root = { 0, -0.56, -0.5, 0, 40, 0 } }),
				-- 반 바퀴 돌며 일어선다(등 뒤의 적을 본다)
				K(0.92, "cubicInOut", behind(EG, { W = { 0, 0, 0, -60, 0, 0 } })),
				K(1.02, "quadOut", behind(RISE)),
				K(1.14, "expoOut", behind(SWISH)),
				K(1.36, "cubicInOut", behind(COCK2)),
				K(1.46, "sineInOut", behind(COCK2, { Root = { 0, -0.68, -0.56, 0, 224, 0 } })),
				-- 몸을 다 던져 깊게
				K(1.52, "expoOut", behind(DEEP)),
				K(1.78, "sineOut", behind(DEEP, { Root = { 0, -0.76, 0.7, 0, 216, 0 }, Torso = { -20, -8, 0 } })),
				K(2.0, "cubicInOut", behind(EG)),
				K(2.3, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.12, k = "Trail", on = true },
				{ t = 0.54, k = "Dash", to = "Target", gap = -4, d = 0.09 },
				{ t = 0.58, k = "Hit", i = 1, fx = "Pierce" },
				{ t = 0.59, k = "Stop", d = 0.05 },
				{ t = 0.8, k = "Trail", on = false },
				{ t = 1.0, k = "Trail", on = true },
				{ t = 1.16, k = "Fx", n = "Chiburi" },
				{ t = 1.38, k = "Fx", n = "Glint" },
				-- 등 뒤에서 대상 쪽으로 한 걸음 파고든다
				{ t = 1.5, k = "Dash", to = "Target", gap = 1.4, d = 0.07 },
				{ t = 1.53, k = "Hit", i = 2, fx = "PierceBackBig" },
				{ t = 1.54, k = "Stop", d = 0.1 },
				{ t = 1.55, k = "Shake", a = 0.45, d = 0.3 },
				{ t = 1.85, k = "Trail", on = false },
				{ t = 1.95, k = "Dash", to = "Home", d = 0.28 },
			},
		},

		-- 찔러찔러또찔러: 가운데를 찌르고, 뽑아내며 칼끝을 튕기고, 그 반동으로 두 번 더 — 마지막은 몸을 다 던진다
		TripleThrust = {
			Duration = 1.4,
			Keys = {
				K(0, nil, EG),
				K(0.12, "quadOut", EG, { Root = { 0, -0.42, 0.25, 0, 46, 0 }, RArm = { 76, -30, 6 }, W = { 0, 0, 0, -78, 0, 0 } }),
				K(0.24, "expoOut", LUNGE, { Root = { 0, -0.5, -0.2, 0, 40, 0 }, RLeg = { 40, -22, 10 }, LLeg = { -28, 0, -10 } }),
				-- 뽑아내기: 팔을 당기고 칼끝을 위로 튕긴다
				K(0.38, "expoOut", EG, { Root = { 0, -0.36, 0.2, 0, 44, 0 }, RArm = { 80, -30, 8 }, W = { 0, 0, 0, -36, 0, 0 }, Torso = { 4, -6, 0 } }),
				K(0.47, "expoOut", LUNGE, { Root = { 0, -0.56, -0.35, 0, 40, 0 }, RLeg = { 46, -22, 10 }, LLeg = { -34, 0, -10 } }),
				K(0.56, "expoOut", EG, { Root = { 0, -0.4, 0.15, 0, 44, 0 }, RArm = { 78, -30, 10 }, W = { 0, 0, 0, -48, 0, 0 }, Torso = { 2, -4, 0 } }),
				-- 마지막: 몸 전체로 깊게
				K(0.7, "expoOut", DEEP),
				K(0.95, "sineOut", DEEP, { Root = { 0, -0.76, -0.7, 0, 36, 0 }, Torso = { -20, -8, 0 } }),
				K(1.12, "cubicInOut", EG, { W = { 0, 0, 0, -36, 0, 0 }, RArm = { 70, -30, 12 } }),
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

		-- 깊은 호흡: 칼을 얼굴 앞에 세워 경례하고 숨을 들이쉬었다 내쉰 뒤, 높은 겨눔(칼끝이 적 눈높이)으로 굳힌다
		DeepBreath = {
			Duration = 1.7,
			Keys = {
				K(0, nil, EG),
				K(0.3, "cubicInOut", SALUTE),
				-- 들숨
				K(0.8, "sineInOut", SALUTE, { Root = { 0, 0.12, 0.05, 0, 12, 0 }, Torso = { 10, 0, 0 }, Head = { 14, -10, 0 }, RArm = { 106, 30, 0 }, W = { 0, 0, 0, -17, 0, 0 } }),
				-- 날숨
				K(1.1, "sineInOut", SALUTE, { Root = { 0, -0.1, 0, 0, 14, 0 }, Torso = { -2, 0, 0 }, Head = { -4, -10, 0 }, RArm = { 100, 30, 0 }, W = { 0, 0, 0, -11, 0, 0 } }),
				-- 높은 겨눔: 손을 이마 높이로 들고 칼끝을 적 눈에
				K(1.3, "expoOut", EG, { Root = { 0, -0.34, 0.1, 0, 46, 0 }, RArm = { 118, -30, 6 }, W = { 0, 0, 0, -112, 0, 0 }, Head = { 0, -40, 0 } }),
				K(1.7, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.35, k = "Fx", n = "Salute" },
				{ t = 0.8, k = "Fx", n = "Focus" },
				{ t = 1.3, k = "Fx", n = "FocusSnap" },
			},
		},

		-- 검 끝을 쏘아라(가토츠): 활을 당기듯 칼을 머리 옆으로 끌어 수평으로 겨누고 왼손으로 조준(떨림) →
		-- 몸을 왼쪽으로 되돌리는 힘으로 한 줄기 빛처럼 꿰뚫고 지나가 피를 턴다(치부리)
		PointBlank = {
			Duration = 2.0,
			Keys = {
				K(0, nil, EG),
				K(0.3, "cubicOut", DRAW),
				K(0.5, "sineInOut", DRAW, { Root = { 0, -0.66, 0.66, 0, -43, 0 }, RArm = { 173, 21.5, -11 }, LArm = { 121, 11, 0 } }),
				K(0.66, "sineInOut", DRAW, { Root = { 0, -0.68, 0.7, 0, -44, 0 }, RArm = { 174, 21, -11 }, LArm = { 122, 12, 0 }, W = { 0, 0, 0, -163, 0, 27.7 } }),
				K(0.72, "expoOut", SHOT),
				K(1.0, "linear", SHOT, { Root = { 0, -0.86, -0.9, 0, 34, 0 }, Torso = { -26, -8, 0 }, RArm = { 116, -18, 0 } }),
				-- 피 털기(치부리): 등을 적에게 둔 채 일어서며 칼을 옆 아래로 휙 턴다(이때만 칼끝이 잠깐 내려간다)
				K(1.18, "cubicOut", EG, { Root = { 0, -0.2, 0, 0, 30, 0 }, Torso = { 4, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 70, -60, 30 }, W = { 0, 0, 0, -80, 0, 0 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(1.26, "expoOut", EG, { Root = { 0, -0.2, 0, 0, 30, 0 }, Torso = { 4, 0, 0 }, Head = { -6, 10, 0 }, RArm = { 34, -80, 40 }, W = { 0, 0, 0, -100, 0, 0 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(1.55, "sineInOut", EG, { Root = { 0, -0.18, 0, 0, 30, 0 }, Torso = { 4, 0, 0 }, Head = { 0, 4, 0 }, RArm = { 30, -80, 40 }, W = { 0, 0, 0, -100, 0, 0 }, RLeg = { 8, 0, 8 }, LLeg = { -6, 0, -8 } }),
				K(2.0, "cubicInOut", EG),
			},
			Events = {
				{ t = 0.3, k = "Fx", n = "Glint" },
				{ t = 0.66, k = "Trail", on = true },
				-- 적 진영 맨 끝 칸 너머까지 꿰뚫고 지나간다(2026-10-02 사용자)
				{ t = 0.67, k = "Dash", to = "Far", past = 5, d = 0.1 },
				{ t = 0.7, k = "Hit", i = 1, fx = "PointBlank" },
				{ t = 0.71, k = "Stop", d = 0.14 },
				{ t = 0.72, k = "Shake", a = 0.55, d = 0.35 },
				{ t = 0.95, k = "Trail", on = false },
				{ t = 1.24, k = "Fx", n = "Chiburi" },
				{ t = 1.5, k = "Dash", to = "Home", d = 0.34 },
			},
		},

		-- 가드(스킬): 방어 태세 — 칼을 몸 앞에 수직으로 세우고 무게를 뒤로
		Guard = {
			Duration = 0.9,
			Keys = {
				K(0, nil, EG),
				K(0.16, "backOut", EG, { Root = { 0, -0.34, 0.4, 0, 40, 0 }, Torso = { 6, -2, 0 }, RArm = { 90, -18, 4 }, W = { 0, 0, 0, -8, 0, -8 } }),
				K(0.6, "sineInOut", EG, { Root = { 0, -0.36, 0.42, 0, 40, 0 }, Torso = { 7, -2, 0 }, RArm = { 90, -18, 4 }, W = { 0, 0, 0, -8, 0, -8 } }),
				K(0.9, "cubicInOut", EG),
			},
			Events = { { t = 0.16, k = "Fx", n = "GuardRing" } },
		},

		-- 명상: 한쪽 무릎을 꿇고 칼을 얼굴 앞에 세워(칼끝 위) 고개를 숙인다
		Meditate = {
			Duration = 1.8,
			Keys = {
				K(0, nil, EG),
				{ t = 0.35, e = "cubicInOut", Root = { 0, -0.9, 0, 0, 20, 0 }, Torso = { -4, 0, 0 }, Head = { -22, -10, 0 }, RArm = { 70, 24, 0 }, LArm = { 20, 0, -10 }, RLeg = { 86, 0, 6 }, LLeg = { -40, 0, -6 }, W = { 0, 0, 0, 24, 0, 2 } },
				{ t = 1.3, e = "sineInOut", Root = { 0, -0.86, 0, 0, 20, 0 }, Torso = { -1, 0, 0 }, Head = { -16, -10, 0 }, RArm = { 70, 24, 0 }, LArm = { 20, 0, -10 }, RLeg = { 86, 0, 6 }, LLeg = { -40, 0, -6 }, W = { 0, 0, 0, 24, 0, 2 } },
				K(1.8, "cubicInOut", EG),
			},
			Events = { { t = 0.4, k = "Fx", n = "Meditate" } },
		},
	},
}
