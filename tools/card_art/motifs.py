# -*- coding: utf-8 -*-
"""
카드 그림 도형 라이브러리 (2026-09-28).

사용자가 그린 그림(CardArtworks: 양날의 검·레이피어·블랙홀…)의 결을 따른다:
  - 흰 선 그림. 선은 양 끝이 둥근 얇은 막대(Corner 0.5, 두께 0.012~0.02)
  - 원은 선으로(Stroke) 긋고, 채운 도형은 포인트로만 드물게
  - 색은 흰색 + 강조색 하나(카드의 첫 축 색)

좌표는 CardArtworks 와 같다: 한 변 1인 정사각형, (0,0) 왼쪽 위, y 가 아래로. 각도는 도, 시계 방향(+).
CardArt 가 이 좌표를 메달리온 안으로 줄여 넣으므로 0.12~0.88 안쪽에 그린다.
"""
import math

WHITE = "#ffffff"
LINE = 0.016   # 기본 선 두께
THIN = 0.010


def _r(v, n=4):
    return round(v, n)


class Art:
    def __init__(self, accent=WHITE):
        self.shapes = []
        self.z = 6
        self.accent = accent

    # --- 바탕 도형 ---
    def add(self, x, y, w, h, rot=0.0, color=WHITE, corner=0.5, stroke=0.0, tr=0.0):
        self.z += 1
        self.shapes.append({
            "X": _r(x), "Y": _r(y), "W": _r(max(w, 0.002)), "H": _r(max(h, 0.002)),
            "Rotation": _r(rot, 1), "Color": color, "Corner": _r(corner),
            "Stroke": _r(stroke), "ZIndex": self.z, "Transparency": _r(tr, 2),
        })
        return self

    def line(self, x1, y1, x2, y2, w=LINE, color=WHITE, tr=0.0):
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        return self.add((x1 + x2) / 2, (y1 + y2) / 2, length + w, w, math.degrees(math.atan2(dy, dx)), color, 0.5, 0, tr)

    def poly(self, pts, closed=False, w=LINE, color=WHITE, tr=0.0):
        seq = list(pts) + ([pts[0]] if closed else [])
        for (x1, y1), (x2, y2) in zip(seq, seq[1:]):
            self.line(x1, y1, x2, y2, w, color, tr)
        return self

    def arc(self, cx, cy, r, a0, a1, w=LINE, color=WHITE, n=None, ry=None, rot=0.0, tr=0.0):
        """a0→a1 (도, 시계 방향). ry 를 주면 타원, rot 로 타원을 돌린다."""
        ry = r if ry is None else ry
        steps = n or max(3, int(abs(a1 - a0) / 14))
        pts = []
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            px, py = r * math.cos(a), ry * math.sin(a)
            pts.append((cx + px * c - py * s, cy + px * s + py * c))
        return self.poly(pts, False, w, color, tr)

    def ring(self, cx, cy, r, w=LINE, color=WHITE, tr=0.0):
        return self.add(cx, cy, 2 * r, 2 * r, 0, color, 0.5, w, tr)

    def ellipse(self, cx, cy, rx, ry, rot=0.0, w=LINE, color=WHITE, tr=0.0):
        return self.add(cx, cy, 2 * rx, 2 * ry, rot, color, 0.5, w, tr)

    def disc(self, cx, cy, r, color=WHITE, tr=0.0):
        return self.add(cx, cy, 2 * r, 2 * r, 0, color, 0.5, 0, tr)

    def rect(self, cx, cy, w, h, rot=0.0, color=WHITE, corner=0.08, stroke=LINE, tr=0.0):
        return self.add(cx, cy, w, h, rot, color, corner, stroke, tr)

    def fill(self, cx, cy, w, h, rot=0.0, color=WHITE, corner=0.08, tr=0.0):
        return self.add(cx, cy, w, h, rot, color, corner, 0, tr)

    def diamond(self, cx, cy, s, color=WHITE, stroke=0.0, tr=0.0):
        return self.add(cx, cy, s, s, 45, color, 0.06, stroke, tr)


# ---------------------------------------------------------------- 좌표 도우미

def rot(px, py, ang):
    a = math.radians(ang)
    return px * math.cos(a) - py * math.sin(a), px * math.sin(a) + py * math.cos(a)


def at(cx, cy, s, ang, pts):
    """단위 좌표(중심 0, 크기 1)의 점들을 s 배·ang 도 돌려 (cx, cy) 에 놓는다."""
    out = []
    for px, py in pts:
        x, y = rot(px * s, py * s, ang)
        out.append((cx + x, cy + y))
    return out


def polar(cx, cy, r, ang):
    a = math.radians(ang)
    return cx + r * math.cos(a), cy + r * math.sin(a)


# ---------------------------------------------------------------- 무기·도구

def sword(A, cx, cy, s=0.6, ang=-90, w=LINE, color=WHITE, fuller=True):
    """칼끝이 ang 쪽. s 는 전체 길이."""
    tip, base, grip_end = 0.5, -0.16, -0.36
    edge = 0.045
    pts = at(cx, cy, s, ang, [(tip, 0), (0.36, edge), (base, edge), (base, -edge), (0.36, -edge)])
    A.poly(pts, closed=True, w=w, color=color)
    if fuller:
        a, b = at(cx, cy, s, ang, [(0.3, 0), (base + 0.03, 0)])
        A.line(*a, *b, w=THIN * 0.8, color=color)
    g1, g2 = at(cx, cy, s, ang, [(base, 0.15), (base, -0.15)])
    A.line(*g1, *g2, w=w * 1.2, color=color)
    h1, h2 = at(cx, cy, s, ang, [(base, 0), (grip_end, 0)])
    A.line(*h1, *h2, w=w * 1.4, color=color)
    p = at(cx, cy, s, ang, [(grip_end - 0.03, 0)])[0]
    A.disc(*p, 0.03 * s / 0.6 * 1.0 + 0.004, color=color)


