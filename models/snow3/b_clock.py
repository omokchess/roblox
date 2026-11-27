# -*- coding: utf-8 -*-
"""
b_clock.py — 2026-11-14. 설원 마을 3판: 시계탑(광장 가운데 — 이동 탑 · 마을 랜드마크). 아트 부서원 2, B 양식(돌 밑단을 가장 높게).

레퍼런스(회사/설원마을_레퍼런스.md T): 베른 치트글로게(T1·T2 — 길 끝을 막는 탑, 몸 : 시계 단 : 첨탑, 시계판 = 탑 폭의 70%),
치트글로게 천문 시계(T3 — 놋쇠 테 + 짙은 판 + 바늘), 뢰로스 제련소 종탑(T4 — 목조 탑 다리 짜임·받침돌),
뢰로스 교회 탑(T5 — 단마다 들여 좁아지는 탑, 위에서 둘째 단에 시계판, 꼭대기 랜턴 + 뾰족 첨탑).

단(블렌더, 앞 = -y, 원점 = 발자국 가운데 땅). 단마다 벽이 안으로 들고, 그 사이를 잘린 모임지붕(띠지붕·눈)이 덮는다:
  기초 ±10.1 · 0..2
  1단  벽 가운데 ±9.2(바깥 9.8) · 2..22  — 돌 아랫벽 14 까지(바닥 위 12) + 위 뼈대. 1층 방(천장 11) = 이동 탑 자리, 정문 10.4×10
  띠지붕 1(물매 35) · 바닥보 22..22.9
  2단  ±7.5(바깥 8.1) · 22.9..44 — 뼈대 + 판벽, 안은 층 바닥 둘(못 올라감, 창 안은 검은 판)
  띠지붕 2 · 바닥보 44..44.9
  3단  시계 단 ±6.0(바깥 6.6) · 44.9..62 — 네 면 시계판(반지름 4.6, 가운데 높이 53.5)
  지붕  잘린 모임지붕(물매 60) → 평평한 단 ±3.2 → 랜턴(기둥 넷 + 종) → 구리 첨탑(물매 80) → 놋쇠 꼭지 · 쇠 막대 (끝 약 104)
1층 방: 정문 → 앞 빈 바닥 x -5..5 · y -5.4..4.6 → 이동 탑 받침(x -2.5..2.5 · y 4.6..7.6, 위 놋쇠 지도 원판 + 청록 빛) — INFO "teleport"
  왼 뒤 구석: 증기 통 → 관이 뒷벽을 뚫고 나가 바깥면을 타고 2단 기계실로(띠지붕을 뚫음) / 오른 벽: 큰 지도 판
"""
import math

import lib as K
import lib_int1 as P
import lib_b as KB
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_H, WIN_SILL, bx, cbox, CLEAR

NAME = "Sn3_Clock"
PREFIX = "Sn3Clock"
VARIANT = "B"

T = LOG
W1, W2, W3 = 9.2, 7.5, 6.0                # 단마다 벽 가운데 선 반폭
O1, O2, O3 = W1 + T / 2, W2 + T / 2, W3 + T / 2          # 바깥면 9.8 · 8.1 · 6.6
I1 = W1 - T / 2                           # 1단 안쪽 면 8.6
Z1, Z2, Z3 = 22.0, 44.0, 62.0             # 단 벽 윗면
STONE_TO = FZ + 12.0                      # 돌 밑단 높게(레퍼런스 3절 "8" 을 1단 방 천장 위까지 — 단단한 탑 밑동)
CLOCK_Z, CLOCK_R = 53.5, 4.6
COUNTER = (-2.5, 2.5, 5.0, 7.0)           # 이동 탑 받침(카운터 자리) — 2026-11-19 1팀: 뒤 1 을 줄여 뒷벽 톱니 장치 자리를 냄
GEAR16 = (3.4, 8.05, FZ + 5.6)            # 도는 톱니(옛 키트 Gear_16 반지름 4.99 · Gear_10 3.12, 판이 -y 를 봄) 가운데
GEAR10 = (3.4 - 7.21 * 0.9659, 8.05, FZ + 5.6 + 7.21 * 0.2588)     # 맞물림 거리 4.99 + 3.12 - 0.9 = 7.21, 165°
FREE = (-5.0, 5.0, -5.4, 4.6)
TANK = (-6.4, 6.4)


