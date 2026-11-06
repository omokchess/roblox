# -*- coding: utf-8 -*-
"""
칼리스토 피니셔(케노스 아스테리스모스)용 UI 아이콘 5종 (2026-11-06).

  돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" tools/art/ui_icons.py
  결과:   art/ui/Rope.png, Chip_Blade.png, Chip_Foot.png, Chip_TwinStars.png, Chip_Rope.png (256x256 투명), art/ui/_sheet.png

양식은 status_icons.py 와 같다(틀·윤곽·그라디언트). 기믹 칩 4종은 금색 틀로 묶어 "한 세트"로 읽히게 한다.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from artlib import Canvas, INK, WHITE, dark, hexrgb, light, mix, over, resize, write_png, fill_rect  # noqa: E402
import status_icons as S  # noqa: E402

U = Canvas.U
OUT = os.path.join(ROOT, "art", "ui")
GOLD = hexrgb("#e0b84c")
ROPE = hexrgb("#bfe3ff")


def rope_line(c, y, x0=-0.66, x1=0.66, sag=0.05, r=0.062, col=ROPE):
    pts = [(x0 + (x1 - x0) * t, y + sag * np.sin(np.pi * t)) for t in np.linspace(0, 1, 14)]
    c.solid(c.line(pts, r), col, ow=0.03)
    # 꼬임 무늬
    for t in np.linspace(0.08, 0.92, 9):
        x = x0 + (x1 - x0) * t
        yy = y + sag * np.sin(np.pi * t)
        c.paint(c.seg(x - 0.025, yy + 0.05, x + 0.025, yy - 0.05, 0.012), dark(col, 0.45), 0.8)
    c.paint(c.line([(x0 + 0.12, y - 0.02), (x0 + 0.4, y + sag * 0.9 - 0.02)], 0.012), WHITE, 0.7)


def g_rope(c, M):
    c.glow(0, 0, 0.9, M, 0.3)
    for y in (-0.36, 0.0, 0.36):
        rope_line(c, y)
    for x in (-0.66, 0.66):
        c.solid(c.box(x, 0, 0.075, 0.6, 0.03), mix(M, INK, 0.45), ow=0.03)
        c.solid(c.circle(x, -0.62, 0.1), GOLD, ow=0.025)


def g_chip_blade(c, M):
    steel = hexrgb("#d6e0ee")
    S.sword(c, steel, 38, -0.12, 0.08)
    # 칼리스토 쪽(오른쪽 위)에 맞는 별빛 + 충격
    c.solid(c.poly(S.star_pts(0.44, -0.46, 0.34, 0.15, 8, rot=-90)), hexrgb("#fff1b0"), ow=0.03)
    c.paint(c.circle(0.44, -0.46, 0.07), WHITE)


def g_chip_foot(c, M):
    steel = hexrgb("#d6e0ee")
    sole = U(c.ellipse(0.0, -0.04, 0.2, 0.3), c.ellipse(0.02, 0.3, 0.15, 0.17))
    toes = U(*[c.circle(-0.17 + i * 0.113, -0.4 + (0.03 if i in (1, 2) else 0) + (0.08 if i == 3 else 0), 0.05 + (0.012 if i == 0 else 0)) for i in range(4)])
    c.solid(U(sole, toes), steel)
    red = hexrgb("#e0504a")
    c.paint(c.ring(0, 0, 0.66, 0.1), INK)
    c.paint(c.ring(0, 0, 0.66, 0.07), red)
    c.paint(c.seg(-0.47, -0.47, 0.47, 0.47, 0.085), INK)
    c.paint(c.seg(-0.47, -0.47, 0.47, 0.47, 0.055), red)


def g_chip_twin(c, M):
    blue = hexrgb("#cfe0ff")
    c.glow(-0.2, 0.15, 0.8, blue, 0.3)
    c.solid(c.poly(S.star_pts(-0.22, 0.18, 0.42, 0.18, 5)), blue)
    c.paint(c.seg(0.0, 0.0, 0.3, -0.3, 0.02), light(blue, 0.3), 0.8)
    c.solid(c.poly(S.star_pts(0.38, -0.38, 0.2, 0.09, 5)), hexrgb("#fff1b0"), ow=0.025)
    red = hexrgb("#ff7a6a")
    c.paint(c.ring(0.38, -0.38, 0.3, 0.045), INK)
    c.paint(c.ring(0.38, -0.38, 0.3, 0.028), red)
    for a in (0, 90, 180, 270):
        t = np.radians(a)
        c.paint(c.seg(0.38 + 0.22 * np.cos(t), -0.38 + 0.22 * np.sin(t), 0.38 + 0.42 * np.cos(t), -0.38 + 0.42 * np.sin(t), 0.026), INK)
        c.paint(c.seg(0.38 + 0.24 * np.cos(t), -0.38 + 0.24 * np.sin(t), 0.38 + 0.4 * np.cos(t), -0.38 + 0.4 * np.sin(t), 0.014), red)


def g_chip_rope(c, M):
    # 오른쪽 끝에 로프, 왼쪽에서 말이 화살표로 기댄다
    for x_off, rr in ((0.50, 1),):
        for y in (-0.4, 0.0, 0.4):
            pts = [(0.48 + 0.04 * np.sin(np.pi * t), -0.62 + 1.24 * t) for t in np.linspace(0, 1, 2)]
    for x in (0.44, 0.56, 0.68):
        c.solid(c.seg(x, -0.62, x, 0.62, 0.05), ROPE, ow=0.025)
    c.solid(c.box(0.56, -0.64, 0.2, 0.05, 0.02), mix(ROPE, INK, 0.5), ow=0.025)
    c.solid(c.box(0.56, 0.64, 0.2, 0.05, 0.02), mix(ROPE, INK, 0.5), ow=0.025)
    # 말(졸)
    pawn = U(c.circle(-0.42, -0.2, 0.15), c.poly([(-0.58, 0.45), (-0.26, 0.45), (-0.34, 0.0), (-0.5, 0.0)]), c.box(-0.42, 0.47, 0.2, 0.05, 0.02))
    c.solid(pawn, hexrgb("#d6e0ee"))
    # 화살표
    c.solid(U(c.seg(-0.2, 0.08, 0.2, 0.08, 0.055), c.poly([(0.14, -0.08), (0.34, 0.08), (0.14, 0.24)])), GOLD, ow=0.03)


ICONS = [
    ("Rope", "Neutral", ROPE, g_rope),
    ("Chip_Blade", "Neutral", GOLD, g_chip_blade),
    ("Chip_Foot", "Neutral", GOLD, g_chip_foot),
    ("Chip_TwinStars", "Neutral", GOLD, g_chip_twin),
    ("Chip_Rope", "Neutral", GOLD, g_chip_rope),
]


def render(name, size=256, ss=3):
    _, kind, col, fn = [i for i in ICONS if i[0] == name][0]
    c = Canvas(size, ss=ss)
    S.draw_frame(c, kind, col)
    c.X, c.Y = c.X0 / S.GLYPH_SCALE, c.Y0 / S.GLYPH_SCALE
    fn(c, col)
    return c.result()


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, *_ in ICONS:
        write_png(os.path.join(OUT, name + ".png"), render(name))
        print("[ui]", name)
    big, pad = 128, 12
    cw = big + pad * 2
    sheet = np.zeros((big + 48 + pad * 3, cw * len(ICONS), 4), np.uint8)
    sheet[...] = (22, 24, 36, 255)
    for k, (name, *_) in enumerate(ICONS):
        x0 = k * cw + pad
        over(sheet, resize(render(name, 256), big, big), x0, pad)
        y1 = pad * 2 + big
        over(sheet, render(name, 48, 8), x0, y1)
        over(sheet, render(name, 32, 12), x0 + 54, y1 + 8)
        fill_rect(sheet, x0 + 92, y1, 36, 48, (0.82, 0.82, 0.86))
        over(sheet, render(name, 32, 12), x0 + 94, y1 + 8)
    write_png(os.path.join(OUT, "_sheet.png"), sheet)


if __name__ == "__main__":
    main()
