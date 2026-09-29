# -*- coding: utf-8 -*-
"""
build_gate.py — 절화의 문과 담.

  Gate_Main    솟을대문. 가운데 문간을 높이 솟게 하고 양옆에 문간방을 낮게 붙인다
  Wall_Segment 기와 얹은 담 한 토막. 끝과 끝을 이어 붙여 두른다

**담 토막은 이어 붙이므로 기와 처마를 양 끝에서 자른다.** 안 자르면 이웃 토막 기와와
겹쳐 깜빡인다. 대문 양옆 지붕도 같은 까닭으로 가운데 쪽을 잘라 솟은 지붕 밑에 맞붙인다.

돌리는 법: blender --background --python build_gate.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5

# 대문
PASS_W = 22.0     # 가운데 문간 폭
ROOM_W = 17.0     # 문간방 폭
GD = 20.0         # 깊이
PASS_H = 34.0
ROOM_H = 17.0

# 담
WALL_LEN = 40.0
WALL_H = 13.0
WALL_T = 3.2


def gate(g):
    half = PASS_W / 2
    outer = half + ROOM_W
    g["Stylobate"].box(0, 0, 0.75, outer * 2 + 4, GD + 6, 1.5)
    floor = 1.5

    # 가운데 문간. 네 기둥이 높이 선다
    xs, ys = [-half, half], [-GD / 2, GD / 2]
    top_p = L.columns(g, xs, ys, floor, PASS_H, r=1.7)
    roof_p = L.beams(g, xs, ys, top_p, brackets=False)
    L.dancheong(g, PASS_W, GD, top_p)
    # 대문 문짝. 활짝 열어 안쪽 벽에 붙인다. 문지방은 턱을 낮게
    door_h = PASS_H - 6.0
    for s in (-1, 1):
        g["Lattice"].box(s * (half - 1.6), -GD / 2 + 5.8, floor + 1.8 + door_h / 2, 1.0, 10.0, door_h)
        for k in range(4):
            g["Eave"].box(s * (half - 2.2), -GD / 2 + 5.8, floor + 1.8 + door_h * (k + 0.5) / 4,
                          0.3, 10.2, 0.8)
    g["Beam"].box(0, -GD / 2 + 0.8, floor + PASS_H - 2.5, PASS_W, 1.6, 4.0)   # 문 윗인방
    g["Beam"].box(0, -GD / 2 + 0.8, floor + 0.2, PASS_W, 1.6, 0.4)            # 문지방
    # 문 위 홍살. 붉은 살을 촘촘히 세운다
    for k in range(11):
        x = -half + PASS_W * (k + 0.5) / 11
        g["Column"].box(x, -GD / 2 + 0.8, floor + PASS_H + 0.4, 0.5, 0.5, 3.0)

    ridge_p = L.build_roof(g, roof_p, PASS_W, GD, 7.0, 11.0, style="gable", chimi=False,
                           nx=24, ny=24)

    # 문간방 둘. 가운데 쪽 처마는 잘라서 솟은 기둥에 맞붙인다
    for s in (-1, 1):
        cx = s * (half + ROOM_W / 2)
        rxs = sorted([s * half, s * outer])
        L.columns(g, [s * outer], ys, floor, ROOM_H, r=1.6)
        top_r = floor + 1.8 + ROOM_H
        roof_r = L.beams(g, rxs, ys, top_r, brackets=False)
        L.walls(g, rxs, ys, floor, ROOM_H + 1.8,
                front=["window"], back=["window"], side=["solid"])
        if s < 0:
            cut = dict(x_hi=ROOM_W / 2 - 0.2)
        else:
            cut = dict(x_lo=-ROOM_W / 2 + 0.2)
        L.build_roof(g, roof_r, ROOM_W, GD, 7.0, 8.5, style="gable", chimi=False,
                     cx=cx, nx=20, ny=24, **cut)
    assert roof_r + 8.5 + 3.4 < roof_p - 2.0, "문간방 용마루가 솟은 지붕 처마를 뚫는다"


def wall(g):
    # 아래 돌 켜, 위 회벽, 기와 머리. 기와 처마는 양 끝에서 자른다
    g["Masonry"].box(0, 0, 2.5, WALL_LEN, WALL_T + 0.8, 5.0)
    g["Wall"].box(0, 0, 5.0 + (WALL_H - 5.0) / 2, WALL_LEN, WALL_T, WALL_H - 5.0)
    # 돌 켜 위 띠돌 한 줄. 네모 무늬는 멀리서 구멍으로 읽혀 쓰지 않는다
    g["Stylobate"].box(0, 0, 5.2, WALL_LEN, WALL_T + 1.0, 0.4)
    g["Beam"].box(0, 0, WALL_H + 0.3, WALL_LEN, WALL_T + 1.0, 0.6)
    ridge_z = L.build_roof(g, WALL_H + 0.6, WALL_LEN, WALL_T, 2.4, 2.8, style="gable", thick=1.0,
                           lift=0.0, chimi=False, eave=False, ridge=False, nx=16, ny=6,
                           x_lo=-WALL_LEN / 2, x_hi=WALL_LEN / 2)
    # 담 용마루는 가늘게. 지붕용 마루를 쓰면 담에 비해 너무 굵다
    g["RoofEdge"].box(0, 0, ridge_z + 0.3, WALL_LEN, 1.6, 0.9)


L.clear_scene()
g = L.new_groups("Gate")
gate(g)
L.export_model("Gate_Main", g, MODEL_SCALE, renders=[
    ("front", (0, -130, 30), (0, 0, 20)),
    ("corner", (100, -95, 60), (0, 0, 18)),
], min_objs=10)

L.clear_scene()
g = L.new_groups("Wall")
wall(g)
L.export_model("Wall_Segment", g, MODEL_SCALE, renders=[
    ("corner", (45, -45, 25), (0, 0, 7)),
], min_objs=4)
