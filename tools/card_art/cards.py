# -*- coding: utf-8 -*-
"""
카드마다 손으로 짠 그림 구성 (2026-09-28). 도형은 motifs.py.

규칙
  - 흰 선 그림 + 강조색 하나(A.accent = 카드 첫 축의 색, CardAxes). 강조색은 "그 카드의 핵심"에만.
  - 카드 이름·효과가 한눈에 읽히는 상징 하나를 크게, 곁가지는 작게.
"""
import json
import os

from motifs import *  # noqa: F401,F403

HERE = os.path.dirname(os.path.abspath(__file__))

# CardAxes 색(축 Id → #rrggbb)
AXIS = {
    "Melody": "#78c8ff", "Tempo": "#ffcd5a", "Chorus": "#82e696", "Solo": "#f078c8",
    "Precision": "#78c8ff", "Guard": "#c8c8d7", "Riposte": "#ffcd5a", "Execute": "#eb5a5a",
    "Anchor": "#aa8cff", "Charge": "#78c8ff", "Overload": "#ff9646", "Taunt": "#c8c8d7",
    "Ward": "#78c8ff", "Chain": "#aa8cff", "Volley": "#ffcd5a", "Aegis": "#82e696",
    "Judgment": "#ffcd5a", "Mark": "#eb5a5a", "Spread": "#82e696", "Faith": "#f0ebc8",
    "Construct": "#c8aa78", "Plating": "#78c8ff", "Endure": "#82e696",
    "Vanguard": "#ff9646", "Sacrifice": "#eb5a5a", "Brink": "#aa3c50",
    "Brew": "#82e696", "Catalyst": "#aa8cff", "Burn": "#ff9646",
    "Rage": "#eb5a5a", "Frenzy": "#ff9646", "Blood": "#aa283c",
}
BLOOD = "#c8323c"

_DUMP = os.path.join(os.environ.get("CARD_DUMP", ""), "") if os.environ.get("CARD_DUMP") else None
TAGS = {}
NAMES = {}
ARTS = {}  # 지금 카드에 적힌 Art (사용자 그림을 덮어쓰지 않으려고 본다)


def _load_cards():
    """카드 이름·태그를 소스에서 읽는다(Lune 없이). AbilityCards/*.luau 의 Id·Name·Tags 줄."""
    import re
    folder = os.path.join(HERE, "..", "..", "src", "shared", "AbilityCards")
    for name in os.listdir(folder):
        if not name.endswith(".luau"):
            continue
        text = open(os.path.join(folder, name), encoding="utf-8").read()
        for block in re.split(r"\n\t\{", text):
            m = re.search(r'Id = "([^"]+)"', block)
            if not m:
                continue
            card_id = m.group(1)
            n = re.search(r'Name = "([^"]+)"', block)
            t = re.search(r"Tags = \{([^}]*)\}", block)
            if n:
                NAMES[card_id] = n.group(1)
            if t:
                TAGS[card_id] = re.findall(r'"(\w+)"', t.group(1))
            a = re.search(r'Art = "([^"]+)"', block)
            if a:
                ARTS[card_id] = a.group(1)


_load_cards()


def accent_for(card_id):
    tags = TAGS.get(card_id) or []
    return AXIS.get(tags[0] if tags else "", "#ffffff")


SPECS = {}


def art(card_id):
    def deco(fn):
        SPECS[card_id] = fn
        return fn
    return deco


C = 0.5  # 가운데




#==================================================================== 작은 도형(이 파일에서만)

def sharp(A, cx, cy, s=0.3, color=WHITE, w=LINE):
    for dx in (-0.08, 0.08):
        A.line(cx + dx * s, cy - 0.4 * s, cx + dx * s, cy + 0.4 * s, w=w, color=color)
    for dy in (-0.12, 0.12):
        A.line(cx - 0.25 * s, cy + dy * s + 0.05 * s, cx + 0.25 * s, cy + dy * s - 0.05 * s, w=w * 1.3, color=color)


def tuning_fork(A, cx, cy, s=0.6, color=WHITE, w=LINE):
    A.line(cx, cy + 0.1 * s, cx, cy + 0.45 * s, w=w * 1.2, color=color)
    A.arc(cx, cy + 0.02 * s, 0.1 * s, 0, 180, w=w, color=color)
    A.line(cx - 0.1 * s, cy + 0.02 * s, cx - 0.1 * s, cy - 0.45 * s, w=w, color=color)
    A.line(cx + 0.1 * s, cy + 0.02 * s, cx + 0.1 * s, cy - 0.45 * s, w=w, color=color)


