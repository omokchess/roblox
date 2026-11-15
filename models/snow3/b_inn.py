# -*- coding: utf-8 -*-
"""
b_inn.py — 2026-11-14. 설원 마을 3판: 여관(쉬기·저장, 발자국 40×32, 2층). 아트 부서원 1, A 양식(짙은 통나무).

레퍼런스(회사/설원마을_레퍼런스.md I·C): 랑엔 "히르셴" 여관(I1 — 두꺼운 지붕 눈·박공 발코니(기둥 위 보 → 바닥 → 난간은 기둥 사이)·덧창 줄),
베르나우 "뢰슬레"(I2 — 길게 누운 2층 몸 + 목조 발코니), 몬테로사 호텔(I3 — 규칙적인 창 줄), 시모니 산장(I4 — 문 옆 표지판·바깥 벤치),
뢰로스 2층 통나무집(C2 — 짙은 갈색 통나무 + 회색 밑단, 성긴 창).
멀리서 구별: 마을에서 가장 큰 2층 앞 박공 + 앞 전체 2층 발코니(기둥 넷이 땅에서 지붕 앞 트러스까지) + 오른 옆 굵은 돌 굴뚝.

배치(블렌더, 앞 = -y, 1층 바닥 FZ = 2, 2층 바닥 Z2F = 14.4, 천장 1층 11 · 2층 10):
  몸 벽 가운데 선 x ±17.4 · y -11.5..11.6 → 안 33.6 × 21.9. 앞 마루(y -16..-12.1, 지붕 밑) + 계단 폭 14.
  1층 선술집: 정문 x ±5.2 높이 10(밖으로 접어 앞벽에 붙임) → 왼 앞 접수 카운터 x -16..-6 · y -0.75..1.75, NPC (-11, 2.25),
     카운터 앞 빈 바닥 x -16..-6 · y -10.9..-0.9 · 오른 벽 돌 벽난로(진짜 불) → 굴뚝이 옆벽 밖으로 땅부터 지붕 위까지 ·
     긴 식탁 둘 + 둥근 탁자 하나 · 뒷벽 따라 나무 계단(폭 8, 한 단 0.95, 아랫단 x 12.7 → 윗단 x -6.8, 열린 옆 측판 난간판) ·
     2층 바닥 짜임: 큰 보(x ±6, y 방향) + 계단 앞 받을보(y 2.5, x 방향) ← 1층 기둥 둘(±6, 2.5) · 장선 · 마루
  2층 방: 계단참(x -16.8..-6.8) → 앞쪽 방 셋(칸막이 x ±6, 앞벽에서 y -3.4 까지) · 왼·오른 방 침대 + 뒤 오른 구석 침대 = 쉬는 자리 셋 ·
     가운데 방 = 발코니 문(폭 8) · 계단 구멍 둘레 난간(기둥 사이)
  발코니: 앞 기둥 넷(x ±17.5, ±7 · y -15.5, 땅 → 지붕 앞 트러스) · 2층 높이 보 → 장선 → 마루 → 난간은 기둥 사이
"""
import math

import lib as K
import lib_a as A
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, DOOR_W, DOOR_H, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Inn"
PREFIX = "Sn3Inn"
VARIANT = "A"

