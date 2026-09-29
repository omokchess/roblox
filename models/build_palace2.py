# -*- coding: utf-8 -*-
"""
build_palace2.py — 궁을 채우는 건물들. (2026-09-26)

  Gate_Palace      광화문형 정문. 홍예 셋을 뚫은 석축 위에 중층 문루
  Gate_Hall        3칸 중문. 행각 고리의 앞문. 세 칸 모두 문짝을 안으로 열어 드나든다
  Corridor         행각 한 토막(길이 40 = 20 스터드). 이어 붙이므로 양 끝을 자른다.
                   기둥은 1/4 지점 둘(±10)에만 둔다. 끝에 두면 어느 쪽으로 돌려 앉혀도
                   모서리나 문의 기둥과 한 자리에 포개지는 끝이 생긴다. 이음매 너머 기둥 간격도 20 으로 같다
  Corridor_Corner  행각 ㄱ자 모서리. 두 줄 지붕이 안쪽은 골로, 바깥은 추녀로 만난다
  Pavilion_Nugak   경회루형 누각. 섬 위 돌기둥 층, 그 위 마루 층. 안쪽 계단으로 오른다
  Tower_Bell       종루. 누각 틀을 작게 줄이고 위층에 종을 단다
  Palace_Chimjeon  침전. 정면 9칸, 용마루 없는 무량각 지붕, 앞에 넓은 월대

**행각은 토막을 이어 붙이는 것이라 지붕 앙곡(lift)을 0 으로 둔다.** 앙곡이 있으면
토막마다 양 끝이 들려 이음매가 톱니가 된다. 처마 서까래와 용마루도 토막 길이에 딱 맞춘다.
겹치면 이웃 토막과 같은 면이 포개져 깜빡인다.

돌리는 법: blender --background --python build_palace2.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5


# ---------------------------------------------------------------- 홍예

def arc_solid(g, mat, cx, hs, r, y0, y1, outer, n=16):
    """
    반원 홍예를 따라 도는 덩이. 안쪽 곡면이 홍예 천장이 된다.
      outer = ("top", z)     반원 위를 z 까지 메운다. 홍예 위 석축
      outer = ("ring", R)    반지름 R 까지만. 홍예 머리 둘레의 띠돌
    """
    verts = []
    for y in (y0, y1):
        for k in range(n + 1):
            th = math.pi - math.pi * k / n
            verts.append((cx + r * math.cos(th), y, hs + r * math.sin(th)))
        for k in range(n + 1):
            th = math.pi - math.pi * k / n
            if outer[0] == "top":
                verts.append((cx + r * math.cos(th), y, outer[1]))
            else:
                R = outer[1]
                verts.append((cx + R * math.cos(th), y, hs + R * math.sin(th)))
    m = n + 1
    FA, FT, BA, BT = 0, m, 2 * m, 3 * m
    faces = []
    for k in range(n):
        faces.append((FA + k, FA + k + 1, FT + k + 1, FT + k))
        faces.append((BA + k, BT + k, BT + k + 1, BA + k + 1))
        faces.append((FA + k, BA + k, BA + k + 1, FA + k + 1))
        faces.append((FT + k, FT + k + 1, BT + k + 1, BT + k))
    faces.append((FA, FT, BT, BA))
    faces.append((FA + n, BA + n, BT + n, FT + n))
    g[mat].add_mesh(verts, faces)


# ---------------------------------------------------------------- 정문

PW, PD, PH = 120.0, 36.0, 30.0          # 석축(육축)
# 홍예 (가운데 x, 반지름, 홍예 머리가 시작하는 높이)
ARCHES = [(0.0, 10.0, 16.0), (-34.0, 7.0, 12.0), (34.0, 7.0, 12.0)]


def gate_palace(g):
    # 석축. 홍예 사이 기둥 넷을 통으로 세우고, 홍예 위는 반원을 파낸 덩이로 메운다
    edges = [-PW / 2]
    for cx, r, _ in sorted(ARCHES):
        edges += [cx - r, cx + r]
    edges.append(PW / 2)
    for a, b in zip(edges[0::2], edges[1::2]):
        g["Masonry"].box((a + b) / 2, 0, PH / 2, b - a, PD, PH)
        # 밑 켜. 기둥마다 한 켜 넓게 두른다. 홍예 길은 비운다
        g["Stylobate"].box((a + b) / 2, 0, 1.0, b - a, PD + 2.0, 2.0)
    for cx, r, hs in ARCHES:
        arc_solid(g, "Masonry", cx, hs, r, -PD / 2, PD / 2, ("top", PH))
        # 홍예 머리 띠돌과 문설주 띠. 앞뒤 면에 조금 내민다
        for y0, y1 in ((-PD / 2 - 0.6, -PD / 2 + 0.01), (PD / 2 - 0.01, PD / 2 + 0.6)):
            arc_solid(g, "Stylobate", cx, hs, r, y0, y1, ("ring", r + 2.2))
            for s in (-1, 1):
                g["Stylobate"].box(cx + s * (r + 1.1), (y0 + y1) / 2, hs / 2, 2.2, y1 - y0, hs)
        # 가운데 홍예 문짝. 안으로 활짝 열어 홍예 옆벽에 붙인다
        if cx == 0.0:
            for s in (-1, 1):
                g["Column"].box(s * (r - 0.6), -PD / 2 + 9.0, hs * 0.5 + 0.2, 1.0, 11.0, hs - 0.4)
                for k in range(3):
                    g["RoofEdge"].box(s * (r - 0.9), -PD / 2 + 9.0, hs * (k + 1) / 4, 0.5, 11.2, 0.7)
    # 윗면 갓돌과 여장
    g["Stylobate"].box(0, 0, PH + 0.6, PW + 1.6, PD + 1.6, 1.2)
    top = PH + 1.2
    for s in (-1, 1):
        g["Masonry"].box(0, s * (PD / 2 - 0.2), top + 1.8, PW + 1.2, 2.0, 3.6)
        g["Stylobate"].box(0, s * (PD / 2 - 0.2), top + 3.9, PW + 1.8, 2.6, 0.6)
        g["Masonry"].box(s * (PW / 2 - 0.2), 0, top + 1.8, 2.0, PD - 2.4, 3.6)
        g["Stylobate"].box(s * (PW / 2 - 0.2), 0, top + 3.9, 2.6, PD - 3.0, 0.6)

    # 문루 아래층
    W1, D1, COL1 = 60.0, 26.0, 14.0
    g["Stylobate"].box(0, 0, top + 0.6, W1 + 6, D1 + 6, 1.2)
    floor = top + 1.2
    xs, ys = L.column_grid(W1, D1, 3, 2)
    top1 = L.columns(g, xs, ys, floor, COL1, r=2.0)
    roof1_z = L.beams(g, xs, ys, top1)
    L.dancheong(g, W1, D1, top1)
    L.walls(g, xs, ys, floor, COL1 + 1.8, front=["lattice"] * 3, back=["lattice"] * 3,
            side=["window", "window"])
    ridge1 = L.build_roof(g, roof1_z, W1, D1, 8.0, 7.0, chimi=False, ridge=False, nx=32, ny=20)

    # 위층. 아래 지붕 위에 허리를 한 켜 세워 띄우지 않는다
    W2, D2, COL2 = 46.0, 16.0, 9.0
    floor2 = ridge1 + 1.0
    waist = floor2 - roof1_z
    g["Beam"].box(0, 0, roof1_z + waist / 2, W2 + 4, D2 + 4, waist)
    for s in (-1, 1):
        g["Trim"].box(0, s * (D2 / 2 + 2.1), floor2 - 1.2, W2 + 4.4, 0.4, 1.2)
    xs2, ys2 = L.column_grid(W2, D2, 3, 1)
    top2 = L.columns(g, xs2, ys2, floor2, COL2, r=1.7, plinth=False)
    roof2_z = L.beams(g, xs2, ys2, top2)
    L.dancheong(g, W2, D2, top2)
    L.walls(g, xs2, ys2, floor2, COL2, front=["window", "lattice", "window"], back=["window"] * 3,
            side=["window"])
    L.build_roof(g, roof2_z, W2, D2, 11.0, 14.0, nx=36, ny=22)
    # 현판
    g["RoofEdge"].box(0, -(D2 / 2 + 2.6), top2 - 2.6, 12.0, 0.8, 4.0)
    g["Ochre"].box(0, -(D2 / 2 + 3.1), top2 - 2.6, 9.6, 0.4, 2.6)


# ---------------------------------------------------------------- 중문

def gate_hall(g):
    W, D, COL = 60.0, 24.0, 26.0
    BASE = 3.5
    g["Stylobate"].box(0, 0, BASE / 2, W + 14, D + 12, BASE)
    # 앞뒤 계단. 세 칸을 모두 받도록 기단 폭만큼 넓게
    n, tread = 2, 2.4
    for k in range(n):
        h = BASE * (k + 1) / n
        off = (D + 12) / 2 + tread * (n - k) - tread / 2
        g["Stairs"].box(0, -off, h / 2, W, tread + 0.2, h)
        g["Stairs"].box(0, off, h / 2, W, tread + 0.2, h)
    floor = BASE
    xs, ys = [-30.0, -10.0, 10.0, 30.0], [-12.0, 0.0, 12.0]
    top = L.columns(g, xs, ys, floor, COL, r=2.2, edge_only=False)
    roof_z = L.beams(g, xs, ys, top)
    L.dancheong(g, W, D, top)
    # 양 옆벽. 행각이 여기에 와 닿는다
    for s in (-1, 1):
        for cy in (-6.0, 6.0):
            L.opening(g, s * 30.0, cy, 12.0, False, floor, COL + 1.8, 0, 0, 0, "solid")
    # 가운데 줄 문얼굴. 문 위 인방과 홍살
    door_h = COL - 5.0
    g["Beam"].box(0, 0, floor + door_h + 1.0, W, 1.6, 2.0)
    for cx in (-20.0, 0.0, 20.0):
        for k in range(7):
            x = cx - 7.0 + 14.0 * k / 6
            g["Column"].box(x, 0, floor + door_h + 2.0 + (top - floor - door_h - 2.0) / 2,
                            0.5, 0.5, top - floor - door_h - 2.0)
        # 문짝 둘. 안(+y)으로 활짝 열려 옆 기둥 쪽에 붙어 있다
        for s in (-1, 1):
            x = cx + s * 7.9
            g["Column"].box(x, 6.7, floor + door_h / 2 + 0.3, 1.0, 8.6, door_h)
            for k in range(3):
                g["RoofEdge"].box(x, 6.7, floor + door_h * (k + 1) / 4, 1.3, 8.8, 0.8)
    L.build_roof(g, roof_z, W, D, 9.0, 15.0, nx=40, ny=24)
    g["RoofEdge"].box(0, -(D / 2 + 2.4), top - 3.0, 14.0, 0.8, 4.6)
    g["Ochre"].box(0, -(D / 2 + 2.9), top - 3.0, 11.0, 0.4, 3.0)


# ---------------------------------------------------------------- 행각

CL, CD, CCOL = 40.0, 20.0, 16.0          # 토막 길이, 깊이, 기둥
C_EAVE, C_H, C_THICK = 6.0, 9.0, 2.0
C_BASE = 2.5
C_TOP = C_BASE + 1.8 + CCOL              # 기둥 머리
C_ROOF = C_TOP + 4.6                     # 지붕 밑
C_B = CD / 2 + C_EAVE                    # 처마 끝까지 반폭


def c_profile(u):
    """행각 지붕 단면. 처마 끝이 0, 용마루가 C_H. build_roof 맞배와 같은 곡선"""
    t = max(0.0, (C_B - abs(u)) / C_B)
    return C_H * t ** 1.42


def c_column(g, x, y):
    g["Plinth"].cyl(x, y, C_BASE, 1.7 * 1.43, 1.7 * 1.29, 1.8)
    g["Column"].cyl(x, y, C_BASE + 1.8, 1.7, 1.7 * 0.83, CCOL)


def c_back_wall(g, cx, cy, span, along_x):
    wall_h = CCOL + 1.8
    L.opening(g, cx, cy, span, along_x, C_BASE, wall_h, wall_h * 0.5, wall_h * 0.24, 7.0, "window")
    if along_x:
        g["Masonry"].box(cx, cy, C_BASE + 1.6, span, 2.6, 3.2)
    else:
        g["Masonry"].box(cx, cy, C_BASE + 1.6, 2.6, span, 3.2)


def c_ridge(g, x0, x1, y0, y1):
    """용마루. x0..x1 × y0..y1 한 줄. 두 켜"""
    ridge_z = C_ROOF + C_H
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    lx, ly = max(x1 - x0, 3.4), max(y1 - y0, 3.4)
    g["RoofEdge"].box(cx, cy, ridge_z + 1.0, lx, ly, 2.0)
    g["RoofEdge"].box(cx, cy, ridge_z + 2.4, lx if lx > 3.4 else 2.6, ly if ly > 3.4 else 2.6, 1.2)


def corridor(g):
    half = CL / 2
    g["Stylobate"].box(0, 0, C_BASE / 2, CL, CD + 8, C_BASE)
    q = half / 2
    for x in (-q, q):
        for y in (-CD / 2, CD / 2):
            c_column(g, x, y)
    for y in (-CD / 2, CD / 2):
        g["Beam"].box(0, y, C_TOP + 1.2, CL, 2.2, 2.4)
    for x in (-q, q):
        g["Beam"].box(x, 0, C_TOP + 1.2, 2.2, CD + 4, 2.4)
    g["Beam"].box(0, 0, C_TOP + 3.0, CL, CD + 5, 1.4)
    # 바깥(+y) 벽. 기둥 사이 칸에 높은 창 하나, 이음매에 걸친 반 칸 둘은 막는다. 안(-y)은 트였다
    c_back_wall(g, 0.0, CD / 2, half, True)
    for s in (-1, 1):
        L.opening(g, s * (half - q / 2), CD / 2, q, True, C_BASE, CCOL + 1.8, 0, 0, 0, "solid")
        g["Masonry"].box(s * (half - q / 2), CD / 2, C_BASE + 1.6, q, 2.6, 3.2)
    L.heightfield_roof(g, lambda x, y: c_profile(y), -half, half, -C_B, C_B, C_ROOF,
                       thick=C_THICK, nx=4, ny=24)
    c_ridge(g, -half, half, -1.7, 1.7)
    for s in (-1, 1):
        g["Eave"].box(0, s * C_B, C_ROOF - C_THICK - 0.5, CL, 2.6, 1.3)


def corridor_corner(g):
    """
    원점이 모서리 칸 한가운데. 한 줄은 -x 쪽에서, 다른 줄은 -y 쪽에서 와 닿는다.
    마당은 두 줄 안쪽(-x, -y 사이)에 있고, 바깥벽은 +x 와 +y 에 선다.
    지붕 높이 = max(A 줄, B 줄). A 줄은 x>0 에서, B 줄은 y>0 에서 추녀로 꺾여 내려간다
    """
    h = CD / 2

    def roof(x, y):
        za = c_profile(y) if x <= 0 else min(c_profile(y), c_profile(x))
        zb = c_profile(x) if y <= 0 else min(c_profile(x), c_profile(y))
        return max(za, zb)

    # 기단은 모서리 칸과 바깥 두 변만. 안쪽 두 변은 이어 붙는 행각 토막 기단이 채운다
    g["Stylobate"].box(2.0, 2.0, C_BASE / 2, CD + 4, CD + 4, C_BASE)
    for x in (-h, h):
        for y in (-h, h):
            c_column(g, x, y)
    for y in (-h, h):
        g["Beam"].box(0, y, C_TOP + 1.2, CD, 2.2, 2.4)
    for x in (-h, h):
        g["Beam"].box(x, 0, C_TOP + 1.2, 2.2, CD, 2.4)
    g["Beam"].box(1.25, 1.25, C_TOP + 3.0, CD + 2.5, CD + 2.5, 1.4)
    c_back_wall(g, 0, h, CD, True)
    c_back_wall(g, h, 0, CD, False)
    # 지붕은 격자가 골과 추녀를 따르도록 짝수로 촘촘히
    L.heightfield_roof(g, roof, -h, C_B, -h, C_B, C_ROOF, thick=C_THICK, nx=26, ny=26)
    c_ridge(g, -h, 1.7, -1.7, 1.7)
    c_ridge(g, -1.7, 1.7, -h, -1.7)
    # 추녀마루. 바깥 모서리로 내려가는 곡선을 네 도막으로 따른다
    for k in range(4):
        a, b = C_B * k / 4, C_B * (k + 1) / 4
        za, zb = C_ROOF + c_profile(a), C_ROOF + c_profile(b)
        m = (a + b) / 2
        run = (b - a) * math.sqrt(2)
        g["RoofEdge"].obox(m, m, (za + zb) / 2 + 0.9, 2.4, math.hypot(run, za - zb) + 0.6, 1.6,
                           rx=math.atan2(zb - za, run), rz=-math.pi / 4)
    # 두 처마 서까래가 바깥 모서리에서 엇갈린다. 하나를 조금 낮춰 포개진 면이 깜빡이지 않게 한다
    g["Eave"].box(C_B / 2 - h / 2, C_B, C_ROOF - C_THICK - 0.5, CD / 2 + C_B, 2.6, 1.3)
    g["Eave"].box(C_B, C_B / 2 - h / 2, C_ROOF - C_THICK - 0.56, 2.6, CD / 2 + C_B, 1.3)


# ---------------------------------------------------------------- 누각과 종루

def lofty(g, bx, by, bay, pier_h, col_h, eave, roof_h, margin, bell=False):
    """
    돌기둥 층 위에 마루 층을 얹은 누각. 계단은 맨 뒤 칸 줄 안에서 x 쪽으로 오른다.
    계단 위 마루는 뚫고 세 변에 난간을 두른다
    """
    W, D = bx * bay, by * bay
    xs, ys = L.column_grid(W, D, bx, by)
    PB = 4.0
    g["Masonry"].box(0, 0, 0.75, W + 2 * margin + 1.0, D + 2 * margin + 1.0, 1.5)
    g["Stylobate"].box(0, 0, PB / 2, W + 2 * margin, D + 2 * margin, PB)
    for x in xs:
        for y in ys:
            g["Masonry"].box(x, y, PB + pier_h / 2, 3.6, 3.6, pier_h)
            g["Plinth"].box(x, y, PB + pier_h - 0.5, 4.6, 4.6, 1.0)
    deck_z = PB + pier_h
    for y in ys:
        g["Beam"].box(0, y, deck_z + 0.6, W + 3, 2.0, 1.2)
    for x in xs:
        g["Beam"].box(x, 0, deck_z + 0.6, 2.0, D + 3, 1.2)
    floor = deck_z + 1.2 + 1.6

    # 계단
    rise = floor - PB
    n = int(math.ceil(rise / 1.9))
    tread = 2.4
    run = n * tread
    x_s, x_e = -run / 2, run / 2
    y_lo, y_hi = ys[-2] + 2.6, ys[-1] - 2.6
    for k in range(n):
        h = rise * (k + 1) / n
        g["Stairs"].box(x_s + tread * (k + 0.5), (y_lo + y_hi) / 2, PB + h / 2, tread + 0.2, y_hi - y_lo, h)

    # 마루. 계단 위를 비운 네 조각
    EW, ED = W + 6, D + 6
    hy0, hy1 = y_lo - 0.4, y_hi + 0.4
    zc, t = deck_z + 1.2 + 0.8, 1.6
    g["Beam"].box(0, (-ED / 2 + hy0) / 2, zc, EW, hy0 + ED / 2, t)
    g["Beam"].box(0, (ED / 2 + hy1) / 2, zc, EW, ED / 2 - hy1, t)
    g["Beam"].box((-EW / 2 + x_s) / 2, (hy0 + hy1) / 2, zc, x_s + EW / 2, hy1 - hy0, t)
    g["Beam"].box((EW / 2 + x_e) / 2, (hy0 + hy1) / 2, zc, EW / 2 - x_e, hy1 - hy0, t)
    L.railing(g, x_s, hy0, x_e, hy0, floor, h=3.6)
    L.railing(g, x_s, hy1, x_e, hy1, floor, h=3.6)
    L.railing(g, x_s, hy0, x_s, hy1, floor, h=3.6)

    top = L.columns(g, xs, ys, floor, col_h, r=1.7, plinth=False, edge_only=False)
    roof_z = L.beams(g, xs, ys, top)
    L.dancheong(g, W, D, top)
    e = EW / 2 - 0.6
    f = ED / 2 - 0.6
    L.railing(g, -e, -f, e, -f, floor, h=3.6)
    L.railing(g, -e, f, e, f, floor, h=3.6)
    L.railing(g, -e, -f, -e, f, floor, h=3.6)
    L.railing(g, e, -f, e, f, floor, h=3.6)
    # 머리 쪽 낙양. 기둥 사이 윗부분을 살짝 막는다
    for i in range(bx):
        cx, span = (xs[i] + xs[i + 1]) / 2, xs[i + 1] - xs[i] - 3.0
        for y in (ys[0], ys[-1]):
            g["Lattice"].box(cx, y, top - 1.8, span, 0.8, 0.5)
    for j in range(by):
        cy, span = (ys[j] + ys[j + 1]) / 2, ys[j + 1] - ys[j] - 3.0
        for x in (xs[0], xs[-1]):
            g["Lattice"].box(x, cy, top - 1.8, 0.8, span, 0.5)

    if bell:
        # 종. 앞쪽 칸 줄 가운데에 건다. 뒤 칸 줄은 계단 구멍이다
        # 종을 거는 보는 앞 두 줄 안쪽 기둥 사이에 건너지른 보 둘 위에 얹는다
        by_ = (ys[0] + ys[1]) / 2 + 2.0
        hz = top - 2.2
        for x in (xs[1], xs[-2]):
            g["Beam"].box(x, (ys[0] + ys[1]) / 2, hz, 1.8, ys[1] - ys[0], 1.8)
        g["Beam"].box(0, by_, hz, xs[-2] - xs[1], 1.8, 1.8)
        g["Trim"].cyl(0, by_, floor + 2.4, 4.2, 3.8, 1.0, seg=20)
        g["Trim"].cyl(0, by_, floor + 3.4, 3.8, 3.1, 4.6, seg=20)
        g["Trim"].cyl(0, by_, floor + 8.0, 3.1, 2.0, 1.2, seg=20)
        rod = hz - 0.9 - (floor + 9.2)
        assert rod > 0.5, "종 고리 줄 길이 %.2f. 기둥이 종보다 낮다" % rod
        g["Trim"].cyl(0, by_, floor + 9.2, 0.8, 0.8, rod, seg=10)
        g["Ochre"].cyl(0, by_, floor + 5.2, 3.65, 3.6, 0.5, seg=20)
        # 당목. 종 옆에 매단 나무 막대
        g["Lattice"].hcyl(7.2, by_, floor + 5.5, 0.8, 6.0, axis="x")

    L.build_roof(g, roof_z, W, D, eave, roof_h, nx=44, ny=34)
    return floor


# ---------------------------------------------------------------- 침전

def chimjeon(g):
    W, D, COL = 108.0, 40.0, 22.0
    TF = 30.0                                   # 월대가 앞으로 나온 길이
    TW, TD, TH = W + 20, D + 20 + TF, 5.0
    ty = -TF / 2
    g["Masonry"].box(0, ty, 0.8, TW + 1.0, TD + 1.0, 1.6)
    g["Stylobate"].box(0, ty, TH / 2, TW, TD, TH)
    front = ty - TD / 2
    for cx, sw in ((0.0, 22.0), (-38.0, 12.0), (38.0, 12.0)):
        L.stair(g, cx, front, TH, sw, steps=3, tread=2.4)
    g["Stylobate"].box(0, 0, TH + 1.5, W + 8, D + 8, 3.0)
    floor = TH + 3.0
    for cx, sw in ((0.0, 16.0), (-38.0, 10.0), (38.0, 10.0)):
        L.stair(g, cx, -(D + 8) / 2, 3.0, sw, steps=2, tread=2.2, base_z=TH)
    # 월대 위 드므 둘. 불을 막는 물독
    for s in (-1, 1):
        g["Onggi"].cyl(s * 50.0, front + 10.0, TH, 2.2, 3.2, 3.6, seg=14)
        g["RoofEdge"].cyl(s * 50.0, front + 10.0, TH + 3.6, 3.2, 3.0, 0.4, seg=14)

    xs, ys = L.column_grid(W, D, 9, 2)
    top = L.columns(g, xs, ys, floor, COL, r=2.1)
    roof_z = L.beams(g, xs, ys, top)
    L.dancheong(g, W, D, top)
    fr = ["lattice"] * 9
    fr[4] = "open"
    L.walls(g, xs, ys, floor, COL + 1.8, front=fr, back=["window"] * 9, side=["window", "window"])
    g["Stylobate"].box(0, 0, floor + 0.4, W - 2, D - 2, 0.8)
    ridge_half = (W - D) / 2 * 0.5 + 6.0
    ridge_z = L.build_roof(g, roof_z, W, D, 11.0, 16.0, ridge=False, chimi=False, nx=46, ny=26)
    # 무량각. 용마루 대신 둥근 기와등을 지붕과 같은 색으로 얹는다
    g["Roof"].hcyl(0, 0, ridge_z - 0.6, 2.6, ridge_half * 2 + 2.0, axis="x", seg=14)


# ---------------------------------------------------------------- 내놓기

JOBS = [
    ("Gate_Palace", "GateP", gate_palace, [("front", (0, -190, 40), (0, 0, 42)),
                                            ("corner", (150, -150, 110), (0, 0, 40))], 10),
    ("Gate_Hall", "GateH", gate_hall, [("front", (0, -130, 30), (0, 0, 24)),
                                        ("corner", (100, -90, 70), (0, 0, 22))], 10),
    ("Corridor", "Corr", corridor, [("corner", (60, -60, 40), (0, 0, 16))], 8),
    ("Corridor_Corner", "CorrC", corridor_corner, [("corner", (-50, -60, 55), (0, 0, 20)),
                                                    ("outer", (60, 60, 50), (0, 0, 20))], 8),
    ("Pavilion_Nugak", "Nugak", lambda g: lofty(g, 5, 4, 16.8, 22.0, 22.0, 12.0, 24.0, 8.0),
     [("front", (0, -170, 50), (0, 0, 40)), ("corner", (140, -130, 110), (0, 0, 36))], 10),
    ("Tower_Bell", "Bell", lambda g: lofty(g, 3, 2, 16.0, 14.0, 14.0, 9.0, 13.0, 5.0, bell=True),
     [("front", (0, -100, 30), (0, 0, 26)), ("corner", (80, -80, 70), (0, 0, 24))], 10),
    ("Palace_Chimjeon", "Chim", chimjeon, [("front", (0, -210, 50), (0, -10, 26)),
                                            ("corner", (160, -170, 110), (0, -10, 24))], 10),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, renders, min_objs in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = L.new_groups(prefix)
        fn(g)
        L.export_model(name, g, MODEL_SCALE, renders=renders, min_objs=min_objs)
