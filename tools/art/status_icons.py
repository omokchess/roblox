# -*- coding: utf-8 -*-
"""
상태이상 아이콘 1차본 (2026-11-06).

  돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" tools/art/status_icons.py [Id ...]
  결과:   art/status/<Id>.png (256x256 투명), art/status/_sheet.png (비교판)

색과 종류(Buff/Debuff...)는 src/shared/Keywords.luau 에서 읽는다 — 키워드 색을 바꾸면 다시 돌리면 된다.
틀: 이로운 것=동그라미, 해로운 것=육각형, 그 밖(태세·중립·자원)=둥근 네모. 안에 상징 하나를 크게.
"""
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from artlib import Canvas, INK, WHITE, dark, hexrgb, light, mix, over, write_png, fill_rect  # noqa: E402

OUT = os.path.join(ROOT, "art", "status")
U = Canvas.U
GLYPH_SCALE = 0.86


# ───────────────────────── 키워드 읽기 ─────────────────────────
def load_keywords():
    text = open(os.path.join(ROOT, "src", "shared", "Keywords.luau"), encoding="utf-8").read()
    res = {}
    for block in text.split("\n\t{\n")[1:]:
        i = re.search(r'Id = "(\w+)"', block)
        k = re.search(r'Kind = "(\w+)"', block)
        c = re.search(r'Color = "(#[0-9a-fA-F]{6})"', block)
        n = re.search(r'Name = "([^"]+)"', block)
        if i and k and c:
            res[i.group(1)] = (n.group(1) if n else i.group(1), k.group(1), c.group(1))
    return res


# 아이콘을 만들 상태들(그리는 순서 = 비교판 순서). 수치 보정(가하는 피해량 등)과 자원(음표·병…)은 2차.
ORDER = [
    # 지속 피해·해로운 것
    "Bleed", "Poison", "Burn", "Oil", "Tetanus", "Shock", "Spasm", "Groggy",
    "Melt", "Brand", "Overheal", "Zeal", "Gravity", "Depolar", "Bind",
    # 이로운 것·태세·중립
    "Shield", "Wall", "Field", "Brillante", "Concentration", "AttackStance", "DefenseStance", "Taunt", "Fusion",
    # 칼리스토·별
    "Star", "StarSeven", "Seongwi", "Mutbyeol", "Gochal", "Symberasma", "BladeScar",
    "UrsaMinor", "StarDubhe", "StarAlkaid", "StarMizar", "StarBlink", "StarGuard",
]


# ───────────────────────── 틀 ─────────────────────────
def frame_shape(c, kind):
    if kind == "Buff":
        return c.circle(0, 0, 0.95)
    if kind == "Debuff":
        return c.ngon(0, 0, 0.99, 6, rot=-90, round_=0.07)
    return c.box(0, 0, 0.88, 0.88, 0.3)  # Status / Neutral / Resource


def draw_frame(c, kind, col):
    f = frame_shape(c, kind)
    c.paint(f, INK, 0.95)  # 바깥 윤곽
    # 테두리 띠(상태색, 위가 밝다)
    c.paint(f + 0.03, np.stack([light(col, 0.5), col, dark(col, 0.35)])[[0, 2]])
    inner = f + 0.115
    c.paint(inner, INK, 1.0)
    plate = f + 0.13
    base = mix(INK, col, 0.16)
    c.paint(plate, np.stack([mix(base, WHITE, 0.07), dark(base, 0.35)]))
    # 안쪽 빛
    c.glow(0, 0.05, 0.85, mix(col, WHITE, 0.1), 0.28)
    c.mask_to(f + 0.03)
    return f


# ───────────────────────── 모양 모음 ─────────────────────────
def drop_pts(cx, cy, s):
    base = [(0, -0.68), (0.14, -0.38), (0.34, -0.05), (0.40, 0.2), (0.30, 0.46), (0, 0.6),
            (-0.30, 0.46), (-0.40, 0.2), (-0.34, -0.05), (-0.14, -0.38)]
    return [(cx + x * s, cy + y * s) for x, y in base]