WX, YF, YB = 17.4, -11.5, 11.6
T = LOG
HALF = WX + T / 2                          # 18.0
XI, YFI, YBI = WX - T / 2, YF + T / 2, YB - T / 2       # 16.8 · -10.9 · 11.0
Z1C = FZ + CEIL                            # 1층 천장(보 밑) 13
Z2F = Z1C + 1.4                            # 2층 바닥 14.4
CEIL2 = 10.0
Z_PLATE = Z2F + CEIL2 + 0.9                # 25.3
PORCH_Y, TRUSS_Y = -16.0, -15.5
POST_XS = (-17.5, -7.0, 7.0, 17.5)
ST_Y0, ST_Y1 = 3.0, YBI                    # 계단 폭(뒷벽에 붙음)
ST_BOT, ST_TOP = 12.7, -6.8                # 아랫단 앞 x · 윗단 끝 x
HDR_Y = 2.5                                # 계단 앞 받을보 가운데 y
STACK = (16.4, 19.4, -5.8, -2.2)           # 굴뚝(오른 벽을 뚫고 밖으로 2.0)
HEARTH = (13.2, XI, -7.6, -0.4)            # 벽난로 x0 x1 y0 y1
REST = [(-12.5, -6.2), (12.5, -6.2), (14.9, 2.6)]     # 쉬는 자리(침대 발치, 2층 바닥 위)


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    w1, w2 = FZ + WIN_SILL, Z2F + WIN_SILL
    holes = {"f": [(-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H), A.hole(-14.0, w1), A.hole(14.0, w1),
                   (-DOOR_W / 2, DOOR_W / 2, Z2F, Z2F + DOOR_H), A.hole(-12.0, w2), A.hole(12.0, w2)],
             "b": [A.hole(-12.0, w1), A.hole(-12.0, w2), A.hole(14.75, w2)],
             "l": [A.hole(-6.0, w1), A.hole(0.0, w1), A.hole(-6.0, w2), A.hole(7.0, w2)],
             "r": [A.hole(-9.4, w1), A.hole(6.0, w1), A.hole(-8.6, w2), A.hole(6.0, w2), (STACK[2], STACK[3], FZ, 99.0)]}
    A.log_box(g, -WX, WX, YF, YB, FZ, Z_PLATE, holes)
    for side, lst in holes.items():
        for a, b, za, zb in lst:
            if zb - za == K.WIN_H and b - a == K.WIN_W:
                A.win(g, S, side, (a + b) / 2, za, shutters=side != "f")
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    gz = Z_PLATE + 2.0
    K.gable_logs(g, "x", YF, HALF, Z_PLATE, top, holes=[(-1.5, 1.5, gz, gz + 4.0)])
    K.window(g, "x", YF, 0.0, gz, 3.0, 4.0, face=-1)
    K.gable_logs(g, "x", YB, HALF, Z_PLATE, top)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)
    K.door_open(g, "x", YF, 0.0, DOOR_W, DOOR_H, Z2F, face=-1, open_deg=95.0, outward=False)


