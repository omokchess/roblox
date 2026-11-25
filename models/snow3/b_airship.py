# -*- coding: utf-8 -*-
"""
b_airship.py — 2026-11-24 아트 3팀. 설원 마을 3판: 플레이어가 걸어 들어가 타는 비행선(옛 SnowKit.Airship 26×28×60 장식을 갈음).
계류탑 b_mast.py 꼭대기 승강장에서 옆 다리로 곤돌라 옆문(8×9)에 들어간다. 매인 자리 = lib_int3.SHIP_Y · HP.

원점 = 곤돌라 바닥 가운데(바닥 윗면 z 0), 앞 = -y(코). 로블록스 로컬 = (-x, z, y).
레퍼런스(회사/설원마을_레퍼런스.md AS 절): R100(AS1 — 16 각에 가까운 뭉툭한 코 기낭, 세로 갈빗대·고리 띠, 엔진 곤돌라 짝),
Graf Zeppelin LZ127(AS2·AS3 — 코 바로 뒤 곤돌라: 앞 조종실 큰 창 + 뒤 승객 칸, 조종실 타륜·계기·전성관), Hindenburg 식당·산책 갑판(AS4 — 창가 탁자),
카딩턴 계류탑(AS5 — 꼭대기 승강장 · 코 계류 컵 · 탑 안 승강기와 계단), 스팀펑크 비행선 게임 그림(AS6 — 매단 나무 곤돌라 · 놋쇠 띠 · 굵은 줄).
극사실주의 아님: 굵은 덩이(갈빗대 폭 0.9 · 줄 0.45 이상) + 놋쇠/구리 2단 디테일.

짜임: 기낭(16 각 천 덮개 · 짙은 천 갈빗대 16 줄 · 놋쇠 고리 띠 9 · 코 덮개 + 계류 막대 · 꼬리 끝 등)
 → 꼬리날개 넷(고정판 + 방향타/승강타, 놋쇠 경첩) → 엔진 곤돌라 넷(구리 몸 · 놋쇠 띠 · 앞 방열 살 · 배기관 · 받침대 둘 + 버팀대)
 → 곤돌라(나무 배 밑 · 벽 · 지붕) ← 굵은 쇠 막대 여덟 + 옆 X 버팀으로 기낭에 매닮.
곤돌라 안(앞 → 뒤): 조종실(타륜 · 나침반 · 기관 전령기 둘 · 계기판 · 전성관 셋 · 지도 탁자 · 종) → 승객 칸(왼 마주 보는 칸막이 자리 셋 + 탁자,
 오른 창 보는 긴 의자 둘 + 창턱 탁자, 짐 선반) → 칸막이(트인 문 8.4) → 짐칸(밧줄에 묶인 상자·통·자루·궤짝) · 뒷벽 기관실 문(닫힘).
따로 움직이는 틀(같은 원점 기준 자리는 아래 PROP_HUBS · b_airdoor.OPEN/CLOSED): 프로펠러 Sn3_AirProp × 4 · 미닫이 옆문 Sn3_AirDoor.
"""
import math

import lib as K
import lib_int2 as N
import lib_int3 as Q
from lib import bx, cbox

NAME = "Sn3_Airship"
PREFIX = "Sn3Airship"
VARIANT = "A"

# ------------------------------------------------------------------ 곤돌라 치수
GX, WT = 9.0, 1.0               # 바깥 반폭 · 벽 두께(안 너비 16)
GY0, GY1 = -24.0, 24.0          # 앞 · 뒤 바깥면(안 길이 46)
CH_Y, FX = -18.5, 5.0           # 앞 모 깎기 시작(x = ±GX) · 앞면 반폭
FLOOR_B, CEIL, WALL_TOP = -0.5, 10.8, 11.1     # 바닥 판 밑 · 천장 판 밑(안 높이 10.8, 보 밑 10.1) · 벽 윗면
ROOF_TOP = 12.5
POLY = [(-FX, GY0), (FX, GY0), (GX, CH_Y), (GX, GY1), (-GX, GY1), (-GX, CH_Y)]     # 반시계 — 변 0 앞 · 1 오른 모 · 2 오른(+x, 문) · 3 뒤 · 4 왼 · 5 왼 모
DOOR_Y0, DOOR_Y1 = -17.1, -8.5  # 문 구멍(문설주 안쪽 맑은 폭 8.0 = -16.8..-8.8)
DOOR_C = (DOOR_Y0 + DOOR_Y1) / 2
WIN_Z0, WIN_Z1 = 3.4, 8.0       # 옆 창 높이(4.6)
COCK_Z0, COCK_Z1 = 3.0, 8.6     # 조종실 창
PART_Y = 13.5                   # 승객 칸 | 짐칸 칸막이

# 옆 창 가운데(비행선 y) — 오른(+x)은 미닫이 문짝이 열려 덮는 y -8.5..0 을 비움
WIN_R = (2.6, 8.6, 18.6)
WIN_L = (-14.0, -4.4, 2.4, 9.2, 18.6)

# 엔진 곤돌라: (코에서 d, 옆 각 θ — 0 = +x, 아래로 음수), 프로펠러 축 = 비행선 y
ENGINES = [(50.0, -38.0), (50.0, 218.0), (80.0, -38.0), (80.0, 218.0)]
POD_R, POD_OUT = 3.0, 8.0
POD_STATIONS = ((-7.5, 1.6), (-6.9, 2.5), (-5.5, POD_R), (3.8, POD_R), (5.8, 2.25), (7.0, 1.3))


def _pod_center(d, th):
    D = Q.r_at(d) + POD_OUT
    a = math.radians(th)
    return (D * math.cos(a), Q.Y_TIP + d, Q.ZC + D * math.sin(a))


# 프로펠러 굴대 자리(비행선 원점 기준 x, y, z, 날개 돌림 y 축 각) — Sn3_AirProp 을 여기 놓고 비행선 y 축 둘레로 돌린다
PROP_HUBS = [(c[0], c[1] + POD_STATIONS[-1][0] + 0.75, c[2], 0.0) for c in (_pod_center(d, th) for d, th in ENGINES)]


# ================================================================== 기낭
def _stations():
    return [0.4, 1.2, 2.4, 4.0, 6.0, 8.5, 11.5, 15.0, 19.0, 24.0, 30.0, 36.0, 42.9, 50.0, 58.0, 66.0, 74.0, 82.0, 90.0,
            97.0, 103.0, 108.5, 113.5, 118.0, 121.5, 124.5, 126.8, 128.4, 129.4]


