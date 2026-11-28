# -*- coding: utf-8 -*-
"""
b_potion.py — 2026-11-14. 설원 마을 3판: 물약상점(사고팔기, 발자국 28×28). 아트 부서원 1, A 양식(짙은 통나무).
2026-11-18 아트 2팀: 구멍 막이(박공 꼭대기 띠·처마 막이판) · 김 표지 뺌(옛 증류기 김이 방 안, 바깥 증기 통은 처마 밑) · 내부 다시(lib_int2 소품).
2026-11-24 2팀 2차(비평 1차): 카운터 앞면 = 이름표 서랍 격자 + 상판 위 낮은 유리 진열함 · 매단 약초 = 건조대 막대 둘에 다발(줄기 + 잎 덩이) ·
  끓는 솥 위 구리 후드 → 관이 천장 따라 화덕 쇠 연통에 합쳐 지붕 위 비 갓까지(김 = 연통 끝 하나) · 약장 병 줄 손으로 섞음(큰 단지·빈 칸·눕힌 병).

레퍼런스(회사/설원마을_레퍼런스.md P·C·내부 2팀 PO): 약방 "크로난"(P1 — 카운터 뒤 벽 전체 녹색 칠 약장 + 병 줄, 기둥 둘 + 머리보가 두른 "제단" 정면,
카운터 위 큰 약병 둘), 하이델베르크 약방(P2 — 아래 서랍장 격자 + 카운터 앞 저울), 아들러 약국(P3 — 지붕창 줄 → 우리는 앞 박공 큰 병 간판),
옛 증류실(단식 증류솥 + 백조 목 관 + 냉각 통), 뢰로스 통나무(C1·C2). 대장간·잡화점과 구별되게 **더 가파른 앞 박공(물매 48°)** + 박공 한가운데 큰 병 그림 판 + 오른 옆 구리 증기 통.

배치(블렌더, 앞 = -y, 바닥 FZ = 2, 널 마루 윗면 FL = 2.08):
  벽 가운데 선 x ±11.4 · y -11..11.4 → 안 21.6 × 21.2, 천장 11. 앞 돌 마루(깊이 1.4) + 계단 폭 12.
  정문 x ±5.2 높이 10(널문 안쪽 95°) · 양옆 진열창 3.6×5.5(창 안 낮은 단에 큰 병)
  문에 들어서면: 정면 뒷벽 녹색 약장(아래 이름표 서랍 · 위 병·사기 단지 칸 넷 · 놋쇠 난간 + 기댄 사다리) 앞 카운터(천칭·막자사발·큰 병 둘·장부),
     오른쪽 구리 증류 장치(벽돌 화덕 + 불 · 단식 증류솥 · 백조 목 관 → 냉각 통 → 받는 병) · 왼쪽 끓는 솥(청록 물약 + 거품, 장작불) ·
     왼 뒤 약초 작업대 + 벽 선반 + 매단 말린 약초 · 오른 앞 이름표 서랍장 + 약초 통·자루.
  카운터 x -5..5 · y 5.8..8.3, NPC (0, 9.05), 카운터 앞 빈 바닥 x -5..5 · y -4.35..5.65(비움)
  바깥: 앞 박공 큰 병 판, 왼 앞 모서리 쇠 팔 병 간판, 오른 옆 증기 통 → 관이 옆벽으로(증류 장치에 열)
"""
import math

from mathutils import Matrix

import lib as K
import lib_a as A
import lib_int2 as N
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_SILL, bx, cbox, NPC, CLEAR

I = K.I

NAME = "Sn3_Potion"
PREFIX = "Sn3Potion"
VARIANT = "A"
PITCH = 48.0                               # 대장간·잡화점(40)보다 가파르게 — 실루엣 구별