def floor2(g):
    """2층 바닥 짜임: 1층 기둥 둘 → 큰 보(x ±6, y 방향 — 앞벽에서 받을보까지) · 받을보(y 2.5, 벽에서 벽) · 계단 구멍 테 보 → 장선 → 마루"""
    zg0, zg1 = Z1C, Z1C + 0.8                  # 보 13.0..13.8
    for x in (-6.0, 6.0):
        K.post(g, x, HDR_Y, FZ, zg0, s=1.0)
        bx(g, "DarkLog", x - 0.5, x + 0.5, YFI - 0.6, HDR_Y + 0.5, zg0, zg1)                # 큰 보(끝은 앞벽에 묻힘)
        K.brace(g, "y", x, HDR_Y - 0.5, zg0 - 2.0, HDR_Y - 2.5, zg0, s=0.45)                # 까치발
    bx(g, "DarkLog", -XI - 0.6, XI + 0.6, HDR_Y - 0.5, HDR_Y + 0.5, zg0, zg1)               # 받을보(끝은 옆벽에 묻힘)
    for x in (ST_TOP, ST_BOT):                                                              # 계단 구멍 테 보(받을보 → 뒷벽)
        bx(g, "DarkLog", x - 0.4, x + 0.4, HDR_Y + 0.5, YBI + 0.6, zg0 + 0.2, zg1)
    # 장선(x 방향, 큰 보 사이·벽 사이) — 앞쪽 큰 칸
    for k in range(9):
        y = YFI + 0.8 + k * (HDR_Y - 0.5 - YFI - 1.6) / 8
        bx(g, "Timber", -XI, XI, y - 0.3, y + 0.3, zg0 + 0.3, zg1)
    # 뒤 칸(계단참·뒤 오른 구석)은 y 방향 장선
    for x0, x1 in ((-XI, ST_TOP - 0.4), (ST_BOT + 0.4, XI)):
        n = max(1, int((x1 - x0) / 2.0))
        for i in range(n + 1):
            x = x0 + 0.4 + (x1 - x0 - 0.8) * i / n
            bx(g, "Timber", x - 0.3, x + 0.3, HDR_Y + 0.5, YBI, zg0 + 0.3, zg1)
    # 마루(0.6) — 계단 구멍만 비움
    bx(g, "Wood", -XI, XI, YFI, HDR_Y + 0.5, zg1, Z2F)
    bx(g, "Wood", -XI, ST_TOP, HDR_Y + 0.5, YBI, zg1, Z2F)
    bx(g, "Wood", ST_BOT, XI, HDR_Y + 0.5, YBI, zg1, Z2F)
    cbox(-XI, XI, YFI, HDR_Y + 0.5, zg0, Z2F)
    cbox(-XI, ST_TOP, HDR_Y + 0.5, YBI, zg0, Z2F)
    cbox(ST_BOT, XI, HDR_Y + 0.5, YBI, zg0, Z2F)
    # 계단 구멍 둘레 난간(기둥 사이에만) — 기둥은 마루 위
    ry = HDR_Y + 0.5 + 0.3
    xs = (ST_TOP + 0.3, 0.5, 6.5, ST_BOT - 0.3)
    for x in xs:
        bx(g, "DarkLog", x - 0.35, x + 0.35, ry - 0.35, ry + 0.35, Z2F, Z2F + 3.6)
    for a, b in zip(xs, xs[1:]):
        A.rail_between(g, "x", ry, a + 0.35, b - 0.35, Z2F, h=3.4)
    xr = ST_BOT - 0.3
    bx(g, "DarkLog", xr - 0.35, xr + 0.35, YBI - 0.7, YBI, Z2F, Z2F + 3.6)
    A.rail_between(g, "y", xr, ry + 0.35, YBI - 0.7, Z2F, h=3.4)


def hearth(g):
    """오른 벽 돌 벽난로(땅·기초부터): 몸 · 불 아가리 · 진짜 불 · 나무 선반 → 굴뚝 가슴(1층 천장 → 2층 → 지붕 밖 굴뚝과 한 몸)"""
    x0, x1, y0, y1 = HEARTH
    zt = FZ + 6.0
    ym = (y0 + y1) / 2
    K.I.box2(g, "Stone", x0 + 1.4, x1, y0, y1, FZ, zt)                       # 뒤 몸
    for ya, yb in ((y0, y0 + 1.2), (y1 - 1.2, y1)):                         # 아가리 양 볼
        K.I.box2(g, "Stone", x0, x0 + 1.4, ya, yb, FZ, zt)
    bx(g, "Stone", x0, x0 + 1.4, y0 + 1.2, y1 - 1.2, FZ + 4.4, zt)           # 아가리 위
    bx(g, "Soot", x0 + 1.3, x0 + 1.45, y0 + 1.2, y1 - 1.2, FZ, FZ + 4.4)
    bx(g, "StoneTrim", x0 - 0.3, x1, y0 - 0.3, y1 + 0.3, FZ, FZ + 0.4)       # 앞 깔돌
    K.I.fire_logs(g, x0 + 0.7, ym, FZ + 0.4, 3.6, 1.2, axis="y", size=1.4)
    bx(g, "Wood", x0 - 0.4, x1, y0 - 0.4, y1 + 0.4, zt, zt + 0.35)           # 선반
    K.SVC.mantel_clock(g, x0 + 0.2, ym, zt + 0.35, face=-1) if False else None
    for dy in (-2.2, 2.2):
        g["Brass"].cyl(x0 + 0.3, ym + dy, zt + 0.35, 0.3, 0.2, 0.9, seg=10)
    bx(g, "StoneTrim", x0 + 0.3, x1, y0 + 0.3, y1 - 0.3, zt + 0.35, zt + 0.7)
    bx(g, "Stone", x0 + 0.8, x1, y0 + 0.9, y1 - 0.9, zt + 0.7, Z_PLATE - 0.9)    # 굴뚝 가슴(1층 → 2층 천장)
    cbox(x0 + 0.8, x1, y0 + 0.9, y1 - 0.9, zt, Z_PLATE - 0.9)
    K.I.FIRE  # noqa: B018 (fire_logs 가 불 자리를 단다)


