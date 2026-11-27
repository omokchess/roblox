# -*- coding: utf-8 -*-
"""
b_smithy.py — 2026-11-13. 설원 마을 3판 시범 1호: 대장간(장비 제작). 공용 부품 lib.py 의 본보기 건물.

레퍼런스(회사/설원마을_레퍼런스.md 2절): 핀스터라우 마을 대장간(통나무 벽·낮은 들보·돌 화덕 + 후드·나무 등걸 위 모루),
뷤플리츠 대장간(화덕 후드에 집게를 줄지어 검), 포트 밴쿠버(화덕에서 바로 올라가는 계단식 굴뚝),
뮌스터 뮐렌호프 대장간(앞 박공 · 문 위 모루 표지 · 바깥 쇠막대), 뢰로스·발저 집(통나무 모서리 짜임·돌 밑단·처마벽 옆 굴뚝).

배치(블렌더, 앞 = -y, 바닥 FZ = 2):
  몸채 벽 가운데 선 x ±15 · y -12..12 (벽 두께 1.2) → 안 28.8 × 22.8, 천장(평보 밑) 11
  앞 작업 마루(지붕 아래, 기둥 둘 + 앞 트러스) y -16..-12, 앞 계단 폭 14(한 단 1, 디딤 1.5)
  정문 x -5.2..5.2 높이 10(밖으로 접어 연 널문 둘) → 입구 완충 y -11.4..-6 → 오른쪽 카운터 x 3..13 · y 4..6.5, 앞 빈 바닥 x 3..13 · y -6..4
  왼 벽: 화덕(x -14.4..-9.4 · y 1..8, 윗면 FZ+3, 숯불 FIRE) + 계단식 돌 후드 → 왼 벽을 뚫고 나간 굴뚝(땅에서, 처마 옆으로 지붕 위까지)
         풀무(화덕 뒤) · 석탄 통 · 담금질 통(화덕 앞) / 가운데 왼: 모루(-6, 4)
  뒷벽: 왼 = 무기 걸이(x -11..-2), 오른 = 완성품 선반(x 2.4..13.6) · NPC 카운터 뒤(8, 8.6)
  바깥: 왼 뒤 증기 통(구리)+압력계 → 관이 왼 벽을 지나 풀무로(증기 송풍) · 오른 기둥 쇠 팔 모루 간판 · 앞 트러스 밑 큰 모루 판
변형(사양 6절): SMITHY_VARIANT=A 통나무 벽(뢰로스·알프스, 물매 40) | B 돌 아랫벽 + 굵은 뼈대 + 판벽(검은 숲, 물매 50). 기본 = DEFAULT
"""
import math
import os

from mathutils import Matrix

import lib as K
import lib_int1 as P
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Smithy"
PREFIX = "Sn3Smithy"
DEFAULT = "A"
VARIANT = os.environ.get("SMITHY_VARIANT", DEFAULT).upper()

WX, YF, YB = 15.0, -12.0, 12.0          # 벽 가운데 선
T = LOG
HALF = WX + T / 2                        # 벽 바깥면 반폭 15.6
XI, YI0, YI1 = WX - T / 2, YF + T / 2, YB - T / 2     # 안쪽 면 ±14.4, -11.4, 11.4
Z_PLATE = FZ + CEIL + 0.9                # 벽 윗면 = 평보 윗면(평보 밑 = 천장 11)
PORCH_Y = -16.0                          # 앞 작업 마루 앞 끝
TRUSS_Y = -15.5                          # 앞 트러스·마루 기둥 줄
FORGE = (-XI, -9.4, 1.0, 8.0)            # 화덕 x0 x1 y0 y1(왼 벽에 붙음, 앞면 = +x)
STACK = (-17.0, -12.8, 2.6, 6.4)         # 굴뚝 x0 x1 y0 y1(왼 벽을 뚫고 밖으로 1.4)
WIN_L, WIN_R, WIN_F, WIN_B = (-6.0,), (-6.0, 6.0), (-12.2, 12.2), (8.0,)


def walls(g, R):
    wz0 = FZ + WIN_SILL
    hole = lambda u, z0=wz0: (u - WIN_W / 2, u + WIN_W / 2, z0, z0 + K.WIN_H)    # noqa: E731
    door = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    plan = (("x", YF, [door] + [hole(u) for u in WIN_F], 0, -1),
            ("x", YB, [hole(u, FZ + 5.5) for u in WIN_B], 0, 1),
            ("y", -WX, [hole(u) for u in WIN_L] + [(STACK[2], STACK[3], FZ, 99.0)], 1, -1),
            ("y", WX, [hole(u) for u in WIN_R], 1, 1))
    for ax, c, holes, par, face in plan:
        u0, u1 = (-WX, WX) if ax == "x" else (YF, YB)
        if VARIANT == "A":
            K.log_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, parity=par)
        else:
            K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=FZ + 4.0, face=face)
    for u in WIN_F:
        K.window(g, "x", YF, u, wz0, face=-1, shutters=False)     # 앞 창은 열린 문짝이 덮으니 덧창 없음
    for u in WIN_B:
        K.window(g, "x", YB, u, FZ + 5.5, face=1)
    for u in WIN_L:
        K.window(g, "y", -WX, u, wz0, face=-1)
    for u in WIN_R:
        K.window(g, "y", WX, u, wz0, face=1)
    # 박공(앞 = 몸채 앞벽 위, 뒤 = 뒷벽 위). 지붕 밑선 아래까지만 — 도리가 그 위에 얹힌다
    top = lambda m: R.zb(m) - 0.05      # noqa: E731
    for c, face in ((YF, -1), (YB, 1)):
        if VARIANT == "A":
            K.gable_logs(g, "x", c, HALF, Z_PLATE, top)
        else:
            K.gable_boards(g, "x", c, HALF, Z_PLATE, top, face=face)
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=170.0)


