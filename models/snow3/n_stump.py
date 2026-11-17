# -*- coding: utf-8 -*-
"""
n_stump.py — 2026-11-17. 설원 3판 자연 키트: 그루터기(지름 2.6, 높이 1.6). 8각 껍질 몸(밑동이 퍼짐) + 비스듬히 켠 면의 나이테 판(Wood, 껍질 테 0.12 남김)
+ 켠 면 위 눈(한쪽으로 치우침) + 짧은 뿌리 셋. 켠 면은 x 쪽으로 TILT 만큼 기운 한 평면 — 나이테 판·눈이 그 면과 평행.
"""
import math

import lib_n as N

NAME = "Sn3_Stump"
PREFIX = "Sn3Stump"

RINGS = [(-0.4, 1.36), (0.2, 1.30)]        # (높이, 반지름) 아래 두 고리 — 위 고리는 켠 면(TOP_Z + TILT·x)
TOP_Z, TOP_R, TILT = 1.25, 1.18, 0.10
DISC_R = 1.02                               # 나이테 판(켠 면 위 0.06)
ROOTS = [(30, 1.38, 0.30, 0.7), (150, 1.36, 0.28, 0.6), (265, 1.38, 0.30, 0.75)]


def _cut(r, dz):
    return [(x, y, TOP_Z + TILT * x + dz) for x, y, _ in N.ring(0, 0, 0, r, 8, math.pi / 8)]


def build(g):
    N.loft(g, "Bark", [N.ring(0, 0, z, r, 8, math.pi / 8) for z, r in RINGS] + [_cut(TOP_R, 0.0)])
    top = _cut(DISC_R, 0.06)
    N.loft(g, "Wood", [_cut(DISC_R, -0.15), top])
    N.slab_snow(g, top, s=0.78, off=(-0.12, 0.08), sink=0.08, te=0.18, tc=0.3, push=0.06)
    N.roots(g, "Bark", 0, 0, RINGS[0][1], ROOTS)
    N.cbox(-1.2, 1.2, -1.2, 1.2, 0, 1.5)
