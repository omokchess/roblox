# -*- coding: utf-8 -*-
"""
swamp_plan.py — 늪지대(G_늪지대) 안개늪식 재작업 배치표. (2026-09-28)

참고: C:/wth/roblox 안개늪 군도(Mistmire). 그쪽은 매끈한 지형 + 물 + 수상 마을 + 마녀 오두막 + 늪의 사당.
우리 늪은 80 스터드 흙 판(Gs)을 엇갈려 깐 섬이라 그 위에 지형(흙·물)을 덮고 판은 숨긴다.

- 바탕 높이: Studio 에서 잰 판 윗면(tools/swamp/swamph4_*.txt, 4 스터드 격자, Swamp_Survey.luau)
- 이 파일의 표(손으로 적은 자리)로 웅덩이·둑·길·언덕 머리를 찍고, 건물·다리·소품·나무를 놓는다.
- 수면 y = 0. 마을 판자길 바닥 y = 7(안개늪 DECK 과 같다).

돌리는 법(블렌더에 딸린 파이썬: numpy 필요)
  "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" tools/swamp_plan.py
  → tools/swamp/terrain.txt (Studio 가 http://127.0.0.1:35000/terrain.txt 로 읽음)
  → tools/Swamp_data.luau (배치), tools/swamp/plan.png (평면도), 검사 결과 출력
"""
import json
import math
import os
import sys
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "swamp"))
from pngw import write_png  # noqa: E402

MAN = json.load(open(r"C:\wth\roblox\assets\manifest.json", encoding="utf-8"))

X0, Z0, R, NX, NZ = 1384, 452, 4, 486, 312
WATER = 0.0
DECK = 7.0
MATS = ["Mud", "Ground", "LeafyGrass", "Grass", "Rock", "Pebble", "Slate", "Cobblestone", "Sand"]
M = {n: i for i, n in enumerate(MATS)}
ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

# ─────────────────────────────────────────────────────────────
# 지형 표 (좌표는 로블록스 x, z)
# ─────────────────────────────────────────────────────────────

# 웅덩이: (x, z, 반지름x, 반지름z, 바닥 높이, 가장자리 폭)  — 바닥으로 파낸다
PONDS = [
    (1742, 770, 17, 15, -1.7, 12),      # 어부 오두막 웅덩이(마을 북쪽 마당)
    (2940, 1190, 58, 58, -2.0, 10),     # 사당 해자
    (2425, 805, 34, 30, -2.2, 10),      # 마녀 오두막 둘레
    (1428, 1075, 30, 40, -2.2, 8),      # 서쪽 어부 오두막 물가(둘레 물길 넓힘)
]

# 젖은 땅(얕은 물웅덩이): (x, z, 반지름x, 반지름z, 수면 아래 깊이) — 늪다운 얼룩, 길·건물 자리는 피해서 손으로 둔다
WET = [
    # 서쪽 숲
    (1560, 800, 45, 30, -0.7), (1640, 905, 30, 24, -0.6), (1505, 1250, 38, 55, -0.8), (1625, 1325, 30, 20, -0.6),
    (1540, 640, 34, 26, -0.6), (1690, 1180, 26, 34, -0.7),
    # 남서 죽은 늪
    (1600, 1480, 70, 45, -0.9), (1722, 1562, 50, 34, -0.8), (1560, 1602, 40, 28, -0.7), (1805, 1445, 34, 24, -0.6),
    # 북쪽 마당 너머
    (2082, 640, 55, 34, -0.7), (1960, 600, 30, 24, -0.6),
    # 북동
    (2600, 700, 50, 38, -0.8), (2782, 600, 40, 30, -0.7), (2862, 905, 44, 30, -0.7), (2700, 1000, 36, 26, -0.6),
    # 동쪽
    (3150, 1000, 44, 60, -0.8), (3120, 1300, 50, 34, -0.7), (3200, 1500, 44, 40, -0.8), (3060, 1600, 36, 26, -0.6),
    # 남쪽 가운데
    (2250, 1370, 44, 34, -0.7), (2505, 1452, 55, 40, -0.8), (2652, 1562, 44, 34, -0.7), (2560, 1600, 30, 22, -0.6),
    # 언덕 아래
    (2250, 1110, 26, 20, -0.5), (2555, 1130, 30, 22, -0.6),
]

# 둔덕·자리 고르기: (x, z, 반지름, 높이, 가장자리 폭)
MOUNDS = [
    (1992, 800, 13, 1.8, 14),     # 마을 망루
    (1862, 818, 10, 1.25, 8),     # 북쪽 비탈 발치
    (1768, 1040, 9, 1.25, 8),     # 서쪽 비탈 발치
    (1964, 874, 9, 1.25, 8),      # 동쪽 비탈 발치
    (2104, 1180, 9, 1.25, 8),     # 남쪽 못 동쪽 비탈 발치
    (2010, 1424, 15, 1.3, 10),    # 선착장 뭍 끝
    (2425, 829, 6, 0.5, 5),       # 마녀 오두막 계단 발치(계단 끝 z≈826)
    (2400, 1062, 30, 6.6, 18),    # 가운데 언덕 돌무리 마당
    (3062, 772, 16, 7.4, 16),     # 북동 언덕 망루
]

# 길(돌·흙 둑길): (점 목록, 반폭, 최소 높이, 재질) — 물 위를 지나면 둑이 된다
PATHS = [
    # 마을 동쪽 → 마녀 오두막
    ([(1964, 874), (2060, 890), (2180, 905), (2300, 900), (2425, 886), (2425, 829)], 5, 0.8, "Pebble"),
    # 마녀 → 가운데 언덕 돌무리
    ([(2425, 886), (2418, 960), (2402, 1030)], 4.5, 0.8, "Pebble"),
    # 남쪽 못 → 사당(언덕 남쪽을 돌아)
    ([(2104, 1180), (2200, 1232), (2320, 1252), (2450, 1246), (2560, 1282), (2642, 1322), (2716, 1310)], 5, 0.8, "Pebble"),
    # 사당 둑길(물 위)
    ([(2716, 1310), (2780, 1300), (2850, 1268), (2906, 1224)], 6, 0.8, "Cobblestone"),
    # 마녀 → 북동 망루
    ([(2425, 886), (2510, 902), (2620, 852), (2800, 822), (2950, 800), (3050, 782)], 4.5, 0.8, "Ground"),
    # 마을 서쪽 → 서쪽 어부 오두막
    ([(1768, 1040), (1650, 1062), (1520, 1060), (1478, 1066)], 4.5, 0.8, "Ground"),
    # 선착장 → 남서 죽은 늪
    ([(2010, 1428), (1900, 1470), (1780, 1500), (1682, 1518)], 4.5, 0.8, "Ground"),
    # 북쪽 비탈 → 마당
    ([(1862, 818), (1862, 740), (1900, 700)], 4.5, 0.8, "Ground"),
    # 나무꾼 집 → 북동 길
    ([(2700, 656), (2708, 760), (2716, 832)], 3.5, 0.8, "Ground"),
]

LEVEE_W = 14      # 섬 가장자리 둑 폭(스터드): 물이 허공에 서지 않게 가장자리는 뭍으로
LEVEE_H = 0.9

