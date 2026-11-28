# -*- coding: utf-8 -*-
"""
b_ticket.py — 2026-11-14. 설원 마을 3판: 비행선 티켓 판매점(매표 창구, 발자국 14×10). 아트 부서원 1, A 양식(짙은 통나무).
계류탑(b_mast.py)과 짝 — 비행선 = 나중 이동 수단.

레퍼런스(회사/설원마을_레퍼런스.md K·C): 세우라사리 매표소(K3 — 박공 작은 나무집 + 앞면 큰 창구 + 창구 앞 선반),
브리엔츠 로트호른 역(K1 — 기둥이 받친 열린 처마 밑에서 눈 피하며 줄 섬), 뢰로스 역 초소(K2 — 폭:높이 ≈ 1:1), 뢰로스 통나무(C1).
손님은 안에 들어오지 않는다 → **앞 처마를 기둥 둘 + 앞 트러스로 4.5 내밀어** 그 밑 땅에 서서 창구 선반(땅 위 3.5)에 기댄다. 물매 50(작은 집이 높게).

배치(블렌더, 앞 = -y):
  몸 벽 가운데 선 x ±4.4 · y -0.5..3.9 → 안 7.6 × 3.2, 바닥 FB = 1(돌 밑단), 천장 10
  앞벽 창구 x ±2.5 · 땅 위 3.5..8.5(쇠살 + 아래 넘기는 틈), 바깥 선반(까치발 둘) · 안 책상 · NPC (0, 2.0) · 뒷벽 표 꽂이
  처마 밑 마당 y -5..-1.4 (판석 0.15), 기둥 x ±5.5 · y -4.5 + 앞 트러스 + 비행선 그림 판 · 뒷벽 직원 문(폭 3.6, 손님용 아님)
  창구 앞 빈 땅 x -5..5 · y -12..-2.1(처마 밑 + 앞)
"""
import math

import lib as K
import lib_int1 as P
import lib_a as A
from lib import LOG, bx, cbox, NPC, CLEAR

NAME = "Sn3_Ticket"
PREFIX = "Sn3Ticket"
VARIANT = "A"
PITCH = 50.0

FB = 1.0                                   # 몸 바닥(돌 밑단) 높이
CEIL_T = 10.0
WX, YF, YB = 4.4, -0.5, 3.9
T = LOG
HALF = WX + T / 2                          # 5.0
XI, YFI, YBI = WX - T / 2, YF + T / 2, YB - T / 2
Z_PLATE = FB + CEIL_T + 0.9                # 11.9
PORCH_Y, TRUSS_Y, POST_X = -5.0, -4.5, 5.5
LEDGE = 3.5                                # 창구 선반 높이(땅 위)
WIN = (-2.5, 2.5, LEDGE, LEDGE + 5.0)


def shell(g, R):
    S = A.sides(-WX, WX, YF, YB)
    holes = {"f": [WIN],
             "l": [A.hole(1.7, FB + 4.0, 2.0, 3.0)], "r": [A.hole(1.7, FB + 4.0, 2.0, 3.0)],
             "b": [(-1.8, 1.8, FB, FB + 8.0)]}
    A.log_box(g, -WX, WX, YF, YB, FB, Z_PLATE, holes)
    A.win(g, S, "l", 1.7, FB + 4.0, 2.0, 3.0, shutters=False)
    A.win(g, S, "r", 1.7, FB + 4.0, 2.0, 3.0, shutters=False)
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    K.gable_logs(g, "x", YF, HALF, Z_PLATE, top)
    K.gable_logs(g, "x", YB, HALF, Z_PLATE, top)
    # 뒷문은 닫아 둔다(비평 1차: 창구 너머 열린 뒷문으로 바깥이 뚫려 보임) — 문설주·인방 + 널문(두 색 널 · 띠 셋 · 쇠 띠) + 놋쇠 빗장·걸쇠
    for e0, e1 in ((-2.4, -1.8), (1.8, 2.4)):
        bx(g, "Timber", e0, e1, YB - T / 2 - 0.1, YB + T / 2 + 0.1, FB, FB + 8.6)
    bx(g, "Timber", -2.4, 2.4, YB - T / 2 - 0.1, YB + T / 2 + 0.1, FB + 8.0, FB + 8.6)
    for i in range(4):
        bx(g, "DarkLog" if i % 2 else "Timber", -1.8 + 0.9 * i + 0.02, -1.8 + 0.9 * (i + 1) - 0.02, YB - 0.18, YB + 0.18, FB, FB + 8.0)
    for zz in (FB + 1.4, FB + 4.0, FB + 6.6):
        bx(g, "Timber", -1.8, 1.8, YB - 0.33, YB - 0.18, zz - 0.3, zz + 0.3)
        bx(g, "Iron", -1.5, 1.5, YB - 0.38, YB - 0.33, zz - 0.12, zz + 0.12)
    bx(g, "Brass", 0.8, 1.7, YB - 0.45, YB - 0.33, FB + 4.6, FB + 4.8)
    bx(g, "Brass", 1.65, 2.0, YB - 0.5, YB - 0.33, FB + 4.5, FB + 4.9)
    cbox(-1.8, 1.8, YB - 0.2, YB + 0.2, FB, FB + 8.0)


