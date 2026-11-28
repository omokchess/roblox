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
2026-11-18 아트 2팀(레퍼런스 내부 2팀 GA — 성문 초소): 문기둥 채 꼭대기 받침판(채 벽 윗선 ~ 망루 마루 0.3 틈 막음) · 김 표지 뺌(망루 지붕 밑) ·
 왼 채 = 문지기 초소(통로 쪽 창 안 책상·장부·등·걸상·창 걸이, 창 밖 턱에 통행 장부·잉크·종, 옆 알림판),
 오른 채 = 무기 걸이(통로 벽 창·미늘창 걸이 다섯 + 창 안 방패·투구·걸이). 통로 맑은 폭 11(걸이 0.8 내밈).
2026-11-24 2팀 2차(비평 1차 '여기서부터 마을'·'초소 안 안 보임'): 통로 바닥 두 색 큰 돌판 + 짙은 줄눈 + 앞뒤 문턱 돌 ·
 인방 안팎 마을 표지판(톱니 + 눈송이 문장, 글자 없음) · 마을 쪽 출구 양옆 증기 가로등 · 초소 창 = 유리 없는 창구(3×2.5, 덧창 올려 받침) + 안 등 ·
 초소 옆 세운 차단봉 · 창 걸이 손 표(미늘창 2 · 창 2 · 빈 칸, 높이 다르게) + 둥근 방패.
