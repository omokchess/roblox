# -*- coding: utf-8 -*-
"""
b_mast.py — 2026-11-25 아트 3팀(2판). 설원 마을 3판: 비행선 계류탑 — 플레이어가 계단이나 증기 승강기로 올라가 꼭대기 승강장에서
옆 다리를 건너 비행선(b_airship.py) 곤돌라 옆문으로 탄다. 1판(높이 46, 10×10 격자탑 + 사다리, 2팀이 밑을 고친 것)은 갈아엎음.
사용자(2026-11-23): "플레이어가 진짜 들어가서 탈 수 있도록 하자. 그만큼 비행정 그 탑 높이도 높게 하고."

레퍼런스(회사/설원마을_레퍼런스.md AS 절 · K4~K6): 카딩턴 계류탑(꼭대기 둘레 승강장 + 지붕 · 가운데 승강기 · 나선 계단 · 코 계류 컵),
USS 애크런·굿이어 계류탑(쇠 격자 다리 · 가로대 · X 가새 · 리벳 이음판), 보일러실(돌 받침 위 기계). 블록감 있는 양식화 — 가는 실선 금지.

발자국 22.1 × 22.1(돌 발 받침 포함), 승강장 바닥 HP = 49(= 곤돌라 바닥), 꼭대기 경고등 약 86.
짜임(실제 공사처럼 — 받침이 없는 것 없음):
  돌 바닥판(1.0) + 모서리 돌 발 받침 넷 → 모서리 다리 넷(쇠 상자 기둥 + 덧판) · 면 가운데 기둥 → 층 띠보(12 · 24 · 36 · 48) → 층마다 X 가새
  → 1층 둘레 리벳 쇠판 벽(정문 8×9 · 쇠살 창) · 가운데 승강로(기둥 넷 = 머리 돛대 다리로 이어짐 · 쇠살 · 묶음 띠)
  → 계단(폭 6 · 한 단 1 · 디딤 2.4, 모서리 쉼참마다 꺾어 세 바퀴): 쉼참은 다리·계단 기둥·승강로 기둥 사이 보 넷 위 · 계단은 옆판 둘 위 디딤
     · 바깥 난간은 계단 기둥·다리 사이에만(난간 위 기둥 없음) · 쉼터(17 · 33 북동 쉼참: 걸상 · 벽 등)
  → 꼭대기 승강장(36.5 × 34, 탑 밖으로 내밀고 까치발이 받침): 쇠 무늬판 · 둘레 기둥 + 기둥 사이 난간 · 잘린 모임지붕 차양(눈) · 등 · 비행선 간판
  → 비행선 다리(동남, 폭 8 · 길이 17.7): 옆 보 둘 + 가로보 · 무늬판 · 바깥 난간 · 등 기둥 · 탑 남면에서 비스듬한 버팀대 셋
  → 머리 돛대(승강로 기둥 위, 좁아지며 77.5 까지): 아래 칸 쇠살(승강기 칸이 서는 곳, 동쪽 트임) · 기계 바닥(감개 북 · 증기 실린더 · 톱니 · 작은 보일러)
     · X 가새 · 원통 머리(놋쇠 띠) · 남쪽 계류 팔 + 컵(비행선 코 막대가 들어감) · 위 갓 · 붉은 경고등
움직이는 틀: 승강기 칸 Sn3_MastLift(b_mastlift.py, 1층 바닥 1.0 ↔ 승강장 49).
"""
import math

import lib as K
import lib_a as A
import lib_b as LB
import lib_int2 as N
import lib_int3 as Q
from lib import bx, cbox

NAME = "Sn3_Mast"
PREFIX = "Sn3Mast"
VARIANT = "A"

F0 = 1.0                         # 1층 바닥 윗면
HP = Q.HP                        # 승강장 바닥(49)
LEG, LS = 10.3, 1.1              # 다리 가운데 · 단면(바깥 10.85)
GIRD = ((11.2, 12.0), (23.2, 24.0), (35.2, 36.0), (47.3, 48.1))
SP, SPS = 3.3, 0.6               # 승강로 기둥 가운데 · 단면(3.0..3.6)
SI, SO = 3.6, 9.6                # 계단 안 · 바깥 선
COL_U, COL_V = 3.85, 9.7         # 계단 기둥(옆마다 둘)
NFL = 12                         # 계단 판 수(4 단씩 = 48)
PX0, PX1, PY0, PY1 = -18.0, 18.5, -18.0, 16.0      # 승강장
GW_X0, GW_X1, GW_Y1 = 9.7, 19.7, 33.7              # 비행선 다리 바닥 폭 10(2026-11-27 비평 비행선_1차 3번: 길 10 — 바깥 난간 19.7..20.3)
GW_IN_Y = 21.9                                     # 다리 안쪽 난간 끝(그 뒤로는 곤돌라 옆벽이 0.7 틈으로 붙는다)
HEAD_TOP = 77.0                  # 계류 머리 사각 트러스 꼭대기(2026-11-27 2판: 몸통 다리를 지붕 위로 올려 12 폭으로 좁힘)
HW_TOP = 6.0                     # 꼭대기 다리 가운데 반폭(폭 12)
TUR_R = 2.5                      # 도는 원통 머리 반지름(지름 5 · 높이 6)
LFOOT, FOOT_Z = 16.5, 3.45       # 벌어진 바깥 다리 발(땅 34×34) · 발 받침 윗면(돌 받침 높이 3)
SKIRT = 18.5                     # 돌 밑단 판 반폭(37×37, 높이 1.0 = 1층 바닥)
LIFT_BOTTOM = (0.0, 0.0, F0)     # 승강기 칸 바닥 윗면 자리(아래 · 위)
LIFT_TOP = (0.0, 0.0, HP)

# holes.py: 일부러 트인 자리 — 탑 전체(벽 없는 격자탑 · 승강장 · 다리)
OPEN_ZONES = [(-21.0, 21.0, -19.5, 35.0, 0.0, 90.0, "쇠 격자 계류탑 · 둘레 트인 승강장 · 비행선 다리(K4~K6 · AS5)")]


# ------------------------------------------------------------------ 계단 좌표(옆 s: 0 동 · 1 남 · 2 서 · 3 북, 90° 씩 돈다)
def R(s, u, v):
    """옆 s 의 제 좌표(u = 오르는 방향, v = 바깥쪽) → 블렌더 (x, y)"""
    return ((v, u), (-u, v), (-v, -u), (u, -v))[s % 4]


def box_uv(g, mat, s, u0, u1, v0, v1, z0, z1, coll=False):
    a, b = R(s, u0, v0), R(s, u1, v1)
    x0, x1, y0, y1 = min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1])
    bx(g, mat, x0, x1, y0, y1, z0, z1)
    if coll:
        cbox(x0, x1, y0, y1, z0, z1)


def rail_uv(g, s, fixed, a, b, z0, along="u"):
    """옆 s 제 좌표의 수평 난간(along 축으로 a..b, 다른 축 = fixed)"""
    p, q = (R(s, a, fixed), R(s, b, fixed)) if along == "u" else (R(s, fixed, a), R(s, fixed, b))
    if abs(p[0] - q[0]) > abs(p[1] - q[1]):
        A.rail_between(g, "x", p[1], min(p[0], q[0]), max(p[0], q[0]), z0, h=3.4, gap=1.0, mat="Rail")
    else:
        A.rail_between(g, "y", p[0], min(p[1], q[1]), max(p[1], q[1]), z0, h=3.4, gap=1.0, mat="Rail")


