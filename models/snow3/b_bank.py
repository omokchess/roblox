# -*- coding: utf-8 -*-
"""
b_bank.py — 2026-11-14 아트 부서원 2 → 2026-11-18 아트 1팀 다시 지음. 설원 마을 3판: 은행(보관·환전). B 양식 — 벽 절반까지 돌.

사용자(2026-11-18): "은행은 또 벽에 문만 달려있는 식이야." (2026-10-24 2판 때도: 금고 뒤 쌩 벽 → 뒤를 금고 공간으로, 양옆으로 추가 공간)
→ 금고 문 그림 대신 **열린 둥근 금고 문(두께 2.6, 가장자리 빗장) + 그 뒤 진짜 금고실 + 양옆 회랑(붉은 융단)** 을 짓고, 발자국을 뒤로 늘렸다
  (바닥 발자국 깊이 31.3 → 43.9, 폭 그대로 — 총괄 허락 44 이내). 문에 들어서면 쇠살 창구 너머로 금고 문과 불 켜진 금고실이 보인다.

레퍼런스(회사/설원마을_레퍼런스.md B·'내부 레퍼런스 — 1팀'): 뢰로스 은행(B1 돌 1층 + 짙은 목재), 1922 퀸즐랜드 은행 안(B2 쇠살 창구),
은행 박물관 금고문(B3), 둥근 금고 문 + 대여 금고 서랍 벽(내부 레퍼런스 BI1~BI4).

배치(블렌더, 앞 = -y, 바닥 FZ = 2). 벽 가운데 선 x ±16.4 · y -13..25.6 → 안 31.6 × 37.4, 천장(평보 밑) 11.
  홀      y -12.4..-0.5 : 문 → 붉은 깔개 → 창구 카운터(x -5..4 · y -0.5..2, 쇠살 칸막이 · 창구 둘) · 양옆 등받이 긴 의자 · 기입대 · 큰 괘종시계 · 증기 동전 저울
  직원 칸  y 2..12.1    : 창구 NPC 둘 · 왼 벽 장부 책상(의자·장부 책장) · 금고 문으로 가는 길(폭 8 넘음) · 오른쪽은 열린 금고 문짝이 막 서 있는 자리
  금고 벽  y 12.1..14.1 : 돌 벽(두께 2) + 둥근 구멍(반지름 4.4, 가운데 바닥 위 3.4 — 걷는 높이 폭 8.6) + 쇠 틀 · 문짝은 오른 경첩에서 밖으로 90° 열림(80° 면 길이 7.7)
  금고실   x ±6.2 · y 14.1..25.0 (돌 천장 바닥 위 10.2): 앞 8.4 는 지나는 길(양옆 회랑 문 y 14.35..22.75, 폭 8.4, 쇠살문은 위로 들림),
           뒤 2.25 에 대여 금고 서랍 벽(뒷벽) · 금괴 선반 둘(옆벽) · 장부 책상(가운데) · 돈자루
  회랑     x ±(7.4..15.8) · y 12.1..25.0 (폭 8.4): 앞이 직원 칸으로 트임 · 붉은 융단 · 벽등 · 높은 쇠살 창 · 그림 액자 · 끝 벽 난방기 · 금고실 문 위 들림 감개
  → 한 바퀴: 홀 → 왼 길 → 직원 칸 → 금고 문 → 금고실 → (왼·오른) 회랑 문 → 회랑 → 직원 칸 → 홀. 통로 폭은 int1_render.py check 가 잰다(8 이상).
"""
import math

from mathutils import Matrix

import lib as K
import lib_b as KB
import lib_int1 as P
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Bank"
PREFIX = "Sn3Bank"
VARIANT = "B"

WX, YF, YB = 16.4, -13.0, 25.6
T = LOG
AX = WX + T / 2                          # 벽 바깥면 반폭 17.0
AYF, AYB = YF - T / 2, YB + T / 2         # 앞 -13.6 · 뒤 26.4
CY, HA = (AYF + AYB) / 2, (AYB - AYF) / 2     # 지붕 가운데 y 6.4 · 반 깊이 20.0
XI, YI0, YI1 = WX - T / 2, YF + T / 2, YB - T / 2       # 15.8, -12.4, 25.2
Z_PLATE = FZ + CEIL + 0.9
STONE_TO = FZ + 6.0
PITCH = 40.0
WIN_F, WIN_S = (-11.5, 11.5), (-6.5, 6.5)
SLIT_Y = 19.0                            # 회랑 높은 쇠살 창(옆벽)
COUNTER = (-5.0, 2.5, -0.5, 2.0)          # 1.5 줄임(비평 1차 — 열린 문짝 옆 오른 길)
FREE = (-5.0, 5.0, -10.65, -0.65)
TIES = (-9.0, -2.5, 4.0, 10.5, 17.0, 23.5)    # 평보(x 방향) 자리 — 금고 쪽 둘은 금고 돌 천장 위에 얹힌다
# 금고
VY0, VY1 = 12.1, 14.1                    # 금고 앞벽(직원 칸 쪽 면 · 금고실 쪽 면)
VX, VXO = 4.4, 5.6                       # 금고실 안 반폭 · 옆벽 바깥 반폭 — 비평 1차(2026-11-24) 방법 B: 회랑 8.4 → 10.2(0.5 격자로 재도 10)
VZC, VR = 3.4, 4.4                       # 둥근 구멍 가운데 높이(바닥 위) · 반지름
VCEIL = FZ + 10.2                        # 금고 돌 천장 밑
GATE = (14.35, 22.75)                    # 회랑 문(쇠살문 들림) y — 폭 8.4(0.5 격자로 재도 8 넘게)
HINGE, OPEN = (4.45, VY0), 90.0           # 금고 문짝 경첩 · 연 각(80° 면 문짝이 구멍 앞을 비스듬히 가려 길이 7.7 — 90° 가 폭 8 을 지키는 가장 작은 각)
NPCS = ((-3.25, 3.3), (-0.25, 3.3))


