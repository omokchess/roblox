# -*- coding: utf-8 -*-
"""
build_yard_props.py — 마당 살림. 집 사이 빈 땅을 채운다.

  Prop_Well      우물. 돌 우물 둘레, 도르래 틀, 작은 기와 지붕, 두레박
  Prop_Jangdok   장독대. 돌 단 위에 크고 작은 독을 두 줄로
  Prop_Haystack  짚가리 둘과 짚단 몇
  Prop_Garden    텃밭. 흙 두둑 여섯 줄에 채소

독 크기와 자리는 표에 적었다. 다 같은 크기로 줄 세우면 공산품처럼 보인다.

돌리는 법: blender --background --python build_yard_props.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5


def well(g):
    # 돌 둘레. 바깥 원통을 돌로, 안쪽 윗면에 어두운 물 구멍을 얹는다
    g["Masonry"].cyl(0, 0, 0, 5.2, 4.8, 4.6, seg=16)
    g["Plinth"].cyl(0, 0, 4.6, 5.0, 5.0, 0.6, seg=16)
    g["RoofEdge"].cyl(0, 0, 5.15, 3.6, 3.6, 0.1, seg=16)
    # 바닥 돌판
    g["Stylobate"].box(0, 0, 0.2, 14.0, 14.0, 0.4)
    # 도르래 틀. 기둥 둘과 가로대, 그 위 작은 맞배지붕
    for s in (-1, 1):
        g["Beam"].box(s * 6.0, 0, 7.0, 1.2, 1.2, 14.0)
    g["Beam"].box(0, 0, 11.5, 13.4, 1.0, 1.0)
    rz = L.build_roof(g, 14.0, 12.0, 5.0, 1.8, 2.6, style="gable", thick=0.8, chimi=False,
                      eave=False, ridge=False, nx=12, ny=8, gable_ends=(False, False))
    g["RoofEdge"].box(0, 0, rz + 0.3, 15.0, 1.2, 0.8)
    g["Beam"].box(0, 0, 13.6, 14.0, 5.6, 0.6)   # 지붕을 받치는 판. 기둥 머리를 잇는다
    # 두레박. 줄에 매달아 우물 위에
    g["Lattice"].box(0, 0, 9.0, 0.15, 0.15, 5.0)
    g["Onggi"].cyl(0, 0, 5.6, 0.9, 1.1, 1.3, seg=10)


# 독. (x, y, 크기). 크기 1 이 큰 독이다
JARS = [
    (-5.6, 2.2, 1.0), (-1.8, 2.4, 0.92), (2.1, 2.1, 1.0), (5.9, 2.3, 0.86),
    (-6.0, -2.4, 0.62), (-3.4, -2.2, 0.7), (-0.6, -2.5, 0.58), (2.2, -2.3, 0.66), (5.0, -2.2, 0.6),
]


def jangdok(g):
    g["Stylobate"].box(0, 0, 0.45, 17.0, 10.0, 0.9)
    g["Masonry"].box(0, 0, 0.15, 17.6, 10.6, 0.3)
    z0 = 0.9
    for x, y, k in JARS:
        r = 1.9 * k
        # 굽, 배, 어깨, 뚜껑 네 켜로 옹기 곡선을 낸다
        g["Onggi"].cyl(x, y, z0, r * 0.62, r, 1.5 * k, seg=12)
        g["Onggi"].cyl(x, y, z0 + 1.5 * k, r, r * 1.02, 1.1 * k, seg=12)
        g["Onggi"].cyl(x, y, z0 + 2.6 * k, r * 1.02, r * 0.55, 1.4 * k, seg=12)
        g["Onggi"].cyl(x, y, z0 + 4.0 * k, r * 0.6, r * 0.6, 0.35 * k, seg=12)
        g["RoofEdge"].cyl(x, y, z0 + 4.35 * k, r * 0.68, r * 0.3, 0.6 * k, seg=12)


# 짚가리와 짚단. (x, y, 반지름, 높이)
STACKS = [(-3.5, 0.5, 4.4, 5.0), (5.2, 1.8, 3.2, 3.8)]
BUNDLES = [(1.2, -4.6, 0.0), (3.6, -4.2, 0.0), (-8.6, -2.4, 0.0)]


def haystack(g):
    for x, y, r, h in STACKS:
        g["Thatch"].cyl(x, y, 0, r * 0.88, r, h, seg=14)
        g["Thatch"].cyl(x, y, h, r, r * 0.12, h * 0.95, seg=14)
        # 꼭지를 묶은 짚
        g["Lattice"].cyl(x, y, h * 1.9, r * 0.14, r * 0.05, 0.9, seg=8)
        g["Beam"].cyl(x, y, h * 0.55, r * 0.97, r * 0.97, 0.35, seg=14)   # 허리를 두른 새끼
    for x, y, _ in BUNDLES:
        g["Thatch"].box(x, y, 0.8, 1.8, 4.0, 1.6)
        g["Beam"].box(x, y, 0.8, 1.9, 0.3, 1.6)  # 짚단보다 높으면 땅에 묻힌다


def garden(g):
    W, D = 22.0, 15.0
    g["Soil"].box(0, 0, 0.25, W, D, 0.5)
    # 가장자리 돌. 텃밭 둘레를 낮게
    for s in (-1, 1):
        g["Masonry"].box(0, s * (D / 2 + 0.4), 0.45, W + 1.6, 0.8, 0.9)
        g["Masonry"].box(s * (W / 2 + 0.4), 0, 0.45, 0.8, D, 0.9)
    rows = 6
    for i in range(rows):
        y = -D / 2 + D * (i + 0.5) / rows
        g["Soil"].box(0, y, 0.75, W - 2.0, 1.4, 0.5)
        # 채소. 줄마다 포기 수를 달리해 가지런하지 않게 한다
        n = (7, 6, 8, 5, 7, 6)[i]
        for k in range(n):
            x = -W / 2 + 2.2 + (W - 4.4) * k / (n - 1)
            s = (1.0, 0.8, 1.15, 0.9)[(i + k) % 4]
            g["Leaf"].box(x, y, 1.0 + 0.55 * s, 1.2 * s, 1.2 * s, 1.1 * s)


BUILDS = [
    ("Prop_Well", "Well", well, (22, -26, 20), (0, 0, 7)),
    ("Prop_Jangdok", "Jang", jangdok, (18, -20, 14), (0, 0, 2)),
    ("Prop_Haystack", "Hay", haystack, (20, -24, 16), (0, 0, 4)),
    ("Prop_Garden", "Garden", garden, (22, -24, 18), (0, 0, 0)),
]

for name, prefix, fn, cam, look in BUILDS:
    L.clear_scene()
    g = L.new_groups(prefix)
    fn(g)
    L.export_model(name, g, MODEL_SCALE, renders=[("corner", cam, look)], min_objs=2)
