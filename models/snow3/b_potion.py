# -*- coding: utf-8 -*-
"""
b_potion.py — 2026-11-14. 설원 마을 3판: 물약상점(사고팔기, 발자국 28×28). 아트 부서원 1, A 양식(짙은 통나무).

레퍼런스(회사/설원마을_레퍼런스.md P·C): 약방 "크로난"(P1 — 카운터 뒤 벽 전체 녹색 칠 약장 + 병 줄, 기둥 둘 + 머리보가 두른 "제단" 정면,
카운터 위 큰 약병 둘), 하이델베르크 약방(P2 — 아래 서랍장 격자 + 카운터 앞 저울), 아들러 약국(P3 — 지붕창 줄 → 우리는 앞 박공 큰 병 간판),
뢰로스 통나무(C1·C2). 대장간·잡화점과 구별되게 **더 가파른 앞 박공(물매 48°)** + 박공 한가운데 큰 병 그림 판 + 오른 옆 구리 증기 통.

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  벽 가운데 선 x ±11.4 · y -11..11.4 → 안 21.6 × 21.2, 천장 11. 앞 돌 마루(깊이 1.4) + 계단 폭 12.
  정문 x ±5.2 높이 10(널문 안쪽 95°) · 양옆 진열창 3.6×5.5(창 안 낮은 단에 큰 병)
  뒤: 카운터 x -5..5 · y 5.8..8.3(저울·막자사발·큰 병 둘), NPC (0, 9.05), 뒷벽 약장(아래 서랍 격자 + 위 병 선반 넷 + 기둥 둘·머리보, PaintGreen)
  카운터 앞 빈 바닥 x -5..5 · y -4.35..5.65 · 오른: 구리 증류기(큰 덩어리) · 왼: 약초 작업대 + 머리 위 말린 약초 줄
  바깥: 앞 박공 큰 병 판, 왼 앞 모서리 쇠 팔 병 간판, 오른 옆 증기 통 → 관이 옆벽으로(증류기 열)
"""
import math

from mathutils import Matrix

import lib as K
import lib_a as A
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_SILL, bx, cbox, NPC, CLEAR

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
DIST = (7.2, 0.0)


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
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=95.0, outward=False)


def cabinet(g):
    """뒷벽 약장(P1·P2): 아래 서랍장(격자 + 놋쇠 손잡이) · 위 병 선반 넷 · 양끝 + 가운데 둘 기둥 · 머리보 · 가운데 병 머리판"""
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
            bx(g, "Brass", (xa + xb) / 2 - 0.12, (xa + xb) / 2 + 0.12, yd - 0.14, yd - 0.06, zz + 0.3, zz + 0.45)
    cbox(x0, x1, yd, yw, FZ, FZ + 3.2)
    # 위 병 선반(얕음 0.8) — 뒤판 + 칸 넷
    ys = yw - 0.8
    bx(g, "PaintGreen", x0, x1, yw - 0.12, yw, FZ + 3.2, FZ + 8.6)
    for k in range(4):
        z = FZ + 3.9 + k * 1.2
        bx(g, "Wood", x0, x1, ys, yw, z - 0.12, z)
        A.jar_row(g, x0 + 0.2, x1 - 0.2, ys + 0.4, z, seed=3 * k)
    # 기둥(서랍장 위 → 머리보 밑) + 머리보 + 가운데 머리판
    for x in (x0 + 0.3, -3.6, 3.6, x1 - 0.3):
        bx(g, "PaintGreen", x - 0.3, x + 0.3, ys - 0.15, yw, FZ + 3.2, FZ + 8.6)
        bx(g, "Brass", x - 0.36, x + 0.36, ys - 0.2, yw, FZ + 3.2, FZ + 3.4)
    bx(g, "PaintGreen", x0 - 0.2, x1 + 0.2, ys - 0.35, yw, FZ + 8.6, FZ + 9.3)
    bx(g, "Brass", x0 - 0.25, x1 + 0.25, ys - 0.4, yw, FZ + 9.3, FZ + 9.45)
    bx(g, "PaintGreen", -2.2, 2.2, yw - 0.5, yw, FZ + 9.45, FZ + 10.6)
    K.L.transformed(g, Matrix.Translation((0, yw - 0.5, FZ + 9.5)) @ Matrix.Scale(0.42, 4) @ Matrix.Translation((0, -(yw - 0.5), -(FZ + 9.5))),
                    lambda q: K.SVC.flask_icon(q, 0.0, yw - 0.5, FZ + 9.5, face=-1))


