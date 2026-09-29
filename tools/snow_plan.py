# -*- coding: utf-8 -*-
"""
snow_plan.py — 설원 슈네라이히 도시 배치표. (2026-09-26)

jeolhwa_plan.py 와 같은 방식이다. **자리는 전부 이 표에 손으로 적는다.**
이 파일은 표를 평면도(PNG)로 그리고, 겹침을 검사하고, Studio 가 읽을 Snow_City_data.luau 를 뽑는다.

  서쪽 고원(y≈78, x -4800..-4120, z -2810..-2530)에 도시.
    동문에서 서쪽으로 케셀가(대로)가 뻗고, 한가운데 감정 변환로 광장, 서쪽 끝 차펜 공방.
    북동쪽에 기물군 본부와 체스판 연병장, 대로 남쪽에 프로스티히 공방.
    나머지는 스팀펑크 집. 대로 양쪽 한 줄씩, 그 뒤 골목에 한 줄씩.
    변환로에서 난방관이 높이 걸려 서쪽 공방, 동쪽 본부, 남쪽 골목으로 뻗는다.
  가운데 띠를 내려갔다 올라가는 길 끝, 동쪽 고원에 불탄 설 공방 폐허.

좌표는 스터드, yaw 는 도. 0 이면 모델 앞(-Z)이 -Z 를 본다. 180 이면 +Z.
설원 섬에서 -Z 는 북쪽 바다, +Z 는 남쪽 바다다.

돌리는 법: python tools/snow_plan.py 출력.png [x0,z0,x1,z1] [배율]
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from plan_png import Canvas, seg_rect  # noqa: E402

# Snow_Kit 이 잰 발자국. (base x0 x1 z0 z1), (all x0 x1 z0 z1)
KIT = {
    "Airship": ((-10.0, 10.0, -12.3, 12.3), (-12.8, 12.8, -30.0, 30.0)),
    "Big_Gear": ((-6.0, 6.0, -2.5, 2.5), (-6.7, 6.7, -2.8, 2.8)),
    "Boiler_Tank": ((-3.6, 5.7, -3.6, 3.5), (-3.6, 5.7, -3.6, 3.5)),
    "City_Gate": ((-13.0, 13.0, -3.0, 3.0), (-13.0, 13.0, -3.0, 3.0)),
    "Figuren_HQ": ((-25.1, 25.1, -22.0, 14.0), (-25.1, 25.1, -22.0, 14.6)),
    "Frostig_Werk": ((-12.6, 20.0, -11.0, 9.6), (-15.5, 20.4, -14.2, 10.3)),
    "Gas_Lamp": ((-0.9, 0.9, -2.5, 0.7), (-0.9, 0.9, -2.5, 0.7)),
    "Herzofen": ((-20.0, 20.0, -20.0, 20.0), (-20.4, 20.4, -20.4, 20.4)),
    "Mooring_Mast": ((-4.5, 4.5, -4.5, 4.5), (-4.5, 4.5, -8.9, 4.5)),
    "Sel_Werk_Ruin": ((-12.6, 12.6, -9.6, 9.6), (-15.2, 12.6, -10.0, 10.5)),
    "Steam_House_A": ((-7.6, 7.6, -8.0, 6.6), (-10.3, 8.7, -8.3, 7.2)),
    "Steam_House_B": ((-15.3, 10.6, -9.0, 7.6), (-16.2, 10.6, -9.3, 8.1)),
    "Steam_House_C": ((-6.6, 6.6, -8.0, 6.6), (-9.1, 9.2, -9.1, 7.0)),
    "Zapfen_Werk": ((-45.0, 40.0, -21.0, 18.0), (-46.7, 40.0, -21.0, 18.0)),
}
SMALL = {"Gas_Lamp", "Boiler_Tank", "Big_Gear"}
# 길 끝이 건물 문 앞에 닿도록 낸 것. 겹침 검사에서 뺀다
ROAD_ENDS = {("서대로", "Zapfen_Werk")}

# 들어갈 수 있는 건물. (건물 표의 이름표, 안쪽 방 id, 문 로컬 좌표 x, z, 문 폭)
DOORS = {
    "frostig": ("Frostig", 6.0, -9.0, 3.4),
    "zapfen": ("Zapfen", 0.0, -17.0, 12.0),
    "sel": ("Sel", 6.0, -9.0, 3.4),
    "figuren": ("Figuren", 0.0, -16.0, 5.0),
}

# ================================================================== 도시
# 한가운데 감정 변환로. 사람들은 열원 둘레에 모여 산다. 그래서 도시는 변환로를 도는 두 고리다.
#   안쪽 고리길 r 44, 바깥 고리길 r 86. 집은 고리 사이(r 68)와 바깥(r 105)에 변환로를 바라보고 둘러선다
#   동서 대로가 고리를 꿰어 동문과 차펜 공방으로 간다. 남북 골목은 고원 끝 전망 자리까지
#   각도(θ)와 반지름은 한 채씩 손으로 골랐다. polar() 는 그 값을 좌표로 바꾸기만 한다
CX, CZ = -4440.0, -2670.0


def polar(th, r):
    """θ 0 이 동(+X), 90 이 남(+Z). 돌려주는 값은 x, z 와 변환로를 바라보는 yaw"""
    a = math.radians(th)
    return round(CX + r * math.cos(a), 1), round(CZ + r * math.sin(a), 1), round(90.0 - th, 1)


def ring_house(kind, th, r, grp, tweak=0.0):
    x, z, yaw = polar(th, r)
    return (kind, x, z, yaw + tweak, grp, "")


BUILD = [
    # (틀, x, z, yaw, 묶음, 이름표)  이름표가 DOORS 에 있으면 문을 단다
    ("Herzofen", CX, CZ, 0, "광장", ""),
    ("Zapfen_Werk", -4706, -2670, -90, "차펜공방", "zapfen"),
    ("Figuren_HQ", -4290, -2745, 180, "기물군본부", "figuren"),
    ("Frostig_Werk", -4290, -2627, 0, "프로스티히공방", "frostig"),
    ("City_Gate", -4112, -2670, -90, "동문", ""),
    # 탑 앞(비행선 코를 대는 쪽)이 남쪽 도시를 본다. 북쪽으로 대면 비행선이 설림 나무를 뚫는다
    ("Mooring_Mast", -4172, -2795, 180, "계류탑", ""),
    ("Big_Gear", -4440, -2792, 180, "북쪽전망", ""),
    ("Big_Gear", -4452, -2548, 12, "남쪽전망", ""),
    # 안쪽 고리 (r 68). 이웃한 두 채 사이가 반폭 합 + 4 보다 넓도록 각도를 골랐다
    ring_house("Steam_House_A", -156, 68, "안고리"),
    ring_house("Steam_House_B", -130, 69, "안고리"),
    ring_house("Steam_House_C", -104, 67, "안고리"),
    ring_house("Steam_House_A", -76, 68, "안고리", 3),
    ring_house("Steam_House_B", -50, 69, "안고리"),
    ring_house("Steam_House_C", -22, 67, "안고리"),
    ring_house("Steam_House_A", 26, 68, "안고리"),
    ring_house("Steam_House_B", 50, 69, "안고리"),
    ring_house("Steam_House_C", 76, 67, "안고리", -3),
    ring_house("Steam_House_A", 104, 68, "안고리"),
    ring_house("Steam_House_B", 130, 69, "안고리"),
    ring_house("Steam_House_C", 156, 67, "안고리"),
    # 바깥 고리 (r 105)
    ring_house("Steam_House_C", -160, 105, "바깥고리"),
    ring_house("Steam_House_A", -140, 104, "바깥고리"),
    ring_house("Steam_House_B", -118, 106, "바깥고리"),
    ring_house("Steam_House_B", -62, 106, "바깥고리"),
    ring_house("Steam_House_A", -40, 104, "바깥고리"),
    ring_house("Steam_House_C", -20, 105, "바깥고리"),
    ring_house("Steam_House_A", 20, 104, "바깥고리"),
    ring_house("Steam_House_C", 40, 105, "바깥고리"),
    ring_house("Steam_House_B", 62, 106, "바깥고리"),
    ring_house("Steam_House_A", 118, 104, "바깥고리"),
    ring_house("Steam_House_B", 140, 106, "바깥고리"),
    ring_house("Steam_House_C", 160, 105, "바깥고리"),
    # 서쪽 대로. 공방 앞 한 줄씩
    ("Steam_House_A", -4585, -2695, 180, "서대로", ""),
    ("Steam_House_C", -4618, -2696, 184, "서대로", ""),
    ("Boiler_Tank", -4648, -2700, 0, "서대로", ""),
    ("Steam_House_C", -4583, -2645, 0, "서대로", ""),
    ("Steam_House_B", -4623, -2644, 0, "서대로", ""),
    # 동쪽 대로
    ("Steam_House_A", -4205, -2696, 180, "동대로", ""),
    ("Steam_House_C", -4172, -2698, 176, "동대로", ""),
    ("Steam_House_B", -4240, -2645, 0, "동대로", ""),
    ("Steam_House_A", -4200, -2644, 2, "동대로", ""),
    ("Steam_House_C", -4168, -2645, -3, "동대로", ""),
    ("Boiler_Tank", -4332, -2580, 0, "동대로", ""),
    # 동쪽 고원. 설 공방 폐허와 버려진 마당
    ("Sel_Werk_Ruin", -3050, -2625, 90, "설공방", "sel"),
    ("Boiler_Tank", -3030, -2662, 0, "설공방", ""),
    ("Big_Gear", -3085, -2590, 35, "설공방", ""),
]


def ring_pts(r, a0, a1, step=15):
    pts = []
    a = a0
    while a <= a1 + 1e-6:
        x, z, _ = polar(a, r)
        pts.append((x, z))
        a += step
    return pts


# 가스등. (x, z, yaw). 광장 가장자리를 두르고 팔은 광장 안을 본다.
# 대로 북쪽 가에는 난방관 받침이 서므로 등은 남쪽 가에만
LAMPS = []
for th in (-157, -112, -67, -22, 22, 67, 112, 157):
    x, z, yaw = polar(th, 36)
    LAMPS.append((x, z, yaw))
for x in (-4150, -4185, -4225, -4265, -4305, -4345, -4380):
    LAMPS.append((x, -2657, 0))
for x in (-4500, -4540, -4565, -4605, -4650):
    LAMPS.append((x, -2657, 0))
# 띠 길. 한쪽에만 드문드문
LAMPS += [(-3960, -2673, 180), (-3800, -2675, 180), (-3640, -2685, 180), (-3480, -2663, 180), (-3320, -2643, 180),
          (-3160, -2639, 180)]

ROADS = [
    # (이름, 폭, 재질, 점들). pave 는 평지 포장, ramp 는 땅을 따라 기울어진 길
    ("안고리길", 10, "pave", ring_pts(44, -180, 180)),
    ("바깥고리길북", 10, "pave", ring_pts(86, -170, -10, 10)),
    ("바깥고리길남", 10, "pave", ring_pts(86, 10, 170, 10)),
    ("동대로", 18, "pave", [(CX + 46, CZ), (-4112, CZ)]),
    ("서대로", 18, "pave", [(CX - 46, CZ), (-4684, CZ)]),
    ("북골목", 8, "pave", [(CX, CZ - 46), (CX, -2785)]),
    ("남골목", 8, "pave", [(CX, CZ + 46), (CX, -2556)]),
    ("띠길", 12, "ramp", [(-4100, -2670), (-4040, -2667), (-3960, -2662), (-3880, -2660), (-3800, -2664),
                        (-3720, -2672), (-3640, -2676), (-3560, -2668), (-3480, -2652), (-3400, -2640),
                        (-3320, -2632), (-3240, -2627), (-3160, -2626), (-3072, -2628)]),
]
PAVES = [
    # (이름, x0, z0, x1, z1, 재질) 또는 원판 (이름, cx, cz, r, "disc")
    ("변환로광장", CX, CZ, 39, "disc"),
    ("연병장", -4318, -2717, -4262, -2682, "chess"),
    ("탄마당", -3085, -2665, -3015, -2590, "soot"),
]
# 북쪽 고리관 두 끝은 동서 본관(CZ - 10)과 만나는 각도에서 끝낸다. 81 sin(a) = -10
RING_JOIN = math.degrees(math.asin(10.0 / 81.0))


def ring_end(th):
    x, z, _ = polar(th, 81)
    return (x, z)


# 난방관. 땅에서 7 높이로 쇠 받침 위에 건다. (이름, 점들)
PIPES = [
    ("동관", [(CX + 22, CZ - 10), (-4150, CZ - 10)]),
    ("서관", [(CX - 22, CZ - 10), (-4680, CZ - 10)]),
    ("북관", [(CX - 6, CZ - 22), (CX - 6, -2780)]),
    ("남관", [(CX + 6, CZ + 22), (CX + 6, -2560)]),
    ("고리관북", [ring_end(-180 + RING_JOIN)] + ring_pts(81, -170, -10, 5) + [ring_end(-RING_JOIN)]),
    ("고리관남", ring_pts(81, 10, 170, 5)),
]
# 관이 만나는 자리의 모음통. (x, z, 만나는 관들). 만나는 관은 한 높이로 맞추고,
# 모음통 곁에서 끝나는 관 끝은 땅으로 꺾지 않고 통에 꽂는다
JUNCTIONS = [
    (CX - 6, CZ - 80.75, ["고리관북", "북관"]),
    (CX + 6, CZ + 80.75, ["고리관남", "남관"]),
    (ring_end(-RING_JOIN)[0], CZ - 10, ["고리관북", "동관"]),
    (ring_end(-180 + RING_JOIN)[0], CZ - 10, ["고리관북", "서관"]),
]
# 톱니 무늬 맨홀. 대로와 안쪽 고리길 위
MANHOLES = [(-4200, -2671), (-4360, -2667), (-4560, -2672), (-4650, -2668), (CX + 22, CZ + 38.1), (CX - 22, CZ - 38.1)]
# 김구멍 쇠살판. 길 위에 놓이면 길 윗면에 얹는다. 바깥 고리길 둘은 길 한가운데(r 86)
VENTS = [(CX + 30, CZ + 30), (CX - 30, CZ - 30), (-4600, -2672), (-4250, -2672), (CX + 60.8, CZ - 60.8),
         (CX - 59.7, CZ + 61.9)]

# 도시 자리에 걸려 옮길 설원 지물 (나무는 옮기지 않는다)
CLEAR = ["Drift_-12700_-7900", "Spire_-13000_-8200"]


def airship_pose():
    """계류탑 팔 끝에 비행선 코를 댄다. 탑 앞(-Z 에서 yaw 만큼 돈 쪽)으로 8+30"""
    for k, x, z, yaw, g, tag in BUILD:
        if k == "Mooring_Mast":
            r = math.radians(yaw)
            fx, fz = -math.sin(r), -math.cos(r)
            return (x + fx * 38.0, z + fz * 38.0, yaw + 180.0, 25.4)
    return None


# ------------------------------------------------------------------ 계산과 검사
def rect_world(kind, x, z, yaw, which=0, pad=0.0):
    x0, x1, z0, z1 = KIT[kind][which]
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


def terrain():
    return json.load(open(os.path.join(HERE, "snow_terrain.json"), encoding="utf-8"))


def height_at(T, x, z):
    for tag in ("W", "E", "B"):
        g = T["grids"][tag]
        if g["x0"] <= x <= g["x1"] and g["z0"] <= z <= g["z1"]:
            i = round((x - g["x0"]) / g["st"])
            j = round((z - g["z0"]) / g["st"])
            row = g["rows"][min(j, len(g["rows"]) - 1)]
            return row[1 + min(i, len(row) - 2)]
    return None


def all_items():
    items = [(k, x, z, y, g, t) for k, x, z, y, g, t in BUILD]
    items += [("Gas_Lamp", x, z, y, "가스등", "") for x, z, y in LAMPS]
    return items


def check():
    T = terrain()
    msgs = []
    items = all_items()
    polys = []
    for k, x, z, y, g, t in items:
        pad = 1.0 if k in SMALL else 2.0
        polys.append((f"{g}:{k}@({x},{z})", rect_world(k, x, z, y, 0, pad), k))
    for i in range(len(polys)):
        for j in range(i + 1, len(polys)):
            if overlap(polys[i][1], polys[j][1]):
                msgs.append("건물겹침 " + polys[i][0] + " <> " + polys[j][0])
    road_rects = []
    for name, w, mat, pts in ROADS:
        for a, b in zip(pts, pts[1:]):
            road_rects.append((name, seg_rect(a[0], a[1], b[0], b[1], w)))
    for n, p, k in polys:
        if k == "Gas_Lamp":
            continue
        for rn, rr in road_rects:
            if overlap(p, rr) and k != "City_Gate" and (rn, k) not in ROAD_ENDS:
                msgs.append("길겹침 " + n + " <> " + rn)
    for o in T["objs"]:
        orect = [(o["x"] - o["sx"] / 2, o["z"] - o["sz"] / 2), (o["x"] + o["sx"] / 2, o["z"] - o["sz"] / 2),
                 (o["x"] + o["sx"] / 2, o["z"] + o["sz"] / 2), (o["x"] - o["sx"] / 2, o["z"] + o["sz"] / 2)]
        hit = [n for n, p, k in polys if overlap(p, orect)]
        hit += [rn for rn, rr in road_rects if overlap(rr, orect)]
        if hit:
            if o["folder"] == "설림":
                msgs.append("나무에 걸림(옮기면 안 됨) " + o["name"] + " <> " + ", ".join(hit[:3]))
            elif o["name"] not in CLEAR:
                msgs.append("지물 걸림, CLEAR 에 없음 " + o["name"] + " <> " + ", ".join(hit[:3]))
    pipes = dict(PIPES)
    for jx, jz, names in JUNCTIONS:
        for n in names:
            d = min(seg_dist(jx, jz, a, b) for a, b in zip(pipes[n], pipes[n][1:]))
            if d > 0.3:
                msgs.append("모음통 (%.1f,%.1f) 이 %s 에서 %.2f 떨어짐" % (jx, jz, n, d))
    for vx, vz in VENTS:
        vr = [(vx - 2.6, vz - 2.6), (vx + 2.6, vz - 2.6), (vx + 2.6, vz + 2.6), (vx - 2.6, vz + 2.6)]
        for n, p, k in polys:
            if overlap(vr, p):
                msgs.append("김구멍 (%.0f,%.0f) 이 %s 에 걸림" % (vx, vz, n))
    ap = airship_pose()
    ship = rect_world("Airship", ap[0], ap[1], ap[2], 1, 2.0)
    for o in T["objs"]:
        orect = [(o["x"] - o["sx"] / 2, o["z"] - o["sz"] / 2), (o["x"] + o["sx"] / 2, o["z"] - o["sz"] / 2),
                 (o["x"] + o["sx"] / 2, o["z"] + o["sz"] / 2), (o["x"] - o["sx"] / 2, o["z"] + o["sz"] / 2)]
        if overlap(ship, orect):
            msgs.append("비행선이 " + o["name"] + " 에 걸림")
    for n, p, k in polys:
        if k != "Mooring_Mast" and overlap(ship, p):
            msgs.append("비행선이 " + n + " 에 걸림")
    # 발밑 높이차. 고원 위라면 1~2 여야 한다
    for n, p, k in polys:
        if k in ("Gas_Lamp",):
            continue
        hs = [height_at(T, px, pz) for px, pz in p]
        hs = [h for h in hs if h is not None]
        if hs and max(hs) - min(hs) > 4:
            msgs.append("땅 높이차 %d (%d..%d) %s" % (max(hs) - min(hs), min(hs), max(hs), n))
    return msgs


# ------------------------------------------------------------------ 그림
def render(path, region, sc):
    T = terrain()
    C = Canvas(*region, sc)
    C.rect(region[0], region[1], region[2], region[3], "#5d7fa0")
    for tag in ("B", "E", "W"):
        g = T["grids"][tag]
        st = g["st"]
        for row in g["rows"]:
            z = row[0]
            for i, h in enumerate(row[1:]):
                x = g["x0"] + i * st
                if h is None:
                    continue
                if h >= 76:
                    col = "#3f4046"
                elif h >= 70:
                    col = "#5c5e66"
                else:
                    v = max(0, min(255, 150 + h * 1.4))
                    col = "#%02x%02x%02x" % (int(v * 0.9), int(v * 0.93), int(v))
                C.rect(x - st / 2, z - st / 2, x + st / 2, z + st / 2, col)
    for gx in range(-5000, -2800, 50):
        C.line(gx, region[1], gx, region[3], (1.0 if gx % 100 == 0 else 0.5) / sc, "#20242a")
    for gz in range(-3000, -2350, 50):
        C.line(region[0], gz, region[2], gz, (1.0 if gz % 100 == 0 else 0.5) / sc, "#20242a")
    for o in T["objs"]:
        col = {"설림": "#2f6a4a", "서리바위": "#8a8e98", "빙주": "#9fd8ee", "눈언덕": "#f2f6fa", "돌무지": "#b09a7a"}[o["folder"]]
        if o["name"] in CLEAR:
            col = "#e0506a"
        if o["folder"] == "설림":
            C.circle(o["x"], o["z"], max(o["sx"], o["sz"]) / 2, col, 0.9)
        else:
            C.rect(o["x"] - o["sx"] / 2, o["z"] - o["sz"] / 2, o["x"] + o["sx"] / 2, o["z"] + o["sz"] / 2, col, 0.7)
    for pv in PAVES:
        if pv[-1] == "disc":
            C.circle(pv[1], pv[2], pv[3], "#6b6d74")
            continue
        name, x0, z0, x1, z1, kind = pv
        if kind == "chess":
            n = 0
            for i, x in enumerate(range(int(x0), int(x1), 6)):
                for j, z in enumerate(range(int(z0), int(z1), 6)):
                    C.rect(x, z, x + 6, z + 6, "#e8e8ec" if (i + j) % 2 else "#2c2c30")
        else:
            C.rect(x0, z0, x1, z1, {"stone": "#6b6d74", "soot": "#2a2828"}[kind])
    for name, w, mat, pts in ROADS:
        col = "#6b6d74" if mat == "pave" else "#8c8474"
        for a, b in zip(pts, pts[1:]):
            C.line(a[0], a[1], b[0], b[1], w, col)
        for p in pts[1:-1]:
            C.circle(p[0], p[1], w / 2, col)
    for k, x, z, y, g, t in all_items():
        allp = rect_world(k, x, z, y, 1)
        base = rect_world(k, x, z, y, 0)
        col = {"Herzofen": "#c05a3a", "Zapfen_Werk": "#7a4034", "Figuren_HQ": "#55565c", "Frostig_Werk": "#8a4a34",
               "Sel_Werk_Ruin": "#2b2a2c", "Gas_Lamp": "#f0a050", "Big_Gear": "#b8913f",
               "Boiler_Tank": "#b06a3f", "City_Gate": "#8c8b8a", "Mooring_Mast": "#3a3c42"}.get(k, "#353840")
        C.poly(allp, col, 0.92)
        C.outline(base, 0.6 / sc, "#e0d8c0")
        r = math.radians(y)
        fz = KIT[k][0][2]
        C.circle(x + fz * math.sin(r), z + fz * math.cos(r), 1.6, "#ffcc33")
        if t in DOORS:
            _, dx, dz, dw = DOORS[t]
            c, s = math.cos(r), math.sin(r)
            C.circle(x + dx * c + dz * s, z - dx * s + dz * c, 2.4, "#40e0ff")
    for name, pts in PIPES:
        for a, b in zip(pts, pts[1:]):
            C.line(a[0], a[1], b[0], b[1], 2.6, "#c07a48")
    for x, z in VENTS:
        C.circle(x, z, 2.2, "#ffffff")
    ap = airship_pose()
    if ap:
        C.poly(rect_world("Airship", ap[0], ap[1], ap[2], 1), "#cbbe9e", 0.6)
    C.save(path)


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
              ("VENTS", VENTS), ("MANHOLES", MANHOLES), ("JUNCTIONS", JUNCTIONS), ("CLEAR", CLEAR)]
    lines = ["-- snow_plan.py 가 적은 표. 손으로 고치지 말고 snow_plan.py 를 고쳐 다시 뽑는다", "local D = {}"]
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
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "snow_plan.png")
    region = tuple(float(v) for v in sys.argv[2].split(",")) if len(sys.argv) > 2 else (-4960, -2920, -2900, -2420)
    sc = float(sys.argv[3]) if len(sys.argv) > 3 else 0.6
    render(out, region, sc)
    emit(os.path.join(HERE, "Snow_City_data.luau"))
    msgs = check()
    print("건물 %d, 가스등 %d, 길 %d" % (len(BUILD), len(LAMPS), len(ROADS)))
    for m in msgs:
        print(m)
    print("검사 %d 건" % len(msgs))
