# -*- coding: utf-8 -*-
"""
build_steam.py — 설원 슈네라이히의 스팀펑크 건물과 소품. (2026-09-26)

슈네라이히는 극한의 추위를 **사람의 감정을 열기로 바꾸는 기술**로 버티는 기술 국가다.
그래서 집마다 보일러와 굴뚝이 있고, 도시 한가운데 감정 변환로가 붉게 달아 있으며,
열기를 나르는 구리 관이 거리를 따라 달린다. 창은 모두 따뜻한 불빛이다.

  Steam_House_A    좁은 이층 벽돌집. 앞박공, 옆에 구리 보일러 굴뚝
  Steam_House_B    넓은 작업장 집. 반원 함석 지붕, 둥근 창, 옆에 눕힌 보일러 통
  Steam_House_C    탑집. 삼층에 모서리 원통 탑과 발코니
  Herzofen         감정 변환로. 리벳 박은 거대한 원통로와 유리 속 붉은 핵, 굴뚝 넷
  Zapfen_Werk      차펜 공방. 톱날 지붕 공장, 굴뚝 셋, 큰 톱니 문장
  Frostig_Werk     프로스티히 공방. 이층 무기 공방, 진열창과 총 간판, 대장간 굴뚝
  Sel_Werk_Ruin    설 공방 폐허. 차펜 공방이 불태운 옛 공방. 지붕이 무너졌다
  Figuren_HQ       기물군 본부. 룩(성장) 모양 총안 탑, 시계 톱니, 깃발
  Gas_Lamp         가스등
  Big_Gear         광장 톱니 조형물
  Boiler_Tank      세운 보일러 통
  Mooring_Mast     비행선 계류탑
  Airship          비행선. 원점은 곤돌라 밑바닥 가운데
  City_Gate        도시 동문

단위는 스터드 그대로(배율 1). 앞은 -y. **벽은 속이 찬 덩이다.** 안에 들어가는 건
문에서 순간이동하는 별도 방이라 겉 건물은 속을 비울 까닭이 없다(폐허만 벽을 판으로 세운다).

표지 둘: Vent 는 김이 나오는 자리(로블록스에서 투명하게 하고 연기를 단다),
LampPt 는 점광원 자리다.

돌리는 법: blender --background --python build_steam.py [-- 이름 ...]
"""
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

PALETTE = {
    "Brick": "#7A4034",      # 붉은 벽돌
    "BrickDark": "#5A433D",  # 그을린 벽돌
    "Stone": "#55565C",      # 고원 화강암과 같은 계열
    "StoneTrim": "#8C8B8A",  # 띠돌
    "Iron": "#3A3C42",
    "IronLight": "#5E626B",
    "Brass": "#B8913F",
    "Copper": "#B06A3F",
    "Verdigris": "#5F9E8C",  # 녹청
    "Timber": "#5A3E2C",
    "RoofMetal": "#353840",
    "SnowCap": "#EEF3F7",
    "Glow": "#FFB45A",       # 창 불빛
    "Core": "#FF7E5F",       # 감정 열기. 붉은 산호빛
    "Soot": "#2B2A2C",       # 불탄 벽
    "Char": "#1F1B1A",       # 숯이 된 나무
    "Canvas": "#CBBE9E",     # 비행선 천
    "Banner": "#7C2B2E",     # 기물군 깃발
    "Wood": "#8A5A36",       # 총 개머리, 풀무 같은 다듬은 나무
    "Glass": "#C8E1EB",      # 유리. Studio 에서 반투명
    "Leather": "#4A2E24",    # 짙은 가죽 (영사기 몸통)
    "Vent": "#FFFFFF",       # 표지. 김 자리
    "LampPt": "#FFFFFF",     # 표지. 점광원 자리
}
HALF_PI = math.pi / 2


def G(prefix):
    return L.new_groups(prefix, PALETTE)


# ---------------------------------------------------------------- 부품

def roof_gable(g, cx, cy, z0, W, D, H, along="y", over=0.9, thick=0.6, gable="BrickDark", snow=0.75):
    """
    맞배지붕. W 는 용마루와 직각인 폭, D 는 용마루 길이. along 은 용마루 방향.
    박공 세모는 gable 재질로 벽 위에 세운다. snow 는 눈이 덮은 비율(처마 쪽은 금속이 보인다)
    """
    a = math.atan2(H, W / 2)
    s = W / 2 + over
    L_ = s / math.cos(a)
    for side in (-1, 1):
        # 지붕 판 가운데. 용마루에서 처마로 반쯤 내려간 자리, 판 두께 반만큼 바깥으로
        mx = side * s / 2
        mz = z0 + H - (s / 2) * math.tan(a)
        nx, nz = side * math.sin(a), math.cos(a)
        if along == "y":
            g["RoofMetal"].obox(cx + mx + nx * thick / 2, cy, mz + nz * thick / 2, L_, D + 2 * over, thick, ry=side * a)
            ls = L_ * snow
            sx = side * (s * snow) / 2
            smz = z0 + H - (s * snow / 2) * math.tan(a)
            g["SnowCap"].obox(cx + sx + nx * (thick + 0.25), cy, smz + nz * (thick + 0.25), ls, D + 2 * over - 0.4, 0.5,
                              ry=side * a)
        else:
            g["RoofMetal"].obox(cx, cy + mx + nx * thick / 2, mz + nz * thick / 2, D + 2 * over, L_, thick, rx=-side * a)
            ls = L_ * snow
            sy = side * (s * snow) / 2
            smz = z0 + H - (s * snow / 2) * math.tan(a)
            g["SnowCap"].obox(cx, cy + sy + nx * (thick + 0.25), smz + nz * (thick + 0.25), D + 2 * over - 0.4, ls, 0.5,
                              rx=-side * a)
    # 박공 세모 둘
    for side in (-1, 1):
        if along == "y":
            y = cy + side * D / 2
            v = [(cx - W / 2, y, z0), (cx + W / 2, y, z0), (cx, y, z0 + H),
                 (cx - W / 2, y - side * 0.8, z0), (cx + W / 2, y - side * 0.8, z0), (cx, y - side * 0.8, z0 + H)]
        else:
            x = cx + side * D / 2
            v = [(x, cy - W / 2, z0), (x, cy + W / 2, z0), (x, cy, z0 + H),
                 (x - side * 0.8, cy - W / 2, z0), (x - side * 0.8, cy + W / 2, z0), (x - side * 0.8, cy, z0 + H)]
        g[gable].add_mesh(v, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    # 용마루 쇠
    if along == "y":
        g["Iron"].box(cx, cy, z0 + H + 0.35, 0.9, D + 2 * over, 0.7)
    else:
        g["Iron"].box(cx, cy, z0 + H + 0.35, D + 2 * over, 0.9, 0.7)


def pyramid(g, mat, cx, cy, z0, w, d, h, frac=1.0, lift=0.0):
    """네모뿔. frac 은 꼭대기에서 아래로 덮는 비율(눈 모자용). 닫힌 덩이"""
    top = (cx, cy, z0 + h + lift)
    k = frac
    zb = z0 + h * (1 - k) + lift
    hw, hd = w / 2 * k, d / 2 * k
    base = [(cx - hw, cy - hd, zb), (cx + hw, cy - hd, zb), (cx + hw, cy + hd, zb), (cx - hw, cy + hd, zb)]
    v = base + [top]
    g[mat].add_mesh(v, [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)])


def arc_shell(g, mat, x0, x1, cy, cz, r0, r1, a0=0.0, a1=math.pi, n=18):
    """x 방향으로 뻗은 원통 껍질 조각. y-z 평면에서 cy,cz 둘레 a0..a1. 반원 지붕용"""
    v = []
    for x in (x0, x1):
        for r in (r0, r1):
            for k in range(n + 1):
                a = a0 + (a1 - a0) * k / n
                v.append((x, cy + r * math.cos(a), cz + r * math.sin(a)))
    m = n + 1
    A0i, A0o, A1i, A1o = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f.append((A0o + k, A1o + k, A1o + k + 1, A0o + k + 1))    # 바깥
        f.append((A0i + k, A0i + k + 1, A1i + k + 1, A1i + k))    # 안
        f.append((A0i + k, A0o + k, A0o + k + 1, A0i + k + 1))    # 끝 x0
        f.append((A1i + k, A1i + k + 1, A1o + k + 1, A1o + k))    # 끝 x1
    for k0 in (0, n):
        f.append((A0i + k0, A1i + k0, A1o + k0, A0o + k0))
    g[mat].add_mesh(v, f)


def half_disc(g, mat, x, cy, cz, r, t, n=18):
    """x 에 선 반원판. 반원 지붕 끝벽"""
    v = []
    for xx in (x - t / 2, x + t / 2):
        v.append((xx, cy, cz))
        for k in range(n + 1):
            a = math.pi * k / n
            v.append((xx, cy + r * math.cos(a), cz + r * math.sin(a)))
    m = n + 2
    f = []
    for k in range(n):
        f.append((0, 1 + k + 1, 1 + k))
        f.append((m, m + 1 + k, m + 1 + k + 1))
        f.append((1 + k, 1 + k + 1, m + 1 + k + 1, m + 1 + k))
    f.append((0, 1, m + 1, m))
    f.append((0, m, m + 1 + n, 1 + n))
    g[mat].add_mesh(v, f)


