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
import build_steam_obs as O  # noqa: E402
from build_steam_obs import sphere, sweep  # noqa: E402

R = math.radians
COLL, PROPS, LAMPS, DIGS = {}, {}, {}, {}
_cur = [None]


def C(cx, cy, cz, sx, sy, sz, rz=0.0):
    """걸을 때 부딪히는 상자(블렌더 좌표, rz 라디안)"""
    COLL[_cur[0]].append((cx, cy, cz, sx, sy, sz, rz))


def PROP(kit, x, y, z, yaw=0.0, sc=1.0, rot=(0, 0, 0), speed=None, col=None):
    """키트 소품 자리(블렌더 좌표, yaw 도). rot = 로블록스 로컬 회전(도) 덧붙임. speed = 도는 톱니(도/초). col = 재질로 다시 칠함"""
    PROPS[_cur[0]].append((kit, x, y, z, yaw, sc, rot, speed, col))


def DIG(x0, x1, y0, y1, z0, z1, world=False):
    """마을 땅(큰 판)을 파낼 상자(블렌더 끝점). world = 세계 축 그대로 둔다(둥근 입구 굴 — 돌리면 둘레 상자가 받침 밖으로 나간다)"""
    DIGS.setdefault(_cur[0], []).append(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, world))


FIRES = {}


def FIRE(x, y, z, size=1.0):
    """진짜 불 자리(2026-10-10 사용자: 빛나는 블록 말고 불 떼는 것처럼). Snow_City2 가 불꽃·불티 입자와 깜빡이는 불빛을 단다. z = 장작 위"""
    FIRES.setdefault(_cur[0], []).append((x, y, z, size))


def fire_logs(g, x, y, z0, w, d, axis="x", size=None):
    """화덕 속 장작불: 재 바닥 + 쇠 받침살 + 엇갈린 장작 셋(끝은 숯) + 불씨 + 불 자리. w = 장작 길이 쪽 폭, d = 깊이, axis = 장작 방향"""
    ax = axis

    def BX(mat, u, v, z, su, sv, sz, rz=0.0):
        if ax == "x":
            g[mat].obox(x + u, y + v, z, su, sv, sz, rz=rz)
        else:
            g[mat].obox(x + v, y + u, z, sv, su, sz, rz=rz)
    r = max(0.1, min(w, d) * 0.16)
    BX("Soot", 0, 0, z0 + 0.03, w, d, 0.06)
    for v in (-d / 3, 0.0, d / 3):
        BX("Iron", 0, v, z0 + 0.22, w * 0.9, 0.08, 0.08)
    for u in (-w * 0.38, w * 0.38):
        BX("Iron", u, 0, z0 + 0.12, 0.08, d * 0.8, 0.2)
    for v, dz in ((-d * 0.2, 0.0), (d * 0.2, 0.0)):
        if ax == "x":
            g["Timber"].hcyl(x, y + v, z0 + 0.26 + r, r, w * 0.8, axis="x", seg=8)
        else:
            g["Timber"].hcyl(x + v, y, z0 + 0.26 + r, r, w * 0.8, axis="y", seg=8)
    if ax == "x":
        g["Char"].hcyl(x, y, z0 + 0.26 + 2.6 * r, r * 0.9, w * 0.7, axis="x", seg=8, rz=0.5)
    else:
        g["Char"].hcyl(x, y, z0 + 0.26 + 2.6 * r, r * 0.9, w * 0.7, axis="y", seg=8, rz=0.5)
    for k in range(6):
        u = (k - 2.5) * w * 0.13
        v = ((k * 7) % 5 - 2) * d * 0.1
        BX("Core", u, v, z0 + 0.1 + (k % 2) * 0.08, r * 1.3, r * 1.1, r * 0.8, rz=k * 0.9)
    FIRE(x, y, z0 + 0.3 + 2 * r, size if size is not None else max(0.3, w * 0.4))


def coal_bed(g, x, y, z0, w, d, size=None):
    """숯불 바닥(대장간·보일러 화실): 재 + 숯 덩이 + 붉은 불씨 + 불 자리"""
    g["Soot"].box(x, y, z0 + 0.05, w, d, 0.1)
    n = max(4, int(w * d * 3))
    for k in range(n):
        u = ((k * 0.618) % 1.0 - 0.5) * w * 0.85
        v = ((k * 0.382 + 0.3) % 1.0 - 0.5) * d * 0.85
        s = 0.14 + 0.08 * ((k * 3) % 3)
        g["Core" if k % 3 == 0 else "Char"].obox(x + u, y + v, z0 + 0.12 + s / 3, s, s * 0.8, s * 0.6, rz=k * 1.3)
    FIRE(x, y, z0 + 0.25, size if size is not None else max(0.3, min(w, d) * 0.5))


DOORS = {}


def DOORWAY(x0, x1, y0, y1, z0, h, depth=2.5):
    """문 앞뒤 비울 자리(2026-10-10 사용자: 입구 길막 전부 확인). (x0..x1, y0..y1) = 벽 두께를 포함한 문 구멍 바닥.
    얇은 쪽으로 depth 씩 늘리고 넓은 쪽은 문틀에서 조금 들인다. 높이는 바닥 위 0.15 ~ 사람 키(6.6)"""
    zt = z0 + min(h, 5.8)
    if x1 - x0 >= y1 - y0:
        m = min(0.4, max(0.1, (x1 - x0 - 1.2) / 2))
        DOORS.setdefault(_cur[0], []).append(((x0 + m, y0 - depth, z0 + 0.15), (x1 - m, y1 + depth, zt)))
    else:
        m = min(0.4, max(0.1, (y1 - y0 - 1.2) / 2))
        DOORS.setdefault(_cur[0], []).append(((x0 - depth, y0 + m, z0 + 0.15), (x1 + depth, y1 - m, zt)))


def CLEAR(x0, x1, y0, y1, z0, z1):
    """그 밖에 비울 자리(계단 머리·발치 등)"""
    DOORS.setdefault(_cur[0], []).append(((x0, y0, z0), (x1, y1, z1)))


