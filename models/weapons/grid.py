# -*- coding: utf-8 -*-
"""grid.py — 렌더 PNG 여러 장을 cols 열 격자로 묶는다(무기 확인용).
  blender -b -P models/weapons/grid.py -- <출력.png> <열 수> <입력...>"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, cols, inputs = args[0], int(args[1]), args[2:]
imgs = []
for p in inputs:
    im = bpy.data.images.load(p)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    imgs.append(a.reshape(h, w, 4))
cw = max(a.shape[1] for a in imgs)
ch = max(a.shape[0] for a in imgs)
rows = (len(imgs) + cols - 1) // cols
sheet = np.full((rows * ch, cols * cw, 4), 0.2, dtype=np.float32)
sheet[..., 3] = 1
for i, a in enumerate(imgs):
    r, c = divmod(i, cols)
    h, w = a.shape[:2]
    y0 = (rows - 1 - r) * ch  # 블렌더 픽셀은 아래 줄부터
    sheet[y0:y0 + h, c * cw:c * cw + w] = a
img = bpy.data.images.new("grid", cols * cw, rows * ch, alpha=False)
img.pixels.foreach_set(sheet.ravel())
img.filepath_raw = out
img.file_format = "PNG"
img.save()
print("격자", out, cols * cw, rows * ch)