def tier_walls(g, w, z0, z1, holes_fn, stone_to=None, dark=()):
    """한 단 네 벽(frame_wall) + 창. holes_fn(face 이름) → [(u0,u1,z0,z1, 창?)]. dark = 창 안쪽 검은 판을 댈 창 높이 목록"""
    for ax, c, face, tag in (("x", -w, -1, "F"), ("x", w, 1, "B"), ("y", -w, -1, "L"), ("y", w, 1, "R")):
        hs = holes_fn(tag)
        K.frame_wall(g, ax, c, -w, w, z0, z1, [h[:4] for h in hs], stone_to=stone_to, face=face)
        for u0, u1, hz0, hz1, win in hs:
            if not win:
                continue
            K.window(g, ax, c, (u0 + u1) / 2, hz0, w=u1 - u0, h=hz1 - hz0, face=face, shutters=(hz1 - hz0) > 4)
            if hz0 in dark:     # 못 올라가는 층: 창 안 0.9 에 검은 판(안이 어둡게)
                ci = c - face * (T / 2 + 0.9)
                if ax == "x":
                    bx(g, "Soot", u0 - 0.6, u1 + 0.6, ci - 0.1, ci + 0.1, hz0 - 0.6, hz1 + 0.6)
                else:
                    bx(g, "Soot", ci - 0.1, ci + 0.1, u0 - 0.6, u1 + 0.6, hz0 - 0.6, hz1 + 0.6)


def floor_beams(g, z, span, under):
    """단 사이 바닥: 아래 벽 위에서 위 벽 밑을 받치는 보 넷(x·y 방향, 위 단 벽 가운데 선 under) + 바닥 판"""
    for s in (-1, 1):
        bx(g, "DarkLog", -span, span, s * under - 0.6, s * under + 0.6, z, z + 0.9)
        bx(g, "DarkLog", s * under - 0.6, s * under + 0.6, -span, span, z, z + 0.9)
    bx(g, "Timber", -under + 0.6, under - 0.6, -under + 0.6, under - 0.6, z + 0.55, z + 0.9)


def tier1(g):
    win_lo = lambda: (-WIN_W / 2, WIN_W / 2, FZ + WIN_SILL, FZ + WIN_SILL + WIN_H, True)     # noqa: E731
    win_hi = lambda: (-1.4, 1.4, 16.0, 20.0, True)                                        # noqa: E731

    def holes(tag):
        out = [win_hi()]
        if tag == "F":
            out.append((-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H, False))
        elif tag in ("L", "B"):
            out.append(win_lo())
        return out
    tier_walls(g, W1, FZ, Z1, holes, stone_to=STONE_TO, dark=(16.0,))
    K.door_open(g, "x", -W1, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)
    # 1층 방 천장: 보 셋(x 방향) + 판 — 2층 바닥
    zc = FZ + CEIL
    for y in (-4.3, 0.0, 4.3):
        bx(g, "DarkLog", -I1, I1, y - 0.5, y + 0.5, zc, zc + 0.9)
    bx(g, "Timber", -I1, I1, -I1, I1, zc + 0.9, zc + 1.2)


