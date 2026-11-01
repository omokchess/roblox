# -*- coding: utf-8 -*-
"""
build_snow_forge.py — 2026-11-01. (구)설공방 폐허의 대장간 화덕(블렌더). 사용자: "화로를 주변 풍경에 어울리는 품질로 —
낡고 마모된 건 당연하고, 블렌더에서 작업해서 톱니바퀴보다 품질이 딸리지 않게".

레퍼런스: 옛 대장간 화덕(돌 받침 · 벽돌 화실 · 내쌓기 덮개 · 굴뚝 · 큰 가죽 풀무 · 담금 통), 불난 벽돌 건물 폐허
(그을음은 아가리·굴뚝 끝에서 짙고 멀어질수록 옅다, 덮개 앞 모서리가 무너지고 굴뚝 끝은 줄마다 다른 높이로 부러진다).
  돌 받침  허리 높이 2.6 — 길이 다른 다듬은 돌 줄(줄눈이 보이게 뒤에 밝은 줄눈 덩이), 위 띠돌 판 셋(한 판은 귀가 깨짐)
  화실    벽돌 줄쌓기(반 장 엇갈림). 벽돌마다 조금 튀어나오고 들어가고 비뚤고, 몇 장은 빠짐. 그을음 = 아가리에서 가까울수록 짙은 벽돌
  덮개    내쌓기 셋(앞으로 0.15 씩) + 들여쌓기 셋(굴뚝으로 좁아짐) — 오른쪽 앞 모서리는 무너짐
  굴뚝    속이 빈 굴뚝(검은 연도), 줄마다 다른 높이로 부러진 끝, 쇠띠 둘(위 띠는 끊겨 한 토막이 늘어짐)
  불자리  쇠 화로 그릇 + 숯덩이 + 풀무에서 오는 송풍관 · 오른쪽 가죽 풀무(받침·판·주름·지렛대) · 왼쪽 담금 통(얼음) · 집게
  주변    떨어진 벽돌 · 무너진 덮개 덩이 · 눈(덮개 단·굴뚝 끝·받침 귀·밑동 더미)
원점 = 바닥 가운데, 앞 = -y(블렌더). 앞머리 SelForge → Studio 틀 ServerStorage.SnowKit.Sel_Forge_Ruin(tools/Snow_Kit.luau 가 가른다).
돌리기: blender -b -P models/build_snow_forge.py [-- render]  →  models/forge_only/SnowKit.fbx (+ models/snowtown_render/Sel_Forge_Ruin_*.png)
"""
import math
import os
import random
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
import zfight_scan as Z  # noqa: E402

RNG = random.Random(20261101)
BL, BH, JOINT, BDEPTH = 1.0, 0.4, 0.06, 0.5      # 벽돌 길이 · 높이 · 줄눈 · 박힌 깊이


def pick(soot):
    """그을음 0..1 → 재질. 짙을수록 그을린 벽돌, 아주 짙으면 숯검정."""
    r = RNG.random()
    if soot > 0.82 and r < (soot - 0.82) * 4.5:
        return "Soot"
    return "BrickDark" if r < soot * 0.95 else "Brick"


def bricks(g, face, plane, u0, u1, z0, z1, soot=lambda u, z: 0.0, skip=lambda u, z: False, top=None, offset=0.0, miss=0.035):
    """벽 한 면의 벽돌. face = 바깥을 보는 쪽('-y' '+y' '-x' '+x'), plane = 그 면 좌표. u = 면을 따라(x 또는 y), z = 높이.
    top(u) 가 있으면 그 높이 위 벽돌은 안 놓는다(부러진 끝). 반 장 엇갈림 · 튀어나옴 · 비뚤어짐 · 빠진 벽돌 · 깨진 반쪽."""
    k = 0
    z = z0
    while z + BH <= z1 + 1e-6:
        u = u0 - (BL / 2 if k % 2 else 0) - offset
        while u < u1 - 1e-6:
            a, b = max(u, u0), min(u + BL, u1)
            u += BL
            if b - a < 0.2:
                continue
            cu, cz = (a + b) / 2, z + BH / 2
            if skip(cu, cz) or (top and cz > top(cu)) or RNG.random() < miss:
                continue
            w = b - a - JOINT
            if RNG.random() < 0.06:          # 깨진 반쪽
                w *= 0.6
                cu += (RNG.random() - 0.5) * (b - a - w)
            out = RNG.uniform(-0.04, 0.05)
            tw = RNG.uniform(-0.025, 0.025)
            mat = pick(soot(cu, cz))
            h = BH - JOINT + RNG.uniform(-0.02, 0.0)
            if face in ("-y", "+y"):
                s = -1 if face == "-y" else 1
                g[mat].obox(cu, plane - s * BDEPTH / 2 + s * out, cz, w, BDEPTH, h, rz=tw)
            else:
                s = -1 if face == "-x" else 1
                g[mat].obox(plane - s * BDEPTH / 2 + s * out, cu, cz, BDEPTH, w, h, rz=tw)
        z += BH
        k += 1
    return z


