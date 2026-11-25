# -*- coding: utf-8 -*-
"""
b_general.py — 2026-11-14. 설원 마을 3판: 잡화점(사고팔기, 발자국 28×28). 아트 부서원 1, A 양식(짙은 통나무).

레퍼런스(회사/설원마을_레퍼런스.md G·C): 앤더슨 상점(G1 — 가운데 무쇠 난로 + 카운터, 가운데 길), 옛 잡화점(G2 — 유리 진열 카운터),
뉘른베르크 식료품점(G3 — 매단 등), 컴벌랜드 회사 상점(G4 — 1층 큰 진열창), 뢰로스 통나무(C1·C2).
대장간(앞 박공 + 옆 굴뚝)과 멀리서 구별되게 **옆 박공**(용마루가 정면과 나란함 → 정면은 긴 처마 선) + 지붕을 뚫는 무쇠 연통 + 정면 진열창 둘.

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  벽 가운데 선 x ±12 · y ±10.5 → 안 22.8 × 19.8, 천장 11. 앞 돌 마루(깊이 2) + 계단 폭 12.
  정문 x ±5.2 높이 10(널문은 안쪽으로 90° 열어 벽에 직각 — 진열창을 가리지 않게) · 양옆 진열창 4.4×6(창턱 FZ+1.6)
  오른 뒤: 카운터 x 0..10 · y 4..6.5, NPC (5, 7.7), 뒷벽 선반 전체 · 카운터 앞 빈 바닥 x 0..10 · y -6.15..3.85
  왼: 유리 진열 카운터(왼 벽) · 가운데 왼 무쇠 난로(-4.5, -1.5, 진짜 불) → 연통이 지붕을 뚫음 · 걸상 둘 · 통
  진열창 안: 낮은 진열 단(물건) · 바깥: 오른 앞 모서리 쇠 팔 자루 간판, 앞 마루 상자·통, 뒤 증기 통
"""
import math

import lib as K
import lib_a as A
import lib_int1 as P
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_General"
PREFIX = "Sn3General"
VARIANT = "A"

WX, YF, YB = 12.0, -10.5, 11.0
T = LOG
HX, HY = WX + T / 2, YB + T / 2           # 벽 바깥면 12.6 · 11.1
XI, YI, YFI = WX - T / 2, YB - T / 2, YF + T / 2     # 안쪽 면 11.4 · 10.4 · -9.9
YC, HD = (YF + YB) / 2, (YB - YF) / 2 + T / 2   # 지붕 가운데 y · 반 깊이(바깥면)
Z_PLATE = FZ + CEIL + 0.9
LAND = YF - T / 2 - 1.4                   # 앞 돌 마루 앞 끝
STOVE = (-4.5, -1.5)
PIPE = (STOVE[0] - 0.45, STOVE[0] + 0.45, STOVE[1] - 0.45, STOVE[1] + 0.45)
SHOP_WIN = (4.4, 6.0, FZ + 1.6)           # 진열창 폭·높이·창턱


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    sw, sh, sz = SHOP_WIN
    wz = FZ + WIN_SILL
    holes = {"f": [(-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H), A.hole(-8.6, sz, sw, sh), A.hole(8.6, sz, sw, sh)],
             "b": [A.hole(-6.0, FZ + 7.4, 3.0, 3.6)],
             "l": [A.hole(-3.0, wz), A.hole(5.0, wz)],
             "r": [A.hole(-4.0, wz)]}
    A.log_box(g, -WX, WX, YF, YB, FZ, Z_PLATE, holes)
    for u in (-8.6, 8.6):
        A.win(g, S, "f", u, sz, sw, sh, shutters=False)
    A.win(g, S, "b", -6.0, FZ + 7.4, 3.0, 3.6)
    for u in (-3.0, 5.0):
        A.win(g, S, "l", u, wz)
    A.win(g, S, "r", -4.0, wz)
    # 옆 박공(양쪽) + 다락 창
    gz = Z_PLATE + 1.2
    for xc, face in ((-WX, -1), (WX, 1)):
        A.gable_x(g, R, xc, YC, holes=[(YC - 1.2, YC + 1.2, gz, gz + 3.0)])
        K.window(g, "y", xc, YC, gz, 2.4, 3.0, face=face, shutters=False)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=95.0, outward=False)