def porch(g, R):
    """앞 작업 마루: 기둥 둘(받침돌) + 까치발 + 앞 트러스(평보·동자기둥) — 처마도리·중도리·마룻대 앞끝을 받친다"""
    ztb = Z_PLATE - 0.9
    for s in (-1, 1):
        x = s * (HALF - 0.5)
        K.post(g, x, TRUSS_Y, FZ, ztb, s=1.0)
        K.brace(g, "x", TRUSS_Y, x - s * 0.5, ztb - 2.6, x - s * 3.0, ztb, s=0.5)     # 까치발(기둥 → 평보)
    K.tie_truss(g, TRUSS_Y, R)
    # 앞 트러스 밑 큰 모루 판(쇠 막대 둘로 평보에 매닮)
    for x in (-2.6, 2.6):
        bx(g, "Iron", x - 0.06, x + 0.06, TRUSS_Y - 0.06, TRUSS_Y + 0.06, FZ + 10.2, ztb)
    bx(g, "Timber", -3.6, 3.6, TRUSS_Y - 0.15, TRUSS_Y + 0.15, FZ + 8.0, FZ + 10.2)
    bx(g, "Brass", -3.75, 3.75, TRUSS_Y - 0.2, TRUSS_Y + 0.2, FZ + 10.15, FZ + 10.35)
    bx(g, "SnowCap", -3.6, 3.6, TRUSS_Y - 0.18, TRUSS_Y + 0.18, FZ + 10.35, FZ + 10.47)
    K.SVC.anvil_icon(g, -0.3, TRUSS_Y - 0.15, FZ + 8.55, s=1.05, face=-1)
    K.SVC.anvil_icon(g, -0.3, TRUSS_Y + 0.15, FZ + 8.55, s=1.05, face=1)
    # 오른 기둥 쇠 팔 간판(길에서 옆으로 읽힌다)
    K.hang_sign(g, HALF, TRUSS_Y, FZ + 8.6, along="x", icon=lambda g_, x, y, z, f: K.SVC.anvil_icon(g_, x - 0.25, y, z, s=0.75, face=f))
    # 마루 위 바깥 일감: 왼 = 쇠막대 꽂은 통
    barrel(g, -12.6, -14.2)
    for k in range(5):
        g["Iron"].obox(-12.6 + 0.3 * math.cos(k * 1.3), -14.2 + 0.3 * math.sin(k * 1.3), FZ + 2.6, 0.12, 0.12, 3.0, rx=0.08 * (k - 2), ry=0.06 * (2 - k))
    # 문 옆 바깥 등(트러스 평보에 매닮)
    for x in (-8.0, 8.0):
        K.lantern(g, x, TRUSS_Y, ztb, FZ + 8.4)


def barrel(g, x, y, z0=FZ, r=0.8, h=2.3):
    P.barrel(g, x, y, z0, r=r, h=h, lid=False)
    g["Char"].cyl(x, y, z0 + h - 0.5, r - 0.1, r - 0.1, 0.1, seg=12)       # 속(어둠) — 쇠막대를 꽂은 통