def envelope(g):
    ds = _stations()
    rings = [[Q.hull_pt(d, k) for k in range(Q.NS)] for d in ds]
    Q.loft(g, "Canvas", rings, tip0=(0.0, Q.Y_TIP, Q.ZC), tip1=(0.0, Q.Y_TIP + Q.LH, Q.ZC))
    # 갈빗대(16 줄, 짙은 천 — 꼭짓점마다 폭 0.9 · 0.35 내밈). 코·꼬리 가는 곳은 뺀다
    rd = [d for d in ds if 2.4 <= d <= 124.5]
    for k in range(Q.NS):
        a = Q.ang(k)
        ca, sa = math.cos(a), math.sin(a)
        tx, tz = -sa, ca
        rr = []
        for d in rd:
            r = Q.r_at(d)
            rr.append([((r - 0.3) * ca - tx * 0.45, Q.Y_TIP + d, Q.ZC + (r - 0.3) * sa - tz * 0.45),
                       ((r - 0.3) * ca + tx * 0.45, Q.Y_TIP + d, Q.ZC + (r - 0.3) * sa + tz * 0.45),
                       ((r + 0.35) * ca + tx * 0.38, Q.Y_TIP + d, Q.ZC + (r + 0.35) * sa + tz * 0.38),
                       ((r + 0.35) * ca - tx * 0.38, Q.Y_TIP + d, Q.ZC + (r + 0.35) * sa - tz * 0.38)])
        Q.loft(g, "CanvasDark", rr)
    # 고리 띠(놋쇠, 폭 1.2 · 0.5 내밈) — 몸 둘레 아홉
    for d in (14.0, 27.0, 40.0, 53.0, 66.0, 79.0, 92.0, 104.0, 115.0):
        r = max(Q.r_at(d - 0.6), Q.r_at(d + 0.6)) + 0.5
        ring = lambda yy: [(r * math.cos(Q.ang(k)), yy, Q.ZC + r * math.sin(Q.ang(k))) for k in range(Q.NS)]   # noqa: E731
        Q.loft(g, "Brass", [ring(Q.Y_TIP + d - 0.6), ring(Q.Y_TIP + d + 0.6)])
    # 코 덮개(쇠, 기낭보다 0.25 크게) + 코 살 8 줄 + 계류 막대(쇠 굴대 · 놋쇠 깃 · 뾰족 끝)
    nd = [0.2, 1.2, 2.4, 4.0, 5.2]
    Q.loft(g, "Iron", [[Q.hull_pt(d, k, 0.25) for k in range(Q.NS)] for d in nd], tip0=(0.0, Q.Y_TIP - 0.3, Q.ZC))
    for k in range(0, Q.NS, 2):
        a = Q.ang(k)
        p0 = Q.hull_pt(5.0, k, 0.3)
        p1 = Q.hull_pt(12.5, k, 0.3)
        Q.rod(g, "Iron", p0, p1, 0.6)
        g["Brass"].box(*Q.hull_pt(12.6, k, 0.35), 0.7, 0.7, 0.7)
    yt = Q.Y_TIP
    g["Iron"].hcyl(0.0, yt - Q.PROBE / 2, Q.ZC, 0.42, Q.PROBE + 0.6, axis="y", seg=10)
    g["Brass"].hcyl(0.0, yt - 0.55, Q.ZC, 1.05, 0.5, axis="y", seg=12)
    _cone_y(g, "Brass", 0.0, yt - Q.PROBE, Q.ZC, 0.42, 0.12, 0.6)
    # 꼬리 끝: 쇠 덮개 + 흰 꼬리등
    Q.loft(g, "Iron", [[Q.hull_pt(d, k, 0.2) for k in range(Q.NS)] for d in (126.8, 128.4, 129.4)], tip1=(0.0, Q.Y_TIP + Q.LH + 0.4, Q.ZC))
    g["Glow"].box(0.0, Q.Y_TIP + Q.LH + 0.5, Q.ZC, 0.6, 0.6, 0.6)
    # 등: 왼(-x, 로블록스 오른 = 우현) 초록빛 · 오른(+x, 좌현) 붉은빛 — 옆 면 가운데 앞쪽
    for s, mat in ((1, "Core"), (-1, "GlowTeal")):
        x = s * (Q.r_at(20.0) * math.cos(math.pi / 16) + 0.15)
        g["Brass"].box(x, Q.Y_TIP + 20.0, Q.ZC, 0.5, 1.5, 1.5)
        g[mat].box(x + s * 0.35, Q.Y_TIP + 20.0, Q.ZC, 0.4, 1.0, 1.0)
    # 등 위 가스 밸브 갓(놋쇠 다섯)
    for d in (32.0, 47.0, 62.0, 77.0, 92.0):
        z = Q.ZC + Q.r_at(d) * math.cos(math.pi / 16)
        g["Brass"].cyl(0.0, Q.Y_TIP + d, z - 0.2, 0.9, 0.9, 0.7, seg=10)
        g["Iron"].cyl(0.0, Q.Y_TIP + d, z + 0.5, 1.15, 0.6, 0.45, seg=10)
    # 이름판(양옆, d 38..56): 짙은 판 + 놋쇠 테 + 가운데 놋쇠 톱니 무늬
    for s in (1, -1):
        x = s * Q.r_at(47.0) * math.cos(math.pi / 16)
        y0, y1 = Q.Y_TIP + 39.0, Q.Y_TIP + 55.0
        bx(g, "DarkLog", *sorted((x - s * 0.2, x + s * 0.3)), y0, y1, Q.ZC - 1.7, Q.ZC + 1.7)
        bx(g, "Brass", *sorted((x - s * 0.15, x + s * 0.4)), y0 - 0.35, y1 + 0.35, Q.ZC + 1.7, Q.ZC + 2.1)
        bx(g, "Brass", *sorted((x - s * 0.15, x + s * 0.4)), y0 - 0.35, y1 + 0.35, Q.ZC - 2.1, Q.ZC - 1.7)
        for yy in (y0, y1):
            bx(g, "Brass", *sorted((x - s * 0.15, x + s * 0.4)), yy - 0.35, yy + 0.05 if yy == y0 else yy + 0.35, Q.ZC - 1.7, Q.ZC + 1.7)
        g["Brass"].hcyl(x + s * 0.45, (y0 + y1) / 2, Q.ZC, 1.15, 0.3, axis="x", seg=12)
        g["DarkLog"].hcyl(x + s * 0.55, (y0 + y1) / 2, Q.ZC, 0.55, 0.25, axis="x", seg=8)


