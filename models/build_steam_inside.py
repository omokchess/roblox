# -*- coding: utf-8 -*-
"""
build_steam_inside.py — 2026-10-10. 슈네라이히 "들어가는 건물" 1묶음(사용자: 천문대처럼 순간이동 말고 건물 자체에 인테리어).

옛 키트(build_steam.py)의 겉모양을 그대로 살리되 벽을 속 빈 껍데기로 바꾸고, 문 자리를 열고, 안을 새로 짓는다.
  Frostig_Werk   장비상점(프로스티히 공방): 판매대·권총 진열장·장총 걸이·화덕과 모루·작업대·갑옷 진열대
  Zapfen_Werk    슈네라이히 공방(차펜): 톱날 지붕 작업장 — 압착기(움직이는 것을 옮겨 옴)·운반대·보일러 둘·특허 금고·사무실 중이층·도는 큰 톱니
  Figuren_HQ     체스판 건물(기물군 본부): 체스판 바닥 큰 홀·큰 체스 말·기둥·깃발·단상·작전 탁자·영사기·샹들리에, 탑 속 시계 장치와 큰 추
  Sel_Werk_Ruin  설 공방 폐허: 무너진 선반·탄 상자·그을린 시제품·떨어진 샹들리에·재 더미와 불씨
  (2·3묶음) Shop_Blue 잡화 · Shop_Teal 물약 · Shop_Red 강화소 · Ticket_Booth 비행선 표 · Inn_House 선술집·접수 ·
  Casino_Hall 카지노(둥근 천장 홀) + 경매장(옆 동) · Steam_Factory 공장(조립 운반대·증기 망치·기중기)
크기는 마을에 놓이는 최종 크기(배율 1)로 짓는다(옛 배율 Zapfen 1.3 · Figuren 1.2 · Sel 1.3 은 겉모양에 구워 넣었다).

걷기: 보이는 메시는 마을 빌더가 부딪히지 않게 하고, 여기서 적은 상자(COLL)로 벽·바닥·계단·가구를 세운다.
키트 소품(장총·화덕·체스 말·톱니…)은 PROPS 로 자리만 적고 빌더가 복제해 놓는다. → tools/Snow_Inside_data.luau
좌표: 블렌더 (x, y, z), 앞 = -y. 로블록스 로컬 = (-x, z, y), 상자 크기 (sx, sz, sy), 수평 돌림(rz 도)은 그대로 yaw.
"""
import math
import os
import sys

from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
from build_steam_obs import sphere, sweep  # noqa: E402

R = math.radians
COLL, PROPS, LAMPS = {}, {}, {}
_cur = [None]


def C(cx, cy, cz, sx, sy, sz, rz=0.0):
    """걸을 때 부딪히는 상자(블렌더 좌표, rz 라디안)"""
    COLL[_cur[0]].append((cx, cy, cz, sx, sy, sz, rz))


def PROP(kit, x, y, z, yaw=0.0, sc=1.0, rot=(0, 0, 0), speed=None, col=None):
    """키트 소품 자리(블렌더 좌표, yaw 도). rot = 로블록스 로컬 회전(도) 덧붙임. speed = 도는 톱니(도/초). col = 재질로 다시 칠함"""
    PROPS[_cur[0]].append((kit, x, y, z, yaw, sc, rot, speed, col))


def job(name, fn):
    def run(g):
        _cur[0] = name
        COLL[name], PROPS[name] = [], []
        fn(g)
        # 등 표지(LampPt 상자)가 한 메시로 합쳐지면 빛이 건물 가운데 하나만 생긴다 → 상자마다 자리를 뽑아 따로 빛을 달고 메시는 비운다
        vs = [v.co.copy() for v in g["LampPt"].bm.verts]
        assert len(vs) % 8 == 0, (name, len(vs))
        LAMPS[name] = [sum(vs[i + 1:i + 8], vs[i]) / 8 for i in range(0, len(vs), 8)]
        g["LampPt"].bm.clear()
    return run