def door_clear(g, name):
    """문·계단 비울 자리에 들어온 메시 덩이를 찾는다(바닥에 깔린 것 · 문틀에 닿기만 한 것은 뺀다)"""
    zones = DOORS.get(name, [])
    bad = []
    for k, grp in g.items():
        if k in ("Cut", "Pane", "LampPt", "Vent") or not grp.bm.verts:
            continue
        for vs, fs in S._comps(grp.bm):
            lo, hi = S._aabb([v.co for v in vs])
            for zi, (zl, zh) in enumerate(zones):
                if hi[2] <= zl[2] + 0.55:      # 무릎 아래(깔개·마지막 계단 단)는 넘어간다
                    continue
                if all(hi[i] - lo[i] > 2.5 * (zh[i] - zl[i]) for i in (0, 1)):    # 둘레를 두른 고리(둥근 벽·나선 손잡이)
                    continue
                if all(min(hi[i], zh[i]) - max(lo[i], zl[i]) > 0.05 for i in range(3)):
                    bad.append("      막힘 %s 자리%d: %s (%.1f..%.1f, %.1f..%.1f, %.1f..%.1f)" % (name, zi, k, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    for b in bad[:40]:
        print(b)
    return len(bad)


def job(name, fn, cut=None, owner=None):
    """cut = 벽 두께(창마다 그만큼 뚫고 맑은 유리). owner = 충돌·소품·등을 다른 틀 표에 덧붙인다(지하처럼 틀 둘로 나뉜 건물)"""
    def run(g):
        key = owner or name
        _cur[0] = key
        if owner is None:
            COLL[key], PROPS[key], LAMPS[key] = [], [], []
        S.CUT_T = cut
        try:
            fn(g)
        finally:
            S.CUT_T = None
        nc, nh, npane = S.apply_cuts(g)
        print("    %s: 구멍 %d · 자른 덩이 %d · 유리 %d" % (name, nc, nh, npane))
        nb = door_clear(g, key)
        print("    %s: 문 비울 자리 %d 곳, 막힌 덩이 %d" % (name, len(DOORS.get(key, [])), nb))
        # 등 표지(LampPt 상자)가 한 메시로 합쳐지면 빛이 건물 가운데 하나만 생긴다 → 상자마다 자리를 뽑아 따로 빛을 달고 메시는 비운다
        vs = [v.co.copy() for v in g["LampPt"].bm.verts]
        assert len(vs) % 8 == 0, (name, len(vs))
        LAMPS[key] += [sum(vs[i + 1:i + 8], vs[i]) / 8 for i in range(0, len(vs), 8)]
        g["LampPt"].bm.clear()
    return run


def room_window(g, x, y, z0, w, h, face, depth=2.0, curtain="Banner"):
    """속 찬 위층 덩이에 내는 창: 벽감(depth)을 파고 유리·커튼·벽판·작은 등을 넣어 불 켜진 방처럼 보이게(안에서 갈 수 없는 층)"""
    S.window(g, x, y, z0, w, h, face=face, cut=depth, pane_at=0.4)
    s = -1 if face[0] == "-" else 1
    zc = z0 + h / 2

    def B(mat, u, dn, z, su, sn, sz):    # dn: 벽 안쪽으로(+)
        if face[1] == "y":
            g[mat].box(x + u, y - s * dn, z, su, sn, sz)
        else:
            g[mat].box(x - s * dn, y + u, z, sn, su, sz)
    for su in (-1, 1):
        B(curtain, su * (w / 2 - 0.3), 0.65, zc, 0.6, 0.12, h)
    B(curtain, 0, 0.6, z0 + h - 0.25, w, 0.14, 0.5)
    B("Wood", 0, depth - 0.06, zc, w, 0.1, h)
    B("Brass", -w * 0.18, depth - 0.14, zc + h * 0.05, w * 0.32, 0.06, h * 0.28)
    B("Canvas", -w * 0.18, depth - 0.18, zc + h * 0.05, w * 0.26, 0.04, h * 0.22)
    B("Glow", w * 0.25, depth - 0.5, z0 + h - 0.6, 0.3, 0.3, 0.4)


def half_ring(g, mat, x, y, z, r0, r1, t, n=14):
    """y 에 선 반원 고리 테(두께 t, 아래 끝 높이 z)"""
    v = []
    for yy in (y - t / 2, y + t / 2):
        for r in (r0, r1):
            for k in range(n + 1):
                a = math.pi * k / n
                v.append((x + r * math.cos(a), yy, z + r * math.sin(a)))
    m = n + 1
    i0, o0, i1, o1 = 0, m, 2 * m, 3 * m
    f = []
    for k in range(n):
        f += [(i0 + k, o0 + k, o0 + k + 1, i0 + k + 1), (i1 + k, i1 + k + 1, o1 + k + 1, o1 + k),
              (o0 + k, o1 + k, o1 + k + 1, o0 + k + 1), (i0 + k, i0 + k + 1, i1 + k + 1, i1 + k)]
    f += [(i0, i1, o1, o0), (i0 + n, o0 + n, o1 + n, i1 + n)]
    g[mat].add_mesh(v, f)


def arch_top(g, x, y, z, r, t, frame="Brass", cut=None):
    """-y 를 보는 벽(겉면 y, 두께 t)의 네모 창 위(창 윗변 높이 z) 반원 채광창: 원통 구멍(아래 반은 창 구멍과 겹친다) + 반원 유리 + 안팎 반원 테"""
    c = cut or t     # 둥근 벽은 휘어서 더 깊게 판다(테는 벽 두께 t 에 붙인다)
    g["Cut"].hcyl(x, y + c / 2, z, r, c + 0.04, axis="y", seg=16)
    L.transformed(g, Matrix.Translation((x, y + t / 2, z)) @ Matrix.Rotation(math.pi / 2, 4, "Z"),
                  lambda q: S.half_disc(q, "Pane", 0, 0, 0, r, 0.08))
    for yy in (y - 0.15, y + t + 0.15):
        half_ring(g, frame, x, yy, z, r - 0.05, r + 0.3, 0.24)


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
    S.hole(g, SX, fy, 3.3 + SH / 2, SW, SH, "-y", T)
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
        room_window(g, x, fy - 0.6, 14.5, 2.6, 3.8, "-y", 2.2)
    for x in (-5.0, 5.0):
        g["BrickDark"].box(x, fy + 2.4, 25.0, 3.6, 3.0, 3.6)
        g["RoofMetal"].obox(x, fy + 2.2, 27.3, 4.6, 3.6, 0.4, rx=-0.3)
        room_window(g, x, fy + 0.9, 23.6, 2.2, 2.4, "-y", 1.8)
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
    FIRE(8.6, 3.4, ZF + 2.4, 0.5)
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
    DOORWAY(-8.0, -4.0, -9.0, -8.2, ZF, 8.0)


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
            arch_top(g, x, fy, 16.0, 1.5, T)
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
            room_window(g, ox + 7.0, yy, z, 2.2, 3.2, "+x", 2.0)
    S.door(g, ox, 4.0 - 8.0, 2.0, 3.0, 6.6)
    room_window(g, ox + 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2, "-y", 2.0)
    room_window(g, ox - 3.8, 4.0 - 8.0, 12.0, 2.2, 3.2, "-y", 2.0)
    lx = -W / 2 - 5.0
    g["Timber"].box(lx, -6.0, 1.5, 10.0, 14.0, 3.0)
    for x, y, s in ((-1.5, -9.0, 3.2), (1.8, -8.6, 2.6), (-1.0, -4.5, 3.0), (-1.2, -9.0, 2.4)):
        z = 3.0 + s / 2 if s != 2.4 else 3.0 + 3.2 + 1.2
        g["Timber"].box(lx + x, y, z, s, s, s)
        g["Iron"].box(lx + x, y, z, s + 0.1, s + 0.1, 0.3)


def telescope_build(g, ZF, hook):
    """천문대가 맡긴 초거대 굴절 망원경(사용자 2026-10-10: 로봇 대신). 공방 바닥에서 조립 중:
    경통 셋(둘은 이어 붙였고 셋째는 옆 받침에서 기다림) · 접안부 · 대물렌즈를 닦는 회전대 · 짓고 있는 적도의 받침(극축·포크 한쪽) ·
    기중기 갈고리에 매달린 렌즈 테 · 천문대 설계도 판 · 천문대 문장이 찍힌 궤짝"""
    ty, tz, r = -2.0, ZF + 6.4, 2.5
    # 경통 A(-3..6) + B(6..15) 이어 붙임, 테·리벳 줄
    for x0, x1 in ((-3.0, 6.0), (6.0, 15.0)):
        g["Brass"].hcyl((x0 + x1) / 2, ty, tz, r, x1 - x0, axis="x", seg=28)
        for xx in (x0 + 0.2, x1 - 0.2):
            g["Iron"].hcyl(xx, ty, tz, r + 0.25, 0.45, axis="x", seg=28)
        for k in range(12):
            a = 2 * math.pi * k / 12
            g["Iron"].obox((x0 + x1) / 2, ty + (r + 0.05) * math.cos(a), tz + (r + 0.05) * math.sin(a), x1 - x0 - 0.8, 0.12, 0.12, rx=a)
    # 접안부(뒤 끝): 좁아지는 마개 + 초점 통 + 손잡이 둘 + 파인더
    g["Iron"].hcyl(-3.6, ty, tz, 1.6, 1.0, axis="x", seg=20)
    g["Brass"].hcyl(-5.0, ty, tz, 0.7, 2.0, axis="x", seg=14)
    g["Iron"].hcyl(-6.3, ty, tz, 0.45, 0.8, axis="x", seg=10)
    for s in (-1, 1):
        g["Brass"].obox(-4.6, ty + s * 1.0, tz, 0.3, 0.8, 0.3)
        sphere(g, "Brass", (-4.6, ty + s * 1.45, tz), 0.3, sub=1)
    g["Brass"].hcyl(2.0, ty, tz + r + 1.2, 0.5, 5.0, axis="x", seg=12)
    for xx in (0.5, 3.5):
        g["Iron"].box(xx, ty, tz + r + 0.6, 0.3, 0.3, 1.0)
    # 경통 C(16.5..24, 옆 받침 위 — 아직 안 붙임) + 열린 앞끝(속 가림 고리)
    cy2 = ty + 0.6
    g["Brass"].hcyl(20.25, cy2, tz, r, 7.5, axis="x", seg=28)
    g["Iron"].hcyl(16.7, cy2, tz, r + 0.25, 0.45, axis="x", seg=28)
    for xx in (23.6, 22.0):
        L.transformed(g, Matrix.Translation((xx, cy2, tz)) @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                      lambda q: S.ring(q, "Iron", 0, 0, -0.15, r - 0.6, r + 0.25, 0.3, n=28))
    g["Soot"].hcyl(19.0, cy2, tz, r - 0.1, 0.1, axis="x", seg=24)
    # 받침(나무 V 받침 넷) + 충돌
    for xx, yy in ((0.0, ty), (11.0, ty), (18.0, cy2), (22.5, cy2)):
        g["Timber"].box(xx, yy, ZF + 1.2, 1.4, 6.0, 2.4)
        for s in (-1, 1):
            g["Timber"].obox(xx, yy + s * 1.9, tz - r + 0.3, 1.4, 2.0, 0.5, rx=-s * 0.7)
        g["Iron"].box(xx, yy, ZF + 2.5, 1.5, 6.1, 0.2)
    C(6.0, ty, tz, 19.0, 2 * r + 0.6, 2 * r + 0.6)
    C(20.25, cy2, tz, 7.6, 2 * r + 0.6, 2 * r + 0.6)
    C(-4.8, ty, tz, 3.4, 3.2, 3.2)
    # 대물렌즈 닦는 회전대(앞 왼쪽): 무쇠 대 + 유리 렌즈 + 닦는 팔 + 붉은 연마제 통
    lx, ly = -2.0, -9.0
    g["Iron"].cyl(lx, ly, ZF, 3.4, 3.0, 2.4, seg=24)
    g["Brass"].cyl(lx, ly, ZF + 2.4, 3.2, 3.2, 0.2, seg=24)
    g["Glass"].cyl(lx, ly, ZF + 2.6, 3.0, 2.6, 0.6, seg=28)
    g["Iron"].box(lx + 4.0, ly, ZF + 2.2, 0.8, 0.8, 4.4)
    g["Iron"].obox(lx + 2.4, ly, ZF + 4.3, 3.4, 0.4, 0.4, ry=0.15)
    g["Brass"].cyl(lx + 0.9, ly, ZF + 3.2, 0.7, 0.7, 0.4, seg=12)
    g["SignRed"].cyl(lx + 4.4, ly + 2.4, ZF, 0.6, 0.6, 1.2, seg=12)
    C(lx, ly, ZF + 1.6, 6.8, 6.8, 3.2)
    C(lx + 4.0, ly, ZF + 2.2, 0.9, 0.9, 4.4)
    # 적도의 받침(뒤): 돌 기둥 + 기운 극축 통(위도 40 도, 앞 -y 로) + 포크 한쪽(다른 쪽은 바닥에)
    px, py = 8.0, 13.0
    g["Stone"].box(px, py, ZF + 1.6, 4.4, 4.4, 3.2)
    g["StoneTrim"].box(px, py, ZF + 3.3, 4.8, 4.8, 0.3)
    C(px, py, ZF + 1.6, 4.4, 4.4, 3.2)
    ax = (0.0, -math.cos(R(40)), math.sin(R(40)))
    base = (px, py + 0.6, ZF + 4.0)
    mid = tuple(b + a * 3.0 for b, a in zip(base, ax))
    g["Iron"].obox(*mid, 2.4, 2.4, 6.0, rx=-(math.pi / 2 - R(40)))
    top = tuple(b + a * 6.2 for b, a in zip(base, ax))
    g["Brass"].obox(*top, 3.4, 3.4, 0.5, rx=-(math.pi / 2 - R(40)))
    g["Iron"].box(top[0] - 1.6, top[1], top[2] + 2.6, 0.7, 1.2, 5.6)        # 포크 한쪽(세움)
    g["Iron"].obox(px + 3.0, py + 3.5, ZF + 0.4, 5.6, 1.2, 0.7, rz=0.3)     # 다른 쪽(바닥에 눕힘)
    S.gear(g, "Brass", px, py + 2.3, ZF + 4.4, 1.6, 24, 0.3, axis="y")
    C(px, py - 1.0, ZF + 6.0, 4.0, 5.0, 6.0)
    C(px + 3.0, py + 3.5, ZF + 0.4, 5.6, 1.6, 0.8, 0.3)
    # 갈고리에 매달린 렌즈 테(세로 고리) + 사슬
    hx, hy, hz = hook
    g["Iron"].box(hx, hy, hz - 1.0, 2.4, 0.4, 0.3)
    for s in (-1, 1):
        sweep(g, "Iron", [(hx + s * 1.1, hy, hz - 1.1), (hx + s * 1.9, hy, hz - 3.4)], 0.07, seg=5)
    L.transformed(g, Matrix.Translation((hx, hy, hz - 5.6)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                  lambda q: (S.ring(q, "Brass", 0, 0, -0.25, 2.0, 2.4, 0.5, n=28), S.ring(q, "Iron", 0, 0, -0.3, 1.85, 2.0, 0.6, n=28)))
    # 천문대 설계도 판(이젤) — 경통·돔 그림 + 천문대 문장(별)
    ex, ey = -12.0, -6.0
    for s in (-1, 1):
        g["Wood"].obox(ex + s * 1.6, ey, ZF + 3.0, 0.2, 0.2, 6.2, rx=0.15)
    g["Wood"].obox(ex, ey + 1.1, ZF + 2.8, 0.2, 0.2, 5.8, rx=-0.45)
    g["Wood"].obox(ex, ey - 0.25, ZF + 3.2, 4.0, 0.1, 3.0, rx=0.15)
    g["SignBlue"].obox(ex, ey - 0.33, ZF + 3.2, 3.6, 0.04, 2.6, rx=0.15)
    g["Marble"].obox(ex - 0.2, ey - 0.38, ZF + 3.0, 2.6, 0.02, 0.5, rx=0.15, ry=0.25)
    g["Marble"].obox(ex + 1.0, ey - 0.38, ZF + 3.9, 0.9, 0.02, 0.9, rx=0.15)
    g["Glow"].obox(ex + 1.0, ey - 0.4, ZF + 3.9, 0.3, 0.02, 0.3, rx=0.15)
    g["Wood"].box(ex, ey - 0.5, ZF + 1.75, 3.6, 0.5, 0.12)
    C(ex, ey, ZF + 3.0, 3.8, 2.0, 6.0)
    # 천문대에서 온 궤짝(문장 판) 무더기
    for i, (dx, dy, s_, lv) in enumerate(((0, 0, 2.6, 0), (2.8, 0.2, 2.4, 0), (1.2, 2.6, 2.2, 0), (0.8, 0.6, 2.0, 1))):
        x, y = 15.0 + dx, -7.5 + dy
        z = ZF + s_ / 2 + (2.6 if lv else 0.0)
        g["Timber"].obox(x, y, z, s_, s_, s_, rz=0.12 * (i - 1))
        g["SignBlue"].obox(x, y - s_ / 2 - 0.02, z, s_ * 0.5, 0.04, s_ * 0.5, rz=0.12 * (i - 1))
        g["Brass"].obox(x, y - s_ / 2 - 0.05, z, s_ * 0.2, 0.04, s_ * 0.2, rz=0.12 * (i - 1))
    C(16.4, -6.2, ZF + 2.4, 5.4, 5.4, 4.8)


def work_bench(g, x, y, z0, length, rz=0.0):
    """작업대(나무 상판 + 무쇠 다리 + 바이스 + 연장 + 부품)"""
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g["Wood"].obox(x, y, z0 + 2.8, length, 2.2, 0.3, rz=rz)
    for u in (-length / 2 + 0.4, length / 2 - 0.4):
        for v in (-0.8, 0.8):
            g["Iron"].obox(*P(u, v), z0 + 1.35, 0.25, 0.25, 2.7, rz=rz)
    g["Wood"].obox(x, y, z0 + 0.7, length - 0.6, 1.8, 0.15, rz=rz)
    g["Iron"].obox(*P(-length / 2 + 1.0, -0.9), z0 + 3.3, 0.7, 0.6, 0.7, rz=rz)
    g["Iron"].obox(*P(-length / 2 + 1.0, -1.3), z0 + 3.5, 0.12, 0.9, 0.12, rz=rz)
    for k in range(4):
        g["Iron" if k % 2 else "Brass"].obox(*P(-0.8 + k * 0.7, 0.3), z0 + 3.0, 0.15, 1.0, 0.1, rz=rz + 0.3 * k)
    S.gear(g, "Brass", *P(length / 2 - 1.2, 0.0), z0 + 2.98, 0.5, 9, 0.1, axis="z")
    g["Copper"].obox(*P(length / 2 - 2.4, -0.2), z0 + 3.2, 0.9, 0.5, 0.5, rz=rz)
    C(x, y, z0 + 1.5, length if abs(s) < 0.5 else 2.2, 2.2 if abs(s) < 0.5 else length, 3.0)


def work_lamp(g, x, y, z0, lean=0.3):
    """세워 두는 작업등(무쇠 삼발이 + 기둥 + 갓 + 불빛)"""
    for k in range(3):
        a = 2 * math.pi * k / 3
        g["Iron"].obox(x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), z0 + 0.4, 0.12, 0.12, 1.0, rx=0.6 * math.sin(a), ry=-0.6 * math.cos(a))
    g["Iron"].cyl(x, y, z0 + 0.6, 0.08, 0.08, 6.0, seg=6)
    g["Brass"].cyl(x, y, z0 + 6.4, 0.7, 0.25, 0.7, seg=12)
    g["Glow"].cyl(x, y, z0 + 6.25, 0.5, 0.5, 0.15, seg=10)
    g["LampPt"].box(x, y, z0 + 5.9, 0.3, 0.3, 0.3)
    C(x, y, z0 + 3.4, 1.2, 1.2, 6.8)


def zapfen_more(g, ZF, ZT, hook):
    """공방 가운데: 천문대가 맡긴 초거대 망원경 조립(사용자 2026-10-10 — 로봇 대신), 앞 작업대 둘, 뒤 부품 선반, 작업등 셋, 바닥 기름 얼룩"""
    telescope_build(g, ZF, hook)
    for x in (-6.0, 9.0):
        work_bench(g, x, -14.0, ZF, 7.0)
    for x in (-8.0, 17.5):
        work_bench(g, x, 0.5 if x < 0 else 12.0, ZF, 6.0, rz=math.pi / 2)    # 기둥(±14, ±10) 피함
    # 뒤 부품 선반(뒷벽 — 가운데 굴뚝 기둥 x ±3 과 오른쪽 큰 톱니 x 4.9..19.9 를 피해 왼쪽에 둘)
    for x0 in (-16.5, -10.0):
        x1 = x0 + 5.5
        for xx in (x0, x1):
            g["Iron"].box(xx, 19.8, ZF + 3.5, 0.25, 1.2, 7.0)
        for zz in (0.4, 2.6, 4.8, 7.0):
            g["IronLight"].box((x0 + x1) / 2, 19.8, ZF + zz, x1 - x0, 1.2, 0.12)
        for li, zz in enumerate((0.5, 2.7, 4.9)):
            for k in range(4):
                xx = x0 + 0.7 + k * 1.2
                if (k + li) % 2:
                    S.gear(g, "Brass" if k % 3 else "Copper", xx, 19.8, ZF + zz + 0.55, 0.5, 9, 0.1, axis="y")
                else:
                    g["Timber"].box(xx, 19.8, ZF + zz + 0.45, 0.9, 0.9, 0.9)
        C((x0 + x1) / 2, 19.8, ZF + 3.5, x1 - x0, 1.3, 7.0)
    for x, y in ((-3.0, 2.0), (11.0, 2.0), (4.5, -7.0)):
        work_lamp(g, x, y, ZF)
    for x, y, r in ((0.5, -2.0, 1.4), (7.5, 13.0, 1.0), (-12.0, -6.0, 1.2), (18.0, -8.0, 0.9)):
        g["Soot"].cyl(x, y, ZF + 0.01, r, r, 0.02, seg=12)


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
        S.hole(g, bx, -16.2, ZF + 2.4, 1.6, 1.1, "-y", 1.4, pane=False)
        coal_bed(g, bx, -15.4, ZF + 1.85, 1.3, 0.9, size=0.45)
        g["Iron"].obox(bx - 1.15, -16.6, ZF + 2.4, 0.9, 0.08, 1.1, rz=0.9)
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
            lantern(g, x, y, ZT - 1.4, 14.0)    # 바닥까지 빛이 닿게
    zapfen_more(g, ZF, ZT, (0.0, 4.0, hz))
    DOORWAY(-7.8, 7.8, -22.1, -20.8, ZF, 16.7)
    CLEAR(ix0 + 0.3, ix0 + 3.7, -19.5, -17.2, ZF + 0.15, ZF + 6.6)
    CLEAR(ix0 + 0.3, ix0 + 3.7, -2.8, -0.5, ZM + 0.15, ZM + 6.6)
    for x in (-36.0, 36.0):
        g["LampPt"].box(x, -8.0, 10.0, 0.3, 0.3, 0.3)


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
    for x, y, r in ((-9.0, -6.0, 1.8), (7.5, -7.4, 1.5), (-1.0, 3.0, 1.3)):
        FIRE(x, y, ZF + r * 0.55, 0.3)
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
        shell4(g, "Brick", W, D, T, 1.5, 10.5, door=(-6.8, -3.2, 9.2))    # 진열창(x -1.2..6.8)은 창이 뚫는다
        g["Wood"].box(0, 0, 10.3, W - 2 * T, D - 2 * T, 0.4)
        for y in (-2.6, 0.0, 2.6):
            g["Iron"].box(0, y, ZC - 0.2, W - 2 * T, 0.4, 0.4)
        # 겉: 옛 shop 그대로(문은 열린 문틀, 진열창은 안팎)
        g["StoneTrim"].box(0, 0, 10.9, W + 0.8, D + 0.8, 0.8)
        g["BrickDark"].box(0, 0, 11.3 + 3.75, W + 0.4, D + 0.4, 7.5)
        S.roof_gable(g, 0, 0, 18.8, W + 0.6, D + 0.6, 7.0, along="x")
        S.window(g, 2.8, fy, 2.6, 8.0, 5.0, cross=True)
        S.window(g, 2.8, iy0, 2.6, 8.0, 5.0, face="+y", cross=True, sill=False)
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
            room_window(g, x, fy - 0.2, 13.0, 2.4, 3.4, "-y", 2.0)    # 위층(속 찬 덩이 겉면 fy-0.2)
        S.banded_cyl(g, "Copper", -W / 2 - 1.4, 2.0, 1.5, 1.1, 24.0, every=5.0)
        C(-W / 2 - 1.4, 2.0, 13.5, 2.4, 2.4, 24.0)
        S.vent(g, -W / 2 - 1.4, 2.0, 26.0)
        g["LampPt"].box(0, fy - 2.4, 10.4, 0.5, 0.5, 0.5)
        # 안: 판매대(뒤쪽 앞) + 뒷벽 선반 + 매단 등 둘 + 간판 색 띠
        # 판매대(사람 크기: 허리 높이 3.05, 뒤 점원 길 2.8 — y -0.3..1.3, 선반 앞 4.1)
        g["Timber"].box(2.6, 0.5, (ZF + 4.6) / 2, 8.4, 1.6, 4.6 - ZF)
        g["Brass"].box(2.6, 0.5, 4.72, 8.7, 1.9, 0.25)
        g[sign].box(2.6, -0.32, 3.3, 8.4, 0.06, 1.0)
        C(2.6, 0.5, (ZF + 4.85) / 2, 8.7, 1.9, 4.85 - ZF)
        tops = shelf_unit(g, -6.8, 6.8, iy1, ZF, 6.6, depth=1.1, levels=4, face=-1)    # 맨 윗칸 물건이 천장(10.1)에 닿지 않게
        g[sign].box(0, iy1 - 0.12, 9.4, 12.0, 0.1, 0.9)
        for x, y in ((-3.5, -1.0), (3.8, -2.6)):
            lantern(g, x, y, ZC - 0.4, 8.0)
        DOORWAY(-6.8, -3.2, fy, iy0, ZF, 7.5)
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
            g["Brass"].box(5.4, 0.5, 5.1, 0.2, 0.2, 1.4)
            g["Brass"].box(5.4, 0.5, 5.8, 1.6, 0.12, 0.12)
            for s in (-1, 1):
                g["Brass"].cyl(5.4 + s * 0.75, 0.5, 5.2, 0.35, 0.4, 0.12, seg=10)
            g["Leather"].obox(1.0, 0.5, 4.92, 1.0, 0.7, 0.14, rz=0.2)
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
            sphere(g, "Copper", (-0.8, 0.5, 5.5), 0.6, sub=2)
            g["Iron"].cyl(-0.8, 0.5, 4.85, 0.5, 0.4, 0.25, seg=10)
            sweep(g, "Copper", [(-0.8, 0.5, 6.1), (-0.8, 0.5, 6.7), (0.2, 0.5, 6.7), (0.6, 0.5, 5.8), (0.6, 0.5, 5.3)], 0.07, seg=6)
            bottle(g, 0.6, 0.5, 4.85, "GlowTeal", r=0.25, h=0.45)
            # 가마솥(왼 뒤, 판매대 옆 — 문길 비움): 무쇠 솥 + 빛나는 물약 + 화로 받침
            g["Iron"].cyl(-5.2, 2.4, ZF, 1.3, 1.5, 0.9, seg=16)
            g["Iron"].cyl(-5.2, 2.4, ZF + 0.9, 1.5, 1.2, 1.6, seg=16)
            g["GlowTeal"].cyl(-5.2, 2.4, ZF + 2.35, 1.1, 1.1, 0.12, seg=16)
            S.hole(g, -5.2, 2.4 - 1.4, ZF + 0.45, 0.9, 0.6, "-y", 1.0, pane=False)
            coal_bed(g, -5.2, 2.4 - 0.85, ZF + 0.15, 0.7, 0.6, size=0.3)
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
            PROP("Anvil", -1.0, -3.4, ZF, 20.0, 1.4)
            g["Timber"].cyl(-1.0, -3.4, ZF, 0.9, 0.9, 1.4, seg=12)
            C(-1.0, -3.4, ZF + 1.3, 2.0, 2.0, 2.6)
            g["Iron"].box(1.4, -4.0, ZF + 1.2, 1.4, 0.8, 2.4)
            g["Stone"].hcyl(1.4, -4.0, ZF + 2.6, 1.0, 0.35, axis="y", seg=18)
            g["Iron"].hcyl(1.4, -4.0, ZF + 2.6, 0.15, 1.0, axis="y", seg=8)
            C(1.4, -4.0, ZF + 1.6, 2.2, 1.4, 3.2)
            g["Stone"].cyl(3.8, -3.6, ZF, 0.9, 0.7, 2.4, seg=8)
            g["Core"].cyl(3.8, -3.6, ZF + 2.4, 0.75, 0.75, 0.06, seg=12)
            g["Brass"].cyl(3.8, -3.6, ZF + 2.45, 0.95, 0.95, 0.06, seg=12)
            g["Iron"].obox(3.8, -3.6, ZF + 3.4, 0.15, 0.4, 2.0, rx=0.2)
            g["Brass"].box(3.8, -3.6, ZF + 2.55, 0.6, 0.15, 0.15)
            C(3.8, -3.6, ZF + 1.2, 1.8, 1.8, 2.4)
            box2(g, "BrickDark", ix1 - 1.8, ix1, -4.4, -2.4, ZF, ZF + 3.0)
            S.hole(g, ix1 - 1.8, -3.4, ZF + 1.4, 1.3, 1.1, "-x", 1.3, pane=False)
            coal_bed(g, ix1 - 1.15, -3.4, ZF + 0.85, 1.0, 1.0, size=0.45)
            g["Iron"].box(ix1 - 0.9, -3.4, ZF + 3.2, 2.0, 2.2, 0.4)
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
    box2(g, "Timber", -W / 2, W / 2, -D / 2, iy0, 1.0, 10.0)    # 앞벽(표 파는 창 구멍은 창이 뚫는다)
    box2(g, "Timber", -W / 2, ix0, iy0, iy1, 1.0, 10.0)
    # 오른(+x) 벽: 문 구멍(y -0.3..2.3, 높이 7.4)
    box2(g, "Timber", ix1, W / 2, iy0, -0.3, 1.0, 10.0)
    box2(g, "Timber", ix1, W / 2, 2.3, iy1, 1.0, 10.0)
    box2(g, "Timber", ix1, W / 2, -0.3, 2.3, 8.6, 10.0)
    g["IronLight"].box(0, 0, 10.4, W + 1.6, D + 1.6, 0.6)
    g["Wood"].box(0, 0, ZC + 0.1, W - 2 * T, D - 2 * T, 0.2)
    S.pyramid(g, "RoofMetal", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4)
    S.pyramid(g, "SnowCap", 0, 0, 10.7, W + 1.6, D + 1.6, 3.4, frac=0.6, lift=0.2)
    S.window(g, 0, fy, 4.6, 5.4, 3.2, cross=False)
    S.window(g, 0, iy0, 4.6, 5.4, 3.2, face="+y", cross=False, sill=False)
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
    DOORWAY(ix1, W / 2, -0.3, 2.3, ZF, 7.4)


# =========================================================================== 여관(아래층 = 선술집·접수)
def bed(g, x, y, z0, rz=0.0, mat="Banner"):
    """침대(머리판 쪽 = 로컬 -u). 길이 6 · 폭 3.6 · 매트 높이 2.2"""
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g["Wood"].obox(x, y, z0 + 1.0, 6.0, 3.6, 0.6, rz=rz)
    g["Canvas"].obox(*P(0.2, 0), z0 + 1.6, 5.6, 3.4, 0.6, rz=rz)
    g[mat].obox(*P(1.0, 0), z0 + 1.95, 3.8, 3.5, 0.15, rz=rz)
    g["Canvas"].obox(*P(-2.2, 0), z0 + 2.05, 1.0, 2.8, 0.4, rz=rz)
    g["Wood"].obox(*P(-3.1, 0), z0 + 2.2, 0.3, 3.8, 4.4, rz=rz)
    g["Wood"].obox(*P(2.9, 0), z0 + 1.3, 0.3, 3.8, 2.6, rz=rz)
    for u in (-2.85, 2.75):
        for v in (-1.7, 1.7):
            g["Wood"].obox(*P(u, v), z0 + 0.35, 0.3, 0.3, 0.7, rz=rz)
    C(x, y, z0 + 1.2, 6.2 if abs(s) < 0.5 else 3.8, 3.8 if abs(s) < 0.5 else 6.2, 2.4)


def wardrobe(g, x, y, z0, face):
    """옷장(앞 = face '+x' '-x' '+y' '-y')"""
    sx = {"+x": 1, "-x": -1}.get(face, 0)
    sy = {"+y": 1, "-y": -1}.get(face, 0)
    w, d, h = 3.0, 1.6, 7.0
    bx, by = (d, w) if sx else (w, d)
    g["Wood"].box(x, y, z0 + h / 2, bx, by, h)
    g["Timber"].box(x + sx * (d / 2 + 0.03), y + sy * (d / 2 + 0.03), z0 + h / 2, 0.06 if sx else w - 0.4, w - 0.4 if sx else 0.06, h - 0.6)
    for k in (-1, 1):
        ox, oy = (0, k * 0.3) if sx else (k * 0.3, 0)
        sphere(g, "Brass", (x + sx * (d / 2 + 0.12) + ox, y + sy * (d / 2 + 0.12) + oy, z0 + 3.6), 0.12, sub=1)
    C(x, y, z0 + h / 2, bx, by, h)


def washstand(g, x, y, z0, face):
    """세면대(대리석 판 + 놋쇠 대야 + 물병 + 위 거울). face = 벽에서 방 쪽"""
    sx = {"+x": 1, "-x": -1}.get(face, 0)
    sy = {"+y": 1, "-y": -1}.get(face, 0)
    g["Wood"].box(x, y, z0 + 1.4, 2.4 if sy else 1.2, 1.2 if sy else 2.4, 2.8)
    g["Marble"].box(x, y, z0 + 2.9, 2.6 if sy else 1.4, 1.4 if sy else 2.6, 0.2)
    g["Brass"].cyl(x, y, z0 + 3.0, 0.5, 0.35, 0.3, seg=12)
    g["Glass"].cyl(x + 0.7 * (1 if sy else 0), y + 0.7 * (1 if sx else 0), z0 + 3.0, 0.2, 0.15, 0.7, seg=8)
    g["Brass"].box(x - sx * 0.55, y - sy * 0.55, z0 + 5.0, 0.1 if sx else 1.8, 1.8 if sx else 0.1, 2.2)
    g["Glass"].box(x - sx * 0.5, y - sy * 0.5, z0 + 5.0, 0.04 if sx else 1.5, 1.5 if sx else 0.04, 1.9)
    C(x, y, z0 + 1.5, 2.6 if sy else 1.4, 1.4 if sy else 2.6, 3.0)


def inn_in(g):
    W, D, T = 24.0, 16.0, 0.8
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T     # ±11.2, ±7.2
    ZF, ZC = 1.7, 9.6
    Z2F, Z2C = 10.3, 18.7                     # 2층 바닥 윗면 · 천장 밑(2026-10-10 사용자: 객실 문이 벽 → 2층·계단 동을 지음)
    fy = -D / 2
    g["Stone"].box(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    C(0, 0, 0.75, W + 1.2, D + 1.2, 1.5)
    g["Timber"].box(0, 0, 1.6, W - 2 * T, D - 2 * T, 0.2)
    # 아래층 벽: 뒤·왼·앞(문) + 오른 벽(계단 동으로 가는 문 y -1.6..1.2, 높이 7.6)
    box2(g, "Brick", -W / 2, W / 2, D / 2 - T, D / 2, 1.5, 10.0)
    box2(g, "Brick", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 1.5, 10.0)
    wall_door(g, "Brick", -W / 2, W / 2, -D / 2, -D / 2 + T, 1.5, 10.0, -2.2, 2.2, 9.1)
    for y0, y1, z0, z1 in ((iy0, -1.6, 1.5, 10.0), (1.2, iy1, 1.5, 10.0), (-1.6, 1.2, ZF + 7.6, 10.0)):
        box2(g, "Brick", ix1, W / 2, y0, y1, z0, z1)
    g["Wood"].box(0, 0, 9.8, W - 2 * T, D - 2 * T, 0.4)
    for x in (-7.5, -2.5, 2.5, 7.5):
        g["Wood"].box(x, 0, ZC - 0.2, 0.5, D - 2 * T, 0.5)
    # 2층(속 빈 벽 z 10..19) + 3층(속 찬 덩이 19..28) + 띠돌 고리 + 지붕
    g["Wood"].box(0, 0, (10.0 + Z2F) / 2, W - 2 * T, D - 2 * T, Z2F - 10.0)
    C(0, 0, (9.6 + Z2F) / 2, W - 2 * T, D - 2 * T, Z2F - 9.6)
    box2(g, "Brick", -W / 2, W / 2, D / 2 - T, D / 2, 10.0, 19.0)
    box2(g, "Brick", -W / 2, -W / 2 + T, -D / 2 + T, D / 2 - T, 10.0, 19.0)
    box2(g, "Brick", -W / 2, W / 2, -D / 2, -D / 2 + T, 10.0, 19.0)
    for y0, y1, z0, z1 in ((iy0, 4.6, 10.0, 19.0), (7.0, iy1, 10.0, 19.0), (4.6, 7.0, Z2F + 7.2, 19.0)):
        box2(g, "Brick", ix1, W / 2, y0, y1, z0, z1)
    g["Wood"].box(0, 0, (Z2C + 19.0) / 2, W - 2 * T, D - 2 * T, 19.0 - Z2C)
    g["Brick"].box(0, 0, 19.0 + 4.5, W, D, 9.0)
    for z in (10.0, 19.0):
        for x0, x1, y0, y1 in ((-W / 2 - 0.4, W / 2 + 0.4, -D / 2 - 0.4, -D / 2 + 0.2), (-W / 2 - 0.4, W / 2 + 0.4, D / 2 - 0.2, D / 2 + 0.4),
                               (-W / 2 - 0.4, -W / 2 + 0.2, -D / 2 + 0.2, D / 2 - 0.2), (W / 2 - 0.2, W / 2 + 0.4, -D / 2 + 0.2, D / 2 - 0.2)):
            g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, z, x1 - x0, y1 - y0, 0.6)
    g["StoneTrim"].box(0, 0, 28.0, W + 0.8, D + 0.8, 0.6)
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
    # 창: 아래(앞, 문 양옆 둘) · 2층(앞 넷 + 뒤 둘 + 왼 둘 — 진짜) · 3층(벽감)
    for x in (-8.0, 8.0):
        S.window(g, x, fy, 3.0, 2.4, 4.2)
        S.window(g, x, iy0, 3.0, 2.4, 4.2, face="+y", sill=False)
    for x in (-8.0, -3.5, 3.5, 8.0):
        S.window(g, x, fy, 12.0, 2.4, 4.2)
        S.window(g, x, iy0, 12.0, 2.4, 4.2, face="+y", sill=False)
        room_window(g, x, fy, 21.0, 2.4, 4.2, "-y", 2.2, curtain="SignPurple" if x > 0 else "Banner")
    for x in (-6.0, 6.0):
        S.window(g, x, D / 2, 12.0, 2.4, 4.2, face="+y")
        S.window(g, x, iy1, 12.0, 2.4, 4.2, face="-y", sill=False)
    for y in (-4.0,):
        S.window(g, -W / 2, y, 12.0, 2.4, 4.2, face="-x")
        S.window(g, ix0, y, 12.0, 2.4, 4.2, face="+x", sill=False)
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
    inn_stair_wing(g, ix1, ZF, Z2F)
    inn_rooms(g, ix0, ix1, iy0, iy1, Z2F, Z2C)
    DOORWAY(-2.2, 2.2, fy, iy0, ZF, 7.4)
    DOORWAY(ix1, W / 2, -1.6, 1.2, ZF, 7.6)
    DOORWAY(ix1, W / 2, 4.6, 7.0, Z2F, 7.2)
    DOORWAY(-6.5, -4.5, 3.2, 3.6, Z2F, 7.0)
    DOORWAY(4.5, 6.5, 3.2, 3.6, Z2F, 7.0)
    CLEAR(12.9, 15.4, -6.5, -4.0, ZF + 0.15, ZF + 5.8)
    CLEAR(12.9, 19.0, 4.45, 7.0, Z2F + 0.15, Z2F + 5.8)
    # 안(사람 크기 기준 — 2026-10-10 사용자: 바 뒤가 좁아 사람이 접힌다. 사람 키 5.2·어깨 2):
    #   바텐더 길 2.6(판매대 뒤 y 3.8 → 뒷장 앞 6.4), 판매대 높이 3.1(허리 높이), 문 길 x ±1.5 비움, 객실 문 앞 길 2.1
    # 왼 앞 접수대 + 열쇠판
    g["Wood"].box(-8.4, -3.6, ZF + 1.6, 4.6, 1.4, 3.2)
    g["Brass"].box(-8.4, -3.6, ZF + 3.28, 4.9, 1.6, 0.16)
    C(-8.4, -3.6, ZF + 1.65, 4.9, 1.6, 3.3)
    sphere(g, "Brass", (-7.0, -3.7, ZF + 3.55), 0.22, sub=1)
    g["Leather"].obox(-9.2, -3.5, ZF + 3.4, 1.1, 0.8, 0.15, rz=-0.15)
    g["Wood"].box(ix0 + 0.1, -4.2, 6.2, 0.15, 3.0, 2.2)
    for r in range(3):
        for c in range(4):
            g["Brass"].box(ix0 + 0.25, -5.3 + c * 0.75, 6.9 - r * 0.7, 0.12, 0.12, 0.35)
    # 벽난로(왼 벽 가운데 뒤 — 지붕 굴뚝 x -8 쪽)
    box2(g, "Stone", ix0, ix0 + 1.6, 0.6, 5.4, ZF, ZC)
    S.hole(g, ix0 + 1.6, 3.0, ZF + 1.2, 2.4, 2.2, "+x", 1.1, pane=False)          # 화실(돌 몸을 파 들어감) — 진짜 장작불
    g["Soot"].box(ix0 + 0.55, 3.0, ZF + 1.2, 0.06, 2.3, 2.1)
    fire_logs(g, ix0 + 1.05, 3.0, ZF + 0.1, 2.0, 0.9, axis="y", size=0.75)
    g["Stone"].box(ix0 + 2.1, 3.0, ZF + 0.08, 1.0, 3.2, 0.16)
    g["StoneTrim"].box(ix0 + 1.0, 3.0, ZF + 3.2, 2.4, 5.4, 0.35)
    S.gear(g, "Brass", ix0 + 1.65, 3.0, ZF + 5.4, 0.9, 12, 0.15, axis="x")
    # 둥근 탁자 둘(벽난로 앞 · 오른 앞) — 걸상까지 반지름 2.9
    for x, y in ((-4.6, 0.8), (4.6, -4.2)):
        round_table(g, x, y, ZF, r=1.4, h=2.7, stools=4)
        g["Copper"].cyl(x + 0.4, y + 0.2, ZF + 2.7, 0.2, 0.2, 0.45, seg=8)
        g["Brass"].cyl(x - 0.5, y - 0.1, ZF + 2.7, 0.18, 0.18, 0.4, seg=8)
        g["Wood"].cyl(x, y - 0.6, ZF + 2.7, 0.1, 0.1, 0.3, seg=6)
        g["Glow"].box(x, y - 0.6, ZF + 3.08, 0.12, 0.12, 0.16)
    # 바: 판매대(x -1..9, y 2.4..3.8) + 놋쇠 꼭지 셋 + 발걸이 + 앞 걸상 다섯
    bx0, bx1, by0, by1 = -1.0, 9.0, 2.4, 3.8
    box2(g, "Wood", bx0, bx1, by0, by1, ZF, ZF + 3.0)
    g["Brass"].box((bx0 + bx1) / 2, (by0 + by1) / 2, ZF + 3.08, bx1 - bx0 + 0.3, by1 - by0 + 0.3, 0.16)
    g["Timber"].box((bx0 + bx1) / 2, by0 - 0.05, ZF + 1.5, bx1 - bx0, 0.1, 2.6)
    g["Brass"].hcyl((bx0 + bx1) / 2, by0 - 0.4, ZF + 0.55, 0.08, bx1 - bx0, axis="x", seg=6)
    for x in (1.5, 4.0, 6.5):
        g["Brass"].cyl(x, by0 + 0.5, ZF + 3.16, 0.14, 0.14, 0.9, seg=8)
        g["Brass"].obox(x, by0 + 0.25, ZF + 3.95, 0.12, 0.55, 0.12)
        g["Wood"].cyl(x, by0 + 0.5, ZF + 4.06, 0.1, 0.12, 0.5, seg=6)
    for k in range(4):
        g["Glass"].cyl(2.6 + k * 0.9, by0 + 0.9, ZF + 3.16, 0.16, 0.18, 0.5, seg=8)
    for x in (0.0, 2.2, 4.4, 6.6, 8.6):
        g["Leather"].cyl(x, by0 - 0.9, ZF + 1.95, 0.5, 0.5, 0.25, seg=12)
        g["Brass"].cyl(x, by0 - 0.9, ZF, 0.08, 0.08, 1.95, seg=6)
        g["Brass"].cyl(x, by0 - 0.9, ZF + 0.6, 0.35, 0.35, 0.06, seg=10)
    # 바텐더 쪽: 뒷벽 아래 장(깊이 0.8, 높이 2.8, 대리석 윗판 + 잔) + 위 술 선반 셋
    box2(g, "Wood", 0.0, 8.6, iy1 - 0.8, iy1, ZF, ZF + 2.8)
    g["Marble"].box(4.3, iy1 - 0.4, ZF + 2.86, 8.8, 0.9, 0.12)
    for k in range(7):
        g["Glass"].cyl(0.8 + k * 1.15, iy1 - 0.4, ZF + 2.92, 0.18, 0.2, 0.45, seg=8)
    for k in range(4):
        g["Brass"].box(0.9 + k * 2.2, iy1 - 0.82, ZF + 1.6, 0.4, 0.04, 0.12)
    tops = shelf_unit(g, 0.4, 8.6, iy1, ZF + 3.8, 3.6, depth=0.6, levels=3, face=-1)
    for li, z in enumerate(tops[1:]):
        for k in range(10):
            bottle(g, 0.9 + k * 0.78, iy1 - 0.3, z, ["SignPurple", "Core", "SignTeal", "Glow"][(k + li) % 4], r=0.17, h=0.55)
    # 판매대 왼끝 통 둘(눕힌 받침 위) — 바텐더는 오른끝(x 9..11.2)으로 드나든다
    for y in (4.4, 6.2):
        g["Wood"].hcyl(-2.6, y, ZF + 1.15, 1.0, 1.9, axis="x", seg=14)
        g["Iron"].hcyl(-2.6, y, ZF + 1.15, 1.05, 0.15, axis="x", seg=14)
        g["Brass"].hcyl(-1.55, y, ZF + 1.15, 0.12, 0.3, axis="x", seg=6)
    for x in (-3.3, -1.9):
        g["Timber"].box(x, 5.3, ZF + 0.15, 0.3, 4.0, 0.3)
    C(-2.6, 5.3, ZF + 1.1, 2.2, 3.8, 2.2)
    # 계단 동으로 가는 문(오른 벽 y -1.6..1.2, 높이 7.6) — 돌 문틀 + 객실 간판
    for yy in (-1.85, 1.45):
        g["StoneTrim"].box(ix1 - 0.15, yy, ZF + 3.8, 0.3, 0.5, 7.6)
    g["StoneTrim"].box(ix1 - 0.15, -0.2, ZF + 7.85, 0.3, 3.4, 0.5)
    g["Brass"].box(ix1 - 0.15, -0.2, ZF + 8.55, 0.12, 2.4, 0.7)
    g["SignPurple"].box(ix1 - 0.22, -0.2, ZF + 8.55, 0.06, 2.1, 0.45)
    cx_, cy_ = ix1 - 0.9, -5.8
    g["Wood"].cyl(cx_, cy_, ZF, 0.12, 0.12, 5.6, seg=6)
    g["Wood"].cyl(cx_, cy_, ZF, 0.5, 0.4, 0.15, seg=8)
    for kk in range(4):
        a = kk * math.pi / 2
        g["Brass"].obox(cx_ + 0.3 * math.cos(a), cy_ + 0.3 * math.sin(a), ZF + 5.2, 0.08, 0.08, 0.6, rx=0.6 * math.sin(a), ry=-0.6 * math.cos(a))
    g["Leather"].obox(cx_ + 0.3, cy_, ZF + 4.3, 0.3, 0.9, 1.6, ry=0.15)
    C(cx_, cy_, ZF + 2.8, 0.8, 0.8, 5.6)
    g["Banner"].box(0.5, -2.4, ZF + 0.03, 9.0, 5.0, 0.06)
    for x, y in ((-4.6, 0.8), (4.6, -4.2), (4.0, 5.1)):
        lantern(g, x, y, ZC - 0.25, 8.0)


def inn_stair_wing(g, ix1, ZF, Z2F):
    """여관 오른쪽 계단 동(x 12..20, y -8..8, 2층 높이): 술집 오른 벽 문 → 바깥벽 따라 오르는 계단(13 단) → 2층 층계참 → 복도 문"""
    x0, x1, y0, y1, t = ix1 + 0.8, 20.0, -8.0, 8.0, 0.8
    jx0, jx1, jy0, jy1 = x0, x1 - t, y0 + t, y1 - t           # 안 12..19.2, -7.2..7.2
    g["Stone"].box((x0 + x1) / 2 + 0.3, 0, 0.75, x1 - x0 + 0.6, y1 - y0 + 1.2, 1.5)
    C((x0 + x1) / 2 + 0.3, 0, 0.75, x1 - x0 + 0.6, y1 - y0 + 1.2, 1.5)
    g["Timber"].box((jx0 + jx1) / 2 - 0.4, 0, 1.6, jx1 - jx0 + 0.8, jy1 - jy0, 0.2)
    C((jx0 + jx1) / 2 - 0.4, 0, 1.6, jx1 - jx0 + 0.8, jy1 - jy0, 0.2)
    box2(g, "Brick", x0, x1, y0, jy0, 1.5, 19.0)
    box2(g, "Brick", x0, x1, jy1, y1, 1.5, 19.0)
    box2(g, "Brick", jx1, x1, jy0, jy1, 1.5, 19.0)
    for z in (10.0, 19.0):
        for a0, a1, b0, b1 in ((x0, x1 + 0.4, y0 - 0.4, y0 + 0.2), (x0, x1 + 0.4, y1 - 0.2, y1 + 0.4), (x1 - 0.2, x1 + 0.4, y0 + 0.2, y1 - 0.2)):
            g["StoneTrim"].box((a0 + a1) / 2, (b0 + b1) / 2, z, a1 - a0, b1 - b0, 0.6)
    S.roof_gable(g, (x0 + x1) / 2 + 0.2, 0, 19.3, x1 - x0 + 0.8, y1 - y0 + 0.8, 3.6, along="y", gable="Brick")
    g["Wood"].box((jx0 + jx1) / 2, 0, 18.85, jx1 - jx0, jy1 - jy0, 0.3)
    # 창(진짜): 바깥벽 아래·위, 앞벽 아래
    S.window(g, x1, -3.0, 3.0, 2.2, 4.2, face="+x")
    S.window(g, jx1, -3.0, 3.0, 2.2, 4.2, face="-x", sill=False)
    S.window(g, x1, 1.0, 12.0, 2.2, 4.2, face="+x")
    S.window(g, jx1, 1.0, 12.0, 2.2, 4.2, face="-x", sill=False)
    S.window(g, 14.0, y0, 3.0, 2.2, 4.2, face="-y")
    S.window(g, 14.0, jy0, 3.0, 2.2, 4.2, face="+y", sill=False)
    # 술집 쪽 문턱(아래) · 2층 문턱 + 층계참
    C(ix1 + 0.4, -0.2, 1.6, 0.8, 2.8, 0.2)
    sx0, sx1 = 15.6, jx1
    box2(g, "Wood", ix1, jx1, 4.2, jy1, 10.0, Z2F)
    box2(g, "Wood", ix1, x0, 4.2, 4.6, 10.0, Z2F)
    # 계단(바깥벽 따라 y -6.8 → 4.2, 13 단) — 단마다 상자 + 깔개
    n, ya, yb = 13, -6.8, 4.2
    run, rise = (yb - ya) / n, (Z2F - ZF) / n
    for i in range(n):
        yy = ya + i * run
        box2(g, "Wood" if i % 2 else "Timber", sx0, sx1, yy, yy + run, ZF, ZF + (i + 1) * rise)
        g["Banner"].box((sx0 + sx1) / 2, yy + run / 2, ZF + (i + 1) * rise + 0.02, 2.4, run, 0.04)
    ln, ang = math.hypot(yb - ya, Z2F - ZF), math.atan2(Z2F - ZF, yb - ya)
    for k in range(8):
        yy = ya + 0.4 + k * (yb - ya - 0.8) / 7
        zz = ZF + (yy - ya) / (yb - ya) * (Z2F - ZF)
        g["Iron"].cyl(sx0, yy, zz, 0.07, 0.07, 3.0, seg=5)
    g["Brass"].obox(sx0, (ya + yb) / 2, (ZF + Z2F) / 2 + 3.1, 0.2, ln, 0.2, rx=ang)
    C(sx0, (ya + yb) / 2 + 1.5, (ZF + Z2F) / 2 + 2.0, 0.3, yb - ya - 3.0, Z2F - ZF + 3.0)
    # 층계참 난간(계단 옆 열린 자리) + 계단 밑 궤짝·바구니 + 객실 안내판 + 등
    for k in range(5):
        g["Iron"].cyl(x0 + 0.3 + k * 0.8, 4.3, Z2F, 0.07, 0.07, 3.0, seg=5)
    g["Brass"].box((x0 + sx0) / 2, 4.3, Z2F + 3.05, sx0 - x0, 0.2, 0.2)
    C((x0 + sx0) / 2, 4.3, Z2F + 1.6, sx0 - x0, 0.3, 3.2)
    for k, (yy, s) in enumerate(((2.6, 1.6), (0.8, 1.4))):
        g["Timber"].box(sx0 + 1.4, yy + 1.0, ZF + s / 2, s, s, s)
    g["Canvas"].cyl(sx0 + 2.6, 3.2, ZF, 0.6, 0.7, 1.2, seg=10)
    g["Brass"].box(x0 + 0.1, -4.0, ZF + 5.6, 0.1, 2.4, 0.9)
    g["SignPurple"].box(x0 + 0.15, -4.0, ZF + 5.6, 0.04, 2.0, 0.6)
    g["Brass"].obox(x0 + 0.15, -2.9, ZF + 5.6, 0.04, 0.8, 0.2, rx=0.5)
    lantern(g, 14.0, -1.0, 18.4, 13.0)


def inn_rooms(g, ix0, ix1, iy0, iy1, Z2F, Z2C):
    """여관 2층: 뒤 복도(y 3.6..7.2) + 앞 객실 둘(왼 A — 벽난로 굴뚝 / 오른 B). 객실마다 침대·옷장·세면대·책상·의자·깔개·등"""
    py0, py1 = 3.2, 3.6
    for a0, a1 in ((ix0, -6.5), (-4.5, 4.5), (6.5, ix1)):
        box2(g, "Wood", a0, a1, py0, py1, Z2F, Z2C)
    for a0, a1 in ((-6.5, -4.5), (4.5, 6.5)):
        box2(g, "Wood", a0, a1, py0, py1, Z2F + 7.0, Z2C)
        for xx in (a0, a1):
            g["Timber"].box(xx, (py0 + py1) / 2, Z2F + 3.5, 0.3, 0.6, 7.0)
        g["Timber"].box((a0 + a1) / 2, (py0 + py1) / 2, Z2F + 7.1, a1 - a0 + 0.6, 0.6, 0.3)
    box2(g, "Brick", -0.2, 0.2, iy0, py0, Z2F, Z2C)
    door_leaf_in(g, -6.5, py0 - 0.15, Z2F, 1.9, 6.9, -100.0, 1)
    door_leaf_in(g, 6.5, py0 - 0.15, Z2F, 1.9, 6.9, -100.0, -1)
    for xx, mat in ((-5.5, "Banner"), (5.5, "SignPurple")):       # 객실 문패(복도 쪽)
        g["Brass"].box(xx, py1 + 0.08, Z2F + 7.6, 0.9, 0.05, 0.5)
        g[mat].box(xx, py1 + 0.11, Z2F + 7.6, 0.7, 0.03, 0.3)
    # 굴뚝 몸(아래 벽난로 위) + 객실 A 작은 벽난로
    box2(g, "Stone", ix0, ix0 + 1.6, 0.6, 5.4, Z2F, Z2C)
    S.hole(g, ix0 + 1.6, 1.9, Z2F + 0.95, 1.6, 1.7, "+x", 1.0, pane=False)
    g["Soot"].box(ix0 + 0.65, 1.9, Z2F + 0.95, 0.06, 1.5, 1.6)
    fire_logs(g, ix0 + 1.1, 1.9, Z2F + 0.1, 1.3, 0.8, axis="y", size=0.5)
    g["Stone"].box(ix0 + 2.0, 1.9, Z2F + 0.07, 0.8, 2.2, 0.14)
    g["StoneTrim"].box(ix0 + 1.0, 1.9, Z2F + 2.15, 2.2, 2.6, 0.3)
    for s in (-1, 1):
        bed(g, s * 8.2, -3.6, Z2F, rz=0.0 if s < 0 else math.pi, mat="Banner" if s < 0 else "SignPurple")
        wardrobe(g, s * 1.2, -5.0, Z2F, "-x" if s < 0 else "+x")
        washstand(g, s * 2.0, 2.4, Z2F, "-y")
        dx = s * 4.2
        g["Wood"].box(dx, -6.4, Z2F + 2.6, 3.0, 1.4, 0.2)
        for ux in (-1.3, 1.3):
            for uy in (-0.55, 0.55):
                g["Wood"].box(dx + ux, -6.4 + uy, Z2F + 1.25, 0.2, 0.2, 2.5)
        g["Canvas"].obox(dx - 0.5, -6.4, Z2F + 2.72, 0.9, 0.6, 0.03, rz=0.2)
        g["Brass"].cyl(dx + 0.9, -6.6, Z2F + 2.7, 0.15, 0.1, 0.8, seg=6)
        g["Glow"].box(dx + 0.9, -6.6, Z2F + 3.55, 0.15, 0.15, 0.25)
        C(dx, -6.4, Z2F + 1.35, 3.0, 1.4, 2.7)
        g["Wood"].box(dx, -5.0, Z2F + 1.5, 1.2, 1.2, 0.15)
        g["Wood"].box(dx, -5.55, Z2F + 2.6, 1.2, 0.15, 2.2)
        g[("Banner" if s < 0 else "SignPurple")].box(s * 6.0, -2.0, Z2F + 0.03, 5.0, 4.0, 0.06)
        lantern(g, s * 5.5, -1.0, Z2C - 0.2, Z2F + 6.6)
    # 칸막이 벽 양쪽 그림
    g["Brass"].box(-0.3, -1.5, Z2F + 5.5, 0.08, 2.4, 1.8)
    g["Canvas"].box(-0.36, -1.5, Z2F + 5.5, 0.04, 2.0, 1.4)
    g["Brass"].box(0.3, -1.5, Z2F + 5.5, 0.08, 2.4, 1.8)
    g["SignTeal"].box(0.36, -1.5, Z2F + 5.5, 0.04, 2.0, 1.4)
    # 복도: 깔개 · 콘솔 탁자와 꽃병 · 벽등 둘 · 그림
    g["Banner"].box(0.8, 5.4, Z2F + 0.03, 18.0, 1.6, 0.06)
    g["Wood"].box(0, iy1 - 0.4, Z2F + 1.4, 3.0, 0.8, 2.8)
    C(0, iy1 - 0.4, Z2F + 1.4, 3.0, 0.8, 2.8)
    g["SignBlue"].cyl(0, iy1 - 0.4, Z2F + 2.8, 0.3, 0.4, 0.8, seg=10)
    for k in range(4):
        sphere(g, "Felt", (-0.2 + (k % 2) * 0.4, iy1 - 0.4 + (k // 2) * 0.3 - 0.15, Z2F + 3.9 + 0.2 * (k % 2)), 0.3, sub=1)
    for xx in (-2.5, 2.5):
        g["Brass"].box(xx, iy1 - 0.12, Z2F + 5.2, 0.4, 0.25, 0.9)
        g["Glow"].cyl(xx, iy1 - 0.45, Z2F + 5.5, 0.2, 0.2, 0.6, seg=8)
        g["LampPt"].box(xx, iy1 - 0.8, Z2F + 5.8, 0.3, 0.3, 0.3)


# =========================================================================== 지하 카지노가 쓰는 슬롯머신(앞 = 로컬 -v, rz 로 돌린다)
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


def drill_press(g, x, y, z0, face=1.0):
    """기둥 드릴(받침·기둥·작업판·머리·벨트 바퀴·손잡이 바퀴). face = 머리가 나오는 쪽(+x 1, -x -1)"""
    g["Iron"].box(x, y, z0 + 0.3, 2.4, 2.0, 0.6)
    g["Iron"].cyl(x - face * 0.6, y, z0 + 0.6, 0.32, 0.32, 7.6, seg=10)
    g["IronLight"].box(x + face * 0.2, y, z0 + 3.4, 1.6, 1.6, 0.25)
    g["Iron"].cyl(x - face * 0.6, y, z0 + 3.1, 0.5, 0.5, 0.5, seg=10)
    g["Iron"].box(x, y, z0 + 6.4, 2.2, 1.2, 1.6)
    g["Brass"].cyl(x + face * 0.3, y, z0 + 4.6, 0.12, 0.12, 1.2, seg=6)
    g["Brass"].hcyl(x - face * 0.8, y, z0 + 7.6, 0.8, 0.35, axis="y", seg=16)
    g["Brass"].hcyl(x + face * 0.4, y + 0.75, z0 + 6.2, 0.55, 0.12, axis="y", seg=12)
    for k in range(3):
        a = k * 2 * math.pi / 3
        g["Iron"].obox(x + face * 0.4 + 0.45 * math.cos(a), y + 0.8, z0 + 6.2 + 0.45 * math.sin(a), 0.9, 0.08, 0.08, ry=-a)
    C(x, y, z0 + 4.0, 2.6, 2.2, 8.0)


def line_shaft(g, x, y0, y1, z, zt, drops):
    """천장 굴대(벨트로 기계를 돌린다): 굴대 + 매단 받침 + 풀리 + 아래로 내려가는 가죽 벨트 둘. drops = [(y, 벨트 아래 끝 x, z)]"""
    g["Iron"].hcyl(x, (y0 + y1) / 2, z, 0.28, y1 - y0, axis="y", seg=10)
    yy = y0 + 2.0
    while yy < y1 - 1.0:
        g["Iron"].box(x, yy, (z + zt) / 2, 0.35, 0.35, zt - z)
        g["Iron"].box(x, yy, z + 0.2, 0.9, 0.5, 0.9)
        yy += 8.0
    for y, bx, bz in drops:
        g["Brass"].hcyl(x, y, z, 0.95, 0.5, axis="y", seg=18)
        g["Iron"].hcyl(x, y, z, 0.35, 0.6, axis="y", seg=10)
        for side in (-1, 1):
            x0, z0 = x + side * 0.9, z
            x1, z1 = bx + side * 0.45, bz
            ln = math.hypot(x1 - x0, z1 - z0)
            g["Leather"].obox((x0 + x1) / 2, y, (z0 + z1) / 2, 0.08, 0.42, ln, ry=math.atan2(x1 - x0, z1 - z0))


def wood_crates(g, x0, y0, z0=0.0):
    """궤짝 무더기(아래 셋 + 위 둘, 쇠 띠) + 충돌"""
    for i, (dx, dy, s, lv) in enumerate(((0, 0, 3.0, 0), (3.2, 0.3, 2.8, 0), (1.4, 3.0, 2.6, 0), (0.8, 0.8, 2.4, 1), (2.6, 2.2, 2.2, 1))):
        z = z0 + s / 2 + (3.0 if lv else 0.0)
        g["Timber"].obox(x0 + dx, y0 + dy, z, s, s, s, rz=0.15 * (i - 2))
        g["Iron"].obox(x0 + dx, y0 + dy, z, s + 0.08, s + 0.08, 0.3, rz=0.15 * (i - 2))
    C(x0 + 1.6, y0 + 1.5, z0 + 2.8, 6.6, 6.2, 5.6)


def factory_more(g, ix0, ix1, iy0, iy1, ZF, ZT):
    """공장 밀도(사용자 2026-10-10 "공장쪽 밀도 더"): 굴대 둘 + 드릴 셋 + 벽 선반 + 쇠막대 받침·손수레 + 감독 사무실(유리)
    + 단조로·석탄 + 벽 증기관 + 연장판 + 바닥 짐 + 앞마당(궤짝·석탄 수레 레일·관 받침·지브 기중기)"""
    # 오른쪽 굴대(선반 기계 넷 위) — 벨트는 기계 왼쪽 풀리(x 9.4, 높이 ZF+4.3)로
    line_shaft(g, 9.4, -26.0, 6.0, 19.0, ZT - 1.0, [(y - 0.85, 9.4, ZF + 4.3) for y in (-22.0, -14.0, -6.0, 2.0)])
    # 왼쪽: 기둥 드릴 셋 + 그 위 굴대
    for y in (-26.0, -19.0, -12.0):
        drill_press(g, -18.0, y, ZF, face=1.0)
    line_shaft(g, -18.8, -30.0, -8.0, 19.0, ZT - 1.0, [(y, -18.8, ZF + 7.6) for y in (-26.0, -19.0, -12.0)])
    # 왼 벽 높은 쇠 선반(굴뚝 기둥 y 9.75..16.25 자리 피해 둘) — 통·상자·쇠막대
    for y0, y1 in ((-4.0, 8.0), (17.5, 23.5)):
        for yy in (y0, (y0 + y1) / 2, y1):
            g["Iron"].box(ix0 + 1.2, yy, ZF + 4.5, 0.3, 0.3, 9.0)
            g["Iron"].box(ix0 + 0.2, yy, ZF + 4.5, 0.3, 0.3, 9.0)
        for zz in (0.4, 3.2, 6.0, 8.8):
            g["IronLight"].box(ix0 + 0.7, (y0 + y1) / 2, ZF + zz, 1.4, y1 - y0 + 0.3, 0.15)
        n = 0
        for li, zz in enumerate((0.5, 3.3, 6.1)):
            yy = y0 + 0.3
            while yy < y1 - 0.8:
                w = 0.9 + 0.3 * ((n * 7 + li) % 3)
                if (n + li) % 3 == 0:
                    g["Wood"].cyl(ix0 + 0.7, yy + w / 2, ZF + zz, w / 2, w / 2, 1.6, seg=10)
                elif (n + li) % 3 == 1:
                    g["Timber"].box(ix0 + 0.7, yy + w / 2, ZF + zz + 0.6, 1.1, w, 1.2)
                else:
                    for b in range(3):
                        g["IronLight"].hcyl(ix0 + 0.4 + b * 0.3, yy + w / 2, ZF + zz + 0.2, 0.12, w, axis="y", seg=6)
                yy += w + 0.25
                n += 1
        C(ix0 + 0.7, (y0 + y1) / 2, ZF + 4.6, 1.6, y1 - y0 + 0.4, 9.2)
    # 앞 왼 구석: 쇠막대 받침(가로로 쌓은 봉) + 손수레
    for yy in (-31.0, -29.0):
        for xx in (-21.0, -14.0):
            g["Iron"].box(xx, yy, ZF + 1.3, 0.35, 0.35, 2.6)
    for r in range(3):
        for c in range(4):
            g["IronLight" if (r + c) % 2 else "Copper"].hcyl(-17.5, -31.6 + c * 0.5, ZF + 0.6 + r * 0.6, 0.2, 7.6, axis="x", seg=6)
    C(-17.5, -30.0, ZF + 1.3, 7.8, 2.6, 2.6)
    g["Timber"].box(-11.5, -29.0, ZF + 1.2, 1.6, 2.6, 0.2)
    for sx in (-1, 1):
        g["Iron"].obox(-11.5 + sx * 0.7, -30.6, ZF + 1.4, 0.12, 0.12, 2.6, rx=0.5)
    g["Iron"].hcyl(-11.5, -28.0, ZF + 0.5, 0.5, 1.8, axis="x", seg=12)
    for k in range(3):
        g["Iron" if k % 2 else "Brass"].box(-11.5, -29.4 + k * 0.8, ZF + 1.6, 1.2, 0.6, 0.6)
    C(-11.5, -29.2, ZF + 1.2, 2.0, 3.6, 2.4)
    # 뒤 오른쪽: 감독 사무실(아래 벽돌 + 위 유리, 굴뚝 기둥 x ≤ 16.25 피함, 문은 -y 쪽 왼끝 x 17.3..19.9)
    ox0, oy0, oy1 = 16.9, 18.0, iy1
    zw, zg = ZF + 3.2, ZF + 8.6
    box2(g, "BrickDark", ox0, ox0 + 0.4, oy0, oy1, ZF, zw)
    box2(g, "BrickDark", ox0 + 3.0, ix1, oy0, oy0 + 0.4, ZF, zw)
    C(ox0 + 0.2, (oy0 + oy1) / 2, (zw + zg) / 2, 0.4, oy1 - oy0, zg - zw)
    C((ox0 + 3.0 + ix1) / 2, oy0 + 0.2, (zw + zg) / 2, ix1 - ox0 - 3.0, 0.4, zg - zw)
    g["Glass"].box(ox0 + 0.2, (oy0 + oy1) / 2, (zw + zg) / 2, 0.1, oy1 - oy0, zg - zw)
    g["Glass"].box((ox0 + 3.0 + ix1) / 2, oy0 + 0.2, (zw + zg) / 2, ix1 - ox0 - 3.0, 0.1, zg - zw)
    for yy in (oy0, oy0 + 4.0, oy0 + 8.0, oy0 + 12.0, oy1):
        g["Iron"].box(ox0 + 0.2, yy, (zw + zg) / 2, 0.25, 0.25, zg - zw)
    for xx in (ox0 + 0.2, ox0 + 3.0):
        g["Iron"].box(xx, oy0 + 0.2, (ZF + zg) / 2, 0.25, 0.25, zg - ZF)
    g["Iron"].box(ox0 + 1.6, oy0 + 0.2, zg - 0.4, 3.0, 0.3, 0.8)
    box2(g, "Wood", ox0, ix1, oy0, oy1, zg, zg + 0.3)
    g["SignGold"].box(ox0 + 1.6, oy0 - 0.05, zg - 0.4, 2.0, 0.06, 0.5)
    # 사무실 안: 책상·서류·등·의자·서류장·설계도판·벽시계
    g["Wood"].box(19.6, 28.0, ZF + 2.6, 3.6, 2.0, 0.25)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Wood"].box(19.6 + sx * 1.6, 28.0 + sy * 0.8, ZF + 1.25, 0.25, 0.25, 2.5)
    C(19.6, 28.0, ZF + 1.4, 3.6, 2.0, 2.8)
    for k in range(5):
        g["Canvas"].obox(19.0 + (k % 3) * 0.5, 27.8 + (k // 3) * 0.4, ZF + 2.76 + k * 0.02, 0.9, 0.6, 0.02, rz=0.2 * k)
    g["Brass"].cyl(20.8, 28.4, ZF + 2.72, 0.25, 0.15, 1.0, seg=8)
    g["Glow"].box(20.8, 28.4, ZF + 3.9, 0.5, 0.5, 0.35)
    g["Wood"].box(19.6, 25.6, ZF + 1.5, 1.2, 1.2, 0.2)
    g["Wood"].box(19.6, 25.1, ZF + 2.6, 1.2, 0.2, 2.0)
    g["Iron"].box(ix1 - 0.7, 21.0, ZF + 2.4, 1.2, 2.2, 4.8)
    for zz in (1.0, 2.4, 3.8):
        g["Brass"].box(ix1 - 1.32, 21.0, ZF + zz, 0.06, 1.2, 0.12)
    C(ix1 - 0.7, 21.0, ZF + 2.4, 1.3, 2.3, 4.8)
    g["Canvas"].box(ix1 - 0.06, 26.0, ZF + 5.4, 0.05, 4.0, 2.4)
    g["SignBlue"].box(ix1 - 0.1, 26.0, ZF + 5.4, 0.04, 3.4, 1.8)
    g["Brass"].hcyl(19.6, iy1 - 0.1, ZF + 6.6, 0.7, 0.12, axis="y", seg=16)
    g["Dial"].hcyl(19.6, iy1 - 0.18, ZF + 6.6, 0.6, 0.04, axis="y", seg=16)
    g["LampPt"].box(19.6, 27.0, zg - 0.8, 0.3, 0.3, 0.3)
    # 뒤 가운데: 단조로(벽돌 화덕, 붉은 아가리) + 연통 + 석탄 통·더미 + 삽
    box2(g, "Brick", -5.0, 5.0, iy1 - 4.0, iy1, ZF, ZF + 6.0)
    g["StoneTrim"].box(0, iy1 - 2.0, ZF + 6.2, 10.6, 4.6, 0.4)
    S.hole(g, 0, iy1 - 4.0, ZF + 2.4, 3.6, 2.6, "-y", 2.6, pane=False)          # 화구(벽돌 몸을 2.6 파 들어감) — 숯불
    g["Soot"].box(0, iy1 - 1.45, ZF + 2.4, 3.5, 0.06, 2.5)
    coal_bed(g, 0, iy1 - 2.7, ZF + 1.1, 3.2, 2.2, size=1.1)
    g["Iron"].box(0, iy1 - 4.15, ZF + 3.95, 4.2, 0.3, 0.3)
    g["Iron"].cyl(0, iy1 - 2.0, ZF + 6.4, 1.0, 1.0, ZT - ZF - 6.4 + 3.0, seg=14)
    for zz in (10.0, 16.0, 22.0):
        g["Brass"].cyl(0, iy1 - 2.0, zz, 1.08, 1.08, 0.3, seg=14)
    box2(g, "Iron", 6.2, 10.4, iy1 - 3.4, iy1 - 0.4, ZF, ZF + 1.6)
    for k in range(9):
        g["Soot"].obox(6.8 + (k % 3) * 1.3, iy1 - 2.8 + (k // 3) * 0.9, ZF + 1.7 + (k % 2) * 0.2, 0.9, 0.8, 0.5, rz=k * 0.7)
    g["Iron"].obox(6.4, iy1 - 4.0, ZF + 2.0, 0.12, 0.12, 3.6, rx=0.35)
    g["Iron"].obox(6.4, iy1 - 4.6, ZF + 0.4, 0.6, 0.8, 0.08, rx=0.35)
    # 벽 증기관(양 옆벽 높이 21 — 창(10.4..19.5) 위, 밸브 바퀴·압력계)
    for sx in (-1, 1):
        xw = (ix0 + 0.5) if sx < 0 else (ix1 - 0.5)
        S.pipe(g, [(xw, iy0 + 1.0, 21.0), (xw, iy1 - 1.0, 21.0)], 0.4, mat="Copper")
        for yy in (-20.0, -4.0, 16.0):
            g["Iron"].box(xw - sx * 0.2, yy, 20.0, 0.3, 0.6, 2.0)
            g["Brass"].hcyl(xw - sx * 0.65, yy, 21.0, 0.5, 0.15, axis="x", seg=10)
            g["Brass"].hcyl(xw - sx * 0.45, yy, 21.0, 0.15, 0.4, axis="x", seg=6)
        for yy in (-12.0, 8.0):
            g["Brass"].hcyl(xw - sx * 0.55, yy, 22.2, 0.55, 0.2, axis="x", seg=16)
            g["Dial"].hcyl(xw - sx * 0.67, yy, 22.2, 0.45, 0.05, axis="x", seg=16)
    # 앞벽 안쪽 연장판(문 양옆) + 걸린 연장
    for sx in (-1, 1):
        xc = sx * 13.0
        g["Timber"].box(xc, iy0 + 0.12, ZF + 5.5, 6.0, 0.2, 3.6)
        for k in range(7):
            ln = 0.8 + 0.25 * (k % 3)
            g["Iron" if k % 2 else "Brass"].box(xc - 2.4 + k * 0.8, iy0 + 0.3, ZF + 6.4 - ln / 2, 0.15, 0.12, ln)
    # 바닥 짐: 톱니 깔판 둘 + 기름통·연장 상자 + 사슬 더미
    for x, y in ((5.6, -24.0), (-8.6, 22.0)):
        g["Timber"].box(x, y, ZF + 0.2, 3.0, 3.0, 0.4)
        for k, (r, n) in enumerate(((1.0, 10), (0.7, 8), (0.8, 9))):
            S.gear(g, "Brass" if k % 2 else "Copper", x - 0.6 + k * 0.6, y - 0.5 + k * 0.5, ZF + 0.5 + k * 0.32, r, n, 0.3, axis="z")
        C(x, y, ZF + 0.8, 3.0, 3.0, 1.6)
    for y in (-10.0, -18.0):
        g["SignRed"].cyl(16.2, y, ZF, 0.5, 0.5, 1.4, seg=12)
        g["Iron"].box(14.4, y + 1.0, ZF + 0.45, 1.2, 0.6, 0.9)
    S.ring(g, "Iron", 4.0, 12.0, ZF, 0.3, 0.9, 0.35, n=14)
    S.ring(g, "Iron", 4.1, 12.1, ZF + 0.35, 0.2, 0.8, 0.3, n=14)
    # ── 앞마당(문 앞. 서대로가 x ±10 으로 들어오니 비운다)
    fy = -D_F / 2
    wood_crates(g, -20.0, fy - 12.0)
    wood_crates(g, 16.0, fy - 24.0)
    # 석탄 수레 + 짧은 레일(왼쪽)
    for sx in (-1, 1):
        g["Iron"].box(-21.0 + sx * 1.2, fy - 34.0, 0.15, 0.3, 26.0, 0.3)
    for k in range(13):
        g["Timber"].box(-21.0, fy - 46.0 + k * 2.0, 0.08, 3.4, 0.6, 0.16)
    g["Iron"].box(-21.0, fy - 30.0, 1.6, 2.6, 4.0, 2.0)
    for sy in (-1, 1):
        for sx in (-1, 1):
            g["Iron"].hcyl(-21.0 + sx * 1.2, fy - 30.0 + sy * 1.3, 0.55, 0.45, 0.25, axis="x", seg=8)
    for k in range(6):
        g["Soot"].obox(-21.6 + (k % 3) * 0.6, fy - 31.0 + (k // 3) * 1.4, 2.7 + (k % 2) * 0.2, 0.9, 0.8, 0.6, rz=k)
    C(-21.0, fy - 30.0, 1.5, 2.8, 4.2, 3.0)
    # 관 받침(오른쪽, 구리 관 여덟)
    for xx in (13.5, 22.5):
        for yy in (fy - 6.0, fy - 14.0):
            g["Iron"].box(xx, yy, 1.8, 0.4, 0.4, 3.6)
    for yy in (fy - 6.0, fy - 14.0):
        g["Iron"].box(18.0, yy, 3.4, 9.4, 0.4, 0.3)
    for r in range(2):
        for c in range(4):
            g["Copper"].hcyl(18.0, fy - 7.0 - c * 2.0, 3.8 + r * 1.0, 0.45, 10.6, axis="x", seg=12)
    C(18.0, fy - 10.0, 2.4, 9.8, 9.0, 4.8)
    # 지브 기중기(문 왼쪽): 기둥 + 팔 + 버팀대 + 사슬 + 갈고리
    g["Iron"].cyl(-14.0, fy - 3.0, 0, 0.5, 0.5, 12.0, seg=12)
    g["Iron"].box(-14.0 + 3.5, fy - 3.0, 11.6, 7.4, 0.5, 0.6)
    g["Iron"].obox(-14.0 + 1.6, fy - 3.0, 10.2, 0.25, 0.25, 4.0, ry=-0.85)
    sweep(g, "Iron", [(-14.0 + 6.6, fy - 3.0, 11.3 - i * 0.5) for i in range(12)], 0.1, seg=6)
    g["Iron"].obox(-14.0 + 6.6, fy - 3.0, 5.6, 0.6, 0.15, 0.6, ry=0.6)
    C(-14.0, fy - 3.0, 6.0, 1.0, 1.0, 12.0)


D_F = 52.0 * 1.3      # 공장 깊이(배율 구운 뒤) — factory_more 앞마당이 쓴다


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
    for y in (-22.0, -14.0, -6.0, 2.0):
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
    # 궤짝 → 앞 오른 구석, 통 → 뒤 왼 구석(굴뚝 기둥과 겹치던 것을 옮김)
    wood_crates(g, 16.4, -30.4, ZF)
    for x, y in ((-20.0, 27.0), (-18.0, 29.6), (-20.4, 30.6), (-18.6, 26.6)):
        g["Wood"].cyl(x, y, ZF, 1.1, 1.1, 2.8, seg=14)
        g["Iron"].cyl(x, y, ZF + 0.5, 1.15, 1.15, 0.15, seg=14)
        g["Iron"].cyl(x, y, ZF + 2.2, 1.15, 1.15, 0.15, seg=14)
    C(-19.2, 28.6, ZF + 1.4, 4.4, 6.2, 2.8)
    factory_more(g, ix0, ix1, iy0, iy1, ZF, ZT)
    DOORWAY(-7.8, 7.8, -D / 2, iy0, ZF, 18.0)
    for x in (-10.0, 10.0):
        for y in (-22.0, -8.0, 6.0, 20.0):
            lantern(g, x, y, ZT - 1.0, 13.0)    # 바닥까지 빛이 닿게(등 반경 16)


JOBS = [
    ("Observatory", "Obs", job("Observatory", lambda g: (O.observatory(g), DOORWAY(-3.0, 3.0, -22.6, -20.4, 2.0, 9.0)), cut=O.RO - O.RI)),   # 등만 INSIDE 로(충돌은 Snow_City2 가 따로)
    ("Frostig_Werk", "FrosIn", job("Frostig_Werk", frostig_in, cut=0.8)),
    ("Zapfen_Werk", "ZapfIn", job("Zapfen_Werk", zapfen_in, cut=1.0)),
    ("Sel_Werk_Ruin", "SelIn", job("Sel_Werk_Ruin", sel_in)),
    ("Shop_Blue", "ShopBIn", job("Shop_Blue", shop_in("SignBlue", "general"), cut=0.8)),
    ("Shop_Teal", "ShopTIn", job("Shop_Teal", shop_in("SignTeal", "potion"), cut=0.8)),
    ("Shop_Red", "ShopRIn", job("Shop_Red", shop_in("SignRed", "forge"), cut=0.8)),
    ("Ticket_Booth", "TicketIn", job("Ticket_Booth", ticket_in, cut=0.7)),
    ("Inn_House", "InnIn", job("Inn_House", inn_in, cut=0.8)),
    ("Steam_Factory", "FactIn", job("Steam_Factory", factory_in, cut=1.0)),
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
        if FIRES.get(name):
            out.append("\t\tfires = {")
            for x, y, z, sz in FIRES[name]:
                out.append("\t\t\t{ %s, %s, %s, %s }," % (f(-x), f(z), f(y), f(sz)))
            out.append("\t\t},")
        if DIGS.get(name):
            out.append("\t\tdig = {")
            for cx, cy, cz, sx, sy, sz, world in DIGS[name]:
                out.append("\t\t\t{ %s, %s, %s, %s, %s, %s, %s }," % (f(-cx), f(cz), f(cy), f(sx), f(sz), f(sy), "true" if world else "false"))
            out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