def room(g):
    """1층: 이동 탑 받침(큰 덩어리 하나) · 증기 통 · 오른 벽 지도 판 · 등"""
    x0, x1, y0, y1 = COUNTER
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    K.box2(g, "Stone", x0, x1, y0, y1, FZ, FZ + 2.6)
    bx(g, "StoneTrim", x0 - 0.2, x1 + 0.2, y0 - 0.2, y1 + 0.2, FZ, FZ + 0.4)
    bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, FZ + 2.6, FZ + 2.9)
    zt = FZ + 2.9
    g["Brass"].cyl(cx, cy, zt, 1.45, 1.45, 0.35, seg=28)               # 지도 원판(놋쇠 테) — 받침 깊이 2 안
    g["Dial"].cyl(cx, cy, zt + 0.35, 1.25, 1.25, 0.1, seg=28)
    for k, (dx, dy) in enumerate(((-0.7, 0.35), (0.45, 0.65), (0.8, -0.45), (-0.3, -0.65), (0.0, 0.0))):   # 이동 자리 빛 점
        g["GlowTeal"].cyl(cx + dx, cy + dy, zt + 0.45, 0.2, 0.2, 0.12, seg=8)
    # 위 놋쇠 고리(아스트롤라베) — 받침 뒤 기둥 둘이 받침
    for s in (-1, 1):
        bx(g, "Iron", cx + s * 2.3 - 0.15, cx + s * 2.3 + 0.15, y1 - 0.5, y1 - 0.2, zt, zt + 4.0)
    for k in range(20):                               # 고리(바깥 2.45 · 안 1.85) — 뒤 톱니 맞물림이 고리 안으로 보인다(비평 1차)
        a = 2 * math.pi * (k + 0.5) / 20
        g["Brass"].obox(cx + 2.15 * math.cos(a), y1 - 0.35, zt + 3.6 + 2.15 * math.sin(a), 0.71, 0.22, 0.6, ry=-a + math.pi / 2)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        g["Iron"].obox(cx + 1.15 * math.cos(a), y1 - 0.3, zt + 3.6 + 1.15 * math.sin(a), 1.5, 0.14, 0.18, ry=-a)
    K.S.gear(g, "Brass", cx, y1 - 0.4, zt + 3.6, 0.6, 10, 0.2)
    bx(g, "Iron", cx - 2.3, cx + 2.3, y1 - 0.42, y1 - 0.28, zt + 3.5, zt + 3.7)
    g["LampPt"].box(cx, cy, zt + 1.4, 0.3, 0.3, 0.3)
    cbox(x0 - 0.2, x1 + 0.2, y0 - 0.2, y1, FZ, FZ + 3.4)
    # 왼 뒤 증기 통 → 관: 뒷벽을 뚫고 나가 바깥면을 타고 올라 2단 기계실로
    tx, ty = TANK
    K.steam_bundle(g, tx, ty, FZ, h=6.0, r=1.1, gauge_face=-1, vent=False,        # 방 안 — 김 빼기(holes.py 김 검사)
                   pipe_pts=[(tx, ty + 1.1, FZ + 4.6), (tx, O1 + 0.5, FZ + 4.6), (tx, O1 + 0.5, 30.0), (tx, O2 - 0.4, 30.0)])
    for z in (FZ + 8.0, 15.0, 19.0, 26.0):          # 관 띠쇠(벽에 박음 — 2단 쪽은 띠지붕 위 2단 벽까지)
        yw = O1 if z < Z1 else O2
        bx(g, "Iron", tx - 0.45, tx + 0.45, yw, O1 + 0.9, z - 0.12, z + 0.12)
    # 오른 벽 큰 지도 판(마을·지역 — 큰 덩어리)
    bx(g, "Timber", I1 - 0.3, I1, -4.5, 3.5, FZ + 2.8, FZ + 8.4)
    bx(g, "Canvas", I1 - 0.4, I1 - 0.3, -4.1, 3.1, FZ + 3.2, FZ + 8.0)
    for dy, dz, w, h, m in ((-2.0, 5.0, 2.4, 1.6, "PaintGreen"), (1.0, 6.3, 1.8, 1.2, "PaintGreen"), (-0.5, 4.2, 1.2, 0.8, "Glass")):
        bx(g, m, I1 - 0.45, I1 - 0.4, dy - w / 2, dy + w / 2, FZ + dz - h / 2, FZ + dz + h / 2)
    g["SignRed"].hcyl(I1 - 0.48, 0.2, FZ + 5.5, 0.22, 0.06, axis="x", seg=8)
    for x, y in ((-4.5, -4.3), (4.5, -4.3), (0.0, 0.0)):        # 천장 보(y -4.3 · 0)에 매닮
        K.lantern(g, x, y, FZ + CEIL, FZ + 8.4)
    clockwork(g)


