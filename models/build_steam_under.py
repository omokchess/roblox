# -*- coding: utf-8 -*-
"""
build_steam_under.py — 2026-10-10. 지하 카지노(사용자: 카지노는 지하로). 옛 "지하 입구" 자리(가운데 고리 r117)에 둥근 입구 정자를 두고
나선 계단(44 단, 28 스터드)으로 내려가면 로비 → 큰 도박장 → 옆 경매장.

  Casino_Gate   땅 위: 둥근 받침·벽돌 원통(진짜 창 다섯·열린 쇠창살 문)·청동 돔·유리 등탑·간판·등
  Casino_Under  땅 밑(Casino_Gate 피벗에 소품으로 붙는다): 굴 벽·나선 계단·로비(외투 맡기는 곳·환전 창구)·
                도박장(룰렛 둘·카드 넷·슬롯 줄·바·악단 무대·행운의 바퀴·쇠기둥 여섯)·경매장(무대·경매대·진열 받침·반원 걸상 셋·진열장)
마을 땅(Surface.R_설원3.Land 의 큰 판)은 Snow_City2 가 dig 상자대로 파낸다(입구 굴은 세계 축 정사각, 방들은 돌린 상자의 둘레 상자).
좌표: 블렌더 (x, y, z), 앞 = -y(광장을 본다), z 0 = 땅. 로블록스 로컬 = (-x, z, y).
"""
import math
import os
import sys

from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
from build_steam_obs import sphere, sweep, sector, arc_wall, polar_m  # noqa: E402
from build_steam_inside import C, PROP, DIG, job, box2, wall_door, lantern, arch_top, armor_stand, slot_machine, bottle  # noqa: E402

R = math.radians
ZU = -28.0                     # 땅 밑 바닥 윗면
RI_S, RO_S, R_PL = 7.6, 8.6, 11.6     # 받침 반지름 ≥ 굴 정사각 반대각선(8.0·√2 = 11.3)
Z_LAND = 0.4
DOOR_A, DOOR_H = -90.0, 15.0    # 입구 문(광장 쪽), 반각
EXIT_A = 90.0                  # 굴 바닥 문(로비 쪽)
N_STEP, A_START = 44, -50.0
SWEEP = 90.0 - 10.0 - A_START + 720.0          # 마지막 단이 80 도에서 끝나 90 도 문으로 나간다
D_STEP = SWEEP / N_STEP
RISE = (Z_LAND - ZU) / N_STEP


def adiff(a, b):
    return abs((a - b + 180.0) % 360.0 - 180.0)


def ring_coll(r0, r1, z0, z1, skip=()):
    """둥근 벽 충돌: 15 도 토막(가운데 7.5+15k). skip = [(가운데 각, 반각, z0, z1)] 그 높이만 비운다"""
    for k in range(24):
        a = 7.5 + 15.0 * k
        rm = (r0 + r1) / 2
        w = 2 * r1 * math.sin(R(7.5)) + 0.05
        spans = [(z0, z1)]
        for ca, half, sz0, sz1 in skip:
            if adiff(a, ca) < half:
                nxt = []
                for a0, a1 in spans:
                    if sz0 > a0:
                        nxt.append((a0, min(a1, sz0)))
                    if sz1 < a1:
                        nxt.append((max(a0, sz1), a1))
                spans = [s for s in nxt if s[1] - s[0] > 0.05]
        for a0, a1 in spans:
            C(rm * math.cos(R(a)), rm * math.sin(R(a)), (a0 + a1) / 2, r1 - r0, w, a1 - a0, R(a))


def rwin_ring(g, a, z0, w, h, t):
    """둥근 벽(바깥 RO_S)의 진짜 창 + 반원 머리(안팎 틀)"""
    L.transformed(g, polar_m(a, RO_S), lambda q: (S.window(q, 0, 0, z0, w, h, face="-y", cross=True, cut=t),
                                                arch_top(q, 0, 0, z0 + h, w / 2, RO_S - RI_S, cut=t)))
    L.transformed(g, polar_m(a, RI_S), lambda q: S.window(q, 0, 0, z0, w, h, face="+y", cross=True, sill=False, cut=t))