WX, YF, YB = 11.4, -11.0, 11.4
T = LOG
HALF = WX + T / 2                          # 12.0
XI, YFI, YBI = WX - T / 2, YF + T / 2, YB - T / 2     # 10.8 · -10.4 · 10.8
Z_PLATE = FZ + CEIL + 0.9
LAND = YF - T / 2 - 1.4
SHOP_WIN = (3.6, 5.5, FZ + 2.0)
FL = FZ + 0.08
STILL = (8.0, 0.1)                         # 증류솥 가운데(화덕 위)
TUB = (8.0, 4.4)                           # 냉각 통
CAUL = (-8.4, 5.2)                         # 끓는 솥(왼 뒤 구석 — 2026-11-28: 앞 진열단과 5 · 작업대와 3.4 틈이 나서 옮김. 후드 다리는 평보 y 7 에)
FLUE = (7.3, 2.7)                          # 화덕 쇠 연통(뒤, 지붕 위로)


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    sw, sh, sz = SHOP_WIN
    wz = FZ + WIN_SILL
    holes = {"f": [(-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H), A.hole(-8.2, sz, sw, sh), A.hole(8.2, sz, sw, sh)],
             "l": [A.hole(-6.5, wz), A.hole(5.0, wz)],
             "r": [A.hole(-7.0, wz), A.hole(6.0, wz)]}
    A.log_box(g, -WX, WX, YF, YB, FZ, Z_PLATE, holes)
    for u in (-8.2, 8.2):
        A.win(g, S, "f", u, sz, sw, sh, shutters=False)
    for u in (-6.5, 5.0):
        A.win(g, S, "l", u, wz)
    for u in (-7.0, 6.0):
        A.win(g, S, "r", u, wz)
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    gz = Z_PLATE + 6.0
    K.gable_logs(g, "x", YF, HALF, Z_PLATE, top)
    K.gable_logs(g, "x", YB, HALF, Z_PLATE, top, holes=[(-1.2, 1.2, gz, gz + 3.0)])
    K.window(g, "x", YB, 0.0, gz, 2.4, 3.0, face=1, shutters=False)
    for c in (YF, YB):                                         # (2팀) 박공 꼭대기 띠 · 처마 막이판(공용 gable_logs · roof_gable 의 틈)
        N.gable_seal(g, "x", c, R)
    N.eave_block(g, R, YF, YB)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=95.0, outward=False)


def _shelf_row(g, x0, x1, y, z, seed):
    """약장 칸 하나 채우기(손 표): 병·사기 단지·큰 단지·빈 칸·눕힌 병을 손으로 정한 순서로 — 같은 모양이 같은 간격으로 이어지지 않게"""
    seq = ((0, "SignRed", 1.1), ("big", "SignTeal", 1.2), (2, "SignGold", 1.0), (0, "SignPurple", 1.3), ("gap",), (1, "Verdigris", 0.9),
           ("jar", "SignRed", 0.85), (0, "GlowTeal", 1.0), ("lie", "SignBlue"), (2, "SignGold", 1.15), (0, "SignBlue", 0.95),
           ("big", "SignGold", 1.15), (1, "SignRed", 0.85), ("gap",), ("jar", "SignPurple", 0.9))
    x, k = x0 + 0.45, seed
    while x < x1 - 0.4:
        it = seq[k % len(seq)]
        kind = it[0]
        if kind == "gap":
            x += 0.6
        elif kind == "big":
            if x + 0.6 > x1 - 0.2:
                break
            N.jar(g, x + 0.12, y, z, r=0.52, h=it[2], band=it[1])
            x += 1.2
        elif kind == "jar":
            N.jar(g, x, y, z, r=0.36, h=it[2], band=it[1])
            x += 0.88
        elif kind == "lie":
            if x + 1.1 > x1 - 0.2:
                break
            g[it[1]].hcyl(x + 0.35, y, z + 0.27, 0.26, 0.75, axis="x", seg=8)
            g["Glass"].hcyl(x + 0.9, y, z + 0.27, 0.1, 0.35, axis="x", seg=6)
            g["Wood"].hcyl(x + 1.1, y, z + 0.27, 0.11, 0.12, axis="x", seg=6)
            x += 1.35
        else:
            N.bottle(g, x, y, z, it[1], r=0.25 if kind != 1 else 0.22, h=it[2], kind=kind, label="Paint" if k % 3 else "Canvas")
            x += 0.75 if kind != 1 else 0.85
        k += 1


