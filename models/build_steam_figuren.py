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
SW = 6.0                                                    # 날개 계단 폭(2026-11-25 사용자 "폭 4 → 넓힌다" — 날개 안 폭 12.3 이라 8 이면 옆 길이 4.3, 그래서 6)


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
SIDE_BLIND = (21.0,)                           # 옆 아래 뒤쪽(계단 뒤라 창을 못 낸 자리) 막힌 창 — 겉면에만(y 6 = 증기 장치, y 14 = 옆문 — 2026-11-27)
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
    detail3(g)
    # 문·계단 비울 자리(문 앞뒤 2.5)
    DOORWAY(-4.0, 4.0, GY0, GY0 + T, ZF, 9.0)
    DOORWAY(-5.0, 5.0, HY0 - 0.5, HY0 + 0.5, ZF, 10.0)
    DOORWAY(-4.2, 4.2, HY0 - 0.5, HY0 + 0.5, Z1, 9.0)
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.5), s * (HX + 0.5)))
        for y0, y1, z in ((-25.8, -17.4, ZF), (1.8, 10.2, ZF), (-25.8, -17.4, Z1), (-2.2, 6.2, Z1)):
            DOORWAY(x0, x1, y0, y1, z, 9.0)
        xa, xb = sorted((s * IX1, s * (IX1 - SW)))
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
        for k in range(int((ZH - 1.0 - Z1 - 8.6) / 0.62)):        # 사슬 마디(사소 7: 가는 쇠줄이 대각선 줄로 비침 — 2026-11-27)
            zz = Z1 + 8.9 + k * 0.62
            g["Rail"].box(0, y, zz, 0.28 if k % 2 else 0.1, 0.1 if k % 2 else 0.28, 0.5)


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
    """날개 바깥벽 따라 계단(폭 SW — 2026-11-25 사용자 "폭 4 → 넓힌다"): y 4 → 22, 21 단 + 가운데 계단참(길이 2.4, 열째 단 뒤) ·
    열린 쪽 난간(두 마디 + 참) + 위 구멍 둘레 난간. 꼭대기가 뒤 모서리 탑 몸(반지름 5.5)에 닿지 않게 y 22 에서 끝난다"""
    x_out, x_in = s * IX1, s * (IX1 - SW)
    xa, xb = sorted((x_out, x_in))
    n, ya, yb, lm, nl = 21, 4.0, 22.0, 2.4, 10
    run, rise = (yb - ya - lm) / n, (Z1 - ZF) / n
    for i in range(n):
        y0 = ya + i * run + (lm if i >= nl else 0.0)
        y1 = y0 + run + (lm if i == nl - 1 else 0.0)
        box2(g, "Stone" if i % 2 else "StoneTrim", xa, xb, y0, y1, ZF, ZF + (i + 1) * rise)
        g["Banner"].box((xa + xb) / 2, (y0 + y1) / 2, ZF + (i + 1) * rise + 0.02, SW - 1.6, y1 - y0, 0.04)

    def zt(y):                       # 디딤 앞 끝 높이(난간 기준)
        if y < ya + nl * run:
            return ZF + max(0.0, y - ya) / run * rise
        if y < ya + nl * run + lm:
            return ZF + nl * rise
        return min(Z1, ZF + nl * rise + (y - ya - nl * run - lm) / run * rise)
    for k in range(14):
        yy = ya + 0.5 + k * (yb - ya - 1.0) / 13
        g["Iron"].cyl(x_in, yy, zt(yy), 0.07, 0.07, 3.0, seg=5)
    for y0, y1 in ((ya, ya + nl * run), (ya + nl * run, ya + nl * run + lm), (ya + nl * run + lm, yb)):
        z0_, z1_ = zt(y0) + 3.1, zt(y1 - 1e-6) + 3.1 if y1 < yb else Z1 + 3.1
        g["BrassB"].obox(x_in, (y0 + y1) / 2, (z0_ + z1_) / 2, 0.2, math.hypot(y1 - y0, z1_ - z0_), 0.2, rx=math.atan2(z1_ - z0_, y1 - y0))
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
    # 장선(위층 판 밑): 홀 벽에서 2.8 · 5.5 는 끝까지, 9.3 은 계단 구멍(y 4..22)을 비켜 두 토막
    for u, spans in ((2.8, ((IY0, IY1),)), (5.5, ((IY0, IY1),)), (9.3, ((IY0, ya), (yb, IY1)))):
        for y0, y1 in spans:
            g["Timber"].box(x_hall + s * u, (y0 + y1) / 2, ZS - 0.5, 0.6, y1 - y0, 0.6)


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
        for k, (u, y) in enumerate(((4.0, -16.0), (7.5, -16.0), (4.0, -10.5), (7.5, -10.5), (10.5, -19.6), (10.5, -8.2))):     # 2026-11-27: (10, -22.5) 는 탑 몸 속, (10, -16) 은 새 벽난로 앞이라 옮김
            dummy(g, X(u), y, ZF)
        ry0, ry1 = -6.0, 0.8          # 2026-11-27: 넓힌 계단 발치(y 1.5~) 비움
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
        for y0, y1 in ((-26.4, -21.0), (-7.0, -4.6), (1.0, 3.4)):          # (-15..-12.6) 은 벽난로(2026-11-27) 자리
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
        mx, my, ml = X(3.15), 16.5, 9.0          # 2026-11-27: 계단 폭 6(x 30.8~) 이라 홀 벽 쪽으로 · 짧게
        P = _P()
        P.table(g, mx - 1.4, mx + 1.4, my - ml / 2, my + ml / 2, ZF, h=2.85)
        for sx in (-1, 1):
            xb = mx + sx * 2.2
            P.prism(g, "Wood", P.chamfer_pts(xb - 0.5, xb + 0.5, my - ml / 2 + 0.3, my + ml / 2 - 0.3, 0.15), ZF + 1.45, ZF + 1.7)
            for y in (my - ml / 2 + 1.0, my, my + ml / 2 - 1.0):
                for dx in (-0.3, 0.3):
                    g["Timber"].box(xb + dx, y, ZF + 0.72, 0.18, 0.3, 1.45)
                g["Timber"].box(xb, y, ZF + 0.5, 0.6, 0.15, 0.15)
            g["Timber"].box(xb, my, ZF + 0.5, 0.15, ml - 2.0, 0.15)
            C(xb, my, ZF + 0.85, 1.0, ml, 1.7)
        for k in range(3):
            y = my - 3.0 + k * 3.0
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
        dx, dy = X(6.0), -9.0          # 책상을 앞으로 물려 홀 문(y -2..6) 앞을 연다(2026-11-27: 넓힌 계단 구멍 모서리 y 4 와 9.5 띄움)
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
        for k, y in enumerate((-14.0, -11.0)):     # 진열장(2026-11-27 비평: 흰 유리 덩이 → 짙은 나무 틀 · 맑은 유리 앞·옆 · 선반 · 트로피)
            xc = X(1.2)
            g["Wood"].box(xc, y, z0 + 1.4, 1.6, 2.2, 2.8)
            for dy in (-1.0, 1.0):
                for dx in (-0.7, 0.7):
                    g["DarkLog"].box(xc + dx, y + dy, z0 + 4.2, 0.2, 0.2, 2.78)
            g["DarkLog"].box(xc - s * 0.72, y, z0 + 4.2, 0.12, 1.8, 2.78)
            g["DarkLog"].box(xc + 0.05 * s, y, z0 + 4.25, 1.3, 1.8, 0.08)
            g["WinGlass"].box(xc + s * 0.75, y, z0 + 4.2, 0.04, 1.8, 2.6)
            for dy in (-1.0, 1.0):
                g["WinGlass"].box(xc, y + dy * 0.98, z0 + 4.2, 1.2, 0.04, 2.6)
            g["Brass"].box(xc, y, z0 + 5.65, 1.6, 2.2, 0.1)
            if k == 0:
                S.gear(g, "SignGold", xc - s * 0.6, y, z0 + 4.95, 0.45, 10, 0.1, axis="x")
                g["SignGold"].cyl(xc, y - 0.4, z0 + 2.85, 0.18, 0.28, 0.7, seg=10)
                g["SignGold"].cyl(xc, y - 0.4, z0 + 3.55, 0.06, 0.06, 0.3, seg=6)
                g["SignGold"].cyl(xc, y - 0.4, z0 + 3.85, 0.3, 0.2, 0.35, seg=10)
            else:
                sphere(g, "SignGold", (xc, y, z0 + 4.85), 0.4, sub=1)
                for dy in (-0.5, 0.0, 0.5):
                    g["Canvas"].hcyl(xc + 0.1 * s, y + dy, z0 + 3.0, 0.16, 1.0, axis="x", seg=8)
            C(xc, y, z0 + 2.9, 1.6, 2.2, 5.8)
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


