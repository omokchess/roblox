"""광전사 '차분한 전투광' 자세(2026-10-02 사용자: "짐승 같은 느낌보단 차분한 전투광, 도끼를 한 손에 쥔 채 힘 푼 채 서 있게,
잡기·놓기 때도 차분하게").
  CALM  꼿꼿이 힘 빼고 선다. 오른손은 늘어져 자루 끝(가죽 아래쪽)을 느슨히 쥐고, 도끼 머리는 오른쪽 뒤 땅에 눕혀 끌린다
        (날 면이 땅에 닿게 — 무기 X 축이 위). 고개는 살짝 숙여 눈만 치켜 적을 본다.
  HANG  들림: 축 늘어져 매달리고, 도끼는 한 손에 머리가 아래로 늘어진다(공중이라 땅에 안 닿음)
도끼 무기 공간: 원점 = 오른손 쥔 점, +Y 머리 쪽(눈 3.45), 날 -Z(끝 -1.39), 턱 아래 끝 y 1.96.
땅 = HRP 공간 y -3. 머리 가장 낮은 점이 땅 바로 위(-2.96)에 오도록 자루 기울기를 찾는다.
쓰는 법: python berserker_calm.py → Luau 줄"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]
# 도끼 머리 둘레 점(무기 공간)
HEAD_PTS = [(0, 3.45, 0), (0, 4.32, -1.3), (0, 4.0, -1.0), (0, 3.6, -1.39), (0, 2.6, -1.33), (0, 1.96, -1.26), (0, 2.2, -0.7), (0, 4.0, 0), (0, 3.45, 0.45), (0, -1.25, 0)]
GRIP_Y = -0.15  # 손이 쥔 자루 자리(가죽 아래쪽)


def frame_flat(d):
    """날 축 d, 날 면이 땅에 눕게(무기 X = 위쪽에 가깝게), 날(-Z)은 바깥(+X 월드) 쪽"""
    up = (0, 1, 0)
    x = norm(sub(up, scale(d, sum(a * b for a, b in zip(up, d)))))
    z = cross(x, d)
    if -z[0] < 0:  # -Z 가 오른쪽(바깥)을 보게
        x = scale(x, -1)
        z = cross(x, d)
    return tuple(tuple(v[i] for v in (x, d, z)) for i in range(3))


def lowest(P):
    return min(wpoint(P, "W", p)[1] for p in HEAD_PTS[:-1])


def calm():
    P = {"Root": (0, -0.06, 0, 0, -18, 0), "Torso": (-7, 2, 0), "Head": (-6, 16, -3), "RArm": (-14, 0, 9), "LArm": (2, 0, -7),
         "RLeg": (4, 0, 7), "LLeg": (-3, 0, -7)}
    h = hand(P, "R")
    best = None
    for k in range(0, 61):
        pitch = math.radians(5 + k)  # 수평에서 아래로
        yaw = math.radians(28)  # 뒤에서 바깥쪽으로 벌림
        d = norm((math.sin(yaw) * math.cos(pitch), -math.sin(pitch), math.cos(yaw) * math.cos(pitch)))
        R = frame_flat(d)
        origin = add(h, scale(d, -GRIP_Y))
        P["W"] = aim(P, "W", R, origin)
        lo = lowest(P)
        e = abs(lo - (-2.96))
        if best is None or e < best[0]:
            best = (e, P["W"], round(5 + k, 1), lo)
    P["W"] = best[1]
    return P, best


def hang():
    P = {"Root": (0, 0, 0, 2, -18, 0), "Torso": (-4, 0, 0), "Head": (-12, 20, 0), "RArm": (-4, 0, 6), "LArm": (0, 0, -6),
         "RLeg": (6, 0, 4), "LLeg": (-2, 0, -4)}
    h = hand(P, "R")
    d = norm((0.08, -1, 0.12))
    origin = add(h, scale(d, -GRIP_Y))
    P["W"] = aim(P, "W", frame(d, (1, 0, 0)), origin)
    return P


if __name__ == "__main__":
    P, (e, w, pitch, lo) = calm()
    print(f"-- CALM: 자루 기울기 {pitch}°, 머리 가장 낮은 점 {lo:.2f}, 손 {[round(v, 2) for v in hand(P, 'R')]}")
    print("local CALM = { " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }")
    H = hang()
    print(f"-- HANG: 머리 가장 낮은 점 {lowest(H):.2f}")
    print("local HANG = { " + ", ".join(f"{k} = {f(H[k])}" for k in KEYS) + " }")
    # 다른 모션과 이어 붙일 때 오일러 표기를 가까운 쪽으로(check_wrap)
    refs = {
        "ROAR": (0, 0, 0, -42, -5.1, 7), "BLOCK": (-0.11, -0.38, 0.02, -84.4, -177.4, -11.2), "DRAG_FWD": (0, 0, 0, -3.9, 11, -189.3),
        "FERAL_387": (0, -1.5, 0.02, -53.1, -34.6, -387.3), "CUT_B1": (0, -0.59, 0, -197.2, -190.8, -258.3), "SLAM": (0, -0.41, -0.01, -51.4, -204.5, 46.2),
        "PLANT": (-0.01, 0.39, -0.01, 109.9, -1.5, -99.2), "CUT_A0": (0, -0.6, 0.01, -1.9, -78.3, 4.6), "WHIRL": (0, -0.21, -0.01, 2.7, -54.2, -88.5),
        "FERAL": (0, -1.5, 0.02, -53.1, -34.6, -27.3),
    }
    for name, ref in refs.items():
        print(f"-- CALM W near {name}: {f(near(P['W'], ref))}")