"""
import math

import lib as K
import lib_a as A
import lib_int1 as P
import lib_int2 as N
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
XP = XIN - T / 2                         # 통로 쪽 채 벽 바깥면(6.3)

# holes.py: 일부러 트인 자리 — 통로(지나가는 문)와 망루(난간만 둘린 지붕 밑). 문기둥 채 속 방(초소·무기고)은 닫는다
OPEN_ZONES = [(-XP, XP, -12.0, 12.0, 0.0, PASS_H + 0.6, "통로(지나가는 문 — 앞뒤로 트임)"),
              (-XOUT - 3.0, XOUT + 3.0, -6.0, 6.0, Z_FLOOR, 40.0, "망루(기둥 사이 난간만 — E1 문루)"),
              (-XOUT, -XIN, YF, YB, PLINTH, Z_PIER, "문지기 초소(통로 쪽 유리 없는 창구 — 통행 장부를 주고받는 자리)")]
GW = (3.0, 2.5, PLINTH + 3.05)             # 초소 창구 폭 · 높이 · 밑


def piers(g):
    for s in (-1, 1):
        x0, x1 = sorted((s * XIN, s * XOUT))
        fx0 = x0 - T / 2 - (0.3 if s < 0 else 0.0)                # 통로 쪽 밑단은 벽면과 같게(통로 폭을 줄이지 않게)
        fx1 = x1 + T / 2 + (0.3 if s > 0 else 0.0)
        K.foundation(g, fx0, fx1, YF - T / 2 - 0.3, YB + T / 2 + 0.3, h=PLINTH)
        # 통로 쪽 벽에 쇠살 작은 창(문지기 방 느낌) — 바깥쪽 벽엔 총안 같은 좁은 창
        gw, gh, gz = GW
        holes = {("r" if s < 0 else "l"): [A.hole(0.0, gz, gw, gh) if s < 0 else A.hole(0.0, PLINTH + 4.0, 1.6, 2.6)]}
        inner = (True, False) if s < 0 else (False, True)          # 통로 쪽 모서리 통나무 끝은 내밀지 않는다(통로 폭 12 유지)
        A.log_box(g, x0, x1, YF, YB, PLINTH, Z_PIER, holes, ends={"f": inner, "b": inner})
        side = "r" if s < 0 else "l"
        if s > 0:                                                    # 오른 채(무기고) = 유리 창 · 왼 채(초소) = 유리 없는 창구
            A.win(g, A.sides(x0, x1, YF, YB), side, 0.0, PLINTH + 4.0, 1.6, 2.6, shutters=False)
        bx(g, "DarkLog", x0 - T / 2, x1 + T / 2, YF - T / 2, YB + T / 2, Z_PIER, Z_PIER + 0.28)   # (2팀) 채 윗 받침판


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
    N.no_vent(g, K.steam_bundle, tx, 0.0, Z_FLOOR, h=3.4, r=0.8, gauge_face=-1,              # (2팀) 김 뺌 — 망루 지붕 밑
              pipe_pts=[(tx - 0.8, 0.0, Z_FLOOR + 3.0), (tx - 2.2, 0.0, Z_FLOOR + 3.0), (tx - 2.2, 0.0, Z_FLOOR + 5.2)])
    g["Brass"].cyl(tx - 2.2, 0.0, Z_FLOOR + 5.2, 0.25, 0.55, 1.0, seg=12)        # 경적 나팔


def guard_post(g):
    """왼 채 = 문지기 초소: 통로 쪽 유리 없는 창구(3×2.5) + 위로 올려 받친 덧창 · 창구 턱(까치발 둘) 위 통행 장부 · 잉크병 · 종 ·
    창구 안 책상(장부·촛대 등 — 통로에서 불 켜진 창구가 보이게) · 걸상 · 안쪽 벽 창 걸이 · 창 옆 알림판 · 앞 세운 차단봉"""
    z = PLINTH
    gw, gh, gz = GW
    N.put(g, -8.1, 0.0, z, math.pi / 2, N.table, 2.6, 1.2, 3.0)
    N.book(g, -8.1, -0.4, z + 3.0, cover="Leather", open_=True)
    N.candle(g, -8.2, 0.85, z + 3.0, h=0.6, light=True)
    g["LampPt"].box(-8.6, 0.0, gz + 1.6, 0.3, 0.3, 0.3)
    N.put(g, -9.6, 0.3, z, 0.0, N.stool)
    N.put(g, -11.8, 0.0, z, math.pi / 2, N.spear_rack, 2, 0.8, 6.4)
    cbox(-11.8, -7.5, -1.8, 1.8, z, z + 0.2)
    xs = -XIN + T / 2                                                            # 통로 쪽 벽 바깥면(6.3)
    bx(g, "Wood", xs, xs + 0.85, -gw / 2 - 0.15, gw / 2 + 0.15, gz - 0.22, gz)    # 창구 턱 + 까치발
    for y in (-gw / 2 + 0.2, gw / 2 - 0.2):
        g["DarkLog"].obox(xs + 0.32, y, gz - 0.7, 0.22, 0.22, 0.95, ry=0.6)
    N.book(g, xs + 0.45, -0.4, gz, w=0.8, d=1.1, cover="SignRed", open_=True)
    g["DarkStone"].cyl(xs + 0.5, 0.6, gz, 0.18, 0.15, 0.3, seg=8)
    g["Brass"].cyl(xs + 0.4, 1.15, gz, 0.3, 0.26, 0.08, seg=10)
    g["Brass"].cyl(xs + 0.4, 1.15, gz + 0.08, 0.24, 0.1, 0.3, seg=10)
    hz = gz + gh                                                                 # 덧창: 위 끝 경첩, 통로 쪽으로 65° 들어 올려(차양처럼) 쇠 받침 둘
    a = math.radians(65)
    L_ = gh + 0.2
    cxs, czs = xs + 0.12 + math.sin(a) * L_ / 2, hz + 0.12 - math.cos(a) * L_ / 2
    g["DarkLog"].obox(cxs, 0.0, czs, 0.18, gw + 0.3, L_, ry=-a)
    for y in (-gw / 2, gw / 2):
        g["Iron"].box(xs + 0.15, y, hz + 0.1, 0.3, 0.14, 0.2)
        p1 = (xs + 0.12 + math.sin(a) * L_ * 0.9, y, hz + 0.12 - math.cos(a) * L_ * 0.9)
        A.lattice_leg(g, (xs + 0.05, y, gz + 0.6), p1, s=0.3, mat="Timber")      # 0.3 각재 버팀(2026-11-27 비평 2팀 사소 A: 쇠막대가 철사처럼)
        g["Iron"].box(p1[0], p1[1], p1[2], 0.4, 0.4, 0.4)                          # 끝 쇠 걸쇠
    bx(g, "DarkLog", xs, xs + 0.18, 1.75, 2.95, PLINTH + 2.2, PLINTH + 5.2)       # 알림판(창구 옆)
    bx(g, "Timber", xs + 0.18, xs + 0.24, 1.88, 2.82, PLINTH + 2.35, PLINTH + 5.05)
    for y, zz, ang, mat in ((2.1, 4.4, 0.1, "Paint"), (2.6, 4.2, -0.08, "Canvas"), (2.3, 3.0, -0.06, "Canvas")):
        g[mat].obox(xs + 0.27, y, PLINTH + zz, 0.04, 0.42, 0.75, rx=ang)
        g["Brass"].box(xs + 0.3, y, PLINTH + zz + 0.32, 0.05, 0.1, 0.1)
    bx(g, "DarkLog", xs, xs + 0.5, -2.45, -1.95, 0.0, 1.6)                        # 세운 차단봉(받침 + 쇠 띠 두른 봉 + 붉은 끝)
    g["Iron"].hcyl(xs + 0.25, -2.2, 1.2, 0.12, 0.6, axis="y", seg=6)
    g["Timber"].box(xs + 0.25, -2.2, 5.3, 0.3, 0.3, 7.6)
    for zz in (2.5, 4.5, 6.5, 8.4):
        g["Iron"].box(xs + 0.25, -2.2, zz, 0.36, 0.36, 0.2)
    g["SignRed"].box(xs + 0.25, -2.2, 8.85, 0.32, 0.32, 0.6)
    cbox(xs, xs + 0.55, -2.5, -1.9, 0.0, 9.2)


def armory(g):
    """오른 채 = 무기 걸이: 통로 쪽 벽에 창·미늘창 걸이(다섯) · 채 속(창 너머로 보이게) 둥근 방패 · 투구 · 창 걸이"""
    N.put(g, XP, 0.0, 0.12, -math.pi / 2, N.spear_rack, 5, 0.75, 6.4, 2,
          [("h", 0.0), ("s", 0.4), None, ("h", -0.4), ("s", 0.2)])                 # 손 표: 미늘창 2 · 창 2 · 빈 칸, 높이 ±0.4
    P.wall_weapon(g, "y", XP, 2.1, 8.6, -1, lambda q: P.shield(q, r=1.0))       # 통로 벽 둥근 방패(쇠못 · 테 · 리벳 · 배꼽 · 뒤 손잡이)
    cbox(XP - 0.8, XP, -2.0, 2.0, 0.0, 5.0)
    z = PLINTH
    N.put(g, 11.8, -0.9, z, -math.pi / 2, N.spear_rack, 2, 0.8, 6.4)
    sx, sz = 11.75, z + 4.6                                                      # 둥근 방패(바깥 벽 안면, 창 정면)
    P.wall_weapon(g, "y", sx + 0.05, 0.9, sz, -1, lambda q: P.shield(q, r=1.1, mat="Paint"))
    bx(g, "Timber", 8.8, 9.2, 0.8, 1.2, z, z + 0.9)                               # 투구 받침(나무 기둥 + 발판) + 통 투구(눈 틈 · 숨 구멍 · 놋쇠 볏)
    bx(g, "Timber", 8.5, 9.5, 0.5, 1.5, z, z + 0.15)
    bx(g, "Steel", 8.55, 9.45, 0.5, 1.5, z + 0.9, z + 1.95)
    bx(g, "Iron", 8.62, 9.38, 0.42, 0.5, z + 1.45, z + 1.58)
    for xx in (8.8, 9.0, 9.2):
        bx(g, "Iron", xx - 0.05, xx + 0.05, 0.43, 0.5, z + 1.1, z + 1.3)
    bx(g, "Brass", 8.9, 9.1, 0.5, 1.5, z + 1.95, z + 2.2)
    cbox(7.5, 11.8, -1.8, 1.8, z, z + 0.2)


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
    x0p, x1p = -XIN + T / 2, XIN - T / 2                                         # (2팀 2차) 두 색 큰 돌판 3×3 + 짙은 줄눈 + 앞뒤 문턱 돌
    nx, ny = 4, 2
    for i in range(nx):
        for j in range(ny):
            xa, xb = x0p + (x1p - x0p) * i / nx, x0p + (x1p - x0p) * (i + 1) / nx
            ya, yb = YF - T / 2 + (YB - YF + T) * j / ny, YF - T / 2 + (YB - YF + T) * (j + 1) / ny
            bx(g, ("Stone", "RockA")[(i + j) % 2], xa, xb, ya, yb, 0.0, 0.12)
    for i in range(1, nx):
        x = x0p + (x1p - x0p) * i / nx
        bx(g, "DarkStone", x - 0.05, x + 0.05, YF - T / 2 + 0.05, YB + T / 2 - 0.05, 0.12, 0.13)
    bx(g, "DarkStone", x0p + 0.05, x1p - 0.05, -0.05, 0.05, 0.12, 0.13)
    for ya, yb in ((YF - T / 2 - 0.8, YF - T / 2), (YB + T / 2, YB + T / 2 + 0.8)):
        bx(g, "StoneTrim", x0p, x1p, ya, yb, 0.0, 0.24)
    # 마을 표지판(인방 안팎, 쇠 막대 둘로 매닮): 판 · 놋쇠 테 · 톱니 + 눈송이 문장 · 위 눈
    for yl, f in ((YF - 0.7, -1), (YB + 0.7, 1)):
        yb_ = yl + f * 0.2
        for x in (-2.2, 2.2):                                                    # 매단 쇠 막대 + 인방에 박은 쇠 팔(2026-11-28: 뒤 표지판이 인방에서 떠 있었다)
            bx(g, "Iron", x - 0.08, x + 0.08, yb_ - 0.08, yb_ + 0.08, PASS_H - 0.1, PASS_H + 0.6)
            bx(g, "Iron", x - 0.1, x + 0.1, *sorted((yb_, yl - f * 0.6)), PASS_H + 0.45, PASS_H + 0.65)
        bx(g, "Timber", -3.0, 3.0, *sorted((yb_ - 0.15, yb_ + 0.15)), PASS_H - 1.7, PASS_H - 0.1)
        bx(g, "Brass", -3.15, 3.15, *sorted((yb_ - 0.2, yb_ + 0.2)), PASS_H - 0.18, PASS_H)
        bx(g, "Brass", -3.15, 3.15, *sorted((yb_ - 0.2, yb_ + 0.2)), PASS_H - 1.8, PASS_H - 1.62)
        for fs in (f, -f):                                                       # 문장은 판 양면(통로 안에서도 읽히게)
            ye = yb_ + fs * 0.2
            K.S.gear(g, "Brass", -1.6, ye, PASS_H - 0.9, 0.55, 10, 0.12, axis="y")
            K.S.gear(g, "Brass", 1.6, ye, PASS_H - 0.9, 0.55, 10, 0.12, axis="y")
            for k in range(3):                                                   # 눈송이(가운데, 세 획 + 끝 마디)
                ang = k * math.pi / 3
                g["Paint"].obox(0.0, ye, PASS_H - 0.9, 1.3, 0.1, 0.16, ry=ang)
                for sg in (-1, 1):
                    g["Paint"].obox(sg * 0.5 * math.cos(ang), ye, PASS_H - 0.9 - sg * 0.5 * math.sin(ang), 0.4, 0.1, 0.12, ry=ang + math.pi / 2)
    # 마을 쪽 출구 양옆 증기 가로등
    for x in (-XP - 0.9, XP + 0.9):
        N.put(g, x, YB + T / 2 + 1.0, 0.0, 0.0, N.lamp_post, 7.0)
        cbox(x - 0.75, x + 0.75, YB + T / 2 + 0.25, YB + T / 2 + 1.75, 0.0, 6.0)
    for x in (-4.0, 4.0):
        K.lantern(g, x, YB, PASS_H + 0.6, PASS_H - 1.8)
    guard_post(g)
    armory(g)
    CLEAR(-5.0, 5.0, YF - 3.0, YB + 3.0, 0.15, 5.4)


INFO = {
    "variant": VARIANT,
    "floor": 0.0,
    "free": (-5.0, 5.0, 0.0, 8.0),                  # 통로 안·뒤(지나가는 길)
    "walk": ((0.0, -6.5), (0.0, 3.0)),              # 문 앞 → 통로 지나 → 뒤
    "inside": (-22.0, 22.0, -10.0, 18.0),
    "outdoor": True,                                # 바깥 문 — playcheck 가 범위 끝을 벽으로 보지 않는다
    "extra_views": [
        ("fp_approach", (0.0, -16.0, 4.5), (0.0, 0.0, 8.0), 17, None),      # 1인칭 문 앞 16
        ("fp_under", (0.0, -4.5, 4.5), (0.0, 1.0, 22.0), 17, None),         # 1인칭 문 밑에서 올려다봄
        ("fp_through", (0.0, -1.0, 4.5), (0.0, 30.0, 4.0), 17, None),       # 1인칭 통로 안 → 마을 쪽
        ("plan_top", (0.0, 0.0, 120.0), (0.0, 0.01, 0.0), None, (0.1, 34)),
    ],
}
