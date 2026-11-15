# -*- coding: utf-8 -*-
"""
b_general.py — 2026-11-14. 설원 마을 3판: 잡화점(사고팔기, 발자국 28×28). 아트 부서원 1, A 양식(짙은 통나무).

레퍼런스(회사/설원마을_레퍼런스.md G·C): 앤더슨 상점(G1 — 가운데 무쇠 난로 + 카운터, 가운데 길), 옛 잡화점(G2 — 유리 진열 카운터),
뉘른베르크 식료품점(G3 — 매단 등), 컴벌랜드 회사 상점(G4 — 1층 큰 진열창), 뢰로스 통나무(C1·C2).
대장간(앞 박공 + 옆 굴뚝)과 멀리서 구별되게 **옆 박공**(용마루가 정면과 나란함 → 정면은 긴 처마 선) + 지붕을 뚫는 무쇠 연통 + 정면 진열창 둘.

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  벽 가운데 선 x ±12 · y ±10.5 → 안 22.8 × 19.8, 천장 11. 앞 돌 마루(깊이 2) + 계단 폭 12.
  정문 x ±5.2 높이 10(널문은 안쪽으로 90° 열어 벽에 직각 — 진열창을 가리지 않게) · 양옆 진열창 4.4×6(창턱 FZ+1.6)
  오른 뒤: 카운터 x 0..10 · y 4..6.5, NPC (5, 7.7), 뒷벽 선반 전체 · 카운터 앞 빈 바닥 x 0..10 · y -6.15..3.85
  왼: 유리 진열 카운터(왼 벽) · 가운데 왼 무쇠 난로(-4.5, -1.5, 진짜 불) → 연통이 지붕을 뚫음 · 걸상 둘 · 통
  진열창 안: 낮은 진열 단(물건) · 바깥: 오른 앞 모서리 쇠 팔 자루 간판, 앞 마루 상자·통, 뒤 증기 통
"""
import math

import lib as K
import lib_a as A
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_General"
PREFIX = "Sn3General"
VARIANT = "A"

WX, YF, YB = 12.0, -10.5, 11.0
T = LOG
HX, HY = WX + T / 2, YB + T / 2           # 벽 바깥면 12.6 · 11.1
XI, YI, YFI = WX - T / 2, YB - T / 2, YF + T / 2     # 안쪽 면 11.4 · 10.4 · -9.9
YC, HD = (YF + YB) / 2, (YB - YF) / 2 + T / 2   # 지붕 가운데 y · 반 깊이(바깥면)
Z_PLATE = FZ + CEIL + 0.9
LAND = YF - T / 2 - 1.4                   # 앞 돌 마루 앞 끝
STOVE = (-4.5, -1.5)
PIPE = (STOVE[0] - 0.45, STOVE[0] + 0.45, STOVE[1] - 0.45, STOVE[1] + 0.45)
SHOP_WIN = (4.4, 6.0, FZ + 1.6)           # 진열창 폭·높이·창턱


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    sw, sh, sz = SHOP_WIN
    wz = FZ + WIN_SILL
    holes = {"f": [(-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H), A.hole(-8.6, sz, sw, sh), A.hole(8.6, sz, sw, sh)],
             "b": [A.hole(-6.0, FZ + 7.4, 3.0, 3.6)],
             "l": [A.hole(-3.0, wz), A.hole(5.0, wz)],
             "r": [A.hole(-4.0, wz)]}
    A.log_box(g, -WX, WX, YF, YB, FZ, Z_PLATE, holes)
    for u in (-8.6, 8.6):
        A.win(g, S, "f", u, sz, sw, sh, shutters=False)
    A.win(g, S, "b", -6.0, FZ + 7.4, 3.0, 3.6)
    for u in (-3.0, 5.0):
        A.win(g, S, "l", u, wz)
    A.win(g, S, "r", -4.0, wz)
    # 옆 박공(양쪽) + 다락 창
    gz = Z_PLATE + 1.2
    for xc, face in ((-WX, -1), (WX, 1)):
        A.gable_x(g, R, xc, YC, holes=[(YC - 1.2, YC + 1.2, gz, gz + 3.0)])
        K.window(g, "y", xc, YC, gz, 2.4, 3.0, face=face, shutters=False)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=95.0, outward=False)


