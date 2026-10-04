# -*- coding: utf-8 -*-
"""
wall_profile.py — 2026-10-04. 벽 밑 바위 줄의 높이 곡선(자연 마모) — Luau(wallPillars) 와 같은 셈을 파이썬으로 그려 본다.

사용자: "커다란 돌 구조가 띄엄띄엄, 그 사이를 중간·작은 돌이 채우고, 블록 가운데 가장 높은 점을 이으면 불규칙한 곡선 —
         자연적으로 마모된 느낌. 맵은 네모(직육면체). 파동함수처럼 너무 극적이면 안 됨."
곡선 = 1차원 fBm(fractional Brownian motion): 매끈한 값 잡음(value noise, 격자마다 해시로 높이, 사이는 smoothstep 보간)을
  파장 80·34·14 세 겹, 세기 1·0.4·0.15(지속도 ≈ 0.4 — 지형 생성에 흔히 쓰는 0.5 보다 조금 잔잔하게)로 더해 0~1 로 맞춘다.
  → 큰 굽이는 한 벽에 한두 번, 그 위에 잔물결. 사인파처럼 같은 간격으로 오르내리지 않는다.
블록: 곡선이 높은 마루 근처는 넓고 깊은 큰 바위(띄엄띄엄), 그 밖은 중간·작은 바위가 메운다. 블록 윗면 가운데 = 곡선 위 점.
돌리기: python tools/wall_profile.py → tools/wall_profile.png (벽 넷 예시)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def hash1(i, seed):
    v = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return v - math.floor(v)


def vnoise(x, seed):
    i = math.floor(x)
    t = x - i
    t = t * t * (3 - 2 * t)
    return hash1(i, seed) * (1 - t) + hash1(i + 1, seed) * t


OCT = [(80.0, 1.0), (34.0, 0.4), (14.0, 0.15)]


def profile(s, seed):
    total, norm = 0.0, 0.0
    for k, (wl, amp) in enumerate(OCT):
        total += amp * vnoise(s / wl + k * 17.31, seed + k * 3.7)
        norm += amp
    return total / norm  # 0~1 (대개 0.25~0.75)


def frac(s, seed):
    """벽 높이에 대한 블록 높이 비(0.28~0.95)"""
    p = profile(s, seed)
    t = min(1, max(0, (p - 0.12) / 0.76))
    t = t * t * (3 - 2 * t)  # 부드러운 끝(잘린 평평한 마루·골 없이 둥글게 눕는다)
    return 0.22 + 0.73 * t


def blocks_along(a0, a1, seed, dens=1.0):
    """[(시작, 끝, 높이비, 깊이, 종류)] — Luau wallPillars 와 같은 규칙"""
    out = []
    cur = a0 + 1
    n = 0
    while cur < a1 - 2:
        n += 1
        r = hash1(n * 7 + 3, seed)
        h_here = frac(cur + 4, seed)
        slope = abs(frac(cur + 9, seed) - frac(cur - 1, seed))
        if h_here > 0.72 and slope < 0.08:
            w, d, kind = 20 + r * 10, 7.5 + r * 2.5, "큰"
        elif h_here > 0.5:
            w, d, kind = 11 + r * 6, 5 + r * 2, "중"
        else:
            w, d, kind = 6 + r * 4, 3.5 + r * 1.5, "작"
        w = min(w, a1 - cur + 1)
        hf = frac(cur + w / 2, seed)
        skip = kind == "작" and hash1(n * 5 + 1, seed) < (1 - dens) * 0.9
        if not skip:
            out.append((cur, cur + w, hf, d, kind))
        cur += w - 0.8
    return out


if __name__ == "__main__":
    from plan_png import Canvas
    L, H = 300, 40
    C = Canvas(0, 0, L, 4 * (H + 12), 3.0)
    C.rect(0, 0, L, 4 * (H + 12), "#f4ead6")
    for row, (seed, dens) in enumerate([(1.3, 1.0), (7.9, 0.6), (13.1, 0.85), (21.7, 0.35)]):
        base = row * (H + 12) + H + 6
        C.rect(0, base - H, L, base, "#c98a5c", 0.25)  # 벽
        for s0, s1, hf, d, kind in blocks_along(0, L, seed, dens):
            col = {"큰": "#8a4a28", "중": "#b5653a", "작": "#d58a58"}[kind]
            C.rect(s0, base - H * hf, s1, base, col, 0.9)
        prev = None
        for i in range(0, L * 2 + 1):
            s = i / 2
            y = base - H * frac(s, seed)
            if prev:
                C.line(prev[0], prev[1], s, y, 0.5, "#1a1a1a")
            prev = (s, y)
        for s0, s1, hf, d, kind in blocks_along(0, L, seed, dens):
            C.circle((s0 + s1) / 2, base - H * hf, 0.9, "#ffffff")
    C.save(os.path.join(HERE, "wall_profile.png"))
    print("ok")