def cabinet(g):
    """뒷벽 약장(P1·P2): 아래 이름표 서랍(격자 · 놋쇠 손잡이) · 위 병 칸 넷(병·사기 단지) · 기둥 넷 · 머리보 + 가운데 병 머리판 ·
    머리보 밑 놋쇠 난간 + 기댄 사다리"""
    x0, x1 = -XI + 0.2, XI - 0.2
    yw = YBI
    yd = yw - 1.0                                   # 아래 서랍장 앞
    bx(g, "PaintGreen", x0, x1, yd, yw, FZ, FZ + 3.0)
    bx(g, "Wood", x0 - 0.1, x1 + 0.1, yd - 0.15, yw, FZ + 3.0, FZ + 3.2)
    nx = int((x1 - x0) / 1.4)
    for i in range(nx):
        xa = x0 + (x1 - x0) * i / nx
        xb = x0 + (x1 - x0) * (i + 1) / nx
        for zz in (FZ + 0.4, FZ + 1.3, FZ + 2.2):
            bx(g, "Timber", xa + 0.08, xb - 0.08, yd - 0.06, yd, zz, zz + 0.75)
            bx(g, "Paint", (xa + xb) / 2 - 0.3, (xa + xb) / 2 + 0.3, yd - 0.09, yd - 0.06, zz + 0.45, zz + 0.67)
            bx(g, "Brass", (xa + xb) / 2 - 0.12, (xa + xb) / 2 + 0.12, yd - 0.14, yd - 0.06, zz + 0.15, zz + 0.32)
    cbox(x0, x1, yd, yw, FZ, FZ + 3.2)
    ys = yw - 0.8
    bx(g, "PaintGreen", x0, x1, yw - 0.12, yw, FZ + 3.2, FZ + 8.6)
    for k in range(4):
        z = FZ + 3.9 + k * 1.2 + (0.25 if k == 3 else 0.0)
        bx(g, "Wood", x0, x1, ys, yw, z - 0.12, z)
        for b, (a0, a1) in enumerate(((x0 + 0.6, -3.9), (-3.3, 3.3), (3.9, x1 - 0.6))):
            _shelf_row(g, a0, a1, ys + 0.42, z, seed=k * 3 + b * 5)
    for x in (x0 + 0.3, -3.6, 3.6, x1 - 0.3):
        bx(g, "PaintGreen", x - 0.3, x + 0.3, ys - 0.15, yw, FZ + 3.2, FZ + 8.6)
        bx(g, "Brass", x - 0.36, x + 0.36, ys - 0.2, yw, FZ + 3.2, FZ + 3.4)
    bx(g, "PaintGreen", x0 - 0.2, x1 + 0.2, ys - 0.35, yw, FZ + 8.6, FZ + 9.3)
    bx(g, "Brass", x0 - 0.25, x1 + 0.25, ys - 0.4, yw, FZ + 9.3, FZ + 9.45)
    bx(g, "PaintGreen", -2.2, 2.2, yw - 0.5, yw, FZ + 9.45, FZ + 10.6)
    K.L.transformed(g, Matrix.Translation((0, yw - 0.5, FZ + 9.5)) @ Matrix.Scale(0.42, 4) @ Matrix.Translation((0, -(yw - 0.5), -(FZ + 9.5))),
                    lambda q: K.SVC.flask_icon(q, 0.0, yw - 0.5, FZ + 9.5, face=-1))
    # 사다리 난간(머리보 밑, 기둥 앞에 받침) + 기댄 사다리(오른 칸)
    ry = ys - 0.55
    g["Brass"].hcyl(0.0, ry, FZ + 8.2, 0.1, x1 - x0 - 1.0, axis="x", seg=8)
    for x in (x0 + 0.3, -3.6, 3.6, x1 - 0.3):
        bx(g, "Brass", x - 0.08, x + 0.08, ry, ys - 0.15, FZ + 8.12, FZ + 8.28)
    lean = 0.14
    foot_y = ry - 7.0 * math.sin(lean) - 0.15
    K.L.transformed(g, Matrix.Translation((7.6, foot_y, FL)) @ Matrix.Rotation(-lean, 4, "X"), lambda q: N.ladder(q, 6.15))
    cbox(6.8, 8.4, foot_y - 0.2, ry, FZ, FL + 2.0)