# 뒷벽 왼쪽 열린 선반 물건 손 표: 단마다 (종류, x, 값) — 무작위 없음(바이블 9절). y 는 선반 깊이 가운데
SHELF_L = (
    (("barrel", -10.3, 0.55), ("crate", -8.6, 1.3), ("pot", -6.9, 0.6), ("pot", -5.7, 0.5), ("crate", -4.5, 1.1), ("barrel", -2.9, 0.52), ("rope", -1.3, 0.55)),
    (("tins", -10.6, "SignRed"), ("tins", -9.9, "SignRed"), ("tins", -9.2, "SignBlue"), ("jar", -8.1, "SignGold"), ("jar", -7.3, "SignRed"),
     ("tins", -6.3, "PaintGreen"), ("tins", -5.6, "PaintGreen"), ("jar", -4.6, "PaintGreen"), ("candles", -3.5, None), ("tins", -2.4, "SignBlue"),
     ("tins", -1.7, "Copper"), ("tins", -1.0, "Copper")),
    (("cloth", -10.0, ("Banner", "Canvas", "Felt", "SignBlue")), ("cloth", -8.4, ("Felt", "Canvas", "Banner")), ("boots", -6.6, "Leather"),
     ("boots", -5.3, "Timber"), ("lamp", -3.9, None), ("lamp", -2.9, None), ("cloth", -1.4, ("SignBlue", "Paint", "Felt"))),
    (("box", -10.4, "Canvas"), ("box", -9.3, "Paint"), ("books", -8.5, -6.4), ("rope", -5.6, 0.5), ("box", -4.5, "Canvas"), ("lamp", -3.4, None),
     ("box", -2.2, "Paint"), ("box", -1.2, "Canvas")),
)


def _goods(g, kind, x, v, y, z):
    if kind == "barrel":
        P.barrel(g, x, y, z, r=v, h=1.25, coll=False)
    elif kind == "crate":
        P.crate(g, x, y, z, w=v, d=0.8, h=1.0, coll=False)
    elif kind == "pot":
        P.pot(g, x, y, z, r=v, h=0.6)
    elif kind == "rope":
        P.rope_coil(g, x, y, z, r=v)
    elif kind == "tins":
        P.tins(g, x, y, z, n=2, r=0.28, h=0.5, mat=v)
    elif kind == "jar":
        P.bottle(g, x, y, z, liquid=v, h=1.15, r=0.34, label="Paint")
    elif kind == "candles":
        P.candles(g, x, y, z)
    elif kind == "cloth":
        P.cloth_stack(g, x, y, z, w=1.3, d=0.8, mats=v)
    elif kind == "boots":
        P.boots(g, x, y, z, mat=v)
    elif kind == "lamp":
        P.lantern_sale(g, x, y, z, s=0.62)
    elif kind == "box":
        bx(g, "Wood", x - 0.45, x + 0.45, y - 0.35, y + 0.35, z, z + 0.7)
        bx(g, v, x - 0.3, x + 0.3, y - 0.37, y - 0.33, z + 0.2, z + 0.5)
        bx(g, "Timber", x - 0.48, x + 0.48, y - 0.38, y + 0.38, z + 0.7, z + 0.8)
    elif kind == "books":
        P.book_row(g, x, v, y + 0.05, z, depth=0.7, start=int(-x))