# ================================================================== 1. 바닥 · 다리 · 띠보 · 가새
def frame(g):
    # 돌 바닥판(1.0) + 띠돌 · 모서리 돌 발 받침
    bx(g, "Stone", -11.0, 11.0, -11.0, 11.0, 0.0, F0 - 0.12)
    bx(g, "StoneTrim", -11.05, 11.05, -11.05, 11.05, F0 - 0.12, F0)
    cbox(-11.05, 11.05, -11.05, 11.05, 0.0, F0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * LEG, sy * LEG
            bx(g, "Stone", x - 0.75, x + 0.75, y - 0.75, y + 0.75, 0.0, 1.7)
            bx(g, "StoneTrim", x - 0.8, x + 0.8, y - 0.8, y + 0.8, 1.7, 1.95)
            bx(g, "IronLight", x - 0.7, x + 0.7, y - 0.7, y + 0.7, 1.95, 2.15)
            cbox(x - 0.8, x + 0.8, y - 0.8, y + 0.8, 0.0, 2.15)
            # 다리: 쇠 상자 기둥 + 4 마다 덧판(놋쇠 볼트 띠 대신 쇠 띠)
            bx(g, "Iron", x - LS / 2, x + LS / 2, y - LS / 2, y + LS / 2, 2.15, GIRD[-1][1])
            cbox(x - LS / 2, x + LS / 2, y - LS / 2, y + LS / 2, 2.15, HP)
            z = 4.0
            while z < GIRD[-1][0] - 1.0:
                if not any(a - 0.8 < z < b + 0.3 for a, b in GIRD):
                    bx(g, "Iron", x - LS / 2 - 0.08, x + LS / 2 + 0.08, y - LS / 2 - 0.08, y + LS / 2 + 0.08, z, z + 0.45)
                z += 4.0
    # 면 가운데 기둥(북면은 정문 위 띠보에서 시작)
    for x, y in ((0.0, -LEG), (0.0, LEG), (-LEG, 0.0), (LEG, 0.0)):
        z0 = GIRD[0][1] if y < 0 else F0
        bx(g, "Iron", x - 0.4, x + 0.4, y - 0.4, y + 0.4, z0, GIRD[-1][0])
    # 층 띠보(네 면) + 이음판(다리 · 가운데 기둥 자리, 바깥으로 0.1)
    for za, zb in GIRD:
        for s in (-1, 1):
            bx(g, "Iron", -LEG, LEG, s * LEG - 0.28, s * LEG + 0.28, za, zb)
            bx(g, "Iron", s * LEG - 0.28, s * LEG + 0.28, -LEG, LEG, za, zb)
            for u in (-LEG, 0.0, LEG):
                bx(g, "Iron", u - 0.85, u + 0.85, *sorted((s * (LEG + 0.28), s * (LEG + 0.4))), za - 0.5, zb + 0.5)
                bx(g, "Iron", *sorted((s * (LEG + 0.28), s * (LEG + 0.4))), u - 0.85, u + 0.85, za - 0.5, zb + 0.5)
    # X 가새(2~4 층, 면마다 두 칸) — 띠보 · 다리 · 가운데 기둥 사이
    for (za, zb), (zc, zd) in zip(GIRD, GIRD[1:]):
        for s in (-1, 1):
            for a, b in ((-LEG + 0.6, -0.45), (0.45, LEG - 0.6)):
                for p0, p1 in (((a, zb), (b, zc)), ((b, zb), (a, zc))):
                    A.lattice_leg(g, (p0[0], s * LEG, p0[1]), (p1[0], s * LEG, p1[1]), s=0.45)
                    A.lattice_leg(g, (s * LEG, p0[0], p0[1]), (s * LEG, p1[0], p1[1]), s=0.45)
    # 북면 정문 위 안쪽 머리보(북쪽 계단 기둥이 그 위에 선다)
    bx(g, "Iron", -LEG + 0.5, LEG - 0.5, -COL_V - 0.25, -COL_V + 0.25, GIRD[0][0], GIRD[0][1])


# ================================================================== 1b. 벌어진 바깥 다리 · 돌 발 받침 · 돌 밑단 판
def _lf(z):
    """바깥 다리 가운데 반폭(z): 발(FOOT_Z) 에서 LFOOT → 승강장 밑(GIRD 맨 위) 에서 몸통 다리 LEG"""
    return LFOOT + (LEG - LFOOT) * (z - FOOT_Z) / (GIRD[-1][1] - FOOT_Z)


def splay(g):
    """2026-11-27 비평 비행선_1차 1번(곧은 다리 · 얇은 밑 → 붙잡을 구조로 안 보임): 땅에서 34×34 로 벌어져 승강장 밑에서 몸통 다리와 만나는 바깥 다리 넷 ·
    다리마다 돌 발 받침(4×4 · 높이 3 · 띠돌 테 · 쇠 신) · 둘레 돌 밑단 판(37×37 · 높이 F0=1.0 — 1층 바닥과 한 면, 바깥 띠돌 테 · 정문 앞 계단 2단) ·
    층(12 · 24 · 36)마다 둘레 띠보 + 몸통 다리로 잇는 가로대 · 면마다 ʌ 가새(정문 쪽 아래 칸은 트임). 몸통(계단 틀)은 그대로 안에 선다"""
    ring = ((-SKIRT, SKIRT, -SKIRT, -11.05), (-SKIRT, SKIRT, 11.05, SKIRT), (-SKIRT, -11.05, -11.05, 11.05), (11.05, SKIRT, -11.05, 11.05))
    for x0, x1, y0, y1 in ring:
        bx(g, "Stone", x0, x1, y0, y1, 0.0, F0 - 0.1)
        cbox(x0, x1, y0, y1, 0.0, F0)
        nx, ny = max(1, round((x1 - x0) / 3.7)), max(1, round((y1 - y0) / 3.7))
        for i in range(nx):
            for j in range(ny):
                a, b = x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny
                bx(g, "StoneTrim", a + 0.06, a + (x1 - x0) / nx - 0.06, b + 0.06, b + (y1 - y0) / ny - 0.06, F0 - 0.1, F0)
    # 2026-11-28 비평 비행선_2차 2번: 밑단을 1층 바닥 높이(F0)로 올리고 바깥 모에 띠돌 테(0.3 내밈) + 정문(북, -y) 앞 폭 10 계단 2단(발 앞에서 한 단 0.33)
    o = SKIRT + 0.3
    bx(g, "StoneTrim", -o, o, SKIRT, o, 0.0, 0.55)
    bx(g, "StoneTrim", -o, -5.0, -o, -SKIRT, 0.0, 0.55)
    bx(g, "StoneTrim", 5.0, o, -o, -SKIRT, 0.0, 0.55)
    bx(g, "StoneTrim", -o, -SKIRT, -SKIRT, SKIRT, 0.0, 0.55)
    bx(g, "StoneTrim", SKIRT, o, -SKIRT, SKIRT, 0.0, 0.55)
    for top, y0, y1 in ((0.66, -SKIRT - 1.2, -SKIRT), (0.33, -SKIRT - 2.4, -SKIRT - 1.2)):
        bx(g, "Stone", -5.0, 5.0, y0, y1, 0.0, top - 0.1)
        bx(g, "StoneTrim", -5.0, 5.0, y0, y1, top - 0.1, top)
        cbox(-5.0, 5.0, y0, y1, 0.0, top)
    zt = GIRD[-1][1]
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * LFOOT, sy * LFOOT
            bx(g, "Stone", x - 2.0, x + 2.0, y - 2.0, y + 2.0, 0.3, 2.85)
            bx(g, "StoneTrim", x - 2.2, x + 2.2, y - 2.2, y + 2.2, 2.85, 3.25)
            bx(g, "IronLight", x - 1.2, x + 1.2, y - 1.2, y + 1.2, 3.25, FOOT_Z)
            cbox(x - 2.2, x + 2.2, y - 2.2, y + 2.2, 0.0, FOOT_Z)
            A.lattice_leg(g, (x, y, FOOT_Z - 0.1), (sx * LEG, sy * LEG, zt), s=1.3)
            for z0, z1 in ((FOOT_Z, 8.0), (8.0, 12.5)):                     # 사람 키 높이까지만 충돌
                w = _lf((z0 + z1) / 2)
                cbox(sx * w - 0.65, sx * w + 0.65, sy * w - 0.65, sy * w + 0.65, z0, z1)
            for z in (7.4, 17.4, 29.4, 41.4):                               # 덧판(띠보 사이)
                w = _lf(z + 0.25)
                bx(g, "IronLight", sx * w - 0.85, sx * w + 0.85, sy * w - 0.85, sy * w + 0.85, z, z + 0.5)
            bx(g, "IronLight", sx * LEG - 1.0, sx * LEG + 1.0, sy * LEG - 1.0, sy * LEG + 1.0, 46.6, 48.35)   # 만나는 자리 이음 덩이
    lv = [FOOT_Z + 1.5] + [(a + b) / 2 for a, b in GIRD]
    for za, zb in GIRD[:3]:
        zc = (za + zb) / 2
        w = _lf(zc)
        for s in (-1, 1):
            bx(g, "Iron", -w + 0.3, w - 0.3, s * w - 0.35, s * w + 0.35, zc - 0.45, zc + 0.45)
            bx(g, "Iron", s * w - 0.35, s * w + 0.35, -w, w, zc - 0.4, zc + 0.4)
        for sx in (-1, 1):
            for sy in (-1, 1):
                A.lattice_leg(g, (sx * (w - 0.3), sy * (w - 0.3), zc), (sx * (LEG + 0.6), sy * (LEG + 0.6), zc), s=0.7)
    for k, (za, zb) in enumerate(zip(lv, lv[1:])):
        wa, wb = _lf(za), _lf(zb)
        for face in range(4):
            if k == 0 and face == 0:                                        # 정문(북) 아래 칸은 트임
                continue
            sg = -1 if face in (0, 2) else 1
            for e in (-1, 1):
                p0, p1 = (e * (wa - 0.8), sg * wa, za + 0.3), (e * 0.5, sg * wb, zb - 0.5)
                if face >= 2:
                    p0, p1 = (p0[1], p0[0], p0[2]), (p1[1], p1[0], p1[2])
                A.lattice_leg(g, p0, p1, s=0.55)


# ------------------------------------------------------------------ 1층 둘레 리벳 쇠판 벽 · 정문 · 쇠살 창
def ground_walls(g):
    z0, z1 = F0, GIRD[0][0]
    door = (-4.3, 4.3, F0, F0 + 9.3)
    wins = [(-5.6 - 1.5, -5.6 + 1.5, 4.6, 8.6), (5.6 - 1.5, 5.6 + 1.5, 4.6, 8.6)]
    for side, (ax, c) in enumerate((("x", -LEG), ("x", LEG), ("y", -LEG), ("y", LEG))):
        holes = [door] if side == 0 else wins
        u = -LEG + LS / 2
        cuts = sorted(holes)
        pieces = []
        for h0, h1, hz0, hz1 in cuts:
            pieces += [(u, h0, z0, z1), (h0, h1, z0, hz0), (h0, h1, hz1, z1)]
            u = h1
        pieces.append((u, LEG - LS / 2, z0, z1))
        for a, b, za, zb in pieces:
            if b - a > 0.01 and zb - za > 0.01:
                K.wbox(g, "IronLight", ax, c, 0.3, a, b, za, zb)
                if ax == "x":
                    cbox(a, b, c - 0.15, c + 0.15, za, zb)
                else:
                    cbox(c - 0.15, c + 0.15, a, b, za, zb)
        # 바깥 쇠 띠(아래 · 허리 · 위) + 세로 띠 — 바깥으로 0.12
        out = -1 if c < 0 else 1
        oc = c + out * 0.2
        for za, zb in ((z0, z0 + 0.5), (6.0, 6.4)):
            u = -LEG + LS / 2
            for h0, h1, hz0, hz1 in cuts:
                if hz0 < zb and hz1 > za:
                    K.wbox(g, "Iron", ax, oc, 0.14, u, h0 - 0.35, za, zb)
                    u = h1 + 0.35
            K.wbox(g, "Iron", ax, oc, 0.14, u, LEG - LS / 2, za, zb)
        for p in (-6.9, -2.0, 2.0, 6.9) if side else (-6.9, 6.9):
            if not any(h0 - 0.4 < p < h1 + 0.4 for h0, h1, hz0, hz1 in cuts if hz0 < 9):
                K.wbox(g, "Iron", ax, oc, 0.14, p - 0.25, p + 0.25, z0 + 0.5, z1)
        # 쇠살 창(틀 · 살 넷 · 맑은 유리)
        for h0, h1, hz0, hz1 in holes:
            if hz0 < 2.0:
                continue
            for a, b in ((h0 - 0.05, h0 + 0.25), (h1 - 0.25, h1 + 0.05)):
                K.wbox(g, "Iron", ax, c, 0.5, a, b, hz0, hz1)
            K.wbox(g, "Iron", ax, c, 0.5, h0, h1, hz0 - 0.05, hz0 + 0.25)
            K.wbox(g, "Iron", ax, c, 0.5, h0, h1, hz1 - 0.25, hz1 + 0.05)
            for k in range(1, 4):
                p = h0 + (h1 - h0) * k / 4
                K.wbox(g, "Rail", ax, c + out * 0.12, 0.18, p - 0.09, p + 0.09, hz0 + 0.25, hz1 - 0.25)
            K.wbox(g, "WinGlass", ax, c - out * 0.05, 0.08, h0 + 0.24, h1 - 0.24, hz0 + 0.24, hz1 - 0.24)
    # 정문: 쇠 문설주 · 머리 · 놋쇠 아치 판 + 비행선 그림 · 문지방
    for a, b in ((-4.35, -4.0), (4.0, 4.35)):
        bx(g, "Iron", a, b, -LEG - 0.35, -LEG + 0.35, F0, F0 + 9.3)
    bx(g, "Iron", -4.35, 4.35, -LEG - 0.35, -LEG + 0.35, F0 + 9.0, F0 + 9.4)
    bx(g, "Brass", -3.4, 3.4, -LEG - 0.5, -LEG - 0.3, F0 + 9.4, F0 + 10.15)
    A.airship_icon(g, 0.0, -LEG - 0.4, F0 + 9.45, face=-1, s=0.28)
    bx(g, "StoneTrim", -4.0, 4.0, -LEG - 0.45, -LEG + 0.45, F0 - 0.05, F0 + 0.03)
    Q.door_mark("x", -LEG, 0.0, 8.0, 9.0, F0, -1)
    # 문 앞 디딤: 둘레 돌 밑단 판(splay — 높이 0.5)이 땅 → 바닥 1.0 사이 한 단이 된다


# ================================================================== 2. 승강로
def shaft(g):
    ties = [F0 + 8.0 * k for k in range(7)]          # 1 · 9 · 17 … 49
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * SP, sy * SP
            bx(g, "Iron", x - SPS / 2, x + SPS / 2, y - SPS / 2, y + SPS / 2, 0.0, HP)
            cbox(x - SPS / 2, x + SPS / 2, y - SPS / 2, y + SPS / 2, F0, HP)
    for k, z in enumerate(ties):
        for s in (-1, 1):
            if k > 0:
                bx(g, "Iron", -SP + 0.3, SP - 0.3, s * SP - 0.2, s * SP + 0.2, z - 0.4, z)
                bx(g, "Iron", s * SP - 0.2, s * SP + 0.2, -SP + 0.3, SP - 0.3, z - 0.4, z)
    # 쇠살(옆마다 다섯 줄) — 1층 북쪽(타는 곳)과 꼭대기는 트임
    for face, (ax, c) in enumerate((("x", -SP), ("x", SP), ("y", -SP), ("y", SP))):
        for za, zb in zip(ties, ties[1:]):
            if face == 0 and za < F0 + 1:
                continue
            for p in (-2.4, -1.2, 0.0, 1.2, 2.4):
                K.wbox(g, "Rail", ax, c, 0.2, p - 0.1, p + 0.1, za, zb - 0.4)
            K.wbox(g, "Rail", ax, c, 0.2, -SP + 0.3, SP - 0.3, (za + zb) / 2 - 0.12, (za + zb) / 2 + 0.12)
        if ax == "x":
            cbox(-SP, SP, c - 0.15, c + 0.15, F0 + (8.0 if face == 0 else 0.0), HP)
        else:
            cbox(c - 0.15, c + 0.15, -SP, SP, F0, HP)
    # 1층 타는 곳 머리(놋쇠) + 층 표시 계기 · 칸 받이(쇠 판, 승강기 칸이 1.0 에 선다)
    bx(g, "Brass", -SP, SP, -SP - 0.35, -SP + 0.1, F0 + 7.6, F0 + 8.0)
    g["Brass"].hcyl(0.0, -SP - 0.45, F0 + 8.75, 0.75, 0.2, axis="y", seg=14)
    g["Dial"].hcyl(0.0, -SP - 0.58, F0 + 8.75, 0.6, 0.06, axis="y", seg=14)
    Q.member(g, "Iron", (0.0, -SP - 0.64, F0 + 8.75), (0.4, -SP - 0.64, F0 + 9.15), 0.1, 0.06)


# ================================================================== 3. 계단(세 바퀴)
def stairs(g):
    # 계단 기둥 8(옆마다 둘) — 북쪽은 정문 머리보 위에서
    for s in range(4):
        for u in (-COL_U, COL_U):
            x, y = R(s, u, COL_V)
            z0 = GIRD[0][1] if s == 3 else F0
            bx(g, "Iron", x - 0.25, x + 0.25, y - 0.25, y + 0.25, z0, GIRD[-1][0])
            cbox(x - 0.25, x + 0.25, y - 0.25, y + 0.25, z0, GIRD[-1][0])
    for k in range(NFL + 1):
        s = k % 4
        z0 = F0 + 4.0 * k
        if 0 < k < NFL:
            # 쉼참(모서리 6×6): 무늬판 + 아래 보 넷(다리 · 계단 기둥 · 승강로 기둥 사이)
            box_uv(g, "Iron", s, -SO, -SI, SI, SO, z0 - 0.3, z0, coll=True)          # 2026-11-27 비평 4번: 연회색 → 짙은 쇠
            box_uv(g, "Iron", s, -SO, -SI + 0.05, SI, SI + 0.4, z0 - 0.9, z0 - 0.3)       # 안 보(승강로 기둥 → 북 계단 기둥)
            box_uv(g, "Iron", s, -SI - 0.4, -SI, SI, SO + 0.3, z0 - 0.9, z0 - 0.3)       # 안 보(승강로 기둥 → 이 옆 계단 기둥)
            box_uv(g, "Iron", s, -LEG + 0.5, -COL_U + 0.25, COL_V - 0.25, COL_V + 0.25, z0 - 0.9, z0 - 0.3)   # 바깥 보(다리 → 계단 기둥)
            box_uv(g, "Iron", s, -COL_V - 0.25, -COL_V + 0.25, COL_U - 0.25, LEG - 0.5, z0 - 0.9, z0 - 0.3)   # 바깥 보(다리 → 앞 옆 계단 기둥)
            # 바깥 두 변 난간(다리 ↔ 계단 기둥)
            rail_uv(g, s, SO - 0.15, -LEG + LS / 2, -COL_U - 0.25, z0, "u")
            rail_uv(g, s, -SO + 0.15, COL_U + 0.25, LEG - LS / 2, z0, "v")
            if k in (4, 8):                                                             # 쉼터(북동, 17 · 33): 구석 걸상 + 다리에 단 등
                x, y = R(s, -8.2, 8.65)
                N.put(g, x, y, z0, -math.pi / 2, N.bench, 2.4)
                cbox(x - 0.7, x + 0.7, y - 1.2, y + 1.2, z0, z0 + 1.75)
                lx, ly = R(s, -9.1, 9.1)
                bx(g, "Iron", min(lx, R(s, -9.75, 9.75)[0]) - 0.1, max(lx, R(s, -9.75, 9.75)[0]) + 0.1,
                   min(ly, R(s, -9.75, 9.75)[1]) - 0.1, max(ly, R(s, -9.75, 9.75)[1]) + 0.1, z0 + 7.3, z0 + 7.55)
                K.lantern(g, lx, ly, z0 + 7.3, z0 + 6.0)
        if k == NFL:
            break
        # 계단 판: 옆판 둘(안 · 바깥) + 디딤 셋(무늬판) + 챌판 넷
        for v0, v1 in ((SI, SI + 0.35), (SO - 0.35, SO)):
            p0, p1 = R(s, -SI, (v0 + v1) / 2), R(s, SI, (v0 + v1) / 2)
            Q.member(g, "Iron", (p0[0], p0[1], z0 - 0.55), (p1[0], p1[1], z0 + 4.0 - 0.55), 0.35, 1.1)
        for j in range(1, 4):
            ua, ub = -SI + (j - 1) * 2.4, -SI + j * 2.4
            top = z0 + j
            box_uv(g, "Iron", s, ua, ub, SI + 0.35, SO - 0.35, top - 0.3, top)
            box_uv(g, "Brass", s, ua - 0.05, ua + 0.3, SI + 0.45, SO - 0.45, top - 0.05, top + 0.03)       # 놋쇠 코
            box_uv(g, "Iron", s, ua, ua + 0.15, SI + 0.35, SO - 0.35, top - 1.0, top - 0.3)
            a, b = R(s, ua, SI), R(s, ub, SO)
            cbox(min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1]), top - 1.0, top)
        box_uv(g, "Iron", s, SI - 0.15, SI, SI + 0.35, SO - 0.35, z0 + 3.0, z0 + 3.7)
        # 바깥 비스듬 난간(계단 기둥 ↔ 계단 기둥)
        p0, p1 = R(s, -COL_U + 0.25, SO - 0.15), R(s, COL_U - 0.25, SO - 0.15)
        Q.rail_slope(g, (p0[0], p0[1], z0 + 0.3), (p1[0], p1[1], z0 + 3.7), h=3.4)


