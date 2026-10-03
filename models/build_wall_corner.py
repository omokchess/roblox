# -*- coding: utf-8 -*-
"""
build_wall_corner.py — 2026-10-03. 기와 담(Wall_Segment) ㄱ자 모서리 마감 Wall_Corner.

사용자(2026-10-03): "요런 담 모서리 부분도 자연스럽게 수정해줄 수 있어?" — 담 토막 둘이 모서리에서 맞배 끝(박공)으로
끝나 기와 사이가 비고 벽면이 어긋나 보였다.

모양(블렌더 치수, 배율 0.5 전. 원점 = 두 담 가운데선이 만나는 점, 두 팔은 +x 와 +y):
  - 바깥 귀는 추녀(두 지붕 면이 대각선에서 만나는 우진각 귀), 안쪽은 골. 대각선 y = x 를 경계로
    y < x 는 +x 팔 지붕(높이 = f(|y|)), y > x 는 +y 팔 지붕(f(|x|)).
  - 지붕 단면 f 는 build_gate.py wall() 의 build_roof(style="gable", W=40, D=3.2, eave_out=2.4, H=2.8, exp=1.42) 와 같다.
  - 팔은 모서리에서 E 만큼 담 토막 위로 덮어 나간다(토막 끝이 모서리 가운데보다 1 스터드 안에서 끝나는 곳도 있다).
    겹친 곳에서 면이 같으면 깜빡이므로 지붕은 DZ 만큼 높이고, 돌 켜·회벽은 0.4 두껍게 해 모서리 기둥(기둥 담)처럼 보이게 한다.
  - 용마루: 두 팔 마루 + 바깥 귀 추녀마루(대각선, 곡선을 네 토막으로)
  - 지붕 밑 빈 세모(박공 자리)는 회벽으로 채운다
로블록스에서는 담 토막처럼 세로를 늘린다(Wall_Segment 와 같은 배율, tools/Jeolhwa_WallCorner.luau).

돌리는 법: blender --background --python build_wall_corner.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

SCALE = 0.5
T = 3.2          # 회벽 두께(Wall_Segment WALL_T)
H = 13.0         # 담 높이(WALL_H)
BASE = H + 0.6   # 지붕 밑 높이
B = T / 2 + 2.4  # 처마까지 반폭
RH = 2.8         # 지붕 높이
THICK = 1.0
EXP = 1.42
E = 6.0          # 팔이 모서리 가운데에서 나가는 길이(3 스터드)
DZ = 0.3         # 토막 지붕보다 높이는 만큼
PIER = 0.4       # 돌 켜·회벽을 두껍게 하는 만큼
STEP = 0.25      # 지붕 격자(대각선이 꼭짓점을 지나게 x·y 같은 간격)


def f(d):
    """용마루에서 d 떨어진 곳의 지붕 윗면 높이(BASE 기준)"""
    return RH * (max(0.0, B - d) / B) ** EXP + DZ


def roof_h(x, y):
    return f(abs(y)) if y < x else f(abs(x))


def field(grp, fn, x0, x1, y0, y1, z_of, thick, step=STEP):
    """fn(x, y) 위 판을 닫힌 덩이로. 네모 칸을 (i,j)-(i+1,j+1) 대각선으로 갈라 y = x 골·추녀가 꺾이게 한다"""
    nx, ny = int(round((x1 - x0) / step)), int(round((y1 - y0) / step))
    top, bot = [], []
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        for j in range(ny + 1):
            y = y0 + (y1 - y0) * j / ny
            z = z_of(fn(x, y))
            top.append((x, y, z))
            bot.append((x, y, z - thick))
    n = len(top)

    def idx(i, j):
        return i * (ny + 1) + j

    faces = []
    for i in range(nx):
        for j in range(ny):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            faces += [(a, b, c), (a, c, d)]
            faces += [(a + n, c + n, b + n), (a + n, d + n, c + n)]
    for i in range(nx):
        for j0 in (0, ny):
            a, b = idx(i, j0), idx(i + 1, j0)
            faces.append((a, b, b + n, a + n))
    for j in range(ny):
        for i0 in (0, nx):
            a, b = idx(i0, j), idx(i0, j + 1)
            faces.append((a, b, b + n, a + n))
    grp.add_mesh(top + bot, faces)


def corner(g):
    # 돌 켜·띠돌·회벽·도리: ㄱ자 두 상자(겹치지 않게 +y 팔은 코어 바깥부터)
    def ell(grp, half, z0, z1):
        grp.box((E - half) / 2, 0, (z0 + z1) / 2, E + half, 2 * half, z1 - z0)
        grp.box(0, (E + half) / 2, (z0 + z1) / 2, 2 * half, E - half, z1 - z0)
    ell(g["Masonry"], (T + 0.8 + PIER) / 2, 0.0, 5.0)
    ell(g["Wall"], (T + PIER) / 2, 5.0, H)
    ell(g["Stylobate"], (T + 1.0 + PIER) / 2, 5.0, 5.4)
    ell(g["Beam"], (T + 1.0 + PIER) / 2, H, BASE)

    # 지붕: +x 팔과 코어(대각선으로 갈림), +y 팔 나머지
    z_roof = lambda h: BASE + h
    field(g["Roof"], roof_h, -B, E, -B, B, z_roof, THICK)
    field(g["Roof"], lambda x, y: f(abs(x)), -B, B, B, E, z_roof, THICK)

    # 지붕 밑 세모를 회벽으로 채운다(윗면 = 지붕 밑면 − 0.05). 회벽 두께 안만
    hw = (T + PIER) / 2
    z_fill = lambda h: BASE + h - THICK - 0.05
    fill_h = lambda x, y: roof_h(x, y)
    # 두께 2.2: 가장 낮은 윗면(회벽 바깥선 14.05)과 가장 높은 윗면(용마루 15.65) 모두 밑이 도리(13.6) 안에 든다
    field(g["Wall"], fill_h, -hw, E, -hw, hw, z_fill, 2.2, step=hw / 4)
    field(g["Wall"], lambda x, y: f(abs(x)), -hw, hw, hw, E, z_fill, 2.2, step=hw / 4)

    # 마루: 두 팔 + 바깥 귀 추녀마루
    rz = BASE + f(0.0)
    g["RoofEdge"].box((E - 0.8) / 2, 0, rz + 0.3, E + 0.8, 1.6, 0.9)
    g["RoofEdge"].box(0, (E - 0.8) / 2, rz + 0.3, 1.6, E + 0.8, 0.9)
    seg = 4
    for k in range(seg):
        d0, d1 = B * k / seg, B * (k + 1) / seg            # 대각선 위 |x| = |y| 거리
        p0 = (-d0, -d0, BASE + f(d0) + 0.25)
        p1 = (-d1, -d1, BASE + f(d1) + 0.25)
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        horiz = math.hypot(dx, dy)
        length = math.hypot(horiz, dz) + 0.35
        pitch = math.atan2(dz, horiz)
        g["RoofEdge"].obox((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2,
                           length, 1.2, 0.7, ry=-pitch, rz=math.radians(225))

    # 원점 표지(가져온 뒤 원점을 되찾는다)
    g["Marker"].box(0, 0, 0.2, 0.4, 0.4, 0.4)


PALETTE = dict(L.PALETTE)
PALETTE["Marker"] = "#ff00ff"
L.clear_scene()
g = L.new_groups("WallC", PALETTE)
corner(g)
fbx, tris, nobj, size = L.export_model("Wall_Corner", g, SCALE, renders=[
    ("outer", (-30, -34, 26), (0, 0, 13)),
    ("hip", (-13, -15, 24), (-1, -1, 15)),
    ("inner", (26, 30, 24), (0, 0, 13)),
], min_objs=5, palette=PALETTE)