def drawer_cabinet(g, x0, x1, c, depth=0.9):
    """서랍장(G3 식료품점 벽 서랍): 아래 서랍 4 줄(짙은 틀 + 밝은 서랍 앞판 + 놋쇠 손잡이 · 이름표 판) · 상판 · 위 열린 선반 둘(병·깡통)"""
    yf = c - depth
    zt = FZ + 3.6
    bx(g, "DarkLog", x0, x1, yf, c, FZ, FZ + 0.4)
    bx(g, "DarkLog", x0, x1, yf + 0.1, c, FZ + 0.4, zt)
    cols = int(round((x1 - x0) / 1.4))
    cw = (x1 - x0) / cols
    for i in range(cols):
        for j in range(4):
            a, b = x0 + i * cw + 0.08, x0 + (i + 1) * cw - 0.08
            za, zb = FZ + 0.48 + j * 0.78, FZ + 0.48 + (j + 1) * 0.78 - 0.08
            bx(g, "Wood", a, b, yf - 0.05, yf + 0.1, za, zb)
            m = (a + b) / 2
            bx(g, "Brass", m - 0.22, m + 0.22, yf - 0.12, yf - 0.05, za + 0.18, za + 0.3)
            bx(g, "Paint", m - 0.25, m + 0.25, yf - 0.08, yf - 0.05, zb - 0.28, zb - 0.1)
    bx(g, "Wood", x0 - 0.1, x1 + 0.1, yf - 0.12, c, zt, zt + 0.15)
    tops = P.shelf(g, "x", c, x0, x1, zt + 0.15, 3.1, depth=0.75, levels=2, face=-1, bay=2.8, coll=False)
    cbox(x0, x1, yf, c, FZ, zt + 3.4)
    return zt + 0.15, tops


def glass_case(g, x0, x1, y0, y1):
    """유리 진열장(왼 벽, 길이 y): 짙은 몸(판 줄) · 밝은 테 · 유리 윗단 · 놋쇠 모서리 기둥 · 안: 주머니칼·나침반·회중시계 손 표"""
    zt = FZ + 2.6
    bx(g, "Timber", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, FZ, zt)
    n = int((y1 - y0) / 1.5)
    for k in range(n + 1):
        yy = y0 + 0.3 + (y1 - y0 - 0.6) * k / n
        bx(g, "DarkLog", x1 - 0.1, x1, yy - 0.12, yy + 0.12, FZ + 0.4, zt - 0.3)
    bx(g, "Iron", x1 - 0.12, x1, y0 + 0.1, y1 - 0.1, FZ, FZ + 0.3)
    bx(g, "Wood", x0, x1 + 0.05, y0, y1, zt, zt + 0.15)
    bx(g, "Glass", x0 + 0.15, x1 - 0.15, y0 + 0.15, y1 - 0.15, zt + 0.15, zt + 1.0)
    bx(g, "Wood", x0, x1 + 0.05, y0, y1, zt + 1.0, zt + 1.12)
    for xx in (x0 + 0.08, x1 - 0.08):
        for yy in (y0 + 0.08, y1 - 0.08):
            bx(g, "Brass", xx - 0.08, xx + 0.08, yy - 0.08, yy + 0.08, zt + 0.15, zt + 1.0)
    xm, z = (x0 + x1) / 2, zt + 0.15
    bx(g, "Felt", x0 + 0.2, x1 - 0.2, y0 + 0.2, y1 - 0.2, z, z + 0.04)
    z += 0.04
    for k, y in enumerate((y0 + 0.9, y0 + 2.2, y0 + 3.5)):          # 주머니칼(쇠 날 + 가죽 자루)
        g["Steel"].obox(xm + 0.2, y, z + 0.05, 0.12, 0.7, 0.06, rz=0.4 * (k - 1))
        g["Leather"].obox(xm - 0.25, y + 0.1, z + 0.07, 0.18, 0.55, 0.12, rz=0.4 * (k - 1))
    for y in (y0 + 4.9, y0 + 6.0):                                   # 나침반(놋쇠 통 + 흰 판 + 바늘)
        g["Brass"].cyl(xm, y, z, 0.35, 0.35, 0.16, seg=10)
        g["Dial"].cyl(xm, y, z + 0.16, 0.28, 0.28, 0.03, seg=10)
        g["SignRed"].obox(xm, y, z + 0.2, 0.06, 0.4, 0.03, rz=0.6)
    for y in (y0 + 7.1, y0 + 8.0):                                   # 회중시계(놋쇠 + 흰 판 + 사슬)
        g["Brass"].cyl(xm, y, z, 0.3, 0.3, 0.12, seg=10)
        g["Dial"].cyl(xm, y, z + 0.12, 0.24, 0.24, 0.03, seg=10)
        g["Brass"].obox(xm - 0.1, y + 0.45, z + 0.04, 0.06, 0.5, 0.06, rz=0.3)
    cbox(x0, x1, y0, y1, FZ, zt + 1.12)


