# -*- coding: utf-8 -*-
"""
카드 그림 견본 3장 + 지금 그림과의 비교판 (2026-11-06).

  돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" tools/art/card_samples.py
  결과:   art/cards/sample_Duelist_R_Bloodletting.png, sample_Alchemist_R_Napalm.png, sample_WallPilgrim_R_DeepNail.png (512x512)
          art/cards/_compare.png  (위: 지금 생성기 그림, 아래: 견본, 맨 아래: 손 안 실제 크기 128px)

지금 그림은 tools/card_art/preview/art.json (build.py 가 만든 도형 목록)을 CardArt.luau 규칙대로 다시 그려 얻는다.
"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from artlib import Canvas, INK, WHITE, dark, hexrgb, light, mix, over, resize, write_png, fill_rect  # noqa: E402

OUT = os.path.join(ROOT, "art", "cards")
U = Canvas.U

# 등급 색 (CardView.GRADE_STYLE 과 같다)
GRADE = {
    "Common": dict(fill=(58, 60, 70), edge=(170, 172, 186)),
    "Rare": dict(fill=(38, 74, 150), edge=(120, 175, 255)),
    "Essential": dict(fill=(96, 52, 154), edge=(214, 160, 255)),
}


def rgb255(t):
    return np.array(t) / 255.0


# ───────────────────────── 지금 그림 다시 그리기 ─────────────────────────
def render_current(card_id, grade, size=512):
    art = {a["Id"]: a for a in json.load(open(os.path.join(ROOT, "tools", "card_art", "preview", "art.json"), encoding="utf-8"))}[card_id]
    back = {"Common": (78, 80, 88), "Rare": (38, 74, 150), "Essential": (96, 52, 154)}[grade]
    rims = {"Common": 1, "Rare": 2, "Essential": 2}[grade]
    c = Canvas(size, ss=2)
    c.paint(c.box(0, 0, 1, 1), rgb255(back))
    M, INSET = 0.78, 0.78 * 0.94

    def frame(x, y, w, h, rot, color, corner, stroke, tr):
        cx, cy = (x - 0.5) * 2, (y - 0.5) * 2
        hw, hh = w, h  # 0~1 폭 → 설계 단위 반폭 = w
        with c.at(rot, cx, cy):
            r = corner * min(hw, hh) * 2
            d = c.box(0, 0, hw, hh, min(r, min(hw, hh)))
            if stroke > 0:
                t = max(stroke * 2, 1.0 / size * 2)
                d = np.abs(d - t / 2) - t / 2
            return d, color, 1 - tr

    layers = []
    if grade == "Essential":
        for i in range(8):
            layers.append((i, 1, frame(0.5, 0.5, 0.05, 1.16, i / 8 * 180, WHITE, 0.5, 0, 0.78)))
    layers.append((2, 2, frame(0.5, 0.5, M + 0.06, M + 0.06, 0, WHITE, 0.5, 0, 0.72)))
    layers.append((3, 3, frame(0.5, 0.5, M, M, 0, back_scale(back, 0.55), 0.5, 0, 0)))
    for i in range(rims):
        sz = M + 0.02 - i * 0.12
        layers.append((4, 4, frame(0.5, 0.5, sz, sz, 0, WHITE, 0.5, 0.022, 0 if i == 0 else 0.55)))
    for s in art["Shapes"]:
        x = 0.5 + (s["X"] - 0.5) * INSET
        y = 0.5 + (s["Y"] - 0.5) * INSET
        st = s["Stroke"] * INSET if s["Stroke"] > 0 else 0
        layers.append((10, s["ZIndex"] + 10, frame(x, y, s["W"] * INSET, s["H"] * INSET, s["Rotation"], hexrgb(s["Color"]), s["Corner"], st, s["Transparency"])))
    layers.sort(key=lambda t: t[1])
    for _, _, (d, col, a) in layers:
        c.paint(d, col, a)
    return c.result()


def back_scale(b, k):
    return rgb255(b) * k


# ───────────────────────── 새 양식 공통 ─────────────────────────
def scene(c, grade, tint, glow_at=(0, -0.05), seed=1):
    """어두운 우주 바탕 + 직업색 빛 + 별가루 + 등급 테두리."""
    g = GRADE[grade]
    f = c.box(0, 0, 0.97, 0.97, 0.14)
    base = mix(hexrgb("#070912"), tint, 0.18)
    c.paint(f, np.stack([mix(base, tint, 0.28), base, hexrgb("#05060c")]) [[0, 2]])
    c.glow(glow_at[0], glow_at[1], 1.15, tint, 0.55)
    c.glow(glow_at[0], glow_at[1], 0.55, mix(tint, WHITE, 0.35), 0.35)
    rng = np.random.RandomState(seed)
    for _ in range(46):
        x, y = rng.uniform(-0.9, 0.9, 2)
        r = rng.uniform(0.006, 0.016)
        c.paint(c.circle(x, y, r), mix(WHITE, tint, 0.3), rng.uniform(0.25, 0.8))
    for _ in range(5):
        x, y = rng.uniform(-0.8, 0.8, 2)
        c.paint(c.poly([(x, y - 0.04), (x + 0.012, y - 0.012), (x + 0.04, y), (x + 0.012, y + 0.012), (x, y + 0.04), (x - 0.012, y + 0.012), (x - 0.04, y), (x - 0.012, y - 0.012)]), WHITE, 0.7)
    # 비네팅
    d = np.hypot(c.X0, c.Y0)
    a = np.clip((d - 0.7) / 0.9, 0, 1) ** 1.5 * 0.55
    c.rgb = c.rgb * (1 - a[..., None]) + INK * a[..., None] * c.a[..., None]
    return f


def finish(c, f, grade):
    """등급 테두리(바깥 윤곽 + 등급색 띠). 투명 모서리를 둥글게 자른다."""
    g = GRADE[grade]
    edge = rgb255(g["edge"])
    c.paint(np.abs(f + 0.035) - 0.026, np.stack([light(edge, 0.4), dark(edge, 0.35)]))
    c.paint(np.abs(f + 0.085) - 0.008, edge, 0.35)
    c.mask_to(f)


def shade_solid(c, d, col, ow=0.03, rim=0.5):
    """윤곽 + 면 + 위쪽 림 라이트(면을 위로 조금 밀어 낸 뒤 겹쳐 가장자리만 밝힘)."""
    c.solid(d, col, ow=ow)


def blood_drop(c, cx, cy, s, M):
    base = [(0, -0.68), (0.14, -0.38), (0.34, -0.05), (0.40, 0.2), (0.30, 0.46), (0, 0.6),
            (-0.30, 0.46), (-0.40, 0.2), (-0.34, -0.05), (-0.14, -0.38)]
    d = c.blob([(cx + x * s, cy + y * s) for x, y in base])
    c.solid(d, M, ow=0.022)
    c.paint(c.seg(cx - 0.18 * s, cy + 0.15 * s, cx - 0.18 * s, cy + 0.38 * s, 0.05 * s), light(M, 0.8), 0.85)


def flame(c, cx, cy, s, col, ow=0.03):
    base = [(0.05, -0.74), (0.2, -0.45), (0.38, -0.15), (0.44, 0.18), (0.32, 0.48), (0.0, 0.62),
            (-0.32, 0.48), (-0.44, 0.18), (-0.36, -0.08), (-0.2, -0.22), (-0.16, -0.45)]
    d = c.blob([(cx + x * s, cy + y * s) for x, y in base])
    c.solid(d, col, ow=ow)


# ───────────────────────── 견본 1: 방혈 (결투사 · 희귀) ─────────────────────────
def sample_bloodletting(size=512):
    c = Canvas(size, ss=3)
    tint = hexrgb("#d83a4a")
    f = scene(c, "Rare", tint, glow_at=(0.1, 0.35), seed=3)
    steel = hexrgb("#aebccb")
    red = hexrgb("#c4202f")
    # 바닥 핏물 웅덩이와 파문
    c.paint(c.ellipse(0.18, 0.66, 0.62, 0.13), dark(red, 0.5), 0.9)
    c.paint(c.ellipse(0.18, 0.66, 0.5, 0.09), red, 0.95)
    c.paint(np.abs(c.ellipse(0.18, 0.66, 0.3, 0.052)) - 0.008, light(red, 0.5), 0.9)
    c.paint(np.abs(c.ellipse(0.18, 0.66, 0.16, 0.028)) - 0.007, light(red, 0.6), 0.8)
    # 레이피어(끝이 아래, 살짝 기울임)
    with c.at(-16, 0.02, -0.02):
        blade_l = c.poly([(0, 0.62), (0.0, -0.36), (-0.045, -0.36)])
        blade_r = c.poly([(0, 0.62), (0.0, -0.36), (0.045, -0.36)])
        c.paint(U(blade_l, blade_r) - 0.03, INK, 0.95)
        c.paint(blade_l, light(steel, 0.55))
        c.paint(blade_r, dark(steel, 0.3))
        # 칼날 위 핏자국
        c.paint(c.poly([(0, 0.62), (0.012, 0.3), (0.03, 0.26), (0.045 * 0.6, 0.18), (0.0, 0.14)]), red)
        # 귀 (컵 가드)
        guard = U(c.arc(0, -0.4, 0.28, 0, 180, 0.075), c.seg(-0.32, -0.4, 0.32, -0.4, 0.045))
        c.solid(guard, mix(steel, hexrgb("#d9b25a"), 0.7))
        c.solid(c.box(0, -0.58, 0.04, 0.12, 0.02), hexrgb("#5b2a30"))
        c.solid(c.circle(0, -0.74, 0.07), mix(steel, hexrgb("#d9b25a"), 0.7), ow=0.025)
    # 떨어지는 핏방울
    blood_drop(c, 0.12, 0.34, 0.2, red)
    blood_drop(c, 0.26, 0.5, 0.13, red)
    blood_drop(c, -0.25, 0.46, 0.09, light(red, 0.1))
    # 튀는 핏방울들
    for (x, y, r) in ((0.62, 0.56, 0.028), (0.52, 0.48, 0.02), (-0.2, 0.6, 0.02), (0.78, 0.7, 0.02)):
        c.paint(c.circle(x, y, r), light(red, 0.2))
    finish(c, f, "Rare")
    return c.result()


# ───────────────────────── 견본 2: 네이팜 (연금술사 · 희귀) ─────────────────────────
def sample_napalm(size=512):
    c = Canvas(size, ss=3)
    tint = hexrgb("#ff8a2a")
    f = scene(c, "Rare", tint, glow_at=(0.0, -0.15), seed=7)
    glass = hexrgb("#9fd4e6")
    liquid = hexrgb("#ff9a2e")
    # 바닥 불바다
    c.glow(0, 0.7, 0.9, hexrgb("#ff6a1a"), 0.5)
    for (x, s) in ((-0.5, 0.2), (-0.25, 0.28), (0.3, 0.3), (0.55, 0.2)):
        flame(c, x, 0.68, s, hexrgb("#e8501c"), ow=0.025)
    with c.at(-14, -0.02, 0.2):
        body = c.box(0, 0.2, 0.38, 0.4, 0.2)
        neck = c.box(0, -0.38, 0.13, 0.2, 0.04)
        shoulder = c.poly([(-0.38, -0.12), (-0.13, -0.3), (0.13, -0.3), (0.38, -0.12), (0.38, 0.1), (-0.38, 0.1)])
        bottle = U(body, neck, shoulder)
        c.paint(bottle - 0.03, INK, 0.95)
        c.paint(bottle, np.stack([light(glass, 0.3), dark(glass, 0.35)]), 0.95)
        liq = c.inter(bottle + 0.045, c.box(0, 0.37, 0.5, 0.33))
        c.paint(liq, np.stack([light(liquid, 0.35), dark(liquid, 0.1)]))
        c.paint(c.box(0, 0.05, 0.31, 0.012), light(liquid, 0.7), 0.9)  # 액면 반짝
        for (x, y, r) in ((-0.15, 0.3, 0.035), (0.1, 0.42, 0.045), (0.18, 0.22, 0.025), (-0.05, 0.5, 0.03)):
            c.paint(np.abs(c.circle(x, y, r)) - 0.008, light(liquid, 0.8), 0.85)
        # 유리 하이라이트
        c.paint(c.seg(-0.28, 0.0, -0.28, 0.46, 0.028), WHITE, 0.7)
        c.paint(c.seg(-0.28, -0.1, -0.2, -0.2, 0.02), WHITE, 0.7)
        c.paint(c.seg(0.27, 0.12, 0.27, 0.3, 0.014), WHITE, 0.5)
        # 마개 + 헝겊
        c.solid(c.box(0, -0.6, 0.12, 0.05, 0.02), hexrgb("#8a5a34"), ow=0.025)
        c.solid(c.blob([(0, -0.62), (0.06, -0.7), (0.1, -0.78), (0.02, -0.76), (-0.02, -0.7), (-0.08, -0.74), (-0.06, -0.66)]), hexrgb("#d9cfae"), ow=0.02)
        # 불길
        flame(c, 0.0, -0.84, 0.38, hexrgb("#ff6a1c"))
        flame(c, 0.02, -0.8, 0.23, hexrgb("#ffc43a"), ow=0.02)
        flame(c, 0.03, -0.77, 0.11, hexrgb("#fff4b0"), ow=0.0)
    # 불씨
    rng = np.random.RandomState(5)
    for _ in range(16):
        x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.95, -0.2)
        c.paint(c.circle(x, y, rng.uniform(0.01, 0.022)), hexrgb("#ffd36a"), rng.uniform(0.5, 1))
    finish(c, f, "Rare")
    return c.result()


# ───────────────────────── 견본 3: 깊은 못 (월 필그림 · 희귀) ─────────────────────────
def sample_deepnail(size=512):
    c = Canvas(size, ss=3)
    tint = hexrgb("#b07bff")
    f = scene(c, "Rare", tint, glow_at=(0.0, 0.0), seed=11)
    stone = hexrgb("#b9b3a8")
    # 돌벽 정면
    wall = c.box(0, 0.02, 0.82, 0.78, 0.07)
    c.paint(wall - 0.03, INK, 0.95)
    c.paint(wall, np.stack([light(stone, 0.2), dark(stone, 0.5)]))
    # 돌 줄눈
    for y in (-0.25, 0.28):
        c.paint(c.box(0, y, 0.82, 0.012), dark(stone, 0.6), 0.8)
    for (x, y0, y1) in ((-0.4, -0.8, -0.25), (0.35, -0.25, 0.28), (-0.2, 0.28, 0.8), (0.5, 0.28, 0.8), (0.1, -0.8, -0.25)):
        c.paint(c.seg(x, y0, x, y1, 0.012), dark(stone, 0.6), 0.8)
    # 못 머리 주변 빛 고리 (광신)
    c.glow(0, 0.02, 0.62, tint, 0.9)
    for r, a in ((0.46, 0.55), (0.6, 0.3)):
        c.paint(np.abs(c.circle(0, 0.02, r)) - 0.01, mix(tint, WHITE, 0.5), a)
    # 금
    rng = np.random.RandomState(2)
    for k in range(9):
        t = k / 9 * 2 * np.pi + 0.3
        pts = [(0.0, 0.02)]
        ang = t
        r = 0.2
        for _ in range(4):
            ang += rng.uniform(-0.35, 0.35)
            r += rng.uniform(0.1, 0.18)
            pts.append((r * np.cos(ang), 0.02 + r * np.sin(ang)))
        pts = [(x, y) for x, y in pts]
        inside = wall + 0.04
        c.paint(c.inter(c.line(pts, 0.016), inside), INK, 0.95)
        c.paint(c.inter(c.line(pts, 0.006), inside), mix(tint, WHITE, 0.4), 0.6)
    # 못: 정면에서 본 큰 머리 + 둘레 빛, 위쪽으로 그림자 길이감
    head = c.circle(0, 0.02, 0.2)
    rust = hexrgb("#6d5a4a")
    nail_steel = hexrgb("#8d94a3")
    c.paint(c.circle(0.03, 0.06, 0.24), INK, 0.55)
    c.solid(head, np.stack([light(nail_steel, 0.35), dark(nail_steel, 0.35)]), ow=0.035, grad=False)
    c.paint(np.abs(c.circle(0, 0.02, 0.15)) - 0.012, dark(nail_steel, 0.5), 0.8)
    c.paint(c.circle(0, 0.02, 0.12), np.stack([light(nail_steel, 0.1), dark(nail_steel, 0.2)]))
    c.paint(c.circle(-0.07, -0.05, 0.035), WHITE, 0.85)
    # 부서진 돌조각
    for (x, y, s, rot) in ((-0.48, -0.42, 0.07, 20), (0.46, -0.36, 0.06, -30), (0.5, 0.4, 0.08, 40), (-0.45, 0.46, 0.06, 10), (0.62, 0.1, 0.045, 0)):
        with c.at(rot, x, y):
            c.solid(c.poly([(-s, -s * 0.6), (s * 0.8, -s), (s, s * 0.7), (-s * 0.5, s)]), light(stone, 0.1), ow=0.02)
    finish(c, f, "Rare")
    return c.result()


SAMPLES = [
    ("Duelist_R_Bloodletting", "방혈", "Rare", sample_bloodletting),
    ("Alchemist_R_Napalm", "네이팜", "Rare", sample_napalm),
    ("WallPilgrim_R_DeepNail", "깊은 못", "Rare", sample_deepnail),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    pad = 20
    S = 320
    W = pad + 3 * (S + pad)
    H = pad + (S + pad) * 2 + (128 + pad)
    sheet = np.zeros((H, W, 4), np.uint8)
    sheet[...] = (18, 20, 30, 255)
    for i, (cid, name, grade, fn) in enumerate(SAMPLES):
        print("[card]", cid, name)
        new = fn(512)
        write_png(os.path.join(OUT, "sample_%s.png" % cid), new)
        cur = render_current(cid, grade, 512)
        x = pad + i * (S + pad)
        # 카드 그림 칸은 가로로 긴 틀 + 중앙 정사각. 견본은 정사각 그대로 보인다.
        over(sheet, rs(cur, S), x, pad)
        over(sheet, rs(new, S), x, pad + S + pad)
        # 손 안 실제 크기(대략 128px)
        y3 = pad + (S + pad) * 2
        over(sheet, rs(cur, 128), x, y3)
        over(sheet, rs(new, 128), x + 128 + 24, y3)
    write_png(os.path.join(OUT, "_compare.png"), sheet)
    print("[card] 비교판", os.path.join(OUT, "_compare.png"))


def rs(img, n):
    """512 → n (정수배가 아니면 한 번 거쳐서)"""
    if img.shape[0] % n == 0:
        return resize(img, n, n)
    # 512 → 320: 최근접이 거칠므로 640 으로 늘렸다가 줄인다
    big = resize(img, 1280, 1280)
    return resize(big, n, n)


if __name__ == "__main__":
    main()