def rapier(A, cx, cy, s=0.7, ang=-45, color=WHITE):
    tip, base = 0.5, -0.12
    a, b = at(cx, cy, s, ang, [(tip, 0), (base, 0)])
    A.line(*a, *b, w=LINE * 0.9, color=color)
    hc = at(cx, cy, s, ang, [(base - 0.02, 0)])[0]
    A.arc(hc[0], hc[1], 0.09 * s, ang - 100, ang + 100, w=THIN, color=color)
    g1, g2 = at(cx, cy, s, ang, [(base, 0.13), (base, -0.13)])
    A.line(*g1, *g2, w=LINE, color=color)
    h1, h2 = at(cx, cy, s, ang, [(base, 0), (-0.34, 0)])
    A.line(*h1, *h2, w=LINE * 1.3, color=color)
    A.disc(*at(cx, cy, s, ang, [(-0.36, 0)])[0], 0.022 * s / 0.7 + 0.006, color=color)


def dagger(A, cx, cy, s=0.36, ang=-90, color=WHITE):
    sword(A, cx, cy, s, ang, w=LINE * 0.9, color=color, fuller=False)


def axe(A, cx, cy, s=0.6, ang=-60, color=WHITE, flip=False):
    """자루 끝이 ang 반대쪽, 머리가 ang 쪽. 날은 자루의 한쪽(flip 이면 반대쪽)으로 초승달처럼."""
    a, b = at(cx, cy, s, ang, [(0.46, 0), (-0.48, 0)])
    A.line(*a, *b, w=LINE * 1.3, color=color)
    side = -1 if flip else 1
    # 날 윤곽(자루 쪽 두 점 → 바깥 호 → 자루 쪽)
    outer = []
    for i in range(11):
        th = math.radians(-70 + i * 140 / 10)
        outer.append((0.31 + 0.2 * math.sin(th), side * (0.06 + 0.2 * math.cos(th))))
    blade = [(0.43, side * 0.03)] + outer + [(0.19, side * 0.03)]
    A.poly(at(cx, cy, s, ang, blade), closed=True, w=LINE, color=color)
    spike = at(cx, cy, s, ang, [(0.36, -side * 0.03), (0.31, -side * 0.12), (0.26, -side * 0.03)])
    A.poly(spike, w=LINE, color=color)


def hammer(A, cx, cy, s=0.6, ang=-60, color=WHITE):
    a, b = at(cx, cy, s, ang, [(0.3, 0), (-0.45, 0)])
    A.line(*a, *b, w=LINE * 1.3, color=color)
    hc = at(cx, cy, s, ang, [(0.36, 0)])[0]
    A.rect(hc[0], hc[1], 0.16 * s, 0.4 * s, ang, color=color, corner=0.1, stroke=LINE)


def nail(A, cx, cy, s=0.55, ang=90, color=WHITE, head=True):
    """못 끝이 ang 쪽."""
    a, b = at(cx, cy, s, ang, [(-0.36, 0), (0.28, 0)])
    A.line(*a, *b, w=LINE * 1.5, color=color)
    t1, t2, t3 = at(cx, cy, s, ang, [(0.28, 0.035), (0.46, 0), (0.28, -0.035)])
    A.poly([t1, t2, t3], w=LINE, color=color)
    if head:
        h1, h2 = at(cx, cy, s, ang, [(-0.38, 0.14), (-0.38, -0.14)])
        A.line(*h1, *h2, w=LINE * 1.8, color=color)


def staff(A, cx, cy, s=0.7, ang=-80, color=WHITE):
    a, b = at(cx, cy, s, ang, [(0.4, 0), (-0.5, 0)])
    A.line(*a, *b, w=LINE * 1.2, color=color)
    top = at(cx, cy, s, ang, [(0.42, 0)])[0]
    A.arc(top[0], top[1] - 0.0, 0.07 * s / 0.7 + 0.02, 180, 450, w=LINE, color=color)


def chisel(A, cx, cy, s=0.55, ang=45, color=WHITE):
    a, b = at(cx, cy, s, ang, [(-0.45, 0), (0.05, 0)])
    A.line(*a, *b, w=LINE * 2.2, color=color)
    blade = at(cx, cy, s, ang, [(0.05, 0.05), (0.45, 0.03), (0.45, -0.03), (0.05, -0.05)])
    A.poly(blade, closed=True, w=LINE, color=color)


def pick(A, cx, cy, s=0.6, ang=-60, color=WHITE):
    a, b = at(cx, cy, s, ang, [(0.35, 0), (-0.45, 0)])
    A.line(*a, *b, w=LINE * 1.2, color=color)
    # 머리: 자루 끝을 지나며 자루와 직각으로 휜 막대(자루 쪽에 중심을 둔 호)
    center = at(cx, cy, s, ang, [(0.35 - 0.55, 0)])[0]
    A.arc(center[0], center[1], 0.55 * s, ang - 32, ang + 32, w=LINE * 1.4, color=color)


def trowel(A, cx, cy, s=0.55, ang=45, color=WHITE):
    a, b = at(cx, cy, s, ang, [(-0.45, 0), (-0.12, 0)])
    A.line(*a, *b, w=LINE * 1.6, color=color)
    blade = at(cx, cy, s, ang, [(-0.1, 0.0), (0.05, 0.16), (0.45, 0.0), (0.05, -0.16)])
    A.poly(blade, closed=True, w=LINE, color=color)


# ---------------------------------------------------------------- 몸·상징

