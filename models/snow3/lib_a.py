# -*- coding: utf-8 -*-
"""
snow3/lib_a.py — 2026-11-14. 아트 부서원 1(A 양식 = 짙은 통나무) 전용 부품. lib.py 는 공용이라 고치지 않고 여기에 더한다.
건물: b_general · b_potion · b_ticket · b_mast · b_gate · b_inn.

■ 부품(한 줄씩)
    sides(x0,x1,y0,y1) → {f,b,l,r: (ax, c, face, parity, u0, u1)}   벽 가운데 선 네 개를 이름으로
    log_box(g, x0,x1,y0,y1, z0,z1, holes={side:[(a,b,za,zb)]}, ends)   통나무 네 벽(lib.log_wall 넷)
    win(g, S, side, u, z0, w, h, shutters)                            창(lib.window) — 구멍은 hole() 로 같이 넣는다
    hole(u, z0, w, h)                                                 구멍 튜플
    roof_x(g, R, yc, openings) · truss_x(g, R, x, yc) · gable_x(g, R, x_c, yc)   용마루가 x 방향(옆이 박공)인 맞배지붕 — lib 지붕을 90° 돌려 쓴다
    iron_stove(g, x, y, z0, z_pipe)                                   무쇠 난로 + 진짜 불(FIRE) + 연통(바닥 난로에서 지붕 위까지)
    glass_case(g, x0,x1,y0,y1, z0)                                    유리 진열 카운터(나무 몸 + 유리 윗단, G2)
    airship_icon(g, x, y, z, face)                                    비행선 간판 그림
    rail_between(g, ax, c, a, b, z0, h)                               난간: 양끝 기둥은 부르는 쪽이 세우고, 이 함수는 그 사이 윗대·아랫대·살만(난간 위엔 아무것도 없다)
    joists(g, ax, c0, c1, a0, a1, z_top, gap)                         장선(보 위에 얹는 바닥 받침) + 마루 판
    lattice_leg(g, p0, p1, s)                                         쇠 격자 다리(두 점 사이 한 덩이)
"""
import math

from mathutils import Matrix

import lib as K
from lib import FZ, LOG, bx, cbox


def sides(x0, x1, y0, y1):
    return {"f": ("x", y0, -1, 0, x0, x1), "b": ("x", y1, 1, 0, x0, x1),
            "l": ("y", x0, -1, 1, y0, y1), "r": ("y", x1, 1, 1, y0, y1)}


def hole(u, z0, w=K.WIN_W, h=K.WIN_H):
    return (u - w / 2, u + w / 2, z0, z0 + h)


def log_box(g, x0, x1, y0, y1, z0, z1, holes=None, ends=None, skip=()):
    """통나무 네 벽. holes = {'f': [...], ...}, ends = {'l': (True, False)} 모서리 끝 내밈 끄기, skip = 짓지 않을 벽"""
    holes, ends = holes or {}, ends or {}
    for k, (ax, c, face, par, u0, u1) in sides(x0, x1, y0, y1).items():
        if k in skip:
            continue
        K.log_wall(g, ax, c, u0, u1, z0, z1, holes.get(k, ()), parity=par, ends=ends.get(k, (True, True)))


def win(g, S, side, u, z0, w=K.WIN_W, h=K.WIN_H, shutters=True):
    ax, c, face = S[side][:3]
    K.window(g, ax, c, u, z0, w, h, face=face, shutters=shutters)


