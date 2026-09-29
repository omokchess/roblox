# -*- coding: utf-8 -*-
"""
build_props.py — 설원 슈네라이히 안쪽 방 소품. (2026-09-27)

build_steam.py 와 같은 팔레트와 부품을 쓴다. 키트(build_kit_snow.py)가 JOBS 를 함께 묶는다.
  Steam_Press      차펜 공방 증기 압착기. 앞(-y)으로 판을 운반대에 내린다
  Vertical_Boiler  차펜 공방 선 보일러. 앞(-y)에 아궁이
  Emotion_Proto    설 공방의 초기 감정 변환장치. 유리 핵실이 깨지고 핵에 금이 갔다
  Forge            프로스티히 공방 대장간 화덕. 풀무는 -x 쪽
  Steam_Rifle      장총. 옆모습이 x-z 평면, 총구가 +x(로블록스 -X)
  Steam_Pistol     권총. 같은 방향
  Chess_*          기물군 본부 작전판의 체스 기물 여섯. 한 재질(Iron)로 깎고 편은 Studio 에서 칠한다

모두 원점이 바닥 가운데이고 앞은 -y 다.
돌리는 법: blender --background --python build_props.py [-- 이름...]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
from build_steam import G, pipe, tube  # noqa: E402


# ---------------------------------------------------------------- 도형
def lathe(g, mat, cx, cy, z0, prof, seg=16):
    """z 축 둘레로 깎은 몸. prof 는 아래에서 위로 (반지름, 높이). 반지름 0 은 쓰지 않는다(두 끝은 뚜껑으로 막는다)"""
    assert all(r > 0 for r, _ in prof), "반지름 0 인 점이 있다"
    v = []
    for r, z in prof:
        for k in range(seg):
            a = 2 * math.pi * k / seg
            v.append((cx + r * math.cos(a), cy + r * math.sin(a), z0 + z))
    f = []
    n = len(prof)
    for i in range(n - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            f.append((i * seg + k, i * seg + k2, (i + 1) * seg + k2, (i + 1) * seg + k))
    f.append(tuple(range(seg))[::-1])
    f.append(tuple(range((n - 1) * seg, n * seg)))
    g[mat].add_mesh(v, f)


def ball(g, mat, cx, cy, cz, r, seg=12):
    prof = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a in range(-75, 76, 25)]
    lathe(g, mat, cx, cy, cz, prof, seg)


def ear_clip(pts):
    """단순 다각형을 삼각형 번호 목록으로. 오목해도 된다"""
    n = len(pts)
    area2 = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    ccw = area2 > 0

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(p, a, b, c):
        d1, d2, d3 = cross(a, b, p), cross(b, c, p), cross(c, a, p)
        return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))

    idx = list(range(n))
    tris = []
    while len(idx) > 3:
        for j in range(len(idx)):
            i0, i1, i2 = idx[j - 1], idx[j], idx[(j + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            cr = cross(a, b, c)
            if abs(cr) < 1e-12 or (cr > 0) != ccw:
                continue
            if any(inside(pts[k], a, b, c) for k in idx if k not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            idx.pop(j)
            break
        else:
            raise AssertionError("귀를 못 찾았다. 다각형이 스스로 겹친다")
    tris.append(tuple(idx))
    return tris


def extrude(g, mat, prof, w0, w1, plane="xz"):
    """옆모습 prof 를 두께 방향으로 w0..w1 만큼 밀어 낸 판. plane xz 면 y 로, yz 면 x 로 민다"""
    n = len(prof)

    def P(a, b, w):
        return (a, w, b) if plane == "xz" else (w, a, b)

    v = [P(a, b, w0) for a, b in prof] + [P(a, b, w1) for a, b in prof]
    f = []
    for t in ear_clip(prof):
        f.append(t)
        f.append(tuple(i + n for i in t[::-1]))
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, j + n, i + n))
    g[mat].add_mesh(v, f)


def annulus(g, mat, c, axis, r0, r1, t, n=24):
    """굴대가 axis 인 고리판(바퀴 테). c 가 가운데"""
    cx, cy, cz = c

    def P(u, vv, w):
        if axis == "x":
            return (cx + w, cy + u, cz + vv)
        if axis == "y":
            return (cx + u, cy + w, cz + vv)
        return (cx + u, cy + vv, cz + w)

    v = []
    for w in (-t / 2, t / 2):
        for r in (r0, r1):
            for k in range(n):
                a = 2 * math.pi * k / n
                v.append(P(r * math.cos(a), r * math.sin(a), w))
    A_i, A_o, B_i, B_o = 0, n, 2 * n, 3 * n
    f = []
    for k in range(n):
        k2 = (k + 1) % n
        f.append((A_i + k, A_o + k, A_o + k2, A_i + k2))
        f.append((B_i + k, B_i + k2, B_o + k2, B_o + k))
        f.append((A_o + k, B_o + k, B_o + k2, A_o + k2))
        f.append((A_i + k, A_i + k2, B_i + k2, B_i + k))
    g[mat].add_mesh(v, f)


def wheel(g, rim, spoke, c, axis, r, t, spokes=6, hub=None):
    """살 달린 바퀴. 테, 살, 굴대통"""
    cx, cy, cz = c
    annulus(g, rim, c, axis, r * 0.84, r, t, n=28)
    rm, L_ = r * 0.46, r * 0.8
    for j in range(spokes):
        a = 2 * math.pi * j / spokes
        if axis == "x":
            g[spoke].obox(cx, cy + rm * math.cos(a), cz + rm * math.sin(a), t * 0.6, L_, t * 0.5, rx=a)
        else:
            g[spoke].obox(cx + rm * math.cos(a), cy, cz + rm * math.sin(a), L_, t * 0.6, t * 0.5, ry=-a)
    g[hub or spoke].hcyl(cx, cy, cz, r * 0.16, t * 1.6, axis=axis, seg=12)


def frustum(g, mat, cx, cy, z0, w0, d0, w1, d1, h):
    """네모 뿔대. 아래 w0 x d0, 위 w1 x d1"""
    v = [(cx - w0 / 2, cy - d0 / 2, z0), (cx + w0 / 2, cy - d0 / 2, z0), (cx + w0 / 2, cy + d0 / 2, z0),
         (cx - w0 / 2, cy + d0 / 2, z0), (cx - w1 / 2, cy - d1 / 2, z0 + h), (cx + w1 / 2, cy - d1 / 2, z0 + h),
         (cx + w1 / 2, cy + d1 / 2, z0 + h), (cx - w1 / 2, cy + d1 / 2, z0 + h)]
    f = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    g[mat].add_mesh(v, f)


def arch_xz(g, mat, cx, cy, cz, r0, r1, t, n=10):
    """앞(-y)을 보고 선 반고리 아치. x-z 평면, 두께 t 는 y 쪽"""
    v = []
    for y in (cy - t / 2, cy + t / 2):
        for r in (r0, r1):
            for k in range(n + 1):
                a = math.pi * k / n
                v.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    m = n + 1
    A_i, A_o, B_i, B_o = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f.append((A_i + k, A_o + k, A_o + k + 1, A_i + k + 1))
        f.append((B_i + k, B_i + k + 1, B_o + k + 1, B_o + k))
        f.append((A_o + k, B_o + k, B_o + k + 1, A_o + k + 1))
        f.append((A_i + k, A_i + k + 1, B_i + k + 1, B_i + k))
    for k0 in (0, n):
        f.append((A_i + k0, B_i + k0, B_o + k0, A_o + k0))
    g[mat].add_mesh(v, f)


def cyl_shell(g, mat, cx, cy, z0, z1, r0, r1, a0, a1, n=16):
    """선 원통 껍질 조각(a0..a1 라디안). 깨진 유리통"""
    v = []
    for z in (z0, z1):
        for r in (r0, r1):
            for k in range(n + 1):
                a = a0 + (a1 - a0) * k / n
                v.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    m = n + 1
    A_i, A_o, B_i, B_o = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f.append((A_o + k, B_o + k, B_o + k + 1, A_o + k + 1))
        f.append((A_i + k, A_i + k + 1, B_i + k + 1, B_i + k))
        f.append((A_i + k, A_o + k, A_o + k + 1, A_i + k + 1))
        f.append((B_i + k, B_i + k + 1, B_o + k + 1, B_o + k))
    for k0 in (0, n):
        f.append((A_i + k0, B_i + k0, B_o + k0, A_o + k0))
    g[mat].add_mesh(v, f)


def rivets_ring(g, mat, cx, cy, z, r, n, s=0.14):
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        g[mat].obox(cx + r * math.cos(a), cy + r * math.sin(a), z, s, s, s, rz=a)


def gauge(g, c, r, face="-y", dial="SnowCap"):
    """놋쇠 테 둥근 계기. face 쪽을 본다"""
    x, y, z = c
    g["Brass"].hcyl(x, y, z, r, 0.3, axis="y", seg=16)
    g[dial].hcyl(x, y - 0.14, z, r * 0.82, 0.06, axis="y", seg=16)
    for k in range(5):
        a = math.radians(210 - k * 60)
        g["Iron"].obox(x + r * 0.62 * math.cos(a), y - 0.18, z + r * 0.62 * math.sin(a), r * 0.2, 0.03, r * 0.07, ry=-a)
    g["Iron"].obox(x + r * 0.15, y - 0.2, z + r * 0.12, r * 0.6, 0.03, r * 0.09, ry=-0.7)


# ---------------------------------------------------------------- 차펜 공방
def steam_press(g):
    """
    증기 압착기. 받침 위 두 기둥이 윗 가로보를 떠받치고, 가로보 위 증기 실린더가 피스톤 막대로
    램을 누른다. 위아래 금형 사이에 달군 판. 앞 미끄럼판이 운반대로 내린다. +x 옆에 플라이휠
    """
    g["Iron"].box(0, 0, 0.4, 8.4, 6.4, 0.8)
    g["IronLight"].box(0, 0, 0.85, 7.6, 5.6, 0.1)
    for sx in (-1, 1):
        x = sx * 3.3
        g["Iron"].box(x, 0.3, 6.8, 1.4, 4.4, 12.0)
        g["IronLight"].box(x, -1.95, 6.8, 1.0, 0.1, 11.0)
        for k in range(8):
            for dx in (-0.3, 0.3):
                g["Brass"].box(x + dx, -2.05, 1.6 + k * 1.45, 0.16, 0.12, 0.16)
    # 모루와 금형, 달군 판
    g["Iron"].box(0, 0, 2.4, 5.2, 4.4, 3.2)
    g["IronLight"].box(0, -0.2, 4.25, 4.2, 3.4, 0.5)
    g["Glow"].box(0, -0.2, 4.62, 3.2, 2.4, 0.24)
    g["IronLight"].box(0, -0.2, 6.35, 4.2, 3.4, 0.5)
    g["Iron"].box(0, -0.2, 7.4, 4.6, 3.8, 1.6)
    for sx in (-1, 1):
        g["Brass"].box(sx * 2.45, -0.2, 7.4, 0.3, 1.2, 1.6)
    # 피스톤 막대와 윗 가로보
    g["IronLight"].cyl(0, -0.2, 8.2, 0.45, 0.45, 4.6, seg=14)
    g["Brass"].cyl(0, -0.2, 8.2, 0.7, 0.7, 0.35, seg=14)
    g["Brass"].cyl(0, -0.2, 12.45, 0.7, 0.7, 0.35, seg=14)
    g["Iron"].box(0, 0.3, 13.6, 8.0, 4.8, 1.6)
    g["Brass"].box(0, -2.12, 13.6, 7.4, 0.12, 0.3)
    rivet_x = [-3.4 + k * 0.85 for k in range(9)]
    for x in rivet_x:
        g["Brass"].box(x, -2.12, 14.15, 0.14, 0.12, 0.14)
        g["Brass"].box(x, -2.12, 13.05, 0.14, 0.12, 0.14)
    # 증기 실린더와 들이는 목
    g["Copper"].cyl(0, 0.3, 14.4, 1.7, 1.7, 3.8, seg=20)
    for z in (14.6, 17.9):
        g["Brass"].cyl(0, 0.3, z - 0.2, 1.85, 1.85, 0.4, seg=20)
    rivets_ring(g, "Iron", 0, 0.3, 16.25, 1.75, 16)
    g["Iron"].cyl(0, 0.3, 18.2, 1.9, 1.2, 0.5, seg=20)
    g["Copper"].cyl(0, 0.3, 18.7, 0.6, 0.6, 0.3, seg=12)
    g["Brass"].cyl(0, 0.3, 18.85, 0.85, 0.85, 0.15, seg=12)
    # 실린더에서 내려오는 배기관. 뒤로 돌아 기둥을 따라 받침까지
    pipe(g, [(1.2, 1.5, 16.0), (2.6, 1.5, 16.0), (2.6, 1.5, 12.8)], 0.28, mat="Copper")
    # 압력계, 조종 손잡이
    gauge(g, (-2.3, -2.35, 13.6), 0.55)
    g["Iron"].hcyl(-3.3, -2.3, 5.0, 0.22, 0.6, axis="y", seg=10)
    g["Iron"].obox(-3.55, -2.45, 6.05, 0.2, 0.2, 2.2, ry=0.25)
    ball(g, "Brass", -3.82, -2.45, 7.15, 0.26)
    # 플라이휠. +x 기둥 바깥에 굴대로 걸린다
    wheel(g, "Iron", "Iron", (4.62, 0.3, 6.0), "x", 3.0, 0.5, spokes=6, hub="Brass")
    g["IronLight"].hcyl(4.3, 0.3, 6.0, 0.35, 1.3, axis="x", seg=12)
    # 운반대로 내리는 미끄럼판과 양옆 난간
    g["IronLight"].obox(0, -2.9, 4.37, 3.4, 1.5, 0.15, rx=0.245)
    for sx in (-1, 1):
        g["Brass"].obox(sx * 1.75, -2.9, 4.6, 0.12, 1.5, 0.35, rx=0.245)
    g["LampPt"].box(0, -1.2, 5.1, 0.3, 0.3, 0.3)


def vertical_boiler(g):
    """
    선 보일러. 팔각 받침 위 쇠 화실(앞에 아궁이 문), 리벳 띠 두른 구리 몸통, 돔 뚜껑과 증기 목.
    앞 오른쪽에 수위 유리관, 앞 위에 압력계, 돔에 안전밸브, 옆에 밸브 달린 급수관
    """
    g["Stone"].cyl(0, 0, 0, 3.7, 3.7, 0.5, seg=8)
    g["Iron"].cyl(0, 0, 0.5, 3.25, 3.25, 3.3, seg=24)
    g["Brass"].cyl(0, 0, 3.62, 3.4, 3.4, 0.36, seg=24)
    rivets_ring(g, "Iron", 0, 0, 3.8, 3.42, 24)
    # 아궁이: 문틀, 불빛, 쇠살, 경첩, 빗장, 재받이
    g["Iron"].box(0, -3.22, 2.15, 2.8, 0.5, 2.3)
    g["Glow"].box(0, -3.49, 2.15, 1.9, 0.06, 1.5)
    for k in range(5):
        g["Iron"].box(0, -3.55, 1.55 + k * 0.3, 2.0, 0.1, 0.1)
    for k in range(3):
        g["Iron"].box(-0.6 + k * 0.6, -3.55, 2.15, 0.1, 0.1, 1.6)
    for z in (1.35, 2.95):
        g["Brass"].cyl(-1.45, -3.5, z - 0.22, 0.13, 0.13, 0.44, seg=8)
    g["Brass"].box(1.15, -3.62, 2.15, 0.16, 0.14, 0.7)
    g["IronLight"].box(0, -3.3, 0.8, 2.2, 0.45, 0.5)
    g["Brass"].box(0, -3.56, 0.8, 0.7, 0.1, 0.12)
    # 구리 몸통과 리벳 띠
    g["Copper"].cyl(0, 0, 3.8, 3.0, 3.0, 8.4, seg=24)
    for z in (4.4, 8.0, 11.6):
        g["Brass"].cyl(0, 0, z - 0.25, 3.18, 3.18, 0.5, seg=24)
        rivets_ring(g, "Iron", 0, 0, z, 3.22, 22)
    for k in range(8):   # 뒤쪽 세로 이음 리벳 줄
        g["Iron"].box(0, 3.04, 5.0 + k * 0.8, 0.14, 0.12, 0.14)
    # 돔, 증기 목, 안전밸브
    g["Copper"].cyl(0, 0, 12.2, 3.0, 1.4, 1.4, seg=24)
    g["Brass"].cyl(0, 0, 13.6, 1.5, 1.5, 0.3, seg=16)
    g["Copper"].cyl(0, 0, 13.9, 0.7, 0.7, 0.6, seg=12)
    g["Brass"].cyl(0, 0, 14.25, 0.95, 0.95, 0.2, seg=12)
    g["Brass"].cyl(1.2, 1.0, 12.6, 0.28, 0.28, 1.4, seg=10)
    g["Iron"].obox(1.95, 1.0, 14.05, 1.7, 0.14, 0.14, ry=0.08)
    g["Iron"].box(2.75, 1.0, 13.85, 0.4, 0.4, 0.4)
    # 수위 유리관 (앞 오른쪽)
    a = math.radians(-58)
    px, py = 3.3 * math.cos(a), 3.3 * math.sin(a)
    for z in (5.1, 9.3):
        g["Brass"].box(px, py, z, 0.4, 0.4, 0.35)
        g["Brass"].box(px * 0.95, py * 0.95, z, 0.3, 0.3, 0.2)
    g["Glass"].cyl(px, py, 5.28, 0.17, 0.17, 3.85, seg=10)
    g["Iron"].cyl(px, py, 5.28, 0.09, 0.09, 2.2, seg=6)   # 물높이
    # 압력계 (앞 위)
    g["Iron"].hcyl(0, -3.2, 10.2, 0.14, 0.5, axis="y", seg=8)
    gauge(g, (0, -3.55, 10.2), 0.62)
    # 급수관: 옆(-x)으로 나와 꺾여 바닥으로. 밸브 손바퀴
    pipe(g, [(-2.9, 0.6, 6.4), (-4.0, 0.6, 6.4), (-4.0, 0.6, 0.5)], 0.32, mat="Copper")
    wheel(g, "Brass", "Brass", (-4.0, 0.0, 3.4), "y", 0.6, 0.12, spokes=4)
    g["Iron"].hcyl(-4.0, 0.3, 3.4, 0.08, 0.5, axis="y", seg=6)
    g["LampPt"].box(0, -3.9, 2.1, 0.3, 0.3, 0.3)


# ---------------------------------------------------------------- 설 공방
def emotion_proto(g):
    """
    초기 감정 변환장치. 변환로를 작게 줄인 꼴. 쇠 몸통에 구리 코일을 감고, 위 유리 핵실에
    붉은 핵을 넣었다. 불에 그을려 앞 유리가 깨지고 핵과 몸통에 금이 가 희미하게 달아 있다
    """
    g["Soot"].cyl(0, 0, 0, 2.8, 2.8, 0.35, seg=8)
    g["Iron"].cyl(0, 0, 0.35, 1.8, 1.8, 3.6, seg=20)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        g["IronLight"].obox(1.84 * math.cos(a), 1.84 * math.sin(a), 2.15, 0.3, 0.26, 3.5, rz=a)
    g["Brass"].cyl(0, 0, 1.0, 1.95, 1.95, 0.35, seg=20)
    g["Brass"].cyl(0, 0, 3.55, 1.95, 1.95, 0.35, seg=20)
    # 구리 코일. 몸통을 세 바퀴 감는다
    pts = []
    for i in range(73):
        t = i / 72
        a = 2 * math.pi * 3 * t
        pts.append((2.08 * math.cos(a), 2.08 * math.sin(a), 1.5 + 1.9 * t))
    for p0, p1 in zip(pts, pts[1:]):
        tube(g, "Copper", p0, p1, 0.12, seg=8)
    # 몸통 앞의 달아오른 금
    crack = [(-100, 0.6), (-94, 1.1), (-99, 1.6), (-91, 2.2), (-96, 2.7), (-88, 3.3), (-93, 3.9)]
    for (a0, z0), (a1, z1) in zip(crack, crack[1:]):
        r = 1.82
        p0 = (r * math.cos(math.radians(a0)), r * math.sin(math.radians(a0)), z0)
        p1 = (r * math.cos(math.radians(a1)), r * math.sin(math.radians(a1)), z1)
        tube(g, "Core", p0, p1, 0.06, seg=5)
    # 유리 핵실. 앞(-y) 쪽이 깨져 비었다
    g["Brass"].cyl(0, 0, 3.95, 1.6, 1.6, 0.3, seg=20)
    cyl_shell(g, "Glass", 0, 0, 4.25, 6.3, 1.25, 1.33, math.radians(-50), math.radians(230), n=18)
    cyl_shell(g, "Glass", 0, 0, 4.25, 4.9, 1.25, 1.33, math.radians(-130), math.radians(-50), n=6)
    for k in range(6):
        a = 2 * math.pi * k / 6 + math.pi / 6
        if k == 4:   # 앞 살 하나는 휘었다
            g["Brass"].obox(1.45 * math.cos(a) * 1.1, 1.45 * math.sin(a) * 1.1, 5.2, 0.14, 0.14, 2.1, rx=0.25)
            continue
        g["Brass"].box(1.45 * math.cos(a), 1.45 * math.sin(a), 5.27, 0.14, 0.14, 2.05)
    g["Brass"].cyl(0, 0, 6.3, 1.6, 1.0, 0.4, seg=20)
    ann = (0, 0, 6.95)
    annulus(g, "Brass", ann, "y", 0.22, 0.34, 0.12, n=14)
    # 금 간 핵. 큰 조각 둘과 떨어진 부스러기
    g["Core"].obox(0.05, 0.1, 5.1, 0.55, 0.55, 1.1, rz=0.7, rx=0.12)
    g["Core"].obox(-0.12, -0.05, 5.95, 0.38, 0.38, 0.62, rz=0.3, ry=0.4)
    g["Core"].obox(0.9, -1.9, 0.45, 0.28, 0.22, 0.18, rz=0.9)
    # 받침 위 유리 조각
    for x, y, rz in ((0.6, -2.2, 0.3), (-0.7, -2.3, 1.2), (1.5, -1.6, 2.0), (-1.4, -1.9, 0.8), (0.1, -2.55, 2.6)):
        g["Glass"].obox(x, y, 0.39, 0.5, 0.32, 0.05, rz=rz)
    # 부서진 계기. 그을린 판에 휜 바늘
    gauge(g, (1.0, -1.72, 2.55), 0.42, dial="Char")
    # 옆으로 나와 꺾여 내려가다 끊긴 관. 끝 테는 바닥에 떨어졌다
    pipe(g, [(1.75, 0.3, 2.3), (2.75, 0.3, 2.3), (2.75, 0.3, 1.0)], 0.26, mat="Copper")
    g["Brass"].obox(2.95, -0.5, 0.42, 0.75, 0.75, 0.14, rz=0.4, rx=0.2)


# ---------------------------------------------------------------- 프로스티히 공방
def forge(g):
    """
    대장간 화덕. 벽돌 화덕 위 쇠 화로에 숯불, 앞에 아치 재구덩이, 네모 후드와 굴뚝(천장 16 까지).
    -x 에 풀무(나무 판과 가죽, 놋쇠 부리), +x 에 연장 걸이와 담금질 물통
    """
    g["Brick"].box(0, 0, 1.6, 6.0, 6.0, 3.2)
    g["StoneTrim"].box(0, 0, 3.4, 6.4, 6.4, 0.4)
    g["StoneTrim"].box(0, 0, 0.15, 6.3, 6.3, 0.3)
    # 앞 재구덩이: 어두운 구멍, 벽돌 아치, 속 불씨
    g["Soot"].box(0, -3.02, 1.0, 2.2, 0.1, 1.4)
    arch_xz(g, "StoneTrim", 0, -3.05, 1.7, 1.1, 1.45, 0.3)
    for sx in (-1, 1):
        g["StoneTrim"].box(sx * 1.27, -3.05, 1.0, 0.35, 0.3, 1.4)
    g["Glow"].box(0, -2.95, 0.55, 1.8, 0.1, 0.35)
    # 화로: 쇠 테, 숯불, 숯 덩이
    for sx in (-1, 1):
        g["Iron"].box(sx * 1.35, 0, 3.75, 0.3, 3.0, 0.3)
        g["Iron"].box(0, sx * 1.35, 3.75, 3.0, 0.3, 0.3)
    g["Glow"].box(0, 0, 3.66, 2.4, 2.4, 0.12)
    for x, y, rz, s in ((-0.6, -0.4, 0.4, 0.45), (0.5, 0.3, 1.1, 0.5), (-0.2, 0.6, 0.2, 0.4), (0.7, -0.6, 2.0, 0.35),
                        (-0.8, 0.5, 1.5, 0.35), (0.1, -0.1, 0.8, 0.4)):
        g["Char"].obox(x, y, 3.8, s, s * 0.8, s * 0.6, rz=rz)
    for x, y in ((0.0, 0.2), (-0.4, -0.2), (0.4, -0.1)):
        g["Glow"].obox(x, y, 3.86, 0.3, 0.26, 0.2, rz=x * 3)
    # 후드: 뒤 두 기둥이 받치는 쇠 뿔대, 아래 테와 리벳
    for sx in (-1, 1):
        g["Iron"].box(sx * 2.4, 2.4, 4.8, 0.35, 0.35, 2.4)
    frustum(g, "Iron", 0, 0, 6.0, 5.4, 5.4, 1.9, 1.9, 2.4)
    for sx in (-1, 1):
        g["IronLight"].box(sx * 2.75, 0, 6.15, 0.2, 5.7, 0.3)
        g["IronLight"].box(0, sx * 2.75, 6.15, 5.7, 0.2, 0.3)
    for k in range(7):
        t = -2.4 + k * 0.8
        for sx in (-1, 1):
            g["Brass"].box(sx * 2.88, t, 6.15, 0.1, 0.14, 0.14)
            g["Brass"].box(t, sx * 2.88, 6.15, 0.14, 0.1, 0.14)
    # 굴뚝과 놋쇠 띠, 바람막이 손잡이
    g["Iron"].cyl(0, 0, 8.4, 0.95, 0.95, 7.8, seg=16)
    for z in (9.0, 11.4, 13.8):
        g["Brass"].cyl(0, 0, z, 1.05, 1.05, 0.3, seg=16)
    g["Iron"].obox(-1.1, 0, 9.8, 0.9, 0.12, 0.12, ry=0.2)
    ball(g, "Brass", -1.55, 0, 9.9, 0.14)
    # 풀무 (-x). 나무 받침대, 아래 판, 벌어진 윗 판, 가죽 주름, 놋쇠 부리, 손잡이
    for x in (-4.0, -5.8):
        g["Wood"].box(x, 0, 1.3, 0.3, 1.6, 2.6)
    g["Wood"].box(-4.9, 0, 2.7, 2.4, 1.8, 0.2)
    g["Wood"].box(-4.9, 0, 2.95, 3.0, 1.8, 0.15)
    extrude(g, "Banner", [(-3.4, 3.03), (-6.3, 3.03), (-6.3, 3.75), (-3.4, 3.1)], -0.8, 0.8)
    g["Wood"].obox(-4.9, 0, 3.45, 3.1, 1.8, 0.15, ry=0.23)
    g["Wood"].obox(-6.55, 0, 3.95, 0.14, 0.4, 1.2, ry=0.23)
    g["Brass"].hcyl(-3.15, 0, 3.08, 0.2, 0.7, axis="x", seg=10)
    # 연장 걸이 (+x 옆면): 쇠 막대와 집게, 망치, 부지깽이
    g["Iron"].box(3.25, 0, 2.9, 0.12, 4.4, 0.12)
    for y in (-1.6, 1.6):
        g["Iron"].box(3.15, y, 2.9, 0.3, 0.12, 0.12)
    g["Iron"].obox(3.36, -0.9, 2.1, 0.08, 0.1, 1.7, rx=0.12)
    g["Iron"].obox(3.36, -0.7, 2.1, 0.08, 0.1, 1.7, rx=-0.12)
    g["Wood"].box(3.36, 0.3, 2.2, 0.12, 0.12, 1.4)
    g["Iron"].box(3.36, 0.3, 1.45, 0.3, 0.45, 0.25)
    g["Iron"].box(3.36, 1.1, 2.0, 0.08, 0.08, 1.8)
    # 담금질 물통 (+x 앞 모서리)
    for sx in (-1, 1):
        g["Iron"].box(4.0 + sx * 0.6, -1.2, 0.6, 0.12, 2.8, 1.2)
        g["Iron"].box(4.0, -1.2 + sx * 1.35, 0.6, 1.3, 0.12, 1.2)
    g["Iron"].box(4.0, -1.2, 0.08, 1.3, 2.8, 0.16)
    g["Glass"].box(4.0, -1.2, 1.0, 1.1, 2.6, 0.1)
    g["LampPt"].box(0, 0, 4.4, 0.3, 0.3, 0.3)


def cone_between(g, mat, s, e, r0, r1, seg=12):
    """s 에서 e 로 가늘어지는 원뿔대 (모루 뿔)"""
    from mathutils import Matrix, Vector
    import bmesh
    s, e = Vector(s), Vector(e)
    d = e - s
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(g[mat].bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1,
                          depth=d.length, matrix=Matrix.Translation((s + e) / 2) @ rot)


def anvil(g):
    """
    그루터기 위 모루. 나무 그루터기에 쇠 띠, 모루 몸은 옆모습을 민 것, 뿔은 +x 로 가늘어진다.
    윗면에 망치 하나
    """
    lathe(g, "Wood", 0, 0, 0, [(0.95, 0.0), (0.9, 0.15), (0.85, 0.3), (0.85, 1.85), (0.8, 2.0)], 14)
    for z in (0.5, 1.6):
        g["Iron"].cyl(0, 0, z, 0.89, 0.89, 0.18, seg=14)
    body = [(-0.8, 2.0), (0.8, 2.0), (0.7, 2.2), (0.35, 2.35), (0.35, 2.75), (0.75, 2.9), (0.75, 3.3), (-1.05, 3.3),
            (-1.15, 3.1), (-0.45, 2.95), (-0.35, 2.75), (-0.35, 2.35), (-0.7, 2.2)]
    extrude(g, "Iron", body, -0.34, 0.34)
    cone_between(g, "Iron", (0.75, 0, 3.1), (1.75, 0, 3.12), 0.3, 0.05, seg=12)
    g["IronLight"].box(-0.15, 0, 3.32, 1.7, 0.6, 0.04)
    g["Iron"].box(-0.7, 0, 3.3, 0.16, 0.16, 0.06)   # 구멍 자리
    # 망치
    g["Wood"].obox(0.0, 0.0, 3.42, 1.3, 0.1, 0.1, rz=0.5)
    g["Iron"].obox(-0.57, -0.31, 3.45, 0.22, 0.45, 0.2, rz=0.5)


def steam_rifle(g):
    """
    장총. 옆모습이 x-z 평면이고 두께는 y. 개머리판은 -x, 총구는 +x.
    나무 개머리와 앞총대, 쇠 기관부에 놋쇠 옆판, 총열 띠, 조준경, 아래 증기통과 작은 계기
    """
    stock = [(-3.8, 0.05), (-3.8, 1.15), (-2.0, 1.05), (-1.0, 1.0), (-0.7, 0.95), (-0.7, 0.55), (-1.0, 0.5),
             (-1.25, 0.12), (-1.55, 0.18), (-1.9, 0.55)]
    extrude(g, "Wood", stock, -0.2, 0.2)
    g["Brass"].box(-3.86, 0, 0.6, 0.12, 0.42, 1.12)
    g["Iron"].box(-0.05, 0, 0.88, 1.3, 0.34, 0.55)
    g["Brass"].box(-0.05, -0.18, 0.86, 1.0, 0.04, 0.34)
    for x in (-0.45, 0.35):
        g["Iron"].box(x, -0.21, 0.86, 0.1, 0.03, 0.1)
    g["Wood"].box(1.6, 0, 0.8, 2.0, 0.36, 0.34)
    g["Iron"].hcyl(2.2, 0, 1.03, 0.13, 3.2, axis="x", seg=10)
    for x in (1.2, 2.45):
        g["Brass"].hcyl(x, 0, 0.92, 0.23, 0.18, axis="x", seg=10)
    g["Brass"].hcyl(3.72, 0, 1.03, 0.18, 0.18, axis="x", seg=10)
    g["Brass"].hcyl(0.45, 0, 1.46, 0.15, 1.9, axis="x", seg=10)
    for x in (-0.4, 1.3):
        g["Brass"].hcyl(x, 0, 1.46, 0.19, 0.14, axis="x", seg=10)
    for x in (0.0, 0.9):
        g["Iron"].box(x, 0, 1.25, 0.14, 0.12, 0.22)
    # 방아쇠울과 방아쇠, 공이치기
    g["Iron"].box(-0.3, 0, 0.44, 0.6, 0.1, 0.06)
    g["Iron"].box(-0.58, 0, 0.53, 0.06, 0.1, 0.2)
    g["Brass"].obox(-0.2, 0, 0.53, 0.06, 0.08, 0.2, ry=0.3)
    g["Iron"].obox(-0.6, 0, 1.2, 0.12, 0.1, 0.3, ry=-0.4)
    # 앞총대 밑 증기통과 계기
    g["Copper"].hcyl(1.45, 0, 0.42, 0.2, 1.0, axis="x", seg=10)
    for x in (0.95, 1.95):
        g["Brass"].hcyl(x, 0, 0.42, 0.23, 0.08, axis="x", seg=10)
    g["SnowCap"].hcyl(1.45, -0.21, 0.42, 0.11, 0.04, axis="y", seg=10)


def steam_pistol(g):
    """권총. 장총과 같은 방향. 나무 손잡이, 쇠 틀, 구리 탄창통, 총열과 놋쇠 총구 테"""
    grip = [(-0.35, 0.5), (-0.02, 0.5), (-0.12, 0.2), (-0.26, 0.02), (-0.5, 0.0), (-0.5, 0.12)]
    extrude(g, "Wood", grip, -0.11, 0.11)
    g["Iron"].box(-0.12, 0, 0.64, 0.6, 0.18, 0.3)
    g["Copper"].hcyl(0.3, 0, 0.64, 0.17, 0.36, axis="x", seg=10)
    g["Iron"].hcyl(0.95, 0, 0.7, 0.07, 1.0, axis="x", seg=8)
    g["Iron"].box(0.8, 0, 0.62, 0.7, 0.1, 0.08)
    g["Brass"].hcyl(1.43, 0, 0.7, 0.1, 0.08, axis="x", seg=8)
    g["Iron"].box(0.02, 0, 0.36, 0.34, 0.08, 0.05)
    g["Brass"].box(0.0, 0, 0.44, 0.05, 0.06, 0.14)
    g["Iron"].obox(-0.4, 0, 0.84, 0.08, 0.08, 0.2, ry=-0.5)


# ---------------------------------------------------------------- 기물군 본부 영사기
def _bar(g, mat, x, p0, p1, w, t):
    """y-z 평면에서 p0 에서 p1 로 가는 납작한 막대(폭 w 는 x, 두께 t)"""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    L_ = math.hypot(dy, dz)
    g[mat].obox(x, (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, w, L_, t, rx=math.atan2(dz, dy))


def _holed_reel(g, cy, cz, R, holes=6):
    """
    구멍 뚫린 놋쇠 필름 릴. x 축 굴대에 옆판 둘(x ±0.13), 사이에 감긴 필름, 볼트 박은 굴대통.
    옆판은 구멍 하나가 든 부채꼴을 구멍 가운데 선으로 반씩 갈라 오목한 다각형으로 민다(구멍은 뚫린 채)
    """
    rh, rc, h = 0.26 * R, 0.6 * R, 0.2 * R
    step = 2 * math.pi / holes
    halves = []
    for s in range(holes):
        a0 = s * step + step / 2
        am = a0 + step / 2
        ur = (math.cos(am), math.sin(am))
        ut = (-math.sin(am), math.cos(am))
        C = (rc * ur[0], rc * ur[1])
        for side in (-1, 1):
            a_edge = am + side * step / 2
            pts = [(rh * math.cos(a), rh * math.sin(a)) for a in [a_edge + (am - a_edge) * k / 3 for k in range(4)]]
            for k in range(9):
                psi = math.pi * k / 8
                pts.append((C[0] + h * (-math.cos(psi) * ur[0] + side * math.sin(psi) * ut[0]),
                            C[1] + h * (-math.cos(psi) * ur[1] + side * math.sin(psi) * ut[1])))
            pts += [(R * math.cos(a), R * math.sin(a)) for a in [am + (a_edge - am) * k / 3 for k in range(4)]]
            halves.append([(cy + y, cz + z) for y, z in pts])
    for x in (-0.13, 0.13):
        for poly in halves:
            extrude(g, "Brass", poly, x - 0.035, x + 0.035, plane="yz")
    g["Char"].hcyl(0, cy, cz, 0.44 * R, 0.2, axis="x", seg=20)
    g["Brass"].hcyl(0, cy, cz, 0.28 * R, 0.5, axis="x", seg=16)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        for x in (-0.26, 0.26):
            g["Iron"].obox(x, cy + 0.17 * R * math.cos(a), cz + 0.17 * R * math.sin(a), 0.04, 0.09, 0.09, rx=a)


def film_projector(g):
    """
    기록 영사기. 옛 영화 영사기 꼴(사용자가 준 사진): 튼튼한 삼각대 위 넓은 나무 받침판에 계단진 가죽
    몸통, 몸통에 반쯤 묻혀 붙은 구멍 뚫린 놋쇠 릴 둘(위 하나, 뒤 하나), 앞 위쪽으로 긴 검은 경통.
    +x 옆면(방에서 보이는 쪽)에 볼트 박은 큰 쇠 원판과 놋쇠 징을 따라 도는 필름 띠.
    앞은 -y. 렌즈 끝은 (0, -3.25, 5.95)
    """
    # 삼각대: 각진 쇠 다리 셋, 머리 받침, 가운데 기둥과 벌림대, 발굽
    head_z, foot_r = 3.3, 1.75
    mids = []
    for a_deg in (90, 210, 330):
        a = math.radians(a_deg)
        top = (0.3 * math.cos(a), 0.3 * math.sin(a), head_z)
        bot = (foot_r * math.cos(a), foot_r * math.sin(a), 0.1)
        tube(g, "Iron", top, bot, 0.12, seg=4)
        g["IronLight"].cyl(bot[0], bot[1], 0, 0.17, 0.14, 0.12, seg=8)
        k = (head_z - 1.9) / (head_z - 0.1)
        mids.append(tuple(t + (b - t) * k for t, b in zip(top, bot)))
    g["Iron"].box(0, 0, head_z + 0.15, 0.9, 0.9, 0.3)
    g["Iron"].cyl(0, 0, 1.9, 0.12, 0.12, head_z - 1.9, seg=8)
    for m in mids:
        tube(g, "Iron", (0, 0, 1.9), m, 0.06, seg=6)
    g["Brass"].cyl(0, 0, 1.82, 0.16, 0.16, 0.16, seg=10)

    # 받침판
    g["Timber"].box(0, 0, 3.72, 2.5, 4.4, 0.25)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Brass"].box(sx * 1.2, sy * 2.15, 3.72, 0.14, 0.14, 0.27)

    # 몸통: 계단진 옆모습을 x 로 민다
    body = [(-1.6, 3.85), (1.4, 3.85), (1.4, 5.6), (1.15, 5.95), (0.2, 5.95), (0.0, 6.35), (-0.8, 6.35),
            (-0.95, 6.75), (-1.6, 6.75)]
    extrude(g, "Leather", body, -0.85, 0.85, plane="yz")
    for y, z0, z1 in ((-1.6, 3.85, 6.75), (1.4, 3.85, 5.6)):   # 앞뒤 세로 모서리 놋쇠
        for sx in (-1, 1):
            g["Brass"].box(sx * 0.86, y, (z0 + z1) / 2, 0.06, 0.1, z1 - z0)
    for sx in (-1, 1):
        g["Brass"].box(sx * 0.86, -0.1, 3.9, 0.06, 3.0, 0.1)
    # 몸통 윗면 환기 창살
    for k in range(4):
        g["Iron"].box(0, 0.45 + k * 0.18, 5.97, 1.2, 0.06, 0.04)

    # 옆면(±x): 볼트 박은 큰 쇠 원판. +x 쪽에 필름 띠와 놋쇠 징
    for sx in (-1, 1):
        x = sx * 0.89
        g["Iron"].hcyl(x, 0.2, 5.0, 0.75, 0.08, axis="x", seg=28)
        g["Brass"].hcyl(sx * 0.93, 0.2, 5.0, 0.2, 0.08, axis="x", seg=14)
        for k in range(8):
            a = 2 * math.pi * k / 8
            g["Brass"].hcyl(sx * 0.94, 0.2 + 0.6 * math.cos(a), 5.0 + 0.6 * math.sin(a), 0.06, 0.06, axis="x", seg=8)
    path = [(1.4, 4.6), (0.9, 4.1), (-0.4, 4.1), (-0.95, 4.6), (-0.95, 5.5), (-0.3, 5.85), (0.35, 5.93)]
    for p0, p1 in zip(path, path[1:]):
        _bar(g, "Char", 0.95, p0, p1, 0.03, 0.16)
    for y, z in path[1:-1]:
        g["Brass"].hcyl(0.98, y, z, 0.09, 0.1, axis="x", seg=10)
    for y, z in ((-1.3, 6.4), (-1.3, 4.2), (1.1, 5.2), (-0.5, 6.05)):   # 흩어진 놋쇠 볼트
        g["Brass"].hcyl(0.9, y, z, 0.07, 0.06, axis="x", seg=8)
    # 앞 아래 크랭크 손잡이와 놋쇠 이름 원판
    g["Brass"].hcyl(1.0, -1.25, 4.35, 0.12, 0.3, axis="x", seg=12)
    g["Brass"].hcyl(0.88, 0.2, 4.0, 0.001 + 0.18, 0.04, axis="x", seg=16)

    # 렌즈: 앞면 위쪽. 놋쇠 목, 긴 검은 경통, 초점 고리, 은빛 끝 테, 유리와 빛나는 알. 위에 작은 죔쇠
    lz = 5.95
    g["Brass"].hcyl(0, -1.68, lz, 0.5, 0.16, axis="y", seg=20)
    g["Iron"].hcyl(0, -2.4, lz, 0.36, 1.3, axis="y", seg=20)
    g["Brass"].hcyl(0, -2.2, lz, 0.4, 0.14, axis="y", seg=20)
    g["IronLight"].hcyl(0, -3.13, lz, 0.42, 0.24, axis="y", seg=20)
    g["Glow"].hcyl(0, -3.2, lz, 0.3, 0.02, axis="y", seg=16)
    g["Glass"].hcyl(0, -3.24, lz, 0.33, 0.03, axis="y", seg=16)
    g["Iron"].box(0, -1.95, lz + 0.42, 0.3, 0.5, 0.14)
    g["Brass"].hcyl(0.2, -1.95, lz + 0.42, 0.07, 0.14, axis="x", seg=8)
    g["Brass"].hcyl(0.44, -2.55, lz, 0.06, 0.2, axis="x", seg=8)

    # 릴 둘. 사진보다 조금 크게(반지름 1.08, 몸통 높이 2.9 의 0.75 배). 몸통에 반쯤 묻혀 걸린다
    upper, lower = (0.55, 7.2), (2.0, 5.3)
    _holed_reel(g, upper[0], upper[1], 1.08)
    _holed_reel(g, lower[0], lower[1], 1.08)
    for sx in (-1, 1):   # 굴대 받침살: 위 릴은 몸통 윗면에서, 뒤 릴은 몸통 뒷면에서
        g["Iron"].box(sx * 0.32, upper[0], (5.95 + upper[1]) / 2, 0.08, 0.2, upper[1] - 5.95 + 0.1)
        g["Iron"].box(sx * 0.32, (1.4 + lower[0]) / 2, lower[1], 0.08, lower[0] - 1.4 + 0.1, 0.2)
    # 필름: 뒤 릴 아래에서 몸통 뒤로, 위 릴에서 몸통 윗면으로
    _bar(g, "Char", 0, (1.55, 4.55), (1.38, 4.75), 0.2, 0.03)
    _bar(g, "Char", 0, (0.12, 6.4), (0.02, 5.97), 0.2, 0.03)


# ---------------------------------------------------------------- 체스 기물
def _base(r):
    return [(r, 0.0), (r, 0.1), (r * 0.92, 0.14), (r * 0.92, 0.2), (r * 0.78, 0.26)]


def chess_pawn(g):
    head = [(0.22 * math.cos(math.radians(a)), 0.98 + 0.22 * math.sin(math.radians(a))) for a in (-60, -30, 0, 30, 60, 80)]
    lathe(g, "Iron", 0, 0, 0, _base(0.42) + [(0.26, 0.38), (0.2, 0.62), (0.3, 0.68), (0.3, 0.73), (0.17, 0.78)] + head, 20)


def chess_rook(g):
    lathe(g, "Iron", 0, 0, 0, _base(0.52) + [(0.36, 0.4), (0.3, 0.95), (0.38, 1.02), (0.43, 1.06), (0.43, 1.32),
                                               (0.3, 1.32), (0.3, 1.24)], 20)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        g["Iron"].obox(0.34 * math.cos(a), 0.34 * math.sin(a), 1.41, 0.18, 0.28, 0.18, rz=a)


def chess_knight(g):
    lathe(g, "Iron", 0, 0, 0, [(0.52, 0.0), (0.52, 0.1), (0.48, 0.14), (0.48, 0.2), (0.4, 0.3), (0.36, 0.36)], 20)
    horse = [(0.34, 0.33), (-0.30, 0.33), (-0.26, 0.6), (-0.2, 0.82), (-0.3, 0.98), (-0.56, 1.06), (-0.66, 1.14),
             (-0.64, 1.27), (-0.42, 1.43), (-0.22, 1.56), (-0.17, 1.72), (-0.08, 1.58), (0.0, 1.68), (0.06, 1.52),
             (0.22, 1.36), (0.33, 1.06), (0.38, 0.7)]
    extrude(g, "Iron", horse, -0.19, 0.19, plane="yz")
    # 갈기. 목 뒤를 따라 얇은 등성이
    g["Iron"].obox(0, 0.3, 1.05, 0.1, 0.12, 0.7, rx=0.3)


def chess_bishop(g):
    lathe(g, "Iron", 0, 0, 0, _base(0.5) + [(0.3, 0.4), (0.2, 0.95), (0.34, 1.02), (0.34, 1.07), (0.16, 1.12),
                                              (0.24, 1.25), (0.3, 1.42), (0.26, 1.6), (0.14, 1.74), (0.05, 1.8)], 20)
    ball(g, "Iron", 0, 0, 1.87, 0.08)
    g["Iron"].obox(0, -0.18, 1.5, 0.06, 0.2, 0.34, rx=0.5)   # 주교관의 홈 자리 덧판


def chess_queen(g):
    lathe(g, "Iron", 0, 0, 0, _base(0.55) + [(0.34, 0.42), (0.22, 1.1), (0.38, 1.18), (0.38, 1.23), (0.18, 1.3),
                                               (0.22, 1.5), (0.36, 1.8), (0.36, 1.86), (0.2, 1.9), (0.12, 2.0)], 20)
    for k in range(8):
        a = 2 * math.pi * k / 8
        ball(g, "Iron", 0.34 * math.cos(a), 0.34 * math.sin(a), 1.92, 0.065, seg=8)
    ball(g, "Iron", 0, 0, 2.1, 0.1)


def chess_king(g):
    lathe(g, "Iron", 0, 0, 0, _base(0.58) + [(0.36, 0.44), (0.23, 1.2), (0.4, 1.28), (0.4, 1.33), (0.19, 1.4),
                                               (0.23, 1.6), (0.36, 1.95), (0.36, 2.0), (0.22, 2.06), (0.14, 2.12)], 20)
    g["Iron"].box(0, 0, 2.28, 0.1, 0.1, 0.34)
    g["Iron"].box(0, 0, 2.33, 0.3, 0.1, 0.1)


# ---------------------------------------------------------------- 내놓기
JOBS = [
    ("Steam_Press", "Press", steam_press, [("front", (6, -22, 12), (0, 0, 9)), ("corner", (-16, -16, 16), (0, 0, 9))]),
    ("Vertical_Boiler", "VBoil", vertical_boiler, [("front", (5, -18, 10), (0, 0, 7.5)), ("corner", (14, -12, 14), (0, 0, 7))]),
    ("Emotion_Proto", "Proto", emotion_proto, [("front", (2, -11, 6), (0, 0, 3.5)), ("corner", (8, -7, 8), (0, 0, 3.2))]),
    ("Forge", "Forge", forge, [("front", (0, -20, 9), (0, 0, 5)), ("corner", (-14, -13, 12), (0, 0, 5))]),
    ("Anvil", "Anvil", anvil, [("front", (1, -6, 3.2), (0.2, 0, 2.4)), ("corner", (4, -4, 4), (0.2, 0, 2.3))]),
    ("Film_Projector", "Proj", film_projector, [("side", (11, 0.5, 6), (0, 0.3, 5.2)), ("front", (6, -9, 7), (0, 0, 5)),
                                                ("back", (-7, 7, 8), (0, 0.5, 5.5))]),
    ("Steam_Rifle", "Rifle", steam_rifle, [("front", (0, -8, 1.2), (0, 0, 0.8))]),
    ("Steam_Pistol", "Pistol", steam_pistol, [("front", (0.4, -3, 0.6), (0.4, 0, 0.45))]),
    ("Chess_Pawn", "ChP", chess_pawn, [("front", (0, -4, 1.2), (0, 0, 0.6))]),
    ("Chess_Rook", "ChR", chess_rook, [("front", (0, -4, 1.4), (0, 0, 0.75))]),
    ("Chess_Knight", "ChN", chess_knight, [("side", (4, -1.5, 1.4), (0, 0, 0.85))]),
    ("Chess_Bishop", "ChB", chess_bishop, [("front", (0, -4.5, 1.5), (0, 0, 0.95))]),
    ("Chess_Queen", "ChQ", chess_queen, [("front", (0, -5, 1.6), (0, 0, 1.1))]),
    ("Chess_King", "ChK", chess_king, [("front", (0, -5, 1.7), (0, 0, 1.2))]),
]


def _selfcheck():
    """귀 자르기: 삼각형 넓이 합이 다각형 넓이와 같아야 한다 (오목한 L 자와 말머리)"""
    def area(p):
        return abs(sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))) / 2

    for poly in ([(0, 0), (2, 0), (2, 1), (1, 1), (1, 2), (0, 2)],
                 [(0.34, 0.33), (-0.30, 0.33), (-0.26, 0.6), (-0.2, 0.82), (-0.3, 0.98), (-0.56, 1.06), (-0.66, 1.14),
                  (-0.64, 1.27), (-0.42, 1.43), (-0.22, 1.56), (-0.17, 1.72), (-0.08, 1.58), (0.0, 1.68), (0.06, 1.52),
                  (0.22, 1.36), (0.33, 1.06), (0.38, 0.7)]):
        tris = ear_clip(poly)
        assert len(tris) == len(poly) - 2
        got = sum(area([poly[i] for i in t]) for t in tris)
        assert abs(got - area(poly)) < 1e-9, (got, area(poly))


if __name__ == "__main__":
    _selfcheck()
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, renders in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        L.export_model(name, g, 1.0, renders=renders, min_objs=1, palette=S.PALETTE)