def tavern(g):
    zt = K.counter(g, -16.0, -6.0, -0.75, 1.75)
    K.SVC.cash_register(g, -8.2, 0.5, zt)
    K.SVC.beer_tower(g, -13.0, 0.6, zt)
    for x in (-11.4, -10.6):
        K.SVC.beer_mug(g, x, -0.2, zt)
    NPC(-11.0, 2.25, FZ, 0.0)
    # 계단 옆 판에 붙인 얕은 병 선반(카운터 뒤)
    for z in (FZ + 4.2, FZ + 5.6):
        bx(g, "Wood", -16.4, -7.4, ST_Y0 - 0.5, ST_Y0, z - 0.12, z)
        A.jar_row(g, -16.2, -7.6, ST_Y0 - 0.25, z, seed=int(z), d=0.4, liquids=("SignGold", "Verdigris", "SignRed", "Wood"))
    # 계단참 밑 광(통)
    for k, (x, y) in enumerate(((-15.4, 5.0), (-13.6, 5.0), (-15.4, 9.6), (-11.0, 9.8))):
        K.SVC.barrel(g, x, y, FZ, r=0.85, h=2.2)
    # 식탁: 앞 오른 긴 식탁 · 가운데 오른 긴 식탁 · 둥근 탁자
    A.long_table(g, 7.5, 14.5, -8.4, -6.8, FZ)
    A.long_table(g, 6.5, 13.0, -2.4, -0.8, FZ)
    K.I.round_table(g, 2.6, -4.2, FZ, r=1.6, h=2.6, stools=4)
    for x, y in ((9.5, -7.6), (11.5, -7.6), (8.4, -1.6)):
        K.SVC.beer_mug(g, x, y, FZ + 2.6)
    # 샹들리에·등(2층 보에 매닮)
    K.SVC.chandelier(g, 0.0, -5.0, Z1C, FZ + 8.6)
    K.SVC.chandelier(g, 10.5, -4.6, Z1C, FZ + 8.6)
    K.lantern(g, -11.0, -5.0, Z1C, FZ + 8.4)
    K.lantern(g, -11.0, 1.0, Z1C, FZ + 8.4)


def rooms(g):
    """2층: 칸막이 둘 · 침대 셋(쉬는 자리) · 옷장·세면대 · 가운데 방 깔개·걸상 · 등"""
    zc = Z_PLATE - 0.9
    for x in (-6.0, 6.0):
        A.partition(g, "y", x, YFI, -3.4, Z2F, zc)
    K.I.bed(g, -12.5, -9.0, Z2F, rz=0.0, mat="Banner")
    K.I.bed(g, 12.5, -9.0, Z2F, rz=math.pi, mat="Felt")
    K.I.bed(g, 14.9, 7.4, Z2F, rz=-math.pi / 2, mat="Banner")
    K.I.wardrobe(g, -7.6, -9.4, Z2F, "-x")
    K.I.washstand(g, 7.2, -10.0, Z2F, "+y")
    K.I.wardrobe(g, 15.95, -2.2, Z2F, "-x") if False else None
    for x, y in REST:                                                     # 쉬는 자리 깔개(침대 발치)
        bx(g, "Banner", x - 1.6, x + 1.6, y - 1.0, y + 1.0, Z2F, Z2F + 0.06)
        bx(g, "Brass", x - 1.7, x + 1.7, y - 1.1, y + 1.1, Z2F, Z2F + 0.03)
    # 가운데 방(발코니 문 앞) 깔개 + 걸상 둘
    bx(g, "Leather", -3.6, 3.6, -8.6, -4.4, Z2F, Z2F + 0.05)
    for x in (-4.6, 4.6):
        K.SVC.bench(g, x, -6.4, Z2F, 3.6, axis="y", mat="Leather")
    for x, y in ((-11.5, -3.0), (0.0, -6.0), (11.5, -3.0), (-11.5, 7.0), (14.8, 7.0)):
        K.lantern(g, x, y, zc, Z2F + 7.4)


