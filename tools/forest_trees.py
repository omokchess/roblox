# -*- coding: utf-8 -*-
"""
forest_trees.py — 2026-10-09 (2판). 숲 나무 → tools/Forest_Trees_data.luau

1판(덩어리 안을 간격대로 채운 18738그루)은 사용자가 "나무 너무 빽빽" → 2판은 **큰 나무 몇 그루**:
  forest_plan.BIG_TREES(손 배치 · 검사는 forest_plan.check) 자리마다 거목(Giant_A)을 그 배율로,
  둘레에 덤불 셋(BUSHES — 줄기에서 잎 반경 비율·방향 손 표, 나무 돌림만큼 같이 돈다). 덤불은 길·구역·평원·숲 밖이면 뺀다.
짓기: tools/Forest_Trees.luau 머리 주석(자료 끼워 job.sh).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forest_plan import BIG_TREES, FOREST, HIGHWOOD, PLAINS, ROADS, ZONES, check, inside  # noqa: E402

CANOPY = 19  # 거목 잎 반경(배율 1)
# 덤불 { 잎 반경 비율, 방향(도), 틀, 배율 }
BUSHES = [(0.85, 25, "Bush_A", 1.3), (1.05, 150, "Bush_B", 1.2), (0.75, 255, "Bush_A", 1.0)]


def seg_d(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def free(x, z, r):
    if not inside((x, z), FOREST) or any(seg_d(x, z, *FOREST[i], *FOREST[(i + 1) % len(FOREST)]) < r + 6 for i in range(len(FOREST))):
        return False
    if PLAINS[0] - r < x < PLAINS[2] + r and PLAINS[1] - r < z < PLAINS[3] + r:
        return False
    if inside((x, z), HIGHWOOD):
        return False
    for _, x0, z0, x1, z1, _ in ZONES:
        if x0 - r < x < x1 + r and z0 - r < z < z1 + r:
            return False
    for _, pts in ROADS:
        for k in range(len(pts) - 1):
            if seg_d(x, z, *pts[k], *pts[k + 1]) < 12 + r:
                return False
    return True


if __name__ == "__main__":
    bad = check()
    trees = []
    for i, (x, z, sc) in enumerate(BIG_TREES):
        yaw = (i * 47) % 360
        trees.append(("Giant_A", x, z, yaw, sc))
        for ratio, ang, kind, bsc in BUSHES:
            a = math.radians(ang + yaw)
            bx, bz = x + math.cos(a) * CANOPY * sc * ratio, z + math.sin(a) * CANOPY * sc * ratio
            if free(bx, bz, 6):
                trees.append((kind, round(bx, 1), round(bz, 1), (yaw + ang) % 360, bsc))
    for p in bad:
        print("문제:", p)
    lines = ["-- forest_trees.py 가 만든 자료(손으로 고치지 말 것)", "local TREES = {"]
    lines += [f'\t{{ "{k}", {x}, {z}, {y}, {s} }},' for k, x, z, y, s in trees]
    lines.append("}")
    open(os.path.join(HERE, "Forest_Trees_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print(f"거목 {len(BIG_TREES)} + 덤불 {len(trees) - len(BIG_TREES)}, 문제 {len(bad)}건")