def clockwork(g):
    """뒷벽 시계 장치(문에서 이동 받침 너머로 보이는 초점, 레퍼런스 T3·TI1~TI3): 도는 톱니 둘(PROP — Studio 가 돌림) · 뒤 쇠 틀판 ·
    오른 구석 세로 굴대(천장을 뚫고 시계 단으로) + 누운 맞물림 톱니 · 왼 위 놋쇠 톱니 무리(고정) · 추(흔들이) · 대기 긴 의자 둘 · 바닥 놋쇠 고리 · 벽등"""
    K.I.PROP("Gear_16", *GEAR16, 0.0, 1.0, speed=12)
    K.I.PROP("Gear_10", *GEAR10, 0.0, 1.0, speed=-19.2)
    for (x, y, z), r in ((GEAR16, 4.99), (GEAR10, 3.12)):           # 축받이: 벽에 박은 쇠 판 + 놋쇠 통(톱니 뒤)
        bx(g, "Iron", x - 0.9, x + 0.9, I1 - 0.08, I1, z - 0.9, z + 0.9)
        g["Brass"].hcyl(x, y + 0.6, z, 0.4, 0.4, axis="y", seg=10)
        for a in range(4):                                         # 쇠 틀(벽 판 → 축받이 버팀 넷)
            aa = a * math.pi / 2 + math.pi / 4
            g["Iron"].obox(x + 0.75 * math.cos(aa), I1 - 0.05, z + 0.75 * math.sin(aa), 0.22, 0.1, 1.0, ry=-aa)
    sx, sy = 7.9, 7.0                                              # 세로 굴대(바닥 상자 → 천장)
    bx(g, "Iron", sx - 0.6, sx + 0.6, sy - 0.6, sy + 0.6, FZ, FZ + 1.4)
    bx(g, "Brass", sx - 0.65, sx + 0.65, sy - 0.65, sy + 0.65, FZ + 1.4, FZ + 1.55)
    g["Steel"].cyl(sx, sy, FZ + 1.55, 0.2, 0.2, CEIL - 1.55 + 1.2, seg=8)
    for z in (FZ + 3.2, FZ + 8.2, FZ + 10.6):
        g["Brass"].cyl(sx, sy, z, 0.32, 0.32, 0.25, seg=8)
        bx(g, "Iron", sx - 0.12, sx + 0.12, sy, I1, z - 0.1, z + 0.35)        # 굴대 받침 팔(뒷벽에 박음)
    K.S.gear(g, "Brass", sx, sy, FZ + 5.6, 0.9, 10, 0.25, axis="z")
    for x, z, r, n, m in ((-6.9, FZ + 9.6, 1.25, 12, "Brass"), (-5.2, FZ + 10.3, 0.7, 8, "Copper"), (-7.4, FZ + 7.9, 0.6, 8, "Brass")):
        K.S.gear(g, m, x, I1 - 0.25, z, r, n, 0.2)
        g["Iron"].hcyl(x, I1 - 0.15, z, 0.18, 0.3, axis="y", seg=6)
    # 추(흔들이): 천장 판 → 쇠 막대 → 놋쇠 추(앞을 보는 원판 두 겹)
    px, py = -4.0, 5.8
    bx(g, "Iron", px - 0.3, px + 0.3, py - 0.3, py + 0.3, FZ + CEIL + 0.6, FZ + CEIL + 0.9)
    bx(g, "Brass", px - 0.15, px + 0.15, py - 0.15, py + 0.15, FZ + 4.3, FZ + CEIL + 0.1)        # 놋쇠 막대 0.3 각(비평 사소 7: 가는 선)
    bx(g, "Iron", px - 0.6, px + 0.6, py - 0.2, py + 0.2, FZ + CEIL + 0.1, FZ + CEIL + 0.6)      # 매다는 쇠 받침(칼날 받침 + 볼 둘)
    for e in (-1, 1):
        bx(g, "Iron", px + e * 0.45 - 0.1, px + e * 0.45 + 0.1, py - 0.3, py + 0.3, FZ + CEIL - 0.3, FZ + CEIL + 0.1)
    g["Brass"].hcyl(px, py, FZ + 3.6, 0.85, 0.3, axis="y", seg=16)
    g["Iron"].hcyl(px, py - 0.18, FZ + 3.6, 0.55, 0.06, axis="y", seg=16)
    # 대기 긴 의자(왼 벽 · 오른 벽 앞 — 오른 벽 지도 판 밑은 비움)
    P.wall_bench(g, -I1, -1, -7.6, -2.6, FZ)
    P.wall_bench(g, I1, 1, -8.1, -5.0, FZ)
    # 바닥 놋쇠 고리(이동 탑 길잡이) · 앞벽 벽등 둘
    for i in range(4):                                     # 큰 돌판 두 톤(4.3, 높이 0.05 — 충돌 없음, 비평 1차 맨바닥)
        for j in range(4):
            bx(g, "Stone" if (i + j) % 2 else "DarkStone", -I1 + i * 4.3, -I1 + (i + 1) * 4.3, -I1 + j * 4.3, -I1 + (j + 1) * 4.3, FZ, FZ + 0.05)
    K.S.ring(g, "Brass", 0.0, -0.4, FZ + 0.05, 3.6, 3.9, 0.03, n=24)
    # 시계판 꼴(비평 사소 6: 은행 금고실과 같은 8살 바퀴 → 살 빼고 눈금 12 · 바늘 둘(3.0 / 2.2) · 가운데 꼭지)
    for k in range(12):
        th = k * math.pi / 6
        g["Brass"].obox(3.0 * math.sin(th), -0.4 + 3.0 * math.cos(th), FZ + 0.065, 0.4, 1.0 if k % 3 == 0 else 0.6, 0.03, rz=-th)
    for th, ln in ((math.pi / 3, 3.0), (-math.pi / 3, 2.2)):                                 # 분침(2시) · 시침(10시)
        g["Iron"].obox(ln / 2 * math.sin(th), -0.4 + ln / 2 * math.cos(th), FZ + 0.068, 0.4, ln, 0.035, rz=-th)
    g["Brass"].cyl(0.0, -0.4, FZ + 0.05, 0.35, 0.35, 0.06, seg=12)
    for x in (-7.0, 7.0):
        P.sconce(g, "x", -I1, x, FZ + 7.4, face=1)
    # 문 옆 행선지 판(앞벽 안쪽, 문 왼쪽): 짙은 틀 · 검은 판 · 행선지 패 다섯 줄 + 놋쇠 화살 · 위 놋쇠 머리판(비평 1차: 앞벽이 휑함)
    yf = -I1
    bx(g, "Timber", -8.3, -5.7, yf, yf + 0.2, FZ + 2.6, FZ + 6.3)
    bx(g, "Char", -8.1, -5.9, yf + 0.2, yf + 0.25, FZ + 2.8, FZ + 6.1)
    for k in range(5):
        z = FZ + 3.0 + k * 0.62
        bx(g, "Paint", -7.95, -6.75, yf + 0.25, yf + 0.3, z, z + 0.4)
        bx(g, ("SignTeal", "SignGold", "SignRed", "PaintGreen", "SignBlue")[k], -6.65, -6.45, yf + 0.25, yf + 0.31, z + 0.05, z + 0.35)
        g["Brass"].obox(-6.2, yf + 0.29, z + 0.2, 0.32, 0.05, 0.12, ry=0.0)
        g["Brass"].obox(-6.0, yf + 0.29, z + 0.2, 0.14, 0.05, 0.14, ry=0.785)
    bx(g, "Brass", -8.4, -5.6, yf, yf + 0.3, FZ + 6.3, FZ + 6.55)