def balcony(g, R):
    """앞 발코니·마루: 기둥 넷(받침돌, 땅 → 앞 트러스) · 2층 높이 보(기둥 옆) → 장선(보 → 앞벽) → 마루 → 난간은 기둥 사이 · 앞 트러스 · 간판"""
    ztb = Z_PLATE - 0.9
    for x in POST_XS:
        K.post(g, x, TRUSS_Y, FZ, ztb, s=1.0)
    for s in (-1, 1):
        x = s * 17.5
        K.brace(g, "x", TRUSS_Y, x - s * 0.5, ztb - 2.6, x - s * 3.0, ztb, s=0.5)
    K.tie_truss(g, TRUSS_Y, R)
    zb0, zb1 = Z2F - 1.5, Z2F - 0.9
    yb = YF - T / 2
    bx(g, "DarkLog", -18.0, 18.0, TRUSS_Y - 0.5, TRUSS_Y + 0.5, zb0 - 0.3, zb1)                 # 발코니 보(기둥 머리 아닌 기둥 옆 — 기둥이 꿰뚫음)
    for k in range(13):
        x = -17.0 + k * 34.0 / 12
        bx(g, "Timber", x - 0.3, x + 0.3, TRUSS_Y - 0.4, yb, zb1, Z2F - 0.3)                      # 장선(보 위 → 앞벽)
    bx(g, "Wood", -18.0, 18.0, PORCH_Y, yb, Z2F - 0.3, Z2F)
    cbox(-18.0, 18.0, PORCH_Y, yb, zb0 - 0.3, Z2F)
    for a, b in zip(POST_XS, POST_XS[1:]):
        A.rail_between(g, "x", TRUSS_Y, a + 0.5, b - 0.5, Z2F, h=3.4)
    for x in (-17.5, 17.5):
        A.rail_between(g, "y", x, TRUSS_Y + 0.5, yb, Z2F, h=3.4)
    # 1층 마루 등(발코니 보에 매닮) · 바깥 걸상(I4)
    for x in (-11.5, 11.5):
        K.lantern(g, x, -13.8, zb0 - 0.3, FZ + 7.6)
    K.SVC.bench(g, -11.0, -12.9, FZ, 6.0, axis="x", mat="Wood")
    # 앞 트러스 밑 큰 간판(맥주잔) + 오른 기둥 쇠 팔 간판
    for x in (-2.8, 2.8):
        bx(g, "Iron", x - 0.06, x + 0.06, TRUSS_Y - 0.06, TRUSS_Y + 0.06, Z2F + 7.6, ztb)
    bx(g, "Timber", -4.0, 4.0, TRUSS_Y - 0.15, TRUSS_Y + 0.15, Z2F + 4.9, Z2F + 7.6)
    bx(g, "Brass", -4.15, 4.15, TRUSS_Y - 0.2, TRUSS_Y + 0.2, Z2F + 7.55, Z2F + 7.75)
    bx(g, "SnowCap", -4.0, 4.0, TRUSS_Y - 0.18, TRUSS_Y + 0.18, Z2F + 7.75, Z2F + 7.87)
    for f in (-1, 1):
        K.L.transformed(g, K.L.Matrix.Identity(4) if hasattr(K.L, "Matrix") else _scale(0.0, TRUSS_Y, Z2F + 5.3, 1.2),
                        lambda q, f=f: K.SVC.mug_icon(q, -0.15, TRUSS_Y + f * 0.15, Z2F + 5.2, face=f)) if False else None
        _big(g, lambda q, f=f: K.SVC.mug_icon(q, -0.15, TRUSS_Y + f * 0.15, Z2F + 5.2, face=f), (0.0, TRUSS_Y, Z2F + 5.2), 1.15)
    K.hang_sign(g, 18.0, TRUSS_Y, FZ + 9.0, along="x", arm=2.4, board=(2.6, 2.2),
                icon=lambda g_, x, y, z, f: K.SVC.mug_icon(g_, x - 0.15, y, z, face=f))


