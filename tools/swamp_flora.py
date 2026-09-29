# -*- coding: utf-8 -*-
"""
swamp_flora.py — 늪지대 풀·나무 틀(맵 양식: Part 블록). (2026-09-28)

다른 섬 나무 짜임을 따른다(평원 Pln_Tree·숲 For_W/P 를 뜯어봄):
- 줄기: Wood 네모 막대 여러 토막(조금씩 기울며 가늘어짐), 밑동은 넓적한 뿌리 블록
- 가지: a(굵고 45° 위로) + b(가늘고 거의 눕게) 두 토막
- 잎: 가지 끝마다 Grass 블록 덩이 2~4개(y 축으로 돌리고 몇 도만 기울임), 색은 짙은 녹색 몇 가지
늪 나무는 여기에 늪 맛을 더했다: 삼나무는 밑동이 부풀고 무릎뿌리가 솟으며 잎이 납작한 층, 가지 밑에 늘어진 이끼 판.
맹그로브는 버팀뿌리가 둥글게 내려오고, 죽은 나무는 잿빛 가지만 남는다.

각 틀의 변수(키·가지 방향·길이·잎 크기)는 손으로 정한 값이다(무작위 없음).
출력: tools/swamp/flora.txt  (틀 부품 목록: 틀 이름·부품 이름·재질·색·CFrame 12 수·크기)
돌리는 법: python tools/swamp_flora.py   (numpy 불필요)
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# 색(맵 나무 색과 같은 결: 짙은 녹색 + 늪이라 누렇게 조금)
LEAF = [(44, 62, 38), (54, 74, 44), (64, 86, 50), (38, 56, 36), (72, 92, 54)]
LEAF_M = [(40, 70, 42), (50, 84, 48), (60, 96, 54), (34, 60, 38)]      # 맹그로브(더 푸름)
LEAF_B = [(52, 84, 46), (64, 100, 52), (46, 78, 44), (58, 92, 50)]     # 언덕 활엽수(평원 나무 색)
MOSS = [(128, 136, 104), (112, 122, 92), (140, 146, 112)]
WOOD = (62, 46, 34)
WOOD_DK = (48, 36, 28)
WOOD_GREY = (104, 96, 88)
WOOD_PALE = (126, 116, 104)


def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def v_len(a):
    return math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)


def v_norm(a):
    L = v_len(a)
    return (a[0] / L, a[1] / L, a[2] / L)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    # 로블록스 CFrame.Angles(0, θ, 0) 의 행렬(열: 로컬 X, Y, Z 의 월드 방향)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rot_yxz(ry, rx, rz):
    """CFrame.fromOrientation(rx, ry, rz) = Y·X·Z 순서(도). 행렬 행 우선 3x3."""
    def m(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    cy, sy = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cx, sx = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    Ry = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    Rx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    Rz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
    return m(m(Ry, Rx), Rz)


class Tree:
    def __init__(self, name):
        self.name = name
        self.parts = []

    def box(self, pname, mat, col, center, size, R=((1, 0, 0), (0, 1, 0), (0, 0, 1))):
        self.parts.append((pname, mat, col, center, R, size))

    def block(self, pname, mat, col, center, size, yaw=0.0, tilt_x=0.0, tilt_z=0.0):
        self.box(pname, mat, col, center, size, rot_yxz(yaw, tilt_x, tilt_z))

    def seg(self, pname, col, p0, p1, t, t2=None, mat="Wood"):
        """p0→p1 막대(굵기 t×t2). 로컬 Z 가 막대 방향(다른 섬 줄기 토막과 같은 짜임)."""
        d = v_sub(p1, p0)
        L = v_len(d)
        z = v_norm(v_mul(d, -1))           # lookAt 처럼 -Z 가 p1 쪽
        up = (0, 1, 0) if abs(z[1]) < 0.95 else (1, 0, 0)
        x = v_norm(cross(up, z))
        y = cross(z, x)
        R = ((x[0], y[0], z[0]), (x[1], y[1], z[1]), (x[2], y[2], z[2]))
        c = v_mul(v_add(p0, p1), 0.5)
        self.box(pname, mat, col, c, (t, t2 or t, L), R)
        return p1


def polar(r, deg, y):
    a = math.radians(deg)
    return (r * math.cos(a), y, -r * math.sin(a))


# ─────────────────────────────────────────────────────────────
# 늪삼나무: (이름, 키, 줄기 굵기, 기울기 방향·양, 가지 [(높이비, 방향, 길이, 잎 너비)], 무릎뿌리 방향들)
# ─────────────────────────────────────────────────────────────
CYPRESS = [
    ("Cyp_A", 40, 4.6, (30, 1.5), [(0.58, 20, 11, 16), (0.66, 140, 10, 15), (0.74, 255, 12, 17), (0.84, 75, 9, 14), (0.93, 200, 7, 12)], (60, 170, 290)),
    ("Cyp_B", 34, 4.2, (200, 2.0), [(0.55, 95, 10, 15), (0.66, 215, 11, 16), (0.77, 330, 9, 14), (0.9, 150, 7, 12)], (20, 250)),
    ("Cyp_C", 46, 5.0, (110, 1.2), [(0.52, 300, 12, 17), (0.6, 60, 11, 16), (0.7, 175, 13, 18), (0.8, 250, 10, 15), (0.88, 20, 9, 14), (0.96, 130, 6, 11)], (100, 220, 340)),
    ("Cyp_D", 30, 3.8, (320, 2.5), [(0.6, 170, 9, 14), (0.72, 290, 10, 15), (0.85, 45, 8, 13)], (135, 300)),
]


def cypress(name, H, T, lean, branches, knees):
    t = Tree(name)
    k = 0
    # 부푼 밑동: 넓적 뿌리 + 버팀 네 갈래(맵 나무의 Root 블록을 늪식으로 크게)
    t.block("Root", "Wood", WOOD_DK, (0, 1.2, 0), (T * 2.1, 2.4, T * 2.1), yaw=45)
    for i, a in enumerate((20, 110, 200, 290)):
        t.seg("Buttress%d" % i, WOOD, polar(T * 1.45, a, 0.2), polar(T * 0.35, a, T * 1.6), T * 0.55, T * 0.8)
    for i, a in enumerate(knees):
        r = T * 1.8 + 2.5 + i
        t.block("Knee%d" % i, "Wood", WOOD, polar(r, a, 0.9), (1.1, 1.8 + 0.4 * i, 1.1), yaw=a)
    # 줄기 네 토막, 기울며 가늘어짐
    la, lk = lean
    top = (0, 0, 0)
    p = (0, 1.0, 0)
    for i in range(4):
        f = (i + 1) / 4
        q = v_add(polar(lk * f * f, la, 0), (0, H * f, 0))
        t.seg("T%d" % (i + 1), WOOD, p, q, T * (1.0 - 0.14 * i))
        p = q
    top = p
    # 가지 + 납작 잎층 + 늘어진 이끼
    for bi, (hf, ang, L, W) in enumerate(branches):
        base = v_add(polar(lk * hf * hf, la, 0), (0, H * hf, 0))
        mid = v_add(base, polar(L * 0.55, ang, L * 0.32))
        tip = v_add(mid, polar(L * 0.45, ang + 8, L * 0.06))
        t.seg("B%da" % bi, WOOD, base, mid, max(1.1, T * 0.34))
        t.seg("B%db" % bi, WOOD, mid, tip, max(0.8, T * 0.24))
        col = LEAF[bi % len(LEAF)]
        t.block("B%dt1" % bi, "Grass", col, v_add(tip, (0, 1.4, 0)), (W, 3.4, W * 0.82), yaw=ang + 12, tilt_x=2)
        t.block("B%dt2" % bi, "Grass", LEAF[(bi + 2) % len(LEAF)], v_add(mid, polar(1.5, ang - 30, 2.6)), (W * 0.72, 3.0, W * 0.64), yaw=ang - 40, tilt_z=-3)
        t.block("B%dt3" % bi, "Grass", LEAF[(bi + 1) % len(LEAF)], v_add(tip, polar(W * 0.32, ang + 70, 3.6)), (W * 0.55, 2.6, W * 0.5), yaw=ang + 75, tilt_x=-3)
        for mi in range(2):
            mp = v_add(tip, polar(W * (0.12 + 0.2 * mi), ang + 90 + 160 * mi, -0.2 - (3.6 + 1.2 * mi)))
            t.block("Moss%d_%d" % (bi, mi), "Grass", MOSS[(bi + mi) % 3], mp, (0.3, 7.0 + 1.6 * mi, 1.6 - 0.3 * mi), yaw=ang + 90)
        k += 1
    # 꼭대기 납작 관(평평한 머리가 늪삼나무 특징)
    t.block("C1", "Grass", LEAF[1], v_add(top, (0, 1.2, 0)), (13, 3.2, 11), yaw=la + 25)
    t.block("C2", "Grass", LEAF[3], v_add(top, (1.5, 3.6, -1.0)), (8, 2.6, 7.5), yaw=la + 70, tilt_z=3)
    return t


# ─────────────────────────────────────────────────────────────
# 맹그로브: (이름, 키, 버팀뿌리 방향들, 가지 [(방향, 길이)])
# ─────────────────────────────────────────────────────────────
MANGROVE = [
    ("Man_A", 17, (0, 40, 80, 120, 160, 200, 240, 280, 320), [(30, 8), (150, 7), (270, 9), (90, 6)]),
    ("Man_B", 14, (15, 60, 110, 165, 215, 265, 315), [(60, 7), (190, 8), (310, 6)]),
]


def mangrove(name, H, roots, branches):
    """버팀뿌리: 줄기에서 거의 옆으로 나와(무릎) 둥글게 꺾여 물속으로 내려간다. 세 토막이라 다리처럼 곧지 않다."""
    t = Tree(name)
    for i, a in enumerate(roots):
        y0 = 5.0 + 1.4 * (i % 3)
        r1 = 3.0 + 0.6 * (i % 2)
        r2 = 5.2 + 0.8 * (i % 3)
        r3 = 6.6 + 1.0 * (i % 3)
        p0 = polar(0.9, a, y0)
        p1 = polar(r1, a + 4, y0 + 0.4)
        p2 = polar(r2, a + 8, y0 - 1.8)
        p3 = polar(r3, a + 10, -1.4)
        t.seg("Rt%da" % i, WOOD, p0, p1, 0.8)
        t.seg("Rt%db" % i, WOOD, p1, p2, 0.75)
        t.seg("Rt%dc" % i, WOOD_DK, p2, p3, 0.7)
    # 가운데 줄기(버팀뿌리가 모이는 곳부터)
    t.block("Hub", "Wood", WOOD_DK, (0, 5.4, 0), (2.8, 3.0, 2.8), yaw=20)
    p = (0, 6.0, 0)
    for i in range(2):
        q = (0.5 * (i + 1), 6.0 + (H - 6.0) * (i + 1) / 2, -0.3 * (i + 1))
        t.seg("T%d" % (i + 1), WOOD, p, q, 2.6 - 0.5 * i)
        p = q
    top = p
    for bi, (a, L) in enumerate(branches):
        base = v_add(top, (0, -3.0 + bi * 0.7, 0))
        tip = v_add(base, polar(L, a, L * 0.4))
        t.seg("B%d" % bi, WOOD, base, tip, 1.1)
        t.block("L%da" % bi, "Grass", LEAF_M[bi % 4], v_add(tip, (0, 1.4, 0)), (10.0, 6.0, 9.0), yaw=a + 20, tilt_x=3)
        t.block("L%db" % bi, "Grass", LEAF_M[(bi + 1) % 4], v_add(tip, polar(3.8, a + 80, 3.0)), (7.5, 5.0, 8.0), yaw=a - 25, tilt_z=-4)
        t.block("L%dc" % bi, "Grass", LEAF_M[(bi + 2) % 4], v_add(base, polar(L * 0.5, a - 40, 1.2)), (6.5, 4.2, 6.0), yaw=a + 60)
    t.block("L_top1", "Grass", LEAF_M[2], v_add(top, (0, 3.8, 0)), (12, 6.5, 11), yaw=35)
    t.block("L_top2", "Grass", LEAF_M[0], v_add(top, (-2.0, 7.0, 1.0)), (8.0, 5.0, 7.5), yaw=80, tilt_x=-4)
    return t


# ─────────────────────────────────────────────────────────────
# 죽은 나무: (이름, 키, 가지 [(높이비, 방향, 길이, 위로 휨)])
# ─────────────────────────────────────────────────────────────
DEAD = [
    ("Dead_A", 30, [(0.45, 40, 9, 0.8), (0.6, 170, 11, 0.5), (0.72, 290, 8, 1.0), (0.85, 95, 6, 1.2)]),
    ("Dead_B", 24, [(0.5, 250, 8, 0.4), (0.66, 20, 10, 0.9), (0.8, 140, 6, 1.1)]),
]


def dead(name, H, branches):
    t = Tree(name)
    t.block("Root", "Wood", WOOD_GREY, (0, 1.0, 0), (6.5, 2.0, 6.5), yaw=30)
    p = (0, 0.5, 0)
    for i in range(3):
        f = (i + 1) / 3
        q = (0.9 * f * f, H * f, -0.6 * f)
        t.seg("T%d" % (i + 1), WOOD_GREY, p, q, 3.2 - 0.7 * i)
        p = q
    t.seg("Snag", WOOD_PALE, p, v_add(p, (0.6, 4.0, 0.4)), 1.0)
    for bi, (hf, a, L, up) in enumerate(branches):
        base = (0.9 * hf * hf, H * hf, -0.6 * hf)
        mid = v_add(base, polar(L * 0.55, a, L * 0.35 * up))
        tip = v_add(mid, polar(L * 0.45, a - 15, L * 0.5 * up))
        t.seg("B%da" % bi, WOOD_GREY, base, mid, 1.2)
        t.seg("B%db" % bi, WOOD_PALE, mid, tip, 0.8)
        if bi % 2 == 0:
            t.block("Moss%d" % bi, "Grass", MOSS[bi % 3], v_add(mid, (0, -3.2, 0)), (0.3, 5.5, 1.4), yaw=a + 90)
    return t


# ─────────────────────────────────────────────────────────────
# 언덕 활엽수(평원 나무 짜임): (이름, 키, 가지 [(높이비, 방향, 길이)])
# ─────────────────────────────────────────────────────────────
BROAD = [
    ("Brd_A", 22, [(0.62, 30, 8), (0.7, 150, 7), (0.78, 260, 8), (0.9, 90, 5)]),
    ("Brd_B", 19, [(0.6, 200, 7), (0.72, 320, 8), (0.86, 80, 6)]),
]


def broad(name, H, branches):
    t = Tree(name)
    t.block("Root", "Wood", WOOD, (0, 1.2, 0), (6.5, 2.4, 6.5), yaw=20)
    p = (0, 0.5, 0)
    for i in range(3):
        f = (i + 1) / 3
        q = (0.5 * f, H * 0.78 * f, 0.4 * f)
        t.seg("T%d" % (i + 1), WOOD, p, q, 3.2 - 0.5 * i)
        p = q
    for bi, (hf, a, L) in enumerate(branches):
        base = (0.5 * hf, H * 0.78 * hf, 0.4 * hf)
        mid = v_add(base, polar(L * 0.6, a, L * 0.55))
        tip = v_add(mid, polar(L * 0.4, a, L * 0.15))
        t.seg("B%da" % bi, WOOD, base, mid, 1.4)
        t.seg("B%db" % bi, WOOD, mid, tip, 1.0)
        t.block("B%dt1" % bi, "Grass", LEAF_B[bi % 4], v_add(tip, (0, 1.6, 0)), (9.5, 5.8, 8.8), yaw=a + 15)
        t.block("B%dt2" % bi, "Grass", LEAF_B[(bi + 1) % 4], v_add(tip, polar(3.0, a + 70, 3.8)), (7.0, 5.0, 6.5), yaw=a - 30, tilt_x=3)
        t.block("B%dt3" % bi, "Grass", LEAF_B[(bi + 2) % 4], v_add(mid, (0, 2.5, 0)), (6.5, 4.5, 6.0), yaw=a + 50)
    t.block("F1", "Grass", LEAF_B[1], v_add(p, (0, 3.0, 0)), (9.0, 6.4, 8.5), yaw=40)
    t.block("F2", "Grass", LEAF_B[3], v_add(p, (1.0, 6.0, -0.5)), (6.0, 4.5, 6.0), yaw=75)
    return t


# ─────────────────────────────────────────────────────────────
# 작은 것들
# ─────────────────────────────────────────────────────────────

def bushes():
    out = []
    specs = {
        "Bush_A": [((0, 1.6, 0), (5.5, 3.2, 5.0), 10, 1), ((2.6, 1.2, 1.4), (3.8, 2.4, 3.6), 40, 0), ((-2.2, 1.1, 1.8), (3.4, 2.2, 3.2), 70, 2)],
        "Bush_B": [((0, 1.9, 0), (6.5, 3.8, 6.0), 25, 3), ((-3.0, 1.3, -1.0), (4.0, 2.6, 3.8), 60, 1), ((2.4, 1.4, -2.2), (3.6, 2.8, 3.4), 5, 0), ((0.6, 3.6, 0.4), (3.2, 2.0, 3.0), 45, 4)],
        "Bush_C": [((0, 1.2, 0), (4.2, 2.4, 3.8), 0, 2), ((1.8, 1.0, -1.6), (3.0, 2.0, 2.8), 35, 4)],
    }
    for name, blocks in specs.items():
        t = Tree(name)
        for i, (c, s, yaw, ci) in enumerate(blocks):
            t.block("L%d" % i, "Grass", LEAF[ci], c, s, yaw=yaw, tilt_x=(i % 2) * 3)
        out.append(t)
    return out


def reeds():
    out = []
    for name, n, h0, spread in (("Reed_A", 11, 6.5, 2.6), ("Reed_B", 8, 5.0, 2.0)):
        t = Tree(name)
        for i in range(n):
            a = i * 137.5
            r = spread * (0.35 + 0.65 * ((i * 7) % n) / n)
            h = h0 * (0.75 + 0.35 * ((i * 5) % n) / n)
            base = polar(r, a, -0.6)
            tip = v_add(base, polar(0.8 + 0.3 * (i % 3), a, h))
            col = (132, 128, 72) if i % 3 == 0 else ((104, 120, 62) if i % 3 == 1 else (118, 126, 68))
            t.seg("Stalk%d" % i, col, base, tip, 0.28, mat="Grass")
            if i % 3 == 0:
                t.seg("Head%d" % i, (86, 58, 38), v_sub(tip, (0, 1.9, 0)), v_sub(tip, (0, 0.3, 0)), 0.62, mat="Fabric")
        out.append(t)
    return out


def lilies():
    out = []
    for name, pads, flowers in (("Lily_A", [((0, 0, 0), 4.2, 10), ((4.4, 0, 2.0), 3.2, 55), ((-3.5, 0, 3.0), 2.8, 30), ((1.0, 0, -4.2), 3.0, 75)], [(0.8, 0.3)]),
                                ("Lily_B", [((0, 0, 0), 3.6, 20), ((-3.8, 0, -1.4), 2.8, 65), ((2.4, 0, 3.4), 2.4, 5)], [(-3.6, -1.2)])):
        t = Tree(name)
        for i, (c, s, yaw) in enumerate(pads):
            t.block("Pad%d" % i, "Grass", (70, 108, 58) if i % 2 == 0 else (82, 118, 64), c, (s, 0.2, s * 0.92), yaw=yaw)
        for i, (fx, fz) in enumerate(flowers):
            t.block("Flower%d" % i, "SmoothPlastic", (232, 176, 196), (fx, 0.5, fz), (0.9, 0.7, 0.9), yaw=45)
            t.block("FlowerC%d" % i, "SmoothPlastic", (246, 220, 120), (fx, 0.95, fz), (0.4, 0.3, 0.4), yaw=0)
        out.append(t)
    return out


def mushrooms():
    t = Tree("Shroom_A")
    for i, (x, z, h, s) in enumerate(((0, 0, 1.8, 1.8), (1.6, 1.0, 1.2, 1.2), (-1.3, 1.4, 1.0, 1.0), (0.6, -1.6, 1.4, 1.3))):
        t.block("Stalk%d" % i, "SmoothPlastic", (214, 214, 196), (x, h / 2, z), (0.45, h, 0.45))
        t.block("Cap%d" % i, "Neon", (118, 228, 188) if i % 2 == 0 else (150, 240, 170), (x, h + 0.25, z), (s, 0.5, s), yaw=20 * i)
    return [t]


def logs():
    t = Tree("Log_A")
    t.seg("Log", WOOD_DK, (-9, 1.3, 0), (9, 1.5, 1.0), 2.6)
    t.seg("Branch", WOOD_DK, (3, 1.8, 0.6), (6, 3.8, 3.6), 0.9)
    t.block("Stump", "Wood", WOOD, (-9.6, 1.4, -0.2), (3.2, 2.8, 3.2), yaw=15)
    t.block("Moss1", "Grass", LEAF[2], (-2, 2.9, 0.4), (5.0, 0.6, 2.6), yaw=3)
    t.block("Moss2", "Grass", LEAF[0], (4.5, 3.0, 0.8), (3.2, 0.5, 2.2), yaw=-4)
    t.block("Cap", "Neon", (118, 228, 188), (0.5, 3.1, 1.3), (1.0, 0.4, 1.0), yaw=30)
    return [t]


def all_trees():
    ts = [cypress(*c) for c in CYPRESS] + [mangrove(*m) for m in MANGROVE] + [dead(*d) for d in DEAD] + [broad(*b) for b in BROAD]
    return ts + bushes() + reeds() + lilies() + mushrooms() + logs()


def write():
    L = []
    for t in all_trees():
        for (pname, mat, col, c, R, s) in t.parts:
            L.append("\t".join([t.name, pname, mat, "%d,%d,%d" % col,
                                " ".join("%.3f" % v for v in (c[0], c[1], c[2], R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2])),
                                " ".join("%.2f" % v for v in s)]))
    open(os.path.join(HERE, "swamp", "flora.txt"), "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    cnt = {}
    for t in all_trees():
        cnt[t.name] = len(t.parts)
    print("틀 %d, 부품 %s" % (len(cnt), cnt))


if __name__ == "__main__":
    write()