def _cone_y(g, mat, x, y, z, r0, r1, h):
    """y 축 뿔대(y 에서 -y 쪽으로 h, 밑 r0 → 끝 r1)"""
    import bmesh
    from mathutils import Matrix
    m = Matrix.Translation((x, y - h / 2, z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    bmesh.ops.create_cone(g[mat].bm, cap_ends=True, cap_tris=False, segments=10, radius1=r1, radius2=r0, depth=h, matrix=m)


# ------------------------------------------------------------------ 꼬리날개
def fins(g):
    """십자 꼬리날개 넷: 고정판(천 + 쇠 앞전) · 경첩 줄(놋쇠) · 방향타/승강타(짙은 천). 뿌리는 기낭 속으로 0.6 묻힌 곧은 줄"""
    d0, d1, dh = 97.0, 128.0, 118.0
    s0, s1 = Q.r_at(d0) - 0.7, 0.5

    def root(d):
        return s0 + (s1 - s0) * (d - d0) / (d1 - d0)
    fixed = [(d0, root(d0)), (107.0, 20.5), (dh, 20.8), (dh, root(dh))]
    rud = [(dh + 0.35, root(dh + 0.35)), (dh + 0.35, 20.8), (124.0, 21.0), (d1, 18.4), (d1, root(d1))]
    for phi in (0.0, math.pi / 2, math.pi, 1.5 * math.pi):
        u = (math.cos(phi), math.sin(phi))
        v = (-math.sin(phi), math.cos(phi))

        def P(d, s, off):
            return (s * u[0] + off * v[0], Q.Y_TIP + d, Q.ZC + s * u[1] + off * v[1])
        for poly, mat, th in ((fixed, "Canvas", 1.0), (rud, "CanvasDark", 0.8)):
            Q.slab(g, mat, [P(d, s, -th / 2) for d, s in poly], (v[0] * th, 0.0, v[1] * th))
        # 앞전 쇠 띠(0.3 두껍게) · 바깥 끝 띠
        Q.member(g, "Iron", P(d0 + 0.4, root(d0) + 0.6, 0), P(107.0, 20.5, 0), 0.7, 1.3)
        Q.member(g, "Iron", P(107.0, 20.5, 0), P(dh, 20.8, 0), 0.6, 1.3)
        # 경첩 놋쇠 셋 + 방향타 뿔(조종줄 받이)
        for f in (0.25, 0.55, 0.85):
            s = root(dh) + (20.8 - root(dh)) * f
            c = P(dh + 0.17, s, 0)
            g["Brass"].box(c[0], c[1], c[2], 1.3, 0.8, 1.3)
        c = P(dh + 1.6, root(dh + 1.6) + 2.2, 0)
        Q.rod(g, "Brass", (c[0] - v[0] * 0.4, c[1], c[2] - v[1] * 0.4), (c[0] + v[0] * 1.4, c[1], c[2] + v[1] * 1.4), 0.4)


# ------------------------------------------------------------------ 엔진 곤돌라
def engines(g):
    for d, th in ENGINES:
        cx, cy, cz = _pod_center(d, th)
        a = math.radians(th)
        ring = lambda yy, r: [(cx + r * math.cos(2 * math.pi * (k + 0.5) / 8), yy, cz + r * math.sin(2 * math.pi * (k + 0.5) / 8)) for k in range(8)]   # noqa: E731
        Q.loft(g, "Copper", [ring(cy + yy, r) for yy, r in POD_STATIONS])
        for yy in (-5.5, -0.8, 3.8):                                     # 놋쇠 띠
            Q.loft(g, "Brass", [ring(cy + yy - 0.35, POD_R + 0.2), ring(cy + yy + 0.35, POD_R + 0.2)])
        # 앞 방열 살(쇠 판 + 가로살 넷)
        y0 = cy + POD_STATIONS[0][0]
        Q.loft(g, "Iron", [ring(y0 - 0.25, 1.45), ring(y0 + 0.05, 1.45)])
        for k in range(5):
            g["IronLight"].box(cx, y0 - 0.32, cz - 1.0 + k * 0.5, 2.1, 0.2, 0.22)
        # 뒤 굴대 받이(놋쇠) — 프로펠러(따로 도는 틀)가 여기 꽂힌다
        y1 = cy + POD_STATIONS[-1][0]
        g["Brass"].hcyl(cx, y1 + 0.25, cz, 0.75, 0.5, axis="y", seg=10)
        # 배기관 둘(바깥 위쪽, 굵게) — 기낭 반대쪽으로 꺾음
        ox, oz = math.cos(a), math.sin(a)
        for yy in (-2.0, 1.0):
            b = (cx + ox * 2.0, cy + yy, cz + 2.1)
            t = (cx + ox * 3.6, cy + yy + 1.1, cz + 3.2)
            Q.rod(g, "Iron", b, t, 0.6)
        # 창 하나(불빛) — 기관사 칸
        g["Glow"].box(cx + ox * (POD_R - 0.05), cy - 2.8, cz + 0.2, 0.3 if abs(ox) > 0.5 else 1.0, 1.2, 1.0 if abs(ox) > 0.5 else 0.3)
        # 받침대 둘(기낭 → 곤돌라, 0.7 굵기) + X 버팀 + 기낭 쪽 놋쇠 받침판
        inv = (-ox, -oz)
        for yy in (-3.2, 2.4):
            p_pod = (cx + inv[0] * (POD_R - 0.3), cy + yy, cz + inv[1] * (POD_R - 0.3))
            rr = Q.r_at(d + yy) - 0.3
            p_hull = (rr * ox, cy + yy, Q.ZC + rr * oz)
            Q.rod(g, "Iron", p_pod, p_hull, 0.7)
            g["Brass"].box(rr * ox + ox * 0.45, cy + yy, Q.ZC + rr * oz + oz * 0.45, 1.0, 1.2, 1.0)
        pa = (cx + inv[0] * (POD_R - 0.3), cy - 3.2, cz + inv[1] * (POD_R - 0.3))
        rr = Q.r_at(d + 2.4) - 0.3
        Q.rod(g, "Iron", pa, (rr * ox, cy + 2.4, Q.ZC + rr * oz), 0.5)


# ================================================================== 곤돌라 겉
def gondola_shell(g):
    holes = _holes()
    inner = Q.ring_walls(g, "Timber", POLY, WT, FLOOR_B, WALL_TOP, holes)
    # 바닥 판 · 천장 판
    Q.prism_z(g, "Timber", inner, FLOOR_B, -0.08)
    cbox(-GX, GX, GY0, GY1, FLOOR_B, 0.0)
    Q.prism_z(g, "Wood", inner, CEIL, WALL_TOP)
    # 지붕: 짙은 판(처마 0.4) → 쇠 덮개 → 가운데 등마루. 매단 쇠 막대 받이 판
    Q.prism_z(g, "DarkLog", Q.poly_inset(POLY, -0.4), WALL_TOP, WALL_TOP + 0.4)
    Q.prism_z(g, "RoofMetal", Q.poly_inset(POLY, 0.3), WALL_TOP + 0.4, WALL_TOP + 0.8)
    bx(g, "RoofMetal", -2.6, 2.6, GY0 + 5.0, GY1 - 2.0, WALL_TOP + 0.8, ROOF_TOP)
    bx(g, "Brass", -2.8, 2.8, GY0 + 4.8, GY0 + 5.2, WALL_TOP + 0.8, ROOF_TOP + 0.1)
    bx(g, "Brass", -2.8, 2.8, GY1 - 2.2, GY1 - 1.8, WALL_TOP + 0.8, ROOF_TOP + 0.1)
    cbox(-GX - 0.4, GX + 0.4, GY0, GY1, WALL_TOP, ROOF_TOP)
    # 배 밑(나무 V — 바닥 둘레에서 용골까지 좁아짐) · 놋쇠 띠 · 용골
    Q.loft(g, "Timber", [[(x, y, FLOOR_B) for x, y in Q.poly_inset(POLY, -0.15)],
                         [(x, y, -1.6) for x, y in Q.poly_inset(POLY, 1.4)],
                         [(x, y, -2.5) for x, y in Q.poly_inset(POLY, 3.4)]])
    Q.prism_z(g, "Brass", Q.poly_inset(POLY, -0.4), -0.95, FLOOR_B + 0.05)
    bx(g, "DarkLog", -0.45, 0.45, GY0 + 3.0, GY1 - 3.0, -2.9, -2.45)
    # 벽 바깥 꾸밈(오른 변 2 는 미닫이 문짝이 지나니 0.15 만 내민다)
    for i in range(len(POLY)):
        o0, e, nn, Lo = Q.edge_frame(POLY, i)
        out = -0.15 if i == 2 else -0.28
        Q.on_wall(g, "DarkLog", POLY, i, -0.1, Lo + 0.1, FLOOR_B + 0.05, 0.6, out, 0.05)              # 밑 띠
        Q.on_wall(g, "Brass", POLY, i, -0.1, Lo + 0.1, 10.2, 10.9, out, 0.05)                         # 윗 놋쇠 띠
        hs = sorted(holes.get(i, []))
        # 창 밑 띠(문 구멍에서 끊음)
        u = -0.1
        for h0, h1, hz0, hz1 in hs + [(Lo + 0.1, Lo + 0.1, 0, 0)]:
            if hz0 < 1.0 and h1 > h0:                 # 문
                Q.on_wall(g, "DarkLog", POLY, i, u, h0 - 0.4, 2.9, 3.3, out, 0.05)
                u = h1 + 0.4
            elif h1 == h0:
                Q.on_wall(g, "DarkLog", POLY, i, u, Lo + 0.1, 2.9, 3.3, out, 0.05)
        # 세로 기둥: 모서리 + 구멍 양옆
        posts = {0.45, Lo - 0.45}
        for h0, h1, hz0, hz1 in hs:
            posts |= {h0 - 0.3, h1 + 0.3}
        for p in sorted(posts):
            Q.on_wall(g, "DarkLog", POLY, i, p - 0.3, p + 0.3, 0.6, 10.2, out - 0.06, 0.05)
        # 창: 놋쇠 틀 · 가운데 살 · 유리 · 바깥 창턱 · 안 창턱 판
        for h0, h1, hz0, hz1 in hs:
            if hz0 < 1.0:
                continue
            _window(g, i, h0, h1, hz0, hz1, out)
        # 허리 밑 들인 판(밝은 나무 — 기둥 사이, 문 자리 빼고)
        ps = sorted(posts)
        for a, b in zip(ps, ps[1:]):
            if b - a < 1.6 or any(h0 < b and h1 > a and hz0 < 1.0 for h0, h1, hz0, hz1 in hs):
                continue
            Q.on_wall(g, "Wood", POLY, i, a + 0.55, b - 0.55, 0.95, 2.55, out + 0.08, 0.05)
    # 문: 쇠 문설주 · 머리 · 미닫이 문짝 레일(문 위, 뒤로 열림)
    u0, u1 = DOOR_Y0 - CH_Y, DOOR_Y1 - CH_Y
    for a, b in ((u0 - 0.05, u0 + 0.3), (u1 - 0.3, u1 + 0.05)):
        Q.on_wall(g, "Iron", POLY, 2, a, b, 0.0, 9.3, -0.1, WT + 0.1)
    Q.on_wall(g, "Iron", POLY, 2, u0 - 0.05, u1 + 0.05, 9.0, 9.35, -0.1, WT + 0.1)
    Q.on_wall(g, "Brass", POLY, 2, u0 - 0.05, u1 + 0.05, -0.02, 0.04, -0.1, WT + 0.1)          # 문지방 놋쇠 띠
    Q.on_wall(g, "Iron", POLY, 2, u0 - 0.6, u1 + 9.0, 9.45, 9.85, -0.6, 0.05)                    # 문짝 레일
    for p in (u0 - 0.4, u1 + 0.2, u1 + 8.6):
        Q.on_wall(g, "Iron", POLY, 2, p - 0.2, p + 0.2, 9.3, 10.2, -0.6, 0.05)
    Q.door_mark("y", GX - WT / 2, DOOR_C, 8.0, 9.0, 0.0, 1)
    # 앞면 놋쇠 표(창 밑)
    Q.on_wall(g, "Brass", POLY, 0, 3.2, 6.8, 1.0, 2.4, -0.3, 0.05)
    Q.on_wall(g, "DarkLog", POLY, 0, 3.45, 6.55, 1.2, 2.2, -0.42, -0.25)
    g["Brass"].hcyl(0.0, GY0 - 0.55, 1.7, 0.42, 0.2, axis="y", seg=10)
    # 뒤 기관실(밖에 붙은 쇠 칸 — 안은 막힘): 구리 몸 · 놋쇠 띠 · 둥근 창 셋 · 환기 살 · 뒤 등
    bx(g, "Iron", -5.5, 5.5, GY1 - 0.05, GY1 + 6.0, -1.6, 9.2)
    bx(g, "Copper", -5.8, 5.8, GY1 + 0.6, GY1 + 5.4, -1.3, 8.6)
    bx(g, "RoofMetal", -6.0, 6.0, GY1 - 0.05, GY1 + 6.4, 9.2, 9.8)
    for z in (1.0, 6.4):
        bx(g, "Brass", -6.0, 6.0, GY1 + 1.2, GY1 + 1.7, z, z + 0.45)
        bx(g, "Brass", -6.0, 6.0, GY1 + 4.3, GY1 + 4.8, z, z + 0.45)
    for x in (-3.2, 0.0, 3.2):
        g["Brass"].hcyl(x, GY1 + 6.05, 4.2, 0.85, 0.3, axis="y", seg=12)
        g["Glow"].hcyl(x, GY1 + 6.2, 4.2, 0.6, 0.12, axis="y", seg=12)
    for s in (-1, 1):
        for k in range(4):
            bx(g, "IronLight", *sorted((s * 5.8, s * 6.05)), GY1 + 1.9 + k * 0.6, GY1 + 2.2 + k * 0.6, 2.0, 6.0)
    g["Glow"].box(0.0, GY1 + 6.55, 8.3, 0.6, 0.3, 0.6)
    cbox(-6.0, 6.0, GY1, GY1 + 6.4, -1.6, 9.8)


def _window(g, i, h0, h1, z0, z1, out):
    """벽 구멍(변 i, u h0..h1, z0..z1)에 끼우는 창: 놋쇠 틀(벽 두께 + 0.1 씩) · 가운데 살 · 유리 · 바깥 창턱(짙은 나무) · 안 창턱 판(밝은 나무)"""
    t = WT
    f = 0.28
    for a, b in ((h0 - 0.05, h0 + f), (h1 - f, h1 + 0.05)):
        Q.on_wall(g, "Brass", POLY, i, a, b, z0, z1, -0.1, t + 0.1)
    Q.on_wall(g, "Brass", POLY, i, h0, h1, z0 - 0.05, z0 + f, -0.1, t + 0.1)
    Q.on_wall(g, "Brass", POLY, i, h0, h1, z1 - f, z1 + 0.05, -0.1, t + 0.1)
    m = (h0 + h1) / 2
    Q.on_wall(g, "Brass", POLY, i, m - 0.12, m + 0.12, z0 + f, z1 - f, 0.3, 0.7)
    Q.on_wall(g, "Brass", POLY, i, h0 + f, h1 - f, (z0 + z1) / 2 + 0.6, (z0 + z1) / 2 + 0.8, 0.3, 0.7)
    Q.on_wall(g, "WinGlass", POLY, i, h0 + f - 0.02, h1 - f + 0.02, z0 + f - 0.02, z1 - f + 0.02, 0.46, 0.54)
    Q.on_wall(g, "DarkLog", POLY, i, h0 - 0.35, h1 + 0.35, z0 - 0.35, z0 - 0.02, out - 0.05, 0.05)
    Q.on_wall(g, "Wood", POLY, i, h0 - 0.3, h1 + 0.3, z0 - 0.25, z0 + 0.02, t - 0.05, t + 0.55)


# ------------------------------------------------------------------ 매단 쇠 막대
def hangers(g):
    """곤돌라 지붕 받이(±6.5) → 기낭 아랫면(±8.6). 네 쌍 + 옆 X 버팀(굵기 0.45~0.55)"""
    ys = (-19.0, -7.0, 5.0, 17.0)
    top = {}
    for s in (-1, 1):
        for y in ys:
            d = y - Q.Y_TIP
            zh = Q.hull_low_z(d, s * 8.6) + 0.5
            top[(s, y)] = (s * 8.6, y, zh)
            Q.rod(g, "Iron", (s * 6.5, y, WALL_TOP + 0.6), top[(s, y)], 0.55)
            bx(g, "Iron", s * 6.5 - 0.6, s * 6.5 + 0.6, y - 0.6, y + 0.6, WALL_TOP + 0.75, WALL_TOP + 1.05)
            g["Brass"].box(s * 8.6, y, zh - 0.25, 1.1, 1.1, 0.8)
        for y0, y1 in zip(ys, ys[1:]):
            Q.rod(g, "Iron", (s * 6.5, y0, WALL_TOP + 0.9), top[(s, y1)], 0.4)
            Q.rod(g, "Iron", (s * 6.5, y1, WALL_TOP + 0.9), top[(s, y0)], 0.4)


# ================================================================== 곤돌라 안
# 앉는 자리(프로그래밍이 Seat 를 붙임): (블렌더 x, y, 방석 윗면 z, 보는 쪽 블렌더 방향) — 보고서에 로블록스 로컬로 옮겨 적음
BOOTHS = (-4.4, 2.4, 9.2)            # 왼(-x) 칸막이 자리 탁자 가운데 y(창 가운데와 같음)
PROM = ((-0.2, 5.4), (5.8, 11.4))    # 오른(+x) 창 보는 긴 의자 y 범위
SEAT_H = 1.75
SEATS = ([(-6.05, yt - 1.95, SEAT_H + 0.25, "+y") for yt in BOOTHS] + [(-6.05, yt + 1.95, SEAT_H + 0.25, "-y") for yt in BOOTHS]
         + [(6.15, (a + b) / 2 + s * 1.4, SEAT_H + 0.25, "+x") for a, b in PROM for s in (-1, 1)])


def _bench(q, length=3.6, depth=1.3, back_h=4.6, cushion="Banner"):
    """칸막이 긴 의자(제 좌표: 앉는 쪽 = -y, 등 = +y): 짙은 굽 · 판 몸 · 밝은 좌판 · 방석 · 높은 등 + 등 방석 · 놋쇠 윗대 · 옆판(팔걸이)"""
    hl, hd = length / 2, depth / 2
    bx(q, "DarkLog", -hl, hl, -hd, hd + 0.35, 0.0, 0.45)
    bx(q, "Timber", -hl + 0.1, hl - 0.1, -hd + 0.06, hd, 0.45, SEAT_H - 0.3)
    bx(q, "Wood", -hl, hl, -hd - 0.08, hd, SEAT_H - 0.3, SEAT_H - 0.1)
    bx(q, cushion, -hl + 0.15, hl - 0.15, -hd + 0.05, hd - 0.05, SEAT_H - 0.1, SEAT_H + 0.25)
    bx(q, "DarkLog", -hl, hl, hd, hd + 0.35, 0.45, back_h)
    bx(q, cushion, -hl + 0.2, hl - 0.2, hd - 0.22, hd + 0.02, SEAT_H + 0.4, back_h - 0.6)
    bx(q, "Brass", -hl - 0.05, hl + 0.05, hd - 0.05, hd + 0.42, back_h, back_h + 0.18)
    for s in (-1, 1):
        bx(q, "DarkLog", *sorted((s * (hl - 0.25), s * (hl + 0.05))), -hd - 0.12, hd + 0.35, 0.0, SEAT_H + 0.95)
        bx(q, "Brass", *sorted((s * (hl - 0.3), s * (hl + 0.1))), -hd - 0.17, -hd + 0.25, SEAT_H + 0.95, SEAT_H + 1.1)
    n = max(1, int(round((length - 0.7) / 1.8)))                      # 등 뒤 들인 판(밝은 나무)
    w = (length - 0.7) / n
    for k in range(n):
        a = -hl + 0.35 + k * w
        bx(q, "Wood", a + 0.12, a + w - 0.12, hd + 0.3, hd + 0.42, 0.85, back_h - 0.45)


def _wall_lamp(g, x, y, z, face_x):
    """벽 등(놋쇠 받침 · 유리 갓 · 불빛) — 벽 면 x 에 붙음, face_x = 방 쪽 부호"""
    bx(g, "Brass", *sorted((x, x + face_x * 0.15)), y - 0.35, y + 0.35, z - 0.6, z + 0.5)
    bx(g, "Brass", *sorted((x, x + face_x * 0.8)), y - 0.08, y + 0.08, z - 0.1, z + 0.06)
    g["Glass"].box(x + face_x * 0.9, y, z + 0.35, 0.55, 0.55, 0.6)
    g["Glow"].box(x + face_x * 0.9, y, z + 0.3, 0.22, 0.22, 0.35)
    g["Brass"].box(x + face_x * 0.9, y, z + 0.72, 0.7, 0.7, 0.14)


def cockpit(g):
    """조종실(앞 y -23..-17.5): 쇠 무늬판 바닥 · 앞 계기 탁(기운 계기판 다섯) · 타륜 · 나침반 · 기관 전령기 둘 · 전성관 셋 · 지도 탁자 · 종"""
    from mathutils import Matrix
    ip = Q.poly_inset(POLY, WT)
    Q.prism_z(g, "IronLight", [ip[0], ip[1], ip[2], (8.0, -17.5), (-8.0, -17.5), ip[5]], -0.08, 0.0)
    # 앞 계기 탁: 나무 몸 · 짙은 테 · 상판 + 기운 계기판(쇠, 계기 다섯 · 놋쇠 손잡이 셋 · 붉은 등)
    bx(g, "Timber", -3.9, 3.9, -22.95, -21.3, 0.0, 2.6)
    bx(g, "DarkLog", -4.0, 4.0, -21.45, -21.2, 0.0, 2.65)
    bx(g, "Wood", -4.05, 4.05, -23.0, -21.1, 2.6, 2.85)
    cbox(-4.05, 4.05, -23.0, -21.1, 0.0, 2.85)

    def board(q):
        bx(q, "IronLight", -3.7, 3.7, -0.25, 0.0, 0.0, 1.7)
        bx(q, "Brass", -3.8, 3.8, -0.3, 0.05, 1.7, 1.85)
        for k, x in enumerate((-2.8, -1.4, 0.0, 1.4, 2.8)):
            Q.gauge(q, x, 0.0, 0.95, face_y=1, r=0.5 if k != 2 else 0.62)
    K.L.transformed(g, Matrix.Translation((0.0, -21.55, 2.8)) @ Matrix.Rotation(0.55, 4, "X"), board)
    for x in (-2.1, 0.0, 2.1):
        bx(g, "Iron", x - 0.12, x + 0.12, -21.8, -21.55, 2.85, 3.05)
        Q.member(g, "Brass", (x, -21.65, 3.0), (x, -21.45, 3.75), 0.16, 0.16)
        g["Brass"].box(x, -21.45, 3.85, 0.32, 0.32, 0.32)
    g["Core"].box(3.4, -21.4, 3.0, 0.3, 0.3, 0.3)
    # 타륜(나무 테 12 조각 · 살 8 · 손잡이 · 놋쇠 통) + 받침 기둥
    hy, hz, R = -18.95, 4.4, 1.75
    bx(g, "Brass", -0.75, 0.75, -20.85, -19.35, 0.0, 0.25)
    bx(g, "DarkLog", -0.5, 0.5, -20.6, -19.6, 0.25, 3.6)
    bx(g, "Brass", -0.6, 0.6, -20.7, -19.5, 3.6, 3.85)
    bx(g, "DarkLog", -0.4, 0.4, -20.5, -19.7, 3.85, hz + 0.45)
    g["Brass"].hcyl(0.0, -19.45, hz, 0.22, 1.0, axis="y", seg=8)
    for k in range(12):
        a0, a1 = 2 * math.pi * k / 12, 2 * math.pi * (k + 1) / 12
        Q.member(g, "Wood", (R * math.cos(a0), hy, hz + R * math.sin(a0)), (R * math.cos(a1), hy, hz + R * math.sin(a1)), 0.34, 0.34)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        Q.member(g, "Wood", (0.3 * math.cos(a), hy, hz + 0.3 * math.sin(a)), (2.25 * math.cos(a), hy, hz + 2.25 * math.sin(a)), 0.24, 0.24)
        g["Wood"].box(2.45 * math.cos(a), hy, hz + 2.45 * math.sin(a), 0.38, 0.38, 0.38)
    g["Brass"].hcyl(0.0, hy, hz, 0.5, 0.45, axis="y", seg=10)
    cbox(-2.5, 2.5, -20.9, -18.7, 0.0, 6.8)
    # 나침반 받침(놋쇠 기둥 · 그릇 · 유리 덮개 · 쇠공 둘)
    bx(g, "DarkLog", -3.15, -2.05, -20.75, -19.65, 0.0, 0.3)
    g["Brass"].cyl(-2.6, -20.2, 0.3, 0.42, 0.32, 2.7, seg=10)
    g["Brass"].cyl(-2.6, -20.2, 3.0, 0.85, 0.85, 0.5, seg=12)
    g["Glass"].cyl(-2.6, -20.2, 3.5, 0.7, 0.3, 0.45, seg=12)
    for s in (-1, 1):
        bx(g, "Brass", -2.6 + s * 0.85, -2.6 + s * 1.15, -20.3, -20.1, 3.1, 3.3)
        g["Iron"].box(-2.6 + s * 1.35, -20.2, 3.2, 0.5, 0.5, 0.5)
    cbox(-3.2, -2.0, -20.8, -19.6, 0.0, 3.9)
    # 기관 전령기 둘(놋쇠 기둥 · 둥근 머리 + 흰 판 · 손잡이)
    for x in (2.55, 3.85):
        bx(g, "DarkLog", x - 0.45, x + 0.45, -20.65, -19.75, 0.0, 0.3)
        g["Brass"].cyl(x, -20.2, 0.3, 0.3, 0.26, 3.0, seg=8)
        g["Iron"].hcyl(x, -20.2, 3.9, 0.75, 0.55, axis="y", seg=14)
        g["Dial"].hcyl(x, -19.88, 3.9, 0.6, 0.12, axis="y", seg=14)
        Q.member(g, "Brass", (x, -19.75, 3.9), (x + 0.35, -19.7, 4.85), 0.16, 0.16)
        g["Brass"].box(x + 0.38, -19.7, 4.95, 0.34, 0.34, 0.34)
    cbox(2.05, 4.35, -20.7, -19.7, 0.0, 4.7)
    # 전성관 셋(오른 앞 모 — 바닥에서 올라와 놋쇠 나팔)
    for k, (x, y) in enumerate(((6.9, -18.9), (6.3, -19.75), (5.7, -20.6))):
        zt = 4.6 + 0.35 * k
        g["Brass"].cyl(x, y, 0.0, 0.2, 0.2, zt, seg=8)
        g["Brass"].cyl(x, y, zt, 0.22, 0.6, 0.75, seg=10)
        g["DarkLog"].cyl(x, y, zt + 0.75, 0.5, 0.5, 0.06, seg=10)
        for z in (1.2, 3.0):
            bx(g, "Iron", x - 0.3, x + 0.3, y - 0.3, y + 0.3, z, z + 0.2)
    cbox(5.3, 7.4, -21.0, -18.5, 0.0, 6.0)
    # 지도 탁자(왼 벽, 창 밑) + 지도 · 놋쇠 디바이더 · 만 지도 · 펼친 책 · 위 등
    N.put(g, -6.3, -14.0, 0.0, math.pi / 2, N.table, 5.0, 3.0, 3.0)
    cbox(-7.8, -4.8, -16.5, -11.5, 0.0, 3.0)
    g["Canvas"].obox(-6.3, -14.2, 3.03, 2.5, 3.9, 0.06, rz=0.06)
    g["Paint"].obox(-6.0, -14.6, 3.07, 1.4, 1.8, 0.03, rz=0.06)
    for k, (a, b) in enumerate((((-6.9, -15.4), (-5.6, -13.6)), ((-5.6, -13.6), (-6.4, -12.6)))):
        Q.member(g, "Banner", (a[0], a[1], 3.11), (b[0], b[1], 3.11), 0.14, 0.04)
    Q.member(g, "Brass", (-5.6, -13.2, 3.1), (-6.3, -15.0, 3.12), 0.12, 0.08)
    Q.member(g, "Brass", (-5.6, -13.2, 3.1), (-5.2, -15.0, 3.12), 0.12, 0.08)
    g["Canvas"].hcyl(-7.2, -12.3, 3.25, 0.25, 1.9, axis="x", seg=8)
    N.book(g, -5.4, -11.95, 3.0, 0.7, 0.9, 0.2, "Leather", "Canvas", open_=True)
    Q.lamp_hang(g, -6.3, -14.0, 10.1, 7.3)
    # 배의 종(천장 보에 매단 놋쇠 종 + 종 줄)
    bx(g, "DarkLog", 1.2, 2.4, -16.25, -15.75, 9.6, 10.1)
    g["Brass"].cyl(1.8, -16.0, 8.55, 0.6, 0.32, 0.85, seg=12)
    g["Brass"].cyl(1.8, -16.0, 9.4, 0.18, 0.18, 0.2, seg=8)
    Q.rod(g, "Canvas", (1.8, -16.0, 8.55), (1.8, -16.0, 6.9), 0.16)
    K.NPC(0.0, -17.2, 0.0, 0.0)                  # 조종사(타륜 뒤, 앞을 봄)


def cabin(g):
    """승객 칸(y -8..13): 왼 칸막이 자리 셋(마주 보는 긴 의자 + 탁자 + 접시·잔·작은 등) · 오른 창 보는 긴 의자 둘 + 창턱 탁자 · 위 짐 선반 + 궤짝 · 깔개 · 그림 · 등 둘"""
    for yt in BOOTHS:
        N.put(g, -6.05, yt - 1.95, 0.0, math.pi, _bench)
        N.put(g, -6.05, yt + 1.95, 0.0, 0.0, _bench)
        cbox(-7.95, -4.1, yt - 2.95, yt - 1.2, 0.0, 4.8)
        cbox(-7.95, -4.1, yt + 1.2, yt + 2.95, 0.0, 4.8)
        N.put(g, -6.3, yt, 0.0, 0.0, N.table, 3.0, 1.6, 2.8)
        cbox(-7.8, -4.8, yt - 0.8, yt + 0.8, 0.0, 2.8)
        for s in (-1, 1):
            N.plate(g, -5.8, yt + s * 0.45, 2.8, 0.42, "Paint", "Wood" if s < 0 else None)
            N.mug(g, -5.1, yt + s * 0.5, 2.8)
        g["Brass"].cyl(-7.3, yt, 2.8, 0.3, 0.22, 0.25, seg=8)              # 탁자 등
        g["Brass"].cyl(-7.3, yt, 3.05, 0.08, 0.08, 0.9, seg=6)
        g["Glow"].cyl(-7.3, yt, 3.85, 0.42, 0.22, 0.5, seg=8)
    for a, b in PROM:
        N.put(g, 6.15, (a + b) / 2, 0.0, math.pi / 2, _bench, b - a, 1.3, 3.6, "Leather")
        cbox(4.9, 7.0, a - 0.05, b + 0.05, 0.0, 3.8)
        bx(g, "Wood", 7.0, 7.95, a + 0.2, b - 0.2, 2.75, 2.95)             # 창턱 탁자
        for y in (a + 1.0, b - 1.0):
            Q.member(g, "DarkLog", (7.9, y, 1.7), (7.15, y, 2.72), 0.25, 0.25)
        N.mug(g, 7.45, (a + b) / 2 - 1.4, 2.95)
        N.mug(g, 7.45, (a + b) / 2 + 1.1, 2.95)
    # 짐 선반(양 벽, 창 위) — 놋쇠 막대 넷 + 까치발 + 궤짝·가방
    for s in (-1, 1):
        y0, y1 = -7.2, 12.6
        for x in (7.95, 7.5, 7.05, 6.6):
            bx(g, "Brass", *sorted((s * (x - 0.09), s * (x + 0.09))), y0, y1, 8.75, 8.93)
        bx(g, "Brass", *sorted((s * 6.45, s * 6.7)), y0, y1, 8.93, 9.25)
        for y in (y0 + 0.4, (y0 + y1) / 2, y1 - 0.4):
            Q.member(g, "DarkLog", (s * 7.95, y, 7.7), (s * 6.6, y, 8.75), 0.22, 0.22)
            bx(g, "DarkLog", *sorted((s * 7.95, s * 7.6)), y - 0.15, y + 0.15, 7.5, 8.75)
    for x, y, rz, w in ((-7.25, -3.0, math.pi / 2, 2.4), (-7.25, 6.0, math.pi / 2, 1.8), (7.25, 1.5, -math.pi / 2, 2.2), (7.25, 9.8, -math.pi / 2, 2.0)):
        N.put(g, x, y, 8.93, rz, N.trunk, w, 1.1, 0.9)
    # 깔개(통로) · 그림(오른 벽, 문짝 뒤) · 벽 등 · 매단 등
    N.put(g, 0.6, 2.5, 0.0, 0.0, N.rug, 3.4, 17.0)
    N.put(g, 7.88, -4.4, 4.2, -math.pi / 2, N.painting, 4.4, 3.0)
    for y in (-0.9, 5.8):
        _wall_lamp(g, -7.88, y, 6.2, 1)
    for y in (-3.0, 7.0):
        Q.lamp_hang(g, 0.0, y, 10.1, 8.0)


def partition(g):
    """승객 칸 | 짐칸 칸막이(y 13.5, 두께 0.6): 양옆 판벽 + 트인 문 8.4(짙은 기둥 · 머리보) · 그림 · 놋쇠 벽시계"""
    y0, y1 = PART_Y - 0.3, PART_Y + 0.3
    for s in (-1, 1):
        bx(g, "Timber", *sorted((s * 4.8, s * 7.95)), y0, y1, 0.0, CEIL)
        cbox(*sorted((s * 4.2, s * 7.95)), y0, y1, 0.0, CEIL)
        bx(g, "DarkLog", *sorted((s * 4.2, s * 4.85)), y0 - 0.1, y1 + 0.1, 0.0, 10.1)
        bx(g, "Wood", *sorted((s * 4.85, s * 7.85)), y0 - 0.12, y0 + 0.05, 0.0, 3.0)
        bx(g, "Wood", *sorted((s * 4.85, s * 7.85)), y1 - 0.05, y1 + 0.12, 0.0, 3.0)
        bx(g, "DarkLog", *sorted((s * 4.85, s * 7.85)), y0 - 0.2, y1 + 0.2, 2.95, 3.25)
    bx(g, "DarkLog", -4.85, 4.85, y0 - 0.1, y1 + 0.1, 9.2, 10.1)
    bx(g, "Brass", -4.2, 4.2, y0 - 0.15, y0 - 0.05, 9.2, 9.4)
    N.put(g, -6.3, y0 - 0.0, 4.4, 0.0, N.painting, 2.6, 2.4)
    g["Brass"].hcyl(6.3, y0 - 0.12, 6.4, 0.95, 0.24, axis="y", seg=16)
    g["Dial"].hcyl(6.3, y0 - 0.26, 6.4, 0.78, 0.06, axis="y", seg=16)
    Q.member(g, "Iron", (6.3, y0 - 0.32, 6.4), (6.3, y0 - 0.32, 6.95), 0.1, 0.06)
    Q.member(g, "Iron", (6.3, y0 - 0.32, 6.4), (6.65, y0 - 0.32, 6.25), 0.1, 0.06)


def cargo(g):
    """짐칸(y 13.8..23): 밧줄로 묶은 상자 더미 · 통 셋(둘레 밧줄) · 팔레트 위 자루 · 궤짝 · 감은 밧줄 · 뒷벽 기관실 문(닫힘) + 관 · 압력계 · 등"""
    yb = GY1 - WT
    # 왼: 상자 더미 + 묶음 띠 둘 + 바닥 고리
    for y in (19.1, 21.6):
        N.put(g, -6.5, y, 0.0, 0.0, N.crate, 2.4, 2.3, 2.0)
    N.put(g, -6.5, 20.35, 2.0, 0.15, N.crate, 2.0, 2.0, 1.7)
    cbox(-7.8, -5.2, 17.9, 22.8, 0.0, 3.7)
    for y in (19.1, 21.6):
        bx(g, "CanvasDark", -5.3, -5.1, y - 0.14, y + 0.14, 0.0, 2.08 if y > 20.35 + 1.0 else 3.78)
        bx(g, "CanvasDark", -7.7, -5.1, y - 0.14, y + 0.14, 2.0 if y > 20.35 + 1.0 else 3.7, 2.08 if y > 20.35 + 1.0 else 3.78)
        bx(g, "Brass", -5.05, -4.75, y - 0.25, y + 0.25, 0.0, 0.25)
    # 왼 앞: 팔레트 + 자루 셋
    N.put(g, -6.3, 15.6, 0.0, 0.0, N.pallet, 2.6, 2.0)
    for x, y, r in ((-6.9, 15.1, 0.2), (-5.8, 15.3, -0.4), (-6.4, 16.1, 0.9)):
        N.put(g, x, y, 0.45, r, N.sack, 0.85)
    cbox(-7.6, -5.0, 14.6, 16.6, 0.0, 2.2)
    # 오른: 선 통 셋 + 둘레 밧줄(굵게) + 벽 고리
    for y in (17.3, 19.6, 21.9):
        N.put(g, 6.6, y, 0.0, 0.0, N.barrel, 0.95, 2.5)
    cbox(5.6, 7.6, 16.3, 22.9, 0.0, 2.6)
    for x0, x1, y0, y1 in ((5.4, 7.8, 16.05, 16.35), (5.4, 7.8, 22.75, 22.95), (5.4, 5.7, 16.05, 22.95)):
        bx(g, "CanvasDark", x0, x1, y0, y1, 1.4, 1.8)
    for y in (16.9, 22.4):
        bx(g, "Brass", 7.85, 8.0, y - 0.25, y + 0.25, 1.3, 1.9)
    # 오른 앞: 궤짝 둘(쌓음)
    N.put(g, 6.4, 14.9, 0.0, -math.pi / 2, N.trunk, 2.2, 1.3, 1.4)
    N.put(g, 6.4, 14.9, 2.05, -math.pi / 2 + 0.12, N.trunk, 1.8, 1.1, 1.1)
    cbox(5.6, 7.2, 13.9, 16.0, 0.0, 3.4)
    # 감은 밧줄(바닥, 충돌 없음)
    K.S.ring(g, "CanvasDark", -3.2, 22.1, 0.0, 0.25, 0.75, 0.3, n=12)
    K.S.ring(g, "CanvasDark", -3.2, 22.1, 0.3, 0.3, 0.7, 0.28, n=12)
    # 뒷벽 기관실 문(닫힘 — 쇠 판 · 테 · 리벳 띠 · 둥근 불빛 창 · 바퀴 손잡이 · 놋쇠 이름판)
    bx(g, "IronLight", -2.6, 2.6, yb - 0.2, yb + 0.05, 0.0, 8.3)
    bx(g, "Iron", -2.1, 2.1, yb - 0.32, yb - 0.1, 0.0, 7.8)
    for z in (1.0, 3.9, 6.6):
        bx(g, "IronLight", -2.0, 2.0, yb - 0.42, yb - 0.25, z, z + 0.35)
    g["Brass"].hcyl(0.0, yb - 0.4, 5.6, 0.75, 0.2, axis="y", seg=12)
    g["Glow"].hcyl(0.0, yb - 0.48, 5.6, 0.55, 0.1, axis="y", seg=12)
    g["Brass"].hcyl(1.2, yb - 0.45, 3.2, 0.5, 0.12, axis="y", seg=12)
    for k in range(3):
        a = k * math.pi / 3
        g["Brass"].obox(1.2, yb - 0.5, 3.2, 1.0, 0.1, 0.12, ry=a)
    bx(g, "Brass", -1.4, 1.4, yb - 0.3, yb - 0.1, 8.4, 9.0)
    # 관(구리, 문 왼쪽 → 천장) · 압력계 · 밸브 바퀴
    K.S.pipe(g, [(-3.6, yb - 0.5, 0.0), (-3.6, yb - 0.5, 9.3), (-7.3, yb - 0.5, 9.3)], 0.28, mat="Copper")
    Q.gauge(g, 3.6, yb, 5.2, face_y=-1, r=0.62)
    g["Iron"].hcyl(-3.6, yb - 1.0, 3.0, 0.5, 0.12, axis="y", seg=12)
    g["Iron"].hcyl(-3.6, yb - 0.8, 3.0, 0.12, 0.35, axis="y", seg=8)
    Q.lamp_hang(g, 0.0, 18.5, 10.1, 8.0)


def interior(g):
    ip = Q.poly_inset(POLY, WT)
    N.plank_floor(g, -8.0, 8.0, -17.5, GY1 - WT, -0.08, along="y")
    # 천장 보(짙은 나무, 4 간격) · 천장 구리 관(왼 위 모서리, 앞 → 뒤)
    for y in range(-16, 23, 4):
        bx(g, "DarkLog", -8.05, 8.05, y - 0.35, y + 0.35, 10.1, CEIL + 0.02)
    K.S.pipe(g, [(-7.35, -17.0, 9.6), (-7.35, 22.5, 9.6)], 0.25, mat="Copper")
    # 벽 안 꾸밈: 허리 판(밝은 나무) · 허리 띠 · 창 양옆 짙은 기둥(옆 벽 · 뒷벽)
    for i in (2, 3, 4):
        o0, e, nn, Lo = Q.edge_frame(POLY, i)
        hs = sorted([(u0, u1) for u0, u1, za, zb in _holes().get(i, []) if za < 1.0])
        u = 0.6
        for a, b in hs + [(Lo - 0.6, Lo - 0.6)]:
            if a - u > 0.2:
                Q.on_wall(g, "Wood", POLY, i, u, a, 0.0, 2.95, WT - 0.05, WT + 0.12)
                Q.on_wall(g, "DarkLog", POLY, i, u, a, 2.95, 3.25, WT - 0.05, WT + 0.22)
            u = b
        for a, b, za, zb in _holes().get(i, []):
            if za < 1.0:
                continue
            for p in (a - 0.35, b + 0.35):
                Q.on_wall(g, "DarkLog", POLY, i, p - 0.3, p + 0.3, 0.0, 10.1, WT - 0.05, WT + 0.3)
    cockpit(g)
    cabin(g)
    partition(g)
    cargo(g)


def _holes():
    return {
        0: [(1.5, 8.5, COCK_Z0, COCK_Z1)],
        1: [(1.3, 5.5, COCK_Z0, COCK_Z1)],
        5: [(1.3, 5.5, COCK_Z0, COCK_Z1)],
        2: [(DOOR_Y0 - CH_Y, DOOR_Y1 - CH_Y, 0.0, 9.3)] + [(y - 2.0 - CH_Y, y + 2.0 - CH_Y, WIN_Z0, WIN_Z1) for y in WIN_R],
        4: [(GY1 - y - 2.0, GY1 - y + 2.0, WIN_Z0, WIN_Z1) for y in WIN_L],
    }


def build(g):
    envelope(g)
    fins(g)
    engines(g)
    gondola_shell(g)
    hangers(g)
    interior(g)


INFO = {
    "variant": VARIANT,
    "floor": 0.0,
    "door_side": "+x(블렌더) = 로블록스 -X(좌현)",
    "hole_seeds": [(0.0, -18.0, 4.5), (0.0, 0.0, 4.5), (0.0, 18.0, 4.5)],
}
