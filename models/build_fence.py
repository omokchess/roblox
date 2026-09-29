# -*- coding: utf-8 -*-
"""
build_fence.py — 마을 담과 울타리. 모두 길이 40(배율 뒤 20 스터드)이라 서로 이어 붙는다.

  Wall_Stone    돌담. 크고 작은 돌을 켜마다 엇갈려 쌓고 위에 기와를 한 줄 얹는다
  Fence_Brush   싸리 울타리. 말뚝 사이에 가는 싸리를 촘촘히 세우고 가로대로 묶는다
  Wall_GateTile 기와 담에 낸 작은 대문. Wall_Segment 와 같은 담에 끼운다
  Fence_Gate    싸리문. 울타리나 돌담 사이에 끼운다

돌 크기와 자리는 아래 표에 적었다. 난수로 흩으면 매번 모양이 달라지고 틈이 생긴다.

돌리는 법: blender --background --python build_fence.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

MODEL_SCALE = 0.5
LEN = 40.0

# 돌담 켜. (켜 높이, [돌 길이...]). 한 켜의 길이 합은 LEN 이다.
# 윗켜와 아랫켜의 이음매가 겹치지 않게 적었다
STONE_COURSES = [
    (3.2, [7.0, 5.5, 8.0, 6.0, 7.5, 6.0]),
    (2.6, [4.0, 7.0, 6.0, 8.5, 5.0, 9.5]),
    (2.4, [6.5, 5.0, 7.5, 6.0, 8.0, 7.0]),
    (2.0, [3.5, 8.0, 6.5, 5.5, 9.0, 7.5]),
]
STONE_T = 5.0


def stone_wall(g):
    z = 0.0
    for k, (h, stones) in enumerate(STONE_COURSES):
        assert abs(sum(stones) - LEN) < 1e-6, "돌담 %d 켜 길이가 %.1f" % (k, sum(stones))
        x = -LEN / 2
        # 켜마다 두께를 조금 줄여 위로 갈수록 들여쌓는다
        t = STONE_T - k * 0.35
        for i, s in enumerate(stones):
            # 돌마다 앞뒤로 조금 튀어나오고 들어가게 한다. 표의 순서로 정한 값이라 늘 같다
            bulge = (0.35, -0.2, 0.15, -0.3, 0.25, 0.0)[i % 6]
            g["Masonry"].box(x + s / 2, bulge * 0.5, z + h / 2, s - 0.25, t + bulge, h - 0.2)
            x += s
        # 켜 사이 줄눈. 돌 틈이 비어 보이지 않게 속을 채운다
        g["Plinth"].box(0, 0, z + h / 2, LEN, t - 0.8, h)
        z += h
    top = z
    # 기와 한 줄. 돌담이라 낮고 얇다
    g["Stylobate"].box(0, 0, top + 0.25, LEN, STONE_T - 1.0, 0.5)
    ridge_z = L.build_roof(g, top + 0.5, LEN, STONE_T - 1.6, 1.6, 1.8, style="gable", thick=0.8,
                           lift=0.0, chimi=False, eave=False, ridge=False, nx=12, ny=6,
                           x_lo=-LEN / 2, x_hi=LEN / 2, gable_ends=(False, False))
    g["RoofEdge"].box(0, 0, ridge_z + 0.2, LEN, 1.2, 0.7)


def brush_fence(g):
    H = 9.0
    # 말뚝 셋. 양 끝 말뚝은 반만 이 토막에 속하게 끝에 붙인다
    for x in (-LEN / 2 + 0.6, 0.0, LEN / 2 - 0.6):
        g["Beam"].box(x, 0, H / 2 + 0.3, 1.2, 1.2, H + 0.6)
    # 싸리. 굵기와 키를 표로 돌려 가지런하지 않게 한다
    heights = (0.0, 0.5, -0.3, 0.8, 0.2, -0.5, 0.6, -0.1)
    n = 64
    for i in range(n):
        x = -LEN / 2 + 1.3 + (LEN - 2.6) * i / (n - 1)
        h = H - 0.8 + heights[i % 8]
        g["Brush"].box(x, 0.22 if i % 2 else -0.22, h / 2, 0.32, 0.32, h)
    # 가로대 둘. 앞뒤로 싸리를 끼운다
    for z in (2.6, 6.4):
        g["Beam"].box(0, 0.55, z, LEN, 0.5, 0.6)
        g["Beam"].box(0, -0.55, z, LEN, 0.5, 0.6)


def tile_wall_piece(g, cx, length, h=13.0, t=3.2):
    """Wall_Segment 와 같은 켜의 짧은 담. 대문 양옆에 쓴다"""
    g["Masonry"].box(cx, 0, 2.5, length, t + 0.8, 5.0)
    g["Wall"].box(cx, 0, 5.0 + (h - 5.0) / 2, length, t, h - 5.0)
    g["Stylobate"].box(cx, 0, 5.2, length, t + 1.0, 0.4)
    g["Beam"].box(cx, 0, h + 0.3, length, t + 1.0, 0.6)
    rz = L.build_roof(g, h + 0.6, length, t, 2.4, 2.8, style="gable", thick=1.0, lift=0.0,
                      chimi=False, eave=False, ridge=False, nx=6, ny=6, cx=cx,
                      x_lo=-length / 2, x_hi=length / 2, gable_ends=(False, False))
    g["RoofEdge"].box(cx, 0, rz + 0.3, length, 1.6, 0.9)


def gate_tile(g):
    OPEN = 16.0          # 문 폭. 배율 뒤 8 스터드
    side = (LEN - OPEN) / 2
    for s in (-1, 1):
        tile_wall_piece(g, s * (OPEN / 2 + side / 2), side)
    POST_H = 17.0
    for s in (-1, 1):
        g["Column"].box(s * (OPEN / 2 + 0.8), 0, POST_H / 2, 1.8, 2.2, POST_H)
        g["Plinth"].box(s * (OPEN / 2 + 0.8), 0, 0.6, 2.8, 3.2, 1.2)
        # 문짝. 안쪽(+y)으로 활짝 열어 담 안면에 붙인다
        g["Lattice"].box(s * (OPEN / 2 - 0.4), 4.2, 7.8, 0.7, 7.6, 14.4)
        for z in (3.0, 7.8, 12.6):
            g["Eave"].box(s * (OPEN / 2 - 0.9), 4.2, z, 0.3, 7.8, 0.7)
    g["Beam"].box(0, 0, POST_H - 1.0, OPEN + 3.6, 2.4, 2.0)   # 인방
    g["Beam"].box(0, 0, 0.15, OPEN, 2.2, 0.3)                  # 문지방. 낮게
    rz = L.build_roof(g, POST_H + 0.2, OPEN + 6.0, 6.0, 2.8, 4.2, style="gable", thick=1.0,
                      chimi=False, eave=True, ridge=False, nx=16, ny=10)
    # 집 용마루는 이 작은 지붕에 너무 굵다. 가는 마루 두 켜로 얹는다
    g["RoofEdge"].box(0, 0, rz + 0.4, OPEN + 11.6, 1.8, 1.0)
    g["RoofEdge"].box(0, 0, rz + 1.1, OPEN + 10.0, 1.2, 0.5)
    assert rz > 13.0 + 3.4 + 2.0, "대문 지붕이 담 기와보다 충분히 높지 않다"


def gate_brush(g):
    OPEN = 16.0
    side = (LEN - OPEN) / 2
    # 양옆은 싸리 울타리를 짧게. brush_fence 를 짧은 길이로 짠다
    heights = (0.0, 0.5, -0.3, 0.8, 0.2, -0.5, 0.6, -0.1)
    for s in (-1, 1):
        cx = s * (OPEN / 2 + side / 2)
        n = 20
        for i in range(n):
            x = cx - side / 2 + 1.0 + (side - 2.0) * i / (n - 1)
            h = 8.2 + heights[i % 8]
            g["Brush"].box(x, 0.22 if i % 2 else -0.22, h / 2, 0.32, 0.32, h)
        for z in (2.6, 6.4):
            g["Beam"].box(cx, 0.55, z, side, 0.5, 0.6)
            g["Beam"].box(cx, -0.55, z, side, 0.5, 0.6)
        g["Beam"].box(s * (LEN / 2 - 0.6), 0, 4.8, 1.2, 1.2, 9.6)
        # 문설주. 굵은 통나무
        g["Beam"].box(s * (OPEN / 2 + 0.7), 0, 6.0, 1.6, 1.6, 12.0)
    # 싸리문짝 한 짝. 왼쪽 설주에 붙여 안쪽(+y)으로 활짝 열어 둔다
    # 문짝도 판자가 아니라 싸리를 엮은 것이다. 틀 넷에 싸리를 세운다
    fx, fy0, fy1 = -(OPEN / 2 - 0.2), 0.3, 7.3
    for z in (0.9, 7.4):
        g["Beam"].box(fx, (fy0 + fy1) / 2, z, 0.6, fy1 - fy0, 0.6)
    for y in (fy0, fy1):
        g["Beam"].box(fx, y, 4.15, 0.6, 0.6, 7.1)
    for k in range(12):
        y = fy0 + 0.5 + (fy1 - fy0 - 1.0) * k / 11
        g["Brush"].box(fx, y, 4.15, 0.3, 0.3, 6.5)
    g["Beam"].box(0, 0, 11.6, OPEN + 3.0, 1.0, 0.9)   # 설주를 잇는 가로대. 머리 위로 높게


BUILDS = [
    ("Wall_Stone", "WallS", stone_wall, (45, -45, 22), (0, 0, 5)),
    ("Fence_Brush", "Fence", brush_fence, (40, -40, 18), (0, 0, 4)),
    ("Wall_GateTile", "WGate", gate_tile, (45, -50, 28), (0, 0, 9)),
    ("Fence_Gate", "FGate", gate_brush, (40, -45, 20), (0, 0, 6)),
]

for name, prefix, fn, cam, look in BUILDS:
    L.clear_scene()
    g = L.new_groups(prefix)
    fn(g)
    L.export_model(name, g, MODEL_SCALE, renders=[("corner", cam, look)], min_objs=2)