def general_counter(g, x0, x1, y0, y1):
    """잡화 계산대(G3 식료품점): 앞면 서랍 2줄 × 6칸(밝은 앞판 · 이름표 · 놋쇠 손잡이) · 짙은 몸 · 밑 걷어차기 판 · 두꺼운 상판"""
    zt = FZ + K.COUNTER_H
    bx(g, "Timber", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, FZ, zt - 0.3)
    bx(g, "Char", x0 + 0.15, x1 - 0.15, y0 + 0.02, y0 + 0.12, FZ, FZ + 0.35)
    cw = (x1 - x0 - 0.4) / 6
    for i in range(6):
        for j in range(2):
            a, b = x0 + 0.2 + i * cw + 0.06, x0 + 0.2 + (i + 1) * cw - 0.06
            za, zb = FZ + 0.45 + j * 1.3 + 0.06, FZ + 0.45 + (j + 1) * 1.3 - 0.06
            bx(g, "Wood", a, b, y0 - 0.02, y0 + 0.1, za, zb)
            m = (a + b) / 2
            bx(g, "Brass", m - 0.25, m + 0.25, y0 - 0.1, y0 - 0.02, za + 0.3, za + 0.45)
            bx(g, "Canvas", m - 0.3, m + 0.3, y0 - 0.06, y0 - 0.02, zb - 0.42, zb - 0.18)
    bx(g, "Wood", x0 - 0.1, x1 + 0.1, y0 - 0.2, y1 + 0.15, zt - 0.3, zt)
    cbox(x0 - 0.1, x1 + 0.1, y0 - 0.2, y1 + 0.15, FZ, zt)
    return zt


def hung_goods(g):
    """평보(x -7.5 · 0 · 7.5)에 매단 물건(G2 옛 잡화점) — 바닥 위 7 이상(머리에 안 닿게) · 뒤 박공 벽 큰 간판 · 오른 벽 천 걸이"""
    zt = Z_PLATE - 0.9
    for x, y, kind in ((-7.5, -5.5, "bucket"), (-7.5, -3.0, "basket"), (0.0, -2.0, "lamp"), (0.0, 1.5, "basket"), (0.0, 4.0, "bucket"),
                       (-7.5, 5.0, "rope"), (-7.5, 7.5, "lamp"), (7.5, -2.0, "basket")):
        bx(g, "Iron", x - 0.04, x + 0.04, y - 0.04, y + 0.04, FZ + 9.3, zt)
        z = FZ + 7.6
        if kind == "bucket":                                 # 양동이: 무쇠 몸(아래 좁게) · 테 · 손잡이
            g["Iron"].cyl(x, y, z, 0.42, 0.55, 0.9, seg=10)
            g["Brass"].cyl(x, y, z + 0.82, 0.57, 0.57, 0.1, seg=10)
            g["Iron"].obox(x, y, z + 1.3, 0.08, 1.1, 0.08)
            g["Iron"].obox(x, y - 0.55, z + 1.05, 0.08, 0.08, 0.5)
            g["Iron"].obox(x, y + 0.55, z + 1.05, 0.08, 0.08, 0.5)
        elif kind == "basket":                               # 바구니: 엮은 몸(Wood/Timber 띠) · 손잡이 고리
            g["Wood"].cyl(x, y, z, 0.6, 0.75, 0.8, seg=10)
            for k in range(3):
                g["Timber"].cyl(x, y, z + 0.1 + k * 0.25, 0.63 + k * 0.05, 0.66 + k * 0.05, 0.08, seg=10)
            g["Timber"].obox(x, y, z + 1.2, 0.1, 1.3, 0.1)
        elif kind == "lamp":
            P.lantern_sale(g, x, y, z + 0.2, s=0.7)
        else:
            P.rope_coil(g, x, y, z + 0.6, r=0.55)
            bx(g, "Iron", x - 0.3, x + 0.3, y - 0.05, y + 0.05, z + 0.55, z + 0.6)
    # 뒤 박공 벽 큰 간판(나무 판 6×2 · 놋쇠 테 · 자루 그림)
    yb = YI - 0.1
    bx(g, "Timber", 1.0, 7.0, yb - 0.15, yb, FZ + 7.6, FZ + 9.6)
    bx(g, "Brass", 0.85, 7.15, yb - 0.2, yb - 0.05, FZ + 7.45, FZ + 7.6)
    bx(g, "Brass", 0.85, 7.15, yb - 0.2, yb - 0.05, FZ + 9.6, FZ + 9.75)
    K.SVC.sack_icon(g, 2.5, yb - 0.15, FZ + 7.75, face=-1)
    P.scale(g, 5.4, yb - 0.45, FZ + 7.65)
    # 오른 벽 천 걸이(문에서 보이는 벽 위)
    P.cloth_hang(g, "y", XI, -1.5, 4.5, FZ + 6.4, FZ + 8.6, face=-1, mat="Felt")