def _big(g, fn, at, k):
    from mathutils import Matrix
    m = Matrix.Translation(at) @ Matrix.Scale(k, 4) @ Matrix.Translation((-at[0], -at[1], -at[2]))
    K.L.transformed(g, m, fn)


def outside(g):
    # 왼 옆 증기 통 → 관이 왼벽으로(난방)
    tx, ty = -HALF - 1.6, 6.0
    K.steam_bundle(g, tx, ty, 0.0, h=7.0, r=1.2, gauge_face=-1, pipe_pts=[(tx + 1.2, ty, 7.6), (-HALF + 0.3, ty, 7.6)])


def build(g):
    R = K.roof_frame(HALF, PORCH_Y, YB + T / 2, Z_PLATE, VARIANT)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, PORCH_Y, YB + T / 2 + 0.3)
    K.stair(g, 0.0, PORCH_Y, 14.0, FZ)
    shell(g, R)
    floor2(g)
    A.stair_x(g, ST_BOT, ST_TOP, ST_Y0, ST_Y1, FZ, Z2F, open_y=ST_Y0)
    for y in (-9.0, -3.0, 3.0, 9.0):
        K.tie_truss(g, y, R)
    balcony(g, R)
    K.roof_gable(g, R, openings=[STACK])
    K.chimney(g, *STACK, R.top() + 1.0)
    hearth(g)
    tavern(g)
    rooms(g)
    outside(g)
    CLEAR(-4.8, 4.8, YFI + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-16.0, -6.0, -10.9, -0.9, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": (-16.0, -6.0, -0.75, 1.75),
    "free": (-16.0, -6.0, -10.9, -0.9),
    "walk": ((0.0, YF - 1.5), (-11.0, -6.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YBI),
    "forge_look": (HEARTH[0], (HEARTH[2] + HEARTH[3]) / 2),
    "plan_scale": 50,
    "rest": REST,                               # 쉬는 자리(블렌더 x, y — 바닥 = Z2F). Studio 표지 종류는 질문 md
    "floors": [
        {"name": "2층", "floor": Z2F, "what": "계단 윗단 → 왼 방 쉬는 자리",
         "walk": ((-11.8, 7.0), (-11.4, -2.0)), "free": (-16.4, -6.6, -7.0, 3.0),
         "inside": (-XI, XI, YFI, YBI), "voids": [(ST_TOP, ST_BOT, HDR_Y + 0.5, YBI)]},
        {"name": "2층b", "floor": Z2F, "what": "계단 윗단 → 오른 방 쉬는 자리",
         "walk": ((-11.8, 7.0), (11.4, -2.0)), "free": (6.6, 16.4, -7.0, 2.0),
         "inside": (-XI, XI, YFI, YBI), "voids": [(ST_TOP, ST_BOT, HDR_Y + 0.5, YBI)]},
    ],
    "extra_views": [
        ("fp_stair", (14.5, -1.0, FZ + 4.5), (-6.0, 7.0, Z2F - 2.0), 17, None),          # 1층에서 계단 올려다봄
        ("fp_stairtop", (-9.0, 7.0, Z2F + 4.5), (-11.0, -8.0, Z2F + 2.0), 17, None),     # 2층 계단참 → 왼 방
        ("fp_2f", (0.0, 1.0, Z2F + 4.5), (12.0, -8.0, Z2F + 2.0), 17, None),            # 2층 복도 → 오른 방
        ("fp_balcony", (-10.0, -14.0, Z2F + 4.5), (10.0, -14.5, Z2F + 2.0), 17, None),  # 발코니
        ("plan2", (0.0, 0.0, 120.0), (0.0, 0.01, 0.0), None, (120 - (Z2F + CEIL2 - 0.3), 50)),
    ],
}