# ------------------------------------------------------------------ 껍데기
def walls(g):
    hole = lambda u, z0=FZ + WIN_SILL, w=WIN_W, h=K.WIN_H: (u - w / 2, u + w / 2, z0, z0 + h)     # noqa: E731
    door = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    slit = hole(SLIT_Y, FZ + 6.3, 2.2, 2.6)
    plan = (("x", YF, [door] + [hole(u) for u in WIN_F], -1),
            ("x", YB, [], 1),
            ("y", -WX, [hole(u) for u in WIN_S] + [slit], -1),
            ("y", WX, [hole(u) for u in WIN_S] + [slit], 1))
    for ax, c, holes, face in plan:
        u0, u1 = (-WX, WX) if ax == "x" else (YF, YB)
        K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=STONE_TO, face=face)
        for h in holes[1 if ax == "x" and c == YF else 0:]:
            KB.barred_window(g, ax, c, (h[0] + h[1]) / 2, h[2], face, w=h[1] - h[0], h=h[3] - h[2])
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=150.0, outward=False)     # 150°: 카운터 앞 빈 바닥(문 앞 1.75 부터)을 비킴


def portal(g):
    """정문 돌 기둥 둘(기초 위) + 돌 인방(처마 밑까지) — 은행만의 단단한 문"""
    y0, y1 = AYF - 0.9, AYF
    for s in (-1, 1):
        x0, x1 = sorted((s * 6.0, s * 7.5))
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ, FZ + 0.8)
        bx(g, "Stone", x0, x1, y0, y1, FZ + 0.8, FZ + 10.6)
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ + 10.6, FZ + 11.0)
        cbox(x0, x1, y0, y1, FZ, FZ + 10.6)
    bx(g, "Stone", -7.65, 7.65, y0 - 0.1, y1, FZ + 11.0, FZ + 11.6)
    bx(g, "StoneTrim", -7.9, 7.9, y0 - 0.3, y1, FZ + 11.6, FZ + 11.85)
    g["Brass"].hcyl(0, y0 - 0.2, FZ + 11.3, 0.5, 0.2, axis="y", seg=16)


def _roof_local(q):
    """제 좌표(용마루 = x, 길이 반 HA 20 · 폭 반 AX 17)로 모임지붕 + 평보(y 방향) · 동자기둥 · 버팀대. 뒤에 90° 돌려 놓는다"""
    A, B = HA, AX
    ztop, zb = KB.hip_roof(q, A, B, Z_PLATE, PITCH)
    zt0 = Z_PLATE - 0.9
    for yt in TIES:
        xt = yt - CY
        bx(q, "DarkLog", xt - 0.5, xt + 0.5, -B + 0.05, B - 0.05, zt0, Z_PLATE)
        inset = min(B, A - abs(xt) - 0.5)
        zp = zb(inset) - (1.15 if abs(xt) < A - B + 0.1 else 0.1)
        bx(q, "DarkLog", xt - 0.4, xt + 0.4, -0.4, 0.4, Z_PLATE, zp)
        for s in (-1, 1):
            KB.member(q, "DarkLog", (xt, s * 0.4, Z_PLATE + (zp - Z_PLATE) * 0.55), (xt, s * (B - 4.0), Z_PLATE + 0.3), 0.45, 0.45)