# ─────────────────────────────────────────────────────────────
# 배치 표
#   (에셋, x, z, 높이, 방향(도), 크기)
#   높이: 숫자면 그 y 에 그대로(물 위 기둥집·판자길은 0, 판자 위는 DECK),
#         "g" 면 지형에 광선을 쏴 그 높이, "g-7" 처럼 더하기 빼기 가능(뭍에 박는 기둥집)
#   방향: 로블록스 y 축 회전. 0 이면 건물 앞(입구)이 +z, 90 이면 +x, -90 이면 -x, 180 이면 -z
# ─────────────────────────────────────────────────────────────

# 마을 판자길: 안개늪 마을을 90도 돌려(그쪽 동쪽 → 우리 남쪽) 북쪽 못에 앉혔다. X = 1862 + y_b, Z = 500 + x_b
WALKS = [
    [(1862, 840), (1862, 874), (1862, 935.7)],
    [(1862, 874), (1908, 874)],
    [(1908, 874), (1908, 1040)],
    [(1908, 1040), (1862, 1040), (1862, 984.3)],
    [(1862, 874), (1816, 874)],
    [(1816, 874), (1816, 1040)],
    [(1816, 960), (1843.7, 960)],
    [(1816, 1040), (1862, 1040)],
    [(1908, 1040), (1908, 1100)],
    [(1908, 874), (1940, 874)],
    [(1816, 1040), (1784, 1040)],
    # 남쪽 못
    [(1908, 1136), (1950, 1180)],
    [(1950, 1180), (2010, 1180)],
    [(2010, 1180), (2010, 1334)],
    [(2010, 1180), (2080, 1180)],
]
JUNCTIONS = [(1862, 874), (1908, 874), (1908, 1040), (1862, 1040), (1816, 874), (1816, 1040), (1816, 960),
             (1950, 1180), (2010, 1180)]
RAMPS = [  # (윗끝, 아래쪽으로 향하는 점)
    ((1862, 840), (1862, 824)),
    ((1784, 1040), (1768, 1040)),
    ((1940, 874), (1956, 874)),
    ((2080, 1180), (2096, 1180)),
]
BRIDGES = [((1908, 1100), (1908, 1136))]

PLACE = [
    # ── 늪 마을 북쪽 못 (안개늪 마을 그대로, 방향은 -90 돌림)
    ("Longhouse", 1862, 960, 0, -90, 1),
    ("StiltHouseA", 1922.8, 898, 0, -90, 1),
    ("StiltHouseB", 1921.8, 952, 0, -90, 1),
    ("StiltHutC", 1920.8, 1006, 0, -90, 1),
    ("StiltHouseB", 1802.2, 898, 0, 90, 1),
    ("StiltHouseA", 1801.2, 1014, 0, 90, 1),
    ("DeckPlatform", 1800.7, 940, 0, -90, 1),
    ("DeckPlatform", 1800.7, 964, 0, -90, 1),
    ("MarketStallA", 1795.5, 940, DECK, 90, 1),
    ("MarketStallB", 1795.5, 965, DECK, 90, 1),
    ("NoticeBoard", 1790.5, 952.5, DECK, 90, 1),
    ("Bench", 1806.5, 952.5, DECK, -90, 1),
    ("LampPost", 1868, 868, DECK, 0, 1),
    ("LampPost", 1902, 1034, DECK, 0, 1),
    ("LampPost", 1822, 1034, DECK, 0, 1),
    ("LampPost", 1822, 880, DECK, 0, 1),
    # ── 남쪽 못: 집 넷 + 선착장
    ("StiltHouseA", 2024.8, 1215, 0, -90, 1),
    ("StiltHutC", 2022.8, 1262, 0, -90, 1),
    ("StiltHouseB", 1996.2, 1240, 0, 90, 1),
    ("StiltHouseA", 1995.2, 1290, 0, 90, 1),
    ("FerryDock", 2010, 1395, 0, -90, 1),
    ("Rowboat", 1984, 1362, 0, 10, 1),
    ("Rowboat", 2038, 1364, 0, -15, 1),
    ("Rowboat", 2066, 1300, 0, 80, 1),
    ("LampPost", 2016, 1186, DECK, 0, 1),
    ("LampPost", 2016, 1320, DECK, 0, 1),
    ("LampPost", 1999, 1430, "g", 0, 1),
    ("LampPost", 2021, 1430, "g", 0, 1),
    # ── 북쪽 마당 (안개늪 선착장 쪽 물건들)
    ("Watchtower", 1992, 800, "g-0.4", -75, 1),
    ("StiltHutC", 1742, 770, 0, 110, 1),
    ("FishRack", 1762, 794, "g", 20, 1),
    ("Rowboat", 1754, 752, 0, -20, 1),
    ("Signpost", 1876, 786, "g", 90, 1),
    ("TorchPost", 1852, 800, "g", 0, 1),
    ("TorchPost", 1872, 800, "g", 0, 1),
    ("Campfire", 1918, 760, "g", 0, 1),
    ("Bench", 1918, 748, "g", 180, 1),
    ("CargoPile", 1836, 744, "g", -70, 1),
    ("CargoPile", 1896, 722, "g", 15, 1),
    ("Well", 1812, 722, "g", 0, 1),
    # ── 마녀 오두막
    ("WitchHut", 2425, 805, 0, 0, 1),
    ("TorchPost", 2419, 862, "g", 0, 1),
    ("TorchPost", 2431, 862, "g", 0, 1),
    # ── 가운데 언덕 돌무리(옛 제단 우물을 돌기둥 여섯과 아치가 두른다)
    ("Well", 2400, 1062, "g", 0, 1),
    ("RuinArch", 2402, 1036, "g-0.3", 0, 1.2),
    ("RuinPillar", 2426, 1045, "g-0.3", 50, 1.2),
    ("RuinPillar", 2428, 1076, "g-0.3", 110, 1.2),
    ("RuinPillar", 2405, 1091, "g-0.3", 170, 1.2),
    ("RuinPillar", 2376, 1080, "g-0.3", 230, 1.2),
    ("RuinPillar", 2372, 1049, "g-0.3", 290, 1.2),
    # ── 늪의 사당
    ("MireShrine", 2940, 1190, 0, -45, 1),
    # 둑길 횃불: 둑 가운데 줄에서 4 스터드 옆(둑 반폭 6)
    ("TorchPost", 2722.6, 1313.0, "g", 0, 1),
    ("TorchPost", 2721.4, 1305.0, "g", 0, 1),
    ("TorchPost", 2799.9, 1295.3, "g", 0, 1),
    ("TorchPost", 2842.2, 1267.9, "g", 0, 1),
    ("TorchPost", 2899.7, 1234.0, "g", 0, 1),
    ("TorchPost", 2894.7, 1227.8, "g", 0, 1),
    ("RuinArch", 2815, 1284, "g-0.3", -65.4, 1.25),
    ("RuinPillar", 2800, 1330, "g-0.4", 30, 1.3),
    ("RuinPillar", 2758, 1268, "g-0.4", -20, 1.2),
    ("RuinPillar", 2872, 1302, "g-0.4", 60, 1.3),
    ("RuinPillar", 2830, 1232, "g-0.4", 10, 1.2),
    ("RuinPillar", 2990, 1262, "g-0.4", -35, 1.3),
    ("RuinPillar", 3006, 1128, "g-0.4", 75, 1.2),
    # ── 북동 언덕 망루
    ("Watchtower", 3062, 772, "g-0.4", 20, 1),
    ("Campfire", 3036, 800, "g", 0, 1),
    # ── 서쪽 어부 오두막(둘레 물길)
    ("StiltHutC", 1428, 1075, 0, 90, 1),
    ("FishRack", 1500, 1084, "g", 90, 1),
    ("Rowboat", 1420, 1112, 0, 5, 1),
    # ── 사냥꾼 쉼터(사당 길 가운데)
    ("Campfire", 2640, 1344, "g", 0, 1),
    ("CargoPile", 2618, 1360, "g", 30, 1),
    ("Bench", 2660, 1356, "g", -60, 1),
    ("TorchPost", 2632, 1318, "g", 0, 1),
    # ── 남서 끝 물에 잠긴 옛 문(죽은 늪 길의 끝)
    ("RuinArch", 1672, 1520, "g-0.3", -79.6, 1.3),
    ("RuinPillar", 1668, 1486, "g-0.4", 20, 1.3),
    ("RuinPillar", 1705, 1540, "g-0.4", 60, 1.15),
    # ── 북동 들 나무꾼 집(뭍에 기둥을 묻는다: g-7), 앞마당은 남쪽
    ("StiltHouseB", 2700, 630, "g-7", 0, 1),
    ("Well", 2736, 690, "g", 0, 1),
    ("Fence", 2662, 668, "g", 90, 1),
    ("Fence", 2662, 681, "g", 90, 1),
    ("Fence", 2662, 694, "g", 90, 1),
    ("Fence", 2670, 712, "g", 0, 1),
    ("Fence", 2694, 712, "g", 0, 1),
    ("CargoPile", 2742, 648, "g", 90, 1),
    ("FallenLog", 2745, 712, "g", 5, 0.9),
    ("FallenLog", 2748, 722, "g", -8, 0.85),
    ("LampPost", 2716, 660, "g", 0, 1),
    ("Bench", 2688, 664, "g", 180, 1),
    # ── 동쪽 물길 난파선
    ("Shipwreck", 3242, 1180, -1.5, 8, 1),
]