def flame_pts(cx, cy, s):
    base = [(0.05, -0.74), (0.2, -0.45), (0.38, -0.15), (0.44, 0.18), (0.32, 0.48), (0.0, 0.62),
            (-0.32, 0.48), (-0.44, 0.18), (-0.36, -0.08), (-0.2, -0.22), (-0.16, -0.45)]
    return [(cx + x * s, cy + y * s) for x, y in base]


def shield_pts(s=1.0, cy=0.0):
    base = [(-0.5, -0.55), (0.5, -0.55), (0.5, 0.05), (0.34, 0.4), (0, 0.68), (-0.34, 0.4), (-0.5, 0.05)]
    return [(x * s, y * s + cy) for x, y in base]


BIG_DIPPER = {  # 북두칠성 (오른쪽이 국자 통)
    "Alkaid": (-0.68, -0.22), "Mizar": (-0.42, -0.03), "Alioth": (-0.16, 0.04), "Megrez": (0.08, -0.08),
    "Phecda": (0.14, 0.3), "Merak": (0.6, 0.34), "Dubhe": (0.64, -0.12),
}
BIG_LINKS = [("Alkaid", "Mizar"), ("Mizar", "Alioth"), ("Alioth", "Megrez"), ("Megrez", "Phecda"),
             ("Phecda", "Merak"), ("Merak", "Dubhe"), ("Dubhe", "Megrez")]
LITTLE_DIPPER = {  # 작은곰자리
    "Polaris": (-0.66, 0.42), "b": (-0.44, 0.2), "c": (-0.2, 0.06), "d": (0.04, -0.06),
    "e": (0.2, -0.34), "f": (0.56, -0.26), "g": (0.46, 0.14),
}
LITTLE_LINKS = [("Polaris", "b"), ("b", "c"), ("c", "d"), ("d", "e"), ("e", "f"), ("f", "g"), ("g", "d")]


def star_pts(cx, cy, R, r, n, rot=-90):
    return [(cx + (R if i % 2 == 0 else r) * np.cos(np.radians(rot + i * 180 / n)),
             cy + (R if i % 2 == 0 else r) * np.sin(np.radians(rot + i * 180 / n))) for i in range(n * 2)]


# ───────────────────────── 상징들 ─────────────────────────
# 각 함수: (c, M) — c=캔버스, M=상태색. 상징은 중심 ±0.62 안에.
def g_bleed(c, M):
    c.solid(c.blob(drop_pts(0, 0.02, 1.0)), M)
    c.paint(c.seg(-0.2, 0.18, -0.2, 0.36, 0.055), light(M, 0.75), 0.9)
    c.paint(c.circle(-0.2, 0.08, 0.05), light(M, 0.75), 0.9)


def g_poison(c, M):
    bone = mix(M, WHITE, 0.55)
    for sgn in (1, -1):
        with c.at(sgn * 38, 0, 0.0):
            c.solid(U(c.seg(0, -0.64, 0, 0.64, 0.075), c.circle(-0.1, -0.66, 0.1), c.circle(0.1, -0.66, 0.1),
                      c.circle(-0.1, 0.66, 0.1), c.circle(0.1, 0.66, 0.1)), dark(bone, 0.25), ow=0.03)
    skull = U(c.circle(0, -0.1, 0.42), c.box(0, 0.3, 0.25, 0.2, 0.09))
    c.solid(skull, M)
    eye = U(c.ellipse(-0.17, -0.06, 0.13, 0.15), c.ellipse(0.17, -0.06, 0.13, 0.15))
    c.paint(eye, INK)
    c.paint(c.poly([(0, 0.08), (-0.06, 0.2), (0.06, 0.2)]), INK)
    for x in (-0.1, 0.0, 0.1):
        c.paint(c.box(x, 0.4, 0.014, 0.08), INK)


