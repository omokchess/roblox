# -*- coding: utf-8 -*-
"""
snow3_ground.py — 2026-10-09. 설원 3판 지상 땅 → tools/Snow3_Ground_data.luau

구역·높이 = snow3_plan.py(사용자 승인: "높이는 그대로, 어긋난 칸 없음"). 기운 변은 사용자 말대로 "블록을 크게 놓아 보정":
  구역 다각형을 그림 10px(= 37 스터드) 칸으로 나눠 칸 가운데가 든 구역에 주고, 같은 구역 칸을 큰 직사각형으로 묶는다(계단식).
바닷가: 섬 바깥 변(칸 경계)을 곧은 토막으로 이어, 토막마다 바위 벼랑. 높이·깊이는 손 표(CLIFF_STYLE)를 차례로 돌려 쓴다.
계단 단(2026-10-09 사용자: "설원은 높낮이 차를 천천히 채울 거야, 여러 개로" → "경사가 아니라 네모난 블록들을 차근차근"):
  → 다시 "썰매장마냥 놓지 말고" + 참고 사진(눈 협곡): 반듯한 켜 대신 손으로 짠 바위 덩어리 본보기(CLUSTERS)를 벽 따라 차례로·거울 번갈아
  놓는다. 높이 비 × 높이 차, 깊이는 높이 차에 맞춰 줄이고 낮은 땅 밖으로 나가면 자른다. 쐐기·한 줄 오르막·반듯한 띠는 쓰지 않는다.
돌리기: python tools/snow3_ground.py (문제 0건) → 짓기: tools/Snow3_Build.luau 머리 주석
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import FIELD, SCALE, SPOTS, ZONES, world  # noqa: E402

CELL = 10  # 그림 px
X0, X1, Y0, Y1 = 120, 880, 930, 1500
# 바닷가 벼랑 손 표: (땅 위 높이, 깊이 스터드) — 바깥 토막마다 차례로
CLIFF_STYLE = [(10, 26), (18, 30), (6, 24), (14, 28), (22, 32), (8, 24), (16, 28), (4, 22), (12, 26), (20, 30)]
# 오르막 { 이름, 시작(X,Y), 끝(X,Y), 시작 높이, 끝 높이, 폭 스터드 } — 그림 좌표, 높은 단 벽 바로 바깥(낮은 땅 위)
RAMPS = []  # 2026-10-09 비탈(slopes)로 바꿈
# 단 사이 바위 덩어리 본보기(손으로 — 사용자 참고 사진: 눈 협곡). 2026-10-09 "크게크게 놔서 빈 공간 안 보이고 자연스럽게":
#   본보기 = 폭이 다른 기둥 줄. 기둥마다 벽에서 낮은 쪽으로 띠(끝 v 스터드, 윗면 높이 비)를 이어 붙여 빈틈이 없다.
#   기둥끼리 띠 끊는 자리가 달라 엇갈린 바위 단이 된다. 그 위에 큰 바위(BOULDERS: u0,u1,v0,v1,높이 비)를 몇 개 얹는다.
#   v 는 높이 차 40 기준 스터드(최대 ≈ 250). 낮은 땅이 모자라면 기둥마다 v 를 줄여 띠를 다 넣는다(중간에 잘린 벽이 안 생기게).
CLUSTERS = [
    ([(60, [(50, 0.92), (95, 0.74), (150, 0.5), (200, 0.3), (240, 0.12)]),
      (45, [(70, 0.88), (120, 0.66), (170, 0.42), (230, 0.2)]),
      (70, [(40, 0.96), (85, 0.8), (140, 0.58), (190, 0.34), (250, 0.14)]),
      (35, [(60, 0.86), (110, 0.62), (160, 0.38), (210, 0.18)])],
     [(40, 90, 20, 60, 1.12), (130, 165, 100, 135, 0.7)]),
    ([(80, [(65, 0.9), (110, 0.7), (180, 0.46), (235, 0.22)]),
      (50, [(45, 0.94), (100, 0.76), (140, 0.56), (200, 0.3), (250, 0.1)]),
      (65, [(80, 0.84), (130, 0.6), (170, 0.4), (220, 0.2)])],
     [(100, 150, 90, 125, 0.82), (20, 45, 140, 170, 0.5)]),
    ([(40, [(55, 0.9), (120, 0.64), (190, 0.32), (230, 0.14)]),
      (75, [(35, 0.97), (90, 0.78), (135, 0.55), (185, 0.36), (245, 0.16)]),
      (55, [(70, 0.86), (110, 0.68), (160, 0.46), (215, 0.24)]),
      (45, [(50, 0.92), (100, 0.72), (150, 0.5), (205, 0.28), (240, 0.1)])],
     [(100, 140, 10, 40, 1.15), (160, 200, 130, 170, 0.6)]),
    ([(90, [(60, 0.93), (115, 0.71), (165, 0.5), (210, 0.26), (245, 0.12)]),
      (60, [(40, 0.88), (95, 0.68), (150, 0.44), (200, 0.22)])],
     [(60, 110, 50, 90, 0.85)]),
]
# 볼록 모서리 메움: 모서리에서 낮은 쪽 사분면에 겹친 네모(깊이 비, 높이 비) — 큰 것이 낮다
CORNER = [(0.32, 0.82), (0.55, 0.6), (0.78, 0.36), (1.0, 0.14)]


def inside(pt, poly):
    x, y = pt
    hit = False
    for i in range(len(poly)):
        (ax, ay), (bx, by) = poly[i], poly[(i + 1) % len(poly)]
        if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
            hit = not hit
    return hit


def grid():
    nx, ny = (X1 - X0) // CELL, (Y1 - Y0) // CELL
    g = [[None] * ny for _ in range(nx)]
    for i in range(nx):
        for j in range(ny):
            c = (X0 + (i + 0.5) * CELL, Y0 + (j + 0.5) * CELL)
            for k, (name, poly, top, _) in enumerate(ZONES):
                if inside(c, poly):
                    g[i][j] = k
                    break
    # 구역 다각형 사이 틈(손으로 딴 꼭짓점이 조금씩 어긋남): 어느 구역 변에서든 6px 안이면 가장 가까운 구역으로
    for i in range(nx):
        for j in range(ny):
            if g[i][j] is None:
                c = (X0 + (i + 0.5) * CELL, Y0 + (j + 0.5) * CELL)
                best, bk = 6.0, None
                for k, (name, poly, top, _) in enumerate(ZONES):
                    for t in range(len(poly)):
                        d = seg_d(c, poly[t], poly[(t + 1) % len(poly)])
                        if d < best:
                            best, bk = d, k
                g[i][j] = bk
    # 칸 나누기로 생긴 한 칸 폭 조각(같은 구역 이웃이 마주 보는 두 쪽 다 없음)은 이웃 중 많은 구역으로(두 번)
    for _ in range(2):
        for i in range(nx):
            for j in range(ny):
                k = g[i][j]
                if k is None:
                    continue
                def at(a, b):
                    return g[a][b] if 0 <= a < nx and 0 <= b < ny else None
                thin_x = at(i - 1, j) != k and at(i + 1, j) != k
                thin_y = at(i, j - 1) != k and at(i, j + 1) != k
                if thin_x or thin_y:
                    nb = [at(i - 1, j), at(i + 1, j), at(i, j - 1), at(i, j + 1)]
                    nb = [v for v in nb if v is not None and v != k]
                    if nb:
                        g[i][j] = max(set(nb), key=nb.count)
    return g, nx, ny


def seg_d(p, a, b):
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def rects(g, nx, ny):
    used = [[False] * ny for _ in range(nx)]
    out = []
    for i in range(nx):
        for j in range(ny):
            k = g[i][j]
            if k is None or used[i][j]:
                continue
            j2 = j
            while j2 + 1 < ny and g[i][j2 + 1] == k and not used[i][j2 + 1]:
                j2 += 1
            i2 = i
            while i2 + 1 < nx and all(g[i2 + 1][t] == k and not used[i2 + 1][t] for t in range(j, j2 + 1)):
                i2 += 1
            for a in range(i, i2 + 1):
                for b in range(j, j2 + 1):
                    used[a][b] = True
            out.append((k, X0 + i * CELL, Y0 + j * CELL, X0 + (i2 + 1) * CELL, Y0 + (j2 + 1) * CELL))
    return out


def coast(g, nx, ny):
    """바깥 변(땅 칸 ↔ 빈 칸) 을 곧은 토막으로: (축, 고정 좌표, 시작, 끝, 바깥 방향 ±1, 안쪽 땅 높이)"""
    def land(i, j):
        return 0 <= i < nx and 0 <= j < ny and g[i][j] is not None
    runs = []
    # 가로 변(아래·위)
    for j in range(ny + 1):
        for side in (-1, 1):  # -1: 칸 j 의 위(북)쪽이 바다, +1: 칸 j-1 의 아래(남)쪽이 바다
            cur = None
            for i in range(nx + 1):
                if side == -1:
                    edge = i < nx and land(i, j) and not land(i, j - 1)
                    owner = (i, j)
                else:
                    edge = i < nx and land(i, j - 1) and not land(i, j)
                    owner = (i, j - 1)
                top = ZONES[g[owner[0]][owner[1]]][2] if edge else None
                if edge and cur and cur[4] == top:
                    cur[3] = i + 1
                else:
                    if cur:
                        runs.append(tuple(cur))
                    cur = ["z", Y0 + j * CELL, i, i + 1, top, side] if edge else None
            if cur:
                runs.append(tuple(cur))
    # 세로 변(서·동)
    for i in range(nx + 1):
        for side in (-1, 1):
            cur = None
            for j in range(ny + 1):
                if side == -1:
                    edge = j < ny and land(i, j) and not land(i - 1, j)
                    owner = (i, j)
                else:
                    edge = j < ny and land(i - 1, j) and not land(i, j)
                    owner = (i - 1, j)
                top = ZONES[g[owner[0]][owner[1]]][2] if edge else None
                if edge and cur and cur[4] == top:
                    cur[3] = j + 1
                else:
                    if cur:
                        runs.append(tuple(cur))
                    cur = ["x", X0 + i * CELL, j, j + 1, top, side] if edge else None
            if cur:
                runs.append(tuple(cur))
    cliffs = []
    for n, (axis, fixed, a, b, top, side) in enumerate(runs):
        h, depth = CLIFF_STYLE[n % len(CLIFF_STYLE)]
        d = depth / SCALE  # 그림 px
        if axis == "z":
            xa, xb = X0 + a * CELL - d, X0 + b * CELL + d  # 모서리 이음매 막기
            za, zb = (fixed - d, fixed + 0.5) if side == -1 else (fixed - 0.5, fixed + d)
        else:
            za, zb = Y0 + a * CELL - d, Y0 + b * CELL + d
            xa, xb = (fixed - d, fixed + 0.5) if side == -1 else (fixed - 0.5, fixed + d)
        (wx0, wz0), (wx1, wz1) = world(xa, za), world(xb, zb)
        cliffs.append((wx0, wx1, wz0, wz1, top + h))
    return cliffs


def slopes(g, nx, ny, bad):
    """단 사이 벽마다 바위 덩어리 띠(CLUSTERS)를 차례로(거울 번갈아), 볼록 모서리는 CORNER 로 → [("R", (x0,x1,z0,z1), 아래, 위, 색)]"""
    def top(i, j):
        if 0 <= i < nx and 0 <= j < ny and g[i][j] is not None:
            return ZONES[g[i][j]][2]
        return None
    dirs = {"S": (0, 1), "N": (0, -1), "E": (1, 0), "W": (-1, 0)}
    walls = {}
    for i in range(nx):
        for j in range(ny):
            h = top(i, j)
            if h is None:
                continue
            for name, (di, dj) in dirs.items():
                lo = top(i + di, j + dj)
                if lo is not None and lo < h:
                    walls.setdefault((name, h, lo), set()).add((i, j))
    out = []
    k = 0
    cell = CELL * SCALE

    def put(box, lo, topy, c):
        if topy - lo >= 1.5:
            out.append(("R", box, lo - 2, topy, c))

    for (name, h, lo), cells in sorted(walls.items()):
        di, dj = dirs[name]
        dh = h - lo
        sv = max(0.5, min(1.0, dh / 40))
        lines = {}
        for (i, j) in cells:
            lines.setdefault(j if dj != 0 else i, []).append(i if dj != 0 else j)
        for key, idx in sorted(lines.items()):
            idx.sort()
            runs, cur = [], [idx[0]]
            for v in idx[1:]:
                if v == cur[-1] + 1:
                    cur.append(v)
                else:
                    runs.append(cur)
                    cur = [v]
            runs.append(cur)
            for run in runs:
                if dj != 0:
                    wall = world(0, Y0 + (key + (1 if dj > 0 else 0)) * CELL)[1]
                    a0, a1 = world(X0 + run[0] * CELL, 0)[0], world(X0 + (run[-1] + 1) * CELL, 0)[0]
                else:
                    wall = world(X0 + (key + (1 if di > 0 else 0)) * CELL, 0)[0]
                    a0, a1 = world(0, Y0 + run[0] * CELL)[1], world(0, Y0 + (run[-1] + 1) * CELL)[1]
                od = dj if dj != 0 else di

                def fit_at(u):
                    c = max(0, min(len(run) - 1, int((u - a0) / cell)))
                    ci, cj = (run[c], key) if dj != 0 else (key, run[c])
                    f = 0
                    while f < 40 and top(ci + di * (f + 1), cj + dj * (f + 1)) == lo:
                        f += 1
                    return f * cell

                def rect(u0, u1, d0, d1):
                    n0, n1 = wall + od * d0, wall + od * d1
                    if dj != 0:
                        return (u0, u1, min(n0, n1), max(n0, n1))
                    return (min(n0, n1), max(n0, n1), u0, u1)

                cur_u = a0
                while cur_u < a1 - 4:
                    cols, boulders = CLUSTERS[k % len(CLUSTERS)]
                    W = sum(c[0] for c in cols)
                    mirror = (k // len(CLUSTERS)) % 2 == 1
                    k += 1
                    order = list(reversed(cols)) if mirror else cols
                    u = cur_u
                    for cw, bands in order:
                        u0, u1 = u, min(u + cw, a1)
                        u += cw
                        if u1 - u0 < 3:
                            continue
                        fit = min(fit_at(u0 + 0.1), fit_at(u1 - 0.1))
                        need = bands[-1][0] * sv
                        sc = sv * min(1.0, fit / need) if need > 0 else sv
                        v0 = -0.5
                        for v1, f in bands:
                            # 이웃 띠·기둥과 1 겹쳐 틈이 안 보이게
                            put(rect(u0 - 0.5, u1 + 0.5, v0, v1 * sc + 0.5), lo, lo + f * dh, k % 2)
                            v0 = v1 * sc - 0.5
                    for (b0, b1, c0, c1, f) in boulders:
                        if mirror:
                            b0, b1 = W - b1, W - b0
                        x0, x1 = cur_u + b0, min(cur_u + b1, a1)
                        if x1 - x0 < 4:
                            continue
                        fit = min(fit_at(x0 + 0.1), fit_at(x1 - 0.1))
                        d0, d1 = c0 * sv, min(c1 * sv, fit)
                        if f > 1:
                            d0 = -(d1 - d0) * 0.4
                        if d1 - d0 >= 4:
                            put(rect(x0, x1, d0, d1), lo, lo + f * dh, (k + 1) % 2)
                    cur_u += W
    # 볼록 모서리(높은 칸 하나에 남북·동서 벽이 같이 있고 대각 칸이 같은 낮은 땅)
    corners = 0
    for i in range(nx):
        for j in range(ny):
            h = top(i, j)
            if h is None:
                continue
            for si in (-1, 1):
                for sj in (-1, 1):
                    l1, l2, l3 = top(i + si, j), top(i, j + sj), top(i + si, j + sj)
                    if l1 is None or not (l1 == l2 == l3) or l1 >= h:
                        continue
                    dh = h - l1
                    D = 240 * max(0.5, min(1.0, dh / 40))
                    # 대각 쪽 낮은 땅이 이어지는 만큼
                    f = 0
                    while f < 40 and top(i + si * (f + 1), j + sj * (f + 1)) == l1:
                        f += 1
                    D = min(D, f * cell)
                    vx, vz = world(X0 + (i + (1 if si > 0 else 0)) * CELL, Y0 + (j + (1 if sj > 0 else 0)) * CELL)
                    for fr, fh in CORNER:
                        d = D * fr
                        x0, x1 = sorted((vx - si * 0.5, vx + si * d))
                        z0, z1 = sorted((vz - sj * 0.5, vz + sj * d))
                        put((x0, x1, z0, z1), l1, l1 + fh * dh, corners % 2)
                    corners += 1
    return out, corners


def zone_at(X, Y, g):
    i, j = int((X - X0) // CELL), int((Y - Y0) // CELL)
    if 0 <= i < len(g) and 0 <= j < len(g[0]) and g[i][j] is not None:
        return ZONES[g[i][j]][2]
    return None


def main():
    bad = []
    g, nx, ny = grid()
    rs = rects(g, nx, ny)
    tiles = []
    for k, xa, ya, xb, yb in rs:
        (wx0, wz0), (wx1, wz1) = world(xa, ya), world(xb, yb)
        tiles.append((ZONES[k][0], wx0, wz0, wx1, wz1, ZONES[k][2]))
        if max(wx1 - wx0, wz1 - wz0) > 2048:
            bad.append(f"{ZONES[k][0]} 판이 2048 넘음")
    cliffs = coast(g, nx, ny)
    wedges, ncorner = slopes(g, nx, ny, bad)
    ramps = []
    for name, (sx, sy), (ex, ey), h0, h1, w in RAMPS:
        L = math.hypot(ex - sx, ey - sy) * SCALE
        if abs(h1 - h0) / L > 0.3:
            bad.append(f"{name}: 기울기 {abs(h1 - h0) / L:.2f}")
        for (X, Y), want in (((sx, sy), h0), ((ex, ey), h0)):
            if zone_at(X, Y, g) != want:
                bad.append(f"{name}: ({X},{Y}) 땅 높이 {zone_at(X, Y, g)} ≠ {want}(오르막은 낮은 땅 위)")
        # 끝 바로 옆(벽 너머)에 끝 높이 땅이 있어야
        dx, dy = (ex - sx), (ey - sy)
        L0 = math.hypot(dx, dy)
        nx_, ny_ = -dy / L0, dx / L0
        if not any(zone_at(ex + nx_ * s * CELL, ey + ny_ * s * CELL, g) == h1 for s in (-1.5, 1.5)):
            bad.append(f"{name}: 끝 옆에 높이 {h1} 땅이 없다")
        (wsx, wsz), (wex, wez) = world(sx, sy), world(ex, ey)
        ramps.append((wsx, wsz, wex, wez, h0, h1, w, name))
    for n, X, Y in SPOTS:
        if zone_at(X, Y, g) is None and not n.startswith("3번"):
            bad.append(f"{n} 이 땅 밖")
    return tiles, cliffs, ramps, bad, wedges, ncorner


if __name__ == "__main__":
    tiles, cliffs, ramps, bad, wedges, ncorner = main()
    for p in bad[:30]:
        print("문제:", p)
    out = ["-- snow3_ground.py 가 만든 자료(손으로 고치지 말 것)", "local TILES = {"]
    out += [f'\t{{ "{n}", {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t} }},' for n, a, b, c, d, t in tiles]
    out += ["}", "local CLIFFS = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t:.1f} }}," for a, b, c, d, t in cliffs]
    out += ["}", "local RAMPS = {"]
    out += [f'\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {h0}, {h1}, {w}, "{n}" }},' for a, b, c, d, h0, h1, w, n in ramps]
    out += ["}", "local STEPS = {"]  # 계단 켜 { x0, x1, z0, z1, 아래, 위, 색 번호 }
    out += [f"	{{ {bx[0]:.1f}, {bx[1]:.1f}, {bx[2]:.1f}, {bx[3]:.1f}, {lo:.1f}, {tp:.2f}, {c} }}," for _, bx, lo, tp, c in wedges]
    out += ["}"]
    open(os.path.join(HERE, "Snow3_Ground_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"땅 판 {len(tiles)} · 벼랑 {len(cliffs)} · 바위 상자 {len(wedges)}(모서리 {ncorner}곳) · 문제 {len(bad)}건")