def stones(g, face, plane, u0, u1, rows, z0=0.0):
    """다듬은 돌 줄(돌 받침). rows = 줄 높이들. 돌 길이 1.1~2.0, 귀가 깨진 돌 몇."""
    z = z0
    for k, rh in enumerate(rows):
        u = u0 - RNG.uniform(0, 0.8) * (k % 2)
        while u < u1 - 0.2:
            ln = RNG.uniform(1.1, 2.0)
            a, b = max(u, u0), min(u + ln, u1)
            u += ln
            if b - a < 0.3:
                continue
            w, h = b - a - 0.08, rh - 0.08
            out = RNG.uniform(-0.03, 0.07)
            cu, cz = (a + b) / 2, z + rh / 2
            mat = "Stone"
            if face in ("-y", "+y"):
                s = -1 if face == "-y" else 1
                g[mat].obox(cu, plane - s * 0.35 + s * out, cz, w, 0.7, h, rz=RNG.uniform(-0.015, 0.015))
            else:
                s = -1 if face == "-x" else 1
                g[mat].obox(plane - s * 0.35 + s * out, cu, cz, 0.7, w, h, rz=RNG.uniform(-0.015, 0.015))
        z += rh


def loose_brick(g, x, y, z, mat=None):
    g[mat or ("BrickDark" if RNG.random() < 0.45 else "Brick")].obox(
        x, y, z, BL - JOINT, BDEPTH, BH - JOINT, rx=RNG.uniform(-0.5, 0.5), ry=RNG.uniform(-0.4, 0.4), rz=RNG.uniform(0, math.pi))