def g_burn(c, M):
    c.glow(0, 0.1, 0.75, M, 0.35)
    c.solid(c.blob(flame_pts(0, 0.02, 1.0)), M)
    c.paint(c.blob(flame_pts(0.02, 0.3, 0.52)), mix(hexrgb("#ffe27a"), WHITE, 0.2))


def g_oil(c, M):
    c.solid(c.ellipse(0, 0.56, 0.6, 0.11), dark(M, 0.3))
    c.paint(c.ellipse(-0.1, 0.55, 0.3, 0.04), light(M, 0.4), 0.7)
    c.solid(c.blob(drop_pts(0, -0.1, 0.9)), M)
    c.paint(c.blob(drop_pts(0.03, 0.02, 0.5)), dark(M, 0.5), 0.55)
    c.paint(c.seg(-0.22, -0.02, -0.22, 0.16, 0.05), light(M, 0.8), 0.9)


def g_tetanus(c, M):
    rust = hexrgb("#d2692f")
    steel = mix(M, WHITE, 0.45)
    with c.at(38, 0, 0):
        c.solid(c.poly([(-0.07, -0.42), (0.07, -0.42), (0.065, 0.5), (0, 0.84), (-0.065, 0.5)]), steel)
        c.solid(c.ellipse(0, -0.5, 0.27, 0.095), light(steel, 0.1))
        for (x, y, r) in ((0.0, -0.5, 0.07), (0.1, -0.52, 0.045), (0.02, -0.15, 0.06), (-0.02, 0.14, 0.05), (0.01, 0.4, 0.04)):
            c.paint(c.circle(x, y, r), rust, 0.95)
        c.paint(c.box(0, -0.42, 0.075, 0.03), rust, 0.9)


def g_shock(c, M):
    c.glow(0, 0, 0.8, M, 0.3)
    c.solid(c.poly([(0.24, -0.74), (-0.36, 0.1), (-0.04, 0.1), (-0.22, 0.74), (0.4, -0.16), (0.07, -0.16)]), M, ow=0.04)


def g_spasm(c, M):
    c.solid(c.circle(0, 0, 0.17), M)
    for sgn in (-1, 1):
        for k, x in enumerate((0.36, 0.58)):
            L = 0.46 - k * 0.14
            pts = [(sgn * x + sgn * (0.06 if i % 2 else -0.06), -L + i * L / 2.5) for i in range(6)]
            c.solid(c.line(pts, 0.045), light(M, 0.1) if k == 0 else M, ow=0.025)


def g_groggy(c, M):
    pts = []
    for i in range(70):
        t = i / 69
        a = t * 2.4 * 2 * np.pi
        r = 0.04 + 0.4 * t
        pts.append((r * np.cos(a), 0.22 + r * np.sin(a) * 0.9))
    c.solid(c.line(pts, 0.06), M)
    for (x, y, s) in ((-0.38, -0.46, 0.17), (0.0, -0.58, 0.2), (0.4, -0.44, 0.16)):
        c.solid(c.poly(star_pts(x, y, s, s * 0.45, 5)), light(M, 0.5), ow=0.025)


def g_melt(c, M):
    hot = hexrgb("#ffb347")
    drips = U(c.seg(-0.32, -0.02, -0.32, 0.4, 0.1), c.circle(-0.32, 0.42, 0.12),
              c.seg(-0.02, -0.02, -0.02, 0.6, 0.1), c.circle(-0.02, 0.6, 0.13),
              c.seg(0.3, -0.02, 0.3, 0.3, 0.1), c.circle(0.3, 0.31, 0.11))
    c.solid(c.blob(flame_pts(0, -0.58, 0.34)), hot)
    c.solid(U(drips, c.box(0, -0.2, 0.5, 0.2, 0.1)), M)
    c.paint(c.box(0, -0.28, 0.38, 0.05, 0.05), light(hot, 0.2), 0.9)
    c.paint(c.circle(-0.02, 0.62, 0.05), light(M, 0.7), 0.8)