def forge(g):
    """화덕: 돌 몸(윗면 FZ+3, 뒤 = 굴뚝 몸이 불막이) · 쇠 테 · 숯불(FIRE) · 앞 재구멍 · 쇠기둥 둘 + 쇠 인방이 받치는 계단식 돌 후드 → 굴뚝"""
    x0, x1, y0, y1 = FORGE
    zt = FZ + 3.0
    K.box2(g, "Stone", x0, x1, y0, y1, FZ, zt - 0.3)
    bx(g, "StoneTrim", x0, x1 + 0.15, y0 - 0.15, y1 + 0.15, zt - 0.3, zt)
    bx(g, "Soot", x1 - 0.4, x1 + 0.05, 3.2, 5.8, FZ + 0.5, FZ + 1.9)                     # 재 구멍
    bx(g, "StoneTrim", x1 - 0.2, x1 + 0.15, 2.8, 6.2, FZ + 1.9, FZ + 2.2)
    cx, cy = -11.0, (STACK[2] + STACK[3]) / 2
    for s in (-1, 1):
        bx(g, "Iron", cx + s * 1.7 - 0.15, cx + s * 1.7 + 0.15, cy - 1.85, cy + 1.85, zt, zt + 0.3)
        bx(g, "Iron", cx - 1.7, cx + 1.7, cy + s * 1.7 - 0.15, cy + s * 1.7 + 0.15, zt, zt + 0.3)
    K.coal_bed(g, cx, cy, zt, 3.2, 3.2, size=1.2)
    bx(g, "Core", cx - 1.2, cx + 1.2, cy - 1.2, cy + 1.2, zt + 0.1, zt + 0.13)          # 숯 사이 불씨 판
    # 숯 무더기(비평 1차 [심각]: 문에서 불이 안 보임) — 쇠 테보다 0.5~0.8 높게 손으로 쌓은 숯 덩이 열하나 + 사이로 드러난 불씨 여섯
    for k, (dx, dy, sz) in enumerate(((-0.9, -0.8, 0.7), (0.2, -1.0, 0.6), (1.0, -0.4, 0.75), (-0.3, 0.1, 0.8), (0.8, 0.7, 0.6), (-1.0, 0.6, 0.65),
                                      (0.1, 1.0, 0.7), (-0.5, -0.3, 0.55), (0.5, 0.0, 0.6), (1.1, 1.1, 0.5), (-1.1, -1.2, 0.5))):
        g["Char"].obox(cx + dx, cy + dy, zt + 0.3 + sz * 0.4, sz, sz * 0.85, sz * 0.7, rz=k * 0.7)
    for dx, dy, sz in ((-0.4, -0.6, 0.45), (0.5, -0.3, 0.5), (0.0, 0.5, 0.45), (-0.8, 0.2, 0.4), (0.7, 0.6, 0.4), (0.3, -1.0, 0.4)):
        g["Core"].obox(cx + dx, cy + dy, zt + 0.75, sz, sz, sz * 0.8, rz=dx)
    bx(g, "Core", STACK[1] + 0.02, STACK[1] + 0.06, cy - 1.2, cy + 1.2, zt + 0.2, zt + 1.8)        # 불 아가리 뒤 굴뚝 몸 앞면 붉은 빛
    bx(g, "Copper", x1 + 0.05, x1 + 0.08, 3.5, 5.5, FZ + 0.7, FZ + 1.4)                          # 재 구멍 속 짙은 주황
    g["LampPt"].box(cx + 1.6, cy, zt + 1.6, 0.3, 0.3, 0.3)                                       # Studio 따뜻한 빛 자리
    # 후드 받침: 화덕 앞 모서리 쇠기둥 둘(화덕 윗면 위) + 쇠 인방
    zh = FZ + 6.6
    for y in (y0 + 0.3, y1 - 0.3):
        bx(g, "Iron", x1 - 0.5, x1 - 0.1, y - 0.2, y + 0.2, zt, zh - 0.4)
    bx(g, "Iron", x1 - 0.5, x1 + 0.1, y0 - 0.2, y1 + 0.2, zh - 0.4, zh)
    # 계단식 돌 후드(켜마다 들임) → 굴뚝 가슴(후드가 받침, 천장까지)
    z = zh
    for k, (b, ya, yb) in enumerate(((x1 + 0.2, y0 - 0.2, y1 + 0.2), (x1 - 0.7, y0 + 0.6, y1 - 0.6), (x1 - 1.6, y0 + 1.2, y1 - 1.2))):
        bx(g, "Stone", x0, b, ya, yb, z, z + 1.0)
        bx(g, "StoneTrim", b - 0.25, b + 0.08, ya - 0.08, yb + 0.08, z + 0.85, z + 1.0)
        z += 1.0
    bx(g, "Stone", x0, STACK[1], STACK[2], STACK[3], z, Z_PLATE - 0.9)
    # 후드 앞 쇠막대 + 집게(후드 돌 면에 걸어 불 아가리를 가리지 않게)
    bx(g, "Iron", x1 + 0.2, x1 + 0.35, y0, y1, zh + 0.75, zh + 0.9)
    for k in range(4):                                                      # 집게 넷(굵기 0.15 — 비평 1차: 가는 선 잡음)
        y = y0 + 1.0 + k * (y1 - y0 - 2.0) / 3
        for d in (-1, 1):
            g["Iron"].obox(x1 + 0.3, y + d * 0.14, zh + 0.15, 0.15, 0.15, 1.4, rx=d * 0.07)
    # 풀무: 화덕 앞(왼 벽) 나무 틀 위 쐐기꼴 — 바람관이 화덕 옆구리(y 1)로 든다(비평 2차 보통 1: 화덕 오른 뒤 옛 자리는 모루와 겹쳐 '통 위 판자 더미'로 읽혔다)
    bellows(g, -13.0, -0.9)
    # 석탄 통(화덕 뒤, 왼 벽 — 풀무에 자리를 내줌)
    K.box2(g, "Iron", -XI + 0.1, -12.3, 8.6, 11.1, FZ, FZ + 1.5)
    for k, (x, y) in enumerate(((-13.6, 9.2), (-12.9, 9.9), (-13.5, 10.5), (-12.9, 9.0), (-13.2, 9.8))):
        g["Char"].obox(x, y, FZ + 1.62, 0.6, 0.5, 0.36, rz=k * 0.9)
    # 담금질 통(석탄 통 앞): 나무 통 + 쇠 띠 + 물
    qx0, qx1, qy0, qy1 = -XI + 0.2, -11.4, -5.4, -2.6
    K.box2(g, "Timber", qx0, qx1, qy0, qy1, FZ, FZ + 2.2)
    for z in (FZ + 0.5, FZ + 1.7):
        bx(g, "Iron", qx0 - 0.05, qx1 + 0.05, qy0 - 0.05, qy1 + 0.05, z, z + 0.15)
    bx(g, "Soot", qx0 + 0.2, qx1 - 0.2, qy0 + 0.2, qy1 - 0.2, FZ + 2.21, FZ + 2.26)          # 짙은 물(비평 1차: 흰 뚜껑처럼 보임)


def bellows(g, x, y):
    """큰 풀무(2.4×3.0, 비평 2차 보통 1): 나무 틀(높이 2 — 다리 넷·가름대) 위 쐐기꼴. 아래판 Timber · 가죽 주름 다섯 켜(켜마다 0.1 들여 넣기,
    위 켜일수록 바람관 쪽이 짧다) · 바람관 쪽이 낮은 들린 윗판 Timber · 뒤 끝 손잡이 막대 1.5 · 놋쇠 바람관(0.25)이 +y 화덕 옆구리로"""
    yn, yb = y + 1.5, y - 1.5                     # 바람관 쪽(+y, 화덕) · 뒤 끝
    zb = FZ + 2.0
    for dx in (-1.0, 1.0):
        for dy in (-1.3, 1.3):
            bx(g, "Timber", x + dx - 0.15, x + dx + 0.15, y + dy - 0.15, y + dy + 0.15, FZ, zb)
        bx(g, "Timber", x + dx - 0.1, x + dx + 0.1, y - 1.3, y + 1.3, FZ + 0.6, FZ + 0.8)
    pear = [(-0.85, -1.5), (0.85, -1.5), (1.2, -1.2), (1.2, -0.2), (0.6, 1.1), (0.25, 1.5), (-0.25, 1.5), (-0.6, 1.1), (-1.2, -0.2), (-1.2, -1.2)]

    def outline(ymax, ins):                       # 배 꼴 판(바람관 쪽이 좁다) — y 를 ymax 로 자르고 x 를 ins 만큼 들임
        pts = []
        for px, py in pear:
            q = (x + px * (1.2 - ins) / 1.2, y + min(py, ymax))
            if not pts or abs(q[0] - pts[-1][0]) + abs(q[1] - pts[-1][1]) > 1e-3:
                pts.append(q)
        return pts if abs(pts[0][0] - pts[-1][0]) + abs(pts[0][1] - pts[-1][1]) > 1e-3 else pts[:-1]
    P.prism(g, "Timber", outline(1.5, 0.0), zb, zb + 0.2)                                    # 아래판
    lo, hi = zb + 0.4, zb + 1.4                                                               # 윗판 높이: 바람관 끝 · 뒤 끝
    for k in range(5):                                                                        # 주름 켜(아코디언: 홀수 켜 0.1 들임, 위 켜일수록 바람관 쪽이 짧다)
        z0 = zb + 0.2 + k * 0.2
        yk = min(1.4, 1.5 - (z0 + 0.2 - lo) / (hi - lo) * 3.0)
        P.prism(g, "Leather", outline(yk, 0.1 if k % 2 else 0.0), z0, z0 + 0.2)
    ang = math.atan2(hi - lo, yn - yb)
    L_ = math.hypot(yn - yb, hi - lo)
    K.L.transformed(g, Matrix.Translation((0, yn, lo)) @ Matrix.Rotation(-ang, 4, "X") @ Matrix.Translation((0, -yn, 0)),
                    lambda q: P.prism(q, "Timber", [(x + px, yn - (1.5 - py) * L_ / 3.0) for px, py in pear], 0.0, 0.2))   # 윗판(뒤가 들림)
    g["Iron"].obox(x, yb - 0.55, hi + 0.25, 0.2, 1.5, 0.2, rx=-0.45)                         # 손잡이 막대 1.5
    g["Iron"].obox(x, yb - 1.25, hi + 0.55, 0.9, 0.18, 0.18, rx=-0.45)                       # 손잡이 가로대
    g["Brass"].hcyl(x, (yn + FORGE[2]) / 2 + 0.2, zb + 0.35, 0.125, FORGE[2] - yn + 0.6, axis="y", seg=10)   # 바람관(화덕 앞 옆면 y 1 로)
    g["Brass"].hcyl(x, yn + 0.05, zb + 0.35, 0.22, 0.2, axis="y", seg=10)                    # 관 목
    cbox(x - 1.2, x + 1.2, yb, yn, FZ, hi + 0.4)