def tier2(g):
    def holes(tag):
        return [(-1.4, 1.4, 26.5, 30.5, True), (-1.4, 1.4, 35.5, 39.5, True)]
    tier_walls(g, W2, Z1 + 0.9, Z2, holes, dark=(26.5, 35.5))
    zm = 33.3                                       # 2단 가운데 층 바닥
    for y in (-3.0, 3.0):
        bx(g, "DarkLog", -W2 + 0.6, W2 - 0.6, y - 0.45, y + 0.45, zm - 0.8, zm)
    bx(g, "Timber", -W2 + 0.6, W2 - 0.6, -W2 + 0.6, W2 - 0.6, zm, zm + 0.3)


def tier3(g):
    """시계 단: 판벽 네 면 + 시계판 넷 + 단 밑 놋쇠 띠"""
    tier_walls(g, W3, Z2 + 0.9, Z3, lambda tag: [])
    bx(g, "Brass", -O3 - 0.1, O3 + 0.1, -O3 - 0.1, O3 + 0.1, Z2 + 0.9, Z2 + 1.25)
    faces = []
    for ax, c, face, name in (("x", -O3, -1, "-y"), ("x", O3, 1, "+y"), ("y", -O3, -1, "-x"), ("y", O3, 1, "+x")):
        p = KB.clock_face(g, ax, c, 0.0, CLOCK_Z, CLOCK_R, face)
        faces.append((round(p[0], 2), round(p[1], 2), round(p[2], 2), name, CLOCK_R))
    return faces