# ─────────────────────────────────────────────────────────────
# 풀·나무 표 (손으로 적은 자리)
#   글자: A/B/C 늪삼나무(CypressA/B/C), M 맹그로브, D 죽은 나무, L 활엽수, S 덤불, R 갈대, P 수련잎,
#         F 쓰러진 통나무, G 빛버섯.   "C 1520 640" 또는 크기를 붙여 "C1.3 1520 640"
#   방향은 차례로 137.5 도씩 돌리고, 크기를 안 적으면 글자별 크기 목록을 차례로 돈다(둘 다 규칙적 반복)
# ─────────────────────────────────────────────────────────────
VKIND = {"A": "CypressA", "B": "CypressB", "C": "CypressC", "M": "Mangrove", "D": "DeadTree", "L": "BroadleafTree",
         "S": "SwampBush", "R": "Reeds", "P": "LilyPads", "F": "FallenLog", "G": "GlowMushrooms"}
VSCALE = {"A": (1.0, 1.15, 0.9, 1.25, 1.05), "B": (1.1, 0.95, 1.25, 1.0, 1.15), "C": (1.0, 1.2, 0.9, 1.1),
          "M": (1.0, 1.15, 0.9, 1.2), "D": (1.0, 1.2, 0.85, 1.1), "L": (1.0, 1.15, 0.9, 1.1),
          "S": (1.0, 1.3, 0.85, 1.15, 1.45), "R": (1.0, 1.25, 0.85, 1.1), "P": (1.0, 1.3, 0.8, 1.15),
          "F": (1.0, 1.15, 0.9), "G": (1.0, 1.3, 0.8)}
VY = {"A": "g-0.5", "B": "g-0.5", "C": "g-0.5", "M": "g-0.3", "D": "g-0.3", "L": "g-0.4", "S": "g-0.2", "R": "g-0.2",
      "P": -0.3, "F": "g-0.3", "G": "g-0.1"}
# 물 깊이 조건(지형 높이 h 범위)
VH = {"A": (-1.6, 99), "B": (-1.6, 99), "C": (-1.6, 99), "M": (-2.9, 1.3), "D": (-2.2, 99), "L": (0.4, 99),
      "S": (0.15, 99), "R": (-1.7, 0.8), "P": (-99, -0.8), "F": (0.1, 99), "G": (0.15, 99)}

