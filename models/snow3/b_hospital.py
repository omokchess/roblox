# -*- coding: utf-8 -*-
"""
b_hospital.py — 2026-11-14. 설원 마을 3판: 병원(치료 · 사망 뒤 돌아오는 곳). 아트 부서원 2, B 양식(긴 몸).
2026-11-18 아트 2팀: 구멍 막이(박공 꼭대기 띠·처마 막이판) · 김 표지 뺌(회랑 지붕 밑이라 위가 막힘) · 내부 다시(lib_int2 소품).
2026-11-24 2팀 2차(비평 1차): 흰 칠 세로 널 접수대 · 흰 칠 유리문 약장(붕대·홑청·사기 대야, 병 1/4, 하트 판 1.5배) — 녹색은 물약상점에만 ·
  고리는 놋쇠 사슬 둘로 · 심장 기관은 짙은 쇠 받침 + 리벳, 우리가 문을 봄 · 부활 판 석회색 + 굵은 별살 · 볕쬐기 의자 다시.

레퍼런스(회사/설원마을_레퍼런스.md H·C·내부 2팀 HS): 다보스 샤츠알프 요양소(H1 — 볕쬐기 회랑: 기둥 줄 위 보 → 지붕, 난간은 기둥 사이만),
다보스 네덜란드 요양소 정문(H2 — 기둥·보가 받친 차양, 넓은 계단), 같은 요양소 모서리 발코니(H3 — 기둥 축이 이어짐),
검은 숲 농가(C4 — 짙은 뼈대·50° 물매). 내부: 19세기 병동(침대 머리 = 벽, 가운데 길) · 약방 약장.
마을에서 유일하게 **용마루가 길 방향(x)** 인 긴 몸 + 오른쪽 볕쬐기 회랑 + 앞 박공 차양으로 멀리서 구별.

배치(블렌더, 앞 = -y, 바닥 FZ = 2, 널 마루 윗면 FL = 2.08). 몸채는 x 가운데 -5.5 (오른쪽 회랑까지 합친 발자국이 가운데 오게):
  몸채 벽 가운데 선 x -19..8 · y -11.6..11.6 → 안 25.8 × 22, 천장(평보 밑) 11. 용마루 x 방향, 긴 처마 0.9(앞 차양과 겹치지 않게)
  정문 x -12.6..-2.2(가운데 -7.65) 높이 10 · 앞 계단(폭 12) 위 차양: 땅에 선 기둥 넷 → 보 → 작은 박공 지붕(물매 30)
  왼쪽 = 접수: 판넬 카운터(대리석 상판) x -17..-7 · y 3..5.5, 앞 빈 바닥 x -17..-7 · y -7.15..2.85, NPC (-12, 7.5), 뒤 녹색 약장(서랍·병·단지)
  오른쪽 = 병실: 문에 들어서면 정면 오른쪽에 **부활 자리 위 '되살아나는 고리'**(놋쇠 톱니 고리 + 붉은 빛 테 + 심장, 평보에 매닮) ·
     바닥 놋쇠·대리석 둥근 판 · 앞 구석 **심장 톱니 기관**(쇠살 우리 속 붉은 심장 + 양옆 톱니 → 구리 관이 천장 따라 고리로) ·
     침대 셋(뒷벽 둘·앞벽 하나, 머리 = 벽) · 머리맡 탁자(대야) · 약병 걸이대 · 접이 칸막이
  부활 자리 x -1.5..6.5 · y -4..4(8×8, 비움) — 고리 밑은 바닥 + 5.5 위
  오른 박공벽 가운데 문(10.4) → 볕쬐기 회랑 x 8.6..19.7(맑은 폭 10): 기둥 다섯(x 19.2) → 보 → 외쪽 지붕(벽 띠장에 걸침),
  난간은 바깥 기둥 사이·뒤 끝만, 앞 끝은 계단으로 열림. 회랑 뒤 구석 증기 통 → 관이 박공벽 속으로(병실 난방)
"""
import math

from mathutils import Matrix

import lib as K
import lib_b as KB
import lib_int2 as N
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Hospital"
PREFIX = "Sn3Hospital"
VARIANT = "B"