def smithy_counter(g, x0, x1, y0, y1):
    """대장간 카운터(비평 1차: 세 채가 같은 틀): 두꺼운 세로 널(DarkLog/Timber 0.4) · 쇠 띠 둘 · 모서리 쇠 꺾쇠 · 앞에 건 편자 셋·집게 · 두꺼운 상판"""
    zt = FZ + K.COUNTER_H
    bx(g, "Timber", x0 + 0.2, x1 - 0.2, y0 + 0.3, y1 - 0.1, FZ, zt - 0.4)
    n = int(round((x1 - x0) / 1.1))
    for i in range(n):
        a = x0 + (x1 - x0) * i / n
        bx(g, "DarkLog" if i % 2 else "Timber", a + 0.02, a + (x1 - x0) / n - 0.02, y0 - 0.05, y0 + 0.3, FZ, zt - 0.4)
    for zz in (FZ + 0.6, zt - 1.0):
        bx(g, "Iron", x0, x1, y0 - 0.12, y0 - 0.05, zz, zz + 0.15)
    for xx in (x0, x1):
        for zz in (FZ, zt - 0.55):
            bx(g, "Iron", xx - 0.12, xx + 0.12, y0 - 0.12, y0 + 0.6, zz, zz + 0.55)
    for k, xx in enumerate((x0 + 2.0, x0 + 3.4, x0 + 7.6)):
        for a in range(5):
            ang = math.pi * (a / 4.0)
            g["Iron"].obox(xx + 0.32 * math.cos(ang), y0 - 0.09, FZ + 1.8 + 0.32 * math.sin(ang), 0.2, 0.07, 0.14, ry=-ang)
    P.tongs(g, x0 + 5.6, y0 - 0.09, zt - 0.5, rz=0.0, s=0.8)
    bx(g, "Wood", x0 - 0.1, x1 + 0.1, y0 - 0.14, y1 + 0.15, zt - 0.4, zt)
    cbox(x0 - 0.1, x1 + 0.1, y0 - 0.14, y1 + 0.15, FZ, zt)
    return zt