def counter(g):
    """카운터(앞면 = 이름표 서랍 격자, 녹색 칠 틀) + 상판 위 낮은 유리 진열함 · 천칭 · 막자사발 · 큰 약병 둘(P1) · 촛대 · NPC"""
    zt = N.drawer_counter(g, -6.3, 5.0, 5.8, 8.3, FZ)                          # 왼 끝 -5 → -6.3(솥과 1.3 — 3~9 틈 금지)
    N.put(g, 0.0, 7.0, zt, 0.0, N.glass_case_low, 3.2, 1.3, 1.1)
    N.scale(g, -2.9, 6.9, zt)
    N.mortar(g, 2.6, 7.1, zt)
    for x, liq in ((-4.3, "SignRed"), (4.35, "GlowTeal")):
        N.bottle(g, x, 7.0, zt, liq, r=0.42, h=1.6, kind=1)
    N.candle(g, 3.6, 7.7, zt, h=0.6)
    NPC(0.0, 9.05, FZ, 0.0)


def distillery(g):
    """오른쪽 구리 증류 장치: 벽돌 화덕(불 아가리가 문을 봄 · 장작불 · 열어 둔 쇠 문) → 단식 증류솥(배 · 놋쇠 띠 · 둥근 지붕 · 투구 머리 · 압력계)
    → 백조 목 관(직각 꺾임) → 냉각 통(나무 통 + 위 물 · 구리 고리) → 아래 꼭지 → 받는 큰 병(걸상 위)"""
    sx, sy = STILL
    x0, x1, y0, y1 = sx - 1.8, sx + 1.8, sy - 1.7, sy + 1.7
    zt = FL + 2.6
    bx(g, "StoneTrim", x0 - 0.1, x1 + 0.1, y0 - 0.1, y1 + 0.1, FL, FL + 0.35)
    bx(g, "Brick", x0, x1, y0, y1, FL + 0.35, zt - 0.25)
    for z in (FL + 1.05, FL + 1.75):                                          # 벽돌 켜 줄(짙은 띠)
        bx(g, "BrickDark", x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, z, z + 0.1)
    bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, zt - 0.25, zt)
    bx(g, "Soot", sx - 0.8, sx + 0.8, y0 - 0.06, y0 + 0.1, FL + 0.5, FL + 1.75)  # 불 아가리(검은 테) + 속
    I.fire_logs(g, sx, y0 + 0.75, FL + 0.5, 1.4, 0.9, axis="x", size=0.9)
    g["LampPt"].box(sx, y0 - 0.6, FL + 1.3, 0.3, 0.3, 0.3)
    g["Iron"].obox(sx - 1.35, y0 - 0.5, FL + 1.12, 0.12, 1.0, 1.25, rz=0.6)      # 열어 둔 쇠 문
    cbox(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, FZ, zt)
    g["Copper"].cyl(sx, sy, zt, 1.2, 1.55, 0.9, seg=14)
    g["Copper"].cyl(sx, sy, zt + 0.9, 1.55, 1.05, 0.8, seg=14)
    g["Brass"].cyl(sx, sy, zt + 0.82, 1.6, 1.6, 0.18, seg=14)
    g["Copper"].cyl(sx, sy, zt + 1.7, 1.05, 0.45, 0.6, seg=14)
    g["Copper"].cyl(sx, sy, zt + 2.3, 0.45, 0.72, 0.45, seg=12)
    g["Copper"].cyl(sx, sy, zt + 2.75, 0.72, 0.3, 0.45, seg=12)
    for k in range(6):                                                          # 배 둘레 리벳 띠(굵게)
        a = k * math.pi / 3
        g["Brass"].box(sx + 1.56 * math.cos(a), sy + 1.56 * math.sin(a), zt + 0.5, 0.16, 0.16, 0.16)
    g["Iron"].hcyl(sx - 0.2, sy - 1.6, zt + 1.25, 0.42, 0.14, axis="y", seg=12)     # 압력계(문 쪽)
    g["Dial"].hcyl(sx - 0.2, sy - 1.68, zt + 1.25, 0.34, 0.05, axis="y", seg=12)
    tx, ty = TUB
    zh = zt + 3.2
    K.S.pipe(g, [(sx, sy, zh - 0.05), (sx, sy, zh + 0.7), (tx, ty, zh + 0.7), (tx, ty, FL + 3.2)], 0.24, mat="Copper")
    N.put(g, tx, ty, FL, 0.0, N.barrel, 1.15, 3.0, "Wood", "Iron", "DarkLog", 10, False)
    g["Glass"].cyl(tx, ty, FL + 3.0, 0.9, 0.9, 0.09, seg=10)
    for z in (FL + 3.1, FL + 3.25):
        K.S.ring(g, "Copper", tx, ty, z, 0.45, 0.65, 0.1, n=12)
    cbox(tx - 1.15, tx + 1.15, ty - 1.15, ty + 1.15, FZ, FL + 3.1)
    g["Copper"].hcyl(tx - 1.3, ty, FL + 0.9, 0.12, 0.5, axis="x", seg=6)         # 꼭지 → 받는 병
    g["Brass"].cyl(tx - 1.55, ty, FL + 0.55, 0.08, 0.06, 0.35, seg=6)
    N.put(g, tx - 1.7, ty, FL, 0.0, N.stool, 0.45)
    N.bottle(g, tx - 1.7, ty, FL + 0.45, "SignTeal", r=0.42, h=1.1, kind=1, label=None)
    # 화덕 쇠 연통: 화덕 뒤 벽돌 목 → 쇠 관(놋쇠 띠) → 지붕을 뚫고 비 갓 · 김(이 건물 김은 여기 하나)
    fx, fy = FLUE
    bx(g, "Brick", fx - 0.55, fx + 0.55, y1 - 0.1, fy + 0.45, FL + 0.35, FL + 2.3)
    bx(g, "StoneTrim", fx - 0.6, fx + 0.6, y1 - 0.15, fy + 0.5, FL + 2.3, FL + 2.5)
    cbox(fx - 0.55, fx + 0.55, y1, fy + 0.45, FZ, FL + 2.5)
    top = 24.9
    g["Iron"].cyl(fx, fy, FL + 2.5, 0.32, 0.32, top - FL - 2.5, seg=10)
    z = FL + 4.5
    while z < top - 1.0:
        g["Brass"].cyl(fx, fy, z, 0.38, 0.38, 0.16, seg=10)
        z += 2.6
    g["Iron"].cyl(fx, fy, 23.5, 0.6, 0.45, 0.5, seg=10)                          # 지붕 깃(물막이, 눈 위)
    for sx in (-1, 1):
        bx(g, "Iron", fx + sx * 0.3 - 0.05, fx + sx * 0.3 + 0.05, fy - 0.05, fy + 0.05, top, top + 0.7)
    g["Iron"].cyl(fx, fy, top + 0.7, 0.85, 0.15, 0.55, seg=10)                   # 비 갓
    bx(g, "SnowCap", fx - 0.35, fx + 0.35, fy - 0.35, fy + 0.35, top + 1.2, top + 1.32)
    K.S.vent(g, fx, fy, top + 2.0)