def shop(g):
    zt = K.counter(g, -5.0, 5.0, 5.8, 8.3)
    K.SVC.balance_scale(g, -2.6, 6.9, zt)
    K.SVC.mortar(g, 1.2, 7.2, zt)
    for x, liq in ((-4.0, "SignRed"), (3.9, "GlowTeal")):           # 카운터 위 큰 약병 둘(P1)
        A.flask(g, x, 7.0, zt, liq, r=0.55, h=1.5)
    NPC(0.0, 9.05, FZ, 0.0)
    cabinet(g)
    # 오른: 구리 증류기(옛 서비스 키트 부품을 바닥 높이로 올려 씀)
    dx, dy = DIST
    K.L.transformed(g, Matrix.Translation((0, 0, FZ - K.SVC.FZ)), lambda q: K.SVC.distiller(q, dx, dy))
    bx(g, "Stone", dx - 1.9, dx + 1.9, dy - 1.9, dy + 1.9, FZ, FZ + 0.25)
    cbox(dx - 1.6, dx + 1.6, dy - 3.2, dy + 3.2, FZ, FZ + 9.0)
    # 왼: 약초 작업대(벽에 붙음) + 막자사발·병
    ax0, ax1, ay0, ay1 = -XI, -8.4, -4.0, 4.0
    for x in (ax0 + 0.3, ax1 - 0.3):
        for y in (ay0 + 0.3, ay1 - 0.3):
            bx(g, "Timber", x - 0.2, x + 0.2, y - 0.2, y + 0.2, FZ, FZ + 3.0)
    bx(g, "Timber", ax0 + 0.1, ax1 - 0.1, ay0 + 0.1, ay1 - 0.1, FZ + 0.6, FZ + 0.8)
    bx(g, "Wood", ax0, ax1, ay0, ay1, FZ + 3.0, FZ + 3.25)
    K.SVC.mortar(g, -9.5, -2.4, FZ + 3.25)
    K.SVC.bottle_col(g, -10.2, -0.8, 3.6, FZ + 3.25, seed=7)
    cbox(ax0, ax1, ay0, ay1, FZ, FZ + 3.25)
    # 머리 위 말린 약초(앞 평보에 매닮)
    for k in range(6):
        K.SVC.herb_bundle(g, -9.5 + k * 1.2, -5.0 + (0.25 if k % 2 else -0.25), Z_PLATE - 1.1, mat=("Felt", "Verdigris", "Canvas")[k % 3])
    # 진열창 안 낮은 단 + 큰 병
    for x0, x1 in ((-10.6, -5.8), (5.8, 10.6)):
        K.I.box2(g, "Timber", x0, x1, YFI, YFI + 1.4, FZ, FZ + 1.6)
        bx(g, "Wood", x0, x1, YFI, YFI + 1.4, FZ + 1.6, FZ + 1.75)
        for k, liq in enumerate(("SignPurple", "SignTeal", "SignRed")):
            A.flask(g, x0 + 0.9 + k * 1.5, YFI + 0.7, FZ + 1.75, liq, r=0.5 - 0.1 * (k % 2), h=1.6 - 0.4 * (k % 2))
    for x, y in ((0.0, -5.0), (0.0, 1.0), (-7.0, 7.0), (7.0, 7.0)):
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
    # 오른 옆 증기 통 → 관이 옆벽으로(증류기에 열)
    tx, ty = HALF + 1.6, 3.5
    K.steam_bundle(g, tx, ty, 0.0, h=6.8, r=1.1, gauge_face=-1, pipe_pts=[(tx - 1.1, ty, 7.4), (HALF - 0.3, ty, 7.4)])


def build(g):
    R = K.RoofFrame(HALF, YF - T / 2, YB + T / 2, Z_PLATE, PITCH)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, LAND, YB + T / 2 + 0.3)
    K.stair(g, 0.0, LAND, 12.0, FZ)
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
    "counter": (-5.0, 5.0, 5.8, 8.3),
    "free": (-5.0, 5.0, -4.35, 5.65),
    "walk": ((0.0, YF - 1.5), (0.0, 0.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YBI),
    "forge_look": DIST,
}