def gear(g, mat, cx, cy, cz, r, teeth, t, axis="y", depth=None):
    """톱니바퀴 판. axis 는 판이 바라보는 방향(y 면 앞을 본다, z 면 눕는다)"""
    depth = depth or r * 0.18
    pts = []
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        da = 2 * math.pi / teeth
        for frac, rr in ((0.0, r - depth), (0.18, r), (0.5, r), (0.68, r - depth)):
            aa = a + da * frac
            pts.append((rr * math.cos(aa), rr * math.sin(aa)))
    n = len(pts)

    def P(u, w, h):
        if axis == "y":
            return (cx + u, cy + h, cz + w)
        if axis == "x":
            return (cx + h, cy + u, cz + w)
        return (cx + u, cy + w, cz + h)

    v = [P(0, 0, -t / 2), P(0, 0, t / 2)]
    for u, w in pts:
        v.append(P(u, w, -t / 2))
    for u, w in pts:
        v.append(P(u, w, t / 2))
    f = []
    for k in range(n):
        a, b = 2 + k, 2 + (k + 1) % n
        f.append((0, b, a))
        f.append((1, a + n, b + n))
        f.append((a, b, b + n, a + n))
    g[mat].add_mesh(v, f)
    # 굴대
    if axis == "y":
        g["Iron"].hcyl(cx, cy, cz, r * 0.22, t + 0.6, axis="y", seg=10)
    elif axis == "x":
        g["Iron"].hcyl(cx, cy, cz, r * 0.22, t + 0.6, axis="x", seg=10)
    else:
        g["Iron"].cyl(cx, cy, cz - t / 2 - 0.3, r * 0.22, r * 0.22, t + 0.6, seg=10)


WIN_OUT = 0.1


def window(g, cx, cy, z0, w, h, face="-y", cross=True, frame="Iron", glass="Glow", sill=True):
    """벽 겉면(cx,cy 가 벽면 위 한 점)에 붙이는 창. face 는 벽이 바라보는 쪽"""
    s = -1 if face[0] == "-" else 1
    ax = face[1]
    zc = z0 + h / 2

    def B(mat, u, dn, z, su, sn, sz):
        # u: 벽을 따라, dn: 벽 바깥으로. 창 전체를 WIN_OUT 만큼 벽에서 띄운다
        # (2026-10-09 사용자: 창이 벽과 깜빡인다 → 0.1 앞으로)
        dn += WIN_OUT
        if ax == "y":
            g[mat].box(cx + u, cy + s * dn, z, su, sn, sz)
        else:
            g[mat].box(cx + s * dn, cy + u, z, sn, su, sz)

    if glass:   # None = 틀만(유리는 바깥 창이 맡음)
        B(glass, 0, 0.1, zc, w, 0.2, h)
    fw = 0.35
    B(frame, 0, 0.25, z0 + h + fw / 2, w + 2 * fw, 0.4, fw)
    B(frame, 0, 0.25, z0 - fw / 2, w + 2 * fw, 0.4, fw)
    for su in (-1, 1):
        B(frame, su * (w / 2 + fw / 2), 0.25, zc, fw, 0.4, h)
    if cross:
        B(frame, 0, 0.3, zc, 0.22, 0.3, h)
        B(frame, 0, 0.3, zc, w, 0.3, 0.22)
    if sill:
        B("StoneTrim", 0, 0.45, z0 - fw - 0.2, w + 1.0, 0.9, 0.4)


def door(g, cx, cy, z0, w, h, face="-y", canopy=True):
    s = -1 if face[0] == "-" else 1
    ax = face[1]

    def B(mat, u, dn, z, su, sn, sz):
        if ax == "y":
            g[mat].box(cx + u, cy + s * dn, z, su, sn, sz)
        else:
            g[mat].box(cx + s * dn, cy + u, z, sn, su, sz)

    B("Timber", 0, 0.15, z0 + h / 2, w, 0.3, h)
    for k in range(3):
        B("Iron", 0, 0.35, z0 + h * (k + 0.5) / 3, w + 0.1, 0.12, 0.4)
    B("StoneTrim", 0, 0.3, z0 + h + 0.4, w + 1.2, 0.6, 0.8)
    for su in (-1, 1):
        B("StoneTrim", su * (w / 2 + 0.3), 0.3, z0 + h / 2, 0.6, 0.6, h)
    B("Brass", w * 0.3, 0.45, z0 + h * 0.48, 0.35, 0.3, 0.35)
    B("Stone", 0, 1.0, z0 - 0.25, w + 1.6, 2.0, 0.5)
    if canopy:
        a = 0.35
        if ax == "y":
            g["RoofMetal"].obox(cx, cy + s * 1.1, z0 + h + 1.4, w + 1.8, 2.4, 0.3, rx=s * a)
        else:
            g["RoofMetal"].obox(cx + s * 1.1, cy, z0 + h + 1.4, 2.4, w + 1.8, 0.3, ry=-s * a)


def tube(g, mat, s, e, r, seg=14):
    """s 에서 e 까지 곧은 원통. 방향은 아무래도 좋다"""
    s, e = Vector(s), Vector(e)
    d = e - s
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(g[mat].bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r,
                          depth=d.length, matrix=Matrix.Translation((s + e) / 2) @ rot)


def collar(g, mat, c, d, r, t, seg=14):
    """관에 두르는 짧은 테. c 가 가운데, d 가 관 방향"""
    c, d = Vector(c), Vector(d).normalized()
    tube(g, mat, c - d * t / 2, c + d * t / 2, r, seg)


def bend(g, mat, P, a, b, r, R, n=10, seg=14):
    """
    a 방향으로 들어와 꺾인 자리 P 에서 b 방향으로 나가는 관을 1/4 원환으로 휜다.
    휜 관은 P - aR 에서 시작해 P + bR 에서 끝난다. 곧은 관은 그 두 점까지만 오면 된다
    """
    a, b, P = Vector(a).normalized(), Vector(b).normalized(), Vector(P)
    O = P - a * R + b * R
    n1 = a.cross(b).normalized()
    v = []
    for i in range(n + 1):
        th = HALF_PI * i / n
        c = O - b * R * math.cos(th) + a * R * math.sin(th)
        t = (a * math.cos(th) + b * math.sin(th)).normalized()
        n2 = t.cross(n1).normalized()
        for k in range(seg):
            ph = 2 * math.pi * k / seg
            v.append(tuple(c + (n1 * math.cos(ph) + n2 * math.sin(ph)) * r))
    f = []
    for i in range(n):
        for k in range(seg):
            k2 = (k + 1) % seg
            f.append((i * seg + k, i * seg + k2, (i + 1) * seg + k2, (i + 1) * seg + k))
    f.append(tuple(range(seg))[::-1])
    f.append(tuple(range(n * seg, n * seg + seg)))
    g[mat].add_mesh(v, f)


def pipe(g, pts, r, mat="Copper", flange="Brass", R=None):
    """
    꺾은 관. 꺾이는 자리는 뭉툭한 이음 대신 반지름 R 로 매끈하게 휘고(1/4 원환),
    휜 곳 두 끝과 관 양 끝에 테를 두른다. 점들은 이웃끼리 직각으로 꺾여야 한다
    """
    R = R or r * 2.2
    P = [Vector(p) for p in pts]
    for i in range(len(P) - 1):
        u = (P[i + 1] - P[i]).normalized()
        s = P[i] + u * (R if i > 0 else 0.0)
        e = P[i + 1] - u * (R if i < len(P) - 2 else 0.0)
        assert (e - s).dot(u) > 0, "관 도막이 굽힘 반지름보다 짧다 %s" % (pts,)
        tube(g, mat, s, e, r)
    for i in range(1, len(P) - 1):
        a = (P[i] - P[i - 1]).normalized()
        b = (P[i + 1] - P[i]).normalized()
        bend(g, mat, P[i], a, b, r, R)
        collar(g, flange, P[i] - a * R, a, r * 1.3, 0.3)
        collar(g, flange, P[i] + b * R, b, r * 1.3, 0.3)
    collar(g, flange, P[0] + (P[1] - P[0]).normalized() * 0.2, P[1] - P[0], r * 1.4, 0.4)
    collar(g, flange, P[-1] + (P[-2] - P[-1]).normalized() * 0.2, P[-2] - P[-1], r * 1.4, 0.4)


def banded_cyl(g, mat, cx, cy, z0, r, h, band="Brass", every=6.0, seg=16, cap="Iron"):
    g[mat].cyl(cx, cy, z0, r, r, h, seg=seg)
    k = every
    while k < h - 0.5:
        g[band].cyl(cx, cy, z0 + k - 0.3, r * 1.08, r * 1.08, 0.6, seg=seg)
        k += every
    if cap:
        g[cap].cyl(cx, cy, z0 + h, r * 1.2, r * 1.0, 0.8, seg=seg)


def vent(g, x, y, z):
    g["Vent"].box(x, y, z, 0.6, 0.6, 0.6)


def ring(g, mat, cx, cy, z, r0, r1, t, n=24):
    """가로로 누운 고리판. 둘레 난간 윗가로대나 발판"""
    v = []
    for zz in (z, z + t):
        for r in (r0, r1):
            for k in range(n):
                a = 2 * math.pi * k / n
                v.append((cx + r * math.cos(a), cy + r * math.sin(a), zz))
    f = []
    B0i, B0o, B1i, B1o = 0, n, 2 * n, 3 * n
    for k in range(n):
        k2 = (k + 1) % n
        f.append((B0i + k, B0o + k, B0o + k2, B0i + k2))
        f.append((B1i + k, B1i + k2, B1o + k2, B1o + k))
        f.append((B0o + k, B1o + k, B1o + k2, B0o + k2))
        f.append((B0i + k, B0i + k2, B1i + k2, B1i + k))
    g[mat].add_mesh(v, f)


# ---------------------------------------------------------------- 집 셋