def g_brand(c, M):
    c.solid(c.seg(0.64, -0.64, 0.14, -0.14, 0.08), dark(M, 0.3))
    c.solid(c.box(-0.12, 0.2, 0.42, 0.42, 0.1), M)
    c.paint(c.box(-0.12, 0.2, 0.32, 0.32, 0.06), dark(M, 0.6))
    rune = U(c.seg(-0.12, -0.02, -0.12, 0.42, 0.045), c.seg(-0.12, 0.2, -0.3, 0.0, 0.045), c.seg(-0.12, 0.2, 0.06, 0.0, 0.045))
    c.paint(rune, light(M, 0.8))
    c.paint(c.circle(0.52, 0.5, 0.035), hexrgb("#ffd36a"))
    c.paint(c.circle(0.4, 0.62, 0.025), hexrgb("#ffd36a"))


def g_overheal(c, M):
    plus = U(c.box(0, 0, 0.5, 0.17, 0.05), c.box(0, 0, 0.17, 0.5, 0.05))
    c.solid(plus, M)
    crack = [(0.42, -0.5), (0.12, -0.18), (0.22, -0.02), (-0.08, 0.2), (0.0, 0.3), (-0.42, 0.6)]
    c.paint(c.line(crack, 0.075), INK)


def g_zeal(c, M):
    for a in (-62, -31, 0, 31, 62):
        t = np.radians(a)
        c.solid(c.seg(0.5 * np.sin(t), -0.5 * np.cos(t) * 1.0 - 0.06, 0.78 * np.sin(t), -0.78 * np.cos(t) - 0.06, 0.05), light(M, 0.3), ow=0.025)
    lens = c.inter(c.circle(0, 0.62, 0.95), c.circle(0, -0.62, 0.95))
    c.solid(lens, mix(M, WHITE, 0.55))
    c.paint(c.circle(0, 0, 0.27), M)
    c.paint(c.circle(0, 0, 0.14), INK)
    c.paint(c.circle(-0.06, -0.06, 0.04), WHITE)


def g_gravity(c, M):
    for x in (-0.34, 0, 0.34):
        c.solid(c.arrow_down(x, -0.7, -0.14, 0.09, 0.14), light(M, 0.25), ow=0.025)
    c.solid(c.circle(0, 0.3, 0.3), M)
    c.paint(c.circle(-0.1, 0.2, 0.08), light(M, 0.7), 0.8)


def g_depolar(c, M):
    plus = U(c.box(-0.2, -0.2, 0.3, 0.1, 0.03), c.box(-0.2, -0.2, 0.1, 0.3, 0.03))
    minus = c.box(0.22, 0.34, 0.3, 0.1, 0.03)
    c.solid(plus, M)
    c.solid(minus, M)
    crack = [(0.5, -0.55), (0.12, -0.12), (0.22, 0.0), (-0.2, 0.35), (-0.1, 0.42), (-0.52, 0.62)]
    c.paint(c.line(crack, 0.06), INK)
    c.paint(c.line(crack, 0.022), light(M, 0.8))


def link_ring(c, cx, cy, rot, t=0.1):
    with c.at(rot, cx, cy):
        return c.stadium(0, 0, 0.14, 0.22)


def g_bind(c, M):
    def chain(cx, cy):
        with c.at(45, cx, cy):
            return c.stadium(0, 0, 0.2, 0.23)
    a = chain(-0.2, -0.2)
    b = chain(0.2, 0.2)
    ra = np.abs(a + 0.07) - 0.07
    rb = np.abs(b + 0.07) - 0.07
    c.solid(ra, M)
    c.solid(rb, light(M, 0.15))
    # 얽힘: a 의 한쪽을 b 위로 다시 그린다
    with c.at(45, 0, 0):
        pass
    over_region = c.circle(0.02, 0.02, 0.2)
    c.paint(c.inter(ra, over_region + 0.0), np.stack([light(M, 0.28), dark(M, 0.18)]))


