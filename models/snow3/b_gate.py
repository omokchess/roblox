# -*- coding: utf-8 -*-
"""
b_gate.py — 2026-11-14. 설원 마을 3판: 동문(마을 입구, 발자국 26×6). 아트 부서원 1, A 양식(짙은 통나무). 지나가는 문 — 안은 없다.

레퍼런스(회사/설원마을_레퍼런스.md E·C): 오시누프 돌니 목조 성문(E1 — 아래 통나무 벽 + 위 기둥 망루 + 넓은 처마),
쳅스토 성 나무 문짝(E2 — 세로 널 + 쇠 띠 + 빗장), 트라인펠트 성문(E3 — 문루 비례, 통로 폭 ≈ 높이의 1/2 → 우리는 12×12, 지붕 위 작은 종),
뢰로스·발저 집(C1·C5 — 통나무 모서리 짜임·돌 밑단).

짜임(실제 공사처럼): 돌 밑단(높이 3) 둘 → 통나무 문기둥 채 둘(x ±6.9..±12.4, 위 13.8까지)
 → 통로 위 큰 인방 둘(앞·뒤, 끝은 문기둥 채 벽에 묻힘) → 인방 위 장선 → 망루 마루(14.4)
 → 마루 위 기둥 열(문기둥 채 모서리·안쪽 벽 축 위) → 기둥 머리 도리 → 옆 박공 맞배지붕(용마루 x 방향), 난간은 기둥 사이에만.
 통로 폭 12(문설주 사이) · 높이 12, 쇠 띠 널문 둘은 바깥으로 활짝 열어 문기둥 채 앞면에 붙임. 망루 위 증기 경적 통(마을 경보) · 가운데 종.
"""
import lib as K
import lib_a as A
from lib import LOG, bx, cbox, CLEAR

NAME = "Sn3_Gate"
PREFIX = "Sn3Gate"
VARIANT = "A"

PASS_W, PASS_H = 12.0, 12.0
XIN, XOUT = 6.9, 12.4                    # 문기둥 채 벽 가운데 선(안·바깥)
YF, YB = -2.4, 2.4
T = LOG
PLINTH = 3.0                             # 돌 밑단
Z_PIER = 13.8                            # 문기둥 채 윗면 = 인방 윗면
Z_FLOOR = 14.4                           # 망루 마루
Z_PLATE = Z_FLOOR + 7.0                  # 망루 기둥 머리(도리 윗면)
POSTS_X = (-XOUT, -XIN, XIN, XOUT)


def piers(g):
    for s in (-1, 1):
        x0, x1 = sorted((s * XIN, s * XOUT))
        fx0 = x0 - T / 2 - (0.3 if s < 0 else 0.0)                # 통로 쪽 밑단은 벽면과 같게(통로 폭을 줄이지 않게)
        fx1 = x1 + T / 2 + (0.3 if s > 0 else 0.0)
        K.foundation(g, fx0, fx1, YF - T / 2 - 0.3, YB + T / 2 + 0.3, h=PLINTH)
        # 통로 쪽 벽에 쇠살 작은 창(문지기 방 느낌) — 바깥쪽 벽엔 총안 같은 좁은 창
        holes = {("r" if s < 0 else "l"): [A.hole(0.0, PLINTH + 4.0, 1.6, 2.6)]}
        inner = (True, False) if s < 0 else (False, True)          # 통로 쪽 모서리 통나무 끝은 내밀지 않는다(통로 폭 12 유지)
        A.log_box(g, x0, x1, YF, YB, PLINTH, Z_PIER, holes, ends={"f": inner, "b": inner})
        side = "r" if s < 0 else "l"
        A.win(g, A.sides(x0, x1, YF, YB), side, 0.0, PLINTH + 4.0, 1.6, 2.6, shutters=False)


def lintels(g):
    """통로 위 큰 인방(앞·뒤) — 끝은 문기둥 채 벽 속으로 1.5 묻힘 · 위 장선 · 통로 쪽 까치발"""
    for y in (YF, YB):
        bx(g, "DarkLog", -XIN - 1.5, XIN + 1.5, y - 0.7, y + 0.7, PASS_H + 0.6, Z_PIER)
        for s in (-1, 1):                                             # 까치발: 문기둥 채 안벽 → 인방 밑
            K.brace(g, "x", y, s * (XIN - T / 2), PASS_H - 1.6, s * (XIN - T / 2 - 1.8), PASS_H + 0.6, s=0.5)
    cbox(-XIN, XIN, YF - 0.7, YB + 0.7, PASS_H + 0.6, Z_PIER)
    # 장선은 인방 사이(y 방향) — 인방 윗면에 얹힌다 · 마루 판 0.6
    for k in range(7):
        x = -XIN + 0.8 + k * (2 * XIN - 1.6) / 6
        bx(g, "Timber", x - 0.3, x + 0.3, YF - 0.7, YB + 0.7, Z_PIER, Z_PIER + 0.3)
    bx(g, "Wood", -XOUT - T / 2, XOUT + T / 2, YF - T / 2, YB + T / 2, Z_PIER + 0.3, Z_FLOOR)
    cbox(-XOUT - T / 2, XOUT + T / 2, YF - T / 2, YB + T / 2, Z_PIER, Z_FLOOR)
    # 앞 인방 가운데 놋쇠 톱니 문장
    K.S.gear(g, "Brass", 0.0, YF - 0.75, (PASS_H + 0.6 + Z_PIER) / 2, 0.75, 12, 0.18, axis="y")