# ================================================================== 땅 위 입구 정자
def casino_gate(g):
    # 받침(고리) + 디딤 둘(문 앞)
    arc_wall(g, "Stone", 0.0, Z_LAND, RI_S, R_PL, -180, 180, n=48)
    arc_wall(g, "StoneTrim", Z_LAND, Z_LAND + 0.15, R_PL - 0.6, R_PL - 0.2, -180, 180, n=48)
    for k in range(24):
        a = 7.5 + 15.0 * k
        C((RI_S + R_PL) / 2 * math.cos(R(a)), (RI_S + R_PL) / 2 * math.sin(R(a)), Z_LAND / 2, R_PL - RI_S + 0.2,   # 벽 밑·문턱까지(파낸 굴 위)
          2 * R_PL * math.sin(R(7.5)) + 0.05, Z_LAND, R(a))
    # 들어서는 마루(문 안쪽 부채꼴, 높이 0.4) — 여기서 계단이 시작한다
    sector(g, "Marble", 1.0, RI_S, A_START - 80.0, A_START, 0.0, Z_LAND, n=8)
    for a in (A_START - 70.0, A_START - 40.0, A_START - 10.0):
        C(4.3 * math.cos(R(a)), 4.3 * math.sin(R(a)), Z_LAND / 2, 6.6, 2 * RI_S * math.sin(R(15)), Z_LAND, R(a))
    # 벽(문 자리 비움) + 문 위 상인방 + 띠 + 벽기둥
    arc_wall(g, "Brick", Z_LAND, 10.0, RI_S, RO_S, DOOR_A + DOOR_H, DOOR_A - DOOR_H + 360, n=48)
    arc_wall(g, "Brick", 8.4, 10.0, RI_S, RO_S, DOOR_A - DOOR_H, DOOR_A + DOOR_H, n=6)
    ring_coll(RI_S, RO_S, Z_LAND, 10.0, skip=[(DOOR_A, DOOR_H, Z_LAND, 8.4)])
    arc_wall(g, "StoneTrim", 10.0, 10.7, RI_S - 0.3, RO_S + 0.6, -180, 180, n=48)
    arc_wall(g, "StoneTrim", Z_LAND, 1.4, RO_S, RO_S + 0.3, DOOR_A + DOOR_H + 3, DOOR_A - DOOR_H - 3 + 360, n=40)
    for a in range(-90 + 45, 270, 45):
        if adiff(a, DOOR_A) < 30:
            continue
        L.transformed(g, polar_m(a, RO_S), lambda t: (t["BrickDark"].box(0, -0.35, (Z_LAND + 10.0) / 2, 1.2, 0.7, 10.0 - Z_LAND),
                                                    t["StoneTrim"].box(0, -0.45, 9.6, 1.6, 0.9, 0.5)))
    # 창 다섯(벽기둥 사이, 문 반대쪽으로) — 진짜 구멍, 반원 머리
    for a in (-22.5, 22.5, 90.0 - 22.5, 90.0 + 22.5, 180.0 + 22.5):
        rwin_ring(g, a, 3.0, 1.8, 4.2, 1.2)
    # 돔(청동, 층층 고리) + 안 천장판 + 유리 등탑 + 꼭대기
    zc = 10.7
    for r0, r1, h in ((RO_S + 0.4, 8.2, 1.2), (8.2, 7.3, 1.2), (7.3, 5.9, 1.2), (5.9, 4.0, 1.0), (4.0, 1.9, 0.8)):
        g["Verdigris"].cyl(0, 0, zc, r0, r1, h, seg=32)
        zc += h
    for k in range(8):
        a = 22.5 + 45 * k
        pts = [((RO_S + 0.45 - d) * math.cos(R(a)), (RO_S + 0.45 - d) * math.sin(R(a)), 10.75 + z) for d, z in
               ((0.0, 0.0), (0.4, 1.2), (1.3, 2.4), (2.7, 3.6), (4.6, 4.6), (6.7, 5.4))]
        sweep(g, "Brass", pts, 0.18, seg=6)
    g["StoneTrim"].cyl(0, 0, 10.0, RI_S, RI_S, 0.7, seg=32)
    g["WinGlass"].cyl(0, 0, zc, 1.6, 1.6, 1.8, seg=16)
    for k in range(8):
        a = 2 * math.pi * k / 8
        g["Iron"].box(1.65 * math.cos(a), 1.65 * math.sin(a), zc + 0.9, 0.18, 0.18, 1.8)
    g["Iron"].cyl(0, 0, zc + 1.8, 2.0, 0.4, 0.8, seg=16)
    g["Glow"].cyl(0, 0, zc + 0.2, 0.7, 0.7, 1.2, seg=10)
    g["Iron"].cyl(0, 0, zc + 2.6, 0.1, 0.1, 2.0, seg=6)
    S.gear(g, "Brass", 0, 0, zc + 4.0, 0.8, 10, 0.12)
    # 문: 돌 문틀 + 바깥으로 활짝 연 쇠창살 문짝 둘 + 간판 + 문 등 둘
    fr = polar_m(DOOR_A, RO_S)

    def doorway(t):
        hw = RO_S * math.sin(R(DOOR_H))
        for s in (-1, 1):
            t["StoneTrim"].box(s * (hw + 0.35), -0.3, (Z_LAND + 8.6) / 2, 0.8, 0.9, 8.6 - Z_LAND)
            # 쇠창살 문짝(경첩 = 문틀, 바깥으로 110 도)
            beta = R(110.0)
            hx = s * hw
            ux, uy = -s * math.cos(beta), -math.sin(beta)
            for k in range(6):
                d = 0.2 + k * 0.4
                t["Iron"].box(hx + ux * d, uy * d - 0.2, Z_LAND + 3.9, 0.1, 0.1, 7.6)
            for zz in (1.2, 4.0, 7.4):
                t["Iron"].obox(hx + ux * 1.2, uy * 1.2 - 0.2, Z_LAND + zz, 2.4, 0.08, 0.15, rz=math.atan2(uy, ux))
            t["Brass"].obox(hx + ux * 1.2, uy * 1.2 - 0.2, Z_LAND + 7.9, 2.4, 0.1, 0.25, rz=math.atan2(uy, ux))
        t["StoneTrim"].box(0, -0.35, 8.9, 2 * hw + 1.6, 1.0, 0.8)
        t["Brass"].box(0, -1.0, 9.7, 6.0, 0.3, 1.4)
        t["SignRed"].box(0, -1.17, 9.7, 5.4, 0.06, 1.0)
        for s in (-1, 1):
            S.gear(t, "Brass", s * 3.4, -1.1, 9.7, 0.7, 10, 0.15)
            t["Iron"].box(s * 4.6, -0.6, 6.0, 0.3, 1.0, 0.3)
            t["Iron"].cyl(s * 4.6, -1.1, 5.0, 0.35, 0.45, 1.0, seg=8)
            t["Glow"].box(s * 4.6, -1.1, 6.2, 0.5, 0.5, 0.8)
            t["LampPt"].box(s * 4.6, -1.6, 6.2, 0.3, 0.3, 0.3)
        # 문 앞 디딤(받침 0.4 를 한 번에) — 받침 고리 위 깔판
        t["Stone"].box(0, -3.0, 0.2, 2 * hw + 2.0, 2.0, 0.4)
    L.transformed(g, fr, doorway)
    # 안: 계단 위 샹들리에(천장판 밑)
    g["Iron"].cyl(0, 0, 7.6, 0.06, 0.06, 2.4, seg=6)
    S.ring(g, "Brass", 0, 0, 7.4, 1.6, 1.9, 0.25, n=20)
    for k in range(6):
        a = 2 * math.pi * k / 6
        g["Glow"].box(1.75 * math.cos(a), 1.75 * math.sin(a), 7.85, 0.2, 0.2, 0.4)
    g["LampPt"].box(0, 0, 6.8, 0.3, 0.3, 0.3)
    PROP("Casino_Under", 0, 0, 0, 0.0)
    # 땅 파기: 입구 굴(세계 축 정사각 ±8 — 안쪽 반지름 7.6 을 덮고, 꼭짓점 11.3 은 받침 고리 11.6 안에 든다)
    DIG(-8.0, 8.0, -8.0, 8.0, ZU - 1.6, 1.0, world=True)


