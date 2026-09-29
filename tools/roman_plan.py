# -*- coding: utf-8 -*-
"""
roman_plan.py — 칼로도르 폴리스(화산섬 로마풍 제국 도시) 배치표. (2026-09-29)

전부 손으로 적은 자리다. 스크립트는 (1) 20 간격 실측(tools/roman/h20.txt)으로 발밑이 평평한 뭍인지,
(2) 건물끼리 겹치지 않는지 검사하고, (3) Studio 빌드용 자료(tools/swamp/roman_data.luau)를 쓴다.

섬 모양: 칼데라 고리(높이 75~79) 가운데 북쪽 석호와 남쪽 석호가 파여 있고(바닥 없음 → 용암 호수로 메움, 수면 43),
그 사이 섬(-1440..-1200, -2930..-2810) 봉인 단 가운데에 제단이 있다(봉인된 거인은 나중에 보스로 나온다).

  북      황궁(팔라티움) — 봉인된 거인을 마주 보고, 석호를 건너는 황제의 다리가 섬까지
  북동    포룸: 이그너스 신전·바실리카·작은 신전 둘·승전 기둥·개선문·목욕장(수도교로 북쪽 온천물)
  동      평민 인술라 거리 · 동문(바다 쪽 정문)
  남동    시장 광장(가게 줄 넷·가판)
  남      원형 투기장 · 인술라
  남서    옛 제국 유적 공원(쓰러진 거인의 머리·손·발, 무너진 신전, 거인 발자국)
  서      길드 파빌라키니스의 군단 요새(고리 방향으로 비스듬히): 본부·불의 글라디우스·병영·망루·훈련장·임모로우 공병 마당
  북서    귀족 저택 · 작은 신전
  고리 네 곳 거인 석상(콜로수스)이 봉인된 거인을 바라본다

yaw: 도. 틀 앞(-Z)이 보는 쪽 = (-sin yaw, -cos yaw). 0 = 북(-Z), 90 = 서(-X), 180 = 남, -90 = 동.
돌리는 법: python tools/roman_plan.py  → 검사 결과 출력 + tools/swamp/roman_data.luau
"""
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- 실측·틀 크기
_L = open(os.path.join(HERE, "roman", "h20.txt"), encoding="utf-8").read().splitlines()
X0, X1, Z0, Z1, ST = map(int, _L[0].split())
HROWS = [list(map(float, l.split(","))) for l in _L[1:] if not l.startswith("#")]


def H(x, z):
    c = round((x - X0) / ST)
    r = round((z - Z0) / ST)
    if 0 <= r < len(HROWS) and 0 <= c < len(HROWS[0]):
        return HROWS[r][c]
    return -1.0


KIT = {}
for line in open(os.path.join(HERE, "roman", "kit_footprints.txt"), encoding="utf-8"):
    m = re.match(r"(\w+) x (-?[\d.]+)\.\.(-?[\d.]+) z (-?[\d.]+)\.\.(-?[\d.]+) h ([\d.]+)", line)
    if m:
        KIT[m.group(1)] = tuple(float(v) for v in m.groups()[1:])

G = (-1320.0, -2870.0)          # 봉인된 거인
LAVA = 43.0                      # 용암 호수 수면


def face(x, z, tx, tz):
    """(x,z) 에서 (tx,tz) 를 보는 yaw."""
    return math.degrees(math.atan2(-(tx - x), -(tz - z)))


ITEMS = []   # (kit, x, z, yaw, opts)
VARIANTS = {"Domus", "Insula_A", "Insula_B", "Taberna_Row", "Barracks", "Wall_Seg"}   # 폐허 두 번째 판(_2)이 있는 틀


def put(kit, x, z, yaw=0.0, **o):
    assert kit in KIT, kit
    ITEMS.append((kit, float(x), float(z), float(yaw), o))


