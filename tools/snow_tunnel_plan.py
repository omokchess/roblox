# -*- coding: utf-8 -*-
"""
snow_tunnel_plan.py — 2026-10-31. 설원 동굴 입구 셋을 비스듬한 굴(지하 터널)로 → tools/Snow_Tunnels_data.luau
사용자: "동굴이 지하에 있는 건 의도한 사항이 맞는데, 들어갈 땐 비스듬하게, 지하 터널 들어가는 것처럼".

예전: 땅에 뚫린 네모 구멍(snow3_ground.HOLES) + 구멍 벽을 도는 디딤 블록(Snow3_Under 의 ShaftWall · Ledge).
이제: 굴마다 북쪽 바위 언덕에 판 갱도 입구 → 1:2 로 내려가는 굴(바닥은 높이 1 · 깊이 2 블록 계단, 벽·천장은 같이 기울어짐,
      12 스터드마다 갱목 틀, 세 틀마다 등잔 — 진짜 불) → 바닥 -70 평지 → 그 굴 방의 북쪽 벽을 뚫고 들어간다.
      예전 구멍은 땅으로 메우고(땅 규칙: 바위 + 눈 윗판), 굴 방 천장도 막는다.
  - 땅 속을 지나는 굴 위는 도랑을 파서(Land 상자 빼기) 굴을 넣고 그 위를 다시 땅으로 덮는다(땅 밑 -24 아래로 들어가면 덮을 필요 없음)
  - 입구 바위 언덕(손 표 PORTAL_ROCKS — 굴 몸 쪽 좌표): 굴 지붕이 땅 위로 나오는 첫 38 스터드를 덮는다. 굴 안을 침범하지 않게 확인
  - 3번 입구: 입구에 잠긴 쇠창살(속성 QuestLocked — 예전 구멍 위 창살 대신)
  - 2026-10-31 2판(사용자: "레일 깔아서 그 레일 타서 들어가게" · "앞면이 밋밋, 입구마다 다르게" · "레퍼런스 여러 개"):
    레일 = 입구 밖 짧은 선로(멈춤 막이) → 계단 위 기울어진 레일(계단마다 침목) → 바닥 평지 → 굴 방 안 멈춤 막이. 레일·침목은 부딪힘 없음(걷는 길 그대로).
    광차 = 위·아래에 한 대씩(태그 MineCart — 속성 P1..Pn 탈 길, Locked). 타기는 src/server/MineCartService · src/client/MineCartClient.
    입구 모양(레퍼런스): 동굴 입구 2 = 낡은 나무 갱구(알래스카 Kennecott·콜로라도 광산 갱구 — 갱목 문틀·차양 지붕·널빤지 벽·폐석 더미·광석 통),
    동굴 입구 1 = 돌 아치 문(유럽 석조 철도·광산 터널 입구 — 계단 아치·쐐기돌·연도석·붙임기둥·처마 돌림띠·날개벽),
    3번 입구 = 슈네라이히 쇠 문(스팀펑크 공장 문 — 리벳 쇠틀·경고 줄무늬·톱니 문장·증기 관·조작실·빨간 경고등). 셋 다 바위 앞면을 튀어나온 덩어리·처마 바위·고드름으로 깬다.
  - 순간이동 명소(TeleportSpot): 입구마다 앞 14 스터드
굴 셋은 다 북 → 남으로 내려간다(입 = 굴 방 북쪽 벽). 지하 방은 snow3_under(그림 좌표 + UNDER_SHIFT).
돌리기: python tools/snow_tunnel_plan.py (문제 0건) → 짓기: tools/Snow_Tunnels.luau (Snow3_Build · Snow3_Under · Snow_City2 뒤 — 다시 지으면 이것도 다시)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import SCALE, world  # noqa: E402
import snow3_ground as SG  # noqa: E402
import snow3_under as U  # noqa: E402

G = SG.grid()[0]
W, T, HV = 14.0, 3.0, 16.0          # 굴 안 폭 · 벽 두께 · 안 높이(세로, 계단 선 위)
TH = math.atan(0.5)                 # 1 내려가고 2 나아감
CO, SI = math.cos(TH), math.sin(TH)
HC = HV * CO                        # 천장 밑까지(굴 몸에 수직)
LAND_BOTTOM = -24
FLOOR = -70
LANDING = 24                        # 바닥 -70 평지 길이(벽 두께 18.5 포함)
WALL_CELL = U.CELL * SCALE          # 지하 벽 한 칸 = 18.5

# 손 표: 이름, 굴 가운데 그림 X, 들어갈 굴 방, 메울 옛 구멍, 잠김
TUNNELS = [
    ("동굴 입구 2", 293, "입구2 방", "동굴 입구 2", False),
    ("동굴 입구 1", 700, "동굴입구1 굴", "동굴 입구 1", False),
    ("3번 입구", 841, "입구1 굴", "3번 입구", True),
]
# 입구 바위 언덕(굴 몸 좌표: lx 옆(+ 동), lz 굴 안쪽으로(+ 남), ly 땅 위) { lx0, lx1, lz0, lz1, ly0, ly1, 돌림, 색 1/2 }
# 굴 안(|lx| < 7, ly < 16 - lz/2)을 침범하면 안 된다 — 덮개는 앞 끝의 굴 천장 높이에서 시작해 계단처럼 내려간다.
BODY = [
    (-12, 12, -1.3, 10, 16.5, 29.0, 0, 1),   # 덮개 1(입구 위)
    (-12.5, 11.5, 10, 20, 11.2, 25.4, 0, 2),  # 덮개 2
    (-11.5, 12.5, 20, 30, 6.1, 20.6, 0, 1),   # 덮개 3
    (-12, 12, 30, 40, 1.2, 13.8, 0, 2),       # 덮개 4
    (-13, 11, 40, 49, -0.2, 6.6, 0, 1),       # 뒤 꼬리
    (-26, -9, -2, 22, -0.2, 27.6, 0, 2),      # 왼 어깨
    (-24, -9, 22, 40, -0.2, 17.8, 0, 1),      # 왼 뒤
    (9, 25, -1, 20, -0.2, 24.8, 0, 1),        # 오른 어깨
    (9, 23, 20, 38, -0.2, 15.6, 0, 2),        # 오른 뒤
]
# 입구마다 앞면 { 종류, lx0, lx1, lz0, lz1, ly0, ly1, 돌림 y, 기울기 z } — 바위(Rock·Rock2·Spoil)는 눈 윗판이 저절로 붙는다
# 레일 자리(|lx| < 3.6, lz -15 ~ 0, ly < 8)와 굴 안(|lx| < 7, ly < 16 - lz/2)은 비운다(plan 이 검사)
PORTALS = {
    "동굴 입구 2": {   # 낡은 나무 갱구(남서 필드)
        "frame": "timber",
        "front": [
            ("Rock2", -19, -10, -6, 4, -0.2, 22.6, 4, 0), ("Rock", -27, -17, -10, -3, -0.2, 5.4, -10, 0),
            ("Rock2", -23, -19.5, -14, -10.5, -0.2, 2.4, 25, 0), ("Rock", 10, 18, -4.5, 6, -0.2, 19.4, -6, 0),
            ("Rock", -13, 13, -7.2, 2, 18.6, 22.8, 0, 0),                    # 처마 바위(차양 위로 튀어나옴)
            ("Rock2", -9, 6, -9.6, -6, 21.2, 23.6, 8, 0), ("Rock", -30, -25, 6, 16, -0.2, 9.6, 12, 0),
            ("Spoil", 14, 26, -18, -8, -0.2, 3.2, 6, 0), ("Spoil", 16, 24, -16.5, -10, 3.0, 5.3, -4, 0),
            ("Spoil2", 18, 22, -14.5, -11.5, 5.1, 6.5, 15, 0),
            ("Post", 8.0, 9.2, -8.1, -6.9, -0.2, 14.2, 0, 0), ("Post", -9.2, -8.0, -8.1, -6.9, -0.2, 14.2, 0, 0),
            ("Post", -9.4, 9.4, -8.2, -6.8, 14.2, 15.4, 0, 0),             # 차양 앞 들보
            ("Post", -0.4, 0.4, -9.4, 1.6, 18.9, 19.7, 0, 0),              # 용마루
            ("Plank", -10.6, 0.2, -9.6, 1.6, 16.7, 17.2, 0, 20), ("Plank", -0.2, 10.6, -9.6, 1.6, 16.7, 17.2, 0, -20),
            ("Snow", -10.7, 0.3, -9.8, 1.6, 17.25, 17.75, 0, 20), ("Snow", -0.3, 10.7, -9.8, 1.6, 17.25, 17.75, 0, -20),
            ("Post", -8.2, -6.4, -7.8, -7.2, 11.6, 12.4, 0, -45), ("Post", 6.4, 8.2, -7.8, -7.2, 11.6, 12.4, 0, 45),   # 버팀대
            ("Plank", -7.0, 7.0, -1.0, -0.5, 16.6, 19.0, 0, 0),             # 박공 널빤지 벽
            ("Plank", -12.6, -9.4, -1.2, -0.6, -0.2, 14.0, 0, 0), ("Plank", 9.4, 12.6, -1.2, -0.6, -0.2, 14.0, 0, 0),
            ("Barrel", 10.4, 13.0, -10.2, -7.6, -0.2, 2.4, 0, 90), ("Crate", 11.3, 13.7, -13.7, -11.3, -0.2, 2.2, 0, 0),
            ("Crate", 9.7, 11.5, -14.2, -12.4, -0.2, 1.6, 20, 0), ("Crate", 11.6, 13.2, -13.4, -11.8, 2.2, 3.6, -15, 0),
            ("Post", -10.9, -10.5, -10.6, -10.2, -0.2, 4.4, 0, 18), ("Iron", -11.8, -9.8, -10.6, -10.2, 4.0, 4.4, 0, 18),   # 기댄 곡괭이
            ("Drift", -18, -9, -10, -6, -0.2, 1.4, 0, 0), ("Drift", 9, 15, -9, -5, -0.2, 1.1, 0, 0),
        ],
        "ice": [(-11, -7.0, 18.6, 2.8), (-8.2, -7.0, 18.6, 1.6), (-5.6, -7.0, 18.6, 3.4), (-2.4, -7.1, 18.6, 2.0),
                (1.2, -7.0, 18.6, 3.0), (4.6, -7.1, 18.6, 1.4), (7.8, -7.0, 18.6, 2.6), (10.8, -7.0, 18.6, 1.8)],
        "lamps": [(0, -7.6, 15.9, "warm"), (-10.7, -10.4, 6.6, "warm")],
        "signs": [(-14.5, -11.5, 5.2, 4.2, 1.8, "갱도 Ⅱ")],
        "steam": [],
    },
    "동굴 입구 1": {   # 돌 아치 문(북동 들)
        "frame": "stone",
        "front": [
            ("Stone", -13, -7, -2.4, 0.2, -0.2, 18.2, 0, 0), ("Stone", 7, 13, -2.4, 0.2, -0.2, 18.2, 0, 0),         # 아치 다리
            ("Stone2", -7, -4.4, -2.4, -0.6, 11.0, 14.8, 0, 0), ("Stone2", -4.4, -1.5, -2.4, -0.6, 13.6, 17.2, 0, 0),
            ("Stone3", -1.5, 1.5, -2.9, -0.6, 14.6, 18.6, 0, 0),                                                   # 쐐기돌(튀어나옴)
            ("Stone2", 1.5, 4.4, -2.4, -0.6, 13.6, 17.2, 0, 0), ("Stone2", 4.4, 7, -2.4, -0.6, 11.0, 14.8, 0, 0),
            ("Stone", -13, -1.5, -2.4, -0.6, 17.2, 22.2, 0, 0), ("Stone", 1.5, 13, -2.4, -0.6, 17.2, 22.2, 0, 0),
            ("Stone", -1.5, 1.5, -2.4, -0.6, 18.6, 22.2, 0, 0),
            ("Stone3", -3.6, 3.6, -2.75, -2.4, 19.0, 21.6, 0, 0),                                                  # 연도석
            ("Stone2", -12.8, -10.4, -3.4, -2.4, -0.2, 22.2, 0, 0), ("Stone2", 10.4, 12.8, -3.4, -2.4, -0.2, 22.2, 0, 0),   # 붙임기둥
            ("Stone3", -14.6, 14.6, -3.8, 0.8, 22.2, 23.6, 0, 0),                                                  # 처마 돌림띠
            ("Stone", -24, -13, -1.8, 0.6, -0.2, 14.2, 18, 0), ("Stone", -31, -23.5, -0.4, 1.8, -0.2, 8.4, 30, 0),     # 날개벽
            ("Stone", 13, 24, -1.8, 0.6, -0.2, 13.6, -18, 0), ("Stone", 23.5, 31, -0.4, 1.8, -0.2, 7.8, -30, 0),
            ("Stone3", -24.4, -12.6, -2.1, 0.9, 14.2, 15.0, 18, 0), ("Stone3", 12.6, 24.4, -2.1, 0.9, 13.6, 14.4, -18, 0),
            ("Rock", -18, 18, 6, 24, 27.0, 38.6, 3, 0), ("Rock2", -10, 12, 10, 22, 38.4, 44.2, -6, 0),             # 뒤로 솟은 벼랑
            ("Rock2", -30, -18, 4, 20, -0.2, 24.0, 8, 0), ("Rock", 18, 30, 4, 18, -0.2, 21.4, -5, 0),
            ("Drift", -26, -14, -5, -1.4, -0.2, 1.8, 18, 0), ("Drift", 14, 26, -5, -1.4, -0.2, 1.4, -18, 0),
            ("Iron", -12.0, -11.2, -4.6, -3.4, 12.6, 13.2, 0, 0), ("Iron", 11.2, 12.0, -4.6, -3.4, 12.6, 13.2, 0, 0),   # 등 팔
        ],
        "ice": [(-12, -3.6, 22.2, 2.2), (-9, -3.7, 22.2, 1.2), (-6.4, -3.6, 22.2, 2.8), (-3.0, -3.6, 22.2, 1.6),
                (2.8, -3.7, 22.2, 2.4), (6.0, -3.6, 22.2, 1.0), (9.4, -3.6, 22.2, 3.0), (12.2, -3.6, 22.2, 1.4)],
        "lamps": [(-11.6, -4.9, 11.9, "warm"), (11.6, -4.9, 11.9, "warm")],
        "signs": [(0, -2.8, 20.3, 6.6, 2.2, "제1 갱도")],
        "steam": [],
    },
    "3번 입구": {   # 슈네라이히 쇠 문(잠김)
        "frame": "iron",
        "front": [
            ("Iron", -9.4, -7.0, -2.6, 0.2, -0.2, 17.6, 0, 0), ("Iron", 7.0, 9.4, -2.6, 0.2, -0.2, 17.6, 0, 0),
            ("Iron", -9.4, 9.4, -2.6, 0.2, 15.4, 18.6, 0, 0),
            ("Iron2", -11.6, -9.4, -1.8, 0.4, -0.2, 19.8, 0, 0), ("Iron2", 9.4, 11.6, -1.8, 0.4, -0.2, 19.8, 0, 0),
            ("Iron2", -11.6, 11.6, -1.8, 0.4, 18.6, 20.2, 0, 0),
            ("Rock", -20, -11.6, -4, 4, -0.2, 21.4, 0, 0), ("Rock2", 11.6, 21, -3, 5, -0.2, 23.8, 0, 0),
            ("Rock2", -14, 14, -2.6, 3, 20.2, 27.4, 0, 0), ("Rock", -6, 9, -4.8, -1.4, 27.2, 30.4, -7, 0),
            ("Iron", -19.2, -13.0, -4.4, -4.0, 6.0, 13.0, 0, 0), ("Iron", 13.2, 19.8, -3.4, -3.0, 9.0, 17.0, 0, 0),   # 바위에 박은 쇠판
            ("Pipe", 11.6, 24, -2.2, 0.2, 11.0, 13.4, 0, 0), ("Pipe", 15.6, 18.0, -3.6, -1.2, -0.2, 12.0, 0, 90),     # 증기 관(가로·세로)
            ("Flange", 13.0, 13.6, -2.6, 0.6, 10.6, 13.8, 0, 0), ("Flange", 15.4, 18.2, -3.9, -0.9, 5.6, 6.2, 0, 90),
            ("Brass", 17.2, 18.8, -4.1, -3.7, 7.4, 9.0, 0, 0),                                                     # 압력계
            ("Iron", -17.5, -11.0, -12.5, -6.5, -0.2, 8.2, 0, 0), ("Iron2", -18.1, -10.4, -13.1, -5.9, 8.2, 8.8, 0, 0),   # 조작실
            ("Glass", -16.0, -12.6, -12.62, -12.5, 3.6, 6.4, 0, 0), ("Char", -12.62, -12.5, -11.8, -9.4, -0.2, 6.0, 0, 0),
            ("Iron", -9.9, -9.1, -8.9, -8.1, -0.2, 2.6, 0, 0), ("Brass", -9.7, -9.3, -8.7, -8.3, 2.6, 5.0, 0, 20),   # 손잡이 막대
            ("Drift", -22, -12, -8, -4, -0.2, 1.6, 0, 0), ("Drift", 12, 22, -8, -4, -0.2, 1.2, 0, 0),
        ],
        "hazard": (-9.4, 9.4, -2.75, 15.6, 18.4),   # 윗보 앞 경고 줄무늬(lx0, lx1, lz, ly0, ly1)
        "gear": (0, -2.2, 23.6, 3.4),              # 톱니 문장(lx, lz, ly, 반지름)
        "ice": [(-8.4, -2.8, 15.4, 1.8), (-5.0, -2.8, 15.4, 1.0), (-1.4, -2.8, 15.4, 2.2), (2.2, -2.8, 15.4, 1.2),
                (5.6, -2.8, 15.4, 2.0), (8.6, -2.8, 15.4, 1.4)],
        "lamps": [(0, -3.4, 20.8, "red"), (-14.2, -13.0, 7.2, "warm")],
        "signs": [(13.5, -9.0, 4.6, 5.0, 2.0, "위험 · 출입 금지")],
        "steam": [(17.0, -3.8, 12.6), (24.0, -1.0, 12.2)],
    },
}

parts = []    # (종류, cx, cy, cz, sx, sy, sz, rx 도, ry 도)
carve_land = []   # (x0, x1, y0, y1, z0, z1)
carve_under = []
air = []
lamps = []    # (x, y, z, rx, 빛 종류 warm/red)
spots = []    # (이름, x, y, z, 보는 x, 보는 z)
caps = []     # 옛 구멍 메움 (이름, x0, x1, z0, z1, 땅 높이)
gates = []    # 쇠창살 (이름, [parts])
signs = []    # 간판 (x, y, z, 폭, 높이, 글)
steam = []    # 김 (x, y, z)
carts = []    # 광차 (이름, [(x, y, z) 길 점], 잠김, 글)
bad = []


CYL = {"Barrel", "Pipe", "Flange", "GearDisc", "GearHub"}   # 원기둥(축 = 몸 X) — 세운 것(rz ±90)은 길이를 X 로 옮긴다


def P(kind, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0, rz=0.0):
    if kind in CYL and abs(abs(rz) - 90) < 1e-6:
        sx, sy = sy, sx
    parts.append((kind, cx, cy, cz, sx, sy, sz, rx, ry, rz))


def room(name):
    for r in U.rects_all():
        if r[0] == name or r[0].startswith(name + "("):
            return r
    raise KeyError(name)


def land_block(x0, x1, z0, z1, y0, top):
    """땅 규칙: 바위(y0 ~ top-2) + 눈 윗판(top-2.2 ~ top-0.2, 0.1 넓게)."""
    if top - 2 - y0 > 0.3:
        P("Backfill", (x0 + x1) / 2, (y0 + top - 2) / 2, (z0 + z1) / 2, x1 - x0, top - 2 - y0, z1 - z0)
    P("Snow", (x0 + x1) / 2, top - 1.2, (z0 + z1) / 2, x1 - x0 + 0.1, 2, z1 - z0 + 0.1)


for name, X, roomName, hole, locked in TUNNELS:
    r = room(roomName)
    y0 = r[2]
    edge = 5 * math.ceil((y0 - 2.5) / 5)        # 굴 방 맨 북쪽 칸의 북쪽 변(그림)
    xc, zend = world(X, edge)
    hx = SG.HOLES[hole]
    top = SG.zone_at((hx[0] + hx[1]) / 2, (hx[2] + hx[3]) / 2, G)
    S = top - 0.2                                 # 걷는 땅 높이
    R = 2 * (S - FLOOR)
    zl = zend - LANDING
    zp = zl - R
    zwall = zend - WALL_CELL                      # 벽 북쪽 면

    def floor_at(z):
        return S - (z - zp) / 2 if z < zl else FLOOR

    # 길 위 땅 높이가 한결같은지(도랑·입구 언덕 자리)
    for z in [zp - 30 + k * 4 for k in range(int((zl - zp + 30) // 4))]:
        for dx in (-12, 0, 12):
            Xp, Yp = (xc + dx - (world(0, 0)[0])) / SCALE, (z - world(0, 0)[1]) / SCALE
            t = SG.zone_at(Xp, Yp, G)
            if t != top and floor_at(z) + HV + 3.4 > LAND_BOTTOM:
                bad.append(f"{name}: z {z:.0f} 땅 {t} (입구 {top})")
                break
    # 굴 밑 끝 벽이 정말 벽인지(지하 자료)
    uparts = U.build()[0]
    if not any(k == "Wall" and a <= xc <= b and c <= zwall + 9 <= d for k, a, b, c, d, *_ in uparts):
        bad.append(f"{name}: 굴 방 북쪽 벽을 못 찾음 (x {xc:.0f}, z {zwall + 9:.0f})")
    # 바위 무리·오르막과 겹침
    for _, (a, b, c, d), lo, tp, _c in SG.main()[4]:
        if a < xc + 30 and b > xc - 30 and c < zp + 50 and d > zp - 10:
            bad.append(f"{name}: 입구가 단 사이 바위 무리와 겹침")

    # ── 기울어진 몸 ──
    L = R / CO
    mz, my = (zp + zl) / 2, (S + FLOOR) / 2
    deg = math.degrees(TH)

    def slope(h, lz=0.0):
        """기울어진 몸 좌표(옆 0, 몸에 수직 h, 몸 따라 lz — 가운데 기준) → (y, z)."""
        return my + h * CO - lz * SI, mz + h * SI + lz * CO

    y, z = slope(HC + 1.5)
    P("Ceil", xc, y, z, W + 2 * T - 0.2, 3, L + 4, deg)   # 벽 바깥면과 한 평면이 되지 않게 0.2 좁게(벽이 덮는다)
    y, z = slope((HC - 1) / 2)
    for s in (-1, 1):
        P("Wall", xc + s * (W / 2 + T / 2), y, z, T, HC + 7, L + 4, deg)
    y, z = slope(-3.05)
    P("Under", xc, y, z, W, 2.9, L, deg)
    n = int(round(S - FLOOR))
    step = R / n
    for k in range(n):
        tz0, tz1 = zp + k * step, zp + (k + 1) * step
        tt = S - (k + 1) * step / 2
        P("Step" if k % 2 == 0 else "Step2", xc, tt - 1, (tz0 + tz1) / 2, W, 2, tz1 - tz0)
    # 갱목 틀: 12 마다(몸 따라), 세 틀마다 등잔
    k = 0
    for lz in [-L / 2 + 6 + 12 * i for i in range(int((L - 10) // 12))]:
        for s in (-1, 1):
            y, z = slope(HC / 2, lz)
            P("Timber", xc + s * (W / 2 - 0.6), y, z, 1.2, HC, 1.2, deg)
        y, z = slope(HC - 0.7, lz)
        P("Timber", xc, y, z, W, 1.2, 1.4, deg)
        if k % 3 == 1:
            y, z = slope(9.5, lz + 1.4)
            lamps.append((xc - W / 2 + 1.3, y, z, deg, "warm"))
        k += 1
    # ── 바닥 -70 평지(벽 북쪽 면까지 — 벽 안은 판 벽이 굴 몸) ──
    a, b = zl - 2, zwall
    P("Floor", xc, FLOOR - 1.5, (a + b) / 2, W, 3, b - a)
    P("Ceil", xc, FLOOR + HV + 1.5, (a + b) / 2, W + 2 * T - 0.2, 3, b - a)
    for s in (-1, 1):
        P("Wall", xc + s * (W / 2 + T / 2), FLOOR + HV / 2, (a + b) / 2, T, HV + 6, b - a)
    for zz in (zl + 4, zwall - 1):
        for s in (-1, 1):
            P("Timber", xc + s * (W / 2 - 0.6), FLOOR + (HV - 0.7) / 2, zz, 1.2, HV - 0.7, 1.2)
        P("Timber", xc, FLOOR + HV - 0.7, zz, W, 1.2, 1.4)
    lamps.append((xc - W / 2 + 1.3, FLOOR + 9.5, zl + 5.4, 0.0, "warm"))
    carve_under.append((xc - W / 2, xc + W / 2, FLOOR, FLOOR + HV, zwall - 0.5, zend + 0.5))
    # ── 도랑(땅 빼기)과 다시 덮기 ──
    send = 2 * (S + 19.4 - LAND_BOTTOM)          # 천장 윗면이 땅 밑(-24)보다 위인 동안
    carve_land.append((xc - 10, xc + 10, LAND_BOTTOM - 0.5, top + 1, zp, zp + send + 2))
    za = zp + 38
    while za < zp + send:
        zb = min(za + 6, zp + send + 2)
        bottom = floor_at(za) + HV + 3.4
        if bottom < top - 2.4:
            land_block(xc - 10, xc + 10, za, zb, max(bottom, LAND_BOTTOM), top)
        za = zb
    air.append((xc - 11, xc + 11, FLOOR - 6, top + 4, zp - 2, zwall))
    # ── 입구: 언덕 몸 + 굴마다 앞면 · 문틀 · 고드름 · 등잔 · 간판 · 김 ──
    design = PORTALS[name]
    CAP = {"Rock": "RockSnow", "Rock2": "RockSnow", "Spoil": "RockSnow", "Spoil2": "RockSnow", "Stone": "StoneSnow",
           "Stone2": "StoneSnow", "Stone3": "StoneSnow", "Iron2": "StoneSnow"}
    for lx0, lx1, lz0, lz1, ly0, ly1, ry, tone in BODY:
        cx, cz = xc + (lx0 + lx1) / 2, zp + (lz0 + lz1) / 2
        P("Rock" if tone == 1 else "Rock2", cx, S + (ly0 + ly1) / 2, cz, lx1 - lx0, ly1 - ly0, lz1 - lz0, 0, ry)
        P("RockSnow", cx, S + ly1 + 0.3, cz, lx1 - lx0 + 0.4, 1.0, lz1 - lz0 + 0.4, 0, ry)
    for kind, lx0, lx1, lz0, lz1, ly0, ly1, ry, rz in design["front"]:
        for lx in (lx0 + 0.01, lx1 - 0.01):
            for lz in (lz0 + 0.01, lz1 - 0.01):
                if abs(lx) < W / 2 and lz > -0.5 and ly0 < HV - lz / 2:
                    bad.append(f"{name}: 앞면 {kind} ({lx0},{lz0}) 가 굴 안을 침범")
        if lx0 < 3.6 and lx1 > -3.6 and lz0 < 0 and lz1 > -15 and ly0 < 8:
            bad.append(f"{name}: 앞면 {kind} ({lx0},{lz0}) 가 레일 자리를 막음")
        cx, cz = xc + (lx0 + lx1) / 2, zp + (lz0 + lz1) / 2
        P(kind, cx, S + (ly0 + ly1) / 2, cz, lx1 - lx0, ly1 - ly0, lz1 - lz0, 0, ry, rz)
        if kind in CAP and not rz:
            P(CAP[kind], cx, S + ly1 + (0.3 if CAP[kind] == "RockSnow" else 0.2), cz, lx1 - lx0 + 0.3, 1.0 if CAP[kind] == "RockSnow" else 0.6,
              lz1 - lz0 + 0.3, 0, ry)
    if design["frame"] == "timber":
        for sgn in (-1, 1):
            P("Timber", xc + sgn * (W / 2 - 0.7), S + 7.6, zp - 0.6, 1.4, 15.6, 1.4)
        P("Timber", xc, S + 15.9, zp - 0.6, W + 1.6, 1.4, 1.6)
    if "hazard" in design:
        hx0, hx1, hz, hy0, hy1 = design["hazard"]
        n_ = 12
        for i in range(n_):
            P("Hazard" if i % 2 == 0 else "Hazard2", xc + hx0 + (i + 0.5) * (hx1 - hx0) / n_, S + (hy0 + hy1) / 2, zp + hz,
              (hx1 - hx0) / n_ + 0.02, hy1 - hy0, 0.12, 0, 0, 30)
    if "gear" in design:
        gx, gz, gy, gr = design["gear"]
        P("GearDisc", xc + gx, S + gy, zp + gz, 0.8, gr * 2, gr * 2, 0, 90)
        P("GearHub", xc + gx, S + gy, zp + gz - 0.5, 0.6, gr * 0.7, gr * 0.7, 0, 90)
        for k in range(10):
            a_ = math.radians(k * 36)
            P("Iron", xc + gx + math.cos(a_) * (gr + 0.5), S + gy + math.sin(a_) * (gr + 0.5), zp + gz, 1.0, 1.2, 0.8, 0, 0, k * 36 + 90)
    # 고드름(처마 아래로 매달림 — 굵은 위 + 가는 끝) { lx, lz, 매단 높이, 길이 }
    for lx, lz, ly, ln in design["ice"]:
        P("Icicle", xc + lx, S + ly - ln * 0.3, zp + lz, 0.55, ln * 0.6, 0.55)
        P("Icicle", xc + lx, S + ly - ln * 0.6 - ln * 0.2, zp + lz, 0.28, ln * 0.4, 0.28)
    for lx, lz, ly, kind in design["lamps"]:
        lamps.append((xc + lx, S + ly, zp + lz, 0.0, kind))
    for lx, lz, ly, w, h, text in design["signs"]:
        signs.append((xc + lx, S + ly, zp + lz, w, h, text))
        if ly < 10:   # 땅에 세운 간판은 말뚝
            P("Post", xc + lx, S + (ly - 0.6) / 2, zp + lz + 0.3, 0.5, ly - 0.6, 0.5)
    for lx, lz, ly in design["steam"]:
        steam.append((xc + lx, S + ly, zp + lz))
    if locked:
        bars = []
        for i in range(9):
            bx = xc - 6.4 + i * 1.6
            bars.append(("Bar", bx, S + 6.2, zp + 1.0, 0.5, 15.4, 0.5))
        for yy in (S + 1.2, S + 7.5, S + 13.6):
            bars.append(("Bar", xc, yy, zp + 1.0, W - 0.2, 0.5, 0.6))
        gates.append((name, bars))
    # ── 레일: 밖 선로(zp-14 ~ zp) → 기울어진 레일 → 바닥 평지 → 굴 방 안(zend+7) ──
    RT = 0.8                                    # 걷는 면 → 레일 윗면
    for sgn in (-1, 1):
        rx_ = xc + sgn * 2.0
        P("Rail", rx_, S + RT - 0.225, zp - 7, 0.35, 0.45, 14.4)
        y, z = slope(0)
        P("Rail", rx_, y + RT - 0.225 / CO, z, 0.35, 0.45, L + 0.4, deg)
        P("Rail", rx_, FLOOR + RT - 0.225, (zl + zend + 7) / 2, 0.35, 0.45, zend + 7 - zl + 0.4)
    for zz in [zp - 13 + 2.5 * i for i in range(6)]:
        P("Sleeper", xc, S + 0.175, zz, 6.4, 0.35, 1.0)
    for k in range(n):
        tz = zp + (k + 0.5) * step
        tt = S - (k + 1) * step / 2
        top_ = S - (tz - zp) / 2 + RT - 0.45
        P("Sleeper", xc, (tt + top_) / 2, tz, 6.4, top_ - tt, 1.0)
    zz = zl + 1.25
    while zz < zend + 7:
        P("Sleeper", xc, FLOOR + 0.175, zz, 6.4, 0.35, 1.0)
        zz += 2.5
    for bz_, gy in ((zp - 14, S), (zend + 7.6, FLOOR)):      # 멈춤 막이(기둥 둘 + 가로보)
        for sgn in (-1, 1):
            P("Post", xc + sgn * 2.0, gy + 1.2, bz_, 0.8, 2.4, 0.8)
        P("Buffer", xc, gy + 1.8, bz_ + (0.6 if gy == S else -0.6), 5.4, 0.9, 0.7)
    # 광차: 위(밖)·아래(굴 방) — 길 = 레일 윗면 점(탈 쪽 → 내릴 쪽)
    top_pts = [(xc, S + RT, zp - 9), (xc, S + RT, zp), (xc, FLOOR + RT, zl), (xc, FLOOR + RT, zend + 3)]
    carts.append((name, top_pts, locked, "굴 안으로"))
    carts.append((name, list(reversed(top_pts)), locked, "밖으로"))
    spots.append((name, xc, S + 0.5, zp - 16, xc, zp))
    caps.append((hole, *world(hx[0], hx[2]), *world(hx[1], hx[3]), top))
    print(f"{name}: 입구 z {zp:.0f} (땅 {S:.1f}) → 평지 z {zl:.0f} → 굴 방 z {zend:.0f} · 길이 {R + LANDING:.0f} · 계단 {n} · 도랑 {send:.0f}")

# 옛 구멍 메우기(땅 규칙) — 지하 천장도 그 자리만 막는다
for hole, x0, z0, x1, z1, top in caps:
    land_block(x0, x1, z0, z1, LAND_BOTTOM, top)
    P("CaveCeil", (x0 + x1) / 2, -33, (z0 + z1) / 2, x1 - x0, 6, z1 - z0)


if __name__ == "__main__":
    for p in bad:
        print("문제:", p)

    def row(t):
        return "\t{ " + ", ".join(f'"{v}"' if isinstance(v, str) else f"{v:.2f}" for v in t) + " },"

    out = ["-- snow_tunnel_plan.py 가 만든 자료(손으로 고치지 말 것)", "local PARTS = {"]
    out += [row(p) for p in parts]
    out += ["}", "local CARVE_LAND = {"] + [row(c) for c in carve_land]
    out += ["}", "local CARVE_UNDER = {"] + [row(c) for c in carve_under]
    out += ["}", "local AIR = {"] + [row(c) for c in air]
    out += ["}", "local LAMPS = {"] + [row(l) for l in lamps]
    out += ["}", "local SPOTS = {"] + [row(s) for s in spots]
    out += ["}", "local SHAFTS = {"] + [f'\t"{c[0]}",' for c in caps]
    out += ["}", "local SIGNS = {"] + [row(g) for g in signs]
    out += ["}", "local STEAM = {"] + [row(g) for g in steam]
    out += ["}", "local CARTS = {"]
    for cname, pts, lk, label in carts:
        out.append(f'\t{{ "{cname}", {str(lk).lower()}, "{label}", {{ ' + ", ".join(f"{{ {x:.2f}, {y:.2f}, {z:.2f} }}" for x, y, z in pts) + " } },")
    out += ["}", "local GATES = {"]
    for gname, bars in gates:
        out.append(f'\t{{ "{gname}", {{')
        out += ["\t" + row(b) for b in bars]
        out.append("\t} },")
    out += ["}"]
    open(os.path.join(HERE, "Snow_Tunnels_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"파트 {len(parts)} · 등잔 {len(lamps)} · 땅 빼기 {len(carve_land)} · 지하 빼기 {len(carve_under)} · 문제 {len(bad)}건")