# ================================================================== 땅 밑
def spiral(g):
    """굴 벽 + 나선 계단 + 가운데 기둥 + 바깥 손잡이 + 벽 등 + 바닥"""
    arc_wall(g, "Brick", ZU, ZU + 9.0, RI_S, RO_S, EXIT_A + DOOR_H, EXIT_A - DOOR_H + 360, n=48)
    arc_wall(g, "Brick", ZU + 9.0, 0.0, RI_S, RO_S, -180, 180, n=48)
    ring_coll(RI_S, RO_S, ZU, 0.4, skip=[(EXIT_A, DOOR_H, ZU, ZU + 9.0)])
    for z in range(int(ZU) + 4, 0, 6):
        arc_wall(g, "StoneTrim", z, z + 0.4, RI_S - 0.15, RI_S, -180, 180, n=48)
    sector(g, "Marble", 0.0, RO_S, -180, 180, ZU - 0.5, ZU, n=32)
    C(0, 0, ZU - 0.25, 2 * RO_S, 2 * RO_S, 0.5)
    g["Brass"].cyl(0, 0, ZU, 0.9, 0.9, 10.4 - ZU, seg=16)
    for z in range(int(ZU) + 2, 10, 3):
        g["Iron"].cyl(0, 0, z, 1.0, 1.0, 0.3, seg=16)
    C(0, 0, (ZU + 10.4) / 2, 1.8, 1.8, 10.4 - ZU)
    rail = []
    for i in range(N_STEP):
        a0 = A_START + i * D_STEP
        a1 = a0 + D_STEP
        top = Z_LAND - (i + 1) * RISE
        sector(g, "Wood" if i % 2 else "Timber", 0.95, RI_S - 0.05, a0, a1, top - 0.35, top, n=2)
        sector(g, "Iron", 0.95, RI_S - 0.05, a0, a1, top - 0.6, top - 0.35, n=2)
        sector(g, "Banner", 2.2, 6.2, a0 + 0.5, a1 - 0.5, top, top + 0.04, n=2)
        am = (a0 + a1) / 2
        C(4.6 * math.cos(R(am)), 4.6 * math.sin(R(am)), top - 0.3, 5.8, 2 * RI_S * math.sin(R(D_STEP / 2)) + 0.1, 0.6, R(am))
        rail.append((7.1 * math.cos(R(am)), 7.1 * math.sin(R(am)), top + 3.0))
        if i % 2 == 0:
            g["Iron"].cyl(7.1 * math.cos(R(am)), 7.1 * math.sin(R(am)), top, 0.07, 0.07, 3.0, seg=5)
    sweep(g, "Brass", rail, 0.12, seg=6)
    for k, (a, z) in enumerate(((0.0, -4.0), (180.0, -9.0), (0.0, -15.0), (180.0, -21.0), (90.0, -24.0))):
        x, y = (RI_S - 0.6) * math.cos(R(a)), (RI_S - 0.6) * math.sin(R(a))
        g["Brass"].box(x, y, z, 0.6, 0.6, 0.3)
        g["Glow"].box(x, y, z + 0.5, 0.5, 0.5, 0.7)
        g["Iron"].box(x, y, z + 0.95, 0.7, 0.7, 0.15)
        g["LampPt"].box((RI_S - 1.2) * math.cos(R(a)), (RI_S - 1.2) * math.sin(R(a)), z + 0.5, 0.3, 0.3, 0.3)


