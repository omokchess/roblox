# -*- coding: utf-8 -*-
"""
b_hospital.py — 2026-11-14. 설원 마을 3판: 병원(치료 · 사망 뒤 돌아오는 곳). 아트 부서원 2, B 양식(긴 몸).

레퍼런스(회사/설원마을_레퍼런스.md H·C): 다보스 샤츠알프 요양소(H1 — 볕쬐기 회랑: 기둥 줄 위 보 → 지붕, 난간은 기둥 사이만),
다보스 네덜란드 요양소 정문(H2 — 기둥·보가 받친 차양, 넓은 계단), 같은 요양소 모서리 발코니(H3 — 기둥 축이 이어짐),
검은 숲 농가(C4 — 짙은 뼈대·50° 물매). 마을에서 유일하게 **용마루가 길 방향(x)** 인 긴 몸 + 오른쪽 볕쬐기 회랑 + 앞 박공 차양으로 멀리서 구별.

배치(블렌더, 앞 = -y, 바닥 FZ = 2). 몸채는 x 가운데 -5.5 (오른쪽 회랑까지 합친 발자국이 가운데 오게):
  몸채 벽 가운데 선 x -19..8 · y -11.6..11.6 → 안 25.8 × 22, 천장(평보 밑) 11. 용마루 x 방향, 긴 처마 0.9(앞 차양과 겹치지 않게)
  정문 x -12.6..-2.2(가운데 -7.4) 높이 10 · 앞 계단(폭 12) 위 차양: 땅에 선 기둥 넷 → 보 → 작은 박공 지붕(물매 30)
  왼쪽 = 접수: 카운터 x -17..-7 · y 3..5.5, 앞 빈 바닥 x -17..-7 · y -7.15..2.85, NPC (-12, 7.5), 뒤 약장
  오른쪽 = 병실: 침대 넷(뒷벽 둘·앞벽 둘, 머리는 벽) 사이 가운데 길 y -5..5(폭 10) · 부활 자리 x -1.5..6.5 · y -4..4(8×8)
  오른 박공벽 가운데 문(10.4) → 볕쬐기 회랑 x 8.6..19.7(맑은 폭 10): 기둥 다섯(x 19.2) → 보 → 외쪽 지붕(벽 띠장에 걸침),
  난간은 바깥 기둥 사이·뒤 끝만, 앞 끝은 계단으로 열림. 회랑 뒤 구석 증기 통 → 관이 박공벽 속으로(병실 난방)
"""
import math

from mathutils import Matrix

import lib as K
import lib_b as KB
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
    """용마루 x 방향 맞배: 제 좌표(용마루 y)로 지어 -90° 돌림(제 (x, y) → (y, -x)). 박공벽 판·평보도 같이"""
    R = K.RoofFrame(OY, OXL, OXR, Z_PLATE, K.PITCH["B"], eave=0.9)

    def local(gg):
        top = lambda m: R.zb(m) - 0.05      # noqa: E731
        for c, face in ((XL, -1), (XR, 1)):
            K.gable_boards(gg, "x", c, OY, Z_PLATE, top, face=face)
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
    for f in (-1, 1):
        K.SVC.heart_icon(g, cx, y0 + f * 0.15, zs - 3.75, face=f, s=0.95)
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
        bx(g, "Timber", x - 1.2, x + 1.2, y - 1.1, y + 1.1, FZ, FZ + 1.4)
        g["Canvas"].obox(x + 0.4, y, FZ + 1.5, 2.6, 2.0, 0.2, ry=0.1)
        g["Canvas"].obox(x - 1.2, y, FZ + 2.4, 0.25, 2.0, 2.2, ry=-0.45)
        g["Banner"].obox(x + 0.2, y, FZ + 1.66, 1.6, 2.1, 0.15, ry=0.1)
        cbox(x - 1.4, x + 1.4, y - 1.1, y + 1.1, FZ, FZ + 2.6)
    # 뒤 구석 증기 통 → 박공벽 속으로(병실 난방)
    tx, ty = 10.4, 8.3
    K.steam_bundle(g, tx, ty, FZ, h=5.6, r=1.1, gauge_face=-1, pipe_pts=[(tx - 1.1, ty, FZ + 2.6), (OXR - 0.4, ty, FZ + 2.6)])


