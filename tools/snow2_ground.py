# -*- coding: utf-8 -*-
"""
snow2_ground.py — 2026-10-09. 설원 리메이크 1단계: 땅(단 높이)·바닷가·오르막 → tools/Snow2_Ground_data.luau

사용자 그림(설원 지도.jpg)을 격자 위에 놓고(그림 x-100, y-880 = 아래 '그림 좌표') 덩어리를 땄다. 그림은 비스듬히 본 그림이라
땅이 여러 단이다: 마을 고원(북서) · 보스룸 단(가운데) · 북동 고원(휴식처·옛 설공방 폐허) · 낮은 필드(동굴 입구 1·2) ·
동쪽 히든 보스 메사(지하·3번 입구로만 — 오르막 없음). 축에 맞춘 상자(맵 규칙)로 옮긴다.
축척(사용자: 설원 ≈ 숲 크기): 그림 1px = SCALE 스터드. 월드 = ORIGIN + 그림 좌표 × SCALE.
  TILES   땅 덩어리 { 이름, x0, z0, x1, z1, 윗면 높이 } (그림 좌표)
  COAST   바깥 변마다 바위 벼랑 토막 (길이 px, 높이(땅 위), 깊이 스터드) — 손으로
  RAMPS   단 사이 오르막: 벽 따라 길게(사용자 규칙) { 이름, 시작(x,z), 끝(x,z), 시작 높이, 끝 높이, 폭 스터드 }
돌리기: python tools/snow2_ground.py (문제 0건) → 짓기: tools/Snow2_Build.luau 머리 주석
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 2.9
ORIGIN = (-5450, -4050)

FIELD, TOWN, BOSS, NE, HIDDEN = 20, 60, 40, 72, 150
TILES = [
    ("마을 고원", 30, 30, 370, 250, TOWN),
    ("북쪽 들", 370, 30, 520, 250, FIELD),
    ("보스룸 단", 300, 250, 520, 400, BOSS),
    ("북동 고원", 520, 100, 810, 400, NE),
    ("서쪽 필드", 20, 250, 300, 600, FIELD),
    ("남쪽 필드", 300, 400, 780, 600, FIELD),
    ("동쪽 필드(3번 입구)", 780, 500, 920, 600, FIELD),
    ("히든 메사", 860, 160, 1060, 300, HIDDEN),
]
# 본 땅 바깥 윤곽(시계 방향, 그림 좌표) — TILES 합집합(히든 메사 빼고)
OUTLINE = [(30, 30), (520, 30), (520, 100), (810, 100), (810, 400), (780, 400), (780, 500), (920, 500), (920, 600), (20, 600), (20, 250), (30, 250)]
MESA = [(860, 160), (1060, 160), (1060, 300), (860, 300)]
# 바닷가: 변 번호 → (길이 px | None=나머지, 벼랑 높이(그 땅 위), 깊이 스터드)
COAST = {
    0: [(120, 14, 28), (150, 22, 32), (None, 10, 26)],      # 북쪽(마을·북쪽 들)
    1: [(None, 18, 28)],
    2: [(100, 12, 26), (110, 20, 30), (None, 8, 24)],        # 북동 고원 북
    3: [(90, 16, 28), (110, 24, 32), (None, 12, 26)],        # 북동 고원 동
    4: [(None, 6, 24)],
    5: [(None, 8, 24)],
    6: [(None, 10, 26)],
    7: [(None, 12, 26)],                                      # 3번 입구 동쪽
    8: [(200, 6, 24), (220, 10, 26), (220, 4, 22), (None, 8, 24)],  # 남쪽
    9: [(120, 10, 26), (None, 16, 28)],                       # 서쪽
    10: [(None, 8, 24)],
    11: [(80, 12, 26), (None, 20, 30)],                       # 마을 서쪽
}
MESA_COAST = {0: [(None, 30, 34)], 1: [(None, 36, 36)], 2: [(None, 26, 32)], 3: [(None, 32, 34)]}
# 오르막 { 이름, (x,z) 시작, (x,z) 끝, 시작 높이, 끝 높이, 폭 } — 그림 좌표, 벽 바로 바깥을 따라
RAMPS = [
    ("필드→마을(남벽)", (290, 260), (110, 260), FIELD, TOWN, 26),
    ("북쪽 들→마을(동벽)", (378, 230), (378, 70), FIELD, TOWN, 24),
    ("필드→보스룸(서벽)", (292, 395), (292, 290), FIELD, BOSS, 24),
    ("필드→북동 고원(남벽)", (770, 408), (560, 408), FIELD, NE, 26),
]
# 표시(나중 단계 자리): 입구·폐허·휴식처 { 이름, x, z }
SPOTS = [("동굴 입구 1", 590, 455), ("동굴 입구 2", 170, 455), ("3번 입구", 885, 585), ("(구)설공방 폐허", 715, 225), ("순례자의 휴식처 2/8", 575, 245)]


def W(x, z):
    return ORIGIN[0] + x * SCALE, ORIGIN[1] + z * SCALE


def inside(pt, poly):
    x, z = pt
    hit = False
    for i in range(len(poly)):
        (ax, az), (bx, bz) = poly[i], poly[(i + 1) % len(poly)]
        if (az > z) != (bz > z) and x < ax + (z - az) * (bx - ax) / (bz - az):
            hit = not hit
    return hit


def tile_top(x, z):
    for name, x0, z0, x1, z1, top in TILES:
        if x0 <= x <= x1 and z0 <= z <= z1:
            return top
    return None


def coast(poly, table, bad, label):
    cliffs = []
    n = len(poly)
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    for i in range(n):
        (ax, az), (bx, bz) = poly[i], poly[(i + 1) % n]
        L = abs(bx - ax) + abs(bz - az)
        ux, uz = (bx - ax) / L, (bz - az) / L
        ox, oz = -uz, ux
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        if inside((mx + ox, mz + oz), poly):
            ox, oz = -ox, -oz

        def convex(k):
            p, q, r = poly[k - 1], poly[k], poly[(k + 1) % n]
            cr = (q[0] - p[0]) * (r[1] - q[1]) - (q[1] - p[1]) * (r[0] - q[0])
            return (cr > 0) == (area > 0)

        segs = table[i]
        fixed = sum(s[0] for s in segs if s[0] is not None)
        rest = L - fixed
        if any(s[0] is None for s in segs) and rest < 10:
            bad.append(f"{label} 변 {i}: 남는 길이 {rest}")
        t = 0.0
        for k, (ln, h, depth) in enumerate(segs):
            ln = rest if ln is None else ln
            s0, s1 = t * SCALE, (t + ln) * SCALE
            t += ln
            e0, e1 = s0, s1
            if k == 0 and convex(i):
                e0 -= depth
            if k == len(segs) - 1 and convex((i + 1) % n):
                e1 += depth
            wax, waz = W(ax, az)
            p0 = (wax + ux * e0 - ox * 2, waz + uz * e0 - oz * 2)
            p1 = (wax + ux * e1 + ox * depth, waz + uz * e1 + oz * depth)
            # 이 토막 안쪽 땅 높이
            gx, gz = ax + ux * (t - ln / 2) - ox * 3, az + uz * (t - ln / 2) - oz * 3
            top = (tile_top(gx, gz) or FIELD) + h
            cliffs.append((min(p0[0], p1[0]), max(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[1], p1[1]), top))
    return cliffs


def main():
    bad = []
    # 덩어리 겹침
    for i, a in enumerate(TILES):
        for b in TILES[i + 1:]:
            if a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]:
                bad.append(f"겹침 {a[0]} / {b[0]}")
    # 윤곽 안이 덩어리로 다 덮이나(10px 격자)
    for x in range(25, 920, 10):
        for z in range(35, 600, 10):
            if inside((x + 0.3, z + 0.3), OUTLINE) and tile_top(x + 0.3, z + 0.3) is None:
                bad.append(f"윤곽 안 빈 곳 ({x},{z})")
                break
    cliffs = coast(OUTLINE, COAST, bad, "본섬") + coast(MESA, MESA_COAST, bad, "메사")
    ramps = []
    for name, (sx, sz), (ex, ez), h0, h1, w in RAMPS:
        L = math.hypot(ex - sx, ez - sz) * SCALE
        if abs(h1 - h0) / L > 0.35:
            bad.append(f"{name}: 기울기 {abs(h1 - h0) / L:.2f}")
        # 시작은 낮은 땅 위, 끝은 높은 땅 가장자리 바로 바깥
        if tile_top(sx, sz) != h0:
            bad.append(f"{name}: 시작 땅 높이 {tile_top(sx, sz)} ≠ {h0}")
        ramps.append((*W(sx, sz), *W(ex, ez), h0, h1, w, name))
    tiles = []
    for name, x0, z0, x1, z1, top in TILES:
        wx0, wz0 = W(x0, z0)
        wx1, wz1 = W(x1, z1)
        tiles.append((name, wx0, wz0, wx1, wz1, top))
        if max(wx1 - wx0, wz1 - wz0) > 2048:
            bad.append(f"{name} 가 2048 넘음")
    return tiles, cliffs, ramps, bad


if __name__ == "__main__":
    tiles, cliffs, ramps, bad = main()
    for p in bad[:30]:
        print("문제:", p)
    out = ["-- snow2_ground.py 가 만든 자료(손으로 고치지 말 것)", "local TILES = {"]
    out += [f'\t{{ "{n}", {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t} }},' for n, a, b, c, d, t in tiles]
    out += ["}", "local CLIFFS = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t:.1f} }}," for a, b, c, d, t in cliffs]
    out += ["}", "local RAMPS = {"]
    out += [f'\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {h0}, {h1}, {w}, "{n}" }},' for a, b, c, d, h0, h1, w, n in ramps]
    out += ["}", "local SPOTS = {"]
    out += [f'\t{{ "{n}", {W(x, z)[0]:.1f}, {W(x, z)[1]:.1f} }},' for n, x, z in SPOTS]
    out += ["}"]
    open(os.path.join(HERE, "Snow2_Ground_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    xs = [t[1] for t in tiles] + [t[3] for t in tiles]
    zs = [t[2] for t in tiles] + [t[4] for t in tiles]
    print(f"땅 {len(tiles)} · 벼랑 {len(cliffs)} · 오르막 {len(ramps)} · 범위 x {min(xs):.0f}~{max(xs):.0f} z {min(zs):.0f}~{max(zs):.0f} · 문제 {len(bad)}건")
