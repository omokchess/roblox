"""청의 검사 자세 계산(2026-10-25). azure_gen.py 가 이 POSES 로 모션 파일을 쓴다 — 자세값의 출처(손으로 고치지 말 것).

대태도(Odachi, 설계 치수 ×1.3 — WeaponDefinitions 의 ODACHI): 칼 W 의 쥔 점 = 오른손(코등이 바로 아래, 무기 y 0),
손잡이 −1.37~0.39, 날 0.57~5.79, 등(+Z) 쪽으로 휨. 검집 O 는 **등에 멘다**(Hand = Back: 몸통에 붙고 O 값 = 몸통 공간 자리·회전).
검집 기준점(입 바로 아래)은 칼이 꽂혀 있을 때 칼 무기 공간 y 1.03(SHEATH_Y).

2026-10-25 사용자: "대태도가 좀 많이 작은 것 같은데 … 등에 매게 하고 크기를 더 키울까?" →
  · 대기: 검집은 오른 어깨 뒤에서 왼 엉덩이 뒤로 비스듬히, 칼자루가 오른 어깨 위로 솟는다. 몸은 왼쪽으로 조금 틀어
    전투 카메라(오른쪽 앞 위)에 등의 대태도가 보이게 하고, 고개는 적을 본다.
  · 발도: 오른손이 어깨 너머 칼자루를 잡고(R6 곧은 팔이 정확히 닿는 자리) 한순간 뽑아 벤다. 뽑은 뒤 검집은 등에 그대로.
  · 검집 타격·방어: 두 손으로 검집째 등에서 들어 쓴다(검집 O 를 칼 W 에 맞춰 겹친다).
몸·다리를 파고드는지(hits)와 칼끝·검집 끝이 땅(-3) 위인지를 찍어 본다.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403,E402

K = 1.3
SHEATH_Y = 0.79 * K
TIP_Y = 4.45 * K
TSUKA_LOW = -1.0  # 왼손이 두 손으로 쥘 때 손잡이 아래쪽(무기 y)


def sori(y):
    s = max(0.0, (y / K - 0.44) / 4.01)
    return K * 0.34 * s * s


def slope(y):
    return math.degrees(math.atan(2 * 0.34 * max(0.0, y / K - 0.44) / (4.01 * 4.01)))


def T_of(P):
    return solve(P)["Torso"]


def back_cf(P):
    v = P["O"]
    return T_of(P) * angles(v[3], v[4], v[5]) * cfp(v[0], v[1], v[2])


def set_back(P, R_world, origin):
    """등 검집을 월드 회전·기준점에 — O 값(몸통 공간, CombatRig: Angles 다음 자기 축으로 밀기)"""
    T = T_of(P)
    a = to_angles(mm(tr(T.R), R_world))
    off = mv(tr(R_world), sub(origin, T.p))
    P["O"] = tuple(round(x, 3) for x in off) + tuple(round(x, 2) for x in a)


def saya_point(P, y):
    """검집 위 점(검집 공간 y, 휨 포함)"""
    return back_cf(P).pt((0, y, sori(y + SHEATH_Y) - sori(SHEATH_Y)))


def on_back(P, ref_t, dir_t, edge_t):
    """검집을 등에: 기준점 ref_t·방향 dir_t(입 → 끝)·날 쪽(-Z) edge_t — 몸통 공간"""
    T = T_of(P)
    R = frame(mv(T.R, norm(dir_t)), mv(T.R, edge_t))
    set_back(P, R, T.pt(ref_t))


def place_sword(P, depth=0.0):
    """검집 안에 칼을 넣는다(depth = 손잡이 쪽으로 뽑혀 나온 길이)"""
    oc = back_cf(P)
    y = SHEATH_Y + depth
    R = mm(oc.R, rx(-(slope(y) - slope(SHEATH_Y))))
    P["W"] = aim(P, "W", R, oc.pt((0, -y, -(sori(y) - sori(SHEATH_Y)))))


def saya_with_sword(P):
    """칼(W)에 검집을 씌운다(검집째 들어 쓸 때)"""
    wc = weapon_cf(P, "W")
    set_back(P, wc.R, wc.pt((0, SHEATH_Y, 0)))


def grip_hilt(P, depth=0.0):
    """오른팔을 칼 쥔 점(무기 원점)에 — 등에 꽂힌(depth 만큼 뽑힌) 칼자루를 잡는다. 어긋남을 돌려준다"""
    place_sword(P, depth)
    target = weapon_cf(P, "W").p
    P["RArm"], err = reach(P, "R", target, hint=P.get("RArm"))
    place_sword(P, depth)  # 팔이 바뀌었으니 칼을 다시 검집에 맞춘다
    return round(err, 3)


def blade(P, dir_t, edge_t):
    """오른손에 쥔 칼: 날 방향·날이 향하는 쪽(몸통 공간)"""
    T = T_of(P)
    R = frame(mv(T.R, norm(dir_t)), mv(T.R, edge_t))
    P["W"] = aim(P, "W", R, hand(P, "R"))


def tip(P):
    return wpoint(P, "W", (0, TIP_Y, sori(TIP_Y)))


def blade_above(P, dir_xz, edge_t, pitches, want=-2.6):
    best = None
    for p in pitches:
        r = math.radians(p)
        d = (dir_xz[0] * math.cos(r), math.sin(r), dir_xz[1] * math.cos(r))
        Q = dict(P)
        blade(Q, d, edge_t)
        h = tip(Q)[1]
        if best is None or abs(h - want) < best[0]:
            best = (abs(h - want), Q, p)
    P.update(best[1])
    return best[2]


BOXES = {"Torso": (1.0, 1.0, 0.5), "RLeg": (0.5, 1.0, 0.5), "LLeg": (0.5, 1.0, 0.5), "Head": (0.6, 0.5, 0.6)}


def hits(P):
    w = solve(P)
    pts = [wpoint(P, "W", (0, y, sori(y))) for y in [0.8 + i * 0.33 for i in range(16)]]
    pts += [saya_point(P, y) for y in [-0.3 + i * 0.33 for i in range(16)]]
    n = 0
    for name, (hx, hy, hz) in BOXES.items():
        inv = w[name].inv()
        for p in pts:
            q = inv.pt(p)
            if abs(q[0]) < hx and abs(q[1]) < hy and abs(q[2]) < hz:
                n += 1
    return n, round(min(p[1] for p in pts), 2)


# 등 검집: 오른 어깨 뒤 → 왼 엉덩이 뒤.
# 2026-10-25 사용자: "모든 모션에서 검집이 90도 돌아가있음" — 날이 등 바깥(+Z)을 보게 두어 검집의 넓은 면이 등에서
# 지느러미처럼 섰다. 날을 등 판 안에서 왼 위(목 쪽)로 돌려 검집 넓은 면이 등에 눕게 했다(휨도 등 판 안에서 보인다).
BACK_REF = (0.75, 1.25, 0.64)
BACK_DIR = (-0.72, -0.68, 0.12)
BACK_EDGE = (-0.68, 0.72, 0.0)


def base(**kw):
    P = {
        "Root": (0, -0.2, 0, 0, 24, 0),
        "Torso": (-5, 0, 0),
        "Head": (2, -22, 0),
        "RArm": (10, 0, 8),
        "LArm": (10, 0, -8),
        "RLeg": (12, 0, -4),
        "LLeg": (-10, 0, 5),
    }
    P.update(kw)
    return P


def carried(P, ref=BACK_REF, direction=BACK_DIR):
    on_back(P, ref, direction, BACK_EDGE)
    place_sword(P)


POSES, NOTES, REPORT = {}, {}, []


def keep(name, note, P, err=None):
    POSES[name] = P
    NOTES[name] = note
    n, low = hits(P)
    REPORT.append(f"{name:10s} 몸 파고듦 {n:2d}  가장 낮은 점 {low:6.2f}  칼끝 {[round(v, 2) for v in tip(P)]}" + (f"  손 어긋남 {err}" if err is not None else ""))


P = base()
carried(P)
keep("STANCE", "대기 — 등에 비스듬히 멘 대태도(칼자루가 오른 어깨 위로 솟음). 몸을 왼쪽으로 조금 틀어 등의 칼을 보이고, 무릎을 굽혀 적을 노려본다", P)

P = base(Head=(6, -26, 0), RArm=(160, 10, 10), LArm=(18, 0, -14))
carried(P)
e = grip_hilt(P, 0.1)
keep("THUMB", "버릇 — 어깨 너머 칼자루를 쥐어 칼을 한 치 들썩였다가 놓는다", P, e)

P = base(Root=(0, -0.5, 0.05, 0, 18, 0), Torso=(-14, 4, 0), Head=(-6, -18, 0), RArm=(160, 10, 10), LArm=(30, 0, -30), RLeg=(28, 0, -5), LLeg=(-18, 0, 6))
carried(P)
e = grip_hilt(P)
keep("CROUCH", "발도 직전 — 깊게 숙여 오른손을 어깨 너머 칼자루로, 왼손은 앞으로 내밀어 거리를 잰다", P, e)

P = base(Root=(0, -0.42, -0.15, 0, -40, 0), Torso=(-10, -18, 0), Head=(-2, 40, 0), RArm=(88, 38, 0), LArm=(30, 0, -40), RLeg=(34, 0, -6), LLeg=(-24, 0, 6))
carried(P)
blade(P, (0.5, 0.04, -0.87), (0.87, 0, 0.5))
keep("DRAWCUT", "발도 일섬 끝 — 어깨 너머로 뽑아 내딛으며 오른팔을 앞으로 쭉, 날은 수평으로 적을 지나 오른쪽을 본다 · 검집은 등에 그대로", P)

P = base(Root=(0, -0.1, 0.1, 0, 0, 0), Torso=(8, -6, 0), Head=(14, 6, 0), RArm=(168, 10, 12), LArm=(40, 0, -40), RLeg=(6, 0, -4), LLeg=(-4, 0, 5))
carried(P)
blade(P, (0.1, 0.95, 0.3), (0, 0.3, -1))
keep("RAISE", "치켜들기 — 오른손 하나로 대태도를 머리 위로 곧게(공간을 가르기 전, 칼이 빛으로 길어진다)", P)

P = base(Root=(0, -0.52, -0.25, 0, 10, 0), Torso=(-14, 22, 0), Head=(-4, -8, 0), RArm=(88, 72, 0), LArm=(20, 0, -50), RLeg=(36, 0, -6), LLeg=(-26, 0, 6))
carried(P)
blade(P, (-0.62, -0.06, -0.78), (-0.78, 0, 0.62))
keep("SWEEP", "공간의 이해 끝 — 오른쪽에서 왼쪽으로 크게 가른 뒤 몸이 왼쪽으로 감기고 날은 왼 앞을 가리킨다", P)

P = base(Root=(0, -0.6, -0.3, 0, -10, 0), Torso=(-22, -6, 0), Head=(-14, 10, 0), RArm=(62, 22, 0), LArm=(20, 0, -36), RLeg=(40, 0, -6), LLeg=(-30, 0, 6))
carried(P)
pitch = blade_above(P, (0.12, -0.99), (0, -0.6, -0.8), range(-60, 41, 2), want=-2.55)
keep("CUTDOWN", f"내려벤 끝 — 깊게 내딛어 칼끝이 앞 아래 땅 바로 위(기울기 {pitch}°)", P)

P = base(Root=(0, -0.2, 0, 0, -10, 0), Head=(2, 10, 0), RArm=(36, 0, 56), LArm=(12, 0, -20))
carried(P)
pitch = blade_above(P, (0.7, -0.7), (0.7, 0, 0.7), range(-70, 1, 2), want=-2.5)
keep("CHIBURI", f"치부리 — 칼을 오른쪽 아래로 털어 피를 떨군다(기울기 {pitch}°)", P)

P = base(Root=(0, -0.3, 0, 0, 18, 0), Torso=(-6, 6, 0), Head=(2, -20, 0), RArm=(160, 10, 10), LArm=(14, 0, -14))
carried(P)
e = grip_hilt(P)
keep("NOTO", "납도 — 칼을 어깨 너머로 되돌려 등의 검집에 밀어 넣은 끝(딸깍)", P, e)

P = base(Root=(0, -0.18, 0, 0, 24, 0), Head=(14, -22, 4), RArm=(160, 10, 10), LArm=(78, -22, -34))
carried(P)
e = grip_hilt(P, 0.22)
keep("PEEK", "도발 — 어깨 너머로 칼을 한 자 뽑아 날빛을 보이고, 왼손 바닥을 위로 까딱(덤벼라) · 턱을 들어 내려다본다", P, e)

# 검집째 들어 치기: 두 손(오른손 y 0 · 왼손 손잡이 아래)으로 칼을 쥐고, 검집을 칼에 씌운다
P = base(Root=(0, -0.2, 0.15, 0, 10, 0), Torso=(10, 0, 0), Head=(10, -10, 0), RLeg=(6, 0, -4), LLeg=(-8, 0, 5))
eR, eL, _ = two_hand(P, (0.3, 1.9, -0.2), (-0.1, 0.6, 0.79), (0, 1, -0.3), left_y=TSUKA_LOW, hintR=(165, 20, 0), hintL=(165, -20, 0))
saya_with_sword(P)
keep("LIFT", "검집 타격 준비 — 두 손으로 검집째 등에서 들어 머리 뒤로 치켜든다", P, (eR, eL))

P = base(Root=(0, -0.42, -0.3, 0, -6, 0), Torso=(-16, 0, 0), Head=(-8, 4, 0), RLeg=(34, 0, -5), LLeg=(-24, 0, 5))
best = None
for pitch in range(-30, 31, 3):
    r = math.radians(pitch)
    Q = dict(P)
    eR, eL, _ = two_hand(Q, (0.2, -0.1, -1.1), (0.05 * math.cos(r), math.sin(r), -math.cos(r)), (0, -1, 0), left_y=TSUKA_LOW, hintR=(80, 20, 0), hintL=(80, -20, 0))
    saya_with_sword(Q)
    end = saya_point(Q, 4.9)[1]
    score = abs(end - (-1.4)) + 4 * max(eR, eL)
    if best is None or score < best[0]:
        best = (score, Q, (eR, eL))
P.update(best[1])
eR, eL = best[2]
keep("STRIKE", "검집 타격 — 내딛으며 검집째 내려쳐 검집 끝이 적을 친다", P, (eR, eL))

P = base(Root=(0, -0.3, 0.2, 0, 0, 0), Torso=(-4, 0, 0), Head=(-2, 0, 0))
eR, eL, _ = two_hand(P, (0.55, 0.15, -1.0), (-0.75, 0.6, -0.28), (0, 0.2, -1), left_y=SHEATH_Y + 1.5, hintR=(80, 30, 0), hintL=(90, -20, 0))
saya_with_sword(P)
keep("BLOCK", "방어 — 검집째 몸 앞에 비스듬히 들어 두 손(칼자루·검집)으로 받아 막는다", P, (eR, eL))

P = base(Root=(0, -0.24, 0.6, 0, 24, 0), Torso=(14, 4, 0), Head=(16, -20, 0), RArm=(30, 0, 30), LArm=(30, 0, -30), RLeg=(4, 0, -4), LLeg=(-2, 0, 5))
carried(P)
keep("RECOIL", "피격 — 상체가 뒤로 젖혀지고 두 팔이 흩어진다(칼은 등에)", P)

P = base(Root=(1.2, -0.55, 0.9, 0, 24, -6), Torso=(-10, 0, 8), Head=(-4, -22, -6), RArm=(20, 0, 30), LArm=(20, 0, -24), RLeg=(-10, 0, -12), LLeg=(-20, 0, 4))
carried(P)
keep("STEPBACK", "회피 — 낮게 뒤로 미끄러져 비켜선다", P)

P = base(Root=(0, 0.05, 0, 3, 20, 2), Torso=(4, 0, 0), Head=(10, -20, 0), RArm=(6, 0, 10), LArm=(6, 0, -10), RLeg=(-4, 0, 2), LLeg=(4, 0, -2))
carried(P)
keep("HANG", "들림 — 꼿꼿이 매달려 적을 내려다본다(팔짱 낀 듯 느슨히)", P)

P = base(Root=(0, -0.45, 0, 0, 24, 0), Torso=(-12, 0, 0), Head=(-8, -22, 0), RArm=(24, 10, 14), LArm=(24, -10, -14), RLeg=(26, 0, -4), LLeg=(-16, 0, 5))
carried(P)
keep("LAND", "내려놓임 — 무릎을 굽혀 사뿐히 내려선다", P)

P = base(Root=(0, -0.3, 0, 0, 24, 0), Torso=(-10, 0, 0), Head=(-22, -22, 0))
carried(P)
keep("BOW", "호흡 — 눈을 감고 고개를 숙여 숨을 고른다", P)


# ── 2026-10-25 사용자 말 설명으로 다시 짠 자세 ─────────────────────────────

# 천천히 뽑기(2026-10-25 사용자: "검집에서 검을 빼는 모션을 천천히 재생").
# 오른손은 어깨 너머 칼자루를, 왼손은 검집 입 바로 아래를 쥐고 두 팔을 벌려 검집을 등에서 끌어낸다 — 칼은 두 손 사이 한 줄에
# 놓이고(칼자루 → 검집 끝), 두 손 사이가 벌어진 만큼 뽑힌다. R6 곧은 팔로 벌릴 수 있는 길이(뽑힘 약 3.4)가 끝이라
# 남은 한 뼘(칼끝까지 4.75)은 칼이 빠지는 한순간(Release 섬광) 안에 지나간다.
# 팔 방향은 몸통 공간 (방위각 0 = 오른쪽 · 90 = 뒤, 높이각) — 몸·검집이 겹치지 않고 검집 끝이 땅 위인 것을 찾아 정했다.
LGRIP_Y = 0.45  # 왼손이 쥐는 검집 자리(입에서 검집 쪽으로)


def sph(az, el):
    a, e = math.radians(az), math.radians(el)
    return (math.cos(e) * math.cos(a), math.sin(e), math.cos(e) * math.sin(a))


def draw_stage(P, r_dir, l_dir):
    """두 팔을 몸통 공간 방향으로 뻗고 그 사이에 칼+검집을 건다 → 뽑힌 길이"""
    T = T_of(P)
    for side, d, key in (("R", r_dir, "RArm"), ("L", l_dir, "LArm")):
        P[key], _ = reach(P, side, add(pivot(P, side), scale(norm(mv(T.R, d)), ARM)), hint=P.get(key))
    H, G = hand(P, "R"), hand(P, "L")
    ax = norm(sub(G, H))
    depth = dist(G, H) - SHEATH_Y - LGRIP_Y
    set_back(P, frame(ax, mv(T.R, BACK_EDGE)), add(H, scale(ax, SHEATH_Y + depth)))
    place_sword(P, depth)
    grip_hilt(P, depth)
    P["LArm"], _ = reach(P, "L", saya_point(P, LGRIP_Y), hint=P["LArm"])
    return round(depth, 2)


# 몸을 왼쪽으로 60° 틀어 오른 어깨를 적에게 — 오른손이 어깨 위 높이 칼자루를 끌어올려 하늘을 배경으로 날이 드러나게
# (전투 카메라는 오른쪽 옆 위. 처음엔 몸을 30°만 틀어 칼이 등 뒤에 가려 뽑는 것이 잘 안 보였다)
DRAW_BODY = dict(Root=(0, -0.3, 0, 0, 60, 0), Torso=(-4, 14, 0), Head=(4, -50, 0))
DEPTH = {}
for name, r_dir, l_dir, note in (
    ("DRAW1", sph(90, 74), sph(90, 5), "뽑기 1 — 오른손은 칼자루를 위로, 왼손은 검집 입을 쥐어 등 뒤로 끌어낸다(한 자쯤 드러남)"),
    ("DRAW2", sph(70, 56), sph(138, -19), "뽑기 2 — 두 팔이 더 벌어져 날이 절반쯤 드러난다(발도술의 절정은 여기서 챙! 멈춘다)"),
    ("DRAW3", sph(30, 38), sph(150, -19), "뽑기 3 — 두 팔을 어깨 높이로 활짝 벌려 칼끝만 검집에 남았다"),
):
    P = base(**DRAW_BODY)
    carried(P)
    DEPTH[name] = draw_stage(P, r_dir, l_dir)
    keep(name, note + f" · 뽑힘 {DEPTH[name]}", P)


# 뽑은 칼을 오른 어깨 위로 치켜든 끝(발도가 끝난 순간 — 이어서 왼쪽 아래로 사선베기)
P = base(Root=(0, -0.24, 0.05, 0, -18, 0), Torso=(6, -12, 0), Head=(2, 18, 0), RArm=(172, 0, 28), LArm=(40, 0, -30), RLeg=(8, 0, -4), LLeg=(-8, 0, 5))
carried(P)
blade(P, (-0.25, 0.7, 0.67), (0.35, 0.45, -0.8))
keep("OUT", "뽑아 든 끝 — 칼을 오른 어깨 위로 치켜들어 날이 하늘 뒤를 본다(검집은 등에 돌아가 있다)", P)

# 왼쪽 아래로 사선베기(袈裟斬り) 끝: 몸이 왼쪽으로 감기고 칼끝이 왼 앞 아래 땅 위
P = base(Root=(0, -0.5, -0.25, 0, 14, 0), Torso=(-18, 24, 0), Head=(-6, -14, 0), LArm=(10, 0, -46), RLeg=(36, 0, -6), LLeg=(-26, 0, 6))
carried(P)
P["RArm"] = point_arm(P, "R", T_of(P).pt((-1.4, -1.6, -1.6)))
pitch = blade_above(P, (-0.62, -0.78), (-0.55, -0.55, -0.6), range(-70, 11, 2), want=-2.5)
keep("KESA", f"사선베기 끝 — 오른 어깨 위에서 왼쪽 아래로 크게 갈라 칼끝이 왼 앞 땅 바로 위(기울기 {pitch}°)", P)

# 올려베기 끝(잔상·흐름): 아래에서 오른 위로 쳐올려 칼이 머리 위 오른쪽 하늘을 가리킨다
P = base(Root=(0, -0.12, 0.05, 0, -34, 0), Torso=(10, -16, 0), Head=(10, 28, 0), LArm=(30, 0, -40), RLeg=(-12, 0, -4), LLeg=(20, 0, 6))
carried(P)
P["RArm"] = point_arm(P, "R", T_of(P).pt((1.9, 2.9, -1.3)))
blade(P, (0.45, 0.78, -0.43), (0.25, 0.7, 0.6))
keep("RISE", "올려베기 끝 — 왼 아래에서 오른 위로 쳐올려 칼이 머리 위 오른쪽 하늘을 가리킨다", P)

# 발도술의 절정 — 이미 벤 자세(사용자 그림): 아주 낮게 앞발을 깊이 굽히고 뒷발은 뒤로 길게, 칼은 땅 가까이 앞으로 수평
P = base(Root=(0, -0.92, -0.2, 0, -6, 0), Torso=(-24, 0, 0), Head=(16, -4, 0), LArm=(-48, 0, -24), RLeg=(56, 0, -8), LLeg=(-56, 0, 6))
carried(P)
P["RArm"] = point_arm(P, "R", (0.95, -2.15, -1.7))
P["W"] = aim(P, "W", frame(norm((0.08, 0.03, -1.0)), (1.0, -0.15, 0.0)), hand(P, "R"))
keep("ZAN", "베고 지나간 끝(사용자 그림) — 아주 낮게 앞무릎을 굽히고 뒷발을 뒤로 길게 뻗어, 칼을 땅 가까이 앞으로 수평으로 겨눈다", P)

# 공간의 이해 들머리: 오른발을 살짝 들어 물 위에 올리고(또옥) — 고개를 숙여 발끝을 본다
P = base(Root=(0, -0.12, 0, 0, 24, 0), Torso=(2, 0, 0), Head=(-16, -14, 0), RLeg=(30, 0, -4), LLeg=(-4, 0, 5))
carried(P)
keep("FOOTLIFT", "물 위에 발을 올리기 전 — 오른발을 살짝 들고 고개를 숙여 발끝을 본다", P)
P = base(Root=(0, -0.24, -0.08, 0, 24, 0), Torso=(-2, 0, 0), Head=(-18, -14, 0), RLeg=(16, 0, -4), LLeg=(-8, 0, 5))
carried(P)
keep("FOOTDOWN", "또옥 — 발끝이 물 위에 닿는 순간(무게가 앞발로 옮겨 간다)", P)

# 도발 까딱: 왼손 끝을 위로 튕긴다
P = base(Root=(0, -0.18, 0, 0, 24, 0), Head=(16, -22, 4), RArm=(160, 10, 10), LArm=(104, -16, -28))
carried(P)
e = grip_hilt(P, 0.22)
keep("FLICK", "도발 까딱 — 내민 왼손 끝을 위로 튕긴다(덤벼라)", P, e)


# ── 공간의 이해(2026-10-26 사용자: 연속 블링크로 적진을 가로질러 줄 끝에서 꽂고 → 격자 검흔이 필드 전체를 벤다) ─────


def blade_w(P, dir_w, edge_w, want=None, pitches=None):
    """오른손 칼을 캐릭터 공간 방향으로(몸통 기울기와 상관없이). want 면 칼끝 높이가 want 에 가깝게 아래로 숙인다"""
    if want is None:
        P["W"] = aim(P, "W", frame(norm(dir_w), edge_w), hand(P, "R"))
        return 0
    best = None
    flat_d = norm((dir_w[0], 0, dir_w[2]))
    for p in pitches or range(-60, 31, 2):
        r = math.radians(p)
        d = (flat_d[0] * math.cos(r), math.sin(r), flat_d[2] * math.cos(r))
        Q = dict(P)
        Q["W"] = aim(Q, "W", frame(d, edge_w), hand(Q, "R"))
        h = tip(Q)[1]
        if best is None or abs(h - want) < best[0]:
            best = (abs(h - want), Q, p)
    P.update(best[1])
    return best[2]


# 강한 가로베기 끝: 오른쪽 아래로 아주 조금 기운 가로 — 깊게 내딛고 몸이 오른쪽으로 감긴다
P = base(Root=(0, -0.62, -0.3, 0, -40, 0), Torso=(-16, -24, 0), Head=(-4, 34, 0), LArm=(20, 0, -60), RLeg=(40, 0, -6), LLeg=(-34, 0, 6))
carried(P)
P["RArm"] = point_arm(P, "R", (2.3, -0.5, -1.6))
blade_w(P, (0.86, -0.2, -0.47), (0.4, -0.15, 0.9))
keep("SLASHR", "강한 베기 끝 — 오른쪽 아래로 아주 조금 기운 가로베기, 깊게 내딛고 몸이 오른쪽으로 감긴다", P)


# 공간의 이해 블링크 자세(2026-10-26 사용자: "블링크했을 때 동작이 이전 동작에 비해 크게 달라지도록") —
# 높이(아주 낮게 ↔ 공중) · 몸 방향(오른쪽으로 크게 틂 ↔ 뒤돌아섬) · 칼 방향을 블링크마다 번갈아 바꾼다. 팔·칼은 원래 자세 그대로
def variant(src, root, **legs):
    P = {k: tuple(v) for k, v in POSES[src].items()}
    P["Root"] = root
    P.update(legs)
    return P


keep("SKYRISE", "공중 올려베기 — 뛰어올라 공중에서 오른 위로 쳐올린 채(다리를 벌려 뜬다)",
     variant("RISE", (0, 1.1, 0.05, 0, -34, 0), RLeg=(40, 0, -6), LLeg=(-34, 0, 6)))
keep("SIDEKESA", "틀어 사선베기 — 몸을 오른쪽으로 크게 틀어 낮게 왼 아래로 갈라 내린 끝",
     variant("KESA", (0, -0.6, -0.2, 0, -70, 0)))
keep("BACKSWEEP", "뒤돌아 휩쓸기 — 몸이 거의 반 바퀴 돌아 등을 적 쪽에 두고 크게 휩쓴 끝",
     variant("SWEEP", (0, -0.5, -0.25, 0, 190, 0)))


# 공간의 이해 준비(2026-10-30 사용자: "내딛고 준비자세를 할 땐 달리기 준비자세랑 비슷하게 하면서 오른손으론 검 손잡이를 잡고")
P = base(Root=(0, -0.72, -0.1, 0, 10, 0), Torso=(-32, 6, 0), Head=(10, -30, 0), RArm=(160, 10, 10), RLeg=(-46, 0, -6), LLeg=(44, 0, 6))
carried(P)
e = grip_hilt(P)
P["LArm"] = point_arm(P, "L", (-0.7, -2.6, -1.7))
keep("SET", "달리기 준비 — 앞발을 굽히고 뒷발을 뒤로 뻗어 몸을 낮게 숙이고, 오른손은 어깨 너머 칼자루, 왼손은 앞 땅 가까이", P, e)

P = base(Root=(0, -0.5, -0.35, 0, 8, 0), Torso=(-38, 4, 0), Head=(16, -6, 0), RArm=(160, 10, 10), LArm=(-40, 0, -20), RLeg=(60, 0, -6), LLeg=(-50, 0, 6))
carried(P)
e = grip_hilt(P)
keep("RUNOFF", "박차고 나감 — 오른 무릎을 앞으로 끌어올리며 몸을 던진다, 오른손은 칼자루", P, e)

# 2026-10-30 사용자: "달려가는 모션이 멈춘 후에 사라지는데, 달려가는 모션중에 사라지도록" — 박찬 뒤 한 걸음 더 달려 나가는 도중에 사라진다
P = base(Root=(0, -0.46, -0.4, 0, 6, 0), Torso=(-40, 2, 0), Head=(18, -4, 0), RArm=(160, 10, 10), LArm=(40, 0, -16), RLeg=(-52, 0, -6), LLeg=(62, 0, 6))
carried(P)
e = grip_hilt(P)
keep("RUNOFF2", "달려 나가는 둘째 걸음 — 왼 무릎이 앞으로, 오른다리는 뒤로 차 내고 왼팔은 앞으로 흔든다(이 걸음 도중에 사라진다), 오른손은 칼자루", P, e)


# 자세마다 칼의 상태(azure_gen 이 키 사이 중간 키를 넣을 때 본다)
#   back  = 칼이 등 검집에 꽂혀 있다(DEPTH 만큼 뽑힘) · carry = 검집째 손에 든다 · drawn = 뽑아 들었다
#   hilt  = 두 손이 칼자루·검집을 쥐고 뽑는 중(검집이 등에서 떨어져 있다 — DEPTH 만큼 뽑힘)
MODE = {name: "back" for name in POSES}
for name in ("LIFT", "STRIKE", "BLOCK"):
    MODE[name] = "carry"
for name in ("DRAWCUT", "RAISE", "SWEEP", "CUTDOWN", "CHIBURI", "OUT", "KESA", "RISE", "ZAN", "SLASHR", "SKYRISE", "SIDEKESA", "BACKSWEEP"):
    MODE[name] = "drawn"
for name in ("DRAW1", "DRAW2", "DRAW3"):
    MODE[name] = "hilt"
DEPTH.update({"THUMB": 0.1, "PEEK": 0.22, "FLICK": 0.22})
# 오른손이 칼자루를 잡고 있는 꽂힌 자세(검집째 들기·뽑기와 이어질 수 있다)
ON_HILT = {"THUMB", "CROUCH", "NOTO", "PEEK", "FLICK", "SET", "RUNOFF", "RUNOFF2"}


if __name__ == "__main__":
    print("\n".join(REPORT))