# ================================================================ 1. 봉인 단의 제단(섬)
# 2026-09-29: 봉인된 거인·오벨리스크 여덟·사슬은 나중에 보스로 낸다 — 지금은 봉인 단 가운데 제단만 둔다(Roman_City 가 짓는다).
# 오벨리스크가 섰던 여덟 방향은 봉인 문자 살로만 남는다
SEAL_R = 62.0
OBELISKS = []
for k in range(8):                               # 22.5 도 비껴 북쪽 참배길(다리→제단)을 비운다
    a = math.radians(22.5 + k * 45)
    OBELISKS.append((G[0] + SEAL_R * math.sin(a), G[1] - SEAL_R * math.cos(a)))

# ================================================================ 2. 황궁·황제의 다리
put("Palatium", -1330, -3440, 180, group="Palace")
put("Domus", -1330, -3545, 0, group="Palace")                      # 황제의 뒤채(바다를 본다)
for zc in range(-3340, -2979, 40):                                  # 다리 10칸(수면 아래 교각)
    put("Bridge_Span", -1320, zc, 90, group="Bridge", y=-1.0, plinth="none", check=False)
put("Aquila", -1338, -3366, 180, group="Bridge", plinth="none")
put("Aquila", -1302, -3366, 180, group="Bridge", plinth="none")
put("Brazier", -1334, -2941, 0, group="Seal", plinth="none")   # 아래 단(r 76) 위, 다리 내림길 양옆
put("Brazier", -1306, -2941, 0, group="Seal", plinth="none")

# ================================================================ 3. 포룸(북동)
put("Temple_Ignus", -860, -3345, 180, group="Forum")
put("Brazier", -886, -3296, 0, group="Forum", plinth="none")
put("Brazier", -834, -3296, 0, group="Forum", plinth="none")
put("Victory_Column", -860, -3262, 0, group="Forum")
put("Basilica", -773, -3220, 90, group="Forum")
put("Temple_Small", -934, -3255, -90, group="Forum")
put("Temple_Small", -934, -3185, -90, group="Forum")
put("Fountain", -892, -3200, 0, group="Forum", plinth="none")
put("Fountain", -828, -3200, 0, group="Forum", plinth="none")
for (x, z, yaw) in ((-903, -3288, -90), (-817, -3288, 90), (-903, -3150, -90), (-817, -3150, 90)):
    put("Statue_Human", x, z, yaw, group="Forum", plinth="none")
put("Triumphal_Arch", -860, -3118, 0, group="Forum")
put("Thermae", -998, -3266, -90, group="Forum")   # 북벽이 수도교 끝(-3300)에 닿는다
for zc in range(-3520, -3319, 40):                                  # 수도교(북쪽 온천에서 목욕장으로)
    put("Aqueduct_Span", -998, zc, 90, group="Aqueduct", plinth="piers", level="aqueduct")
# 수도교 북쪽 끝은 샘집(카스텔룸, Roman_City 가 짓는다: x -998, z -3549, 14 x 14) 에서 시작한다
for x in (-1180, -1120, -1060):
    put("Domus", x, -3470, 180, group="Patrician")

# ================================================================ 4. 동쪽 인술라 거리 · 동문
WEST_ROW = ["A", "B", "A", "A", "B", "A", "A"]
EAST_ROW = ["B", "A", "A", None, "A", "B", "A"]   # 넷째 칸은 동문 길
for i, z in enumerate(range(-3070, -2805, 44)):
    k = WEST_ROW[i]
    put("Insula_" + k, -791 if k == "A" else -797, z, -90, group="EastQuarter")
    k = EAST_ROW[i]
    if k:
        put("Insula_" + k, -729 if k == "A" else -723, z, 90, group="EastQuarter")
put("City_Gate", -672, -2938, -90, group="EastGate")
for zc in (-2984.4, -3024.4, -2891.6, -2851.6):  # 문루(±26.4)에 바로 붙는다
    put("Wall_Seg", -672, zc, 90, group="EastGate")
