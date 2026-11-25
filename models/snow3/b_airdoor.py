# -*- coding: utf-8 -*-
"""
b_airdoor.py — 2026-11-24 아트 3팀. 비행선 곤돌라 미닫이 옆문 문짝(따로 움직이는 틀 — 프로그래밍이 OPEN ↔ CLOSED 로 민다).
원점 = 문짝 밑 가운데(두께 가운데). 비행선 원점 기준 자리: CLOSED(문 구멍을 덮음) · OPEN(뒤 +y 로 8.6 밀려 벽 밖에 붙음 — 기본).
쇠 틀 · 리벳 띠 셋 · 놋쇠 손잡이 · 둥근 창 · 위 바퀴 둘(문 위 레일에 걸림). 문짝은 벽 밖 x 9.2..9.5 에서 미끄러진다(다리 바닥은 9.7 부터).
"""
import b_airship as SH

NAME = "Sn3_AirDoor"
PREFIX = "Sn3AirDoor"
VARIANT = "A"

W, H, T = 8.8, 9.25, 0.3
CLOSED = (SH.GX + 0.35, SH.DOOR_C, 0.1)
OPEN = (SH.GX + 0.35, SH.DOOR_C + 8.6, 0.1)


def build(g):
    from lib import bx
    hw, ht = W / 2, T / 2
    bx(g, "Iron", -ht, ht, -hw, hw, 0.0, H)                                        # 판
    for y0, y1 in ((-hw - 0.05, -hw + 0.45), (hw - 0.45, hw + 0.05)):              # 세로 틀(바깥으로 0.1)
        bx(g, "IronLight", -ht - 0.05, ht + 0.1, y0, y1, 0.0, H)
    for z in (0.25, 4.3, 8.6):                                                      # 가로 리벳 띠
        bx(g, "IronLight", -ht - 0.05, ht + 0.1, -hw + 0.45, hw - 0.45, z, z + 0.45)
    g["Brass"].hcyl(ht + 0.05, 0.0, 6.4, 1.0, 0.2, axis="x", seg=12)                # 둥근 창 테
    g["WinGlass"].hcyl(ht + 0.1, 0.0, 6.4, 0.75, 0.18, axis="x", seg=12)
    for s in (-1, 1):                                                               # 손잡이(문 앞 끝 · 안팎)
        bx(g, "Brass", s * (ht + 0.05) - 0.12, s * (ht + 0.05) + 0.12, -hw + 0.7, -hw + 0.95, 3.0, 5.6)
    for y in (-hw + 1.2, hw - 1.2):                                                 # 위 바퀴(레일에 걸림)
        bx(g, "Iron", -0.12, 0.12, y - 0.2, y + 0.2, H, H + 0.25)
        g["Brass"].hcyl(0.0, y, H + 0.35, 0.3, 0.3, axis="x", seg=10)


INFO = {"variant": VARIANT, "floor": 0.0, "closed": CLOSED, "open": OPEN}
