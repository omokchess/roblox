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
FREE = (-5.0, 5.0, -5.4, 4.6)
TANK = (-6.4, 6.4)


def tier_walls(g, w, z0, z1, holes_fn, stone_to=None):
    """한 단 네 벽(frame_wall) + 창. holes_fn(face 이름) → [(u0,u1,z0,z1, 창?)].
    (2026-11-28) 창 안 검은 판을 뺐다 — 창 안팎 짝: 위 단 창으로는 다락 안 시계 굴대(drive_train)가 보인다"""
    for ax, c, face, tag in (("x", -w, -1, "F"), ("x", w, 1, "B"), ("y", -w, -1, "L"), ("y", w, 1, "R")):
        hs = holes_fn(tag)
        K.frame_wall(g, ax, c, -w, w, z0, z1, [h[:4] for h in hs], stone_to=stone_to, face=face)
        for u0, u1, hz0, hz1, win in hs:
            if not win:
                continue
            K.window(g, ax, c, (u0 + u1) / 2, hz0, w=u1 - u0, h=hz1 - hz0, face=face, shutters=(hz1 - hz0) > 4)


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
    tier_walls(g, W1, FZ, Z1, holes, stone_to=STONE_TO)
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
    # (2026-11-28 사용자 4차: 용도 모를 기계 금지) 순간이동 지도대 — 놋쇠 테 원판 위 바다 · 섬 셋(초록 + 눈 덮인 봉우리) · 가는 곳 핀(놋쇠 대 + 청록 보석) ·
    # 테 눈금 열여섯 · 북쪽 화살. 옛 '놋쇠 고리 + 톱니'(아스트롤라베)는 무엇인지 안 읽혀 뺐다
    g["Brass"].cyl(cx, cy, zt, 1.45, 1.45, 0.35, seg=28)
    g["Dial"].cyl(cx, cy, zt + 0.35, 1.3, 1.3, 0.08, seg=28)
    g["SignBlue"].cyl(cx, cy, zt + 0.43, 1.12, 1.12, 0.06, seg=28)
    for k in range(16):
        a = 2 * math.pi * k / 16
        g["Iron"].obox(cx + 1.37 * math.cos(a), cy + 1.37 * math.sin(a), zt + 0.4, 0.14, 0.14 if k % 4 else 0.3, 0.1, rz=a + math.pi / 2)
    isles = ([(-0.95, -0.25), (-0.4, -0.6), (0.05, -0.35), (-0.05, 0.15), (-0.7, 0.35)],
             [(0.35, 0.25), (0.85, 0.1), (0.95, 0.5), (0.6, 0.8), (0.3, 0.65)],
             [(0.3, -0.85), (0.7, -0.75), (0.6, -0.45), (0.3, -0.5)])
    for pts in isles:
        P.prism(g, "PaintGreen", [(cx + u, cy + v) for u, v in pts], zt + 0.49, zt + 0.62)
        mu, mv = sum(u for u, v in pts) / len(pts), sum(v for u, v in pts) / len(pts)
        P.prism(g, "SnowCap", [(cx + mu + (u - mu) * 0.45, cy + mv + (v - mv) * 0.45) for u, v in pts], zt + 0.62, zt + 0.72)
    for dx, dy in ((-0.65, -0.2), (-0.15, -0.05), (0.62, 0.45), (0.5, -0.65), (-0.45, 0.18)):     # 가는 곳 핀
        bx(g, "Brass", cx + dx - 0.07, cx + dx + 0.07, cy + dy - 0.07, cy + dy + 0.07, zt + 0.62, zt + 0.86)
        g["GlowTeal"].obox(cx + dx, cy + dy, zt + 0.97, 0.2, 0.2, 0.2, rz=0.785)
    g["Brass"].obox(cx - 0.95, cy + 0.85, zt + 0.52, 0.16, 0.5, 0.1, rz=-0.7)                     # 북쪽 화살(테 안 왼 뒤)
    g["SignRed"].obox(cx - 0.8, cy + 1.0, zt + 0.52, 0.24, 0.24, 0.12, rz=0.08)
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


MOV = (5.4, I1, 4.6, I1)                  # 탑시계 기계(무브먼트) 자리 x0 x1 y0 y1 — 오른 뒤 구석
SHAFT = (8.3, 6.5)                        # 기계 → 천장 → 다락 → 시계 단으로 오르는 굴대(블렌더 x, y)
ZB = FZ + 2.4                             # 기계 받침 윗면
ZR = ZB + 0.45                            # 쇠 바닥 틀 윗면
DIAL_C = (0.0, FZ + 7.6)                  # 뒷벽 큰 시계판(받침 뒤) 가운데 x, z