# ================================================================== 3차 디테일(2026-11-27 아트 — 회사/비평/본부_1차.md 심각 2·보통 3·사소 4)
# 사용자(2026-11-23): "한쪽에만 세밀하게 구현돼있고, 다른 한쪽은 민둥민둥한 건 전체적으로 세밀하게" · (2026-11-18) "테마에 맞는 수준에서 퀄리티의 극상 … 극사실주의 금지"
# 네 면 모두: 돌 밑단 + 두 톤 돌 켜(줄눈) + 굵직한 볼거리(문·현수막·문장·증기 장치) 셋 이상 / 탑 넷: 받침돌·활 구멍 테·켜 / 지붕: 굴뚝 둘·증기 관 둘·지붕창·용마루 장식
# 방마다: 짙은 나무 판벽(4) + 밝은 돌 겉판·줄눈 + 널 마루 + 벽등 둘 이상 + 초점 하나.
# 재질: 2판 덩이 한도(재질당 삼각형 10000)가 찬 Brass·StoneTrim 대신 같은 모습 짝 BrassB·TrimB(build_steam_town.PAL · Studio SKIN 에 넣음).
TONE = (1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0)     # 두 톤 돌 손 표(켜·자리마다 몇째 돌이 한 톤 짙은지)
TOWER_RINGS = (5.4, 7.0, 11.4, 13.4, 17.8, 23.6, 25.6, 27.6, 34.8)   # 탑 줄눈 고리(활 구멍 z 9·21·32.5 와 띠 15.6·29.4 를 비킴)
FY = -14.0                                                            # 날개 벽난로(바깥벽) y


def _gb(g):
    """Brass → BrassB, StoneTrim → TrimB, Timber → DarkLog, Iron → Rail(같은 모습) 로 바꿔 끼운 덩이 표(남의 부품 함수에 넘길 때 — 한도 찬 재질을 피한다)"""
    q = dict(g)
    q["Brass"], q["StoneTrim"], q["Timber"], q["Iron"] = g["BrassB"], g["TrimB"], g["DarkLog"], g["Rail"]
    return q


def _rt(z):
    """모서리 탑 몸 반지름(높이 z) — 0 에서 RT, 38 에서 RT·0.94"""
    return RT * (1.0 - 0.06 * z / 38.0)


def _zs(a, b, n):
    return [a + (b - a) * i / n for i in range(n + 1)]


def _cuts(g, ax, c, pad=(0.6, 1.0, 1.8)):
    """벽 면(ax 'y' = y=c 평면 · u = x / 'x' = x=c 평면 · u = y)을 꿰뚫는 창 구멍(Cut 덩이) → [(u0, u1, z0, z1)], 창틀·창턱·반원 머리만큼 pad 로 넓힘"""
    k, u = (1, 0) if ax == "y" else (0, 1)
    out = []
    for vs, fs in S._comps(g["Cut"].bm):
        lo, hi = S._aabb([v.co for v in vs])
        if lo[k] - 0.05 <= c <= hi[k] + 0.05:
            out.append((lo[u] - pad[0], hi[u] + pad[0], lo[2] - pad[1], hi[2] + pad[2]))
    return out


def _plate(g, mat, ax, c, sgn, ua, ub, za, zb, d0, d1, coll=False):
    """벽 면에서 바깥(sgn)으로 d0..d1 나온 판"""
    if ub - ua < 0.04 or zb - za < 0.04:
        return
    n0, n1 = sorted((c + sgn * d0, c + sgn * d1))
    if ax == "y":
        box2(g, mat, ua, ub, n0, n1, za, zb, coll)
    else:
        box2(g, mat, n0, n1, ua, ub, za, zb, coll)


def _free(a, b, za, zb, holes):
    segs = [(a, b)]
    for h0, h1, hz0, hz1 in holes:
        if hz1 <= za or hz0 >= zb:
            continue
        segs = [p for s0, s1 in segs for p in ((s0, min(s1, h0)), (max(s0, h1), s1)) if p[1] - p[0] > 0.04]
    return segs


def ashlar(g, ax, c, sgn, u0, u1, zs, holes, hm="Soot", vm="DarkStone", tone="StoneB", blk=4.0, seed=0, d=0.0):
    """돌 켜: 켜 경계 가로 줄눈(hm) · 켜마다 반 돌 엇갈린 세로 줄눈(vm) · 손 표 TONE 자리 돌은 한 톤 짙게(tone). d = 벽 면에서 띄움"""
    for i, (za, zb) in enumerate(zip(zs, zs[1:])):
        if i:
            for s0, s1 in _free(u0, u1, za - 0.06, za + 0.06, holes):
                _plate(g, hm, ax, c, sgn, s0, s1, za - 0.06, za + 0.06, d, d + 0.06)
        off = (i % 2) * blk / 2
        for k in range(int(math.floor((u0 - off) / blk)), int(math.ceil((u1 - off) / blk)) + 1):
            uj = off + k * blk
            if u0 + 0.4 < uj < u1 - 0.4 and _free(uj - 0.06, uj + 0.06, za, zb, holes) == [(uj - 0.06, uj + 0.06)]:
                _plate(g, vm, ax, c, sgn, uj - 0.06, uj + 0.06, za + 0.03, zb - 0.03, d, d + 0.05)
            if tone and TONE[(k * 3 + i * 5 + seed) % len(TONE)]:
                a, b = max(uj + 0.08, u0 + 0.1), min(uj + blk - 0.08, u1 - 0.1)
                if b - a > 1.2 and _free(a, b, za, zb, holes) == [(a, b)]:
                    _plate(g, tone, ax, c, sgn, a, b, za + 0.08, zb - 0.08, d, d + 0.03)


def plinth(g, ax, c, sgn, u0, u1, gaps=()):
    """돌 밑단(받침 위 2.0 → 3.7, 0.4 내밈) + 물끊기 턱(0.65 내밈) + 턱 위 눈"""
    for a, b in _free(u0, u1, ZB, 4.0, [(g0, g1, ZB, 4.0) for g0, g1 in gaps]):
        _plate(g, "TrimB", ax, c, sgn, a, b, ZB, 3.7, 0.0, 0.4)
        _plate(g, "TrimB", ax, c, sgn, a, b, 3.7, 3.95, 0.0, 0.65)
        _plate(g, "SnowCap", ax, c, sgn, a + 0.05, b - 0.05, 3.95, 4.03, 0.05, 0.6)


def _ext_face(g, ax, c, sgn, u0, u1, holes, gaps=(), seed=0, zones=((3.95, 15.2, 6), (16.0, 28.2, 6))):
    plinth(g, ax, c, sgn, u0, u1, gaps)
    for za, zb, n in zones:
        ashlar(g, ax, c, sgn, u0, u1, _zs(za, zb, n), holes, seed=seed)


def _pt(ax, c, sgn, u, d):
    """벽 면 좌표(u 벽 따라, d 바깥으로) → (x, y)"""
    return (u, c + sgn * d) if ax == "y" else (c + sgn * d, u)


def _bxy(g, mat, ax, c, sgn, u, d, z, su, sd, sz):
    x, y = _pt(ax, c, sgn, u, d)
    g[mat].box(x, y, z, su if ax == "y" else sd, sd if ax == "y" else su, sz)


def wall_lamp(g, ax, c, sgn, u, z, d=0.0):
    """바깥 벽 증기 등(관문 등과 같은 꼴): 쇠 팔 · 쇠 등갓 몸 · 불빛 · 빛 표지"""
    _bxy(g, "Rail", ax, c, sgn, u, d + 0.5, z, 0.3, 1.0, 0.3)
    x, y = _pt(ax, c, sgn, u, d + 1.0)
    g["Rail"].cyl(x, y, z - 1.2, 0.4, 0.5, 1.2, seg=8)
    g["Glow"].box(x, y, z + 0.2, 0.55, 0.55, 0.9)
    g["Rail"].cyl(x, y, z + 0.65, 0.5, 0.15, 0.4, seg=8)
    x2, y2 = _pt(ax, c, sgn, u, d + 1.5)
    g["LampPt"].box(x2, y2, z + 0.2, 0.3, 0.3, 0.3)