# ================================================================== 4. 승강장 · 차양 · 다리
def platform(g):
    z0 = HP - 0.3
    # 무늬판 바닥(계단 구멍 · 승강로 빼고) + 충돌
    pieces = [(PX0, PX1, SP + 0.3, PY1), (SP + 0.3, PX1, PY0, SP + 0.3), (PX0, -SI, 1.2, SP + 0.3),
              (PX0, -SO, PY0, 1.2), (-SO, SP + 0.3, PY0, -SO)]
    for x0, x1, y0, y1 in pieces:
        bx(g, "IronLight", x0, x1, y0, y1, z0, HP)
        cbox(x0, x1, y0, y1, HP - 1.0, HP)
    # 바닥 틀: 둘레 테 보 · 탑 밖 내민 장선 · 까치발(다리 · 가운데 기둥에서)
    zt = GIRD[-1][1]
    for x0, x1, y0, y1 in ((PX0, PX1, PY0, PY0 + 0.5), (PX0, PX1, PY1 - 0.5, PY1), (PX0, PX0 + 0.5, PY0, PY1), (PX1 - 0.5, PX1, PY0, PY1)):
        bx(g, "Iron", x0, x1, y0, y1, zt, z0)
    for x in (-14.0, 14.0):
        bx(g, "Iron", x - 0.3, x + 0.3, PY0, PY1, zt, z0)
    for y in (-14.0, 12.5):
        bx(g, "Iron", PX0, PX1, y - 0.3, y + 0.3, zt, z0)
    for s in (-1, 1):
        for u in (-LEG, 0.0, LEG):
            e = PY1 if s > 0 else PY0
            A.lattice_leg(g, (u, s * (LEG + 0.3), zt - 7.0), (u, e - s * 0.6, zt - 0.1), s=0.5)
            e = PX1 if s > 0 else PX0
            A.lattice_leg(g, (s * (LEG + 0.3), u, zt - 7.0), (e - s * 0.6, u, zt - 0.1), s=0.5)
    # 차양: 둘레 기둥 → 잘린 모임지붕(물매 20, 처마 0.4) + 머리 둘레 덮개 판
    A_, B_ = (PX1 - PX0) / 2, (PY1 - PY0) / 2
    cx, cy = (PX0 + PX1) / 2, (PY0 + PY1) / 2
    zp = HP + 10.0
    posts = []
    for x in (-17.6, -8.7, cx, 9.2, 18.0):
        posts += [(x, -17.6), (x, 15.6)]
    for y in (-8.5, 0.0, 8.0):
        posts += [(-17.6, y), (18.0, y)]
    for x, y in posts:
        bx(g, "Iron", x - 0.4, x + 0.4, y - 0.4, y + 0.4, HP, zp)
        bx(g, "Brass", x - 0.5, x + 0.5, y - 0.5, y + 0.5, HP, HP + 0.35)
        cbox(x - 0.4, x + 0.4, y - 0.4, y + 0.4, HP, zp)
    cut, eave = 13.0, 0.4
    zb, zbf = LB.hip_roof(g, A_, B_, zp, 20.0, eave=eave, cut=cut, cx=cx, cy=cy, snow=False)
    hx0, hx1, hy0, hy1 = cx - (A_ - cut), cx + (A_ - cut), cy - (B_ - cut), cy + (B_ - cut)
    bx(g, "RoofMetal", hx0, hx1, hy0, hy1, zb, zb + 0.45)                 # 잘린 단 덮개(2판: 머리 트러스는 비탈을 뚫어 단 가운데는 막힘)
    bx(g, "SnowCap", hx0 + 0.1, hx1 - 0.1, hy0 + 0.1, hy1 - 0.1, zb + 0.45, zb + 0.9)
    zsurf = roof_dress(g, A_, B_, cx, cy, cut, eave, zbf)
    # 둘레 난간(기둥 사이 — 다리 들머리 9.2..18.0 은 트임)
    xs = (-17.6, -8.7, cx, 9.2, 18.0)
    for a, b in zip(xs, xs[1:]):
        A.rail_between(g, "x", -17.6, a + 0.4, b - 0.4, HP, h=3.4, gap=1.0, mat="Rail")
        if a < 9.0:
            A.rail_between(g, "x", 15.6, a + 0.4, b - 0.4, HP, h=3.4, gap=1.0, mat="Rail")
    ys = (-17.6, -8.5, 0.0, 8.0, 15.6)
    for a, b in zip(ys, ys[1:]):
        for x in (-17.6, 18.0):
            A.rail_between(g, "y", x, a + 0.4, b - 0.4, HP, h=3.4, gap=1.0, mat="Rail")
    # 계단 구멍 둘레 난간(기둥 + 기둥 사이) — 동쪽 끝은 계단이 올라오는 곳(트임)
    hp = [(SI - 0.3, -SO - 0.3), (-SO - 0.3, 1.5), (-SI - 0.3, 1.5), (-3.0 - 0.3, -SO - 0.3)]       # 북서 모(-9.9, -9.9)는 머리 트러스 다리가 기둥(2026-11-27)
    for x, y in hp:
        bx(g, "Iron", x - 0.3, x + 0.3, y - 0.3, y + 0.3, HP, HP + 3.8)
        cbox(x - 0.3, x + 0.3, y - 0.3, y + 0.3, HP, HP + 3.8)
    A.rail_between(g, "x", -SO - 0.3, -SO, -3.6, HP, h=3.4, gap=1.0, mat="Rail")
    A.rail_between(g, "x", -SO - 0.3, -3.0, SI - 0.6, HP, h=3.4, gap=1.0, mat="Rail")
    A.rail_between(g, "y", -SO - 0.3, -SO, 1.2, HP, h=3.4, gap=1.0, mat="Rail")
    A.rail_between(g, "x", 1.5, -SO, -SI - 0.6, HP, h=3.4, gap=1.0, mat="Rail")
    # 등(차양 처마도리에 매단 등 넷) · 비행선 간판(다리 들머리 기둥)
    for x, y in ((cx, -16.6), (-16.6, 0.0), (17.0, -8.5), (-8.7, 14.6)):
        K.lantern(g, x, y, zp, zp - 2.2)
    K.hang_sign(g, 18.0 - 0.4, 15.6, zp - 1.4, along="x", icon=A.airship_icon, arm=4.2, board=(3.6, 2.4), face_sign=-1)
    return zsurf


