# -*- coding: utf-8 -*-
"""
field_lib.py — 지역 들판(새 땅·오름·돌담·밭·바위·나무·길) 배치표 공용 도구. (2026-09-29)

요청: "지형들이 다 평면이라 밋밋해 … 마을과 필드의 비율을 늪지대에서의 비율을 따라가자."
섬마다 바깥쪽(군도 가운데 반대편)으로 땅을 넓히고 그 위에 들판을 짓는다. 지역별 배치표는 tools/fields/<이름>.py.

**무엇을 어디에 둘지는 배치표에 손으로 적는다.** 이 모듈은
  1. 배치표를 평면도 PNG 로 그리고(높이 지도가 있으면 밑에 깐다)
  2. 겹침·바다에 빠짐·길 막음을 검사하고
  3. Studio 가 읽을 Luau 표로 옮긴다(tools/swamp/field_data.luau → Field_Build_run.luau 조립).
판 채우기·오름 층 쌓기처럼 **모양 안을 고르게 채우는 것**만 규칙이 한다(자리·모양·크기는 표가 정한다).

좌표: 스터드, 위 = +Z(북), 오른쪽 = +X. 높이 y 는 판 윗면.
"""
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))


# ------------------------------------------------------------------ 기하
def pip(x, z, poly):
    """점이 다각형 안인가(짝홀)."""
    inside = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z):
            xi = x1 + (z - z1) * (x2 - x1) / (z2 - z1)
            if xi > x:
                inside = not inside
    return inside