def smithy_extra(g):
    """바닥 돌판(세 톤, 3~4 크기 손 표) + 화덕 앞 검댕 · 뒷벽(걸이 오른쪽 위) 엇갈린 큰 칼 둘 + 모루 간판 · 평보(y 0)에 매단 편자 묶음·사슬"""
    rows = [(3.4, [3.6, 2.8, 4.0, 3.2, 3.8, 2.6, 3.4, 4.2]), (3.8, [2.4, 3.9, 3.0, 4.1, 2.7, 3.6, 3.3, 4.0]),
            (3.0, [3.3, 4.2, 2.6, 3.5, 4.0, 2.9, 3.7, 3.6]), (4.0, [4.0, 2.9, 3.6, 2.8, 3.9, 3.2, 3.5, 3.9]),
            (3.5, [2.9, 3.4, 4.1, 3.0, 2.8, 4.0, 3.3, 4.3]), (3.6, [3.8, 3.1, 2.7, 4.2, 3.5, 2.9, 3.9, 3.7]),
            (3.6, [3.2, 4.0, 3.4, 2.8, 4.1, 3.3, 3.0, 4.0])]
    bx(g, "Mortar", -XI, XI, YI0, YI1, FZ + 0.01, FZ + 0.035)              # 줄눈 바탕(비평 2차 보통 2: 줄눈 없이 밝은 회색·검정이 맞붙어 얼룩처럼 읽혔다)
    P.slab_floor(g, -XI, XI, YI0, YI1, FZ, rows, ("Stone", "StoneB", "RockC", "StoneB", "Stone", "RockC"), gap=0.1)   # 세 톤 좁힘(85·75·74 — 검정·밝은 회색 뺌)
    bx(g, "Soot", FORGE[1], FORGE[1] + 2.6, FORGE[2] - 0.6, FORGE[3] + 0.4, FZ + 0.05, FZ + 0.07)
    for k, a in enumerate((0.7, -0.7)):                                    # 엇갈린 큰 칼(뒷벽, 걸이 오른쪽 x 0 언저리)
        g["Steel"].obox(0.2, YI1 - 0.15, FZ + 7.6, 0.4, 0.1, 4.2, ry=a)
        g["Iron"].obox(0.2, YI1 - 0.22, FZ + 7.6, 0.08, 0.05, 3.9, ry=a)
        hx, hz = 0.2 - math.sin(a) * 2.3, FZ + 7.6 - math.cos(a) * 2.3
        g["Brass"].obox(hx, YI1 - 0.2, hz, 1.1, 0.16, 0.18, ry=a)
        g["Leather"].obox(hx - math.sin(a) * 0.55, YI1 - 0.2, hz - math.cos(a) * 0.55, 0.22, 0.2, 0.9, ry=a)
    bx(g, "Timber", -1.4, 1.8, YI1 - 0.2, YI1, FZ + 9.9, FZ + 11.4)
    bx(g, "Brass", -1.5, 1.9, YI1 - 0.25, YI1 - 0.05, FZ + 9.8, FZ + 9.9)
    K.SVC.anvil_icon(g, 0.1, YI1 - 0.2, FZ + 10.1, s=0.75, face=-1)
    for x, kind in ((4.5, "shoe"), (7.5, "chain"), (10.5, "shoe")):          # 평보(y 0)에 매단 것 — 바닥 위 7 이상
        bx(g, "Iron", x - 0.04, x + 0.04, -0.04, 0.04, FZ + 9.0, Z_PLATE - 0.9)
        if kind == "shoe":                                                  # 쇠고리 하나에 꿴 편자 넷(굵기 0.25 — 비평 2차 사소 5: 회색 점 잡음)
            g["Iron"].hcyl(x, 0.0, FZ + 8.85, 0.3, 0.12, axis="y", seg=10)
            for q, rzq in enumerate((0.0, 0.8, 1.6, 2.4)):
                def shoe(t, q=q):
                    for e in (-1, 1):
                        t["Iron"].box(e * 0.35, 0, -0.55 - 0.05 * q, 0.25, 0.25, 0.9)
                    t["Iron"].box(0, 0, -1.05 - 0.05 * q, 0.95, 0.25, 0.25)
                K.L.transformed(g, Matrix.Translation((x, 0.0, FZ + 8.85)) @ Matrix.Rotation(rzq, 4, "Z"), shoe)
        else:                                                               # 사슬 마디 0.3 블록
            for k in range(6):
                g["Iron"].obox(x, 0.0, FZ + 8.6 - 0.4 * k, 0.3 if k % 2 else 0.12, 0.12 if k % 2 else 0.3, 0.45)
            g["Iron"].obox(x, 0.18, FZ + 6.3, 0.2, 0.6, 0.2, rx=0.6)


def anvil(g, x, y):
    """모루: 쇠 띠 두른 나무 등걸 + 무쇠 받침·허리·윗면 + 뿔 + 꼬리 + 위에 망치·집게"""
    z0 = FZ
    g["Wood"].cyl(x, y, z0, 1.0, 0.92, 1.7, seg=10)                         # 그루터기(지름 2.0 — 비평 2차: 쇠 띠 두른 통처럼 읽혔다)
    g["Timber"].cyl(x, y, z0 + 1.66, 0.86, 0.86, 0.06, seg=10)              # 나이테 면(짙게)
    for k in range(4):                                                      # 뿌리 넷
        a = 0.4 + k * math.pi / 2
        g["Wood"].obox(x + 1.0 * math.cos(a), y + 1.0 * math.sin(a), z0 + 0.2, 0.7, 0.5, 0.4, rz=a, ry=0.5)
    zb = z0 + 1.7
    bx(g, "Iron", x - 0.9, x + 0.9, y - 0.6, y + 0.6, zb, zb + 0.35)
    bx(g, "Iron", x - 0.5, x + 0.5, y - 0.4, y + 0.4, zb + 0.35, zb + 0.85)
    bx(g, "Iron", x - 1.1, x + 0.9, y - 0.5, y + 0.5, zb + 0.85, zb + 1.25)
    g["Iron"].obox(x + 1.6, y, zb + 1.08, 1.4, 0.55, 0.32, ry=0.18)
    g["Iron"].obox(x + 2.35, y, zb + 1.2, 0.6, 0.3, 0.16, ry=0.32)
    bx(g, "Iron", x - 1.55, x - 1.1, y - 0.3, y + 0.3, zb + 1.0, zb + 1.25)
    g["Wood"].obox(x - 0.1, y - 0.2, zb + 1.33, 1.6, 0.14, 0.14, rz=0.4)
    bx(g, "Iron", x - 0.95, x - 0.55, y - 0.65, y - 0.25, zb + 1.25, zb + 1.6)
    cbox(x - 1.6, x + 2.6, y - 1.2, y + 1.2, z0, zb + 1.25)
    P.hammer(g, x + 0.4, y + 0.25, zb + 1.33, rz=0.5, ry=1.45, s=0.95)
    P.tongs(g, x - 1.5, y - 1.05, zb + 1.2, rz=0.2, s=0.8)
    # 사슬 도르래(평보 y 0): 쇠 고리판 · 도르래 통 · 사슬 · 갈고리
    yt = 0.0
    bx(g, "Iron", x - 0.3, x + 0.3, yt - 0.55, yt + 0.55, Z_PLATE - 1.2, Z_PLATE - 0.9)
    g["Iron"].hcyl(x, yt, Z_PLATE - 1.75, 0.45, 0.3, axis="x", seg=12)
    g["Brass"].hcyl(x, yt, Z_PLATE - 1.75, 0.18, 0.4, axis="x", seg=8)
    for k in range(6):
        g["Iron"].obox(x, yt + 0.12, Z_PLATE - 2.4 - 0.5 * k, 0.1, 0.3 if k % 2 else 0.1, 0.45)
    g["Iron"].obox(x, yt + 0.12, Z_PLATE - 5.6, 0.18, 0.18, 0.6)
    g["Iron"].obox(x, yt + 0.35, Z_PLATE - 6.0, 0.16, 0.6, 0.16, rx=0.6)


