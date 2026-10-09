# -*- coding: utf-8 -*-
"""
highwood_build.py — 2026-10-09. 하이우드 1단계(거대수·판·다리·나선 비탈) 상자 계산 → tools/Highwood_data.luau

배치는 highwood_plan.py(GIANTS·DECKS·BRIDGES, 사용자 승인). 여기서는 모양을 상자로 푼다:
  거대수  줄기 = 굵기 w 곧은 기둥(땅 아래 10 ~ 잎 시작 + 60) + 면마다 껍질 골(손 비율 표 RIDGES).
          뿌리·가지·잎 = 숲 키트 Giant_A 손 표(models/forest/build_kit_forest.py)를 키운 것:
            가로 배율 k = w / 7(키트 줄기 굵기), 뿌리는 k × 0.6(나선 비탈과 안 부딪히게), 잎은 높이를 잎 띠(잎 시작~꼭대기)에 맞춰 늘린다.
  판      줄기 둘레 네모 고리(두께 3) + 바깥 난간(기둥 24 간격·윗난간), 다리·비탈 이음 자리는 난간을 튼다. 밑에 버팀 보.
  다리    두 나무 판 바깥 모서리 사이 널판(폭 12) + 밧줄 난간 둘 + 양 끝 기둥.
  나선 비탈  나무마다 하나, 땅 → 맨 위 판. 반경 R = 가장 넓은 판 바깥 + 16, 기울기 0.3, 네모 둘레를 시계 방향으로 돈다.
          판 높이를 지날 때 판 모서리까지 이음 널판. 모서리 꺾임마다 쉼판, 바깥 난간, 줄기로 버팀 보(60 간격).
검사: 비탈·다리 기울기, 길(비탈·다리·이음)이 줄기·뿌리·가지·다른 판과 부딪힘, 다리와 나선이 같은 자리 같은 높이(±14).
돌리기: python tools/highwood_build.py (문제 0건) → 짓기: tools/Highwood_Build.luau 머리 주석.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from highwood_plan import BRIDGES, DECKS, GIANTS, GROUND  # noqa: E402

SLOPE = 0.3
WALK = 12  # 걷는 폭
POST_GAP = 24

# 숲 키트 Giant_A(손 표) — (묶음, 가운데, 크기, 회전)
GIANT_A = [
    ("Root", (6, 2.2, 0), (6, 4.4, 1.6), (0, 0, -18)),
    ("Root", (-6, 2.2, 0.5), (6, 4.4, 1.6), (0, 0, 18)),
    ("Root", (0.5, 2.2, 6), (1.6, 4.4, 6), (18, 0, 0)),
    ("Root", (-0.5, 2.2, -6), (1.6, 4.4, 6), (-18, 0, 0)),
    ("Branch", (6, 38, -2), (2.2, 12, 2.2), (10, 0, -42)),
    ("Branch", (-6, 40, 3), (2, 11, 2), (-12, 0, 44)),
    ("Branch", (1, 41, 6), (1.8, 10, 1.8), (40, 0, 4)),
    ("LeafB", (0, 44, 0), (28, 9, 26), (0, 12, 0)),
    ("LeafA", (8, 47, -5), (17, 8, 16), (0, 30, 0)),
    ("LeafB", (-9, 46.5, 6), (16, 8, 15), (0, -20, 0)),
    ("LeafA", (1, 51.5, 2), (18, 7, 17), (0, 40, 0)),
    ("LeafA", (-2, 56, -1), (11, 5, 10), (0, 5, 0)),
    ("LeafB", (4, 40.5, 10), (12, 5, 10), (0, 15, 0)),
    ("LeafB", (-6, 40, -9), (12, 5, 11), (0, -30, 0)),
]
LEAF_Y0, LEAF_Y1 = 37.5, 58.5  # 키트 잎 띠
# 줄기 껍질 골: 면마다 { 면 위 위치(-0.5~0.5 × w), 굵기 비, 튀어나옴 비, 아래 높이 비, 위 높이 비 } (높이 비 = 줄기 높이에 대해)
RIDGES = [(-0.3, 0.16, 0.06, 0.0, 0.62), (0.05, 0.12, 0.05, 0.18, 0.95), (0.33, 0.18, 0.07, 0.05, 0.78)]
FLARE, FLARE_H, UPPER = 1.3, 110, 0.8  # 밑 퍼짐 배율·높이, 윗줄기 배율
# 곁가지 그루터기 { 줄기 높이 비, 방향(도), 길이 비(× 굵기), 굵기 비, 들림(도) } — 나무마다 손으로(판·다리 방향은 피해서)
STUBS = {
    "어머니 나무": [(0.83, 20, 0.9, 0.16, 28), (0.88, 200, 1.0, 0.18, 32), (0.93, 110, 0.7, 0.14, 25)],
    "북서 나무": [(0.80, 300, 0.9, 0.18, 30), (0.88, 130, 0.8, 0.16, 26)],
    "북동 나무": [(0.82, 60, 0.9, 0.18, 30), (0.9, 250, 0.7, 0.16, 25)],
    "남서 나무": [(0.80, 250, 1.0, 0.17, 30), (0.9, 330, 0.8, 0.15, 28)],
    "남동 나무": [(0.83, 120, 0.9, 0.18, 30), (0.9, 230, 0.7, 0.15, 26)],
}
# 나무마다 키트 표를 얼마나 돌릴까(같은 나무가 줄지어 보이지 않게) — 손으로
YAW = {"어머니 나무": 0, "북서 나무": 70, "북동 나무": 155, "남서 나무": 20, "남동 나무": 300}

boxes = []  # (이름, 묶음, cx, cy, cz, sx, sy, sz, rx, ry, rz)
walk = []   # 걷는 길 표본점 (x, y, z, 무엇)
solids = []  # 부딪힘 검사용 (이름, cx, cy, cz, sx, sy, sz, ry) — 축 정렬 + y 돌림만(검사용 근사)


def add(name, group, c, s, r=(0, 0, 0), solid=True):
    boxes.append((name, group, *c, *s, *r))
    if solid and group not in ("LeafA", "LeafB", "Rail", "Rope"):
        solids.append((name, *c, *s, r[1], r))


def rot_y(x, z, deg):
    a = math.radians(deg)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def orient(r):
    """로블록스 CFrame.fromOrientation(rx, ry, rz) = Ry · Rx · Rz 의 3×3"""
    ax, ay, az = (math.radians(v) for v in r)
    cx, sx, cy, sy, cz, sz = math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay), math.cos(az), math.sin(az)
    Ry = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    Rx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    Rz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
    mul = lambda A, B: tuple(tuple(sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)) for i in range(3))  # noqa: E731
    return mul(mul(Ry, Rx), Rz)


def to_local(dx, dy, dz, r):
    M = orient(r)  # 열 = 로컬 축 → 로컬 = Mᵀ · d
    return (M[0][0] * dx + M[1][0] * dy + M[2][0] * dz, M[0][1] * dx + M[1][1] * dy + M[2][1] * dz, M[0][2] * dx + M[1][2] * dy + M[2][2] * dz)


def giant(g):
    name, gx, gz, w, leaf, top = g
    k = w / 7
    kv = (top - leaf) / (LEAF_Y1 - LEAF_Y0)
    yaw = YAW[name]
    trunk_top = leaf + 60
    up = upper_from(g)
    add(f"{name}_줄기", "Bark", (gx, (up - 10) / 2, gz), (w, up + 10, w))
    add(f"{name}_윗줄기", "Bark", (gx, (up + trunk_top) / 2, gz), (w * UPPER, trunk_top - up, w * UPPER))
    # 밑 퍼짐: 두 켜(땅 ~ FLARE_H)
    add(f"{name}_밑퍼짐", "Bark2", (gx, FLARE_H * 0.5 / 2, gz), (w * FLARE, FLARE_H * 0.5, w * FLARE))
    add(f"{name}_밑퍼짐2", "Bark", (gx, FLARE_H * 0.5 + FLARE_H * 0.5 / 2, gz), (w * (1 + FLARE) / 2, FLARE_H * 0.5, w * (1 + FLARE) / 2))
    # 곁가지 그루터기(손 표: 줄기 높이 비, 방향, 길이 비, 굵기 비, 들림 각)
    for i, (hr, ang, lr, tr, lift) in enumerate(STUBS[name]):
        hy = up * hr
        L = w * lr
        a = math.radians(ang)
        dx, dz = math.sin(a), math.cos(a)
        reach = w / 2 + L * 0.42
        add(f"{name}_곁가지{i}", "Bark", (gx + dx * reach, hy + L * 0.25, gz + dz * reach), (w * tr, w * tr, L), (-lift, ang, 0))
    # 껍질 골(네 면)
    for f, (nx, nz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        for i, (u, th, out, h0, h1) in enumerate(RIDGES):
            uu = u if f % 2 == 0 else -u
            y0, y1 = trunk_top * h0, trunk_top * h1
            if f % 2 == 0:  # ±x 면
                c = (gx + nx * (w / 2 + w * out / 2 - 1), (y0 + y1) / 2, gz + uu * w)
                s = (w * out + 2, y1 - y0, w * th)
            else:
                c = (gx + uu * w, (y0 + y1) / 2, gz + nz * (w / 2 + w * out / 2 - 1))
                s = (w * th, y1 - y0, w * out + 2)
            add(f"{name}_골{f}{i}", "Bark2", c, s)
    for group, (x, y, z), (sx, sy, sz), (rx, ry, rz) in GIANT_A:
        x, z = rot_y(x, z, yaw)
        if group == "Root":
            kr = k * 0.6
            add(f"{name}_뿌리", "Bark", (gx + x * kr, y * kr - 2, gz + z * kr), (sx * kr, sy * kr, sz * kr), (rx, ry + yaw, rz))
        elif group == "Branch":
            add(f"{name}_가지", "Bark", (gx + x * k, leaf + (y - 39.5) * k * 0.6, gz + z * k), (sx * k, sy * k, sz * k), (rx, ry + yaw, rz))
        else:
            add(f"{name}_잎", group, (gx + x * k * 0.9, leaf + (y - LEAF_Y0) * kv, gz + z * k * 0.9), (sx * k * 0.9, sy * kv, sz * k * 0.9), (rx, ry + yaw, rz))


def upper_from(g):
    return g[4] - 280  # 잎 시작 280 아래부터 윗줄기(좁음)


def trunk_half(g, h):
    if h < FLARE_H * 0.5:
        return g[3] * FLARE / 2
    if h < FLARE_H:
        return g[3] * (1 + FLARE) / 4
    if h >= upper_from(g):
        return g[3] * UPPER / 2
    return g[3] / 2


def deck_outer(d):
    g = next(x for x in GIANTS if x[0] == d[0])
    return trunk_half(g, d[1]) + d[2]


def square_hit(cx, cz, half, dx, dz):
    """중심에서 (dx,dz) 방향 반직선이 반폭 half 정사각과 만나는 점"""
    t = half / max(abs(dx), abs(dz))
    return cx + dx * t, cz + dz * t


gaps = {}  # (나무, 높이) → [(x, z)] 난간 트는 자리


def deck_build(d):
    t, h, ring, dname, houses = d
    g = next(x for x in GIANTS if x[0] == t)
    gx, gz = g[1], g[2]
    inner = trunk_half(g, h)
    outer = inner + ring
    th = 3
    # 네 쪽(북·남 판은 모서리까지, 동·서 판은 그 사이)
    add(f"{dname}_판N", "Plank", (gx, h - th / 2, gz - (inner + outer) / 2), (outer * 2, th, ring))
    add(f"{dname}_판S", "Plank", (gx, h - th / 2, gz + (inner + outer) / 2), (outer * 2, th, ring))
    add(f"{dname}_판W", "Plank", (gx - (inner + outer) / 2, h - th / 2, gz), (ring, th, inner * 2))
    add(f"{dname}_판E", "Plank", (gx + (inner + outer) / 2, h - th / 2, gz), (ring, th, inner * 2))
    # 테두리 보(판 바깥 모서리 아래)
    for (cx, cz, sx, sz) in ((gx, gz - outer + 1, outer * 2, 2), (gx, gz + outer - 1, outer * 2, 2), (gx - outer + 1, gz, 2, outer * 2), (gx + outer - 1, gz, 2, outer * 2)):
        add(f"{dname}_테두리", "PlankDark", (cx, h - th - 1.5, cz), (sx + 0.4, 3, sz + 0.4))
    # 버팀 보: 판 밑에서 줄기로 비스듬히(쪽마다 셋 — 1/4·1/2·3/4 자리)
    for (nx, nz) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for u in (-0.5, 0, 0.5):
            px = gx + nx * (inner + ring * 0.75) + (0 if nx else u * inner)
            pz = gz + nz * (inner + ring * 0.75) + (0 if nz else u * inner)
            qx, qz = gx + nx * inner + (0 if nx else u * inner), gz + nz * inner + (0 if nz else u * inner)
            qy = h - th - ring * 0.75
            L = math.hypot(px - qx, pz - qz, (h - th) - qy)
            mx, my, mz = (px + qx) / 2, (h - th + qy) / 2, (pz + qz) / 2
            pitch = math.degrees(math.atan2((h - th) - qy, math.hypot(px - qx, pz - qz)))
            yaw = 0 if nz else 90
            # 보는 로컬 z 로 길게: y 돌림 후 x 축으로 숙임
            add(f"{dname}_버팀", "PlankDark", (mx, my, mz), (4, 4, L), (pitch * (-1 if (nz > 0 or nx > 0) else 1), yaw, 0), solid=False)
    return gx, gz, outer


def rails(dname, gx, gz, outer, h, gap_pts):
    """판 바깥 난간: 기둥 24 간격 + 윗난간, gap_pts 근처(±9)는 비운다"""
    sides = [((gx - outer, gz - outer), (gx + outer, gz - outer)), ((gx + outer, gz - outer), (gx + outer, gz + outer)),
             ((gx + outer, gz + outer), (gx - outer, gz + outer)), ((gx - outer, gz + outer), (gx - outer, gz - outer))]
    for (ax, az), (bx, bz) in sides:
        L = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / L, (bz - az) / L
        cuts = sorted(((px - ax) * ux + (pz - az) * uz) for px, pz in gap_pts
                      if abs((px - ax) * -uz + (pz - az) * ux) < 3 and -1 < (px - ax) * ux + (pz - az) * uz < L + 1)
        spans, s0 = [], 0.0
        for c in cuts:
            if c - 9 > s0:
                spans.append((s0, c - 9))
            s0 = c + 9
        if L > s0:
            spans.append((s0, L))
        for a, b in spans:
            n = max(1, int((b - a) // POST_GAP))
            for i in range(n + 1):
                s = a + (b - a) * i / n
                add(f"{dname}_난간기둥", "Rail", (ax + ux * s, h + 2, az + uz * s), (1, 4, 1))
            add(f"{dname}_난간", "Rail", (ax + ux * (a + b) / 2, h + 4, az + uz * (a + b) / 2),
                ((b - a) if abs(ux) > 0.5 else 1.2, 0.8, (b - a) if abs(uz) > 0.5 else 1.2))


def plank_between(name, a, b, width, group="Plank", thick=2):
    """a(x,y,z) → b 널판(윗면이 두 점을 잇는다)"""
    (ax, ay, az), (bx, by, bz) = a, b
    dx, dy, dz = bx - ax, by - ay, bz - az
    flat = math.hypot(dx, dz)
    L = math.hypot(flat, dy)
    yaw = math.degrees(math.atan2(dx, dz))
    pitch = -math.degrees(math.atan2(dy, flat))
    add(name, group, ((ax + bx) / 2, (ay + by) / 2 - thick / 2, (az + bz) / 2), (width, thick, L), (pitch, yaw, 0))
    if group == "Plank":  # 걷는 판만 검사 표본
        n = max(2, int(L // 6))
        for i in range(n + 1):
            t = i / n
            walk.append((ax + dx * t, ay + dy * t, az + dz * t, name))
    return L, yaw, pitch


def main():
    bad = []
    for g in GIANTS:
        giant(g)
    deck_info = {}
    for d in DECKS:
        deck_info[(d[0], d[1])] = deck_build(d)
        gaps[(d[0], d[1])] = []
    # 다리
    bridge_lines = []
    for (ta, ha), (tb, hb) in BRIDGES:
        ax, az, ao = deck_info[(ta, ha)]
        bx, bz, bo = deck_info[(tb, hb)]
        dx, dz = bx - ax, bz - az
        pa = square_hit(ax, az, ao, dx, dz)
        pb = square_hit(bx, bz, bo, -dx, -dz)
        gaps[(ta, ha)].append(pa)
        gaps[(tb, hb)].append(pb)
        L, yaw, pitch = plank_between(f"다리_{ta}{ha}_{tb}{hb}", (pa[0], ha, pa[1]), (pb[0], hb, pb[1]), WALK)
        if abs(hb - ha) / max(L, 1) > 0.25:
            bad.append(f"다리 {ta}{ha}–{tb}{hb} 기울기")
        # 밧줄 난간 둘 + 양 끝 기둥
        nx, nz = -dz / math.hypot(dx, dz), dx / math.hypot(dx, dz)
        for sgn in (-1, 1):
            o = WALK / 2 * sgn
            plank_between(f"다리밧줄", (pa[0] + nx * o, ha + 3.5, pa[1] + nz * o), (pb[0] + nx * o, hb + 3.5, pb[1] + nz * o), 0.6, "Rope", 0.6)
            for (px, py, pz) in ((pa[0], ha, pa[1]), (pb[0], hb, pb[1])):
                add("다리기둥", "PlankDark", (px + nx * o, py + 2.5, pz + nz * o), (1.6, 5, 1.6))
        bridge_lines.append(((pa[0], ha, pa[1]), (pb[0], hb, pb[1])))
    walk[:] = [w for w in walk if w[3] != "다리밧줄"]
    # 나선 비탈
    spiral_pts = []
    for g in GIANTS:
        name, gx, gz, w, leaf, top = g
        decks = sorted([d for d in DECKS if d[0] == name], key=lambda d: d[1])
        R = max(deck_outer(d) for d in decks) + 16
        top_h = decks[-1][1]
        side = 2 * R
        corners = [(gx - R, gz - R), (gx + R, gz - R), (gx + R, gz + R), (gx - R, gz + R)]  # 시계(북서 → 북동 → …)
        # 다리와 나선이 겹치지 않는 시작 모서리·어긋남을 고른다(규칙적 구조 — 자리는 다리가 정한다)
        def pos(p):
            p %= 4 * side
            i = int(p // side)
            f = p - i * side
            (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
            return ax + (bx - ax) * f / side, az + (bz - az) * f / side, i
        best = None
        for start in [side * q / 8 for q in range(32)]:
            ok = True
            for (a, b) in bridge_lines:
                for (px, py, pz) in (a, b):
                    pass
                # 다리 선이 나선 둘레(반경 R 네모)를 지나는 점
                (ax, ay, az), (bx, by, bz) = a, b
                for tt in [i / 200 for i in range(201)]:
                    x, y, z = ax + (bx - ax) * tt, ay + (by - ay) * tt, az + (bz - az) * tt
                    if abs(max(abs(x - gx), abs(z - gz)) - R) < WALK:
                        # 이 자리 둘레 좌표
                        if abs(z - (gz - R)) < WALK:
                            p = (x - (gx - R))
                        elif abs(x - (gx + R)) < WALK:
                            p = side + (z - (gz - R))
                        elif abs(z - (gz + R)) < WALK:
                            p = 2 * side + ((gx + R) - x)
                        else:
                            p = 3 * side + ((gz + R) - z)
                        rel = (p - start) % (4 * side)
                        for lap in range(6):
                            hh = GROUND + SLOPE * (rel + lap * 4 * side)
                            if hh <= top_h + 2 and abs(hh - y) < 16:
                                ok = False
            if ok:
                best = start
                break
        if best is None:
            bad.append(f"{name}: 다리와 안 부딪히는 나선 시작을 못 찾음")
            best = 0
        total = (top_h - GROUND) / SLOPE
        # 면 조각마다 널판
        p = 0.0
        while p < total - 0.01:
            x0, z0, i0 = pos(best + p)
            to_corner = side - ((best + p) % side)
            step = min(to_corner, total - p)
            x1, z1, _ = pos(best + p + step - 1e-6)
            y0, y1 = GROUND + SLOPE * p, GROUND + SLOPE * (p + step)
            plank_between(f"{name}_비탈", (x0, y0, z0), (x1, y1, z1), WALK)
            # 바깥 난간(나무 바깥 쪽 6)
            ox, oz = (x0 + x1) / 2 - gx, (z0 + z1) / 2 - gz
            n = (1 if ox > 0 else -1, 0) if abs(ox) > abs(oz) else (0, 1 if oz > 0 else -1)
            plank_between(f"{name}_비탈난간", (x0 + n[0] * 6, y0 + 4, z0 + n[1] * 6), (x1 + n[0] * 6, y1 + 4, z1 + n[1] * 6), 1.2, "Rail", 0.8)
            # 버팀 보(60 간격): 비탈 안쪽 → 줄기
            k = 50.0
            while k < step:
                bx_, bz_, _ = pos(best + p + k)
                by_ = GROUND + SLOPE * (p + k) - 3
                th_ = trunk_half(g, by_)
                tx, tz = gx + (bx_ - gx) * th_ / R, gz + (bz_ - gz) * th_ / R
                L = math.hypot(bx_ - tx, bz_ - tz)
                yaw = math.degrees(math.atan2(bx_ - tx, bz_ - tz))
                add(f"{name}_비탈보", "PlankDark", ((bx_ + tx) / 2, by_, (bz_ + tz) / 2), (2.4, 2.4, L), (0, yaw, 0), solid=False)
                k += 120
            # 모서리 쉼판
            if step >= to_corner - 0.01 and p + step < total - 0.01:
                add(f"{name}_쉼판", "Plank", (x1, y1 - 1, z1), (WALK, 2, WALK))
            p += step
        spiral_pts.append((name, R))
        # 판 이음: 판 높이에서 나선 자리 → 판 바깥 모서리
        for d in decks:
            pp = (d[1] - GROUND) / SLOPE
            sx, sz, _ = pos(best + pp)
            ox, oz = sx - gx, sz - gz
            o = deck_outer(d)
            if abs(ox) > abs(oz):
                ex, ez = gx + (o if ox > 0 else -o), sz
            else:
                ex, ez = sx, gz + (o if oz > 0 else -o)
            if math.hypot(sx - ex, sz - ez) > 1:
                plank_between(f"{d[3]}_이음", (sx, d[1], sz), (ex, d[1], ez), WALK)
            gaps[(d[0], d[1])].append((ex, ez))
    for d in DECKS:
        gx, gz, outer = deck_info[(d[0], d[1])]
        rails(d[3], gx, gz, outer, d[1], gaps[(d[0], d[1])])
    # 부딪힘 검사: 걷는 길 표본점 위 머리 공간(0.5~7)이 줄기·뿌리·가지·다른 판 안이면
    def inside_box(px, py, pz, b):
        name, cx, cy, cz, sx, sy, sz, ry, r = b
        lx, ly, lz = to_local(px - cx, py - cy, pz - cz, r)
        return abs(lx) < sx / 2 - 0.5 and abs(ly) < sy / 2 - 0.5 and abs(lz) < sz / 2 - 0.5
    hits = {}
    for (x, y, z, what) in walk:
        for b in solids:
            if b[0] == what or "_판" in b[0] and abs(b[2] - (y - 1.5)) < 2.5:
                continue  # 자기 자신 · 같은 높이 판(이어지는 자리)
            if "테두리" in b[0] or "_비탈" in b[0] or "쉼판" in b[0] or "이음" in b[0] or "다리" in b[0]:
                continue
            for hy in (y + 1, y + 4, y + 7):
                if inside_box(x, hy, z, b):
                    hits[(what, b[0])] = hits.get((what, b[0]), 0) + 1
    for (a, b), n in sorted(hits.items()):
        bad.append(f"길 {a} 이 {b} 에 부딪힘({n}점)")
    return bad


GROUP_SKIN = {
    "Bark": ("112,84,60", "Wood"), "Bark2": ("94,70,50", "Wood"), "LeafA": ("60,94,50", "Grass"), "LeafB": ("38,66,40", "Grass"),
    "Plank": ("168,134,94", "WoodPlanks"), "PlankDark": ("120,92,64", "Wood"), "Rail": ("104,80,56", "Wood"), "Rope": ("120,96,64", "Fabric"),
}

if __name__ == "__main__":
    problems = main()
    for p in problems[:40]:
        print("문제:", p)
    if len(problems) > 40:
        print("…", len(problems) - 40, "더")
    out = ["-- highwood_build.py 가 만든 자료(손으로 고치지 말 것)", "local SKIN = {"]
    for k, (c, m) in GROUP_SKIN.items():
        out.append(f'\t{k} = {{ Color3.fromRGB({c}), Enum.Material.{m} }},')
    out += ["}", "local BOXES = {"]
    for b in boxes:
        name, group, cx, cy, cz, sx, sy, sz, rx, ry, rz = b
        out.append(f'\t{{ "{name}", "{group}", {cx:.2f}, {cy:.2f}, {cz:.2f}, {sx:.2f}, {sy:.2f}, {sz:.2f}, {rx:.1f}, {ry:.1f}, {rz:.1f} }},')
    out.append("}")
    open(os.path.join(HERE, "Highwood_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    big = max(max(b[5], b[6], b[7]) for b in boxes)
    print(f"상자 {len(boxes)} (가장 긴 변 {big:.0f}), 걷는 길 점 {len(walk)}, 문제 {len(problems)}건")
