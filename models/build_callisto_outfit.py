# -*- coding: utf-8 -*-
"""
build_callisto_outfit.py — 히든 보스 칼리스토 복장 4판(2026-11-01). 블렌더 5.2.

사용자(2026-11-01): "검을 들고 있는 의수 방향이 이상해 — 의수를 놓지 말고 그냥 팔을 검으로 하자. 얼굴엔 그냥 가면을 씌워 놓고,
가면도 블렌더로. 전체적인 복장에서 로블록스 느낌이 날 필요는 없으니 최대한 퀄리티 높게. 대신 체형은 로블록스 체형에 맞춰야
입혔을 때 자연스러울 듯. 재질도 진짜 옷 재질처럼."

- 체형: R6 관절 상자(몸통 2×2×1 · 팔·다리 1×2×1 · 고전 머리 지름 1.25)를 감싸는 옷. 관절 부품마다 따로 메시(모션을 따라간다).
  옷을 입으면 몸 부품은 감춘다(Combat/Callisto) — 옷이 몸 모양을 다 만든다(허리 들어감·가슴·둥근 어깨).
- 옷은 매개 곡면(둘레 × 높이 격자)에 주름·체형 변위를 넣고 서브디비전 · 두께(솔리디파이)로 다듬는다.
- 재질: 직접 만든 이음매 없는 PBR 텍스처(models/callisto_tex) — 갈색 도니갈 트위드(헤링본 + 색점), 남색 별무늬 실크 안감,
  흰 포플린 셔츠, 검은 울 능직 바지, 가죽(구두·허리띠·장갑), 스웨이드 팔꿈치 덧댐, 놋쇠·금, 자기 가면(빙렬), 벨벳 끈.
  GLB(glTF PBR)로 내보내면 스튜디오 가져오기가 SurfaceAppearance(색·법선·거칠기·금속)를 만든다.
- 오른팔 = 검: 소매 끝(셔츠 소맷부리)에서 날이 곧장 나온다(무기 CallistoArms Main, 팔 축에 고정 — WeaponDefinitions Fixed).
  날은 따로 models/CallistoBlade.glb(무기 공간: 원점 = 팔 끝, 블렌더 -y = 날 끝 쪽) → tools/WeaponMeshes.luau.
- 가면: 하얀 자기 볼토 가면(이마·코·광대·입술 부조, 아몬드 눈구멍) + 금 테두리 + 금 북두칠성(알코르까지) 상감 + 별빛 점 + 남색 벨벳 끈.

리그 공간(블렌더): 몸통 가운데 원점, 앞 = -y, 위 = +z. 오른팔(로블록스 +X) = 블렌더 x -1.5. (블렌더 (x,y,z) → 로블록스 (-x, z, y))
메시 이름 = 앞머리_재질: CalT 몸통 · CalRA 오른팔 · CalLA 왼팔 · CalRL 오른다리 · CalLL 왼다리 · CalH 머리. 원점 표지 CalOrigin_Marker(1×1×1).
돌리기: blender -b -P models/build_callisto_outfit.py [-- render]
  → models/CallistoOutfit.glb · models/CallistoBlade.glb (+ models/snowtown_render/CallistoV4_*.png)
스튜디오: 두 GLB 를 가져온 뒤 tools/Callisto_Outfit.luau(→ CallistoAssets.Outfit) · tools/WeaponMeshes.luau(→ WeaponMeshes.CallistoArms).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TEXDIR = os.path.join(HERE, "callisto_tex")
OUT = os.path.join(HERE, "snowtown_render")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = "render" in ARGS
os.makedirs(TEXDIR, exist_ok=True)


# ═════════════════════════════ 텍스처(이음매 없음 · numpy) ═════════════════════════════

def band_noise(n, f0, bw, seed, ax=1.0, ay=1.0):
    """주파수 f0(타일당 주기) 둘레 띠만 남긴 잡음 — FFT 라 저절로 이음매가 없다. ax > 1 이면 x 로 길게 늘어난 결."""
    r = np.random.default_rng(seed)
    F = np.fft.fft2(r.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None] * n * ay
    fx = np.fft.fftfreq(n)[None, :] * n * ax
    k = np.sqrt(fx * fx + fy * fy)
    out = np.real(np.fft.ifft2(F * np.exp(-((k - f0) / bw) ** 2)))
    return (out - out.mean()) / (out.std() + 1e-9)


def fbm(n, f0, seed, octaves=3):
    s, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + amp * band_noise(n, f0 * 2 ** o, f0 * 2 ** o * 0.5, seed + o)
        tot += amp
        amp *= 0.5
    return s / tot


def voronoi_edges(n, npts, seed):
    """이음매 없는 보로노이 경계 거리(가장 가까운 두 점 거리 차) — 자기 빙렬."""
    r = np.random.default_rng(seed)
    pts = r.random((npts, 2)).astype(np.float32)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    P = np.stack([x.ravel(), y.ravel()], 1)
    d1 = np.full(P.shape[0], 9.0, np.float32)
    d2 = d1.copy()
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            for q in pts + np.array([ox, oy], np.float32):
                d = ((P - q) ** 2).sum(1)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                d1 = np.where(closer, d, d1)
    return (np.sqrt(d2) - np.sqrt(d1)).reshape(n, n)


def to_normal(h, strength):
    """높이 → OpenGL 법선(초록 = 위). 행 0 = 이미지 아래(블렌더 픽셀 순서)라 축 0 증가 = v 증가."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, -dy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / ln, ny / ln, nz / ln]) * 0.5 + 0.5


IMAGES = {}


def save(name, arr, data):
    arr = np.clip(np.asarray(arr, np.float32), 0, 1)
    if arr.ndim == 2:
        arr = np.repeat(arr[:, :, None], 3, 2)
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    img.pixels.foreach_set(np.concatenate([arr, np.ones((h, w, 1), np.float32)], 2).ravel())
    img.filepath_raw = os.path.join(TEXDIR, name + ".png")
    img.file_format = "PNG"
    img.save()
    IMAGES[name] = img


def C(r, g, b):
    return np.array([r, g, b], np.float32) / 255.0


def tex_set(key, alb, height, strength, rough, metal):
    n = alb.shape[0]
    save(key + "_ALB", alb, False)
    save(key + "_NOR", to_normal(height, strength), True)
    save(key + "_RGH", rough if np.ndim(rough) else np.full((n, n), rough), True)
    save(key + "_MET", np.full((n, n), float(metal)), True)


def mix(a, b, t):
    return a[None, None, :] * (1 - t[:, :, None]) + b[None, None, :] * t[:, :, None]


