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


def barrel(g, x, y, z0=FZ, r=0.9, h=2.3):
    g["Wood"].cyl(x, y, z0, r, r, h, seg=14)
    for z in (z0 + 0.35, z0 + h - 0.45):
        g["Iron"].cyl(x, y, z, r + 0.04, r + 0.04, 0.14, seg=14)
    cbox(x - r, x + r, y - r, y + r, z0, z0 + h)


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
    for k in range(8):
        y = y0 + 0.6 + k * (y1 - y0 - 1.2) / 7
        for d in (-1, 1):
            g["Iron"].obox(x1 + 0.3, y + d * 0.1, zh + 0.15, 0.08, 0.08, 1.4, rx=d * 0.07)
    # 풀무(화덕 뒤, 왼 벽): 다리 넷 · 아래 판 · 가죽 주름 · 들린 윗판 · 놋쇠 바람관 → 화덕 뒤 옆
    bxx, byy = -12.6, 9.9
    for dx in (-0.8, 0.8):
        for dy in (-0.9, 0.9):
            bx(g, "Timber", bxx + dx - 0.15, bxx + dx + 0.15, byy + dy - 0.15, byy + dy + 0.15, FZ, FZ + 2.4)
    bx(g, "Wood", bxx - 1.1, bxx + 1.1, byy - 1.1, byy + 1.1, FZ + 2.4, FZ + 2.6)
    for k in range(4):
        hh = 0.7 - k * 0.12
        bx(g, "Leather", bxx - 0.9, bxx + 0.9, byy + 1.0 - k * 0.5 - 0.45, byy + 1.0 - k * 0.5, FZ + 2.6, FZ + 2.6 + hh)
    g["Wood"].obox(bxx, byy, FZ + 3.15, 2.0, 2.3, 0.16, rx=-0.25)
    g["Brass"].hcyl(bxx, (byy - 1.1 + y1) / 2, FZ + 2.8, 0.14, byy - 1.1 - y1 + 0.3, axis="y", seg=10)
    cbox(bxx - 1.1, bxx + 1.1, byy - 1.1, byy + 1.1, FZ, FZ + 3.4)
    # 석탄 통(화덕 앞, 왼 벽)
    K.box2(g, "Iron", -XI + 0.1, -12.3, -1.9, 0.6, FZ, FZ + 1.5)
    for k, (x, y) in enumerate(((-13.6, -1.2), (-12.9, -0.5), (-13.5, 0.1), (-12.9, -1.4), (-13.2, -0.6))):
        g["Char"].obox(x, y, FZ + 1.62, 0.6, 0.5, 0.36, rz=k * 0.9)
    # 담금질 통(석탄 통 앞): 나무 통 + 쇠 띠 + 물
    qx0, qx1, qy0, qy1 = -XI + 0.2, -11.4, -5.4, -2.6
    K.box2(g, "Timber", qx0, qx1, qy0, qy1, FZ, FZ + 2.2)
    for z in (FZ + 0.5, FZ + 1.7):
        bx(g, "Iron", qx0 - 0.05, qx1 + 0.05, qy0 - 0.05, qy1 + 0.05, z, z + 0.15)
    bx(g, "Glass", qx0 + 0.2, qx1 - 0.2, qy0 + 0.2, qy1 - 0.2, FZ + 2.21, FZ + 2.26)


def anvil(g, x, y):
    """모루: 쇠 띠 두른 나무 등걸 + 무쇠 받침·허리·윗면 + 뿔 + 꼬리 + 위에 망치·집게"""
    z0 = FZ
    g["Wood"].cyl(x, y, z0, 1.15, 1.05, 1.7, seg=14)
    for z in (z0 + 0.3, z0 + 1.35):
        g["Iron"].cyl(x, y, z, 1.16, 1.12, 0.14, seg=14)
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
    zt = K.counter(g, 3.0, 13.0, 4.0, 6.5)
    g["Steel"].box(9.8, 5.0, zt + 0.06, 3.0, 0.32, 0.08)
    bx(g, "Brass", 8.1, 8.3, 4.5, 5.5, zt, zt + 0.15)
    bx(g, "Leather", 7.3, 8.1, 4.92, 5.08, zt, zt + 0.15)
    bx(g, "Leather", 4.6, 6.2, 4.7, 5.8, zt, zt + 0.16)
    bx(g, "Canvas", 4.7, 6.1, 4.8, 5.7, zt + 0.16, zt + 0.2)
    g["Brass"].cyl(12.0, 4.8, zt, 0.32, 0.18, 0.4, seg=12)
    NPC(8.0, 8.6, FZ, 0.0)
    yb0, yb1 = YI1 - 1.1, YI1
    for x in (2.6, 8.0, 13.4):
        bx(g, "Timber", x - 0.15, x + 0.15, yb0, yb0 + 0.3, FZ, FZ + 5.2)
    for k, z in enumerate((FZ + 1.4, FZ + 3.0, FZ + 4.6)):
        bx(g, "Wood", 2.4, 13.6, yb0, yb1, z - 0.15, z)
        for j in range(6):
            x = 3.3 + j * 1.75
            m = ("Iron", "Brass", "Copper", "IronLight")[(j + k) % 4]
            if k == 2 and j % 2 == 0:
                g["Iron"].cyl(x, (yb0 + yb1) / 2, z, 0.55, 0.35, 0.8, seg=12)       # 투구
            else:
                bx(g, m, x - 0.45, x + 0.45, yb0 + 0.25, yb1 - 0.25, z, z + 0.28)
    cbox(2.4, 13.6, yb0, yb1, FZ, FZ + 5.2)
    barrel(g, 12.6, -10.2)
    for k in range(4):
        g["Iron"].obox(12.6 + 0.3 * math.cos(k * 1.7), -10.2 + 0.3 * math.sin(k * 1.7), FZ + 2.8, 0.12, 0.12, 3.2, rx=0.07 * (k - 1.5))
    K.SVC.crate(g, 12.4, -7.6, FZ, 2.2)
    K.SVC.crate(g, 12.4, -7.6, FZ + 2.2, 1.6, rz=0.25)
    cbox(11.3, 13.5, -8.7, -6.5, FZ, FZ + 3.8)


def steam(g):
    """바깥 왼 뒤: 증기 통 + 압력계 → 관이 왼 벽을 지나 풀무로(증기 송풍 — 슈네라이히 증기 기술)"""
    tx, ty = -17.9, 9.8
    K.steam_bundle(g, tx, ty, 0.0, h=6.6, r=1.2, gauge_face=-1,
                   pipe_pts=[(tx + 1.2, ty, 6.8), (-12.6, ty, 6.8), (-12.6, ty, FZ + 3.7)])


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
    for x, y in ((0.0, -6.0), (8.5, 0.0), (-6.0, 0.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)
    steam(g)
    # 비울 자리: 입구 완충 · 카운터 앞 빈 바닥 10×10
    CLEAR(-5.0, 5.0, YI0 + 0.2, -6.0, FZ + 0.15, FZ + 5.4)
    CLEAR(3.0, 13.0, -6.0, 3.85, FZ + 0.15, FZ + 5.4)


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
