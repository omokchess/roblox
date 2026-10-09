# -*- coding: utf-8 -*-
"""
forest_trees.py — 2026-10-09 (3판). 숲 나무 → tools/Forest_Trees_data.luau

1판: 블렌더 키트 나무 18738그루 → "너무 빽빽". 2판: 거목 36 → 초원 같았다.
3판(사용자: "옛날에 쓰던 나무 레퍼런스로 거목들 엄청 만들어서 숲처럼 보이게"): 옛 숲 나무 18그루를 틀로 뽑은 것
(ServerStorage.ForestOldKit.Old_*, tools/Forest_OldKit.luau — 높이 47~101, 잎 폭 40~120)을 덩어리마다 간격 55~70 으로.
  - 덩어리(GROVES)·빈터(CLEARINGS)·간격·틀 섞임은 손으로. 덩어리 안만 칸마다 한 그루(칸 안 비킴·돌림·배율은 씨앗값).
  - 빼는 곳: 평원(+20) · 하이우드 · 맥동·솔르헨(+15) · 길(줄기 반경 + 12) · 숲 가장자리 20 안.
  - 거목 밑 절반쯤에 키트 덤불 하나.
짓기: tools/Forest_Trees.luau 머리 주석(자료 끼워 job.sh). 틀은 ForestKit·ForestOldKit 둘 다 찾는다.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forest_plan import FOREST, HIGHWOOD, PLAINS, ROADS, ZONES, inside  # noqa: E402

OLD = {  # 틀 → (무게, 줄기 반경)
    "Old_P422": (3, 4), "Old_P171": (3, 4), "Old_P331": (3, 4), "Old_P249": (3, 4), "Old_P283": (3, 4), "Old_P525": (3, 4),
    "Old_P228": (3, 4), "Old_P453": (3, 4), "Old_P251": (3, 4), "Old_P440": (3, 4), "Old_P2": (3, 4),
    "Old_W56": (2, 4), "Old_W166": (2, 4), "Old_W213": (2, 4),
    "Old_S40": (2, 3), "Old_S30": (2, 3), "Old_X13": (2, 3), "Old_X16": (2, 3),
}
# 덩어리 { 이름, x0, x1, z0, z1, 간격 } — 2판 숲 윤곽 안을 손으로 나눔
GROVES = [
    ("북서 숲", -1700, -860, -170, 470, 60),
    ("맥동 서쪽 띠", -860, -240, -30, 470, 62),
    ("북쪽 숲", -240, 400, -170, 90, 58),
    ("북동 숲", 400, 1000, -40, 90, 58),
    ("동쪽 띠", 900, 1000, 90, 1080, 55),
    ("하이우드·평원 사이", -900, -220, 470, 1080, 60),
    ("남서 숲", -900, 100, 1080, 2080, 60),
    ("남동 숲", 100, 1000, 1080, 2080, 58),
    ("솔르헨 동쪽 숲", 80, 1000, 2080, 2350, 58),
]
CLEARINGS = [
    ("맥동 앞 빈터", -800, -300, -20, 200),
    ("서 빈터", -1500, -1150, 50, 330),
    ("남서 빈터", -820, -460, 1150, 1450),
    ("남 빈터", -200, 150, 1250, 1550),
    ("남동 빈터", 450, 800, 1800, 2150),
]
EDGE = 20
SEED = 20261009


def seg_d(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def free(x, z, r):
    if not inside((x, z), FOREST) or any(seg_d(x, z, *FOREST[i], *FOREST[(i + 1) % len(FOREST)]) < EDGE for i in range(len(FOREST))):
        return False
    if PLAINS[0] - 20 < x < PLAINS[2] + 20 and PLAINS[1] - 20 < z < PLAINS[3] + 20:
        return False
    if inside((x, z), HIGHWOOD):
        return False
    for _, x0, z0, x1, z1, _ in ZONES:
        if x0 - 15 < x < x1 + 15 and z0 - 15 < z < z1 + 15:
            return False
    for _, x0, x1, z0, z1 in CLEARINGS:
        if x0 < x < x1 and z0 < z < z1:
            return False
    for _, pts in ROADS:
        for k in range(len(pts) - 1):
            if seg_d(x, z, *pts[k], *pts[k + 1]) < 12 + r:
                return False
    return True


def pick(rng):
    tot = sum(w for w, _ in OLD.values())
    r = rng.random() * tot
    for k, (w, _) in OLD.items():
        r -= w
        if r <= 0:
            return k
    return k


if __name__ == "__main__":
    rng = random.Random(SEED)
    bad, trees, report = [], [], []
    for i, g in enumerate(GROVES):
        for h in GROVES[i + 1:]:
            if g[1] < h[2] and g[2] > h[1] and g[3] < h[4] and g[4] > h[3]:
                bad.append(f"덩어리 겹침: {g[0]} / {h[0]}")
    for name, x0, x1, z0, z1, sp in GROVES:
        nx, nz = max(1, int((x1 - x0) // sp)), max(1, int((z1 - z0) // sp))
        cw, ch = (x1 - x0) / nx, (z1 - z0) / nz
        n = 0
        for i in range(nx):
            for j in range(nz):
                kind = pick(rng)
                x = x0 + (i + 0.5) * cw + (rng.random() - 0.5) * cw * 0.6
                z = z0 + (j + 0.5) * ch + (rng.random() - 0.5) * ch * 0.6
                yaw = rng.randrange(0, 360, 15)
                sc = round(0.9 + rng.random() * 0.35, 2)
                bush = rng.random() < 0.5
                if not free(x, z, OLD[kind][1]):
                    continue
                trees.append((kind, round(x, 1), round(z, 1), yaw, sc))
                n += 1
                if bush:
                    a = math.radians(yaw + 40)
                    bx, bz = x + math.cos(a) * 11, z + math.sin(a) * 11
                    if free(bx, bz, 5):
                        trees.append(("Bush_A" if rng.random() < 0.6 else "Bush_B", round(bx, 1), round(bz, 1), (yaw * 3) % 360, 1.2))
        report.append((name, n))
        if n == 0:
            bad.append(f"{name}: 한 그루도 못 심음")
    for p in bad:
        print("문제:", p)
    lines = ["-- forest_trees.py 가 만든 자료(손으로 고치지 말 것)", "local TREES = {"]
    lines += [f'\t{{ "{k}", {x}, {z}, {y}, {s} }},' for k, x, z, y, s in trees]
    lines.append("}")
    open(os.path.join(HERE, "Forest_Trees_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    big = sum(1 for t in trees if t[0].startswith("Old_"))
    print("덩어리별:", ", ".join(f"{n} {c}" for n, c in report))
    print(f"거목 {big} + 덤불 {len(trees) - big} (파트 약 {big * 55 + (len(trees) - big) * 2}), 문제 {len(bad)}건")
