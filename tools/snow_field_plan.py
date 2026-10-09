# -*- coding: utf-8 -*-
"""
snow_field_plan.py — 2026-10-09. 설원 지상 마무리(손 표) → tools/Snow_Field_data.luau
  - 보스룸(보스룸 단 가운데): 팔각 돌 바닥 + 얼음 안쪽, 둘레 바위 기둥 8(높이 손), 부서진 기계(키트 톱니·보일러), 서쪽 입구 기둥, 보스 표지
  - 순례자의 휴식처 2/8(북동 들): 돌 단, 모닥불, 차양 쉼터, 통나무 의자, 퀘스트 물건 받침(속성 QuestItem)
  - 동굴 입구 1·2: 구멍 둘레 바위 무더기(앞은 트임) / 3번 입구: 돌 틀 + 잠긴 쇠창살(속성 QuestLocked)
  - 눈 나무 숲: 손 덩어리 안에 간격대로(숲 키트 나무를 눈 색으로) · 큰 바위 몇 개
좌표 = 똑바로 한 지상 그림 좌표(snow3_plan, 1px = 3.7 스터드). 바닥 높이는 그 자리 구역 높이(snow3_ground).
돌리기: python tools/snow_field_plan.py (문제 0건) → 짓기: tools/Snow_Field.luau
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import SCALE, world  # noqa: E402
import snow3_ground as SG  # noqa: E402

G, NX, NY = SG.grid()
_, _, _, _, ROCKS, _ = SG.main()  # 단 사이 바위 무리 상자(나무를 피하려고)


def top_at(X, Y):
    return SG.zone_at(X, Y, G)


BOXES = []    # (묶음, cx, cy, cz, sx, sy, sz, ry)
KITS = []     # (틀, x, y, z, yaw, 배율)
MARKS = []    # (이름, x, y, z, 속성)
TREES = []    # (틀, x, y, z, yaw, 배율)
bad = []


def box(group, X, Y, base, sx, sy, sz, ry=0.0, dy=0.0):
    x, z = world(X, Y)
    BOXES.append((group, x, base + dy + sy / 2, z, sx, sy, sz, ry))


# ── 보스룸 ── 가운데(그림) · 반지름(스터드)
BC = (510, 1205)
BR = 130
by = top_at(*BC) - 0.2
bx, bz = world(*BC)
side = 2 * BR * math.cos(math.radians(22.5))
BOXES.append(("ArenaStone", bx, by + 0.4, bz, side, 1.0, side, 0.0))
BOXES.append(("ArenaStone", bx, by + 0.42, bz, side, 1.0, side, 45.0))
BOXES.append(("ArenaIce", bx, by + 0.5, bz, BR * 1.1, 1.0, BR * 1.1, 22.5))
# 둘레 바위 기둥 8 — (각도, 바닥 폭, 켜 높이들) 손으로
PILLARS = [(10, 26, [30, 18, 9]), (55, 22, [42, 14]), (100, 30, [24, 20, 12]), (145, 24, [50, 10]),
           (190, 0, []), (235, 28, [36, 16, 8]), (280, 22, [28, 22]), (325, 26, [46, 12, 6])]  # 190° = 서쪽 입구(비움)
for ang, w, layers in PILLARS:
    a = math.radians(ang)
    px, pz = bx + math.cos(a) * (BR + 18), bz + math.sin(a) * (BR + 18)
    base, ww = by, w
    for k, h in enumerate(layers):
        BOXES.append(("PillarRock" if k % 2 == 0 else "PillarRock2", px + (k % 2) * 1.5, base + h / 2, pz - (k % 2) * 1.2, ww, h, ww * 0.9, ang + k * 7))
        BOXES.append(("SnowCap", px + (k % 2) * 1.5, base + h + 0.5, pz - (k % 2) * 1.2, ww + 0.4, 1.0, ww * 0.9 + 0.4, ang + k * 7))
        base += h
        ww *= 0.72
# 서쪽 입구 기둥 둘 + 윗돌
ga = math.radians(190)
gx, gz = bx + math.cos(ga) * (BR + 18), bz + math.sin(ga) * (BR + 18)
nxg, nzg = -math.sin(ga), math.cos(ga)
for s in (-1, 1):
    BOXES.append(("PillarRock", gx + nxg * s * 22, by + 20, gz + nzg * s * 22, 12, 40, 12, 190.0))
BOXES.append(("PillarRock2", gx, by + 44, gz, 12, 8, 58, 190.0))
BOXES.append(("SnowCap", gx, by + 48.6, gz, 12.6, 1.2, 58.6, 190.0))
# 부서진 기계(키트) — 손 자리(보스룸 가운데 기준 스터드)
for kit, dx, dz, yaw, sc, sink in (("Big_Gear", -60, -70, 30, 2.4, 6), ("Big_Gear", 75, 55, -110, 2.0, 4), ("Boiler_Tank", 70, -60, 15, 1.8, 2),
                                    ("Boiler_Tank", -80, 50, -40, 1.6, 3), ("Gear_24", 20, 95, 80, 2.2, 5)):
    KITS.append((kit, bx + dx, by - sink, bz + dz, yaw, sc))
MARKS.append(("BossArena", bx, by + 1, bz, {"Region": "설원", "Radius": BR}))

# ── 순례자의 휴식처 2/8 ──
RX, RY = 632, 1107
ry_ = top_at(RX, RY) - 0.2
rx, rz = world(RX, RY)
BOXES.append(("RestStone", rx, ry_ + 0.6, rz, 30, 1.2, 26, 8.0))
for k in range(7):  # 모닥불 돌 고리
    a = math.radians(k * 360 / 7)
    BOXES.append(("FireRock", rx + math.cos(a) * 3.2, ry_ + 1.6, rz + math.sin(a) * 3.2, 1.6, 1.2, 1.4, k * 31))
MARKS.append(("Campfire", rx, ry_ + 1.8, rz, {}))
for dx in (-9, 9):  # 차양 쉼터 기둥
    for dz in (6, 12):
        BOXES.append(("Timber", rx + dx, ry_ + 5.2, rz + dz, 0.8, 8.0, 0.8, 0.0))
BOXES.append(("Timber", rx, ry_ + 9.6, rz + 9, 20, 0.6, 9, 0.0))
BOXES.append(("SnowCap", rx, ry_ + 10.1, rz + 9, 20.6, 0.5, 9.6, 0.0))
BOXES.append(("Timber", rx - 6, ry_ + 1.8, rz - 6, 8, 1.6, 1.6, 20.0))  # 통나무 의자
BOXES.append(("Timber", rx + 6, ry_ + 1.8, rz - 5, 7, 1.6, 1.6, -15.0))
BOXES.append(("RestStone", rx + 11, ry_ + 2.4, rz - 2, 3, 3.6, 3, 0.0))  # 퀘스트 물건 받침
MARKS.append(("QuestItem", rx + 11, ry_ + 5.0, rz - 2, {"QuestItem": "전직 퀘템 2/8"}))

# ── 동굴 입구 둘레 바위(구멍 = snow3_ground.HOLES) ── 앞(트임) 방향은 손으로
ENTRY_OPEN = {"동굴 입구 2": "S", "동굴 입구 1": "W", "3번 입구": "E"}
for name, (a, b, c, d) in SG.HOLES.items():
    gy = top_at((a + b) / 2, (c + d) / 2) - 0.2
    (x0, z0), (x1, z1) = world(a, c), world(b, d)
    opening = ENTRY_OPEN[name]
    sides = {"N": ((x0 - 6, x1 + 6), (z0 - 10, z0)), "S": ((x0 - 6, x1 + 6), (z1, z1 + 10)),
             "W": ((x0 - 10, x0), (z0 - 6, z1 + 6)), "E": ((x1, x1 + 10), (z0 - 6, z1 + 6))}
    hs = [14, 9, 18, 11]
    for k, (sd, ((ax, bx_), (az, bz_))) in enumerate(sides.items()):
        if sd == opening:
            continue
        h = hs[k]
        BOXES.append(("PillarRock", (ax + bx_) / 2, gy + h / 2, (az + bz_) / 2, bx_ - ax, h, bz_ - az, 0.0))
        BOXES.append(("SnowCap", (ax + bx_) / 2, gy + h + 0.5, (az + bz_) / 2, bx_ - ax + 0.4, 1.0, bz_ - az + 0.4, 0.0))
    if name == "3번 입구":
        BOXES.append(("Grate", (x0 + x1) / 2, gy + 0.4, (z0 + z1) / 2, x1 - x0 + 2, 0.8, z1 - z0 + 2, 0.0))
        MARKS.append(("QuestLock", (x0 + x1) / 2, gy + 1, (z0 + z1) / 2, {"QuestLocked": True, "Entrance": "3번 입구"}))

# ── 눈 나무 덩어리(손) { X0, X1, Y0, Y1, 간격 px } ── 바위 무리·마을·보스룸·구멍·바닷가를 피해서
GROVES = [
    (165, 330, 1252, 1455, 13),   # 남서 필드
    (460, 548, 948, 1058, 12),    # 북쪽 들 가운데
    (622, 722, 1180, 1290, 12),   # 북동 들 서쪽
    (760, 848, 1120, 1290, 12),   # 북동 들 동쪽
    (612, 700, 990, 1050, 12),    # 북동 들 북서
    (690, 800, 1350, 1405, 12),   # 북동 들 남쪽
    (410, 600, 1352, 1468, 14),   # 남쪽 필드
]
TREE_MIX = {"Pine_A": 5, "Pine_B": 4, "Birch_A": 2, "Oak_B": 2, "Bush_B": 1}
AVOID = [  # 그림 좌표 네모(나무 금지): 폐허·휴식처·구멍 둘레
    (745, 790, 1045, 1085), (612, 652, 1088, 1128), (270, 310, 1390, 1430), (680, 720, 1300, 1340), (820, 860, 1300, 1340),
]


def in_rocks(x, z, r):
    for _, (a, b, c, d), lo, tp, _c in ROCKS:
        if a - r < x < b + r and c - r < z < d + r:
            return True
    return False


rng = random.Random(20261009)
tot = sum(TREE_MIX.values())
for X0, X1, Y0, Y1, sp in GROVES:
    n = 0
    nx_, ny_ = int((X1 - X0) // sp), int((Y1 - Y0) // sp)
    for i in range(nx_):
        for j in range(ny_):
            X = X0 + (i + 0.5) * sp + (rng.random() - 0.5) * sp * 0.6
            Y = Y0 + (j + 0.5) * sp + (rng.random() - 0.5) * sp * 0.6
            r = rng.random() * tot
            kind = None
            for k, w in TREE_MIX.items():
                r -= w
                if r <= 0:
                    kind = k
                    break
            kind = kind or "Pine_A"
            yaw = rng.randrange(0, 360, 15)
            sc = round(1.1 + rng.random() * 0.6, 2)
            t = top_at(X, Y)
            if t is None or any(a <= X <= b and c <= Y <= d for a, b, c, d in AVOID):
                continue
            # 이웃 칸이 바다·다른 높이면(가장자리) 빼기
            if any(top_at(X + dx, Y + dy) != t for dx, dy in ((8, 0), (-8, 0), (0, 8), (0, -8))):
                continue
            x, z = world(X, Y)
            if in_rocks(x, z, 8):
                continue
            TREES.append((kind, x, t - 0.3, z, yaw, sc))
            n += 1
    if n == 0:
        bad.append(f"나무 덩어리 {X0},{Y0} 에 한 그루도 없음")
# 큰 바위(손) { X, Y, 폭, 높이, 깊이, 돌림 }
BOULDERS = [(200, 1300, 22, 14, 18, 15), (318, 1440, 30, 18, 24, -20), (520, 1420, 26, 12, 20, 40), (585, 1380, 18, 10, 16, 5),
            (500, 1000, 24, 16, 20, 30), (660, 1240, 20, 12, 18, -35), (820, 1180, 28, 20, 22, 10), (740, 1380, 22, 14, 18, 60)]
for X, Y, w, h, d, ry in BOULDERS:
    t = top_at(X, Y)
    x, z = world(X, Y)
    if t is None or in_rocks(x, z, 2):
        bad.append(f"큰 바위 ({X},{Y}) 자리 문제(땅 {t}, 바위 무리 겹침)")
        continue
    BOXES.append(("PillarRock", x, t - 2 + h / 2, z, w, h, d, ry))
    BOXES.append(("SnowCap", x, t - 2 + h + 0.5, z, w + 0.4, 1.0, d + 0.4, ry))


if __name__ == "__main__":
    for p in bad:
        print("문제:", p)
    out = ["-- snow_field_plan.py 가 만든 자료(손으로 고치지 말 것)", "local BOXES = {"]
    out += [f'\t{{ "{g}", {x:.1f}, {y:.2f}, {z:.1f}, {sx:.1f}, {sy:.1f}, {sz:.1f}, {ry:.1f} }},' for g, x, y, z, sx, sy, sz, ry in BOXES]
    out += ["}", "local KITS = {"]
    out += [f'\t{{ "{k}", {x:.1f}, {y:.1f}, {z:.1f}, {yaw}, {sc} }},' for k, x, y, z, yaw, sc in KITS]
    out += ["}", "local MARKS = {"]
    for n, x, y, z, attrs in MARKS:
        a = ", ".join(f'{k} = {str(v).lower() if isinstance(v, bool) else (repr(v) if not isinstance(v, str) else chr(34) + v + chr(34))}' for k, v in attrs.items())
        out.append(f'\t{{ "{n}", {x:.1f}, {y:.1f}, {z:.1f}, {{ {a} }} }},')
    out += ["}", "local TREES = {"]
    out += [f'\t{{ "{k}", {x:.1f}, {y:.1f}, {z:.1f}, {yaw}, {sc} }},' for k, x, y, z, yaw, sc in TREES]
    out += ["}"]
    open(os.path.join(HERE, "Snow_Field_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"상자 {len(BOXES)} · 키트 {len(KITS)} · 표지 {len(MARKS)} · 나무 {len(TREES)} · 문제 {len(bad)}건")
