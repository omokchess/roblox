# -*- coding: utf-8 -*-
"""
b_mast.py — 2026-11-14. 설원 마을 3판: 비행선 계류탑(발자국 10×10, 높이 약 46). 아트 부서원 1. 티켓 판매점(b_ticket.py)과 짝.
비행선 자체는 옛 키트 Airship 을 Studio 에서 붙인다 — 붙일 자리는 INFO["moor"](탑 머리 앞 계류 컵 끝, 블렌더 좌표).

레퍼런스(회사/설원마을_레퍼런스.md K): 카딩턴 계류탑 + R-100(K4 — 높은 쇠 격자탑, 꼭대기 원통 머리에 코를 묶음),
USS 애크런 계류탑(K5 — 아래로 벌어진 네 다리 격자 + 꼭대기 좁은 단·원뿔 머리), 굿이어 이동식 계류탑(K6 — 기둥·가로대·가새, 아래 작은 기계실),
보일러실(ST1·ST3 — 돌 받침 위 기계, 굵은 테 관).

짜임(실제 공사처럼): 돌 기초 넷 → 다리 넷(기초에서 꼭대기까지 한 덩이로 비스듬히 좁아짐) → 층마다 가로대(다리와 다리 사이) → 칸마다 X 가새
 → 꼭대기 가로대 위 쇠 바닥 + 난간(구석 짧은 기둥 사이에만) → 바닥 위 원통 머리 + 도는 갓 + 앞 계류 컵.
아래: 돌 받침 위 증기 통(압력계) → 관 → 윈치 북(돌 뺨 둘) → 줄이 탑 가운데로 머리까지. 사다리는 탑 안 가운데 뒤쪽(바닥 → 꼭대기 바닥 구멍).
"""
import math

import lib as K
import lib_a as A
from lib import bx, cbox

NAME = "Sn3_Mast"
PREFIX = "Sn3Mast"
VARIANT = "A"

B, TOPW = 4.0, 1.6           # 다리 중심: 땅(기초 위) ±4.0 → 꼭대기 ±1.6
Z0, ZT = 1.0, 40.0           # 기초 윗면 · 꼭대기 바닥 밑
LEVELS = (7.0, 13.5, 20.0, 26.5, 33.0, ZT)
HEAD_R, HEAD_H = 1.25, 3.4
MOOR = (0.0, -(TOPW + 0.9 + 1.4), ZT + 0.3 + HEAD_H + 0.5)     # 난간 밖·위로 내민 팔 끝 컵 앞(코가 닿는 점)


def leg_at(z):
    return B - (B - TOPW) * (z - Z0) / (ZT - Z0)


def tower(g):
    # 기초 넷(돌 + 띠돌)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, "Stone", sx * B - 0.8, sx * B + 0.8, sy * B - 0.8, sy * B + 0.8, 0.0, Z0 - 0.15)
            bx(g, "StoneTrim", sx * B - 0.9, sx * B + 0.9, sy * B - 0.9, sy * B + 0.9, Z0 - 0.15, Z0)
            cbox(sx * B - 0.9, sx * B + 0.9, sy * B - 0.9, sy * B + 0.9, 0.0, Z0)
            # 다리: 기초에서 꼭대기까지 한 덩이
            A.lattice_leg(g, (sx * B, sy * B, Z0), (sx * TOPW, sy * TOPW, ZT + 0.5), s=0.8)
            for z in (Z0 + 0.3, ZT + 0.2):                       # 다리 밑 받침판·머리판(볼트 판)
                p = leg_at(z)
                bx(g, "IronLight", sx * p - 0.6, sx * p + 0.6, sy * p - 0.6, sy * p + 0.6, z - 0.3, z)
            # 걸리는 상자(아래 몸만 — 위는 손이 닿지 않음)
            p = leg_at(7.0)
            cbox(min(sx * B, sx * p) - 0.4, max(sx * B, sx * p) + 0.4, min(sy * B, sy * p) - 0.4, max(sy * B, sy * p) + 0.4, Z0, 7.0)
    # 층 가로대(네 면) + 칸마다 X 가새
    prev = Z0 + 0.5
    for z in LEVELS:
        p = leg_at(z)
        for s in (-1, 1):
            bx(g, "Iron", -p, p, s * p - 0.25, s * p + 0.25, z - 0.5, z)
            bx(g, "Iron", s * p - 0.25, s * p + 0.25, -p, p, z - 0.5, z)
        q = leg_at(prev)
        for s in (-1, 1):
            for d in (-1, 1):
                A.lattice_leg(g, (d * q, s * q, prev), (-d * p, s * p, z - 0.5), s=0.3)
                A.lattice_leg(g, (s * q, d * q, prev), (s * p, -d * p, z - 0.5), s=0.3)
        prev = z