def wicket(g):
    """창구: 쇠살(위 2/3) + 놋쇠 테 + 아래 넘기는 틈 · 바깥 선반(까치발 둘) · 안 책상"""
    a, b, z0, z1 = WIN
    zg = z0 + 1.3                                       # 쇠살 아래 끝(그 밑은 표·돈 넘기는 틈)
    bx(g, "Brass", a, b, YF - 0.15, YF + 0.15, zg - 0.15, zg)
    bx(g, "Brass", a, b, YF - 0.15, YF + 0.15, z1 - 0.2, z1)
    n = 9
    for i in range(1, n):
        x = a + (b - a) * i / n
        bx(g, "Iron", x - 0.05, x + 0.05, YF - 0.05, YF + 0.05, zg, z1 - 0.2)
    bx(g, "Iron", a, b, YF - 0.05, YF + 0.05, (zg + z1) / 2 - 0.05, (zg + z1) / 2 + 0.05)
    # 선반(벽을 지나 안팎으로) + 놋쇠 앞 테 + 까치발
    yo = YF - T / 2 - 1.3
    bx(g, "Wood", a - 0.4, b + 0.4, yo, YFI + 0.6, z0 - 0.2, z0)
    bx(g, "Brass", a - 0.4, b + 0.4, yo - 0.08, yo, z0 - 0.25, z0 + 0.05)
    for x in (a + 0.3, b - 0.3):
        g["DarkLog"].obox(x, (YF - T / 2 + yo + 0.3) / 2, z0 - 0.9, 0.3, 1.6, 0.3, rx=0.72)
    # 안 책상 다리(바닥 FB → 선반 밑)
    for x in (a, b):
        bx(g, "Timber", x - 0.15, x + 0.15, YFI + 0.2, YFI + 0.5, FB, z0 - 0.2)
    cbox(a - 0.4, b + 0.4, YFI, YFI + 0.6, FB, z0)


