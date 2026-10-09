# -*- coding: utf-8 -*-
"""
forest_trees.py — 2026-10-09. 숲+평원 리메이크 3단계: 나무 숲 배치 → tools/Forest_Trees_data.luau + tools/forest_trees.svg

숲이 약 1300만 평방 스터드라 나무를 한 그루씩 손으로 놓을 수 없다. 그래서
  - 숲 덩어리(GROVES)의 **자리·크기·나무 섞임·간격**, 빈터(CLEARINGS), 길(ROADS), 띠 틈(BELT_GAPS)은 손으로 적고,
  - 덩어리 안만 간격대로 칸을 나눠 칸마다 한 그루(칸 안에서 조금 비키고, 돌림·크기만 씨앗값으로 다르게) 심는다.
  평원 둘레 띠(BELT)는 빽빽하게(그림의 "나무 빽빽").
빼는 곳: 평원 땅(Land 판) · 남은 평원 벼랑(윗면 ≥ 3.5) · 맥동·솔르헨·하이우드 구역(나중에 짓는다) · 빈터 · 길 · 숲 가장자리 14 안.
나무 틀 = ServerStorage.ForestKit(models/forest/build_kit_forest.py). 짓기: tools/Forest_Trees.luau 머리 주석.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forest_plan import FOREST, ZONES, HIGHWOOD, inside  # noqa: E402
from forest_ground import PLAINS_LAND  # noqa: E402

# 나무 섞임(틀 → 무게)
MIX = {
    "oak": {"Oak_A": 5, "Oak_B": 4, "Birch_A": 2, "Bush_A": 2, "Bush_B": 1},
    "pine": {"Pine_A": 6, "Pine_B": 5, "Bush_B": 1, "Log_A": 0.3},
    "giant": {"Giant_A": 3, "Oak_A": 3, "Oak_B": 2, "Bush_A": 2, "Log_A": 0.5},
    "mixed": {"Oak_A": 3, "Oak_B": 3, "Pine_A": 2, "Pine_B": 2, "Birch_A": 2, "Bush_A": 2, "Bush_B": 1, "Log_A": 0.3},
    "birch": {"Birch_A": 6, "Oak_B": 2, "Bush_B": 2},
    "belt": {"Oak_A": 4, "Oak_B": 3, "Pine_A": 3, "Pine_B": 2, "Giant_A": 1, "Bush_A": 3, "Bush_B": 2},
    "meadow": {"Bush_A": 3, "Bush_B": 4, "Log_A": 1},
}

# 숲 덩어리 { 이름, x0, x1, z0, z1, 섞임, 간격 } — 손으로(그림의 필드 빗금 안을 덩어리로 나눔)
GROVES = [
    # 북서
    ("북서 소나무숲", -3190, -2350, -342, 300, "pine", 22),
    ("북서 소나무숲(턱)", -2792, -2350, -418, -342, "pine", 22),
    ("북 참나무숲", -2350, -1740, -418, 250, "oak", 24),
    ("서 섞인숲", -3190, -2350, 300, 722, "mixed", 26),
    ("서 덤불벌", -2350, -1740, 250, 722, "meadow", 60),
    # 맥동 둘레·북쪽 띠
    ("맥동 서쪽 거목", -1740, -1600, -640, 722, "giant", 24),
    ("맥동 남쪽 거목숲", -1600, -1020, -450, 250, "giant", 24),
    ("맥동 동쪽 띠", -500, 706, -640, -330, "mixed", 22),
    ("북동 띠", 706, 1330, -417, -330, "mixed", 22),
    ("평원 서쪽 숲", -1600, -1020, 250, 722, "oak", 28),
    # 평원과 하이우드 사이
    ("하이우드 동쪽 숲", -1653, -1020, 722, 1280, "mixed", 24),
    # 평원 남쪽(가운데·남)
    ("남서 참나무숲", -1653, -300, 1280, 2100, "oak", 24),
    ("남 소나무숲", -300, 700, 1280, 2300, "pine", 22),
    ("남동 거목숲", 700, 1330, 1280, 3418, "giant", 28),
    ("남 자작나무숲", -1653, -300, 2100, 2967, "birch", 22),
    ("남 섞인숲", -300, 700, 2300, 2967, "mixed", 26),
    ("솔르헨 옆 숲", -222, 700, 2967, 3418, "pine", 24),
    ("동쪽 띠", 1250, 1330, -330, 1280, "belt", 16),
]
# 평원 둘레 나무 빽빽 띠: 이 상자 안 평원 땅 밖 — 간격 14
BELT = (-1020, 1250, -330, 1280)
BELT_SPACING = 16
# 빈터(필드 몬스터 자리 — 나무 없음, 덤불 조금은 meadow 덩어리가 맡는다) { 이름, x0, x1, z0, z1 }
CLEARINGS = [
    ("북 빈터", -2250, -1900, -250, 50),
    ("맥동 남 빈터", -1450, -1150, -250, 50),
    ("남서 빈터", -1100, -500, 1500, 1900),
    ("남 빈터", -100, 450, 2450, 2900),
    ("남동 빈터", 850, 1150, 2000, 2400),
    ("평원 서 빈터", -1500, -1150, 400, 650),
]
# 길(꺾은선, 폭) — 나무를 비운다
ROADS = [
    ("하이우드 → 솔르헨", [(-1653, 2384), (-1157, 2384), (-1157, 2967)], 18),
    ("평원 서문 → 하이우드", [(-745, 330), (-1300, 330), (-1300, 900), (-1653, 900)], 18),
    ("평원 서문 → 맥동", [(-1300, 330), (-1300, -450)], 18),
    ("평원 남문 → 솔르헨", [(190, 1050), (190, 1700), (-700, 1700), (-700, 2967)], 18),
]
# 띠 틈(평원에서 숲으로 나가는 문) — 길과 같은 자리
BELT_GAPS = [
    ("서문", -1020, -745, 300, 360),
    ("남문", 160, 220, 1050, 1280),
]
EDGE_MARGIN = 14
SEED = 20261009


def dist_seg(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def cliffs_left(dump):
    out = []
    if not os.path.exists(dump):
        return out
    for line in open(dump, encoding="utf-8"):
        f = line.strip().split("|")
        if len(f) >= 9 and f[1] == "Cliffs":
            x0, x1, z0, z1, top = map(float, f[3:8])
            if top >= 3.5:
                out.append((x0 - 6, x1 + 6, z0 - 6, z1 + 6))
    return out


def blocked(x, z, r, cliffs):
    """심으면 안 되는 자리인가(r = 나무 반경 여유)"""
    if not inside((x, z), FOREST):
        return "숲 밖"
    for i in range(len(FOREST)):
        (ax, az), (bx, bz) = FOREST[i], FOREST[(i + 1) % len(FOREST)]
        if dist_seg(x, z, ax, az, bx, bz) < EDGE_MARGIN + r:
            return "가장자리"
    for a, b, c, d in PLAINS_LAND:
        if a - r < x < b + r and c - r < z < d + r:
            return "평원 땅"
    for _, a, c, b, d, _ in ZONES:  # (이름, x0, z0, x1, z1, 색)
        if a - r < x < b + r and c - r < z < d + r:
            return "구역"
    if inside((x, z), HIGHWOOD):
        return "하이우드"
    for _, a, b, c, d in CLEARINGS:
        if a < x < b and c < z < d:
            return "빈터"
    for _, a, b, c, d in BELT_GAPS:
        if a < x < b and c < z < d:
            return "띠 틈"
    for _, pts, w in ROADS:
        for k in range(len(pts) - 1):
            if dist_seg(x, z, *pts[k], *pts[k + 1]) < w / 2 + r:
                return "길"
    for a, b, c, d in cliffs:
        if a < x < b and c < z < d:
            return "평원 벼랑"
    return None


RADIUS = {"Giant_A": 14, "Oak_A": 10, "Oak_B": 8, "Pine_A": 8, "Pine_B": 6, "Birch_A": 5, "Bush_A": 4, "Bush_B": 3, "Log_A": 6}


def pick(rng, mix):
    tot = sum(mix.values())
    r = rng.random() * tot
    for k, w in mix.items():
        r -= w
        if r <= 0:
            return k
    return k


def plant(rng, x0, x1, z0, z1, mix, sp, cliffs, out, used, tag):
    nx, nz = max(1, int((x1 - x0) // sp)), max(1, int((z1 - z0) // sp))
    cw, ch = (x1 - x0) / nx, (z1 - z0) / nz
    n = 0
    for i in range(nx):
        for j in range(nz):
            kind = pick(rng, MIX[mix])
            x = x0 + (i + 0.5) * cw + (rng.random() - 0.5) * cw * 0.7
            z = z0 + (j + 0.5) * ch + (rng.random() - 0.5) * ch * 0.7
            # 같은 칸을 두 덩어리가 덮으면(경계) 한 번만
            key = (round(x / 6), round(z / 6))
            if key in used:
                continue
            if blocked(x, z, RADIUS[kind] * 0.5, cliffs):
                continue
            used.add(key)
            yaw = rng.randrange(0, 360, 15)
            sc = round(0.85 + rng.random() * 0.35, 2)
            out.append((kind, round(x, 1), round(z, 1), yaw, sc, tag))
            n += 1
    return n


def svg(trees):
    X0, Z0, X1, Z1 = -3400, -900, 1450, 3900
    k = 0.2
    col = {"Giant_A": "#1d4a22", "Oak_A": "#3d7a3a", "Oak_B": "#4f8a45", "Pine_A": "#25503a", "Pine_B": "#2f6046",
           "Birch_A": "#9cbf6a", "Bush_A": "#6a9a52", "Bush_B": "#7aa85e", "Log_A": "#6b4a2e"}
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{(X1 - X0) * k:.0f}" height="{(Z1 - Z0) * k:.0f}" viewBox="{X0} {Z0} {X1 - X0} {Z1 - Z0}" font-family="Malgun Gothic">',
         f'<rect x="{X0}" y="{Z0}" width="{X1 - X0}" height="{Z1 - Z0}" fill="#1f6f9a"/>',
         '<polygon points="' + " ".join(f"{x},{z}" for x, z in FOREST) + '" fill="#a8c47a"/>']
    for a, b, c, d in PLAINS_LAND:
        o.append(f'<rect x="{a}" y="{c}" width="{b - a}" height="{d - c}" fill="#c9d98a"/>')
    o.append('<polygon points="' + " ".join(f"{x},{z}" for x, z in HIGHWOOD) + '" fill="#5aa0e6" fill-opacity="0.5"/>')
    for name, a, c, b, d, cc in ZONES:
        o.append(f'<rect x="{a}" y="{c}" width="{b - a}" height="{d - c}" fill="{cc}" fill-opacity="0.6"/>')
    for name, a, b, c, d in CLEARINGS:
        o.append(f'<rect x="{a}" y="{c}" width="{b - a}" height="{d - c}" fill="#e8e0a0" fill-opacity="0.6"/>')
    for name, pts, w in ROADS:
        o.append('<polyline points="' + " ".join(f"{x},{z}" for x, z in pts) + f'" fill="none" stroke="#b08850" stroke-width="{w * 1.5}"/>')
    for kind, x, z, yaw, sc, tag in trees:
        o.append(f'<circle cx="{x}" cy="{z}" r="{RADIUS[kind] * sc * 0.8:.1f}" fill="{col[kind]}"/>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    rng = random.Random(SEED)
    cliffs = cliffs_left(os.path.join(os.environ.get("RECV", ""), "plainsedge.txt"))
    trees, used, report = [], set(), []
    bad = []
    # 덩어리끼리 겹침 검사(경계 맞닿음은 괜찮다)
    for i, g in enumerate(GROVES):
        for h in GROVES[i + 1:]:
            if g[1] < h[2] and g[2] > h[1] and g[3] < h[4] and g[4] > h[3]:
                bad.append(f"덩어리 겹침: {g[0]} / {h[0]}")
    # 띠 먼저(빽빽)
    bx0, bx1, bz0, bz1 = BELT
    report.append(("띠", plant(rng, bx0, bx1, bz0, bz1, "belt", BELT_SPACING, cliffs, trees, used, "띠")))
    for name, x0, x1, z0, z1, mix, sp in GROVES:
        report.append((name, plant(rng, x0, x1, z0, z1, mix, sp, cliffs, trees, used, name)))
    for name, n in report:
        if n == 0:
            bad.append(f"{name}: 한 그루도 못 심음")
    counts = {}
    for t in trees:
        counts[t[0]] = counts.get(t[0], 0) + 1
    for p in bad:
        print("문제:", p)
    lines = ["-- forest_trees.py 가 만든 자료(손으로 고치지 말 것)", "local TREES = {"]
    lines += [f'\t{{ "{k}", {x}, {z}, {y}, {s} }},' for k, x, z, y, s, _ in trees]
    lines.append("}")
    open(os.path.join(HERE, "Forest_Trees_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    open(os.path.join(HERE, "forest_trees.svg"), "w", encoding="utf-8").write(svg(trees))
    print("덩어리별:", ", ".join(f"{n} {c}" for n, c in report))
    print("틀별:", counts)
    print(f"나무 {len(trees)}그루(파트 약 {sum(3 if not k.startswith('Bush') else 2 for k, *_ in trees)}), 문제 {len(bad)}건")