def roof_dress(g, A_, B_, cx, cy, cut, e, zbf):
    """차양 지붕(2026-11-27 비평 비행선_1차 5번: 넓은 연회색 민짜 판 → 본부 지붕처럼): 눈은 처마 띠(2.0)만 · 위는 쇠 덮개가 보이고
    판 줄눈(서 있는 이음, 2.4 간격 — 처마에서 추녀·잘린 단까지) · 추녀마루와 잘린 단 테에 띠돌 덮개(0.6). 겉면 높이 함수를 돌려준다"""
    cp = math.cos(math.radians(20.0))
    top = (0.9 + 0.75) / cp                     # 서까래 밑 → 덮개 윗면(lib_b.hip_roof 의 층: 개판 0.35 + 덮개 0.4)

    def ii(x, y):
        return min(A_ - abs(x - cx), B_ - abs(y - cy), cut)

    def zsurf(x, y):
        return zbf(ii(x, y)) + top

    def zf(x, y):
        return zbf(ii(x, y)) + 0.9 / cp
    w = 2.0
    bands = [[(cx - A_ - e, cy - B_ - e), (cx + A_ + e, cy - B_ - e), (cx + A_ - w, cy - B_ + w), (cx - A_ + w, cy - B_ + w)],
             [(cx + A_ + e, cy + B_ + e), (cx - A_ - e, cy + B_ + e), (cx - A_ + w, cy + B_ - w), (cx + A_ - w, cy + B_ - w)],
             [(cx + A_ + e, cy - B_ - e), (cx + A_ + e, cy + B_ + e), (cx + A_ - w, cy + B_ - w), (cx + A_ - w, cy - B_ + w)],
             [(cx - A_ - e, cy + B_ + e), (cx - A_ - e, cy - B_ - e), (cx - A_ + w, cy - B_ + w), (cx - A_ + w, cy + B_ - w)]]
    for pts in bands:
        LB.plane_slab(g, "SnowCap", pts, zf, 0.75 / cp, K.SNOW_T / cp)
    i0 = w + 0.15
    for s in (-1, 1):
        u = cx - A_ + 1.2
        while u < cx + A_ - 1.0:                    # ±y 면(처마 = x 를 따라): x = u 줄
            im = min(cut, A_ - abs(u - cx)) - 0.3
            if im - i0 > 0.8:
                p0, p1 = (u, cy + s * (B_ - i0), 0.0), (u, cy + s * (B_ - im), 0.0)
                Q.member(g, "Rail", (p0[0], p0[1], zsurf(*p0[:2]) + 0.06), (p1[0], p1[1], zsurf(*p1[:2]) + 0.06), 0.22, 0.22)
            u += 2.4
        u = cy - B_ + 1.2
        while u < cy + B_ - 1.0:                    # ±x 면: y = u 줄
            im = min(cut, B_ - abs(u - cy)) - 0.3
            if im - i0 > 0.8:
                p0, p1 = (cx + s * (A_ - i0), u, 0.0), (cx + s * (A_ - im), u, 0.0)
                Q.member(g, "Rail", (p0[0], p0[1], zsurf(*p0[:2]) + 0.06), (p1[0], p1[1], zsurf(*p1[:2]) + 0.06), 0.22, 0.22)
            u += 2.4
    for sx in (-1, 1):                              # 추녀마루 띠돌
        for sy in (-1, 1):
            a = (cx + sx * (A_ + e), cy + sy * (B_ + e))
            b = (cx + sx * (A_ - cut), cy + sy * (B_ - cut))
            Q.member(g, "StoneTrim", (a[0], a[1], zbf(-e) + top + 0.12), (b[0], b[1], zbf(cut) + top + 0.12), 0.6, 0.45)
    zr = zbf(cut) + top                             # 잘린 단 테
    hx0, hx1, hy0, hy1 = cx - (A_ - cut), cx + (A_ - cut), cy - (B_ - cut), cy + (B_ - cut)
    for y in (hy0, hy1):
        bx(g, "StoneTrim", hx0 - 0.3, hx1 + 0.3, y - 0.3, y + 0.3, zr - 0.3, zr + 0.3)
    for x in (hx0, hx1):
        bx(g, "StoneTrim", x - 0.3, x + 0.3, hy0 - 0.25, hy1 + 0.25, zr - 0.32, zr + 0.28)
    return zsurf


