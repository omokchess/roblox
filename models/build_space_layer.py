# -*- coding: utf-8 -*-
"""
build_space_layer.py — 칼리스토 2·3페이즈 '우주를 담은 몸'에 깔 우주 그림(2026-11-01).
사용자: "우주를 담은 느낌은 모델링보다 레이어 같은 걸 이용해서 특정 공간에 우주 이미지 자체를 갖다 때려박은 느낌".

이음매 없는 1024² 성운 그림(numpy FFT 잡음 — 타일로 이어 깔아도 경계가 안 보인다):
  깊은 남색 바탕 · 보라/파랑/자홍 성운 구름과 가는 실(능선 잡음) · 작은 별 수천(밝기 거듭제곱 분포) · 큰 별 몇(빛무리 + 십자 빛살).
→ models/callisto_tex/SpaceLayer.png, 스튜디오 업로드용 판 하나 models/CallistoSpaceLayer.glb(이 그림을 입힌 1×1 판 — 가져오면 그림이 올라간다).
스튜디오: GLB 가져오기 → tools/Callisto_SpaceLayer.luau 가 그림 주소를 ReplicatedStorage.CallistoAssets 속성 SpaceLayerImage 로 옮긴다.
돌리기: blender -b -P models/build_space_layer.py
"""
import math
import os

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TEXDIR = os.path.join(HERE, "callisto_tex")
os.makedirs(TEXDIR, exist_ok=True)
N = 1024


def band(n, f0, bw, seed):
    r = np.random.default_rng(seed)
    F = np.fft.fft2(r.standard_normal((n, n)))
    f = np.fft.fftfreq(n) * n
    k = np.sqrt(f[:, None] ** 2 + f[None, :] ** 2)
    out = np.real(np.fft.ifft2(F * np.exp(-((k - f0) / bw) ** 2)))
    return (out - out.mean()) / (out.std() + 1e-9)


def fbm(n, f0, seed, octaves=5, gain=0.55):
    s, a, t = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * band(n, f0 * 2 ** o, f0 * 2 ** o * 0.6, seed + o * 7)
        t += a
        a *= gain
    return s / t


def C(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def stamp(img, x, y, rad, col, cross=0.0):
    """이음매 없이(감싸며) 빛 점 하나 + 십자 빛살."""
    r = int(math.ceil(rad * 6 + cross * 18)) + 1
    ys = (np.arange(-r, r + 1) + int(y)) % N
    xs = (np.arange(-r, r + 1) + int(x)) % N
    dy = (np.arange(-r, r + 1) + int(y) - y)[:, None]
    dx = (np.arange(-r, r + 1) + int(x) - x)[None, :]
    d2 = dx * dx + dy * dy
    v = np.exp(-d2 / (2 * rad * rad)) + 0.1 * np.exp(-d2 / (2 * (rad * 2.4) ** 2))
    if cross > 0:
        v = v + cross * (np.exp(-(dy * dy) / 0.35) * np.exp(-np.abs(dx) / (rad * 6)) + np.exp(-(dx * dx) / 0.35) * np.exp(-np.abs(dy) / (rad * 6)))
    img[np.ix_(ys, xs)] += v[:, :, None] * col[None, None, :]


def make_image():
    base = fbm(N, 2, 1, 3)
    img = (C(5, 5, 16)[None, None, :] * (1 - smoothstep(-1, 1.5, base))[:, :, None]
           + C(16, 12, 44)[None, None, :] * smoothstep(-1, 1.5, base)[:, :, None])
    # 성운: 큰 구름 셋(색마다 다른 잡음) × 밝기 · 가는 실
    for seed, col, gain, lo in ((11, C(126, 72, 228), 0.75, 0.2), (23, C(52, 112, 236), 0.7, 0.35), (37, C(214, 82, 172), 0.55, 0.65)):
        cloud = smoothstep(lo, lo + 1.6, fbm(N, 2.5, seed, 6))
        detail = 0.6 + 0.4 * smoothstep(-1.2, 1.4, fbm(N, 10, seed + 3, 4))
        img += col[None, None, :] * (cloud * detail * gain)[:, :, None]
    fil = (1 - np.abs(band(N, 4, 2, 51))) ** 3 * smoothstep(0.0, 1.4, fbm(N, 3, 52, 4))
    img += C(170, 140, 255)[None, None, :] * (fil * 0.07)[:, :, None]
    dust = smoothstep(0.4, 1.8, fbm(N, 4, 61, 5))
    img *= (1 - 0.45 * dust)[:, :, None]                                     # 어두운 먼지 띠
    # 별: 작은 별 수천 · 밝은 별 몇(빛무리 + 빛살)
    r = np.random.default_rng(71)
    for _ in range(4200):
        m = r.random() ** 7
        col = C(255, 255, 255) * (0.25 + 1.6 * m)
        tint = r.random()
        if tint < 0.18:
            col = col * C(170, 205, 255) / C(255, 255, 255).max()
        elif tint < 0.26:
            col = col * C(255, 220, 160) / C(255, 255, 255).max()
        stamp(img, r.random() * N, r.random() * N, 0.55 + 0.6 * m, col)
    for _ in range(14):
        col = [C(210, 230, 255), C(255, 236, 200), C(200, 190, 255)][int(r.random() * 3)]
        stamp(img, r.random() * N, r.random() * N, 0.9 + 0.5 * r.random(), col * 0.9, cross=0.5 + 0.3 * r.random())
    img = 1 - np.exp(-img * 1.35)                                            # 부드러운 톤 매핑(밝은 곳이 하얗게 뭉개지지 않게)
    return np.clip(img, 0, 1).astype(np.float32)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arr = make_image()
    im = bpy.data.images.new("SpaceLayer", N, N, alpha=False)
    im.pixels.foreach_set(np.concatenate([arr, np.ones((N, N, 1), np.float32)], 2).ravel())
    im.filepath_raw = os.path.join(TEXDIR, "SpaceLayer.png")
    im.file_format = "PNG"
    im.save()
    # 업로드용 판(그림을 입힌 1×1)
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((-0.5, 0, -0.5), (0.5, 0, -0.5), (0.5, 0, 0.5), (-0.5, 0, 0.5))]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.verify()
    for lp, t in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        lp[uv].uv = t
    me = bpy.data.meshes.new("CallistoSpaceLayer")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("CallistoSpaceLayer", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("SpaceLayer")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = im
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    me.materials.append(mat)
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERE, "CallistoSpaceLayer.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_texcoords=True)
    print("SpaceLayer.png + CallistoSpaceLayer.glb")


main()