def herb_corner(g):
    """왼쪽(2026-11-28 다시 놓음): 앞 약초 작업대(벽에 붙음) · 약초 통·자루(작업대 ~ 솥 사이) · 위 벽 선반 · 평보(y 1)에 매단 약초 건조대 · 왼 뒤 구석 끓는 솥"""
    N.put(g, -9.8, -4.2, FL, math.pi / 2, N.table, 6.4, 2.0, 3.0)                # 약초 작업대(진열단과 1.6 · 약초 통과 0.4)
    cbox(-10.8, -8.8, -7.4, -1.0, FZ, FL + 3.0)
    zt = FL + 3.0
    N.mortar(g, -9.6, -6.6, zt)
    bx(g, "Wood", -10.3, -9.0, -5.4, -3.8, zt, zt + 0.15)                       # 도마 + 썬 약초
    for k, (dx, dy) in enumerate(((0.0, 0.0), (0.25, 0.4), (-0.2, 0.7))):
        g["Felt"].obox(-9.65 + dx, -5.0 + dy, zt + 0.22, 0.5, 0.3, 0.12, rz=k * 0.6)
    for k, (y, liq) in enumerate(((-3.0, "SignPurple"), (-2.4, "Verdigris"), (-1.8, "SignRed"))):
        N.bottle(g, -9.9, y, zt, liq, r=0.24, h=0.95 + 0.15 * k)
    N.book(g, -9.4, -7.0 + 0.4, zt, cover="Leather", open_=True)
    N.put(g, -10.0, 0.5, FL, 0.0, N.barrel, 0.75, 2.1, "Wood", "Iron", "DarkLog", 10, False)    # 약초 통(뚜껑 열림 — 마른 잎) + 자루 둘
    g["Felt"].cyl(-10.0, 0.5, FL + 2.1, 0.6, 0.25, 0.35, seg=8)
    for x, y, r in ((-9.4, -0.3, 0.4), (-9.35, 1.25, -0.5)):
        N.put(g, x, y, FL, r, N.sack, 0.8, "Canvas")
    cbox(-10.8, -8.6, -0.6, 1.6, FZ, FL + 2.4)
    N.put(g, -XI, 2.0, FZ + 6.2, math.pi / 2, N.wall_shelf, 2.6)                # 벽 선반(창 옆) + 단지
    for k, y in enumerate((1.1, 1.9, 2.8)):
        N.jar(g, -10.3, y, FZ + 6.2, r=0.34, h=0.9 + 0.1 * k, band=("SignTeal", "SignGold", "SignRed")[k])
    zt0 = Z_PLATE - 0.9                                                          # 건조대: 평보(y 7 · y 1)에서 쇠 막대 둘 → 막대(길이 5) → 다발 일곱
    mats = ("Felt", "SignPurple", "SignGold", "Twig", "Felt", "SignPurple", "Twig")
    for r, (y, x0) in enumerate(((1.0, -9.8),)):                                # (y 7 건조대는 솥 후드 자리라 뺐다)
        zp = zt0 - 1.9
        for x in (x0 + 0.3, x0 + 4.7):
            bx(g, "Iron", x - 0.06, x + 0.06, y - 0.06, y + 0.06, zp, zt0)
        g["Timber"].hcyl(x0 + 2.5, y, zp, 0.14, 5.0, axis="x", seg=8)
        for k in range(7):
            N.herbs(g, x0 + 0.5 + k * 0.67, y + (0.12 if k % 2 else -0.12), zp - 0.05, mat=mats[(k + 3 * r) % len(mats)],
                    drop=1.3 + 0.25 * ((k + r) % 3))
    cx, cy = CAUL                                                                # 끓는 솥 + 장작불 + 구리 후드(평보 y 1 에 비스듬 막대 둘)
    N.put(g, cx, cy, FL, 0.0, N.cauldron)
    I.fire_logs(g, cx, cy, FL + 0.48, 1.3, 0.8, axis="x", size=0.9)
    g["LampPt"].box(cx + 1.6, cy, FL + 3.6, 0.3, 0.3, 0.3)
    cbox(cx - 1.95, cx + 1.95, cy - 1.95, cy + 1.95, FZ, FL + 2.5)
    zh = FL + 6.2
    K.SVC.frustum(g, "Copper", cx, cy, zh, 4.0, 4.0, 1.0, 1.0, 2.0)
    bx(g, "Brass", cx - 2.05, cx + 2.05, cy - 2.05, cy + 2.05, zh - 0.18, zh)
    for dx in (-1.5, 1.5):
        A.lattice_leg(g, (cx + dx, cy + 1.5, zh + 0.5), (cx + dx, 1.0, Z_PLATE - 0.9), s=0.14, mat="Iron")
    fx, fy = FLUE
    K.S.pipe(g, [(cx, cy, zh + 2.0), (cx, cy, 12.3), (fx, cy, 12.3), (fx, fy, 12.3)], 0.28, mat="Copper")


