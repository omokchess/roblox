# -*- coding: utf-8 -*-
"""
build_town2.py — 저잣거리와 곳간. (2026-09-26)

  Shop_Row5   시전 행랑 다섯 칸. 칸마다 칸막이, 앞은 트였고 들어열개 덧문을 처마 밑에 들어 올렸다
  Shop_Row3   같은 행랑 세 칸
  Granary     곳간. 돌 받침 위에 마루를 띄운 판벽 창고. 앞 가운데 칸에 문과 돌계단

칸마다 무엇을 파는지는 GOODS 표에 적는다. 다섯 칸이 다 같은 물건이면 공산품 진열대처럼 보인다.
"open" 칸은 좌판 없이 비워 두어 안으로 드나든다.

돌리는 법: blender --background --python build_town2.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5
BAY, SD, SCOL = 18.0, 24.0, 17.0


def shop_row(g, plan):
    n = len(plan)
    W, D = n * BAY, SD
    g["Stylobate"].box(0, 0, 0.8, W + 6, D + 6, 1.6)
    floor = 1.6
    xs, ys = L.column_grid(W, D, n, 1)
    top = L.columns(g, xs, ys, floor, SCOL, r=1.4)
    roof_z = L.beams(g, xs, ys, top, brackets=False)
    wall_h = SCOL + 1.8
    back = ["window" if i % 2 == 0 else "solid" for i in range(n)]
    L.walls(g, xs, ys, floor, wall_h, front=["none"] * n, back=back, side=["solid"])
    for x in xs[1:-1]:
        g["Wall"].box(x, 0, floor + wall_h / 2, 1.2, D - 1.0, wall_h)
    g["Beam"].box(0, 1.0, floor + 0.3, W - 2.0, D - 4.0, 0.6)       # 마루

    front_y = -D / 2
    for i, kind in enumerate(plan):
        cx = (xs[i] + xs[i + 1]) / 2
        # 들어열개. 처마 밑 도리에 걸어 바깥으로 들어 올렸다. 35 도
        a = math.radians(35.0)
        pl = 7.0
        g["Lattice"].obox(cx, front_y - math.cos(a) * pl / 2, top - 0.6 + math.sin(a) * pl / 2,
                          BAY - 3.4, pl, 0.6, rx=math.pi - a)
        if kind == "open":
            continue
        g["Beam"].box(cx, front_y + 3.2, floor + 1.6, BAY - 4.0, 5.0, 3.2)   # 좌판
        g["Eave"].box(cx, front_y + 3.2, floor + 3.3, BAY - 3.6, 5.4, 0.3)
        # 좌판 위 물건과 칸 뒤 독·궤짝은 2026-09-27 부터 모델에 넣지 않는다. 색 많은 안살림 소품
        # (models/build_hanok_props.py 의 Stall_*, Suldok, Gwe)으로 tools/Jeolhwa_Interiors.luau 가 얹는다

    # 깃발. 맨 왼쪽 칸 앞에 장대를 세우고 무명 기를 단다. 멀리서 가게 줄임을 알린다
    # 처마(6.5) 밖으로 내고 지붕 선보다 높여야 멀리서 보인다
    px, py = -W / 2 + 3.0, front_y - 9.0
    g["Lattice"].box(px, py, 20.0, 0.8, 0.8, 40.0)
    g["Lattice"].box(px + 2.6, py, 38.4, 5.6, 0.5, 0.5)
    g["Paper"].box(px + 2.8, py, 32.0, 4.4, 0.3, 12.4)
    g["Trim"].box(px + 2.8, py, 26.4, 4.4, 0.34, 0.6)

    L.build_roof(g, roof_z, W, D, 6.5, 11.0, style="gable", chimi=False, nx=10 * n, ny=24)


def granary(g):
    W, D, COL = 48.0, 28.0, 15.0
    xs, ys = L.column_grid(W, D, 3, 2)
    POST = 4.0
    for x in xs:
        for y in ys:
            g["Masonry"].box(x, y, POST / 2, 3.2, 3.2, POST)
    g["Beam"].box(0, 0, POST + 0.7, W + 2.4, D + 2.4, 1.4)
    floor = POST + 1.4
    top = L.columns(g, xs, ys, floor, COL, r=1.3, plinth=False)
    roof_z = L.beams(g, xs, ys, top, brackets=False)
    # 판벽. walls 가 쓰는 "Wall" 을 나무 판으로 바꿔 끼운다
    wood = dict(g)
    wood["Wall"] = g["Lattice"]
    L.walls(wood, xs, ys, floor, COL, front=["solid", "open", "solid"], back=["solid"] * 3,
            side=["solid", "solid"])
    # 판자 이음줄. 바깥 면에 가로 띠를 일정하게 덧댄다
    for k in range(1, 7):
        z = floor + COL * k / 7
        for s in (-1, 1):
            g["Eave"].box(0, s * (D / 2 + 1.0), z, W, 0.3, 0.35)
            g["Eave"].box(s * (W / 2 + 1.0), 0, z, 0.3, D, 0.35)
    # 문짝 하나. 반쯤 열려 있다
    door_w = (xs[2] - xs[1]) * 0.72
    hx = xs[1] + (xs[2] - xs[1] - door_w) / 2
    g["Eave"].obox(hx + math.cos(1.2) * door_w / 4, -D / 2 - math.sin(1.2) * door_w / 4, floor + (COL - 5.0) / 2 + 1.2,
                   door_w / 2, 0.9, COL - 5.0, rz=-1.2)
    L.stair(g, 0, -D / 2 - 1.2, floor, 12.0, steps=3, tread=2.2)
    L.build_roof(g, roof_z, W, D, 6.0, 11.0, style="gable", chimi=False, nx=36, ny=24)


JOBS = [
    ("Shop_Row5", "Shop5", lambda g: shop_row(g, ["jars", "cloth", "open", "crates", "baskets"]),
     [("front", (0, -150, 36), (0, 0, 14)), ("corner", (-120, -110, 70), (0, 0, 12))]),
    ("Shop_Row3", "Shop3", lambda g: shop_row(g, ["cloth", "open", "baskets"]),
     [("front", (0, -110, 30), (0, 0, 12)), ("corner", (-90, -80, 55), (0, 0, 12))]),
    ("Granary", "Gran", granary,
     [("front", (0, -110, 30), (0, 0, 14)), ("corner", (90, -80, 60), (0, 0, 12))]),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, renders in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = L.new_groups(prefix)
        fn(g)
        L.export_model(name, g, MODEL_SCALE, renders=renders, min_objs=8)
