# -*- coding: utf-8 -*-
"""
swamp2_plan.py — 늪지대 2판(맵 양식) 배치표. (2026-09-28)

1판(swamp_plan.py)은 매끈한 지형과 안개늪 나무를 써서 다른 섬들과 딴판이었다(사용자 지적). 2판:
- 땅: 원래 흙 판(Gs) 모자이크 그대로. 섬 안 구멍은 같은 모양 판으로 메우고(FILLS),
      낮은 판(물길) 위에 판 모양 그대로 블록 물을 얹는다(WATER = -0.4).
- 길: 뭍은 숲 섬 길처럼 흙 블록 띠(PATHS2), 물 위는 판자길·징검돌(STONES)·돌둑(CAUSEWAY).
- 나무·풀: swamp_flora.py 의 Part 블록 틀(1판 VEG 자리를 옮겨 씀).
- 건물: 안개늪 건물을 쓰되 마을 배치는 새로(물길 따라 판자길 거리, 집 입구 앞은 난간 없는 BoardwalkOpen).
  StiltHouseB 는 계단을 눕힌 StiltHouseB2 로 바꿨다.

돌리는 법(블렌더 딸린 파이썬: numpy):
  python tools/swamp2_plan.py            → swamp/ground2.txt, place2.txt, fx2.txt, plan2.png + 검사
  python tools/swamp2_plan.py crop x0 x1 z0 z1 [S]   → swamp/crop2.png
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "swamp"))
sys.path.insert(0, HERE)
from pngw import write_png  # noqa: E402
import swamp_plan as V1  # noqa: E402  (1판 나무 자리표·도움 함수)

X0, Z0, X1, Z1 = 1384, 452, 3328, 1700
WATER = -0.4
DECK = WATER + 7.0
V1.MAN.update(json.load(open(os.path.join(HERE, "..", "models", "swamp_ref", "manifest_extra.json"), encoding="utf-8")))
MAN = V1.MAN


# ─────────────────────────────────────────────────────────────
# 흙 판 읽기
# ─────────────────────────────────────────────────────────────

class Slab:
    __slots__ = ("name", "kind", "x", "y", "z", "yaw", "sx", "sy", "sz", "col")

    def __init__(self, t):
        self.name = t[0]
        self.kind = t[0][:2]
        self.x, self.y, self.z, self.yaw = float(t[1]), float(t[2]), float(t[3]), float(t[4])
        self.sx, self.sy, self.sz = float(t[5]), float(t[6]), float(t[7])
        self.col = (int(t[8]), int(t[9]), int(t[10]))

    @property
    def top(self):
        return self.y + self.sy / 2


def load_slabs():
    out = []
    for line in open(os.path.join(HERE, "swamp", "slabs.txt"), encoding="utf-8").read().split("\n"):
        if line.strip():
            out.append(Slab(line.split()))
    return out


def rect_mask(XX, ZZ, x, z, yaw, sx, sz):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    dx, dz = XX - x, ZZ - z
    u = dx * c - dz * s
    v = dx * s + dz * c
    return (np.abs(u) <= sx / 2) & (np.abs(v) <= sz / 2)


def top_grid(slabs, extra=(), R=4):
    """4 스터드 칸마다 가장 높은 윗면. extra = [(x, z, yaw, sx, sz, top)] (메움 판)."""
    nx, nz = (X1 - X0) // R, (Z1 - Z0) // R
    H = np.full((nz, nx), np.nan)
    xs = X0 + R * (np.arange(nx) + 0.5)
    zs = Z0 + R * (np.arange(nz) + 0.5)
    XX, ZZ = np.meshgrid(xs, zs)
    rects = [(s.x, s.z, s.yaw, s.sx, s.sz, s.top) for s in slabs if s.kind == "Gs"] + list(extra)
    for (x, z, yaw, sx, sz, top) in rects:
        m = rect_mask(XX, ZZ, x, z, yaw, sx, sz)
        upd = m & (np.isnan(H) | (H < top))
        H[upd] = top
    return H


def T(H, x, z):
    i = int((x - X0) // 4)
    j = int((z - Z0) // 4)
    if 0 <= i < H.shape[1] and 0 <= j < H.shape[0]:
        return H[j, i]
    return np.nan


# ─────────────────────────────────────────────────────────────
# 땅 표
# ─────────────────────────────────────────────────────────────

# 섬 안 구멍 메움 판: (x, z, yaw, 너비, 깊이, 윗면) — 원래 낮은 판(-2.7)보다 조금 낮게 두어 겹친 면이 안 떨린다
FILLS = [
    (1856, 925, 10, 80, 80, -2.80),
    (1856, 1003, 25, 80, 80, -2.84),
    (1860, 1062, 5, 80, 64, -2.88),
    (1990, 1150, 0, 40, 36, -2.80),
    (2006, 1200, 15, 80, 80, -2.84),
    (2004, 1282, 40, 80, 80, -2.80),
    (2010, 1340, 8, 70, 60, -2.88),
    (2412, 802, 0, 84, 50, -2.80),
    (2944, 1200, 20, 90, 84, -2.84),
    (2876, 1190, 5, 30, 30, -2.88),
    (2944, 1262, 0, 44, 36, -2.80),
    (2806, 1330, 12, 96, 90, -2.84),
    (1548, 750, 0, 20, 20, -2.80),
    (2484, 1656, 0, 16, 16, -2.80),
    # 큰 메움 판 가장자리에 남은 틈
    (1890, 884, 0, 14, 14, -2.92),
    (1888, 974, 0, 22, 32, -2.92),
    (1820, 968, 0, 14, 14, -2.92),
    (1888, 1096, 0, 14, 14, -2.92),
    (2940, 1144, 0, 12, 12, -2.92),
    (2992, 1196, 0, 16, 18, -2.92),
    (2896, 1202, 0, 12, 16, -2.92),
    (2031, 1247, 0, 34, 38, -2.92),
    (1976, 1244, 0, 12, 18, -2.92),
    (1975, 1310, 0, 14, 16, -2.92),
    (2848, 1370, 0, 12, 10, -2.92),
]

# 뭍 흙길 띠: (점 목록, 폭) — 숲 섬 길(For_PathW: Ground 두께 3.3)과 같은 짜임
PATHS2 = [
    ([(1872, 826), (1872, 760), (1900, 700)], 8),                                   # 마을 북쪽 비탈 → 마당
    ([(1961, 880), (2060, 890), (2180, 905), (2300, 900), (2425, 868)], 9),         # 마을 동쪽 → 마녀 웅덩이 물가
    ([(2425, 868), (2418, 960), (2402, 1030)], 8),                                  # 마녀 → 언덕 돌무리
    ([(2112, 1170), (2200, 1232), (2320, 1252), (2450, 1246), (2560, 1282), (2642, 1322), (2712, 1310)], 9),  # 흔들다리 → 사당 둑
    ([(2425, 868), (2510, 902), (2620, 852), (2800, 822), (2950, 800), (3050, 782)], 8),   # 마녀 → 북동 망루
    ([(1774, 1050), (1650, 1062), (1520, 1060), (1512, 1064)], 8),                  # 마을 서쪽 → 서쪽 어부 오두막
    ([(2010, 1426), (1900, 1470), (1800, 1480), (1722, 1470)], 8),                  # 나루 → 남서 잠긴 문(물가까지)
    ([(2700, 656), (2708, 760), (2716, 832)], 7),                                   # 나무꾼 집 → 북동 길
]

# 징검돌: (점 목록, 간격) — 물 위 수면 +0.45
STONES = [
    ([(2425, 830), (2425, 862)], 6.5),       # 마녀 오두막 계단 발치 → 물가
]

# 돌둑(사당 가는 둑길): (점 목록, 폭) — 물 위 수면 +0.8, 조각마다 조금씩 비틀림
CAUSEWAY = [
    ([(2712, 1310), (2780, 1300), (2850, 1268), (2906, 1224)], 9),
]

# ─────────────────────────────────────────────────────────────
# 마을(새 배치): 물길 따라 판자길 거리. 좌표는 판자길 가운데 줄
# ─────────────────────────────────────────────────────────────
WALKS2 = [
    [(1872, 842), (1872, 880)],
    [(1872, 880), (1872, 1050)],
    [(1872, 1050), (1872, 1142)],
    [(1872, 1142), (2008, 1142)],
    [(2008, 1142), (2008, 1170)],
    [(2008, 1170), (2008, 1336)],
    [(1872, 880), (1945, 880)],            # 북동 나들목
    [(1872, 1050), (1790, 1050)],          # 서쪽 나들목
    [(2008, 1170), (2060, 1170)],          # 동쪽 흔들다리 앞
]
JUNCTIONS2 = [(1872, 880), (1872, 1050), (1872, 1142), (2008, 1142), (2008, 1170)]
RAMPS2 = [((1872, 842), (1872, 826)), ((1945, 880), (1961, 880)), ((1790, 1050), (1774, 1050)), ((2096, 1170), (2112, 1170))]
BRIDGES2 = [((2060, 1170), (2096, 1170))]

# 건물·소품: (에셋, x, z, 높이, 방향, 크기)  높이: 숫자 그대로 / "g" 땅에 광선(+더하기) / "w" 수면 / "d" 판자 위
PLACE2 = [
    # ── 북쪽 거리(판자길 x 1872): 서쪽 집은 동쪽을, 동쪽 집은 서쪽을 본다
    ("StiltHouseA", 1857, 897, "w", 90, 1),
    ("StiltHouseB2", 1886, 928, "w", -90, 1),
    ("StiltHutC", 1859, 965, "w", 90, 1),
    ("StiltHouseA", 1887, 995, "w", -90, 1),
    ("StiltHouseB2", 1858, 1030, "w", 90, 1),
    # ── 목(가장 넓은 물): 주점과 장터
    ("Longhouse", 1942, 1120, "w", 0, 1),
    ("DeckPlatform", 1925, 1158, "w", 0, 1),
    ("DeckPlatform", 1951, 1158, "w", 0, 1),
    ("MarketStallA", 1925, 1161, "d", 180, 1),
    ("MarketStallB", 1951, 1161, "d", 180, 1),
    ("NoticeBoard", 1938, 1167, "d", 180, 1),
    ("Bench", 1944, 1151, "d", 0, 1),
    ("Rowboat", 1960, 1086, "w", 80, 1),
    ("Rowboat", 1835, 1102, "w", 10, 1),
    # ── 남쪽 거리(판자길 x 2008)
    ("StiltHouseA", 1993, 1190, "w", 90, 1),
    ("StiltHouseB2", 2022, 1210, "w", -90, 1),
    ("StiltHutC", 1995, 1232, "w", 90, 1),
    ("StiltHouseA", 2023, 1250, "w", -90, 1),
    ("StiltHouseB2", 1994, 1272, "w", 90, 1),
    ("StiltHutC", 2021, 1290, "w", -90, 1),
    ("FerryDock", 2010, 1395, "w", -90, 1),
    ("Rowboat", 1984, 1362, "w", 10, 1),
    ("Rowboat", 2040, 1364, "w", -15, 1),
    ("LampPost", 1999, 1432, "g", 0, 1),
    ("LampPost", 2021, 1432, "g", 0, 1),
    # ── 서쪽 갯벌 어부 오두막
    ("StiltHutC", 1748, 990, WATER, 90, 1),     # 갯벌 위(기둥이 진흙에 박힘)
    ("FishRack", 1728, 1018, "g", 0, 1),
    ("Rowboat", 1782, 1080, "w", 30, 1),
    # ── 북쪽 마당
    ("Watchtower", 1992, 800, "g-0.4", -75, 1),
    ("Signpost", 1892, 800, "g", 90, 1),
    ("TorchPost", 1862, 816, "g", 0, 1),
    ("TorchPost", 1882, 816, "g", 0, 1),
    ("Campfire", 1918, 760, "g", 0, 1),
    ("Bench", 1918, 748, "g", 180, 1),
    ("CargoPile", 1836, 744, "g", -70, 1),
    ("CargoPile", 1896, 722, "g", 15, 1),
    ("Well", 1812, 722, "g", 0, 1),
    # ── 마녀 오두막(웅덩이 한가운데, 징검돌로 건넘)
    ("WitchHut", 2425, 805, "w", 0, 1),
    ("TorchPost", 2417, 870, "g", 0, 1),
    ("TorchPost", 2433, 870, "g", 0, 1),
    # ── 가운데 언덕 돌무리
    ("Well", 2400, 1062, "g", 0, 1),
    ("RuinArch", 2402, 1036, "g-0.3", 0, 1.2),
    ("RuinPillar", 2426, 1045, "g-0.3", 50, 1.2),
    ("RuinPillar", 2428, 1076, "g-0.3", 110, 1.2),
    ("RuinPillar", 2405, 1091, "g-0.3", 170, 1.2),
    ("RuinPillar", 2376, 1080, "g-0.3", 230, 1.2),
    ("RuinPillar", 2372, 1049, "g-0.3", 290, 1.2),
    # ── 늪의 사당(해자 가운데) + 돌둑 횃불·부서진 유적
    ("MireShrine", 2940, 1190, "w", -45, 1),
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
    # ── 서쪽 둘레 물길 어부 오두막
    ("StiltHutC", 1428, 1075, "w", 90, 1),
    ("FishRack", 1500, 1084, "g", 90, 1),
    ("Rowboat", 1420, 1112, "w", 5, 1),
    # ── 사냥꾼 쉼터
    ("Campfire", 2640, 1344, "g", 0, 1),
    ("CargoPile", 2618, 1360, "g", 30, 1),
    ("Bench", 2660, 1356, "g", -60, 1),
    ("TorchPost", 2632, 1318, "g", 0, 1),
    # ── 남서 잠긴 옛 문
    ("RuinArch", 1672, 1520, "g-0.3", -79.6, 1.3),
    ("RuinPillar", 1668, 1486, "g-0.4", 20, 1.3),
    ("RuinPillar", 1705, 1540, "g-0.4", 60, 1.15),
    # ── 나무꾼 집(계단 눕힌 B2, 뭍에 기둥을 묻음). 울타리는 옆 한 줄만, 앞마당은 트임
    ("StiltHouseB2", 2700, 630, "g-7", 0, 1),
    ("Well", 2736, 690, "g", 0, 1),
    ("Fence", 2656, 668, "g", 90, 1),
    ("Fence", 2656, 681, "g", 90, 1),
    ("Fence", 2656, 694, "g", 90, 1),
    ("CargoPile", 2745, 650, "g", 90, 1),
    ("FallenLog", 2748, 712, "g", 5, 0.9),
    ("LampPost", 2716, 668, "g", 0, 1),
    ("Bench", 2684, 672, "g", 180, 1),
    # ── 동쪽 물길 난파선
    ("Shipwreck", 3242, 1180, WATER - 1.1, 8, 1),
]

# 판자길 앞에 입구가 오는 곳(난간 없는 판을 깐다): 에셋별 입구 로컬 (x, z)
DOORS = {
    "StiltHouseA": [(0, 11.8)],
    "StiltHouseB2": [(0, 10.8), (10.3, 10.8)],       # 문 + 바깥 계단 발치
    "StiltHutC": [(3.3, 9.8)],
    "Longhouse": [(0, 18.3)],
    "DeckPlatform": [(0, -12.9)],                    # 장터 마루 앞(북쪽)
}

WALKSEGS = [seg for pts in WALKS2 for seg in zip(pts[:-1], pts[1:])] +     [(t, (t[0] + (l[0] - t[0]) * 1.6, t[1] + (l[1] - t[1]) * 1.6)) for (t, l) in RAMPS2] + list(BRIDGES2)

# 빈 곳 검사에서 일부러 비운 자리
CLEARINGS2 = [(1880, 760, 42), (2400, 1062, 42), (3062, 772, 30), (2425, 880, 22), (2640, 1340, 26), (2010, 1432, 26), (2710, 680, 40)]

# ─────────────────────────────────────────────────────────────
# 나무·풀: 1판 자리표(VEG·REEDS)를 그대로 옮겨 쓰고, 글자를 블록 틀로 바꾼다
# ─────────────────────────────────────────────────────────────
FLORA_OF = {"A": ("Cyp_A", "Cyp_D"), "B": ("Cyp_B",), "C": ("Cyp_C",), "M": ("Man_A", "Man_B"), "D": ("Dead_A", "Dead_B"),
            "L": ("Brd_A", "Brd_B"), "S": ("Bush_A", "Bush_B", "Bush_C"), "R": ("Reed_A", "Reed_B"), "P": ("Lily_A", "Lily_B"),
            "F": ("Log_A",), "G": ("Shroom_A",)}
FLORA_R = {"Cyp": 19, "Man": 14, "Dead": 9, "Brd": 11, "Bush": 3.5, "Reed": 3, "Lily": 5, "Log": 9, "Shroom": 2}
# 2판에서 자리를 바꾸거나 뺀 것: 1판 좌표 → 새 좌표(None 이면 뺌)
VEG_MOVE = {(1965, 1170): (1945, 1196)}
# 2판에서 종을 바꾼 것(흙 판 위에선 물이 깊은 자리): 1판 좌표 → 글자
VEG_KIND = {(3160, 700): "M"}
VEG_ADD = """
    C 1748 748 | B 1772 790 | S 1740 785 | A 1812 850
    B 1908 1232 | A 1822 1282 | C 1826 1382 | S 1930 1300 | S 1915 1345 | B 1994 1495
    B 2572 840 | S 2560 868 | A 2545 705 | L 2688 745 | B 2045 630 | C 2165 925 | A 2985 640 | B 3095 990
    M 1462 1135 | S 1634 1042 | S 1734 1070 | S 2214 1222 | S 2214 1342 | S 2454 1262 | S 2514 1282
    S 2774 1402 | S 2894 1082 | S 3074 1262 | S 3214 1242