def make_textures():
    # 도니갈 트위드: 헤링본(열마다 사선이 뒤집힘) + 열 사이 골 + 실 결 + 색점(녹·이끼·크림·청회색)
    n = 1024
    y, x = np.mgrid[0:n, 0:n] / n
    cols, pitch = 32, 128
    c = np.floor(x * cols)
    xl = x * cols - c
    d = np.where(c % 2 == 0, 1.0, -1.0)
    ridge = (0.5 + 0.5 * np.cos(2 * np.pi * (y * pitch + d * xl * 2.0))) ** 1.5
    groove = np.exp(-(np.minimum(xl, 1 - xl) / 0.05) ** 2)
    yarn = fbm(n, 90, 11)
    t = np.clip(ridge * 0.42 + 0.12 * yarn + 0.3, 0, 1)
    alb = mix(C(72, 50, 36), C(124, 89, 62), t) * (1 + 0.035 * band_noise(n, 24, 10, 5))[:, :, None]
    fleck = band_noise(n, 150, 45, 21) > 3.0
    pick = band_noise(n, 40, 12, 22)
    for lo, hi, col in ((-9, -0.6, C(176, 88, 46)), (-0.6, 0.2, C(98, 116, 62)), (0.2, 0.9, C(220, 202, 160)), (0.9, 9, C(92, 108, 136))):
        alb[fleck & (pick >= lo) & (pick < hi)] = col
    tex_set("Tweed", alb, ridge * 0.8 - groove * 0.35 + yarn * 0.08, 3.5, np.clip(0.83 + 0.05 * yarn - 0.05 * ridge, 0, 1), 0)

    # 실크(안감·손수건): 짙은 남색 공단 결 + 작은 금빛 별 점
    n = 512
    sheen = band_noise(n, 120, 60, 31, ax=6.0)
    alb = np.repeat(np.repeat(C(30, 40, 92)[None, None, :], n, 0), n, 1) * (0.92 + 0.08 * sheen)[:, :, None]
    star = band_noise(n, 70, 18, 32) > 2.7
    alb[star] = C(232, 204, 128)
    tex_set("Silk", alb, sheen * 0.05 + star * 0.2, 2.0, np.where(star, 0.3, 0.32 + 0.04 * sheen), 0)

    # 스웨이드: 결 없는 보풀
    nap = fbm(n, 60, 41)
    alb = np.repeat(np.repeat(C(86, 55, 36)[None, None, :], n, 0), n, 1) * (1 + 0.08 * fbm(n, 8, 42, 2) + 0.04 * nap)[:, :, None]
    tex_set("Suede", alb, nap * 0.4, 3.0, np.clip(0.92 + 0.03 * nap, 0, 1), 0)

    # 포플린(셔츠): 평직 — 날실·씨실이 번갈아 위로
    y, x = np.mgrid[0:n, 0:n] / n
    N = 96
    over = ((np.floor(x * N) + np.floor(y * N)) % 2) * 2 - 1
    h = 0.5 * (np.abs(np.sin(np.pi * x * N)) * (0.5 + 0.5 * over) + np.abs(np.sin(np.pi * y * N)) * (0.5 - 0.5 * over)) + 0.05 * fbm(n, 30, 51, 2)
    alb = np.repeat(np.repeat(C(240, 237, 230)[None, None, :], n, 0), n, 1) * (0.965 + 0.035 * h)[:, :, None]
    tex_set("Poplin", alb, h, 4.0, np.clip(0.7 + 0.06 * h, 0, 1), 0)

    # 울 능직(바지): 45° 사선 골 + 실 결
    N = 56
    h = (0.5 + 0.5 * np.cos(2 * np.pi * (x + y) * N)) ** 1.4 * (0.8 + 0.2 * np.abs(np.sin(np.pi * x * N * 3))) + 0.06 * fbm(n, 40, 61, 2)
    alb = np.repeat(np.repeat(C(30, 30, 35)[None, None, :], n, 0), n, 1) * (0.82 + 0.32 * h)[:, :, None]
    tex_set("Twill", alb, h, 4.0, np.clip(0.72 + 0.08 * (1 - h), 0, 1), 0)

    # 가죽: 주름진 결(능선 잡음) + 모공
    g = band_noise(n, 40, 14, 71)
    pores = band_noise(n, 180, 40, 73) > 2.3
    h = (1 - np.abs(g)) ** 2 * 0.6 + 0.1 * fbm(n, 120, 72, 2) - 0.3 * pores
    big = fbm(n, 3, 74, 2)
    rough = np.clip(0.42 + 0.16 * (1 - h), 0, 1)
    tex_set("Leather", np.repeat(np.repeat(C(94, 56, 33)[None, None, :], n, 0), n, 1) * (0.78 + 0.3 * h + 0.06 * big)[:, :, None], h, 3.5, rough, 0)
    tex_set("GloveLeather", np.repeat(np.repeat(C(32, 27, 27)[None, None, :], n, 0), n, 1) * (0.85 + 0.3 * h)[:, :, None], h, 3.0, np.clip(rough - 0.06, 0, 1), 0)
    tex_set("SoleLeather", np.repeat(np.repeat(C(46, 31, 24)[None, None, :], n, 0), n, 1) * (0.9 + 0.2 * h)[:, :, None], h, 2.0, np.clip(rough + 0.12, 0, 1), 0)

    # 자기(가면): 하얀 유약 + 가는 빙렬(보로노이 경계)
    e = voronoi_edges(n, 70, 81)
    crack = np.exp(-e / 0.0022) * 0.45
    warm = fbm(n, 4, 82, 2)
    alb = np.repeat(np.repeat(C(245, 241, 232)[None, None, :], n, 0), n, 1) * (1 - 0.12 * crack + 0.015 * warm)[:, :, None]
    tex_set("Porcelain", alb, -crack * 0.35 + warm * 0.03, 2.0, np.clip(0.09 + 0.2 * crack, 0, 1), 0)

    # 벨벳(가면 끈·소맷부리 안): 짙은 남색, 아주 거칠게
    n = 256
    v = fbm(n, 60, 91, 2)
    tex_set("Velvet", np.repeat(np.repeat(C(22, 24, 46)[None, None, :], n, 0), n, 1) * (0.85 + 0.15 * v)[:, :, None], v * 0.3, 2.0, 0.95, 0)

    # 금속: 결 방향 솔질(x 로 긴 결)
    for key, col, rough0, metal, seed in (("Brass", C(206, 164, 80), 0.28, 1, 101), ("Gold", C(228, 186, 100), 0.22, 1, 111),
                                          ("Pearl", C(244, 240, 233), 0.18, 0, 121)):
        h = band_noise(n, 30, 20, seed, ax=10.0)
        tex_set(key, np.repeat(np.repeat(col[None, None, :], n, 0), n, 1) * (0.93 + 0.07 * h)[:, :, None], h * 0.2, 1.5, np.clip(rough0 + 0.07 * h, 0, 1), metal)
    n = 512
    h = band_noise(n, 60, 40, 131, ax=16.0)
    tex_set("Steel", np.repeat(np.repeat(C(208, 213, 222)[None, None, :], n, 0), n, 1) * (0.95 + 0.05 * h)[:, :, None], h * 0.15, 1.5, np.clip(0.15 + 0.05 * h, 0, 1), 1)
    tex_set("BluedSteel", np.repeat(np.repeat(C(42, 56, 96)[None, None, :], n, 0), n, 1) * (0.92 + 0.08 * h)[:, :, None], h * 0.15, 1.5, np.clip(0.22 + 0.05 * h, 0, 1), 1)


# 재질 → (텍스처 묶음, UV 한 칸 = 몇 스터드)
MATS = {
    "Tweed": ("Tweed", 0.9), "Silk": ("Silk", 0.5), "Suede": ("Suede", 0.8), "Poplin": ("Poplin", 0.5), "Twill": ("Twill", 0.6),
    "Leather": ("Leather", 0.6), "GloveLeather": ("GloveLeather", 0.5), "SoleLeather": ("SoleLeather", 0.6), "Brass": ("Brass", 0.4),
    "Gold": ("Gold", 0.3), "Pearl": ("Pearl", 0.3), "Porcelain": ("Porcelain", 0.8), "Velvet": ("Velvet", 0.5),
    "Steel": ("Steel", 1.0), "BluedSteel": ("BluedSteel", 0.6), "Glow": (None, 1.0),
}
MATERIALS = {}


def make_materials():
    for name, (key, _tile) in MATS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        if key is None:            # 별빛(스튜디오에서 Neon 으로)
            bsdf.inputs["Base Color"].default_value = (0.35, 0.6, 1.0, 1)
            bsdf.inputs["Emission Color"].default_value = (0.35, 0.6, 1.0, 1)
            bsdf.inputs["Emission Strength"].default_value = 6.0
        else:
            def img(suffix):
                t = nodes.new("ShaderNodeTexImage")
                t.image = IMAGES[key + suffix]
                return t
            links.new(img("_ALB").outputs["Color"], bsdf.inputs["Base Color"])
            links.new(img("_RGH").outputs["Color"], bsdf.inputs["Roughness"])
            links.new(img("_MET").outputs["Color"], bsdf.inputs["Metallic"])
            nm = nodes.new("ShaderNodeNormalMap")
            links.new(img("_NOR").outputs["Color"], nm.inputs["Color"])
            links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        MATERIALS[name] = m


# ═════════════════════════════ 메시 도구 ═════════════════════════════

def scol():
    return bpy.context.scene.collection