def snowflake(A, cx, cy, r=0.28, color=WHITE, w=LINE):
    for a in (0, 60, 120):
        A.line(*polar(cx, cy, r, a), *polar(cx, cy, r, a + 180), w=w, color=color)
        for sgn in (1, -1):
            base = polar(cx, cy, r * 0.62, a if sgn > 0 else a + 180)
            ang = a if sgn > 0 else a + 180
            A.line(*base, *polar(*base, r * 0.25, ang + 45), w=THIN, color=color)
            A.line(*base, *polar(*base, r * 0.25, ang - 45), w=THIN, color=color)


def lighthouse(A, cx, cy, s=0.6, color=WHITE, beam=WHITE, w=LINE):
    A.poly([(cx - 0.14 * s, cy + 0.42 * s), (cx - 0.09 * s, cy - 0.18 * s), (cx + 0.09 * s, cy - 0.18 * s), (cx + 0.14 * s, cy + 0.42 * s)], closed=True, w=w, color=color)
    A.rect(cx, cy - 0.26 * s, 0.16 * s, 0.14 * s, 0, color, 0.1, w)
    A.poly([(cx - 0.1 * s, cy - 0.33 * s), (cx, cy - 0.44 * s), (cx + 0.1 * s, cy - 0.33 * s)], w=w, color=color)
    for dy in (0.02, 0.2):
        A.line(cx - 0.11 * s, cy + dy * s, cx + 0.11 * s, cy + dy * s, w=THIN, color=color)
    A.poly([(cx + 0.08 * s, cy - 0.28 * s), (cx + 0.45 * s, cy - 0.4 * s), (cx + 0.45 * s, cy - 0.14 * s)], closed=True, w=THIN, color=beam)
    A.poly([(cx - 0.08 * s, cy - 0.28 * s), (cx - 0.45 * s, cy - 0.4 * s), (cx - 0.45 * s, cy - 0.14 * s)], closed=True, w=THIN, color=beam)