def g_shield(c, M):
    glass = mix(M, WHITE, 0.25)
    c.solid(c.circle(0, 0, 0.58), M, alpha=0.9)
    c.paint(c.ring(0, 0, 0.5, 0.06), light(glass, 0.5))
    c.paint(c.arc(0, 0, 0.36, 200, 275, 0.07), WHITE)
    c.paint(c.circle(-0.33, -0.33, 0.045), WHITE)
    c.paint(c.poly([(0, -0.12), (0.12, 0), (0, 0.12), (-0.12, 0)]), light(M, 0.8), 0.9)


def g_wall(c, M):
    rows = [(-0.4, [(-0.4, 0.34), (0.1, 0.34)], 0), (-0.1, [(-0.65, 0.1), (-0.15, 0.4), (0.4, 0.2)], 0),
            (0.2, [(-0.4, 0.34), (0.1, 0.34)], 0), (0.5, [(-0.65, 0.1), (-0.15, 0.4), (0.4, 0.2)], 0)]
    ys = [-0.42, -0.14, 0.14, 0.42]
    xs_even = [-0.37, 0.19, ]
    k = 0
    for ri, y in enumerate(ys):
        if ri % 2 == 0:
            cells = [(-0.36, 0.26), (0.2, 0.26)]
        else:
            cells = [(-0.6, 0.05), (-0.1, 0.4 - 0.0), (0.46, 0.0)]
        if ri % 2 == 0:
            cells = [(-0.33, 0.29), (0.25, 0.29)]
        else:
            cells = [(-0.62, 0.1), (-0.04, 0.29), (0.54, 0.1)]
        for (cx, hw) in cells:
            col = light(M, 0.18) if (k % 2) else M
            c.solid(c.box(cx, y, hw - 0.012, 0.125, 0.03), col, ow=0.025)
            k += 1


def g_field(c, M):
    c.glow(0, -0.3, 0.7, M, 0.25)
    for r in (0.42, 0.58):
        c.paint(c.arc(0, -0.5, r, 205, 335, 0.045), light(M, 0.4), 0.9)
    u = U(c.arc(0, 0.0, 0.3, 0, 180, 0.22), c.box(-0.3, -0.25, 0.11, 0.25), c.box(0.3, -0.25, 0.11, 0.25))
    c.solid(u, M)
    c.solid(c.box(-0.3, -0.5, 0.11, 0.085), mix(M, WHITE, 0.8), ow=0.03)
    c.solid(c.box(0.3, -0.5, 0.11, 0.085), mix(M, WHITE, 0.8), ow=0.03)


def sparkle(c, cx, cy, R, r=None):
    r = r or R * 0.22
    return c.poly(star_pts(cx, cy, R, r, 4))


def g_brillante(c, M):
    c.glow(0, 0, 0.8, M, 0.3)
    c.solid(sparkle(c, -0.04, 0.02, 0.7), M)
    c.solid(sparkle(c, 0.42, -0.42, 0.28), light(M, 0.45), ow=0.025)
    c.solid(sparkle(c, -0.46, 0.46, 0.22), light(M, 0.45), ow=0.025)


def g_concentration(c, M):
    c.solid(c.ring(0, 0, 0.4, 0.12), M)
    for a in (0, 90, 180, 270):
        t = np.radians(a)
        c.solid(c.seg(0.2 * np.cos(t), 0.2 * np.sin(t), 0.68 * np.cos(t), 0.68 * np.sin(t), 0.05), light(M, 0.25), ow=0.025)
    c.solid(c.circle(0, 0, 0.1), light(M, 0.55), ow=0.025)


