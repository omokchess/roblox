# -*- coding: utf-8 -*-
"""
snow3_ground.py — 2026-10-09. 설원 3판 지상 땅 → tools/Snow3_Ground_data.luau

구역·높이 = snow3_plan.py(사용자 승인: "높이는 그대로, 어긋난 칸 없음"). 기운 변은 사용자 말대로 "블록을 크게 놓아 보정":
  구역 다각형을 그림 10px(= 37 스터드) 칸으로 나눠 칸 가운데가 든 구역에 주고, 같은 구역 칸을 큰 직사각형으로 묶는다(계단식).
바닷가: 섬 바깥 변(칸 경계)을 곧은 토막으로 이어, 토막마다 바위 벼랑. 높이·깊이는 손 표(CLIFF_STYLE)를 차례로 돌려 쓴다.
오르막: 단 사이, 벽 바로 바깥을 따라 길게(사용자 규칙) — RAMPS 손 표(그림 좌표).
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
RAMPS = [
    ("남서 필드→마을(남벽 따라 서쪽)", (378, 1174), (274, 1174), 20, 60, 28),
    ("남서 필드→보스룸(서벽 따라 북쪽)", (396, 1300), (396, 1215), 20, 40, 26),
    ("북쪽 들→마을(동벽 따라 북쪽)", (384, 1120), (384, 1045), 32, 60, 24),
    ("북쪽 들→보스룸(북벽 따라 동쪽)", (420, 1094), (520, 1094), 32, 40, 24),
    ("북쪽 들→북동 들(서벽 따라 북쪽)", (586, 1085), (586, 990), 32, 44, 24),
    ("남서 필드→북동 들(서벽 따라 북쪽)", (636, 1355), (636, 1285), 20, 44, 26),
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
    return tiles, cliffs, ramps, bad


if __name__ == "__main__":
    tiles, cliffs, ramps, bad = main()
    for p in bad[:30]:
        print("문제:", p)
    out = ["-- snow3_ground.py 가 만든 자료(손으로 고치지 말 것)", "local TILES = {"]
    out += [f'\t{{ "{n}", {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t} }},' for n, a, b, c, d, t in tiles]
    out += ["}", "local CLIFFS = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t:.1f} }}," for a, b, c, d, t in cliffs]
    out += ["}", "local RAMPS = {"]
    out += [f'\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {h0}, {h1}, {w}, "{n}" }},' for a, b, c, d, h0, h1, w, n in ramps]
    out += ["}"]
    open(os.path.join(HERE, "Snow3_Ground_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"땅 판 {len(tiles)} · 벼랑 {len(cliffs)} · 오르막 {len(ramps)} · 문제 {len(bad)}건")
