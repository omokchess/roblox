# -*- coding: utf-8 -*-
"""
build_steam_service.py — 2026-10-18. 슈네라이히 서비스 구역 건물을 회색 상자(tools/snow_gray.py) 그대로의 동선·크기로 꾸민다.

사용자(2026-10-11): "예쁘게만 → 유저 플레이에 맞춰" → 회색 상자로 동선 승인(6f00ebd) → "굿굿 이제 꾸미자"(2026-10-18).
규칙(마을_플레이_기준.md): R6 폭 4·키 5, 문 6×9(정문 10×10), 복도 8, 천장 12+, 카운터 3.5·앞 빈 바닥 10×10,
실내 세 구역(입구 완충 비움 → 가운데 기능 → 벽 쪽 이야기). 회색 상자의 문·카운터·NPC 자리·빈 바닥은 옮기지 않는다
(걷기 검사 tools/snow_walkcheck.py 의 길이 그대로 통과해야 함).

  Svc_Smithy    대장간 36×30: 앞이 넓게 트인 작업장(14×11, 밀어 연 쇠문), 왼 뒤 화덕(숯불·풀무·후드·굴뚝), 가운데 모루,
                오른 뒤 제작 카운터, 왼 벽 무기 걸이, 오른 뒤 재료 선반·광석 상자, 앞 오른 구석 숫돌, 뒷문 → 마당
  Yard_Smithy   대장간 마당 30×16: 광석 더미 셋, 바깥 모루, 숯 화로, 담금질 통, 장작 헛간, 간판 기둥

좌표: 블렌더 (x, y, z), 앞 = -y(광장). 로블록스 로컬 = (-x, z, y). 바닥 윗면 0.4(회색 상자와 같음 — 문턱 없이 걸어 들어간다).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_steam as S  # noqa: E402
import hanok_lib as L_  # noqa: E402
from build_steam_obs import sphere  # noqa: E402
from build_steam_inside import (C, PROP, NPC, job, box2, lantern, coal_bed, armor_stand, shelf_unit, bottle, fire_logs,  # noqa: E402
                                round_table, bed, wardrobe, washstand, DOORWAY, CLEAR)

T, FZ = 1.0, 0.4


# ------------------------------------------------------------------ 공용
def frustum(g, mat, cx, cy, z0, w0, d0, w1, d1, h):
    """네모 뿔대(아래 w0×d0 → 위 w1×d1)"""
    v = [(cx - w0 / 2, cy - d0 / 2, z0), (cx + w0 / 2, cy - d0 / 2, z0), (cx + w0 / 2, cy + d0 / 2, z0), (cx - w0 / 2, cy + d0 / 2, z0),
         (cx - w1 / 2, cy - d1 / 2, z0 + h), (cx + w1 / 2, cy - d1 / 2, z0 + h), (cx + w1 / 2, cy + d1 / 2, z0 + h), (cx - w1 / 2, cy + d1 / 2, z0 + h)]
    g[mat].add_mesh(v, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])


def prism_xz(g, mat, pts, y0, y1):
    """xz 평면 볼록 다각형을 y0..y1 로 민 덩이"""
    n = len(pts)
    v = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g[mat].add_mesh(v, f)


def quoins(g, W, D, z0, z1, step=1.5):
    """모서리 돌: 긴 돌·짧은 돌을 엇갈려 빈틈없이 쌓는다(2026-10-18 점검: 띄엄띄엄 놓으면 벽에 뜬 상자처럼 보였다)"""
    k = 0
    z = z0
    while z < z1 - 0.2:
        h = min(step, z1 - z)
        for sx in (-1, 1):
            for sy in (-1, 1):
                long_x = k % 2 == 0
                lx, ly = (2.2, 1.2) if long_x else (1.2, 2.2)
                g["StoneTrim"].box(sx * (W / 2 - lx / 2 + 0.25), sy * (D / 2 - ly / 2 + 0.25), z + h / 2 - 0.04, lx, ly, h - 0.08)
        z += step
        k += 1


def side_window(g, x_out, x_in, y, z0, w, h, face):
    """옆벽(겉 x_out · 안 x_in) 안팎 짝 창 = 구멍 하나 + 유리"""
    S.window(g, x_out, y, z0, w, h, face=face, cross=True, frame="Iron")
    S.window(g, x_in, y, z0, w, h, face=("+x" if face == "-x" else "-x"), cross=True, sill=False, frame="Iron")


def back_window(g, x, y_out, y_in, z0, w, h):
    S.window(g, x, y_out, z0, w, h, face="+y", cross=True, frame="Iron")
    S.window(g, x, y_in, z0, w, h, face="-y", cross=True, sill=False, frame="Iron")


def anvil_icon(g, x, y, z, s=1.0, face=-1, mat="Brass"):
    """간판의 모루 그림(두께 0.2, 어두운 판 위에서 보이게 기본 놋쇠) + 엇갈린 망치. face = 판이 보는 쪽(-1 앞 -y)"""
    y0, y1 = (y - 0.2, y) if face < 0 else (y, y + 0.2)
    k = s
    prism_xz(g, mat, [(x - 1.0 * k, z + 0.55 * k), (x + 0.75 * k, z + 0.55 * k), (x + 0.75 * k, z + 0.95 * k), (x - 1.15 * k, z + 0.95 * k)], y0, y1)   # 윗면
    prism_xz(g, mat, [(x + 0.75 * k, z + 0.6 * k), (x + 1.75 * k, z + 0.88 * k), (x + 0.75 * k, z + 0.95 * k)], y0, y1)   # 뿔
    prism_xz(g, mat, [(x - 0.35 * k, z + 0.1 * k), (x + 0.35 * k, z + 0.1 * k), (x + 0.3 * k, z + 0.55 * k), (x - 0.3 * k, z + 0.55 * k)], y0, y1)  # 허리
    prism_xz(g, mat, [(x - 0.9 * k, z - 0.35 * k), (x + 0.9 * k, z - 0.35 * k), (x + 0.6 * k, z + 0.1 * k), (x - 0.6 * k, z + 0.1 * k)], y0, y1)   # 받침
    yy = (y0 + y1) / 2 + face * 0.12
    g["Wood"].obox(x + 0.2 * k, yy, z + 1.75 * k, 0.16 * k, 0.12, 1.9 * k, ry=-0.6)
    g["Steel"].obox(x + 0.75 * k, yy, z + 2.45 * k, 0.9 * k, 0.16, 0.42 * k, ry=-0.6)


def sword_hilt_up(g, x, y, z_tip, blade=3.0, lean=0.0):
    """칼끝을 아래 홈에 꽂고 손잡이가 위로 선 칼(벽 걸이). lean = x 축으로 살짝 기운 각"""
    zc = z_tip + blade / 2
    g["Steel"].obox(x, y, zc, 0.07, 0.3, blade, rx=lean)
    gz = z_tip + blade + 0.1
    g["Brass"].obox(x, y, gz, 0.16, 1.1, 0.16, rx=lean)
    g["Leather"].obox(x, y, gz + 0.5, 0.16, 0.16, 0.8, rx=lean)
    g["Brass"].box(x, y, gz + 0.98, 0.22, 0.22, 0.2)


def axe_up(g, x, y, z0):
    g["Timber"].box(x, y, z0 + 1.8, 0.16, 0.16, 3.6)
    g["Steel"].box(x, y - 0.45, z0 + 3.2, 0.1, 0.8, 0.9)
    g["Iron"].box(x, y + 0.1, z0 + 3.2, 0.2, 0.35, 0.5)


def spear_up(g, x, y, z0, h=6.6):
    g["Timber"].box(x, y, z0 + h / 2, 0.14, 0.14, h)
    frustum(g, "Steel", x, y, z0 + h, 0.1, 0.3, 0.02, 0.02, 0.9)
    g["Brass"].box(x, y, z0 + h - 0.05, 0.22, 0.22, 0.2)


def crate(g, x, y, z0, s=2.2, h=None, rz=0.0):
    h = h or s
    g["Wood"].obox(x, y, z0 + h / 2, s, s, h, rz=rz)
    c, sn = math.cos(rz), math.sin(rz)
    for su in (-1, 1):
        for sv in (-1, 1):
            u, v = su * (s / 2 - 0.08), sv * (s / 2 - 0.08)
            g["Timber"].obox(x + c * u - sn * v, y + sn * u + c * v, z0 + h / 2, 0.22, 0.22, h + 0.02, rz=rz)
    g["Timber"].obox(x, y, z0 + h - 0.08, s + 0.04, s + 0.04, 0.16, rz=rz)


def ore_lumps(g, x, y, z0, r=1.8, n=10, seed=1, mats=("Stone", "IronLight", "Stone", "Copper"), mound=False):
    """광석 더미: 아래 넓게 위로 좁게 쌓인 덩이. mound = 가운데 돌 무덤(큰 더미가 속 빈 자갈로 안 보이게)"""
    import random
    rnd = random.Random(seed)
    if mound:
        frustum(g, "Stone", x, y, z0, 2 * r, 1.8 * r, 0.7 * r, 0.6 * r, 0.85 * r)
    big = 1.6 if mound else 1.0
    for k in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        ring = (1.0 - k / n)
        d = rnd.uniform(0.15, 1.0) * r * ring
        s = rnd.uniform(0.55, 0.95) * big
        zz = z0 + s * 0.75 + (k / n) * r * 0.9       # 돌린 덩이 밑이 바닥 밑으로 안 나가게(배치가 가장 낮은 면을 땅에 맞춘다)
        g[mats[k % len(mats)]].obox(x + d * math.cos(a), y + d * math.sin(a), zz, s * 1.2, s, s * 0.8,
                                     rx=rnd.uniform(-0.4, 0.4), ry=rnd.uniform(-0.4, 0.4), rz=a)



# ------------------------------------------------------------------ 눈·세밀 소품(2026-10-18 사용자: 작동할 것 같은 건 세밀하게, 겉은 눈 쌓임·대칭으로 예쁘게)
def solid(g, mat, verts, faces):
    """볼록 덩이: 면마다 바깥을 보게 감는 방향을 맞춘다(뉴얼 법선 · 무게중심 기준)"""
    n = len(verts)
    cx, cy, cz = (sum(v[i] for v in verts) / n for i in range(3))
    out = []
    for f in faces:
        pts = [verts[i] for i in f]
        nx = ny = nz = 0.0
        for i in range(len(pts)):
            x1, y1, z1 = pts[i]
            x2, y2, z2 = pts[(i + 1) % len(pts)]
            nx += (y1 - y2) * (z1 + z2)
            ny += (z1 - z2) * (x1 + x2)
            nz += (x1 - x2) * (y1 + y2)
        fx, fy_, fz = (sum(p_[i] for p_ in pts) / len(pts) for i in range(3))
        out.append(tuple(f) if nx * (fx - cx) + ny * (fy_ - cy) + nz * (fz - cz) >= 0 else tuple(reversed(f)))
    g[mat].add_mesh(verts, out)


def drift(g, x0, x1, yw, face, d=1.3, h=0.75):
    """벽 밑에 쌓인 눈 더미(x0..x1 을 따라, 벽 겉면 yw 에서 face 쪽으로 d, 끝은 비스듬히)"""
    if x1 - x0 < 1.6:
        return
    yo = yw + face * d
    v = [(x0, yw, 0.0), (x1, yw, 0.0), (x1, yo, 0.0), (x0, yo, 0.0), (x0 + 0.7, yw, h), (x1 - 0.7, yw, h)]
    solid(g, "SnowDrift", v, [(0, 1, 2, 3), (0, 1, 5, 4), (3, 2, 5, 4), (0, 3, 4), (1, 2, 5)])   # 지붕·창턱 눈과 따로(발자국 재기)


def snow(g, x, y, ztop, sx, sy, t=0.16):
    """평평한 윗면에 얹힌 눈"""
    g["SnowCap"].box(x, y, ztop + t / 2, sx, sy, t)


def lamp_snow(g, x, y, zl):
    """바깥 등 놋쇠 지붕 위 눈"""
    S.pyramid(g, "SnowCap", x, y, zl + 0.62, 1.4, 1.4, 0.55, frac=0.55, lift=0.06)


def cash_register(g, x, y, z0):
    """놋쇠 금전 등록기: 서랍 받침 · 몸통 · 비탈 자판(3×6 둥근 단추) · 위 숫자 창(유리 + 숫자 패) · 꼭대기 톱니 문장 · 오른쪽 손잡이 · 옆 구리 판.
    자판은 +y(주인 쪽), 숫자 창은 -y(손님 쪽)"""
    W, D = 1.8, 1.5
    g["Wood"].box(x, y, z0 + 0.3, W, D, 0.6)
    g["Brass"].box(x, y, z0 + 0.63, W + 0.08, D + 0.08, 0.06)
    g["Timber"].box(x, y + D / 2 + 0.02, z0 + 0.3, W - 0.3, 0.06, 0.4)
    g["Brass"].box(x, y + D / 2 + 0.08, z0 + 0.32, 0.45, 0.08, 0.1)
    g["Brass"].box(x, y - 0.2, z0 + 1.1, W - 0.12, D - 0.55, 0.9)
    g["Brass"].obox(x, y + 0.42, z0 + 0.86, W - 0.12, 0.72, 0.4, rx=-0.5)
    for r in range(3):
        for c in range(6):
            kx = x - 0.66 + c * 0.264
            ky = y + 0.62 - r * 0.2
            kz = z0 + 0.98 + r * 0.11
            g["Iron"].cyl(kx, ky, kz, 0.025, 0.025, 0.14, seg=6)
            g["Paint"].cyl(kx, ky, kz + 0.14, 0.085, 0.085, 0.05, seg=10)
            g["Brass"].cyl(kx, ky, kz + 0.13, 0.095, 0.095, 0.02, seg=10)
    g["Brass"].box(x, y - 0.25, z0 + 1.82, 1.3, 0.4, 0.55)
    g["Glass"].box(x, y - 0.46, z0 + 1.84, 1.1, 0.03, 0.38)
    for k in range(4):
        g["Paint"].box(x - 0.42 + k * 0.28, y - 0.4, z0 + 1.84, 0.22, 0.02, 0.28)
        g["Char"].box(x - 0.42 + k * 0.28, y - 0.42, z0 + 1.84, 0.05, 0.01, 0.18)
    S.gear(g, "Brass", x, y - 0.25, z0 + 2.32, 0.28, 10, 0.1)
    for sx in (-1, 1):
        g["Brass"].hcyl(x + sx * 0.6, y - 0.25, z0 + 2.15, 0.1, 0.42, axis="y", seg=8)
        g["Copper"].box(x + sx * (W / 2 - 0.03), y - 0.2, z0 + 1.1, 0.04, 0.6, 0.45)
    g["Iron"].hcyl(x + W / 2 + 0.06, y, z0 + 1.05, 0.13, 0.2, axis="x", seg=10)
    g["Iron"].obox(x + W / 2 + 0.2, y - 0.18, z0 + 0.86, 0.07, 0.07, 0.55, rx=0.75)
    g["Wood"].cyl(x + W / 2 + 0.26, y - 0.38, z0 + 0.55, 0.06, 0.06, 0.28, seg=8)


def balance_scale(g, x, y, z0):
    """놋쇠 저울: 나무 받침 · 기둥 · 받침점 · 살짝 기운 대 · 바늘 · 사슬 셋에 매단 접시 둘 · 추 넷"""
    g["Wood"].box(x, y, z0 + 0.08, 1.6, 0.7, 0.16)
    g["Brass"].box(x, y, z0 + 0.17, 1.62, 0.72, 0.03)
    g["Brass"].cyl(x, y, z0 + 0.18, 0.12, 0.06, 1.3, seg=10)
    g["Brass"].box(x, y, z0 + 1.52, 0.22, 0.14, 0.16)
    g["Brass"].obox(x, y, z0 + 1.6, 1.75, 0.06, 0.07, ry=0.06)
    g["Steel"].box(x, y - 0.08, z0 + 1.3, 0.03, 0.03, 0.5)
    for sx in (-1, 1):
        ex, ez = x + sx * 0.84, z0 + 1.6 - sx * 0.05
        g["Brass"].cyl(ex, y, ez - 0.05, 0.04, 0.04, 0.1, seg=6)
        pz = z0 + 0.62 - sx * 0.05
        for k in range(3):
            a = k * 2 * math.pi / 3
            S.tube(g, "Iron", (ex, y, ez - 0.05), (ex + 0.27 * math.cos(a), y + 0.27 * math.sin(a), pz + 0.05), 0.012, seg=4)
        g["Brass"].cyl(ex, y, pz, 0.3, 0.34, 0.06, seg=14)
    for k, r in enumerate((0.13, 0.11, 0.09, 0.07)):
        g["Brass"].cyl(x - 0.45 + k * 0.28, y - 0.22, z0 + 0.2, r, r, 0.12 + r, seg=10)


def mortar(g, x, y, z0):
    """돌 절구 + 공이"""
    g["Stone"].cyl(x, y, z0, 0.32, 0.45, 0.5, seg=12)
    g["Char"].cyl(x, y, z0 + 0.46, 0.36, 0.36, 0.05, seg=12)
    g["Stone"].obox(x + 0.15, y, z0 + 0.75, 0.13, 0.13, 0.85, ry=0.45)
    g["Stone"].cyl(x + 0.36, y, z0 + 1.08, 0.09, 0.09, 0.12, seg=8)


def engraving_machine(g, x, y, z0):
    """룬 새김 기계: 쇠 바닥판 · 바이스(턱 둘 · 나사 · 손잡이)에 문 룬 돌 · 뒤 기둥(놋쇠 띠 · 톱니 상자 · 조절 바퀴) ·
    관절 팔 둘(놋쇠 관 · 쇠 축통) · 공구 머리(쇠 통 + 강철 끝이 돌 바로 위) · 뒤 무게추 · 거위목 확대경 · 끌 받침"""
    g["Iron"].box(x, y, z0 + 0.06, 2.6, 1.6, 0.12)
    for sx in (-1, 1):
        g["Iron"].box(x + sx * 0.55, y - 0.1, z0 + 0.32, 0.22, 1.0, 0.4)
    g["DarkStone"].box(x, y - 0.1, z0 + 0.25, 0.86, 0.9, 0.26)
    g["GlowTeal"].box(x, y - 0.1, z0 + 0.39, 0.42, 0.06, 0.02)
    g["GlowTeal"].box(x, y - 0.1, z0 + 0.39, 0.06, 0.5, 0.02)
    g["Steel"].hcyl(x + 0.9, y - 0.1, z0 + 0.34, 0.05, 0.9, axis="x", seg=6)
    g["Steel"].box(x + 1.35, y - 0.1, z0 + 0.34, 0.06, 0.6, 0.06)
    for dy in (-0.32, 0.32):
        sphere(g, "Brass", (x + 1.35, y - 0.1 + dy, z0 + 0.34), 0.07, sub=1)
    cx_, cy_ = x - 1.0, y + 0.5
    g["Iron"].cyl(cx_, cy_, z0 + 0.12, 0.17, 0.15, 1.75, seg=12)
    for zz in (0.5, 1.2):
        g["Brass"].cyl(cx_, cy_, z0 + zz, 0.21, 0.21, 0.08, seg=12)
    S.ring(g, "Brass", cx_, cy_, z0 + 0.9, 0.24, 0.34, 0.06, n=16)
    g["Brass"].box(cx_, cy_, z0 + 1.95, 0.5, 0.5, 0.45)
    S.gear(g, "Copper", cx_ - 0.27, cy_, z0 + 1.95, 0.22, 10, 0.06, axis="x")
    S.gear(g, "Brass", cx_ - 0.27, cy_ + 0.18, z0 + 1.75, 0.13, 8, 0.06, axis="x")
    sh, el, hd = (cx_ + 0.15, cy_, z0 + 2.05), (x - 0.15, y + 0.25, z0 + 2.3), (x, y - 0.05, z0 + 1.25)
    S.tube(g, "Brass", sh, el, 0.07, seg=8)
    S.tube(g, "Brass", el, hd, 0.06, seg=8)
    for p_ in (sh, el):
        g["Iron"].hcyl(p_[0], p_[1], p_[2], 0.11, 0.24, axis="y", seg=10)
    S.tube(g, "Iron", sh, (cx_ - 0.55, cy_, z0 + 1.85), 0.05, seg=6)
    g["Iron"].cyl(cx_ - 0.6, cy_, z0 + 1.6, 0.17, 0.17, 0.35, seg=10)
    g["Iron"].cyl(hd[0], hd[1], hd[2] - 0.35, 0.13, 0.13, 0.4, seg=10)
    g["Brass"].cyl(hd[0], hd[1], hd[2] - 0.36, 0.15, 0.15, 0.05, seg=10)
    g["Steel"].cyl(hd[0], hd[1], z0 + 0.45, 0.012, 0.035, 0.45, seg=6)
    gn = [(x + 1.15, y + 0.6, z0 + 0.12), (x + 1.15, y + 0.6, z0 + 0.9), (x + 0.85, y + 0.3, z0 + 1.35), (x + 0.45, y - 0.05, z0 + 1.45)]
    for a_, b_ in zip(gn, gn[1:]):
        S.tube(g, "Iron", a_, b_, 0.035, seg=5)
    S.ring(g, "Brass", x + 0.3, y - 0.1, z0 + 1.42, 0.3, 0.38, 0.06, n=16)
    g["Glass"].cyl(x + 0.3, y - 0.1, z0 + 1.43, 0.3, 0.3, 0.03, seg=16)
    g["Wood"].box(x - 0.2, y + 0.65, z0 + 0.17, 0.9, 0.25, 0.1)
    for k in range(3):
        g["Steel"].obox(x - 0.5 + k * 0.3, y + 0.65, z0 + 0.25, 0.04, 0.04, 0.45, rx=1.3)


def beer_tower(g, x, y, z0, taps=3, along=1.0):
    """맥주 꼭지 탑: 놋쇠 기둥 · 둥근 머리 · 꼭지 셋(나무 손잡이 · 놋쇠 띠 · 굽은 부리) · 쇠 받침 쟁반(창살)"""
    g["Brass"].cyl(x, y, z0, 0.22, 0.18, 1.1, seg=12)
    sphere(g, "Brass", (x, y, z0 + 1.15), 0.24, sub=1)
    g["Brass"].hcyl(x + 0.2, y, z0 + 0.85, 0.08, 0.55 * (taps - 1) + 0.2, axis="y", seg=8)   # 꼭지를 잇는 가로 관
    for k in range(taps):
        ty = y + (k - (taps - 1) / 2) * 0.55 * along
        g["Brass"].hcyl(x + 0.22, ty, z0 + 0.85, 0.07, 0.3, axis="x", seg=8)
        g["Brass"].cyl(x + 0.36, ty, z0 + 0.55, 0.05, 0.05, 0.32, seg=8)
        g["Brass"].cyl(x + 0.28, ty, z0 + 0.92, 0.07, 0.07, 0.12, seg=8)
        g["Wood"].cyl(x + 0.28, ty, z0 + 1.04, 0.05, 0.08, 0.6, seg=8)
        g["Brass"].cyl(x + 0.28, ty, z0 + 1.62, 0.085, 0.085, 0.06, seg=8)
    g["Iron"].box(x + 0.4, y, z0 + 0.04, 0.6, 0.55 * taps + 0.3, 0.08)
    for k in range(5):
        g["Steel"].box(x + 0.4, y - 0.55 * taps / 2 + k * 0.55 * taps / 4, z0 + 0.09, 0.55, 0.03, 0.02)


def beer_mug(g, x, y, z0):
    g["Glass"].cyl(x, y, z0, 0.22, 0.24, 0.55, seg=10)
    g["SignGold"].cyl(x, y, z0 + 0.03, 0.19, 0.2, 0.42, seg=10)
    g["Canvas"].cyl(x, y, z0 + 0.45, 0.21, 0.23, 0.12, seg=10)
    g["Glass"].box(x + 0.28, y, z0 + 0.28, 0.06, 0.08, 0.36)


def mantel_clock(g, x, y, z0, face=-1):
    """벽난로 선반 시계: 나무 함(둥근 머리) · 흰 판 · 놋쇠 테 · 시침·분침 · 아래 추 창 · 다리"""
    yf = y + face * 0.31
    g["Wood"].box(x, y, z0 + 0.8, 1.3, 0.6, 1.2)
    g["Wood"].hcyl(x, y, z0 + 1.4, 0.65, 0.6, axis="y", seg=16)
    g["Paint"].hcyl(x, yf, z0 + 1.35, 0.42, 0.04, axis="y", seg=16)
    g["Brass"].hcyl(x, yf - face * 0.01, z0 + 1.35, 0.5, 0.03, axis="y", seg=16)
    g["Paint"].hcyl(x, yf + face * 0.02, z0 + 1.35, 0.42, 0.03, axis="y", seg=16)
    g["Iron"].obox(x + 0.08, yf + face * 0.05, z0 + 1.47, 0.04, 0.02, 0.28, ry=-0.6)
    g["Iron"].obox(x - 0.1, yf + face * 0.05, z0 + 1.42, 0.04, 0.02, 0.2, ry=1.1)
    g["Glass"].box(x, yf, z0 + 0.6, 0.5, 0.03, 0.5)
    g["Brass"].cyl(x, yf - face * 0.1, z0 + 0.4, 0.1, 0.1, 0.04, seg=8)
    for sx in (-1, 1):
        sphere(g, "Brass", (x + sx * 0.55, y, z0 + 0.12), 0.1, sub=1)

# ------------------------------------------------------------------ 대장간
W_SM, D_SM, H_SM = 36.0, 30.0, 16.0
FORGE = (-11.0, 10.5)


def smithy_forge(g):
    """왼 뒤 화덕: 벽돌 화덕 7×6(윗면 4.0) · 쇠 화로에 숯불(진짜 불) · 앞 재구덩이 · 후드 → 쇠 굴뚝 → 지붕 위 벽돌 굴뚝 · 풀무(왼) · 연장 걸이(오른)"""
    fx, fy = FORGE
    box2(g, "Brick", fx - 3.5, fx + 3.5, fy - 3.0, fy + 3.0, FZ, 3.6)
    g["StoneTrim"].box(fx, fy, 3.8, 7.4, 6.4, 0.4)
    g["StoneTrim"].box(fx, fy, FZ + 0.15, 7.3, 6.3, 0.3)
    # 앞 재구덩이(어두운 아가리 + 띠돌 테)
    g["Soot"].box(fx, fy - 3.04, 1.6, 2.6, 0.1, 1.6)
    g["StoneTrim"].box(fx, fy - 3.12, 2.55, 3.4, 0.3, 0.35)
    for s in (-1, 1):
        g["StoneTrim"].box(fx + s * 1.5, fy - 3.12, 1.6, 0.4, 0.3, 1.6)
    # 화로: 쇠 테 + 숯불(빛나는 블록 아님 — coal_bed 가 숯·불씨·불꽃 자리)
    for s in (-1, 1):
        g["Iron"].box(fx + s * 1.9, fy - 0.4, 4.15, 0.3, 3.8, 0.3)
        g["Iron"].box(fx, fy - 0.4 + s * 1.9, 4.15, 4.1, 0.3, 0.3)
    coal_bed(g, fx, fy - 0.4, 4.0, 3.4, 3.4, size=0.9)
    # 후드: 뒤 두 기둥 + 쇠 뿔대 + 테·리벳 → 쇠 굴뚝(지붕 밑 벽돌 굴뚝으로)
    for s in (-1, 1):
        g["Iron"].box(fx + s * 3.2, fy + 2.6, 5.5, 0.4, 0.4, 3.0)
    frustum(g, "Iron", fx, fy, 7.0, 7.0, 6.2, 2.2, 2.2, 3.0)
    for s in (-1, 1):
        g["IronLight"].box(fx + s * 3.55, fy, 7.15, 0.2, 6.5, 0.3)
        g["IronLight"].box(fx, fy + s * 3.15, 7.15, 7.3, 0.2, 0.3)
    for k in range(9):
        t = -3.2 + k * 0.8
        g["Brass"].box(fx + t, fy - 3.3, 7.15, 0.14, 0.1, 0.14)
    g["Iron"].cyl(fx, fy, 10.0, 1.0, 1.0, 10.2, seg=16)
    for z in (11.0, 14.0, 17.0):
        g["Brass"].cyl(fx, fy, z, 1.1, 1.1, 0.3, seg=16)
    # 지붕 위 벽돌 굴뚝 + 갓 + 김(연기) 자리
    g["BrickDark"].box(fx, fy, 22.0, 3.2, 3.2, 12.0)
    g["StoneTrim"].box(fx, fy, 28.2, 3.8, 3.8, 0.5)
    g["Iron"].box(fx, fy, 28.9, 2.2, 2.2, 0.9)
    S.vent(g, fx, fy, 29.6)
    # 풀무(화덕 왼쪽, 왼 벽과 사이 2.5): 받침 다리 · 아래 판 · 벌어진 윗판 · 가죽 주름 · 놋쇠 부리 · 손잡이
    bx = fx - 4.75
    for y in (fy - 1.0, fy + 1.0):
        g["Wood"].box(bx, y, 1.5, 1.6, 0.3, 2.2)
    # 풀무: 아래 판(고정) · 가죽 주름 넷(부리 쪽으로 낮아짐) · 놋쇠 띠 · 윗판(부리 쪽 경첩, 뒤가 들림) · 놋쇠 부리(화덕으로) ·
    #       뒤 기둥 + 지렛대 + 사슬(윗판 손잡이까지)
    g["Wood"].box(bx, fy, 2.66, 2.2, 1.7, 0.16)
    for k in range(4):
        u = -0.75 + k * 0.45                                  # 뒤(-x) → 부리(+x)
        hh = 0.62 - k * 0.13
        g["Leather"].box(bx + u, fy, 2.74 + hh / 2, 0.36, 1.55 - (k % 2) * 0.12, hh)
        g["Brass"].box(bx + u + 0.2, fy, 2.74 + hh / 2, 0.04, 1.62, hh + 0.02)
    g["Wood"].obox(bx, fy, 3.18, 2.25, 1.7, 0.14, ry=0.3)
    g["Iron"].hcyl(bx + 1.05, fy, 2.82, 0.08, 1.4, axis="y", seg=8)
    S.tube(g, "Brass", (bx + 1.05, fy - 0.4, 2.8), (fx - 3.45, fy - 0.4, 3.0), 0.12, seg=10)
    g["Timber"].box(bx - 0.95, fy + 0.95, 3.2, 0.3, 0.3, 4.4)
    g["Timber"].obox(bx - 0.5, fy + 0.95, 5.25, 1.6, 0.16, 0.16, ry=0.35)
    S.tube(g, "Iron", (bx + 0.25, fy + 0.95, 4.98), (bx - 0.6, fy, 3.42), 0.03, seg=4)
    g["Brass"].box(bx - 0.6, fy, 3.42, 0.3, 0.3, 0.1)
    C(bx, fy, 2.0, 2.2, 3.0, 3.6)
    # 연장 걸이(화덕 오른 옆면): 쇠 막대 + 집게 둘 · 망치 · 부지깽이
    rx = fx + 3.62
    g["Iron"].box(rx, fy, 3.1, 0.12, 4.6, 0.12)
    for y in (-1.8, 1.8):
        g["Iron"].box(rx - 0.1, fy + y, 3.1, 0.3, 0.12, 0.12)
    g["Iron"].obox(rx + 0.12, fy - 1.0, 2.3, 0.08, 0.1, 1.7, rx=0.12)
    g["Iron"].obox(rx + 0.12, fy - 0.8, 2.3, 0.08, 0.1, 1.7, rx=-0.12)
    g["Wood"].box(rx + 0.12, fy + 0.3, 2.4, 0.12, 0.12, 1.4)
    g["Iron"].box(rx + 0.12, fy + 0.3, 1.65, 0.3, 0.45, 0.25)
    g["Iron"].box(rx + 0.12, fy + 1.2, 2.2, 0.08, 0.08, 1.8)
    # 담금질 통(화덕과 뒷문 사이) — 쇠 통 + 물
    qx, qy = -5.0, 10.5
    for s in (-1, 1):
        g["Iron"].box(qx + s * 1.45, qy, FZ + 1.0, 0.15, 3.0, 2.0)
        g["Iron"].box(qx, qy + s * 1.45, FZ + 1.0, 3.0, 0.15, 2.0)
    g["Iron"].box(qx, qy, FZ + 0.1, 3.0, 3.0, 0.2)
    g["Glass"].box(qx, qy, FZ + 1.7, 2.75, 2.75, 0.1)
    for s in (-1, 1):
        g["Brass"].box(qx, qy + s * 1.45, FZ + 2.0, 3.1, 0.25, 0.12)
    C(qx, qy, FZ + 1.0, 3.0, 3.0, 2.0)
    # 석탄 통(왼 벽, 화덕 앞)
    box2(g, "Iron", -17.0 + 0.1, -14.6, 1.6, 4.4, FZ, FZ + 1.6)
    for k, (x, y) in enumerate(((-16.2, 2.2), (-15.4, 2.9), (-16.0, 3.7), (-15.3, 3.9), (-15.8, 2.9))):
        g["Char"].obox(x, y, FZ + 1.7, 0.6, 0.5, 0.35, rz=k * 0.9)


def smithy_racks(g):
    """왼 벽 무기 걸이(y -12..0): 뒤 판 · 칼끝 홈 받침(1.4) · 위 걸이 막대(4.6) · 칼 다섯 · 도끼 둘 · 창 둘, 위에 방패 둘"""
    xw = -17.0
    g["Timber"].box(xw + 0.15, -6.0, 4.3, 0.3, 12.0, 6.6)
    for y in (-12.0, -6.0, 0.0):
        g["Timber"].box(xw + 0.55, y, 3.9, 0.5, 0.4, 7.0)
    g["Timber"].box(xw + 0.9, -6.0, 1.3, 1.2, 12.0, 0.25)
    g["Iron"].box(xw + 0.9, -6.0, 4.75, 0.12, 12.0, 0.12)
    for y in (-11.0, -9.8, -8.6, -7.4, -6.2):
        sword_hilt_up(g, xw + 0.9, y, 1.45, blade=3.1)
    for y in (-4.6, -3.2):
        axe_up(g, xw + 0.9, y, 1.45)
    for y in (-1.8, -0.8):
        spear_up(g, xw + 0.9, y, 1.45)
    for y in (-6.0, 0.0):
        g["Wood"].hcyl(xw + 0.25, y, 8.2, 1.1, 0.2, axis="x", seg=16)
        g["Iron"].hcyl(xw + 0.38, y, 8.2, 0.35, 0.12, axis="x", seg=10)
        g["Brass"].hcyl(xw + 0.3, y, 8.2, 1.15, 0.08, axis="x", seg=16)
    C(xw + 0.75, -6.0, FZ + 3.6, 1.5, 12.4, 7.2)


def smithy_counter(g):
    """오른 뒤 제작 카운터(x 5..15, y 4..6.5, 높이 3.5): 나무 몸 · 쇠 띠 · 놋쇠 모서리 · 위 장부·완성 칼·종, 뒤 주문판"""
    x0, x1, y0, y1 = 5.0, 15.0, 4.0, 6.5
    g["Timber"].box((x0 + x1) / 2, (y0 + y1) / 2, (FZ + 3.2) / 2, x1 - x0 - 0.4, y1 - y0 - 0.3, 3.2 - FZ)
    g["Wood"].box((x0 + x1) / 2, (y0 + y1) / 2, 3.35, x1 - x0 + 0.2, y1 - y0 + 0.3, 0.3)
    for x in (6.6, 10.0, 13.4):
        g["Iron"].box(x, y0 + 0.08, 1.8, 0.45, 0.1, 2.6)
    g["IronLight"].box((x0 + x1) / 2, y0 + 0.1, 2.75, x1 - x0 - 0.3, 0.1, 0.25)
    g["Iron"].box((x0 + x1) / 2, y0 + 0.12, FZ + 0.2, x1 - x0 - 0.3, 0.12, 0.4)
    for x in (x0 - 0.05, x1 + 0.05):
        for y in (y0 - 0.1, y1 + 0.1):
            g["Brass"].box(x, y, 3.35, 0.35, 0.35, 0.34)
    C((x0 + x1) / 2, (y0 + y1) / 2, (FZ + 3.5) / 2, x1 - x0 + 0.2, y1 - y0 + 0.3, 3.5 - FZ)
    # 위: 장부(가죽 표지 + 펼친 쪽) · 완성 칼(가로) · 놋쇠 종
    g["Leather"].box(7.6, 5.2, 3.58, 1.6, 1.1, 0.16)
    g["Canvas"].box(7.6, 5.2, 3.68, 1.45, 0.95, 0.04)
    g["Steel"].box(11.6, 5.0, 3.56, 2.8, 0.32, 0.08)
    g["Brass"].box(10.1, 5.0, 3.58, 0.16, 1.0, 0.14)
    g["Leather"].box(9.6, 5.0, 3.58, 0.8, 0.16, 0.14)
    g["Brass"].cyl(13.9, 4.8, 3.5, 0.32, 0.18, 0.4, seg=12)
    sphere(g, "Brass", (13.9, 4.8, 4.0), 0.12, sub=1)
    # 뒤 벽 주문판(종이 넷) + 연장 판(망치·집게 실루엣)
    g["Timber"].box(11.6, 13.85, 7.2, 6.0, 0.25, 3.4)                     # 뒷문(x 1..7) 옆으로 비켜
    for k, (x, z, rz) in enumerate(((9.6, 7.8, 0.06), (11.0, 6.9, -0.05), (12.3, 7.9, 0.03), (13.6, 6.8, -0.08))):
        g["Canvas"].obox(x, 13.7, z, 1.3, 0.04, 1.6, ry=rz)
        g["Brass"].box(x, 13.66, z + 0.7, 0.14, 0.06, 0.14)
    NPC(10.0, 9.0, FZ, 0.0)


def smithy_shelf(g):
    """오른 뒤 재료 선반(x 15.6..17, y 8..14): 기둥 · 판 넷 · 쇠·놋쇠·구리 주괴 · 광석 · 앞 상자 둘(하나는 열린 광석 상자)"""
    x0, x1, y0, y1 = 15.6, 17.0, 8.0, 14.0
    for y in (y0 + 0.15, y1 - 0.15):
        for x in (x0 + 0.12, x1 - 0.12):
            g["Timber"].box(x, y, FZ + 3.5, 0.24, 0.24, 7.0)
    for k, z in enumerate((1.3, 3.1, 4.9, 6.7)):
        g["Wood"].box((x0 + x1) / 2, (y0 + y1) / 2, z, x1 - x0, y1 - y0, 0.18)
        mats = ("Iron", "Brass", "Copper", "IronLight")
        for j in range(5):
            y = y0 + 0.8 + j * 1.1
            m = mats[(j + k) % 4]
            for h in range(2 - (j + k) % 2):
                g[m].box(x0 + 0.7, y, z + 0.17 + h * 0.26, 0.9, 0.42, 0.24)
    C((x0 + x1) / 2, (y0 + y1) / 2, FZ + 3.5, x1 - x0, y1 - y0, 7.0)
    crate(g, 13.6, 12.6, FZ, 2.2)
    crate(g, 13.6, 12.6, FZ + 2.2, 1.8, rz=0.2)
    crate(g, 13.4, 9.9, FZ, 2.2, h=1.4)
    ore_lumps(g, 13.4, 9.9, FZ + 1.4, r=0.8, n=7, seed=3)
    C(13.5, 11.3, FZ + 1.9, 2.6, 5.2, 3.8)


def grindstone(g, x, y):
    """숫돌: 돌 바퀴(축 x) · 나무 틀 · 아래 물받이 · 발판"""
    g["Stone"].hcyl(x, y, 2.4, 1.3, 0.5, axis="x", seg=20)
    g["Iron"].hcyl(x, y, 2.4, 0.14, 2.2, axis="x", seg=8)
    for s in (-1, 1):
        g["Timber"].obox(x + s * 0.7, y - 0.6, 1.4, 0.25, 0.25, 2.2, rx=0.35)
        g["Timber"].obox(x + s * 0.7, y + 0.6, 1.4, 0.25, 0.25, 2.2, rx=-0.35)
    g["Iron"].box(x, y, 0.9, 0.9, 2.0, 0.5)
    g["Glass"].box(x, y, 1.12, 0.7, 1.8, 0.06)
    g["Wood"].obox(x, y - 1.5, 0.6, 0.9, 1.0, 0.12, rx=0.3)
    # 손잡이 크랭크(축 끝) + 발판 → 크랭크 막대
    g["Iron"].obox(x + 1.15, y, 2.05, 0.1, 0.12, 0.8)
    g["Wood"].hcyl(x + 1.35, y, 1.68, 0.07, 0.4, axis="x", seg=8)
    S.tube(g, "Iron", (x + 1.12, y - 1.5, 0.66), (x + 1.12, y, 1.7), 0.035, seg=5)
    C(x, y, 1.8, 2.6, 3.2, 3.0)


def smithy_shell(g):
    W, D, H = W_SM, D_SM, H_SM
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T
    # 바닥(돌 판) + 화덕 둘레 그을음
    g["Stone"].box(0, 0, FZ / 2, W + 0.6, D + 0.6, FZ)
    C(0, 0, FZ / 2, W + 0.6, D + 0.6, FZ)
    g["Soot"].box(FORGE[0] + 1.0, FORGE[1] - 1.0, FZ + 0.03, 11.0, 9.0, 0.06)
    # 벽: 앞(가운데 14×11 트임) · 뒤(뒷문 x 1..7, 높이 9) · 옆
    box2(g, "Brick", -W / 2, -7.0, -D / 2, iy0, FZ, H)
    box2(g, "Brick", 7.0, W / 2, -D / 2, iy0, FZ, H)
    box2(g, "Brick", -7.0, 7.0, -D / 2, iy0, FZ + 11.0, H)
    box2(g, "Brick", -W / 2, 1.0, iy1, D / 2, FZ, H)
    box2(g, "Brick", 7.0, W / 2, iy1, D / 2, FZ, H)
    box2(g, "Brick", 1.0, 7.0, iy1, D / 2, FZ + 9.0, H)
    for s in (-1, 1):
        box2(g, "Brick", *sorted((s * W / 2, s * ix1)), iy0, iy1, FZ, H)
    # 띠돌: 밑동(트임 자리는 비움) · 처마
    for y0, y1, xs in ((-D / 2 - 0.25, -D / 2 + 0.05, ((-W / 2 - 0.25, -7.8), (7.8, W / 2 + 0.25))),
                       (D / 2 - 0.05, D / 2 + 0.25, ((-W / 2 - 0.25, 0.8), (7.2, W / 2 + 0.25)))):
        for a, b in xs:
            g["StoneTrim"].box((a + b) / 2, (y0 + y1) / 2, FZ + 0.45, b - a, y1 - y0, 0.9)
    for s in (-1, 1):
        g["StoneTrim"].box(s * (W / 2 + 0.1), 0, FZ + 0.45, 0.3, D + 0.5, 0.9)
    for y0, y1, x0, x1 in ((-D / 2 - 0.4, -D / 2 + 0.4, -W / 2 - 0.4, W / 2 + 0.4), (D / 2 - 0.4, D / 2 + 0.4, -W / 2 - 0.4, W / 2 + 0.4),
                           (-D / 2 + 0.4, D / 2 - 0.4, -W / 2 - 0.4, -W / 2 + 0.4), (-D / 2 + 0.4, D / 2 - 0.4, W / 2 - 0.4, W / 2 + 0.4)):
        g["StoneTrim"].box((x0 + x1) / 2, (y0 + y1) / 2, H - 0.3, x1 - x0, y1 - y0, 0.7)
    quoins(g, W, D, FZ, H - 0.8)
    for a_, b_ in ((-W / 2, -15.0), (15.0, W / 2)):
        drift(g, a_, b_, -D / 2 - 0.85, -1, d=1.0)
    for a_, b_ in ((-W / 2, 0.4), (7.6, W / 2)):
        drift(g, a_, b_, D / 2, 1)
    # 트임: 띠돌 기둥 · 리벳 박은 쇠 들보 · 밀어 연 쇠문 둘(겉, 레일)
    fy = -D / 2
    for s in (-1, 1):
        g["StoneTrim"].box(s * 7.45, fy - 0.15, FZ + 5.5, 0.9, 0.7, 11.0)
    g["Iron"].box(0, fy - 0.3, FZ + 11.5, 15.6, 0.6, 1.0)
    for z in (FZ + 11.05, FZ + 11.95):
        g["IronLight"].box(0, fy - 0.42, z, 15.8, 0.8, 0.16)
    snow(g, 0, fy - 0.42, FZ + 12.03, 15.6, 0.7)                             # 들보 위 눈
    for k in range(13):
        g["Brass"].box(-7.2 + k * 1.2, fy - 0.66, FZ + 11.5, 0.16, 0.12, 0.16)
    g["Iron"].box(0, fy - 0.85, FZ + 11.1, 30.0, 0.2, 0.22)                 # 문 레일
    for s in (-1, 1):
        cx = s * 11.2
        g["Iron"].box(cx, fy - 0.6, FZ + 5.4, 6.8, 0.25, 10.6)
        for z in (FZ + 1.2, FZ + 5.4, FZ + 9.6):
            g["IronLight"].box(cx, fy - 0.76, z, 6.9, 0.1, 0.35)
        g["IronLight"].obox(cx, fy - 0.78, FZ + 3.3, 0.3, 0.08, 4.6, ry=s * 0.95)
        g["IronLight"].obox(cx, fy - 0.78, FZ + 7.5, 0.3, 0.08, 4.6, ry=-s * 0.95)
        for x in (cx - 2.6, cx + 2.6):
            g["Brass"].cyl(x, fy - 0.85, FZ + 10.75, 0.22, 0.22, 0.3, seg=10)
    # 트임 위 간판: 나무 판 + 놋쇠 테 + 모루 그림(광장에서 읽힌다) + 양옆 작은 톱니
    g["Timber"].box(0, fy - 0.35, FZ + 13.5, 7.4, 0.3, 3.0)
    for z in (FZ + 12.05, FZ + 14.95):
        g["Brass"].box(0, fy - 0.5, z, 7.6, 0.2, 0.2)
    snow(g, 0, fy - 0.45, FZ + 15.05, 7.5, 0.4)
    for x in (-3.75, 3.75):
        g["Brass"].box(x, fy - 0.5, FZ + 13.5, 0.2, 0.2, 3.1)
    anvil_icon(g, -0.5, fy - 0.5, FZ + 12.62, s=0.9)
    for x in (-5.4, 5.4):
        S.gear(g, "Brass", x, fy - 0.45, FZ + 13.5, 0.9, 10, 0.25)
    # 창: 옆벽 높은 창 넷씩(무기 걸이·선반 위) · 뒤 창 둘
    for y in (-9.0, -3.0, 3.0, 9.0):
        side_window(g, -W / 2, ix0, y, 9.5, 3.0, 4.0, "-x")
        side_window(g, W / 2, ix1, y, 9.5, 3.0, 4.0, "+x")
    for x in (-4.5, 12.0):
        back_window(g, x, D / 2, iy1, 9.5, 3.0, 4.0)
    # 지붕: 앞뒤 박공(광장에서 세모가 보인다) + 박공 환기 덧창 + 놋쇠 큰 톱니
    S.roof_gable(g, 0, 0, H, W + 0.6, D + 0.6, 9.0, along="y")
    gy = -D / 2 - 0.35
    g["Iron"].box(0, gy, H + 3.4, 4.4, 0.3, 2.8)
    snow(g, 0, gy - 0.05, H + 4.8, 4.3, 0.4, t=0.12)
    for k in range(5):
        g["IronLight"].obox(0, gy - 0.15, H + 2.3 + k * 0.52, 4.0, 0.12, 0.42, rx=0.6)
    S.gear(g, "Brass", 0, gy - 0.1, H + 6.0, 1.3, 12, 0.3)
    # 안: 지붕틀 셋(밑둥 들보 · 왕기둥 · 서까래) + 매단 등 넷
    a = math.atan2(9.0, (W + 0.6) / 2)
    for y in (-7.0, 0.0, 7.0):
        g["Timber"].box(0, y, H - 0.6, W - 2 * T, 0.6, 0.6)
        g["Timber"].box(0, y, (H + H + 8.4) / 2, 0.5, 0.5, 8.4)
        for s in (-1, 1):
            g["Timber"].obox(s * 8.5, y, H + 4.3, 18.9, 0.45, 0.5, ry=s * a)
            g["Timber"].obox(s * 4.0, y, H + 2.1, 0.35, 0.4, 5.0, ry=-s * 0.85)
    for x, y in ((-6.0, -7.0), (6.0, -7.0), (10.0, 0.0), (-2.0, 7.0)):
        lantern(g, x, y, H - 0.9, 11.2)
    # 바깥 오른 뒤: 감정 열기 통(구리, 띠) + 벽으로 드는 관 + 압력계 + 김
    tx, ty = W / 2 + 1.7, 10.0
    S.banded_cyl(g, "Copper", tx, ty, FZ, 1.4, 11.0, every=3.0)
    S.vent(g, tx, ty, FZ + 11.8)
    S.pipe(g, [(tx, ty, FZ + 11.0), (tx, ty, FZ + 12.6), (W / 2 - 0.2, ty, FZ + 12.6)], 0.35, mat="Copper")
    g["Iron"].hcyl(tx, ty - 0.55, FZ + 12.0, 0.6, 0.12, axis="y", seg=12)
    g["Brass"].hcyl(tx, ty - 0.62, FZ + 12.0, 0.15, 0.1, axis="y", seg=8)
    g["Brass"].hcyl(tx, ty - 1.38, 4.0, 0.55, 0.25, axis="y", seg=14)
    g["Glow"].hcyl(tx, ty - 1.52, 4.0, 0.42, 0.06, axis="y", seg=14)
    C(tx, ty, FZ + 5.5, 2.8, 2.8, 11.0)
    # 뒷문: 안(-y)으로 연 널문(경첩 x 1 — 담금질 통과 모루 사이, 문 길 x 1..7 밖)
    ang = -math.radians(95.0)
    hx, hy = 1.0, D / 2 - T - 0.2
    cxl, cyl = hx + math.cos(ang) * 3.0, hy + math.sin(ang) * 3.0
    g["Timber"].obox(cxl, cyl, FZ + 4.45, 6.0, 0.3, 8.9, rz=ang)
    for zz in (0.25, 0.55, 0.85):
        g["Iron"].obox(cxl + math.sin(ang) * 0.2, cyl - math.cos(ang) * 0.2, FZ + 8.9 * zz, 6.05, 0.08, 0.3, rz=ang)
    DOORWAY(-7.0, 7.0, -D / 2 - 0.2, iy0, FZ, 11.0)
    DOORWAY(1.0, 7.0, iy1, D / 2 + 0.2, FZ, 9.0)
    CLEAR(-6.5, 6.5, iy0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)          # 입구 완충
    CLEAR(5.2, 14.8, -6.0, 3.7, FZ + 0.15, FZ + 5.4)                # 카운터 앞 빈 바닥


def svc_smithy(g):
    smithy_shell(g)
    smithy_forge(g)
    smithy_racks(g)
    smithy_counter(g)
    smithy_shelf(g)
    PROP("Anvil", -1.0, 4.0, FZ, 15.0, 1.1)
    C(-1.0, 4.0, FZ + 1.8, 2.2, 2.2, 3.6)
    grindstone(g, 14.0, -10.5)
    # 앞 왼: 갑옷 진열대(문 쪽을 본다) + 창 꽂은 통
    armor_stand(g, -12.5, -11.0, FZ, face_rz=math.pi / 2 - 0.5)
    g["Wood"].cyl(-15.6, -12.8, FZ, 0.75, 0.75, 1.6, seg=12)
    for z in (FZ + 0.4, FZ + 1.3):
        g["Iron"].cyl(-15.6, -12.8, z, 0.78, 0.78, 0.12, seg=12)
    for k, (dx, dy) in enumerate(((-0.3, -0.2), (0.25, 0.1), (0.0, 0.35), (0.3, -0.3))):
        spear_up(g, -15.6 + dx, -12.8 + dy, FZ + 0.3, h=5.4 + k * 0.3)
    C(-15.6, -12.8, FZ + 0.8, 1.6, 1.6, 1.6)
    # 오른 벽: 연장 작업대(바이스) + 위 연장 판
    bx0, bx1, by0, by1 = 15.0, 17.0, -5.0, 1.0
    g["Wood"].box((bx0 + bx1) / 2, (by0 + by1) / 2, 3.25, bx1 - bx0, by1 - by0, 0.3)
    for x in (bx0 + 0.2, bx1 - 0.2):
        for y in (by0 + 0.2, by1 - 0.2):
            g["Timber"].box(x, y, (FZ + 3.1) / 2, 0.3, 0.3, 3.1 - FZ)
    g["Timber"].box((bx0 + bx1) / 2, (by0 + by1) / 2, 1.0, bx1 - bx0 - 0.3, by1 - by0 - 0.3, 0.15)
    g["Iron"].box(bx0 + 0.3, by0 + 0.8, 3.75, 0.6, 0.9, 0.7)
    g["Iron"].box(bx0 + 0.3, by0 + 0.8, 3.75, 0.9, 0.2, 0.3)
    C((bx0 + bx1) / 2, (by0 + by1) / 2, (FZ + 3.4) / 2, bx1 - bx0, by1 - by0, 3.4 - FZ)
    g["Timber"].box(16.85, -2.0, 6.3, 0.2, 6.0, 3.6)
    for k, y in enumerate((-4.2, -3.2, -2.2, -1.2, -0.2, 0.6)):
        if k % 2:
            g["Iron"].obox(16.7, y - 0.1, 6.0, 0.08, 0.1, 1.9, rx=0.15)
            g["Iron"].obox(16.7, y + 0.1, 6.0, 0.08, 0.1, 1.9, rx=-0.15)
        else:
            g["Wood"].box(16.7, y, 5.8, 0.1, 0.12, 1.5)
            g["IronLight"].box(16.7, y, 6.7, 0.18, 0.55, 0.3)
    # 모루 위 사슬 도르래(지붕틀에서) · 오른 뒤 통
    g["Iron"].box(-1.0, 0.0, H_SM - 1.3, 0.8, 0.5, 0.6)
    g["Iron"].cyl(-1.0, 0.0, 9.6, 0.07, 0.07, H_SM - 1.6 - 9.6, seg=6)
    g["Iron"].obox(-1.0, 0.18, 9.35, 0.12, 0.5, 0.12, rx=0.6)
    g["Wood"].cyl(16.0, 6.9, FZ, 0.75, 0.75, 2.0, seg=12)
    for z in (FZ + 0.4, FZ + 1.5):
        g["Iron"].cyl(16.0, 6.9, z, 0.78, 0.78, 0.12, seg=12)
    C(16.0, 6.9, FZ + 1.0, 1.6, 1.6, 2.0)


# ------------------------------------------------------------------ 대장간 마당
def yard_sign(g, x, y, icon):
    """뜰 간판 기둥: 나무 기둥 · 쇠 팔 · 매단 판(양면 그림)"""
    g["Timber"].box(x, y, 3.6, 0.4, 0.4, 7.2)
    g["Iron"].box(x + 1.4, y, 6.8, 3.0, 0.15, 0.15)
    for dx in (0.6, 2.2):
        g["Iron"].box(x + dx, y, 6.35, 0.06, 0.06, 0.8)
    g["Timber"].box(x + 1.4, y, 5.3, 2.6, 0.22, 1.8)
    g["Brass"].box(x + 1.4, y, 6.24, 2.7, 0.26, 0.12)
    snow(g, x + 1.4, y, 6.3, 2.6, 0.3, t=0.12)
    snow(g, x + 1.4, y, 6.88, 2.9, 0.18, t=0.08)
    icon(g, x + 1.4, y - 0.11, 5.1, -1)
    icon(g, x + 1.4, y + 0.11, 5.1, 1)
    C(x, y, 3.6, 0.6, 0.6, 7.2)


def yard_smithy(g):
    W, D = 30.0, 16.0
    g["Stone"].box(0, 0, 0.1, W, D, 0.2)
    C(0, 0, 0.1, W, D, 0.2)
    for x, y, sx, sy in ((-6.0, 3.0, 9.0, 6.0), (8.0, 0.0, 7.0, 5.0)):
        g["Soot"].box(x, y, 0.23, sx, sy, 0.04)
    # 광석 더미 셋(뒷문에서 오는 길 x 1..7 밖)
    for k, x in enumerate((-12.0, -7.5, -3.0)):
        ore_lumps(g, x, 4.0, 0.2, r=1.9, n=16, seed=11 + k, mound=True)
        C(x, 4.0, 1.3, 4.0, 4.0, 2.4)
    # 광석 수레(바퀴 넷) · 식히는 칼 걸이 · 물통
    cx_, cy_ = -9.0, -3.6
    g["Wood"].box(cx_, cy_, 1.6, 3.4, 2.0, 1.2)
    for z in (1.1, 2.1):
        g["Iron"].box(cx_, cy_, z, 3.5, 2.1, 0.14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].hcyl(cx_ + sx * 1.1, cy_ + sy * 1.1, 0.75, 0.55, 0.2, axis="y", seg=12)
    g["Iron"].obox(cx_ + 2.4, cy_, 1.9, 1.6, 0.12, 0.12, ry=-0.4)
    ore_lumps(g, cx_, cy_, 2.1, r=0.9, n=7, seed=21)
    C(cx_, cy_, 1.2, 3.6, 2.4, 2.4)
    for sx in (1.6, 4.4):
        for sy in (-1, 1):
            g["Timber"].obox(sx, 5.5 + sy * 0.4, 1.4, 0.2, 0.2, 2.6, rx=-sy * 0.3)
    g["Timber"].box(3.0, 5.5, 2.55, 3.2, 0.2, 0.2)
    for k, x in enumerate((2.0, 2.7, 3.4, 4.1)):
        g["Steel"].obox(x, 5.1, 1.6, 0.07, 0.3, 2.4, rx=0.32)
        g["Leather"].obox(x, 4.75, 2.75, 0.14, 0.14, 0.7, rx=0.32)
    C(3.0, 5.5, 1.4, 3.4, 1.4, 2.8)
    g["Wood"].cyl(13.6, -1.2, 0.2, 0.85, 0.85, 1.9, seg=14)
    for z in (0.6, 1.7):
        g["Iron"].cyl(13.6, -1.2, z, 0.88, 0.88, 0.12, seg=14)
    g["Glass"].cyl(13.6, -1.2, 2.0, 0.78, 0.78, 0.06, seg=14)
    C(13.6, -1.2, 1.1, 1.8, 1.8, 1.9)
    # 바깥 모루(그루터기) + 숯 화로(다리 셋, 진짜 불)
    PROP("Anvil", 6.3, 0.6, 0.2, -20.0, 1.0)
    C(6.3, 0.6, 1.8, 2.0, 2.0, 3.3)
    hx, hy = 9.6, 3.2
    g["Iron"].cyl(hx, hy, 2.0, 0.9, 1.1, 0.7, seg=14)
    for k in range(3):
        a = k * 2 * math.pi / 3
        g["Iron"].obox(hx + 0.75 * math.cos(a), hy + 0.75 * math.sin(a), 1.1, 0.16, 0.16, 1.9, rx=0.15 * math.sin(a), ry=-0.15 * math.cos(a))
    coal_bed(g, hx, hy, 2.55, 1.4, 1.4, size=0.5)
    C(hx, hy, 1.4, 2.2, 2.2, 2.6)
    # 담금질 통(쇠 테 두른 나무 통 + 물)
    qx, qy = 11.5, -4.5
    g["Wood"].box(qx, qy, 1.0, 4.6, 1.8, 1.6)
    for x in (qx - 2.2, qx + 2.2):
        g["Iron"].box(x, qy, 1.0, 0.15, 1.9, 1.7)
    g["Iron"].box(qx, qy, 1.55, 4.7, 1.9, 0.12)
    g["Glass"].box(qx, qy, 1.72, 4.3, 1.5, 0.08)
    C(qx, qy, 1.0, 4.7, 1.9, 1.8)
    # 장작 헛간(뒤 오른): 기둥 넷 · 함석 지붕 + 눈 · 세 줄 장작
    x0, x1, y0, y1 = 8.0, 14.5, 5.2, 7.8
    for x in (x0, x1):
        for y in (y0, y1):
            g["Timber"].box(x, y, 2.4 if y < y1 else 2.8, 0.3, 0.3, 4.8 if y < y1 else 5.6)
    g["RoofMetal"].obox((x0 + x1) / 2, (y0 + y1) / 2, 5.3, x1 - x0 + 1.0, y1 - y0 + 1.2, 0.2, rx=-0.15)
    g["SnowCap"].obox((x0 + x1) / 2, (y0 + y1) / 2 + 0.05, 5.5, x1 - x0 + 0.6, y1 - y0 + 0.8, 0.25, rx=-0.15)
    for r_ in range(3):
        for k in range(8):
            g["Timber" if (k + r_) % 2 else "Wood"].hcyl(x0 + 0.5 + k * 0.78, (y0 + y1) / 2, 0.55 + r_ * 0.7, 0.36, y1 - y0 - 0.2, axis="y", seg=8)
    C((x0 + x1) / 2, (y0 + y1) / 2, 1.3, x1 - x0, y1 - y0, 2.4)
    # 간판(앞 왼 모서리) + 등 기둥(뒷문 길 옆)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: anvil_icon(q, x - 0.2, y, z - 0.35, s=0.42, face=f))
    g["Iron"].box(-1.2, -5.5, 2.8, 0.25, 0.25, 5.6)
    g["Iron"].box(-0.6, -5.5, 5.5, 1.4, 0.15, 0.15)
    lantern(g, 0.0, -5.5, 5.4, 4.3)
    lamp_snow(g, 0.0, -5.5, 4.3)
    C(-1.2, -5.5, 2.8, 0.5, 0.5, 5.6)
    for k, x in enumerate((-12.0, -7.5, -3.0)):                            # 광석 더미 위 눈
        sphere(g, "SnowCap", (x + 0.2, 4.1, 2.25), 0.9, sub=1)



# ------------------------------------------------------------------ 공용(서비스 건물 둘째 묶음, 2026-10-18 "건물마다 특징이 드러나게")
def front_window(g, x, y_out, y_in, z0, w, h, frame="Iron", cross=True):
    """앞벽 안팎 짝 창"""
    S.window(g, x, y_out, z0, w, h, face="-y", cross=cross, frame=frame)
    S.window(g, x, y_in, z0, w, h, face="+y", cross=cross, sill=False, frame=frame)


def side_shelf(g, xw, y0, y1, z0, h, depth=1.4, levels=4, face=1, mat="Wood"):
    """옆벽(x = xw)에 붙은 선반. face = 방 쪽(+1 이면 +x). 칸 윗면 높이들을 돌려준다"""
    xb = xw + face * depth / 2
    g[mat].box(xw + face * 0.05, (y0 + y1) / 2, z0 + h / 2, 0.1, y1 - y0, h)
    for y in (y0, y1):
        g[mat].box(xb, y, z0 + h / 2, depth, 0.2, h)
    tops = []
    for k in range(levels):
        z = z0 + 0.3 + k * (h - 0.4) / (levels - 1)
        g[mat].box(xb, (y0 + y1) / 2, z, depth, y1 - y0, 0.15)
        tops.append(z + 0.075)
    C(xb, (y0 + y1) / 2, z0 + h / 2, depth, y1 - y0, h)
    return tops


def shell_walls(g, W, D, H, mat, door, front_win=(), side_win=(), back_win=(), back_door=None, frame="Iron", trim="StoneTrim",
                front_drift=True):
    """바닥 돌 판 + 네 벽(안팎 짝 창은 job cut 이 뚫는다) + 밑동 띠·처마 띠·모서리 돌. door = (x0, x1, 높이)"""
    ix0, ix1, iy0, iy1 = -W / 2 + T, W / 2 - T, -D / 2 + T, D / 2 - T
    g["Stone"].box(0, 0, FZ / 2, W + 0.6, D + 0.6, FZ)
    C(0, 0, FZ / 2, W + 0.6, D + 0.6, FZ)
    dx0, dx1, dh = door
    box2(g, mat, -W / 2, dx0, -D / 2, iy0, FZ, H)
    box2(g, mat, dx1, W / 2, -D / 2, iy0, FZ, H)
    box2(g, mat, dx0, dx1, -D / 2, iy0, FZ + dh, H)
    if back_door:
        bx0, bx1, bh = back_door
        box2(g, mat, -W / 2, bx0, iy1, D / 2, FZ, H)
        box2(g, mat, bx1, W / 2, iy1, D / 2, FZ, H)
        box2(g, mat, bx0, bx1, iy1, D / 2, FZ + bh, H)
    else:
        box2(g, mat, -W / 2, W / 2, iy1, D / 2, FZ, H)
    for s in (-1, 1):
        box2(g, mat, *sorted((s * W / 2, s * ix1)), iy0, iy1, FZ, H)
    for x, z0, w, h in front_win:
        front_window(g, x, -D / 2, iy0, z0, w, h, frame=frame)
    for y, z0, w, h in side_win:
        side_window(g, -W / 2, ix0, y, z0, w, h, "-x")
        side_window(g, W / 2, ix1, y, z0, w, h, "+x")
    for x, z0, w, h in back_win:
        back_window(g, x, D / 2, iy1, z0, w, h)
    # 밑동 띠(문 자리 비움) · 처마 띠 · 모서리 돌
    for a, b in ((-W / 2 - 0.25, dx0 - 0.6), (dx1 + 0.6, W / 2 + 0.25)):
        g[trim].box((a + b) / 2, -D / 2 - 0.1, FZ + 0.45, b - a, 0.3, 0.9)
    if back_door:
        for a, b in ((-W / 2 - 0.25, back_door[0] - 0.4), (back_door[1] + 0.4, W / 2 + 0.25)):
            g[trim].box((a + b) / 2, D / 2 + 0.1, FZ + 0.45, b - a, 0.3, 0.9)
    else:
        g[trim].box(0, D / 2 + 0.1, FZ + 0.45, W + 0.5, 0.3, 0.9)
    for s in (-1, 1):
        g[trim].box(s * (W / 2 + 0.1), 0, FZ + 0.45, 0.3, D + 0.5, 0.9)
    for y0, y1, x0, x1 in ((-D / 2 - 0.4, -D / 2 + 0.4, -W / 2 - 0.4, W / 2 + 0.4), (D / 2 - 0.4, D / 2 + 0.4, -W / 2 - 0.4, W / 2 + 0.4),
                           (-D / 2 + 0.4, D / 2 - 0.4, -W / 2 - 0.4, -W / 2 + 0.4), (-D / 2 + 0.4, D / 2 - 0.4, W / 2 - 0.4, W / 2 + 0.4)):
        g[trim].box((x0 + x1) / 2, (y0 + y1) / 2, H - 0.3, x1 - x0, y1 - y0, 0.7)
    quoins(g, W, D, FZ, H - 0.8)
    # 벽 밑 눈 더미: 앞(문 길 비움) · 뒤(뒷문 비움). 옆은 길과 가까워 두지 않는다
    for a_, b_ in ((-W / 2, dx0 - 1.0), (dx1 + 1.0, W / 2)) if front_drift else ():     # 좁은 구역 가게는 앞 모서리가 길 여유에 걸려 뺀다
        drift(g, a_, b_, -D / 2, -1)
    if back_door:
        for a_, b_ in ((-W / 2, back_door[0] - 0.6), (back_door[1] + 0.6, W / 2)):
            drift(g, a_, b_, D / 2, 1)
    else:
        drift(g, -W / 2, W / 2, D / 2, 1)
    return ix0, ix1, iy0, iy1


def wall_lamp(g, x, y, z, face=-1):
    """문 옆 벽 등(쇠 팔 + 매단 등). face = 벽 바깥쪽(-1 앞 -y)"""
    g["Iron"].box(x, y + face * 0.7, z + 1.2, 0.15, 1.4, 0.15)
    lantern(g, x, y + face * 1.3, z + 1.2, z)
    lamp_snow(g, x, y + face * 1.3, z)


def door_frame(g, x0, x1, y, z1, mat="StoneTrim"):
    """앞 문 둘레 돌 테(문틀) — 겉"""
    for x in (x0 - 0.35, x1 + 0.35):
        g[mat].box(x, y - 0.15, (FZ + z1) / 2, 0.7, 0.5, z1 - FZ)
    g[mat].box((x0 + x1) / 2, y - 0.15, z1 + 0.35, x1 - x0 + 1.4, 0.5, 0.7)
    snow(g, (x0 + x1) / 2, y - 0.17, z1 + 0.7, x1 - x0 + 1.3, 0.45, t=0.14)


def hanging_sign(g, x, y, z, icon, board="Timber"):
    """앞벽에 붙인 간판 판(양옆 놋쇠 테) + 그림. y = 앞벽 겉면"""
    g[board].box(x, y - 0.2, z, 5.4, 0.3, 2.6)
    for zz in (z - 1.35, z + 1.35):
        g["Brass"].box(x, y - 0.32, zz, 5.6, 0.2, 0.18)
    for xx in (x - 2.75, x + 2.75):
        g["Brass"].box(xx, y - 0.32, z, 0.18, 0.2, 2.8)
    icon(g, x, y - 0.35, z - 1.0, -1)
    snow(g, x, y - 0.26, z + 1.44, 5.5, 0.4, t=0.14)


def poly_disc(n, r, cx, cz, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * k / n), cz + r * math.sin(a0 + 2 * math.pi * k / n)) for k in range(n)]


# ---- 간판 그림(xz 평면, 판 앞면 y 에서 face 쪽으로 0.2) — z 는 그림 아래 끝
def _yy(y, face):
    return (y - 0.2, y) if face < 0 else (y, y + 0.2)


def rune_icon(g, x, y, z, face=-1):
    y0, y1 = _yy(y, face)
    prism_xz(g, "DarkStone", [(x, z), (x + 1.0, z + 1.0), (x, z + 2.0), (x - 1.0, z + 1.0)], y0, y1)
    yf = (y0 + y1) / 2 + face * 0.11
    g["GlowTeal"].box(x, yf, z + 1.0, 0.16, 0.06, 1.2)
    g["GlowTeal"].obox(x + 0.22, yf, z + 1.25, 0.14, 0.06, 0.6, ry=0.7)
    g["GlowTeal"].obox(x - 0.22, yf, z + 0.75, 0.14, 0.06, 0.6, ry=0.7)


def flask_icon(g, x, y, z, face=-1):
    y0, y1 = _yy(y, face)
    prism_xz(g, "Glass", poly_disc(12, 0.85, x, z + 0.85), y0, y1)
    prism_xz(g, "SignTeal", [(x - 0.8, z + 0.65), (x + 0.8, z + 0.65), (x + 0.6, z + 0.25), (x, z + 0.02), (x - 0.6, z + 0.25)],
             y0 + face * 0.04, y1 + face * 0.04)
    prism_xz(g, "Glass", [(x - 0.25, z + 1.6), (x + 0.25, z + 1.6), (x + 0.25, z + 2.2), (x - 0.25, z + 2.2)], y0, y1)
    prism_xz(g, "Wood", [(x - 0.3, z + 2.2), (x + 0.3, z + 2.2), (x + 0.3, z + 2.5), (x - 0.3, z + 2.5)], y0, y1)


def sack_icon(g, x, y, z, face=-1):
    y0, y1 = _yy(y, face)
    prism_xz(g, "Canvas", [(x - 0.9, z + 0.1), (x + 0.9, z + 0.1), (x + 1.05, z + 0.8), (x + 0.6, z + 1.6), (x - 0.6, z + 1.6), (x - 1.05, z + 0.8)], y0, y1)
    prism_xz(g, "Canvas", [(x - 0.35, z + 1.6), (x + 0.35, z + 1.6), (x + 0.55, z + 2.2), (x - 0.55, z + 2.2)], y0, y1)
    yf = (y0 + y1) / 2 + face * 0.11
    g["Leather"].box(x, yf, z + 1.62, 0.9, 0.06, 0.16)
    S.gear(g, "Brass", x, yf + face * 0.02, z + 0.8, 0.4, 8, 0.06)


def coin_icon(g, x, y, z, face=-1):
    yf = y + face * 0.1
    S.gear(g, "Brass", x, yf, z + 1.0, 1.0, 16, 0.2)
    g["SignGold"].hcyl(x, yf + face * 0.08, z + 1.0, 0.7, 0.08, axis="y", seg=16)


def heart_icon(g, x, y, z, face=-1, s=1.0):
    """심장 + 톱니(감정 열기로 고치는 슈네라이히 병원). s = 크기 배율"""
    yf = y + face * 0.1
    S.gear(g, "Brass", x, yf, z + 1.05 * s, 1.05 * s, 14, 0.18)
    y0, y1 = (yf + face * 0.08 - 0.1, yf + face * 0.08 + 0.1)
    for dx in (-0.3, 0.3):
        prism_xz(g, "SignRed", poly_disc(10, 0.36 * s, x + dx * s, z + 1.25 * s), y0, y1)
    prism_xz(g, "SignRed", [(x - 0.64 * s, z + 1.15 * s), (x + 0.64 * s, z + 1.15 * s), (x, z + 0.45 * s)], y0, y1)


def mug_icon(g, x, y, z, face=-1):
    y0, y1 = _yy(y, face)
    prism_xz(g, "Wood", [(x - 0.7, z + 0.1), (x + 0.5, z + 0.1), (x + 0.5, z + 1.6), (x - 0.7, z + 1.6)], y0, y1)
    prism_xz(g, "Canvas", [(x - 0.8, z + 1.55), (x + 0.6, z + 1.55), (x + 0.45, z + 2.0), (x - 0.65, z + 2.0)], y0, y1)
    for zz in (z + 0.4, z + 1.2):
        prism_xz(g, "Brass", [(x - 0.72, zz), (x + 0.52, zz), (x + 0.52, zz + 0.14), (x - 0.72, zz + 0.14)], y0 + face * 0.03, y1 + face * 0.03)
    for zz, h in ((z + 1.25, 0.2), (z + 0.45, 0.2)):
        prism_xz(g, "Wood", [(x + 0.5, zz - h), (x + 1.0, zz - h), (x + 1.0, zz), (x + 0.5, zz)], y0, y1)
    prism_xz(g, "Wood", [(x + 0.8, z + 0.45), (x + 1.0, z + 0.45), (x + 1.0, z + 1.25), (x + 0.8, z + 1.25)], y0, y1)


def bottle_lite(g, x, y, z0, liquid, r=0.18, h=0.6):
    """선반용 가벼운 병(유리 삼각형 한도 1만 — 병이 수백 개라 면을 줄인다)"""
    g["Glass"].cyl(x, y, z0, r, r, h, seg=6)
    g[liquid].cyl(x, y, z0 + 0.02, r * 0.8, r * 0.8, h * 0.6, seg=6)
    g["Glass"].cyl(x, y, z0 + h, r * 0.45, r * 0.45, h * 0.35, seg=5)
    g["Wood"].box(x, y, z0 + h * 1.4, r * 0.8, r * 0.8, 0.08)


def bottle_row(g, x0, x1, y, z, seed=0, liquids=("SignRed", "SignTeal", "SignPurple", "Verdigris", "SignGold", "GlowTeal")):
    import random
    rnd = random.Random(seed)
    x = x0 + 0.3
    while x < x1 - 0.2:
        r = rnd.uniform(0.13, 0.22)
        bottle_lite(g, x, y, z, rnd.choice(liquids), r=r, h=rnd.uniform(0.45, 0.8))
        x += 2 * r + rnd.uniform(0.08, 0.2)


def bottle_col(g, x, y0, y1, z, seed=0, liquids=("SignRed", "SignTeal", "SignPurple", "Verdigris", "SignGold", "GlowTeal")):
    import random
    rnd = random.Random(seed)
    y = y0 + 0.3
    while y < y1 - 0.2:
        r = rnd.uniform(0.13, 0.22)
        bottle_lite(g, x, y, z, rnd.choice(liquids), r=r, h=rnd.uniform(0.45, 0.8))
        y += 2 * r + rnd.uniform(0.08, 0.2)


def goods_row(g, x0, x1, y, z, seed=0, depth=0.9, k_=1.5):
    """잡화 선반 물건: 상자·통·병·자루가 섞인 줄. k_ = 크기 배율(점검: 1 배는 칸 높이에 비해 작아 선반이 비어 보였다)"""
    import random
    rnd = random.Random(seed)
    from mathutils import Matrix
    import hanok_lib as L_
    if k_ != 1.0:
        L_.transformed(g, Matrix.Translation((x0, y, z)) @ Matrix.Scale(k_, 4) @ Matrix.Translation((-x0, -y, -z)),
                       lambda q: goods_row(q, x0, x0 + (x1 - x0) / k_, y, z, seed, depth, 1.0))
        return
    x = x0 + 0.2
    while x < x1 - 0.3:
        k = rnd.randint(0, 4)
        if k == 0:
            s = rnd.uniform(0.6, 0.9)
            g["Wood"].box(x + s / 2, y, z + s / 2, s, depth * 0.8, s)
            x += s + 0.1
        elif k == 1:
            r = rnd.uniform(0.25, 0.35)
            g["Copper" if rnd.random() < 0.5 else "Steel"].cyl(x + r, y, z, r, r, rnd.uniform(0.5, 0.8), seg=10)
            x += 2 * r + 0.1
        elif k == 2:
            bottle(g, x + 0.2, y, z, rnd.choice(("SignGold", "Verdigris", "SignRed")), r=0.18, h=0.6)
            x += 0.5
        elif k == 3:
            g["Canvas"].obox(x + 0.4, y, z + 0.35, 0.8, depth * 0.7, 0.7, rz=rnd.uniform(-0.2, 0.2))
            x += 0.9
        else:
            g["Brass"].cyl(x + 0.3, y, z, 0.3, 0.22, 0.45, seg=10)
            x += 0.7


def goods_col(g, x, y0, y1, z, seed=0, depth=0.9, k_=1.5):
    import random
    rnd = random.Random(seed)
    from mathutils import Matrix
    import hanok_lib as L_
    if k_ != 1.0:
        L_.transformed(g, Matrix.Translation((x, y0, z)) @ Matrix.Scale(k_, 4) @ Matrix.Translation((-x, -y0, -z)),
                       lambda q: goods_col(q, x, y0, y0 + (y1 - y0) / k_, z, seed, depth, 1.0))
        return
    y = y0 + 0.2
    while y < y1 - 0.3:
        k = rnd.randint(0, 3)
        if k == 0:
            s = rnd.uniform(0.6, 0.9)
            g["Wood"].box(x, y + s / 2, z + s / 2, depth * 0.8, s, s)
            y += s + 0.1
        elif k == 1:
            r = rnd.uniform(0.25, 0.35)
            g["Copper" if rnd.random() < 0.5 else "Steel"].cyl(x, y + r, z, r, r, rnd.uniform(0.5, 0.8), seg=10)
            y += 2 * r + 0.1
        elif k == 2:
            bottle(g, x, y + 0.2, z, rnd.choice(("SignGold", "Verdigris", "SignRed")), r=0.18, h=0.6)
            y += 0.5
        else:
            g["Canvas"].obox(x, y + 0.4, z + 0.35, depth * 0.7, 0.8, 0.7, rz=rnd.uniform(-0.2, 0.2))
            y += 0.9


def barrel(g, x, y, z0=FZ, r=0.85, h=2.2, coll=True):
    g["Wood"].cyl(x, y, z0, r, r, h, seg=14)
    for z in (z0 + 0.35, z0 + h - 0.45):
        g["Iron"].cyl(x, y, z, r + 0.03, r + 0.03, 0.12, seg=14)
    g["Timber"].cyl(x, y, z0 + h, r * 0.92, r * 0.92, 0.05, seg=14)
    if coll:
        C(x, y, z0 + h / 2, 2 * r, 2 * r, h)


def herb_bundle(g, x, y, z, mat="Felt"):
    g["Canvas"].cyl(x, y, z - 0.2, 0.05, 0.05, 0.4, seg=4)
    g[mat].cyl(x, y, z - 1.3, 0.05, 0.3, 1.1, seg=6)


# ------------------------------------------------------------------ 강화소(룬)
W_SH, D_SH, H_SH = 26.0, 26.0, 14.0
SHOP_FRONT = ((-8.75, 3.5, 4.5, 5.0), (8.75, 3.5, 4.5, 5.0))
SHOP_SIDE = ((-7.25, 3.5, 4.5, 5.0),)
SHOP_BACK = ((-6.0, 10.0, 3.0, 2.8), (6.0, 10.0, 3.0, 2.8))        # 뒷벽이 민짜로 보여 뒤 선반 위 높은 창(2026-10-18 점검)


def svc_enhance(g):
    """강화소: 아래 검은 돌·위 벽돌, 가파른 네모뿔 지붕 + 청록 수정 꼭지, 룬 돌 간판. 안: 룬 새기는 돌 작업대(새김 팔·확대경),
    바닥 룬 고리(놋쇠 + 청록), 왼 벽 룬 받침 셋(떠 있는 룬 돌), 뒤 룬 칸 선반, 오른 선반(두루마리·책) + 쓰고 남은 돌덩이 통(사양: 쓴 룬은 돌덩이)"""
    W, D, H = W_SH, D_SH, H_SH
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, H, "Brick", (-3.0, 3.0, 9.0), SHOP_FRONT, SHOP_SIDE, back_win=SHOP_BACK, front_drift=False)
    # 아래 검은 돌 옷(창 밑까지)
    for (x0, x1, y0, y1) in ((-W / 2 - 0.2, -3.6, -D / 2 - 0.2, -D / 2), (3.6, W / 2 + 0.2, -D / 2 - 0.2, -D / 2), (-W / 2 - 0.2, W / 2 + 0.2, D / 2, D / 2 + 0.2),
                             (-W / 2 - 0.2, -W / 2, -D / 2, D / 2), (W / 2, W / 2 + 0.2, -D / 2, D / 2)):
        g["DarkStone"].box((x0 + x1) / 2, (y0 + y1) / 2, FZ + 1.5, x1 - x0, y1 - y0, 2.2)
    # 문: 검은 돌 테 + 룬 쐐기돌 + 등 둘
    door_frame(g, -3.0, 3.0, -D / 2, FZ + 9.0, mat="DarkStone")
    g["GlowTeal"].box(0, -D / 2 - 0.45, FZ + 9.4, 0.5, 0.1, 0.5)
    hanging_sign(g, 0, -D / 2, FZ + 11.4, rune_icon, board="Timber")
    for x in (-4.6, 4.6):
        wall_lamp(g, x, -D / 2, FZ + 6.5)
    # 지붕: 가파른 네모뿔 + 눈 + 청록 수정 꼭지(팔면) + 놋쇠 받침
    S.pyramid(g, "RoofMetal", 0, 0, H, W + 1.2, D + 1.2, 11.0)
    S.pyramid(g, "SnowCap", 0, 0, H, W + 1.2, D + 1.2, 11.0, frac=0.55, lift=0.35)
    g["Brass"].cyl(0, 0, H + 10.6, 0.7, 0.5, 0.8, seg=8)
    g["GlowTeal"].add_mesh([(0, 0, H + 13.6), (0.7, 0, H + 12.2), (0, 0.7, H + 12.2), (-0.7, 0, H + 12.2), (0, -0.7, H + 12.2), (0, 0, H + 11.3)],
                           [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1), (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)])
    # 안: 들보 + 놋쇠 고리 등(청록 수정 셋)
    for y in (-6.0, 6.0):
        g["Timber"].box(0, y, H - 0.5, W - 2 * T, 0.5, 0.5)
    g["Iron"].cyl(0, 0, 9.4, 0.06, 0.06, H - 9.4, seg=6)
    S.ring(g, "Brass", 0, 0, 9.2, 2.0, 2.3, 0.2)
    for k in range(3):
        a = k * 2 * math.pi / 3
        g["GlowTeal"].box(2.15 * math.cos(a), 2.15 * math.sin(a), 8.8, 0.3, 0.3, 0.6)
        g["LampPt"].box(2.15 * math.cos(a), 2.15 * math.sin(a), 8.6, 0.3, 0.3, 0.3)
    # 바닥 룬 고리(평평한 테 — 걸을 수 있다)
    S.ring(g, "Brass", 0, -3.0, FZ + 0.02, 4.6, 5.0, 0.05, n=32)
    S.ring(g, "Brass", 0, -3.0, FZ + 0.02, 3.0, 3.2, 0.05, n=24)
    for k in range(8):
        a = k * math.pi / 4
        g["GlowTeal"].obox(4.0 * math.cos(a), -3.0 + 4.0 * math.sin(a), FZ + 0.04, 0.9, 0.18, 0.04, rz=a + math.pi / 2)
    # 룬 새기는 작업대(x -4..4, y 4..7, 높이 3.5): 돌 판 · 놋쇠 새김 팔 · 확대경 · 룬 돌
    g["DarkStone"].box(0, 5.5, (FZ + 3.1) / 2, 7.4, 2.6, 3.1 - FZ)
    g["StoneTrim"].box(0, 5.5, 3.3, 8.2, 3.2, 0.4)
    for x in (-3.0, 0.0, 3.0):
        g["GlowTeal"].box(x, 4.18, 2.0, 0.6, 0.06, 0.6)
    C(0, 5.5, (FZ + 3.5) / 2, 8.2, 3.2, 3.5 - FZ)
    from mathutils import Matrix as M_
    L_.transformed(g, M_.Translation((0.3, 5.5, 3.5)) @ M_.Scale(1.3, 4) @ M_.Translation((-0.3, -5.5, -3.5)),
                   lambda q: engraving_machine(q, 0.3, 5.5, 3.5))                 # 작업대에 비해 작아 1.3 배
    NPC(0.0, 9.0, FZ, 0.0)
    # 뒤 룬 칸 선반(x -9..9): 칸마다 룬 돌
    g["Wood"].box(0, iy1 - 0.75, FZ + 4.5, 18.0, 1.5, 9.0)
    for r in range(4):
        z = FZ + 1.2 + r * 2.1
        for k in range(7):
            x = -7.7 + k * 2.57
            g["Soot"].box(x, iy1 - 1.52, z + 0.8, 2.1, 0.06, 1.7)
            if (r + k) % 3:
                g["DarkStone"].box(x, iy1 - 1.7, z + 0.45, 0.9, 0.3, 0.9)
                g["GlowTeal"].box(x, iy1 - 1.87, z + 0.45, 0.35, 0.04, 0.5)
    C(0, iy1 - 0.75, FZ + 4.5, 18.0, 1.5, 9.0)
    # 왼 벽 룬 받침 셋: 돌 기둥 + 놋쇠 받침 + 떠 있는 룬 돌(빛)
    for y in (-4.0, 1.0, 6.0):
        g["StoneTrim"].box(ix0 + 1.0, y, FZ + 1.6, 1.6, 1.6, 3.2)
        g["Brass"].box(ix0 + 1.0, y, FZ + 3.3, 1.9, 1.9, 0.2)
        g["DarkStone"].obox(ix0 + 1.0, y, FZ + 4.4, 0.7, 0.9, 1.1, rz=0.4)
        g["GlowTeal"].obox(ix0 + 1.0, y, FZ + 4.4, 0.75, 0.3, 0.5, rz=0.4)
        g["LampPt"].box(ix0 + 1.6, y, FZ + 4.4, 0.3, 0.3, 0.3)
        C(ix0 + 1.0, y, FZ + 1.7, 1.9, 1.9, 3.4)
    # 오른 선반(두루마리·책) + 앞 구석 쓰고 남은 돌덩이 통
    tops = side_shelf(g, ix1, -3.0, 9.0, FZ, 8.0, depth=1.5, levels=4, face=-1)
    for k, z in enumerate(tops):
        for j in range(8):
            y = -2.3 + j * 1.4
            if (j + k) % 2:
                g["Canvas"].hcyl(ix1 - 0.7, y, z + 0.25, 0.22, 1.1, axis="x", seg=8)
            else:
                g[("Leather", "SignTeal", "Banner", "SignPurple")[(j + k) % 4]].box(ix1 - 0.7, y, z + 0.45, 1.0, 0.35, 0.9)
    g["Wood"].box(ix1 - 1.5, -9.5, FZ + 1.0, 2.4, 2.4, 2.0)
    for k, (dx, dy) in enumerate(((-0.5, -0.4), (0.4, 0.3), (-0.2, 0.5), (0.5, -0.5), (0.0, 0.0))):
        g["Stone"].obox(ix1 - 1.5 + dx, -9.5 + dy, FZ + 2.15, 0.6, 0.5, 0.4, rz=k)
    C(ix1 - 1.5, -9.5, FZ + 1.1, 2.4, 2.4, 2.2)
    DOORWAY(-3.0, 3.0, -D / 2 - 0.2, iy0, FZ, 9.0)
    CLEAR(-2.8, 2.8, iy0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-4.8, 4.8, -6.0, 3.8, FZ + 0.15, FZ + 5.4)


# ------------------------------------------------------------------ 물약상점
def distiller(g, x, y):
    """옆벽 밖 구리 증류 탑: 보일러 통 · 꼬인 관 · 유리 구 셋 · 김"""
    S.banded_cyl(g, "Copper", x, y, FZ, 1.3, 7.0, every=2.4)
    g["Copper"].cyl(x, y, FZ + 7.0, 1.3, 0.4, 1.2, seg=14)
    for k in range(5):
        z = FZ + 2.0 + k * 1.2
        S.ring(g, "Copper", x, y, z, 1.45, 1.6, 0.25, n=16)
    g["Copper"].cyl(x, y, FZ + 8.2, 0.28, 0.28, 0.7, seg=10)                     # 목
    sphere(g, "Glass", (x, y, FZ + 9.55), 0.8, sub=2)
    sphere(g, "Verdigris", (x, y, FZ + 9.3), 0.55, sub=1)
    for dy, z in ((-2.0, 3.0), (2.0, 4.2)):                                 # 옆 구: 통 옆구리 쇠 받침 팔에 얹는다(땅에 닿지 않게 — 길 여유)
        sgn = 1 if dy > 0 else -1
        g["Iron"].obox(x, y + sgn * 1.55, FZ + z - 0.85, 0.3, 1.2, 0.15)
        g["Brass"].cyl(x, y + dy, FZ + z - 0.9, 0.45, 0.25, 0.25, seg=10)
        sphere(g, "Glass", (x, y + dy, FZ + z), 0.65, sub=2)
        sphere(g, "Verdigris", (x, y + dy, FZ + z - 0.2), 0.45, sub=1)
        S.pipe(g, [(x, y + sgn * 1.25, FZ + z + 0.6), (x, y + dy, FZ + z + 0.6)], 0.2, mat="Copper")
    S.pipe(g, [(x - 1.3, y, FZ + 5.5), (x - 2.0, y, FZ + 5.5)], 0.3, mat="Copper")
    S.vent(g, x, y, FZ + 10.6)
    C(x, y, FZ + 3.5, 3.0, 6.4, 7.0)


def svc_potion(g):
    """물약상점: 벽돌 + 녹청 덧창·문틀·차양, 앞벽과 나란한 박공 지붕 + 구리 환기탑, 오른 벽 밖 구리 증류 탑, 둥근 병 간판.
    안: 큰 솥(진짜 불)·끓는 녹청 물약, 뒤 벽 색색 병 선반, 옆 선반(병·단지), 천장 마른 약초 다발, 카운터(놋쇠 저울·절구·병)"""
    W, D, H = W_SH, D_SH, H_SH
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, H, "Brick", (-3.0, 3.0, 9.0), SHOP_FRONT, SHOP_SIDE, back_win=SHOP_BACK, front_drift=False)
    for cx in (-8.75, 8.75):
        for s in (-1, 1):
            g["PaintGreen"].box(cx + s * 3.15, -D / 2 - 0.15, 6.0, 1.3, 0.2, 5.4)
            for z in (4.6, 6.0, 7.4):
                g["Wood"].box(cx + s * 3.15, -D / 2 - 0.28, z, 1.1, 0.06, 0.18)
    door_frame(g, -3.0, 3.0, -D / 2, FZ + 9.0, mat="PaintGreen")
    g["PaintGreen"].obox(0, -D / 2 - 1.3, FZ + 10.4, 8.0, 2.6, 0.2, rx=0.3)       # 차양: 바깥 끝이 낮게
    g["SnowCap"].obox(0, -D / 2 - 1.1, FZ + 10.62, 7.6, 2.0, 0.14, rx=0.3)
    for x in (-3.8, 3.8):
        g["Iron"].obox(x, -D / 2 - 0.8, FZ + 9.6, 0.12, 1.8, 0.12, rx=0.9)
    hanging_sign(g, 0, -D / 2, FZ + 12.2, flask_icon)
    for x in (-4.6, 4.6):
        wall_lamp(g, x, -D / 2, FZ + 6.5)
    S.roof_gable(g, 0, 0, H, D + 0.6, W + 0.6, 7.0, along="x")
    g["Copper"].box(0, 0, H + 7.6, 2.4, 2.4, 1.6)
    S.pyramid(g, "Verdigris", 0, 0, H + 8.4, 3.0, 3.0, 1.6)
    S.vent(g, 0, 0, H + 10.4)
    distiller(g, W / 2 + 1.7, 2.0)
    for y in (-6.0, 0.0, 6.0):
        g["Timber"].box(0, y, H - 0.5, W - 2 * T, 0.5, 0.5)
        for k in range(7):
            herb_bundle(g, -9.0 + k * 3.0, y, H - 0.75, mat=("Felt", "PaintGreen", "Wood")[k % 3])
    for x, y in ((-5.0, -3.0), (5.0, -3.0), (0.0, 3.0)):
        lantern(g, x, y, H - 0.75, 9.6)
    g["PaintGreen"].box(0, 5.25, (FZ + 3.2) / 2, 11.6, 2.2, 3.2 - FZ)
    g["Wood"].box(0, 5.25, 3.35, 12.2, 2.8, 0.3)
    for x in (-5.0, -1.7, 1.7, 5.0):
        g["Brass"].box(x, 4.12, 1.8, 0.2, 0.06, 2.6)
    C(0, 5.25, (FZ + 3.5) / 2, 12.2, 2.8, 3.5 - FZ)
    balance_scale(g, -3.5, 5.3, 3.5)
    mortar(g, 0.4, 5.4, 3.5)
    bottle_row(g, 2.0, 5.5, 5.3, 3.5, seed=5)
    NPC(0.0, 8.5, FZ, 0.0)
    tops = shelf_unit(g, -6.0, 9.0, iy1, FZ, 9.0, depth=1.5, levels=5, face=-1)
    for k, z in enumerate(tops[1:]):
        bottle_row(g, -5.8, 8.8, iy1 - 0.75, z, seed=10 + k)
    cx, cy = ix0 + 2.0, iy1 - 2.0
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.5
        g["Iron"].box(cx + 1.4 * math.cos(a), cy + 1.4 * math.sin(a), FZ + 0.8, 0.3, 0.3, 1.6)
    g["Iron"].cyl(cx, cy, FZ + 1.4, 1.2, 1.8, 1.8, seg=16)
    S.ring(g, "Iron", cx, cy, FZ + 3.1, 1.75, 2.0, 0.25, n=18)
    g["Verdigris"].cyl(cx, cy, FZ + 3.0, 1.65, 1.65, 0.12, seg=16)
    for k, (dx, dy) in enumerate(((0.4, 0.3), (-0.5, -0.2), (0.1, -0.6))):
        sphere(g, "GlowTeal", (cx + dx, cy + dy, FZ + 3.15), 0.18 + k * 0.04, sub=1)
    coal_bed(g, cx, cy, FZ + 0.1, 1.6, 1.6, size=0.45)
    g["Wood"].obox(cx + 0.6, cy - 0.4, FZ + 4.0, 0.14, 0.14, 2.6, ry=0.35)
    S.vent(g, cx, cy, FZ + 3.4)
    C(cx, cy, FZ + 1.7, 4.0, 4.0, 3.4)
    tops = side_shelf(g, ix1, -3.0, 9.0, FZ, 8.0, depth=1.5, levels=4, face=-1)
    for k, z in enumerate(tops):
        bottle_col(g, ix1 - 0.75, -2.8, 8.8, z, seed=20 + k)
    tops = side_shelf(g, ix0, -3.0, 5.0, FZ, 8.0, depth=1.5, levels=4, face=1)
    for k, z in enumerate(tops):
        for j in range(5):
            y = -2.2 + j * 1.5
            g[("Copper", "Stone", "Verdigris")[(j + k) % 3]].cyl(ix0 + 0.75, y, z, 0.42, 0.36, 0.8, seg=10)
            g["Wood"].cyl(ix0 + 0.75, y, z + 0.8, 0.3, 0.3, 0.12, seg=8)
    DOORWAY(-3.0, 3.0, -D / 2 - 0.2, iy0, FZ, 9.0)
    CLEAR(-2.8, 2.8, iy0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-4.8, 4.8, -6.0, 3.8, FZ + 0.15, FZ + 5.4)


# ------------------------------------------------------------------ 잡화점
def svc_general(g):
    """잡화점: 앞면 나무 판자 옷 · 줄무늬 천 차양 · 문 양옆 바깥 물건(통·상자·자루) · 자루 간판 · 앞 박공 + 다락 도르래 들보.
    안: 물건 가득한 선반(뒤·옆), 놋쇠 금전 등록기 카운터, 밀가루 자루 더미, 매단 등·냄비, 앞 구석 상자 더미"""
    W, D, H = W_SH, D_SH, H_SH
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, H, "Brick", (-3.0, 3.0, 9.0), SHOP_FRONT, SHOP_SIDE, back_win=SHOP_BACK)
    fy = -D / 2 - 0.12
    for x0, x1 in ((-W / 2, -11.6), (-5.9, -3.6), (3.6, 5.9), (11.6, W / 2)):
        g["Wood"].box((x0 + x1) / 2, fy, FZ + 6.5, x1 - x0, 0.24, 12.2)
    for x0, x1, z0, z1 in ((-11.6, -5.9, FZ + 0.9, 3.0), (5.9, 11.6, FZ + 0.9, 3.0), (-11.6, -5.9, 9.0, H - 0.6), (5.9, 11.6, 9.0, H - 0.6),
                           (-3.6, 3.6, FZ + 9.6, H - 0.6)):
        g["Wood"].box((x0 + x1) / 2, fy, (z0 + z1) / 2, x1 - x0, 0.24, z1 - z0)
    for x in (-W / 2 + 0.2, -11.6, -5.9, -3.6, 3.6, 5.9, 11.6, W / 2 - 0.2):
        g["Timber"].box(x, fy - 0.1, FZ + 6.5, 0.35, 0.2, 12.2)
    for k in range(12):
        x = -11.5 + k * 2.09
        g["SignBlue" if k % 2 else "Canvas"].obox(x, -D / 2 - 1.5, FZ + 9.7, 2.09, 3.0, 0.15, rx=0.32)     # 바깥 끝이 낮게
    g["Canvas"].box(0, -D / 2 - 2.95, FZ + 9.1, 25.0, 0.1, 0.6)
    g["SnowCap"].obox(0, -D / 2 - 1.26, FZ + 9.93, 24.4, 2.3, 0.14, rx=0.32)
    for x in (-11.0, 11.0):
        g["Iron"].obox(x, -D / 2 - 1.0, FZ + 9.0, 0.12, 2.2, 0.12, rx=0.9)
    hanging_sign(g, 0, -D / 2 - 0.25, FZ + 11.6, sack_icon)
    for s in (-1, 1):
        barrel(g, s * 5.0, -D / 2 - 1.2, 0.0, r=0.75, h=1.9)
        g["SnowCap"].cyl(s * 5.0, -D / 2 - 1.2, 1.95, 0.7, 0.62, 0.14, seg=14)
        crate(g, s * 8.0, -D / 2 - 1.3, 0.0, 1.8)
        crate(g, s * 8.2, -D / 2 - 1.3, 1.8, 1.4, rz=0.3)
        g["SnowCap"].obox(s * 8.2, -D / 2 - 1.3, 3.27, 1.3, 1.3, 0.14, rz=0.3)
        C(s * 8.0, -D / 2 - 1.3, 1.6, 2.0, 2.0, 3.2)
        g["Canvas"].obox(s * 10.3, -D / 2 - 1.1, 0.5, 1.2, 0.9, 1.0, rz=0.2)
        g["Canvas"].obox(s * 10.6, -D / 2 - 1.2, 1.3, 1.0, 0.8, 0.8, rz=-0.3)
    for x in (-4.6, 4.6):
        wall_lamp(g, x, -D / 2 - 0.25, FZ + 6.8)
    S.roof_gable(g, 0, 0, H, W + 0.6, D + 0.6, 7.5, along="y")
    g["Wood"].box(0, -D / 2 - 0.25, H + 2.4, 2.6, 0.2, 3.0)
    g["Timber"].box(0, -D / 2 - 1.6, H + 4.4, 0.5, 3.4, 0.5)
    g["Iron"].hcyl(0, -D / 2 - 3.1, H + 4.0, 0.35, 0.3, axis="x", seg=10)
    g["Canvas"].cyl(0, -D / 2 - 3.1, H + 0.6, 0.05, 0.05, 3.4, seg=4)
    g["Iron"].obox(0, -D / 2 - 3.1, H + 0.4, 0.1, 0.4, 0.4, rx=0.5)
    for y in (-6.0, 0.0, 6.0):
        g["Timber"].box(0, y, H - 0.5, W - 2 * T, 0.5, 0.5)
    for x, y in ((-5.0, -6.0), (5.0, -6.0), (0.0, 0.0)):
        lantern(g, x, y, H - 0.75, 9.4)
    for k, x in enumerate((-9.0, -7.0, 7.0, 9.0)):
        g["Iron"].cyl(x, 6.0, 10.2, 0.05, 0.05, H - 10.95, seg=4)
        g["Copper" if k % 2 else "Iron"].cyl(x, 6.0, 9.4, 0.55, 0.45, 0.8, seg=12)
    g["Timber"].box(0, 5.25, (FZ + 3.2) / 2, 11.6, 2.2, 3.2 - FZ)
    g["Wood"].box(0, 5.25, 3.35, 12.2, 2.8, 0.3)
    for x in (-5.0, -2.5, 0.0, 2.5, 5.0):
        g["Wood"].box(x, 4.12, 1.8, 2.2, 0.06, 2.4)
    C(0, 5.25, (FZ + 3.5) / 2, 12.2, 2.8, 3.5 - FZ)
    cash_register(g, 3.3, 5.3, 3.5)
    goods_row(g, -5.6, 1.6, 5.3, 3.5, seed=3)
    NPC(0.0, 8.5, FZ, 0.0)
    tops = shelf_unit(g, -9.0, 9.0, iy1, FZ, 9.0, depth=1.5, levels=5, face=-1)
    for k, z in enumerate(tops[1:]):
        goods_row(g, -8.8, 8.8, iy1 - 0.75, z, seed=30 + k)
    for s, xw in ((-1, ix0), (1, ix1)):
        tops = side_shelf(g, xw, -3.0, 9.0, FZ, 8.0, depth=1.5, levels=4, face=-s)
        for k, z in enumerate(tops):
            goods_col(g, xw - s * 0.75, -2.8, 8.8, z, seed=40 + k + (s > 0) * 5)
    for s in (-1, 1):
        crate(g, s * 8.0, iy0 + 2.0, FZ, 2.4)
        crate(g, s * 8.4, iy0 + 2.2, FZ + 2.4, 1.6, rz=0.25)
        barrel(g, s * 10.6, iy0 + 1.6, FZ, r=0.8, h=2.0)
        C(s * 8.0, iy0 + 2.0, FZ + 1.6, 2.6, 2.6, 3.2)
    for k, (x, y, z) in enumerate(((-7.6, 5.0, FZ), (-8.6, 6.0, FZ), (-8.0, 5.4, FZ + 0.9))):
        g["Canvas"].obox(x, y, z + 0.45, 1.2, 0.9, 0.9, rz=k * 0.4)
    C(-8.1, 5.5, FZ + 0.9, 2.4, 2.2, 1.8)
    DOORWAY(-3.0, 3.0, -D / 2 - 0.2, iy0, FZ, 9.0)
    CLEAR(-2.8, 2.8, iy0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-4.8, 4.8, -6.0, 3.8, FZ + 0.15, FZ + 5.4)


# ------------------------------------------------------------------ 은행
def checker_floor(g, x0, x1, y0, y1, sq=3.0, a="Marble", b="DarkStone", z=FZ):
    """체크 무늬 돌바닥(바닥 판 위 0.05 — 걸을 수 있다)"""
    nx, ny = int(round((x1 - x0) / sq)), int(round((y1 - y0) / sq))
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx):
        for j in range(ny):
            g[a if (i + j) % 2 else b].box(x0 + (i + 0.5) * dx, y0 + (j + 0.5) * dy, z + 0.025, dx, dy, 0.05)


def chandelier(g, x, y, ztop, z):
    """놋쇠 샹들리에: 사슬 · 고리 둘 · 등 여섯"""
    g["Iron"].cyl(x, y, z + 0.6, 0.06, 0.06, ztop - z - 0.6, seg=6)
    S.ring(g, "Brass", x, y, z, 1.7, 1.95, 0.18, n=20)
    S.ring(g, "Brass", x, y, z + 0.8, 0.9, 1.1, 0.15, n=16)
    g["Brass"].cyl(x, y, z - 0.4, 0.25, 0.1, 1.4, seg=8)
    for k in range(6):
        a = k * math.pi / 3
        g["Glow"].box(x + 1.82 * math.cos(a), y + 1.82 * math.sin(a), z + 0.45, 0.25, 0.25, 0.5)
    g["LampPt"].box(x, y, z + 0.2, 0.3, 0.3, 0.3)


def bench(g, x, y, z0, length, axis="y", mat="Leather"):
    """긴 걸상(가죽 방석 · 나무 등받이 · 놋쇠 다리). axis = 긴 쪽"""
    if axis == "y":
        g["Wood"].box(x, y, z0 + 1.5, 1.6, length, 0.2)
        g[mat].box(x, y, z0 + 1.7, 1.5, length - 0.1, 0.25)
        for yy in (y - length / 2 + 0.3, y + length / 2 - 0.3):
            for xx in (x - 0.6, x + 0.6):
                g["Brass"].box(xx, yy, z0 + 0.75, 0.15, 0.15, 1.5)
        C(x, y, z0 + 0.95, 1.6, length, 1.9)
    else:
        g["Wood"].box(x, y, z0 + 1.5, length, 1.6, 0.2)
        g[mat].box(x, y, z0 + 1.7, length - 0.1, 1.5, 0.25)
        for xx in (x - length / 2 + 0.3, x + length / 2 - 0.3):
            for yy in (y - 0.6, y + 0.6):
                g["Brass"].box(xx, yy, z0 + 0.75, 0.15, 0.15, 1.5)
        C(x, y, z0 + 0.95, length, 1.6, 1.9)


def potted_plant(g, x, y, z0=FZ, s=1.0):
    g["Brass"].cyl(x, y, z0, 0.7 * s, 0.85 * s, 1.3 * s, seg=12)
    g["Char"].cyl(x, y, z0 + 1.25 * s, 0.75 * s, 0.75 * s, 0.06, seg=12)
    for k, (dx, dy, dz, r) in enumerate(((0, 0, 2.2, 0.9), (0.4, 0.2, 2.9, 0.7), (-0.3, -0.3, 3.4, 0.6))):
        sphere(g, "Felt", (x + dx * s, y + dy * s, z0 + dz * s), r * s, sub=1)
    C(x, y, z0 + 1.2 * s, 1.6 * s, 1.6 * s, 2.4 * s)


def svc_bank(g):
    """은행: 밝은 돌 앞면 · 대리석 붙임기둥 넷 · 삼각 박공(금화 톱니) · 쇠살 창 · 평지붕 난간 + 녹청 둥근 지붕.
    안: 체크 대리석 바닥, 대리석 창구(놋쇠 창살 창 둘), 뒤 벽 둥근 금고 문 + 양옆 대여 금고 서랍 벽, 직원 책상, 대기 걸상, 시세판, 샹들리에"""
    W, D, H = 36.0, 30.0, 16.0
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, H, "StoneTrim", (-5.0, 5.0, 10.0), ((-12.0, 4.0, 6.0, 6.0), (12.0, 4.0, 6.0, 6.0)),
                                     ((-7.0, 5.0, 6.0, 5.0),), back_win=((-11.0, 10.2, 3.0, 4.0), (11.0, 10.2, 3.0, 4.0)), trim="Marble")
    fy = -D / 2
    # 밑동 검은 돌 · 앞면 붙임기둥 넷(대리석) + 머리 · 처마 띠 · 박공(금화 톱니)
    for a, b in ((-W / 2 - 0.2, -5.6), (5.6, W / 2 + 0.2)):
        g["DarkStone"].box((a + b) / 2, fy - 0.12, FZ + 1.6, b - a, 0.24, 2.4)
    g["DarkStone"].box(0, D / 2 + 0.12, FZ + 1.6, W + 0.4, 0.24, 2.4)
    for s_ in (-1, 1):
        g["DarkStone"].box(s_ * (W / 2 + 0.12), 0, FZ + 1.6, 0.24, D + 0.4, 2.4)
        for y in (1.5, 8.5):                                               # 옆벽 붙임기둥(옆 창 y -10..-4 비움)
            g["Marble"].box(s_ * (W / 2 + 0.25), y, FZ + 7.0, 0.5, 1.4, 13.0)
            g["Marble"].box(s_ * (W / 2 + 0.4), y, FZ + 13.6, 0.8, 2.0, 0.7)
    for x in (-6.0, 0.0, 6.0):                                             # 뒷벽 붙임기둥(뒤 창 x ±11 비움)
        g["Marble"].box(x, D / 2 + 0.25, FZ + 7.0, 1.4, 0.5, 13.0)
        g["Marble"].box(x, D / 2 + 0.4, FZ + 13.6, 2.0, 0.8, 0.7)
    for x in (-16.4, -6.4, 6.4, 16.4):
        g["Marble"].box(x, fy - 0.3, FZ + 7.0, 1.6, 0.6, 13.0)
        g["Marble"].box(x, fy - 0.45, FZ + 13.6, 2.2, 0.9, 0.7)
        g["Marble"].box(x, fy - 0.45, FZ + 0.5, 2.0, 0.9, 1.0)
    g["Marble"].box(0, fy - 0.5, H - 0.6, W + 0.8, 1.0, 1.2)
    g["Marble"].box(0, fy - 0.6, H + 0.6, W + 1.0, 1.2, 1.2)
    v = [(-9.0, fy - 0.9, H + 1.2), (9.0, fy - 0.9, H + 1.2), (0, fy - 0.9, H + 5.4), (-9.0, fy + 0.6, H + 1.2), (9.0, fy + 0.6, H + 1.2), (0, fy + 0.6, H + 5.4)]
    g["Marble"].add_mesh(v, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)])
    coin_icon(g, 0, fy - 0.9, H + 1.75, -1)
    for s_ in (-1, 1):                                                     # 박공 비탈 위 눈
        g["SnowCap"].obox(s_ * 4.5, fy - 0.15, H + 3.45, 9.95, 1.4, 0.18, ry=s_ * 0.437)
    # 문: 대리석 문틀 + 놋쇠 징 박은 쌍문(안으로 연) + 문 위 판(금화)
    door_frame(g, -5.0, 5.0, fy, FZ + 10.0, mat="Marble")
    for s in (-1, 1):
        cxl, cyl = s * 5.0 - s * math.cos(math.radians(100.0)) * 2.5, iy0 + 0.2 + math.sin(math.radians(100.0)) * 2.5
        g["Wood"].obox(cxl, cyl, FZ + 4.95, 0.3, 5.0, 9.9, rz=-s * math.radians(10.0))
        for zz in (2.0, 5.0, 8.0):
            g["Brass"].obox(cxl - s * 0.18, cyl, FZ + zz, 0.08, 4.8, 0.25, rz=-s * math.radians(10.0))
    for x in (-8.0, 8.0):
        wall_lamp(g, x, fy - 0.5, FZ + 7.0)
    # 쇠살(앞 창 둘 · 옆 창)
    for cx in (-12.0, 12.0):
        for k in range(5):
            g["Iron"].box(cx - 2.4 + k * 1.2, fy - 0.55, FZ + 7.0, 0.14, 0.14, 6.0)
        g["Iron"].box(cx, fy - 0.55, FZ + 7.0, 6.0, 0.14, 0.14)
    # 평지붕 + 눈 + 난간(대리석) + 녹청 둥근 지붕(북)
    g["RoofMetal"].box(0, 0, H + 0.3, W + 0.4, D + 0.4, 0.6)
    g["SnowCap"].box(0, 0, H + 0.75, W - 1.0, D - 1.0, 0.3)
    for y0, y1, x0, x1 in ((fy - 0.2, fy + 0.6, -W / 2 - 0.2, W / 2 + 0.2), (D / 2 - 0.6, D / 2 + 0.2, -W / 2 - 0.2, W / 2 + 0.2),
                           (fy + 0.6, D / 2 - 0.6, -W / 2 - 0.2, -W / 2 + 0.6), (fy + 0.6, D / 2 - 0.6, W / 2 - 0.6, W / 2 + 0.2)):
        g["Marble"].box((x0 + x1) / 2, (y0 + y1) / 2, H + 1.8, x1 - x0, y1 - y0, 0.5)
        snow(g, (x0 + x1) / 2, (y0 + y1) / 2, H + 2.05, x1 - x0 - 0.1, y1 - y0 - 0.1, t=0.18)
        g["Marble"].box((x0 + x1) / 2, (y0 + y1) / 2, H + 1.0, x1 - x0 - 0.4, y1 - y0 - 0.2 if y1 - y0 < 1 else y1 - y0, 1.2)
    g["StoneTrim"].cyl(0, 2.0, H + 0.6, 4.4, 4.4, 3.6, seg=24)
    S.ring(g, "Marble", 0, 2.0, H + 4.0, 4.2, 4.8, 0.5, n=24)
    sphere(g, "Verdigris", (0, 2.0, H + 4.2), 4.1, sub=3)
    g["Brass"].cyl(0, 2.0, H + 8.2, 0.4, 0.2, 1.6, seg=8)
    sphere(g, "Brass", (0, 2.0, H + 9.9), 0.4, sub=1)
    # 안: 체크 대리석 바닥 · 나무 징두리(놋쇠 띠) · 대리석 우물 천장 + 샹들리에 둘
    checker_floor(g, ix0, ix1, iy0, iy1, sq=3.4)
    for x0, x1, y0, y1 in ((ix0, -5.0, iy0, iy0 + 0.25), (5.0, ix1, iy0, iy0 + 0.25), (ix0, ix1, iy1 - 0.25, iy1),
                           (ix0, ix0 + 0.25, iy0, iy1), (ix1 - 0.25, ix1, iy0, iy1)):
        g["Wood"].box((x0 + x1) / 2, (y0 + y1) / 2, FZ + 1.6, x1 - x0, y1 - y0, 3.2)
        g["Brass"].box((x0 + x1) / 2, (y0 + y1) / 2, FZ + 3.25, x1 - x0, y1 - y0 + 0.08, 0.12)
    g["Marble"].box(0, 0, H - 0.25, W - 2 * T, D - 2 * T, 0.5)
    for x in (-10.0, 0.0, 10.0):
        g["StoneTrim"].box(x, 0, H - 0.75, 0.6, D - 2 * T, 0.5)
    for y in (-7.0, 0.0, 7.0):
        g["StoneTrim"].box(0, y, H - 0.75, W - 2 * T, 0.6, 0.5)
    for x in (-8.0, 8.0):
        chandelier(g, x, -5.0, H - 0.1, 11.0)
    # 창구(x -14..14, y 3..5.5, 높이 3.5): 짙은 나무 앞판 · 대리석 윗판 · 놋쇠 띠, 위 칸막이 판 + 놋쇠 창살 창 둘
    g["Timber"].box(0, 4.25, (FZ + 3.2) / 2, 27.6, 2.2, 3.2 - FZ)
    for x in range(-13, 14, 2):
        g["Wood"].box(x, 3.12, 1.8, 1.6, 0.06, 2.2)
    g["Brass"].box(0, 3.1, 3.0, 27.8, 0.08, 0.15)
    g["Marble"].box(0, 4.25, 3.35, 28.4, 2.8, 0.3)
    C(0, 4.25, (FZ + 3.5) / 2, 28.4, 2.8, 3.5 - FZ)
    for x0, x1 in ((-14.0, -9.0), (9.0, 14.0)):
        g["Wood"].box((x0 + x1) / 2, 4.6, 5.5, x1 - x0, 0.3, 4.0)
        g["Brass"].box((x0 + x1) / 2, 4.6, 7.55, x1 - x0, 0.4, 0.15)
    g["Brass"].box(0, 4.6, 4.5, 6.0, 0.15, 0.15)                         # 가운데는 낮은 난간 — 창구 사이로 금고 문이 보인다
    for x in (-2.9, 0.0, 2.9):
        g["Brass"].box(x, 4.6, 4.0, 0.15, 0.15, 1.0)
    for cx in (-6.0, 6.0):
        g["Brass"].box(cx, 4.6, 7.55, 6.0, 0.4, 0.15)
        for x in (cx - 3.0, cx + 3.0):
            g["Brass"].box(x, 4.6, 5.5, 0.2, 0.4, 4.0)
        for k in range(9):
            x = cx - 2.4 + k * 0.6
            if abs(x - cx) > 1.1:
                g["Brass"].box(x, 4.6, 5.5, 0.07, 0.07, 4.0)
            else:
                g["Brass"].box(x, 4.6, 6.75, 0.07, 0.07, 1.5)
        g["Brass"].box(cx, 4.6, 6.0, 2.4, 0.1, 0.12)
        half_ring_y(g, "Brass", cx, 4.6, 6.0, 1.1, 1.3, 0.2)
        g["Brass"].box(cx, 3.6, 3.55, 2.6, 0.6, 0.06)
        for k in range(3):                                                 # 금화 더미
            g["SignGold"].cyl(cx + 0.8 + k * 0.32, 3.8, 3.5, 0.15, 0.15, 0.12 + k * 0.1, seg=10)
        g["Char"].box(cx - 0.9, 3.85, 3.53, 0.5, 0.35, 0.06)                # 잉크판 + 도장
        g["Brass"].box(cx - 0.4, 3.85, 3.6, 0.3, 0.2, 0.12)
        g["Wood"].cyl(cx - 0.4, 3.85, 3.66, 0.06, 0.08, 0.35, seg=8)
        NPC(cx, 8.0, FZ, 0.0)
    # 뒤 벽: 둥근 금고 문(쇠 원판 · 놋쇠 테 · 바퀴 손잡이 · 빗장) + 양옆 대여 금고 서랍 벽
    vz = FZ + 5.5
    g["StoneTrim"].box(0, iy1 - 0.15, vz, 10.4, 0.3, 10.4)
    g["Iron"].hcyl(0, iy1 - 0.5, vz, 4.4, 0.7, axis="y", seg=28)
    g["Brass"].hcyl(0, iy1 - 0.9, vz, 4.5, 0.12, axis="y", seg=28)
    g["Iron"].hcyl(0, iy1 - 0.97, vz, 4.1, 0.08, axis="y", seg=28)
    g["Brass"].hcyl(0, iy1 - 1.1, vz, 0.5, 0.3, axis="y", seg=12)
    for k in range(6):
        a = k * math.pi / 3
        g["Brass"].obox(0.9 * math.cos(a), iy1 - 1.2, vz + 0.9 * math.sin(a), 1.8, 0.12, 0.14, ry=-a)
    for k in range(8):
        a = k * math.pi / 4
        g["Steel"].hcyl(3.6 * math.cos(a), iy1 - 1.0, vz + 3.6 * math.sin(a), 0.22, 0.2, axis="y", seg=8)
    for k in range(6):                                                     # 바퀴 살 끝 손잡이
        a = k * math.pi / 3
        sphere(g, "Brass", (1.8 * math.cos(a), iy1 - 1.25, vz + 1.8 * math.sin(a)), 0.16, sub=1)
    for zz in (vz - 2.6, vz + 2.6):                                         # 왼쪽 경첩 통 둘
        g["Iron"].cyl(-4.75, iy1 - 0.75, zz - 0.8, 0.32, 0.32, 1.6, seg=12)
        g["Brass"].cyl(-4.75, iy1 - 0.75, zz - 0.85, 0.36, 0.36, 0.1, seg=12)
    for zz in (vz - 1.2, vz, vz + 1.2):                                     # 빗장 막대(가운데 → 테)
        g["Steel"].box(2.6, iy1 - 1.02, zz, 2.8, 0.1, 0.16)
    g["Paint"].hcyl(2.3, iy1 - 1.05, vz + 2.3, 0.45, 0.06, axis="y", seg=20)   # 번호 다이얼
    g["Brass"].hcyl(2.3, iy1 - 1.03, vz + 2.3, 0.52, 0.04, axis="y", seg=20)
    for k in range(12):
        a = k * math.pi / 6
        g["Char"].box(2.3 + 0.38 * math.cos(a), iy1 - 1.1, vz + 2.3 + 0.38 * math.sin(a), 0.04, 0.02, 0.04)
    g["Brass"].hcyl(2.3, iy1 - 1.16, vz + 2.3, 0.14, 0.12, axis="y", seg=10)
    g["Brass"].box(-2.4, iy1 - 1.04, vz - 3.0, 1.4, 0.04, 0.4)              # 이름판
    C(0, iy1 - 0.5, vz, 9.0, 1.0, 9.0)
    for x0, x1 in ((-14.5, -5.8), (5.8, 14.5)):
        g["Wood"].box((x0 + x1) / 2, iy1 - 0.3, FZ + 4.6, x1 - x0, 0.6, 8.4)
        for i in range(int((x1 - x0) / 1.4)):
            for j in range(6):
                x = x0 + 0.75 + i * 1.4
                z = FZ + 1.3 + j * 1.3
                g["Brass"].box(x, iy1 - 0.62, z, 1.2, 0.06, 1.1)
                g["Iron"].box(x, iy1 - 0.68, z, 0.2, 0.06, 0.12)
        C((x0 + x1) / 2, iy1 - 0.3, FZ + 4.6, x1 - x0, 0.6, 8.4)
    # 직원 책상 둘(창구 뒤 양끝) · 동전 더미 · 장부
    for s in (-1, 1):
        x = s * 12.0
        g["Wood"].box(x, 9.5, 2.9, 3.6, 2.0, 0.25)
        for dx in (-1.6, 1.6):
            for dy in (-0.8, 0.8):
                g["Timber"].box(x + dx, 9.5 + dy, (FZ + 2.8) / 2, 0.25, 0.25, 2.8 - FZ)
        for k in range(3):
            g["SignGold"].cyl(x - 0.8 + k * 0.45, 9.3, 3.02, 0.2, 0.2, 0.2 + k * 0.15, seg=10)
        g["Leather"].box(x + 0.8, 9.6, 3.1, 1.2, 0.9, 0.15)
        C(x, 9.5, (FZ + 3.0) / 2, 3.6, 2.0, 3.0 - FZ)
    # 대기 걸상(옆 벽) · 시세판(왼 벽) · 화분
    for s in (-1, 1):
        bench(g, s * (ix1 - 1.0), iy0 + 6.0, FZ, 8.0, axis="y")
        potted_plant(g, s * 12.8, iy0 + 1.4)
    bx = ix0 + 0.2
    g["Brass"].box(bx, iy0 + 8.0, FZ + 7.4, 0.2, 10.4, 5.4)
    g["DarkStone"].box(bx + 0.12, iy0 + 8.0, FZ + 7.4, 0.1, 10.0, 5.0)
    for j in range(5):
        z = FZ + 9.3 - j * 0.95
        g["Dial"].box(bx + 0.2, iy0 + 5.0, z, 0.05, 3.0, 0.4)
        for k in range(3):
            g["SignGold" if (j + k) % 2 else "GlowTeal"].box(bx + 0.2, iy0 + 8.2 + k * 1.5, z, 0.05, 0.9, 0.35)
    DOORWAY(-5.0, 5.0, fy - 0.2, iy0, FZ, 10.0)
    CLEAR(-4.8, 4.8, iy0 + 0.2, -7.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-10.8, -1.2, -7.0, 2.7, FZ + 0.15, FZ + 5.4)
    CLEAR(1.2, 10.8, -7.0, 2.7, FZ + 0.15, FZ + 5.4)


def half_ring_y(g, mat, x, y, z, r0, r1, t, n=12):
    """y 에 선 반원 테(아래 끝 높이 z)"""
    v = []
    for yy in (y - t / 2, y + t / 2):
        for r in (r0, r1):
            for k in range(n + 1):
                a = math.pi * k / n
                v.append((x + r * math.cos(a), yy, z + r * math.sin(a)))
    m = n + 1
    f = []
    for k in range(n):
        f += [(k, m + k, m + k + 1, k + 1), (2 * m + k, 2 * m + k + 1, 3 * m + k + 1, 3 * m + k),
              (m + k, 3 * m + k, 3 * m + k + 1, m + k + 1), (k, k + 1, 2 * m + k + 1, 2 * m + k)]
    f += [(0, 2 * m, 3 * m, m), (n, m + n, 3 * m + n, 2 * m + n)]
    g[mat].add_mesh(v, f)


# ------------------------------------------------------------------ 병원
def radiator(g, x, y, z0, axis="x"):
    """감정 열기 방열기(구리 지느러미 + 놋쇠 관)"""
    for k in range(6):
        if axis == "x":
            g["Copper"].box(x - 0.75 + k * 0.3, y, z0 + 1.2, 0.16, 0.5, 2.2)
        else:
            g["Copper"].box(x, y - 0.75 + k * 0.3, z0 + 1.2, 0.5, 0.16, 2.2)
    g["Brass"].box(x, y, z0 + 0.25, 1.9 if axis == "x" else 0.6, 0.6 if axis == "x" else 1.9, 0.2)
    g["Brass"].box(x, y, z0 + 2.35, 1.9 if axis == "x" else 0.6, 0.6 if axis == "x" else 1.9, 0.15)
    C(x, y, z0 + 1.2, 1.9 if axis == "x" else 0.6, 0.6 if axis == "x" else 1.9, 2.4)


def svc_hospital(g):
    """병원: 크림 회벽 + 벽돌 띠, 옆 박공 지붕 + 용마루 유리 채광 탑, 쌍문 위 유리 차양, 심장 톱니 간판(감정 열기로 고친다).
    안: 밝은 대리석 바닥·천장, 접수대, 침대 여섯(커튼 줄), 침대 곁 구리 방열기, 가운데 뒤 부활 고리(놋쇠 테 + 심장) → 뒷문 → 회복 정원, 약장"""
    W, D, H = 40.0, 30.0, 16.0
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, H, "Paint", (-5.0, 5.0, 10.0), ((-13.0, 4.0, 6.0, 6.0), (13.0, 4.0, 6.0, 6.0)),
                                     ((-3.0, 5.0, 6.0, 5.0),), back_door=(-3.0, 3.0, 9.0), trim="Brick",
                                     back_win=((-12.0, 9.0, 2.6, 4.0), (-6.0, 9.0, 2.6, 4.0), (6.0, 9.0, 2.6, 4.0), (12.0, 9.0, 2.6, 4.0)))
    fy = -D / 2
    # 벽돌 밑동 · 창 둘레 벽돌 테 · 쌍문(안으로 연) · 유리 차양 · 간판 · 큰 심장 톱니
    for a, b in ((-W / 2 - 0.2, -5.6), (5.6, W / 2 + 0.2)):
        g["Brick"].box((a + b) / 2, fy - 0.12, FZ + 1.6, b - a, 0.24, 2.4)
    for cx in (-13.0, 13.0):
        g["Brick"].box(cx, fy - 0.15, FZ + 10.2, 7.4, 0.3, 0.7)
        snow(g, cx, fy - 0.15, FZ + 10.55, 7.3, 0.28, t=0.1)
    door_frame(g, -5.0, 5.0, fy, FZ + 10.0, mat="Brick")
    for s in (-1, 1):
        cxl, cyl = s * 5.0 - s * math.cos(math.radians(100.0)) * 2.5, iy0 + 0.2 + math.sin(math.radians(100.0)) * 2.5
        g["Paint"].obox(cxl, cyl, FZ + 4.95, 0.3, 5.0, 9.9, rz=-s * math.radians(10.0))
        g["WinGlass"].obox(cxl - s * 0.17, cyl, FZ + 6.5, 0.06, 3.0, 3.5, rz=-s * math.radians(10.0))
    g["Iron"].box(0, fy - 1.6, FZ + 11.0, 12.0, 3.2, 0.25)
    g["WinGlass"].box(0, fy - 1.6, FZ + 11.2, 11.4, 2.8, 0.1)
    snow(g, 0, fy - 1.0, FZ + 11.25, 11.0, 1.6, t=0.14)
    for x in (-5.8, 5.8):
        g["Iron"].obox(x, fy - 1.0, FZ + 10.0, 0.15, 2.4, 0.15, rx=0.8)
    g["Paint"].hcyl(0, fy - 0.15, FZ + 14.0, 2.2, 0.3, axis="y", seg=20)
    heart_icon(g, 0, fy - 0.3, FZ + 12.0, -1, s=1.9)
    for x in (-7.5, 7.5):
        wall_lamp(g, x, fy, FZ + 7.0)
    # 지붕: 옆 박공 + 용마루 유리 채광 탑(흰 틀 + 유리 + 눈)
    S.roof_gable(g, 0, 0, H, D + 0.6, W + 0.6, 7.0, along="x")
    g["Paint"].box(0, 0, H + 7.6, 24.0, 3.6, 1.0)
    g["WinGlass"].box(0, 0, H + 8.9, 23.6, 3.4, 1.6)
    for x in range(-11, 12, 3):
        g["Paint"].box(x, 0, H + 8.9, 0.3, 3.6, 1.6)
    g["RoofMetal"].box(0, 0, H + 9.9, 24.6, 4.4, 0.4)
    g["SnowCap"].box(0, 0, H + 10.25, 23.8, 3.8, 0.3)
    # 안: 밝은 바닥 · 회 천장 · 매단 등
    checker_floor(g, ix0, ix1, iy0, iy1, sq=4.0, a="Marble", b="Paint")
    g["Paint"].box(0, 0, H - 0.2, W - 2 * T, D - 2 * T, 0.4)
    for x, y in ((-8.0, -6.0), (8.0, -6.0), (-12.0, 9.0), (12.0, 9.0)):
        lantern(g, x, y, H - 0.4, 11.4)
    # 접수대(x -10.5..-8, y -8..0, 높이 3.5): 흰 몸 · 놋쇠 윗테 · 장부 · 종 + 뒤 서류장(왼 벽)
    g["Paint"].box(-9.25, -4.0, (FZ + 3.2) / 2, 2.2, 7.6, 3.2 - FZ)
    g["Wood"].box(-9.25, -4.0, 3.35, 2.8, 8.2, 0.3)
    g["Brass"].box(-8.05, -4.0, 3.0, 0.08, 7.8, 0.15)
    g["SignRed"].box(-8.1, -4.0, 2.0, 0.06, 2.0, 0.6)
    C(-9.25, -4.0, (FZ + 3.5) / 2, 2.8, 8.2, 3.5 - FZ)
    g["Leather"].box(-9.3, -5.6, 3.58, 1.0, 1.4, 0.15)
    g["Canvas"].box(-9.3, -5.6, 3.68, 0.9, 1.25, 0.04)
    g["Brass"].cyl(-9.0, -1.5, 3.5, 0.3, 0.16, 0.4, seg=12)
    NPC(-13.0, -4.0, FZ, 90.0)
    tops = side_shelf(g, ix0, -9.0, 0.0, FZ, 7.0, depth=1.4, levels=4, face=1)
    for k, z in enumerate(tops):
        for j in range(6):
            g[("Canvas", "SignBlue", "Paint")[(j + k) % 3]].box(ix0 + 0.7, -8.2 + j * 1.4, z + 0.5, 1.0, 1.1, 0.95)
    # 침대 여섯: 뒤 벽 넷(머리가 벽) · 오른 벽 둘 + 커튼 줄 + 방열기
    for x in (-15.0, -9.0, 9.0, 15.0):
        bed(g, x, iy1 - 3.1, FZ, rz=-math.pi / 2, mat="Banner")
    for y in (-8.0, -2.0):
        bed(g, ix1 - 3.1, y, FZ, rz=math.pi, mat="Banner")
    for x in (-12.0, -6.0, 6.0, 12.0):
        g["Brass"].box(x, 10.5, 8.0, 0.1, 7.0, 0.1)
        g["Brass"].box(x, 7.05, 4.0, 0.1, 0.1, 8.0)
        g["Canvas"].box(x, 12.4, 4.6, 0.08, 3.0, 6.4)
    for x in (-12.0, 12.0):
        radiator(g, x, iy1 - 0.5, FZ)
    radiator(g, ix1 - 0.5, -5.0, FZ, axis="y")
    for x in (-6.0, 6.0):
        g["Wood"].box(x, iy1 - 0.8, FZ + 1.2, 1.4, 1.4, 2.4)
        g["Glass"].cyl(x, iy1 - 0.8, FZ + 2.4, 0.18, 0.18, 0.6, seg=8)
        C(x, iy1 - 0.8, FZ + 1.2, 1.4, 1.4, 2.4)
    # 부활 고리(가운데 뒤, 뒷문 앞): 놋쇠 테 둘 + 심장 무늬 · 위 놋쇠 심장 등 · 뒤 벽 심장 톱니
    S.ring(g, "Brass", 0, 8.0, FZ + 0.02, 2.6, 3.0, 0.05, n=32)
    S.ring(g, "Brass", 0, 8.0, FZ + 0.02, 1.5, 1.7, 0.05, n=24)
    for dx in (-0.35, 0.35):
        g["SignRed"].cyl(dx, 8.25, FZ + 0.02, 0.42, 0.42, 0.05, seg=12)
    g["SignRed"].add_mesh([(-0.75, 8.15, FZ + 0.02), (0.75, 8.15, FZ + 0.02), (0, 7.2, FZ + 0.02),
                           (-0.75, 8.15, FZ + 0.07), (0.75, 8.15, FZ + 0.07), (0, 7.2, FZ + 0.07)],
                          [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)])
    g["Iron"].cyl(0, 8.0, 10.2, 0.06, 0.06, H - 10.6, seg=6)
    S.ring(g, "Brass", 0, 8.0, 9.4, 0.7, 0.85, 0.8, n=14)
    sphere(g, "SignRed", (0, 8.0, 9.8), 0.45, sub=1)
    g["LampPt"].box(0, 8.0, 9.2, 0.3, 0.3, 0.3)
    heart_icon(g, 0, iy1, FZ + 10.4, -1, s=1.4)
    # 약장(왼 벽, 유리 문 속 병) · 치료사 수레
    x0 = ix0
    g["Wood"].box(x0 + 0.75, 7.5, FZ + 3.6, 1.5, 9.0, 7.2)
    for k, z in enumerate((FZ + 1.6, FZ + 3.4, FZ + 5.2)):
        g["Wood"].box(x0 + 0.85, 7.5, z - 0.1, 1.3, 8.6, 0.12)
        bottle_col(g, x0 + 1.0, 3.3, 11.7, z, seed=60 + k, liquids=("SignRed", "Verdigris", "SignTeal", "SignGold"))
    g["WinGlass"].box(x0 + 1.52, 7.5, FZ + 3.8, 0.06, 8.6, 6.4)
    g["SignRed"].box(x0 + 1.56, 7.5, FZ + 7.6, 0.06, 1.2, 0.4)
    C(x0 + 0.75, 7.5, FZ + 3.6, 1.5, 9.0, 7.2)
    g["Steel"].box(3.8, 4.8, FZ + 2.4, 1.2, 2.0, 0.12)
    g["Steel"].box(3.8, 4.8, FZ + 1.2, 1.2, 2.0, 0.12)
    for dx in (-0.5, 0.5):
        for dy in (-0.9, 0.9):
            g["Steel"].box(3.8 + dx, 4.8 + dy, FZ + 1.25, 0.08, 0.08, 2.5)
    bottle_row(g, 3.3, 4.4, 4.6, FZ + 2.46, seed=7, liquids=("SignRed", "Verdigris"))
    C(3.8, 4.8, FZ + 1.3, 1.2, 2.0, 2.6)
    NPC(5.0, 3.0, FZ, 0.0)
    for s in (-1, 1):
        potted_plant(g, s * 14.0, iy0 + 1.4)
    DOORWAY(-5.0, 5.0, fy - 0.2, iy0, FZ, 10.0)
    DOORWAY(-3.0, 3.0, iy1, D / 2 + 0.2, FZ, 9.0)
    CLEAR(-4.8, 4.8, iy0 + 0.2, -7.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-7.8, 1.8, -8.5, 0.8, FZ + 0.15, FZ + 5.4)          # 앞쪽 끝은 열린 문짝(y -8.8) 옆


# ------------------------------------------------------------------ 여관
Z2_INN, H_INN = 13.4, 27.4


def svc_inn(g):
    """여관 2층: 아래 벽돌 · 위 반목조(회벽 + 나무 틀), 옆 박공 지붕 + 앞 지붕창 셋, 뒤 벽 굴뚝, 쌍문 위 작은 지붕, 맥주잔 간판, 창 꽃상자.
    1층: 바(맥주 꼭지·병 선반·통), 벽난로(진짜 장작불), 둥근 탁자 셋, 계단(오른 벽, 난간). 2층: 뒤 복도(깔개·벽등) + 앞 방 셋(침대·옷장·세면대·깔개)"""
    W, D = 40.0, 30.0
    Z2, H = Z2_INN, H_INN
    ix0, ix1, iy0, iy1 = shell_walls(g, W, D, Z2, "Brick", (-4.0, 4.0, 10.0), ((-12.0, 3.5, 6.0, 5.0), (12.0, 3.5, 6.0, 5.0)),
                                     (), back_door=(-11.0, -5.0, 9.0))
    S.window(g, -W / 2, -9.0, 3.5, 5.0, 5.0, face="-x", cross=True, frame="Iron")
    S.window(g, ix0, -9.0, 3.5, 5.0, 5.0, face="+x", cross=True, sill=False, frame="Iron")
    fy = -D / 2
    # 2층 벽(회벽) + 창 + 나무 틀
    box2(g, "Paint", -W / 2, W / 2, -D / 2, iy0, Z2, H)
    box2(g, "Paint", -W / 2, W / 2, iy1, D / 2, Z2, H)
    for s in (-1, 1):
        box2(g, "Paint", *sorted((s * W / 2, s * ix1)), iy0, iy1, Z2, H)
    for x in (-15.5, -5.5, 5.5, 15.5):                                    # 앞 위층 창 넷(좌우 대칭 — 오른 끝은 계단 칸)
        front_window(g, x, fy, iy0, Z2 + 3.0, 5.0, 5.0, frame="Timber")
    side_window(g, -W / 2, ix0, -8.0, Z2 + 3.0, 4.0, 5.0, "-x")
    side_window(g, W / 2, ix1, 11.0, Z2 + 3.0, 4.0, 5.0, "+x")
    for x in (-12.0, 2.0):
        back_window(g, x, D / 2, iy1, Z2 + 3.0, 4.0, 4.5)
    for y, xs_, face in ((fy - 0.12, (-19.85, -12.6, -8.4, -2.6, 0.0, 2.6, 8.4, 12.6, 19.85), -1),
                         (D / 2 + 0.12, (-19.85, -14.5, -9.5, 0.0, 4.5, 9.5, 19.85), 1)):
        for x in xs_:
            g["Timber"].box(x, y, (Z2 + H) / 2, 0.35, 0.24, H - Z2)
        for z in (Z2 + 0.3, Z2 + 2.6, Z2 + 8.4, H - 0.5):
            g["Timber"].box(0, y, z, W + 0.2, 0.24, 0.35)
    for s in (-1, 1):
        xw = s * (W / 2 + 0.12)
        for y in (-14.85, -6.0, 3.0, 14.85):
            g["Timber"].box(xw, y, (Z2 + H) / 2, 0.24, 0.35, H - Z2)
        for z in (Z2 + 0.3, Z2 + 2.6, Z2 + 8.4, H - 0.5):
            g["Timber"].box(xw, 0, z, 0.24, D + 0.2, 0.35)
    # 지붕: 옆 박공 + 앞 지붕창 셋(작은 박공 + 유리창) + 굴뚝(뒤 벽, 벽난로 위)
    S.roof_gable(g, 0, 0, H, D + 0.6, W + 0.6, 9.0, along="x")
    for x in (-12.0, 0.0, 12.0):
        g["Paint"].box(x, -9.5, H + 4.6, 3.6, 3.0, 3.6)
        g["Timber"].box(x, -11.05, H + 4.6, 3.8, 0.12, 3.8)
        g["Soot"].box(x, -11.12, H + 4.6, 2.2, 0.06, 2.4)
        g["WinGlass"].box(x, -11.18, H + 4.6, 2.2, 0.04, 2.4)
        g["Timber"].box(x, -11.2, H + 4.6, 0.15, 0.08, 2.4)
        S.roof_gable(g, x, -9.5, H + 6.4, 4.0, 3.4, 1.8, along="y", over=0.3, thick=0.3, gable="Paint")
    g["BrickDark"].box(0, 15.0, (Z2 + H + 12.0) / 2, 4.0, 2.6, H + 12.0 - Z2)
    g["StoneTrim"].box(0, 15.0, H + 12.2, 4.6, 3.2, 0.5)
    for x in (-0.9, 0.9):
        g["Iron"].cyl(x, 15.0, H + 12.4, 0.45, 0.45, 1.2, seg=10)
    S.vent(g, 0, 15.0, H + 14.0)
    C(0, 15.0, (Z2 + H) / 2, 4.0, 2.6, H - Z2)
    # 앞: 문틀 + 쌍문(안으로 연) + 문 위 작은 지붕 + 간판 + 창 꽃상자 + 벽등
    door_frame(g, -4.0, 4.0, fy, FZ + 10.0, mat="Timber")
    for s in (-1, 1):
        cxl, cyl = s * 4.0 - s * math.cos(math.radians(100.0)) * 2.0, iy0 + 0.2 + math.sin(math.radians(100.0)) * 2.0
        g["Timber"].obox(cxl, cyl, FZ + 4.95, 0.3, 4.0, 9.9, rz=-s * math.radians(10.0))
    g["RoofMetal"].obox(0, fy - 1.4, FZ + 11.3, 10.0, 3.0, 0.25, rx=0.35)
    g["SnowCap"].obox(0, fy - 1.35, FZ + 11.55, 9.6, 2.6, 0.25, rx=0.35)
    for x in (-4.6, 4.6):
        g["Timber"].obox(x, fy - 1.0, FZ + 10.3, 0.2, 2.2, 0.2, rx=0.9)
    hanging_sign(g, 0, fy - 0.25, FZ + 13.2, mug_icon)
    for cx, w in ((-12.0, 6.0), (12.0, 6.0)):
        g["Wood"].box(cx, fy - 0.5, 3.0, w + 0.4, 0.8, 0.6)
        for k in range(int(w / 0.8)):
            x = cx - w / 2 + 0.4 + k * 0.8
            sphere(g, "Felt", (x, fy - 0.5, 3.5), 0.35, sub=1)
            if k % 2:
                sphere(g, "SignRed" if k % 4 == 1 else "SignPurple", (x, fy - 0.65, 3.8), 0.18, sub=1)
    for x in (-6.0, 6.0):
        wall_lamp(g, x, fy, FZ + 7.0)
    # 1층 바닥(나무 판) · 2층 바닥 판(계단 구멍 x 13..19, y -11.5..8 비움) · 2층 천장
    g["Wood"].box(0, 0, FZ + 0.025, W - 2 * T, D - 2 * T, 0.05)
    sx0, sx1, sy0, n = 13.0, ix1, -11.5, 13
    sy1 = sy0 + n * 1.5
    box2(g, "Wood", ix0, sx0, iy0, iy1, Z2 - 1.0, Z2)
    box2(g, "Wood", sx0, ix1, sy1, iy1, Z2 - 1.0, Z2)
    g["Timber"].box((ix0 + sx0) / 2, 0, Z2 - 1.15, sx0 - ix0, 0.5, 0.3)
    for x in (-12.0, -4.0, 4.0):
        g["Timber"].box(x, 0, Z2 - 1.15, 0.5, D - 2 * T, 0.3)
    g["Paint"].box(0, 0, H - 0.3, W - 2 * T, D - 2 * T, 0.4)
    # 계단(13 단, 단 1.0 · 디딤 1.5) + 왼쪽 난간(아래 두 단은 비움 — 옆에서 오른다)
    for i in range(n):
        box2(g, "Wood", sx0, sx1, sy0 + i * 1.5, sy0 + (i + 1) * 1.5, FZ, FZ + (i + 1) * (Z2 - FZ) / n)
        g["Timber"].box((sx0 + sx1) / 2, sy0 + i * 1.5 + 0.1, FZ + (i + 1) * (Z2 - FZ) / n - 0.08, sx1 - sx0, 0.2, 0.16)
    for i in range(2, n + 1, 2):
        yy = sy0 + i * 1.5 - 0.2
        zt = FZ + min(i, n) * (Z2 - FZ) / n
        g["Timber"].box(sx0 + 0.15, yy, zt + 1.7, 0.25, 0.25, 3.4)
    rail_len = math.hypot((n - 2) * 1.5, (n - 2) * (Z2 - FZ) / n)
    rz0 = FZ + 2 * (Z2 - FZ) / n + 3.4
    g["Timber"].obox(sx0 + 0.15, sy0 + 3.0 + (n - 2) * 0.75, rz0 + (n - 2) * (Z2 - FZ) / n / 2, 0.3, rail_len, 0.3,
                     rx=math.atan2((Z2 - FZ) / n, 1.5))
    # 1층: 바(왼 벽) — 앞판·놋쇠 발걸이·윗판, 맥주 꼭지 셋, 잔, 뒤 병 선반·통, 바 의자(빈 바닥 밖)
    bx0, bx1, by0, by1 = -14.0, -11.5, -4.0, 12.0
    g["Timber"].box((bx0 + bx1) / 2, (by0 + by1) / 2, (FZ + 3.2) / 2, bx1 - bx0 - 0.3, by1 - by0, 3.2 - FZ)
    for y in range(-3, 12, 2):
        g["Wood"].box(bx1 - 0.12, y, 1.8, 0.06, 1.6, 2.2)
    g["Brass"].box(bx1 + 0.35, (by0 + by1) / 2, FZ + 0.6, 0.12, by1 - by0, 0.12)
    g["Wood"].box((bx0 + bx1) / 2, (by0 + by1) / 2, 3.35, bx1 - bx0 + 0.4, by1 - by0 + 0.3, 0.3)
    C((bx0 + bx1) / 2, (by0 + by1) / 2, (FZ + 3.5) / 2, bx1 - bx0 + 0.4, by1 - by0 + 0.3, 3.5 - FZ)
    beer_tower(g, -13.2, 3.0, 3.5)
    for y in (7.0, 7.8, 9.6):
        beer_mug(g, -12.4, y, 3.5)
    tops = side_shelf(g, ix0, -4.0, 12.0, FZ, 9.0, depth=1.0, levels=5, face=1)
    for k, z in enumerate(tops[2:]):
        bottle_col(g, ix0 + 0.5, -3.8, 11.8, z, seed=70 + k, liquids=("SignGold", "Wood", "SignRed", "Verdigris"))
    for y in (-2.0, 0.6, 3.2):
        g["Wood"].hcyl(ix0 + 0.55, y, FZ + 1.0, 0.75, 1.1, axis="x", seg=12)
        g["Brass"].hcyl(ix0 + 1.12, y, FZ + 1.0, 0.18, 0.2, axis="x", seg=8)
    NPC(-16.5, 4.0, FZ, 90.0)
    for y in (8.2, 10.2):
        g["Wood"].cyl(-10.6, y, FZ + 2.3, 0.55, 0.55, 0.2, seg=12)
        g["Iron"].cyl(-10.6, y, FZ, 0.08, 0.08, 2.3, seg=6)
    # 벽난로(뒤 가운데): 돌 둘레 · 화구 · 진짜 장작불 · 선반(시계·촛대) · 앞 화로돌(y 11 부터)
    fx0, fx1 = -4.0, 4.0
    box2(g, "StoneTrim", fx0, -2.0, iy1 - 2.0, iy1, FZ, FZ + 7.0)
    box2(g, "StoneTrim", 2.0, fx1, iy1 - 2.0, iy1, FZ, FZ + 7.0)
    box2(g, "StoneTrim", -2.0, 2.0, iy1 - 2.0, iy1, FZ + 3.6, FZ + 7.0)
    g["Soot"].box(0, iy1 - 0.3, FZ + 1.8, 4.0, 0.2, 3.6)
    fire_logs(g, 0, iy1 - 1.0, FZ + 0.05, 2.6, 1.2, axis="x", size=0.7)
    g["Wood"].box(0, iy1 - 2.2, FZ + 7.2, 9.0, 1.0, 0.4)
    mantel_clock(g, 0, iy1 - 2.2, FZ + 7.4)
    for x in (-3.0, 3.0):
        g["Brass"].cyl(x, iy1 - 2.2, FZ + 7.4, 0.15, 0.12, 0.8, seg=8)
        g["Canvas"].cyl(x, iy1 - 2.2, FZ + 8.2, 0.1, 0.1, 0.4, seg=6)
    g["StoneTrim"].box(0, iy1 - 2.5, FZ + 0.05, 7.0, 1.0, 0.1)
    box2(g, "StoneTrim", -2.0, 2.0, iy1 - 1.0, iy1, FZ + 7.0, Z2 - 1.0, coll=False)
    # 탁자 셋(둥근 탁자 + 걸상) · 매단 등 · 계단 밑 통
    for x, y in ((5.0, -3.0), (5.0, 5.0), (-9.0, -10.0)):
        round_table(g, x, y, FZ, r=1.7, h=2.8, stools=4)
        g["Canvas"].cyl(x, y, FZ + 2.8, 0.3, 0.3, 0.2, seg=8)
    for x, y in ((0.0, -6.0), (6.0, 1.0), (-6.0, 4.0), (-9.0, -10.0)):
        lantern(g, x, y, Z2 - 1.3, 9.2)
    for y in (4.6, 6.4):
        barrel(g, 15.2, y, FZ, r=0.8, h=2.2)
    crate(g, 17.6, 5.5, FZ, 2.0)
    C(17.6, 5.5, FZ + 1.0, 2.0, 2.0, 2.0)
    # 2층: 방 셋(앞) + 복도(뒤 y 6.3..14)
    wall_x = sx0 - 0.3
    box2(g, "Paint", wall_x - 0.3, wall_x + 0.3, iy0, 6.0, Z2, H)
    xs = [ix0, -8.33, 2.33, wall_x - 0.3]
    for k in range(1, 3):
        box2(g, "Paint", xs[k] - 0.3, xs[k] + 0.3, iy0, 6.0, Z2, H)
    door_cx = [(xs[k] + xs[k + 1]) / 2 for k in range(3)]
    segs = [ix0] + [v for c in door_cx for v in (c - 3.0, c + 3.0)] + [wall_x - 0.3]
    for a, b in zip(segs[0::2], segs[1::2]):
        box2(g, "Paint", a, b, 5.7, 6.3, Z2, H)
    for c in door_cx:
        box2(g, "Paint", c - 3.0, c + 3.0, 5.7, 6.3, Z2 + 9.0, H)
        for x in (c - 3.15, c + 3.15):
            g["Timber"].box(x, 6.0, Z2 + 4.5, 0.35, 0.8, 9.0)
        g["Timber"].box(c, 6.0, Z2 + 9.15, 6.6, 0.8, 0.35)
        g["Brass"].box(c, 6.45, Z2 + 9.9, 0.9, 0.06, 0.5)
    for k in range(3):
        cx = door_cx[k]
        bed(g, cx, iy0 + 3.1, Z2, rz=math.pi / 2, mat=("Banner", "SignBlue", "SignPurple")[k])
        wardrobe(g, xs[k] + 0.3 + (1.1 if k else 0.8), -2.0, Z2, "+x")
        washstand(g, xs[k + 1] - 1.0, -10.5, Z2, "-x")
        g[("Banner", "SignTeal", "SignGold")[k]].box(cx, -3.0, Z2 + 0.03, 4.6, 6.0, 0.05)
        lantern(g, cx, -4.0, H - 0.5, Z2 + 9.0)
    g["Banner"].box((ix0 + wall_x) / 2, 10.2, Z2 + 0.03, wall_x - ix0 - 2.0, 3.0, 0.05)
    # 복도 징두리(나무 판 + 놋쇠 띠) — 크림 벽이 등빛에 너무 노랗게 떠서 아래를 나무로
    for a_, b_ in zip([ix0] + [c + 3.0 for c in door_cx], [c - 3.0 for c in door_cx] + [wall_x - 0.3]):
        g["Wood"].box((a_ + b_) / 2, 6.36, Z2 + 1.6, b_ - a_, 0.12, 3.2)
        g["Brass"].box((a_ + b_) / 2, 6.42, Z2 + 3.25, b_ - a_, 0.08, 0.1)
    for a_, b_ in ((ix0, -2.0), (2.0, wall_x + 0.3)):
        g["Wood"].box((a_ + b_) / 2, iy1 - 0.06, Z2 + 1.6, b_ - a_, 0.12, 3.2)
        g["Brass"].box((a_ + b_) / 2, iy1 - 0.12, Z2 + 3.25, b_ - a_, 0.08, 0.1)
    for x in (-12.0, 4.0):
        lantern(g, x, 11.0, H - 0.5, Z2 + 9.0)
    g["Wood"].box(-18.3, 10.0, Z2 + 1.4, 1.2, 3.0, 2.8)
    potted_plant(g, -18.2, 13.0, Z2)
    C(-18.3, 10.0, Z2 + 1.4, 1.2, 3.0, 2.8)
    DOORWAY(-4.0, 4.0, fy - 0.2, iy0, FZ, 10.0)
    DOORWAY(-11.0, -5.0, iy1, D / 2 + 0.2, FZ, 9.0)
    for c in door_cx:
        DOORWAY(c - 3.0, c + 3.0, 5.6, 6.4, Z2, 9.0, depth=1.5)
    CLEAR(-3.8, 3.8, iy0 + 0.2, -8.0, FZ + 0.15, FZ + 5.4)
    CLEAR(-11.0, -1.7, -3.0, 6.8, FZ + 0.15, FZ + 5.4)
    CLEAR(9.5, 18.8, iy0 + 0.8, sy0 - 0.1, FZ + 0.15, FZ + 5.4)     # 앞 창 안 틀(0.4) 비켜
    CLEAR(13.2, 18.2, sy1 + 0.2, iy1 - 0.2, Z2 + 0.15, Z2 + 5.6)    # 옆 창 안 틀 비켜


# ------------------------------------------------------------------ 뜰 다섯 + 은행 시세판
def horseshoe_icon(g, x, y, z, face=-1):
    y0, y1 = _yy(y, face)
    for k in range(7):
        a0, a1 = math.pi * k / 7, math.pi * (k + 1) / 7
        pts = [(x + 0.9 * math.cos(a0), z + 0.9 + 0.9 * math.sin(a0)), (x + 0.9 * math.cos(a1), z + 0.9 + 0.9 * math.sin(a1)),
               (x + 0.55 * math.cos(a1), z + 0.9 + 0.55 * math.sin(a1)), (x + 0.55 * math.cos(a0), z + 0.9 + 0.55 * math.sin(a0))]
        prism_xz(g, "Steel", pts[::-1], y0, y1)
    for s in (-1, 1):
        prism_xz(g, "Steel", [(x + s * 0.55, z), (x + s * 0.9, z), (x + s * 0.9, z + 0.9), (x + s * 0.55, z + 0.9)][::(1 if s > 0 else -1)], y0, y1)


def yard_base(g, W, D, mat="Stone"):
    g[mat].box(0, 0, 0.1, W, D, 0.2)
    C(0, 0, 0.1, W, D, 0.2)


def yard_enhance(g):
    """룬 시험대: 룬 돌 기둥 셋(돌 기둥 · 검은 룬 돌 · 청록 글자) · 그을린 과녁 · 쓰고 남은 돌덩이 더미 · 돌 걸상 · 간판"""
    W, D = 20.0, 12.0
    yard_base(g, W, D)
    for x in (-6.0, 0.0, 6.0):
        g["StoneTrim"].box(x, 2.0, 2.2, 1.8, 1.8, 4.0)
        g["DarkStone"].obox(x, 2.0, 5.0, 1.0, 1.2, 1.6, rz=0.3)
        g["GlowTeal"].obox(x, 2.0, 5.0, 1.05, 0.4, 0.8, rz=0.3)
        g["LampPt"].box(x, 1.2, 5.0, 0.3, 0.3, 0.3)
        S.ring(g, "Brass", x, 2.0, 0.2, 1.4, 1.7, 0.06, n=16)
        C(x, 2.0, 2.2, 1.8, 1.8, 4.0)
    g["Timber"].box(7.8, -3.0, 2.6, 0.4, 0.4, 5.2)
    g["Iron"].box(7.8, -3.2, 3.6, 1.6, 0.2, 2.0)
    g["Soot"].box(7.8, -3.32, 3.6, 1.0, 0.06, 1.2)
    C(7.8, -3.0, 2.6, 1.6, 0.6, 5.2)
    ore_lumps(g, -7.0, -2.6, 0.2, r=1.3, n=9, seed=31, mats=("Stone", "StoneTrim"))
    C(-7.0, -2.6, 0.9, 2.6, 2.6, 1.6)
    g["StoneTrim"].box(0, 4.8, 1.0, 4.0, 1.2, 0.4)
    snow(g, 0, 4.8, 1.2, 3.8, 1.0, t=0.12)
    for x in (-1.5, 1.5):
        g["StoneTrim"].box(x, 4.8, 0.5, 0.6, 1.0, 0.8)
    C(0, 4.8, 0.65, 4.0, 1.2, 1.3)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: rune_icon(q, x, y, z - 0.25, face=f))


def yard_bank(g):
    """오늘의 시세판: 쇠 기둥 둘 · 양면 검은 판(금색·청록 숫자 줄) · 놋쇠 지붕 · 걸상 둘 · 화분"""
    W, D = 16.0, 10.0
    yard_base(g, W, D, mat="StoneTrim")
    for x in (-5.8, 5.8):
        g["Iron"].box(x, 0, 4.5, 0.5, 0.5, 9.0)
    g["Brass"].box(0, 0, 6.0, 12.0, 0.5, 5.4)
    g["DarkStone"].box(0, 0, 6.0, 11.4, 0.6, 4.8)
    for f in (-1, 1):
        y = f * 0.32
        for j in range(5):
            z = 7.8 - j * 0.9
            g["Dial"].box(-3.5, y, z, 3.4, 0.04, 0.38)
            for k in range(3):
                g["SignGold" if (j + k) % 2 else "GlowTeal"].box(0.6 + k * 1.7, y, z, 1.1, 0.04, 0.34)
    g["RoofMetal"].box(0, 0, 9.1, 13.0, 1.6, 0.25)
    g["SnowCap"].box(0, 0, 9.35, 12.6, 1.3, 0.25)
    C(0, 0, 4.5, 12.0, 0.6, 9.0)
    for x in (-4.5, 4.5):
        bench(g, x, 3.6, 0.2, 4.0, axis="x", mat="Wood")
        snow(g, x, 3.6, 1.82, 3.6, 1.3, t=0.1)
    for x in (-7.0, 7.0):
        potted_plant(g, x, -4.0, 0.2, s=0.9)


def yard_inn(g):
    """마구간: 나무 뒤 벽·옆 벽 · 칸막이 셋(칸 넷) · 경사 함석 지붕 + 눈 · 칸마다 뒤 건초 · 여물통 · 안장 걸이 · 건초 더미 · 편자 간판"""
    W, D = 26.0, 14.0
    yard_base(g, W, D, mat="Wood")
    g["Timber"].box(0, 6.7, 4.6, 24.0, 0.6, 8.8)
    for x in (-12.0, 12.0):
        g["Timber"].box(x, 3.0, 4.6, 0.6, 8.0, 8.8)
        C(x, 3.0, 4.6, 0.6, 8.0, 8.8)
    C(0, 6.7, 4.6, 24.0, 0.6, 8.8)
    for x in (-6.0, 0.0, 6.0):
        g["Wood"].box(x, 3.7, 2.4, 0.4, 5.4, 4.4)
        g["Timber"].box(x, 1.0, 3.5, 0.5, 0.5, 6.6)
        C(x, 3.7, 2.4, 0.4, 5.4, 4.4)
    g["RoofMetal"].obox(0, 2.6, 9.6, 25.6, 9.6, 0.3, rx=0.18)
    g["SnowCap"].obox(0, 2.7, 9.95, 25.0, 9.0, 0.3, rx=0.18)
    for x in (-12.0, 12.0):
        g["Timber"].box(x, -1.4, 4.4, 0.5, 0.5, 8.6)
    for cx in (-9.0, -3.0, 3.0, 9.0):
        g["SignGold"].obox(cx, 6.0, 0.6, 3.6, 0.8, 0.8, rz=0.05)
        g["Timber"].box(cx, 6.2, 4.5, 3.0, 0.6, 1.4)
        g["SignGold"].box(cx, 6.1, 5.0, 2.8, 0.4, 0.5)
        C(cx, 6.0, 0.6, 3.6, 0.8, 0.8)
    g["Wood"].box(-8.0, -4.0, 1.0, 6.0, 1.2, 1.4)
    g["Glass"].box(-8.0, -4.0, 1.62, 5.6, 0.9, 0.08)
    C(-8.0, -4.0, 0.9, 6.0, 1.2, 1.4)
    g["Timber"].box(-3.2, -4.6, 1.8, 1.4, 0.3, 0.3)
    for x in (-3.8, -2.6):
        g["Timber"].box(x, -4.6, 1.0, 0.2, 0.6, 1.6)
    g["Leather"].obox(-3.2, -4.6, 2.15, 1.2, 1.0, 0.45, rx=0.1)
    C(-3.2, -4.6, 1.2, 1.4, 0.8, 2.0)
    for k, (x, y, z) in enumerate(((4.5, -4.5, 0.2), (6.0, -4.6, 0.2), (5.2, -4.5, 1.2))):
        g["SignGold"].box(x, y, z + 0.5, 1.4, 1.0, 1.0)
        g["Timber"].box(x, y, z + 0.5, 1.45, 1.05, 0.12)
    C(5.2, -4.5, 1.2, 3.0, 1.2, 2.0)
    for x in (-6.0, 6.0):                                                  # 마구간 안 등 둘(지붕 밑이 어두웠다)
        lantern(g, x, 2.2, 9.2, 6.4)
    NPC(9.0, -4.0, 0.2, 0.0)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: horseshoe_icon(q, x, y, z - 0.2, face=f))


def yard_potion(g):
    """약초밭: 돋운 나무 밭 넷(흙 · 풀 덩이 · 꽃) · 작은 유리 온상 · 물통 · 물뿌리개 · 병 간판"""
    W, D = 20.0, 16.0
    yard_base(g, W, D, mat="Stone")
    import random
    rnd = random.Random(5)
    for i, x in enumerate((-7.5, -2.5, 2.5, 7.5)):
        g["Timber"].box(x, 1.5, 0.6, 3.0, 11.0, 0.8)
        g["Char"].box(x, 1.5, 1.02, 2.7, 10.7, 0.05)
        for k in range(8):
            y = -3.4 + k * 1.35
            sphere(g, ("Felt", "PaintGreen", "Felt")[(i + k) % 3], (x + rnd.uniform(-0.4, 0.4), y, 1.35), rnd.uniform(0.45, 0.6), sub=1)
            if (i + k) % 2:
                sphere(g, ("SignPurple", "SignRed", "SignGold")[i % 3], (x + rnd.uniform(-0.3, 0.3), y, 1.9), 0.2, sub=1)
        C(x, 1.5, 0.6, 3.0, 11.0, 1.0)
    g["Timber"].box(7.0, -6.0, 0.6, 3.6, 2.4, 0.8)
    g["WinGlass"].obox(7.0, -6.0, 1.4, 3.4, 2.2, 0.08, rx=0.3)
    C(7.0, -6.0, 0.7, 3.6, 2.4, 1.4)
    barrel(g, -8.2, -6.0, 0.2, r=0.8, h=1.9)
    g["Copper"].cyl(-6.6, -6.4, 0.2, 0.4, 0.35, 0.7, seg=10)
    g["Copper"].obox(-6.0, -6.4, 0.75, 0.6, 0.1, 0.1, ry=-0.6)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: flask_icon(q, x, y, z - 0.3, face=f))


def pine_tree(g, x, y, z0, h=7.0):
    g["Timber"].cyl(x, y, z0, 0.3, 0.25, 1.6, seg=8)
    for k in range(3):
        zb = z0 + 1.2 + k * (h - 1.6) / 3
        r = 2.0 - k * 0.5
        g["Felt"].cyl(x, y, zb, r, 0.1, (h - 1.2) / 2.2, seg=10)
        g["SnowCap"].cyl(x, y, zb + (h - 1.2) / 2.2 * 0.5, r * 0.55, 0.05, (h - 1.2) / 4.4, seg=10)


def yard_hospital(g):
    """회복 정원: 디딤돌 길(뒷문 → 가운데) · 가운데 화단 + 눈 덮인 작은 전나무 · 걸상 셋 · 등 기둥 둘 · 심장 간판"""
    W, D = 20.0, 16.0
    yard_base(g, W, D, mat="StoneTrim")
    g["Felt"].box(0, 0, 0.25, W - 1.0, D - 1.0, 0.06)
    for k in range(4):
        g["Stone"].box(0, -7.0 + k * 1.6, 0.3, 1.6, 1.0, 0.06)
    g["StoneTrim"].box(0, 2.0, 0.95, 4.0, 4.0, 1.5)
    g["Char"].box(0, 2.0, 1.72, 3.6, 3.6, 0.05)
    pine_tree(g, 0, 2.0, 1.7, h=6.5)
    C(0, 2.0, 0.95, 4.0, 4.0, 1.5)
    for x in (-7.5, 7.5):
        bench(g, x, 2.0, 0.2, 5.0, axis="y", mat="Wood")
        snow(g, x, 2.0, 1.82, 1.3, 4.6, t=0.1)
    bench(g, 0, 6.8, 0.2, 5.0, axis="x", mat="Wood")
    snow(g, 0, 6.8, 1.82, 4.6, 1.3, t=0.1)
    for x in (-5.0, 5.0):
        g["Iron"].box(x, -5.0, 2.8, 0.25, 0.25, 5.6)
        lantern(g, x, -5.0, 6.3, 5.0)
        lamp_snow(g, x, -5.0, 5.0)
        C(x, -5.0, 2.8, 0.5, 0.5, 5.6)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: heart_icon(q, x, y, z - 0.3, face=f))


def yard_general(g):
    """노점 칸: 가운데 길(폭 6.5)을 사이에 두고 셋씩 — 나무 판매대 · 줄무늬 천 지붕(색 셋) · 물건 · 자루 간판"""
    W, D = 28.0, 16.0
    yard_base(g, W, D, mat="Stone")
    colors = ("SignBlue", "SignRed", "SignGold")
    for y, s in ((-4.0, -1), (4.0, 1)):
        for i, x in enumerate((-9.0, 0.0, 9.0)):
            g["Wood"].box(x, y, 1.95, 5.0, 1.5, 3.5)
            g["Timber"].box(x, y, 3.8, 5.3, 1.8, 0.2)
            C(x, y, 1.95, 5.3, 1.8, 3.7)
            goods_row(g, x - 2.3, x + 2.3, y, 3.9, seed=80 + i + (s > 0) * 3, depth=1.2)
            for xx in (x - 2.4, x + 2.4):
                g["Timber"].box(xx, y + s * 2.4, 4.1, 0.25, 0.25, 7.8)
            for k in range(5):
                g[colors[i] if k % 2 else "Canvas"].obox(x - 2.4 + (k + 0.5) * 0.96, y + s * 0.9, 7.9, 0.96, 3.6, 0.12, rx=s * 0.3)
    yard_sign(g, -W / 2 + 1.0, -D / 2 + 0.6, lambda q, x, y, z, f: sack_icon(q, x, y, z - 0.3, face=f))

JOBS = [
    ("Svc_Smithy", "SvcSmithy", job("Svc_Smithy", svc_smithy, cut=T)),
    ("Yard_Smithy", "YdSmithy", job("Yard_Smithy", yard_smithy)),
    ("Svc_Enhance", "SvcEnh", job("Svc_Enhance", svc_enhance, cut=T)),
    ("Svc_Potion", "SvcPot", job("Svc_Potion", svc_potion, cut=T)),
    ("Svc_General", "SvcGen", job("Svc_General", svc_general, cut=T)),
    ("Svc_Bank", "SvcBank", job("Svc_Bank", svc_bank, cut=T)),
    ("Svc_Hospital", "SvcHosp", job("Svc_Hospital", svc_hospital, cut=T)),
    ("Svc_Inn", "SvcInn", job("Svc_Inn", svc_inn, cut=T)),
    ("Yard_Enhance", "YdEnh", job("Yard_Enhance", yard_enhance)),
    ("Yard_Bank", "YdBank", job("Yard_Bank", yard_bank)),
    ("Yard_Inn", "YdInn", job("Yard_Inn", yard_inn)),
    ("Yard_Potion", "YdPot", job("Yard_Potion", yard_potion)),
    ("Yard_Hospital", "YdHosp", job("Yard_Hospital", yard_hospital)),
    ("Yard_General", "YdGen", job("Yard_General", yard_general)),
]