put("Wall_Tower", -672, -3052, 0, group="EastGate")
put("Wall_Tower", -672, -2824, 0, group="EastGate")

# ================================================================ 5. 남동 시장
put("Taberna_Row", -880, -2662, 180, group="Market")
put("Taberna_Row", -880, -2558, 0, group="Market")
put("Taberna_Row", -934, -2610, -90, group="Market")
put("Taberna_Row", -826, -2610, 90, group="Market")
for (x, z, yaw) in ((-900, -2628, 0), (-860, -2628, 0), (-900, -2592, 180), (-860, -2592, 180), (-880, -2610, 90)):
    put("Market_Stall", x, z, yaw, group="Market", plinth="none")
for (x, z) in ((-912, -2640), (-848, -2582), (-915, -2582)):
    put("Amphorae", x, z, 0, group="Market", plinth="none")
put("Insula_A", -1020, -2640, -90, group="Market")
put("Insula_B", -1016, -2586, -90, group="Market")
put("Insula_A", -1030, -2530, 0, group="Market")
put("Domus", -742, -2600, 90, group="Market")
put("Insula_A", -780, -2510, 0, group="Market")
put("Brazier", -880, -2632, 0, group="Market", plinth="none") if False else None

# ================================================================ 6. 남쪽 원형 투기장
AMPH = (-1300.0, -2360.0)
for q, yaw in enumerate((0, 90, 180, 270)):
    put("Amph_Quarter", AMPH[0], AMPH[1], yaw, group="Amphitheater", plinth="none", level="amph", check=(q == 0),
        footprint="circle")
for (x, z, yaw) in ((-1560, -2440, 0), (-1510, -2440, 0), (-1460, -2440, 0)):
    put("Insula_A", x, z, yaw, group="SouthQuarter")
put("Insula_B", -1150, -2405, 0, group="SouthQuarter")
put("Insula_A", -1100, -2400, 0, group="SouthQuarter")
put("Taberna_Row", -1030, -2440, 0, group="SouthQuarter")
put("Insula_A", -1520, -2390, 180, group="SouthQuarter")
put("Insula_A", -1470, -2390, 180, group="SouthQuarter")

# ================================================================ 7. 남서 옛 제국 유적 공원
put("Ruin_Temple", -1720, -2600, 20, group="Ruins")
put("Ruin_Temple", -1560, -2560, -15, group="Ruins")
put("Giant_Head", -1650, -2652, 40, group="Ruins", plinth="none")
put("Giant_Hand", -1470, -2548, -30, group="Ruins", plinth="none")
put("Giant_Foot", -1770, -2570, 10, group="Ruins")
for (x, z, yaw) in ((-1640, -2560, 70), (-1598, -2645, -20), (-1690, -2525, 5), (-1760, -2650, 35)):
    put("Column_Drums", x, z, yaw, group="Ruins", plinth="none")
FOOTPRINTS = [  # 거인 발자국: 가운데, 방향(발끝이 보는 yaw), 오른발/왼발
    (-1705, -2685, 60, 1),
    (-1610, -2505, 60, -1),
]

# ================================================================ 8. 서쪽 군단 요새(고리를 따라 비스듬히)
CC = (-1745.0, -3185.0)
DU = (0.646, -0.763)            # 요새 긴 축(남서→북동)
DV = (0.763, 0.646)             # 칼데라 쪽


def W(u, v):
    return CC[0] + u * DU[0] + v * DV[0], CC[1] + u * DU[1] + v * DV[1]


YAW_IN = -130.3                  # 앞이 +v(칼데라 쪽)
YAW_OUT = YAW_IN + 180           # 앞이 -v(바깥)
YAW_ALONG = 49.7                 # 긴 축(로컬 x)이 요새 긴 축과 나란함, 앞이 -v
px, pz = W(0, 0)
put("Principia", px, pz, YAW_IN, group="Legion", fire_gladius=True)
for u in (-10, 10, -17, 17):                   # 본부 문 앞(v 26) 과 병영 길(v 34..44) 사이
    ax, az = W(u, 30)
    put("Aquila", ax, az, YAW_IN, group="Legion", plinth="none")