def gangway(g):
    """비행선 다리(2026-11-27 비평 비행선_1차 3번: 폭 8 → 10 · 민짜 회색 바닥 → 짙은 널 마루(엇갈린 이음, 널 틈으로 밑 쇠판이 보임) + 놋쇠 끝 띠):
    옆 보 둘 + 가로보 · 바깥 난간(x 20) · 등 기둥 · 탑 남면에서 비스듬한 버팀대 셋. 승강장 동쪽 끝(18.5)과 바깥 난간 사이는 짧은 난간으로 막음"""
    z0 = HP - 0.3
    zt = GIRD[-1][1] - 0.3
    y0 = PY1
    xo = GW_X1 + 0.3                                   # 바깥 난간 줄
    bx(g, "Iron", GW_X0, GW_X1 + 0.6, y0, GW_Y1, z0, HP - 0.12)
    cbox(GW_X0, GW_X1 + 0.6, y0, GW_Y1, HP - 1.0, HP)
    bx(g, "Iron", 8.9, GW_X0, y0, GW_IN_Y, z0, HP - 0.12)        # 들머리 안쪽 덧바닥(곤돌라 앞 모가 깎인 자리 — 난간이 길을 좁히지 않게)
    cbox(8.9, GW_X0, y0, GW_IN_Y, HP - 1.0, HP)
    # 널 마루(y 를 따라 뻗은 널 폭 1.0 · 틈 0.06 · 이음은 손 표로 엇갈림)
    cuts = (4.0, 9.5, 6.5, 12.0, 2.5, 8.0, 11.0, 5.0, 10.0, 3.5, 7.5)
    xs = [GW_X0 + k * (GW_X1 + 0.6 - GW_X0) / 10 for k in range(11)]
    strips = [(8.9, GW_X0, GW_IN_Y)] + [(a, b, GW_Y1) for a, b in zip(xs, xs[1:])]
    for k, (a, b, yb) in enumerate(strips):
        yc = y0 + cuts[k % len(cuts)]
        for p0, p1 in ((y0, min(yc, yb)), (min(yc, yb), yb)):
            if p1 - p0 > 0.2:
                bx(g, "DarkLog", a + 0.03, b - 0.03, p0 + 0.03, p1 - 0.03, HP - 0.14, HP)
    for x0, x1 in ((GW_X0, GW_X0 + 0.6), (GW_X1 - 0.2, GW_X1 + 0.6)):
        bx(g, "Iron", x0, x1, y0 - 0.5, GW_Y1, zt, z0)
    y = y0 + 1.5
    while y < GW_Y1:
        bx(g, "Iron", GW_X0 + 0.6, GW_X1 - 0.2, y - 0.25, y + 0.25, zt + 0.2, z0)
        y += 3.0
    bx(g, "Iron", GW_X0, GW_X1 + 0.6, GW_Y1 - 0.5, GW_Y1, zt, z0)
    # 버팀대(탑 남면 셋째 띠보에서 다리 끝 · 가운데로) + 끝 가로 X
    base = (LEG, LEG + 0.4, GIRD[2][1] - 0.4)
    for x, y in ((GW_X0 + 0.3, GW_Y1 - 0.3), (GW_X1 + 0.2, GW_Y1 - 0.3), (GW_X1 + 0.2, 24.0)):
        A.lattice_leg(g, base, (x, y, zt - 0.2), s=0.7)
    A.lattice_leg(g, (GW_X0 + 0.3, GW_Y1 - 0.3, zt - 0.2), (GW_X1 + 0.2, 24.0, zt - 0.2), s=0.4)
    bx(g, "IronLight", LEG - 0.9, LEG + 0.9, LEG + 0.3, LEG + 0.6, base[2] - 1.0, base[2] + 1.0)
    # 기둥: 바깥 줄(xo) + 끝 + 안쪽 들머리(곤돌라 앞 모가 깎여 틈이 넓은 16..22.3) + 승강장 모 잇는 기둥
    outer = [(xo, y0 + 0.3), (xo, 22.0), (xo, 28.0), (xo, GW_Y1 - 0.35)]
    inner = [(9.2, GW_IN_Y - 0.3)]
    endp = [(GW_X0 + 0.3, GW_Y1 - 0.35)]
    for x, y in outer + inner + endp:
        tall = (x, y) in ((xo, 22.0), (xo, GW_Y1 - 0.35))
        h = 6.6 if tall else 3.8
        bx(g, "Iron", x - 0.3, x + 0.3, y - 0.3, y + 0.3, HP, HP + h)
        cbox(x - 0.3, x + 0.3, y - 0.3, y + 0.3, HP, HP + h)
        if tall:
            K.lantern(g, x, y, HP + h + 1.9, HP + h + 0.75)
            bx(g, "Iron", x - 0.45, x + 0.45, y - 0.45, y + 0.45, HP + h, HP + h + 0.25)
    A.rail_between(g, "x", y0 + 0.3, 18.0 + 0.4, xo - 0.3, HP, h=3.4, gap=1.0, mat="Rail")     # 승강장 동쪽 모(18.0) ↔ 다리 바깥 난간
    ys = [p[1] for p in outer]
    for a, b in zip(ys, ys[1:]):
        A.rail_between(g, "y", xo, a + 0.3, b - 0.3, HP, h=3.4, gap=1.0, mat="Rail")
    A.rail_between(g, "y", 9.2, 16.0, GW_IN_Y - 0.6, HP, h=3.4, gap=1.0, mat="Rail")
    A.rail_between(g, "x", GW_Y1 - 0.35, GW_X0 + 0.6, xo - 0.3, HP, h=3.4, gap=1.0, mat="Rail")
    # 다리 바닥 놋쇠 끝 띠(곤돌라 쪽 가장자리 — 틈 0.7 표시)
    bx(g, "Brass", GW_X0, GW_X0 + 0.3, GW_IN_Y, GW_Y1, HP - 0.02, HP + 0.05)