def top(g):
    """잘린 모임지붕 → 평평한 단(판·눈) → 랜턴 기둥 넷 + 테 보 + 종 → 구리 첨탑 → 놋쇠 꼭지 · 쇠 막대"""
    cut = O3 - 3.2
    zd, zb = KB.hip_roof(g, O3, O3, Z3, 60.0, eave=1.4, cut=cut)
    # 단 판(지붕 윗면 높이) + 눈
    zt = zd + (0.9 + 0.75) / math.cos(math.radians(60.0))
    bx(g, "DarkLog", -3.3, 3.3, -3.3, 3.3, zd, zt)
    bx(g, "SnowCap", -3.3, 3.3, -3.3, 3.3, zt, zt + 0.4)
    zl0, zl1 = zt + 0.4, zt + 7.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.post(g, sx * 2.6, sy * 2.6, zl0, zl1, s=0.8, coll=False)
    for s in (-1, 1):                                  # 랜턴 중간 띠(기둥 사이를 잡는 가로대) + 놋쇠 난간살
        bx(g, "DarkLog", -2.9, 2.9, s * 2.6 - 0.3, s * 2.6 + 0.3, zl0 + 1.0, zl0 + 1.7)
        bx(g, "DarkLog", s * 2.6 - 0.3, s * 2.6 + 0.3, -2.9, 2.9, zl0 + 1.0, zl0 + 1.7)
    for s in (-1, 1):
        bx(g, "DarkLog", -3.1, 3.1, s * 2.6 - 0.45, s * 2.6 + 0.45, zl1, zl1 + 0.9)
        bx(g, "DarkLog", s * 2.6 - 0.45, s * 2.6 + 0.45, -3.1, 3.1, zl1, zl1 + 0.9)
    bx(g, "DarkLog", -2.6, 2.6, -0.35, 0.35, zl1 - 0.2, zl1 + 0.5)          # 종 거는 보
    bx(g, "Iron", -0.1, 0.1, -0.1, 0.1, zl1 - 1.4, zl1 - 0.2)
    g["Brass"].cyl(0, 0, zl1 - 3.4, 1.35, 0.55, 2.0, seg=16)               # 종
    g["Brass"].cyl(0, 0, zl1 - 3.55, 1.45, 1.45, 0.2, seg=16)
    g["Iron"].cyl(0, 0, zl1 - 3.9, 0.22, 0.22, 0.8, seg=8)
    # 구리 첨탑
    zs0 = zl1 + 0.9
    ztip, zb2 = KB.hip_roof(g, 3.1, 3.1, zl1, 80.0, eave=1.3, snow=False, cover="Copper")
    bx(g, "Brass", -0.5, 0.5, -0.5, 0.5, ztip - 0.6, ztip + 0.9)
    g["Brass"].cyl(0, 0, ztip + 0.9, 0.7, 0.7, 0.3, seg=12)
    g["Brass"].cyl(0, 0, ztip + 1.2, 0.75, 0.2, 1.0, seg=12)
    g["Iron"].cyl(0, 0, ztip + 2.2, 0.12, 0.08, 5.6, seg=8)
    K.S.gear(g, "Brass", 0, 0, ztip + 5.0, 0.9, 10, 0.18)                  # 꼭지 톱니(슈네라이히 표지)
    g["Brass"].cyl(0, 0, ztip + 7.8, 0.3, 0.05, 0.6, seg=8)
    return zs0, ztip + 8.4