for u in (-95, -25, 45):                       # 바깥 줄 병영(안쪽을 본다)
    bx, bz = W(u, -58)
    put("Barracks", bx, bz, YAW_ALONG + 180, group="Legion")
for u in (-95, 70):                            # 안쪽 줄 병영
    bx, bz = W(u, 56)
    put("Barracks", bx, bz, YAW_ALONG, group="Legion")
for (u, v) in ((-140, -70), (120, -72), (135, 70)):
    wx, wz = W(u, v)
    put("Watchtower", wx, wz, YAW_ALONG, group="Legion")
for u in range(-120, 121, 40):                 # 바깥 성벽
    sx, sz = W(u, -84)
    put("Wall_Seg", sx, sz, YAW_ALONG, group="Legion")
gx, gz = W(162, 39)                            # 북동 끝 문. 병영 길(v 39)이 지난다
put("City_Gate", gx, gz, face(gx, gz, *W(300, 39)), group="Legion")
TRAIN = W(95, 0)                               # 훈련장(모래 마당 + 허수아비 기둥)
for (u, v) in ((85, -12), (95, -12), (105, -12), (85, 12), (95, 12), (105, 12)):
    tx, tz = W(u, v)
    put("Brazier", tx, tz, 0, group="Legion", plinth="none") if False else None
ENG = W(-60, 20)                               # 임모로우 공병 마당
cx_, cz_ = W(-60, 14)
put("Crane", cx_, cz_, YAW_ALONG, group="Legion", plinth="none")
for (u, v, yaw) in ((-72, 8, 10), (-48, 10, -25)):
    dx_, dz_ = W(u, v)
    put("Column_Drums", dx_, dz_, yaw, group="Legion", plinth="none")
fgx, fgz = W(0, 0)
FIRE_GLADIUS = (fgx, fgz)

# ================================================================ 9. 북서 귀족 저택 · 작은 신전
for x in (-1560, -1500, -1440):
    put("Domus", x, -3426, 180, group="Patrician")
put("Temple_Small", -1535, -3345, face(-1535, -3345, *G), group="Patrician")

# ================================================================ 10. 콜로수스 넷(봉인된 거인을 본다)
for (x, z) in ((-1480, -3318), (-1060, -3330), (-1060, -2700), (-1560, -2690)):
    put("Colossus", x, z, face(x, z, *G), group="Colossi")

# ================================================================ 길(현무암 포장)
ROADS = [
    # (이름, 폭, 점들)
    ("Cardo_Forum", 14, [(-860, -3137), (-860, -3095), (-760, -3095)]),
    ("East_Street", 12, [(-760, -3095), (-760, -2780)]),
    ("East_to_Market", 12, [(-760, -2780), (-760, -2700), (-849, -2700), (-849, -2650)]),   # 시장 북동 모퉁이 틈으로
    ("Market_South", 12, [(-849, -2566), (-849, -2480), (-960, -2470)]),                    # 남동 모퉁이 틈에서
    ("South_Road", 12, [(-960, -2470), (-1180, -2465), (-1240, -2460)]),
    ("Amph_North", 12, [(-1240, -2460), (-1360, -2458), (-1420, -2470)]),
    ("SW_Road", 12, [(-1420, -2470), (-1540, -2480), (-1660, -2470), (-1740, -2495), (-1800, -2525), (-1860, -2560)]),
    ("West_Road", 12, [(-1860, -2560), (-1880, -2700), (-1910, -2800), (-1905, -2960), (-1874, -3032), (-1833, -3050), W(-125, 39)]),
    ("Legion_Via", 10, [W(-125, 39), W(185, 39)]),
    ("NW_Road", 12, [W(185, 39), (-1592, -3385), (-1400, -3385), (-1345, -3376)]),
    # 황궁 동쪽은 석호 턱(58)이라 황궁 뒤(북쪽)로 돌아 포룸으로 간다. 수도교는 아치(z -3430) 밑으로 곧게 지난다
    ("Palace_to_Forum", 12, [(-1405, -3385), (-1405, -3505), (-1240, -3505), (-1212, -3445), (-1208, -3424), (-1120, -3422),
                             (-1030, -3430), (-966, -3430), (-940, -3400), (-905, -3385), (-905, -3303)]),
    ("Gate_Road", 12, [(-760, -2938), (-640, -2938)]),
    ("Ash_Path", 8, [(-1240, -3505), (-1200, -3560), (-1190, -3612)]),        # 에쉬스 마을 계단 윗머리로
]
PLAZAS = [
    # (이름, 가운데 x, z, 폭 x, 깊이 z, yaw)
    ("Forum", -860, -3218, 96, 166, 0),
    ("Palace_Court", -1322, -3375, 56, 28, 0),
    ("Market", -880, -2610, 84, 88, 0),
    ("Legion_Yard", TRAIN[0], TRAIN[1], 40, 52, YAW_ALONG),
]