def foyer(g):
    """로비(y 8.6..24.6): 굴 문 → 붉은 길 → 큰 쌍문. 왼쪽 외투 맡기는 곳, 오른쪽 환전 창구, 문지기 자동인형 둘"""
    x0, x1, y0, y1 = -10.0, 10.0, RO_S, 24.6
    zc = ZU + 12.0
    box2(g, "Stone", x0, x1, y0, y1, ZU - 1.5, ZU)
    wall_door(g, "Brick", x0, x1, y0, y0 + 1.0, ZU, zc, -2.2, 2.2, ZU + 9.0)
    for s in (-1, 1):
        box2(g, "Brick", *sorted((s * x1, s * (x1 - 1.0))), y0 + 1.0, y1, ZU, zc)
    box2(g, "Wood", x0, x1, y0, y1, zc, zc + 0.6, coll=False)
    for i in range(9):
        for j in range(7):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(-8.0 + i * 2.0, y0 + 2.0 + j * 2.0, ZU + 0.03, 2.0, 2.0, 0.06)
    g["Banner"].box(0, (y0 + y1) / 2 + 0.5, ZU + 0.08, 4.0, y1 - y0 - 1.0, 0.04)
    for s in (-1, 1):
        for k in range(5):
            g["Wood"].box(s * (x1 - 1.05), y0 + 2.0 + k * 3.2, ZU + 1.5, 0.1, 2.8, 3.0)
        g["Brass"].box(s * (x1 - 1.05), (y0 + y1) / 2, ZU + 3.05, 0.12, y1 - y0 - 1.0, 0.12)
    # 외투 맡기는 곳(왼쪽): 반쪽 문 달린 계산대 + 뒤 옷걸이 줄 + 외투들 + 번호표판
    box2(g, "Wood", -9.0, -6.0, 12.0, 20.0, ZU, ZU + 3.2)
    g["Brass"].box(-6.0, 16.0, ZU + 3.3, 0.6, 8.2, 0.12)
    g["Iron"].hcyl(-8.6, 16.0, ZU + 6.4, 0.08, 7.6, axis="y", seg=6)
    for k in range(9):
        y = 12.6 + k * 0.85
        g[("Leather", "Banner", "Canvas", "SignBlue", "Iron")[k % 5]].box(-8.6, y, ZU + 5.0, 0.5, 0.7, 2.8)
    for r in range(3):
        for c in range(6):
            g["Brass"].box(x0 + 1.12, 13.0 + c * 0.8, ZU + 8.0 - r * 0.7, 0.05, 0.3, 0.4)
    # 환전 창구(오른쪽): 놋쇠 창살 칸 + 창구 셋 + 금고
    box2(g, "Wood", 6.0, 9.0, 12.0, 20.0, ZU, ZU + 3.4)
    C(7.5, 16.0, ZU + 5.0, 3.0, 8.0, 10.0)
    for k in range(17):
        g["Brass"].box(6.05, 12.0 + k * 0.5, ZU + 6.2, 0.1, 0.1, 5.6)
    g["Brass"].box(6.05, 16.0, ZU + 9.0, 0.3, 8.2, 0.3)
    g["Brass"].box(6.05, 16.0, ZU + 3.5, 0.3, 8.2, 0.2)
    for y in (13.5, 16.0, 18.5):
        g["Iron"].box(6.0, y, ZU + 4.1, 0.15, 1.2, 1.0)
        for k in range(4):
            g["SignGold"].cyl(6.4, y - 0.3 + k * 0.2, ZU + 3.6, 0.15, 0.15, 0.06 + k * 0.04, seg=8)
    g["Iron"].box(8.3, 19.6, ZU + 1.8, 1.2, 1.4, 3.6)
    g["Brass"].hcyl(7.66, 19.6, ZU + 2.2, 0.45, 0.1, axis="x", seg=12)
    # 문지기 자동인형 둘(큰 쌍문 양옆, 문 쪽을 본다) + 놋쇠 화병 + 그림
    for s in (-1, 1):
        armor_stand(g, s * 5.6, y1 - 2.4, ZU, R(180))
        g["Brass"].cyl(s * 8.3, y1 - 1.8, ZU, 0.6, 0.9, 2.4, seg=12)
        g["Felt"].cyl(s * 8.3, y1 - 1.8, ZU + 2.4, 0.9, 1.2, 1.2, seg=8)
        C(s * 8.3, y1 - 1.8, ZU + 1.8, 2.0, 2.0, 3.6)
    g["Brass"].box(0, y0 + 1.1, ZU + 10.6, 6.4, 0.2, 1.6)
    g["SignRed"].box(0, y0 + 1.2, ZU + 10.6, 5.8, 0.06, 1.1)
    # 샹들리에
    hang_chandelier(g, 0, 16.5, zc, ZU + 8.0, 2.2)
    DIG(x0 - 1.0, x1 + 1.0, y0 - 1.0, y1 + 1.0, ZU - 1.6, zc + 1.0)


def hang_chandelier(g, x, y, ztop, zl, r):
    """놋쇠 고리 둘 + 촛불 + 유리 방울 + 사슬 + 등"""
    g["Iron"].cyl(x, y, zl + 0.6, 0.06, 0.06, ztop - zl - 0.6, seg=6)
    for rr, dz in ((r, 0.0), (r * 0.6, 0.9)):
        S.ring(g, "Brass", x, y, zl + dz, rr - 0.25, rr, 0.3, n=24)
        n = max(6, int(rr * 4))
        for k in range(n):
            a = 2 * math.pi * k / n
            g["Glow"].box(x + (rr - 0.12) * math.cos(a), y + (rr - 0.12) * math.sin(a), zl + dz + 0.5, 0.18, 0.18, 0.4)
    sphere(g, "Glass", (x, y, zl - 0.6), 0.5, sub=1)
    g["LampPt"].box(x, y, zl - 0.2, 0.3, 0.3, 0.3)


def roulette(g, x, y, z0):
    g["Wood"].cyl(x, y, z0, 2.6, 2.6, 2.8, seg=28)
    g["Felt"].cyl(x, y, z0 + 2.8, 2.4, 2.4, 0.06, seg=28)
    g["Wood"].cyl(x, y, z0 + 2.86, 1.3, 1.3, 0.12, seg=24)
    for kk in range(18):
        a = 2 * math.pi * kk / 18
        g["SignRed" if kk % 2 else "DarkStone"].box(x + 1.1 * math.cos(a), y + 1.1 * math.sin(a), z0 + 3.0, 0.3, 0.3, 0.04)
    g["Brass"].cyl(x, y, z0 + 2.98, 0.3, 0.1, 0.5, seg=10)
    sphere(g, "Marble", (x + 0.6, y, z0 + 3.08), 0.1, sub=1)
    C(x, y, z0 + 1.45, 5.2, 5.2, 2.9)
    for kk in range(6):
        a = math.pi * (0.55 + 0.18 * kk)
        g["Wood"].cyl(x + 3.6 * math.cos(a), y + 3.6 * math.sin(a), z0 + 1.6, 0.5, 0.5, 0.2, seg=12)
        g["Iron"].cyl(x + 3.6 * math.cos(a), y + 3.6 * math.sin(a), z0, 0.08, 0.08, 1.6, seg=6)