# ------------------------------------------------------------------ 옆 박공 지붕(용마루 x 방향)
# 돌림: 제 좌표 (lx, ly) → 세계 (-ly, lx + yc). lib 의 RoofFrame 은 용마루가 y 방향이라 90° 돌려 짓는다.
def _rot(yc):
    return Matrix.Translation((0, yc, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")


def roof_frame_x(half_y, x0, x1, z_plate, pitch):
    """half_y = 벽 바깥면 반 깊이, x0..x1 = 박공벽 바깥면(세계 x). 제 좌표 y 범위 = -x1..-x0"""
    return K.RoofFrame(half_y, -x1, -x0, z_plate, pitch)


def roof_x(g, R, yc=0.0, openings=()):
    loc = [(y0 - yc, y1 - yc, -x1, -x0) for x0, x1, y0, y1 in openings]
    K.L.transformed(g, _rot(yc), lambda q: K.roof_gable(q, R, openings=loc))


def truss_x(g, R, x, yc=0.0, posts=True):
    K.L.transformed(g, _rot(yc), lambda q: K.tie_truss(q, -x, R, posts=posts))


def gable_x(g, R, xc, yc=0.0, holes=()):
    """x = xc 박공벽(통나무 켜가 지붕 밑선까지). holes 는 세계 y 기준(yc 를 뺀 값으로 바꿔 넘긴다)"""
    loc = [(a - yc, b - yc, za, zb) for a, b, za, zb in holes]
    K.L.transformed(g, Matrix.Translation((0, yc, 0)),
                    lambda q: K.gable_logs(q, "y", xc, R.half, R.z_plate, lambda m: R.zb(m) - 0.05, holes=loc))


# ------------------------------------------------------------------ 난로
def iron_stove(g, x, y, z0, z_pipe, face=-1, r=1.1, vent=True):
    """무쇠 난로(G1 가운데 난로): 돌 깔판 · 다리 넷 · 둥근 몸(놋쇠 띠) · 앞 불 문(불빛 틈) · 진짜 불 · 뚜껑 · 연통(z_pipe 까지, 지붕을 뚫는 쪽은 roof openings 로)"""
    bx(g, "Stone", x - 1.7, x + 1.7, y - 1.7, y + 1.7, z0, z0 + 0.2)
    zb = z0 + 0.2
    for dx in (-0.7, 0.7):
        for dy in (-0.7, 0.7):
            bx(g, "Iron", x + dx - 0.15, x + dx + 0.15, y + dy - 0.15, y + dy + 0.15, zb, zb + 0.6)
    g["Iron"].cyl(x, y, zb + 0.6, r, r, 2.6, seg=16)
    for z in (zb + 0.75, zb + 3.0):
        g["Brass"].cyl(x, y, z, r + 0.04, r + 0.04, 0.14, seg=16)
    fy = y + face * (r - 0.05)
    bx(g, "Soot", x - 0.55, x + 0.55, *sorted((fy, fy + face * 0.15)), zb + 1.1, zb + 2.2)
    bx(g, "Core", x - 0.4, x + 0.4, *sorted((fy + face * 0.15, fy + face * 0.18)), zb + 1.25, zb + 1.4)
    bx(g, "Brass", x + 0.35, x + 0.5, *sorted((fy + face * 0.15, fy + face * 0.3)), zb + 1.5, zb + 1.8)
    K.I.FIRE(x, y, zb + 1.3, 0.6)
    g["Iron"].cyl(x, y, zb + 3.2, r + 0.15, r * 0.6, 0.5, seg=16)
    g["Iron"].cyl(x, y, zb + 3.7, 0.32, 0.32, z_pipe - zb - 3.7, seg=10)
    for z in (zb + 6.0, z_pipe - 0.6):
        g["Brass"].cyl(x, y, z, 0.38, 0.38, 0.15, seg=10)
    g["Iron"].cyl(x, y, z_pipe - 3.0, 0.42, 0.42, 3.0, seg=10)   # 지붕 위 굵은 토막(멀리서 읽히게)
    g["Iron"].cyl(x, y, z_pipe, 0.85, 0.2, 0.7, seg=10)          # 연통 갓
    for k in range(3):
        a = k * 2.09
        bx(g, "Iron", x + 0.6 * math.cos(a) - 0.05, x + 0.6 * math.cos(a) + 0.05, y + 0.6 * math.sin(a) - 0.05, y + 0.6 * math.sin(a) + 0.05, z_pipe - 0.4, z_pipe + 0.1)
    if vent:
        K.S.vent(g, x, y, z_pipe + 0.9)
    cbox(x - r, x + r, y - r, y + r, z0, zb + 3.7)


def glass_case(g, x0, x1, y0, y1, z0=FZ, seed=0):
    """유리 진열 카운터: 짙은 나무 몸(높이 2.6) + 유리 윗단(0.9) + 밝은 나무 테 + 안 물건"""
    zt = z0 + 2.6
    bx(g, "Timber", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, z0, zt)
    bx(g, "Wood", x0, x1, y0, y1, zt, zt + 0.15)
    bx(g, "Glass", x0 + 0.15, x1 - 0.15, y0 + 0.15, y1 - 0.15, zt + 0.15, zt + 0.95)
    for xx in (x0 + 0.05, x1 - 0.05):
        for yy in (y0 + 0.05, y1 - 0.05):
            bx(g, "Brass", xx - 0.08, xx + 0.08, yy - 0.08, yy + 0.08, zt + 0.15, zt + 1.0)
    bx(g, "Wood", x0, x1, y0, y1, zt + 0.95, zt + 1.05)
    long_x = (x1 - x0) >= (y1 - y0)
    n = int(max(x1 - x0, y1 - y0) / 1.3)
    mats = ("Brass", "Copper", "Canvas", "Steel", "Leather")
    for i in range(n):
        t = (i + 0.5) / n
        cx = x0 + (x1 - x0) * t if long_x else (x0 + x1) / 2
        cy = (y0 + y1) / 2 if long_x else y0 + (y1 - y0) * t
        bx(g, mats[(i + seed) % len(mats)], cx - 0.35, cx + 0.35, cy - 0.3, cy + 0.3, zt + 0.15, zt + 0.5)
    cbox(x0, x1, y0, y1, z0, zt + 1.05)


# ------------------------------------------------------------------ 간판 그림
def airship_icon(g, x, y, z, face=-1, s=1.0):
    """비행선 그림(판 면에 붙음, z = 그림 아래 끝): 천 몸통 · 놋쇠 띠 · 꼬리 날개 · 아래 곤돌라"""
    yf = y + face * 0.12
    g["Canvas"].hcyl(x, yf, z + 1.2 * s, 0.6 * s, 2.4 * s, axis="x", seg=12)
    for dx in (-1.25, 1.25):
        g["Canvas"].hcyl(x + dx * s, yf, z + 1.2 * s, 0.38 * s, 0.25 * s, axis="x", seg=10)
    for dx in (-0.6, 0.0, 0.6):
        g["Brass"].hcyl(x + dx * s, yf, z + 1.2 * s, 0.63 * s, 0.08, axis="x", seg=12)
    for dz in (-1, 1):
        g["Timber"].obox(x - 1.45 * s, yf, z + (1.2 + dz * 0.45) * s, 0.5 * s, 0.12, 0.35 * s, ry=dz * 0.6)
    bx(g, "Brass", x - 0.45 * s, x + 0.45 * s, yf - 0.08, yf + 0.08, z + 0.1 * s, z + 0.45 * s)
    for dx in (-0.3, 0.3):
        bx(g, "Iron", x + dx * s - 0.04, x + dx * s + 0.04, yf - 0.04, yf + 0.04, z + 0.45 * s, z + 0.65 * s)


# ------------------------------------------------------------------ 난간·장선
def rail_between(g, ax, c, a, b, z0, h=3.4, gap=0.9, mat="DarkLog"):
    """기둥과 기둥 사이 난간(a..b = 두 기둥 안쪽 면): 아랫대 · 윗대(손잡이) · 세로 살. 난간 위에는 아무것도 올리지 않는다"""
    if b - a < 0.3:
        return
    K.beam(g, ax, c - 0.25, c + 0.25, a, b, z0 + 0.3, z0 + 0.6, mat=mat)
    K.beam(g, ax, c - 0.3, c + 0.3, a, b, z0 + h - 0.35, z0 + h, mat=mat)
    n = max(1, int((b - a) / gap))
    for i in range(n):
        u = a + (b - a) * (i + 0.5) / n
        K.beam(g, ax, c - 0.12, c + 0.12, u - 0.12, u + 0.12, z0 + 0.6, z0 + h - 0.35, mat="Timber")
    if ax == "x":
        cbox(a, b, c - 0.3, c + 0.3, z0, z0 + h)
    else:
        cbox(c - 0.3, c + 0.3, a, b, z0, z0 + h)


def joists(g, ax, c0, c1, a0, a1, z_top, gap=2.0, deck=0.3, s=0.6):
    """장선: ax 방향으로 뻗은 각재(c0..c1 사이에 gap 간격) — 보 위에 얹고 그 위에 마루 판(deck). 돌려주는 값 = 마루 윗면"""
    n = max(1, int(round((c1 - c0) / gap)))
    for i in range(n + 1):
        c = c0 + (c1 - c0) * i / n
        K.beam(g, ax, c - s / 2, c + s / 2, a0, a1, z_top - deck - s, z_top - deck, mat="Timber")
    if ax == "x":
        bx(g, "Wood", a0, a1, c0 - s / 2, c1 + s / 2, z_top - deck, z_top)
    else:
        bx(g, "Wood", c0 - s / 2, c1 + s / 2, a0, a1, z_top - deck, z_top)
    return z_top


def lattice_leg(g, p0, p1, s=0.8, mat="Iron"):
    """두 점 사이 쇠 각재 한 덩이(격자탑 다리·가새·가로대)"""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    Ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    import bmesh
    m = (Matrix.Translation(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2))
         @ _align(dx / Ln, dy / Ln, dz / Ln) @ Matrix.Diagonal((s, s, Ln, 1.0)))
    bmesh.ops.create_cube(g[mat].bm, size=1.0, matrix=m)


def _align(x, y, z):
    """z 축을 (x, y, z) 방향으로 돌리는 행렬"""
    from mathutils import Vector
    return Vector((0, 0, 1)).rotation_difference(Vector((x, y, z))).to_matrix().to_4x4()


def jar_row(g, x0, x1, y, z, seed=0, d=0.5, liquids=("SignRed", "SignTeal", "SignPurple", "Verdigris", "SignGold", "GlowTeal")):
    """약장 칸 병 줄(가벼운 네모 병 — 삼각형 아낌): 유리 몸 · 물약 · 나무 마개. 높이·폭을 손으로 정한 순서로 바꾼다"""
    hs, ws = (1.0, 0.7, 0.85, 0.6, 0.95, 0.75), (0.5, 0.42, 0.55, 0.38, 0.48)
    x, k = x0 + 0.15, seed
    while x < x1 - 0.5:
        w, h = ws[k % len(ws)], hs[k % len(hs)]
        bx(g, liquids[(k * 5) % len(liquids)], x, x + w, y - d / 2, y + d / 2, z, z + h * 0.62)      # 물약이 찬 아래(색이 읽히게 겉으로)
        bx(g, "Glass", x + 0.04, x + w - 0.04, y - d / 2 + 0.04, y + d / 2 - 0.04, z + h * 0.62, z + h)
        bx(g, "Wood", x + w * 0.3, x + w * 0.7, y - 0.12, y + 0.12, z + h, z + h + 0.15)
        x += w + 0.12
        k += 1


def flask(g, x, y, z0, liquid, r=0.5, h=1.3):
    """큰 약병(카운터·진열창): 물약 찬 둥근 몸(색이 겉으로) · 유리 어깨·목 · 나무 마개"""
    g[liquid].cyl(x, y, z0, r * 0.85, r, h * 0.55, seg=10)
    g["Glass"].cyl(x, y, z0 + h * 0.55, r, r * 0.35, h * 0.25, seg=10)
    g["Glass"].cyl(x, y, z0 + h * 0.8, r * 0.3, r * 0.3, h * 0.2, seg=8)
    g["Wood"].cyl(x, y, z0 + h, r * 0.33, r * 0.28, 0.18, seg=8)


def stair_x(g, x_bot, x_top, y0, y1, z0, z1, open_y=None, guard_from=2, guard_h=3.0):
    """x 방향 곧은 나무 계단(한 단 STEP_RISE 이하 · 디딤 STEP_TREAD): x_bot(맨 아랫단 앞) → x_top(맨 윗단 끝, 위층 바닥 가장자리).
    단마다 몸(Timber, 바닥부터 꽉 참 — 계단 밑은 막힌 덩어리) + 밝은 디딤판(Wood) + 충돌 상자.
    open_y = 열린 옆(벽이 없는 쪽) y — 그 옆에 측판 겸 막힌 난간판(DarkLog, 디딤 위 guard_h)을 guard_from 단부터 세운다(아랫단 둘은 옆에서 올라설 수 있게 비움)"""
    n = max(1, int(math.ceil((z1 - z0) / K.STEP_RISE - 1e-6)))
    rs = (z1 - z0) / n
    d = (x_top - x_bot) / n
    for k in range(n):
        top = z0 + rs * (k + 1)
        xa, xb = sorted((x_bot + d * k, x_top))
        bx(g, "Timber", xa, xb, y0, y1, z0 if k == 0 else top - rs, top - 0.15)
        xs0, xs1 = sorted((x_bot + d * k, x_bot + d * (k + 1)))
        bx(g, "Wood", xs0 - 0.05, xs1, y0 - 0.05, y1, top - 0.15, top)
        cbox(xs0, xs1, y0, y1, z0, top)
        if open_y is not None and k >= guard_from:
            ya, yb = sorted((open_y, open_y + (-0.5 if open_y <= y0 else 0.5)))
            bx(g, "DarkLog", xs0, xs1, ya, yb, top - rs - 0.6, top + guard_h)
            bx(g, "Wood", xs0, xs1, ya - 0.08, yb + 0.08, top + guard_h, top + guard_h + 0.15)
            cbox(xs0, xs1, ya, yb, top - rs, top + guard_h)
    return n


def partition(g, ax, c, a, b, z0, z1, t=0.6):
    """판 칸막이(위층 방 사이): 양끝 기둥(바닥 위) + 위 머리보 + 세로 판. 충돌 상자"""
    for u in (a, b):
        K.beam(g, ax, c - 0.45, c + 0.45, u - 0.45, u + 0.45, z0, z1, mat="DarkLog")
    K.beam(g, ax, c - 0.4, c + 0.4, a, b, z1 - 0.6, z1, mat="DarkLog")
    K.beam(g, ax, c - 0.4, c + 0.4, a, b, z0, z0 + 0.4, mat="DarkLog")
    nb = max(1, int(round((b - a - 0.9) / 1.0)))
    w = (b - a - 0.9) / nb
    for i in range(nb):
        u = a + 0.45 + i * w
        K.beam(g, ax, c - t / 2 - (0.06 if i % 2 else 0.0), c + t / 2, u, u + w, z0 + 0.4, z1 - 0.6, mat="Timber")
    if ax == "x":
        cbox(a - 0.45, b + 0.45, c - t / 2, c + t / 2, z0, z1)
    else:
        cbox(c - t / 2, c + t / 2, a - 0.45, b + 0.45, z0, z1)


def long_table(g, x0, x1, y0, y1, z0, benches=True):
    """긴 식탁(밝은 상판 + 짙은 다리 넷 + 가로대) + 양옆 긴 걸상(옛 bench)"""
    zt = z0 + 2.6
    bx(g, "Wood", x0, x1, y0, y1, zt - 0.25, zt)
    for x in (x0 + 0.5, x1 - 0.5):
        for y in (y0 + 0.4, y1 - 0.4):
            bx(g, "Timber", x - 0.2, x + 0.2, y - 0.2, y + 0.2, z0, zt - 0.25)
    bx(g, "Timber", x0 + 0.5, x1 - 0.5, (y0 + y1) / 2 - 0.12, (y0 + y1) / 2 + 0.12, z0 + 0.6, z0 + 0.85)
    cbox(x0, x1, y0, y1, z0, zt)
    if benches:
        for y in (y0 - 1.1, y1 + 1.1):
            K.SVC.bench(g, (x0 + x1) / 2, y, z0, x1 - x0 - 0.6, axis="x", mat="Wood")
