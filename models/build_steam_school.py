# -*- coding: utf-8 -*-
"""
build_steam_school.py — 2026-10-10. 슈네라이히 학교(Schule). 카지노가 있던 동쪽 끝 자리를 통째로 학교로(사용자: 카지노 옆에 학교 느낌이
이상하다 → 카지노는 지하로, 그 구역은 학교). 놀이터(남서)가 운동장이 된다.

  본관 52×36, 2층: 가운데 홀(두 층 높이, 가운데 계단 → 뒤 회랑) + 아래 왼쪽 교실 · 아래 오른쪽 기계 교실 + 위 왼쪽 도서실 · 위 오른쪽 과학실.
  앞 현관(돌출) 위 종탑(종·시계·뾰족 지붕), 반원 채광창. 오른쪽(+x = 남, 놀이터 쪽) 체육관 동(24×20, 마당 문).
  창은 모두 진짜 구멍 + 맑은 유리(job cut=1.0).
좌표: 블렌더 (x, y, z), 앞 = -y(동대로를 본다). 로블록스 로컬 = (-x, z, y).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_steam as S  # noqa: E402
from build_steam_obs import sphere, sweep  # noqa: E402
from build_steam_inside import C, job, box2, wall_door, lantern, arch_top, door_leaf_in  # noqa: E402

R = math.radians
W, D, T = 52.0, 36.0, 1.0
ZB, ZF, ZS, Z1, Z2, ZW = 2.0, 2.2, 13.4, 14.0, 25.0, 25.6     # 받침 윗면 · 아래층 바닥 · 위층 판 밑 · 위층 바닥 · 위층 천장 · 벽 윗면
HX = 7.0                                                     # 가운데 홀 반폭(벽 가운데)
BOOKS = ("SignRed", "SignBlue", "SignTeal", "SignPurple", "Leather", "Canvas", "Banner", "SignGold")


# ------------------------------------------------------------------ 가구
def school_desk(g, x, y, z0, face=1.0):
    """옛 2인 책상(기울어진 상판·무쇠 옆틀) + 붙은 걸상. face = 학생이 보는 쪽(+x 1 / -x -1)"""
    f = face
    g["Wood"].obox(x, y, z0 + 2.55, 1.5, 3.2, 0.16, ry=f * 0.12)
    g["Wood"].box(x - f * 0.55, y, z0 + 2.62, 0.4, 3.2, 0.14)
    g["Wood"].box(x + f * 0.1, y, z0 + 2.2, 1.3, 3.0, 0.5)
    g["Brass"].cyl(x - f * 0.55, y + 0.8, z0 + 2.69, 0.1, 0.1, 0.08, seg=6)
    g["Brass"].cyl(x - f * 0.55, y - 0.8, z0 + 2.69, 0.1, 0.1, 0.08, seg=6)
    for sy in (-1, 1):
        g["Iron"].box(x - f * 0.5, y + sy * 1.45, z0 + 1.2, 2.8, 0.15, 0.2)
        g["Iron"].obox(x + f * 0.1, y + sy * 1.45, z0 + 1.2, 0.18, 0.15, 2.4, ry=f * 0.25)
        g["Iron"].obox(x - f * 1.25, y + sy * 1.45, z0 + 0.8, 0.18, 0.15, 1.6, ry=-f * 0.2)
        g["Iron"].box(x - f * 0.5, y + sy * 1.45, z0 + 0.1, 3.0, 0.3, 0.2)
    g["Wood"].box(x - f * 1.4, y, z0 + 1.55, 0.9, 3.2, 0.14)
    g["Wood"].box(x - f * 1.9, y, z0 + 2.3, 0.12, 3.2, 1.0)
    C(x - f * 0.6, y, z0 + 1.35, 2.9, 3.3, 2.7)


def chair(g, x, y, z0, rz=0.0, mat="Wood"):
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g[mat].obox(*P(0, 0), z0 + 1.5, 1.2, 1.2, 0.15, rz=rz)
    g[mat].obox(*P(0, 0.55), z0 + 2.4, 1.2, 0.12, 1.8, rz=rz)
    for u in (-0.5, 0.5):
        for v in (-0.5, 0.5):
            g[mat].obox(*P(u, v), z0 + 0.75, 0.14, 0.14, 1.5, rz=rz)


def teacher_desk(g, x, y, z0, rz=0.0):
    c, s = math.cos(rz), math.sin(rz)

    def P(u, v):
        return x + c * u - s * v, y + s * u + c * v
    g["Wood"].obox(x, y, z0 + 2.75, 4.2, 2.2, 0.2, rz=rz)
    for u in (-1.6, 1.6):
        g["Wood"].obox(*P(u, 0), z0 + 1.3, 1.0, 2.0, 2.6, rz=rz)
        for k in range(3):
            g["Brass"].obox(*P(u, -1.02), z0 + 0.6 + k * 0.8, 0.3, 0.06, 0.1, rz=rz)
    g["Wood"].obox(*P(0, 1.0), z0 + 1.8, 2.2, 0.12, 1.6, rz=rz)
    g["Canvas"].obox(*P(-0.6, 0), z0 + 2.88, 1.2, 0.9, 0.06, rz=rz + 0.2)
    g["Leather"].obox(*P(0.9, 0.2), z0 + 2.95, 0.9, 0.7, 0.2, rz=rz - 0.1)
    sphere(g, "SignBlue", (*P(1.6, 0.6), z0 + 3.55), 0.45, sub=2)
    g["Brass"].cyl(*P(1.6, 0.6), z0 + 2.85, 0.25, 0.08, 0.3, seg=8)
    C(x, y, z0 + 1.45, 4.3 if abs(s) < 0.5 else 2.3, 2.3 if abs(s) < 0.5 else 4.3, 2.9)


def blackboard(g, x, y, z0, w, h, face, frame="Wood"):
    """벽에 붙은 칠판(얼굴 face: '+x' '-x' '+y' '-y') + 분필 받침 + 분필 글씨 몇 줄"""
    sx = {"+x": 1, "-x": -1}.get(face, 0)
    sy = {"+y": 1, "-y": -1}.get(face, 0)

    def B(mat, u, dn, z, su, sn, sz):
        if sx:
            g[mat].box(x + sx * dn, y + u, z, sn, su, sz)
        else:
            g[mat].box(x + u, y + sy * dn, z, su, sn, sz)
    B(frame, 0, 0.08, z0 + h / 2, w + 0.5, 0.16, h + 0.5)
    B("DarkStone", 0, 0.18, z0 + h / 2, w, 0.06, h)
    B(frame, 0, 0.35, z0 - 0.1, w, 0.4, 0.12)
    for k in range(5):
        B("Marble", -w * 0.38 + (k % 2) * 0.4, 0.22, z0 + h - 0.6 - k * 0.55, w * (0.5 - 0.06 * (k % 3)), 0.02, 0.08)
    B("Marble", w * 0.3, 0.22, z0 + h * 0.45, 0.06, 0.02, h * 0.5)
    B("Marble", w * 0.3, 0.22, z0 + h * 0.45, h * 0.5, 0.02, 0.06)
    B("Marble", -w * 0.2, 0.4, z0 - 0.02, 0.4, 0.12, 0.1)


def books_row(g, x0, x1, y, z, depth, axis="x", seed=0, hmax=1.2):
    """책 한 줄(축 axis 방향으로 꽂힘). 높이·두께·색을 돌려가며"""
    t = x0
    n = seed
    while t < x1 - 0.2:
        w = 0.18 + 0.08 * ((n * 7) % 4)
        h = hmax * (0.7 + 0.1 * ((n * 5) % 4))
        mat = BOOKS[(n * 3 + seed) % len(BOOKS)]
        if axis == "x":
            g[mat].box(t + w / 2, y, z + h / 2, w, depth, h)
        else:
            g[mat].box(y, t + w / 2, z + h / 2, depth, w, h)
        t += w + 0.03
        n += 1


def bookcase(g, x, y0, y1, z0, h, face, levels=5, seed=0):
    """벽(x 쪽)에 붙은 책장, 앞이 face(+1 = +x). 책 가득"""
    d = 1.2
    xb = x + face * d / 2
    g["Wood"].box(x + face * 0.05, (y0 + y1) / 2, z0 + h / 2, 0.1, y1 - y0, h)
    for yy in (y0, y1):
        g["Wood"].box(xb, yy, z0 + h / 2, d, 0.2, h)
    g["Wood"].box(xb, (y0 + y1) / 2, z0 + h + 0.15, d + 0.2, y1 - y0 + 0.4, 0.3)
    for k in range(levels):
        z = z0 + 0.3 + k * (h - 0.6) / (levels - 1)
        g["Wood"].box(xb, (y0 + y1) / 2, z, d, y1 - y0, 0.12)
        if k < levels - 1:
            books_row(g, y0 + 0.15, y1 - 0.15, xb, z + 0.06, d * 0.8, axis="y", seed=seed + k * 5, hmax=min(1.3, (h - 0.6) / (levels - 1) - 0.15))
    C(xb, (y0 + y1) / 2, z0 + h / 2, d, y1 - y0, h)


def stack(g, x0, x1, y, z0, h, levels=5, seed=0):
    """두 면 책장(도서실 줄 책장, x 방향으로 뻗음)"""
    d = 1.6
    g["Wood"].box((x0 + x1) / 2, y, z0 + h / 2, x1 - x0, 0.12, h)
    for xx in (x0, x1):
        g["Wood"].box(xx, y, z0 + h / 2, 0.2, d, h)
    g["Wood"].box((x0 + x1) / 2, y, z0 + h + 0.15, x1 - x0 + 0.3, d + 0.2, 0.3)
    for k in range(levels):
        z = z0 + 0.3 + k * (h - 0.6) / (levels - 1)
        g["Wood"].box((x0 + x1) / 2, y, z, x1 - x0, d, 0.12)
        if k < levels - 1:
            for side in (-1, 1):
                books_row(g, x0 + 0.15, x1 - 0.15, y + side * d / 4, z + 0.06, d * 0.4, axis="x", seed=seed + k * 3 + (side > 0) * 11,
                          hmax=min(1.3, (h - 0.6) / (levels - 1) - 0.15))
    C((x0 + x1) / 2, y, z0 + h / 2, x1 - x0, d, h)


def green_lamp(g, x, y, z):
    """책상 등(놋쇠 대 + 초록 갓 + 불빛)"""
    g["Brass"].cyl(x, y, z, 0.3, 0.3, 0.08, seg=10)
    g["Brass"].cyl(x, y, z, 0.06, 0.06, 0.9, seg=6)
    g["Felt"].box(x, y, z + 0.95, 0.9, 0.4, 0.25)
    g["Glow"].box(x, y, z + 0.8, 0.6, 0.25, 0.06)


def lab_bench(g, x, y, z0, length, axis="y"):
    """실험대(나무 장 + 검은 돌 상판 + 버너·플라스크·시험관 받침)"""
    L_ = length
    sx, sy = (2.4, L_) if axis == "y" else (L_, 2.4)
    g["Wood"].box(x, y, z0 + 1.4, sx - 0.2, sy - 0.2, 2.8)
    g["DarkStone"].box(x, y, z0 + 2.9, sx, sy, 0.2)
    C(x, y, z0 + 1.5, sx, sy, 3.0)
    n = int(L_ // 2.2)
    for k in range(n):
        t = -L_ / 2 + 1.1 + k * L_ / n
        px, py = (x, y + t) if axis == "y" else (x + t, y)
        if k % 3 == 0:
            g["Brass"].cyl(px, py, z0 + 3.0, 0.2, 0.15, 0.6, seg=8)
            g["GlowTeal"].cyl(px, py, z0 + 3.6, 0.08, 0.02, 0.25, seg=6)
            g["Iron"].cyl(px + 0.5, py, z0 + 3.0, 0.05, 0.05, 1.6, seg=5)
            g["Iron"].box(px + 0.2, py, z0 + 4.3, 0.7, 0.06, 0.06)
            sphere(g, "Glass", (px, py, z0 + 4.15), 0.35, sub=1)
        elif k % 3 == 1:
            for j, liq in enumerate(("SignPurple", "Core", "SignTeal", "GlowTeal")):
                g["Glass"].cyl(px - 0.45 + j * 0.3, py, z0 + 3.0, 0.1, 0.1, 0.7, seg=6)
                g[liq].cyl(px - 0.45 + j * 0.3, py, z0 + 3.02, 0.08, 0.08, 0.35, seg=6)
            g["Wood"].box(px, py, z0 + 3.05, 1.4, 0.3, 0.1)
        else:
            g["Glass"].cyl(px, py, z0 + 3.0, 0.4, 0.12, 0.9, seg=10)
            g["SignTeal"].cyl(px, py, z0 + 3.02, 0.36, 0.25, 0.35, seg=10)


def tesla_coil(g, x, y, z0):
    g["Wood"].box(x, y, z0 + 0.6, 2.0, 2.0, 1.2)
    g["Copper"].cyl(x, y, z0 + 1.2, 0.45, 0.45, 3.4, seg=14)
    for k in range(12):
        g["Brass"].cyl(x, y, z0 + 1.35 + k * 0.27, 0.5, 0.5, 0.06, seg=14)
    S.ring(g, "Brass", x, y, z0 + 4.7, 0.3, 1.0, 0.4, n=20)
    sphere(g, "GlowTeal", (x, y, z0 + 5.3), 0.35, sub=1)
    for k in range(5):
        a = k * 1.3
        g["GlowTeal"].obox(x + 0.9 * math.cos(a), y + 0.9 * math.sin(a), z0 + 5.5, 0.06, 0.06, 1.2, rx=0.7 * math.sin(a), ry=-0.7 * math.cos(a))
    C(x, y, z0 + 2.6, 2.0, 2.0, 5.2)


# ------------------------------------------------------------------ 학교
def school_in(g):
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T      # ±25, ±17
    # ── 받침 + 바닥
    g["Stone"].box(0, 0, ZB / 2, W + 2.0, D + 2.0, ZB)
    C(0, 0, ZB / 2, W + 2.0, D + 2.0, ZB)
    g["Timber"].box(0, 0, ZB + 0.1, W - 2 * T, D - 2 * T, 0.2)
    C(0, 0, ZB + 0.1, W - 2 * T, D - 2 * T, 0.2)
    # ── 바깥벽(뒤·왼·오른 + 앞은 현관 자리 x ±7 비움)
    box2(g, "Brick", -W / 2, W / 2, iy1, D / 2, ZB, ZW)
    box2(g, "Brick", -W / 2, ix0, iy0, iy1, ZB, ZW)
    # 오른 벽: 체육관 문(y 8..11, 높이 8)
    box2(g, "Brick", ix1, W / 2, iy0, 8.0, ZB, ZW)
    box2(g, "Brick", ix1, W / 2, 11.0, iy1, ZB, ZW)
    box2(g, "Brick", ix1, W / 2, 8.0, 11.0, ZF + 8.0, ZW)
    for x0, x1 in ((-W / 2, -HX - 1.0), (HX + 1.0, W / 2)):
        box2(g, "Brick", x0, x1, -D / 2, iy0, ZB, ZW)
    # 띠돌(층 사이 · 처마) + 모서리 돌
    for z, h in ((ZS - 0.2, 0.8), (ZW - 0.6, 0.8)):
        for x0, x1, y0, y1 in ((-W / 2 - 0.4, W / 2 + 0.4, -D / 2 - 0.4, -D / 2 + 0.4), (-W / 2 - 0.4, W / 2 + 0.4, D / 2 - 0.4, D / 2 + 0.4),
                               (-W / 2 - 0.4, -W / 2 + 0.4, -D / 2 + 0.4, D / 2 - 0.4), (W / 2 - 0.4, W / 2 + 0.4, -D / 2 + 0.4, D / 2 - 0.4)):
            if y1 < -D / 2 + 1 and x0 < 0 < x1:
                for a, b in ((x0, -HX - 1.0), (HX + 1.0, x1)):
                    g["StoneTrim"].box((a + b) / 2, (y0 + y1) / 2, z + h / 2, b - a, y1 - y0, h)
                continue
            g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, z + h / 2, x1 - x0, y1 - y0, h)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(6):
                zz = ZB + 0.9 + k * 3.8
                g["StoneTrim"].box(sx * (W / 2 + 0.05), sy * (D / 2 + 0.05), zz, 1.6 if k % 2 else 1.1, 1.1 if k % 2 else 1.6, 1.8)
    # ── 창(아래·위, 앞·뒤·옆). 안팎 짝 → 하나의 구멍과 유리
    XS = (-22.0, -16.0, -11.0, 11.0, 16.0, 22.0)
    for x in XS:
        for z0, h in ((ZF + 2.2, 6.6), (Z1 + 2.2, 6.2)):
            for yf, yi, fo, fi in ((-D / 2, iy0, "-y", "+y"), (D / 2, iy1, "+y", "-y")):
                S.window(g, x, yf, z0, 3.0, h, face=fo, cross=True, frame="Paint")
                S.window(g, x, yi, z0, 3.0, h, face=fi, cross=True, sill=False, frame="Paint")
            if z0 > Z1:
                arch_top(g, x, -D / 2, z0 + h, 1.5, T)     # 앞면 위층 창은 반원 머리
    for y in (-12.0, -6.0, 0.0, 6.0, 12.0):
        for z0, h in ((ZF + 2.2, 6.6), (Z1 + 2.2, 6.2)):
            S.window(g, -W / 2, y, z0, 3.0, h, face="-x", cross=True, frame="Paint")
            S.window(g, ix0, y, z0, 3.0, h, face="+x", cross=True, sill=False, frame="Paint")
            if y < -3.0:    # 오른 벽은 체육관 동(y -2..18)에 가리지 않는 앞쪽 둘만
                S.window(g, W / 2, y, z0, 3.0, h, face="+x", cross=True, frame="Paint")
                S.window(g, ix1, y, z0, 3.0, h, face="-x", cross=True, sill=False, frame="Paint")
    # 홀 뒤 위 창 둘(회랑을 밝힌다)
    for x in (-3.5, 3.5):
        S.window(g, x, D / 2, Z1 + 2.2, 2.6, 7.0, face="+y", cross=True, frame="Paint")
        S.window(g, x, iy1, Z1 + 2.2, 2.6, 7.0, face="-y", cross=True, sill=False, frame="Paint")
    # ── 현관(앞으로 3 돌출, x ±8) + 문 + 반원 채광창 + 박공 + 종탑
    PY0, PY1 = -D / 2 - 3.0, -D / 2
    wall_door(g, "Brick", -8.0, 8.0, PY0, PY0 + T, ZB, ZW + 2.0, -2.6, 2.6, ZF + 9.0)
    for s in (-1, 1):
        box2(g, "Brick", *sorted((s * 8.0, s * (8.0 - T))), PY0 + T, PY1 + T, ZB, ZW + 2.0)
    g["Stone"].box(0, PY0 + 0.0, ZB / 2, 17.0, 2.0, ZB)
    C(0, (PY0 + PY1) / 2 - 0.5, (ZB + 0.2) / 2, 16.0, 4.0, ZB + 0.2)     # 현관 바닥(받침 밖으로 나온 자리)
    for k, (yy, zz) in enumerate(((PY0 - 1.5, (ZB + 0.2) * 2 / 3), (PY0 - 3.0, (ZB + 0.2) / 3))):
        g["Stone"].box(0, yy, zz / 2, 9.0 + k * 1.2, 1.6, zz)
        C(0, yy, zz / 2, 9.0 + k * 1.2, 1.6, zz)
    g["Timber"].box(0, (PY0 + PY1) / 2, ZB + 0.1, 14.0, 3.0, 0.2)
    for s in (-1, 1):
        g["StoneTrim"].box(s * 3.2, PY0 - 0.4, ZF + 4.6, 1.2, 0.8, 9.2)
        door_leaf_in(g, s * 2.5, PY0 + T + 0.2, ZF, 2.5, 8.6, 100.0, -s)
    g["StoneTrim"].box(0, PY0 - 0.45, ZF + 9.5, 7.6, 0.9, 1.0)
    g["Brass"].box(0, PY0 - 0.35, ZF + 10.8, 7.0, 0.3, 1.4)
    g["SignBlue"].box(0, PY0 - 0.52, ZF + 10.8, 6.4, 0.06, 1.0)
    S.gear(g, "Brass", 0, PY0 - 0.6, ZF + 10.8, 0.6, 10, 0.15)
    # 현관 위 큰 창(반원 머리) — 홀 위쪽을 밝힌다
    S.window(g, 0, PY0, Z1 + 1.0, 5.0, 6.8, face="-y", cross=True, frame="Paint")
    S.window(g, 0, PY0 + T, Z1 + 1.0, 5.0, 6.8, face="+y", cross=True, sill=False, frame="Paint")
    arch_top(g, 0, PY0, Z1 + 7.8, 2.5, T)
    # 현관 박공(세모 돌판)
    v = [(-8.6, PY0 - 0.6, ZW + 2.0), (8.6, PY0 - 0.6, ZW + 2.0), (0, PY0 - 0.6, ZW + 6.0),
         (-8.6, PY1, ZW + 2.0), (8.6, PY1, ZW + 2.0), (0, PY1, ZW + 6.0)]
    g["StoneTrim"].add_mesh(v, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)])
    g["StoneTrim"].box(0, (PY0 + PY1) / 2 - 0.3, ZW + 1.7, 17.6, 3.8, 0.6)
    # 종탑(현관 뒤 지붕 위): 벽돌 몸 + 사방 열린 종 칸(종) + 시계 + 처마 + 뾰족 지붕 + 바람개비
    tx0, tx1, ty0, ty1 = -4.5, 4.5, PY1, PY1 + 9.0
    zt0 = ZW - 1.0
    box2(g, "Brick", tx0, tx1, ty0, ty1, zt0, ZW + 9.0, coll=False)
    g["StoneTrim"].box(0, (ty0 + ty1) / 2, ZW + 9.3, 10.0, ty1 - ty0 + 1.0, 0.6)
    zb0, zb1 = ZW + 9.6, ZW + 15.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Brick"].box(sx * (4.5 - 0.7), (ty0 + ty1) / 2 + sy * ((ty1 - ty0) / 2 - 0.7), (zb0 + zb1) / 2, 1.4, 1.4, zb1 - zb0)
    for side in (-1, 1):
        L_ = ty1 - ty0
        g["StoneTrim"].box(0, (ty0 + ty1) / 2 + side * (L_ / 2 - 0.3), zb1 - 0.6, 9.0, 0.6, 1.2)
        g["StoneTrim"].box(side * 4.2, (ty0 + ty1) / 2, zb1 - 0.6, 0.6, L_, 1.2)
    g["StoneTrim"].box(0, (ty0 + ty1) / 2, zb1 + 0.3, 10.0, ty1 - ty0 + 1.0, 0.6)
    S.pyramid(g, "RoofMetal", 0, (ty0 + ty1) / 2, zb1 + 0.6, 10.0, ty1 - ty0 + 1.0, 7.0)
    S.pyramid(g, "SnowCap", 0, (ty0 + ty1) / 2, zb1 + 0.6, 10.0, ty1 - ty0 + 1.0, 7.0, frac=0.5, lift=0.2)
    g["Iron"].cyl(0, (ty0 + ty1) / 2, zb1 + 7.4, 0.12, 0.12, 3.0, seg=6)
    g["Brass"].obox(0.8, (ty0 + ty1) / 2, zb1 + 9.6, 1.6, 0.08, 0.5)
    S.gear(g, "Brass", 0, (ty0 + ty1) / 2, zb1 + 8.6, 0.5, 8, 0.1)
    # 종(놋쇠, 종 칸 가운데 들보에 매달림)
    bc = (0, (ty0 + ty1) / 2)
    g["Timber"].box(bc[0], bc[1], zb1 - 1.4, 7.0, 0.6, 0.6)
    g["Brass"].cyl(bc[0], bc[1], zb0 + 1.6, 1.7, 0.9, 2.2, seg=20)
    g["Brass"].cyl(bc[0], bc[1], zb0 + 1.3, 1.9, 1.7, 0.3, seg=20)
    sphere(g, "Brass", (bc[0], bc[1], zb0 + 3.8), 0.7, sub=1)
    g["Iron"].cyl(bc[0], bc[1], zb0 + 0.9, 0.15, 0.15, 1.4, seg=6)
    sphere(g, "Iron", (bc[0], bc[1], zb0 + 0.85), 0.3, sub=1)
    # 시계(현관 박공 세모 한가운데)
    cz, cy_ = ZW + 3.3, PY0 - 0.7
    g["Brass"].hcyl(0, cy_, cz, 1.45, 0.25, axis="y", seg=24)
    g["Dial"].hcyl(0, cy_ - 0.14, cz, 1.25, 0.06, axis="y", seg=24)
    for k in range(12):
        a = 2 * math.pi * k / 12
        g["Iron"].box(1.05 * math.cos(a), cy_ - 0.19, cz + 1.05 * math.sin(a), 0.12, 0.03, 0.12)
    g["Iron"].obox(0.2, cy_ - 0.22, cz + 0.35, 0.1, 0.03, 0.8, ry=-0.5)
    g["Iron"].obox(-0.3, cy_ - 0.23, cz - 0.15, 0.1, 0.03, 1.1, ry=-2.2)
    # ── 지붕(용마루 x 방향) + 굴뚝 둘 + 지붕창 넷
    S.roof_gable(g, 0, 0, ZW, D + 1.2, W + 1.2, 9.0, along="x", gable="Brick")
    for x in (-18.0, 18.0):
        g["Brick"].box(x, 9.0, ZW + 6.0, 2.6, 2.6, 12.0)
        g["StoneTrim"].box(x, 9.0, ZW + 12.2, 3.2, 3.2, 0.5)
        g["Iron"].box(x, 9.0, ZW + 12.7, 2.0, 2.0, 0.5)
        S.vent(g, x, 9.0, ZW + 13.2)
    # ── 가운데 홀: 벽(x ±7, 아래 문 y -13..-9 · 위 문 y 13..16.6) · 대리석 바닥 · 계단 · 회랑 · 난간
    for s in (-1, 1):
        x0, x1 = sorted((s * (HX - 0.3), s * (HX + 0.3)))
        box2(g, "Brick", x0, x1, iy0, -13.0, ZF, Z2)
        box2(g, "Brick", x0, x1, -9.0, 13.0, ZF, Z2)
        box2(g, "Brick", x0, x1, 16.6, iy1, ZF, Z2)
        box2(g, "Brick", x0, x1, -13.0, -9.0, ZF + 8.0, Z2)
        box2(g, "Brick", x0, x1, 13.0, 16.6, ZF, Z1, coll=False)
        C((x0 + x1) / 2, 14.8, (ZF + Z1) / 2, x1 - x0, 3.6, Z1 - ZF)
        box2(g, "Brick", x0, x1, 13.0, 16.6, Z1 + 8.0, Z2)
        for yy, zz in ((-11.0, ZF), (14.8, Z1)):
            g["StoneTrim"].box(s * HX, yy, zz + 8.3, 0.9, 4.8, 0.6)
            for t_ in (-1, 1):
                g["StoneTrim"].box(s * HX, yy + t_ * 2.15, zz + 4.0, 0.8, 0.5, 8.0)
    for i in range(7):
        for j in range(17):
            if (i + j) % 2 == 0:
                g["Marble"].box(-6.0 + i * 2.0, iy0 + 1.0 + j * 2.0, ZF + 0.03, 2.0, 2.0, 0.06)
            else:
                g["DarkStone"].box(-6.0 + i * 2.0, iy0 + 1.0 + j * 2.0, ZF + 0.03, 2.0, 2.0, 0.06)
    g["Marble"].box(0, (PY0 + PY1) / 2 + 0.5, ZF + 0.03, 13.0, 2.0, 0.06)
    # 계단(y -1 → 12, 18 단) — 단마다 상자(밟는다) + 옆판 + 난간
    n, y_a, y_b = 18, -1.0, 12.0
    run = (y_b - y_a) / n
    rise = (Z1 - ZF) / n
    for i in range(n):
        y0 = y_a + i * run
        top = ZF + (i + 1) * rise
        box2(g, "Wood", -3.0, 3.0, y0, y0 + run, ZF, top)
        g["Banner"].box(0, y0 + run / 2, top + 0.02, 4.0, run, 0.04)
    for s in (-1, 1):
        ln = math.hypot(y_b - y_a, Z1 - ZF)
        ang = math.atan2(Z1 - ZF, y_b - y_a)
        g["Timber"].obox(s * 3.15, (y_a + y_b) / 2, (ZF + Z1) / 2 + 0.2, 0.3, ln, 1.4, rx=ang)
        for k in range(10):
            yy = y_a + 0.6 + k * (y_b - y_a - 1.2) / 9
            zz = ZF + (yy - y_a) / (y_b - y_a) * (Z1 - ZF)
            g["Iron"].cyl(s * 3.15, yy, zz, 0.07, 0.07, 3.0, seg=5)
        g["Brass"].obox(s * 3.15, (y_a + y_b) / 2, (ZF + Z1) / 2 + 3.1, 0.2, ln, 0.2, rx=ang)
        g["Brass"].cyl(s * 3.15, y_a, ZF, 0.25, 0.25, 3.6, seg=10)
        sphere(g, "Brass", (s * 3.15, y_a, ZF + 3.75), 0.3, sub=1)
        C(s * 3.15, (y_a + y_b) / 2, (ZF + Z1) / 2 + 1.5, 0.3, y_b - y_a, Z1 - ZF + 3.0)
    # 회랑(뒤, y 12..17) + 앞 난간(계단 자리 비움) + 아래 사물함 줄
    box2(g, "Wood", -HX + 0.3, HX - 0.3, y_b, iy1, ZS, Z1)
    g["StoneTrim"].box(0, y_b + 0.1, ZS - 0.15, 2 * HX - 0.6, 0.4, 0.3)
    for x0, x1 in ((-HX + 0.3, -3.0), (3.0, HX - 0.3)):
        for k in range(int((x1 - x0) // 0.8) + 1):
            g["Iron"].cyl(x0 + 0.2 + k * 0.8, y_b + 0.2, Z1, 0.07, 0.07, 3.0, seg=5)
        g["Brass"].box((x0 + x1) / 2, y_b + 0.2, Z1 + 3.05, x1 - x0, 0.25, 0.2)
        C((x0 + x1) / 2, y_b + 0.2, Z1 + 1.6, x1 - x0, 0.3, 3.2)
    for k in range(10):
        x = -HX + 1.0 + k * 1.3
        if abs(x) < 3.4:
            continue
        g["Brass"].box(x, iy1 - 0.6, ZF + 3.2, 1.2, 1.1, 6.4)
        g["Iron"].box(x, iy1 - 1.16, ZF + 3.2, 1.0, 0.04, 6.0)
        for zz in (5.0, 5.4):
            g["Iron"].box(x - 0.3, iy1 - 1.2, ZF + zz, 0.3, 0.04, 0.08)
    for s in (-1, 1):
        C(s * 5.0, iy1 - 0.6, ZF + 3.2, 3.4, 1.2, 6.4)
    # 홀 꾸밈: 알림판 둘 · 설립자 흉상 · 진열장 · 긴 걸상 · 큰 시계(회랑 위) · 깃발 · 샹들리에
    for s in (-1, 1):
        xw = s * (HX - 0.32)
        g["Wood"].box(xw, -4.0, ZF + 5.5, 0.12, 4.4, 3.2)
        g["Canvas"].box(xw - s * 0.08, -4.0, ZF + 5.5, 0.04, 4.0, 2.8)
        for k in range(6):
            g[BOOKS[k]].box(xw - s * 0.11, -5.4 + (k % 3) * 1.3, ZF + 6.3 - (k // 3) * 1.3, 0.03, 0.9, 0.8)
        g["Wood"].box(xw - s * 0.6, 4.0, ZF + 1.0, 1.0, 5.0, 0.3)
        for yy in (2.0, 6.0):
            g["Iron"].box(xw - s * 0.6, yy, ZF + 0.45, 0.8, 0.2, 0.9)
        C(xw - s * 0.6, 4.0, ZF + 0.6, 1.0, 5.0, 1.2)
        g["Banner"].box(xw - s * 0.1, 0.0, Z1 + 5.0, 0.1, 3.0, 7.0)
        g["Brass"].box(xw - s * 0.3, 0.0, Z1 + 8.6, 0.2, 3.6, 0.2)
        S.gear(g, "Brass", xw - s * 0.18, 0.0, Z1 + 4.0, 0.8, 10, 0.1, axis="x")
    g["Marble"].box(-4.5, -15.0, ZF + 1.6, 1.4, 1.4, 3.2)
    sphere(g, "Iron", (-4.5, -15.0, ZF + 4.1), 0.6, sub=2)
    g["Iron"].box(-4.5, -15.0, ZF + 3.5, 1.2, 0.8, 0.6)
    C(-4.5, -15.0, ZF + 2.2, 1.5, 1.5, 4.4)
    g["Wood"].box(4.5, -15.6, ZF + 2.4, 2.6, 1.2, 4.8)
    g["Glass"].box(4.5, -15.6, ZF + 5.4, 2.4, 1.0, 1.2)
    for k in range(3):
        g["SignGold"].cyl(3.8 + k * 0.7, -15.6, ZF + 4.85, 0.2, 0.1, 0.5 + 0.15 * k, seg=8)
    C(4.5, -15.6, ZF + 3.0, 2.6, 1.2, 6.0)
    g["Brass"].hcyl(0, iy1 - 0.15, Z1 + 8.0, 1.6, 0.25, axis="y", seg=24)
    g["Dial"].hcyl(0, iy1 - 0.3, Z1 + 8.0, 1.4, 0.06, axis="y", seg=24)
    g["Iron"].obox(0.2, iy1 - 0.36, Z1 + 8.4, 0.1, 0.03, 0.9, ry=-0.4)
    g["Iron"].obox(-0.35, iy1 - 0.36, Z1 + 7.8, 0.1, 0.03, 1.2, ry=-2.0)
    for y, zl in ((-8.0, 18.0), (5.0, 19.0)):
        g["Iron"].cyl(0, y, zl + 1.4, 0.07, 0.07, Z2 - zl - 1.4, seg=6)
        S.ring(g, "Brass", 0, y, zl + 1.0, 1.6, 1.9, 0.25, n=20)
        for k in range(6):
            a = 2 * math.pi * k / 6
            g["Glow"].box(1.75 * math.cos(a), y + 1.75 * math.sin(a), zl + 1.45, 0.2, 0.2, 0.4)
        g["LampPt"].box(0, y, zl, 0.3, 0.3, 0.3)
    g["LampPt"].box(0, -16.0, ZF + 8.0, 0.3, 0.3, 0.3)
    # ── 위층 판(방 둘 + 회랑) — 아래층 천장
    for x0, x1 in ((ix0, -HX - 0.3), (HX + 0.3, ix1)):
        box2(g, "Wood", x0, x1, iy0, iy1, ZS, Z1)
        for xx in [x0 + 3.0 + k * 4.0 for k in range(5)]:
            if xx < x1 - 1.0:
                g["Timber"].box(xx, 0, ZS - 0.3, 0.6, iy1 - iy0, 0.6)
    for x0, x1 in ((ix0, -HX - 0.3), (HX + 0.3, ix1), (-HX + 0.3, HX - 0.3)):
        g["Wood"].box((x0 + x1) / 2, 0, Z2 + 0.3, x1 - x0, iy1 - iy0, 0.6)
    classroom(g, ix0, iy0, iy1)
    workshop_room(g, ix1, iy0, iy1)
    library(g, ix0, iy0, iy1)
    science_lab(g, ix1, iy0, iy1)
    gym(g)


def classroom(g, ix0, iy0, iy1):
    """아래 왼쪽 교실: 학생은 홀 쪽 벽(+x)을 본다. 칠판·교단·선생 책상·난로·뒤 사물칸·옷걸이·지도·지구본"""
    xw = -HX - 0.3
    box2(g, "Wood", -11.0, xw, -6.0, 10.0, ZF, ZF + 0.6)
    g["Banner"].box(-9.6, 2.0, ZF + 0.62, 2.0, 12.0, 0.04)
    blackboard(g, xw, 2.0, ZF + 3.4, 11.0, 4.2, "-x")
    teacher_desk(g, -9.2, -2.5, ZF + 0.6, rz=math.pi / 2)
    chair(g, -8.4, -2.5, ZF + 0.6, rz=-math.pi / 2)
    for x in (-14.4, -18.0, -21.6):
        for y in (-10.5, -5.5, 4.5, 9.5):
            school_desk(g, x, y, ZF, face=1.0)
    # 무쇠 난로(뒤 오른 구석) + 연통
    g["Iron"].cyl(-21.0, 15.4, ZF, 0.9, 1.0, 3.2, seg=14)
    sphere(g, "Iron", (-21.0, 15.4, ZF + 3.3), 0.9, sub=1)
    g["Core"].box(-20.2, 15.4, ZF + 1.2, 0.3, 0.6, 0.5)
    g["Iron"].cyl(-21.0, 15.4, ZF + 4.0, 0.3, 0.3, ZS - ZF - 4.0, seg=8)
    C(-21.0, 15.4, ZF + 1.8, 2.0, 2.0, 3.6)
    g["LampPt"].box(-19.8, 15.4, ZF + 1.4, 0.3, 0.3, 0.3)
    # 뒤 사물칸(왼 벽 아래, 창 밑) + 옷걸이 줄
    g["Wood"].box(ix0 + 0.6, 0.0, ZF + 1.0, 1.2, 30.0, 2.0)
    for k in range(15):
        g["Timber"].box(ix0 + 1.22, -14.0 + k * 2.0, ZF + 1.0, 0.04, 1.8, 1.6)
        g[BOOKS[k % len(BOOKS)]].box(ix0 + 0.9, -14.0 + k * 2.0, ZF + 0.6, 0.5, 1.2, 0.6)
    C(ix0 + 0.6, 0.0, ZF + 1.0, 1.2, 30.0, 2.0)
    # 옷걸이 줄(홀 쪽 벽, 교단 뒤 끝 — 창 없는 벽)
    g["Wood"].box(xw - 0.15, 14.0, ZF + 6.4, 0.3, 5.0, 0.4)
    for k in range(5):
        g["Brass"].obox(xw - 0.4, 12.0 + k * 1.0, ZF + 6.2, 0.5, 0.1, 0.1, ry=0.6)
        if k % 2 == 0:
            g[BOOKS[k]].box(xw - 0.55, 12.0 + k * 1.0, ZF + 5.2, 0.3, 0.8, 1.8)
    # 지도(앞벽 창 사이에 걸린 말린 지도) + 지구본 받침
    g["Canvas"].box(-19.0, iy0 + 0.1, ZF + 5.6, 2.6, 0.04, 3.2)
    g["SignTeal"].box(-19.0, iy0 + 0.12, ZF + 5.6, 2.2, 0.02, 2.4)
    g["Wood"].hcyl(-19.0, iy0 + 0.15, ZF + 7.3, 0.12, 2.9, axis="x", seg=6)
    g["Wood"].cyl(-12.5, 13.5, ZF, 0.5, 0.15, 3.0, seg=8)
    sphere(g, "SignBlue", (-12.5, 13.5, ZF + 3.8), 0.8, sub=2)
    g["Brass"].hcyl(-12.5, 13.5, ZF + 3.8, 0.95, 0.1, axis="x", seg=16)
    C(-12.5, 13.5, ZF + 2.2, 1.6, 1.6, 4.4)
    for x, y in ((-12.0, -8.0), (-12.0, 8.0), (-21.0, -8.0), (-21.0, 8.0)):
        lantern(g, x, y, ZS - 0.4, 10.0)


def workshop_room(g, ix1, iy0, iy1):
    """아래 오른쪽 기계 교실: 학생 작업대(바이스·톱니) → 선생 실연대(작은 증기 기관) · 칠판(오른 벽) · 연장판 · 체육관 문"""
    blackboard(g, ix1, 1.5, ZF + 3.6, 9.0, 4.0, "-x")
    box2(g, "Wood", 20.5, ix1, -4.0, 7.0, ZF, ZF + 0.6)
    g["Wood"].box(21.5, 1.5, ZF + 3.4, 2.4, 6.0, 0.3)
    for sy in (-1, 1):
        g["Wood"].box(21.5, 1.5 + sy * 2.7, ZF + 1.9, 2.2, 0.4, 2.8)
    C(21.5, 1.5, ZF + 1.8, 2.4, 6.0, 3.6)
    # 작은 증기 기관(실연용): 보일러 + 굴뚝 + 바퀴 + 피스톤
    g["Copper"].hcyl(21.5, 0.4, ZF + 4.3, 0.7, 2.2, axis="y", seg=14)
    g["Iron"].cyl(21.5, -0.6, ZF + 4.6, 0.18, 0.18, 1.6, seg=8)
    g["Brass"].hcyl(21.5, 2.6, ZF + 4.6, 0.9, 0.15, axis="x", seg=16)
    g["Iron"].box(21.5, 1.8, ZF + 4.2, 0.4, 1.2, 0.3)
    S.gear(g, "Brass", 21.0, 3.4, ZF + 4.2, 0.5, 10, 0.1, axis="x")
    for x in (11.0, 14.5):
        for y0, y1 in ((-6.0, 0.0), (3.0, 9.0), (11.0, 16.0)):
            yc = (y0 + y1) / 2
            g["Wood"].box(x, yc, ZF + 2.8, 2.2, y1 - y0, 0.3)
            for sy in (-1, 1):
                g["Iron"].box(x, yc + sy * ((y1 - y0) / 2 - 0.3), ZF + 1.3, 1.8, 0.3, 2.6)
            g["Wood"].box(x, yc, ZF + 0.7, 2.0, y1 - y0 - 0.6, 0.15)
            for k in range(2):
                yy = y0 + 1.5 + k * 3.0
                g["Iron"].box(x - 0.6, yy, ZF + 3.3, 0.6, 0.5, 0.7)
                g["Iron"].hcyl(x - 0.6, yy, ZF + 3.55, 0.08, 1.2, axis="x", seg=5)
                S.gear(g, "Brass" if k else "Copper", x + 0.4, yy + 0.4, ZF + 2.98, 0.4, 8, 0.08, axis="z")
                g["Wood"].cyl(x - 1.8, yy, ZF, 0.45, 0.4, 1.7, seg=8)
            C(x, yc, ZF + 1.5, 2.2, y1 - y0, 3.0)
    # 연장판(뒤 벽) + 기계 그림(앞 벽 창 사이 대신 오른쪽 뒤)
    g["Timber"].box(16.0, iy1 - 0.12, ZF + 5.4, 7.0, 0.2, 3.4)
    for k in range(9):
        ln = 0.7 + 0.3 * (k % 3)
        g["Iron" if k % 2 else "Brass"].box(13.0 + k * 0.75, iy1 - 0.3, ZF + 6.4 - ln / 2, 0.14, 0.12, ln)
    g["Canvas"].box(HX + 0.32, 6.0, ZF + 6.0, 0.04, 4.0, 3.0)
    g["SignBlue"].box(HX + 0.34, 6.0, ZF + 6.0, 0.02, 3.6, 2.6)
    for k in range(3):
        S.gear(g, "Iron", HX + 0.4, 5.0 + k * 1.0, ZF + 5.4 + (k % 2) * 0.9, 0.5 - 0.1 * k, 8, 0.02, axis="x")
    for x, y in ((12.0, -8.0), (12.0, 8.0), (20.0, -8.0), (20.0, 8.0)):
        lantern(g, x, y, ZS - 0.4, 10.0)


def library(g, ix0, iy0, iy1):
    """위 왼쪽 도서실: 왼 벽에서 뻗은 줄 책장 넷(창 사이) · 읽는 탁자 둘(초록 등) · 안락의자 · 지구본 · 사서 책상 · 바퀴 사다리"""
    z0 = Z1
    for y, sd in ((-9.0, 1), (-3.0, 2), (3.0, 3), (9.0, 4)):
        stack(g, ix0 + 0.1, -16.0, y, z0, 8.0, levels=5, seed=sd * 7)
    for y0, y1 in ((-16.6, -13.6), (-2.0, 2.0)):
        bookcase(g, -HX - 0.3, y0, y1, z0, 8.0, -1, levels=5, seed=int(y0) + 20)
    for y in (-6.0, 6.0):
        g["Wood"].box(-11.0, y, z0 + 2.7, 3.0, 6.0, 0.25)
        for sx in (-1, 1):
            for sy in (-1, 1):
                g["Wood"].box(-11.0 + sx * 1.2, y + sy * 2.6, z0 + 1.3, 0.3, 0.3, 2.6)
        C(-11.0, y, z0 + 1.4, 3.0, 6.0, 2.8)
        green_lamp(g, -11.0, y - 1.5, z0 + 2.85)
        green_lamp(g, -11.0, y + 1.5, z0 + 2.85)
        for k in range(3):
            g[BOOKS[k + 2]].obox(-11.3 + k * 0.3, y + (k - 1) * 0.9, z0 + 2.95, 0.8, 0.6, 0.18, rz=0.3 * k)
        for sx in (-1, 1):
            for yy in (y - 1.8, y + 1.8):
                chair(g, -11.0 + sx * 2.3, yy, z0, rz=sx * math.pi / 2)
        g["LampPt"].box(-11.0, y, z0 + 4.2, 0.3, 0.3, 0.3)
    # 안락의자 둘 + 깔개(앞 창 쪽)
    g["Banner"].box(-20.0, -14.0, z0 + 0.03, 7.0, 4.0, 0.06)
    for x in (-22.0, -18.0):
        g["Leather"].box(x, -14.0, z0 + 1.0, 2.2, 2.2, 1.2)
        g["Leather"].box(x, -15.0, z0 + 2.4, 2.2, 0.5, 2.0)
        for sx in (-1, 1):
            g["Leather"].box(x + sx * 1.0, -14.0, z0 + 1.9, 0.4, 2.2, 0.8)
        C(x, -14.0, z0 + 1.5, 2.3, 2.3, 3.0)
    g["Wood"].cyl(-20.0, -12.6, z0, 0.6, 0.6, 2.2, seg=12)
    sphere(g, "SignBlue", (-20.0, -12.6, z0 + 3.0), 0.7, sub=2)
    g["Brass"].hcyl(-20.0, -12.6, z0 + 3.0, 0.85, 0.08, axis="x", seg=16)
    # 사서 책상(문 옆) + 서랍장(카드 목록)
    g["Wood"].box(-9.5, 12.0, z0 + 1.6, 3.6, 1.6, 3.2)
    g["Brass"].box(-9.5, 12.0, z0 + 3.25, 3.8, 1.8, 0.1)
    C(-9.5, 12.0, z0 + 1.6, 3.8, 1.8, 3.2)
    g["Wood"].box(-13.0, iy1 - 0.8, z0 + 2.0, 3.0, 1.4, 4.0)
    for r in range(5):
        for c in range(4):
            g["Brass"].box(-14.1 + c * 0.75, iy1 - 1.52, z0 + 0.6 + r * 0.75, 0.25, 0.04, 0.1)
    C(-13.0, iy1 - 0.8, z0 + 2.0, 3.0, 1.4, 4.0)
    # 바퀴 사다리(줄 책장에 기댐)
    for sx in (-0.4, 0.4):
        g["Wood"].obox(-19.0 + sx, -7.6, z0 + 3.8, 0.12, 0.12, 7.8, rx=0.25)
    for k in range(8):
        g["Wood"].box(-19.0, -7.6 - 0.25 * (3.8 - k) / 1.0 * 0.25, z0 + 0.6 + k * 0.95, 0.9, 0.1, 0.1)
    for x, y in ((-12.0, -12.0), (-12.0, 0.0), (-12.0, 12.0), (-20.0, -14.0)):
        lantern(g, x, y, Z2 - 0.2, Z1 + 8.0)


def science_lab(g, ix1, iy0, iy1):
    """위 오른쪽 과학실: 실험대 넷 · 선생 실연대(테슬라 코일) · 표본 선반 · 원소표 · 칠판 · 해골 대신 태양계 모형"""
    z0 = Z1
    for x, y in ((11.5, -9.0), (11.5, 4.0), (17.0, -9.0), (17.0, 4.0)):
        lab_bench(g, x, y, z0, 8.0, axis="y")
        for sy in (-1, 1):
            g["Wood"].cyl(x - 1.9, y + sy * 2.5, z0, 0.45, 0.4, 1.8, seg=8)
    g["Wood"].box(22.5, -2.0, z0 + 1.5, 2.6, 9.0, 3.0)
    g["DarkStone"].box(22.5, -2.0, z0 + 3.1, 2.8, 9.2, 0.2)
    C(22.5, -2.0, z0 + 1.6, 2.8, 9.2, 3.2)
    tesla_coil(g, 22.5, -4.5, z0 + 3.2)
    g["LampPt"].box(22.5, -4.5, z0 + 8.6, 0.3, 0.3, 0.3)
    blackboard(g, ix1, -2.0, z0 + 3.6, 8.0, 3.6, "-x")
    # 원소표(홀 쪽 벽)
    g["Canvas"].box(HX + 0.32, -6.0, z0 + 5.2, 0.04, 6.0, 3.6)
    for r in range(5):
        for c in range(9):
            if r == 0 and 0 < c < 8:
                continue
            g[BOOKS[(r * 3 + c) % 4]].box(HX + 0.35, -8.6 + c * 0.62, z0 + 6.6 - r * 0.62, 0.02, 0.5, 0.5)
    # 표본 선반(뒤 벽, 창 사이) — 유리병에 든 것들
    for x0, x1 in ((12.5, 14.6), (17.6, 20.4)):
        g["Wood"].box((x0 + x1) / 2, iy1 - 0.5, z0 + 3.6, x1 - x0, 1.0, 7.2)
        for zz in (1.5, 3.3, 5.1):
            for k in range(int((x1 - x0) / 0.7)):
                xx = x0 + 0.35 + k * 0.7
                g["Glass"].cyl(xx, iy1 - 0.5, z0 + zz, 0.28, 0.28, 1.0, seg=8)
                g[("SignTeal", "GlowTeal", "Core", "SignPurple")[(k + int(zz)) % 4]].cyl(xx, iy1 - 0.5, z0 + zz + 0.05, 0.22, 0.22, 0.6, seg=8)
        C((x0 + x1) / 2, iy1 - 0.5, z0 + 3.6, x1 - x0, 1.0, 7.2)
    # 태양계 모형(창가) — 놋쇠 받침 + 해 + 팔 셋
    mx, my = 20.5, 11.5
    g["Brass"].cyl(mx, my, z0, 0.8, 0.5, 2.6, seg=12)
    sphere(g, "Glow", (mx, my, z0 + 3.2), 0.55, sub=2)
    for k, (r, mat) in enumerate(((1.4, "SignBlue"), (2.1, "SignRed"), (2.8, "SignGold"))):
        a = k * 2.1
        g["Brass"].obox(mx + r / 2 * math.cos(a), my + r / 2 * math.sin(a), z0 + 3.0, r, 0.08, 0.08, rz=a)
        sphere(g, mat, (mx + r * math.cos(a), my + r * math.sin(a), z0 + 3.0), 0.22 + 0.06 * k, sub=1)
    C(mx, my, z0 + 1.8, 1.8, 1.8, 3.6)
    for x, y in ((12.0, -8.0), (12.0, 6.0), (19.0, -8.0), (19.0, 6.0)):
        lantern(g, x, y, Z2 - 0.2, Z1 + 8.0)


def gym(g):
    """체육관 동(오른쪽 +x = 남, 놀이터 쪽): 24×20, 벽 13, 맞배지붕. 앞(-y) 마당 문 · 오른 벽 늑목 · 밧줄 셋 · 뜀틀 · 안마 · 매트 · 걸상"""
    gx0, gx1, gy0, gy1 = W / 2, W / 2 + 24.0, -2.0, D / 2
    zt = 13.0
    g["Stone"].box((gx0 + gx1) / 2, (gy0 + gy1) / 2, ZB / 2, gx1 - gx0 + 2.0, gy1 - gy0 + 2.0, ZB)
    C((gx0 + gx1) / 2 + 0.5, (gy0 + gy1) / 2, ZB / 2, gx1 - gx0 + 1.0, gy1 - gy0 + 2.0, ZB)
    g["Timber"].box((gx0 + gx1) / 2, (gy0 + gy1) / 2, ZB + 0.1, gx1 - gx0 - 2 * T, gy1 - gy0 - 2 * T, 0.2)
    C((gx0 + gx1) / 2, (gy0 + gy1) / 2, ZB + 0.1, gx1 - gx0 - 2 * T, gy1 - gy0 - 2 * T, 0.2)
    box2(g, "Brick", gx0, gx1, gy1 - T, gy1, ZB, zt)
    box2(g, "Brick", gx1 - T, gx1, gy0 + T, gy1 - T, ZB, zt)
    # 앞벽: 마당 문(x 36..40, 높이 8)
    box2(g, "Brick", gx0, 36.0, gy0, gy0 + T, ZB, zt)
    box2(g, "Brick", 40.0, gx1, gy0, gy0 + T, ZB, zt)
    box2(g, "Brick", 36.0, 40.0, gy0, gy0 + T, ZF + 8.0, zt)
    g["StoneTrim"].box(38.0, gy0 - 0.35, ZF + 8.4, 5.4, 0.7, 0.8)
    for s in (-1, 1):
        g["StoneTrim"].box(38.0 + s * 2.3, gy0 - 0.35, ZF + 4.0, 0.6, 0.7, 8.0)
    door_leaf_in(g, 36.1, gy0 + T + 0.2, ZF, 1.9, 7.8, 100.0, 1)
    door_leaf_in(g, 39.9, gy0 + T + 0.2, ZF, 1.9, 7.8, 100.0, -1)
    g["Stone"].box(38.0, gy0 - 1.2, ZB * 0.75 / 2, 6.0, 2.4, ZB * 0.75)       # 마당 문 디딤 둘(받침 2.0 을 나눠)
    C(38.0, gy0 - 1.2, ZB * 0.75 / 2, 6.0, 2.4, ZB * 0.75)
    g["Stone"].box(38.0, gy0 - 3.0, ZB * 0.35 / 2, 6.6, 1.4, ZB * 0.35)
    C(38.0, gy0 - 3.0, ZB * 0.35 / 2, 6.6, 1.4, ZB * 0.35)
    for x0, x1, y0, y1 in ((gx0, gx1 + 0.4, gy0 - 0.4, gy0 + 0.4), (gx0, gx1 + 0.4, gy1 - 0.4, gy1 + 0.4), (gx1 - 0.4, gx1 + 0.4, gy0 + 0.4, gy1 - 0.4)):
        g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, zt - 0.4, x1 - x0, y1 - y0, 0.8)
    S.roof_gable(g, (gx0 + gx1) / 2 + 0.4, (gy0 + gy1) / 2, zt, gy1 - gy0 + 1.0, gx1 - gx0 + 1.0, 6.0, along="x", gable="Brick")
    g["Wood"].box((gx0 + gx1) / 2, (gy0 + gy1) / 2, zt - 0.3, gx1 - gx0 - 2 * T, gy1 - gy0 - 2 * T, 0.4)
    # 높은 창(앞·뒤, 안팎) — 공이 안 맞게 높이
    for x in (30.0, 33.0, 43.0, 46.0):
        S.window(g, x, gy0, ZF + 6.0, 2.2, 3.6, face="-y", cross=True, frame="Paint")
        S.window(g, x, gy0 + T, ZF + 6.0, 2.2, 3.6, face="+y", cross=True, sill=False, frame="Paint")
    for x in (30.0, 35.0, 41.0, 46.0):
        S.window(g, x, gy1, ZF + 6.0, 2.2, 3.6, face="+y", cross=True, frame="Paint")
        S.window(g, x, gy1 - T, ZF + 6.0, 2.2, 3.6, face="-y", cross=True, sill=False, frame="Paint")
    g["Brass"].box(38.0, gy0 - 0.3, ZF + 9.6, 5.0, 0.25, 1.0)
    g["SignTeal"].box(38.0, gy0 - 0.45, ZF + 9.6, 4.4, 0.06, 0.6)
    # 지붕 들보 셋(밧줄이 매달린다)
    for x in (32.0, 38.0, 44.0):
        g["Timber"].box(x, (gy0 + gy1) / 2, zt - 0.9, 0.6, gy1 - gy0 - 2 * T, 0.8)
    g["Timber"].box((gx0 + gx1) / 2, 10.0, zt - 1.6, gx1 - gx0 - 2 * T, 0.6, 0.6)
    # 늑목(오른 벽)
    xw = gx1 - T
    for k in range(9):
        y = 1.0 + k * 1.8
        g["Wood"].box(xw - 0.4, y, ZF + 4.6, 0.3, 0.3, 9.2)
    for r in range(14):
        g["Wood"].hcyl(xw - 0.4, 1.0 + 7.2, ZF + 0.5 + r * 0.65, 0.07, 14.6, axis="y", seg=6)
    C(xw - 0.4, 8.2, ZF + 4.6, 0.5, 14.8, 9.2)
    # 밧줄 셋 + 매트
    for x in (32.0, 35.0, 38.0):
        g["Canvas"].cyl(x, 10.0, ZF + 1.6, 0.14, 0.14, zt - 1.6 - ZF - 1.6, seg=6)
        g["Canvas"].cyl(x, 10.0, ZF + 1.2, 0.24, 0.2, 0.5, seg=6)
    g["Banner"].box(35.0, 10.0, ZF + 0.15, 9.0, 4.0, 0.3)
    C(35.0, 10.0, ZF + 0.15, 9.0, 4.0, 0.3)
    # 안마(가죽 몸 + 손잡이 둘 + 다리)
    hx, hy = 42.0, 4.0
    g["Leather"].hcyl(hx, hy, ZF + 3.6, 0.7, 4.0, axis="x", seg=12)
    for sx in (-1, 1):
        g["Brass"].obox(hx + sx * 0.6, hy, ZF + 4.45, 0.15, 0.15, 0.6, ry=0.0)
        for sy in (-1, 1):
            g["Iron"].obox(hx + sx * 1.5, hy + sy * 0.6, ZF + 1.6, 0.18, 0.18, 3.3, rx=-sy * 0.25)
    C(hx, hy, ZF + 2.2, 4.0, 1.8, 4.4)
    # 뜀틀(층층 나무 상자 + 가죽 윗면)
    bx, by = 45.0, 13.0
    for k in range(4):
        g["Wood"].box(bx, by, ZF + 0.5 + k * 0.9, 3.6 - k * 0.25, 1.8 - k * 0.1, 0.85)
    g["Leather"].box(bx, by, ZF + 4.1, 2.8, 1.4, 0.3)
    C(bx, by, ZF + 2.1, 3.6, 1.8, 4.2)
    # 걸상(앞벽 따라) + 공 바구니
    for x0, x1 in ((28.5, 34.5), (41.5, 47.5)):
        g["Wood"].box((x0 + x1) / 2, gy0 + T + 0.7, ZF + 1.4, x1 - x0, 1.0, 0.2)
        for xx in (x0 + 0.4, x1 - 0.4):
            g["Iron"].box(xx, gy0 + T + 0.7, ZF + 0.7, 0.2, 0.8, 1.4)
        C((x0 + x1) / 2, gy0 + T + 0.7, ZF + 0.75, x1 - x0, 1.0, 1.5)
    g["Iron"].cyl(29.0, 15.0, ZF, 1.0, 1.2, 1.8, seg=12)
    for k in range(5):
        sphere(g, ("SignRed", "Leather", "SignBlue")[k % 3], (28.6 + (k % 3) * 0.4, 14.7 + (k // 3) * 0.6, ZF + 1.9 + (k % 2) * 0.3), 0.45, sub=1)
    C(29.0, 15.0, ZF + 1.2, 2.4, 2.4, 2.4)
    for x in (32.0, 44.0):
        lantern(g, x, 4.0, zt - 0.6, 9.5)
        lantern(g, x, 14.0, zt - 0.6, 9.5)


JOBS = [
    ("Schule", "SchuleIn", job("Schule", school_in, cut=T)),
]
