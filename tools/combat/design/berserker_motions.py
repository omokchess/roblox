"""광전사 모션 파일(src/shared/Combat/Motions/Berserker.luau)을 통째로 만든다(2026-10-03 다시).
자세 = berserker2_gen.py 출력(berserker2_out.txt). W 는 motion_writer 가 앞 키에 맞춰 감는다. 쓰는 법: python berserker_motions.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from motion_writer import load_poses, make, pose_lines  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "src", "shared", "Combat", "Motions", "Berserker.luau")
POSES = load_poses(os.path.join(HERE, "berserker2_out.txt"))
keys, motion = make(POSES)
ORDER = ["CALM", "CALM_HANG", "DRAG", "RAISE", "CHOP", "CUT_A0", "CUT_A1", "CUT_B0", "CUT_B1", "WHIRL", "BLOCK", "ROAR", "BREATH"]
NOTE = {
    "CALM": "대기(차분한 전투광): 꼿꼿이 힘 빼고, 늘어뜨린 오른손이 자루 아래를 느슨히 쥐고 도끼 머리는 오른쪽 앞 땅에 눕힌다(2026-10-03: 뒤 → 앞)",
    "CALM_HANG": "들림: 축 늘어져 매달리고 도끼는 한 손에 머리가 아래로",
    "DRAG": "돌진·회피: 웅크려 한 손으로 도끼를 뒤 땅에 끈다",
    "RAISE": "머리 위 치켜듦(내려찍기 예비): 두 손을 머리 위로, 도끼 머리는 등 뒤, 날은 위",
    "CHOP": "내려찍은 끝: 깊게 숙여 두 손이 배 앞 아래, 날이 앞 땅에 박힌다",
    "CUT_A0": "쌍베기 1 예비: 오른 어깨 위로 감아 올림(날은 적 쪽)",
    "CUT_A1": "쌍베기 1 끝: 왼쪽 아래로 베어 내림 — 위 손을 미끄러뜨려 두 손을 모음",
    "CUT_B0": "쌍베기 2 예비: 왼 어깨 위로 감아 올림",
    "CUT_B1": "쌍베기 2 끝: 오른쪽 아래로 베어 내림",
    "WHIRL": "회오리: 두 손을 자루 아래에 모아 도끼를 오른쪽으로 수평으로 뻗는다",
    "BLOCK": "막기: 자루를 가로로 들어 얼굴 앞에서 받는다(두 손을 벌려)",
    "ROAR": "포효(피격): 한 손으로 도끼를 머리 위로 치켜들고 가슴을 펴 고개를 젖힌다, 왼 주먹은 아래로",
    "BREATH": "호흡: 도끼 머리를 앞 땅에 짚고(자루가 몸보다 길어 비스듬히) 두 손을 가슴 앞 자루 끝에 포갠 채 기댄다",
}

head = '''--!strict
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

'''
t = head + pose_lines(POSES, ORDER, NOTE) + "\n\nreturn {\n\tStance = CALM,\n\n"
t += '''	-- 대기: 차분한 전투광 — 힘 빼고 서서 느리고 깊게 숨 쉰다(Kit.Breath, Smooth). 들숨에 가슴이 오르면 늘어진 팔·도끼도 조금 따라 들린다
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

'''
t += motion("Held", "들림: 차분하게 — 버둥대지 않고 축 늘어져 매달린 채 도끼를 한 손에 늘어뜨리고, 고개만 들어 내려다본다. 시계추처럼 느리게 흔들린다", 3.0,
            [(0, None, "CALM_HANG", None), (1.5, None, "CALM_HANG", {"Root": [0, 0.04, 0, -2, -18, 0], "Head": [-8, 24, 3], "RLeg": [-2, 0, 4], "LLeg": [4, 0, -4]})],
            [], "\t\tLoop = true,\n\t\tSmooth = true,\n", 1)
t += "\n" + motion("Drop", "내려놓임: 차분하게 — 사뿐히 무릎을 굽혀 내려서고 도끼 머리가 앞 땅에 툭 눕는다. 숨을 한 번 내쉬며 목을 기울이고 선다", 1.2,
                   [(0, None, "CALM_HANG", {"Root": [0, 0.3, 0, 0, -18, 0]}),
                    (0.14, "quadIn", "CALM", {"Root": [0, -0.42, 0, 0, -18, 0], "Torso": [-14, 2, 0], "Head": [-10, 16, -3], "RLeg": [26, 0, 8], "LLeg": [-14, 0, -8]}),
                    (0.5, "sineOut", "CALM", {"Root": [0, -0.12, 0, 0, -18, 0], "Torso": [-9, 2, 0], "Head": [-8, 16, 8]}),
                    (0.8, "sineInOut", "CALM", {"Head": [-4, 18, -10]}), (1.2, "sineInOut", "CALM", None)],
                   ['{ t = 0.14, k = "Shake", a = 0.15, d = 0.2 }'], "\t\tBlendIn = 0.05,\n", 1)
t += "\n" + motion("Hit", "피격(격분): 맞고 고개가 젖혀지며 움찔 → 그 힘을 받아 한 손으로 도끼를 머리 위로 치켜들고 가슴을 펴 포효 → 천천히 내린다", 0.95,
                   [(0, None, "CALM", None), (0.05, "expoOut", "CALM", {"Root": [0, -0.2, 0.45, 0, -18, 0], "Torso": [-16, 2, 0], "Head": [20, 22, 8]}),
                    (0.22, "backOut", "ROAR", None), (0.5, "sineOut", "ROAR", {"Torso": [22, 0, 0], "Head": [40, 12, 0]}), (0.95, "sineInOut", "CALM", None)],
                   ['{ t = 0.24, k = "Fx", n = "Roar" }', '{ t = 0.25, k = "Shake", a = 0.2, d = 0.3 }'], "\t\tBlendIn = 0.02,\n", 1)
t += "\n" + motion("Guard", "방어: 도끼를 움켜쥐어 자루를 가로로 들고 얼굴 앞에서 받는다", 0.7,
                   [(0, None, "CALM", None), (0.07, "expoOut", "BLOCK", None), (0.2, "sineOut", "BLOCK", {"Root": [0, -0.8, 0.4, 0, -10, 0], "Torso": [-16, 0, 0], "Head": [18, 10, 0]}), (0.7, "sineInOut", "CALM", None)],
                   ['{ t = 0.08, k = "Fx", n = "HaftBlock" }'], "\t\tBlendIn = 0.03,\n", 1)
t += "\n" + motion("Dodge", "회피: 낮게 숙여 공격 밑으로 파고들고, 도끼를 뒤로 끌며 어깨로 들이받는다", 0.7,
                   [(0, None, "CALM", None), (0.08, "expoOut", "DRAG", {"Root": [0, -1.2, 0, 0, -30, 0], "Torso": [-50, 0, 0], "Head": [36, 12, 0]}),
                    (0.2, "expoOut", "DRAG", {"Root": [0, -0.7, -1.0, 0, 20, 0], "Torso": [-30, 30, 0], "Head": [20, -20, 0], "LArm": [70, -30, -30]}),
                    (0.4, "sineOut", "DRAG", {"Root": [0, -0.7, -0.9, 0, 16, 0], "Torso": [-28, 26, 0], "Head": [20, -16, 0], "LArm": [70, -30, -30]}), (0.7, "sineInOut", "CALM", None)],
                   ['{ t = 0.2, k = "Fx", n = "ShoulderCheck" }'], "\t\tBlendIn = 0.02,\n", 1)

sk = []
sk.append(motion("BloodCrash", "핏빛 분쇄: 도끼를 뒤로 끌며 웅크렸다 도약 → 머리 위로 치켜든 도끼를 두 손으로 내려찍어 날이 땅에 박힌다", 1.7,
                 [(0, None, "CALM", None), (0.2, "quadOut", "DRAG", None), (0.45, "cubicOut", "RAISE", {"Root": [0, 0.4, 0.3, 0, -12, 0]}), (0.55, "expoOut", "CHOP", None),
                  (1.0, "linear", "CHOP", {"Root": [0, -1.05, -0.7, 0, -16, 0]}), (1.3, "cubicInOut", "CALM", {"Root": [0, -0.35, 0, 0, -18, 0], "Torso": [-14, 2, 0]}), (1.7, "sineInOut", "CALM", None)],
                 ['{ t = 0.22, k = "Fx", n = "BloodBoil" }', '{ t = 0.22, k = "Dash", to = "Target", gap = 4.2, d = 0.3, arc = 3.5 }', '{ t = 0.42, k = "Trail", on = true }',
                  '{ t = 0.55, k = "Hit", i = 1, fx = "BloodCrash" }', '{ t = 0.56, k = "Stop", d = 0.14 }', '{ t = 0.57, k = "Shake", a = 0.9, d = 0.5 }',
                  '{ t = 0.7, k = "Trail", on = false }', '{ t = 1.15, k = "Dash", to = "Home", d = 0.35 }']))
sk.append(motion("DoubleSlash", "쌍베기: 오른 어깨 위에서 왼쪽 아래로, 곧장 왼 어깨 위에서 오른쪽 아래로 — 한 걸음씩 파고든다", 1.5,
                 [(0, None, "CALM", None), (0.2, "cubicOut", "CUT_A0", None), (0.3, "expoOut", "CUT_A1", None), (0.46, "cubicOut", "CUT_B0", None), (0.56, "expoOut", "CUT_B1", None),
                  (0.95, "sineOut", "CUT_B1", {"Root": [0, -0.76, -0.9, 0, -30, 0], "Torso": [-32, -28, 0], "Head": [26, 30, 0]}), (1.5, "sineInOut", "CALM", None)],
                 ['{ t = 0.05, k = "Dash", to = "Target", gap = 4, d = 0.2 }', '{ t = 0.2, k = "Trail", on = true }', '{ t = 0.3, k = "Hit", i = 1, fx = "AxeSlashA" }',
                  '{ t = 0.31, k = "Stop", d = 0.06 }', '{ t = 0.56, k = "Hit", i = 2, fx = "AxeSlashB" }', '{ t = 0.57, k = "Stop", d = 0.1 }', '{ t = 0.58, k = "Shake", a = 0.5, d = 0.3 }',
                  '{ t = 0.75, k = "Trail", on = false }', '{ t = 1.05, k = "Dash", to = "Home", d = 0.3 }']))
sk.append(motion("Burst", "광역 폭발: 두 손을 자루 아래에 모아 도끼를 옆으로 뻗고 두 바퀴 회오리 → 머리 위로 들어 땅에 내리꽂아 폭발", 2.0,
                 [(0, None, "CALM", None), (0.2, "cubicOut", "WHIRL", None), (0.5, "linear", "WHIRL", {"Root": [0, -0.5, 0, 0, -330, 0]}), (0.8, "linear", "WHIRL", {"Root": [0, -0.5, 0, 0, -690, 0]}),
                  (1.0, "cubicOut", "RAISE", {"Root": [0, 0.2, 0.3, 0, -736, 0]}), (1.1, "expoOut", "CHOP", {"Root": [0, -0.95, -0.6, 0, -736, 0]}),
                  (1.55, "linear", "CHOP", {"Root": [0, -0.92, -0.6, 0, -736, 0]}), (2.0, "sineInOut", "CALM", {"Root": [0, -0.06, 0, 0, -738, 0]})],
                 ['{ t = 0.2, k = "Trail", on = true }', '{ t = 0.25, k = "Fx", n = "Whirl" }', '{ t = 0.55, k = "Fx", n = "Whirl" }', '{ t = 1.1, k = "Hit", i = 1, fx = "BurstBlast" }',
                  '{ t = 1.11, k = "Stop", d = 0.12 }', '{ t = 1.12, k = "Shake", a = 0.8, d = 0.5 }', '{ t = 1.3, k = "Trail", on = false }']))
sk.append(motion("Guard", "가드(스킬): 자루를 가로로 들고 오래 버틴다", 1.1,
                 [(0, None, "CALM", None), (0.14, "backOut", "BLOCK", None), (0.8, "sineInOut", "BLOCK", {"Root": [0, -0.72, 0.2, 0, -10, 0], "Torso": [-15, 0, 0]}), (1.1, "sineInOut", "CALM", None)],
                 ['{ t = 0.14, k = "Fx", n = "HaftBlock" }']))
sk.append(motion("Meditate", "호흡(2026-10-03 사용자: '명상' → '호흡'): 도끼 머리를 앞 땅에 짚고 자루 끝에 두 손을 포개 기댄 채, 크게 들이쉬고(가슴을 펴 고개를 듦) 길게 내쉰다(어깨가 처짐) — 두 번", 2.6,
                 [(0, None, "CALM", None), (0.45, "cubicInOut", "BREATH", None), (1.0, "sineInOut", "BREATH", {"Root": [0, -0.04, 0, 0, -18, 0], "Torso": [4, 0, 0], "Head": [12, 16, 0]}),
                  (1.55, "sineInOut", "BREATH", {"Root": [0, -0.14, 0, 0, -18, 0], "Torso": [-10, 0, 0], "Head": [-12, 16, 0]}),
                  (1.95, "sineInOut", "BREATH", {"Root": [0, -0.06, 0, 0, -18, 0], "Torso": [2, 0, 0], "Head": [6, 16, 0]}), (2.6, "sineInOut", "CALM", None)],
                 ['{ t = 0.5, k = "Fx", n = "Meditate" }']))
t += "\n\tSkills = {\n" + "\n".join(sk) + "\t},\n}\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(t)
print("썼다", os.path.normpath(OUT))
