import os
import sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *

def place(P, side, target, d, prefer, hint):
    key = "RArm" if side == "R" else "LArm"
    pref = norm(prefer)
    best = None
    for x in range(int(hint[0]) - 80, int(hint[0]) + 81, 4):
        for y in range(int(hint[1]) - 80, int(hint[1]) + 81, 4):
            for z in (-30, -15, 0, 15):
                Q = dict(P); Q[key] = (x, y, z)
                h = hand(Q, side)
                off = sub(h, target)
                e = (math.sqrt(sum(v * v for v in off)) - d) ** 2 * 4 + dist(norm(off), pref) ** 2
                if best is None or e < best[0]:
                    best = (e, (x, y, z))
    P[key] = best[1]
    h = hand(P, side)
    return round(dist(h, target) - d, 2), round(math.degrees(math.acos(max(-1, min(1, sum(a * b for a, b in zip(norm(sub(h, target)), pref)))))), 1)

# 다지기
for larm in [(60, -20, 0), (70, 0, 0), (75, 15, 0)]:
    P = {"Root": (0, -0.15, 0, 0, -30, 0), "Torso": (-24, 0, 0), "Head": (-24, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": larm}
    P["O"] = aim_axis(P, "O", (0, 1, 0))
    neck = wpoint(P, "O", (0, 1.05, 0))
    r = place(P, "R", neck, 1.35, (0, 1, 0), (110, 40, 0))
    P["W"] = aim_axis(P, "W", sub(neck, hand(P, "R")))
    print("GRIND larm", larm, r); show("GRIND", P); print("    O =", f(P["O"]))
# 붓기
for larm in [(70, -24, 0), (75, 0, 0)]:
    P = {"Root": (0, -0.15, 0, 0, -30, 0), "Torso": (-14, 0, 0), "Head": (-18, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": larm}
    P["O"] = aim_axis(P, "O", (0, 1, 0))
    mouthL = wpoint(P, "O", (0, 1.3, 0))
    r = place(P, "R", add(mouthL, (0, 0.15, 0)), 1.35, (0.6, 0.5, 0.2), (110, 30, 0))
    P["W"] = aim_axis(P, "W", sub(add(mouthL, (0, 0.15, 0)), hand(P, "R")))
    print("POUR larm", larm, r); show("POUR", P); print("    O =", f(P["O"]))
# 마시기
P = {"Root": (0, -0.1, 0, 0, -30, 0), "Torso": (12, 0, 0), "Head": (34, 10, 0), "RLeg": (8, 0, 6), "LLeg": (-6, 0, -6), "LArm": (40, 0, -20)}
H = solve(P)["Head"]
mouth = H.pt((0, -0.3, -0.62))
r = place(P, "R", mouth, 1.42, add(mv(H.R, (0, 0.8, -0.6)), (0, 0, 0)), (150, 40, 0))
P["W"] = aim_axis(P, "W", sub(mouth, hand(P, "R")))
P["O"] = aim_axis(P, "O", (0, 1, 0))
print("DRINK", r, "cork", tuple(round(x, 2) for x in wpoint(P, "W", (0, 1.42, 0))), "mouth", tuple(round(x, 2) for x in mouth))
show("DRINK", P); print("    O =", f(P["O"]))
