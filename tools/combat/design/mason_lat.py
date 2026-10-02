"""정을 가슴 앞에 가로로(날은 왼쪽 아래 = 돌면, 머리는 오른쪽 = 망치 쪽), 망치는 목 가까이(choke) 세워 쥐고 옆으로 톡.
mason_search 로 고른 자리(몸통 공간)를 다시 세운다."""
import sys; sys.path.insert(0,'.')
from mason_gen import *

def lat(ry_, tor, ldir, yd, ch, phi, head=(-18, 20, 0), root_y=-0.25, legs=((-14, 0, 10), (22, 0, -10))):
    P = {"Root": (0, root_y, 0, 0, ry_, 0), "Torso": (tor, 0, 0), "Head": head, "RLeg": legs[0], "LLeg": legs[1]}
    T0 = T_of(P); lp = pivot(P, "L")
    P["LArm"], e = reach(P, "L", add(lp, scale(mv(T0.R, norm(ldir)), ARM)), hint=(80, -10, 0))
    P["O"] = aim_axis(P, "O", mv(T0.R, yd))
    cap = wpoint(P, "O", CAP); d = norm(mv(weapon_cf(P, "O").R, (0, 1, 0))); n = scale(d, -1)
    a2 = norm(cross(n, (0, 1, 0))); b2 = cross(n, a2)
    hy = add(scale(a2, math.cos(phi * D)), scale(b2, math.sin(phi * D)))
    R = frame(hy, n); hp = sub(cap, mv(R, (0, 2.2 - ch, -0.8)))
    P["RArm"], e2 = reach(P, "R", hp, hint=(80, 30, 0))
    P["W"] = aim(P, "W", R, sub(hp, mv(R, (0, ch, 0))))
    return P, round(e, 3), round(e2, 3)

def cockc(P, ch, dx, a, dy=0.0):
    """팔을 dx·dy 만큼 더 들고, 망치를 쥔 손(자루 y=ch)을 중심으로 자기 X 축 둘레 a 만큼 젖힘(머리가 면 반대쪽으로)"""
    Q = dict(P)
    r = P["RArm"]
    Q["RArm"] = (round(r[0] + dx, 1), round(r[1] + dy, 1), r[2])
    Wc = weapon_cf(Q, "W")
    h = Wc.pt((0, ch, 0))
    R = mm(Wc.R, rx(a))
    Q["W"] = near(aim(Q, "W", R, sub(h, mv(R, (0, ch, 0)))), P["W"])
    return Q

if __name__ == "__main__":
    for name, args in [("M1", (-30, -10, (0.3, -0.4, -1), (1, 0.7, 0.2), 1.5, 240)), ("M2", (-30, -10, (0.6, -0.6, -1), (1, 0.4, 0), 1.2, 290)), ("M3", (-30, -20, (0.3, -0.4, -1), (1, 0.4, 0), 1.5, 290))]:
        P, e, e2 = lat(*args)
        out(name, P, f"err {e} {e2}")