def box2(g, mat, x0, x1, y0, y1, z0, z1, coll=True):
    """끝점으로 상자"""
    g[mat].box((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)
    if coll:
        C((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)


def wall_door(g, mat, x0, x1, y0, y1, z0, z1, dx0, dx1, dz1, coll=True):
    """x 로 뻗은 벽에 문 구멍(dx0..dx1, z0..dz1)"""
    box2(g, mat, x0, dx0, y0, y1, z0, z1, coll)
    box2(g, mat, dx1, x1, y0, y1, z0, z1, coll)
    box2(g, mat, dx0, dx1, y0, y1, dz1, z1, coll)


def scaled(g, k, fn):
    """옛 좌표로 지은 겉모양을 k 배로"""
    L.transformed(g, Matrix.Scale(k, 4), fn)


def lantern(g, x, y, ztop, zl, lamp=True):
    """매단 등: 사슬 + 놋쇠 갓 + 불빛 + 무쇠 밑"""
    g["Iron"].cyl(x, y, zl + 0.8, 0.06, 0.06, ztop - zl - 0.8, seg=6)
    g["Brass"].box(x, y, zl + 0.75, 1.4, 1.4, 0.3)
    g["Glow"].box(x, y, zl, 0.9, 0.9, 1.2)
    g["Iron"].box(x, y, zl - 0.7, 1.1, 1.1, 0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].box(x + sx * 0.5, y + sy * 0.5, zl, 0.12, 0.12, 1.3)
    if lamp:
        g["LampPt"].box(x, y, zl, 0.3, 0.3, 0.3)


def armor_stand(g, x, y, z0, face_rz=0.0):
    """갑옷 진열대(무쇠 흉갑·놋쇠 어깨·투구, 가슴에 압력계)"""
    c, s = math.cos(face_rz), math.sin(face_rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g["Iron"].cyl(x, y, z0, 0.75, 0.75, 0.3, seg=12)
    g["Iron"].cyl(x, y, z0 + 0.3, 0.12, 0.12, 4.0, seg=8)
    g["Iron"].obox(*P(0, 0), z0 + 4.0, 1.7, 0.9, 2.2, rz=face_rz)
    g["Iron"].obox(*P(0, 0), z0 + 2.75, 1.4, 0.8, 0.5, rz=face_rz)
    for su in (-1, 1):
        sphere(g, "Brass", (*P(su * 1.0, 0), z0 + 4.9), 0.5, sub=1)
    sphere(g, "Iron", (x, y, z0 + 5.9), 0.58, sub=2)
    g["Glow"].obox(*P(0, -0.5), z0 + 5.95, 0.7, 0.1, 0.16, rz=face_rz)
    g["Brass"].obox(*P(0, -0.47), z0 + 4.3, 0.55, 0.12, 0.55, rz=face_rz)
    C(x, y, z0 + 3.1, 1.8, 1.8, 6.2)


# =========================================================================== 장비상점(프로스티히 공방)
def frostig_in(g):
    W, D, T = 24.0, 18.0, 0.8
    fy = -D / 2
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T
    ZF, ZC = 1.7, 11.4
    # 받침·바닥
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    C(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Timber"].box(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)
    C(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)
    # 벽(아래층 속 빔): 뒤·왼·오른 + 앞(문 x -8..-4, 높이 8)
    box2(g, "Brick", -W / 2, W / 2, iy1, D / 2, 1.5, 12.0)
    box2(g, "Brick", -W / 2, ix0, iy0, iy1, 1.5, 12.0)
    box2(g, "Brick", ix1, W / 2, iy0, iy1, 1.5, 12.0)
    wall_door(g, "Brick", -W / 2, W / 2, -D / 2, iy0, 1.5, 12.0, -8.0, -4.0, 9.7)
    g["Wood"].box(0, 0, 11.7, W - 2 * T, D - 2 * T, 0.6)                    # 안 천장(나무)
    for y in (-4.5, 0.0, 4.5):
        g["Iron"].box(0, y, 11.2, W - 2 * T, 0.5, 0.4)
    # 위층(겉만, 속 찬 덩이) + 지붕 — 옛 frostig 그대로
    g["StoneTrim"].box(0, 0, 12.3, W + 1.0, D + 1.0, 0.6)
    g["BrickDark"].box(0, -0.3, 12.6 + 4.5, W + 0.4, D + 0.6, 9.0)
    g["StoneTrim"].box(0, -0.3, 21.4, W + 1.4, D + 1.4, 0.6)
    S.roof_gable(g, 0, -0.3, 21.7, D + 0.6, W + 0.4, 8.0, along="x")
    # 진열창(밖·안) — 안쪽도 같은 자리에 불빛 판과 쇠살
    SX, SW, SH = 4.5, 10.0, 5.2
    g["Glow"].box(SX, fy - 0.1 - S.WIN_OUT, 3.3 + SH / 2, SW, 0.2, SH)
    g["Glow"].box(SX, iy0 + 0.2, 3.3 + SH / 2, SW, 0.2, SH)
    for yy, d in ((fy - 0.3, 1), (iy0 + 0.35, -1)):
        g["Brass"].box(SX, yy, 3.3 + SH + 0.2, SW + 0.8, 0.4, 0.4)
        g["Brass"].box(SX, yy, 3.3 - 0.2, SW + 0.8, 0.4, 0.4)
        for k in range(4):
            g["Iron"].box(SX - SW / 2 + k * SW / 3, yy, 3.3 + SH / 2, 0.3, 0.4, SH)
    g["StoneTrim"].box(SX, fy - 0.5, 2.8, SW + 1.2, 1.0, 0.5)
    g["Banner"].obox(SX, fy - 1.6, 10.3, SW + 1.2, 3.4, 0.25, rx=-0.45)
    # 문틀(돌) + 안으로 연 문짝
    for x in (-8.45, -3.55):
        g["StoneTrim"].box(x, fy - 0.3, 1.5 + 4.1, 0.9, 0.8, 8.2)
    g["StoneTrim"].box(-6.0, fy - 0.3, 10.1, 5.8, 0.8, 0.8)
    g["Stone"].box(-6.0, fy - 1.0, 0.75, 5.4, 2.0, 1.5)
    g["Stone"].box(-6.0, fy - 2.6, 0.375, 5.4, 1.2, 0.75)
    C(-6.0, fy - 1.0, 0.75, 5.4, 2.0, 1.5)
    C(-6.0, fy - 2.6, 0.375, 5.4, 1.2, 0.75)
    hx, hy, ang = -7.9, iy0 + 0.2, R(100)
    cxl, cyl = hx + math.cos(ang) * 1.95, hy + math.sin(ang) * 1.95
    g["Timber"].obox(cxl, cyl, 1.7 + 3.9, 3.9, 0.3, 7.8, rz=ang)
    for zz in (2.6, 5.6, 8.6):
        g["Iron"].obox(cxl - math.sin(ang) * 0.2, cyl + math.cos(ang) * 0.2, zz, 3.95, 0.08, 0.35, rz=ang)
    # 겉 장식: 총 간판·이층 창·지붕창·대장간 굴뚝·옆 헛간·뒤 박공 톱니·뒤 창 — 옛 frostig 그대로
    g["Iron"].box(-1.2, fy - 1.6, 11.2, 0.35, 3.2, 0.35)
    g["Brass"].box(-1.2, fy - 2.9, 9.3, 0.3, 2.6, 3.0)
    g["Iron"].box(-1.4, fy - 2.9, 9.8, 0.3, 4.6, 0.35)
    g["Timber"].obox(-1.4, fy - 1.6, 9.2, 0.35, 1.8, 0.9, rx=0.3)
    for x in (-7.0, 0.0, 7.0):
        S.window(g, x, fy - 0.6, 14.5, 2.6, 3.8)
    for x in (-5.0, 5.0):
        g["BrickDark"].box(x, fy + 2.4, 25.0, 3.6, 3.0, 3.6)
        g["RoofMetal"].obox(x, fy + 2.2, 27.3, 4.6, 3.6, 0.4, rx=-0.3)
        g["Glow"].box(x, fy + 0.85, 24.8, 2.2, 0.2, 2.4)
    cx = W / 2 + 1.6
    g["Brick"].box(cx, 3.0, 1.5 + 14.5, 3.2, 3.2, 29.0)
    C(cx, 3.0, 1.5 + 14.5, 3.2, 3.2, 29.0)
    g["StoneTrim"].box(cx, 3.0, 20.0, 3.8, 3.8, 0.6)
    g["Core"].box(cx, 3.0, 30.7, 2.6, 2.6, 0.5)
    g["Iron"].box(cx, 3.0, 31.2, 3.6, 3.6, 0.5)
    S.vent(g, cx, 3.0, 32.0)
    hxx = -W / 2 - 4.0
    g["Stone"].box(hxx, 0, 0.5, 8.0, 12.0, 1.0)
    C(hxx, 0, 0.5, 8.0, 12.0, 1.0)
    for y in (-5.5, 5.5):
        g["Timber"].box(hxx - 3.4, y, 5.5, 0.6, 0.6, 9.0)
        C(hxx - 3.4, y, 5.5, 0.6, 0.6, 9.0)
    g["RoofMetal"].obox(hxx, 0, 10.4, 9.0, 13.0, 0.4, ry=0.25)
    g["SnowCap"].obox(hxx + 0.2, 0, 10.8, 8.0, 12.4, 0.4, ry=0.25)
    g["Timber"].cyl(hxx, -2.0, 1.0, 1.1, 1.1, 2.4, seg=10)
    g["Iron"].box(hxx, -2.0, 3.8, 1.2, 2.8, 0.8)
    C(hxx, -2.0, 2.4, 1.6, 2.8, 2.8)
    g["Timber"].box(hxx - 1.0, 3.5, 3.4, 3.0, 5.0, 0.4)
    for y in (1.4, 5.6):
        for x in (-2.2, 0.2):
            g["Timber"].box(hxx + x, y, 1.9, 0.4, 0.4, 2.8)
    C(hxx - 1.0, 3.5, 2.3, 3.0, 5.0, 2.6)
    S.gear(g, "Brass", 0, D / 2 + 0.3, 16.0, 2.2, 10, 0.5)
    for x in (-6.0, 6.0):
        S.window(g, x, D / 2, 4.0, 2.4, 3.4, face="+y")
        S.window(g, x, iy1, 4.0, 2.4, 3.4, face="-y", sill=False)
    # ── 안 ──
    g["Banner"].box(-6.0, -4.8, ZF + 0.03, 3.6, 4.2, 0.06)                   # 들어오는 깔개
    # 판매대 + 놋쇠 상판 + 진열장(권총) + 금전 등록기 + 장부
    g["Timber"].box(4.0, -1.5, (ZF + 5.2) / 2, 11.0, 2.0, 5.2 - ZF)
    g["Brass"].box(4.0, -1.5, 5.32, 11.3, 2.3, 0.25)
    g["Brass"].box(4.0, -2.55, 2.1, 11.0, 0.1, 0.3)
    C(4.0, -1.5, (ZF + 5.45) / 2, 11.3, 2.3, 5.45 - ZF)
    g["Glass"].box(1.6, -1.5, 6.2, 4.4, 1.6, 1.5)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Brass"].box(1.6 + sx * 2.2, -1.5 + sy * 0.8, 6.2, 0.12, 0.12, 1.55)
    g["Brass"].box(1.6, -1.5, 6.98, 4.5, 1.7, 0.08)
    for x, y, yaw in ((0.4, -1.5, 8), (1.7, -1.3, -12), (2.9, -1.6, 180)):
        PROP("Steam_Pistol", x, y, 5.47, yaw, 1.0, (-90, 0, 0))
    g["Brass"].box(7.8, -1.5, 6.05, 1.8, 1.3, 1.2)
    g["Iron"].box(7.8, -2.2, 5.62, 1.5, 0.4, 0.35)
    g["Glow"].box(7.8, -2.17, 6.4, 0.8, 0.05, 0.35)
    g["Leather"].obox(5.6, -1.6, 5.52, 1.1, 0.75, 0.15, rz=0.2)
    # 뒷벽 장총 걸이(여섯) + 놋쇠 못 + 간판
    g["Timber"].box(-3.25, iy1 - 0.3, 6.2, 15.7, 0.6, 6.0)
    for x in (-7.2, 0.6):
        for z in (4.2, 6.2, 8.2):
            PROP("Steam_Rifle", x, iy1 - 0.85, z, 0.0)
            for dx in (-2.2, 2.4):
                g["Brass"].box(x + dx, iy1 - 0.75, z - 0.35, 0.24, 0.5, 0.24)
    g["Brass"].box(-3.25, iy1 - 0.65, 9.9, 6.0, 0.15, 1.0)
    g["SignRed"].box(-3.25, iy1 - 0.75, 9.9, 5.4, 0.08, 0.6)
    # 화덕(키트, 오른 벽 — 굴뚝 자리) + 그루터기 모루
    PROP("Forge", 8.6, 3.4, ZF, -90.0, 0.6)
    C(8.6, 3.4, (ZF + 9.4) / 2, 3.9, 7.0, 9.4 - ZF)
    g["Timber"].cyl(5.6, 1.4, ZF, 0.8, 0.8, 1.6, seg=12)
    PROP("Anvil", 5.6, 1.4, ZF + 1.6, 30.0, 1.2)
    C(5.6, 1.4, ZF + 1.2, 1.7, 1.7, 2.4)
    # 작업대(왼 벽) + 바이스·설계도·연장, 위에 연장판
    g["Wood"].box(-9.0, 2.0, 4.6, 3.6, 6.5, 0.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Wood"].box(-9.0 + sx * 1.5, 2.0 + sy * 2.9, (ZF + 4.4) / 2, 0.35, 0.35, 4.4 - ZF)
    C(-9.0, 2.0, (ZF + 4.8) / 2, 3.6, 6.5, 4.8 - ZF)
    g["Iron"].box(-7.6, 0.0, 5.3, 0.9, 0.9, 1.0)
    g["Canvas"].obox(-9.2, 2.6, 4.82, 2.2, 3.0, 0.04, rz=0.1)
    g["Iron"].obox(-9.5, 4.6, 4.9, 0.25, 1.6, 0.2, rz=0.4)
    g["Brass"].obox(-8.3, 4.0, 4.9, 0.3, 1.2, 0.25, rz=-0.3)
    g["Timber"].box(ix0 + 0.15, 2.0, 7.6, 0.3, 6.0, 3.0)
    for k, (yy, zz, ln) in enumerate(((0.0, 8.4, 1.6), (1.4, 7.6, 1.2), (2.8, 8.6, 2.0), (4.2, 7.4, 1.4))):
        g["Iron" if k % 2 == 0 else "Brass"].obox(ix0 + 0.4, yy, zz, 0.2, 0.25, ln, ry=0.0)
    # 궤짝(왼 앞) · 통(오른 앞)
    g["Timber"].box(-10.0, -2.7, ZF + 1.0, 2.0, 2.0, 2.0)
    g["Timber"].obox(-9.9, -2.6, ZF + 3.0, 1.8, 1.8, 1.8, rz=0.25)
    C(-10.0, -2.7, ZF + 1.9, 2.1, 2.1, 3.8)
    for y in (-6.6, -4.3):
        g["Wood"].cyl(10.0, y, ZF, 1.0, 1.0, 2.4, seg=14)
        g["Iron"].cyl(10.0, y, ZF + 0.5, 1.05, 1.05, 0.15, seg=14)
        g["Iron"].cyl(10.0, y, ZF + 1.9, 1.05, 1.05, 0.15, seg=14)
        C(10.0, y, ZF + 1.2, 2.0, 2.0, 2.4)
    # 진열창 안 갑옷 진열대 둘(창을 본다)
    for x in (2.0, 7.0):
        armor_stand(g, x, -6.7, ZF, 0.0)
    # 오른 벽 톱니 장식 · 매단 등 셋
    S.gear(g, "Brass", ix1 - 0.15, -4.0, 7.6, 1.6, 12, 0.3, axis="x")
    S.gear(g, "Copper", ix1 - 0.15, -1.55, 8.75, 0.9, 8, 0.3, axis="x")
    for x, y in ((-5.0, -2.0), (4.5, 3.6), (0.5, -5.5)):
        lantern(g, x, y, ZC, 9.5)


# =========================================================================== 슈네라이히 공방(차펜) — 겉은 옛 좌표 ×1.3
ZK = 1.3


def zapfen_shell(g):
    """옛 zapfen 겉모양(옛 좌표). 큰 벽돌 덩이를 속 빈 벽(두께 1)으로, 큰 짐문을 열린 미닫이로"""
    W, D, T = 60.0, 34.0, 1.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    fy = -D / 2
    box2(g, "Brick", -W / 2, W / 2, D / 2 - T, D / 2, 2.0, 22.0, coll=False)
    box2(g, "Brick", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 2.0, 22.0, coll=False)
    box2(g, "Brick", W / 2 - T, W / 2, -D / 2 + T, D / 2 - T, 2.0, 22.0, coll=False)
    wall_door(g, "Brick", -W / 2, W / 2, -D / 2, -D / 2 + T, 2.0, 22.0, -6.0, 6.0, 15.0, coll=False)
    # 위 띠돌은 고리(속을 막지 않게)
    for x0, x1, y0, y1 in ((-W / 2 - 0.6, W / 2 + 0.6, -D / 2 - 0.6, -D / 2 + 1.0), (-W / 2 - 0.6, W / 2 + 0.6, D / 2 - 1.0, D / 2 + 0.6),
                           (-W / 2 - 0.6, -W / 2 + 1.0, -D / 2 + 1.0, D / 2 - 1.0), (W / 2 - 1.0, W / 2 + 0.6, -D / 2 + 1.0, D / 2 - 1.0)):
        box2(g, "StoneTrim", x0, x1, y0, y1, 22.0, 22.6, coll=False)
    for k in range(9):
        x = -W / 2 + 3 + k * (W - 6) / 8
        if abs(x) < 8:
            continue
        g["BrickDark"].box(x, fy - 0.4, 12.0, 1.6, 0.8, 20.0)
        g["BrickDark"].box(x, D / 2 + 0.4, 12.0, 1.6, 0.8, 20.0)
    n, rise = 5, 8.0
    tooth = D / n
    for k in range(n):
        y0 = -D / 2 + k * tooth
        a = math.atan2(rise, tooth)
        Lr = math.hypot(tooth, rise)
        g["RoofMetal"].obox(0, y0 + tooth / 2, 22.6 + rise / 2, W + 1.0, Lr, 0.6, rx=a)
        g["SnowCap"].obox(0, y0 + tooth / 2 - 0.2, 22.9 + rise / 2, W + 0.4, Lr * 0.8, 0.5, rx=a)
        g["Glass"].box(0, y0 + tooth - 0.15, 22.6 + rise / 2, W - 1.0, 0.3, rise - 0.6)   # 채광창(안에서 하늘이 보이게 유리)
        for m in range(9):
            g["Iron"].box(-W / 2 + 3 + m * (W - 6) / 8, y0 + tooth - 0.05, 22.6 + rise / 2, 0.4, 0.4, rise - 0.6)
    for s in (-1, 1):
        for k in range(n):
            y0 = -D / 2 + k * tooth
            v = [(s * W / 2, y0, 22.6), (s * W / 2, y0 + tooth, 22.6), (s * W / 2, y0 + tooth, 22.6 + rise),
                 (s * (W / 2 - 0.8), y0, 22.6), (s * (W / 2 - 0.8), y0 + tooth, 22.6),
                 (s * (W / 2 - 0.8), y0 + tooth, 22.6 + rise)]
            g["BrickDark"].add_mesh(v, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    g["BrickDark"].box(0, fy + 0.6, 22.6 + 5.0, 24.0, 1.2, 10.0)
    g["StoneTrim"].box(0, fy + 0.4, 32.9, 25.0, 1.6, 0.6)
    g["Iron"].hcyl(0, fy - 0.3, 28.0, 0.9, 0.6, axis="y", seg=12)
    g["Iron"].hcyl(-5.77, fy - 0.3, 28.0, 0.6, 0.6, axis="y", seg=12)
    g["Iron"].box(0, fy - 0.4, 22.0, 14.0, 0.5, 2.0)
    g["Brass"].box(0, fy - 0.7, 22.0, 12.6, 0.2, 1.2)
    # 열린 미닫이 짐문: 문짝 둘이 양옆으로 밀려 있다 + 위 레일
    GW, GH = 12.0, 13.0
    for s in (-1, 1):
        x = s * (GW / 2 + 3.2)
        g["Timber"].box(x, fy - 0.6, 2.0 + GH / 2, GW / 2 + 0.2, 0.4, GH)
        for k in range(4):
            g["Iron"].box(x, fy - 0.85, 2.0 + GH * (k + 0.5) / 4, GW / 2 + 0.2, 0.2, 0.45)
        g["Iron"].obox(x, fy - 0.85, 2.0 + GH / 2, 0.3, 0.2, math.hypot(GW / 2, GH) * 0.95, ry=math.atan2(GW / 2, GH) * s)
    g["Iron"].box(0, fy - 0.85, 2.0 + GH + 0.4, GW * 2 + 2.0, 0.35, 0.35)
    for s in (-1, 1):
        g["StoneTrim"].box(s * (GW / 2 + 0.6), fy - 0.3, 2.0 + GH / 2, 1.2, 0.8, GH)
    g["StoneTrim"].box(0, fy - 0.3, 2.0 + GH + 0.6, GW + 2.4, 0.8, 1.2)
    g["Stone"].box(0, fy - 2.0, 1.0, GW + 4, 4.0, 2.0)
    g["Stone"].box(0, fy - 4.6, 0.5, GW + 4, 1.2, 1.0)
    for k in range(3):
        for s in (-1, 1):
            x = s * (11.0 + k * 7.0)
            S.window(g, x, fy, 7.0, 3.0, 9.0, cross=True)
            g["Glow"].hcyl(x, fy - 0.1 - S.WIN_OUT, 16.0, 1.5, 0.2, axis="y", seg=12)
            S.window(g, x, fy + T, 7.0, 3.0, 9.0, face="+y", cross=True, sill=False)
            S.window(g, x, D / 2, 7.0, 3.0, 9.0, face="+y")
            S.window(g, x, D / 2 - T, 7.0, 3.0, 9.0, face="-y", cross=True, sill=False)
    for x, h in ((-19.0, 56.0), (0.0, 50.0), (19.0, 53.0)):
        yy = D / 2 - 3.0
        g["Brick"].box(x, yy, 2.0 + h / 2, 4.6, 4.6, h)
        for z in (20.0, 36.0, h - 1.0):
            g["StoneTrim"].box(x, yy, 2.0 + z, 5.2, 5.2, 0.8)
        g["Iron"].box(x, yy, 2.0 + h + 0.5, 5.4, 5.4, 1.0)
        S.vent(g, x, yy, 2.0 + h + 1.4)
    for sx in (-1, 1):
        S.pipe(g, [(sx * (W / 2 - 1), fy + 1.0, 19.0), (sx * (W / 2 - 1), fy - 1.5, 19.0), (sx * 8.0, fy - 1.5, 19.0),
                   (sx * 8.0, fy - 1.5, 2.0)], 0.7)
    ox = W / 2 + 7.5
    g["Stone"].box(ox, 4.0, 1.0, 15.0, 18.0, 2.0)
    g["BrickDark"].box(ox, 4.0, 2.0 + 8.5, 14.0, 16.0, 17.0)
    g["StoneTrim"].box(ox, 4.0, 19.8, 14.8, 16.8, 0.6)
    S.roof_gable(g, ox, 4.0, 20.1, 14.6, 16.6, 6.5, along="x", gable="Brick")
    for z in (4.0, 12.0):
        for yy in (-1.0, 5.0, 10.0):
            S.window(g, ox + 7.0, yy, z, 2.2, 3.2, face="+x")
    S.door(g, ox, 4.0 - 8.0, 2.0, 3.0, 6.6)
    S.window(g, ox + 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2)
    S.window(g, ox - 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2)
    lx = -W / 2 - 5.0
    g["Timber"].box(lx, -6.0, 1.5, 10.0, 14.0, 3.0)
    for x, y, s in ((-1.5, -9.0, 3.2), (1.8, -8.6, 2.6), (-1.0, -4.5, 3.0), (-1.2, -9.0, 2.4)):
        z = 3.0 + s / 2 if s != 2.4 else 3.0 + 3.2 + 1.2
        g["Timber"].box(lx + x, y, z, s, s, s)
        g["Iron"].box(lx + x, y, z, s + 0.1, s + 0.1, 0.3)


def zapfen_in(g):
    k = ZK
    scaled(g, k, zapfen_shell)
    W, D, T = 60.0 * k, 34.0 * k, 1.0 * k
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T      # ±37.7, ±20.8
    ZF, ZT = 2.8, 22.0 * k                                                 # 바닥 윗면, 벽 윗면 28.6
    # 충돌(겉): 받침·벽(짐문 x ±7.8, 높이 19.5)·굴뚝 셋·사무동·짐 부리는 단·문 앞 디딤돌
    C(0, 0, 1.3, (60 + 2) * k, (34 + 2) * k, 2.6)
    C(0, iy1 + T / 2, (2.6 + ZT) / 2, W, T, ZT - 2.6)
    C(-W / 2 + T / 2, 0, (2.6 + ZT) / 2, T, D, ZT - 2.6)
    C(W / 2 - T / 2, 0, (2.6 + ZT) / 2, T, D, ZT - 2.6)
    for x0, x1, z0, z1 in ((-W / 2, -7.8, 2.6, ZT), (7.8, W / 2, 2.6, ZT), (-7.8, 7.8, 19.5, ZT)):
        C((x0 + x1) / 2, -D / 2 + T / 2, (z0 + z1) / 2, x1 - x0, T, z1 - z0)
    for x in (-19.0, 0.0, 19.0):
        C(x * k, (D / k / 2 - 3.0) * k, 2.6 + 30, 4.6 * k, 4.6 * k, 60)
    C((30 + 7.5) * k, 4.0 * k, 11.05 * k, 15 * k, 18 * k, 22.1 * k)
    C(-35.0 * k, -6.0 * k, 1.5 * k, 10 * k, 14 * k, 3 * k)
    C(0, (-17 - 2.0) * k, 1.3, 16 * k, 4 * k, 2.6)
    C(0, (-17 - 4.6) * k, 0.65, 16 * k, 1.2 * k, 1.3)
    # 바닥(돌) + 가운데 통로(줄무늬 쇠판)
    g["Stone"].box(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    g["IronLight"].box(0, 0, ZF + 0.03, 10.0, D - 2 * T, 0.06)
    C(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    # 지붕보(트러스) 넷 + 기둥 넷
    for y in (-13.0, -4.3, 4.3, 13.0):
        g["Iron"].box(0, y, ZT - 0.9, W - 2 * T, 0.8, 1.0)
        for x in (-26.0, -13.0, 0.0, 13.0, 26.0):
            g["Iron"].obox(x - 3.0, y, ZT - 3.0, 0.3, 0.3, 5.2, ry=0.6)
            g["Iron"].obox(x + 3.0, y, ZT - 3.0, 0.3, 0.3, 5.2, ry=-0.6)
    for x in (-14.0, 14.0):
        for y in (-10.0, 10.0):
            g["Iron"].box(x, y, (ZF + ZT - 1.4) / 2, 1.2, 1.2, ZT - 1.4 - ZF)
            g["Brass"].box(x, y, ZF + 0.5, 1.7, 1.7, 1.0)
            C(x, y, (ZF + ZT) / 2, 1.3, 1.3, ZT - ZF)
    # 압착기 자리(움직이는 압착기를 옮겨 놓는다) + 운반대 + 짐통
    PROP("@Press", -20.0, -6.0, ZF, 0.0)
    C(-20.0, -6.0, ZF + 9.5, 9.6, 6.8, 19.0)
    for x in (-21.6, -18.4):
        g["Iron"].box(x, 5.0, ZF + 2.4, 0.3, 14.0, 0.5)
        for y in (-1.5, 5.0, 11.5):
            g["Iron"].box(x, y, ZF + 1.1, 0.4, 0.4, 2.2)
    for k2 in range(14):
        g["Iron"].hcyl(-20.0, -1.5 + k2 * 1.0, ZF + 2.55, 0.32, 3.0, axis="x", seg=10)
    for y, sz in ((1.0, 1.6), (6.5, 1.8), (10.2, 1.4)):
        g["Timber"].box(-20.0, y, ZF + 2.9 + sz / 2, sz, sz, sz)
    C(-20.0, 5.0, ZF + 1.5, 3.6, 14.0, 3.0)
    for x0, x1, y0, y1 in ((-22.6, -17.4, 13.0, 13.2), (-22.6, -17.4, 17.8, 18.0), (-22.6, -22.4, 13.0, 18.0), (-17.6, -17.4, 13.0, 18.0)):
        box2(g, "Iron", x0, x1, y0, y1, ZF, ZF + 3.0, coll=False)
    g["IronLight"].box(-20.0, 15.5, ZF + 0.1, 5.2, 5.0, 0.2)
    C(-20.0, 15.5, ZF + 1.5, 5.2, 5.0, 3.0)
    for x, y, s in ((-21.0, 14.6, 1.5), (-18.9, 16.4, 1.3), (-20.2, 16.6, 1.2)):
        g["Timber"].box(x, y, ZF + 0.2 + s / 2, s, s, s)
    # 사무실 중이층(왼 벽) + 계단(문 쪽에서 올라감) + 난간 + 유리 칸막이
    ZM = 14.4
    box2(g, "IronLight", ix0, -28.5, -3.0, iy1, ZM - 0.8, ZM)
    for y in (-2.6, 6.0, 14.0, 20.4):
        box2(g, "Iron", -29.2, -28.6, y - 0.3, y + 0.3, ZF, ZM - 0.8)
    for k2 in range(14):
        y0 = -17.0 + k2
        top = ZF + (ZM - ZF) * (k2 + 1) / 14
        box2(g, "Timber", ix0, ix0 + 4.0, y0, y0 + 1.05, top - 0.3, top)
    g["Iron"].obox(ix0 + 4.1, -10.0, (ZF + ZM) / 2 - 0.4, 0.3, math.hypot(14, ZM - ZF), 0.6, rx=math.atan2(ZM - ZF, 14))
    pr = []
    for y in (-17.0, -10.0, -3.0):
        z = ZF + (ZM - ZF) * (y + 17.0) / 14.0
        g["Iron"].cyl(ix0 + 4.1, y, z, 0.1, 0.1, 3.2, seg=6)
        pr.append((ix0 + 4.1, y, z + 3.2))
    sweep(g, "Brass", pr, 0.1, seg=6)
    for (x0, y0), (x1, y1) in (((-33.5, -2.8), (-28.6, -2.8)), ((-28.6, -2.8), (-28.6, iy1 - 0.2))):
        ln = math.hypot(x1 - x0, y1 - y0)
        for t in range(int(ln // 2.5) + 1):
            f = t / max(1, int(ln // 2.5))
            g["Iron"].cyl(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, ZM, 0.09, 0.09, 3.2, seg=6)
        g["Brass"].obox((x0 + x1) / 2, (y0 + y1) / 2, ZM + 3.2, max(ln, 0.2) if x1 != x0 else 0.2, 0.2 if x1 != x0 else ln, 0.2)
        C((x0 + x1) / 2, (y0 + y1) / 2, ZM + 1.6, max(abs(x1 - x0), 0.3), max(abs(y1 - y0), 0.3), 3.2)
    for y0, y1 in ((-2.0, 7.0), (9.0, 20.4)):
        g["Glass"].box(-29.6, (y0 + y1) / 2, ZM + 2.4, 0.15, y1 - y0, 3.6)
        g["Iron"].box(-29.6, (y0 + y1) / 2, ZM + 4.25, 0.25, y1 - y0, 0.25)
    g["Wood"].box(-34.0, 12.0, ZM + 2.6, 4.0, 2.2, 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Wood"].box(-34.0 + sx * 1.8, 12.0 + sy * 0.9, ZM + 1.25, 0.25, 0.25, 2.5)
    g["Canvas"].obox(-34.2, 12.1, ZM + 2.78, 2.2, 1.4, 0.04, rz=0.15)
    g["Brass"].box(-33.0, 11.6, ZM + 3.1, 0.6, 0.6, 0.6)
    g["Wood"].box(-31.6, 12.0, ZM + 1.4, 1.4, 1.4, 0.2)
    g["Wood"].box(-31.0, 12.0, ZM + 2.4, 0.2, 1.4, 2.0)
    for y in (16.0, 18.2):
        g["Iron"].box(ix0 + 0.8, y, ZM + 2.5, 1.6, 2.0, 5.0)
        for z in (1.2, 2.6, 4.0):
            g["Brass"].box(ix0 + 1.65, y, ZM + z, 0.1, 0.6, 0.15)
    for k2 in range(5):
        g["Canvas"].hcyl(ix0 + 0.6, 4.0 + k2 * 0.5, ZM + 3.6, 0.22, 1.4, axis="x", seg=8)
    g["Wood"].box(ix0 + 0.6, 5.0, ZM + 3.2, 1.2, 3.0, 0.2)
    S.gear(g, "Brass", ix0 + 0.15, 8.5, ZM + 5.5, 1.1, 12, 0.2, axis="x")
    g["LampPt"].box(-33.0, 8.0, ZM + 5.5, 0.3, 0.3, 0.3)
    C(-34.0, 12.0, ZM + 1.4, 4.0, 2.2, 2.8)
    C(ix0 + 0.8, 17.1, ZM + 2.5, 1.6, 4.2, 5.0)
    # 중이층 밑 궤짝·통
    for x, y, s, rz in ((-35.5, 4.0, 2.6, 0.0), (-35.0, 7.4, 2.4, 0.2), (-32.0, 4.5, 2.2, -0.1), (-35.4, 4.2, 2.0, 0.3)):
        z = ZF + s / 2 if (x, y) != (-35.4, 4.2) else ZF + 2.6 + s / 2
        g["Timber"].obox(x, y, z, s, s, s, rz=rz)
    C(-34.0, 5.6, ZF + 2.3, 6.0, 6.0, 4.6)
    for x, y in ((-35.6, 12.0), (-33.4, 12.6), (-35.4, 14.6)):
        g["Wood"].cyl(x, y, ZF, 1.0, 1.0, 2.6, seg=14)
        g["Iron"].cyl(x, y, ZF + 0.5, 1.05, 1.05, 0.15, seg=14)
        g["Iron"].cyl(x, y, ZF + 2.0, 1.05, 1.05, 0.15, seg=14)
    C(-34.6, 13.0, ZF + 1.3, 4.4, 5.0, 2.6)
    # 보일러 둘(오른 앞) + 압력계 + 김 관(천장 따라 압착기로)
    for bx in (24.0, 32.0):
        S.banded_cyl(g, "Copper", bx, -13.0, ZF, 3.2, 14.0, every=3.0, seg=24)
        S.pyramid(g, "Iron", bx, -13.0, ZF + 14.8, 4.4, 4.4, 1.6)
        g["Brass"].hcyl(bx, -16.35, ZF + 7.0, 0.8, 0.3, axis="y", seg=16)
        g["Dial"].hcyl(bx, -16.52, ZF + 7.0, 0.62, 0.06, axis="y", seg=16)
        g["Iron"].box(bx, -13.0, ZF + 0.4, 7.0, 7.0, 0.8)
        g["Core"].box(bx, -16.25, ZF + 2.4, 1.6, 0.2, 1.0)
        C(bx, -13.0, ZF + 7.4, 6.6, 6.6, 14.8)
        S.vent(g, bx + 1.6, -11.0, ZF + 15.0)
    S.pipe(g, [(24.0, -13.0, ZF + 14.6), (24.0, -13.0, 24.0), (-20.0, -13.0, 24.0), (-20.0, -13.0, 22.6)], 0.6)
    S.pipe(g, [(32.0, -11.4, ZF + 14.0), (32.0, -11.4, 25.4), (-17.0, -11.4, 25.4), (-17.0, -11.4, 22.6)], 0.5)
    # 특허 금고(오른 뒤 구석): 벽돌 금고방 + 둥근 금고문(놋쇠 테·바퀴·빗장)
    box2(g, "BrickDark", 26.0, ix1, 9.0, iy1, ZF, ZF + 12.0)
    g["StoneTrim"].box((26.0 + ix1) / 2, (9.0 + iy1) / 2, ZF + 12.3, ix1 - 26.0 + 0.6, iy1 - 9.0 + 0.6, 0.6)
    vx, vz = 31.8, ZF + 5.4
    g["Brass"].hcyl(vx, 8.85, vz, 4.1, 0.4, axis="y", seg=32)
    g["Iron"].hcyl(vx, 8.5, vz, 3.6, 0.8, axis="y", seg=32)
    g["Brass"].hcyl(vx, 8.0, vz, 0.6, 0.6, axis="y", seg=16)
    for k2 in range(4):
        g["Brass"].obox(vx, 7.95, vz, 0.3, 0.2, 4.4, ry=k2 * math.pi / 4)
    sweep(g, "Brass", [(vx + 2.2 * math.cos(2 * math.pi * i / 24), 7.9, vz + 2.2 * math.sin(2 * math.pi * i / 24)) for i in range(25)], 0.12, seg=6, cap=False)
    for k2 in range(12):
        a = 2 * math.pi * k2 / 12
        g["Brass"].box(vx + 3.85 * math.cos(a), 8.6, vz + 3.85 * math.sin(a), 0.35, 0.3, 0.35)
    g["Iron"].box(vx + 4.3, 8.6, vz, 1.2, 0.6, 2.6)
    g["SignGold"].box(vx, 8.85, ZF + 10.6, 5.0, 0.15, 1.0)
    # 뒷벽 큰 톱니 한 쌍(돈다)
    # (안쪽 굴뚝 x 0 · 24.7 사이 빈 벽, 아래·위로 맞물림)
    PROP("Gear_24", 12.35, iy1 - 0.6, 11.0, 0.0, 1.0, speed=10)
    PROP("Gear_16", 12.35, iy1 - 0.6, 11.0 + (7.49 + 4.99 - 0.9), 0.0, 1.0, speed=-15)
    g["Iron"].box(12.35, iy1 - 0.15, 16.8, 1.0, 0.3, 14.0)
    # 오른 벽 작업대 + 선반(연장) + 매단 사슬 기중기
    g["Wood"].box(35.6, 2.0, ZF + 3.0, 3.6, 10.0, 0.5)
    for sy in (-1, 1):
        for sx in (-1, 1):
            g["Wood"].box(35.6 + sx * 1.5, 2.0 + sy * 4.5, ZF + 1.4, 0.4, 0.4, 2.8)
    g["Iron"].box(35.0, -1.5, ZF + 3.8, 1.0, 1.0, 1.2)
    g["Iron"].hcyl(35.6, 3.5, ZF + 3.75, 0.5, 2.6, axis="y", seg=12)
    g["Brass"].box(35.6, 5.5, ZF + 3.9, 1.0, 1.4, 1.3)
    g["Canvas"].obox(35.8, 1.0, ZF + 3.28, 2.0, 2.8, 0.04, rz=0.2)
    g["Wood"].box(ix1 - 0.15, 2.0, ZF + 7.5, 0.3, 9.0, 4.0)
    for k2, (yy, zz) in enumerate(((-1.5, 8.6), (0.5, 7.8), (2.5, 9.0), (4.5, 8.2), (6.0, 8.8))):
        g["Iron" if k2 % 2 else "Brass"].box(ix1 - 0.45, yy, ZF + zz - 1.0, 0.25, 0.3, 1.8)
    C(35.6, 2.0, ZF + 1.6, 3.6, 10.0, 3.2)
    g["Iron"].box(0, 0, ZT - 2.4, 1.2, D - 4 * T, 0.8)
    g["Iron"].box(0, 4.0, ZT - 3.2, 1.6, 2.0, 0.8)
    pts = [(0, 4.0, ZT - 3.6)] + [(0.15 * math.sin(i), 4.0, ZT - 3.6 - i * 0.5) for i in range(1, 22)]
    sweep(g, "Iron", pts, 0.12, seg=6)
    hz = ZT - 3.6 - 21 * 0.5
    sweep(g, "Iron", [(0, 4.0, hz), (0.6, 4.0, hz - 0.5), (0.6, 4.0, hz - 1.2), (0, 4.0, hz - 1.5), (-0.4, 4.0, hz - 1.1)], 0.18, seg=6)
    # 매단 등 여섯 + 벽등
    for x in (-12.0, 12.0):
        for y in (-12.0, 0.0, 12.0):
            lantern(g, x, y, ZT - 1.4, 20.0)
    for x in (-36.0, 36.0):
        g["LampPt"].box(x, -8.0, 10.0, 0.3, 0.3, 0.3)


# =========================================================================== 체스판 건물(기물군 본부) — 겉은 옛 좌표 ×1.2
FK = 1.2


def figuren_shell(g):
    """옛 figuren 겉모양(옛 좌표). 큰 돌 덩이를 속 빈 홀로, 가운데 탑은 앞 현관(문)과 지붕 위 탑신(속 빈 굴)으로"""
    W, D, T = 44.0, 26.0, 1.0
    TX, TY, TW, TH = 0.0, -D / 2 + 3.0, 12.0, 40.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    # 홀 벽: 뒤·왼·오른 + 앞(탑 자리 x ±5 비움 — 현관이 홀로 이어진다)
    box2(g, "Stone", -W / 2, W / 2, D / 2 - T, D / 2, 2.0, 20.0, coll=False)
    box2(g, "Stone", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 2.0, 20.0, coll=False)
    box2(g, "Stone", W / 2 - T, W / 2, -D / 2 + T, D / 2 - T, 2.0, 20.0, coll=False)
    box2(g, "Stone", -W / 2, -TW / 2, -D / 2, -D / 2 + T, 2.0, 20.0, coll=False)
    box2(g, "Stone", TW / 2, W / 2, -D / 2, -D / 2 + T, 2.0, 20.0, coll=False)
    for z in (10.0, 20.0):
        for x0, x1, y0, y1 in ((-W / 2 - 0.4, W / 2 + 0.4, -D / 2 - 0.4, -D / 2 + 0.6), (-W / 2 - 0.4, W / 2 + 0.4, D / 2 - 0.6, D / 2 + 0.4),
                               (-W / 2 - 0.4, -W / 2 + 0.6, -D / 2 + 0.6, D / 2 - 0.6), (W / 2 - 0.6, W / 2 + 0.4, -D / 2 + 0.6, D / 2 - 0.6)):
            if z == 10.0 and y0 < -D / 2 and x0 < 0 < x1:
                box2(g, "StoneTrim", x0, -TW / 2, y0, y1, z, z + 0.6, coll=False)
                box2(g, "StoneTrim", TW / 2, x1, y0, y1, z, z + 0.6, coll=False)
                continue
            box2(g, "StoneTrim", x0, x1, y0, y1, z, z + 0.6, coll=False)

    def merlons(x0, x1, y0, y1, z, step=3.0, s=1.6, h=2.6):
        n = int(round(abs(x1 - x0) / step)) if x1 != x0 else int(round(abs(y1 - y0) / step))
        for k in range(n + 1):
            t = k / max(1, n)
            g["Stone"].box(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + h / 2, s, s, h)
    merlons(-W / 2 + 0.8, W / 2 - 0.8, -D / 2 + 0.8, -D / 2 + 0.8, 20.6)
    merlons(-W / 2 + 0.8, W / 2 - 0.8, D / 2 - 0.8, D / 2 - 0.8, 20.6)
    merlons(-W / 2 + 0.8, -W / 2 + 0.8, -D / 2 + 3.8, D / 2 - 3.8, 20.6)
    merlons(W / 2 - 0.8, W / 2 - 0.8, -D / 2 + 3.8, D / 2 - 3.8, 20.6)
    # 지붕판(= 홀 천장). 탑 굴 자리(x ±5, y TY-5..TY+5) 는 뚫는다
    hx0, hx1, hy0, hy1 = -5.0, 5.0, TY - 5.0, TY + 5.0
    for x0, x1, y0, y1 in ((-W / 2 + 0.5, hx0, -D / 2 + 0.5, D / 2 - 0.5), (hx1, W / 2 - 0.5, -D / 2 + 0.5, D / 2 - 0.5),
                           (hx0, hx1, hy1, D / 2 - 0.5)):
        box2(g, "Stone", x0, x1, y0, y1, 20.6, 21.2, coll=False)
    # 탑: 앞벽(문 x ±2.5, 높이 9) 끝까지 / 옆벽 현관 부분(홀 앞벽 밖) / 지붕 위 탑신(네 벽)
    ty0, ty1 = TY - TW / 2, TY + TW / 2
    wall_door(g, "Stone", -TW / 2, TW / 2, ty0, ty0 + T, 2.0, 2.0 + TH, -2.5, 2.5, 11.0, coll=False)
    for s in (-1, 1):
        box2(g, "Stone", *sorted((s * TW / 2, s * (TW / 2 - T))), ty0 + T, -D / 2 + T, 2.0, 2.0 + TH, coll=False)
        box2(g, "Stone", *sorted((s * TW / 2, s * (TW / 2 - T))), -D / 2 + T, ty1, 21.2, 2.0 + TH, coll=False)
    box2(g, "Stone", -TW / 2 + T, TW / 2 - T, ty1 - T, ty1, 21.2, 2.0 + TH, coll=False)
    for z in (20.0, 30.0, 39.0):
        for x0, x1, y0, y1 in ((-TW / 2 - 0.4, TW / 2 + 0.4, ty0 - 0.4, ty0 + 0.6), (-TW / 2 - 0.4, TW / 2 + 0.4, ty1 - 0.6, ty1 + 0.4),
                               (-TW / 2 - 0.4, -TW / 2 + 0.6, ty0 + 0.6, ty1 - 0.6), (TW / 2 - 0.6, TW / 2 + 0.4, ty0 + 0.6, ty1 - 0.6)):
            box2(g, "StoneTrim", x0, x1, y0, y1, 2.0 + z - 0.3, 2.0 + z + 0.3, coll=False)
    g["StoneTrim"].box(TX, TY, 2.0 + TH + 0.8, TW + 2.4, TW + 2.4, 1.6)
    for k in range(4):
        for s in (-1, 1):
            u = -TW / 2 - 0.4 + k * (TW + 0.8) / 3
            g["Stone"].box(TX + u, TY + s * (TW / 2 + 0.4), 2.0 + TH + 3.2, 2.2, 2.2, 3.2)
            g["Stone"].box(TX + s * (TW / 2 + 0.4), TY + u, 2.0 + TH + 3.2, 2.2, 2.2, 3.2)
    S.gear(g, "Brass", TX, TY - TW / 2 - 0.4, 2.0 + 33.5, 4.2, 18, 0.8)
    g["Iron"].cyl(TX, TY, 2.0 + TH + 1.6, 0.35, 0.3, 14.0, seg=8)
    g["Banner"].box(TX + 3.2, TY, 2.0 + TH + 12.0, 6.0, 0.2, 3.6)
    g["Brass"].box(TX + 3.2, TY - 0.15, 2.0 + TH + 12.0, 1.4, 0.1, 1.4)
    for s in (-1, 1):
        cx, cy = s * (W / 2 - 1.0), -D / 2 + 1.0
        g["Stone"].cyl(cx, cy, 2.0, 3.4, 3.4, 26.0, seg=16)
        g["StoneTrim"].cyl(cx, cy, 27.4, 3.9, 3.9, 1.0, seg=16)
        for k in range(8):
            a = 2 * math.pi * k / 8
            g["Stone"].obox(cx + 3.3 * math.cos(a), cy + 3.3 * math.sin(a), 29.6, 1.6, 1.6, 2.6, rz=a)
        for z in (8.0, 17.0):
            g["Glow"].box(cx, cy - 3.35 - S.WIN_OUT, z + 1.6, 0.8, 0.3, 3.2)
    # 문: 무쇠 쌍문을 안(현관 옆벽)으로 활짝
    fy = ty0
    for s in (-1, 1):
        g["Iron"].box(s * (TW / 2 - T - 0.25), fy + T + 1.3, 2.0 + 4.5, 0.4, 2.5, 9.0)
        for k in range(5):
            g["Brass"].box(s * (TW / 2 - T - 0.5), fy + T + 0.6 + (k % 3) * 0.9, 3.2 + k * 1.8, 0.2, 0.35, 0.35)
    g["StoneTrim"].box(TX, fy - 0.4, 2.0 + 9.6, 6.6, 0.8, 1.2)
    for s in (-1, 1):
        g["StoneTrim"].box(TX + s * 3.0, fy - 0.4, 2.0 + 4.5, 0.8, 0.8, 9.0)
        g["Banner"].box(TX + s * 4.8, fy - 0.3, 2.0 + 12.0, 2.4, 0.2, 7.0)
    g["Stone"].box(TX, fy - 2.4, 1.0, 9.0, 4.8, 2.0)
    g["Stone"].box(TX, fy - 5.4, 0.5, 9.0, 1.2, 1.0)
    # 총안 창(밖) + 같은 자리 안쪽 불빛
    for z in (4.0, 13.5):
        for k in range(7):
            x = -W / 2 + 5.0 + k * 5.6
            if abs(x) < TW / 2 + 1.0:
                continue
            g["Glow"].box(x, -D / 2 - 0.1 - S.WIN_OUT, z + 2.0, 0.8, 0.2, 4.0)
            g["Glow"].box(x, -D / 2 + T + 0.2, z + 2.0, 0.8, 0.2, 4.0)
            g["StoneTrim"].box(x, -D / 2 - 0.3, z - 0.2, 1.6, 0.6, 0.4)
            g["Glow"].box(x, D / 2 + 0.1 + S.WIN_OUT, z + 2.0, 0.8, 0.2, 4.0)
            g["Glow"].box(x, D / 2 - T - 0.2, z + 2.0, 0.8, 0.2, 4.0)
    for s in (-1, 1):
        for k in range(3):
            g["Glow"].box(s * (W / 2 + 0.1 + S.WIN_OUT), -6.0 + k * 6.0, 15.5, 0.2, 0.8, 4.0)
            g["Glow"].box(s * (W / 2 - T - 0.2), -6.0 + k * 6.0, 15.5, 0.2, 0.8, 4.0)
    S.pipe(g, [(W / 2 - 4.0, D / 2 + 0.8, 1.0), (W / 2 - 4.0, D / 2 + 0.8, 24.0)], 0.6, mat="Iron")
    S.vent(g, W / 2 - 4.0, D / 2 + 0.8, 24.8)
    # 탑 속 시계 장치(시계판 뒤) + 큰 추(홀 천장 구멍으로 내려온다)
    g["Iron"].box(0, ty0 + T + 0.4, 2.0 + 30.0, TW - 2 * T, 0.6, 0.6)
    g["Iron"].box(0, ty0 + T + 0.4, 2.0 + 37.5, TW - 2 * T, 0.6, 0.6)
    for x, z, r, n in ((0.0, 33.5, 2.6, 24), (3.0, 35.4, 1.4, 12), (-3.1, 31.8, 1.6, 14), (2.4, 31.4, 1.0, 10)):
        S.gear(g, "Brass" if r > 1.2 else "Copper", x, ty0 + T + 1.0, 2.0 + z, r, n, 0.3, axis="y")
        g["Iron"].hcyl(x, ty0 + T + 1.6, 2.0 + z, 0.25, 1.6, axis="y", seg=8)
    g["Iron"].hcyl(0, ty0 + T + 2.5, 2.0 + 33.5, 0.35, 3.2, axis="y", seg=10)
    g["Iron"].cyl(0, ty0 + T + 3.8, 13.8, 0.12, 0.12, 2.0 + 32.0 - 13.8, seg=8)
    g["Brass"].hcyl(0, ty0 + T + 3.8, 13.3, 1.4, 0.5, axis="y", seg=24)
    g["Iron"].hcyl(0, ty0 + T + 3.8, 13.3, 0.5, 0.7, axis="y", seg=12)


def figuren_in(g):
    k = FK
    scaled(g, k, figuren_shell)
    W, D, T = 44.0 * k, 26.0 * k, 1.0 * k
    TY, TW = (-13.0 + 3.0) * k, 12.0 * k
    ty0 = TY - TW / 2
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T      # ±25.2, -14.4..14.4
    ZF, ZT = 2.6, 20.6 * k                                                 # 바닥, 천장 24.72
    # 충돌(겉): 받침·홀 벽(앞벽은 탑 자리 비움)·현관 옆벽·탑 앞벽(문 x ±3, 높이 10.8)·모서리 탑·문 앞 디딤돌
    C(0, 0, 1.2, (44 + 2) * k, (26 + 2) * k, 2.4)
    C(0, iy1 + T / 2, 14.0, W, T, 24)
    C(-W / 2 + T / 2, 0, 14.0, T, D, 24)
    C(W / 2 - T / 2, 0, 14.0, T, D, 24)
    for s in (-1, 1):
        x0, x1 = sorted((s * TW / 2, s * W / 2))
        C((x0 + x1) / 2, -D / 2 + T / 2, 14.0, x1 - x0, T, 24)
        vy0, vy1 = ty0 + T, -D / 2 + T
        C(s * (TW / 2 - T / 2), (vy0 + vy1) / 2, 26.4, T, vy1 - vy0, 48)
        C(s * (W / 2 - 1.0) * k, (-13 + 1.0) * k, 16.0, 6.8 * k, 6.8 * k, 28)
    for x0, x1, z0, z1 in ((-TW / 2, -3.0, 2.4, 50), (3.0, TW / 2, 2.4, 50), (-3.0, 3.0, 13.2, 50)):
        C((x0 + x1) / 2, ty0 + T / 2, (z0 + z1) / 2, x1 - x0, T, z1 - z0)
    C(0, ty0 - 2.4 * k, 1.2, 9 * k, 4.8 * k, 2.4)
    C(0, ty0 - 5.4 * k, 0.6, 9 * k, 1.2 * k, 1.2)
    # 바닥(돌) + 체스판(8×8, 칸 3) + 놋쇠 테
    g["Stone"].box(0, (iy0 + iy1) / 2 - 0.0, ZF - 0.1, ix1 - ix0, iy1 - iy0, 0.2)
    g["Stone"].box(0, (ty0 + T + iy0) / 2, ZF - 0.1, TW - 2 * T, iy0 - ty0 - T, 0.2)
    C(0, 0, ZF - 0.1, ix1 - ix0, iy1 - iy0, 0.2)
    C(0, (ty0 + T + iy0) / 2, ZF - 0.1, TW - 2 * T, iy0 - ty0 - T, 0.2)
    for i in range(8):
        for j in range(8):
            g["Marble" if (i + j) % 2 == 0 else "DarkStone"].box(-10.5 + 3 * i, -10.5 + 3 * j, ZF + 0.03, 3.0, 3.0, 0.06)
    for x0, x1, y0, y1 in ((-12.3, 12.3, -12.3, -12.0), (-12.3, 12.3, 12.0, 12.3), (-12.3, -12.0, -12.0, 12.0), (12.0, 12.3, -12.0, 12.0)):
        box2(g, "Brass", x0, x1, y0, y1, ZF, ZF + 0.1, coll=False)
    # 큰 체스 말(키트 말 ×4): 무쇠 편 / 놋쇠 편, 한창 두는 판
    # 문에서 단상까지 가운데 두 줄(x ±1.5)은 비워 길로 둔다
    pieces = [("King", 4.5, 10.5, "Iron"), ("Queen", -4.5, 4.5, "Iron"), ("Rook", -10.5, 10.5, "Iron"), ("Knight", 4.5, 1.5, "Iron"),
              ("Pawn", -4.5, 7.5, "Iron"), ("Pawn", 7.5, 7.5, "Iron"), ("Bishop", -7.5, 1.5, "Iron"),
              ("King", -4.5, -10.5, "Brass"), ("Queen", 7.5, -4.5, "Brass"), ("Rook", 10.5, -10.5, "Brass"), ("Knight", -4.5, -1.5, "Brass"),
              ("Pawn", 4.5, -7.5, "Brass"), ("Pawn", -7.5, -4.5, "Brass"), ("Bishop", 7.5, -1.5, "Brass")]
    for kind, x, y, col in pieces:
        PROP("Chess_" + kind, x, y, ZF + 0.06, 0.0 if col == "Brass" else 180.0, 4.0, col=col)
        C(x, y, ZF + 4.0, 2.2, 2.2, 8.0)
    # 기둥 여섯(돌, 받침·머리 띠돌)
    for x in (-19.5, 19.5):
        for y in (-9.0, 0.0, 9.0):
            g["Stone"].cyl(x, y, ZF, 1.3, 1.2, ZT - ZF, seg=16)
            g["StoneTrim"].cyl(x, y, ZF, 1.7, 1.7, 1.0, seg=16)
            g["StoneTrim"].cyl(x, y, ZT - 1.2, 1.3, 1.8, 1.2, seg=16)
            C(x, y, (ZF + ZT) / 2, 2.6, 2.6, ZT - ZF)
    # 천장 들보(나무) 격자
    for x in (-19.5, -6.5, 6.5, 19.5):
        g["Wood"].box(x, 0, ZT - 0.5, 0.9, iy1 - iy0, 0.9)
    for y in (-9.0, 9.0):
        g["Wood"].box(0, y, ZT - 0.5, ix1 - ix0, 0.9, 0.9)
    # 깃발(옆벽 기둥 사이) + 뒷벽 단상 양옆
    for s in (-1, 1):
        for y in (-4.5, 4.5):
            x = s * (ix1 - 0.15)
            g["Brass"].box(x - s * 0.3, y, 19.0, 0.2, 3.6, 0.2)
            g["Banner"].box(x, y, 14.6, 0.15, 3.0, 8.6)
            g["Brass"].box(x - s * 0.1, y, 12.0, 0.1, 1.0, 1.0)
        g["Banner"].box(s * 8.0, iy1 - 0.15, 13.0, 3.4, 0.15, 12.0)
        g["Brass"].box(s * 8.0, iy1 - 0.4, 19.2, 4.0, 0.2, 0.2)
    # 단상 + 큰 의자(뒷벽 가운데, 앞을 본다)
    box2(g, "Stone", -5.0, 5.0, 12.4, iy1, ZF, ZF + 0.8)
    box2(g, "StoneTrim", -4.0, 4.0, 12.0, 12.4, ZF, ZF + 0.4)
    g["Wood"].box(0, 13.4, ZF + 2.4, 2.8, 2.0, 0.4)
    g["Banner"].box(0, 13.4, ZF + 2.65, 2.4, 1.6, 0.12)
    g["Wood"].box(0, 14.25, ZF + 4.6, 2.8, 0.4, 4.6)
    g["Banner"].box(0, 14.0, ZF + 4.6, 2.2, 0.08, 3.6)
    for sx in (-1, 1):
        g["Wood"].box(sx * 1.3, 13.4, ZF + 3.2, 0.3, 2.0, 0.3)
        g["Wood"].box(sx * 1.3, 12.6, ZF + 1.6, 0.3, 0.3, 1.6)
        sphere(g, "Brass", (sx * 1.3, 14.25, ZF + 7.0), 0.3, sub=1)
    S.gear(g, "Brass", 0, 14.4 - 0.25, ZF + 8.2, 1.4, 12, 0.2, axis="y")
    C(0, 13.3, ZF + 3.0, 3.0, 2.4, 6.0)
    # 작전 탁자(오른 뒤) + 지도·작은 말·놋쇠 나침반·의자
    tx, ty = 14.0, 9.0
    g["Wood"].box(tx, ty, ZF + 3.0, 8.0, 4.4, 0.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Wood"].box(tx + sx * 3.6, ty + sy * 1.8, ZF + 1.4, 0.4, 0.4, 2.8)
    g["Canvas"].box(tx, ty, ZF + 3.23, 7.0, 3.6, 0.04)
    for k2 in range(9):
        g["Iron" if k2 % 2 else "Brass"].box(tx - 2.6 + (k2 * 1.37) % 5.6, ty - 1.2 + (k2 * 0.83) % 2.4, ZF + 3.45, 0.3, 0.3, 0.4)
    g["Brass"].cyl(tx + 2.8, ty + 1.2, ZF + 3.2, 0.5, 0.5, 0.12, seg=14)
    C(tx, ty, ZF + 1.6, 8.0, 4.4, 3.2)
    for sx in (-1, 1):
        g["Wood"].box(tx + sx * 2.2, ty - 3.4, ZF + 1.5, 1.4, 1.4, 0.2)
        g["Wood"].box(tx + sx * 2.2, ty - 4.05, ZF + 2.6, 1.4, 0.2, 2.2)
    # 영사기(키트) + 화면(왼 벽)
    g["Canvas"].box(ix0 + 0.12, 0.0, 11.0, 0.08, 10.0, 6.0)
    for (y0, y1, z0, z1) in ((-5.2, 5.2, 13.9, 14.3), (-5.2, 5.2, 7.7, 8.1), (-5.2, -4.9, 7.7, 14.3), (4.9, 5.2, 7.7, 14.3)):
        box2(g, "Brass", ix0, ix0 + 0.3, y0, y1, z0, z1, coll=False)
    g["Wood"].box(-14.5, 0.0, ZF + 1.6, 2.4, 2.4, 3.2)
    PROP("Film_Projector", -14.5, 0.0, ZF + 3.2, -90.0, 1.0)
    C(-14.5, 0.0, ZF + 3.0, 2.6, 3.0, 6.0)
    # 샹들리에 둘 + 벽 횃불 넷
    for y in (-4.0, 6.0):
        g["Iron"].cyl(0, y, 18.4, 0.08, 0.08, ZT - 18.4, seg=6)
        S.ring(g, "Brass", 0, y, 17.8, 2.4, 2.7, 0.3, n=24)
        S.ring(g, "Brass", 0, y, 16.6, 1.3, 1.5, 0.25, n=16)
        for k2 in range(8):
            a = 2 * math.pi * k2 / 8
            g["Wood"].cyl(2.55 * math.cos(a), y + 2.55 * math.sin(a), 18.1, 0.12, 0.12, 0.6, seg=6)
            g["Glow"].box(2.55 * math.cos(a), y + 2.55 * math.sin(a), 18.85, 0.16, 0.16, 0.3)
        for k2 in range(4):
            a = 2 * math.pi * k2 / 4 + 0.4
            g["Iron"].obox(1.3 * math.cos(a), y + 1.3 * math.sin(a), 17.6, 0.1, 0.1, 2.6, rx=0.45 * math.sin(a), ry=-0.45 * math.cos(a))
        g["LampPt"].box(0, y, 17.0, 0.3, 0.3, 0.3)
    for s in (-1, 1):
        for y in (-12.0, 12.0):
            x = s * (ix1 - 0.3)
            g["Iron"].box(x, y, 9.5, 0.6, 0.5, 0.8)
            g["Iron"].cyl(x - s * 0.4, y, 9.5, 0.25, 0.35, 1.0, seg=8)
            g["Glow"].box(x - s * 0.4, y, 10.9, 0.4, 0.4, 0.8)
            g["LampPt"].box(x - s * 0.9, y, 10.9, 0.3, 0.3, 0.3)
    # 갑옷 진열대 넷(단상 양옆, 앞 모서리)
    for x, y, rz in ((-8.0, 12.4, math.pi), (8.0, 12.4, math.pi), (-23.0, -12.0, -math.pi / 4), (23.0, -12.0, math.pi / 4)):
        armor_stand(g, x, y, ZF, rz)


# =========================================================================== 설 공방 폐허 — 겉은 옛 좌표 ×1.3
SK = 1.3


def sel_shell(g):
    S.sel_ruin(g)
    g["Stone"].box(-6.0, -9.0 - 1.1, 0.5, 4.0, 2.2, 1.0)     # 문 앞 디딤돌(받침 1.5 를 두 번에)


def sel_in(g):
    k = SK
    scaled(g, k, sel_shell)
    W, D, T = 24.0 * k, 18.0 * k, 1.2 * k
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T      # ±14.04, ±10.14
    ZF = 1.7 * k
    C(0, 0, 0.75 * k, (24 + 1.2) * k, (18 + 1.2) * k, 1.5 * k)
    # 벽 조각 충돌(옛 sel_ruin 의 벽 표 그대로 ×k)
    front = [(-12, -9.5, 14.0), (-9.5, -7.6, 18.5), (-4.4, -1.0, 16.0), (-1.0, 2.6, 9.5), (2.6, 4.0, 5.5), (4.0, 8.5, 12.0), (8.5, 12, 20.5)]
    back = [(-12, -6.0, 12.5), (-6.0, -2.0, 21.0), (-2.0, 3.0, 17.5), (3.0, 7.5, 8.0), (7.5, 12, 15.0)]
    left = [(-9, -3.0, 19.5), (-3.0, 2.5, 11.0), (2.5, 9, 16.5)]
    right = [(-9, -4.0, 6.5), (-4.0, 1.5, 13.5), (1.5, 9, 20.0)]
    t = 1.2
    for x0, x1, h in front:
        C((x0 + x1) / 2 * k, (-9 + t / 2) * k, (1.5 + h / 2) * k, (x1 - x0) * k, t * k, h * k)
    for x0, x1, h in back:
        C((x0 + x1) / 2 * k, (9 - t / 2) * k, (1.5 + h / 2) * k, (x1 - x0) * k, t * k, h * k)
    for y0, y1, h in left:
        C((-12 + t / 2) * k, (y0 + y1) / 2 * k, (1.5 + h / 2) * k, t * k, (y1 - y0) * k, h * k)
    for y0, y1, h in right:
        C((12 - t / 2) * k, (y0 + y1) / 2 * k, (1.5 + h / 2) * k, t * k, (y1 - y0) * k, h * k)
    C((12 + 1.6) * k, 3.0 * k, (1.5 + 6.5) * k, 3.2 * k, 3.2 * k, 13.0 * k)
    C(-6.0 * k, -10.1 * k, 0.5 * k, 4.0 * k, 2.2 * k, 1.0 * k)
    # 무너진 선반 둘(왼 벽에 기대 쓰러짐) + 쏟아진 책
    for y, ry in ((-3.0, 0.32), (3.2, 0.42)):
        g["Char"].obox(ix0 + 1.6, y, ZF + 3.2, 0.6, 4.0, 6.6, ry=ry)
        for z in (1.4, 3.0, 4.6):
            g["Char"].obox(ix0 + 1.6 + math.sin(ry) * (z - 3.2), y, ZF + 3.2 + math.cos(ry) * (z - 3.2), 1.8, 3.8, 0.2, ry=ry)
        C(ix0 + 1.5, y, ZF + 2.5, 2.4, 4.0, 5.0)
    for k2 in range(12):
        x = ix0 + 3.2 + (k2 * 1.7) % 4.0
        y = -4.5 + (k2 * 2.3) % 9.0
        g["Soot" if k2 % 3 else "Leather"].obox(x, y, ZF + 0.12, 0.8, 0.55, 0.22, rz=k2 * 0.7)
    # 탄 궤짝 둘(앞 왼 구석)
    for x, y, s, rz, mat in ((-11.4, -7.6, 2.4, 0.2, "Char"), (-9.2, -8.2, 2.0, -0.4, "Soot")):
        g[mat].obox(x, y, ZF + s / 2, s, s, s, rz=rz)
    C(-10.4, -7.9, ZF + 1.2, 4.6, 3.0, 2.4)
    # 그을린 작업대(다리 하나 부러져 기욺) + 흩어진 종이(반쯤 탐)
    g["Char"].obox(-4.0, 7.2, ZF + 2.4, 6.0, 2.6, 0.4, ry=0.12)
    for sx, h in ((-2.6, 2.3), (2.6, 1.6)):
        for sy in (-1.0, 1.0):
            g["Char"].box(-4.0 + sx, 7.2 + sy, ZF + h / 2, 0.35, 0.35, h)
    C(-4.0, 7.2, ZF + 1.2, 6.0, 2.6, 2.4)
    for k2 in range(14):
        g["Canvas" if k2 % 3 else "Soot"].obox(-6.5 + (k2 * 1.3) % 7.0, 3.0 + (k2 * 0.9) % 4.0, ZF + 0.05, 0.9, 1.2, 0.03, rz=k2 * 0.9)
    # 그을린 감정 변환장치 시제품(키트) — 가슴 핵은 아직 붉다
    # (뒤 오른 구석 — 옛 폐허 바닥의 무너진 서까래·떨어진 톱니를 피해서)
    PROP("Emotion_Proto", 10.0, 6.5, ZF, 200.0, 1.2)
    C(10.0, 6.5, ZF + 4.4, 7.4, 6.8, 8.8)
    for x, y, z, s in ((9.0, 5.6, ZF + 5.5, 1.4), (11.2, 7.4, ZF + 3.4, 1.1)):
        g["Soot"].obox(x, y, z, s, s * 0.7, 0.3, rz=x, ry=0.3)
    # 떨어진 샹들리에(바닥에 찌그러진 고리) + 몽당초
    S.ring(g, "Iron", -2.0, -4.0, ZF + 0.05, 1.7, 2.0, 0.25, n=20)
    S.ring(g, "Iron", -2.3, -3.8, ZF + 0.3, 0.8, 1.0, 0.2, n=14)
    for k2 in range(6):
        a = k2 * 1.05
        g["Char"].obox(-2.0 + 1.85 * math.cos(a), -4.0 + 1.85 * math.sin(a), ZF + 0.35, 0.18, 0.18, 0.5, rx=0.6 * math.sin(a))
    g["Iron"].cyl(-2.0, -4.0, ZF + 0.2, 0.06, 0.06, 1.4, seg=5)
    # 재 더미 + 불씨(아직 붉게) — 불빛 셋
    for x, y, r in ((-9.0, -6.0, 1.8), (7.5, -7.4, 1.5), (-1.0, 3.0, 1.3), (11.5, -2.0, 1.2)):
        g["Soot"].cyl(x, y, ZF, r, r * 0.35, r * 0.6, seg=12)
        g["Core"].box(x + 0.2, y - 0.1, ZF + r * 0.35, 0.35, 0.3, 0.2)
        g["Core"].box(x - 0.4, y + 0.3, ZF + r * 0.2, 0.25, 0.25, 0.15)
    for x, y in ((-9.0, -6.0), (7.5, -7.4), (-1.0, 3.0)):
        g["LampPt"].box(x, y, ZF + 1.2, 0.3, 0.3, 0.3)
    # 벽에서 떨어져 휜 구리 관 둘
    sweep(g, "Copper", [(ix1 - 0.2, -6.0, 12.0), (ix1 - 0.4, -6.0, 9.0), (ix1 - 1.6, -6.4, 5.5), (ix1 - 3.4, -7.0, ZF + 0.5)], 0.45, seg=10)
    sweep(g, "Copper", [(-6.0, iy1 - 0.2, 14.0), (-6.4, iy1 - 0.6, 10.0), (-7.4, iy1 - 2.4, ZF + 0.5)], 0.35, seg=10)
    S.gear(g, "Copper", 6.8, 8.6, ZF + 0.25, 1.6, 12, 0.4, axis="z")
    S.gear(g, "Copper", -11.0, -8.0, ZF + 1.5, 1.2, 10, 0.3, axis="y")


# =========================================================================== 2·3묶음 공통
def shell4(g, mat, W, D, T, z0, z1, door=None, coll=True, front=True):
    """속 빈 네 벽. door = (x0, x1, ztop) 앞(-y)벽 문 구멍. front=False 면 앞벽은 부르는 쪽이 짓는다"""
    box2(g, mat, -W / 2, W / 2, D / 2 - T, D / 2, z0, z1, coll)
    box2(g, mat, -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, z0, z1, coll)
    box2(g, mat, W / 2 - T, W / 2, -D / 2 + T, D / 2 - T, z0, z1, coll)
    if not front:
        return
    if door:
        wall_door(g, mat, -W / 2, W / 2, -D / 2, -D / 2 + T, z0, z1, door[0], door[1], door[2], coll)
    else:
        box2(g, mat, -W / 2, W / 2, -D / 2, -D / 2 + T, z0, z1, coll)


def door_leaf_in(g, hx, hy, z0, w, h, open_deg=100.0, side=1):
    """안으로 연 문짝. 경첩 (hx, hy), 닫힌 방향 = side·x, open_deg 만큼 +y(안)로 돈다"""
    ang = R(open_deg) if side > 0 else math.pi - R(open_deg)
    cxl, cyl = hx + math.cos(ang) * w / 2, hy + math.sin(ang) * w / 2
    g["Timber"].obox(cxl, cyl, z0 + h / 2, w, 0.3, h, rz=ang)
    for zz in (0.25, 0.55, 0.85):
        g["Iron"].obox(cxl - math.sin(ang) * 0.2, cyl + math.cos(ang) * 0.2, z0 + h * zz, w + 0.05, 0.08, 0.3, rz=ang)


def shelf_unit(g, x0, x1, y, z0, h, depth=1.0, levels=4, face=-1):
    """벽에 붙은 나무 선반(face = 앞이 -y 면 -1). 칸 높이 위 물건은 부르는 쪽이 놓는다. 칸 윗면 높이들을 돌려준다"""
    yb = y + face * depth / 2
    g["Wood"].box((x0 + x1) / 2, y + face * 0.05, z0 + h / 2, x1 - x0, 0.1, h)
    for x in (x0, x1):
        g["Wood"].box(x, yb, z0 + h / 2, 0.2, depth, h)
    tops = []
    for k in range(levels):
        z = z0 + 0.3 + k * (h - 0.4) / (levels - 1 if levels > 1 else 1)
        g["Wood"].box((x0 + x1) / 2, yb, z, x1 - x0, depth, 0.15)
        tops.append(z + 0.075)
    C((x0 + x1) / 2, yb, z0 + h / 2, x1 - x0, depth, h)
    return tops


def round_table(g, x, y, z0, r=1.6, h=2.6, stools=4, mat="Wood"):
    g[mat].cyl(x, y, z0 + h - 0.2, r, r, 0.2, seg=20)
    g["Iron"].cyl(x, y, z0, 0.12, 0.12, h - 0.2, seg=8)
    g["Iron"].cyl(x, y, z0, 0.7, 0.5, 0.12, seg=12)
    C(x, y, z0 + h / 2, 2 * r, 2 * r, h)
    for k in range(stools):
        a = 2 * math.pi * k / stools + 0.3
        sx, sy = x + (r + 1.0) * math.cos(a), y + (r + 1.0) * math.sin(a)
        g["Wood"].cyl(sx, sy, z0 + 1.5, 0.55, 0.55, 0.2, seg=12)
        g["Iron"].cyl(sx, sy, z0, 0.08, 0.08, 1.5, seg=6)


def bottle(g, x, y, z0, liquid, r=0.18, h=0.6):
    g["Glass"].cyl(x, y, z0, r, r, h, seg=8)
    g[liquid].cyl(x, y, z0 + 0.02, r * 0.8, r * 0.8, h * 0.6, seg=8)
    g["Glass"].cyl(x, y, z0 + h, r * 0.45, r * 0.45, h * 0.35, seg=6)
    g["Wood"].cyl(x, y, z0 + h * 1.35, r * 0.4, r * 0.4, 0.08, seg=6)


# =========================================================================== 상점 셋(잡화·물약·강화소)
def shop_in(sign, kind):
    def fn(g):
        W, D, T = 16.0, 12.0, 0.8
        ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T     # ±7.2, ±5.2
        ZF, ZC = 1.7, 10.1
        fy = -D / 2
        g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
        C(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
        g["Timber"].box(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)
        shell4(g, "Brick", W, D, T, 1.5, 10.5, front=False)
        # 앞벽: 문(x -6.8..-3.2) + 진열창 구멍(x -1.2..6.8, z 2.6..7.6 — 맑은 유리로 길에서 안이 보인다)
        for x0, x1, z0, z1 in ((-W / 2, -6.8, 1.5, 10.5), (-6.8, -3.2, 9.2, 10.5), (-3.2, -1.2, 1.5, 10.5),
                               (-1.2, 6.8, 1.5, 2.6), (-1.2, 6.8, 7.6, 10.5), (6.8, W / 2, 1.5, 10.5)):
            box2(g, "Brick", x0, x1, fy, iy0, z0, z1)
        C(2.8, (fy + iy0) / 2, 5.1, 8.0, T, 5.0)
        g["Wood"].box(0, 0, 10.3, W - 2 * T, D - 2 * T, 0.4)
        for y in (-2.6, 0.0, 2.6):
            g["Iron"].box(0, y, ZC - 0.2, W - 2 * T, 0.4, 0.4)
        # 겉: 옛 shop 그대로(문은 열린 문틀, 진열창은 안팎)
        g["StoneTrim"].box(0, 0, 10.9, W + 0.8, D + 0.8, 0.8)
        g["BrickDark"].box(0, 0, 11.3 + 3.75, W + 0.4, D + 0.4, 7.5)
        S.roof_gable(g, 0, 0, 18.8, W + 0.6, D + 0.6, 7.0, along="x")
        S.window(g, 2.8, fy, 2.6, 8.0, 5.0, cross=True, glass="Glass")
        S.window(g, 2.8, iy0, 2.6, 8.0, 5.0, face="+y", cross=True, sill=False, glass=None)
        for x in (-7.2, -2.8):
            g["StoneTrim"].box(x, fy - 0.3, 1.5 + 3.85, 0.8, 0.8, 7.7)
        g["StoneTrim"].box(-5.0, fy - 0.3, 9.6, 5.2, 0.8, 0.8)
        g["Stone"].box(-5.0, fy - 1.0, 0.75, 4.4, 2.0, 1.5)
        g["Stone"].box(-5.0, fy - 2.6, 0.375, 4.4, 1.2, 0.75)
        C(-5.0, fy - 1.0, 0.75, 4.4, 2.0, 1.5)
        C(-5.0, fy - 2.6, 0.375, 4.4, 1.2, 0.75)
        door_leaf_in(g, -6.7, iy0 + 0.2, ZF, 3.4, 7.3)
        g[sign].obox(0, fy - 1.6, 8.6, W - 1.0, 3.4, 0.3, rx=-0.32)
        for x in range(-6, 7, 3):
            g["StoneTrim"].obox(x, fy - 2.9, 7.9, 0.3, 0.6, 0.6, rx=-0.32)
        g["Iron"].box(W / 2 - 1.5, fy - 2.2, 14.2, 0.3, 4.4, 0.3)
        g["Brass"].box(W / 2 - 1.5, fy - 3.8, 12.6, 0.4, 3.2, 2.8)
        g[sign].box(W / 2 - 1.5, fy - 3.8, 12.6, 0.5, 2.6, 2.2)
        for x in (-4.0, 4.0):
            S.window(g, x, fy, 13.0, 2.4, 3.4)
        S.banded_cyl(g, "Copper", -W / 2 - 1.4, 2.0, 1.5, 1.1, 24.0, every=5.0)
        C(-W / 2 - 1.4, 2.0, 13.5, 2.4, 2.4, 24.0)
        S.vent(g, -W / 2 - 1.4, 2.0, 26.0)
        g["LampPt"].box(0, fy - 2.4, 10.4, 0.5, 0.5, 0.5)
        # 안: 판매대(뒤쪽 앞) + 뒷벽 선반 + 매단 등 둘 + 간판 색 띠
        g["Timber"].box(2.6, 1.2, (ZF + 5.0) / 2, 8.4, 1.6, 5.0 - ZF)
        g["Brass"].box(2.6, 1.2, 5.12, 8.7, 1.9, 0.25)
        g[sign].box(2.6, 0.38, 3.6, 8.4, 0.06, 1.0)
        C(2.6, 1.2, (ZF + 5.25) / 2, 8.7, 1.9, 5.25 - ZF)
        tops = shelf_unit(g, -6.8, 6.8, iy1, ZF, 6.6, depth=1.1, levels=4, face=-1)    # 맨 윗칸 물건이 천장(10.1)에 닿지 않게
        g[sign].box(0, iy1 - 0.12, 9.4, 12.0, 0.1, 0.9)
        for x, y in ((-3.5, -1.0), (3.8, -2.6)):
            lantern(g, x, y, ZC - 0.4, 8.0)
        yb = iy1 - 0.55
        if kind == "general":
            # 잡화: 선반에 상자·자루·병, 앞에 통·궤짝, 판매대 위 저울·장부, 벽에 밧줄 사리
            cols = ["Wood", "Canvas", "SignBlue", "Copper", "Leather", "SignGold"]
            for li, z in enumerate(tops[1:]):
                x = -6.3
                n = 0
                while x < 6.2:
                    w = 0.7 + 0.25 * ((n * 7 + li) % 3)
                    h = 0.6 + 0.3 * ((n * 5 + li) % 3)
                    mat = cols[(n * 3 + li) % len(cols)]
                    if mat == "Canvas":
                        g[mat].cyl(x + w / 2, yb, z, w / 2, w / 2 * 0.8, h, seg=10)
                    else:
                        g[mat].box(x + w / 2, yb, z + h / 2, w, 0.8, h)
                    x += w + 0.15
                    n += 1
            for x, y in ((6.2, -4.2), (4.4, -4.3)):    # 진열창 앞(문길 x -6.8..-3.2 비움)
                g["Wood"].cyl(x, y, ZF, 0.85, 0.85, 2.2, seg=14)
                g["Iron"].cyl(x, y, ZF + 0.5, 0.9, 0.9, 0.12, seg=14)
                for k in range(5):
                    sphere(g, "SignRed" if k % 2 else "SignGold", (x - 0.4 + (k % 3) * 0.4, y - 0.3 + (k // 3) * 0.5, ZF + 2.35), 0.25, sub=1)
                C(x, y, ZF + 1.1, 1.8, 1.8, 2.2)
            g["Timber"].box(-2.0, -3.9, ZF + 0.9, 1.8, 1.8, 1.8)
            g["Canvas"].cyl(-2.0, -3.9, ZF + 1.8, 0.7, 0.5, 1.2, seg=10)
            C(-2.0, -3.9, ZF + 1.4, 1.9, 1.9, 2.8)
            g["Brass"].box(5.4, 1.2, 5.5, 0.2, 0.2, 1.4)
            g["Brass"].box(5.4, 1.2, 6.2, 1.6, 0.12, 0.12)
            for s in (-1, 1):
                g["Brass"].cyl(5.4 + s * 0.75, 1.2, 5.6, 0.35, 0.4, 0.12, seg=10)
            g["Leather"].obox(1.0, 1.2, 5.32, 1.0, 0.7, 0.14, rz=0.2)
            sweep(g, "Canvas", [(ix0 + 0.25, -1.0 + 0.6 * math.cos(a / 3), 6.0 + 0.6 * math.sin(a / 3)) for a in range(0, 19)], 0.12, seg=6)
        elif kind == "potion":
            # 물약: 선반 가득 병(색), 구리 증류기, 빛나는 가마솥, 천장에 말린 약초
            liquids = ["GlowTeal", "SignPurple", "Core", "SignTeal", "Glow", "SignBlue"]
            for li, z in enumerate(tops[1:]):
                x = -6.3
                n = 0
                while x < 6.2:
                    r = 0.16 + 0.06 * ((n + li) % 3)
                    bottle(g, x + r, yb + 0.1 * ((n % 2) * 2 - 1), z, liquids[(n * 2 + li) % len(liquids)], r=r, h=0.5 + 0.15 * ((n * 3) % 3))
                    x += 2 * r + 0.12
                    n += 1
            # 증류기(판매대 왼쪽 위): 구리 둥근 솥 + 관 + 유리 받이
            sphere(g, "Copper", (-0.8, 1.2, 5.9), 0.6, sub=2)
            g["Iron"].cyl(-0.8, 1.2, 5.25, 0.5, 0.4, 0.25, seg=10)
            sweep(g, "Copper", [(-0.8, 1.2, 6.5), (-0.8, 1.2, 7.1), (0.2, 1.2, 7.1), (0.6, 1.2, 6.2), (0.6, 1.2, 5.7)], 0.07, seg=6)
            bottle(g, 0.6, 1.2, 5.25, "GlowTeal", r=0.25, h=0.45)
            # 가마솥(왼 뒤, 판매대 옆 — 문길 비움): 무쇠 솥 + 빛나는 물약 + 화로 받침
            g["Iron"].cyl(-5.2, 2.4, ZF, 1.3, 1.5, 0.9, seg=16)
            g["Iron"].cyl(-5.2, 2.4, ZF + 0.9, 1.5, 1.2, 1.6, seg=16)
            g["GlowTeal"].cyl(-5.2, 2.4, ZF + 2.35, 1.1, 1.1, 0.12, seg=16)
            g["Core"].box(-5.2, 2.4 - 1.45, ZF + 0.45, 0.8, 0.1, 0.4)
            g["LampPt"].box(-5.2, 2.4, ZF + 3.2, 0.3, 0.3, 0.3)
            C(-5.2, 2.4, ZF + 1.25, 3.0, 3.0, 2.5)
            sweep(g, "Wood", [(-5.2 - 0.6, 2.4, ZF + 2.4), (-5.2 + 0.3, 2.4 + 0.2, ZF + 3.6)], 0.07, seg=5)
            # 말린 약초 다발(천장 들보에)
            for k in range(7):
                x = -5.5 + k * 1.6
                g["Iron"].cyl(x, -1.0 + (k % 2) * 0.6, ZC - 1.4, 0.03, 0.03, 1.0, seg=4)
                g["Leather" if k % 2 else "Wood"].cyl(x, -1.0 + (k % 2) * 0.6, ZC - 2.4, 0.15, 0.35, 1.0, seg=6)
        else:
            # 강화소: 문길(x -6.8..-3.2)·판매대 앞(y -1.5..0.4)은 비운다
            #   증기 망치 = 왼 뒤(판매대 옆), 모루 = 앞 가운데, 숫돌·강화 받침 = 진열창 앞, 작은 화로 = 오른 벽 앞쪽
            HX, HY = -5.6, 2.6
            for s in (-1, 1):
                g["Iron"].box(HX + s * 1.2, HY, ZF + 3.6, 0.5, 0.8, 7.2)
            g["Iron"].box(HX, HY, ZF + 7.0, 3.0, 1.0, 0.6)
            g["Copper"].cyl(HX, HY, ZF + 4.6, 0.55, 0.55, 2.3, seg=12)
            g["Brass"].cyl(HX, HY, ZF + 2.8, 0.35, 0.35, 1.8, seg=10)
            g["Iron"].box(HX, HY, ZF + 2.5, 1.4, 1.0, 0.6)
            g["Iron"].box(HX, HY, ZF + 0.6, 2.4, 1.6, 1.2)
            C(HX, HY, ZF + 3.8, 3.2, 1.8, 7.6)
            S.pipe(g, [(HX, HY, ZF + 7.6), (ix0 + 0.4, HY, ZF + 7.6)], 0.25)
            PROP("Anvil", -0.6, -2.6, ZF, 20.0, 1.4)
            g["Timber"].cyl(-0.6, -2.6, ZF, 0.9, 0.9, 1.4, seg=12)
            C(-0.6, -2.6, ZF + 1.3, 2.0, 2.0, 2.6)
            g["Iron"].box(1.4, -4.0, ZF + 1.2, 1.4, 0.8, 2.4)
            g["Stone"].hcyl(1.4, -4.0, ZF + 2.6, 1.0, 0.35, axis="y", seg=18)
            g["Iron"].hcyl(1.4, -4.0, ZF + 2.6, 0.15, 1.0, axis="y", seg=8)
            C(1.4, -4.0, ZF + 1.6, 2.2, 1.4, 3.2)
            g["Stone"].cyl(3.6, -2.4, ZF, 0.9, 0.7, 2.4, seg=8)
            g["Core"].cyl(3.6, -2.4, ZF + 2.4, 0.75, 0.75, 0.06, seg=12)
            g["Brass"].cyl(3.6, -2.4, ZF + 2.45, 0.95, 0.95, 0.06, seg=12)
            g["Iron"].obox(3.6, -2.4, ZF + 3.4, 0.15, 0.4, 2.0, rx=0.2)
            g["Brass"].box(3.6, -2.4, ZF + 2.55, 0.6, 0.15, 0.15)
            C(3.6, -2.4, ZF + 1.2, 1.8, 1.8, 2.4)
            box2(g, "BrickDark", ix1 - 1.8, ix1, -4.4, -2.4, ZF, ZF + 3.0)
            g["Core"].box(ix1 - 1.85, -3.4, ZF + 1.2, 0.1, 1.2, 0.8)
            g["Iron"].box(ix1 - 0.9, -3.4, ZF + 3.2, 2.0, 2.2, 0.4)
            g["LampPt"].box(ix1 - 2.4, -3.4, ZF + 1.4, 0.3, 0.3, 0.3)
            for li, z in enumerate(tops[1:]):
                for k in range(6):
                    x = -6.0 + k * 2.2 + (li % 2) * 0.6
                    mat = "Iron" if (k + li) % 2 else "Brass"
                    g[mat].obox(x, yb, z + 0.15, 1.6, 0.3, 0.25, rz=0.1 * (k % 3))
    return fn


# =========================================================================== 티켓 판매점(비행선 표)
def ticket_in(g):
    W, D, T = 9.0, 7.0, 0.7
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T
    ZF, ZC = 1.2, 9.6
    fy = -D / 2
    g["Stone"].box(0, 0, 0.5, W + 1.0, D + 1.0, 1.0)
    C(0, 0, 0.5, W + 1.0, D + 1.0, 1.0)
    g["Timber"].box(0, 0, 1.1, W - 2 * T, D - 2 * T, 0.2)
    box2(g, "Timber", -W / 2, W / 2, iy1, D / 2, 1.0, 10.0)
    # 앞벽: 표 파는 창 구멍(x ±2.7, z 4.6..7.8) — 맑은 유리로 안팎이 보인다
    box2(g, "Timber", -W / 2, -2.7, -D / 2, iy0, 1.0, 10.0)
    box2(g, "Timber", 2.7, W / 2, -D / 2, iy0, 1.0, 10.0)
    box2(g, "Timber", -2.7, 2.7, -D / 2, iy0, 1.0, 4.6)
    box2(g, "Timber", -2.7, 2.7, -D / 2, iy0, 7.8, 10.0)
    C(0, (fy + iy0) / 2, 6.2, 5.4, D / 2 + iy0, 3.2)
    box2(g, "Timber", -W / 2, ix0, iy0, iy1, 1.0, 10.0)
    # 오른(+x) 벽: 문 구멍(y -0.3..2.3, 높이 7.4)
    box2(g, "Timber", ix1, W / 2, iy0, -0.3, 1.0, 10.0)
    box2(g, "Timber", ix1, W / 2, 2.3, iy1, 1.0, 10.0)
    box2(g, "Timber", ix1, W / 2, -0.3, 2.3, 8.6, 10.0)
    g["IronLight"].box(0, 0, 10.4, W + 1.6, D + 1.6, 0.6)
    g["Wood"].box(0, 0, ZC + 0.1, W - 2 * T, D - 2 * T, 0.2)
    S.pyramid(g, "RoofMetal", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4)
    S.pyramid(g, "SnowCap", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4, frac=0.6, lift=0.2)
    S.window(g, 0, fy, 4.6, 5.4, 3.2, cross=False, glass="Glass")
    S.window(g, 0, iy0, 4.6, 5.4, 3.2, face="+y", cross=False, sill=False, glass=None)
    g["StoneTrim"].box(0, fy - 0.8, 4.4, 6.4, 1.6, 0.4)
    g["Brass"].box(0, fy - 0.4, 9.0, 7.0, 0.4, 1.6)
    g["SignRed"].box(0, fy - 0.6, 9.0, 6.4, 0.25, 1.1)
    for y in (-0.6, 2.6):
        g["StoneTrim"].box(W / 2 + 0.3, y, 1.0 + 3.7, 0.7, 0.6, 7.4)
    g["StoneTrim"].box(W / 2 + 0.3, 1.0, 8.8, 0.7, 3.8, 0.6)
    g["Stone"].box(W / 2 + 1.0, 1.0, 0.5, 1.6, 3.2, 1.0)
    C(W / 2 + 1.0, 1.0, 0.5, 1.6, 3.2, 1.0)
    g["LampPt"].box(0, fy - 1.6, 8.0, 0.5, 0.5, 0.5)
    # 안: 창 앞 판매대 + 표 찍는 기계 + 의자 + 뒷벽 시간표판·항로 지도 + 금고 + 등
    g["Wood"].box(0, iy0 + 0.7, ZF + 1.6, ix1 - ix0, 1.2, 3.2)
    g["Brass"].box(0, iy0 + 0.7, ZF + 3.25, ix1 - ix0, 1.3, 0.12)
    C(0, iy0 + 0.7, ZF + 1.65, ix1 - ix0, 1.3, 3.3)
    g["Brass"].box(-1.6, iy0 + 0.8, ZF + 3.9, 1.2, 0.9, 1.2)
    g["Glow"].box(-1.6, iy0 + 0.33, ZF + 4.1, 0.7, 0.04, 0.35)
    S.gear(g, "Copper", -2.22, iy0 + 0.8, ZF + 3.9, 0.4, 10, 0.08, axis="x")
    g["Iron"].obox(-0.95, iy0 + 0.8, ZF + 4.2, 0.12, 0.12, 0.6, ry=-0.5)
    for k in range(4):
        g["Canvas"].obox(0.6 + k * 0.25, iy0 + 0.7, ZF + 3.33 + k * 0.03, 0.9, 0.5, 0.02, rz=0.15 * k)
    g["Wood"].cyl(0.0, 0.6, ZF, 0.5, 0.5, 2.0, seg=12)
    g["Leather"].cyl(0.0, 0.6, ZF + 2.0, 0.55, 0.55, 0.2, seg=12)
    g["Wood"].box(0, iy1 - 0.08, 6.0, 5.4, 0.12, 3.0)
    g["Brass"].box(0, iy1 - 0.14, 7.6, 5.6, 0.1, 0.15)
    for r in range(5):
        for c in range(3):
            g["Iron" if c else "Brass"].box(-1.9 + c * 1.6, iy1 - 0.16, 7.0 - r * 0.5, 1.2 if c else 0.6, 0.04, 0.22)
    g["Canvas"].box(ix0 + 0.06, 0.0, 6.2, 0.06, 3.4, 2.4)
    for (y0, z0_, y1, z1_) in ((-1.2, 5.4, 0.8, 6.9), (0.8, 6.9, 1.4, 5.6)):
        g["SignRed"].obox(ix0 + 0.1, (y0 + y1) / 2, (z0_ + z1_) / 2, 0.04, math.hypot(y1 - y0, z1_ - z0_), 0.08, rx=math.atan2(z1_ - z0_, y1 - y0))
    g["Iron"].box(ix0 + 0.7, iy1 - 0.7, ZF + 1.0, 1.2, 1.2, 2.0)
    g["Brass"].hcyl(ix0 + 0.7, iy1 - 1.32, ZF + 1.1, 0.3, 0.08, axis="y", seg=10)
    C(ix0 + 0.7, iy1 - 0.7, ZF + 1.0, 1.3, 1.3, 2.0)
    lantern(g, 0.6, 0.0, ZC, 7.6)


# =========================================================================== 여관(아래층 = 선술집·접수)
def inn_in(g):
    W, D, T = 24.0, 16.0, 0.8
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T     # ±11.2, ±7.2
    ZF, ZC = 1.7, 9.6
    fy = -D / 2
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    C(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Timber"].box(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)
    shell4(g, "Brick", W, D, T, 1.5, 10.0, door=(-2.2, 2.2, 9.1))
    g["Wood"].box(0, 0, 9.8, W - 2 * T, D - 2 * T, 0.4)
    for x in (-7.5, -2.5, 2.5, 7.5):
        g["Wood"].box(x, 0, ZC - 0.2, 0.5, D - 2 * T, 0.5)
    # 겉(옛 inn): 위층은 속 찬 덩이
    g["Brick"].box(0, 0, 10.0 + 9.0, W, D, 18.0)
    for z in (10.0, 19.0, 28.0):
        g["StoneTrim"].box(0, 0, z, W + 0.8, D + 0.8, 0.6)
    S.roof_gable(g, 0, 0, 28.3, W + 0.8, D + 0.8, 9.0, along="x")
    for x in (-2.6, 2.6):
        g["StoneTrim"].box(x, fy - 0.3, 1.5 + 3.85, 0.8, 0.8, 7.7)
    g["StoneTrim"].box(0, fy - 0.3, 9.5, 6.0, 0.8, 0.8)
    g["Stone"].box(0, fy - 1.0, 0.75, 5.6, 2.0, 1.5)
    g["Stone"].box(0, fy - 2.6, 0.375, 5.6, 1.2, 0.75)
    C(0, fy - 1.0, 0.75, 5.6, 2.0, 1.5)
    C(0, fy - 2.6, 0.375, 5.6, 1.2, 0.75)
    door_leaf_in(g, -2.1, iy0 + 0.2, ZF, 2.1, 7.2, 95.0, 1)
    door_leaf_in(g, 2.1, iy0 + 0.2, ZF, 2.1, 7.2, 95.0, -1)
    for z in (3.0, 12.0, 21.0):
        for x in (-8.0, -3.5, 3.5, 8.0):
            if z == 3.0 and abs(x) < 4:
                continue
            S.window(g, x, fy, z, 2.4, 4.2)
            if z == 3.0:
                S.window(g, x, iy0, z, 2.4, 4.2, face="+y", sill=False)
    g["Timber"].box(0, fy - 1.6, 10.4, 14.0, 3.2, 0.5)
    for x in range(-7, 8, 2):
        g["Iron"].box(x, fy - 3.0, 12.0, 0.25, 0.25, 3.0)
    g["Iron"].box(0, fy - 3.0, 13.5, 14.2, 0.3, 0.3)
    g["Brass"].box(0, fy - 0.5, 18.0, 10.0, 0.4, 2.6)
    g["SignPurple"].box(0, fy - 0.75, 18.0, 9.2, 0.25, 1.9)
    for x in (-8.0, 8.0):
        S.banded_cyl(g, "Iron", x, 3.0, 28.0, 0.9, 10.0, band="Brass", every=3.0)
        S.vent(g, x, 3.0, 39.0)
    g["LampPt"].box(0, fy - 2.0, 9.0, 0.6, 0.6, 0.6)
    # 안: 왼 앞 접수대 + 열쇠판, 왼 벽 벽난로, 가운데 둥근 탁자 셋, 뒤 바(통·병 선반), 오른 벽 계단(2층 문)
    g["Wood"].box(-8.4, -3.6, ZF + 1.7, 4.6, 1.4, 3.4)
    g["Brass"].box(-8.4, -3.6, ZF + 3.48, 4.9, 1.6, 0.16)
    C(-8.4, -3.6, ZF + 1.75, 4.9, 1.6, 3.5)
    sphere(g, "Brass", (-7.0, -3.7, ZF + 3.75), 0.22, sub=1)
    g["Leather"].obox(-9.2, -3.5, ZF + 3.6, 1.1, 0.8, 0.15, rz=-0.15)
    g["Wood"].box(ix0 + 0.1, -4.2, 6.2, 0.15, 3.0, 2.2)
    for r in range(3):
        for c in range(4):
            g["Brass"].box(ix0 + 0.25, -5.3 + c * 0.75, 6.9 - r * 0.7, 0.12, 0.12, 0.35)
    # 벽난로(왼 벽 가운데 뒤 — 지붕 굴뚝 x -8 쪽)
    box2(g, "Stone", ix0, ix0 + 1.6, 0.6, 5.4, ZF, ZC)
    box2(g, "Soot", ix0 + 1.55, ix0 + 1.65, 1.8, 4.2, ZF + 0.3, ZF + 2.6, coll=False)
    g["Core"].box(ix0 + 1.5, 3.0, ZF + 0.5, 0.5, 1.4, 0.4)
    g["Glow"].box(ix0 + 1.5, 3.0, ZF + 1.0, 0.3, 1.0, 0.6)
    g["StoneTrim"].box(ix0 + 1.0, 3.0, ZF + 3.2, 2.4, 5.4, 0.35)
    g["LampPt"].box(ix0 + 2.6, 3.0, ZF + 1.2, 0.3, 0.3, 0.3)
    S.gear(g, "Brass", ix0 + 1.65, 3.0, ZF + 5.4, 0.9, 12, 0.15, axis="x")
    for x, y in ((-3.5, 0.5), (1.5, -2.5), (5.5, 1.0)):
        round_table(g, x, y, ZF, r=1.4, h=2.7, stools=4)
        g["Copper"].cyl(x + 0.4, y + 0.2, ZF + 2.7, 0.2, 0.2, 0.45, seg=8)
        g["Brass"].cyl(x - 0.5, y - 0.1, ZF + 2.7, 0.18, 0.18, 0.4, seg=8)
        g["Wood"].cyl(x, y - 0.6, ZF + 2.7, 0.1, 0.1, 0.3, seg=6)
        g["Glow"].box(x, y - 0.6, ZF + 3.08, 0.12, 0.12, 0.16)
    g["Wood"].box(4.5, 5.2, ZF + 1.8, 9.0, 1.4, 3.6)
    g["Brass"].box(4.5, 5.2, ZF + 3.67, 9.3, 1.6, 0.15)
    C(4.5, 5.2, ZF + 1.85, 9.3, 1.6, 3.7)
    for x in (1.5, 4.0, 6.5):
        g["Brass"].cyl(x, 5.6, ZF + 3.75, 0.12, 0.12, 0.8, seg=8)
        g["Brass"].obox(x, 5.35, ZF + 4.5, 0.12, 0.5, 0.12)
    tops = shelf_unit(g, 0.4, 8.6, iy1, ZF + 3.8, 3.6, depth=0.6, levels=3, face=-1)
    for li, z in enumerate(tops[1:]):
        for k in range(10):
            bottle(g, 0.9 + k * 0.78, iy1 - 0.3, z, ["SignPurple", "Core", "SignTeal", "Glow"][(k + li) % 4], r=0.17, h=0.55)
    for y in (6.0, 4.0):
        g["Wood"].hcyl(-1.6, y, ZF + 1.0, 1.0, 1.9, axis="x", seg=14)
        g["Iron"].hcyl(-1.6, y, ZF + 1.0, 1.05, 0.15, axis="x", seg=14)
        g["Brass"].hcyl(-0.55, y, ZF + 1.0, 0.12, 0.3, axis="x", seg=6)
    C(-1.6, 5.0, ZF + 1.0, 2.0, 4.0, 2.1)
    # 객실로 가는 닫힌 문(오른 벽, 위층은 이번에 짓지 않음) + 간판 + 옷걸이
    g["Timber"].box(ix1 - 0.12, 3.6, ZF + 3.5, 0.2, 2.8, 7.0)
    for zz in (1.0, 3.5, 6.0):
        g["Iron"].box(ix1 - 0.25, 3.6, ZF + zz, 0.08, 2.85, 0.3)
    sphere(g, "Brass", (ix1 - 0.35, 2.5, ZF + 3.4), 0.15, sub=1)
    g["StoneTrim"].box(ix1 - 0.15, 3.6, ZF + 7.25, 0.3, 3.6, 0.5)
    g["Brass"].box(ix1 - 0.15, 3.6, ZF + 7.9, 0.12, 2.4, 0.7)
    g["SignPurple"].box(ix1 - 0.22, 3.6, ZF + 7.9, 0.06, 2.1, 0.45)
    g["Wood"].cyl(ix1 - 1.0, -2.5, ZF, 0.12, 0.12, 5.6, seg=6)
    g["Wood"].cyl(ix1 - 1.0, -2.5, ZF, 0.5, 0.4, 0.15, seg=8)
    for kk in range(4):
        a = kk * math.pi / 2
        g["Brass"].obox(ix1 - 1.0 + 0.3 * math.cos(a), -2.5 + 0.3 * math.sin(a), ZF + 5.2, 0.08, 0.08, 0.6, rx=0.6 * math.sin(a), ry=-0.6 * math.cos(a))
    g["Leather"].obox(ix1 - 0.7, -2.5, ZF + 4.3, 0.3, 0.9, 1.6, ry=0.15)
    C(ix1 - 1.0, -2.5, ZF + 2.8, 0.8, 0.8, 5.6)
    g["Banner"].box(-1.0, -1.5, ZF + 0.03, 8.0, 5.0, 0.06)
    for x, y in ((-4.5, -1.5), (4.0, 2.5)):
        lantern(g, x, y, ZC - 0.25, 7.6)


# =========================================================================== 카지노 + 경매장 — 겉은 옛 좌표 ×1.3
CK = 1.3


def casino_shell(g):
    W, D, T = 40.0, 30.0, 1.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    fy = -D / 2
    box2(g, "Brick", -W / 2, W / 2, D / 2 - T, D / 2, 2.0, 20.0, coll=False)
    box2(g, "Brick", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 2.0, 20.0, coll=False)
    # 오른 벽: 경매동으로 이어지는 문(y 1..7, 높이 8)
    box2(g, "Brick", W / 2 - T, W / 2, -D / 2 + T, 1.0, 2.0, 20.0, coll=False)
    box2(g, "Brick", W / 2 - T, W / 2, 7.0, D / 2 - T, 2.0, 20.0, coll=False)
    box2(g, "Brick", W / 2 - T, W / 2, 1.0, 7.0, 10.0, 20.0, coll=False)
    wall_door(g, "Brick", -W / 2, W / 2, -D / 2, -D / 2 + T, 2.0, 20.0, -3.0, 3.0, 10.0, coll=False)
    for x0, x1, y0, y1 in ((-W / 2 - 0.7, W / 2 + 0.7, -D / 2 - 0.7, -D / 2 + 1.0), (-W / 2 - 0.7, W / 2 + 0.7, D / 2 - 1.0, D / 2 + 0.7),
                           (-W / 2 - 0.7, -W / 2 + 1.0, -D / 2 + 1.0, D / 2 - 1.0), (W / 2 - 1.0, W / 2 + 0.7, -D / 2 + 1.0, D / 2 - 1.0)):
        box2(g, "StoneTrim", x0, x1, y0, y1, 20.0, 20.8, coll=False)
    for k in range(6):
        x = -W / 2 + 4 + k * (W - 8) / 5
        g["StoneTrim"].cyl(x, fy - 2.2, 2.0, 1.1, 1.0, 16.0, seg=12)
    g["StoneTrim"].box(0, fy - 2.2, 18.6, W - 2, 3.4, 1.0)
    g["Stone"].box(0, fy - 2.2, 2.4, W - 2, 4.4, 0.8)
    g["Brass"].hcyl(0, fy - 0.2, 13.0, 5.4, 0.4, axis="y", seg=24)
    g["Glow"].hcyl(0, fy - 0.35, 13.0, 4.8, 0.3, axis="y", seg=24)
    g["Brass"].hcyl(0, fy + T + 0.2, 13.0, 5.4, 0.4, axis="y", seg=24)
    g["Glow"].hcyl(0, fy + T + 0.35, 13.0, 4.8, 0.3, axis="y", seg=24)
    for s in (-1, 1):
        g["StoneTrim"].box(s * 3.4, fy - 0.3, 6.0, 0.8, 0.8, 8.0)
    g["StoneTrim"].box(0, fy - 0.3, 10.4, 7.6, 0.8, 0.8)
    for x in (-13, -7, 7, 13):
        S.window(g, x, fy, 5.0, 3.0, 5.0)
        S.window(g, x, fy, 13.0, 3.0, 4.0)
        S.window(g, x, fy + T, 5.0, 3.0, 5.0, face="+y", sill=False)
        S.window(g, x, fy + T, 13.0, 3.0, 4.0, face="+y", sill=False)
    g["Brass"].box(0, fy - 0.6, 23.5, 18.0, 0.5, 4.6)
    g["SignRed"].box(0, fy - 0.9, 23.5, 16.6, 0.3, 3.4)
    S.gear(g, "Brass", -10.4, fy - 0.9, 23.5, 2.2, 12, 0.4)
    S.gear(g, "Brass", 10.4, fy - 0.9, 23.5, 2.2, 12, 0.4)
    Rr = D / 2 + 0.8
    S.arc_shell(g, "RoofMetal", -W / 2 - 0.6, W / 2 + 0.6, 0, 20.8, Rr - 0.6, Rr, n=22)
    S.arc_shell(g, "SnowCap", -W / 2 - 0.3, W / 2 + 0.3, 0, 20.8, Rr, Rr + 0.6, a0=math.radians(40), a1=math.radians(140), n=12)
    for s in (-1, 1):
        S.half_disc(g, "BrickDark", s * W / 2, 0, 20.8, Rr - 0.6, 0.6)
    # 경매동(+x): 속 빈 벽(두께 1) + 앞문(열림) + 카지노 쪽 문
    ox, oy, AW, AD = W / 2 + 10, 4.0, 18.0, 22.0
    g["Stone"].box(ox, oy, 1.0, AW + 1, AD + 1, 2.0)
    box2(g, "BrickDark", ox - AW / 2 - T, ox + AW / 2, oy + AD / 2 - T, oy + AD / 2, 2.0, 16.0, coll=False)    # 서쪽 끝은 홀 벽에 붙임(틈 막기)
    box2(g, "BrickDark", ox + AW / 2 - T, ox + AW / 2, oy - AD / 2 + T, oy + AD / 2 - T, 2.0, 16.0, coll=False)
    wall_door(g, "BrickDark", ox - AW / 2 - T, ox + AW / 2, oy - AD / 2, oy - AD / 2 + T, 2.0, 16.0, ox - 2.6, ox + 2.6, 9.8, coll=False)
    S.roof_gable(g, ox, oy, 16.0, AW + 0.6, AD + 0.6, 7.0, along="y")
    g["Brass"].box(ox, oy - AD / 2 - 0.6, 12.5, 12.0, 0.4, 3.0)
    g["SignGold"].box(ox, oy - AD / 2 - 0.85, 12.5, 11.0, 0.25, 2.2)
    for yy in (-2.0, 6.0, 12.0):
        S.window(g, ox + AW / 2, yy, 5.0, 2.6, 4.0, face="+x")
        S.window(g, ox + AW / 2 - T, yy, 5.0, 2.6, 4.0, face="-x", sill=False)
    # 난로 굴뚝: 홀 뒤 왼 구석 바닥의 무쇠 난로에서 둥근 지붕을 뚫고 올라간다(지붕 속에 떠 보이지 않게 바닥부터)
    S.banded_cyl(g, "Copper", -W / 2 + 4, D / 2 - 4, 4.6, 1.4, 30.4, every=4.0)
    S.vent(g, -W / 2 + 4, D / 2 - 4, 36.0)
    g["Iron"].box(-W / 2 + 4, D / 2 - 4, 3.3, 3.2, 3.2, 2.6)
    g["Core"].box(-W / 2 + 4, D / 2 - 5.65, 3.2, 1.4, 0.1, 0.9)
    for x in (-8.0, 8.0):
        g["LampPt"].box(x, fy - 4.6, 14.0, 0.6, 0.6, 0.6)


def slot_machine(g, x, y, z0, rz):
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g["Brass"].obox(*P(0, 0), z0 + 1.6, 1.8, 1.4, 3.2, rz=rz)
    g["Iron"].obox(*P(0, 0), z0 + 3.4, 2.0, 1.6, 0.4, rz=rz)
    g["Glow"].obox(*P(0, -0.71), z0 + 2.4, 1.2, 0.05, 0.8, rz=rz)
    for k in range(3):
        g["Iron"].obox(*P(-0.4 + k * 0.4, -0.73), z0 + 2.4, 0.06, 0.04, 0.8, rz=rz)
    g["SignRed"].obox(*P(0, -0.71), z0 + 3.0, 1.4, 0.05, 0.35, rz=rz)
    g["Copper"].obox(*P(1.0, 0), z0 + 2.6, 0.12, 0.12, 1.0, rz=rz)
    sphere(g, "SignRed", (*P(1.0, 0), z0 + 3.15), 0.2, sub=1)
    g["Iron"].obox(*P(0, -0.75), z0 + 1.3, 1.2, 0.3, 0.2, rz=rz)
    S.gear(g, "Copper", *P(0, 0), z0 + 3.75, 0.5, 10, 0.12, axis="z")
    C(x, y, z0 + 1.7, 2.2, 2.2, 3.4, rz)


def casino_in(g):
    k = CK
    scaled(g, k, casino_shell)
    W, D, T = 40.0 * k, 30.0 * k, 1.0 * k
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T     # ±24.7, ±18.2
    ZF, ZT = 2.8, 20.0 * k
    # 충돌(겉): 받침·벽(앞 문 x ±3.9 높이 13 · 오른 벽 경매동 문 y 1.3..9.1 높이 13)·경매동 벽·문 앞 디딤
    C(0, 0, 1.3, (40 + 2) * k, (30 + 2) * k, 2.6)
    C(0, iy1 + T / 2, (2.6 + ZT) / 2, W, T, ZT - 2.6)
    C(-W / 2 + T / 2, 0, (2.6 + ZT) / 2, T, D, ZT - 2.6)
    for y0, y1, z0, z1 in ((-D / 2, 1.3, 2.6, ZT), (9.1, D / 2, 2.6, ZT), (1.3, 9.1, 13.0, ZT)):
        C(W / 2 - T / 2, (y0 + y1) / 2, (z0 + z1) / 2, T, y1 - y0, z1 - z0)
    for x0, x1, z0, z1 in ((-W / 2, -3.9, 2.6, ZT), (3.9, W / 2, 2.6, ZT), (-3.9, 3.9, 13.0, ZT)):
        C((x0 + x1) / 2, -D / 2 + T / 2, (z0 + z1) / 2, x1 - x0, T, z1 - z0)
    C(0, (-15 - 2.2) * k, 1.56, (40 - 2) * k, 4.4 * k, 3.12)
    C((-20 + 4) * k, (15 - 4) * k, 2.6 + 3.0, 3.4 * k, 3.4 * k, 6.0)
    C((-20 + 4) * k, (15 - 4) * k, 25.0, 2.0 * k, 2.0 * k, 40.0)
    for kx in range(6):
        C((-20 + 4 + kx * 32 / 5) * k, (-15 - 2.2) * k, 13.0, 2.8, 2.8, 20.8)
    ox, oy, AW, AD = (20 + 10) * k, 4.0 * k, 18.0 * k, 22.0 * k
    C(ox, oy, 1.3, AW + 1.3, AD + 1.3, 2.6)
    C(ox - T / 2, oy + AD / 2 - T / 2, 11.7, AW + T, T, 18.2)
    C(ox + AW / 2 - T / 2, oy, 11.7, T, AD, 18.2)
    for x0, x1, z0, z1 in ((ox - AW / 2 - T, ox - 3.4, 2.6, 20.8), (ox + 3.4, ox + AW / 2, 2.6, 20.8), (ox - 3.4, ox + 3.4, 12.7, 20.8)):
        C((x0 + x1) / 2, oy - AD / 2 + T / 2, (z0 + z1) / 2, x1 - x0, T, z1 - z0)
    # 바닥(돌) + 붉은 깔개 길 + 아치 늑골(놋쇠) 여섯
    g["Stone"].box(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    C(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    g["Banner"].box(0, -8.0, ZF + 0.03, 6.0, 20.0, 0.06)
    g["Banner"].box(12.0, 5.2, ZF + 0.03, 25.0, 4.0, 0.06)
    Rr = (15 + 0.8) * k
    zc = 20.8 * k
    for x in (-18.0, -10.8, -3.6, 3.6, 10.8, 18.0):
        S.arc_shell(g, "Brass", x - 0.35, x + 0.35, 0, zc, Rr - 1.4, Rr - 0.78, n=22)
    # 큰 샹들리에(가운데) + 벽 등
    g["Iron"].cyl(0, 0, 22.0, 0.12, 0.12, zc + Rr - 22.0 - 1.0, seg=6)
    for rr, z in ((4.0, 21.0), (2.6, 19.6), (1.4, 18.4)):
        S.ring(g, "Brass", 0, 0, z, rr - 0.25, rr, 0.35, n=32)
        for kk in range(int(rr * 4)):
            a = 2 * math.pi * kk / int(rr * 4)
            g["Glow"].box(rr * math.cos(a), rr * math.sin(a), z + 0.55, 0.2, 0.2, 0.4)
    sphere(g, "Glass", (0, 0, 17.6), 0.8, sub=2)
    g["LampPt"].box(0, 0, 19.0, 0.3, 0.3, 0.3)
    g["LampPt"].box(0, -10.0, 15.0, 0.3, 0.3, 0.3)
    g["LampPt"].box(0, 10.0, 15.0, 0.3, 0.3, 0.3)
    # 탁자마다 매단 등(룰렛 둘·카드 넷) + 옆벽 촛대 등(오른 벽은 경매장 문 앞 비움)
    for x, y in ((-10.0, -2.0), (10.0, -2.0), (-12.0, 9.0), (-4.0, 9.0), (4.0, 9.0), (12.0, 9.0)):
        lantern(g, x, y, zc + math.sqrt((Rr - 1.4) ** 2 - y * y) - 0.5, ZF + 8.5)
    for xw, s in ((ix0, 1), (ix1, -1)):
        for y in (-12.0, -4.0, 4.0, 12.0):
            if s < 0 and 0.0 < y < 10.0:
                continue
            g["Brass"].box(xw + s * 0.15, y, ZF + 7.0, 0.3, 0.9, 1.4)
            g["Brass"].obox(xw + s * 0.55, y, ZF + 7.4, 0.9, 0.15, 0.15, ry=-s * 0.5)
            g["Glow"].cyl(xw + s * 0.95, y, ZF + 7.6, 0.25, 0.25, 0.8, seg=8)
            g["LampPt"].box(xw + s * 0.95, y, ZF + 8.0, 0.3, 0.3, 0.3)
    # 룰렛 탁자 둘(가운데 양옆) + 카드 탁자 넷 + 증기 슬롯머신 줄(옆벽) + 환전 창구(뒤 왼쪽)
    for x in (-10.0, 10.0):
        g["Wood"].cyl(x, -2.0, ZF, 2.6, 2.6, 2.8, seg=28)
        g["Felt"].cyl(x, -2.0, ZF + 2.8, 2.4, 2.4, 0.06, seg=28)
        g["Wood"].cyl(x, -2.0, ZF + 2.86, 1.3, 1.3, 0.12, seg=24)
        for kk in range(18):
            a = 2 * math.pi * kk / 18
            g["SignRed" if kk % 2 else "DarkStone"].box(x + 1.1 * math.cos(a), -2.0 + 1.1 * math.sin(a), ZF + 3.0, 0.3, 0.3, 0.04)
        g["Brass"].cyl(x, -2.0, ZF + 2.98, 0.3, 0.1, 0.5, seg=10)
        sphere(g, "Marble", (x + 0.6, -2.0, ZF + 3.08), 0.1, sub=1)
        C(x, -2.0, ZF + 1.45, 5.2, 5.2, 2.9)
        for kk in range(5):
            a = math.pi * (0.6 + 0.2 * kk)
            g["Wood"].cyl(x + 3.6 * math.cos(a), -2.0 + 3.6 * math.sin(a), ZF + 1.6, 0.5, 0.5, 0.2, seg=12)
            g["Iron"].cyl(x + 3.6 * math.cos(a), -2.0 + 3.6 * math.sin(a), ZF, 0.08, 0.08, 1.6, seg=6)
    for x, y in ((-12.0, 9.0), (-4.0, 9.0), (4.0, 9.0), (12.0, 9.0)):
        g["Wood"].box(x, y, ZF + 1.4, 4.2, 2.6, 2.8)
        g["Felt"].box(x, y, ZF + 2.82, 3.9, 2.3, 0.06)
        for kk in range(5):
            g["Marble"].obox(x - 1.2 + kk * 0.6, y - 0.6 + (kk % 2) * 0.3, ZF + 2.87, 0.4, 0.6, 0.02, rz=0.2 * kk)
        for kk in range(4):
            g["SignRed" if kk % 2 else "SignBlue"].cyl(x + 1.4, y + 0.6, ZF + 2.85 + kk * 0.08, 0.16, 0.16, 0.08, seg=8)
        C(x, y, ZF + 1.4, 4.2, 2.6, 2.8)
        for sy in (-1, 1):
            for sx in (-1, 1):
                g["Wood"].cyl(x + sx * 1.2, y + sy * 2.2, ZF + 1.6, 0.5, 0.5, 0.2, seg=10)
                g["Iron"].cyl(x + sx * 1.2, y + sy * 2.2, ZF, 0.08, 0.08, 1.6, seg=6)
    for y in (-14.0, -9.0, -4.0, 1.0):
        slot_machine(g, ix0 + 1.0, y, ZF, -math.pi / 2)
        if y < 0:   # 오른 벽은 경매장 문(y 1.3..9.1) 앞을 비운다
            slot_machine(g, ix1 - 1.0, y, ZF, math.pi / 2)
    # 환전 창구(뒤 오른쪽, 놋쇠 창살)
    box2(g, "Wood", 14.0, ix1, 13.0, 13.8, ZF, ZF + 3.6)
    for kk in range(12):
        g["Brass"].box(14.3 + kk * 0.85, 13.4, ZF + 5.4, 0.12, 0.12, 3.6)
    g["Brass"].box((14.0 + ix1) / 2, 13.4, ZF + 7.25, ix1 - 14.0, 0.3, 0.3)
    g["SignGold"].box((14.0 + ix1) / 2, 13.0, ZF + 8.0, 6.0, 0.15, 1.2)
    C((14.0 + ix1) / 2, 13.4, ZF + 3.8, ix1 - 14.0, 0.8, 7.6)
    for kk in range(4):
        g["SignGold"].cyl(16.0 + kk * 0.6, 14.8, ZF + 3.6, 0.25, 0.25, 0.1 + kk * 0.05, seg=10)
    # ── 경매장(옆 동) 안: 단상 + 경매대 + 의자 줄 + 진열대 셋 + 큰 놋쇠 판
    ax0, ax1 = ox - AW / 2 + 0.0, ox + AW / 2 - T
    ay0, ay1 = oy - AD / 2 + T, oy + AD / 2 - T
    g["Timber"].box((ax0 + ax1) / 2, (ay0 + ay1) / 2, ZF - 0.1, ax1 - ax0, ay1 - ay0, 0.2)
    C((ax0 + ax1) / 2, (ay0 + ay1) / 2, ZF - 0.1, ax1 - ax0, ay1 - ay0, 0.2)
    box2(g, "Wood", ax0 + 2.0, ax1 - 2.0, ay1 - 4.5, ay1, ZF, ZF + 1.2)
    g["Banner"].box((ax0 + ax1) / 2, ay1 - 2.25, ZF + 1.23, ax1 - ax0 - 4.6, 4.0, 0.06)
    g["Wood"].box(ox, ay1 - 3.0, ZF + 1.2 + 1.8, 2.4, 1.2, 3.6)
    g["Brass"].box(ox, ay1 - 3.0, ZF + 1.2 + 3.7, 2.6, 1.4, 0.15)
    g["Wood"].obox(ox + 0.5, ay1 - 3.6, ZF + 1.2 + 3.9, 0.12, 0.12, 0.9, rx=0.6)
    g["Brass"].box(ox, ay1 - 0.15, ZF + 8.0, 10.0, 0.2, 5.0)
    g["SignGold"].box(ox, ay1 - 0.28, ZF + 8.0, 9.0, 0.1, 4.0)
    for r in range(4):
        for c in range(5):
            x = ax0 + 3.8 + c * 3.4
            y = ay0 + 3.0 + r * 3.0
            g["Wood"].box(x, y, ZF + 1.5, 1.4, 1.2, 0.2)
            g["Wood"].box(x, y + 0.55, ZF + 2.5, 1.4, 0.15, 1.8)
            for sx in (-0.6, 0.6):
                g["Iron"].cyl(x + sx, y, ZF, 0.07, 0.07, 1.5, seg=5)
        C((ax0 + ax1) / 2, ay0 + 3.0 + r * 3.0, ZF + 1.2, ax1 - ax0 - 6.0, 1.4, 2.4)
    for x, item in ((ax0 + 1.4, "gear"), (ax1 - 1.4, "vase"), (ax1 - 1.4, "orb")):
        y = ay0 + 4.0 if item != "orb" else ay0 + 10.0
        g["Marble"].box(x, y, ZF + 1.6, 1.4, 1.4, 3.2)
        if item == "gear":
            S.gear(g, "Brass", x, y, ZF + 4.2, 0.9, 12, 0.2, axis="y")
        elif item == "vase":
            g["SignBlue"].cyl(x, y, ZF + 3.2, 0.4, 0.6, 1.2, seg=12)
        else:
            sphere(g, "GlowTeal", (x, y, ZF + 3.8), 0.5, sub=2)
        g["Glass"].box(x, y, ZF + 4.1, 1.3, 1.3, 1.8)
        C(x, y, ZF + 2.5, 1.5, 1.5, 5.0)
    for x, y in ((ox - 5.0, oy - 6.0), (ox + 5.0, oy - 6.0), (ox - 5.0, oy + 2.0), (ox + 5.0, oy + 2.0)):
        lantern(g, x, y, 20.0, 10.5)
    g["LampPt"].box(ox, ay1 - 5.0, ZF + 9.0, 0.3, 0.3, 0.3)    # 단상 비춤


# =========================================================================== 공장 — 겉은 옛 좌표 ×1.3
FK2 = 1.3


def factory_shell(g):
    W, D, T = 36.0, 52.0, 1.0
    g["Stone"].box(0, 0, 1.0, W + 2, D + 2, 2.0)
    fy = -D / 2
    box2(g, "Brick", -W / 2, W / 2, D / 2 - T, D / 2, 2.0, 22.0, coll=False)
    box2(g, "Brick", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 2.0, 22.0, coll=False)
    box2(g, "Brick", W / 2 - T, W / 2, -D / 2 + T, D / 2 - T, 2.0, 22.0, coll=False)
    wall_door(g, "Brick", -W / 2, W / 2, -D / 2, -D / 2 + T, 2.0, 22.0, -6.0, 6.0, 16.0, coll=False)
    for x0, x1, y0, y1 in ((-W / 2 - 0.6, W / 2 + 0.6, -D / 2 - 0.6, -D / 2 + 1.0), (-W / 2 - 0.6, W / 2 + 0.6, D / 2 - 1.0, D / 2 + 0.6),
                           (-W / 2 - 0.6, -W / 2 + 1.0, -D / 2 + 1.0, D / 2 - 1.0), (W / 2 - 1.0, W / 2 + 0.6, -D / 2 + 1.0, D / 2 - 1.0)):
        box2(g, "StoneTrim", x0, x1, y0, y1, 22.0, 22.8, coll=False)
    S.roof_gable(g, 0, 0, 22.8, W + 1.0, D + 1.0, 10.0, along="y")
    for k in range(7):
        y = -D / 2 + 4 + k * (D - 8) / 6
        for s in (-1, 1):
            g["BrickDark"].box(s * (W / 2 + 0.4), y, 12, 0.8, 1.8, 20)
            S.window(g, s * W / 2, y + 3.2, 8.0, 2.6, 7.0, face="+x" if s > 0 else "-x")
            S.window(g, s * (W / 2 - T), y + 3.2, 8.0, 2.6, 7.0, face="-x" if s > 0 else "+x", sill=False)
    GW, GH = 12.0, 14.0
    for s in (-1, 1):
        x = s * (GW / 2 + 3.2)
        g["Timber"].box(x, fy - 0.6, 2 + GH / 2, GW / 2 + 0.2, 0.4, GH)
        for k in range(4):
            g["Iron"].box(x, fy - 0.85, 2 + GH * (k + 0.5) / 4, GW / 2 + 0.2, 0.2, 0.45)
    g["Iron"].box(0, fy - 0.85, 2 + GH + 0.4, GW * 2 + 2.0, 0.35, 0.35)
    g["StoneTrim"].box(0, fy - 0.3, 2 + GH + 0.6, GW + 2.4, 0.8, 1.2)
    for s in (-1, 1):
        g["StoneTrim"].box(s * (GW / 2 + 0.6), fy - 0.3, 2 + GH / 2, 1.2, 0.8, GH)
    g["Iron"].box(0, fy - 0.4, 20.0, 16.0, 0.5, 2.0)
    g["Brass"].box(0, fy - 0.7, 20.0, 14.6, 0.2, 1.2)
    g["Stone"].box(0, fy - 2.0, 1.0, GW + 4, 4.0, 2.0)
    g["Stone"].box(0, fy - 4.6, 0.5, GW + 4, 1.2, 1.0)
    for x, y, h in ((-10, 10, 62.0), (10, 10, 56.0), (-10, 22, 50.0), (10, 22, 66.0)):
        g["Brick"].box(x, y, 2 + h / 2, 5.0, 5.0, h)
        for z in (24.0, 40.0, h - 1.0):
            g["StoneTrim"].box(x, y, 2 + z, 5.6, 5.6, 0.8)
        g["Iron"].box(x, y, 2 + h + 0.5, 5.8, 5.8, 1.0)
        S.vent(g, x, y, 2 + h + 1.4)
    for y in (-12.0, 4.0):
        S.banded_cyl(g, "Copper", -W / 2 - 5, y, 2.0, 3.2, 16.0, every=4.0)
        S.pipe(g, [(-W / 2 - 5, y, 18.8), (-W / 2 - 5, y, 21.0), (-W / 2, y, 21.0)], 0.7)
        S.vent(g, -W / 2 - 5, y, 19.4)
    S.gear(g, "Brass", 14.0, fy - 0.6, 19.4, 2.4, 16, 0.5)    # 미닫이 문짝(x 6.1..12.3, 높이 16) 위 오른쪽


def factory_in(g):
    k = FK2
    scaled(g, k, factory_shell)
    W, D, T = 36.0 * k, 52.0 * k, 1.0 * k
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T     # ±22.1, ±32.5
    ZF, ZT = 2.8, 22.0 * k
    C(0, 0, 1.3, (36 + 2) * k, (52 + 2) * k, 2.6)
    C(0, iy1 + T / 2, (2.6 + ZT) / 2, W, T, ZT - 2.6)
    C(-W / 2 + T / 2, 0, (2.6 + ZT) / 2, T, D, ZT - 2.6)
    C(W / 2 - T / 2, 0, (2.6 + ZT) / 2, T, D, ZT - 2.6)
    for x0, x1, z0, z1 in ((-W / 2, -7.8, 2.6, ZT), (7.8, W / 2, 2.6, ZT), (-7.8, 7.8, 20.8, ZT)):
        C((x0 + x1) / 2, -D / 2 + T / 2, (z0 + z1) / 2, x1 - x0, T, z1 - z0)
    C(0, (-26 - 2.0) * k, 1.3, 16 * k, 4 * k, 2.6)
    C(0, (-26 - 4.6) * k, 0.65, 16 * k, 1.2 * k, 1.3)
    for x, y in ((-10, 10), (10, 10), (-10, 22), (10, 22)):
        C(x * k, y * k, 40.0, 5.0 * k, 5.0 * k, 80.0)
    for y in (-12.0, 4.0):
        C((-18 - 5) * k, y * k, 12.0, 6.4 * k, 6.4 * k, 20.8)
    # 바닥 + 줄무늬 쇠판 통로
    g["Stone"].box(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    C(0, 0, ZF - 0.1, W - 2 * T, D - 2 * T, 0.2)
    g["IronLight"].box(0, -6.0, ZF + 0.03, 8.0, 50.0, 0.06)
    # 지붕 트러스(맞배 밑) + 기중기 레일 + 이동 기중기
    for y in (-26.0, -13.0, 0.0, 13.0, 26.0):
        g["Iron"].box(0, y, ZT - 0.5, W - 2 * T, 0.8, 1.0)
        for s in (-1, 1):
            g["Iron"].obox(s * 11.0, y, ZT + 6.5, 0.6, 0.6, math.hypot(22.0, 13.0), ry=-s * math.atan2(22.0, 13.0))
    for x in (-14.0, 14.0):
        g["Iron"].box(x, -4.0, ZT - 2.6, 0.8, 52.0, 1.2)
    g["Iron"].box(0, 2.0, ZT - 3.6, 29.0, 1.6, 1.4)
    g["SignGold"].box(0, 1.15, ZT - 3.6, 6.0, 0.06, 0.9)
    g["Iron"].box(2.0, 2.0, ZT - 4.8, 2.4, 2.4, 1.2)
    sweep(g, "Iron", [(2.0, 2.0, ZT - 5.4)] + [(2.0 + 0.1 * math.sin(i), 2.0, ZT - 5.4 - i * 0.55) for i in range(1, 18)], 0.12, seg=6)
    hz = ZT - 5.4 - 17 * 0.55
    g["Iron"].box(2.0, 2.0, hz - 0.6, 1.4, 1.4, 0.4)
    for sx in (-1, 1):
        g["Iron"].obox(2.0 + sx * 1.2, 2.0, hz - 1.6, 0.15, 0.15, 2.2, ry=sx * 0.5)
    g["Timber"].box(2.0, 2.0, hz - 3.2, 2.6, 2.6, 2.0)
    # 조립 운반대(가운데 길이 방향) + 증기 망치 둘 + 선반 기계 셋 + 작업대 + 궤짝·통
    for x in (-5.6, -2.4):
        g["Iron"].box(x, 6.0, ZF + 2.4, 0.3, 36.0, 0.5)
        for y in range(-11, 24, 6):
            g["Iron"].box(x, y, ZF + 1.1, 0.4, 0.4, 2.2)
    for kk in range(36):
        g["Iron"].hcyl(-4.0, -11.5 + kk * 1.0, ZF + 2.55, 0.32, 3.0, axis="x", seg=10)
    for y, s in ((-8.0, 1.4), (-1.0, 1.6), (7.0, 1.2), (15.0, 1.5), (21.0, 1.3)):
        g["Timber"].box(-4.0, y, ZF + 2.9 + s / 2, s, s, s)
        S.gear(g, "Copper", -4.0, y - s / 2 - 0.05, ZF + 2.9 + s / 2, s * 0.3, 8, 0.05, axis="y")
    C(-4.0, 6.0, ZF + 1.5, 3.6, 36.0, 3.0)
    for y in (-2.0, 12.0):
        for s in (-1, 1):
            g["Iron"].box(-10.5 + s * 1.6, y, ZF + 5.0, 0.6, 1.2, 10.0)
        g["Iron"].box(-10.5, y, ZF + 10.2, 4.4, 1.6, 0.8)
        g["Copper"].cyl(-10.5, y, ZF + 6.4, 0.7, 0.7, 3.4, seg=14)
        g["Brass"].cyl(-10.5, y, ZF + 3.6, 0.45, 0.45, 2.8, seg=12)
        g["Iron"].box(-10.5, y, ZF + 3.3, 1.8, 1.2, 0.7)
        g["Iron"].box(-10.5, y, ZF + 0.8, 3.0, 2.0, 1.6)
        g["Core"].box(-10.5, y, ZF + 1.65, 1.2, 1.0, 0.1)
        S.vent(g, -9.4, y, ZF + 10.8)
        S.pipe(g, [(-10.5, y, ZF + 10.6), (-10.5, y, ZT - 1.4), (ix0 + 0.5, y, ZT - 1.4)], 0.35)
        C(-10.5, y, ZF + 5.2, 4.6, 2.2, 10.4)
    for y in (-14.0, -6.0, 2.0):
        g["Iron"].box(12.0, y, ZF + 1.6, 6.0, 1.8, 3.2)
        g["IronLight"].box(12.0, y, ZF + 3.3, 6.2, 2.0, 0.2)
        g["Brass"].hcyl(12.0, y, ZF + 4.3, 0.5, 4.0, axis="x", seg=14)
        g["Iron"].box(9.4, y, ZF + 4.3, 1.4, 1.6, 1.8)
        S.gear(g, "Brass", 9.4, y - 0.85, ZF + 4.3, 0.7, 12, 0.12, axis="y")
        g["Iron"].box(14.6, y, ZF + 4.0, 0.8, 1.2, 1.2)
        C(12.0, y, ZF + 2.4, 6.2, 2.0, 4.8)
    g["Wood"].box(ix1 - 1.4, 14.0, ZF + 2.8, 2.6, 10.0, 0.4)
    for sy in (-1, 1):
        for sx in (-1, 1):
            g["Wood"].box(ix1 - 1.4 + sx * 1.0, 14.0 + sy * 4.6, ZF + 1.3, 0.35, 0.35, 2.6)
    for kk in range(5):
        g["Iron" if kk % 2 else "Brass"].obox(ix1 - 1.4, 10.0 + kk * 2.0, ZF + 3.1, 0.6, 1.2, 0.3, rz=0.2 * kk)
    C(ix1 - 1.4, 14.0, ZF + 1.5, 2.6, 10.0, 3.0)
    for x, y, s, rz in ((16.0, 26.0, 2.8, 0.1), (19.0, 25.0, 2.4, -0.2), (17.2, 28.8, 2.6, 0.3), (16.2, 26.2, 2.2, 0.0)):
        z = ZF + s / 2 if (x, y) != (16.2, 26.2) else ZF + 2.8 + s / 2
        g["Timber"].obox(x, y, z, s, s, s, rz=rz)
    C(17.5, 26.8, ZF + 2.5, 6.0, 6.0, 5.0)
    for x, y in ((-18.0, 26.0), (-15.6, 27.6), (-18.4, 29.0)):
        g["Wood"].cyl(x, y, ZF, 1.1, 1.1, 2.8, seg=14)
        g["Iron"].cyl(x, y, ZF + 0.5, 1.15, 1.15, 0.15, seg=14)
        g["Iron"].cyl(x, y, ZF + 2.2, 1.15, 1.15, 0.15, seg=14)
    C(-17.2, 27.4, ZF + 1.4, 5.0, 5.0, 2.8)
    for x in (-10.0, 10.0):
        for y in (-22.0, -8.0, 6.0, 20.0):
            lantern(g, x, y, ZT - 1.0, 13.0)    # 바닥까지 빛이 닿게(등 반경 16)


JOBS = [
    ("Frostig_Werk", "FrosIn", job("Frostig_Werk", frostig_in)),
    ("Zapfen_Werk", "ZapfIn", job("Zapfen_Werk", zapfen_in)),
    ("Figuren_HQ", "FiguIn", job("Figuren_HQ", figuren_in)),
    ("Sel_Werk_Ruin", "SelIn", job("Sel_Werk_Ruin", sel_in)),
    ("Shop_Blue", "ShopBIn", job("Shop_Blue", shop_in("SignBlue", "general"))),
    ("Shop_Teal", "ShopTIn", job("Shop_Teal", shop_in("SignTeal", "potion"))),
    ("Shop_Red", "ShopRIn", job("Shop_Red", shop_in("SignRed", "forge"))),
    ("Ticket_Booth", "TicketIn", job("Ticket_Booth", ticket_in)),
    ("Inn_House", "InnIn", job("Inn_House", inn_in)),
    ("Casino_Hall", "CasinoIn", job("Casino_Hall", casino_in)),
    ("Steam_Factory", "FactIn", job("Steam_Factory", factory_in)),
]


def emit_luau(path):
    """COLL·PROPS → 로블록스 로컬 좌표 Luau 표(빌더가 --@@INSIDE@@ 자리에 끼운다)"""
    def f(v):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    out = ["-- models/build_steam_inside.py 가 만든 표(손으로 고치지 말 것). 로블록스 로컬 = (-x, z, y)", "local INSIDE = {"]
    for name in COLL:
        out.append("\t%s = {" % name)
        out.append("\t\tcoll = {")
        for cx, cy, cz, sx, sy, sz, rz in COLL[name]:
            out.append("\t\t\t{ %s, %s, %s, %s, %s, %s, %s }," % (f(-cx), f(cz), f(cy), f(sx), f(sz), f(sy), f(math.degrees(rz))))
        out.append("\t\t},")
        out.append("\t\tprops = {")
        for kit, x, y, z, yaw, sc, rot, speed, col in PROPS[name]:
            out.append('\t\t\t{ "%s", %s, %s, %s, %s, %s, %s, %s, %s, %s, %s },' % (
                kit, f(-x), f(z), f(y), f(yaw), f(sc), f(rot[0]), f(rot[1]), f(rot[2]),
                f(speed) if speed is not None else "nil", '"%s"' % col if col else "nil"))
        out.append("\t\t},")
        out.append("\t\tlamps = {")
        for v in LAMPS[name]:
            out.append("\t\t\t{ %s, %s, %s }," % (f(-v.x), f(v.z), f(v.y)))
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