def closed_door(g, ax, c, sgn, u, w, h, steps=2, lamp_u=None, lamp_d=0.0, step_w=None):
    """닫힌 바깥 문(벽 앞에 붙임 — 뒤는 막힌 벽, 안 동선은 그대로): 짙은 나무 문짝 둘 · 놋쇠 띠 셋 · 고리 손잡이 ·
    돌 문설주 + 반원 쐐기돌 아치(이맛돌) · 반원 쇠살 채광 · 문턱 · 계단(받침 끝에서 땅까지) · 양옆 등"""
    r = w / 2
    zc = ZF + h                                   # 반원 가운데
    for e in (-1, 1):                             # 문짝 둘(가운데 틈 0.1) + 놋쇠 띠 셋 + 고리
        uc = u + e * (r / 2 + 0.025)
        _bxy(g, "DarkLog", ax, c, sgn, uc, 0.2, ZF + h / 2, r - 0.05, 0.2, h)
        for f in (0.15, 0.5, 0.85):
            _bxy(g, "BrassB", ax, c, sgn, uc, 0.33, ZF + h * f, r - 0.25, 0.06, 0.28)
        x, y = _pt(ax, c, sgn, u + e * 0.55, 0.42)
        g["BrassB"].hcyl(x, y, ZF + h * 0.45, 0.3, 0.08, axis="y" if ax == "y" else "x", seg=12)
    x, y = _pt(ax, c, sgn, u, 0.06)
    g["Soot"].hcyl(x, y, zc, r, 0.12, axis="y" if ax == "y" else "x", seg=20)          # 반원 채광(짙은 바탕)
    for k in range(5):                                                                  # 쇠살(부챗살)
        a = math.pi * (k + 1) / 6
        _rot = (lambda q, a=a: q["BrassB"].obox(0, 0, 0, r * 0.95, 0.08, 0.1, ry=-a))
        L.transformed(g, Matrix.Translation((*_pt(ax, c, sgn, u, 0.16), zc)) @ Matrix.Rotation(0 if ax == "y" else math.pi / 2, 4, "Z")
                      @ Matrix.Translation((r * 0.475 * math.cos(a), 0, r * 0.475 * math.sin(a))), _rot)
    for e in (-1, 1):                                                                   # 문설주
        _bxy(g, "TrimB", ax, c, sgn, u + e * (r + 0.5), 0.35, ZF + h / 2, 1.0, 0.7, h)
    half = [((r + 0.5) * math.cos(math.pi * k / 10), (r + 0.5) * math.sin(math.pi * k / 10)) for k in range(11)]
    for (a0, b0), (a1, b1) in zip(half, half[1:]):                                       # 쐐기돌 아치
        def vous(q, a0=a0, b0=b0, a1=a1, b1=b1):
            q["TrimB"].obox((a0 + a1) / 2, 0, (b0 + b1) / 2, math.hypot(a1 - a0, b1 - b0) + 0.1, 0.7, 1.0, ry=-math.atan2(b1 - b0, a1 - a0))
        L.transformed(g, Matrix.Translation((*_pt(ax, c, sgn, u, 0.35), zc)) @ Matrix.Rotation(0 if ax == "y" else math.pi / 2, 4, "Z"), vous)
    _bxy(g, "TrimB", ax, c, sgn, u, 0.5, zc + r + 0.5, 1.2, 1.0, 1.4)                  # 이맛돌
    sw = step_w or w + 4.0
    _bxy(g, "TrimB", ax, c, sgn, u, 0.6, (ZB + ZF) / 2, w + 1.0, 1.2, ZF - ZB)          # 문턱
    for k in range(steps):                                                              # 계단: 받침 끝(1.2)에서 땅까지
        d0, d1 = 1.2 + 1.4 * k, 1.2 + 1.4 * (k + 1)
        top = ZB * (steps - k) / (steps + 1)
        _bxy(g, "Stone", ax, c, sgn, u, (d0 + d1) / 2, top / 2, sw + 1.2 * k, d1 - d0, top)
        x, y = _pt(ax, c, sgn, u, (d0 + d1) / 2)
        C(x, y, top / 2, (sw + 1.2 * k) if ax == "y" else d1 - d0, (d1 - d0) if ax == "y" else (sw + 1.2 * k), top)
    for e in (-1, 1):
        wall_lamp(g, ax, c, sgn, u + e * (lamp_u or r + 2.4), ZF + h - 0.6, lamp_d)


def banner(g, ax, c, sgn, u, z_top, ln, w=3.4, d=0.55, emblem=1.6):
    """문장 현수막(앞면 관문 현수막과 같은 꼴): 놋쇠 막대 + 쇠 걸쇠 둘 · 붉은 천 · 금 문장 · 금 술 띠"""
    _bxy(g, "BrassB", ax, c, sgn, u, d, z_top + 0.2, w + 0.6, 0.3, 0.3)
    for e in (-1, 1):
        _bxy(g, "Rail", ax, c, sgn, u + e * (w / 2 + 0.1), d / 2, z_top + 0.2, 0.2, d, 0.2)
    _bxy(g, "Banner", ax, c, sgn, u, d, z_top - ln / 2, w, 0.15, ln)
    _bxy(g, "SignGold", ax, c, sgn, u, d + 0.105, z_top - 3.3, emblem, 0.06, emblem)
    _bxy(g, "Banner", ax, c, sgn, u, d + 0.14, z_top - 3.3, emblem * 0.45, 0.02, emblem * 0.45)
    _bxy(g, "SignGold", ax, c, sgn, u, d, z_top - ln + 0.05, w, 0.18, 0.25)


def steam_set(g, ax, c, sgn, u, d=0.75, ur=None, tank=None, top=ZW + 2.4):
    """벽 증기 장치 한 벌: 받침돌 위 구리 보일러(놋쇠 띠 둘·녹청 뚜껑·압력계·밸브 바퀴) → 구리 관(쇠 고리·놋쇠 테)이 벽을 타고
    처마 위 녹청 갓 + 김 구멍(Vent — Studio 에서 김)까지. tank = 벽에 건 구리 통(관이 지나간다)"""
    ur = u if ur is None else ur
    oax = "y" if ax == "y" else "x"
    lax = "x" if ax == "y" else "y"
    bd = d + 1.35
    bx_, by_ = _pt(ax, c, sgn, u, bd)
    g["TrimB"].box(bx_, by_, 1.1, 2.9, 2.9, 2.2)
    C(bx_, by_, 3.4, 2.9, 2.9, 6.8)
    g["Copper"].cyl(bx_, by_, 2.2, 1.1, 1.1, 3.6, seg=16)
    for zz in (2.7, 5.0):
        g["BrassB"].cyl(bx_, by_, zz, 1.17, 1.17, 0.24, seg=16)
    cone(g, "Verdigris", (bx_, by_, 5.8), (bx_, by_, 6.7), 1.12, seg=16)
    sphere(g, "BrassB", (bx_, by_, 6.75), 0.22, sub=1)
    x, y = _pt(ax, c, sgn, u, bd + 1.12)
    g["BrassB"].hcyl(x, y, 4.0, 0.52, 0.12, axis=oax, seg=16)
    x, y = _pt(ax, c, sgn, u, bd + 1.2)
    g["Dial"].hcyl(x, y, 4.0, 0.42, 0.06, axis=oax, seg=16)
    _bxy(g, "Rail", ax, c, sgn, u + 0.12, bd + 1.25, 4.08, 0.32, 0.03, 0.06)
    x, y = _pt(ax, c, sgn, u + 1.2, bd)
    g["BrassB"].hcyl(x, y, 4.6, 0.45, 0.1, axis=lax, seg=12)
    x, y = _pt(ax, c, sgn, u + 1.28, bd)
    g["Rail"].hcyl(x, y, 4.6, 0.18, 0.1, axis=lax, seg=8)
    # 보일러 → 관(벽 쪽으로, 필요하면 벽 따라 옆으로)
    zc = 5.2
    x, y = _pt(ax, c, sgn, u, (d + bd - 1.1) / 2)
    g["Copper"].hcyl(x, y, zc, 0.3, bd - 1.1 - d + 0.3, axis=oax, seg=10)
    x, y = _pt(ax, c, sgn, u, d)
    sphere(g, "BrassB", (x, y, zc), 0.4, sub=1)
    if abs(ur - u) > 0.1:
        x, y = _pt(ax, c, sgn, (u + ur) / 2, d)
        g["Copper"].hcyl(x, y, zc, 0.3, abs(ur - u), axis=lax, seg=10)
        x, y = _pt(ax, c, sgn, ur, d)
        sphere(g, "BrassB", (x, y, zc), 0.4, sub=1)
    x, y = _pt(ax, c, sgn, ur, d)
    g["Copper"].cyl(x, y, zc, 0.3, 0.3, top - zc, seg=10)
    for zz in (9.0, 13.5, 20.0, 24.5):
        g["Rail"].cyl(x, y, zz, 0.38, 0.38, 0.22, seg=10)
        _bxy(g, "Rail", ax, c, sgn, ur, d / 2, zz + 0.11, 0.18, d, 0.18)
    for zz in (11.2, 22.2):
        g["BrassB"].cyl(x, y, zz, 0.42, 0.42, 0.3, seg=10)
    g["Verdigris"].cyl(x, y, top - 0.2, 0.42, 0.6, 0.5, seg=10)            # 나팔 입(위는 열어 둔다 — 김이 막히지 않게)
    g["Vent"].box(x, y, top + 0.55, 0.3, 0.3, 0.3)
    if tank is not None:                                                    # tank = 통 가운데 u
        x, y = _pt(ax, c, sgn, tank, 1.15)
        g["Copper"].hcyl(x, y, 10.0, 0.85, 3.0, axis=lax, seg=16)
        for e in (-1, 1):
            x, y = _pt(ax, c, sgn, tank + e * 1.45, 1.15)
            g["BrassB"].hcyl(x, y, 10.0, 0.9, 0.2, axis=lax, seg=16)
            _bxy(g, "Rail", ax, c, sgn, tank + e * 1.0, 0.6, 8.95, 0.3, 1.2, 0.5)
        x, y = _pt(ax, c, sgn, tank + 0.9, 2.0)
        g["BrassB"].hcyl(x, y, 10.3, 0.36, 0.08, axis=oax, seg=12)
        x, y = _pt(ax, c, sgn, tank + 0.9, 2.05)
        g["Dial"].hcyl(x, y, 10.3, 0.28, 0.04, axis=oax, seg=12)