def gable_plaque(g):
    """왼 박공(길에서 옆으로 보이는 큰 세모 면)에 둥근 놋쇠 테 판 + 심장 그림 — 1차 렌더에서 박공이 비어 보였다"""
    zc = Z_PLATE + 4.6

    def local(gg):
        gg["Brass"].hcyl(0, -0.15, 0, 2.7, 0.3, axis="y", seg=24)
        gg["Timber"].hcyl(0, -0.3, 0, 2.4, 0.3, axis="y", seg=24)
        K.SVC.heart_icon(gg, 0, -0.45, -1.7, face=-1, s=1.6)
    K.L.transformed(g, Matrix.Translation((OXL, 0, zc)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"), local)


def reception(g):
    x0, x1, y0, y1 = COUNTER
    zt = K.counter(g, x0, x1, y0, y1)
    NPC(-12.0, 7.5, FZ, 0.0)
    for x, mat in ((-15.6, "Glass"), (-15.0, "SignRed"), (-9.0, "Glass")):     # 약병·붕대
        g[mat].cyl(x, 4.4, zt, 0.3, 0.25, 0.8, seg=10)
    bx(g, "Canvas", -11.6, -10.2, 3.6, 4.6, zt, zt + 0.35)
    bx(g, "Leather", -13.4, -12.4, 3.5, 4.4, zt, zt + 0.2)
    # 뒤 약장(벽에 붙인 큰 덩어리 — 칸 판 + 병 줄)
    sy0, sy1 = IY - 1.2, IY
    bx(g, "PaintGreen", -17.4, -6.6, sy0, sy1, FZ, FZ + 6.4)
    bx(g, "Timber", -17.6, -6.4, sy0 - 0.1, sy1, FZ + 6.4, FZ + 6.8)
    for k, z in enumerate((FZ + 2.4, FZ + 4.0, FZ + 5.5)):
        bx(g, "Wood", -17.2, -6.8, sy0 - 0.15, sy1, z - 0.12, z)
        for j in range(8):
            x = -16.5 + j * 1.3
            g[("Glass", "SignRed", "Glass", "Canvas")[(j + k) % 4]].cyl(x, sy0 + 0.45, z, 0.28, 0.22, 0.7, seg=8)
    bx(g, "Timber", -17.2, -6.8, sy0 - 0.12, sy1, FZ, FZ + 1.6)          # 아래 서랍 덩이
    cbox(-17.6, -6.4, sy0 - 0.15, sy1, FZ, FZ + 6.8)


def ward(g):
    """침대 넷(머리 = 벽) + 침대 사이 작은 탁자 둘 + 칸막이 천 틀 하나 · 의사 NPC 는 두지 않음(접수 NPC 하나)"""
    for x in (0.0, 5.0):
        K.I.bed(g, x, IY - 3.2, FZ, rz=-math.pi / 2)
        K.I.bed(g, x, -IY + 3.2, FZ, rz=math.pi / 2)
    for y in (IY - 0.9, -IY + 0.9):
        bx(g, "Wood", 2.0, 3.0, y - 0.7, y + 0.7, FZ, FZ + 2.4)
        g["Glass"].cyl(2.5, y, FZ + 2.4, 0.22, 0.18, 0.6, seg=8)
    # 병실 쪽 세운 칸막이 천 틀(접수와 병실 사이, 뒷벽에서 나옴 — 길 밖)
    for y in (IY - 0.3, IY - 5.6):
        bx(g, "Timber", -2.85, -2.55, y - 0.15, y + 0.15, FZ, FZ + 6.0)
    bx(g, "Timber", -2.85, -2.55, IY - 5.75, IY - 0.15, FZ + 5.8, FZ + 6.1)
    bx(g, "Canvas", -2.78, -2.62, IY - 5.45, IY - 0.45, FZ + 1.2, FZ + 5.8)
    cbox(-2.9, -2.5, IY - 5.75, IY, FZ, FZ + 6.1)


def build(g):
    # 1 기초(몸채 + 회랑 바닥) · 앞 계단
    K.foundation(g, OXL - 0.3, GAL_X + 0.7, -OY - 0.3, OY + 0.3)
    K.stair(g, DX, -OY - 0.3, 12.0, FZ)
    # 2 벽 · 3·4 평보 · 지붕
    walls(g)
    main_roof(g)
    canopy(g)
    gallery(g)
    gable_plaque(g)
    # 6 안
    reception(g)
    ward(g)
    for x, y in ((-15.0, -2.0), (-9.5, -2.0), (-3.5, 0.0), (2.5, 0.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)
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
