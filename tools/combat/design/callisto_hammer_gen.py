"""
칼리스토 북두칠성 망치(2026-11-01 블렌더판 — 오른손 y 0, 왼손 y -0.85, 머리 가운데 y 2.6) 자세 계산.
사용자: "망치 쥐고 있는 모션도 손봐야 할 듯 — 지금은 의수마냥 손에 꽂아 놓은 느낌".
→ 대기는 어깨에 메고(오른손 하나), 공격은 두 손(왼손이 자루 아래를 받친다).
2026-11-01 두 번째 손질(사용자: "망치 스탠딩 모션은 사람 기준 팔뚝을 팔이라 정의해서, 180도정도 뒤집은 다음 망치를 어깨에 걸치게 해줘"):
  R6 팔(팔꿈치 없음)을 사람의 아래팔로 본다 → 팔을 위로 세워(RArm X 약 180) 손이 어깨 위·앞쪽에 오고, 오른손 하나로 쥔 자루가 오른 어깨 윗면에 얹혀
  망치 머리는 등 뒤로 넘어간다(shoulder). 몸통·머리와 안 겹치는지, 자루가 어깨에 닿는지는 같은 계산(상자 겹침 검사)으로 확인한다.
레퍼런스: 엘든 링 두 손 거대 망치 대기(어깨 메기) · 슬레지해머 스윙(뒷손 고정, 앞손이 미끄러져 내려왔다가 칠 때 단단히) — US7694392,
          군인이 총을, 나무꾼이 도끼를 어깨에 메는 자세(손은 어깨 앞 위, 자루는 어깨 윗면을 넘어 머리가 등 뒤로).
출력 = Motions/Callisto.luau 에 붙일 자세 표(몸통 공간: X 오른쪽 · Y 위 · -Z 앞).

돌리는 법(저장소 루트에서, 먼저 lune run tools/combat/export_motions.luau — 망치 부품 크기를 weapons.json 에서 읽는다):
  python tools/combat/design/callisto_hammer_gen.py hobs   # 대기(어깨 메기)만 계산·검사 — 몇 초
  python tools/combat/design/callisto_hammer_gen.py        # 전부(두 손 자세들은 쥔 점을 찾느라 몇 분)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403

REF = (0, 0, 0, 0, 0, 0)
RY, LY = 0.0, -0.85
GROUND = -3.0  # HRP 높이 3(다리 2 + 몸통 반) — 이 공간에서 땅

BODY_SIZE = {"Torso": (2, 2, 1), "Head": (1.25, 1.2, 1.2), "RArm": (1, 2, 1), "LArm": (1, 2, 1), "RLeg": (1, 2, 1), "LLeg": (1, 2, 1)}
WEAPONS_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "weapons.json")


def body(root, torso, head, rleg=(8, 0, 4), lleg=(-6, 0, -4)):
    return {"Root": root, "Torso": torso, "Head": head, "RLeg": rleg, "LLeg": lleg}


def two(name, P, grip, d, z, hR, hL, ref, note=""):
    r = two_hand(P, grip, d, z, left_y=LY, right_y=RY, hintR=hR, hintL=hL, search=0.45)
    P["W"] = near(P["W"], ref)
    head = wpoint(P, "W", (0, 2.6, 0))
    show(name, P, "%s 어긋남 %s 머리 (%.2f, %.2f, %.2f) %s" % (name, r, head[0], head[1], head[2], note))
    return P


def fit_two(name, mk, grip, d, z, hR, hL, ref, head_y):
    """두 손 자세에서 망치 머리 가운데가 head_y(월드)에 오도록 쥔 점 y 를 찾는다(땅에 박히지 않게)."""
    best = None
    for k in range(-24, 25):
        g = (grip[0], grip[1] + k * 0.05, grip[2])
        P = mk()
        two_hand(P, g, d, z, left_y=LY, right_y=RY, hintR=hR, hintL=hL, search=0.3)
        err = abs(wpoint(P, "W", (0, 2.6, 0))[1] - head_y)
        if best is None or err < best[0]:
            best = (err, g)
    return two(name, mk(), best[1], d, z, hR, hL, ref, "(맞춘 쥔 점 y %.2f)" % best[1][1])


def one(name, P, grip, d, z, hint, ref, larm, note=""):
    e = one_hand(P, grip, d, z, hint=hint)
    P["W"] = near(P["W"], ref)
    P["LArm"] = larm
    head = wpoint(P, "W", (0, 2.6, 0))
    show(name, P, "%s 어긋남 %.2f 머리 (%.2f, %.2f, %.2f) %s" % (name, e, head[0], head[1], head[2], note))
    return P


# ── 상자 겹침 검사(자세 → 몸 부품 · 망치 부품을 상자로, 분리축 정리) ──────────────────────────
def _axes(cf):
    return [tuple(cf.R[i][k] for i in range(3)) for k in range(3)]


def box_depth(cfa, sa, cfb, sb):
    """두 상자의 겹침 깊이: 양수 = 파고든 깊이, 음수 = 떨어진 틈(분리축 위에서 잰 값 — 가까운 상자끼리는 실제 틈과 거의 같다)"""
    A, B = _axes(cfa), _axes(cfb)
    ha, hb = [s / 2 for s in sa], [s / 2 for s in sb]
    d = sub(cfb.p, cfa.p)
    axes = list(A) + list(B)
    for i in range(3):
        for j in range(3):
            c = cross(A[i], B[j])
            n = math.sqrt(sum(x * x for x in c))
            if n > 1e-6:
                axes.append(tuple(x / n for x in c))
    best = 1e9
    for ax in axes:
        ra = sum(ha[i] * abs(sum(A[i][k] * ax[k] for k in range(3))) for i in range(3))
        rb = sum(hb[i] * abs(sum(B[i][k] * ax[k] for k in range(3))) for i in range(3))
        best = min(best, ra + rb - abs(sum(d[k] * ax[k] for k in range(3))))
    return best


def hammer_blocks():
    """weapons.json 의 망치 메인 조각 중 상자들(이름, 크기, 자리)"""
    parts = json.load(open(WEAPONS_JSON, encoding="utf-8"))["CallistoHammer"]["Main"]["Parts"]
    return [(p["Name"], p["Size"], p["At"]) for p in parts if p["Shape"] == "Block"]


# 손이 쥐는 자리라 오른팔과 겹쳐도 되는 조각(겹침 상한 GRIP_OVERLAP)
GRIP_PARTS = ("Shaft", "GripHigh", "GripLow", "Pommel", "RingMizar")
GRIP_OVERLAP = 0.45


def overlaps(P):
    """{(망치 조각, 몸 부품): 겹침 깊이} — 틈 -0.3 보다 가까운 것만"""
    w = solve(P)
    wcf = weapon_cf(P, "W")
    out = {}
    for name, size, at in hammer_blocks():
        cf = wcf * cfp(at[0], at[1], at[2]) * orient(at[3], at[4], at[5])
        for bn, bs in BODY_SIZE.items():
            dep = box_depth(cf, size, w[bn], bs)
            if dep > -0.3:
                out[(name, bn)] = dep
    return out


def shoulder_report(P):
    """어깨 메기 검사: 자루–몸통 틈, 몸 부품과의 겹침(손 쥐는 곳은 오른팔과 GRIP_OVERLAP 까지 허용), 손·머리 자리(몸통 공간), 얼굴 앞 가림"""
    w = solve(P)
    T = w["Torso"]
    ov = overlaps(P)
    hand_t = mv(tr(T.R), sub(hand(P, "R"), T.p))
    head_t = mv(tr(T.R), sub(wpoint(P, "W", (0, 2.6, 0)), T.p))
    gap = -ov.get(("Shaft", "Torso"), -9)
    bad = {k: v for k, v in ov.items() if v > 0.02 and not (k[1] == "RArm" and k[0] in GRIP_PARTS and v <= GRIP_OVERLAP)}
    face = [y / 10 for y in range(-14, 33, 2) if (lambda q: abs(q[0]) < 0.85 and 0.6 < q[1] < 2.3 and q[2] < 0.1)(mv(tr(T.R), sub(wpoint(P, "W", (0, y / 10, 0)), T.p)))]
    print("  [검사] 자루–몸통 틈 %.2f(0~0.15 이면 얹힘) · 손 (%.2f, %.2f, %.2f) · 머리 가운데 (%.2f, %.2f, %.2f)" % (gap, *hand_t, *head_t))
    print("  [검사] 오른팔과 겹침(손 쥐는 곳): " + ", ".join("%s %.2f" % (k[0], v) for k, v in sorted(ov.items()) if k[1] == "RArm" and v > 0) or "없음")
    print("  [검사] 몸을 뚫는 곳: " + (", ".join("%s–%s %.2f" % (k[0], k[1], v) for k, v in sorted(bad.items())) if bad else "없음") + " · 얼굴 앞을 지나는 자루 점: " + (str(face) if face else "없음"))
    return gap, bad, face


def shoulder(name, P, arm, contact, roll, ref, larm, c_y=1.19, note=""):
    """어깨에 멘 대기. 오른팔 각(arm)을 정하면 손(팔 끝)이 정해지고, 자루는 그 손과 어깨 윗면의 접점(몸통 공간 x, z · 높이 c_y)을 지나는 직선이다.
    roll = 머리 앞면(무기 -Z)이 자루 둘레로 돌아간 각. 자루가 어깨를 넘어 머리는 등 뒤 아래로 걸린다."""
    P["RArm"] = tuple(arm)
    P["LArm"] = larm
    T = T_of(P)
    H = mv(tr(T.R), sub(hand(P, "R"), T.p))
    C = (contact[0], c_y, contact[1])
    d = norm(sub(C, H))
    dw = norm(mv(T.R, d))
    ref_ = (1, 0, 0) if abs(dw[0]) < 0.9 else (0, 1, 0)
    e1 = norm(cross(dw, ref_))
    e2 = cross(dw, e1)
    zh = tuple(math.cos(roll * D) * e1[k] + math.sin(roll * D) * e2[k] for k in range(3))
    P["W"] = near(aim(P, "W", frame(dw, zh)), ref)
    head = wpoint(P, "W", (0, 2.6, 0))
    show(name, P, "%s 머리 (%.2f, %.2f, %.2f) %s" % (name, head[0], head[1], head[2], note))
    shoulder_report(P)
    return P


# 1) 대기 — 어깨 메기: 팔뚝(R6 팔)을 세워 손이 어깨 위·앞쪽(오른쪽 귀 곁), 자루는 어깨 윗면 뒤쪽 가장자리를 넘어 머리가 등 뒤 아래에 걸린다.
#    몸은 1페이즈 관찰자 그대로(몸 20° 틀고 상체 살짝 젖힘). 왼팔은 허벅지 곁으로 늘어뜨려 손목 카메라가 앞을 본다.
def make_obs():
    return shoulder("HOBS", body((0, 0, 0, 0, 20, 0), (4, -6, 0), (-6, -16, 6)), (183.2, 76.8, 4.6), (0.9, 0.45), 41.2, REF, (14, 6, -6))


def _quat(R):
    t = R[0][0] + R[1][1] + R[2][2]
    if t > 0:
        s = math.sqrt(t + 1) * 2
        return ((R[2][1] - R[1][2]) / s, (R[0][2] - R[2][0]) / s, (R[1][0] - R[0][1]) / s, s / 4)
    i = max(range(3), key=lambda k: R[k][k])
    j, k = (i + 1) % 3, (i + 2) % 3
    s = math.sqrt(R[i][i] - R[j][j] - R[k][k] + 1) * 2
    q = [0.0] * 4
    q[i] = s / 4
    q[j] = (R[j][i] + R[i][j]) / s
    q[k] = (R[k][i] + R[i][k]) / s
    q[3] = (R[k][j] - R[j][k]) / s
    return tuple(q)


def _mat(q):
    x, y, z, w = q
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
            (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
            (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)))


def w_between(P, wa, wb, k):
    """무기 회전 wa → wb 의 k(0~1) 만큼 지점(최단 호). 손(팔)은 P 그대로 — 망치만 손 둘레로 돈다"""
    Q = dict(P)
    Q["W"] = wa
    Ra = weapon_cf(Q, "W").R
    Q["W"] = wb
    Rb = weapon_cf(Q, "W").R
    qa, qb = _quat(Ra), _quat(Rb)
    dot_ = sum(a * b for a, b in zip(qa, qb))
    if dot_ < 0:
        qb = tuple(-v for v in qb)
        dot_ = -dot_
    th = math.acos(min(1.0, dot_))
    if th < 1e-6:
        return tuple(wa)
    sa, sb = math.sin((1 - k) * th) / math.sin(th), math.sin(k * th) / math.sin(th)
    q = tuple(sa * a + sb * b for a, b in zip(qa, qb))
    n = math.sqrt(sum(v * v for v in q))
    return near(aim(Q, "W", _mat(tuple(v / n for v in q))), wa)


def make_pop(OBS):
    """들썩(HPOP): 손·몸은 대기 그대로, 망치만 손 둘레로 돌려 머리가 어깨 위 하늘을 본다. 대기 ↔ 두 손 자세(머리 위·하늘·가로치기) 사이에 거쳐
    망치가 머리·몸통을 뚫고 지나지 않게 하는 다리 — 대기에서 곧장 섞으면 머리가 등 뒤에서 몸통을 가로질러 앞으로 넘어온다."""
    P = dict(OBS)
    T = T_of(P)
    dw = norm(mv(T.R, (0.2, 1, 0.35)))
    ref_ = (1, 0, 0) if abs(dw[0]) < 0.9 else (0, 1, 0)
    e1 = norm(cross(dw, ref_))
    e2 = cross(dw, e1)
    zh = tuple(math.cos(41.2 * D) * e1[k] + math.sin(41.2 * D) * e2[k] for k in range(3))
    P["W"] = near(aim(P, "W", frame(dw, zh)), OBS["W"])
    head = wpoint(P, "W", (0, 2.6, 0))
    show("HPOP", P, "HPOP 머리 (%.2f, %.2f, %.2f)" % tuple(head))
    return P


def main(only=None):
    OBS = make_obs()
    POP = make_pop(OBS)
    # 대기 버릇 1(망치 추켜 메기): 망치가 어깨에서 살짝 들썩 — 대기와 들썩 사이 20% 지점
    print("  버릇 W(들썩 20%%): %s" % (f(w_between(OBS, OBS["W"], POP["W"], 0.2)),))
    if only == "hobs":
        return
    # 2) 두 손 낮은 겨눔(막기 전·공격 준비): 머리는 앞 오른쪽 무릎 높이, 자루는 허리로 비스듬히
    READY = fit_two("HREADY", lambda: body((0, -0.35, 0.1, 0, 30, 0), (-10, 14, 0), (8, -18, 0), (22, 0, 8), (-14, 0, -8)), (0.25, -0.35, -0.95), (0.35, -0.42, -1), (0, 1, 0), (40, 20, 0), (40, -30, 0), OBS["W"], GROUND + 1.1)
    # 3) 머리 위로 치켜듦: 두 손을 머리 위로, 망치 머리는 등 뒤 위(내려찍기 준비)
    RAISE = two("HRAISE", body((0, -0.1, 0.25, 0, 10, 0), (12, 6, 0), (-2, -6, 0), (-10, 0, 6), (16, 0, -6)), (0.1, 2.0, 0.15), (0, 0.42, 1), (0, -1, 0.3), (165, 10, 0), (165, -10, 0), READY["W"])
    # 4) 내려찍은 끝: 무릎을 굽혀 앞 땅에(머리 아래면이 땅에 닿는다)
    SMASH = fit_two("HSMASH", lambda: body((0, -0.65, -0.45, 0, 6, 0), (-26, 0, 0), (16, 0, 0), (48, 0, 8), (-36, 0, -8)), (0.1, -0.1, -1.15), (0, -0.12, -1), (0, -1, 0.3), (80, 10, 0), (80, -10, 0), RAISE["W"], GROUND + 0.62)
    # 5) 가로치기 준비: 몸을 오른쪽으로 감고 망치는 오른쪽 뒤 허리 높이
    COIL = two("HCOIL", body((0, -0.3, 0, 0, -40, 0), (-8, -30, 0), (0, 30, 0), (14, 0, 8), (-10, 0, -8)), (0.55, 0.05, -0.65), (1, 0.12, 0.65), (0, 1, 0), (70, 50, 20), (70, 0, 0), READY["W"])
    # 6) 가로치기 끝: 몸이 왼쪽으로 풀리고 망치는 왼쪽 앞
    SWEEP = two("HSWEEP", body((0, -0.35, -0.25, 0, 30, 0), (-12, 32, 0), (4, -24, 0), (26, 0, 8), (-18, 0, -8)), (-0.35, 0.05, -0.95), (-1, 0.1, -0.25), (0, 1, 0), (80, -10, 0), (80, -40, 0), COIL["W"])
    # 7) 하늘로: 두 손으로 망치를 곧추세워 머리가 하늘을 본다(별을 부를 때)
    SKY = two("HSKY", body((0, 0.2, 0, 0, 0, 0), (12, 0, 0), (28, 0, 0), (0, 0, 4), (0, 0, -4)), (0.15, 2.0, -0.45), (0.02, 1, 0.12), (0, 0, 1), (165, 10, 0), (165, -10, 0), RAISE["W"])
    # 8) 올려치기 끝(공명적 성위): 한 손으로 아래에서 앞위로 휘둘러 올린 끝 — 머리가 앞 위, 왼손은 펴서 균형
    UPPER = one("HUPPER", body((0, 0.05, -0.2, 0, 10, 0), (8, -10, 0), (-10, 4, 0), (-6, 0, 4), (24, 0, -4)), (0.65, 1.15, -0.95), (0.05, 0.75, -0.66), (1, 0, 0), (140, 10, 10), READY["W"], (40, 0, -40))
    # 9) 막기: 자루를 가로로 얼굴 앞에(머리는 오른쪽, 두 손을 넓게)
    GUARD = two("HGUARD", body((0, -0.3, 0.2, 0, 10, 0), (-8, 6, 0), (12, -6, 0), (20, 0, 8), (-14, 0, -8)), (0.4, 0.95, -0.95), (1, 0.06, 0.05), (0, 0, 1), (100, 30, 0), (100, -30, 0), READY["W"])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
