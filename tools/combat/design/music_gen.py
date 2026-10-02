import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from posecalc import *

YAW, RISE, ROLL, G = 60, 2, 40, 1.55


def violin(P):
    T = solve(P)["Torso"]
    B = T.pt((-0.36, 1.11, -0.5))
    Dl = (-math.sin(YAW * D) * math.cos(RISE * D), math.sin(RISE * D), -math.cos(YAW * D) * math.cos(RISE * D))
    Dw = mv(T.R, Dl)
    up = mv(T.R, (0, 1, 0))
    n0 = norm(sub(up, scale(Dw, sum(a * b for a, b in zip(up, Dw)))))
    side = norm(cross(Dw, n0))
    n = norm(add(scale(n0, math.cos(ROLL * D)), scale(side, math.sin(ROLL * D))))
    grip = add(B, scale(Dw, G))
    v, err = reach(P, "L", grip, hint=(115, 21, 11))
    P["LArm"] = v
    R = frame(Dw, n)
    P["O"] = aim(P, "O", R, grip)
    return R, n, err


def f(v):
    return "{ " + ", ".join(f"{x:g}" for x in v) + " }"


P = {"Root": (0, -0.05, 0, 0, -48, 0), "Torso": (3, 6, 0), "Head": (-14, 30, 18), "RLeg": (3, 0, 4), "LLeg": (-8, 0, -8)}
R, n, err = violin(P)
T = solve(P)["Torso"]
print("-- 턱 바이올린", "err", round(err, 3))
print("LArm =", f(P["LArm"]), "O =", f(P["O"]))


def tor(v):
    return mv(T.R, v)


# 활을 세워 든 대기
for arm in [(76, 20, 5)]:
    Q = dict(P)
    Q["RArm"] = arm
    Q["W"] = aim_axis(Q, "W", tor((-0.12, 1, 0.1)))
    print("READY RArm =", f(arm), "W =", f(Q["W"]), "hand", tuple(round(x, 2) for x in hand(Q, "R")))
# 대기 흔들림: 활끝이 박자에 맞춰 좌우로
for name, arm, d in [("SWAY_L", (77, 22, 4), (-0.2, 1, 0.08)), ("SWAY_R", (75, 18, 6), (-0.04, 1, 0.12))]:
    Q = dict(P)
    Q["RArm"] = arm
    Q["W"] = aim_axis(Q, "W", tor(d))
    print(name, "RArm =", f(arm), "W =", f(Q["W"]))

# 활 긋기(bow_stroke.py 와 같은 방식)
C = wpoint(P, "O", (0, 0.72 - G, -0.19))
vx = tuple(R[i][0] for i in range(3))
Dv = tuple(R[i][1] for i in range(3))
pr = pivot(P, "R")
hint = (115, 47, -22)
for s in (0.9, 1.1, 1.4, 1.7, 2.0, 2.3):
    best = None
    for a10 in range(0, 700, 5):
        a = a10 / 10
        bd = norm(add(scale(vx, math.cos(a * D)), scale(Dv, math.sin(a * D))))
        Rb = frame(bd, scale(n, -1))
        o = sub(C, mv(Rb, (0, s, -0.16)))
        e = abs(dist(o, pr) - ARM)
        if best is None or e < best[0]:
            best = (e, a, Rb, o)
    e, a, Rb, o = best
    v, e2 = reach(P, "R", o, hint=hint)
    hint = v
    Q = dict(P)
    Q["RArm"] = v
    w = aim(Q, "W", Rb, o)
    print(f"BOW s={s} a={a} err={e2:.2f}: RArm = {f(v)}, W = {f(w)}")

# 활을 하늘로(브릴란테·모으기)
Q = dict(P)
Q["RArm"] = (170, 14, 16)
Q["W"] = aim_axis(Q, "W", tor((0.1, 1, 0.15)))
print("RAISE RArm =", f(Q["RArm"]), "W =", f(Q["W"]))
# 내던지듯 긋고 난 끝: 팔을 바깥 아래로 쓸고 활은 팔 연장선에서 조금 들림
Q = dict(P)
Q["RArm"] = (70, -80, 58)
w = solve(Q)["RArm"]
armdir = norm(sub(w.pt((0, -1, 0)), w.pt((0, 1, 0))))
Q["W"] = aim_axis(Q, "W", add(armdir, (0, 0.45, 0)))
print("FLING RArm =", f(Q["RArm"]), "W =", f(Q["W"]))
# 인사(커트시): 활을 옆 아래로 내려 든다
Q = dict(P)
Q["RArm"] = (40, -30, 40)
w = solve(Q)["RArm"]
armdir = norm(sub(w.pt((0, -1, 0)), w.pt((0, 1, 0))))
Q["W"] = aim_axis(Q, "W", add(armdir, (0, 0.2, 0)))
print("BOWDOWN RArm =", f(Q["RArm"]), "W =", f(Q["W"]))
# 피치카토: 오른손을 지판 끝 줄 위로, 활은 세운 채
Cp = wpoint(P, "O", (0, 0.95 - G, -0.34))
Q = dict(P)
v, e = reach(Q, "R", Cp, hint=(110, 45, -20))
Q["RArm"] = v
Q["W"] = aim_axis(Q, "W", tor((0.1, 1, 0.2)))
print("PIZZ err", round(e, 2), "RArm =", f(v), "W =", f(Q["W"]))
# 피치카토 튕긴 뒤(손이 줄에서 떨어져 위로)
Q2 = dict(P)
v2, e2 = reach(Q2, "R", add(Cp, tor((0.25, 0.3, -0.1))), hint=v)
Q2["RArm"] = v2
Q2["W"] = aim_axis(Q2, "W", tor((0.15, 1, 0.2)))
print("PIZZ2 err", round(e2, 2), "RArm =", f(v2), "W =", f(Q2["W"]))
# 방어: 활을 몸 앞에 수직으로 세워 뻗는다(오선 방패의 기둥)
Q = dict(P)
Q["RArm"] = (92, 26, 0)
Q["W"] = aim_axis(Q, "W", tor((0, 1, 0)))
print("GUARDBOW RArm =", f(Q["RArm"]), "W =", f(Q["W"]))

# 바이올린을 턱에서 뗀 자세들: O 를 다시 구한다
for name, larm, ydir, top in [
    ("OPEN", (120, 30, -30), (-0.35, 1, -0.1), (0, 0, -1)),  # 팔을 벌려 목을 쥐고 치켜든다(스크롤 위)
    ("HUG", (60, 70, 0), (0.1, 1, -0.1), (0, 0, -1)),  # 가슴에 끌어안음(뒤판이 가슴)
    ("GUARDV", (52, 34, 0), (0.05, 1, 0), (0, 0, -1)),  # 가슴 앞에 세워 감쌈
    ("HIGH", (150, 20, -10), (-0.1, 1, 0.3), (0, 0.3, -1)),  # 머리 위로 치켜듦
]:
    Q = dict(P)
    Q["LArm"] = larm
    Rv = frame(tor(ydir), tor(top))
    print(name, "LArm =", f(larm), "O =", f(aim(Q, "O", Rv)))
