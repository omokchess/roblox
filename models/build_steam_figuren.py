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
from build_steam_inside import C, PROP, job, box2, lantern, arch_top, door_leaf_in, DOORWAY, CLEAR, fire_logs, half_ring  # noqa: E402
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
    facade_detail(g)


# ------------------------------------------------------------------ 겉 고르게(2026-11-23 아트 1팀)
# 사용자(2026-11-23): "한쪽에만 세밀하게 구현돼있고, 다른 한쪽은 민둥민둥한 건 전체적으로 세밀하게" — 어느 쪽에서 봐도 같은 밀도.
# 전: 앞면만 받침돌 줄·위 창 반원 머리·관문 탑, 옆은 버팀벽·창, 뒤는 창 넷 + 장미창뿐(큰 민벽). 아래 손 표로 네 면을 맞춘다.
BACK_WIN = (-21.0, -15.5, 15.5, 21.0)          # 뒤 홀 벽 새 창(아래·위) — 옛 ±10(위 큰 창)·±27.5(날개) 사이를 채운다
BACK_LOW10 = (-10.0, 10.0)                     # 뒤 큰 창(위) 밑 아래 창
FRONT_BUTT = (-23.75, -17.0, 17.0, 23.75)      # 앞 버팀벽(창 ±14·±20·±27.5 사이)
BACK_BUTT = (-24.25, -18.25, -12.75, 12.75, 18.25, 24.25)
SIDE_BLIND = (6.0, 14.0, 21.0)                 # 옆 아래 뒤쪽(계단 뒤라 창을 못 낸 자리) 막힌 창 — 겉면에만
HALL_LANCET_B = (-18.0, -12.0, 12.0, 18.0)     # 홀 뒷벽 위(장미창 양옆) 좁은 창
HALL_LANCET_F = (-19.5, -14.5, 14.5, 19.5)     # 홀 앞벽 위(로비 지붕 위, 관문 탑 양옆) 좁은 창


def _side(g, sgn, fn):
    """옆벽(x = sgn 쪽)에 -y 벽용 부품(arch_top 등)을 90° 돌려 짓는다: 제 (lx, ly) → 세계 (ly, -lx)"""
    L.transformed(g, Matrix.Rotation(-math.pi / 2, 4, "Z"), fn)


def blind_window(g, s, y, z0, w=2.8, h=6.4):
    """옆벽 겉면 막힌 창(성벽 '눈먼 창'): 짙은 판 · 돌 문설주 둘 · 돌 인방 · 창턱(눈) — 안에는 아무것도 없다(계단 뒤)"""
    xo = s * X1
    g["Soot"].box(xo + s * 0.05, y, z0 + h / 2, 0.1, w, h)
    for e in (-1, 1):
        g["StoneTrim"].box(xo + s * 0.15, y + e * (w / 2 + 0.18), z0 + h / 2 - 0.15, 0.3, 0.36, h + 0.3)
    g["StoneTrim"].box(xo + s * 0.18, y, z0 + h + 0.22, 0.36, w + 0.9, 0.45)
    g["StoneTrim"].box(xo + s * 0.25, y, z0 - 0.35, 0.5, w + 1.0, 0.3)
    g["SnowCap"].box(xo + s * 0.25, y, z0 - 0.15, 0.45, w + 0.9, 0.1)


def slit(g, x, y, z, rz, h=2.4):
    """좁은 활 구멍(성벽·탑 몸): 짙은 틈 + 돌 테(뒤) + 창턱 — rz = 바깥을 보는 방향(라디안, 0 = +x)"""
    c, sn = math.cos(rz), math.sin(rz)
    g["Char"].obox(x + c * 0.06, y + sn * 0.06, z, 0.12, 0.45, h, rz=rz)
    g["StoneTrim"].obox(x, y, z + 0.05, 0.2, 1.05, h + 0.6, rz=rz)
    g["StoneTrim"].obox(x + c * 0.15, y + sn * 0.15, z - h / 2 - 0.25, 0.4, 1.2, 0.25, rz=rz)


