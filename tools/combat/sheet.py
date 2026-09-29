# -*- coding: utf-8 -*-
"""
sheet.py — 미리보기 PNG 여러 장을 세로로 이어 한 장으로 만든다(한눈에 비교). (2026-09-28)
  blender -b -P tools/combat/sheet.py -- <출력.png> <입력1.png> <입력2.png> ...
너비가 다르면 왼쪽 맞춤, 빈 곳은 회색.
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, inputs = args[0], args[1:]
imgs = []
for p in inputs:
    im = bpy.data.images.load(p)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    imgs.append(a.reshape(h, w, 4))
W = max(a.shape[1] for a in imgs)
gap = 6
H = sum(a.shape[0] for a in imgs) + gap * (len(imgs) - 1)
sheet = np.full((H, W, 4), 0.35, dtype=np.float32)
sheet[..., 3] = 1
y = H
for a in imgs:  # 블렌더 픽셀은 아래 줄부터라 위에서부터 채우려면 거꾸로 쌓는다
    h, w = a.shape[:2]
    y -= h
    sheet[y:y + h, :w] = a
    y -= gap
res = bpy.data.images.new("sheet", W, H, alpha=True)
res.pixels.foreach_set(sheet.ravel())
res.filepath_raw = out
res.file_format = "PNG"
res.save()
print("묶음", out, W, H)