XL, XR, YF, YB = -19.0, 8.0, -11.6, 11.6
T = LOG
OXL, OXR, OY = XL - T / 2, XR + T / 2, YB + T / 2         # 바깥면 -19.6 · 8.6 · ±12.2
IXL, IXR, IY = XL + T / 2, XR - T / 2, YB - T / 2         # 안쪽 면 -18.4 · 7.4 · ±11.0
Z_PLATE = FZ + CEIL + 0.9
STONE_TO = FZ + 2.5                      # 가벼운 요양소 — 돌 아랫벽 낮게
DX = -7.65                               # 정문 가운데(통로 재는 0.5 격자 가운데에 맞춤 — -7.4 면 격자 탓에 9.9 로 잼)
COUNTER = (-17.0, -7.0, 3.0, 5.5)
FREE = (-17.0, -7.0, -7.15, 2.85)
RESPAWN = (-1.5, 6.5, -4.0, 4.0)
GAL_X = 19.2                             # 회랑 바깥 기둥 줄
GAL_POSTS = (-10.4, -5.2, 0.0, 5.2, 10.4)   # 끝 기둥 ±10.4 — 회랑 지붕이 몸채 처마도리(|y| 11.1~12.2)와 겹치지 않는 폭 안
LEDGER_TOP = Z_PLATE                     # 회랑 지붕 띠장 = 박공벽 머리보 바깥면에 박음(13.0~13.9, 회랑 문틀 위)
GAL_BEAM_TOP = FZ + 8.4                  # 물매 약 18°, 보 밑 바닥 위 7.5
TIES = (-15.0, -9.5, -3.5, 2.5)          # 몸채 평보(세계 x)
CANOPY = (-15.0, 0.2, -16.6, -13.2)      # 차양 기둥 x0 x1 y0 y1(땅 위)
FL = FZ + 0.08                           # 널 마루 윗면
HALO = (2.5, 0.0, FZ + 8.1)             # 되살아나는 고리 가운데(부활 자리 위, x = 2.5 평보에 매닮)

# holes.py: 일부러 트인 자리 — 볕쬐기 회랑(H1, 한쪽이 트인 지붕 밑)과 정문 차양 밑(H2). 몸채 안은 다 막는다
OPEN_ZONES = [(OXR + 0.05, 23.0, -16.0, 16.0, 0.0, 40.0, "볕쬐기 회랑(외쪽 지붕 밑, 바깥 기둥 사이 난간만 — H1)"),
              (-17.0, 2.5, -19.0, -OY - 0.05, 0.0, 40.0, "정문 차양 밑(기둥·보가 받친 열린 박공 — H2)")]


def walls(g):
    hole = lambda u: (u - WIN_W / 2, u + WIN_W / 2, FZ + WIN_SILL, FZ + WIN_SILL + K.WIN_H)     # noqa: E731
    door = (DX - MAIN_W / 2, DX + MAIN_W / 2, FZ, FZ + MAIN_H)
    side = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    plan = (("x", YF, (XL, XR), [door, hole(4.8)], -1),                 # 앞 왼 창은 밖으로 접은 문짝이 덮어 빼고 병실 창만
            ("x", YB, (XL, XR), [hole(-4.5), hole(2.5)], 1),            # 약장 뒤는 창 없음
            ("y", XL, (YF, YB), [hole(-5.0), hole(5.0)], -1),
            ("y", XR, (YF, YB), [side, hole(-8.5)], 1))                 # 회랑 쪽: 뒤 구석은 증기 통 자리
    for ax, c, (u0, u1), holes, face in plan:
        K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=STONE_TO, face=face)
        for h in holes:
            if h[2] > FZ + 1:
                K.window(g, ax, c, (h[0] + h[1]) / 2, FZ + WIN_SILL, face=face, shutters=ax == "y" and c == XL)   # 앞(문짝)·뒤·회랑 쪽은 덧창 없이
    K.door_open(g, "x", YF, DX, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)
    K.door_open(g, "y", XR, 0.0, MAIN_W, MAIN_H, FZ, face=1, open_deg=95.0)      # 회랑 문(바깥으로 벽에 직각 — 회랑 쪽 막지 않게 벽 가까이)