def top(g):
    """꼭대기: 가로대 위 쇠 바닥(0.3, 사다리 구멍) · 구석 짧은 기둥 + 그 사이 난간 · 원통 머리 · 도는 갓 · 앞 계류 컵 · 경고등"""
    zf = ZT + 0.3
    w = TOPW + 0.9
    bx(g, "IronLight", -w, w, -w, 0.55, ZT, zf)
    bx(g, "IronLight", -w, -0.6, 0.55, w, ZT, zf)
    bx(g, "IronLight", 0.6, w, 0.55, w, ZT, zf)
    bx(g, "IronLight", -0.6, 0.6, 1.65, w, ZT, zf)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, "Iron", sx * w - 0.15, sx * w + 0.15, sy * w - 0.15, sy * w + 0.15, zf, zf + 3.0)
    for s in (-1, 1):
        A.rail_between(g, "x", s * w, -w + 0.15, w - 0.15, zf, h=3.0, gap=0.8, mat="Iron")
        A.rail_between(g, "y", s * w, -w + 0.15, w - 0.15, zf, h=3.0, gap=0.8, mat="Iron")
    # 원통 머리(놋쇠 띠) + 도는 갓 + 꼭대기 경고등
    K.S.banded_cyl(g, "Iron", 0.0, 0.0, zf, HEAD_R, HEAD_H, band="Brass", every=1.1)
    g["Brass"].cyl(0.0, 0.0, zf + HEAD_H, HEAD_R + 0.3, 0.35, 1.1, seg=16)
    g["Iron"].cyl(0.0, 0.0, zf + HEAD_H + 1.1, 0.2, 0.2, 0.8, seg=8)
    g["Core"].cyl(0.0, 0.0, zf + HEAD_H + 1.9, 0.32, 0.32, 0.45, seg=10)
    g["LampPt"].box(0.0, 0.0, zf + HEAD_H + 2.1, 0.3, 0.3, 0.3)
    # 앞 계류 컵(코를 받는 깔때기) + 받침 팔
    mx, my, mz = MOOR
    ya = my + 0.9                                    # 팔 끝(컵 뒤)
    g["Brass"].hcyl(0.0, (ya - 0.2) / 2, mz, 0.3, -ya - 0.2, axis="y", seg=10)       # 머리 갓 속 → 난간 밖으로 내민 팔
    A.lattice_leg(g, (0.0, -HEAD_R + 0.1, zf + 1.2), (0.0, ya + 0.2, mz - 0.25), s=0.3)  # 팔 밑 버팀(머리 몸 → 팔 끝)
    _cup(g, my, mz)
    # 사다리(탑 안 가운데 뒤 — 바닥에서 꼭대기 바닥 구멍까지)
    for x in (-0.5, 0.5):
        bx(g, "Iron", x - 0.08, x + 0.08, 1.02, 1.18, Z0, zf + 1.2)
    z = Z0 + 0.8
    while z < zf:
        bx(g, "Iron", -0.5, 0.5, 1.04, 1.16, z, z + 0.1)
        z += 1.0


def _cup(g, my, mz):
    """계류 컵: 앞(-y)으로 벌어진 놋쇠 깔때기(좁은 끝이 머리에 붙음)"""
    import bmesh
    from mathutils import Matrix
    m = Matrix.Translation((0, my + 0.45, mz)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    bmesh.ops.create_cone(g["Brass"].bm, cap_ends=True, cap_tris=False, segments=12, radius1=0.9, radius2=0.35, depth=0.9, matrix=m)


def winch(g):
    """아래 기계실: 돌 받침 · 증기 통(압력계) → 관 → 윈치 북(돌 뺨 둘) → 줄이 탑 가운데로 머리까지"""
    bx(g, "Stone", -2.6, 2.6, -2.6, 2.0, 0.0, 0.6)
    bx(g, "StoneTrim", -2.7, 2.7, -2.7, 2.1, 0.6, 0.75)
    cbox(-2.7, 2.7, -2.7, 2.1, 0.0, 0.75)
    # 윈치 북
    for x in (-0.3, 2.1):
        bx(g, "Stone", x - 0.3, x + 0.3, -1.6, -0.2, 0.75, 2.6)
    g["Iron"].hcyl(0.9, -0.9, 2.0, 0.85, 2.1, axis="x", seg=16)
    for x in (-0.05, 1.85):
        g["Brass"].hcyl(x, -0.9, 2.0, 1.05, 0.15, axis="x", seg=16)
    g["Iron"].hcyl(0.9, -0.9, 2.0, 0.15, 3.2, axis="x", seg=8)
    K.S.gear(g, "Brass", 2.55, -0.9, 2.0, 0.6, 12, 0.15, axis="x")
    cbox(-0.6, 2.4, -1.8, 0.0, 0.75, 3.0)
    # 줄: 북 위 → 탑 가운데 → 머리 밑
    g["Iron"].cyl(0.9, -0.9, 2.85, 0.07, 0.07, 1.0, seg=6)
    A.lattice_leg(g, (0.9, -0.9, 3.8), (0.0, 0.0, ZT), s=0.12, mat="Iron")
    # 증기 통 → 관 → 북 굴대
    tx, ty = -1.4, 0.8
    K.steam_bundle(g, tx, ty, 0.75, h=4.4, r=0.85, gauge_face=-1,
                   pipe_pts=[(tx + 0.85, ty, 3.6), (2.6, ty, 3.6), (2.6, -0.9, 3.6), (2.6, -0.9, 2.6)])


def build(g):
    tower(g)
    top(g)
    winch(g)
    for sx in (-1, 1):                 # 기초 둘레 눈 더미(바람 맞는 앞쪽만)
        bx(g, "SnowDrift", sx * B - 1.1, sx * B + 1.1, -B - 1.2, -B - 0.9, 0.0, 0.5)


INFO = {
    "variant": VARIANT,
    "floor": 0.0,
    "moor": MOOR,                      # 블렌더 (x, y, z) — 로블록스 로컬 = (-x, z, y)
    "extra_views": [
        ("ext_far", (-46, -78, 34), (0, 0, 22), 30, None),
        ("fp_under", (5.5, -10.0, 4.5), (0.0, 0.0, 40.0), 17, None),        # 1인칭 아래에서 올려다봄
        ("fp_base", (0.0, -11.0, 4.5), (0.0, 0.0, 4.0), 17, None),         # 1인칭 기계실
        ("top", (8.0, -14.0, 50.0), (0.0, 0.0, 42.0), 26, None),           # 머리·난간 가까이
    ],
}