# ================================================================ 지열: 포도밭 · 온천 계단 못 · 분기공
# 화산재 흙의 계단 비탈에 포도밭(폼페이처럼). 줄은 로컬 x 로 뻗고 간격 SP 로 로컬 z 를 따라 선다
VINES = [
    # (이름, 가운데 x, z, 줄 길이 w, 너비 d, yaw, 줄 간격)
    ("Vinea_SE", -785, -2428, 96, 120, 0, 7),     # 남동 계단 비탈(73→62)
    ("Vinea_SW", -1660, -2390, 56, 104, 0, 7),    # 남서 비탈(74→67)
]
# 온천 계단 못: 수도교 샘 아래 북쪽 비탈을 따라 트래버틴 못이 층층이 흘러내린다. (x, z, 반지름)
POOLS = [(-1000, -3582, 10), (-986, -3603, 8), (-1016, -3600, 6)]
# 분기공(김이 새는 틈과 유황 자국). 석호 턱(46)과 비탈에 손으로 찍었다
FUMAROLES = [
    (-1440, -2990), (-1200, -2992), (-1238, -3372), (-1512, -2692), (-1722, -3010),
    (-1566, -3244), (-1690, -2660), (-1612, -2525), (-1460, -2745), (-1175, -2760),
]


# ================================================================ 에쉬스 마을(북쪽 해안 아래 단, 높이 46)
# 계급 맨 아래 에쉬스가 도시 고원(74) 밑, 바다에 붙은 재 덮인 턱에 판잣집을 짓고 살았다. 고원에서 돌계단 하나로 내려간다.
# (x, z, yaw, 너비, 깊이, 높이, 지붕 무너짐) — 앞(-Z 로컬)이 두 줄 사이 골목(z -3652)을 본다. 사람은 떠났다
ASH_HUTS = [
    (-1303, -3645, 3, 9, 7, 5.5, True), (-1276, -3641, -4, 9, 7, 5.5, False), (-1250, -3638, 2, 11, 8, 6.0, False),
    (-1158, -3640, -2, 10, 8, 6.0, False), (-1131, -3638, 5, 9, 7, 5.5, True), (-1103, -3641, -3, 10, 8, 6.0, False),
    (-1289, -3666, 184, 10, 8, 5.5, False), (-1262, -3667, 177, 9, 7, 5.5, True), (-1232, -3665, 181, 10, 8, 6.0, False),
    (-1150, -3666, 176, 11, 8, 6.0, False), (-1121, -3667, 183, 9, 7, 5.5, False), (-1092, -3665, 179, 10, 8, 6.0, True),
]
ASH_SQUARE = (-1195, -3655)          # 공동 화덕·재 더미
ASH_LANE = [(-1310, -3652), (-1075, -3652)]
ASH_STAIR = ((-1190, -3614), (-1190, -3646))   # 고원 끝 → 턱