VEG = {
    # 북쪽 들: 마당(1880,760)을 비우고 북서·북쪽 웅덩이·북동에 숲 덩이, 북쪽 물길 서쪽 둑엔 맹그로브
    "북쪽 들": """
        C 1868 541 | B 1902 568 | A 1842 594 | C 1884 626 | B 1826 645
        A 1936 540 | C 1990 536 | B 2014 575 | A 1926 630 | D 1962 606
        C 2060 532 | B 2106 550 | A 2150 584 | C 2138 630 | B 2046 692 | A 2100 702
        M 2190 540 | M 2200 612 | M 2214 690 | M 2232 772
        L 1790 688 | L 1958 690 | B 2040 748 | L 2086 792 | C 2132 758
        A 1718 692 | C 1706 822 | B 1770 846
        S 1850 690 | S 1965 655 | S 2075 600 | S 2000 820 | S 1800 800 | S 2160 700
        G 1905 600 | G 2120 660 | F 2010 660 | F 1760 640
        M 1850 490 | M 1960 488 | M 2080 492
        M 1720 560 | M 1650 640 | M 1580 720 | M 1520 780 | M 1705 612
        P 1655 660 | P 1560 750 | P 1720 590 | P 2330 600 | P 2320 690
    """,
    # 마을 못 둘레 뭍
    "마을 둘레": """
        C 1722 880 | A 1745 935 | C 1712 1000
        B 1975 935 | A 1985 988 | C 1975 1042
        A 1830 1160 | C 1860 1200 | B 1812 1112
        C 1850 1245 | A 1886 1290 | B 1840 1325 | A 1878 1372
        C 2120 1282 | B 2155 1322 | A 2108 1358 | C 2168 1392
        S 1760 900 | S 1750 975 | G 1735 960 | G 1995 1020
        P 1840 1010 | P 1885 905 | P 1935 1070 | P 1835 1075
        P 1960 1230 | P 2060 1250 | P 2055 1335 | P 1965 1170
    """,
    # 서쪽 삼나무 숲(오솔길 북쪽)
    "서쪽 숲 북": """
        A 1562 790 | B 1598 770 | C 1622 800 | A 1656 820
        B 1588 848 | C 1628 868 | A 1672 852
        A 1570 905 | D 1612 928 | B 1668 912 | C 1700 950
        C 1582 965 | A 1625 990 | B 1668 975
        M 1510 822 | M 1510 905 | M 1472 985
        S 1560 880 | S 1640 945 | S 1700 1015 | G 1600 880 | G 1655 1000 | F 1590 1010
    """,
    # 서쪽 삼나무 숲(오솔길 남쪽)
    "서쪽 숲 남": """
        A 1528 1112 | C 1575 1098 | B 1625 1112 | A 1668 1098 | C 1712 1118 | B 1760 1102
        B 1498 1165 | C 1548 1150 | A 1598 1172 | B 1645 1160 | D 1690 1182 | A 1735 1165 | C 1778 1205
        A 1478 1215 | C 1525 1210 | B 1572 1238 | A 1620 1215 | C 1665 1245 | B 1715 1230 | A 1760 1262
        D 1508 1262 | A 1545 1290 | B 1596 1278 | D 1645 1305 | C 1690 1292 | B 1740 1312 | A 1785 1332
        C 1545 1340 | A 1580 1362 | B 1638 1378 | A 1690 1352 | C 1738 1385
        M 1418 1180 | M 1425 1250 | M 1488 1292 | M 1560 1405
        S 1600 1130 | S 1690 1140 | S 1560 1250 | S 1720 1280 | S 1590 1300 | S 1700 1410
        G 1650 1200 | G 1760 1220 | F 1620 1265 | F 1592 1205
    """,
    # 남서 죽은 늪과 남쪽 둑
    "남서 죽은 늪": """
        D 1745 1440 | D 1705 1470 | D 1812 1440 | D 1822 1545 | D 1850 1585 | D 1905 1610
        F 1770 1455 | F 1870 1545 | F 1940 1600
        C 1880 1510 | C 1945 1520 | A 1990 1562 | B 1950 1470
        C 2040 1480 | A 2085 1520 | B 2030 1540 | C 2070 1592 | A 2002 1605 | B 2120 1560
        M 2185 1470 | M 2190 1540 | M 2178 1610 | M 1860 1640 | M 1990 1655 | M 2100 1640
        S 1760 1410 | S 1905 1560 | S 1830 1500 | S 2060 1440
        G 1880 1590 | G 1860 1565
    """,
    # 마을과 언덕 사이
    "마을 동쪽": """
        C 2010 945 | A 2060 962 | B 2110 942 | C 2162 968 | A 2215 950
        B 2040 1012 | C 2095 1032 | A 2150 1005 | B 2205 1040
        C 2025 1078 | B 2075 1102 | A 2130 1082 | C 2180 1112 | B 2228 1090
        A 2068 1125 | C 2110 1158 | B 2172 1178 | D 2250 1112
        S 2050 1110 | S 2135 990 | S 2240 1000 | S 2255 1180
        G 2080 990 | G 2200 1150 | F 2150 1050
    """,
    # 가운데 언덕: 활엽수가 돌무리를 둘러싼다
    "가운데 언덕": """
        L 2312 988 | L 2332 1132 | L 2470 1002 | L 2482 1120 | L 2398 1162 | L 2300 1062 | L 2350 948 | L 2462 942
        S 2340 1010 | S 2455 1030 | S 2345 1100 | S 2420 1140
    """,
    # 마녀 웅덩이: 죽은 나무·맹그로브·빛버섯·수련
    "마녀 웅덩이": """
        D 2310 790 | M 2340 832 | D 2355 745 | M 2470 745 | D 2505 790 | M 2495 845 | D 2372 862
        G 2380 870 | G 2455 868 | G 2330 860
        P 2380 790 | P 2462 812 | P 2445 770 | P 2395 830
        M 2318 560 | M 2322 650 | M 2360 720
    """,
    # 북동 들(나무꾼 집 둘레)
    "북동 들": """
        C 2362 548 | B 2410 565 | A 2455 535 | A 2380 622 | C 2440 640 | B 2492 600
        L 2545 560 | D 2598 700
        C 2640 540 | A 2690 525 | B 2740 548 | C 2790 530 | D 2786 598
        A 2830 650 | C 2872 690 | B 2820 720
        C 2470 700 | B 2520 745 | A 2380 710 | A 2660 770 | C 2745 760 | B 2850 790 | L 2560 800
        S 2520 610 | S 2580 540 | S 2600 620 | S 2475 670 | S 2700 800 | S 2800 700 | S 2410 690
        G 2480 640 | G 2860 640 | F 2555 655 | F 2880 740
        M 2420 490 | M 2560 492 | M 2700 488 | M 2835 510
    """,
    # 북동 언덕(망루)
    "북동 언덕": """
        L 2980 690 | L 3100 690 | L 3140 800 | L 2975 850 | L 3080 860
        M 2940 590 | M 3010 600 | M 3060 612
        C 2920 660 | B 2935 720 | A 3160 700 | B 3170 760 | C 3150 850
        M 3210 780 | M 3222 860
        S 3000 740 | S 3110 740 | S 3030 850 | G 3120 830
        P 2960 580
    """,
    # 동쪽 숲과 사당 둘레
    "동쪽 숲": """
        C 2920 915 | A 2970 940 | B 3020 915 | C 3070 945 | A 3120 925 | B 3180 940
        D 3150 1000
        A 2935 1000 | C 2990 990 | B 3050 1010 | A 3100 1050 | C 3175 1070
        B 3060 1080 | C 3080 1150 | A 3140 1130 | B 3190 1190
        A 3060 1220 | C 3120 1230 | B 3175 1270
        D 3110 1300 | C 3050 1320 | A 3160 1340 | B 3090 1370 | C 3020 1400
        D 2860 1120 | D 3030 1175 | D 2835 1160 | D 3000 1270
        M 2880 1340 | M 2960 1285
        G 3010 1100 | G 2880 1420 | G 3030 1300
        P 2780 1340 | P 2790 1360 | P 2745 1345 | P 2850 1330 | P 2900 1140 | P 2985 1145 | P 2995 1240
        M 3228 1000 | M 3225 1330 | M 3235 1420 | M 3218 1080 | M 3150 1465 | M 3200 1500
        P 3240 1250
    """,
    # 언덕과 사당 사이 숲
    "가운데 동쪽": """
        C 2535 930 | A 2590 915 | B 2645 940 | C 2700 925 | A 2760 945 | B 2815 920 | C 2870 940
        A 2520 1000 | C 2580 985 | B 2635 1010 | D 2700 1000 | A 2755 1020 | C 2815 995 | B 2860 1050
        B 2530 1070 | A 2600 1060 | C 2660 1085 | B 2720 1065 | A 2780 1090
        D 2555 1128 | C 2615 1150 | A 2680 1160 | B 2745 1140 | C 2800 1165
        A 2520 1195 | B 2580 1215 | C 2650 1225 | A 2715 1210 | B 2770 1235
        S 2560 950 | S 2680 960 | S 2740 1110 | S 2600 1110 | S 2830 1060
        G 2670 1030 | G 2790 1200 | F 2620 1180 | F 2800 950
    """,
    # 사당 길 남쪽(가운데 남)
    "가운데 남": """
        C 2240 1290 | A 2300 1300 | B 2360 1290 | C 2420 1300 | A 2480 1310 | B 2540 1330
        B 2275 1340 | D 2250 1372 | A 2330 1360 | C 2395 1370 | B 2455 1385 | A 2520 1395
        C 2385 1440 | A 2440 1450 | B 2600 1395 | C 2690 1390
        C 2255 1195 | A 2330 1205 | B 2420 1200 | C 2490 1215
        S 2280 1255 | S 2380 1330 | S 2470 1350 | S 2580 1370
        G 2350 1400 | G 2560 1310 | F 2430 1340
    """,
    # 남동 뭍
    "남동 뭍": """
        D 2500 1455
        A 2430 1510 | C 2480 1540 | B 2545 1500 | A 2590 1470 | C 2640 1440
        B 2700 1430 | A 2760 1455 | C 2820 1430 | B 2880 1450 | A 2940 1430
        C 2620 1520 | B 2680 1500 | A 2735 1520 | C 2795 1500 | B 2850 1520 | C 2910 1500
        D 2652 1562 | B 2700 1580 | C 2760 1575 | A 2820 1590 | B 2880 1580 | D 2945 1570 | A 2520 1590
        M 2450 1620 | M 2620 1640 | M 2780 1640 | M 2920 1625
        M 2410 1470 | M 2400 1560 | M 2440 1600 | M 2985 1480 | M 2990 1545
        S 2560 1430 | S 2660 1470 | S 2790 1470 | S 2900 1560 | S 2650 1610
        G 2700 1545 | G 2860 1480 | F 2600 1530 | F 2830 1555
        P 2600 1655
    """,
    # 빈 곳 검사로 찾아 메운 자리(길 따라 좁은 띠, 물가 둑 사이)
    "메움": """
        C 2140 812 | B 2188 835 | A 2236 818 | C 2270 855 | B 2125 862 | S 2210 870 | G 2160 860
        A 2052 842 | B 2096 856 | S 2020 852 | S 2045 912 | S 2090 915
        B 2625 800 | C 2790 785 | A 2640 885 | C 2700 875 | B 2760 870 | A 2830 865 | C 2890 860 | B 2935 850
        C 2940 1335 | A 2985 1365 | B 2930 1390
        B 2925 1048 | A 2978 1052 | D 2945 1088 | B 2885 1010
        C 2150 1245 | A 2190 1275 | B 2125 1420 | C 2130 1470
        A 1870 1425 | S 1925 1440 | B 1935 1415
        A 2538 1242 | L 2270 938 | S 2390 930 | G 2395 975 | S 2375 1225
        B 3160 1395 | M 3180 1430 | A 3200 1130 | S 3115 1185
        C 3040 670 | S 3050 720 | A 2925 772
        B 1530 1022 | C 2685 1262 | S 2612 1260
        B 2845 585 | A 2662 588 | C 2612 762 | C 2178 765
        S 1985 735 | S 1690 752 | S 1925 812 | S 2575 1575 | B 2585 1622
    """,
    # 섬 둘레 물길: 비어 보이던 곳마다 맹그로브 한 그루와 수련
    "둘레 물길": """
        M 2180 478 | M 2480 478 | M 2630 478 | M 1790 538 | M 3140 628 | M 3288 838 | M 3260 925 | M 1402 1045
        M 3260 1135 | M 2300 1435 | M 3080 1435 | M 1760 1525 | M 2990 1615 | M 2720 1645 | M 2150 1672
        M 2540 1672 | M 2840 1672
        P 2205 500 | P 2505 500 | P 1815 555 | P 3165 650 | P 1425 1020 | P 2320 1460 | P 2765 1655
    """,
}