def card_table(g, x, y, z0):
    g["Wood"].box(x, y, z0 + 1.4, 4.2, 2.6, 2.8)
    g["Felt"].box(x, y, z0 + 2.82, 3.9, 2.3, 0.06)
    for kk in range(5):
        g["Marble"].obox(x - 1.2 + kk * 0.6, y - 0.6 + (kk % 2) * 0.3, z0 + 2.87, 0.4, 0.6, 0.02, rz=0.2 * kk)
    for kk in range(4):
        g["SignRed" if kk % 2 else "SignBlue"].cyl(x + 1.4, y + 0.6, z0 + 2.85 + kk * 0.08, 0.16, 0.16, 0.08, seg=8)
    C(x, y, z0 + 1.4, 4.2, 2.6, 2.8)
    for sy in (-1, 1):
        for sx in (-1, 1):
            g["Wood"].cyl(x + sx * 1.2, y + sy * 2.2, z0 + 1.6, 0.5, 0.5, 0.2, seg=10)
            g["Iron"].cyl(x + sx * 1.2, y + sy * 2.2, z0, 0.08, 0.08, 1.6, seg=6)
    g["Brass"].cyl(x, y, z0 + 2.9, 0.15, 0.15, 0.7, seg=6)
    g["Felt"].box(x, y, z0 + 3.7, 0.9, 0.5, 0.25)


