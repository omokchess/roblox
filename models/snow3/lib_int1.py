# -*- coding: utf-8 -*-
"""
snow3/lib_int1.py — 2026-11-18 아트 1팀. 설원 3판 1팀 건물(은행·잡화·대장간·시계탑·티켓)의 안살림 소품.
사용자(2026-11-18): "각 건물의 특색이 잘 드러나도록 내부 인테리어를 채워주고, 건물 내부에 있는 모든 오브젝트들의 퀄리티를 극상으로 …
지금 테마에 맞는 수준에서 퀄리티의 극상이니까, 극사실주의로 만들면 안 돼."

■ 양식(바이블 9절 · 핸드북 · 지시서 2절)
  - 상자 하나로 때운 물건 금지: 통 = 널 12 쪽(두 색 번갈아) + 쇠테, 병 = 몸·어깨·목·코르크·라벨, 책 = 앞뒤 표지·등·속장·등 띠,
    의자·탁자 = 다리·가름대·모서리 따낸 상판, 선반 = 까치발, 천 = 각진 주름. 놋쇠 리벳·테·손잡이 같은 2단 디테일.
  - 극사실 금지: 실제 크기보다 약간 두툼하게, 각진 면, 단색 재질 + 놋쇠/구리 강조. 1인칭 눈높이 4.5 에서 실루엣이 읽히는 굵기(0.12 이상).
  - 자리·치수는 부르는 쪽(b_*.py)의 손 표. 이 파일엔 물건 '모양'만 있다(자동 뿌리기 없음 — 줄 세우는 소품도 손으로 정한 순서 표를 돈다).

■ 부품(한 줄씩) — 모두 (x, y, z0 = 바닥) 에 놓고 rz(라디안)로 돌린다. coll=True 면 충돌 상자(K.I.C)
  At(g, x, y, z0, rz)                          제 좌표 놓개: .box(mat, x0,x1,y0,y1,z0,z1) · .ob(mat, cx,cy,cz, sx,sy,sz, rx,ry,rz) · .cyl · .hcyl · .coll
  prism(g, mat, pts, z0, z1)                   평면 볼록 다각형 기둥(모서리 따낸 상판·금괴)
  barrel(g, x, y, z0, r, h)                    배 부른 통: 널 12 쪽 × 위아래 두 마디(Wood/Timber 번갈아) + 쇠테 셋 + 뚜껑(테·마개)
  crate(g, x, y, z0, w, d, h, rz)              나무 상자: 판 + 모서리 각재 12 + 앞뒤 X 가새 + 쇠 모서리 덮개 8
  sack(g, x, y, z0, s, rz, mat)                자루: 각진 몸 + 접힌 어깨 + 묶은 목 + 끈
  bottle(g, x, y, z0, liquid, h, r, label)     병: 물약 찬 몸 + 유리 어깨·목 + 코르크 + 라벨 띠
  book(g, x, y, z0, w, d, h, mat, rz, lean)    책: 앞뒤 표지 + 등 + 속장(Paint, 0.05 낮게) + 등 띠 둘(SignGold)
  book_row(g, x0, x1, y, z0, depth, start, face)  손 표 BOOKS 를 start 부터 돌며 x0..x1 에 세움(끝 하나는 기댐)
  stool(g, x, y, z0, h, r)                     둥근 걸상: 테 두른 자리 + 벌어진 다리 넷 + 가름대 고리
  chair(g, x, y, z0, rz)                       등받이 의자: 따낸 자리 + 다리 넷 + H 가름대 + 등 기둥 둘·살 셋·윗대
  table(g, x0, x1, y0, y1, z0, h)              탁자: 모서리 따낸 상판 + 앞판(apron) + 다리 넷(밑동 굵게) + 가름대
  shelf(g, ax, c, u0, u1, z0, h, depth, levels, face)  벽 선반: 옆판·가운데 판 + 단 판(앞 턱) + 단마다 까치발 + 머리 장식 + 뒤판. 돌려줌: 단 윗면 높이들
  cloth_hang(g, ax, c, u0, u1, z0, z1, face, mat)  매단 천: 세로 주름 판(번갈아 비틀어 각진 주름) + 위 막대
  rug(g, x0, x1, y0, y1, z0, mat, edge)        깔개: 바탕 + 테 + 가운데 마름모
  sconce(g, ax, c, u, z, face)                 벽등: 놋쇠 받침판 + 쇠 팔 + 유리 등 + 불빛(Glow) + 빛 자리(LampPt)
  strongbox(g, x, y, z0, w, d, h, rz)          쇠 궤: 몸 + 놋쇠 띠 + 자물쇠판 + 손잡이 둘 + 리벳
  gold_bar(g, x, y, z0, rz) · gold_stack(g, x, y, z0, rz)  금괴(윗면 좁은 기둥꼴) 하나 / 3·2·1 쌓음
  coin_stack(g, x, y, z0, n)                   동전 기둥(놋쇠, 0.12 한 닢)
  ledger_open(g, x, y, z0, rz)                 펼친 장부: 표지 + 두 면(가운데 접힘) + 줄 + 깃펜·잉크병
  scale(g, x, y, z0, rz)                       놋쇠 천칭: 받침 + 기둥 + 들보 + 접시 둘(줄 셋)
  deposit_wall(g, ax, c, u0, u1, z0, cols, rows, face)  대여 금고 서랍 벽: 쇠 틀 + 칸마다 문(Steel) + 번호판(Brass) + 열쇠 구멍
  tool_board(g, ax, c, u0, u1, z0, z1, face)   연장 걸이판(판 + 위아래 테) — 걸 물건은 부르는 쪽이
  hammer(g, x, y, z, rz, ry) · tongs(g, x, y, z, rz)   망치(자루 + 쇠 머리 + 쐐기) · 집게(두 다리 + 고리)
  pot(g, x, y, z0, r, h)                       무쇠 냄비(몸 + 테 + 손잡이 둘 + 뚜껑 꼭지)
  rope_coil(g, x, y, z0, r)                    밧줄 사리(고리 셋 쌓음)
  lantern_sale(g, x, y, z0)                    파는 등(작은 놋쇠 등 — 불 없음)
"""
import math

import lib as K
from lib import bx

S = K.S
C = K.I.C


