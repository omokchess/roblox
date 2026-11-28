# -*- coding: utf-8 -*-
"""
b_bank.py — 2026-11-14 아트 부서원 2 → 2026-11-18 아트 1팀 다시 지음. 설원 마을 3판: 은행(보관·환전). B 양식 — 벽 절반까지 돌.

사용자(2026-11-28 4차 점검): "은행은 그냥 금고를 없애자" — 금고 문이 사방 뚫린 채 열려 있고 문짝이 땅에 박혀 있었다.
→ 금고실·금고 문·회랑을 통째로 뺐다. 발자국 깊이 43.9 → 35.2(뒤 벽 y 25.6 → 20.4, 모임지붕이 반 깊이 ≥ 반 폭이어야 해서 이보다 못 줄임).
  홀을 은행답게: 벽에서 벽까지 창구 줄(창구 넷 · 쇠살 · 창구 번호판 · 동전 접시 · 종) + 대기석(양 벽 긴 의자 셋) + 기입대 + 환율 판 + 괘종시계 + 동전 저울.
  창구 뒤 직원 칸(손님은 못 들어감 — 양 끝은 닫힌 직원 문): 창구마다 서기 책상(장부·등·동전·작은 쇠 궤) + 의자 · 뒷벽 장부 책장 넷 · 서랍장 + 은행 문장 · 돈자루.

레퍼런스(회사/설원마을_레퍼런스.md B): 뢰로스 은행(B1 돌 1층 + 짙은 목재), 1922 퀸즐랜드 은행 안(B2 쇠살 창구 줄).

배치(블렌더, 앞 = -y, 바닥 FZ = 2). 벽 가운데 선 x ±16.4 · y -13..20.4 → 안 31.6 × 32.2, 천장(평보 밑) 11.
  홀     y -12.4..3.8 : 문 → 붉은 깔개 → 창구 줄(y 4..6.5, x -13..13 + 양 끝 닫힌 직원 문) · 양 벽 대기석 · 기입대 · 환율 판 · 괘종시계 · 동전 저울
  직원 칸 y 6.5..19.8 : 창구 NPC 넷(y 7.8) · 서기 책상 넷 · 뒷벽 책장·서랍장·문장 · 옆벽 서랍장·돈자루
"""
import math

from mathutils import Matrix

import lib as K
import lib_b as KB
import lib_int1 as P
import lib_int2 as N
from lib import FZ, LOG, CEIL, MAIN_W, MAIN_H, WIN_W, WIN_SILL, bx, cbox, NPC, CLEAR

NAME = "Sn3_Bank"
PREFIX = "Sn3Bank"
VARIANT = "B"

WX, YF, YB = 16.4, -13.0, 20.4          # 2026-11-28: 금고 빼고 뒤 벽 25.6 → 20.4(반 깊이 17.3 ≥ 반 폭 17 — 모임지붕)
T = LOG
AX = WX + T / 2                          # 벽 바깥면 반폭 17.0
AYF, AYB = YF - T / 2, YB + T / 2         # 앞 -13.6 · 뒤 21.0
CY, HA = (AYF + AYB) / 2, (AYB - AYF) / 2     # 지붕 가운데 y 3.7 · 반 깊이 17.3
XI, YI0, YI1 = WX - T / 2, YF + T / 2, YB - T / 2       # 15.8, -12.4, 19.8
Z_PLATE = FZ + CEIL + 0.9
STONE_TO = FZ + 6.0
PITCH = 40.0
WIN_F, WIN_S = (-11.5, 11.5), (-6.5, 6.5, 14.0)
COUNTER = (-13.0, 13.0, 4.0, 6.5)        # 창구 줄(양 끝 x ±13..±15.8 은 닫힌 직원 문)
FREE = (-5.0, 5.0, -6.35, 3.65)
TIES = (-9.0, -2.5, 4.0, 10.5, 17.0)     # 평보(x 방향) 자리
TELLERS = (-9.0, -3.0, 3.0, 9.0)         # 창구 가운데 x
NPCS = tuple((t, 7.8) for t in TELLERS)