def turret_clock(g):
    """탑시계 기계(2026-11-28 사용자 4차: 용도 모를 기계 금지 — '톱니가 바늘 굴대로 이어짐'). 레퍼런스: 옛 탑시계 무브먼트(평상 틀).
    나무 받침(다리 넷) · 쇠 평상 틀 · 사다리꼴 옆판 둘 · 굴대 셋(감는 북 · 가운데 바퀴 · 탈진 바퀴) · 큰 바퀴/작은 톱니 맞물림 · 닻(탈진기) ·
    감는 손잡이 · 북에서 내려간 줄 + 쇠 추 · 앞 작은 시계판 · 진자(천장 보에 매닮, 닻 막대가 잡음) · 위로 오르는 굴대(맞물린 원뿔 톱니)"""
    x0, x1, y0, y1 = MOV
    for x in (x0 + 0.25, x1 - 0.25):                       # 받침 다리 · 가름대 · 윗판
        for y in (y0 + 0.25, y1 - 0.25):
            bx(g, "DarkLog", x - 0.25, x + 0.25, y - 0.25, y + 0.25, FZ, ZB - 0.4)
    for y in (y0 + 0.25, y1 - 0.25):
        bx(g, "Timber", x0 + 0.5, x1 - 0.5, y - 0.15, y + 0.15, FZ + 0.6, FZ + 0.9)
    bx(g, "DarkLog", x0, x1, y0, y1, ZB - 0.4, ZB)
    for x in (x0 + 0.35, x1 - 0.35):                       # 쇠 평상 틀(긴 레일 둘 + 가로 레일 둘)
        bx(g, "Iron", x - 0.2, x + 0.2, y0 + 0.15, y1 - 0.15, ZB, ZR)
    for y in (y0 + 0.35, y1 - 0.35):
        bx(g, "Iron", x0 + 0.55, x1 - 0.55, y - 0.2, y + 0.2, ZB, ZR)
    for x in (x0 + 0.35, x1 - 0.35):                       # 사다리꼴 옆판(굴대 받침)
        P.prism_x(g, "Iron", [(y0 + 0.4, ZR), (y1 - 0.4, ZR), (y1 - 0.9, ZR + 2.6), (y0 + 0.9, ZR + 2.6)], x - 0.15, x + 0.15)
        for yy, zz in ((7.5, ZR + 0.9), (6.5, ZR + 1.7), (5.6, ZR + 1.0), (5.8, ZR + 2.1)):     # 굴대 구멍 놋쇠 받이
            g["Brass"].hcyl(x, yy, zz, 0.22, 0.42, axis="x", seg=10)
    xa, xb = x0 + 0.1, x1 - 0.1
    # 감는 북(굴대 C) + 큰 바퀴 + 감긴 줄 · 손잡이
    g["Steel"].hcyl((xa + xb) / 2, 7.5, ZR + 0.9, 0.12, xb - xa, axis="x", seg=8)
    g["Wood"].hcyl(6.9, 7.5, ZR + 0.9, 0.55, 1.5, axis="x", seg=14)
    for xx in (6.15, 7.65):
        g["Iron"].hcyl(xx, 7.5, ZR + 0.9, 0.7, 0.12, axis="x", seg=14)
    for k in range(4):
        g["Canvas"].hcyl(6.4 + 0.33 * k, 7.5, ZR + 0.9, 0.6, 0.18, axis="x", seg=12)
    K.S.gear(g, "Brass", 7.95, 7.5, ZR + 0.9, 1.0, 24, 0.2, axis="x")
    g["Iron"].obox(xa - 0.1, 7.5, ZR + 0.55, 0.16, 0.2, 0.9)                       # 감는 손잡이(팔 + 나무 쥘대)
    g["Wood"].hcyl(xa - 0.3, 7.5, ZR + 0.15, 0.13, 0.4, axis="x", seg=8)
    # 가운데 바퀴(굴대 B): 작은 톱니(큰 바퀴와 맞물림) + 큰 바퀴(탈진 톱니와 맞물림)
    g["Steel"].hcyl((xa + xb) / 2, 6.5, ZR + 1.7, 0.12, xb - xa, axis="x", seg=8)
    K.S.gear(g, "Iron", 7.95, 6.5, ZR + 1.7, 0.4, 8, 0.25, axis="x")
    K.S.gear(g, "Brass", 6.2, 6.5, ZR + 1.7, 0.8, 20, 0.2, axis="x")
    # 탈진 바퀴(굴대 A) + 닻(굴대 D)
    g["Steel"].hcyl((xa + xb) / 2, 5.6, ZR + 1.0, 0.12, xb - xa, axis="x", seg=8)
    K.S.gear(g, "Iron", 6.2, 5.6, ZR + 1.0, 0.32, 8, 0.25, axis="x")
    K.S.gear(g, "Brass", 6.9, 5.6, ZR + 1.0, 0.6, 15, 0.18, axis="x", depth=0.18)
    g["Steel"].hcyl((xa + xb) / 2 - 0.25, 5.8, ZR + 2.1, 0.12, xb - xa + 0.5, axis="x", seg=8)
    g["Iron"].obox(6.9, 5.8, ZR + 1.75, 0.2, 1.2, 0.3)                              # 닻 팔
    for s in (-1, 1):
        g["Iron"].obox(6.9, 5.8 + s * 0.55, ZR + 1.45, 0.2, 0.2, 0.55, rx=s * 0.3)   # 닻 발톱 둘
    # 북 → 줄 → 쇠 추(받침 밑)
    bx(g, "Canvas", 6.83, 6.97, 7.98, 8.12, FZ + 1.9, ZB - 0.4)
    g["Iron"].cyl(6.9, 8.05, FZ + 0.9, 0.42, 0.42, 1.0, seg=10)
    g["Brass"].cyl(6.9, 8.05, FZ + 1.9, 0.2, 0.12, 0.12, seg=8)
    bx(g, "Canvas", 6.83, 6.97, 7.98, 8.12, ZB, ZR + 0.35)
    # 앞 작은 시계판(기계가 무엇인지 한눈에): 쇠 대 + 놋쇠 테 + 흰 판 + 눈금 + 바늘
    dx_, dz_ = 7.6, ZR + 2.75
    bx(g, "Iron", dx_ - 0.12, dx_ + 0.12, y0 + 0.25, y0 + 0.5, ZR, dz_ - 0.7)
    g["Brass"].hcyl(dx_, y0 + 0.35, dz_, 0.8, 0.2, axis="y", seg=20)
    g["Dial"].hcyl(dx_, y0 + 0.22, dz_, 0.66, 0.08, axis="y", seg=20)
    for k in range(12):
        th = k * math.pi / 6
        g["Iron"].obox(dx_ + 0.52 * math.sin(th), y0 + 0.16, dz_ + 0.52 * math.cos(th), 0.08, 0.05, 0.18 if k % 3 else 0.28, ry=th)
    g["Iron"].obox(dx_ + 0.12, y0 + 0.12, dz_ + 0.18, 0.1, 0.06, 0.45, ry=0.6)
    g["Iron"].obox(dx_ - 0.13, y0 + 0.12, dz_ + 0.06, 0.1, 0.06, 0.32, ry=-2.0)
    g["Brass"].hcyl(dx_, y0 + 0.1, dz_, 0.1, 0.06, axis="y", seg=8)
    # 진자: 천장 보(y 4.3) 밑 칼날 받침 → 쇠 막대 → 놋쇠 추. 닻 굴대 끝 막대(crutch)가 진자 막대를 잡는다
    px, py = 5.6, 4.3
    bx(g, "Iron", px - 0.5, px + 0.5, py - 0.3, py + 0.3, FZ + CEIL - 0.45, FZ + CEIL)
    bx(g, "Steel", px - 0.12, px + 0.12, py - 0.12, py + 0.12, FZ + 3.6, FZ + CEIL - 0.45)
    g["Brass"].hcyl(px, py, FZ + 3.0, 0.8, 0.3, axis="y", seg=16)
    g["Iron"].hcyl(px, py - 0.18, FZ + 3.0, 0.5, 0.06, axis="y", seg=16)
    bx(g, "Iron", px - 0.1, px + 0.1, py, 5.8, ZR + 2.0, ZR + 2.2)
    cbox(px - 0.9, px + 0.9, py - 0.3, py + 0.3, FZ, FZ + 3.9)
    # 위로: 가운데 굴대 끝 원뿔 톱니(선 톱니) ↔ 누운 톱니 → 굴대가 천장을 뚫고 다락으로
    sx, sy = SHAFT
    K.S.gear(g, "Brass", sx, 6.5, ZR + 1.7, 0.5, 10, 0.2, axis="x")
    K.S.gear(g, "Brass", sx, sy, ZR + 2.3, 0.5, 10, 0.2, axis="z")
    g["Steel"].cyl(sx, sy, ZR + 2.2, 0.2, 0.2, FZ + CEIL + 1.2 - ZR - 2.2, seg=8)
    for z in (FZ + 7.0, FZ + 10.4):
        g["Brass"].cyl(sx, sy, z, 0.32, 0.32, 0.25, seg=8)
        bx(g, "Iron", sx, I1, sy - 0.12, sy + 0.12, z - 0.05, z + 0.3)
    # 뒷벽 큰 시계판(받침 뒤) ← 기계 위 상자에서 벽을 따라 온 굴대
    cxd, czd = DIAL_C
    yb = I1
    bx(g, "DarkLog", cxd - 3.0, cxd + 3.0, yb - 0.35, yb, czd - 3.0, czd + 3.0)
    g["Brass"].hcyl(cxd, yb - 0.45, czd, 2.6, 0.2, axis="y", seg=32)
    g["Dial"].hcyl(cxd, yb - 0.6, czd, 2.35, 0.12, axis="y", seg=32)
    for k in range(12):
        th = k * math.pi / 6
        g["Iron"].obox(cxd + 2.0 * math.sin(th), yb - 0.69, czd + 2.0 * math.cos(th), 0.18, 0.08, 0.5 if k % 3 else 0.8, ry=th)
    g["Iron"].obox(cxd + 0.55, yb - 0.75, czd + 0.6, 0.2, 0.08, 1.7, ry=0.75)             # 분침
    g["Iron"].obox(cxd - 0.45, yb - 0.75, czd + 0.2, 0.22, 0.08, 1.1, ry=-1.15)           # 시침
    g["Brass"].hcyl(cxd, yb - 0.8, czd, 0.25, 0.12, axis="y", seg=10)
    bx(g, "Iron", x0 + 0.3, x0 + 1.1, yb - 0.7, yb, ZR + 2.6, czd + 0.4)                  # 기계 위 톱니 상자(뒤 왼 귀)
    bx(g, "Iron", x0 + 0.55, x0 + 0.95, yb - 0.6, yb - 0.1, FZ, ZR + 2.6)                  # 상자 받침 기둥(바닥부터 — 레일 위에 세우지 않음)
    bx(g, "Steel", cxd + 3.0, x0 + 0.3, yb - 0.33, yb - 0.08, czd - 0.12, czd + 0.12)     # 시계판으로 가는 굴대(벽을 따라)
    bx(g, "Iron", 4.1, 4.4, yb - 0.4, yb, czd - 0.3, czd + 0.3)                            # 굴대 벽 받침
    cbox(x0, x1, y0, y1, FZ, ZR + 3.6)


