# -*- coding: utf-8 -*-
"""
아트팀 공용 그리기 도구 (2026-11-06).  numpy 만 쓴다(PIL 없음).

  돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" tools/art/<스크립트>.py
  (시스템 파이썬 3.10 에는 numpy 가 없다. 블렌더 안 파이썬에 있다.)

원리: 도형을 부호 있는 거리(SDF)로 만들고, 3배 크게 칠한 뒤 줄여서 안티앨리어싱한다.
좌표: 세로 -1~1(아래가 +), 가로는 -비율~비율. 아이콘은 정사각이라 -1~1.
"""
import struct
import zlib

import numpy as np


# ───────────────────────── PNG ─────────────────────────
def write_png(path, rgba):
    """rgba: (H,W,4) uint8"""
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def read_png(path):
    """우리가 쓴 PNG(8bit RGBA, 필터 0)만 읽는다 — 비교판 조립용."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    w = h = 0
    while pos < len(data):
        ln, = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h = struct.unpack(">II", body[:8])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + ln
    raw = zlib.decompress(idat)
    out = np.zeros((h, w, 4), np.uint8)
    stride = w * 4 + 1
    for y in range(h):
        assert raw[y * stride] == 0, "필터 0 만 지원"
        out[y] = np.frombuffer(raw[y * stride + 1:(y + 1) * stride], np.uint8).reshape(w, 4)
    return out


# ───────────────────────── 색 ─────────────────────────
def hexrgb(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def mix(a, b, t):
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


WHITE = np.array([1.0, 1.0, 1.0])
INK = hexrgb("#080a12")


def light(c, t=0.4):
    return mix(c, WHITE, t)


def dark(c, t=0.45):
    return mix(c, INK, t)


# ───────────────────────── 캔버스 ─────────────────────────
class Canvas:
    def __init__(self, w, h=None, ss=3):
        h = h or w
        self.w, self.h, self.ss = w, h, ss
        n_w, n_h = w * ss, h * ss
        aspect = w / h
        xs = (np.arange(n_w) + 0.5) / n_w * 2 - 1
        ys = (np.arange(n_h) + 0.5) / n_h * 2 - 1
        self.X0, self.Y0 = np.meshgrid(xs * aspect, ys)
        self.X, self.Y = self.X0, self.Y0
        self.px = 2.0 / n_h  # 한 칸의 너비(설계 단위)
        self.rgb = np.zeros((n_h, n_w, 3))  # 미리 곱한 색
        self.a = np.zeros((n_h, n_w))
        self.ymin, self.ymax = -0.75, 0.75  # 그라디언트 범위

    # ── 좌표 변환 ──
    class _At:
        def __init__(s, c, rot, dx, dy):
            s.c, s.rot, s.dx, s.dy = c, rot, dx, dy

        def __enter__(s):
            c = s.c
            s.save = (c.X, c.Y)
            t = np.radians(s.rot)
            ct, st = np.cos(t), np.sin(t)
            x, y = c.X - s.dx, c.Y - s.dy
            # 도형을 rot 도 돌리는 것 = 점을 -rot 도 돌린다
            c.X, c.Y = x * ct + y * st, -x * st + y * ct

        def __exit__(s, *a):
            s.c.X, s.c.Y = s.save

    def at(self, rot=0, dx=0, dy=0):
        return Canvas._At(self, rot, dx, dy)

    # ── 거리 도형 (전부 안쪽이 음수) ──
    def circle(self, cx, cy, r):
        return np.hypot(self.X - cx, self.Y - cy) - r

    def ellipse(self, cx, cy, a, b):
        return (np.hypot((self.X - cx) / a, (self.Y - cy) / b) - 1) * min(a, b)

    def box(self, cx, cy, hw, hh, r=0.0):
        r = min(r, hw, hh)
        qx = np.abs(self.X - cx) - (hw - r)
        qy = np.abs(self.Y - cy) - (hh - r)
        return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r

    def seg(self, x1, y1, x2, y2, r):
        px, py = self.X - x1, self.Y - y1
        dx, dy = x2 - x1, y2 - y1
        h = np.clip((px * dx + py * dy) / (dx * dx + dy * dy + 1e-12), 0, 1)
        return np.hypot(px - dx * h, py - dy * h) - r

    def line(self, pts, r):
        d = None
        for (x1, y1), (x2, y2) in zip(pts[:-1], pts[1:]):
            s = self.seg(x1, y1, x2, y2, r)
            d = s if d is None else np.minimum(d, s)
        return d

    def ring(self, cx, cy, r, t):
        return np.abs(np.hypot(self.X - cx, self.Y - cy) - r) - t / 2

    def arc(self, cx, cy, r, a0, a1, t, n=24):
        pts = [(cx + r * np.cos(np.radians(a)), cy + r * np.sin(np.radians(a))) for a in np.linspace(a0, a1, n)]
        return self.line(pts, t / 2)

    def stadium(self, cx, cy, half, r):
        """가로로 긴 알약(반길이 half, 반지름 r)"""
        return self.seg(cx - half, cy, cx + half, cy, r)

    def poly(self, pts):
        """임의 다각형(오목 가능). 정확한 부호 거리."""
        P = np.asarray(pts, float)
        xs, ys = P[:, 0], P[:, 1]
        m = 0.25
        x0, x1, y0, y1 = xs.min() - m, xs.max() + m, ys.min() - m, ys.max() + m
        inside_box = (self.X >= x0) & (self.X <= x1) & (self.Y >= y0) & (self.Y <= y1)
        out = np.full(self.X.shape, m)
        idx = np.nonzero(inside_box)
        if len(idx[0]) == 0:
            return out
        px, py = self.X[idx], self.Y[idx]
        d = np.full(px.shape, 1e9)
        sign = np.ones(px.shape)
        n = len(P)
        for i in range(n):
            ax, ay = P[i]
            bx, by = P[(i + 1) % n]
            ex, ey = bx - ax, by - ay
            wx, wy = px - ax, py - ay
            h = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey + 1e-12), 0, 1)
            d = np.minimum(d, np.hypot(wx - ex * h, wy - ey * h))
            cond = [py >= ay, py < by, ex * wy > ey * wx]
            flip = (cond[0] & cond[1] & cond[2]) | (~cond[0] & ~cond[1] & ~cond[2])
            sign = np.where(flip, -sign, sign)
        out[idx] = np.minimum(sign * d, m)
        return out

    def smooth(self, pts, closed=True, per=10):
        """Catmull-Rom 으로 부드럽게 이은 다각형(점 목록)"""
        P = np.asarray(pts, float)
        n = len(P)
        out = []
        rng = range(n) if closed else range(n - 1)
        for i in rng:
            p0 = P[(i - 1) % n] if (closed or i > 0) else P[0]
            p1 = P[i]
            p2 = P[(i + 1) % n]
            p3 = P[(i + 2) % n] if (closed or i + 2 < n) else P[-1]
            for t in np.linspace(0, 1, per, endpoint=False):
                t2, t3 = t * t, t * t * t
                out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
        if not closed:
            out.append(P[-1])
        return [tuple(p) for p in out]

    def blob(self, pts):
        return self.poly(self.smooth(pts))

    def star(self, cx, cy, R, r, n=5, rot=-90):
        pts = []
        for i in range(n * 2):
            a = np.radians(rot + i * 180.0 / n)
            rr = R if i % 2 == 0 else r
            pts.append((cx + rr * np.cos(a), cy + rr * np.sin(a)))
        return self.poly(pts)

    def ngon(self, cx, cy, R, n, rot=-90, round_=0.0):
        pts = [(cx + R * np.cos(np.radians(rot + i * 360.0 / n)), cy + R * np.sin(np.radians(rot + i * 360.0 / n))) for i in range(n)]
        d = self.poly(pts)
        if round_ > 0:  # 모서리 둥글게: 안쪽으로 줄였다 부풀린다
            inner = [(cx + (R - round_ * 2.2) * np.cos(np.radians(rot + i * 360.0 / n)),
                      cy + (R - round_ * 2.2) * np.sin(np.radians(rot + i * 360.0 / n))) for i in range(n)]
            d = self.poly(inner) - round_
        return d

    def arrow_down(self, x, y1, y2, w, head):
        shaft = self.seg(x, y1, x, y2 - head * 0.5, w / 2)
        tri = self.poly([(x - head, y2 - head * 1.3), (x + head, y2 - head * 1.3), (x, y2)])
        return np.minimum(shaft, tri)

    # ── 합성 ──
    @staticmethod
    def U(*ds):
        out = ds[0]
        for d in ds[1:]:
            out = np.minimum(out, d)
        return out

    @staticmethod
    def sub(a, b):
        return np.maximum(a, -b)

    @staticmethod
    def inter(a, b):
        return np.maximum(a, b)

    def cov(self, d):
        return np.clip(0.5 - d / self.px, 0, 1)

    def _color(self, color):
        c = np.asarray(color, float)
        if c.ndim == 2:  # (위, 아래) 그라디언트
            t = np.clip((self.Y0 - self.ymin) / (self.ymax - self.ymin), 0, 1)[..., None]
            return c[0] * (1 - t) + c[1] * t
        return c

    def paint(self, d, color, alpha=1.0):
        a = self.cov(d) * alpha
        col = self._color(color)
        self.rgb = col * a[..., None] + self.rgb * (1 - a[..., None])
        self.a = a + self.a * (1 - a)

    def paint_through(self, d, alpha=1.0):
        """그린 것을 지운다(구멍)."""
        k = 1 - self.cov(d) * alpha
        self.rgb *= k[..., None]
        self.a *= k

    def solid(self, d, color, ow=0.035, alpha=1.0, grad=True, outline=True):
        """윤곽선(INK) + 위가 밝고 아래가 어두운 면."""
        if outline and ow > 0:
            self.paint(d - ow, INK, 0.92)
        color = np.asarray(color, float)
        if grad and color.ndim == 1:
            color = np.stack([light(color, 0.28), dark(color, 0.18)])
        self.paint(d, color, alpha)

    def glow(self, cx, cy, r, color, strength=0.5):
        d = np.hypot(self.X - cx, self.Y - cy)
        a = np.clip(1 - d / r, 0, 1) ** 2 * strength
        col = np.asarray(color, float)
        self.rgb = col * a[..., None] + self.rgb * (1 - a[..., None])
        self.a = a + self.a * (1 - a)

    def mask_to(self, d):
        """지금까지 그린 것을 d 안쪽만 남긴다."""
        k = self.cov(d)
        self.rgb *= k[..., None]
        self.a *= k

    def result(self):
        s = self.ss
        n_h, n_w = self.a.shape
        a = self.a.reshape(self.h, s, self.w, s).mean(axis=(1, 3))
        rgb = self.rgb.reshape(self.h, s, self.w, s, 3).mean(axis=(1, 3))
        straight = np.where(a[..., None] > 1e-6, rgb / np.maximum(a[..., None], 1e-6), 0)
        out = np.concatenate([np.clip(straight, 0, 1), a[..., None]], axis=-1)
        return (out * 255 + 0.5).astype(np.uint8)


# ───────────────────────── 합성(비교판용) ─────────────────────────
def over(dst, src, x, y):
    """dst(RGBA uint8) 위 (x,y)에 src(RGBA uint8) 를 얹는다. 둘 다 곧은 알파."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, W), min(y + h, H)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x].astype(float) / 255
    d = dst[y0:y1, x0:x1].astype(float) / 255
    sa = s[..., 3:4]
    da = d[..., 3:4]
    oa = sa + da * (1 - sa)
    oc = np.where(oa > 1e-6, (s[..., :3] * sa + d[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6), 0)
    dst[y0:y1, x0:x1] = (np.concatenate([oc, oa], -1) * 255 + 0.5).astype(np.uint8)


def fill_rect(dst, x, y, w, h, color):
    c = (np.array(list(color) + [1.0][:4 - len(color)]) * 255).astype(np.uint8)
    over(dst, np.broadcast_to(c, (h, w, 4)).copy(), x, y)


def resize(img, w, h):
    """상자 평균(줄이기) / 최근접(늘리기). 곧은 알파는 미리 곱해서 평균."""
    H, W = img.shape[:2]
    f = img.astype(float) / 255
    f[..., :3] *= f[..., 3:4]
    if w < W:
        k = W // w
        assert W % w == 0 and H % h == 0 and W // w == H // h, "정수배로만 줄인다"
        f = f.reshape(h, k, w, k, 4).mean(axis=(1, 3))
    else:
        ys = (np.arange(h) * H // h)
        xs = (np.arange(w) * W // w)
        f = f[ys][:, xs]
    a = f[..., 3:4]
    f[..., :3] = np.where(a > 1e-6, f[..., :3] / np.maximum(a, 1e-6), 0)
    return (np.clip(f, 0, 1) * 255 + 0.5).astype(np.uint8)