# ------------------------------------------------------------------ 껍데기
def walls(g):
    hole = lambda u, z0=FZ + WIN_SILL, w=WIN_W, h=K.WIN_H: (u - w / 2, u + w / 2, z0, z0 + h)     # noqa: E731
    door = (-MAIN_W / 2, MAIN_W / 2, FZ, FZ + MAIN_H)
    plan = (("x", YF, [door] + [hole(u) for u in WIN_F], -1),
            ("x", YB, [], 1),
            ("y", -WX, [hole(u) for u in WIN_S], -1),
            ("y", WX, [hole(u) for u in WIN_S], 1))
    for ax, c, holes, face in plan:
        u0, u1 = (-WX, WX) if ax == "x" else (YF, YB)
        K.frame_wall(g, ax, c, u0, u1, FZ, Z_PLATE, holes, stone_to=STONE_TO, face=face)
        for h in holes[1 if ax == "x" and c == YF else 0:]:
            KB.barred_window(g, ax, c, (h[0] + h[1]) / 2, h[2], face, w=h[1] - h[0], h=h[3] - h[2])
    K.door_open(g, "x", YF, 0.0, MAIN_W, MAIN_H, FZ, face=-1, open_deg=150.0, outward=False)     # 150°: 카운터 앞 빈 바닥(문 앞 1.75 부터)을 비킴


def portal(g):
    """정문 돌 기둥 둘(기초 위) + 돌 인방(처마 밑까지) — 은행만의 단단한 문"""
    y0, y1 = AYF - 0.9, AYF
    for s in (-1, 1):
        x0, x1 = sorted((s * 6.0, s * 7.5))
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ, FZ + 0.8)
        bx(g, "Stone", x0, x1, y0, y1, FZ + 0.8, FZ + 10.6)
        bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1, FZ + 10.6, FZ + 11.0)
        cbox(x0, x1, y0, y1, FZ, FZ + 10.6)
    bx(g, "Stone", -7.65, 7.65, y0 - 0.1, y1, FZ + 11.0, FZ + 11.6)
    bx(g, "StoneTrim", -7.9, 7.9, y0 - 0.3, y1, FZ + 11.6, FZ + 11.85)
    g["Brass"].hcyl(0, y0 - 0.2, FZ + 11.3, 0.5, 0.2, axis="y", seg=16)


def _roof_local(q):
    """제 좌표(용마루 = x, 길이 반 HA 20 · 폭 반 AX 17)로 모임지붕 + 평보(y 방향) · 동자기둥 · 버팀대. 뒤에 90° 돌려 놓는다"""
    A, B = HA, AX
    ztop, zb = KB.hip_roof(q, A, B, Z_PLATE, PITCH)
    zt0 = Z_PLATE - 0.9
    for yt in TIES:
        xt = yt - CY
        bx(q, "DarkLog", xt - 0.5, xt + 0.5, -B + 0.05, B - 0.05, zt0, Z_PLATE)
        inset = min(B, A - abs(xt) - 0.5)
        zp = zb(inset) - (1.15 if abs(xt) < A - B + 0.1 else 0.1)
        bx(q, "DarkLog", xt - 0.4, xt + 0.4, -0.4, 0.4, Z_PLATE, zp)
        for s in (-1, 1):
            KB.member(q, "DarkLog", (xt, s * 0.4, Z_PLATE + (zp - Z_PLATE) * 0.55), (xt, s * (B - 4.0), Z_PLATE + 0.3), 0.45, 0.45)