def roof(g):
    # 제 (lx, ly) → 세계 (-ly, lx + CY): 용마루가 y 를 따른다(뒤로 늘린 집이 폭보다 길어서)
    K.L.transformed(g, Matrix.Translation((0, CY, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"), _roof_local)


# ------------------------------------------------------------------ 홀
def bench_wall(g, s, y0, y1):
    """벽(x = s·XI)에 등을 댄 긴 의자 — lib_int1.wall_bench"""
    P.wall_bench(g, s * XI, s, y0, y1, FZ)


def tall_clock(g, x, y, face_rz):
    """큰 괘종시계(앞 = -y 를 rz 로 돌림): 받침 · 몸(허리 문 + 유리 창 속 추) · 머리(시계판 · 놋쇠 테 · 바늘) · 꼭대기 장식 셋"""
    A = P.At(g, x, y, FZ, face_rz)
    A.box("DarkLog", -0.95, 0.95, -0.7, 0.7, 0, 1.2)
    A.box("Timber", -0.8, 0.8, -0.6, 0.6, 1.2, 5.6)
    A.box("Wood", -0.55, 0.55, -0.66, -0.6, 1.6, 5.2)
    A.box("Glass", -0.32, 0.32, -0.7, -0.66, 2.4, 4.9)
    A.cyl("Iron", 0, -0.45, 3.0, 0.04, 0.04, 1.8, seg=4)
    A.hcyl("Brass", 0, -0.45, 2.75, 0.28, 0.08, axis="y", seg=12)
    A.box("DarkLog", -1.0, 1.0, -0.75, 0.75, 5.6, 5.9)
    A.box("Timber", -0.9, 0.9, -0.65, 0.65, 5.9, 7.9)
    A.hcyl("Brass", 0, -0.66, 6.9, 0.78, 0.08, axis="y", seg=20)
    A.hcyl("Dial", 0, -0.72, 6.9, 0.66, 0.06, axis="y", seg=20)
    for k in range(12):
        a = 2 * math.pi * k / 12
        A.ob("Iron", 0.55 * math.sin(a), -0.77, 6.9 + 0.55 * math.cos(a), 0.06, 0.04, 0.16 if k % 3 else 0.26, ry=a)
    A.ob("Iron", 0.12, -0.8, 7.05, 0.07, 0.04, 0.45, ry=0.6)
    A.ob("Iron", -0.2, -0.8, 6.85, 0.07, 0.04, 0.32, ry=-2.0)
    A.box("DarkLog", -1.1, 1.1, -0.8, 0.8, 7.9, 8.25)
    A.ob("DarkLog", 0, 0, 8.55, 1.6, 1.3, 0.5)
    for sx in (-0.85, 0.0, 0.85):
        A.cyl("Brass", sx, -0.45, 8.25 if sx else 8.8, 0.12, 0.05, 0.55, seg=6)
    A.coll(-0.95, 0.95, -0.7, 0.7, 0, 8.25)


def coin_machine(g, xw, yc):
    """증기 동전 저울(오른 벽 x = xw 에 붙음): 돌 받침 · 구리 통(놋쇠 띠) · 놋쇠 깔때기 · 맞물린 톱니 둘 · 미끄럼 홈 · 동전 쟁반 · 압력계 · 벽으로 드는 관"""
    s = 1 if xw > 0 else -1
    xm = xw - s * 0.95
    bx(g, "Stone", *sorted((xw, xw - s * 1.9)), yc - 1.6, yc + 1.6, FZ, FZ + 0.6)
    K.S.banded_cyl(g, "Copper", xm, yc + 0.6, FZ + 0.6, 0.75, 3.2, every=1.2, seg=12)
    g["Brass"].cyl(xm, yc + 0.6, FZ + 3.8, 0.35, 0.95, 1.0, seg=10)
    g["Brass"].cyl(xm, yc + 0.6, FZ + 4.8, 0.95, 0.95, 0.12, seg=10)
    K.S.gear(g, "Brass", xm - s * 0.1, yc - 0.7, FZ + 3.3, 0.75, 10, 0.18, axis="x")
    K.S.gear(g, "Iron", xm - s * 0.1, yc - 0.7 - 1.1, FZ + 3.3 - 0.35, 0.45, 8, 0.18, axis="x")
    g["Brass"].obox(xm - s * 0.2, yc - 0.6, FZ + 1.9, 0.5, 1.6, 0.12, rx=0.45)
    bx(g, "Wood", *sorted((xw - s * 0.4, xw - s * 1.85)), yc - 1.5, yc - 0.5, FZ + 1.1, FZ + 1.25)
    for k, dy in enumerate((-1.2, -0.85)):
        P.coin_stack(g, xm - s * 0.25 * (k * 2 - 1), yc + dy, FZ + 1.25, n=3 + k, r=0.18)
    g["Iron"].hcyl(xm - s * 0.8, yc + 0.6, FZ + 2.8, 0.42, 0.14, axis="x", seg=12)
    g["Dial"].hcyl(xm - s * 0.88, yc + 0.6, FZ + 2.8, 0.32, 0.06, axis="x", seg=12)
    K.S.pipe(g, [(xm, yc + 0.6, FZ + 4.0), (xm, yc + 1.4, FZ + 4.0), (xw - s * 0.2, yc + 1.4, FZ + 4.0)], 0.18, mat="Copper")
    cbox(*sorted((xw, xw - s * 1.9)), yc - 1.6, yc + 1.6, FZ, FZ + 4.9)


def bank_counter(g, x0, x1, y0, y1):
    """은행 창구 카운터(비평 1차: 세 채가 같은 틀): 돌 밑단 0.6 · 짙은 나무(Timber) 몸 · 앞면 밝은 판(Wood) 칸 · 놋쇠 띠 둘 · 밝은 돌 상판 0.3"""
    zt = FZ + K.COUNTER_H
    bx(g, "StoneTrim", x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, FZ, FZ + 0.6)
    bx(g, "Timber", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, FZ + 0.6, zt - 0.3)
    n = max(1, int(round((x1 - x0) / 1.6)))
    for i in range(n):
        a = x0 + 0.25 + (x1 - x0 - 0.5) * i / n
        b = x0 + 0.25 + (x1 - x0 - 0.5) * (i + 1) / n
        bx(g, "Wood", a + 0.12, b - 0.12, y0 + 0.02, y0 + 0.1, FZ + 1.25, zt - 0.85)
    for zz in (FZ + 0.95, zt - 0.6):
        bx(g, "Brass", x0 + 0.1, x1 - 0.1, y0 - 0.02, y0 + 0.1, zz, zz + 0.1)
    bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.2, y1 + 0.15, zt - 0.3, zt)
    cbox(x0 - 0.15, x1 + 0.15, y0 - 0.2, y1 + 0.15, FZ, zt)
    return zt


def writing_desk(g, x, y):
    """기입대(서서 쓰는 책상, 앞뒤 양면): 다리 넷 · 아래 선반(종이 묶음) · 기운 상판 둘(놋쇠 펜 홈) · 가운데 등 · 잉크병"""
    for sx in (-1.6, 1.6):
        for sy in (-0.7, 0.7):
            bx(g, "Timber", x + sx - 0.15, x + sx + 0.15, y + sy - 0.15, y + sy + 0.15, FZ, FZ + 3.3)
    bx(g, "Wood", x - 1.75, x + 1.75, y - 0.85, y + 0.85, FZ + 0.6, FZ + 0.75)
    for k, xx in enumerate((-1.0, 0.1, 1.0)):
        for q in range(2 + k % 2):                             # 바랜 크림 종이(Canvas) 두세 장 어긋나게(비평 1차: 가장 밝은 덩이)
            g["Canvas"].obox(x + xx + 0.08 * q, y - 0.05 * q, FZ + 0.8 + 0.07 * q, 0.8, 0.8, 0.06, rz=0.12 * (q - 1))
    for sy in (-1, 1):
        g["Wood"].obox(x, y + sy * 0.55, FZ + 3.55, 3.8, 1.2, 0.14, rx=sy * 0.22)
        bx(g, "Brass", x - 1.8, x + 1.8, y + sy * 1.1 - 0.06, y + sy * 1.1 + 0.06, FZ + 3.3, FZ + 3.45)
    bx(g, "DarkLog", x - 1.85, x + 1.85, y - 0.12, y + 0.12, FZ + 3.55, FZ + 3.85)
    for xx in (-1.1, 1.1):
        g["Iron"].cyl(x + xx, y, FZ + 3.85, 0.16, 0.12, 0.28, seg=8)
    g["Brass"].cyl(x, y, FZ + 3.85, 0.1, 0.1, 1.2, seg=6)
    g["Brass"].cyl(x, y, FZ + 5.05, 0.45, 0.15, 0.35, seg=8)
    g["Glow"].cyl(x, y, FZ + 4.85, 0.18, 0.12, 0.2, seg=6)
    cbox(x - 1.8, x + 1.8, y - 0.9, y + 0.9, FZ, FZ + 3.6)


def hall(g):
    """홀: 붉은 깔개 · 카운터 + 쇠살 + NPC + 카운터 위 물건 · 긴 의자 둘 · 기입대 · 괘종시계 · 동전 저울 · 벽등 · 매단 등"""
    for i in range(16):                                      # 홀 바닥: 두 톤 돌 바둑판(판 2.0, 높이 0.04 — 충돌 없음, 비평 1차 맨바닥)
        for j in range(6):
            bx(g, "StoneTrim" if (i + j) % 2 else "Stone", -XI + i * 2.0 - 0.2 * (i == 0), -XI + (i + 1) * 2.0, YI0 + j * 1.96, YI0 + (j + 1) * 1.96, FZ, FZ + 0.04)
    P.rug(g, -3.0, 3.0, YI0 + 0.3, COUNTER[2] - 0.6, FZ, "Banner", "SignGold", "SignGold")
    x0, x1, y0, y1 = COUNTER
    zt = bank_counter(g, x0, x1, y0, y1)
    KB.grille(g, x0, x1, (y0 + y1) / 2, zt, FZ + 9.0, gaps=((-4.5, -2.0), (-1.5, 1.0)))
    for x, y in NPCS:
        NPC(x, y, FZ, 0.0)
    # 카운터 위(손님 쪽): 창구마다 동전 접시 · 장부 · 놋쇠 갓 등 / 오른쪽 환전 천칭 · 동전 기둥
    for xc in (-3.25, -0.25):
        g["Brass"].cyl(xc, y0 + 0.5, zt, 0.42, 0.48, 0.1, seg=12)
        P.coin_stack(g, xc + 0.15, y0 + 0.5, zt + 0.1, n=2, r=0.16)
        bx(g, "Leather", xc - 1.0, xc - 0.45, y0 + 0.2, y0 + 1.0, zt, zt + 0.22)
        bx(g, "Paint", xc - 0.95, xc - 0.5, y0 + 0.25, y0 + 0.95, zt + 0.22, zt + 0.26)
    P.scale(g, 1.6, y0 + 0.55, zt, rz=0.0)
    for k, xx in enumerate((-4.6, -4.2)):
        P.coin_stack(g, xx, y0 + 0.4 + 0.3 * (k % 2), zt, n=3 + k, r=0.2)
    for x in (-4.6, 2.1):
        g["Brass"].cyl(x, y1 - 0.4, zt, 0.3, 0.2, 0.15, seg=10)
        g["Iron"].cyl(x, y1 - 0.4, zt + 0.15, 0.06, 0.06, 1.3, seg=6)
        g["Brass"].cyl(x, y1 - 0.4, zt + 1.1, 0.55, 0.2, 0.45, seg=12)
        g["Glow"].box(x, y1 - 0.4, zt + 1.05, 0.28, 0.28, 0.1)
    # 홀 양옆 긴 의자 · 의자 위 벽등
    bench_wall(g, -1, -10.6, -5.6)       # 짧게 — 왼 길(벽 ~ 카운터 왼끝) 10 을 비움(비평 1차)
    bench_wall(g, 1, -6.2, -4.0)         # 오른쪽은 짧게(둘 자리) — 앞에 동전 저울 · 괘종시계(오른 길 어귀를 비움)
    for s in (-1, 1):
        for yy in (-9.6, -3.4):
            P.sconce(g, "y", s * XI, yy, FZ + 7.2, face=-s)
    writing_desk(g, -11.0, -10.8)         # 왼 앞(긴 의자 앞 — 왼 길(카운터 왼끝 ~ 벽, y 0 언저리)을 비움)
    tall_clock(g, 14.5, -11.3, 0.0)      # 오른 앞 구석(창 옆)
    coin_machine(g, XI, -8.4)            # 오른 벽 앞쪽(괘종시계와 짧은 긴 의자 사이 — 오른 길 어귀 y 0 언저리는 비움)
    for x, y in ((-3.4, -9.0), (3.4, -9.0), (-3.4, -2.5), (3.4, -2.5)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


# ------------------------------------------------------------------ 직원 칸
def staff(g):
    """왼 벽: 장부 책상(창 밑) + 의자 · 장부 책장 / 금고 벽 앞 놋쇠 문장 · 벽등 둘 / 매단 등"""
    xw = -XI
    # (비평 1차 2026-11-24) 왼 벽 장부 책상·책장은 뺐다: 카운터 왼끝 ~ 금고 벽 모서리 ~ 회랑 어귀가 모두 10 이 되려면 이 벽은 비어야 한다.
    # 장부 자리는 카운터 위(창구마다 장부)와 금고실 장부 책상이 맡는다. 벽에는 기대지 않는 높이(바닥 위 7 위)의 장부 선반 하나만
    bx(g, "Wood", xw, xw + 0.9, 3.0, 11.0, FZ + 7.2, FZ + 7.4)
    for k, y in enumerate((3.4, 5.4, 7.4, 9.4)):
        brace(g, xw, y, FZ + 6.4)
    K.L.transformed(g, Matrix.Translation((xw + 0.45, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                    lambda q: P.book_row(q, 3.1, 10.9, 0.0, FZ + 7.4, depth=0.8, start=2, face=-1))
    # 금고 벽 앞(직원 칸 쪽 면) 장식: 위 놋쇠 문장(동전 + 열쇠 구멍) · 벽등 둘
    g["Brass"].hcyl(0, VY0 - 0.25, FZ + 9.3, 0.95, 0.3, axis="y", seg=20)
    g["Iron"].hcyl(0, VY0 - 0.4, FZ + 9.3, 0.7, 0.08, axis="y", seg=20)
    g["Brass"].hcyl(0, VY0 - 0.45, FZ + 9.45, 0.18, 0.06, axis="y", seg=8)
    g["Brass"].obox(0, VY0 - 0.45, FZ + 9.1, 0.18, 0.06, 0.35)
    for x in (-5.8, 5.8):
        P.sconce(g, "x", VY0, x * 5.3 / 5.8, FZ + 8.6, face=-1)
    for x, y in ((-9.0, 4.0), (-9.0, 10.5), (10.8, 4.0), (10.8, 10.5)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def brace(g, xw, y, z):
    """벽 선반 까치발(벽 x = xw 에서 방 쪽으로 비스듬한 각재)"""
    g["Timber"].obox(xw + 0.4, y, z + 0.4, 0.15, 0.15, 1.1, ry=0.7)


def _books_y(g, x, y0, y1, z, start):
    """y 를 따라 선 책장 한 단(등이 +x 를 봄) — book_row 를 90° 돌려 쓴다"""
    K.L.transformed(g, Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                    lambda q: P.book_row(q, y0, y1, 0.0, z, depth=0.8, start=start, face=-1))


# ------------------------------------------------------------------ 금고
def _arc(cx, cz, r, n=32):
    return [(cx + r * math.cos(2 * math.pi * k / n), cz + r * math.sin(2 * math.pi * k / n)) for k in range(n + 1)]


def round_hole_wall(g, mat, ax, c, th, u0, u1, z0, z1, cu, cz, r, n=32):
    """벽(u0..u1 × z0..z1, 두께 th)에 둥근 구멍: 구멍 위·아래를 세로 조각(볼록 다각형)으로 채우고 양옆 기둥. 바닥 밑 원은 잘림"""
    pts = _arc(cu, cz, r, n)
    for p, q in zip(pts, pts[1:]):
        if p[1] >= cz - 1e-6 and q[1] >= cz - 1e-6:
            poly = [p, q, (q[0], z1), (p[0], z1)]
        else:
            poly = K._clip_hp([(p[0], z0), (q[0], z0), q, p], 0.0, -1.0, -z0)
        if len(poly) >= 3:
            K.wall_prism(g, mat, ax, c, th, poly)
    K.wall_prism(g, mat, ax, c, th, [(u0, z0), (cu - r, z0), (cu - r, z1), (u0, z1)])
    K.wall_prism(g, mat, ax, c, th, [(cu + r, z0), (u1, z0), (u1, z1), (cu + r, z1)])


def ring_prism(g, mat, ax, c, th, cu, cz, r0, r1, zmin, n=32):
    """벽 면에 붙는 둥근 테(r0..r1, 바닥 zmin 밑은 잘림)"""
    a, b = _arc(cu, cz, r0, n), _arc(cu, cz, r1, n)
    for k in range(n):
        poly = K._clip_hp([a[k], a[k + 1], b[k + 1], b[k]], 0.0, -1.0, -zmin)
        if len(poly) >= 3:
            K.wall_prism(g, mat, ax, c, th, poly)


def vault_shell(g):
    """금고 앞벽(둥근 구멍 + 쇠 안 테 + 쇠 겉 테 + 놋쇠 띠 + 빗장 구멍) · 옆벽 둘(회랑 문 + 들린 쇠살문) · 돌 천장 · 바닥 놋쇠 별"""
    zc = FZ + VZC
    yc = (VY0 + VY1) / 2
    round_hole_wall(g, "Stone", "x", yc, VY1 - VY0, -VXO, VXO, FZ, VCEIL, 0.0, zc, VR + 0.3)
    ring_prism(g, "Steel", "x", yc, VY1 - VY0, 0.0, zc, VR, VR + 0.32, FZ)             # 구멍 안 쇠 테(벽 두께 전부)
    ring_prism(g, "Iron", "x", VY0 - 0.15, 0.3, 0.0, zc, VR + 0.3, VR + 1.0, FZ)       # 겉 쇠 테(직원 칸 쪽)
    ring_prism(g, "Brass", "x", VY0 - 0.12, 0.42, 0.0, zc, VR + 1.0, VR + 1.18, FZ)
    for k in range(10):                                                              # 빗장 구멍(문짝 빗장이 들어가는 자리)
        a = math.pi / 2 + 2 * math.pi * k / 10
        zz = zc + (VR + 0.15) * math.sin(a)
        if zz > FZ + 0.6:
            g["Char"].obox((VR + 0.15) * math.cos(a), VY0 + 0.3, zz, 0.5, 0.62, 0.5, ry=-a)
    bx(g, "StoneTrim", -VXO - 0.15, VXO + 0.15, VY0 - 0.2, VY1, FZ, FZ + 0.6)          # 밑 띠돌
    bx(g, "StoneTrim", -VXO - 0.2, VXO + 0.2, VY0 - 0.3, VY1, VCEIL - 0.3, VCEIL + 0.1)
    for s in (-1, 1):                                                                # 앞벽 모서리 돌 기둥(벽보다 0.2 내밈)
        bx(g, "StoneTrim", *sorted((s * VXO, s * (VXO - 0.9))), VY0 - 0.2, VY0, FZ, VCEIL - 0.3)
    cbox(-VXO, -VR, VY0, VY1, FZ, VCEIL)
    cbox(VR, VXO, VY0, VY1, FZ, VCEIL)
    cbox(-VR, VR, VY0, VY1, zc + 3.0, VCEIL)
    # 옆벽(회랑 문 GATE, 높이 8.4 — 위 돌 인방)
    gz = FZ + 8.4
    for s in (-1, 1):
        xa, xb = sorted((s * VX, s * VXO))
        for y0, y1 in ((VY1, GATE[0] - 0.4), (GATE[1] + 0.4, YI1)):     # 문설주 면은 문설주만(비평 1차 겹친 면)
            bx(g, "Stone", xa, xb, y0, y1, FZ, VCEIL)
            cbox(xa, xb, y0, y1, FZ, VCEIL)
        cbox(xa, xb, GATE[0] - 0.4, GATE[0], FZ, VCEIL)
        cbox(xa, xb, GATE[1], GATE[1] + 0.4, FZ, VCEIL)
        bx(g, "Stone", xa, xb, GATE[0] - 0.4, GATE[1] + 0.4, gz + 0.4, VCEIL)
        for y0, y1 in ((GATE[0] - 0.4, GATE[0]), (GATE[1], GATE[1] + 0.4)):            # 문설주 돌(양쪽 0.2 내밈)
            bx(g, "StoneTrim", xa - 0.2, xb + 0.2, y0, y1, FZ, gz + 0.4)
        bx(g, "StoneTrim", xa - 0.2, xb + 0.2, GATE[0] - 0.4, GATE[1] + 0.4, gz, gz + 0.4)
        # 들린 쇠살문: 살 끝(창날)만 인방 밑으로 0.7 보인다 + 가로대
        xm = s * (VX + VXO) / 2
        y = GATE[0] + 0.35
        while y < GATE[1] - 0.3:
            bx(g, "Iron", xm - 0.1, xm + 0.1, y - 0.1, y + 0.1, gz - 0.55, gz + 0.1)
            g["Iron"].obox(xm, y, gz - 0.62, 0.14, 0.14, 0.14, rx=0.785)
            y += 0.8
        bx(g, "Iron", xm - 0.12, xm + 0.12, GATE[0] + 0.1, GATE[1] - 0.1, gz - 0.35, gz - 0.15)
        # 감개(회랑 쪽 벽 높이 — 머리 위): 쇠 바퀴 + 축 받침 + 사슬(쇠 띠)
        xo = s * (VXO + 0.25)
        g["Iron"].hcyl(xo, 13.4, FZ + 7.6, 0.85, 0.16, axis="x", seg=14)
        g["Brass"].hcyl(xo, 13.4, FZ + 7.6, 0.3, 0.35, axis="x", seg=8)
        for k in range(4):
            a = k * math.pi / 4
            g["Iron"].obox(xo, 13.4, FZ + 7.6, 0.1, 1.5, 0.1, rx=a)
        bx(g, "Iron", *sorted((s * VXO, s * (VXO + 0.12))), 13.0, 13.8, FZ + 7.0, FZ + 8.2)
        g["Iron"].obox(xo, (13.4 + GATE[0]) / 2 + 0.3, FZ + 8.3, 0.08, GATE[0] - 13.4 + 0.4, 0.08)
    # 돌 천장(옆벽·앞벽 위) — 평보 둘이 그 위에 얹힌다
    bx(g, "Stone", -VXO, VXO, VY0, YI1, VCEIL, FZ + 11.0)
    for y in (16.8, 20.4):
        bx(g, "StoneTrim", -VX, VX, y - 0.35, y + 0.35, VCEIL - 0.45, VCEIL)              # 천장 돌 들보
    # 금고실 바닥: 놋쇠 별(바닥에 박은 테 + 네 갈래)
    S = K.S
    S.ring(g, "Brass", 0.0, 18.6, FZ, 1.6, 1.85, 0.03, n=20)
    for k in range(4):
        g["Brass"].obox(0.0, 18.6, FZ + 0.015, 0.22, 3.2, 0.03, rz=k * math.pi / 4)


def _leaf_local(q):
    """문짝(제 좌표: 경첩 축 = z 축, 닫히면 -x 로 뻗고 앞면이 -y). 바깥 판(쇠, 반지름 4.7, 두께 0.8) + 마개(Steel 4.2, 1.8) +
    가장자리 빗장 9 · 놋쇠 테 · 바퀴 손잡이(살 셋 + 테 조각 12) · 다이얼 · 리벳 고리 · 경첩 팔·통"""
    cu, zc = -HINGE[0], VZC
    disc = K._clip_hp(_arc(cu, zc, 4.4, 36)[:-1], 0.0, -1.0, -0.05)
    plug = K._clip_hp(_arc(cu, zc, 4.2, 36)[:-1], 0.0, -1.0, -0.1)
    K.wall_prism(q, "Iron", "x", -0.7, 0.8, disc)
    K.wall_prism(q, "Iron", "x", 0.6, 1.8, plug)          # 마개도 짙은 쇠(비평 1차: 흰 Steel 원판이 첫 초점이 됐다)
    # 뒷면(마개 +y 면, 열면 홀 쪽) 빗장 장치: 놋쇠 기어 통 · 빗장 막대 9 · 시한 자물쇠 상자(유리 + 다이얼 둘) · 가로 띠 둘 · 리벳 16
    q["Brass"].hcyl(cu, 1.7, zc, 0.8, 0.4, axis="y", seg=16)
    K.S.gear(q, "Brass", cu, 1.95, zc, 0.55, 10, 0.12)
    for k in range(9):
        a = math.pi / 2 + 2 * math.pi * k / 9
        if zc + 3.9 * math.sin(a) > 0.7:
            q["Iron"].obox(cu + 2.3 * math.cos(a), 1.65, zc + 2.3 * math.sin(a), 3.1, 0.3, 0.3, ry=-a)
    q["Iron"].box(cu + 1.6, 1.7, zc + 1.7, 1.4, 0.4, 1.0)
    q["Glass"].box(cu + 1.6, 1.92, zc + 1.75, 1.1, 0.06, 0.7)
    for dx in (-0.3, 0.3):
        q["Brass"].hcyl(cu + 1.6 + dx, 1.97, zc + 1.75, 0.22, 0.06, axis="y", seg=10)
    for dz in (-1.8, 1.8):
        q["Iron"].box(cu, 1.6, zc + dz, 2 * math.sqrt(max(0.5, 4.0 ** 2 - dz * dz)), 0.12, 0.4)
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        if zc + 3.9 * math.sin(a) > 0.4:
            q["Brass"].hcyl(cu + 3.9 * math.cos(a), 1.55, zc + 3.9 * math.sin(a), 0.12, 0.12, axis="y", seg=6)
    for k in range(9):                                     # 가장자리 빗장(마개 둘레에서 바깥으로)
        a = math.pi / 2 + 2 * math.pi * k / 9
        zz = zc + 4.45 * math.sin(a)
        if zz > 0.7:
            q["Steel"].obox(cu + 4.45 * math.cos(a), 0.6, zz, 0.9, 0.5, 0.5, ry=-a)
            q["Brass"].obox(cu + 4.95 * math.cos(a), 0.6, zc + 4.95 * math.sin(a), 0.12, 0.56, 0.56, ry=-a)
    q["Brass"].hcyl(cu, -1.15, zc, 3.6, 0.1, axis="y", seg=32)
    q["Iron"].hcyl(cu, -1.2, zc, 3.3, 0.1, axis="y", seg=32)
    for k in range(16):                                    # 리벳 고리(바깥 판)
        a = 2 * math.pi * (k + 0.5) / 16
        zz = zc + 4.0 * math.sin(a)
        if zz > 0.35:
            q["Brass"].hcyl(cu + 4.0 * math.cos(a), -1.16, zz, 0.13, 0.12, axis="y", seg=6)
    q["Brass"].hcyl(cu, -1.55, zc, 0.5, 0.7, axis="y", seg=12)      # 바퀴 축
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        q["Brass"].obox(cu + 0.85 * math.cos(a), -1.85, zc + 0.85 * math.sin(a), 1.7, 0.18, 0.22, ry=-a)
        q["Brass"].hcyl(cu + 1.95 * math.cos(a), -2.05, zc + 1.95 * math.sin(a), 0.16, 0.45, axis="y", seg=8)
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        q["Iron"].obox(cu + 1.7 * math.cos(a), -1.88, zc + 1.7 * math.sin(a), 0.24, 0.24, 0.95, ry=-a)
    q["Brass"].hcyl(cu + 2.1, -1.3, zc + 2.2, 0.55, 0.2, axis="y", seg=14)       # 다이얼
    q["Dial"].hcyl(cu + 2.1, -1.42, zc + 2.2, 0.42, 0.06, axis="y", seg=14)
    q["Iron"].obox(cu + 2.15, -1.47, zc + 2.32, 0.06, 0.04, 0.3, ry=-0.5)
    for zz in (1.0, 5.8):                                  # 경첩 팔 + 통
        q["Iron"].obox(-0.95, -0.7, zz, 1.9, 0.5, 0.7)
        q["Iron"].cyl(0.0, -0.7, zz - 0.8, 0.45, 0.45, 1.6, seg=10)
        q["Brass"].cyl(0.0, -0.7, zz + 0.8, 0.2, 0.15, 0.3, seg=8)


def vault_door(g):
    """열린 둥근 금고 문짝: 오른 경첩(HINGE)에서 밖(직원 칸 쪽)으로 OPEN° — 길(구멍 앞 폭 8.8 · 오른 길 8.4)을 막지 않는 각"""
    hx, hy = HINGE
    th = math.radians(OPEN)
    K.L.transformed(g, Matrix.Translation((hx, hy, FZ)) @ Matrix.Rotation(th, 4, "Z"), _leaf_local)
    for zz in (1.0, 5.8):                                  # 경첩 받침(벽에 박은 쇠판)
        bx(g, "Iron", hx - 0.3, hx + 0.9, hy - 1.2, hy, FZ + zz - 0.9, FZ + zz + 0.9)
    c, s = math.cos(th), math.sin(th)
    lx, ly = -HINGE[0], 0.2
    K.I.C(hx + lx * c - ly * s, hy + lx * s + ly * c, FZ + VZC, 8.8, 2.6, 2 * 4.4 - 0.6, th)


def vault_room(g):
    """금고실 뒤 2.6: 뒷벽 대여 금고 서랍 벽 · 옆벽 금괴 선반 둘 · 가운데 장부 책상 · 사이 돈자루 · 돌 천장 매단 등 둘"""
    P.deposit_wall(g, "x", YI1, -VX + 0.1, VX - 0.1, FZ, cols=6, rows=6, face=-1, depth=0.7)
    yb0 = GATE[1] + 0.15
    for s in (-1, 1):                                       # 금괴 선반(옆벽, 3 단)
        xw = s * VX
        tops = P.shelf(g, "y", xw, yb0, YI1 - 0.8, FZ, 5.0, depth=1.1, levels=3, face=-s, bay=1.6, back=False)
        for k, z in enumerate(tops):
            for yy in (yb0 + 0.35, yb0 + 0.88):            # 금괴(긴 쪽이 x — 선반 깊이 방향) 둘 + 위 하나
                P.gold_bar(g, xw - s * 0.55, yy, z, rz=0.0)
            P.gold_bar(g, xw - s * 0.55, yb0 + 0.62, z + 0.3, rz=0.0 if k % 2 else 0.12)
    # 장부 책상(서서 쓰는 비탈 책상) + 펼친 장부 · 동전 기둥 · 천칭
    zt = P.table(g, -1.9, 1.9, GATE[1] + 0.3, YI1 - 0.85, FZ, h=3.2)
    g["Wood"].obox(0.0, (GATE[1] + YI1 - 0.55) / 2, zt + 0.3, 3.4, 1.1, 0.12, rx=-0.28)
    bx(g, "Leather", -1.5, -0.1, GATE[1] + 0.6, GATE[1] + 1.2, zt + 0.25, zt + 0.45)
    bx(g, "Paint", -1.42, -0.18, GATE[1] + 0.65, GATE[1] + 1.15, zt + 0.45, zt + 0.5)
    P.coin_stack(g, 0.6, GATE[1] + 0.9, zt, n=6, r=0.2)
    P.coin_stack(g, 1.1, GATE[1] + 0.8, zt, n=3, r=0.2)
    g["Iron"].cyl(1.5, YI1 - 1.2, zt, 0.16, 0.12, 0.28, seg=8)
    # 돈자루(책상과 선반 사이)
    for s in (-1, 1):
        for k, (dx, dy, sc, rz) in enumerate(((2.5, 23.3, 0.6, 0.3), (2.8, 23.85, 0.5, -0.5), (2.6, 23.5, 0.45, 1.2))):
            P.sack(g, s * dx, dy, FZ if k < 2 else FZ + 0.6, s=sc, rz=rz * s, mark="SignGold")
        cbox(*sorted((s * 2.0, s * 3.2)), 22.85, 24.25, FZ, FZ + 1.3)
    for y in (16.8, 20.4):
        K.lantern(g, 0.0, y, VCEIL - 0.45, FZ + 7.4)
    for y in (16.8, 20.4):
        for s in (-1, 1):
            g["Glow"].box(s * (VX - 0.05), y, FZ + 8.6, 0.1, 0.5, 0.5)
            g["LampPt"].box(s * (VX - 0.5), y, FZ + 8.0, 0.3, 0.3, 0.3)


def corridors(g):
    """회랑 둘: 붉은 융단 · 바깥 벽 벽등 셋 + 안쪽 벽 둘 · 그림 액자 둘 · 끝 벽 난방기(관 · 놋쇠 핀) · 끝 등받이 의자"""
    for s in (-1, 1):
        xa, xb = sorted((s * VXO, s * XI))
        xm = (xa + xb) / 2
        P.rug(g, xm - 2.0, xm + 2.0, VY0 + 0.4, YI1 - 0.5, FZ, "Banner", "SignGold", "SignGold")
        for y in (14.6, 23.6):
            P.sconce(g, "y", s * XI, y, FZ + 7.4, face=-s)
        for y in (13.2, 24.0):
            P.sconce(g, "y", s * VXO, y, FZ + 7.4, face=s)
        for y, sky, hill in ((16.6, "SignBlue", "PaintGreen"), (21.4, "SignTeal", "Stone")):
            xw = s * XI
            bx(g, "Brass", *sorted((xw, xw - s * 0.18)), y - 1.3, y + 1.3, FZ + 4.2, FZ + 6.6)
            bx(g, sky, *sorted((xw - s * 0.18, xw - s * 0.24)), y - 1.1, y + 1.1, FZ + 4.4, FZ + 6.4)
            K.wall_prism(g, hill, "y", xw - s * 0.3, 0.06, [(y - 1.0, FZ + 4.75), (y + 1.0, FZ + 4.75), (y - 0.1, FZ + 5.9)])
            bx(g, "Paint", *sorted((xw - s * 0.24, xw - s * 0.3)), y - 1.1, y + 1.1, FZ + 4.4, FZ + 4.75)
        # 끝 벽 난방기(뒷벽 y = YI1): 돌 받침 · 놋쇠 핀 일곱 · 구리 관 둘(벽 속으로)
        bx(g, "Stone", xm - 2.4, xm + 2.4, YI1 - 0.7, YI1, FZ, FZ + 0.4)
        for k in range(7):
            xx = xm - 1.8 + 0.6 * k
            bx(g, "Brass", xx - 0.18, xx + 0.18, YI1 - 0.6, YI1 - 0.1, FZ + 0.4, FZ + 2.6)
        for zz in (FZ + 0.8, FZ + 2.3):
            g["Copper"].hcyl(xm, YI1 - 0.35, zz, 0.16, 4.4, axis="x", seg=8)
        cbox(xm - 2.4, xm + 2.4, YI1 - 0.7, YI1, FZ, FZ + 2.6)


def signs(g):
    coin = lambda g_, x, y, z, f: K.SVC.coin_icon(g_, x, y, z - 0.75, face=f)    # noqa: E731
    K.hang_sign(g, AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=1)
    K.hang_sign(g, -AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=-1)


def steam(g):
    tx, ty = -12.5, -15.7
    rx = -8.4
    K.steam_bundle(g, tx, ty, 0.0, h=6.4, r=1.15, gauge_face=-1, vent=False,       # 김 자리는 처마 밑이라 뺌(holes.py 김 검사)
                   pipe_pts=[(tx + 1.15, ty, 4.2), (rx, ty, 4.2), (rx, -14.3, 4.2), (rx, -14.3, 12.6), (rx, -13.3, 12.6)])
    for z in (7.4, 10.4):
        bx(g, "Iron", rx - 0.45, rx + 0.45, -14.7, AYF, z - 0.12, z + 0.12)


def build(g):
    K.foundation(g, -AX - 0.3, AX + 0.3, AYF - 0.3, AYB + 0.3)
    K.stair(g, 0.0, AYF - 0.3, 14.0, FZ)
    walls(g)
    portal(g)
    roof(g)
    hall(g)
    staff(g)
    vault_shell(g)
    vault_door(g)
    vault_room(g)
    corridors(g)
    signs(g)
    steam(g)
    CLEAR(-4.7, 4.7, YI0 + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)      # 안으로 연 문짝 띠가 0.1~0.3 들어와 ±4.7
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.15, FZ + 0.15, FZ + 5.4)
    CLEAR(-2.8, 2.8, VY0 + 0.2, VY1 + 1.0, FZ + 0.15, FZ + 5.4)    # 금고 문 구멍: 둥근 구멍은 발밑 폭 5.6(원) — 걷는 높이(바닥 + 2.5) 충돌 폭은 8.8
    for s in (-1, 1):
        CLEAR(*sorted((s * VX - s * 0.5, s * VXO + s * 0.5)), GATE[0] + 0.1, GATE[1] - 0.1, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((0.0, YF - 1.5), (0.0, -3.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI1),
    "forge_look": (0.0, VY0),
    # 금고 문(2026-11-18 1팀): 열린 문짝. 퀘스트로 닫을 땐 문짝(경첩 축 hinge, 연 각 open_deg)을 0° 로 돌리면 구멍을 막는다(지금은 메시에 합쳐 있음)
    "vault_door": {"hole_center": (0.0, VY0, FZ + VZC), "hole_radius": VR, "leaf_radius": 4.4, "hinge": (HINGE[0], HINGE[1], FZ),
                   "open_deg": OPEN, "face": "-y"},
    # holes.py 눈 자리(방에서 보이는 자리만 셀 때) — 금고실 가운데 · 회랑 둘 · 직원 칸
    "hole_seeds": [(0.0, 18.6, FZ + 4.5), (-11.6, 18.6, FZ + 4.5), (11.6, 18.6, FZ + 4.5), (-8.0, 7.0, FZ + 4.5), (10.0, 7.0, FZ + 4.5)],
    # 한 바퀴 통로(int1_render.py check — 폭 8 이상): (이름, 출발, 도착)
    # 문(가운데 x, y, 반폭) — int1_render check 가 가장 좁은 자리가 문 안이면 문 기준 8, 아니면 길 10(비평 1차)
    "doors_xy": [(0.0, (VY0 + VY1) / 2, VR), (-(VX + VXO) / 2, (GATE[0] + GATE[1]) / 2, 4.2), ((VX + VXO) / 2, (GATE[0] + GATE[1]) / 2, 4.2)],
    "loops": [("홀 → 직원 칸(왼 길)", (-10.0, -2.5), (-6.0, 7.0)), ("직원 칸 → 금고실(금고 문)", (-6.0, 6.5), (0.0, 18.6)),
              ("금고실 → 왼 회랑", (0.0, 18.6), (-10.8, 18.6)), ("금고실 → 오른 회랑", (0.0, 18.6), (10.8, 18.6)),
              ("왼 회랑 → 직원 칸", (-10.8, 18.6), (-6.0, 7.0)), ("오른 회랑 → 홀(오른 길)", (10.8, 18.6), (2.0, -6.0))],
}
