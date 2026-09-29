# -*- coding: utf-8 -*-
"""
build_pavilion.py — 정자. Pavilion_Jeongja.

정면 2칸 측면 2칸, 벽 없이 사방이 트였다.
  돌기둥 위에 나무 마루를 높이 띄우고(누마루), 마루 끝을 난간으로 두른다
  가운데 기둥은 빼서 안이 한 칸으로 트인다
  지붕은 사모지붕. 네 면이 한 점으로 모이고 꼭대기에 절병통을 얹는다
앞 계단 자리만 난간을 비운다.

돌리는 법: blender --background --python build_pavilion.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

NAME = "Pavilion_Jeongja"
MODEL_SCALE = 0.5

S = 34.0          # 기둥 중심 사이 한 변
PIER_H = 8.0      # 돌기둥
DECK_T = 1.6      # 마루 두께
DECK_OUT = 3.0    # 마루가 기둥 밖으로 나오는 폭
COL_H = 17.0
STAIR_W = 10.0


def build(g):
    xs, ys = L.column_grid(S, S, 2, 2)

    # 바닥 돌판. 돌기둥을 받친다
    g["Stylobate"].box(0, 0, 0.6, S + 12, S + 12, 1.2)
    # 돌기둥. 네모 기둥에 윗돌을 한 켜 얹는다
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            if i == 1 and j == 1:
                continue
            g["Masonry"].box(x, y, 1.2 + PIER_H / 2, 3.6, 3.6, PIER_H)
            g["Plinth"].box(x, y, 1.2 + PIER_H - 0.5, 4.6, 4.6, 1.0)
    # 가운데 돌기둥. 마루가 처지지 않게 아래만 받친다
    g["Masonry"].box(0, 0, 1.2 + PIER_H / 2, 3.0, 3.0, PIER_H)

    deck_z = 1.2 + PIER_H
    # 마루 밑 귀틀. 돌기둥 머리를 잇는다
    for y in ys:
        g["Beam"].box(0, y, deck_z + 0.6, S + 3, 2.0, 1.2)
    for x in xs:
        g["Beam"].box(x, 0, deck_z + 0.6, 2.0, S + 3, 1.2)
    E = S + DECK_OUT * 2
    g["Beam"].box(0, 0, deck_z + 1.2 + DECK_T / 2, E, E, DECK_T)
    floor = deck_z + 1.2 + DECK_T
    # 마루널 줄. 판 위에 얇게 덧대 결을 낸다
    for k in range(9):
        x = -E / 2 + E * (k + 0.5) / 9
        g["Bracket"].box(x, 0, floor + 0.05, 0.35, E - 0.4, 0.1)

    # 계단. 땅에서 마루까지
    # 돌 볼막이로 막으면 계단이 덩어리에 묻힌다. 나무 계단에 얇은 옆판만 댄다
    L.stair(g, 0, -E / 2, floor - 1.2, STAIR_W, steps=6, tread=2.2, cheek=False, base_z=1.2)
    run = 2.2 * 6
    for s in (-1, 1):
        x = s * (STAIR_W / 2 + 0.5)
        verts = [(x - 0.5, -E / 2 - run, 1.2), (x - 0.5, -E / 2, 1.2), (x - 0.5, -E / 2, floor + 0.8),
                 (x + 0.5, -E / 2 - run, 1.2), (x + 0.5, -E / 2, 1.2), (x + 0.5, -E / 2, floor + 0.8)]
        g["Beam"].add_mesh(verts, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)])
        # 계단 난간. 옆판 빗면을 따라 기둥 둘과 손잡이
        g["Lattice"].box(x, -E / 2 - run + 0.6, 1.2 + 2.0, 0.8, 0.8, 4.0)
        g["Lattice"].box(x, -E / 2 - 0.4, floor + 2.0, 0.8, 0.8, 4.0)

    top = L.columns(g, xs, ys, floor, COL_H, r=1.5, plinth=False)
    roof_z = L.beams(g, xs, ys, top)
    L.dancheong(g, S, S, top)

    # 난간. 마루 끝을 두르고 앞 계단 자리는 비운다
    h = E / 2 - 0.6
    gap = STAIR_W / 2 + 0.8
    L.railing(g, -h, -h, -gap, -h, floor, h=3.6)
    L.railing(g, gap, -h, h, -h, floor, h=3.6)
    L.railing(g, -h, h, h, h, floor, h=3.6)
    L.railing(g, -h, -h, -h, h, floor, h=3.6)
    L.railing(g, h, -h, h, h, floor, h=3.6)

    # 기둥 사이 머리 쪽 낙양. 트인 칸 위를 살짝 막아 정자답게 한다
    for i in range(2):
        cx = (xs[i] + xs[i + 1]) / 2
        span = xs[i + 1] - xs[i] - 3.0
        for y in ys[0], ys[-1]:
            g["Lattice"].box(cx, y, top - 1.8, span, 0.8, 0.5)
            for k in range(6):
                g["Lattice"].box(cx - span / 2 + span * (k + 0.5) / 6, y, top - 1.0, 0.4, 0.7, 1.6)
        for x in xs[0], xs[-1]:
            g["Lattice"].box(x, cx, top - 1.8, 0.8, span, 0.5)
            for k in range(6):
                g["Lattice"].box(x, cx - span / 2 + span * (k + 0.5) / 6, top - 1.0, 0.7, 0.4, 1.6)

    L.build_roof(g, roof_z, S, S, 9.0, 17.0, style="hip", ridge_half=0.0, nx=40, ny=40)


L.clear_scene()
g = L.new_groups("Pavilion")
build(g)
L.export_model(NAME, g, MODEL_SCALE, renders=[
    ("front", (0, -110, 30), (0, 0, 22)),
    ("corner", (80, -80, 58), (0, 0, 20)),
], min_objs=10)
