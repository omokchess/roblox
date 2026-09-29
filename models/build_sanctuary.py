# -*- coding: utf-8 -*-
"""
build_sanctuary.py — 탑의 성역 리메이크 모델. (2026-09-27)

성역은 게임 이름(Porcelain)에 맞춰 백자 같은 흰 돌에 청화 코발트 띠, 금 장식, 푸른 룬 빛으로 간다.
치수는 스터드 그대로(배율 1). 원점은 바닥 가운데, 앞은 -y (로블록스 -Z). 블렌더 +x 는 로블록스 -X,
블렌더 +y 는 로블록스 +Z(북, 평원 쪽. 성역의 큰길이 뻗는 쪽)다.

  탑      예전에 고른 꼴(가운데 기둥을 감고 오르는 나선계단 + 반대로 꼬인 갈빗대 다섯)을 살린다.
          높이 520, 42% 부터 부서진다. 로블록스 메시 한도 때문에 높이 여섯 토막(Tower_S1..S6)으로 나눈다.
          모든 토막의 원점은 탑 발치 한가운데라 같은 자리에 겹쳐 놓으면 된다. 코어와 도는 파편은 Studio 에서
  기단    세 켜 둥근 단과 네 방향 계단 (Tower_Plinth). 탑 발치는 기단 원점 + 12

돌리는 법: blender --background --python build_sanctuary.py [-- 이름...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
from build_props import lathe, ball, extrude, annulus, frustum, cone_between  # noqa: E402
from build_steam import tube  # noqa: E402
from build_palace_props import ellipsoid  # noqa: E402

SPAL = {
    "Marble": "#E9E6DC",       # 백자 빛 돌
    "Shade": "#C4C0B3",        # 오래된 돌 이음, 계단 챌판
    "Cobalt": "#24478F",       # 청화
    "Gold": "#C9A24A",
    "Rune": "#7ACAFF",         # 푸른 룬 빛 (Neon)
    "Stone": "#8E8A80",        # 부서진 속살
    "Bronze": "#6B5635",
    "Leaf": "#2F5A3C",         # 측백 짙은 잎
    "LeafLight": "#6E9A5A",
    "Bark": "#6B5A4A",
    "Blossom": "#F3E7EB",      # 흰 꽃
    "LampPt": "#FFFFFF",       # 표지. 점광원 자리
}


def G(prefix):
    return L.new_groups(prefix, SPAL)


# ================================================================ 탑
H = 520.0
BREAK = 0.42
TURNS = 4.0          # 계단. 반시계
CTURNS = -2.4        # 갈빗대. 계단과 반대로 꼰다
A0 = math.pi / 2     # 계단은 북(+y, 큰길 쪽)에서 오르기 시작한다
N_SEC = 6


class Sections:
    """z 로 토막을 고른다. 미리보기는 한 토막에 다 넣는다"""

    def __init__(self, gs):
        self.gs = gs

    def at(self, z):
        k = int(z / (H / len(self.gs)))
        return self.gs[min(len(self.gs) - 1, max(0, k))]


def col_r(z):
    return 14.0 - 6.0 * z / H


def stair_r(t):
    return 30.0 - 10.0 * t


def stair_w(t):
    return 12.0 - 3.0 * t


def rib_r(t):
    return 60.0 - 26.0 * t


def rib_ring(c, t, a, T, V, dr=0.0):
    """갈빗대 단면 네 점. 반지름 방향 두께 T, 높이 V"""
    r = rib_r(t) + dr
    ca, sa = math.cos(a), math.sin(a)
    z = t * H
    return [((r - T / 2) * ca, (r - T / 2) * sa, z - V / 2), ((r + T / 2) * ca, (r + T / 2) * sa, z - V / 2),
            ((r + T / 2) * ca, (r + T / 2) * sa, z + V / 2), ((r - T / 2) * ca, (r - T / 2) * sa, z + V / 2)]


def sweep(g, mat, rings, cap0=True, cap1=True):
    """고리(네 점)들을 이어 띠 하나. 두 끝을 막는다"""
    v = [p for ring in rings for p in ring]
    f = []
    n = len(rings)
    for i in range(n - 1):
        b0, b1 = i * 4, (i + 1) * 4
        for k in range(4):
            k1 = (k + 1) % 4
            f.append((b0 + k, b0 + k1, b1 + k1, b1 + k))
    if cap0:
        f.append((3, 2, 1, 0))
    if cap1:
        b = (n - 1) * 4
        f.append((b, b + 1, b + 2, b + 3))
    g[mat].add_mesh(v, f)


RIB_END = [0.95, 0.72, 0.86, 0.63, 0.80]
RIB_GAPS = [[(0.62, 0.645), (0.80, 0.82)], [(0.55, 0.575)], [(0.50, 0.52), (0.70, 0.73)], [(0.47, 0.50)], [(0.58, 0.60)]]
STAIR_END = 0.66
TIES = [0.10, 0.20, 0.30, 0.40]


STEPS_OUT = []   # (번호, 로블록스 x, 윗면 y, z, 폭) — 탑 발치 원점. 충돌 비탈을 Studio 에서 이 점들로 잇는다


def tower(sec):
    STEPS_OUT.clear()
    rnd = random.Random(52)
    # 가운데 기둥. 26 마다 한 토막, 토막 밑에 청화 띠, 네 곳에 룬 창
    TOP = 0.8 * H
    z = 0.0
    k = 0
    while z < TOP - 1:
        z1 = min(TOP, z + 26.0)
        g = sec.at((z + z1) / 2)
        lathe(g, "Marble", 0, 0, z, [(col_r(z), 0.0), (col_r(z1), z1 - z)], 24)
        annulus(g, "Cobalt", (0, 0, z + 1.2), "z", col_r(z) - 0.2, col_r(z) + 0.45, 1.6, n=24)
        annulus(g, "Gold", (0, 0, z + 2.3), "z", col_r(z) - 0.2, col_r(z) + 0.3, 0.3, n=24)
        for j in range(4):
            a = A0 + j * math.pi / 2 + k * 0.5
            r = col_r(z + 14) + 0.05
            g["Rune"].obox(r * math.cos(a), r * math.sin(a), z + 14, 0.5, 1.0, 5.0, rz=a)
        z = z1
        k += 1
    # 부러진 꼭대기. 가장자리에 들쭉날쭉한 덩이
    g = sec.at(TOP)
    for j in range(9):
        a = 2 * math.pi * j / 9 + rnd.uniform(0, 0.3)
        h = rnd.uniform(3, 16)
        r = col_r(TOP) - 1.6
        g["Stone"].obox(r * math.cos(a), r * math.sin(a), TOP + h / 2 - 0.5, 3.4, 4.2, h, rz=a,
                        rx=rnd.uniform(-0.15, 0.15))
    g["Stone"].cyl(0, 0, TOP - 0.5, col_r(TOP) - 2.5, col_r(TOP) - 3.5, 2.0, seg=16)
    # 룬 고리. 부서지기 전 높이에만 온전하다
    for zz in (60.0, 150.0):
        annulus(sec.at(zz), "Rune", (0, 0, zz), "z", col_r(zz) + 0.1, col_r(zz) + 0.7, 0.8, n=24)

    # 나선계단
    rise = 2.0
    n = int(H * STAIR_END / rise)
    per = TURNS * 2 * math.pi / (H / rise)
    posts = []
    for i in range(n):
        zt = (i + 1) * rise
        t = zt / H
        if t > BREAK and (i % 5 in (1, 3) or (t > 0.56 and i % 3 == 0)):
            posts.append(None)
            continue
        a = A0 + (i + 0.5) * per
        r_in = col_r(zt) - 0.6
        r_out = stair_r(t) + stair_w(t) / 2
        g = sec.at(zt)
        tw = per * r_out * 1.12
        rc = (r_in + r_out) / 2
        drop = 0.0
        if t > BREAK:   # 흔들린 계단. 조금 처지고 비뚤다
            drop = rnd.uniform(0, 0.8)
        g["Marble"].obox(rc * math.cos(a), rc * math.sin(a), zt - 0.8 - drop, r_out - r_in, tw, 1.6, rz=a,
                         rx=rnd.uniform(-0.04, 0.04) if drop else 0.0)
        STEPS_OUT.append((i, -rc * math.cos(a), zt - drop, rc * math.sin(a), r_out - r_in))
        if zt > 3:
            g["Shade"].obox((r_out - 0.3) * math.cos(a), (r_out - 0.3) * math.sin(a), zt - 1.9 - drop, 0.6, tw, 0.6, rz=a)
        if i % 6 == 0 and zt > 6:   # 계단 밑 까치발
            rb = r_in + 2.2
            g["Shade"].obox(rb * math.cos(a), rb * math.sin(a), zt - 3.2, 4.4, 1.6, 2.8, rz=a)
        if i % 3 == 0 and t < BREAK + 0.1:
            rp = r_out - 0.5
            p = (rp * math.cos(a), rp * math.sin(a), zt)
            g["Cobalt"].box(p[0], p[1], zt + 1.6, 0.5, 0.5, 3.2)
            posts.append(p)
        else:
            posts.append(None)
    # 난간대. 이웃한 기둥 머리끼리
    last = None
    for p in posts:
        if p is None:
            continue
        if last is not None and p[2] - last[2] < 8:
            tube(sec.at(p[2]), "Gold", (last[0], last[1], last[2] + 3.3), (p[0], p[1], p[2] + 3.3), 0.22, seg=5)
        last = p

    # 갈빗대 다섯
    NS = 130
    T, V = 9.0, 17.0
    for rb in range(5):
        a0 = A0 + 2 * math.pi * rb / 5 + math.pi / 5
        end = RIB_END[rb]
        gaps = RIB_GAPS[rb]
        cur = []
        loosen = 0.0

        def flush(cur, loosen):
            if len(cur) < 2:
                return
            zmid = cur[len(cur) // 2][1] * H
            g = sec.at(zmid)
            rings = [rib_ring(None, t, a, T, V, loosen) for (a, t) in cur]
            sweep(g, "Marble", rings)
            inl = [rib_ring(None, t, a, 1.0, 3.6, T / 2 + 0.25 + loosen) for (a, t) in cur]
            sweep(g, "Cobalt", inl)
            # 부러진 끝이면 속살 덩이
            for (a, t) in (cur[0], cur[-1]):
                if t > BREAK:
                    r = rib_r(t) + loosen
                    gg = sec.at(t * H)
                    for j in range(3):
                        gg["Stone"].obox(r * math.cos(a) + rnd.uniform(-1.5, 1.5), r * math.sin(a) + rnd.uniform(-1.5, 1.5),
                                         t * H + rnd.uniform(-3, 3), rnd.uniform(2, 4), rnd.uniform(2, 4), rnd.uniform(2, 5),
                                         rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.4, 0.4))

        for i in range(NS + 1):
            t = i / NS
            if t > end:
                break
            if t * H < V / 2:   # 첫 마디가 발치 밑으로 들어가지 않게. 받침이 덮는다
                continue
            a = a0 + t * CTURNS * 2 * math.pi
            if any(g0 <= t <= g1 for g0, g1 in gaps):
                flush(cur, loosen)
                cur = []
                loosen += 0.9
                continue
            cur.append((a, t))
            # 금 못. 열 마디마다 바깥 면에
            if i % 10 == 5:
                r = rib_r(t) + T / 2 + 0.3 + loosen
                ball(sec.at(t * H), "Gold", r * math.cos(a), r * math.sin(a), t * H, 0.8, seg=8)
        flush(cur, loosen)
        # 발치 받침
        a = a0
        r = rib_r(0)
        g = sec.at(4)
        g["Marble"].obox(r * math.cos(a), r * math.sin(a), 3.0, T + 6, 16, 6.0, rz=a)
        g["Cobalt"].obox((r + T / 2 + 3.05) * math.cos(a), (r + T / 2 + 3.05) * math.sin(a), 3.0, 0.2, 12, 2.0, rz=a)

    # 갈빗대를 묶는 가로대
    for t in TIES:
        for rb in range(5):
            a0 = A0 + 2 * math.pi * rb / 5 + math.pi / 5 + t * CTURNS * 2 * math.pi
            a1 = a0 + 2 * math.pi / 5
            r = rib_r(t)
            p0 = (r * math.cos(a0), r * math.sin(a0), t * H)
            p1 = (r * math.cos(a1), r * math.sin(a1), t * H)
            g = sec.at(t * H)
            tube(g, "Cobalt", p0, p1, 1.6, seg=6)
            for p in (p0, p1):
                g["Gold"].cyl(p[0], p[1], p[2] - 2.2, 2.2, 2.2, 0.6, seg=8)


def tower_plinth(g):
    """세 켜 둥근 단. 켜마다 윗단 턱과 챌판 청화 띠, 네 방향 계단(16 폭)과 옆벽, 계단 밑 두 귀에 룬 받침"""
    tiers = [(96.0, 0.0, 4.0), (82.0, 4.0, 8.0), (68.0, 8.0, 12.0)]
    for r, z0, z1 in tiers:
        g["Marble"].cyl(0, 0, z0, r, r, z1 - z0, seg=64)
        g["Marble"].cyl(0, 0, z1 - 0.6, r + 0.6, r + 0.6, 0.6, seg=64)
        annulus(g, "Cobalt", (0, 0, z0 + (z1 - z0) * 0.45), "z", r - 0.1, r + 0.15, 1.2, n=64)
    for q in range(4):
        a = A0 + q * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        nstep = 15
        for k in range(nstep):
            zt = 12.0 * (k + 1) / nstep
            r0 = 96.0 + 1.0 - 1.9 * (k + 1)   # 바깥에서 안으로 올라간다
            rc = r0 + 0.95
            g["Marble"].obox(rc * ca, rc * sa, zt / 2, 1.9, 16.0, zt, rz=a)
            g["Shade"].obox((r0 + 1.9) * ca, (r0 + 1.9) * sa, zt - 0.4, 0.12, 16.0, 0.8, rz=a)
        # 옆벽. 계단 옆을 따라 비스듬히
        for s in (-1, 1):
            ox, oy = -sa * s * 8.8, ca * s * 8.8
            for k in range(nstep):
                zt = 12.0 * (k + 1) / nstep
                r0 = 96.0 + 1.0 - 1.9 * (k + 1) + 0.95
                g["Marble"].obox(r0 * ca + ox, r0 * sa + oy, (zt + 1.6) / 2, 1.9, 1.6, zt + 1.6, rz=a)
            r0 = 96.0 + 1.0 - 0.95
            g["Cobalt"].obox(r0 * ca + ox, r0 * sa + oy, 2.4, 1.2, 1.7, 0.8, rz=a)
            # 계단 밑 룬 받침
            g["Marble"].obox((r0 + 2.2) * ca + ox * 1.05, (r0 + 2.2) * sa + oy * 1.05, 1.8, 2.4, 2.4, 3.6, rz=a)
            ball(g, "Rune", (r0 + 2.2) * ca + ox * 1.05, (r0 + 2.2) * sa + oy * 1.05, 4.2, 0.7, seg=10)
            g["LampPt"].box((r0 + 2.2) * ca + ox * 1.05, (r0 + 2.2) * sa + oy * 1.05, 5.4, 0.1, 0.1, 0.1)


# ================================================================ 열주 (안뜰 둘레 r 170, 28 기둥)
COL_H = 36.0


def col_base(g):
    g["Marble"].box(0, 0, 0.6, 7.2, 7.2, 1.2)
    g["Cobalt"].box(0, 0, 0.6, 7.3, 7.3, 0.35)
    lathe(g, "Marble", 0, 0, 1.2, [(3.5, 0.0), (3.6, 0.4), (3.0, 0.9), (3.1, 1.2), (2.8, 1.5)], 20)


def col_shaft(g, z0, h, r0=2.75, r1=2.4):
    lathe(g, "Marble", 0, 0, z0, [(r0, 0.0), (r0 * 1.01, h * 0.3), (r1, h)], 20)
    for zz in (z0 + 1.2, z0 + h - 1.6):
        rr = r0 + (r1 - r0) * (zz - z0) / h
        annulus(g, "Cobalt", (0, 0, zz), "z", rr - 0.1, rr + 0.18, 0.7, n=20)
    # 청화 덩굴 무늬 대신 세로 띠 넷. 기둥이 도는 쪽을 알려 준다
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        rr = (r0 + r1) / 2 + 0.05
        g["Cobalt"].obox(rr * math.cos(a), rr * math.sin(a), z0 + h * 0.5, 0.2, 0.45, h * 0.62, rz=a)


def col_capital(g, z0):
    lathe(g, "Marble", 0, 0, z0, [(2.4, 0.0), (2.9, 0.6), (3.5, 1.4), (3.6, 1.7)], 20)
    annulus(g, "Gold", (0, 0, z0 + 0.35), "z", 2.35, 2.6, 0.3, n=20)
    g["Marble"].box(0, 0, z0 + 2.3, 7.4, 7.4, 1.2)
    g["Cobalt"].box(0, 0, z0 + 2.3, 7.5, 7.5, 0.4)


def jagged(g, z, r, n, rnd, hmax=2.5):
    """부러진 기둥 윗면. 가장자리 덩이 몇과 속살 판"""
    g["Stone"].cyl(0, 0, z - 0.3, r - 0.2, r - 0.4, 0.4, seg=12)
    for j in range(n):
        a = 2 * math.pi * j / n + rnd.uniform(0, 0.4)
        h = rnd.uniform(0.6, hmax)
        g["Marble"].obox((r - 0.7) * math.cos(a), (r - 0.7) * math.sin(a), z + h / 2 - 0.2, 1.4, 1.6, h, rz=a,
                         rx=rnd.uniform(-0.2, 0.2))


def col_intact(g):
    """열주 기둥. 네모 받침과 둥근 주초, 배흘림 몸에 청화 고리와 세로 띠, 나팔 꼴 주두와 금 테, 네모 판"""
    col_base(g)
    col_shaft(g, 2.7, 29.6)
    col_capital(g, 32.3)


def col_broken_a(g):
    """반쯤 부러진 기둥"""
    rnd = random.Random(3)
    col_base(g)
    col_shaft(g, 2.7, 17.0, 2.75, 2.55)
    jagged(g, 19.7, 2.55, 6, rnd)


def col_broken_b(g):
    """밑동만 남은 기둥"""
    rnd = random.Random(4)
    col_base(g)
    lathe(g, "Marble", 0, 0, 2.7, [(2.75, 0.0), (2.72, 5.0)], 20)
    annulus(g, "Cobalt", (0, 0, 3.9), "z", 2.65, 2.93, 0.7, n=20)
    jagged(g, 7.7, 2.72, 7, rnd, 1.8)


def col_fallen(g):
    """쓰러진 기둥. 누운 몸 토막 셋이 굴러 흩어지고 주두가 옆으로 누웠다. 원점은 가운데 땅"""
    for (x, y, rz, L0) in ((-6.5, 0.4, 0.08, 8.0), (2.8, -0.6, -0.2, 7.0), (10.8, 1.8, 0.5, 6.0)):
        c, sn = math.cos(rz), math.sin(rz)
        g["Marble"].hcyl(x, y, 2.67, 2.55, L0, axis="x", seg=16, rz=rz)
        for e in (-1, 1):
            g["Cobalt"].hcyl(x + e * (L0 / 2 - 0.9) * c, y + e * (L0 / 2 - 0.9) * sn, 2.67, 2.66, 0.5, axis="x", seg=16, rz=rz)
    # 주두
    g["Marble"].obox(-13.0, -2.0, 3.7, 1.2, 7.4, 7.4, rz=0.3)
    g["Cobalt"].obox(-13.0, -2.0, 3.7, 1.25, 7.5, 0.4, rz=0.3)
    for k in range(5):   # 작은 파편
        g["Stone"].obox(-4 + k * 3.7, 3.8 - (k % 2) * 7.6, 0.4, 1.2 + 0.2 * k, 0.9, 0.8, rz=k * 0.9)


def lintel(g):
    """인방. 두 기둥 머리를 잇는 돌보. 바깥(-y)·안(+y) 두 면에 청화 띠, 아래 금 이빨 줄. 길이 38.2 (원점은 밑 가운데)"""
    Lg = 38.2
    g["Marble"].box(0, 0, 2.0, Lg, 4.4, 4.0)
    g["Marble"].box(0, 0, 4.3, Lg + 0.6, 5.0, 0.6)
    for sy in (-1, 1):
        g["Cobalt"].box(0, sy * 2.22, 2.4, Lg - 0.4, 0.06, 1.3)
        for k in range(19):
            g["Gold"].box(-Lg / 2 + 1.0 + k * (Lg - 2) / 18, sy * 2.3, 0.35, 0.5, 0.2, 0.5)


# ================================================================ 큰 문 (북)
def great_gate(g):
    """
    큰 문. 좁아지는 탑문 둘이 폭 26 높이 34 의 문간을 두고 서고, 위로 처마 얹은 들보와 가운데 금 원판에 푸른 정육면체.
    탑문마다 청화 띠 넷, 앞면 룬 원, 받침 턱. 앞(-y)이 바깥
    """
    for sx in (-1, 1):
        cx = sx * 23.0
        frustum(g, "Marble", cx, 0, 0.0, 20.0, 15.0, 16.5, 12.0, 44.0)
        g["Marble"].box(cx, 0, 1.0, 22.0, 17.0, 2.0)
        for zz in (6.0, 18.0, 30.0, 41.0):
            w = 20.0 - 3.5 * zz / 44 + 0.3
            d = 15.0 - 3.0 * zz / 44 + 0.3
            g["Cobalt"].box(cx, 0, zz, w, d, 1.2)
        g["Marble"].box(cx, 0, 45.0, 18.5, 13.5, 2.0)
        g["Gold"].box(cx, 0, 46.2, 17.5, 12.5, 0.4)
        # 앞면 룬 원
        fy = -(15.0 - 3.0 * 24 / 44) / 2 - 0.05
        annulus(g, "Gold", (cx, fy, 24.0), "y", 3.0, 3.6, 0.3, n=20)
        g["Rune"].hcyl(cx, fy, 24.0, 2.2, 0.25, axis="y", seg=16)
        g["LampPt"].box(cx, fy - 1.5, 24.0, 0.1, 0.1, 0.1)
    # 들보와 처마
    g["Marble"].box(0, 0, 38.0, 30.0, 11.0, 8.0)
    g["Cobalt"].box(0, 0, 36.0, 30.2, 11.2, 1.0)
    g["Marble"].box(0, 0, 43.0, 32.0, 12.5, 2.0)
    frustum(g, "Cobalt", 0, 0, 44.0, 30.0, 11.0, 26.0, 7.0, 3.0)
    g["Gold"].box(0, 0, 47.2, 26.5, 1.0, 0.4)
    # 가운데 금 원판과 푸른 정육면체 (탑의 표)
    annulus(g, "Gold", (0, -5.6, 38.0), "y", 2.4, 3.4, 0.4, n=24)
    g["Cobalt"].hcyl(0, -5.55, 38.0, 2.4, 0.3, axis="y", seg=20)
    g["Rune"].obox(0, -5.9, 38.0, 2.2, 0.4, 2.2, ry=math.pi / 4)
    g["LampPt"].box(0, -7.5, 38.0, 0.1, 0.1, 0.1)
    # 문간 문지방
    g["Shade"].box(0, 0, 0.25, 26.0, 15.0, 0.5)
    # 탑문 머리 나팔 처마 (밖으로 벌어진다)
    for sx in (-1, 1):
        cx = sx * 23.0
        frustum(g, "Marble", cx, 0, 46.4, 17.0, 12.0, 20.0, 15.0, 2.2)
        g["Gold"].box(cx, 0, 48.7, 20.2, 15.2, 0.3)
        # 문간 쪽 문틀. 안쪽 모서리를 따라 도드라진 테
        ix = cx - sx * (16.5 / 2 + 0.2)
        g["Marble"].box(cx - sx * 8.9, -6.8, 17.0, 1.2, 1.4, 34.0)
        # 앞면 글자판. 청화 바탕에 금 룬 셋
        fy = -(15.0 - 3.0 * 12 / 44) / 2 - 0.08
        g["Cobalt"].box(cx, fy, 12.0, 7.0, 0.15, 9.0)
        for j in range(3):
            g["Gold"].box(cx - 2.0 + j * 2.0, fy - 0.1, 12.0 + (j % 2) * 1.2, 0.5, 0.1, 3.2 - (j % 2) * 1.0)
            g["Gold"].box(cx - 2.0 + j * 2.0, fy - 0.1, 14.2 - (j % 2) * 3.0, 1.4, 0.1, 0.4)
    g["Marble"].box(0, -6.8, 33.4, 26.0, 1.4, 1.2)   # 문간 윗 테


# ================================================================ 원형 사당 (동·서)
def tholos(g):
    """
    원형 사당. 세 켜 둥근 단, 기둥 열 개가 둥근 들보와 반구 지붕을 받친다. 지붕에 청화 늑골 여덟과 금 꼭지,
    안에 네모 제단과 푸른 불. 앞(-y)에 계단 한 줄
    """
    for r, z0, z1 in ((17.0, 0.0, 1.2), (15.5, 1.2, 2.4), (14.0, 2.4, 3.6)):
        g["Marble"].cyl(0, 0, z0, r, r, z1 - z0, seg=40)
    annulus(g, "Cobalt", (0, 0, 3.0), "z", 13.95, 14.1, 0.6, n=40)
    for k in range(4):   # 앞 계단
        g["Marble"].box(0, -17.0 - 0.8 - k * 1.6 + 1.6, 0.9 * (3 - k) / 2 + 0.45, 7.0, 1.6, 0.9 * (4 - k))
    R = 12.2
    for k in range(10):
        a = -math.pi / 2 + 2 * math.pi * (k + 0.5) / 10
        x, y = R * math.cos(a), R * math.sin(a)
        lathe(g, "Marble", x, y, 3.6, [(1.25, 0.0), (1.3, 0.5), (1.05, 0.9), (1.0, 14.0), (1.35, 14.8), (1.45, 15.4)], 12)
        annulus(g, "Cobalt", (x, y, 4.9), "z", 0.95, 1.12, 0.5, n=12)
    zt = 3.6 + 15.4
    annulus(g, "Marble", (0, 0, zt + 1.0), "z", R - 2.0, R + 2.0, 2.0, n=40)
    annulus(g, "Cobalt", (0, 0, zt + 1.0), "z", R + 1.95, R + 2.1, 1.0, n=40)
    annulus(g, "Gold", (0, 0, zt + 0.05), "z", R - 1.9, R + 2.05, 0.1, n=40)
    lathe(g, "Marble", 0, 0, zt + 2.0, [(R + 1.2, 0.0)] + [((R + 1.2) * math.cos(math.radians(d)), (R + 1.2) * 0.75 *
                                                              math.sin(math.radians(d))) for d in range(15, 90, 15)] +
          [(0.9, (R + 1.2) * 0.75)], 32)
    for k in range(8):
        a = 2 * math.pi * k / 8
        pts = []
        for d in range(0, 91, 10):
            rr = (R + 1.35) * math.cos(math.radians(d))
            zz = zt + 2.0 + (R + 1.35) * 0.75 * math.sin(math.radians(d))
            pts.append((rr * math.cos(a), rr * math.sin(a), zz))
        for p0, p1 in zip(pts, pts[1:]):
            tube(g, "Cobalt", p0, p1, 0.35, seg=5)
    ztop = zt + 2.0 + (R + 1.2) * 0.75
    lathe(g, "Gold", 0, 0, ztop - 0.1, [(1.2, 0.0), (0.8, 0.6), (0.3, 1.6), (0.12, 2.6)], 10)
    ball(g, "Gold", 0, 0, ztop + 3.0, 0.6, seg=10)
    # 제단과 불
    g["Marble"].box(0, 1.0, 3.6 + 1.6, 5.0, 3.6, 3.2)
    g["Cobalt"].box(0, 1.0, 3.6 + 2.6, 5.2, 3.8, 0.5)
    g["Gold"].box(0, 1.0, 3.6 + 3.3, 4.4, 3.0, 0.2)
    lathe(g, "Bronze", 0, 1.0, 7.0, [(0.9, 0.0), (1.5, 0.5), (1.6, 0.8)], 12)
    cone_between(g, "Rune", (0, 1.0, 7.6), (0, 1.0, 10.8), 1.1, 0.05, seg=8)
    cone_between(g, "Rune", (0.4, 1.3, 7.6), (0.5, 1.2, 9.4), 0.6, 0.05, seg=6)
    g["LampPt"].box(0, 1.0, 9.0, 0.1, 0.1, 0.1)


# ================================================================ 정자 (남쪽 비석 뜰)
def pavilion(g):
    """네모 정자. 두 켜 단, 귀 기둥 넷과 가운데 칸 기둥 여덟, 청화 유약 기와 네모 뿔 지붕과 금 용마루·꼭지, 안에 긴 의자 둘"""
    g["Marble"].box(0, 0, 0.6, 24.0, 24.0, 1.2)
    g["Marble"].box(0, 0, 1.6, 21.0, 21.0, 0.8)
    g["Cobalt"].box(0, 0, 1.6, 21.1, 21.1, 0.3)
    posts = [(-9, -9), (9, -9), (9, 9), (-9, 9), (-3, -9), (3, -9), (-3, 9), (3, 9), (-9, -3), (-9, 3), (9, -3), (9, 3)]
    for x, y in posts:
        lathe(g, "Marble", x, y, 2.0, [(0.9, 0.0), (0.75, 0.6), (0.7, 12.0), (0.95, 12.6)], 10)
        annulus(g, "Gold", (x, y, 13.9), "z", 0.72, 0.95, 0.3, n=10)
    g["Marble"].box(0, 0, 15.2, 21.0, 21.0, 1.4)
    g["Cobalt"].box(0, 0, 15.2, 21.2, 21.2, 0.6)
    frustum(g, "Cobalt", 0, 0, 15.9, 27.0, 27.0, 2.0, 2.0, 8.5)
    for k in range(4):   # 추녀 금 줄
        a = math.pi / 4 + k * math.pi / 2
        tube(g, "Gold", (13.5 * math.sqrt(2) * math.cos(a), 13.5 * math.sqrt(2) * math.sin(a), 15.95),
             (1.0 * math.sqrt(2) * math.cos(a), 1.0 * math.sqrt(2) * math.sin(a), 24.4), 0.3, seg=5)
    lathe(g, "Gold", 0, 0, 24.3, [(1.1, 0.0), (0.7, 0.8), (0.25, 2.2), (0.08, 3.0)], 10)
    for sx in (-1, 1):
        g["Marble"].box(sx * 5.5, 0, 2.9, 1.6, 9.0, 0.4)
        for sy in (-1, 1):
            g["Marble"].box(sx * 5.5, sy * 3.6, 2.4, 1.2, 0.8, 0.8)


# ================================================================ 수호상
def guardian(g):
    """
    수호상. 청화 띠 두른 높은 받침 위에 앞다리를 세우고 앉은 뿔 하나 짐승(해치). 갈기 두 켜, 벌린 입과 송곳니,
    가슴 방울, 말린 꼬리. 몸은 백자 빛, 눈과 갈기 끝에 청화. 앞(-y)을 본다. 높이 약 16
    """
    g["Marble"].box(0, 0, 0.4, 8.4, 10.4, 0.8)
    frustum(g, "Marble", 0, 0, 0.8, 7.6, 9.6, 7.0, 9.0, 3.6)
    g["Cobalt"].box(0, 0, 2.6, 7.4, 9.4, 1.4)
    for sx in (-1, 1):
        g["Gold"].box(sx * 3.72, 0, 2.6, 0.08, 6.0, 0.5)
    g["Marble"].box(0, 0, 4.7, 7.6, 9.6, 0.6)
    s = 3.4
    z0 = 5.0
    m = "Marble"
    ellipsoid(g, m, 0, 0.4 * s, z0 + 0.5 * s, 0.62 * s, 0.65 * s, 0.5 * s)
    ellipsoid(g, m, 0, -0.1 * s, z0 + 1.05 * s, 0.5 * s, 0.48 * s, 0.62 * s)
    for sx in (-1, 1):
        ellipsoid(g, m, sx * 0.5 * s, 0.35 * s, z0 + 0.38 * s, 0.2 * s, 0.45 * s, 0.34 * s, seg=8, rings=5)
        ellipsoid(g, m, sx * 0.45 * s, -0.15 * s, z0 + 0.08 * s, 0.15 * s, 0.24 * s, 0.09 * s, seg=8, rings=4)
        tube(g, m, (sx * 0.27 * s, -0.35 * s, z0 + 0.9 * s), (sx * 0.3 * s, -0.5 * s, z0 + 0.1 * s), 0.14 * s, seg=8)
        ellipsoid(g, m, sx * 0.3 * s, -0.62 * s, z0 + 0.1 * s, 0.17 * s, 0.23 * s, 0.1 * s, seg=8, rings=4)
        for k in range(3):   # 발톱
            g["Gold"].box(sx * 0.3 * s + (k - 1) * 0.22, -0.84 * s, z0 + 0.06 * s, 0.14, 0.3, 0.2)
    hz = z0 + 1.8 * s
    ellipsoid(g, m, 0, -0.35 * s, hz, 0.44 * s, 0.42 * s, 0.38 * s)
    ellipsoid(g, m, 0, -0.74 * s, hz - 0.1 * s, 0.27 * s, 0.23 * s, 0.19 * s, seg=8)
    ball(g, "Cobalt", 0, -0.95 * s, hz - 0.04 * s, 0.09 * s, seg=6)
    for sx in (-1, 1):
        ball(g, "Cobalt", sx * 0.17 * s, -0.69 * s, hz + 0.14 * s, 0.075 * s, seg=6)
        ellipsoid(g, m, sx * 0.17 * s, -0.63 * s, hz + 0.24 * s, 0.14 * s, 0.08 * s, 0.06 * s, seg=8, rings=4)
        cone_between(g, m, (sx * 0.3 * s, -0.25 * s, hz + 0.25 * s), (sx * 0.42 * s, -0.15 * s, hz + 0.5 * s), 0.09 * s,
                     0.02 * s, seg=5)
        cone_between(g, "Gold", (sx * 0.12 * s, -0.82 * s, hz - 0.2 * s), (sx * 0.12 * s, -0.84 * s, hz - 0.36 * s),
                     0.04 * s, 0.01 * s, seg=4)
    ellipsoid(g, m, 0, -0.68 * s, hz - 0.33 * s, 0.22 * s, 0.19 * s, 0.08 * s, seg=8, rings=4)
    for layer, (rr, yy, n, a0) in enumerate(((0.46, -0.2, 11, -150), (0.56, -0.02, 10, -135))):
        for k in range(n):
            a = math.radians(a0 + 30 * k)
            ball(g, m, rr * s * math.sin(a), yy * s, hz + rr * s * math.cos(a) * 0.9 - 0.05 * s, 0.13 * s, seg=6)
            if layer == 1:
                ball(g, "Cobalt", rr * s * 1.12 * math.sin(a), (yy + 0.06) * s, hz + rr * s * 1.12 * math.cos(a) * 0.9 - 0.05 * s,
                     0.05 * s, seg=5)
    cone_between(g, "Gold", (0, -0.42 * s, hz + 0.3 * s), (0, -0.33 * s, hz + 0.72 * s), 0.08 * s, 0.015 * s, seg=6)
    annulus(g, "Cobalt", (0, -0.15 * s, z0 + 1.52 * s), "z", 0.36 * s, 0.47 * s, 0.1 * s, n=14)
    ball(g, "Gold", 0, -0.6 * s, z0 + 1.36 * s, 0.13 * s, seg=8)
    tube(g, m, (0, 0.95 * s, z0 + 0.4 * s), (0, 1.15 * s, z0 + 0.9 * s), 0.1 * s, seg=6)
    tube(g, m, (0, 1.15 * s, z0 + 0.9 * s), (0, 1.0 * s, z0 + 1.35 * s), 0.09 * s, seg=6)
    ball(g, m, 0, 0.95 * s, z0 + 1.45 * s, 0.16 * s, seg=6)


# ================================================================ 청등, 오벨리스크, 벤치
def lantern_blue(g):
    """청등. 네모 받침, 여덟모 기둥, 네 창이 뚫린 불집(안에 푸른 불), 청화 지붕과 금 구슬 꼭지. 높이 약 8"""
    g["Marble"].box(0, 0, 0.4, 2.6, 2.6, 0.8)
    g["Marble"].box(0, 0, 1.0, 2.0, 2.0, 0.4)
    lathe(g, "Marble", 0, 0, 1.2, [(0.55, 0.0), (0.5, 3.2)], 8)
    annulus(g, "Cobalt", (0, 0, 2.0), "z", 0.48, 0.6, 0.35, n=8)
    g["Marble"].box(0, 0, 4.55, 2.2, 2.2, 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Marble"].box(sx * 0.85, sy * 0.85, 5.5, 0.4, 0.4, 1.6)
    g["Rune"].box(0, 0, 5.4, 1.1, 1.1, 1.3)
    g["LampPt"].box(0, 0, 5.4, 0.1, 0.1, 0.1)
    g["Marble"].box(0, 0, 6.45, 2.3, 2.3, 0.3)
    frustum(g, "Cobalt", 0, 0, 6.6, 3.0, 3.0, 0.5, 0.5, 1.3)
    ball(g, "Gold", 0, 0, 8.1, 0.28, seg=8)


def obelisk(g):
    """오벨리스크. 두 켜 받침, 네모 뿔 기둥에 청화 글자 띠 네 면, 금 머리. 높이 30"""
    g["Marble"].box(0, 0, 0.8, 7.0, 7.0, 1.6)
    g["Marble"].box(0, 0, 2.3, 5.4, 5.4, 1.4)
    g["Cobalt"].box(0, 0, 2.3, 5.5, 5.5, 0.4)
    frustum(g, "Marble", 0, 0, 3.0, 3.8, 3.8, 2.4, 2.4, 24.0)
    for k in range(4):
        a = k * math.pi / 2
        for j in range(6):
            zz = 6.0 + j * 3.2
            w = 3.8 - 1.4 * (zz - 3.0) / 24
            g["Cobalt"].obox((w / 2 + 0.02) * math.cos(a), (w / 2 + 0.02) * math.sin(a), zz, 0.06, w * 0.5, 1.6 + 0.4 * (j % 2),
                             rz=a)
    frustum(g, "Gold", 0, 0, 27.0, 2.4, 2.4, 0.05, 0.05, 2.6)
    g["Rune"].box(0, 0, 26.2, 2.46, 2.46, 0.3)


def bench(g):
    """돌 긴 의자. 두 발 판과 앉을 판, 앞 모서리에 청화 선"""
    for sx in (-1, 1):
        g["Marble"].box(sx * 2.6, 0, 0.8, 0.8, 2.0, 1.6)
    g["Marble"].box(0, 0, 1.85, 7.2, 2.4, 0.5)
    g["Cobalt"].box(0, -1.22, 1.85, 7.2, 0.06, 0.2)


# ================================================================ 나무
def cypress(g, h=22.0, seed=1):
    """측백. 짧은 줄기 위로 잎이 한 덩이 불꽃꼴로 좁고 높게 오른다. 겉에 잎 뭉치가 조금씩 불거진다"""
    rnd = random.Random(seed)
    lathe(g, "Bark", 0, 0, 0.0, [(0.6, 0.0), (0.45, 2.6)], 8)
    prof = [(0.9, 1.6), (2.3, 0.18 * h), (2.7, 0.34 * h), (2.4, 0.56 * h), (1.6, 0.78 * h), (0.7, 0.93 * h), (0.12, h)]
    lathe(g, "Leaf", 0, 0, 0.0, prof, 14)
    for k in range(9):
        t = 0.2 + 0.07 * k
        z = t * h
        # 그 높이 반지름
        r = 0.0
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1:
                r = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        a = k * 2.3 + rnd.uniform(0, 0.6)
        br = rnd.uniform(0.7, 1.0)
        mat = "LeafLight" if k % 3 == 1 else "Leaf"
        ellipsoid(g, mat, (r - 0.55) * math.cos(a), (r - 0.55) * math.sin(a), z, br, br, br * 1.8, seg=8, rings=5)


def blossom(g, seed=2):
    """꽃나무. 굽은 줄기가 셋으로 갈라지고 가지 끝마다 흰 꽃 구름, 사이사이 잎"""
    rnd = random.Random(seed)
    tube(g, "Bark", (0, 0, 0.12), (0.4, 0.2, 4.0), 0.75, seg=8)
    ball(g, "Bark", 0.4, 0.2, 4.0, 0.75, seg=8)
    tips = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        p = (0.4 + 3.2 * math.cos(a), 0.2 + 3.2 * math.sin(a), 7.5 + k * 0.6)
        tube(g, "Bark", (0.4, 0.2, 4.0), p, 0.45, seg=6)
        tips.append(p)
    tips.append((0.4, 0.2, 9.8))
    tube(g, "Bark", (0.4, 0.2, 4.0), (0.4, 0.2, 9.8), 0.4, seg=6)
    for (x, y, z) in tips:
        for j in range(4):
            ellipsoid(g, "Blossom", x + rnd.uniform(-1.6, 1.6), y + rnd.uniform(-1.6, 1.6), z + rnd.uniform(-0.3, 1.3),
                      rnd.uniform(1.6, 2.4), rnd.uniform(1.6, 2.4), rnd.uniform(1.2, 1.7), seg=9, rings=5)
        ellipsoid(g, "LeafLight", x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), z - 0.8, 1.4, 1.4, 0.9, seg=8, rings=4)


# ================================================================ 떨어진 탑 조각, 도는 파편
def chunk_rib(g):
    """떨어진 갈빗대 토막. 휜 돌띠가 비스듬히 땅에 박혔다. 바깥 청화 띠, 부러진 두 끝 속살. 원점은 땅"""
    rings, inl = [], []
    T, V = 9.0, 17.0
    for k in range(9):
        u = k / 8
        a = -0.45 + 0.9 * u
        R = 40.0
        cx, cy = R * math.sin(a), R * (1 - math.cos(a)) - 6
        z = -3.0 + 14.0 * u
        n = (math.sin(a), -math.cos(a))
        rings.append([(cx - n[0] * T / 2, cy - n[1] * T / 2, z - V / 2), (cx + n[0] * T / 2, cy + n[1] * T / 2, z - V / 2),
                      (cx + n[0] * T / 2, cy + n[1] * T / 2, z + V / 2), (cx - n[0] * T / 2, cy - n[1] * T / 2, z + V / 2)])
        o = T / 2 + 0.25
        inl.append([(cx + n[0] * (o - 0.5), cy + n[1] * (o - 0.5), z - 1.8), (cx + n[0] * (o + 0.5), cy + n[1] * (o + 0.5), z - 1.8),
                    (cx + n[0] * (o + 0.5), cy + n[1] * (o + 0.5), z + 1.8), (cx + n[0] * (o - 0.5), cy + n[1] * (o - 0.5), z + 1.8)])
    # 땅 밑으로 들어간 부분을 잘라 원점 위로. 그리고 전체를 올린다
    lift = 11.5
    rings = [[(x, y, z + lift) for x, y, z in r] for r in rings]
    inl = [[(x, y, z + lift) for x, y, z in r] for r in inl]
    sweep(g, "Marble", rings)
    sweep(g, "Cobalt", inl)
    rnd = random.Random(8)
    for r in (rings[0], rings[-1]):
        cx = sum(p[0] for p in r) / 4
        cy = sum(p[1] for p in r) / 4
        cz = sum(p[2] for p in r) / 4
        for j in range(4):
            g["Stone"].obox(cx + rnd.uniform(-2, 2), cy + rnd.uniform(-2, 2), max(1.5, cz + rnd.uniform(-4, 4)),
                            rnd.uniform(2, 4), rnd.uniform(2, 4), rnd.uniform(2, 4), rz=rnd.uniform(0, 3), rx=rnd.uniform(-0.5, 0.5))
    for j in range(6):   # 떨어질 때 튄 조각
        g["Marble"].obox(rnd.uniform(-20, 20), rnd.uniform(-12, 10), 0.6, rnd.uniform(1.5, 3.5), rnd.uniform(1.5, 3), 1.2,
                         rz=rnd.uniform(0, 3))


def lift_all(g, dz):
    """지은 것을 통째로 dz 올린다. 기울여 놓은 덩이가 원점 밑으로 파고들 때"""
    import bmesh
    for grp in g.values():
        bmesh.ops.translate(grp.bm, vec=(0, 0, dz), verts=grp.bm.verts)


def chunk_block(g):
    """무너진 기둥·계단 덩이 무더기. 큰 토막 둘이 기대고 계단 조각과 청화 띠 판이 섞였다"""
    rnd = random.Random(9)
    g["Marble"].obox(0, 0, 4.0, 12.0, 9.0, 8.0, rz=0.3, rx=0.25)
    g["Cobalt"].obox(0.3, -4.6, 4.8, 11.5, 0.3, 1.6, rz=0.3, rx=0.25)
    g["Marble"].obox(7.5, 3.0, 3.2, 8.0, 6.0, 6.4, rz=-0.5, ry=0.35)
    g["Stone"].obox(7.8, 3.0, 6.2, 6.0, 4.5, 0.8, rz=-0.5, ry=0.35)
    for k in range(4):
        g["Marble"].obox(-8.0 + k * 1.8, -5.0 + k * 0.4, 0.4 + k * 0.5, 2.2, 7.0, 0.8, rz=0.2)
    for j in range(8):
        g["Marble"].obox(rnd.uniform(-10, 12), rnd.uniform(-8, 8), 0.5, rnd.uniform(1, 3), rnd.uniform(1, 3), 1.0,
                         rz=rnd.uniform(0, 3))
    lift_all(g, 1.25)   # 기운 큰 토막 모서리가 원점 밑으로 1.2 들어간다. 놓을 때 땅에 조금 묻는다


def debris(g, kind):
    """코어를 도는 파편. 원점은 가운데(바닥 아님). 돌리려고 쓴다"""
    rnd = random.Random(20 + kind)
    if kind == 0:   # 갈빗대 마디
        g["Marble"].box(0, 0, 9.0, 18.0, 9.0, 17.0)
        g["Cobalt"].box(0, -4.6, 9.0, 18.0, 0.3, 3.6)
        g["Stone"].box(9.1, 0, 9.0, 0.4, 8.0, 15.0)
        for j in range(3):
            g["Stone"].obox(-9.4, rnd.uniform(-3, 3), rnd.uniform(3, 15), 2.0, 3.0, 3.0, rz=rnd.uniform(0, 3))
    elif kind == 1:   # 계단 판
        for k in range(3):
            g["Marble"].box(k * 2.9, 0, 1.0 + k * 2.0, 2.9, 10.0, 1.6)
        g["Shade"].box(2.9, 0, 0.4, 8.7, 9.0, 0.8)
    else:   # 기둥 토막
        lathe(g, "Marble", 0, 0, 0.0, [(10.0, 0.0), (9.6, 12.0)], 16)
        annulus(g, "Cobalt", (0, 0, 1.4), "z", 9.8, 10.3, 1.6, n=16)
        g["Rune"].obox(9.9, 0, 7.0, 0.5, 1.0, 5.0)


# ================================================================ 담장 난간, 부서진 상
def balustrade(g):
    """성역 가장자리 난간 한 토막(길이 40). 지방석, 동자 기둥과 하엽, 둥근 돌란대, 칸마다 풍혈 청판(청화). 두 끝 엄지"""
    from build_hanok_props import fret_panel
    Lg = 40.0
    half = Lg / 2
    g["Marble"].box(0, 0, 0.2, 1.2, Lg, 0.4)
    y0, y1 = -half + 0.5, half - 0.5
    n = 12
    bay = (y1 - y0) / n
    for k in range(n + 1):
        y = y0 + k * bay
        if k in (0, n):
            g["Marble"].box(0, y, 1.9, 0.9, 0.9, 3.0)
            lathe(g, "Gold", 0, y, 3.4, [(0.3, 0.0), (0.4, 0.15), (0.2, 0.5), (0.05, 0.65)], 8)
        else:
            g["Marble"].box(0, y, 1.3, 0.4, 0.4, 1.8)
            lathe(g, "Marble", 0, y, 2.2, [(0.18, 0.0), (0.3, 0.14), (0.4, 0.28), (0.38, 0.34)], 8)
    tube(g, "Marble", (0, y0, 2.75), (0, y1, 2.75), 0.2, seg=8)
    for k in range(n):
        ya = y0 + k * bay + (0.45 if k == 0 else 0.2)
        yb = y0 + (k + 1) * bay - (0.45 if k == n - 1 else 0.2)
        fret_panel(g, "Cobalt", ya, yb, 0.4, 1.6, 0.18)


def statue_broken(g):
    """부러진 상. 받침 위에 옷자락 끝과 두 발만 남고 허리에서 부러졌다. 떨어진 윗몸과 머리가 옆에 누웠다"""
    rnd = random.Random(11)
    g["Marble"].box(0, 0, 1.0, 7.0, 7.0, 2.0)
    g["Cobalt"].box(0, 0, 1.3, 7.1, 7.1, 0.7)
    g["Marble"].box(0, 0, 2.3, 6.2, 6.2, 0.6)
    lathe(g, "Marble", 0, 0, 2.6, [(2.6, 0.0), (2.4, 1.2), (1.9, 4.2), (1.6, 6.0)], 16)
    for k in range(10):   # 옷 주름
        a = 2 * math.pi * k / 10
        g["Marble"].obox(2.1 * math.cos(a), 2.1 * math.sin(a), 5.0, 0.45, 0.5, 5.0, rz=a, rx=0.08)
    annulus(g, "Cobalt", (0, 0, 3.2), "z", 2.35, 2.65, 0.5, n=16)
    for sx in (-1, 1):
        ellipsoid(g, "Marble", sx * 0.8, -2.4, 2.9, 0.5, 0.9, 0.35, seg=8, rings=4)
    jagged(g, 8.6, 1.6, 6, rnd, 1.4)
    # 떨어진 윗몸
    ellipsoid(g, "Marble", 5.5, 4.5, 1.2, 1.4, 2.6, 1.2, seg=10, rings=6)
    ellipsoid(g, "Marble", 5.2, 7.5, 1.0, 0.9, 0.9, 0.9, seg=10, rings=6)
    g["Cobalt"].obox(5.5, 3.2, 1.9, 2.6, 0.4, 0.3)
    tube(g, "Marble", (6.8, 3.6, 1.0), (8.4, 1.4, 0.6), 0.45, seg=8)


# ---------------------------------------------------------------- 내놓기
def job_tower_preview(g):
    tower(Sections([g]))


JOBS = [
    ("Tower_Plinth", "TwPl", tower_plinth, (140, -160, 70), (0, 0, 6)),
    ("Tower_Preview", "TwPv", job_tower_preview, (420, -520, 300), (0, 0, 250)),
    ("Col_Intact", "ColI", col_intact, (14, -18, 20), (0, 0, 18)),
    ("Col_BrokenA", "ColA", col_broken_a, (12, -16, 16), (0, 0, 10)),
    ("Col_BrokenB", "ColB", col_broken_b, (10, -12, 10), (0, 0, 4)),
    ("Col_Fallen", "ColF", col_fallen, (20, -24, 16), (0, 0, 2)),
    ("Lintel", "Lint", lintel, (20, -26, 14), (0, 0, 2)),
    ("Great_Gate", "GGate", great_gate, (60, -90, 40), (0, 0, 24)),
    ("Tholos", "Tholos", tholos, (40, -50, 30), (0, 0, 12)),
    ("Pavilion", "Pavil", pavilion, (34, -44, 26), (0, 0, 10)),
    ("Guardian", "Guard", guardian, (14, -20, 14), (0, 0, 9)),
    ("Lantern_Blue", "LantB", lantern_blue, (6, -8, 7), (0, 0, 4)),
    ("Obelisk", "Obel", obelisk, (18, -26, 20), (0, 0, 14)),
    ("Bench", "Bench", bench, (6, -8, 5), (0, 0, 1)),
    ("Cypress", "Cyp", lambda g: cypress(g, 22.0, 1), (14, -20, 14), (0, 0, 11)),
    ("Cypress_Tall", "CypT", lambda g: cypress(g, 28.0, 5), (16, -24, 16), (0, 0, 14)),
    ("Blossom", "Blos", lambda g: blossom(g, 2), (14, -18, 12), (0, 0, 7)),
    ("Blossom_B", "BlosB", lambda g: blossom(g, 7), (14, -18, 12), (0, 0, 7)),
    ("Chunk_Rib", "ChRib", chunk_rib, (40, -50, 30), (0, 0, 8)),
    ("Chunk_Block", "ChBlk", chunk_block, (24, -30, 18), (0, 0, 4)),
    ("Debris_Rib", "DebR", lambda g: debris(g, 0), (26, -34, 24), (0, 0, 9)),
    ("Debris_Step", "DebS", lambda g: debris(g, 1), (16, -20, 14), (3, 0, 3)),
    ("Debris_Drum", "DebD", lambda g: debris(g, 2), (26, -34, 24), (0, 0, 6)),
    ("Balustrade", "Balu", balustrade, (10, -30, 10), (0, 0, 1.5)),
    ("Statue_Broken", "StatB", statue_broken, (14, -18, 12), (1, 1, 4)),
]
TOWER_SECTIONS = ["Tower_S%d" % (k + 1) for k in range(N_SEC)]


def tower_section_groups():
    """합본용. 토막마다 앞머리 Tw1..Tw6"""
    gs = [G("Tw%d" % (k + 1)) for k in range(N_SEC)]
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
        L.export_model(name, g, 1.0, renders=[("corner", cam, look)], min_objs=1, palette=SPAL, tri_limit=10 ** 6)
