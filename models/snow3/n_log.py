# -*- coding: utf-8 -*-
"""
n_log.py — 2026-11-17. 설원 3판 자연 키트: 쓰러진 통나무(길이 16, 지름 2). x 축으로 누움, 밑동(-x) 켠 면(Wood 판) · 끝(+x) 부러진 가시(Wood).
몸 = 8각(윗면 평평) 껍질, 밑동 쪽이 굵고 땅에 0.13 묻힘. 눈 = 윗면·윗 비탈 면을 따라 얹힌 세 조각(사이에 껍질이 드러남, 손 표),
밑면은 껍질 면과 평행하게 0.08 묻힘. 부러진 가지 토막 셋.
"""
import math

import lib_n as N

NAME = "Sn3_Log"
PREFIX = "Sn3Log"

X0, X1 = -7.6, 7.3            # 밑동 끝 · 부러진 끝
R0, R1 = 1.06, 0.92           # 8각 반지름(꼭짓점)
Z0, Z1 = 0.84, 0.72           # 축 높이(양끝 바닥이 0.13 묻히게)
C8 = math.cos(math.pi / 8)
SNOW = [(-6.9, -3.3, 0.30), (-2.5, 1.6, 0.30), (2.4, 5.8, 0.24)]          # (x0, x1, 두께)
JAG = (0.15, 0.55, 0.2, 0.7, 0.1, 0.45, 0.25, 0.6)                         # 부러진 끝 가시 길이(8각 꼭짓점마다)
STUBS = [(-3.8, 58, 0.45, 0.2), (1.0, 122, 0.4, 0.18), (4.6, 70, 0.35, 0.16)]   # (x, 둘레 각 도 — 0 = +y, 90 = 위, 내민 길이, 굵기)


def _ax(x):
    t = (x - X0) / (X1 - X0)
    return Z0 + t * (Z1 - Z0), R0 + t * (R1 - R0)


def _ring(x, r, dx=None):
    z, _ = _ax(x)
    return [(x + (dx[i] if dx else 0.0), r * math.cos(math.pi / 8 + i * math.pi / 4), z + r * math.sin(math.pi / 8 + i * math.pi / 4)) for i in range(8)]


def _snow(x, t, sink=0.08):
    """x 자리 눈 단면: 밑 = 오른 비탈 가운데 · 윗면 두 꼭짓점 · 왼 비탈 가운데(껍질 면을 sink 만큼 안으로 옮긴 8각 위), 위 = 두께 t"""
    z, r = _ax(x)
    rs = r - sink / C8
    a, ap = rs * C8, r * C8
    b = [(a * math.cos(math.pi / 4), a * math.sin(math.pi / 4)), (rs * math.cos(3 * math.pi / 8), rs * math.sin(3 * math.pi / 8)),
         (rs * math.cos(5 * math.pi / 8), rs * math.sin(5 * math.pi / 8)), (a * math.cos(3 * math.pi / 4), a * math.sin(3 * math.pi / 4))]
    top = [(b[3][0] - 0.08, b[3][1] + sink + t * 0.5), (-0.3, ap + t), (0.28, ap + t * 1.1), (b[0][0] + 0.08, b[0][1] + sink + t * 0.5)]
    return [(x, y, z + zz) for y, zz in b + top]


def build(g):
    N.loft(g, "Bark", [_ring(X0, R0), _ring(X1, R1)])
    N.loft(g, "Wood", [_ring(X0 + 0.25, 0.88), _ring(X0 - 0.06, 0.88)])           # 켠 면(껍질 테 남김)
    z1, _ = _ax(X1)
    N.loft(g, "Wood", [_ring(X1 - 0.35, 0.74), _ring(X1, 0.7, JAG)], top=(X1 + 0.2, 0.0, z1))
    for x0, x1, t in SNOW:
        N.loft(g, "SnowCap", [_snow(x0, t), _snow(x1, t)])
    for x, ang, ln, r in STUBS:
        z, rr = _ax(x)
        a = math.radians(ang)
        p0 = (x, 0.0, z)
        p1 = (x + 0.1, (rr + ln) * math.cos(a), z + (rr + ln) * math.sin(a))
        N.branch(g, "Bark", p0, p1, r, r * 0.7)
    N.cbox(X0 - 0.1, X1 + 0.1, -0.95, 0.95, 0, 1.75)