def gallery(g, R):
    """망루: 기둥 열 · 도리 · 난간(기둥 사이) · 가운데 종 · 증기 경적 통"""
    zt = Z_PLATE - 0.9
    for x in POSTS_X:
        for y in (YF, YB):
            K.post(g, x, y, Z_FLOOR, zt, s=1.0, pad=False)
    for y in (YF, YB):                                              # 도리(기둥 머리, 앞뒤)
        bx(g, "DarkLog", -XOUT - 0.6, XOUT + 0.6, y - 0.6, y + 0.6, zt, Z_PLATE)
    for x in (-XOUT, XOUT):                                         # 옆 도리(박공 받침)
        bx(g, "DarkLog", x - 0.6, x + 0.6, YF - 0.6, YB + 0.6, zt, Z_PLATE)
    # 난간: 기둥 사이에만(앞뒤 셋 칸 · 옆 한 칸)
    for y in (YF, YB):
        for a, b in zip(POSTS_X, POSTS_X[1:]):
            A.rail_between(g, "x", y, a + 0.5, b - 0.5, Z_FLOOR, h=3.4)
    for x in (-XOUT, XOUT):
        A.rail_between(g, "y", x, YF + 0.5, YB - 0.5, Z_FLOOR, h=3.4)
    # 기둥 ↔ 도리 까치발
    for x in POSTS_X:
        for d in (-1, 1):
            if abs(x + d * 2.0) > XOUT:
                continue
            for y in (YF, YB):
                K.brace(g, "x", y, x + d * 0.5, zt - 1.8, x + d * 2.2, zt, s=0.4)
    # 가운데 종(평보에 매닮)
    g["Iron"].cyl(0.0, 0.0, zt - 1.6, 0.1, 0.1, 1.6, seg=6)
    g["Brass"].cyl(0.0, 0.0, zt - 3.4, 1.1, 0.55, 1.8, seg=16)
    g["Brass"].cyl(0.0, 0.0, zt - 3.55, 1.2, 1.2, 0.2, seg=16)
    g["Iron"].cyl(0.0, 0.0, zt - 3.9, 0.2, 0.2, 0.5, seg=8)
    # 증기 경적 통(마을 경보) — 망루 마루 위 오른쪽
    tx = 9.6
    K.steam_bundle(g, tx, 0.0, Z_FLOOR, h=3.4, r=0.8, gauge_face=-1,
                   pipe_pts=[(tx - 0.8, 0.0, Z_FLOOR + 3.0), (tx - 2.2, 0.0, Z_FLOOR + 3.0), (tx - 2.2, 0.0, Z_FLOOR + 5.2)])
    g["Brass"].cyl(tx - 2.2, 0.0, Z_FLOOR + 5.2, 0.25, 0.55, 1.0, seg=12)        # 경적 나팔


def build(g):
    R = K.RoofFrame(3.0, -XOUT - 0.6, XOUT + 0.6, Z_PLATE, K.PITCH["A"], eave=1.4, eave_g=1.5)   # 처마를 줄여 깊이 6(+3) 안에
    piers(g)
    lintels(g)
    gallery(g, R)
    for x in (-XOUT, -XIN, 0.0, XIN, XOUT):
        A.truss_x(g, R, x, posts=x in (-XIN, XIN, 0.0))
    for x in (-XOUT, XOUT):
        A.gable_x(g, R, x)
    A.roof_x(g, R)
    # 쇠 띠 널문(바깥으로 활짝 — 문기둥 채 앞면에 붙음) · 문설주 · 문 비울 자리
    K.door_open(g, "x", YF, 0.0, PASS_W, PASS_H, 0.0, face=-1, open_deg=172.0)
    # 통로 판석 + 통로 등(인방에 매닮)
    bx(g, "Stone", -XIN + T / 2, XIN - T / 2, YF - T / 2, YB + T / 2, 0.0, 0.12)
    for x in (-4.0, 4.0):
        K.lantern(g, x, YB, PASS_H + 0.6, PASS_H - 1.8)
    CLEAR(-5.0, 5.0, YF - 3.0, YB + 3.0, 0.15, 5.4)


INFO = {
    "variant": VARIANT,
    "floor": 0.0,
    "free": (-5.0, 5.0, 0.0, 8.0),                  # 통로 안·뒤(지나가는 길)
    "walk": ((0.0, -6.5), (0.0, 3.0)),              # 문 앞 → 통로 지나 → 뒤
    "inside": (-13.0, 13.0, -8.0, 12.0),
    "extra_views": [
        ("fp_approach", (0.0, -16.0, 4.5), (0.0, 0.0, 8.0), 17, None),      # 1인칭 문 앞 16
        ("fp_under", (0.0, -4.5, 4.5), (0.0, 1.0, 22.0), 17, None),         # 1인칭 문 밑에서 올려다봄
        ("fp_through", (0.0, -1.0, 4.5), (0.0, 30.0, 4.0), 17, None),       # 1인칭 통로 안 → 마을 쪽
        ("plan_top", (0.0, 0.0, 120.0), (0.0, 0.01, 0.0), None, (0.1, 34)),
    ],
}