def inside(g):
    # 카운터 + NPC + 등록기
    zt = K.counter(g, 0.0, 10.0, 5.8, 8.3)
    K.SVC.cash_register(g, 7.6, 7.1, zt)
    bx(g, "Canvas", 1.2, 3.4, 6.4, 7.7, zt, zt + 0.5)                   # 천 두루마리 묶음
    g["Brass"].cyl(4.6, 7.0, zt, 0.4, 0.3, 0.6, seg=10)
    NPC(5.0, 8.9, FZ, 0.0)
    # 뒷벽 선반(벽 전체) + 물건(큰 덩어리)
    tops = K.I.shelf_unit(g, -11.2, 11.2, YI, FZ, 6.4, depth=0.9, levels=4, face=-1)
    for k, z in enumerate(tops):
        K.SVC.goods_row(g, -11.0, 11.0, YI - 0.45, z, seed=11 + k, depth=0.8, k_=1.5)
    # 왼 벽 유리 진열 카운터
    A.glass_case(g, -XI, -9.0, -6.0, 3.0, seed=2)
    # 무쇠 난로 + 걸상 둘 + 크래커 통
    A.iron_stove(g, *STOVE, FZ, R_TOP + 1.2)
    for x, y in ((-7.0, -0.5), (-4.5, 1.5)):
        g["Wood"].cyl(x, y, FZ + 1.5, 0.6, 0.6, 0.2, seg=12)
        for a in range(3):
            g["Wood"].cyl(x + 0.4 * math.cos(a * 2.1), y + 0.4 * math.sin(a * 2.1), FZ, 0.08, 0.08, 1.5, seg=6)
    K.SVC.barrel(g, -7.6, 4.2, FZ)
    # 진열창 안 낮은 진열 단(창 밑까지)
    for x0, x1 in ((-11.0, -6.4), (6.4, 11.0)):
        K.I.box2(g, "Timber", x0, x1, YFI, YFI + 1.6, FZ, FZ + 1.4)
        bx(g, "Wood", x0, x1, YFI, YFI + 1.6, FZ + 1.4, FZ + 1.55)
        K.SVC.goods_row(g, x0 + 0.2, x1 - 0.2, YFI + 0.8, FZ + 1.55, seed=int(x0), depth=1.2, k_=1.6)
    # 오른 앞 구석: 자루·상자 무더기(빈 바닥 밖)
    K.SVC.crate(g, 10.0, -7.6, FZ, 2.2)
    K.SVC.crate(g, 10.0, -7.6, FZ + 2.2, 1.6, rz=0.3)
    cbox(8.9, 11.1, -8.7, -6.5, FZ, FZ + 3.8)
    # 매단 등(평보에)
    for x, y in ((0.0, -5.0), (5.0, 0.0), (-7.5, 2.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def outside(g):
    # 오른 앞 모서리 쇠 팔 자루 간판(옆벽 면에 박음)
    K.hang_sign(g, HX, YF + 1.0, FZ + 9.4, along="x", arm=2.0, board=(2.6, 2.0),
                icon=lambda g_, x, y, z, f: K.SVC.sack_icon(g_, x, y, z - 0.15, face=f))
    # 앞 마루 위 상자·통(문 양옆, 진열창 아래)
    K.SVC.crate(g, -8.6, LAND + 0.7, FZ, 1.2, rz=0.2)
    K.SVC.barrel(g, 9.6, LAND + 0.7, FZ, r=0.55, h=1.8)
    K.SVC.crate(g, 8.0, LAND + 0.7, FZ, 1.1, rz=-0.15)
    # 문 양옆 바깥 등(벽에 박은 쇠 팔)
    for x in (-6.15, 6.15):
        bx(g, "Iron", x - 0.1, x + 0.1, YF - T / 2 - 1.2, YF - T / 2, FZ + 9.0, FZ + 9.2)
        K.lantern(g, x, YF - T / 2 - 1.1, FZ + 9.1, FZ + 7.8)
    # 오른 옆 뒤 증기 통 → 관이 옆벽으로(난방)
    tx, ty = HX + 1.6, 6.5
    K.steam_bundle(g, tx, ty, 0.0, h=6.0, r=1.1, gauge_face=-1, pipe_pts=[(tx - 1.1, ty, 7.0), (HX - 0.3, ty, 7.0)])


R_TOP = 0.0


def build(g):
    global R_TOP
    R = A.roof_frame_x(HD, -HX, HX, Z_PLATE, K.PITCH["A"])
    R_TOP = R.top()
    K.foundation(g, -HX - 0.3, HX + 0.3, LAND, HY + 0.3)
    K.stair(g, 0.0, LAND, 12.0, FZ)
    shell(g, R)
    for x in (-7.5, 0.0, 7.5):
        A.truss_x(g, R, x, YC)
    A.roof_x(g, R, YC, openings=[PIPE])
    inside(g)
    outside(g)
    CLEAR(-4.8, 4.8, YF + T / 2 + 0.2, -4.35, FZ + 0.15, FZ + 5.4)
    CLEAR(0.0, 10.0, -4.35, 5.65, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": (0.0, 10.0, 5.8, 8.3),
    "free": (0.0, 10.0, -4.35, 5.65),
    "walk": ((0.0, YF - 1.5), (5.0, 0.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI),
    "forge_look": STOVE,
}