def right_front(g):
    """오른 앞(안으로 연 문짝 뒤): 창 밑 이름표 서랍장 + 단지 · 약초 통(뚜껑 열림) · 자루 둘"""
    N.put(g, 10.15, -6.6, FL, math.pi / 2, N.drawer_chest, 4.4, 1.2, 3.0, 3, 2)
    cbox(9.55, 10.8, -8.8, -4.4, FZ, FL + 3.0)
    for k, y in enumerate((-8.0, -7.1, -6.0, -5.1)):
        N.jar(g, 10.15, y, FL + 3.0, r=0.32, h=0.85 + 0.12 * (k % 2), band=("SignPurple", "SignTeal")[k % 2])
    N.put(g, 7.2, -7.0, FL, 0.0, N.barrel, 0.95, 2.4, "Wood", "Iron", "DarkLog", 10, False)
    g["Felt"].cyl(7.2, -7.0, FL + 2.4, 0.75, 0.3, 0.4, seg=8)
    cbox(6.25, 8.15, -7.95, -6.05, FZ, FL + 2.5)
    for x, y, r in ((7.4, -4.6, 0.3), (8.6, -5.2, -0.4)):
        N.put(g, x, y, FL, r, N.sack, 0.95, "Canvas")
    cbox(6.6, 9.4, -5.9, -3.9, FZ, FL + 1.6)


