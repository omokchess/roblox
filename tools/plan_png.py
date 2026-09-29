# -*- coding: utf-8 -*-
"""
plan_png.py — 표준 라이브러리만으로 평면도 PNG 를 그리는 작은 캔버스.

모든 모양을 다각형으로 바꿔 줄 단위(스캔라인)로 칠한다. 좌표는 월드 스터드,
region 과 sc(스터드당 픽셀)로 화면에 옮긴다. jeolhwa_plan.py 가 쓴다.
"""
import math
import struct
import zlib

FONT = {  # 3x5 숫자
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
    "8": "111101111101111", "9": "111101111001111", "-": "000000111000000",
}


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[k:k + 2], 16) for k in (0, 2, 4))


def seg_rect(ax, az, bx, bz, w):
    dx, dz = bx - ax, bz - az
    L = math.hypot(dx, dz)
    ux, uz = dx / L, dz / L
    nx, nz = -uz * w / 2, ux * w / 2
    return [(ax + nx, az + nz), (bx + nx, bz + nz), (bx - nx, bz - nz), (ax - nx, az - nz)]


class Canvas:
    def __init__(self, x0, z0, x1, z1, sc):
        self.x0, self.z0, self.sc = x0, z0, sc
        self.W, self.H = int((x1 - x0) * sc), int((z1 - z0) * sc)
        self.px = bytearray(self.W * self.H * 3)

    def poly(self, pts, col, a=1.0):
        r, g, b = hexrgb(col)
        P = [((x - self.x0) * self.sc, (z - self.z0) * self.sc) for x, z in pts]
        ys = [p[1] for p in P]
        y0, y1 = max(0, int(min(ys))), min(self.H - 1, int(max(ys)) + 1)
        n = len(P)
        W3 = self.W * 3
        for py in range(y0, y1 + 1):
            yc = py + 0.5
            xs = []
            for k in range(n):
                (ax, ay), (bx, by) = P[k], P[(k + 1) % n]
                if (ay <= yc < by) or (by <= yc < ay):
                    xs.append(ax + (yc - ay) * (bx - ax) / (by - ay))
            xs.sort()
            base = py * W3
            for k in range(0, len(xs) - 1, 2):
                xa, xb = max(0, int(xs[k] + 0.5)), min(self.W, int(xs[k + 1] + 0.5))
                if xb <= xa:
                    continue
                if a >= 1.0:
                    self.px[base + xa * 3: base + xb * 3] = bytes((r, g, b)) * (xb - xa)
                else:
                    for o in range(base + xa * 3, base + xb * 3, 3):
                        self.px[o] = int(self.px[o] * (1 - a) + r * a)
                        self.px[o + 1] = int(self.px[o + 1] * (1 - a) + g * a)
                        self.px[o + 2] = int(self.px[o + 2] * (1 - a) + b * a)

    def rect(self, x0, z0, x1, z1, col, a=1.0):
        self.poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], col, a)

    def line(self, ax, az, bx, bz, w, col, a=1.0):
        if (ax, az) != (bx, bz):
            self.poly(seg_rect(ax, az, bx, bz, w), col, a)

    def circle(self, x, z, r, col, a=1.0):
        self.poly([(x + r * math.cos(t * math.pi / 8), z + r * math.sin(t * math.pi / 8)) for t in range(16)], col, a)

    def outline(self, pts, w, col):
        for k in range(len(pts)):
            a, b = pts[k], pts[(k + 1) % len(pts)]
            self.line(a[0], a[1], b[0], b[1], w, col)

    def text(self, x, z, s, col, px=2):
        cx = (x - self.x0) * self.sc
        cy = (z - self.z0) * self.sc
        r, g, b = hexrgb(col)
        for ch in s:
            bits = FONT.get(ch)
            if bits:
                for k, bit in enumerate(bits):
                    if bit == "1":
                        for dy in range(px):
                            for dx in range(px):
                                X = int(cx + (k % 3) * px + dx)
                                Y = int(cy + (k // 3) * px + dy)
                                if 0 <= X < self.W and 0 <= Y < self.H:
                                    o = (Y * self.W + X) * 3
                                    self.px[o], self.px[o + 1], self.px[o + 2] = r, g, b
            cx += 4 * px

    def save(self, path):
        W3 = self.W * 3
        raw = b"".join(b"\x00" + bytes(self.px[y * W3:(y + 1) * W3]) for y in range(self.H))

        def chunk(t, d):
            c = struct.pack(">I", len(d)) + t + d
            return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.W, self.H, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


if __name__ == "__main__":
    import os
    import tempfile
    c = Canvas(0, 0, 40, 30, 2.0)
    c.rect(0, 0, 40, 30, "#ffffff")
    c.rect(5, 5, 15, 10, "#ff0000")
    c.circle(30, 15, 5, "#0000ff", 0.5)
    assert c.px[(12 * c.W + 20) * 3:(12 * c.W + 20) * 3 + 3] == bytearray((255, 0, 0)), "사각형이 안 칠해졌다"
    p = os.path.join(tempfile.gettempdir(), "plan_png_selftest.png")
    c.save(p)
    assert open(p, "rb").read(8) == b"\x89PNG\r\n\x1a\n"
    print("ok", p)