def house_a(g):
    W, D = 14.0, 12.0
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Brick"].box(0, 0, 1.5 + 5.0, W, D, 10.0)
    g["StoneTrim"].box(0, 0, 11.9, W + 0.8, D + 0.8, 0.8)
    g["BrickDark"].box(0, 0, 12.3 + 4.0, W + 0.6, D + 0.6, 8.0)
    g["StoneTrim"].box(0, 0, 20.6, W + 1.2, D + 1.2, 0.6)
    roof_gable(g, 0, 0, 20.9, W + 0.6, D + 0.6, 9.0, along="y")
    fy = -D / 2
    door(g, -3.2, fy, 1.5, 3.2, 6.6)
    window(g, 3.4, fy, 4.0, 2.6, 3.6)
    for x in (-3.4, 3.4):
        window(g, x, fy - 0.3, 14.0, 2.4, 3.4)
    # 박공 둥근 창
    g["Brass"].hcyl(0, fy - 0.3, 25.0, 1.9, 0.25, axis="y", seg=16)
    g["Glow"].hcyl(0, fy - 0.5, 25.0, 1.5, 0.25, axis="y", seg=16)
    # 뒤 창
    for x in (-3.4, 3.4):
        window(g, x, D / 2, 4.0, 2.4, 3.4, face="+y")
        window(g, x, D / 2 + 0.3, 14.0, 2.4, 3.4, face="+y")
    # 옆 보일러 굴뚝과 벽으로 드는 관
    bx = W / 2 + 1.6
    banded_cyl(g, "Copper", bx, 2.0, 1.5, 1.4, 31.5, every=5.5)
    vent(g, bx, 2.0, 34.0)
    pipe(g, [(bx, 2.0 - 1.4, 8.0), (bx, -2.5, 8.0), (W / 2, -2.5, 8.0)], 0.45, mat="Iron")
    g["Brass"].hcyl(bx + 1.35, 2.0, 6.0, 0.7, 0.3, axis="x", seg=14)   # 압력계
    window(g, W / 2, -2.5, 14.0, 2.2, 3.2, face="+x")
    gear(g, "Brass", 0, fy - 0.5, 15.7, 1.3, 10, 0.3)                    # 이층 가운데 톱니 문장
    gear(g, "Copper", W / 2 + 0.25, -2.5, 19.3, 0.9, 8, 0.3, axis="x")


def house_b(g):
    W, D = 20.0, 14.0
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Brick"].box(0, 0, 1.5 + 6.0, W, D, 12.0)
    g["StoneTrim"].box(0, 0, 13.8, W + 0.8, D + 0.8, 0.6)
    R = D / 2 + 0.8
    zc = 14.1
    arc_shell(g, "RoofMetal", -W / 2 - 0.6, W / 2 + 0.6, 0, zc, R - 0.6, R, n=20)
    # 골함석 이음. 바깥에 가는 고리를 일정하게
    k = -W / 2
    while k <= W / 2 + 0.01:
        arc_shell(g, "IronLight", k - 0.2, k + 0.2, 0, zc, R, R + 0.25, n=20)
        k += 2.5
    # 눈. 꼭대기 쪽 110 도만
    arc_shell(g, "SnowCap", -W / 2 - 0.4, W / 2 + 0.4, 0, zc, R + 0.25, R + 0.8,
              a0=math.radians(35), a1=math.radians(145), n=12)
    for s in (-1, 1):
        half_disc(g, "BrickDark", s * W / 2, 0, zc, R - 0.6, 0.6)
        gear(g, "Brass" if s > 0 else "Copper", s * (W / 2 + 0.45), 0, zc + 2.8, 2.2, 12, 0.4, axis="x")
    fy = -D / 2
    door(g, -4.5, fy, 1.5, 4.4, 7.6)
    g["Iron"].box(-4.5, fy - 0.5, 10.0, 8.0, 0.3, 0.3)                    # 미닫이 문 레일
    g["Brass"].hcyl(4.8, fy - 0.15, 8.0, 2.7, 0.3, axis="y", seg=18)
    g["Glow"].hcyl(4.8, fy - 0.4, 8.0, 2.2, 0.25, axis="y", seg=18)
    for a in range(4):
        g["Iron"].obox(4.8, fy - 0.6, 8.0, 4.4, 0.2, 0.2, ry=a * math.pi / 4)
    window(g, 8.3, fy, 4.0, 1.8, 3.0, cross=False)
    # 옆 눕힌 보일러 통
    tx = W / 2 + 3.4
    g["Copper"].hcyl(tx, 0, 5.2, 2.6, 9.0, axis="y", seg=18)
    for yy in (-3.5, 0.0, 3.5):
        g["Brass"].hcyl(tx, yy, 5.2, 2.75, 0.5, axis="y", seg=18)
    for yy in (-3.0, 3.0):
        g["Iron"].box(tx, yy, 1.3, 3.8, 0.8, 2.6)
    g["Brass"].hcyl(tx + 2.65, -1.5, 6.4, 0.8, 0.3, axis="x", seg=14)
    pipe(g, [(tx, 3.0, 7.8), (tx, 3.0, 23.0)], 0.6, mat="Iron")
    vent(g, tx, 3.0, 23.8)
    pipe(g, [(tx - 2.6, -2.0, 5.2), (W / 2, -2.0, 5.2)], 0.5, mat="Copper")
    # 지붕 뚫고 나온 굴뚝
    banded_cyl(g, "Iron", -6.0, 2.0, 18.0, 0.9, 7.5, band="Brass", every=3.0)
    vent(g, -6.0, 2.0, 26.5)
    for x in (-6.5, 0.0, 6.5):
        window(g, x, D / 2, 5.0, 2.2, 3.4, face="+y")


def house_c(g):
    W, D = 12.0, 12.0
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Brick"].box(0, 0, 1.5 + 4.5, W, D, 9.0)
    g["StoneTrim"].box(0, 0, 10.8, W + 0.8, D + 0.8, 0.6)
    g["BrickDark"].box(0, 0, 11.1 + 4.2, W, D, 8.4)
    g["StoneTrim"].box(0, 0, 19.8, W + 0.8, D + 0.8, 0.6)
    g["Brick"].box(0, 0, 20.1 + 3.6, W, D, 7.2)
    g["StoneTrim"].box(0, 0, 27.6, W + 1.4, D + 1.4, 0.6)
    pyramid(g, "RoofMetal", 0, 0, 27.9, W + 2.0, D + 2.0, 8.0)
    pyramid(g, "SnowCap", 0, 0, 27.9, W + 2.0, D + 2.0, 8.0, frac=0.72, lift=0.35)
    g["Brass"].cyl(0, 0, 35.8, 0.35, 0.05, 3.0, seg=8)
    # 모서리 원통 탑 (앞 오른쪽)
    tx, ty = W / 2, -D / 2
    g["BrickDark"].cyl(tx, ty, 9.0, 2.6, 2.6, 21.0, seg=16)
    g["StoneTrim"].cyl(tx, ty, 29.8, 2.9, 2.9, 0.6, seg=16)
    g["RoofMetal"].cyl(tx, ty, 30.4, 3.1, 0.2, 6.5, seg=16)
    gear(g, "Brass", tx, ty - 2.75, 27.8, 1.1, 8, 0.3)
    g["SnowCap"].cyl(tx, ty, 31.9, 2.35, 0.2, 5.2, seg=16)
    for z in (13.0, 22.5):
        g["Glow"].box(tx + 1.2, ty - 1.9, z + 1.6, 1.3, 1.3, 3.0)
        g["Iron"].box(tx + 1.2, ty - 2.0, z + 3.3, 1.8, 1.4, 0.4)
    fy = -D / 2
    door(g, -2.6, fy, 1.5, 3.0, 6.4)
    window(g, 2.0, fy, 4.0, 2.2, 3.2)
    for z in (13.0, 22.0):
        window(g, -2.6, fy, z, 2.4, 3.4)
    # 발코니. 이층 앞
    g["IronLight"].box(-2.6, fy - 1.4, 19.9, 6.0, 2.8, 0.4)
    for x in (-5.4, -3.5, -1.7, 0.2):
        g["Iron"].box(x, fy - 2.7, 21.1, 0.25, 0.25, 2.2)
    g["Iron"].box(-2.6, fy - 2.7, 22.2, 6.0, 0.3, 0.3)
    for s in (-1, 1):
        g["Iron"].box(-2.6 + s * 2.9, fy - 1.4, 22.2, 0.3, 2.8, 0.3)
    # 옆 빗물 관과 보일러
    pipe(g, [(-W / 2 - 0.6, 3.5, 27.6), (-W / 2 - 0.6, 3.5, 1.5)], 0.35, mat="Iron", flange="Iron")
    banded_cyl(g, "Copper", -W / 2 - 1.8, -2.5, 1.5, 1.2, 6.0, every=2.5)
    vent(g, -W / 2 - 1.8, -2.5, 8.5)
    for z in (4.0, 13.0, 22.0):
        window(g, W / 2, 2.5, z, 2.2, 3.2, face="+x")
        window(g, -W / 2, -2.5 + 5.0, z, 2.2, 3.2, face="-x")
        window(g, 0, D / 2, z, 2.4, 3.2, face="+y")


# ---------------------------------------------------------------- 감정 변환로

