import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *

UP = (0, 1, 0)


def up_flasks(P, wdir=UP, odir=UP):
    """두 병을 세계 기준 wdir/odir 로 세운다(비틀기 없이)"""
    if "RArm" in P:
        P["W"] = aim_axis(P, "W", wdir)
    if "LArm" in P:
        P["O"] = aim_axis(P, "O", odir)


def line(name, P):
    show(name, P)
    keys = [k for k in ("O",) if k in P]
    if keys:
        print(f"    O = {f(P['O'])}")


# 1) 투척 준비(대기): 왼 어깨를 적에게(몸을 오른쪽으로 55°), 오른손 병은 어깨 위 머리 옆, 왼팔은 45° 위로 표적을 가리킨다
for arm in [(140, -40, 20), (130, -30, 25), (150, -50, 15)]:
    P = {"Root": (0, -0.12, 0, 0, -55, 0), "Torso": (-4, 10, 0), "Head": (4, 40, 0), "RLeg": (-12, 0, 12), "LLeg": (14, 0, -14)}
    P["RArm"] = arm
    P["LArm"] = point_arm(P, "L", (0, 4.5, -8))
    up_flasks(P)
    print("  right hand", tuple(round(v, 2) for v in hand(P, "R")), "head", tuple(round(v, 2) for v in solve(P)["Head"].pt((0, 0, 0))))
    line("READY", P)

# 2) 감기(던지기 직전): 몸을 더 오른쪽으로 틀고 병을 머리 뒤로
P = {"Root": (0, -0.3, 0.3, 0, -85, 0), "Torso": (10, -10, 0), "Head": (6, 70, 0), "RLeg": (-20, 0, 14), "LLeg": (20, 0, -14), "RArm": (165, -70, 30)}
P["LArm"] = point_arm(P, "L", (0, 3, -8))
up_flasks(P, (0.2, 1, 0.6))
line("COCK", P)
# 3) 던진 끝: 몸이 적 쪽으로 돌아 숙이고, 오른팔은 앞 아래로 따라감(손은 비었지만 병 자리는 팔 연장선)
P = {"Root": (0, -0.5, -0.5, 0, 10, 0), "Torso": (-30, -10, 0), "Head": (16, -10, 0), "RLeg": (30, 0, 10), "LLeg": (-30, 0, -10), "RArm": (70, 20, 10), "LArm": (10, 0, -40)}
up_flasks(P, (0, 0.2, -1), UP)
line("RELEASE", P)

# 4) 다지기: 왼손 병(절구)을 배 앞에 세우고, 오른손 병을 거꾸로 세워 그 입에 짓찧는다
P = {"Root": (0, -0.15, 0, 0, -30, 0), "Torso": (-24, 0, 0), "Head": (-24, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": (60, -20, 0)}
up_flasks(P)
neck = wpoint(P, "O", (0, 1.0, 0))
for dx, nm in [(0, "GRIND"), (0.12, "GRIND_A"), (-0.12, "GRIND_B")]:
    Q = dict(P)
    tgt = add(neck, (dx, 1.35, 0))
    v, e = reach(Q, "R", tgt, hint=(90, 30, 0))
    Q["RArm"] = v
    Q["W"] = aim_axis(Q, "W", sub(neck, hand(Q, "R")))
    print(nm, "err", round(e, 2))
    line(nm, Q)

# 5) 섞기: 오른손 병을 기울여(입이 아래 왼쪽) 왼손 병 입 위로 붓는다
P = {"Root": (0, -0.15, 0, 0, -30, 0), "Torso": (-14, 0, 0), "Head": (-18, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": (70, -24, 0)}
up_flasks(P)
neck = wpoint(P, "O", (0, 1.0, 0))
Q = dict(P)
v, e = reach(Q, "R", add(neck, (0.9, 0.9, 0.1)), hint=(110, 10, 0))
Q["RArm"] = v
Q["W"] = aim_axis(Q, "W", sub(add(neck, (0, 0.25, 0)), hand(Q, "R")))
print("POUR err", round(e, 2))
line("POUR", Q)
# 흔들기: 두 병을 머리 높이로
P = {"Root": (0, -0.15, 0, 0, -30, 0), "Torso": (0, 0, 0), "Head": (6, 16, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "RArm": (130, 30, 10), "LArm": (130, -30, -10)}
up_flasks(P)
line("SHAKE_HI", P)
P["RArm"], P["LArm"] = (110, 30, 10), (110, -30, -10)
up_flasks(P, (0.1, 1, -0.3), (-0.1, 1, -0.3))
line("SHAKE_LO", P)

# 6) 마시기: 병 입을 입에 대고 바닥을 치켜든다
P = {"Root": (0, -0.1, 0, 0, -30, 0), "Torso": (12, 0, 0), "Head": (34, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": (40, 0, -20)}
H = solve(P)["Head"]
mouth = H.pt((0, -0.25, -0.62))
v, e = reach(P, "R", add(mouth, mv(H.R, (0.3, 1.1, -0.8))), hint=(150, 40, 0))
P["RArm"] = v
P["W"] = aim_axis(P, "W", sub(mouth, hand(P, "R")))
up_flasks({}, UP)
P["O"] = aim_axis(P, "O", UP)
print("DRINK err", round(e, 2), "cork", tuple(round(x, 2) for x in wpoint(P, "W", (0, 1.42, 0))), "mouth", tuple(round(x, 2) for x in mouth))
line("DRINK", P)

# 7) 끌어안기(들림·방어): 두 병을 가슴 앞에 세워 감싼다
P = {"Root": (0, 0.1, 0, 4, -30, 4), "Torso": (-14, 0, 0), "Head": (-10, 30, 0), "RArm": (70, 44, 0), "LArm": (70, -44, 0)}
up_flasks(P)
line("HUG", P)
# 8) 명상: 쪼그려 앉아 두 병을 눈 위로 들어 빛에 비춘다
P = {"Root": (0, -1.1, 0, 0, -30, 0), "Torso": (-6, 0, 0), "Head": (16, 10, 0), "RArm": (120, 20, 0), "LArm": (120, -20, 0), "RLeg": (90, 0, 16), "LLeg": (90, 0, -16)}
up_flasks(P)
line("LIGHT", P)
# 9) 피격: 오른팔이 휙 튀어 병이 기운다(놓칠 뻔)
P = {"Root": (0, -0.1, 0.8, 0, -40, 10), "Torso": (12, 14, -10), "Head": (24, 30, 0), "RArm": (170, -30, 40), "LArm": (60, 0, -60)}
up_flasks(P, (0.6, 0.5, 0.4), UP)
line("JOLT", P)
