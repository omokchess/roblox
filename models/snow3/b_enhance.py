# -*- coding: utf-8 -*-
"""
b_enhance.py — 2026-11-14. 설원 마을 3판: 강화소(룬 새기기 — 정밀 공방). 아트 부서원 2, B 양식(돌 아랫벽 + 굵은 뼈대 + 세로 판벽).
2026-11-18 아트 2팀: 박공 꼭대기 띠·처마 막이판(틈 0 은 서까래 자리 운 — 막아 둠) · 김 하나(연통 비 갓 위, 바깥 증기 통 김은 처마 밑이라 뺌) ·
  내부 다시: 문 왼쪽 **청록 수정 받침 강화대 + 강화 모루(칼·망치) + 바닥 룬 고리** · 발판 숫돌(연마) · 판넬 카운터(짙은 돌 상판) ·
  뒤 작업대 위 바이스·광택 바퀴·연장 두루마리·보석 쟁반 · 오른 앞 원석 상자(레퍼런스 내부 2팀 EN: 보석 세공·연마 작업대)
2026-11-24 2팀 2차(비평 1차): 수정 받침·모루를 문 화면 가운데(기계 앞)로 · 카운터 = 짙은 돌 + 쇠판 리벳 + 바이스 · 왼 앞 원석 진열대 + 숫돌 ·
  오른 벽 연장 걸이판 + 원석 통 둘 · 룬 판 진열판은 창을 피해 앞으로 · 모루 = 그루터기 + 2단 뿔.

레퍼런스(회사/설원마을_레퍼런스.md R·C): 로샤이더 호프 시계공 작업대(R1 — 창 아래 긴 작업대 + 갓 등, 벽 진열판 하나),
금세공·시계 공방 집(R2/C11 — 가파른 지붕 + 뼈대 칸 나눔), 몰프제 시계공 집(R3/C10 — 낮은 벽 + 큰 지붕, 작은 창 여럿).
대장간(B)과 같은 벽·지붕 부품을 쓰되 돌 아랫벽을 낮게(3), 뒤·오른 벽에 창 줄, 지붕을 뚫고 솟은 구리 연통(룬 기계 열기)으로 멀리서 구별.

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  벽 가운데 선 x ±12.5 · y -11..11 → 안 23.8 × 20.8, 천장(평보 밑) 11. 앞 계단 폭 12
  정문 x -5.2..5.2 높이 10 → 오른쪽 카운터 겸 작업대 x 1..11 · y 3..5.5, 앞 빈 바닥 x 1..11 · y -7.15..2.85, NPC (6, 7.3)
  뒷벽 오른쪽: 창 줄 셋 아래 긴 작업대 + 갓 등 둘 / 오른 벽: 룬 판 진열판 / 왼 뒤: 룬 새기는 기계(돌 받침 · 쇠 몸 · 구리 통 · 놋쇠 톱니 바퀴 · 청록 룬 판 · 지붕 위로 나간 연통)
  바깥: 왼 앞 증기 통 → 관이 앞벽을 타고 올라가 벽 속으로 · 오른 벽 쇠 팔 룬 간판 · 앞 박공 큰 룬 판
"""
import math

from mathutils import Matrix

import lib as K
import lib_b as KB
import lib_int2 as N
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_H, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Enhance"
PREFIX = "Sn3Enhance"
VARIANT = "B"

WX, YF, YB = 12.5, -11.0, 11.0
T = LOG
HALF = WX + T / 2                        # 13.1
XI, YI0, YI1 = WX - T / 2, YF + T / 2, YB - T / 2       # 11.9, -10.4, 10.4
Z_PLATE = FZ + CEIL + 0.9
STONE_TO = FZ + 3.0                      # 대장간 4 보다 낮은 돌 아랫벽(가벼운 공방)
WIN_F = (-9.6, 9.6)
WIN_B = (2.0, 5.6, 9.2)                  # 창 줄(작업대 위)
RIB_SILL = FZ + 4.0
WIN_L = (-5.0,)
WIN_R = (-5.0, 5.0)
FLUE = (-9.95, -8.45, 6.75, 8.25)        # 연통 지붕 구멍 x0 x1 y0 y1
FX, FY = -9.2, 7.5                       # 연통 가운데
COUNTER = (1.0, 11.0, 3.0, 5.5)
FREE = (1.0, 11.0, -7.15, 2.85)
FL = FZ + 0.08                           # 널 마루 윗면
ALTAR = (-3.4, 0.6)                      # 청록 수정 받침(문 축 왼쪽, 룬 기계 앞 — 문 화면 가운데 1/3)