def main_roof(g):
    """용마루 x 방향 맞배: 제 좌표(용마루 y)로 지어 -90° 돌림(제 (x, y) → (y, -x)). 박공벽 판·평보도 같이.
    (2팀) 같은 돌림 안에서 박공 꼭대기 띠 · 처마 막이판(서까래 사이 틈 — 공용 roof_gable/gable_boards 의 틈)"""
    R = K.RoofFrame(OY, OXL, OXR, Z_PLATE, K.PITCH["B"], eave=0.9)

    def local(gg):
        top = lambda m: R.zb(m) - 0.05      # noqa: E731
        for c, face in ((XL, -1), (XR, 1)):
            K.gable_boards(gg, "x", c, OY, Z_PLATE, top, face=face)
            N.gable_seal(gg, "x", c, R, mat="Timber")
        N.eave_block(gg, R, XL, XR)
        for xt in TIES:
            K.tie_truss(gg, xt, R)
        K.roof_gable(gg, R)
    K.L.transformed(g, Matrix.Rotation(-math.pi / 2, 4, "Z"), local)
    return R


def canopy(g):
    """정문 차양(H2): 땅 위 받침돌 + 기둥 넷 → 옆 보(y) → 박공 지붕(물매 30, 용마루 y) + 앞·뒤 평보, 뒤는 판으로 막고 앞 평보 밑 심장 간판"""
    x0, x1, y0, y1 = CANOPY
    zb_ = FZ + 9.7                        # 보 밑(땅에서 11.7)
    zp = zb_ + 0.9                        # 보 윗면 = 차양 지붕 벽 윗면
    for x in (x0, x1):
        for y in (y0, y1):
            K.post(g, x, y, 0.0, zb_, s=1.0)
        bx(g, "DarkLog", x - 0.5, x + 0.5, y0 - 0.5, y1 + 0.5, zb_, zp)
    half = (x1 - x0) / 2 + 0.5
    cx = (x0 + x1) / 2
    R = K.RoofFrame(half, y0 - 0.5, y1 + 0.5, zp, 30.0, eave=0.9, eave_g=0.4)

    def local(gg):
        K.tie_truss(gg, y0, R)
        K.tie_truss(gg, y1, R)
        K.roof_gable(gg, R)
        K.gable_boards(gg, "x", y1 + 0.1, half, zp, lambda m: R.zb(m) - 0.05, face=1)
        for s in (-1, 1):                 # 까치발(기둥 → 평보)
            K.brace(gg, "x", y0, s * (half - 1.0), zb_ - 2.4, s * (half - 3.4), zb_, s=0.5)
    K.L.transformed(g, Matrix.Translation((cx, 0, 0)), local)
    # 앞 평보 밑 심장 간판(쇠 막대 둘로 매닮)
    zs = zb_ - 0.0
    for dx in (-2.4, 2.4):
        bx(g, "Iron", cx + dx - 0.06, cx + dx + 0.06, y0 - 0.06, y0 + 0.06, zs - 1.6, zs)
    bx(g, "Timber", cx - 3.3, cx + 3.3, y0 - 0.15, y0 + 0.15, zs - 3.8, zs - 1.6)
    bx(g, "Brass", cx - 3.45, cx + 3.45, y0 - 0.2, y0 + 0.2, zs - 1.65, zs - 1.45)
    for f in (-1, 1):                                                             # 녹십자(2026-11-28 사용자: 하트 → 녹십자)
        N.green_cross(g, cx, y0 + f * 0.15, zs - 2.7, s=1.2, depth=0.2, plate=True, face=f)
    for x in (cx - 4.6, cx + 4.6):
        K.lantern(g, x, y0, zb_, zb_ - 2.0)