def main_hall(g):
    """큰 도박장(x ±26, y 24.6..64.6, 천장 -14)"""
    x0, x1, y0, y1 = -26.0, 26.0, 24.6, 64.6
    zc = ZU + 14.0
    ix0, ix1, iy0, iy1 = x0 + 1.0, x1 - 1.0, y0 + 1.0, y1 - 1.0
    box2(g, "Stone", x0, x1, y0, y1, ZU - 1.5, ZU)
    wall_door(g, "Brick", x0, x1, y0, y0 + 1.0, ZU, zc, -4.0, 4.0, ZU + 10.0)
    box2(g, "Brick", x0, x1, y1 - 1.0, y1, ZU, zc)
    box2(g, "Brick", x0, ix0, iy0, iy1, ZU, zc)
    # 오른 벽: 경매장 문(y 41..47, 높이 10)
    box2(g, "Brick", ix1, x1, iy0, 41.0, ZU, zc)
    box2(g, "Brick", ix1, x1, 47.0, iy1, ZU, zc)
    box2(g, "Brick", ix1, x1, 41.0, 47.0, ZU + 10.0, zc)
    # 큰 쌍문 틀(로비 쪽에서 보이게) + 문짝 둘(안으로 활짝)
    for s in (-1, 1):
        g["StoneTrim"].box(s * 4.5, y0 - 0.3, ZU + 5.0, 1.0, 0.8, 10.0)
        g["Brass"].box(s * 3.9, iy0 + 1.4, ZU + 4.8, 0.2, 2.6, 9.6)
        g["Wood"].box(s * 3.75, iy0 + 1.4, ZU + 4.8, 0.2, 2.4, 9.4)
    g["StoneTrim"].box(0, y0 - 0.35, ZU + 10.5, 10.0, 0.9, 1.0)
    g["Brass"].box(0, y0 - 0.2, ZU + 11.8, 7.0, 0.3, 1.6)
    g["SignGold"].box(0, y0 - 0.38, ZU + 11.8, 6.4, 0.06, 1.0)
    # 천장(우물 반자: 나무 들보 격자 + 놋쇠 테) + 벽 아래 판벽 + 놋쇠 띠
    g["Wood"].box(0, (y0 + y1) / 2, zc + 0.3, x1 - x0, y1 - y0, 0.6)
    for x in (-18.0, -6.0, 6.0, 18.0):
        g["Timber"].box(x, (iy0 + iy1) / 2, zc - 0.5, 0.8, iy1 - iy0, 1.0)
    for y in (34.0, 44.0, 54.0):
        g["Timber"].box(0, y, zc - 0.5, ix1 - ix0, 0.8, 1.0)
    for x in (-12.0, 0.0, 12.0):
        for y in (29.0, 39.0, 49.0, 59.0):
            g["Brass"].box(x, y, zc - 0.05, 5.0, 4.0, 0.1)
            g["Banner"].box(x, y, zc - 0.08, 4.4, 3.4, 0.06)
    for xw, s in ((ix0, 1), (ix1, -1)):
        g["Wood"].box(xw + s * 0.06, (iy0 + iy1) / 2, ZU + 2.0, 0.12, iy1 - iy0, 4.0)
        g["Brass"].box(xw + s * 0.1, (iy0 + iy1) / 2, ZU + 4.05, 0.12, iy1 - iy0, 0.15)
    g["Wood"].box(0, iy1 - 0.06, ZU + 2.0, ix1 - ix0, 0.12, 4.0)
    # 바닥: 무늬 깔개 + 붉은 길
    g["Banner"].box(0, (iy0 + 56.0) / 2, ZU + 0.04, 6.0, 56.0 - iy0, 0.06)
    for x, y in ((-6.0, 36.0), (6.0, 36.0)):
        g["Banner"].cyl(x, y, ZU + 0.02, 5.0, 5.0, 0.06, seg=24)
        S.ring(g, "Brass", x, y, ZU + 0.02, 4.8, 5.05, 0.08, n=24)
    # 쇠기둥 여섯(놋쇠 머리·받침)
    for x in (-12.0, 12.0):
        for y in (34.0, 44.0, 54.0):
            g["Iron"].cyl(x, y, ZU, 0.6, 0.55, zc - ZU, seg=12)
            g["Brass"].cyl(x, y, ZU, 0.9, 0.9, 0.8, seg=12)
            g["Brass"].cyl(x, y, zc - 1.2, 0.6, 1.1, 1.2, seg=12)
            C(x, y, (ZU + zc) / 2, 1.4, 1.4, zc - ZU)
    # 룰렛 둘(입구 가까이) + 카드 넷(기둥과 벽 사이)
    for x in (-6.0, 6.0):
        roulette(g, x, 36.0, ZU)
    for x in (-18.0, 18.0):
        for y in (37.0, 50.0):
            card_table(g, x, y, ZU)
    # 슬롯 줄: 왼 벽(앞이 +x) · 오른 벽(앞이 -x, 경매장 문 자리 비움)
    for y in (29.0, 32.0, 35.0, 38.0, 41.0, 44.0, 47.0, 50.0):
        slot_machine(g, ix0 + 1.0, y, ZU, math.pi / 2)
    for y in (29.0, 32.0, 35.0, 38.0, 50.0, 53.0):
        slot_machine(g, ix1 - 1.0, y, ZU, -math.pi / 2)
    # 바(뒤 왼쪽): 계산대 + 놋쇠 발걸이 + 걸상 + 뒷벽 술 선반 + 통
    bx0, bx1, by = -24.0, -12.0, 57.0
    box2(g, "Wood", bx0, bx1, by - 0.8, by + 0.8, ZU, ZU + 3.6)
    g["Marble"].box((bx0 + bx1) / 2, by, ZU + 3.7, bx1 - bx0 + 0.3, 1.9, 0.2)
    g["Brass"].hcyl((bx0 + bx1) / 2, by - 1.2, ZU + 0.6, 0.1, bx1 - bx0, axis="x", seg=6)
    for k in range(6):
        x = bx0 + 1.0 + k * 2.0
        g["Leather"].cyl(x, by - 2.2, ZU + 2.5, 0.55, 0.55, 0.3, seg=12)
        g["Brass"].cyl(x, by - 2.2, ZU, 0.1, 0.1, 2.5, seg=6)
    for zz in (ZU + 4.6, ZU + 6.4, ZU + 8.2):
        g["Wood"].box((bx0 + bx1) / 2, iy1 - 0.4, zz, bx1 - bx0, 0.8, 0.15)
        for k in range(int((bx1 - bx0) / 0.6)):
            bottle(g, bx0 + 0.4 + k * 0.6, iy1 - 0.4, zz + 0.08, ("Core", "SignTeal", "SignPurple", "Glow", "SignRed")[k % 5], r=0.18, h=0.6)
    g["Glass"].box((bx0 + bx1) / 2, iy1 - 0.15, ZU + 7.0, bx1 - bx0, 0.05, 5.0)
    for x in (-23.5, -21.0):
        g["Wood"].hcyl(x, iy1 - 2.2, ZU + 1.0, 1.0, 1.9, axis="y", seg=14)
        g["Iron"].hcyl(x, iy1 - 2.2, ZU + 1.0, 1.05, 0.15, axis="y", seg=14)
    C(-22.2, iy1 - 2.2, ZU + 1.0, 4.4, 2.0, 2.1)
    # 악단 무대(뒤 오른쪽, 높이 1.2): 증기 오르간(놋쇠 관) + 피아노 + 북
    sx0, sx1, sy0 = 13.0, ix1, 56.0
    box2(g, "Wood", sx0, sx1, sy0, iy1, ZU, ZU + 1.2)
    box2(g, "Wood", sx0 + 1.0, sx0 + 3.0, sy0 - 1.0, sy0, ZU, ZU + 0.6)     # 무대 디딤
    g["Banner"].box((sx0 + sx1) / 2, iy1 - 0.1, ZU + 7.0, sx1 - sx0, 0.12, 11.0)
    g["Wood"].box(19.0, iy1 - 1.2, ZU + 3.6, 6.0, 1.8, 4.8)
    for k in range(11):
        h = 3.0 + 3.0 * math.sin(math.pi * k / 10)
        g["Brass"].cyl(16.5 + k * 0.5, iy1 - 1.2, ZU + 6.0, 0.18, 0.18, h, seg=8)
    C(19.0, iy1 - 1.2, ZU + 4.0, 6.0, 1.8, 8.0)
    g["DarkStone"].box(15.5, 59.5, ZU + 2.6, 3.2, 1.6, 0.4)
    g["DarkStone"].box(15.5, 60.1, ZU + 3.3, 3.2, 0.4, 1.2)
    for sx in (-1, 1):
        g["DarkStone"].box(15.5 + sx * 1.4, 59.5, ZU + 1.9, 0.3, 1.4, 1.4)
    g["Marble"].box(15.5, 59.0, ZU + 2.85, 3.0, 0.5, 0.06)
    C(15.5, 59.6, ZU + 2.4, 3.2, 1.8, 2.4)
    g["SignRed"].cyl(22.5, 59.0, ZU + 1.2, 0.9, 0.9, 1.0, seg=14)
    g["Canvas"].cyl(22.5, 59.0, ZU + 2.2, 0.85, 0.85, 0.05, seg=14)
    # 행운의 바퀴(뒷벽 가운데): 색 칸 놋쇠 바퀴 + 바늘 + 받침
    wy = iy1 - 0.3
    g["Brass"].hcyl(0, wy, ZU + 8.0, 4.6, 0.4, axis="y", seg=32)
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        g["SignRed" if k % 2 else "SignGold"].obox(2.3 * math.cos(a), wy - 0.25, ZU + 8.0 + 2.3 * math.sin(a), 1.6, 0.06, 0.8, ry=-a)
    g["Iron"].hcyl(0, wy - 0.35, ZU + 8.0, 0.6, 0.2, axis="y", seg=12)
    g["Iron"].obox(0, wy - 0.4, ZU + 12.9, 0.4, 0.1, 1.0)
    g["Wood"].box(0, iy1 - 0.8, ZU + 1.6, 6.0, 1.6, 3.2)
    C(0, iy1 - 0.8, ZU + 1.6, 6.0, 1.6, 3.2)
    # 샹들리에 셋 + 벽 촛대 등
    for y in (34.0, 44.0, 54.0):
        hang_chandelier(g, 0, y, zc, ZU + 9.5, 2.8)
    for xw, s in ((ix0, 1), (ix1, -1)):
        for y in (31.0, 39.0, 51.0, 59.0):
            if s < 0 and 40.0 < y < 48.0:
                continue
            g["Brass"].box(xw + s * 0.15, y, ZU + 7.0, 0.3, 0.9, 1.4)
            g["Glow"].cyl(xw + s * 0.8, y, ZU + 7.6, 0.25, 0.25, 0.8, seg=8)
            g["LampPt"].box(xw + s * 0.8, y, ZU + 8.0, 0.3, 0.3, 0.3)
    DIG(x0 - 1.0, x1 + 1.0, y0 - 0.5, y1 + 1.0, ZU - 1.6, zc + 2.6)