def walls(g, R):
    hole = lambda u, z0=FZ + WIN_SILL: (u - WIN_W / 2, u + WIN_W / 2, z0, z0 + WIN_H)     # noqa: E731
    door = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    plan = (("x", YF, [door] + [hole(u) for u in WIN_F], -1),
            ("x", YB, [hole(u, RIB_SILL) for u in WIN_B], 1),
            ("y", -WX, [hole(u) for u in WIN_L], -1),
            ("y", WX, [hole(u) for u in WIN_R], 1))
    for ax, c, holes, face in plan:
        u0, u1 = (-WX, WX) if ax == "x" else (YF, YB)
        K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=STONE_TO, face=face)
    for u in WIN_F:
        K.window(g, "x", YF, u, FZ + WIN_SILL, face=-1)
    for u in WIN_B:
        K.window(g, "x", YB, u, RIB_SILL, face=1, shutters=False)    # 창 줄은 덧창 없이(창 사이가 좁다)
    for u in WIN_L:
        K.window(g, "y", -WX, u, FZ + WIN_SILL, face=-1)
    for u in WIN_R:
        K.window(g, "y", WX, u, FZ + WIN_SILL, face=1)
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    for c, face in ((YF, -1), (YB, 1)):
        K.gable_boards(g, "x", c, HALF, Z_PLATE, top, face=face)
        N.gable_seal(g, "x", c, R, mat="Timber")              # (2팀) 박공 꼭대기 띠
    N.eave_block(g, R, YF, YB)                                # (2팀) 처마 막이판(서까래 사이)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)


def gable_sign(g):
    """앞 박공 큰 룬 판: 둥근 나무 판(놋쇠 테) + 룬 그림 두 배 — 머리보 위 박공 판에 박음"""
    y = YF - T / 2
    zc = Z_PLATE + 3.2
    g["Brass"].hcyl(0, y - 0.15, zc, 2.6, 0.3, axis="y", seg=24)
    g["Timber"].hcyl(0, y - 0.3, zc, 2.3, 0.3, axis="y", seg=24)
    K.L.transformed(g, Matrix.Translation((0, y - 0.45, zc - 1.9)) @ Matrix.Scale(1.9, 4),
                    lambda gg: K.SVC.rune_icon(gg, 0, 0, 0, face=-1))


def side_sign(g):
    """오른 벽 앞쪽 쇠 팔 간판(룬 그림 양면) — 길에서 옆으로 읽힌다"""
    K.hang_sign(g, HALF, -8.6, FZ + 8.8, along="x",
                icon=lambda g_, x, y, z, f: K.SVC.rune_icon(g_, x, y, z - 0.15, face=f))