FACES = []


def build(g):
    K.foundation(g, -O1 - 0.3, O1 + 0.3, -O1 - 0.3, O1 + 0.3)
    K.stair(g, 0.0, -O1 - 0.3, 12.0, FZ)
    tier1(g)
    room(g)
    floor_beams(g, Z1, O1, W2)
    KB.hip_roof(g, O1, O1, Z1, 35.0, eave=1.2, cut=O1 - O2)
    tier2(g)
    floor_beams(g, Z2, O2, W3)
    KB.hip_roof(g, O2, O2, Z2, 35.0, eave=1.2, cut=O2 - O3)
    FACES[:] = tier3(g)
    top(g)
    CLEAR(-5.0, 5.0, -I1 + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.2, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((0.0, -W1 - 1.5), (0.0, -1.0)),
    "inside": (-I1, I1, -W1 - T / 2 - 1.5, I1),
    "forge_look": (0.0, 6.5),
    "plan_scale": 30,
    # 순간이동 UI 자리(받침 위 지도 원판 가운데) — 블렌더 좌표, 로블록스 로컬 = (-x, z, y)
    "teleport": (0.0, 6.0, FZ + 3.35),
    # 시계 바늘 달 자리: (판 가운데 x, y, z, 바라보는 쪽, 반지름) — 블렌더 좌표. 메시에 10:10 고정 바늘이 그려져 있다(Studio 바늘을 달면 메시 바늘은 Iron 덩이에서 지울 것)
    "clock_faces": [(0.0, -O3 - 1.15, CLOCK_Z, "-y", CLOCK_R), (0.0, O3 + 1.15, CLOCK_Z, "+y", CLOCK_R),
                    (-O3 - 1.15, 0.0, CLOCK_Z, "-x", CLOCK_R), (O3 + 1.15, 0.0, CLOCK_Z, "+x", CLOCK_R)],
    "extra_views": [
        ("tall34", (-62, -80, 52), (0, 0, 50), 22, None),
        ("fp_up30", (0, -O1 - 30, 4.5), (0, 0, 55), 17, None),
        ("fp_up80", (0, -O1 - 80, 4.5), (0, 0, 52), 17, None),
        ("far", (-120, -190, 30), (0, 0, 50), 35, None),
        ("back_tall", (60, 75, 40), (0, 0, 50), 22, None),
    ],
}
