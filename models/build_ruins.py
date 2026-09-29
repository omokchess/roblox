# -*- coding: utf-8 -*-
"""
build_ruins.py — 탑의 성역 재작업 모델. (2026-09-27)

컨셉과 색감은 기존 성역 그대로: 부서진 유적, 단색 회백 돌(206,202,186 ~ 풍화 118,120,112), 따뜻한 불빛 조금, 코어의 푸른 빛.
기존 파트 상자 대신 모서리를 깎은 돌 블록(cbox)으로 쌓아 큰 스케일로 다시 만든다. 배치는 tools/ruins_plan.py 에서 손으로.

치수는 스터드(배율 1). 원점은 바닥 가운데, 앞은 -y (로블록스 -Z). 블렌더 +x 는 로블록스 -X, +y 는 로블록스 +Z.
월드 각 θ(x=cos, z=sin) 는 블렌더 각 180-θ 다.

돌리는 법: blender --background --python build_ruins.py [-- 이름...]
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
from build_props import lathe, ball, extrude, annulus, frustum, cone_between  # noqa: E402
from build_steam import tube  # noqa: E402

RPAL = {
    "Stone": "#CECABA",    # 206,202,186 기존 STONE
    "Stone2": "#BAB6A8",
    "Stone3": "#A4A296",
    "Weather": "#767870",  # 118,120,112 기존 WEATHER
    "Joint": "#808078",    # 128,128,120 기존 JOINT
    "Glow": "#FFD68C",     # 255,214,140 기존 GLOW (Neon)
    "Blue": "#7ACAFF",     # 122,202,255 코어 (Neon)
    "Water": "#1E2C3A",    # 30,44,58 기존 반사지 물
    "LampPt": "#FFFFFF",
}
STONES = ("Stone", "Stone2", "Stone3")


def G(prefix):
    return L.new_groups(prefix, RPAL)


# ================================================================ 돌 블록
def _cbox_mesh(hx, hy, hz, c):
    """모서리를 c 만큼 깎은 상자. 꼭짓점 24, 면 26 (삼각형 44)"""
    c = min(c, hx * 0.45, hy * 0.45, hz * 0.45)
    V = []
    idx = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                idx[(sx, sy, sz, 0)] = len(V)
                V.append((sx * hx, sy * (hy - c), sz * (hz - c)))
                idx[(sx, sy, sz, 1)] = len(V)
                V.append((sx * (hx - c), sy * hy, sz * (hz - c)))
                idx[(sx, sy, sz, 2)] = len(V)
                V.append((sx * (hx - c), sy * (hy - c), sz * hz))
    F = []
    # 큰 면 여섯
    for ax in range(3):
        for s in (-1, 1):
            quad = []
            for a in (-1, 1):
                for b in (-1, 1):
                    k = [0, 0, 0]
                    k[ax] = s
                    o = [i for i in range(3) if i != ax]
                    k[o[0]], k[o[1]] = a, b
                    quad.append(idx[(k[0], k[1], k[2], ax)])
            F.append((quad[0], quad[1], quad[3], quad[2]))
    # 모서리 면 열둘
    for ax in range(3):   # ax 방향으로 뻗은 모서리
        o = [i for i in range(3) if i != ax]
        for a in (-1, 1):
            for b in (-1, 1):
                k0 = [0, 0, 0]
                k1 = [0, 0, 0]
                k0[ax], k1[ax] = -1, 1
                k0[o[0]] = k1[o[0]] = a
                k0[o[1]] = k1[o[1]] = b
                F.append((idx[tuple(k0) + (o[0],)], idx[tuple(k1) + (o[0],)], idx[tuple(k1) + (o[1],)],
                          idx[tuple(k0) + (o[1],)]))
    # 귀 삼각형 여덟
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                F.append((idx[(sx, sy, sz, 0)], idx[(sx, sy, sz, 1)], idx[(sx, sy, sz, 2)]))
    return V, F


def cbox(g, mat, cx, cy, cz, sx, sy, sz, c=0.35, rz=0.0, rx=0.0, ry=0.0):
    V, F = _cbox_mesh(sx / 2, sy / 2, sz / 2, c)
    m = (Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y")
         @ Matrix.Rotation(rx, 4, "X"))
    g[mat].add_mesh([tuple(m @ Vector(v)) for v in V], F)


def stone(rnd):
    return rnd.choice(STONES)


def lift_all(g, dz):
    import bmesh
    for grp in g.values():
        bmesh.ops.translate(grp.bm, vec=(0, 0, dz), verts=grp.bm.verts)


def norm_floor(g):
    """원점 밑으로 들어간 만큼 통째로 올리고 그 값을 돌려준다. 놓을 때 그만큼 다시 묻는다(Ruins_lifts.luau)"""
    mn = 0.0
    for grp in g.values():
        for v in grp.bm.verts:
            mn = min(mn, v.co.z)
    if mn < 0:
        lift_all(g, -mn + 0.01)
        return -mn + 0.01
    return 0.0


def masonry_wall(g, rnd, x0, y0, x1, y1, z0, t, prof, course=3.2, blk=(5.0, 8.0), c=0.3):
    """
    (x0,y0)→(x1,y1) 따라 돌을 엇갈려 쌓은 담. 두께 t. prof 는 [(u 0..1, 높이)] 로 무너진 윗선.
    켜마다 이음매를 반 칸 엇갈리고, 돌 크기·빛을 조금씩 달리한다
    """
    L0 = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L0, (y1 - y0) / L0
    rz = math.atan2(uy, ux)

    def height_at(u):
        for (ua, ha), (ub, hb) in zip(prof, prof[1:]):
            if ua <= u <= ub:
                return ha + (hb - ha) * (u - ua) / max(1e-6, ub - ua)
        return prof[-1][1]

    k = 0
    z = z0
    while True:
        s = (blk[0] + blk[1]) / 4 if k % 2 else 0.0
        u = -s
        while u < L0:
            bl = rnd.uniform(*blk)
            a, b = max(0.0, u), min(L0, u + bl)
            if b - a > 0.8:
                mid = (a + b) / 2
                if z + course <= z0 + height_at(mid / L0) + 0.01:
                    cx, cy = x0 + ux * mid, y0 + uy * mid
                    inset = rnd.uniform(-0.12, 0.12)
                    cbox(g, stone(rnd), cx - uy * inset, cy + ux * inset, z + course / 2, b - a - 0.08, t, course - 0.06,
                         c=c, rz=rz)
            u += bl
        z += course
        k += 1
        if z >= z0 + max(h for _, h in prof):
            break


# ================================================================ 탑
H = 560.0
BREAK = 0.42
TURNS = 4.0
CTURNS = -2.4
N_SEC = 6
STAIR_A0 = math.radians(160)   # 월드 20도(첫 참배로) 쪽에서 오른다


class Sections:
    def __init__(self, gs):
        self.gs = gs

    def at(self, z):
        k = int(z / (H / len(self.gs)))
        return self.gs[min(len(self.gs) - 1, max(0, k))]


def col_r(z):
    return 28.0 - 13.0 * z / H


def br_at(t):
    return 0.0 if t < BREAK else ((t - BREAK) / (1 - BREAK)) ** 1.15


STEPS_OUT = []   # (번호, 로블록스 x, 윗면 y, z, 폭) 탑 발치 원점. 충돌 비탈용


def tower(sec):
    STEPS_OUT.clear()
    rnd = random.Random(51774)
    TOP = 0.82 * H
    # 가운데 기둥: 8 마다 한 켜, 켜 사이 이음 고리
    z = 0.0
    while z < TOP - 0.1:
        z1 = min(TOP, z + 8.0)
        g = sec.at((z + z1) / 2)
        lathe(g, stone(rnd), 0, 0, z, [(col_r(z), 0.0), (col_r(z1), z1 - z)], 20)
        annulus(g, "Joint", (0, 0, z1), "z", col_r(z1) - 0.25, col_r(z1) + 0.12, 0.45, n=20)
        z = z1
    # 부러진 머리
    g = sec.at(TOP)
    for j in range(12):
        a = 2 * math.pi * j / 12 + rnd.uniform(0, 0.25)
        h = rnd.uniform(4, 22)
        r = col_r(TOP) - 2.0
        cbox(g, stone(rnd), r * math.cos(a), r * math.sin(a), TOP + h / 2 - 1, 5.0, 5.5, h, c=0.6, rz=a,
             rx=rnd.uniform(-0.12, 0.12))
    g["Weather"].cyl(0, 0, TOP - 1, col_r(TOP) - 3, col_r(TOP) - 5, 2.0, seg=14)
    # 기둥에 따뜻한 빛 새는 틈 몇 (기존 GLOW)
    for zz, a in ((40, 0.3), (120, 2.1), (200, 4.0), (280, 5.5)):
        r = col_r(zz) + 0.05
        sec.at(zz)["Glow"].obox(r * math.cos(a), r * math.sin(a), zz, 0.4, 1.2, 7.0, rz=a)

    # 나선계단
    rise = 2.5
    n = int(H * 0.7 / rise)
    per = TURNS * 2 * math.pi / (H / rise)
    for i in range(n):
        zt = (i + 1) * rise
        t = zt / H
        br = br_at(t)
        if rnd.random() < br * 0.9:
            continue
        a = STAIR_A0 + (i + 0.5) * per
        r_in = col_r(zt) - 1.0
        r_out = (36.0 - 14.0 * t) + (14.0 - 4.0 * t) / 2
        rc = (r_in + r_out) / 2
        g = sec.at(zt)
        jx, jz, jr = 0.0, 0.0, 0.0
        if br > 0.04:
            jx, jz, jr = rnd.uniform(-1, 1) * br * 6, rnd.uniform(-1.5, 0.5) * br * 5, rnd.uniform(-0.3, 0.3) * br
        cx, cy = rc * math.cos(a) + jx, rc * math.sin(a) + jx * 0.5
        cbox(g, stone(rnd), cx, cy, zt - 1.1 + jz, r_out - r_in, per * r_out * 1.1, 2.2, c=0.3, rz=a, rx=jr)
        STEPS_OUT.append((i, -cx, zt + jz, cy, r_out - r_in))
        if i % 4 == 0 and zt > 6 and br < 0.2:   # 계단 밑 받침돌
            rb = r_in + 3.0
            cbox(g, "Stone3", rb * math.cos(a), rb * math.sin(a), zt - 4.4, 6.0, 3.0, 4.4, c=0.3, rz=a)
        if i % 2 == 0 and br < 0.35:   # 바깥 난간 돌
            rp = r_out - 0.7
            cbox(g, stone(rnd), rp * math.cos(a) + jx, rp * math.sin(a), zt + 1.3 + jz, 1.4, per * r_out * 2.1, 2.6, c=0.25,
                 rz=a)

    # 갈빗대 다섯: 돌 덩이를 나선 따라 쌓는다
    for rb in range(5):
        a0 = STAIR_A0 + 2 * math.pi * rb / 5 + math.pi / 5
        t = 0.0
        # 발치 큰 받침
        r = 96.0
        g = sec.at(4)
        cbox(g, "Stone3", r * math.cos(a0), r * math.sin(a0), 4.0, 18.0, 20.0, 8.0, c=0.8, rz=a0)
        while t < 1.0:
            a = a0 + t * CTURNS * 2 * math.pi
            r = 96.0 - 46.0 * t
            z = t * H + 11.0
            br = br_at(t)
            # 한 덩이가 덮는 호 길이 약 8
            dl = 8.0
            dt = dl / math.hypot(abs(CTURNS) * 2 * math.pi * r, H)
            if rnd.random() >= br * 0.93:
                lx = ly = lz = rr = rx = 0.0
                if br > 0.04:
                    d = br * 26
                    lx, ly, lz = rnd.uniform(-d, d), rnd.uniform(-d, d), rnd.uniform(-d * 0.6, d * 0.6)
                    rr, rx = rnd.uniform(-br, br) * 0.8, rnd.uniform(-br, br) * 0.8
                g = sec.at(z)
                # 덩이는 나선 접선 쪽으로 눕는다 (rz 는 반지름 방향 + 90도)
                # 나선 기울기만큼 눕혀 덩이끼리 띠로 잇는다 (세우면 톱니처럼 끊겨 보인다)
                slope = math.atan(H / (CTURNS * 2 * math.pi * r))
                cbox(g, stone(rnd), r * math.cos(a) + lx, r * math.sin(a) + ly, z + lz, 15.0, 14.0, 17.0, c=1.1,
                     rz=a + rr, rx=slope + rx)
                # 바깥 면 이음 줄
                if rnd.random() < 0.5 and br < 0.3:
                    ro = r + 7.55
                    g["Joint"].obox(ro * math.cos(a), ro * math.sin(a), z + 7.0, 0.2, 9.0, 0.5, rz=a)
            t += dt
    # 갈빗대 가로 묶음 (돌 들보)
    for t in (0.1, 0.2, 0.3, 0.4, 0.5):
        for rb in range(5):
            a0 = STAIR_A0 + 2 * math.pi * rb / 5 + math.pi / 5 + t * CTURNS * 2 * math.pi
            a1 = a0 + 2 * math.pi / 5
            r = 96.0 - 46.0 * t
            p0 = Vector((r * math.cos(a0), r * math.sin(a0), t * H + 7))
            p1 = Vector((r * math.cos(a1), r * math.sin(a1), t * H + 7))
            if t >= 0.5 and rb % 2:
                continue
            g = sec.at(t * H)
            d = p1 - p0
            nb = 4
            for k in range(nb):
                q = p0 + d * ((k + 0.5) / nb)
                cbox(g, stone(rnd), q.x, q.y, q.z, d.length / nb - 0.2, 6.0, 6.0, c=0.5,
                     rz=math.atan2(d.y, d.x))


def tower_podium(g):
    """
    탑 기단. 세 켜 둥근 단(r 130/112/96), 가장자리는 큰 돌을 두르되 군데군데 빠지고 무너졌다.
    네 참배로(월드 20, 110, 200, 290도) 쪽에 넓은 계단(폭 30). 윗면 높이 24
    """
    rnd = random.Random(7)
    tiers = [(130.0, 0.0, 8.0), (112.0, 8.0, 16.0), (96.0, 16.0, 24.0)]
    stair_b = [math.radians(180 - w) for w in (20, 110, 200, 290)]
    for r, z0, z1 in tiers:
        g["Stone2"].cyl(0, 0, z0, r - 1.5, r - 1.5, z1 - z0 - 0.3, seg=64)
        g["Stone"].cyl(0, 0, z1 - 0.6, r - 2.0, r - 2.0, 0.6, seg=64)
        # 가장자리 큰 돌. 계단 자리와 무너진 곳은 빈다
        n = int(2 * math.pi * r / 9.0)
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            if any(abs((a - b + math.pi) % (2 * math.pi) - math.pi) < math.radians(9) for b in stair_b):
                continue
            if rnd.random() < 0.12:
                # 굴러 떨어진 돌: 단 아래 땅에
                cbox(g, stone(rnd), (r + 6) * math.cos(a), (r + 6) * math.sin(a), 2.5, 8.4, 4.0, 3.6, c=0.4,
                     rz=a + rnd.uniform(-0.6, 0.6), rx=rnd.uniform(-0.3, 0.3))
                continue
            h = (z1 - z0) - rnd.uniform(0, 0.6)
            cbox(g, stone(rnd), (r - 2.2) * math.cos(a), (r - 2.2) * math.sin(a), z0 + h / 2, 4.6, 2 * math.pi * r / n - 0.25,
                 h, c=0.45, rz=a)
    for b in stair_b:
        ca, sa = math.cos(b), math.sin(b)
        nst = 30
        for k in range(nst):
            zt = 24.0 * (k + 1) / nst
            r0 = 136.0 - 1.35 * (k + 1)
            cbox(g, stone(rnd), (r0 + 0.7) * ca, (r0 + 0.7) * sa, zt / 2, 1.45, 30.0 - (k % 3) * 0.3, zt, c=0.2, rz=b)
        for s in (-1, 1):   # 옆 난간벽. 끝이 부서졌다
            ox, oy = -sa * s * 16.5, ca * s * 16.5
            for k in range(0, nst, 2):
                zt = 24.0 * (k + 1) / nst
                if rnd.random() < 0.15:
                    continue
                r0 = 136.0 - 1.35 * (k + 1)
                cbox(g, stone(rnd), r0 * ca + ox, r0 * sa + oy, (zt + 3) / 2, 2.8, 3.0, zt + 3, c=0.4, rz=b)


# ================================================================ 쌓기 도우미
def pier(g, rnd, cx, cy, z0, w, d, h, course=4.0, top_prof=None, c=0.4, rz=0.0):
    """네모 기둥(탑문·아치 기둥). 켜마다 돌 둘을 엇갈려 쌓는다. top_prof 가 있으면 (0..1 → 높이) 로 무너진 윗선"""
    ca, sa = math.cos(rz), math.sin(rz)

    def P(u, v):
        return cx + u * ca - v * sa, cy + u * sa + v * ca
    k = 0
    z = z0
    while z < z0 + h - 0.01:
        ch = min(course, z0 + h - z)
        if k % 2 == 0:
            parts = [(-w / 4, w / 2, d), (w / 4, w / 2, d)]
        else:
            parts = [(-w * 0.3, w * 0.4, d), (w * 0.2, w * 0.6, d)]
        for (u, bw, bd) in parts:
            top = z + ch
            if top_prof is not None:
                lim = z0 + top_prof((u + w / 2) / w)
                if z >= lim:
                    continue
                ch2 = min(ch, lim - z)
            else:
                ch2 = ch
            if ch2 < 0.6:
                continue
            x, y = P(u, rnd.uniform(-0.1, 0.1))
            cbox(g, stone(rnd), x, y, z + ch2 / 2, bw - 0.1, bd, ch2 - 0.06, c=c, rz=rz)
        z += ch
        k += 1


def drum_column(g, rnd, x, y, z0, r, n_drum, dh, jag=False):
    """주초 위에 북 모양 토막을 쌓은 둥근 기둥. 토막 사이 이음. jag 면 맨 위가 부러진 들쭉날쭉"""
    cbox(g, "Stone3", x, y, z0 + 1.5, r * 2.9, r * 2.9, 3.0, c=0.5)
    lathe(g, "Stone2", x, y, z0 + 3.0, [(r * 1.3, 0.0), (r * 1.32, 0.8), (r * 1.1, 1.6), (r * 1.05, 2.0)], 16)
    z = z0 + 5.0
    for k in range(n_drum):
        rr = r * (1.0 - 0.012 * k)
        lathe(g, stone(rnd), x, y, z, [(rr, 0.0), (rr * 0.99, dh - 0.1)], 16)
        annulus(g, "Joint", (x, y, z + dh - 0.05), "z", rr - 0.2, rr + 0.06, 0.3, n=16)
        z += dh
    if jag:
        for j in range(6):
            a = 2 * math.pi * j / 6 + rnd.uniform(0, 0.5)
            hh = rnd.uniform(0.6, 2.6)
            cbox(g, stone(rnd), (r - 1.0) * math.cos(a) + x, (r - 1.0) * math.sin(a) + y, z + hh / 2 - 0.3, 2.0, 2.2, hh, c=0.3,
                 rz=a, rx=rnd.uniform(-0.2, 0.2))
        g["Weather"].cyl(x, y, z - 0.2, r - 0.4, r - 0.6, 0.3, seg=12)
    return z


def capital(g, rnd, x, y, z, r):
    lathe(g, "Stone2", x, y, z, [(r * 0.98, 0.0), (r * 1.2, 1.0), (r * 1.45, 2.2)], 16)
    cbox(g, stone(rnd), x, y, z + 3.4, r * 3.0, r * 3.0, 2.4, c=0.4)
    return z + 4.6


def arch(g, rnd, cx, cy, zs, R, t, depth, rz=0.0, keep=(0.0, 1.0)):
    """반원 아치. 쐐기돌을 둘러 세운다. keep 은 남은 구간(0 왼쪽 ~ 1 오른쪽)"""
    n = 13
    ca, sa = math.cos(rz), math.sin(rz)
    for k in range(n):
        u = (k + 0.5) / n
        if not (keep[0] <= u <= keep[1]):
            continue
        a = math.pi * (1 - u)
        rr = R + t / 2
        lx, lz = rr * math.cos(a), rr * math.sin(a)
        x, y = cx + lx * ca, cy + lx * sa
        # 쐐기돌은 반지름 방향으로 선다. 로컬 x 가 아치 접선, z 가 반지름
        m_ry = -(a - math.pi / 2)
        cbox(g, stone(rnd), x, y, zs + lz, math.pi * rr / n * 0.97, depth, t, c=0.3, rz=rz, ry=m_ry)


# ================================================================ 열주 기둥, 인방
COLR = 3.6


def col_big(g):
    """열주 기둥(높이 약 46). 네모 주초, 둥근 받침, 북 토막 다섯, 나팔 주두와 네모 판"""
    rnd = random.Random(101)
    z = drum_column(g, rnd, 0, 0, 0, COLR, 5, 7.2)
    capital(g, rnd, 0, 0, z, COLR)


def col_big_b(g):
    rnd = random.Random(102)
    drum_column(g, rnd, 0, 0, 0, COLR, 3, 7.2, jag=True)


def col_big_c(g):
    rnd = random.Random(103)
    drum_column(g, rnd, 0, 0, 0, COLR, 1, 5.5, jag=True)


def col_drums(g):
    """쓰러진 기둥. 누운 북 토막 넷이 굴러 흩어지고 주두가 모로 누웠다"""
    rnd = random.Random(104)
    for (x, y, rz) in ((-9, 0.5, 0.1), (-1.5, -1.0, -0.25), (6.5, 1.5, 0.6), (14, -2.0, 1.2)):
        g[stone(rnd)].hcyl(x, y, COLR + 0.05, COLR, 7.0, axis="x", seg=16, rz=rz)
    cbox(g, "Stone2", -18.0, 3.0, 5.4, 2.4, 10.8, 10.8, c=0.4, rz=0.35, rx=0.05)
    for k in range(7):
        cbox(g, stone(rnd), rnd.uniform(-16, 16), rnd.uniform(-7, 7), 0.8, rnd.uniform(1.5, 3.5), rnd.uniform(1.5, 3), 1.6,
             c=0.3, rz=rnd.uniform(0, 3))


def lintel_big(g):
    """인방. 두 기둥 머리에 걸치는 돌보(길이 30). 가운데 띠와 아래 턱"""
    rnd = random.Random(105)
    for k, x in enumerate((-10.0, 0.0, 10.0)):
        cbox(g, stone(rnd), x, 0, 3.2, 9.9, 7.0, 6.4, c=0.45)
    cbox(g, "Stone2", 0, 0, 6.8, 30.6, 7.6, 0.9, c=0.25)
    g["Joint"].box(0, -3.52, 2.6, 29.5, 0.1, 0.4)


# ================================================================ 무너진 문
def gate_a(g):
    """무너진 문 A. 두 탑문(높이 70, 넓은 밑)과 가로 들보가 남았다. 문간 폭 28"""
    rnd = random.Random(201)
    for sx in (-1, 1):
        cx = sx * 24.0
        for k in range(14):   # 켜마다 조금 좁아진다
            z = k * 5.0
            w = 20.0 - k * 0.3
            d = 16.0 - k * 0.22
            pier(g, rnd, cx, 0, z, w, d, 5.0, course=5.0)
        cbox(g, "Stone2", cx, 0, 71.0, 17.5, 14.0, 2.0, c=0.4)
    for x in (-18.0, -6.0, 6.0, 18.0):
        cbox(g, stone(rnd), x, 0, 64.0, 11.9, 12.0, 10.0, c=0.6)
    cbox(g, "Stone2", 0, 0, 69.6, 50.0, 13.0, 1.4, c=0.3)
    for k in range(8):
        cbox(g, stone(rnd), rnd.uniform(-30, 30), rnd.uniform(-14, 14), 1.0, rnd.uniform(2, 4), rnd.uniform(2, 4), 2.0,
             c=0.3, rz=rnd.uniform(0, 3))


def gate_b(g):
    """무너진 문 B. 왼 탑문은 서 있고 오른 탑문은 반에서 부러졌다. 들보 돌은 문간과 오른쪽 땅에 떨어졌다"""
    rnd = random.Random(202)
    for k in range(14):
        pier(g, rnd, -24.0, 0, k * 5.0, 20.0 - k * 0.3, 16.0 - k * 0.22, 5.0, course=5.0)
    cbox(g, "Stone2", -24.0, 0, 71.0, 17.5, 14.0, 2.0, c=0.4)
    for k in range(7):
        prof = (lambda u, k=k: 5.0 if k < 6 else 5.0 * (1.0 - u * 0.8))
        pier(g, rnd, 24.0, 0, k * 5.0, 20.0 - k * 0.3, 16.0 - k * 0.22, 5.0, course=5.0, top_prof=prof)
    # 떨어진 들보 돌
    cbox(g, stone(rnd), -4.0, 2.0, 6.0, 11.9, 12.0, 10.0, c=0.6, rz=0.3, rx=0.35)
    cbox(g, stone(rnd), 8.0, -9.0, 5.0, 10.0, 11.9, 12.0, c=0.6, rz=1.0, ry=0.2)
    cbox(g, stone(rnd), 40.0, 6.0, 5.4, 12.0, 10.0, 11.0, c=0.6, rz=-0.4, rx=-0.3)
    cbox(g, stone(rnd), 30.0, -14.0, 4.6, 9.0, 12.0, 10.0, c=0.6, rz=0.8)
    for k in range(10):
        cbox(g, stone(rnd), rnd.uniform(-20, 46), rnd.uniform(-16, 16), 1.0, rnd.uniform(2, 5), rnd.uniform(2, 4), 2.0,
             c=0.3, rz=rnd.uniform(0, 3))


# ================================================================ 회랑 (순례 고리)
def arcade_bay(g, rnd, broken=0):
    """
    회랑 한 칸(폭 24). 칸마다 **왼쪽(블렌더 -x) 기둥 하나만** 갖고, 아치 오른쪽 끝은 이웃 칸 기둥에 얹힌다.
    이어 놓으면 기둥이 겹치지 않는다. 줄 끝은 Arcade_Pier 로 막는다.
    broken 0 멀쩡, 1 아치 무너짐(기둥은 섬), 2 기둥 밑동만
    """
    h = 26.0 if broken < 2 else 7.0 + rnd.uniform(0, 4)
    pier(g, rnd, -12.0, 0, 0, 6.0, 7.0, h, course=3.25)
    if broken < 2:
        cbox(g, "Stone2", -12.0, 0, 26.6, 7.4, 8.0, 1.2, c=0.3)
    if broken == 0:
        arch(g, rnd, 0, 0, 27.2, 9.0, 3.0, 6.6)
        # 아치 위 벽과 처마. 칸 경계(±12)까지만 채워 이웃 칸과 포개지지 않게
        for sx in (-1, 1):
            cbox(g, stone(rnd), sx * 7.5, 0, 33.0, 8.9, 6.4, 11.0, c=0.4)
        cbox(g, stone(rnd), 0, 0, 38.6, 23.9, 6.6, 3.2, c=0.4)
        cbox(g, "Stone2", 0, 0, 40.8, 23.9, 7.6, 1.2, c=0.3)
    elif broken == 1:
        arch(g, rnd, 0, 0, 27.2, 9.0, 3.0, 6.6, keep=(0.0, 0.38))
        for k in range(6):
            cbox(g, stone(rnd), rnd.uniform(-4, 10), rnd.uniform(-8, 8), 1.6, 4.4, 6.0, 3.0, c=0.3, rz=rnd.uniform(0, 3),
                 rx=rnd.uniform(-0.4, 0.4))
    else:
        for k in range(8):
            cbox(g, stone(rnd), rnd.uniform(-10, 10), rnd.uniform(-9, 9), 1.4, rnd.uniform(3, 6), rnd.uniform(3, 6), 2.8,
                 c=0.3, rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))
    for x in (-8.0, 0.0, 8.0):
        cbox(g, stone(rnd), x, 0, 0.35, 7.9, 10.0, 0.7, c=0.15)


def arcade_pier(g):
    """회랑 줄 끝 기둥"""
    rnd = random.Random(304)
    pier(g, rnd, 0, 0, 0, 6.0, 7.0, 26.0, course=3.25)
    cbox(g, "Stone2", 0, 0, 26.6, 7.4, 8.0, 1.2, c=0.3)


def arcade_a(g):
    arcade_bay(g, random.Random(301), 0)


def arcade_b(g):
    arcade_bay(g, random.Random(302), 1)


def arcade_c(g):
    arcade_bay(g, random.Random(303), 2)


# ================================================================ 부속 신전
def shrine_pavilion(g):
    """
    신전(열린 정자). 64x48 기단 위 기둥 열둘. 앞 여섯은 들보와 박공 지붕을 이고 서 있고,
    뒤쪽 지붕은 무너져 기단 뒤 땅으로 쏟아졌다. 앞(-y)에 넓은 계단
    """
    rnd = random.Random(401)
    W, D, Hp = 64.0, 48.0, 5.0
    for (x0, y0, x1, y1) in ((-W / 2, -D / 2, W / 2, -D / 2), (W / 2, -D / 2, W / 2, D / 2), (W / 2, D / 2, -W / 2, D / 2),
                             (-W / 2, D / 2, -W / 2, -D / 2)):
        masonry_wall(g, rnd, x0, y0, x1, y1, 0.0, 2.6, [(0, Hp), (1, Hp)], course=2.5, blk=(4.0, 7.0))
    g["Stone2"].box(0, 0, Hp / 2, W - 2.4, D - 2.4, Hp - 0.2)
    for k in range(6):   # 앞 계단
        cbox(g, stone(rnd), 0, -D / 2 - 1.2 - k * 2.2, (Hp - k * 0.83) / 2, 30.0, 2.3, Hp - k * 0.83, c=0.2)
    xs = [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0]
    for x in xs:   # 앞줄: 온전
        z = drum_column(g, rnd, x, -16.0, Hp, 2.6, 4, 6.5)
        capital(g, rnd, x, -16.0, z, 2.6)
    for i, x in enumerate(xs):   # 뒷줄: 부러짐
        drum_column(g, rnd, x, 16.0, Hp, 2.6, (1, 3, 2, 1, 3, 2)[i], 6.5, jag=True)
    zt = Hp + 5 + 4 * 6.5 + 4.6
    for x in (-20.0, 0.0, 20.0):   # 앞 들보
        cbox(g, stone(rnd), x, -16.0, zt + 2.5, 19.9, 7.0, 5.0, c=0.4)
    # 박공(앞 반쪽만 선다)
    extrude(g, "Stone2", [(-32.0, zt + 5.0), (32.0, zt + 5.0), (0.0, zt + 17.0)], -19.5, -12.5)
    extrude(g, "Stone", [(-33.5, zt + 4.6), (33.5, zt + 4.6), (0.0, zt + 17.9)], -20.2, -19.4)
    cbox(g, "Stone3", 0, -8.0, zt + 11.0, 36.0, 16.0, 1.6, c=0.3, rx=-0.05, ry=0.33)
    # 무너진 뒤 지붕 판과 들보
    cbox(g, stone(rnd), -14.0, 30.0, 3.0, 22.0, 14.0, 2.4, c=0.3, rz=0.2, rx=0.25)
    cbox(g, stone(rnd), 12.0, 31.0, 2.6, 24.0, 12.0, 2.4, c=0.3, rz=-0.3, rx=-0.2)
    cbox(g, stone(rnd), 2.0, 22.0, Hp + 3.0, 20.0, 7.0, 5.0, c=0.4, rz=0.5, ry=0.35)
    for k in range(10):
        cbox(g, stone(rnd), rnd.uniform(-30, 30), rnd.uniform(20, 36), 1.0, rnd.uniform(2, 4.5), rnd.uniform(2, 4), 2.0,
             c=0.3, rz=rnd.uniform(0, 3))


def shrine_tower(g):
    """작은 탑. 26x26 네모 탑(높이 약 80), 켜마다 이음, 층마다 아치 창, 앞 문, 꼭대기 한쪽이 무너졌다"""
    rnd = random.Random(402)
    Wd = 26.0
    prof_hi = lambda u: 80.0 - 26.0 * max(0.0, u - 0.45) * 1.8  # noqa: E731
    for (x0, y0, x1, y1, pf) in ((-Wd / 2, -Wd / 2, Wd / 2, -Wd / 2, [(0, 80), (0.5, 80), (1, 64)]),
                                 (Wd / 2, -Wd / 2, Wd / 2, Wd / 2, [(0, 64), (0.6, 52), (1, 58)]),
                                 (Wd / 2, Wd / 2, -Wd / 2, Wd / 2, [(0, 58), (1, 74)]),
                                 (-Wd / 2, Wd / 2, -Wd / 2, -Wd / 2, [(0, 74), (1, 80)])):
        masonry_wall(g, rnd, x0, y0, x1, y1, 0.0, 3.2, pf, course=4.0, blk=(4.5, 8.0), c=0.45)
    # 창과 문(어두운 구멍 판을 벽 바로 앞에)
    for z in (22.0, 42.0, 60.0):
        for (x, y, rz) in ((0, -Wd / 2 - 1.65, 0.0), (Wd / 2 + 1.65, 0, math.pi / 2), (0, Wd / 2 + 1.65, 0.0)):
            g["Weather"].obox(x, y, z, 5.0, 0.1, 9.0, rz=rz)
            arch(g, rnd, x, y, z + 4.5, 2.6, 1.2, 0.8, rz=rz)
    g["Weather"].box(0, -Wd / 2 - 1.65, 7.0, 8.0, 0.1, 14.0)
    arch(g, rnd, 0, -Wd / 2 - 1.7, 14.0, 4.0, 1.6, 1.0)
    for k in range(3):
        cbox(g, stone(rnd), 0, -Wd / 2 - 3.0 - k * 2.0, (2.4 - k * 0.8) / 2, 12.0, 2.1, 2.4 - k * 0.8, c=0.2)
    for sx in (-1, 1):   # 귀 버팀
        for sy in (-1, 1):
            pier(g, rnd, sx * (Wd / 2 + 1.0), sy * (Wd / 2 + 1.0), 0, 5.0, 5.0, 18.0 + 6 * (sx * sy > 0), course=3.0)
    for k in range(12):
        cbox(g, stone(rnd), rnd.uniform(10, 24), rnd.uniform(-4, 22), 1.2, rnd.uniform(2, 5), rnd.uniform(2, 5), 2.4, c=0.3,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))


# ================================================================ 계단 대지
def terrace(g, n_tier, base, seed):
    """계단 대지. 네모 단을 n_tier 켜 쌓고(켜 높이 5, 켜마다 16 씩 좁힘), 앞(-y)에 넓은 계단, 꼭대기에 제단과 부러진 비석 넷"""
    rnd = random.Random(seed)
    for k in range(n_tier):
        w = base - 16.0 * k
        z0, z1 = 5.0 * k, 5.0 * (k + 1)
        g["Stone2"].box(0, 0, (z0 + z1) / 2, w - 3, w - 3, z1 - z0 - 0.1)
        for (x0, y0, x1, y1) in ((-w / 2, -w / 2, w / 2, -w / 2), (w / 2, -w / 2, w / 2, w / 2), (w / 2, w / 2, -w / 2, w / 2),
                                 (-w / 2, w / 2, -w / 2, -w / 2)):
            prof = [(0, 5.0), (1, 5.0)]
            if rnd.random() < 0.5:   # 한 변 가운데가 무너진 켜
                a = rnd.uniform(0.2, 0.7)
                prof = [(0, 5.0), (a, 5.0), (a + 0.04, 2.5), (a + 0.16, 2.5), (a + 0.2, 5.0), (1, 5.0)]
            masonry_wall(g, rnd, x0, y0, x1, y1, z0, 3.0, prof, course=2.5, blk=(5.0, 9.0), c=0.35)
    top = 5.0 * n_tier
    nst = int(top / 0.8)
    for k in range(nst):   # 앞 계단 (폭 26)
        zt = top * (k + 1) / nst
        wtop = base - 16.0 * (n_tier - 1)
        run = base / 2 + 6.0 - wtop / 2
        y = -(base / 2 + 6.0) + (k + 1) * run / nst
        cbox(g, stone(rnd), 0, y - run / nst / 2, zt / 2, 26.0, run / nst + 0.05, zt, c=0.2)
    # 꼭대기 제단과 비석 밑동
    cbox(g, "Stone3", 0, 0, top + 1.5, 16.0, 10.0, 3.0, c=0.4)
    cbox(g, "Stone", 0, 0, top + 4.0, 12.0, 7.0, 2.0, c=0.3)
    lathe(g, "Weather", 0, 0, top + 5.0, [(2.4, 0.0), (3.2, 1.0), (3.4, 1.4)], 12)
    cone_between(g, "Glow", (0, 0, top + 5.8), (0, 0, top + 9.0), 1.8, 0.1, seg=8)
    g["LampPt"].box(0, 0, top + 8.0, 0.1, 0.1, 0.1)
    wtop = base - 16.0 * (n_tier - 1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = rnd.uniform(6, 18)
            cbox(g, stone(rnd), sx * (wtop / 2 - 6), sy * (wtop / 2 - 6), top + h / 2, 4.0, 4.0, h, c=0.4,
                 rx=rnd.uniform(-0.1, 0.1))


# ================================================================ 반사지
def pool(g, R):
    """검은 반사지. 여덟모 돌 테(두 켜) 안에 물. 테 한 곳이 무너져 돌이 물에 빠졌다"""
    rnd = random.Random(int(R))
    n = 8
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        x0, y0 = R * math.cos(a0), R * math.sin(a0)
        x1, y1 = R * math.cos(a1), R * math.sin(a1)
        prof = [(0, 3.2), (1, 3.2)] if k != 3 else [(0, 3.2), (0.3, 3.2), (0.35, 1.2), (0.7, 1.2), (0.75, 3.2), (1, 3.2)]
        masonry_wall(g, rnd, x0, y0, x1, y1, 0.0, 3.4, prof, course=1.6, blk=(4.0, 7.0), c=0.3)
    g["Water"].cyl(0, 0, 0.0, R - 1.2, R - 1.2, 2.2, seg=8)
    for j in range(4):
        a = 2 * math.pi * 3.5 / n + rnd.uniform(-0.2, 0.2)
        rr = R - 4 - j * 2.5
        cbox(g, stone(rnd), rr * math.cos(a), rr * math.sin(a), 2.0, 3.5, 4.0, 2.2, c=0.3, rz=rnd.uniform(0, 3), rx=0.3)


# ================================================================ 거상
def colossus(g):
    """부러진 거상. 26x26 받침(높이 14) 위에 두 발과 옷자락 아랫도리만 남았다(허리에서 부러짐)"""
    rnd = random.Random(501)
    for k in range(4):
        pier(g, rnd, 0, 0, k * 3.5, 26.0 - k * 0.6, 26.0 - k * 0.6, 3.5, course=3.5)
    cbox(g, "Stone2", 0, 0, 14.6, 25.0, 25.0, 1.2, c=0.3)
    z0 = 15.2
    lathe(g, "Stone", 0, 1.0, z0, [(10.5, 0.0), (10.0, 3.0), (8.8, 12.0), (7.6, 20.0)], 20)
    for k in range(14):   # 옷 주름
        a = 2 * math.pi * k / 14
        g["Stone2"].obox(9.2 * math.cos(a), 1.0 + 9.2 * math.sin(a), z0 + 9.0, 1.4, 1.6, 17.0, rz=a, rx=0.05)
    for sx in (-1, 1):   # 발
        ellipsoid(g, "Stone", sx * 4.0, -9.5, z0 + 1.2, 2.6, 4.2, 1.6)
    for j in range(8):   # 부러진 허리
        a = 2 * math.pi * j / 8 + rnd.uniform(0, 0.4)
        hh = rnd.uniform(1.0, 4.0)
        cbox(g, stone(rnd), 6.5 * math.cos(a), 1.0 + 6.5 * math.sin(a), z0 + 20 + hh / 2 - 0.5, 3.4, 3.8, hh, c=0.4, rz=a)
    g["Weather"].cyl(0, 1.0, z0 + 19.6, 7.0, 6.6, 0.6, seg=16)


def ellipsoid(g, mat, cx, cy, cz, rx, ry, rz, seg=12, rings=7):
    v = [(cx, cy, cz - rz)]
    for i in range(1, rings):
        t = math.pi * i / rings - math.pi / 2
        for k in range(seg):
            a = 2 * math.pi * k / seg
            v.append((cx + rx * math.cos(t) * math.cos(a), cy + ry * math.cos(t) * math.sin(a), cz + rz * math.sin(t)))
    v.append((cx, cy, cz + rz))
    top = len(v) - 1
    f = [(0, 1 + (k + 1) % seg, 1 + k) for k in range(seg)]
    for i in range(rings - 2):
        b0, b1 = 1 + i * seg, 1 + (i + 1) * seg
        for k in range(seg):
            k1 = (k + 1) % seg
            f.append((b0 + k, b0 + k1, b1 + k1, b1 + k))
    b = 1 + (rings - 2) * seg
    f += [(b + k, b + (k + 1) % seg, top) for k in range(seg)]
    g[mat].add_mesh(v, f)


def colossus_head(g):
    """거상 머리. 모로 누워 땅에 반쯤 박혔다. 이마 띠 관, 굵은 코와 눈두덩, 닫힌 입. 높이 약 14"""
    ellipsoid(g, "Stone", 0, 0, 7.0, 8.0, 9.5, 8.5, seg=14, rings=8)
    ellipsoid(g, "Stone2", 0, -8.6, 6.0, 1.8, 2.4, 3.2, seg=10, rings=6)      # 코
    for sx in (-1, 1):
        ellipsoid(g, "Stone3", sx * 3.2, -7.8, 9.2, 2.4, 1.2, 1.0, seg=10, rings=5)   # 눈두덩
        ellipsoid(g, "Weather", sx * 3.2, -8.2, 8.0, 1.4, 0.6, 0.6, seg=8, rings=4)   # 감은 눈
    ellipsoid(g, "Stone3", 0, -7.9, 3.0, 3.0, 1.0, 0.8, seg=10, rings=4)           # 입
    annulus(g, "Stone2", (0, 0.6, 11.6), "z", 7.2, 8.4, 2.4, n=16)                    # 관
    for k in range(8):
        a = 2 * math.pi * k / 8
        cbox(g, "Stone2", 7.8 * math.cos(a), 0.6 + 7.8 * math.sin(a), 14.0, 1.8, 1.8, 3.2, c=0.3, rz=a)


def colossus_hand(g):
    """거상 손. 손바닥을 위로 하고 땅에 떨어졌다. 손가락 넷과 엄지, 손목 부러진 면"""
    rnd = random.Random(503)
    cbox(g, "Stone", 0, 0, 2.6, 12.0, 11.0, 5.2, c=1.6)
    for k in range(4):
        x = -4.2 + k * 2.8
        tube(g, "Stone", (x, -5.0, 3.0), (x, -12.0 - (k % 2), 4.2), 1.3, seg=10)
        ball(g, "Stone", x, -12.0 - (k % 2), 4.2, 1.3, seg=10)
    tube(g, "Stone", (6.5, -1.0, 2.8), (10.0, -5.5, 4.6), 1.5, seg=10)
    ball(g, "Stone", 10.0, -5.5, 4.6, 1.5, seg=10)
    cbox(g, "Stone2", 0, 7.5, 2.6, 9.0, 4.0, 4.8, c=0.8)
    g["Weather"].box(0, 9.55, 2.6, 7.0, 0.1, 3.6)


# ================================================================ 비석, 제단, 화로, 빛 기둥 받침
def stele_big(g):
    """큰 비석(높이 32). 받침 위 넓은 판, 앞뒤에 새긴 칸 띠, 머리가 비스듬히 깨졌다"""
    rnd = random.Random(601)
    cbox(g, "Stone3", 0, 0, 1.5, 16.0, 7.0, 3.0, c=0.5)
    extrude(g, "Stone", [(-6.0, 3.0), (6.0, 3.0), (6.0, 28.0), (1.5, 32.0), (-6.0, 30.0)], -1.6, 1.6)
    for k in range(6):
        z = 7.0 + k * 3.6
        for sy in (-1, 1):
            g["Stone2"].box(0, sy * 1.62, z, 9.0, 0.06, 2.2)
    for j in range(3):
        cbox(g, stone(rnd), rnd.uniform(-6, 6), rnd.uniform(-6, -3), 0.8, 2.5, 2.0, 1.6, c=0.3, rz=rnd.uniform(0, 3))


def altar_big(g):
    """제단(22x14). 세 켜 단 위 판, 가운데 돌 화로에 불"""
    rnd = random.Random(602)
    cbox(g, "Stone3", 0, 0, 1.2, 22.0, 14.0, 2.4, c=0.4)
    cbox(g, "Stone2", 0, 0, 3.2, 18.0, 11.0, 1.6, c=0.3)
    cbox(g, "Stone", 0, 0, 5.2, 14.0, 8.0, 2.4, c=0.4)
    lathe(g, "Weather", 0, 0, 6.4, [(2.6, 0.0), (3.4, 1.0), (3.6, 1.6)], 12)
    cone_between(g, "Glow", (0, 0, 7.2), (0, 0, 11.0), 2.2, 0.1, seg=8)
    cone_between(g, "Glow", (1.0, 0.6, 7.2), (1.2, 0.5, 9.4), 1.2, 0.1, seg=6)
    g["LampPt"].box(0, 0, 9.5, 0.1, 0.1, 0.1)
    for k in range(4):
        cbox(g, stone(rnd), rnd.uniform(-12, 12), rnd.uniform(-9, 9), 0.7, 2.0, 1.8, 1.4, c=0.3, rz=rnd.uniform(0, 3))


def brazier_big(g):
    """화로. 네모 기둥 위 돌 사발에 불 (높이 약 12)"""
    cbox(g, "Stone3", 0, 0, 0.8, 5.0, 5.0, 1.6, c=0.3)
    cbox(g, "Stone", 0, 0, 5.0, 3.0, 3.0, 7.0, c=0.3)
    lathe(g, "Stone2", 0, 0, 8.4, [(1.6, 0.0), (2.8, 1.2), (3.0, 2.0)], 12)
    cone_between(g, "Glow", (0, 0, 9.6), (0, 0, 12.6), 1.8, 0.1, seg=8)
    g["LampPt"].box(0, 0, 11.0, 0.1, 0.1, 0.1)


def beacon_base(g):
    """빛 기둥 받침. 둥근 두 켜 돌 단과 가운데 구멍 둘레 돌 넷. 빛 기둥(네온)은 Studio 에서 세운다"""
    rnd = random.Random(604)
    for k, (r, z0, z1) in enumerate(((9.0, 0.0, 1.6), (6.5, 1.6, 3.2))):
        g["Stone2"].cyl(0, 0, z0, r, r, z1 - z0, seg=24)
    for j in range(4):
        a = math.pi / 4 + j * math.pi / 2
        cbox(g, stone(rnd), 4.0 * math.cos(a), 4.0 * math.sin(a), 5.2, 2.4, 2.4, 4.0, c=0.3, rz=a)
    g["Glow"].cyl(0, 0, 3.2, 1.6, 1.6, 0.4, seg=12)


# ================================================================ 떨어진 탑 조각, 떠 있는 바위, 도는 파편
def chunk_tower(g, seed):
    """떨어진 갈빗대 토막. 휜 돌 띠가 비스듬히 땅에 박히고 둘레에 떨어진 덩이"""
    rnd = random.Random(seed)
    R = 60.0
    n = 7
    for k in range(n):
        a = -0.45 + 0.9 * k / (n - 1)
        x, y = R * math.sin(a), R * (1 - math.cos(a)) - 5
        z = 6.0 + 16.0 * k / (n - 1) + rnd.uniform(-0.6, 0.6)
        cbox(g, stone(rnd), x, y, z, 12.0, 14.0, 17.0, c=1.1, rz=a, rx=-0.55 + rnd.uniform(-0.06, 0.06))
    for k in range(9):
        cbox(g, stone(rnd), rnd.uniform(-30, 30), rnd.uniform(-16, 12), 2.2, rnd.uniform(4, 9), rnd.uniform(4, 9), 4.4,
             c=0.6, rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.35, 0.35))


def float_rock(g, seed, size):
    """떠 있는 바위. 모난 돌 덩이 뭉치 위에 무너진 바닥돌과 벽 한 토막. 원점은 밑(띄우는 높이는 Studio)"""
    rnd = random.Random(seed)
    s = size
    for k in range(9):
        cx, cy = rnd.uniform(-0.25, 0.25) * s, rnd.uniform(-0.25, 0.25) * s
        w = rnd.uniform(0.35, 0.6) * s
        h = (0.55 - 0.05 * k) * s
        z = s * 0.1 + k * 0.05 * s
        cbox(g, "Stone3" if k < 4 else "Weather", cx, cy, max(h / 2 + 0.01, z), w, w * rnd.uniform(0.8, 1.2), h, c=w * 0.12,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))
    top = 0.62 * s
    for k in range(5):
        cbox(g, stone(rnd), rnd.uniform(-0.25, 0.25) * s, rnd.uniform(-0.25, 0.25) * s, top, s * 0.2, s * 0.2, 1.6, c=0.3,
             rz=rnd.uniform(0, 3))
    masonry_wall(g, rnd, -0.2 * s, 0.1 * s, 0.2 * s, 0.12 * s, top, 2.6, [(0, 7.0), (0.5, 9.0), (1, 3.5)], course=2.2,
                 blk=(3.0, 5.0))


def debris(g, kind):
    """코어를 도는 파편"""
    rnd = random.Random(700 + kind)
    if kind == 0:
        cbox(g, stone(rnd), 0, 0, 8.5, 15.0, 13.0, 17.0, c=1.1)
    elif kind == 1:
        cbox(g, stone(rnd), 0, 0, 5.0, 12.0, 10.0, 10.0, c=0.8)
        cbox(g, stone(rnd), 6.0, 2.0, 10.0, 9.0, 8.0, 8.0, c=0.7, rz=0.4)
    else:
        for k in range(3):
            cbox(g, stone(rnd), k * 11.0, 0, 7.0 + k * 3.0, 12.0, 11.0, 14.0, c=1.0, rx=-0.4)


# ================================================================ 성벽, 방 폐허, 자갈
def edge_wall(g, seed):
    """가장자리 성벽 한 토막(길이 40, 두께 7). 무너진 윗선과 발치에 떨어진 돌"""
    rnd = random.Random(seed)
    prof = [(0, rnd.uniform(14, 22)), (0.3, rnd.uniform(18, 24)), (0.55, rnd.uniform(6, 12)), (0.8, rnd.uniform(14, 20)),
            (1, rnd.uniform(8, 18))]
    masonry_wall(g, rnd, 0, -20.0, 0, 20.0, 0.0, 7.0, prof, course=3.4, blk=(5.0, 9.0), c=0.45)
    for k in range(8):
        cbox(g, stone(rnd), rnd.uniform(-9, 9), rnd.uniform(-20, 20), 1.6, rnd.uniform(3, 6), rnd.uniform(3, 6), 3.2, c=0.4,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))


def edge_tower(g):
    """성벽 망루. 둥근 망루(지름 26)가 한쪽으로 무너졌다"""
    rnd = random.Random(801)
    R = 13.0
    n = 16
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        h = 34.0 - 20.0 * max(0.0, math.cos(a0 - 1.0))
        masonry_wall(g, rnd, R * math.cos(a0), R * math.sin(a0), R * math.cos(a1), R * math.sin(a1), 0.0, 4.0,
                     [(0, h), (1, h)], course=3.4, blk=(3.0, 6.0), c=0.4)
    for k in range(10):
        a = 1.0 + rnd.uniform(-0.6, 0.6)
        rr = R + rnd.uniform(2, 12)
        cbox(g, stone(rnd), rr * math.cos(a), rr * math.sin(a), 1.8, rnd.uniform(3, 6), rnd.uniform(3, 6), 3.6, c=0.4,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))


def ruin_room(g, seed):
    """방 폐허(30x24). 네 벽이 제각각 무너졌고 앞 벽에 문간, 옆 벽에 창 자리, 안에 깨진 바닥돌"""
    rnd = random.Random(seed)
    W, D = 30.0, 24.0
    walls = [((-W / 2, -D / 2, -3.5, -D / 2), [(0, 12), (1, 9)]), ((3.5, -D / 2, W / 2, -D / 2), [(0, 8), (1, 14)]),
             ((W / 2, -D / 2, W / 2, D / 2), [(0, 14), (0.5, 16), (0.7, 5), (1, 3)]),
             ((W / 2, D / 2, -W / 2, D / 2), [(0, 3), (0.4, 11), (1, 17)]),
             ((-W / 2, D / 2, -W / 2, -D / 2), [(0, 17), (0.5, 12), (1, 12)])]
    for (x0, y0, x1, y1), prof in walls:
        masonry_wall(g, rnd, x0, y0, x1, y1, 0.0, 2.8, prof, course=2.8, blk=(3.5, 6.5), c=0.35)
    cbox(g, "Stone2", 0, -D / 2, 9.8, 8.4, 3.0, 1.6, c=0.3)   # 문 위 인방
    for x in range(-12, 13, 6):
        for y in range(-9, 10, 6):
            if rnd.random() < 0.7:
                cbox(g, stone(rnd), x + rnd.uniform(-0.3, 0.3), y + rnd.uniform(-0.3, 0.3), 0.3, 5.6, 5.6, 0.6, c=0.15,
                     rz=rnd.uniform(-0.06, 0.06), rx=rnd.uniform(-0.04, 0.04))
    for k in range(6):
        cbox(g, stone(rnd), rnd.uniform(8, 20), rnd.uniform(4, 16), 1.4, rnd.uniform(2, 4), rnd.uniform(2, 4), 2.8, c=0.3,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))


def rubble_heap(g, seed):
    """자갈 무더기(24x20). 큰 덩이가 기대고 작은 돌이 둘레에"""
    rnd = random.Random(seed)
    for k in range(18):
        r = rnd.uniform(0, 1) ** 0.7
        a = rnd.uniform(0, 2 * math.pi)
        x, y = r * 11 * math.cos(a), r * 9 * math.sin(a)
        s = (1.3 - r) * rnd.uniform(3, 6) + 1.5
        cbox(g, stone(rnd), x, y, s * 0.45 + (1 - r) * 3.0, s * 1.3, s, s, c=0.35, rz=rnd.uniform(0, 3),
             rx=rnd.uniform(-0.4, 0.4), ry=rnd.uniform(-0.3, 0.3))


def rubble_field(g, seed):
    """돌 밭(60x60). 깨진 바닥돌이 흩어져 땅을 덮고 군데군데 작은 덩이. 높이 2 안쪽 (빈 땅 메우기)"""
    rnd = random.Random(seed)
    for x in range(-27, 28, 9):
        for y in range(-27, 28, 9):
            if rnd.random() < 0.72:
                w = rnd.uniform(6.0, 8.4)
                cbox(g, stone(rnd), x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), 0.35, w, w * rnd.uniform(0.7, 1.0), 0.7,
                     c=0.2, rz=rnd.uniform(-0.3, 0.3), rx=rnd.uniform(-0.05, 0.05))
    for k in range(10):
        cbox(g, stone(rnd), rnd.uniform(-26, 26), rnd.uniform(-26, 26), 1.2, rnd.uniform(2, 4), rnd.uniform(2, 4), 2.0, c=0.3,
             rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.3, 0.3))


def pave_strip(g, seed):
    """참배로 포석 한 토막(폭 30, 길이 40). 큰 판돌 3 줄, 몇 장은 깨지거나 들렸다. 두께 1"""
    rnd = random.Random(seed)
    for i, x in enumerate((-10.0, 0.0, 10.0)):
        y = -20.0
        while y < 20.0 - 0.5:
            L0 = min(rnd.uniform(6.0, 9.0), 20.0 - y)
            tilt = rnd.uniform(-0.05, 0.05) if rnd.random() < 0.2 else 0.0
            cbox(g, stone(rnd), x, y + L0 / 2, 0.5 + abs(tilt) * 3, 9.9, L0 - 0.12, 1.0, c=0.15, rx=tilt)
            y += L0
    cbox(g, "Stone3", -15.6, 0, 0.7, 1.2, 40.0, 1.4, c=0.2)
    cbox(g, "Stone3", 15.6, 0, 0.7, 1.2, 40.0, 1.4, c=0.2)


# ---------------------------------------------------------------- 내놓기
def job_tower_preview(g):
    tower(Sections([g]))


JOBS = [
    ("Tower_Podium", "RPod", tower_podium, (200, -230, 110), (0, 0, 10)),
    ("Tower_Preview", "RTwPv", job_tower_preview, (560, -700, 380), (0, 0, 300)),
    ("Col_Big", "RColA", col_big, (22, -30, 30), (0, 0, 22)),
    ("Col_Big_B", "RColB", col_big_b, (18, -24, 20), (0, 0, 14)),
    ("Col_Big_C", "RColC", col_big_c, (14, -18, 12), (0, 0, 5)),
    ("Col_Drums", "RColD", col_drums, (30, -36, 24), (0, 0, 3)),
    ("Lintel_Big", "RLint", lintel_big, (26, -34, 20), (0, 0, 4)),
    ("Gate_A", "RGateA", gate_a, (90, -120, 70), (0, 0, 35)),
    ("Gate_B", "RGateB", gate_b, (90, -120, 70), (6, 0, 30)),
    ("Arcade_A", "RArcA", arcade_a, (34, -46, 30), (0, 0, 20)),
    ("Arcade_B", "RArcB", arcade_b, (34, -46, 30), (0, 0, 14)),
    ("Arcade_C", "RArcC", arcade_c, (30, -40, 20), (0, 0, 4)),
    ("Arcade_Pier", "RArcP", arcade_pier, (14, -20, 20), (0, 0, 13)),
    ("Shrine_Pavilion", "RShP", shrine_pavilion, (90, -110, 70), (0, 0, 20)),
    ("Shrine_Tower", "RShT", shrine_tower, (70, -90, 70), (0, 0, 38)),
    ("Terrace_A", "RTerA", lambda g: terrace(g, 4, 150.0, 11), (170, -200, 110), (0, 0, 10)),
    ("Terrace_B", "RTerB", lambda g: terrace(g, 3, 120.0, 12), (140, -170, 90), (0, 0, 8)),
    ("Pool_Big", "RPoolA", lambda g: pool(g, 63.0), (100, -120, 70), (0, 0, 0)),
    ("Pool_Mid", "RPoolB", lambda g: pool(g, 50.0), (80, -100, 60), (0, 0, 0)),
    ("Colossus", "RColo", colossus, (50, -64, 44), (0, 0, 20)),
    ("Colossus_Head", "RHead", colossus_head, (26, -34, 20), (0, 0, 7)),
    ("Colossus_Hand", "RHand", colossus_hand, (24, -30, 18), (0, 0, 3)),
    ("Stele_Big", "RStele", stele_big, (26, -36, 24), (0, 0, 16)),
    ("Altar_Big", "RAltar", altar_big, (26, -32, 20), (0, 0, 5)),
    ("Brazier_Big", "RBraz", brazier_big, (12, -16, 12), (0, 0, 7)),
    ("Beacon_Base", "RBeac", beacon_base, (16, -20, 14), (0, 0, 3)),
    ("Chunk_Tower_A", "RChA", lambda g: chunk_tower(g, 21), (70, -90, 50), (0, 0, 12)),
    ("Chunk_Tower_B", "RChB", lambda g: chunk_tower(g, 22), (70, -90, 50), (0, 0, 12)),
    ("Float_Rock_A", "RFlA", lambda g: float_rock(g, 31, 40.0), (60, -80, 50), (0, 0, 14)),
    ("Float_Rock_B", "RFlB", lambda g: float_rock(g, 32, 56.0), (80, -110, 64), (0, 0, 18)),
    ("Float_Rock_C", "RFlC", lambda g: float_rock(g, 33, 30.0), (46, -60, 38), (0, 0, 10)),
    ("Debris_A", "RDebA", lambda g: debris(g, 0), (30, -40, 30), (0, 0, 8)),
    ("Debris_B", "RDebB", lambda g: debris(g, 1), (30, -40, 30), (0, 0, 8)),
    ("Debris_C", "RDebC", lambda g: debris(g, 2), (40, -50, 40), (10, 0, 10)),
    ("Edge_Wall_A", "RWallA", lambda g: edge_wall(g, 41), (50, -40, 36), (0, 0, 10)),
    ("Edge_Wall_B", "RWallB", lambda g: edge_wall(g, 42), (50, -40, 36), (0, 0, 10)),
    ("Edge_Tower", "RWallT", edge_tower, (50, -60, 44), (0, 0, 14)),
    ("Ruin_Room_A", "RRoomA", lambda g: ruin_room(g, 51), (44, -56, 40), (0, 0, 6)),
    ("Ruin_Room_B", "RRoomB", lambda g: ruin_room(g, 52), (44, -56, 40), (0, 0, 6)),
    ("Rubble_Heap_A", "RRubA", lambda g: rubble_heap(g, 61), (30, -38, 24), (0, 0, 3)),
    ("Rubble_Heap_B", "RRubB", lambda g: rubble_heap(g, 62), (30, -38, 24), (0, 0, 3)),
    ("Rubble_Field_A", "RFldA", lambda g: rubble_field(g, 71), (60, -80, 60), (0, 0, 0)),
    ("Rubble_Field_B", "RFldB", lambda g: rubble_field(g, 72), (60, -80, 60), (0, 0, 0)),
    ("Pave_Strip_A", "RPavA", lambda g: pave_strip(g, 81), (40, -50, 30), (0, 0, 0)),
    ("Pave_Strip_B", "RPavB", lambda g: pave_strip(g, 82), (40, -50, 30), (0, 0, 0)),
]


def tower_section_groups():
    gs = [G("RTw%d" % (k + 1)) for k in range(N_SEC)]
    tower(Sections(gs))
    return gs


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, cam, look in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        lift = norm_floor(g)
        if lift:
            print("  %s 올림 %.2f" % (name, lift))
        L.export_model(name, g, 1.0, renders=[("corner", cam, look)], min_objs=1, palette=RPAL, tri_limit=10 ** 7)
