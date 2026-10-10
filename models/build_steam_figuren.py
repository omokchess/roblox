# -*- coding: utf-8 -*-
"""
build_steam_figuren.py — 2026-10-10. 기물군 본부(Figuren_HQ) 2판 — 사용자: "기물군은 건물을 키워야(퀄리티 높게)".
옛 53×31 성채를 76×60 길드 성으로 새로 짓는다(체스 계급 = 길드 계급).

  겉: 어두운 돌 성벽(띠돌·버팀벽·흉벽과 총안·벽 밑 받침돌), 네 모서리 둥근 탑(고깔 지붕·깃발·좁은 창),
      앞 관문 탑(아치 문·올린 내리닫이 쇠창살·큰 톱니 시계·기사 문장·깃발 둘·꼭대기 흉벽과 깃대), 가운데 큰 홀은 높은 벽(위 창 줄)과 맞배지붕.
  안 아래층: 로비(룩 모양 접수대·의뢰판·계급판·걸상) → 큰 체스판 홀(8×8, 칸 4 — 큰 말, 가운데 길, 돌기둥, 세 면 회랑, 왕좌 단)
             왼 날개 = 훈련장(허수아비·무기 걸이·갑옷·과녁·겨루기 마당) / 오른 날개 = 쉼터(벽난로·안락의자·체스 탁자) + 식당(긴 탁자)
  위층: 로비 위 작전실(큰 지도 탁자·작은 말·벽 지도) · 왼 날개 기록 서고 · 오른 날개 길드장 방. 날개마다 바깥벽 따라 계단.
좌표: 블렌더 (x, y, z), 앞 = -y(연병장을 본다). 로블록스 로컬 = (-x, z, y).
"""
import math
import os
import sys

from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
from build_steam_obs import sphere, cone, arc_wall  # noqa: E402
from build_steam_inside import C, PROP, job, box2, lantern, arch_top, door_leaf_in, DOORWAY, CLEAR, fire_logs  # noqa: E402
from build_steam_school import chair, bookcase, books_row, green_lamp, BOOKS  # noqa: E402
from build_steam_under import hang_chandelier  # noqa: E402

R = math.radians
W, D, T = 76.0, 60.0, 1.2
X0, X1, Y0, Y1 = -W / 2, W / 2, -28.0, 32.0
IX0, IX1, IY0, IY1 = X0 + T, X1 - T, Y0 + T, Y1 - T        # ±36.8, -26.8..30.8
ZB, ZF, ZS, Z1, Z2, ZW = 2.0, 2.2, 15.4, 16.0, 28.0, 29.0
HX, HY0, ZH = 24.0, -16.0, 40.0                             # 홀 벽(x ±24), 로비/홀 벽(y -16), 홀 벽 윗면
TOWERS = ((-36.0, -26.0), (36.0, -26.0), (-36.0, 30.0), (36.0, 30.0))
RT = 5.5
GX, GY0, GY1 = 10.0, -34.0, -24.0                           # 관문 탑 x ±10, y -34..-24
CLOCK = (GY0 - 0.9, 41.0)                                   # 시계 판 앞면 y, 가운데 z (Snow_City2 바늘과 같아야 함)


def wall_holes(g, mat, axis, f0, f1, a0, a1, z0, z1, holes, coll=True):
    """구멍 난 벽: axis 'y' = y 로 뻗은 벽(x f0..f1), 'x' = x 로 뻗은 벽(y f0..f1). holes = [(a0, a1, hz0, hz1)].
    구멍 끝점마다 띠로 나눠, 띠마다 덮는 구멍 사이 높이만 쌓는다(보이는 것 + 충돌)"""
    cuts = sorted({a0, a1} | {h[0] for h in holes} | {h[1] for h in holes})
    for u0, u1 in zip(cuts, cuts[1:]):
        if u1 - u0 < 1e-3 or u0 < a0 or u1 > a1:
            continue
        zs = sorted((h[2], h[3]) for h in holes if h[0] <= u0 + 1e-6 and u1 <= h[1] + 1e-6)
        z = z0
        for hz0, hz1 in zs + [(z1, z1)]:
            if hz0 - z > 1e-3:
                if axis == "y":
                    box2(g, mat, f0, f1, u0, u1, z, hz0, coll)
                else:
                    box2(g, mat, u0, u1, f0, f1, z, hz0, coll)
            z = max(z, hz1)


def merlons(g, x0, y0, x1, y1, z, step=3.0, w=1.6, h=2.6, t=1.4, mat="Stone"):
    """흉벽 머리 줄(선분 위에 step 간격)"""
    ln = math.hypot(x1 - x0, y1 - y0)
    n = max(1, int(round(ln / step)))
    for k in range(n + 1):
        f = k / n
        if ln > 0 and abs(x1 - x0) >= abs(y1 - y0):
            g[mat].box(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, z + h / 2, w, t, h)
        else:
            g[mat].box(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, z + h / 2, t, w, h)


def corner_tower(g, cx, cy):
    """둥근 모서리 탑: 몸·띠·흉벽 고리·고깔 지붕·꼭대기·깃발·좁은 창(어두운 틈)"""
    zt = 38.0
    g["Stone"].cyl(cx, cy, 0.0, RT, RT * 0.94, zt, seg=24)
    for a in (0.0, math.pi / 4):          # 팔각(정사각 둘) — 방 모서리로 불룩 들어온 탑 몸에 맞춘다
        C(cx, cy, zt / 2, 2 * RT * 0.924, 2 * RT * 0.924, zt, a)
    for z in (ZS + 0.15, ZW + 0.35):      # 층 바닥 윗면 16.0 · 날개 지붕 눈 29.16 과 겹치지 않게(깜빡임)
        g["StoneTrim"].cyl(cx, cy, z, RT + 0.3, RT + 0.3, 0.8, seg=24)
    g["StoneTrim"].cyl(cx, cy, zt - 0.6, RT + 0.7, RT + 0.7, 1.0, seg=24)
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        g["Stone"].obox(cx + (RT + 0.2) * math.cos(a), cy + (RT + 0.2) * math.sin(a), zt + 1.5, 1.2, 1.8, 2.4, rz=a)
    cone(g, "RoofMetal", (cx, cy, zt + 0.4), (cx, cy, zt + 10.5), RT + 0.6, seg=20)
    cone(g, "SnowCap", (cx, cy, zt + 3.6), (cx, cy, zt + 10.6), (RT + 0.6) * 0.7 + 0.15, seg=20)
    sphere(g, "Brass", (cx, cy, zt + 10.8), 0.45, sub=1)
    g["Iron"].cyl(cx, cy, zt + 10.8, 0.08, 0.08, 3.4, seg=6)
    g["Banner"].box(cx + 0.9, cy, zt + 13.3, 1.8, 0.08, 1.0)
    out_y = -1 if cy < 0 else 1
    out_x = -1 if cx < 0 else 1
    for z in (9.0, 21.0):
        S.hole(g, cx, cy + out_y * RT, z, 0.7, 2.6, "-y" if out_y < 0 else "+y", 1.4, pane=False)
        S.hole(g, cx + out_x * RT, cy, z, 0.7, 2.6, "-x" if out_x < 0 else "+x", 1.4, pane=False)
        g["StoneTrim"].box(cx, cy + out_y * (RT + 0.2), z - 1.5, 1.4, 0.6, 0.3)
        g["StoneTrim"].box(cx + out_x * (RT + 0.2), cy, z - 1.5, 0.6, 1.4, 0.3)


