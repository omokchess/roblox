"""월 메이슨 자세 계산(2026-10-02). 석공 정 작업: 왼손은 정 가운데를 쥐고 날을 돌면에 대며, 오른손은 망치를
머리 가까이(자루 y=CHOKE) 쥐고 정 머리를 톡톡 친다. 타격 키에서 망치 면(무기 공간 (0, 2.2, -0.8))이
정 머리 윗면(정 공간 (0, 0.71, 0))에 닿고, 면의 바깥 방향(-Z)이 정 축을 따라 날 쪽을 향하게 오른손을 찾는다.
땅 치기도 같은 방식(면이 아래를 보며 땅 높이 -3 에 닿게)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W", "O"]
CAP = (0, 0.71, 0)  # 정 머리 윗면
BIT = (0, -1.02, 0)  # 정 날 끝
FACE = (0, 2.2, -0.8)  # 망치 타격면
CHOKE = 0.5  # 망치를 쥔 자루 자리(머리 가까이)
GROUND = -3.0


REF = {}


def out(name, P, note=""):
    """REF(첫 자세 TAP)에 가까운 오일러 표기로 — 키 사이 보간이 뜻하지 않게 오일러로 돌지 않게"""
    for s in ("W", "O"):
        if s in REF:
            P[s] = near(P[s], REF[s])
    print(f"-- {name} {note}")
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS if k in P) + " }")


def chisel(P, lt, ydir, hint=(80, -10, 0)):
    """왼손을 몸통 공간 lt 에, 정 축(+Y = 머리 쪽)을 몸통 공간 ydir 로"""
    T = T_of(P)
    P["LArm"], e = reach(P, "L", T.pt(lt), hint=hint)
    P["O"] = aim_axis(P, "O", mv(T.R, ydir))
    return round(e, 2)


def place(P, target, facedir, ok=lambda hand_t, handle_t: True, hint=(80, 30, 0), choke=CHOKE):
    """망치 면 가운데를 target(월드)에, 면 바깥(-Z)을 facedir 로. 자루 방향을 면 둘레로 훑어 팔이 닿고 ok(몸통 공간 손·자루)인 것."""
    T = T_of(P)
    n = norm(facedir)
    a = norm(cross(n, (0, 1, 0)) if abs(n[1]) < 0.95 else cross(n, (0, 0, 1)))
    b = cross(n, a)
    pv = pivot(P, "R")
    best = None
    for i in range(720):
        phi = i * 0.5 * D
        hy = add(scale(a, math.cos(phi)), scale(b, math.sin(phi)))
        R = frame(hy, n)
        handp = sub(target, mv(R, (FACE[0], FACE[1] - choke, FACE[2])))
        if not ok(T.inv().pt(handp), mv(tr(T.R), hy)):
            continue
        e = abs(dist(handp, pv) - ARM)
        if best is None or e < best[0]:
            best = (e, R, handp)
    e, R, handp = best
    P["RArm"], e2 = reach(P, "R", handp, hint=hint)
    P["W"] = aim(P, "W", R, sub(handp, mv(R, (0, choke, 0))))
    return round(e2, 2)


def strike(P, back=0.0, hint=(80, 30, 0)):
    """망치 면을 정 머리에(back 만큼 정 축 뒤로 띄움). 손은 정 머리보다 위·오른쪽(어깨 높이에서 내려 침)."""
    cap = wpoint(P, "O", CAP)
    d = norm(mv(weapon_cf(P, "O").R, (0, 1, 0)))
    capt = T_of(P).inv().pt(cap)
    return place(P, add(cap, scale(d, back)), scale(d, -1), lambda h, hy: h[1] > capt[1] + 0.3 and h[0] > 0.7, hint)


def cock(P, dx, a, dy=0.0):
    """팔을 X 로 dx(돌기 dy) 더 들고, 손목을 a 만큼 젖힘(망치 자기 X 축 둘레, 쥔 손을 중심으로 — 머리가 면 반대쪽으로)"""
    Q = dict(P)
    r = P["RArm"]
    Q["RArm"] = (round(r[0] + dx, 1), round(r[1] + dy, 1), r[2])
    Wc = weapon_cf(Q, "W")  # 팔과 함께 돈 망치
    h = Wc.pt((0, CHOKE, 0))
    R = mm(Wc.R, rx(a))
    Q["W"] = near(aim(Q, "W", R, sub(h, mv(R, (0, CHOKE, 0)))), P["W"])
    return Q


def ground(P, pt, hint=(70, 20, 0), up=0.0, r=1.0):
    """망치 면이 땅에 아래를 보고 닿음. pt(x, z) 둘레 r 안에서 팔이 가장 잘 닿는 자리를 고른다. 손은 머리보다 위."""
    best = None
    for i in range(-4, 5):
        for j in range(-4, 5):
            q = (pt[0] + r * i / 4, pt[1] + r * j / 4)
            Q = dict(P)
            tgt = (q[0], GROUND + 0.02 + up, q[1])
            e = place(Q, tgt, (0, -1, 0), lambda h, hy: h[1] > T_of(Q).inv().pt(tgt)[1] + 0.4, hint)
            if best is None or e < best[0]:
                best = (e, Q, q)
    P.update(best[1])
    return best[0], best[2]


def tips(P):
    return f"정 날 {wpoint(P, 'O', BIT)[1]:.2f} 망치 면 {wpoint(P, 'W', FACE)[1]:.2f}"


if __name__ == "__main__":
    # 1) 정 작업(대기): 정을 가슴 앞에 가로로 들고(날은 왼쪽 아래 돌면, 머리는 오른쪽), 망치는 목 가까이(자루 y 1.2) 세워 쥐고
    #    옆으로 톡 친다. 정을 앞으로 겨누고 축을 따라 치면 망치 머리(면~뒷날 2.0)가 몸을 파고들어서(곧은 R6 팔) 이렇게 바꿨다
    #    — mason_search.py 로 망치가 몸통·머리를 파고들지 않는 자리만 골랐다(2026-10-02)
    from mason_lat import lat, cockc
    TAP, e, e2 = lat(-30, -10, (0.6, -0.6, -1), (1, 0.4, 0), 1.2, 290)
    print("tap err", e, e2)
    REF.update(W=TAP["W"], O=TAP["O"])
    out("TAP", TAP, "톡 — 망치 면이 정 머리에 닿음. " + tips(TAP))
    out("LIFT", cockc(TAP, 1.2, 0, 35), "톡 예비(손목만 젖혀 머리를 오른쪽으로)")
    out("HIGH", cockc(TAP, 1.2, 40, 80, -20), "쾅 예비(팔을 들어 망치를 오른쪽 뒤로 크게 젖힘)")

    # 2) 어깨에 멤(들림): 망치 머리를 오른 어깨 뒤에 걸치고, 정은 손가락에 걸어 내림
    SH = {"Root": (0, -0.05, 0, 0, -18, 0), "Torso": (4, 0, 0), "Head": (0, 14, 0), "RLeg": (6, 0, 8), "LLeg": (-6, 0, -8)}
    T = T_of(SH)
    SH["RArm"] = (44, 4, 4)
    SH["W"] = aim(SH, "W", frame(norm(sub(T.pt((1.15, 1.35, 0.55)), hand(SH, "R"))), mv(T.R, (0, 1, 0.3))))
    e = dist(wpoint(SH, "W", (0, 2.2, 0)), T.pt((1.15, 1.35, 0.55)))
    SH["LArm"] = (8, 0, -6)
    SH["O"] = aim_axis(SH, "O", mv(T.R, (0, 1, -0.2)))
    out("SHOULDER", SH, f"err {e:.2f} 망치 머리 높이 {wpoint(SH, 'W', (0, 2.2, 0))[1]:.2f}")

    # 3) 땅 치기: 숙여 앞 오른쪽 땅을 톡(내려놓임·축성) / 머리 위로 치켜듦 / 등 뒤에서 크게 내려침(뒷벽 허물기)
    G = {"Root": (0, -0.75, -0.1, 0, -18, 0), "Torso": (-40, 0, 0), "Head": (-6, 10, 0), "RLeg": (30, 0, 10), "LLeg": (-24, 0, -10)}
    G["LArm"] = (30, -20, -20)
    G["O"] = aim_axis(G, "O", mv(T_of(G).R, (0, 1, -0.3)))
    print("ground", ground(G, (1.1, -2.0)))
    out("GTAP", G, "땅 톡. " + tips(G))
    GH = cock(dict(G, Root=(0, -0.25, 0, 0, -18, 0), Torso=(-6, 0, 0)), 90, 40)
    out("GHIGH", GH, "머리 위로 치켜듦")
    S = {"Root": (0, -0.85, -0.45, 0, -8, 0), "Torso": (-44, -6, 0), "Head": (20, 10, 0), "RLeg": (40, 0, 10), "LLeg": (-30, 0, -10), "LArm": (20, -20, -30)}
    S["O"] = aim_axis(S, "O", mv(T_of(S).R, (0, 1, 0.3)))
    print("slam", ground(S, (0.7, -3.0), hint=(80, 10, 0)))
    out("SLAM", S, "크게 내려친 끝. " + tips(S))
    BK = {"Root": (0, -0.2, 0.3, 0, -30, 0), "Torso": (14, 20, 0), "Head": (8, -6, 0), "RArm": (200, 10, 20), "LArm": (70, -30, -30), "RLeg": (4, 0, 8), "LLeg": (-16, 0, -8)}
    Tb = T_of(BK)
    BK["W"] = near(aim_axis(BK, "W", mv(Tb.R, (0.1, -0.5, 1))), S["W"])
    BK["O"] = S["O"]
    out("BACK", BK, f"등 뒤로 젖힘 망치 머리 {wpoint(BK, 'W', (0, 2.2, 0))[1]:.2f}")

    # 4) 막기: 땅을 쳐 돌벽을 세운 뒤, 정 쥔 왼팔을 얼굴 앞에 가로 대고 버팀(망치는 낮게 준비)
    BR = {"Root": (0, -0.55, 0.4, 0, -10, 0), "Torso": (-14, 0, 0), "Head": (-6, 10, 0), "RLeg": (20, 0, 10), "LLeg": (-16, 0, -10)}
    Tr = T_of(BR)
    BR["LArm"], e = reach(BR, "L", Tr.pt((0.1, 1.1, -1.2)), hint=(110, -40, -10))
    BR["O"] = aim_axis(BR, "O", mv(Tr.R, (-0.2, 1, 0.1)))
    BR["RArm"] = (50, 20, 10)
    BR["W"] = near(aim_axis(BR, "W", mv(Tr.R, (-0.3, 0.6, -1))), TAP["W"])
    out("BRACE", BR, f"err {e:.2f}")

    # 5) 명상: 쪼그려 앉아 망치는 오른쪽 땅에 세워 짚고, 정 날을 눈앞에 들어 들여다봄
    M = {"Root": (0, -1.1, 0, 0, -18, 0), "Torso": (-10, 0, 0), "Head": (-20, 10, 0), "RLeg": (90, 0, 16), "LLeg": (90, 0, -16)}
    Tm = T_of(M)
    M["LArm"], e = reach(M, "L", Tm.pt((-0.2, 1.0, -1.25)), hint=(110, -20, 0))
    M["O"] = aim_axis(M, "O", mv(Tm.R, (0.2, -1, 0.3)))  # 날이 위(정 +Y 아래 = 머리 아래)
    print("meditate ground", ground(M, (1.8, -0.6), hint=(30, 10, 10)))
    out("SQUAT", M, f"err {e:.2f} " + tips(M))