def facade_detail(g):
    # ── 뒤(+y): 창(아래·위) + 위 창 반원 머리 + 버팀벽 + 처마 받침돌 줄
    for x in BACK_WIN + BACK_LOW10:
        S.window(g, x, Y1, ZF + 2.4, 2.8, 6.4, face="+y", cross=True, frame="Timber")
        S.window(g, x, IY1, ZF + 2.4, 2.8, 6.4, face="-y", cross=True, frame="Timber", sill=False)
    for x in BACK_WIN:
        S.window(g, x, Y1, Z1 + 2.0, 2.8, 7.0, face="+y", cross=True, frame="Timber")
        S.window(g, x, IY1, Z1 + 2.0, 2.8, 7.0, face="-y", cross=True, frame="Timber", sill=False)
    for x in BACK_WIN + (-27.5, 27.5):
        arch_top(g, x, IY1, Z1 + 9.0, 1.4, T, frame="Wood")      # 나무 머리테(놋쇠·나무 덩이 삼각형 한도 10000 — 옆은 Timber)
    for x in BACK_BUTT:
        g["StoneTrim"].box(x, Y1 + 0.6, ZB + 10.0, 1.6, 1.2, 20.0)
        g["StoneTrim"].obox(x, Y1 + 0.35, ZB + 20.8, 1.6, 0.7, 2.4, rx=-0.4)
    for x in [-30.0 + k * 1.6 for k in range(int(60.0 / 1.6) + 1)]:
        g["StoneTrim"].box(x, Y1 + 0.55, ZW - 1.2, 0.5, 0.7, 0.6)
    # 홀 뒷벽 위(장미창 양옆) 좁은 창 + 창 위 물받이 돌
    for x in HALL_LANCET_B:
        S.window(g, x, Y1, ZW + 2.0, 2.2, 5.4, face="+y", cross=True, frame="Timber")
        S.window(g, x, IY1, ZW + 2.0, 2.2, 5.4, face="-y", cross=True, frame="Timber", sill=False)
        g["StoneTrim"].box(x, Y1 + 0.35, ZW + 8.2, 3.2, 0.7, 0.5)
    # ── 앞(-y): 버팀벽 + 홀 앞벽 위(로비 지붕 위) 좁은 창
    for x in FRONT_BUTT:
        g["StoneTrim"].box(x, Y0 - 0.6, ZB + 10.0, 1.6, 1.2, 20.0)
        g["StoneTrim"].obox(x, Y0 - 0.35, ZB + 20.8, 1.6, 0.7, 2.4, rx=0.4)
    for x in HALL_LANCET_F:
        S.window(g, x, HY0 - 0.5, ZW + 2.0, 2.2, 5.4, face="-y", cross=True, frame="Timber", cut=1.0)
        S.window(g, x, HY0 + 0.5, ZW + 2.0, 2.2, 5.4, face="+y", cross=True, frame="Timber", sill=False, cut=1.0)
        g["StoneTrim"].box(x, HY0 - 0.85, ZW + 8.2, 3.2, 0.7, 0.5)
    g["StoneTrim"].box(0, HY0 - 0.7, ZH - 0.4, 2 * HX + 1.6, 0.8, 0.8)          # 홀 앞벽 위 처마 띠(뒷벽과 같게)
    # ── 옆(±x): 위 창 반원 머리 · 아래 뒤쪽 막힌 창 · 처마 받침돌 줄
    for sx in (-1, 1):
        wall = X0 if sx < 0 else IX1                                              # 제 좌표 ly = 벽 안쪽 끝(벽은 ly..ly+T)
        for y in (-18.0, -10.0, -2.0, 6.0, 14.0, 21.0):
            _side(g, sx, lambda q, y=y, wall=wall: arch_top(q, -y, wall, Z1 + 9.0, 1.4, T, frame="Timber"))
        for y in SIDE_BLIND:
            blind_window(g, sx, y, ZF + 2.4)
        for y in [Y0 + 6.0 + k * 1.6 for k in range(int((Y1 - Y0 - 12.0) / 1.6) + 1)]:
            if abs(y - (-26.0)) < 6.2 or abs(y - 30.0) < 6.2:
                continue
            g["StoneTrim"].box(sx * (X1 + 0.55), y, ZW - 1.2, 0.7, 0.5, 0.6)
    # ── 층 띠돌 위 눈(네 면 — 관문 탑·모서리 탑 몸 속은 가려진다)
    zs = ZS - 0.2 + 0.8
    for x0, x1 in ((X0 - 0.35, -GX - 0.6), (GX + 0.6, X1 + 0.35)):
        g["SnowCap"].box((x0 + x1) / 2, Y0 - 0.2, zs + 0.05, x1 - x0, 0.3, 0.1)
    g["SnowCap"].box(0, Y1 + 0.2, zs + 0.05, W + 0.7, 0.3, 0.1)
    for sx in (-1, 1):
        g["SnowCap"].box(sx * (X1 + 0.2), (Y0 + Y1) / 2, zs + 0.05, 0.3, D + 0.7, 0.1)
    # ── 관문 탑 옆·뒤(지붕 위 Z2..50 — 앞만 시계·문장이던 곳): 활 구멍 + 둥근 채광 구멍
    for sx in (-1, 1):
        for z in (33.0, 42.0):
            slit(g, sx * (GX + 0.02), (GY0 + GY1) / 2, z, 0.0 if sx > 0 else math.pi)
        g["Brass"].hcyl(sx * (GX + 0.1), (GY0 + GY1) / 2, 46.6, 0.95, 0.25, axis="x", seg=16)
        g["Char"].hcyl(sx * (GX + 0.2), (GY0 + GY1) / 2, 46.6, 0.7, 0.1, axis="x", seg=16)
    for x in (-4.5, 4.5):
        for z in (35.0, 44.0):
            slit(g, x, GY1 + 0.02, z, math.pi / 2)
    # ── 모서리 탑: 날개 지붕 위 대각선 넷에 활 구멍(어느 쪽에서도 같은 줄)
    for cx, cy in TOWERS:
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            rr = RT * 0.955
            slit(g, cx + rr * math.cos(a), cy + rr * math.sin(a), 32.5, a, h=2.0)


