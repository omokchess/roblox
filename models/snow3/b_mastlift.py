# -*- coding: utf-8 -*-
"""
b_mastlift.py — 2026-11-25 아트 3팀. 계류탑 증기 승강기 칸(따로 움직이는 틀 — 프로그래밍이 b_mast.LIFT_BOTTOM ↔ LIFT_TOP 로 올리내린다).
원점 = 칸 바닥 윗면 가운데. 바깥 5.7 × 5.7(승강로 기둥 안 6.0), 안 높이 7.6, 타는 곳 둘: 북(-y, 1층) · 동(+x, 승강장).
쇠 바닥판 · 귀 기둥 넷 · 지붕 + 놋쇠 멍에 · 남·서 벽(아래 무늬판 + 위 놋쇠 살) · 북·동 접이문(한쪽으로 접혀 열린 채 — 맑은 폭 4.4) · 손잡이 · 천장 등.
"""
NAME = "Sn3_MastLift"
PREFIX = "Sn3MastLift"
VARIANT = "A"

H = 2.85            # 바깥 반폭
ZR = 7.9            # 지붕 밑


def build(g):
    from lib import bx, cbox
    import lib as K
    bx(g, "IronLight", -H, H, -H, H, -0.4, 0.0)
    bx(g, "Iron", -H + 0.2, H - 0.2, -H + 0.2, H - 0.2, -0.75, -0.4)
    cbox(-H, H, -H, H, -0.75, 0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, "Iron", sx * H - 0.15 - sx * 0.15, sx * H + 0.15 - sx * 0.15, sy * H - 0.15 - sy * 0.15, sy * H + 0.15 - sy * 0.15, 0.0, ZR)
    bx(g, "Iron", -H, H, -H, H, ZR, ZR + 0.3)
    cbox(-H, H, -H, H, ZR, ZR + 0.3)
    bx(g, "Brass", -H + 0.3, H - 0.3, -0.3, 0.3, ZR + 0.3, ZR + 0.75)
    g["Brass"].cyl(0.0, 0.0, ZR + 0.75, 0.3, 0.3, 0.35, seg=8)
    # 남(+y) · 서(-x) 벽: 아래 무늬판(3.0) · 위 놋쇠 살 · 가운데 띠 · 손잡이
    for ax, c in (("x", H - 0.15), ("y", -H + 0.15)):
        K.wbox(g, "IronLight", ax, c, 0.16, -H + 0.3, H - 0.3, 0.0, 3.0)
        K.wbox(g, "Iron", ax, c, 0.22, -H + 0.3, H - 0.3, 3.0, 3.3)
        K.wbox(g, "Iron", ax, c, 0.22, -H + 0.3, H - 0.3, ZR - 0.3, ZR)
        for k in range(-3, 4):
            K.wbox(g, "Brass", ax, c, 0.14, k * 0.75 - 0.07, k * 0.75 + 0.07, 3.3, ZR - 0.3)
        inn = c - (0.45 if c > 0 else -0.45)
        K.wbox(g, "Brass", ax, inn, 0.16, -H + 0.5, H - 0.5, 3.2, 3.4)
        if ax == "x":
            cbox(-H, H, c - 0.15, c + 0.15, 0.0, ZR)
        else:
            cbox(c - 0.15, c + 0.15, -H, H, 0.0, ZR)
    # 북(-y) · 동(+x) 접이문: 접힌 묶음(놋쇠 살 겹 · 0.75 폭)이 한쪽 기둥에 붙음 + 위 레일
    for ax, c, side in (("x", -H + 0.12, 1), ("y", H - 0.12, -1)):
        a, b = sorted((side * (H - 0.3), side * (H - 1.05)))
        for k in range(4):
            K.wbox(g, "Brass", ax, c + (k % 2) * 0.1 - 0.05, 0.1, a + k * 0.18, a + k * 0.18 + 0.14, 0.15, ZR - 0.35)
        K.wbox(g, "Iron", ax, c, 0.25, a, b, 0.0, 0.2)
        K.wbox(g, "Iron", ax, c, 0.2, -H + 0.3, H - 0.3, ZR - 0.4, ZR - 0.2)
        if ax == "x":
            cbox(a, b, c - 0.2, c + 0.2, 0.0, ZR)
        else:
            cbox(c - 0.2, c + 0.2, a, b, 0.0, ZR)
    # 천장 등
    bx(g, "Brass", -0.6, 0.6, -0.6, 0.6, ZR - 0.15, ZR)
    g["Glow"].box(0.0, 0.0, ZR - 0.35, 0.7, 0.7, 0.35)
    g["LampPt"].box(0.0, 0.0, ZR - 0.9, 0.3, 0.3, 0.3)


INFO = {"variant": VARIANT, "floor": 0.0}