def sword(c, M, rot, dx=0, dy=0):
    with c.at(rot, dx, dy):
        blade = c.poly([(0, -0.8), (0.1, -0.62), (0.1, 0.1), (-0.1, 0.1), (-0.1, -0.62)])
        c.solid(blade, mix(M, WHITE, 0.45))
        c.paint(c.box(0, -0.3, 0.018, 0.36), dark(M, 0.4), 0.7)
        c.solid(c.box(0, 0.16, 0.3, 0.06, 0.03), M)
        c.solid(c.box(0, 0.34, 0.05, 0.13, 0.02), dark(M, 0.35))
        c.solid(c.circle(0, 0.5, 0.075), M, ow=0.025)


def g_attack(c, M):
    sword(c, M, 32, 0.14, 0.0)
    sword(c, M, -32, -0.14, 0.0)


def g_defense(c, M):
    c.solid(c.poly(shield_pts(1.0, 0.0)), M)
    c.paint(c.poly(shield_pts(0.72, 0.02)), dark(M, 0.5))
    c.paint(U(c.box(0, -0.05, 0.07, 0.4), c.box(0, -0.12, 0.3, 0.07)), light(M, 0.5))


def g_taunt(c, M):
    bubble = U(c.box(0, -0.08, 0.6, 0.42, 0.2), c.poly([(-0.34, 0.2), (-0.44, 0.7), (0.0, 0.3)]))
    c.solid(bubble, M)
    c.paint(c.box(0, -0.16, 0.08, 0.22, 0.07), INK)
    c.paint(c.circle(0, 0.2, 0.09), INK)


def g_fusion(c, M):
    c.glow(0, 0, 0.9, M, 0.4)
    for rot in (30, -30, 90):
        with c.at(rot, 0, 0):
            c.paint(c.ellipse(0, 0, 0.7, 0.24) + 0.0 - 0.0, M, 0.0)
            ring = np.abs(c.ellipse(0, 0, 0.7, 0.26)) - 0.025
            c.solid(ring, light(M, 0.15), ow=0.02)
    c.solid(U(c.circle(-0.1, 0, 0.19), c.circle(0.1, 0, 0.19), c.circle(0, -0.1, 0.17), c.circle(0, 0.1, 0.17)), mix(M, WHITE, 0.55))


def dipper(c, M, stars, links, lit=None, dim=False, size=0.095, shift=(0, 0)):
    sx, sy = shift
    for a, b in links:
        (x1, y1), (x2, y2) = stars[a], stars[b]
        c.paint(c.seg(x1 + sx, y1 + sy, x2 + sx, y2 + sy, 0.03), INK, 0.9)
    for a, b in links:
        (x1, y1), (x2, y2) = stars[a], stars[b]
        c.paint(c.seg(x1 + sx, y1 + sy, x2 + sx, y2 + sy, 0.02), dark(M, 0.15) if dim else light(M, 0.35))
    for name, (x, y) in stars.items():
        is_lit = (lit is None) or (name == lit)
        if dim and not is_lit:
            c.solid(c.circle(x + sx, y + sy, size * 0.95), dark(M, 0.2), ow=0.025)
        elif is_lit and lit is not None:
            c.glow(x + sx, y + sy, 0.5, M, 0.6)
            c.solid(c.poly(star_pts(x + sx, y + sy, 0.26, 0.09, 5)), mix(M, WHITE, 0.45), ow=0.03)
        else:
            c.solid(c.circle(x + sx, y + sy, size), mix(M, WHITE, 0.35), ow=0.03)


def g_star(c, M):
    dipper(c, M, BIG_DIPPER, BIG_LINKS, shift=(0, 0.04))


def g_starseven(c, M):
    c.glow(0, 0, 0.85, M, 0.35)
    c.paint(c.ring(0, 0, 0.7, 0.05), light(M, 0.2), 0.8)
    c.solid(c.poly(star_pts(0, 0.02, 0.64, 0.64 * 0.47, 7)), M)
    c.paint(c.circle(0, 0.02, 0.13), mix(M, WHITE, 0.75))


