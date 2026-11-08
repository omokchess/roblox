"""월 메이슨 망치 손목 고침(2026-11-08): 대기 계열 키(TAP/LIFT/HIGH)에서 자루가 아래팔과 이루는 각이 112~128° 로
꺾여 있어 망치가 옆으로 누워 보였다. 쥔 점은 그대로 두고 자루-아래팔 각이 TARGET 이 되게 손목만 돌린다."""
import math, re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *
REF = {}
TARGET = float(sys.argv[1]) if len(sys.argv) > 1 else 100
SPIN = float(sys.argv[2]) if len(sys.argv) > 2 else 0
src = open(os.path.join(os.path.dirname(__file__), "../../../src/shared/Combat/Motions/WallMason.luau"), encoding="utf8").read()
def rod(R, ax, ang):
    ax = norm(ax); c, s = math.cos(ang*D), math.sin(ang*D)
    K = ((0,-ax[2],ax[1]),(ax[2],0,-ax[0]),(-ax[1],ax[0],0))
    K2 = mm(K,K)
    Rr = tuple(tuple((1 if i==j else 0)+s*K[i][j]+(1-c)*K2[i][j] for j in range(3)) for i in range(3))
    return mm(Rr, R)
for name in ("TAP","LIFT","HIGH"):
    body = re.search(r'^local %s = \{ (Root.*)\}$' % name, src, re.M).group(1)
    P = {}
    for k in ["Root","Torso","Head","RArm","LArm","RLeg","LLeg","W","O"]:
        m = re.search(r'\b'+k+r' = \{([^}]*)\}', body)
        if m: P[k] = tuple(float(x) for x in m.group(1).split(','))
    cf = weapon_cf(P,"W"); g = grip_cf(P,"W")
    fore = mv(solve(P)["RArm"].R,(0,-1,0)); h = mv(cf.R,(0,1,0))
    now = math.degrees(math.acos(sum(a*b for a,b in zip(h,fore))))
    ax = cross(h, fore)
    R2 = rod(cf.R, ax, now - TARGET)
    h1 = mv(R2,(0,1,0)); R2 = rod(R2, h1, SPIN)
    off = P["W"][:3]
    W = near(aim(P,"W",R2,add(g.p, mv(R2, off))), REF.get('W', P["W"]))
    REF.setdefault('W', W)
    cf2 = None
    P2 = dict(P, W=W); h2 = mv(weapon_cf(P2,"W").R,(0,1,0)); f2 = mv(weapon_cf(P2,"W").R,(0,0,-1))
    print(name, round(now,1), "->", round(math.degrees(math.acos(sum(a*b for a,b in zip(h2,fore)))),1), "handle", [round(x,2) for x in h2], "face", [round(x,2) for x in f2], "face(torso)", [round(x,2) for x in mv(tr(T_of(P).R), f2)])
    print("W =", f(W))
