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
# 단 사이 바위 덩어리 본보기(손으로 — 사용자 참고 사진: 눈 협곡, 크기 제각각 바위 상자가 엇갈려 쌓이고 턱이 튀어나옴).
# 상자 { u0, u1 (벽 따라 스터드), v0, v1 (벽에서 낮은 쪽으로 스터드, 높이 차 40 기준), 윗면 높이 비(0 = 낮은 땅, 1 = 높은 단) }.
# 이웃 상자 높이 비 차는 0.16 아래(높이 차 40 이면 6.4 — 뛰어 오를 수 있게). 1 넘는 것은 벽 위로 솟은 바위 기둥.
CLUSTERS = [
    (130, [(0, 60, 0, 45, 0.88), (55, 130, 0, 30, 0.95), (0, 40, 45, 85, 0.66), (35, 95, 30, 75, 0.74), (95, 130, 30, 60, 0.6),
           (20, 80, 85, 125, 0.44), (80, 130, 60, 110, 0.4), (0, 30, 85, 140, 0.26), (45, 110, 125, 170, 0.12),
           (100, 125, 110, 135, 0.27), (60, 76, 8, 26, 1.18)]),
    (110, [(0, 110, 0, 25, 0.92), (0, 50, 25, 70, 0.76), (50, 110, 25, 50, 0.82), (60, 110, 50, 95, 0.6), (0, 45, 70, 110, 0.5),
           (30, 80, 95, 135, 0.34), (80, 110, 95, 150, 0.2), (0, 30, 110, 160, 0.12)]),
    (150, [(0, 80, 0, 35, 0.82), (80, 150, 0, 50, 0.9), (10, 60, 35, 80, 0.66), (60, 120, 50, 90, 0.7), (120, 150, 50, 85, 0.5),
           (0, 45, 80, 120, 0.36), (45, 110, 90, 130, 0.5), (110, 150, 85, 140, 0.3), (20, 90, 130, 175, 0.16),
           (95, 112, 18, 36, 1.12)]),
    (95, [(0, 95, 0, 35, 0.86), (0, 40, 35, 75, 0.62), (40, 95, 35, 65, 0.72), (45, 95, 65, 110, 0.48), (0, 50, 75, 120, 0.34),
          (10, 70, 120, 155, 0.16), (70, 95, 110, 140, 0.22)]),
]


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
    """단 사이 벽마다 바위 덩어리 무리(CLUSTERS)를 차례로(거울 번갈아) 놓는다 → [("R", (x0,x1,z0,z1), 아래, 위, 색)]"""
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
    for (name, h, lo), cells in sorted(walls.items()):
        di, dj = dirs[name]
        dh = h - lo
        sv = max(0.35, min(1.0, dh / 40))  # 깊이 배율
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
                # 벽 선(월드): 따라가는 축 시작·끝, 고정 좌표, 바깥 방향
                if dj != 0:
                    wall = world(0, Y0 + (key + (1 if dj > 0 else 0)) * CELL)[1]
                    a0, a1 = world(X0 + run[0] * CELL, 0)[0], world(X0 + (run[-1] + 1) * CELL, 0)[0]
                else:
                    wall = world(X0 + (key + (1 if di > 0 else 0)) * CELL, 0)[0]
                    a0, a1 = world(0, Y0 + run[0] * CELL)[1], world(0, Y0 + (run[-1] + 1) * CELL)[1]
                out_dir = dj if dj != 0 else di

                def fit_at(u):
                    """벽 따라 u(월드) 자리에서 낮은 땅이 몇 스터드 이어지나"""
                    c = int(((u - a0) / (CELL * SCALE)))
                    c = max(0, min(len(run) - 1, c))
                    ci, cj = (run[c], key) if dj != 0 else (key, run[c])
                    f = 0
                    while f < 40 and top(ci + di * (f + 1), cj + dj * (f + 1)) == lo:
                        f += 1
                    return f * CELL * SCALE

                cur_u = a0
                while cur_u < a1 - 4:
                    W, boxes = CLUSTERS[k % len(CLUSTERS)]
                    mirror = (k // len(CLUSTERS)) % 2 == 1
                    k += 1
                    for (u0, u1, v0, v1, f) in boxes:
                        if mirror:
                            u0, u1 = W - u1, W - u0
                        x0, x1 = cur_u + u0, min(cur_u + u1, a1)
                        if x1 - x0 < 4:
                            continue
                        fit = min(fit_at(x0 + 0.1), fit_at(x1 - 0.1))
                        d0, d1 = v0 * sv, min(v1 * sv, fit)
                        if f <= 1 and d1 - d0 < 4:
                            continue
                        if f > 1:  # 솟은 바위: 벽에 붙여 높은 단 쪽으로도 조금 들어가게
                            d0, d1 = -abs(d1 - d0) * 0.5, d1
                        topy = lo + f * dh
                        if topy - lo < 1.5:
                            continue
                        n0, n1 = wall + out_dir * (d0 - 0.5), wall + out_dir * d1
                        if dj != 0:
                            box = (x0, x1, min(n0, n1), max(n0, n1))
                        else:
                            box = (min(n0, n1), max(n0, n1), x0, x1)
                        out.append(("R", box, lo - 2, topy, k % 2))
                    cur_u += W
    return out, 0


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
    print(f"땅 판 {len(tiles)} · 벼랑 {len(cliffs)} · 바위 상자 {len(wedges)} · 문제 {len(bad)}건")