def ground_symbol(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.line(cx, cy - 0.3 * s, cx, cy, w=w, color=color)
    for i, half in enumerate((0.3, 0.2, 0.1)):
        y = cy + i * 0.1 * s
        A.line(cx - half * s, y, cx + half * s, y, w=w, color=color)


def bulb(A, cx, cy, s=0.5, color=WHITE, glow=WHITE, w=LINE):
    A.arc(cx, cy - 0.08 * s, 0.24 * s, 130, 410, w=w, color=color)
    A.line(cx - 0.15 * s, cy + 0.1 * s, cx - 0.1 * s, cy + 0.26 * s, w=w, color=color)
    A.line(cx + 0.15 * s, cy + 0.1 * s, cx + 0.1 * s, cy + 0.26 * s, w=w, color=color)
    for dy in (0.3, 0.36):
        A.line(cx - 0.1 * s, cy + dy * s, cx + 0.1 * s, cy + dy * s, w=THIN, color=color)
    A.poly([(cx - 0.06 * s, cy + 0.05 * s), (cx - 0.03 * s, cy - 0.1 * s), (cx, cy + 0.0), (cx + 0.03 * s, cy - 0.1 * s), (cx + 0.06 * s, cy + 0.05 * s)], w=THIN, color=glow)


def dumbbell(A, cx, cy, s=0.6, color=WHITE, w=LINE, ang=0):
    a, b = at(cx, cy, s, ang, [(-0.3, 0), (0.3, 0)])
    A.line(*a, *b, w=w * 1.3, color=color)
    for side in (-1, 1):
        for off, h in ((0.3, 0.3), (0.38, 0.22)):
            p = at(cx, cy, s, ang, [(side * off, 0)])[0]
            A.rect(p[0], p[1], 0.06 * s, h * s, ang, color, 0.2, w)


def pill(A, cx, cy, s=0.4, ang=-40, color=WHITE, half=WHITE, w=LINE):
    A.rect(cx, cy, 0.7 * s, 0.28 * s, ang, color, 0.5, w)
    p = at(cx, cy, s, ang, [(-0.175, 0)])[0]
    A.fill(p[0], p[1], 0.33 * s, 0.22 * s, ang, half, corner=0.5, tr=0.1)
    a, b = at(cx, cy, s, ang, [(0, -0.14), (0, 0.14)])
    A.line(*a, *b, w=THIN, color=color)


def bowl(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.line(cx - 0.4 * s, cy, cx + 0.4 * s, cy, w=w, color=color)
    A.arc(cx, cy, 0.4 * s, 0, 180, w=w, color=color, ry=0.26 * s)
    A.line(cx - 0.12 * s, cy + 0.32 * s, cx + 0.12 * s, cy + 0.32 * s, w=w * 1.2, color=color)


def sickle(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    ox, oy = cx + 0.06 * s, cy - 0.04 * s
    A.arc(ox, oy, 0.34 * s, 170, 350, w=w * 1.4, color=color)
    A.arc(ox, oy, 0.26 * s, 190, 340, w=THIN, color=color)
    root = polar(ox, oy, 0.34 * s, 170)
    A.line(*root, root[0] + 0.04 * s, root[1] + 0.4 * s, w=w * 1.6, color=color)


def satellite(A, cx, cy, s=0.3, color=WHITE, w=LINE, ang=-30):
    A.rect(cx, cy, 0.16 * s, 0.16 * s, ang, color, 0.1, w)
    for side in (-1, 1):
        p = at(cx, cy, s, ang, [(side * 0.34, 0)])[0]
        A.rect(p[0], p[1], 0.36 * s, 0.14 * s, ang, color, 0.05, THIN)
        a, b = at(cx, cy, s, ang, [(side * 0.08, 0), (side * 0.16, 0)])
        A.line(*a, *b, w=THIN, color=color)


def coin(A, cx, cy, r=0.08, color=WHITE, w=THIN):
    A.ring(cx, cy, r, w=w, color=color)
    A.ring(cx, cy, r * 0.62, w=THIN * 0.7, color=color)


def box(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.rect(cx, cy + 0.08 * s, 0.6 * s, 0.4 * s, 0, color, 0.08, w)
    A.poly([(cx - 0.3 * s, cy - 0.12 * s), (cx - 0.22 * s, cy - 0.28 * s), (cx + 0.38 * s, cy - 0.28 * s), (cx + 0.3 * s, cy - 0.12 * s)], w=w, color=color)


def clover(A, cx, cy, r=0.06, color=WHITE, w=THIN):
    for a in (0, 90, 180, 270):
        A.ring(*polar(cx, cy, r, a), r, w=w, color=color)
    A.line(cx, cy, cx + r * 0.6, cy + r * 3, w=w, color=color)


def swirl(A, cx, cy, r=0.2, color=WHITE, w=LINE, n=3):
    for i in range(n):
        A.arc(cx + (i - 1) * r * 0.5, cy + (i - 1) * r * 0.25, r * (0.6 + 0.2 * i), 180 + i * 20, 330 + i * 20, w=w, color=color)


def piano(A, cx, cy, s=0.6, color=WHITE, w=THIN):
    A.rect(cx, cy, s, s * 0.45, 0, color, 0.06, w * 1.3)
    for i in range(1, 7):
        x = cx - s / 2 + i * s / 7
        A.line(x, cy - s * 0.225, x, cy + s * 0.225, w=w, color=color)
    for i in (1, 2, 4, 5, 6):
        x = cx - s / 2 + i * s / 7
        A.fill(x, cy - s * 0.08, s * 0.07, s * 0.28, 0, color, corner=0.1)


def repeat_sign(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.line(cx + 0.12 * s, cy - 0.35 * s, cx + 0.12 * s, cy + 0.35 * s, w=w, color=color)
    A.line(cx + 0.24 * s, cy - 0.35 * s, cx + 0.24 * s, cy + 0.35 * s, w=w * 2.2, color=color)
    A.disc(cx - 0.02 * s, cy - 0.1 * s, 0.035 * s, color)
    A.disc(cx - 0.02 * s, cy + 0.1 * s, 0.035 * s, color)


def loop_arrow(A, cx, cy, r=0.25, color=WHITE, w=LINE, start=-60, end=230):
    A.arc(cx, cy, r, start, end, w=w, color=color)
    tip = polar(cx, cy, r, end)
    ang = end + 90
    A.line(*tip, *polar(*tip, 0.06, ang + 150), w=w, color=color)
    A.line(*tip, *polar(*tip, 0.06, ang - 150), w=w, color=color)


def dots(A, pts, r=0.016, color=WHITE):
    for x, y in pts:
        A.disc(x, y, r, color)


# 직업별 구성(specs/*.py 가 @art 로 SPECS 에 등록한다)
import importlib  # noqa: E402
import pkgutil  # noqa: E402

for _mod in pkgutil.iter_modules([os.path.join(HERE, "specs")]):
    importlib.import_module("specs." + _mod.name)