# ================================================================== 5. 계류 머리(사각 트러스 · 도는 원통 머리 · 계류 팔) · 승강기 위 칸 · 기계 바닥
MDECK = 58.4                     # 기계 바닥(그 밑은 곧은 칸 — 승강기 칸이 선다)
HLV = (59.0, 67.0, 72.5, HEAD_TOP)   # 머리 트러스 띠보 높이(59 = 차양 지붕 밑 · 67 위로 가새)


def head_hw(z):
    """머리 트러스 다리 가운데 반폭(z): 몸통 다리 머리(GIRD 맨 위, LEG) → 꼭대기 HEAD_TOP 에서 HW_TOP"""
    zt = GIRD[-1][1]
    return LEG + (HW_TOP - LEG) * (max(z, zt) - zt) / (HEAD_TOP - zt)


def _roof_cross(sx, sy, zsurf):
    """다리(sx, sy)가 차양 지붕 겉면을 지나는 높이 — zsurf(x, y) 와 다리 높이가 같아지는 곳(반으로 나눠 찾기)"""
    lo, hi = HP, HEAD_TOP
    for _ in range(40):
        z = (lo + hi) / 2
        w = head_hw(z)
        if z < zsurf(sx * w, sy * w):
            lo = z
        else:
            hi = z
    return (lo + hi) / 2


