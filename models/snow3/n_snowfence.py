# -*- coding: utf-8 -*-
"""
n_snowfence.py — 2026-11-17. 설원 3판 자연 키트: 눈막이 나무 울타리(길이 12, 높이 3.5). 노르웨이 길가 눈막이(snøskjerm)처럼
네모 기둥 넷(DarkLog, 땅에 0.8 묻힘 — 오른쪽 끝 기둥은 9° 기울어짐) 앞면(-y)에 잿빛 가로 판(DeadWood) 세 줄, 칸 셋.
오른 칸 가운데 판 빠짐 · 가운데 칸 윗판은 한쪽 못이 빠져 비스듬히 처짐. 판 위·기둥 머리 눈, 바람 받는 앞(-y) 밑에 쌓인 눈.
판 두께를 판마다 달리 적어 앞면이 한 평면에 겹치지 않고, 판 뒷면은 기둥 속으로 0.05 묻힌다.
"""
import math

import lib_n as N
from lib import bx

NAME = "Sn3_SnowFence"
PREFIX = "Sn3SnowFence"

POSTS = [(-5.75, 0.0), (-1.95, 0.0), (1.85, 0.0), (5.7, 9.0)]      # (x, +x 로 기운 도)
PH, PZ0, PR = 3.3, -0.8, 0.3                                        # 기둥 머리 높이 · 묻힌 밑 · 반지름(네모 반폭 0.21)
HW = PR * math.sqrt(0.5)
ROWS = (0.85, 1.75, 2.65)                                           # 판 가운데 높이(판 높이 0.55)
# 판: (칸, 줄, 두께, 눈(왼 끝 들임, 오른 끝 들임) 또는 None)
BOARDS = [
    (0, 0, 0.18, (0.3, 0.9)), (0, 1, 0.20, (0.2, 0.4)), (0, 2, 0.17, (0.5, 0.3)),
    (1, 0, 0.19, (0.6, 0.3)), (1, 1, 0.17, (0.2, 1.1)),
    (2, 0, 0.21, (0.4, 0.5)), (2, 2, 0.18, (0.3, 0.7)),
]
SAG = (1, 2, 0.18, 5.0)                                             # 처진 판: 칸, 줄, 두께, 기운 도 — 왼 못을 축으로 판 평면 안에서 돌아 오른 끝이 아래 판 위에 걸림
DRIFT = [(-5.2, 0.7, 0.8, 0.0), (-2.2, 1.0, 1.0, 0.0), (1.0, 0.6, 0.9, 0.0), (4.0, 0.85, 1.0, 0.0)]
DRIFT_P = [(-2.3, -0.2), (-1.3, 0.45), (-0.55, 1.05), (-0.25, 0.9), (-0.15, -0.2)]


def _px(k, z):
    x, lean = POSTS[k]
    return x + (z - PZ0) * math.tan(math.radians(lean))


def build(g):
    for k, (x, lean) in enumerate(POSTS):
        N.stick(g, "DarkLog", (x, 0, PZ0), (_px(k, PH), 0, PH), PR, PR * 0.92, n=4, rot=math.pi / 4)
        xt = _px(k, PH)
        bx(g, "SnowCap", xt - HW - 0.06, xt + HW + 0.06, -HW - 0.06, HW + 0.06, PH - 0.06, PH + 0.18)
    for bay, row, th, snow in BOARDS:
        z = ROWS[row]
        x0, x1 = _px(bay, z) + 0.02, _px(bay + 1, z) - 0.02
        y0, y1 = -HW - th, -HW + 0.05
        bx(g, "DeadWood", x0, x1, y0, y1, z - 0.275, z + 0.275)
        if snow:
            bx(g, "SnowCap", x0 + snow[0], x1 - snow[1], y0 - 0.06, y1 + 0.06, z + 0.215, z + 0.4)
    bay, row, th, deg = SAG
    z = ROWS[row]
    x0, x1 = _px(bay, z) + 0.15, _px(bay + 1, z) - 0.1
    L_ = x1 - x0
    a = math.radians(deg)
    g["DeadWood"].obox((x0 + x1) / 2, -HW - th / 2 + 0.05, z - L_ / 2 * math.sin(a), L_, th, 0.55, ry=a)
    N.loft_x(g, "SnowCap", DRIFT, DRIFT_P, ((-6.4, -0.9, -0.2), (5.6, -0.9, -0.2)))
    N.cbox(-6.0, 6.3, -0.45, 0.25, 0, 3.4)