def workbench(g):
    """앞벽 오른쪽 작업대(문과 창 사이): 상판(두꺼운 Wood) · 다리 넷 + 아래 선반 · 바이스(무쇠 턱 + 나사 막대) · 위 연장 걸이판(망치 셋 · 집게 둘 · 편자 넷)"""
    x0, x1, y0, y1 = 6.4, 10.4, YI0 + 0.05, YI0 + 1.55
    zt = P.table(g, x0, x1, y0, y1, FZ, h=3.0)
    bx(g, "Wood", x0 + 0.4, x1 - 0.4, y0 + 0.35, y1 - 0.35, FZ + 0.7, FZ + 0.85)
    for k, xx in enumerate((7.0, 8.0)):
        bx(g, "Iron", xx - 0.35, xx + 0.35, y0 + 0.5, y1 - 0.4, FZ + 0.85, FZ + 1.25 - 0.1 * k)
    vx = x1 - 0.7
    bx(g, "Iron", vx - 0.35, vx + 0.35, y1 - 0.5, y1 - 0.05, zt, zt + 0.25)
    bx(g, "Iron", vx - 0.4, vx + 0.4, y1 - 0.2, y1 + 0.05, zt + 0.25, zt + 0.8)
    bx(g, "Iron", vx - 0.4, vx + 0.4, y1 + 0.25, y1 + 0.5, zt + 0.25, zt + 0.8)
    g["Steel"].hcyl(vx, y1 + 0.55, zt + 0.5, 0.08, 0.9, axis="y", seg=6)
    g["Iron"].hcyl(vx, y1 + 1.0, zt + 0.5, 0.06, 0.9, axis="x", seg=6)
    bx(g, "Iron", 7.2, 8.4, y0 + 0.4, y0 + 0.9, zt, zt + 0.12)
    P.tool_board(g, "x", YI0, x0 + 0.2, x1 - 1.6, FZ + 4.2, FZ + 7.6, face=1)
    for k, xx in enumerate((6.9, 7.5, 8.1)):
        P.hammer(g, xx, YI0 + 0.4, FZ + 4.8, rz=math.pi / 2, ry=0.0, s=0.75 + 0.1 * k)
    for xx in (8.5, 8.85):
        P.tongs(g, xx, YI0 + 0.35, FZ + 7.3, rz=math.pi / 2, s=0.85)
    for k, xx in enumerate((6.9, 7.5, 8.1, 8.7)):
        for a in range(5):
            ang = math.pi * (a / 4.0)
            g["Iron"].obox(xx + 0.22 * math.cos(ang), YI0 + 0.3, FZ + 6.9 + 0.22 * math.sin(ang), 0.1, 0.08, 0.16, ry=-ang)


def grindstone(g, x, y):
    """숫돌(앞 왼쪽): 나무 틀(다리 넷 · 가로대) · 돌 바퀴(StoneTrim, 굵은 원판) · 쇠 축 · 손잡이 굽은 막대 · 아래 물 받이"""
    for dx in (-0.9, 0.9):
        for dy in (-0.7, 0.7):
            g["Timber"].obox(x + dx, y + dy, FZ + 1.0, 0.22, 0.22, 2.1, rx=dy * 0.08)
        bx(g, "Timber", x + dx - 0.12, x + dx + 0.12, y - 0.8, y + 0.8, FZ + 1.9, FZ + 2.15)
    bx(g, "Timber", x - 1.0, x + 1.0, y - 0.1, y + 0.1, FZ + 0.6, FZ + 0.8)
    g["Stone"].hcyl(x, y, FZ + 3.0, 1.05, 0.45, axis="x", seg=16)          # 숫돌(짙은 돌 — 비평 1차: 거의 흰색)
    g["Iron"].hcyl(x, y, FZ + 3.0, 0.4, 0.5, axis="x", seg=10)
    g["Iron"].hcyl(x, y, FZ + 3.0, 0.1, 2.4, axis="x", seg=6)
    bx(g, "Iron", x + 1.15, x + 1.25, y - 0.05, y + 0.6, FZ + 2.95, FZ + 3.05)
    g["Wood"].hcyl(x + 1.4, y + 0.6, FZ + 3.0, 0.1, 0.5, axis="x", seg=6)
    bx(g, "Timber", x - 0.6, x + 0.6, y - 0.55, y + 0.55, FZ + 1.4, FZ + 1.8)
    bx(g, "Glass", x - 0.5, x + 0.5, y - 0.45, y + 0.45, FZ + 1.8, FZ + 1.82)
    cbox(x - 1.1, x + 1.5, y - 0.9, y + 0.9, FZ, FZ + 4.1)


def _rack_local(g):
    """무기 걸이(제 좌표: 벽 = x -11.4, 걸이는 +x 를 봄, y -11..-2)"""
    xw = -YI1
    bx(g, "Timber", xw, xw + 0.3, -11.0, -2.0, FZ + 0.3, FZ + 6.2)
    for y in (-11.0, -6.5, -2.0):
        bx(g, "DarkLog", xw + 0.3, xw + 0.8, y - 0.25, y + 0.25, FZ, FZ + 6.6)
    bx(g, "Timber", xw + 0.3, xw + 1.4, -11.0, -2.0, FZ + 1.2, FZ + 1.45)
    bx(g, "Iron", xw + 0.8, xw + 0.95, -11.0, -2.0, FZ + 4.6, FZ + 4.75)
    for y in (-10.3, -9.3, -8.3, -7.3):
        K.SVC.sword_hilt_up(g, xw + 0.9, y, FZ + 1.45, blade=3.0)
    for y in (-5.6, -4.6):
        K.SVC.axe_up(g, xw + 0.9, y, FZ + 1.45)
    for y in (-3.4, -2.6):
        K.SVC.spear_up(g, xw + 0.9, y, FZ + 1.45, h=5.6)
    for y in (-8.8, -4.4):
        g["Wood"].hcyl(xw + 0.45, y, FZ + 7.6, 1.1, 0.25, axis="x", seg=16)
        g["Brass"].hcyl(xw + 0.6, y, FZ + 7.6, 0.4, 0.15, axis="x", seg=10)