def herzofen(g):
    PR = 20.0
    g["Stone"].cyl(0, 0, 0, PR, PR, 2.0, seg=32)
    g["StoneTrim"].cyl(0, 0, 2.0, PR + 0.4, PR + 0.4, 0.5, seg=32)
    for a in range(4):
        ang = a * HALF_PI + math.pi / 4
        g["Stone"].obox((PR + 1.2) * math.cos(ang), (PR + 1.2) * math.sin(ang), 0.5, 3.0, 8.0, 1.0, rz=ang)
    R, top = 10.0, 36.0
    g["Iron"].cyl(0, 0, 2.5, R, R, top - 2.5, seg=28)
    for z in (5.0, 12.0, 19.0, 26.0, 33.0):
        g["Brass"].cyl(0, 0, z - 0.5, R + 0.35, R + 0.35, 1.0, seg=28)
        # 띠마다 리벳. 쇠빛으로 박아 놋쇠 띠 위에서 도드라지게 한다
        for k in range(24):
            a = 2 * math.pi * (k + 0.5) / 24
            g["Iron"].obox((R + 0.42) * math.cos(a), (R + 0.42) * math.sin(a), z, 0.3, 0.35, 0.35, rz=a)
    for z in (8.5, 15.5, 22.5, 29.5):
        g["Core"].cyl(0, 0, z - 0.7, R + 0.15, R + 0.15, 1.4, seg=28)
    for k in range(16):
        a = 2 * math.pi * k / 16
        g["IronLight"].obox((R + 0.3) * math.cos(a), (R + 0.3) * math.sin(a), 2.5 + (top - 2.5) / 2, 0.8, 0.6,
                            top - 2.5, rz=a)
    # 달아오른 들여다보기 창 넷
    for a in range(4):
        ang = a * HALF_PI
        cx, cy = (R + 0.4) * math.cos(ang), (R + 0.4) * math.sin(ang)
        axis = "x" if a % 2 == 0 else "y"
        k = (R + 0.3) / (R + 0.4)
        g["Brass"].hcyl(cx * k, cy * k, 18.5, 2.2, 0.35, axis=axis, seg=16)
        k = (R + 0.6) / (R + 0.4)
        g["Core"].hcyl(cx * k, cy * k, 18.5, 1.7, 0.3, axis=axis, seg=16)
    # 덮개와 유리 속 핵
    g["Iron"].cyl(0, 0, top, R, 6.5, 4.0, seg=28)
    for z, r0, r1, h in ((40.0, 4.0, 5.6, 2.2), (42.2, 5.6, 5.9, 2.4), (44.6, 5.9, 5.2, 2.4), (47.0, 5.2, 3.2, 2.2),
                         (49.2, 3.2, 0.8, 1.6)):
        g["Core"].cyl(0, 0, z, r0, r1, h, seg=20)
    for k in range(8):
        a = 2 * math.pi * k / 8
        g["Brass"].obox(6.3 * math.cos(a), 6.3 * math.sin(a), 44.6, 0.5, 0.5, 9.5, rz=a)
    g["Brass"].cyl(0, 0, 49.0, 6.6, 6.6, 0.6, seg=20)
    g["Brass"].cyl(0, 0, 49.6, 1.8, 1.8, 3.0, seg=12)
    g["Brass"].cyl(0, 0, 52.6, 0.6, 0.05, 5.0, seg=8)
    g["LampPt"].box(0, 0, 45.0, 0.6, 0.6, 0.6)
    # 두름 발판과 난간
    ring(g, "IronLight", 0, 0, 24.0, R, R + 4.0, 0.5, n=32)
    ring(g, "Iron", 0, 0, 27.4, R + 3.7, R + 4.0, 0.3, n=32)
    for k in range(16):
        a = 2 * math.pi * k / 16
        g["Iron"].box((R + 3.85) * math.cos(a), (R + 3.85) * math.sin(a), 25.95, 0.3, 0.3, 3.0)
        if k % 2 == 0 and k != 10:
            g["Iron"].obox((R + 1.8) * math.cos(a), (R + 1.8) * math.sin(a), 22.6, 3.6, 0.5, 0.5, rz=a)
    # 사다리. 들여다보기 창과 겹치지 않게 남서 대각선에 단다
    ua = math.radians(225)
    lx, ly = (R + 1.0) * math.cos(ua), (R + 1.0) * math.sin(ua)
    tx, ty = math.cos(ua + HALF_PI), math.sin(ua + HALF_PI)
    for k in range(12):
        g["Iron"].obox(lx, ly, 3.5 + k * 1.8, 1.8, 0.25, 0.25, rz=ua + HALF_PI)
    for s in (-1, 1):
        g["Iron"].box(lx + s * 0.9 * tx, ly + s * 0.9 * ty, 13.3, 0.25, 0.25, 21.5)
    # 굴뚝 넷
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 11.2, sy * 11.2
            banded_cyl(g, "Iron", cx, cy, 2.5, 1.8, 50.0, band="Brass", every=8.0)
            vent(g, cx, cy, 53.8)
    # 큰 관 넷. 로에서 나와 단 끝에서 매끈하게 꺾여 땅으로 든다
    for a in range(4):
        ang = a * HALF_PI + math.pi / 8
        ux, uy = math.cos(ang), math.sin(ang)
        e = PR - 2.0
        pipe(g, [(ux * (R + 0.2), uy * (R + 0.2), 9.0), (ux * e, uy * e, 9.0), (ux * e, uy * e, 2.5)], 1.5, R=3.4)
        collar(g, "Brass", (ux * (R + 0.6), uy * (R + 0.6), 9.0), (ux, uy, 0), 2.1, 0.6)   # 로 몸통에 붙는 목
        # 받침판과 볼트 넷
        g["Iron"].obox(ux * e, uy * e, 2.65, 4.2, 4.2, 0.3, rz=ang)
        for sx in (-1, 1):
            for sy in (-1, 1):
                bx = ux * e + (sx * ux - sy * uy) * 1.45
                by = uy * e + (sx * uy + sy * ux) * 1.45
                g["Brass"].cyl(bx, by, 2.8, 0.28, 0.28, 0.3, seg=6)


# ---------------------------------------------------------------- 공방 셋