# ---------------------------------------------------------------- 검사
def corners(kit, x, z, yaw, pad=0.0):
    x0, x1, z0, z1, h = KIT[kit]
    a = math.radians(yaw)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for lx, lz in ((x0 - pad, z0 - pad), (x1 + pad, z0 - pad), (x1 + pad, z1 + pad), (x0 - pad, z1 + pad)):
        out.append((x + lx * ca + lz * sa, z - lx * sa + lz * ca))
    return out


def inside(pt, poly):
    x, z = pt
    n = len(poly)
    c = False
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def samples(poly, step=8.0):
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    pts = []
    x = min(xs)
    while x <= max(xs):
        z = min(zs)
        while z <= max(zs):
            if inside((x, z), poly):
                pts.append((x, z))
            z += step
        x += step
    return pts or [(sum(xs) / 4, sum(zs) / 4)]


def check():
    problems = []
    occ = {}
    for idx, (kit, x, z, yaw, o) in enumerate(ITEMS):
        if o.get("footprint") == "circle":
            poly = [(x + 70 * math.cos(t / 16 * math.tau), z + 70 * math.sin(t / 16 * math.tau)) for t in range(16)]
        else:
            poly = corners(kit, x, z, yaw)
        pts = samples(poly)
        hs = [H(px, pz) for px, pz in pts]
        if o.get("check", True):
            low = [h for h in hs if h < 64]
            if low:
                problems.append("%s @(%d,%d): 낮은/빈 땅 %d/%d (최저 %.0f)" % (kit, x, z, len(low), len(hs), min(hs)))
            good = [h for h in hs if h >= 0]
            if good and max(good) - min(good) > 8:
                problems.append("%s @(%d,%d): 높낮이 %.1f" % (kit, x, z, max(good) - min(good)))
        if o.get("check", True) and o.get("footprint") != "circle":
            for px, pz in samples(corners(kit, x, z, yaw, pad=-1.0), 4.0):
                key = (round(px / 4), round(pz / 4))
                if key in occ and occ[key] != idx:
                    other = ITEMS[occ[key]]
                    problems.append("겹침: %s @(%d,%d) ↔ %s @(%d,%d)" % (kit, x, z, other[0], other[1], other[2]))
                    break
                occ[key] = idx
    THROUGH = {"City_Gate", "Triumphal_Arch", "Aqueduct_Span", "Bridge_Span", "Aquila"}
    polys = [(kit, x, z, corners(kit, x, z, yaw, pad=-0.5)) for kit, x, z, yaw, o in ITEMS
             if kit not in THROUGH and o.get("footprint") != "circle"]
    for name, w, pts in ROADS:
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, bz - az)
            nx, nz = -(bz - az) / L, (bx - ax) / L
            for i in range(int(L // 4) + 1):
                t = min(1.0, i * 4 / L)
                for sd in (-0.5, 0.0, 0.5):
                    px, pz = ax + (bx - ax) * t + nx * w * sd, az + (bz - az) * t + nz * w * sd
                    if H(px, pz) < 60:
                        problems.append("길 %s (%d,%d) 밑이 낮다 %.0f" % (name, px, pz, H(px, pz)))
                    for kit, x, z, poly in polys:
                        if inside((px, pz), poly):
                            problems.append("길 %s 가 %s @(%d,%d) 를 지난다" % (name, kit, x, z))
    lava = set()
    for x0_, x1_, z_ in lava_runs():
        for xx in range(int(x0_), int(x1_) + 1, ST):
            lava.add((xx, z_))

    def on_lava(px, pz):
        return (X0 + round((px - X0) / ST) * ST, Z0 + round((pz - Z0) / ST) * ST) in lava

    for name, cx, cz, w, d, yaw, sp in VINES:
        poly = [(cx + lx * math.cos(math.radians(yaw)) + lz * math.sin(math.radians(yaw)),
                 cz - lx * math.sin(math.radians(yaw)) + lz * math.cos(math.radians(yaw)))
                for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        for px, pz in samples(poly, 6.0):
            if H(px, pz) < 60:
                problems.append("포도밭 %s (%d,%d) 밑이 낮다 %.0f" % (name, px, pz, H(px, pz)))
                break
            if any(inside((px, pz), q) for _, _, _, q in polys):
                problems.append("포도밭 %s (%d,%d) 가 건물과 겹친다" % (name, px, pz))
                break
    for x, z, r in POOLS:
        for px, pz in ((x, z), (x + r, z), (x - r, z), (x, z + r), (x, z - r)):
            if H(px, pz) < 55:
                problems.append("온천 못 (%d,%d) 가장자리 (%d,%d) 밑이 낮다 %.0f" % (x, z, px, pz, H(px, pz)))
    for x, z in FUMAROLES:
        if not 40 <= H(x, z) <= 80 or on_lava(x, z):
            problems.append("분기공 (%d,%d) 자리 나쁨 %.0f" % (x, z, H(x, z)))
        if any(inside((x, z), q) for _, _, _, q in polys):
            problems.append("분기공 (%d,%d) 가 건물 안" % (x, z))
    for x, z, yaw, w, d, h, fallen in ASH_HUTS:
        a_ = math.radians(yaw)
        poly = [(x + lx * math.cos(a_) + lz * math.sin(a_), z - lx * math.sin(a_) + lz * math.cos(a_))
                for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        hs = [H(px, pz) for px, pz in samples(poly, 3.0)]
        if min(hs) < 44 or max(hs) > 50:
            problems.append("판잣집 (%d,%d) 땅 %.0f..%.0f" % (x, z, min(hs), max(hs)))
        for x2, z2, *_ in ASH_HUTS:
            if (x2, z2) != (x, z) and abs(x2 - x) < 10 and abs(z2 - z) < 9:
                problems.append("판잣집 겹침 (%d,%d)-(%d,%d)" % (x, z, x2, z2))
    seen = set()
    uniq = []
    for p in problems:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq


def lava_cells():
    """칼데라 석호의 빈 칸(20 간격). 격자 가장자리(바다)에 닿지 않는 빈 칸 무리만 고른다(외곽 테 위 작은 구멍은 뺀다)."""
    rows, cols = len(HROWS), len(HROWS[0])
    seen, cells = set(), set()
    for r in range(rows):
        for c in range(cols):
            if HROWS[r][c] >= 0 or (r, c) in seen:
                continue
            st, comp, border = [(r, c)], [], False
            seen.add((r, c))
            while st:
                a, b = st.pop()
                comp.append((a, b))
                border |= a in (0, rows - 1) or b in (0, cols - 1)
                for na, nb in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= na < rows and 0 <= nb < cols and HROWS[na][nb] < 0 and (na, nb) not in seen:
                        seen.add((na, nb))
                        st.append((na, nb))
            if border:
                continue
            for a, b in comp:
                x, z = X0 + b * ST, Z0 + a * ST
                if -1800 <= x <= -860 and -3400 <= z <= -2500:
                    cells.add((x, z))
    return cells


def lava_runs():
    """용암 칸을 줄(z)마다 이어 붙인 구간 (x0, x1, z)."""
    cells = lava_cells()
    runs = []
    for z in sorted({z for _, z in cells}):
        xs = sorted(x for x, zz in cells if zz == z)
        a = xs[0]
        for k in range(1, len(xs) + 1):
            if k == len(xs) or xs[k] != xs[k - 1] + ST:
                runs.append((a, xs[k - 1], z))
                if k < len(xs):
                    a = xs[k]
    return runs


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.2f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(e) for e in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join("%s = %s" % (k, lua(e)) for k, e in v.items()) + "}"
    raise TypeError(v)


def write():
    out = ["-- tools/roman_plan.py 가 만든 칼로도르 폴리스 배치 자료. 손대지 말고 배치표를 고친 뒤 다시 돌린다.", "return {"]
    out.append("\tItems = {")
    nth = {}
    for kit, x, z, yaw, o in ITEMS:
        # 무너진 모양이 둘인 틀은 번갈아 쓴다(같은 폐허가 줄지어 되풀이되지 않게)
        nth[kit] = nth.get(kit, 0) + 1
        name = kit + "_2" if kit in VARIANTS and nth[kit] % 2 == 0 else kit
        d = {"Kit": name, "X": x, "Z": z, "Yaw": yaw, "Group": o.get("group", "Misc"), "Plinth": o.get("plinth", "box")}
        if "y" in o:
            d["Y"] = o["y"]
        if "level" in o:
            d["Level"] = o["level"]
        if o.get("footprint") == "circle":
            d["Circle"] = 70
        if o.get("fire_gladius"):
            d["FireGladius"] = True
        x0, x1, z0, z1, h = KIT[kit]
        d["B"] = [x0, x1, z0, z1]
        out.append("\t\t" + lua(d) + ",")
    out.append("\t},")
    out.append("\tRoads = {")
    for name, w, pts in ROADS:
        out.append("\t\t" + lua({"Name": name, "W": w, "P": [list(p) for p in pts]}) + ",")
    out.append("\t},")
    out.append("\tPlazas = {")
    for name, x, z, w, d, yaw in PLAZAS:
        out.append("\t\t" + lua({"Name": name, "X": x, "Z": z, "W": w, "D": d, "Yaw": yaw}) + ",")
    out.append("\t},")
    out.append("\tLava = { Level = %s, Cell = %d, Runs = {" % (lua(LAVA), ST))
    for a, b, z in lava_runs():
        out.append("\t\t{%d, %d, %d}," % (a, b, z))
    out.append("\t} },")
    out.append("\tSeal = " + lua({"X": G[0], "Z": G[1], "R": SEAL_R, "Obelisks": [list(p) for p in OBELISKS]}) + ",")
    out.append("\tFootprints = " + lua([list(f) for f in FOOTPRINTS]) + ",")
    out.append("\tTrain = " + lua({"X": TRAIN[0], "Z": TRAIN[1], "Yaw": YAW_ALONG}) + ",")
    out.append("\tVines = {")
    for name, cx, cz, w, d, yaw, sp in VINES:
        out.append("\t\t" + lua({"Name": name, "X": cx, "Z": cz, "W": w, "D": d, "Yaw": yaw, "Sp": sp}) + ",")
    out.append("\t},")
    out.append("\tPools = " + lua([list(p) for p in POOLS]) + ",")
    out.append("\tAsh = " + lua({"Huts": [list(h) for h in ASH_HUTS], "Square": list(ASH_SQUARE), "Lane": [list(p) for p in ASH_LANE],
                                  "Stair": [list(p) for p in ASH_STAIR]}) + ",")
    out.append("\tFumaroles = " + lua([list(p) for p in FUMAROLES]) + ",")
    out.append("}")
    path = os.path.join(HERE, "swamp", "roman_data.luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    return path


if __name__ == "__main__":
    probs = check()
    print("배치 %d 개, 길 %d, 광장 %d, 용암 구간 %d" % (len(ITEMS), len(ROADS), len(PLAZAS), len(lava_runs())))
    for p in probs:
        print("  !", p)
    print("문제 %d" % len(probs))
    print(write())
    src = os.path.join(HERE, "Roman_City.luau")
    data = open(os.path.join(HERE, "swamp", "roman_data.luau"), encoding="utf-8").read()
    city = open(src, encoding="utf-8").read()
    assert city.count("--@@DATA@@") == 1
    run = city.replace("--@@DATA@@", "local D = (function()\n" + data + "end)()")
    with open(os.path.join(HERE, "Roman_City_run.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write(run)
    print("Roman_City_run.luau", len(run))
