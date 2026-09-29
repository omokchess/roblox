# -*- coding: utf-8 -*-
"""
plains_north.py — 평원(절화) 북쪽 들녘 배치표. (2026-09-29)

요청: 마을과 필드 비율을 늪처럼, 언덕·돌이 있는 밀도 있는 땅. 섬은 바깥(북쪽)으로 넓힌다.
모티브(바이옴 배치.md): 평원 = 제주 해안평야, 오름 셋. 그래서
  - 오름 넷: 새별(억새 덮인 큰 오름) · 아부(굼부리에 나무 고리) · 봉수(작은 오름, 봉수대) · 송악(바다에 잘린 해안 오름)
  - 돌담 밭: 현무암 돌담으로 가른 밭(유채·보리·무)
  - 목장: 새별오름 남쪽 기슭, 나무 울
  - 곶자왈: 북서쪽 바위투성이 숲(이끼 낀 현무암 사이 나무)
  - 북포: 북쪽 만(灣)의 포구 마을 — 초가 몇 채, 올레 돌담, 방사탑, 불턱, 돌 부두
  - 해안: 검은 현무암 바위, 바다 돌기둥
길은 절화 북쪽 길 끝(북촌길 -37,922 · 동순환 548,895)에서 시작한다.

돌리는 법: python tools/fields/plains_north.py  → tools/fields/out/plains_north.png + 검사 + tools/swamp/field_data.luau
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from field_lib import (Canvas, Ground, COL, hash01, line_dist, load_hmap, lua, oreum_profile, pip, poly_edge_dist,
                       seg_dist)
import field_parts as FP
import field_pois as POI

NAME = "평원_북쪽들녘"
HERE = os.path.dirname(os.path.abspath(__file__))

# ================================================================ 땅
# 새 땅 둘레(시계 반대로 남서에서). 마지막 세 변은 원래 땅과 맞닿는 변(물가가 아니다)
COAST = [
    (-560, 975), (-600, 1100), (-650, 1300), (-620, 1500), (-560, 1680), (-600, 1880), (-540, 2060),
    (-400, 2210), (-240, 2320), (-60, 2390), (130, 2440), (330, 2470), (500, 2450),
    # 북포 만
    (560, 2400), (600, 2330), (660, 2300), (720, 2320), (760, 2390),
    (840, 2430), (1000, 2380), (1160, 2270), (1270, 2100), (1320, 1880), (1300, 1640), (1250, 1420),
    (1200, 1200), (1160, 1020), (1120, 905),
    (780, 925), (700, 975),
]
INLAND_EDGES = 3  # 끝 세 변(1120,905→780,925→700,975→-560,975)

# 높이 점(판 윗면). 물가로 갈수록 1 로 낮아진다
HEIGHTS = [
    (-450, 1100, 3), (0, 1060, 2.5), (400, 1060, 2.5), (900, 990, 3.5),
    (-400, 1500, 5), (150, 1450, 4), (600, 1450, 4.5), (1050, 1400, 7),
    (-350, 1900, 7), (250, 1950, 8), (750, 1900, 7), (1100, 1950, 9),
    (-100, 2250, 5), (400, 2300, 4), (900, 2250, 5),
]

# ================================================================ 오름
# rx·rz 밑 반지름, h 높이, p 옆모습(작을수록 볼록), crater 굼부리 반지름, depth 굼부리 깊이, tone 풀빛
OREUMS = [
    dict(name="새별오름", x=160, z=1900, rx=230, rz=190, yaw=20, h=62, p=0.8, tone="억새"),
    dict(name="아부오름", x=820, z=1690, rx=170, rz=160, yaw=0, h=38, p=0.9, crater=80, depth=16, tone="풀"),
    dict(name="봉수오름", x=-360, z=1640, rx=115, rz=100, yaw=-30, h=30, p=0.7, tone="풀"),
    dict(name="송악오름", x=1110, z=2080, rx=130, rz=120, yaw=40, h=48, p=0.6, crater=50, depth=18, tone="억새"),
    # 낮은 동산(평평한 들을 깨는 둔덕)
    dict(name="서쪽동산", x=-330, z=1330, rx=95, rz=80, yaw=25, h=10, p=1.3, tone="풀"),
    dict(name="동쪽동산", x=1020, z=1260, rx=110, rz=85, yaw=-20, h=12, p=1.3, tone="풀"),
    dict(name="바닷가동산", x=-100, z=2270, rx=75, rz=60, yaw=10, h=8, p=1.3, tone="풀"),
    dict(name="송악앞동산", x=1150, z=1520, rx=85, rz=70, yaw=35, h=14, p=1.2, tone="풀"),
    dict(name="목장뒤동산", x=560, z=1880, rx=80, rz=70, yaw=0, h=9, p=1.3, tone="풀"),
]

# ================================================================ 돌담(현무암). (점들, 문 자리들)
WALLS = [
    # 돌담 밭(절화 북쪽). 밭 여섯 칸
    ([(300, 1070), (470, 1080), (640, 1065), (730, 1080)], [(385, 1075), (560, 1072)]),
    ([(290, 1070), (300, 1250), (285, 1420)], [(296, 1160)]),
    ([(300, 1250), (460, 1240), (610, 1260), (740, 1235)], [(380, 1245), (535, 1250)]),
    ([(285, 1420), (450, 1440), (600, 1420), (760, 1450)], [(380, 1432), (540, 1428), (700, 1440)]),
    ([(470, 1080), (460, 1240), (470, 1430)], [(465, 1330)]),
    ([(640, 1065), (610, 1260), (600, 1420)], [(622, 1160)]),
    ([(730, 1080), (740, 1235), (760, 1450)], [(735, 1160)]),
    # 북포 올레(마을 안길 두 담)
    ([(470, 2150), (560, 2135), (640, 2130), (720, 2140), (820, 2160)], [(600, 2132), (690, 2134)]),
    ([(480, 2255), (520, 2300), (560, 2330)], []),
    ([(790, 2280), (760, 2320)], []),
    # 곶자왈 둘레 옛 잣담(목장 경계)
    ([(-500, 1760), (-380, 1790), (-240, 1800), (-150, 1840)], [(-310, 1796), (-163, 1831)]),
    # 서쪽 산담 들(무덤 둘레 돌담은 POI 로, 여기는 밭 경계 한 줄)
    ([(-520, 1420), (-420, 1400), (-300, 1440), (-180, 1420)], [(-360, 1420)]),
]

# ================================================================ 밭. (다각형, 작물)
FIELDS = [
    ([(300, 1078), (466, 1086), (458, 1236), (304, 1244)], "Canola"),
    ([(476, 1086), (634, 1072), (606, 1252), (466, 1236)], "Barley"),
    ([(646, 1074), (724, 1088), (734, 1228), (616, 1250)], "Radish"),
    ([(306, 1258), (456, 1250), (462, 1424), (292, 1414)], "Barley"),
    ([(466, 1250), (604, 1266), (596, 1414), (470, 1430)], "Canola"),
    ([(616, 1268), (734, 1244), (752, 1442), (606, 1422)], "Fallow"),
]

# ================================================================ 목장(나무 울). (점들, 문)
FENCES = [
    ([(-120, 1560), (100, 1556), (420, 1560), (430, 1700), (380, 1760), (250, 1780), (40, 1775), (-110, 1740), (-120, 1560)],
     [(160, 1557), (-116, 1650)]),
]

# ================================================================ 길. (이름, 폭, 점들)
PATHS = [
    ("북촌북로", 9, [(-37, 922), (-40, 1000), (0, 1150), (40, 1350), (70, 1450), (110, 1540), (160, 1557)]),
    ("목장안길", 7, [(160, 1557), (190, 1640), (230, 1720)]),
    ("오름둘레길", 8, [(-116, 1650), (-160, 1760), (-170, 1900), (-120, 2060), (0, 2180), (200, 2230), (400, 2210), (520, 2180),
                    (600, 2132)]),
    ("동쪽밭길", 9, [(548, 895), (560, 990), (560, 1072), (548, 1160), (535, 1250), (530, 1340), (540, 1432), (600, 1520),
                   (700, 1560), (760, 1570)]),
    ("포구길", 8, [(760, 1570), (700, 1760), (660, 1950), (660, 2080), (690, 2134)]),
    ("봉수길", 6, [(-160, 1760), (-250, 1700), (-300, 1640)]),
    ("곶자왈길", 6, [(-120, 2060), (-250, 2010), (-380, 2080), (-430, 2160)]),
    ("송악길", 6, [(840, 2185), (950, 2120), (1030, 2060)]),
]

# 오름 오르는 나무 계단 길(땅 위 계단). 점들은 발치 → 꼭대기
STAIRS = [
    ("새별 계단", [(230, 1735), (285, 1790), (240, 1835), (200, 1870), (170, 1900)]),
    ("아부 계단", [(760, 1570), (790, 1580), (810, 1612)]),
    ("봉수 계단", [(-300, 1640), (-330, 1640), (-352, 1640)]),
    ("송악 계단", [(1030, 2060), (1060, 2070), (1085, 2080)]),
]

# ================================================================ 바위(현무암). (x, z, 크기, 각, 기울기)
ROCKS = [
    # 북서 해안
    (-615, 1250, 9, 20, 6), (-640, 1330, 12, 70, -8), (-610, 1420, 7, 10, 4), (-600, 1550, 10, 45, 10),
    (-575, 1700, 8, 80, -5), (-610, 1830, 13, 25, 7), (-575, 1960, 9, 60, -6), (-520, 2090, 11, 15, 9),
    (-440, 2190, 8, 40, -7), (-330, 2270, 12, 75, 5), (-200, 2340, 9, 30, -9), (-80, 2385, 10, 55, 6),
    (60, 2420, 8, 10, -4), (220, 2455, 11, 65, 8), (380, 2465, 9, 35, -6),
    # 북포 만 둘레
    (545, 2395, 7, 20, 5), (590, 2340, 6, 50, -6), (735, 2345, 7, 30, 7), (780, 2400, 8, 70, -4),
    # 동해안(송악오름 밑 벼랑)
    (1180, 2240, 12, 40, 8), (1240, 2140, 14, 10, -6), (1290, 2010, 10, 60, 5), (1310, 1860, 9, 30, -8),
    (1300, 1700, 8, 50, 6), (1265, 1520, 10, 20, -5), (1220, 1330, 7, 75, 7), (1185, 1150, 9, 35, -6),
    # 곶자왈 이끼 바위
    (-360, 1960, 10, 30, 12), (-300, 1990, 7, 70, -9), (-240, 2060, 12, 10, 8), (-330, 2110, 8, 50, -12),
    (-420, 2040, 11, 20, 10), (-450, 1980, 7, 80, -8), (-200, 2130, 9, 40, 9), (-270, 2170, 6, 60, -7),
    (-390, 2150, 10, 15, 11), (-160, 2010, 8, 55, -10), (-230, 1940, 6, 25, 7), (-500, 2120, 9, 65, -9),
    # 들판 여기저기
    (120, 1270, 6, 30, 5), (-150, 1330, 8, 60, -6), (-420, 1380, 7, 20, 8), (880, 1320, 9, 45, -7),
    (1000, 1180, 7, 10, 6), (960, 1560, 8, 70, -5), (560, 1720, 6, 35, 7), (430, 2000, 7, 55, -8),
    (-40, 1960, 6, 20, 6), (980, 1850, 9, 40, 9),
]
# 바다 돌기둥. (x, z, 폭, 높이, 각)
STACKS = [(-480, 2300, 16, 28, 20), (-150, 2470, 12, 22, 60), (280, 2545, 14, 18, 35), (1240, 2330, 18, 30, 10)]

# ================================================================ 나무. 틀: P = 평원 활엽(절화 나무 틀), C = 삼나무(방풍림), B = 큰 팽나무
TREES = {
    # 돌담 밭 북쪽 방풍림(삼나무 한 줄)
    "방풍림": """
        C 300 1470 | C 330 1474 | C 360 1476 | C 390 1478 | C 420 1480 | C 450 1482 | C 480 1478 | C 510 1474
        C 540 1470 | C 610 1462 | C 630 1466 | C 660 1470 | C 690 1476 | C 720 1480 | C 750 1486
    """,
    # 곶자왈(북서 바위 숲)
    "곶자왈": """
        P -380 1920 | P -330 1935 | P -270 1920 | P -210 1950 | P -470 1955 | P -410 1990 | P -350 2010
        P -285 1985 | P -200 2040 | P -140 2060 | P -500 2030 | P -440 2080 | P -370 2100 | P -300 2090
        P -230 2100 | P -170 2110 | P -455 2050 | P -465 2100 | P -350 2170 | P -280 2140 | P -210 2190
        P -150 2170 | P -360 2195 | P -330 2230 | P -260 2240 | P -520 1990 | P -250 1980 | P -310 1960
        C -440 2010 | C -270 2070 | C -380 2200 | C -180 2080
    """,
    # 아부오름 굼부리 나무 고리
    "아부 고리": """
        C 820 1747 | C 856 1733 | C 877 1703 | C 877 1667 | C 856 1637 | C 820 1623 | C 784 1637 | C 763 1667
        C 763 1703 | C 784 1733
    """,
    # 북포 마을
    "북포": """
        B 590 2170 | P 470 2210 | P 850 2210 | C 480 2110 | C 520 2105 | C 800 2110 | C 840 2115
    """,
    # 들판 홀로 선 나무 · 길가
    "들판": """
        B 470 1640 | P -60 1300 | P -250 1250 | P -400 1450 | P 860 1180 | P 1000 1420 | P 960 1700
        P 1100 1640 | P 560 1900 | P 480 2050 | P -30 1500 | P 900 2050 | P 1180 1780 | P -480 1600
        C 820 1480 | C 850 1486 | C 880 1492 | C 910 1498
    """,
}

# 억새 덤불(새별·송악 오름 비탈, 봉수오름 기슭). (x, z)
GRASS = [
    (40, 1780), (80, 1760), (130, 1750), (190, 1760), (300, 1780), (330, 1830), (350, 1890), (340, 1960), (300, 2020),
    (240, 2060), (170, 2080), (100, 2070), (30, 2030), (-20, 1960), (-40, 1880), (-20, 1810), (90, 1840), (230, 1990),
    (120, 1990), (60, 1920), (250, 1850), (180, 1810), (-370, 1570), (-420, 1600), (-300, 1700), (-420, 1690),
    (1010, 2020), (1050, 1980), (1120, 1970), (1180, 2020), (1060, 2150), (1140, 2160),
]

# ================================================================ 절화 틀(ServerStorage.JeolhwaKit). (틀, x, z, yaw, 묶음)
# yaw: 0 이면 앞(-Z)이 남쪽을 본다. 180 = 북(바다) 쪽
KITS = [
    ("Building_Cottage", 560, 2240, 170, "북포/집"),
    ("Building_Cottage", 655, 2218, 180, "북포/집"),
    ("Building_House", 765, 2238, 195, "북포/집"),
    ("Annex_Thatch", 492, 2248, 130, "북포/집"),
    ("Annex_Thatch", 805, 2185, 230, "북포/집"),
    ("Prop_Well", 640, 2165, 0, "북포/살림"),
    ("Prop_Jangdok", 585, 2205, 170, "북포/살림"),
    ("Prop_Jangdok", 715, 2205, 190, "북포/살림"),
    ("Prop_Haystack", 520, 2160, 20, "북포/살림"),
    ("Prop_Haystack", 330, 1640, 10, "목장"),
    ("Prop_Haystack", 360, 1660, 60, "목장"),
    ("Prop_Haystack", 0, 1640, 30, "목장"),
]

# ================================================================ 특별한 자리. (종류, x, z, yaw, 설명)
POIS = [
    ("Beacon", -360, 1640, 0, "봉수오름 꼭대기 봉수대"),
    ("Shrine", -60, 2140, 30, "본향당: 신목과 돌 제단"),
    ("CaveArch", 330, 2075, 200, "용암굴 들머리(새별오름 북쪽 기슭)"),
    ("Pier", 660, 2300, 0, "북포 돌 부두(북쪽으로 80)"),
    ("Bulteok", 720, 2362, 0, "불턱(해녀 돌 쉼터)"),
    ("Bangsatap", 600, 2112, 0, "방사탑 서"),
    ("Bangsatap", 700, 2112, 0, "방사탑 동"),
    ("FishRack", 520, 2330, 30, "생선 말리는 덕"),
    ("Boat", 620, 2360, 10, "배"),
    ("Boat", 700, 2375, -20, "배"),
    ("Trough", 200, 1600, 0, "목장 물통"),
    ("Sandam", -230, 1230, 15, "산담(무덤 돌담)"),
    ("Sandam", -150, 1305, -10, "산담"),
    ("Sandam", -330, 1175, 30, "산담"),
    ("Sandam", 980, 1560, 5, "산담"),
    ("Pond", 1060, 1120, 0, "용천수 못(물가 바위·갈대)"),
    ("Dolhareubang", -58, 1005, 0, "돌하르방(북촌북로 들머리 서)"),
    ("Dolhareubang", -18, 1005, 0, "돌하르방(동)"),
    ("Tor", 940, 1370, 20, "현무암 바위더미"),
    ("Tor", -470, 1300, 60, "현무암 바위더미"),
    ("Tor", 330, 1560, 10, "현무암 바위더미(목장 안)"),
    ("Tor", -40, 2330, 40, "현무암 바위더미(바닷가)"),
]


# ================================================================ 판 만들기(규칙: 모양 안을 고르게 채운다)
def ground():
    shore = COAST[: len(COAST) - INLAND_EDGES + 1]
    g = Ground(COAST, HEIGHTS, coast_y=1.0, coast_w=150)
    # 물가 거리는 바다에 닿는 변만(원래 땅과 맞닿는 변 빼고)
    g.coast_d = lambda x, z: min(seg_dist(x, z, shore[i], shore[i + 1]) for i in range(len(shore) - 1))
    return g


GRASS_COL = [(113, 146, 80), (119, 153, 85), (112, 144, 79), (133, 157, 96), (116, 150, 82)]
SAND_COL = (181, 185, 134)


def land_plates(g):
    out = []
    step = 62
    xs = [p[0] for p in COAST]
    zs = [p[1] for p in COAST]
    x = min(xs) - step
    while x <= max(xs) + step:
        z = min(zs) - step
        while z <= max(zs) + step:
            px = x + (hash01(x, z, 1) - 0.5) * 14
            pz = z + (hash01(x, z, 2) - 0.5) * 14
            if pip(px, pz, COAST):
                out.append(plate(g, px, pz))
            z += step
        x += step
    # 물가 둘레 판(해안선이 이 빠지지 않게): 변을 따라 44 마다, 22 안쪽으로
    shore = COAST[: len(COAST) - INLAND_EDGES + 1]
    for i in range(len(shore) - 1):
        (ax, az), (bx, bz) = shore[i], shore[i + 1]
        L = math.hypot(bx - ax, bz - az)
        nx, nz = -(bz - az) / L, (bx - ax) / L  # 왼쪽 = 안쪽(시계 반대 둘레)
        n = max(1, int(L / 44))
        for k in range(n):
            t = (k + 0.5) / n
            px, pz = ax + (bx - ax) * t + nx * 22, az + (bz - az) * t + nz * 22
            if pip(px, pz, COAST):
                out.append(plate(g, px, pz, coastal=True))
    return out


def plate(g, x, z, coastal=False):
    h = hash01(x, z, 3)
    size = 70 + h * 18 if not coastal else 50 + h * 16
    top = g.y(x, z) + (hash01(x, z, 4) - 0.5) * 0.6
    d = g.coast_d(x, z)
    sand = d < 70 or (d < 110 and hash01(x, z, 5) < (110 - d) / 40)
    col = SAND_COL if sand else GRASS_COL[int(hash01(x, z, 6) * len(GRASS_COL))]
    return dict(x=round(x, 1), z=round(z, 1), s=round(size, 1), t=round(size * (0.9 + hash01(x, z, 8) * 0.2), 1),
                yaw=round(hash01(x, z, 7) * 90, 1), y=round(top, 2), m="Sand" if sand else "Grass", c=col,
                base=d < 140)


def tree_list():
    out = []
    for group, text in TREES.items():
        for tok in text.replace("\n", "|").split("|"):
            tok = tok.strip()
            if not tok:
                continue
            k, x, z = tok.split()
            out.append((k, float(x), float(z), group))
    return out


# ================================================================ 검사
def check(g):
    probs = []
    trees = tree_list()
    for k, x, z, grp in trees:
        if not g.inside(x, z):
            probs.append("나무 바다에 %s %s %s" % (grp, x, z))
        for name, w, pts in PATHS:
            if line_dist(x, z, pts) < w / 2 + 3:
                probs.append("나무가 길 위 %s (%s,%s) %s" % (grp, x, z, name))
        for pts, gates in WALLS:
            if line_dist(x, z, pts) < 4:
                probs.append("나무가 돌담 위 (%s,%s)" % (x, z))
    for i, a in enumerate(trees):
        for b in trees[i + 1:]:
            if math.hypot(a[1] - b[1], a[2] - b[2]) < 14:
                probs.append("나무끼리 너무 가깝다 %s %s" % (a[1:3], b[1:3]))
    for r in ROCKS:
        if not g.inside(r[0], r[1]) and g.coast_d(r[0], r[1]) > 26:
            probs.append("바위가 바다 멀리 %s" % (r[:2],))
        for name, w, pts in PATHS:
            if line_dist(r[0], r[1], pts) < w / 2 + r[2] * 0.6:
                probs.append("바위가 길을 막음 %s %s" % (r[:2], name))
    # 길이 돌담을 지날 때는 문 자리여야 한다
    for name, w, pts in PATHS:
        for wpts, gates in WALLS:
            for i in range(len(pts) - 1):
                for j in range(len(wpts) - 1):
                    p = seg_cross(pts[i], pts[i + 1], wpts[j], wpts[j + 1])
                    if p and not any(math.hypot(p[0] - gx, p[1] - gz) < 14 for gx, gz in gates):
                        probs.append("길 %s 이 돌담을 문 없이 지난다 %s" % (name, (round(p[0]), round(p[1]))))
        for fpts, gates in FENCES:
            for i in range(len(pts) - 1):
                for j in range(len(fpts) - 1):
                    p = seg_cross(pts[i], pts[i + 1], fpts[j], fpts[j + 1])
                    if p and not any(math.hypot(p[0] - gx, p[1] - gz) < 14 for gx, gz in gates):
                        probs.append("길 %s 이 울을 문 없이 지난다 %s" % (name, (round(p[0]), round(p[1]))))
        for x, z in pts:
            if not (g.inside(x, z) or z < 980):
                probs.append("길 점이 바다에 %s (%s,%s)" % (name, x, z))
    for kind, x, z, yaw, grp in KITS:
        for name, w, pts in PATHS:
            if line_dist(x, z, pts) < w / 2 + 8 and not kind.startswith("Prop"):
                probs.append("집이 길 위 %s (%s,%s) %s" % (kind, x, z, name))
    return probs


def seg_cross(a, b, c, d):
    (x1, y1), (x2, y2), (x3, y3), (x4, y4) = a, b, c, d
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-9:
        return None
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))
    return None


# ================================================================ 그림
def render(g, plates, path, hmap=None):
    cv = Canvas(-720, 820, 1400, 2620, 2.5)
    old = load_hmap(hmap) if hmap else None

    def base(x, z):
        if g.inside(x, z):
            oh = sum(oreum_profile(o, x, z) for o in OREUMS)
            d = g.coast_d(x, z)
            col = COL["Sand"] if d < 70 else COL["Grass"]
            k = max(0.55, min(1.35, 0.85 + (g.y(x, z) + oh) / 90))
            if any(o.get("tone") == "억새" and oreum_profile(o, x, z) > 4 for o in OREUMS):
                col = COL["Grass2"]
            return tuple(int(v * k) for v in col)
        if old:
            c = old(x, z)
            if c:
                return tuple(int(v * 0.8) for v in COL["Old"])
        return None
    cv.fill(base)
    for pts, crop in FIELDS:
        cv.fill(lambda x, z, pts=pts, crop=crop: (COL["Canola"] if crop == "Canola" else COL["Barley"] if crop == "Barley"
                                                   else (170, 150, 110) if crop == "Radish" else (150, 160, 100))
                if pip(x, z, pts) else None)
    for name, w, pts in PATHS:
        cv.line(pts, w, COL["Path"])
    for name, pts in STAIRS:
        cv.line(pts, 5, (190, 140, 90))
    for pts, gates in WALLS:
        cv.line(pts, 3, COL["Wall"])
        for gx, gz in gates:
            cv.dot(gx, gz, 5, (255, 255, 255))
    for pts, gates in FENCES:
        cv.line(pts, 2, COL["Fence"])
        for gx, gz in gates:
            cv.dot(gx, gz, 5, (255, 255, 255))
    for x, z, s, yaw, tilt in ROCKS:
        cv.dot(x, z, s * 0.8, COL["Basalt"])
    for x, z, w, h, yaw in STACKS:
        cv.dot(x, z, w * 0.6, (30, 28, 30))
    for x, z in GRASS:
        cv.dot(x, z, 5, (236, 226, 190))
    for k, x, z, grp in tree_list():
        cv.dot(x, z, 7 if k != "B" else 11, COL["Cedar"] if k == "C" else COL["Tree"])
    for kind, x, z, yaw, grp in KITS:
        cv.dot(x, z, 4 if kind.startswith("Prop") else 12, COL["Kit"])
    for kind, x, z, yaw, desc in POIS:
        cv.dot(x, z, 6, COL["Poi"])
    cv.grid(100)
    cv.save(path)


def emit(g, plates, path):
    data = dict(
        Name=NAME, Coast=COAST, InlandEdges=INLAND_EDGES, Plates=plates, Oreums=OREUMS,
        Walls=[dict(pts=p, gates=gts) for p, gts in WALLS], Fields=[dict(pts=p, crop=c) for p, c in FIELDS],
        Fences=[dict(pts=p, gates=gts) for p, gts in FENCES], Paths=[dict(name=n, w=w, pts=p) for n, w, p in PATHS],
        Stairs=[dict(name=n, pts=p) for n, p in STAIRS], Rocks=ROCKS, Stacks=STACKS,
        Trees=[dict(k=k, x=x, z=z, g=grp) for k, x, z, grp in tree_list()], Grass=GRASS,
        Kits=[dict(kind=k, x=x, z=z, yaw=y, g=grp) for k, x, z, y, grp in KITS],
        Pois=[dict(kind=k, x=x, z=z, yaw=y, desc=d) for k, x, z, y, d in POIS],
    )
    open(path, "w", encoding="utf-8", newline="\n").write("return " + lua(data) + "\n")


def build_parts(g, plates):
    """배치표 → 부품 목록(field_parts.txt). 묶음 경로는 Surface/F_<이름>/… 아래."""
    out = FP.Out()
    # 옛 판 치우기: 새 땅 다각형 안에 가운데가 든 평원 판(Gs·Gb)은 창고로(되돌릴 수 있게)
    out.lines.append("R Surface/World/G_평원 " + " ".join("%d %d" % p for p in COAST))
    FP.land(out, plates, "땅")
    stair_lines = [(pts, 3.6) for name, pts in STAIRS]
    tops = {}
    for o in OREUMS:
        FP.oreum(out, o, g, COAST, "오름/" + o["name"], cut_lines=stair_lines)
        tops[o["name"]] = o

    def top_fn(x, z):
        best = None
        for o in OREUMS:
            t = FP.oreum_top(o, g, x, z)
            if t is not None and (best is None or t > best):
                best = t
        return best
    for name, pts in STAIRS:
        FP.stairs(out, pts, top_fn, g.y, "길/" + name)
    for pts, gates in WALLS:
        FP.wall(out, pts, gates, "돌담")
    for pts, crop in FIELDS:
        FP.field(out, pts, crop, "밭/" + crop)
    for pts, gates in FENCES:
        FP.fence(out, pts, gates, "목장/울")
    for name, w, pts in PATHS:
        FP.path(out, pts, w, "길/" + name)
    for x, z, sz, yaw, tilt in ROCKS:
        inland = g.inside(x, z)
        mossy = -560 < x < -120 and 1900 < z < 2260
        FP.rock(out, x, z, sz, yaw, tilt, "바위", mossy=mossy, sea_y=None if inland else -3.8)
    for x, z, w, h, yaw in STACKS:
        FP.stack(out, x, z, w, h, yaw, "바위/바다돌기둥")
    for x, z in GRASS:
        FP.silvergrass(out, x, z, "억새", y_fn=top_fn)
    for k, x, z, grp in tree_list():
        t = top_fn(x, z)
        if k == "C":
            FP.cedar(out, x, z, "나무/" + grp, top=t)
        else:
            a = out.anchor(x, z)
            out.kit("나무/" + grp, "PlainsTree", x, z, hash01(x, z, 300) * 360, 1.7 if k == "B" else 1.0, anchor=a)
    for kind, x, z, yaw, grp in KITS:
        a = out.anchor(x, z)
        out.kit(grp, kind, x, z, yaw, 1.0, anchor=a)
    for kind, x, z, yaw, desc in POIS:
        if kind == "Beacon":
            POI.beacon(out, x, z, yaw, "명소/봉수대", top_fn(x, z))
        else:
            POI.BUILDERS[kind](out, x, z, yaw, "명소/" + desc.split("(")[0].split(":")[0].strip())
    return out


def main():
    g = ground()
    plates = land_plates(g)
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    hmap = os.environ.get("HMAP")
    render(g, plates, os.path.join(HERE, "out", "plains_north.png"), hmap)
    probs = check(g)
    print("판 %d장(물가 받침 %d), 나무 %d, 바위 %d, 억새 %d, 틀 %d" % (len(plates), sum(1 for p in plates if p["base"]),
                                                          len(tree_list()), len(ROCKS), len(GRASS), len(KITS)))
    print("검사 %d" % len(probs))
    for p in probs:
        print("  -", p)
    out = build_parts(g, plates)
    path = os.path.join(HERE, "..", "swamp", "field_parts.txt")
    open(path, "w", encoding="utf-8", newline="\n").write("F %s\n" % NAME + out.text())
    print("부품 %d, 틀 %d, 닻 %d → %s (%d KB)" % (out.count["P"], out.count["K"], out.anchors, path,
                                             os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