def clockwork(g):
    """1층 시계 기계방(2026-11-28 다시): 오른 뒤 탑시계 기계 → (벽 따라) 뒷벽 큰 시계판 / (천장 뚫고) 시계 단. 대기 긴 의자 둘 · 바닥 돌판 · 바닥 놋쇠 시계 고리 · 벽등 · 행선지 판"""
    turret_clock(g)
    # 대기 긴 의자(왼 벽은 앞 끝 ~ 증기 통 앞 2.5 까지 — 3~9 틈 금지 · 오른 벽 앞)
    P.wall_bench(g, -I1, -1, -7.6, 2.4, FZ)
    P.wall_bench(g, I1, 1, -8.1, -5.0, FZ)
    for i in range(4):                                     # 큰 돌판 두 톤(4.3, 높이 0.05 — 충돌 없음, 비평 1차 맨바닥)
        for j in range(4):
            bx(g, "Stone" if (i + j) % 2 else "DarkStone", -I1 + i * 4.3, -I1 + (i + 1) * 4.3, -I1 + j * 4.3, -I1 + (j + 1) * 4.3, FZ, FZ + 0.05)
    K.S.ring(g, "Brass", 0.0, -0.4, FZ + 0.05, 3.6, 3.9, 0.03, n=24)
    for k in range(12):
        th = k * math.pi / 6
        g["Brass"].obox(3.0 * math.sin(th), -0.4 + 3.0 * math.cos(th), FZ + 0.065, 0.4, 1.0 if k % 3 == 0 else 0.6, 0.03, rz=-th)
    for th, ln in ((math.pi / 3, 3.0), (-math.pi / 3, 2.2)):                                 # 분침(2시) · 시침(10시)
        g["Iron"].obox(ln / 2 * math.sin(th), -0.4 + ln / 2 * math.cos(th), FZ + 0.068, 0.4, ln, 0.035, rz=-th)
    g["Brass"].cyl(0.0, -0.4, FZ + 0.05, 0.35, 0.35, 0.06, seg=12)
    for x in (-7.0, 7.0):
        P.sconce(g, "x", -I1, x, FZ + 7.4, face=1)
    # 문 옆 행선지 판(앞벽 안쪽, 문 왼쪽): 짙은 틀 · 검은 판 · 행선지 패 다섯 줄 + 놋쇠 화살 · 위 놋쇠 머리판
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