def seg_dist(x, z, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0 if L2 == 0 else max(0, min(1, ((x - ax) * dx + (z - az) * dz) / L2))
    px, pz = ax + t * dx, az + t * dz
    return math.hypot(x - px, z - pz)


def poly_edge_dist(x, z, poly):
    return min(seg_dist(x, z, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def line_dist(x, z, pts):
    return min(seg_dist(x, z, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def smooth(e0, e1, v):
    t = max(0.0, min(1.0, (v - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def hash01(*args):
    """자리로 정해지는 0..1 값(같은 자리 → 같은 값). 판 크기·각도 흔들기에만 쓴다."""
    h = 2166136261
    for a in args:
        for ch in str(round(a, 2)).encode():
            h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h ^= h >> 15
    return (h & 0xFFFFFF) / float(0x1000000)


# ------------------------------------------------------------------ 높이
class Ground:
    """새 땅 높이: 손으로 적은 높이 점(IDW) + 물가로 갈수록 COAST_Y 로 낮아짐."""

    def __init__(self, coast, pts, coast_y=1.0, coast_w=140, holes=()):
        self.coast = coast
        self.pts = pts
        self.coast_y = coast_y
        self.coast_w = coast_w
        self.holes = holes

    def inside(self, x, z):
        return pip(x, z, self.coast) and not any(pip(x, z, h) for h in self.holes)

    def base(self, x, z):
        num = den = 0.0
        for px, pz, h in self.pts:
            d2 = (x - px) ** 2 + (z - pz) ** 2
            if d2 < 1:
                return h
            w = 1.0 / (d2 ** 1.3)
            num += w * h
            den += w
        return num / den

    def coast_d(self, x, z):
        d = poly_edge_dist(x, z, self.coast)
        for h in self.holes:
            d = min(d, poly_edge_dist(x, z, h))
        return d

    def y(self, x, z):
        d = self.coast_d(x, z)
        return self.coast_y + (self.base(x, z) - self.coast_y) * smooth(0, self.coast_w, d)


# ------------------------------------------------------------------ 오름
def oreum_profile(o, x, z):
    """오름 위 높이(땅에서 더 올라간 만큼). 밖이면 0. o: 오름 표 한 줄(dict)."""
    c, s = math.cos(math.radians(o["yaw"])), math.sin(math.radians(o["yaw"]))
    dx, dz = x - o["x"], z - o["z"]
    lx, lz = dx * c + dz * s, -dx * s + dz * c
    r = math.hypot(lx / o["rx"], lz / o["rz"])  # 1 = 밑둘레
    if r >= 1:
        return 0.0
    h = o["h"] * (1 - r) ** o.get("p", 0.75)
    cr = o.get("crater", 0) / o["rx"]
    if cr > 0 and r < cr:
        # 굼부리(분화구): 테두리에서 바닥까지 안쪽으로 파인 사발
        rim = o["h"] * (1 - cr) ** o.get("p", 0.75)
        return rim - o.get("depth", 0) * (1 - (r / cr) ** 2)
    return h


# ------------------------------------------------------------------ 그림
COL = {"Grass": (104, 150, 80), "Sand": (214, 204, 150), "Rock": (120, 118, 112), "Basalt": (58, 56, 58),
       "Field": (190, 170, 90), "Canola": (240, 220, 60), "Barley": (130, 170, 70), "Path": (150, 120, 84),
       "Wall": (40, 38, 40), "Tree": (40, 90, 40), "Cedar": (30, 70, 50), "Kit": (230, 90, 60), "Grass2": (218, 206, 150),
       "Water": (26, 52, 96), "Old": (80, 110, 70), "Fence": (140, 100, 60), "Poi": (255, 60, 200)}


class Canvas:
    def __init__(self, x0, z0, x1, z1, px=2.0):
        self.x0, self.z0, self.x1, self.z1, self.px = x0, z0, x1, z1, px
        self.W = int((x1 - x0) / px)
        self.H = int((z1 - z0) / px)
        self.img = [[COL["Water"] for _ in range(self.W)] for _ in range(self.H)]

    def ij(self, x, z):
        return int((x - self.x0) / self.px), int((self.z1 - z) / self.px)

    def put(self, x, z, col):
        i, j = self.ij(x, z)
        if 0 <= i < self.W and 0 <= j < self.H:
            self.img[j][i] = col

    def dot(self, x, z, r, col):
        rr = max(1, int(r / self.px))
        i0, j0 = self.ij(x, z)
        for j in range(j0 - rr, j0 + rr + 1):
            for i in range(i0 - rr, i0 + rr + 1):
                if 0 <= i < self.W and 0 <= j < self.H and (i - i0) ** 2 + (j - j0) ** 2 <= rr * rr:
                    self.img[j][i] = col

    def line(self, pts, w, col):
        for k in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[k], pts[k + 1]
            n = max(1, int(math.hypot(bx - ax, bz - az) / (self.px * 0.7)))
            for t in range(n + 1):
                self.dot(ax + (bx - ax) * t / n, az + (bz - az) * t / n, w / 2, col)

    def fill(self, fn):
        """fn(x, z) → 색 또는 None"""
        for j in range(self.H):
            z = self.z1 - (j + 0.5) * self.px
            for i in range(self.W):
                x = self.x0 + (i + 0.5) * self.px
                c = fn(x, z)
                if c is not None:
                    self.img[j][i] = c

    def grid(self, step=100):
        for j in range(self.H):
            z = self.z1 - j * self.px
            for i in range(self.W):
                x = self.x0 + i * self.px
                on5 = abs(x % 500) < self.px or abs(z % 500) < self.px
                on1 = abs(x % step) < self.px or abs(z % step) < self.px
                if on5:
                    self.img[j][i] = (255, 70, 70)
                elif on1:
                    self.img[j][i] = tuple(int(v * 0.8) for v in self.img[j][i])

    def save(self, path):
        raw = b"".join(b"\x00" + b"".join(bytes(max(0, min(255, int(v))) for v in p) for p in row) for row in self.img)

        def ch(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", self.W, self.H, 8, 2, 0, 0, 0))
                               + ch(b"IDAT", zlib.compress(raw, 6)) + ch(b"IEND", b""))


def load_hmap(path):
    """Studio 높이 지도(recv/hmap*.txt). 돌려주는 값: f(x, z) → (y, 재질) 또는 None(물·허공)."""
    L = open(path, encoding="utf-8").read().splitlines()
    X0, X1, Z0, Z1, S = map(int, L[0].split())
    leg = dict((int(a), b) for a, b in (i.split("=") for i in L[1].split(",")))
    g = []
    for row in L[2:]:
        cells = []
        for t in row.split(" "):
            if t == "_":
                cells.append(None)
            else:
                y, m = t.split(":")
                m = leg[int(m)]
                cells.append(None if m in ("T:Water", "Water") else (int(y), m))
        g.append(cells)

    def f(x, z):
        i = int(round((x - X0) / S))
        j = int(round((Z1 - z) / S))
        if 0 <= j < len(g) and 0 <= i < len(g[0]):
            return g[j][i]
        return None
    return f


# ------------------------------------------------------------------ Luau 로 옮기기
def lua(v, ind=""):
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if (isinstance(k, str) and k.isidentifier() and k.isascii()) else "[" + lua(k) + "]"
            items.append(key + " = " + lua(x, ind))
        return "{" + ", ".join(items) + "}"
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(x, ind) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 3)) if isinstance(v, float) else str(v)
    if v is None:
        return "nil"
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'