def gate_tower(g):
    """앞 관문 탑(x ±10, y -34..-24): 아치 문 + 올린 쇠창살 + 연 쇠문, 위 작전실 창, 기사 문장, 큰 톱니 시계, 꼭대기 흉벽·깃대, 깃발 둘"""
    zt = 50.0
    t = T
    # 앞벽(아치 문 x ±4 · 네모 높이 9 + 반원 4 — 꼭대기 15.2 가 위층 판 밑 15.4 아래) — 문 위 작전실 창은 창이 뚫는다
    for x0, x1, z0, z1 in ((-GX, -4.0, ZB, Z2), (4.0, GX, ZB, Z2), (-4.0, 4.0, ZF + 9.0, Z2)):
        box2(g, "Stone", x0, x1, GY0, GY0 + t, z0, z1)
    g["Cut"].hcyl(0, GY0 + t / 2, ZF + 9.0, 4.0, t + 0.04, axis="y", seg=24)
    for s in (-1, 1):     # 옆벽: 아래층(ZB..ZS)은 로비 쪽 끝을 0.8 들여 로비 앞뒤 길을 8.3 으로(2026-11-24 — 통로 8), 위층은 그대로 탑 몸을 받친다
        box2(g, "Stone", *sorted((s * GX, s * (GX - t))), GY0 + t, GY1 - 0.8, ZB, ZS)
        box2(g, "Stone", *sorted((s * GX, s * (GX - t))), GY0 + t, GY1, ZS, Z2)
        g["StoneTrim"].box(s * (GX - t / 2), GY1 - 0.4, ZS - 0.4, t + 0.2, 0.8, 0.8)      # 들인 자리 위 받침돌
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
    # 관문 통로 바닥(2026-11-08): 통로 안 y -33.9..-29.2 는 받침판(y -29.2..)과 문턱 사이가 비어 있었다(충돌 틈 1.8 → 눈 바닥까지 꺼짐). 보이는 판 + 충돌을 로비 바닥 높이 ZF 로 메운다
    box2(g, "Stone", -GX, GX, GY0 + 0.1, Y0 - 1.2, 0.0, ZF)
    C(0, GY0 - 0.45, ZF / 2, 2 * GX, 1.1, ZF)
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
               [(-5.0, 5.0, ZF, ZF + 10.0), (-4.2, 4.2, Z1, Z1 + 9.0)])
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        wall_holes(g, "Stone", "y", x0, x1, IY0, IY1, ZF, ZW,
                   [(-25.8, -17.4, ZF, ZF + 9.0), (1.8, 10.2, ZF, ZF + 9.0), (-25.8, -17.4, Z1, Z1 + 9.0), (-2.2, 6.2, Z1, Z1 + 9.0)])
        for yy, zz, ww in ((-21.6, ZF, 9.2), (6.0, ZF, 9.2), (-21.6, Z1, 9.2), (2.0, Z1, 9.2)):     # 날개 문 넷 모두 8.4×9 (2026-11-24: 문 8 — 0.5 격자로 재도 8)
            g["StoneTrim"].box(s * HX, yy, zz + 9.3, 1.4, ww, 0.6)
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
    DOORWAY(-4.2, 4.2, HY0 - 0.5, HY0 + 0.5, Z1, 9.0)
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        for y0, y1, z in ((-25.8, -17.4, ZF), (1.8, 10.2, ZF), (-25.8, -17.4, Z1), (-2.2, 6.2, Z1)):
            DOORWAY(x0, x1, y0, y1, z, 9.0)
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
            lobby_bench(g, x + dx, IY0 + 0.75)        # 벽 쪽으로 — 넓힌 날개 문 비울 자리(y -25.4~)를 비킨다
    for x in (-12.0, 12.0):
        hang_chandelier(g, x, (IY0 + HY0) / 2, ZS, ZF + 9.2, 2.0)
    hang_chandelier(g, 0, (GY0 + HY0) / 2, ZS, ZF + 10.6, 1.6)


SQ = 2.4          # 큰 홀 바닥 체스판 칸(말은 두지 않는다 — 길드 문장 바닥). 8×8 = 19.2
GIN = 12.0        # 옆 회랑 보·기둥 축 x. 축 ~ 홀 벽 안면(23.5) = 11.5 → 난간 안쪽 면에서 11.4, 기둥 받침 바깥에서 10.7 (2026-11-08: 두 사람이 앞만 보고 걸어도 남게 10.5 이상)
GDEP = 11.5       # 앞·뒤 회랑: 홀 벽 안면 ~ 보·기둥 축 (난간 안쪽 면에서 11.4, 기둥 받침에서 10.7)
PXM = 6.75        # 앞·뒤 가운데 기둥 x (두 기둥 사이 가운데 길 받침 면 기준 10.5 이상)


