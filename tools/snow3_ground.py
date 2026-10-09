# -*- coding: utf-8 -*-
"""
snow3_ground.py — 2026-10-09. 설원 3판 지상 땅 → tools/Snow3_Ground_data.luau

구역·높이 = snow3_plan.py(사용자 승인: "높이는 그대로, 어긋난 칸 없음"). 기운 변은 사용자 말대로 "블록을 크게 놓아 보정":
  구역 다각형을 그림 10px(= 37 스터드) 칸으로 나눠 칸 가운데가 든 구역에 주고, 같은 구역 칸을 큰 직사각형으로 묶는다(계단식).
바닷가: 섬 바깥 변(칸 경계)을 곧은 토막으로 이어, 토막마다 바위 벼랑. 높이·깊이는 손 표(CLIFF_STYLE)를 차례로 돌려 쓴다.
계단 단(2026-10-09 사용자: "설원은 높낮이 차를 천천히 채울 거야, 여러 개로" → "경사가 아니라 네모난 블록들을 차근차근"):
  단과 단 사이 모든 벽(칸 경계)을 곧은 토막으로 잇고, 토막을 손 표(SLOPE_RUNS) 길이로 나눠 조각마다 퍼짐(SLOPE_GRADS: 높이 차 / 퍼짐)과
  켜 높이(STEP_H)를 달리해 낮은 쪽에 직사각형 블록을 여러 켜로 깐다(벽에 가까울수록 높게). 낮은 땅 밖으로 나가면 퍼짐을 줄인다.
  높은 단의 볼록 모서리도 같은 켜로 메운다. 쐐기 비탈·한 줄 오르막은 쓰지 않는다.
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
# 비탈 손 표: 토막을 이 길이(칸)들로 차례로 나누고, 조각마다 기울기를 차례로(완만 0.07 ~ 0.15)
SLOPE_RUNS = [4, 6, 3, 5, 7, 4, 2, 6, 5, 3]
SLOPE_GRADS = [0.10, 0.13, 0.08, 0.11, 0.15, 0.09, 0.12, 0.07, 0.14, 0.10]
# 계단 한 켜 높이(손 표) — 조각마다 차례로. 4 넘으면 뛰어올라야 해서 2.5~4
STEP_H = [3.0, 3.5, 2.5, 4.0, 3.0, 2.5, 3.5, 3.0]


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
    """→ 쐐기 [(종류, cx, cy, cz, sx, sy, sz, 돌림)]. 종류 W: 로컬 +Z 가 높다(돌림 = 높은 쪽을 보는 방향의 y 각),
    C: 모서리 쐐기(로컬 (+X,-Z) 꼭짓점이 높다)."""
    def top(i, j):
        if 0 <= i < nx and 0 <= j < ny and g[i][j] is not None:
            return ZONES[g[i][j]][2]
        return None
    # 벽 칸 변: (축, 바깥 방향, 높은 칸 좌표) — 높은 칸 (i,j) 에서 방향 d 로 한 칸 옆이 낮은 땅
    dirs = {(0, 1): "S", (0, -1): "N", (1, 0): "E", (-1, 0): "W"}
    walls = {}
    for i in range(nx):
        for j in range(ny):
            h = top(i, j)
            if h is None:
                continue
            for (di, dj), name in dirs.items():
                lo = top(i + di, j + dj)
                if lo is not None and lo < h:
                    walls.setdefault((name, h, lo), set()).add((i, j))
    pieces = []
    seg_depth = {}  # (높은 칸, 방향) → 깊이(스터드) — 모서리 쐐기용
    k = 0
    for (name, h, lo), cells in walls.items():
        di, dj = {"S": (0, 1), "N": (0, -1), "E": (1, 0), "W": (-1, 0)}[name]
        along = (1, 0) if dj != 0 else (0, 1)
        # 곧은 토막: 벽 줄(같은 j 또는 i)마다 이어진 칸
        lines = {}
        for (i, j) in cells:
            key = j if dj != 0 else i
            lines.setdefault(key, []).append(i if dj != 0 else j)
        for key, idx in lines.items():
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
                p = 0
                while p < len(run):
                    n = SLOPE_RUNS[k % len(SLOPE_RUNS)]
                    grad = SLOPE_GRADS[k % len(SLOPE_GRADS)]
                    k += 1
                    part = run[p:p + n]
                    p += n
                    dh = h - lo
                    want = dh / grad  # 스터드
                    # 낮은 쪽으로 몇 칸까지 같은 낮은 땅인가(조각 폭 전체)
                    fit = 0
                    while fit < 60:
                        ok = True
                        for v in part:
                            ci, cj = (v, key) if dj != 0 else (key, v)
                            ti, tj = ci + di * (fit + 1), cj + dj * (fit + 1)
                            if top(ti, tj) != lo:
                                ok = False
                                break
                        if not ok:
                            break
                        fit += 1
                    depth = min(want, fit * CELL * SCALE)
                    if depth < dh / 0.4:
                        bad.append(f"비탈 {name} {h}->{lo} 줄 {key} 칸 {part[0]}: 자리 {fit}칸 — 너무 가파름({dh / max(depth, 1):.2f})")
                        depth = max(depth, 1)
                    # 계단 켜(사용자: 경사 말고 네모난 블록을 차근차근) — 켜 높이는 손 표(STEP_H)를 조각마다 차례로
                    n = max(2, round(dh / STEP_H[k % len(STEP_H)]))
                    v0, v1 = part[0], part[-1] + 1
                    for st in range(1, n):
                        d = depth * st / n
                        tp = h - dh * st / n
                        if dj != 0:
                            wall_y = Y0 + (key + (1 if dj > 0 else 0)) * CELL
                            (wxa, wz), (wxb, _) = world(X0 + v0 * CELL, wall_y), world(X0 + v1 * CELL, wall_y)
                            box = (wxa, wxb, min(wz - dj * 0.5, wz + dj * d), max(wz - dj * 0.5, wz + dj * d))
                        else:
                            wall_x = X0 + (key + (1 if di > 0 else 0)) * CELL
                            (wx, wza), (_, wzb) = world(wall_x, Y0 + v0 * CELL), world(wall_x, Y0 + v1 * CELL)
                            box = (min(wx - di * 0.5, wx + di * d), max(wx - di * 0.5, wx + di * d), wza, wzb)
                        pieces.append(("B", box, lo - 2, tp, st % 2))
                    for v in (part[0], part[-1]):
                        ci, cj = (v, key) if dj != 0 else (key, v)
                        seg_depth[(ci, cj, name)] = (depth, n)
    # 볼록 모서리: 높은 칸 하나에 두 방향(예: S·E) 벽 계단이 다 있고 대각 칸이 같은 낮은 땅 → 모서리도 계단 켜로 메운다
    corners = 0
    for (ci, cj, a), (da, na) in list(seg_depth.items()):
        for b in ("E", "W") if a in ("S", "N") else ():
            got = seg_depth.get((ci, cj, b))
            if got is None:
                continue
            db, nb = got
            sj = 1 if a == "S" else -1
            si = 1 if b == "E" else -1
            h = top(ci, cj)
            lo1, lo2, lo3 = top(ci, cj + sj), top(ci + si, cj), top(ci + si, cj + sj)
            if not (lo1 == lo2 == lo3) or lo1 is None:
                continue
            vx = X0 + (ci + (1 if si > 0 else 0)) * CELL
            vy = Y0 + (cj + (1 if sj > 0 else 0)) * CELL
            wx, wz = world(vx, vy)
            nc = max(na, nb)
            dh = h - lo1
            for st in range(1, nc):
                ex, ez = db * st / nc, da * st / nc
                tp = h - dh * st / nc
                box = (min(wx - si * 0.5, wx + si * ex), max(wx - si * 0.5, wx + si * ex), min(wz - sj * 0.5, wz + sj * ez), max(wz - sj * 0.5, wz + sj * ez))
                pieces.append(("B", box, lo1 - 2, tp, st % 2))
            corners += 1
    return pieces, corners


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
    print(f"땅 판 {len(tiles)} · 벼랑 {len(cliffs)} · 계단 켜 {len(wedges)}(모서리 {ncorner}곳 포함) · 문제 {len(bad)}건")