def shield(A, cx, cy, s=0.5, color=WHITE, w=LINE, cross=False):
    pts = at(cx, cy, s, 0, [(-0.4, -0.45), (0.4, -0.45), (0.4, 0.0), (0.3, 0.22), (0.0, 0.5),
                             (-0.3, 0.22), (-0.4, 0.0)])
    A.poly(pts, closed=True, w=w, color=color)
    if cross:
        A.line(cx, cy - 0.3 * s, cx, cy + 0.3 * s, w=w, color=color)
        A.line(cx - 0.25 * s, cy - 0.1 * s, cx + 0.25 * s, cy - 0.1 * s, w=w, color=color)


def heart(A, cx, cy, s=0.4, color=WHITE, filled=False, w=LINE):
    if filled:
        A.disc(cx - 0.13 * s, cy - 0.08 * s, 0.15 * s, color)
        A.disc(cx + 0.13 * s, cy - 0.08 * s, 0.15 * s, color)
        A.fill(cx, cy + 0.05 * s, 0.3 * s, 0.3 * s, 45, color, corner=0.1)
        return
    A.arc(cx - 0.13 * s, cy - 0.1 * s, 0.14 * s, 135, 330, w=w, color=color)
    A.arc(cx + 0.13 * s, cy - 0.1 * s, 0.14 * s, 210, 405, w=w, color=color)
    A.line(cx - 0.25 * s, cy - 0.0 * s, cx, cy + 0.3 * s, w=w, color=color)
    A.line(cx + 0.25 * s, cy - 0.0 * s, cx, cy + 0.3 * s, w=w, color=color)


def drop(A, cx, cy, s=0.3, color=WHITE, filled=True, w=LINE):
    """물·피 방울. 꼭지가 위."""
    r = 0.25 * s
    if filled:
        A.disc(cx, cy + 0.12 * s, r, color)
        A.fill(cx, cy - 0.02 * s, r * 1.42, r * 1.42, 45, color, corner=0.05)
        return
    A.arc(cx, cy + 0.12 * s, r, -30, 210, w=w, color=color)
    A.line(cx - r * 0.87, cy + 0.12 * s - r * 0.5, cx, cy - 0.33 * s, w=w, color=color)
    A.line(cx + r * 0.87, cy + 0.12 * s - r * 0.5, cx, cy - 0.33 * s, w=w, color=color)


def flame(A, cx, cy, s=0.5, color=WHITE, inner=True, w=LINE):
    outer = [(0, -0.5), (0.12, -0.28), (0.28, -0.12), (0.3, 0.1), (0.2, 0.3), (0, 0.38),
             (-0.2, 0.3), (-0.3, 0.1), (-0.24, -0.08), (-0.12, -0.02), (-0.14, -0.26)]
    A.poly(at(cx, cy, s, 0, outer), closed=True, w=w, color=color)
    if inner:
        small = [(0, -0.12), (0.12, 0.08), (0.08, 0.24), (0, 0.28), (-0.08, 0.24), (-0.12, 0.1)]
        A.poly(at(cx, cy, s, 0, small), closed=True, w=w * 0.8, color=color)


def star(A, cx, cy, r, n=5, inner=0.45, color=WHITE, w=LINE, ang=-90, filled=False):
    pts = []
    for i in range(n * 2):
        rr = r if i % 2 == 0 else r * inner
        pts.append(polar(cx, cy, rr, ang + i * 180 / n))
    if filled:
        A.disc(cx, cy, r * inner * 1.05, color)
        for i in range(n):
            a = ang + i * 360 / n
            p = polar(cx, cy, r * 0.62, a)
            A.fill(p[0], p[1], r * 0.75, r * 0.34, a, color, corner=0.1)
        return
    A.poly(pts, closed=True, w=w, color=color)


def sparkle(A, cx, cy, r, color=WHITE, w=LINE, ang=0):
    for a in (ang, ang + 90):
        p1, p2 = polar(cx, cy, r, a), polar(cx, cy, r, a + 180)
        A.line(*p1, *p2, w=w, color=color)
    A.diamond(cx, cy, r * 0.45, color)


def rays(A, cx, cy, r0, r1, n=8, ang=0, color=WHITE, w=LINE, spread=360):
    for i in range(n):
        a = ang + (spread / n) * i if spread == 360 else ang - spread / 2 + spread * i / max(1, n - 1)
        A.line(*polar(cx, cy, r0, a), *polar(cx, cy, r1, a), w=w, color=color)


def eye(A, cx, cy, s=0.5, color=WHITE, w=LINE, pupil=WHITE):
    A.arc(cx, cy + 0.2 * s, 0.4 * s, 210, 330, w=w, color=color)
    A.arc(cx, cy - 0.2 * s, 0.4 * s, 30, 150, w=w, color=color)
    A.ring(cx, cy, 0.11 * s, w=w, color=color)
    A.disc(cx, cy, 0.05 * s, pupil)


def fist(A, cx, cy, s=0.45, color=WHITE, w=LINE):
    for i in range(4):
        A.rect(cx - 0.18 * s + i * 0.12 * s, cy - 0.12 * s, 0.12 * s, 0.2 * s, 0, color, 0.45, w)
    A.rect(cx, cy + 0.1 * s, 0.5 * s, 0.26 * s, 0, color, 0.3, w)
    A.rect(cx - 0.26 * s, cy + 0.02 * s, 0.1 * s, 0.26 * s, -30, color, 0.5, w)