def zapfen(g):
    W, D = 60.0, 34.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    g["Brick"].box(0, 0, 2.0 + 10.0, W, D, 20.0)
    g["StoneTrim"].box(0, 0, 22.3, W + 1.2, D + 1.2, 0.6)
    fy = -D / 2
    for k in range(9):
        x = -W / 2 + 3 + k * (W - 6) / 8
        if abs(x) < 8:
            continue
        g["BrickDark"].box(x, fy - 0.4, 12.0, 1.6, 0.8, 20.0)
        g["BrickDark"].box(x, D / 2 + 0.4, 12.0, 1.6, 0.8, 20.0)
    # 톱날 지붕. 뒤(+y)를 향해 오르는 비탈 다섯, 각 이빨 뒷면은 유리 벽
    n, rise = 5, 8.0
    tooth = D / n
    for k in range(n):
        y0 = -D / 2 + k * tooth
        a = math.atan2(rise, tooth)
        Lr = math.hypot(tooth, rise)
        g["RoofMetal"].obox(0, y0 + tooth / 2, 22.6 + rise / 2, W + 1.0, Lr, 0.6, rx=a)
        g["SnowCap"].obox(0, y0 + tooth / 2 - 0.2, 22.9 + rise / 2, W + 0.4, Lr * 0.8, 0.5, rx=a)
        g["Glow"].box(0, y0 + tooth - 0.15, 22.6 + rise / 2, W - 1.0, 0.3, rise - 0.6)
        for m in range(9):
            g["Iron"].box(-W / 2 + 3 + m * (W - 6) / 8, y0 + tooth - 0.05, 22.6 + rise / 2, 0.4, 0.4, rise - 0.6)
    for s in (-1, 1):
        # 옆 박공. 톱날 단면을 막는다
        for k in range(n):
            y0 = -D / 2 + k * tooth
            v = [(s * W / 2, y0, 22.6), (s * W / 2, y0 + tooth, 22.6), (s * W / 2, y0 + tooth, 22.6 + rise),
                 (s * (W / 2 - 0.8), y0, 22.6), (s * (W / 2 - 0.8), y0 + tooth, 22.6),
                 (s * (W / 2 - 0.8), y0 + tooth, 22.6 + rise)]
            g["BrickDark"].add_mesh(v, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    # 앞 박공벽과 큰 톱니 문장
    g["BrickDark"].box(0, fy + 0.6, 22.6 + 5.0, 24.0, 1.2, 10.0)
    g["StoneTrim"].box(0, fy + 0.4, 32.9, 25.0, 1.6, 0.6)
    # 문장 톱니는 Snow_City 가 돌아가는 톱니로 단다. 여기는 굴대 받침만
    g["Iron"].hcyl(0, fy - 0.3, 28.0, 0.9, 0.6, axis="y", seg=12)
    g["Iron"].hcyl(-5.77, fy - 0.3, 28.0, 0.6, 0.6, axis="y", seg=12)   # 작은 톱니는 같은 높이 옆(맞물림 5.77)
    g["Iron"].box(0, fy - 0.4, 22.0, 14.0, 0.5, 2.0)                  # 이름판
    g["Brass"].box(0, fy - 0.7, 22.0, 12.6, 0.2, 1.2)
    # 큰 짐문. 문 위는 돌 아치
    GW, GH = 12.0, 13.0
    g["Timber"].box(0, fy - 0.15, 2.0 + GH / 2, GW, 0.4, GH)
    g["Iron"].box(0, fy - 0.4, 2.0 + GH / 2, 0.5, 0.2, GH)
    for k in range(4):
        g["Iron"].box(0, fy - 0.4, 2.0 + GH * (k + 0.5) / 4, GW, 0.2, 0.45)
    for s in (-1, 1):
        g["StoneTrim"].box(s * (GW / 2 + 0.6), fy - 0.3, 2.0 + GH / 2, 1.2, 0.8, GH)
    g["StoneTrim"].box(0, fy - 0.3, 2.0 + GH + 0.6, GW + 2.4, 0.8, 1.2)
    g["Stone"].box(0, fy - 2.0, 1.0, GW + 4, 4.0, 2.0)
    # 긴 아치창. 짐문 양옆 셋씩
    for k in range(3):
        for s in (-1, 1):
            x = s * (11.0 + k * 7.0)
            window(g, x, fy, 7.0, 3.0, 9.0, cross=True)
            g["Glow"].hcyl(x, fy - 0.1 - WIN_OUT, 16.0, 1.5, 0.2, axis="y", seg=12)
            window(g, x, D / 2, 7.0, 3.0, 9.0, face="+y")
    # 굴뚝 셋. 뒤쪽. 높이를 달리한다
    for x, h in ((-19.0, 56.0), (0.0, 50.0), (19.0, 53.0)):
        yy = D / 2 - 3.0
        g["Brick"].box(x, yy, 2.0 + h / 2, 4.6, 4.6, h)
        for z in (20.0, 36.0, h - 1.0):
            g["StoneTrim"].box(x, yy, 2.0 + z, 5.2, 5.2, 0.8)
        g["Iron"].box(x, yy, 2.0 + h + 0.5, 5.4, 5.4, 1.0)
        vent(g, x, yy, 2.0 + h + 1.4)
    # 앞벽을 따라 도는 구리 관. 벽 속에서 나와 꺾여 벽기둥 앞(fy - 1.5)을 지나 땅으로 든다
    for sx in (-1, 1):
        pipe(g, [(sx * (W / 2 - 1), fy + 1.0, 19.0), (sx * (W / 2 - 1), fy - 1.5, 19.0), (sx * 8.0, fy - 1.5, 19.0),
                 (sx * 8.0, fy - 1.5, 2.0)], 0.7)
    # 옆 사무동(+x). 이층
    ox = W / 2 + 7.5
    g["Stone"].box(ox, 4.0, 1.0, 15.0, 18.0, 2.0)
    g["BrickDark"].box(ox, 4.0, 2.0 + 8.5, 14.0, 16.0, 17.0)
    g["StoneTrim"].box(ox, 4.0, 19.8, 14.8, 16.8, 0.6)
    roof_gable(g, ox, 4.0, 20.1, 14.6, 16.6, 6.5, along="x", gable="Brick")
    for z in (4.0, 12.0):
        for yy in (-1.0, 5.0, 10.0):
            window(g, ox + 7.0, yy, z, 2.2, 3.2, face="+x")
    door(g, ox, 4.0 - 8.0, 2.0, 3.0, 6.6)
    window(g, ox + 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2)
    window(g, ox - 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2)
    # 왼쪽 짐 부리는 곳. 나무 단과 궤짝
    lx = -W / 2 - 5.0
    g["Timber"].box(lx, -6.0, 1.5, 10.0, 14.0, 3.0)
    for x, y, s in ((-1.5, -9.0, 3.2), (1.8, -8.6, 2.6), (-1.0, -4.5, 3.0), (-1.2, -9.0, 2.4)):
        z = 3.0 + s / 2 if s != 2.4 else 3.0 + 3.2 + 1.2
        g["Timber"].box(lx + x, y, z, s, s, s)
        g["Iron"].box(lx + x, y, z, s + 0.1, s + 0.1, 0.3)


def frostig(g):
    W, D = 24.0, 18.0
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Brick"].box(0, 0, 1.5 + 5.25, W, D, 10.5)
    g["StoneTrim"].box(0, 0, 12.3, W + 1.0, D + 1.0, 0.6)
    g["BrickDark"].box(0, -0.3, 12.6 + 4.5, W + 0.4, D + 0.6, 9.0)
    g["StoneTrim"].box(0, -0.3, 21.4, W + 1.4, D + 1.4, 0.6)
    roof_gable(g, 0, -0.3, 21.7, D + 0.6, W + 0.4, 8.0, along="x")
    fy = -D / 2
    # 진열창. 넓게, 쇠살 셋
    SX, SW, SH = 4.5, 10.0, 5.2
    g["Glow"].box(SX, fy - 0.1 - WIN_OUT, 3.3 + SH / 2, SW, 0.2, SH)
    g["Brass"].box(SX, fy - 0.3, 3.3 + SH + 0.2, SW + 0.8, 0.4, 0.4)
    g["Brass"].box(SX, fy - 0.3, 3.3 - 0.2, SW + 0.8, 0.4, 0.4)
    for k in range(4):
        g["Iron"].box(SX - SW / 2 + k * SW / 3, fy - 0.3, 3.3 + SH / 2, 0.3, 0.4, SH)
    g["StoneTrim"].box(SX, fy - 0.5, 2.8, SW + 1.2, 1.0, 0.5)
    # 차양
    g["Banner"].obox(SX, fy - 1.6, 10.3, SW + 1.2, 3.4, 0.25, rx=-0.45)
    door(g, -6.0, fy, 1.5, 3.4, 7.0, canopy=False)
    # 총 간판. 벽에서 뻗은 쇠 팔에 매단 놋쇠 판과 장총 모양
    g["Iron"].box(-1.2, fy - 1.6, 11.2, 0.35, 3.2, 0.35)
    g["Brass"].box(-1.2, fy - 2.9, 9.3, 0.3, 2.6, 3.0)
    g["Iron"].box(-1.4, fy - 2.9, 9.8, 0.3, 4.6, 0.35)          # 총열
    g["Timber"].obox(-1.4, fy - 1.6, 9.2, 0.35, 1.8, 0.9, rx=0.3)  # 개머리
    for yy in (-2.2, -3.6):
        g["Iron"].box(-1.2, fy + yy + 0.5, 10.8, 0.1, 0.1, 0.9)
    # 이층 창
    for x in (-7.0, 0.0, 7.0):
        window(g, x, fy - 0.6, 14.5, 2.6, 3.8)
    # 지붕창 둘
    for x in (-5.0, 5.0):
        g["BrickDark"].box(x, fy + 2.4, 25.0, 3.6, 3.0, 3.6)
        g["RoofMetal"].obox(x, fy + 2.2, 27.3, 4.6, 3.6, 0.4, rx=-0.3)
        g["Glow"].box(x, fy + 0.85, 24.8, 2.2, 0.2, 2.4)
    # 대장간 굴뚝(+x). 꼭대기가 달아 있다
    cx = W / 2 + 1.6
    g["Brick"].box(cx, 3.0, 1.5 + 14.5, 3.2, 3.2, 29.0)
    g["StoneTrim"].box(cx, 3.0, 20.0, 3.8, 3.8, 0.6)
    g["Core"].box(cx, 3.0, 30.7, 2.6, 2.6, 0.5)
    g["Iron"].box(cx, 3.0, 31.2, 3.6, 3.6, 0.5)
    vent(g, cx, 3.0, 32.0)
    # 옆 헛간(-x). 모루와 작업대
    hx = -W / 2 - 4.0
    g["Stone"].box(hx, 0, 0.5, 8.0, 12.0, 1.0)
    for y in (-5.5, 5.5):
        g["Timber"].box(hx - 3.4, y, 5.5, 0.6, 0.6, 9.0)
    g["RoofMetal"].obox(hx, 0, 10.4, 9.0, 13.0, 0.4, ry=0.25)
    g["SnowCap"].obox(hx + 0.2, 0, 10.8, 8.0, 12.4, 0.4, ry=0.25)
    g["Timber"].cyl(hx, -2.0, 1.0, 1.1, 1.1, 2.4, seg=10)
    g["Iron"].box(hx, -2.0, 3.8, 1.2, 2.8, 0.8)
    g["Iron"].box(hx, -3.0, 3.6, 0.8, 0.8, 0.6)
    g["Timber"].box(hx - 1.0, 3.5, 3.4, 3.0, 5.0, 0.4)
    for y in (1.4, 5.6):
        for x in (-2.2, 0.2):
            g["Timber"].box(hx + x, y, 1.9, 0.4, 0.4, 2.8)
    gear(g, "Brass", 0, D / 2 + 0.3, 16.0, 2.2, 10, 0.5)   # 뒤 박공 톱니
    window(g, -6.0, D / 2, 4.0, 2.4, 3.4, face="+y")
    window(g, 6.0, D / 2, 4.0, 2.4, 3.4, face="+y")


def sel_ruin(g):
    """설 공방 폐허. 벽은 판으로 세우고 윗선을 들쭉날쭉하게 부순다. 지붕은 무너져 서까래만 남았다"""
    W, D, T = 24.0, 18.0, 1.2
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Char"].box(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)     # 그을린 바닥
    # 앞벽. (x0, x1, 높이) 조각. 문 자리(-7.6..-4.4)는 비우고 문틀만 남긴다
    front = [(-12, -9.5, 14.0), (-9.5, -7.6, 18.5), (-4.4, -1.0, 16.0), (-1.0, 2.6, 9.5), (2.6, 4.0, 5.5),
             (4.0, 8.5, 12.0), (8.5, 12, 20.5)]
    back = [(-12, -6.0, 12.5), (-6.0, -2.0, 21.0), (-2.0, 3.0, 17.5), (3.0, 7.5, 8.0), (7.5, 12, 15.0)]
    left = [(-9, -3.0, 19.5), (-3.0, 2.5, 11.0), (2.5, 9, 16.5)]
    right = [(-9, -4.0, 6.5), (-4.0, 1.5, 13.5), (1.5, 9, 20.0)]
    # 벽 조각 하나를 아래 벽돌과 위 그을음 두 켜로. 불이 위에서 벽을 태웠다
    def wall(cx, cy, sx, sy, h):
        low = min(h, 5.5 + (cx * 7.3 + cy * 3.1) % 3.0)
        g["BrickDark"].box(cx, cy, 1.5 + low / 2, sx, sy, low)
        if h > low:
            g["Soot"].box(cx, cy, 1.5 + low + (h - low) / 2, sx, sy, h - low)
    for x0, x1, h in front:
        wall((x0 + x1) / 2, -D / 2 + T / 2, x1 - x0, T, h)
    for x0, x1, h in back:
        wall((x0 + x1) / 2, D / 2 - T / 2, x1 - x0, T, h)
    for y0, y1, h in left:
        wall(-W / 2 + T / 2, (y0 + y1) / 2, T, y1 - y0, h)
    for y0, y1, h in right:
        wall(W / 2 - T / 2, (y0 + y1) / 2, T, y1 - y0, h)
    # 창 구멍 자리를 까만 판으로. 불빛이 없다
    for x in (-10.7, 6.2, 10.3):
        g["Char"].box(x, -D / 2 - 0.05, 6.5, 1.6, 0.2, 3.0)
    # 문틀. 숯이 된 나무가 서 있다
    for s in (-1, 1):
        g["Char"].box(-6.0 + s * 1.7, -D / 2 - 0.2, 1.5 + 3.8, 0.6, 1.6, 7.6)
    g["Char"].box(-6.0, -D / 2 - 0.2, 1.5 + 7.9, 4.2, 1.6, 0.6)
    for k in range(3):
        g["Char"].obox(-6.0, -D / 2 - 0.6, 3.0 + k * 2.2, 3.6, 0.3, 0.5, ry=0.15 * (k - 1))   # 덧댄 판자
    # 무너진 지붕. 서까래 몇 개가 걸려 있고 나머지는 안으로 떨어졌다
    for x, rx_, ry_, z, L_ in ((-8.0, 0.55, 0.0, 17.5, 20.0), (-3.0, 0.62, 0.05, 16.0, 19.0),
                               (4.5, -0.5, 0.0, 14.0, 17.0), (9.5, 0.2, 0.1, 18.8, 19.5)):
        g["Char"].obox(x, 0, z, 0.8, L_, 0.8, rx=rx_, ry=ry_)
    g["Char"].obox(0, 2.0, 18.5, W - 3.0, 0.8, 0.8, rz=0.08)     # 남은 도리
    g["RoofMetal"].obox(7.5, 4.5, 16.5, 8.0, 9.0, 0.3, rx=0.45, ry=-0.2)   # 걸린 지붕 조각
    for x, y, rz_, ry_ in ((-6.0, 3.0, 0.4, 0.2), (2.0, -2.0, -0.8, 0.1), (6.5, 1.0, 1.2, -0.15), (-1.0, 5.5, 0.1, 0.05)):
        g["Char"].obox(x, y, 2.4, 0.8, 10.0, 0.8, rz=rz_, ry=ry_)
    # 부서진 굴뚝
    g["Brick"].box(W / 2 + 1.6, 3.0, 1.5 + 6.5, 3.2, 3.2, 13.0)
    g["Brick"].box(W / 2 + 1.2, 2.4, 15.5, 2.0, 2.2, 3.0)
    # 잔해 더미와 쌓인 눈
    for x, y, s in ((-8.0, -4.0, 2.4), (-6.8, -2.6, 1.6), (3.0, 4.0, 2.0), (7.8, -5.0, 1.8), (-2.0, 6.0, 1.4)):
        g["Soot"].obox(x, y, 1.5 + s / 2, s, s * 1.3, s, rz=x * 0.3)
    g["SnowCap"].obox(-4.0, 1.0, 1.9, 9.0, 7.0, 0.6, rz=0.3)
    g["SnowCap"].obox(6.0, 5.0, 2.0, 6.0, 5.0, 0.8, rz=-0.2)
    g["SnowCap"].box(-W / 2 + 3.0, -D / 2 + 3.0, 1.9, 4.0, 4.0, 0.6)
    # 떨어진 톱니. 녹이 슬었다
    gear(g, "Copper", 4.0, -3.0, 2.3, 2.6, 12, 0.6, axis="z")
    g["Soot"].box(-W / 2 - 0.2, 5.0, 1.6, 0.2, 0.2, 0.2)


def figuren(g):
    W, D = 44.0, 26.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    g["Stone"].box(0, 0, 2.0 + 9.0, W, D, 18.0)
    for z in (10.0, 20.0):
        g["StoneTrim"].box(0, 0, z + 0.3, W + 0.8, D + 0.8, 0.6)
    # 성가퀴. 룩 모양 총안
    def merlons(x0, x1, y0, y1, z, step=3.0, s=1.6, h=2.6):
        n = int(round(abs(x1 - x0) / step)) if x1 != x0 else int(round(abs(y1 - y0) / step))
        for k in range(n + 1):
            t = k / max(1, n)
            g["Stone"].box(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + h / 2, s, s, h)
    merlons(-W / 2 + 0.8, W / 2 - 0.8, -D / 2 + 0.8, -D / 2 + 0.8, 20.6)
    merlons(-W / 2 + 0.8, W / 2 - 0.8, D / 2 - 0.8, D / 2 - 0.8, 20.6)
    merlons(-W / 2 + 0.8, -W / 2 + 0.8, -D / 2 + 3.8, D / 2 - 3.8, 20.6)
    merlons(W / 2 - 0.8, W / 2 - 0.8, -D / 2 + 3.8, D / 2 - 3.8, 20.6)
    g["Stone"].box(0, 0, 20.9, W - 1.0, D - 1.0, 0.6)
    # 가운데 탑. 앞으로 조금 나왔다
    TX, TY, TW, TH = 0.0, -D / 2 + 3.0, 12.0, 40.0
    g["Stone"].box(TX, TY, 2.0 + TH / 2, TW, TW, TH)
    for z in (20.0, 30.0, 39.0):
        g["StoneTrim"].box(TX, TY, 2.0 + z, TW + 0.8, TW + 0.8, 0.6)
    g["StoneTrim"].box(TX, TY, 2.0 + TH + 0.8, TW + 2.4, TW + 2.4, 1.6)
    for k in range(4):
        for s in (-1, 1):
            u = -TW / 2 - 0.4 + k * (TW + 0.8) / 3
            g["Stone"].box(TX + u, TY + s * (TW / 2 + 0.4), 2.0 + TH + 3.2, 2.2, 2.2, 3.2)
            g["Stone"].box(TX + s * (TW / 2 + 0.4), TY + u, 2.0 + TH + 3.2, 2.2, 2.2, 3.2)
    # 시계 톱니와 바늘
    gear(g, "Brass", TX, TY - TW / 2 - 0.4, 2.0 + 33.5, 4.2, 18, 0.8)
    # 시계 바늘은 Snow_City 가 따로 달아 돌린다
    # 깃대와 깃발
    g["Iron"].cyl(TX, TY, 2.0 + TH + 1.6, 0.35, 0.3, 14.0, seg=8)
    g["Banner"].box(TX + 3.2, TY, 2.0 + TH + 12.0, 6.0, 0.2, 3.6)
    g["Brass"].box(TX + 3.2, TY - 0.15, 2.0 + TH + 12.0, 1.4, 0.1, 1.4)
    # 앞 모서리 원통 탑 둘
    for s in (-1, 1):
        cx, cy = s * (W / 2 - 1.0), -D / 2 + 1.0
        g["Stone"].cyl(cx, cy, 2.0, 3.4, 3.4, 26.0, seg=16)
        g["StoneTrim"].cyl(cx, cy, 27.4, 3.9, 3.9, 1.0, seg=16)
        for k in range(8):
            a = 2 * math.pi * k / 8
            g["Stone"].obox(cx + 3.3 * math.cos(a), cy + 3.3 * math.sin(a), 29.6, 1.6, 1.6, 2.6, rz=a)
        for z in (8.0, 17.0):
            g["Glow"].box(cx, cy - 3.35, z + 1.6, 0.8, 0.3, 3.2)
    # 문. 탑 밑 무거운 쇠문
    fy = TY - TW / 2
    g["Iron"].box(TX, fy - 0.2, 2.0 + 4.5, 5.0, 0.4, 9.0)
    for k in range(5):
        for m in range(3):
            g["Brass"].box(TX - 1.8 + m * 1.8, fy - 0.45, 3.2 + k * 1.8, 0.35, 0.2, 0.35)
    g["StoneTrim"].box(TX, fy - 0.4, 2.0 + 9.6, 6.6, 0.8, 1.2)
    for s in (-1, 1):
        g["StoneTrim"].box(TX + s * 3.0, fy - 0.4, 2.0 + 4.5, 0.8, 0.8, 9.0)
        g["Banner"].box(TX + s * 4.8, fy - 0.3, 2.0 + 12.0, 2.4, 0.2, 7.0)
    g["Stone"].box(TX, fy - 2.4, 1.0, 9.0, 4.8, 2.0)
    g["Stone"].box(TX, fy - 5.4, 0.5, 9.0, 1.2, 1.0)
    # 좁은 총안 창. 줄지어
    for z in (4.0, 13.5):
        for k in range(7):
            x = -W / 2 + 5.0 + k * 5.6
            if abs(x) < TW / 2 + 1.0:
                continue
            g["Glow"].box(x, -D / 2 - 0.1 - WIN_OUT, z + 2.0, 0.8, 0.2, 4.0)
            g["StoneTrim"].box(x, -D / 2 - 0.3, z - 0.2, 1.6, 0.6, 0.4)
            g["Glow"].box(x, D / 2 + 0.1 + WIN_OUT, z + 2.0, 0.8, 0.2, 4.0)
    for s in (-1, 1):
        for k in range(3):
            g["Glow"].box(s * (W / 2 + 0.1 + WIN_OUT), -6.0 + k * 6.0, 15.5, 0.2, 0.8, 4.0)
    pipe(g, [(W / 2 - 4.0, D / 2 + 0.8, 1.0), (W / 2 - 4.0, D / 2 + 0.8, 24.0)], 0.6, mat="Iron")
    vent(g, W / 2 - 4.0, D / 2 + 0.8, 24.8)


# ---------------------------------------------------------------- 소품

def gas_lamp(g):
    g["Iron"].box(0, 0, 0.4, 1.4, 1.4, 0.8)
    g["Iron"].cyl(0, 0, 0.8, 0.5, 0.28, 1.2, seg=10)
    g["Iron"].cyl(0, 0, 2.0, 0.26, 0.22, 9.0, seg=10)
    g["Brass"].cyl(0, 0, 6.0, 0.36, 0.36, 0.4, seg=10)
    g["Brass"].cyl(0, 0, 10.8, 0.4, 0.4, 0.4, seg=10)
    g["Iron"].box(0, -0.8, 11.2, 0.25, 1.8, 0.25)
    g["Brass"].box(0, -1.6, 10.2, 1.3, 1.3, 0.25)
    g["Glow"].box(0, -1.6, 11.0, 0.95, 0.95, 1.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Brass"].box(sx * 0.6, -1.6 + sy * 0.6, 11.0, 0.14, 0.14, 1.5)
    g["Iron"].cyl(0, -1.6, 11.7, 0.95, 0.2, 0.9, seg=8)
    g["LampPt"].box(0, -1.6, 11.0, 0.3, 0.3, 0.3)


def big_gear(g):
    g["Stone"].box(0, 0, 0.6, 12.0, 5.0, 1.2)
    g["StoneTrim"].box(0, 0, 1.35, 12.6, 5.6, 0.3)
    # 톱니 셋은 Snow_City 가 돌아가는 톱니로 단다. 여기는 두 기둥과 굴대만
    for x, h in ((-1.5, 6.6), (4.9, 4.2)):
        g["Iron"].box(x, 1.6, 1.5 + h / 2, 1.0, 1.0, h)
        g["Iron"].hcyl(x, 0.9, 1.5 + h, 0.55, 2.4, axis="y", seg=10)
    g["Brass"].box(1.7, 1.6, 1.5 + 0.3, 8.8, 1.4, 0.6)


def boiler_tank(g):
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].box(sx * 2.2, sy * 2.2, 1.6, 0.6, 0.6, 3.2)
    g["Iron"].box(0, 0, 3.3, 5.6, 5.6, 0.4)
    banded_cyl(g, "Copper", 0, 0, 3.5, 3.2, 10.0, every=3.3, cap=None)
    g["Copper"].cyl(0, 0, 13.5, 3.2, 1.2, 2.2, seg=16)
    g["Brass"].cyl(0, 0, 15.7, 0.9, 0.9, 0.8, seg=10)
    vent(g, 0, 0, 16.9)
    # 밸브 바퀴
    wheel_y = -3.5
    wz = 8.45   # 두 놋쇠 띠(6.5..7.1, 9.8..10.4) 사이
    g["Iron"].hcyl(0, wheel_y + 0.3, wz, 0.25, 0.9, axis="y", seg=8)
    for k in range(8):
        a = 2 * math.pi * k / 8
        g["Brass"].obox(0.9 * math.cos(a), wheel_y, wz + 0.9 * math.sin(a), 0.75, 0.25, 0.25, ry=-a + math.pi / 2)
    g["Brass"].obox(0, wheel_y, wz, 1.8, 0.2, 0.2, ry=0.4)
    g["Brass"].obox(0, wheel_y, wz, 1.8, 0.2, 0.2, ry=0.4 + math.pi / 2)
    # 사다리
    for k in range(7):
        g["Iron"].box(3.5, 0, 4.4 + k * 1.5, 0.25, 1.4, 0.2)
    for s in (-1, 1):
        g["Iron"].box(3.5, s * 0.7, 9.0, 0.25, 0.2, 10.0)
    pipe(g, [(-3.2, 0, 6.0), (-5.0, 0, 6.0), (-5.0, 0, 0.2)], 0.5, mat="Iron")


def mooring_mast(g):
    g["Stone"].box(0, 0, 1.0, 9.0, 9.0, 2.0)
    H = 38.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            # 다리. 위로 갈수록 안으로 모인다
            bx, by, tx, ty = sx * 3.4, sy * 3.4, sx * 1.8, sy * 1.8
            L_ = math.sqrt((bx - tx) ** 2 + (by - ty) ** 2 + (H - 2) ** 2)
            g["Iron"].obox((bx + tx) / 2, (by + ty) / 2, 2.0 + (H - 2) / 2, 0.6, 0.6, L_,
                           rx=math.atan2(-(ty - by), H - 2) * 1.0, ry=math.atan2(tx - bx, H - 2))
    for k in range(6):
        z = 5.0 + k * 5.8
        w = 3.4 - (3.4 - 1.8) * (z - 2.0) / (H - 2.0)
        for s in (-1, 1):
            g["IronLight"].box(0, s * w, z, 2 * w, 0.3, 0.3)
            g["IronLight"].box(s * w, 0, z, 0.3, 2 * w, 0.3)
            g["IronLight"].obox(0, s * w, z + 2.9, 2 * w * 1.25, 0.2, 0.2, ry=0.9 * s)
    g["IronLight"].box(0, 0, H + 0.3, 7.0, 7.0, 0.6)
    for sx in (-1, 1):
        g["Iron"].box(sx * 3.4, 0, H + 1.6, 0.25, 7.0, 0.25)
        g["Iron"].box(0, sx * 3.4, H + 1.6, 7.0, 0.25, 0.25)
    g["Iron"].hcyl(0, -4.0, H + 2.4, 0.5, 8.0, axis="y", seg=10)
    g["Brass"].cyl(0, -8.0, H + 1.4, 0.9, 0.9, 2.0, seg=10)
    g["Iron"].cyl(0, 0, H + 0.6, 0.4, 0.4, 6.0, seg=8)
    g["Glow"].cyl(0, 0, H + 6.6, 0.9, 0.9, 1.4, seg=10)
    g["LampPt"].box(0, 0, H + 7.3, 0.3, 0.3, 0.3)
    for k in range(18):
        g["Iron"].box(0, -1.9, 3.0 + k * 2.0, 1.2, 0.2, 0.2)


def airship(g):
    # 기구 주머니. y 로 누운 둥근 몸통을 고리 스무 개로 짓는다
    Lh, R, zc = 30.0, 10.0, 15.0
    n_ring, seg = 22, 18
    rings = []
    for i in range(n_ring + 1):
        t = i / n_ring
        y = -Lh + 2 * Lh * t
        r = R * (math.sin(math.pi * t) ** 0.72)
        rings.append((y, max(r, 0.05)))
    v = []
    for y, r in rings:
        for k in range(seg):
            a = 2 * math.pi * k / seg
            v.append((r * math.cos(a), y, zc + r * math.sin(a)))
    f = []
    for i in range(n_ring):
        for k in range(seg):
            a, b = i * seg + k, i * seg + (k + 1) % seg
            f.append((a, b, b + seg, a + seg))
    f.append(tuple(range(seg))[::-1])
    f.append(tuple(range(n_ring * seg, n_ring * seg + seg)))
    g["Canvas"].add_mesh(v, f)
    for t in (0.3, 0.5, 0.7):
        y = -Lh + 2 * Lh * t
        r = R * (math.sin(math.pi * t) ** 0.72)
        g["Brass"].hcyl(0, y, zc, r + 0.15, 0.6, axis="y", seg=seg)
    # 꼬리 날개 넷
    for a in range(4):
        ang = a * HALF_PI
        ux, uz = math.cos(ang), math.sin(ang)
        y0, y1 = Lh * 0.55, Lh * 0.95
        r0 = R * (math.sin(math.pi * 0.775) ** 0.72)
        pts = [(ux * r0 * 0.8, y0, zc + uz * r0 * 0.8), (ux * (r0 + 5.5), y1, zc + uz * (r0 + 5.5)),
               (ux * 1.0, y1 + 1.5, zc + uz * 1.0)]
        th = 0.5
        nx, nz = -uz * th / 2, ux * th / 2
        vv = [(p[0] + nx, p[1], p[2] + nz) for p in pts] + [(p[0] - nx, p[1], p[2] - nz) for p in pts]
        g["RoofMetal"].add_mesh(vv, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    # 곤돌라
    g["Timber"].box(0, 0, 2.5, 5.0, 16.0, 4.2)
    g["Brass"].box(0, 0, 4.8, 5.4, 16.4, 0.4)
    g["Brass"].box(0, 0, 0.35, 5.2, 16.2, 0.7)
    for k in range(5):
        for s in (-1, 1):
            g["Glow"].box(s * 2.55, -6.0 + k * 3.0, 2.8, 0.2, 1.6, 1.4)
    g["Timber"].obox(0, -8.6, 2.6, 5.0, 2.4, 4.0, rx=0.5)
    # 매단 줄
    for sx in (-1, 1):
        for sy in (-1, 1):
            ax, ay, az = sx * 2.2, sy * 6.5, 4.8
            bx, by, bz = sx * 4.5, sy * 10.0, zc - R * 0.9
            L_ = math.sqrt((bx - ax) ** 2 + (by - ay) ** 2 + (bz - az) ** 2)
            g["Iron"].obox((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2, 0.15, 0.15, L_,
                           rx=-math.atan2(by - ay, bz - az), ry=math.atan2(bx - ax, bz - az))
    # 뒤 추진기 둘
    for s in (-1, 1):
        px = s * 4.2
        g["Iron"].box(px * 0.75, 7.5, 2.5, 2.0, 0.4, 0.4)
        g["Brass"].hcyl(px, 8.6, 2.5, 0.5, 1.4, axis="y", seg=10)
        for k in range(3):
            a = k * 2 * math.pi / 3 + 0.3
            g["Brass"].obox(px + 1.2 * math.cos(a), 9.4, 2.5 + 1.2 * math.sin(a), 2.4, 0.2, 0.6, ry=-a)
    g["LampPt"].box(0, -7.0, 2.8, 0.3, 0.3, 0.3)


def city_gate(g):
    for s in (-1, 1):
        x = s * 10.0
        g["Stone"].box(x, 0, 9.0, 5.0, 5.0, 18.0)
        g["StoneTrim"].box(x, 0, 1.0, 6.0, 6.0, 2.0)
        g["StoneTrim"].box(x, 0, 18.4, 6.0, 6.0, 0.8)
        g["Iron"].box(x, 0, 19.4, 3.0, 3.0, 1.2)
        g["Brass"].box(x, 0, 20.9, 1.6, 1.6, 1.6)
        g["Glow"].box(x, 0, 22.2, 1.4, 1.4, 1.8)
        g["Iron"].cyl(x, 0, 23.1, 1.3, 0.2, 1.2, seg=8)
        g["LampPt"].box(x, 0, 22.2, 0.3, 0.3, 0.3)
        for k in range(3):
            g["IronLight"].box(x, -2.6, 4.0 + k * 5.0, 5.2, 0.3, 0.5)
    g["Iron"].box(0, 0, 16.0, 16.0, 2.4, 2.2)
    g["Iron"].box(0, 0, 13.6, 15.0, 1.4, 0.8)
    for k in range(9):
        x = -7.0 + k * 1.75
        g["Brass"].box(x, -1.25, 16.0, 0.35, 0.2, 0.35)
    # 톱니는 Snow_City 가 돌아가는 톱니로 단다. 들보 위 받침판과 굴대만
    g["IronLight"].box(0, 0.4, 20.0, 12.0, 0.6, 7.0)
    g["Iron"].hcyl(0, -0.3, 20.6, 0.7, 1.2, axis="y", seg=10)
    g["Iron"].box(0, -1.4, 13.6 - 1.2, 7.0, 0.3, 1.4)
    g["Brass"].box(0, -1.6, 13.6 - 1.2, 6.2, 0.1, 0.8)


# ---------------------------------------------------------------- 도는 톱니와 관 부속

TOOTH_PITCH = 1.96   # 이 간격. 세 톱니가 같아야 맞물린다
TOOTH_DEPTH = 0.9


def spoked_gear(g, teeth, t=1.0, spokes=6):
    """
    살 달린 톱니바퀴. 반지름은 이 수 × 이 간격 / 2π 로 정해 세 크기가 서로 맞물린다.
    이는 0 도(+x)에 하나가 오게 대칭으로 깎는다. 로블록스로 가면 좌우가 뒤집히는데,
    이 수가 짝수라 0 도와 180 도에 둘 다 이가 있어 이 자리가 그대로다.
    판은 x-z 평면에서 -y 를 보고, 가운데가 (0, 0, r) 이다. 바닥이 원점 아래로 가지 않게 띄운다
    """
    r = teeth * TOOTH_PITCH / (2 * math.pi)
    zc = r
    r_root = r - TOOTH_DEPTH
    r_in = r_root - max(0.9, r * 0.13)
    da = 2 * math.pi / teeth
    prof = [(-0.5, r_root), (-0.28, r_root), (-0.14, r), (0.14, r), (0.28, r_root)]
    ang = [(k + f) * da for k in range(teeth) for f, _ in prof]
    rad = [rr for k in range(teeth) for _, rr in prof]
    n = len(ang)

    def P(a, rr, y):
        return (rr * math.cos(a), y, zc + rr * math.sin(a))

    v = []
    for y in (-t / 2, t / 2):
        v += [P(a, rr, y) for a, rr in zip(ang, rad)]
        v += [P(a, r_in, y) for a in ang]
    Fo, Fi, Bo, Bi = 0, n, 2 * n, 3 * n
    f = []
    for k in range(n):
        k2 = (k + 1) % n
        f.append((Fo + k, Fo + k2, Fi + k2, Fi + k))
        f.append((Bo + k, Bi + k, Bi + k2, Bo + k2))
        f.append((Fo + k, Bo + k, Bo + k2, Fo + k2))
        f.append((Fi + k, Fi + k2, Bi + k2, Bi + k))
    g["Brass"].add_mesh(v, f)
    r_hub = max(0.8, r * 0.22)
    for j in range(spokes):
        a = 2 * math.pi * j / spokes + da / 2
        rm = (r_hub + r_in) / 2
        g["Iron"].obox(rm * math.cos(a), 0, zc + rm * math.sin(a), r_in - r_hub + 0.4, t * 0.7,
                       max(0.5, r * 0.12), ry=-a)
    g["Iron"].hcyl(0, 0, zc, r_hub, t * 1.3, axis="y", seg=16)
    g["Brass"].hcyl(0, 0, zc, r_hub * 0.5, t * 1.6, axis="y", seg=10)


def pipe_bend90(g):
    """
    도시 난방관 끝의 꺾임. 관 반지름 1.1, 굽힘 반지름 2.6.
    꺾인 자리 P = (0, 0, 4). 블렌더 -x 로 들어와(로블록스에선 +X 로 들어온다) 아래로 나간다
    """
    P, R = (0.0, 0.0, 4.0), 2.6
    bend(g, "Copper", P, (-1, 0, 0), (0, 0, -1), 1.1, R, n=12, seg=16)
    collar(g, "Brass", (R, 0, 4.0), (-1, 0, 0), 1.4, 0.45)
    collar(g, "Brass", (0, 0, 4.0 - R), (0, 0, -1), 1.4, 0.45)


def pipe_valve(g):
    """관 위에 선 밸브. 원점이 관 윗면. 몸통, 줄기, 손바퀴"""
    g["Brass"].box(0, 0, 0.15, 1.8, 2.6, 0.3)
    g["Copper"].cyl(0, 0, 0, 0.75, 0.75, 1.3, seg=14)
    g["Brass"].cyl(0, 0, 1.3, 0.9, 0.9, 0.3, seg=14)
    g["Iron"].cyl(0, 0, 1.6, 0.2, 0.2, 1.6, seg=8)
    ring(g, "Iron", 0, 0, 3.1, 1.15, 1.45, 0.3, n=20)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        g["Iron"].obox(0.65 * math.cos(a), 0.65 * math.sin(a), 3.25, 1.2, 0.2, 0.2, rz=a)
    g["Brass"].cyl(0, 0, 3.0, 0.3, 0.3, 0.5, seg=8)


def pipe_gauge(g):
    """관 위에 선 압력계. 원점이 관 윗면. 앞(-y)으로 눈금판을 본다"""
    g["Brass"].box(0, 0, 0.15, 1.4, 2.0, 0.3)
    g["Iron"].cyl(0, 0, 0.3, 0.22, 0.22, 1.3, seg=8)
    g["Brass"].hcyl(0, 0, 2.5, 1.05, 0.55, axis="y", seg=18)
    g["SnowCap"].hcyl(0, -0.3, 2.5, 0.88, 0.1, axis="y", seg=18)
    for k in range(7):
        a = math.radians(210 - k * 40)
        g["Iron"].obox(0.7 * math.cos(a), -0.37, 2.5 + 0.7 * math.sin(a), 0.22, 0.05, 0.08, ry=-a)
    g["Iron"].obox(0.18, -0.4, 2.62, 0.7, 0.06, 0.1, ry=-0.9)
    g["Core"].obox(-0.5, -0.38, 2.9, 0.18, 0.05, 0.18)


# ---------------------------------------------------------------- 내놓기

JOBS = [
    ("Steam_House_A", "HouseA", house_a, [("front", (18, -45, 18), (0, 0, 15)), ("corner", (38, -38, 30), (0, 0, 14))]),
    ("Steam_House_B", "HouseB", house_b, [("front", (8, -48, 14), (2, 0, 11)), ("corner", (44, -40, 28), (2, 0, 10))]),
    ("Steam_House_C", "HouseC", house_c, [("front", (-12, -45, 18), (0, 0, 17)), ("corner", (36, -36, 32), (0, 0, 16))]),
    ("Herzofen", "Herz", herzofen, [("front", (0, -80, 30), (0, 0, 28)), ("corner", (60, -60, 60), (0, 0, 26))]),
    ("Zapfen_Werk", "Zapf", zapfen, [("front", (10, -110, 30), (5, 0, 22)), ("corner", (-90, -85, 70), (5, 0, 20))]),
    ("Frostig_Werk", "Fros", frostig, [("front", (0, -55, 16), (0, 0, 13)), ("corner", (40, -45, 34), (0, 0, 12))]),
    ("Sel_Werk_Ruin", "Sel", sel_ruin, [("front", (0, -50, 18), (0, 0, 8)), ("corner", (34, -38, 36), (0, 0, 6))]),
    ("Figuren_HQ", "Figu", figuren, [("front", (0, -95, 28), (0, 0, 24)), ("corner", (70, -70, 55), (0, 0, 22))]),
    ("Gas_Lamp", "Lamp", gas_lamp, [("corner", (8, -10, 10), (0, -1, 7))]),
    ("Big_Gear", "Gear", big_gear, [("front", (4, -26, 9), (1, 0, 6))]),
    ("Boiler_Tank", "Boil", boiler_tank, [("corner", (16, -18, 14), (0, 0, 8))]),
    ("Mooring_Mast", "Mast", mooring_mast, [("corner", (40, -40, 34), (0, 0, 22))]),
    ("Airship", "Ship", airship, [("corner", (60, -50, 40), (0, 0, 10))]),
    ("City_Gate", "Gate", city_gate, [("front", (0, -40, 14), (0, 0, 12))]),
    ("Gear_24", "Gear24", lambda g: spoked_gear(g, 24), [("front", (0, -26, 8), (0, 0, 7.5))]),
    ("Gear_16", "Gear16", lambda g: spoked_gear(g, 16), [("front", (0, -18, 5), (0, 0, 5))]),
    ("Gear_10", "Gear10", lambda g: spoked_gear(g, 10), [("front", (0, -12, 3.2), (0, 0, 3.1))]),
    ("Pipe_Bend90", "Bend", pipe_bend90, [("corner", (-7, -10, 7), (0, 0, 2.5))]),
    ("Pipe_Valve", "Valve", pipe_valve, [("corner", (4, -5, 5), (0, 0, 2))]),
    ("Pipe_Gauge", "Gauge", pipe_gauge, [("front", (1.5, -5, 3.2), (0, 0, 2.4))]),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, renders in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        L.export_model(name, g, 1.0, renders=renders, min_objs=2, palette=PALETTE)