# 갈대 줄: (점 목록, 간격) — 물가를 따라 간격마다, 줄 양옆으로 번갈아 3 스터드. 깊이가 맞지 않는 점은 건너뛴다
REEDS = [
    ([(1775, 870), (1770, 940), (1780, 1010)], 12),        # 북쪽 못 서쪽 물가
    ([(1950, 870), (1952, 960), (1948, 1040)], 12),        # 북쪽 못 동쪽 물가
    ([(2090, 1210), (2092, 1300), (2085, 1390)], 12),      # 남쪽 못 동쪽 물가
    ([(1928, 1190), (1925, 1300), (1935, 1390)], 12),      # 남쪽 못 서쪽 물가
    ([(2335, 750), (2338, 850)], 11),                      # 마녀 웅덩이 서쪽
    ([(2500, 760), (2505, 830)], 11),                      # 마녀 웅덩이 동쪽
    ([(2555, 680), (2600, 668), (2645, 690)], 10),         # 북동 웅덩이
    ([(1935, 585), (1985, 590)], 10),                      # 북쪽 웅덩이
    ([(3125, 960), (3120, 1040)], 10),                     # 동쪽 웅덩이
    ([(1480, 1225), (1485, 1280)], 10),                    # 서쪽 웅덩이
    ([(2460, 1440), (2550, 1445)], 10),                    # 남동 웅덩이
    ([(1690, 1470), (1640, 1470)], 9),                     # 잠긴 옛 문
    ([(2725, 1250), (2760, 1240)], 9),                     # 사당 남서 못
    ([(2745, 1395), (2830, 1400)], 11),                    # 사당 남서 못 남쪽
    ([(1450, 1100), (1452, 1200)], 12),                    # 서쪽 물길
    ([(1880, 520), (2000, 515)], 12),                      # 북쪽 물길
    ([(3205, 950), (3205, 1100)], 12),                     # 동쪽 물길
]

# 빈 곳 검사에서 일부러 비운 자리(마당·공터): (x, z, 반지름)
CLEARINGS = [
    (1880, 760, 42),    # 북쪽 마당
    (2400, 1062, 42),   # 가운데 언덕 돌무리
    (3062, 772, 30),    # 북동 망루 발치
    (2425, 880, 22),    # 마녀 오두막 둑 끝
    (2640, 1340, 26),   # 사냥꾼 쉼터
    (2010, 1430, 26),   # 나루 뭍 끝
]