def machine(g, R):
    """룬 새기는 기계(왼 뒤 구석, 큰 덩어리 하나): 돌 받침 → 쇠 몸(놋쇠 띠) → 구리 열기 통 → 연통(지붕 위로) ·
    방 쪽(+x) 면에 놋쇠 톱니 바퀴 + 청록 룬 판, 앞 받침대에 새기는 중인 칼, 놋쇠 관 둘"""
    x0, x1, y0, y1 = -11.6, -5.2, 2.6, 10.2
    bx(g, "Stone", x0, x1, y0, y1, FZ, FZ + 0.9)
    bx(g, "StoneTrim", x0 - 0.1, x1 + 0.1, y0 - 0.1, y1 + 0.1, FZ + 0.9, FZ + 1.1)
    hx0, hx1, hy0, hy1 = -11.2, -6.2, 3.2, 9.6
    bx(g, "Iron", hx0, hx1, hy0, hy1, FZ + 1.1, FZ + 5.0)
    for z in (FZ + 1.6, FZ + 4.3):
        bx(g, "Brass", hx0 - 0.08, hx1 + 0.08, hy0 - 0.08, hy1 + 0.08, z, z + 0.25)
    for yy in (hy0 + 0.4, hy1 - 0.4):                     # 모서리 쇠 띠(볼트 줄)
        bx(g, "IronLight", hx1 - 0.05, hx1 + 0.12, yy - 0.2, yy + 0.2, FZ + 1.1, FZ + 5.0)
    # 구리 열기 통(뒤) + 연통
    K.S.banded_cyl(g, "Copper", FX, FY, FZ + 5.0, 1.6, 4.4, every=1.6)
    zf0 = FZ + 10.2
    ztop = R.top() + 1.0                  # 굴뚝 규칙: 지붕 꼭대기 위 1
    g["Copper"].cyl(FX, FY, zf0, 0.7, 0.7, ztop - zf0, seg=14)
    z = zf0 + 2.0
    while z < ztop - 1.0:
        g["Brass"].cyl(FX, FY, z, 0.82, 0.82, 0.3, seg=14)
        z += 3.0
    g["Brass"].cyl(FX, FY, ztop, 0.85, 0.85, 0.3, seg=14)
    for s in (-1, 1):
        bx(g, "Iron", FX + s * 0.55 - 0.08, FX + s * 0.55 + 0.08, FY - 0.08, FY + 0.08, ztop + 0.3, ztop + 1.3)
    g["Iron"].cyl(FX, FY, ztop + 1.3, 1.25, 0.2, 0.7, seg=14)          # 비 갓
    bx(g, "SnowCap", FX - 0.5, FX + 0.5, FY - 0.5, FY + 0.5, ztop + 1.85, ztop + 2.0)
    K.S.vent(g, FX, FY, ztop + 2.6)                       # (2팀) 비 갓(ztop+2.0) 위 — 갓 밑이면 김 위가 막힘
    # 방 쪽 면: 큰 놋쇠 톱니 바퀴 + 청록 룬 판 + 작은 톱니
    K.S.gear(g, "Brass", hx1 + 0.3, 5.6, FZ + 7.0, 2.1, 18, 0.35, axis="x")
    g["GlowTeal"].hcyl(hx1 + 0.5, 5.6, FZ + 7.0, 1.5, 0.12, axis="x", seg=24)       # 청록 테(검은 판 둘레로 빛이 새게)
    g["DarkStone"].hcyl(hx1 + 0.6, 5.6, FZ + 7.0, 1.25, 0.2, axis="x", seg=20)
    for dy, dz, ln, ang in ((0.0, 0.0, 1.9, 0.0), (0.42, 0.42, 0.9, 0.75), (-0.42, -0.42, 0.9, 0.75)):   # 룬 획(크게 — 1인칭에서 읽히게)
        g["GlowTeal"].obox(hx1 + 0.75, 5.6 + dy, FZ + 7.0 + dz, 0.08, 0.26, ln, rx=ang)
    for yy in (4.2, 7.0):                     # 몸 앞 빛 창(청록 유리)
        bx(g, "GlowTeal", hx1 + 0.02, hx1 + 0.1, yy - 0.5, yy + 0.5, FZ + 1.9, FZ + 2.7)
    K.S.gear(g, "Copper", hx1 + 0.3, 8.4, FZ + 6.0, 1.0, 10, 0.3, axis="x")
    bx(g, "Iron", hx1, hx1 + 0.3, 5.4, 5.8, FZ + 5.0, FZ + 7.0)      # 톱니 축 받침(몸 위)
    bx(g, "Iron", hx1, hx1 + 0.3, 8.2, 8.6, FZ + 5.0, FZ + 6.0)
    # 앞 작업 받침(놋쇠 집게 위 칼) + 청록 빛 띠
    bx(g, "Iron", hx1, hx1 + 1.3, 4.0, 7.2, FZ + 3.0, FZ + 3.4)
    for yy in (4.4, 6.8):
        bx(g, "Brass", hx1 + 0.4, hx1 + 0.9, yy - 0.25, yy + 0.25, FZ + 3.4, FZ + 3.9)
    g["Steel"].box(hx1 + 0.65, 5.6, FZ + 3.95, 0.35, 3.6, 0.1)
    g["GlowTeal"].box(hx1 + 0.65, 5.6, FZ + 4.02, 0.12, 2.2, 0.04)
    for yy in (3.6, 9.2):
        g["GlowTeal"].box(hx1 + 0.06, yy, FZ + 3.0, 0.08, 0.3, 1.6)
    # 놋쇠 관: 열기 통 → 몸 옆
    K.S.pipe(g, [(FX + 1.6, FY, FZ + 8.0), (hx1 - 0.6, FY, FZ + 8.0), (hx1 - 0.6, FY, FZ + 5.0)], 0.22, mat="Brass", flange="Copper")
    g["LampPt"].box(hx1 + 1.4, 5.6, FZ + 6.0, 0.3, 0.3, 0.3)
    cbox(x0, x1, y0, y1, FZ, FZ + 5.0)
    cbox(hx1, hx1 + 1.3, 4.0, 7.2, FZ, FZ + 4.0)


