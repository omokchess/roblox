# -*- coding: utf-8 -*-
"""
snow3_under.py — 2026-10-09. 설원 지하(굴) → tools/Snow3_Under_data.luau

배치 = snow3_plan.UNDER(사용자 지하 그림을 8° 똑바로 해 딴 상자, UNDER_SHIFT 로 지상 아래) + 아래 EXTRA, 승인된 설계.
  굴 바닥 높이(손): 윗굴·입구 쪽 -70, 아랫굴 -80, 케이브(서브보스) -90, 히든 보스 방 -110. 천장은 모두 CEIL.
  땅 밑 지형은 물(-26~-3.5)·얇은 모래(-28)뿐이고 그 아래는 비어 있다(2026-10-09 ReadVoxels) → 굴은 -32 아래에 짓고, 구멍 기둥만 지형을 비운다.
칸: 그림 5px(= 18.5 스터드). 열린 칸 = 굴. 열린 칸 바깥 변에만 벽, 바닥은 깊이별로 묶고, 깊이가 바뀌는 곳은 깊은 쪽에 블록 계단
  (사용자: 경사 말고 네모난 블록). 비밀벽·금이 간 벽은 따로 이름 붙인 벽 덩어리(속성 Secret / Breakable).
구멍(snow3_ground.HOLES) 밑은 천장을 비우고, 구멍 둘레 벽(-24 땅 판 밑 ~ 천장)과 벽을 따라 도는 디딤 블록(5 씩 내려감)을 둔다.
돌리기: python tools/snow3_under.py (문제 0건) → 짓기: tools/Snow3_Under.luau
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import SCALE, UNDER, UNDER_SHIFT, ZONES, world  # noqa: E402
import snow3_ground as SG  # noqa: E402

CELL = 5
CEIL = -36  # 천장 아랫면
DEPTH = {  # 상자 이름 머리 → 바닥 높이
    "입구2 방": -70, "윗굴": -70, "입구1 굴": -70, "동굴입구1 굴": -70,
    "아랫굴": -80, "긴 아랫굴": -80, "케이브": -90, "히든 보스 방": -110,
}
SPECIAL = {"비밀벽": "Secret", "금이 간 벽": "Breakable"}
# 그림(지하 좌표)에 없지만 이어야 하는 굴: 동굴 입구 1 밑에서 입구1 굴까지(지상 좌표로 적고 지하 좌표로 바꿈)
EXTRA = [("동굴입구1 굴", 686 - UNDER_SHIFT[0], 1304 - UNDER_SHIFT[1], 812 - UNDER_SHIFT[0], 1334 - UNDER_SHIFT[1])]


def depth_of(name):
    for k, v in DEPTH.items():
        if name.startswith(k):
            return v
    return None


def rects_all():
    out = []
    for r in list(UNDER) + EXTRA:
        n, x0, y0, x1, y1 = r
        out.append((n, x0 + UNDER_SHIFT[0], y0 + UNDER_SHIFT[1], x1 + UNDER_SHIFT[0], y1 + UNDER_SHIFT[1]))
    return out


def build():
    bad = []
    rs = rects_all()
    xs = [r[1] for r in rs] + [r[3] for r in rs]
    ys = [r[2] for r in rs] + [r[4] for r in rs]
    GX0, GY0 = int(min(xs) // CELL * CELL) - CELL, int(min(ys) // CELL * CELL) - CELL
    nx, ny = int((max(xs) - GX0) // CELL) + 2, int((max(ys) - GY0) // CELL) + 2
    floor = [[None] * ny for _ in range(nx)]
    special = [[None] * ny for _ in range(nx)]
    for n, x0, y0, x1, y1 in rs:
        d = depth_of(n)
        for i in range(nx):
            for j in range(ny):
                cx, cy = GX0 + (i + 0.5) * CELL, GY0 + (j + 0.5) * CELL
                if x0 <= cx <= x1 and y0 <= cy <= y1:
                    if n in SPECIAL:
                        special[i][j] = n
                    elif d is not None:
                        floor[i][j] = d if floor[i][j] is None else max(floor[i][j], d)  # 겹치면 얕은 쪽
    for i in range(nx):
        for j in range(ny):
            if special[i][j]:
                floor[i][j] = None

    def W(i, j):
        return world(GX0 + i * CELL, GY0 + j * CELL)

    parts = []  # (종류, x0, x1, z0, z1, y0, y1, 이름)

    def box(kind, i0, j0, i1, j1, y0, y1, name=""):
        (ax, az), (bx, bz) = W(i0, j0), W(i1, j1)
        parts.append((kind, ax, bx, az, bz, y0, y1, name))

    # 구멍 칸(지상 구멍 밑): 천장 없음
    hole_cells = set()
    for hn, (a, b, c, d) in SG.HOLES.items():
        for i in range(nx):
            for j in range(ny):
                cx, cy = GX0 + (i + 0.5) * CELL, GY0 + (j + 0.5) * CELL
                if a <= cx <= b and c <= cy <= d:
                    hole_cells.add((i, j))
                    if floor[i][j] is None:
                        bad.append(f"{hn} 구멍 밑 ({cx},{cy}) 에 굴이 없다")
    # 바닥·천장: 같은 값 칸을 큰 직사각형으로
    def merge(val):
        used = [[False] * ny for _ in range(nx)]
        out = []
        for i in range(nx):
            for j in range(ny):
                v = val(i, j)
                if v is None or used[i][j]:
                    continue
                j2 = j
                while j2 + 1 < ny and val(i, j2 + 1) == v and not used[i][j2 + 1]:
                    j2 += 1
                i2 = i
                while i2 + 1 < nx and all(val(i2 + 1, t) == v and not used[i2 + 1][t] for t in range(j, j2 + 1)):
                    i2 += 1
                for a in range(i, i2 + 1):
                    for b in range(j, j2 + 1):
                        used[a][b] = True
                out.append((v, i, j, i2 + 1, j2 + 1))
        return out
    for v, i0, j0, i1, j1 in merge(lambda i, j: floor[i][j]):
        box("Floor", i0, j0, i1, j1, v - 6, v)
    for v, i0, j0, i1, j1 in merge(lambda i, j: 1 if (floor[i][j] is not None or special[i][j]) and (i, j) not in hole_cells else None):
        box("Ceil", i0, j0, i1, j1, CEIL, CEIL + 6)
    # 벽: 열린 칸(또는 특별 벽 칸) 바깥 변 — 칸 하나 두께로 바깥 칸에
    def openish(i, j):
        return 0 <= i < nx and 0 <= j < ny and (floor[i][j] is not None or special[i][j] is not None)
    wall = [[None] * ny for _ in range(nx)]
    for i in range(nx):
        for j in range(ny):
            if openish(i, j):
                continue
            if any(openish(i + di, j + dj) for di in (-1, 0, 1) for dj in (-1, 0, 1)):
                wall[i][j] = 1
    for v, i0, j0, i1, j1 in merge(lambda i, j: wall[i][j]):
        box("Wall", i0, j0, i1, j1, -130, CEIL + 6)
    # 특별 벽(비밀벽·금 간 벽): 이름별 덩어리
    for n in SPECIAL:
        cells = [(i, j) for i in range(nx) for j in range(ny) if special[i][j] == n]
        if not cells:
            bad.append(f"{n} 칸이 없다")
            continue
        i0, i1 = min(c[0] for c in cells), max(c[0] for c in cells) + 1
        j0, j1 = min(c[1] for c in cells), max(c[1] for c in cells) + 1
        box(SPECIAL[n], i0, j0, i1, j1, -130, CEIL, n)
    # 깊이 바뀌는 곳: 깊은 칸 쪽에 블록 계단(5 씩, 칸 하나씩 물러나며 낮아짐) — 얕은 칸 옆 깊은 칸들
    steps = 0
    # 특별 벽(열리면 지나는 자리)은 계단 계산에서 이웃 굴 중 얕은 바닥으로 친다(비밀벽 뒤 히든 보스 방 -110 으로 내려가는 계단)
    step_floor = [row[:] for row in floor]
    # 벽이 두 칸 두께일 수 있어 벽 덩어리 전체에 닿는 굴 중 가장 얕은 바닥을 쓴다
    for n in SPECIAL:
        cells = [(i, j) for i in range(nx) for j in range(ny) if special[i][j] == n]
        nb = [floor[a][b] for i, j in cells for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1))
              if 0 <= a < nx and 0 <= b < ny and floor[a][b] is not None]
        for i, j in cells:
            if nb:
                step_floor[i][j] = max(nb)
    for i in range(nx):
        for j in range(ny):
            d = step_floor[i][j]
            if d is None:
                continue
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if not (0 <= a < nx and 0 <= b < ny) or floor[a][b] is None or floor[a][b] >= d or special[a][b]:
                    continue
                # (i,j) 가 얕고 (a,b) 가 깊다 → 깊은 쪽으로 n 칸 계단
                dh = d - floor[a][b]
                n = math.ceil(dh / 5)
                for t in range(1, n):
                    ci, cj = i + di * t, j + dj * t
                    if not (0 <= ci < nx and 0 <= cj < ny) or floor[ci][cj] != floor[a][b]:
                        break
                    top = d - dh * t / n
                    box("Step", ci, cj, ci + 1, cj + 1, floor[a][b] - 1, top)
                    steps += 1
    # 구멍 기둥: 땅 판 밑(-24) ~ 천장 사이 둘레 벽 + 벽 따라 도는 디딤 블록
    shafts = []
    for hn, (a, b, c, d) in SG.HOLES.items():
        (wx0, wz0), (wx1, wz1) = world(a, c), world(b, d)
        Xc, Yc = (a + b) / 2, (c + d) / 2
        surf = SG.zone_at(Xc, Yc, SG.grid()[0])
        # 밑 굴 바닥
        ii, jj = int((Xc - GX0) // CELL), int((Yc - GY0) // CELL)
        bottom = floor[ii][jj] if 0 <= ii < nx and 0 <= jj < ny else None
        if surf is None or bottom is None:
            bad.append(f"{hn}: 땅 {surf} / 굴 바닥 {bottom}")
            continue
        T = 4
        for (x0, x1, z0, z1) in ((wx0 - T, wx1 + T, wz0 - T, wz0), (wx0 - T, wx1 + T, wz1, wz1 + T), (wx0 - T, wx0, wz0, wz1), (wx1, wx1 + T, wz0, wz1)):
            parts.append(("ShaftWall", x0, x1, z0, z1, CEIL, -24, hn))
        # 디딤: 둘레를 시계로 돌며 한 개 길이 18, 폭 14, 5 씩 내려감 — 땅 높이 - 5 에서 바닥 + 5 까지
        side = wx1 - wx0
        per = 4 * side
        Lseg, depth_l = 18.0, 14.0
        y = surf - 5
        p = 0.0
        while y > bottom + 2:
            q = p % per
            k_ = int(q // side)
            f = q - k_ * side
            if k_ == 0:      # 북쪽 벽, 동쪽으로
                box_ = (wx0 + f, min(wx0 + f + Lseg, wx1), wz0, wz0 + depth_l)
            elif k_ == 1:    # 동쪽 벽, 남쪽으로
                box_ = (wx1 - depth_l, wx1, wz0 + f, min(wz0 + f + Lseg, wz1))
            elif k_ == 2:    # 남쪽 벽, 서쪽으로
                box_ = (max(wx1 - f - Lseg, wx0), wx1 - f, wz1 - depth_l, wz1)
            else:            # 서쪽 벽, 북쪽으로
                box_ = (wx0, wx0 + depth_l, max(wz1 - f - Lseg, wz0), wz1 - f)
            parts.append(("Ledge", box_[0], box_[1], box_[2], box_[3], y - 4, y, hn))
            y -= 5
            p += Lseg
        shafts.append((hn, wx0, wx1, wz0, wz1, surf, bottom))
    # 불빛: 큰 직사각형 바닥 조각마다 가운데 하나(얼음 등)
    lights = []
    for v, i0, j0, i1, j1 in merge(lambda i, j: floor[i][j]):
        if (i1 - i0) * (j1 - j0) >= 8:
            (ax, az), (bx, bz) = W(i0, j0), W(i1, j1)
            lights.append(((ax + bx) / 2, v + 10, (az + bz) / 2))
    return parts, shafts, lights, steps, bad


if __name__ == "__main__":
    parts, shafts, lights, steps, bad = build()
    for p in bad:
        print("문제:", p)
    out = ["-- snow3_under.py 가 만든 자료(손으로 고치지 말 것)", "local PARTS = {"]
    out += [f'\t{{ "{k}", {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {y0:.1f}, {y1:.1f}, "{n}" }},' for k, a, b, c, d, y0, y1, n in parts]
    out += ["}", "local SHAFTS = {"]
    out += [f'\t{{ "{n}", {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {s}, {bt} }},' for n, a, b, c, d, s, bt in shafts]
    out += ["}", "local LIGHTS = {"]
    out += [f"\t{{ {x:.1f}, {y:.1f}, {z:.1f} }}," for x, y, z in lights]
    out += ["}"]
    open(os.path.join(HERE, "Snow3_Under_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    kinds = {}
    for p in parts:
        kinds[p[0]] = kinds.get(p[0], 0) + 1
    print(kinds, "계단", steps, "구멍", len(shafts), "불빛", len(lights), "문제", len(bad))