def parse_veg(h):
    items = []
    n = 0
    for zone, text in VEG.items():
        for tok in text.replace("\n", "|").split("|"):
            t = tok.split()
            if not t:
                continue
            assert len(t) == 3, (zone, tok)
            k = t[0][0]
            assert k in VKIND, (zone, tok)
            sc = float(t[0][1:]) if len(t[0]) > 1 else VSCALE[k][n % len(VSCALE[k])]
            items.append((VKIND[k], float(t[1]), float(t[2]), VY[k], (n * 137.5) % 360 - 180, sc))
            n += 1
    for pts, gap in REEDS:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            nx, nz = -dz / L, dx / L
            for k in range(int(L // gap) + 1):
                side = 3 if n % 2 else -3
                x, z = p0[0] + dx * k * gap / L + nx * side, p0[1] + dz * k * gap / L + nz * side
                v = sample(h, x, z)
                if np.isnan(v) or not (VH["R"][0] <= v <= VH["R"][1]):
                    continue
                items.append(("Reeds", x, z, VY["R"], (n * 137.5) % 360 - 180, VSCALE["R"][n % 4]))
                n += 1
    return items


VEG_KEY = {v: k for k, v in VKIND.items()}


def check_veg(veg, items, h):
    """나무·풀 규칙: 물 깊이, 길·판자길·건물 비키기, 나무끼리 간격."""
    bad = []
    walks = []
    for pts in WALKS:
        walks += list(zip(pts[:-1], pts[1:]))
    for (top, low) in RAMPS:
        walks.append((top, (top[0] + (low[0] - top[0]) * 1.6, top[1] + (low[1] - top[1]) * 1.6)))
    walks += BRIDGES
    paths = []
    for (pts, hw, _, _) in PATHS:
        paths += [(a, b, hw) for a, b in zip(pts[:-1], pts[1:])]
    solid = [(a, x, z, radius(a, s)) for (a, x, z, y, yaw, s) in items if a not in WALK and a != "BoardwalkRamp"]
    trees = []
    for (a, x, z, y, yaw, s) in veg:
        k = VEG_KEY[a]
        v = sample(h, x, z)
        tag = "%s(%.0f,%.0f)" % (k, x, z)
        if np.isnan(v):
            bad.append("섬 밖 " + tag)
            continue
        lo, hi = VH[k]
        if not (lo <= v <= hi):
            bad.append("깊이 h=%.1f 범위 밖 %s" % (v, tag))
        big = k in "ABCMDL"
        for (p0, p1) in walks:
            d = float(seg_dist(np.array(x), np.array(z), p0, p1))
            if d < (10 if big else 6):
                bad.append("판자길 %.0f %s" % (d, tag))
                break
        for (p0, p1, hw) in paths:
            d = float(seg_dist(np.array(x), np.array(z), p0, p1))
            if d < hw + (5 if big else 1.5) and k not in "RP":
                bad.append("길 %.0f %s" % (d, tag))
                break
        for (b, bx, bz, br) in solid:
            d = math.hypot(x - bx, z - bz)
            if d < br * (0.8 if big else 0.6) + 2:
                bad.append("건물 %s %.0f %s" % (b, d, tag))
                break
        if big:
            r = radius(a, s)
            for (t2, tx, tz, tr) in trees:
                d = math.hypot(x - tx, z - tz)
                if d < 0.38 * (r + tr):
                    bad.append("나무 겹침 %.0f %s - %s(%.0f,%.0f)" % (d, tag, t2, tx, tz))
                    break
            trees.append((k, x, z, r))
    return bad


def find_gaps(allitems, h, out, cover=44):
    """뭍인데 cover 스터드 안에 나무·건물·소품이 하나도 없는 곳(20 스터드 격자). 길 위·일부러 비운 공터는 뺀다."""
    pts = np.array([(x, z) for (a, x, z, y, yaw, s) in allitems if a not in ("Reeds", "LilyPads")])
    paths = []
    for (pts_, hw, _, _) in PATHS:
        paths += [(a, b, hw) for a, b in zip(pts_[:-1], pts_[1:])]
    gaps = []
    edge = dist_to(out) < 18
    for z in range(Z0 + 10, Z0 + NZ * R, 20):
        for x in range(X0 + 10, X0 + NX * R, 20):
            v = sample(h, x, z)
            if np.isnan(v) or v < -0.3 or sample(edge, x, z):
                continue
            if any(float(seg_dist(np.array(x), np.array(z), a, b)) < hw + 4 for a, b, hw in paths):
                continue
            if any(math.hypot(x - cx, z - cz) < cr for cx, cz, cr in CLEARINGS):
                continue
            if len(pts) and np.min((pts[:, 0] - x) ** 2 + (pts[:, 1] - z) ** 2) < cover * cover:
                continue
            gaps.append((x, z))
    return gaps


# 에셋 대략 반지름(겹침 검사용): 매니페스트 경계 x,z 반폭의 평균
def radius(a, s=1.0):
    b = MAN[a]["bounds"]
    return 0.5 * 0.5 * ((b["max"][0] - b["min"][0]) + (b["max"][2] - b["min"][2])) * s


# ─────────────────────────────────────────────────────────────
# 도움 함수
# ─────────────────────────────────────────────────────────────

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def seg_dist(X, Z, p0, p1):
    ax, az = p0
    bx, bz = p1
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / max(L2, 1e-9), 0, 1)
    return np.sqrt((X - ax - t * dx) ** 2 + (Z - az - t * dz) ** 2)


def value_noise(X, Z, scale, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((int((NZ * R) / scale) + 3, int((NX * R) / scale) + 3))
    fx = (X - X0) / scale
    fz = (Z - Z0) / scale
    i = np.floor(fx).astype(int)
    j = np.floor(fz).astype(int)
    tx = fx - i
    tz = fz - j
    tx = tx * tx * (3 - 2 * tx)
    tz = tz * tz * (3 - 2 * tz)
    a = g[j, i] * (1 - tx) + g[j, i + 1] * tx
    b = g[j + 1, i] * (1 - tx) + g[j + 1, i + 1] * tx
    return (a * (1 - tz) + b * tz) * 2 - 1


def blur(A, valid, sigma_cells):
    rad = int(math.ceil(sigma_cells * 3))
    k = np.exp(-0.5 * (np.arange(-rad, rad + 1) / sigma_cells) ** 2)
    W = valid.astype(float)
    V = np.where(valid, A, 0.0)
    for axis in (0, 1):
        nv = np.zeros_like(V)
        nw = np.zeros_like(W)
        for o, kk in zip(range(-rad, rad + 1), k):
            nv += kk * np.roll(V, o, axis=axis)
            nw += kk * np.roll(W, o, axis=axis)
        V, W = nv, nw
    return np.where(valid, V / np.maximum(W, 1e-6), A)


def load_base():
    rows = []
    for k in range(6):
        for line in open(os.path.join(HERE, "swamp", "swamph4_%d.txt" % k)).read().split("\n"):
            if line.strip():
                rows.append([(np.nan if t == "x" else int(t) / 10) for t in line.split()])
    H = np.array(rows)
    assert H.shape == (NZ, NX), H.shape
    return H


def outside_mask(H):
    out = np.zeros(H.shape, bool)
    q = deque()
    for j in range(NZ):
        q.append((j, 0))
        q.append((j, NX - 1))
    for i in range(NX):
        q.append((0, i))
        q.append((NZ - 1, i))
    while q:
        j, i = q.popleft()
        if 0 <= j < NZ and 0 <= i < NX and not out[j, i] and np.isnan(H[j, i]):
            out[j, i] = True
            q.extend(((j + 1, i), (j - 1, i), (j, i + 1), (j, i - 1)))
    return out


def dist_to(mask):
    """mask 칸까지 칸 거리(8방향 근사, 스터드)."""
    d = np.where(mask, 0.0, 1e9)
    for _ in range(12):
        for dj, di, w in ((1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)):
            d = np.minimum(d, np.roll(np.roll(d, dj, 0), di, 1) + w)
    return d * R


# ─────────────────────────────────────────────────────────────
# 지형 만들기
# ─────────────────────────────────────────────────────────────

def build_terrain():
    H = load_base()
    xs = X0 + R * (np.arange(NX) + 0.5)
    zs = Z0 + R * (np.arange(NZ) + 0.5)
    X, Z = np.meshgrid(xs, zs)
    out = outside_mask(H)
    inside = ~out
    holes = np.isnan(H) & inside
    h = np.where(holes, -3.2, H)
    h = np.where(out, 0.0, h)
    # 판 사이 단차를 누그러뜨린다(8 스터드)
    h = blur(h, inside, 2.0)
    # 뭍에 잔 기복(판 무늬를 흐리고 풀섶 둔덕을 만든다)
    land = smoothstep(0.1, 0.6, h)
    h = h + land * (0.30 * value_noise(X, Z, 52, 11) + 0.14 * value_noise(X, Z, 15, 12))
    # 섬 가장자리 둑
    d_out = dist_to(out)
    lev = 1 - smoothstep(LEVEE_W * 0.55, LEVEE_W, d_out)
    h = np.maximum(h, lev * (LEVEE_H + 0.25 * value_noise(X, Z, 20, 13)) + (1 - lev) * h)
    # 젖은 땅
    for (cx, cz, rx, rz, depth) in WET:
        e = np.sqrt(((X - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2) + 0.18 * value_noise(X, Z, 18, int(cx + cz))
        m = 1 - smoothstep(0.75, 1.05, e)
        h = h * (1 - m) + np.minimum(h, depth + 0.25 * value_noise(X, Z, 9, int(cx))) * m
    # 웅덩이
    for (cx, cz, rx, rz, bottom, fe) in PONDS:
        e = np.sqrt(((X - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2)
        m = 1 - smoothstep(1.0, 1.0 + fe / min(rx, rz), e)
        h = h * (1 - m) + np.minimum(h, bottom) * m
    # 둔덕·자리
    for (cx, cz, r, top, fe) in MOUNDS:
        d = np.sqrt((X - cx) ** 2 + (Z - cz) ** 2)
        m = 1 - smoothstep(r, r + fe, d)
        h = h * (1 - m) + top * m
    # 길
    path_mat = np.full(h.shape, -1)
    for (pts, hw, hmin, mat) in PATHS:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            d = seg_dist(X, Z, p0, p1)
            m = 1 - smoothstep(hw, hw + 5, d)
            h = np.maximum(h, h * (1 - m) + np.maximum(h, hmin) * m)
            core = d < hw * 0.85 + 0.6 * value_noise(X, Z, 6, 21)
            path_mat[core] = M[mat]
    h = np.where(out, np.nan, h)
    # 재질
    sl = np.zeros_like(h)
    gz, gx = np.gradient(np.where(out, 0, h), R)
    sl = np.sqrt(gx * gx + gz * gz)
    n = 0.35 * value_noise(X, Z, 24, 31)
    hv = h + n
    mat = np.full(h.shape, M["Mud"])
    mat[hv >= 0.3] = M["Ground"]
    mat[hv >= 0.62] = M["LeafyGrass"]
    mat[hv >= 3.5] = M["Grass"]
    mat[(sl > 0.55) & (h > 1.5)] = M["Rock"]
    mat[path_mat >= 0] = path_mat[path_mat >= 0]
    # 사당 마당 둘레 돌바닥 얼룩
    d = np.sqrt((X - 2940) ** 2 + (Z - 1190) ** 2)
    mat[(d > 60) & (d < 78) & (h > 0.3) & (value_noise(X, Z, 10, 41) > 0.1)] = M["Slate"]
    return X, Z, h, mat, out


def encode(h, mat, out):
    lines = ["%d %d %d %d %d %g" % (X0, Z0, R, NX, NZ, WATER)]
    q = np.clip(np.round((np.nan_to_num(h, nan=-64) + 64) * 10), 0, 4095).astype(int)
    q[out] = 0
    for j in range(NZ):
        lines.append("".join(ALPHA[v >> 6] + ALPHA[v & 63] for v in q[j]))
    for j in range(NZ):
        row = mat[j]
        runs = []
        i = 0
        while i < NX:
            v = int(row[i])
            k = 1
            while i + k < NX and int(row[i + k]) == v and k < 64:
                k += 1
            runs.append(ALPHA[v] + ALPHA[k - 1])
            i += k
        lines.append("".join(runs))
    return "\n".join(lines) + "\n"


# ─────────────────────────────────────────────────────────────
# 배치 펼치기
# ─────────────────────────────────────────────────────────────

def yaw_of(dx, dz):
    return math.degrees(math.atan2(-dz, dx))


def expand():
    items = []
    for pts in WALKS:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            n = max(1, math.ceil((L - 1.0) / 16.0))
            for k in range(n):
                t = (k + 0.5) / n
                a = "BoardwalkStraightB" if (len(items) % 5 == 3) else "BoardwalkStraight"
                items.append((a, p0[0] + dx * t, p0[1] + dz * t, 0, yaw_of(dx, dz), 1))
    for (x, z) in JUNCTIONS:
        items.append(("BoardwalkJunction", x, z, 0, 0, 1))
    for (top, low) in RAMPS:
        dx, dz = low[0] - top[0], low[1] - top[1]
        L = math.hypot(dx, dz)
        items.append(("BoardwalkRamp", top[0] + dx / L * 8, top[1] + dz / L * 8, 0, yaw_of(dx, dz), 1))
    for (p0, p1) in BRIDGES:
        items.append(("RopeBridge", (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 0, yaw_of(p1[0] - p0[0], p1[1] - p0[1]), 1))
    return items + list(PLACE)


def sample(h, x, z):
    i = int((x - X0) // R)
    j = int((z - Z0) // R)
    if 0 <= i < NX and 0 <= j < NZ:
        return h[j, i]
    return np.nan


STILT = {"Longhouse", "StiltHouseA", "StiltHouseB", "StiltHutC", "WitchHut", "DeckPlatform", "FerryDock", "MireShrine"}
WALK = {"BoardwalkStraight", "BoardwalkStraightB", "BoardwalkJunction", "RopeBridge"}
SMALL = {"LampPost", "TorchPost", "Bench", "Signpost", "NoticeBoard", "MarketStallA", "MarketStallB", "FishRack", "Rowboat"}


def check(items, h):
    bad = []
    for (a, x, z, y, yaw, s) in items:
        v = sample(h, x, z)
        if np.isnan(v):
            bad.append("섬 밖: %s (%.0f, %.0f)" % (a, x, z))
            continue
        if a in WALK and v > -0.6:
            bad.append("판자길 밑이 뭍: %s (%.0f, %.0f) h=%.1f" % (a, x, z, v))
        if a in STILT and y == 0 and a != "FerryDock" and v > -0.6:
            bad.append("물 위 집 밑이 뭍: %s (%.0f, %.0f) h=%.1f" % (a, x, z, v))
        if isinstance(y, str) and y.startswith("g") and v < 0.15 and a not in ("RuinPillar", "RuinArch"):
            bad.append("뭍 물건이 물에: %s (%.0f, %.0f) h=%.1f" % (a, x, z, v))
        if a == "Rowboat" and v > -0.6:
            bad.append("배 밑이 뭍: (%.0f, %.0f) h=%.1f" % (x, z, v))
    # 겹침: 건물·소품끼리(판자길 제외, 같은 판 위 소품 제외)
    big = [(a, x, z, y, radius(a, s)) for (a, x, z, y, yaw, s) in items if a not in WALK and a != "BoardwalkRamp"]
    for i in range(len(big)):
        for k in range(i + 1, len(big)):
            a, x, z, y, r = big[i]
            b, x2, z2, y2, r2 = big[k]
            if y == DECK or y2 == DECK or {a, b} & {"DeckPlatform"}:
                continue
            if a in SMALL and b in SMALL:
                need = 0.5 * (r + r2)
            elif a in SMALL or b in SMALL:
                need = 0.75 * (r + r2)
            else:
                need = 0.85 * (r + r2)
            dd = math.hypot(x - x2, z - z2)
            if dd < need:
                bad.append("겹침 %.0f<%.0f: %s(%.0f,%.0f) - %s(%.0f,%.0f)" % (dd, need, a, x, z, b, x2, z2))
    return bad


# ─────────────────────────────────────────────────────────────
# 평면도
# ─────────────────────────────────────────────────────────────

MCOL = {"Mud": (74, 64, 48), "Ground": (106, 92, 62), "LeafyGrass": (98, 118, 62), "Grass": (112, 136, 70), "Rock": (110, 108, 100),
        "Pebble": (150, 146, 128), "Slate": (88, 92, 96), "Cobblestone": (130, 124, 112), "Sand": (180, 170, 130)}
ACOL = {"tree": (30, 70, 30), "walk": (200, 160, 100), "house": (230, 110, 60), "prop": (250, 230, 90), "ruin": (200, 200, 210)}


def kind(a):
    if a in WALK or a == "BoardwalkRamp":
        return "walk"
    if a in STILT or a in ("Watchtower",):
        return "house"
    if a.startswith("Ruin") or a == "Well":
        return "ruin"
    if a in ("CypressA", "CypressB", "CypressC", "Mangrove", "DeadTree", "BroadleafTree"):
        return "tree"
    return "prop"


def render(h, mat, out, items, path, S=2, crop=None, gaps=()):
    """crop=(x0, x1, z0, z1) 이면 그 범위만(격자 50 스터드), 아니면 섬 전체(격자 100). gaps 는 빨간 점."""
    img = np.zeros((NZ * S, NX * S, 3), np.uint8)
    base = np.zeros((NZ, NX, 3), np.uint8)
    for name, c in MCOL.items():
        base[mat == M[name]] = c
    wet = (h < WATER) & ~out
    depth = np.clip(-np.nan_to_num(h[wet]), 0, 3) / 3
    base[wet] = (np.array([60, 84, 70])[None, :] * (1 - depth[:, None]) + np.array([28, 44, 40])[None, :] * depth[:, None]).astype(np.uint8)
    base[out] = (14, 16, 24)
    img[:] = np.repeat(np.repeat(base, S, 0), S, 1)
    step = 50 if crop else 100
    for x in range(1400, 3330, step):
        img[::3, (x - X0) * S // R] = (220, 220, 220) if x % 100 == 0 else (120, 120, 120)
    for z in range(500, 1700, step):
        img[(z - Z0) * S // R, ::3] = (220, 220, 220) if z % 100 == 0 else (120, 120, 120)
    for (a, x, z, y, yaw, s) in items:
        r = radius(a, s)
        c = ACOL[kind(a)]
        px, pz = (x - X0) * S / R, (z - Z0) * S / R
        rr = max(1.0, r * S / R)
        y0, y1 = int(pz - rr), int(pz + rr) + 1
        x0, x1 = int(px - rr), int(px + rr) + 1
        for yy in range(max(0, y0), min(img.shape[0], y1)):
            for xx in range(max(0, x0), min(img.shape[1], x1)):
                d2 = (xx - px) ** 2 + (yy - pz) ** 2
                if kind(a) == "tree":
                    if d2 <= rr * rr and (d2 >= (rr - 1.2) ** 2 or kind(a) == "tree"):
                        img[yy, xx] = (img[yy, xx] * 0.45 + np.array(c) * 0.55).astype(np.uint8)
                elif d2 <= rr * rr:
                    img[yy, xx] = c
    for (x, z) in gaps:
        px, pz = int((x - X0) * S / R), int((z - Z0) * S / R)
        img[max(0, pz - 2):pz + 3, max(0, px - 2):px + 3] = (255, 40, 40)
    if crop:
        x0, x1, z0, z1 = crop
        img = img[(z0 - Z0) * S // R:(z1 - Z0) * S // R, (x0 - X0) * S // R:(x1 - X0) * S // R]
    write_png(path, img)


FX_NAMES = {"Fire", "Flame", "Smoke", "Cauldron", "SignA", "SignB", "SignC", "Sign", "Board"}
NOTICE = "【늪 마을 알림】\n해가 지면 둑길 밖으로 나가지 마시오.\n사당 쪽 초록 불빛을 따라가지 마시오.\n마녀 할멈 웅덩이에선 목소리를 낮출 것.\n\n— 촌장"
TEXTS = {
    "Signpost": {"SignA": "늪 마을", "SignB": "마녀의 웅덩이", "SignC": "늪의 사당"},
    "Longhouse": {"Sign": "늪개구리 주점"},
    "FerryDock": {"Sign": "늪 마을 나루"},
    "NoticeBoard": {"Board": NOTICE},
}


def category(a):
    k = kind(a)
    return {"walk": "판자길", "house": "건물", "ruin": "유적", "tree": "나무"}.get(k, "소품")


def write_texts(items):
    """place.txt: 에셋 x z 높이 방향 크기 분류 (탭), fx.txt: 에셋 표지 자리(3) 회전(9) 폭 높이 색 글(줄바꿈은 \n)."""
    L = []
    for (a, x, z, y, yaw, s) in items:
        ys = y if isinstance(y, str) else "%g" % round(y, 2)
        L.append("\t".join([a, "%g" % round(x, 2), "%g" % round(z, 2), ys, "%g" % round(yaw, 2), "%g" % s, category(a)]))
    open(os.path.join(HERE, "swamp", "place.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    F = []
    for a in sorted({it[0] for it in items}):
        for mk in MAN[a].get("markers", []):
            if mk["name"] not in FX_NAMES:
                continue
            at = mk.get("attrs", {})
            text = TEXTS.get(a, {}).get(mk["name"], at.get("text", ""))
            if (mk["name"].startswith("Sign") or mk["name"] == "Board") and not text:
                continue
            F.append("\t".join([a, mk["name"], " ".join("%g" % round(v, 4) for v in mk["pos"]),
                                " ".join("%g" % round(v, 5) for v in mk["rot"]), "%g" % at.get("width", 4),
                                "%g" % at.get("height", 1), at.get("color", ""), text.replace("\n", "\\n")]))
    open(os.path.join(HERE, "swamp", "fx.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(F) + "\n")


def main():
    X, Z, h, mat, out = build_terrain()
    items = expand()
    veg = parse_veg(h)
    bad = check(items, h) + check_veg(veg, items, h)
    allitems = items + veg
    gaps = find_gaps(allitems, h, out)
    if len(sys.argv) > 1 and sys.argv[1] == "crop":
        x0, x1, z0, z1 = map(int, sys.argv[2:6])
        S = int(sys.argv[6]) if len(sys.argv) > 6 else 5
        render(h, mat, out, allitems, os.path.join(HERE, "swamp", "crop.png"), S, (x0, x1, z0, z1), gaps)
        print("crop %d..%d x %d..%d, 격자 50" % (x0, x1, z0, z1))
    else:
        open(os.path.join(HERE, "swamp", "terrain.txt"), "w", newline="\n").write(encode(h, mat, out))
        render(h, mat, out, allitems, os.path.join(HERE, "swamp", "plan.png"), 2, None, gaps)
        write_texts(allitems)
    cnt = {}
    for it in allitems:
        cnt[it[0]] = cnt.get(it[0], 0) + 1
    print("배치 %d  %s" % (len(allitems), dict(sorted(cnt.items()))))
    land = ~out
    print("지형 칸 %d, 물 칸 %d (%.0f%%), 높이 %.1f..%.1f" % (land.sum(), (h[land] < WATER).sum(), 100 * (h[land] < WATER).mean(),
                                                         np.nanmin(h), np.nanmax(h)))
    print("빈 곳 %d" % len(gaps))
    print("검사 %d" % len(bad))
    for b in bad:
        print("  " + b)


if __name__ == "__main__":
    main()