"""


def flora_list(H):
    out = []
    n = 0
    for zone, text in V1.VEG.items():
        for tok in text.replace("\n", "|").split("|"):
            t = tok.split()
            if not t:
                continue
            k = t[0][0]
            sc = float(t[0][1:]) if len(t[0]) > 1 else V1.VSCALE[k][n % len(V1.VSCALE[k])]
            x, z = float(t[1]), float(t[2])
            if (x, z) in VEG_MOVE:
                m = VEG_MOVE[(x, z)]
                if m is None:
                    n += 1
                    continue
                x, z = m
            k = VEG_KIND.get((float(t[1]), float(t[2])), k)
            names = FLORA_OF[k]
            out.append((names[n % len(names)], x, z, k, (n * 137.5) % 360 - 180, sc))
            n += 1
    for tok in VEG_ADD.replace("\n", "|").split("|"):
        t = tok.split()
        if not t:
            continue
        k = t[0][0]
        sc = float(t[0][1:]) if len(t[0]) > 1 else V1.VSCALE[k][n % len(V1.VSCALE[k])]
        names = FLORA_OF[k]
        out.append((names[n % len(names)], float(t[1]), float(t[2]), k, (n * 137.5) % 360 - 180, sc))
        n += 1
    for pts, gap in V1.REEDS:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            nx, nz = -dz / L, dx / L
            for kk in range(int(L // gap) + 1):
                side = 3 if n % 2 else -3
                x, z = p0[0] + dx * kk * gap / L + nx * side, p0[1] + dz * kk * gap / L + nz * side
                v = T(H, x, z)
                if np.isnan(v) or v > WATER + 1.0:
                    continue
                if any(float(V1.seg_dist(np.array(x), np.array(z), a, b)) < 6 for a, b in WALKSEGS):
                    continue
                out.append((("Reed_A", "Reed_B")[n % 2], x, z, "R", (n * 137.5) % 360 - 180, V1.VSCALE["R"][n % 4]))
                n += 1
    return out


# ─────────────────────────────────────────────────────────────
# 펼치기
# ─────────────────────────────────────────────────────────────

def yaw_of(dx, dz):
    return math.degrees(math.atan2(-dz, dx))


def local_to_world(x, z, yaw, lx, lz, s=1.0):
    """로블록스 yaw: 로컬 X → (cos, -sin), 로컬 Z → (sin, cos)."""
    c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return x + (lx * c + lz * sn) * s, z + (-lx * sn + lz * c) * s


def door_points():
    pts = []
    for (a, x, z, y, yaw, s) in PLACE2:
        for (lx, lz) in DOORS.get(a, []):
            pts.append(local_to_world(x, z, yaw, lx, lz, s))
    return pts


def expand_walks():
    doors = door_points()
    items = []
    for pts in WALKS2:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            n = max(1, math.ceil((L - 1.0) / 16.0))
            ux, uz = dx / L, dz / L
            for k in range(n):
                t = (k + 0.5) / n
                cx, cz = p0[0] + dx * t, p0[1] + dz * t
                open_ = False
                for (qx, qz) in doors:
                    along = (qx - cx) * ux + (qz - cz) * uz
                    side = abs((qx - cx) * uz - (qz - cz) * ux)
                    if abs(along) < L / n / 2 + 4.0 and side < 7.0:
                        open_ = True
                items.append(("BoardwalkOpen" if open_ else "BoardwalkStraight", cx, cz, "w", yaw_of(dx, dz), 1))
    for (x, z) in JUNCTIONS2:
        items.append(("BoardwalkJunction", x, z, "w", 0, 1))
    for (top, low) in RAMPS2:
        dx, dz = low[0] - top[0], low[1] - top[1]
        L = math.hypot(dx, dz)
        items.append(("BoardwalkRamp", top[0] + dx / L * 8, top[1] + dz / L * 8, "w", yaw_of(dx, dz), 1))
    for (p0, p1) in BRIDGES2:
        items.append(("RopeBridge", (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, "w", yaw_of(p1[0] - p0[0], p1[1] - p0[1]), 1))
    return items


def ground_parts(slabs, H):
    """(분류, 이름, 재질, 색, x, y, z, yaw, sx, sy, sz, 투명, 반사, 충돌)"""
    G = []
    # 메움 판 + 밑 바위
    for i, (x, z, yaw, sx, sz, top) in enumerate(FILLS):
        G.append(("땅", "Fill_%d" % i, "Mud", (62, 60, 44), x, top - 2.35, z, yaw, sx, 4.7, sz, 0, 0, True))
        G.append(("땅", "FillRock_%d" % i, "Rock", (77, 72, 66), x, top - 4.7 - 10, z, yaw, sx * 0.94, 20, sz * 0.94, 0, 0, True))
    # 물: 낮은 판(원래 + 메움) 모양 그대로. 겹치는 판끼리 높이를 조금씩 달리해 겹친 면이 떨리지 않게(탐욕 색칠)
    lows = [(s.x, s.z, s.yaw, s.sx, s.sz, s.top) for s in slabs if s.kind == "Gs" and s.top < WATER - 0.2]
    lows += [(x, z, yaw, sx, sz, top) for (x, z, yaw, sx, sz, top) in FILLS]
    level = []
    for i, a in enumerate(lows):
        used = {level[j] for j in range(i) if math.hypot(a[0] - lows[j][0], a[1] - lows[j][1]) < (max(a[3], a[4]) + max(lows[j][3], lows[j][4])) * 0.72}
        k = 0
        while k in used:
            k += 1
        level.append(k)
    WC = [(54, 74, 58), (50, 70, 55), (58, 78, 60), (52, 72, 52)]
    for i, (x, z, yaw, sx, sz, top) in enumerate(lows):
        wt = WATER + 0.018 * level[i]
        G.append(("물", "Water_%d" % i, "SmoothPlastic", WC[i % 4], x, (wt + top) / 2, z, yaw, sx + 0.6, wt - top, sz + 0.6, 0.22, 0.08, False))
    # 흙길 띠
    k = 0
    for pts, w in PATHS2:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            n = max(1, math.ceil(L / 22.0))
            for j in range(n):
                a, b = j / n, (j + 1) / n
                cx, cz = p0[0] + dx * (a + b) / 2, p0[1] + dz * (a + b) / 2
                seg = L / n + 2.0
                tops = []
                for t in np.linspace(a, b, 5):
                    for off in (-w / 2, 0, w / 2):
                        px = p0[0] + dx * t - dz / L * off
                        pz = p0[1] + dz * t + dx / L * off
                        tops.append(T(H, px, pz))
                tp = np.nanmax(tops) + 0.3
                col = (96, 80, 58) if k % 2 else (104, 88, 64)
                G.append(("길", "Path_%d" % k, "Ground", col, cx, tp - 1.65, cz, yaw_of(dx, dz) + (2 if k % 2 else -2), seg, 3.3, w, 0, 0, True))
                k += 1
    # 징검돌
    k = 0
    for pts, gap in STONES:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            for j in range(int(L // gap) + 1):
                x, z = p0[0] + dx * j * gap / L, p0[1] + dz * j * gap / L
                bot = T(H, x, z)
                tp = WATER + 0.45
                G.append(("길", "Stone_%d" % k, "Slate", (98, 100, 92) if k % 2 else (88, 90, 84), x, (tp + bot) / 2, z, 20 + 37 * k, 4.6, tp - bot, 4.2, 0, 0, True))
                k += 1
    # 돌둑
    k = 0
    for pts, w in CAUSEWAY:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            dx, dz = p1[0] - p0[0], p1[1] - p0[1]
            L = math.hypot(dx, dz)
            n = max(1, math.ceil(L / 10.0))
            for j in range(n):
                t = (j + 0.5) / n
                x, z = p0[0] + dx * t, p0[1] + dz * t
                bot = min(T(H, x, z), WATER - 1.0)
                tp = WATER + 0.8 + (0.12 if k % 3 == 1 else 0.0)
                col = [(122, 118, 106), (110, 108, 98), (132, 126, 112)][k % 3]
                G.append(("길", "Causeway_%d" % k, "Cobblestone", col, x, (tp + bot) / 2, z, yaw_of(dx, dz) + (3, -2, 1)[k % 3], L / n + 0.8, tp - bot, w, 0, 0, True))
                k += 1
    return G


# ─────────────────────────────────────────────────────────────
# 검사
# ─────────────────────────────────────────────────────────────

def footprint(a, x, z, yaw, s=1.0, pad=0.0):
    b = MAN[a]["bounds"]
    lx0, lx1, lz0, lz1 = b["min"][0] * s - pad, b["max"][0] * s + pad, b["min"][2] * s - pad, b["max"][2] * s + pad
    return [local_to_world(x, z, yaw, u, v) for (u, v) in ((lx0, lz0), (lx1, lz0), (lx1, lz1), (lx0, lz1))]


def poly_overlap(A, B):
    """볼록 사각형 두 개의 겹침 깊이(분리축). 0 이하면 안 겹침."""
    best = 1e9
    for poly in (A, B):
        for i in range(4):
            ax, az = poly[i]
            bx, bz = poly[(i + 1) % 4]
            nx, nz = -(bz - az), bx - ax
            L = math.hypot(nx, nz)
            nx, nz = nx / L, nz / L
            pa = [px * nx + pz * nz for px, pz in A]
            pb = [px * nx + pz * nz for px, pz in B]
            o = min(max(pa), max(pb)) - max(min(pa), min(pb))
            best = min(best, o)
    return best


BIG = {"Longhouse", "StiltHouseA", "StiltHouseB2", "StiltHutC", "WitchHut", "DeckPlatform", "FerryDock", "MireShrine", "Watchtower", "Shipwreck"}
WALKS = {"BoardwalkStraight", "BoardwalkOpen", "BoardwalkJunction", "BoardwalkRamp", "RopeBridge"}


def check(items, flora, H, G):
    bad = []
    # 1) 물 위 것은 물, 뭍 것은 뭍
    for (a, x, z, y, yaw, s) in items:
        v = T(H, x, z)
        if np.isnan(v):
            bad.append("섬 밖 %s (%.0f,%.0f)" % (a, x, z))
            continue
        if y == "w" and a not in ("BoardwalkRamp",) and v > WATER - 0.2 and a != "FerryDock":
            bad.append("물 위 것 밑이 뭍: %s (%.0f,%.0f) 윗면 %.1f" % (a, x, z, v))
        if isinstance(y, str) and y.startswith("g") and v < WATER + 0.2 and not a.startswith("Ruin") and a != "TorchPost":
            bad.append("뭍 것이 물에: %s (%.0f,%.0f) 윗면 %.1f" % (a, x, z, v))
    # 2) 큰 건물·판자길끼리 겹침(맞닿는 건 괜찮다: 깊이 1 까지)
    solid = [(a, x, z, yaw, s) for (a, x, z, y, yaw, s) in items if a in BIG or a in WALKS]
    for i in range(len(solid)):
        for j in range(i + 1, len(solid)):
            a, x, z, yaw, s = solid[i]
            b, x2, z2, yaw2, s2 = solid[j]
            if math.hypot(x - x2, z - z2) > 110:
                continue
            if a in WALKS and b in WALKS:
                continue
            if {a, b} <= BIG | {"BoardwalkJunction"} and (a == "DeckPlatform" and b == "DeckPlatform"):
                continue
            pad = -1.0
            o = poly_overlap(footprint(a, x, z, yaw, s, pad), footprint(b, x2, z2, yaw2, s2, pad))
            if o > 0.5 and not ({a, b} & {"Watchtower"} and a in WALKS):
                bad.append("겹침 %.1f: %s(%.0f,%.0f) - %s(%.0f,%.0f)" % (o, a, x, z, b, x2, z2))
    # 3) 풀나무
    walksegs = []
    for pts in WALKS2:
        walksegs += list(zip(pts[:-1], pts[1:]))
    for (top, low) in RAMPS2:
        walksegs.append((top, (top[0] + (low[0] - top[0]) * 1.6, top[1] + (low[1] - top[1]) * 1.6)))
    walksegs += BRIDGES2
    paths = []
    for pts, w in PATHS2:
        paths += [(p, q, w / 2) for p, q in zip(pts[:-1], pts[1:])]
    for pts, w in CAUSEWAY:
        paths += [(p, q, w / 2) for p, q in zip(pts[:-1], pts[1:])]
    for pts, g in STONES:
        paths += [(p, q, 2.5) for p, q in zip(pts[:-1], pts[1:])]
    polys = [(a, footprint(a, x, z, yaw, s, 1.0)) for (a, x, z, y, yaw, s) in items if a in BIG or a in WALKS or a in ("Well", "Campfire", "CargoPile", "FishRack", "Fence", "Bench", "Signpost", "RuinArch", "RuinPillar", "LampPost", "TorchPost")]
    trees = []
    for (name, x, z, k, yaw, sc) in flora:
        v = T(H, x, z)
        tag = "%s(%.0f,%.0f)" % (k, x, z)
        if np.isnan(v):
            bad.append("섬 밖 " + tag)
            continue
        ok = {"A": v >= WATER - 1.3, "B": v >= WATER - 1.3, "C": v >= WATER - 1.3, "M": v >= WATER - 2.6, "D": v >= WATER - 2.6,
              "L": v >= WATER + 0.6, "S": v >= WATER + 0.3, "G": v >= WATER + 0.3, "F": v >= WATER + 0.3,
              "R": v <= WATER + 1.0, "P": v < WATER - 1.0}[k]
        if not ok:
            bad.append("자리 높이 %.1f 안 맞음 %s" % (v, tag))
        big = k in "ABCMDL"
        r = FLORA_R[name.split("_")[0]] * sc
        for (p0, p1) in walksegs:
            d = float(V1.seg_dist(np.array(x), np.array(z), p0, p1))
            if d < (8 if big else 4.5):
                bad.append("판자길 %.0f %s" % (d, tag))
                break
        if k not in "RP":
            for (p0, p1, hw) in paths:
                d = float(V1.seg_dist(np.array(x), np.array(z), p0, p1))
                if d < hw + (4 if big else 1.0):
                    bad.append("길 %.0f %s" % (d, tag))
                    break
        for (a, poly) in polys:
            cx = sum(p[0] for p in poly) / 4
            cz = sum(p[1] for p in poly) / 4
            if math.hypot(x - cx, z - cz) > 70:
                continue
            probe = [(x - 2, z - 2), (x + 2, z - 2), (x + 2, z + 2), (x - 2, z + 2)]
            if poly_overlap(poly, probe) > 0:
                bad.append("건물 %s 위 %s" % (a, tag))
                break
        if big:
            for (t2, tx, tz, tr) in trees:
                if math.hypot(x - tx, z - tz) < 0.38 * (r + tr):
                    bad.append("나무 겹침 %s - (%.0f,%.0f)" % (tag, tx, tz))
                    break
            trees.append((k, x, z, r))
    # 4) 길 띠가 물을 지나면 안 됨
    for pts, w in PATHS2:
        for p0, p1 in zip(pts[:-1], pts[1:]):
            L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
            for t in np.linspace(0, 1, int(L // 4) + 2):
                px, pz = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
                v = T(H, px, pz)
                if np.isnan(v) or v < WATER + 0.1:
                    bad.append("흙길이 물/밖을 지남 (%.0f,%.0f) 윗면 %.1f" % (px, pz, v))
                    break
    return bad


def find_gaps(items, flora, H, cover=44):
    pts = np.array([(x, z) for (a, x, z, y, yaw, s) in items] + [(x, z) for (n, x, z, k, yaw, s) in flora if k not in "RP"])
    paths = []
    for pts_, w in PATHS2:
        paths += [(a, b, w / 2) for a, b in zip(pts_[:-1], pts_[1:])]
    nanmask = np.isnan(H)
    edge = V1.dist_to(nanmask) < 18
    gaps = []
    for z in range(Z0 + 10, Z1, 20):
        for x in range(X0 + 10, X1, 20):
            v = T(H, x, z)
            if np.isnan(v) or v < WATER + 0.1 or T(edge, x, z):
                continue
            if any(float(V1.seg_dist(np.array(x), np.array(z), a, b)) < hw + 4 for a, b, hw in paths):
                continue
            if any(math.hypot(x - cx, z - cz) < cr for cx, cz, cr in CLEARINGS2):
                continue
            if np.min((pts[:, 0] - x) ** 2 + (pts[:, 1] - z) ** 2) < cover * cover:
                continue
            gaps.append((x, z))
    return gaps


# ─────────────────────────────────────────────────────────────
# 출력·평면도
# ─────────────────────────────────────────────────────────────

def category(a):
    if a in WALKS:
        return "판자길"
    if a in BIG:
        return "건물"
    if a.startswith("Ruin") or a == "Well":
        return "유적"
    return "소품"


def write_out(items, flora, G):
    L = []
    for (a, x, z, y, yaw, s) in items:
        ys = y if isinstance(y, str) else "%g" % round(y, 2)
        L.append("\t".join(["K", a, "%g" % round(x, 2), "%g" % round(z, 2), ys, "%g" % round(yaw, 2), "%g" % s, category(a)]))
    for (name, x, z, k, yaw, s) in flora:
        ys = "%g" % (WATER + 0.02) if k == "P" else ("g-0.4" if k in "ABCL" else "g-0.2")
        cat = "풀나무"
        L.append("\t".join(["F", name, "%g" % round(x, 2), "%g" % round(z, 2), ys, "%g" % round(yaw, 2), "%g" % s, cat]))
    open(os.path.join(HERE, "swamp", "place2.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    GL = []
    for g in G:
        cat, name, mat, col, x, y, z, yaw, sx, sy, sz, tr, rf, cc = g
        GL.append("\t".join([cat, name, mat, "%d,%d,%d" % col, "%.2f %.3f %.2f" % (x, y, z), "%.2f" % yaw, "%.2f %.3f %.2f" % (sx, sy, sz),
                             "%g" % tr, "%g" % rf, "1" if cc else "0"]))
    open(os.path.join(HERE, "swamp", "ground2.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(GL) + "\n")
    # 연출 표지(불·연기·글씨): 1판 표 그대로
    V1.write_texts([(a, x, z, y, yaw, s) for (a, x, z, y, yaw, s) in items])
    os.replace(os.path.join(HERE, "swamp", "fx.txt"), os.path.join(HERE, "swamp", "fx2.txt"))
    os.remove(os.path.join(HERE, "swamp", "place.txt"))


def render(H, items, flora, G, gaps, path, S=2, crop=None):
    R = 4
    nz, nx = H.shape
    img = np.zeros((nz, nx, 3), np.uint8)
    img[:] = (14, 16, 24)
    hv = np.nan_to_num(H, nan=-99)
    land = ~np.isnan(H)
    img[land & (hv < WATER - 0.2)] = (46, 70, 64)
    img[land & (hv >= WATER - 0.2) & (hv < 0.3)] = (82, 84, 62)
    img[land & (hv >= 0.3) & (hv < 2.0)] = (92, 98, 62)
    img[land & (hv >= 2.0) & (hv < 5.0)] = (130, 132, 80)
    img[land & (hv >= 5.0)] = (170, 166, 110)
    img = np.repeat(np.repeat(img, S, 0), S, 1)

    def dot(x, z, r, c, ring=False):
        px, pz = (x - X0) / R * S, (z - Z0) / R * S
        rr = max(1.0, r / R * S)
        for yy in range(max(0, int(pz - rr)), min(img.shape[0], int(pz + rr) + 1)):
            for xx in range(max(0, int(px - rr)), min(img.shape[1], int(px + rr) + 1)):
                d2 = (xx - px) ** 2 + (yy - pz) ** 2
                if d2 <= rr * rr and (not ring or d2 >= (rr - 1.2) ** 2):
                    img[yy, xx] = c

    def poly(pts, c):
        for (ax, az), (bx, bz) in zip(pts, pts[1:] + pts[:1]):
            n = int(max(abs(bx - ax), abs(bz - az)) / R * S) + 1
            for t in np.linspace(0, 1, n):
                px = int(((ax + (bx - ax) * t) - X0) / R * S)
                pz = int(((az + (bz - az) * t) - Z0) / R * S)
                if 0 <= px < img.shape[1] and 0 <= pz < img.shape[0]:
                    img[pz, px] = c
    for g in G:
        cat, name, mat, col, x, y, z, yaw, sx, sy, sz = g[:11]
        if cat == "길":
            c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
            pts = [(x + (u * c + v * s), z + (-u * s + v * c)) for (u, v) in ((-sx / 2, -sz / 2), (sx / 2, -sz / 2), (sx / 2, sz / 2), (-sx / 2, sz / 2))]
            poly(pts, (170, 150, 110))
    for (a, x, z, y, yaw, s) in items:
        if a in BIG or a in WALKS:
            poly(footprint(a, x, z, yaw, s), (230, 120, 60) if a in BIG else (210, 170, 110))
        else:
            dot(x, z, 2.5, (250, 230, 90))
    for (name, x, z, k, yaw, sc) in flora:
        r = FLORA_R[name.split("_")[0]] * sc
        col = {"A": (40, 90, 40), "B": (40, 90, 40), "C": (40, 90, 40), "M": (60, 120, 70), "D": (150, 140, 120), "L": (80, 140, 60)}.get(k, (120, 170, 90))
        dot(x, z, r if k in "ABCMDL" else 2.5, col, ring=k in "ABCMDL")
    for (x, z) in gaps:
        dot(x, z, 3, (255, 40, 40))
    step = 50 if crop else 100
    for x in range(1400, X1, step):
        img[::3, (x - X0) * S // R] = (220, 220, 220) if x % 100 == 0 else (120, 120, 120)
    for z in range(500, Z1, step):
        img[(z - Z0) * S // R, ::3] = (220, 220, 220) if z % 100 == 0 else (120, 120, 120)
    if crop:
        x0, x1, z0, z1 = crop
        img = img[(z0 - Z0) * S // R:(z1 - Z0) * S // R, (x0 - X0) * S // R:(x1 - X0) * S // R]
    write_png(path, img)


def main():
    slabs = load_slabs()
    H = top_grid(slabs, [(x, z, yaw, sx, sz, top) for (x, z, yaw, sx, sz, top) in FILLS])
    items = expand_walks() + [tuple(p) for p in PLACE2]
    flora = flora_list(H)
    G = ground_parts(slabs, H)
    bad = check(items, flora, H, G)
    gaps = find_gaps(items, flora, H)
    # 메움 확인: 섬 안 구멍이 남았나
    from collections import deque
    nan = np.isnan(H)
    nz, nx = H.shape
    outm = np.zeros(H.shape, bool)
    q = deque([(j, i) for j in range(nz) for i in (0, nx - 1)] + [(j, i) for i in range(nx) for j in (0, nz - 1)])
    while q:
        j, i = q.popleft()
        if 0 <= j < nz and 0 <= i < nx and not outm[j, i] and nan[j, i]:
            outm[j, i] = True
            q.extend(((j + 1, i), (j - 1, i), (j, i + 1), (j, i - 1)))
    holes = int((nan & ~outm).sum())
    if len(sys.argv) > 1 and sys.argv[1] == "crop":
        x0, x1, z0, z1 = map(int, sys.argv[2:6])
        S = int(sys.argv[6]) if len(sys.argv) > 6 else 4
        render(H, items, flora, G, gaps, os.path.join(HERE, "swamp", "crop2.png"), S, (x0, x1, z0, z1))
    else:
        write_out(items, flora, G)
        render(H, items, flora, G, gaps, os.path.join(HERE, "swamp", "plan2.png"))
    cnt = {}
    for it in items:
        cnt[it[0]] = cnt.get(it[0], 0) + 1
    fc = {}
    for f in flora:
        fc[f[0]] = fc.get(f[0], 0) + 1
    gc = {}
    for g in G:
        gc[g[0]] = gc.get(g[0], 0) + 1
    print("건물·소품 %d %s" % (len(items), dict(sorted(cnt.items()))))
    print("풀나무 %d %s" % (len(flora), dict(sorted(fc.items()))))
    print("땅 부품 %s, 남은 구멍 칸 %d, 빈 곳 %d" % (gc, holes, len(gaps)))
    print("검사 %d" % len(bad))
    for b in bad:
        print("  " + b)


if __name__ == "__main__":
    main()