def hand_open(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.rect(cx, cy + 0.12 * s, 0.34 * s, 0.34 * s, 0, color, 0.3, w)
    for i, (dx, h) in enumerate([(-0.12, 0.3), (-0.04, 0.36), (0.04, 0.36), (0.12, 0.3)]):
        A.rect(cx + dx * s, cy - 0.16 * s, 0.07 * s, h * s, 0, color, 0.5, w)
    A.rect(cx - 0.22 * s, cy + 0.04 * s, 0.07 * s, 0.26 * s, -40, color, 0.5, w)


def claw(A, cx, cy, s=0.5, color=WHITE, w=LINE * 1.3, ang=0):
    for i in (-1, 0, 1):
        ox, oy = rot(i * 0.14 * s, 0, ang)
        A.arc(cx + ox + 0.25 * s, cy + oy + 0.25 * s, 0.45 * s, 190 + ang, 250 + ang, w=w, color=color)


def crack(A, cx, cy, s=0.6, ang=90, color=WHITE, w=LINE):
    pts = at(cx, cy, s, ang, [(-0.5, 0), (-0.28, 0.08), (-0.1, -0.06), (0.1, 0.07), (0.28, -0.05), (0.5, 0.03)])
    A.poly(pts, w=w, color=color)
    b1 = at(cx, cy, s, ang, [(-0.1, -0.06), (0.0, -0.2)])
    A.line(*b1[0], *b1[1], w=w * 0.8, color=color)
    b2 = at(cx, cy, s, ang, [(0.1, 0.07), (0.2, 0.2)])
    A.line(*b2[0], *b2[1], w=w * 0.8, color=color)


def shards(A, cx, cy, s=0.5, n=5, color=WHITE, w=THIN, seed=1):
    import random
    rnd = random.Random(seed)
    for i in range(n):
        a = i * 360 / n + rnd.uniform(-20, 20)
        d = s * rnd.uniform(0.25, 0.45)
        px, py = polar(cx, cy, d, a)
        size = s * rnd.uniform(0.08, 0.14)
        tri = at(px, py, size, a + rnd.uniform(0, 120), [(0, -0.6), (0.5, 0.4), (-0.5, 0.4)])
        A.poly(tri, closed=True, w=w, color=color)


def skull(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx, cy - 0.05 * s, 0.3 * s, 150, 390, w=w, color=color)
    A.line(cx - 0.26 * s, cy + 0.1 * s, cx - 0.16 * s, cy + 0.3 * s, w=w, color=color)
    A.line(cx + 0.26 * s, cy + 0.1 * s, cx + 0.16 * s, cy + 0.3 * s, w=w, color=color)
    A.line(cx - 0.16 * s, cy + 0.3 * s, cx + 0.16 * s, cy + 0.3 * s, w=w, color=color)
    A.ring(cx - 0.11 * s, cy - 0.02 * s, 0.07 * s, w=w, color=color)
    A.ring(cx + 0.11 * s, cy - 0.02 * s, 0.07 * s, w=w, color=color)
    A.line(cx, cy + 0.08 * s, cx, cy + 0.14 * s, w=w, color=color)
    for dx in (-0.08, 0, 0.08):
        A.line(cx + dx * s, cy + 0.22 * s, cx + dx * s, cy + 0.3 * s, w=THIN, color=color)


def fangs(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx, cy - 0.3 * s, 0.42 * s, 40, 140, w=w, color=color)
    for dx, h in ((-0.2, 0.18), (-0.07, 0.1), (0.07, 0.1), (0.2, 0.18)):
        x = cx + dx * s
        y = cy - 0.3 * s + 0.42 * s * math.sin(math.radians(90 - abs(dx) * 120)) - 0.02
        A.poly([(x - 0.04 * s, y), (x, y + h * s), (x + 0.04 * s, y)], w=THIN * 1.2, color=color)


def crown(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    pts = at(cx, cy, s, 0, [(-0.4, 0.2), (-0.4, -0.2), (-0.2, 0.02), (0, -0.3), (0.2, 0.02), (0.4, -0.2), (0.4, 0.2)])
    A.poly(pts, closed=True, w=w, color=color)
    for px in (-0.4, 0, 0.4):
        A.disc(cx + px * s, cy - (0.3 if px == 0 else 0.2) * s - 0.03, 0.022, color)


def cross(A, cx, cy, s=0.5, color=WHITE, w=LINE * 1.3):
    A.line(cx, cy - 0.45 * s, cx, cy + 0.45 * s, w=w, color=color)
    A.line(cx - 0.28 * s, cy - 0.18 * s, cx + 0.28 * s, cy - 0.18 * s, w=w, color=color)


def hourglass(A, cx, cy, s=0.5, color=WHITE, w=LINE, sand=None):
    A.line(cx - 0.25 * s, cy - 0.4 * s, cx + 0.25 * s, cy - 0.4 * s, w=w * 1.3, color=color)
    A.line(cx - 0.25 * s, cy + 0.4 * s, cx + 0.25 * s, cy + 0.4 * s, w=w * 1.3, color=color)
    A.poly([(cx - 0.2 * s, cy - 0.4 * s), (cx, cy), (cx - 0.2 * s, cy + 0.4 * s)], w=w, color=color)
    A.poly([(cx + 0.2 * s, cy - 0.4 * s), (cx, cy), (cx + 0.2 * s, cy + 0.4 * s)], w=w, color=color)
    if sand:
        A.fill(cx, cy + 0.3 * s, 0.22 * s, 0.1 * s, 0, sand, corner=0.3)


def clock(A, cx, cy, r=0.25, color=WHITE, w=LINE, h=-60, m=0):
    A.ring(cx, cy, r, w=w, color=color)
    A.line(cx, cy, *polar(cx, cy, r * 0.55, h), w=w, color=color)
    A.line(cx, cy, *polar(cx, cy, r * 0.8, m - 90), w=w * 0.8, color=color)
    for i in range(12):
        a = i * 30
        A.line(*polar(cx, cy, r * 0.82, a), *polar(cx, cy, r * 0.92, a), w=THIN * 0.8, color=color)


def arrow(A, x1, y1, x2, y2, color=WHITE, w=LINE, head=0.07):
    A.line(x1, y1, x2, y2, w=w, color=color)
    ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
    A.line(x2, y2, *polar(x2, y2, head, ang + 150), w=w, color=color)
    A.line(x2, y2, *polar(x2, y2, head, ang - 150), w=w, color=color)


def chevrons(A, cx, cy, s=0.3, n=3, ang=0, gap=0.09, color=WHITE, w=LINE):
    for i in range(n):
        off = (i - (n - 1) / 2) * gap
        ox, oy = rot(off, 0, ang)
        p = at(cx + ox, cy + oy, s, ang, [(-0.15, -0.3), (0.15, 0), (-0.15, 0.3)])
        A.poly(p, w=w, color=color)


def target(A, cx, cy, r=0.28, color=WHITE, w=LINE, dot=WHITE):
    A.ring(cx, cy, r, w=w, color=color)
    A.ring(cx, cy, r * 0.6, w=w, color=color)
    A.disc(cx, cy, r * 0.18, dot)
    for a in (0, 90, 180, 270):
        A.line(*polar(cx, cy, r * 1.05, a), *polar(cx, cy, r * 1.3, a), w=w, color=color)


def gear(A, cx, cy, r=0.22, teeth=8, color=WHITE, w=LINE, ang=0):
    A.ring(cx, cy, r, w=w, color=color)
    A.ring(cx, cy, r * 0.4, w=w, color=color)
    for i in range(teeth):
        a = ang + i * 360 / teeth
        p = polar(cx, cy, r + 0.035, a)
        A.fill(p[0], p[1], 0.06, 0.05, a, color, corner=0.1)


def magnet(A, cx, cy, s=0.5, ang=0, color=WHITE, tips=None, w=LINE * 1.3):
    c = at(cx, cy, s, ang, [(0, 0.05)])[0]
    A.arc(c[0], c[1], 0.22 * s, ang, ang + 180, w=w, color=color)
    for side in (-1, 1):
        a, b = at(cx, cy, s, ang, [(side * 0.22, 0.05), (side * 0.22, -0.35)])
        A.line(*a, *b, w=w, color=color)
        if tips:
            t1, t2 = at(cx, cy, s, ang, [(side * 0.22, -0.28), (side * 0.22, -0.38)])
            A.line(*t1, *t2, w=w * 1.4, color=tips)


def orbit(A, cx, cy, rx, ry, tilt=-20, color=WHITE, w=THIN, moon=None, moon_at=30):
    A.ellipse(cx, cy, rx, ry, tilt, w=w, color=color)
    if moon:
        a = math.radians(moon_at)
        px, py = rx * math.cos(a), ry * math.sin(a)
        x, y = rot(px, py, tilt)
        A.disc(cx + x, cy + y, 0.035, moon)


def planet(A, cx, cy, r=0.16, color=WHITE, ring_color=WHITE, w=LINE):
    A.ring(cx, cy, r, w=w, color=color)
    A.ellipse(cx, cy, r * 1.8, r * 0.5, -18, w=THIN, color=ring_color)


def moon(A, cx, cy, r=0.22, color=WHITE, w=LINE, ang=0):
    A.arc(cx, cy, r, 60 + ang, 300 + ang, w=w, color=color)
    A.arc(cx + r * 0.35 * math.cos(math.radians(ang)), cy + r * 0.35 * math.sin(math.radians(ang)),
          r * 0.78, 80 + ang, 280 + ang, w=w, color=color)


def sun(A, cx, cy, r=0.13, color=WHITE, n=10, w=LINE):
    A.ring(cx, cy, r, w=w, color=color)
    rays(A, cx, cy, r * 1.35, r * 1.9, n, color=color, w=w)


def spiral(A, cx, cy, r=0.3, turns=2.5, color=WHITE, w=LINE, ang=0):
    pts = []
    steps = int(turns * 24)
    for i in range(steps + 1):
        t = i / steps
        a = ang + t * turns * 360
        pts.append(polar(cx, cy, r * t, a))
    A.poly(pts, w=w, color=color)


def wave(A, cx, cy, width=0.6, amp=0.06, periods=2, color=WHITE, w=LINE, phase=0, tr=0.0):
    pts = []
    n = int(periods * 16)
    for i in range(n + 1):
        t = i / n
        x = cx - width / 2 + width * t
        y = cy + amp * math.sin(math.radians(phase + t * periods * 360))
        pts.append((x, y))
    A.poly(pts, w=w, color=color, tr=tr)


def pulse(A, cx, cy, width=0.66, h=0.2, color=WHITE, w=LINE):
    pts = [(-0.5, 0), (-0.18, 0), (-0.1, -0.2), (0.0, 0.5), (0.08, -0.9), (0.16, 0.2), (0.22, 0), (0.5, 0)]
    A.poly([(cx + x * width, cy + y * h) for x, y in pts], w=w, color=color)


def bolt(A, cx, cy, s=0.5, color=WHITE, w=LINE, ang=0):
    pts = at(cx, cy, s, ang, [(0.08, -0.5), (-0.18, 0.05), (0.02, 0.05), (-0.1, 0.5), (0.2, -0.08), (0.0, -0.08), (0.14, -0.5)])
    A.poly(pts, closed=True, w=w, color=color)


def chain(A, cx, cy, s=0.6, ang=-35, n=4, color=WHITE, w=LINE):
    for i in range(n):
        off = (i - (n - 1) / 2) * 0.2
        ox, oy = rot(off * s, 0, ang)
        vertical = i % 2 == 1
        A.rect(cx + ox, cy + oy, 0.26 * s, 0.12 * s if not vertical else 0.08 * s, ang, color, 0.5, w)


def bricks(A, cx, cy, s=0.6, rows=3, cols=3, color=WHITE, w=THIN * 1.2, gaps=(), tr=0.0):
    bw, bh = s / cols, s * 0.5 / rows
    top = cy - bh * rows / 2
    for r in range(rows):
        offset = (bw / 2) if r % 2 == 1 else 0
        for c in range(cols + (1 if offset else 0)):
            x = cx - s / 2 + offset + c * bw + bw / 2 - (bw / 2 if offset else 0)
            if (r, c) in gaps:
                continue
            left, right = x - bw / 2, x + bw / 2
            left, right = max(left, cx - s / 2), min(right, cx + s / 2)
            if right - left < 0.02:
                continue
            A.rect((left + right) / 2, top + r * bh + bh / 2, right - left - 0.012, bh - 0.012, 0, color, 0.12, w, tr)


def stone(A, cx, cy, r=0.16, color=WHITE, w=LINE, ang=0):
    pts = [polar(cx, cy, r * (1 if i % 2 == 0 else 0.92), ang + i * 60) for i in range(6)]
    A.poly(pts, closed=True, w=w, color=color)


def pillar(A, cx, cy, h=0.6, wid=0.14, color=WHITE, w=LINE):
    A.rect(cx, cy - h / 2 + 0.025, wid * 1.6, 0.05, 0, color, 0.2, w)
    A.rect(cx, cy + h / 2 - 0.025, wid * 1.6, 0.05, 0, color, 0.2, w)
    A.line(cx - wid / 2, cy - h / 2 + 0.05, cx - wid / 2, cy + h / 2 - 0.05, w=w, color=color)
    A.line(cx + wid / 2, cy - h / 2 + 0.05, cx + wid / 2, cy + h / 2 - 0.05, w=w, color=color)
    A.line(cx, cy - h / 2 + 0.08, cx, cy + h / 2 - 0.08, w=THIN * 0.7, color=color)


def arch(A, cx, cy, wid=0.5, h=0.5, color=WHITE, w=LINE, keystone=None):
    r = wid / 2
    A.arc(cx, cy - h / 2 + r, r, 180, 360, w=w, color=color)
    A.line(cx - r, cy - h / 2 + r, cx - r, cy + h / 2, w=w, color=color)
    A.line(cx + r, cy - h / 2 + r, cx + r, cy + h / 2, w=w, color=color)
    if keystone:
        A.fill(cx, cy - h / 2 + 0.01, 0.07, 0.08, 0, keystone, corner=0.1)


def cathedral(A, cx, cy, s=0.6, color=WHITE, w=LINE):
    A.poly([(cx - 0.3 * s, cy + 0.4 * s), (cx - 0.3 * s, cy - 0.05 * s), (cx, cy - 0.3 * s),
            (cx + 0.3 * s, cy - 0.05 * s), (cx + 0.3 * s, cy + 0.4 * s)], closed=True, w=w, color=color)
    A.line(cx, cy - 0.3 * s, cx, cy - 0.5 * s, w=w, color=color)
    A.line(cx - 0.06 * s, cy - 0.42 * s, cx + 0.06 * s, cy - 0.42 * s, w=w, color=color)
    arch(A, cx, cy + 0.2 * s, 0.18 * s, 0.4 * s, color=color, w=w)
    A.ring(cx, cy - 0.04 * s, 0.07 * s, w=THIN, color=color)


def flask(A, cx, cy, s=0.5, color=WHITE, liquid=None, w=LINE):
    r = 0.26 * s
    by = cy + 0.12 * s
    A.arc(cx, by, r, -60, 240, w=w, color=color)
    nx = r * 0.5
    A.line(cx - nx, by - r * 0.86, cx - nx, cy - 0.32 * s, w=w, color=color)
    A.line(cx + nx, by - r * 0.86, cx + nx, cy - 0.32 * s, w=w, color=color)
    A.line(cx - nx * 1.5, cy - 0.34 * s, cx + nx * 1.5, cy - 0.34 * s, w=w * 1.2, color=color)
    if liquid:
        A.disc(cx, by + r * 0.25, r * 0.66, liquid, tr=0.1)


def bottle(A, cx, cy, s=0.5, color=WHITE, liquid=None, w=LINE):
    A.rect(cx, cy + 0.1 * s, 0.32 * s, 0.5 * s, 0, color, 0.25, w)
    A.line(cx - 0.07 * s, cy - 0.15 * s, cx - 0.07 * s, cy - 0.35 * s, w=w, color=color)
    A.line(cx + 0.07 * s, cy - 0.15 * s, cx + 0.07 * s, cy - 0.35 * s, w=w, color=color)
    A.fill(cx, cy - 0.38 * s, 0.12 * s, 0.05 * s, 0, color, corner=0.3)
    if liquid:
        A.fill(cx, cy + 0.2 * s, 0.24 * s, 0.26 * s, 0, liquid, corner=0.2, tr=0.1)


def leaf(A, cx, cy, s=0.4, ang=-45, color=WHITE, w=LINE):
    a, b = at(cx, cy, s, ang, [(-0.5, 0), (0.5, 0)])
    mid = at(cx, cy, s, ang, [(0, 0)])[0]
    A.arc(mid[0], mid[1], 0.5 * s, 0, 180, w=w, color=color, ry=0.2 * s, rot=ang, n=12)
    A.arc(mid[0], mid[1], 0.5 * s, 180, 360, w=w, color=color, ry=0.2 * s, rot=ang, n=12)
    A.line(*a, *b, w=THIN, color=color)


def sprig(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx + 0.3 * s, cy + 0.1 * s, 0.4 * s, 150, 230, w=w, color=color)
    for i, (dx, dy, ang) in enumerate([(-0.02, -0.25, -60), (-0.12, -0.05, -130), (-0.06, 0.12, -40)]):
        leaf(A, cx + dx * s + 0.05 * s, cy + dy * s, 0.28 * s, ang, color=color, w=THIN * 1.2)


def mortar(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx, cy - 0.05 * s, 0.34 * s, 0, 180, w=w, color=color)
    A.line(cx - 0.38 * s, cy - 0.05 * s, cx + 0.38 * s, cy - 0.05 * s, w=w, color=color)
    A.line(cx - 0.12 * s, cy + 0.33 * s, cx + 0.12 * s, cy + 0.33 * s, w=w * 1.3, color=color)
    A.line(cx + 0.05 * s, cy - 0.1 * s, cx + 0.32 * s, cy - 0.46 * s, w=w * 1.6, color=color)


def candle(A, cx, cy, s=0.5, color=WHITE, fire=WHITE, w=LINE):
    A.rect(cx, cy + 0.15 * s, 0.14 * s, 0.46 * s, 0, color, 0.15, w)
    A.line(cx, cy - 0.08 * s, cx, cy - 0.14 * s, w=THIN, color=color)
    flame(A, cx, cy - 0.26 * s, 0.22 * s, color=fire, inner=False, w=THIN * 1.2)


def bell(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx, cy - 0.1 * s, 0.2 * s, 180, 360, w=w, color=color)
    A.line(cx - 0.2 * s, cy - 0.1 * s, cx - 0.28 * s, cy + 0.22 * s, w=w, color=color)
    A.line(cx + 0.2 * s, cy - 0.1 * s, cx + 0.28 * s, cy + 0.22 * s, w=w, color=color)
    A.line(cx - 0.34 * s, cy + 0.22 * s, cx + 0.34 * s, cy + 0.22 * s, w=w, color=color)
    A.disc(cx, cy + 0.3 * s, 0.045 * s, color)
    A.ring(cx, cy - 0.33 * s, 0.04 * s, w=THIN, color=color)


def book(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.poly([(cx, cy - 0.22 * s), (cx - 0.38 * s, cy - 0.3 * s), (cx - 0.38 * s, cy + 0.26 * s), (cx, cy + 0.34 * s)], w=w, color=color)
    A.poly([(cx, cy - 0.22 * s), (cx + 0.38 * s, cy - 0.3 * s), (cx + 0.38 * s, cy + 0.26 * s), (cx, cy + 0.34 * s)], w=w, color=color)
    A.line(cx, cy - 0.22 * s, cx, cy + 0.34 * s, w=w, color=color)
    for i in range(3):
        y = cy - 0.1 * s + i * 0.12 * s
        A.line(cx - 0.3 * s, y - 0.02 * s, cx - 0.08 * s, y + 0.01 * s, w=THIN * 0.7, color=color)
        A.line(cx + 0.08 * s, y + 0.01 * s, cx + 0.3 * s, y - 0.02 * s, w=THIN * 0.7, color=color)


def scales(A, cx, cy, s=0.6, color=WHITE, w=LINE, tilt=0):
    A.line(cx, cy - 0.35 * s, cx, cy + 0.35 * s, w=w, color=color)
    A.line(cx - 0.2 * s, cy + 0.35 * s, cx + 0.2 * s, cy + 0.35 * s, w=w * 1.2, color=color)
    l, r = at(cx, cy - 0.25 * s, s, tilt, [(-0.38, 0), (0.38, 0)])
    A.line(*l, *r, w=w, color=color)
    for (px, py) in (l, r):
        A.line(px, py, px - 0.1 * s, py + 0.22 * s, w=THIN, color=color)
        A.line(px, py, px + 0.1 * s, py + 0.22 * s, w=THIN, color=color)
        A.arc(px, py + 0.22 * s, 0.12 * s, 0, 180, w=w, color=color)


def anchor(A, cx, cy, s=0.6, color=WHITE, w=LINE):
    A.ring(cx, cy - 0.38 * s, 0.06 * s, w=w, color=color)
    A.line(cx, cy - 0.32 * s, cx, cy + 0.36 * s, w=w * 1.2, color=color)
    A.line(cx - 0.16 * s, cy - 0.2 * s, cx + 0.16 * s, cy - 0.2 * s, w=w, color=color)
    A.arc(cx, cy + 0.02 * s, 0.34 * s, 20, 160, w=w, color=color)


def lock(A, cx, cy, s=0.5, color=WHITE, w=LINE, key=WHITE):
    A.rect(cx, cy + 0.1 * s, 0.5 * s, 0.4 * s, 0, color, 0.12, w)
    A.arc(cx, cy - 0.1 * s, 0.17 * s, 180, 360, w=w, color=color)
    A.line(cx - 0.17 * s, cy - 0.1 * s, cx - 0.17 * s, cy - 0.1 * s + 0.001, w=w, color=color)
    A.disc(cx, cy + 0.07 * s, 0.045 * s, key)
    A.line(cx, cy + 0.07 * s, cx, cy + 0.2 * s, w=w, color=key)


def banner(A, cx, cy, s=0.6, color=WHITE, w=LINE):
    A.line(cx - 0.3 * s, cy - 0.45 * s, cx - 0.3 * s, cy + 0.45 * s, w=w * 1.2, color=color)
    A.poly([(cx - 0.3 * s, cy - 0.4 * s), (cx + 0.32 * s, cy - 0.4 * s), (cx + 0.2 * s, cy - 0.22 * s),
            (cx + 0.32 * s, cy - 0.04 * s), (cx - 0.3 * s, cy - 0.04 * s)], w=w, color=color)


def feather(A, cx, cy, s=0.6, ang=-50, color=WHITE, w=LINE):
    a, b = at(cx, cy, s, ang, [(-0.5, 0), (0.5, 0)])
    A.line(*a, *b, w=THIN, color=color)
    mid = at(cx, cy, s, ang, [(0.08, 0)])[0]
    A.arc(mid[0], mid[1], 0.4 * s, 180, 360, w=w, color=color, ry=0.14 * s, rot=ang, n=12)
    A.arc(mid[0], mid[1], 0.4 * s, 0, 180, w=w, color=color, ry=0.14 * s, rot=ang, n=12)
    for t in (-0.1, 0.1, 0.25):
        p = at(cx, cy, s, ang, [(t, 0), (t - 0.08, 0.12)])
        A.line(*p[0], *p[1], w=THIN * 0.7, color=color)


def comet(A, cx, cy, r=0.07, ang=-35, length=0.4, color=WHITE, head=WHITE, w=LINE):
    for off in (-0.04, 0, 0.04):
        ox, oy = rot(0, off, ang)
        A.line(cx + ox, cy + oy, *polar(cx + ox, cy + oy, length * (1 - abs(off) * 5), ang + 180), w=THIN, color=color)
    A.disc(cx, cy, r, head)


def burst(A, cx, cy, r=0.3, n=12, color=WHITE, w=LINE, core=None):
    for i in range(n):
        a = i * 360 / n
        rr = r if i % 2 == 0 else r * 0.62
        A.line(*polar(cx, cy, r * 0.28, a), *polar(cx, cy, rr, a), w=w, color=color)
    if core:
        A.disc(cx, cy, r * 0.2, core)


def atom(A, cx, cy, r=0.3, color=WHITE, w=THIN, nucleus=WHITE):
    for t in (0, 60, 120):
        A.ellipse(cx, cy, r, r * 0.34, t, w=w, color=color)
    A.disc(cx, cy, 0.04, nucleus)


def grid(A, cx, cy, s=0.5, n=3, color=WHITE, w=THIN, filled=(), fill=WHITE):
    cell = s / n
    for i in range(n):
        for j in range(n):
            x = cx - s / 2 + cell * (i + 0.5)
            y = cy - s / 2 + cell * (j + 0.5)
            if (i, j) in filled:
                A.fill(x, y, cell * 0.8, cell * 0.8, 0, fill, corner=0.12)
            else:
                A.rect(x, y, cell * 0.8, cell * 0.8, 0, color, 0.12, w)


def mask(A, cx, cy, s=0.5, color=WHITE, w=LINE):
    A.arc(cx, cy - 0.05 * s, 0.34 * s, 200, 340, w=w, color=color)
    A.arc(cx, cy - 0.2 * s, 0.42 * s, 30, 150, w=w, color=color)
    A.ellipse(cx - 0.13 * s, cy - 0.05 * s, 0.08 * s, 0.045 * s, -10, w=w, color=color)
    A.ellipse(cx + 0.13 * s, cy - 0.05 * s, 0.08 * s, 0.045 * s, 10, w=w, color=color)


def footprints(A, cx, cy, s=0.5, color=WHITE, ang=-90, n=3):
    for i in range(n):
        off = (i - (n - 1) / 2) * 0.22
        side = 0.06 if i % 2 == 0 else -0.06
        ox, oy = rot(off * s * 1.4, side * s * 1.4, ang)
        A.ellipse(cx + ox, cy + oy, 0.05 * s * 1.4, 0.08 * s * 1.4, ang + 90, w=THIN, color=color)


def person(A, cx, cy, s=0.5, color=WHITE, w=LINE, arms=0):
    A.ring(cx, cy - 0.3 * s, 0.09 * s, w=w, color=color)
    A.line(cx, cy - 0.2 * s, cx, cy + 0.12 * s, w=w, color=color)
    A.line(cx, cy + 0.12 * s, cx - 0.12 * s, cy + 0.42 * s, w=w, color=color)
    A.line(cx, cy + 0.12 * s, cx + 0.12 * s, cy + 0.42 * s, w=w, color=color)
    A.line(cx, cy - 0.12 * s, *polar(cx, cy - 0.12 * s, 0.22 * s, 180 - arms), w=w, color=color)
    A.line(cx, cy - 0.12 * s, *polar(cx, cy - 0.12 * s, 0.22 * s, arms), w=w, color=color)


def note(A, cx, cy, s=0.5, color=WHITE, flags=1, filled=True, w=LINE):
    hx, hy = cx - 0.1 * s, cy + 0.28 * s
    if filled:
        A.add(hx, hy, 0.2 * s, 0.14 * s, -22, color, 0.5, 0)
    else:
        A.add(hx, hy, 0.2 * s, 0.14 * s, -22, color, 0.5, w)
    top = cy - 0.38 * s
    A.line(hx + 0.09 * s, hy - 0.02 * s, hx + 0.09 * s, top, w=w, color=color)
    for i in range(flags):
        y = top + i * 0.1 * s
        A.arc(hx + 0.09 * s, y + 0.12 * s, 0.14 * s, -90, -10, w=w, color=color, rot=0)


def staff_lines(A, cx, cy, width=0.7, gap=0.06, n=5, color=WHITE, w=THIN * 0.8, tr=0.3):
    for i in range(n):
        y = cy + (i - (n - 1) / 2) * gap
        A.line(cx - width / 2, y, cx + width / 2, y, w=w, color=color, tr=tr)