# ------------------------------------------------------------------ 놓개
class At:
    """제 좌표(x 오른쪽, y 뒤, z 위)로 지은 소품을 (x, y, z0) 에 rz 만큼 돌려 놓는다"""

    def __init__(self, g, x, y, z0=0.0, rz=0.0):
        self.g, self.x, self.y, self.z0, self.rz = g, x, y, z0, rz
        self.c, self.s = math.cos(rz), math.sin(rz)

    def P(self, lx, ly):
        return self.x + lx * self.c - ly * self.s, self.y + lx * self.s + ly * self.c

    def ob(self, mat, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0, rz=0.0):
        if sx <= 1e-4 or sy <= 1e-4 or sz <= 1e-4:
            return
        wx, wy = self.P(cx, cy)
        self.g[mat].obox(wx, wy, self.z0 + cz, sx, sy, sz, rx=rx, ry=ry, rz=self.rz + rz)

    def box(self, mat, x0, x1, y0, y1, z0, z1):
        self.ob(mat, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)

    def cyl(self, mat, cx, cy, cz, r0, r1, h, seg=10):
        wx, wy = self.P(cx, cy)
        self.g[mat].cyl(wx, wy, self.z0 + cz, r0, r1, h, seg=seg)

    def hcyl(self, mat, cx, cy, cz, r, ln, axis="x", seg=10):
        wx, wy = self.P(cx, cy)
        self.g[mat].hcyl(wx, wy, self.z0 + cz, r, ln, axis=axis, seg=seg, rz=self.rz)

    def coll(self, x0, x1, y0, y1, z0, z1):
        wx, wy = self.P((x0 + x1) / 2, (y0 + y1) / 2)
        C(wx, wy, self.z0 + (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, self.rz)


def prism(g, mat, pts, z0, z1):
    """평면 볼록 다각형(반시계) 기둥꼴"""
    n = len(pts)
    v = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g[mat].add_mesh(v, f)


def chamfer_pts(x0, x1, y0, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def _turn(pts, x, y, rz):
    c, s = math.cos(rz), math.sin(rz)
    return [(x + px * c - py * s, y + px * s + py * c) for px, py in pts]


# ------------------------------------------------------------------ 통·상자·자루
def barrel(g, x, y, z0, r=0.9, h=2.3, coll=True, lid=True):
    """배 부른 통: 널 12 쪽 × 두 마디(밑·위 r, 허리 r×1.12) — 널은 Wood/Timber 번갈아(널 이음이 읽힘) · 쇠테 셋 · 뚜껑(테 안쪽 판 + 마개)"""
    n = 12
    rm = r * 1.12
    hh = h / 2
    w = 2 * math.pi * rm / n * 1.04
    lean = math.atan2(rm - r, hh)
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        mat = "Wood" if k % 2 else "Timber"
        for zc, sgn in ((z0 + hh / 2, 1), (z0 + hh * 1.5, -1)):
            rc = (r + rm) / 2 - 0.09
            g[mat].obox(x + rc * math.cos(a), y + rc * math.sin(a), zc, 0.18, w, hh / math.cos(lean) + 0.02, ry=-sgn * lean, rz=a)
    for zz, rr in ((z0 + 0.25, r + 0.05), (z0 + hh, rm + 0.04), (z0 + h - 0.35, r + 0.05)):
        g["Iron"].cyl(x, y, zz - 0.08, rr, rr, 0.16, seg=n)
    if lid:
        g["Timber"].cyl(x, y, z0 + h - 0.22, r - 0.06, r - 0.06, 0.12, seg=n)
        g["Wood"].cyl(x - r * 0.35, y, z0 + h - 0.1, 0.14, 0.14, 0.08, seg=6)
    if coll:
        C(x, y, z0 + h / 2, 2 * rm, 2 * rm, h)


def crate(g, x, y, z0, w=2.0, d=2.0, h=2.0, rz=0.0, coll=True):
    """상자: 안 판(Wood) + 모서리 각재 12(Timber) + 네 옆면 한 줄 가새 + 쇠 모서리 덮개 8"""
    A = At(g, x, y, z0, rz)
    e = 0.18
    A.box("Wood", -w / 2 + 0.06, w / 2 - 0.06, -d / 2 + 0.06, d / 2 - 0.06, 0.02, h - 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            A.ob("Timber", sx * (w / 2 - e / 2), sy * (d / 2 - e / 2), h / 2, e, e, h)
    for zc in (e / 2, h - e / 2):
        for sy in (-1, 1):
            A.ob("Timber", 0, sy * (d / 2 - e / 2), zc, w - 2 * e, e, e)
        for sx in (-1, 1):
            A.ob("Timber", sx * (w / 2 - e / 2), 0, zc, e, d - 2 * e, e)
    L1 = math.hypot(w - 2 * e, h - 2 * e)
    a1 = math.atan2(h - 2 * e, w - 2 * e)
    for sy in (-1, 1):
        A.ob("Timber", 0, sy * (d / 2 - 0.05), h / 2, L1, 0.12, 0.2, ry=-a1 * sy)
    L2 = math.hypot(d - 2 * e, h - 2 * e)
    a2 = math.atan2(h - 2 * e, d - 2 * e)
    for sx in (-1, 1):
        A.ob("Timber", sx * (w / 2 - 0.05), 0, h / 2, 0.12, L2, 0.2, rx=a2 * sx)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for zc in (0.15, h - 0.15):
                A.ob("Iron", sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), zc, 0.3, 0.3, 0.32)
    if coll:
        A.coll(-w / 2, w / 2, -d / 2, d / 2, 0, h)


def sack(g, x, y, z0, s=1.0, rz=0.0, mat="Canvas", tie="Leather", mark=None):
    """자루: 아래가 넓은 8각 몸 두 마디(불룩) + 좁아지는 어깨 + 묶은 목 + 끈. mark = 앞면 표지(한 면만). 비평 1차: 계단 상자처럼 보여 8각으로"""
    A = At(g, x, y, z0, rz)
    for z0_, z1_, w, d in ((0.0, 0.62, 1.3, 1.05), (0.62, 1.0, 1.12, 0.9)):
        prism(g, mat, [A.P(px, py) for px, py in chamfer_pts(-w * s / 2, w * s / 2, -d * s / 2, d * s / 2, 0.3 * s)], z0 + z0_ * s, z0 + z1_ * s)
    A.ob(mat, 0, 0.02, 1.12 * s, 0.75 * s, 0.62 * s, 0.24 * s, rx=0.1, rz=0.2)
    A.cyl(tie, 0, 0, 1.24 * s, 0.2 * s, 0.2 * s, 0.12 * s, seg=6)
    A.cyl(mat, 0, 0, 1.36 * s, 0.17 * s, 0.32 * s, 0.24 * s, seg=6)
    A.ob(tie, 0.22 * s, -0.1 * s, 1.18 * s, 0.08 * s, 0.08 * s, 0.4 * s, ry=0.5)
    if mark:
        A.ob(mark, 0, -0.53 * s, 0.38 * s, 0.36 * s, 0.03, 0.36 * s, ry=0.785)


# ------------------------------------------------------------------ 병·책
def bottle(g, x, y, z0, liquid="SignTeal", h=1.0, r=0.22, label="Paint", square=False):
    """병: 물약 찬 몸(아래 60%) + 유리 몸 위 + 어깨 + 목 + 코르크 + 라벨 띠(앞 -y 쪽에 두툼한 판)"""
    seg = 4 if square else 8
    g[liquid].cyl(x, y, z0, r, r, h * 0.36, seg=seg)
    g["Glass"].cyl(x, y, z0 + h * 0.36, r, r, h * 0.22, seg=seg)
    g["Glass"].cyl(x, y, z0 + h * 0.58, r, r * 0.42, h * 0.14, seg=seg)
    g["Glass"].cyl(x, y, z0 + h * 0.72, r * 0.36, r * 0.36, h * 0.16, seg=6)
    g["Wood"].cyl(x, y, z0 + h * 0.88, r * 0.4, r * 0.32, h * 0.12, seg=6)
    if label:
        bx(g, label, x - r * 0.75, x + r * 0.75, y - r - 0.03, y - r * 0.6, z0 + h * 0.12, z0 + h * 0.34)


# 책 손 표: (두께, 높이, 색) — 줄 세울 때 이 순서대로 돈다(무작위 아님)
BOOKS = ((0.34, 1.25, "Banner"), (0.28, 1.1, "Leather"), (0.4, 1.35, "PaintGreen"), (0.26, 1.0, "SignBlue"),
         (0.32, 1.2, "Leather"), (0.44, 1.4, "Banner"), (0.3, 1.05, "Timber"), (0.36, 1.3, "SignBlue"),
         (0.27, 1.15, "PaintGreen"), (0.38, 1.25, "Leather"))


def book(g, x, y, z0, w, d, h, mat, rz=0.0, lean=0.0):
    """책(등이 -y 를 봄): 앞뒤 표지 + 등 + 속장(위로 0.05 낮게 — 위에서 보면 밝은 종이 줄) + 등 띠 둘. lean = 옆으로 기댄 각"""
    A = At(g, x, y, z0, rz)
    ct = min(0.07, w * 0.22)
    cz = h / 2 * math.cos(lean)
    for sx in (-1, 1):
        A.ob(mat, sx * (w / 2 - ct / 2) + h / 2 * math.sin(lean), 0, cz, ct, d, h, ry=lean)
    A.ob(mat, h / 2 * math.sin(lean), -d / 2 + 0.04, cz, w, 0.08, h, ry=lean)
    A.ob("Paint", h / 2 * math.sin(lean) - 0.02 * math.sin(lean), 0.03, cz - 0.03, w - 2 * ct + 0.005, d - 0.08, h - 0.06, ry=lean)
    for fz in (0.18, 0.8):
        dz = (fz - 0.5) * h
        A.ob("SignGold", h / 2 * math.sin(lean) + dz * math.sin(lean), -d / 2 + 0.005, cz + dz * math.cos(lean), w + 0.01, 0.03, 0.08, ry=lean)


def book_row(g, x0, x1, y, z0, depth=0.85, start=0, face=-1, lean_end=True):
    """x0..x1 에 BOOKS 손 표 순서로 책을 세운다(등이 face 쪽). 끝에 남는 자리가 0.7 넘으면 마지막 책을 기댄다"""
    rz = 0.0 if face < 0 else math.pi
    x, k = x0 + 0.05, start
    while True:
        w, h, m = BOOKS[k % len(BOOKS)]
        if x + w > x1 - 0.05:
            break
        book(g, x + w / 2, y, z0, w, depth, h, m, rz=rz)
        x += w + 0.02
        k += 1
    w, h, m = BOOKS[k % len(BOOKS)]
    room = x1 - x
    if lean_end and room > 0.7 and h < 1.4:
        lean = -math.asin(min(0.9, (room - w - 0.1) / h)) * 0.6
        book(g, x + w / 2 + 0.05, y, z0, w, depth, h, m, rz=rz, lean=lean * (1 if face < 0 else -1))
    return k + 1


# ------------------------------------------------------------------ 걸상·의자·탁자
def stool(g, x, y, z0, h=1.9, r=0.62, rz=0.0, coll=False):
    A = At(g, x, y, z0, rz)
    A.cyl("Wood", 0, 0, h - 0.22, r, r, 0.22, seg=10)
    A.cyl("Timber", 0, 0, h - 0.3, r - 0.08, r - 0.12, 0.08, seg=10)
    sp = 0.12
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        lx, ly = (r - 0.2) * math.cos(a), (r - 0.2) * math.sin(a)
        A.ob("Timber", lx * 1.12, ly * 1.12, (h - 0.3) / 2, 0.16, 0.16, h - 0.3, rx=-math.sin(a) * sp, ry=math.cos(a) * sp)
    for k in range(4):
        a = k * math.pi / 2
        A.ob("Timber", 0.42 * math.cos(a + math.pi / 4), 0.42 * math.sin(a + math.pi / 4), h * 0.32, 0.62, 0.1, 0.1, rz=a + math.pi / 2 + math.pi / 4)
    if coll:
        A.coll(-r, r, -r, r, 0, h)


def chair(g, x, y, z0, rz=0.0, seat="Wood", coll=True):
    """등받이 의자(앞 = -y): 따낸 자리 · 다리 넷(뒷다리가 등 기둥으로 이어짐) · H 가름대 · 등 살 셋 · 윗대"""
    A = At(g, x, y, z0, rz)
    zs = 1.75
    pts = _turn(chamfer_pts(-0.75, 0.75, -0.75, 0.7, 0.18), 0, 0, 0)
    q = At(g, x, y, z0, rz)
    prism(g, seat, [q.P(px, py) for px, py in pts], z0 + zs - 0.2, z0 + zs)
    for sx in (-1, 1):
        A.box("Timber", sx * 0.6 - 0.09, sx * 0.6 + 0.09, -0.6 - 0.09, -0.6 + 0.09, 0, zs - 0.2)
        A.box("Timber", sx * 0.6 - 0.1, sx * 0.6 + 0.1, 0.55 - 0.1, 0.55 + 0.1, 0, zs + 2.0)
        A.box("Timber", sx * 0.6 - 0.06, sx * 0.6 + 0.06, -0.5, 0.45, 0.5, 0.62)
    A.box("Timber", -0.55, 0.55, -0.05, 0.05, 0.5, 0.6)
    A.box("Timber", -0.62, 0.62, -0.62, -0.54, zs - 0.38, zs - 0.2)
    for k in range(3):
        xx = -0.3 + 0.3 * k
        A.box("Wood", xx - 0.07, xx + 0.07, 0.52, 0.6, zs + 0.15, zs + 1.75)
    A.box("Wood", -0.72, 0.72, 0.46, 0.66, zs + 1.75, zs + 2.1)
    A.box("Timber", -0.6, 0.6, 0.5, 0.62, zs + 0.05, zs + 0.2)
    if coll:
        A.coll(-0.75, 0.75, -0.75, 0.7, 0, zs)


def table(g, x0, x1, y0, y1, z0, h=2.6, top="Wood", coll=True):
    """탁자: 모서리 따낸 상판(0.22) + 앞판(apron 0.45) + 다리 넷(밑동 굵은 두 마디) + 긴 가름대"""
    zt = z0 + h
    prism(g, top, chamfer_pts(x0, x1, y0, y1, 0.22), zt - 0.22, zt)
    ix0, ix1, iy0, iy1 = x0 + 0.35, x1 - 0.35, y0 + 0.3, y1 - 0.3
    bx(g, "Timber", ix0, ix1, iy0, iy0 + 0.12, zt - 0.67, zt - 0.22)
    bx(g, "Timber", ix0, ix1, iy1 - 0.12, iy1, zt - 0.67, zt - 0.22)
    bx(g, "Timber", ix0, ix0 + 0.12, iy0, iy1, zt - 0.67, zt - 0.22)
    bx(g, "Timber", ix1 - 0.12, ix1, iy0, iy1, zt - 0.67, zt - 0.22)
    for lx in (ix0 + 0.12, ix1 - 0.12):
        for ly in (iy0 + 0.12, iy1 - 0.12):
            bx(g, "Timber", lx - 0.17, lx + 0.17, ly - 0.17, ly + 0.17, z0, z0 + 0.35)
            bx(g, "Timber", lx - 0.13, lx + 0.13, ly - 0.13, ly + 0.13, z0 + 0.35, zt - 0.22)
    if ix1 - ix0 >= iy1 - iy0:
        bx(g, "Timber", ix0 + 0.12, ix1 - 0.12, (iy0 + iy1) / 2 - 0.07, (iy0 + iy1) / 2 + 0.07, z0 + 0.55, z0 + 0.7)
        for lx in (ix0 + 0.12, ix1 - 0.12):
            bx(g, "Timber", lx - 0.07, lx + 0.07, iy0 + 0.12, iy1 - 0.12, z0 + 0.55, z0 + 0.7)
    else:
        bx(g, "Timber", (ix0 + ix1) / 2 - 0.07, (ix0 + ix1) / 2 + 0.07, iy0 + 0.12, iy1 - 0.12, z0 + 0.55, z0 + 0.7)
        for ly in (iy0 + 0.12, iy1 - 0.12):
            bx(g, "Timber", ix0 + 0.12, ix1 - 0.12, ly - 0.07, ly + 0.07, z0 + 0.55, z0 + 0.7)
    if coll:
        K.cbox(x0, x1, y0, y1, z0, zt)
    return zt


# ------------------------------------------------------------------ 선반·천·깔개·벽등
def shelf(g, ax, c, u0, u1, z0, h, depth=1.1, levels=4, face=-1, bay=3.2, lip="Timber", back=True, coll=True):
    """
    벽 선반(벽 면 c 에 등을 대고 face 쪽으로 열림): 옆판·사이 판(bay 간격) + 단 판(Wood, 앞 턱) + 단 밑 까치발(옆판마다) +
    머리 장식(DarkLog 두 켜) + 뒤판(세로 판 두 색). 돌려줌: 단 윗면 높이들(아래부터)
    """
    f = face

    def B(mat, a, b, d0, d1, za, zb):
        """a..b = 벽 따라, d0..d1 = 벽에서 방 쪽 거리"""
        p0, p1 = sorted((c + f * d0, c + f * d1))
        if ax == "x":
            bx(g, mat, a, b, p0, p1, za, zb)
        else:
            bx(g, mat, p0, p1, a, b, za, zb)
    n = max(1, int(round((u1 - u0) / bay)))
    posts = [u0 + (u1 - u0) * i / n for i in range(n + 1)]
    for i, u in enumerate(posts):
        a, b = (u, u + 0.2) if i == 0 else ((u - 0.2, u) if i == n else (u - 0.1, u + 0.1))
        B("DarkLog", a, b, 0.0, depth, z0, z0 + h)
    if back:
        nb = max(2, int(round((u1 - u0) / 0.9)))
        for i in range(nb):
            a = u0 + (u1 - u0) * i / nb
            B("Timber" if i % 2 else "DarkLog", a, a + (u1 - u0) / nb, 0.0, 0.12, z0 + 0.3, z0 + h - 0.2)
    tops = []
    gap = (h - 0.6) / levels
    for k in range(levels):
        zb = z0 + 0.3 + k * gap
        B("Wood", u0 + 0.2, u1 - 0.2, 0.1, depth, zb, zb + 0.14)
        B(lip, u0 + 0.2, u1 - 0.2, depth - 0.1, depth + 0.05, zb + 0.14, zb + 0.3)
        tops.append(zb + 0.14)
        if k > 0:
            for i, u in enumerate(posts):       # 까치발: 판 밑 세모 버팀(옆판 양쪽)
                for sd in ((1,) if i == 0 else ((-1,) if i == n else (-1, 1))):
                    uu = u + sd * (0.2 if i in (0, n) else 0.1) + sd * 0.09
                    if ax == "x":
                        g["DarkLog"].obox(uu, c + f * depth * 0.45, zb - 0.35, 0.14, depth * 0.75, 0.16, rx=-f * 0.6)
                    else:
                        g["DarkLog"].obox(c + f * depth * 0.45, uu, zb - 0.35, depth * 0.75, 0.14, 0.16, ry=f * 0.6)
    B("DarkLog", u0 - 0.1, u1 + 0.1, 0.0, depth + 0.15, z0 + h - 0.25, z0 + h)
    B("Timber", u0 - 0.2, u1 + 0.2, 0.0, depth + 0.3, z0 + h, z0 + h + 0.18)
    B("DarkLog", u0, u1, 0.0, depth, z0, z0 + 0.3)
    if coll:
        p0, p1 = sorted((c, c + f * depth))
        if ax == "x":
            K.cbox(u0, u1, p0, p1, z0, z0 + h)
        else:
            K.cbox(p0, p1, u0, u1, z0, z0 + h)
    return tops


def cloth_hang(g, ax, c, u0, u1, z0, z1, face=-1, mat="Banner", rod="Brass", pleat=0.7):
    """매단 천: 위 막대(놋쇠) + 세로 주름 판(폭 pleat, 번갈아 ±0.35 비틀어 각진 지그재그) + 아랫단 술(SignGold 띠)"""
    n = max(2, int(round((u1 - u0) / pleat)))
    w = (u1 - u0) / n
    off = c + face * 0.25
    for i in range(n):
        u = u0 + w * (i + 0.5)
        t = 0.35 if i % 2 else -0.35
        if ax == "x":
            g[mat].obox(u, off + face * (0.06 if i % 2 else 0.0), (z0 + z1) / 2, w / math.cos(t) + 0.04, 0.1, z1 - z0, rz=t)
        else:
            g[mat].obox(off + face * (0.06 if i % 2 else 0.0), u, (z0 + z1) / 2, 0.1, w / math.cos(t) + 0.04, z1 - z0, rz=t)
    a0, a1 = sorted((c, off + face * 0.14))                       # 막대 받침 쇠 팔(벽 → 막대, 2026-11-28 playcheck: 막대가 벽에서 떠 있었다)
    if ax == "x":
        g[rod].hcyl((u0 + u1) / 2, off, z1 + 0.1, 0.12, u1 - u0 + 0.6, axis="x", seg=8)
        bx(g, "SignGold", u0, u1, off - 0.12, off + 0.12, z0, z0 + 0.15)
        for u in (u0 - 0.15, u1 + 0.15):
            bx(g, "Iron", u - 0.08, u + 0.08, a0, a1, z1 - 0.05, z1 + 0.25)
    else:
        g[rod].hcyl(off, (u0 + u1) / 2, z1 + 0.1, 0.12, u1 - u0 + 0.6, axis="y", seg=8)
        bx(g, "SignGold", off - 0.12, off + 0.12, u0, u1, z0, z0 + 0.15)
        for u in (u0 - 0.15, u1 + 0.15):
            bx(g, "Iron", a0, a1, u - 0.08, u + 0.08, z1 - 0.05, z1 + 0.25)


def rug(g, x0, x1, y0, y1, z0, mat="Banner", edge="SignGold", motif="SignGold"):
    """깔개(두께 0.06 + 테 0.03): 바탕 · 둘레 테(0.35 안쪽) · 가운데 마름모"""
    bx(g, mat, x0, x1, y0, y1, z0, z0 + 0.06)
    e, t = 0.35, 0.2
    for a0, a1, b0, b1 in ((x0 + e, x1 - e, y0 + e, y0 + e + t), (x0 + e, x1 - e, y1 - e - t, y1 - e),
                           (x0 + e, x0 + e + t, y0 + e + t, y1 - e - t), (x1 - e - t, x1 - e, y0 + e + t, y1 - e - t)):
        bx(g, edge, a0, a1, b0, b1, z0 + 0.06, z0 + 0.09)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    s = min(x1 - x0, y1 - y0) * 0.22
    prism(g, motif, [(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], z0 + 0.06, z0 + 0.09)


def sconce(g, ax, c, u, z, face=-1, lamp=True):
    """벽등: 놋쇠 받침판 · 쇠 팔(0.9 내밈) · 놋쇠 갓 · 유리 등 · 불빛 · 밑 꼭지. ax/c = 벽 축·벽 면, u = 벽 따라, z = 등 가운데"""
    def Pt(d, du=0.0):
        return (u + du, c + face * d) if ax == "x" else (c + face * d, u + du)
    x, y = Pt(0.06)
    if ax == "x":
        bx(g, "Brass", u - 0.3, u + 0.3, *sorted((c, c + face * 0.12)), z - 0.9, z + 0.3)
    else:
        bx(g, "Brass", *sorted((c, c + face * 0.12)), u - 0.3, u + 0.3, z - 0.9, z + 0.3)
    ax2 = "y" if ax == "x" else "x"
    mx, my = Pt(0.5)
    g["Iron"].hcyl(mx, my, z - 0.55, 0.07, 0.9, axis=ax2, seg=6)
    lx, ly = Pt(0.95)
    g["Iron"].cyl(lx, ly, z - 0.62, 0.22, 0.16, 0.12, seg=8)
    g["Glass"].cyl(lx, ly, z - 0.5, 0.3, 0.3, 0.75, seg=8)
    g["Glow"].cyl(lx, ly, z - 0.42, 0.1, 0.06, 0.4, seg=6)
    g["Brass"].cyl(lx, ly, z + 0.25, 0.4, 0.12, 0.3, seg=8)
    g["Brass"].cyl(lx, ly, z + 0.55, 0.06, 0.06, 0.2, seg=6)
    if lamp:
        g["LampPt"].box(lx, ly, z - 0.1, 0.3, 0.3, 0.3)


# ------------------------------------------------------------------ 은행
def strongbox(g, x, y, z0, w=2.2, d=1.5, h=1.5, rz=0.0, coll=True):
    """쇠 궤(앞 = -y): 몸(Iron) · 뚜껑(조금 넓게) · 놋쇠 띠 둘(세로) · 자물쇠판 + 열쇠 구멍 · 옆 손잡이 둘 · 모서리 리벳"""
    A = At(g, x, y, z0, rz)
    A.box("Iron", -w / 2, w / 2, -d / 2, d / 2, 0, h - 0.3)
    A.box("Iron", -w / 2 - 0.06, w / 2 + 0.06, -d / 2 - 0.06, d / 2 + 0.06, h - 0.3, h)
    for bxx in (-w * 0.3, w * 0.3):
        A.box("Brass", bxx - 0.1, bxx + 0.1, -d / 2 - 0.08, d / 2 + 0.08, -0.0, h + 0.03)
    A.box("Brass", -0.28, 0.28, -d / 2 - 0.1, -d / 2, h * 0.35, h * 0.75)
    A.box("Char", -0.05, 0.05, -d / 2 - 0.13, -d / 2 - 0.08, h * 0.45, h * 0.62)
    for sx in (-1, 1):
        A.hcyl("Iron", sx * (w / 2 + 0.12), 0, h * 0.55, 0.06, 0.7, axis="y", seg=6)
        A.box("Iron", sx * (w / 2) - 0.04, sx * (w / 2) + 0.04, -0.4, 0.4, h * 0.55 - 0.08, h * 0.55 + 0.08)
    if coll:
        A.coll(-w / 2 - 0.1, w / 2 + 0.1, -d / 2 - 0.1, d / 2 + 0.1, 0, h)


def gold_bar(g, x, y, z0, rz=0.0, s=1.0):
    """금괴: 밑 0.9×0.45 · 윗면 0.7×0.3 · 높이 0.3 (기둥꼴 — 사다리꼴 옆면)"""
    a, b, at, bt, hh = 0.45 * s, 0.22 * s, 0.35 * s, 0.15 * s, 0.3 * s
    c, sn = math.cos(rz), math.sin(rz)

    def P(px, py, pz):
        return (x + px * c - py * sn, y + px * sn + py * c, z0 + pz)
    v = [P(-a, -b, 0), P(a, -b, 0), P(a, b, 0), P(-a, b, 0), P(-at, -bt, hh), P(at, -bt, hh), P(at, bt, hh), P(-at, bt, hh)]
    f = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    g["Brass"].add_mesh(v, f)


def gold_stack(g, x, y, z0, rz=0.0):
    """금괴 3·2·1 쌓음(엇갈려)"""
    c, s = math.cos(rz), math.sin(rz)
    for row, (n, dz) in enumerate(((3, 0.0), (2, 0.3), (1, 0.6))):
        for i in range(n):
            lx = (i - (n - 1) / 2) * 0.95
            gold_bar(g, x + lx * c, y + lx * s, z0 + dz, rz + (0.0 if row % 2 == 0 else 0.0))


def coin_stack(g, x, y, z0, n=5, r=0.28):
    g["Brass"].cyl(x, y, z0, r, r, 0.12 * n, seg=8)
    g["SignGold"].cyl(x, y, z0 + 0.12 * n, r * 0.92, r * 0.92, 0.03, seg=8)


def ledger_open(g, x, y, z0, rz=0.0):
    """펼친 장부(앞 = -y 독자 쪽): 표지 · 두 면(가운데로 0.06 처짐) · 글줄 넷씩(Leather 가는 띠) · 깃펜 · 잉크병"""
    A = At(g, x, y, z0, rz)
    A.box("Leather", -1.25, 1.25, -0.85, 0.85, 0, 0.08)
    for sx in (-1, 1):
        A.ob("Paint", sx * 0.6, 0, 0.14, 1.15, 1.6, 0.1, ry=-sx * 0.06)
        for k in range(4):
            A.box("Leather", sx * 0.6 - 0.45, sx * 0.6 + 0.4, -0.55 + 0.32 * k, -0.5 + 0.32 * k, 0.2 - 0.03, 0.21)
    A.cyl("Iron", 1.6, 0.5, 0, 0.18, 0.14, 0.32, seg=8)
    A.ob("Paint", 1.62, 0.38, 0.55, 0.06, 0.06, 0.9, rx=0.5)
    A.ob("Paint", 1.62, 0.25, 0.85, 0.16, 0.05, 0.4, rx=0.5)


def scale(g, x, y, z0, rz=0.0):
    """놋쇠 천칭: 받침(층 둘) · 기둥 · 들보 · 매단 접시 둘(줄 셋은 굵은 막대 하나로 줄임)"""
    A = At(g, x, y, z0, rz)
    A.box("Wood", -0.6, 0.6, -0.35, 0.35, 0, 0.18)
    A.box("Brass", -0.4, 0.4, -0.25, 0.25, 0.18, 0.3)
    A.cyl("Brass", 0, 0, 0.3, 0.07, 0.07, 1.3, seg=6)
    A.ob("Brass", 0, 0, 1.6, 1.8, 0.1, 0.1)
    A.cyl("Brass", 0, 0, 1.55, 0.12, 0.12, 0.15, seg=6)
    for sx in (-1, 1):
        A.cyl("Iron", sx * 0.85, 0, 0.75, 0.03, 0.03, 0.85, seg=4)
        A.cyl("Brass", sx * 0.85, 0, 0.65, 0.42, 0.42, 0.08, seg=10)
    coin_stack(g, *At(g, x, y, z0, rz).P(-0.85, 0), z0 + 0.73, n=2, r=0.18)


def deposit_wall(g, ax, c, u0, u1, z0, cols, rows, face=-1, cell_h=1.1, depth=1.0):
    """대여 금고 서랍 벽: 쇠 틀(바깥 테 + 칸 살) · 칸마다 문(Steel, 앞으로 0.06) · 번호판(Brass) · 열쇠 구멍(Char) · 밑 받침 · 위 놋쇠 띠. 돌려줌: 윗면 높이"""
    f = face

    def B(mat, a, b, d0, d1, za, zb):
        p0, p1 = sorted((c + f * d0, c + f * d1))
        if ax == "x":
            bx(g, mat, a, b, p0, p1, za, zb)
        else:
            bx(g, mat, p0, p1, a, b, za, zb)
    zt = z0 + 0.6 + rows * cell_h
    B("Stone", u0 - 0.1, u1 + 0.1, 0, depth + 0.1, z0, z0 + 0.6)
    B("DarkStone", u0, u1, 0, depth, z0 + 0.6, zt)
    cw = (u1 - u0) / cols
    for i in range(cols):
        for j in range(rows):
            a, b = u0 + i * cw + 0.08, u0 + (i + 1) * cw - 0.08
            za, zb = z0 + 0.6 + j * cell_h + 0.08, z0 + 0.6 + (j + 1) * cell_h - 0.08
            out = 0.5 if (i, j) in ((1, 2), (cols - 2, 4)) else 0.0      # 둘은 반쯤 빼 둔 서랍
            B("Iron", a, b, depth, depth + 0.06 + out, za, zb)
            m = (a + b) / 2
            B("Brass", m - 0.22, m + 0.22, depth + 0.06 + out, depth + 0.1 + out, zb - 0.32, zb - 0.14)
            B("Char", m - 0.05, m + 0.05, depth + 0.06 + out, depth + 0.1 + out, za + 0.22, za + 0.42)
    B("Brass", u0 - 0.1, u1 + 0.1, 0, depth + 0.14, zt, zt + 0.18)
    B("DarkLog", u0 - 0.15, u1 + 0.15, 0, depth + 0.2, zt + 0.18, zt + 0.5)
    p0, p1 = sorted((c, c + f * (depth + 0.1)))
    if ax == "x":
        K.cbox(u0, u1, p0, p1, z0, zt)
    else:
        K.cbox(p0, p1, u0, u1, z0, zt)
    return zt + 0.5


# ------------------------------------------------------------------ 대장간·잡화
def tool_board(g, ax, c, u0, u1, z0, z1, face=-1):
    def B(mat, a, b, d0, d1, za, zb):
        p0, p1 = sorted((c + face * d0, c + face * d1))
        if ax == "x":
            bx(g, mat, a, b, p0, p1, za, zb)
        else:
            bx(g, mat, p0, p1, a, b, za, zb)
    B("Timber", u0, u1, 0, 0.22, z0, z1)
    for za in (z0, z1 - 0.25):
        B("DarkLog", u0 - 0.1, u1 + 0.1, 0, 0.32, za, za + 0.25)


def hammer(g, x, y, z, rz=0.0, ry=0.0, s=1.0):
    """망치(자루 세로 기준 — z = 자루 밑): 자루(Wood) + 쇠 머리(두 마디) + 쐐기(Brass). ry 로 기울임"""
    A = At(g, x, y, z, rz)
    L = 1.9 * s
    A.ob("Wood", math.sin(ry) * L / 2, 0, math.cos(ry) * L / 2, 0.14 * s, 0.14 * s, L, ry=ry)
    hx, hz = math.sin(ry) * L, math.cos(ry) * L
    A.ob("Iron", hx, 0, hz, 0.75 * s, 0.32 * s, 0.32 * s, ry=ry)
    A.ob("Iron", hx + math.cos(ry) * 0.42 * s, 0, hz - math.sin(ry) * 0.42 * s, 0.14 * s, 0.38 * s, 0.38 * s, ry=ry)
    A.ob("Brass", hx, 0, hz + 0.17 * s, 0.1 * s, 0.1 * s, 0.06 * s, ry=ry)


def tongs(g, x, y, z, rz=0.0, s=1.0):
    """집게(걸린 모습 — z = 위 고리): 고리 · 두 다리(벌어짐) · 입(꺾임)"""
    A = At(g, x, y, z, rz)
    A.hcyl("Iron", 0, 0, -0.1, 0.12 * s, 0.06, axis="y", seg=8)
    for sx in (-1, 1):
        A.ob("Iron", sx * 0.08 * s, 0, -1.0 * s, 0.09 * s, 0.09 * s, 1.8 * s, ry=sx * 0.06)
        A.ob("Iron", sx * 0.16 * s, 0, -1.95 * s, 0.1 * s, 0.1 * s, 0.4 * s, ry=-sx * 0.35)


def pot(g, x, y, z0, r=0.55, h=0.7, mat="Iron"):
    g[mat].cyl(x, y, z0, r * 0.85, r, h, seg=10)
    g[mat].cyl(x, y, z0 + h - 0.08, r + 0.06, r + 0.06, 0.08, seg=10)
    g[mat].cyl(x, y, z0 + h, r * 0.9, r * 0.5, 0.12, seg=10)
    g["Brass"].cyl(x, y, z0 + h + 0.12, 0.08, 0.08, 0.1, seg=6)
    for sx in (-1, 1):
        bx(g, mat, x + sx * (r + 0.02), x + sx * (r + 0.18), y - 0.15, y + 0.15, z0 + h - 0.25, z0 + h - 0.12)


def rope_coil(g, x, y, z0, r=0.6):
    """밧줄 사리: 4 켜(위로 조금씩 좁게) + 늘어뜨린 끝 가닥"""
    for k in range(4):
        S.ring(g, "Canvas", x, y, z0 + k * 0.15, r - 0.24 - 0.03 * k, r - 0.03 * k, 0.14, n=12)
    g["Canvas"].obox(x + r - 0.05, y, z0 + 0.25, 0.12, 0.12, 0.5, ry=0.25)


# 마루 널 맞댄 이음 손 표(널마다 첫 토막 길이 — 이웃 널과 엇갈리게) · 토막 길이 순서
PLANK_START = (2.4, 5.1, 1.2, 3.9, 6.0, 0.6, 4.5, 2.9)
PLANK_LENS = (6.4, 5.2, 7.0, 4.8, 6.0, 5.6)


def plank_floor(g, x0, x1, y0, y1, z0, w=1.6, th=0.05, mats=("Wood", "WoodFloor")):
    """보이는 마루(충돌 없음 — 바닥 충돌은 기초가 맡는다): 널 폭 w(y 를 따라 뻗음) · 틈 0 · 이웃 널 한 톤 차 · 맞댄 이음은 손 표로 엇갈림.
    (2팀 비평: 두 색 줄무늬·계단처럼 보임 → 같은 높이, 틈 없이, 한 톤 차, 이음 엇갈림)"""
    n = max(1, int(round((x1 - x0) / w)))
    ww = (x1 - x0) / n
    for i in range(n):
        a = x0 + i * ww
        y, k = y0, i
        first = PLANK_START[i % len(PLANK_START)]
        cuts = [y0 + first] if first < y1 - y0 else []
        while cuts and cuts[-1] < y1:
            cuts.append(cuts[-1] + PLANK_LENS[k % len(PLANK_LENS)])
            k += 1
        for yb in [c for c in cuts if c < y1 - 0.3] + [y1]:
            bx(g, mats[i % 2], a, a + ww, y, yb, z0, z0 + th)
            y = yb


def slab_floor(g, x0, x1, y0, y1, z0, rows, mats, th=0.05, gap=0.0):
    """돌판 바닥(충돌 없음): rows = [(줄 깊이, [판 폭...])] 손 표, mats 를 판마다 돌려 쓴다(같은 줄 이웃은 다른 톤). 마지막 판은 끝까지"""
    y, k = y0, 0
    for depth, widths in rows:
        if y >= y1 - 0.05:
            break
        yb = min(y1, y + depth)
        x = x0
        for j, w_ in enumerate(widths):
            xb = x1 if j == len(widths) - 1 else min(x1, x + w_)
            if xb - x > 0.05:
                bx(g, mats[k % len(mats)], x + gap / 2, xb - gap / 2, y + gap / 2, yb - gap / 2, z0, z0 + th)   # gap = 줄눈(밑에 짙은 판을 깔 것)
            k += 1
            x = xb
            if x >= x1:
                break
        y = yb


def lantern_sale(g, x, y, z0, s=0.6):
    g["Iron"].box(x, y, z0 + 0.06 * s, 0.9 * s, 0.9 * s, 0.12 * s)
    g["Glass"].box(x, y, z0 + 0.12 * s + 0.45 * s, 0.7 * s, 0.7 * s, 0.9 * s)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g["Iron"].box(x + sx * 0.38 * s, y + sy * 0.38 * s, z0 + 0.6 * s, 0.1 * s, 0.1 * s, 1.0 * s)
    S.pyramid(g, "Brass", x, y, z0 + 1.1 * s, 1.0 * s, 1.0 * s, 0.45 * s)
    S.ring(g, "Iron", x, y, z0 + 1.6 * s, 0.08 * s, 0.2 * s, 0.08, n=8)


# ------------------------------------------------------------------ 잡화(2026-11-19 추가)
def tins(g, x, y, z0, n=2, r=0.3, h=0.55, mat="SignRed"):
    """깡통 쌓음: 몸(색) + 흰 라벨 띠 + 쇠 뚜껑 테 — n 개 위로"""
    for k in range(n):
        z = z0 + k * h
        g[mat].cyl(x, y, z, r, r, h - 0.06, seg=8)
        g["Paint"].cyl(x, y, z + h * 0.3, r + 0.02, r + 0.02, h * 0.3, seg=8)
        g["Iron"].cyl(x, y, z + h - 0.06, r - 0.02, r - 0.02, 0.06, seg=8)


def cloth_stack(g, x, y, z0, w=1.4, d=0.9, mats=("Banner", "Canvas", "Felt", "SignBlue"), rz=0.0):
    """접어 쌓은 천: 켜마다 색을 바꾸고 0.05 씩 어긋나게(각진 접힘 끝 — 앞면에 둥근 대신 두툼한 접힌 단)"""
    A = At(g, x, y, z0, rz)
    for k, m in enumerate(mats):
        dx = (0.05, -0.04, 0.03, -0.05)[k % 4]
        A.box(m, -w / 2 + dx, w / 2 + dx, -d / 2, d / 2, k * 0.24, k * 0.24 + 0.22)
        A.box(m, -w / 2 + dx, w / 2 + dx, -d / 2 - 0.05, -d / 2 + 0.05, k * 0.24 + 0.03, k * 0.24 + 0.19)


def boots(g, x, y, z0, rz=0.0, mat="Leather"):
    """장화 한 켤레(앞 = -y): 밑창(Char) · 발등 · 목(위로 넓어짐) · 놋쇠 단추 줄"""
    A = At(g, x, y, z0, rz)
    for sx in (-0.32, 0.32):
        A.box("Char", sx - 0.22, sx + 0.22, -0.55, 0.3, 0, 0.12)
        A.box(mat, sx - 0.2, sx + 0.2, -0.52, 0.0, 0.12, 0.45)
        A.box(mat, sx - 0.22, sx + 0.22, -0.05, 0.3, 0.12, 1.3)
        A.box(mat, sx - 0.25, sx + 0.25, -0.08, 0.33, 1.15, 1.35)
        A.box("Brass", sx - 0.04, sx + 0.04, -0.08, -0.04, 0.45, 1.0)


def candles(g, x, y, z0):
    """초 묶음: 흰 초 다섯 + 노끈(Leather)"""
    for k, (dx, dy, h) in enumerate(((0, 0, 1.0), (0.22, 0.05, 0.9), (-0.2, 0.08, 0.95), (0.08, -0.2, 0.85), (-0.1, 0.22, 0.92))):
        g["Paint"].cyl(x + dx, y + dy, z0, 0.1, 0.1, h, seg=6)
    g["Leather"].cyl(x, y, z0 + 0.4, 0.38, 0.38, 0.1, seg=8)


def snowshoe(g, x, y, z, rz=0.0, ry=0.0):
    """눈신(벽에 걸린 모습 — 판이 x-z 평면): 테(Wood 여덟 토막 타원) + 가운데 가로 살 셋(Leather) + 꼬리"""
    A = At(g, x, y, z, rz)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        A.ob("Wood", 0.45 * math.cos(a), 0, 0.85 * math.sin(a), 0.12, 0.12, 0.72 if k in (1, 2, 5, 6) else 0.5, ry=-a - math.pi / 2)
    for dz in (-0.35, 0.0, 0.35):
        A.ob("Leather", 0, 0.02, dz, 0.8, 0.06, 0.08)
    A.ob("Wood", 0, 0, -1.1, 0.12, 0.12, 0.5)


def shovel(g, x, y, z0, rz=0.0, lean=0.12):
    """눈삽(벽에 기댄 모습): 자루(Wood) · 손잡이 T · 쇠 날(넓은 판, 끝 접힘)"""
    A = At(g, x, y, z0, rz)
    L = 4.2
    A.ob("Wood", 0, math.sin(lean) * L / 2, 0.9 + L / 2 * math.cos(lean), 0.14, 0.14, L, rx=-lean)
    zt = 0.9 + L * math.cos(lean)
    A.ob("Wood", 0, math.sin(lean) * L, zt, 0.6, 0.14, 0.14)
    A.ob("Steel", 0, 0, 0.45, 0.95, 0.08, 0.9, rx=-lean)
    A.ob("Iron", 0, -0.06, 0.05, 0.95, 0.2, 0.08)


def broom(g, x, y, z0, rz=0.0, lean=0.12):
    """빗자루(기댐): 자루 · 묶음 띠(놋쇠) · 짚 술(Canvas 각진 부채꼴 둘)"""
    A = At(g, x, y, z0, rz)
    L = 3.6
    A.ob("Wood", 0, math.sin(lean) * (1.3 + L / 2), 1.3 + L / 2 * math.cos(lean), 0.12, 0.12, L, rx=-lean)
    A.ob("Brass", 0, math.sin(lean) * 1.3, 1.3, 0.3, 0.3, 0.15, rx=-lean)
    A.ob("Canvas", 0, 0.05, 0.62, 0.55, 0.3, 1.25, rx=-lean)
    A.ob("Canvas", 0, 0.05, 0.3, 0.8, 0.26, 0.6, rx=-lean)


def sled(g, x, y, z, rz=0.0):
    """썰매(매단 모습 — 밑 z): 쇠 날 둘(앞이 위로 꺾임) · 가로대 넷 · 널 판 여섯 · 끈(Leather)"""
    A = At(g, x, y, z, rz)
    for sx in (-0.75, 0.75):
        A.box("Iron", sx - 0.07, sx + 0.07, -1.9, 1.6, 0, 0.12)
        A.ob("Iron", sx, -2.09, 0.29, 0.14, 0.6, 0.12, rx=-0.9)          # 앞 꺾임(날 끝에서 앞 위로 — 2026-11-28 playcheck: 떠 있었다)
        for yy in (-1.3, -0.2, 0.9):
            A.box("Timber", sx - 0.09, sx + 0.09, yy - 0.09, yy + 0.09, 0.12, 0.6)
    for yy in (-1.3, -0.2, 0.9, 1.4):
        A.box("Timber", -0.9, 0.9, yy - 0.1, yy + 0.1, 0.6, 0.75)
    for k in range(6):
        xx = -0.75 + 0.3 * k
        A.box("Wood", xx - 0.13, xx + 0.13, -1.6, 1.6, 0.75, 0.87)
    A.ob("Leather", 0, -2.28, 0.52, 1.64, 0.14, 0.14)                  # 끈(꺾인 끝 둘을 잇는다)


def wall_bench(g, xw, s, y0, y1, z0):
    """벽(x = xw, 방 쪽 = -s)에 등을 댄 긴 의자: 따낸 자리(Wood) · 앞 띠 · 다리 셋 줄 · 가름대 · 팔걸이 둘 · 등판(가로대 둘 + 세로 살)"""
    xa, xb = sorted((xw, xw - s * 1.9))
    prism(g, "Wood", chamfer_pts(xa, xb, y0, y1, 0.2), z0 + 1.55, z0 + 1.8)
    bx(g, "Timber", *sorted((xw - s * 1.75, xw - s * 1.9)), y0 + 0.1, y1 - 0.1, z0 + 1.3, z0 + 1.55)
    for yy in (y0 + 0.4, (y0 + y1) / 2, y1 - 0.4):
        bx(g, "Timber", *sorted((xw - s * 1.5, xw - s * 1.75)), yy - 0.15, yy + 0.15, z0, z0 + 1.55)
        bx(g, "Timber", *sorted((xw - s * 0.15, xw - s * 0.4)), yy - 0.15, yy + 0.15, z0, z0 + 1.55)
    bx(g, "Timber", *sorted((xw - s * 0.4, xw - s * 1.5)), (y0 + y1) / 2 - 0.08, (y0 + y1) / 2 + 0.08, z0 + 0.4, z0 + 0.55)
    for yy in (y0 + 0.1, y1 - 0.1):
        bx(g, "DarkLog", *sorted((xw - s * 0.1, xw - s * 1.8)), yy - 0.15, yy + 0.15, z0 + 1.8, z0 + 3.0)
        bx(g, "Wood", *sorted((xw - s * 0.1, xw - s * 1.95)), yy - 0.22, yy + 0.22, z0 + 3.0, z0 + 3.2)
    for zz in (z0 + 2.6, z0 + 4.1):
        bx(g, "DarkLog", *sorted((xw - s * 0.05, xw - s * 0.3)), y0 + 0.25, y1 - 0.25, zz, zz + 0.3)
    n = int((y1 - y0 - 0.5) / 0.75)
    for k in range(n):
        yy = y0 + 0.25 + (y1 - y0 - 0.5) * (k + 0.5) / n
        bx(g, "Timber", *sorted((xw - s * 0.08, xw - s * 0.24)), yy - 0.12, yy + 0.12, z0 + 1.8, z0 + 4.1)
    K.cbox(xa, xb, y0, y1, z0, z0 + 1.8)


# ------------------------------------------------------------------ 가까이 보기(2026-11-28 아트 — 사용자 4차: 무기 품질)
# 무기는 제 좌표로 짓고 K.L.transformed(g, M, lambda q: sword(q)) 로 놓는다. 블록감·두툼(굵기 0.14 이상), 가늘고 뾰족한 것 금지.
def prism_x(g, mat, pts, x0, x1):
    """(y, z) 평면 볼록 다각형(반시계)을 x0..x1 로 민 기둥꼴(칼끝 쐐기·도끼 날)"""
    n = len(pts)
    v = [(x0, y, z) for y, z in pts] + [(x1, y, z) for y, z in pts]
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g[mat].add_mesh(v, f)


def sword(q, L=2.6, w=0.56):
    """칼(제 좌표: 칼끝 = 원점, 날이 +z, 넓이 = y, 두께 = x). 날 몸(Steel 0.12) · 가운데 등줄 두 단(양면 Iron 띠) · 각진 칼끝 쐐기 둘 ·
    리카소(Iron) · 코등이(놋쇠 가운데 덩이 + 팔 + 끝 꼭지) · 손잡이(가죽 0.26 + 감은 띠 셋) · 폼멜(놋쇠 두 단). 길이 L + 2.0"""
    tip = 0.55
    bx(q, "Steel", -0.06, 0.06, -w / 2, w / 2, tip, L)
    bx(q, "Steel", -0.1, 0.1, -0.13, 0.13, tip, L)                          # 등줄(두꺼운 가운데 — 마름모 단면을 블록으로)
    for s in (-1, 1):
        bx(q, "Iron", *sorted((s * 0.1, s * 0.13)), -0.045, 0.045, tip + 0.2, L - 0.15)   # 홈 띠(양면)
    prism_x(q, "Steel", [(w / 2, tip), (-w / 2, tip), (0.0, 0.0)], -0.06, 0.06)        # 반시계(면이 바깥을 봄)
    prism_x(q, "Steel", [(0.13, tip), (-0.13, tip), (0.0, 0.12)], -0.1, 0.1)
    bx(q, "Iron", -0.12, 0.12, -w / 2 + 0.03, w / 2 - 0.03, L, L + 0.28)      # 리카소
    bx(q, "Brass", -0.21, 0.21, -0.3, 0.3, L + 0.28, L + 0.6)                 # 코등이 가운데
    bx(q, "Brass", -0.14, 0.14, -0.78, 0.78, L + 0.34, L + 0.54)              # 코등이 팔
    for s in (-1, 1):
        bx(q, "Brass", -0.18, 0.18, *sorted((s * 0.72, s * 0.95)), L + 0.3, L + 0.62)
    bx(q, "Leather", -0.13, 0.13, -0.13, 0.13, L + 0.6, L + 1.55)
    for zz in (L + 0.72, L + 1.05, L + 1.38):
        bx(q, "Timber", -0.16, 0.16, -0.16, 0.16, zz, zz + 0.1)
    bx(q, "Brass", -0.21, 0.21, -0.21, 0.21, L + 1.55, L + 1.88)
    bx(q, "Brass", -0.13, 0.13, -0.13, 0.13, L + 1.88, L + 2.0)


def axe(q, h=3.6):
    """도끼(제 좌표: 자루 밑 = 원점, 자루 +z, 날 = -y 쪽, 두께 = x). 자루(Wood 0.24) + 밑 쇠고리 · 가죽 쥘 띠 · 쇠 머리(목 덩이) ·
    날(Steel 쐐기 — 위아래로 벌어진 초승 꼴을 블록 다각형으로) · 등 망치 쪽 · 놋쇠 쐐기"""
    bx(q, "Wood", -0.12, 0.12, -0.12, 0.12, 0.0, h)
    bx(q, "Iron", -0.15, 0.15, -0.15, 0.15, 0.0, 0.18)
    bx(q, "Leather", -0.15, 0.15, -0.15, 0.15, 0.35, 1.25)
    zc = h - 0.45
    bx(q, "Iron", -0.2, 0.2, -0.3, 0.3, zc - 0.4, zc + 0.4)                 # 목(자루를 감싼 눈)
    prism_x(q, "Iron", [(-0.3, zc - 0.3), (-0.3, zc + 0.3), (-0.75, zc + 0.42), (-0.75, zc - 0.42)], -0.15, 0.15)
    prism_x(q, "Steel", [(-0.75, zc - 0.42), (-0.75, zc + 0.42), (-1.25, zc + 0.78), (-1.38, zc + 0.3), (-1.38, zc - 0.3), (-1.25, zc - 0.78)], -0.1, 0.1)
    bx(q, "Iron", -0.17, 0.17, 0.3, 0.62, zc - 0.22, zc + 0.22)              # 등(망치 쪽)
    bx(q, "Brass", -0.08, 0.08, -0.08, 0.08, h, h + 0.08)


def spear(q, h=5.6):
    """창(제 좌표: 자루 밑 = 원점, +z). 자루(Wood 0.22) · 밑 쇠 물미 · 가죽 쥘 띠 · 놋쇠 고리 · 쇠 투겁 · 창날(두께 0.14 쐐기 둘 + 등줄)"""
    bx(q, "Wood", -0.11, 0.11, -0.11, 0.11, 0.0, h)
    bx(q, "Iron", -0.14, 0.14, -0.14, 0.14, 0.0, 0.3)
    bx(q, "Leather", -0.14, 0.14, -0.14, 0.14, h * 0.42, h * 0.58)
    bx(q, "Brass", -0.16, 0.16, -0.16, 0.16, h - 0.1, h + 0.05)
    bx(q, "Iron", -0.14, 0.14, -0.14, 0.14, h + 0.05, h + 0.5)
    prism_x(q, "Steel", [(-0.34, h + 0.5), (0.0, h + 0.38), (0.34, h + 0.5), (0.2, h + 1.0), (0.0, h + 1.5), (-0.2, h + 1.0)], -0.07, 0.07)
    bx(q, "Steel", -0.11, 0.11, -0.08, 0.08, h + 0.5, h + 1.2)


def shield(q, r=1.15, mat="Wood"):
    """벽에 건 둥근 방패(제 좌표: 벽 면 = y 0, 방 쪽 = -y, 가운데 = 원점). 쇠못 둘(벽 → 방패 뒤) · 널 다섯(두 색, 원에 맞춘 높이) ·
    쇠 테 조각 16 · 테 리벳 12 · 놋쇠 배꼽 두 단 + 둘레 리벳 6 · 뒤 손잡이(나무 쥘대 + 가죽 팔 끈)"""
    yb, yf = -0.4, -0.62                                                     # 방패 판 뒤·앞
    for sx in (-0.45, 0.45):
        bx(q, "Iron", sx - 0.09, sx + 0.09, yb, 0.0, r * 0.55 - 0.09, r * 0.55 + 0.09)
    n = 5
    for i in range(n):
        x0, x1 = -r + 2 * r * i / n, -r + 2 * r * (i + 1) / n
        xm = max(abs(x0), abs(x1)) if x0 * x1 > 0 else 0.0
        hz = math.sqrt(max(r * r - xm * xm, 0.0)) * 0.98 + (0.12 if xm > 0 else 0.0)
        bx(q, mat if i % 2 else "Timber", x0 + 0.01, x1 - 0.01, yf, yb, -hz, hz)
    m = 16
    for k in range(m):
        a = 2 * math.pi * (k + 0.5) / m
        q["Iron"].obox(r * math.cos(a), (yf + yb) / 2 - 0.02, r * math.sin(a), 2 * math.pi * r / m * 1.12, 0.32, 0.24, ry=-a + math.pi / 2)
    for k in range(12):
        a = 2 * math.pi * k / 12
        bx(q, "Brass", r * math.cos(a) - 0.08, r * math.cos(a) + 0.08, yf - 0.12, yf - 0.02, r * math.sin(a) - 0.08, r * math.sin(a) + 0.08)
    q["Brass"].hcyl(0, yf - 0.1, 0, 0.42, 0.2, axis="y", seg=12)
    q["Brass"].hcyl(0, yf - 0.28, 0, 0.26, 0.18, axis="y", seg=10)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.5
        bx(q, "Iron", 0.55 * math.cos(a) - 0.07, 0.55 * math.cos(a) + 0.07, yf - 0.08, yf, 0.55 * math.sin(a) - 0.07, 0.55 * math.sin(a) + 0.07)
    bx(q, "Timber", -0.4, 0.4, yb + 0.02, yb + 0.2, -0.12, 0.12)             # 쥘대(뒤)
    for sx in (-0.4, 0.4):
        bx(q, "Timber", sx - 0.08, sx + 0.08, yb, yb + 0.2, -0.15, 0.15)
    bx(q, "Leather", -0.75, 0.75, yb + 0.02, yb + 0.12, 0.35, 0.55)          # 팔 끈


def wall_weapon(g, ax, c, u, z, face, fn, tilt=0.0, flat=False):
    """벽(ax 축, 면 c, 방 쪽 = face 부호)에 제 좌표 물건 fn(q) 을 건다. 제 좌표: 벽 면 = y 0, 방 쪽 = -y(방패), 벽을 따라 = x.
    tilt = 벽 면 안에서 기울임(라디안, 제 z 가 위 → tilt π 면 아래). flat = 칼·창·도끼처럼 제 x 가 두께인 물건(두께를 벽 법선으로)"""
    from mathutils import Matrix
    if ax == "x":                               # 벽이 x 로 뻗음 — 법선 = y
        base = Matrix.Rotation(0.0 if face < 0 else math.pi, 4, "Z")
        loc = (u, c, z)
    else:
        base = Matrix.Rotation(-math.pi / 2 if face < 0 else math.pi / 2, 4, "Z")
        loc = (c, u, z)
    M = Matrix.Translation(loc) @ base @ Matrix.Rotation(tilt, 4, "Y")
    if flat:
        M = M @ Matrix.Rotation(math.pi / 2, 4, "Z")
    K.L.transformed(g, M, fn)


def armor_stand(g, x, y, z0, rz=0.0):
    """갑옷 진열대(2026-11-28): 열십자 나무 발 + 쇠 판 · 기둥 · 어깨 막대 · 흉갑(가운데 등줄 · 목·밑 테 · 리벳) · 허리 판 둘 ·
    어깨 판 셋씩(층층) · 목가리개 · 통 투구(눈 틈 · 숨 구멍 · 놋쇠 볏). 앞 = -y. 충돌 2.4×1.6"""
    A = At(g, x, y, z0, rz)
    A.box("Timber", -1.0, 1.0, -0.2, 0.2, 0.0, 0.3)
    A.box("Timber", -0.2, 0.2, -0.8, 0.8, 0.0, 0.3)
    A.box("Iron", -0.35, 0.35, -0.35, 0.35, 0.3, 0.42)
    A.box("Timber", -0.16, 0.16, -0.16, 0.16, 0.42, 4.6)
    A.box("Timber", -1.0, 1.0, -0.14, 0.14, 4.2, 4.45)
    A.box("Steel", -0.75, 0.75, -0.42, 0.3, 2.9, 4.4)                     # 흉갑
    A.box("Steel", -0.12, 0.12, -0.54, -0.4, 3.0, 4.35)                   # 등줄
    A.box("Iron", -0.78, 0.78, -0.46, 0.33, 2.85, 3.0)                    # 밑 테
    A.box("Iron", -0.5, 0.5, -0.46, 0.33, 4.3, 4.45)                      # 목 테
    for sx in (-0.55, 0.55):
        for zz in (3.3, 3.9):
            A.box("Brass", sx - 0.07, sx + 0.07, -0.5, -0.4, zz - 0.07, zz + 0.07)
    for k, zz in enumerate((2.55, 2.2)):                                   # 허리 판 둘(아래로 넓게)
        w = 0.72 + 0.06 * k
        A.box("Steel", -w, w, -0.44 - 0.03 * k, 0.32, zz, zz + 0.32)
        A.box("Iron", -w - 0.02, w + 0.02, -0.47 - 0.03 * k, 0.32, zz, zz + 0.08)
    for s in (-1, 1):                                                      # 어깨 판(층층)
        for k in range(3):
            A.ob("Steel", s * (0.85 + 0.12 * k), -0.05, 4.35 - 0.28 * k, 0.75, 0.85, 0.24, ry=-s * (0.35 + 0.15 * k))
    A.box("Iron", -0.42, 0.42, -0.36, 0.3, 4.45, 4.7)                     # 목가리개
    A.box("Steel", -0.45, 0.45, -0.5, 0.4, 4.7, 5.75)                     # 통 투구
    A.box("Iron", -0.38, 0.38, -0.56, -0.48, 5.25, 5.38)                  # 눈 틈
    for sx in (-0.2, 0.0, 0.2):
        A.box("Iron", sx - 0.05, sx + 0.05, -0.55, -0.49, 4.9, 5.1)       # 숨 구멍
    A.box("Brass", -0.1, 0.1, -0.5, 0.45, 5.75, 6.0)                      # 볏
    A.coll(-1.2, 1.2, -0.8, 0.8, 0.0, 6.0)


def chandelier(g, x, y, ztop, z):
    """놋쇠 샹들리에(2026-11-28 — 옛 SVC 것은 고리·등이 서로 안 닿아 떠 있었다): 굵은 사슬(ztop 까지) → 가운데 기둥 + 밑 방울 →
    팔 여섯(기둥 → 바깥 고리) → 고리 위 초받침 + 흰 초 + 불꽃 · 안 고리. z = 바깥 고리 밑"""
    g["Brass"].cyl(x, y, z - 0.6, 0.3, 0.2, 1.9, seg=8)
    g["Brass"].cyl(x, y, z - 0.95, 0.1, 0.3, 0.35, seg=8)
    zz, k = z + 1.3, 0
    while zz < ztop:
        top = min(zz + 0.55, ztop + 0.05)
        bx(g, "Iron", x - (0.07 if k % 2 else 0.17), x + (0.07 if k % 2 else 0.17), y - (0.17 if k % 2 else 0.07), y + (0.17 if k % 2 else 0.07), zz - 0.05, top)
        zz, k = zz + 0.5, k + 1
    S.ring(g, "Brass", x, y, z, 1.7, 1.95, 0.18, n=20)
    S.ring(g, "Brass", x, y, z + 0.7, 0.75, 0.95, 0.15, n=16)
    for k in range(4):                                                       # 안 고리 살(기둥 → 안 고리)
        a = k * math.pi / 2 + math.pi / 4
        g["Brass"].obox(x + 0.55 * math.cos(a), y + 0.55 * math.sin(a), z + 0.77, 0.75, 0.14, 0.14, rz=a)
    for k in range(6):
        a = k * math.pi / 3
        g["Iron"].obox(x + 0.95 * math.cos(a), y + 0.95 * math.sin(a), z + 0.09, 1.75, 0.14, 0.14, rz=a)
        px, py = x + 1.82 * math.cos(a), y + 1.82 * math.sin(a)
        g["Brass"].cyl(px, py, z + 0.18, 0.24, 0.2, 0.14, seg=8)
        g["Paint"].cyl(px, py, z + 0.32, 0.11, 0.11, 0.45, seg=8)
        g["Glow"].obox(px, py, z + 0.86, 0.14, 0.14, 0.18, rz=0.785)
    g["LampPt"].box(x, y, z + 0.2, 0.3, 0.3, 0.3)


def anvil_icon(g, x, y, z, s=1.0, face=-1, mat="Brass"):
    """간판 모루 그림(SVC.anvil_icon 고친 판 — 2026-11-28 playcheck: 망치 머리가 자루 반대 끝에 떠 있었다). 두께 0.2 모루 + 판에 붙은 망치"""
    y0, y1 = (y - 0.2, y) if face < 0 else (y, y + 0.2)
    k = s
    K.SVC.prism_xz(g, mat, [(x - 1.0 * k, z + 0.55 * k), (x + 0.75 * k, z + 0.55 * k), (x + 0.75 * k, z + 0.95 * k), (x - 1.15 * k, z + 0.95 * k)], y0, y1)
    K.SVC.prism_xz(g, mat, [(x + 0.75 * k, z + 0.6 * k), (x + 1.75 * k, z + 0.88 * k), (x + 0.75 * k, z + 0.95 * k)], y0, y1)
    K.SVC.prism_xz(g, mat, [(x - 0.35 * k, z + 0.1 * k), (x + 0.35 * k, z + 0.1 * k), (x + 0.3 * k, z + 0.55 * k), (x - 0.3 * k, z + 0.55 * k)], y0, y1)
    K.SVC.prism_xz(g, mat, [(x - 0.9 * k, z - 0.35 * k), (x + 0.9 * k, z - 0.35 * k), (x + 0.6 * k, z + 0.1 * k), (x - 0.6 * k, z + 0.1 * k)], y0, y1)
    yy = (y0 + y1) / 2 + face * 0.12
    a = 0.6                                                                  # 자루: 모루 윗면 오른쪽에서 왼 위로
    hx, hz = x + 0.45 * k, z + 1.0 * k
    L = 1.8 * k
    ex, ez = hx - math.sin(a) * L, hz + math.cos(a) * L
    g["Wood"].obox((hx + ex) / 2, yy, (hz + ez) / 2, 0.2 * k, 0.16, L, ry=-a)
    g["Steel"].obox(ex, yy, ez, 0.95 * k, 0.2, 0.45 * k, ry=-a)


SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


def digit(g, ch, x, y, z, s=0.5, mat="DarkStone"):
    """숫자 한 자(일곱 막대 블록 — 판 면 y 앞(-y)으로 0.06 도드라짐). 가운데 (x, z), 높이 s(폭 0.6 s, 막대 굵기 0.16 s)"""
    w, t = 0.6 * s, 0.16 * s
    h = s / 2
    segs = {"a": (-w / 2, w / 2, h - t, h), "d": (-w / 2, w / 2, -h, -h + t), "g": (-w / 2, w / 2, -t / 2, t / 2),
            "f": (-w / 2, -w / 2 + t, 0, h), "b": (w / 2 - t, w / 2, 0, h), "e": (-w / 2, -w / 2 + t, -h, 0), "c": (w / 2 - t, w / 2, -h, 0)}
    for k in SEG.get(ch, ""):
        a, b, c, d = segs[k]
        bx(g, mat, x + a, x + b, y - 0.06, y, z + c, z + d)