def racks(g):
    """뒷벽 왼쪽 무기 걸이 — 제 좌표로 지어 -90° 돌림(+x 를 보던 걸이가 -y(방 안)를 본다: 제 (x, y) → (y, -x))"""
    K.L.transformed(g, Matrix.Rotation(-math.pi / 2, 4, "Z"), _rack_local)
    cbox(-11.3, -1.7, YI1 - 1.5, YI1, FZ, FZ + 6.6)


def shop(g):
    """카운터(오른) + 위 물건 + 뒷벽 완성품 선반 + NPC 자리 + 오른 앞 구석 쇠막대 통·상자"""
    zt = smithy_counter(g, 3.0, 13.0, 4.0, 6.5)
    for k, yy in enumerate((4.75, 5.55)):                             # 칼 받침(나무 받침 둘 + 칼 둘 비스듬히)
        for xx in (8.6, 11.4):
            bx(g, "Timber", xx - 0.15, xx + 0.15, yy - 0.2, yy + 0.2, zt, zt + 0.35 + 0.25 * k)
            bx(g, "Wood", xx - 0.2, xx + 0.2, yy - 0.25, yy + 0.25, zt + 0.35 + 0.25 * k, zt + 0.42 + 0.25 * k)
        za = zt + 0.5 + 0.25 * k
        g["Steel"].obox(10.2, yy, za, 3.0, 0.08, 0.26)
        g["Iron"].obox(10.2, yy, za + 0.02, 2.8, 0.1, 0.05)                 # 날 가운데 등줄
        g["Brass"].obox(8.5, yy, za, 0.14, 1.0, 0.14)                       # 코등이 폭 1.0
        g["Leather"].obox(8.0, yy, za, 0.85, 0.16, 0.16)
        g["Brass"].obox(7.5, yy, za, 0.2, 0.22, 0.22)
    bx(g, "Leather", 4.6, 6.2, 4.7, 5.8, zt, zt + 0.16)
    bx(g, "Paint", 4.7, 6.1, 4.8, 5.7, zt + 0.16, zt + 0.2)
    g["Brass"].cyl(12.6, 4.6, zt, 0.32, 0.18, 0.4, seg=12)
    g["Iron"].cyl(12.6, 4.6, zt + 0.4, 0.05, 0.05, 0.2, seg=6)
    for q in range(3):
        for a in range(5):
            ang = math.pi * (a / 4.0)
            g["Iron"].obox(6.9 + 0.3 * math.cos(ang), 5.1 + 0.3 * math.sin(ang) - 0.15, zt + 0.05 + q * 0.1, 0.18, 0.14, 0.08, rz=ang + math.pi / 2)
    NPC(8.0, 8.6, FZ, 0.0)
    yb0, yb1 = YI1 - 1.1, YI1
    for x in (2.6, 8.0, 13.4):
        bx(g, "Timber", x - 0.15, x + 0.15, yb0, yb0 + 0.3, FZ, FZ + 5.2)
    ym = (yb0 + yb1) / 2
    for k, z in enumerate((FZ + 1.4, FZ + 3.0, FZ + 4.6)):
        bx(g, "Wood", 2.4, 13.6, yb0, yb1, z - 0.15, z)
        bx(g, "Timber", 2.4, 13.6, yb0 - 0.05, yb0 + 0.1, z, z + 0.15)
        for j, kind in enumerate(SHOP_ROWS[k]):
            x = 3.3 + j * 1.75
            if kind == "helm":                                   # 투구: 둥근 머리 + 챙 + 코 막이
                g["Steel"].cyl(x, ym, z, 0.55, 0.42, 0.55, seg=12)
                g["Steel"].cyl(x, ym, z + 0.55, 0.42, 0.12, 0.3, seg=12)
                g["Iron"].cyl(x, ym, z, 0.6, 0.6, 0.1, seg=12)
                bx(g, "Iron", x - 0.06, x + 0.06, ym - 0.62, ym - 0.5, z + 0.05, z + 0.6)
            elif kind == "shoe":                                 # 편자 묶음(넷 겹침)
                for q in range(4):
                    for a in range(5):
                        ang = math.pi * (a / 4.0)
                        g["Iron"].obox(x + 0.3 * math.cos(ang), ym + 0.3 * math.sin(ang) - 0.15, z + 0.05 + q * 0.1, 0.18, 0.14, 0.08, rz=ang + math.pi / 2)
            elif kind == "axe":                                  # 도끼 머리 둘(날 Steel + 목 Iron)
                for dx in (-0.35, 0.35):
                    bx(g, "Iron", x + dx - 0.15, x + dx + 0.15, ym - 0.2, ym + 0.2, z, z + 0.6)
                    g["Steel"].obox(x + dx, ym - 0.3, z + 0.3, 0.12, 0.45, 0.85)
            elif kind == "ingot":                                # 쇠 덩이(쇠괴) 쌓음
                for q, (dx, dz) in enumerate(((-0.3, 0), (0.3, 0), (0.0, 0.25))):
                    g["Iron"].obox(x + dx, ym, z + 0.12 + dz, 0.55, 0.9, 0.24)
            elif kind == "plate":                                # 가슴판(어깨 넓은 판 + 가운데 등줄)
                g["Steel"].obox(x, ym, z + 0.55, 1.2, 0.3, 1.1, rx=-0.15)
                g["Iron"].obox(x, ym - 0.16, z + 0.55, 0.12, 0.05, 1.0, rx=-0.15)
                g["Brass"].obox(x, ym - 0.1, z + 1.05, 1.25, 0.1, 0.12, rx=-0.15)
    cbox(2.4, 13.6, yb0, yb1, FZ, FZ + 5.2)
    for xx, m in ((3.6, "Wood"), (12.2, "Wood")):                    # 선반 위 벽 둥근 방패 둘(뒷창 양옆)
        g[m].hcyl(xx, YI1 - 0.15, FZ + 7.4, 1.1, 0.2, axis="y", seg=16)
        g["Iron"].hcyl(xx, YI1 - 0.2, FZ + 7.4, 1.2, 0.12, axis="y", seg=16)
        g["Wood"].hcyl(xx, YI1 - 0.25, FZ + 7.4, 1.05, 0.08, axis="y", seg=16)
        g["Brass"].hcyl(xx, YI1 - 0.4, FZ + 7.4, 0.32, 0.3, axis="y", seg=10)
        for k in range(8):
            a = 2 * math.pi * k / 8
            g["Iron"].hcyl(xx + 0.85 * math.cos(a), YI1 - 0.32, FZ + 7.4 + 0.85 * math.sin(a), 0.07, 0.08, axis="y", seg=6)
    barrel(g, 12.6, -10.2)
    for k in range(4):
        g["Iron"].obox(12.6 + 0.3 * math.cos(k * 1.7), -10.2 + 0.3 * math.sin(k * 1.7), FZ + 2.8, 0.12, 0.12, 3.2, rx=0.07 * (k - 1.5))
    P.crate(g, 12.4, -7.6, FZ, w=2.2, d=2.2, h=2.0, rz=0.05)
    P.crate(g, 12.3, -7.7, FZ + 2.0, w=1.6, d=1.6, h=1.5, rz=0.25)