def great_hall(g):
    """큰 홀 = 길드 큰 로비(사용자 2026-10-10: 기물 없애고 메인 로비처럼): 체스판 문장 바닥 · 앞쪽 둥근 화단 둘과 둘레 걸상 ·
    소파 자리 넷(회랑 밑) · 뒤 접수대(길드 문장 벽) · 옆벽 의뢰판 둘 · 화분 · 세 면 넓은 회랑 · 샹들리에 셋.
    구조(2026-11-08 사용자: "실제 건물을 올릴 때처럼 공사"): 아래 돌기둥 열둘(받침돌→몸→기둥머리) → 기둥머리 위 가장자리 보(벽~벽) →
    들보(장선) → 회랑 바닥판 → 바닥판 위 받침돌 → 같은 축 위 기둥 여덟 → 기둥머리 → 지붕 받는 세로 보(맞배 가로보가 그 위에 앉는다).
    난간은 기둥과 기둥 사이에만(끝이 기둥 면에 붙는다), 난간 위에는 아무것도 올리지 않는다."""
    hx0, hx1, hy0, hy1 = -HX + 0.5, HX - 0.5, HY0 + 0.5, IY1
    yf, yb = hy0 + GDEP, hy1 - GDEP                   # 앞·뒤 가장자리 보 축 y
    ym = (yf + yb) / 2
    PYS = [yf, ym - 6.3, ym + 6.3, yb]                # 옆 기둥 y (가운데 칸 12.6 — 날개 문 y 2..10 이 이 칸에 든다)
    PXS = [-GIN, -PXM, PXM, GIN]                      # 앞·뒤 기둥 x
    g["Stone"].box(0, (hy0 + hy1) / 2, ZF + 0.02, hx1 - hx0, hy1 - hy0, 0.04)
    cy0, half = ym, 4 * SQ
    for i in range(8):
        for j in range(8):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(-half + SQ / 2 + SQ * i, cy0 - half + SQ / 2 + SQ * j, ZF + 0.07, SQ, SQ, 0.06)
    e = half + 0.4
    for x0, x1, y0, y1 in ((-e, e, cy0 - e, cy0 - half), (-e, e, cy0 + half, cy0 + e), (-e, -half, cy0 - half, cy0 + half), (half, e, cy0 - half, cy0 + half)):
        box2(g, "Brass", x0, x1, y0, y1, ZF, ZF + 0.12, coll=False)
    # 둥근 화단 둘(문 양옆 앞쪽 — 가운데 길 폭 11 을 비운다) + 둘레 둥근 걸상(여섯 토막)
    by = hy0 + 5.5
    for bx in (-9.0, 9.0):
        g["StoneTrim"].cyl(bx, by, ZF, 1.7, 1.7, 1.4, seg=24)
        g["Soot"].cyl(bx, by, ZF + 1.4, 1.5, 1.5, 0.06, seg=24)
        for k in range(7):
            a = k * 0.9
            rr = 0.9 if k < 6 else 0.0
            sphere(g, "Felt", (bx + rr * math.cos(a), by + rr * math.sin(a), ZF + 2.1 + (k % 3) * 0.4), 0.7 if k < 6 else 1.0, sub=1)
        g["Brass"].cyl(bx, by, ZF + 1.4, 0.2, 0.2, 3.8, seg=8)
        S.gear(g, "Brass", bx, by, ZF + 5.4, 1.0, 12, 0.2, axis="y")
        C(bx, by, ZF + 1.2, 3.4, 3.4, 2.4)
        for k in range(6):
            a = 2 * math.pi * (k + 0.5) / 6
            sx_, sy_ = bx + 2.7 * math.cos(a), by + 2.7 * math.sin(a)
            g["Wood"].obox(sx_, sy_, ZF + 1.45, 2.2, 1.0, 0.25, rz=a + math.pi / 2)
            g["Iron"].obox(sx_, sy_, ZF + 0.65, 1.9, 0.6, 1.3, rz=a + math.pi / 2)
            C(sx_, sy_, ZF + 0.8, 2.4, 1.1, 1.6, a + math.pi / 2)
    # 소파 자리 넷(옆 회랑 밑 — 앞·뒤): 마주 보는 소파 둘 + 낮은 탁자 + 깔개
    for sx in (-1, 1):
        for yc in (hy0 + 5.7, hy1 - 4.8):
            xc = sx * 17.6
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
    # ── 구조 1: 아래 돌기둥 열둘(받침돌 → 몸 → 기둥머리). 몸 윗끝이 기둥머리에 묻혀 서고, 기둥머리 위 네모판이 보를 받는다
    zbm = ZS - 1.2                                    # 가장자리 보 밑면
    cols = [(s * GIN, y) for s in (-1, 1) for y in PYS] + [(x, y) for x in PXS[1:3] for y in (yf, yb)]
    for x, y in cols:
        g["StoneTrim"].cyl(x, y, ZF, 1.3, 1.3, 1.0, seg=16)                 # 받침돌
        g["Stone"].cyl(x, y, ZF, 1.0, 0.9, zbm - 1.0 - ZF, seg=16)           # 몸(받침돌 속에서 시작)
        g["StoneTrim"].cyl(x, y, zbm - 1.0, 0.9, 1.5, 0.8, seg=16)           # 기둥머리(나팔)
        g["StoneTrim"].box(x, y, zbm - 0.1, 3.0, 3.0, 0.2)                   # 기둥머리 위 네모판
        C(x, y, (ZF + ZS) / 2, 2.2, 2.2, ZS - ZF)
    for s in (-1, 1):
        for y in PYS:
            x = s * GIN
            g["Iron"].box(x - s * 1.0, y, ZF + 8.0, 0.6, 0.5, 0.8)
            g["Iron"].cyl(x - s * 1.5, y, ZF + 8.0, 0.25, 0.35, 1.0, seg=8)
            g["Glow"].box(x - s * 1.5, y, ZF + 9.4, 0.4, 0.4, 0.8)
            g["LampPt"].box(x - s * 2.0, y, ZF + 9.4, 0.3, 0.3, 0.3)
    # ── 구조 2: 가장자리 보(아키트레이브, 폭 1.6 · 높이 1.2) — 앞·뒤는 벽에서 벽까지(끝이 벽에 앉는다), 옆은 앞·뒤 보 사이
    for y in (yf, yb):
        box2(g, "Stone", -HX, HX, y - 0.8, y + 0.8, zbm, ZS, coll=False)
    for s in (-1, 1):
        box2(g, "Stone", s * GIN - 0.8, s * GIN + 0.8, yf + 0.8, yb - 0.8, zbm, ZS, coll=False)
    # 들보(장선): 앞·뒤 = 벽 ~ 보(y 방향), 옆 = 보 ~ 벽(x 방향). 간격 4.4 이하
    def cuts(a, b, step=4.4):
        n = max(1, int(math.ceil((b - a) / step)))
        return [a + (b - a) * k / n for k in range(1, n)]
    for x in cuts(hx0, hx1, 4.0) + [-PXM, PXM]:
        for y0, y1 in ((hy0, yf - 0.8), (yb + 0.8, hy1)):
            box2(g, "Timber", x - 0.3, x + 0.3, y0, y1, ZS - 0.6, ZS, coll=False)
    jy = sorted(set(PYS[1:3] + cuts(PYS[0], PYS[1]) + cuts(PYS[1], PYS[2]) + cuts(PYS[2], PYS[3])))
    for s in (-1, 1):
        for y in jy:
            xa, xb = sorted((s * (GIN + 0.8), s * hx1))
            box2(g, "Timber", xa, xb, y - 0.3, y + 0.3, ZS - 0.6, ZS, coll=False)
    # ── 구조 3: 회랑 바닥판(보·들보 위, 보 안쪽 면까지 덮는다)
    box2(g, "Wood", hx0, hx1, hy0, yf + 0.8, ZS, Z1)
    box2(g, "Wood", hx0, hx1, yb - 0.8, hy1, ZS, Z1)
    for s in (-1, 1):
        xa, xb = sorted((s * (GIN - 0.8), s * hx1))
        box2(g, "Wood", xa, xb, yf + 0.8, yb - 0.8, ZS, Z1)
    # ── 구조 4: 위 기둥 여덟 — 아래 기둥과 같은 축, 바닥판 위 받침돌 → 몸(같거나 가늘게) → 기둥머리 → 지붕 받는 세로 보
    zr = ZH - 2.2                                     # 세로 보 밑면 (맞배 가로보 밑 ZH-1.2 에 보 윗면이 닿는다)
    for s in (-1, 1):
        for y in PYS:
            x = s * GIN
            g["StoneTrim"].box(x, y, Z1 + 0.3, 1.6, 1.6, 0.6)                              # 받침돌(바닥판 위)
            g["Stone"].cyl(x, y, Z1 + 0.6, 0.7, 0.65, zr - 0.8 - Z1 - 0.6, seg=12)         # 몸
            g["StoneTrim"].cyl(x, y, zr - 0.8, 0.65, 1.0, 0.8, seg=12)                     # 기둥머리
            C(x, y, (Z1 + zr) / 2, 1.8, 1.8, zr - Z1)
        box2(g, "Stone", x - 0.6, x + 0.6, yf - 0.6, yb + 0.6, zr, zr + 1.0, coll=False)   # 세로 보
    # 난간 끝막이 기둥(앞·뒤 가운데 아래 기둥 자리, 바닥판 위 낮은 돌기둥)
    for x in PXS[1:3]:
        for y in (yf, yb):
            g["StoneTrim"].box(x, y, Z1 + 1.8, 0.9, 0.9, 3.6)
            g["Stone"].box(x, y, Z1 + 3.7, 1.3, 1.3, 0.2)
            C(x, y, Z1 + 1.8, 1.2, 1.2, 3.6)
    # 난간: 기둥과 기둥 사이에만(살 + 아래대 + 놋쇠 윗대). 끝은 기둥 받침 면에 붙는다
    cw, nw = 0.8, 0.45                                # 위 기둥 받침 반폭 · 끝막이 기둥 반폭
    segs = []
    for s in (-1, 1):
        for a, b in zip(PYS, PYS[1:]):
            segs.append(((s * GIN, a + cw), (s * GIN, b - cw)))
    for y in (yf, yb):
        for k, (a, b) in enumerate(zip(PXS, PXS[1:])):
            segs.append(((a + (cw if k == 0 else nw), y), (b - (nw if k < 2 else cw), y)))
    for (x0, y0), (x1, y1) in segs:
        ln = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(ln / 0.9))
        for k in range(n + 1):
            f = k / n
            g["Iron"].cyl(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, Z1, 0.07, 0.07, 3.0, seg=5)
        g["Iron"].box((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 0.6, max(abs(x1 - x0), 0.16), max(abs(y1 - y0), 0.16), 0.16)
        g["Brass"].box((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 3.05, max(abs(x1 - x0), 0.25), max(abs(y1 - y0), 0.25), 0.22)
        C((x0 + x1) / 2, (y0 + y1) / 2, Z1 + 1.6, max(abs(x1 - x0), 0.3), max(abs(y1 - y0), 0.3), 3.2)
    # 보 안쪽 면에 걸어 늘어뜨린 깃발(기둥 칸 가운데)
    for s in (-1, 1):
        for k, y in enumerate(((PYS[0] + PYS[1]) / 2, ym, (PYS[2] + PYS[3]) / 2)):
            xb_ = s * (GIN - 0.9)
            g["Brass"].box(xb_, y, ZS - 0.6, 0.2, 3.6, 0.2)
            g[("Banner", "SignBlue", "SignPurple")[k]].box(xb_, y, ZS - 4.9, 0.1, 3.0, 8.6)
            g["SignGold"].box(xb_ - s * 0.06, y, ZS - 3.6, 0.05, 1.4, 1.4)
    # 뒤 접수대(뒤 회랑 밑): 단 + 둥근 앞판 계산대(놋쇠 윗판) + 뒤 직원 칸 4 + 문장 벽 + 장부·종·등
    yp0 = hy1 - 5.6
    box2(g, "Stone", -10.0, 10.0, yp0, hy1, ZF, ZF + 0.6)
    zr = ZF + 0.6
    dy = hy1 - 4.8
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
    # 옆벽 의뢰판 둘(회랑 밑, 홀↔날개 문 y 2..10 피해 y 12..22)
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
    # 화분(네 구석) + 샹들리에 셋
    for x, y in ((-22.2, hy0 + 1.2), (22.2, hy0 + 1.2), (-22.2, hy1 - 1.2), (22.2, hy1 - 1.2)):
        potted_plant(g, x, y, ZF)
    for y in (-2.0, 10.0, 21.0):
        hang_chandelier(g, 0, y, ZH - 1.0, Z1 + 8.0, 3.2)


def war_room(g):
    """작전실(로비 위, x ±23.5, y -26.8..-16.5 + 관문 탑 위층 y -32.8..-26.8): 큰 지도 탁자는 탑 쪽 안으로 들여 문(y -16)을 비운다.
    탁자(12×5) · 의자 여덟 · 벽 지도 둘 · 서류장 넷(옆벽) · 샹들리에"""
    z0 = Z1
    box2(g, "Wood", -HX + 0.5, HX - 0.5, IY0, HY0 - 0.5, Z2, Z2 + 0.5, coll=False)
    tx, ty = 0.0, -25.0
    P = _P()
    P.rug(g, tx - 9.0, tx + 9.0, ty - 4.4, ty + 4.4, z0, "Banner", "SignGold", "SignGold")
    strategy_table(g, tx, ty, z0)
    for k in range(3):
        for sy in (-1, 1):
            chair(g, tx - 4.0 + k * 4.0, ty + sy * 3.6, z0, rz=0.0 if sy > 0 else math.pi, mat="Leather")
    for sx in (-1, 1):
        chair(g, tx + sx * 7.4, ty, z0, rz=-sx * math.pi / 2, mat="Leather")
    # 뒷벽(y -16.5, 문 x ±4 양옆): 벽 지도 둘 + 계급 깃발 넷 / 앞벽: 서류장 둘 · 말 조각 진열장 둘(창 사이)
    for sx in (-1, 1):
        wall_map(g, sx * 9.5, HY0 - 0.5, z0 + 5.6)
        for k, (x, mat) in enumerate(((sx * 14.0, "Banner"), (sx * 19.0, "SignBlue" if sx < 0 else "SignPurple"))):
            rank_banner(g, x, HY0 - 0.5, z0 + 9.2, mat)
        filing_cabinet(g, sx * 17.0, IY0, z0)
        piece_case(g, sx * 22.4, IY0, z0)
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


def _P():
    """1팀 소품 모음(models/snow3/lib_int1.py)을 짓는 순간에 불러온다(모듈 맨 위에서 부르면 build_steam_town 과 서로 불러 막힌다).
    DarkLog 를 쓰는 부품(shelf·wall_bench·deposit_wall·tool_board)은 2판 키트 팔레트에 없어 쓰지 않는다"""
    sys.path.insert(0, os.path.join(HERE, "snow3"))
    import lib_int1 as P
    return P


def lobby_bench(g, x, y):
    """로비 등받이 긴 의자(앞 = +y, 벽에 등): 따낸 자리 · 무쇠 옆틀(다리 + 팔걸이) · 등판 가로대 둘 + 세로 살 다섯"""
    P = _P()
    P.prism(g, "Wood", P.chamfer_pts(x - 2.0, x + 2.0, y - 0.5, y + 0.5, 0.15), ZF + 1.3, ZF + 1.52)
    for e in (-1.8, 1.8):
        g["Iron"].box(x + e, y + 0.3, ZF + 0.65, 0.22, 0.22, 1.3)
        g["Iron"].box(x + e, y - 0.35, ZF + 1.4, 0.22, 0.22, 2.8)
        g["Iron"].obox(x + e, y, ZF + 2.1, 0.2, 1.1, 0.2, rx=-0.15)
    g["Iron"].box(x, y, ZF + 0.5, 3.6, 0.15, 0.15)
    for zz in (ZF + 2.0, ZF + 3.0):
        g["Wood"].box(x, y - 0.42, zz, 3.9, 0.12, 0.3)
    for k in range(5):
        g["Timber"].box(x - 1.6 + k * 0.8, y - 0.4, ZF + 2.5, 0.25, 0.1, 0.9)
    C(x, y, ZF + 1.0, 4.0, 1.2, 2.0)


def strategy_table(g, tx, ty, z0):
    """작전 탁자(12×5): 따낸 상판 + 놋쇠 테 · 앞판 · 굵은 다리 넷(밑동 두 마디) + 가름대 · 위: 8×3 칸 체스판 지도(돌 두 톤 + 땅 표지) ·
    작은 말(PROP) · 놋쇠 나침반 · 자 둘 · 깃발 핀 다섯"""
    P = _P()
    zt = P.table(g, tx - 6.0, tx + 6.0, ty - 2.5, ty + 2.5, z0, h=2.9)
    for sx in (-1, 1):
        g["Brass"].box(tx + sx * 6.02, ty, zt - 0.1, 0.08, 4.6, 0.2)
    for sy in (-1, 1):
        g["Brass"].box(tx, ty + sy * 2.52, zt - 0.1, 11.6, 0.08, 0.2)
    sq = 1.3
    for i in range(8):
        for j in range(3):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(tx - 4 * sq + sq / 2 + i * sq, ty - 1.5 * sq + sq / 2 + j * sq, zt + 0.03, sq, sq, 0.06)
    for i, j, m in ((1, 0, "Felt"), (2, 0, "Felt"), (5, 2, "SignBlue"), (6, 2, "SignBlue"), (3, 1, "StoneTrim")):
        g[m].box(tx - 4 * sq + sq / 2 + i * sq, ty - 1.5 * sq + sq / 2 + j * sq, zt + 0.07, sq * 0.8, sq * 0.8, 0.05)
    for k, (kind, col) in enumerate((("Knight", "Iron"), ("Rook", "Brass"), ("Pawn", "Iron"), ("Bishop", "Brass"),
                                     ("Queen", "Iron"), ("Pawn", "Brass"), ("King", "Brass"), ("Knight", "Brass"))):
        PROP("Chess_" + kind, tx - 4.4 + k * 1.25, ty - 1.2 + (k % 3) * 1.1, zt + 0.06, 0.0 if col == "Brass" else 180.0, 0.35, col=col)
    g["Brass"].cyl(tx + 4.6, ty + 1.9, zt, 0.45, 0.45, 0.12, seg=12)
    g["Dial"].cyl(tx + 4.6, ty + 1.9, zt + 0.12, 0.36, 0.36, 0.03, seg=12)
    g["SignRed"].obox(tx + 4.6, ty + 1.9, zt + 0.17, 0.06, 0.5, 0.03, rz=0.5)
    for k in range(2):
        g["Brass"].obox(tx + 2.6 + k * 0.8, ty + 2.0, zt + 0.03, 0.12, 1.6, 0.05, rz=0.35 + 0.5 * k)
    for k, (dx, dy) in enumerate(((-3.2, 1.6), (-1.0, -0.6), (1.4, 1.2), (2.6, -1.4), (-2.4, -1.8))):
        g["Iron"].cyl(tx + dx, ty + dy, zt + 0.06, 0.04, 0.04, 0.6, seg=4)
        g["SignRed" if k % 2 else "SignBlue"].box(tx + dx + 0.18, ty + dy, zt + 0.52, 0.32, 0.03, 0.2)


def wall_map(g, x, y, z):
    """벽 지도(얼굴 -y): 짙은 틀 · 천 지도 · 땅 덩이 셋 · 놋쇠 핀"""
    g["Timber"].box(x, y - 0.1, z, 3.9, 0.2, 3.9)
    g["Canvas"].box(x, y - 0.22, z, 3.5, 0.05, 3.5)
    for dx, dz, w, h, m in ((-0.7, 0.6, 1.6, 1.2, "SignTeal"), (0.8, -0.5, 1.4, 1.6, "Felt"), (-0.4, -1.1, 1.0, 0.6, "SignBlue")):
        g[m].box(x + dx, y - 0.26, z + dz, w, 0.03, h)
    for dx, dz in ((-0.5, 0.4), (0.9, -0.2), (0.2, 1.1)):
        g["Brass"].box(x + dx, y - 0.3, z + dz, 0.14, 0.06, 0.14)


def rank_banner(g, x, y, z_top, mat):
    """계급 깃발(벽 얼굴 -y): 놋쇠 막대 + 매단 천(아래 제비꼬리 대신 각진 세 갈래) + 금 문장 판"""
    g["Brass"].box(x, y - 0.25, z_top, 2.8, 0.15, 0.15)
    g[mat].box(x, y - 0.18, z_top - 3.0, 2.2, 0.08, 5.6)
    for dx in (-0.73, 0.0, 0.73):
        g[mat].obox(x + dx, y - 0.18, z_top - 6.0, 0.52, 0.08, 0.52, ry=0.785)
    g["SignGold"].box(x, y - 0.24, z_top - 2.2, 1.0, 0.04, 1.0)


def filing_cabinet(g, x, y_wall, z0):
    """서류장(앞벽에 등, 얼굴 +y): 몸 · 서랍 넷(앞판 + 놋쇠 손잡이 · 이름표) · 머리 테"""
    y = y_wall + 0.7
    g["Timber"].box(x, y, z0 + 2.5, 2.6, 1.2, 5.0)
    for k in range(4):
        zz = z0 + 0.7 + k * 1.15
        g["Wood"].box(x, y + 0.62, zz + 0.45, 2.3, 0.06, 1.0)
        g["Brass"].box(x, y + 0.68, zz + 0.55, 0.6, 0.06, 0.12)
        g["Canvas"].box(x, y + 0.66, zz + 0.8, 0.5, 0.04, 0.22)
    g["Wood"].box(x, y, z0 + 5.08, 2.8, 1.35, 0.16)
    C(x, y, z0 + 2.6, 2.6, 1.2, 5.2)


def piece_case(g, x, y_wall, z0):
    """말 조각 진열장(앞벽에 등, 얼굴 +y — 기물군 계급 여섯): 나무 받침 · 유리 몸 · 놋쇠 기둥 넷 · 선반 둘 · 작은 말(PROP) 여섯 · 머리 판"""
    y = y_wall + 0.55
    g["Wood"].box(x, y, z0 + 0.9, 1.7, 1.0, 1.8)
    g["Glass"].box(x, y, z0 + 3.45, 1.5, 0.85, 3.3)
    for dx in (-0.78, 0.78):
        for dy in (-0.45, 0.45):
            g["Brass"].box(x + dx, y + dy, z0 + 3.45, 0.12, 0.12, 3.3)
    for zz in (z0 + 1.8, z0 + 3.45):
        g["Wood"].box(x, y, zz + 0.04, 1.6, 0.9, 0.08)
    for k, kind in enumerate(("King", "Queen", "Bishop", "Knight", "Rook", "Pawn")):
        zz = z0 + 1.88 if k < 3 else z0 + 3.53
        PROP("Chess_" + kind, x - 0.45 + (k % 3) * 0.45, y, zz, 0.0, 0.22, col="Brass" if k % 2 == 0 else "Iron")
    g["Wood"].box(x, y, z0 + 5.2, 1.85, 1.1, 0.2)
    g["SignGold"].box(x, y + 0.56, z0 + 5.2, 0.8, 0.04, 0.14)
    C(x, y, z0 + 2.6, 1.7, 1.0, 5.3)


def weapon_rack(g, xh, y0, y1, z0, s):
    """훈련장 무기 걸이(홀 벽 면 xh 에 붙음, 얼굴 = 날개 쪽): 기둥 셋 · 가로대 셋 · 못 · 칼 셋(날 + 등줄 + 코등이 + 손잡이) · 창 둘"""
    xf = xh + s * 0.3
    for y in (y0, (y0 + y1) / 2, y1):
        g["Timber"].box(xf, y, z0 + 3.5, 0.4, 0.4, 7.0)
    for zz in (z0 + 1.2, z0 + 3.6, z0 + 6.4):
        g["Wood"].box(xf + s * 0.15, (y0 + y1) / 2, zz, 0.25, y1 - y0 + 0.4, 0.3)
    for k, y in enumerate((y0 + 0.9, y0 + 1.7, y0 + 2.5)):
        xb = xf + s * 0.45
        g["Steel"].box(xb, y, z0 + 4.4, 0.08, 0.3, 3.0)
        g["Iron"].box(xb + s * 0.05, y, z0 + 4.4, 0.04, 0.06, 2.8)
        g["Brass"].box(xb, y, z0 + 2.8, 0.15, 1.0, 0.18)
        g["Leather"].box(xb, y, z0 + 2.3, 0.18, 0.18, 0.9)
        g["Brass"].box(xb, y, z0 + 1.75, 0.22, 0.22, 0.2)
    for y in (y1 - 1.4, y1 - 0.7):
        g["Timber"].box(xf + s * 0.45, y, z0 + 3.6, 0.14, 0.14, 7.0)
        g["Steel"].obox(xf + s * 0.45, y, z0 + 7.4, 0.1, 0.3, 0.9, rx=0.0)
    C(xf + s * 0.3, (y0 + y1) / 2, z0 + 3.5, 1.0, y1 - y0 + 0.4, 7.0)


def armor_stand(g, x, y, z0):
    """갑옷 받침(폰 머리 기물군 갑옷): 돌 받침 · 나무 기둥 · 가슴판(Steel) + 등줄 · 어깨 둘 · 투구(둥근 몸 + 챙) · 허리 띠"""
    g["StoneTrim"].cyl(x, y, z0, 0.9, 1.0, 0.4, seg=10)
    g["Timber"].cyl(x, y, z0 + 0.4, 0.15, 0.15, 4.2, seg=6)
    g["Steel"].cyl(x, y, z0 + 2.6, 0.7, 0.85, 1.7, seg=10)
    g["Iron"].box(x, y - 0.8, z0 + 3.4, 0.12, 0.12, 1.4)
    g["Leather"].cyl(x, y, z0 + 2.45, 0.78, 0.78, 0.25, seg=10)
    for sx in (-1, 1):
        g["Steel"].obox(x + sx * 0.95, y, z0 + 4.2, 0.6, 0.9, 0.35, ry=sx * 0.35)
    g["Steel"].cyl(x, y, z0 + 4.55, 0.45, 0.38, 0.7, seg=10)
    g["Steel"].cyl(x, y, z0 + 5.25, 0.38, 0.12, 0.3, seg=10)
    g["Iron"].cyl(x, y, z0 + 4.55, 0.55, 0.55, 0.1, seg=10)
    C(x, y, z0 + 2.7, 2.0, 2.0, 5.5)


def armchair(g, x, y, z0, rz):
    """안락의자(앉는 쪽 = 제 -y 를 rz 로 돌림): 받침 + 방석 · 등(두툼, 위 둥근 대신 각진 테) · 팔걸이 둘 · 짧은 다리 넷 · 놋쇠 못 줄"""
    c, sn = math.cos(rz), math.sin(rz)

    def O(mat, u, v, z, su, sv, sz):
        g[mat].obox(x + u * c - v * sn, y + u * sn + v * c, z, su, sv, sz, rz=rz)
    O("Wood", 0, 0, z0 + 0.55, 2.0, 2.0, 0.3)
    O("Leather", 0, -0.1, z0 + 1.05, 1.5, 1.7, 0.7)
    O("Leather", 0, 0.85, z0 + 2.2, 2.1, 0.5, 2.6)
    O("Wood", 0, 0.85, z0 + 3.55, 2.2, 0.6, 0.2)
    for e in (-1, 1):
        O("Leather", e * 0.9, 0.0, z0 + 1.5, 0.4, 2.0, 1.2)
        O("Wood", e * 0.9, -0.1, z0 + 2.15, 0.5, 2.1, 0.16)
        for v in (-0.85, 0.85):
            O("Wood", e * 0.85, v, z0 + 0.2, 0.25, 0.25, 0.4)
    for k in range(3):
        O("Brass", -0.6 + k * 0.6, -0.95, z0 + 1.45, 0.12, 0.06, 0.12)
    C(x, y, z0 + 1.6, 2.3, 2.3, 3.2)


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
        weapon_rack(g, xh, -13.3, -5.3, ZF, s)
        for k in range(4):
            PROP("Steam_Rifle", xh + s * 0.75, -12.0 + k * 1.8, ZF + 4.2 + (k % 2) * 1.6, 90.0 * s * -1, 1.0)
        for y in (-6.0, 0.0):
            armor_stand(g, X(10.6), y, ZF)
        g["Timber"].hcyl(X(6.0), IY0 + 0.5, ZF + 5.0, 2.0, 0.3, axis="y", seg=20)
        for k, (rr, mat) in enumerate(((1.6, "Canvas"), (1.1, "SignRed"), (0.6, "Canvas"), (0.25, "SignRed"))):
            g[mat].hcyl(X(6.0), IY0 + 0.68 + k * 0.02, ZF + 5.0, rr, 0.04, axis="y", seg=20)
        # ── 위: 기록 서고 — 벽 책장 · 큰 장부 받침 · 탁자 둘
        z0 = Z1
        for y0, y1 in ((-26.4, -21.0), (-15.0, -12.6), (-7.0, -4.6), (1.0, 3.4)):
            bookcase(g, xo, y0, y1, z0, 9.0, -s, levels=6, seed=int(y0) + 40)
        P = _P()
        for y in (-18.0, -6.0):
            P.table(g, X(6.0) - 1.5, X(6.0) + 1.5, y - 2.5, y + 2.5, z0, h=2.85)
            P.book_row(g, X(6.0) - 1.1, X(6.0) + 0.6, y + 1.6, z0 + 2.85, depth=0.7, start=int(-y))
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
        for u, y, rz in ((6.5, fy - 3.0, 0.0), (6.5, fy + 3.0, math.pi), (3.5, fy - 2.0, 0.4), (3.5, fy + 2.4, math.pi - 0.4)):
            armchair(g, X(u), y, ZF, rz)
        for y in (-5.5,):                # 앞 체스 탁자(y -24)는 넓힌 날개 문(y -25.8..-17.4) 바로 안이라 뺐다(2026-11-24)
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
        P = _P()
        P.table(g, mx - 1.6, mx + 1.6, my - ml / 2, my + ml / 2, ZF, h=2.85)
        for sx in (-1, 1):
            xb = mx + sx * 2.4
            P.prism(g, "Wood", P.chamfer_pts(xb - 0.5, xb + 0.5, my - ml / 2 + 0.3, my + ml / 2 - 0.3, 0.15), ZF + 1.45, ZF + 1.7)
            for y in (my - ml / 2 + 1.0, my, my + ml / 2 - 1.0):
                for dx in (-0.3, 0.3):
                    g["Timber"].box(xb + dx, y, ZF + 0.72, 0.18, 0.3, 1.45)
                g["Timber"].box(xb, y, ZF + 0.5, 0.6, 0.15, 0.15)
            g["Timber"].box(xb, my, ZF + 0.5, 0.15, ml - 2.0, 0.15)
            C(xb, my, ZF + 0.85, 1.0, ml, 1.7)
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
        dx, dy = X(6.0), -5.0          # 책상을 뒤로 물려 홀 문(y -2..6) 앞을 연다
        _P().prism(g, "Wood", _P().chamfer_pts(dx - 1.7, dx + 1.7, dy - 3.5, dy + 3.5, 0.25), z0 + 2.65, z0 + 2.95)
        for sy in (-1, 1):
            g["Timber"].box(dx, dy + sy * 2.8, z0 + 1.35, 3.0, 1.2, 2.6)
            for kz in range(3):
                g["Wood"].box(dx - s * 1.52, dy + sy * 2.8, z0 + 0.55 + kz * 0.8, 0.06, 1.0, 0.65)
                g["Brass"].box(dx - s * 1.58, dy + sy * 2.8, z0 + 0.8 + kz * 0.8, 0.06, 0.4, 0.12)
            for sx in (-1, 1):
                g["Brass"].box(dx + sx * 1.6, dy + sy * 3.4, z0 + 2.8, 0.25, 0.25, 0.32)
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
        qx, qy = X(2.5), 16.5          # 계단 구멍(x 32.8..36.8)에 떠 있던 것을 홀 벽 쪽 바닥 위로
        g["Marble"].cyl(qx, qy, z0, 0.8, 0.6, 3.0, seg=12)
        for i in range(4):
            for j in range(4):
                g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(qx - 0.6 + i * 0.4, qy - 0.6 + j * 0.4, z0 + 3.02, 0.4, 0.4, 0.04)
        PROP("Chess_Queen", qx, qy, z0 + 3.05, 0.0, 0.15, col="Iron")
        C(qx, qy, z0 + 1.5, 1.6, 1.6, 3.0)
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
