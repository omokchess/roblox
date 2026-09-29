# -*- coding: utf-8 -*-
"""
build_palace.py — 절화의 궁. 중층 정전 한 채.

일반 건물(build_hall)과 무엇이 다른가
  월대    두 단으로 높이 올리고 둘레에 난간을 두른다. 계단 셋, 가운데가 넓다
  아래층  정면 7칸 측면 4칸. 앞면은 가운데 문과 창살 문짝이 줄지어 선다
  위층    정면 5칸 측면 2칸. 아래층 지붕 위에 올라앉는다
  지붕    둘. 아래층 지붕은 치마처럼 두르고, 위층 지붕이 크게 덮는다

**위층을 아래층 지붕 위에 그냥 얹으면 뜬다.** 아래 지붕은 가장자리로 갈수록 낮아서
위층 벽 밑과 지붕면 사이에 틈이 난다. 그래서 아래 지붕 바닥부터 위층 마루까지
목조 기단을 한 켜 세워 틈을 메운다. 이 켜가 중층 건물의 허리로 보인다.

돌리는 법: blender --background --python build_palace.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

NAME = "Palace_Main"
MODEL_SCALE = 0.5

# 아래층
W1, D1 = 120.0, 72.0
COL_H1 = 30.0
# 위층
W2, D2 = 84.0, 40.0
COL_H2 = 16.0


def terrace(g):
    """월대 두 단과 계단 셋, 난간. 돌려주는 값은 마루 높이다"""
    T1W, T1D, T1H = W1 + 64, D1 + 56, 5.0
    T2W, T2D, T2H = W1 + 34, D1 + 28, 5.0
    g["Stylobate"].box(0, 0, T1H / 2, T1W, T1D, T1H)
    g["Stylobate"].box(0, 0, T1H + T2H / 2, T2W, T2D, T2H)
    g["Stylobate"].box(0, 0, T1H + T2H + 1.5, W1 + 8, D1 + 8, 3.0)
    floor = T1H + T2H + 3.0

    # 계단. 아래 단 앞에서 땅부터 위 단까지 한 번에 오른다
    STAIRS = [(0.0, 34.0), (-44.0, 14.0), (44.0, 14.0)]
    for cx, sw in STAIRS:
        L.stair(g, cx, -T1D / 2, T1H + T2H, sw, steps=9, tread=2.4)
    # 가운데 계단 한복판의 답도. 임금만 오르는 돌판.
    # 기울인 판 하나로 두면 계단 중간에 뜬다. 단마다 한 조각씩 얹는다
    for k in range(9):
        h = (T1H + T2H) * (k + 1) / 9
        g["Ochre"].box(0, -T1D / 2 - 2.4 * (9 - k) + 1.2, h + 0.2, 8.0, 2.4, 0.4)

    # 난간. 위 단 가장자리를 두르되 계단 자리는 비운다
    z = T1H + T2H
    x0, x1 = -T2W / 2 + 1, T2W / 2 - 1
    y0, y1 = -T2D / 2 + 1, T2D / 2 - 1
    gaps = sorted([(cx - sw / 2 - 3, cx + sw / 2 + 3) for cx, sw in STAIRS])
    cur = x0
    for a, b in gaps:
        if a > cur:
            L.railing(g, cur, y0, a, y0, z)
        cur = b
    if cur < x1:
        L.railing(g, cur, y0, x1, y0, z)
    L.railing(g, x0, y1, x1, y1, z)
    L.railing(g, x0, y0, x0, y1, z)
    L.railing(g, x1, y0, x1, y1, z)
    return floor


def build(g):
    floor = terrace(g)

    # 아래층
    xs, ys = L.column_grid(W1, D1, 7, 4)
    top1 = L.columns(g, xs, ys, floor, COL_H1, r=2.4)
    roof1_z = L.beams(g, xs, ys, top1)
    L.dancheong(g, W1, D1, top1)
    L.walls(g, xs, ys, floor, COL_H1 + 1.8,
            front=["window", "lattice", "lattice", "open", "lattice", "lattice", "window"],
            back=["window", "window", "window", "lattice", "window", "window", "window"],
            side=["window", "window", "window", "window"])
    g["Stylobate"].box(0, 0, floor + 0.4, W1 - 2, D1 - 2, 0.8)

    # 아래층 지붕. 낮고 넓게 둘러 치마처럼 보이게 한다
    # 지붕 둘이 한 오브젝트에 들어가므로 격자를 줄여 삼각형 한도 10000 안에 맞춘다
    ridge1 = L.build_roof(g, roof1_z, W1, D1, 10.0, 13.0, chimi=False, ridge=False, nx=36, ny=22)

    # 위층 허리. 아래 지붕 바닥에서 위층 마루까지 메운다. 이게 없으면 위층이 뜬다
    floor2 = ridge1 + 1.0
    waist_h = floor2 - roof1_z
    g["Beam"].box(0, 0, roof1_z + waist_h / 2, W2 + 4, D2 + 4, waist_h)
    g["Trim"].box(0, -(D2 / 2 + 2.1), floor2 - 1.4, W2 + 4.4, 0.4, 1.4)
    g["Trim"].box(0, (D2 / 2 + 2.1), floor2 - 1.4, W2 + 4.4, 0.4, 1.4)

    # 위층
    xs2, ys2 = L.column_grid(W2, D2, 5, 2)
    top2 = L.columns(g, xs2, ys2, floor2, COL_H2, r=1.9, plinth=False)
    roof2_z = L.beams(g, xs2, ys2, top2)
    L.dancheong(g, W2, D2, top2)
    L.walls(g, xs2, ys2, floor2, COL_H2,
            front=["window", "lattice", "lattice", "lattice", "window"],
            back=["window"] * 5,
            side=["window", "window"])

    # 위층 지붕. 크게 덮는다
    L.build_roof(g, roof2_z, W2, D2, 13.0, 24.0, nx=40, ny=24)

    # 현판. 위층 정면 가운데
    g["RoofEdge"].box(0, -(D2 / 2 + 2.6), top2 - 3.5, 16.0, 0.8, 5.0)
    g["Ochre"].box(0, -(D2 / 2 + 3.1), top2 - 3.5, 13.0, 0.4, 3.4)


L.clear_scene()
g = L.new_groups("Palace")
build(g)
L.export_model(NAME, g, MODEL_SCALE, renders=[
    ("front", (0, -270, 80), (0, 0, 50)),
    ("corner", (210, -200, 150), (0, 0, 45)),
], min_objs=10)