def checkers_barrel(g, x, y):
    """난롯가 장기 통(G1 가게 난롯가): 통 + 위 판(굵은 4×4 칸) + 말 넷"""
    P.barrel(g, x, y, FZ, r=0.72, h=2.25)
    zt = FZ + 2.25
    bx(g, "Wood", x - 0.85, x + 0.85, y - 0.85, y + 0.85, zt, zt + 0.1)
    for i in range(4):
        for j in range(4):
            if (i + j) % 2 == 0:
                bx(g, "Char", x - 0.7 + i * 0.35, x - 0.35 + i * 0.35, y - 0.7 + j * 0.35, y - 0.35 + j * 0.35, zt + 0.1, zt + 0.13)
    for dx, dy, m in ((-0.52, -0.52, "SignRed"), (0.18, -0.52, "SignRed"), (-0.18, 0.52, "Paint"), (0.52, 0.18, "Paint")):
        g[m].cyl(x + dx, y + dy, zt + 0.13, 0.13, 0.13, 0.1, seg=8)


def inside(g):
    """잡화점 안(G1 앤더슨 상점 · G2 유리 진열 카운터 · G3 식료품점 서랍 벽): 문에서 보면 물건 가득한 뒷벽 선반 + 오른쪽 계산대가 초점"""
    # 계산대 + NPC + 위 물건(등록기 · 천칭 · 사탕 단지 셋 · 종이 두루마리 걸이 · 장부 · 동전 접시)
    zt = general_counter(g, 0.0, 10.0, 5.8, 8.3)
    P.plank_floor(g, -XI, XI, YFI, YI, FZ)               # 널 마루(폭 1.6 · 틈 0 · 한 톤 차 · 이음 엇갈림 — 충돌 없음)
    K.SVC.cash_register(g, 7.6, 7.1, zt)
    P.scale(g, 2.3, 6.9, zt)
    for x, liq in ((3.7, "SignRed"), (4.45, "SignGold"), (5.2, "PaintGreen")):
        P.bottle(g, x, 6.7, zt, liquid=liq, h=1.35, r=0.36, label=None)
    for xx in (0.45, 1.35):
        bx(g, "Iron", xx - 0.06, xx + 0.06, 6.6, 7.4, zt, zt + 1.0)
    g["Canvas"].hcyl(0.9, 7.0, zt + 0.75, 0.32, 0.8, axis="x", seg=10)
    g["Iron"].hcyl(0.9, 7.0, zt + 0.75, 0.08, 1.0, axis="x", seg=6)
    bx(g, "Leather", 8.9, 9.7, 6.3, 7.3, zt, zt + 0.18)
    g["Brass"].cyl(9.3, 7.7, zt, 0.32, 0.38, 0.08, seg=10)
    P.coin_stack(g, 9.3, 7.7, zt + 0.08, n=2, r=0.14)
    NPC(5.0, 8.9, FZ, 0.0)
    # 뒷벽: 왼 열린 선반(손 표 물건) · 오른 서랍장(계산대 뒤)
    tops = P.shelf(g, "x", YI, -11.2, -0.4, FZ, 6.8, depth=1.1, levels=4, face=-1, bay=3.6)
    for z, row in zip(tops, SHELF_L):
        for kind, x, v in row:
            _goods(g, kind, x, v, YI - 0.6, z)
    zc, tops2 = drawer_cabinet(g, -0.2, 11.2, YI)
    for k, x in enumerate((0.5, 1.4, 2.3, 3.4, 4.3, 7.0, 8.0, 9.0, 10.3)):
        P.bottle(g, x, YI - 0.45, zc, liquid=("SignGold", "SignRed", "PaintGreen", "SignTeal")[k % 4], h=1.0, r=0.3, label="Paint")
    for z, row in zip(tops2, (((0.7, "SignBlue"), (1.5, "SignBlue"), (3.0, "Copper"), (5.6, "SignRed"), (6.4, "SignRed"), (8.8, "PaintGreen"), (9.6, "PaintGreen")),
                              ((1.0, "Copper"), (2.4, "SignGold"), (4.0, "SignTeal"), (6.8, "Copper"), (8.2, "SignBlue"), (10.2, "SignGold")))):
        for x, m in row:
            P.tins(g, x, YI - 0.4, z, n=2 if m in ("SignBlue", "Copper") else 1, r=0.27, h=0.5, mat=m)
    for s in (-1, 1):
        P.sconce(g, "y", s * XI, 8.6, FZ + 7.2, face=-s)
    # 왼 벽: 유리 진열장 + 위 걸이판(눈신 둘 · 망치 둘)
    glass_case(g, -XI, -9.0, -6.0, 3.0)
    P.tool_board(g, "y", -XI, -1.1, 3.1, FZ + 4.6, FZ + 8.2, face=1)
    for y in (-0.3, 0.9):
        P.snowshoe(g, -XI + 0.4, y, FZ + 6.6, rz=math.pi / 2)
    for y, r in ((2.0, 0.25), (2.6, -0.2)):
        P.hammer(g, -XI + 0.35, y, FZ + 5.0, rz=math.pi / 2, ry=r, s=1.1)
    # 난롯가(G1): 무쇠 난로 · 장기 통 · 의자 둘 · 걸상 · 깔개
    P.rug(g, -9.0, -3.2, -4.4, 2.4, FZ, "Felt", "Banner", "SignGold")
    A.iron_stove(g, *STOVE, FZ, R_TOP + 1.2)
    checkers_barrel(g, -7.3, -1.0)
    P.chair(g, -7.3, -2.9, FZ, rz=0.0)
    P.chair(g, -7.3, 0.9, FZ, rz=math.pi)
    P.stool(g, -4.4, 1.3, FZ, coll=True)
    # 오른 벽: 기댄 눈삽·빗자루 / 오른 앞: 상자 둘 · 자루 셋 / 왼 앞: 통 + 자루 둘
    for y, fn in ((0.6, P.shovel), (1.5, P.broom), (2.4, P.shovel), (3.3, P.broom)):
        fn(g, 10.55, y, FZ, rz=-math.pi / 2)
    P.crate(g, 9.9, -6.6, FZ, w=2.0, d=2.0, h=2.0, rz=0.08)
    P.crate(g, 9.8, -6.7, FZ + 2.0, w=1.5, d=1.5, h=1.4, rz=-0.2)
    for x, y, sc, rz in ((7.9, -7.0, 1.0, 0.2), (8.3, -5.6, 0.85, -0.6)):
        P.sack(g, x, y, FZ, s=sc, rz=rz)
    P.sack(g, 8.0, -6.4, FZ + 1.0, s=0.8, rz=1.1)
    cbox(7.3, 10.9, -7.7, -4.9, FZ, FZ + 3.4)
    P.barrel(g, -7.6, -7.0, FZ, r=0.75, h=2.2)
    for x, y, rz in ((-6.2, -6.6, 0.4), (-6.5, -7.8, -0.3)):
        P.sack(g, x, y, FZ, s=0.8, rz=rz)
    # 진열창 안 낮은 단(창 밑) + 손 표 물건
    for x0, x1 in ((-11.0, -6.4), (6.4, 11.0)):
        K.I.box2(g, "Timber", x0, x1, YFI, YFI + 1.6, FZ, FZ + 1.4)
        bx(g, "Wood", x0, x1, YFI, YFI + 1.6, FZ + 1.4, FZ + 1.55)
    zw, yw = FZ + 1.55, YFI + 0.8
    P.lantern_sale(g, -10.2, yw, zw, s=0.8)
    P.boots(g, -8.8, yw, zw, mat="Leather")
    P.cloth_stack(g, -7.3, yw, zw, w=1.2, d=1.0, mats=("Banner", "Felt", "Canvas"))
    for k, x in enumerate((7.0, 7.6, 8.2)):
        P.bottle(g, x, yw - 0.2, zw, liquid=("SignTeal", "SignGold", "SignRed")[k], h=1.0, r=0.26)
    P.candles(g, 9.1, yw, zw)
    P.tins(g, 10.2, yw, zw, n=3, r=0.3, h=0.5, mat="SignBlue")
    # 매단 등(평보 x -7.5 · 0 · 7.5 밑) · 평보에 매단 썰매
    for x, y in ((0.0, -5.0), (7.5, 1.5), (-7.5, -1.0), (0.0, 7.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)
    P.sled(g, 7.5, 4.6, FZ + 9.2)                          # 문에서 보이는 뒤쪽 평보 밑으로(비평 1차)
    for yy in (3.2, 6.0):
        bx(g, "Iron", 7.45, 7.55, yy - 0.05, yy + 0.05, FZ + 9.9, Z_PLATE - 0.9)
    hung_goods(g)


def outside(g):
    # 오른 앞 모서리 쇠 팔 자루 간판(옆벽 면에 박음)
    K.hang_sign(g, HX, YF + 1.0, FZ + 9.4, along="x", arm=2.0, board=(2.6, 2.0),
                icon=lambda g_, x, y, z, f: K.SVC.sack_icon(g_, x, y, z - 0.15, face=f))
    # 앞 마루 위 상자·통(문 양옆, 진열창 아래)
    K.SVC.crate(g, -8.6, LAND + 0.7, FZ, 1.2, rz=0.2)
    K.SVC.barrel(g, 9.6, LAND + 0.7, FZ, r=0.55, h=1.8)
    K.SVC.crate(g, 8.0, LAND + 0.7, FZ, 1.1, rz=-0.15)
    # 문 양옆 바깥 등(벽에 박은 쇠 팔)
    for x in (-6.15, 6.15):
        bx(g, "Iron", x - 0.1, x + 0.1, YF - T / 2 - 1.2, YF - T / 2, FZ + 9.0, FZ + 9.2)
        K.lantern(g, x, YF - T / 2 - 1.1, FZ + 9.1, FZ + 7.8)
    # 오른 옆 뒤 증기 통 → 관이 옆벽으로(난방)
    tx, ty = HX + 1.6, 6.5
    K.steam_bundle(g, tx, ty, 0.0, h=6.0, r=1.1, gauge_face=-1, vent=False,     # 김은 난로 연통 하나(holes.py 김 상자 검사)
                   pipe_pts=[(tx - 1.1, ty, 7.0), (HX - 0.3, ty, 7.0)])


R_TOP = 0.0


def build(g):
    global R_TOP
    R = A.roof_frame_x(HD, -HX, HX, Z_PLATE, K.PITCH["A"])
    R_TOP = R.top()
    K.foundation(g, -HX - 0.3, HX + 0.3, LAND, HY + 0.3)
    K.stair(g, 0.0, LAND, 12.0, FZ)
    shell(g, R)
    for x in (-7.5, 0.0, 7.5):
        A.truss_x(g, R, x, YC)
    A.roof_x(g, R, YC, openings=[PIPE])
    inside(g)
    outside(g)
    CLEAR(-4.8, 4.8, YF + T / 2 + 0.2, -4.35, FZ + 0.15, FZ + 5.4)
    CLEAR(0.0, 10.0, -4.35, 5.65, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": (0.0, 10.0, 5.8, 8.3),
    "free": (0.0, 10.0, -4.35, 5.65),
    "walk": ((0.0, YF - 1.5), (5.0, 0.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI),
    "forge_look": STOVE,
}