def drive_train(g):
    """시계 굴대(2026-11-28): 1층 기계 굴대 → 다락(1층 천장 위)에서 원뿔 톱니 상자 둘로 꺾여 탑 가운데로 → 가운데 세로 굴대(층 바닥마다 놋쇠 받이) →
    시계 단 네 갈래 톱니 상자 → 네 시계판으로 가는 가로 굴대. 위 단 창으로 들여다보면 이것이 보인다(창 안 검은 판 대신)"""
    sx, sy = SHAFT
    zd = FZ + CEIL + 1.2                    # 1층 천장 판 윗면
    zh = zd + 1.4                           # 다락 가로 굴대 높이

    def box_(x, y, z):                      # 원뿔 톱니 상자(쇠 몸 + 놋쇠 덮개) + 밑 받침 기둥(천장 판 위)
        bx(g, "Iron", x - 0.55, x + 0.55, y - 0.55, y + 0.55, z - 0.55, z + 0.55)
        bx(g, "Brass", x - 0.62, x + 0.62, y - 0.62, y + 0.62, z + 0.55, z + 0.7)
        bx(g, "Iron", x - 0.25, x + 0.25, y - 0.25, y + 0.25, zd, z - 0.55)
    g["Steel"].cyl(sx, sy, zd - 0.1, 0.2, 0.2, zh - zd, seg=8)
    box_(sx, sy, zh)
    g["Steel"].hcyl((sx + 0.0) / 2, sy, zh, 0.18, sx - 0.0, axis="x", seg=8)
    box_(0.0, sy, zh)
    g["Steel"].hcyl(0.0, sy / 2, zh, 0.18, sy, axis="y", seg=8)
    box_(0.0, 0.0, zh)
    for x in (sx / 2,):
        bx(g, "Iron", x - 0.2, x + 0.2, sy - 0.2, sy + 0.2, zd, zh - 0.15)
    g["Steel"].cyl(0.0, 0.0, zh + 0.7, 0.22, 0.22, CLOCK_Z - zh - 0.7, seg=8)
    for z in (Z1 + 0.9, 33.6, Z2 + 0.9):                                   # 층 바닥 놋쇠 받이
        g["Brass"].cyl(0.0, 0.0, z, 0.5, 0.5, 0.3, seg=10)
    bx(g, "Iron", -0.8, 0.8, -0.8, 0.8, CLOCK_Z - 0.8, CLOCK_Z + 0.8)       # 네 갈래 톱니 상자
    bx(g, "Brass", -0.9, 0.9, -0.9, 0.9, CLOCK_Z + 0.8, CLOCK_Z + 1.0)
    wi = W3 - T / 2
    for ax_, s in (("x", -1), ("x", 1), ("y", -1), ("y", 1)):
        if ax_ == "x":
            g["Brass"].hcyl(s * 0.9, 0.0, CLOCK_Z, 0.5, 0.2, axis="x", seg=12)
            g["Steel"].hcyl(s * (0.9 + wi) / 2, 0.0, CLOCK_Z, 0.18, wi - 0.9, axis="x", seg=8)
        else:
            g["Brass"].hcyl(0.0, s * 0.9, CLOCK_Z, 0.5, 0.2, axis="y", seg=12)
            g["Steel"].hcyl(0.0, s * (0.9 + wi) / 2, CLOCK_Z, 0.18, wi - 0.9, axis="y", seg=8)
    bx(g, "Iron", -0.3, 0.3, -0.3, 0.3, Z2 + 0.9, CLOCK_Z - 0.8)            # 톱니 상자 받침 기둥(시계 단 바닥 위)


def tier2(g):
    def holes(tag):
        return [(-1.4, 1.4, 26.5, 30.5, True), (-1.4, 1.4, 35.5, 39.5, True)]
    tier_walls(g, W2, Z1 + 0.9, Z2, holes)
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
    drive_train(g)
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
