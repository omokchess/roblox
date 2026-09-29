# -*- coding: utf-8 -*-
"""
build_hall.py — 일반 건물. 정면 5칸 측면 3칸 마루집.

궁이 아니라 어디에나 쓰는 한 채다. 안은 비어 있다.
가운데 칸이 드나드는 문, 양옆 칸이 창살 문짝, 나머지는 뚫린 창이다.

돌리는 법: blender --background --python build_hall.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

NAME = "Building_Hall"
MODEL_SCALE = 0.5

W, D = 78.0, 52.0
COL_H = 26.0
EAVE_OUT = 8.5
ROOF_H = 19.0


def build(g):
    floor = L.stylobate(g, W, D, 4.0, 3.0)
    xs, ys = L.column_grid(W, D, 5, 3)
    top = L.columns(g, xs, ys, floor, COL_H)
    roof_z = L.beams(g, xs, ys, top)
    L.dancheong(g, W, D, top)
    wall_h = COL_H + 1.8
    L.walls(g, xs, ys, floor, wall_h,
            front=["window", "lattice", "open", "lattice", "window"],
            back=["window"] * 5,
            side=["window"] * 3)
    g["Stylobate"].box(0, 0, floor + 0.4, W - 2, D - 2, 0.8)
    L.build_roof(g, roof_z, W, D, EAVE_OUT, ROOF_H)


L.clear_scene()
g = L.new_groups("Hall")
build(g)
L.export_model(NAME, g, MODEL_SCALE, renders=[
    ("front", (0, -150, 52), (0, 0, 30)),
    ("corner", (118, -108, 86), (0, 0, 26)),
], min_objs=10)