def head(g, zsurf=None):
    """2026-11-27 비평 비행선_1차 1번(배를 붙잡는 머리가 가는 기둥 하나 → 안테나·쇠꼬챙이로 읽힘): 몸통 다리 넷을 승강장 · 차양 지붕을 뚫고 올려
    폭 21.7 → 12(꼭대기 77)로 좁힌 사각 트러스 + 띠보 넷 + 지붕 위 두 칸 ʌ 가새 · 지붕 뚫는 자리 쇠 깃 →
    꼭대기 판 · 도는 고리(놋쇠 톱니 테 + 굴림 바퀴 여덟) · 원통 머리(지름 5 · 높이 6, 놋쇠 띠) · 위 갓 · 붉은 경고등 ·
    남쪽 계류 팔(굵은 상자 보) + 꼭대기 판 앞 모에서 받치는 팔 둘 + 머리 위에서 당기는 보 → 컵(입 = Q.CUP_Y · Q.CUP_Z 그대로).
    가운데 승강기 위 칸(HP..MDECK 쇠살 · 동쪽 트임)과 기계 바닥(감개 북 · 실린더 · 보일러)은 그대로"""
    zt = GIRD[-1][1]
    # 승강기 위 칸 기둥(승강로 기둥 그대로 HP → MDECK) + 기계 바닥 테 보
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, "Iron", sx * SP - SPS / 2, sx * SP + SPS / 2, sy * SP - SPS / 2, sy * SP + SPS / 2, HP, MDECK)
    for s in (-1, 1):
        bx(g, "Iron", -SP, SP, s * SP - 0.22, s * SP + 0.22, MDECK - 0.45, MDECK)
        bx(g, "Iron", s * SP - 0.22, s * SP + 0.22, -SP + 0.25, SP - 0.25, MDECK - 0.45, MDECK - 0.02)
    # 머리 트러스 다리(몸통 다리 머리 → 꼭대기) + 승강장 안 충돌 + 지붕 깃
    for sx in (-1, 1):
        for sy in (-1, 1):
            A.lattice_leg(g, (sx * LEG, sy * LEG, zt - 0.3), (sx * HW_TOP, sy * HW_TOP, HEAD_TOP + 0.2), s=1.1)
            for z0, z1 in ((HP, HP + 4.5), (HP + 4.5, HP + 9.0)):
                w = head_hw((z0 + z1) / 2)
                cbox(sx * w - 0.6, sx * w + 0.6, sy * w - 0.6, sy * w + 0.6, z0, z1)
            if zsurf:
                zc = _roof_cross(sx, sy, zsurf)
                w = head_hw(zc)
                bx(g, "Iron", sx * w - 0.95, sx * w + 0.95, sy * w - 0.95, sy * w + 0.95, zc - 0.7, zc + 0.45)
                bx(g, "Brass", sx * w - 1.05, sx * w + 1.05, sy * w - 1.05, sy * w + 1.05, zc + 0.45, zc + 0.7)
    for k, z in enumerate(HLV):
        w = head_hw(z)
        th = 0.7 if k == len(HLV) - 1 else 0.5
        for s in (-1, 1):
            bx(g, "Iron", -w + 0.25, w - 0.25, s * w - 0.3, s * w + 0.3, z - th, z)
            bx(g, "Iron", s * w - 0.3, s * w + 0.3, -w, w, z - th - 0.05, z + 0.01)
    for za, zb in zip(HLV[1:], HLV[2:]):
        wa, wb = head_hw(za), head_hw(zb)
        for face in range(4):
            sg = -1 if face in (0, 2) else 1
            for e in (-1, 1):
                p0, p1 = (e * (wa - 0.7), sg * wa, za + 0.1), (e * 0.4, sg * wb, zb - 0.6)
                if face >= 2:
                    p0, p1 = (p0[1], p0[0], p0[2]), (p1[1], p1[0], p1[2])
                A.lattice_leg(g, p0, p1, s=0.5, mat="Rail")
    # 기계 바닥(58.4): 무늬판 · 감개 북(쇠 + 감긴 줄 띠) · 증기 실린더 둘 · 톱니 · 작은 구리 보일러 · 압력계 · 북에서 칸으로 내리는 줄
    # 아래 칸(승강기 칸이 서는 곳) 쇠살 — 북 · 서 · 남. 동쪽은 타는 곳(놋쇠 머리보)
    for face, (ax, sgn) in enumerate((("x", -1), ("x", 1), ("y", -1))):
        for k in range(-2, 3):
            K.wbox(g, "Rail", ax, sgn * SP, 0.2, k * 1.15 - 0.1, k * 1.15 + 0.1, HP, MDECK - 0.45)
        w = SP
        if ax == "x":
            bx(g, "Rail", -w, w, sgn * w - 0.12, sgn * w + 0.12, HP + 3.9, HP + 4.15)
            cbox(-SP, SP, sgn * SP - 0.3, sgn * SP + 0.3, HP, 57.6)
        else:
            bx(g, "Rail", sgn * w - 0.12, sgn * w + 0.12, -w, w, HP + 3.9, HP + 4.15)
            cbox(sgn * SP - 0.3, sgn * SP + 0.3, -SP, SP, HP, 57.6)
    w = SP
    bx(g, "Brass", w - 0.1, w + 0.35, -w, w, 57.5, 58.0)
    g["Brass"].hcyl(w + 0.45, 0.0, 56.9, 0.6, 0.2, axis="x", seg=12)
    g["Dial"].hcyl(w + 0.58, 0.0, 56.9, 0.47, 0.06, axis="x", seg=12)
    w = SP - 0.2
    bx(g, "IronLight", -w, w, -w, w, 58.4, 58.7)
    for s in (-1, 1):
        bx(g, "IronLight", s * 1.6 - 0.3, s * 1.6 + 0.3, -0.5, 0.5, 58.7, 59.6)
    g["Iron"].hcyl(0.0, 0.0, 60.1, 0.75, 2.6, axis="x", seg=12)
    for k in (-0.75, 0.0, 0.75):
        g["CanvasDark"].hcyl(k, 0.0, 60.1, 0.85, 0.6, axis="x", seg=12)
    K.S.gear(g, "Brass", 1.55, 0.0, 60.1, 1.05, 16, 0.28, axis="x")
    for s in (-1, 1):
        g["Copper"].hcyl(-1.2, s * 1.3, 59.6, 0.42, 1.6, axis="y", seg=10)
        bx(g, "Iron", -1.7, -0.7, s * 1.3 - 0.9, s * 1.3 + 0.9, 58.7, 59.15)
    g["Copper"].cyl(1.2, -1.4, 58.7, 0.55, 0.55, 2.0, seg=10)
    g["Brass"].cyl(1.2, -1.4, 60.7, 0.62, 0.4, 0.35, seg=10)
    Q.gauge(g, 1.2, -1.95, 59.9, face_y=-1, r=0.32)
    A.lattice_leg(g, (0.0, -0.75, 59.4), (0.0, -0.75, 58.1), s=0.3, mat="Iron")
    # 꼭대기 판 · 도는 고리(놋쇠 톱니 테 + 굴림 바퀴) · 원통 머리 · 위 갓 · 쇠 바늘 · 붉은 경고등
    zd = HEAD_TOP + 0.35
    bx(g, "IronLight", -HW_TOP - 0.5, HW_TOP + 0.5, -HW_TOP - 0.5, HW_TOP + 0.5, HEAD_TOP - 0.05, zd)
    K.S.gear(g, "Brass", 0.0, 0.0, zd, 4.0, 28, 0.45, axis="z")                 # 톱니 테(판 위 0.225)
    for k in range(8):                                                           # 굴림 바퀴(고리 밑)
        a = 2 * math.pi * (k + 0.5) / 8
        g["Iron"].hcyl(3.15 * math.cos(a), 3.15 * math.sin(a), zd + 0.5, 0.24, 0.6, axis="x", seg=8, rz=a)
    K.S.ring(g, "Iron", 0.0, 0.0, zd + 0.78, 2.6, 3.7, 0.5, n=24)                 # 도는 고리
    K.S.banded_cyl(g, "Iron", 0.0, 0.0, zd + 0.2, TUR_R, 6.0, band="Brass", every=1.5, seg=16, cap=None)
    zh = zd + 6.2
    g["Brass"].cyl(0.0, 0.0, zh, TUR_R + 0.4, 1.6, 0.9, seg=16)
    g["Iron"].cyl(0.0, 0.0, zh + 0.9, 0.5, 0.35, 1.2, seg=8)
    g["Iron"].cyl(0.0, 0.0, zh + 2.1, 0.8, 0.8, 0.25, seg=10)
    g["Core"].cyl(0.0, 0.0, zh + 2.35, 0.55, 0.45, 0.7, seg=10)
    g["Brass"].cyl(0.0, 0.0, zh + 3.05, 0.6, 0.2, 0.3, seg=10)
    g["LampPt"].box(0.0, 0.0, zh + 2.7, 0.3, 0.3, 0.3)
    # 계류 팔(남쪽 굵은 상자 보) + 받치는 팔 둘(꼭대기 판 앞 모 → 팔 끝) + 당기는 보(원통 위 → 팔 끝) · 컵
    zc = Q.CUP_Z
    ye = Q.CUP_Y - 1.3
    bx(g, "Iron", -0.65, 0.65, TUR_R - 0.3, ye, zc - 0.65, zc + 0.65)
    bx(g, "IronLight", -0.85, 0.85, ye - 0.4, ye, zc - 0.85, zc + 0.85)
    for e in (-1, 1):
        A.lattice_leg(g, (e * 3.6, HW_TOP + 0.2, zd + 0.1), (e * 0.55, ye - 0.3, zc - 0.55), s=0.6)
        bx(g, "Brass", e * 3.6 - 0.5, e * 3.6 + 0.5, HW_TOP - 0.3, HW_TOP + 0.5, zd, zd + 0.3)
    A.lattice_leg(g, (0.0, TUR_R - 0.4, zd + 6.6), (0.0, ye - 0.3, zc + 0.55), s=0.5)
    _cup(g, Q.CUP_Y, zc)