def inside(g):
    """매표소 안(K3 세우라사리 매표소 · 역 매표 창구 레퍼런스 KI1~KI3): 선반 위 표 묶음 · 동전 접시 · 놋쇠 표 찍개(손잡이 지레) ·
    뒷벽 표 꽂이 둘(칸마다 표 다발) + 문 위 벽시계 · 직원 걸상 · 작은 쇠 궤 · 뒷문 옆 달력 판 · 매단 등"""
    bx(g, "Canvas", -1.8, -0.6, YFI - 0.2, YFI + 0.4, LEDGE, LEDGE + 0.25)
    bx(g, "SignGold", -1.7, -0.7, YFI - 0.15, YFI + 0.35, LEDGE + 0.25, LEDGE + 0.32)
    g["Brass"].cyl(0.4, YFI - 0.6, LEDGE, 0.45, 0.5, 0.12, seg=12)
    P.coin_stack(g, 0.3, YFI - 0.6, LEDGE + 0.12, n=2, r=0.15)
    # 표 발권기(2026-11-28 사용자 4차: '표가 나오는 구멍·손잡이·숫자판'): 무쇠 받침 · 놋쇠 몸 · 위 표 두루마리(굴대 받침 둘) ·
    # 앞 숫자판(검은 창 + 흰 숫자 패 셋) · 아래 표 나오는 구멍(쇠 입술) + 반쯤 나온 표 · 옆 돌리는 손잡이(굴대 · 팔 · 나무 쥘대) · 뒤 찍개 지레
    bx(g, "Iron", 1.15, 2.25, YFI - 0.2, YFI + 0.5, LEDGE, LEDGE + 0.15)
    bx(g, "Brass", 1.3, 2.1, YFI - 0.1, YFI + 0.45, LEDGE + 0.15, LEDGE + 1.0)
    bx(g, "Iron", 1.25, 2.15, YFI - 0.15, YFI + 0.5, LEDGE + 1.0, LEDGE + 1.08)
    for xx in (1.4, 2.0):
        bx(g, "Iron", xx - 0.06, xx + 0.06, YFI + 0.05, YFI + 0.3, LEDGE + 1.08, LEDGE + 1.38)
    g["Canvas"].hcyl(1.7, YFI + 0.18, LEDGE + 1.38, 0.28, 0.5, axis="x", seg=12)
    g["Iron"].hcyl(1.7, YFI + 0.18, LEDGE + 1.38, 0.07, 0.72, axis="x", seg=6)
    bx(g, "DarkStone", 1.38, 2.02, YFI - 0.16, YFI - 0.1, LEDGE + 0.52, LEDGE + 0.88)
    for k, ch in enumerate("042"):
        x = 1.5 + k * 0.2
        bx(g, "Paint", x - 0.08, x + 0.08, YFI - 0.19, YFI - 0.16, LEDGE + 0.58, LEDGE + 0.82)
        P.digit(g, ch, x, YFI - 0.19, LEDGE + 0.7, 0.18, "DarkStone")
    bx(g, "Iron", 1.42, 1.98, YFI - 0.22, YFI - 0.1, LEDGE + 0.24, LEDGE + 0.36)
    bx(g, "Paint", 1.5, 1.9, YFI - 0.45, YFI - 0.1, LEDGE + 0.27, LEDGE + 0.33)
    g["Iron"].hcyl(2.2, YFI + 0.2, LEDGE + 0.6, 0.08, 0.2, axis="x", seg=6)
    g["Iron"].obox(2.32, YFI + 0.2, LEDGE + 0.4, 0.12, 0.12, 0.55)
    g["Wood"].hcyl(2.42, YFI + 0.2, LEDGE + 0.17, 0.1, 0.3, axis="x", seg=8)
    g["Iron"].obox(1.7, YFI + 0.55, LEDGE + 1.25, 0.14, 0.14, 0.6, rx=-0.5)
    g["SignRed"].cyl(1.7, YFI + 0.7, LEDGE + 1.48, 0.15, 0.15, 0.15, seg=8)
    NPC(0.0, 2.0, FB, 0.0)
    P.stool(g, -2.8, 1.1, FB, h=2.4, r=0.5)
    P.strongbox(g, 3.0, YFI + 0.85, FB, w=1.2, d=0.9, h=1.1, rz=0.0)
    # 뒷벽 표 꽂이(칸 격자) — 문 양옆, 칸마다 표 다발(두 색 겹)
    for x0, x1 in ((-XI + 0.1, -2.2), (2.2, XI - 0.1)):
        bx(g, "Wood", x0, x1, YBI - 0.5, YBI, FB + 3.0, FB + 7.5)
        bx(g, "DarkLog", x0 - 0.05, x1 + 0.05, YBI - 0.6, YBI, FB + 7.5, FB + 7.8)
        for k in range(4):
            z = FB + 3.3 + k * 1.05
            bx(g, "Timber", x0 + 0.1, x1 - 0.1, YBI - 0.55, YBI - 0.45, z, z + 0.08)
            for j in range(3):
                xx = x0 + 0.3 + j * (x1 - x0 - 0.6) / 2.5
                m = ("Canvas", "SignGold", "Paint")[(j + k) % 3]
                bx(g, m, xx, xx + 0.35, YBI - 0.5, YBI - 0.2, z + 0.08, z + 0.6)
                bx(g, "SignRed" if (j + k) % 2 else "SignBlue", xx + 0.04, xx + 0.31, YBI - 0.22, YBI - 0.18, z + 0.4, z + 0.55)
        cbox(x0, x1, YBI - 0.5, YBI, FB, FB + 7.5)
    # 뒷문 위 벽시계(놋쇠 테 · 흰 판 · 바늘)
    g["DarkLog"].hcyl(0.0, YBI - 0.1, FB + 8.9, 0.85, 0.2, axis="y", seg=16)
    g["Brass"].hcyl(0.0, YBI - 0.25, FB + 8.9, 0.75, 0.12, axis="y", seg=16)
    g["Dial"].hcyl(0.0, YBI - 0.33, FB + 8.9, 0.62, 0.06, axis="y", seg=16)
    g["Iron"].obox(0.12, YBI - 0.38, FB + 9.05, 0.07, 0.03, 0.42, ry=0.7)
    g["Iron"].obox(-0.1, YBI - 0.38, FB + 8.85, 0.07, 0.03, 0.3, ry=-1.9)
    K.lantern(g, 0.0, 1.7, Z_PLATE - 0.9, FB + 7.8)


