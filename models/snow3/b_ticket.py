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
import lib as K
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
    K.door_open(g, "x", YB, 0.0, 3.6, 8.0, FB, face=1, open_deg=95.0, leaves=1)


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
    # 선반 위(창구 틈 앞): 표 묶음 · 동전 접시 · 놋쇠 표 찍개 — 뒷문 비울 자리(안 y 0.7~)를 피해 얕게
    bx(g, "Canvas", -1.8, -0.6, YFI - 0.2, YFI + 0.4, LEDGE, LEDGE + 0.25)
    g["Brass"].cyl(0.4, YFI - 0.6, LEDGE, 0.45, 0.5, 0.12, seg=12)
    bx(g, "Brass", 1.3, 2.1, YFI - 0.1, YFI + 0.45, LEDGE, LEDGE + 0.5)
    bx(g, "Iron", 1.55, 1.85, YFI - 0.3, YFI + 0.2, LEDGE + 0.5, LEDGE + 0.9)
    NPC(0.0, 2.0, FB, 0.0)
    # 뒷벽 표 꽂이(칸 격자) — 문 양옆
    for x0, x1 in ((-XI + 0.1, -2.2), (2.2, XI - 0.1)):
        bx(g, "Wood", x0, x1, YBI - 0.5, YBI, FB + 3.0, FB + 7.5)
        for k in range(4):
            z = FB + 3.3 + k * 1.05
            bx(g, "Timber", x0 + 0.1, x1 - 0.1, YBI - 0.55, YBI - 0.45, z, z + 0.08)
            for j in range(3):
                xx = x0 + 0.3 + j * (x1 - x0 - 0.6) / 2.5
                bx(g, ("Canvas", "SignGold", "Paint")[(j + k) % 3], xx, xx + 0.35, YBI - 0.5, YBI - 0.2, z + 0.08, z + 0.6)
        cbox(x0, x1, YBI - 0.5, YBI, FB, FB + 7.5)
    K.lantern(g, 0.0, 1.7, Z_PLATE - 0.9, FB + 7.8)


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
    K.steam_bundle(g, tx, ty, 0.0, h=5.0, r=0.7, gauge_face=-1, pipe_pts=[(tx, ty + 0.7, 5.6), (tx, YB + T / 2 - 0.3, 5.6), (HALF - 0.3, YB + T / 2 - 0.3, 5.6)])


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
}