def _cup(g, y_mouth, zc):
    """계류 컵: +y 로 벌어진 놋쇠 나팔(입 반지름 1.5) + 쇠 목 테"""
    import bmesh
    from mathutils import Matrix
    m = Matrix.Translation((0.0, y_mouth - 0.6, zc)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    bmesh.ops.create_cone(g["Brass"].bm, cap_ends=True, cap_tris=False, segments=14, radius1=0.6, radius2=1.5, depth=1.2, matrix=m)
    g["Iron"].hcyl(0.0, y_mouth - 1.25, zc, 0.8, 0.3, axis="y", seg=12)


# ================================================================== 6. 1층 안살림
def ground_props(g):
    # 승강기 손잡이 받침(놋쇠 기둥 · 큰 지레 · 계기)
    x, y = -4.6, -5.0
    bx(g, "DarkLog", x - 0.6, x + 0.6, y - 0.6, y + 0.6, F0, F0 + 0.3)
    g["Brass"].cyl(x, y, F0 + 0.3, 0.35, 0.3, 3.0, seg=8)
    g["Iron"].hcyl(x, y, F0 + 3.6, 0.6, 0.6, axis="x", seg=12)
    g["Dial"].hcyl(x + 0.33, y, F0 + 3.6, 0.5, 0.06, axis="x", seg=12)
    Q.member(g, "Brass", (x, y, F0 + 3.3), (x, y - 0.7, F0 + 4.6), 0.18, 0.18)
    g["SignRed"].box(x, y - 0.75, F0 + 4.7, 0.36, 0.36, 0.36)
    cbox(x - 0.6, x + 0.6, y - 0.6, y + 0.6, F0, F0 + 4.4)
    # 기다리는 걸상(북서, 서쪽 벽 · 동쪽을 봄) + 매단 등(북서 쉼참 밑)
    N.put(g, -8.6, -6.6, F0, -math.pi / 2, N.bench, 4.4)
    cbox(-9.3, -7.9, -8.8, -4.4, F0, F0 + 1.75)
    K.lantern(g, -6.6, -6.6, F0 + 11.0, F0 + 8.6)
    # 서쪽: 손수레 위 궤짝 · 쌓은 상자 · 통(짐 — 2팀이 둔 화물 자리를 이음)
    N.put(g, -6.6, -0.2, F0, math.pi / 2, N.cart, 2.6, 1.6, 2.6, "Brass", "Wood")
    N.put(g, -6.6, -0.2, F0 + 2.6, math.pi / 2, N.trunk, 2.0, 1.2, 1.2)
    cbox(-7.6, -5.6, -1.6, 1.2, F0, F0 + 4.4)
    N.put(g, -7.3, 6.8, F0, 0.0, N.pallet, 2.6, 2.0)
    N.put(g, -7.3, 6.7, F0 + 0.45, 0.0, N.crate, 2.2, 1.9, 1.9)
    N.put(g, -5.0, 7.3, F0, 0.4, N.barrel, 0.85, 2.3)
    cbox(-8.6, -4.1, 5.6, 8.4, F0, F0 + 2.4)
    # 남쪽(남 계단 밑): 감은 밧줄 · 상자
    K.S.ring(g, "CanvasDark", 1.5, 7.4, F0, 0.25, 0.85, 0.32, n=12)
    K.S.ring(g, "CanvasDark", 1.5, 7.4, F0 + 0.32, 0.3, 0.8, 0.3, n=12)
    N.put(g, -1.6, 7.6, F0, 0.2, N.crate, 1.8, 1.6, 1.5)
    cbox(-2.5, -0.7, 6.7, 8.5, F0, F0 + 1.5)


def build(g):
    frame(g)
    splay(g)
    ground_walls(g)
    shaft(g)
    stairs(g)
    zsurf = platform(g)
    gangway(g)
    head(g, zsurf)
    ground_props(g)


INFO = {
    "variant": VARIANT,
    "floor": F0,
    "deck": HP,
    "moor": (0.0, Q.SHIP_Y, HP),                  # 비행선 원점 자리(블렌더, 돌림 없음)
    "cup": (0.0, Q.CUP_Y, Q.CUP_Z),
    "gangway_end": ((GW_X0 + GW_X1) / 2, GW_Y1, HP),
    "lift": (LIFT_BOTTOM, LIFT_TOP),
}
