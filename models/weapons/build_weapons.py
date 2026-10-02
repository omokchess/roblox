# -*- coding: utf-8 -*-
"""
build_weapons.py — 전투 무기 9종(조각 12개)을 블렌더 메시로 짓고 FBX 하나로 내보낸다. (2026-10-02)
  (사용자: "무기·몬스터는 블렌더로 — 퀄리티". 설계도 = src/shared/Combat/WeaponDefinitions.luau 의 Part 정의.)

- 치수·쥐는 점(원점)·소켓은 Part 정의 그대로 지킨다(모션이 그 값으로 계산됨). 모양만 곡면·베벨·디테일로 다듬는다.
- 메시 이름 "<무기Id>_<Main|Off>_<묶음>" — 묶음마다 색·재질이 하나(WeaponDefinitions 의 Skins 와 이름이 같다).
- 원점 표지 WeaponsOrigin_Marker(무기 공간 1×1×1 상자, 원점): 스튜디오가 FBX 를 아무 데나 놓으므로 이 상자 자리를 빼서 원점을,
  크기로 스터드 배율을 되찾는다(tools/WeaponMeshes.luau).
- 렌더: models/weapons/render/<무기Id>.png (옆·3/4) → 사용자 확인용.

돌리는 법: blender -b -P models/weapons/build_weapons.py [-- 무기Id ...] [-- norender]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wlib as L  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NORENDER = "norender" in ARGS
ONLY = [a for a in ARGS if a != "norender"]


def rgb(r, g, b):
    return (r / 255) ** 2.2, (g / 255) ** 2.2, (b / 255) ** 2.2


STEEL = rgb(196, 202, 212)
STEEL_DK = rgb(88, 92, 104)
GOLD = rgb(212, 170, 84)
WOOD = rgb(104, 70, 44)
WOOD_DK = rgb(62, 42, 28)
LEATHER = rgb(70, 42, 30)
IRON = rgb(92, 86, 82)


class Piece:
    """무기 조각 하나(Main/Off) — 묶음 이름 → Group"""

    def __init__(self, wid, slot):
        self.prefix = "%s_%s_" % (wid, slot)
        self.groups = {}

    turn = 0.0

    def g(self, name, color, smooth=40.0, alpha=1.0):
        if name not in self.groups:
            self.groups[name] = L.Group(self.prefix + name, color, smooth, alpha)
            self.groups[name].turn = self.turn
        return self.groups[name]

    def finish(self):
        return [grp.finish() for grp in self.groups.values()]


# ── 결투사: 스웹트 힐트 레이피어(컵 가드 없음) ─────────────


def rapier():
    p = Piece("Rapier", "Main")
    steel, gold, grip = p.g("Steel", STEEL, 30), p.g("Gold", GOLD), p.g("Grip", rgb(40, 34, 30))
    # 리카소(날 밑동, 두꺼운 네모) → 납작 육각 날이 가늘어지며 끝(4.62)에서 모인다
    L.loft(steel, [L.section_y(0.46, L.rrect(0.058, 0.034, 0.012, 1)), L.section_y(0.78, L.rrect(0.054, 0.03, 0.012, 1))])
    secs = [(0.78, 0.05, 0.026), (1.6, 0.047, 0.024), (2.6, 0.042, 0.021), (3.5, 0.035, 0.018), (4.2, 0.024, 0.013), (4.5, 0.012, 0.008)]
    loops = [L.section_y(y, L.hexa(w, t, 0.35)) for y, w, t in secs] + [[(0, 4.62, 0)]]
    L.loft(steel, loops)
    # (컵 가드는 없앰 — 2026-10-02 사용자: "손 보호대(동그란 부분)은 없애줘". 십자 날밑·너클 보우만 남긴 스웹트 힐트)
    # 십자 날밑(살짝 S 로 휜 둥근 막대) + 끝 공
    q = [(-0.58, 0.52, 0), (-0.42, 0.475, 0), (-0.18, 0.445, 0), (0.18, 0.44, 0), (0.42, 0.41, 0), (0.58, 0.36, 0)]
    L.tube(gold, q, [0.026, 0.03, 0.033, 0.033, 0.03, 0.026], 10)
    L.ball(gold, (-0.6, 0.53, 0), 0.068, 14, 8)
    L.ball(gold, (0.6, 0.35, 0), 0.068, 14, 8)
    # 너클 보우(칼날 쪽 -Z 로 손가락을 감싸 날밑에서 손잡이 끝까지)
    bow = [(0, 0.415, -0.05), (0, 0.37, -0.2), (0, 0.22, -0.3), (0, 0.0, -0.325), (0, -0.22, -0.3), (0, -0.36, -0.19), (0, -0.42, -0.07)]
    L.tube(gold, bow, 0.026, 8)
    # 손잡이: 가운데가 부푼 통 + 금실 나선 + 양 끝 고리(터크스 헤드)
    L.lathe(grip, [(0.062, -0.33), (0.078, -0.22), (0.086, 0.0), (0.078, 0.22), (0.062, 0.345)], 16)
    L.tube(gold, L.helix(-0.29, 0.31, 0.087, 9, 14), 0.011, 5, cap=True)
    L.ring(gold, (0, -0.335, 0), 0.07, 0.022, (0, 1, 0), 18, 6)
    L.ring(gold, (0, 0.35, 0), 0.068, 0.022, (0, 1, 0), 18, 6)
    # 배 모양 폼멜 + 단추
    L.lathe(gold, [(0, -0.69), (0.035, -0.685), (0.04, -0.65), (0.07, -0.635), (0.12, -0.6), (0.15, -0.54), (0.152, -0.48),
                   (0.125, -0.42), (0.08, -0.375), (0.055, -0.345), (0, -0.335)], 20)
    return [p]


# ── 음악가: 바이올린 + 활 ─────────────────────────────


def violin_outline():
    """몸통 윤곽(오른쪽 반, 위 가운데 → 아래 가운데) — 위 울림통 0.64·허리 0.44·아래 울림통 0.78, 모서리 넷"""
    half = [(0.0, -0.21), (0.12, -0.222), (0.22, -0.265), (0.29, -0.345), (0.318, -0.445), (0.312, -0.55), (0.285, -0.618),
            (0.252, -0.652), (0.212, -0.676), (0.212, -0.74), (0.218, -0.8), (0.214, -0.86), (0.21, -0.918), (0.252, -0.944),
            (0.308, -0.968), (0.358, -1.035), (0.388, -1.135), (0.386, -1.255), (0.356, -1.37), (0.29, -1.462), (0.19, -1.526),
            (0.08, -1.552), (0.0, -1.558)]
    full = half + [(-x, y) for x, y in reversed(half[1:-1])]
    return L.smooth_outline(full, 3)


def arch(k, h):
    return h * (1 - k * k)


def violin():
    out = []
    # 활(오른손 Main): 프로그 쪽 원점, +Y 로 끝, 활털은 -Z 0.16
    b = Piece("Violin", "Main")
    wood, ebony, silver, hair = b.g("Wood", rgb(118, 52, 28)), b.g("Ebony", rgb(28, 24, 22)), b.g("Silver", rgb(200, 200, 206)), b.g("Hair", rgb(236, 230, 214))
    n = 18
    stick = [(0, 0.02 + 2.6 * i / n, -0.035 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    L.tube(wood, stick, [0.031 - 0.01 * i / n for i in range(n + 1)], 8)
    head = [(0.02, 2.6), (0.03, 2.69), (0.012, 2.79), (-0.05, 2.81), (-0.13, 2.76), (-0.172, 2.68), (-0.17, 2.6), (-0.08, 2.585)]
    L.plate(wood, head, (-0.07, 2.69), lambda u, v, k: 0.058, (1.0, 0.6), "ZY")
    L.bbox(hair, (0, 2.625, -0.168), (0.06, 0.034, 0.05), 0.006)
    L.bbox(ebony, (0, -0.12, -0.085), (0.09, 0.3, 0.15), 0.02)
    L.ball(hair, (0.046, -0.12, -0.1), 0.026, 12, 6, (0.35, 1, 1))
    L.ball(hair, (-0.046, -0.12, -0.1), 0.026, 12, 6, (0.35, 1, 1))
    L.bbox(silver, (0, 0.035, -0.125), (0.096, 0.04, 0.1), 0.008)
    L.lathe(silver, [(0.037, 0.03), (0.039, 0.16), (0.037, 0.29)], 12)
    L.lathe(silver, [(0, -0.42), (0.026, -0.415), (0.034, -0.38), (0.034, -0.31), (0.03, -0.27), (0, -0.265)], 12)
    L.bbox(hair, (0, 1.28, -0.16), (0.055, 2.66, 0.01), 0.0)
    out.append(b)

    # 바이올린(왼손 Off): 원점 = 목을 쥐는 점, 몸통 바닥 y -1.55, 윗판(줄 쪽) -Z
    v = Piece("Violin", "Off")
    varnish, spruce = v.g("Varnish", rgb(128, 58, 26)), v.g("Spruce", rgb(176, 96, 42))
    maple, ebony2 = v.g("Maple", rgb(150, 92, 50)), v.g("Ebony", rgb(28, 24, 22))
    bridge, strings = v.g("Bridge", rgb(226, 200, 150)), v.g("Strings", rgb(232, 226, 210), None)
    ol = violin_outline()
    c = (0.0, -0.88)
    rings = (1.0, 0.84, 0.64, 0.42, 0.2)
    # 옆판 + 뒤판(뒤로 볼록) — 앞쪽은 -0.075 평평(윗판이 덮는다)
    zb = lambda u, vv, k: (-0.072, 0.08 + arch(k, 0.035))
    _plate2(varnish, ol, c, zb, rings)
    # 윗판(가문비): 가장자리 -0.085 → 가운데 -0.125 로 볼록, 옆판보다 살짝 크다(오버행)
    olb = [(x * 1.012, (yy - c[1]) * 1.008 + c[1]) for x, yy in ol]
    zt = lambda u, vv, k: (-(0.085 + arch(k, 0.04)), -0.066)
    _plate2(spruce, olb, c, zt, rings)

    def top_z(x, y):
        k = min(1.0, math.sqrt((x / 0.37) ** 2 + ((y + 0.88) / 0.67) ** 2))
        return -(0.085 + arch(k, 0.04))

    # f 구멍: S 자로 굽은 검은 홈 + 양 끝 둥근 눈
    for s in (1, -1):
        fh = [(0.128, -0.735), (0.152, -0.765), (0.168, -0.815), (0.162, -0.87), (0.146, -0.925), (0.138, -0.965)]
        path = [(s * x, y, top_z(s * x, y) + 0.004) for x, y in fh]
        L.tube(ebony2, path, 0.011, 6)
        L.ball(ebony2, (s * 0.126, -0.73, top_z(s * 0.126, -0.73) + 0.003), 0.02, 10, 6, (1, 1, 0.5))
        L.ball(ebony2, (s * 0.14, -0.972, top_z(s * 0.14, -0.972) + 0.003), 0.02, 10, 6, (1, 1, 0.5))
    # 목(단풍) — 몸통에서 줄머리까지, 뒤가 둥근 단면
    L.loft(maple, [L.section_y(-0.25, L.rrect(0.07, 0.07, 0.05, 2), 0, -0.04), L.section_y(-0.12, L.rrect(0.052, 0.05, 0.04, 2), 0, -0.05),
                   L.section_y(0.26, L.rrect(0.046, 0.046, 0.035, 2), 0, -0.06)])
    # 지판(흑단): 줄머리 0.27 → 몸통 위 -0.68, 넓어지며 위가 둥글다
    L.loft(ebony2, [L.section_y(0.27, L.rrect(0.045, 0.022, 0.012, 2), 0, -0.15), L.section_y(-0.68, L.rrect(0.066, 0.022, 0.012, 2), 0, -0.15)])
    L.bbox(ebony2, (0, 0.275, -0.15), (0.1, 0.022, 0.052), 0.006)
    # 줄감개 통 + 줄감개 넷(양쪽 둘씩) + 스크롤(소용돌이)
    L.loft(maple, [L.section_y(0.27, L.rrect(0.05, 0.06, 0.02, 1), 0, -0.035), L.section_y(0.5, L.rrect(0.046, 0.056, 0.02, 1), 0, -0.03)])
    for yy, s in ((0.31, 1), (0.36, -1), (0.41, 1), (0.46, -1)):
        L.lathe(ebony2, [(0.013, 0.0), (0.013, s * 0.13), (0.016, s * 0.135), (0, s * 0.14)], 8, (0, yy, -0.03), "X")
        L.ball(ebony2, (s * 0.16, yy, -0.03), 0.045, 12, 8, (0.35, 1, 1))
    for x0, r0 in ((0.0, 0.026), (0.036, 0.018), (-0.036, 0.018)):
        sp = []
        for i in range(25):
            a = math.radians(-60 + 540 * i / 24)
            r = 0.075 - 0.055 * i / 24
            sp.append((x0, 0.56 + r * math.cos(a), -0.02 + r * math.sin(a)))
        L.tube(maple, sp, [r0 * (1 - 0.45 * i / 24) for i in range(25)], 8)
    # 줄걸이판(흑단) · 턱받침(+X 쪽, 아래) · 끝 단추
    tp = L.smooth_outline([(0.075, -1.47), (0.06, -1.3), (0.05, -1.15), (-0.05, -1.15), (-0.06, -1.3), (-0.075, -1.47), (0, -1.49)], 3)
    _plate2(ebony2, tp, (0, -1.3), lambda u, vv, k: (-0.158, -0.11), (1.0, 0.5))
    L.ball(ebony2, (0.13, -1.465, -0.12), 0.1, 16, 10, (1.6, 0.75, 0.55))
    L.lathe(ebony2, [(0, -1.605), (0.02, -1.6), (0.026, -1.575), (0.022, -1.55), (0, -1.548)], 10)
    # 줄받침(밝은 단풍): 발 둘, 위는 둥근 아치
    br = [(-0.11, -0.118), (-0.07, -0.118), (-0.055, -0.145), (0.055, -0.145), (0.07, -0.118), (0.11, -0.118),
          (0.115, -0.178), (0.09, -0.205), (0.0, -0.222), (-0.09, -0.205), (-0.115, -0.178)]
    L.plate(bridge, br, (0, -0.17), lambda u, vv, k: 0.026, (1.0, 0.5), "XZ", -0.91)
    # 줄 넷: 줄걸이판 → 줄받침 꼭대기 → 줄머리
    for i in range(4):
        f = (i - 1.5) / 1.5
        L.tube(strings, [(f * 0.034, -1.16, -0.124), (f * 0.045, -0.91, -0.224 + abs(f) * 0.012), (f * 0.03, 0.27, -0.165)], 0.0055, 5)
    out.append(v)
    return out


def _plate2(g, outline, center, zfun, rings=(1.0, 0.78, 0.52, 0.26)):
    """XY 평면 판, 고리마다 위아래 Z 를 zfun(u,v,k) → (아래, 위) 로 따로(볼록 판·평평 바닥)"""
    cu, cv = center
    n = len(outline)
    verts, faces, T, B = [], [], [], []
    for k in rings:
        t, b = [], []
        for u, v in outline:
            uu, vv = cu + (u - cu) * k, cv + (v - cv) * k
            lo, hi = zfun(uu, vv, k)
            t.append(len(verts))
            verts.append((uu, vv, lo))
            b.append(len(verts))
            verts.append((uu, vv, hi))
        T.append(t)
        B.append(b)
    lo, hi = zfun(cu, cv, 0)
    ct = len(verts)
    verts.append((cu, cv, lo))
    cb = len(verts)
    verts.append((cu, cv, hi))
    for a, b2 in zip(T, T[1:]):
        for i in range(n):
            faces.append((a[i], a[(i + 1) % n], b2[(i + 1) % n], b2[i]))
    for i in range(n):
        faces.append((T[-1][i], T[-1][(i + 1) % n], ct))
    for a, b2 in zip(B, B[1:]):
        for i in range(n):
            faces.append((a[(i + 1) % n], a[i], b2[i], b2[(i + 1) % n]))
    for i in range(n):
        faces.append((B[-1][(i + 1) % n], B[-1][i], cb))
    for i in range(n):
        faces.append((T[0][(i + 1) % n], T[0][i], B[0][i], B[0][(i + 1) % n]))
    g.add(verts, faces)


# ── 퀘이사: 츠바이핸더 ─────────────────────────────


def greatsword():
    p = Piece("Greatsword", "Main")
    # 날 넓이·날밑을 X 로 그리고 통째로 90° 돌린다 → 날이 Z 쪽(앞날 -Z = 손가락 마디 쪽). WeaponDefinitions 의 Turn = 90 과 같다
    p.turn = 90.0
    void, leather = p.g("Void", rgb(50, 48, 70), 35), p.g("Leather", LEATHER)
    gem, blade = p.g("Gem", rgb(170, 140, 255), None), p.g("Blade", rgb(34, 34, 52), 20)
    edge, core = p.g("Edge", rgb(70, 74, 104), 20), p.g("Core", rgb(140, 110, 255), None)
    # 날: 가운데 몸(어두움) + 양 날(밝은 베벨) + 가운데 빛줄기 — 1.82 에서 6.9 끝으로
    S = [(1.82, 0.45, 0.36, 0.1), (3.0, 0.44, 0.35, 0.095), (4.6, 0.41, 0.32, 0.088), (5.8, 0.37, 0.28, 0.078), (6.45, 0.25, 0.17, 0.06)]
    tip = (0, 6.92, 0)
    L.loft(blade, [L.section_y(y, [(s, t), (-s, t), (-s, -t), (s, -t)]) for y, w, s, t in S] + [[tip]])
    for side in (1, -1):
        L.loft(edge, [L.section_y(y, [(side * w, 0), (side * s, -t if side > 0 else t), (side * s, t if side > 0 else -t)]) for y, w, s, t in S] + [[tip]])
    L.loft(core, [L.section_y(1.95, [(0.05, 0.108), (-0.05, 0.108), (-0.05, -0.108), (0.05, -0.108)]),
                  L.section_y(2.2, [(0.07, 0.108), (-0.07, 0.108), (-0.07, -0.108), (0.07, -0.108)]),
                  L.section_y(5.6, [(0.06, 0.088), (-0.06, 0.088), (-0.06, -0.088), (0.06, -0.088)]),
                  [(0, 6.05, 0.0)]])
    # 리카소(가죽 감음, 결이 보이게 굵기를 번갈아) + 패링 훅 둘
    rl = []
    for i in range(10):
        y = 0.9 + 0.92 * i / 9
        bulge = 0.012 if i % 2 else 0.0
        rl.append(L.section_y(y, L.rrect(0.22 + bulge, 0.125 + bulge, 0.05, 2)))
    L.loft(leather, rl)
    for s in (1, -1):
        L.tube(void, [(s * 0.2, 1.8, 0), (s * 0.38, 1.88, 0), (s * 0.52, 1.84, 0), (s * 0.58, 1.72, 0), (s * 0.54, 1.62, 0)], [0.075, 0.068, 0.055, 0.04, 0.0], 8)
    # 날밑: 가운데 덩어리 + 끝이 처진 팔(굵은 막대) + 끝 공, 보석
    L.bbox(void, (0, 0.77, 0), (0.56, 0.3, 0.36), 0.05)
    cross = [(-1.22, 0.5, 0), (-1.08, 0.64, 0), (-0.8, 0.75, 0), (-0.3, 0.78, 0), (0.3, 0.78, 0), (0.8, 0.75, 0), (1.08, 0.64, 0), (1.22, 0.5, 0)]
    L.tube(void, cross, [0.1, 0.12, 0.13, 0.14, 0.14, 0.13, 0.12, 0.1], 8, section=L.rrect(1.0, 0.9, 0.35, 1))
    for s in (1, -1):
        L.ball(void, (s * 1.25, 0.46, 0), 0.13, 12, 8, (1, 1.3, 1))
    L.lathe(gem, [(0, -0.25), (0.19, 0), (0, 0.25)], 4, (0, 0.77, 0), "Z", math.pi / 4)
    # 손잡이: 가죽 통 + 나선 끈 + 가운데 고리 · 폼멜(향수병 마개 모양)
    L.lathe(leather, [(0.13, -0.86), (0.145, -0.6), (0.15, -0.1), (0.14, 0.4), (0.13, 0.64)], 16)
    L.tube(leather, L.helix(-0.84, 0.6, 0.15, 7, 16), 0.018, 5)
    L.ring(void, (0, -0.28, 0), 0.155, 0.035, (0, 1, 0), 20, 6)
    L.lathe(void, [(0, -1.44), (0.07, -1.43), (0.11, -1.38), (0.12, -1.31), (0.15, -1.27), (0.22, -1.2), (0.26, -1.08),
                   (0.25, -0.96), (0.2, -0.87), (0.13, -0.81), (0, -0.8)], 20)
    return [p]


# ── 펄서: 오브 ─────────────────────────────────


def orbs():
    p = Piece("Orbs", "Main")
    shell, core, band = p.g("Shell", rgb(110, 220, 255), 80, 0.65), p.g("Core", rgb(150, 240, 255), None), p.g("Band", rgb(60, 110, 170))
    L.ball(shell, (0, 0, 0), 0.5, 32, 16)
    L.ball(core, (0, 0, 0), 0.26, 20, 10)
    a = math.radians(30)
    L.ring(band, (0, 0, 0), 0.56, 0.036, (-math.sin(a), math.cos(a), 0), 40, 8)
    L.ring(band, (0, 0, 0), 0.56, 0.036, (0, math.cos(a), math.sin(a)), 40, 8)
    # 두 띠가 만나는 두 곳에 죔쇠(두 띠 평면이 겹치는 선 위)
    n1 = Vector((-math.sin(a), math.cos(a), 0))
    n2 = Vector((0, math.cos(a), math.sin(a)))
    d = n1.cross(n2).normalized() * 0.56
    for s in (1, -1):
        L.ball(band, tuple(d * s), 0.06, 10, 6)
    return [p]


# ── 월 필그림: 역수로 쥔 대장간 못 ───────────────────


def nail(slot, k, tip_y, ribbon):
    p = Piece("PilgrimNails", slot)
    head, iron, cloth = p.g("Head", rgb(70, 66, 62), 25), p.g("Iron", IRON, 25), p.g("Cloth", rgb(140, 36, 36))
    # 장미 머리: 네 면 피라미드처럼 두드린 머리(주먹 위 = -Y 쪽)
    L.lathe(head, [(0, -0.565 * k), (0.15 * k, -0.555 * k), (0.29 * k, -0.47 * k), (0.315 * k, -0.4 * k), (0.28 * k, -0.33 * k), (0.15 * k, -0.3 * k), (0, -0.3 * k)], 4, phase=math.pi / 4)
    # 네모 몸: 쥔 자리에서 끝으로 가늘어지며 한 번 비틀린 단조 자국
    secs = [(-0.31, 0.13), (0.32, 0.13), (0.9, 0.12), (1.5, 0.105), (2.0, 0.088), (tip_y - 0.45, 0.07), (tip_y - 0.18, 0.04)]
    loops = []
    for y, w in secs:
        tw = math.radians(50) * max(0.0, min(1.0, (y - 0.5) / 1.4))
        sec = []
        for u, v in L.rrect(w * k, w * k, 0.02 * k, 1):
            sec.append((u * math.cos(tw) - v * math.sin(tw), y, u * math.sin(tw) + v * math.cos(tw)))
        loops.append(sec)
    loops.append([(0, tip_y, 0)])
    L.loft(iron, loops)
    # 쥔 자리: 붉은 천을 감은 결(굵기 물결) + 비스듬히 두른 끈
    prof = []
    for i in range(13):
        y = -0.31 * k + 0.62 * k * i / 12
        prof.append((0.165 * k + (0.014 * k if i % 2 else 0), y))
    L.lathe(cloth, prof, 14)
    L.tube(cloth, L.helix(-0.28 * k, 0.28 * k, 0.172 * k, 2.5, 14), 0.02 * k, 5)
    if ribbon:
        # 머리에 묶여 손잡이를 따라 늘어진 붉은 끈(끝이 제비꼬리)
        rb = L.smooth_outline([(0.02, -0.4), (0.12, -0.36), (0.1, 0.05), (0.16, 0.42), (0.1, 0.5), (0.06, 0.38), (0.0, 0.52), (-0.03, 0.4), (-0.02, 0.0), (-0.05, -0.36)], 2)
        L.plate(cloth, rb, (0.05, 0.05), lambda u, v, kk: 0.024, (1.0, 0.5), "ZY", 0.2)
    return p


def pilgrim():
    return [nail("Main", 1.0, 2.87, True), nail("Off", 0.935, 2.57, False)]


# ── 월 메이슨: 석공 망치 + 정 ─────────────────────────


def mason():
    h = Piece("MasonHammer", "Main")
    wood, leather, metal, dark = h.g("Wood", WOOD), h.g("Leather", LEATHER), h.g("Head", rgb(120, 118, 112), 30), h.g("Dark", STEEL_DK, 30)
    ell = lambda a, b: [(a * math.cos(L.TAU * i / 12), b * math.sin(L.TAU * i / 12)) for i in range(12)]
    L.loft(wood, [L.section_y(y, ell(a, b)) for y, a, b in ((-0.42, 0.12, 0.14), (-0.3, 0.105, 0.125), (0.5, 0.098, 0.118), (1.4, 0.09, 0.11), (2.4, 0.09, 0.11))])
    L.lathe(wood, [(0, -0.52), (0.09, -0.515), (0.15, -0.47), (0.15, -0.42), (0.12, -0.38), (0, -0.37)], 12)
    prof = [(0.13 + (0.012 if i % 2 else 0), -0.34 + 0.69 * i / 10) for i in range(11)]
    L.lathe(leather, prof, 14)
    L.loft(dark, [L.section_y(1.77, L.rrect(0.15, 0.15, 0.03, 1)), L.section_y(1.95, L.rrect(0.15, 0.15, 0.03, 1))])

    def sxy(z, w, hh, r):
        return [(x, 2.2 + y, z) for x, y in L.rrect(w, hh, r, 1)]

    # 머리 몸(가운데) → 쐐기 날(+Z)
    L.loft(metal, [sxy(-0.64, 0.28, 0.28, 0.04), sxy(-0.3, 0.27, 0.27, 0.05), sxy(0.3, 0.27, 0.27, 0.05), sxy(0.6, 0.27, 0.25, 0.04)])
    L.loft(dark, [sxy(0.6, 0.27, 0.25, 0.04), sxy(0.88, 0.28, 0.13, 0.03), sxy(1.1, 0.29, 0.02, 0.006)])
    # 네모 타격면(-Z): 버섯처럼 살짝 퍼진 면
    L.loft(dark, [sxy(-0.62, 0.28, 0.28, 0.04), sxy(-0.72, 0.33, 0.33, 0.05), sxy(-0.8, 0.33, 0.33, 0.07), sxy(-0.82, 0.3, 0.3, 0.06)])

    c = Piece("MasonHammer", "Off")
    steel, cdark, cleather = c.g("Steel", STEEL, 30), c.g("Dark", STEEL_DK, 30), c.g("Leather", LEATHER)
    L.loft(steel, [L.section_y(-0.7, L.rrect(0.085, 0.085, 0.03, 1)), L.section_y(0.58, L.rrect(0.085, 0.085, 0.03, 1))])
    L.loft(steel, [L.section_y(-0.7, L.rrect(0.085, 0.085, 0.03, 1)), L.section_y(-0.88, L.rrect(0.1, 0.05, 0.02, 1)), L.section_y(-1.02, L.rrect(0.11, 0.008, 0.004, 1))])
    # 망치에 맞아 버섯처럼 뭉개진 머리
    L.lathe(cdark, [(0.09, 0.55), (0.1, 0.6), (0.15, 0.63), (0.155, 0.66), (0.12, 0.7), (0.0, 0.715)], 8, phase=math.pi / 8)
    L.lathe(cleather, [(0.105, -0.2), (0.115, -0.1), (0.118, 0.0), (0.115, 0.1), (0.105, 0.2)], 12)
    return [h, c]


# ── 월 브레이커: 곡괭이 쿼터스태프 ───────────────────


def pickstaff():
    p = Piece("PickStaff", "Main")
    wood, leather, rope = p.g("Wood", WOOD_DK, 50), p.g("Leather", LEATHER), p.g("Rope", rgb(150, 132, 96))
    iron, steel, crystal = p.g("Iron", IRON, 30), p.g("Steel", STEEL, 30), p.g("Crystal", rgb(255, 160, 90), None)
    # 깎은 지팡이(10각, 굵기가 조금씩 다름)
    prof = [(0.13, -1.2), (0.135, -0.6), (0.142, 0.4), (0.138, 1.4), (0.134, 2.4), (0.13, 3.2), (0.125, 3.95)]
    L.lathe(wood, prof, 10)
    for y0, y1 in ((-0.25, 0.35), (1.1, 1.6)):
        L.lathe(leather, [(0.16 + (0.012 if i % 2 else 0), y0 + (y1 - y0) * i / 8) for i in range(9)], 12)
        L.tube(leather, L.helix(y0 + 0.02, y1 - 0.02, 0.168, 2.2, 14), 0.016, 5)
    L.tube(rope, L.helix(3.18, 3.42, 0.155, 5, 14), 0.032, 6)
    # 랑겟(쇠띠 넷 + 못) · 소켓 · 위아래 고리
    for x, z, sx, sz in ((0.135, 0, 0.022, 0.1), (-0.135, 0, 0.022, 0.1), (0, 0.135, 0.1, 0.022), (0, -0.135, 0.1, 0.022)):
        L.bbox(iron, (x, 3.56, z), (sx, 0.82, sz), 0.006)
        for yy in (3.3, 3.75):
            L.ball(iron, (x * 1.14, yy, z * 1.14), 0.024, 8, 5)
    L.loft(iron, [L.section_y(3.72, L.rrect(0.23, 0.23, 0.05, 1)), L.section_y(4.28, L.rrect(0.21, 0.21, 0.05, 1))])
    L.ring(iron, (0, 3.74, 0), 0.24, 0.03, (0, 1, 0), 8, 6)
    # 곡괭이 날(-Z, 끝이 살짝 아래로) — 쇠 몸 + 강철 끝
    sq = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    L.tube(iron, [(0, 4.06, -0.18), (0, 4.08, -0.7), (0, 4.02, -1.25), (0, 3.9, -1.8)], [0.15, 0.135, 0.115, 0.09], 4, section=sq)
    L.tube(steel, [(0, 3.9, -1.8), (0, 3.84, -2.05), (0, 3.76, -2.32)], [0.09, 0.055, 0.0], 4, section=sq)
    # 뒤 망치(+Z): 8각 몸 + 강철 면
    L.loft(iron, [[(x, 4.02 + y, 0.2) for x, y in L.rrect(0.17, 0.17, 0.05, 1)], [(x, 4.02 + y, 0.86) for x, y in L.rrect(0.17, 0.17, 0.05, 1)]])
    L.loft(steel, [[(x, 4.02 + y, 0.86) for x, y in L.rrect(0.21, 0.21, 0.04, 1)], [(x, 4.02 + y, 1.0) for x, y in L.rrect(0.2, 0.2, 0.05, 1)]])
    # 꼭대기 수정(6각 기둥, 양끝 뾰족)
    L.lathe(crystal, [(0, 4.24), (0.13, 4.38), (0.13, 4.62), (0, 4.84)], 6)
    # 물미 · 끝 가시
    L.lathe(iron, [(0.16, -1.42), (0.165, -1.3), (0.15, -1.16), (0.135, -1.12)], 10)
    L.lathe(iron, [(0.13, -1.42), (0.0, -1.76)], 4, phase=math.pi / 4)
    return [p]


# ── 연금술사: 둥근 플라스크 + 원통 약병 ────────────────


def flasks():
    f = Piece("Flask", "Main")
    glass, liquid = f.g("Glass", rgb(200, 236, 230), 70, 0.5), f.g("Liquid", rgb(120, 230, 110), None)
    twine, cork = f.g("Twine", rgb(176, 146, 96)), f.g("Cork", rgb(150, 110, 70))
    L.lathe(glass, [(0, -0.07), (0.16, -0.05), (0.3, 0.03), (0.42, 0.17), (0.48, 0.38), (0.46, 0.57), (0.38, 0.72), (0.25, 0.83),
                    (0.16, 0.91), (0.152, 1.0), (0.152, 1.22), (0.19, 1.27), (0.195, 1.32), (0.16, 1.34), (0.135, 1.34)], 28)
    L.lathe(liquid, [(0, -0.01), (0.15, 0.0), (0.28, 0.07), (0.38, 0.19), (0.425, 0.36), (0.415, 0.52), (0, 0.52)], 24)
    L.ring(twine, (0, 0.925, 0), 0.165, 0.018, (0, 1, 0), 18, 5)
    L.ring(twine, (0, 0.975, 0), 0.163, 0.018, (0, 1, 0), 18, 5)
    L.tube(twine, [(0.165, 0.95, 0.0), (0.23, 0.88, 0.03), (0.25, 0.76, 0.05), (0.2, 0.72, 0.04), (0.17, 0.8, 0.0)], 0.016, 5)
    L.lathe(cork, [(0, 1.23), (0.122, 1.23), (0.134, 1.34), (0.158, 1.48), (0.15, 1.535), (0, 1.545)], 14)

    o = Piece("Flask", "Off")
    g2, l2 = o.g("Glass", rgb(200, 236, 230), 70, 0.5), o.g("Liquid", rgb(255, 120, 60), None)
    c2, seal = o.g("Cork", rgb(150, 110, 70)), o.g("Seal", rgb(150, 30, 30), 60)
    L.lathe(g2, [(0, -0.12), (0.2, -0.12), (0.252, -0.085), (0.262, 0.0), (0.262, 0.62), (0.24, 0.7), (0.16, 0.775), (0.122, 0.82),
                 (0.122, 0.94), (0.15, 0.97), (0.145, 1.0), (0.11, 1.0)], 24)
    L.lathe(l2, [(0, -0.08), (0.21, -0.08), (0.218, 0.0), (0.218, 0.42), (0, 0.42)], 20)
    L.lathe(c2, [(0, 0.9), (0.1, 0.9), (0.11, 1.06), (0.118, 1.13), (0, 1.14)], 12)
    # 봉랍: 마개를 덮고 목으로 흘러내린 방울
    L.lathe(seal, [(0, 1.19), (0.09, 1.18), (0.135, 1.14), (0.145, 1.08), (0.14, 1.02), (0.128, 0.98), (0.0, 0.98)], 16)
    for a, ln in ((0.3, 0.12), (2.1, 0.08), (3.9, 0.15), (5.2, 0.06)):
        x, z = 0.135 * math.cos(a), 0.135 * math.sin(a)
        L.tube(seal, [(x, 1.0, z), (x * 0.96, 1.0 - ln * 0.6, z * 0.96), (x * 0.94, 1.0 - ln, z * 0.94)], [0.028, 0.024, 0.0], 6)
    return [f, o]


# ── 광전사: 데인 액스 ─────────────────────────────


def greataxe():
    p = Piece("Greataxe", "Main")
    wood, leather = p.g("Wood", WOOD_DK, 50), p.g("Leather", LEATHER)
    steel, dark = p.g("Steel", STEEL, 25), p.g("Dark", STEEL_DK, 30)
    edge, rune = p.g("Edge", rgb(226, 230, 236), 25), p.g("Rune", rgb(255, 50, 40), None)
    ell = lambda a, b: [(a * math.cos(L.TAU * i / 12), b * math.sin(L.TAU * i / 12)) for i in range(12)]
    L.loft(wood, [L.section_y(y, ell(a, b)) for y, a, b in ((-1.2, 0.12, 0.13), (0.0, 0.13, 0.14), (2.0, 0.125, 0.135), (3.9, 0.115, 0.125))])
    for y0, y1 in ((-0.6, 0.2), (1.45, 1.95)):
        L.lathe(leather, [(0.158 + (0.012 if i % 2 else 0), y0 + (y1 - y0) * i / 10) for i in range(11)], 12)
        L.tube(leather, L.helix(y0 + 0.02, y1 - 0.02, 0.166, 2.6, 14), 0.016, 5)
    L.lathe(dark, [(0, -1.25), (0.1, -1.24), (0.17, -1.18), (0.17, -1.02), (0.14, -0.98)], 8, phase=math.pi / 8)
    for s in (1, -1):
        L.bbox(dark, (s * 0.138, 2.95, 0), (0.026, 0.7, 0.12), 0.006)
        for yy in (2.72, 3.0, 3.24):
            L.ball(dark, (s * 0.155, yy, 0), 0.022, 8, 5)
    # 자루 구멍(눈) — 앞(날 쪽)으로 길쭉 · 뒤 망치 · 꼭대기 쐐기
    L.loft(dark, [L.section_y(3.1, L.rrect(0.16, 0.2, 0.08, 2), 0, -0.02), L.section_y(3.3, L.rrect(0.175, 0.22, 0.08, 2), 0, -0.02),
                  L.section_y(3.6, L.rrect(0.175, 0.22, 0.08, 2), 0, -0.02), L.section_y(3.8, L.rrect(0.16, 0.2, 0.08, 2), 0, -0.02)])
    L.bbox(dark, (0, 3.45, 0.32), (0.28, 0.42, 0.26), 0.04)
    L.lathe(dark, [(0.15, 3.82), (0.1, 3.95), (0, 4.02)], 4, phase=math.pi / 4)
    # 날 몸: 얇고 넓은 초승달 — 위 뿔 4.5, 아래로 긴 턱 2.12, 날 끝은 -1.38 까지 볼록. 두께는 눈 쪽 0.1 → 날 0.03
    # 위 날등은 거의 곧게(살짝 오름) · 아래는 자루 가까이서 가파르게 떨어졌다가 바깥으로 휘어 나가는 긴 턱(데인 액스)
    out = [(-0.2, 3.74), (-0.6, 3.84), (-1.0, 4.0), (-1.2, 4.16), (-1.3, 4.32), (-1.345, 4.18), (-1.375, 3.95),
           (-1.39, 3.6), (-1.385, 3.25), (-1.37, 2.9), (-1.345, 2.55), (-1.31, 2.22), (-1.26, 1.96), (-1.14, 1.97),
           (-0.94, 2.05), (-0.68, 2.2), (-0.46, 2.42), (-0.31, 2.68), (-0.23, 2.94), (-0.2, 3.18)]
    ol = L.smooth_outline(out, 3)
    thick = lambda u, v, k: 0.03 + 0.07 * max(0.0, min(1.0, (u + 1.3) / 1.1))
    L.plate(steel, ol, (-0.8, 3.42), thick, (1.0, 0.82, 0.6, 0.36, 0.14), "ZY")
    # 날끝 띠(밝은 강철)
    arc = [q for q in out if q[0] <= -1.24]
    arc = L.smooth_outline(arc, 3, closed=False)
    band = arc + [(u + 0.11, v) for u, v in reversed(arc)]
    L.plate(edge, band, (-1.27, 3.3), lambda u, v, k: 0.038, (1.0,), "ZY")
    # 핏빛 룬(ᛉ) — 양면에 도드라지게
    for s in (1, -1):
        x = s * 0.036
        L.tube(rune, [(x, 3.24, -0.8), (x, 3.66, -0.8)], 0.02, 6)
        L.tube(rune, [(x, 3.44, -0.8), (x, 3.6, -0.66)], 0.02, 6)
        L.tube(rune, [(x, 3.44, -0.8), (x, 3.6, -0.94)], 0.02, 6)
    return [p]


BUILDERS = {
    "Rapier": rapier, "Violin": violin, "Greatsword": greatsword, "Orbs": orbs, "PilgrimNails": pilgrim,
    "MasonHammer": mason, "PickStaff": pickstaff, "Flask": flasks, "Greataxe": greataxe,
}


# ── 렌더(확인용) ─────────────────────────────────


def render_weapon(wid, objs, out_dir):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_cavity, sh.cavity_type = True, "BOTH"
    sh.show_shadows = True
    scene.render.film_transparent = False
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    world = bpy.data.worlds.new("W") if not scene.world else scene.world
    scene.world = world
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.16, 0.18)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.hide_render = ob not in objs
    # Off 조각(바이올린·정·왼손 못·약병)은 Main 옆으로 비켜 찍는다(무기 Z = 블렌더 y)
    mains = [ob for ob in objs if "_Main_" in ob.name]
    offs = [ob for ob in objs if "_Off_" in ob.name]
    if mains and offs:
        hi_m = max((ob.matrix_world @ Vector(c)).y for ob in mains for c in ob.bound_box)
        lo_o = min((ob.matrix_world @ Vector(c)).y for ob in offs for c in ob.bound_box)
        for ob in offs:
            ob.location.y += hi_m - lo_o + 0.5
        bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for ob in objs for c in ob.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mid, size = (lo + hi) / 2, (hi - lo).length
    cam = bpy.data.objects.get("Cam") or bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.08
    paths = []
    # 옆(무기 +X 쪽에서 — 블렌더 -x) · 3/4(날 쪽 앞에서 비스듬히)
    for tag, d in (("side", Vector((-1, 0.0, 0.12))), ("q34", Vector((-0.8, -0.75, 0.35)))):
        d.normalize()
        cam.location = mid + d * size * 2
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out_dir, "%s_%s.png" % (wid, tag))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    for ob in offs:
        ob.location.y = 0.0
    bpy.context.view_layer.update()
    return paths


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ids = ONLY or list(BUILDERS)
    out_dir = os.path.join(HERE, "render")
    os.makedirs(out_dir, exist_ok=True)
    all_objs = []
    report = []
    by_weapon = {}
    for wid in ids:
        objs = []
        for piece in BUILDERS[wid]():
            for ob in piece.finish():
                tris = L.tri_count(ob)
                assert tris <= 20000, "%s 삼각형 %d" % (ob.name, tris)
                report.append("  %-28s %6d tri" % (ob.name, tris))
                objs.append(ob)
        by_weapon[wid] = objs
        all_objs += objs
    mk = L.Group("WeaponsOrigin_Marker", (1, 0, 1), None)
    L.bbox(mk, (0, 0, 0), (1, 1, 1))
    marker = mk.finish()
    print("=== weapons ===")
    print("\n".join(report))
    if not NORENDER:
        for wid, objs in by_weapon.items():
            marker.hide_render = True
            render_weapon(wid, objs, out_dir)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in all_objs + [marker]:
        ob.hide_render = False
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    # 일부만 지으면 따로 저장한다(스튜디오에서 그 무기만 갈아 끼우기 — WeaponMeshes.luau 는 든 묶음만 바꾼다)
    fbx = os.path.join(HERE, "Weapons.fbx" if not ONLY else "Weapons_%s.fbx" % "_".join(ONLY))
    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
        object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
        bake_space_transform=False,
    )
    print("objects %d  FBX: %s" % (len(all_objs) + 1, fbx))


main()
