# -*- coding: utf-8 -*-
"""
snow_plan2.py — 슈네라이히 2판 배치표. (2026-10-09)

1판(snow_town_plan.py → Snow_Town.luau)은 큰 마을 땅에 키운 건물 몇 채만 흩어 놓아 휑했다(사용자: "퀄리티가 개떡락").
옛 도시(snow_plan.py → Snow_City.luau, ServerStorage.Snow_Old)의 밀도·소품을 그대로 따른다:
  집은 배율 1 로 빽빽이, 광장을 도는 고리 셋 + 방사 대로, 쇠 받침 위 난방관·모음통·김구멍, 가스등, 포장길·연석, 맨홀,
  도는 톱니, 계류탑과 비행선, 체스판 연병장.
자리는 사용자 마을 그림(설원 지도.jpg 왼쪽 위 확대 그림) 그대로:
  가운데 시계 광장 · 둘레 상점(잡화 북, 장비 북동, 물약 서북서, 강화소 남동) · 북(동) 공방 · 동 카지노+경매장 · 서 공장
  · 남서 천문대(조율자 전직) · 남 여관·티켓 판매점·지하 입구 · 남동 체스판 건물.
마을 땅 = 높이 59.8 평지(tools/snow_town_ground.json — 스튜디오에서 4 스터드 간격으로 잰 값). 서·북은 높은 바위, 동·남은 바위 계단으로 내려간다.

**자리는 전부 이 표에 손으로 적는다.** polar() 는 각도·반지름을 좌표로 바꾸기만 한다.
이 파일은 평면도(PNG)를 그리고, 겹침·땅·관을 검사하고, Snow_City2_data.luau 를 뽑는다.
  python tools/snow_plan2.py [출력.png]
  sed -e '/--@@DATA@@/r tools/Snow_City2_data.luau' tools/Snow_City2.luau > tools/swamp/_city2_run.luau && bash tools/job.sh tools/swamp/_city2_run.luau
좌표는 스터드, yaw 는 도. 0 이면 모델 앞(-Z)이 -Z(북)을 본다. 90 이면 -X(서), -90 이면 +X(동), 180 이면 +Z(남).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_png import Canvas, seg_rect  # noqa: E402

# SnowKit 잰 발자국(배율 1). (base x0 x1 z0 z1), (all x0 x1 z0 z1) — Snow_TownKit 보고(snowtownkit) 그대로
KIT = {
    "Airship": ((-10.0, 10.0, -12.3, 12.3), (-12.8, 12.8, -30.0, 30.0)),
    "Big_Gear": ((-6.0, 6.0, -2.5, 2.5), (-6.3, 6.3, -2.8, 2.8)),
    "Boiler_Tank": ((-3.6, 5.7, -3.7, 3.5), (-3.6, 5.7, -3.7, 3.5)),
    "Casino_Hall": ((-39.5, 21.0, -19.4, 16.0), (-40.6, 21.0, -19.4, 16.2)),
    "City_Gate": ((-13.0, 13.0, -3.0, 3.0), (-13.0, 13.0, -3.0, 3.0)),
    "Clock_Tower": ((-8.5, 8.5, -8.5, 8.5), (-8.5, 8.5, -8.5, 8.5)),
    "Figuren_HQ": ((-25.1, 25.1, -22.0, 14.0), (-25.1, 25.1, -22.0, 14.6)),
    "Frostig_Werk": ((-12.6, 20.0, -11.0, 9.6), (-15.5, 20.4, -14.2, 10.3)),
    "Gas_Lamp": ((-0.9, 0.9, -2.6, 0.7), (-0.9, 0.9, -2.6, 0.7)),
    "Herzofen": ((-20.0, 20.0, -20.0, 20.0), (-20.4, 20.4, -20.4, 20.4)),
    "Inn_House": ((-12.6, 12.6, -10.0, 8.6), (-12.6, 12.6, -13.7, 13.7)),
    "Mooring_Mast": ((-4.5, 4.5, -4.5, 4.5), (-4.5, 4.5, -8.9, 4.5)),
    "Observatory": ((-19.0, 25.5, -19.0, 19.0), (-19.0, 26.7, -19.0, 19.0)),
    "Sel_Werk_Ruin": ((-12.6, 12.6, -9.6, 9.6), (-15.2, 12.6, -10.0, 10.5)),
    "Shop_Blue": ((-8.6, 8.6, -8.0, 6.6), (-8.6, 10.7, -11.4, 9.6)),
    "Shop_Red": ((-8.6, 8.6, -8.0, 6.6), (-8.6, 10.7, -11.4, 9.6)),
    "Shop_Teal": ((-8.6, 8.6, -8.0, 6.6), (-8.6, 10.7, -11.4, 9.6)),
    "Steam_Factory": ((-19.0, 19.0, -27.0, 27.0), (-19.7, 26.8, -27.4, 27.4)),
    "Steam_House_A": ((-7.6, 7.6, -8.0, 6.6), (-10.3, 8.7, -8.3, 7.2)),
    "Steam_House_B": ((-15.3, 11.0, -9.0, 7.6), (-16.2, 11.0, -9.3, 8.1)),
    "Steam_House_C": ((-6.6, 6.6, -8.0, 6.6), (-9.1, 9.2, -9.2, 7.0)),
    "Ticket_Booth": ((-6.5, 5.0, -4.0, 4.0), (-6.5, 5.3, -5.1, 4.3)),
    "Under_Gate": ((-7.0, 7.0, -6.8, 5.0), (-7.5, 7.5, -7.0, 5.5)),
    "Vertical_Boiler": ((-3.7, 3.7, -3.7, 3.7), (-3.7, 4.6, -3.8, 3.7)),
    "Zapfen_Werk": ((-45.0, 40.0, -21.0, 18.0), (-46.7, 40.0, -21.0, 18.0)),
}
SMALL = {"Gas_Lamp", "Boiler_Tank", "Big_Gear", "Vertical_Boiler"}
A, B, C_, SR, ST, SB = "Steam_House_A", "Steam_House_B", "Steam_House_C", "Shop_Red", "Shop_Teal", "Shop_Blue"

# 들어갈 수 있는 건물. (이름표: 안쪽 방 id, 문 로컬 x, z(배율 1), 문 폭) — 옛 Snow_City 와 같은 값, 배율은 짓는 쪽이 곱한다
DOORS = {
    "frostig": ("Frostig", 6.0, -9.0, 3.4),
    "zapfen": ("Zapfen", 0.0, -17.0, 12.0),
    "sel": ("Sel", 6.0, -9.0, 3.4),
    "figuren": ("Figuren", 0.0, -16.0, 5.0),
}

# ================================================================== 마을
# 시계 광장(r 42)을 고리길 셋(r 48 · 94 · 140, 폭 10)이 돌고, 집은 고리 사이(r 72 · 117 · 162)에 광장을 바라보고 둘러선다.
# 방사 대로(폭 18) 넷: 동 → 카지노, 서 → 공장, 북동 → 공방, 남 → 계류탑 전망대. 골목(폭 9) 셋: 남동 → 체스판, 남서 → 천문대, 북 → 북쪽 거리.
CX, CZ = -4933.0, -3818.0
TH_NE = -61.6  # 북동 대로 = 광장 → 공방 문
TH_SE, TH_SW, TH_N = 31.0, 132.0, -100.0


def polar(th, r):
    """θ 0 이 동(+X), 90 이 남(+Z). x, z 와 광장을 바라보는 yaw"""
    a = math.radians(th)
    return round(CX + r * math.cos(a), 1), round(CZ + r * math.sin(a), 1), round(90.0 - th, 1)


def ring(kind, th, r, grp, tag="", sc=1.0, tweak=0.0):
    x, z, yaw = polar(th, r)
    return (kind, x, z, yaw + tweak, grp, tag, sc)


def u(th):
    return math.cos(math.radians(th)), math.sin(math.radians(th))


BUILD = [
    # (틀, x, z, yaw, 묶음, 이름표, 배율)
    ("Clock_Tower", CX, CZ, 0, "광장", "", 1.3),
    # ── 그림의 큰 건물 ──
    ("Zapfen_Werk", -4790, -4105, 180, "공방", "zapfen", 1.3),   # 북(동). 문이 북동 대로 끝(앞마당)을 본다
    ("Casino_Hall", -4665, -3830, 90, "카지노", "", 1.3),         # 동. 앞이 동대로(서)를 본다
    ("Steam_Factory", -5240, -3818, -90, "공장", "", 1.3),        # 서. 앞이 서대로(동)를 본다
    ("Herzofen", -5250, -3922, -90, "공장", "", 1.0),             # 감정 변환로 — 난방관이 여기서 나온다
    ring("Observatory", TH_SW, 262, "천문대", "", 1.3),            # 남서, 조율자 전직
    ("Figuren_HQ", -4560, -3660, 90, "체스판", "figuren", 1.2),   # 남동, 앞에 체스판 연병장
    ("Mooring_Mast", CX + 52, -3600, 180, "계류탑", "", 1.0),     # 남. 비행선은 마을 끝 바위 위에 뜬다
    ("Ticket_Booth", CX + 30, -3600, 90, "계류탑", "", 1.0),      # 티켓 판매점 — 대로 쪽을 본다
    ("Big_Gear", CX, -3598, 180, "남쪽전망", "", 1.0),
    ("City_Gate", -4490, -3722, -90, "동문", "", 1.0),
    # ── 안쪽 고리 r 72: 상점 + 집 ──
    ring(SR, 20, 72, "안고리"),                 # 강화소
    ring(B, 45, 72, "안고리"),
    ring(A, 70, 72, "안고리"),
    ring(C_, 110, 72, "안고리"),
    ring(B, 135, 72, "안고리"),
    ring(A, 160, 72, "안고리"),
    ring(ST, -160, 72, "안고리"),               # 물약상점
    ring(A, -135, 72, "안고리"),
    ring(SB, -110, 72, "안고리"),               # 잡화상점
    ring(C_, -86, 72, "안고리"),
    ring("Frostig_Werk", -30, 69, "안고리", "frostig"),   # 장비상점(프로스티히 공방 — 안쪽 방)
    # ── 가운데 고리 r 117 ──
    ring(C_, 15, 117, "가운데고리"),
    ring("Under_Gate", 44, 117, "가운데고리"),  # 지하 입구(강화소 아래)
    ring(A, 57, 117, "가운데고리"),
    ring(B, 72, 117, "가운데고리"),
    ring(C_, 101, 117, "가운데고리"),
    ring("Inn_House", 116, 117, "가운데고리"),  # 여관
    ring(A, 145, 117, "가운데고리"),
    ring(C_, 158, 117, "가운데고리"),
    ring(A, 170, 117, "가운데고리"),
    ring(C_, -168, 117, "가운데고리"),
    ring(B, -156, 117, "가운데고리"),
    ring(A, -140, 117, "가운데고리"),
    ring(C_, -126, 117, "가운데고리"),
    ring(A, -113, 117, "가운데고리"),
    ring(C_, -88, 117, "가운데고리"),
    ring(A, -75, 117, "가운데고리"),
    ring(A, -48, 117, "가운데고리"),
    ring(B, -34, 117, "가운데고리"),
    ring(C_, -19, 117, "가운데고리"),
    # ── 바깥 고리 r 162 ──
    ring(C_, 11, 162, "바깥고리"),
    ring(A, 22, 162, "바깥고리"),
    ring(B, 41, 162, "바깥고리"),
    ring(A, 54, 162, "바깥고리"),
    ring(C_, 66, 162, "바깥고리"),
    ring(A, 78, 162, "바깥고리"),
    ring(C_, 102, 162, "바깥고리"),
    ring(A, 114, 162, "바깥고리"),
    ring(C_, 124, 162, "바깥고리"),
    ring(A, 141, 162, "바깥고리"),
    ring(B, 153, 162, "바깥고리"),
    ring(C_, 166, 162, "바깥고리"),
    ring(C_, -172, 162, "바깥고리"),
    ring(A, -160, 162, "바깥고리"),
    ring(B, -148, 162, "바깥고리"),
    ring(C_, -135, 162, "바깥고리"),
    ring(A, -123, 162, "바깥고리"),
    ring(C_, -111, 162, "바깥고리"),
    ring(A, -89, 162, "바깥고리"),
    ring(C_, -77, 162, "바깥고리"),
    ring(C_, -50, 162, "바깥고리"),
    ring(A, -38, 162, "바깥고리"),
    ring(B, -26, 162, "바깥고리"),
    ring(C_, -13, 162, "바깥고리"),
]

# ── 북쪽 거리(z -4040, 폭 12) 와 뒷골목(z -4128, 폭 9). 집은 거리를 본다. x 는 한 채씩 골랐다(32 간격, 골목 자리는 비움).
#    뒷골목 서쪽 끝(x < -5260)은 높은 바위라 비운다 ──
N1_Z, N2_Z = -4040.0, -4128.0
BUILD += [(k, x, -4062, 180 + t, "북쪽거리", "", 1.0) for k, x, t in [
    (A, -5292, 0), (C_, -5260, 2), (B, -5224, 0), (A, -5186, -2), (C_, -5154, 0), (A, -5122, 0), (B, -5086, 2),
    (C_, -5050, 0), (A, -5018, 0), (C_, -4986, -3), (B, -4950, 0), (A, -4914, 0), (C_, -4882, 2)]]
BUILD += [(k, x, -4016, 0 + t, "북쪽거리", "", 1.0) for k, x, t in [
    (C_, -5290, 0), (A, -5258, -2), (B, -5222, 0), (C_, -5186, 0), (A, -5106, 3), (C_, -5074, 0),
    (A, -5042, 0), (C_, -5008, -2), (A, -4936, 0), (B, -4900, 0), (C_, -4866, 2)]]
BUILD += [(k, x, -4112, 0 + t, "뒷골목", "", 1.0) for k, x, t in [
    (A, -5250, 2), (C_, -5218, 0), (A, -5186, 0), (C_, -5122, -2), (B, -5086, 0),
    (A, -5048, 0), (C_, -5016, 3), (A, -4952, 0), (C_, -4920, 0), (A, -4888, -2)]]
BUILD += [(k, x, -4146, 180 + t, "뒷골목", "", 1.0) for k, x, t in [
    (B, -5224, -2), (C_, -5188, 0), (A, -5156, 2), (C_, -5124, 0),
    (A, -5092, 0), (B, -5056, 0), (C_, -5020, -2), (A, -4988, 0), (C_, -4956, 0), (B, -4920, 3), (A, -4884, 0)]]
# ── 변환로 북쪽 줄: 북쪽 거리 집 뒤, 변환로 마당을 본다 ──
BUILD += [(k, x, -3975, 180 + t, "변환로마당", "", 1.0) for k, x, t in [
    (C_, -5296, 0), (A, -5264, 2), (C_, -5232, 0), (A, -5200, -2)]]
# ── 서북 거리(x -5140) 서쪽: 변환로 마당 옆 집 줄, 동(거리)을 본다. 난방관이 지나는 z -3922 는 비운다 ──
BUILD += [(k, -5156, z, -90 + t, "서북거리", "", 1.0) for k, z, t in [
    (A, -3998, 0), (C_, -3966, 2), (C_, -3890, 0), (A, -3868, -2)]]
# ── 공방 골목(z -3990): 북동 대로에서 동쪽 거리까지 ──
WK_Z = -3990.0
BUILD += [(k, x, -4010, 180 + t, "공방골목", "", 1.0) for k, x, t in [
    (C_, -4790, 0), (A, -4758, 2), (B, -4722, 0), (A, -4686, 0), (C_, -4654, -2)]]
BUILD += [(k, x, -3970, 0 + t, "공방골목", "", 1.0) for k, x, t in [
    (A, -4780, 0), (C_, -4748, -2), (B, -4712, 0), (A, -4676, 2), (C_, -4648, 0)]]
# ── 동쪽 거리(x -4610) 두 줄. 카지노 뒤는 비운다 ──
BUILD += [(k, -4626, z, -90 + t, "동쪽거리", "", 1.0) for k, z, t in [
    (C_, -4030, 0), (C_, -3962, 0), (A, -3932, -2), (C_, -3900, 0), (A, -3756, 0), (C_, -3722, 0)]]
BUILD += [(k, -4594, z, 90 + t, "동쪽거리", "", 1.0) for k, z, t in [
    (A, -4130, 0), (C_, -4098, -2), (B, -4062, 0), (A, -4026, 0), (C_, -3994, 2), (A, -3962, 0), (B, -3926, 0),
    (C_, -3890, -2), (A, -3858, 0), (C_, -3826, 0), (A, -3794, 2), (C_, -3762, 0)]]
# ── 동문길(z -3722) 북쪽 줄 ──
BUILD += [(k, x, -3742, 180 + t, "동문길", "", 1.0) for k, x, t in [(A, -4578, 0), (C_, -4546, 2), (A, -4514, 0)]]
# ── 남쪽 거리(z -3622): 전망대 동쪽에서 동으로. 계류탑·비행선 밑(x -4900..-4860)은 비운다 ──
BUILD += [(k, x, -3642, 180 + t, "남쪽거리", "", 1.0) for k, x, t in [
    (C_, -4876, 0), (A, -4844, 2), (B, -4808, 0), (C_, -4772, 0), (A, -4740, -2)]]
BUILD += [(k, x, -3600, 0 + t, "남쪽거리", "", 1.0) for k, x, t in [
    (A, -4838, 0), (C_, -4806, -2), (A, -4774, 0), (C_, -4742, 0)]]
BUILD += [(C_, -4978, -3612, -90, "남쪽거리", "", 1.0), (A, -5008, -3612, -90, "남쪽거리", "", 1.0),
          (C_, -5038, -3604, -90, "남쪽거리", "", 1.0)]
# ── 남서 거리(z -3672): 석탄 마당 남쪽, 천문대 서쪽 ──
BUILD += [(k, x, -3690, 180 + t, "남서거리", "", 1.0) for k, x, t in [
    (A, -5290, 0), (C_, -5258, 0), (B, -5222, 2), (A, -5186, 0)]]
BUILD += [(k, x, -3654, 0 + t, "남서거리", "", 1.0) for k, x, t in [
    (C_, -5290, 0), (A, -5258, -2), (C_, -5226, 0), (A, -5194, 0)]]
# ── 공장·변환로·공방 마당의 기계(보일러·톱니) ──
BUILD += [
    ("Boiler_Tank", -5214, -3950, 0, "공장", "", 1.0), ("Boiler_Tank", -5214, -3896, 180, "공장", "", 1.0),
    ("Vertical_Boiler", -5290, -3896, 0, "공장", "", 1.0), ("Vertical_Boiler", -5290, -3950, 0, "공장", "", 1.0),
    ("Boiler_Tank", -5292, -3762, 0, "석탄마당", "", 1.0), ("Vertical_Boiler", -5262, -3762, 0, "석탄마당", "", 1.0),
    ("Boiler_Tank", -5232, -3720, 90, "석탄마당", "", 1.0), ("Big_Gear", -5196, -3730, -90, "석탄마당", "", 1.0),
    ("Boiler_Tank", -4715, -4120, 0, "공방마당", "", 1.0), ("Vertical_Boiler", -4700, -4092, 0, "공방마당", "", 1.0),
    ("Boiler_Tank", -4672, -4120, 0, "공방마당", "", 1.0), ("Big_Gear", -4664, -4080, 180, "공방마당", "", 1.0),
    ("Vertical_Boiler", -4555, -3610, 0, "체스판", "", 1.0),
]
# ── 체스판 둘레: 남쪽 줄은 판을 보고, 남동 골목 끝 두 채 ──
BUILD += [(C_, -4640, -3606, 0, "체스판", "", 1.0), (A, -4608, -3606, 0, "체스판", "", 1.0), (C_, -4578, -3606, 0, "체스판", "", 1.0),
          (A, -4706, -3642, 180, "남쪽거리", "", 1.0), (C_, -4674, -3646, 180, "남쪽거리", "", 1.0)]
# ── 동쪽 고원 바깥: 차펜 공방이 불태운 옛 설 공방 폐허와 그을린 마당(1판 OUTSIDE 와 같은 자리, 땅 높이 43.8) ──
RUIN = (-3084.8, -3921.0)
BUILD += [
    ("Sel_Werk_Ruin", RUIN[0], RUIN[1], 200, "설공방", "sel", 1.3),
    ("Boiler_Tank", RUIN[0] + 28, RUIN[1] - 18, 20, "설공방", "", 1.0),
    ("Big_Gear", RUIN[0] - 30, RUIN[1] + 22, 35, "설공방", "", 1.0),
]


def ring_pts(r, a0, a1, step=10):
    pts, a = [], a0
    while a <= a1 + 1e-6:
        x, z, _ = polar(a, r)
        pts.append((x, z))
        a += step
    return pts


def along(th, r0, r1, side=0.0):
    """방사선 θ 위 r0 → r1, 옆으로 side(+ = θ 에서 시계 방향 쪽)"""
    ux, uz = u(th)
    nx, nz = -uz, ux
    return [(round(CX + ux * r + nx * side, 2), round(CZ + uz * r + nz * side, 2)) for r in (r0, r1)]


WS_X = -5140.0   # 서북 거리
ES_X = -4610.0   # 동쪽 거리
NE_END = 262.0   # 북동 대로 끝(공방 앞마당 안)
ROADS = [
    # (이름, 폭, 재질, 점들, 들어올림). 대로가 고리길 위를 덮도록 조금 높인다(같은 높이로 겹치면 깜빡인다)
    ("안고리길", 10, "pave", ring_pts(48, -180, 180), 0.0),
    ("가운데고리길", 10, "pave", ring_pts(94, -180, 180, 7.5), 0.0),
    ("바깥고리길", 10, "pave", ring_pts(140, -180, 180, 6), 0.0),
    ("동대로", 18, "pave", [(CX + 44, CZ), (-4688, CZ)], 0.05),
    ("서대로", 18, "pave", [(CX - 44, CZ), (-5203, CZ)], 0.05),
    ("북동대로", 18, "pave", along(TH_NE, 44, NE_END), 0.05),
    ("남대로", 18, "pave", [(CX, CZ + 44), (CX, -3606)], 0.05),
    ("남동골목", 9, "pave", [polar(TH_SE, 90)[:2], (-4652, -3660)], 0.03),
    ("남서골목", 9, "pave", along(TH_SW, 90, 236), 0.03),
    ("북골목", 9, "pave", [polar(TH_N, 90)[:2], (CX + (N1_Z + 6 - CZ) / math.tan(math.radians(TH_N)), N1_Z + 4)], 0.03),
    ("북쪽거리", 12, "pave", [(-5306, N1_Z), (-4842, N1_Z)], 0.04),
    ("뒷골목", 9, "pave", [(-5258, N2_Z), (-4858, N2_Z)], 0.04),
    ("서북거리", 10, "pave", [(WS_X, CZ - 6), (WS_X, N1_Z + 4)], 0.04),
    ("동쪽거리", 10, "pave", [(ES_X, -4146), (ES_X, -3690)], 0.04),
    ("동문길", 10, "pave", [(ES_X + 4, -3722), (-4495, -3722)], 0.05),
    ("남쪽거리", 10, "pave", [(CX + 22, -3622), (-4722, -3622)], 0.04),
    ("공방골목", 10, "pave", [(CX + (WK_Z - CZ) / math.tan(math.radians(TH_NE)), WK_Z), (ES_X - 4, WK_Z)], 0.04),
    ("남서거리", 10, "pave", [(-5306, -3672), (-5112, -3672)], 0.04),
]
PAVES = [
    # (이름, x0, z0, x1, z1, 재질) 또는 원판
    ("시계광장", CX, CZ, 42, "plaza", 0.0, "disc"),     # (이름, x, z, 반지름, 색, 들어올림, "disc")
    ("시계광장안", CX, CZ, 24, "road", 0.03, "disc"),
    ("공방앞마당", -4846, -4076, -4734, -4044, "stone"),
    ("공장앞마당", -5205, -3852, -5150, -3784, "stone"),
    ("남쪽전망대", CX - 30, -3626, CX + 22, -3590, "stone"),
    ("연병장", -4650, -3688, -4594, -3632, "chess"),
    ("석탄마당", -5306, -3778, -5180, -3706, "soot"),
    ("탄마당", RUIN[0] - 40, RUIN[1] - 38, RUIN[0] + 40, RUIN[1] + 38, "soot"),
]

# ── 난방관. 땅에서 7 높이, 쇠 받침 위. 변환로(서)에서 나와 서대로 북쪽 가를 따라 고리관으로 들고,
#    고리관(r 84)에서 동대로·북동 대로·북 골목·남 대로로 갈라진다 ──
PIPE_R = 84.0
OFF = 11.5   # 대로 가운데에서 관까지
OFF_L = 8.0  # 골목 가운데에서 관까지


def ring_join(th_line, off):
    """방사선 θ 에서 옆으로 off 떨어진 평행선이 고리관과 만나는 각"""
    return th_line + math.degrees(math.asin(off / PIPE_R))


TH_JW = ring_join(180.0, OFF)      # 서대로 북쪽 가(θ 180 에서 시계 방향 = 북)
TH_JE = ring_join(0.0, -OFF)       # 동대로 북쪽 가
TH_JNE = ring_join(TH_NE, OFF)     # 북동 대로 동쪽 가
TH_JN = ring_join(TH_N, OFF_L)     # 북 골목 동쪽 가
TH_JS = ring_join(90.0, -OFF)      # 남대로 동쪽 가


def pipe_ring(a0, a1, extra):
    """고리관 점들. a0 → a1(도, a0 < a1) 5 도 간격 + 모음통 자리 각을 그대로 끼운다"""
    angs = sorted(set([a0, a1] + [a for a in extra] + [a for a in range(int(math.ceil(a0 / 5)) * 5, int(a1) + 1, 5) if a0 + 1 < a < a1 - 1]))
    out = []
    for a in angs:
        x, z, _ = polar(a, PIPE_R)
        out.append((x, z))
    return out


N_Y = N1_Z - 9.0  # 북쪽 거리 북쪽 가(집 앞과 거리 사이)
_jn = polar(TH_JN, PIPE_R)[:2]
_nx, _nz = u(TH_N)
_t = (N_Y - _jn[1]) / _nz
PIPES = [
    ("고리관북", pipe_ring(-360 + TH_JW, TH_JE, [TH_JNE, TH_JN])),
    ("고리관남", pipe_ring(10, 170, [TH_JS])),
    ("서관", [(-5229, -3922), (-5182, -3922), (-5182, CZ - OFF), polar(TH_JW, PIPE_R)[:2]]),
    ("동관", [polar(TH_JE, PIPE_R)[:2], (-4704, CZ - OFF)]),
    ("북동관", [polar(TH_JNE, PIPE_R)[:2], along(TH_NE, 0, NE_END - 22, OFF)[1]]),
    ("북관", [_jn, (round(_jn[0] + _nx * _t, 2), N_Y), (-5296, N_Y)]),
    ("남관", [polar(TH_JS, PIPE_R)[:2], (CX + OFF, -3632)]),
]
JUNCTIONS = [
    (*polar(TH_JW, PIPE_R)[:2], ["고리관북", "서관"]),
    (*polar(TH_JE, PIPE_R)[:2], ["고리관북", "동관"]),
    (*polar(TH_JNE, PIPE_R)[:2], ["고리관북", "북동관"]),
    (*polar(TH_JN, PIPE_R)[:2], ["고리관북", "북관"]),
    (*polar(TH_JS, PIPE_R)[:2], ["고리관남", "남관"]),
]


# ── 가스등 (x, z, yaw). 팔(앞 -Z)이 길 위로 나온다. 관이 지나는 쪽 맞은편에만 ──
def lamp_along(th, rs, side, ):
    """방사 대로/골목 옆 가스등. side + = 시계 방향 쪽. 팔은 길 가운데를 본다"""
    ux, uz = u(th)
    nx, nz = -uz, ux
    s = 1 if side > 0 else -1
    yaw = math.degrees(math.atan2(s * nx, s * nz))  # 앞(-Z 를 yaw 로 돌린 쪽) = -s·n
    return [(round(CX + ux * r + nx * side, 1), round(CZ + uz * r + nz * side, 1), round(yaw, 1)) for r in rs]


LAMPS = []
for th in (-157.5, -112.5, -67.5, -22.5, 22.5, 67.5, 112.5, 157.5):
    x, z, yaw = polar(th, 37)
    LAMPS.append((x, z, yaw))
LAMPS += lamp_along(0, (70, 115, 165, 210), 11.5)          # 동대로 남쪽 가
LAMPS += lamp_along(180, (70, 150, 205, 252), -11.5)  # 서대로 남쪽 가
LAMPS += lamp_along(90, (70, 150, 205), 11.5)         # 남대로 서쪽 가
LAMPS += lamp_along(TH_NE, (70, 115, 165, 210), -11.5)     # 북동 대로 서쪽 가
LAMPS += lamp_along(TH_N, (115, 170), -7)                  # 북 골목 서쪽 가
LAMPS += lamp_along(TH_SW, (112, 160, 205), 7)             # 남서 골목
# 거리 등은 집과 집 사이 틈에 손으로(거리 쪽 집 앞이 등 자리와 같은 줄이면)
LAMPS += [(x, N1_Z + 10, 0) for x in (-5272, -5204, -5162, -5090, -5025, -4918, -4883)]     # 북쪽 거리 남쪽 가
LAMPS += [(x, N2_Z + 6.5, 0) for x in (-5233.5, -5154, -5108.3, -4984, -4935.5)]           # 뒷골목 남쪽 가
LAMPS += [(ES_X + 7, z, 90) for z in (-4113.5, -4040.2, -3978.5, -3903.6, -3841.5, -3777.5)]  # 동쪽 거리 동쪽 가
LAMPS += [(x, -3622 + 7, 0) for x in (-4900, -4860, -4822, -4790, -4758, -4726)]           # 남쪽 거리 남쪽 가
LAMPS += [(WS_X + 7, z, 90) for z in (-4010, -3950, -3890)]                                # 서북 거리 동쪽 가
LAMPS += [(x, -3722 - 7, 180) for x in (-4562, -4498)]                                     # 동문길 북쪽 가
LAMPS += [(x, WK_Z + 7, 0) for x in (-4796, -4730, -4662)]                                 # 공방 골목 남쪽 가

# 톱니 무늬 맨홀 — 대로·거리 위
MANHOLES = [(CX + 75, CZ + 2), (CX + 180, CZ - 2), (CX - 120, CZ + 2), (CX - 230, CZ - 1), (CX - 2, CZ + 140),
            (-5180, N1_Z), (-4980, N1_Z + 1), (ES_X, -3950), (CX + 60, -3622)] + [along(TH_NE, 0, 120)[1], along(TH_NE, 0, 205)[1]]
# 김구멍 쇠살판 — 길 위면 길 윗면에
VENTS = [(CX + 30, CZ + 30), (CX - 30, CZ - 30), (CX + 140, CZ + 5), (CX - 170, CZ - 4), (CX + 4, CZ + 175),
         (-5100, N1_Z), (-4955, N2_Z), (ES_X, -4080), (ES_X, -3830), (-5250, -3740), (-4705, -3622)]


def airship_pose():
    """계류탑 팔 끝에 비행선 코를 댄다. 탑 앞(-Z 에서 yaw 만큼 돈 쪽)으로 38, 높이 +25.4"""
    for k, x, z, yaw, g, tag, sc in BUILD:
        if k == "Mooring_Mast":
            r = math.radians(yaw)
            fx, fz = -math.sin(r), -math.cos(r)
            return (round(x + fx * 38.0, 2), round(z + fz * 38.0, 2), yaw + 180.0, 25.4)
    return None


# ------------------------------------------------------------------ 계산과 검사
def rect_world(kind, x, z, yaw, which=0, pad=0.0, sc=1.0):
    x0, x1, z0, z1 = (v * sc for v in KIT[kind][which])
    x0, x1, z0, z1 = x0 - pad, x1 + pad, z0 - pad, z1 + pad
    r = math.radians(yaw)
    c, s = math.cos(r), math.sin(r)
    return [(x + lx * c + lz * s, z - lx * s + lz * c) for lx, lz in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]


def overlap(p, q):
    for poly in (p, q):
        n = len(poly)
        for i in range(n):
            a, b = poly[i], poly[(i + 1) % n]
            ax, az = b[1] - a[1], -(b[0] - a[0])
            pa = [ax * v[0] + az * v[1] for v in p]
            qa = [ax * v[0] + az * v[1] for v in q]
            if max(pa) <= min(qa) or max(qa) <= min(pa):
                return False
    return True


def seg_dist(px, pz, a, b):
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - ax - t * dx, pz - az - t * dz)


GROUND = json.load(open(os.path.join(HERE, "snow_town_ground.json"), encoding="utf-8"))


def ground_at(x, z):
    g = GROUND
    i, j = round((x - g["x0"]) / g["st"]), round((z - g["z0"]) / g["st"])
    if 0 <= j < len(g["rows"]) and 0 <= i < len(g["rows"][j]):
        return g["rows"][j][i]
    return None


def all_items():
    items = list(BUILD)
    items += [("Gas_Lamp", x, z, y, "가스등", "", 1.0) for x, z, y in LAMPS]
    return items


def road_rects():
    out = []
    for name, w, mat, pts, lift in ROADS:
        for a, b in zip(pts, pts[1:]):
            out.append((name, seg_rect(a[0], a[1], b[0], b[1], w)))
    for p in PAVES:
        if p[-1] == "disc":
            continue
        name, x0, z0, x1, z1, kind = p
        out.append((name, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]))
    return out


ROAD_NAMES = set()
# 길 끝이 건물 문 앞에 닿도록 낸 것. 겹침 검사에서 뺀다
ROAD_ENDS = {("동대로", "Casino_Hall"), ("서대로", "Steam_Factory"), ("남서골목", "Observatory")}
_POLES = {}


def pole_of(n):
    return _POLES[n]


def check():
    ROAD_NAMES.update(r[0] for r in ROADS)
    msgs = []
    items = all_items()
    polys = []
    for k, x, z, y, g, t, sc in items:
        pad = 1.0 if k in SMALL else 2.0
        nm = f"{g}:{k}@({x},{z})"
        polys.append((nm, rect_world(k, x, z, y, 0, pad, sc), k, rect_world(k, x, z, y, 0, 0.0, sc)))
        _POLES[nm] = [(x - 0.9, z - 0.9), (x + 0.9, z - 0.9), (x + 0.9, z + 0.9), (x - 0.9, z + 0.9)]
    for i in range(len(polys)):
        for j in range(i + 1, len(polys)):
            if overlap(polys[i][1], polys[j][1]):
                msgs.append("건물겹침 " + polys[i][0] + " <> " + polys[j][0])
    rr = [r for r in road_rects() if r[0] in ROAD_NAMES]
    for n, p, k, raw in polys:
        if k in ("City_Gate", "Clock_Tower"):
            continue
        for rn, r in rr:
            if (rn, k) in ROAD_ENDS:
                continue
            if k == "Gas_Lamp":
                hit = overlap(pole_of(n), r)  # 팔은 길 위로 나와도 된다
            else:
                hit = overlap(p, r)
            if hit:
                msgs.append("길겹침 " + n + " <> " + rn)
    # 광장 원판
    for n, p, k, raw in polys:
        if k in ("Clock_Tower", "Gas_Lamp"):
            continue
        if any(math.hypot(px - CX, pz - CZ) < 42 + 1 for px, pz in p):
            msgs.append("광장겹침 " + n)
    # 땅: 바닥 네 귀·가운데가 59.8 평지여야(폐허는 격자 밖)
    for (k, x, z, y, g, t, sc), (n, p, _, raw) in zip(items, polys):
        hs = [ground_at(px, pz) for px, pz in raw + [(x, z)]]
        hs = [h for h in hs if h is not None]
        if g == "설공방":
            continue
        if len(hs) < 5 or max(hs) > 60.3 or min(hs) < 59.4:
            msgs.append("땅 %s (%s)" % (n, ", ".join("%.1f" % h for h in hs)))
    # 길 밑 땅: 가운데·두 가장자리를 5 마다 — 평지(59.8) 위여야 길 판이 뜨지 않는다
    for name, w, mat, pts, lift in ROADS:
        bad = 0
        for p0, p1 in zip(pts, pts[1:]):
            L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
            ux_, uz_ = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
            for k in range(int(L // 5) + 1):
                for sd in (-w / 2 + 0.5, 0, w / 2 - 0.5):
                    h = ground_at(p0[0] + ux_ * k * 5 - uz_ * sd, p0[1] + uz_ * k * 5 + ux_ * sd)
                    if h is None or abs(h - 59.8) > 0.4:
                        bad += 1
        if bad:
            msgs.append("길 %s 밑 땅이 평지가 아닌 점 %d" % (name, bad))
    # 관: 모음통 자리, 관 밑 건물
    pipes = dict(PIPES)
    for jx, jz, names in JUNCTIONS:
        for nm in names:
            d = min(seg_dist(jx, jz, a, b) for a, b in zip(pipes[nm], pipes[nm][1:]))
            if d > 0.3:
                msgs.append("모음통 (%.1f,%.1f) 이 %s 에서 %.2f 떨어짐" % (jx, jz, nm, d))
    for nm, pts in PIPES:
        for a, b in zip(pts, pts[1:]):
            pr = seg_rect(a[0], a[1], b[0], b[1], 3.0)
            for n, p, k, raw in polys:
                if overlap(pr, raw) and k not in ("Herzofen",):
                    msgs.append("관 %s 이 %s 를 지남" % (nm, n))
        for q in pts:
            h = ground_at(*q)
            if h is None or abs(h - 59.8) > 0.4:
                msgs.append("관 %s 점 (%.0f,%.0f) 땅 %s" % (nm, q[0], q[1], h))
    for vx, vz in VENTS:
        vr = [(vx - 2.6, vz - 2.6), (vx + 2.6, vz - 2.6), (vx + 2.6, vz + 2.6), (vx - 2.6, vz + 2.6)]
        for n, p, k, raw in polys:
            if overlap(vr, raw):
                msgs.append("김구멍 (%.0f,%.0f) 이 %s 에 걸림" % (vx, vz, n))
    for mx, mz in MANHOLES:
        if not any(overlap([(mx - 2, mz - 2), (mx + 2, mz - 2), (mx + 2, mz + 2), (mx - 2, mz + 2)], r) for rn, r in rr if rn in [x[0] for x in ROADS]):
            msgs.append("맨홀 (%.0f,%.0f) 이 길 위가 아님" % (mx, mz))
    ap = airship_pose()
    ship = rect_world("Airship", ap[0], ap[1], ap[2], 1, 2.0)
    for n, p, k, raw in polys:
        if k != "Mooring_Mast" and overlap(ship, p):
            msgs.append("비행선이 " + n + " 에 걸림")
    for px, pz in ship:
        h = ground_at(px, pz)
        if h is not None and h > 62:
            msgs.append("비행선 밑 높은 땅 %.1f" % h)
    return msgs


# ------------------------------------------------------------------ 그림
def render(path, region, sc):
    Cv = Canvas(*region, sc)
    g = GROUND
    st = g["st"]
    for j, row in enumerate(g["rows"]):
        z = g["z0"] + j * st
        for i, h in enumerate(row):
            x = g["x0"] + i * st
            col = "#33506c" if h < -900 else ("#e8eef4" if abs(h - 59.8) < 0.4 else ("#7c848c" if h > 59.8 else "#aab4bc"))
            Cv.rect(x - st / 2, z - st / 2, x + st / 2, z + st / 2, col)
    for gx in range(-5350, -4440, 50):
        Cv.line(gx, region[1], gx, region[3], (1.0 if gx % 100 == 0 else 0.5) / sc, "#c8d0d8")
    for gz in range(-4200, -3490, 50):
        Cv.line(region[0], gz, region[2], gz, (1.0 if gz % 100 == 0 else 0.5) / sc, "#c8d0d8")
    for pv in PAVES:
        if pv[-1] == "disc":
            Cv.circle(pv[1], pv[2], pv[3], "#8a847c")
            continue
        name, x0, z0, x1, z1, kind = pv
        if kind == "chess":
            for i, x in enumerate(range(int(x0), int(x1), 7)):
                for j, z in enumerate(range(int(z0), int(z1), 7)):
                    Cv.rect(x, z, x + 7, z + 7, "#e8e8ec" if (i + j) % 2 else "#2c2c30")
        else:
            Cv.rect(x0, z0, x1, z1, {"stone": "#8a847c", "soot": "#3a3838"}[kind])
    for name, w, mat, pts, lift in ROADS:
        for a, b in zip(pts, pts[1:]):
            Cv.line(a[0], a[1], b[0], b[1], w, "#9a9288")
        for p in pts[1:-1]:
            Cv.circle(p[0], p[1], w / 2, "#9a9288")
    for k, x, z, y, gname, t, sc_ in all_items():
        allp = rect_world(k, x, z, y, 1, 0, sc_)
        base = rect_world(k, x, z, y, 0, 0, sc_)
        col = {"Herzofen": "#c05a3a", "Zapfen_Werk": "#7a4034", "Figuren_HQ": "#55565c", "Frostig_Werk": "#8a4a34",
               "Sel_Werk_Ruin": "#2b2a2c", "Gas_Lamp": "#f0a050", "Big_Gear": "#b8913f", "Boiler_Tank": "#b06a3f",
               "Vertical_Boiler": "#b06a3f", "City_Gate": "#8c8b8a", "Mooring_Mast": "#3a3c42", "Clock_Tower": "#806020",
               "Casino_Hall": "#a03050", "Steam_Factory": "#606060", "Observatory": "#304880", "Inn_House": "#8040c0",
               "Ticket_Booth": "#c03030", "Under_Gate": "#202020", SR: "#c04040", ST: "#30a0a0", SB: "#3070c0"}.get(k, "#4a4e58")
        Cv.poly(allp, col, 0.92)
        Cv.outline(base, 0.6 / sc, "#f0e8d0")
        r = math.radians(y)
        fz = KIT[k][0][2] * sc_
        Cv.circle(x + fz * math.sin(r), z + fz * math.cos(r), 1.6, "#ffcc33")
        if t in DOORS:
            _, dx, dz, dw = DOORS[t]
            c, s = math.cos(r), math.sin(r)
            Cv.circle(x + (dx * c + dz * s) * sc_, z + (-dx * s + dz * c) * sc_, 2.6, "#40e0ff")
    for name, pts in PIPES:
        for a, b in zip(pts, pts[1:]):
            Cv.line(a[0], a[1], b[0], b[1], 2.6, "#c07a48")
    for jx, jz, _ in JUNCTIONS:
        Cv.circle(jx, jz, 2.4, "#e0a060")
    for x, z in VENTS:
        Cv.circle(x, z, 2.2, "#ffffff")
    for x, z in MANHOLES:
        Cv.circle(x, z, 2.0, "#202020")
    ap = airship_pose()
    Cv.poly(rect_world("Airship", ap[0], ap[1], ap[2], 1), "#cbbe9e", 0.6)
    Cv.save(path)


# ------------------------------------------------------------------ Luau 로 옮겨 적기
def lua(v):
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, dict):
        return "{" + ", ".join("%s = %s" % (k, lua(x)) for k, x in v.items()) + "}"
    return "{" + ", ".join(lua(x) for x in v) + "}"


def emit(path):
    tables = [("BUILD", BUILD), ("LAMPS", LAMPS), ("ROADS", ROADS), ("PAVES", PAVES), ("PIPES", PIPES),
              ("VENTS", VENTS), ("MANHOLES", MANHOLES), ("JUNCTIONS", JUNCTIONS)]
    lines = ["-- snow_plan2.py 가 적은 표. 손으로 고치지 말고 snow_plan2.py 를 고쳐 다시 뽑는다", "local D = {}"]
    for name, rows in tables:
        lines.append("D.%s = {" % name)
        for r in rows:
            lines.append("\t" + lua(r) + ",")
        lines.append("}")
    lines.append("D.DOORS = {")
    for k, (iid, dx, dz, dw) in DOORS.items():
        lines.append("\t%s = %s," % (k, lua([iid, dx, dz, dw])))
    lines.append("}")
    lines.append("D.AIRSHIP = %s" % lua(list(airship_pose())))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "snow_plan2.png")
    render(out, (-5360, -4200, -4440, -3480), 1.2)
    emit(os.path.join(HERE, "Snow_City2_data.luau"))
    msgs = check()
    nh = sum(1 for b in BUILD if b[0].startswith("Steam_House"))
    print("건물 %d (집 %d), 가스등 %d, 길 %d, 관 %d" % (len(BUILD), nh, len(LAMPS), len(ROADS), len(PIPES)))
    for m in msgs:
        print(m)
    print("검사 %d 건" % len(msgs))