def _arc(g, mat, cx, cy, z0, z1, r0, r1, a0, a1, n=8):
    L.transformed(g, Matrix.Translation((cx, cy, 0)), lambda q: arc_wall(q, mat, z0, z1, r0, r1, a0, a1, n=n))


def _quadrant(cx, cy):
    """모서리 탑이 방 안으로 불룩 든 쪽(도, a0 < a1) — 벽 속으로 9° 더"""
    a0, a1 = sorted((180.0 if cx > 0 else 0.0, 90.0 if cy < 0 else 270.0))
    if a1 - a0 > 180:
        a0, a1 = a1, a0 + 360
    return a0 - 9, a1 + 9


def tower_detail(g, cx, cy):
    """모서리 탑: 밑단(바깥 쪽 고리) · 줄눈 고리 · 흉벽 밑 받침돌 16 · 활 구멍 돌 테 + 바깥 대각 활 구멍(아래·위층)"""
    a0, a1 = _quadrant(cx, cy)
    b0, b1 = (a0 + a1) / 2 + 60, (a0 + a1) / 2 + 300           # 바깥 쪽(방 쪽 반대)
    r0 = _rt(0)
    _arc(g, "TrimB", cx, cy, 0.0, 3.7, r0 - 0.2, r0 + 0.4, b0, b1, n=16)
    _arc(g, "TrimB", cx, cy, 3.7, 3.95, r0 - 0.2, r0 + 0.65, b0, b1, n=16)
    _arc(g, "SnowCap", cx, cy, 3.95, 4.03, r0 - 0.2, r0 + 0.6, b0 + 1, b1 - 1, n=16)
    for z in TOWER_RINGS:
        g["RoofMetal"].cyl(cx, cy, z - 0.06, _rt(z - 0.06) + 0.05, _rt(z + 0.06) + 0.05, 0.12, seg=24)
    zt = 38.0
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        rr = _rt(36.8) + 0.4
        g["TrimB"].obox(cx + rr * math.cos(a), cy + rr * math.sin(a), zt - 1.75, 0.9, 0.8, 1.1, rz=a)
        g["TrimB"].obox(cx + (rr - 0.15) * math.cos(a), cy + (rr - 0.15) * math.sin(a), zt - 2.55, 0.6, 0.6, 0.5, rz=a)
    out_y = -1 if cy < 0 else 1
    out_x = -1 if cx < 0 else 1
    ad = math.atan2(out_y, out_x)
    for z in (9.0, 21.0):
        r = _rt(z)
        for ux, uy in ((0, out_y), (out_x, 0)):                 # 있던 활 구멍(어두운 틈)에 돌 테
            px, py = cx + ux * (r + 0.12), cy + uy * (r + 0.12)
            for e in (-1, 1):
                g["TrimB"].box(px + uy * 0 + abs(uy) * e * 0.6, py + abs(ux) * e * 0.6, z, 0.3 if ux else 0.3, 0.3, 3.0)
            g["TrimB"].box(px, py, z + 1.55, 1.5 if uy else 0.3, 1.5 if ux else 0.3, 0.3)
        slit(_gb(g), cx + (r - 0.04) * math.cos(ad), cy + (r - 0.04) * math.sin(ad), z, ad)


