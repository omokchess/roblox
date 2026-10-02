--!strict
--[[
	음악가 — 바이올리니스트. (2026-09-28, 자세 다시 2026-09-30)

	성격: 우아함·무대 체질. 움직임은 곡선(sine)으로 흐르고, 피하면 피루엣으로 돈다.
	      공격은 칼질이 아니라 **활 긋기**다 — 음표가 날아가 때린다.
	사용자 지정(`스탠딩/직업 베이스 모션.md`): 바이올린 **바닥이 목에 닿고**, 대기에서 **활은 똑바로 세운다**.
	참고: 바이올린 자세 — 악기는 왼쪽 쇄골에 얹고 턱받침에 턱을 괸다, 스크롤은 왼 어깨 앞 위로,
	      윗판은 20~45° 오른쪽으로 눕힌다. 활은 프로그(손잡이)를 쥔다.
	      대기 = 쉼표에서 활을 세워 든 준비 자세. 긋기는 활털이 브리지와 지판 사이 줄에 닿은 채로 미끄러진다.
	무대 쪽으로 몸을 연다: 전투 카메라는 오른쪽 옆에서 본다 — 몸을 오른쪽으로 48° 틀어(Root Y -48) 가슴과 악기가 카메라 쪽.
	무기 종류: Bowed (WeaponDefinitions.Violin: O = 왼손 바이올린, W = 오른손 활)
	수치: tools/combat/posecalc.py 로 구했다 — 곧은 R6 팔로 바닥이 목에 닿으면서 왼손이 목을 쥐고(어긋남 0.02),
	      활털이 줄에 닿은 채 활 길이 0.9~2.3 구간을 긋는 오른팔·활 각도(활 길이 s 별 BOW 표).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

-- 턱에 괸 바이올린(바닥 = 목 왼쪽 쇄골, 몸 앞에서 왼쪽 60°·위로 2°, 윗판 오른쪽으로 40° 눕힘)
local CHIN = { LArm = { 114.7, 20.6, 11 }, O = { 0, 0.01, -0.01, 35.2, -22.1, 125 } }
-- 활 긋기: 활털의 s 스터드 자리가 줄에 닿는 오른팔·활(프로그 쪽 0.9 → 끝 쪽 2.3)
local BOW = {
	[9] = { RArm = { 109.4, 41.5, -21.2 }, W = { 0, 0, 0, -104.4, 46.8, 35.3 } },
	[11] = { RArm = { 102.9, 36.4, -18.9 }, W = { 0, 0, 0, -104.7, 44.1, 54.9 } },
	[14] = { RArm = { 95.6, 31.2, -15 }, W = { 0, 0, 0, -105.1, 40.5, 71.8 } },
	[17] = { RArm = { 89.1, 26.7, -10.5 }, W = { 0, 0, 0, -105.4, 36.9, 84 } },
	[20] = { RArm = { 83.5, 20.3, -7.5 }, W = { 0, 0, 0, -106, 33.1, 93.6 } },
	[23] = { RArm = { 78.5, 13.7, -3.8 }, W = { 0, 0, 0, -106.8, 28.8, 102 } },
}
-- 활을 세워 든 오른손(가슴 앞, 활끝은 바이올린 쪽으로 살짝)
local UPRIGHT = { RArm = { 76, 20, 5 }, W = { 0, 0, 0, 17.7, 0, 6.9 } }
-- 활을 하늘로 / 내던진 끝 / 인사하며 옆 아래로 / 몸 앞에 세워 뻗기(오선 방패의 기둥)
local RAISE = { RArm = { 170, 14, 16 }, W = { 0, 0, 0, -70, 0, 11.6 } }
local FLING = { RArm = { 70, -80, 58 }, W = { 0, 0, 0, -64.8, 0, -6.6 } }
local BOWDOWN = { RArm = { 40, -30, 40 }, W = { 0, 0, 0, -81.3, 0, -5.8 } }
local GUARDBOW = { RArm = { 92, 26, 0 }, W = { 0, 0, 0, -2, 0, 0 } }
-- 바이올린을 턱에서 뗀 자세: 목을 쥐고 치켜듦(스크롤 위) / 가슴에 끌어안음 / 가슴 앞에 세움 / 머리 위로
local VOPEN = { LArm = { 120, 30, -30 }, O = { 0, 0, 0, -56.2, -53, -13 } }
local VHUG = { LArm = { 60, 70, 0 }, O = { 0, 0, 0, 14.3, -68.7, -20.5 } }
local VGUARD = { LArm = { 52, 34, 0 }, O = { 0, 0, 0, 38, -34, -2.9 } }
local VHIGH = { LArm = { 150, 20, -10 }, O = { 0, 0, 0, -45.2, -26.4, 3.9 } }

local function with(...)
	local out = {}
	for _, t in { ... } do
		for k, v in t do
			out[k] = v
		end
	end
	return out
end

-- 준비 자세(대기): 오른발에 무게(콘트라포스토), 왼발끝을 세우고, 턱을 턱받침에 괴고 고개를 왼쪽으로 기울인다
local READY = with({
	Root = { 0, -0.05, 0, 0, -48, 0 },
	Torso = { 3, 6, 0 },
	Head = { -14, 30, 18 },
	RLeg = { 3, 0, 4 },
	LLeg = { -8, 0, -8 },
}, CHIN, UPRIGHT)
-- 연주 자세(활이 줄 위)
local function PLAY(s: number, over: { [string]: any }?)
	return with(READY, BOW[s], over or {})
end
-- 두 팔을 활짝 편 자세(피날레·피루엣)
local OPEN = with(READY, VOPEN, {
	Root = { 0, 0.15, 0, 0, -60, 0 },
	Torso = { 14, 0, 0 },
	Head = { 20, 0, 0 },
	RArm = { 150, -40, 40 },
	W = { 0, 0, 0, -60, 0, 20 },
	RLeg = { 2, 0, 3 },
	LLeg = { -20, 0, -6 },
})
-- 인사(커트시): 바이올린을 가슴에 안고 활을 옆 아래로, 한 발 뒤로 빼며 무릎을 굽힌다
local CURTSY = with(READY, VHUG, BOWDOWN, {
	Root = { 0, -0.45, 0.1, 0, -52, 0 },
	Torso = { -18, 4, 0 },
	Head = { -24, 20, 8 },
	RLeg = { 16, 0, 4 },
	LLeg = { -34, 0, -4 },
})
-- 방어: 바이올린을 가슴 앞에 세워 감싸고, 활을 몸 앞에 수직으로 뻗는다
local GUARD = with(READY, VGUARD, GUARDBOW, {
	Root = { 0, -0.2, 0.45, 0, -66, 0 },
	Torso = { 6, -6, 0 },
	Head = { 0, 14, 0 },
})
-- 들림: 몸이 떠서 가슴을 젖히고 발을 찬다
local LIFT = { Root = { 0, 0.1, 0, 6, -48, 0 }, Torso = { 10, 6, 0 }, Head = { -6, 32, 16 } }
-- 벨로체: 앞으로 몸을 싣는다
local LEAN = { Root = { 0, -0.2, -0.2, 0, -42, 0 }, Torso = { -8, 10, 0 }, Head = { -18, 32, 18 }, RLeg = { 16, 0, 4 }, LLeg = { -16, 0, -8 } }
-- 알 포르테: 발끝으로 선다
local TIPTOE = { Root = { 0, 0.3, 0.1, 0, -48, 0 }, Torso = { 16, 6, 0 }, Head = { 6, 30, 14 }, RLeg = { -6, 0, 2 }, LLeg = { -10, 0, -2 } }

return {
	Stance = READY,

	-- 대기: 연주(2026-10-02 사용자: 바드는 "연주하는 느낌"). 턱에 바이올린을 괸 채 활털을 줄에 대고 쉼 없이 긋는다 —
	-- 내림활 길게(프로그 → 끝) · 올림활 반 · 내림활 반 · 올림활 길게(끝 → 프로그). 긋는 자리는 BOW 표(활털이 줄에 닿는 자세)를 따라가고,
	-- Smooth 라 활이 바뀌는 끝에서만 잠깐 늦춰지고 키마다 멈추지 않는다. 몸은 활을 따라 좌우로 실려 흔들리고(내림활에 왼쪽 → 올림활에 오른쪽),
	-- 숨도 함께 쉰다. 턱받침에 괸 고개는 몸을 따라 아주 조금만.
	Idle = {
		Duration = 6.0,
		Loop = true,
		Smooth = true,
		Keys = {
			K(0.0, nil, PLAY(9, { Root = { 0, -0.05, 0, 0, -50, 0 }, Torso = { 3, 8, -1.5 }, Head = { -14, 31, 18 } })),
			K(0.45, nil, PLAY(14, { Torso = { 4, 7, -0.8 } })),
			K(0.9, nil, PLAY(17, { Root = { 0, -0.04, 0, 0, -48, 0 }, Torso = { 4.5, 6, 0 } })),
			K(1.35, nil, PLAY(20, { Torso = { 5, 5, 0.8 } })),
			K(1.8, nil, PLAY(23, { Root = { 0, -0.03, 0, 0, -46, 0 }, Torso = { 5, 4, 1.5 }, Head = { -13, 29, 17 } })),
			K(2.25, nil, PLAY(17, { Torso = { 4, 5, 0.6 } })),
			K(2.7, nil, PLAY(14, { Root = { 0, -0.05, 0, 0, -48, 0 }, Torso = { 3, 6, 0 } })),
			K(3.15, nil, PLAY(20, { Torso = { 3.5, 5, 0.8 } })),
			K(3.6, nil, PLAY(23, { Root = { 0, -0.04, 0, 0, -46, 0 }, Torso = { 4.5, 4, 1.5 }, Head = { -13, 29, 17 } })),
			K(4.2, nil, PLAY(20, { Torso = { 4, 5, 0.8 } })),
			K(4.8, nil, PLAY(14, { Root = { 0, -0.05, 0, 0, -49, 0 }, Torso = { 3, 7, -0.6 } })),
			K(5.4, nil, PLAY(11, { Torso = { 2.5, 8, -1.2 }, Head = { -14, 31, 18 } })),
		},
	},

	-- 들림: 발끝을 번갈아 차며 트레몰로(활을 줄 위에서 아주 빠르게 떤다) — 신이 나서 멈추지 않는다
	Held = {
		Duration = 0.72,
		Loop = true,
		Keys = {
			K(0, "sineInOut", PLAY(14, LIFT), { RLeg = { 18, 0, 2 }, LLeg = { -22, 0, -2 } }),
			K(0.12, "sineInOut", PLAY(17, LIFT), { RLeg = { 4, 0, 2 }, LLeg = { -6, 0, -2 } }),
			K(0.24, "sineInOut", PLAY(14, LIFT), { RLeg = { -8, 0, 2 }, LLeg = { 6, 0, -2 } }),
			K(0.36, "sineInOut", PLAY(17, LIFT), { Root = { 0, 0.14, 0, 4, -46, 0 }, RLeg = { -20, 0, 2 }, LLeg = { 16, 0, -2 } }),
			K(0.48, "sineInOut", PLAY(14, LIFT), { RLeg = { -6, 0, 2 }, LLeg = { 4, 0, -2 } }),
			K(0.6, "sineInOut", PLAY(17, LIFT), { RLeg = { 8, 0, 2 }, LLeg = { -10, 0, -2 } }),
		},
	},

	-- 내려놓임: 발끝으로 사뿐히 내려서 두 팔을 활짝 펴고(활을 크게 한 번), 바이올린을 안고 인사(커트시)
	Drop = {
		Duration = 1.0,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, READY, { Root = { 0, 0.4, 0, 0, -48, 0 }, RLeg = { 10, 0, 2 }, LLeg = { -14, 0, -2 } }),
			K(0.08, "quadIn", READY, { Root = { 0, -0.2, 0, 0, -48, 0 } }),
			K(0.3, "cubicOut", OPEN),
			K(0.55, "sineInOut", CURTSY),
			K(0.75, "sineInOut", CURTSY, { Root = { 0, -0.4, 0.1, 0, -52, 0 }, Torso = { -16, 4, 0 } }),
			K(1.0, "sineInOut", READY),
		},
		Events = {
			{ t = 0.08, k = "Fx", n = "Tiptoe" },
			{ t = 0.12, k = "Trail", on = true },
			{ t = 0.3, k = "Fx", n = "Flourish" },
			{ t = 0.5, k = "Trail", on = false },
		},
	},

	-- 피격: 바이올린을 가슴에 끌어안고 등을 돌리며 움츠린다 → 다시 자세
	Hit = {
		Duration = 0.65,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, READY),
			K(0.05, "expoOut", READY, with(VHUG, { Root = { 0, -0.2, 0.7, 0, -22, -6 }, Torso = { -16, 30, 6 }, Head = { -20, 20, 0 }, RArm = { 60, 50, 20 }, W = { 0, 0, 0, -10, 0, 0 }, RLeg = { 20, 0, 6 }, LLeg = { -10, 0, -8 } })),
			K(0.22, "sineOut", READY, with(VHUG, { Root = { 0, -0.24, 0.8, 0, -26, -4 }, Torso = { -12, 26, 4 }, Head = { -14, 24, 4 }, RArm = { 64, 46, 18 }, W = { 0, 0, 0, -6, 0, 0 }, RLeg = { 18, 0, 6 }, LLeg = { -8, 0, -8 } })),
			K(0.65, "cubicInOut", READY),
		},
	},

	-- 방어: 뒤로 물러서며 바이올린을 가슴 앞에 세워 감싸고, 활을 앞에 수직으로 세워 오선 방패를 친다
	Guard = {
		Duration = 0.65,
		BlendIn = 0.03,
		Keys = {
			K(0, nil, READY),
			K(0.08, "expoOut", GUARD),
			K(0.18, "sineOut", GUARD, { Root = { 0, -0.25, 0.6, 0, -64, 0 }, Torso = { 8, -4, 0 }, Head = { 2, 14, 0 }, RArm = { 94, 26, 0 } }),
			K(0.65, "cubicInOut", READY),
		},
		Events = { { t = 0.08, k = "Fx", n = "StaveShield" } },
	},

	-- 회피: 두 팔을 펴고 한 발로 피루엣(한 바퀴) 돌며 옆으로 비껴난다
	Dodge = {
		Duration = 0.7,
		BlendIn = 0.02,
		Keys = {
			K(0, nil, READY),
			K(0.06, "quadOut", READY, { Root = { 0.3, -0.2, 0.2, 0, -60, 0 }, Torso = { 6, 0, 0 } }),
			K(0.2, "cubicIn", OPEN, { Root = { -0.6, 0.35, 0.5, 0, 130, 0 }, RLeg = { 0, 0, 2 }, LLeg = { 40, 0, -10 } }),
			K(0.36, "cubicOut", OPEN, { Root = { -1.2, 0.2, 0.9, 0, 312, 0 }, RLeg = { 0, 0, 2 }, LLeg = { 30, 0, -10 } }),
			K(0.7, "sineInOut", READY, { Root = { -0.4, -0.05, 0.3, 0, 312, 0 } }),
		},
		Events = { { t = 0.06, k = "Fx", n = "Pirouette" } },
	},

	Skills = {
		-- 벨로체: 활을 줄에 얹어 빠른 스피카토(짧게 튀기며 여러 번) — 앞으로 몸을 싣고, 마지막은 끝까지 길게 내리긋는다
		Veloce = {
			Duration = 1.3,
			Keys = {
				K(0, nil, READY),
				K(0.12, "quadOut", PLAY(14, LEAN)),
				K(0.2, "expoOut", PLAY(17, LEAN)),
				K(0.28, "expoOut", PLAY(14, LEAN), { Root = { 0, -0.24, -0.2, 0, -42, 0 } }),
				K(0.36, "expoOut", PLAY(17, LEAN), { Root = { 0, -0.2, -0.25, 0, -42, 0 }, Torso = { -9, 10, 0 } }),
				K(0.44, "expoOut", PLAY(14, LEAN), { Root = { 0, -0.24, -0.25, 0, -42, 0 }, Torso = { -9, 10, 0 } }),
				K(0.52, "sineOut", PLAY(9, LEAN), { Root = { 0, -0.24, -0.25, 0, -42, 0 }, Torso = { -9, 10, 0 } }),
				-- 마지막 한 번은 길고 세게 내리그어 음표를 떠나보낸다
				K(0.62, "expoOut", PLAY(23, LEAN), { Root = { 0, -0.3, -0.35, 0, -38, 0 }, Torso = { -12, 14, 0 }, Head = { -16, 30, 14 }, RLeg = { 22, 0, 4 }, LLeg = { -22, 0, -8 } }),
				K(0.9, "sineOut", PLAY(23, LEAN), { Root = { 0, -0.26, -0.3, 0, -40, 0 }, Torso = { -10, 12, 0 }, RLeg = { 20, 0, 4 }, LLeg = { -20, 0, -8 } }),
				K(1.3, "sineInOut", READY),
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
				K(0, nil, READY),
				K(0.25, "cubicOut", READY, with(RAISE, { Root = { 0, 0.1, 0, 0, -48, 0 }, Torso = { 12, 6, 0 }, Head = { 10, 26, 10 }, RLeg = { 0, 0, 3 }, LLeg = { -26, 0, -6 } })),
				K(0.6, "sineInOut", OPEN, { Root = { 0, 0.25, 0, 0, 312, 0 } }),
				K(0.82, "expoOut", OPEN, with(FLING, { Root = { 0, -0.1, 0, 0, 312, 0 }, Torso = { -10, -12, 0 }, Head = { -8, -10, 0 } })),
				K(1.25, "sineOut", OPEN, with(FLING, { Root = { 0, 0, 0, 0, 312, 0 }, RArm = { 66, -84, 60 }, Torso = { -6, -12, 0 }, Head = { 2, -10, 0 } })),
				K(1.7, "sineInOut", READY, { Root = { 0, -0.05, 0, 0, 312, 0 } }),
			},
			Events = {
				{ t = 0.1, k = "Trail", on = true },
				{ t = 0.25, k = "Fx", n = "Raise" },
				{ t = 0.82, k = "Fx", n = "Brillante" },
				{ t = 1.0, k = "Trail", on = false },
			},
		},

		-- 크레셴도: 세 번 긋는 동안 점점 길고 크게, 몸이 점점 뒤로 젖혀지다가 마지막 포르테로 활을 내던지듯 긋는다
		Crescendo = {
			Duration = 1.9,
			Keys = {
				K(0, nil, READY),
				K(0.15, "sineInOut", PLAY(11)),
				K(0.3, "sineInOut", PLAY(17, { Torso = { 6, 6, 0 } })),
				K(0.55, "sineInOut", PLAY(11, { Torso = { 10, 8, 2 }, Head = { -8, 32, 18 } })),
				K(0.82, "sineInOut", PLAY(20, { Torso = { 14, 6, -3 }, Head = { -4, 30, 18 }, Root = { 0, 0.05, 0.1, 0, -50, 0 } })),
				K(1.1, "cubicInOut", PLAY(9, { Torso = { 20, 10, 4 }, Head = { 6, 30, 16 }, Root = { 0, 0.15, 0.25, 0, -46, 0 }, RLeg = { -4, 0, 3 }, LLeg = { -14, 0, -6 } })),
				-- 포르테
				K(1.22, "expoOut", READY, with(FLING, { Torso = { -14, -8, 0 }, Head = { -20, 18, 8 }, Root = { 0, -0.3, -0.4, 0, -44, 0 }, RLeg = { 26, 0, 4 }, LLeg = { -26, 0, -6 } })),
				K(1.5, "sineOut", READY, with(FLING, { RArm = { 66, -84, 62 }, Torso = { -10, -8, 0 }, Head = { -14, 18, 8 }, Root = { 0, -0.26, -0.35, 0, -44, 0 }, RLeg = { 24, 0, 4 }, LLeg = { -24, 0, -6 } })),
				K(1.9, "sineInOut", READY),
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

		-- 크레셴도 알 포르테: 발끝으로 서서 광란의 트레몰로 → 바이올린과 활을 머리 위로 모았다가 내던지듯 긋는 순간 별처럼 터진다
		CrescendoAlForte = {
			Duration = 2.4,
			Keys = {
				K(0, nil, READY),
				K(0.3, "cubicOut", PLAY(14, TIPTOE)),
				K(0.38, "linear", PLAY(17, TIPTOE), { Root = { 0, 0.32, 0.1, 0, -48, 0 } }),
				K(0.46, "linear", PLAY(14, TIPTOE), { Torso = { 17, 6, 0 } }),
				K(0.54, "linear", PLAY(17, TIPTOE), { Root = { 0, 0.34, 0.1, 0, -48, 0 }, Torso = { 17, 6, 0 } }),
				K(0.62, "linear", PLAY(14, TIPTOE), { Torso = { 18, 6, 0 } }),
				K(0.7, "linear", PLAY(17, TIPTOE), { Root = { 0, 0.36, 0.1, 0, -48, 0 }, Torso = { 18, 6, 0 }, Head = { 8, 30, 14 } }),
				K(0.78, "linear", PLAY(14, TIPTOE), { Torso = { 18, 6, 0 }, Head = { 8, 30, 14 } }),
				-- 숨을 멈추는 한 박: 바이올린과 활을 머리 위로 모은다
				K(1.05, "cubicOut", READY, with(VHIGH, RAISE, { Root = { 0, 0.4, 0.3, 0, -42, 0 }, Torso = { 24, 12, 4 }, Head = { 20, 30, 10 }, RLeg = { -10, 0, 2 }, LLeg = { -30, 0, -2 } })),
				-- 내던지듯 긋기
				K(1.14, "expoOut", OPEN, with(FLING, { Root = { 0, -0.35, -0.5, 0, -54, 0 }, Torso = { -18, -14, 0 }, Head = { -10, -4, 0 }, RLeg = { 30, 0, 4 }, LLeg = { -30, 0, -6 } })),
				K(1.7, "sineOut", OPEN, with(FLING, { Root = { 0, -0.3, -0.45, 0, -54, 0 }, Torso = { -14, -14, 0 }, Head = { 4, -4, 0 }, RArm = { 66, -84, 62 }, RLeg = { 28, 0, 4 }, LLeg = { -28, 0, -6 } })),
				K(2.4, "sineInOut", READY),
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
				K(0, nil, READY),
				K(0.14, "backOut", GUARD, { Root = { 0, -0.2, 0.4, 0, -66, 0 } }),
				K(0.7, "sineInOut", GUARD, { Root = { 0, -0.22, 0.4, 0, -66, 0 }, Torso = { 7, -6, 0 } }),
				K(1.0, "sineInOut", READY),
			},
			Events = { { t = 0.14, k = "Fx", n = "StaveShield" } },
		},

		-- 명상: 눈을 감고 턱을 바이올린에 깊이 묻은 채 아주 느린 활 한 번으로 음을 고른다
		Meditate = {
			Duration = 2.0,
			Keys = {
				K(0, nil, READY),
				K(0.3, "sineInOut", PLAY(11, { Head = { -20, 34, 20 }, Torso = { 0, 8, 0 } })),
				K(0.5, "sineInOut", PLAY(14, { Head = { -21, 34, 20 }, Torso = { 0, 8, 0 } })),
				K(1.0, "sineInOut", PLAY(23, { Head = { -22, 34, 20 }, Torso = { -1, 8, 0 } })),
				K(1.5, "sineInOut", PLAY(14, { Head = { -18, 32, 18 }, Torso = { 1, 8, 0 } })),
				K(2.0, "sineInOut", READY),
			},
			Events = {
				{ t = 0.5, k = "Fx", n = "Pizz" },
				{ t = 1.0, k = "Fx", n = "Pizz" },
				{ t = 1.1, k = "Fx", n = "Meditate" },
			},
		},
	},
}