def gallery(g):
    """볕쬐기 회랑(H1): 받침돌 위 기둥 다섯 → 보(y) / 박공벽 띠장 → 외쪽 지붕. 난간 = 바깥 기둥 사이 · 뒤 끝(벽 ~ 난간 기둥 ~ 모서리 기둥)"""
    zb_ = GAL_BEAM_TOP - 0.9
    for y in GAL_POSTS:
        K.post(g, GAL_X, y, FZ, zb_, s=1.0)
    bx(g, "DarkLog", GAL_X - 0.5, GAL_X + 0.5, -GAL_POSTS[-1] - 0.6, GAL_POSTS[-1] + 0.6, zb_, GAL_BEAM_TOP)
    for y in GAL_POSTS:                   # 까치발(기둥 → 보)
        for s in (-1, 1):
            if abs(y + s * 2.0) <= GAL_POSTS[-1]:
                KB.member(g, "DarkLog", (GAL_X, y, zb_ - 2.0), (GAL_X, y + s * 2.0, zb_), 0.45, 0.45)
    # 띠장(박공벽 머리보 바깥면에 박은 보 — 회랑 지붕 높은 쪽을 받침)
    YE = GAL_POSTS[-1] + 0.6
    bx(g, "DarkLog", OXR, OXR + 0.8, -YE, YE, LEDGER_TOP - 0.9, LEDGER_TOP)
    # 평보(띠장 → 보, 기둥마다) — 지붕 서까래를 가로로 묶음
    for y in GAL_POSTS:
        yy = max(-OY + 0.4, min(OY - 0.4, y))
        bx(g, "DarkLog", OXR + 0.8, GAL_X - 0.5, yy - 0.4, yy + 0.4, GAL_BEAM_TOP - 0.7, GAL_BEAM_TOP)
    sl = (LEDGER_TOP - GAL_BEAM_TOP) / (GAL_X - OXR - 0.4)
    KB.shed_roof(g, "y", -YE + 0.3, YE - 0.3, OXR + 0.4, GAL_X + 0.5, LEDGER_TOP, GAL_BEAM_TOP - sl * 0.5, eave=1.2, side_eave=0.3)
    # 난간: 바깥 기둥 사이
    for a, b in zip(GAL_POSTS, GAL_POSTS[1:]):
        KB.railing(g, "y", GAL_X, a + 0.5, b - 0.5, FZ)
    # 뒤 끝: 벽 ~ 난간 기둥 ~ 모서리 기둥
    rp, ry = 13.9, GAL_POSTS[-1]
    K.post(g, rp, ry, FZ, FZ + 4.0, s=0.8)
    KB.railing(g, "x", ry, OXR, rp - 0.4, FZ)
    KB.railing(g, "x", ry, rp + 0.4, GAL_X - 0.5, FZ)
    # 앞 끝 계단(회랑으로 오르는 길)
    K.stair(g, (OXR + GAL_X) / 2 + 0.1, -OY - 0.3, 9.6, FZ)
    # 볕쬐기 의자 둘(바깥을 봄)
    for y in (-6.5, 3.5):
        x = 15.8
        N.put(g, x, y, FZ, math.pi / 2, N.deck_chair, "Felt")
        cbox(x - 1.4, x + 1.4, y - 1.1, y + 1.1, FZ, FZ + 2.6)
    # 뒤 구석 증기 통 → 박공벽 속으로(병실 난방). (2팀) 김 표지는 뺌 — 회랑 지붕 밑이라 위가 막힘
    tx, ty = 10.4, 8.3
    N.no_vent(g, K.steam_bundle, tx, ty, FZ, h=5.6, r=1.1, gauge_face=-1, pipe_pts=[(tx - 1.1, ty, FZ + 2.6), (OXR - 0.4, ty, FZ + 2.6)])