def roof_details(g):
    """큰 홀 지붕: 지붕창 여섯(불 켜진 창·짙은 나무 틀·작은 맞배·눈) · 구리 증기 관 둘(김) · 용마루 쇠 장식(놋쇠 꼭지) · 처마 구리 물받이와 홈통"""
    ta = 9.0 / (HX + 0.8)                     # 지붕 기울기(roof_gable: 높이 9 / 반폭 24.8)

    def zs_(x):                               # 눈 윗면 높이
        return ZH + 9.0 - abs(x) * ta + 1.17
    for s in (-1, 1):
        f = "+x" if s > 0 else "-x"
        for y in (-6.0, 9.0, 24.0):
            xf, xb = s * 16.5, s * 12.0
            z0, z1 = zs_(16.5) - 0.6, zs_(16.5) + 3.4
            box2(g, "Stone", *sorted((xb, xf)), y - 1.9, y + 1.9, z0, z1, coll=False)
            S.window(g, xf, y, z0 + 1.0, 1.8, 2.4, face=f, cross=True, frame="DarkLog", glass="Glow", sill=False, cut=False)
            g["TrimB"].box(xf + s * 0.35, y, z0 + 0.7, 0.7, 2.8, 0.3)
            zr = z1 + 1.5
            for e in (-1, 1):
                ang = math.atan2(1.5, 2.3)
                g["RoofMetal"].obox((xf + xb) / 2 + s * 0.4, y + e * 1.15, z1 + 0.8, abs(xf - xb) + 0.9, 2.75, 0.25, rx=-e * ang)
                g["SnowCap"].obox((xf + xb) / 2 + s * 0.2, y + e * 1.05, z1 + 1.0, abs(xf - xb) + 0.3, 2.3, 0.2, rx=-e * ang)
            v = [(xf, y - 1.9, z1), (xf, y + 1.9, z1), (xf, y, zr - 0.1),
                 (xf - s * 0.6, y - 1.9, z1), (xf - s * 0.6, y + 1.9, z1), (xf - s * 0.6, y, zr - 0.1)]
            g["Stone"].add_mesh(v, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
        # 처마 구리 물받이 + 모서리 홈통(날개 지붕까지)
        xe = s * (HX + 0.8 + 0.9 + 0.3)
        g["Copper"].hcyl(xe, (HY0 + Y1) / 2 - 0.25, ZH - 0.5, 0.3, Y1 - HY0 + 1.8, axis="y", seg=10)
        for y in (HY0 + 0.6, Y1 - 2.0):
            g["Copper"].cyl(xe, y, ZW + 0.2, 0.22, 0.22, ZH - 0.5 - ZW - 0.2, seg=8)
            for zz in (32.0, 36.5):
                g["Rail"].box(xe - s * 0.3, y, zz, 0.6, 0.15, 0.15)
    # 구리 증기 관 둘(지붕 뒤쪽 양옆)
    for x, y in ((-8.0, 22.0), (8.0, 14.0)):
        zb = zs_(x) - 0.6
        g["Rail"].cyl(x, y, zb, 0.85, 0.85, 0.8, seg=12)
        g["Copper"].cyl(x, y, zb, 0.55, 0.55, 6.4, seg=12)
        for zz in (zb + 2.0, zb + 4.4):
            g["BrassB"].cyl(x, y, zz, 0.62, 0.62, 0.3, seg=12)
        g["Verdigris"].cyl(x, y, zb + 6.2, 0.55, 0.85, 0.6, seg=12)         # 나팔 입(위는 열림 — 김)
        g["Vent"].box(x, y, zb + 7.1, 0.4, 0.4, 0.3)
    # 용마루 쇠 장식: 쇠 가로대 + 꼭지(놋쇠 구슬) 열셋 + 끝 큰 꼭지
    zr = ZH + 9.0 + 1.17
    g["Rail"].box(0, (HY0 + Y1) / 2 - 0.25, zr + 0.75, 0.14, Y1 - HY0 - 1.0, 0.14)
    for k in range(13):
        y = HY0 + 0.5 + k * (Y1 - HY0 - 2.0) / 12
        g["Rail"].box(0, y, zr + 0.45, 0.12, 0.12, 1.1)
        sphere(g, "BrassB", (0, y, zr + 1.1), 0.18, sub=1)
    for y in (HY0 - 0.2, Y1 + 0.2):
        g["Rail"].cyl(0, y, zr - 0.3, 0.12, 0.08, 2.4, seg=6)
        sphere(g, "BrassB", (0, y, zr + 2.2), 0.35, sub=1)


def chimney_top(g, s):
    """날개 벽난로 굴뚝(안 굴뚝 x ±35.2..36.8 위) — 날개 지붕 위 돌 몸 · 돌 띠 둘 · 구리 굴뚝 단지 둘(녹청 테) · 연기(Vent)"""
    x0, x1 = sorted((s * 34.6, s * 36.5))
    y0, y1 = FY - 1.6, FY + 1.6
    zt = ZW + 6.5
    box2(g, "Stone", x0, x1, y0, y1, Z2 + 0.5, zt, coll=False)
    for zz, e in ((zt - 0.3, 0.5), (zt - 2.6, 0.3)):
        g["TrimB"].box((x0 + x1) / 2, FY, zz, x1 - x0 + e, y1 - y0 + e, 0.6 if e > 0.4 else 0.3)
    g["SnowCap"].box((x0 + x1) / 2, FY, zt + 0.04, x1 - x0 + 0.3, y1 - y0 + 0.3, 0.08)
    for dy in (-0.75, 0.75):
        g["Copper"].cyl((x0 + x1) / 2, FY + dy, zt, 0.42, 0.38, 1.4, seg=10)
        g["Verdigris"].cyl((x0 + x1) / 2, FY + dy, zt + 1.3, 0.48, 0.48, 0.2, seg=10)
        g["Vent"].box((x0 + x1) / 2, FY + dy, zt + 1.7, 0.3, 0.3, 0.3)


def back_face(g):
    """뒤(+y): 닫힌 뒷문(폭 8, 7 + 반원 4) · 계단 · 등 둘 / 위 돌 발코니(폭 10 · 내밈 3 · 받침돌 · 놋쇠 난간 — 난간 위 기둥 없음) + 유리문 /
    현수막 둘 / 장미창 돌 테(쐐기돌 16) / 박공 문장 방패(룩) / 증기 장치(버팀벽 x 12.75)"""
    closed_door(g, "y", Y1, 1, 0.0, 8.0, 7.0, steps=2, lamp_u=6.4, step_w=12.0)
    # 발코니
    w, dep = 10.0, 3.0
    box2(g, "TrimB", -w / 2, w / 2, Y1, Y1 + dep, ZS - 0.1, Z1 + 0.1)
    C(0, Y1 + dep / 2, (ZS + Z1) / 2, w, dep, Z1 - ZS + 0.2)
    g["SnowCap"].box(0, Y1 + 0.45 + (dep - 0.75) / 2, Z1 + 0.15, w - 0.6, dep - 0.75, 0.1)
    for x in (-4.6, -2.8, 2.8, 4.6):                                       # 받침돌(아치 등 위로 비켜)
        box2(g, "TrimB", x - 0.4, x + 0.4, Y1, Y1 + 1.4, ZS - 1.7, ZS - 0.9, coll=False)
        box2(g, "TrimB", x - 0.4, x + 0.4, Y1, Y1 + 2.6, ZS - 0.9, ZS - 0.1, coll=False)
    box2(g, "TrimB", -0.6, 0.6, Y1, Y1 + 0.7, ZF + 10.6, ZS - 0.1, coll=False)     # 이맛돌이 받침이 된다
    ye = Y1 + dep - 0.25
    xs = [-w / 2 + 0.25 + k * (w - 0.5) / 16 for k in range(17)]
    for x in xs:
        g["BrassB"].cyl(x, ye, Z1 + 0.1, 0.07, 0.07, 2.9, seg=6)
    for e in (-1, 1):
        for k in range(1, 5):
            g["BrassB"].cyl(e * (w / 2 - 0.25), Y1 + 0.3 + k * (dep - 0.55) / 4 - 0.25, Z1 + 0.1, 0.07, 0.07, 2.9, seg=6)
        g["BrassB"].box(e * (w / 2 - 0.25), Y1 + dep / 2 - 0.05, Z1 + 3.05, 0.2, dep - 0.4, 0.2)
    g["BrassB"].box(0, ye, Z1 + 3.05, w - 0.3, 0.2, 0.2)
    g["BrassB"].box(0, ye, Z1 + 0.45, w - 0.3, 0.14, 0.14)
    C(0, ye, Z1 + 1.6, w, 0.3, 3.2)
    S.window(g, 0.0, Y1, Z1 + 0.2, 3.6, 7.2, face="+y", cross=True, frame="Timber", sill=False)
    S.window(g, 0.0, IY1, Z1 + 0.2, 3.6, 7.2, face="-y", cross=True, frame="Timber", sill=False)
    arch_top(_gb(g), 0.0, IY1, Z1 + 7.4, 1.8, T, frame="Wood")
    # 현수막 둘(관문 현수막과 같은 폭)
    for e in (-1, 1):
        banner(g, "y", Y1, 1, e * 7.2, ZW - 1.4, 14.4)
    # 장미창 돌 테 + 쐐기돌
    rz_ = ZH - 7.0
    L.transformed(g, Matrix.Translation((0, Y1 + 0.23, rz_)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                  lambda q: S.ring(q, "TrimB", 0, 0, -0.23, 4.0, 4.6, 0.46, n=32))
    for k in range(16):
        a = 2 * math.pi * k / 16
        if math.sin(a) < -0.6:
            continue                                                     # 아래는 처마 띠에 묻힌다
        g["TrimB"].obox(4.75 * math.cos(a), Y1 + 0.3, rz_ + 4.75 * math.sin(a), 0.7, 0.6, 0.9, ry=-a + math.pi / 2)
    # 박공 문장 방패(붉은 판 · 금 테 · 금 룩) — 박공 겉면 y = Y1 + 0.25
    yb_, zc = Y1 + 0.25, ZH + 4.4
    g["TrimB"].hcyl(0, yb_ + 0.1, zc, 2.4, 0.2, axis="y", seg=20)
    for mat, dy, sc in (("SignGold", 0.25, 1.0), ("SignRed", 0.32, 0.86)):
        g[mat].box(0, yb_ + dy, zc + 0.5 * sc, 3.0 * sc, 0.12, 1.8 * sc)
        g[mat].obox(0, yb_ + dy, zc - 0.4 * sc, 2.12 * sc, 0.12, 2.12 * sc, ry=math.pi / 4)
    for x0_, z0_, w_, h_ in ((-0.55, -0.9, 1.1, 0.25), (-0.35, -0.65, 0.7, 1.3), (-0.5, 0.65, 1.0, 0.35)):
        g["SignGold"].box(x0_ + w_ / 2, yb_ + 0.42, zc + z0_ + h_ / 2, w_, 0.06, h_)
    for x in (-0.4, 0.0, 0.4):
        g["SignGold"].box(x, yb_ + 0.42, zc + 1.15, 0.22, 0.06, 0.3)
    # 증기 장치(버팀벽 앞)
    steam_set(g, "y", Y1, 1, 12.75, d=1.7)


def side_faces(g):
    """옆(±x): 가운데 뒤 칸(y 14) 닫힌 옆문 + 계단 + 등 둘(버팀벽 앞) · 그 양옆 버팀벽에 현수막 둘 · 앞 칸(y 6) 증기 장치 + 벽 구리 통"""
    for s in (-1, 1):
        closed_door(g, "x", s * X1, s, 14.0, 4.4, 6.5, steps=2, lamp_u=4.0, lamp_d=1.2, step_w=7.0)
        for y in (10.0, 18.0):
            banner(g, "x", s * X1, s, y, ZW - 1.6, 12.6, w=2.4, d=1.45, emblem=1.2)
        steam_set(g, "x", s * X1, s, 6.4, d=0.75, ur=3.6, tank=4.6)


def exterior3(g):
    """네 면·관문 탑·홀 위 벽의 밑단과 돌 켜(창·문·버팀벽·현수막 자리는 비움)"""
    b = lambda xs, z1=23.0: [(x - 0.85, x + 0.85, ZB, z1) for x in xs]    # 버팀벽
    # 앞(-y)
    hf = _cuts(g, "y", Y0) + b(FRONT_BUTT) + b((23.75,))
    _ext_face(g, "y", Y0, -1, -31.0, -GX, hf, seed=1)
    _ext_face(g, "y", Y0, -1, GX, 31.0, hf, seed=4)
    # 관문 탑 앞·옆·뒤(지붕 위)
    hg = _cuts(g, "y", GY0) + [(-5.1, 5.1, ZB, ZF + 14.3), (-3.0, 3.0, 24.0, Z2 + 1.4), (-6.4, 6.4, 34.6, 47.6),
                               (-8.9, -5.1, 10.9, 27.4), (5.1, 8.9, 10.9, 27.4), (-7.2, -5.6, ZF + 5.4, ZF + 9.0), (5.6, 7.2, ZF + 5.4, ZF + 9.0)]
    plinth(g, "y", GY0, -1, -GX - 0.65, GX + 0.65, gaps=((-5.1, 5.1),))
    for za, zb, n in ((3.95, 15.2, 6), (16.2, 28.2, 6), (29.2, 48.2, 9)):
        ashlar(g, "y", GY0, -1, -GX, GX, _zs(za, zb, n), hg, seed=7)
    for s in (-1, 1):
        hs = [(-29.8, -28.2, 31.2, 34.8), (-29.8, -28.2, 40.2, 43.8), (-30.2, -27.8, 45.4, 47.8)]
        plinth(g, "x", s * GX, s, GY0, Y0)
        for (za, zb, n), (u0, u1) in (((3.95, 15.2, 6), (GY0, Y0)), ((16.2, 28.2, 6), (GY0, Y0)), ((29.2, 48.2, 9), (GY0, GY1))):
            ashlar(g, "x", s * GX, s, u0, u1, _zs(za, zb, n), hs, seed=2 + s)
    ashlar(g, "y", GY1, 1, -GX, GX, _zs(29.2, 48.2, 9), [(-5.3, -3.7, 33.2, 36.8), (-5.3, -3.7, 42.2, 45.8), (3.7, 5.3, 33.2, 36.8), (3.7, 5.3, 42.2, 45.8)], seed=5)
    # 뒤(+y)
    hb = _cuts(g, "y", Y1) + b(BACK_BUTT) + [(-5.1, 5.1, ZB, ZF + 12.2), (-5.2, 5.2, ZS - 2.0, Z1 + 0.3),
                                              (-9.0, -5.4, 12.8, ZW - 0.9), (5.4, 9.0, 12.8, ZW - 0.9), (-5.0, 5.0, ZW - 1.0, ZH - 1.2)]
    _ext_face(g, "y", Y1, 1, -31.0, 31.0, hb, gaps=((-5.1, 5.1),), seed=3)
    ashlar(g, "y", Y1, 1, -HX - 0.5, HX + 0.5, _zs(ZW + 0.2, ZH - 0.8, 5), hb, seed=6)
    # 옆(±x)
    for s in (-1, 1):
        hs = _cuts(g, "x", s * X1) + b((-14.0, -6.0, 2.0, 10.0, 18.0)) + [(18.9, 23.1, ZF + 1.4, ZF + 9.4), (11.0, 17.0, ZB, ZF + 10.0),
                                                                           (3.0, 6.2, 8.9, 11.1)]
        _ext_face(g, "x", s * X1, s, -21.2, 25.2, hs, gaps=((11.0, 17.0),), seed=8 + s)
        # 홀 위 옆벽(날개 지붕 위)
        ashlar(g, "x", s * (HX + 0.5), s, HY0 - 0.5, Y1, _zs(ZW + 0.2, ZH - 0.8, 5), _cuts(g, "x", s * (HX + 0.5)), seed=11 + s)
    # 홀 앞 위벽(로비 지붕 위)
    ashlar(g, "y", HY0 - 0.5, -1, -HX - 0.5, HX + 0.5, _zs(ZW + 0.2, ZH - 0.8, 5), _cuts(g, "y", HY0 - 0.5), seed=13)


# ------------------------------------------------------------------ 3차 — 안
def finish_wall(g, ax, c, face, u0, u1, z0, z1, holes, wain=4.0, blk=4.8, seed=0, no_wain=(), jm="Mortar"):
    """방 벽 마감: 아래 짙은 나무 판벽(높이 wain · 세로 널 · 걸레받이 · 놋쇠 윗테 — 창 밑은 창턱까지) + 위 밝은 돌 겉판(TrimB) + 줄눈(Mortar).
    face = 방 쪽(±1). holes = 문·창·벽난로 자리(비움). no_wain = 판벽 없이 겉판만 둘 u 구간(계단 옆)"""
    zw = z0 + wain
    cuts = sorted({u0, u1} | {v for h in holes for v in h[:2] if u0 < v < u1} | {v for p in no_wain for v in p if u0 < v < u1})
    for a, b in zip(cuts, cuts[1:]):
        m = (a + b) / 2
        hs = sorted((h[2], h[3]) for h in holes if h[0] < m < h[1])
        bare = any(p0 < m < p1 for p0, p1 in no_wain) or not wain
        z = z0 if bare else zw
        if not bare:
            top = min([zw] + [hz0 for hz0, hz1 in hs if hz1 > z0])
            if top - z0 >= 0.6:
                _plate(g, "DarkLog", ax, c, face, a, b, z0, top, 0.0, 0.1)
                _plate(g, "DarkLog", ax, c, face, a, b, z0, z0 + 0.35, 0.1, 0.18)
                _plate(g, "BrassB" if top >= zw else "DarkLog", ax, c, face, a, b, top - 0.18, top, 0.1, 0.22)
                nb = int((b - a) / 1.6)
                for k in range(1, nb + 1):
                    uu = a + (b - a) * k / (nb + 1)
                    _plate(g, "DarkLog", ax, c, face, uu - 0.1, uu + 0.1, z0 + 0.35, top - 0.18, 0.1, 0.15)
        for hz0, hz1 in hs + [(z1, z1)]:
            if hz0 > z + 0.04:
                _plate(g, "TrimB", ax, c, face, a, b, z, min(hz0, z1), 0.0, 0.1)
            z = max(z, hz1)
            if z >= z1:
                break
    n = max(1, int(round((z1 - zw) / 2.4)))
    ashlar(g, ax, c, face, u0, u1, _zs(zw, z1, n), holes + [(p0, p1, z0, zw) for p0, p1 in no_wain], hm=jm, vm=jm, tone=None, blk=blk, seed=seed, d=0.1)


def bulge_finish(g, cx, cy, z0, z1, wain=4.0):
    """방 안으로 불룩 든 모서리 탑 몸 마감(방 쪽 부채꼴만): 판벽 + 놋쇠 테 + 밝은 돌 겉판 + 줄눈 고리"""
    a0, a1 = _quadrant(cx, cy)
    r = _rt((z0 + z1) / 2)
    _arc(g, "DarkLog", cx, cy, z0, z0 + wain, r + 0.15, r + 0.25, a0, a1)
    _arc(g, "BrassB", cx, cy, z0 + wain - 0.18, z0 + wain, r + 0.15, r + 0.32, a0, a1)
    _arc(g, "TrimB", cx, cy, z0 + wain, z1, r + 0.15, r + 0.25, a0, a1)
    for zz in _zs(z0 + wain, z1, max(1, int(round((z1 - z0 - wain) / 2.4))))[1:-1]:
        _arc(g, "Mortar", cx, cy, zz - 0.06, zz + 0.06, r + 0.2, r + 0.31, a0, a1)


def hearth_left(g):
    """왼 날개 벽난로(아래 훈련장·위 서고 — 오른 날개와 같은 자리 · 같은 굴뚝 기둥, 2026-11-27 굴뚝 넷 중 하나)"""
    s, xo = -1, -IX1
    for z0, z1, w, h, zc, mz in ((ZF, ZS, 3.0, 2.8, 1.6, 3.6), (Z1, Z2, 2.6, 2.6, 1.5, 3.4)):
        box2(g, "Stone", xo, xo + 1.6, FY - 3.0, FY + 3.0, z0, z1)
        S.hole(g, xo + 1.6, FY, z0 + zc, w, h, "+x", 1.2, pane=False)
        g["Soot"].box(xo + 0.45, FY, z0 + zc, 0.06, w - 0.1, h - 0.1)
        fire_logs(g, xo + 1.0, FY, z0 + 0.25, w - 0.5, 1.0, axis="y", size=0.85)
        g["Stone"].box(xo + 2.1, FY, z0 + 0.08, 1.0, 4.0, 0.16)
        g["TrimB"].box(xo + 1.0, FY, z0 + mz, 2.4, 6.6, 0.4)


def hearth_dress(g, s, z0, z1, w, h, mz, over):
    """벽난로 앞 꾸밈: 돌 문설주·인방(TrimB) · 굴뚝 가슴 겉판·줄눈 · 양옆 벽등 · 선반 위 초점(over: 'shield' 방패와 교차 칼 / 'antler' 사냥 트로피 / 'spear' 둥근 방패와 창 / 'paint' 풍경화)"""
    xf = s * (IX1 - 1.6)                       # 굴뚝 가슴 면
    f = -s
    _plate(g, "TrimB", "x", xf, f, FY - w / 2 - 0.9, FY - w / 2, z0, z0 + h + 0.2, 0.0, 0.3)
    _plate(g, "TrimB", "x", xf, f, FY + w / 2, FY + w / 2 + 0.9, z0, z0 + h + 0.2, 0.0, 0.3)
    _plate(g, "TrimB", "x", xf, f, FY - w / 2 - 0.9, FY + w / 2 + 0.9, z0 + h + 0.2, z0 + h + 0.75, 0.0, 0.35)
    _plate(g, "TrimB", "x", xf, f, FY - 0.35, FY + 0.35, z0 + h - 0.1, z0 + h + 0.95, 0.0, 0.45)
    ztop = z0 + mz + 0.2
    hole = [(FY - w / 2 - 1.0, FY + w / 2 + 1.0, z0, ztop)]
    finish_wall(g, "x", xf, f, FY - 3.0, FY + 3.0, ztop, z1, hole, wain=0.0, seed=17)
    for sy in (-1, 1):
        _plate(g, "TrimB", "y", FY + sy * 3.0, sy, *sorted((s * IX1, xf)), z0, z1, 0.0, 0.08)
    P = _P()
    for e in (-1, 1):
        P.sconce(_gb(g), "y", xf, FY + e * 2.4, ztop + 2.0, face=f)
    zc = ztop + 2.6
    x = xf + f * 0.15
    if over == "shield":
        for dz, mat, sc in ((0.0, "SignGold", 1.0), (0.0, "SignBlue", 0.86)):
            g[mat].box(x + f * (0.05 if sc < 1 else 0.0), FY, zc + 0.45 * sc, 0.12, 2.4 * sc, 1.5 * sc)
            g[mat].obox(x + f * (0.05 if sc < 1 else 0.0), FY, zc - 0.35 * sc, 0.12, 1.7 * sc, 1.7 * sc, rx=math.pi / 4)
        sphere(g, "BrassB", (x + f * 0.15, FY, zc + 0.1), 0.32, sub=1)
        for e in (-1, 1):
            g["Steel"].obox(x - f * 0.05, FY, zc + 0.2, 0.08, 0.22, 4.6, rx=e * 0.75)
            g["BrassB"].obox(x - f * 0.02, FY - e * 1.55, zc - 1.35, 0.14, 0.8, 0.14, rx=e * 0.75 + math.pi / 2)
    elif over == "antler":
        g["DarkLog"].hcyl(x, FY, zc, 0.9, 0.2, axis="x", seg=14)
        g["Leather"].box(x + f * 0.4, FY, zc - 0.1, 0.8, 0.7, 0.9)
        for e in (-1, 1):
            g["Canvas"].obox(x + f * 0.5, FY + e * 0.8, zc + 0.9, 0.16, 0.16, 1.9, rx=-e * 0.55)
            for k, (dy, dz, ln, a) in enumerate(((1.3, 1.6, 0.8, 0.1), (1.0, 1.9, 0.7, -0.5), (1.75, 1.2, 0.7, 1.2))):
                g["Canvas"].obox(x + f * 0.5, FY + e * dy, zc + dz, 0.12, 0.12, ln, rx=-e * a)
    elif over == "spear":
        g["SignRed"].hcyl(x, FY, zc, 1.1, 0.14, axis="x", seg=16)
        g["BrassB"].hcyl(x + f * 0.08, FY, zc, 0.35, 0.14, axis="x", seg=12)
        for e in (-1, 1):
            g["DarkLog"].obox(x - f * 0.06, FY, zc, 0.12, 0.12, 5.2, rx=e * 0.6)
            g["Steel"].obox(x - f * 0.06, FY + e * 1.48, zc + 2.12, 0.1, 0.3, 0.7, rx=e * 0.6)
    else:
        g["DarkLog"].box(x, FY, zc, 0.15, 3.6, 2.6)
        g["SignBlue"].box(x + f * 0.08, FY, zc + 0.45, 0.04, 3.1, 1.2)
        g["Felt"].box(x + f * 0.09, FY - 0.4, zc - 0.55, 0.04, 2.3, 0.9)
        g["Canvas"].box(x + f * 0.1, FY + 0.9, zc - 0.25, 0.04, 0.9, 1.4)
        g["SnowCap"].box(x + f * 0.11, FY - 0.1, zc + 0.1, 0.04, 1.4, 0.35)
        g["BrassB"].box(x + f * 0.05, FY, zc - 1.45, 0.12, 1.0, 0.18)


def map_board(g, ax, c, face, u, z, w=4.2, h=3.0):
    """큰 지도판(짙은 나무 틀 · 천 지도 · 땅 덩이 · 바다 · 붉은 핀 · 놋쇠 머리판)"""
    _plate(g, "DarkLog", ax, c, face, u - w / 2, u + w / 2, z - h / 2, z + h / 2, 0.1, 0.3)
    _plate(g, "Canvas", ax, c, face, u - w / 2 + 0.3, u + w / 2 - 0.3, z - h / 2 + 0.3, z + h / 2 - 0.3, 0.3, 0.34)
    for du, dz, ww, hh, m in ((-0.9, 0.3, 1.6, 1.4, "Felt"), (0.8, -0.3, 1.5, 1.2, "Felt"), (0.3, 0.7, 1.0, 0.5, "SignTeal"), (-0.6, -0.8, 1.2, 0.4, "SignBlue")):
        _plate(g, m, ax, c, face, u + du - ww / 2, u + du + ww / 2, z + dz - hh / 2, z + dz + hh / 2, 0.34, 0.37)
    for du, dz in ((-1.1, 0.5), (0.9, -0.1), (0.2, 0.8), (-0.4, -0.5)):
        _plate(g, "SignRed", ax, c, face, u + du - 0.08, u + du + 0.08, z + dz - 0.08, z + dz + 0.08, 0.37, 0.45)
    _plate(g, "BrassB", ax, c, face, u - 0.9, u + 0.9, z + h / 2 + 0.05, z + h / 2 + 0.4, 0.15, 0.25)


def globe(g, x, y, z0):
    """지구의(짙은 나무 세 발 받침 · 놋쇠 자오환 · 바다·땅 구)"""
    for k in range(3):
        a = k * 2 * math.pi / 3
        g["DarkLog"].obox(x + 0.45 * math.cos(a), y + 0.45 * math.sin(a), z0 + 1.0, 0.16, 0.16, 2.1, rz=a, ry=0.25)
    g["DarkLog"].cyl(x, y, z0 + 1.9, 0.75, 0.75, 0.12, seg=14)
    sphere(g, "SignBlue", (x, y, z0 + 2.9), 0.85, sub=2)
    for dx, dy, dz, r in ((0.45, 0.3, 0.25, 0.42), (-0.3, -0.5, -0.1, 0.38), (0.1, 0.55, -0.45, 0.3)):
        sphere(g, "Felt", (x + dx, y + dy, z0 + 2.9 + dz), r, sub=1)
    L.transformed(g, Matrix.Translation((x, y, z0 + 2.9)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(0.4, 4, "Y"),
                  lambda q: S.ring(q, "BrassB", 0, 0, -0.06, 0.95, 1.05, 0.12, n=24))


def interior3(g):
    """방 마감(판벽·겉판·줄눈·마루·벽등·탑 몸) + 방마다 초점"""
    P = _P()
    gb = _gb(g)
    pad_in = (0.45, 0.45, 0.6)
    for s in (-1, 1):
        xo, xh = s * IX1, s * (HX + 0.5)
        xs = sorted((xo, xh))
        stair_y = (4.0, 22.0)
        # 마루(아래: 받침 2.0 → 2.2 널 + 충돌 / 위: 판 위 0.04 널)
        P.plank_floor(g, xs[0], xs[1], IY0, IY1, ZB, th=ZF - ZB, mats=("WoodFloor", "Wood"))
        C((xs[0] + xs[1]) / 2, (IY0 + IY1) / 2, (ZB + ZF) / 2, xs[1] - xs[0], IY1 - IY0, ZF - ZB)
        xi = s * (IX1 - SW)
        xa, xb = sorted((xh, xi))
        P.plank_floor(g, xs[0], xs[1], IY0, stair_y[0], Z1, th=0.04, mats=("WoodFloor", "Wood"))
        P.plank_floor(g, xa, xb, stair_y[0], stair_y[1], Z1, th=0.04, mats=("WoodFloor", "Wood"))
        P.plank_floor(g, xs[0], xs[1], stair_y[1], IY1, Z1, th=0.04, mats=("WoodFloor", "Wood"))
        for y0, y1 in ((-25.8, -17.4), (1.8, 10.2)):            # 날개 문 문턱(벽 두께 — 홀 바닥과 널 사이)
            box2(g, "TrimB", *sorted((s * (HX - 0.5), xh)), y0, y1, ZB, ZF + 0.02)
        stack = [(FY - 3.05, FY + 3.05, ZF - 1, Z2 + 1)]
        for z0, z1, doors in ((ZF, ZS, ((-25.8, -17.4), (1.8, 10.2))), (Z1, Z2, ((-25.8, -17.4), (-2.2, 6.2)))):
            finish_wall(g, "x", xo, -s, IY0, IY1, z0, z1, _cuts(g, "x", xo, pad_in) + stack, seed=20 + s, no_wain=(stair_y,))
            finish_wall(g, "x", xh, s, IY0, IY1, z0, z1, [(d0 - 0.4, d1 + 0.4, z0 - 0.5, z0 + 9.9) for d0, d1 in doors], seed=23 + s)
            finish_wall(g, "y", IY0, 1, xs[0], xs[1], z0, z1, _cuts(g, "y", IY0, pad_in), seed=26 + s)
            finish_wall(g, "y", IY1, -1, xs[0], xs[1], z0, z1, _cuts(g, "y", IY1, pad_in), seed=29 + s)
            for cy in (-26.0, 30.0):
                bulge_finish(g, s * 36.0, cy, z0, z1)
        # 계단 벽 쪽 놋쇠 손잡이(두 마디)
        for (ya_, za_), (yb_, zb_) in (((4.4, ZF + 3.3), (11.4, ZF + 3.3 + 6.57)), ((13.8, ZF + 3.3 + 6.57), (21.6, Z1 + 3.0))):
            ln, ang = math.hypot(yb_ - ya_, zb_ - za_), math.atan2(zb_ - za_, yb_ - ya_)
            g["BrassB"].obox(xo - s * 0.3, (ya_ + yb_) / 2, (za_ + zb_) / 2, 0.16, ln, 0.16, rx=ang)
            for yy, zz in ((ya_ + 0.4, za_), (yb_ - 0.4, zb_)):
                g["Rail"].box(xo - s * 0.15, yy, zz - 0.15, 0.3, 0.12, 0.12)
        # 벽등(방마다 둘 이상 — 홀 쪽 벽, 문 사이)
        for z0 in (ZF, Z1):
            for y in (-14.5, 15.0):
                P.sconce(gb, "y", xh, y, z0 + 6.2, face=s)
        chimney_top(g, s)
    hearth_left(g)
    for s, z0, w, h, mz, over in ((-1, ZF, 3.0, 2.8, 3.6, "spear"), (-1, Z1, 2.6, 2.6, 3.4, "paint"),
                                  (1, ZF, 3.0, 2.8, 3.6, "antler"), (1, Z1, 2.6, 2.6, 3.4, "shield")):
        hearth_dress(g, s, z0, ZS if z0 == ZF else Z2, w, h, mz, over)
    # 길드장 방: 큰 지도판(홀 쪽 벽) · 깔개 / 서고: 지구의 · 사다리 · 깔개
    map_board(g, "x", HX + 0.5, 1, -5.1, Z1 + 4.8)
    P.rug(g, 26.6, 34.4, -14.6, -3.4, Z1 + 0.04, "SignBlue", "SignGold", "SignGold")
    globe(g, -27.6, 17.6, Z1 + 0.04)
    L.transformed(_gb(g), Matrix.Translation((-34.3, -23.7, Z1 + 0.04)) @ Matrix.Rotation(-0.14, 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                  lambda q: _P2().ladder(q, 8.4))
    P.rug(g, -33.6, -27.4, -21.4, -2.6, Z1 + 0.04, "Banner", "SignGold", "SignGold")
    # 작전실(로비 위)
    zw0, zw1 = Z1, Z2
    P.plank_floor(g, -HX + 0.5, HX - 0.5, IY0, HY0 - 0.5, Z1, th=0.04, mats=("WoodFloor", "Wood"))
    P.plank_floor(g, -GX + T, GX - T, GY0 + T, IY0, Z1, th=0.04, mats=("WoodFloor", "Wood"))
    hf = _cuts(g, "y", IY0, pad_in)
    for u0, u1 in ((-HX + 0.5, -GX + T), (GX - T, HX - 0.5)):
        finish_wall(g, "y", IY0, 1, u0, u1, zw0, zw1, hf, seed=31)
    finish_wall(g, "y", GY0 + T, 1, -GX + T, GX - T, zw0, zw1, _cuts(g, "y", GY0 + T, pad_in), seed=32)
    for s in (-1, 1):
        finish_wall(g, "x", s * (GX - T), -s, GY0 + T, IY0, zw0, zw1, [], seed=33 + s)
        for x, y_wall, f in ((s * 6.0, HY0 - 0.5, -1), (s * 10.8, IY0, 1)):
            P.sconce(gb, "x", y_wall, x, zw0 + 6.2, face=f)
    finish_wall(g, "y", HY0 - 0.5, -1, -HX + 0.5, HX - 0.5, zw0, zw1, [(-4.6, 4.6, zw0 - 0.5, zw0 + 9.9)], seed=37)
    # 로비(앞벽 · 홀 쪽 벽)
    for u0, u1 in ((-HX + 0.5, -GX + T), (GX - T, HX - 0.5)):
        finish_wall(g, "y", IY0, 1, u0, u1, ZF, ZS, _cuts(g, "y", IY0, pad_in), seed=38)
    finish_wall(g, "y", HY0 - 0.5, -1, -HX + 0.5, HX - 0.5, ZF, ZS, [(-5.8, 5.8, ZF - 0.5, ZF + 11.0), (6.8, 21.2, ZF + 2.2, ZF + 10.4),
                                                                  (-21.2, -6.8, ZF + 2.2, ZF + 10.4)], seed=39)
    for s in (-1, 1):
        P.sconce(gb, "x", IY0, s * 10.8, ZF + 6.6, face=1)
        finish_wall(g, "x", s * (GX - T), -s, GY0 + T, GY1 - 0.8, ZF, ZS, [], seed=43 + s, jm="StoneB")      # 관문 통로 옆벽
    hall3(g)


def _P2():
    sys.path.insert(0, os.path.join(HERE, "snow3"))
    import lib_int2 as P2
    return P2


def hall3(g):
    """큰 홀(사소 6): 뒷벽·앞벽 위(회랑 위) 돌 켜 줄눈 · 바둑판 둘레 두 톤 돌판 · 바깥 바닥 줄눈"""
    pad_in = (0.45, 0.45, 0.6)
    # 회랑 밑 아래 벽(판벽 + 밝은 돌 겉판 — 줄눈은 StoneB): 옆벽(날개 문 · 의뢰판 비움) · 뒷벽(문장 벽·직원 칸 비움) · 앞벽(큰 문 비움)
    for s in (-1, 1):
        finish_wall(g, "x", s * (HX - 0.5), -s, HY0 + 0.5, IY1, ZF, ZS - 0.1, [(1.4, 10.6, ZF - 0.5, ZF + 9.9), (12.2, 21.8, ZF + 2.4, ZF + 9.4)],
                    seed=45 + s, jm="StoneB")
    finish_wall(g, "y", IY1, -1, -HX + 0.5, HX - 0.5, ZF, ZS - 0.1, [(-8.7, 8.7, ZF - 0.5, ZS)], seed=47, jm="StoneB")
    finish_wall(g, "y", HY0 + 0.5, 1, -HX + 0.5, HX - 0.5, ZF, ZS - 0.1, [(-5.9, 5.9, ZF - 0.5, ZF + 11.0)], seed=48, jm="StoneB")
    ashlar(g, "y", IY1, -1, -HX + 0.5, HX - 0.5, _zs(Z1 + 0.4, ZH - 1.2, 9), _cuts(g, "y", IY1, (0.45, 0.45, 1.6)), hm="DarkStone", vm="DarkStone", tone=None, blk=4.8, seed=41)
    ashlar(g, "y", HY0 + 0.5, 1, -HX + 0.5, HX - 0.5, _zs(Z1 + 0.4, ZH - 1.2, 9), _cuts(g, "y", HY0 + 0.5, pad_in) + [(-4.6, 4.6, Z1, Z1 + 9.9)],
           hm="DarkStone", vm="DarkStone", tone=None, blk=4.8, seed=42)
    hx0, hx1, hy0, hy1 = -HX + 0.5, HX - 0.5, HY0 + 0.5, IY1
    yf, yb = hy0 + GDEP, hy1 - GDEP
    cy0 = (yf + yb) / 2
    e0, e1 = 4 * SQ + 0.4, 4 * SQ + 0.4 + SQ                 # 놋쇠 테 바깥 ~ 한 칸
    ring = [(-e1 + k * 2 * e1 / 10, cy0 + e0, 2 * e1 / 10, SQ) for k in range(10)] + [(-e1 + k * 2 * e1 / 10, cy0 - e1, 2 * e1 / 10, SQ) for k in range(10)]
    ring += [(-e1, cy0 - e0 + k * 2 * e0 / 8, SQ, 2 * e0 / 8) for k in range(8)] + [(e0, cy0 - e0 + k * 2 * e0 / 8, SQ, 2 * e0 / 8) for k in range(8)]
    for k, (x0, y0, w, d) in enumerate(ring):                  # 둘레 돌판(두 톤, 줄눈 0.08)
        g["TrimB" if k % 2 == 0 else "StoneB"].box(x0 + w / 2, y0 + d / 2, ZF + 0.06, w - 0.08, d - 0.08, 0.04)
    e0 = e1 - SQ
    for x in [hx0 + 3.0 * n for n in range(1, int((hx1 - hx0) / 3.0) + 1)]:   # 바깥 바닥 줄눈(3 칸)
        for a, b in _free(hy0, hy1, ZF, ZF + 0.1, [(cy0 - e1, cy0 + e1, ZF, ZF + 0.1)] if abs(x) < e1 else []):
            box2(g, "Mortar", x - 0.05, x + 0.05, a, b, ZF + 0.04, ZF + 0.055, coll=False)
    for y in [hy0 + 3.0 * n for n in range(1, int((hy1 - hy0) / 3.0) + 1)]:
        for a, b in _free(hx0, hx1, ZF, ZF + 0.1, [(-e1, e1, ZF, ZF + 0.1)] if abs(y - cy0) < e1 else []):
            box2(g, "Mortar", a, b, y - 0.05, y + 0.05, ZF + 0.04, ZF + 0.055, coll=False)


def detail3(g):
    for t_ in TOWERS:
        tower_detail(g, *t_)
    back_face(g)
    side_faces(g)
    steam_set(g, "y", Y0, -1, 23.75, d=1.7)
    roof_details(g)
    exterior3(g)
    interior3(g)


JOBS = [
    ("Figuren_HQ", "FiguIn", job("Figuren_HQ", figuren_in, cut=T)),
]