def g_seongwi(c, M):
    c.glow(0, 0, 0.85, M, 0.35)
    c.paint(c.ring(0, 0, 0.72, 0.05), light(M, 0.2), 0.8)
    c.solid(c.poly(star_pts(0, 0.04, 0.58, 0.25, 5)), M)
    c.paint(c.circle(0, 0.06, 0.1), mix(M, WHITE, 0.7))


def g_mutbyeol(c, M):
    for (x, y, R) in ((-0.12, 0.08, 0.34), (0.34, -0.34, 0.24), (0.38, 0.38, 0.2), (-0.4, -0.4, 0.17), (-0.34, 0.5, 0.15)):
        c.solid(c.poly(star_pts(x, y, R, R * 0.45, 5)), M if R > 0.2 else light(M, 0.3), ow=0.028)


def g_gochal(c, M):
    c.solid(c.seg(0.2, 0.2, 0.58, 0.58, 0.095), dark(M, 0.3))
    c.solid(c.ring(-0.1, -0.1, 0.38, 0.13), M)
    c.paint(c.circle(-0.1, -0.1, 0.32), mix(M, WHITE, 0.4), 0.28)
    c.paint(c.arc(-0.1, -0.1, 0.22, 200, 260, 0.06), WHITE)


def g_symberasma(c, M):
    burst = c.poly(star_pts(0, 0.04, 0.72, 0.42, 9, rot=-80))
    c.solid(burst, M)
    c.paint(c.arrow_down(0, -0.36, 0.34, 0.15, 0.2), INK)
    c.paint(c.line([(-0.4, 0.5), (-0.2, 0.42), (-0.12, 0.52)], 0.03), INK, 0.7)


def g_bladescar(c, M):
    for dx in (-0.36, 0.0, 0.36):
        with c.at(22, dx, 0):
            cut = c.blob([(0, -0.7), (0.07, -0.3), (0.1, 0.1), (0.04, 0.45), (0, 0.72), (-0.05, 0.4), (-0.09, 0.05), (-0.06, -0.3)])
            c.solid(cut, M if dx else light(M, 0.25), ow=0.03)
    c.paint(c.circle(0.46, -0.52, 0.04), light(M, 0.7))
    c.paint(c.circle(-0.5, 0.5, 0.03), light(M, 0.7))


def g_ursaminor(c, M):
    dipper(c, M, LITTLE_DIPPER, LITTLE_LINKS, shift=(0, 0.04))


def g_dubhe(c, M):
    dipper(c, M, BIG_DIPPER, BIG_LINKS, lit="Dubhe", dim=True, shift=(0, 0.04))


def g_alkaid(c, M):
    dipper(c, M, BIG_DIPPER, BIG_LINKS, lit="Alkaid", dim=True, shift=(0, 0.04))
    c.solid(c.blob(flame_pts(0.3, 0.5, 0.3)), hexrgb("#ff8a3a"), ow=0.025)


def g_mizar(c, M):
    dipper(c, M, BIG_DIPPER, BIG_LINKS, lit="Mizar", dim=True, shift=(0, 0.04))


def g_blink(c, M):
    for i, (y, ln) in enumerate(((-0.28, 0.5), (0.0, 0.7), (0.28, 0.5))):
        c.solid(c.seg(-0.7, y, -0.7 + ln, y, 0.05), light(M, 0.2 * i), ow=0.02, alpha=0.9)
    c.glow(0.2, 0, 0.7, M, 0.4)
    c.solid(sparkle(c, 0.24, 0.0, 0.58), M)


def g_starguard(c, M):
    c.solid(c.poly(shield_pts(1.0, 0.0)), M)
    c.paint(c.poly(shield_pts(0.76, 0.02)), dark(M, 0.55))
    c.solid(c.poly(star_pts(0, 0.04, 0.3, 0.13, 5)), mix(M, WHITE, 0.6), ow=0.02)


