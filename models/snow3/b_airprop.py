# -*- coding: utf-8 -*-
"""
b_airprop.py — 2026-11-24 아트 3팀. 비행선 프로펠러(따로 도는 틀 — 프로그래밍이 돌린다). 비행선 엔진 곤돌라 넷에 하나씩.
원점 = 굴대 가운데, 굴대 = 블렌더 y(로블록스 로컬 Z, 비행선 앞뒤). 놓는 자리 = b_airship.PROP_HUBS(비행선 원점 기준).
나무 날개 넷(굵게 — 폭 1.0~1.25 · 두께 0.35, 22° 비틂) · 놋쇠 날끝 덮개 · 쇠 굴대통 · 놋쇠 뾰족 덮개(뒤 = +y).
"""
import math

import bmesh
from mathutils import Matrix

NAME = "Sn3_AirProp"
PREFIX = "Sn3AirProp"
VARIANT = "A"
R_TIP = 5.8


def _blade_box(g, mat, a, r0, r1, chord, th, pitch):
    """반지름 r0..r1 날개 조각(굴대 y 둘레 각 a, 비틂 pitch)"""
    m = (Matrix.Rotation(a, 4, "Y") @ Matrix.Translation(((r0 + r1) / 2, 0.0, 0.0)) @ Matrix.Rotation(pitch, 4, "X")
         @ Matrix.Diagonal((r1 - r0, th, chord, 1.0)))
    bmesh.ops.create_cube(g[mat].bm, size=1.0, matrix=m)


def build(g):
    g["Iron"].hcyl(0.0, 0.0, 0.0, 0.85, 1.4, axis="y", seg=12)
    g["Brass"].hcyl(0.0, -0.75, 0.0, 1.0, 0.25, axis="y", seg=12)
    m = Matrix.Translation((0.0, 1.15, 0.0)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    bmesh.ops.create_cone(g["Brass"].bm, cap_ends=True, cap_tris=False, segments=12, radius1=0.85, radius2=0.15, depth=1.0, matrix=m)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        _blade_box(g, "Wood", a, 0.6, 2.8, 1.5, 0.45, math.radians(24))
        _blade_box(g, "Wood", a, 2.75, 5.0, 1.25, 0.4, math.radians(20))
        _blade_box(g, "Brass", a, 4.95, R_TIP, 1.15, 0.48, math.radians(20))
        _blade_box(g, "Iron", a, 0.65, 1.3, 1.7, 0.6, math.radians(24))         # 뿌리 쇠 죔쇠


INFO = {"variant": VARIANT, "floor": 0.0, "axis": "y(블렌더) = 로블록스 로컬 Z", "radius": R_TIP}
