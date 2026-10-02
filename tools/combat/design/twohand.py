"""양손 무기 자세 도우미: 몸통 공간으로 무기 자리·방향을 주면 두 팔·W 를 구한다."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from posecalc import *


def f(v):
    return "{ " + ", ".join(f"{(round(x, 2) if abs(x) < 3 else round(x, 1)):g}" for x in v) + " }"


def wrap(a, ref):
    return a + 360 * round((ref - a) / 360)


def near(w, ref):
    """같은 회전의 두 오일러 표기(CFrame.Angles) 중 ref 에 가까운 것 — 키 사이 보간이 짧은 길로 돌게"""
    a, b, c = w[3], w[4], w[5]
    cands = [(a, b, c), (a + 180, 180 - b, c + 180)]
    best = None
    for x, y, z in cands:
        x, y, z = wrap(x, ref[3]), wrap(y, ref[4]), wrap(z, ref[5])
        d = abs(x - ref[3]) + abs(y - ref[4]) + abs(z - ref[5])
        if best is None or d < best[0]:
            best = (d, (x, y, z))
    return tuple(w[:3]) + tuple(round(v, 1) for v in best[1])


def T_of(P):
    return solve(P)["Torso"]


def one_hand(P, grip_t, dir_t, zhint_t=None, hint=(60, 0, 0)):
    """오른손 하나: 쥔 점(몸통 공간)·날 방향. 쥔 점에 팔이 닿게 한 뒤 무기를 그 자리·방향에 둔다."""
    T = T_of(P)
    g = T.pt(grip_t)
    v, e = reach(P, "R", g, hint=hint)
    P["RArm"] = v
    d = mv(T.R, dir_t)
    if zhint_t is None:
        P["W"] = aim_axis(P, "W", d)
    else:
        P["W"] = aim(P, "W", frame(d, mv(T.R, zhint_t)), hand(P, "R"))
    return e


def two_hand(P, grip_t, dir_t, zhint_t, left_y=-0.6, hintR=(70, 20, 0), hintL=(70, -20, 0), search=0.5, right_y=0.0):
    """두 손: 오른손 = 무기 y=right_y, 왼손 = y=left_y. 쥔 점을 search 반경 안에서 옮겨 두 팔 어긋남이 가장 작게."""
    T = T_of(P)
    d = norm(mv(T.R, dir_t))
    zh = mv(T.R, zhint_t)
    best = None
    n = 5
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            for k in range(-n, n + 1):
                off = (i * search / n, j * search / n, k * search / n)
                g = T.pt(add(grip_t, off))
                pr, pl = pivot(P, "R"), pivot(P, "L")
                gr = add(g, scale(d, right_y))
                gl = add(g, scale(d, left_y))
                e = max(abs(dist(gr, pr) - ARM), abs(dist(gl, pl) - ARM)) + 0.05 * math.sqrt(sum(o * o for o in off))
                if best is None or e < best[0]:
                    best = (e, g, off)
    _, g, off = best
    vR, eR = reach(P, "R", add(g, scale(d, right_y)), hint=hintR)
    vL, eL = reach(P, "L", add(g, scale(d, left_y)), hint=hintL)
    P["RArm"], P["LArm"] = vR, vL
    # 무기 원점 = 쥔 점 g (오른손 자리 기준 y=right_y 만큼 아래)
    P["W"] = aim(P, "W", frame(d, zh), sub(g, (0, 0, 0)))
    return round(eR, 2), round(eL, 2), tuple(round(o, 2) for o in off)


def show(name, P, extra=""):
    keys = [k for k in ("Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W") if k in P]
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in keys) + " }" + (" -- " + extra if extra else ""))
