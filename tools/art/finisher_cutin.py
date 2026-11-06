# -*- coding: utf-8 -*-
"""
FINISHER / PIN! 컷인 시안 (2026-11-06). 블렌더 글꼴 렌더로 글자 마스크를 얻어 numpy 로 합성한다.

  돌리기: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/art/finisher_cutin.py
  결과:   art/ui/finisher_cutin.png, art/ui/pin_cutin.png  (1280x720 시안 — 게임에서는 TextLabel 로 그린다. 사양은 art/ui/컷인_사양.md)

시안 글꼴은 설치된 Times New Roman Bold(로블록스 Enum.Font.Bodoni 와 같은 '굵기 대비 큰 세리프')와
맑은 고딕(부제). 실제 게임 글꼴은 사양서 참조.
"""
import os
import sys

import bpy
import numpy as np

ROOT = r"C:\PROJECT-EDIT(by roblox)"
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
from artlib import Canvas, hexrgb, write_png, over  # noqa: E402

OUT = os.path.join(ROOT, "art", "ui")
SERIF = r"C:\Windows\Fonts\timesbd.ttf"
GOTHIC = r"C:\Windows\Fonts\malgun.ttf"
TMP = os.path.join(os.environ.get("TEMP", "."), "cutin_mask.png")


def text_mask(text, font_path, em_px, spacing=1.0):
    """글자 알파 마스크(위가 위인 float 배열)"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    curve = bpy.data.curves.new("t", "FONT")
    curve.body = text
    curve.font = bpy.data.fonts.load(font_path)
    curve.align_x = "CENTER"
    curve.space_character = spacing
    obj = bpy.data.objects.new("t", curve)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    xs = [v[0] for v in obj.bound_box]
    ys = [v[1] for v in obj.bound_box]
    pad = 0.15
    w, h = max(xs) - min(xs) + pad * 2, max(ys) - min(ys) + pad * 2
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(w, h)
    cam.location = (cx, cy, 5)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = int(w * em_px)
    scene.render.resolution_y = int(h * em_px)
    cam.data.ortho_scale = w  # 가로 기준
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (1, 1, 1)
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = TMP
    scene.display_settings.display_device = "sRGB"
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(TMP)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    return px[::-1, :, 3]


def dilate(m, r):
    out = m.copy()
    n = int(np.ceil(r))
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            if dx * dx + dy * dy <= r * r:
                out = np.maximum(out, np.roll(np.roll(m, dy, 0), dx, 1))
    return out


def blend(canvas, rgb, mask, x, y, alpha=1.0):
    """canvas float(H,W,3) 위 (x,y)에 단색/그라디언트 rgb 를 mask 모양으로"""
    h, w = mask.shape
    reg = canvas[y:y + h, x:x + w]
    a = (mask * alpha)[..., None]
    reg[:] = reg * (1 - a) + rgb * a


def vgrad(h, w, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    return np.array(top) * (1 - t) + np.array(bottom) * t + np.zeros((h, w, 3))


def background(W, H):
    c = Canvas(W, H, ss=1)
    base = np.stack([hexrgb("#0b1022"), hexrgb("#04050a")])
    c.paint(c.box(0, 0, 2, 2), base)
    c.glow(0, 0.35, 1.2, hexrgb("#3a2f6a"), 0.5)
    rng = np.random.RandomState(4)
    for _ in range(140):
        x, y = rng.uniform(-1.7, 1.7), rng.uniform(-1, 1)
        c.paint(c.circle(x, y, rng.uniform(0.003, 0.009)), hexrgb("#dfe8ff"), rng.uniform(0.2, 0.9))
    # 판(3x6 격자 느낌의 바닥)
    for i in range(7):
        c.paint(c.seg(-1.1 + i * 0.37, 0.45, -1.4 + i * 0.56, 1.0, 0.004), hexrgb("#7a86b8"), 0.4)
    for j in range(4):
        y = 0.45 + j * 0.18
        c.paint(c.seg(-1.7, y, 1.7, y, 0.004), hexrgb("#7a86b8"), 0.35)
    return c.result()[..., :3].astype(np.float32) / 255.0


def compose(path, title, sub, title_fill, title_stroke, sub_color, band_line):
    W, H = 1280, 720
    img = background(W, H)
    band_y, band_h = 100, 190
    # 검은 띠
    reg = img[band_y:band_y + band_h]
    reg[:] = reg * 0.12
    for yy in (band_y, band_y + band_h - 3):
        img[yy:yy + 3, :] = band_line
    # 제목
    tm = text_mask(title, SERIF, 150, spacing=1.12)
    th, tw = tm.shape
    ox, oy = (W - tw) // 2, band_y + 22
    r = 5
    padded = np.pad(tm, r + 2)
    stroke = dilate(padded, r)
    blend(img, np.array([0, 0, 0]), np.clip(dilate(padded, r + 5) * 0.6, 0, 1), ox - r - 2, oy - r - 2)  # 그림자
    blend(img, np.array(title_stroke), stroke, ox - r - 2, oy - r - 2)
    grad = vgrad(padded.shape[0], padded.shape[1], title_fill[0], title_fill[1])
    reg = img[oy - r - 2:oy - r - 2 + padded.shape[0], ox - r - 2:ox - r - 2 + padded.shape[1]]
    a = padded[..., None]
    reg[:] = reg * (1 - a) + grad * a
    # 부제
    sm = text_mask(sub, GOTHIC, 44, spacing=1.35)
    sh, sw = sm.shape
    sx, sy = (W - sw) // 2, band_y + band_h - sh - 16
    sp = np.pad(sm, 3)
    blend(img, np.array([0, 0, 0]), np.clip(dilate(sp, 2.5), 0, 1), sx - 3, sy - 3)
    blend(img, np.array(sub_color), sp, sx - 3, sy - 3)
    rgba = np.concatenate([img, np.ones((H, W, 1), np.float32)], -1)
    write_png(path, (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8))
    print("[cutin]", path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    compose(os.path.join(OUT, "finisher_cutin.png"), "FINISHER", "빈 별자리 · KENOS ASTERISMOS",
            (hexrgb("#ffffff"), hexrgb("#a9b4c8")), hexrgb("#e0b84c"), hexrgb("#d7deea"), hexrgb("#c9a24a"))
    compose(os.path.join(OUT, "pin_cutin.png"), "PIN!", "핀 성공 · PIN FALL",
            (hexrgb("#fff3b0"), hexrgb("#e0a92c")), hexrgb("#6a4608"), hexrgb("#f4e3a8"), hexrgb("#c9a24a"))