def timetable(g, x, face_y):
    """시간표 판(앞벽 바깥, 창구 양옆 — 손님이 줄 서며 본다): 짙은 틀 · 검은 판 · 줄 여섯(놋쇠 칸 + 흰 패 + 색 표지) · 위 작은 시계 · 비행선 그림 · 눈 턱"""
    y = face_y - 0.3                                   # 0.3 앞으로(비평 1차: 통나무 끝이 판 가장자리를 덮음) + 뒤 받침
    bx(g, "DarkLog", x - 0.45, x + 0.45, y, face_y, 3.6, 7.2)
    bx(g, "DarkLog", x - 0.65, x + 0.65, y - 0.25, y, 3.2, 7.6)
    bx(g, "Char", x - 0.52, x + 0.52, y - 0.3, y - 0.25, 3.4, 7.0)
    for k in range(6):
        z = 3.65 + k * 0.55
        bx(g, "Brass", x - 0.47, x + 0.47, y - 0.34, y - 0.3, z - 0.03, z)
        bx(g, "Paint", x - 0.42, x - 0.04, y - 0.36, y - 0.3, z + 0.05, z + 0.38)
        bx(g, "Paint", x + 0.04, x + 0.26, y - 0.36, y - 0.3, z + 0.05, z + 0.38)
        bx(g, ("SignRed", "SignTeal", "SignGold")[k % 3], x + 0.31, x + 0.44, y - 0.37, y - 0.3, z + 0.12, z + 0.3)
    g["Brass"].hcyl(x, y - 0.3, 8.1, 0.5, 0.15, axis="y", seg=14)
    g["Dial"].hcyl(x, y - 0.4, 8.1, 0.4, 0.06, axis="y", seg=14)
    g["Iron"].obox(x + 0.08, y - 0.45, 8.2, 0.05, 0.03, 0.3, ry=0.5)
    bx(g, "SnowCap", x - 0.7, x + 0.7, y - 0.35, y, 7.6, 7.72)


def luggage(g):
    """처마 밑 오른쪽(빈 땅 밖): 증기 트렁크(쇠 모서리 · 놋쇠 띠 · 가죽 손잡이) + 가방 둘 · 왼쪽: 바깥 옆벽에 등 댄 긴 의자"""
    A = P.At(g, 6.6, -2.6, 0.15, 0.25)
    A.box("Leather", -1.1, 1.1, -0.65, 0.65, 0, 1.4)
    A.box("Wood", -1.15, 1.15, -0.7, 0.7, 1.4, 1.6)
    for xx in (-0.7, 0.7):
        A.box("Brass", xx - 0.1, xx + 0.1, -0.72, 0.72, 0.0, 1.62)
    for sx in (-1, 1):
        for sy in (-1, 1):
            A.box("Iron", sx * 1.15 - 0.15, sx * 1.15 + 0.15, sy * 0.7 - 0.15, sy * 0.7 + 0.15, 0.0, 0.3)
            A.box("Iron", sx * 1.15 - 0.15, sx * 1.15 + 0.15, sy * 0.7 - 0.15, sy * 0.7 + 0.15, 1.35, 1.62)
    A.box("Brass", -0.2, 0.2, -0.75, -0.7, 1.0, 1.35)
    A.coll(-1.15, 1.15, -0.7, 0.7, 0, 1.62)
    B = P.At(g, 6.5, -2.7, 1.77, -0.15)
    B.box("SignBlue", -0.75, 0.75, -0.4, 0.4, 0, 0.9)
    B.box("Leather", -0.15, 0.15, -0.08, 0.08, 0.9, 1.15)
    B.box("Brass", -0.78, -0.6, -0.42, 0.42, 0.1, 0.8)
    C = P.At(g, 7.4, -0.9, 0.15, 1.2)
    C.box("Banner", -0.6, 0.6, -0.35, 0.35, 0, 1.6)
    C.box("Leather", -0.12, 0.12, -0.06, 0.06, 1.6, 1.85)
    C.coll(-0.6, 0.6, -0.35, 0.35, 0, 1.6)
    P.wall_bench(g, -HALF, 1, 0.0, 3.4, 0.0)