def mesh_obj(name, rows, closed=False, cap0=None, cap1=None, holes=None):
    """rows = 같은 길이 점 줄들(아래 → 위). closed = 둘레가 닫힘. cap0/cap1 = 첫·끝 줄을 막는 가운데 점.
    면 방향: 줄이 +z 에서 봐 반시계로 돌면 바깥을 본다. holes(i, j) = True 면 그 칸을 비운다(가면 눈구멍)."""
    bm = bmesh.new()
    vv = [[bm.verts.new(p) for p in row] for row in rows]
    nc = len(rows[0])
    for i in range(len(rows) - 1):
        for j in range(nc if closed else nc - 1):
            if holes and holes(i, j):
                continue
            j2 = (j + 1) % nc
            bm.faces.new((vv[i][j], vv[i][j2], vv[i + 1][j2], vv[i + 1][j]))
    if cap0 is not None:
        c = bm.verts.new(cap0)
        for j in range(nc if closed else nc - 1):
            bm.faces.new((c, vv[0][(j + 1) % nc], vv[0][j]))
    if cap1 is not None:
        c = bm.verts.new(cap1)
        for j in range(nc if closed else nc - 1):
            bm.faces.new((c, vv[-1][j], vv[-1][(j + 1) % nc]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scol().objects.link(ob)
    return ob


def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)


PIECES = {}


def finish(ob, host, mat, sub=1, solid=0.0, offset=-1.0, inner=None):
    """서브디비전 → 두께. inner = 안쪽 껍질 재질(재킷 안감) — 두께를 준 뒤 재질별로 갈라 따로 담는다."""
    if sub:
        m = ob.modifiers.new("ss", "SUBSURF")
        m.levels = m.render_levels = sub
    if solid:
        m = ob.modifiers.new("so", "SOLIDIFY")
        m.thickness, m.offset, m.use_even_offset, m.use_rim, m.use_quality_normals = solid, offset, True, True, True
        m.thickness_clamp = 1.0                    # 좁은 모서리에서 안쪽 껍질이 튀지 않게
        if inner:
            ob.data.materials.append(MATERIALS[mat])
            ob.data.materials.append(MATERIALS[inner])
            m.material_offset, m.material_offset_rim = 1, 0
    apply_mods(ob)
    if inner:
        for idx, key in ((1, inner), (0, mat)):
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != idx], context="FACES")
            me = bpy.data.meshes.new(ob.name + key)
            bm.to_mesh(me)
            bm.free()
            part = bpy.data.objects.new(ob.name + key, me)
            scol().objects.link(part)
            PIECES.setdefault((host, key), []).append(part)
        bpy.data.objects.remove(ob, do_unlink=True)
        return
    PIECES.setdefault((host, mat), []).append(ob)


def lathe(profile, seg, M=Matrix()):
    """(반지름, 높이) 단면을 z 축으로 돌린 줄들 + 끝 막이(반지름 0 인 끝은 가운데 점)."""
    rows, cap0, cap1 = [], None, None
    for i, (r, z) in enumerate(profile):
        if r < 1e-6:
            if i == 0:
                cap0 = M @ Vector((0, 0, z))
            else:
                cap1 = M @ Vector((0, 0, z))
            continue
        rows.append([M @ Vector((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z)) for k in range(seg)])
    return rows, cap0, cap1


def add_lathe(name, host, mat, profile, seg, M, sub=1):
    rows, c0, c1 = lathe(profile, seg, M)
    finish(mesh_obj(name, rows, True, c0, c1), host, mat, sub)