def figuren_shell(g):
    # ── 받침 + 바닥(충돌)
    g["Stone"].box(0, (Y0 + Y1) / 2, ZB / 2, W + 2.4, D + 2.4, ZB)
    C(0, (Y0 + Y1) / 2, ZB / 2, W + 2.4, D + 2.4, ZB)
    for x0, x1, y0, y1 in ((X0 - 1.2, X1 + 1.2, Y0 - 1.2, Y0 - 0.6), (X0 - 1.2, X1 + 1.2, Y1 + 0.6, Y1 + 1.2),
                           (X0 - 1.2, X0 - 0.6, Y0 - 0.6, Y1 + 0.6), (X1 + 0.6, X1 + 1.2, Y0 - 0.6, Y1 + 0.6)):
        g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, ZB + 0.2, x1 - x0, y1 - y0, 0.4)
    # ── 바깥벽(앞: 관문 탑 자리 x ±10 비움)
    box2(g, "Stone", X0, X1, IY1, Y1, ZB, ZW)
    box2(g, "Stone", X0, IX0, IY0, IY1, ZB, ZW)
    box2(g, "Stone", IX1, X1, IY0, IY1, ZB, ZW)
    for x0, x1 in ((X0, -GX + 1.2), (GX - 1.2, X1)):
        box2(g, "Stone", x0, x1, Y0, IY0, ZB, ZW)
    # 띠돌(층 사이 · 처마) + 처마 밑 받침돌 줄(앞·옆)
    for z, h in ((ZS - 0.2, 0.8), (ZW - 0.8, 1.0)):
        for x0, x1, y0, y1 in ((X0 - 0.4, X1 + 0.4, Y0 - 0.4, Y0 + 0.4), (X0 - 0.4, X1 + 0.4, Y1 - 0.4, Y1 + 0.4),
                               (X0 - 0.4, X0 + 0.4, Y0 + 0.4, Y1 - 0.4), (X1 - 0.4, X1 + 0.4, Y0 + 0.4, Y1 - 0.4)):
            g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, z + h / 2, x1 - x0, y1 - y0, h)
    for x in [X0 + 6.0 + k * 1.6 for k in range(int((W - 12) / 1.6) + 1)]:
        if abs(x) < GX + 0.5:
            continue
        g["StoneTrim"].box(x, Y0 - 0.55, ZW - 1.2, 0.5, 0.7, 0.6)
    # 버팀벽(옆벽, 창 사이)
    for s in (-1, 1):
        for y in (-14.0, -6.0, 2.0, 10.0, 18.0):
            g["StoneTrim"].box(s * (X1 + 0.6), y, ZB + 10.0, 1.2, 1.6, 20.0)
            g["StoneTrim"].obox(s * (X1 + 0.35), y, ZB + 20.8, 0.7, 1.6, 2.4, ry=s * 0.4)
    # 흉벽(날개 지붕 둘레) + 지붕판(눈)
    merlons(g, X0 + 0.7, Y0 + 0.7, -GX - 0.5, Y0 + 0.7, ZW)
    merlons(g, GX + 0.5, Y0 + 0.7, X1 - 0.7, Y0 + 0.7, ZW)
    merlons(g, X0 + 0.7, Y1 - 0.7, -HX - 0.6, Y1 - 0.7, ZW)
    merlons(g, HX + 0.6, Y1 - 0.7, X1 - 0.7, Y1 - 0.7, ZW)
    for s in (-1, 1):
        merlons(g, s * (X1 - 0.7), Y0 + 6.0, s * (X1 - 0.7), Y1 - 6.0, ZW)
    for s in (-1, 1):
        x0, x1 = sorted((s * IX1, s * (HX + 0.5)))
        g["Stone"].box((x0 + x1) / 2, (IY0 + IY1) / 2, Z2 + 0.5, x1 - x0, IY1 - IY0, 1.0)
        g["SnowCap"].box((x0 + x1) / 2, (IY0 + IY1) / 2, ZW + 0.08, x1 - x0, IY1 - IY0, 0.16)
    g["Stone"].box(0, (IY0 + HY0) / 2 - 0.25, Z2 + 0.5, 2 * HX - 1.0, HY0 - IY0 - 0.5, 1.0)
    g["SnowCap"].box(0, (IY0 + HY0) / 2 - 0.25, ZW + 0.08, 2 * HX - 1.0, HY0 - IY0 - 0.5, 0.16)
    for t_ in TOWERS:
        corner_tower(g, *t_)
    # ── 큰 홀 벽 윗부분(날개 지붕 위로 ZW..ZH) + 앞 박공 벽 + 맞배지붕 + 위 창 줄(안팎)
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        box2(g, "Stone", x0, x1, HY0 - 0.5, Y1, ZW, ZH, coll=False)
        g["StoneTrim"].box(s * HX, (HY0 + Y1) / 2 - 0.25, ZH - 0.4, 1.6, Y1 - HY0 + 0.5, 0.8)
        for y in (-10.0, -2.0, 6.0, 14.0, 22.0):
            S.window(g, s * (HX + 0.5), y, ZW + 2.0, 2.4, 5.6, face="+x" if s > 0 else "-x", cross=True, frame="Timber", cut=1.0)
            S.window(g, s * (HX - 0.5), y, ZW + 2.0, 2.4, 5.6, face="-x" if s > 0 else "+x", cross=True, frame="Timber", sill=False, cut=1.0)
            g["StoneTrim"].box(s * (HX + 0.9), y, ZW + 9.0, 0.6, 3.4, 0.5)
    S.roof_gable(g, 0, (HY0 + Y1) / 2 - 0.25, ZH, 2 * HX + 1.6, Y1 - HY0 + 1.0, 9.0, along="y", gable="Stone")
    for y in (-8.0, 4.0, 16.0, 26.0):
        g["Timber"].box(0, y, ZH - 0.6, 2 * HX - 1.0, 0.8, 1.2)
        for s in (-1, 1):
            g["Timber"].obox(s * HX / 2, y, ZH + 4.0, 0.6, 0.6, math.hypot(HX, 9.0), ry=-s * math.atan2(HX, 9.0))
        g["Timber"].box(0, y, ZH + 4.4, 0.6, 0.6, 8.8)
    # 홀 뒷벽 윗부분(날개 지붕 위 ZW..ZH — 박공 세모 아래) — 장미창이 뚫린다
    box2(g, "Stone", -HX - 0.5, HX + 0.5, IY1, Y1, ZW, ZH, coll=False)
    g["StoneTrim"].box(0, Y1 + 0.2, ZH - 0.4, 2 * HX + 1.6, 0.8, 0.8)
    # 뒷벽 둥근 장미창(홀 위) + 큰 창 둘(회랑 뒤)
    rz_ = ZH - 7.0
    g["Cut"].hcyl(0, Y1 - T / 2, rz_, 3.6, T + 0.04, axis="y", seg=24)
    g["Pane"].hcyl(0, Y1 - T / 2, rz_, 3.6, 0.08, axis="y", seg=24)
    for yy in (Y1 + 0.15, IY1 - 0.15):
        L.transformed(g, Matrix.Translation((0, yy, rz_)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                      lambda q: S.ring(q, "Brass", 0, 0, -0.12, 3.5, 4.0, 0.24, n=28))
        for k in range(4):
            g["Brass"].obox(0, yy, rz_, 0.18, 0.2, 7.2, ry=k * math.pi / 4)
    for x in (-10.0, 10.0):
        S.window(g, x, Y1, Z1 + 2.5, 3.0, 8.0, face="+y", cross=True, frame="Timber")
        S.window(g, x, IY1, Z1 + 2.5, 3.0, 8.0, face="-y", cross=True, frame="Timber", sill=False)
    # ── 바깥 창(아래·위). 앞: 관문 탑·모서리 탑 자리 비움 / 옆: 계단 뒤(아래 y ≥ 9)는 비움 / 뒤: 날개만
    for x in (-27.5, -20.0, -14.0, 14.0, 20.0, 27.5):
        for z0, h in ((ZF + 2.4, 6.4), (Z1 + 2.0, 7.0)):
            S.window(g, x, Y0, z0, 2.8, h, face="-y", cross=True, frame="Timber")
            S.window(g, x, IY0, z0, 2.8, h, face="+y", cross=True, frame="Timber", sill=False)
            if z0 > Z1:
                arch_top(g, x, Y0, z0 + h, 1.4, T)
    for s in (-1, 1):
        for y in (-18.0, -10.0, -2.0, 6.0, 14.0, 21.0):
            for z0, h in ((ZF + 2.4, 6.4), (Z1 + 2.0, 7.0)):
                if z0 < Z1 and y > 3.0:    # 아래층 계단(y 4..22) 뒤 창은 비운다
                    continue
                S.window(g, s * X1, y, z0, 2.8, h, face="+x" if s > 0 else "-x", cross=True, frame="Timber")
                S.window(g, s * IX1, y, z0, 2.8, h, face="-x" if s > 0 else "+x", cross=True, frame="Timber", sill=False)
        for x in (s * 27.5,):
            for z0, h in ((ZF + 2.4, 6.4), (Z1 + 2.0, 7.0)):
                S.window(g, x, Y1, z0, 2.8, h, face="+y", cross=True, frame="Timber")
                S.window(g, x, IY1, z0, 2.8, h, face="-y", cross=True, frame="Timber", sill=False)
    gate_tower(g)


def gate_tower(g):
    """앞 관문 탑(x ±10, y -34..-24): 아치 문 + 올린 쇠창살 + 연 쇠문, 위 작전실 창, 기사 문장, 큰 톱니 시계, 꼭대기 흉벽·깃대, 깃발 둘"""
    zt = 50.0
    t = T
    # 앞벽(아치 문 x ±4 · 네모 높이 9 + 반원 4 — 꼭대기 15.2 가 위층 판 밑 15.4 아래) — 문 위 작전실 창은 창이 뚫는다
    for x0, x1, z0, z1 in ((-GX, -4.0, ZB, Z2), (4.0, GX, ZB, Z2), (-4.0, 4.0, ZF + 9.0, Z2)):
        box2(g, "Stone", x0, x1, GY0, GY0 + t, z0, z1)
    g["Cut"].hcyl(0, GY0 + t / 2, ZF + 9.0, 4.0, t + 0.04, axis="y", seg=24)
    for s in (-1, 1):
        box2(g, "Stone", *sorted((s * GX, s * (GX - t))), GY0 + t, GY1, ZB, Z2)
    # 위(지붕 위로): 속 찬 덩이 + 띠 + 흉벽 + 깃대
    g["Stone"].box(0, (GY0 + GY1) / 2, (Z2 + zt) / 2, 2 * GX, GY1 - GY0, zt - Z2)
    for z in (ZS - 0.2, ZW - 0.8, zt - 1.0):
        g["StoneTrim"].box(0, (GY0 + GY1) / 2, z + 0.5, 2 * GX + 0.8, GY1 - GY0 + 0.8, 1.0)
    for k in range(9):
        g["StoneTrim"].box(-GX + 1.0 + k * 2.25, GY0 - 0.6, zt - 1.6, 0.6, 0.8, 0.6)
    merlons(g, -GX + 0.7, GY0 + 0.7, GX - 0.7, GY0 + 0.7, zt, step=2.6)
    merlons(g, -GX + 0.7, GY1 - 0.7, GX - 0.7, GY1 - 0.7, zt, step=2.6)
    for s in (-1, 1):
        merlons(g, s * (GX - 0.7), GY0 + 3.0, s * (GX - 0.7), GY1 - 3.0, zt, step=2.6)
    g["Iron"].cyl(0, (GY0 + GY1) / 2, zt, 0.25, 0.2, 12.0, seg=8)
    g["Banner"].box(2.4, (GY0 + GY1) / 2, zt + 10.0, 4.6, 0.15, 3.0)
    g["Brass"].box(2.4, (GY0 + GY1) / 2 - 0.1, zt + 10.0, 1.2, 0.08, 1.2)
    sphere(g, "Brass", (0, (GY0 + GY1) / 2, zt + 12.2), 0.4, sub=1)
    # 아치 테 + 쐐기돌 + 올린 쇠창살 + 연 쇠문 + 문 앞 계단
    for s in (-1, 1):
        g["StoneTrim"].box(s * 4.5, GY0 - 0.35, ZF + 4.5, 1.0, 0.7, 9.0)
    half = [(4.5 * math.cos(math.pi * k / 10), 4.5 * math.sin(math.pi * k / 10)) for k in range(11)]
    for (ax0, az0), (ax1, az1) in zip(half, half[1:]):
        g["StoneTrim"].obox((ax0 + ax1) / 2, GY0 - 0.35, ZF + 9.0 + (az0 + az1) / 2, math.hypot(ax1 - ax0, az1 - az0) + 0.1, 0.7, 1.0,
                            ry=-math.atan2(az1 - az0, ax1 - ax0))
    g["StoneTrim"].box(0, GY0 - 0.5, ZF + 13.6, 1.4, 1.0, 1.4)
    # 올린 내리닫이 쇠창살(아치 안 위쪽, 끝이 머리 위 7.8 에)
    for k in range(9):
        x = -3.2 + k * 0.8
        top = ZF + 9.0 + math.sqrt(max(0.0, 4.0 ** 2 - x * x)) - 0.2
        g["Iron"].box(x, GY0 + t + 0.3, (ZF + 7.8 + top) / 2, 0.18, 0.18, top - ZF - 7.8)
        g["Iron"].box(x, GY0 + t + 0.3, ZF + 7.6, 0.12, 0.12, 0.4)
    for zz in (ZF + 8.4, ZF + 10.0, ZF + 11.6):
        g["Iron"].box(0, GY0 + t + 0.3, zz, 7.6, 0.16, 0.16)
    for s in (-1, 1):
        door_leaf_in(g, s * 3.9, GY0 + t + 0.6, ZF, 3.8, 8.8, 100.0, -s)
    for k, (yy, zz) in enumerate(((GY0 - 1.6, (ZB + 0.2) * 2 / 3), (GY0 - 3.2, (ZB + 0.2) / 3), (GY0 - 4.8, 0.2))):
        g["Stone"].box(0, yy, zz / 2, 12.0 + k * 1.6, 1.6, zz)
        C(0, yy, zz / 2, 12.0 + k * 1.6, 1.6, zz)
    g["Stone"].box(0, GY0 - 0.4, ZB / 2, 2 * GX + 1.0, 1.0, ZB)
    C(0, GY0 + 1.0, (ZB + 0.2) / 2, 2 * GX, 4.0, ZB + 0.2)
    # 관문 탑 위층 창(작전실) + 반원 머리
    S.window(g, 0, GY0, Z1 + 2.4, 4.4, 6.6, face="-y", cross=True, frame="Timber")
    S.window(g, 0, GY0 + t, Z1 + 2.4, 4.4, 6.6, face="+y", cross=True, frame="Timber", sill=False)
    arch_top(g, 0, GY0, Z1 + 9.0, 2.2, t)
    # 기사 문장(큰 체스 기사 말, 돌 받침 위) + 깃발 둘 + 문 등 둘
    g["StoneTrim"].box(0, GY0 - 1.2, Z2 + 0.2, 4.0, 2.4, 0.6)
    g["Stone"].box(0, GY0 - 0.8, Z2 - 0.8, 2.6, 1.6, 1.6)
    PROP("Chess_Knight", 0, GY0 - 1.2, Z2 + 0.5, 180.0, 2.4, col="Brass")
    for s in (-1, 1):
        g["Brass"].box(s * 7.0, GY0 - 0.3, Z2 - 1.0, 4.0, 0.3, 0.3)
        g["Banner"].box(s * 7.0, GY0 - 0.25, Z2 - 9.0, 3.4, 0.15, 15.6)
        g["SignGold"].box(s * 7.0, GY0 - 0.35, Z2 - 6.0, 1.6, 0.05, 1.6)
        g["Iron"].box(s * 6.4, GY0 - 0.6, ZF + 7.6, 0.3, 1.0, 0.3)
        g["Iron"].cyl(s * 6.4, GY0 - 1.1, ZF + 6.4, 0.4, 0.5, 1.2, seg=8)
        g["Glow"].box(s * 6.4, GY0 - 1.1, ZF + 7.8, 0.55, 0.55, 0.9)
        g["LampPt"].box(s * 6.4, GY0 - 1.6, ZF + 7.8, 0.3, 0.3, 0.3)
    # 큰 톱니 시계(바늘은 Snow_City2 가 단다: CLOCK)
    cy, cz = CLOCK
    S.gear(g, "Brass", 0, GY0 - 0.4, cz, 6.0, 24, 0.8)
    g["Dial"].hcyl(0, cy + 0.05, cz, 4.2, 0.1, axis="y", seg=32)
    for k in range(12):
        a = 2 * math.pi * k / 12
        g["Iron"].box(3.6 * math.cos(a), cy - 0.02, cz + 3.6 * math.sin(a), 0.4 if k % 3 else 0.6, 0.06, 0.4 if k % 3 else 0.6)


# ------------------------------------------------------------------ 안
def figuren_in(g):
    figuren_shell(g)
    # ── 안쪽 벽: 로비/홀(y -16, 아래 큰 문 x ±5 · 위 작전실 문 x ±3) · 홀/날개(x ±24, 문 넷)
    wall_holes(g, "Stone", "x", HY0 - 0.5, HY0 + 0.5, -HX + 0.5, HX - 0.5, ZF, ZH,
               [(-5.0, 5.0, ZF, ZF + 10.0), (-3.0, 3.0, Z1, Z1 + 8.0)])
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        wall_holes(g, "Stone", "y", x0, x1, IY0, IY1, ZF, ZW,
                   [(-24.0, -20.0, ZF, ZF + 8.0), (4.0, 8.0, ZF, ZF + 8.0), (-24.0, -20.0, Z1, Z1 + 8.0), (0.0, 4.0, Z1, Z1 + 8.0)])
        for yy, zz in ((-22.0, ZF), (6.0, ZF), (-22.0, Z1), (2.0, Z1)):
            g["StoneTrim"].box(s * HX, yy, zz + 8.3, 1.4, 4.8, 0.6)
    for x in (-4.2, 4.2):
        g["StoneTrim"].box(x * 1.0 + (0.8 if x > 0 else -0.8), HY0, ZF + 5.0, 0.8, 1.4, 10.0)
    g["StoneTrim"].box(0, HY0, ZF + 10.4, 11.6, 1.4, 0.8)
    lobby(g)
    great_hall(g)
    war_room(g)
    for s in (-1, 1):
        wing(g, s)
    # 문·계단 비울 자리(문 앞뒤 2.5)
    DOORWAY(-4.0, 4.0, GY0, GY0 + T, ZF, 9.0)
    DOORWAY(-5.0, 5.0, HY0 - 0.5, HY0 + 0.5, ZF, 10.0)
    DOORWAY(-3.0, 3.0, HY0 - 0.5, HY0 + 0.5, Z1, 8.0)
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        for y0, y1, z in ((-24.0, -20.0, ZF), (4.0, 8.0, ZF), (-24.0, -20.0, Z1), (0.0, 4.0, Z1)):
            DOORWAY(x0, x1, y0, y1, z, 8.0)
        xa, xb = sorted((s * IX1, s * (IX1 - 4.0)))
        CLEAR(xa + 0.7, xb - 0.7, 1.5, 3.9, ZF + 0.15, ZF + 5.8)
        CLEAR(xa + 0.7, xb - 0.7, 22.1, 24.3, Z1 + 0.15, Z1 + 5.8)


def potted_plant(g, x, y, z0, h=3.0):
    """화분(놋쇠 단지 + 잎 덩이)"""
    g["Brass"].cyl(x, y, z0, 0.6, 0.8, 1.4, seg=12)
    g["Soot"].cyl(x, y, z0 + 1.35, 0.7, 0.7, 0.1, seg=12)
    for k in range(5):
        a = k * 1.26
        sphere(g, "Felt", (x + 0.45 * math.cos(a), y + 0.45 * math.sin(a), z0 + 1.6 + h * 0.25 + (k % 2) * 0.5), 0.55, sub=1)
    sphere(g, "Felt", (x, y, z0 + 1.6 + h * 0.5), 0.6, sub=1)
    C(x, y, z0 + 1.0, 1.6, 1.6, 2.0)


def sofa(g, x, y, z0, rz, ln=5.0, mat="Leather"):
    """긴 소파(앉는 쪽 = 로컬 -v)"""
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g[mat].obox(x, y, z0 + 0.9, ln, 2.2, 1.0, rz=rz)
    g[mat].obox(*P(0, 0.85), z0 + 2.2, ln, 0.5, 1.8, rz=rz)
    for u in (-1, 1):
        g[mat].obox(*P(u * (ln / 2 - 0.25), 0), z0 + 1.7, 0.5, 2.2, 0.8, rz=rz)
    for u in (-1, 1):
        for v in (-0.8, 0.8):
            g["Wood"].obox(*P(u * (ln / 2 - 0.4), v), z0 + 0.2, 0.25, 0.25, 0.4, rz=rz)
    C(x, y, z0 + 1.4, ln if abs(s) < 0.5 else 2.3, 2.3 if abs(s) < 0.5 else ln, 2.8)


def lobby(g):
    """현관 로비(x ±24, y -26.8..-16) + 관문 탑 아래(x ±8.8, y -32.8..-26.8): 체크 바닥 · 붉은 길 · 의뢰판(오른 홀 쪽 벽) ·
    길드 알림판·마을 지도(왼 홀 쪽 벽) · 걸상 넷 · 화분 · 샹들리에 셋. (말은 두지 않는다 — 사용자 2026-10-10)"""
    for i in range(24):
        for j in range(5):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(-23.0 + i * 2.0, IY0 + 1.0 + j * 2.0, ZF + 0.03, 2.0, 2.0, 0.06)
    g["Banner"].box(0, (GY0 + HY0) / 2 + 0.5, ZF + 0.1, 5.0, HY0 - GY0 - 2.0, 0.04)
    box2(g, "Wood", -HX + 0.5, HX - 0.5, IY0, HY0 - 0.5, ZS, Z1)
    box2(g, "Wood", -GX + T, GX - T, GY0 + T, IY0, ZS, Z1)
    for x in (-18.0, -10.0, 10.0, 18.0):
        g["Timber"].box(x, (IY0 + HY0) / 2, ZS - 0.35, 0.8, HY0 - IY0, 0.7)
    # 의뢰판(오른쪽, 홀 쪽 벽 앞면): 나무 판 + 쪽지 격자 + 놋쇠 머리판
    qx0, qx1, qz0, qz1 = 7.0, 21.0, ZF + 2.4, ZF + 9.4
    g["Timber"].box((qx0 + qx1) / 2, HY0 - 0.62, (qz0 + qz1) / 2, qx1 - qx0, 0.2, qz1 - qz0)
    g["Brass"].box((qx0 + qx1) / 2, HY0 - 0.7, qz1 + 0.4, qx1 - qx0 + 0.6, 0.15, 0.8)
    g["SignRed"].box((qx0 + qx1) / 2, HY0 - 0.78, qz1 + 0.4, qx1 - qx0 - 1.0, 0.05, 0.5)
    for r in range(4):
        for c in range(9):
            if (r * 5 + c * 3) % 7 == 0:
                continue
            x = qx0 + 1.0 + c * 1.5
            z = qz1 - 1.1 - r * 1.6
            g["Canvas"].obox(x, HY0 - 0.74, z, 1.1, 0.03, 1.3, ry=0.06 * ((r + c) % 3 - 1))
            g["Brass"].box(x, HY0 - 0.77, z + 0.55, 0.12, 0.03, 0.12)
            g[BOOKS[(r + c) % 4]].box(x - 0.3, HY0 - 0.77, z - 0.3, 0.3, 0.02, 0.2)
    # 길드 알림판 + 마을 지도(왼쪽 홀 쪽 벽)
    g["Timber"].box(-14.0, HY0 - 0.62, ZF + 5.9, 14.0, 0.2, 7.0)
    g["Brass"].box(-14.0, HY0 - 0.7, ZF + 9.8, 14.6, 0.15, 0.8)
    g["SignBlue"].box(-14.0, HY0 - 0.78, ZF + 9.8, 13.0, 0.05, 0.5)
    g["Canvas"].box(-17.5, HY0 - 0.74, ZF + 5.9, 6.0, 0.03, 5.2)
    for k in range(10):
        g[("SignTeal", "Felt", "SignBlue")[k % 3]].box(-19.6 + (k % 5) * 1.0, HY0 - 0.76, ZF + 4.4 + (k // 5) * 2.2, 0.8, 0.02, 1.4)
    for k in range(6):
        g["Canvas"].obox(-12.4 + (k % 3) * 2.2, HY0 - 0.74, ZF + 7.2 - (k // 3) * 2.6, 1.6, 0.03, 2.0, ry=0.05 * (k % 2))
        g["Brass"].box(-12.4 + (k % 3) * 2.2, HY0 - 0.77, ZF + 8.1 - (k // 3) * 2.6, 0.12, 0.03, 0.12)
    # 걸상 넷(앞벽 아래 창 사이) · 화분 넷 · 샹들리에
    for x in (-17.0, 17.0):
        for dx in (-3.2, 3.2):
            xx = x + dx
            g["Wood"].box(xx, IY0 + 0.9, ZF + 1.4, 4.0, 1.0, 0.2)
            g["Wood"].box(xx, IY0 + 0.45, ZF + 2.3, 4.0, 0.15, 1.6)
            for e in (-1.7, 1.7):
                g["Iron"].box(xx + e, IY0 + 0.9, ZF + 0.7, 0.2, 0.9, 1.4)
            C(xx, IY0 + 0.9, ZF + 1.0, 4.0, 1.2, 2.0)
    for x, y in ((-22.4, -25.6), (22.4, -25.6), (-22.4, HY0 - 1.6), (22.4, HY0 - 1.6)):
        potted_plant(g, x, y, ZF)
    for x in (-12.0, 12.0):
        hang_chandelier(g, x, (IY0 + HY0) / 2, ZS, ZF + 9.2, 2.0)
    hang_chandelier(g, 0, (GY0 + HY0) / 2, ZS, ZF + 10.6, 1.6)


SQ = 3.6          # 큰 홀 바닥 체스판 칸(말은 두지 않는다 — 길드 문장 바닥)
GIN = 17.0        # 옆 회랑 안쪽 끝(2026-10-10 사용자: 2층 안쪽 복도를 넓게 → 폭 6.5)
GDEP = 6.0        # 앞·뒤 회랑 깊이


def great_hall(g):
    """큰 홀 = 길드 큰 로비(사용자 2026-10-10: 기물 없애고 메인 로비처럼): 체스판 문장 바닥 · 가운데 둥근 화단과 둘레 걸상 ·
    소파 자리 넷 · 뒤 접수대(길드 문장 벽) · 옆벽 의뢰판 둘 · 화분 · 돌기둥 여덟 · 세 면 넓은 회랑 · 샹들리에 셋"""
    hx0, hx1, hy0, hy1 = -HX + 0.5, HX - 0.5, HY0 + 0.5, IY1
    g["Stone"].box(0, (hy0 + hy1) / 2, ZF + 0.02, hx1 - hx0, hy1 - hy0, 0.04)
    cy0, half = 7.0, 4 * SQ
    for i in range(8):
        for j in range(8):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(-half + SQ / 2 + SQ * i, cy0 - half + SQ / 2 + SQ * j, ZF + 0.07, SQ, SQ, 0.06)
    e = half + 0.4
    for x0, x1, y0, y1 in ((-e, e, cy0 - e, cy0 - half), (-e, e, cy0 + half, cy0 + e), (-e, -half, cy0 - half, cy0 + half), (half, e, cy0 - half, cy0 + half)):
        box2(g, "Brass", x0, x1, y0, y1, ZF, ZF + 0.12, coll=False)
    # 가운데 둥근 화단(돌 테 + 흙 + 잎) + 둘레 둥근 걸상(여덟 토막)
    g["StoneTrim"].cyl(0, cy0, ZF, 3.0, 3.0, 1.6, seg=24)
    g["Soot"].cyl(0, cy0, ZF + 1.6, 2.7, 2.7, 0.06, seg=24)
    for k in range(9):
        a = k * 0.7
        rr = 1.6 if k < 8 else 0.0
        sphere(g, "Felt", (rr * math.cos(a), cy0 + rr * math.sin(a), ZF + 2.4 + (k % 3) * 0.5), 0.9 if k < 8 else 1.2, sub=1)
    g["Brass"].cyl(0, cy0, ZF + 1.6, 0.25, 0.25, 4.6, seg=8)
    S.gear(g, "Brass", 0, cy0, ZF + 6.6, 1.2, 12, 0.2, axis="y")
    C(0, cy0, ZF + 1.2, 6.0, 6.0, 2.4)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        bx, by = 4.0 * math.cos(a), cy0 + 4.0 * math.sin(a)
        g["Wood"].obox(bx, by, ZF + 1.45, 2.6, 1.0, 0.25, rz=a + math.pi / 2)
        g["Iron"].obox(bx, by, ZF + 0.65, 2.2, 0.6, 1.3, rz=a + math.pi / 2)
    for k in range(8):
        a = 2 * math.pi * k / 8
        C(4.0 * math.cos(a), cy0 + 4.0 * math.sin(a), ZF + 0.8, 3.2, 1.1, 1.6, a + math.pi / 2)
    # 소파 자리 넷(판 양쪽 앞·뒤): 마주 보는 소파 둘 + 낮은 탁자 + 깔개
    for sx in (-1, 1):
        for yc in (cy0 - 6.6, cy0 + 6.6):
            xc = sx * 10.2
            g["Banner"].box(xc, yc, ZF + 0.14, 6.6, 7.4, 0.04)
            for side in (-1, 1):
                sofa(g, xc, yc + side * 2.6, ZF, 0.0 if side > 0 else math.pi, ln=5.0)
            g["Wood"].box(xc, yc, ZF + 1.0, 3.0, 1.6, 0.2)
            for ux in (-1.3, 1.3):
                for uy in (-0.6, 0.6):
                    g["Wood"].box(xc + ux, yc + uy, ZF + 0.45, 0.2, 0.2, 0.9)
            C(xc, yc, ZF + 0.55, 3.0, 1.6, 1.1)
            g["Brass"].cyl(xc - 0.6, yc, ZF + 1.1, 0.2, 0.15, 0.4, seg=8)
            g["Canvas"].obox(xc + 0.6, yc + 0.1, ZF + 1.12, 0.9, 0.6, 0.04, rz=0.3)
    # 돌기둥 여덟(넓힌 회랑 안쪽 가장자리 x ±17)
    for s in (-1, 1):
        for y in (hy0 + GDEP, 2.0, 13.5, hy1 - GDEP):
            x = s * GIN
            g["Stone"].cyl(x, y, ZF, 1.1, 1.0, ZS - ZF, seg=16)
            g["StoneTrim"].cyl(x, y, ZF, 1.5, 1.5, 1.0, seg=16)
            g["StoneTrim"].cyl(x, y, ZS - 1.2, 1.1, 1.6, 1.2, seg=16)
            C(x, y, (ZF + ZS) / 2, 2.2, 2.2, ZS - ZF)
            g["Stone"].cyl(x, y, Z1 + 3.4, 0.7, 0.7, ZH - Z1 - 3.4, seg=12)
            g["Iron"].box(x - s * 1.1, y, ZF + 8.0, 0.6, 0.5, 0.8)
            g["Iron"].cyl(x - s * 1.5, y, ZF + 8.0, 0.25, 0.35, 1.0, seg=8)
            g["Glow"].box(x - s * 1.5, y, ZF + 9.4, 0.4, 0.4, 0.8)
            g["LampPt"].box(x - s * 2.0, y, ZF + 9.4, 0.3, 0.3, 0.3)
    # 넓은 회랑(옆 둘 6.5 · 앞·뒤 6) + 난간
    for s in (-1, 1):
        x0, x1 = sorted((s * GIN, s * (HX - 0.5)))
        box2(g, "Wood", x0, x1, hy0, hy1, ZS, Z1)
    box2(g, "Wood", -GIN, GIN, hy0, hy0 + GDEP, ZS, Z1)
    box2(g, "Wood", -GIN, GIN, hy1 - GDEP, hy1, ZS, Z1)
    g["StoneTrim"].box(0, hy0 + GDEP, ZS - 0.2, 2 * GIN, 0.5, 0.4)
    g["StoneTrim"].box(0, hy1 - GDEP, ZS - 0.2, 2 * GIN, 0.5, 0.4)
    for s in (-1, 1):
        g["StoneTrim"].box(s * GIN, (hy0 + hy1) / 2, ZS - 0.2, 0.5, hy1 - hy0, 0.4)
    rails = [((-GIN, hy0 + GDEP), (GIN, hy0 + GDEP)), ((-GIN, hy1 - GDEP), (GIN, hy1 - GDEP)),
             ((-GIN, hy0 + GDEP), (-GIN, hy1 - GDEP)), ((GIN, hy0 + GDEP), (GIN, hy1 - GDEP))]
    for (x0, y0), (x1, y1) in rails:
        ln = math.hypot(x1 - x0, y1 - y0)
        n = int(ln / 0.9)
        for k in range(n + 1):
            f = k / n
            g["Iron"].cyl(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, Z1, 0.07, 0.07, 3.0, seg=5)
        g["Brass"].box((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 3.05, max(abs(x1 - x0), 0.25), max(abs(y1 - y0), 0.25), 0.22)
        C((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 1.6, max(abs(x1 - x0), 0.3), max(abs(y1 - y0), 0.3), 3.2)
    for s in (-1, 1):
        for k, y in enumerate((-4.0, 8.0, 19.0)):
            g[("Banner", "SignBlue", "SignPurple")[k]].box(s * (GIN - 0.1), y, Z1 - 4.6, 0.1, 3.6, 8.6)
            g["SignGold"].box(s * (GIN - 0.16), y, Z1 - 2.6, 0.05, 1.4, 1.4)
            g["Brass"].box(s * (GIN - 0.15), y, Z1 - 0.2, 0.2, 4.0, 0.2)
    # 뒤 접수대(뒤 회랑 밑): 단 + 둥근 앞판 계산대(놋쇠 윗판) + 뒤 직원 칸 4 + 문장 벽 + 장부·종·등
    box2(g, "Stone", -10.0, 10.0, hy1 - GDEP + 0.4, hy1, ZF, ZF + 0.6)
    C(0, hy1 - (GDEP - 0.4) / 2, ZF + 0.3, 20.0, GDEP - 0.4, 0.6)
    zr = ZF + 0.6
    dy = hy1 - GDEP + 1.2
    g["Wood"].box(0, dy, zr + 1.5, 14.0, 1.4, 3.0)
    g["Brass"].box(0, dy, zr + 3.08, 14.4, 1.7, 0.16)
    for k in range(7):
        g["Timber"].box(-6.0 + k * 2.0, dy - 0.72, zr + 1.5, 1.6, 0.06, 2.4)
    C(0, dy, zr + 1.5, 14.4, 1.7, 3.0)
    for s in (-1, 1):
        g["Wood"].box(s * 7.6, dy + 1.4, zr + 1.5, 1.4, 4.2, 3.0)
        C(s * 7.6, dy + 1.4, zr + 1.5, 1.4, 4.2, 3.0)
    sphere(g, "Brass", (-3.0, dy, zr + 3.4), 0.25, sub=1)
    g["Leather"].obox(2.0, dy, zr + 3.25, 1.4, 1.0, 0.18, rz=0.15)
    green_lamp(g, 5.0, dy, zr + 3.16)
    g["Banner"].box(0, hy1 - 0.15, ZF + 7.6, 12.0, 0.15, 13.0)
    S.gear(g, "Brass", 0, hy1 - 0.3, ZF + 9.5, 3.0, 20, 0.3, axis="y")
    g["SignGold"].box(0, hy1 - 0.35, ZF + 9.5, 1.8, 0.06, 1.8)
    for s in (-1, 1):
        g["Wood"].box(s * 6.5, hy1 - 0.6, zr + 3.0, 4.0, 1.0, 6.0)
        for zz in (1.0, 2.6, 4.2):
            for k in range(4):
                g["Brass"].box(s * 6.5 - 1.4 + k * 0.95, hy1 - 1.12, zr + zz + 0.5, 0.6, 0.04, 0.5)
        C(s * 6.5, hy1 - 0.6, zr + 3.0, 4.0, 1.0, 6.0)
    # 옆벽 의뢰판 둘(회랑 밑, 홀↔날개 문 y 4..8 피해 y 12..22)
    for s in (-1, 1):
        xw = s * (HX - 0.62)
        g["Timber"].box(xw, 17.0, ZF + 5.6, 0.2, 9.0, 6.0)
        g["Brass"].box(xw - s * 0.08, 17.0, ZF + 8.9, 0.15, 9.6, 0.7)
        for r in range(3):
            for c in range(5):
                if (r + c * 2) % 5 == 0:
                    continue
                g["Canvas"].obox(xw - s * 0.12, 13.6 + c * 1.7, ZF + 7.4 - r * 1.8, 0.03, 1.2, 1.4, rx=0.05 * (c % 2))
                g["Brass"].box(xw - s * 0.15, 13.6 + c * 1.7, ZF + 8.0 - r * 1.8, 0.03, 0.12, 0.12)
    # 화분(구석·기둥 사이) + 샹들리에 셋
    for x, y in ((-21.5, hy0 + 1.6), (21.5, hy0 + 1.6), (-21.5, hy1 - 7.6), (21.5, hy1 - 7.6), (-14.0, 22.0), (14.0, 22.0)):
        potted_plant(g, x, y, ZF)
    for y in (-2.0, 10.0, 21.0):
        hang_chandelier(g, 0, y, ZH - 1.0, Z1 + 8.0, 3.2)


def war_room(g):
    """작전실(로비 위, x ±23.5, y -26.8..-16.5 + 관문 탑 위층 y -32.8..-26.8): 큰 지도 탁자는 탑 쪽 안으로 들여 문(y -16)을 비운다.
    탁자(12×5) · 의자 여덟 · 벽 지도 둘 · 서류장 넷(옆벽) · 샹들리에"""
    z0 = Z1
    box2(g, "Wood", -HX + 0.5, HX - 0.5, IY0, HY0 - 0.5, Z2, Z2 + 0.5, coll=False)
    tx, ty = 0.0, -25.0
    g["Banner"].box(tx, ty, z0 + 0.04, 18.0, 9.0, 0.06)
    g["Wood"].box(tx, ty, z0 + 2.7, 12.0, 5.0, 0.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Wood"].box(tx + sx * 5.5, ty + sy * 2.1, z0 + 1.25, 0.6, 0.6, 2.5)
    g["Canvas"].box(tx, ty, z0 + 2.93, 11.2, 4.4, 0.04)
    for i in range(11):
        for j in range(4):
            if (i * 3 + j * 5) % 4 == 0:
                g[("SignTeal", "SignBlue", "Felt")[(i + j) % 3]].box(tx - 5.0 + i, ty - 1.5 + j, z0 + 2.96, 0.9, 0.9, 0.02)
    for k, (kind, col) in enumerate((("Knight", "Iron"), ("Rook", "Brass"), ("Pawn", "Iron"), ("Bishop", "Brass"),
                                     ("Queen", "Iron"), ("Pawn", "Brass"), ("King", "Brass"), ("Knight", "Brass"))):
        PROP("Chess_" + kind, tx - 4.4 + k * 1.25, ty - 1.2 + (k % 3) * 1.1, z0 + 2.97, 0.0 if col == "Brass" else 180.0, 0.35, col=col)
    for k in range(3):
        g["Brass"].obox(tx + 1.5 + k * 1.0, ty + 1.4, z0 + 3.0, 0.08, 1.2, 0.05, rz=0.4 * k)
    C(tx, ty, z0 + 1.45, 12.0, 5.0, 2.9)
    for k in range(3):
        for sy in (-1, 1):
            chair(g, tx - 4.0 + k * 4.0, ty + sy * 3.6, z0, rz=0.0 if sy > 0 else math.pi, mat="Leather")
    for sx in (-1, 1):
        chair(g, tx + sx * 7.4, ty, z0, rz=-sx * math.pi / 2, mat="Leather")
    # 벽 지도 둘(옆벽) + 서류장 넷(옆벽 따라 — 문 y -24..-20 피함)
    for s in (-1, 1):
        g["Canvas"].box(s * (HX - 0.62), -18.6, z0 + 6.0, 0.05, 3.6, 3.6)
        g["SignTeal"].box(s * (HX - 0.65), -18.6, z0 + 6.0, 0.03, 3.0, 3.0)
        for k, x in enumerate((s * 14.0, s * 17.4)):
            g["Wood"].box(x, IY0 + 0.7, z0 + 2.6, 2.8, 1.2, 5.2)
            for zz in (1.0, 2.4, 3.8):
                g["Brass"].box(x, IY0 + 1.32, z0 + zz, 0.8, 0.04, 0.12)
            C(x, IY0 + 0.7, z0 + 2.6, 2.8, 1.2, 5.2)
    for x in (-12.0, 12.0):
        hang_chandelier(g, x, -21.0, Z2, z0 + 8.4, 1.8)
    hang_chandelier(g, 0, ty, Z2, z0 + 8.4, 1.4)


def stair(g, s):
    """날개 바깥벽 따라 계단(y 4 → 22, 21 단 — 꼭대기가 뒤 모서리 탑 몸(반지름 5.5)에 닿지 않게) + 열린 쪽 난간 + 위 구멍 둘레 난간"""
    x_out, x_in = s * IX1, s * (IX1 - 4.0)
    xa, xb = sorted((x_out, x_in))
    n, ya, yb = 21, 4.0, 22.0
    run, rise = (yb - ya) / n, (Z1 - ZF) / n
    for i in range(n):
        y0 = ya + i * run
        box2(g, "Stone" if i % 2 else "StoneTrim", xa, xb, y0, y0 + run, ZF, ZF + (i + 1) * rise)
        g["Banner"].box((xa + xb) / 2, y0 + run / 2, ZF + (i + 1) * rise + 0.02, 2.6, run, 0.04)
    ln, ang = math.hypot(yb - ya, Z1 - ZF), math.atan2(Z1 - ZF, yb - ya)
    for k in range(12):
        yy = ya + 0.5 + k * (yb - ya - 1.0) / 11
        zz = ZF + (yy - ya) / (yb - ya) * (Z1 - ZF)
        g["Iron"].cyl(x_in, yy, zz, 0.07, 0.07, 3.0, seg=5)
    g["Brass"].obox(x_in, (ya + yb) / 2, (ZF + Z1) / 2 + 3.1, 0.2, ln, 0.2, rx=ang)
    C(x_in, (ya + yb) / 2, (ZF + Z1) / 2 + 1.5, 0.3, yb - ya, Z1 - ZF + 3.0)
    # 위층 판(계단 구멍 비움) + 구멍 둘레 난간
    x_hall = s * (HX + 0.5)
    xh0, xh1 = sorted((x_in, x_hall))
    box2(g, "Wood", xh0, xh1, IY0, IY1, ZS, Z1)
    box2(g, "Wood", xa, xb, IY0, ya, ZS, Z1)
    box2(g, "Wood", xa, xb, yb, IY1, ZS, Z1)
    for (x0, y0), (x1, y1) in (((x_in, ya), (x_in, yb)), ((xa, ya), (xb, ya))):
        lnr = math.hypot(x1 - x0, y1 - y0)
        for k in range(int(lnr / 0.9) + 1):
            f = k / max(1, int(lnr / 0.9))
            g["Iron"].cyl(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, Z1, 0.07, 0.07, 3.0, seg=5)
        g["Brass"].box((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 3.05, max(abs(x1 - x0), 0.25), max(abs(y1 - y0), 0.25), 0.22)
        C((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 1.6, max(abs(x1 - x0), 0.3), max(abs(y1 - y0), 0.3), 3.2)
    for zz in (ZS - 0.5,):
        for xx in [xh0 + 3.0 + k * 4.0 for k in range(3)]:
            g["Timber"].box(xx, (IY0 + IY1) / 2, zz, 0.6, IY1 - IY0, 0.6)


def dummy(g, x, y, z0):
    """폰 모양 허수아비(나무 기둥 + 자루 몸 + 둥근 머리 + 받침)"""
    g["Iron"].cyl(x, y, z0, 0.9, 1.0, 0.4, seg=12)
    g["Timber"].cyl(x, y, z0 + 0.4, 0.15, 0.15, 3.0, seg=6)
    g["Canvas"].cyl(x, y, z0 + 1.6, 0.8, 0.6, 2.2, seg=10)
    g["Canvas"].cyl(x, y, z0 + 3.8, 0.55, 0.7, 0.3, seg=10)
    sphere(g, "Canvas", (x, y, z0 + 4.6), 0.55, sub=1)
    g["Leather"].box(x, y - 0.5, z0 + 2.6, 1.2, 0.1, 0.25)
    C(x, y, z0 + 2.6, 1.8, 1.8, 5.2)


def wing(g, s):
    """날개(s = -1 왼 / +1 오른): 계단 + 아래(왼 훈련장 / 오른 쉼터·식당) + 위(왼 기록 서고 / 오른 길드장 방) + 등"""
    stair(g, s)
    xo, xh = s * IX1, s * (HX + 0.5)          # 바깥벽 안면, 홀 벽 겉면
    xmid = (xo + xh) / 2

    def X(u):                                  # u: 홀 벽(0) → 바깥벽(12.3) 거리 → x
        return xh + s * u
    if s < 0:
        # ── 아래: 훈련장 — 허수아비 여섯 · 무기 걸이(홀 벽) · 과녁(앞벽) · 겨루기 마당(밧줄) · 갑옷 둘
        for k, (u, y) in enumerate(((4.0, -16.0), (7.5, -16.0), (4.0, -10.5), (7.5, -10.5), (10.0, -22.5), (10.0, -16.0))):
            dummy(g, X(u), y, ZF)
        ry0, ry1 = -6.0, 1.5
        for u in (2.0, 8.0):
            for y in (ry0, ry1):
                g["Iron"].cyl(X(u), y, ZF, 0.2, 0.2, 3.4, seg=6)
                C(X(u), y, ZF + 1.7, 0.4, 0.4, 3.4)
        for zz in (ZF + 1.6, ZF + 2.8):
            for (u0, y0), (u1, y1) in (((2.0, ry0), (8.0, ry0)), ((2.0, ry1), (8.0, ry1)), ((8.0, ry0), (8.0, ry1))):
                x0, x1 = X(u0), X(u1)
                g["Canvas"].box((x0 + x1) / 2, (y0 + y1) / 2, zz, max(abs(x1 - x0), 0.1), max(abs(y1 - y0), 0.1), 0.1)
        g["Banner"].box(X(5.25), (ry0 + ry1) / 2, ZF + 0.08, 6.4, 7.4, 0.12)
        for k in range(4):
            PROP("Steam_Rifle", xh + s * 0.75, -12.0 + k * 1.8, ZF + 4.2 + (k % 2) * 1.6, 90.0 * s * -1, 1.0)
        g["Timber"].box(xh + s * 0.45, -9.3, ZF + 5.0, 0.3, 8.0, 4.4)
        g["Timber"].hcyl(X(6.0), IY0 + 0.5, ZF + 5.0, 2.0, 0.3, axis="y", seg=20)
        for k, (rr, mat) in enumerate(((1.6, "Canvas"), (1.1, "SignRed"), (0.6, "Canvas"), (0.25, "SignRed"))):
            g[mat].hcyl(X(6.0), IY0 + 0.68 + k * 0.02, ZF + 5.0, rr, 0.04, axis="y", seg=20)
        # ── 위: 기록 서고 — 벽 책장 · 큰 장부 받침 · 탁자 둘
        z0 = Z1
        for y0, y1 in ((-26.4, -21.0), (-15.0, -12.6), (-7.0, -4.6), (1.0, 3.4)):
            bookcase(g, xo, y0, y1, z0, 9.0, -s, levels=6, seed=int(y0) + 40)
        for y in (-18.0, -6.0):
            g["Wood"].box(X(6.0), y, z0 + 2.7, 3.0, 5.0, 0.25)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    g["Wood"].box(X(6.0) + sx * 1.2, y + sy * 2.1, z0 + 1.3, 0.3, 0.3, 2.6)
            C(X(6.0), y, z0 + 1.4, 3.0, 5.0, 2.8)
            green_lamp(g, X(6.0), y - 1.4, z0 + 2.85)
            for sx in (-1, 1):
                chair(g, X(6.0) + sx * 2.3, y + 0.8, z0, rz=sx * math.pi / 2)
            g["LampPt"].box(X(6.0), y, z0 + 4.4, 0.3, 0.3, 0.3)
        g["Wood"].obox(X(4.0), 12.0, z0 + 3.6, 1.6, 1.2, 0.2, rx=-0.4)
        g["Wood"].box(X(4.0), 12.3, z0 + 1.7, 0.6, 0.6, 3.4)
        g["Leather"].obox(X(4.0), 11.9, z0 + 3.75, 1.4, 1.0, 0.25, rx=-0.4)
        g["Canvas"].obox(X(4.0), 11.85, z0 + 3.88, 1.3, 0.9, 0.02, rx=-0.4)
        C(X(4.0), 12.2, z0 + 1.9, 1.6, 1.4, 3.8)
    else:
        # ── 아래: 쉼터(앞) — 벽난로(바깥벽) · 안락의자 넷 · 체스 탁자 둘 / 식당(뒤) — 긴 탁자 + 걸상
        fy = -14.0
        box2(g, "Stone", xo - s * 1.6, xo, fy - 3.0, fy + 3.0, ZF, ZS)
        S.hole(g, xo - s * 1.6, fy, ZF + 1.6, 3.0, 2.8, "-x" if s > 0 else "+x", 1.2, pane=False)    # 화실 — 진짜 장작불
        g["Soot"].box(xo - s * 0.45, fy, ZF + 1.6, 0.06, 2.9, 2.7)
        fire_logs(g, xo - s * 1.0, fy, ZF + 0.25, 2.5, 1.0, axis="y", size=0.9)
        g["Stone"].box(xo - s * 2.1, fy, ZF + 0.08, 1.0, 4.0, 0.16)
        g["StoneTrim"].box(xo - s * 1.0, fy, ZF + 3.6, 2.4, 6.6, 0.4)
        S.gear(g, "Brass", xo - s * 1.65, fy, ZF + 6.4, 1.2, 12, 0.15, axis="x")
        g["Banner"].box(X(6.0), fy, ZF + 0.04, 7.0, 8.0, 0.06)
        for u, y, rz in ((6.5, fy - 3.0, 0.0), (6.5, fy + 3.0, math.pi), (3.5, fy - 2.4, 0.4), (3.5, fy + 2.4, math.pi - 0.4)):
            x = X(u)
            c, sn = math.cos(rz), math.sin(rz)
            g["Leather"].obox(x, y, ZF + 1.0, 2.2, 2.2, 1.2, rz=rz)
            g["Leather"].obox(x + sn * 1.0, y - c * 1.0, ZF + 2.4, 2.2, 0.5, 2.0, rz=rz)
            C(x, y, ZF + 1.5, 2.3, 2.3, 3.0)
        for y in (-24.0, -5.5):
            x = X(6.0)
            g["Wood"].cyl(x, y, ZF + 2.6, 1.3, 1.3, 0.2, seg=16)
            g["Wood"].cyl(x, y, ZF, 0.25, 0.25, 2.6, seg=8)
            for i in range(4):
                for j in range(4):
                    g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(x - 0.6 + i * 0.4, y - 0.6 + j * 0.4, ZF + 2.82, 0.4, 0.4, 0.02)
            for k, (kind, col) in enumerate((("King", "Brass"), ("Pawn", "Iron"), ("Knight", "Brass"))):
                PROP("Chess_" + kind, x - 0.4 + k * 0.4, y - 0.2 + (k % 2) * 0.4, ZF + 2.83, 0.0, 0.12, col=col)
            C(x, y, ZF + 1.4, 2.6, 2.6, 2.8)
            for sy in (-1, 1):
                chair(g, x, y + sy * 2.2, ZF, rz=0.0 if sy > 0 else math.pi, mat="Leather")
        # 식당: 긴 탁자(y 11..23 — 홀 문 y 4..8 앞 비움, 계단 x 32.8..36.8 피함) + 걸상 둘 + 촛대
        mx, my, ml = X(4.5), 17.0, 12.0
        g["Wood"].box(mx, my, ZF + 2.7, 3.2, ml, 0.3)
        for y in (my - ml / 2 + 1.0, my, my + ml / 2 - 1.0):
            g["Wood"].box(mx, y, ZF + 1.3, 2.4, 0.5, 2.6)
        C(mx, my, ZF + 1.4, 3.2, ml, 2.8)
        for sx in (-1, 1):
            g["Wood"].box(mx + sx * 2.4, my, ZF + 1.6, 1.0, ml, 0.25)
            for y in (my - ml / 2 + 1.0, my, my + ml / 2 - 1.0):
                g["Wood"].box(mx + sx * 2.4, y, ZF + 0.75, 0.8, 0.4, 1.5)
            C(mx + sx * 2.4, my, ZF + 0.8, 1.0, ml, 1.6)
        for k in range(3):
            y = my - 4.0 + k * 4.0
            g["Brass"].cyl(mx, y, ZF + 2.85, 0.15, 0.1, 0.8, seg=6)
            g["Glow"].box(mx, y, ZF + 3.75, 0.15, 0.15, 0.25)
            for sx in (-0.8, 0.8):
                g["Iron"].cyl(mx + sx, y + 1.2, ZF + 2.85, 0.35, 0.3, 0.12, seg=10)
        # ── 위: 길드장 방 — 큰 책상 · 의자 · 벽난로(아래 굴뚝 위) · 트로피 장 · 체스 받침 · 깃발 · 책장
        z0 = Z1
        box2(g, "Stone", xo - s * 1.6, xo, fy - 3.0, fy + 3.0, z0, Z2)
        S.hole(g, xo - s * 1.6, fy, z0 + 1.5, 2.6, 2.6, "-x" if s > 0 else "+x", 1.2, pane=False)
        g["Soot"].box(xo - s * 0.45, fy, z0 + 1.5, 0.06, 2.5, 2.5)
        fire_logs(g, xo - s * 1.0, fy, z0 + 0.25, 2.2, 1.0, axis="y", size=0.8)
        g["Stone"].box(xo - s * 2.1, fy, z0 + 0.08, 1.0, 3.6, 0.16)
        g["StoneTrim"].box(xo - s * 1.0, fy, z0 + 3.4, 2.4, 6.6, 0.4)
        dx, dy = X(6.0), -2.0
        g["Wood"].box(dx, dy, z0 + 2.8, 3.4, 7.0, 0.3)
        for sy in (-1, 1):
            g["Wood"].box(dx, dy + sy * 2.8, z0 + 1.35, 3.0, 1.2, 2.7)
        g["Leather"].box(dx, dy, z0 + 2.97, 2.6, 4.0, 0.05)
        green_lamp(g, dx, dy + 2.6, z0 + 2.95)
        PROP("Chess_King", dx, dy - 2.4, z0 + 2.95, 0.0, 0.3, col="Brass")
        for k in range(4):
            g["Canvas"].obox(dx - 0.3 + 0.2 * k, dy - 0.6 + 0.4 * k, z0 + 3.0 + 0.01 * k, 0.9, 1.2, 0.02, rz=0.2 * k)
        C(dx, dy, z0 + 1.5, 3.4, 7.0, 3.0)
        chair(g, dx + s * 2.4, dy, z0, rz=s * math.pi / 2, mat="Leather")
        g["Leather"].box(dx + s * 2.6, dy, z0 + 3.4, 0.4, 1.4, 2.6)
        for y0, y1 in ((8.0, 12.0),):
            bookcase(g, xh, y0, y1, z0, 9.0, s, levels=6, seed=77)
        for k, y in enumerate((-14.0, -11.0)):
            g["Wood"].box(X(1.2), y, z0 + 1.4, 1.6, 2.2, 2.8)
            g["Glass"].box(X(1.2), y, z0 + 4.2, 1.4, 2.0, 2.8)
            g["Brass"].box(X(1.2), y, z0 + 5.65, 1.6, 2.2, 0.1)
            if k == 0:
                S.gear(g, "SignGold", X(1.2), y, z0 + 4.2, 0.6, 10, 0.12, axis="x")
            else:
                sphere(g, "SignGold", (X(1.2), y, z0 + 4.1), 0.5, sub=1)
            C(X(1.2), y, z0 + 2.9, 1.6, 2.2, 5.8)
        g["Marble"].cyl(X(9.0), 10.0, z0, 0.8, 0.6, 3.0, seg=12)
        for i in range(4):
            for j in range(4):
                g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(X(9.0) - 0.6 + i * 0.4, 10.0 - 0.6 + j * 0.4, z0 + 3.02, 0.4, 0.4, 0.04)
        PROP("Chess_Queen", X(9.0), 10.0, z0 + 3.05, 0.0, 0.15, col="Iron")
        C(X(9.0), 10.0, z0 + 1.5, 1.6, 1.6, 3.0)
        g["Banner"].box(X(0.12), -9.0, z0 + 6.0, 0.1, 3.0, 7.0)
        g["SignGold"].box(X(0.18), -9.0, z0 + 7.0, 0.05, 1.4, 1.4)
    # 등(날개 아래·위)
    for y in (-18.0, -4.0, 12.0):
        lantern(g, xmid, y, ZS - 0.4, ZF + 8.6)
    for y in (-18.0, -4.0, 14.0):
        lantern(g, xmid, y, Z2 - 0.4, Z1 + 8.6)


JOBS = [
    ("Figuren_HQ", "FiguIn", job("Figuren_HQ", figuren_in, cut=T)),
]