def auction_hall(g):
    """경매장(x 26..54, y 30..56, 천장 -15): 무대(+x 벽) · 경매대 · 진열 받침(빛나는 물건) · 번호판 · 반원 걸상 셋 · 옆벽 진열장"""
    x0, x1, y0, y1 = 25.0, 54.0, 30.0, 56.0
    zc = ZU + 13.0
    ix1, iy0, iy1 = x1 - 1.0, y0 + 1.0, y1 - 1.0
    box2(g, "Stone", x0 + 1.0, x1, y0, y1, ZU - 1.5, ZU)
    box2(g, "Brick", x0 + 1.0, x1, y0, iy0, ZU, zc)
    box2(g, "Brick", x0 + 1.0, x1, iy1, y1, ZU, zc)
    box2(g, "Brick", ix1, x1, iy0, iy1, ZU, zc)
    box2(g, "Wood", x0, x1, y0, y1, zc, zc + 0.6, coll=False)
    for x in (32.0, 40.0, 48.0):
        g["Timber"].box(x, (iy0 + iy1) / 2, zc - 0.4, 0.8, iy1 - iy0, 0.8)
    for xw in (iy0, iy1):
        s = 1 if xw == iy0 else -1
        g["Wood"].box((x0 + ix1) / 2 + 0.5, xw + s * 0.06, ZU + 2.0, ix1 - x0 - 1.0, 0.12, 4.0)
        g["Brass"].box((x0 + ix1) / 2 + 0.5, xw + s * 0.1, ZU + 4.05, ix1 - x0 - 1.0, 0.12, 0.15)
    g["Banner"].box(38.0, 43.0, ZU + 0.04, 22.0, 20.0, 0.06)
    # 무대(높이 1.4) + 디딤 + 막(뒤) + 놋쇠 막대 + 번호판
    box2(g, "Wood", 46.0, ix1, 35.0, 51.0, ZU, ZU + 1.4)
    box2(g, "Wood", 45.0, 46.0, 40.0, 46.0, ZU, ZU + 0.7)
    g["Brass"].box(46.05, 43.0, ZU + 1.45, 0.1, 16.0, 0.1)
    for y0_, y1_ in ((35.0, 40.5), (45.5, 51.0)):
        g["Banner"].box(ix1 - 0.2, (y0_ + y1_) / 2, ZU + 6.6, 0.3, y1_ - y0_, 10.4)
    g["Brass"].hcyl(ix1 - 0.4, 43.0, ZU + 11.9, 0.12, 17.0, axis="y", seg=6)
    g["Brass"].box(ix1 - 0.15, 43.0, ZU + 9.6, 0.3, 5.0, 2.6)
    for k in range(3):
        g["SignGold"].box(ix1 - 0.32, 41.6 + k * 1.4, ZU + 9.6, 0.06, 1.1, 1.6)
        g["DarkStone"].box(ix1 - 0.36, 41.6 + k * 1.4, ZU + 9.6, 0.04, 0.6, 1.0)
    # 경매대(왼쪽 무대 앞) + 망치
    g["Wood"].box(47.6, 38.0, ZU + 1.4 + 1.9, 1.6, 2.2, 3.8)
    g["Brass"].box(47.6, 38.0, ZU + 5.25, 1.9, 2.5, 0.12)
    g["Wood"].obox(47.2, 38.4, ZU + 5.45, 0.25, 0.9, 0.25)
    g["Wood"].box(47.2, 38.4, ZU + 5.45, 0.5, 0.4, 0.35)
    C(47.6, 38.0, ZU + 1.4 + 1.9, 1.6, 2.2, 3.8)
    # 진열 받침(무대 가운데): 돌 기둥 + 유리 덮개 + 빛나는 핵 + 위 조명
    g["Marble"].cyl(49.5, 43.0, ZU + 1.4, 1.0, 0.8, 2.8, seg=16)
    g["Brass"].cyl(49.5, 43.0, ZU + 4.2, 1.1, 1.1, 0.15, seg=16)
    g["Glass"].cyl(49.5, 43.0, ZU + 4.35, 0.9, 0.9, 2.0, seg=16)
    sphere(g, "GlowTeal", (49.5, 43.0, ZU + 5.3), 0.55, sub=2)
    S.ring(g, "Brass", 49.5, 43.0, ZU + 5.2, 0.7, 0.85, 0.08, n=16)
    C(49.5, 43.0, ZU + 3.3, 2.2, 2.2, 4.0)
    g["Iron"].cyl(49.5, 43.0, ZU + 9.0, 0.6, 0.3, 1.0, seg=10)
    g["Iron"].cyl(49.5, 43.0, ZU + 10.0, 0.06, 0.06, zc - ZU - 10.0, seg=5)
    g["LampPt"].box(49.5, 43.0, ZU + 8.6, 0.3, 0.3, 0.3)
    # 반원 걸상 셋(무대 쪽을 본다): 가운데 (49.5, 43), 반지름 9 · 12.5 · 16, 150..210 도를 다섯 토막
    for rr in (9.0, 12.5, 16.0):
        n = 5
        for k in range(n):
            a = R(150.0 + 60.0 * (k + 0.5) / n)
            ln = 2 * rr * math.sin(R(60.0 / n / 2)) - 0.5
            bx, by = 49.5 + rr * math.cos(a), 43.0 + rr * math.sin(a)
            rz = a + math.pi / 2
            ox, oy = math.cos(a), math.sin(a)
            g["Leather"].obox(bx, by, ZU + 1.5, ln, 1.3, 0.4, rz=rz)
            g["Leather"].obox(bx + ox * 0.75, by + oy * 0.75, ZU + 2.6, ln, 0.3, 1.8, rz=rz)
            g["Wood"].obox(bx, by, ZU + 0.65, ln - 0.3, 1.0, 1.3, rz=rz)
            g["Brass"].obox(bx + ox * 0.9, by + oy * 0.9, ZU + 3.55, ln, 0.1, 0.1, rz=rz)
            C(bx + ox * 0.15, by + oy * 0.15, ZU + 1.75, ln, 1.6, 3.5, rz)
    # 옆벽 진열장 여섯(유리 상자 속 물건)
    items = ("vase", "gear", "helm", "orb", "crown", "sword")
    for k, (x, wall) in enumerate(((31.0, iy0), (37.0, iy0), (43.0, iy0), (31.0, iy1), (37.0, iy1), (43.0, iy1))):
        s = 1 if wall == iy0 else -1
        y = wall + s * 1.0
        g["Wood"].box(x, y, ZU + 1.4, 2.6, 1.6, 2.8)
        g["Glass"].box(x, y, ZU + 4.1, 2.4, 1.4, 2.6)
        g["Brass"].box(x, y, ZU + 5.45, 2.6, 1.6, 0.12)
        it = items[k]
        if it == "vase":
            g["SignBlue"].cyl(x, y, ZU + 2.8, 0.4, 0.6, 1.4, seg=12)
        elif it == "gear":
            S.gear(g, "Brass", x, y, ZU + 4.0, 0.9, 12, 0.2, axis="y")
        elif it == "helm":
            sphere(g, "Iron", (x, y, ZU + 3.6), 0.6, sub=2)
            g["Brass"].box(x, y - s * 0.55, ZU + 3.6, 0.6, 0.1, 0.15)
        elif it == "orb":
            sphere(g, "GlowTeal", (x, y, ZU + 3.6), 0.5, sub=2)
        elif it == "crown":
            S.ring(g, "SignGold", x, y, ZU + 3.0, 0.45, 0.6, 0.5, n=12)
            for j in range(6):
                a = 2 * math.pi * j / 6
                g["SignGold"].box(x + 0.52 * math.cos(a), y + 0.52 * math.sin(a), ZU + 3.7, 0.15, 0.15, 0.4)
        else:
            g["IronLight"].obox(x, y, ZU + 3.8, 2.0, 0.1, 0.25, ry=0.3)
            g["Brass"].obox(x + 0.9, y, ZU + 3.5, 0.5, 0.3, 0.1, ry=0.3)
        C(x, y, ZU + 2.7, 2.6, 1.6, 5.4)
    # 샹들리에 둘 + 벽 등
    for x in (34.0, 42.0):
        hang_chandelier(g, x, 43.0, zc, ZU + 9.0, 2.2)
    for y, s in ((iy0, 1), (iy1, -1)):
        for x in (28.0, 46.0):
            g["Brass"].box(x, y + s * 0.15, ZU + 7.0, 0.9, 0.3, 1.4)
            g["Glow"].cyl(x, y + s * 0.8, ZU + 7.6, 0.25, 0.25, 0.8, seg=8)
            g["LampPt"].box(x, y + s * 0.8, ZU + 8.0, 0.3, 0.3, 0.3)
    DIG(x0 - 0.5, x1 + 1.0, y0 - 1.0, y1 + 1.0, ZU - 1.6, zc + 2.0)


def casino_under(g):
    spiral(g)
    foyer(g)
    main_hall(g)
    auction_hall(g)


JOBS = [
    ("Casino_Gate", "CasGate", job("Casino_Gate", casino_gate, cut=1.2)),
    ("Casino_Under", "CasUnder", job("Casino_Under", casino_under, owner="Casino_Gate")),
]