def steam(g):
    """바깥 왼 뒤: 증기 통 + 압력계 → 관이 왼 벽을 지나 풀무로(증기 송풍 — 슈네라이히 증기 기술)"""
    tx, ty = -17.9, 9.8
    K.steam_bundle(g, tx, ty, 0.0, h=6.6, r=1.2, gauge_face=-1, vent=False,     # 김은 굴뚝 하나(holes.py 김 상자 검사)
                   pipe_pts=[(tx + 1.2, ty, FZ + 5.0), (-12.3, ty, FZ + 5.0), (-12.3, -0.9, FZ + 5.0), (-12.3, -0.9, FZ + 3.2)])   # 왼 벽 안쪽을 따라 바닥 위 5 로 → 풀무 윗판에 꽂음(비평 2차)
    g["Iron"].hcyl(-11.95, 0.6, FZ + 5.0, 0.5, 0.12, axis="x", seg=14)     # 관 압력계(풀무 바로 위 — 문에서 보이는 쪽 +x)
    g["Dial"].hcyl(-11.87, 0.6, FZ + 5.0, 0.4, 0.05, axis="x", seg=14)
    bx(g, "Iron", -11.84, -11.82, 0.58, 0.62, FZ + 4.95, FZ + 5.3)


def build(g):
    R = K.roof_frame(HALF, PORCH_Y, YB + T / 2, Z_PLATE, VARIANT)
    # 1 기초(몸채 + 앞 작업 마루) + 앞 계단
    K.foundation(g, -HALF - 0.3, HALF + 0.3, PORCH_Y, YB + T / 2 + 0.3)
    K.stair(g, 0.0, PORCH_Y, 14.0, FZ)
    # 2 벽·박공 · 문 · 창
    walls(g, R)
    # 3 평보·동자기둥(안 셋 + 앞 트러스) · 마루 기둥
    for y in (-6.0, 0.0, 8.5):
        K.tie_truss(g, y, R)
    porch(g, R)
    # 4 지붕(굴뚝 자리 서까래는 받을보로)
    K.roof_gable(g, R, openings=[STACK])
    # 5 굴뚝(땅부터, 지붕 꼭대기 위로)
    K.chimney(g, *STACK, R.top() + 1.0)
    # 6 안: 화덕·모루·걸이·카운터 · 등 · 바깥 증기
    forge(g)
    anvil(g, -6.0, 4.0)
    racks(g)
    shop(g)
    workbench(g)
    smithy_extra(g)
    grindstone(g, -8.2, -9.6)
    P.tool_board(g, "y", -XI, -11.0, -8.4, FZ + 3.2, FZ + 7.4, face=1)       # 왼 벽 앞 걸이판: 집게 · 망치
    for k, yy in enumerate((-10.5, -10.0, -9.5)):
        P.tongs(g, -XI + 0.4, yy, FZ + 7.1, rz=math.pi / 2, s=0.9 + 0.08 * k)
    for yy in (-9.0, -8.7):
        P.hammer(g, -XI + 0.4, yy, FZ + 3.6, rz=0.0, ry=0.0, s=0.9)
    for x, y in ((0.0, -6.0), (8.5, 0.0), (-6.0, 0.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)
    steam(g)
    # 비울 자리: 입구 완충 · 카운터 앞 빈 바닥 10×10
    CLEAR(-5.0, 5.0, YI0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(3.0, 13.0, -6.0, 3.85, FZ + 0.15, FZ + 5.4)


# 완성품 선반 손 표(아래 → 위, 칸 6)
SHOP_ROWS = (("ingot", "shoe", "axe", "ingot", "shoe", "axe"),
             ("plate", "axe", "shoe", "plate", "axe", "shoe"),
             ("helm", "shoe", "helm", "axe", "helm", "shoe"))


# json·점검용 치수(build_kit · preview · audit 가 읽는다) — 블렌더 좌표
INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": (3.0, 13.0, 4.0, 6.5),           # x0 x1 y0 y1
    "free": (3.0, 13.0, -6.0, 3.85),            # 카운터 앞 빈 바닥(상판 앞 끝 3.85 까지)
    "walk": ((0.0, YF - 1.5), (8.0, -1.0)),     # 통로 재기: 문 밖 한 점 → 카운터 앞 빈 바닥(가장자리 2 안쪽, 카운터에서 4 떨어진 곳까지 들어서면 끝)
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI1),  # 통로 재는 범위(문 밖 1.5 포함)
    "forge_look": (-11.0, 4.5),                 # 1인칭 렌더가 바라볼 화덕 불
}