GLYPHS = {
    "Bleed": g_bleed, "Poison": g_poison, "Burn": g_burn, "Oil": g_oil, "Tetanus": g_tetanus, "Shock": g_shock,
    "Spasm": g_spasm, "Groggy": g_groggy, "Melt": g_melt, "Brand": g_brand, "Overheal": g_overheal, "Zeal": g_zeal,
    "Gravity": g_gravity, "Depolar": g_depolar, "Bind": g_bind, "Shield": g_shield, "Wall": g_wall, "Field": g_field,
    "Brillante": g_brillante, "Concentration": g_concentration, "AttackStance": g_attack, "DefenseStance": g_defense,
    "Taunt": g_taunt, "Fusion": g_fusion, "Star": g_star, "StarSeven": g_starseven, "Seongwi": g_seongwi,
    "Mutbyeol": g_mutbyeol, "Gochal": g_gochal, "Symberasma": g_symberasma, "BladeScar": g_bladescar,
    "UrsaMinor": g_ursaminor, "StarDubhe": g_dubhe, "StarAlkaid": g_alkaid, "StarMizar": g_mizar,
    "StarBlink": g_blink, "StarGuard": g_starguard,
}


def render(status_id, kw, size=256, ss=3):
    name, kind, color = kw[status_id]
    col = hexrgb(color)
    # 어두운 색(파상풍 갈색 등)은 틀 테두리·상징이 묻히지 않게 밝기를 끌어올린다
    lum = 0.299 * col[0] + 0.587 * col[1] + 0.114 * col[2]
    if lum < 0.45:
        col = mix(col, WHITE, (0.45 - lum) * 1.1)
    c = Canvas(size, ss=ss)
    draw_frame(c, kind, col)
    c.X, c.Y = c.X0 / GLYPH_SCALE, c.Y0 / GLYPH_SCALE  # 상징을 틀 안쪽으로 줄여 넣는다
    GLYPHS[status_id](c, col)
    return c.result()


def main(only):
    kw = load_keywords()
    os.makedirs(OUT, exist_ok=True)
    ids = [i for i in ORDER if not only or i in only]
    missing = [i for i in ids if i not in kw or i not in GLYPHS]
    assert not missing, missing
    for i in ids:
        write_png(os.path.join(OUT, i + ".png"), render(i, kw))
        print("[status] ", i, kw[i][0], kw[i][1])
    if not only:
        make_sheet(kw)


def make_sheet(kw):
    """비교판: 위 = 256 크기, 아래 = 실제 표시 크기 48 / 32 (어두운 바탕·밝은 바탕)."""
    cols = 8
    big, cell_pad = 128, 12
    rows = (len(ORDER) + cols - 1) // cols
    row_h = big + 48 + 32 + cell_pad * 4
    W = cols * (big + cell_pad * 2)
    H = rows * row_h
    sheet = np.zeros((H, W, 4), np.uint8)
    sheet[...] = (22, 24, 36, 255)
    for k, i in enumerate(ORDER):
        r, cidx = divmod(k, cols)
        x0 = cidx * (big + cell_pad * 2) + cell_pad
        y0 = r * row_h + cell_pad
        icon256 = render(i, kw, 256)
        from artlib import resize
        over(sheet, resize(icon256, big, big), x0, y0)
        y1 = y0 + big + cell_pad
        # 48px, 32px — 직접 그 크기로 다시 그린다(ss 를 키워 부드럽게)
        over(sheet, render(i, kw, 48, 8), x0, y1)
        over(sheet, render(i, kw, 32, 12), x0 + 54, y1 + 8)
        # 밝은 바탕 위 32px
        fill_rect(sheet, x0 + 92, y1, 36, 48, (0.82, 0.82, 0.86))
        over(sheet, render(i, kw, 32, 12), x0 + 94, y1 + 8)
    write_png(os.path.join(OUT, "_sheet.png"), sheet)
    print("[status] 비교판", os.path.join(OUT, "_sheet.png"), sheet.shape)


if __name__ == "__main__":
    main(set(sys.argv[1:]))