def shop(g):
    """카운터(판넬 · 짙은 돌 상판) + 벨벳 방석 위 수정 · 확대경 · 룬 돌판 · 맡긴 칼 · NPC · 뒷벽 작업대(창 줄 아래) + 갓 등 둘 +
    바이스 · 광택 바퀴 · 연장 두루마리 · 보석 쟁반 · 오른 벽 룬 판 진열판"""
    x0, x1, y0, y1 = COUNTER
    zt = N.stone_counter(g, x0, x1, y0, y1, FZ)
    g["DarkStone"].obox(3.0, 4.2, zt + 0.12, 1.2, 0.8, 0.24, rz=0.3)          # 룬 돌판
    g["GlowTeal"].box(3.0, 4.2, zt + 0.25, 0.6, 0.1, 0.03)
    g["Steel"].obox(7.6, 4.3, zt + 0.08, 3.0, 0.32, 0.12, rz=0.05)            # 맡긴 칼(날 · 코등이 · 손잡이)
    g["Brass"].obox(5.95, 4.22, zt + 0.12, 0.2, 1.0, 0.2, rz=0.05)
    g["Leather"].obox(5.45, 4.2, zt + 0.12, 0.8, 0.22, 0.22, rz=0.05)
    bx(g, "Banner", 4.0, 5.0, 3.6, 4.6, zt, zt + 0.25)                         # 벨벳 방석 + 작은 수정
    N.crystal(g, 4.5, 4.1, zt + 0.25, r=0.22, h=0.8, tilt=0.3)
    g["Brass"].cyl(9.8, 4.5, zt, 0.25, 0.2, 0.9, seg=10)                       # 확대경 받침
    g["Brass"].hcyl(9.8, 4.2, zt + 1.0, 0.4, 0.1, axis="y", seg=14)
    g["Glass"].hcyl(9.8, 4.15, zt + 1.0, 0.32, 0.12, axis="y", seg=14)
    NPC(6.0, 7.3, FZ, 0.0)
    # 뒷벽 긴 작업대(창 줄 아래)
    by0, by1 = YI1 - 1.6, YI1
    bt = FZ + 3.2
    for xx in (0.8, 5.95, 11.1):
        bx(g, "Timber", xx - 0.22, xx + 0.22, by0 + 0.2, by0 + 0.64, FZ, bt - 0.2)
        bx(g, "Timber", xx - 0.28, xx + 0.28, by0 + 0.14, by0 + 0.7, FZ, FZ + 0.25)
    bx(g, "Timber", 0.6, 11.3, by0 + 0.1, by1, FZ + 0.6, FZ + 0.8)
    bx(g, "Wood", 0.5, 11.4, by0, by1, bt - 0.2, bt)
    bx(g, "Timber", 7.5, 11.0, by0 + 0.1, by1, bt - 1.3, bt - 0.2)            # 서랍 덩이
    for xx in (8.4, 10.1):
        bx(g, "Brass", xx - 0.2, xx + 0.2, by0 - 0.05, by0, bt - 0.85, bt - 0.65)
    bx(g, "Iron", 1.0, 1.6, by0 - 0.15, by0 + 0.6, bt, bt + 0.25)              # 바이스(몸 · 턱 둘 · 손잡이)
    for yy in (by0 - 0.1, by0 + 0.35):
        bx(g, "Iron", 1.05, 1.55, yy, yy + 0.22, bt + 0.25, bt + 0.75)
    g["Iron"].hcyl(1.3, by0 - 0.45, bt + 0.45, 0.07, 0.7, axis="y", seg=6)
    g["Brass"].hcyl(1.3, by0 - 0.8, bt + 0.45, 0.13, 0.14, axis="y", seg=6)
    bx(g, "Iron", 2.7, 3.3, by0 + 0.4, by0 + 1.2, bt, bt + 0.35)              # 광택 바퀴(받침 · 굴대 · 천 바퀴 둘)
    g["Iron"].hcyl(3.0, by0 + 0.8, bt + 0.9, 0.08, 1.8, axis="x", seg=6)
    bx(g, "Iron", 2.9, 3.1, by0 + 0.7, by0 + 0.9, bt + 0.35, bt + 0.9)
    for xx in (2.25, 3.75):
        g["Canvas"].hcyl(xx, by0 + 0.8, bt + 0.9, 0.55, 0.28, axis="x", seg=12)
    g["Leather"].box(9.2, by0 + 0.8, bt + 0.04, 2.0, 1.0, 0.08)               # 연장 두루마리(가죽 + 손잡이 줄)
    for k in range(5):
        g[("Wood", "Brass")[k % 2]].hcyl(8.5 + k * 0.35, by0 + 0.75, bt + 0.2, 0.09, 0.9, axis="y", seg=6)
    bx(g, "Wood", 4.6, 5.8, by0 + 0.3, by0 + 1.2, bt, bt + 0.12)               # 보석 쟁반 + 수정
    bx(g, "Banner", 4.7, 5.7, by0 + 0.4, by0 + 1.1, bt + 0.12, bt + 0.16)
    for k, (dx, dy) in enumerate(((0.0, 0.0), (0.4, 0.25), (-0.3, 0.3))):
        N.crystal(g, 5.2 + dx, by0 + 0.6 + dy, bt + 0.16, r=0.13, h=0.5, mat=("GlowTeal", "SignBlue", "SignPurple")[k], tilt=0.6, rz=k * 2.0)
    for xx in (3.8, 7.4):                    # 갓 등: 작업대 위 기둥 + 팔 + 놋쇠 갓
        bx(g, "Iron", xx - 0.1, xx + 0.1, by1 - 0.5, by1 - 0.3, bt, bt + 2.4)
        bx(g, "Iron", xx - 0.08, xx + 0.08, by1 - 1.4, by1 - 0.3, bt + 2.3, bt + 2.45)
        g["Brass"].cyl(xx, by1 - 1.4, bt + 1.7, 0.6, 0.25, 0.6, seg=12)
        g["Glow"].box(xx, by1 - 1.4, bt + 1.65, 0.3, 0.3, 0.12)
        g["LampPt"].box(xx, by1 - 1.4, bt + 1.4, 0.3, 0.3, 0.3)
    cbox(0.5, 11.4, by0, by1, FZ, bt)
    # 오른 벽 진열판(룬 판 넷) — 창(y -6.5..-3.5)을 피해 앞 구석, 짙은 틀 + 놋쇠 머리
    px = XI
    bx(g, "DarkLog", px - 0.35, px, -10.1, -6.8, FZ + 2.7, FZ + 7.9)
    bx(g, "Timber", px - 0.42, px - 0.3, -9.85, -7.05, FZ + 3.0, FZ + 7.6)
    bx(g, "Brass", px - 0.45, px, -10.2, -6.7, FZ + 7.9, FZ + 8.1)
    for k in range(4):
        yy = -9.15 + (k % 2) * 1.75
        zz = FZ + 4.2 + (k // 2) * 2.0
        g["DarkStone"].obox(px - 0.55, yy, zz, 0.2, 0.9, 0.9, rx=math.pi / 4)
        g["GlowTeal"].box(px - 0.68, yy, zz, 0.05, 0.12, 0.7)
    # 오른 벽 연장 걸이판(창 사이) + 아래 원석 통 둘(무릎 높이 — 충돌 없음)
    N.put(g, px, 1.0, FZ + 3.4, -math.pi / 2, N.tool_board, 4.0, 3.0)
    for k, y in enumerate((6.5, 8.0)):                                            # 원석 통 둘(카운터 오른 끝 뒤 — 빈 바닥 밖)
        N.put(g, px - 0.75, y, FL, 0.2 * k, N.barrel, 0.6, 1.3, "Wood", "Iron", "DarkLog", 10, False)
        for j, (dx, dy, t) in enumerate(((0.0, 0.0, 0.2), (0.2, 0.15, 0.6), (-0.2, -0.1, 0.5))):
            N.crystal(g, px - 0.75 + dx, y + dy, FL + 1.35, r=0.17, h=0.65 - 0.1 * j, mat=("GlowTeal", "SignPurple")[(j + k) % 2], tilt=t, rz=j * 2.1)
    cbox(px - 1.4, px, 5.8, 8.7, FZ, FL + 1.4)


def enhance_corner(g):
    """강화 자리(문에 들어서면 정면 왼쪽 — 룬 기계 앞): 청록 수정 받침 + 바닥 룬 고리 · 앞 강화 모루(그루터기 · 2단 뿔 · 칼 · 망치) ·
    왼 앞 원석 진열대 · 앞 구석 발판 숫돌 · 수정 빛"""
    ax, ay = ALTAR
    N.put(g, ax, ay, FL, 0.0, N.crystal_altar)
    cbox(ax - 1.6, ax + 1.6, ay - 1.6, ay + 1.6, FZ, FL + 6.0)
    g["LampPt"].box(ax + 1.2, ay - 1.2, FL + 5.2, 0.3, 0.3, 0.3)
    N.put(g, ax - 3.2, ay - 0.6, FL, 0.3, N.rune_anvil)                         # 모루: 받침 왼쪽(길 폭 10 지킴)
    cbox(ax - 4.4, ax - 2.0, ay - 1.8, ay + 0.6, FZ, FL + 2.6)
    N.put(g, -7.0, -4.2, FL, 0.0, N.ore_display, 4.0, 2.0, 2.0)
    cbox(-9.0, -5.0, -5.2, -3.2, FZ, FL + 2.0)
    N.put(g, -10.4, -7.6, FL, math.pi / 2, N.grindstone)
    cbox(-11.4, -9.4, -8.7, -6.5, FZ, FL + 3.8)
    K.lantern(g, ax - 3.2, ay - 2.4, Z_PLATE - 0.9, FZ + 8.4)


def crystal_crate(g):
    """오른 앞 구석: 뚜껑 연 원석 상자 + 수정 덩이"""
    N.put(g, 9.8, -8.9, FL, 0.15, N.crate, 2.2, 1.9, 1.7)
    for k, (dx, dy, t, rz, h) in enumerate(((0.0, 0.0, 0.2, 0.0, 1.3), (0.5, 0.3, 0.5, 1.0, 0.9), (-0.5, -0.2, 0.55, 3.5, 1.0), (0.2, -0.45, 0.4, 5.0, 0.8))):
        N.crystal(g, 9.8 + dx, -8.9 + dy, FL + 1.55, r=0.22 + 0.06 * (k == 0), h=h, tilt=t, rz=rz)
    g["Iron"].obox(9.6, -10.15, FL + 0.9, 2.0, 0.15, 1.6, rz=0.15, rx=0.4)
    cbox(8.6, 11.0, -10.1, -7.7, FZ, FL + 1.9)


def steam(g):
    """왼 앞 바깥: 증기 통(압력계가 길을 봄) → 관이 앞벽 앞으로 → 벽을 타고 올라 → 벽 속으로(룬 기계 열기)"""
    tx, ty = -10.3, -14.2
    rx = -6.95
    N.no_vent(g, K.steam_bundle, tx, ty, 0.0, h=6.2, r=1.15, gauge_face=-1,
              pipe_pts=[(tx + 1.15, ty, 4.2), (rx, ty, 4.2), (rx, -12.35, 4.2), (rx, -12.35, 12.6), (rx, -11.3, 12.6)])
    for z in (7.0, 10.0):                     # 관 띠쇠(벽에 박음)
        bx(g, "Iron", rx - 0.45, rx + 0.45, -12.75, -11.6, z - 0.12, z + 0.12)


def build(g):
    R = K.roof_frame(HALF, YF - T / 2, YB + T / 2, Z_PLATE, VARIANT)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, YF - T / 2 - 0.3, YB + T / 2 + 0.3)
    K.stair(g, 0.0, YF - T / 2 - 0.3, 12.0, FZ)
    N.plank_floor(g, -XI, XI, YI0, YI1, FZ)             # (2팀) 널 마루
    walls(g, R)
    for y in (-6.0, 0.5, 9.0):
        K.tie_truss(g, y, R)
    K.roof_gable(g, R, openings=[FLUE])
    gable_sign(g)
    side_sign(g)
    machine(g, R)
    shop(g)
    enhance_corner(g)
    crystal_crate(g)
    for x, y in ((0.0, -6.0), (6.0, 0.5), (-4.0, 0.5)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)
    steam(g)
    CLEAR(-5.0, 5.0, YI0 + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.15, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((0.0, YF - 1.5), (6.0, -2.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI1),
    "forge_look": (-6.0, 5.6),              # 1인칭 안 렌더가 바라볼 룬 기계
}
