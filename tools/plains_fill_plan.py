# -*- coding: utf-8 -*-
"""
plains_fill_plan.py — 2026-10-04. 평원 섬 빈 들 채우기 배치표(손 배치) → 평면도 PNG + 겹침 검사 + Luau 데이터.

사용자(2026-10-04): "평원 맵쪽 너무 휑하니까 이것만 손 보고" — 도성 바깥 서쪽 들·동쪽 해안·북쪽 들이 풀밭에 나무 몇 그루뿐.
원칙(메모리): 배치는 표에 손으로(quality-over-speed), 덩어리는 축에 맞춘 상자(feedback-blocky-continents),
삼각형 법칙(높은 상자·랜드마크가 가렸다 드러냄), 뜬금없는 밭 금지(밭은 마을에 붙은 텃밭만), 절화 양식(한옥 키트).

있는 물건 자리 = tools/plains_occ.txt (스튜디오에서 뽑음: 태그, 이름, x, z, 너비x, 너비z, 윗면 y).
돌리기: python tools/plains_fill_plan.py [png] → tools/plains_fill_plan.png + tools/Plains_Fill_data.luau, 겹침 0건이어야 한다.
짓기: sed '/--@@DATA@@/r tools/Plains_Fill_data.luau' tools/Plains_Fill.luau > tools/swamp/_fill_run.luau && bash tools/job.sh tools/swamp/_fill_run.luau
좌표 = 월드(x 동, z 남; 북 = -z). 땅 윗면 1.90.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_png import Canvas  # noqa: E402

# 키트 틀 땅 위 크기(돌림 0, x·z) — 스튜디오에서 잰 값(ServerStorage 키트 목록)
KIT = {
    "Building_Cottage": (29, 22), "Building_House": (33, 25), "Building_HouseL": (34, 41), "Annex_Thatch": (21, 17),
    "Annex_Tile": (23, 18), "Granary": (30, 21), "Pavilion_Jeongja": (27, 30), "Prop_Well": (7, 7), "Yard_Well": (7, 7),
    "Yard_Haystack": (8, 5), "Yard_Jangdok": (8, 5), "Yard_Garden": (11, 8), "Fence_Brush": (20, 1), "Fence_Gate": (20, 4),
    "WallRuin_A": (39, 24), "WallRuin_B": (27, 19), "WallRuin_Tower": (21, 26),
    "Reeds": (7, 7), "LilyPads": (11, 15), "Rowboat": (13, 16), "FishRack": (11, 3), "FallenLog": (20, 4),
    "Signpost": (9, 5), "Campfire": (14, 12), "CargoPile": (14, 8), "Bench": (6, 1),
}
KIT_SRC = {  # 틀이 든 ServerStorage 폴더
    "Reeds": "SwampKit", "LilyPads": "SwampKit", "Rowboat": "SwampKit", "FishRack": "SwampKit", "FallenLog": "SwampKit",
    "Signpost": "SwampKit", "Campfire": "SwampKit", "CargoPile": "SwampKit", "Bench": "SwampKit",
    "WallRuin_A": "PlainsKit", "WallRuin_B": "PlainsKit", "WallRuin_Tower": "PlainsKit",
    "Yard_Haystack": "JeolhwaProps", "Yard_Jangdok": "JeolhwaProps", "Yard_Well": "JeolhwaProps", "Yard_Garden": "JeolhwaProps",
}

#=== 손 배치표 ===#
# 2026-10-04 사용자: "내가 말하는 채운다는 언덕같은걸 좀 놔서 굴곡감을 주자는 얘기" → 마을·소품·숲은 빼고 언덕만.
# 언덕 = 축에 맞춘 상자 켜(바위 옆 + 풀 윗판), 켜마다 5 안팎으로 올라 뛰어서 오를 수 있게. 윗켜는 한쪽으로 비켜 놓아 덜 반듯하게.
# 길·나무 밑동·도성·옛 덩어리를 비킨다(검사). 넓고 낮은 둔덕 + 가끔 세 켜 언덕 → 들판이 오르내린다(삼각형 법칙: 언덕이 다음 볼거리를 가림).

# 언덕(바위 상자 + 풀 윗판): { 이름, x0, x1, z0, z1, 윗면(땅 위) } — 같은 이름은 위로 얹는 켜(아래 켜 안쪽)
MASSES = [
    # 윗켜는 한쪽(바다·바깥 쪽)으로 몰아 그쪽은 가파른 층계, 반대쪽은 넓은 비탈 — 동심 네모(지구라트)처럼 안 보이게
    # ── 서쪽 들(도성 서순환 바깥 ~ 숲 섬) ──
    ("서북들", -600, -450, 190, 352, 4), ("서북들", -596, -475, 196, 320, 9), ("서북들", -592, -505, 200, 285, 15), ("서북들", -588, -530, 204, 250, 21),
    ("서들둔덕", -480, -340, 400, 560, 3), ("서들둔덕", -470, -370, 410, 520, 7), ("서들둔덕", -462, -410, 418, 470, 12),
    ("서해둔덕", -742, -655, 505, 590, 4), ("서해둔덕", -740, -680, 508, 575, 10), ("서해둔덕", -738, -705, 511, 550, 16),
    ("버들마루", -625, -540, 615, 745, 5), ("버들마루", -620, -555, 620, 720, 10), ("버들마루", -615, -575, 625, 685, 16), ("버들마루", -610, -590, 630, 660, 22),
    # 못재: 서쪽 바닷가 높은 언덕(다섯 켜 29) — 숲 섬 쪽에서 오면 바다를 가린다
    ("못재", -742, -660, 690, 800, 5), ("못재", -740, -668, 694, 790, 11), ("못재", -738, -680, 708, 775, 17), ("못재", -736, -695, 712, 758, 23), ("못재", -734, -708, 716, 745, 29),
    ("버들재", -556, -440, 750, 840, 4), ("버들재", -550, -455, 770, 838, 9), ("버들재", -545, -475, 795, 836, 14),
    # 도성 서순환 바로 바깥 낮은 둔덕(서촌에서 나서자마자 땅이 오르내리게)
    ("서촌둔덕", -428, -345, 600, 720, 3), ("서촌둔덕", -418, -360, 612, 700, 6),
    ("남서둔덕", -445, -335, 860, 950, 4), ("남서둔덕", -440, -360, 862, 930, 9),
    ("서남해", -740, -670, 885, 975, 4), ("서남해", -738, -685, 890, 950, 9), ("서남해", -736, -700, 895, 925, 14),
    # ── 북쪽 들 ──
    ("북들", -320, -215, 130, 198, 5), ("북들", -318, -240, 132, 180, 10),
    ("북촌둔덕", -205, -100, 95, 190, 3), ("북촌둔덕", -195, -130, 105, 175, 7),
    ("중북둔덕", 205, 300, 70, 160, 4), ("중북둔덕", 210, 290, 74, 140, 9), ("중북둔덕", 215, 270, 78, 118, 15), ("중북둔덕", 220, 250, 82, 105, 21),
    ("동북들", 560, 670, -100, -15, 5), ("동북들", 565, 650, -96, -30, 11), ("동북들", 570, 620, -92, -50, 17),
    ("북동해", 905, 1060, 100, 198, 4), ("북동해", 920, 1056, 128, 195, 9), ("북동해", 960, 1052, 140, 192, 15),
    # ── 동쪽 들 ──
    ("동중들", 705, 850, 300, 450, 4), ("동중들", 720, 840, 315, 445, 9), ("동중들", 740, 830, 335, 440, 15), ("동중들", 760, 825, 350, 430, 21),
    ("갯둔덕", 872, 985, 385, 500, 5), ("갯둔덕", 886, 975, 388, 485, 10), ("갯둔덕", 890, 955, 391, 460, 16), ("갯둔덕", 894, 930, 394, 435, 22),
    ("동촌둔덕", 700, 752, 480, 600, 3), ("동촌둔덕", 708, 745, 495, 585, 6),
    ("동들둔덕", 760, 865, 470, 595, 4), ("동들둔덕", 765, 855, 500, 592, 9),
    ("동해둔덕", 992, 1075, 535, 612, 5), ("동해둔덕", 1000, 1072, 538, 600, 10), ("동해둔덕", 1020, 1068, 541, 580, 15),
    ("동북해", 1030, 1120, 240, 330, 5), ("동북해", 1040, 1118, 244, 320, 10), ("동북해", 1055, 1116, 248, 300, 15), ("동북해", 1075, 1114, 252, 282, 20),
    ("동남해", 1005, 1120, 795, 872, 4), ("동남해", 1010, 1110, 800, 850, 9),
]
RAMPS = []
# 땅 판 높낮이(2026-10-04 사용자: "평원 전체에서, 큰 판도 높낮이를 줘서 입체감을 더 살릴 것").
# 도성(서순환·궁) 바깥 들판에 넓은 단(바위 옆 + 풀 윗면)을 깔아 땅 자체가 층을 이루게 한다.
#   { 이름, x0, x1, z0, z1, 높이(땅 위) } — 높이 3 = 한 단, 6 = 두 단(3 단 안쪽에만). 가장자리 3 은 뛰어 오른다.
#   단 안의 옛 덩어리·오르막·잔해·나무·바위(평원 지형)는 단 높이만큼 함께 올린다. 언덕(MASSES)은 첫 켜가 든 단 위에 선다.
#   도성 물건·돌길·사용자 물건은 단에 걸치면 안 된다(검사).
PLATEAUS = [
    # 서쪽: 서순환 바깥 남서 들 한 단 + 그 안쪽(버들마루·버들재) 두 단, 서들둔덕 쪽 한 단 — 사이(z 575~592)는 낮은 골
    ("서들판", -650, -318, 592, 972, 3),
    ("서들판위", -628, -436, 605, 748, 6),
    ("서중판", -586, -318, 395, 575, 3),
    # 북쪽: 북촌 바깥 들 한 단
    ("북들판", -440, -75, 55, 198, 3),
    # 북동: 바닷길 동쪽 한 단(동북들 언덕이 올라앉음)
    ("동북판", 548, 690, -100, 104, 3),
    # 동쪽: 갯둔덕·동언덕 들 한 단
    ("동판", 868, 1144, 336, 524, 3),
]
KITS = []
TREES = []
ROCKS = []
PATHS = []
PONDS = []
GARDENS = []
MARKS = []

# 벽 밑 바위 기둥 줄(사막과 같은 사용자 그림 — 평원 높은 덩어리 벽에도): 크기 표는 손으로 적고, 벽마다 시작 자리를 달리
PILLAR_BANK = [
    (7, 0.45, 4), (10, 0.66, 6), (5, 0.36, 3), (12, 0.8, 7), (6, 0.52, 5), (4, 0.31, 3), (9, 0.9, 6), (8, 0.58, 5),
    (6, 0.4, 4), (11, 0.72, 7), (5, 0.47, 4), (10, 0.86, 6), (7, 0.34, 5), (13, 0.62, 7), (4, 0.42, 3), (8, 0.77, 6),
    (9, 0.5, 6), (6, 0.93, 4), (10, 0.44, 6), (5, 0.6, 4), (12, 0.38, 7), (7, 0.82, 5), (8, 0.54, 6), (4, 0.29, 3),
    (11, 0.88, 8), (6, 0.48, 4), (9, 0.69, 6), (5, 0.33, 4), (10, 0.56, 7), (7, 0.92, 5),
]
# { 축, 벽 좌표, 바깥 쪽, 시작, 끝, 덩어리 윗면(땅 위), 표 시작 자리 } — 덩어리가 단 위에 올라갔으면 짓기가 단 높이를 더한다
WALL_RUNS = [
    # 남산 첫 켜(윗면 26): 남벽(턱 길 자리 x 235~345 비움)·동벽·서벽
    ("x", -60, 1, 162, 233, 26, 0), ("x", -60, 1, 347, 398, 26, 9), ("z", 400, 1, -150, -62, 26, 17), ("z", 160, -1, -200, -62, 26, 4),
    # 서쪽 덩어리(34): 동벽·남벽
    ("z", -500, 1, -54, -2, 34, 12), ("x", 60, 1, -598, -502, 34, 21),
    # 동쪽 덩어리(30): 남벽·서벽
    ("x", 90, 1, 962, 1078, 30, 6), ("z", 960, -1, -34, 18, 30, 25),
    # 동언덕(14, 동판 위): 서벽 · 서언덕(16): 동벽·북벽 · 서남바위(12): 북벽 · 동들(20): 북벽·동벽
    ("z", 1040, -1, 382, 478, 14, 14), ("z", -590, 1, 382, 498, 16, 2), ("x", 380, -1, -698, -592, 16, 19),
    ("x", 760, -1, -648, -562, 12, 27), ("x", 60, -1, 702, 788, 20, 8), ("z", 790, 1, 62, 148, 20, 15),
]
# 오르는 길(2026-10-04 사용자: "평원쪽 계단도 사막처럼"): 매끈한 풀 쐐기·자동 턱을 걷고 벽을 따라 나란히 오르는 바위 턱 길.
#   { 이름, 축("x"·"z"), 낮은 끝, 높은 끝, 벽 줄(그 축에 직각인 좌표), 바깥 쪽(+1/-1), 낮은 높이, 높은 높이(땅 위), 폭, 턱마다 폭 더하기[...] }
#   턱 수 = 폭 더하기 개수. 턱 높이는 낮은 → 높은 높이를 고르게, 바깥 가장자리는 표의 숫자만큼 들쭉날쭉(손으로 적음).
LEDGE_PATHS = [
    ("남산1", "x", 345, 235, -60, 1, 0, 26, 14, [0, 3, -2, 4, 1, -1, 2, -3, 0, 2, 3, -1, 1]),
    ("남산2", "x", 212, 300, -90, 1, 26, 44, 12, [2, -1, 3, 0, -2, 1, 2, -1, 0]),
    ("남산3", "x", 335, 245, -112, 1, 44, 58, 11, [1, -2, 2, 0, 3, -1, 1]),
    ("남산4", "x", 262, 310, -128, 1, 58, 68, 10, [0, 2, -1, 1, 2]),
    ("서쪽2", "z", 60, 4, -460, 1, 0, 18, 14, [1, -2, 3, 0, 2, -1, 1, 3, 0]),
    ("동들", "x", 785, 705, 150, 1, 6.4, 20, 14, [0, 2, -2, 3, 1, -1, 2]),
    ("동남바위", "x", 870, 820, 810, 1, 0, 10, 12, [1, -1, 2, 0, 1]),
    ("동언덕", "x", 1130, 1050, 480, 1, 0, 14, 14, [2, 0, -1, 3, 1, -2, 2]),
    ("서언덕", "z", 490, 400, -700, -1, 0, 16, 14, [0, 2, -1, 3, 1, -2, 2, 0]),
]
# 동산길 끝(정자 오르는 도성 길)은 길 판이 얹혀 있어 매끈한 쐐기로 둔다: { x, 낮은 z, 높은 z, 너비, 낮은 높이, 높은 높이 }
ROAD_WEDGES = [(676, 322, 290, 28, 0, 6.4)]
# 턱 길 위 작은 돌: { 길 이름, 턱 번호, 바깥에서 안쪽으로(0~1), 크기 }
LEDGE_STONES = [
    ("남산1", 2, 0.25, 2.2), ("남산1", 5, 0.2, 1.6), ("남산1", 9, 0.3, 2.6), ("남산1", 12, 0.15, 1.8),
    ("남산2", 3, 0.25, 2.0), ("남산2", 7, 0.2, 1.5), ("남산3", 2, 0.3, 1.8), ("남산3", 5, 0.2, 2.2), ("남산4", 3, 0.25, 1.6),
    ("서쪽2", 2, 0.2, 2.4), ("서쪽2", 6, 0.3, 1.7), ("동들", 3, 0.25, 2.0), ("동들", 6, 0.2, 1.5),
    ("동남바위", 2, 0.3, 1.8), ("동언덕", 2, 0.2, 2.3), ("동언덕", 5, 0.3, 1.6), ("서언덕", 3, 0.25, 2.1), ("서언덕", 6, 0.2, 1.7),
]
# 탑바위(아래로 갈수록 넓은 바위 상자 켜 + 꼭대기 작은 돌): { 이름, x, z, 켜[(너비, 깊이, 높이, 비킴 x, z)], 꼭대기 돌[(너비, 높이, 깊이, 비킴 x, z)] }
FORMATIONS = [
    ("들탑1", -520, 880, [(24, 20, 6, 0, 0), (18, 15, 7, 1, -1), (12, 10, 6, -1, 1), (6, 5, 4, 0, 0)], [(2.2, 1.8, 2, 0, 1)]),
    ("들탑2", -640, 560, [(22, 24, 5, 0, 0), (16, 18, 6, -1, 1), (10, 11, 6, 1, 0)], [(2, 1.6, 1.8, 1, 0), (1.4, 1.2, 1.4, -2, -1)]),
    ("들탑3", -275, 95, [(20, 18, 6, 0, 0), (14, 13, 7, 1, 1), (8, 7, 5, 0, -1)], [(1.8, 1.5, 1.8, 0, 0)]),
    ("들탑4", 455, 140, [(24, 20, 5, 0, 0), (18, 15, 6, -1, 0), (12, 10, 6, 1, 1), (7, 6, 4, 0, -1)], [(2.4, 2, 2.2, 0, 0)]),
    ("들탑5", 1010, 440, [(22, 22, 6, 0, 0), (16, 16, 7, 1, -1), (10, 9, 6, -1, 1)], [(2, 1.6, 2, 1, 1)]),
    ("들탑6", 740, 870, [(24, 22, 6, 0, 0), (17, 16, 7, -1, 1), (11, 10, 6, 1, 0), (5, 5, 4, 0, 0)], [(1.8, 1.4, 1.6, 0, 0)]),
    ("들탑7", -40, 170, [(22, 20, 5, 0, 0), (16, 14, 6, 1, 1), (9, 8, 6, 0, -1)], [(2, 1.6, 1.8, -1, 0)]),
    ("들탑8", 110, 20, [(20, 20, 6, 0, 0), (14, 15, 7, -1, 0), (8, 9, 5, 1, 1)], [(1.8, 1.5, 1.6, 0, 1)]),
    ("들탑9", -700, 130, [(24, 22, 6, 0, 0), (17, 16, 7, 1, 0), (11, 10, 6, 0, 1), (6, 5, 4, -1, 0)], [(2.2, 1.8, 2, 0, 0)]),
    ("들탑10", 1100, 300, [(20, 18, 5, 0, 0), (14, 13, 6, 1, 1), (8, 7, 5, -1, 0)], [(1.8, 1.5, 1.8, 0, 0)]),
]


def ledges_of(path):
    """턱 길 → 턱 네모들 [(x0, z0, x1, z1, 윗면)] (벽 쪽으로 1 겹쳐 틈 없이)"""
    name, axis, a_lo, a_hi, wall, out, h0, h1, w, jit = path
    n = len(jit)
    step = (a_hi - a_lo) / n
    out_rects = []
    for k in range(n):
        s0 = a_lo + step * k
        s1 = s0 + step
        lo, hi = min(s0, s1), max(s0, s1)
        lo, hi = lo - 0.3, hi + 0.3
        width = w + jit[k]
        o0, o1 = wall - out * 1.0, wall + out * width
        top = h0 + (h1 - h0) * (k + 1) / n
        if axis == "x":
            out_rects.append((lo, min(o0, o1), hi, max(o0, o1), top))
        else:
            out_rects.append((min(o0, o1), lo, max(o0, o1), hi, top))
    return out_rects

MARK_SIZE = {"Beacon": (26, 26), "Seonang": (12, 12), "Jangseung": (3, 3)}


def kit_rect(name, x, z, yaw, sc=1.0):
    w, d = KIT[name]
    w, d = w * sc, d * sc
    if int(yaw) % 180 == 90:
        w, d = d, w
    return (x - w / 2, z - d / 2, x + w / 2, z + d / 2)


def overlap(a, b, pad=0.0):
    return a[0] < b[2] + pad and b[0] < a[2] + pad and a[1] < b[3] + pad and b[1] < a[3] + pad


def load_occ():
    out = []
    for line in open(os.path.join(HERE, "plains_occ.txt"), encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 7:
            continue
        tag, name = f[0], f[1]
        x, z, sx, sz, top = map(float, f[2:7])
        out.append((tag, name, (x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2), top))
    return out


def load_land():
    """Plains_Build 의 땅 판(LAND) 네모들"""
    src = open(os.path.join(HERE, "Plains_Build.luau"), encoding="utf-8").read()
    rects = []
    for m in re.finditer(r"LAND = \{(.*?)\n\t?\}", src, re.S):
        for g in re.findall(r"\{ *(-?\d+), *(-?\d+), *(-?\d+)(?:, *(-?\d+))? *\}", m.group(1)):
            x0, x1, zn = int(g[0]), int(g[1]), int(g[2])
            zs = int(g[3]) if g[3] else 200
            rects.append((x0, zn, x1, zs))
    return rects


def new_items():
    """새로 놓는 것 전부: (종류, 이름, 네모)"""
    items = []
    for m in MASSES:
        items.append(("mass", m[0], (m[1], m[3], m[2], m[4])))
    for i, (k, x, z, yaw, *rest) in enumerate(KITS):
        sc = rest[0] if rest else 1.0
        items.append(("kit", "%s#%d" % (k, i), kit_rect(k, x, z, yaw, sc)))
    for i, t in enumerate(TREES):
        r = 9 * t[3]
        items.append(("tree", "Tree#%d" % i, (t[0] - r, t[1] - r, t[0] + r, t[1] + r)))
    for i, r in enumerate(ROCKS):
        h = max(r[2], r[4]) / 2
        items.append(("rock", "Rock#%d" % i, (r[0] - h, r[1] - h, r[0] + h, r[1] + h)))
    for i, p in enumerate(PONDS):
        items.append(("pond", "Pond#%d" % i, (p[0] - 2, p[1] - 2, p[2] + 2, p[3] + 2)))
    for i, g in enumerate(GARDENS):
        items.append(("garden", "Garden#%d" % i, tuple(g)))
    for path in LEDGE_PATHS:
        for j, r in enumerate(ledges_of(path)):
            items.append(("ledge", "%s#%d" % (path[0], j), r[:4]))
    for f in FORMATIONS:
        w, d = f[3][0][0], f[3][0][1]
        items.append(("form", f[0], (f[1] - w / 2, f[2] - d / 2, f[1] + w / 2, f[2] + d / 2)))
    for i, (k, x, z, yaw) in enumerate(MARKS):
        w, d = MARK_SIZE[k]
        if int(yaw) % 180 == 90:
            w, d = d, w
        items.append(("mark", "%s#%d" % (k, i), (x - w / 2, z - d / 2, x + w / 2, z + d / 2)))
    return items


def path_rects():
    out = []
    for w, pts in PATHS:
        for a, b in zip(pts, pts[1:]):
            assert a[0] == b[0] or a[1] == b[1], "돌길은 직각으로만 꺾는다: %s→%s" % (a, b)
            out.append((min(a[0], b[0]) - w / 2, min(a[1], b[1]) - w / 2, max(a[0], b[0]) + w / 2, max(a[1], b[1]) + w / 2))
    return out


def inside_land(r, land):
    """네 모서리가 모두 어느 땅 판 위인가"""
    def on(x, z):
        return any(l[0] <= x <= l[2] and l[1] <= z <= l[3] for l in land)
    return all(on(x, z) for x, z in ((r[0], r[1]), (r[2], r[1]), (r[0], r[3]), (r[2], r[3])))


WATER_KITS = ("Reeds", "LilyPads")
# 모래 단(동쪽 만) — 배·짐이 올라앉는 땅
EXTRA_LAND = [(1130, 700, 1196, 780)]


def liftable(tag):
    """Plains_Fill 이 언덕 위로 들어 올리는 것: 평원 지형 폴더의 나무·바위(도성 나무는 아님)"""
    return tag.startswith("R_평원") and (tag.endswith("/Trees") or tag.endswith("/Rocks"))


def is_tree(tag, name):
    return "Trees" in tag or "Flora" in tag or "나무" in tag


def plateau_at(x0, z0, x1, z1):
    """네모 전체가 든 단 중 가장 높은 것의 높이(없으면 0)"""
    h = 0
    for _, a0, a1, b0, b1, ph in PLATEAUS:
        if a0 <= x0 and x1 <= a1 and b0 <= z0 and z1 <= b1:
            h = max(h, ph)
    return h


def check_plateaus(occ, land):
    probs = []
    for pl in PLATEAUS:
        name, x0, x1, z0, z1, h = pl
        r = (x0, z0, x1, z1)
        if not inside_land(r, land):
            probs.append("단이 땅 밖: %s" % name)
        if h > 3 and plateau_at(*r) < h and not any(
            o is not pl and o[1] <= x0 and x1 <= o[2] and o[3] <= z0 and z1 <= o[4] and o[5] == h - 3 for o in PLATEAUS
        ):
            probs.append("두 단(%d)은 한 단 안쪽에: %s" % (h, name))
        for tag, oname, orect, _ in occ:
            if "/Sand" in tag:
                continue
            inside = r[0] <= orect[0] and orect[2] <= r[2] and r[1] <= orect[1] and orect[3] <= r[3]
            lift = tag.startswith("R_평원") and any(tag.endswith(k) for k in ("/Trees", "/Rocks", "/Masses", "/Ramps", "/Ruins"))
            if lift:
                if is_tree(tag, oname):
                    # 나무는 밑동(4)만 본다: 단 안쪽 5 이상 또는 바깥 4 넘게
                    cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                    inner = r[0] + 5 <= cx <= r[2] - 5 and r[1] + 5 <= cz <= r[3] - 5
                    if not (inner or not overlap((cx, cz, cx, cz), r, 4)):
                        probs.append("나무가 단 가장자리에: %s ↔ %s/%s" % (name, tag, oname))
                elif not inside and overlap(r, orect, 2):
                    probs.append("단에 걸침: %s ↔ %s/%s" % (name, tag, oname))
                continue
            pad = 0 if "/Cliffs" in tag else 3
            if is_tree(tag, oname):
                cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                orect = (cx - 4, cz - 4, cx + 4, cz + 4)
            if overlap(r, orect, pad):
                probs.append("단이 덮음(못 올림): %s ↔ %s/%s" % (name, tag, oname))
        # 언덕 첫 켜는 단 안이거나 2 넘게 떨어져야
        firsts = {}
        for m in MASSES:
            firsts.setdefault(m[0], (m[1], m[3], m[2], m[4]))
        for hn, hr in firsts.items():
            inside = r[0] <= hr[0] and hr[2] <= r[2] and r[1] <= hr[1] and hr[3] <= r[3]
            if not inside and overlap(r, hr, 2):
                probs.append("언덕이 단에 걸침: %s ↔ %s" % (name, hn))
    return probs


def check(occ, land):
    probs = check_plateaus(occ, land)
    items = new_items()
    # 덩어리·오르막 위에 얹는 것은 같은 덩어리 이름이면 괜찮다(정자를 언덕 위에) — 덩어리와 물건 겹침은 덩어리가 받침이면 허용
    mass_rects = [it[2] for it in items if it[0] == "mass"]
    for kind, name, r in items:
        if not inside_land(r, land):
            probs.append("땅 밖: %s %s" % (name, tuple(round(v) for v in r)))
        if kind == "mass":
            for tag, oname, orect, _ in occ:
                if "/Sand" in tag:
                    continue
                if liftable(tag):
                    # 들어 올릴 나무·바위: 켜 안쪽 5 이상 또는 바깥 4 넘게(가장자리에 걸치면 안 됨)
                    cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                    inner = r[0] + 5 <= cx <= r[2] - 5 and r[1] + 5 <= cz <= r[3] - 5
                    outer = not overlap((cx, cz, cx, cz), r, 4)
                    if not (inner or outer):
                        probs.append("나무·바위가 언덕 가장자리에: %s ↔ %s/%s" % (name, tag, oname))
                    continue
                if is_tree(tag, oname):
                    cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                    orect = (cx - 4, cz - 4, cx + 4, cz + 4)
                if overlap(r, orect, 1):
                    probs.append("언덕이 있는 것과 겹침: %s ↔ %s/%s" % (name, tag, oname))
            continue
        on_mass = any(m[0] <= r[0] and r[2] <= m[2] and m[1] <= r[1] and r[3] <= m[3] for m in mass_rects)
        for tag, oname, orect, _ in occ:
            if kind in ("ledge", "form") and ("/Masses" in tag or "/Ramps" in tag or "/Cliffs" in tag or "Pavilion" in tag):
                continue  # 오르는 덩어리 벽에 붙고(옛 쐐기 자리는 지운다), 탑바위는 언덕 위에도 선다
            # 옛 덩어리 위에 올라앉는 것은 허용(받침), 그 밖은 3 스터드 띄운다
            if "/Masses" in tag and orect[0] <= r[0] and r[2] <= orect[2] and orect[1] <= r[1] and r[3] <= orect[3]:
                continue
            if "/Cliffs" in tag and kind in ("tree", "rock"):
                continue
            if "/Sand" in tag:
                continue  # 모래 단은 땅
            if is_tree(tag, oname):
                if kind == "tree":
                    continue  # 숲은 붙어도 된다
                # 나무: 집·랜드마크는 수관(반지름 14)을 비키고, 납작한 것(밭·못·바위)은 밑동(4)만
                cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                rad = 14 if kind in ("kit", "mark") else 4
                orect = (cx - rad, cz - rad, cx + rad, cz + rad)
            pad = 0 if kind in ("tree", "rock") else 3
            if overlap(r, orect, pad):
                probs.append("있는 것과 겹침: %s ↔ %s/%s" % (name, tag, oname))
        for kind2, name2, r2 in items:
            if name2 <= name or kind2 == "mass":
                continue
            if kind in ("tree",) and kind2 in ("tree",):
                continue  # 숲 덩어리는 서로 붙어도 된다
            if kind == "ledge" and kind2 == "ledge" and name.split("#")[0] == name2.split("#")[0]:
                continue  # 같은 길의 턱끼리는 이어 붙는다
            if {kind, kind2} == {"kit", "pond"} and (name.split("#")[0] in WATER_KITS or name2.split("#")[0] in WATER_KITS):
                continue  # 갈대·연잎은 못 안에
            if overlap(r, r2, 2):
                probs.append("새 것끼리 겹침: %s ↔ %s" % (name, name2))
        for pr in path_rects():
            if kind not in ("tree", "rock") and overlap(r, pr, 1) and not on_mass:
                probs.append("돌길 위: %s" % name)
    for pr in path_rects():
        for tag, oname, orect, _ in occ:
            if "/Masses" in tag or "/Cliffs" in tag or "/Sand" in tag or "/Paths" in tag or "길" in tag:
                continue
            if is_tree(tag, oname):
                cx, cz = (orect[0] + orect[2]) / 2, (orect[1] + orect[3]) / 2
                orect = (cx - 4, cz - 4, cx + 4, cz + 4)
            if overlap(pr, orect, 1):
                probs.append("돌길이 있는 것을 지남: %s/%s" % (tag, oname))
    seen = {}
    for m in MASSES:
        if m[0] in seen:
            lo = seen[m[0]]
            if not (lo[0] <= m[1] and m[2] <= lo[1] and lo[2] <= m[3] and m[4] <= lo[3] and m[5] > lo[4]):
                probs.append("윗켜가 아래 켜 밖이거나 낮음: %s" % (m,))
        else:
            for n, o in seen.items():
                pass
        seen[m[0]] = m[1:]
    names = {}
    for m in MASSES:
        names.setdefault(m[0], (m[1], m[3], m[2], m[4]))
    keys = list(names)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            if overlap(names[a], names[b], 4):
                probs.append("언덕끼리 붙음: %s ↔ %s" % (a, b))
    return probs


def render(path, occ, land, region=(-800, -280, 1220, 1090), sc=0.5):
    C = Canvas(*region, sc)
    C.rect(*region, "#4f7f9c")
    for l in land:
        C.rect(*l, "#86ad70")
    for gx in range(-800, 1221, 100):
        C.line(gx, region[1], gx, region[3], 1.0 / sc if gx % 500 else 2.2 / sc, "#3c5a33")
        C.text(gx + 3, region[1] + 4, str(abs(gx)), "#ffffff" if gx >= 0 else "#ffd080", 2)
    for gz in range(-200, 1091, 100):
        C.line(region[0], gz, region[2], gz, 1.0 / sc if gz % 500 else 2.2 / sc, "#3c5a33")
        C.text(region[0] + 4, gz + 3, str(abs(gz)), "#ffffff" if gz >= 0 else "#ffd080", 2)
    colors = [("/Cliffs", "#7c7c78"), ("/Masses", "#6c6a62"), ("/Ramps", "#9ab27e"), ("/Sand", "#d9cc98"),
              ("/Trees", "#2f5a2a"), ("Flora", "#2f5a2a"), ("나무", "#2f5a2a"), ("/Rocks", "#5d5d58"), ("/Paths", "#c9c3b0"),
              ("/Ruins", "#a09a8c"), ("길", "#a88f68")]
    for _, x0, x1, z0, z1, h in sorted(PLATEAUS, key=lambda q: q[5]):
        C.rect(x0, z0, x1, z1, "#6f9a55" if h <= 3 else "#557d40")
    for tag, name, r, top in occ:
        col = "#c0b49a"
        for key, c in colors:
            if key in tag or key in name:
                col = c
                break
        C.rect(*r, col, 0.85)
    for w, pts in PATHS:
        for a, b in zip(pts, pts[1:]):
            C.line(a[0], a[1], b[0], b[1], w, "#e0dccb")
    newcol = {"mass": "#c05a2c", "kit": "#e8b400", "tree": "#0d7a2a", "rock": "#303030", "pond": "#3a9ad9",
              "garden": "#8a6f4c", "mark": "#ff3d7f", "ledge": "#ffd27a", "form": "#4a4a46"}
    for kind, name, r in new_items():
        C.rect(*r, newcol[kind], 0.9 if kind != "mass" else 0.55)
    for lp in LEDGE_PATHS:
        for r in ledges_of(lp):
            C.rect(r[0], r[1], r[2], r[3], "#ffd27a")
    for f in FORMATIONS:
        for w, d, h, dx, dz in f[3]:
            C.rect(f[1] + dx - w / 2, f[2] + dz - d / 2, f[1] + dx + w / 2, f[2] + dz + d / 2, "#4a4a46", 0.5)
    for x, zl, zh, w, *_ in RAMPS:
        C.rect(x - w / 2, min(zl, zh), x + w / 2, max(zl, zh), "#ffe08a", 0.9)
    C.save(path)


def lua(v):
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def emit(path):
    kits = [(k, x, z, yaw, rest[0] if rest else 1, KIT_SRC.get(k, "JeolhwaKit")) for k, x, z, yaw, *rest in KITS]
    out = ["-- plains_fill_plan.py 가 만든 데이터(손으로 고치지 말고 표를 고칠 것)"]
    ledges = [r + (lp[0],) for lp in LEDGE_PATHS for r in ledges_of(lp)]
    stones = []
    for name, k, inward, size in LEDGE_STONES:
        lp = next(pp for pp in LEDGE_PATHS if pp[0] == name)
        r = ledges_of(lp)[k - 1]
        _, axis, _, _, wall, side, *_ = lp
        if axis == "x":
            outer = r[3] if side > 0 else r[1]
            z = outer - (outer - wall) * inward
            stones.append(((r[0] + r[2]) / 2, z, size))
        else:
            outer = r[2] if side > 0 else r[0]
            x = outer - (outer - wall) * inward
            stones.append((x, (r[1] + r[3]) / 2, size))
    for name, rows in (("PILLAR_BANK", PILLAR_BANK), ("WALL_RUNS", WALL_RUNS), ("LEDGES", ledges), ("LEDGE_STONES", stones), ("ROAD_WEDGES", ROAD_WEDGES), ("FORMATIONS", FORMATIONS),
                       ("PLATEAUS", PLATEAUS), ("MASSES", MASSES), ("RAMPS", RAMPS), ("KITS", kits), ("TREES", TREES), ("ROCKS", ROCKS),
                       ("PONDS", PONDS), ("GARDENS", GARDENS), ("MARKS", MARKS)):
        out.append("local %s = {" % name)
        out += ["\t%s," % lua(r) for r in rows]
        out.append("}")
    out.append("local PATHS = {")
    out += ["\t{ %s, %s }," % (w, lua([list(p) for p in pts])) for w, pts in PATHS]
    out.append("}")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")


if __name__ == "__main__":
    occ, land = load_occ(), load_land() + EXTRA_LAND
    png = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "plains_fill_plan.png")
    render(png, occ, land)
    probs = check(occ, land)
    for p in probs:
        print(p)
    print("겹침·문제 %d건" % len(probs))
    emit(os.path.join(HERE, "Plains_Fill_data.luau"))
