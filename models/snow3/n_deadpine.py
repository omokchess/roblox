# -*- coding: utf-8 -*-
"""
n_deadpine.py — 2026-11-17. 설원 3판 자연 키트: 죽은 가문비(높이 20, 폭 6). 껍질 벗은 잿빛 줄기(DeadWood), 꼭대기가 부러져
들쭉날쭉한 끝 + 속 나무(Wood) 가시 둘, 아래로 처진 짧은 죽은 가지 여덟(셋에 눈), 밑동 뿌리 셋.
"""
import math

import lib_n as N

NAME = "Sn3_DeadPine"
PREFIX = "Sn3DeadPine"

TRUNK = [(0, 0, -0.6, 0.78), (0, 0, 4.0, 0.66), (0.1, 0.05, 11.0, 0.5), (0.15, 0.1, 16.4, 0.4)]
JAG = (19.6, 18.2, 17.0, 18.9, 17.6, 20.0)      # 부러진 끝: 6각 꼭짓점마다 높이(손 표)
JAG_R, JAG_C = 0.36, (0.15, 0.1, 16.9)          # 끝 고리 반지름 · 안으로 꺼진 가운데
SPLINTERS = [((0.05, 0.0, 16.6), (0.32, 0.22, 19.2), 0.16), ((0.22, 0.12, 16.6), (-0.08, 0.3, 18.4), 0.13)]
# 죽은 가지: (높이, 방향 도, 길이, 아래로 처짐 도, 밑 굵기, 눈 구간 또는 None)
STUBS = [
    (3.6, 10, 3.3, 28, 0.17, None),
    (5.2, 165, 3.2, 22, 0.17, (0.15, 0.8)),
    (6.9, 255, 3.3, 30, 0.16, None),
    (8.4, 80, 3.1, 20, 0.15, (0.2, 0.85)),
    (10.2, 205, 2.4, 25, 0.13, None),
    (11.8, 320, 2.0, 15, 0.12, (0.1, 0.75)),
    (13.5, 120, 1.6, 22, 0.11, None),
    (15.0, 240, 1.2, 10, 0.10, None),
]
ROOTS = [(50, 1.8, 0.36, 1.2), (175, 1.6, 0.34, 1.0), (295, 1.9, 0.38, 1.3)]
COLL = (1.25, 10.0)           # 줄기 1.5 + 1


def _axis(z):
    for a, b in zip(TRUNK, TRUNK[1:]):
        if z <= b[2]:
            t = (z - a[2]) / (b[2] - a[2])
            return a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])
    return TRUNK[-1][:2]


def build(g):
    rings = [N.ring(x, y, z, r, 6) for x, y, z, r in TRUNK]
    jx, jy = TRUNK[-1][:2]
    rings.append([(jx + JAG_R * math.cos(2 * math.pi * i / 6), jy + JAG_R * math.sin(2 * math.pi * i / 6), z) for i, z in enumerate(JAG)])
    N.loft(g, "DeadWood", rings, top=JAG_C)
    for p0, p1, r in SPLINTERS:
        N.stick(g, "Wood", p0, p1, r, 0, n=3, tip=True)
    for z, ang, ln, dn, r0, snow in STUBS:
        x, y = _axis(z)
        a, d = math.radians(ang), math.radians(dn)
        p1 = (x + ln * math.cos(a) * math.cos(d), y + ln * math.sin(a) * math.cos(d), z - ln * math.sin(d))
        N.branch(g, "DeadWood", (x, y, z), p1, r0, r0 * 0.45, snow=snow)
    N.roots(g, "DeadWood", 0, 0, TRUNK[0][3], ROOTS)
    hw, h = COLL
    N.cbox(-hw, hw, -hw, hw, 0, h)
