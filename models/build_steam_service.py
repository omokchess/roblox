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
from build_steam_obs import sphere  # noqa: E402
from build_steam_inside import (C, PROP, NPC, job, box2, lantern, coal_bed, armor_stand,  # noqa: E402
                                DOORWAY, CLEAR)

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


def quoins(g, W, D, z0, z1, step=3.6):
    """모서리 돌(엇갈려 쌓은 띠돌)"""
    k = 0
    z = z0 + 0.9
    while z < z1 - 0.9:
        for sx in (-1, 1):
            for sy in (-1, 1):
                g["StoneTrim"].box(sx * (W / 2 + 0.05), sy * (D / 2 + 0.05), z, 1.6 if k % 2 else 1.1, 1.1 if k % 2 else 1.6, 1.8)
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
    g["Wood"].box(bx, fy, 2.65, 2.0, 2.6, 0.2)
    g["Leather"].obox(bx, fy, 3.05, 1.8, 2.4, 0.6, rx=0.08)
    g["Wood"].obox(bx, fy, 3.45, 2.0, 2.8, 0.16, rx=0.18)
    g["Wood"].obox(bx, fy + 1.6, 4.0, 0.16, 0.16, 1.4, rx=0.3)
    g["Brass"].hcyl(fx - 3.6, fy - 0.4, 3.1, 0.18, 0.8, axis="x", seg=10)
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
    g["Iron"].obox(x + 1.15, y, 2.4, 0.12, 0.12, 0.9, rx=0.0)
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
    # 트임: 띠돌 기둥 · 리벳 박은 쇠 들보 · 밀어 연 쇠문 둘(겉, 레일)
    fy = -D / 2
    for s in (-1, 1):
        g["StoneTrim"].box(s * 7.45, fy - 0.15, FZ + 5.5, 0.9, 0.7, 11.0)
    g["Iron"].box(0, fy - 0.3, FZ + 11.5, 15.6, 0.6, 1.0)
    for z in (FZ + 11.05, FZ + 11.95):
        g["IronLight"].box(0, fy - 0.42, z, 15.8, 0.8, 0.16)
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
    S.pipe(g, [(tx - 1.4, ty, 6.0), (W / 2, ty, 6.0)], 0.4, mat="Iron")
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
    C(-1.2, -5.5, 2.8, 0.5, 0.5, 5.6)


JOBS = [
    ("Svc_Smithy", "SvcSmithy", job("Svc_Smithy", svc_smithy, cut=T)),
    ("Yard_Smithy", "YdSmithy", job("Yard_Smithy", yard_smithy)),
]