def roof(g):
    # 제 (lx, ly) → 세계 (-ly, lx + CY): 용마루가 y 를 따른다(뒤로 늘린 집이 폭보다 길어서)
    K.L.transformed(g, Matrix.Translation((0, CY, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z"), _roof_local)


# ------------------------------------------------------------------ 홀
def bench_wall(g, s, y0, y1):
    """벽(x = s·XI)에 등을 댄 긴 의자 — lib_int1.wall_bench"""
    P.wall_bench(g, s * XI, s, y0, y1, FZ)


def tall_clock(g, x, y, face_rz):
    """큰 괘종시계(앞 = -y 를 rz 로 돌림): 받침 · 몸(허리 문 + 유리 창 속 추) · 머리(시계판 · 놋쇠 테 · 바늘) · 꼭대기 장식 셋"""
    A = P.At(g, x, y, FZ, face_rz)
    A.box("DarkLog", -0.95, 0.95, -0.7, 0.7, 0, 1.2)
    A.box("Timber", -0.8, 0.8, -0.6, 0.6, 1.2, 5.6)
    A.box("Wood", -0.55, 0.55, -0.84, -0.6, 1.6, 2.2)                     # 허리 문 틀(밑대 · 윗대 · 옆대) — 유리 속 추가 보이게(2026-11-28: 추가 몸 속에 묻혀 있었다)
    A.box("Wood", -0.55, 0.55, -0.84, -0.6, 4.9, 5.2)
    for sx in (-1, 1):
        A.box("Wood", *sorted((sx * 0.36, sx * 0.55)), -0.84, -0.6, 2.2, 4.9)
    A.box("Glass", -0.36, 0.36, -0.82, -0.78, 2.2, 4.9)
    A.box("Iron", -0.06, 0.06, -0.74, -0.6, 3.0, 4.9)                     # 추 막대(몸 앞면에 붙음)
    A.hcyl("Brass", 0, -0.69, 2.85, 0.3, 0.12, axis="y", seg=12)
    A.box("DarkLog", -1.0, 1.0, -0.75, 0.75, 5.6, 5.9)
    A.box("Timber", -0.9, 0.9, -0.65, 0.65, 5.9, 7.9)
    A.hcyl("Brass", 0, -0.66, 6.9, 0.78, 0.08, axis="y", seg=20)
    A.hcyl("Dial", 0, -0.72, 6.9, 0.66, 0.06, axis="y", seg=20)
    for k in range(12):
        a = 2 * math.pi * k / 12
        A.ob("Iron", 0.55 * math.sin(a), -0.77, 6.9 + 0.55 * math.cos(a), 0.06, 0.04, 0.16 if k % 3 else 0.26, ry=a)
    A.ob("Iron", 0.12, -0.8, 7.05, 0.07, 0.04, 0.45, ry=0.6)
    A.ob("Iron", -0.2, -0.8, 6.85, 0.07, 0.04, 0.32, ry=-2.0)
    A.box("DarkLog", -1.1, 1.1, -0.8, 0.8, 7.9, 8.25)
    A.ob("DarkLog", 0, 0, 8.55, 1.6, 1.3, 0.5)
    for sx in (-0.85, 0.0, 0.85):
        A.cyl("Brass", sx, -0.45, 8.25 if sx else 8.8, 0.12, 0.05, 0.55, seg=6)
    A.coll(-0.95, 0.95, -0.7, 0.7, 0, 8.25)


def coin_machine(g, xw, yc):
    """증기 동전 저울(오른 벽 x = xw 에 붙음): 돌 받침 · 구리 통(놋쇠 띠) · 놋쇠 깔때기 · 맞물린 톱니 둘 · 미끄럼 홈 · 동전 쟁반 · 압력계 · 벽으로 드는 관"""
    s = 1 if xw > 0 else -1
    xm = xw - s * 0.95
    bx(g, "Stone", *sorted((xw, xw - s * 1.9)), yc - 1.6, yc + 1.6, FZ, FZ + 0.6)
    K.S.banded_cyl(g, "Copper", xm, yc + 0.6, FZ + 0.6, 0.75, 3.2, every=1.2, seg=12)
    g["Brass"].cyl(xm, yc + 0.6, FZ + 3.8, 0.35, 0.95, 1.0, seg=10)
    g["Brass"].cyl(xm, yc + 0.6, FZ + 4.8, 0.95, 0.95, 0.12, seg=10)
    K.S.gear(g, "Brass", xm - s * 0.1, yc - 0.7, FZ + 3.3, 0.75, 10, 0.18, axis="x")
    K.S.gear(g, "Iron", xm - s * 0.1, yc - 0.7 - 1.1, FZ + 3.3 - 0.35, 0.45, 8, 0.18, axis="x")
    g["Brass"].obox(xm - s * 0.2, yc - 0.6, FZ + 1.9, 0.5, 1.6, 0.12, rx=0.45)
    bx(g, "Wood", *sorted((xw - s * 0.4, xw - s * 1.85)), yc - 1.5, yc - 0.5, FZ + 1.1, FZ + 1.25)
    for k, dy in enumerate((-1.2, -0.85)):
        P.coin_stack(g, xm - s * 0.25 * (k * 2 - 1), yc + dy, FZ + 1.25, n=3 + k, r=0.18)
    g["Iron"].hcyl(xm - s * 0.8, yc + 0.6, FZ + 2.8, 0.42, 0.14, axis="x", seg=12)
    g["Dial"].hcyl(xm - s * 0.88, yc + 0.6, FZ + 2.8, 0.32, 0.06, axis="x", seg=12)
    K.S.pipe(g, [(xm, yc + 0.6, FZ + 4.0), (xm, yc + 1.4, FZ + 4.0), (xw - s * 0.2, yc + 1.4, FZ + 4.0)], 0.18, mat="Copper")
    cbox(*sorted((xw, xw - s * 1.9)), yc - 1.6, yc + 1.6, FZ, FZ + 4.9)


def bank_counter(g, x0, x1, y0, y1):
    """은행 창구 카운터(비평 1차: 세 채가 같은 틀): 돌 밑단 0.6 · 짙은 나무(Timber) 몸 · 앞면 밝은 판(Wood) 칸 · 놋쇠 띠 둘 · 밝은 돌 상판 0.3"""
    zt = FZ + K.COUNTER_H
    bx(g, "StoneTrim", x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, FZ, FZ + 0.6)
    bx(g, "Timber", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, FZ + 0.6, zt - 0.3)
    n = max(1, int(round((x1 - x0) / 1.6)))
    for i in range(n):
        a = x0 + 0.25 + (x1 - x0 - 0.5) * i / n
        b = x0 + 0.25 + (x1 - x0 - 0.5) * (i + 1) / n
        bx(g, "Wood", a + 0.12, b - 0.12, y0 + 0.02, y0 + 0.1, FZ + 1.25, zt - 0.85)
    for zz in (FZ + 0.95, zt - 0.6):
        bx(g, "Brass", x0 + 0.1, x1 - 0.1, y0 - 0.02, y0 + 0.1, zz, zz + 0.1)
    bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.2, y1 + 0.15, zt - 0.3, zt)
    cbox(x0 - 0.15, x1 + 0.15, y0 - 0.2, y1 + 0.15, FZ, zt)
    return zt


def writing_desk(g, x, y):
    """기입대(서서 쓰는 책상, 앞뒤 양면): 다리 넷 · 아래 선반(종이 묶음) · 기운 상판 둘(놋쇠 펜 홈) · 가운데 등 · 잉크병"""
    for sx in (-1.6, 1.6):
        for sy in (-0.7, 0.7):
            bx(g, "Timber", x + sx - 0.15, x + sx + 0.15, y + sy - 0.15, y + sy + 0.15, FZ, FZ + 3.3)
    bx(g, "Wood", x - 1.75, x + 1.75, y - 0.85, y + 0.85, FZ + 0.6, FZ + 0.75)
    for k, xx in enumerate((-1.0, 0.1, 1.0)):
        for q in range(2 + k % 2):                             # 바랜 크림 종이(Canvas) 두세 장 어긋나게(비평 1차: 가장 밝은 덩이)
            g["Canvas"].obox(x + xx + 0.08 * q, y - 0.05 * q, FZ + 0.8 + 0.07 * q, 0.8, 0.8, 0.06, rz=0.12 * (q - 1))
    for sy in (-1, 1):
        g["Wood"].obox(x, y + sy * 0.55, FZ + 3.55, 3.8, 1.2, 0.14, rx=-sy * 0.22)      # 바깥(쓰는 사람 쪽)이 낮게
        bx(g, "Brass", x - 1.8, x + 1.8, y + sy * 1.1 - 0.06, y + sy * 1.1 + 0.06, FZ + 3.3, FZ + 3.45)
    bx(g, "DarkLog", x - 1.85, x + 1.85, y - 0.12, y + 0.12, FZ + 3.55, FZ + 3.85)
    for xx in (-1.1, 1.1):
        g["Iron"].cyl(x + xx, y, FZ + 3.85, 0.16, 0.12, 0.28, seg=8)
    g["Brass"].cyl(x, y, FZ + 3.85, 0.1, 0.1, 1.2, seg=6)
    g["Brass"].cyl(x, y, FZ + 5.05, 0.45, 0.15, 0.35, seg=8)
    g["Glow"].cyl(x, y, FZ + 4.85, 0.18, 0.12, 0.2, seg=6)
    cbox(x - 1.8, x + 1.8, y - 0.9, y + 0.9, FZ, FZ + 3.6)


def rate_board(q, w=4.4, h=3.3):
    """환율 판(제 좌표: 벽 = y 0, 방 = -y, 아래 가운데 원점): 짙은 나무 판 · 놋쇠 테 · 위 붉은 띠 + 금화 · 줄 넷(동전 원판 + 흰 숫자 패 셋) · 벽 쇠못 둘"""
    bx(q, "DarkLog", -w / 2, w / 2, -0.22, 0.0, 0.0, h)
    bx(q, "Brass", -w / 2 - 0.15, w / 2 + 0.15, -0.38, -0.05, -0.12, 0.12)
    bx(q, "Brass", -w / 2 - 0.15, w / 2 + 0.15, -0.38, -0.05, h - 0.12, h + 0.12)
    for sx in (-1, 1):
        bx(q, "Brass", *sorted((sx * (w / 2 - 0.1), sx * (w / 2 + 0.15))), -0.38, -0.05, 0.12, h - 0.12)
        bx(q, "Iron", sx * 1.4 - 0.1, sx * 1.4 + 0.1, -0.5, 0.0, h + 0.12, h + 0.32)
    bx(q, "Banner", -w / 2 + 0.25, w / 2 - 0.25, -0.3, -0.2, h - 0.75, h - 0.2)
    q["SignGold"].hcyl(0, -0.36, h - 0.47, 0.3, 0.14, axis="y", seg=12)
    for r, (mat, num) in enumerate((("SignGold", "125"), ("Steel", "080"), ("Copper", "017"), ("Brass", "340"))):
        z = h - 1.2 - r * 0.62
        q[mat].hcyl(-w / 2 + 0.6, -0.3, z, 0.24, 0.16, axis="y", seg=10)
        bx(q, "Iron", -w / 2 + 1.0, -w / 2 + 1.35, -0.28, -0.2, z - 0.05, z + 0.05)          # 화살 막대
        for k, ch in enumerate(num):
            x = -w / 2 + 1.85 + k * 0.62
            bx(q, "Paint", x - 0.25, x + 0.25, -0.3, -0.2, z - 0.27, z + 0.27)
            P.digit(q, ch, x, -0.3, z, 0.4, "DarkStone")


def staff_gate(g, s):
    """창구 줄 끝(카운터 끝 ~ 옆벽) 닫힌 직원 문: 받침 · 세로 널 문짝 · 앞뒤 띠 둘 · 윗대 · 벽 쪽 놋쇠 경첩 둘 · 카운터 쪽 쇠 빗장"""
    xa, xb = sorted((s * (COUNTER[1] + 0.15), s * XI))
    y0, y1 = COUNTER[2], COUNTER[3]
    bx(g, "DarkLog", xa, xb, y0 + 0.5, y1 - 0.5, FZ, FZ + 0.3)
    n = 4
    for i in range(n):
        a, b_ = xa + 0.1 + (xb - xa - 0.2) * i / n, xa + 0.1 + (xb - xa - 0.2) * (i + 1) / n
        bx(g, "Timber" if i % 2 else "DarkLog", a + 0.01, b_ - 0.01, 5.0, 5.5, FZ + 0.3, FZ + 3.2)
    for zz in (FZ + 0.8, FZ + 2.4):
        bx(g, "Wood", xa + 0.15, xb - 0.15, 4.85, 5.65, zz, zz + 0.35)
    bx(g, "Wood", xa - 0.05, xb + 0.05, y0 + 0.4, y1 - 0.4, FZ + 3.2, FZ + K.COUNTER_H)
    xw = xb if s > 0 else xa
    for zz in (FZ + 0.85, FZ + 2.45):
        bx(g, "Brass", *sorted((xw, xw - s * 0.6)), 4.75, 5.75, zz + 0.05, zz + 0.3)
    xc = xa if s > 0 else xb
    bx(g, "Iron", *sorted((xc, xc + s * 0.7)), 4.8, 4.9, FZ + 1.7, FZ + 1.95)
    cbox(xa, xb, y0, y1, FZ, FZ + K.COUNTER_H)


def hall(g):
    """홀: 두 톤 돌 바둑판 · 붉은 깔개 · 창구 줄(카운터 + 쇠살 + 창구 넷 + 번호판 · 접시 · 종) + 양 끝 직원 문 · 대기석 셋 · 기입대 · 환율 판 · 그림 · 괘종시계 · 동전 저울 · 벽등 · 매단 등"""
    rows = 8
    dy = (COUNTER[2] - 0.2 - YI0) / rows
    for i in range(16):
        for j in range(rows):
            bx(g, "StoneTrim" if (i + j) % 2 else "Stone", -XI + i * 2.0 - 0.2 * (i == 0), -XI + (i + 1) * 2.0, YI0 + j * dy, YI0 + (j + 1) * dy, FZ, FZ + 0.04)
    P.rug(g, -3.0, 3.0, YI0 + 0.3, COUNTER[2] - 0.8, FZ, "Banner", "SignGold", "SignGold")
    x0, x1, y0, y1 = COUNTER
    zt = bank_counter(g, x0, x1, y0, y1)
    yc = (y0 + y1) / 2
    KB.grille(g, -XI + 0.3, XI - 0.3, yc, zt, FZ + 9.0, gaps=[(t - 1.25, t + 1.25) for t in TELLERS])
    for s in (-1, 1):
        staff_gate(g, s)
    for x, y in NPCS:
        NPC(x, y, FZ, 0.0)
    zg = zt + 2.4
    for i, t in enumerate(TELLERS):                       # 창구마다: 번호판(쇠살 위) · 동전 접시 · 동전 · 종 · 잉크병
        bx(g, "Brass", t - 0.45, t + 0.45, yc - 0.34, yc - 0.02, zg + 0.35, zg + 1.15)       # 쇠살에 박은 번호판
        bx(g, "DarkLog", t - 0.35, t + 0.35, yc - 0.4, yc - 0.34, zg + 0.45, zg + 1.05)
        P.digit(g, str(i + 1), t, yc - 0.4, zg + 0.75, 0.5, "Paint")
        g["Brass"].cyl(t - 0.6, y0 + 0.45, zt, 0.42, 0.48, 0.1, seg=12)
        P.coin_stack(g, t - 0.45, y0 + 0.45, zt + 0.1, n=2 + i % 2, r=0.16)
        g["Brass"].cyl(t + 0.75, y0 + 0.4, zt, 0.3, 0.2, 0.36, seg=10)           # 종
        g["Iron"].cyl(t + 0.75, y0 + 0.4, zt + 0.36, 0.08, 0.08, 0.14, seg=6)
        g["Brass"].cyl(t + 0.75, y0 + 0.4, zt + 0.5, 0.13, 0.13, 0.08, seg=8)
        g["DarkStone"].cyl(t + 0.1, y0 + 0.9, zt, 0.16, 0.13, 0.3, seg=8)           # 잉크병 + 깃펜
        g["Paint"].obox(t + 0.15, y0 + 0.95, zt + 0.55, 0.06, 0.12, 0.6, ry=0.3)
    P.scale(g, -11.6, y0 + 0.55, zt, rz=0.0)               # 1번 창구 옆 환전 천칭
    for k, xx in enumerate((11.4, 11.85)):
        P.coin_stack(g, xx, y0 + 0.45 + 0.3 * (k % 2), zt, n=3 + k, r=0.2)
    # 대기석(양 벽 긴 의자) · 벽등
    bench_wall(g, -1, -10.6, -5.6)
    bench_wall(g, -1, -3.6, 2.4)
    bench_wall(g, 1, -5.4, 2.4)
    for s in (-1, 1):
        for yy in (-9.6, -3.4):
            P.sconce(g, "y", s * XI, yy, FZ + 7.2, face=-s)
    P.wall_weapon(g, "y", -XI, -0.4, FZ + 5.0, 1, rate_board)               # 왼 벽 환율 판(긴 의자 위)
    N.put(g, XI, -1.4, FZ + 4.9, -math.pi / 2, N.painting, 4.4, 3.0)         # 오른 벽 그림(설산)
    writing_desk(g, -11.0, -10.8)
    tall_clock(g, 14.5, -11.3, 0.0)
    coin_machine(g, XI, -8.4)
    for x, y in ((-3.4, -9.0), (3.4, -9.0), (-3.4, -2.5), (3.4, -2.5), (-10.0, -2.5), (10.0, -2.5)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def staff(g):
    """창구 뒤 직원 칸(손님 못 들어감): 마루 · 창구마다 서기 책상(장부 · 등 · 동전 · 작은 쇠 궤 둘) + 의자 · 뒷벽 책장 넷 · 가운데 서랍장 + 은행 문장 ·
    옆 서랍장 둘 · 오른 벽 돈자루·상자 · 매단 등"""
    P.plank_floor(g, -XI, XI, COUNTER[3] + 0.15, YI1, FZ)
    for i, t in enumerate(TELLERS):
        zt = P.table(g, t - 1.7, t + 1.7, 10.2, 11.8, FZ, h=2.6)
        P.chair(g, t, 12.9, FZ, rz=0.0)
        P.ledger_open(g, t - 0.3, 10.95, zt, rz=math.pi)
        g["Brass"].cyl(t + 1.2, 11.35, zt, 0.26, 0.2, 0.12, seg=10)             # 책상 등
        g["Iron"].cyl(t + 1.2, 11.35, zt + 0.12, 0.06, 0.06, 1.1, seg=6)
        g["Brass"].cyl(t + 1.2, 11.35, zt + 1.05, 0.5, 0.18, 0.4, seg=10)
        g["Glow"].cyl(t + 1.2, 11.35, zt + 0.95, 0.16, 0.12, 0.16, seg=6)
        P.coin_stack(g, t - 1.35, 10.6, zt, n=2 + i % 3, r=0.18)
        if i in (1, 2):
            P.strongbox(g, t - 1.05, 11.35, zt, w=0.9, d=0.7, h=0.6, coll=False)
    for k, x in enumerate((-13.6, -11.3, 11.3, 13.6)):
        N.put(g, x, YI1 - 0.55, FZ, 0.0, N.bookcase, 2.2, 1.1, 7.0, "DarkLog", "Wood", k)
        K.cbox(x - 1.1, x + 1.1, YI1 - 1.1, YI1, FZ, FZ + 7.0)
    for x in (-5.2, 0.0, 5.2):
        N.put(g, x, YI1 - 0.6, FZ, 0.0, N.drawer_chest, 4.4, 1.2, 3.0)
        K.cbox(x - 2.2, x + 2.2, YI1 - 1.2, YI1, FZ, FZ + 3.0)
    g["Brass"].hcyl(0, YI1 - 0.15, FZ + 7.4, 1.35, 0.3, axis="y", seg=20)       # 은행 문장: 놋쇠 동전 + 쇠 테 + 열쇠 구멍
    g["Iron"].hcyl(0, YI1 - 0.32, FZ + 7.4, 1.05, 0.08, axis="y", seg=20)
    g["SignGold"].hcyl(0, YI1 - 0.4, FZ + 7.4, 0.95, 0.06, axis="y", seg=20)
    g["Char"].hcyl(0, YI1 - 0.45, FZ + 7.6, 0.2, 0.06, axis="y", seg=8)
    bx(g, "Char", -0.1, 0.1, YI1 - 0.48, YI1 - 0.42, FZ + 6.95, FZ + 7.5)
    N.put(g, -XI + 0.6, 10.0, FZ, math.pi / 2, N.drawer_chest, 4.4, 1.2, 3.0)
    K.cbox(-XI, -XI + 1.2, 7.8, 12.2, FZ, FZ + 3.0)
    N.put(g, -XI + 0.6, 17.4, FZ, math.pi / 2, N.drawer_chest, 3.4, 1.2, 3.0, 2, 2)
    K.cbox(-XI, -XI + 1.2, 15.7, 19.1, FZ, FZ + 3.0)
    P.crate(g, XI - 1.2, 9.4, FZ, w=1.9, d=1.9, h=1.7, rz=0.05)
    for k, (dx, dy, s_) in enumerate(((-1.0, 11.6, 1.0), (-1.1, 12.9, 0.9), (-2.4, 12.2, 0.85))):
        P.sack(g, XI + dx, dy, FZ, s=s_, rz=0.4 * k)
    P.crate(g, XI - 1.0, 17.6, FZ, w=1.7, d=1.7, h=1.6, rz=-0.1)
    P.crate(g, XI - 1.05, 17.55, FZ + 1.6, w=1.3, d=1.3, h=1.2, rz=0.2)
    for x, y in ((-8.0, 10.5), (8.0, 10.5), (-8.0, 17.0), (8.0, 17.0), (0.0, 17.0)):
        K.lantern(g, x, y, Z_PLATE - 0.9, FZ + 8.4)


def signs(g):
    coin = lambda g_, x, y, z, f: K.SVC.coin_icon(g_, x, y, z - 0.75, face=f)    # noqa: E731
    K.hang_sign(g, AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=1)
    K.hang_sign(g, -AX, -10.2, FZ + 9.0, along="x", icon=coin, face_sign=-1)


def steam(g):
    tx, ty = -12.5, -15.7
    rx = -8.4
    K.steam_bundle(g, tx, ty, 0.0, h=6.4, r=1.15, gauge_face=-1, vent=False,       # 김 자리는 처마 밑이라 뺌(holes.py 김 검사)
                   pipe_pts=[(tx + 1.15, ty, 4.2), (rx, ty, 4.2), (rx, -14.3, 4.2), (rx, -14.3, 12.6), (rx, -13.3, 12.6)])
    for z in (7.4, 10.4):
        bx(g, "Iron", rx - 0.45, rx + 0.45, -14.7, AYF, z - 0.12, z + 0.12)


def build(g):
    K.foundation(g, -AX - 0.3, AX + 0.3, AYF - 0.3, AYB + 0.3)
    K.stair(g, 0.0, AYF - 0.3, 14.0, FZ)
    walls(g)
    portal(g)
    roof(g)
    hall(g)
    staff(g)
    signs(g)
    steam(g)
    CLEAR(-4.7, 4.7, YI0 + 0.2, FREE[2], FZ + 0.15, FZ + 5.4)      # 안으로 연 문짝 띠가 0.1~0.3 들어와 ±4.7
    CLEAR(FREE[0], FREE[1], FREE[2], FREE[3] - 0.15, FZ + 0.15, FZ + 5.4)


INFO = {
    "variant": VARIANT,
    "floor": FZ,
    "ceiling": CEIL,
    "counter": COUNTER,
    "free": FREE,
    "walk": ((0.0, YF - 1.5), (0.0, -3.0)),
    "inside": (-XI, XI, YF - T / 2 - 1.5, YI1),
    "forge_look": (0.0, 10.0),
    # holes.py 눈 자리(방에서 보이는 자리만 셀 때) — 홀 · 직원 칸 셋
    "hole_seeds": [(0.0, -4.0, FZ + 4.5), (0.0, 13.5, FZ + 4.5), (-11.0, 13.5, FZ + 4.5), (11.0, 13.5, FZ + 4.5)],
}