def tube_rows(points, radius, seg=8, round_end=True):
    """길(points)을 따라 도는 둥근 관(평행 이동 틀). 끝은 반구로 닫는다."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    rows, prev = [], None
    tans = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        tans.append(t)
        if prev is None:
            a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            nrm = t.cross(a).normalized()
        else:
            nrm = (prev - t * prev.dot(t)).normalized()
        prev = nrm
        b = t.cross(nrm)
        r = radius(i / max(n - 1, 1)) if callable(radius) else radius
        rows.append([pts[i] + (nrm * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * r for k in range(seg)])
    cap = pts[-1]
    if round_end:
        t = tans[-1]
        r = radius(1.0) if callable(radius) else radius
        last = rows[-1]
        for k in (1, 2):
            ang = k / 3 * math.pi / 2
            rows.append([pts[-1] + (p - pts[-1]) * math.cos(ang) + t * r * math.sin(ang) for p in last])
        cap = pts[-1] + t * r
    return rows, cap


def add_tube(name, host, mat, points, radius, seg=8, sub=1, round_start=True):
    rows, cap1 = tube_rows(points, radius, seg)
    c0 = None
    if round_start:
        c0 = Vector(points[0]) - (Vector(points[1]) - Vector(points[0])).normalized() * (radius(0) if callable(radius) else radius) * 0.6
    finish(mesh_obj(name, rows, True, c0, cap1), host, mat, sub)


def orient(normal):
    return Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def interp(table, z):
    if z <= table[0][0]:
        return table[0][1]
    for (z0, v0), (z1, v1) in zip(table, table[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return table[-1][1]


def lin(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


# ── 둥근 사각 둘레(R6 상자를 감싸는 단면) ──
def rr_len(a, b, r):
    return 4 * (a - r) + 4 * (b - r) + 2 * math.pi * r


def rr_point(a, b, r, s):
    """반폭 a(x)·반깊이 b(y)·모서리 r 둘레에서 앞 가운데(0,-b)부터 +x 쪽으로 호 길이 s 인 점과 바깥 법선."""
    s = s % rr_len(a, b, r)
    hx, hy = a - r, b - r
    for sg in (("L", (0, -b), (hx, -b), (0, -1)), ("A", (hx, -hy), -math.pi / 2), ("L", (a, -hy), (a, hy), (1, 0)),
               ("A", (hx, hy), 0.0), ("L", (hx, b), (-hx, b), (0, 1)), ("A", (-hx, hy), math.pi / 2),
               ("L", (-a, hy), (-a, -hy), (-1, 0)), ("A", (-hx, -hy), math.pi), ("L", (-hx, -b), (0, -b), (0, -1))):
        if sg[0] == "L":
            (x0, y0), (x1, y1), nrm = sg[1], sg[2], sg[3]
            ln = math.hypot(x1 - x0, y1 - y0)
            if s <= ln + 1e-9:
                t = s / ln if ln > 0 else 0
                return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, nrm[0], nrm[1]
            s -= ln
        else:
            (cx, cy), t0 = sg[1], sg[2]
            ln = r * math.pi / 2
            if s <= ln + 1e-9:
                th = t0 + s / r
                return cx + r * math.cos(th), cy + r * math.sin(th), math.cos(th), math.sin(th)
            s -= ln
    return 0.0, -b, 0.0, -1.0


def wrap_rows(zs, shape, n, gap=None, cx=0.0, cy=0.0, disp=None):
    """높이마다 둥근 사각 둘레 한 줄. gap(z) = 앞 트임 반폭(None 이면 닫힘). disp(x,y,z,nx,ny,u) = 법선 방향 변위."""
    rows = []
    for z in zs:
        a, b, r = shape(z)
        L = rr_len(a, b, r)
        if gap is None:
            ss = [L * j / n for j in range(n)]
        else:
            g = gap(z)
            ss = [g + (L - 2 * g) * j / (n - 1) for j in range(n)]
        row = []
        for j, s in enumerate(ss):
            x, y, nx, ny = rr_point(a, b, r, s)
            u = j / (n if gap is None else n - 1)
            dd = disp(x, y, z, nx, ny, u) if disp else 0.0
            row.append(Vector((cx + x + nx * dd, cy + y + ny * dd, z)))
        rows.append(row)
    return rows


def cap_rows(top, center, z0, z1, steps, k0=1.0):
    """마지막 줄(top)에서 가운데(center)로 둥글게 덮는 돔 줄들(소매 어깨 · 바지 위)."""
    rows = []
    for k in range(1, steps + 1):
        th = k / (steps + 1) * math.pi / 2
        s = math.cos(th) * k0 if k < steps + 1 else 0
        z = z0 + (z1 - z0) * math.sin(th)
        rows.append([Vector((center.x + (p.x - center.x) * s, center.y + (p.y - center.y) * s, z)) for p in top])
    return rows


# ═════════════════════════════ 체형(여성 · R6 상자 둘레) ═════════════════════════════

def bust(x, z):
    d = sum(math.exp(-(((x - cx) / 0.30) ** 2 + ((z - 0.30) / 0.27) ** 2)) for cx in (-0.42, 0.42))
    return 0.085 * min(d, 1.1)


def torso_shape(cl, flare=True):
    def f(z):
        a = interp([(-1.36, 1.06 if flare else 0.99), (-0.9, 1.0 if flare else 0.99), (-0.45, 0.955), (0.2, 0.99), (0.9, 1.0)], z) + cl
        b = interp([(-1.36, 0.55 if flare else 0.5), (-0.9, 0.525 if flare else 0.5), (-0.5, 0.5), (0.9, 0.5)], z) + cl
        return a, b, 0.38
    return f
CL_SHIRT, CL_JACKET = 0.024, 0.078
JACKET_SHAPE = torso_shape(CL_JACKET)
SHIRT_SHAPE = torso_shape(CL_SHIRT, flare=False)


def jacket_gap(z):
    # 앞 트임 반폭: 목 옆 0.40 → 꺾임점(허리 위) 0.31 → 단 0.46(단추를 풀어 아래가 벌어짐)
    return interp([(-1.36, 0.5), (-0.95, 0.39), (-0.55, 0.325), (-0.22, 0.31), (0.4, 0.36), (0.97, 0.40)], z)


def jacket_disp(x, y, z, nx, ny, u):
    front, back = max(0.0, -ny), max(0.0, ny)
    d = bust(x, z) * front * 0.92
    d += 0.014 * math.sin(x * 9.0 + 0.6) * smooth(-0.3, -1.36, z) * front          # 앞판 아래 드레이프 주름
    d += 0.011 * math.sin(x * 6.0 + 1.3) * smooth(-0.2, -1.36, z) * back           # 등판 아래 부드러운 주름
    d -= 0.018 * math.exp(-((z + 0.45) / 0.3) ** 2) * (1 - 0.5 * front)            # 허리선(옆·뒤)
    d -= 0.012 * math.exp(-((x / 0.04) ** 2)) * back * smooth(1.0, 0.8, z)         # 뒤 가운데 솔기(골)
    return d


def jacket_front_y(x, z):
    a, b, r = JACKET_SHAPE(z)
    return -b - jacket_disp(x, -b, z, 0.0, -1.0, 0.0)


def shirt_disp(x, y, z, nx, ny, u):
    front = max(0.0, -ny)
    d = bust(x, z) * front
    d += 0.012 * math.sin(x * 12.0 + 0.4) * smooth(-0.55, -0.86, z) * front        # 허리띠 위로 부푼 셔츠
    d -= 0.012 * math.exp(-((z + 0.45) / 0.3) ** 2)
    return d


def shirt_front_y(x, z):
    a, b, r = SHIRT_SHAPE(z)
    return -b - shirt_disp(x, -b, z, 0.0, -1.0, 0.0)


# ═════════════════════════════ 몸통(셔츠 · 재킷 · 바지 허리) ═════════════════════════════

def shoulder_rows(top, z0, ztop, ncy, nrx, nry, nz, steps_arc=4, steps_flat=3, rc=0.22, slope=0.0):
    """어깨: 마지막 둘레 줄에서 둥근 어깨(반지름 rc)로 꺾여 목 둘레 타원(nrx·nry, 높이 nz)까지."""
    rows = []
    q = []
    for p in top:
        ang = math.atan2((p.y - ncy) / nry, p.x / nrx)
        q.append(Vector((nrx * math.cos(ang), ncy + nry * math.sin(ang), nz)))
    ends = []
    for k in range(1, steps_arc + 1):
        th = k / steps_arc * math.pi / 2
        row = []
        for p, qq in zip(top, q):
            inward = Vector((qq.x - p.x, qq.y - p.y, 0)).normalized()
            zt = ztop - slope * min(abs(p.x), 1.1) ** 2
            row.append(p + inward * rc * (1 - math.cos(th)) + Vector((0, 0, z0 - p.z + (zt - z0) * math.sin(th))))
        rows.append(row)
    ends = rows[-1]
    for k in range(1, steps_flat + 1):
        w = k / steps_flat
        rows.append([e.lerp(qq, w) + Vector((0, 0, 0.02 * math.sin(math.pi * w))) for e, qq in zip(ends, q)])
    return rows


def build_shirt():
    zs = lin(-0.92, 0.79, 21)
    rows = wrap_rows(zs, SHIRT_SHAPE, 44, disp=shirt_disp)
    rows += shoulder_rows(rows[-1], 0.79, 1.0 + CL_SHIRT, 0.0, 0.6, 0.55, 1.02, slope=0.07)
    finish(mesh_obj("Shirt", rows, True, None, Vector((0, 0.0, 1.03))), "CalT", "Poplin", sub=1)
    # 셔츠 깃: 서는 깃 → 접혀 넘어가는 깃, 앞은 뾰족한 깃 끝(재킷 라펠 위로 퍼짐)
    a, b, r, cy = 0.65, 0.62, 0.32, 0.025
    L = rr_len(a, b, r)
    s0 = 0.2                                                     # 앞은 V 로 벌어짐(가면 턱이 보이게)
    nu = 36
    rows = []
    for w, (zz, off) in enumerate(((0.985, 0.0), (1.1, -0.01), (1.15, 0.01), (1.1, 0.04), (1.02, 0.06))):
        row = []
        for j in range(nu):
            u = j / (nu - 1)
            s = s0 + (L - 2 * s0) * u
            x, y, nx, ny = rr_point(a, b, r, s)
            f = max(0.0, 1 - min(u, 1 - u) / 0.22) ** 1.5           # 앞 끝으로 갈수록 1
            z = zz - (0.15 * f if w in (1, 2) else 0) - (0.2 * f if w == 3 else 0) - (0.3 * f if w == 4 else 0)
            o = off + (0.02 * f if w >= 3 else 0)
            row.append(Vector((x + nx * o + (0.02 * f * (1 if x > 0 else -1) if w == 4 else 0), cy + y + ny * o + 0.07 * f, z)))
        rows.append(row)
    finish(mesh_obj("ShirtCollar", rows), "CalT", "Poplin", sub=1, solid=0.022, offset=0.0)
    # 단추 덧단 · 진주 단추
    rows = []
    for z in lin(-0.86, 0.9, 20):
        rows.append([Vector((x, shirt_front_y(x, z) - 0.012, z)) for x in lin(-0.065, 0.065, 4)])
    finish(mesh_obj("Placket", rows), "CalT", "Poplin", sub=1, solid=0.012, offset=-1.0)
    for z in (0.8, 0.52, 0.24, -0.04, -0.32, -0.6):
        M = Matrix.Translation((0, shirt_front_y(0, z) - 0.024, z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        add_lathe("Button", "CalT", "Pearl", [(0.0, -0.004), (0.036, -0.004), (0.04, 0.006), (0.03, 0.012), (0.0, 0.009)], 14, M)


def build_jacket():
    zs = [-1.36, -1.3, -1.2] + lin(-1.08, 0.78, 18)
    nu = 46
    rows = wrap_rows(zs, JACKET_SHAPE, nu, gap=jacket_gap, disp=jacket_disp)
    # 앞 끝 아래 모서리를 둥글게 깎아 올림(컷어웨이)
    for i, lift in ((0, 0.2), (1, 0.12), (2, 0.04)):
        for j in range(nu):
            u = j / (nu - 1)
            f = max(0.0, 1 - min(u, 1 - u) / 0.09) ** 2
            rows[i][j].z += lift * f
    rows += shoulder_rows(rows[-1], 0.78, 1.0 + CL_JACKET, 0.04, 0.66, 0.6, 1.06, slope=0.08)
    finish(mesh_obj("Jacket", rows), "CalT", "Tweed", sub=1, solid=0.036, offset=-1.0, inner="Silk")
    # 노치 라펠: 꺾임선(앞 끝) → 바깥 끝, 앞판 위에 누움. 0.74 근처에서 노치(V 홈)
    W = [(0.0, 0.0), (0.2, 0.12), (0.45, 0.23), (0.66, 0.33), (0.72, 0.35), (0.75, 0.17), (0.79, 0.24), (0.9, 0.2), (1.0, 0.07)]
    for side in (1, -1):
        rows = []
        for t in [i / 22 for i in range(23)]:
            z = -0.22 + (0.97 + 0.22) * t
            xr = jacket_gap(z)
            w = interp(W, t)
            row = []
            for k in lin(0.0, 1.0, 6):
                x = xr + w * k
                bulge = 0.06 * (1 - k) ** 2 * (0.3 + 0.7 * t)           # 꺾임선 쪽이 살짝 일어섬(롤)
                row.append(Vector((side * x, jacket_front_y(x, z) - 0.032 - bulge, z + 0.04 * k * w)))
            rows.append(row if side > 0 else row[::-1])
        finish(mesh_obj("Lapel", rows), "CalT", "Tweed", sub=1, solid=0.03, offset=-1.0)
    # 재킷 깃(목 뒤로 돌아 라펠 위 끝과 만남): 서는 깃 → 접힘 → 넘어간 깃 끝
    a, b, r, cy = 0.77, 0.7, 0.32, 0.04
    L = rr_len(a, b, r)
    s0 = min((abs(rr_point(a, b, r, s)[0] - 0.43), s) for s in [L * i / 400 for i in range(100)])[1]
    nu = 44
    rows = []
    for zz, off in ((0.95, 0.0), (1.12, -0.03), (1.21, -0.015), (1.15, 0.05), (1.0, 0.1)):
        row = []
        for j in range(nu):
            u = j / (nu - 1)
            x, y, nx, ny = rr_point(a, b, r, s0 + (L - 2 * s0) * u)
            f = max(0.0, 1 - min(u, 1 - u) / 0.16) ** 1.5
            row.append(Vector((x + nx * off * (1 - 0.5 * f), cy + y + ny * off * (1 - 0.5 * f), zz - 0.2 * f)))
        rows.append(row)
    finish(mesh_obj("Collar", rows), "CalT", "Tweed", sub=1, solid=0.03, offset=0.0)
    # 덮개 주머니 둘(허리 아래) · 가슴 주머니(왼쪽) + 실크 손수건
    for side, z0, w, h in ((1, -0.9, 0.42, 0.15), (-1, -0.9, 0.42, 0.15), (1, 0.42, 0.3, 0.05)):
        cxp = side * 0.66
        rows = []
        for z in lin(z0 - h, z0, 4):
            rows.append([Vector((x, jacket_front_y(x, z) - 0.012 - 0.008 * (z0 - z) / h, z - 0.02 * abs(x - cxp) / w)) for x in lin(cxp - w / 2, cxp + w / 2, 8)])
        finish(mesh_obj("Flap", rows), "CalT", "Tweed", sub=1, solid=0.03, offset=-1.0)
    for k, (dx, dz) in enumerate(((-0.08, 0.1), (0.0, 0.14), (0.07, 0.09))):        # 손수건 끝 셋
        x0 = 0.66 + dx
        rows = []
        for z in lin(0.42, 0.42 + dz, 4):
            t = (z - 0.42) / dz
            rows.append([Vector((x, jacket_front_y(x, 0.42) - 0.02 - 0.01 * k, z)) for x in lin(x0 - 0.05 * (1 - t), x0 + 0.05 * (1 - t) + 0.002, 3)])
        finish(mesh_obj("Square", rows), "CalT", "Silk", sub=1, solid=0.01, offset=0.0)
    # 단추 둘(풀린 채 오른 앞판 — 블렌더 -x) · 단춧구멍(왼 앞판)
    for z in (-0.3, -0.66):
        x = -(jacket_gap(z) + 0.1)
        M = Matrix.Translation((x, jacket_front_y(-x, z) - 0.03, z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        add_lathe("JButton", "CalT", "Brass", [(0.0, -0.006), (0.06, -0.006), (0.066, 0.008), (0.05, 0.02), (0.0, 0.016)], 16, M)
        xb = jacket_gap(z) + 0.09
        add_tube("Hole", "CalT", "SoleLeather", [(xb - 0.05, jacket_front_y(xb, z) - 0.03, z), (xb + 0.05, jacket_front_y(xb, z) - 0.03, z)], 0.008, 6, 0)
    # 별 브로치(왼 라펠) + 회중시계 줄(가슴 주머니 → 단춧구멍)
    bx, bz = 0.52, 0.55
    by = jacket_front_y(bx, bz) - 0.08
    star_pts = []
    for k in range(8):
        rr_ = 0.1 if k % 2 == 0 else 0.035
        a_ = math.pi / 2 + k * math.pi / 4
        star_pts.append((bx + rr_ * math.cos(a_), bz + rr_ * math.sin(a_)))
    rows = [[Vector((px, by - 0.0, pz)) for px, pz in star_pts], [Vector((bx + (px - bx) * 0.6, by - 0.02, bz + (pz - bz) * 0.6)) for px, pz in star_pts]]
    finish(mesh_obj("Brooch", rows, True, Vector((bx, by + 0.012, bz)), Vector((bx, by - 0.03, bz))), "CalT", "Gold", sub=0)
    add_lathe("BroochGem", "CalT", "Glow", [(0.0, 0.0), (0.022, 0.0), (0.0, 0.022)], 10,
              Matrix.Translation((bx, by - 0.025, bz)) @ Matrix.Rotation(math.pi / 2, 4, "X"), sub=1)


def build_waist():
    # 바지 허리·엉덩이(몸통에 붙음) + 허리띠 + 고리 + 놋쇠 버클
    sh = lambda z: (interp([(-1.16, 1.03), (-0.8, 1.0)], z), interp([(-1.16, 0.55), (-0.8, 0.52)], z), 0.36)
    rows = wrap_rows(lin(-1.16, -0.8, 5), sh, 44)
    finish(mesh_obj("Seat", rows, True, Vector((0, 0, -1.17)), None), "CalT", "Twill", sub=1)
    a0, b0 = 1.015, 0.535
    ring = []
    for zz, d in ((-0.8, 0.0), (-0.935, 0.0), (-0.935, 0.026), (-0.8, 0.026)):
        ring.append(wrap_rows([zz], lambda z, d=d: (a0 + d, b0 + d, 0.37), 52)[0])
    ring.append(ring[0])
    finish(mesh_obj("Belt", ring, True), "CalT", "Leather", sub=1)
    for x in (0.55, -0.55):
        rows = [[Vector((xx, -b0 - 0.035, z)) for xx in lin(x - 0.035, x + 0.035, 3)] for z in lin(-0.95, -0.785, 3)]
        finish(mesh_obj("Loop", rows), "CalT", "Twill", sub=1, solid=0.012, offset=-1.0)
    # 버클: 둥근 사각 고리(앞을 봄) + 혀 + 혀끝 띠
    bx = 0.06
    frame = []
    for zz, d in ((0.0, 0.0), (0.0, 0.02), (0.02, 0.02), (0.02, 0.0)):
        loop = []
        for k in range(28):
            th = 2 * math.pi * k / 28
            hw, hh = 0.13 + d * (1 if zz == 0 else 1), 0.085 + d
            px = bx + hw * math.copysign(abs(math.cos(th)) ** 0.5, math.cos(th))
            pz = -0.8675 + hh * math.copysign(abs(math.sin(th)) ** 0.5, math.sin(th))
            loop.append(Vector((px, -b0 - 0.04 - zz, pz)))
        frame.append(loop)
    frame.append(frame[0])
    finish(mesh_obj("Buckle", frame, True), "CalT", "Brass", sub=1)
    add_tube("Prong", "CalT", "Brass", [(bx - 0.12, -b0 - 0.05, -0.8675), (bx + 0.1, -b0 - 0.05, -0.8675)], 0.012, 6, 0)
    rows = [[Vector((x, -b0 - 0.03, z)) for x in lin(bx - 0.09, bx + 0.32, 6)] for z in lin(-0.925, -0.81, 3)]
    finish(mesh_obj("BeltTip", rows), "CalT", "Leather", sub=1, solid=0.018, offset=-1.0)


# ═════════════════════════════ 팔(소매 · 소맷부리 · 장갑) ═════════════════════════════

def sleeve_disp_fn(side):
    def f(x, y, z, nx, ny, u):
        front, back = max(0.0, -ny), max(0.0, ny)
        inner = max(0.0, -nx * side)                                         # 몸 쪽
        d = 0.018 * math.sin(z * 24.0 + 1.0) * math.exp(-((z - 0.02) / 0.18) ** 2) * (front * 0.8 + inner * 0.5)   # 팔꿈치 안쪽 주름
        d += 0.013 * math.sin(z * 30.0 + u * 18.0) * math.exp(-((z + 0.5) / 0.16) ** 2)                             # 소맷부리 위 눌린 주름
        d += 0.01 * back * math.exp(-((z - 0.0) / 0.25) ** 2)                                                        # 팔꿈치 뒤 불룩
        return d
    return f


def build_arm(host, side):
    """side = +1 왼팔(블렌더 x +1.5) · -1 오른팔(검). 소매(재킷) + 어깨 머리 + 팔꿈치 덧댐 + 소매 단추 + 셔츠 소맷부리."""
    cx = side * 1.5
    z_end = -0.74
    half = lambda z: interp([(z_end, 0.34), (-0.4, 0.355), (0.0, 0.375), (0.4, 0.395), (0.96, 0.42)], z)
    shape = lambda z: (half(z), half(z), 0.3)
    zs = lin(z_end, 0.94, 20)
    rows = wrap_rows(zs, shape, 32, cx=cx, disp=sleeve_disp_fn(side))
    caps = cap_rows(rows[-1], Vector((cx, 0, 0)), 0.94, 1.08, 3)
    for k, row in enumerate(caps):
        for v in row:
            v.z -= 0.14 * (k + 1) / len(caps) * ((v.x - cx) * side / 0.42)         # 어깨선: 바깥이 낮다
    rows += caps
    finish(mesh_obj("Sleeve", rows, True, None, Vector((cx - side * 0.04, 0, 1.08))), host, "Tweed", sub=1)
    # 소매 끝 접단(두툼) — 사각 단면 고리
    ring = []
    for zz, d in ((z_end - 0.005, 0.0), (z_end - 0.005, 0.02), (z_end + 0.07, 0.02), (z_end + 0.07, 0.0)):
        ring.append(wrap_rows([zz], lambda z, d=d: (0.35 + d, 0.35 + d, 0.31), 32, cx=cx)[0])
    ring.append(ring[0])
    finish(mesh_obj("Cuff", ring, True), host, "Tweed", sub=1)
    # 팔꿈치 덧댐(뒤, 스웨이드 타원)
    rows = []
    for q in lin(-1, 1, 6):
        row = []
        for p in lin(-1, 1, 6):
            ex, ez = p * math.sqrt(1 - q * q / 2), q * math.sqrt(1 - p * p / 2)
            z = 0.02 + ez * 0.24
            a, b, r = shape(z)
            row.append(Vector((cx + ex * 0.17, b + 0.012 + sleeve_disp_fn(side)(0, b, z, 0, 1, 0), z)))
        rows.append(row[::-1])
    finish(mesh_obj("Patch", rows), host, "Suede", sub=1, solid=0.012, offset=-1.0)
    # 소매 단추 셋(바깥 옆 뒤쪽)
    for k in range(3):
        z = z_end + 0.12 + k * 0.085
        a, b, r = shape(z)
        n = Vector((side, 0.35, 0)).normalized()
        p = Vector((cx + side * (a + 0.012), 0.22, z))
        add_lathe("SButton", host, "Brass", [(0.0, -0.004), (0.03, -0.004), (0.033, 0.006), (0.0, 0.012)], 12, Matrix.Translation(p) @ orient(n), sub=1)
    # 셔츠 소맷부리(흰 포플린) + 커프스(금 별)
    ring = []
    for zz, d in ((z_end - 0.14, 0.0), (z_end - 0.14, 0.02), (z_end + 0.02, 0.02), (z_end + 0.02, 0.0)):
        ring.append(wrap_rows([zz], lambda z, d=d: (0.31 + d, 0.31 + d, 0.27), 32, cx=cx)[0])
    ring.append(ring[0])
    finish(mesh_obj("ShirtCuff", ring, True), host, "Poplin", sub=1)
    p = Vector((cx + side * 0.335, -0.08, z_end - 0.07))
    add_lathe("Cufflink", host, "Gold", [(0.0, -0.004), (0.035, -0.004), (0.038, 0.008), (0.0, 0.014)], 8, Matrix.Translation(p) @ orient((side, 0, 0)), sub=0)
    # 소맷부리 안(어둠) — 오른팔은 여기서 날이 나온다
    rows, c0, _ = lathe([(0.0, 0.0), (0.32, 0.0)], 24, Matrix.Translation((cx, 0, z_end - 0.1)))
    finish(mesh_obj("CuffDark", rows, True, c0, None), host, "Velvet", sub=0)


def build_glove(host, side):
    """왼손 검은 가죽 장갑: 손목 → 손바닥(몸 쪽을 봄) → 살짝 굽은 손가락 넷(앞뒤로 늘어섬) + 엄지(앞)."""
    cx = side * 1.5
    zs = [-1.05, -0.99, -0.92, -0.86, -0.80]
    dims = {-0.80: (0.3, 0.29), -0.86: (0.28, 0.26), -0.92: (0.31, 0.28), -0.99: (0.32, 0.27), -1.05: (0.3, 0.25)}
    rows = wrap_rows(zs, lambda z: (dims[z][0], dims[z][1], 0.2), 28, cx=cx)
    finish(mesh_obj("Palm", rows, True, Vector((cx, 0, -1.08)), None), host, "GloveLeather", sub=1)
    inward = -side                                                            # 손가락이 굽는 쪽(몸 쪽)
    for k, (fy, ln) in enumerate(((-0.19, 0.24), (-0.064, 0.27), (0.064, 0.25), (0.185, 0.2))):
        pts = []
        for i in range(6):
            t = i / 5
            pts.append((cx + inward * (0.02 + 0.11 * t * t) - side * 0.02, fy * (1 - 0.1 * t), -1.02 - ln * t))
        add_tube("Finger", host, "GloveLeather", pts, lambda t: 0.057 - 0.009 * t, 10, 1)
    pts = [(cx + inward * 0.03, -0.23, -0.86), (cx + inward * 0.08, -0.3, -0.96), (cx + inward * 0.12, -0.32, -1.05)]
    add_tube("Thumb", host, "GloveLeather", pts, lambda t: 0.062 - 0.009 * t, 10, 1)


# ═════════════════════════════ 다리(바지 · 구두) ═════════════════════════════

def build_leg(host, side):
    lx = side * 0.5
    shape = lambda z: (interp([(-2.84, 0.41), (-2.0, 0.425), (-1.0, 0.475)], z), interp([(-2.84, 0.42), (-2.0, 0.44), (-1.0, 0.5)], z), 0.36)
    def disp(x, y, z, nx, ny, u):
        front, back = max(0.0, -ny), max(0.0, ny)
        cxl = x                                                              # 둘레 점의 다리 가운데 기준 x
        d = 0.012 * math.exp(-((cxl / 0.03) ** 2)) * (front + back)           # 앞뒤 주름선
        d += 0.012 * math.sin(z * 28.0) * math.exp(-((z + 2.02) / 0.12) ** 2) * back   # 무릎 뒤 주름
        d += 0.024 * math.exp(-((z + 2.66) / 0.05) ** 2)                       # 밑단 꺾임(구두 위)
        d += 0.01 * math.sin(u * 2 * math.pi * 5) * smooth(-2.4, -2.8, z)      # 밑단 쪽 처짐
        return d
    zs = lin(-2.84, -1.02, 20)
    rows = wrap_rows(zs, shape, 32, cx=lx + side * 0.02, disp=disp)
    rows += cap_rows(rows[-1], Vector((lx, 0, 0)), -1.02, -0.94, 2)
    finish(mesh_obj("Trouser", rows, True, None, Vector((lx, 0, -0.93))), host, "Twill", sub=1)
    # 구두(갈색 가죽 옥스퍼드, 낮은 굽): 뒤꿈치 → 앞코로 단면을 이어 붙임
    def w_(y):
        return interp([(-0.82, 0.09), (-0.72, 0.27), (-0.42, 0.4), (0.1, 0.38), (0.46, 0.32)], y)
    def h_(y):
        return interp([(-0.82, 0.05), (-0.7, 0.11), (-0.4, 0.17), (0.0, 0.3), (0.3, 0.36), (0.46, 0.36)], y)
    sole_top = -2.95
    rows = []
    for yv in lin(0.47, -0.8, 18):
        w, hh = w_(yv), h_(yv)
        ring = []
        for k in range(24):
            th = 2 * math.pi * k / 24
            px = w / 2 * math.copysign(abs(math.cos(th)) ** 0.7, math.cos(th))
            pz = hh * 0.5 * (1 + math.copysign(abs(math.sin(th)) ** 0.7, math.sin(th)))
            ring.append(Vector((lx + px, yv, sole_top + max(pz, 0.0))))
        rows.append(ring)
    finish(mesh_obj("Shoe", rows, True, Vector((lx, 0.48, sole_top + 0.17)), Vector((lx, -0.81, sole_top + 0.03))), host, "Leather", sub=1)
    # 밑창(조금 더 넓게) · 굽
    rows = []
    for zz, d in ((-3.0, 0.0), (-2.945, 0.0)):
        ring = []
        for yv in lin(0.49, -0.83, 16):
            ring.append(Vector((lx + w_(yv) / 2 + 0.022, yv, zz)))
        for yv in lin(-0.83, 0.49, 16):
            ring.append(Vector((lx - w_(yv) / 2 - 0.022, yv, zz)))
        rows.append(ring[::-1])
    finish(mesh_obj("Sole", rows, True, Vector((lx, -0.17, -3.0)), Vector((lx, -0.17, -2.945))), host, "SoleLeather", sub=1)
    rows = [[Vector((lx + x, y, -2.94)) for x in lin(-0.17, 0.17, 4)] for y in lin(0.18, 0.46, 3)]
    finish(mesh_obj("Heel", rows), host, "SoleLeather", sub=1, solid=0.06, offset=-1.0)
    # 끈(엇갈린 셋) · 놋쇠 구멍 · 앞코 솔기
    top = lambda y: sole_top + h_(y) + 0.008
    for k in range(3):
        y0 = -0.1 - k * 0.1
        for s_ in (1, -1):
            add_tube("Lace", host, "Silk" if False else "SoleLeather", [(lx - 0.12 * s_, y0 + 0.03, top(y0 + 0.03)), (lx + 0.12 * s_, y0 - 0.03, top(y0 - 0.03))], 0.012, 6, 0)
        for s_ in (1, -1):
            add_lathe("Eyelet", host, "Brass", [(0.0, 0.0), (0.022, 0.0), (0.022, 0.01), (0.0, 0.01)], 8,
                      Matrix.Translation((lx + 0.14 * s_, y0, top(y0) - 0.006)), sub=0)
    seam = []
    for k in range(13):
        th = math.pi * k / 12
        yv = -0.5 - 0.06 * math.sin(th)
        x = lx + (w_(yv) / 2 + 0.004) * math.cos(th)
        seam.append((x, yv, sole_top + h_(yv) * (0.55 + 0.45 * math.sin(th)) + 0.004))
    add_tube("ToeSeam", host, "SoleLeather", seam, 0.008, 5, 0)


# ═════════════════════════════ 가면(머리) ═════════════════════════════

HEAD = Vector((0, 0, 1.5))


def head_r(h):
    """고전 머리(지름 1.25 둥근 원통) 반지름 — 위아래 모서리가 둥글다."""
    a = abs(h)
    return 0.625 if a <= 0.32 else 0.325 + math.sqrt(max(0.0, 0.3 ** 2 - (a - 0.32) ** 2))


def mask_relief(xm, h):
    g = lambda dx, sx, dh, sh: math.exp(-((dx / sx) ** 2 + (dh / sh) ** 2))
    d = 0.035 * math.exp(-((h - 0.2) / 0.07) ** 2) * math.exp(-((xm / 0.42) ** 4))            # 눈썹 뼈
    d -= 0.035 * (g(abs(xm) - 0.22, 0.13, h - 0.07, 0.08))                                       # 눈두덩
    t = min(max((0.15 - h) / 0.26, 0.0), 1.0)
    nose = 0.115 * t ** 1.3 * math.exp(-((xm / (0.045 + 0.04 * t)) ** 2))
    if h < -0.11:
        nose *= math.exp(-((h + 0.11) / 0.035) ** 2)
    d += nose
    d += 0.02 * g(abs(xm) - 0.3, 0.12, h + 0.02, 0.1)                                            # 광대
    d += 0.03 * g(xm, 0.1, h + 0.27, 0.025) + 0.035 * g(xm, 0.09, h + 0.335, 0.03)              # 입술(무표정 — 다문 입)
    d -= 0.012 * g(xm, 0.11, h + 0.3, 0.008)
    d += 0.03 * g(xm, 0.14, h + 0.47, 0.06)                                                      # 턱
    return d





def mask_uv(p, q):
    """[-1,1]² → 타원 가면 위 (xm, h): 사각 → 원 대응, 아래(턱)는 갸름하게."""
    ex, eq = p * math.sqrt(1 - q * q / 2), q * math.sqrt(1 - p * p / 2)
    w = 0.44 * (1 - 0.22 * max(0.0, -eq) ** 2)
    return ex * w, 0.02 + eq * 0.53
def mask_point(ph, h, extra=0.0):
    r = head_r(h)
    xm = r * math.sin(ph)
    off = 0.03 + mask_relief(xm, h) + extra
    return HEAD + Vector((math.sin(ph) * (r + off), -math.cos(ph) * (r + off), h)), xm


EYES = (0.22, 0.075, 0.1, 0.03)       # 눈구멍 가운데 |x|, 높이, 반폭, 반높이


def build_mask():
    n = 40

    def at(pp, qq, extra=0.0):
        xm, h = mask_uv(pp, qq)
        ph = math.asin(max(-1, min(1, xm / head_r(h))))
        return mask_point(ph, h, extra)[0]
    grid = [[at(pp, qq) for pp in lin(-1, 1, n)] for qq in lin(-1, 1, n)]
    ex, eh, ew, ehh = EYES
    finish(mesh_obj("Mask", grid), "CalH", "Porcelain", sub=0, solid=0.024, offset=-1.0)
    # 아몬드 눈(어두운 벨벳 — 멀리서 눈구멍처럼 보인다)
    for s in (1, -1):
        rows = []
        for q in lin(-1, 1, 7):
            row = []
            for p in lin(-1, 1, 11):
                xm = s * ex + p * ew
                h = eh + q * ehh * (1 - p * p) ** 0.7 + 0.012 * (1 - p * p)
                ph = math.asin(max(-1, min(1, xm / head_r(h))))
                row.append(mask_point(ph, h, 0.003)[0])
            rows.append(row)
        finish(mesh_obj("Eye", rows), "CalH", "Velvet", sub=0)
    # 금 테두리(가면 가장자리를 도는 가는 관)
    loop = [at(pp, -1, 0.012) for pp in lin(-1, 1, 24)] + [at(1, qq, 0.012) for qq in lin(-1, 1, 24)[1:]]
    loop += [at(pp, 1, 0.012) for pp in lin(1, -1, 24)[1:]] + [at(-1, qq, 0.012) for qq in lin(1, -1, 24)[1:-1]]
    rows, _ = tube_rows(loop, 0.013, 6, round_end=False)
    rows.append(rows[0])
    finish(mesh_obj("Rim", rows, True), "CalH", "Gold", sub=0)
    # 북두칠성(+알코르) 금 상감: 별(네 갈래) + 잇는 선 + 별빛 점
    stars = {"Dubhe": (-0.26, 0.38), "Merak": (-0.27, 0.26), "Phecda": (-0.12, 0.24), "Megrez": (-0.09, 0.35),
             "Alioth": (0.06, 0.39), "Mizar": (0.2, 0.36), "Alkaid": (0.31, 0.24), "Alcor": (0.225, 0.42)}

    def on_mask(xm, h, extra):
        ph = math.asin(max(-1, min(1, xm / head_r(h))))
        return mask_point(ph, h, extra)[0], Vector((math.sin(ph), -math.cos(ph), 0.0))
    for name, (xm, h) in stars.items():
        size = 0.022 if name == "Alcor" else 0.04
        p, n = on_mask(xm, h, 0.03)
        M = Matrix.Translation(p) @ orient(n)
        pts = [M @ Vector(((size if k % 2 == 0 else size * 0.32) * math.cos(k * math.pi / 4), (size if k % 2 == 0 else size * 0.32) * math.sin(k * math.pi / 4), 0)) for k in range(8)]
        top = [M @ Vector(((size if k % 2 == 0 else size * 0.32) * 0.5 * math.cos(k * math.pi / 4), (size if k % 2 == 0 else size * 0.32) * 0.5 * math.sin(k * math.pi / 4), 0.008)) for k in range(8)]
        finish(mesh_obj("Star", [pts, top], True, M @ Vector((0, 0, -0.006)), M @ Vector((0, 0, 0.012))), "CalH", "Gold", sub=0)
        add_lathe("StarDot", "CalH", "Glow", [(0.0, 0.0), (size * 0.28, 0.0), (0.0, size * 0.3)], 8, Matrix.Translation(p + n * 0.012) @ orient(n), sub=0)
    for a_, b_ in (("Dubhe", "Merak"), ("Merak", "Phecda"), ("Phecda", "Megrez"), ("Megrez", "Dubhe"), ("Megrez", "Alioth"), ("Alioth", "Mizar"), ("Mizar", "Alkaid")):
        (x0, h0), (x1, h1) = stars[a_], stars[b_]
        pts = [on_mask(x0 + (x1 - x0) * t, h0 + (h1 - h0) * t, 0.032)[0] for t in lin(0.12, 0.88, 7)]
        add_tube("Line", "CalH", "Gold", pts, 0.006, 5, 0, round_start=True)
    # 남색 벨벳 끈(가면 옆에서 머리 뒤로 — 머리카락 밑)
    rows = []
    for hh in (0.06, 0.13):
        row = []
        for ph in lin(0.7, 2 * math.pi - 0.7, 30):
            r = head_r(hh) + 0.014
            row.append(HEAD + Vector((math.sin(ph) * r, -math.cos(ph) * r, hh)))
        rows.append(row)
    finish(mesh_obj("Ribbon", rows), "CalH", "Velvet", sub=1, solid=0.01, offset=-1.0)


# ═════════════════════════════ 팔 검(무기 공간) ═════════════════════════════

def build_blade():
    """무기 공간(블렌더): 원점 = 팔 끝(소맷부리 안), -y = 날 끝, x = 날 두께, z = 날 폭(로블록스 무기 +Y 쪽이 날).
    로블록스 무기 -Z(블렌더 -y)가 모터 C0(팔 끝 · X -90°)에서 팔 축 아래로 이어진다 — 팔이 곧 검."""
    objs = {}

    def W(y):
        return interp([(-2.48, 0.0), (-2.36, 0.09), (-2.12, 0.19), (-1.7, 0.235), (-0.6, 0.27), (-0.1, 0.31), (0.25, 0.31)], y)

    def T(y):
        return interp([(-2.48, 0.01), (-2.0, 0.045), (-0.1, 0.08), (0.25, 0.08)], y)
    rows = []
    for yv in lin(0.25, -2.48, 40):
        w, t = W(yv) / 2, T(yv) / 2
        f = w * 0.4
        sec = [(0.0, w), (t * 0.3, w * 0.86), (t, w * 0.52), (t, f), (t * 0.6, f * 0.55), (t * 0.6, -f * 0.55), (t, -f), (t, -w * 0.52), (t * 0.3, -w * 0.86),
               (0.0, -w), (-t * 0.3, -w * 0.86), (-t, -w * 0.52), (-t, -f), (-t * 0.6, -f * 0.55), (-t * 0.6, f * 0.55), (-t, f), (-t, w * 0.52), (-t * 0.3, w * 0.86)]
        rows.append([Vector((px, yv, pz)) for px, pz in reversed(sec)])
    ob = mesh_obj("CallistoArms_Main_Blade", rows, True, Vector((0, 0.26, 0)), Vector((0, -2.49, 0)))
    objs["Blade"] = ob
    # 혈조(푸른 강철) — 홈 안 양면 띠
    for s in (1, -1):
        rows = []
        for yv in lin(-0.12, -1.8, 16):
            t = T(yv) / 2 * 0.6 + 0.002
            hw = W(yv) / 2 * 0.4 * 0.5 * (1 - 0.7 * smooth(-1.5, -1.8, yv))
            rows.append([Vector((s * t, yv, z)) for z in lin(-hw, hw, 3)][:: s])
        o = mesh_obj("CallistoArms_Main_Fuller%d" % (1 if s > 0 else 2), rows)
        objs.setdefault("Fuller", []).append(o)
    # 날 밑 금 고리(소맷부리 바로 밖 — 날과 함께 나고 든다)
    rows, c0, c1 = lathe([(0.0, 0.0), (0.17, 0.0), (0.2, 0.03), (0.2, 0.09), (0.16, 0.12), (0.0, 0.12)], 20,
                         Matrix.Translation((0, 0.16, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    objs["Collar"] = mesh_obj("CallistoArms_Main_Collar", rows, True, c0, c1)
    # 별빛 일곱(북두칠성 모양으로 혈조를 따라 — 양면)
    dipper = [(-0.3, 0.012), (-0.48, -0.016), (-0.66, 0.0), (-0.84, 0.018), (-1.1, 0.009), (-1.36, -0.012), (-1.6, 0.006)]
    stars = []
    for s in (1, -1):
        for yv, zz in dipper:
            t = T(yv) / 2 * 0.6 + 0.004
            rr, cc, c1_ = lathe([(0.0, 0.0), (0.016, 0.0), (0.0, 0.012)], 8, Matrix.Translation((s * t, yv, zz)) @ orient((s, 0, 0)))
            stars.append(mesh_obj("Star", rr, True, cc, c1_))
    objs["Edge"] = stars
    return objs


# ═════════════════════════════ 마무리 · 내보내기 · 렌더 ═════════════════════════════

def box_uv(ob, tile):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            co = lp.vert.co
            if ax == 0:
                u, v = co.y * (1 if n.x > 0 else -1), co.z
            elif ax == 1:
                u, v = co.x * (-1 if n.y > 0 else 1), co.z
            else:
                u, v = co.x, co.y * (1 if n.z > 0 else -1)
            lp[uv].uv = (u / tile, v / tile)
    bm.to_mesh(ob.data)
    bm.free()


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = ob.data.name = name
    return ob


def dress(ob, mat, smooth_angle=48):
    ob.data.materials.clear()
    ob.data.materials.append(MATERIALS[mat])
    box_uv(ob, MATS[mat][1])
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def marker(name):
    rows, c0, c1 = lathe([(0.0, -0.5), (0.7071, -0.5), (0.7071, 0.5), (0.0, 0.5)], 4, Matrix.Rotation(math.pi / 4, 4, "Z"))
    ob = mesh_obj(name, rows, True, c0, c1)
    ob.data.materials.append(MATERIALS["Brass"])
    return ob


def export_glb(objs, path):
    # 블렌더 → glTF(+Y 위) 는 (x, z, -y) — z 둘레로 반 바퀴 돌려 두면 로블록스에서 FBX 때와 같은 (-x, z, y) 가 된다
    rot = Matrix.Rotation(math.pi, 4, "Z")
    for o in objs:
        o.data.transform(rot)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_texcoords=True, export_normals=True)
    for o in objs:
        o.data.transform(rot.inverted())
    print("GLB:", path)


def render_views(outfit, blade_objs):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 760, 1000
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.47, 0.56, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    for nm, loc, energy, size in (("Key", (-4, -6, 6), 900, 4), ("Rim", (5, 5, 5), 600, 3), ("Fill", (5, -5, 1), 250, 5)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.size = energy, size
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scol().objects.link(lo)
    # 미리보기 머리(살결) · 바닥 — 내보내지 않는다
    skin = bpy.data.materials.new("PreviewSkin")
    skin.use_nodes = True
    skin.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.72, 0.64, 1)
    prof = [(0.0, -0.625)] + [(head_r(h), h) for h in lin(-0.62, 0.62, 13)] + [(0.0, 0.625)]
    rows, c0, c1 = lathe(prof, 32, Matrix.Translation(HEAD))
    head = mesh_obj("PreviewHead", rows, True, c0, c1)
    head.data.materials.append(skin)
    for p in head.data.polygons:
        p.use_smooth = True
    floor = mesh_obj("PreviewFloor", [[Vector((-6, -6, -3.0)), Vector((6, -6, -3.0))], [Vector((-6, 6, -3.0)), Vector((6, 6, -3.0))]])
    fm = bpy.data.materials.new("PreviewFloor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.78, 0.82, 1)
    floor.data.materials.append(fm)
    # 팔 검을 오른팔 끝에(무기 공간 → 리그: 팔 끝 (-1.5, 0, -1), x 둘레 +90°)
    to_rig = Matrix.Translation((-1.5, 0, -1.0)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    for o in blade_objs:
        o.matrix_world = to_rig
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scol().objects.link(cam)
    scene.camera = cam
    for tag, d, mid, dist, lens in (("front", (0.18, -1.0, 0.1), (0, 0, -0.5), 13, 60), ("q34", (-0.8, -0.8, 0.2), (0, 0, -0.4), 12, 60),
                                    ("back", (-0.35, 1.0, 0.15), (0, 0, -0.5), 13, 60), ("mask", (0.15, -1.0, 0.05), (0, 0, 1.55), 3.4, 70),
                                    ("arm", (-1.0, -0.55, 0.1), (-1.6, 0, -1.4), 6.5, 55)):
        d = Vector(d).normalized()
        cam.location = Vector(mid) + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        scene.render.filepath = os.path.join(OUT, "CallistoV4_%s.png" % tag)
        bpy.ops.render.render(write_still=True)
    for o in (head, floor):
        bpy.data.objects.remove(o, do_unlink=True)
    for o in blade_objs:
        o.matrix_world = Matrix()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_textures()
    make_materials()
    build_shirt()
    build_jacket()
    build_waist()
    build_arm("CalLA", 1)
    build_glove("CalLA", 1)
    build_arm("CalRA", -1)
    build_leg("CalRL", -1)
    build_leg("CalLL", 1)
    build_mask()
    outfit, total = [], 0
    for (host, mat), objs in sorted(PIECES.items()):
        ob = dress(join(objs, "%s_%s" % (host, mat)), mat)
        n = tris(ob)
        assert n <= 20000, (ob.name, n)
        total += n
        print("  %-22s %6d tri" % (ob.name, n))
        outfit.append(ob)
    print("CallistoOutfit v4: %d tri · %d 메시" % (total, len(outfit)))
    PIECES.clear()
    parts = build_blade()
    blade = []
    for key, mat in (("Blade", "Steel"), ("Fuller", "BluedSteel"), ("Collar", "Gold"), ("Edge", "Glow")):
        objs = parts[key] if isinstance(parts[key], list) else [parts[key]]
        ob = dress(join(objs, "CallistoArms_Main_" + key), mat, 30)
        print("  %-26s %6d tri" % (ob.name, tris(ob)))
        blade.append(ob)
    if RENDER:
        render_views(outfit, blade)
    export_glb(outfit + [marker("CalOrigin_Marker")], os.path.join(HERE, "CallistoOutfit.glb"))
    export_glb(blade + [marker("WeaponsOrigin_Marker")], os.path.join(HERE, "CallistoBlade.glb"))


if __name__ == "__main__":
    main()
