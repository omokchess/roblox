"""numpy 기반 결정적(seed 고정) 2D 노이즈 — 지형 생성용."""

import numpy as np


class Noise2D:
    def __init__(self, seed=1337):
        rng = np.random.default_rng(seed)
        self.perm = np.concatenate([rng.permutation(256)] * 2).astype(np.int64)
        ang = rng.uniform(0, 2 * np.pi, 256)
        self.gx = np.cos(ang)
        self.gy = np.sin(ang)

    def _grad(self, ix, iy, fx, fy):
        h = self.perm[(self.perm[ix & 255] + iy) & 255]
        return self.gx[h] * fx + self.gy[h] * fy

    def perlin(self, x, y):
        x = np.asarray(x, dtype=np.float64)
        y = np.asarray(y, dtype=np.float64)
        x0 = np.floor(x).astype(np.int64)
        y0 = np.floor(y).astype(np.int64)
        fx = x - x0
        fy = y - y0
        u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
        v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
        n00 = self._grad(x0, y0, fx, fy)
        n10 = self._grad(x0 + 1, y0, fx - 1, fy)
        n01 = self._grad(x0, y0 + 1, fx, fy - 1)
        n11 = self._grad(x0 + 1, y0 + 1, fx - 1, fy - 1)
        nx0 = n00 + u * (n10 - n00)
        nx1 = n01 + u * (n11 - n01)
        return (nx0 + v * (nx1 - nx0)) * 1.4142  # 대략 [-1, 1]

    def fbm(self, x, y, octaves=5, lac=2.0, gain=0.5):
        amp, freq, total, norm = 1.0, 1.0, 0.0, 0.0
        for i in range(octaves):
            total = total + amp * self.perlin(x * freq + i * 17.3, y * freq - i * 9.1)
            norm += amp
            amp *= gain
            freq *= lac
        return total / norm

    def ridged(self, x, y, octaves=4):
        return 1.0 - np.abs(self.fbm(x, y, octaves))


def smoothstep(e0, e1, x):
    if e1 == e0:
        return (np.asarray(x) >= e0).astype(np.float64)
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t