def forge(g):
    # ── 돌 받침(x -5..5, y -5.6..4.8, 높이 2.6) ──
    g["StoneTrim"].box(0, -0.4, 1.26, 9.84, 10.2, 2.52)                              # 줄눈 덩이(속)
    stones(g, "-y", -5.6, -5.0, 5.0, (0.9, 0.85, 0.77))
    stones(g, "-x", -5.0, -5.6, 4.8, (0.9, 0.85, 0.77))
    stones(g, "+x", 5.0, -5.6, 4.8, (0.9, 0.85, 0.77))
    for x0, x1, chip in ((-5.15, -1.82, False), (-1.76, 1.62, False), (1.68, 5.15, True)):   # 띠돌 판 셋(오른 판은 앞 귀가 깨짐)
        g["StoneTrim"].obox((x0 + x1) / 2, -0.4, 2.67 + RNG.uniform(-0.02, 0.02), x1 - x0, 10.5, 0.3, ry=RNG.uniform(-0.01, 0.01))
        if chip:
            g["Stone"].obox(x1 - 0.6, -5.7, 2.6, 1.3, 0.5, 0.3, rz=0.4, ry=0.2)          # 깨져 나간 귀 조각(앞에 걸침)
    Z0 = 2.82
    # ── 화실: 왼·오른 벽(x ±2.6..±4.7, y -4.9..4.6) · 뒷벽(y 1.4..4.6) · 아가리(x -2.6..2.6, 높이 Z0..6.6) ──
    def soot_out(u, z):        # 바깥 면: 아가리에 가까울수록, 위로 갈수록 짙다
        return max(0.0, 0.75 - abs(abs(u) - 2.6) * 0.35) * min(1.0, (z - Z0) / 3.5) + 0.08
    def soot_in(u, z):         # 화실 안: 거의 다 그을림
        return 0.85 + 0.15 * min(1.0, (z - Z0) / 3.0)
    for s in (-1, 1):
        xo, xi = s * 4.7, s * 2.6
        g["StoneTrim"].box(s * 3.65, -0.15, (Z0 + 7.75) / 2, 1.94, 9.36, 7.75 - Z0)   # 벽 속(줄눈)
        bricks(g, "-y", -4.9, min(xo, xi), max(xo, xi), Z0, 7.75, soot=soot_out)
        bricks(g, "-x" if s < 0 else "+x", xo, -4.9, 4.6, Z0, 7.75, soot=lambda u, z: 0.06 + max(0, -u - 2) * 0.05, offset=0.5)
        bricks(g, "+x" if s < 0 else "-x", xi, -4.9, 1.4, Z0, 6.6, soot=soot_in)
    g["Soot"].box(0, 3.0, (Z0 + 7.75) / 2, 5.2, 3.2, 7.75 - Z0)                       # 뒷벽 속(그을린 줄눈)
    bricks(g, "-y", 1.4, -2.6, 2.6, Z0, 6.6, soot=soot_in)
    g["Soot"].box(0, -1.75, 6.75, 5.2, 6.3, 0.3)                                      # 화실 천장
    # 아가리 위: 쇠 인방(조금 처짐) + 세워 쌓은 벽돌 줄
    g["Iron"].obox(0, -4.82, 6.72, 5.9, 0.3, 0.24, ry=0.012)
    g["Iron"].obox(0, -4.7, 6.6, 5.9, 0.08, 0.22, ry=0.012)
    x = -2.6
    while x < 2.6 - 0.2:
        if RNG.random() > 0.05:
            g[pick(0.7)].obox(x + 0.2, -4.9 + BDEPTH / 2 - RNG.uniform(-0.03, 0.05), 7.31, 0.34, BDEPTH, 0.86, ry=RNG.uniform(-0.04, 0.04))
        x += 0.4
    # ── 덮개: 내쌓기 셋 + 들여쌓기 셋(z 7.75..10.15), 오른쪽 앞 모서리 무너짐 ──
    def fallen(u, z, edge):
        return u > edge + RNG.uniform(0, 0.7)
    z = 7.75
    for c in range(6):
        if c < 3:
            fy, hx = -4.9 - 0.15 * (c + 1), 4.7 + 0.1 * (c + 1)
        else:
            fy, hx = -5.35 + (c - 2) * 1.1, 4.7 - (c - 2) * 0.6
        by_ = 4.6
        broken = c >= 1
        edge = 1.8 if c < 3 else 1.2
        # 속(무너진 귀는 비움)
        # 속은 그을린 벽돌 색 — 들여쌓은 단의 윗면이 보이니까(회색이면 시멘트 판처럼 보인다)
        if broken:
            g["BrickDark"].box((-hx + 0.08 + edge) / 2, (fy + 0.1 + by_) / 2, z + BH / 2, edge + hx - 0.08, by_ - fy - 0.1, BH)
            g["BrickDark"].box((edge + hx - 0.08) / 2, (-1.0 + by_) / 2, z + BH / 2, hx - 0.08 - edge, by_ + 1.0, BH)
        else:
            g["BrickDark"].box(0, (fy + 0.1 + by_) / 2, z + BH / 2, 2 * hx - 0.16, by_ - fy - 0.1, BH)
        sootc = lambda u, zz: 0.35 + 0.1 * c
        bricks(g, "-y", fy, -hx, hx, z, z + BH, soot=sootc, skip=(lambda u, zz: broken and fallen(u, zz, edge)), offset=0.5 * (c % 2), miss=0.05)
        bricks(g, "-x", -hx, fy, by_, z, z + BH, soot=lambda u, zz: 0.2)
        bricks(g, "+x", hx, fy, by_, z, z + BH, soot=lambda u, zz: 0.25, skip=(lambda u, zz: broken and u < -1.0 + RNG.uniform(-0.6, 0.6)))
        if c >= 3:   # 들여쌓은 단의 앞 윗면에 눈
            g["SnowCap"].obox(-0.6, fy - 0.35, z - 0.02, 2 * hx - 2.6, 0.6, 0.12, ry=RNG.uniform(-0.02, 0.02))
        z += BH
    # 무너진 귀에 남은 깨진 벽돌 몇(비뚤게 걸침)
    for (x, y, zz) in ((2.4, -4.4, 8.25), (3.1, -3.7, 8.6), (2.0, -3.0, 9.0), (3.6, -2.4, 8.2)):
        loose_brick(g, x, y, zz)
    # ── 굴뚝(x -2.5..2.5, y 0.4..4.6), 속 빈 연도, 줄마다 부러진 끝 ──
    CZ = z

    def top_front(u):     # 앞·옆 면 부러진 끝 높이(왼쪽이 높고 오른쪽이 낮음, 들쭉날쭉)
        return 17.4 - max(0.0, u + 0.5) * 0.55 + math.sin(u * 3.1) * 0.35

    # 속(줄눈) — 벽돌 면에서 0.1 들인다(살짝 들어간 벽돌이 속에 묻히지 않게)
    for x0, x1, y0, y1 in ((-2.4, -1.7, 0.5, 4.6), (1.7, 2.4, 0.5, 4.6), (-1.7, 1.7, 0.5, 1.2), (-1.7, 1.7, 3.8, 4.6)):
        g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, (CZ + 15.0) / 2, x1 - x0, y1 - y0, 15.0 - CZ)
    g["Soot"].box(0, 2.5, (CZ + 15.6) / 2, 3.38, 2.58, 15.6 - CZ)                    # 연도(검게)
    bricks(g, "-y", 0.4, -2.5, 2.5, CZ, 18.0, soot=lambda u, zz: 0.15 + max(0, zz - 15.0) * 0.3, top=top_front)
    bricks(g, "-x", -2.5, 0.4, 4.6, CZ, 18.0, soot=lambda u, zz: 0.12 + max(0, zz - 15.5) * 0.3, top=lambda u: 17.6 - u * 0.12, offset=0.5)
    bricks(g, "+x", 2.5, 0.4, 4.6, CZ, 18.0, soot=lambda u, zz: 0.12 + max(0, zz - 15.0) * 0.3, top=lambda u: 15.6 + math.sin(u * 2.3) * 0.4, offset=0.5)
    for (x, y, zz) in ((-1.9, 1.4, 17.75), (-0.9, 0.9, 17.2), (2.1, 2.2, 16.0)):      # 끝에 얹힌 헐거운 벽돌
        loose_brick(g, x, y, zz, "BrickDark")
    def top_surface(t):   # 가운데가 t 아래인 마지막 줄의 윗면
        return CZ + BH * (math.floor((t - CZ) / BH - 0.5) + 1)

    for (x, y, w, t) in ((-2.0, 0.65, 1.1, top_front(-2.0)), (-0.9, 0.65, 0.8, top_front(-0.9)), (-2.25, 2.4, 0.6, 17.6 - 2.4 * 0.12),
                         (2.25, 3.2, 0.6, 15.6 + math.sin(3.2 * 2.3) * 0.4)):   # 끝의 눈(맨 위 벽돌에 얹힘)
        g["SnowCap"].obox(x, y, top_surface(t) + 0.06, w, 0.6, 0.12, rz=RNG.uniform(-0.15, 0.15))
    # 쇠띠 둘(아래 띠는 성함, 위 띠는 앞이 끊겨 한 토막이 늘어짐) + 볼트
    for zz, whole in ((12.2, True), (14.6, False)):
        if whole:
            g["Iron"].box(0, 0.38, zz, 5.12, 0.08, 0.26)
        g["Iron"].box(-2.53, 2.5, zz, 0.08, 4.2, 0.26)
        g["Iron"].box(2.53, 2.5, zz, 0.08, 4.2, 0.26)
        for x in (-2.55, 2.55):
            g["Iron"].box(x, 0.38, zz, 0.18, 0.18, 0.18)
    g["Iron"].obox(-2.0, 0.3, 13.9, 1.6, 0.08, 0.26, ry=-0.9)                         # 끊겨 늘어진 토막
    # ── 불자리: 쇠 화로 그릇 · 숯덩이 · 송풍관 ──
    g["Iron"].cyl(0, -1.6, Z0, 1.62, 1.5, 0.24, seg=18)
    g["Soot"].cyl(0, -1.6, Z0 + 0.02, 1.32, 1.32, 0.24, seg=16)
    for _ in range(16):
        a, r = RNG.uniform(0, math.tau), RNG.uniform(0, 1.15)
        sz = RNG.uniform(0.22, 0.48)
        g["Soot"].obox(math.cos(a) * r, -1.6 + math.sin(a) * r, Z0 + 0.3 + RNG.uniform(0, 0.12), sz, sz * 0.8, sz * 0.6,
                       rx=RNG.uniform(-0.6, 0.6), ry=RNG.uniform(-0.6, 0.6), rz=RNG.uniform(0, 3))
    g["Iron"].hcyl(3.9, -1.6, Z0 + 0.35, 0.2, 4.6, axis="x", seg=10)                # 송풍관(오른 벽을 지나 풀무로)
    g["Iron"].hcyl(4.75, -1.6, Z0 + 0.35, 0.3, 0.16, axis="x", seg=10)
    # 재 흘림(받침 앞)
    for x, w in ((-0.6, 1.6), (0.9, 1.0)):
        g["Stone"].obox(x, -5.4, 2.84, w, 0.7, 0.05, rz=RNG.uniform(-0.3, 0.3))
    # ── 가죽 큰 풀무(오른쪽 바깥) — 서양배 꼴 판 둘 사이 가죽 주름, 주둥이는 송풍관으로, 위 지렛대로 당긴다 ──
    def pear(cx, cy, sc):     # 판 꼴(뒤가 둥글고 앞 주둥이 쪽으로 좁아짐) — 주둥이 = -x(화덕 쪽)
        pts = []
        for k in range(9):    # 뒤 반원
            a_ = math.radians(-90 + k * 22.5)
            pts.append((cx + 1.0 * sc + math.cos(a_) * 1.6 * sc, cy + math.sin(a_) * 1.6 * sc))
        pts += [(cx - 0.9 * sc, cy + 0.7 * sc), (cx - 1.7 * sc, cy + 0.35 * sc), (cx - 1.7 * sc, cy - 0.35 * sc), (cx - 0.9 * sc, cy - 0.7 * sc)]
        return pts

    def slab(mat, pts, z0, z1):
        n = len(pts)
        verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
        faces = [list(range(n))[::-1], list(range(n, 2 * n))] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        g[mat].add_mesh(verts, faces)

    BX, BY = 7.3, -1.6
    for lx, ly in ((5.9, -2.9), (8.9, -2.9), (5.9, -0.3), (8.9, -0.3)):              # 받침 두 짝(가새)
        g["Timber"].obox(lx, ly, 0.95, 0.3, 0.3, 1.9, rx=RNG.uniform(-0.03, 0.03))
    for ly in (-2.9, -0.3):
        g["Timber"].box(7.4, ly, 1.95, 3.6, 0.32, 0.3)
        g["Timber"].obox(7.4, ly, 1.0, 3.0, 0.2, 0.2, ry=0.55)
    slab("Wood", pear(BX, BY, 1.0), 2.15, 2.33)                                      # 아랫판
    for k in range(4):                                                               # 가죽 주름(가운데가 불룩, 주름 사이 그늘)
        sc = 0.93 + (0.05 if k in (1, 2) else 0.0)
        slab("Leather", pear(BX + 0.05, BY, sc), 2.33 + k * 0.22, 2.51 + k * 0.22)
        slab("Soot", pear(BX + 0.05, BY, sc - 0.04), 2.51 + k * 0.22, 2.55 + k * 0.22)
    slab("Wood", pear(BX, BY, 1.0), 3.22, 3.4)                                       # 윗판
    g["Iron"].obox(BX + 1.0, BY, 3.42, 0.16, 2.6, 0.08)                             # 판 쇠띠
    g["Iron"].obox(BX - 0.4, BY, 3.42, 0.16, 1.6, 0.08)
    g["Iron"].hcyl(5.2, BY, 2.75, 0.2, 0.9, axis="x", seg=10)                        # 주둥이(송풍관에 물림)
    g["Soot"].obox(BX + 1.8, BY - 1.25, 2.7, 0.6, 0.05, 0.35, rz=0.5)                # 찢어진 가죽 자국
    g["Timber"].box(BX + 2.5, BY, 3.0, 0.34, 0.34, 6.0)                              # 지렛대 기둥
    g["Iron"].hcyl(BX + 2.5, BY, 5.8, 0.12, 0.6, axis="y", seg=8)                     # 굴대
    g["Timber"].obox(BX + 0.8, BY, 5.55, 4.6, 0.24, 0.24, ry=0.12)                   # 지렛대(화덕 쪽이 조금 처짐)
    g["Iron"].obox(BX + 0.6, BY, 4.45, 0.08, 0.08, 2.1)                              # 윗판과 잇는 쇠막대
    g["Iron"].obox(BX - 1.4, BY, 5.25, 0.5, 0.5, 0.5)                                # 손잡이 쪽 추
    # ── 담금 통(왼쪽 앞 바깥 — 반 통, 얼어붙은 물) · 집게 ──
    g["Timber"].cyl(-6.5, -3.4, 0, 1.15, 1.25, 1.6, seg=16)
    for zz in (0.25, 1.25):
        g["Iron"].cyl(-6.5, -3.4, zz, 1.2 + zz * 0.05, 1.21 + zz * 0.05, 0.12, seg=16)
    g["Glass"].cyl(-6.5, -3.4, 1.5, 1.05, 1.08, 0.06, seg=16)
    g["SnowCap"].obox(-6.8, -3.1, 1.6, 0.9, 0.7, 0.14, rz=0.6)
    for dx in (-0.12, 0.12):                                                           # 받침에 기댄 집게 한 벌
        g["Iron"].obox(-5.35 + dx, -5.95, 1.35, 0.1, 0.1, 2.8, rx=0.32, ry=dx * 0.6)
    g["Iron"].obox(-5.35, -6.4, 0.12, 0.5, 0.18, 0.18)
    # ── 떨어진 벽돌 · 무너진 덮개 덩이 · 눈 더미 ──
    for (x, y) in ((3.6, -6.4), (4.4, -7.1), (2.8, -7.6), (5.2, -6.0), (1.9, -6.6), (4.9, -8.2), (-3.4, -6.5), (0.6, -7.2)):
        loose_brick(g, x, y, 0.2)
    for k in range(5):                                                                 # 덮개 덩이: 벽돌 다섯이 붙은 채
        g["BrickDark" if k % 2 else "Brick"].obox(3.4 + k * 0.48, -9.0, 0.45 + (k % 2) * 0.38, 0.94, 0.48, 0.34, rz=0.35, ry=0.18)
    g["StoneTrim"].obox(4.4, -9.05, 0.5, 2.6, 0.42, 0.66, rz=0.35, ry=0.18)
    for (x, y, w, d, h) in ((-5.0, 4.4, 2.4, 1.6, 0.9), (5.4, 4.2, 2.0, 1.4, 0.7), (-6.0, -5.4, 1.6, 1.2, 0.5)):
        g["SnowCap"].obox(x, y, h / 2, w, d, h, rz=RNG.uniform(-0.3, 0.3))
    g["SnowCap"].obox(-4.2, 4.0, 2.86, 1.6, 1.2, 0.14, rz=0.2)                        # 받침 뒤 귀의 눈