def gable_plaque(g):
    """왼 박공(길에서 옆으로 보이는 큰 세모 면)에 둥근 놋쇠 테 판 + 심장 그림 — 1차 렌더에서 박공이 비어 보였다"""
    zc = Z_PLATE + 4.6

    def local(gg):
        gg["Brass"].hcyl(0, -0.15, 0, 2.7, 0.3, axis="y", seg=24)
        gg["Timber"].hcyl(0, -0.3, 0, 2.4, 0.3, axis="y", seg=24)
        gg["Paint"].hcyl(0, -0.5, 0, 2.15, 0.1, axis="y", seg=24)
        N.green_cross(gg, 0, -0.55, 0, s=2.5, depth=0.3, face=-1)                 # 녹십자(2026-11-28)
    K.L.transformed(g, Matrix.Translation((OXL, 0, zc)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"), local)


def reception(g):
    """접수: 흰 칠 세로 널 접수대(대리석 상판 · 앞 하트 판) + 입원 장부·잉크·종·붕대 두루마리 · 뒷벽 흰 칠 약장(아래 서랍 둘 줄 ·
    위 유리문 칸 둘 — 붕대 두루마리 · 접은 홑청 더미 · 사기 대야 · 병은 1/4) + 머리 하트 판(놋쇠 테, 1.5배)"""
    x0, x1, y0, y1 = COUNTER
    zt = N.board_counter(g, x0, x1, y0, y1, FZ)
    NPC(-12.0, 7.5, FZ, 0.0)
    N.book(g, -12.4, 4.1, zt, w=1.0, d=1.4, cover="SignRed", open_=True)
    g["DarkStone"].cyl(-11.2, 3.6, zt, 0.2, 0.17, 0.32, seg=8)
    g["Canvas"].obox(-11.15, 3.62, zt + 0.7, 0.08, 0.3, 1.0, rx=0.35)
    g["Brass"].cyl(-8.0, 4.0, zt, 0.4, 0.34, 0.1, seg=10)
    g["Brass"].cyl(-8.0, 4.0, zt + 0.1, 0.3, 0.12, 0.36, seg=10)
    for x in (-15.9, -15.3, -14.7):                                              # 붕대 두루마리(굵게)
        g["Canvas"].hcyl(x, 4.4, zt + 0.32, 0.32, 0.5, axis="y", seg=8)
        g["Paint"].hcyl(x, 4.4, zt + 0.32, 0.12, 0.54, axis="y", seg=6)
    N.jar(g, -9.6, 4.6, zt, r=0.4, h=1.0, band="SignRed")
    # 뒷벽 흰 칠 약장(y 9.6..11)
    sx0, sx1, sy0, sy1 = -17.4, -6.6, IY - 1.4, IY
    bx(g, "Paint", sx0 + 0.1, sx1 - 0.1, sy0 + 0.2, sy1, FZ, FZ + 3.0)
    bx(g, "DarkLog", sx0, sx1, sy0 + 0.1, sy1, FZ, FZ + 0.3)
    for z in (FZ + 0.45, FZ + 1.7):                                              # 서랍 둘 줄 × 다섯(틀 · 놋쇠 손잡이 · 이름표)
        for i in range(5):
            xa = sx0 + 0.3 + i * (sx1 - sx0 - 0.6) / 5
            xb = xa + (sx1 - sx0 - 0.6) / 5
            bx(g, "Paint", xa + 0.08, xb - 0.08, sy0 + 0.06, sy0 + 0.2, z, z + 1.1)
            g["Brass"].box((xa + xb) / 2, sy0 + 0.0, z + 0.4, 0.5, 0.12, 0.14)
            bx(g, "Canvas", (xa + xb) / 2 - 0.3, (xa + xb) / 2 + 0.3, sy0 + 0.02, sy0 + 0.06, z + 0.72, z + 0.95)
    bx(g, "Marble", sx0, sx1, sy0 - 0.05, sy1, FZ + 3.0, FZ + 3.2)
    bx(g, "Paint", sx0 + 0.3, sx1 - 0.3, sy1 - 0.18, sy1, FZ + 3.2, FZ + 8.4)
    xs = (sx0 + 0.2, -14.7, -12.0, -9.3, sx1 - 0.2)
    for x in xs:
        bx(g, "Paint", x - 0.2, x + 0.2, sy0 + 0.25, sy1, FZ + 3.2, FZ + 8.4)
    for z in (FZ + 4.8, FZ + 6.5):
        bx(g, "Wood", sx0 + 0.4, sx1 - 0.4, sy0 + 0.35, sy1 - 0.18, z - 0.16, z)
    for a, b in zip(xs, xs[1:]):                                                 # 유리문 테(칸마다 문 둘: 놋쇠 테 + 가운데 살 + 맑은 유리)
        for za, zb in ((FZ + 3.3, FZ + 6.3), (FZ + 6.45, FZ + 8.3)):
            m = (a + b) / 2
            for ca, cb in ((a + 0.2, m - 0.02), (m + 0.02, b - 0.2)):
                for e0, e1 in ((ca, ca + 0.12), (cb - 0.12, cb)):
                    bx(g, "Brass", e0, e1, sy0 + 0.12, sy0 + 0.22, za, zb)
                for zz in (za, zb - 0.12):
                    bx(g, "Brass", ca, cb, sy0 + 0.12, sy0 + 0.22, zz, zz + 0.12)
                bx(g, "WinGlass", ca + 0.12, cb - 0.12, sy0 + 0.15, sy0 + 0.19, za + 0.12, zb - 0.12)
            g["Brass"].box(m - 0.18, sy0 + 0.06, (za + zb) / 2, 0.1, 0.12, 0.4)
            g["Brass"].box(m + 0.18, sy0 + 0.06, (za + zb) / 2, 0.1, 0.12, 0.4)
    bx(g, "DarkLog", sx0 - 0.15, sx1 + 0.15, sy0 + 0.1, sy1, FZ + 8.4, FZ + 8.9)
    bx(g, "Brass", sx0 - 0.17, sx1 + 0.17, sy0 + 0.05, sy0 + 0.15, FZ + 8.5, FZ + 8.64)
    g["Brass"].hcyl(-12.0, sy0 + 0.12, FZ + 10.0, 1.42, 0.12, axis="y", seg=18)    # 머리 하트 판(1.5배)
    g["Paint"].hcyl(-12.0, sy0 + 0.05, FZ + 10.0, 1.28, 0.15, axis="y", seg=18)
    N.green_cross(g, -12.0, sy0 - 0.02, FZ + 10.0, s=1.5, depth=0.15, face=-1)   # 머리 녹십자 판(2026-11-28 하트 → 녹십자)
    cbox(sx0 - 0.15, sx1 + 0.15, sy0, sy1, FZ, FZ + 8.9)
    yy = sy0 + 0.75                                                              # 칸 안: 붕대 · 홑청 · 대야 · 병(1/4)
    for z, items in ((FZ + 3.2, ("roll", "linen", "basin", "bottle")), (FZ + 4.8, ("linen", "roll", "roll", "basin")),
                     (FZ + 6.5, ("basin", "linen", "bottle", "roll"))):
        for bay, (a, b) in enumerate(zip(xs, xs[1:])):
            kind = items[bay]
            cx = (a + b) / 2
            if kind == "roll":
                for k in range(3):
                    g["Canvas"].hcyl(cx - 0.75 + k * 0.75, yy, z + 0.32, 0.3, 0.55, axis="y", seg=8)
            elif kind == "linen":
                for k in range(3):
                    bx(g, ("Paint", "Canvas", "Paint")[k], cx - 0.95 + 0.04 * k, cx + 0.95 - 0.04 * k, yy - 0.35, yy + 0.35, z + k * 0.3, z + k * 0.3 + 0.28)
            elif kind == "basin":
                for k, dx in enumerate((-0.6, 0.6)):
                    g["Paint"].cyl(cx + dx, yy, z, 0.35, 0.55, 0.32, seg=12)
                    g["SignBlue"].cyl(cx + dx, yy, z + 0.32, 0.56, 0.56, 0.05, seg=12)
            else:
                for k, (dx, liq) in enumerate(((-0.6, "SignRed"), (0.1, "Verdigris"), (0.7, "SignBlue"))):
                    N.bottle(g, cx + dx, yy, z, liq, r=0.24, h=1.0 + 0.15 * k)


def ward(g):
    """병실: 침대 셋(머리 = 벽) · 머리맡 탁자(대야·병) · 약병 걸이대 · 접이 칸막이(접수와 병실 사이, 뒤) · 부활 자리 둥근 판 ·
    되살아나는 고리(평보 x 2.5 에 매닮) · 앞 구석 심장 톱니 기관 → 구리 관(천장 따라) → 고리"""
    for x in (-0.6, 5.0):                                                       # 뒷벽 침대 둘(머리 = 뒷벽)
        N.put(g, x, IY - 3.0, FL, 0.0, N.bed, 3.6, 6.0, "Canvas", "Paint", "DarkLog", "Wood", 3.0, 2.5)
        cbox(x - 1.8, x + 1.8, IY - 6.0, IY, FZ, FL + 2.4)
    N.put(g, 5.0, -IY + 3.0, FL, math.pi, N.bed, 3.6, 6.0, "Canvas", "Paint", "DarkLog", "Wood", 3.0, 2.5)   # 앞벽 침대(창 밑 — 머리판 낮게)
    cbox(3.2, 6.8, -IY, -IY + 6.0, FZ, FL + 2.4)
    for x, y, rz in ((2.2, IY - 0.75, 0.0), (2.5, -IY + 0.75, math.pi)):           # 머리맡 탁자 + 대야·병
        N.put(g, x, y, FL, rz, N.nightstand)
        cbox(x - 0.75, x + 0.75, y - 0.65, y + 0.65, FZ, FL + 2.2)
        g["Brass"].cyl(x, y, FL + 2.2, 0.32, 0.5, 0.3, seg=10)
        N.bottle(g, x + 0.45, y + 0.1, FL + 2.2, "Verdigris", r=0.2, h=0.8)
    N.put(g, 2.2, 6.6, FL, 0.0, N.drip_stand)                                   # 약병 걸이대(뒤 침대 사이)
    cbox(1.6, 2.8, 6.0, 7.2, FZ, FL + 5.9)
    N.put(g, -4.6, 7.4, FL, math.pi / 2, N.folding_screen, 3, 1.7, 5.2)        # 접이 칸막이(접수 뒤 ↔ 병실)
    cbox(-5.3, -3.9, 5.0, 9.8, FZ, FL + 5.5)
    # 부활 자리 둥근 판(바닥 — 무릎 아래, 비울 자리 안 괜찮음)
    cx, cy = (RESPAWN[0] + RESPAWN[1]) / 2, (RESPAWN[2] + RESPAWN[3]) / 2
    g["Brass"].cyl(cx, cy, FL, 3.85, 3.85, 0.05, seg=24)
    g["StoneTrim"].cyl(cx, cy, FL + 0.05, 3.55, 3.55, 0.05, seg=24)
    for k in range(4):                                                          # 여덟 갈래 놋쇠 별(나침반 무늬)
        g["Brass"].obox(cx, cy, FL + 0.115, 5.6 if k % 2 == 0 else 4.2, 0.6, 0.03, rz=k * math.pi / 4 + math.pi / 8)
    g["SignRed"].cyl(cx, cy, FL + 0.13, 0.9, 0.9, 0.03, seg=16)
    # 되살아나는 고리(부활 자리 위) + 매단 쇠 막대 둘 + 빛
    hx, hy, hz = HALO
    N.halo(g, hx, hy, hz, r=2.3)
    for dx in (-1.0, 1.0):                                                       # 놋쇠 사슬 둘(마디 0.35) — 평보에서
        N.chain(g, hx + dx, hy, hz + math.sqrt(2.3 ** 2 - dx * dx) - 0.3, Z_PLATE - 0.9)
    g["LampPt"].box(hx, hy - 1.0, hz, 0.3, 0.3, 0.3)
    # 심장 톱니 기관(앞 구석, 방을 봄) → 구리 관이 위로 → 천장 따라 → 고리 왼 테로
    ex, ey = 0.0, -IY + 2.0
    N.put(g, ex, ey, FL, -1.31, N.heart_engine)                                  # 심장 우리가 정문(왼 앞)을 봄
    cbox(ex - 1.8, ex + 1.8, ey - 1.95, ey + 1.95, FZ, FL + 6.75)
    K.S.pipe(g, [(ex, ey, FL + 6.75), (ex, ey, 12.3), (ex, hy, 12.3), (ex, hy, hz + 0.6)], 0.25, mat="Copper")
    # 등(평보에 매닮)
    for x, y in ((-15.0, -2.0), (-9.5, -2.0), (-3.5, -6.0), (-3.5, 6.5), (2.5, 7.5), (2.5, -7.5)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def build(g):
    # 1 기초(몸채 + 회랑 바닥) · 앞 계단
    K.foundation(g, OXL - 0.3, GAL_X + 0.7, -OY - 0.3, OY + 0.3)
    K.stair(g, DX, -OY - 0.3, 12.0, FZ)
    N.plank_floor(g, IXL, IXR, -IY, IY, FZ)                                     # (2팀) 널 마루
    # 2 벽 · 3·4 평보 · 지붕
    walls(g)
    main_roof(g)
    canopy(g)
    gallery(g)
    gable_plaque(g)
    # 6 안
    reception(g)
    ward(g)
    CLEAR(DX - 5.0, DX + 5.0, -IY + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.15, FZ + 0.15, FZ + 5.4)
    CLEAR(*RESPAWN, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((DX, YF - 1.5), (-12.0, -2.0)),
    "inside": (IXL, IXR, YF - T / 2 - 1.5, IY),
    "forge_look": (5.0, 6.0),                # 1인칭 안 렌더가 바라볼 병실 침대
    # 부활 자리(사망 뒤 돌아오는 곳): 블렌더 (x, y, z, yaw 도 — 0 = 앞 -y). 빈 바닥 8×8 = respawn_free
    "respawn": (2.5, 0.0, FZ, 0.0),
    "respawn_free": RESPAWN,
}