def porch(g, R):
    """처마 밑: 판석 · 기둥 둘(받침돌) + 까치발 + 앞 트러스 · 트러스 밑 비행선 그림 판 · 기둥 등"""
    bx(g, "Stone", -POST_X - 0.6, POST_X + 0.6, PORCH_Y, YF - T / 2 - 0.3, 0.0, 0.15)
    ztb = Z_PLATE - 0.9
    for s in (-1, 1):
        x = s * POST_X
        K.post(g, x, TRUSS_Y, 0.0, ztb, s=0.8)
        K.brace(g, "x", TRUSS_Y, x - s * 0.4, ztb - 2.2, x - s * 2.4, ztb, s=0.45)
        K.brace(g, "y", x, TRUSS_Y + 0.4, ztb - 2.2, YF - T / 2, ztb - 0.4, s=0.45)     # 기둥 → 앞벽(옆 버팀)
    # 앞 트러스: 평보는 기둥 바깥까지(기둥 머리에 얹힘)
    K.tie_truss(g, TRUSS_Y, R)
    bx(g, "DarkLog", -POST_X - 0.5, POST_X + 0.5, TRUSS_Y - 0.5, TRUSS_Y + 0.5, ztb, Z_PLATE)
    # 비행선 그림 판(쇠 막대 둘로 평보에 매닮)
    for x in (-2.6, 2.6):
        bx(g, "Iron", x - 0.06, x + 0.06, TRUSS_Y - 0.06, TRUSS_Y + 0.06, 9.2, ztb)
    bx(g, "Timber", -3.4, 3.4, TRUSS_Y - 0.15, TRUSS_Y + 0.15, 6.9, 9.2)
    bx(g, "Brass", -3.55, 3.55, TRUSS_Y - 0.2, TRUSS_Y + 0.2, 9.15, 9.35)
    bx(g, "SnowCap", -3.4, 3.4, TRUSS_Y - 0.18, TRUSS_Y + 0.18, 9.35, 9.47)
    for f in (-1, 1):
        A.airship_icon(g, 0.0, TRUSS_Y + f * 0.15, 7.2, face=f, s=1.1)
    for x in (-POST_X, POST_X):
        K.lantern(g, x * 0.72, TRUSS_Y, ztb, 7.6)
    # 오른 옆 작은 증기 통(창구 난방) → 관이 옆벽으로
    tx, ty = HALF + 1.0, 2.6
    K.steam_bundle(g, tx, ty, 0.0, h=5.0, r=0.7, gauge_face=-1, vent=False, pipe_pts=[(tx, ty + 0.7, 5.6), (tx, YB + T / 2 - 0.3, 5.6), (HALF - 0.3, YB + T / 2 - 0.3, 5.6)])


def build(g):
    R = K.RoofFrame(HALF, PORCH_Y, YB + T / 2, Z_PLATE, PITCH)
    K.foundation(g, -HALF - 0.3, HALF + 0.3, YF - T / 2 - 0.3, YB + T / 2 + 0.3, h=FB)
    K.stair(g, 0.0, YB + T / 2 + 0.3, 4.4, FB, face=1)          # 뒷문 디딤(한 단)
    shell(g, R)
    K.tie_truss(g, 1.7, R)
    porch(g, R)
    K.roof_gable(g, R)
    wicket(g)
    inside(g)
    for x in (-3.45, 3.45):
        timetable(g, x, YF - T / 2)
    luggage(g)
    # 창구 옆 종(놋쇠 종 + 쇠 받침 팔): 줄 선 손님을 부른다
    bx(g, "Iron", 2.75, 2.95, YF - T / 2 - 0.9, YF - T / 2, 8.7, 8.85)
    g["Brass"].cyl(2.85, YF - T / 2 - 0.85, 7.9, 0.4, 0.15, 0.6, seg=12)
    g["Brass"].cyl(2.85, YF - T / 2 - 0.85, 8.5, 0.08, 0.08, 0.25, seg=6)
    CLEAR(-4.9, 4.9, -12.0, YF - T / 2 - 1.5, 0.15, 5.4)


INFO = {
    "variant": VARIANT,
    "floor": 0.0,                               # 손님이 서는 땅(창구 선반 = 땅 위 3.5)
    "ceiling": FB + CEIL_T,
    "counter": (-2.5, 2.5, YF - T / 2 - 1.3, YF + T / 2),     # 창구 선반
    "free": (-5.0, 5.0, -12.0, -2.1),           # 창구 앞 빈 땅(처마 밑 + 앞)
    "walk": ((0.0, -13.5), (0.0, -8.0)),
    "inside": (-9.0, 9.0, -14.0, -1.3),
    "door_view": (0.0, YF),                     # 1인칭 "문" 시점 = 창구
    "forge_look": (0.0, 3.0),
    "plan_scale": 24,
    "hole_seeds": [(0.0, 1.7, FB + 4.5)],          # holes.py 눈 자리: 매표소 안(손님 자리에서는 쇠살 너머라 안 보임)
}