if __name__ == "__main__":
    RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    L.clear_scene()
    g = S.G("SelForge")
    forge(g)
    zm, zl = Z.fix(g, "Sel_Forge_Ruin")
    objs, total = [], 0
    for k in S.PALETTE:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris <= 10000, (ob.name, tris)
        total += tris
        objs.append(ob)
        print("  %-22s %6d tri" % (ob.name, tris))
    print("Sel_Forge_Ruin %d tri · 반짝임 민 면 %d 남음 %d" % (total, zm, zl))
    m = L.Group("SnowOrigin_Marker", L.material("Stone", S.PALETTE))
    m.box(0, 0, 0, 0.8, 0.8, 0.8)
    marker = m.finish()
    if RENDER:
        from mathutils import Vector
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light, sh.color_type = "STUDIO", "MATERIAL"
        sh.show_cavity = True
        sh.show_shadows = True
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.62, 0.72, 0.82)
        scene.render.resolution_x, scene.render.resolution_y = 900, 900
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        cam.data.lens = 50
        marker.hide_render = True
        out = os.path.join(HERE, "snowtown_render")
        os.makedirs(out, exist_ok=True)
        for tag, d in (("front", Vector((0.55, -1.0, 0.42))), ("side", Vector((1.0, -0.35, 0.3))), ("top", Vector((-0.6, -0.7, 0.9)))):
            mid = Vector((1.2, -1.0, 7.5))
            d = d.normalized()
            cam.location = mid + d * 34
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, "Sel_Forge_Ruin_%s.png" % tag)
            bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    os.makedirs(os.path.join(HERE, "forge_only"), exist_ok=True)
    fbx = os.path.join(HERE, "forge_only", "SnowKit.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("FBX:", fbx)