def shop(g):
    counter(g)
    cabinet(g)
    distillery(g)
    herb_corner(g)
    right_front(g)
    for x0, x1 in ((-10.6, -5.8), (5.8, 10.6)):                                # 진열창 안 낮은 단 + 큰 병
        K.I.box2(g, "Timber", x0, x1, YFI, YFI + 1.4, FZ, FZ + 1.6)
        bx(g, "Wood", x0 - 0.05, x1 + 0.05, YFI, YFI + 1.45, FZ + 1.6, FZ + 1.75)
        for k, liq in enumerate(("SignPurple", "SignTeal", "SignRed")):
            N.bottle(g, x0 + 0.9 + k * 1.5, YFI + 0.75, FZ + 1.75, liq, r=0.5 - 0.1 * (k % 2), h=1.6 - 0.4 * (k % 2), kind=1 if k != 1 else 0)
    for x, y in ((0.0, -5.0), (0.0, 1.0), (-4.0, 7.0), (4.5, 7.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.6)


def outside(g, R):
    # 앞 박공 큰 병 판(통나무 박공에 쇠 띠로 박음)
    zb = Z_PLATE + 1.6
    yb = YF - T / 2
    bx(g, "Timber", -2.6, 2.6, yb - 0.3, yb, zb, zb + 4.4)
    bx(g, "Brass", -2.75, 2.75, yb - 0.35, yb, zb - 0.15, zb)
    bx(g, "Brass", -2.75, 2.75, yb - 0.35, yb, zb + 4.4, zb + 4.55)
    for x in (-2.0, 2.0):
        bx(g, "Iron", x - 0.12, x + 0.12, yb - 0.4, yb - 0.3, zb + 0.3, zb + 4.1)
    K.L.transformed(g, Matrix.Translation((0, yb - 0.3, zb + 0.6)) @ Matrix.Scale(1.4, 4) @ Matrix.Translation((0, -(yb - 0.3), -(zb + 0.6))),
                    lambda q: K.SVC.flask_icon(q, 0.0, yb - 0.3, zb + 0.6, face=-1))
    # 왼 앞 모서리 쇠 팔 병 간판(옆벽 면 → -x 로)
    K.hang_sign(g, -HALF, YF + 1.0, FZ + 9.4, along="x", arm=2.0, board=(2.4, 2.6), face_sign=-1,
                icon=lambda g_, x, y, z, f: K.SVC.flask_icon(g_, x, y, z - 0.1, face=f))
    # 문 양옆 등
    for x in (-6.15, 6.15):
        bx(g, "Iron", x - 0.1, x + 0.1, YF - T / 2 - 1.2, YF - T / 2, FZ + 9.0, FZ + 9.2)
        K.lantern(g, x, YF - T / 2 - 1.1, FZ + 9.1, FZ + 7.8)
    # 오른 옆 증기 통 → 관이 옆벽으로(증류 장치에 열). (2팀) 김 표지는 뺌 — 처마 밑이라 위가 막힘
    tx, ty = HALF + 1.6, 3.5
    N.no_vent(g, K.steam_bundle, tx, ty, 0.0, h=6.8, r=1.1, gauge_face=-1, pipe_pts=[(tx - 1.1, ty, 7.4), (HALF - 0.3, ty, 7.4)])


def build(g):
    R = K.RoofFrame(HALF, YF - T / 2, YB + T / 2, Z_PLATE, PITCH)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, LAND, YB + T / 2 + 0.3)
    K.stair(g, 0.0, LAND, 12.0, FZ)
    N.plank_floor(g, -XI, XI, YFI, YBI, FZ, along="y")                          # (2팀) 널 마루
    shell(g, R)
    for y in (-5.0, 1.0, 7.0):
        K.tie_truss(g, y, R)
    K.roof_gable(g, R)
    shop(g)
    outside(g, R)
    CLEAR(-4.8, 4.8, YFI + 0.2, -4.35, FZ + 0.15, FZ + 5.4)
    CLEAR(-5.0, 5.0, -4.35, 5.65, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": (-6.3, 5.0, 5.8, 8.3),
    "free": (-5.0, 5.0, -4.35, 5.65),
    "walk": ((0.0, YF - 1.5), (0.0, 0.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YBI),
    "forge_look": STILL,
}
